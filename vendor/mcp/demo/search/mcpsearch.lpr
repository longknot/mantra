program mcpsearch;

uses
  // Standard stuff
  SysUtils, Classes, JsonParser,fpJSON, fphttpclient, opensslsockets,
  // MCP
  mcp.application.stdio, mcp.tools, mcp.resources, mcp.prompts, mcp.types;

Type
  TApplication = class (TMCPStdioApplication)
    procedure DoRun; override;
  end;

  TTavilySearchTool = class(TMCPTool)
  protected
    Procedure DoExecute(aInput: TJSONObject; var aResult: TMCPToolResultArray); override;
  public
    APIKey : String;
    constructor create(const aName: string; const aDescription: string); override;
  end;

procedure TTavilySearchTool.DoExecute(aInput: TJSONObject; var aResult: TMCPToolResultArray);

const
  SearchURL = 'https://api.tavily.com/search ';

var
  i : Integer;
  lQuery : String;
  lHTTP : TFPHTTPClient;
  lJSON : TJSONObject;
  lResponse,lResult : TJSONObject;
  lSearchResults : TJSONArray;

begin
  lQuery:=aINput.Get('query','');
  lHTTP:=TFPHTTPClient.Create(Nil);
  try
    lHTTP.AddHeader('Authorization','Bearer '+APIKey);
    lHTTP.AddHeader('Content-Type','application/json');
    lJSON:=TJSONObject.Create(['query',lQuery]);
    lHTTP.RequestBody:=TStringStream.Create(lJSON.AsJSON);
    lResponse:=GetJSON(lHTTP.Post(SearchURL)) as TJSONObject;
  finally
    lJSON.Free;
    lHTTP.RequestBody.Free;
    lHTTP.Free;
  end;
  lSearchResults:=lResponse.Get('results',TJSONArray(Nil));
  SetLength(aResult,lSearchResults.Count);
  for I:=0 to lSearchResults.Count-1 do
    begin
    lResult:=lSearchResults.Objects[i];
    aResult[i]:=TMCPToolResult.CreateText(lResult.AsJSON);
    end;
end;

constructor TTavilySearchTool.create(const aName: string; const aDescription: string);
begin
  inherited create(aName, aDescription);
  InputSchema.AddArgument('query',TJSONObject.Create(['type','string']),True);
end;

{ TApplication }

procedure TApplication.DoRun;
var
  T : TTavilySearchTool;
begin
  T:=TTavilySearchTool.create('TavilySearch','Search the web using Tavily');
  T.ApiKey:=GetOptionValue('k','api-key');
  if T.ApiKey='' then
    T.ApiKey:=GetEnvironmentVariable('TAVILY_API_KEY');
  T.Register;
  // Show help for the server
  if HasOption('h','help') then
    begin
    writeln('Model Context Protocol Server [',{$INCLUDE %DATE%},']: '+Title);
    Halt;
    end;
  inherited DoRun;
end;

var
  Application : TApplication;

begin
  Application:=TApplication.Create(Nil);
  Application.Initialize;
  Application.Run;
  Application.Free;
end.

