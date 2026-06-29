unit http_operation;

{$I mantra.inc}

interface

uses
  context;

function ExecuteHttpOperation(
  Context: TContext;
  const DestPrefix: ansistring;
  const RequestPath: ansistring;
  out ResultHandle: ansistring;
  out ErrorText: ansistring
): Integer;

procedure RegisterHttpOperation;

implementation

uses
  Classes, SysUtils, fphttpclient, fpjson, jsonparser, opensslsockets,
  URIParser, NetDB, Sockets, Math, parsetree, json_value_codec,
  runtime_settings, external_operations;

const
  DEFAULT_TIMEOUT_MS = 10000;
  DEFAULT_MAX_RESPONSE_BYTES = 1024 * 1024;
  DEFAULT_MAX_REDIRECTS = 3;

type
  EHttpResponseTooLarge = class(Exception);

  TLimitedMemoryStream = class(TMemoryStream)
  private
    FMaximumSize: Int64;
  public
    constructor Create(AMaximumSize: Int64);
    function Write(const Buffer; Count: LongInt): LongInt; override;
  end;

  THttpPolicy = record
    Enabled: Boolean;
    AllowedSchemes: ansistring;
    AllowedHosts: ansistring;
    DeniedHosts: ansistring;
    AllowPrivateNetworks: Boolean;
    TimeoutMs: Integer;
    MaxResponseBytes: Integer;
    MaxRedirects: Integer;
  end;

constructor TLimitedMemoryStream.Create(AMaximumSize: Int64);
begin
  inherited Create;
  FMaximumSize := AMaximumSize;
end;

function TLimitedMemoryStream.Write(
  const Buffer;
  Count: LongInt
): LongInt;
begin
  if (Count < 0) or
     ((FMaximumSize >= 0) and (Size + Count > FMaximumSize)) then
    raise EHttpResponseTooLarge.CreateFmt(
      'HTTP response exceeds %d bytes',
      [FMaximumSize]
    );
  Result := inherited Write(Buffer, Count);
end;

function JsonScalarText(JsonValue: TJSONData; out Value: ansistring): Boolean;
begin
  Result := False;
  Value := '';
  if JsonValue = nil then
    Exit(False);
  case JsonValue.JSONType of
    jtString:
      Value := JsonValue.AsString;
    jtNumber:
      Value := JsonValue.AsJSON;
    jtBoolean:
      if JsonValue.AsBoolean then
        Value := 'true'
      else
        Value := 'false';
    jtNull:
      Value := '';
  else
    Exit(False);
  end;
  Result := True;
end;

function JsonObjectString(
  JsonObject: TJSONObject;
  const Name, DefaultValue: ansistring;
  out Value: ansistring
): Boolean;
var
  JsonValue: TJSONData;
begin
  Value := DefaultValue;
  JsonValue := JsonObject.Find(Name);
  if JsonValue = nil then
    Exit(True);
  Result := JsonValue.JSONType = jtString;
  if Result then
    Value := JsonValue.AsString;
end;

function JsonObjectInteger(
  JsonObject: TJSONObject;
  const Name: ansistring;
  DefaultValue: Integer;
  out Value: Integer
): Boolean;
var
  JsonValue: TJSONData;
  ParsedValue: Int64;
begin
  Value := DefaultValue;
  JsonValue := JsonObject.Find(Name);
  if JsonValue = nil then
    Exit(True);
  if JsonValue.JSONType <> jtNumber then
    Exit(False);
  ParsedValue := JsonValue.AsInt64;
  Result := (ParsedValue >= 0) and (ParsedValue <= High(Integer));
  if Result then
    Value := Integer(ParsedValue);
end;

function JsonObjectBoolean(
  JsonObject: TJSONObject;
  const Name: ansistring;
  DefaultValue: Boolean;
  out Value: Boolean
): Boolean;
var
  JsonValue: TJSONData;
begin
  Value := DefaultValue;
  JsonValue := JsonObject.Find(Name);
  if JsonValue = nil then
    Exit(True);
  Result := JsonValue.JSONType = jtBoolean;
  if Result then
    Value := JsonValue.AsBoolean;
end;

function ReadBooleanPolicySetting(
  Context: TContext;
  const Name: ansistring;
  DefaultValue: Boolean;
  out Value: Boolean;
  out ErrorText: ansistring
): Boolean;
var
  SourceName: ansistring;
begin
  ErrorText := '';
  case ReadBooleanSetting(GlobalTree, Context, [Name], Value, SourceName) of
    srrNotFound:
      Value := DefaultValue;
    srrInvalid:
      begin
        ErrorText := 'invalid boolean setting: ' + SourceName;
        Exit(False);
      end;
  end;
  Result := True;
end;

function ReadIntegerPolicySetting(
  Context: TContext;
  const Name: ansistring;
  DefaultValue: Integer;
  out Value: Integer;
  out ErrorText: ansistring
): Boolean;
var
  SourceName: ansistring;
begin
  ErrorText := '';
  case ReadIntegerSetting(GlobalTree, Context, [Name], Value, SourceName) of
    srrNotFound:
      Value := DefaultValue;
    srrInvalid:
      begin
        ErrorText := 'invalid integer setting: ' + SourceName;
        Exit(False);
      end;
  end;
  Result := True;
