unit chess_engine;

{$mode objfpc}{$H+}

interface

const
  Pawn = 1; Knight = 2; Bishop = 3; Rook = 4; Queen = 5; King = 6;
  WhiteSide = 1; BlackSide = -1;
  StartFEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  MaxMoves = 512;
  MaxHistory = 2048;

type
  TPosition = record
    Board: array[0..63] of ShortInt;
    Turn: ShortInt;
    Castling: Byte;
    EnPassant: ShortInt;
    Halfmove, Fullmove: LongInt;
  end;
  TMove = record
    FromSquare, ToSquare, Promotion: ShortInt;
  end;
  TMoveList = record
    Count: Integer;
    Items: array[0..MaxMoves-1] of TMove;
  end;
  TOutcome = (ocPlaying, ocWhiteWins, ocBlackWins, ocStalemate,
    ocMaterial, ocFivefold, ocSeventyFive, ocClaimed);
  TGame = record
    Position: TPosition;
    Positions: array[0..MaxHistory] of TPosition;
    Moves: array[0..MaxHistory-1] of TMove;
    Notation: array[0..MaxHistory-1] of String[16];
    Count: Integer;
    Outcome: TOutcome;
  end;

function PieceChar(Piece: Integer): Char;
function SquareName(Square: Integer): String;
function ParseSquare(const Name: String): Integer;
function MoveName(const Move: TMove): String;
function SameMove(const A, B: TMove): Boolean;
function Attacked(const P: TPosition; Square, BySide: Integer): Boolean;
function InCheck(const P: TPosition; Side: Integer): Boolean;
procedure ApplyMove(const P: TPosition; const Move: TMove; out Next: TPosition);
procedure LegalMoves(const P: TPosition; out Moves: TMoveList);
function FindMove(const P: TPosition; const Name: String; out Move: TMove): Boolean;
function LoadFEN(const FEN: String; out P: TPosition; out Error: String): Boolean;
function SaveFEN(const P: TPosition): String;
function SAN(const P: TPosition; const Move: TMove): String;
function Perft(const P: TPosition; Depth: Integer): QWord;
function InsufficientMaterial(const P: TPosition): Boolean;
function PositionKey(const P: TPosition): String;
procedure StartGame(var Game: TGame; const P: TPosition);
procedure RefreshOutcome(var Game: TGame);
function PlayMove(var Game: TGame; const Move: TMove): Boolean;
function UndoMove(var Game: TGame): Boolean;
function Repetitions(const Game: TGame): Integer;
function CanClaimDraw(const Game: TGame): Boolean;
function ClaimDraw(var Game: TGame): Boolean;
function OutcomeText(Outcome: TOutcome): String;
function ExportPGN(const Game: TGame): String;

implementation

uses SysUtils, Classes;

function PieceChar(Piece: Integer): Char;
const Letters = '.PNBRQK';
begin
  if Abs(Piece) > King then Exit('?');
  Result := Letters[Abs(Piece) + 1];
  if Piece < 0 then Result := LowerCase(Result);
end;

function SquareName(Square: Integer): String;
begin
  if (Square < 0) or (Square > 63) then Exit('-');
  Result := Chr(Ord('a') + Square mod 8) + Chr(Ord('1') + Square div 8);
end;

function ParseSquare(const Name: String): Integer;
begin
  Result := -1;
  if (Length(Name) = 2) and (Name[1] in ['a'..'h']) and
    (Name[2] in ['1'..'8']) then
    Result := Ord(Name[1]) - Ord('a') + 8 * (Ord(Name[2]) - Ord('1'));
end;

function MoveName(const Move: TMove): String;
begin
  Result := SquareName(Move.FromSquare) + SquareName(Move.ToSquare);
  if Move.Promotion <> 0 then Result := Result + LowerCase(PieceChar(Move.Promotion));
end;

function SameMove(const A, B: TMove): Boolean;
begin
  Result := (A.FromSquare = B.FromSquare) and (A.ToSquare = B.ToSquare) and
    (A.Promotion = B.Promotion);
end;

