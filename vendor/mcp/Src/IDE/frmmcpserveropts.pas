unit frmmcpserveropts;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ButtonPanel;

type
  TTransportType = (ttStdIO,ttHTTP,ttSocket,ttDefine);

  { TMCPServerOptionsForm }

  TMCPServerOptionsForm = class(TForm)
    bpmcpserver: TButtonPanel;
    cbAddTool : TCheckbox;
    cbLogging: TCheckBox;
    rgTransport : TRadioGroup;
  private
    FTransportType: TTransportType;
    function GetAddTool: Boolean;
    function GetConfigureLogging: Boolean;
    function GetTransportType: TTransportType;
  public
    property AddTool : Boolean read GetAddTool;
    property ConfigureLogging : Boolean read GetConfigureLogging;
    property TransportType : TTransportType read GetTransportType;
  end;

var
  MCPServerOptionsForm: TMCPServerOptionsForm;

implementation

{$R *.lfm}

{ TMCPServerOptionsForm }

function TMCPServerOptionsForm.GetAddTool: Boolean;
begin
  Result:=cbAddTool.Checked;
end;

function TMCPServerOptionsForm.GetConfigureLogging: Boolean;
begin
  Result:=cbLogging.Checked;
end;

function TMCPServerOptionsForm.GetTransportType: TTransportType;
begin
  Result:=TTransportType(rgTransport.ItemIndex);
end;

end.

