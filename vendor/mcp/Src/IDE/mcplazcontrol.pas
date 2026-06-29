{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit mcplazcontrol;

{$warn 5023 off : no warning about unused units}
interface

uses
  mcpcontrolreg, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('mcpcontrolreg', @mcpcontrolreg.Register);
end;

initialization
  RegisterPackage('mcplazcontrol', @Register);
end.
