{
    This file is part of the Free Component Library

    MCP Prompt definitions
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.prompts;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch typehelpers}

interface

uses
  Classes, SysUtils, types, syncobjs, contnrs, fpjson, mcp.utils, mcp.types, mcp.resources;

type
  { TMCPPrompt }
  TMCPPrompt = class;
  TMCPPromptRegistry = class;
  TMCPPromptRegistryClass = Class of TMCPPromptRegistry;
  TMCPPromptArray = array of TMCPPrompt;

{ TMCPPrompt }

  { TMCPPromptMessage }

  TMCPPromptMessage = record
    kind : TMCPPromptKind;
    role : TMCPRole;
    data : TBytes;
    ResourceURI : String;
    mimeType : String;
    textcontent : string;
    _meta : TJSONObject; // Will be freed !
    Annotations : TMCPAnnotation;
    constructor createtext(aRole : TMCPRole; const aText : String);
    constructor createImage(aRole : TMCPRole; aImage : TBytes; const aMimeType : String);
    constructor createAudio(aRole : TMCPRole; aImage : TBytes; const aMimeType : String);
    constructor createResourceLink(aRole : TMCPRole; aURI : String);
    constructor createEmbeddedResource(aRole : TMCPRole; aURI : String);

    procedure ToJSON(aJSON: TJSONObject; aResources : TMCPResourceRegistry);
    function ToJSON(aResources : TMCPResourceRegistry): TJSONObject;
  end;
  TMCPPromptMessageArray = array of TMCPPromptMessage;

  { TMCPPromptMessageArrayHelper }

  TMCPPromptMessageArrayHelper = type helper for TMCPPromptMessageArray
    procedure ToJSON(aJSON: TJSONArray; aResources: TMCPResourceRegistry);
    function ToJSON(aResources: TMCPResourceRegistry): TJSONArray;
  end;

  TMCPPromptCompletionEvent = Procedure(Sender: TMCPPrompt; Const aArgName : string ; aPreviousCompletions, aCompletions : TStrings) of object;
  TMCPPrompt = Class(TObject)
  private
    FInfo: TMCPPromptInfo;
    FOnCompletion: TMCPPromptCompletionEvent;
    function GetArgument(aIndex : integer): TPromptArgument;
    function GetArgumentCount: integer;
    function GetName: String;
    function GetTitle: String;
    function GetDescription: String;
    procedure SetName(const AValue: String);
    procedure SetTitle(const AValue: String);
    procedure SetDescription(const AValue: String);
  protected
    procedure ToJSON(aJSON : TJSONObject); virtual;
    Procedure GetCompletions(const aArgName : string ; aPreviousCompletions, aCompletions : TStrings); virtual;
  Public
    constructor Create(const aName,aTitle : String; aDescription: String = '');
    destructor Destroy; override;
    procedure Register(aRegistry : TMCPPromptRegistry = Nil);
    function GetCompletions(const aArgName : String; aPreviousCompletions : TStrings) : TStringDynArray;
    procedure AddArgument(const aName,aDescription : String; aRequired : Boolean = true);
    procedure AddArgument(const aArgument : TPromptArgument);
    function GetPrompt(aArguments : TStrings) : TMCPPromptMessageArray; virtual; abstract;
    function GetPromptDescription(aArguments : TStrings) : String; virtual;
    function ToJSON() : TJSONObject;
    property Arguments[aIndex : integer] : TPromptArgument Read GetArgument;
    property ArgumentCount : integer Read GetArgumentCount;
    property Title : string Read GetTitle Write SetTitle;
    Property Description : string read GetDescription Write SetDescription;
    Property Name : string Read GetName Write SetName;
    Property OnCompletion : TMCPPromptCompletionEvent Read FOnCompletion Write FOnCompletion;
    // Access to info object
    Property Info: TMCPPromptInfo read FInfo;
  end;

  { TMCPTemplatePrompt }

  TMCPTemplatePrompt = class(TMCPPrompt)
  private
    FTemplate: string;
  protected
    function ReplaceValue(const aPrompt, aName, aValue : string) : string;
  public
    function GetPrompt(aArguments : TStrings) : TMCPPromptMessageArray; override;
    property Template : string read FTemplate Write FTemplate;
  end;


  { TMCPPromptRegistry }

  TMCPPromptRegistry = Class(TObject)
  private
    class var _instance : TMCPPromptRegistry;
    class function GetInstance: TMCPPromptRegistry; static;
  private
    FList :  TThreadSafeObjectHash;
    FOnChange: TNotifyEvent;
  protected
    function GetCount: Integer; virtual;
    procedure DoChange; virtual;
  Public
    constructor Create; virtual;
    destructor destroy; override;
    // Add a Prompt. Once added, the registry owns the Prompt
    Procedure Add(aPrompt : TMCPPrompt); virtual;
    Function AddTemplate(const aName,aTitle,aDescription,aTemplate : string) : TMCPTemplatePrompt;
    // Remove a Prompt. The object will be freed.
    procedure Remove(const aName : String); virtual;
    procedure Remove(aPrompt : TMCPPrompt);
    procedure LockList(aList : TFPList);
    procedure LockList(var aList: TMCPPromptArray);
    procedure UnlockList;
    function Find(const aName : String) : TMCPPrompt;
    function Get(const aName : String) : TMCPPrompt;
    Property Prompts[aName : string] : TMCPPrompt Read Get; default;
    Property Count : Integer Read GetCount;
    property OnChange : TNotifyEvent Read FOnChange Write FOnChange;
    class procedure Init(aClass: TMCPPromptRegistryClass);
    class procedure Done;
    class property Instance : TMCPPromptRegistry read GetInstance;
  end;

