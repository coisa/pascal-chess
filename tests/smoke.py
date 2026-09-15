#!/usr/bin/env python3
"""Bounded executable checks; all exports live in disposable fixtures."""
import hashlib
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

CLI = str(Path(sys.argv[1] if len(sys.argv) > 1 else 'build/ChessCLI').resolve())
DESKTOP = str(Path(sys.argv[2] if len(sys.argv) > 2 else 'build/chess').resolve())


def run(binary, *args, success=True, text='', env=None):
    result = subprocess.run([binary, *args], input=text, text=True,
                            capture_output=True, timeout=30,
                            env=os.environ | (env or {}))
    assert (result.returncode == 0) == success, (args, result.returncode, result.stdout, result.stderr)
    return result.stdout + result.stderr


assert 'Pascal Chess' in run(CLI, '--help')
assert 'Pascal Chess' in run(DESKTOP, '--help')
assert 'Nodes: 197281' in run(CLI, '--perft', '4')
assert 'Best move:' in run(CLI, '--search', '--nodes', '2000', '--depth', '4')
for options in [('--perft', '-1'), ('--perft', '7'), ('--nodes', '1e4'),
                ('--depth', '0'), ('--fen', 'nonsense'), ('--fen',),
                ('--search', '--perft', '1'), ('--unknown',)]:
    run(CLI, *options, success=False)
for options in [('--fen', 'nonsense'), ('--scene', 'unknown'), ('--snapshot',),
                ('--self-test', '--snapshot', 'unused.bmp'), ('--unknown',)]:
    run(DESKTOP, *options, success=False)
run(CLI, '--moves', 'e2e5', '--perft', '1', success=False)
transcript = run(CLI, text='e2e4\ne7e5\nundo\nfen\nhint\nai\npgn\nnew\nquit\n')
assert 'Suggested:' in transcript and '[Event "Pascal Chess casual game"]' in transcript
assert 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1' in transcript
assert 'Illegal move' in run(CLI, text='e2e5\nquit\n')
run(CLI, text='')  # EOF is a clean exit, including redirected stdin.
with tempfile.TemporaryDirectory(prefix='pascal-chess-') as scratch:
    output = Path(scratch) / 'game.pgn'
    run(CLI, '--moves', 'f2f3 e7e5 g2g4 d8h4', '--pgn', str(output))
    assert '1. f3 e5 2. g4 Qh4# 0-1' in output.read_text()
    run(CLI, '--pgn', str(Path(scratch) / 'absent' / 'game.pgn'), success=False)
print('ok - CLI options, perft, search, interaction, EOF and PGN exports')

headless = {'SDL_VIDEODRIVER': 'dummy', 'SDL_AUDIODRIVER': 'dummy'}
for _ in range(3):
    assert 'PASS SDL replay' in run(DESKTOP, '--self-test', env=headless)
assert 'PASS SDL replay' in run(DESKTOP, '--self-test', env=headless | {'SDL_AUDIODRIVER': 'unavailable'})
with tempfile.TemporaryDirectory(prefix='pascal-chess-frames-') as scratch:
    hashes = set()
    for scene in ('start', 'play', 'paused', 'promotion', 'mate'):
        path = Path(scratch) / f'{scene}.bmp'
        run(DESKTOP, '--no-audio', '--snapshot', str(path), '--scene', scene, env=headless)
        data = path.read_bytes()
        assert data[:2] == b'BM'
        offset = struct.unpack_from('<I', data, 10)[0]
        width, height = struct.unpack_from('<ii', data, 18)
        assert (width, height) == (1280, 900), (scene, width, height)
        assert len(data) - offset == width * height * 4
        pixels = data[offset:]
        colors = set(pixels[i:i+4] for i in range(0, len(pixels), 4))
        assert len(colors) > 100, (scene, len(colors))
        hashes.add(hashlib.sha256(pixels).hexdigest())
    assert len(hashes) == 5
    run(DESKTOP, '--snapshot', str(Path(scratch) / 'absent' / 'frame.bmp'),
        '--no-audio', env=headless, success=False)
    run(DESKTOP, '--snapshot', str(Path(scratch) / 'frame.bmp'), '--no-audio',
        env=headless | {'CHESS_FONT': str(Path(scratch) / 'missing.ttf')}, success=False)
run(DESKTOP, '--self-test', env=headless | {'SDL_VIDEODRIVER': 'unavailable'}, success=False)
print('ok - repeated SDL replay, audio fallback, five distinct frames and clean failure paths')
