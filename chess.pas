program chess;

{$mode objfpc}{$H+}

uses SysUtils, chess_engine, chess_desktop;

var Options: TDesktopOptions; I: Integer; P: TPosition; Error: String;

function Value: String;
begin
  Inc(I); if I > ParamCount then raise Exception.Create('Missing option value.');
  Result := ParamStr(I);
end;

begin
  try
    Options := Default(TDesktopOptions); Options.FEN := StartFEN; Options.Scene := 'play'; I := 1;
    while I <= ParamCount do
    begin
      case ParamStr(I) of
        '--help': begin
          WriteLn('Pascal Chess 1.0.0 / After Class');
          WriteLn('Usage: chess [--fen "FEN"] [--two-players] [--no-audio] [--reduced-motion]');
          WriteLn('             [--self-test | --snapshot FILE.bmp [--scene start|play|paused|promotion|mate]]');
          WriteLn('Controls: click a piece and destination, or arrows + Enter.');
          WriteLn('H hint / U undo / N new / F flip / D claim draw / M mute / V reduced motion');
          WriteLn('C copy FEN / P copy PGN (clipboard only, no automatic player files)');
          WriteLn('1-3 search pace / F11 fullscreen / Space resume / Esc cancel / Q quit');
          Halt(0);
        end;
        '--fen': Options.FEN := Value;
        '--snapshot': Options.Snapshot := Value;
        '--scene': Options.Scene := Value;
        '--self-test': Options.SelfTest := True;
        '--no-audio': Options.NoAudio := True;
        '--reduced-motion': Options.ReducedMotion := True;
        '--two-players': Options.TwoPlayers := True;
        else raise Exception.Create('Unknown option: '+ParamStr(I));
      end;
      Inc(I);
    end;
    if Options.SelfTest and (Options.Snapshot <> '') then raise Exception.Create('Choose self-test or snapshot.');
    if (Options.Scene <> 'start') and (Options.Scene <> 'play') and (Options.Scene <> 'paused') and
      (Options.Scene <> 'promotion') and (Options.Scene <> 'mate') then raise Exception.Create('Unknown snapshot scene.');
    if not LoadFEN(Options.FEN,P,Error) then raise Exception.Create(Error);
    Halt(RunDesktop(Options));
  except
    on E: Exception do begin WriteLn(StdErr,'Error: '+E.Message); Halt(1); end;
  end;
end.