function Attacked(const P: TPosition; Square, BySide: Integer): Boolean;
var S, Piece, DX, DY, SX, SY, X, Y: Integer;
begin
  for S := 0 to 63 do
  begin
    Piece := P.Board[S] * BySide;
    if Piece <= 0 then Continue;
    DX := Square mod 8 - S mod 8; DY := Square div 8 - S div 8;
    case Piece of
      Pawn: if (Abs(DX) = 1) and (DY = BySide) then Exit(True);
      Knight: if (Abs(DX) * Abs(DY) = 2) then Exit(True);
      King: if (Abs(DX) <= 1) and (Abs(DY) <= 1) then Exit(True);
      Bishop, Rook, Queen:
        begin
          if (DX = 0) and (DY = 0) then Continue;
          if not (((Piece in [Bishop, Queen]) and (Abs(DX) = Abs(DY))) or
            ((Piece in [Rook, Queen]) and ((DX = 0) or (DY = 0)))) then Continue;
          SX := 0; SY := 0;
          if DX <> 0 then SX := DX div Abs(DX);
          if DY <> 0 then SY := DY div Abs(DY);
          X := S mod 8 + SX; Y := S div 8 + SY;
          while (X <> Square mod 8) or (Y <> Square div 8) do
          begin
            if P.Board[Y * 8 + X] <> 0 then Break;
            Inc(X, SX); Inc(Y, SY);
          end;
          if (X = Square mod 8) and (Y = Square div 8) then Exit(True);
        end;
    end;
  end;
  Result := False;
end;

function InCheck(const P: TPosition; Side: Integer): Boolean;
var S: Integer;
begin
  for S := 0 to 63 do
    if P.Board[S] = Side * King then Exit(Attacked(P, S, -Side));
  Result := True;
end;

procedure ApplyMove(const P: TPosition; const Move: TMove; out Next: TPosition);
var Piece, Captured, F, T: Integer;
begin
  Next := P; F := Move.FromSquare; T := Move.ToSquare;
  Piece := P.Board[F]; Captured := P.Board[T];
  Next.Board[F] := 0; Next.Board[T] := Piece;
  Next.EnPassant := -1;
  if Abs(Piece) = Pawn then
  begin
    if (T = P.EnPassant) and (Captured = 0) and (F mod 8 <> T mod 8) then
      Next.Board[T - 8 * P.Turn] := 0;
    if Abs(T - F) = 16 then Next.EnPassant := (F + T) div 2;
    if Move.Promotion <> 0 then Next.Board[T] := Move.Promotion * P.Turn;
  end;
  if Abs(Piece) = King then
  begin
    if P.Turn = WhiteSide then Next.Castling := Next.Castling and 12
    else Next.Castling := Next.Castling and 3;
    if T - F = 2 then begin Next.Board[F+3] := 0; Next.Board[F+1] := P.Turn * Rook; end;
    if F - T = 2 then begin Next.Board[F-4] := 0; Next.Board[F-1] := P.Turn * Rook; end;
  end;
  if (F = 0) or (T = 0) then Next.Castling := Next.Castling and 13;
  if (F = 7) or (T = 7) then Next.Castling := Next.Castling and 14;
  if (F = 56) or (T = 56) then Next.Castling := Next.Castling and 7;
  if (F = 63) or (T = 63) then Next.Castling := Next.Castling and 11;
  if (Abs(Piece) = Pawn) or (Captured <> 0) then Next.Halfmove := 0
  else Inc(Next.Halfmove);
  if P.Turn = BlackSide then Inc(Next.Fullmove);
  Next.Turn := -P.Turn;
end;

procedure LegalMoves(const P: TPosition; out Moves: TMoveList);
const
  DXs: array[0..7] of Integer = (1,-1,0,0,1,1,-1,-1);
  DYs: array[0..7] of Integer = (0,0,1,-1,1,-1,1,-1);
  NXs: array[0..7] of Integer = (1,2,2,1,-1,-2,-2,-1);
  NYs: array[0..7] of Integer = (2,1,-1,-2,-2,-1,1,2);
var S, Piece, X, Y, TX, TY, D, Target, Offset, Rights: Integer;

  procedure Add(F, T, Promotion: Integer);
  var M: TMove; Next: TPosition;
  begin
    if (P.Board[T] * P.Turn > 0) or (Abs(P.Board[T]) = King) then Exit;
    M.FromSquare := F; M.ToSquare := T; M.Promotion := Promotion;
    ApplyMove(P, M, Next);
    if InCheck(Next, P.Turn) then Exit;
    if Moves.Count = MaxMoves then raise Exception.Create('Move list capacity exceeded.');
    Moves.Items[Moves.Count] := M; Inc(Moves.Count);
  end;

  procedure PawnMove(T: Integer);
  var Promotion: Integer;
  begin
    if T div 8 in [0,7] then
      for Promotion := Knight to Queen do Add(S, T, Promotion)
    else Add(S, T, 0);
  end;

