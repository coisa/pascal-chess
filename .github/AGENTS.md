# AGENTS.md

## Purpose

Validate the game and synchronize documentation to the GitHub Wiki.

## Ownership

The root contract owns merge and publication. The owner authorized the
docs-to-Wiki workflow; publication runs only from the default branch.

## Local Contracts

Write in English. Pin external actions by SHA and bound job time.
Game tests use read-only permissions. Wiki synchronization uses the built-in
`GITHUB_TOKEN` with `contents: write`; pull requests do not publish.

## Work Guidance

Use the game Makefile targets locally and in CI. Keep Wiki synchronization
in one workflow: clone, mirror `docs/`, commit changes and push.

## Verification

Check workflow syntax and actual Actions results before claiming publication.

## Child DOX Index

- `workflows/ci.yml`: Linux AMD64/ARM64 game validation.
- `workflows/wiki-sync.yml`: default-branch documentation mirror.
- `dependabot.yml`: weekly Actions and Docker update PRs; no automatic merge.
