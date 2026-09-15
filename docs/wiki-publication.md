# Publishing docs to the Wiki

The Documentation Wiki workflow validates documentation on PRs, then publishes
`docs/` after changes reach the repository's default branch (`master` today;
the trigger also accepts `main`). Manual dispatch on the default branch can
reconcile it again. PR runs have no Wiki credential and never publish.

The Wiki is generated: edit `docs/` and submit a PR instead of editing its
managed pages. Markdown links between docs become Wiki links; assets are
copied beneath `assets/`; links to source files point to the exact source SHA.
Targets outside `docs/` must exist in the source commit, not just in the working
tree. Root-relative GitHub links are preserved. All PRs run validation so deleting
or renaming a linked repository file is checked before merge.
Home and the sidebar are generated indexes. The initial Home bootstrap may be
replaced; an existing unmanaged sidebar must be migrated explicitly. The manifest removes only stale
previously managed files and leaves unrelated Wiki pages intact. Name clashes
with existing unmanaged pages fail rather than silently overwrite them.

## One-time setup

1. Enable the repository Wiki and create its initial Home page on GitHub.
   GitHub requires [an initial page before cloning the Wiki](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages).
2. Configure the repository Actions secret `WIKI_TOKEN` with a dedicated
   credential permitted to push this repository's Wiki. Do not paste the token
   into a PR, source file, command argument or chat. Set it through GitHub's
   secret UI or `gh secret set WIKI_TOKEN` using protected stdin.
3. Merge the automation PR or dispatch Documentation Wiki on the default branch.
   Verify both the run result and the Wiki's Home source-commit link.

The ordinary Actions token is not assumed to write the separate Wiki Git
repository. Existing [Wiki publisher guidance](https://github.com/marketplace/actions/publish-to-github-wiki)
requires a separate access token and initialized Wiki. Use the narrowest token
accepted by your GitHub account; public repositories may use a dedicated
classic token with `public_repo`, while access policy can require a different
credential. Credential creation/permissions remain an explicit owner setup.
No interactive developer token is copied into Actions automatically.

## Execution and failure handling

The default-branch job checks out the latest source, serializes publications,
renders into a clean Wiki clone, and makes a normal commit/push only when files
changed. Tokens are supplied by a temporary askpass helper, never in the remote
URL or logs. Missing setup fails with a specific message. A missing secret or
failed job is not a successful deployment.

Preview and tests require Git, Python 3.9+ with `venv`, and no credentials. The first
run downloads the hash-pinned Markdown parser into `build/wiki-venv`; subsequent
runs reuse it until the requirements change. The renderer itself is offline:

```sh
make wiki-check
```

To roll back published content, revert the source documentation and merge the
correction so CI republishes it. To stop publication, disable the workflow or
remove its trigger through a reviewed change. Wiki history preserves earlier
commits; do not force-push or delete the Wiki as a routine repair.

Dependabot independently opens weekly update PRs for GitHub Actions, Docker
and the Python Markdown parser.
It does not merge or update the pinned APT snapshot automatically.
