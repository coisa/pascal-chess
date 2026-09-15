# Validation evidence

Executed locally on September 15, 2026. Runtime implementation initially
committed as `b6677f38d9852baaf5663e0ceb32652378b0562b`; subsequent review adds
journal edge-case corrections and expands the perft suite. The final PR checks
are authoritative for its exact revision.

## Executed environments

| Environment | Components | Evidence |
|---|---|---|
| Linux ARM64 container | Docker/OrbStack 29.4.0, FPC 3.2.2+dfsg-20, SDL2 2.26.5, SDL2_ttf 2.20.1, DejaVu Sans | Full build, rule/search tests, CLI/SDL checks and runtime image |
| Native macOS ARM64 | macOS 27.0, FPC 3.2.2_1, SDL2-compat 2.32.72, SDL2_ttf 2.24.0, Arial | Native compilation, rule/search and integration tests; actual renderer capture |
| GitHub CI | Ubuntu 24.04 AMD64 and ARM64 | Configured; inspect the final PR run for completion |

Native tools reuse the official checksum-verified Homebrew bottles extracted
into ignored scratch for Pascal Snake. The temporary SDL2_ttf library was
relocated to existing Homebrew dependencies and ad-hoc signed. No global
compiler install or unrelated upgrade was required. FPC's older Apple linker
switches produce deprecation warnings; compilation and execution succeed.

## Rule and search coverage

`make test` runs **918 assertions**, including a deterministic 200-ply legal
walk with king-safety/FEN roundtrips. Assertions and enumerated move-tree leaves
are different measurements. The perft suite compares these reference counts:

| Position | Depth | Leaf nodes |
|---|---:|---:|
| Initial | 1–5 | 20; 400; 8,902; 197,281; 4,865,609 |
| Kiwipete | 1–3 | 48; 2,039; 97,862 |
| Rook/pawn ending (position 3) | 4 | 43,238 |
| Castling/promotion stress (position 4) | 3 | 9,467 |
| Promotion/check stress (position 5) | 3 | 62,379 |
| Tactical middlegame (position 6) | 3 | 89,890 |

Fixtures and expected results come from [Perft Results](https://www.chessprogramming.org/Perft_Results),
also used at greater depths by [Stockfish's own perft test script](https://github.com/official-stockfish/Stockfish/blob/master/tests/perft.sh).
The implementation does not use Stockfish at runtime.

Targeted tests cover castling pieces/rights and attacked transit squares,
vertical and horizontal en-passant pins, actual en-passant removal, all four
promotions, checkmate/stalemate, mate precedence at move 75, draw claims,
automatic repetition, irrelevant en-passant repetition keys, material endings,
SAN/PGN, complete undo, invalid FEN and finished-game move rejection. Search
tests cover legal/deterministic choices, one-node fallback, node limits,
cooperative cancellation and finding mate in one.

## Executables and rendering

```sh
make test image smoke preview
docker compose config --quiet
git diff --check
```

The Python standard-library smoke harness tests strict CLI failures, perft,
search, interactive moves/undo/hints, clean EOF, PGN export and unwritable
destinations. It runs the real SDL event path repeatedly: keyboard/pointer
selection, legal moves, animation, promotion choices, hints, the computer turn,
undo, new-game confirmation, focus pause/resume, mute and reduced motion.

Five actual BMP frames (start, play, paused, promotion, mate) have their headers,
dimensions, pixel diversity and distinct hashes checked. Missing fonts, bad
video/audio drivers and unwritable captures exercise cleanup and fallback.
Linux and native macOS gameplay captures were visually inspected separately.
Clipboard tests run only on SDL's dummy driver, preserving the host clipboard.

The packaged CLI executes perft and search as UID 65532 with no network, a
read-only root and dropped capabilities. The game does not require Docker
socket or personal-directory mounts.

## Findings addressed during implementation

- Native FPC without a global config rejected C-style `+=` assignments accepted
  by Debian's compiler configuration. Standard Pascal assignments now compile
  under both environments.
- Geometry intersection storage is explicitly initialized, keeping Linux
  compilation free of source warnings.
- Independent review caught a journal window that omitted the newest odd ply
  after twelve moves. Rows now follow actual move numbers and side-to-move,
  with regressions for thirteen plies and black-first imported positions.
- Self-test assertions now respect initial mute/reduced-motion options; all
  supported combinations are exercised instead of reporting false failures.
- The native SDL boundary preserves the floating-point mask and captures the
  renderer's physical dimensions, retaining the fixes proven in Pascal Snake.

## Limits of this evidence

Linux graphics use SDL's dummy/software renderer, not a physical Linux desktop.
Native macOS includes real graphics initialization and rendering, but not a
wide display/input matrix or independent subjective audio listening. Windows,
screen-reader accessibility, general dead-position proofs and tournament rules
are not validated. A legal-move suite does not establish engine playing strength
or a security certification. No external agentic security scan was run.

Use the actual PR checks and review findings to verify readiness; configuration
alone is not evidence that a remote job passed. Wiki publication is a separate
workflow and does not become validated merely because the game tests pass.
