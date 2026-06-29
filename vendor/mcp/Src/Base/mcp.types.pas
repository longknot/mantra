{
    This file is part of the Free Component Library

    MCP basic types
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.types;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch typehelpers}

interface

uses
  SysUtils,Types, Classes, Contnrs, fpjson, mcp.utils;

Type
  EMCPClient = Class(Exception);

  { TRPCError }

  TRPCError = Record
    Code : Integer;
    Message : TJSONStringType;
    Data : TJSONStringType; // JSON
    Procedure FromJSON(aJSON : TJSONObject);
    Procedure ToJSON(aJSON : TJSONObject);
    Function IsSuccess : Boolean; Inline;
    Function IsError : Boolean; Inline;
    class Function NoError: TRPCError; static;
  end;

Type
  TMCPLogType = (mltError,mltWarning,mltInfo,mltTrace,mltDebug);
  TMCPLogTypes = set of TMCPLogType;

  TMCPLogEvent = procedure(Sender : TObject; aType : TMCPLogType; Const aMessage: string) of object;

  TMCPResourceKind = (rkUnknown,rkText,rkData);
  EMCPException = class(Exception)
    code: integer;
  end;

  { TServerInfo }

  TServerInfo = record
    name : string;
    version : string;
    procedure fromJSON(aJSON : TJSONObject);
  end;

  TServerFeature = (sfLogging,sfCompletions,sfPrompts,sfResources,sfTools,sfPromptChanges,sfResourceChanges,sfResourceSubscribe,sfToolChanges);
  TServerFeatures = set of TServerFeature;

  { TInitializeResponse }

  TMCPInitializeResponse = record
    Info : TServerInfo;
    protocol : string;
    Features : TServerFeatures;
    procedure FromJson(aJSON : TJSONObject);
  end;

  TMCPPromptKind = (pkText,pkImage,pkAudio,pkResourceLink,pkEmbeddedResource);

  { TMCPPromptKindHelper }

  TMCPPromptKindHelper = type helper for TMCPPromptKind
  private
    procedure SetAsString(AValue: String);
  public
    function toString : String;
    property AsString : String Read ToString Write SetAsString;
  end;

  TMCPRole = (prUser,prAssistant);
  TMCPRoles = set of TMCPRole;

  { TMCPRoleHelper }

  TMCPRoleHelper = type helper for TMCPRole
  private
    function ToString: String;
    procedure SetAsString(AValue: String);
  public
    property AsString : String Read ToString Write SetAsString;
  end;

  { TMCPAnnotation }

  TMCPAnnotation = record
  private
    _Roles : TMCPRoles;
    _priority : Boolean;
    _Lastmodified : TDateTime;
    _Initialized : boolean;
    procedure SetLastModified(AValue: TDateTime);
    procedure SetPriority(AValue: Boolean);
    procedure SetRoles(AValue: TMCPRoles);
  public
    class operator initialize (var rec : TMCPAnnotation);
    property Roles : TMCPRoles read _Roles write SetRoles;
    property priority : Boolean read _priority write SetPriority;
    property Lastmodified : TDateTime read _Lastmodified write SetLastModified;
    property Initialized : boolean read _Initialized;
    procedure ToJSON(aObject : TJSONObject);
    function ToJSON : TJSONObject;
    procedure FromJSON(aJSON: TJSONObject);
  end;

  { TMCPSchema }

  TMCPSchema = Class
  Private
    FArguments : TFPObjectHashTable;
    FRequired: TStringDynArray;
    function GetArgument(aName : string): TJSONObject;
  protected
    Procedure ToJSON(aJSON : TJSONObject);
    procedure AddRequired(const aName : string);
  Public
    Constructor Create;
    Destructor Destroy; override;
    Procedure Clear;
    Procedure AddArgument(aName : string; aSchema : TJSONObject; aRequired : Boolean = true); virtual;
    Function ToJSON : TJSONObject;
    Property Arguments [aName : string]  : TJSONObject Read GetArgument;
    Property Required : TStringDynArray Read FRequired;
  end;

  { TMCPToolInfo }

  TMCPToolInfo = class
  private
    FName: String;
    FDescription: String;
    FInputSchema: TMCPSchema;
    FOutputSchema: TMCPSchema;
    FMeta: TJSONObject;
    procedure SetMeta(AValue: TJSONObject);
  public
    FAnnotations: TMCPAnnotation;
    constructor Create(const aName, aDescription: string);
    destructor Destroy; override;

    property Name: String read FName write FName;
    property Description: String read FDescription write FDescription;
    property InputSchema: TMCPSchema read FInputSchema;
    property OutputSchema: TMCPSchema read FOutputSchema;
    property Annotations: TMCPAnnotation read FAnnotations write FAnnotations;
    property _Meta: TJSONObject read FMeta write SetMeta;

    procedure ToJSON(aJSON: TJSONObject);
    function ToJSON: TJSONObject;
    procedure FromJSON(aJSON: TJSONObject);
  end;

  TMCPToolInfoList = class(specialize TGFPObjectList<TMCPToolInfo>)
  public
    procedure ToJSON(aJSON: TJSONArray);
    function ToJSON: TJSONArray;
    procedure FromJSON(aJSON: TJSONArray);
  end;

  { Forward declarations for prompt info }
  TPromptArgument = record
    Name : string;
    Description : string;
    Required : boolean;
    constructor Create(const aName: String; const aDescription : String; aRequired : Boolean = true);
    procedure ToJSON(aJSON: TJSONObject);
    function ToJSON : TJSONObject;
  end;
  TPromptArgumentArray = array of TPromptArgument;

  { TMCPPromptInfo }
  TMCPPromptInfo = Record
  private
    FName: string;
    FTitle: string;
    FDescription: string;
    FArguments: TPromptArgumentArray;
    function GetArgument(aIndex: integer): TPromptArgument;
    function GetArgumentCount: integer;
    procedure SetName(const AValue: String);
  public
    constructor Create(const aName, aTitle: String; aDescription: String = '');
    procedure AddArgument(const aName, aDescription: String; aRequired: Boolean = true);
    procedure AddArgument(const aArgument: TPromptArgument);
    procedure ToJSON(aJSON: TJSONObject);
    function ToJSON: TJSONObject;
    procedure FromJSON(aJSON: TJSONObject);
    property Name: string read FName write SetName;
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property Arguments[aIndex: integer]: TPromptArgument read GetArgument;
    property ArgumentCount: integer read GetArgumentCount;
  end;

  TMCPPromptInfoArray = array of TMCPPromptInfo;

  { TMCPPromptInfoArrayHelper }

  TMCPPromptInfoArrayHelper = type helper for TMCPPromptInfoArray
    procedure ToJSON(aJSON: TJSONArray);
    function ToJSON: TJSONArray;
    procedure FromJSON(aJSON: TJSONArray);
    function Count : Integer;
  end;

  { TMCPResourceInfo }

  TMCPResourceInfo = Record
  private
    FData: TBytes;
    FKind: TMCPResourceKind;
    FMimeType: string;
    FName: string;
    FText: String;
    FTitle: string;
    FDescription: string;
    FUri: String;
    FSize: Integer;
    procedure SetData(AValue: TBytes);
    procedure SetText(AValue: String);
    procedure SetUri(AValue: String);
    procedure SetSize(AValue: Integer);
  public
    constructor Create(const aURI, aName: String);
    // Clears everything
    procedure Free;
    procedure Clear;
    function GetSize: Integer;
    function GetKind: TMCPResourceKind;
    procedure SetKind(AValue: TMCPResourceKind);

    property Uri: String read FUri write SetUri;
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property MimeType: string read FMimeType write FMimeType;
    property Name: string read FName write FName;
    property Text: String read FText write SetText;
    property Data: TBytes read FData write SetData;
    property Size: Integer read GetSize write SetSize;
    property Kind: TMCPResourceKind read FKind;

    procedure ToJSON(aJSON: TJSONObject; withData: Boolean);
    function ToJSON(withData: Boolean): TJSONObject;
    procedure FromJSON(aJSON: TJSONObject);
  end;

  TMCPResourceInfoArray = Array of TMCPResourceInfo;