Function PromptRegistry : TMCPPromptRegistry;


implementation

uses  mcp.strings;

function PromptRegistry: TMCPPromptRegistry;
begin
  Result:=TMCPPromptRegistry.Instance;
end;

{ TMCPPromptRegistry }

class function TMCPPromptRegistry.GetInstance: TMCPPromptRegistry; static;
begin
  if _instance=nil then
    _Instance:=TMCPPromptRegistry.Create;
  Result:=_Instance
end;

function TMCPPromptRegistry.GetCount: Integer;
begin
  Result:=FList.Count;
end;

procedure TMCPPromptRegistry.DoChange;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

constructor TMCPPromptRegistry.Create;
begin
  FList:=TThreadSafeObjectHash.Create(True);
end;

destructor TMCPPromptRegistry.destroy;
begin
  FList.Destroy;
  inherited destroy;
end;

procedure TMCPPromptRegistry.Add(aPrompt: TMCPPrompt);
begin
  FList.Add(aPrompt.Name,aPrompt);
  DoChange;
end;

function TMCPPromptRegistry.AddTemplate(const aName, aTitle, aDescription,
  aTemplate: string): TMCPTemplatePrompt;
begin
  Result:=TMCPTemplatePrompt.Create(aName,aTitle,aDescription);
  Result.Template:=aTemplate;
  Add(Result);
end;

procedure TMCPPromptRegistry.Remove(const aName: String);
begin
  if FList.Get(aName)=nil then exit;
  FList.Remove(aName);
  DoChange;
end;

procedure TMCPPromptRegistry.Remove(aPrompt: TMCPPrompt);
begin
  Remove(aPrompt.Name);
end;

procedure TMCPPromptRegistry.LockList(aList: TFPList);
begin
  FList.GetObjectList(alist);
end;

procedure TMCPPromptRegistry.LockList(var aList: TMCPPromptArray);
var
  llist : TFPList;
  I : Integer;
begin
  lList:=TFPList.Create;
  try
    FList.GetObjectList(lList);
    SetLength(aList,lList.Count);
    For I:=0 to lList.Count-1 do
      aList[i]:=TMCPPrompt(lList[i]);
  finally
    lList.free;
  end;
  // do not unlock.
end;

procedure TMCPPromptRegistry.UnlockList;
begin
  FList.Unlock;
end;

function TMCPPromptRegistry.Find(const aName: String): TMCPPrompt;
begin
  Result:=TMCPPrompt(FList.Get(aName));
