unit exp_trees;

{$I mantra.inc}

interface

uses
  Classes, SysUtils, exp_tokenizer;

const
  EOT = MaxInt; // $FFFF;   // "end of tree"

  TRAVERSE_CONTINUE = $0000;
  TRAVERSE_ABORT    = $0001;


type
  TCustomTree = class;

  TEdgeArray = array [0..1] of Integer;

  // Q: GetTokenID + GetTokenKey + SetTokenID
  // (expression token id / offset) <-> (tree node)
  // procedure TTreeNode.SetTokenID(Value: Cardinal);
  // var
  //   T: TCustomTree;
  // begin
  //   Assert(Token >= 0);
  //   T := GetTree;
  //   if Assigned(T) then
  //     T.Expression.Token[Token]^.ID := Value;
  // end;

  // old:
  // Expression.Token[Token] -> TTokenInfo (ID + Data)
  // new:
  // only save Data to node + use "child" to store token ID (index in expression)?

  PTreeNode = ^TTreeNode;
  TTreeNodeCallback = procedure (Node: PTreeNode; Data: Pointer) of object;
  TTreeNode = packed record
    //Meta: Byte;
    //Op: Byte;
    //Id: Word;
    // [ token = 24 bits | id = 8 bits ]
    // 1024 = 2^10 = 1 KB
    // 1024 * 1024 = 2^20 = 1 MB
    // 1024 * 1024 * 2^4 = 16 MB

    //function GetChild: Integer;
    //procedure SetChild(AValue: Integer);
    //property Child: Integer read GetChild write SetChild;
    //property LHS: Integer read GetChild write SetChild;

    function GetRefData: Integer;
    procedure SetRefData(RefData: Integer);
    property RefData: Integer read GetRefData write SetRefData;

    // function Prev: Integer;

    // Ref -> RefTable
    case Integer of
      0: (Data, Ref: Cardinal; Edge: TEdgeArray);
      1: (Id, Extra, Op, Meta: Byte; HRef, LRef: Word; LHS, RHS: Integer);
      // 1: (HData, LData: Word; Child, Next, Prev: Integer);


  (*
    Token: Integer; // TTokenInfo;
    Edge: TEdgeArray;
    property Child: Integer read Edge[0] write Edge[0];
    property Next:  Integer read Edge[1] write Edge[1];
    property Prev:  Integer read Edge[2] write Edge[2];
    property LHS: Integer read Edge[0] write Edge[0];
    property RHS: Integer read Edge[1] write Edge[1];
    // N: fold left = DFS, fold right = BFS

    // case Integer of
    //  0: (Child, Next, Prev: Word);
    //  1: (Tree: TTreeArray);  // shorthand for (Child, Next, Prev)

    // procedure Compute();
    // procedure SaveToExpression();
    procedure Traverse(ATree: TCustomTree; Callback: TTreeNodeCallback); virtual;
    // TraverseDFS -> child first
    // TraverseBFS -> next first
    function GetTree: TCustomTree; virtual;
    function GetTokenID: Cardinal; virtual;
    function GetTokenKey: Integer; virtual;
    procedure SetTokenID(Value: Cardinal); virtual;

    constructor Initialize;
    constructor Initialize(Flags: Integer);
    constructor Reinitialize;
    destructor Cleanup;

    property Tree: TCustomTree read GetTree;
    property TokenID: Cardinal read GetTokenID write SetTokenID;
    property TokenKey: Integer read GetTokenKey;

    class function RealVMT: Pointer;
    function GetVMT: Pointer;
    procedure SetVMT(Value: Pointer);
    property VMT: Pointer read GetVMT write SetVMT;
*)
    // function GetTokenID: Cardinal;
  end;

  TArrayOfTreeNode = array of TTreeNode;

  TTreeCallback = function(Index: Integer; Data: Pointer): Integer of object;


  { TAbstractTree }
  TAbstractTree = class
  end;

  { TCustomTree }
  TCustomTree = class(TAbstractTree)
  private
    FCount: Integer;
    FRevision: QWord;
    FDisposedNode: Integer;      // linked list of disposed nodes
    FTail: Integer;
    FExpression: TCustomExpression;
    //SetCount: Integer;
    function GetNode(Index: Integer): PTreeNode;
    function GetHead: PTreeNode;
    function GetRef(Index: Integer): Integer;
    function GetChild(Index: Integer): Integer;
    function GetNext(Index: Integer): Integer;
    // function GetPrev(Index: Integer): Integer;
    //function GetParent(Index: Integer): Integer;
    //function GetRoot(Index: Integer): Integer;
    function GetLastChild(Index: Integer): Integer;

    function GetFirstSibling(Index: Integer): Integer;
    function GetLastSibling(Index: Integer): Integer;
    function GetSibling(Index, Offset: Integer): Integer;

    function GetSize: Integer;
    procedure SetSize(ASize: Integer);
  protected
    function DisposableNode(Index: Integer; var Data: Integer): Integer;
    procedure InitializeNode(var ANode: TTreeNode); virtual;
    procedure Touch; inline;
  public
    FNodes: TArrayOfTreeNode;
    constructor Create; virtual;

    function AllocateNode: Integer;
    function DisposeNode(Index: Integer): Integer;

    function TraverseTree(Index, Flags: Integer; Data: Pointer;
      Callback: TTreeCallback): Integer;

    procedure Delete(APrev, Index: Integer);
    procedure DeleteRange(Y1, X1, X2: Integer);
    procedure DeleteInline(Index: Integer);
    procedure DeleteSubtree(APrev, Index: Integer);
    procedure DeleteLHS(Index: Integer);
    procedure DeleteRHS(Index: Integer);

    procedure Expand(APrev, Index: Integer);
    procedure ExpandInline(APrev, Index: Integer);

    procedure Insert(X1, X2, Y1, Y2: Integer);

    function Copy(X1, X2: Integer): Integer;
    function CopySubtree(Src, Dst: Integer): Integer;
    function CloneSubtree(Index: Integer): Integer;
    function CloneLHS(Index: Integer): Integer;
    function CloneRHS(Index: Integer): Integer;

    //procedure Replace(Src, Dst: Integer);
    //procedure Unlink(Index: Integer);
    // maximal node array size
    //procedure Extend; virtual;
    // minimal node array size
    procedure Compress;
    // procedure Optimize;
    //function IsChild(Index: Integer): Boolean;

    procedure LinkLHSorRHS(X, Z, Branch: Integer);
    function InsertNextOrChild(Index, Branch: Integer): Integer;

    // function InsertPrev
    function InsertNext(Index: Integer): Integer;
    function InsertChild(Index: Integer): Integer;
    //function InsertChild(Index: Integer): Integer;

    procedure LinkLHS(X, Y: Integer);
    procedure LinkRHS(X, Y: Integer);

    function SiblingCount(Index: Integer): Integer;

    // property Prev[Index: Integer]: Integer read GetPrev;
    property Next[Index: Integer]: Integer read GetNext;
    property FirstSibling[Index: Integer]: Integer read GetFirstSibling;
    property LastSibling[Index: Integer]: Integer read GetLastSibling;
    property Sibling[Index, Offset: Integer]: Integer read GetSibling;
    property Child[Index: Integer]: Integer read GetChild;
    property LastChild[Index: Integer]: Integer read GetLastChild;
    //property Parent[Index: Integer]: Integer read GetParent;
    property Ref[Index: Integer]: Integer read GetRef;
    //property Root[Index: Integer]: Integer read GetRoot;

    property LHS[Index: Integer]: Integer read GetChild;
    property RHS[Index: Integer]: Integer read GetNext;
    // "binary tree"
    // property Child[Index: Integer; LeftRight: Boolean]: Integer;

    function NodeIndex(Node: PTreeNode): Integer;
    property Node[Index: Integer]: PTreeNode read GetNode; default;
    //property Head: Integer read GetHead;
    property Tail: Integer read FTail;


    //property Token[Index: Integer]: TTokenInfo;
    property Expression: TCustomExpression read FExpression write FExpression;
    property Count: Integer read FCount;
    property Size: Integer read GetSize write SetSize;
    property Revision: QWord read FRevision;
  end;

  (*
const
  EMPTY_NODE: TTreeNode = (
    Token: (Id: 0; Raw: '');
    Tree: (EOT, EOT, EOT);
  );
*)