begin
  Moves.Count := 0;
  for S := 0 to 63 do
  begin
    Piece := P.Board[S] * P.Turn;
    if Piece <= 0 then Continue;
    X := S mod 8; Y := S div 8;
    case Piece of
      Pawn:
        begin
          TY := Y + P.Turn;
          if (TY < 0) or (TY > 7) then Continue;
          Target := TY * 8 + X;
          if P.Board[Target] = 0 then
          begin
            PawnMove(Target);
            if ((P.Turn = WhiteSide) and (Y = 1)) or
               ((P.Turn = BlackSide) and (Y = 6)) then
              if P.Board[S + 16 * P.Turn] = 0 then Add(S, S + 16 * P.Turn, 0);
          end;
          for D := -1 to 1 do
            if (D <> 0) and (X+D >= 0) and (X+D <= 7) then
            begin
              Target := TY * 8 + X + D;
              if (P.Board[Target] * P.Turn < 0) or
                ((Target = P.EnPassant) and (P.Board[Target] = 0) and
                 (P.Board[Target - P.Turn * 8] = -P.Turn * Pawn)) then PawnMove(Target);
            end;
        end;
      Knight:
        for D := 0 to 7 do
        begin
          TX := X + NXs[D]; TY := Y + NYs[D];
          if (TX >= 0) and (TX < 8) and (TY >= 0) and (TY < 8) then Add(S, TY*8+TX, 0);
        end;
      Bishop, Rook, Queen, King:
        begin
          for D := 0 to 7 do
          begin
            if (Piece = Bishop) and (D < 4) then Continue;
            if (Piece = Rook) and (D >= 4) then Continue;
            TX := X + DXs[D]; TY := Y + DYs[D];
            while (TX >= 0) and (TX < 8) and (TY >= 0) and (TY < 8) do
            begin
              Target := TY*8+TX; Add(S, Target, 0);
              if (P.Board[Target] <> 0) or (Piece = King) then Break;
              Inc(TX, DXs[D]); Inc(TY, DYs[D]);
            end;
          end;
          if Piece = King then
          begin
            Offset := 0; Rights := P.Castling;
            if P.Turn = BlackSide then begin Offset := 56; Rights := Rights shr 2; end;
            if (S = Offset+4) and not InCheck(P, P.Turn) then
            begin
              if ((Rights and 1) <> 0) and (P.Board[Offset+7] = P.Turn*Rook) and
                (P.Board[Offset+5] = 0) and (P.Board[Offset+6] = 0) and
                not Attacked(P, Offset+5, -P.Turn) and not Attacked(P, Offset+6, -P.Turn) then
                Add(S, Offset+6, 0);
              if ((Rights and 2) <> 0) and (P.Board[Offset] = P.Turn*Rook) and
                (P.Board[Offset+1] = 0) and (P.Board[Offset+2] = 0) and
                (P.Board[Offset+3] = 0) and not Attacked(P, Offset+3, -P.Turn) and
                not Attacked(P, Offset+2, -P.Turn) then Add(S, Offset+2, 0);
            end;
          end;
        end;
    end;
  end;
end;

function FindMove(const P: TPosition; const Name: String; out Move: TMove): Boolean;
var Moves: TMoveList; I: Integer;
begin
  LegalMoves(P, Moves);
  for I := 0 to Moves.Count-1 do
    if MoveName(Moves.Items[I]) = Name then begin Move := Moves.Items[I]; Exit(True); end;
  Result := False;
end;

function SaveFEN(const P: TPosition): String;
var X, Y, Empty: Integer;
begin
  Result := '';
  for Y := 7 downto 0 do
  begin
    Empty := 0;
    for X := 0 to 7 do
      if P.Board[Y*8+X] = 0 then Inc(Empty)
      else
      begin
        if Empty > 0 then Result := Result + IntToStr(Empty);
        Empty := 0; Result := Result + PieceChar(P.Board[Y*8+X]);
      end;
    if Empty > 0 then Result := Result + IntToStr(Empty);
    if Y > 0 then Result := Result + '/';
  end;
  if P.Turn = WhiteSide then Result := Result + ' w ' else Result := Result + ' b ';
  if P.Castling = 0 then Result := Result + '-'
  else
  begin
    if P.Castling and 1 <> 0 then Result := Result + 'K';
    if P.Castling and 2 <> 0 then Result := Result + 'Q';
    if P.Castling and 4 <> 0 then Result := Result + 'k';
    if P.Castling and 8 <> 0 then Result := Result + 'q';
  end;
  Result := Result + ' ' + SquareName(P.EnPassant) + ' ' + IntToStr(P.Halfmove) + ' ' + IntToStr(P.Fullmove);
