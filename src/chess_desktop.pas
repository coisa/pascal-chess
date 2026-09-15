unit chess_desktop;

{$mode objfpc}{$H+}

interface

type
  TDesktopOptions = record
    FEN, Snapshot, Scene: String;
    SelfTest, NoAudio, ReducedMotion, TwoPlayers: Boolean;
  end;

function RunDesktop(const Options: TDesktopOptions): Integer;

implementation

uses SysUtils, Math, chess_engine, chess_search, chess_sdl;

const
  CanvasW = 1280; CanvasH = 900;
  BoardX = 64; BoardY = 156; CellSize = 80;
  Ink = $11171D; Panel = $1A222B; Edge = $2D3A46;
  Gold = $E5BA73; White = $F3EFE5; Muted = $A7B1BA;
  Coral = $F18C82; LightSquare = $E2DFD2; DarkSquare = $647D86;
  FontSizes: array[0..4] of Integer = (12,16,22,32,48);
  Budgets: array[0..2] of Integer = (6000,40000,160000);
  SkillNames: array[0..2] of String = ('CASUAL','CLUB','DEEP');

type
  TTextCache = record
    Text: String; Font, W, H: Integer; Texture: Pointer;
  end;
  TApp = record
    Window, Renderer: Pointer;
    Fonts: array[0..4] of Pointer;
    Cache: array[0..127] of TTextCache;
    CacheNext: Integer;
    Audio: LongWord;
    FPMask: TFPUExceptionMask;
    SDLReady, TTFReady, Quit, Muted, ReducedMotion, Fullscreen: Boolean;
    Game: TGame;
    Initial: TPosition;
    HumanSide, PendingSide, Skill, Selected, Cursor: Integer;
    Flipped, Busy, CancelSearch, HintRequested, FocusPaused, NewDialog: Boolean;
    PendingPromotion, HintValid: Boolean;
    PromotionMove, HintMove, LastMove: TMove;
    MovingPiece: Integer;
    Elapsed, Animation, ToastLife: Double;
    LastSearchFrame: QWord;
    MouseX, MouseY: Single;
    ToastText: String;
    LastDepth, LastNodes: Integer;
  end;

var A: TApp;

function RGBA(Value: LongWord; Alpha: Byte = 255): TColor;
begin
  Result.R := (Value shr 16) and 255;
  Result.G := (Value shr 8) and 255;
  Result.B := Value and 255;
  Result.A := Alpha;
end;

function Blend(FromColor, ToColor: LongWord; T: Double): LongWord;
var C, D: TColor;
begin
  C := RGBA(FromColor); D := RGBA(ToColor);
  Result := (LongWord(Round(C.R + (D.R - C.R) * T)) shl 16) or
    (LongWord(Round(C.G + (D.G - C.G) * T)) shl 8) or
    LongWord(Round(C.B + (D.B - C.B) * T));
end;

procedure SetColor(Color: LongWord; Alpha: Byte = 255);
var C: TColor;
begin
  C := RGBA(Color, Alpha);
  SDL_SetRenderDrawColor(A.Renderer, C.R, C.G, C.B, C.A);
end;

procedure Rect(X, Y, W, H: Double; Color: LongWord; Alpha: Byte = 255);
var R: TRect;
begin
  R.X := Round(X); R.Y := Round(Y); R.W := Round(W); R.H := Round(H);
  SetColor(Color, Alpha);
  SDL_RenderFillRect(A.Renderer, @R);
end;

procedure Circle(X, Y, Radius: Double; Color: LongWord; Alpha: Byte = 255);
var V: array[0..95] of TVertex; I, J: Integer; Angle: Double;
begin
  for I := 0 to 31 do
    for J := 0 to 2 do
    begin
      V[I * 3 + J].Color := RGBA(Color, Alpha);
      V[I * 3 + J].TexCoord.X := 0;
      V[I * 3 + J].TexCoord.Y := 0;
      V[I * 3 + J].Position.X := X;
      V[I * 3 + J].Position.Y := Y;
      if J > 0 then
      begin
        Angle := (I + J - 1) * Pi / 16;
        V[I * 3 + J].Position.X := X + Cos(Angle) * Radius;
        V[I * 3 + J].Position.Y := Y + Sin(Angle) * Radius;
      end;
    end;
  SDL_RenderGeometry(A.Renderer, nil, @V[0], Length(V), nil, 0);
end;

procedure Rounded(X, Y, W, H, Radius: Double; Color: LongWord; Alpha: Byte = 255);
begin
  Rect(X + Radius, Y, W - Radius * 2, H, Color, Alpha);
  Rect(X, Y + Radius, Radius, H - Radius * 2, Color, Alpha);
  Rect(X + W - Radius, Y + Radius, Radius, H - Radius * 2, Color, Alpha);
  Circle(X + Radius, Y + Radius, Radius, Color, Alpha);
  Circle(X + W - Radius, Y + Radius, Radius, Color, Alpha);
  Circle(X + Radius, Y + H - Radius, Radius, Color, Alpha);
  Circle(X + W - Radius, Y + H - Radius, Radius, Color, Alpha);
end;

function CachedText(const Value: String; FontIndex: Integer): Integer;
var I: Integer; Surface: Pointer;
begin
  for I := 0 to High(A.Cache) do
    if (A.Cache[I].Texture <> nil) and (A.Cache[I].Text = Value) and
       (A.Cache[I].Font = FontIndex) then Exit(I);
  Result := A.CacheNext;
  A.CacheNext := (A.CacheNext + 1) mod Length(A.Cache);
  with A.Cache[Result] do
  begin
    if Texture <> nil then SDL_DestroyTexture(Texture);
    Texture := nil;
    Text := Value; Font := FontIndex;
  end;
  Surface := TTF_RenderUTF8_Blended(A.Fonts[FontIndex], PChar(Value), RGBA($FFFFFF));
  if Surface = nil then raise Exception.Create('Could not rasterize text: ' + String(SDL_GetError()));
  try
    A.Cache[Result].Texture := SDL_CreateTextureFromSurface(A.Renderer, Surface);
  finally
    SDL_FreeSurface(Surface);
  end;
  with A.Cache[Result] do
  begin
    if Texture = nil then raise Exception.Create('Could not create text texture.');
    SDL_QueryTexture(Texture, nil, nil, @W, @H);
  end;