implementation

uses
  tokens, parsetree;

{ TCustomTree }

function TCustomTree.GetNode(Index: Integer):PTreeNode;
begin
  Result := @FNodes[Index];
end;

function TCustomTree.GetHead: PTreeNode;
begin
  Result := @FNodes[0];
end;

function TCustomTree.GetRef(Index: Integer): Integer;
begin
  Result := FNodes[Index].Ref;
end;

function TCustomTree.GetChild(Index: Integer): Integer;
begin
  Result := FNodes[Index].LHS;
end;

function TCustomTree.GetNext(Index: Integer): Integer;
begin
  Result := FNodes[Index].RHS;
end;

// function TCustomTree.GetPrev(Index: Integer): Integer;
// begin
//   Result := FNodes[Index].Prev;
// end;

constructor TCustomTree.Create;
begin
  FDisposedNode := EOT;
  FCount := 0;
  FRevision := 0;
  //Extend;
  //SetLength(FNodes, 1);
  //FNodes[0] := EMPTY_NODE;
end;

procedure TCustomTree.Touch;
begin
  Inc(FRevision);
end;

// Q: flags = [BFS, DFS, LEFT, RIGHT, RANDOM] ?
function TCustomTree.TraverseTree(Index, Flags: Integer; Data: Pointer; Callback: TTreeCallback): Integer;
begin
  Result := TRAVERSE_CONTINUE;
  if Index <> EOT then
  begin
    Result := Callback(Index, Data);
    if Result = TRAVERSE_CONTINUE then
    begin
      if TraverseTree(FNodes[Index].Edge[0], Flags, Data, Callback) = TRAVERSE_ABORT then Exit;
      if TraverseTree(FNodes[Index].Edge[1], Flags, Data, Callback) = TRAVERSE_ABORT then Exit;
    end;
  end;