end;

function LoadFEN(const FEN: String; out P: TPosition; out Error: String): Boolean;
var Parts: TStringList; Q: TPosition; X, Y, I, Piece, Flag, WKing, BKing, WP, BP: Integer; C: Char;
begin
  Result := False; Error := 'Invalid FEN.'; FillChar(P, SizeOf(P), 0);
  FillChar(Q, SizeOf(Q), 0); Q.EnPassant := -1;
  Parts := TStringList.Create;
  try
    ExtractStrings([' '], [], PChar(FEN), Parts);
    if Parts.Count <> 6 then Exit;
    X := 0; Y := 7; WKing := 0; BKing := 0; WP := 0; BP := 0;
    for C in Parts[0] do
    begin
      if C = '/' then
      begin
        if (X <> 8) or (Y = 0) then Exit;
        Dec(Y); X := 0; Continue;
      end;
      if C in ['1'..'8'] then begin Inc(X, Ord(C)-Ord('0')); if X > 8 then Exit; Continue; end;
      Piece := Pos(UpCase(C), 'PNBRQK');
      if (Piece = 0) or (X >= 8) then Exit;
      if (Piece = Pawn) and (Y in [0,7]) then Exit;
      if C in ['a'..'z'] then Piece := -Piece;
      Q.Board[Y*8+X] := Piece; Inc(X);
      if Piece = King then Inc(WKing);
      if Piece = -King then Inc(BKing);
      if Piece > 0 then Inc(WP) else Inc(BP);
    end;
    if (Y <> 0) or (X <> 8) or (WKing <> 1) or (BKing <> 1) or (WP > 16) or (BP > 16) then Exit;
    if Parts[1] = 'w' then Q.Turn := WhiteSide
    else if Parts[1] = 'b' then Q.Turn := BlackSide else Exit;
    if Parts[2] <> '-' then
      for C in Parts[2] do
      begin
        case C of 'K': Flag := 1; 'Q': Flag := 2; 'k': Flag := 4; 'q': Flag := 8; else Exit; end;
        if Q.Castling and Flag <> 0 then Exit;
        Q.Castling := Q.Castling or Flag;
      end;
    if ((Q.Castling and 3 <> 0) and (Q.Board[4] <> King)) or
      ((Q.Castling and 12 <> 0) and (Q.Board[60] <> -King)) or
      ((Q.Castling and 1 <> 0) and (Q.Board[7] <> Rook)) or
      ((Q.Castling and 2 <> 0) and (Q.Board[0] <> Rook)) or
      ((Q.Castling and 4 <> 0) and (Q.Board[63] <> -Rook)) or
      ((Q.Castling and 8 <> 0) and (Q.Board[56] <> -Rook)) then Exit;
    if Parts[3] <> '-' then
    begin
      Q.EnPassant := ParseSquare(Parts[3]);
      if Q.EnPassant < 0 then Exit;
      if ((Q.Turn = WhiteSide) and (Q.EnPassant div 8 <> 5)) or
        ((Q.Turn = BlackSide) and (Q.EnPassant div 8 <> 2)) then Exit;
      if (Q.Board[Q.EnPassant] <> 0) or
        (Q.Board[Q.EnPassant - 8*Q.Turn] <> -Q.Turn*Pawn) or
        (Q.Board[Q.EnPassant + 8*Q.Turn] <> 0) then Exit;
    end;
    for I := 4 to 5 do
    begin
      if Parts[I] = '' then Exit;
      for C in Parts[I] do if not (C in ['0'..'9']) then Exit;
    end;
    if not TryStrToInt(Parts[4], Q.Halfmove) or (Q.Halfmove < 0) or (Q.Halfmove > 1000000) then Exit;
    if not TryStrToInt(Parts[5], Q.Fullmove) or (Q.Fullmove < 1) or (Q.Fullmove > 1000000) then Exit;
    if InCheck(Q, -Q.Turn) then begin Error := 'FEN leaves the previous player in check.'; Exit; end;
    P := Q; Error := ''; Result := True;
  finally
    Parts.Free;
  end;
