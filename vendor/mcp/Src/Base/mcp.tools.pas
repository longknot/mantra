{
    This file is part of the Free Component Library

    MCP tool definitions
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.tools;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

{$IFNDEF VER3_2}
{$DEFINE USE_RTTI}
{$ENDIF}

interface

uses
  Classes, SysUtils, fpJSON, contnrs, syncobjs,
  {$IFDEF USE_RTTI}typinfo, rtti, fpjsonvalue,{$ENDIF}
  mcp.utils, mcp.types;

type
  TMCPToolRegistry = class;
  TMCPToolRegistryClass = class of TMCPToolRegistry;


  { TMCPTool }
  // TMCPToolContentType, TMCPToolResult, TMCPToolResultArray now in mcp.types

  TToolInvocationEvent = Procedure (aInput : TJSONData; var aOutput : TMCPToolResultArray) of object;

  TMCPTool = class abstract (TObject)
  private
    FInfo: TMCPToolInfo;
    function GetName: String;
    function GetDescription: String;
    function GetInputSchema: TMCPSchema;
    function GetOutputSchema: TMCPSchema;
    function GetAnnotations: TMCPAnnotation;
    function GetMeta: TJSONObject;
    procedure SetAnnotations(AValue: TMCPAnnotation);
    procedure SetMeta(AValue: TJSONObject);
  protected
    // Send messages to log facility
    procedure DoLog(aType : TMCPLogType; const aMessage : String);
    procedure DoLog(aType: TMCPLogType; const aFmt: String; const aArgs: array of const);
    // Override this if you need multiple content answers
    Procedure DoExecute(aInput : TJSONObject; var aResult : TMCPToolResultArray); virtual;
    // Override this if you need a single content answer
    Procedure DoExecute(aInput : TJSONObject; out aResult : TMCPToolResult); virtual;
    // Override this if you need a JSON object as answer. It will be returned as text, in JSON
    Procedure DoExecute(aInput : TJSONObject; aResult : TJSONObject); virtual;
  public
    constructor create(const aName : string; const aDescription : string); virtual;
    destructor destroy; override;
    procedure Register(aRegistry : TMCPToolRegistry = Nil);
    procedure Execute(aInput : TJSONObject; aResult : TJSONObject);
    Property Name : String read GetName;
    property Description : String Read GetDescription;
    Property InputSchema : TMCPSchema Read GetInputSchema;
    Property OutputSchema : TMCPSchema Read GetOutputSchema;
    Property Annotations : TMCPAnnotation Read GetAnnotations Write SetAnnotations;
    procedure ToJSON(aJSON : TJSONObject); virtual;
    function ToJSON() : TJSONObject;
    // Owned by the tool
    Property _Meta : TJSONObject Read GetMeta Write SetMeta;
    // Access to info object
    Property Info: TMCPToolInfo read FInfo;
  end;
  TMCPToolArray = Array of TMCPTool;

  { TMCPEventTool }

  TMCPEventTool = class(TMCPTool)
  private
    FOnExecute: TToolInvocationEvent;
  protected
    procedure DoExecute(aInput : TJSONObject; var aResult : TMCPToolResultArray); override;
    property OnExecute : TToolInvocationEvent read FOnExecute Write FOnExecute;
  Public
    constructor create(const aName,aDescription : String; aOnExecute : TToolInvocationEvent); reintroduce; virtual;
  end;

  {$IFDEF USE_RTTI}

  { TMCPCallTool }
  TMCPCallTool = class(TMCPTool)
  protected
    // Looks for a method called 'Call' and executes it. Attempts to convert the result to a single string.
    procedure DoExecute(aInput : TJSONObject; var aResult : TMCPToolResultArray); override;
    function CallResultToToolResult(aResult: TValue; aType: TRttiType): TMCPToolResultArray; virtual;
    class function JSONToValue(aData: TJSONData; aType: TRttiType): TValue;
    class function ValueToJSON(const aValue: TValue; aType: TRttiType): TJSONData;
  end;
  TMCPCallToolClass = class of TMCPCallTool;
  {$ENDIF}


  { TMCPToolRegistry }

  TMCPToolRegistry = Class(TObject)
  private
    class var _instance : TMCPToolRegistry;
    class function GetInstance: TMCPToolRegistry; static;
  private
    FList :  TThreadSafeObjectHash;
    FOnChange: TNotifyEvent;
  protected
    function GetCount: Integer; virtual;
    procedure DoChange; virtual;
  Public
    constructor Create; virtual;
    destructor destroy; override;
    // Add a Tool. Once added, the registry owns the Tool
    Procedure Add(aTool : TMCPTool); virtual;
    // Remove a Tool. The object will be freed.
    procedure Remove(const aName : String); virtual;
    procedure Remove(aTool : TMCPTool);
    procedure LockList(aList : TFPList);
    procedure LockList(var aList : TMCPToolArray);
    procedure UnlockList;
    function Find(const aName : String) : TMCPTool;
    function Get(const aName : String) : TMCPTool;
    property Tools[aName : string] : TMCPTool Read Get; default;
    Property Count : Integer Read GetCount;
    property OnChange : TNotifyEvent Read FOnChange Write FOnChange;
    class procedure Init(aClass: TMCPToolRegistryClass);
    class procedure Done;
    class property Instance : TMCPToolRegistry read GetInstance;
  end;

Function ToolRegistry : TMCPToolRegistry;

implementation

uses base64, dateutils, mcp.logging, mcp.strings;

function ToolRegistry: TMCPToolRegistry;
begin
  Result:=TMCPToolRegistry.Instance;
end;

{ TMCPTool }

function TMCPTool.GetName: String;
begin
  Result:=FInfo.Name;
end;

function TMCPTool.GetDescription: String;
begin
  Result:=FInfo.Description;
end;

function TMCPTool.GetInputSchema: TMCPSchema;
begin
  Result:=FInfo.InputSchema;
end;

function TMCPTool.GetOutputSchema: TMCPSchema;
begin
  Result:=FInfo.OutputSchema;
end;

function TMCPTool.GetAnnotations: TMCPAnnotation;
begin
  Result:=FInfo.FAnnotations;
end;

function TMCPTool.GetMeta: TJSONObject;
begin
  Result:=FInfo._Meta;
end;

procedure TMCPTool.SetAnnotations(AValue: TMCPAnnotation);
begin
  FInfo.FAnnotations:=AValue;
end;

procedure TMCPTool.SetMeta(AValue: TJSONObject);
begin
  FInfo._Meta:=AValue;
end;

procedure TMCPTool.DoLog(aType: TMCPLogType; const aMessage: String);
begin
  MCPLogger.Log(aType,'['+Self.ClassName+']: '+aMessage);
end;

procedure TMCPTool.DoLog(aType: TMCPLogType; const aFmt: String; const aArgs: array of const);
begin
  DoLog(aType,{$IFNDEF VER3_2}SafeFormat{$ELSE}Format{$ENDIF}(aFmt,aArgs));
end;

procedure TMCPTool.DoExecute(aInput: TJSONObject; var aResult: TMCPToolResultArray);
// Defaults to calling DoExecute with single argument
begin
  SetLength(aResult,1);
  DoExecute(aInput,aResult[0]);
end;

procedure TMCPTool.DoExecute(aInput: TJSONObject; out aResult: TMCPToolResult);
// Defaults to calling DoExecute with JSON output
var
  aJSON : TJSONObject;
begin
  aJSON:=TJSONObject.Create;
  try
    DoExecute(aInput,aJSON);
    if aJSON.Count>0 then
      aResult:=TMCPToolResult.CreateText(aJSON.AsJSON)
    else
      aResult:=TMCPToolResult.CreateText('OK')
  finally
    aJSON.Free;
  end;
end;

procedure TMCPTool.DoExecute(aInput: TJSONObject; aResult: TJSONObject);
// Defaults to warning
begin
  DoLog(mltWarning,'Called json-based DoExecute, and it was not overridden in '+ClassName);
end;

constructor TMCPTool.create(const aName: string; const aDescription: string);
begin
  FInfo:=TMCPToolInfo.Create(aName,aDescription);
end;

destructor TMCPTool.destroy;
begin
  FreeAndNil(FInfo);
  inherited destroy;
end;

procedure TMCPTool.Register(aRegistry: TMCPToolRegistry);
begin
  if aRegistry=Nil then
    aRegistry:=TMCPToolRegistry.Instance;
  aRegistry.Add(Self);
end;

procedure TMCPTool.Execute(aInput: TJSONObject; aResult : TJSONObject);

var
  lToolResult : TMCPToolResultArray;
  lArr : TJSONArray;
  lContent : TJSONObject;
  lResult : TMCPToolResult;

begin
  lToolResult:=[];
  DoExecute(aInput,lToolResult);
  // Format result
  lArr:=TJSONArray.Create;
  for lResult in lToolResult do
    begin
    lContent:=lResult.ToJSON;
    lArr.Add(lContent);
    end;
  aResult.Add('content',lArr);
end;

procedure TMCPTool.ToJSON(aJSON: TJSONObject);
begin
  FInfo.ToJSON(aJSON);
end;

function TMCPTool.ToJSON: TJSONObject;
begin
  Result:=FInfo.ToJSON;
end;

{ TMCPEventTool }

procedure TMCPEventTool.DoExecute(aInput: TJSONObject; var aResult: TMCPToolResultArray);
begin
  FOnExecute(aInput,aResult);
end;

constructor TMCPEventTool.create(const aName, aDescription: String;
  aOnExecute: TToolInvocationEvent);
begin
  Inherited Create(aName,aDescription);
  if aOnExecute=Nil then
    Raise EMCPException.Create('Invocation event cannot be nil');
  FOnExecute:=AOnExecute;
end;

{$IFDEF USE_RTTI}

{ TMCPCallTool }
class function TMCPCallTool.ValueToJSON(const aValue: TValue; aType: TRttiType): TJSONData;
begin
  result:={$IFDEF FPC_DOTTEDUNITS}FpJson.Value{$ELSE}fpjsonvalue{$ENDIF}.ValueToJSON(aValue,aType);
end;

class function TMCPCallTool.JSONToValue  (aData: TJSONData; aType: TRttiType): TValue;

begin
  result:={$IFDEF FPC_DOTTEDUNITS}FpJson.Value{$ELSE}fpjsonvalue{$ENDIF}.JSONToValue(aData,aType);
end;

procedure TMCPCallTool.DoExecute(aInput: TJSONObject; var aResult: TMCPToolResultArray);
var
  lMethod : TRttiMethod;
  Ctx : TRttiContext;
  lType,lResultType : TRttiType;
  lParams : specialize TArray<TRttiParameter>;
  lParam : TRttiParameter;
  lValue : TJSONData;
  lArgs: array of TValue;
  argIdx : Integer;
  lRes : TValue;
  lObj : TObject;

begin
  Ctx:=TRttiContext.Create(False);
  lType:=Ctx.GetType(Self.ClassType);
  lMethod:=lType.GetMethod('Call');
  if (lMethod=Nil) then
    Raise EMCPException.Create('No "Call" method found in MCP tool '+ClassName);
  lParams:=lMethod.GetParameters;
  argIdx:=0;
  Setlength(lArgs,Length(lParams));
  for lParam in lParams do
    begin
    if pfHidden in lParam.Flags then
      Continue
    else
      if ([pfVar,pfOut] * lParam.Flags)<>[] then
        Raise EMCPException.Create('Call method cannot have var/out params');
    lValue:=aInput.Elements[lParam.Name];
    lArgs[argidx]:=JSONToValue(lValue, lParam.ParamType);
    Inc(argidx);
    end;
  SetLength(lArgs,argidx);
  lRes:=TValue.Empty;
  lObj:=Self;
  lRes:=lMethod.Invoke(lObj,lArgs);
  lResultType:=lMethod.ReturnType;
  aResult:=CallResultToToolResult(lRes,lResultType);
end;

function TMCPCallTool.CallResultToToolResult(aResult: TValue; aType : TRttiType) : TMCPToolResultArray;

var
  S : String;
  lData : TJSONData;
  lInfo : PTypeInfo;
begin
  lInfo:=aType.Handle;
  if lInfo=TypeInfo(TMCPToolResultArray) then
    begin
    Result:=PMCPToolResultArray(aResult.GetReferenceToRawData)^;
    exit;
    end;
  if lInfo=TypeInfo(TMCPToolResult) then
    begin
    SetLength(Result,1);
    Result[0]:=PMCPToolResult(aResult.GetReferenceToRawData)^;
    exit;
    end;
  case lInfo^.Kind of
    tkString :
      S:=aResult.AsAnsiString;
    tkChar:
      S:=aResult.AsAnsiChar;
    tkAstring:
      S:=aResult.AsAnsiString;
    tkUChar:
      S:=UTF8Encode(aResult.AsWideChar);
    tkUString:
      S:=UTF8Encode(aResult.AsUnicodeString);
    tkWchar:
      S:=UTF8Encode(aResult.AsWideChar);
    tkWString:
      S:=UTF8Encode(aResult.AsUnicodeString);
    tkInteger:
      S:=IntToStr(aResult.AsInteger);
    tkInt64:
      S:=IntToStr(aResult.AsInt64);
    tkQWord:
      S:=IntToStr(aResult.AsInt64); // not so good
    tkBool:
      S:=BoolToStr(aResult.AsBoolean,'True','False');
    tkEnumeration:
      S:=GetEnumName(aType.Handle,aResult.AsOrdinal);
    tkFloat:
     begin
     if (lInfo = TypeInfo(TDateTime))
        or (lInfo = TypeInfo(TDate))
        or (lInfo = TypeInfo(TTime)) then
          begin
          S:=DateToISO8601(aResult.AsDateTime,False);
          end
     else
       begin
       Str(aResult.AsDouble,S);
       S:=TrimLeft(S);
       end;
     end;
    tkSet:
      S:=aResult.ToString;
    tkArray,
    tkDynArray:
      begin
      lData:=ValueToJSON(aResult,aType);
      try
        S:=lData.AsJSON;
      finally
        lData.Free;
      end;
      end;
    tkClass:
      begin
      if GetTypeData(lInfo)^.ClassType.InheritsFrom(TJSONData) then
        S:=TJSONData(aResult.AsObject).AsJSON
      else
        S:=aResult.AsObject.ToString;
      end;
    tkClassRef:
      S:=aResult.AsClass.ClassName;
  end;
  SetLength(Result,1);
  Result[0]:=TMCPToolResult.CreateText(S);
end;

{$ENDIF}
{ TMCPToolRegistry }

class function TMCPToolRegistry.GetInstance: TMCPToolRegistry; static;
begin
  if _instance=nil then
    _Instance:=TMCPToolRegistry.Create;
  Result:=_Instance
end;

function TMCPToolRegistry.GetCount: Integer;
begin
  Result:=FList.Count;
end;

procedure TMCPToolRegistry.DoChange;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

constructor TMCPToolRegistry.Create;
begin
  FList:=TThreadSafeObjectHash.Create(True);
end;

destructor TMCPToolRegistry.destroy;
begin
  FList.Destroy;
  inherited destroy;
end;

procedure TMCPToolRegistry.Add(aTool: TMCPTool);
begin
  MCPLogger.Info('[%s] registering tool "%s" : "%s"',[ClassName,aTool.Name,aTool.Description]);
  FList.Add(aTool.Name,aTool);
  DoChange;
end;

procedure TMCPToolRegistry.Remove(const aName: String);
begin
  MCPLogger.Info('[%s] removing tool "%s"',[ClassName,aName]);
  if FList.Get(aName)=Nil then
    exit;
  FList.Remove(aName);
  DoChange;
end;

procedure TMCPToolRegistry.Remove(aTool: TMCPTool);
begin
  Remove(aTool.Name);
end;


procedure TMCPToolRegistry.LockList(aList: TFPList);
begin
  FList.GetObjectList(aList);
end;

procedure TMCPToolRegistry.LockList(var aList: TMCPToolArray);
var
  llist : TFPList;
  I : Integer;
begin
  lList:=TFPList.Create;
  try
    FList.GetObjectList(lList);
    SetLength(aList,lList.Count);
    For I:=0 to lList.Count-1 do
      aList[i]:=TMCPTool(lList[i]);
  finally
    lList.free;
  end;
  // do not unlock.
end;

procedure TMCPToolRegistry.UnlockList;
begin
  FList.Unlock;
end;

function TMCPToolRegistry.Find(const aName: String): TMCPTool;
begin
  Result:=TMCPTool(FList.Get(aName));
end;

function TMCPToolRegistry.Get(const aName: String): TMCPTool;
begin
  Result:=Find(aName);
  if Result=Nil then
    Raise EMCPException.CreateFmt(SErrUnknownTool,[aName]);
end;

class procedure TMCPToolRegistry.Init(aClass: TMCPToolRegistryClass);
begin
  if assigned(_instance) then
    Raise EMCPException.Create(SErrRegistryALreadyInstantiated);
  if aClass=Nil then
    Raise EMCPException.Create(SErrRegistryClassEmpty);
  _Instance:=aClass.Create;
end;

class procedure TMCPToolRegistry.Done;
begin
  FreeAndNil(_instance);
end;

finalization
  TMCPToolRegistry.Done;
end.