end;

procedure Text(X, Y: Double; const Value: String; Font: Integer;
  Color: LongWord; Center: Boolean = False);
var I: Integer; R: TRect; C: TColor;
begin
  if Value = '' then Exit;
  I := CachedText(Value, Font);
  R.X := Round(X); R.Y := Round(Y);
  R.W := A.Cache[I].W; R.H := A.Cache[I].H;
  if Center then Dec(R.X, R.W div 2);
  C := RGBA(Color);
  SDL_SetTextureColorMod(A.Cache[I].Texture, C.R, C.G, C.B);
  SDL_RenderCopy(A.Renderer, A.Cache[I].Texture, nil, @R);
end;

function Inside(X, Y, W, H: Integer): Boolean;
begin
  Result := (A.MouseX >= X) and (A.MouseX < X + W) and
    (A.MouseY >= Y) and (A.MouseY < Y + H);
end;

procedure Button(X, Y, W, H: Integer; const LabelText: String; Selected: Boolean;
  Enabled: Boolean = True; FontIndex: Integer = 1);
var Background, Foreground: LongWord;
begin
  Background := $1C2935; Foreground := Muted;
  if Enabled and Inside(X, Y, W, H) then Background := $304252;
  if Selected then begin Background := Gold; Foreground := Ink; end;
  if not Enabled then
    if Selected then begin Background := $213A30; Foreground := Gold; end
    else begin Background := $18232E; Foreground := $71818F; end;
  Rounded(X, Y, W, H, 10, Background);
  Text(X + W / 2, Y + (H - FontSizes[FontIndex] - 3) / 2,
    LabelText, FontIndex, Foreground, True);
end;

procedure Tone(Frequency: Double; Falling: Boolean = False);
var Samples: array[0..5759] of SmallInt; I: Integer; T, Envelope, Phase: Double;
begin
  if A.Muted or (A.Audio = 0) then Exit;
  SDL_ClearQueuedAudio(A.Audio);
  Phase := 0;
  for I := 0 to High(Samples) do
  begin
    T := I / Length(Samples);
    Envelope := Sin(Pi * T) * (1 - T);
    if Falling then Phase := Phase + 2 * Pi * Frequency * (1 - T * 0.7) / 48000
    else Phase := Phase + 2 * Pi * Frequency / 48000;
    Samples[I] := Round((Sin(Phase) + Sin(Phase * 2) * 0.18) * Envelope * 4800);
  end;
  if SDL_QueueAudio(A.Audio, @Samples[0], SizeOf(Samples)) <> 0 then
  begin
    SDL_CloseAudioDevice(A.Audio); A.Audio := 0;
  end;
end;


procedure Poly(X,Y,Scale: Double; const Points: array of Integer; Color: LongWord);
var I,J,K,N,LowY,HighY,Row: Integer; Crossings: array[0..63] of Double;
  X1,Y1,X2,Y2,Scan,Value: Double;
begin
  FillChar(Crossings,SizeOf(Crossings),0);
  LowY := 80; HighY := 0;
  for I := 0 to Length(Points) div 2-1 do
  begin LowY := Min(LowY,Points[I*2+1]); HighY := Max(HighY,Points[I*2+1]); end;
  SetColor(Color);
  for Row := Floor(Y+LowY*Scale) to Ceil(Y+HighY*Scale)-1 do
  begin
    N := 0; Scan := (Row+0.5-Y)/Scale;
    for I := 0 to Length(Points) div 2-1 do
    begin
      J := (I+1) mod (Length(Points) div 2);
      X1 := Points[I*2]; Y1 := Points[I*2+1];
      X2 := Points[J*2]; Y2 := Points[J*2+1];
      if ((Y1 <= Scan) and (Y2 > Scan)) or ((Y2 <= Scan) and (Y1 > Scan)) then
      begin
        Value := X + Scale*(X1+(Scan-Y1)*(X2-X1)/(Y2-Y1));
        K := N-1;
        while (K >= 0) and (Crossings[K] > Value) do
        begin Crossings[K+1] := Crossings[K]; Dec(K); end;
        Crossings[K+1] := Value; Inc(N);
      end;
    end;
    I := 0;
    while I+1 < N do
    begin SDL_RenderDrawLine(A.Renderer,Round(Crossings[I]),Row,Round(Crossings[I+1]),Row); Inc(I,2); end;
  end;
end;

procedure Piece(X,Y,Size: Double; Value: Integer);
var Fill, Rim, Shine: LongWord; S: Double; I: Integer;
  procedure R(L,T,W,H: Double; C: LongWord);
  begin Rounded(X+L*S,Y+T*S,W*S,H*S,2*S,C); end;
  procedure C(L,T,Radius: Double; Color: LongWord);
  begin Circle(X+L*S,Y+T*S,Radius*S,Color); end;
  procedure Shape(const P: array of Integer; Color: LongWord);
  begin Poly(X,Y,S,P,Color); end;
