program ChessCLI;

{$mode objfpc}{$H+}

uses SysUtils, Classes, chess_engine, chess_search;

var P: TPosition; Game: TGame; M: TMove; Reply: TSearchResult;
  Error, FEN, Action, Line, OutputPath, MovesText, Token: String;
  I, Depth, Budget, X, Y: Integer; Lines, Tokens: TStringList;

procedure Help;
begin
  WriteLn('Pascal Chess 1.0.0 - offline terminal and analysis');
  WriteLn('Usage: ChessCLI [--fen "FEN"] [--moves "e2e4 e7e5"]');
  WriteLn('                [--perft DEPTH | --search] [--depth N] [--nodes N]');
  WriteLn('                [--pgn FILE] [--help]');
  WriteLn('No action: interactive game. Moves use UCI coordinates; promotion e7e8q.');
  WriteLn('Commands: undo, hint, ai, fen, pgn, claim, new, help, quit.');
end;

function Argument: String;
begin
  Inc(I); if I > ParamCount then raise Exception.Create('Missing option value.');
  Result := ParamStr(I);
end;

function Number(const Value: String; Low, High: Integer): Integer;
var C: Char;
begin
  if Value = '' then raise Exception.Create('Expected a decimal integer.');
  for C in Value do if not (C in ['0'..'9']) then raise Exception.Create('Expected a decimal integer.');
  if not TryStrToInt(Value,Result) or (Result < Low) or (Result > High) then
    raise Exception.Create('Numeric option is outside the supported range.');
end;

procedure Board;
begin
  WriteLn;
  for Y := 7 downto 0 do
  begin
    Write(Y+1,'  ');
    for X := 0 to 7 do Write(PieceChar(Game.Position.Board[Y*8+X]),' ');
    WriteLn;
  end;
  WriteLn('   a b c d e f g h');
  if Game.Outcome <> ocPlaying then WriteLn(OutcomeText(Game.Outcome))
  else
  begin
    if Game.Position.Turn = WhiteSide then Write('White') else Write('Black');
    Write(' to move');
    if InCheck(Game.Position,Game.Position.Turn) then Write(' - CHECK');
    WriteLn;
    if CanClaimDraw(Game) then WriteLn('A draw may be claimed.');
  end;
end;

begin
  try
    FEN := StartFEN; Action := ''; Depth := 5; Budget := 40000; I := 1;
    while I <= ParamCount do
    begin
      case ParamStr(I) of
        '--help': begin Help; Halt(0); end;
        '--fen': FEN := Argument;
        '--perft': begin
          if Action <> '' then raise Exception.Create('Choose one analysis action.');
          Action := 'perft'; Depth := Number(Argument,0,6);
        end;
        '--search': begin
          if Action <> '' then raise Exception.Create('Choose one analysis action.');
          Action := 'search';
        end;
        '--depth': Depth := Number(Argument,1,6);
        '--nodes': Budget := Number(Argument,1,1000000);
        '--moves': MovesText := Argument;
        '--pgn': OutputPath := Argument;
        else raise Exception.Create('Unknown option: ' + ParamStr(I));
      end;
      Inc(I);
    end;
    if not LoadFEN(FEN,P,Error) then raise Exception.Create(Error);
    StartGame(Game,P); Tokens := TStringList.Create;
    try
      ExtractStrings([' '],[],PChar(MovesText),Tokens);
      for Token in Tokens do
      begin
        if not FindMove(Game.Position,Token,M) then raise Exception.Create('Illegal move: ' + Token);
        if not PlayMove(Game,M) then raise Exception.Create('Cannot move after the game ended.');
      end;
    finally Tokens.Free; end;
    if OutputPath <> '' then
    begin
      Lines := TStringList.Create;
      try Lines.Text := ExportPGN(Game); Lines.SaveToFile(OutputPath); finally Lines.Free; end;
      WriteLn('PGN saved to ',OutputPath);
    end;
    if Action = 'perft' then WriteLn('Nodes: ',Perft(Game.Position,Depth))
    else if Action = 'search' then
    begin
      Reply := Search(Game.Position,Budget,Depth);
      if Reply.HasMove then WriteLn('Best move: ',MoveName(Reply.Move),' (',SAN(Game.Position,Reply.Move),')')
      else WriteLn('No legal move.');
      WriteLn('Depth: ',Reply.Depth,' Nodes: ',Reply.Nodes,' Score: ',Reply.Score,' cp for the side to move');
    end
    else if OutputPath = '' then
    begin
      Help;
      repeat
        Board; Write('chess> ');
        if EOF(Input) then Break;
        ReadLn(Line); Line := LowerCase(Trim(Line));
        if (Line = 'quit') or (Line = 'q') then Break;
        if Line = 'help' then Help
        else if Line = 'undo' then begin if not UndoMove(Game) then WriteLn('Nothing to undo.'); end
        else if Line = 'new' then StartGame(Game,P)
        else if Line = 'fen' then WriteLn(SaveFEN(Game.Position))
        else if Line = 'pgn' then WriteLn(ExportPGN(Game))
        else if Line = 'claim' then begin if not ClaimDraw(Game) then WriteLn('No draw claim available.'); end
        else if (Line = 'hint') or (Line = 'ai') then
        begin
          if Game.Outcome <> ocPlaying then begin WriteLn(OutcomeText(Game.Outcome)); Continue; end;
          Reply := Search(Game.Position,Budget,Depth);
          if Reply.HasMove then
          begin
            WriteLn('Suggested: ',MoveName(Reply.Move),' ',SAN(Game.Position,Reply.Move));
            if Line = 'ai' then PlayMove(Game,Reply.Move);
          end;
        end
        else if FindMove(Game.Position,Line,M) then
        begin if not PlayMove(Game,M) then WriteLn('Game ended or history capacity reached.'); end
        else WriteLn('Illegal move or unknown command. Type help.');
      until False;
    end;
  except
    on E: Exception do begin WriteLn(StdErr,'Error: ',E.Message); Halt(1); end;
  end;
end.
