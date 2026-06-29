unit mcp.transport.http;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, httpprotocol, contnrs, mcp.types, mcp.dispatcher.http, mcp.controller, mcp.transport.base, httpdefs, httproute;

{$IF DECLARED(THTTPServerEvent)}
{$DEFINE USE_EVENTS}
{$ENDIF}

const
  SInitializeMethod = 'initialize';
  SMcpSessionID = 'Mcp-Session-Id';
  STextEventStream = 'text/event-stream';

Type
  EMCPHTTP = class(EMCPException);

  { TMCPHTTPTransport }

  TMCPHTTPTransport = class(TMCPMessageTransport)
  private
    FResponse: TResponse;
    FUseSSE: Boolean;
    FEventID : Integer;
    FClosed : Boolean;
  protected
    procedure DoSendDiagnostic(const aMessage: UTF8String); override;
    procedure DoSendMessage(aMessage: TJSONData); override;
    property Closed : Boolean read FClosed;
  Public
    Property Response : TResponse Read FResponse Write FResponse;
    Property UseSSE : Boolean Read FUseSSE Write FUseSSE;
  end;

  { TMCPSession }

  TMCPSession = class(TComponent)
  private
    FDIspatcher: TMCPHTTPDispatcher;
    FLastSeen: TDateTime;
    FSessionID: String;
    FTransport: TMCPHTTPTransport;
    FTransportRegistered: Boolean;
  protected
    procedure SetSessionID(AValue: String); virtual;
    function CreateTransport: TMCPHTTPTransport; virtual;
    function CreateDispatcher : TMCPHTTPDispatcher; virtual;
  Public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RegisterTransport;
    procedure UnRegisterTransport;
    Property Transport : TMCPHTTPTransport Read FTransport;
    Property Dispatcher : TMCPHTTPDispatcher Read FDispatcher;
    Property SessionID : String read FSessionID Write SetSessionID;
    Property LastSeen : TDateTime Read FLastSeen Write FLastSeen;
  end;

  { TMCPRoute }
  TAuthenticateRequestEvent = Procedure (Sender : TObject; aRequest : TRequest; var aAllow : Boolean) of object;

  TMCPRoute = class(TComponent)
  Private
    class var _instance : TMCPRoute;
  private
    FAllowSSE: Boolean;
    FOnAuthenticate: TAuthenticateRequestEvent;
    FRequireSessionID: Boolean;
    FSessions : TFPObjectHashTable;
  protected
    function AuthenticateRequest(aRequest : TRequest; aResponse : TResponse): boolean; virtual;
    function AllocateSession: String; virtual;
    function GetOrCreateSession(const aSessionID : String) : TMCPSession;
    function FindSession(const aSessionID : String) : TMCPSession;
    function CreateSession(const aSessionID : String) : TMCPSession; virtual;
    function DeleteSession(const aSessionID : String) : Boolean;
    function CheckSession(ARequest: TRequest; AResponse: TResponse; aMethod: string; out aSession: string): boolean; virtual;
    function GetJSONRPC(aRequest: TRequest; out aMethod: string): TJSONData; virtual;
    procedure HandleMCPDeleteRequest(ARequest: TRequest; AResponse: TResponse); virtual;
    procedure HandleMCPGetRequest(ARequest: TRequest; AResponse: TResponse); virtual;
    procedure HandleMCPPostRequest(ARequest: TRequest; AResponse: TResponse); virtual;
  Public
    constructor Create(aOwner : TComponent); override;
    destructor destroy; override;
    class procedure Init(const aPath : String);
    class property Instance : TMCPRoute Read _Instance;
    // Allow use of SSE if client supports it ?
    property AllowSSE : Boolean Read FAllowSSE Write FAllowSSE;
    // Require session ID ?
    property RequireSessionID : Boolean Read FRequireSessionID Write FRequireSessionID;
    // Called for all requests
    Property OnAuthenticate : TAuthenticateRequestEvent Read FOnAuthenticate Write FOnAuthenticate;
  end;

implementation

{$IFDEF VER3_2_2}

Type

  { TResponseHelper }

  TResponseHelper = class helper for TResponse
    procedure SetStatus(const aStatus : Integer; aSend : Boolean);
  end;

{ TResponseHelper }

procedure TResponseHelper.SetStatus(const aStatus: Integer; aSend: Boolean);
begin
  Code:=aStatus;
  case aStatus of
    200 : CodeText:='OK';
    204 : CodeText:='NO CONTENT';
    400 : CodeText:='BAD REQUEST';
    401 : CodeText:='UNAUTHORIZED';
    404 : CodeText:='NOT FOUND';
  end;
  if aSend then
    SendResponse;
end;

{$ENDIF}

{ TMCPHTTPTransport }

procedure TMCPHTTPTransport.DoSendDiagnostic(const aMessage: UTF8String);
var
  lEventID,lJSON : string;
  lObj,lData : TJSONObject;
  {$IFDEF USE_EVENTS}
  lEventData : THTTPServerEvent;
  {$ENDIF}