//  TMCPResourceInfoList = class(specialize TGFPObjectList<TMCPResourceInfo>)

  { TMCPResourceInfoArrayHelper }

  TMCPResourceInfoArrayHelper = Type helper for TMCPResourceInfoArray
    procedure ToJSON(aJSON: TJSONArray; withData: Boolean = True);
    function ToJSON(withData: Boolean = True): TJSONArray;
    procedure FromJSON(aJSON: TJSONArray);
    function Count : Integer;
  end;

  { Tool Result Types - Shared between client and server }

  TMCPToolContentType = (ctText,ctImage,ctAudio,ctResource);

  { TMCPToolResult }

  TMCPToolResult = record
    ContentType : TMCPToolContentType;
    MimeType : string;
    Content: string; // uri in case of resource
    Description : String;
    constructor CreateText(aText : string);
    constructor CreateText(aJSON : TJSONObject);
    constructor CreateImage(aMime : string; aData : TBytes);
    constructor CreateImage(aMime : string; aData : TStream);
    constructor CreateAudio(aMime : string; aData : TBytes);
    constructor CreateAudio(aMime : string; aData : TStream);
    constructor CreateResource(aURI,aMime,aDescription : string);
    procedure ToJSON(aJSON : TJSONObject);
    function ToJSON : TJSONObject;
    procedure FromJSON(aJSON: TJSONObject);
    procedure Clear;
  end;
  PMCPToolResult = ^TMCPToolResult;

  { TMCPProtocolLogLevel }

  TMCPProtocolLogLevel = (
    mclError,    // error
    mclWarn,     // warn
    mclInfo,     // info
    mclDebug     // debug
  );

  { Type helper for TMCPProtocolLogLevel }

  TMCPProtocolLogLevelHelper = type helper for TMCPProtocolLogLevel
    function AsString: string;
    class function FromString(const aStr: string): TMCPProtocolLogLevel; static;
  end;


  TMCPToolResultArray = Array of TMCPToolResult;
  PMCPToolResultArray = ^TMCPToolResultArray;

  // Var arguments that are classes: The caller frees the argument if the callee didn't set it to nil.
  TListToolsResponseEvent = procedure (aSender: TObject; var aList: TMCPToolInfoList; const aError : TRPCError) of object;
  TPromptListResponseEvent = procedure (aSender: TObject; aList: TMCPPromptInfoArray; const aError : TRPCError) of object;
  TResourceListResponseEvent = procedure (aSender: TObject; aList: TMCPResourceInfoArray; const aError : TRPCError) of object;
  TOnInitializeEvent = procedure(const aResponse : TMCPInitializeResponse; aError : TRPCError) of object;
  TGetResourceResponseEvent = procedure (aSender: TObject; constref aResource: TMCPResourceInfo; const aError : TRPCError) of object;
  TCompletionCompleteEvent = procedure(aSender: TObject; const aResponse: TJSONObject; const aError : TRPCError) of object;
  TSetLogLevelEvent = procedure(aSender: TObject; const aResponse: TJSONObject; const aError : TRPCError) of object;
  TToolCallEvent = procedure(aSender: TObject; const aResponse: TJSONObject; const aError : TRPCError) of object;


