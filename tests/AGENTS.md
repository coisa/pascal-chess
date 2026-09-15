# AGENTS.md

## Purpose

Prove chess behavior with reference positions and synthetic executable tests.

## Ownership

The root contract governs delivery. Tests own fixtures and assertions.

## Local Contracts

Use Pascal for rules and AI tests. Python standard library may drive executable
integration. Never use real player files or personal directories as fixtures.
Bound processes and verify failures as well as success paths. State the exact
coverage; repeated assertions are not independent scenarios.

## Work Guidance

Include perft, king safety, castling, en passant, promotion, draw rules,
notation, undo and search-budget regressions. Use temporary directories for
exports and actual renderer captures for visual assertions.

## Verification

`make test` is the container reference. Native validation is separate evidence.

## Child DOX Index

No child instruction boundaries.