end;

function ReadStringPolicySetting(
  Context: TContext;
  const Name, DefaultValue: ansistring;
  out Value: ansistring;
  out ErrorText: ansistring
): Boolean;
var
  SourceName: ansistring;
begin
  ErrorText := '';
  case ReadStringSetting(GlobalTree, Context, [Name], Value, SourceName) of
    srrNotFound:
      Value := DefaultValue;
    srrInvalid:
      begin
        ErrorText := 'invalid string setting: ' + SourceName;
        Exit(False);
      end;
  end;
  Result := True;
end;

function LoadHttpPolicy(
  Context: TContext;
  out Policy: THttpPolicy;
  out ErrorText: ansistring
): Boolean;
var
  ExternalEnabled: Boolean;
  HttpEnabled: Boolean;
begin
  Result := False;
  ErrorText := '';
  if not ReadBooleanPolicySetting(
    Context,
    'mantra.external.enabled',
    False,
    ExternalEnabled,
    ErrorText
  ) then
    Exit(False);
  if not ReadBooleanPolicySetting(
    Context,
    'mantra.external.http.enabled',
    True,
    HttpEnabled,
    ErrorText
  ) then
    Exit(False);
  Policy.Enabled := ExternalEnabled and HttpEnabled;
  if not ReadStringPolicySetting(
    Context,
    'mantra.external.http.allowed_schemes',
    'https',
    Policy.AllowedSchemes,
    ErrorText
  ) then
    Exit(False);
  if not ReadStringPolicySetting(
    Context,
    'mantra.external.http.allowed_hosts',
    '',
    Policy.AllowedHosts,
    ErrorText
  ) then
    Exit(False);
  if not ReadStringPolicySetting(
    Context,
    'mantra.external.http.denied_hosts',
    '',
    Policy.DeniedHosts,
    ErrorText
  ) then
    Exit(False);
  if not ReadBooleanPolicySetting(
    Context,
    'mantra.external.http.allow_private_networks',
    False,
    Policy.AllowPrivateNetworks,
    ErrorText
  ) then
    Exit(False);
  if not ReadIntegerPolicySetting(
    Context,
    'mantra.external.http.timeout_ms',
    DEFAULT_TIMEOUT_MS,
    Policy.TimeoutMs,
    ErrorText
  ) then
    Exit(False);
  if not ReadIntegerPolicySetting(
    Context,
    'mantra.external.http.max_response_bytes',
    DEFAULT_MAX_RESPONSE_BYTES,
    Policy.MaxResponseBytes,
    ErrorText
  ) then
    Exit(False);
  if not ReadIntegerPolicySetting(
    Context,
    'mantra.external.http.max_redirects',
    DEFAULT_MAX_REDIRECTS,
    Policy.MaxRedirects,
    ErrorText
  ) then
    Exit(False);

  if Policy.TimeoutMs <= 0 then
  begin
    ErrorText := 'mantra.external.http.timeout_ms must be greater than zero';
    Exit(False);
  end;
  if Policy.MaxResponseBytes <= 0 then
  begin
    ErrorText := 'mantra.external.http.max_response_bytes must be greater than zero';
    Exit(False);
  end;
  if Policy.MaxRedirects < 0 then
  begin
    ErrorText := 'mantra.external.http.max_redirects cannot be negative';
    Exit(False);
  end;
  Result := True;
end;

function ListContainsToken(
  const ListText, Token: ansistring
): Boolean;
var
  Values: TStringList;
  I: Integer;
  NormalizedToken: ansistring;
begin
  Result := False;
  NormalizedToken := LowerCase(Trim(Token));
  Values := TStringList.Create;
  try
    Values.StrictDelimiter := True;
    Values.Delimiter := ',';
    Values.DelimitedText := ListText;
    for I := 0 to Values.Count - 1 do
      if LowerCase(Trim(Values[I])) = NormalizedToken then
        Exit(True);
  finally
    Values.Free;
  end;
end;

function HostMatchesPattern(
  const HostName, Pattern: ansistring
): Boolean;
var
  HostValue: ansistring;
  PatternValue: ansistring;
  Suffix: ansistring;
begin
  HostValue := LowerCase(Trim(HostName));
  PatternValue := LowerCase(Trim(Pattern));
  if (HostValue = '') or (PatternValue = '') then
    Exit(False);
  if HostValue = PatternValue then
    Exit(True);
  if Copy(PatternValue, 1, 2) <> '*.' then
    Exit(False);
  Suffix := Copy(PatternValue, 2, MaxInt);
  Result := (Length(HostValue) > Length(Suffix)) and
            (Copy(HostValue, Length(HostValue) - Length(Suffix) + 1, MaxInt) = Suffix);
end;

function HostMatchesList(
  const HostName, ListText: ansistring
): Boolean;
var
  Values: TStringList;
  I: Integer;
begin
  Result := False;
  Values := TStringList.Create;
  try
    Values.StrictDelimiter := True;
    Values.Delimiter := ',';
    Values.DelimitedText := ListText;
    for I := 0 to Values.Count - 1 do
      if HostMatchesPattern(HostName, Values[I]) then
        Exit(True);
  finally
    Values.Free;
  end;
end;

function IsForbiddenIPv4(const Address: THostAddr): Boolean;
var
  AddressText: ansistring;
  Parts: TStringList;
  A, B, C: Integer;