implementation

uses typinfo,dateutils, mcp.strings, base64;

{ TMCPPromptKindHelper }

procedure TMCPPromptKindHelper.SetAsString(AValue: String);
var
  K : TMCPPromptKind;
begin
  if ToString=AValue then Exit;
  for K in TMCPPromptKind do
    if K.AsString=aValue then
      begin
      Self:=k ;
      exit;
      end;
end;

function TMCPPromptKindHelper.toString: String;
const
  names : Array[TMCPPromptKind] of string = ('text','image','audio','resource_link','resource');

begin
  Result:=Names[self];
end;

{ TMCPRoleHelper }

function TMCPRoleHelper.ToString: String;
begin
  Case Self of
    prUser : Result:='user';
    prAssistant : Result:='assistant';
  end;
end;

procedure TMCPRoleHelper.SetAsString(AValue: String);
begin
  case aValue of
  'user' : Self:=prUser;
  'assistant' : self:=prAssistant;
  else
    Raise EMCPException.CreateFmt('Invalid role: %s',[aValue]);
  end;
end;

{ TMCPAnnotation }

procedure TMCPAnnotation.SetPriority(AValue: Boolean);
begin
  if _priority=AValue then Exit;
  _priority:=AValue;
  _Initialized:=True;
end;

procedure TMCPAnnotation.SetLastModified(AValue: TDateTime);
begin
  if _Lastmodified=AValue then Exit;
  _Lastmodified:=AValue;
  _initialized:=True;
end;

procedure TMCPAnnotation.SetRoles(AValue: TMCPRoles);
begin
  if _Roles=AValue then Exit;
  _Roles:=AValue;
  _Initialized:=True;
end;

class operator TMCPAnnotation.initialize(var rec: TMCPAnnotation);
begin
  Rec:=Default(TMCPAnnotation);
end;

procedure TMCPAnnotation.ToJSON(aObject: TJSONObject);
var
  arr : TJSONArray;
  lRole : TMCPRole;

begin
  if _Roles<>[] then
    begin
    arr:=TJSONArray.Create;
    aObject.Add('roles',arr);
    for lRole in _Roles do
      Arr.Add(lRole.ToString);
    end;
  aObject.Add('priority',Ord(_priority));
  if _Lastmodified<>0 then
    aObject.Add('lastModified',DateToISO8601(_Lastmodified));
end;

function TMCPAnnotation.ToJSON: TJSONObject;
begin
  Result:=Nil;
  if Initialized then
    try
      Result:=TJSONObject.Create;
      ToJSON(Result);
    except
      Result.Free;
      Raise;
    end;
end;

procedure TMCPAnnotation.FromJSON(aJSON: TJSONObject);
var
  lArr : TJSONArray;
  lRole : TMCPRole;
  lDate : string;
  I : Integer;
begin
  lRole:=Default(TMCPRole);
  _Initialized:=True;
  if not assigned(aJSON) then
    exit;
  lArr:=aJSON.Get('roles',TJSONArray(Nil));
  if assigned(lArr) then
    begin
    for I:=0 to lArr.Count-1 do
      begin
      lRole.AsString:=lArr.Items[i].AsString;
      Include(_roles,lRole);
      end;
    end;
  priority:=aJSON.get('priority',1)=1;
  lDate:=aJSON.get('lastModified','');
  if lDate<>'' then
    _Lastmodified:=ISO8601ToDate(lDate);
end;

{ TMCPSchema }

function TMCPSchema.GetArgument(aName : string): TJSONObject;
begin
  Result:=FArguments[aName] as TJSONObject;
end;

