# Publishing docs to the Wiki

[Sync Documentation to GitHub Wiki](https://github.com/coisa/pascal-chess/actions/workflows/wiki-sync.yml)
runs when `docs/` or the workflow changes on the default branch (`master`
today; the trigger also accepts `main`). It can also be dispatched manually
on that branch.

The workflow uses the built-in `GITHUB_TOKEN` with `contents: write`.
It clones the Wiki, mirrors `docs/` with rsync, and commits and pushes only
when files changed. No separate token or dependency installation is configured.

Enable the Wiki and [create its first page](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages#cloning-wikis-to-your-computer)
before the first run. If cloning or pushing fails, inspect the Actions log.

Edit `docs/` rather than the Wiki: synchronization replaces Wiki content and
removes files absent from `docs/`, while preserving its Git history.
`Home.md` supplies the landing page. Files and links are copied as written;
use absolute GitHub URLs for links that must work in both the repository and Wiki.

After merging, check the Actions result and published pages to confirm that
the token can push in this repository. Local checks do not prove publication.
To undo a documentation change, revert it in the source and synchronize again.

Dependabot opens weekly update PRs for GitHub Actions and Docker.
