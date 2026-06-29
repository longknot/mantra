unit runtime_output;

{$I mantra.inc}

interface

uses
  fpjson;

type
  TOutputLineSink = procedure(const LineText: ansistring) of object;

type
  TRuntimeRichOutput = class
  public
    MimeType: ansistring;
    Encoding: ansistring;
    Data: TJSONData;
    Metadata: TJSONObject;
    constructor Create(
      const AMimeType: ansistring;
      AData: TJSONData;
      const AEncoding: ansistring = ''
    );
    destructor Destroy; override;
  end;

  TRichOutputSink = procedure(Output: TRuntimeRichOutput) of object;

procedure SetRuntimeOutputSink(Sink: TOutputLineSink);
procedure ClearRuntimeOutputSink;
procedure EmitRuntimeOutputLine(const LineText: ansistring);
procedure SetRuntimeRichOutputSink(Sink: TRichOutputSink);
procedure ClearRuntimeRichOutputSink;
procedure EmitRuntimeJsonOutput(
  const MimeType: ansistring;
  Data: TJSONData
);

implementation

var
  RuntimeOutputSink: TOutputLineSink = nil;
  RuntimeRichOutputSink: TRichOutputSink = nil;

constructor TRuntimeRichOutput.Create(
  const AMimeType: ansistring;
  AData: TJSONData;
  const AEncoding: ansistring
);
begin
  inherited Create;
  MimeType := AMimeType;
  Encoding := AEncoding;
  Data := AData;
  Metadata := TJSONObject.Create;
end;

destructor TRuntimeRichOutput.Destroy;
begin
  Metadata.Free;
  Data.Free;
  inherited Destroy;
end;

procedure SetRuntimeOutputSink(Sink: TOutputLineSink);
begin
  RuntimeOutputSink := Sink;
end;

procedure ClearRuntimeOutputSink;
begin
  RuntimeOutputSink := nil;
end;

procedure EmitRuntimeOutputLine(const LineText: ansistring);
begin
  if Assigned(RuntimeOutputSink) then
    RuntimeOutputSink(LineText)
  else
    WriteLn(LineText);
end;

procedure SetRuntimeRichOutputSink(Sink: TRichOutputSink);
begin
  RuntimeRichOutputSink := Sink;
end;

procedure ClearRuntimeRichOutputSink;
begin
  RuntimeRichOutputSink := nil;
end;

procedure EmitRuntimeJsonOutput(
  const MimeType: ansistring;
  Data: TJSONData
);
var
  Output: TRuntimeRichOutput;
begin
  Output := TRuntimeRichOutput.Create(MimeType, Data);
  if Assigned(RuntimeRichOutputSink) then
    RuntimeRichOutputSink(Output)
  else
  begin
    try
      if Assigned(Output.Data) then
        WriteLn(Output.Data.AsJSON);
    finally
      Output.Free;
    end;
  end;
end;

end.