end;

function TCustomTree.DisposableNode(Index: Integer; var Data: Integer): Integer;
begin
  Result := TRAVERSE_CONTINUE;
  if (FNodes[Index].Edge[0] = EOT) or (FNodes[Index].Edge[1] = EOT) then
  begin
    Data := Index;
    Result := TRAVERSE_ABORT;
  end;
end;

function TreeIndex(Node: PTreeNode; Index: Integer): Integer;
begin
  Result := -1;
  if Node^.Edge[0] = Index then Result := 0
  else if Node^.Edge[1] = Index then Result := 1;
  // else if Node^.Edge[2] = Index then Result := 2;
end;

function TCustomTree.AllocateNode: Integer;

  // Re-use node at Index.
  // P^.Ref -> linked to previously disposed node.
  function PopDisposedNode(Index: Integer): Integer;
  var
    //T: TEdgeArray;
    P: PTreeNode;
  begin
    P := @FNodes[Index];

    // both left and right exists => add both to linked list
    if (P^.LHS <> EOT) and (P^.RHS <> EOT) then
    begin
      FNodes[P^.LHS].Ref := P^.RHS;
      FNodes[P^.RHS].Ref := P^.Ref;
      Result := P^.LHS;
    end
    // only left exists => add left to linked list
    else if P^.LHS <> EOT then
    begin
      FNodes[P^.LHS].Ref := P^.Ref;
      Result := P^.LHS;
    end
    // only right exists => add right to linked list
    else if P^.RHS <> EOT then
    begin
      FNodes[P^.RHS].Ref := P^.Ref;
      Result := P^.RHS;
    end
    else
    // return next entry in linked list
    begin
      Result := P^.Ref;
    end;
  end;

begin
  if FDisposedNode = EOT then
  begin
    Result := FCount;
    Inc(FCount);
    //Result := Length(FNodes);
    //SetLength(FNodes, Result + 1);
  end
  else
  begin
    // N: disposed nodes have 3 subtrees (and no back-references)
    Result := FDisposedNode;
    FDisposedNode := PopDisposedNode(Result);
  end;
  InitializeNode(FNodes[Result]);
  Touch;
  //FNodes[Result].Initialize;
end;

procedure TCustomTree.InitializeNode(var ANode: TTreeNode);
begin
  //ANode.Initialize;
  ANode.ID := 0;
  ANode.Ref := 0;
  ANode.Edge[0] := EOT;
  ANode.Edge[1] := EOT;
end;

