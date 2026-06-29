{
    This file is part of the Free Component Library

    MCP proxy tool configuration
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.proxy.config;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IniFiles;

Const
  DefaultSocketUnix = '';
  DefaultSocketPort = 9876;
  DefaultLogFile = '';

Type
  { TMCPProxyConfig }

  TMCPProxyConfig = Class(TObject)
  private
    FLogFile: String;
    FPort: Word;
    FUnix: String;
  Public
    Constructor Create; virtual;
    Procedure Reset; virtual;
    class Function DefaultConfigFile : String;
    Procedure LoadFromFile(const aFileName : String);
    Procedure SaveToFile(const aFileName : String);
    Procedure LoadFromIni(aIni : TCustomIniFile); virtual;
    Procedure SaveToIni(aIni : TCustomIniFile); virtual;
  Public
    Property Port : Word Read FPort Write FPort;
    Property Unix : String Read FUnix Write FUnix;
    Property LogFile : String Read FLogFile Write FLogFile;
  end;


implementation

Const
  SProxy = 'Proxy';
  KeyPort = 'Port';
  KeyUnix = 'Unix';
  KeyLogFile = 'LogFile';

{ TMCPProxyConfig }

constructor TMCPProxyConfig.Create;
begin
  Reset;
end;

procedure TMCPProxyConfig.Reset;
begin
  FPort:=DefaultSocketPort;
  FUnix:=DefaultSocketUnix;
  LogFile:=DefaultLogFile;
end;

class function TMCPProxyConfig.DefaultConfigFile: String;
begin
{$IFDEF UNIX}
  Result:='/etc/pasMCProxy.cfg';
{$ELSE}
  Result:=ChangeFileExt(ParamStr(0),'.ini');
{$ENDIF}
end;

procedure TMCPProxyConfig.LoadFromFile(const aFileName: String);

Var
  Ini : TCustomIniFile;

begin
  Ini:=TMemIniFile.Create(aFileName);
  try
    LoadFromIni(Ini);
  finally
    Ini.Free;
  end;
end;

procedure TMCPProxyConfig.SaveToFile(const aFileName: String);
Var
  Ini : TCustomIniFile;

begin
  Ini:=TMemIniFile.Create(aFileName);
  try
    SaveToIni(Ini);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

procedure TMCPProxyConfig.LoadFromIni(aIni: TCustomIniFile);
begin
  With aIni do
    begin
    FPort:=ReadInteger(SProxy,KeyPort,FPort);
    FUnix:=ReadString(SProxy,KeyUnix,FUnix);
    FLogFile:=ReadString(SProxy,KeyLogFile,LogFile);
    end;
end;

procedure TMCPProxyConfig.SaveToIni(aIni: TCustomIniFile);
begin
  With aIni do
    begin
    WriteInteger(SProxy,KeyPort,FPort);
    WriteString(SProxy,KeyUnix,FUnix);
    WriteString(SProxy,KeyLogFile,LogFile);
    end;
end;


end.

