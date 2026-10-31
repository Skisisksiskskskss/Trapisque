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
from jjsforge.nodes import (AIR, BAR, HOLD, JUMP, ULT, Anim, Awaken, Branch,  # noqa: E402,F401
                            CancelVisual, Hitbox, HitCancel, Loop, SetCooldown, SetMelee, Sfx,
                            State, Tag, TagCheck, TagSet, Velo, Visual, Wait)

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


# ====================================================== 1  STRIKING LOG ====
def _lunge_checks(dmg, size, pos, stun, branch, target, checks=3, **kw):
    """A hitbox re-checked every 0.06 s while the user travels."""
    return [Hitbox(dmg, size=size, pos=pos, stun=stun, stun_anim=True, branch=branch,
                   target=target, **kw),
            Wait(0.06), Loop(2, checks)]


def build_striking_log():
    """Move 1: ram the log into the bell. Starter that resets the M1 string."""
    br = {}
    # ---- tap -----------------------------------------------------------
    gl, gb = toll_gain("lt", [SetMelee(0, 1.5), Wait(0.3)])
    br.update(gb)
    br["hit"] = Br([Velo((0, 0.01, 0), 0.05), shake("Medium", 0.35, 3), fov(-6, 0.3),
                    light("Right Arm", 10, 4, 0.3)] + gl)
    br["struck"] = Br([Sfx(S.PUNCH_3, vol=2.4), Sfx(S.HEAVY_HIT, vol=1.8), *gong("small", 1.8),
                       Velo((0, 2, 16), 0.12, rel_branch=True), *burst(1.1),
                       sound_ring((0, 0, 0), 1.2, GOLD, 0.35)])
    # ---- hold: charged ram (ender) ----------------------------------------
    cgl, cgb = toll_gain("ct", [Wait(0.35)])
    br.update(cgb)
    br["hold"] = Br([
        State("SpeedMultiplier", 0.6, value=0.35), State("NoJump", 0.6),
        Anim(A.DIVERGENT_1, start=0.25, speed=0),            # hold the wind-up pose
        Sfx(S.LUCK_CHARGE, vol=2), aura("Right Arm", 0.8, 0.7, GOLD, PALE, op=0.2, hold=False),
        light("Right Arm", 9, 3, 0.7), glow(0.6, GOLD, 0.75),
        Wait(0.6),
        Sfx(S.FULL_CHARGE_DASH, vol=2.2), Sfx(S.WHOOSH_FAST, vol=1.2),
        Anim(A.DIVERGENT_1, start=0.25, speed=1.3), afterimage(0.4),
        trail("Right Arm", 0.5), State("NoM1", 0.9), State("NoJump", 0.9),
        Velo((0, 0, 120), 0.25, fade=True, track=True),
        Wait(0.06),
        *_lunge_checks(9, (9, 9, 10), (0, 0, 4), 1.2, "chit", "cstruck", checks=4),
        Velo((0, 0.01, 0), 0.05), State("Stun", 0.4), Wait(0.4),
    ], req=[HOLD()])
    br["chit"] = Br([Velo((0, 0.01, 0), 0.05), shake("Heavy", 0.5, 4), fov(-10, 0.4),
                     flash(PALE, 0.06)] + cgl)
    br["cstruck"] = Br([Sfx(S.PUNCH_3, vol=2.6), Sfx(S.IMPACT_FRAMES, vol=2),
                        *gong("medium", 2.0), Velo((0, 10, 70), 0.15, rel_branch=True, ragdoll=1.2),
                        *burst(1.6), *bell_ring(0.6, col=GOLD)])
    # ---- air: falling log -----------------------------------------------
    agl, agb = toll_gain("at", [Wait(0.3)])
    br.update(agb)
    br["air"] = Br([
        State("NoM1", 0.75), State("NoJump", 0.75),
        Sfx(S.WHOOSH_FAST, vol=1.6, speed=0.9), Sfx(S.CURSED_STRIKE_STARTUP, vol=1.6),
        Anim(A.M1_DOWN, speed=0.8), trail("Right Arm", 0.5), afterimage(0.35),
        Velo((0, -55, 45), 0.3, track=True),
        Wait(0.06),
        *_lunge_checks(6, (8, 10, 8), (0, -2, 3), 1.0, "ahit", "aspike", checks=4,
                       hit_ragdoll=True),
        Velo((0, 0.01, 0), 0.05), ripple(0.5, time=0.4), Sfx(S.ROCK_IMPACT, vol=1.2),
        State("Stun", 0.3), Wait(0.3),
    ], req=[AIR()])
    br["ahit"] = Br([Velo((0, 12, 0), 0.1), shake("Medium", 0.35, 3)] + agl)
    br["aspike"] = Br([Sfx(S.PUNCH_3, vol=2.4), Sfx(S.AIR_SLAMMED, vol=2), *gong("small", 1.6),
                       Velo((0, -80, 6), 0.15, rel_branch=True, ragdoll=1.1), *burst(1.2),
                       ripple(0.8, time=0.5), Sfx(S.ROCK_IMPACT, vol=1.6)])
    line = [
        Branch("air"),
        State("NoM1", 0.75), State("NoJump", 0.75), State("NoSprint", 0.75),
        Sfx(S.CURSED_STRIKE_STARTUP, vol=1.8), tok(1, 1.2),
        Anim(A.DIVERGENT_1, speed=1.2),
        light("Right Arm", 8, 2.5, 0.4), aura("Right Arm", 0.6, 0.4, GOLD, PALE, hold=False),
        Wait(0.18),
        Branch("hold"),
        Sfx(S.WHOOSH_FAST, vol=1.4), afterimage(0.35), trail("Right Arm", 0.45),
        Velo((0, 0, 80), 0.25, fade=True, track=True),
        Wait(0.08),
        *_lunge_checks(6, (8, 8, 9), (0, 0, 3.5), 1.0, "hit", "struck", checks=3),
        Velo((0, 0.01, 0), 0.05), Anim(A.DIVERGENT_1, start=0.6, end=1.4),
        State("Stun", 0.3), Wait(0.35),
    ]
    return Skill("Striking Log", key=1, cooldown=10, line=line, branches=br, props=BASE(),
                 tooltip="Hold: Charged Log | Air: Falling Log")