begin
  if Value = 0 then Exit;
  S := Size/80;
  if Value > 0 then begin Fill := $F8F3E4; Rim := $52616A; Shine := $FFFFFF; end
  else begin Fill := $23333F; Rim := $D1B58A; Shine := $486170; end;
  Rounded(X+18*S,Y+66*S,47*S,8*S,4*S,$18222A,65);
  Shape([29,34,51,34,54,58,26,58],Rim);
  Shape([32,35,48,35,51,57,29,57],Fill);
  case Abs(Value) of
    Pawn: begin C(40,25,13,Rim); C(40,24,11,Fill); C(37,20,3,Shine); R(28,37,24,5,Rim); end;
    Knight:
      begin
        Shape([25,58,28,44,40,31,31,34,20,31,21,24,30,14,30,7,40,13,47,11,58,26,57,43,53,58],Rim);
        Shape([29,56,32,43,46,28,31,30,24,28,25,25,34,16,34,13,41,17,46,15,54,28,53,43,50,56],Fill);
        C(38,23,2.2,Shine); R(43,34,3,13,Shine);
      end;
    Bishop:
      begin
        Shape([40,8,55,25,54,30,42,42,26,30,26,25],Rim);
        Shape([40,12,51,26,50,29,41,38,30,29,30,26],Fill);
        Poly(X,Y,S,[43,17,46,20,35,32,32,29],Rim);
        C(40,9,3,Rim); R(28,40,24,4,Rim);
      end;
    Rook:
      begin
        R(23,15,34,25,Rim);
        R(27,19,26,17,Fill);
        R(21,12,10,14,Rim); R(35,12,10,14,Rim); R(49,12,10,14,Rim);
        R(24,14,5,9,Fill); R(38,14,5,9,Fill); R(52,14,5,9,Fill);
        R(26,38,28,5,Rim); R(31,44,4,10,Shine);
      end;
    Queen:
      begin
        Shape([24,37,17,17,30,24,32,12,40,23,48,12,50,24,63,17,56,37],Rim);
        Shape([27,34,23,23,32,29,34,20,40,29,46,20,48,29,57,23,53,34],Fill);
        for I := 0 to 4 do C(18+I*11,16-4*Ord(I in [1,3]),3.5,Rim);
        R(25,37,30,5,Rim);
      end;
    King:
      begin
        R(36,8,8,19,Rim); R(29,14,22,7,Rim);
        R(38,10,4,16,Fill); R(31,16,18,3,Fill);
        Shape([25,28,55,28,51,42,29,42],Rim);
        Shape([29,31,51,31,48,38,32,38],Fill);
        R(28,41,24,4,Rim);
      end;
  end;
  R(25,57,30,6,Rim); R(27,58,26,3,Fill);
  R(18,63,44,7,Rim); R(21,64,38,4,Fill);
end;

procedure SquareXY(Square: Integer; out X,Y: Double);
var FileNo,Rank: Integer;
begin
  FileNo := Square mod 8; Rank := Square div 8;
  if A.Flipped then begin FileNo := 7-FileNo; Rank := 7-Rank; end;
  X := BoardX+FileNo*CellSize; Y := BoardY+(7-Rank)*CellSize;
end;

function MouseSquare: Integer;
var FileNo, Rank: Integer;
begin
  Result := -1;
  if not Inside(BoardX,BoardY,CellSize*8,CellSize*8) then Exit;
  FileNo := Trunc(A.MouseX-BoardX) div CellSize;
  Rank := 7-Trunc(A.MouseY-BoardY) div CellSize;
  if A.Flipped then begin FileNo := 7-FileNo; Rank := 7-Rank; end;
  Result := Rank*8+FileNo;
end;

procedure Outline(X,Y,W,H: Double; Color: LongWord; Thickness: Integer = 3);
begin
  Rect(X,Y,W,Thickness,Color); Rect(X,Y+H-Thickness,W,Thickness,Color);
  Rect(X,Y,Thickness,H,Color); Rect(X+W-Thickness,Y,Thickness,H,Color);
end;

procedure DrawBoard;
var S,I,KingSquare: Integer; X,Y,FromX,FromY,T: Double; Color: LongWord;
  Moves: TMoveList;
begin
  Rounded(BoardX-9,BoardY-9,658,658,13,Edge);
  LegalMoves(A.Game.Position,Moves); KingSquare := -1;
  if InCheck(A.Game.Position,A.Game.Position.Turn) then
    for S := 0 to 63 do
      if A.Game.Position.Board[S] = A.Game.Position.Turn*King then KingSquare := S;
  for S := 0 to 63 do
  begin
    SquareXY(S,X,Y);
    if (S mod 8 + S div 8) mod 2 = 0 then Color := DarkSquare else Color := LightSquare;
    Rect(X,Y,CellSize,CellSize,Color);
    if (A.Game.Count > 0) and ((S = A.LastMove.FromSquare) or (S = A.LastMove.ToSquare)) then
      Rect(X,Y,CellSize,CellSize,Gold,92);
    if S = KingSquare then Rect(X,Y,CellSize,CellSize,Coral,150);
    if S = A.Selected then Rect(X,Y,CellSize,CellSize,$F4D293,150);
    if S = A.Cursor then Outline(X+3,Y+3,74,74,$F7E5C1,2);
    if A.HintValid and ((S = A.HintMove.FromSquare) or (S = A.HintMove.ToSquare)) then
      Outline(X+5,Y+5,70,70,$7EE0C6,3);
    if (A.Animation <= 0) or (S <> A.LastMove.ToSquare) then
      Piece(X,Y,CellSize,A.Game.Position.Board[S]);
    if A.Selected >= 0 then
      for I := 0 to Moves.Count-1 do
        with Moves.Items[I] do
          if (FromSquare = A.Selected) and (ToSquare = S) then
          begin
            if A.Game.Position.Board[S] = 0 then Circle(X+40,Y+40,8,Ink,75)
            else Outline(X+5,Y+5,70,70,Gold,4);
            Break;
          end;
  end;
  if A.Animation > 0 then
  begin
    SquareXY(A.LastMove.FromSquare,FromX,FromY); SquareXY(A.LastMove.ToSquare,X,Y);
    T := 1-A.Animation/0.22; T := T*T*(3-2*T);
    Piece(FromX+(X-FromX)*T,FromY+(Y-FromY)*T,CellSize,A.MovingPiece);
  end;
  for S := 0 to 7 do
  begin
    I := S; if A.Flipped then I := 7-S;
    Text(BoardX+S*80+40,BoardY+651,Chr(Ord('a')+I),0,Muted,True);
    Text(BoardX-24,BoardY+S*80+30,IntToStr(8-I),0,Muted,True);
  end;
end;

function JournalFirstNumber: Integer;
begin
  Result := A.Game.Positions[0].Fullmove;
  if A.Game.Count > 0 then
    Result := Max(Result,A.Game.Positions[A.Game.Count-1].Fullmove-5);
end;

procedure JournalCell(Index: Integer; out Row,Column: Integer);
begin
  Row := A.Game.Positions[Index].Fullmove-JournalFirstNumber;
  Column := 0; if A.Game.Positions[Index].Turn = BlackSide then Column := 1;
end;

