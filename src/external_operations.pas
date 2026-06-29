unit external_operations;

{$I mantra.inc}

interface

uses
  context;

type
  TExternalOperation = function(
    Context: TContext;
    const DestPrefix: ansistring;
    const RequestPath: ansistring;
    out ResultHandle: ansistring;
    out ErrorText: ansistring
  ): Integer;

procedure RegisterExternalOperation(
  const Name: ansistring;
  Operation: TExternalOperation
);

function ExecuteExternalOperation(
  Context: TContext;
  const Name: ansistring;
  const DestPrefix: ansistring;
  const RequestPath: ansistring;
  out ResultHandle: ansistring;
  out ErrorText: ansistring
): Boolean;

implementation

uses
  SysUtils;

type
  TExternalOperationEntry = record
    Name: ansistring;
    Operation: TExternalOperation;
  end;

var
  OperationEntries: array of TExternalOperationEntry;

procedure RegisterExternalOperation(
  const Name: ansistring;
  Operation: TExternalOperation
);
var
  I: Integer;
begin
  if (Trim(Name) = '') or (not Assigned(Operation)) then
    raise Exception.Create('invalid external operation registration');

  for I := 0 to High(OperationEntries) do
    if SameText(OperationEntries[I].Name, Name) then
    begin
      OperationEntries[I].Operation := Operation;
      Exit;
    end;

  I := Length(OperationEntries);
  SetLength(OperationEntries, I + 1);
  OperationEntries[I].Name := Name;
  OperationEntries[I].Operation := Operation;
end;

function ExecuteExternalOperation(
  Context: TContext;
  const Name: ansistring;
  const DestPrefix: ansistring;
  const RequestPath: ansistring;
  out ResultHandle: ansistring;
  out ErrorText: ansistring
): Boolean;
var
  I: Integer;
  Status: Integer;
begin
  ResultHandle := '';
  ErrorText := '';
  for I := 0 to High(OperationEntries) do
    if SameText(OperationEntries[I].Name, Name) then
    begin
      Status := OperationEntries[I].Operation(
        Context,
        DestPrefix,
        RequestPath,
        ResultHandle,
        ErrorText
      );
      if (Status <> 0) and (ErrorText = '') then
        ErrorText := Format(
          'external operation "%s" failed with status %d',
          [Name, Status]
        );
      Exit(Status = 0);
    end;
  ErrorText := 'unknown external operation: ' + Name;
  Result := False;
end;

end.
