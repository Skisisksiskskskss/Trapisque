#!/usr/bin/env python3
"""Fails if a Sift name, subtitle or translation key has no English text (WP-052; mission §7.6).

Checked, each against the registry sources (not only against datagen output, so something left out of
datagen is caught too):
- every block, item and entity registered in ModBlocks / ModItems / ModEntities has a name;
- every sound event registered in ModSounds is in sounds.json and has a subtitle with English text
  (steps excepted, as in vanilla);
- every translation key the code uses in a string literal passed to translatable(...) (across line
  breaks too), and every "translate" key in our data JSON, has English text.

Limits, stated: a key built at run time (concatenation, a constant defined elsewhere) can't be read
from the source; those keys are the registry names above, which are checked by name instead.
Usage: python3 tools/docs/check_lang.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SRC = REPO / "src"
JAVA = SRC / "main/java/thesift"
GEN = SRC / "main/generated"


def names(path: Path, pattern: str) -> list[str]:
    return re.findall(pattern, path.read_text())


def main() -> int:
    lang = json.loads((GEN / "assets/thesift/lang/en_us.json").read_text())
    sounds = json.loads((GEN / "assets/thesift/sounds.json").read_text())
    errors: list[str] = []

    # Registered things need names.
    blocks = names(JAVA / "registry/ModBlocks.java", r'register(?:NoItem)?\(\s*"([a-z0-9_]+)"')
    items = names(JAVA / "registry/ModItems.java", r'key\(\s*"([a-z0-9_]+)"\s*\)')
    entities = names(JAVA / "registry/ModEntities.java", r'Registries\.ENTITY_TYPE,\s*TheSift\.id\(\s*"([a-z0-9_]+)"')
    for b in blocks:
        if f"block.thesift.{b}" not in lang:
            errors.append(f"block {b}: no name")
    for i in items:
        if f"item.thesift.{i}" not in lang:
            errors.append(f"item {i}: no name")
    for e in entities:
        if f"entity.thesift.{e}" not in lang:
            errors.append(f"entity {e}: no name")

    # Every registered sound is in sounds.json with a subtitle (steps excepted).
    registered = names(JAVA / "registry/ModSounds.java", r'register(?:Holder)?\(\s*"([a-z0-9_.]+)"')
    for event in registered:
        entry = sounds.get(event)
        if entry is None:
            errors.append(f"sound {event}: registered but missing from sounds.json")
            continue
        sub = entry.get("subtitle")
        if sub is None:
            if not event.endswith(".step"):
                errors.append(f"sound {event}: no subtitle")
        elif sub not in lang:
            errors.append(f"sound {event}: subtitle key {sub} has no English text")
    for event in sounds:
        if event not in registered:
            errors.append(f"sound {event}: in sounds.json but not registered in ModSounds")

    # Keys written in code and in data.
    used: set[str] = set()
    for java in (SRC / "main/java").rglob("*.java"):
        used |= set(re.findall(r'translatable(?:WithFallback)?\(\s*"([^"]*thesift[^"]*)"', java.read_text(), re.S))
    for java in (SRC / "client/java").rglob("*.java"):
        text = java.read_text()
        if "/datagen/" not in java.as_posix():
            used |= set(re.findall(r'translatable(?:WithFallback)?\(\s*"([^"]*thesift[^"]*)"', text, re.S))
    for data_root in (GEN / "data", SRC / "main/resources/data"):
        for f in data_root.rglob("*.json"):
            used |= {k for k in re.findall(r'"translate"\s*:\s*"([^"]+)"', f.read_text()) if "thesift" in k}
    for key in sorted(used - lang.keys()):
        errors.append(f"key {key}: used, no English text")

    for e in errors:
        print("ERROR", e)
    print(f"{len(blocks)} blocks, {len(items)} items, {len(entities)} entities, {len(registered)} sounds, "
          f"{len(used)} used keys, {len(lang)} lang entries checked, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
