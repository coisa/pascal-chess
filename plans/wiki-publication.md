# Documentation publication

Tracks [issue #4](https://github.com/coisa/pascal-chess/issues/4).

1. Render the canonical `docs/` Markdown and assets into an isolated Wiki tree.
   Rewrite links, record the source SHA and manage only manifest-owned files.
2. Validate on pull requests without credentials. Publish after a merge into
   the default branch, checking out its latest source and using a dedicated
   `WIKI_TOKEN`. Initialize the Wiki once before the first publication.
3. Preserve the existing Dependabot configuration from the 1.0.0 release.
4. Test idempotence, links, assets, stale managed files, collisions and unsafe
   paths; inspect the actual GitHub run before claiming publication succeeded.

The renderer and workflow are independent of gameplay. Existing 1.0.0 release
history remains unchanged. Roll back through a source revert and a new sync;
disable the workflow to stop publication. Never force-push the Wiki or export
a developer's interactive token into CI.

Acceptance requires passing PR checks and independent review. Deployment also
requires the configured secret, an initialized Wiki and a successful default-
branch run whose source link matches the published documentation.
