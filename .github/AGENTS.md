# AGENTS.md

## Purpose

Validate pull requests and master with reproducible Linux builds.

## Ownership

The root contract owns merge and publication. Tests do not need secrets.

## Local Contracts

Pin external actions by SHA. Use read-only permissions, standard runners and
bounded jobs. Wiki publication will be introduced in its own reviewed PR.

## Work Guidance

Use the same Makefile targets locally and in CI.

## Verification

Inspect actual check results at the final PR commit.

## Child DOX Index

No child instruction boundaries.
