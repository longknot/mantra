{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit mcpclient;

{$warn 5023 off : no warning about unused units}
interface

uses
  rpc.clienttool, MCP.Client.Base, rpc.client.process, rpc.client.stdio,
  MCP.Client.Calls, mcp.client, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('mcpclient', @Register);
end.
