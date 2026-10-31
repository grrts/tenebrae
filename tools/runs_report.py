#!/usr/bin/env python3
"""Playtest report from Tenebrae run logs.

Each build appends one JSON line per run to user://runs.jsonl
(Windows: %APPDATA%/Godot/app_userdata/Tenebrae Prototype/runs.jsonl,
Linux: ~/.local/share/godot/app_userdata/Tenebrae Prototype/runs.jsonl).
Collect testers' files into one folder and run:  python3 tools/runs_report.py <folder or files>
It prints the numbers the plan's playtesting section asks for: deaths by depth,
time to first death, rune pick rates, weapon win rates and boss reach.
"""
import json, sys, pathlib, collections

paths = []
for a in sys.argv[1:] or ["."]:
    p = pathlib.Path(a)
    paths += sorted(p.rglob("*.jsonl")) if p.is_dir() else [p]
runs = []
for p in paths:
    for line in p.read_text().splitlines():
        try:
            r = json.loads(line)
        except ValueError:
            continue
        if not r.get("smoke"):
            runs.append(r)
if not runs:
    sys.exit("no runs found")

n = len(runs)
wins = sum(r["won"] for r in runs)
print(f"{n} runs from {len(paths)} file(s), {wins} won ({wins / n:.0%})")
times = sorted(r["time"] for r in runs)
print(f"median run {times[n // 2] / 60:.1f} min, first death after {min((r['time'] for r in runs if not r['won']), default=0) / 60:.1f} min")

print("\ndeaths by depth")
deaths = collections.Counter(r["depth"] for r in runs if not r["won"])
for d in range(1, 17):
    if deaths[d]:
        print(f"  {d:>2} {'#' * deaths[d]} {deaths[d]}")

print("\nboss reach (share of runs that got to each boss)")
for d, name in [(4, "Chain Warden"), (8, "Hollow King"), (12, "Ashen Jarl"), (16, "Saint Umber")]:
    print(f"  {name:<13} {sum(r['depth'] >= d for r in runs) / n:.0%}")

print("\nrune pick rate (picked / offered)")
off = collections.Counter(x for r in runs for x in r.get("offered", []))
pick = collections.Counter(x for r in runs for x in r.get("runes", []))
for k, v in sorted(off.items(), key=lambda kv: -pick[kv[0]] / kv[1]):
    print(f"  {k:<13} {pick[k] / v:>4.0%}  ({pick[k]}/{v})")

print("\nweapons (runs, win rate, mean depth)")
by_w = collections.defaultdict(list)
for r in runs:
    by_w[r["weapon"] or "none"].append(r)
for w, rs in sorted(by_w.items()):
    print(f"  {w:<11} {len(rs):>3}  {sum(r['won'] for r in rs) / len(rs):>4.0%}  {sum(r['depth'] for r in rs) / len(rs):.1f}")
