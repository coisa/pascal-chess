# Documentation renderer

`wiki_sync.py` turns the repository's `docs/` Markdown and supported assets
into files for a GitHub Wiki. It needs Python3.9+, the source repository,
an output directory, `owner/repository` and a full source commit SHA.

```sh
python3 .github/wiki_sync.py --output build/wiki-preview --repository coisa/pascal-chess --revision "$(git rev-parse HEAD)"
python3 .github/test_wiki_sync.py
```

The renderer writes the chosen output, an index/sidebar and a managed-file
manifest. It performs no network, commit or push. It rejects missing sources,
broken repository links, unsafe names, symlinks and unmanaged page collisions.
Only stale files listed by its previous manifest are removed. Repeating the
same input produces the same content. Failed validation should be corrected in
source and rerun; do not bypass it by deleting unrelated Wiki content.

[Wiki publication](../docs/wiki-publication.md) explains credentials, the first
page, triggers, verification and rollback. The workflow owns Git publication;
the pure renderer is tested without credentials or a remote Wiki.