procedure Draw;
var I,J,First,Row,MoveRow,Material: Integer; LabelText, Detail: String; Color: LongWord;
begin
  SetColor(Ink); SDL_RenderClear(A.Renderer);
  Rounded(48,35,52,52,12,Gold); Piece(55,38,38,-Rook);
  Text(116,32,'PASCAL CHESS',3,White);
  Text(117,73,'A COLLEGE PROJECT. A NEW CHAPTER.',0,Muted);
  Text(1176,48,'AFTER CLASS',0,Gold,True);
  Rect(48,112,1184,1,Edge);
  Text(64,125,'THE BOARD',0,Muted);
  if A.Flipped then LabelText := 'BLACK PERSPECTIVE' else LabelText := 'WHITE PERSPECTIVE';
  Text(520,125,LabelText,0,Muted);
  DrawBoard;
  Rounded(760,144,456,210,16,Panel);
  if A.Game.Position.Turn = WhiteSide then LabelText := 'WHITE TO MOVE' else LabelText := 'BLACK TO MOVE';
  Detail := 'Pick a piece. Find your next move.';
  if A.Busy then begin LabelText := 'PASCAL IS THINKING'; Detail := 'Searching in Pascal. Escape to cancel.'; end
  else if A.FocusPaused then begin LabelText := 'GAME PAUSED'; Detail := 'Click the board or press Space to resume.'; end
  else if A.Game.Outcome <> ocPlaying then
  begin LabelText := 'GAME COMPLETE'; Detail := OutcomeText(A.Game.Outcome); end
  else if InCheck(A.Game.Position,A.Game.Position.Turn) then Detail := 'Your king is in check.';
  Circle(784,167,4,Gold); Text(798,158,LabelText,0,Gold);
  if A.Game.Outcome in [ocWhiteWins,ocBlackWins] then LabelText := 'Checkmate.'
  else if A.Game.Outcome <> ocPlaying then LabelText := 'A shared point.'
  else if A.Busy then LabelText := 'Every move matters.'
  else LabelText := 'Make your move.';
  Text(780,181,LabelText,3,White); Text(781,223,Detail,1,Muted);
  Button(780,260,132,36,'Play White',A.HumanSide=1);
  Button(918,260,132,36,'Play Black',A.HumanSide=-1);
  Button(1056,260,140,36,'Two players',A.HumanSide=0);
  for I := 0 to 2 do Button(780+I*140,310,136,30,SkillNames[I],A.Skill=I,not A.Busy,0);

  Rounded(760,368,456,296,16,Panel);
  Text(780,386,'MOVE JOURNAL',0,Gold);
  Button(1074,378,122,28,'Copy PGN / P',False,not A.Busy,0);
  Rect(780,416,416,1,Edge);
  First := JournalFirstNumber;
  if A.Game.Count = 0 then
  begin
    Piece(958,440,64,King);
    Text(988,522,'A game starts with a little courage.',1,Muted,True);
    Text(988,552,'Click a piece to see its legal moves.',1,Muted,True);
  end
  else
    for Row := 0 to 5 do
    begin
      if First+Row > A.Game.Positions[A.Game.Count-1].Fullmove then Break;
      if Row mod 2 = 0 then Rounded(780,427+Row*34,416,32,5,$202B35);
      Text(794,434+Row*34,IntToStr(First+Row)+'.',1,Muted);
      for I := 0 to A.Game.Count-1 do
        if A.Game.Positions[I].Fullmove = First+Row then
        begin
          JournalCell(I,MoveRow,J);
          Color := White; if I = A.Game.Count-1 then Color := Gold;
          Text(852+J*156,434+MoveRow*34,A.Game.Notation[I],1,Color);
        end;
    end;
  Material := 0;
  for I := 0 to 63 do
    case Abs(A.Game.Position.Board[I]) of
      Pawn: Inc(Material,Sign(A.Game.Position.Board[I]));
      Knight,Bishop: Inc(Material,Sign(A.Game.Position.Board[I])*3);
      Rook: Inc(Material,Sign(A.Game.Position.Board[I])*5);
      Queen: Inc(Material,Sign(A.Game.Position.Board[I])*9);
    end;
  if Material = 0 then LabelText := 'Material is level'
  else if Material > 0 then LabelText := 'White +'+IntToStr(Material)+' material'
  else LabelText := 'Black +'+IntToStr(-Material)+' material';
  Text(780,637,LabelText,0,Muted);
  if A.LastNodes > 0 then Text(980,637,'Depth '+IntToStr(A.LastDepth)+' / '+IntToStr(A.LastNodes)+' nodes',0,Muted);
  Button(760,680,144,46,'Hint / H',False,(A.Game.Outcome=ocPlaying) and not A.Busy);
  Button(916,680,144,46,'Undo / U',False,(A.Game.Count>0) and not A.Busy);
  Button(1072,680,144,46,'New / N',True,not A.Busy);
  if CanClaimDraw(A.Game) then Button(760,742,456,42,'Claim draw / D',True)
  else
  begin
    Text(780,748,'NO CLOCK. NO ACCOUNT. JUST CHESS.',0,Muted);
    Text(780,773,'All game logic and search written in Pascal.',0,Muted);
  end;
  Rect(48,832,1184,1,Edge);
  Text(64,851,'Arrows + Enter: move    F: flip    H: hint    U: undo',0,Muted);
  LabelText := 'Sound on'; if A.Muted or (A.Audio=0) then LabelText := 'Sound off';
  Button(760,845,140,32,LabelText+' / M',False,True,0);
  LabelText := 'Motion on'; if A.ReducedMotion then LabelText := 'Motion off';
  Button(912,845,164,32,LabelText+' / V',False,True,0);
  Button(1088,845,128,32,'Fullscreen',False,True,0);
  if A.ToastLife > 0 then
  begin
    Rounded(200,770,376,44,12,Ink);
    Text(388,783,A.ToastText,1,Gold,True);
  end;
  if A.PendingPromotion or A.NewDialog then
  begin
    Rect(0,0,CanvasW,CanvasH,Ink,205); Rounded(380,304,520,258,20,Panel);
    if A.PendingPromotion then
    begin
      Text(640,330,'Your pawn has earned this.',2,White,True);
      Text(640,367,'Choose a piece. Q / R / B / N',1,Muted,True);
      for I := 0 to 3 do
      begin
        J := Queen-I; Button(416+I*116,413,104,112,'',False);
        Piece(428+I*116,417,80,J*A.Game.Position.Turn);
        Text(468+I*116,499,PieceChar(J),1,Gold,True);
      end;
    end
    else
    begin
      Text(640,335,'Start a new game?',3,White,True);
      Text(640,387,'This replaces the current game in memory.',1,Muted,True);
      Button(424,461,208,52,'Keep playing / Esc',False);
      Button(648,461,208,52,'New game / Enter',True);
    end;
  end;
