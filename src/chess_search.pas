unit chess_search;

{$mode objfpc}{$H+}

interface

uses chess_engine;

type
  TSearchPoll = function: Boolean;
  TSearchResult = record
    Move: TMove;
    HasMove, Cancelled: Boolean;
    Score, Depth, Nodes: Integer;
  end;

function Evaluate(const P: TPosition): Integer;
function Search(const P: TPosition; NodeBudget, MaxDepth: Integer;
  Poll: TSearchPoll = nil): TSearchResult;

implementation

uses Math;

const
  Values: array[0..6] of Integer = (0,100,320,335,500,900,0);
  Infinity = 32000;
  MateScore = 30000;
  MaxPly = 64;

function Evaluate(const P: TPosition): Integer;
var S, Piece, Side, Rank, FileNo, Center, Bonus, BishopsW, BishopsB: Integer;
begin
  Result := 0; BishopsW := 0; BishopsB := 0;
  for S := 0 to 63 do
  begin
    Piece := Abs(P.Board[S]); if Piece = 0 then Continue;
    Side := 1; if P.Board[S] < 0 then Side := -1;
    Rank := S div 8; FileNo := S mod 8;
    if Side = -1 then Rank := 7-Rank;
    Center := 7 - Abs(2*FileNo-7) div 2 - Abs(2*Rank-7) div 2;
    Bonus := 0;
    case Piece of
      Pawn: Bonus := Rank * 9 + Center * 3;
      Knight: Bonus := Center * 12;
      Bishop:
        begin
          Bonus := Center * 6;
          if Side = 1 then Inc(BishopsW) else Inc(BishopsB);
        end;
      Rook: if Rank = 6 then Bonus := 24;
      Queen: Bonus := Center * 2;
      King:
        begin
          Bonus := -Rank * 10;
          if (Rank = 0) and (FileNo in [1,2,6]) then Inc(Bonus, 35);
        end;
    end;
    Inc(Result, Side * (Values[Piece] + Bonus));
  end;
  if BishopsW >= 2 then Inc(Result, 25);
  if BishopsB >= 2 then Dec(Result, 25);
end;

function Search(const P: TPosition; NodeBudget, MaxDepth: Integer;
  Poll: TSearchPoll): TSearchResult;
