unit mcp.application.http;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpapp, mcp.transport.http;

type

  { TMCPServerApplication }

  { TMCPHTTPServerApplication }

  TMCPHTTPServerApplication = class(THTTPApplication)
  private
    FRequireSessionID : Boolean;
    FAllowSSE: Boolean;
    FEndpointPath: String;
    FOnAuthenticate: TAuthenticateRequestEvent;
    function GetAllowSSE: Boolean;
    function GetOnAuthenticate: TAuthenticateRequestEvent;
    function GetRequireSessionID: Boolean;
    procedure SetALlowSSE(AValue: Boolean);
    procedure SetEndPointPath(AValue: String);
    procedure SetOnAuthenticate(AValue: TAuthenticateRequestEvent);
    procedure SetRequireSessionID(AValue: Boolean);
  Public
    constructor Create(AOwner: TComponent); override;
    procedure Initialize; override;
    // This must be set before calling Initialize. Defaults to /MCP
    Property EndpointPath : String Read FEndpointPath Write SetEndPointPath;
    // This can be set any time. Will initiate a SSE stream when client has the capability.
    Property AllowSSE : Boolean Read GetAllowSSE Write SetALlowSSE;
    // If set, then a session ID is required.
    Property RequireSessionID : Boolean Read GetRequireSessionID Write SetRequireSessionID;
    // Set this to allow authenticating a request
    Property OnAuthenticate : TAuthenticateRequestEvent Read GetOnAuthenticate Write SetOnAuthenticate;
  end;

implementation

uses mcp.stdhandlers;

{ TMCPServerApplication }

procedure TMCPHTTPServerApplication.SetEndPointPath(AValue: String);
begin
  if FEndpointPath=AValue then Exit;
  if Assigned(TMCPRoute.Instance) then
    Raise EMCPHTTP.Create('MCP Server already initialized');
  FEndpointPath:=AValue;
end;

procedure TMCPHTTPServerApplication.SetOnAuthenticate(AValue: TAuthenticateRequestEvent);
begin
  if GetOnAuthenticate=AValue then Exit;
  FOnAuthenticate:=AValue;
  if assigned(TMCPRoute.Instance) then
      TMCPRoute.Instance.OnAuthenticate:=aValue;
end;

procedure TMCPHTTPServerApplication.SetRequireSessionID(AValue: Boolean);
begin

end;

constructor TMCPHTTPServerApplication.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  {$IFNDEF VER3_2}
  ALlowSSE:=True;
  Address:='127.0.0.1';
  {$ENDIF}
end;

procedure TMCPHTTPServerApplication.SetALlowSSE(AValue: Boolean);
begin
  if GetAllowSSE=AValue then Exit;
  FAllowSSE:=AValue;
  if Assigned(TMCPRoute.Instance) then
    TMCPRoute.Instance.AllowSSE:=True;
end;

function TMCPHTTPServerApplication.GetOnAuthenticate: TAuthenticateRequestEvent;
begin
  if assigned(TMCPRoute.Instance) then
    Result:=TMCPRoute.Instance.OnAuthenticate
  else
    Result:=FOnAuthenticate;
end;

function TMCPHTTPServerApplication.GetRequireSessionID: Boolean;
begin
  if Assigned(TMCPRoute.Instance) then
    Result:=TMCPRoute.Instance.RequireSessionID
  else
    Result:=FRequireSessionID;
end;

function TMCPHTTPServerApplication.GetAllowSSE: Boolean;
begin
  if Assigned(TMCPRoute.Instance) then
    Result:=TMCPRoute.Instance.AllowSSE
  else
    Result:=AllowSSE;
end;

procedure TMCPHTTPServerApplication.Initialize;
var
  lPath : String;
begin
  inherited Initialize;
  RegisterStandardHandlers;
  lPath:=EndpointPath;
  if lPath='' then
    lPath:='/MCP';
  TMCPRoute.Init(lPath);
  TMCPRoute.Instance.AllowSSE:=FAllowSSE;
  TMCPRoute.Instance.OnAuthenticate:=FOnAuthenticate;
  TMCPRoute.Instance.RequireSessionID:=FRequireSessionID;
end;

end.

