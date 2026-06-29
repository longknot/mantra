{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit mcpdesign;

{$warn 5023 off : no warning about unused units}
interface

uses
  regmcp, frmmcptoolopts, mcpstrings, frmmcpserveropts, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('regmcp', @regmcp.Register);
end;

initialization
  RegisterPackage('mcpdesign', @Register);
end.