// function TCustomTree.GetParent(Index: Integer): Integer;
// begin
//   Result := FNodes[Index].Prev;
//   if (Result <> EOT) and (FNodes[Result].Child <> Index) then
//     Result := GetParent(Result);
// end;

// function TCustomTree.GetRoot(Index: Integer): Integer;
// begin
//   if FNodes[Index].Prev <> EOT then
//     Result := GetRoot(FNodes[Index].Prev)
//   else
//     Result := Index;
// end;

function TCustomTree.GetLastChild(Index: Integer): Integer;
begin
  Result := Index;
  if FNodes[Index].RHS <> EOT then Result := GetLastChild(FNodes[Index].RHS)
  else if FNodes[Index].LHS <> EOT then Result := GetLastChild(FNodes[Index].LHS);
end;

//  (Prev, Next, Child)
function TCustomTree.DisposeNode(Index: Integer): Integer;
begin
  Assert(FNodes[Index].RHS = EOT);

  //FNodes[Index].Next := FDisposedNode;
  //FNodes[FDisposedNode].Prev := Index;
  FNodes[Index].Ref := FDisposedNode;
  FDisposedNode := Index;
  Touch;
end;

// delete single node
// join (prev, next) + delete (child)
// Q: flags for subtree deletion (0, 1) ?
procedure TCustomTree.Delete(APrev, Index: Integer);
var
  ANext: Integer;
begin
  if Index <> EOT then
  begin
    Touch;
    // delete child node
    DeleteSubtree(Index, FNodes[Index].LHS);

    //APrev := FNodes[Index].Prev;
    ANext := FNodes[Index].RHS;
    if APrev <> EOT then
    begin
      // prev is parent node
      if FNodes[APrev].LHS = Index then FNodes[APrev].LHS := ANext;
      // prev is previous node
      if FNodes[APrev].RHS = Index then FNodes[APrev].RHS := ANext;
    end;

    // if ANext <> EOT then FNodes[ANext].Prev := APrev;

    //FNodes[Index].VMT := nil;
    FNodes[Index].LHS := EOT;
    FNodes[Index].RHS := EOT;

    // Child is deleted ???
    // FNodes[FNodes[Index].Child].Prev :=

    // update disposed nodes
    DisposeNode(Index);
  end;
end;

procedure TCustomTree.DeleteInline(Index: Integer);
var
  //APrev,
  ANext: Integer;
begin
  Touch;
  //APrev := FNodes[Index].Prev;
  ANext := FNodes[Index].RHS;
  if ANext = EOT then
    DisposeNode(Index)
  else
  begin
    FNodes[Index] := FNodes[ANext];
    //FNodes[Index].Prev := APrev;

    FNodes[ANext].RHS := EOT;
    DisposeNode(ANext);
  end;
end;


// delete node + subtree
procedure TCustomTree.DeleteSubtree(APrev, Index: Integer);
begin
  if Index <> EOT then
  begin
    //if FNodes[Index].Prev <> EOT then FNodes[Index].Prev
    DeleteSubtree(Index, FNodes[Index].LHS);
    DeleteSubtree(Index, FNodes[Index].RHS);
    //FNodes[Index].LHS := EOT;
    //FNodes[Index].RHS := EOT;
    //DisposeNode(Index);
    Delete(APrev, Index);
  end;
end;

procedure TCustomTree.DeleteLHS(Index: Integer);
begin
  DeleteSubtree(Index, LHS[Index]);
end;

procedure TCustomTree.DeleteRHS(Index: Integer);
begin
  DeleteSubtree(Index, RHS[Index]);
end;


procedure TCustomTree.Expand(APrev, Index: Integer);
var
  X, Y, Z, W: Integer;
begin
  Touch;
{
  X --- I --- Y
        |
    	  Z --- ... --- W

  Expand(I) ==>

  X --- Z --- ... --- W --- Y

}

  X := APrev; //Prev[Index];
  Y := FNodes[Index].RHS;
  Z := FNodes[Index].LHS;
  if X = EOT then
  begin
    ExpandInline(X, Index);
    Exit;
  end;
  Assert(X <> EOT);    // Q: root node ???
  if Z <> EOT then
  begin
    //Node[Z]^.Prev := X;

    if FNodes[X].RHS = Index then
      FNodes[X].RHS := Z
    else
      FNodes[X].LHS := Z;

    W := LastSibling[Z];

    FNodes[W].RHS := Y;
    //if Y <> EOT then Node[Y]^.Prev := W;

    //Node[Index]^.Prev := EOT;
    FNodes[Index].LHS := EOT;
    FNodes[Index].RHS := EOT;
    DisposeNode(Index);
  end
  else
  begin
    // no child node => delete node
    Delete(APrev, Index);
  end;
