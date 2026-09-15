#!/usr/bin/env python3
"""Test documentation transformation and managed-file boundaries without network."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).with_name('wiki_sync.py')
spec = importlib.util.spec_from_file_location('wiki_sync', MODULE)
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)
SCRATCH = MODULE.parent.parent / 'build'
SCRATCH.mkdir(exist_ok=True)
SHA = 'a' * 40


class WikiTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=SCRATCH, prefix='wiki-test-')
        self.root = Path(self.temp.name)
        self.repo, self.output = self.root / 'repo', self.root / 'wiki'
        (self.repo / 'docs').mkdir(parents=True)
        (self.repo / 'README.md').write_text('# Game\n')
        (self.repo / 'docs/a.md').write_text('# First\n[Second](b.md#part) [Build](../README.md)\n![Image](pic.png)\n`[literal](missing.md)`\n```md\n[example](missing.md)\n```\n')
        (self.repo / 'docs/b.md').write_text('# Second\n## Part\n')
        (self.repo / 'docs/pic.png').write_bytes(b'synthetic-image')

    def tearDown(self):
        self.temp.cleanup()

    def render(self):
        return sync.render(self.repo, self.output, 'owner/game', SHA)

    def test_links_assets_and_idempotence(self):
        self.assertEqual(self.render(), (2, 1))
        content = (self.output / 'a.md').read_text()
        self.assertIn('https://github.com/owner/game/wiki/b#part', content)
        self.assertIn(f'/blob/{SHA}/README.md', content)
        self.assertIn('https://raw.githubusercontent.com/wiki/owner/game/assets/pic.png', content)
        self.assertIn('`[literal](missing.md)`', content)
        self.assertIn('```md\n[example](missing.md)\n```', content)
        before = {p.relative_to(self.output): p.read_bytes() for p in self.output.rglob('*') if p.is_file()}
        self.render()
        self.assertEqual(before, {p.relative_to(self.output): p.read_bytes() for p in self.output.rglob('*') if p.is_file()})

    def test_removes_only_previously_managed_pages(self):
        self.render()
        (self.output / 'Manual.md').write_text('Keep me')
        (self.repo / 'docs/a.md').write_text('# First\n')
        (self.repo / 'docs/b.md').unlink()
        self.render()
        self.assertFalse((self.output / 'b.md').exists())
        self.assertEqual((self.output / 'Manual.md').read_text(), 'Keep me')

    def test_refuses_collision_and_broken_links(self):
        (self.repo / 'docs/Home.md').write_text('# Collision')
        with self.assertRaises(ValueError): self.render()
        (self.repo / 'docs/Home.md').unlink()
        (self.repo / 'docs/a.md').write_text('[broken](missing.md)')
        with self.assertRaises(ValueError): self.render()

    def test_refuses_traversal_and_symlinks(self):
        (self.repo / 'docs/a.md').write_text('[outside](../../private.md)')
        with self.assertRaises(ValueError): self.render()
        (self.repo / 'docs/a.md').write_text('# Fine')
        (self.repo / 'docs/link.md').symlink_to(self.repo / 'README.md')
        with self.assertRaises(ValueError): self.render()

    def test_refuses_unsafe_manifest_and_unmanaged_overwrite(self):
        self.render()
        (self.output / sync.MANIFEST).write_text(json.dumps({'owner': 'docs-publisher', 'files': ['../outside.md']}))
        with self.assertRaises(ValueError): self.render()
        (self.output / sync.MANIFEST).unlink()
        with self.assertRaises(ValueError): self.render()

    def test_refuses_output_over_source(self):
        with self.assertRaises(ValueError): sync.render(self.repo, self.repo / 'docs', 'owner/game', SHA)

    def test_preserves_multiple_backtick_delimiters(self):
        literal = '``[example](missing.md)`` and ```a ` [other](absent.md)```'
        (self.repo / 'docs/a.md').write_text('# First\n' + literal + '\n[Real](b.md)\n')
        self.render()
        result = (self.output / 'a.md').read_text()
        self.assertIn(literal, result)
        self.assertIn('[Real](https://github.com/owner/game/wiki/b)', result)

    def test_preserves_indented_code(self):
        literal = '    [example](missing.md)\n\t[other](absent.md)\n'
        (self.repo / 'docs/a.md').write_text('# First\n\n' + literal)
        self.render()
        self.assertIn(literal, (self.output / 'a.md').read_text())

    def test_whole_line_code_span_does_not_open_a_fence(self):
        (self.repo / 'docs/a.md').write_text('# First\n\n```[literal](missing.md)```\n\n[Actual](b.md)\n')
        self.render()
        result = (self.output / 'a.md').read_text()
        self.assertIn('```[literal](missing.md)```', result)
        self.assertIn('[Actual](https://github.com/owner/game/wiki/b)', result)

    def test_rewrites_reference_definitions(self):
        (self.repo / 'docs/nested').mkdir()
        (self.repo / 'docs/nested/page.md').write_text('# Nested\n')
        (self.repo / 'docs/a.md').write_text('# First\n[Page][page] ![Picture][image]\n\n[page]: nested/page.md#section "Title"\n[image]: <pic.png>\n[code]: ../README.md\n')
        self.render()
        result = (self.output / 'a.md').read_text()
        self.assertIn('[page]: https://github.com/owner/game/wiki/nested--page#section "Title"', result)
        self.assertIn('[image]: <https://raw.githubusercontent.com/wiki/owner/game/assets/pic.png>', result)
        self.assertIn(f'[code]: https://github.com/owner/game/blob/{SHA}/README.md', result)

    def test_preserves_multiline_code_spans(self):
        literal = '`literal\n[example](missing.md)\ntext`'
        (self.repo / 'docs/a.md').write_text('# First\n\n' + literal + '\n\n[Actual](b.md)\n')
        self.render()
        result = (self.output / 'a.md').read_text()
        self.assertIn(literal, result)
        self.assertIn('[Actual](https://github.com/owner/game/wiki/b)', result)

    def test_nested_labels_and_linked_images(self):
        (self.repo / 'docs/a.md').write_text('# First\n[outer [inner]](../README.md) [![Picture](pic.png)](b.md)\n')
        self.render()
        result = (self.output / 'a.md').read_text()
        self.assertIn(f'[outer [inner]](https://github.com/owner/game/blob/{SHA}/README.md)', result)
        self.assertIn('[![Picture](https://raw.githubusercontent.com/wiki/owner/game/assets/pic.png)](https://github.com/owner/game/wiki/b)', result)

    def test_multiline_reference_definition(self):
        (self.repo / 'docs/a.md').write_text('# First\n[Page][page]\n\n[page]:\n  <b.md>\n  "Title"\n')
        self.render()
        self.assertIn('[page]:\n  <https://github.com/owner/game/wiki/b>\n  "Title"', (self.output / 'a.md').read_text())

    def test_container_offsets_and_escaped_labels(self):
        (self.repo / 'docs/a.md').write_text('# First\n\n> [Quoted](b.md)\n\n- Item\n  - [Nested](../README.md)\n\n\\[literal](missing.md)\n')
        self.render()
        result = (self.output / 'a.md').read_text()
        self.assertIn('> [Quoted](https://github.com/owner/game/wiki/b)', result)
        self.assertIn(f'  - [Nested](https://github.com/owner/game/blob/{SHA}/README.md)', result)
        self.assertIn('\\[literal](missing.md)', result)

    def test_reference_offsets_inside_containers(self):
        (self.repo / 'docs/a.md').write_text('# First\n\n> Café [Page][page]\n>\n> [page]: b.md\n\n- [Code][code]\n\n  [code]: <../README.md>\n')
        self.render()
        result = (self.output / 'a.md').read_text()
        self.assertIn('> Café [Page][page]', result)
        self.assertIn('> [page]: https://github.com/owner/game/wiki/b', result)
        self.assertIn(f'  [code]: <https://github.com/owner/game/blob/{SHA}/README.md>', result)

    def test_uses_tree_urls_for_directories(self):
        (self.repo / 'src').mkdir()
        (self.repo / 'docs/a.md').write_text('# First\n[Sources](../src/)\n')
        self.render()
        self.assertIn(f'/tree/{SHA}/src)', (self.output / 'a.md').read_text())

    def test_preserves_unmanaged_sidebar_and_initial_home(self):
        self.output.mkdir()
        (self.output / 'Home.md').write_text('Bootstrap')
        (self.output / '_Sidebar.md').write_text('Manual navigation')
        with self.assertRaises(ValueError): self.render()
        self.assertEqual((self.output / '_Sidebar.md').read_text(), 'Manual navigation')
        self.assertEqual((self.output / 'Home.md').read_text(), 'Bootstrap')
        (self.output / '_Sidebar.md').unlink()
        self.render()
        self.assertIn('Published from', (self.output / 'Home.md').read_text())

    def test_refuses_symlink_ancestors_before_write_or_stale_delete(self):
        self.render()
        (self.output / 'assets').rename(self.output / 'manual-assets')
        (self.output / 'assets').symlink_to(self.output / 'manual-assets', target_is_directory=True)
        manual = self.output / 'manual-assets/pic.png'
        manual.write_bytes(b'unmanaged-original')
        manifest = (self.output / sync.MANIFEST).read_bytes()
        with self.assertRaises(ValueError): self.render()
        self.assertEqual(manual.read_bytes(), b'unmanaged-original')
        self.assertEqual((self.output / sync.MANIFEST).read_bytes(), manifest)
        (self.repo / 'docs/pic.png').unlink()
        (self.repo / 'docs/a.md').write_text('# First\n')
        with self.assertRaises(ValueError): self.render()
        self.assertEqual(manual.read_bytes(), b'unmanaged-original')
        self.assertEqual((self.output / sync.MANIFEST).read_bytes(), manifest)


if __name__ == '__main__':
    unittest.main()
