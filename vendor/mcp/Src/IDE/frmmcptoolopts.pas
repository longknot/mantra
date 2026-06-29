unit frmmcptoolopts;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ButtonPanel, StdCtrls;

type
  TToolReturn = (trSingle,trMultiple,trRaw)  ;
  { TMCPToolOptionsForm }

  TMCPToolOptionsForm = class(TForm)
    BPMCP: TButtonPanel;
    cbRegister: TCheckBox;
    cbReturn: TComboBox;
    edtClassName: TEdit;
    edtName: TEdit;
    EdtDescription: TEdit;
    lblReturn: TLabel;
    lblClassName: TLabel;
    lblName: TLabel;
    lblDescription: TLabel;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    function GetToolClassName: string;
    function GetToolDescription: String;
    function GetToolName: string;
    function GetToolRegister: boolean;
    function GetToolReturn: TToolReturn;

  public
    Property ToolDescription : String Read GetToolDescription;
    Property ToolName : string Read GetToolName;
    property ToolClassName: string Read GetToolClassName;
    property ToolRegister : boolean Read GetToolRegister;
    property ToolReturn : TToolReturn Read GetToolReturn;
  end;

var
  MCPToolOptionsForm: TMCPToolOptionsForm;

implementation

uses mcpstrings;

{$R *.lfm}

{ TMCPToolOptionsForm }

procedure TMCPToolOptionsForm.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);

var
  ErrMsg : string;

  procedure Check (aCond : Boolean; const aMsg : string);
  begin
    if aCond then
      exit;
    if ErrMsg<>'' then
      ErrMsg:=ErrMsg+sLineBreak;
    ErrMsg:=ErrMsg+aMsg;
  end;

begin
  ErrMsg:='';
  Check(ToolClassName<>'', rsToolClassNameRequired);
  Check(IsValidIdent(ToolClassName),rsToolClassNameIdentifier);
  Check(ToolName<>'',rsToolNameRequired);
  Check(ToolDescription<>'',rsToolDescriptionRequired);
  Check(cbReturn.ItemHeight<>-1,rsToolReturnRequired);
  CanClose:=ErrMsg='';
  if not CanClose then
    MessageDlg(rsIncomplete,ErrMsg,mtError,[mbOK],0);
end;

function TMCPToolOptionsForm.GetToolClassName: string;
begin
  Result:=edtClassName.Text;
end;

function TMCPToolOptionsForm.GetToolDescription: String;
begin
  Result:=EdtDescription.Text;
end;

function TMCPToolOptionsForm.GetToolName: string;
begin
  Result:=EdtName.Text;
end;

function TMCPToolOptionsForm.GetToolRegister: boolean;
begin
  Result:=cbRegister.Checked;
end;

function TMCPToolOptionsForm.GetToolReturn: TToolReturn;
begin
  Result:=TToolReturn(cbReturn.ItemIndex);
end;

end.

