{
    This file is part of the Free Component Library

    MCP dispatcher class - handles request-response
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.dispatcher.base;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, fpjsonrpc,
  mcp.Logging,
  mcp.Handler,
  mcp.types,
  mcp.controller,
  mcp.transport.base;

Type
  {
    A dispatcher is responsible for handling a request and returning the result.
    It is 'Transport-Aware'
  }
  TMCPBaseDispatcher = class(TComponent)
  protected
    Function GetTransport : TMCPMessageTransport; virtual; abstract;
  Public
    Function ExecuteRequest(aRequest : TJSONData): TJSONData; virtual; abstract;
    Property Transport : TMCPMessageTransport Read GetTransport;
  end;


  { TJSONRPCDispatcher }
  { Wrapper class for TCustomJSONRPCDispatcher, does 2 things:
    - handles a bug in fpc's 3.2.2. JSON-rpc
    - Adds transport
  }

  TJSONRPCDispatcher = class(TCustomJSONRPCDispatcher)
  private
    FTransport: TMCPMessageTransport;
  protected
    function ExecuteHandler(H: TCustomJSONRPCHandler; Params, ID: TJSONData; AContext: TJSONRPCCallContext): TJSONData; override;
    function ExecuteMethod(const AClassName, AMethodName: TJSONStringType;  Params, ID: TJSONData; AContext: TJSONRPCCallContext): TJSONData; override;
    function CheckRequest(Request: TJSONData; Out AClassName, AMethodName : TJSONStringType; Out ID, Params : TJSONData): TJSONData; override;
  public
    constructor Create(AOwner: TComponent); override;
    Property Transport : TMCPMessageTransport Read FTransport Write FTransport;
  end;

  {
   TMCPLocalDispatcher
   // Dispatches the request locally through a TJSONRPCDispatcher instance.
  }

  TClientMethodResultEvent = procedure (Sender : TObject; aResponse : TObject; const aID : String; aResult : TJSONData) of object;
  TClientMethodErrorEvent = procedure (Sender : TObject; aResponse : TObject; const aID : String; aError : TJSONData) of object;

  TMCPLocalDispatcher = class(TMCPBaseDispatcher)
  Private
    FJSONDispatcher : TJSONRPCDispatcher;
    FOnMethodError: TClientMethodErrorEvent;
    FOnMethodResult: TClientMethodResultEvent;
    FController: TMCPController;
    FTransport: TMCPMessageTransport;
    procedure SetTransport(const aValue: TMCPMessageTransport);
  Protected
    procedure ProcessClientMethodResult(aResponse: TJSONObject; const aID : String; aResult: TJSONData); virtual;
    procedure ProcessClientMethodError(aResponse: TJSONObject; const aID : String; aResult: TJSONData); virtual;
    function GetTransport: TMCPMessageTransport; override;
    function CreateContext : TMCPContext;  virtual;
    property JSONDispatcher : TJSONRPCDispatcher read FJSONDispatcher;
  Public
    Constructor Create(aController : TMCPController); reintroduce;
    Destructor Destroy; override;
    Property Transport : TMCPMessageTransport Read FTransport Write SetTransport;
    function ExecuteRequest(aRequest : TJSONData): TJSONData; override;
    // Called when client (acting as server) returned a result.
    Property OnMethodResult : TClientMethodResultEvent Read FOnMethodResult Write FOnMethodResult;
    // Called when client (acting as server) returned a result.
    Property OnMethodError : TClientMethodErrorEvent Read FOnMethodError Write FOnMethodError;
  end;


implementation

{ ---------------------------------------------------------------------
  TJSONRPCDispatcher
  ---------------------------------------------------------------------}

constructor TJSONRPCDispatcher.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Options := [jdoSearchRegistry, jdoJSONRPC2, jdoNotifications, jdoStrictNotifications];
end;


function TJSONRPCDispatcher.ExecuteHandler(H: TCustomJSONRPCHandler; Params,
  ID: TJSONData; AContext: TJSONRPCCallContext): TJSONData;
begin
  MCPLogger.Trace('[%s] Execute handler "%s" - start',[ClassName,H.ClassName]);
  if H is TMCPBaseHandler then
    TMCPBaseHandler(H).Transport:=Self.FTransport;
  Result:=Inherited ExecuteHandler(H,Params,ID,AContext);
  MCPLogger.Trace('[%s] Execute handler "%s" - end',[ClassName,H.ClassName]);
end;

function TJSONRPCDispatcher.ExecuteMethod(const AClassName, AMethodName: TJSONStringType;
    Params, ID: TJSONData; AContext: TJSONRPCCallContext): TJSONData;

Var
  {$IFDEF VER3_2}
  lID : TJSONData;
  {$ENDIF}
  lRes : TJSONObject;

begin
  MCPLogger.Trace('[%s] ExecuteMethod "%s.%s" - start',[ClassName,AClassName,aMethodName]);
  try
{$IFDEF VER3_2}
    lID:=ID;
    if lID=Nil then
      lID:=TJSONIntegerNumber.Create(0);
    try
      Result := inherited ExecuteMethod(AClassName, AMethodName, Params, lID, AContext);
    finally
      if lID<>ID then
        lID.Free;
    end;
{$ELSE}
   Result := inherited ExecuteMethod(AClassName, AMethodName, Params, ID, AContext);
{$ENDIF}
  except
    on E: EMCPException do // handle errors specific to MCP
      begin
      MCPLogger.LogException(E,'[%s] ExecuteMethod "%s.%s"',[ClassName,AClassName,aMethodName]);
      lRes:=CreateJSON2Error(E.Message, E.Code, ID.Clone, TransactionProperty);
      if lRes.Types['id']=jtNull then
        lRes.Delete('id');
      Result:=lRes;
      end;
    on Ex: EJSON do // handle errors specific to JSON
      begin
      MCPLogger.LogException(Ex,'[%s] ExecuteMethod "%s.%s"',[ClassName,AClassName,aMethodName]);
      lRes:=CreateJSON2Error(Ex.Message, 500, ID.Clone, TransactionProperty);
      if lRes.Types['id']=jtNull then
        lRes.Delete('id');
      Result:=lRes;
      end;
    on Er: exception do // handle other errors
      begin
      MCPLogger.LogException(Er,'[%s] ExecuteMethod "%s.%s"',[ClassName,AClassName,aMethodName]);
      lRes:=CreateJSON2Error(Er.Message, 500, ID.Clone, TransactionProperty);
      if lRes.Types['id']=jtNull then
        lRes.Delete('id');
      Result:=lRes;
      end
  else
    // Not even an Exception ??
    raise;
  end;
  MCPLogger.Trace('[%s] ExecuteMethod "%s.%s" - end',[ClassName,AClassName,aMethodName]);
end;

function TJSONRPCDispatcher.CheckRequest(Request: TJSONData; out AClassName, AMethodName: TJSONStringType; out ID, Params: TJSONData
  ): TJSONData;
var
  lRequest : TJSONObject absolute Request;
begin
  MCPLogger.Trace('[%s] CheckRequest - start',[ClassName]);
  if Request is TJSONObject then
    begin
    // FPC's JSON-RPC always expects a params property, but for notifications, we don't get one
    // from some JSON-RPC clients, so we create one.
    if lRequest.IndexOfName(ParamsProperty)=-1 then
      lRequest.Add(ParamsProperty,TJSONObject.Create);
    end;
  Result:=inherited CheckRequest(Request, AClassName, AMethodName, ID, Params);
  MCPLogger.Trace('[%s] CheckRequest - end (-> %s.%s)',[ClassName,AClassName,aMethodName]);
end;

{ ---------------------------------------------------------------------
  TMCPLocalDispatcher
  ---------------------------------------------------------------------}

function TMCPLocalDispatcher.GetTransport: TMCPMessageTransport;
begin
  Result:=FTransport;
end;

function TMCPLocalDispatcher.CreateContext: TMCPContext;
begin
  Result:=TMCPContext.Create(FController);
end;

constructor TMCPLocalDispatcher.Create(aController: TMCPController);
begin
  inherited create(aController);
  FController:=aController;
  FJSONDispatcher:=TJSONRPCDispatcher.Create(Nil);
  FJSONDispatcher.Transport:=Self.Transport;
end;

destructor TMCPLocalDispatcher.Destroy;
begin
  FreeAndNil(FJSONDispatcher);
  inherited Destroy;
end;

procedure TMCPLocalDispatcher.SetTransport(const aValue: TMCPMessageTransport);
begin
  if FTransport=aValue then Exit;
  FTransport:=aValue;
end;

procedure TMCPLocalDispatcher.ProcessClientMethodResult(aResponse: TJSONObject;const aID : String;  aResult: TJSONData);
begin
  MCPLogger.Trace('[%s] ProcessClientMethodResult - start',[ClassName]);
  if Assigned(OnMethodResult) then
    OnMethodResult(Self,aResponse,aID,aResult);
  MCPLogger.Trace('[%s] ProcessClientMethodResult - end',[ClassName]);
end;

procedure TMCPLocalDispatcher.ProcessClientMethodError(aResponse: TJSONObject;
  const aID: String; aResult: TJSONData);

begin
  MCPLogger.Trace('[%s] ProcessClientMethodError - start',[ClassName]);
  if Assigned(OnMethodError) then
    OnMethodError(Self,aResponse,aID,aResult);
  MCPLogger.Trace('[%s] ProcessClientMethodError - end',[ClassName]);
end;

function TMCPLocalDispatcher.ExecuteRequest(aRequest: TJSONData): TJSONData;
var
  Obj: TJSONObject absolute aRequest;
  Idx: Integer;
  rID: String;
  Ctx : TMCPContext;

begin
  MCPLogger.Trace('[%s] Execute request - start',[ClassName]);
  Result:=nil;
  if Not (aRequest is TJSONObject) then
    Exit;
  if (Obj.Get('method','')='') then
    begin
    // We have a reply from the client to a method we executed.
    rID:='';
    Idx:=Obj.IndexOfName('id');
    if Idx<>-1 then
      rID:=Obj.Items[Idx].AsString;
    Idx:=Obj.IndexOfName('result');
    if (Idx<>-1) then
      ProcessClientMethodResult(Obj,rID,Obj.Items[Idx])
    else
      begin
      Idx:=Obj.IndexOfName('error');
      ProcessClientMethodError(Obj,rID,Obj.Items[Idx]);
      end;
    end
  else
    begin
    // We have a method call from the client to which we must reply
    Ctx:=CreateContext;
    try
      Result:=FJSONDispatcher.Execute(aRequest,Ctx);
      if Result=Nil then
        MCPLogger.Debug('[%s] Execute request - nil response ',[ClassName]);
    finally
      Ctx.Free;
    end;
    end;
  MCPLogger.Trace('[%s] Execute request - end',[ClassName]);
end;

end.