end;

function SAN(const P: TPosition; const Move: TMove): String;
var Moves: TMoveList; Next: TPosition; I, Piece: Integer; Capture, Ambiguous, SameFile, SameRank: Boolean;
begin
  Piece := Abs(P.Board[Move.FromSquare]);
  if (Piece = King) and (Abs(Move.ToSquare-Move.FromSquare) = 2) then
  begin
    if Move.ToSquare > Move.FromSquare then Result := 'O-O' else Result := 'O-O-O';
  end
  else
  begin
    Result := ''; Capture := (P.Board[Move.ToSquare] <> 0) or
      ((Piece = Pawn) and (Move.FromSquare mod 8 <> Move.ToSquare mod 8));
    if Piece <> Pawn then
    begin
      Result := PieceChar(Piece); LegalMoves(P, Moves);
      Ambiguous := False; SameFile := False; SameRank := False;
      for I := 0 to Moves.Count-1 do
        with Moves.Items[I] do
          if (ToSquare = Move.ToSquare) and (FromSquare <> Move.FromSquare) and
            (P.Board[FromSquare] = P.Board[Move.FromSquare]) then
          begin
            Ambiguous := True;
            SameFile := SameFile or (FromSquare mod 8 = Move.FromSquare mod 8);
            SameRank := SameRank or (FromSquare div 8 = Move.FromSquare div 8);
          end;
      if Ambiguous then
      begin
        if not SameFile then Result := Result + SquareName(Move.FromSquare)[1]
        else if not SameRank then Result := Result + SquareName(Move.FromSquare)[2]
        else Result := Result + SquareName(Move.FromSquare);
      end;
    end
    else if Capture then Result := SquareName(Move.FromSquare)[1];
    if Capture then Result := Result + 'x';
    Result := Result + SquareName(Move.ToSquare);
    if Move.Promotion <> 0 then Result := Result + '=' + PieceChar(Move.Promotion);
  end;
  ApplyMove(P, Move, Next);
  if InCheck(Next, Next.Turn) then
  begin
    LegalMoves(Next, Moves);
    if Moves.Count = 0 then Result := Result + '#' else Result := Result + '+';
  end;
end;

function Perft(const P: TPosition; Depth: Integer): QWord;
var Moves: TMoveList; Next: TPosition; I: Integer;
begin
  if Depth <= 0 then Exit(1);
  LegalMoves(P, Moves); Result := 0;
  if Depth = 1 then Exit(Moves.Count);
  for I := 0 to Moves.Count-1 do
  begin ApplyMove(P, Moves.Items[I], Next); Inc(Result, Perft(Next, Depth-1)); end;
end;

function InsufficientMaterial(const P: TPosition): Boolean;
var S, Minors, Knights, BishopColor, Color: Integer;
begin
  Minors := 0; Knights := 0; BishopColor := -1;
  for S := 0 to 63 do
    case Abs(P.Board[S]) of
      Pawn, Rook, Queen: Exit(False);
      Knight: begin Inc(Knights); Inc(Minors); end;
      Bishop:
        begin
          Inc(Minors); Color := (S mod 8 + S div 8) mod 2;
          if BishopColor = -1 then BishopColor := Color
          else if BishopColor <> Color then BishopColor := 2;
        end;
    end;
  Result := (Minors <= 1) or ((Knights = 0) and (BishopColor < 2));
end;

function PositionKey(const P: TPosition): String;
var Q: TPosition; Moves: TMoveList; I: Integer; HasEP: Boolean;
begin
  Q := P; Q.Halfmove := 0; Q.Fullmove := 1;
  if Q.EnPassant >= 0 then
  begin
    HasEP := False; LegalMoves(P, Moves);
    for I := 0 to Moves.Count-1 do
      with Moves.Items[I] do
        if (ToSquare = P.EnPassant) and (Abs(P.Board[FromSquare]) = Pawn) and
          (FromSquare mod 8 <> ToSquare mod 8) then HasEP := True;
    if not HasEP then Q.EnPassant := -1;
  end;
  Result := SaveFEN(Q);
end;

function Repetitions(const Game: TGame): Integer;
var I: Integer; Key: String;
begin
  Result := 0; Key := PositionKey(Game.Position);
  for I := Game.Count downto 0 do
  begin
    if (Game.Count-I) > Game.Position.Halfmove then Break;
    if PositionKey(Game.Positions[I]) = Key then Inc(Result);
  end;