end;

procedure TCustomTree.ExpandInline(APrev, Index: Integer);
var
  X, Y, Z, V, W: Integer;
begin
  Touch;
{
  X --- I --- Y
        |
    	  Z --- V --- ... --- W
        |
        Q

  Expand(I) ==>

  X --- Z --- V --- ... --- W --- Y
        |
        Q

  Note:

  X --- I --- Y
        |
        Z ---- V = W

  update V backreference to I
}

  //X := Prev[Index];
  X := APrev;
  Y := FNodes[Index].RHS;
  Z := FNodes[Index].LHS;

  if X = EOT then
  begin
    if Z <> EOT then
    begin
      FNodes[Index] := FNodes[Z];
      FNodes[Z].LHS := EOT;
      FNodes[Z].RHS := EOT;
      DisposeNode(Z);

      W := LastSibling[Index];
      FNodes[W].RHS := Y;
    end
    else if Y <> EOT then
    begin
      FNodes[Index] := FNodes[Y];
      FNodes[Y].LHS := EOT;
      FNodes[Y].RHS := EOT;
      DisposeNode(Y);
    end
    else
      InitializeNode(FNodes[Index]);
    Exit;
  end;

  if Z <> EOT then
  begin
    //V := FNodes[Z].LHS;
    //if V <> EOT then
    //  FNodes[V].Prev := Index;

    //Assert(Z = FNodes[FNodes[Z].LHS].Prev);

    //V := FNodes[Z].RHS;
    //if V <> EOT then
    //  FNodes[V].Prev := Index;

    FNodes[Index] := FNodes[Z];
    //FNodes[Index].Prev := X;

    FNodes[Z].LHS := EOT;
    FNodes[Z].RHS := EOT;
    DisposeNode(Z);


    W := LastSibling[Index];  // N : could be equal to Index
    FNodes[W].RHS := Y;

    //if Y <> EOT then Node[Y]^.Prev := W;

    //if FNodes[Index].LHS <> EOT then
    //  Assert(Index = FNodes[FNodes[Index].LHS].Prev);
  end
  else
  begin
    // no child node => delete node
    // Q: use Y as next node ?
    Delete(X, Index);

    FNodes[X].RHS := Y;
    //DisposeNode(Index);

  end;
end;

// insert (Y1..Y2) at (X1..X2) + delete (X1..X2)
procedure TCustomTree.Insert(X1, X2, Y1, Y2: Integer);
var
  L, R: Integer;
begin
  // L := Prev[X1];
  // R := Next[X2];

  // FNodes[Y1].Prev := L;
  // FNodes[Y2].Next := R;

  // if L <> EOT then
  // begin
  //   if RHS[L] = X1 then
  //     FNodes[L].RHS := Y1;
  //   if LHS[L] = X1 then
  //     FNodes[L].LHS := Y1;
  // end;
  // if R <> EOT then
  // begin
  //   FNodes[R].Prev := Y2;
  // end;

  // FNodes[X1].Prev := EOT;
  // FNodes[X2].Next := EOT;
  // DeleteSubtree(X1);
end;

function TCustomTree.Copy(X1, X2: Integer): Integer;
var
  N: Integer;
begin
  // EOT .. X2
  // X1 .. EOT
  //Assert(X1 <> EOT);
  if (X1 = EOT) or (X2 = EOT) then Exit(EOT);

  N := FNodes[X2].RHS;
  FNodes[X2].RHS := EOT;
  Result := CloneSubtree(X1);
  FNodes[X2].RHS := N;