begin
  if NetAddrIsPrivate(Address) then
    Exit(True);
  AddressText := NetAddrToStr(Address);
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := '.';
    Parts.DelimitedText := AddressText;
    if Parts.Count <> 4 then
      Exit(True);
    A := StrToIntDef(Parts[0], -1);
    B := StrToIntDef(Parts[1], -1);
    C := StrToIntDef(Parts[2], -1);
    Result :=
      (A < 1) or
      (A = 127) or
      ((A = 169) and (B = 254)) or
      ((A = 100) and (B >= 64) and (B <= 127)) or
      ((A = 192) and (B = 0) and ((C = 0) or (C = 2))) or
      ((A = 192) and (B = 88) and (C = 99)) or
      ((A = 198) and ((B = 18) or (B = 19))) or
      ((A = 198) and (B = 51) and (C = 100)) or
      ((A = 203) and (B = 0) and (C = 113)) or
      (A >= 224);
  finally
    Parts.Free;
  end;
end;

function IsForbiddenIPv6(const Address: THostAddr6): Boolean;
var
  AddressText: ansistring;
begin
  if NetAddrIsPrivate6(Address) then
    Exit(True);
  AddressText := LowerCase(NetAddrToStr6(Address));
  Result :=
    (AddressText = '::') or
    (AddressText = '::1') or
    (Copy(AddressText, 1, 2) = 'ff') or
    (Copy(AddressText, 1, 3) = 'fe8') or
    (Copy(AddressText, 1, 3) = 'fe9') or
    (Copy(AddressText, 1, 3) = 'fea') or
    (Copy(AddressText, 1, 3) = 'feb') or
    (Copy(AddressText, 1, 9) = '2001:db8:') or
    (Copy(AddressText, 1, 7) = '::ffff:');
end;

function SameHttpOrigin(const LeftUrl, RightUrl: ansistring): Boolean;
var
  LeftUri: TURI;
  RightUri: TURI;
begin
  try
    LeftUri := ParseURI(LeftUrl);
    RightUri := ParseURI(RightUrl);
  except
    Exit(False);
  end;
  Result :=
    SameText(LeftUri.Protocol, RightUri.Protocol) and
    SameText(LeftUri.Host, RightUri.Host) and
    (LeftUri.Port = RightUri.Port);
end;

function ValidateHttpUrl(
  const Url: ansistring;
  const Policy: THttpPolicy;
  out ParsedUri: TURI;
  out ErrorKind: ansistring;
  out ErrorText: ansistring
): Boolean;
var
  Scheme: ansistring;
  HostName: ansistring;
  Addresses: array[0..MaxResolveAddr - 1] of THostAddr;
  Addresses6: array[0..MaxResolveAddr - 1] of THostAddr6;
  LiteralAddress: THostAddr;
  LiteralAddress6: THostAddr6;
  AddressCount: LongInt;
  I: Integer;
  ResolvedCount: Integer;
begin
  Result := False;
  ErrorKind := 'invalid_request';
  ErrorText := '';
  try
    ParsedUri := ParseURI(Trim(Url));
  except
    on E: Exception do
    begin
      ErrorText := 'invalid HTTP URL: ' + E.Message;
      Exit(False);
    end;
  end;

  Scheme := LowerCase(Trim(ParsedUri.Protocol));
  HostName := LowerCase(Trim(ParsedUri.Host));
  if (Scheme = '') or (HostName = '') then
  begin
    ErrorText := 'HTTP URL requires a scheme and host';
    Exit(False);
  end;
  if not ListContainsToken(Policy.AllowedSchemes, Scheme) then
  begin
    ErrorKind := 'policy';
    ErrorText := 'HTTP scheme is not allowed: ' + Scheme;
    Exit(False);
  end;
  if (Trim(Policy.AllowedHosts) <> '') and
     (not HostMatchesList(HostName, Policy.AllowedHosts)) then
  begin
    ErrorKind := 'policy';
    ErrorText := 'HTTP host is not allowlisted: ' + HostName;
    Exit(False);
  end;
  if HostMatchesList(HostName, Policy.DeniedHosts) then
  begin
    ErrorKind := 'policy';
    ErrorText := 'HTTP host is denied: ' + HostName;
    Exit(False);
  end;

  ResolvedCount := 0;
  if TryStrToNetAddr(HostName, LiteralAddress) then
  begin
    ResolvedCount := 1;
    if (not Policy.AllowPrivateNetworks) and IsForbiddenIPv4(LiteralAddress) then
    begin
      ErrorKind := 'policy';
      ErrorText := 'HTTP host resolves to a non-public IPv4 address';
      Exit(False);
    end;
  end;
  if (ResolvedCount = 0) and TryStrToHostAddr6(HostName, LiteralAddress6) then
  begin
    ResolvedCount := 1;
    if (not Policy.AllowPrivateNetworks) and IsForbiddenIPv6(LiteralAddress6) then
    begin
      ErrorKind := 'policy';
      ErrorText := 'HTTP host resolves to a non-public IPv6 address';
      Exit(False);
    end;
  end;
  if ResolvedCount = 0 then
  begin
    AddressCount := ResolveName(HostName, Addresses);
    if AddressCount > 0 then
    begin
      Inc(ResolvedCount, AddressCount);
      if not Policy.AllowPrivateNetworks then
        for I := 0 to AddressCount - 1 do
          if IsForbiddenIPv4(Addresses[I]) then
          begin
            ErrorKind := 'policy';
            ErrorText := 'HTTP host resolves to a non-public IPv4 address';
            Exit(False);
          end;
    end;
    AddressCount := ResolveName6(HostName, Addresses6);
    if AddressCount > 0 then
    begin
      Inc(ResolvedCount, AddressCount);
      if not Policy.AllowPrivateNetworks then
        for I := 0 to AddressCount - 1 do
          if IsForbiddenIPv6(Addresses6[I]) then
          begin
            ErrorKind := 'policy';
            ErrorText := 'HTTP host resolves to a non-public IPv6 address';
            Exit(False);
          end;
    end;
  end;
  if ResolvedCount = 0 then
  begin
    ErrorKind := 'dns';
    ErrorText := 'HTTP host could not be resolved: ' + HostName;
    Exit(False);
  end;
  Result := True;