type
  { TArgumentLister }

  TArgumentLister = class(TObject)
    FJSON : TJSONObject;
    constructor Create(aJSON : TJSONObject) ;
    procedure ListArg(Item: TObject; const Key: string; var Continue: Boolean);
  end;

{ TArgumentLister }

constructor TArgumentLister.Create(aJSON: TJSONObject);
begin
  FJSON:=aJSON;
end;

procedure TArgumentLister.ListArg(Item: TObject; const Key: string;
  var Continue: Boolean);
begin
  Continue:=True;
  FJSON.Add(Key,TJSONData(Item).Clone);
end;


procedure TMCPSchema.ToJSON(aJSON: TJSONObject);
var
  lList : TArgumentLister;
  lProps : TJSONObject;
  lReq: TJSONArray;
  S : String;
begin
  aJSON.Add('type','object');
  lProps:=TJSONObject.Create;
  lList:=TArgumentLister.Create(lProps);
  try
    FArguments.Iterate(@lList.ListArg);
  finally
    lList.Free;
  end;
  if lProps.Count=0 then
    lProps.Free
  else
    begin
    aJSON.Add('properties',lProps);
    if Length(FRequired)>0 then
      begin
      lReq:=TJSONArray.Create;
      aJSON.Add('required',lReq);
      For S in FRequired do
        lReq.Add(s);
      end;
    end;
end;

constructor TMCPSchema.Create;
begin
  FArguments:=TFPObjectHashTable.Create(True);
end;

destructor TMCPSchema.Destroy;
begin
  FreeAndNil(FArguments);
  inherited Destroy;
end;

procedure TMCPSchema.Clear;
begin
  FArguments.Clear;
  FRequired:=[];
end;

procedure TMCPSchema.AddArgument(aName: string; aSchema: TJSONObject;
  aRequired: Boolean);
begin
  FArguments.Add(aName,aSchema);
  if aRequired then
    AddRequired(aName);
end;

procedure TMCPSchema.AddRequired(const aName: string);
var
  S : String;
  Len: Integer;
begin
  For S in FRequired do
    if aName=S then
      exit;
   len:=Length(FRequired);
   SetLength(FRequired,Len+1);
   FRequired[len]:=aName;
end;

function TMCPSchema.ToJSON: TJSONObject;
begin
  Result:=TJSONObject.Create();
  try
    ToJSON(Result);
  except
    Result.Free;
    Raise;
  end;
end;

{ TMCPToolInfo }

procedure TMCPToolInfo.SetMeta(AValue: TJSONObject);
begin
  if FMeta=AValue then Exit;
  FreeAndNil(FMeta);
  FMeta:=AValue;
end;

constructor TMCPToolInfo.Create(const aName, aDescription: string);
begin
  FInputSchema:=TMCPSchema.Create;
  FOutputSchema:=TMCPSchema.Create;
  FName:=aName;
  FDescription:=aDescription;
end;

destructor TMCPToolInfo.Destroy;
begin
  _Meta:=Nil;
  FreeAndNil(FInputSchema);
  FreeAndNil(FOutputSchema);
  inherited Destroy;
end;

procedure TMCPToolInfo.ToJSON(aJSON: TJSONObject);
var
  Anns : TJSONObject;
begin
  aJSON.Add('name',Name);
  aJSON.Add('description',Description);
  Anns:=FAnnotations.ToJSON;
  if assigned(Anns) then
    aJSON.Add('annotations',Anns);
  aJSON.Add('inputSchema',InputSchema.ToJSON);
end;

function TMCPToolInfo.ToJSON: TJSONObject;
begin
  Result:=TJSONObject.Create;
  try
    ToJSON(Result);
  except
    Result.Free;
    Raise;
  end;
end;

procedure TMCPToolInfo.FromJSON(aJSON: TJSONObject);

var
  AnnotationsJSON, InputSchemaJSON, PropertiesJSON, RequiredArray: TJSONData;
  i, j: Integer;
  RequiredName: String;
  RequiredNames: array of String;
  ArgJSON: TJSONObject;
  IsRequired: Boolean;

begin
  if not Assigned(aJSON) then
    Exit;

  FName:=aJSON.Get('name', '');
  FDescription:=aJSON.Get('description', '');

  AnnotationsJSON:=aJSON.Find('annotations');
  if Assigned(AnnotationsJSON) and (AnnotationsJSON is TJSONObject) then
    FAnnotations.FromJSON(AnnotationsJSON as TJSONObject);

  InputSchemaJSON:=aJSON.Find('inputSchema');
  if Not (Assigned(InputSchemaJSON) and (InputSchemaJSON is TJSONObject)) then
    exit;

  FInputSchema.Clear;
  RequiredNames:=[];
  RequiredArray:=(InputSchemaJSON as TJSONObject).Find('required');
  if Assigned(RequiredArray) and (RequiredArray is TJSONArray) then
    begin
    SetLength(RequiredNames, (RequiredArray as TJSONArray).Count);
    for i:=0 to (RequiredArray as TJSONArray).Count - 1 do
      RequiredNames[i]:=(RequiredArray as TJSONArray).Items[i].AsString;
    end;

  PropertiesJSON:=(InputSchemaJSON as TJSONObject).Find('properties');
  if Assigned(PropertiesJSON) and (PropertiesJSON is TJSONObject) then
    begin
    for i:=0 to (PropertiesJSON as TJSONObject).Count - 1 do
      begin
      RequiredName:=(PropertiesJSON as TJSONObject).Names[i];
      IsRequired:=False;
      for j:=0 to Length(RequiredNames) - 1 do
        begin
        if RequiredName = RequiredNames[j] then
          begin
          IsRequired:=True;
          Break;
          end;
        end;
      // Clone the argument JSON
      ArgJSON:=(PropertiesJSON as TJSONObject).Items[i].Clone as TJSONObject;
      FInputSchema.AddArgument(RequiredName, ArgJSON, IsRequired);
      end;
    end;
