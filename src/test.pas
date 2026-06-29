unit test;

{$mode objfpc}
{$modeswitch prefixedattributes}
{$modeswitch advancedrecords}

{$implicitexceptions off}
{$objectchecks off}
{$rangechecks off}

{-$omitrtti}

interface

uses
  exp_trees, sysutils, typinfo, classes, nodes;

const
  OBJ_ABSTRACT_NODE = 1;
  OBJ_BASE_NODE     = 2;
  OBJ_EXTENDED_NODE = 3;

type
  PAbstractNode = ^TAbstractNode;
  TAbstractNode = packed object
    constructor Initialize;
    function GetId: Integer; static;
    function GetVMT: PVmt;
    procedure SetVMT(Value: PVmt);
    property VMT: PVmt read GetVMT write SetVMT;
    procedure Test; virtual;
    function Size: Integer; virtual;
  end;

  PBaseNode = ^TBaseNode;
  TBaseNode = packed object(TAbstractNode)
    Node: TTreeNode;
    procedure Test; virtual;
  end;

  PExtendedNode = ^TExtendedNode;
  TExtendedNode = packed object(TBaseNode)
    X: Int64;
    Y: Int64;
    Z: Int64;
    procedure Test; virtual;
  end;

  TMockNode = packed record
    vmt: pointer;
    id: Integer;
    X, Y, Z: Int64;
  end;

procedure BaseTests;

implementation

var
  NODE_MAP: array [Byte] of Pointer;

function ObjectFromId(Id: Integer): Pointer;
begin
  Result := NODE_MAP[Id];
end;

procedure RegisterObject(vmt: Pvmt; id: Integer);
begin
  NODE_MAP[id] := vmt;
  vmt^.vInstanceSize2 := id;
end;

procedure RegisterObjects;
begin
  // Add all objects to a list (?)
  RegisterObject(TypeOf(TAbstractNode), OBJ_ABSTRACT_NODE);
  RegisterObject(TypeOf(TBaseNode),     OBJ_BASE_NODE);
  RegisterObject(TypeOf(TExtendedNode), OBJ_EXTENDED_NODE);
end;



{ TAbstractNode }

constructor TAbstractNode.Initialize;
begin
end;

function TAbstractNode.GetId: Integer;
begin
  Result := PVmt(Self)^.vInstanceSize2;
end;

function TAbstractNode.Size: Integer;
begin
  Result := SizeOf(Self);
end;

function TAbstractNode.GetVMT: PVmt;
begin
  Result := PVmt(Self);
end;

procedure TAbstractNode.SetVMT(Value: PVmt);
begin
  PPointer(UInt64(@Self))^ := Value;
end;

procedure TAbstractNode.Test;
begin
  WriteLn('TAbstractNode: Hello world!');
end;

{ TBaseNode }
procedure TBaseNode.Test;
begin
  inherited;
  WriteLn('TBaseNode: Hello world!');
end;

{ TExtendedNode }
procedure TExtendedNode.Test;
begin
  inherited;
  WriteLn('TExtendedNode: Hello world!');
end;

function NodeFromVMT(vmt: Pointer): PAbstractNode;
begin
  GetMem(PByte(Result), SizeOf(TAbstractNode(vmt)));
  PPointer(Result)^ := vmt;
end;

// rtl/inc/generic.inc
// {$ifndef FPC_SYSTEM_HAS_FPC_CHECK_OBJECT}
// procedure fpc_check_object(_vmt : pointer); [public,alias:'FPC_CHECK_OBJECT'];  compilerproc;
// begin
//   if (_vmt=nil) or
//      (pobjectvmt(_vmt)^.size=0) or
//      (pobjectvmt(_vmt)^.size+pobjectvmt(_vmt)^.msize<>0) then
//     HandleErrorAddrFrameInd(210,get_pc_addr,get_frame);
// end;

// {$endif ndef FPC_SYSTEM_HAS_FPC_CHECK_OBJECT}


procedure BaseTests;
var
  m: array [0..2] of TMockNode;
  p: array [0..2] of PAbstractNode;
begin
  m[0].vmt := TypeOf(TAbstractNode);
  m[1].vmt := TypeOf(TBaseNode);
  m[2].vmt := TypeOf(TExtendedNode);

  m[0].id := TAbstractNode.GetId;
  m[1].id := TBaseNode.GetId;
  m[2].id := TExtendedNode.GetId;

  p[0] := NodeFromVMT(ObjectFromId(m[0].id));
  p[1] := NodeFromVMT(ObjectFromId(m[1].id));
  p[2] := NodeFromVMT(ObjectFromId(m[2].id));

  WriteLn('SizeOf(TAbstractNode) = ', SizeOf(PAbstractNode(@m[0])^));
  WriteLn('SizeOf(TBaseNode)     = ', SizeOf(PAbstractNode(@m[1])^));
  WriteLn('SizeOf(TExtendedNode) = ', SizeOf(PAbstractNode(@m[2])^));

  WriteLn('TAbstractNode    : id = ', m[0].id);
  WriteLn('TBaseNode        : id = ', m[1].id);
  WriteLn('TExtendedNode    : id = ', m[2].id);

  WriteLn('TAbstractNode.id      = ', p[0]^.GetId);
  WriteLn('TBaseNode.id          = ', p[1]^.GetId);
  WriteLn('TExtendedNode.id      = ', p[2]^.GetId);

  WriteLn('TAbstractNode.id      = ', TAbstractNode.GetId);
  WriteLn('TBaseNode.id          = ', TBaseNode.GetId);
  WriteLn('TExtendedNode.id      = ', TExtendedNode.GetId);

  WriteLn('SizeOf(TAbstractNode) = ', SizeOf(p[0]^));
  WriteLn('SizeOf(TBaseNode)     = ', SizeOf(p[1]^));
  WriteLn('SizeOf(TExtendedNode) = ', SizeOf(p[2]^));
end;

// 0x52f250
// 0x52f288
// 0x52f2c0

initialization
  //TBaseNode.CODE := 123;
  //TAbstractNode.GetId;

  // TAbstractNode.id := 112;
  // TBaseNode.id := 222;
  // TExtendedNode.id := 333;

  // WriteLn(TAbstractNode.id);
  // WriteLn(TBaseNode.id);
  // WriteLn(TExtendedNode.id);

  //InitializeNodeMap;
  RegisterObjects;

  BaseTests;

// TEST OUTPUT:
// SizeOf(TAbstractNode) = 8
// SizeOf(TBaseNode)     = 24
// SizeOf(TExtendedNode) = 48
// TAbstractNode    : id = 1
// TBaseNode        : id = 2
// TExtendedNode    : id = 3
// SizeOf(TAbstractNode) = 8
// SizeOf(TBaseNode)     = 24
// SizeOf(TExtendedNode) = 48

end.
