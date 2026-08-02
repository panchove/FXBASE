unit fxb.ast;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fxb.tokens,
  fxb.ast.expr,
  fxb.ast.stmt,
  fxb.ast.def,
  fxb.ast.base;

type
  // Re-export essential types from sub-units to make them available in fxb.ast
  TASTNode = fxb.ast.base.TASTNode;
  TExpr = fxb.ast.base.TExpr;
  TExprArray = fxb.ast.base.TExprArray;
  TASTNodeArray = fxb.ast.base.TASTNodeArray;
  TASTNodeArrayArray = fxb.ast.base.TASTNodeArrayArray;
  TFunctionDef = fxb.ast.def.TFunctionDef;
  TProcedureDef = fxb.ast.def.TProcedureDef;
  TMethodDef = fxb.ast.def.TMethodDef;
  TConstructorDef = fxb.ast.def.TConstructorDef;
  TClassDef = fxb.ast.def.TClassDef;
  TInterfaceDef = fxb.ast.def.TInterfaceDef;
  TStructDef = fxb.ast.def.TStructDef;
  TNewTypeDef = fxb.ast.def.TNewTypeDef;
  TCompilationUnit = fxb.ast.def.TCompilationUnit;
  // Expression types
  TLiteralExpr = fxb.ast.expr.TLiteralExpr;
  TIdentifierExpr = fxb.ast.expr.TIdentifierExpr;
  TBinaryExpr = fxb.ast.expr.TBinaryExpr;
  TUnaryExpr = fxb.ast.expr.TUnaryExpr;
  TCallExpr = fxb.ast.expr.TCallExpr;
  TMethodCallExpr = fxb.ast.expr.TMethodCallExpr;
  TMemberAccessExpr = fxb.ast.expr.TMemberAccessExpr;
  TDerefExpr = fxb.ast.expr.TDerefExpr;
  TIndexExpr = fxb.ast.expr.TIndexExpr;
  TArrayLiteralExpr = fxb.ast.expr.TArrayLiteralExpr;
  THashLiteralExpr = fxb.ast.expr.THashLiteralExpr;
  TStructLiteralExpr = fxb.ast.expr.TStructLiteralExpr;
  TMacroExpr = fxb.ast.expr.TMacroExpr;
  TCodeBlockExpr = fxb.ast.expr.TCodeBlockExpr;
  // Statement types
  TExprStmt = fxb.ast.stmt.TExprStmt;
  TPrintStmt = fxb.ast.stmt.TPrintStmt;
  TVarDeclStmt = fxb.ast.stmt.TVarDeclStmt;
  TAssignStmt = fxb.ast.stmt.TAssignStmt;
  TIfStmt = fxb.ast.stmt.TIfStmt;
  TForStmt = fxb.ast.stmt.TForStmt;
  TWhileStmt = fxb.ast.stmt.TWhileStmt;
  TReturnStmt = fxb.ast.stmt.TReturnStmt;
  TYieldStmt = fxb.ast.stmt.TYieldStmt;
  TLoopCtrlStmt = fxb.ast.stmt.TLoopCtrlStmt;
  TASTDBStmt = fxb.ast.stmt.TASTDBStmt;

implementation

end.
