{
    This file is part of the Free Component Library

    Include various types of database support
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcpsqldbsupport;

// Undefine this if you want to enable all supported databases
{$DEFINE USE_ALL_SUPPORTED}

// Undefine one of these to include support for that particular database
{ $DEFINE USE_FIREBIRD}
{ $DEFINE USE_POSTGRESQL}
{ $DEFINE USE_MYSQL8}
{ $DEFINE USE_MYSQL57}
{ $DEFINE USE_ORACLE}
{ $DEFINE USE_ODBC}
{ $DEFINE USE_MSSQL}
{ $DEFINE USE_SQLITE}



{$IFDEF USE_ALL_SUPPORTED}
{$DEFINE USE_FIREBIRD}
{$DEFINE USE_POSTGRESQL}
{$DEFINE USE_MYSQL8}
{$DEFINE USE_MYSQL57}
{$DEFINE USE_ORACLE}
{$DEFINE USE_ODBC}
{$DEFINE USE_MSSQL}
{$DEFINE USE_SQLITE}
{$ENDIF}

interface

uses
  {$IFDEF USE_FIREBIRD}
  ibase60dyn,
  IBConnection,
  mcpmetadata.firebird,
  {$ENDIF}
  {$IFDEF USE_POSTGRESQL}
  PQConnection,
  mcpmetadata.postgresql,
  {$ENDIF}
  {$IFDEF USE_MYSQL8}
  mysql80conn,
  {$ENDIF}
  {$IFDEF USE_MYSQL57}
  mysql57conn,
  {$ENDIF}
  {$IF DEFINED(USE_MYSQL8) OR DEFINED(USE_MYSQL57)}
  mcpmetadata.mysql,
  {$ENDIF}
  {$IFDEF USE_ODBC}
  odbcconn,
  {$ENDIF}
  {$IFDEF USE_MSSQL}
  MSSQLConn,
  mcpmetadata.mssql,
  {$ENDIF}
  {$IFDEF USE_ORACLE}
  oracleconnection,
  mcpmetadata.oracle,
  {$ENDIF}
  {$IFDEF USE_SQLITE}
  SQLite3Conn,
  mcpmetadata.sqlite,
  {$ENDIF}
  Sqldb,
  mcpmetadata.base,
  mcpsqldbtools;


implementation

{$IFDEF UNIX}
uses
  baseunix, unixtype;
{$ENDIF}

{$IFDEF unix}
{$IFDEF USE_FIREBIRD}
{$DEFINE INSTALLSIGHANDLER}
{$ENDIF}
{$ENDIF}

// Firebird installs a signal handler which prevents Ctrl-C from working.
// So when it is used, we explicitly load firebird and override their signal handler.
{$ifdef INSTALLSIGHANDLER}
procedure installdefaultsignalhandler(signum: Integer; out oldact: SigActionRec); external name '_FPC_INSTALLDEFAULTSIGHANDLER';

var
  OldInt,
  OldTerm : SigActionRec;

procedure HandleCtrlC(sig : longint; SigInfo: PSigInfo; SigContext: PSigContext);

begin
  TMCPToolConnectionManager.Instance.CloseConnections;
  Case Sig of
    SIGTERM: oldterm.sa_handler(sig,siginfo,sigcontext);
    SIGINT: oldint.sa_handler(sig,siginfo,sigcontext);
  end;
  Halt(42);
end;

var
  HandlerInstalled : Boolean;

Procedure InstallCtrlCHandler;

var
  act : SigActionRec;

begin
  if HandlerInstalled then
    exit;
  act:=Default(SigActionRec);
  { initialize handler                    }
  act.sa_handler := SigActionHandler(@HandleCtrlC);
  act.sa_flags:=SA_SIGINFO;
  FpSigAction(SIGINT,@act,@oldint);
  FpSigAction(SIGTERM,@act,@oldterm);
  HandlerInstalled:=True;
end;
{$ENDIF}

initialization
// If we need to install a signal handler...
{$IFDEF INSTALLSIGHANDLER}
// We load the libs that need this...
{$IFDEF USE_FIREBIRD}
  InitialiseIBase60;
{$ENDIF}
// And we install the signal handler
  InstallCtrlCHandler
{$ENDIF}
end.

