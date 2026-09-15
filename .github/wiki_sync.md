# Documentation renderer

`wiki_sync.py` turns the repository's `docs/` Markdown and supported assets
into files for a GitHub Wiki. It needs Python 3.9+, the source repository,
an output directory, `owner/repository` and a full source commit SHA.

```sh
make wiki-check
```

The Makefile creates `build/wiki-venv` and installs the hash-pinned
[Marko parser](https://github.com/frostming/marko) from `requirements.txt`.
Only this dependency setup needs network access. Dependabot proposes updates;
the parser's destination-offset contract is covered by the rendering tests.
The small reference-definition adapter also masks container prefixes when
matching continued destinations, retaining the original character offsets.

The renderer writes the chosen output, an index/sidebar and a managed-file
manifest. It parses CommonMark and replaces only local link destinations at
their original source offsets. Nested labels, linked images and multiline
reference definitions work; fenced/indented examples, multiline code spans
and all other source formatting stay literal. Repository directories use
tree URLs; repository images outside `docs/` use revision-pinned raw URLs.
Navigation labels escape heading markup so each entry links to its Wiki page.
Only the initial Home page is an allowed
unmanaged bootstrap; an existing unmanaged sidebar requires explicit migration.
It performs no network, commit or push. It rejects missing sources,
broken repository links, unsafe names, symlinks, non-directory destination
ancestors and unmanaged page collisions before replacing managed content.
Only stale files listed by its previous manifest are removed. Repeating the
same input produces the same content. Failed validation should be corrected in
source and rerun; do not bypass it by deleting unrelated Wiki content.

[Wiki publication](../docs/wiki-publication.md) explains credentials, the first
page, triggers, verification and rollback. The workflow owns Git publication;
the pure renderer is tested without credentials or a remote Wiki.