end;

function PercentEncode(const Value: ansistring): ansistring;
var
  I: Integer;
  C: Byte;
begin
  Result := '';
  for I := 1 to Length(Value) do
  begin
    C := Byte(Value[I]);
    if (C in [Ord('a')..Ord('z')]) or
       (C in [Ord('A')..Ord('Z')]) or
       (C in [Ord('0')..Ord('9')]) or
       (C = Ord('-')) or (C = Ord('.')) or
       (C = Ord('_')) or (C = Ord('~')) then
      Result := Result + AnsiChar(C)
    else
      Result := Result + '%' + IntToHex(C, 2);
  end;
end;

procedure AppendQueryPair(
  var Url: ansistring;
  const Name, Value: ansistring;
  var HasQuery: Boolean
);
begin
  if not HasQuery then
  begin
    if Pos('?', Url) = 0 then
      Url := Url + '?'
    else if (Url <> '') and
            (Url[Length(Url)] <> '?') and
            (Url[Length(Url)] <> '&') then
      Url := Url + '&';
    HasQuery := True;
  end
  else
    Url := Url + '&';
  Url := Url + PercentEncode(Name) + '=' + PercentEncode(Value);
end;

function AppendQueryObject(
  var Url: ansistring;
  QueryObject: TJSONObject;
  out ErrorText: ansistring
): Boolean;
var
  I, J: Integer;
  ValueText: ansistring;
  JsonValue: TJSONData;
  JsonArray: TJSONArray;
  HasQuery: Boolean;
begin
  Result := False;
  ErrorText := '';
  HasQuery := Pos('?', Url) > 0;
  for I := 0 to QueryObject.Count - 1 do
  begin
    JsonValue := QueryObject.Items[I];
    if JsonValue.JSONType = jtArray then
    begin
      JsonArray := TJSONArray(JsonValue);
      for J := 0 to JsonArray.Count - 1 do
      begin
        if not JsonScalarText(JsonArray.Items[J], ValueText) then
        begin
          ErrorText := 'HTTP query values must be scalars or scalar arrays';
          Exit(False);
        end;
        AppendQueryPair(Url, QueryObject.Names[I], ValueText, HasQuery);
      end;
    end
    else
    begin
      if not JsonScalarText(JsonValue, ValueText) then
      begin
        ErrorText := 'HTTP query values must be scalars or scalar arrays';
        Exit(False);
      end;
      AppendQueryPair(Url, QueryObject.Names[I], ValueText, HasQuery);
    end;
  end;
  Result := True;
end;

function HeaderIsForbidden(const Name: ansistring): Boolean;
var
  HeaderName: ansistring;
begin
  HeaderName := LowerCase(Trim(Name));
  Result :=
    (HeaderName = 'host') or
    (HeaderName = 'content-length') or
    (HeaderName = 'transfer-encoding') or
    (HeaderName = 'connection') or
    (HeaderName = 'proxy-connection');
end;