begin
  if Response=Nil then
    exit;
  inc(FEventID);
  lEventID:=IntToStr(FEventID);
  lData:=TJSONObject.Create(['level','info','data', aMessage,'logger','MCP']);
  try
    lObj:=TJSONObject.Create(['json-rpc','2.0','method','notifications/message','params',lData]);
    lData:=Nil; // so it is not freed...
    lJSON:=lObj.AsJSON;
  finally
    lData.Free;
    lObj.Free;
  end;
  {$IFDEF USE_EVENTS}
  if UseSSE then
    begin
    lEventData:=Default(THTTPServerEvent);
    lEventData.Event:='mcp';
    lEventData.Id:=lEventID;
    SetLength(lEventData.Data,1);
    lEventData.Data[0]:=lJSON;
    Response.SendServerEvent(lEventData);
    end
  else
  {$endif}
    // FPC extension...
    Response.CustomHeaders.Values['X-Server-Event-'+lEventID]:=lJSON;
end;

procedure TMCPHTTPTransport.DoSendMessage(aMessage: TJSONData);
var
  lEventID,lJSON : string;
  {$IFDEF USE_EVENTS}
  lEventData : THTTPServerEvent;
  {$ENDIF}
begin
  if not Assigned(Response) then
    exit;
  inc(FEventID);
  lEventID:=IntToStr(FEventID);
  lJSON:=aMessage.AsJSON;
  {$IFDEF USE_EVENTS}
  if UseSSE then
    begin
    lEventData:=Default(THTTPServerEvent);
    lEventData.Id:=lEventID;
    SetLength(lEventData.Data,1);
    lEventData.Event:='mcp';
    lEventData.Data[0]:=lJSON;
    Response.SendServerEvent(lEventData);
    Response.EndServerEvents;
    FClosed:=True;
    Response:=Nil;
    end
  else
  {$endif}
    // FPC extension...
    begin
    Response.ContentStream:=TStringStream.Create(lJSON);
    Response.FreeContentStream:=True;
    Response.ContentType:='application/json';
    Response.SendResponse;
    FClosed:=True;
    Response:=Nil;
    end;
end;

{ TMCPSession }

procedure TMCPSession.SetSessionID(AValue: String);
begin
  if FSessionID=AValue then Exit;
  FSessionID:=AValue;
  FDIspatcher.SessionID:=aValue;
end;

function TMCPSession.CreateTransport: TMCPHTTPTransport;
begin
  Result:=TMCPHTTPTransport.Create(Self);
end;

function TMCPSession.CreateDispatcher: TMCPHTTPDispatcher;
begin
  Result:=TMCPHTTPDispatcher.Create(TMCPController.Instance);
end;

constructor TMCPSession.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTransport:=CreateTransport;
  FDispatcher:=CreateDispatcher;
end;

destructor TMCPSession.Destroy;
begin
  UnregisterTRansport;
  FreeAndNil(FTransport);
  FreeAndNil(FDispatcher);
  inherited Destroy;
end;

procedure TMCPSession.RegisterTransport;
begin
  TMCPController.Instance.RegisterTransport(Transport);
  FTransportRegistered:=True;
end;

procedure TMCPSession.UnRegisterTransport;
begin
  if FTransportRegistered then
    TMCPController.Instance.UnRegisterTransport(Transport);
  FTransportRegistered:=False;
end;

{ TMCPRoute }

procedure TMCPRoute.HandleMCPGetRequest(ARequest: TRequest; AResponse: TResponse);
var
  lAllow : Boolean;
{$IFDEF USE_EVENTS}
  lSession : TMCPSession;
{$ENDIF}
begin
  if not AuthenticateRequest(aRequest,aResponse) then
    exit;
{$IFNDEF USE_EVENTS}
// No streams in 3.2.2
  lAllow:=False;
{$ELSE}
  lAllow:=AllowSSE;
{$endif};
  if not lAllow then
    begin
    aResponse.Code:=405;
    aResponse.CodeText:='METHOD NOT ALLOWED';
    aResponse.SendResponse;
    end
  else
    begin
    {$IFDEF USE_EVENTS}
    lSession:=GetOrCreateSession(aRequest.CustomHeaders.Values['Mcp-Session-Id']);
    lSession.Transport.Response:=aResponse;
    lSession.RegisterTransport;
    aResponse.CustomHeaders.Values['Mcp-Session-Id']:=lSession.SessionID;
    aResponse.StartServerEvents;
    {$ENDIF}
    end;
end;

function TMCPRoute.GetJSONRPC(aRequest : TRequest; out aMethod : string) : TJSONData;
var
  lReq : TJSONData;
  lObj : TJSONObject absolute lReq;
begin
  aMethod:='';
  lReq:=GetJSON(aRequest.Content);
  if lReq is TJSONObject then
    aMethod:=lObj.Get('method','');
  Result:=lReq;
end;

function TMCPRoute.CheckSession(ARequest: TRequest; AResponse: TResponse; aMethod : string; out aSession : string) : boolean;

