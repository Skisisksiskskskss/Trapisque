"""Curated built-in animation catalog.

ANIM_USE is [character folder, clip index]. Folders follow the base roster
order (1 Honored One, 2 Vessel, ... 8 Switcher, ... 17 Salaryman ...); clip
indices follow each folder's insertion order. Every entry below was checked
against real game exports:

  length  = the clip length the editor stores as PREVIEW end (mode over exports)
  strike  = median time (s, at speed 1) where creators place the first damaging
            hitbox after starting this clip - i.e. the visible impact frame
  uses    = how many exported nodes use this clip (confidence)

Names come from the clip's base move (libjjs naming, cross-checked with how
creators use the clip).
"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Animation:
    name: str
    use: tuple
    length: float
    strike: float | None
    uses: int
    note: str = ""

    def __iter__(self):
        return iter(self.use)


A = Animation

# --- Honored One (Gojo): clean martial-arts M1 set, the most-used M1 clips ---
M1_1 = A("Honored One Melee 1", (1, 13), 0.333, 0.2, 34)
M1_2 = A("Honored One Melee 2", (1, 14), 0.35, 0.2, 33)
M1_3 = A("Honored One Melee 3", (1, 15), 0.35, 0.2, 18)
M1_4 = A("Honored One Melee 4", (1, 16), 0.333, 0.2, 32)
M1_UP = A("Honored One Up (uptilt)", (1, 17), 0.35, 0.2, 166, "M4 while holding jump")
M1_DOWN = A("Honored One Down (downslam)", (1, 18), 0.5, 0.25, 255, "M4 in the air")
CHASE = A("Honored One Chase (front dash)", (1, 19), 1.5, 0.42, 177)
LAPSE_BLUE = A("Lapse Blue (palm forward)", (1, 3), 5.1, 0.4, 63)
RAPID_PUNCHES = A("Rapid Punches", (1, 5), 6.7, 0.44, 48)
HOLLOW_PURPLE = A("Hollow Purple (gather pose)", (1, 1), 3.6, 1.0, 146)
TWOFOLD_HIT = A("Twofold Kick hit", (1, 9), 1.35, 0.35, 47)

# --- Vessel (Yuji) ---
CRUSHING_BLOW = A("Crushing Blow (ground slam)", (2, 3), 4.733, 0.6, 179)
DIVERGENT_1 = A("Divergent Fist 1", (2, 4), 2.75, 0.42, 92)
DIVERGENT_3 = A("Divergent Fist 3", (2, 6), 2.75, 0.36, 37)
VESSEL_ULT = A("Vessel awakening", (2, 17), 2.25, None, 12)

# --- Mahoraga ---
EARTHQUAKE = A("Mahoraga Earthquake (stomp)", (5, 3), 1.333, 0.49, 46)

# --- Blood Manipulator (Choso) ---
PIERCING_BLOOD = A("Piercing Blood (palms together, thrust)", (7, 5), 1.15, 0.675, 77)

# --- Switcher (Todo) ---
BRUTE_FORCE = A("Brute Force (heavy punch)", (8, 2), 4.7, 0.375, 68)
PEBBLE_THROW = A("Pebble Throw", (8, 8), 1.0, 0.29, 26)
CLAP_1 = A("Boogie Woogie clap 1", (8, 18), 0.8, None, 5)
CLAP_2 = A("Boogie Woogie clap 2", (8, 19), 0.8, None, 3)
CLAP_3 = A("Boogie Woogie clap 3", (8, 20), 0.8, None, 16)

CURATED = [v for v in globals().values() if isinstance(v, Animation)]


def known_pairs(catalog_json_path: str | None = None, min_uses: int = 2) -> set:
    """All (cat, idx) pairs seen in real exports (for validation warnings)."""
    pairs = {a.use for a in CURATED}
    if catalog_json_path:
        import json
        with open(catalog_json_path) as f:
            data = json.load(f)
        for key, v in data.items():
            if v.get("n", 0) >= min_uses:
                c, i = key.split(",")
                pairs.add((int(c), int(i)))
    return pairs
