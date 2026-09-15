unit chess_sdl;

{$mode objfpc}{$H+}{$packrecords c}

interface

uses Dynlibs;

{ Minimal declarations for the public SDL2 C ABI. See docs/architecture.md. }
type
  TColor = record R, G, B, A: Byte; end;
  TRect = record X, Y, W, H: LongInt; end;
  TFPoint = record X, Y: Single; end;
  TVertex = record Position: TFPoint; Color: TColor; TexCoord: TFPoint; end;
  TKeySym = record ScanCode, Sym: LongInt; Modifiers: Word; Unused: LongWord; end;
  TKeyEvent = record
    Kind, Timestamp, WindowID: LongWord;
    State, Repeated, Pad2, Pad3: Byte;
    Keysym: TKeySym;
  end;
  TWindowEvent = record
    Kind, Timestamp, WindowID: LongWord;
    Event, Pad1, Pad2, Pad3: Byte;
    Data1, Data2: LongInt;
  end;
  TMouseEvent = record
    Kind, Timestamp, WindowID, Which: LongWord;
    Button, State, Clicks, Padding: Byte;
    X, Y: LongInt;
  end;
  TEvent = record
    case Integer of
      0: (Kind: LongWord);
      1: (Key: TKeyEvent);
      2: (Window: TWindowEvent);
      3: (Mouse: TMouseEvent);
      4: (Padding: array[0..55] of Byte);
  end;
  TAudioSpec = record
    Frequency: LongInt;
    Format: Word;
    Channels, Silence: Byte;
    Samples, Padding: Word;
    Size: LongWord;
    Callback, UserData: Pointer;
  end;

const
  EventQuit = $100;
  EventWindow = $200;
  EventKeyDown = $300;
  EventMouseDown = $401;
  WindowFocusLost = 13;
  KeyRight = 1073741903;
  KeyLeft = 1073741904;
  KeyDown = 1073741905;
  KeyUp = 1073741906;
  KeyF11 = 1073741892;

var
  SDL_Init: function(Flags: LongWord): LongInt; cdecl;
  SDL_InitSubSystem: function(Flags: LongWord): LongInt; cdecl;
  SDL_Quit: procedure; cdecl;
  SDL_GetError: function: PChar; cdecl;
  SDL_SetHint: function(Name, Value: PChar): LongInt; cdecl;
  SDL_CreateWindow: function(Title: PChar; X, Y, W, H: LongInt; Flags: LongWord): Pointer; cdecl;
  SDL_DestroyWindow: procedure(Window: Pointer); cdecl;
  SDL_SetWindowMinimumSize: procedure(Window: Pointer; W, H: LongInt); cdecl;
  SDL_SetWindowFullscreen: function(Window: Pointer; Flags: LongWord): LongInt; cdecl;
  SDL_CreateRenderer: function(Window: Pointer; Index: LongInt; Flags: LongWord): Pointer; cdecl;
  SDL_DestroyRenderer: procedure(Renderer: Pointer); cdecl;
  SDL_GetRendererOutputSize: function(Renderer: Pointer; W, H: PLongInt): LongInt; cdecl;
  SDL_RenderSetLogicalSize: function(Renderer: Pointer; W, H: LongInt): LongInt; cdecl;
  SDL_SetRenderDrawBlendMode: function(Renderer: Pointer; Mode: LongInt): LongInt; cdecl;
  SDL_SetRenderDrawColor: function(Renderer: Pointer; R, G, B, A: Byte): LongInt; cdecl;
  SDL_RenderClear: function(Renderer: Pointer): LongInt; cdecl;
  SDL_RenderFillRect: function(Renderer: Pointer; Rect: Pointer): LongInt; cdecl;
  SDL_RenderDrawLine: function(Renderer: Pointer; X1, Y1, X2, Y2: LongInt): LongInt; cdecl;
  SDL_RenderGeometry: function(Renderer, Texture, Vertices: Pointer;
    NumVertices: LongInt; Indices: Pointer; NumIndices: LongInt): LongInt; cdecl;
  SDL_RenderSetClipRect: function(Renderer, Rect: Pointer): LongInt; cdecl;
  SDL_RenderPresent: procedure(Renderer: Pointer); cdecl;
  SDL_PollEvent: function(Event: Pointer): LongInt; cdecl;
  SDL_PushEvent: function(Event: Pointer): LongInt; cdecl;
  SDL_GetMouseState: function(X, Y: PLongInt): LongWord; cdecl;
  SDL_SetClipboardText: function(Text: PChar): LongInt; cdecl;
  SDL_GetClipboardText: function: PChar; cdecl;
  SDL_free: procedure(Memory: Pointer); cdecl;
  SDL_RenderWindowToLogical: procedure(Renderer: Pointer; X, Y: LongInt; LX, LY: PSingle); cdecl;
  SDL_Delay: procedure(MS: LongWord); cdecl;
  SDL_GetTicks64: function: QWord; cdecl;
  SDL_CreateTextureFromSurface: function(Renderer, Surface: Pointer): Pointer; cdecl;
  SDL_FreeSurface: procedure(Surface: Pointer); cdecl;
  SDL_QueryTexture: function(Texture, Format, Access, W, H: Pointer): LongInt; cdecl;
  SDL_SetTextureColorMod: function(Texture: Pointer; R, G, B: Byte): LongInt; cdecl;
  SDL_SetTextureAlphaMod: function(Texture: Pointer; Alpha: Byte): LongInt; cdecl;
  SDL_DestroyTexture: procedure(Texture: Pointer); cdecl;
  SDL_RenderCopy: function(Renderer, Texture, Src, Dest: Pointer): LongInt; cdecl;
  SDL_RenderReadPixels: function(Renderer, Rect: Pointer; Format: LongWord; Pixels: Pointer; Pitch: LongInt): LongInt; cdecl;
  SDL_CreateRGBSurfaceFrom: function(Pixels: Pointer; W,H,Depth,Pitch: LongInt;
    RMask,GMask,BMask,AMask: LongWord): Pointer; cdecl;
  SDL_RWFromFile: function(FileName, Mode: PChar): Pointer; cdecl;
  SDL_SaveBMP_RW: function(Surface, RW: Pointer; FreeRW: LongInt): LongInt; cdecl;
  SDL_OpenAudioDevice: function(Device: PChar; Capture: LongInt;
    Desired, Obtained: Pointer; AllowedChanges: LongInt): LongWord; cdecl;
  SDL_CloseAudioDevice: procedure(Device: LongWord); cdecl;
  SDL_PauseAudioDevice: procedure(Device: LongWord; Paused: LongInt); cdecl;
  SDL_QueueAudio: function(Device: LongWord; Data: Pointer; Length: LongWord): LongInt; cdecl;
  SDL_ClearQueuedAudio: procedure(Device: LongWord); cdecl;
  SDL_GetQueuedAudioSize: function(Device: LongWord): LongWord; cdecl;
  TTF_Init: function: LongInt; cdecl;
  TTF_Quit: procedure; cdecl;
  TTF_OpenFont: function(FileName: PChar; Size: LongInt): Pointer; cdecl;
  TTF_CloseFont: procedure(Font: Pointer); cdecl;
  TTF_RenderUTF8_Blended: function(Font: Pointer; Text: PChar; Color: TColor): Pointer; cdecl;

