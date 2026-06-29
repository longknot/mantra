{
    This file is part of the Free Component Library

    MCP logging class
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.logging;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, mcp.types;

Type
  EMCPLogger = class(Exception);
  TMCPLogger = class;
  TMCPLoggerClass = class of TMCPLogger;
  TMCPLogLevel = TMCPLogType;
  TMCPLogLevels = TMCPLogTypes;
  TMCPLogEvent = procedure (aType: TMCPLogLevel; const Msg : string) of Object;
  TMCPLogEventArray = array of TMCPLogEvent;

  { TMCPLogger }

  TMCPLogger = class(TObject)
  Private
    class var _Instance : TMCPLogger;
  private
    FEnabled: Boolean;
    FLogLevels: TMCPLogLevels;
    FLogToConsole: Boolean;
    FLogHandlers: TMCPLogEventArray;
    class function GetInstance: TMCPLogger; static;
  public
    constructor create; virtual;
    Class procedure InitLogger(aClass : TMCPLoggerClass);
    class function LogLeveltoString(aLevel : TMCPLogLevel) : string;
    class destructor done;
    Procedure Log(aType : TMCPLogLevel; Const Msg : String);
    Procedure Log(aType : TMCPLogLevel; Const Fmt : String; Const Args : Array of const);
    // Shortcuts
    Procedure Debug(Const Msg : String); inline;
    Procedure Debug(Const Fmt : String; Const Args : Array of const);
    Procedure Error(Const Msg : String); inline;
    Procedure Error(Const Fmt : String; Const Args : Array of const);
    Procedure Info(Const Msg : String); inline;
    Procedure Info(Const Fmt : String; Const Args : Array of const);
    Procedure Warning(Const Msg : String); inline;
    Procedure Warning(Const Fmt : String; Const Args : Array of const);
    Procedure Trace(Const Msg : String); inline;
    Procedure Trace(Const Fmt : String; Const Args : Array of const);
    Procedure LogException(E : Exception; Const Msg : String); inline;
    Procedure LogException(E : Exception; Const Fmt : String; Const Args : Array of const);

    procedure AddLogHandler(aEvent : TMCPLogEvent);
    procedure RemoveLogHandler(aEvent : TMCPLogEvent);
    property LogLevels : TMCPLogLevels Read FLogLevels Write FLogLevels;
    Property Enabled : Boolean Read FEnabled Write FEnabled;
    property LogToConsole : Boolean Read FLogToConsole Write FLogToConsole;
    class property Instance : TMCPLogger Read GetInstance;
  end;

function MCPLogger : TMCPLogger;

implementation

const
  LogLevelNames : array[TMCPLogType] of string = ('Error','Warning','Info','Trace','Debug');

resourcestring
  SErrLoggerInitialized = 'Logger is already initialized';
  SErrLoggerEmptyClass = 'Cannot initialize logger with empty class';

function MCPLogger : TMCPLogger;
begin
  Result:=TMCPLogger.Instance;
end;

{ TMCPLogger }

class function TMCPLogger.GetInstance: TMCPLogger; static;
begin
  if _instance=Nil then
    _Instance:=TMCPLogger.Create;
  Result:=_Instance;
end;


constructor TMCPLogger.create;
begin
  FLogLevels:=[mltError];
  FEnabled:=True;
  FLogToConsole:=True;
end;

class procedure TMCPLogger.InitLogger(aClass: TMCPLoggerClass);
begin
  if assigned(_Instance) then
    Raise EMCPLogger.Create(SErrLoggerInitialized);
  if aClass=nil then
    Raise EMCPLogger.Create(SErrLoggerEmptyClass);
  _instance:=aClass.Create;
end;

class function TMCPLogger.LogLeveltoString(aLevel: TMCPLogLevel): string;

begin
  Result:=LogLevelNames[aLevel];
end;

class destructor TMCPLogger.done;
begin
  FreeAndNil(_Instance);
end;

procedure TMCPLogger.Log(aType: TMCPLogLevel; const Msg: String);
var
  aHandler : TMCPLogEvent;
begin
  if Not (Enabled and (aType in LogLevels)) then
    exit;
  if LogToConsole then
    Writeln(StdErr,LogLevelToString(aType),Msg);
  for aHandler in FLogHandlers do
     aHandler(aType,Msg);
end;

procedure TMCPLogger.Log(aType: TMCPLogLevel; const Fmt: String; const Args: array of const);
begin
  if Not (Enabled and (aType in LogLevels)) then
    exit;
  Log(aType,Format(Fmt,Args));
end;

procedure TMCPLogger.Debug(const Msg: String);
begin
  Log(mltDebug,Msg);
end;

procedure TMCPLogger.Debug(const Fmt: String; const Args: array of const);
begin
  Log(mltDebug,Fmt,Args);
end;

procedure TMCPLogger.Error(const Msg: String);
begin
  Log(mltError,Msg);
end;

procedure TMCPLogger.Error(const Fmt: String; const Args: array of const);
begin
  Log(mltError,Fmt,Args);
end;

procedure TMCPLogger.Info(const Msg: String);
begin
  Log(mltInfo,Msg);
end;

procedure TMCPLogger.Info(const Fmt: String; const Args: array of const);
begin
  Log(mltInfo,Fmt,Args);
end;

procedure TMCPLogger.Warning(const Msg: String);
begin
  Log(mltWarning,Msg);
end;

procedure TMCPLogger.Warning(const Fmt: String; const Args: array of const);
begin
  Log(mltWarning,Fmt,Args);
end;

procedure TMCPLogger.Trace(const Msg: String);
begin
  Log(mltTrace,Msg);
end;

procedure TMCPLogger.Trace(const Fmt: String; const Args: array of const);
begin
  Log(mltTrace,Fmt,Args);
end;

procedure TMCPLogger.LogException(E: Exception; const Msg: String);
begin
  Error('Exception %s during %s: %s',[E.ClassName,Msg,E.Message]);
end;

procedure TMCPLogger.LogException(E: Exception; const Fmt: String; const Args: array of const);
begin
  LogException(E,Format(Fmt,Args));
end;

procedure TMCPLogger.AddLogHandler(aEvent: TMCPLogEvent);
var
  Len : integer;
begin
  Len:=Length(FLogHandlers);
  SetLength(FLogHandlers,Len+1);
  FLogHandlers[Len]:=aEvent;
end;

procedure TMCPLogger.RemoveLogHandler(aEvent: TMCPLogEvent);
var
  Last,Idx : integer;
begin
  Last:=Length(FLogHandlers)-1;
  For Idx:=Last downto 0 do
    if FLogHandlers[Idx]=aEvent then
      begin
      if Idx<Last then
        FLogHandlers[Idx]:=FLogHandlers[Last];
      SetLength(FLogHandlers,Last);
      Dec(Last);
      end;
end;

end.