end;

procedure Toast(const MessageText: String);
begin A.ToastText := MessageText; A.ToastLife := 3; end;

procedure ResetGame;
begin
  StartGame(A.Game,A.Initial); A.Selected := -1; A.Cursor := 12;
  A.HintValid := False; A.PendingPromotion := False; A.NewDialog := False;
  A.FocusPaused := False; A.Animation := 0; A.ToastLife := 0;
  A.HintRequested := False;
  A.LastDepth := 0; A.LastNodes := 0; A.Flipped := A.HumanSide = BlackSide;
end;

procedure CommitMove(const M: TMove);
var MovingPiece: Integer;
begin
  MovingPiece := A.Game.Position.Board[M.FromSquare];
  if not PlayMove(A.Game,M) then begin Toast('Game ended or history limit reached.'); Exit; end;
  A.LastMove := M; A.MovingPiece := MovingPiece;
  A.Animation := 0; if not A.ReducedMotion then A.Animation := 0.22;
  A.Selected := -1; A.Cursor := M.ToSquare; A.HintValid := False;
  A.PendingPromotion := False;
  if InCheck(A.Game.Position,A.Game.Position.Turn) then Tone(650)
  else Tone(360+Abs(MovingPiece)*40);
end;

procedure SelectSquare(Square: Integer);
var Moves: TMoveList; I: Integer;
begin
  if (Square < 0) or A.Busy or (A.Game.Outcome <> ocPlaying) then Exit;
  if A.FocusPaused then begin A.FocusPaused := False; Exit; end;
  if (A.HumanSide <> 0) and (A.Game.Position.Turn <> A.HumanSide) then Exit;
  A.Cursor := Square;
  if A.Selected >= 0 then
  begin
    LegalMoves(A.Game.Position,Moves);
    for I := 0 to Moves.Count-1 do
      with Moves.Items[I] do
        if (FromSquare = A.Selected) and (ToSquare = Square) then
        begin
          if Promotion <> 0 then
          begin A.PendingPromotion := True; A.PromotionMove := Moves.Items[I]; end
          else CommitMove(Moves.Items[I]);
          Exit;
        end;
  end;
  if A.Game.Position.Board[Square]*A.Game.Position.Turn > 0 then
  begin A.Selected := Square; A.HintValid := False; end
  else begin A.Selected := -1; Toast('Select a piece, then a highlighted square.'); end;
end;

procedure Promote(Promotion: Integer);
begin
  if not A.PendingPromotion then Exit;
  A.PromotionMove.Promotion := Promotion;
  CommitMove(A.PromotionMove);
end;

procedure RequestNew(Side: Integer);
begin
  A.PendingSide := Side;
  if (A.Game.Count > 0) or A.Busy then
  begin A.NewDialog := True; A.CancelSearch := True; end
  else begin A.HumanSide := Side; ResetGame; end;
end;

procedure Undo;
begin
  if A.Busy then begin A.CancelSearch := True; Toast('Search cancelled. Press U to undo.'); Exit; end;
  if UndoMove(A.Game) then
  begin
    if (A.HumanSide <> 0) and (A.Game.Position.Turn <> A.HumanSide) then UndoMove(A.Game);
    A.Animation := 0; A.Selected := -1; A.HintValid := False;
    A.PendingPromotion := False; A.LastDepth := 0; A.LastNodes := 0;
    if A.Game.Count > 0 then A.LastMove := A.Game.Moves[A.Game.Count-1];
    Tone(280);
  end;
end;

procedure HandleKey(Key: LongInt);
var Step, FileNo, Rank: Integer;
begin
  if A.PendingPromotion then
  begin
    case Key of
      Ord('q'): Promote(Queen); Ord('r'): Promote(Rook);
      Ord('b'): Promote(Bishop); Ord('n'): Promote(Knight);
      27: begin A.PendingPromotion := False; A.Selected := -1; end;
    end;
    Exit;
  end;
  if A.NewDialog then
  begin
    if Key = 27 then A.NewDialog := False;
    if Key = 13 then begin A.HumanSide := A.PendingSide; ResetGame; end;
    Exit;
  end;
  case Key of
    27: begin A.Selected := -1; A.HintValid := False; A.CancelSearch := True; end;
    Ord('q'): begin A.Quit := True; A.CancelSearch := True; end;
    Ord('f'): A.Flipped := not A.Flipped;
    Ord('m'):
      begin
        A.Muted := not A.Muted;
        if A.Muted and (A.Audio <> 0) then SDL_ClearQueuedAudio(A.Audio);
      end;
    Ord('v'): begin A.ReducedMotion := not A.ReducedMotion; A.Animation := 0; end;
    Ord('n'): RequestNew(A.HumanSide);
    Ord('u'): Undo;
    Ord('h'): if not A.Busy and (A.Game.Outcome = ocPlaying) then A.HintRequested := True;
    Ord('d'): if not A.Busy then begin if not ClaimDraw(A.Game) then Toast('No draw claim available.'); end;
    Ord('c'),Ord('p'):
      if not A.Busy then
      begin
        if Key = Ord('c') then
          Step := SDL_SetClipboardText(PChar(SaveFEN(A.Game.Position)))
        else Step := SDL_SetClipboardText(PChar(ExportPGN(A.Game)));
        if Step = 0 then Toast('Copied. Paste into your chess study tool.')
        else Toast('Clipboard is unavailable.');
      end;
    Ord('1')..Ord('3'): if not A.Busy then A.Skill := Key-Ord('1');
    32: if A.FocusPaused then A.FocusPaused := False;
    KeyF11:
      begin
        A.Fullscreen := not A.Fullscreen;
        if SDL_SetWindowFullscreen(A.Window,LongWord(Ord(A.Fullscreen))*$1001) <> 0 then
        begin A.Fullscreen := False; Toast('Fullscreen is unavailable.'); end;
      end;
    KeyLeft,KeyRight,KeyUp,KeyDown:
      begin
        FileNo := A.Cursor mod 8; Rank := A.Cursor div 8;
        Step := 1; if A.Flipped then Step := -1;
        case Key of
          KeyLeft: Dec(FileNo,Step); KeyRight: Inc(FileNo,Step);
          KeyUp: Inc(Rank,Step); KeyDown: Dec(Rank,Step);
        end;
        if (FileNo >= 0) and (FileNo < 8) and (Rank >= 0) and (Rank < 8) then
          A.Cursor := Rank*8+FileNo;
      end;
    13: SelectSquare(A.Cursor);
  end;
