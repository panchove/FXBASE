program test_threadpool;

{$mode delphi}{$H+}

// Unit tests for fxb.threadpool: parallel job execution, completion waiting
// (including the dequeue-vs-active race), timeouts, callbacks and concurrent
// pools.

uses
  cthreads, // MUST be first: initializes the FPC threading manager (TEvent depends on it)
  SysUtils,
  SyncObjs,
  fxb.threadpool,
  fxb.test.framework;

var
  GCount: Integer = 0;
  GCountLock: TCriticalSection;

procedure IncJob(const AData: Pointer);
begin
  GCountLock.Enter;
  try
    Inc(GCount);
  finally
    GCountLock.Leave;
  end;
end;

procedure SleepJob(const AData: Pointer);
begin
  Sleep(200);
  IncJob(AData);
end;

type
  TCallbackTracker = class
    Completed: Integer;
    procedure OnJobComplete(ASender: TObject);
  end;

procedure TCallbackTracker.OnJobComplete(ASender: TObject);
begin
  GCountLock.Enter;
  try
    Inc(Completed);
  finally
    GCountLock.Leave;
  end;
end;

procedure TestPool_WorkerCount;
var
  pool: TThreadPool;
begin
  pool := TThreadPool.Create(4);
  try
    AssertEqualsI(4, pool.WorkerCount, 'explicit worker count');
  finally
    pool.Free;
  end;

  pool := TThreadPool.Create(0);
  try
    AssertTrue(pool.WorkerCount >= 1, 'auto-detected worker count >= 1');
  finally
    pool.Free;
  end;
end;

procedure TestPool_BasicParallel;
var
  pool: TThreadPool;
  i: Integer;
begin
  GCount := 0;
  pool := TThreadPool.Create(4);
  try
    for i := 1 to 1000 do
      pool.QueueJob(@IncJob);
    // NOTE: workers consume the queue concurrently, so JobCount is not 1000
    // at any point after the first enqueue; only end-state counts are asserted.
    pool.WaitForCompletion;
    AssertEqualsI(1000, GCount, 'every job executed exactly once');
    AssertEqualsI(0, pool.JobCount, 'queue empty after completion');
    AssertEqualsI(0, pool.ActiveJobCount, 'no active jobs after completion');
  finally
    pool.Free;
  end;
end;

// Regression for the WaitForCompletion race: the queue is drained before
// FActiveJobs is bumped, so waiting could observe "empty queue + zero active"
// while a job was still in flight. Many small batches stress the window.
procedure TestPool_ManyBatches;
var
  pool: TThreadPool;
  i, b: Integer;
begin
  pool := TThreadPool.Create(2);
  try
    for b := 1 to 50 do
    begin
      GCount := 0;
      for i := 1 to 20 do
        pool.QueueJob(@IncJob);
      pool.WaitForCompletion;
      AssertEqualsI(20, GCount, 'batch ' + IntToStr(b) + ' completed fully');
    end;
  finally
    pool.Free;
  end;
end;

procedure TestPool_JobCompleteCallback;
var
  pool: TThreadPool;
  tracker: TCallbackTracker;
  i: Integer;
begin
  GCount := 0;
  tracker := TCallbackTracker.Create;
  pool := TThreadPool.Create(3);
  try
    tracker.Completed := 0;
    pool.OnJobComplete := tracker.OnJobComplete;
    for i := 1 to 100 do
      pool.QueueJob(@IncJob);
    pool.WaitForCompletion;
    AssertEqualsI(100, GCount, 'jobs ran');
    AssertEqualsI(100, tracker.Completed, 'callback fired once per job');
  finally
    pool.Free;
    tracker.Free;
  end;
end;

procedure TestPool_Timeout;
var
  pool: TThreadPool;
  startTick, elapsed: QWord;
begin
  GCount := 0;
  pool := TThreadPool.Create(1);
  try
    pool.QueueJob(@SleepJob);
    startTick := GetTickCount64;
    pool.WaitForCompletion(50);
    elapsed := GetTickCount64 - startTick;
    AssertTrue(elapsed < 150, 'WaitForCompletion(50) returns before the 200ms job finishes');
    AssertEqualsI(0, GCount, 'long job still running after short timeout');
    pool.WaitForCompletion;
    AssertEqualsI(1, GCount, 'long job finished after full wait');
  finally
    pool.Free;
  end;
end;

procedure TestPool_ConcurrentPools;
var
  pool1, pool2: TThreadPool;
  i: Integer;
begin
  pool1 := TThreadPool.Create(2);
  pool2 := TThreadPool.Create(2);
  try
    GCount := 0;
    for i := 1 to 500 do
      pool1.QueueJob(@IncJob);
    for i := 1 to 500 do
      pool2.QueueJob(@IncJob);
    pool1.WaitForCompletion;
    pool2.WaitForCompletion;
    AssertEqualsI(1000, GCount, 'jobs from both pools ran to completion');
  finally
    pool1.Free;
    pool2.Free;
  end;
end;

begin
  GCountLock := TCriticalSection.Create;
  try
    RegisterTest('ThreadPool: worker count', @TestPool_WorkerCount);
    RegisterTest('ThreadPool: basic parallel execution', @TestPool_BasicParallel);
    RegisterTest('ThreadPool: many batches (WaitForCompletion race)', @TestPool_ManyBatches);
    RegisterTest('ThreadPool: OnJobComplete callback', @TestPool_JobCompleteCallback);
    RegisterTest('ThreadPool: WaitForCompletion timeout', @TestPool_Timeout);
    RegisterTest('ThreadPool: concurrent pools', @TestPool_ConcurrentPools);
    RunAllTests('THREAD POOL TESTS');
  finally
    GCountLock.Free;
  end;
end.