var
  Nodes: Integer;
  Stopped, Cancelled: Boolean;
  RootMoves: TMoveList;
  Iteration, I, Score, BestScore, Alpha: Integer;
  Candidate, BestMove: TMove;
  Next: TPosition;
  Path: array[0..MaxPly] of TPosition;

  function Visit: Boolean;
  begin
    if Nodes >= NodeBudget then Stopped := True;
    if not Stopped then
    begin
      Inc(Nodes);
      if (Nodes mod 256 = 0) and Assigned(Poll) then
        if not Poll() then begin Stopped := True; Cancelled := True; end;
    end;
    Result := not Stopped;
  end;

  function OrderValue(const Position: TPosition; const M: TMove): Integer;
  var Victim: Integer;
  begin
    Victim := Abs(Position.Board[M.ToSquare]);
    if (Victim = 0) and (Abs(Position.Board[M.FromSquare]) = Pawn) and
      (M.ToSquare = Position.EnPassant) then Victim := Pawn;
    Result := 0;
    if Victim <> 0 then Result := Values[Victim]*10 - Values[Abs(Position.Board[M.FromSquare])];
    Inc(Result, Values[M.Promotion] * 10);
  end;

  procedure Order(const Position: TPosition; var Moves: TMoveList);
  var A, B, Rank: Integer; M: TMove;
  begin
    for A := 1 to Moves.Count-1 do
    begin
      M := Moves.Items[A]; Rank := OrderValue(Position, M); B := A-1;
      while (B >= 0) and (OrderValue(Position, Moves.Items[B]) < Rank) do
      begin Moves.Items[B+1] := Moves.Items[B]; Dec(B); end;
      Moves.Items[B+1] := M;
    end;
  end;

  function Repeated(const Position: TPosition; Ply: Integer): Boolean;
  var A: Integer;
  begin
    Result := False;
    for A := Ply-2 downto 0 do
      if (Position.Turn = Path[A].Turn) and (Position.Castling = Path[A].Castling) and
        (Position.EnPassant = Path[A].EnPassant) and
        (CompareByte(Position.Board, Path[A].Board, SizeOf(Position.Board)) = 0) then Exit(True);
  end;

  function Negamax(const Position: TPosition; Depth, Low, High, Ply: Integer): Integer;
  var Moves: TMoveList; Child: TPosition; A, Value, Stand: Integer; Check, Tactical: Boolean;
  begin
    Result := Evaluate(Position) * Position.Turn;
    if not Visit then Exit;
    Path[Ply] := Position;
    LegalMoves(Position, Moves); Check := InCheck(Position, Position.Turn);
    if Moves.Count = 0 then
    begin if Check then Exit(-MateScore+Ply) else Exit(0); end;
    if (Position.Halfmove >= 100) or InsufficientMaterial(Position) or Repeated(Position, Ply) then Exit(0);
    if Ply >= MaxPly-1 then Exit;
    if (Depth <= 0) and not Check then
    begin
      Stand := Result;
      if Stand >= High then Exit(Stand);
      if Stand > Low then Low := Stand;
    end;
    Order(Position, Moves);
    Result := -Infinity;
    if (Depth <= 0) and not Check then Result := Low;
    for A := 0 to Moves.Count-1 do
    begin
      with Moves.Items[A] do Tactical := (Position.Board[ToSquare] <> 0) or
        (Promotion <> 0) or ((Abs(Position.Board[FromSquare]) = Pawn) and (ToSquare = Position.EnPassant));
      if (Depth <= 0) and not Check and not Tactical then Continue;
      ApplyMove(Position, Moves.Items[A], Child);
      Value := -Negamax(Child, Depth-1, -High, -Low, Ply+1);
      if Stopped then Exit;
      if Value > Result then Result := Value;
      if Value > Low then Low := Value;
      if Low >= High then Break;
    end;
  end;

begin
  Result := Default(TSearchResult);
  Nodes := 0; Stopped := False; Cancelled := False;
  NodeBudget := Max(1, NodeBudget); MaxDepth := EnsureRange(MaxDepth, 1, 12);
  LegalMoves(P, RootMoves);
  if RootMoves.Count = 0 then Exit;
  Order(P, RootMoves);
  Result.Move := RootMoves.Items[0]; Result.HasMove := True;
  Result.Score := Evaluate(P) * P.Turn;
  Path[0] := P;
  for Iteration := 1 to MaxDepth do
  begin
    BestScore := -Infinity; Alpha := -Infinity; BestMove := Result.Move;
    { Search the last completed principal move first, preserving stable ties. }
    for I := 0 to RootMoves.Count-1 do
      if SameMove(RootMoves.Items[I], Result.Move) then
      begin
        Candidate := RootMoves.Items[0]; RootMoves.Items[0] := RootMoves.Items[I];
        RootMoves.Items[I] := Candidate; Break;
      end;
    for I := 0 to RootMoves.Count-1 do
    begin
      ApplyMove(P, RootMoves.Items[I], Next);
      Score := -Negamax(Next, Iteration-1, -Infinity, -Alpha, 1);
      if Stopped then Break;
      if Score > BestScore then begin BestScore := Score; BestMove := RootMoves.Items[I]; end;
      if Score > Alpha then Alpha := Score;
    end;
    if Stopped then Break;
    Result.Move := BestMove; Result.Score := BestScore; Result.Depth := Iteration;
    if Abs(BestScore) > MateScore-MaxPly then Break;
  end;
  Result.Nodes := Nodes; Result.Cancelled := Cancelled;
end;

end.
