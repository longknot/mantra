{
    This file is part of the Free Component Library

    Database handling MCP tools
    Copyright (c) 2025 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit mcpsqldbtools;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, fpjson, db, sqldb, mcp.types, mcp.logging, mcp.utils, mcp.tools;

type

  { TMCPDBConnectionInfo }

  TMCPDBConnectionInfo = Class(TObject)
    DBType : string;
    HostName : string;
    Port : integer;
    DatabaseName : string;
    UserName : string;
    Password : string;
    Params : Array of string;
    Procedure FromJSON(aJSON: TJSONObject);
  end;
  TMCPDBConnectionInfoArray = Array of TMCPDBConnectionInfo;

  { TSQLConnectionHelper }

  TSQLConnectionHelper = Class helper for TSQLConnection
    function ConnectionURL(aType: String = ''): string;
  end;
  { TMCPToolConnectionManager }

  TMCPToolConnectionManager = class(TComponent)
  private
    class var _instance: TMCPToolConnectionManager;
    function CreateConnection(const aName: string): TSQLConnection;
  private
    FAllowModify: Boolean;
    FConnectionDefs : TThreadSafeObjectHash;
    FConnections : TThreadSafeObjectHash;
    FQryCount : Integer;
  protected
    procedure DoLog(aType : TMCPLogType; Const aMsg : String);
    procedure DoLog(aType : TMCPLogType; Const aFmt : String; Const aArgs : Array of const);
    Function GetConnection(const aName : string) : TSQLConnection;
    Function GetQuery(aConnection : TSQLConnection) : TSQLQuery;
    procedure ReleaseConnection(aConnection : TSQLConnection);
    procedure ReleaseQuery(aQuery : TSQLQuery);
  public
    constructor create(aOwner : TComponent); override;
    destructor destroy; override;
    class constructor init;
    class destructor done;
    class function DefaultDBType : string;
    procedure CloseConnections;
    // Set default connection.
    Procedure SetDefaultConnection(aInfo : TMCPDBConnectionInfo);
    Property AllowModify : Boolean Read FAllowModify Write FallowModify;
    class Property Instance : TMCPToolConnectionManager Read _instance;
  end;

  { TSQLDBTool }

  TSQLDBTool = class abstract (TMCPTool)
  private
  protected
    function ConnMgr : TMCPToolConnectionManager;
    function GetConnection(aInput : TJSONObject) : TSQLConnection;
    function GetQuery(aConnection : TSQLConnection) : TSQLQuery;
    function FieldsToMetaData(aFields : TFields) : TJSONArray;
    procedure ReleaseConnection(aConnection : TSQLConnection);
    procedure ReleaseQuery(aQuery : TSQLQuery);
    procedure FillParams(aParams : TParams; aData : TJSONObject);
    procedure RecordToJSON(aRow: TJSONObject; const aQuery: TSQLQuery);
    function QueryToJSON(const aQuery : TSQLQuery) : TJSONArray;
    function QueryToJSON(aConnection: TSQLConnection; const aSQL: String; aParams: TJSONObject=nil): TJSONArray;
    Procedure DoExecute(aInput : TJSONObject; out aResult : TMCPToolResult); override;
    Procedure ExecuteInConnection(aConnection : TSQLConnection; aInput : TJSONObject; aResult : TJSONObject); virtual; abstract;
  end;

  { TListTablesTool }

  TListTablesTool = Class(TSQLDBTool)
    Procedure ExecuteInConnection(aConnection : TSQLConnection; aInput : TJSONObject; aResult : TJSONObject); override;
  end;

  { TGetTableInfoTool }

  TGetTableInfoTool = Class(TSQLDBTool)
    constructor create(const aName: string; const aDescription: string); override;
    Procedure ExecuteInConnection(aConnection : TSQLConnection; aInput : TJSONObject; aResult : TJSONObject); override;
  end;


  { TExecuteSQLTool }

  TExecuteSQLTool = Class(TSQLDBTool)
    constructor create(const aName: string; const aDescription: string); override;
    Procedure ExecuteInConnection(aConnection : TSQLConnection; aInput : TJSONObject; aResult : TJSONObject); override;
  end;

implementation

uses dateutils;

function TSQLDBTool.ConnMgr : TMCPToolConnectionManager;
begin
  Result:=TMCPToolConnectionManager.Instance;
end;

{ TMCPDBConnectionInfo }

procedure TMCPDBConnectionInfo.FromJSON(aJSON: TJSONObject);

var
  lParams : TJSONArray;
  i: integer;

begin
  DBType:=aJSON.get('type','');
  HostName:=aJSON.get('host','');
  DatabaseName:=aJSON.get('databasename','');
  Port:=aJSON.get('port',0);
  UserName:=aJSON.get('username','');
  Password:=aJSON.get('password','');
  lParams:=aJSON.get('params',TJSONArray(Nil));
  if Assigned(lParams) then
    begin
    SetLength(Params,lParams.Count);
    For I:=0 to lParams.Count-1 do
      if lParams.Types[i]=jtString then
        Params[i]:=lParams[i].AsString;
    end;
end;

{ TSQLConnectionHelper }

function TSQLConnectionHelper.ConnectionURL(aType : String) : string;
begin
  if aType='' then
    if (Self is TSQLConnector) then
      aType:=TSQLConnector(Self).ConnectorType
    else
      aType:='db';
  Result:=Format('%s://%s@%s/%s',[aType,UserName,HostName,DatabaseName]);
end;

{ TMCPToolConnectionManager }

function TMCPToolConnectionManager.CreateConnection(const aName: string): TSQLConnection;
var
  lInfo : TMCPDBConnectionInfo;
  lDef : TConnectionDef;
  lType,S : String;
begin
  lInfo:=TMCPDBConnectionInfo(FConnectionDefs.Get(aName));
  if not assigned(lInfo) then
    Raise EMCPException.CreateFmt('Unknown connection : %s',[aName]);
  lType:=lInfo.DBType;
  if lType='' then
    lType:=DefaultDBType;
  lDef:=GetConnectionDef(lType);
  if lDef=Nil then
    Raise EMCPException.CreateFmt('Unknown/Unsupported connection type: %s',[lType]);
  Result:=lDef.ConnectionClass.Create(Nil);
  Result.DatabaseName:=lInfo.DatabaseName;
  Result.HostName:=lInfo.HostName;
  Result.UserName:=lInfo.UserName;
  Result.Password:=lInfo.Password;
  if lInfo.Port<>0 then
    Result.Params.Values['port']:=IntToStr(lInfo.Port);
  for S in lInfo.Params do
    Result.Params.Add(S);
  DoLog(mltInfo,'Creating connection to %s',[Result.ConnectionURL(lType)]);
  Result.Transaction:=TSQLTransaction.Create(Result);
  try
    Result.Connected:=True;
  except
    on E : Exception do
      begin
      DoLog(mltError,'Error %s ceating connection to %s: %s',[E.ClassName,Result.ConnectionURL(lType),E.Message]);
      Result.Free;
      Raise;
      end;
  end;

end;

procedure TMCPToolConnectionManager.DoLog(aType: TMCPLogType; const aMsg: String);
begin
  MCPLogger.Log(aType,'['+Self.ClassName+'] '+aMsg);
end;

procedure TMCPToolConnectionManager.DoLog(aType: TMCPLogType; const aFmt: String; const aArgs: array of const);
begin
  DoLog(aType,{$IFNDEF VER3_2}SafeFormat{$ELSE}Format{$ENDIF}(aFmt,aArgs));
end;

function TMCPToolConnectionManager.GetConnection(const aName: string): TSQLConnection;
var
  lName : string;

begin
  lName:=aName;
  if lName='' then
    lName:='_default_';
  Result:=TSQLConnection(FConnections.Get(lName));
  if Result=Nil then
    begin
    Result:=CreateConnection(lName);
    FConnections.Add(lName,Result);
    end;
  Result.Transaction.Active:=True;
end;

function TMCPToolConnectionManager.GetQuery(aConnection: TSQLConnection): TSQLQuery;
var
  id : integer;
begin
  Result:=TSQLQuery.Create(Self);
  Id:=InterlockedIncrement(FQryCount);
  Result.name:='Qry'+IntToStr(id);
  Result.Database:=aConnection;
  Result.Transaction:=aConnection.Transaction;
end;

procedure TMCPToolConnectionManager.ReleaseConnection(aConnection: TSQLConnection);
begin
  if aConnection.Transaction.Active then
    aConnection.Transaction.RollBack;
end;

procedure TMCPToolConnectionManager.ReleaseQuery(aQuery: TSQLQuery);
begin
  if aQuery.SQLTransaction.Active then
    aQuery.SQLTransaction.RollBack;
  aQuery.Free;
end;

constructor TMCPToolConnectionManager.create(aOwner: TComponent);
begin
  inherited create(aOwner);
  FConnectionDefs:=TThreadSafeObjectHash.create(True);
  FConnections:=TThreadSafeObjectHash.create(True);
end;

destructor TMCPToolConnectionManager.destroy;
begin
  FConnectionDefs.Destroy;
  try
    FConnections.Destroy;
  except
    on E : Exception do
      DoLog(mltError,'Error %s freeing database connections: %s',[E.ClassName,E.Message]);
  end;
  inherited destroy;
end;

class constructor TMCPToolConnectionManager.init;
begin
  _Instance:=TMCPToolConnectionManager.Create(Nil);
end;

class destructor TMCPToolConnectionManager.done;
begin
  FreeAndNil(_Instance);
end;

class function TMCPToolConnectionManager.DefaultDBType: string;
var
  L : TStringlist;
begin
  Result:='';
  l:=TStringList.Create;
  try
    GetConnectionList(l);
    if L.Count>0 then
      Result:=L[0];
  finally
    l.Free;
  end;
end;

procedure TMCPToolConnectionManager.CloseConnections;
var
  lList : TFPList;
  l : Pointer;
  Conn : TSQLConnection absolute l;
begin
  lList:=TFPList.Create;
  try
    FConnections.GetObjectList(lList);
    For l in lList do
      try
        Conn.Close(True);
      except
        on E : exception do
          DoLog(mltError,'Error %s closing connection to [%s:%s]: %s',[E.ClassName,Conn.HostName,Conn.DatabaseName,E.Message]);
      end;
  finally
    lList.Free;
    FConnections.unlock;
  end;
end;

procedure TMCPToolConnectionManager.SetDefaultConnection(aInfo: TMCPDBConnectionInfo);
begin
  FConnectionDefs.Add('_default_',aInfo);
end;

{ TSQLDBTool }

function TSQLDBTool.GetConnection(aInput: TJSONObject): TSQLConnection;

begin
  // later on, we can collect a connection name from the input
  Result:=ConnMgr.GetConnection('');
end;

function TSQLDBTool.GetQuery(aConnection: TSQLConnection): TSQLQuery;
begin
  Result:=ConnMgr.GetQuery(aConnection);
end;

function TSQLDBTool.FieldsToMetaData(aFields: TFields): TJSONArray;

Const
  // SQL names instead of DB names
  Fieldtypenames : Array [TFieldType] of String[20] =
  (
    {ftUnknown} 'Unknown',
    {ftString} 'VARCHAR',
    {ftSmallint} 'INTEGER',
    {ftInteger} 'INTEGER',
    {ftWord} 'INTEGER',
    {ftBoolean} 'Boolean',
    {ftFloat} 'DOUBLE PRECISION',
    {ftCurrency} 'DOUBLE PRECISION',
    {ftBCD} 'DECIMAL',
    {ftDate} 'DATE',
    {ftTime} 'TIME',
    {ftDateTime} 'TIMESTAMP',
    {ftBytes} 'Bytes',
    {ftVarBytes} 'VarBytes',
    {ftAutoInc} 'AutoInc',
    {ftBlob} 'BLOB',
    {ftMemo} 'BLOB',
    {ftGraphic} 'BLOB',
    {ftFmtMemo} 'BLOB',
    {ftParadoxOle} 'Unknown',
    {ftDBaseOle} 'Unknown',
    {ftTypedBinary} 'Unknown',
    {ftCursor} 'Unknown',
    {ftFixedChar} 'CHAR',
    {ftWideString} 'VARCHAR',
    {ftLargeint} 'BIGINT',
    {ftADT} 'Unknown',
    {ftArray} 'Unknown',
    {ftReference} 'Unknown',
    {ftDataSet} 'Unknown',
    {ftOraBlob} 'BLOB',
    {ftOraClob} 'BLOB',
    {ftVariant} 'Unknown',
    {ftInterface} 'Unknown',
    {ftIDispatch} 'Unknown',
    {ftGuid} 'STRING',
    {ftTimeStamp} 'TimeStamp',
    {ftFMTBcd} 'DECOMAL',
    {ftFixedWideChar} 'CHAR',
    {ftWideMemo} 'TEXT'
{$IFNDEF VER3_2}
    {ftOraTimeStamp} , 'TimeStamp',
    { ftOraInterval} 'INTERVAL',
    { ftLongWord }   'BIGINT',
    { ftShortint }   'SMALLINT',
    { ftByte }       'SMALLINT',
    { ftExtended }   'DOUBLE',
    { ftSingle }     'DOUBLE'
{$ENDIF}
  );

var
  F : TField;
  Obj : TJSONObject;
begin
  Result:=TJSONArray.Create;
  try
    For F in aFields do
      begin
      Obj:=TJSONObject.Create;
      Result.Add(Obj);
      Obj.Add('FieldName',F.FieldName);
      Obj.Add('FieldType',Fieldtypenames[F.DataType]);
      Obj.Add('FieldLength',F.Size);
      if F is TFloatField then
        Obj.Add('FieldScale',TFloatField(F).Precision);
      Obj.Add('nullable',not F.Required);
      end;
  except
    Result.Free;
    Raise;
  end;
end;

procedure TSQLDBTool.ReleaseConnection(aConnection: TSQLConnection);
begin
  ConnMgr.ReleaseConnection(aConnection);
end;

procedure TSQLDBTool.ReleaseQuery(aQuery: TSQLQuery);
begin
  ConnMgr.ReleaseQuery(aQuery);
end;

procedure TSQLDBTool.FillParams(aParams: TParams; aData: TJSONObject);
var
  lParam : TParam;
  lValue : TJSONData;
  lNumber : TJSONNumber absolute lValue;
begin
  For lParam in aParams do
    begin
    if aData.IndexOfName(lParam.Name)<>-1 then
      begin
      lValue:=aData.Elements[lParam.name];
      case lValue.JSONType of
        jtString: lParam.AsString:=lValue.AsString;
        jtBoolean: lParam.AsBoolean:=lValue.AsBoolean;
        jtNull : lParam.Clear;
        jtNumber :
          case lNumber.NumberType of
            ntFloat : lParam.AsFloat:=lValue.AsFloat;
            ntInteger : lParam.AsInteger:=lValue.AsInteger;
            ntInt64: lParam.AsLargeInt:=lValue.asInt64;
            ntQWord : lParam.asFloat:=lValue.asFloat;
          end;
        jtObject : lParam.AsString:=lValue.AsJSON;
      end;
      end;
    end;

end;

procedure TSQLDBTool.RecordToJSON(aRow: TJSONObject; const aQuery: TSQLQuery);
var
  F : TField;
  S : String;
begin
  For F in aQuery.Fields do
    begin
    if F.IsNull then
      aRow.Add(F.FieldName)
    else
      Case f.DataType of
        ftInteger : aRow.Add(F.FieldName,F.AsInteger);
        ftLargeInt : aRow.Add(F.FieldName,F.AsLargeInt);
        ftBoolean : aRow.Add(F.FieldName,F.AsBoolean);
        ftFloat,
        ftCurrency : aRow.Add(F.FieldName,F.AsString);
        ftDate,
        ftDateTime,
        ftTime,
        ftTimeStamp : aRow.Add(F.FieldName,DateToIso8601(F.AsDateTime));
        ftGuid,
        ftString,
        ftFixedChar,
        ftMemo : aRow.Add(F.FieldName,F.AsString);
        ftWideString,
        ftFixedWideChar,
        ftWideMemo : aRow.Add(F.FieldName,UTF8Encode(F.AsUnicodeString));
      else
        WriteStr(S,F.DataType);
        DoLog(mltWarning,'Field type %s not supported in SQL: %s',[S,capString(aQuery.SQL.Text)]);
      end;
    end;
end;

function TSQLDBTool.QueryToJSON(const aQuery: TSQLQuery): TJSONArray;

var
  lRow : TJSONObject;

begin
  Result:=TJSONArray.Create;
  try
    While not aQuery.EOF do
      begin
      lRow:=TJSONObject.Create;
      try
        RecordToJSON(lRow,aQuery);
      except
        lRow.Free;
        Raise
      end;
      Result.Add(lRow);
      aQuery.next;
      end;
  except
    Result.Free;
    Raise;
  end;
end;

function TSQLDBTool.QueryToJSON(aConnection: TSQLConnection; const aSQL: String; aParams: TJSONObject = Nil): TJSONArray;

const
  ReadStatements : set of TStatementType
                 = [stSelect,stGetSegment,stStartTrans,stCommit,stRollBack];
var
  lQry : TSQLQuery;
  lType : string;
begin
  lQry:=GetQuery(aConnection);
  try
    lQry.SQL.Text:=aSQL;
    DoLog(mltInfo,'Executing SQL on %s : %s',[aConnection.ConnectionURL(''),CapString(aSql)]);
    lQry.Prepare;
    if not (lQry.StatementType in ReadStatements) then
      begin
      writeStr(lType,lQry.StatementType);
      Raise EMCPException.CreateFmt('Executing a statement of type %s is not allowed',[lType]);
      end;
    if assigned(aParams) then
      begin
      FillParams(lQry.Params,aParams);
      end;
    lQry.Open;
    Result:=QueryToJSON(lQry);
  finally
    ReleaseQuery(lQry);
  end;
end;

procedure TSQLDBTool.DoExecute(aInput: TJSONObject; out aResult: TMCPToolResult);
var
  lConnection : TSQLConnection;
  lResult : TJSONObject;
begin
  DoLog(mltTrace,'Executing database tool "%s" - start',[Name]);
  lConnection:=GetConnection(aInput);
  try
    lResult:=TJSONObject.Create;
    ExecuteInConnection(lConnection,aInput,lResult);
    aResult:=TMCPToolResult.CreateText(lResult.AsJSON);
  finally
    ReleaseConnection(lConnection);
    lResult.Free;
  end;
  DoLog(mltTrace,'Execute database tool "%s" - end',[Name]);
end;

{ TListTablesTool }

procedure TListTablesTool.ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject);

