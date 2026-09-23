# Documentation publication

Tracks [issue #4](https://github.com/coisa/pascal-chess/issues/4).

1. Use one workflow to copy `docs/` into the initialized GitHub Wiki after
   documentation changes reach the default branch, or on manual dispatch.
2. Authenticate with the built-in `GITHUB_TOKEN` and `contents: write`.
   Clone the Wiki, mirror files with rsync, and commit/push only changes.
3. Keep `Home.md` and links in the source documentation. No Markdown renderer,
   Python dependencies or separate preview pipeline are needed.
4. Keep weekly Dependabot updates for Actions and Docker.
5. Validate the workflow and exercise copy, deletion and no-op behavior against
   a disposable local Git remote. Confirm actual publication from an Actions run.

The Wiki is a generated mirror: edit `docs/`, including its home page.
Rollback uses a source revert and another sync. Keep the existing PR open for
review; local validation does not establish that a remote Wiki push succeeded.