(*
  if X1 = EOT then X1 := FirstSibling[X2];
  if X2 = EOT then X2 := LastSibling[X1];
  if (X1 = EOT) or (X2 = EOT) then
    Result := EOT
  else
  begin
    Result := CloneLHS(X1);
    Y1 := Result;
    X1 := FNodes[X1].Next;
    while (X1 <> X2) and (X1 <> EOT) do
    begin
      Y2 := CloneLHS(X1);
      LinkRHS(Y1, Y2);
      Y1 := Y2;
      X1 := FNodes[X1].Next;
    end;
  end;
  *)
end;

// Y1 - X1 ... X2 - Y2  -->  Y1 - Y2
// Q: How to get Y1 ?
procedure TCustomTree.DeleteRange(Y1, X1, X2: Integer);
var
  Y2: Integer;
begin
  Touch;
  Assert(X1 <> EOT);
  Assert(X2 <> EOT);

  //Y1 := FNodes[X1].Prev;
  Y2 := FNodes[X2].RHS;

  FNodes[X2].RHS := EOT;
  if Y1 <> EOT then FNodes[Y1].RHS := EOT;
  //if Y2 <> EOT then FNodes[Y2].Prev := EOT;
  DeleteSubtree(Y1, X1);
  LinkRHS(Y1, Y2);
end;

function TCustomTree.CopySubtree(Src, Dst: Integer): Integer;
begin
  if Src = EOT then
    Result := EOT
  else
  begin
    if Dst = EOT then Dst := AllocateNode;
    //InitializeNode(FNodes[Dst]);
    FNodes[Dst] := FNodes[Src];
    FNodes[Dst].LHS := EOT;
    FNodes[Dst].RHS := EOT;
    //! FNodes[Dst].Prev := EOT;

    // !!!
    // FNodes[Dst].Token := Expression.Clone(FNodes[Dst].Token);     // Q: Safe? Use AddDynToken??

    LinkLHS(Dst, CopySubtree(FNodes[Src].LHS, EOT));
    LinkRHS(Dst, CopySubtree(FNodes[Src].RHS, EOT));
    //WriteLn(Format('%d ( %d,%d )', [Dst, FNodes[Dst].LHS, FNodes[Dst].RHS]));

    Result := Dst;
  end;
end;

function TCustomTree.CloneSubtree(Index: Integer): Integer;
begin
  //Result := AllocateNode;
  //FNodes[Result] := FNodes[Index];
  Result := CopySubtree(Index, EOT);
end;

function TCustomTree.CloneLHS(Index: Integer): Integer;
var
  R: Integer;
begin
  R := FNodes[Index].RHS;
  FNodes[Index].RHS := EOT;
  Result := CloneSubtree(Index);
  FNodes[Index].RHS := R;
end;

function TCustomTree.CloneRHS(Index: Integer): Integer;
var
  L: Integer;
begin
  L := FNodes[Index].LHS;
  FNodes[Index].LHS := EOT;
  Result := CloneSubtree(Index);
  FNodes[Index].LHS := L;
end;

// procedure TCustomTree.Replace(Src, Dst: Integer);
// var
//   P, N, W, E: Integer;
// begin
//   Assert(Src <> EOT);
//   P := FNodes[Src].Prev;
//   N := FNodes[Src].Next;

//   Assert(P <> EOT);
//   E := Ord(FNodes[P].Next = Src); // 0 = Child, 1 = Next

//   DeleteSubtree(FNodes[Src].LHS);
//   FNodes[Src].Next := EOT;
//   DisposeNode(Src);
//   if Dst <> EOT then
//   begin
//     W := LastSibling[Dst];
//     FNodes[Dst].Prev := P;
//     FNodes[W].Next := N;
//     if P <> EOT then FNodes[P].Edge[E] := Dst;
//     if N <> EOT then FNodes[N].Prev := W;
//   end
//   else
//   begin
//     if P <> EOT then FNodes[P].Edge[E] := N;
//     if N <> EOT then FNodes[N].Prev := P;
//   end;
// end;

// procedure TCustomTree.Unlink(Index: Integer);
// var
//   P: Integer;
// begin
//   P := FNodes[Index].Prev;
//   if P <> EOT then
//   begin
//     if FNodes[P].RHS = Index then
//       FNodes[P].RHS := EOT
//     else
//       FNodes[P].LHS := EOT;
//     //FNodes[P].Edge[Ord(FNodes[P].RHS = Index)] := EOT;
//     FNodes[Index].Prev := EOT;
//   end;
// end;

