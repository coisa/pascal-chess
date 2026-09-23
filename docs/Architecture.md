# Architecture

## Pascal owns the game

`chess.pas` launches `chess_desktop`; `ChessCLI.pas` exposes a text game and
analysis commands. Both call `chess_engine` and `chess_search`. `chess_sdl` is
a small dynamic adapter for SDL2/SDL2_ttf's public C ABI, adapted from the same
owner's [Pascal Snake](https://github.com/coisa/pascal-snake) implementation.
No Stockfish binary, browser engine, Python chess rules or remote model plays
the opponent. Python only drives integration tests.

## Positions and legal moves

A position stores 64 signed pieces, side to move, castling rights, en-passant
target and move counters. Square zero is a1; positive pieces are White. Move
generation applies a candidate to a fresh position and rejects it when its
king remains attacked. The king is never a capturable piece. Castling checks
the original, transit and destination squares; en passant removes the captured
pawn before checking king safety. Promotions enumerate all four choices.

FEN loading validates the board structure, kings, counters, castling pieces,
en-passant geometry and the previous player's king. It does not establish full
historical reachability. `ApplyMove` is an internal primitive for generated
moves; interface inputs go through `FindMove` or `PlayMove`.

A game stores positions, moves and SAN up to 2,048 plies. Undo restores the
previous position, including castling, en-passant and counters. Repetition
ignores an en-passant target when no legal en-passant capture exists. Checkmate
takes precedence over the automatic 75-move result.

The draw policy follows the distinction between claimable repetition/50-move
draws and automatic fivefold/75-move draws in the [FIDE Laws of Chess](https://handbook.fide.com/chapter/e012023).
The interface claims only an already-reached position. Insufficient material
recognizes bare kings, a single minor against a king, and bishops-only endings
where every bishop is on the same square color. General dead-position proofs,
intended-move claims and tournament procedures are outside scope.

## Computer opponent

Search uses iterative-deepening negamax with alpha-beta pruning. Captures and
promotions are ordered first; the previous completed principal move is searched
first at the next depth. Quiescence extends tactical exchanges and check
evasions. Evaluation combines material, piece activity, pawn advancement,
bishop pairs and simple king shelter. There is no opening book, transposition
table or tablebase. This keeps the implementation inspectable and its strength
claims modest.

Node budgets stop incomplete iterations; the last completed move survives,
with a legal fallback even at one node. Recursion is bounded to 64 plies and
the desktop search to seven iterations. A callback every 256 nodes pumps SDL
events and renders progress. Cancellation, new-game requests and focus loss
discard stale results. Search estimates repetitions within its current path;
the game layer adjudicates actual history and claims an available draw for the
computer. Search scores are heuristics, not calibrated win probabilities.

## Presentation and resource ownership

The 1280 by 900 logical canvas scales into a resizable, high-DPI window. Pascal
draws Staunton silhouettes, board highlights, cards and controls. Drawn pieces
avoid dependence on chess or emoji glyph availability. Movement uses a 220 ms
smooth interpolation; reduced motion skips it. The journal shows recent SAN,
and the material indicator reports piece-value balance rather than an invented
engine rating.

SDL provides graphics/input/audio, with SDL2_ttf and a bounded 128-entry text
texture cache. Sound is a short synthesized waveform; missing audio is
nonfatal. The graphics boundary saves and masks Free Pascal's floating-point
traps for C libraries, restoring the original mask during cleanup. Cleanup
also handles partial initialization. Screenshots allocate physical renderer
dimensions, which may exceed logical size on Retina displays.

Gameplay has no network and creates no automatic player files. Only explicit
snapshot/PGN paths write files. Copy commands write the clipboard on demand;
tests exercise clipboard behavior only through SDL's isolated dummy driver.

## Build and maintenance

The Dockerfile pins a Debian multi-architecture digest and signed APT snapshot,
including Free Pascal 3.2.2. The runtime image carries only the text executable,
runs as UID 65532 and is exercised without network or writable root filesystem.
CI uses standard AMD64 and ARM64 runners with read-only permissions. Dependabot
tracks Docker and GitHub Actions weekly; snapshot and native-library updates
still require review. The Wiki publishing workflow is delivered separately.
