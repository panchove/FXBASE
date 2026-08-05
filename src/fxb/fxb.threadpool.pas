unit fxb.threadpool;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  Generics.Collections,
  fxb.preprocessor,
  fxb.errors;

type
  TThreadJob = procedure(const AData: Pointer);
  TJobPair = record
    Job: TThreadJob;
    Data: Pointer;
  end;
  TJobQueue = specialize TQueue<TJobPair>;

  TThreadPool = class
  private
    FWorkers: array of TThread;
    FJobQueue: TJobQueue;
    FQueueLock: TCriticalSection;
    FJobAvailable: TEvent;
    FShutdown: Boolean;
    FShutdownLock: TCriticalSection;
    FActiveJobs: Integer;
    FActiveJobsLock: TCriticalSection;
    FOnJobComplete: TNotifyEvent;
    
    procedure WorkerExecute(WorkerIndex: Integer);
    function GetJobCount: Integer;
    function GetActiveJobCount: Integer;
  public
    constructor Create(const AWorkerCount: Integer = 0); // 0 = auto-detect cores
    destructor Destroy; override;
    
    procedure QueueJob(const AJob: TThreadJob; const AData: Pointer = nil);
    procedure WaitForCompletion(const ATimeoutMs: Integer = -1); // -1 = infinite
    procedure Shutdown;
    function GetWorkerCount: Integer;
    
    property WorkerCount: Integer read GetWorkerCount;
    property JobCount: Integer read GetJobCount;
    property ActiveJobCount: Integer read GetActiveJobCount;
    property OnJobComplete: TNotifyEvent read FOnJobComplete write FOnJobComplete;
  end;

  // Helper for parallel file processing
  TParallelFileProcessor = class
  private
    FPool: TThreadPool;
    FSourceFiles: TStringList;
    FIncludePaths: TStringList;
    FDefines: TStringList;
    FOutputDir: string;
    FResults: TStringList;
    FResultsLock: TCriticalSection;
    FErrors: TStringList;
    FErrorsLock: TCriticalSection;
    FCompletedCount: Integer;
    FTotalCount: Integer;
    
    class procedure ProcessFileJobStatic(const AData: Pointer); static;
    function GetResult(const AIndex: Integer): string;
    function GetError(const AIndex: Integer): string;
  public
    constructor Create(const AWorkerCount: Integer = 0);
    destructor Destroy; override;
    
    procedure AddFile(const AFile: string);
    procedure SetIncludePaths(const APaths: TStringList);
    procedure SetDefines(const ADefines: TStringList);
    procedure SetOutputDir(const ADir: string);
    function ProcessAll: Boolean;
    
    property Results[const Index: Integer]: string read GetResult;
    property Errors[const Index: Integer]: string read GetError;
    property CompletedCount: Integer read FCompletedCount;
    property TotalCount: Integer read FTotalCount;
  end;

function GetCPUCoreCount: Integer;

implementation

function GetCPUCoreCount: Integer;
var
  f: TextFile;
  line: string;
  count: Integer;
begin
  // Fallback: read /proc/cpuinfo
  count := 0;
  Assign(f, '/proc/cpuinfo');
  {$I-}
  Reset(f);
  {$I+}
  if IOResult = 0 then
  begin
    while not EOF(f) do
    begin
      Readln(f, line);
      if Pos('processor', LowerCase(line)) = 1 then
        Inc(count);
    end;
    Close(f);
  end;
  
  if count > 0 then
    Result := count
  else
    Result := 1;
end;

{ TThreadPool }

type
  TWorkerThread = class(TThread)
  private
    FPool: TThreadPool;
    FWorkerIndex: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TThreadPool; AWorkerIndex: Integer; ASuspended: Boolean);
  end;

constructor TWorkerThread.Create(APool: TThreadPool; AWorkerIndex: Integer; ASuspended: Boolean);
begin
  FPool := APool;
  FWorkerIndex := AWorkerIndex;
  FreeOnTerminate := False;
  inherited Create(ASuspended);
end;