procedure TCustomTree.Compress;
begin
  SetLength(FNodes, Count);
end;

// function TCustomTree.IsChild(Index: Integer): Boolean;
// var
//   P: Integer;
// begin
//   Assert(Index <> EOT);
//   P := FNodes[Index].Prev;
//   Result := (P <> EOT) and (FNodes[P].Child = Index);
// end;


procedure TCustomTree.LinkLHSorRHS(X, Z, Branch: Integer);
var
  Y: Integer;
begin
  Touch;
  Y := EOT;

  if X <> EOT then
  begin
    Y := FNodes[X].Edge[Branch];

    // x -> z
    FNodes[X].Edge[Branch] := Z;
  end;


  if Z <> EOT then
  begin
    // x <- z
    //! FNodes[Z].Prev := X;

    // z -> y

    // Q: if inserted node has child ???
    if Y <> EOT then
    begin
      Assert(FNodes[Z].Edge[Branch] = EOT);

      FNodes[Z].Edge[Branch] := Y;
      // z <- y
      //! FNodes[Y].Prev := Z;
    end;
  end;
end;

function TCustomTree.InsertNextOrChild(Index, Branch: Integer): Integer;
var
  X: Integer absolute Index;
  Z: Integer absolute Result;
begin
  Assert(X <> EOT);
  Assert(X <= High(FNodes));

  // x <-> y  =>  x <-> z <-> y
  Z := AllocateNode;
  LinkLHSorRHS(X, Z, Branch);
end;

function TCustomTree.GetFirstSibling(Index: Integer): Integer;
begin
  // Result := EOT;
  // if Index <> EOT then
  // begin
  //   while (Prev[Index] <> EOT) and (Next[Prev[Index]] = Index) do
  //     Index := Prev[Index];
  //   Result := Index;
  // end;
end;

function TCustomTree.GetLastSibling(Index: Integer): Integer;
begin
  Result := EOT;
  if Index <> EOT then
  begin
    while Next[Index] <> EOT do
      Index := Next[Index];
    Result := Index;
  end;
end;

function TCustomTree.GetSibling(Index, Offset: Integer): Integer;
begin
  if Index = EOT then
    Result := EOT
  else if Offset = 0 then
    Result := Index
  else
    Result := GetSibling(RHS[Index], Offset - 1);
end;

function TCustomTree.GetSize: Integer;
begin
  Result := Length(FNodes);
end;

procedure TCustomTree.SetSize(ASize: Integer);
begin
  SetLength(FNodes, ASize);
end;

function TCustomTree.InsertNext(Index: Integer): Integer;
begin
  InsertNextOrChild(Index, 1);
end;

function TCustomTree.InsertChild(Index: Integer): Integer;
begin
  InsertNextOrChild(Index, 0);
end;

procedure TCustomTree.LinkLHS(X, Y: Integer);
begin
  LinkLHSorRHS(X, Y, 0);
end;

procedure TCustomTree.LinkRHS(X, Y: Integer);
begin
  LinkLHSorRHS(X, Y, 1);
end;

function TCustomTree.SiblingCount(Index: Integer): Integer;
begin
  Result := 0;
  while Index <> EOT do
  begin
    Inc(Result);
    Index := Next[Index];
  end;
end;

function TCustomTree.NodeIndex(Node: PTreeNode): Integer;
begin
  // Compute index from memory address:
  Result := (UInt64(Node) - UInt64(@FNodes[0])) div SizeOf(TTreeNode);
end;

{ TTreeNode }

(*
function TTreeNode.GetChild: Integer;
begin
  // N: Identifiers have no children.
  if Data and TK_IDENTIFIER <> 0 then
    Result := EOT
  else
    Result := Value;
end;

procedure TTreeNode.SetChild(AValue: Integer);
begin
  Value := AValue;
end;
*)

function TTreeNode.GetRefData: Integer;
begin
  Result := GlobalTree.Expression.Token[Ref]^.ID;
end;

procedure TTreeNode.SetRefData(RefData: Integer);
begin
  GlobalTree.Expression.Token[Ref]^.ID := RefData;
end;

// function TTreeNode.Prev: Integer;
// begin
//   // Iterate through table.
// end;

end.