end;

{ TMCPResourceInfo }

procedure TMCPResourceInfo.SetData(AValue: TBytes);
begin
  if FData = AValue then Exit;
  FData:=AValue;
  FText:='';
  FKind:=rkData;
end;

procedure TMCPResourceInfo.SetText(AValue: String);
begin
  if FText = AValue then Exit;
  FText:=AValue;
  FData:=nil;
  FKind:=rkText;
end;

procedure TMCPResourceInfo.SetUri(AValue: String);
begin
  if FUri = AValue then Exit;
  if aValue = '' then
    raise EMCPException.Create(SErrUriCannotBeEmpty);
  FUri:=aValue;
end;

procedure TMCPResourceInfo.SetSize(AValue: Integer);
begin
  FSize:=AValue;
end;

procedure TMCPResourceInfo.SetKind(AValue: TMCPResourceKind);
begin
  FKind:=AValue;
end;

constructor TMCPResourceInfo.Create(const aURI, aName: String);
begin
  Self:=Default(TMCPResourceInfo);
  Uri:=aURI;
  Name:=aName;
end;

procedure TMCPResourceInfo.Free;
begin
  Clear;
end;

procedure TMCPResourceInfo.Clear;
begin
  Self:=Default(TMCPResourceInfo);
end;


function TMCPResourceInfo.GetSize: Integer;
begin
  Result:=0;
  if FSize <> 0 then
    Result:=FSize
  else if Kind = rkData then
    Result:=Length(FData)
  else if Kind = rkText then
    Result:=Length(FText);
end;

function TMCPResourceInfo.GetKind: TMCPResourceKind;
begin
  Result:=FKind;
end;

procedure TMCPResourceInfo.ToJSON(aJSON: TJSONObject; withData: Boolean);
var
  lData: string;
begin
  aJSON.Add('uri', FUri);
  aJSON.Add('name', Name);
  aJSON.Add('title', Title);
  aJSON.Add('description', Description);
  aJSON.Add('mimetype', MimeType);
  if not withData then
    exit;
  case Kind of
    rkText:
      lData:=Text;
    rkData:
      lData:=EncodeBytes(Self.Data);
  end;
  aJSON.Add('text', lData);
end;

function TMCPResourceInfo.ToJSON(withData: Boolean): TJSONObject;
begin
  Result:=TJSONObject.Create;
  try
    ToJSON(Result, withData);
  except
    Result.Free;
    raise;
  end;
end;

procedure TMCPResourceInfo.FromJSON(aJSON: TJSONObject);

var
  textData: String;

begin
  if not Assigned(aJSON) then
    Exit;
  FUri:=aJSON.Get('uri', '');
  FName:=aJSON.Get('name', '');
  FTitle:=aJSON.Get('title', '');
  FDescription:=aJSON.Get('description', '');
  FMimeType:=aJSON.Get('mimetype', '');

  textData:=aJSON.Get('text', '');
  if textData <> '' then
    begin
    // For now, assume it's text data unless we can detect it's encoded binary
    if (FMimeType <> '') and (Pos('text/', FMimeType) = 1) then
      Text:=textData
    else
      try
        Data:=DecodeBytes(textData);
      except
        // If decoding fails, treat as text
        Text:=textData;
      end;
    end;
end;

{ TPromptArgument }

constructor TPromptArgument.Create(const aName: String; const aDescription: String;
  aRequired: Boolean);
begin
  Name:=aName;
  Description:=aDescription;
  Required:=aRequired;
end;

procedure TPromptArgument.ToJSON(aJSON: TJSONObject);
begin
  aJSON.Add('name', Name);
  aJSON.Add('description', Description);
  aJSON.Add('required', Required);
end;

function TPromptArgument.ToJSON: TJSONObject;
begin
  Result:=TJSONObject.Create;
  try
    ToJSON(Result);
  except
    Result.Free;
    raise;
  end;
end;

{ TMCPPromptInfo }

constructor TMCPPromptInfo.Create(const aName, aTitle: String; aDescription: String);
begin
  Self:=Default(TMCPPromptInfo);
  Name:=aName;
  FTitle:=aTitle;
  FDescription:=aDescription;