procedure TWorkerThread.Execute;
begin
  FPool.WorkerExecute(FWorkerIndex);
end;

constructor TThreadPool.Create(const AWorkerCount: Integer = 0);
var
  i: Integer;
  count: Integer;
begin
  inherited Create;

  count := AWorkerCount;
  if count <= 0 then
    count := GetCPUCoreCount;

  FQueueLock := TCriticalSection.Create;
  FShutdownLock := TCriticalSection.Create;
  FActiveJobsLock := TCriticalSection.Create;
  FJobQueue := TJobQueue.Create;
  FShutdown := False;
  FActiveJobs := 0;
  FOnJobComplete := nil;

  SetLength(FWorkers, count);
  // Create workers suspended first: TThread.Create initializes the FPC
  // threading manager, which TEvent.Create below depends on.
  for i := 0 to count - 1 do
    FWorkers[i] := TWorkerThread.Create(Self, i, True);

  FJobAvailable := TEvent.Create(nil, True, False, 'fxb_pool');

  for i := 0 to count - 1 do
    FWorkers[i].Start;
end;

destructor TThreadPool.Destroy;
var
  i: Integer;
begin
  Shutdown;
  
  for i := 0 to High(FWorkers) do
    FWorkers[i].Free;
  SetLength(FWorkers, 0);
  
  FJobQueue.Free;
  FJobAvailable.Free;
  FQueueLock.Free;
  FShutdownLock.Free;
  FActiveJobsLock.Free;
  
  inherited Destroy;
end;

procedure TThreadPool.WorkerExecute(WorkerIndex: Integer);
var
  job: TThreadJob;
  data: Pointer;
  jobRecord: TJobPair;
begin
  while True do
  begin
    // Wait for job
    FJobAvailable.WaitFor(INFINITE);
    
    // Check shutdown
    FShutdownLock.Enter;
    try
      if FShutdown then
        Exit;
    finally
      FShutdownLock.Leave;
    end;
    
    // Get job from queue
    FQueueLock.Enter;
    try
      if FJobQueue.Count = 0 then
      begin
        FJobAvailable.ResetEvent;
        Continue;
      end;
      jobRecord := FJobQueue.Dequeue;
      job := jobRecord.Job;
      data := jobRecord.Data;
      // Mark active before the queue is observed empty: WaitForCompletion
      // treats "queue empty" as "no job in flight", so the increment must be
      // visible before FQueueLock is released.
      FActiveJobsLock.Enter;
      Inc(FActiveJobs);
      FActiveJobsLock.Leave;
      if FJobQueue.Count = 0 then
        FJobAvailable.ResetEvent;
    finally
      FQueueLock.Leave;
    end;

    // Execute job
    try
      if Assigned(job) then
        job(data);
    finally
      FActiveJobsLock.Enter;
      Dec(FActiveJobs);
      FActiveJobsLock.Leave;
      
      if Assigned(FOnJobComplete) then
        FOnJobComplete(Self);
    end;
  end;
end;

procedure TThreadPool.QueueJob(const AJob: TThreadJob; const AData: Pointer = nil);
var
  jobRecord: TJobPair;
begin
  FShutdownLock.Enter;
  try
    if FShutdown then
      Exit;
  finally
    FShutdownLock.Leave;
  end;
  
  jobRecord.Job := AJob;
  jobRecord.Data := AData;
  
  FQueueLock.Enter;
  try
    FJobQueue.Enqueue(jobRecord);
    FJobAvailable.SetEvent;
  finally
    FQueueLock.Leave;
  end;
end;

procedure TThreadPool.WaitForCompletion(const ATimeoutMs: Integer = -1);
var
  startTime: QWord;
  timeout: QWord;