var
  lTables : TStrings;
  lArray : TJSONArray;
  S : String;
begin
  lTables:=TStringList.Create;
  try
    aConnection.GetTableNames(lTables,false);
    lArray:=TJSONArray.Create;
    aResult.Add('tables',lArray);
    for S in lTables do
      lArray.Add(S);
//      lArray.Add(TJSONObject.Create(['name',S,'uri','database://table/'+S]));
  finally
    lTables.Free;
  end;
end;

{ TGetTableInfoTool }

constructor TGetTableInfoTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('tableName',TJSONObject.Create(['type','string']),True);
end;

procedure TGetTableInfoTool.ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject);
var
  lTableName : String;
  lQry : TSQLQuery;
  lArray : TJSONArray;
begin
  lTableName:=aInput.Get('tableName','');
  if lTableName='' then
    Raise EMCPException.Create('Missing table name argument');
  lQry:=GetQuery(aConnection);
  try
    lQry.SQL.Text:=Format('select * from %s where (1=0)',[lTableName]);
    lQry.Open;
    lArray:=FieldsToMetaData(lQry.Fields);
    aResult.Add('rows',lArray);
  finally
    ReleaseQuery(lQry);
  end;
end;

{ TExecuteSQLTool }

constructor TExecuteSQLTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('sql',TJSONObject.Create(['type','string']),True);
  InputSchema.AddArgument('params',TJSONObject.Create(['type','object']),False);
end;

procedure TExecuteSQLTool.ExecuteInConnection(aConnection: TSQLConnection; aInput: TJSONObject; aResult: TJSONObject);
var
  lData : TJSONArray;
  lParams : TJSONObject;
  lSQL : String;
begin
  lSQL:=aInput.Get('sql','');
  lParams:=aInput.Get('params',TJSONObject(Nil));
  lData:=QueryToJSON(aConnection,lSQL,lParams);
  aResult.Add('rows',lData);
end;

end.

