{
    This file is part of the Free Component Library

    MCP Resource definitions
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit mcp.resources;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Contnrs, fpjson, mcp.types, mcp.utils;

Type
  TMCPResource = class;
  TMCPResourceRegistry = class;
  TMCPResourceRegistryClass = Class of TMCPResourceRegistry;
  TMCPResourceArray = array of TMCPResource;

  TMCPResourceGetDataCallBack = Procedure (aResource : TMCPResource) of object;

  { TMCPResource }

  TMCPResource = Class(TObject)
  private
    FInfo: TMCPResourceInfo;
    FOnData: TMCPResourceGetDataCallBack;
    function GetData: TBytes;
    function GetText: String;
    function GetKind: TMCPResourceKind;
    function GetSize: Integer;
    function GetUri: String;
    function GetName: string;
    function GetTitle: string;
    function GetDescription: string;
    function GetMimeType: string;
    procedure SetData(AValue: TBytes);
    procedure SetText(AValue: String);
    procedure SetUri(AValue: String);
    procedure SetSize(AValue: Integer);
    procedure SetName(AValue: string);
    procedure SetTitle(AValue: string);
    procedure SetDescription(AValue: string);
    procedure SetMimeType(AValue: string);
  protected
    function GetDataVirtual: TBytes; virtual;
    function GetTextVirtual: String; virtual;
    function GetKindVirtual: TMCPResourceKind; virtual;
  Public
    constructor Create(const aURI,aName : String);
    constructor Create(const aURI,aName : String; aText : String);
    constructor Create(const aURI,aName : String; aData : TBytes);
    constructor Create(const aURI,aName : String; aKind : TMCPResourceKind; aCallBack : TMCPResourceGetDataCallBack);
    destructor Destroy; override;
    procedure Register(aRegistry : TMCPResourceRegistry = Nil);
    procedure ToJSON(aJSON : TJSONObject; withData : Boolean); virtual;
    function ToJSON(withData : Boolean) : TJSONObject;
    Property Uri : String read GetUri Write SetUri;
    property Title : string Read GetTitle Write SetTitle;
    Property Description : string read GetDescription Write SetDescription;
    Property MimeType: string read GetMimeType Write SetMimeType;
    Property Name : string Read GetName Write SetName;
    Property Text : String Read GetText Write SetText;
    Property Data : TBytes Read GetData Write SetData;
    Property Size : Integer Read GetSize Write SetSize;
    Property Kind: TMCPResourceKind Read GetKind;
    // Allow to dynamically update  the data.
    Property OnData : TMCPResourceGetDataCallBack Read FOnData Write FOnData;
    // Access to info object
    Property Info: TMCPResourceInfo read FInfo;
  end;

  { TMCPResourceRegistry }

  TMCPResourceRegistry = Class(TObject)
  private
    class var _instance : TMCPResourceRegistry;
    class function GetInstance: TMCPResourceRegistry; static;
  private
    FList :  TThreadSafeObjectHash;
    FOnChange: TNotifyEvent;
  protected
    function GetCount: Integer; virtual;
    procedure DoChange; virtual;
  Public
    constructor Create; virtual;
    destructor destroy; override;
    // Add a resource. Once added, the registry owns the resource
    Procedure Add(aResource : TMCPResource); virtual;
    // Remove a resource. The object will be freed.
    procedure Remove(const aURI : String); virtual;
    procedure Remove(aResource : TMCPResource);
    procedure LockList(aList : TFPList);
    procedure LockList(var aList : TMCPResourceArray);
    procedure UnlockList;
    function Find(const aURI : String) : TMCPResource; virtual;
    function Get(const aURI : String) : TMCPResource; virtual;
    property Resources[aName : string] : TMCPResource Read Get; default;
    Property Count : Integer Read GetCount;
    property OnChange : TNotifyEvent Read FOnChange Write FOnChange;
    class procedure Init(aClass: TMCPResourceRegistryClass);
    class procedure Done;
    class property Instance : TMCPResourceRegistry read GetInstance;
  end;

Function ResourceRegistry : TMCPResourceRegistry;

implementation

uses mcp.strings;

function ResourceRegistry: TMCPResourceRegistry;
begin
  Result:=TMCPResourceRegistry.Instance;
end;

{ TMCPResource }

procedure TMCPResource.SetData(AValue: TBytes);
begin
  FInfo.Data:=AValue;
end;

function TMCPResource.GetSize: Integer;
begin
  Result:=FInfo.GetSize;
end;

procedure TMCPResource.SetSize(AValue: Integer);
begin
  FInfo.Size:=aValue;
end;

function TMCPResource.GetData: TBytes;
begin
  Result:=GetDataVirtual;
end;

function TMCPResource.GetText: String;
begin
  Result:=GetTextVirtual;
end;

function TMCPResource.GetKind: TMCPResourceKind;
begin
  Result:=GetKindVirtual;
end;

function TMCPResource.GetUri: String;
begin
  Result:=FInfo.Uri;
end;

function TMCPResource.GetName: string;
begin
  Result:=FInfo.Name;
end;

function TMCPResource.GetTitle: string;
begin
  Result:=FInfo.Title;
end;

function TMCPResource.GetDescription: string;
begin
  Result:=FInfo.Description;
end;

function TMCPResource.GetMimeType: string;
begin
  Result:=FInfo.MimeType;
end;

procedure TMCPResource.SetUri(AValue: String);
begin
  FInfo.Uri:=AValue;
end;

procedure TMCPResource.SetName(AValue: string);
begin
  FInfo.Name:=AValue;
end;

procedure TMCPResource.SetTitle(AValue: string);
begin
  FInfo.Title:=AValue;
end;

procedure TMCPResource.SetDescription(AValue: string);
begin
  FInfo.Description:=AValue;
end;

procedure TMCPResource.SetMimeType(AValue: string);
begin
  FInfo.MimeType:=AValue;
end;

procedure TMCPResource.SetText(AValue: String);
begin
  FInfo.Text:=AValue;
end;

function TMCPResource.GetDataVirtual: TBytes;
begin
  if Assigned(FOnData) then
  begin
    FOnData(Self);
  end;
  Result:=FInfo.Data;
end;

function TMCPResource.GetTextVirtual: String;
begin
  if Assigned(FOnData) then
  begin
    FOnData(Self);
  end;
  Result:=FInfo.Text;
end;

function TMCPResource.GetKindVirtual: TMCPResourceKind;
begin
  Result:=FInfo.GetKind;
end;

constructor TMCPResource.Create(const aURI, aName: String);
begin
  FInfo:=TMCPResourceInfo.Create(aURI, aName);
end;


constructor TMCPResource.Create(const aURI,aName: String; aText: String);
begin
  Create(aURI,aName);
  Text:=aText;
end;

constructor TMCPResource.Create(const aURI,aName: String; aData: TBytes);
begin
   Create(aURI,aName);
   Data:=aData;
end;

constructor TMCPResource.Create(const aURI,aName: String; aKind: TMCPResourceKind;
  aCallBack: TMCPResourceGetDataCallBack);
begin
  Create(aURI,aName);
  FInfo.SetKind(aKind);
  FOnData:=aCallBack;
end;

procedure TMCPResource.Register(aRegistry : TMCPResourceRegistry = Nil);
begin
  if aRegistry=nil then
    aRegistry:=TMCPResourceRegistry.Instance;
  aRegistry.Add(Self);
end;

function TMCPResource.ToJSON(withData : boolean): TJSONObject;
begin
  Result:=TJSONObject.Create;
  try
    ToJSON(Result,WithData);
  Except
    Result.Free;
    Raise;
  end;
end;

destructor TMCPResource.Destroy;
begin
  inherited Destroy;
end;

procedure TMCPResource.ToJSON(aJSON: TJSONObject; WithData : Boolean);
begin
  FInfo.ToJSON(aJSON, WithData);
end;

  { TMCPResourceRegistry }

class function TMCPResourceRegistry.GetInstance: TMCPResourceRegistry; static;
begin
  if _instance=nil then
    _Instance:=TMCPResourceRegistry.Create;
  Result:=_Instance
end;

function TMCPResourceRegistry.GetCount: Integer;
begin
  Result:=FList.Count;
end;

procedure TMCPResourceRegistry.DoChange;
begin
  if assigned(FOnChange) then
    FOnChange(Self);
end;

constructor TMCPResourceRegistry.Create;
begin
  FList:=TThreadSafeObjectHash.Create(True);
end;

destructor TMCPResourceRegistry.destroy;
begin
  FList.Destroy;
  inherited destroy;
end;

procedure TMCPResourceRegistry.Add(aResource: TMCPResource);
begin
  FList.Add(aResource.Uri,aResource);
  DoChange;
end;

procedure TMCPResourceRegistry.Remove(const aURI: String);
begin
  if FList.Get(aURI)=nil then
    exit;
  FList.Remove(aURI);
  DoChange;
end;

procedure TMCPResourceRegistry.Remove(aResource: TMCPResource);
begin
  Remove(aResource.URI);
end;

procedure TMCPResourceRegistry.LockList(aList: TFPList);
begin
  FList.GetObjectList(aList);
  // do not unlock.
end;

procedure TMCPResourceRegistry.LockList(var aList: TMCPResourceArray);
var
  llist : TFPList;
  I : Integer;
begin
  lList:=TFPList.Create;
  try
    FList.GetObjectList(lList);
    SetLength(aList,lList.Count);
    For I:=0 to lList.Count-1 do
      aList[i]:=TMCPResource(lList[i]);
  finally
    lList.free;
  end;
  // do not unlock.
end;

procedure TMCPResourceRegistry.UnlockList;
begin
  FList.Unlock;
end;

function TMCPResourceRegistry.Find(const aURI: String): TMCPResource;
begin
  Result:=TMCPResource(FList.Get(aURI));
end;

function TMCPResourceRegistry.Get(const aURI: String): TMCPResource;
begin
  Result:=Find(aURI);
  if Result=Nil then
    Raise EMCPException.CreateFmt(SErrUnknownResource,[aURI]);
end;

class procedure TMCPResourceRegistry.Init(aClass: TMCPResourceRegistryClass);
begin
  if assigned(_instance) then
    Raise EMCPException.Create(SErrRegistryAlreadyInstantiated);
  if aClass=Nil then
    Raise EMCPException.Create(SErrRegistryClassEmpty);
  _Instance:=aClass.Create;
end;

class procedure TMCPResourceRegistry.Done;
begin
  FreeAndNil(_instance);
end;

finalization
  TMCPResourceRegistry.Done;
end.

