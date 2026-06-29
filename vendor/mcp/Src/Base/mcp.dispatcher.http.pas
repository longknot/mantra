unit mcp.dispatcher.http;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, mcp.dispatcher.base, mcp.handler, httpdefs, fpjson;

Type

  { TMCPHTTPDispatcher }

  TMCPHTTPDispatcher = class(TMCPLocalDispatcher)
  private
    FSessionID: String;
  protected
    function CreateContext: TMCPContext; override;
  public
    property SessionID : String Read FSessionID Write FSessionID;
  end;



implementation

{ TMCPHTTPDispatcher }

function TMCPHTTPDispatcher.CreateContext: TMCPContext;
begin
  Result:=inherited CreateContext;
  Result.SessionID:=Self.SessionID;
end;

end.

