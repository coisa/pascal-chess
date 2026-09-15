# AGENTS.md

## Purpose

Modernize the original university chess exercise into an approachable native
desktop game. Application logic, chess rules, search and rule tests stay Pascal.

## Ownership

The owner authorized modernization, English translation, unarchiving, an issue
and PR, a 0.1.0 baseline release, merge and a 1.0.0 release. Wiki synchronization
belongs in a separate PR. No license or external service credentials are implied.

## Local Contracts

- Keep `chess.pas` as the desktop entry point and share pure rules with the CLI.
- Write UI, source identifiers, comments and documentation in English.
- Use SDL2 for platform services; keep rules and AI independent of SDL and time.
- Gameplay is offline. Write files only to an explicit CLI export path.
- Git preserves the original; do not keep duplicate legacy source trees.
- `build/` and `tmp/` are ignored project-local outputs.

## Work Guidance

Read the child contract for the target path before editing. Keep the plan,
changelog, build instructions and evidence consistent with executed behavior.
Run commands through RTK when available. Do not invent performance or Elo claims.

## Verification

Run the deterministic rules/search suite, perft positions, CLI/SDL integration
checks and `git diff --check`. Inspect real rendered frames. Confirm remote
checks and review findings at the final commit before merging.

## Child DOX Index

- [src/AGENTS.md](src/AGENTS.md): pure rules/search and graphical platform boundary.
- [tests/AGENTS.md](tests/AGENTS.md): synthetic rule and executable integration proof.
- [docs/AGENTS.md](docs/AGENTS.md): provenance, architecture, challenge and evidence.
- [plans/AGENTS.md](plans/AGENTS.md): canonical modernization recipe.
- [.github/AGENTS.md](.github/AGENTS.md): bounded, read-only CI validation.