begin
  startTime := GetTickCount64;
  if ATimeoutMs >= 0 then
    timeout := ATimeoutMs
  else
    timeout := QWord(-1);
  
  while True do
  begin
    // Check the queue first (under its lock), then the active count. Workers
    // increment FActiveJobs before releasing FQueueLock when dequeuing, so a
    // queue observed as empty implies no job is still in flight.
    FQueueLock.Enter;
    try
      if FJobQueue.Count = 0 then
      begin
        FActiveJobsLock.Enter;
        try
          if FActiveJobs = 0 then
            Exit;
        finally
          FActiveJobsLock.Leave;
        end;
      end;
    finally
      FQueueLock.Leave;
    end;
    
    if (timeout <> QWord(-1)) and (GetTickCount64 - startTime >= timeout) then
      Exit;
    
    Sleep(1);
  end;
end;

procedure TThreadPool.Shutdown;
begin
  FShutdownLock.Enter;
  try
    FShutdown := True;
  finally
    FShutdownLock.Leave;
  end;
  
  // Wake all workers
  FJobAvailable.SetEvent;
end;

function TThreadPool.GetJobCount: Integer;
begin
  FQueueLock.Enter;
  try
    Result := FJobQueue.Count;
  finally
    FQueueLock.Leave;
  end;
end;

function TThreadPool.GetActiveJobCount: Integer;
begin
  FActiveJobsLock.Enter;
  try
    Result := FActiveJobs;
  finally
    FActiveJobsLock.Leave;
  end;
end;

function TThreadPool.GetWorkerCount: Integer;
begin
  Result := Length(FWorkers);
end;

{ TParallelFileProcessor }

type
  PFileJobData = ^TFileJobData;
  TFileJobData = record
    FilePath: string;
    Index: Integer;
    IncludePaths: TStringList;
    Defines: TStringList;
    OutputDir: string;
    Results: TStringList;
    ResultsLock: TCriticalSection;
    Errors: TStringList;
    ErrorsLock: TCriticalSection;
    CompletedCount: PInteger;
  end;

constructor TParallelFileProcessor.Create(const AWorkerCount: Integer = 0);
begin
  inherited Create;
  FPool := TThreadPool.Create(AWorkerCount);
  FSourceFiles := TStringList.Create;
  FIncludePaths := TStringList.Create;
  FDefines := TStringList.Create;
  FResults := TStringList.Create;
  FResultsLock := TCriticalSection.Create;
  FErrors := TStringList.Create;
  FErrorsLock := TCriticalSection.Create;
  FCompletedCount := 0;
  FTotalCount := 0;
  FOutputDir := '';
end;

destructor TParallelFileProcessor.Destroy;
begin
  FPool.Free;
  FSourceFiles.Free;
  FIncludePaths.Free;
  FDefines.Free;
  FResults.Free;
  FResultsLock.Free;
  FErrors.Free;
  FErrorsLock.Free;
  inherited Destroy;
end;

procedure TParallelFileProcessor.AddFile(const AFile: string);
begin
  FSourceFiles.Add(AFile);
end;

procedure TParallelFileProcessor.SetIncludePaths(const APaths: TStringList);
begin
  FIncludePaths.Assign(APaths);
end;

procedure TParallelFileProcessor.SetDefines(const ADefines: TStringList);
begin
  FDefines.Assign(ADefines);
end;

procedure TParallelFileProcessor.SetOutputDir(const ADir: string);
begin
  FOutputDir := ADir;
  if (FOutputDir <> '') and not DirectoryExists(FOutputDir) then
    ForceDirectories(FOutputDir);
end;

class procedure TParallelFileProcessor.ProcessFileJobStatic(const AData: Pointer);
var
  jobData: PFileJobData;
  source: string;
  sl: TStringList;
  line: string;
  outputFile: string;
  preprocessor: TPreprocessor;
  reporter: TErrorReporter;
  ppoOutput: string;
  i: Integer;
  hasError: Boolean;
  errMsg: string;
