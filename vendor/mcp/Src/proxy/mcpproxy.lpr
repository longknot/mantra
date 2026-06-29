{
    This file is part of the Free Component Library

    MCP transport proxy tool
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

program mcpproxy;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}
  cwstring,
  {$endif}
  { RTL }
  SysUtils, Classes, fpjson, jsonparser, jsonscanner,
  ssockets, custapp, types,

  { LSP }

  mcp.dispatcher.clientsocket,
  mcp.transport.socket,
  mcp.transport.stdio,
  mcp.controller,
  mcp.logging,
  mcp.proxy.config;

Type

  { TLSPProxyApplication }

  { TMCPProxyApplication }

  TMCPProxyApplication = Class(TCustomApplication)
  Private
    const
      ShortOptions = 'hp:u:c:l:';
      LongOptions : Array of string = ('help','port:','unix:','config:','log:');
    procedure DoMCPLog(aType: TMCPLogLevel; const Msg: string);
  Private
    FLog : TFIleStream;
    FConfig : TMCPProxyConfig;
    FText : TMCPSTDIOTransport;
    FDisp : TMCPClientSocketDispatcher;
    FController: TMCPController;
  protected
    procedure DoRun; override;
    // parse options
    function ParseOptions: Boolean;
    // Setup socket transport
    function SetupRemoteTransport: TMCPSocketTransport;
    // Text loop callback to handle a request
    procedure HandleRequest(aRequest: TJSONObject; var aResponse: TJSONObject);
    // Socket transport non-response handling
    procedure DoHandleFrame(Sender: TObject; const aFrame: TMCPFrame);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Usage(const aError: String); virtual;
  end;

procedure TMCPProxyApplication.DoHandleFrame(Sender: TObject; const aFrame: TMCPFrame);
// Socket transport calls this for all frames that are not mpmtResponse
var
  aMsg : String;
  lData : TJSONData;
begin
  aMsg:=aFrame.PayloadString;
  MCPLogger.Info('Out of band message of type %s: %s',[aFrame.MessageType.AsString,aMsg]);
  case aFrame.MessageType of
    mpmtDiagnostic: FText.SendDiagnostic(aMsg);
    mpmtRequest:
      begin
      try
        lData:=GetJSON(aMsg);
      except
        on E : Exception do
          MCPLogger.Warning('Invalid message format: %s',[aMsg]);
      end;
      try
        if lData is TJSONObject then
          FText.SendMessage(TJSONObject(lData))
        else
          MCPLogger.Warning('Invalid message format: %s',[aMsg]);
      finally
        lData.Free;
      end;
      end;
  else
    MCPLogger.Warning('Unknown out-of-band message of type %s: %s',[aFrame.MessageType.AsString,aMsg]);
  end;
end;

constructor TMCPProxyApplication.Create(TheOwner: TComponent);

begin
  inherited Create(TheOwner);
  FConfig:=TMCPProxyConfig.Create;
  StopOnException:=True;
end;

destructor TMCPProxyApplication.Destroy;
begin
  FreeAndNil(FConfig);
  FreeAndNil(FText);
  FreeAndNil(FController);
  FreeAndNil(FDisp);
  FreeAndNil(FLog);
  inherited Destroy;
end;

procedure TMCPProxyApplication.Usage(const aError: String);

begin
  if aError<>'' then
    Writeln('Error: ',aError);
  Writeln('Pascal Language Server Proxy [',{$INCLUDE %DATE%},']');
  Writeln('Usage: ', ExeName, ' [options]');
  Writeln('Where options is one or more of:');
  Writeln('-h  --help           This help message');
  Writeln('-c  --config=FILE    Read configuration from file FILE. Default is to read from ',TMCPProxyConfig.DefaultConfigFile);
  Writeln('-l  --log=FILE       Set log file in which to write all log messages');
  Writeln('-p  --port=NNN       Listen on port NNN (default: ',DefaultSocketPort);
  Writeln('-u  --unix=FILE      Listen on unix socket FILE (only on unix-like systems. Default: ',DefaultSocketUnix,')');
  Writeln('Only one of -p or -u may be specified, if none is specified then the default is to connect to port 9898');
  ExitCode:=Ord(aError<>'');
end;


function TMCPProxyApplication.ParseOptions: Boolean;
var
  FN : String;
begin
  Result:=False;
  FN:=GetOptionValue('c','config');
  if FN='' then
    FN:=TMCPProxyConfig.DefaultConfigFile;
  FConfig.LoadFromFile(FN);
{$IFDEF UNIX}
  if HasOption('u','unix') then
    FConfig.Unix:=GetOptionValue('u','unix');
{$ENDIF}
  if HasOption('p','port') then
    FConfig.Port:=StrToInt(GetOptionValue('p','port'));
  if HasOption('l','log') then
    FConfig.LogFile:=GetOptionValue('l','log');
  Result:=True;
end;

function TMCPProxyApplication.SetupRemoteTransport: TMCPSocketTransport;

var
  aSock : TSocketStream;

begin
  Result:=Nil;
  aSock:=Nil;
{$IFDEF UNIX}
  // Todo: Add some code to start the socket server, e.g. when the file does not exist.
  if FConfig.Unix<>'' then
    aSock:=TUnixSocket.Create(FConfig.Unix);
{$ENDIF}
  if aSock=Nil then
    aSock:=TInetsocket.Create('127.0.0.1',FConfig.Port);
  Result:=TMCPSocketTransport.Create(aSock);
  Result.OnHandleFrame:=@DoHandleFrame;
end;

procedure TMCPProxyApplication.HandleRequest(aRequest : TJSONObject; var aResponse : TJSONObject);
var
  lData : TJSONData;
begin
  lData:=FDisp.ExecuteRequest(aRequest);
  if lData is TJSONObject then
    aResponse:=TJSONObject(lData)
  else
    lData.Free;
end;

procedure TMCPProxyApplication.DoMCPLog(aType: TMCPLogLevel; const Msg: string);
var
  S : String;
begin
  WriteStr(S,aType);
  S:='['+S+'] '+Msg+sLineBreak;
  FLog.WriteBuffer(S[1],Length(S));
end;

procedure TMCPProxyApplication.DoRun;

var
  S : String;

begin
  Terminate;
  S:=CheckOptions(ShortOptions,LongOptions);
  if (S<>'') or HasOption('h','help') then
    begin
    Usage(S);
    exit;
    end;
  if not ParseOptions() then
    begin
    Usage('Faulty options');
    exit;
    end;
  // Controller is using remote transport
  FController:=TMCPController.Create(Self);
  if FConfig.LogFile<>'' then
    begin
    FLog:=TFileStream.Create(FConfig.LogFile,fmCreate or fmShareDenyNone);
    MCPLogger.AddLogHandler(@DoMCPLog);
    MCPLogger.LogToConsole:=False;
    MCPLogger.LogLevels:=[Low(TMCPLogLevel)..High(TMCPLogLevel)];
    MCPLogger.Enabled:=True;
    end;
  FText:=TMCPSTDIOTransport.Create(@Input,@Output,@StdErr);
  FController.RegisterTransport(FText);
  // Dispatcher is using remote transport
  FDisp:=TMCPClientSocketDispatcher.Create(FController);
  FDisp.Transport:=SetupRemoteTransport;
  // Set up text loop

  FText.RunMessageLoop(@HandleRequest);
end;

var
  Application: TMCPProxyApplication;

begin
  Application:=TMCPProxyApplication.Create(nil);
  Application.Title:='Pascal MCP Server proxy application';
  Application.Run;
  Application.Free;
end.

end.

