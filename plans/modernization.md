# Pascal Chess modernization

## Outcome and authority

The owner asked for the same ambitious modernization and delivery flow as
Pascal Snake: retain Pascal, translate everything to English, explain the
university origin and simple-prompt experiment, provide a reusable challenge,
create an issue/PR, preserve 0.1.0, merge and publish 1.0.0. Wiki CI follows in
a separate PR. No external chess engine, account or network play is required.

## Instruction map

Original scope: one `chess.pas`, no repository instructions or documentation.
Create a root contract for authority, language, offline behavior and validation.
Create `src/` for pure rule/search and SDL resource boundaries, `tests/` for
disposable synthetic fixtures, `docs/` for evidence/provenance, `plans/` for
the recipe and `.github/` for CI permissions. Each parent indexes only its
direct durable children. Read root then the applicable child before editing.
Generated `build/` and `tmp/` need no contracts. Rollback restores these
contracts and consumers together through Git.

## Implementation sequence

1. Tag the unchanged original master as v0.1.0 and publish its limitations.
2. Implement legal move generation with king safety, castling, en passant and
   all promotions. Add FEN import/export, SAN, history/undo and PGN export.
3. Handle checkmate/stalemate, common insufficient-material positions, draw
   claims at threefold/50 moves and automatic fivefold/75-move draws. Document
   the scope of dead-position adjudication and omitted tournament procedures.
4. Add deterministic iterative-deepening alpha-beta search in Pascal, with
   quiescence, move ordering, material/positional evaluation and node budgets.
   Keep the interface responsive while the opponent thinks; no Elo claims.
5. Build a native SDL2 board with procedural Staunton pieces, transitions,
   move animation, legal targets, check/last-move highlights and synthesized
   sound. Include human/computer modes, either color, hints, undo, board flip,
   promotion choice, keyboard navigation, mute and reduced motion.
6. Add a plain-text terminal/analysis executable sharing the engine, a pinned
   Docker toolchain and Linux AMD64/ARM64 CI. Reuse the already validated
   minimal SDL platform adapter from the same owner's Pascal Snake.
7. Verify reference perft positions, special-move regressions, search budgets,
   notation roundtrips, undo, CLI errors and real SDL event replay. Inspect
   renderer output on Linux and native macOS separately.
8. Write English README, architecture, baseline, challenge and validation.
   Review final code/diff, resolve findings, push a PR linked to the issue,
   verify checks, merge and tag the resulting master as v1.0.0.

## Acceptance and limits

| Requirement | Evidence |
|---|---|
| Pascal foundation | Pascal application, engine, AI and tests compile |
| Legal chess | Reference perft and targeted special-move/check/draw assertions |
| Usable opponent | Deterministic legal choice, bounded search, tactical fixtures |
| Functional desktop | Event replay, repeated lifecycle and failure paths |
| Visual quality | Actual rendered board and interface inspected |
| Accessibility controls | Keyboard, flip, reduced motion and mute checks |
| Provenance and reproducibility | English docs, pinned build, baseline and release tags |

FIDE's basic rules guide move legality; this is a casual offline game, without
an arbiter, clocks or tournament touch-move procedures. Performance depends
on hardware; node budgets provide deterministic workload ceilings. Preserve
the original only in Git. Revert the modernization as a set for rollback.
