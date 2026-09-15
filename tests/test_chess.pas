program test_chess;

{$mode objfpc}{$H+}

uses SysUtils, chess_engine, chess_search;

var Checks: Integer = 0; P, Q: TPosition; G: TGame; M: TMove;
  Moves: TMoveList; Error, Before: String; I, J: Integer; A, B: TSearchResult;

procedure Check(Condition: Boolean; const LabelText: String);
begin
  Inc(Checks); if not Condition then raise Exception.Create(LabelText);
end;

procedure Position(const FEN: String);
begin Check(LoadFEN(FEN, P, Error), 'FEN: ' + FEN + ' ' + Error); end;

procedure Move(const Name: String);
begin
  Check(FindMove(G.Position, Name, M), 'Find legal ' + Name);
  Check(PlayMove(G, M), 'Play ' + Name);
end;

procedure Count(Depth: Integer; Expected: QWord);
var Actual: QWord;
begin
  Actual := Perft(P, Depth);
  Check(Actual = Expected, 'Perft ' + IntToStr(Depth) + ': expected ' + UIntToStr(Expected) + ', got ' + UIntToStr(Actual));
end;

function Cancel: Boolean;
begin Result := False; end;

begin
  try
    Position(StartFEN); Check(SaveFEN(P) = StartFEN, 'Initial FEN roundtrip');
    Count(1,20); Count(2,400); Count(3,8902); Count(4,197281); Count(5,4865609);
    Position('r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
    Count(1,48); Count(2,2039); Count(3,97862);
    Position('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1'); Count(4,43238);
    Position('r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1'); Count(3,9467);
    Position('rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8'); Count(3,62379);
    Position('r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10'); Count(3,89890);
    WriteLn('ok - six reference perft positions');

    Position('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    Check(FindMove(P, 'e1g1', M), 'White short castle');
    Check(SAN(P,M) = 'O-O', 'Castle SAN'); ApplyMove(P,M,Q);
    Check((Q.Board[6] = King) and (Q.Board[5] = Rook) and (Q.Board[7] = 0) and (Q.Castling = 12), 'Castle pieces and rights');
    Position('r3kr1r/8/8/8/8/8/8/R3K2R w KQ - 0 1');
    Check(not FindMove(P, 'e1g1', M), 'Cannot castle through check');
    Position('4r1k1/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
    Check(not FindMove(P, 'e5d6', M), 'Pinned en passant');
    Position('6k1/8/8/r4pPK/8/8/8/8 w - f6 0 1');
    Check(not FindMove(P, 'g5f6', M), 'Horizontal en passant discovery');
    Position('6k1/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
    Check(FindMove(P,'e5d6',M), 'Legal en passant'); Check(SAN(P,M) = 'exd6', 'EP SAN');
    ApplyMove(P,M,Q); Check((Q.Board[35] = 0) and (Q.Board[43] = Pawn) and (Q.EnPassant = -1), 'EP removal');
    Position('7k/P7/8/8/8/8/8/7K w - - 0 1'); LegalMoves(P,Moves); J := 0;
    for I := 0 to Moves.Count-1 do if Moves.Items[I].Promotion <> 0 then Inc(J);
    Check(J = 4, 'All four promotions'); Check(FindMove(P,'a7a8n',M), 'Underpromotion');
    ApplyMove(P,M,Q); Check(Q.Board[56] = Knight, 'Knight promoted');
    WriteLn('ok - castling, en passant and all promotions');

    Position(StartFEN); StartGame(G,P); Before := SaveFEN(P);
    Move('f2f3'); Move('e7e5'); Move('g2g4'); Move('d8h4');
    Check(G.Outcome = ocBlackWins, 'Fools mate'); Check(G.Notation[3] = 'Qh4#', 'Mate SAN');
    Check(not PlayMove(G,M), 'Finished game refuses moves');
    Check(Pos('1. f3 e5 2. g4 Qh4# 0-1', ExportPGN(G)) > 0, 'PGN result');
    while UndoMove(G) do ; Check(SaveFEN(G.Position) = Before, 'Full undo');
    Position('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1'); StartGame(G,P);
    Check(G.Outcome = ocStalemate, 'Stalemate');
    Position('7k/8/8/8/8/8/8/KB6 w - - 0 1'); Check(InsufficientMaterial(P), 'K+B vs K');
    Position('7k/8/8/8/8/8/8/KNN5 w - - 0 1'); Check(not InsufficientMaterial(P), 'K+NN vs K is not dead');
    Position('7k/5Q2/6K1/8/8/8/8/8 w - - 149 1'); StartGame(G,P);
    Move('f7g7'); Check(G.Outcome = ocWhiteWins, 'Mate takes precedence over 75 moves');
    Position('7k/8/8/8/8/8/8/KR6 w - - 149 1'); StartGame(G,P);
    Move('b1b2'); Check(G.Outcome = ocSeventyFive, 'Automatic 75 moves');
    Position('7k/8/8/8/8/8/8/KR6 w - - 100 1'); StartGame(G,P);
    Check(CanClaimDraw(G), '50 move claim'); Check(ClaimDraw(G), 'Claim applied');
    Position(StartFEN); StartGame(G,P);
    for I := 1 to 4 do
    begin
      Move('g1f3'); Move('g8f6'); Move('f3g1'); Move('f6g8');
      if I = 2 then Check(CanClaimDraw(G), 'Threefold claim');
    end;
    Check(G.Outcome = ocFivefold, 'Automatic fivefold repetition');
    Position('7k/8/8/8/4P3/8/8/4K3 b - e3 0 1'); Before := PositionKey(P);
    P.EnPassant := -1; Check(PositionKey(P) = Before, 'Irrelevant EP omitted from repetition key');
    WriteLn('ok - mate, stalemate, draw rules, SAN, PGN and undo');

    Check(not LoadFEN('bad',P,Error), 'Reject malformed FEN');
    Check(not LoadFEN('8/8/8/8/8/8/8/8 w - - 0 1',P,Error), 'Reject missing kings');
    Check(not LoadFEN('7k/8/8/8/8/8/8/K7 w K - 0 1',P,Error), 'Reject fake castling rights');
    Check(not LoadFEN('7k/8/8/8/8/8/8/K7 w - a1 0 1',P,Error), 'Reject invalid EP');
    Position(StartFEN); StartGame(G,P);
    for I := 0 to 199 do
    begin
      if G.Outcome <> ocPlaying then Break;
      LegalMoves(G.Position,Moves); M := Moves.Items[(I*37+11) mod Moves.Count];
      Check(PlayMove(G,M), 'Deterministic legal walk');
      Check(not InCheck(G.Position,-G.Position.Turn), 'King remains safe');
      Check(LoadFEN(SaveFEN(G.Position),Q,Error), 'Walk FEN loads');
      Check(SaveFEN(Q) = SaveFEN(G.Position), 'Walk FEN roundtrip');
    end;
    WriteLn('ok - invalid FEN and deterministic legal walk');

    Position(StartFEN); A := Search(P,3000,4); B := Search(P,3000,4);
    Check(A.HasMove and FindMove(P,MoveName(A.Move),M), 'Search returns legal move');
    Check((A.Nodes <= 3000) and (A.Nodes = B.Nodes) and SameMove(A.Move,B.Move), 'Deterministic bounded search');
    A := Search(P,1,8); Check(A.HasMove and (A.Nodes = 1), 'Tiny budget legal fallback');
    A := Search(P,100000,8,@Cancel); Check(A.Cancelled and (A.Nodes = 256), 'Cooperative cancellation');
    Position('7k/5Q2/6K1/8/8/8/8/8 w - - 0 1'); A := Search(P,6000,3);
    StartGame(G,P); Check(PlayMove(G,A.Move), 'Tactical move legal');
    Check(G.Outcome = ocWhiteWins, 'Search finds mate in one');
    WriteLn('ok - legal, deterministic, bounded and cancellable Pascal search');
    WriteLn('PASS: ',Checks,' assertions');
  except
    on E: Exception do begin WriteLn(StdErr,'FAIL: ',E.Message); Halt(1); end;
  end;
end.