end;

procedure RefreshOutcome(var Game: TGame);
var Moves: TMoveList;
begin
  Game.Outcome := ocPlaying; LegalMoves(Game.Position, Moves);
  if Moves.Count = 0 then
  begin
    if not InCheck(Game.Position, Game.Position.Turn) then Game.Outcome := ocStalemate
    else if Game.Position.Turn = WhiteSide then Game.Outcome := ocBlackWins
    else Game.Outcome := ocWhiteWins;
  end
  else if InsufficientMaterial(Game.Position) then Game.Outcome := ocMaterial
  else if Game.Position.Halfmove >= 150 then Game.Outcome := ocSeventyFive
  else if Repetitions(Game) >= 5 then Game.Outcome := ocFivefold;
end;

procedure StartGame(var Game: TGame; const P: TPosition);
begin
  Game.Count := 0; Game.Position := P; Game.Positions[0] := P;
  RefreshOutcome(Game);
end;

function PlayMove(var Game: TGame; const Move: TMove): Boolean;
var Moves: TMoveList; I: Integer; Next: TPosition;
begin
  Result := False;
  if (Game.Outcome <> ocPlaying) or (Game.Count = MaxHistory) then Exit;
  LegalMoves(Game.Position, Moves);
  for I := 0 to Moves.Count-1 do
    if SameMove(Move, Moves.Items[I]) then
    begin
      Game.Notation[Game.Count] := SAN(Game.Position, Move);
      Game.Moves[Game.Count] := Move;
      ApplyMove(Game.Position, Move, Next); Game.Position := Next;
      Inc(Game.Count); Game.Positions[Game.Count] := Next;
      RefreshOutcome(Game); Exit(True);
    end;
end;

function UndoMove(var Game: TGame): Boolean;
begin
  Result := Game.Count > 0;
  if not Result then Exit;
  Dec(Game.Count); Game.Position := Game.Positions[Game.Count]; RefreshOutcome(Game);
end;

function CanClaimDraw(const Game: TGame): Boolean;
begin
  Result := (Game.Outcome = ocPlaying) and
    ((Game.Position.Halfmove >= 100) or (Repetitions(Game) >= 3));
end;

function ClaimDraw(var Game: TGame): Boolean;
begin
  Result := CanClaimDraw(Game);
  if Result then Game.Outcome := ocClaimed;
end;

function OutcomeText(Outcome: TOutcome): String;
begin
  case Outcome of
    ocPlaying: Result := 'In play';
    ocWhiteWins: Result := 'White wins by checkmate';
    ocBlackWins: Result := 'Black wins by checkmate';
    ocStalemate: Result := 'Draw by stalemate';
    ocMaterial: Result := 'Draw by insufficient material';
    ocFivefold: Result := 'Draw by fivefold repetition';
    ocSeventyFive: Result := 'Draw by the 75-move rule';
    ocClaimed: Result := 'Draw claimed';
  end;
end;

function ExportPGN(const Game: TGame): String;
var I, Number: Integer; Score: String;
begin
  case Game.Outcome of
    ocWhiteWins: Score := '1-0'; ocBlackWins: Score := '0-1';
    ocPlaying: Score := '*'; else Score := '1/2-1/2';
  end;
  Result := '[Event "Pascal Chess casual game"]' + LineEnding +
    '[Site "Local"]' + LineEnding + '[Date "????.??.??"]' + LineEnding +
    '[Round "-"]' + LineEnding + '[White "White"]' + LineEnding +
    '[Black "Black"]' + LineEnding + '[Result "' + Score + '"]' + LineEnding;
  if SaveFEN(Game.Positions[0]) <> StartFEN then
    Result := Result + '[SetUp "1"]' + LineEnding + '[FEN "' + SaveFEN(Game.Positions[0]) + '"]' + LineEnding;
  Result := Result + LineEnding;
  for I := 0 to Game.Count-1 do
  begin
    Number := Game.Positions[I].Fullmove;
    if Game.Positions[I].Turn = WhiteSide then Result := Result + IntToStr(Number) + '. '
    else if I = 0 then Result := Result + IntToStr(Number) + '... ';
    Result := Result + Game.Notation[I] + ' ';
    if I mod 12 = 11 then Result := Result + LineEnding;
  end;
  Result := Result + Score + LineEnding;
end;

end.
