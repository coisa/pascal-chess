# AGENTS.md

## Purpose

Validate pull requests and master with reproducible Linux builds; publish docs
to the initialized Wiki from the default branch.

## Ownership

The root contract owns merge and publication. Tests do not need secrets.

## Local Contracts

Pin external actions by SHA. Use read-only permissions, standard runners and
bounded jobs. Wiki publication uses a dedicated secret only on default-branch
runs. Pull requests test and render documentation without credentials.

## Work Guidance

Use the same Makefile targets locally and in CI.
Run Wiki validation on every PR: documentation can reference any repository
file, and those targets must exist in the source commit.

## Verification

Inspect actual check results at the final PR commit.

## Child DOX Index

- `workflows/ci.yml`: shared Linux AMD64/ARM64 validation.
- `dependabot.yml`: weekly Actions, Docker and Python update PRs; no automatic merge.
- `requirements.txt`: hash-pinned Markdown parser installed in `build/wiki-venv`.
- `workflows/wiki.yml`: PR rendering and default-branch Wiki publication.
- [wiki_sync.md](wiki_sync.md): renderer inputs, outputs, boundaries and checks.
- `test_wiki_sync.py`: isolated rendering and managed-file boundary tests.
