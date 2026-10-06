#!/usr/bin/env python3
"""Builds build/CloverBattlegrounds.rbxlx from src with Rojo, then checks
script sizes: Roblox won't take a script longer than 200,000 characters
(Script.Source), so the build fails if one gets there.

    python3 tools/build.py
"""

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIMIT = 200_000


def main():
    subprocess.run(['rojo', 'build', 'default.project.json', '-o', 'build/CloverBattlegrounds.rbxlx'], cwd=ROOT,
                   check=True)
    sizes = []
    for base, _, files in os.walk(os.path.join(ROOT, 'src')):
        for name in files:
            if name.endswith('.luau'):
                path = os.path.join(base, name)
                with open(path, encoding='utf-8') as f:
                    sizes.append((len(f.read()), os.path.relpath(path, ROOT)))
    sizes.sort(reverse=True)
    print(f'{len(sizes)} scripts, {sum(size for size, _ in sizes):,} characters; largest:')
    for size, path in sizes[:5]:
        print(f'  {size:8,}  {path}')
    over = [path for size, path in sizes if size >= LIMIT]
    if over:
        sys.exit(f'over the {LIMIT:,}-character limit: {", ".join(over)}')


if __name__ == '__main__':
    main()
