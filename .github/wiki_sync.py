#!/usr/bin/env python3
"""Render tracked docs into a Wiki checkout; performs no network or Git writes."""
import argparse
import json
from pathlib import Path
import re
import shutil
import string
from urllib.parse import quote, unquote, urlsplit
from html import unescape
from marko import block, inline
from marko.parser import Parser
from marko.source import Source

MANIFEST = '.docs-sync-manifest.json'
ASSETS = {'.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.pdf'}


class SourceLinkRefDef(block.LinkRefDef):
    """Retain Marko's parsed destination offsets for reference definitions."""
    override = True

    @classmethod
    def match(cls, source):
        if not source.prefix:
            return super().match(source)
        if not source.expect_re(cls.pattern):
            return False
        # Marko's reference matcher reads the raw buffer across line breaks.
        # Match container definitions in a temporary view, including titles
        # continued after a same-line destination. Equal-length padding
        # keeps every destination offset relative to the original document.
        chunks = [source._buffer[:source.pos]]
        for line in source._buffer[source.pos:].splitlines(keepends=True):
            prefix_length = source.match_prefix(source.prefix, line)
            if prefix_length < 0:
                break
            chunks.append(' ' * prefix_length + line[prefix_length:])
        shadow = Source(''.join(chunks))
        shadow.pos = source._current_pos
        if not super().match(shadow):
            return False
        source.context.linkref_info = shadow.context.linkref_info
        return True

    @classmethod
    def parse(cls, source):
        destination = source.context.linkref_info.link_dest
        result = super().parse(source)
        result.dest_span = (destination.start, destination.end)
        return result


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
            repository_path = quote(target.relative_to(repo).as_posix())
            if target.is_file() and target.suffix.lower() in ASSETS:
                url = f'https://raw.githubusercontent.com/{repository}/{revision}/{repository_path}'
            else:
                view = 'tree' if target.is_dir() else 'blob'
                url = f'https://github.com/{repository}/{view}/{revision}/{repository_path}'
        if parsed.query:
            url += '?' + parsed.query
        if parsed.fragment:
            url += '#' + parsed.fragment
        return url

    def markdown(path):
        original = path.read_text(encoding='utf-8')
        parser = Parser()
        parser.add_element(SourceLinkRefDef)
        document = parser.parse(original)
        replacements = {}

        def visit(node):
            if isinstance(node, (inline.Link, inline.Image, block.LinkRefDef)):
                span = getattr(node, 'dest_span', None)
                value = unescape(inline.Literal.strip_backslash(node.dest.removeprefix('<').removesuffix('>')))
                parsed = urlsplit(value)
                # Reference uses have no destination span; their definition owns it.
                if span is not None and parsed.path and not parsed.scheme and not parsed.netloc:
                    start, end = span
                    if not 0 <= start <= end <= len(original):
                        raise ValueError('Invalid Markdown source span.')
                    replacement = target_url(path, value)
                    if original[start:end].startswith('<'):
                        replacement = '<' + replacement + '>'
                    replacements[span] = replacement
            children = getattr(node, 'children', [])
            if isinstance(children, list):
                for child in children:
                    visit(child)

        visit(document)
        # Replace only parsed destinations, preserving every other source character.
        previous_start = len(original)
        for (start, end), replacement in sorted(replacements.items(), reverse=True):
            if end > previous_start:
                raise ValueError('Overlapping Markdown destination spans.')
            original = original[:start] + replacement + original[end:]
            previous_start = start
        return original

    planned = {target: markdown(path) for path, target in pages.items()}
    links = []
    for path, target in pages.items():
        title = next((line[2:].strip() for line in path.read_text(encoding='utf-8').splitlines() if line.startswith('# ')), path.stem)
        # A heading can itself contain links or HTML; navigation labels are literal.
        title = ''.join('\\' + char if char in string.punctuation else char for char in title)
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
        if any(ancestor.exists() and not ancestor.is_dir()
               for ancestor in (output.joinpath(*parts[:depth]) for depth in range(1, len(parts)))):
            raise ValueError(f'Wiki destination ancestor is not a directory: {name}')
        if target.exists() and not target.is_file():
            raise ValueError(f'Wiki destination is not a file: {name}')
        if target.exists() and name not in previous and name != 'Home.md':
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