procedure LoadSDL;
procedure UnloadSDL;

implementation

uses SysUtils;

var SDLHandle, TTFHandle: TLibHandle;

function OpenLibrary(const Candidates: array of String): TLibHandle;
var Name: String;
begin
  for Name in Candidates do
  begin
    Result := LoadLibrary(Name);
    if Result <> NilHandle then Exit;
  end;
  raise Exception.Create('Missing SDL library. Install SDL2 and SDL2_ttf; see README.md.');
end;

procedure Bind(Handle: TLibHandle; var Proc; const Name: String);
begin
  Pointer(Proc) := GetProcedureAddress(Handle, PChar(Name));
  if Pointer(Proc) = nil then
    raise Exception.Create('SDL2 2.0.18 or newer required: missing ' + Name);
end;

procedure VerifySize(Actual, Expected: Integer);
begin
  if Actual <> Expected then
    raise Exception.Create('Unsupported SDL ABI layout.');
end;

procedure LoadSDL;
begin
  VerifySize(SizeOf(TEvent), 56);
  VerifySize(SizeOf(TKeyEvent), 32);
  VerifySize(SizeOf(TMouseEvent), 28);
  VerifySize(SizeOf(TVertex), 20);
  VerifySize(SizeOf(TAudioSpec), 16 + 2 * SizeOf(Pointer));
  {$ifdef darwin}
  SDLHandle := OpenLibrary(['/opt/homebrew/opt/sdl2-compat/lib/libSDL2.dylib',
    '/opt/homebrew/opt/sdl2/lib/libSDL2.dylib', '/usr/local/lib/libSDL2.dylib', 'libSDL2.dylib']);
  TTFHandle := OpenLibrary(['/opt/homebrew/opt/sdl2_ttf/lib/libSDL2_ttf.dylib',
    '/usr/local/lib/libSDL2_ttf.dylib', 'libSDL2_ttf.dylib']);
  {$else}
  SDLHandle := OpenLibrary(['libSDL2-2.0.so.0']);
  TTFHandle := OpenLibrary(['libSDL2_ttf-2.0.so.0']);
  {$endif}
  Bind(SDLHandle, SDL_Init, 'SDL_Init');
  Bind(SDLHandle, SDL_InitSubSystem, 'SDL_InitSubSystem');
  Bind(SDLHandle, SDL_Quit, 'SDL_Quit');
  Bind(SDLHandle, SDL_GetError, 'SDL_GetError');
  Bind(SDLHandle, SDL_SetHint, 'SDL_SetHint');
  Bind(SDLHandle, SDL_CreateWindow, 'SDL_CreateWindow');
  Bind(SDLHandle, SDL_DestroyWindow, 'SDL_DestroyWindow');
  Bind(SDLHandle, SDL_SetWindowMinimumSize, 'SDL_SetWindowMinimumSize');
  Bind(SDLHandle, SDL_SetWindowFullscreen, 'SDL_SetWindowFullscreen');
  Bind(SDLHandle, SDL_CreateRenderer, 'SDL_CreateRenderer');
  Bind(SDLHandle, SDL_DestroyRenderer, 'SDL_DestroyRenderer');
  Bind(SDLHandle, SDL_GetRendererOutputSize, 'SDL_GetRendererOutputSize');
  Bind(SDLHandle, SDL_RenderSetLogicalSize, 'SDL_RenderSetLogicalSize');
  Bind(SDLHandle, SDL_SetRenderDrawBlendMode, 'SDL_SetRenderDrawBlendMode');
  Bind(SDLHandle, SDL_SetRenderDrawColor, 'SDL_SetRenderDrawColor');
  Bind(SDLHandle, SDL_RenderClear, 'SDL_RenderClear');
  Bind(SDLHandle, SDL_RenderFillRect, 'SDL_RenderFillRect');
  Bind(SDLHandle, SDL_RenderDrawLine, 'SDL_RenderDrawLine');
  Bind(SDLHandle, SDL_RenderGeometry, 'SDL_RenderGeometry');
  Bind(SDLHandle, SDL_RenderSetClipRect, 'SDL_RenderSetClipRect');
  Bind(SDLHandle, SDL_RenderPresent, 'SDL_RenderPresent');
  Bind(SDLHandle, SDL_PollEvent, 'SDL_PollEvent');
  Bind(SDLHandle, SDL_PushEvent, 'SDL_PushEvent');
  Bind(SDLHandle, SDL_GetMouseState, 'SDL_GetMouseState');
  Bind(SDLHandle, SDL_SetClipboardText, 'SDL_SetClipboardText');
  Bind(SDLHandle, SDL_GetClipboardText, 'SDL_GetClipboardText');
  Bind(SDLHandle, SDL_free, 'SDL_free');
  Bind(SDLHandle, SDL_RenderWindowToLogical, 'SDL_RenderWindowToLogical');
  Bind(SDLHandle, SDL_Delay, 'SDL_Delay');
  Bind(SDLHandle, SDL_GetTicks64, 'SDL_GetTicks64');
  Bind(SDLHandle, SDL_CreateTextureFromSurface, 'SDL_CreateTextureFromSurface');
  Bind(SDLHandle, SDL_FreeSurface, 'SDL_FreeSurface');
  Bind(SDLHandle, SDL_QueryTexture, 'SDL_QueryTexture');
  Bind(SDLHandle, SDL_SetTextureColorMod, 'SDL_SetTextureColorMod');
  Bind(SDLHandle, SDL_SetTextureAlphaMod, 'SDL_SetTextureAlphaMod');
  Bind(SDLHandle, SDL_DestroyTexture, 'SDL_DestroyTexture');
  Bind(SDLHandle, SDL_RenderCopy, 'SDL_RenderCopy');
  Bind(SDLHandle, SDL_RenderReadPixels, 'SDL_RenderReadPixels');
  Bind(SDLHandle, SDL_CreateRGBSurfaceFrom, 'SDL_CreateRGBSurfaceFrom');
  Bind(SDLHandle, SDL_RWFromFile, 'SDL_RWFromFile');
  Bind(SDLHandle, SDL_SaveBMP_RW, 'SDL_SaveBMP_RW');
  Bind(SDLHandle, SDL_OpenAudioDevice, 'SDL_OpenAudioDevice');
  Bind(SDLHandle, SDL_CloseAudioDevice, 'SDL_CloseAudioDevice');
  Bind(SDLHandle, SDL_PauseAudioDevice, 'SDL_PauseAudioDevice');
  Bind(SDLHandle, SDL_QueueAudio, 'SDL_QueueAudio');
  Bind(SDLHandle, SDL_ClearQueuedAudio, 'SDL_ClearQueuedAudio');
  Bind(SDLHandle, SDL_GetQueuedAudioSize, 'SDL_GetQueuedAudioSize');
  Bind(TTFHandle, TTF_Init, 'TTF_Init');
  Bind(TTFHandle, TTF_Quit, 'TTF_Quit');
  Bind(TTFHandle, TTF_OpenFont, 'TTF_OpenFont');
  Bind(TTFHandle, TTF_CloseFont, 'TTF_CloseFont');
  Bind(TTFHandle, TTF_RenderUTF8_Blended, 'TTF_RenderUTF8_Blended');
end;

procedure UnloadSDL;
begin
  if TTFHandle <> NilHandle then UnloadLibrary(TTFHandle);
  if SDLHandle <> NilHandle then UnloadLibrary(SDLHandle);
  TTFHandle := NilHandle;
  SDLHandle := NilHandle;
end;

end.