begin
  jobData := PFileJobData(AData);
  
  // Load source
  sl := TStringList.Create;
  try
    sl.LoadFromFile(jobData^.FilePath);
    source := '';
    for line in sl do
      source := source + line + LineEnding;
  finally
    sl.Free;
  end;
  
  // Create preprocessor
  reporter := TErrorReporter.Create(jobData^.FilePath);
  preprocessor := TPreprocessor.Create(reporter);
  try
    // Set includes and defines
    for i := 0 to jobData^.IncludePaths.Count - 1 do
      preprocessor.AddIncludePath(jobData^.IncludePaths[i]);
    for i := 0 to jobData^.Defines.Count - 1 do
      preprocessor.Defines.Values[jobData^.Defines.Names[i]] := jobData^.Defines.ValueFromIndex[i];
    
    // Process
    ppoOutput := preprocessor.Process(source, jobData^.FilePath);
    
    hasError := reporter.HasErrors;
    errMsg := '';
    if hasError then
    begin
      for i := 0 to Length(reporter.Messages) - 1 do
        errMsg := errMsg + DumpMessage(reporter.Messages[i]) + LineEnding;
    end;
  finally
    preprocessor.Free;
    reporter.Free;
  end;
  
  // Save result or error
  jobData^.ResultsLock.Enter;
  try
    while jobData^.Results.Count <= jobData^.Index do
      jobData^.Results.Add('');
    jobData^.Results[jobData^.Index] := ppoOutput;
  finally
    jobData^.ResultsLock.Leave;
  end;
  
  if hasError then
  begin
    jobData^.ErrorsLock.Enter;
    try
      while jobData^.Errors.Count <= jobData^.Index do
        jobData^.Errors.Add('');
      jobData^.Errors[jobData^.Index] := errMsg;
    finally
      jobData^.ErrorsLock.Leave;
    end;
  end;
  
  // Write .ppo file if output dir set
  if (jobData^.OutputDir <> '') and not hasError then
  begin
    outputFile := jobData^.OutputDir + '/' + ExtractFileName(ChangeFileExt(jobData^.FilePath, '.ppo'));
    sl := TStringList.Create;
    try
      sl.Text := ppoOutput;
      sl.SaveToFile(outputFile);
    finally
      sl.Free;
    end;
  end;
  
  // Update completed count
  InterlockedIncrement(jobData^.CompletedCount^);
  
  // Free job data
  Dispose(jobData);
end;

function TParallelFileProcessor.ProcessAll: Boolean;
var
  i: Integer;
  jobData: PFileJobData;
begin
  FTotalCount := FSourceFiles.Count;
  FCompletedCount := 0;
  FResults.Clear;
  FErrors.Clear;
  
  for i := 0 to FSourceFiles.Count - 1 do
  begin
    New(jobData);
    jobData^.FilePath := FSourceFiles[i];
    jobData^.Index := i;
    jobData^.IncludePaths := FIncludePaths;
    jobData^.Defines := FDefines;
    jobData^.OutputDir := FOutputDir;
    jobData^.Results := FResults;
    jobData^.ResultsLock := FResultsLock;
    jobData^.Errors := FErrors;
    jobData^.ErrorsLock := FErrorsLock;
    jobData^.CompletedCount := @FCompletedCount;
    FPool.QueueJob(@ProcessFileJobStatic, jobData);
  end;
  
  FPool.WaitForCompletion;
  
  // Check for errors
  Result := True;
  for i := 0 to FErrors.Count - 1 do
  begin
    if FErrors[i] <> '' then
    begin
      WriteLn(StdErr, 'Error preprocessing ', FSourceFiles[i], ':');
      WriteLn(StdErr, FErrors[i]);
      Result := False;
    end;
  end;
end;

function TParallelFileProcessor.GetResult(const AIndex: Integer): string;
begin
  FResultsLock.Enter;
  try
    if (AIndex >= 0) and (AIndex < FResults.Count) then
      Result := FResults[AIndex]
    else
      Result := '';
  finally
    FResultsLock.Leave;
  end;
end;

function TParallelFileProcessor.GetError(const AIndex: Integer): string;
begin
  FErrorsLock.Enter;
  try
    if (AIndex >= 0) and (AIndex < FErrors.Count) then
      Result := FErrors[AIndex]
    else
      Result := '';
  finally
    FErrorsLock.Leave;
  end;
end;

end.