end;

function TMCPPromptInfo.GetArgument(aIndex: integer): TPromptArgument;
begin
  Result:=FArguments[aIndex];
end;

function TMCPPromptInfo.GetArgumentCount: integer;
begin
  Result:=Length(FArguments);
end;

procedure TMCPPromptInfo.SetName(const AValue: String);
begin
  if aValue = '' then
    raise EMCPException.Create(SErrPromptNameRequired);
  FName:=aValue;
end;

procedure TMCPPromptInfo.AddArgument(const aName, aDescription: String;
  aRequired: Boolean);
begin
  AddArgument(TPromptArgument.Create(aName, aDescription, aRequired));
end;

procedure TMCPPromptInfo.AddArgument(const aArgument: TPromptArgument);
var
  Len: Integer;
begin
  Len:=Length(FArguments);
  SetLength(FArguments, Len + 1);
  FArguments[Len]:=aArgument;
end;

procedure TMCPPromptInfo.ToJSON(aJSON: TJSONObject);
var
  Arr: TJSONArray;
  I: Integer;
begin
  aJSON.Add('name', Name);
  aJSON.Add('title', Title);
  aJSON.Add('description', Description);
  Arr:=TJSONArray.Create;
  aJSON.Add('arguments', Arr);
  for I:=0 to Length(FArguments) - 1 do
    Arr.Add(FArguments[I].ToJSON);
end;