# ======================================================= 2  REVERB PALM ====
def _palm_windup(col=GOLD, big=False):
    return [
        State("NoJump", 0.9), State("NoSprint", 0.9), State("DirectionLock", 0.35),
        Sfx(S.ENERGY_WINDUP, vol=1.8), chime(0.9 if not big else 0.75, vol=1.2),
        Anim(A.PIERCING_BLOOD, speed=2.0),           # palms meet, thrust at ~0.34 s
        light("Right Arm", 7, 3, 0.4, col), light("Left Arm", 7, 3, 0.4, col),
        aura("Right Arm", 0.6, 0.4, col, PALE, hold=False),
        aura("Left Arm", 0.6, 0.4, col, PALE, hold=False),
    ] + ([glow(0.35, GOLD, 0.5), aura(HRP, 1.2, 0.5, GOLD, JADE, op=0.3, hold=False)]
         if big else [])


def _echo(dmg: float, stun: float, target: str, pitch: float, bell_sound: bool = False):
    """A vibration detonating inside the (stunned) target in front of the user."""
    return [
        chime(pitch, vol=1.8), Sfx(S.ENERGY_HIT, vol=1.8, speed=pitch),
        *(gong("small", 1.6) if bell_sound else []),
        Hitbox(dmg, size=(9, 9, 9), pos=(0, 0, 5), stun=stun, stun_anim=True,
               blockable=False, ignore_wakeup=True, target=target),
    ]


