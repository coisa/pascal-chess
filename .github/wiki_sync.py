#!/usr/bin/env python3
"""Render tracked docs into a Wiki checkout; performs no network or Git writes."""
import argparse
import json
from pathlib import Path
import re
import shutil
from urllib.parse import quote, unquote, urlsplit

MANIFEST = '.docs-sync-manifest.json'
ASSETS = {'.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.pdf'}
LINK = re.compile(r'(!?\[[^\]\n]*\]\()(<[^>\n]+>|[^)\s]+)(\s+["\'][^)\n]*["\'])?\)')


def managed_name(name):
    path = Path(name)
    return (not path.is_absolute() and '..' not in path.parts and
            all(not part.startswith('.') for part in path.parts) and
            ((len(path.parts) == 1 and path.suffix == '.md') or
             (path.parts[0] == 'assets' and path.suffix.lower() in ASSETS)))


def render(repo, output, repository, revision):
    repo, output = Path(repo).resolve(), Path(output).resolve()
    source = repo / 'docs'
    if source.is_symlink():
        raise ValueError('The documentation root must not be a symlink.')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Expected owner/repository.')
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Expected a full source commit SHA.')
    if output == repo or output in repo.parents or output == source or source in output.parents:
        raise ValueError('Output must not overwrite source files.')
    pages, assets = {}, {}
    for path in sorted(source.rglob('*')):
        if path.is_symlink():
            raise ValueError(f'Symlinks are not publishable: {path.relative_to(repo)}')
        if not path.is_file():
            continue
        relative = path.relative_to(source)
        if path.suffix.lower() == '.md':
            slug = '--'.join(relative.with_suffix('').parts)
            if not re.fullmatch(r'[A-Za-z0-9_-]+', slug):
                raise ValueError(f'Use portable Markdown page names: {relative}')
            target = slug + '.md'
            if slug.lower() in {'home', '_sidebar', '_footer'} or target.lower() in {v.lower() for v in pages.values()}:
                raise ValueError(f'Wiki page name collision: {relative}')
            pages[path] = target
        elif path.suffix.lower() in ASSETS:
            assets[path] = 'assets/' + relative.as_posix()
        else:
            raise ValueError(f'Unsupported documentation asset: {relative}')
    if not pages:
        raise ValueError('No Markdown documentation to publish.')

    def target_url(source_page, value):
        value = value.removeprefix('<').removesuffix('>')
        parsed = urlsplit(value)
        if parsed.scheme or parsed.netloc or not parsed.path:
            return value
        target = (source_page.parent / unquote(parsed.path)).resolve()
        if target != repo and repo not in target.parents:
            raise ValueError(f'Link escapes repository: {value}')
        if target in pages:
            url = f'https://github.com/{repository}/wiki/{quote(pages[target][:-3])}'
        elif target in assets:
            url = f'https://raw.githubusercontent.com/wiki/{repository}/{quote(assets[target])}'
        else:
            if not target.exists():
                raise ValueError(f'Broken repository link: {source_page.name}: {value}')
            url = f'https://github.com/{repository}/blob/{revision}/{quote(target.relative_to(repo).as_posix())}'
        if parsed.query:
            url += '?' + parsed.query
        if parsed.fragment:
            url += '#' + parsed.fragment
        return url

    def markdown(path):
        rendered, fence = [], ''
        for line in path.read_text(encoding='utf-8').splitlines(keepends=True):
            marker = re.match(r'^\s{0,3}(`{3,}|~{3,})', line)
            if marker:
                token = marker.group(1)
                if not fence:
                    fence = token
                elif token[0] == fence[0] and len(token) >= len(fence) and not line[marker.end():].strip():
                    fence = ''
                rendered.append(line)
                continue
            if fence:
                rendered.append(line)
                continue
            # Inline code remains literal; documentation uses standard inline links.
            chunks = re.split(r'(`[^`]*`)', line)
            for index in range(0, len(chunks), 2):
                chunks[index] = LINK.sub(lambda match: match[1] + target_url(path, match[2]) + (match[3] or '') + ')', chunks[index])
            rendered.append(''.join(chunks))
        return ''.join(rendered)

    planned = {target: markdown(path) for path, target in pages.items()}
    links = []
    for path, target in pages.items():
        title = next((line[2:].strip() for line in path.read_text(encoding='utf-8').splitlines() if line.startswith('# ')), path.stem)
        links.append(f'- [{title}](https://github.com/{repository}/wiki/{quote(target[:-3])})')
    index = '\n'.join(links) + '\n'
    planned['Home.md'] = (f'# {repository.split("/")[1]} documentation\n\n'
                          f'Published from [docs/ at {revision[:12]}](https://github.com/{repository}/tree/{revision}/docs). '
                          'Edit the repository documentation and submit a PR; this Wiki is generated.\n\n' + index +
                          f'\n[Build and play](https://github.com/{repository}/blob/{revision}/README.md)\n')
    planned['_Sidebar.md'] = f'[Documentation home](https://github.com/{repository}/wiki)\n\n' + index
    output.mkdir(parents=True, exist_ok=True)
    manifest = output / MANIFEST
    previous = []
    if manifest.is_symlink():
        raise ValueError('Refusing a symlink manifest.')
    if manifest.exists():
        old = json.loads(manifest.read_text(encoding='utf-8'))
        if old.get('owner') != 'docs-publisher' or not isinstance(old.get('files'), list):
            raise ValueError('Unrecognized publication manifest.')
        previous = old['files']
        if any(not isinstance(name, str) or not managed_name(name) for name in previous):
            raise ValueError('Unsafe previous manifest path.')
    names = sorted(list(planned) + list(assets.values()))
    # Validate all destinations before changing anything; preserve unrelated Wiki pages.
    for name in set(names + previous):
        target = output / name
        parts = Path(name).parts
        has_symlink = any(output.joinpath(*parts[:depth]).is_symlink()
                          for depth in range(1, len(parts) + 1))
        if not managed_name(name) or output not in target.resolve().parents or has_symlink:
            raise ValueError(f'Unsafe Wiki destination: {name}')
        if target.exists() and not target.is_file():
            raise ValueError(f'Wiki destination is not a file: {name}')
        if target.exists() and name not in previous and name not in {'Home.md', '_Sidebar.md'}:
            raise ValueError(f'Unmanaged Wiki page would be overwritten: {name}')
    for name in set(previous) - set(names):
        (output / name).unlink(missing_ok=True)
    for name, content in planned.items():
        (output / name).write_text(content, encoding='utf-8')
    for path, name in assets.items():
        (output / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, output / name)
    manifest.write_text(json.dumps({'owner': 'docs-publisher', 'source': revision, 'files': names}, indent=2) + '\n', encoding='utf-8')
    return len(pages), len(assets)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', default='.')
    parser.add_argument('--output', required=True)
    parser.add_argument('--repository', required=True)
    parser.add_argument('--revision', required=True)
    args = parser.parse_args()
    pages, assets = render(args.repo, args.output, args.repository, args.revision)
    print(f'Rendered {pages} documentation pages and {assets} assets; unrelated Wiki files preserved.')
