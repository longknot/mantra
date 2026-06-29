{
    This file is part of the Free Component Library

    MCP client side process control transport
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit rpc.client.process;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, rpc.clienttool, fpjson, streamex, process;

Type

  { TMCPClientProcessTransport }

  TMCPClientProcessTransport = class(TMCPClientCustomTransport)
  private
    FArguments: TStrings;
    FExecutable: String;
    FProcess: TProcess;
    FExitCode : integer;
    function GetExitCode: Integer;
    function GetRunning: Boolean;
    procedure SetArguments(AValue: TStrings);
    procedure SetExecutable(AValue: String);
  Protected
    Procedure StartProcess(aProcess : TProcess); virtual;
    Procedure StopProcess(aProcess : TProcess); virtual;
    procedure DoConnect; override;
    procedure DoDisconnect; override;
    Property Process : TProcess Read FProcess;
  Public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    Property Running : Boolean Read GetRunning;
    Property ExitCode : Integer Read GetExitCode;
  Published
    Property Executable : String Read FExecutable Write SetExecutable;
    Property Arguments : TStrings Read FArguments Write SetArguments;
  end;



implementation


{ TMCPClientProcessTransport }

function TMCPClientProcessTransport.GetRunning: Boolean;
begin
  if Assigned(FProcess) then
    Result:=FProcess.Running
  else
    Result:=False;
end;

function TMCPClientProcessTransport.GetExitCode: Integer;
begin
  if Not Assigned(FProcess) then
    Result:=FExitCode
  else
    Result:=FProcess.ExitCode;
end;

procedure TMCPClientProcessTransport.SetArguments(AValue: TStrings);
begin
  if FArguments=AValue then Exit;
  FArguments.Assign(aValue);
end;

procedure TMCPClientProcessTransport.SetExecutable(AValue: String);
begin
  if FExecutable=AValue then Exit;
  FExecutable:=AValue;
end;

procedure TMCPClientProcessTransport.StartProcess(aProcess: TProcess);
begin
  aProcess.Execute;
end;

procedure TMCPClientProcessTransport.StopProcess(aProcess: TProcess);
begin
  aProcess.Terminate(0);
end;

procedure TMCPClientProcessTransport.DoConnect;
begin
  FProcess:=TProcess.Create(Self);
  FProcess.Executable:=Executable;
  FProcess.Parameters.Assign(Arguments);
  FExitCode:=-1;
  StartProcess(FProcess);
end;

procedure TMCPClientProcessTransport.DoDisconnect;
begin
  if not Assigned(FProcess) then
    exit;
  try
    StopProcess(FProcess);
    FExitCode:=FProcess.ExitCode;
  finally
    FreeAndNil(FProcess);
  end;
end;

constructor TMCPClientProcessTransport.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FArguments:=TStringList.Create;
end;

destructor TMCPClientProcessTransport.Destroy;
begin
  FreeAndNil(FArguments);
  inherited Destroy;
end;



end.
