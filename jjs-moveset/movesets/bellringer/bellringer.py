#!/usr/bin/env python3
"""THE BELLRINGER - source of the Jujutsu Shenanigans Skill Builder character.

Run `python3 bellringer.py` to rebuild every milestone into ../../dist/.
See DESIGN.md for the design and FRAMEDATA.md for generated timings.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, HERE)

from jjsforge import anims as A  # noqa: E402
from jjsforge import analyze, codec, validate  # noqa: E402
from jjsforge.assets import SFX as S  # noqa: E402
from jjsforge.model import (AWAKENED, BASE, PASSIVE, Awakening, Br, Character,  # noqa: E402,F401
                            Chase, Melee, Skill, Special)
from jjsforge.nodes import (AIR, BAR, HOLD, JUMP, ULT, Anim, Branch, CancelVisual,  # noqa: E402,F401
                            Hitbox, HitCancel, Loop, SetCooldown, SetMelee, Sfx, State, Tag,
                            TagCheck, TagSet, Velo, Visual, Wait)

from fx import (BRONZE, GOLD, GROUND, HRP, IVORY, JADE, PALE, afterimage, aura,  # noqa: E402,F401
                bell, bell_ring, burst, chime, flash, fov, glow, gong, light, ripple, shake,
                sound_ring, spark, tok, trail)

NAME = "The Bellringer"

# ================================================================ TOLLS ====
# The gimmick lives entirely on the user: one numeric tag (0-3) driven only
# by the user's own timeline, so it behaves the same however the game scopes
# tags. The palm-glow readout is redrawn whenever the count changes and lasts
# exactly as long as the tag (TOLL_TIME), so no polling loop is needed.
TOLL = "BR_TOLL"
TOLL_FX = "BR_TOLLFX"
TOLL_TIME = 12


def toll_readout(level: int, announce: bool = True) -> list:
    """Redraw the Toll indicator for `level` (1-3)."""
    out = [CancelVisual(TOLL_FX)]
    arms = ["Right Arm", "Left Arm"][: min(level, 2)]
    for arm in arms:
        out += [
            light(arm, size=7, bright=1.8, time=TOLL_TIME, hold=True, vtag=TOLL_FX),
            aura(arm, size=0.55, time=TOLL_TIME, col=GOLD, alt=JADE, op=0.35, vtag=TOLL_FX),
        ]
    if level >= 3:
        out += [
            aura(HRP, size=1.1, time=TOLL_TIME, col=GOLD, alt=JADE, op=0.45, vtag=TOLL_FX),
            light(HRP, size=16, bright=1.2, time=TOLL_TIME, hold=True, vtag=TOLL_FX),
        ]
    if announce:
        out += [chime(0.85 + 0.15 * level, vol=1.4 + 0.2 * level),
                glow(0.25, GOLD, op=0.7 if level < 3 else 0.45)]
        if level >= 3:   # RESONANT: a deeper bell answers
            out += [Sfx(S.BRASS_HANDBELL_2, vol=1.6, speed=0.75, end=2.4, fade_out=1.0),
                    Visual("Wind Ring", time=0.6, size=1.4, alt_size=3, amount=3, col=GOLD,
                           alt_col=JADE, opacity=0.8, alt_opacity=1)]
    return out


def toll_gain(prefix: str, rest: list):
    """+1 Toll (capped at 3), redraw the readout, then run `rest`.

    Returns (line_nodes, branches). TAG ADD then equality checks is the standard
    counter idiom used by dozens of community movesets."""
    line = [Tag(TOLL, "1", time=TOLL_TIME, check=False, set_=False, add=True),
            TagCheck(TOLL, "4", f"{prefix}_cap"),
            TagCheck(TOLL, "3", f"{prefix}_3"),
            TagCheck(TOLL, "2", f"{prefix}_2"),
            TagCheck(TOLL, "1", f"{prefix}_1")] + list(rest)
    branches = {
        f"{prefix}_cap": Br([TagSet(TOLL, "3", TOLL_TIME)] + toll_readout(3, announce=False)
                            + [glow(0.2, GOLD, 0.6)] + list(rest)),
        f"{prefix}_3": Br(toll_readout(3) + list(rest)),
        f"{prefix}_2": Br(toll_readout(2) + list(rest)),
        f"{prefix}_1": Br(toll_readout(1) + list(rest)),
    }
    return line, branches


def toll_reset() -> list:
    return [TagSet(TOLL, "0", time=0.05), CancelVisual(TOLL_FX)]


# ================================================================ SPAWN ====
def build_spawn():
    line = toll_reset() + [
        chime(1.0, vol=1.2),
        ripple(0.6, op=0.5, time=0.7),
        light(HRP, size=12, bright=2, time=0.6),
    ]
    return Skill("Bonsho", key=0, cooldown=0, line=line, props=PASSIVE(),
                 notes="Hidden passive: resets Tolls on spawn and rings once.")


# ================================================================== M1s ====
M1_TABLE = [
    # index, clip, damage, swinging arm, hit sound, grants a Toll
    (1, A.M1_1, 3.0, "Right Arm", S.PUNCH_1, False),
    (2, A.M1_2, 3.0, "Left Arm", S.PUNCH_2, True),
    (3, A.M1_3, 3.5, "Right Arm", S.PUNCH_3, False),
]


def _m1_body(p: str, i: int, clip, dmg: float, arm: str, hit_sfx: int, toll: bool,
             awk: bool):
    """One M1 swing. `p` prefixes branch names (normal / awakened variants)."""
    tgt, miss, blk = f"{p}tgt", f"{p}miss", f"{p}blk"
    col = JADE if awk else GOLD
    br = {}
    line = [
        Sfx(S.SWING, vol=1.5, speed=1.0 + 0.06 * i),
        State("NoSprint", 0.4), State("NoJump", 0.4), State("NoM1", 0.33),
        trail(arm, 0.35, col),
        Anim(clip),
        Wait(0.2),
        Hitbox(dmg + (0.5 if awk else 0), size=(7, 7, 8), pos=(0, 0, 4), stun=0.75,
               stun_anim=True, ignore_wakeup=False, target=tgt),
        HitCancel(miss, time=0.1, missed=True),
    ]
    rest = [Velo((0, 0, 10), 0.1), Wait(0.15)]
    if toll and not awk:
        gl, gb = toll_gain(f"{p}t", rest)
        line += gl
        br.update(gb)
    else:
        line += rest
    reaction = [Sfx(hit_sfx, vol=2.2), tok(i), Velo((0, 0, 12), 0.1, rel_branch=True),
                *spark(0.8, col=col)]
    if awk:
        reaction += [chime(1.1 + 0.1 * i, vol=1.2), sound_ring((0, 0, 0), 0.8, JADE, 0.3)]
    br[tgt] = Br(reaction)
    # whiff: an unblockable 0-damage probe tells a block apart from a true miss
    br[miss] = Br([
        Hitbox(0, size=(7, 7, 8), pos=(0, 0, 4), stun=-1, stun_anim=False, ignore_wakeup=True,
               atk="Domain", blockable=False, cancel_enemy=False, can_kill=False),
        HitCancel(blk, time=0.1, missed=False),
        Anim(clip, start=clip.strike),
        Wait(0.15),
    ])
    br[blk] = Br([State("NoSprint", 0.4), State("NoJump", 0.4), State("NoM1", 0.25),
                  Sfx(S.HIT_KICK_L, vol=1.2, speed=0.8), Anim(clip, start=clip.strike, speed=0.8),
                  Wait(0.2)])
    return line, br


def build_m1(i: int):
    idx, clip, dmg, arm, hit_sfx, toll = M1_TABLE[i - 1]
    awk_line, awk_br = _m1_body("a", idx, clip, dmg, arm, hit_sfx, toll, awk=True)
    line, br = _m1_body("", idx, clip, dmg, arm, hit_sfx, toll, awk=False)
    br["awk"] = Br(awk_line, req=[ULT()])
    br.update(awk_br)
    return Melee(f"Palm {idx}", [Branch("awk")] + line, br)


def _m4_body(p: str, kind: str, awk: bool):
    """4th M1: normal knockback / up (holding jump) / down (airborne)."""
    clip = {"normal": A.M1_4, "up": A.M1_UP, "down": A.M1_DOWN}[kind]
    strike = 0.25 if kind == "down" else 0.2
    col = JADE if awk else GOLD
    tgt, miss = f"{p}{kind}_tgt", f"{p}{kind}_miss"
    hb = {"normal": dict(size=(8, 8, 8), pos=(0, 0, 4)),
          "up": dict(size=(8, 10, 8), pos=(0, 1.5, 4)),
          "down": dict(size=(8, 10, 8), pos=(0, -3, 4), hit_ragdoll=True, clear_kb=True)}[kind]
    br = {}
    line = [
        Sfx(S.SWING, vol=1.7, speed=0.9),
        Sfx(S.WHOOSH_FAST, vol=0.8, speed=1.2),
        State("NoSprint", 0.5), State("NoJump", 0.5), State("NoM1", 0.6),
        trail("Right Arm", 0.4, col), trail("Left Arm", 0.4, col),
        Anim(clip),
        Wait(strike),
        Hitbox(4 + (0.5 if awk else 0), stun=0.75, stun_anim=True, ignore_wakeup=False,
               target=tgt, debree=2 if kind != "up" else 0, **hb),
        HitCancel(miss, time=0.1, missed=True),
    ]
    rest = [Velo((0, 0, 8), 0.1), Wait(0.2)]
    if awk:   # the bell never stops ringing: the finisher sends out an echo ring
        rest = [*bell_ring(0.55, z=4, col=JADE), *gong("small", vol=1.4),
                Hitbox(1.5, size=(14, 8, 14), pos=(0, 0, 4), stun=0.5, stun_anim=True,
                       blockable=False, single=False)] + rest
        line += rest
    else:
        gl, gb = toll_gain(f"{p}{kind}t", rest)
        line += gl
        br.update(gb)
    launch = {"normal": Velo((0, 6, 48), 0.12, rel_branch=True, ragdoll=1.0),
              "up": Velo((0, 52, 6), 0.12, rel_branch=True, ragdoll=1.3),
              "down": Velo((0, -75, 8), 0.15, rel_branch=True, ragdoll=1.2)}[kind]
    reaction = [Sfx(S.PUNCH_3, vol=2.4), Sfx(S.HIT_KICK_H, vol=1.6), *gong("small", vol=1.6),
                launch, *burst(1.0, col=col), shake("Light", 0.4, 2)]
    if kind == "down":
        reaction += [Sfx(S.ROCK_IMPACT, vol=1.6), ripple(0.7, col=col, time=0.5)]
    br[tgt] = Br(reaction)
    br[miss] = Br([State("Stun", 0.45), Anim(clip, start=strike, speed=0.5), Wait(0.3)])
    return line, br


def build_m4():
    br, line = {}, []
    for awk in (True, False):
        p = "a" if awk else ""
        for kind, req in (("down", [AIR()]), ("up", [JUMP()]), ("normal", [])):
            body, b = _m4_body(p, kind, awk)
            br[f"{p}{kind}"] = Br(body, req=([ULT()] if awk else []) + req)
            br.update(b)
            line.append(Branch(f"{p}{kind}"))
    return Melee("Gong Palm", line, br,
                 notes="Branches try awakened variants first (Req ULT), then down (AIR), "
                       "up (JUMP) and normal.")


# ================================================================= DASH ====
def build_dash():
    br = {}
    rest = [SetMelee(0, 1), Anim(A.CHASE, start=1.22, speed=1.2), Wait(0.15)]
    gl, gb = toll_gain("dt", rest)
    br.update(gb)
    br["dhit"] = Br([Velo((0, 0.01, 0), 0.05), Sfx(S.PUNCH_2, vol=2), tok(2)] + gl)
    br["dtgt"] = Br([Velo((0, 0, 10), 0.1, rel_branch=True), *spark(0.9),
                     sound_ring((0, 0, 0), 0.7, GOLD, 0.3)])
    line = [
        Sfx(S.DASH, vol=2), Sfx(S.WHOOSH_FAST, vol=1, speed=1.1),
        State("NoM1", 0.25),
        afterimage(0.45), trail("Right Arm", 0.6), light(HRP, 8, 1.5, 0.5),
        Anim(A.CHASE, end=0.95, speed=1.1),
        Velo((0, 0, 72), 0.5, fade=True, track=True),
        Wait(0.08),
        Hitbox(3, size=(7, 7, 9), pos=(0, 0, 3), stun=0.8, stun_anim=True, branch="dhit",
               target="dtgt"),
        Wait(0.08),
        Loop(2, 5),
        Velo((0, 0.01, 0), 0.08),
        Anim(A.CHASE, start=1.22, speed=1.2),
        Wait(0.2),
    ]
    return Chase("Shumoku Step", 6, line, br)


# ============================================================ MILESTONES ====
def milestone_entries(stage: int):
    """Entries included at each milestone (cumulative)."""
    entries = [build_spawn(), build_m1(1), build_m1(2), build_m1(3), build_m4(), build_dash()]
    return entries


MILESTONES = [
    (1, "0.1", "M1s, dash and the Toll system"),
]


def build(stage: int) -> Character:
    version = dict((s, v) for s, v, _ in MILESTONES)[stage]
    ch = Character(NAME, version)
    ch.add(*milestone_entries(stage))
    return ch


def frame_rows(ch: Character):
    """Representative paths for the frame-data table."""
    rows = []
    doc = {e.name: e.to_json() for e in ch.entries}

    def add(label, ename, take):
        if ename in doc:
            rows.append((label, analyze.entry_paths(doc[ename], {"x": take})["x"]))

    add("M1 #1 (hit)", "Palm 1", {})
    add("M1 #2 (hit, +Toll)", "Palm 2", {"tag:BR_TOLL": "t_1"})
    add("M1 #3 (hit)", "Palm 3", {})
    add("M1 #1 (whiff)", "Palm 1", {"miss": "miss"})
    add("M4 normal (hit)", "Gong Palm", {"branch:normal": True})
    add("M4 up (hit)", "Gong Palm", {"branch:up": True})
    add("M4 down (hit)", "Gong Palm", {"branch:down": True})
    add("M4 normal (whiff)", "Gong Palm", {"branch:normal": True, "miss": "normal_miss"})
    add("Dash (hit at first check)", "Shumoku Step", {"hit": "dhit"})
    return rows


def write_outputs(stage: int, outdir: str, known):
    ch = build(stage)
    doc = ch.document()
    rep = validate.validate(doc, known_anims=known)
    if not rep.ok:
        print(rep.summary())
        raise SystemExit(f"milestone {stage} failed validation")
    code = codec.encode(doc)
    assert codec.decode(code) == json.loads(codec.dumps_compact(doc)), "round-trip mismatch"
    os.makedirs(outdir, exist_ok=True)
    base = f"bellringer_v{ch.version}"
    with open(os.path.join(outdir, base + ".txt"), "w") as f:
        f.write(code + "\n")
    with open(os.path.join(outdir, base + ".json"), "w") as f:
        f.write(ch.readable_json() + "\n")
    return ch, code, rep


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default=os.path.join(ROOT, "dist"))
    ap.add_argument("--stage", type=int, default=None, help="build one milestone only")
    ap.add_argument("--catalog", default=os.path.join(ROOT, "tools", "data", "anim_catalog.json"))
    args = ap.parse_args()
    known = A.known_pairs(args.catalog if os.path.exists(args.catalog) else None)
    stages = [args.stage] if args.stage else [s for s, _, _ in MILESTONES]
    last = None
    for st in stages:
        ch, code, rep = write_outputs(st, args.out, known)
        last = (ch, code)
        print(f"v{ch.version}: {len(ch.entries)} entries, code {len(code):,} chars, "
              f"{len(rep.warnings)} warning(s)")
        for w in rep.warnings:
            print("   warn", w)
    if last and not args.stage:
        ch, code = last
        with open(os.path.join(args.out, "bellringer_latest.txt"), "w") as f:
            f.write(code + "\n")
        with open(os.path.join(HERE, "FRAMEDATA.md"), "w") as f:
            f.write(f"# Frame data - {NAME} v{ch.version}\n\n")
            f.write("Generated from the actual timelines by `jjsforge.analyze` "
                    "(WAIT sums; hitstun from each HITBOX). *Advantage* = target stun "
                    "left when you recover; a follow-up whose first hit comes out "
                    "faster than that is a true combo.\n\n")
            f.write(analyze.table(frame_rows(ch)) + "\n")


if __name__ == "__main__":
    main()