function TMCPPromptInfo.ToJSON: TJSONObject;
begin
  Result:=TJSONObject.Create;
  try
    ToJSON(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TMCPPromptInfo.FromJSON(aJSON: TJSONObject);
var
  ArgsArray: TJSONArray;
  ArgObj: TJSONObject;
  I: Integer;
  Arg: TPromptArgument;
begin
  if not Assigned(aJSON) then
    Exit;
  SetLength(FArguments, 0);
  FName:=aJSON.Get('name', '');
  FTitle:=aJSON.Get('title', '');
  FDescription:=aJSON.Get('description', '');
  ArgsArray:=aJSON.Get('arguments', TJSONArray(nil));
  if Assigned(ArgsArray) then
    begin
    SetLength(FArguments, ArgsArray.Count);
    for I:=0 to ArgsArray.Count - 1 do
      begin
      if ArgsArray[I] is TJSONObject then
        begin
        ArgObj:=TJSONObject(ArgsArray[I]);
        Arg.Name:=ArgObj.Get('name', '');
        Arg.Description:=ArgObj.Get('description', '');
        Arg.Required:=ArgObj.Get('required', True);
        FArguments[I]:=Arg;
        end;
      end;
    end;
end;

{ TMCPToolInfoList }

procedure TMCPToolInfoList.ToJSON(aJSON: TJSONArray);
var
  I: Integer;
begin
  for I:=0 to Count - 1 do
    aJSON.Add(Elements[I].ToJSON);
end;

function TMCPToolInfoList.ToJSON: TJSONArray;
begin
  Result:=TJSONArray.Create;
  try
    ToJSON(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TMCPToolInfoList.FromJSON(aJSON: TJSONArray);
var
  I: Integer;
  ToolInfo: TMCPToolInfo;
  ItemObj: TJSONObject;
begin
  if not Assigned(aJSON) then
    Exit;
  Clear;
  for I:=0 to aJSON.Count - 1 do
    begin
    if aJSON[I] is TJSONObject then
      begin
      ItemObj:=TJSONObject(aJSON[I]);
      ToolInfo:=TMCPToolInfo.Create('', ''); // Will be set by FromJSON
      try
        ToolInfo.FromJSON(ItemObj);
        Add(ToolInfo);
      except
        ToolInfo.Free;
        raise;
      end;
      end;
    end;
end;

{ TMCPPromptInfoList }

procedure TMCPPromptInfoArrayHelper.ToJSON(aJSON: TJSONArray);
var
  I: Integer;
begin
  for I:=0 to Length(Self)- 1 do
    aJSON.Add(Self[I].ToJSON);
end;

function TMCPPromptInfoArrayHelper.ToJSON: TJSONArray;

begin
  Result:=TJSONArray.Create;
  try
    ToJSON(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TMCPPromptInfoArrayHelper.FromJSON(aJSON: TJSONArray);
var
  I,aCount: Integer;
  PromptInfo: TMCPPromptInfo;
  ItemObj: TJSONObject;

begin
  if not Assigned(aJSON) then
    Exit;
  SetLength(Self,aJSON.Count);
  aCount:=0;
  for I:=0 to aJSON.Count - 1 do
    begin
    if aJSON[I] is TJSONObject then
      begin
      ItemObj:=TJSONObject(aJSON[I]);
      Self[aCount]:=Default(TMCPPromptInfo);
      Self[aCount].FromJSON(ItemObj);
      inc(aCount);
      end;
    end;
  SetLength(Self,aCount);
end;

function TMCPPromptInfoArrayHelper.Count: Integer;
begin
  Result:=Length(Self);
end;

{ TMCPResourceInfoList }

procedure TMCPResourceInfoArrayHelper.ToJSON(aJSON: TJSONArray; withData: Boolean);
var
  I: Integer;
begin
  for I:=0 to Length(Self) - 1 do
    aJSON.Add(Self[I].ToJSON(withData));
end;

function TMCPResourceInfoArrayHelper.ToJSON(withData: Boolean): TJSONArray;
begin
  Result:=TJSONArray.Create;
  try
    ToJSON(Result, withData);
  except
    Result.Free;
    raise;
  end;
end;

procedure TMCPResourceInfoArrayHelper.FromJSON(aJSON: TJSONArray);
var
  I,aCount: Integer;
  ItemObj: TJSONObject;
begin
  if not Assigned(aJSON) then
    Exit;
  SetLength(Self,aJSON.Count);
  aCount:=0;
  for I:=0 to aJSON.Count - 1 do
    begin
    if aJSON[I] is TJSONObject then
      begin
      ItemObj:=TJSONObject(aJSON[I]);
      Self[aCount]:=Default(TMCPResourceInfo);
      Self[aCount].FromJSON(ItemObj);
      inc(aCount);
      end;
    end;
  SetLength(Self,aCount);
end;

function TMCPResourceInfoArrayHelper.Count: Integer;
begin
  Result:=Length(Self);
end;

{ Helper functions for TMCPToolResult }

function StreamToBase64(aStream : TStream) : String;
var
  Enc : TBase64EncodingStream;
  S : TStringStream;
begin
  Enc:=Nil;
  S:=TStringStream.Create;
  try
    Enc:=TBase64EncodingStream.Create(S);
    Enc.CopyFrom(aStream,0);
    Enc.Flush;
    Result:=S.DataString;
  finally
    Enc.Free;
    S.Free;
  end;
end;

function BytesToBase64(aBytes : TBytes) : String;
var
  Enc : TBase64EncodingStream;
  S : TStringStream;
begin
  Enc:=Nil;
  S:=TStringStream.Create;
  try
    Enc:=TBase64EncodingStream.Create(S);
    Enc.WriteBuffer(aBytes[0],length(aBytes));
    Enc.Flush;
    Result:=S.DataString;
  finally
    Enc.Free;
    S.Free;
  end;
end;

{ TMCPToolResult }

constructor TMCPToolResult.CreateText(aText: string);
begin
  ContentType:=ctText;
  Content:=aText;
  MimeType:='text/plain';
end;

constructor TMCPToolResult.CreateText(aJSON: TJSONObject);
begin
  ContentType:=ctText;
  Content:=aJSON.AsJSON;
  MimeType:='text/plain';
end;

constructor TMCPToolResult.CreateImage(aMime: string; aData: TBytes);
begin
  ContentType:=ctImage;
  MimeType:=aMime;
  Content:=BytesToBase64(aData);
end;

constructor TMCPToolResult.CreateImage(aMime: string; aData: TStream);
begin
  ContentType:=ctImage;
  MimeType:=aMime;
  Content:=StreamToBase64(aData);
end;

constructor TMCPToolResult.CreateAudio(aMime: string; aData: TBytes);
begin
  ContentType:=ctAudio;
  MimeType:=aMime;
  Content:=BytesToBase64(aData);
end;

constructor TMCPToolResult.CreateAudio(aMime: string; aData: TStream);
begin
  ContentType:=ctAudio;
  MimeType:=aMime;
  Content:=StreamToBase64(aData);
end;

constructor TMCPToolResult.CreateResource(aURI, aMime, aDescription: string);
begin
  ContentType:=ctResource;
  MimeType:=aMime;
  Content:=aURI;
  Description:=aDescription;
end;

procedure TMCPToolResult.ToJSON(aJSON: TJSONObject);
const
  ResTypes : array[TMCPToolContentType] of string = ('text','image','audio','resource');
begin
  aJSON.Add('type',ResTypes[ContentType]);
  case ContentType of
    ctText :
      aJSON.Add('text',Content);
    ctAudio,
    ctImage :
      begin
      aJSON.Add('mimeType',mimeType);
      aJSON.Add('data',Content);
      end;
    ctResource:
      begin
      aJSON.Add('resource',TJSONObject.Create([
        'uri',Content,
        'mimeType',mimeType,
        'text',Description
      ]));
      end;
  end;
end;

function TMCPToolResult.ToJSON: TJSONObject;
begin
  Result:=TJSONObject.Create;
  try
    ToJSON(Result);
  except
    Result.Free;
    Raise;
  end;
end;

procedure TMCPToolResult.FromJSON(aJSON: TJSONObject);

const
  ResTypes : array[TMCPToolContentType] of string = ('text','image','audio','resource');
var
  TypeStr: string;
  i: TMCPToolContentType;
  ResourceObj: TJSONObject;
begin
  if not Assigned(aJSON) then
    Exit;
  TypeStr:=aJSON.Get('type', '');
  ContentType:=ctText; // Default

  for i:=Low(TMCPToolContentType) to High(TMCPToolContentType) do
    if ResTypes[i] = TypeStr then
      begin
      ContentType:=i;
      Break;
      end;

  case ContentType of
    ctText:
      begin
      Content:=aJSON.Get('text', '');
      MimeType:='text/plain';
      Description:='';
      end;
    ctImage, ctAudio:
      begin
      Content:=aJSON.Get('data', '');
      MimeType:=aJSON.Get('mimeType', '');
      Description:='';
      end;
    ctResource:
      begin
      ResourceObj:=aJSON.Get('resource', TJSONObject(nil));
      if Assigned(ResourceObj) then
        begin
        Content:=ResourceObj.Get('uri', '');
        MimeType:=ResourceObj.Get('mimeType', '');
        Description:=ResourceObj.Get('text', '');
        end;
      end;
  end;
end;

procedure TMCPToolResult.Clear;
begin
  ContentType:=ctText;
  MimeType:='';
  Content:='';
  Description:='';
end;

{ TMCPProtocolLogLevelHelper }

function TMCPProtocolLogLevelHelper.AsString: string;
begin
  case Self of
    mclError: Result:='error';
    mclWarn: Result:='warn';
    mclInfo: Result:='info';
    mclDebug: Result:='debug';
  else
    Result:='error'; // Default fallback
  end;
end;

class function TMCPProtocolLogLevelHelper.FromString(const aStr: string): TMCPProtocolLogLevel;
var
  lStr: string;
begin
  lStr:=LowerCase(aStr);
  if lStr = 'error' then Result:=mclError
  else if lStr = 'warn' then Result:=mclWarn
  else if lStr = 'info' then Result:=mclInfo
  else if lStr = 'debug' then Result:=mclDebug
  else Result:=mclError; // Default fallback
end;

{ TServerInfo }

procedure TServerInfo.fromJSON(aJSON: TJSONObject);
begin
  with aJSON do
    begin
    name:=get('name','');
    version:=get('version','');
    end;
end;

{ TInitializeResponse }

procedure TMCPInitializeResponse.FromJson(aJSON: TJSONObject);

  function checkavailable(aCaps : TJSONObject; aFeature : string; aAvailable : TServerFeature; aChanges : TServerFeature) : boolean;
  var
    lTmp : TJSONObject;
  begin
    Result:=assigned(aCaps);
    if result then
      ltmp:=aCaps.get(aFeature,TJSONObject(Nil));
    Result:=Result and Assigned(lTmp);
    if result then
      begin
      Include(Features,aAvailable);
      if lTmp.Get('listChanged',false) then
        Include(Features,aChanges);
      end;
  end;

var
  lCaps : TJSONObject;

begin
  lCaps:=aJSON.get('serverInfo',TJSONObject(nil));
  if assigned(lCaps) then
    Info.fromJSON(lCaps);
  protocol:=aJSON.Get('protocol','');
  lCaps:=aJSON.get('capabilities',TJSONObject(nil));
  checkavailable(lCaps,'prompts',sfPrompts,sfPromptChanges);
  if checkavailable(lCaps,'resources',sfResources,sfResourceChanges) then
    if lCaps.Get('resources',TJSONObject(Nil)).Get('subscribe',false) then
      include(Features,sfResourceSubscribe);
  checkAvailable(lCaps,'tools',sfTools,sfToolChanges);
  checkAvailable(lCaps,'logging',sfLogging,sfLogging);
  checkAvailable(lCaps,'completions',sfCompletions,sfCompletions);
end;

{ TRPCError }

procedure TRPCError.FromJSON(aJSON: TJSONObject);

var
  D : TJSONData;

begin
  D:=aJSON.Find('code');
  if not assigned(D) or (D.JSONType=jtNull) then
    Code:=0
  else if D.JSONType<>jtNumber then
    Raise EJSON.Create('Code is not a number')
  else
    Code:=aJSON.Get('code',0);
  D:=aJSON.Find('message');
  if not assigned(D) or (D.JSONType=jtNull) then
    Message:=''
  else if D.JSONType<>jtString then
    Raise EJSON.Create('Message is not a string')
  else
    Message:=aJSON.Get('message','');
  D:=aJSON.Find('data');
  if Assigned(D) then
    Data:=D.AsJSON
  else
    Data:='';
end;

procedure TRPCError.ToJSON(aJSON: TJSONObject);

Var
  D : TJSONData;

begin
  if not Assigned(aJSON) then
    Raise Exception.Create('Need JSON object');
  aJSON.Integers['code']:=Code;
  aJSON.Strings['message']:=Message;
  if Data<>'' then
    begin
    D:=GetJSON(Data);
    aJSON.Elements['data']:=D;
    end;
end;

function TRPCError.IsSuccess: Boolean;
begin
  Result:=(Code=0)
end;

function TRPCError.IsError: Boolean;
begin
  Result:=Code<>0;
end;

class function TRPCError.NoError: TRPCError;
begin
  Result:=Default(TRPCError);
end;


end.
