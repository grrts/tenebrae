#!/usr/bin/env python3
"""Flags GDScript locals that Godot rejects but gdparse accepts: a `var` declared
again in a nested block after the same name was declared earlier in an enclosing
block of the same function. Usage: python3 tools/check_locals.py src/*.gd"""
import re, sys
bad = 0
for f in sys.argv[1:]:
    for fn in re.split(r'\n(?=(?:static )?func )', open(f).read()):
        open_vars = []  # (indent, name) still in scope
        for line in fn.split('\n'):
            if not line.strip() or line.strip().startswith('#'):
                continue
            ind = len(line) - len(line.lstrip('\t'))
            open_vars = [(i, n) for i, n in open_vars if i <= ind or not line.strip()]
            open_vars = [(i, n) for i, n in open_vars if i <= ind]
            m = re.match(r'\t+(?:var|const) (\w+)', line)
            if m and ind >= 1:
                name = m.group(1)
                if any(n == name and i < ind for i, n in open_vars) or any(n == name and i == ind for i, n in open_vars):
                    print(f'{f}: {fn.split("(")[0].strip()}: "{name}" declared twice in one scope chain'); bad += 1
                open_vars.append((ind, name))
sys.exit(1 if bad else 0)