function HeaderValueIsSafe(const Value: ansistring): Boolean;
begin
  Result := (Pos(#10, Value) = 0) and (Pos(#13, Value) = 0);
end;

function ApplyRequestHeaders(
  Client: TFPHTTPClient;
  HeadersObject: TJSONObject;
  out HasContentType: Boolean;
  out ErrorText: ansistring
): Boolean;
var
  I, J: Integer;
  HeaderName: ansistring;
  HeaderValue: ansistring;
  JsonValue: TJSONData;
  JsonArray: TJSONArray;
begin
  Result := False;
  HasContentType := False;
  ErrorText := '';
  for I := 0 to HeadersObject.Count - 1 do
  begin
    HeaderName := HeadersObject.Names[I];
    if (Trim(HeaderName) = '') or
       (Pos(#10, HeaderName) > 0) or
       (Pos(#13, HeaderName) > 0) then
    begin
      ErrorText := 'HTTP header name is invalid';
      Exit(False);
    end;
    if HeaderIsForbidden(HeaderName) then
    begin
      ErrorText := 'HTTP header is managed by the transport: ' + HeaderName;
      Exit(False);
    end;
    if SameText(HeaderName, 'Content-Type') then
      HasContentType := True;

    JsonValue := HeadersObject.Items[I];
    if JsonValue.JSONType = jtArray then
    begin
      JsonArray := TJSONArray(JsonValue);
      for J := 0 to JsonArray.Count - 1 do
      begin
        if not JsonScalarText(JsonArray.Items[J], HeaderValue) or
           (not HeaderValueIsSafe(HeaderValue)) then
        begin
          ErrorText := 'HTTP header values must be safe scalars';
          Exit(False);
        end;
        Client.AddHeader(HeaderName, HeaderValue);
      end;
    end
    else
    begin
      if not JsonScalarText(JsonValue, HeaderValue) or
         (not HeaderValueIsSafe(HeaderValue)) then
      begin
        ErrorText := 'HTTP header values must be safe scalars';
        Exit(False);
      end;
      Client.AddHeader(HeaderName, HeaderValue);
    end;
  end;
  Result := True;
end;

function MemoryStreamText(Stream: TMemoryStream): ansistring;
begin
  if Stream.Size > High(SizeInt) then
    raise Exception.Create('HTTP response is too large for this platform');
  SetLength(Result, SizeInt(Stream.Size));
  Stream.Position := 0;
  if Stream.Size > 0 then
    Stream.ReadBuffer(Result[1], SizeInt(Stream.Size));
end;

function ResponseHeaderValue(
  Headers: TStrings;
  const Name: ansistring
): ansistring;
var
  I, SeparatorPos: Integer;
  HeaderName: ansistring;
begin
  Result := '';
  for I := 0 to Headers.Count - 1 do
  begin
    SeparatorPos := Pos(':', Headers[I]);
    if SeparatorPos <= 0 then
      Continue;
    HeaderName := Trim(Copy(Headers[I], 1, SeparatorPos - 1));
    if SameText(HeaderName, Name) then
      Exit(Trim(Copy(Headers[I], SeparatorPos + 1, MaxInt)));
  end;
end;

function ResponseHeadersJson(Headers: TStrings): TJSONObject;
var
  I, SeparatorPos: Integer;
  HeaderName: ansistring;
  HeaderValue: ansistring;
  Existing: TJSONData;
begin
  Result := TJSONObject.Create;
  for I := 0 to Headers.Count - 1 do
  begin
    SeparatorPos := Pos(':', Headers[I]);
    if SeparatorPos <= 0 then
      Continue;
    HeaderName := Trim(Copy(Headers[I], 1, SeparatorPos - 1));
    HeaderValue := Trim(Copy(Headers[I], SeparatorPos + 1, MaxInt));
    if HeaderName = '' then
      Continue;
    Existing := Result.Find(HeaderName);
    if Existing = nil then
      Result.Add(HeaderName, HeaderValue)
    else
      Existing.AsString := Existing.AsString + ', ' + HeaderValue;
  end;
end;

function IsJsonMediaType(const ContentType: ansistring): Boolean;
var
  MediaType: ansistring;
  SeparatorPos: Integer;
begin
  MediaType := LowerCase(Trim(ContentType));
  SeparatorPos := Pos(';', MediaType);
  if SeparatorPos > 0 then
    MediaType := Trim(Copy(MediaType, 1, SeparatorPos - 1));
  Result := (MediaType = 'application/json') or
            ((Length(MediaType) > 5) and
             (Copy(MediaType, Length(MediaType) - 4, 5) = '+json'));
end;

function IsRedirectStatus(StatusCode: Integer): Boolean;
begin
  Result :=
    (StatusCode = 301) or
    (StatusCode = 302) or
    (StatusCode = 303) or
    (StatusCode = 307) or
    (StatusCode = 308);
end;

procedure PopulateAllowedResponseCodes(out Codes: array of LongInt);
var
  I: Integer;
begin
  for I := 0 to High(Codes) do
    Codes[I] := I + 100;
end;

function PerformSingleRequest(
  const Method, Url, BodyText: ansistring;
  HeadersObject: TJSONObject;
  DefaultJsonContentType: Boolean;
  ConnectTimeoutMs: Integer;
  TimeoutMs: Integer;
  MaxResponseBytes: Integer;
  out StatusCode: Integer;
  out StatusText: ansistring;
  out ResponseHeaders: TStringList;
  out ResponseText: ansistring;
  out ErrorText: ansistring
): Boolean;
var
  Client: TFPHTTPClient;
  ResponseStream: TLimitedMemoryStream;
  RequestStream: TStringStream;
  AllowedCodes: array of LongInt;
  HasContentType: Boolean;
begin
  Result := False;
  ErrorText := '';
  StatusCode := 0;
  StatusText := '';
  ResponseText := '';
  ResponseHeaders := TStringList.Create;
  Client := TFPHTTPClient.Create(nil);
  ResponseStream := TLimitedMemoryStream.Create(MaxResponseBytes);
  RequestStream := nil;
  try
    Client.AllowRedirect := False;
    Client.MaxRedirects := 0;
    Client.VerifySSLCertificate := True;
    Client.ConnectTimeout := ConnectTimeoutMs;
    Client.IOTimeout := TimeoutMs;
    if not ApplyRequestHeaders(Client, HeadersObject, HasContentType, ErrorText) then
      Exit(False);
    if BodyText <> '' then
    begin
      if DefaultJsonContentType and (not HasContentType) then
        Client.AddHeader('Content-Type', 'application/json');
      RequestStream := TStringStream.Create(BodyText);
      Client.RequestBody := RequestStream;
    end;
    SetLength(AllowedCodes, 500);
    PopulateAllowedResponseCodes(AllowedCodes);
    Client.HTTPMethod(Method, Url, ResponseStream, AllowedCodes);
    StatusCode := Client.ResponseStatusCode;
    StatusText := Client.ResponseStatusText;
    ResponseHeaders.Assign(Client.ResponseHeaders);
    ResponseText := MemoryStreamText(ResponseStream);
    Result := True;
  except
    on E: EHttpResponseTooLarge do
      ErrorText := E.Message;
    on E: Exception do
      ErrorText := E.Message;
  end;
  RequestStream.Free;
  ResponseStream.Free;
  Client.Free;
  if not Result then
    FreeAndNil(ResponseHeaders);
end;

procedure AddErrorResponse(
  ResponseObject: TJSONObject;
  const Kind, MessageText, Url: ansistring;
  ElapsedMs: QWord
);
var
  ErrorObject: TJSONObject;
begin
  ResponseObject.Add('ok', False);
  ResponseObject.Add('status', 0);
  ResponseObject.Add('url', Url);
  ResponseObject.Add('elapsedMs', Int64(ElapsedMs));
  ErrorObject := TJSONObject.Create;
  ErrorObject.Add('kind', Kind);
  ErrorObject.Add('message', MessageText);
  ResponseObject.Add('error', ErrorObject);
end;

function MaterializeHttpResponse(
  Context: TContext;
  const DestPrefix: ansistring;
  ResponseObject: TJSONObject;
  out ResultHandle: ansistring;
  out ErrorText: ansistring
): Integer;
begin
  ResultHandle := '';
  ErrorText := '';
  Context.RemoveVariableSubtree(DestPrefix);
  if not MaterializeJsonValueAtPath(Context, DestPrefix, ResponseObject) then
  begin
    ErrorText := 'failed to materialize HTTP response at ' + DestPrefix;
    Exit(1);
  end;
  ResultHandle := DestPrefix;
  Result := 0;
end;

function ExecuteHttpOperation(
  Context: TContext;
  const DestPrefix: ansistring;
  const RequestPath: ansistring;
  out ResultHandle: ansistring;
  out ErrorText: ansistring
): Integer;
var
  Policy: THttpPolicy;
  RequestData: TJSONData;
  RequestObject: TJSONObject;
  HeadersData: TJSONData;
  HeadersObject: TJSONObject;
  QueryData: TJSONData;
  BodyData: TJSONData;
  BodyTextData: TJSONData;
  ResponseObject: TJSONObject;
  ResponseHeaders: TStringList;
  ParsedBody: TJSONData;
  ParsedUri: TURI;
  Method: ansistring;
  Url: ansistring;
  CurrentUrl: ansistring;
  NextUrl: ansistring;
  BodyText: ansistring;
  ResponseText: ansistring;
  StatusText: ansistring;
  ContentType: ansistring;
  OperationError: ansistring;
  ErrorKind: ansistring;
  StatusCode: Integer;
  TimeoutMs: Integer;
  ConnectTimeoutMs: Integer;
  MaxResponseBytes: Integer;
  MaxRedirects: Integer;
  RedirectCount: Integer;
  FollowRedirects: Boolean;
  StructuredBody: Boolean;
  AttemptTimeoutMs: Integer;
  StartedAt: QWord;
  ElapsedMs: QWord;
begin
  Result := 1;
  ResultHandle := '';
  ErrorText := '';
  RequestData := nil;
  ResponseObject := TJSONObject.Create;
  ResponseHeaders := nil;
  StartedAt := GetTickCount64;
  CurrentUrl := '';
  try
    if not Assigned(Context) then
    begin
      ErrorText := 'HTTP operation requires an execution context';
      Exit(1);
    end;
    if Trim(DestPrefix) = '' then
    begin
      ErrorText := 'HTTP response destination cannot be empty';
      Exit(1);
    end;
    if Trim(RequestPath) = '' then
    begin
      ErrorText := 'HTTP request path cannot be empty';
      Exit(1);
    end;

    if not LoadHttpPolicy(Context, Policy, OperationError) then
    begin
      AddErrorResponse(
        ResponseObject,
        'configuration',
        OperationError,
        '',
        GetTickCount64 - StartedAt
      );
      Exit(MaterializeHttpResponse(
        Context,
        DestPrefix,
        ResponseObject,
        ResultHandle,
        ErrorText
      ));
    end;
    if not Policy.Enabled then
    begin
      AddErrorResponse(
        ResponseObject,
        'disabled',
        'HTTP external operations are disabled',
        '',
        GetTickCount64 - StartedAt
      );
      Exit(MaterializeHttpResponse(
        Context,
        DestPrefix,
        ResponseObject,
        ResultHandle,
        ErrorText
      ));
    end;

    try
      RequestData := BuildJsonDataFromPath(Context, RequestPath);
    except
      on E: Exception do
      begin
        AddErrorResponse(
          ResponseObject,
          'invalid_request',
          E.Message,
          '',
          GetTickCount64 - StartedAt
        );
        Exit(MaterializeHttpResponse(
          Context,
          DestPrefix,
          ResponseObject,
          ResultHandle,
          ErrorText
        ));
      end;
    end;
    if RequestData.JSONType <> jtObject then
    begin
      AddErrorResponse(
        ResponseObject,
        'invalid_request',
        'HTTP request path must contain an object',
        '',
        GetTickCount64 - StartedAt
      );
      Exit(MaterializeHttpResponse(
        Context,
        DestPrefix,
        ResponseObject,
        ResultHandle,
        ErrorText
      ));
    end;
    RequestObject := TJSONObject(RequestData);

    if not JsonObjectString(RequestObject, 'method', 'GET', Method) then
      OperationError := 'HTTP method must be a string'
    else if not JsonObjectString(RequestObject, 'url', '', Url) or (Trim(Url) = '') then
      OperationError := 'HTTP URL must be a non-empty string'
    else
      OperationError := '';
    Method := UpperCase(Trim(Method));
    if (OperationError = '') and
       (not (Method = 'GET')) and
       (not (Method = 'POST')) and
       (not (Method = 'PUT')) and
       (not (Method = 'PATCH')) and
       (not (Method = 'DELETE')) and
       (not (Method = 'HEAD')) then
      OperationError := 'HTTP method is not supported: ' + Method;

    HeadersData := RequestObject.Find('headers');
    if (OperationError = '') and (HeadersData <> nil) and
       (HeadersData.JSONType <> jtObject) then
      OperationError := 'HTTP headers must be an object';
    if HeadersData = nil then
    begin
      HeadersObject := TJSONObject.Create;
      RequestObject.Add('headers', HeadersObject);
    end
    else
      HeadersObject := TJSONObject(HeadersData);

    QueryData := RequestObject.Find('query');
    if (OperationError = '') and (QueryData <> nil) and
       (QueryData.JSONType <> jtObject) then
      OperationError := 'HTTP query must be an object';

    BodyData := RequestObject.Find('body');
    BodyTextData := RequestObject.Find('body_text');
    StructuredBody := BodyData <> nil;
    if (OperationError = '') and (BodyData <> nil) and (BodyTextData <> nil) then
      OperationError := 'HTTP request cannot contain both body and body_text';
    BodyText := '';
    if (OperationError = '') and (BodyData <> nil) then
      BodyText := BodyData.AsJSON
    else if (OperationError = '') and (BodyTextData <> nil) then
      if BodyTextData.JSONType = jtString then
        BodyText := BodyTextData.AsString
      else
        OperationError := 'HTTP body_text must be a string';

    if not JsonObjectInteger(
      RequestObject,
      'timeout_ms',
      Policy.TimeoutMs,
      TimeoutMs
    ) then
      OperationError := 'HTTP timeout_ms must be a non-negative integer';
    if not JsonObjectInteger(
      RequestObject,
      'connect_timeout_ms',
      TimeoutMs,
      ConnectTimeoutMs
    ) then
      OperationError := 'HTTP connect_timeout_ms must be a non-negative integer';
    if not JsonObjectInteger(
      RequestObject,
      'max_response_bytes',
      Policy.MaxResponseBytes,
      MaxResponseBytes
    ) then
      OperationError := 'HTTP max_response_bytes must be a non-negative integer';
    if not JsonObjectBoolean(
      RequestObject,
      'follow_redirects',
      False,
      FollowRedirects
    ) then
      OperationError := 'HTTP follow_redirects must be a boolean';

    TimeoutMs := Min(TimeoutMs, Policy.TimeoutMs);
    ConnectTimeoutMs := Min(ConnectTimeoutMs, TimeoutMs);
    MaxResponseBytes := Min(MaxResponseBytes, Policy.MaxResponseBytes);
    MaxRedirects := Policy.MaxRedirects;
    if (TimeoutMs <= 0) or (ConnectTimeoutMs <= 0) then
      OperationError := 'HTTP timeouts must be greater than zero';
    if MaxResponseBytes <= 0 then
      OperationError := 'HTTP max_response_bytes must be greater than zero';

    CurrentUrl := Url;
    if (OperationError = '') and (QueryData <> nil) then
      if not AppendQueryObject(
        CurrentUrl,
        TJSONObject(QueryData),
        OperationError
      ) then
        OperationError := 'HTTP query: ' + OperationError;

    if OperationError <> '' then
    begin
      AddErrorResponse(
        ResponseObject,
        'invalid_request',
        OperationError,
        CurrentUrl,
        GetTickCount64 - StartedAt
      );
      Exit(MaterializeHttpResponse(
        Context,
        DestPrefix,
        ResponseObject,
        ResultHandle,
        ErrorText
      ));
    end;

    RedirectCount := 0;
    repeat
      ElapsedMs := GetTickCount64 - StartedAt;
      if ElapsedMs >= QWord(TimeoutMs) then
      begin
        AddErrorResponse(
          ResponseObject,
          'timeout',
          'HTTP operation exceeded its total timeout',
          CurrentUrl,
          ElapsedMs
        );
        Exit(MaterializeHttpResponse(
          Context,
          DestPrefix,
          ResponseObject,
          ResultHandle,
          ErrorText
        ));
      end;
      AttemptTimeoutMs := TimeoutMs - Integer(ElapsedMs);

      if not ValidateHttpUrl(
        CurrentUrl,
        Policy,
        ParsedUri,
        ErrorKind,
        OperationError
      ) then
      begin
        AddErrorResponse(
          ResponseObject,
          ErrorKind,
          OperationError,
          CurrentUrl,
          GetTickCount64 - StartedAt
        );
        Exit(MaterializeHttpResponse(
          Context,
          DestPrefix,
          ResponseObject,
          ResultHandle,
          ErrorText
        ));
      end;

      if not PerformSingleRequest(
        Method,
        CurrentUrl,
        BodyText,
        HeadersObject,
        StructuredBody,
        Min(ConnectTimeoutMs, AttemptTimeoutMs),
        AttemptTimeoutMs,
        MaxResponseBytes,
        StatusCode,
        StatusText,
        ResponseHeaders,
        ResponseText,
        OperationError
      ) then
      begin
        ElapsedMs := GetTickCount64 - StartedAt;
        if Pos('exceeds', LowerCase(OperationError)) > 0 then
          ErrorKind := 'response_too_large'
        else if (Pos('timed out', LowerCase(OperationError)) > 0) or
                (Pos('timeout', LowerCase(OperationError)) > 0) or
                (ElapsedMs >= QWord(TimeoutMs)) then
          ErrorKind := 'timeout'
        else
          ErrorKind := 'transport';
        AddErrorResponse(
          ResponseObject,
          ErrorKind,
          OperationError,
          CurrentUrl,
          ElapsedMs
        );
        Exit(MaterializeHttpResponse(
          Context,
          DestPrefix,
          ResponseObject,
          ResultHandle,
          ErrorText
        ));
      end;

      if FollowRedirects and IsRedirectStatus(StatusCode) then
      begin
        OperationError := ResponseHeaderValue(ResponseHeaders, 'Location');
        if OperationError = '' then
          Break;
        if RedirectCount >= MaxRedirects then
        begin
          ResponseHeaders.Free;
          ResponseHeaders := nil;
          AddErrorResponse(
            ResponseObject,
            'redirect_limit',
            'HTTP redirect limit exceeded',
            CurrentUrl,
            GetTickCount64 - StartedAt
          );
          Exit(MaterializeHttpResponse(
            Context,
            DestPrefix,
            ResponseObject,
            ResultHandle,
            ErrorText
          ));
        end;
        if not ResolveRelativeURI(CurrentUrl, OperationError, NextUrl) then
        begin
          ResponseHeaders.Free;
          ResponseHeaders := nil;
          AddErrorResponse(
            ResponseObject,
            'invalid_redirect',
            'HTTP redirect location is invalid',
            CurrentUrl,
            GetTickCount64 - StartedAt
          );
          Exit(MaterializeHttpResponse(
            Context,
            DestPrefix,
            ResponseObject,
            ResultHandle,
            ErrorText
          ));
        end;
        Inc(RedirectCount);
        if not SameHttpOrigin(CurrentUrl, NextUrl) then
        begin
          ResponseHeaders.Free;
          ResponseHeaders := nil;
          AddErrorResponse(
            ResponseObject,
            'redirect_policy',
            'cross-origin HTTP redirects are not allowed',
            CurrentUrl,
            GetTickCount64 - StartedAt
          );
          Exit(MaterializeHttpResponse(
            Context,
            DestPrefix,
            ResponseObject,
            ResultHandle,
            ErrorText
          ));
        end;
        CurrentUrl := NextUrl;
        if ((StatusCode = 301) or
            (StatusCode = 302) or
            (StatusCode = 303)) and
           (Method <> 'GET') and (Method <> 'HEAD') then
        begin
          Method := 'GET';
          BodyText := '';
        end;
        ResponseHeaders.Free;
        ResponseHeaders := nil;
        Continue;
      end;
      Break;
    until False;

    ElapsedMs := GetTickCount64 - StartedAt;
    ResponseObject.Add('ok', (StatusCode >= 200) and (StatusCode < 300));
    ResponseObject.Add('status', StatusCode);
    ResponseObject.Add('reason', StatusText);
    ResponseObject.Add('url', CurrentUrl);
    ResponseObject.Add('headers', ResponseHeadersJson(ResponseHeaders));
    ContentType := ResponseHeaderValue(ResponseHeaders, 'Content-Type');
    ResponseObject.Add('contentType', ContentType);
    ResponseObject.Add('bodyText', ResponseText);
    ResponseObject.Add('elapsedMs', Int64(ElapsedMs));
    if IsJsonMediaType(ContentType) and (Trim(ResponseText) <> '') then
    begin
      ParsedBody := nil;
      try
        ParsedBody := GetJSON(ResponseText);
        ResponseObject.Add('body', ParsedBody);
        ParsedBody := nil;
      except
        on E: Exception do
          ResponseObject.Add('bodyParseError', E.Message);
      end;
      ParsedBody.Free;
    end;

    Result := MaterializeHttpResponse(
      Context,
      DestPrefix,
      ResponseObject,
      ResultHandle,
      ErrorText
    );
  finally
    ResponseHeaders.Free;
    RequestData.Free;
    ResponseObject.Free;
  end;
end;

procedure RegisterHttpOperation;
begin
  RegisterExternalOperation('http.request', @ExecuteHttpOperation);
end;

end.