end;

function TMCPPromptRegistry.Get(const aName: String): TMCPPrompt;
begin
  Result:=Find(aName);
  if Result=Nil then
    Raise EMCPException.CreateFmt(SErrUnknownPrompt,[aName]);
end;

class procedure TMCPPromptRegistry.Init(aClass: TMCPPromptRegistryClass);
begin
  if assigned(_instance) then
    Raise EMCPException.Create(SErrRegistryALreadyInstantiated);
  if aClass=Nil then
    Raise EMCPException.Create(SErrRegistryClassEmpty);
  _Instance:=aClass.Create;
end;

class procedure TMCPPromptRegistry.Done;
begin
  FreeAndNil(_instance);
end;


{ TMCPPromptMessage }

constructor TMCPPromptMessage.createtext(aRole: TMCPRole; const aText: String);
begin
  Self:=Default(TMCPPromptMessage);
  kind:=pkText;
  Role:=aRole;
  TextContent:=aText;
end;

constructor TMCPPromptMessage.createImage(aRole: TMCPRole; aImage: TBytes;
  const aMimeType: String);
begin
  Self:=Default(TMCPPromptMessage);
  kind:=pkImage;
  Role:=aRole;
  Data:=aImage;
  mimeType:=aMimeType;
end;

constructor TMCPPromptMessage.createAudio(aRole: TMCPRole; aImage: TBytes;
  const aMimeType: String);
begin
  Self:=Default(TMCPPromptMessage);
  kind:=pkAudio;
  Role:=aRole;
  Data:=aImage;
  mimeType:=aMimeType;
end;

constructor TMCPPromptMessage.createResourceLink(aRole: TMCPRole; aURI: String);
begin
  Self:=Default(TMCPPromptMessage);
  Role:=aRole;
  kind:=pkResourceLink;
  ResourceURI:=aURI;
end;

constructor TMCPPromptMessage.createEmbeddedResource(aRole: TMCPRole;
  aURI: String);
begin
  Self:=Default(TMCPPromptMessage);
  Role:=aRole;
  kind:=pkEmbeddedResource;
  ResourceURI:=aURI;
end;


procedure TMCPPromptMessage.ToJSON(aJSON: TJSONObject; aResources: TMCPResourceRegistry);
var
  lObj : TJSONObject;
  LResource: TMCPResource;
  lResObject : TJSONObject;

begin
  aJSON.Add('type',kind.tostring);
  if (kind in [pkResourceLink,pkEmbeddedResource]) and not Assigned(aResources) then
    Raise EMCPException.Create(SErrNoResourceRegistry);

  case kind of
   pkText:
     aJSON.Add('text',TextContent);
   pkImage,pkAudio:
     begin
     aJSON.Add('data',EncodeBytes(Data));
     aJSON.Add('mimeType',mimeType);
     end;
   pkResourceLink:
     begin
     lResource:=aResources.Get(ResourceURI);
     lResource.ToJSON(aJSON,False);
     end;
   pkEmbeddedResource:
     begin
     lResource:=aResources.Get(ResourceURI);
     lResObject:=TJSONObject.Create;
     aJSON.Add('resource',lResObject);
     lResource.ToJSON(lResObject,True);
     end;
  end;
  lOBj:=Annotations.ToJSON;
  if assigned(lObj) then
    aJSON.Add('annotations',lObj);
  if assigned(_meta) then
    aJSON.Add('_meta',_meta);
end;

function TMCPPromptMessage.ToJSON(aResources: TMCPResourceRegistry): TJSONObject;

begin
  Result:=TJSONObject.Create;
  try
    ToJSON(Result,aResources);
  except
    Result.Free;
    Raise;
  end;
end;

{ TMCPPromptMessageArrayHelper }

procedure TMCPPromptMessageArrayHelper.ToJSON(aJSON: TJSONArray; aResources : TMCPResourceRegistry);
var
  lMessage : TMCPPromptMessage;
begin
  For lMessage in Self do
    aJSON.Add(lMessage.ToJSON(aResources));
end;

