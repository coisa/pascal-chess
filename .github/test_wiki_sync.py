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


if __name__ == '__main__':
    unittest.main()