end;

procedure Click;
var I,S: Integer;
begin
  if A.NewDialog then
  begin
    if Inside(424,461,208,52) then A.NewDialog := False;
    if Inside(648,461,208,52) then begin A.HumanSide := A.PendingSide; ResetGame; end;
    Exit;
  end;
  if A.PendingPromotion then
  begin
    for I := 0 to 3 do if Inside(416+I*116,413,104,112) then Promote(Queen-I);
    Exit;
  end;
  S := MouseSquare;
  if S >= 0 then begin SelectSquare(S); Exit; end;
  if Inside(780,260,132,36) then RequestNew(WhiteSide);
  if Inside(918,260,132,36) then RequestNew(BlackSide);
  if Inside(1056,260,140,36) then RequestNew(0);
  for I := 0 to 2 do if Inside(780+I*140,310,136,30) then HandleKey(Ord('1')+I);
  if Inside(760,680,144,46) then HandleKey(Ord('h'));
  if Inside(1074,378,122,28) then HandleKey(Ord('p'));
  if Inside(916,680,144,46) then HandleKey(Ord('u'));
  if Inside(1072,680,144,46) then HandleKey(Ord('n'));
  if Inside(760,742,456,42) and CanClaimDraw(A.Game) then HandleKey(Ord('d'));
  if Inside(760,845,140,32) then HandleKey(Ord('m'));
  if Inside(912,845,164,32) then HandleKey(Ord('v'));
  if Inside(1088,845,128,32) then HandleKey(KeyF11);
end;

procedure Events;
var E: TEvent;
begin
  while SDL_PollEvent(@E) <> 0 do
    case E.Kind of
      EventQuit: begin A.Quit := True; A.CancelSearch := True; end;
      EventKeyDown: if E.Key.Repeated = 0 then HandleKey(E.Key.Keysym.Sym);
      EventMouseDown: if E.Mouse.Button = 1 then
        begin A.MouseX := E.Mouse.X; A.MouseY := E.Mouse.Y; Click; end;
      EventWindow: if E.Window.Event = WindowFocusLost then
        begin A.FocusPaused := True; A.CancelSearch := True; end;
    end;
end;

function SearchPoll: Boolean;
var Now: QWord;
begin
  Events;
  Now := SDL_GetTicks64();
  if Now-A.LastSearchFrame >= 16 then
  begin Draw; SDL_RenderPresent(A.Renderer); A.LastSearchFrame := Now; end;
  Result := not (A.Quit or A.CancelSearch or A.FocusPaused or A.NewDialog);
end;

procedure Think(Hint: Boolean);
var Reply: TSearchResult; Root: TPosition;
begin
  if A.Game.Outcome <> ocPlaying then Exit;
  if not Hint and CanClaimDraw(A.Game) then begin ClaimDraw(A.Game); Exit; end;
  A.Busy := True; A.CancelSearch := False; Root := A.Game.Position;
  A.LastSearchFrame := SDL_GetTicks64(); Draw; SDL_RenderPresent(A.Renderer);
  try
    Reply := Search(Root,Budgets[A.Skill],7,@SearchPoll);
    if Reply.Cancelled or A.CancelSearch or A.Quit or A.FocusPaused or A.NewDialog then
    begin
      if not Hint then A.FocusPaused := True;
      Toast('Search cancelled. Space resumes play.'); Exit;
    end;
    A.LastDepth := Reply.Depth; A.LastNodes := Reply.Nodes;
    if Reply.HasMove then
      if Hint then
      begin
        A.HintMove := Reply.Move; A.HintValid := True;
        Toast('Consider '+SAN(Root,Reply.Move)+' / '+MoveName(Reply.Move));
      end
      else CommitMove(Reply.Move);
  finally A.Busy := False; end;
end;

procedure Update(Delta: Double);
begin
  A.Elapsed := A.Elapsed + Delta; A.Animation := Max(0,A.Animation-Delta);
  A.ToastLife := Max(0,A.ToastLife-Delta);
  if A.Quit or A.NewDialog or A.PendingPromotion or A.FocusPaused or (A.Animation > 0) then Exit;
  if A.HintRequested then begin A.HintRequested := False; Think(True); end
  else if (A.HumanSide <> 0) and (A.Game.Position.Turn <> A.HumanSide) then Think(False);
end;

function FontPath: String;
const Paths: array[0..4] of String = (
  '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  '/System/Library/Fonts/Supplemental/Arial.ttf',
  '/Library/Fonts/Arial.ttf','/usr/share/fonts/TTF/DejaVuSans.ttf',
  '/usr/local/share/fonts/DejaVuSans.ttf');
var Candidate: String;
begin
  Result := GetEnvironmentVariable('CHESS_FONT');
  if Result <> '' then Exit;
  for Candidate in Paths do if FileExists(Candidate) then Exit(Candidate);
  raise Exception.Create('No TrueType font found. Set CHESS_FONT to a readable font file.');
end;

