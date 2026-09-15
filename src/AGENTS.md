# AGENTS.md

## Purpose

Implement standard chess, bounded Pascal search and native presentation.

## Ownership

The root contract governs scope and language. This subtree owns runtime code.

## Local Contracts

Rules use values and explicit position state, with no I/O, SDL, clocks or global
mutable game state. UI and CLI must use legal-move generation rather than apply
untrusted coordinates directly. Search must stop within its node budget. SDL
resources and floating-point state must be restored on every exit path.

## Work Guidance

Keep special moves and draw handling in the engine. Keep rendering, audio and
input in the desktop layer. Expose deterministic hooks for integration tests.

## Verification

Run engine tests after rule/search changes and SDL smoke after UI changes.

## Child DOX Index

No child instruction boundaries.
