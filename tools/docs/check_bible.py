#!/usr/bin/env python3
"""Check the content bible's tables (WP-024, D-016, D-017).

Rules:
- Every table row tiered Core or Should names a milestone (M1..M6) in its
  milestone column ("MS", or a combined "Tier / MS" column).
- Rows tiered Could or Won't claim no milestone.
- A table with a tier column must also have a milestone column.
- Every bible file must contain at least one tiered row, and the bible
  directory must exist and contain the three bible files.
Headers are compared case-insensitively with Markdown emphasis removed.
Exits non-zero on any violation, so CI can run it.

Usage: python3 tools/docs/check_bible.py [docs/DESIGN/bible]
"""
import pathlib
import re
import sys

MILESTONE = re.compile(r"\bM[1-6]\b")
ANY_MILESTONE = re.compile(r"\bM\d+\b")
TIER_WORD = re.compile(r"\b(Core|Should|Could|Won't)\b")
EXPECTED_FILES = {"world.md", "creatures.md", "items.md"}


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def norm(header_cell):
    return re.sub(r"[*_`]", "", header_cell).strip().lower()


def is_separator(row):
    return all(set(c) <= set("-: ") for c in row)


def check_file(path):
    errors, rows_checked = [], 0
    header = None
    tier_col = ms_col = None
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.startswith("|"):
            header = None
            continue
        row = cells(line)
        if header is None:
            header = [norm(c) for c in row]
            tier_col = ms_col = None
            combined = [i for i, h in enumerate(header) if h in ("tier / ms", "tier/ms")]
            tiers = [i for i, h in enumerate(header) if h == "tier"]
            mss = [i for i, h in enumerate(header) if h == "ms"]
            tierish = [h for h in header if "tier" in h]
            if combined:
                tier_col = ms_col = combined[0]
            elif tiers and mss:
                tier_col, ms_col = tiers[0], mss[0]
            elif tiers:
                errors.append(f"{path}:{n}: table has a Tier column but no MS column")
            elif tierish:
                errors.append(f"{path}:{n}: unrecognised tier header {tierish!r}")
            continue
        if is_separator(row) or tier_col is None:
            continue
        if len(row) != len(header):
            errors.append(f"{path}:{n}: row has {len(row)} cells, header has {len(header)}")
            continue
        tier_cell, ms_cell = row[tier_col], row[ms_col]
        m = TIER_WORD.search(tier_cell)
        rows_checked += 1
        if not m:
            errors.append(f"{path}:{n}: no tier in {tier_cell!r}")
            continue
        tier = m.group(1)
        bad = [x for x in ANY_MILESTONE.findall(ms_cell) if not MILESTONE.fullmatch(x)]
        if bad:
            errors.append(f"{path}:{n}: unknown milestone(s) {bad}")
        if tier in ("Core", "Should") and not MILESTONE.search(ms_cell):
            errors.append(f"{path}:{n}: {tier} row without a milestone: {row[0][:60]!r}")
        elif tier in ("Could", "Won't") and MILESTONE.search(ms_cell):
            errors.append(f"{path}:{n}: {tier} row claims a milestone: {row[0][:60]!r}")
    if rows_checked == 0:
        errors.append(f"{path}: no tiered rows found (unrecognised headers?)")
    return errors, rows_checked


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "docs/DESIGN/bible")
    if not root.is_dir():
        print(f"ERROR {root}: not a directory")
        return 1
    files = sorted(root.glob("*.md"))
    all_errors, total = [], 0
    missing = EXPECTED_FILES - {f.name for f in files}
    if missing:
        all_errors.append(f"{root}: missing bible files {sorted(missing)}")
    for path in files:
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