procedure Initialize(const Options: TDesktopOptions);
var I: Integer; Desired: TAudioSpec; Path,Error: String; Flags: LongWord;
begin
  A := Default(TApp); A.FPMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp,exDenormalized,exZeroDivide,exOverflow,exUnderflow,exPrecision]);
  A.Muted := Options.NoAudio; A.ReducedMotion := Options.ReducedMotion;
  A.HumanSide := WhiteSide; if Options.TwoPlayers then A.HumanSide := 0;
  A.Skill := 1;
  if not LoadFEN(Options.FEN,A.Initial,Error) then raise Exception.Create(Error);
  LoadSDL; SDL_SetHint('SDL_RENDER_SCALE_QUALITY','1');
  if SDL_Init($20) <> 0 then raise Exception.Create('Video initialization failed: '+String(SDL_GetError()));
  A.SDLReady := True; Flags := $20 or $2000;
  if Options.SelfTest or (Options.Snapshot <> '') then Flags := Flags or $8;
  A.Window := SDL_CreateWindow('Pascal Chess / After Class',$2FFF0000,$2FFF0000,CanvasW,CanvasH,Flags);
  if A.Window = nil then raise Exception.Create('Could not create a window: '+String(SDL_GetError()));
  SDL_SetWindowMinimumSize(A.Window,960,675);
  A.Renderer := SDL_CreateRenderer(A.Window,-1,$2 or $4);
  if A.Renderer = nil then A.Renderer := SDL_CreateRenderer(A.Window,-1,$1);
  if A.Renderer = nil then raise Exception.Create('Could not create a renderer: '+String(SDL_GetError()));
  SDL_RenderSetLogicalSize(A.Renderer,CanvasW,CanvasH);
  SDL_SetRenderDrawBlendMode(A.Renderer,1);
  if TTF_Init() <> 0 then raise Exception.Create('Could not initialize SDL2_ttf.');
  A.TTFReady := True; Path := FontPath;
  for I := 0 to High(A.Fonts) do
  begin
    A.Fonts[I] := TTF_OpenFont(PChar(Path),FontSizes[I]);
    if A.Fonts[I] = nil then raise Exception.Create('Could not open font: '+Path);
  end;
  if not Options.NoAudio and (SDL_InitSubSystem($10) = 0) then
  begin
    FillChar(Desired,SizeOf(Desired),0); Desired.Frequency := 48000;
    Desired.Format := $8010; Desired.Channels := 1; Desired.Samples := 1024;
    A.Audio := SDL_OpenAudioDevice(nil,0,@Desired,nil,0);
    if A.Audio <> 0 then SDL_PauseAudioDevice(A.Audio,0);
  end;
  ResetGame;
end;

procedure Cleanup;
var I: Integer;
begin
  if A.Audio <> 0 then SDL_CloseAudioDevice(A.Audio);
  for I := 0 to High(A.Cache) do if A.Cache[I].Texture <> nil then SDL_DestroyTexture(A.Cache[I].Texture);
  for I := 0 to High(A.Fonts) do if A.Fonts[I] <> nil then TTF_CloseFont(A.Fonts[I]);
  if A.TTFReady then TTF_Quit;
  if A.Renderer <> nil then SDL_DestroyRenderer(A.Renderer);
  if A.Window <> nil then SDL_DestroyWindow(A.Window);
  if A.SDLReady then SDL_Quit;
  UnloadSDL; SetExceptionMask(A.FPMask);
end;

procedure Snapshot(const FileName: String);
var Pixels: array of LongWord; Surface,RW: Pointer; W,H: LongInt;
begin
  if (SDL_GetRendererOutputSize(A.Renderer,@W,@H) <> 0) or
    (W < 1) or (H < 1) or (W > 8192) or (H > 8192) then
    raise Exception.Create('Unsupported screenshot dimensions.');
  SetLength(Pixels,W*H);
  if SDL_RenderReadPixels(A.Renderer,nil,$16362004,@Pixels[0],W*4) <> 0 then
    raise Exception.Create('Could not read rendered pixels.');
  Surface := SDL_CreateRGBSurfaceFrom(@Pixels[0],W,H,32,W*4,$00FF0000,$0000FF00,$000000FF,$FF000000);
  if Surface = nil then raise Exception.Create('Could not create screenshot surface.');
  try
    RW := SDL_RWFromFile(PChar(FileName),'wb');
    if RW = nil then raise Exception.Create('Could not open screenshot output: '+FileName);
    if SDL_SaveBMP_RW(Surface,RW,1) <> 0 then raise Exception.Create('Could not write screenshot.');
  finally SDL_FreeSurface(Surface); end;
end;

procedure Require(Condition: Boolean; const LabelText: String);
begin if not Condition then raise Exception.Create('SDL test failed: '+LabelText); end;

procedure PushKey(Key: LongInt);
var E: TEvent;
begin
  FillChar(E,SizeOf(E),0); E.Kind := EventKeyDown; E.Key.Keysym.Sym := Key;
  Require(SDL_PushEvent(@E) = 1,'push key'); Events;
end;

procedure PushClick(X,Y: Integer);
var E: TEvent;
begin
  FillChar(E,SizeOf(E),0); E.Kind := EventMouseDown; E.Mouse.Button := 1;
  E.Mouse.X := X; E.Mouse.Y := Y; Require(SDL_PushEvent(@E) = 1,'push click'); Events;
end;

procedure SetScene(const Scene: String);
const Opening: array[0..7] of String = ('e2e4','e7e5','g1f3','b8c6','f1b5','a7a6','b5a4','g8f6');
var I: Integer; M: TMove; P: TPosition; Error: String;
begin
  A.HumanSide := 0; ResetGame; A.ReducedMotion := True;
  if Scene = 'start' then Exit;
  if (Scene = 'play') or (Scene = 'paused') then
  begin
    for I := 0 to High(Opening) do
    begin
      Require(FindMove(A.Game.Position,Opening[I],M),'opening fixture');
      CommitMove(M);
    end;
    A.Selected := ParseSquare('f3'); A.Cursor := A.Selected;
    A.FocusPaused := Scene = 'paused'; A.ToastLife := 0;
  end
  else if Scene = 'promotion' then
  begin
    Require(LoadFEN('7k/P7/8/8/8/8/8/7K w - - 0 1',P,Error),'promotion fixture');
    StartGame(A.Game,P); A.Selected := 48; SelectSquare(56);
  end
  else if Scene = 'mate' then
  begin
    Require(LoadFEN('7k/5Q2/6K1/8/8/8/8/8 w - - 0 1',P,Error),'mate fixture');
    StartGame(A.Game,P); Require(FindMove(P,'f7g7',M),'mate move'); CommitMove(M);
  end;
end;

procedure SelfTest;
const JournalMoves: array[0..4] of String = ('b1c3','f8e7','d2d3','b7b5','a4b3');
var P: TPosition; Error: String; E: TEvent; Before: String; I,Row,Column: Integer;
  Clipboard: PChar; M: TMove; InitialMuted,InitialMotion: Boolean;
