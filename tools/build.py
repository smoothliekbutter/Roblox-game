#!/usr/bin/env python3
"""Builds build/CloverBattlegrounds.rbxlx from a minified copy of src.

    python3 tools/build.py              minify, verify, build
    python3 tools/build.py --readable   build straight from src (no minifying)

1. darklua (rules in .darklua.json5) writes build/min: every script with its
   comments and spacing stripped and its locals renamed. Tokens keep their
   lines, so an error's line number still matches src.
2. Every minified script must compile to exactly the same bytecode as its
   source, at -O1 and -O2. Without debug info (-g0) local names aren't in
   the bytecode, so this proves the scripts behave (and perform) the same.
   Needs luau-compile (on PATH, or $LUAU_COMPILE).
3. rojo builds the place from build/min, laid out like default.project.json.
4. Prints sizes (in bytes, which is what the limit counts) and fails if a
   script reaches Roblox's 200,000-character Script.Source limit.
"""

import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
MIN = os.path.join(ROOT, 'build', 'min')
PROJECT = os.path.join(ROOT, 'default.project.json')
MIN_PROJECT = os.path.join(ROOT, 'build', 'min.project.json')
PLACE = os.path.join(ROOT, 'build', 'CloverBattlegrounds.rbxlx')
LIMIT = 200_000


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def scripts(folder):
    for base, _, files in os.walk(folder):
        for name in sorted(files):
            if name.endswith('.luau'):
                path = os.path.join(base, name)
                yield os.path.relpath(path, folder), path


def compiled(compiler, path, level):
    return subprocess.run([compiler, '--binary', '-g0', level, path], capture_output=True, check=True).stdout


def verify():
    compiler = os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile')
    if not compiler:
        sys.exit('luau-compile not found (put it on PATH or set LUAU_COMPILE); it checks the minified scripts')
    bad = []
    count = 0
    for rel, path in scripts(SRC):
        for level in ('-O1', '-O2'):
            if compiled(compiler, path, level) != compiled(compiler, os.path.join(MIN, rel), level):
                bad.append(f'{rel} ({level})')
        count += 1
    if bad:
        sys.exit('minified scripts compile differently from their source:\n  ' + '\n  '.join(bad))
    print(f'verified: {count} scripts compile to the same bytecode as their source (-O1 and -O2)')


def min_project():
    def repoint(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == '$path' and isinstance(value, str) and value.startswith('src/'):
                    node[key] = 'min/' + value[len('src/'):]
                else:
                    repoint(value)

    with open(PROJECT) as f:
        project = json.load(f)
    repoint(project)
    with open(MIN_PROJECT, 'w') as f:
        json.dump(project, f, indent='\t')
        f.write('\n')


def report(folder):
    sizes = sorted(((os.path.getsize(path), rel) for rel, path in scripts(folder)), reverse=True)
    total = sum(size for size, _ in sizes)
    print(f'{len(sizes)} scripts, {total:,} bytes; largest:')
    for size, rel in sizes[:5]:
        print(f'  {size:8,}  {rel}')
    over = [rel for size, rel in sizes if size >= LIMIT]
    if over:
        sys.exit(f'over the {LIMIT:,}-character Script.Source limit: {", ".join(over)}')
    return total


def main():
    if '--readable' in sys.argv[1:]:
        run('rojo', 'build', PROJECT, '-o', PLACE)
        report(SRC)
        return
    shutil.rmtree(MIN, ignore_errors=True)
    run('darklua', 'process', SRC, MIN, '--config', os.path.join(ROOT, '.darklua.json5'))
    verify()
    min_project()
    run('rojo', 'build', MIN_PROJECT, '-o', PLACE)
    source = sum(os.path.getsize(path) for _, path in scripts(SRC))
    print(f'src: {source:,} bytes')
    shipped = report(MIN)
    print(f'shipped scripts are {100 * shipped / source:.0f}% of the source')


if __name__ == '__main__':
    main()
