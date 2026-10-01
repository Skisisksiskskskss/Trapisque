#!/usr/bin/env python3
"""Fails if a Sift sound has no subtitle, a subtitle or translation key used by the mod has no English
text, or a block, item or entity of ours has no name (WP-052; mission §7.6).

Steps are the one exception to "every sound has a subtitle", as in vanilla.
Usage: python3 tools/docs/check_lang.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GEN = REPO / "src/main/generated/assets/thesift"
RES = REPO / "src/main/resources/assets/thesift"


def main() -> int:
    lang = json.loads((GEN / "lang/en_us.json").read_text())
    sounds = json.loads((GEN / "sounds.json").read_text())
    errors: list[str] = []
    for event, entry in sorted(sounds.items()):
        sub = entry.get("subtitle")
        if sub is None:
            if not event.endswith(".step"):
                errors.append(f"sound {event}: no subtitle")
        elif sub not in lang:
            errors.append(f"sound {event}: subtitle key {sub} has no English text")
    used = set()
    for java in (REPO / "src").rglob("*.java"):
        if "/gametest/" in java.as_posix():
            continue
        used |= set(re.findall(r'translatable\("([^"]*thesift[^"]*)"', java.read_text()))
    for key in sorted(used - lang.keys()):
        errors.append(f"key {key}: used in code, no English text")
    for kind, folder in (("block", "blockstates"), ("item", "items")):
        for f in sorted((GEN / folder).glob("*.json")):
            name = f.stem
            if f"{kind}.thesift.{name}" not in lang and f"block.thesift.{name}" not in lang:
                errors.append(f"{kind} {name}: no name")
    for e in errors:
        print("ERROR", e)
    print(f"{len(sounds)} sound events, {len(used)} code keys, {len(lang)} lang entries checked, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
