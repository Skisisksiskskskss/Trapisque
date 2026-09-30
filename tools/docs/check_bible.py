#!/usr/bin/env python3
"""Check the content bible's tables (WP-024, D-016).

Every table row tiered Core or Should must name a milestone (M1..M6) in its
milestone column ("MS", or "Tier / MS"). Rows tiered Could or Won't must not
claim one. Exits non-zero on any violation, so it can run in CI.

Usage: python3 tools/docs/check_bible.py [docs/DESIGN/bible]
"""
import pathlib
import re
import sys

MILESTONE = re.compile(r"\bM[1-6]\b")


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def tier_of(text):
    # The first tier word in the cell decides (e.g. "**Core** (gate **Should**...)").
    m = re.search(r"\b(Core|Should|Could|Won't)\b", text)
    return m.group(1) if m else None


def check_file(path):
    errors, rows_checked = [], 0
    lines = path.read_text(encoding="utf-8").splitlines()
    header = None
    for n, line in enumerate(lines, 1):
        if not line.startswith("|"):
            header = None
            continue
        row = cells(line)
        if header is None:
            header = row
            continue
        if all(set(c) <= set("-: ") for c in row):
            continue  # the separator row
        cols = {name: i for i, name in enumerate(header)}
        if "Tier / MS" in cols:
            tier_cell = ms_cell = row[cols["Tier / MS"]]
        elif "Tier" in cols and "MS" in cols:
            tier_cell, ms_cell = row[cols["Tier"]], row[cols["MS"]]
        elif "Tier" in cols:
            errors.append(f"{path}:{n}: table has a Tier column but no MS column")
            header = ["(reported)"]
            continue
        else:
            continue
        tier = tier_of(tier_cell)
        rows_checked += 1
        if tier is None:
            errors.append(f"{path}:{n}: no tier in {tier_cell!r}")
        elif tier in ("Core", "Should") and not MILESTONE.search(ms_cell) and "with each" not in ms_cell:
            errors.append(f"{path}:{n}: {tier} row without a milestone: {row[0][:60]!r}")
        elif tier in ("Could", "Won't") and MILESTONE.search(ms_cell) and ms_cell is not tier_cell:
            errors.append(f"{path}:{n}: {tier} row claims a milestone: {row[0][:60]!r}")
    return errors, rows_checked


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "docs/DESIGN/bible")
    all_errors, total = [], 0
    for path in sorted(root.glob("*.md")):
        errors, rows = check_file(path)
        all_errors += errors
        total += rows
        print(f"{path}: {rows} tiered rows")
    for e in all_errors:
        print("ERROR", e)
    print(f"{total} tiered rows checked, {len(all_errors)} errors")
    return 1 if all_errors else 0


if __name__ == "__main__":
    sys.exit(main())