def build_reverb_palm():
    """Move 2 (★): double palm plants a vibration; the echo detonates 0.5 s later.
    Knell: the echo rings three times and bursts into a launch."""
    br = {}
    echo_rest = [Velo((0, 0, 4), 0.06), Wait(0.5),
                 *_echo(5, 1.0, "echo", 1.0, bell_sound=True),
                 SetMelee(0, 1.5), Wait(0.2)]
    gl, gb = toll_gain("rt", echo_rest)
    br.update(gb)
    br["planted"] = Br([Sfx(S.PUNCH_2, vol=2.2), tok(2, 1.4), Velo((0, 0, 6), 0.08, rel_branch=True),
                        *spark(0.9), sound_ring((0, 0, 0), 1.0, GOLD, 0.4),
                        aura(HRP, 0.9, 0.55, GOLD, JADE, op=0.4, hold=False)])
    br["echo"] = Br([Visual("Distortion", time=0.25, size=3.5, alt_size=1.5, amount=1,
                            opacity=0, alt_opacity=1), *burst(1.0, col=JADE, alt=PALE),
                     ripple(0.5, col=JADE, time=0.45), Velo((0, 4, 4), 0.1, rel_branch=True)])
    br["miss"] = Br([State("Stun", 0.35), Anim(A.PIERCING_BLOOD, start=0.7, speed=1.2),
                     Wait(0.3)])
    # ---- Knell (3 Tolls): spent only if the palm connects ----------------
    br["knell"] = Br(_palm_windup(GOLD, big=True) + [
        Wait(0.3),
        Hitbox(4, size=(7, 7, 7), pos=(0, 0, 4), stun=1.4, stun_anim=True, target="kplant"),
        HitCancel("miss", time=0.1, missed=True),
        *toll_reset(),
        Sfx(S.BRASS_HANDBELL_1, vol=1.6, speed=0.8, end=2, fade_out=0.8),
        shake("Light", 0.3, 2), Wait(0.45),
        *_echo(3, 0.9, "kecho1", 1.0), Wait(0.45),
        *_echo(3, 0.9, "kecho2", 1.15), Wait(0.45),
        *_echo(4, 0.9, "kecho3", 1.3), Wait(0.45),
        *gong("medium", 2.2), shake("Medium", 0.5, 4), fov(-10, 0.45), flash(PALE, 0.06),
        Hitbox(4, size=(9, 9, 9), pos=(0, 0, 5), stun=1.2, stun_anim=True, blockable=False,
               ignore_wakeup=True, target="kburst"),
        Awaken(6), SetMelee(0, 1.5), Wait(0.25),
    ], req=[])
    br["kplant"] = Br(br["planted"].line + [aura(HRP, 1.2, 2.0, GOLD, JADE, op=0.35, hold=False)])
    for i in (1, 2, 3):
        br[f"kecho{i}"] = Br([Visual("Distortion", time=0.25, size=3 + i, alt_size=1.5,
                                     amount=1, opacity=0, alt_opacity=1),
                              *spark(0.8 + 0.2 * i, col=JADE, alt=PALE),
                              sound_ring((0, 0, 0), 0.8 + 0.3 * i, JADE, 0.35, forward=False),
                              Velo((0, 2, 2), 0.06, rel_branch=True)])
    br["kburst"] = Br([*bell(0.8, time=0.45, op=0.4, grow=1.15), *bell_ring(0.7, col=GOLD),
                       *burst(1.6), Velo((0, 35, 30), 0.15, rel_branch=True, ragdoll=1.3)])
    line = [TagCheck(TOLL, "3", "knell"),
            State("NoM1", 1.0), *_palm_windup(),
            Wait(0.3),
            Hitbox(4, size=(7, 7, 7), pos=(0, 0, 4), stun=1.4, stun_anim=True, target="planted"),
            HitCancel("miss", time=0.1, missed=True)] + gl
    return Skill("Reverb Palm", key=2, cooldown=12, line=line, branches=br, props=BASE(),
                 tooltip="★ Knell at 3 Tolls: the echo rings three times")


# ============================================================ MILESTONES ====
def milestone_entries(stage: int):
    """Entries included at each milestone (cumulative)."""
    entries = [build_spawn(), build_m1(1), build_m1(2), build_m1(3), build_m4(), build_dash()]
    if stage >= 2:
        entries.append(build_striking_log())
    if stage >= 3:
        entries.append(build_reverb_palm())
    return entries


MILESTONES = [
    (1, "0.1", "M1s, dash and the Toll system"),
    (2, "0.2", "Move 1 - Striking Log (hold + air variants)"),
    (3, "0.3", "Move 2 - Reverb Palm (delayed echo, Knell)"),
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

    W = {"whiff": True}
    add("M1 #1 (hit)", "Palm 1", {})
    add("M1 #2 (hit, +Toll)", "Palm 2", {"tag:BR_TOLL": "t_1"})
    add("M1 #3 (hit)", "Palm 3", {})
    add("M1 (whiff)", "Palm 1", {"miss": "miss", **W})
    add("M4 normal (hit, ragdoll)", "Gong Palm", {"branch:normal": True})
    add("M4 up (hit, ragdoll)", "Gong Palm", {"branch:up": True})
    add("M4 down (hit, ragdoll)", "Gong Palm", {"branch:down": True})
    add("M4 (whiff)", "Gong Palm", {"branch:normal": True, "miss": "normal_miss", **W})
    add("Dash (hit at first check)", "Shumoku Step", {"hit": "dhit"})
    add("Dash (whiff)", "Shumoku Step", W)
    add("1 Striking Log (hit)", "Striking Log", {"hit": "hit"})
    add("1 Striking Log (whiff)", "Striking Log", W)
    add("1 Charged Log (hold, hit, ragdoll)", "Striking Log", {"branch:hold": True, "hit": "chit"})
    add("1 Falling Log (air, hit, ragdoll)", "Striking Log", {"branch:air": True, "hit": "ahit"})
    add("2 Reverb Palm (hit + echo)", "Reverb Palm", {"tag:BR_TOLL": "rt_1"})
    add("2 Reverb Palm (whiff)", "Reverb Palm", {"miss": "miss", **W})
    add("2 ★ Knell Reverb Palm (hit, ragdoll)", "Reverb Palm", {"tag:BR_TOLL": "knell"})
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