begin
  Events; A.FocusPaused := False; A.HumanSide := 0; ResetGame;
  InitialMuted := A.Muted; InitialMotion := A.ReducedMotion;
  PushClick(424,676); Require(A.Selected = 12,'pointer selects e2');
  PushClick(424,516); Require((A.Game.Count = 1) and (A.Game.Position.Board[28] = Pawn),'pointer plays e4');
  Require((A.Animation > 0) = not InitialMotion,'animation respects initial motion'); A.Animation := 0;
  A.Cursor := 52; PushKey(13); PushKey(KeyDown); PushKey(KeyDown); PushKey(13);
  Require(A.Game.Count = 2,'keyboard plays e5');
  { Dummy driver uses an isolated clipboard; never replace a native user's clipboard in tests. }
  if GetEnvironmentVariable('SDL_VIDEODRIVER') = 'dummy' then
  begin
    PushKey(Ord('c')); Clipboard := SDL_GetClipboardText();
    Require(Clipboard <> nil,'clipboard read');
    try Require(String(Clipboard) = SaveFEN(A.Game.Position),'copy FEN'); finally SDL_free(Clipboard); end;
    PushKey(Ord('p')); Clipboard := SDL_GetClipboardText();
    Require(Clipboard <> nil,'clipboard PGN read');
    try Require(Pos('1. e4 e5',String(Clipboard)) > 0,'copy PGN'); finally SDL_free(Clipboard); end;
  end;
  PushKey(Ord('u')); Require(A.Game.Count = 1,'undo');
  PushKey(Ord('f')); Require(A.Flipped,'flip');
  PushKey(Ord('m')); Require(A.Muted <> InitialMuted,'mute toggles');
  Require((A.Audio = 0) or (SDL_GetQueuedAudioSize(A.Audio) = 0),'mute clears queue');
  PushKey(Ord('v')); Require((A.ReducedMotion <> InitialMotion) and (A.Animation = 0),'reduced motion toggles');
  PushKey(Ord('3')); Require(A.Skill = 2,'search pace');
  PushKey(Ord('n')); Require(A.NewDialog,'new game confirmation');
  PushKey(27); Require(A.Game.Count = 1,'cancel keeps game');
  PushKey(Ord('n')); PushKey(13); Require(A.Game.Count = 0,'new game');
  A.Skill := 0; Before := SaveFEN(A.Game.Position);
  PushKey(Ord('h')); Update(0); Require(A.HintValid,'hint appears');
  Require(SaveFEN(A.Game.Position) = Before,'hint preserves position');
  A.HumanSide := BlackSide; Update(0); Require(A.Game.Count = 1,'computer move');
  FillChar(E,SizeOf(E),0); E.Kind := EventWindow; E.Window.Event := WindowFocusLost;
  SDL_PushEvent(@E); Events; Require(A.FocusPaused,'focus loss');
  Before := SaveFEN(A.Game.Position); Update(1);
  Require(SaveFEN(A.Game.Position) = Before,'paused game frozen');
  PushKey(32); Require(not A.FocusPaused,'resume');
  A.HumanSide := 0;
  for I := Knight to Queen do
  begin
    Require(LoadFEN('7k/P7/8/8/8/8/8/7K w - - 0 1',P,Error),'promotion test FEN');
    StartGame(A.Game,P); A.Selected := 48; SelectSquare(56);
    Require(A.PendingPromotion,'promotion dialog');
    Promote(I); Require(A.Game.Position.Board[56] = I,'chosen promotion');
  end;
  SetScene('play');
  for I := 0 to High(JournalMoves) do
  begin
    Require(FindMove(A.Game.Position,JournalMoves[I],M),'journal move'); CommitMove(M);
  end;
  JournalCell(12,Row,Column);
  Require((A.Game.Count = 13) and (Row = 5) and (Column = 0),'newest odd ply remains visible');
  Require(LoadFEN('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 7',P,Error),'black-first FEN');
  StartGame(A.Game,P); Require(FindMove(P,'e7e5',M),'black-first move'); CommitMove(M);
  JournalCell(0,Row,Column); Require((Row = 0) and (Column = 1),'black-first journal column');
  Require(FindMove(A.Game.Position,'g1f3',M),'white response'); CommitMove(M);
  JournalCell(1,Row,Column); Require((Row = 1) and (Column = 0),'new move number in journal');
  SetScene('mate'); Require(A.Game.Outcome = ocWhiteWins,'checkmate state');
  Before := SaveFEN(A.Game.Position); SelectSquare(0); Update(1);
  Require(SaveFEN(A.Game.Position) = Before,'finished state frozen');
  A.NewDialog := False; Draw; SDL_RenderPresent(A.Renderer);
  PushKey(Ord('q')); Require(A.Quit,'clean quit');
  WriteLn('PASS SDL replay: pointer, keyboard, legal moves, promotion, hints, AI, undo, focus and lifecycle');
end;

function RunDesktop(const Options: TDesktopOptions): Integer;
var Last,Now,FrameTime: QWord; Delta: Double; MX,MY: LongInt;
begin
  Result := 0;
  try
    try
      Initialize(Options);
      if Options.SelfTest then SelfTest
      else if Options.Snapshot <> '' then
      begin
        SetScene(Options.Scene); Draw; Snapshot(Options.Snapshot);
        WriteLn('Saved rendered frame: '+Options.Snapshot);
      end
      else
      begin
        Last := SDL_GetTicks64();
        while not A.Quit do
        begin
          Now := SDL_GetTicks64(); Delta := Min(0.05,(Now-Last)/1000); Last := Now;
          SDL_GetMouseState(@MX,@MY);
          SDL_RenderWindowToLogical(A.Renderer,MX,MY,@A.MouseX,@A.MouseY);
          Events; Update(Delta); Draw; SDL_RenderPresent(A.Renderer);
          FrameTime := SDL_GetTicks64()-Now;
          if FrameTime < 16 then SDL_Delay(16-FrameTime);
        end;
      end;
    finally Cleanup; end;
  except
    on E: Exception do
    begin
      WriteLn(StdErr,E.Message);
      if GetEnvironmentVariable('CHESS_DEBUG') = '1' then DumpExceptionBackTrace(StdErr);
      Result := 1;
    end;
  end;
end;

end.