function TMCPPromptMessageArrayHelper.ToJSON(aResources : TMCPResourceRegistry): TJSONArray;
begin
  Result:=TJSONArray.Create;
  try
    ToJSON(Result,aResources);
  except
    Result.Free;
    Raise;
  end;

end;

function TMCPPrompt.GetArgument(aIndex: integer): TPromptArgument;
begin
  Result:=FInfo.Arguments[aIndex];
end;

function TMCPPrompt.GetArgumentCount: integer;
begin
  Result:=FInfo.ArgumentCount;
end;

function TMCPPrompt.GetName: String;
begin
  Result:=FInfo.Name;
end;

function TMCPPrompt.GetTitle: String;
begin
  Result:=FInfo.Title;
end;

function TMCPPrompt.GetDescription: String;
begin
  Result:=FInfo.Description;
end;

procedure TMCPPrompt.SetName(const AValue: String);
begin
  FInfo.Name:=AValue;
end;

procedure TMCPPrompt.SetTitle(const AValue: String);
begin
  FInfo.Title:=AValue;
end;

procedure TMCPPrompt.SetDescription(const AValue: String);
begin
  FInfo.Description:=AValue;
end;

procedure TMCPPrompt.ToJSON(aJSON: TJSONObject);
begin
  FInfo.ToJSON(aJSON);
end;

procedure TMCPPrompt.GetCompletions(const aArgName: string;
  aPreviousCompletions, aCompletions: TStrings);
begin
  If Assigned(FOnCompletion) then
    FOnCompletion(Self,aArgName,aPreviousCompletions,aCompletions);
end;

constructor TMCPPrompt.Create(const aName, aTitle: String; aDescription: String);
begin
  FInfo:=TMCPPromptInfo.Create(aName, aTitle, aDescription);
end;

destructor TMCPPrompt.Destroy;
begin
  inherited Destroy;
end;

procedure TMCPPrompt.Register(aRegistry : TMCPPromptRegistry = Nil);
begin
  if aRegistry=Nil then
    aRegistry:=TMCPPromptRegistry.Instance;
  aRegistry.Add(Self);
end;

function TMCPPrompt.GetCompletions(const aArgName: String;
  aPreviousCompletions: TStrings): TStringDynArray;
var
  lRes : TStrings;

begin
  lRes:=TStringList.Create;
  try
    GetCompletions(aArgName,aPreviousCompletions,lRes);
    Result:=lRes.ToStringArray;
  finally
    lRes.Free
  end;
end;

procedure TMCPPrompt.AddArgument(const aName, aDescription: String;
  aRequired: Boolean);
begin
  FInfo.AddArgument(aName, aDescription, aRequired);
end;

procedure TMCPPrompt.AddArgument(const aArgument: TPromptArgument);
begin
  FInfo.AddArgument(aArgument);
end;

function TMCPPrompt.GetPromptDescription(aArguments: TStrings): String;
begin
  Result:=Description;
end;

function TMCPPrompt.ToJSON(): TJSONObject;
begin
  Result:=TJSONObject.Create;
  try
    ToJSON(Result);
  except
    Result.Free;
    Raise;
  end;
end;

{ TMCPTemplatePrompt }

function TMCPTemplatePrompt.ReplaceValue(const aPrompt, aName, aValue: string
  ): string;
begin
  Result:=StringReplace(aPrompt,'{{'+aName+'}}',aValue,[rfReplaceAll]);
end;

function TMCPTemplatePrompt.GetPrompt(aArguments: TStrings): TMCPPromptMessageArray;
var
  I: Integer;
  lArg : TPromptArgument;
  lValue, lPrompt : string;

begin
  lPrompt:=Template;
  for I:=0 to FInfo.ArgumentCount - 1 do
    begin
    lArg:=FInfo.Arguments[I];
    lValue:=aArguments.Values[lArg.Name];
    lPrompt:=ReplaceValue(lPrompt,lArg.Name,lValue);
    end;
  Result:=[TMCPPromptMessage.CreateText(prUser,lValue)];
end;


finalization
  TMCPPromptRegistry.Done;
end.

