# Changelog

## [1.0.0] - 2026-09-15

### Added

- Pure Pascal legal chess, castling, en passant, promotion, king safety,
  checkmate/stalemate and documented draw rules.
- Bounded Pascal computer search, three workloads, hints and either-color play.
- Native SDL2 interface with procedural pieces, animations, legal targets,
  journal, material balance, keyboard/mouse controls and synthesized audio.
- Undo, new-game confirmation, board flip, focus pause, fullscreen, mute and
  reduced motion; FEN/PGN clipboard export and terminal analysis commands.
- Reference perft, rule/search and executable integration tests; pinned Docker
  builds, non-root offline runtime, AMD64/ARM64 CI and weekly Dependabot.
- English documentation covering the university origin and reusable AI challenge.

### Changed

- Replace unrestricted CRT piece copying with a shared chess engine and separate
  graphical/text entry points. Preserve the original through Git and 0.1.0.
- Use English for all authored identifiers, UI, comments and documentation.

## [0.1.0] - 2026-09-15

- Preserve the original university exercise at `bec5c0cedae44637e2086ba9d6d52eb42a64b945`.

[1.0.0]: https://github.com/coisa/pascal-chess/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/coisa/pascal-chess/releases/tag/v0.1.0