begin
  aSession:=aRequest.CustomHeaders.Values[SMcpSessionId];
  if not RequireSessionID then
    Result:=True
  else
    begin
    if (aMethod<>SInitializeMethod) then
      begin
      Result:=(aSession<>'');
      if not Result then
        aResponse.SetStatus(400,True);
      end
    else
      begin
      aSession:=AllocateSession;
      Result:=True;
      end;
    end;
end;

procedure TMCPRoute.HandleMCPPostRequest(ARequest: TRequest; AResponse: TResponse);
var
  lSession : TMCPSession;
  lSessionID,lMethod : String;
  lRequest,lResponse : TJSONData;
begin
  lSession:=Nil;
  lResponse:=Nil;
  if not AuthenticateRequest(aRequest,aResponse) then
    exit;
  // Get JSON-RPC request and extract method
  lRequest:=GetJSONRPC(aRequest,lMethod);
  try
    if not CheckSession(aRequest,aResponse,lMethod,lSessionID) then
      exit;
    lSession:=GetOrCreateSession(lSessionID);
    lSession.Transport.Response:=aResponse;
    if (lSessionID<>'') and (lMethod=SInitializeMethod) then
      aResponse.CustomHeaders.Values[SMcpSessionID]:=lSessionID;
    {$IFDEF USE_EVENTS}
    lSession.Transport.UseSSE:=AllowSSE and (Pos(STextEventStream,aRequest.Accept)>0);
    if lSession.Transport.UseSSE then
      aResponse.StartServerEvents;
    {$ELSE}
    lSession.Transport.UseSSE:=False;
    {$ENDIF}
    lResponse:=lSession.Dispatcher.ExecuteRequest(lRequest);
    lSession.Transport.SendMessage(lResponse);
  finally
    lResponse.Free;
    lRequest.Free;
    if Assigned(lSession) and (lSession.SessionID='') then
      lSession.Free;
  end;
end;

constructor TMCPRoute.Create(aOwner: TComponent);
begin
  inherited;
  FSessions:=TFPObjectHashTable.Create(True);
  FRequireSessionID:=True;
end;

destructor TMCPRoute.destroy;
begin
  FreeAndNil(FSessions);
  inherited destroy;
end;

function TMCPRoute.AuthenticateRequest(aRequest: TRequest; aResponse: TResponse): boolean;
begin
  Result:=True;
  if Assigned(OnAuthenticate) then
    FOnAuthenticate(Self,aRequest,Result);
  if not Result then
    aResponse.SetStatus(401,True);
end;

function TMCPRoute.AllocateSession: String;
begin
  Result:=TGUID.NewGuid.ToString(True);
end;

function TMCPRoute.GetOrCreateSession(const aSessionID: String): TMCPSession;
var
  lNewSession : string;
begin
  Result:=Nil;
  if aSessionID<>'' then
    Result:=FindSession(aSessionID);
  if (Result=Nil) then
    begin
    if RequireSessionID then
      lNewSession:=AllocateSession;
    Result:=CreateSession(lNewSession);
    end;
  Result.LastSeen:=Now;
end;

function TMCPRoute.FindSession(const aSessionID: String): TMCPSession;
begin
  Result:=TMCPSession(FSessions.Items[aSessionID]);
end;

function TMCPRoute.CreateSession(const aSessionID: String): TMCPSession;
begin
  Result:=TMCPSession.Create(Self);
  Result.SessionID:=aSessionID;
  if aSessionID<>'' then
    FSessions.Add(aSessionID,Result);
end;

function TMCPRoute.DeleteSession(const aSessionID: String): Boolean;
begin
  Result:=Assigned(FSessions.Items[aSessionID]);
  if Result then
    FSessions.Delete(aSessionID);
end;

procedure TMCPRoute.HandleMCPDeleteRequest(ARequest: TRequest; AResponse: TResponse);
begin
  if not AuthenticateRequest(aRequest,aResponse) then
    exit;
  {$IFNDEF USE_EVENTS}
    // No streams in 3.2.2
    aResponse.Code:=405;
    aResponse.CodeText:='METHOD NOT ALLOWED';
    aResponse.SendResponse;
  {$ELSE}
    if DeleteSession(aRequest.CustomHeaders.Values['Mcp-Session-Id']) then
      aResponse.SetStatus(204,True)
    else
      aResponse.SetStatus(404,True);
  {$ENDIF}
end;


class procedure TMCPRoute.Init(const aPath: String);
begin
  if Assigned(_Instance) then
    Raise EMCPHTTP.Create('MCP routing already initialized');
  _Instance:=TMCProute.Create(Nil);
  HTTPRouter.RegisterRoute(aPath,rmGet,@_Instance.HandleMCPGetRequest);
  HTTPRouter.RegisterRoute(aPath,rmPost,@_Instance.HandleMCPPostRequest);
  HTTPRouter.RegisterRoute(aPath,rmDelete,@_Instance.HandleMCPDeleteRequest);
end;

end.

