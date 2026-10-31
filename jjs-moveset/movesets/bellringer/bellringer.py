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
from jjsforge.assets import MESH as M  # noqa: E402
from jjsforge.assets import SFX as S  # noqa: E402
from jjsforge.model import (AWAKENED, BASE, PASSIVE, Awakening, Br, Character,  # noqa: E402,F401
                            Chase, Melee, Props, Skill, Special)
from jjsforge.nodes import (AIR, BAR, HOLD, JUMP, ULT, Anim, Awaken, Branch,  # noqa: E402,F401
                            Grab, Teleport, Counter,
                            CancelVisual, Hitbox, HitCancel, Loop, Projectile, SetCooldown,
                            SetMelee, Sfx, State, Tag, TagCheck, TagSet, Velo, Visual, Wait)

from fx import (BRONZE, DUSK, GOLD, GROUND, HRP, IVORY, JADE, PALE, afterimage, aura,  # noqa: E402,F401
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


def funeral_toll(post=()) -> Br:
    """Kill flourish (HITBOX BRANCH FINISHER): palms pressed in prayer, the
    funeral bell tolls three times and a spectral bell rises over the fallen.
    `post` replays the effects the move would have played after its last hit."""
    return Br(list(post) + [
        State("IFrame", 2.2), State("NoM1", 2.2), State("NoJump", 2.2), State("NoSprint", 2.2),
        Anim(A.CLAP_1, start=0.35, speed=0),
        flash(DUSK, 1.2), fov(6, 1.2),
        Sfx(S.DEATH_TOLL, vol=2.2, end=3.0, fade_out=1.2, global_=True),
        *bell(1.2, z=6, time=2.2, op=0.45, rise=35, ease="Sine", ease_dir="In"),
        aura(HRP, 1.0, 2.2, GOLD, JADE, op=0.3, hold=False),
        Wait(0.75),
        Sfx(S.DEATH_TOLL, vol=1.8, speed=0.95, end=2.5, fade_out=1.0),
        ripple(1.2, col=JADE, time=0.8),
        Wait(0.75),
        Sfx(S.DEATH_TOLL, vol=1.5, speed=0.9, end=2.5, fade_out=1.2), chime(0.7, vol=1.6),
        Wait(0.6),
    ])


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
                chime(1.2, vol=1.4)] + rest     # audiovisual only: never re-hits the launch
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
def _dash_body(p: str, col, awk: bool):
    return [
        Sfx(S.DASH, vol=2), Sfx(S.WHOOSH_FAST, vol=1, speed=1.1),
        State("NoM1", 0.25),
        afterimage(0.45, col), trail("Right Arm", 0.6, col), light(HRP, 8, 1.5, 0.5, col),
        *([aura(HRP, 0.9, 0.5, JADE, GOLD, op=0.3, hold=False), chime(1.3, vol=1)] if awk else []),
        Anim(A.CHASE, end=0.95, speed=1.1),
        Velo((0, 0, 72), 0.5, fade=True, track=True),
        Wait(0.08),
        Hitbox(3, size=(7, 7, 9), pos=(0, 0, 3), stun=0.8, stun_anim=True, branch=f"{p}dhit",
               target=f"{p}dtgt"),
        Wait(0.08),
        Loop(2, 5),
        Velo((0, 0.01, 0), 0.08),
        Anim(A.CHASE, start=1.22, speed=1.2),
        Wait(0.2),
    ]


def build_dash(polish: bool = False):
    br = {}
    rest = [SetMelee(0, 1), Anim(A.CHASE, start=1.22, speed=1.2), Wait(0.15)]
    gl, gb = toll_gain("dt", rest)
    br.update(gb)
    br["dhit"] = Br([Velo((0, 0.01, 0), 0.05), Sfx(S.PUNCH_2, vol=2), tok(2)] + gl)
    br["dtgt"] = Br([Velo((0, 0, 10), 0.1, rel_branch=True), *spark(0.9),
                     sound_ring((0, 0, 0), 0.7, GOLD, 0.3)])
    line = _dash_body("", GOLD, awk=False)
    if polish:   # v1.0: awakened dash - jade afterimages, an echo instead of a Toll
        br["awk"] = Br(_dash_body("a", JADE, awk=True), req=[ULT()])
        br["adhit"] = Br([Velo((0, 0.01, 0), 0.05), Sfx(S.PUNCH_2, vol=2), chime(1.2, vol=1.4),
                          *bell_ring(0.5, z=3, col=JADE)] + rest)
        br["adtgt"] = Br([Velo((0, 0, 10), 0.1, rel_branch=True), *spark(0.9, col=JADE),
                          sound_ring((0, 0, 0), 0.8, JADE, 0.3)])
        line = [Branch("awk")] + line
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
        *_lunge_checks(6, (8, 8, 9), (0, 0, 3.5), 1.0, "hit", "struck", checks=3,
                       hit_ragdoll=True),                  # can chase a knocked-back body
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
               ignore_wakeup=True, target="kburst", finisher="fin"),
        Awaken(6), SetMelee(0, 1.5), Wait(0.25),
    ], req=[])
    br["fin"] = funeral_toll()
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


# ========================================================= 3  TOLL WAVE ====
def _wave_fx(ptag: str, time: float, scale: float = 1.0, col=GOLD):
    """Ring of sound riding a projectile."""
    return [
        Visual("Mesh", amount=M.RING_LINE, time=time, size=0.12 * scale, alt_size=1.3, col=col,
               alt_col=PALE, opacity=0.1, alt_opacity=0.7, rot=(90, 0, 0), ptag=ptag),
        Visual("Mesh", amount=M.RING_LINE, time=time, size=0.09 * scale, alt_size=1.3,
               col=JADE, alt_col=PALE, opacity=0.3, alt_opacity=0.8, pos=(0, 0, -2.5),
               rot=(90, 0, 0), ptag=ptag),
        Visual("Wind Ring", time=time, size=1.4 * scale, alt_size=1.3, amount=3, col=col,
               alt_col=PALE, opacity=0.8, alt_opacity=1, ptag=ptag),
        Visual("Light", time=time, size=14 * scale, opacity=2, alt_opacity=0.5, col=col,
               ptag=ptag),
        Sfx(S.WHOOSH_FAST, vol=1.4, speed=1.2, ptag=ptag),
    ]


def build_toll_wave():
    """Move 3: push a ring of sound forward. Hold: Sustained Note (multi-hit)."""
    br = {}
    pgl, pgb = toll_gain("wt", [Wait(0.05)])
    br.update(pgb)
    br["phit"] = Br(list(pgl))
    br["rung"] = Br([Sfx(S.PUNCH_1, vol=2), chime(1.15, vol=1.6), *spark(0.9),
                     sound_ring((0, 0, 0), 1.0, GOLD, 0.35),
                     Velo((0, 2, -45), 0.15, rel_branch=True)])        # sympathetic pull
    # ---- hold: Sustained Note -------------------------------------------
    sgl, sgb = toll_gain("st", [Wait(0.05)])
    br.update(sgb)
    br["shit"] = Br(list(sgl))
    br["sung"] = Br([Sfx(S.PUNCH_2, vol=1.6), chime(1.0, vol=1.3), *spark(0.8, col=JADE),
                     Velo((0, 1, 18), 0.1, rel_branch=True)])
    br["hold"] = Br([
        State("NoM1", 1.3), State("NoJump", 1.3), State("SpeedMultiplier", 0.45, value=0.4),
        Anim(A.LAPSE_BLUE, start=0.2, speed=0), Sfx(S.RED_MAX_CHARGE, vol=1.6, end=0.9,
                                                   fade_out=0.3),
        aura("Right Arm", 0.9, 0.5, GOLD, JADE, op=0.2, hold=False),
        light("Right Arm", 10, 3, 0.5), sound_ring((0, 0, 3), 0.6, JADE, 0.45),
        Wait(0.45),
        Anim(A.LAPSE_BLUE, start=0.2, end=1.2, speed=1.2),
        *gong("small", 1.6), Sfx(S.RED_MAX_SHOOT, vol=1.4, end=1.2, fade_out=0.4),
        shake("Light", 0.3, 2), fov(4, 0.3),
        Projectile("BR_NOTE", dmg=3, size=(16, 10, 8), pos=(0, 0, 4), speed=45, time=0.9,
                   stun=0.8, stun_anim=True, atk="Bullet", continue_=True, filter_interval=0.3,
                   hit_ragdoll=False, branch="shit", target="sung"),
        *_wave_fx("BR_NOTE", 0.9, 1.8, JADE),
        Wait(0.5),
    ], req=[HOLD()])
    line = [
        State("NoM1", 0.75), State("NoJump", 0.75), State("DirectionLock", 0.3),
        Sfx(S.ENERGY_WINDUP_2, vol=1.6), chime(1.0, vol=1.1),
        Anim(A.LAPSE_BLUE, end=1.2, speed=1.3),            # palm forward at ~0.31 s
        light("Right Arm", 8, 2.5, 0.4),
        Wait(0.15),
        Branch("hold"),
        Wait(0.16),
        Sfx(S.CLAP, vol=1.6, speed=0.9), *gong("small", 1.4),
        shake("Light", 0.25, 1.5),
        Projectile("BR_WAVE", dmg=4, size=(9, 9, 5), pos=(0, 0, 3), speed=140, time=0.4,
                   stun=1.1, stun_anim=True, atk="Bullet", hit_ragdoll=True,
                   ignore_wakeup=True, branch="phit", target="rung"),   # can pick up OTG
        *_wave_fx("BR_WAVE", 0.4, 1.0, GOLD),
        sound_ring((0, 0, 2.5), 0.8, GOLD, 0.3),
        Wait(0.4),
    ]
    return Skill("Toll Wave", key=3, cooldown=9, line=line, branches=br, props=BASE(),
                 tooltip="Hold: Sustained Note")


# ========================================================= 4  BELL TOLL ====
def _crater(z: float = 5, scale: float = 1.0):
    """Ground impact: ripple, bell ring, lingering cracks, rock sound."""
    return [ripple(1.6 * scale, time=0.8), *bell_ring(1.2 * scale, z=z),
            Visual("Mesh", amount=M.CRACKS, time=4, size=0.35 * scale, alt_size=1, col=DUSK,
                   opacity=0, alt_opacity=1, pos=(0, GROUND + 0.05, z), rot=(90, 0, 0),
                   ease="Exponential", ease_dir="In"),
            Sfx(S.ROCK_IMPACT, vol=2)]


def _rising_palm(target: str, branch: str):
    return [
        State("NoM1", 1.1), State("NoJump", 1.1), State("NoSprint", 1.1),
        Sfx(S.WHOOSH_FAST, vol=1.6), Sfx(S.CURSED_STRIKE_STARTUP, vol=1.6),
        Anim(A.M1_UP, speed=0.9),                       # strike at ~0.22 s
        trail("Right Arm", 0.45), trail("Left Arm", 0.45),
        Velo((0, 0, 18), 0.1),
        Wait(0.22),
        Hitbox(4, size=(8, 9, 8), pos=(0, 1, 4), stun=1.2, stun_anim=True, branch=branch,
               target=target),
        HitCancel("miss", time=0.1, missed=True),
    ]


def build_bell_toll():
    """Move 4 (★): rising palm launches, a spectral bell slams the target back down.
    Knell: a giant bell crushes them into a crater."""
    br = {}
    slam_rest = [
        Anim(A.CLAP_1), Sfx(S.CLAP, vol=2), chime(0.8, vol=1.6),
        light(HRP, 12, 3, 0.4),
        Wait(0.3),
        Hitbox(6, size=(12, 22, 12), pos=(0, 9, 5), stun=1.0, stun_anim=True, hit_ragdoll=True,
               ignore_wakeup=True, blockable=False, target="slammed"),
        *gong("medium", 2.0), shake("Medium", 0.45, 4), fov(-8, 0.4),
        Wait(0.2),
        ripple(0.9, time=0.6), *bell_ring(0.7, z=5),
        Wait(0.15),
    ]
    gl, gb = toll_gain("bt", slam_rest)
    br.update(gb)
    br["launched"] = Br([Sfx(S.PUNCH_3, vol=2.2), shake("Light", 0.3, 2)] + gl)
    br["up"] = Br([Velo((0, 55, 4), 0.12, rel_branch=True, ragdoll=1.6), *burst(1.0),
                   Sfx(S.HIT_KICK_H, vol=1.8)])
    br["slammed"] = Br([*bell(0.9, drop=6, time=0.35, op=0.4, ease="Quad", ease_dir="In"),
                        *burst(1.3), Sfx(S.HEAVY_HIT, vol=2),
                        Velo((0, -90, 0), 0.15, rel_branch=True, ragdoll=1.3)])
    br["miss"] = Br([State("Stun", 0.45), Anim(A.M1_UP, start=0.2, speed=0.5), Wait(0.35)])
    # ---- Knell: the giant bell -------------------------------------------
    br["knell"] = Br(_rising_palm("up", "klaunched"))
    br["klaunched"] = Br([
        Sfx(S.PUNCH_3, vol=2.2), *toll_reset(),
        Anim(A.CLAP_3), Sfx(S.CLAP, vol=2.2), Sfx(S.AMP_IGNITION, vol=1.6),
        aura(HRP, 1.6, 0.6, GOLD, JADE, op=0.2, hold=False), glow(0.5, GOLD, 0.4),
        light(HRP, 18, 4, 0.6),
        Wait(0.3),
        Hitbox(14, size=(14, 24, 14), pos=(0, 9, 5), stun=1.2, stun_anim=True,
               hit_ragdoll=True, ignore_wakeup=True, blockable=False, debree=6,
               target="crushed", finisher="fin"),
        *gong("big", 2.4), shake("Heavy", 0.7, 6), fov(-14, 0.5), flash(PALE, 0.08),
        Awaken(10),
        Wait(0.2),
        *_crater(5),
        Wait(0.3),
    ])
    br["fin"] = funeral_toll([*gong("big", 2.4), shake("Heavy", 0.7, 6), flash(PALE, 0.08),
                              *_crater(5)])
    br["crushed"] = Br([*bell(1.35, drop=10, time=0.3, op=0.35, ease="Quad", ease_dir="In"),
                        *burst(2.0), Sfx(S.IMPACT_FRAMES, vol=2),
                        Velo((0, -110, 0), 0.2, rel_branch=True, ragdoll=2.0)])
    line = [TagCheck(TOLL, "3", "knell")] + _rising_palm("up", "launched")
    return Skill("Bell Toll", key=4, cooldown=14, line=line, branches=br, props=BASE(),
                 tooltip="★ Knell at 3 Tolls: the giant bell")


# ================================================== R  STRIKE THE BELL ====
def _grand_knell(consume: bool):
    """A colossal bell drops around the user and rings everyone inside upward."""
    return ([*toll_reset()] if consume else [SetCooldown(-1, 12)]) + [
        State("IFrame", 0.6), State("NoM1", 1.1), State("NoJump", 1.1), State("NoSprint", 1.1),
        Anim(A.CLAP_3), Sfx(S.CLAP, vol=2.4), Sfx(S.AMP_IGNITION, vol=1.8),
        glow(0.4, GOLD, 0.35), aura(HRP, 1.8, 0.8, GOLD, JADE, op=0.15, hold=False),
        *bell(2.2, drop=18, time=0.35, op=0.35, ease="Quad", ease_dir="In"),
        Wait(0.35),
        *gong("big", 2.6), shake("Heavy", 0.8, 6), fov(-14, 0.55), flash(PALE, 0.08),
        Hitbox(12, size=(30, 14, 30), pos=(0, 1, 0), stun=1.2, stun_anim=True, hit_ragdoll=True,
               ignore_wakeup=True, blockable=False, debree=4, target="knelled", finisher="fin"),
        *bell(2.2, time=0.7, op=0.35, grow=1.12, ease="Exponential", ease_dir="Out"),
        *bell_ring(2.0), ripple(2.4, time=0.9),
        Awaken(12),
        Wait(0.5),
    ]


def build_special():
    """R (★): resonant clap pulse; at 3 Tolls (or awakened) the Grand Knell."""
    br = {}
    gl, gb = toll_gain("pt", [SetMelee(0, 1.5), Wait(0.3)])
    br.update(gb)
    br["rung"] = Br([Sfx(S.PUNCH_1, vol=1.8), chime(1.2, vol=1.4), *spark(0.8),
                     Velo((0, 1, 8), 0.1, rel_branch=True)])
    br["whiff"] = Br([Wait(0.3)])
    br["grand"] = Br(_grand_knell(consume=True))
    br["awk"] = Br(_grand_knell(consume=False), req=[ULT()])
    br["fin"] = funeral_toll([*bell(2.2, time=0.7, op=0.35, grow=1.12, ease="Exponential",
                                    ease_dir="Out"), *bell_ring(2.0), ripple(2.4, time=0.9)])
    br["knelled"] = Br([Velo((0, 60, 0), 0.15, rel_branch=True, ragdoll=1.6), *burst(1.4),
                        Sfx(S.HEAVY_HIT, vol=2), *bell(1.0, time=0.4, op=0.5, grow=1.2,
                                                      ease="Exponential", ease_dir="Out")])
    line = [
        Branch("awk"),
        TagCheck(TOLL, "3", "grand"),
        State("NoM1", 0.45), State("NoJump", 0.45),
        Anim(A.CLAP_2), Sfx(S.CLAP, vol=2), chime(1.0, vol=1.5),
        Wait(0.15),
        ripple(0.7, time=0.45), sound_ring((0, 0, 0), 1.2, GOLD, 0.35, forward=False),
        Visual("Wind Ring", time=0.4, size=1.2, alt_size=2.5, amount=3, col=GOLD, alt_col=PALE,
               opacity=0.8, alt_opacity=1),
        light(HRP, 12, 3, 0.3),
        Hitbox(2, size=(13, 8, 13), pos=(0, 0, 1), stun=0.8, stun_anim=True, target="rung"),
        HitCancel("whiff", time=0.1, missed=True, endlag=0.25),
    ] + gl
    return Special("Strike the Bell", 7, line, br,
                   notes="Base: clap pulse. 3 Tolls: Grand Knell (consumes). Awakened: always "
                         "Grand Knell, 12 s cooldown.")


# ===================================================== AWAKENING (G) ====
AWK_DURATION = 100
AWK_FX = "BR_AWKFX"


def build_awakening():
    """Joya no Kane - the bell is struck 108 times to dispel the 108 desires."""
    hold_time = AWK_DURATION
    br = {"awk_push": Br([Velo((0, 45, 0), 0.15, rel_branch=True, ragdoll=1.4), *burst(1.3),
                          Sfx(S.HEAVY_HIT, vol=1.8)])}
    line = [
        State("IFrame", 2.4), State("Stun", 2.1), State("NoM1", 2.2), State("NoJump", 2.2),
        *toll_reset(),
        Anim(A.VESSEL_ULT),
        Sfx(S.HOLLOW_GONG, vol=2.2, end=2.5, fade_out=1.0, global_=True),
        Sfx(S.AMP_IGNITION, vol=2), chime(0.7, vol=2),
        glow(1.0, GOLD, 0.4), flash(DUSK, 0.6), fov(8, 1.0),
        aura(HRP, 1.6, 1.0, GOLD, JADE, op=0.2, hold=False), light(HRP, 20, 3, 1.0),
        *bell(2.4, drop=30, time=1.0, op=0.4, ease="Quad", ease_dir="In"),
        Wait(1.0),
        # --- first toll: the bell lands over the Bellringer -------------------
        *gong("huge", 2.6, global_=True), shake("Heavy", 1.0, 7), flash(PALE, 0.1),
        fov(-16, 0.6),
        Hitbox(5, size=(26, 12, 26), pos=(0, 1, 0), stun=1.0, stun_anim=True, blockable=False,
               ignore_wakeup=True, target="awk_push"),
        *bell(2.4, time=1.1, op=0.4, grow=1.08, ease="Exponential", ease_dir="Out"),
        *bell_ring(2.4), ripple(3.0, time=1.0),
        Wait(0.6),
        # --- the tolls keep coming ----------------------------------------------
        chime(0.9, vol=2), sound_ring((0, 1, 0), 2.0, GOLD, 0.5, forward=False),
        ripple(1.6, col=JADE, time=0.6),
        Wait(0.3),
        chime(1.1, vol=2), sound_ring((0, 2, 0), 2.4, JADE, 0.5, forward=False),
        ripple(2.0, col=GOLD, time=0.6),
        Wait(0.3),
        # --- the aura that lasts the whole awakening ------------------------------
        CancelVisual(AWK_FX),
        aura(HRP, 1.3, hold_time, GOLD, JADE, op=0.35, vtag=AWK_FX),
        aura("Right Arm", 0.7, hold_time, GOLD, JADE, op=0.3, vtag=AWK_FX),
        aura("Left Arm", 0.7, hold_time, GOLD, JADE, op=0.3, vtag=AWK_FX),
        light(HRP, 16, 1.5, hold_time, GOLD, hold=True, vtag=AWK_FX),
        light("Right Arm", 7, 1.8, hold_time, PALE, hold=True, vtag=AWK_FX),
        light("Left Arm", 7, 1.8, hold_time, PALE, hold=True, vtag=AWK_FX),
    ]
    return Awakening("Joya no Kane: 108 Tolls", AWK_DURATION, line, br,
                     props=Props(invincible=True, no_cancel=True), req=[BAR(99)],
                     delay=2.2, color="255,196,92 92,224,186")


# ============================================ U1  HUNDREDFOLD STRIKES ====
def build_hundredfold():
    """Awakened 1: lunge-catch, hold, 10 chiming palms, gong palm launcher."""
    br = {}
    pair = [   # two palms per loop pass, each with its own sound
        Hitbox(1.4, size=(8, 8, 8), pos=(0, 0, 4.5), stun=0.6, stun_anim=True, blockable=False,
               ignore_wakeup=True, target="fl_a"),
        Sfx(S.PUNCH_1, vol=1.8, speed=1.1), Wait(0.15),
        Hitbox(1.4, size=(8, 8, 8), pos=(0, 0, 4.5), stun=0.6, stun_anim=True, blockable=False,
               ignore_wakeup=True, target="fl_b"),
        Sfx(S.PUNCH_2, vol=1.8, speed=1.05), chime(1.3, vol=1.0), Wait(0.15),
    ]
    br["flurry"] = Br([
        Velo((0, 0.01, 0), 0.05), Sfx(S.PUNCH_3, vol=2.2), shake("Light", 0.3, 2),
        Grab(time=1.7, pos=(0, 0, 4.5), rot=(0, 180, 0), last_hit=1),   # releases before the gong
        Anim(A.RAPID_PUNCHES, end=2.2, speed=1.1),
        trail("Right Arm", 1.6, JADE), trail("Left Arm", 1.6, GOLD),
        aura(HRP, 1.4, 1.6, GOLD, JADE, op=0.25, hold=False),
        *pair, Loop(len(pair), 4),                              # 5 passes = 10 palms
        Anim(A.DIVERGENT_1, start=0.25, speed=1.3), Sfx(S.CURSED_STRIKE_STARTUP, vol=1.8),
        light("Right Arm", 10, 4, 0.4),
        Wait(0.25),
        Hitbox(8, size=(9, 9, 9), pos=(0, 0, 4.5), stun=1.2, stun_anim=True, blockable=False,
               ignore_wakeup=True, target="gonged", finisher="fin"),
        *gong("big", 2.4), shake("Heavy", 0.6, 5), fov(-12, 0.45), flash(PALE, 0.07),
        Wait(0.4),
    ])
    br["fin"] = funeral_toll([*gong("big", 2.4), shake("Heavy", 0.6, 5), flash(PALE, 0.07)])
    br["caught"] = Br([Sfx(S.PUNCH_3, vol=2), *spark(1.0, col=JADE)])
    br["fl_a"] = Br([*spark(0.7, col=GOLD), Velo((0, 0, 1), 0.05, rel_branch=True)])
    br["fl_b"] = Br([*spark(0.7, col=JADE), sound_ring((0, 0, 0), 0.6, JADE, 0.2)])
    br["gonged"] = Br([*bell(0.9, time=0.4, op=0.4, grow=1.15, ease="Exponential",
                             ease_dir="Out"), *burst(1.8), *bell_ring(0.8),
                       Velo((0, 15, 70), 0.15, rel_branch=True, ragdoll=1.4)])
    line = [
        State("NoM1", 0.9), State("NoJump", 0.9), State("NoSprint", 0.9),
        Sfx(S.CURSED_STRIKE_STARTUP, vol=1.8), chime(0.9, vol=1.4),
        Anim(A.DIVERGENT_3, speed=1.4), afterimage(0.4, JADE),
        trail("Right Arm", 0.5, JADE), light("Right Arm", 9, 3, 0.4, JADE),
        Wait(0.12),
        Sfx(S.WHOOSH_FAST, vol=1.5), Velo((0, 0, 95), 0.25, fade=True, track=True),
        Wait(0.06),
        *_lunge_checks(3, (8, 8, 9), (0, 0, 3.5), 1.5, "flurry", "caught", checks=4,
                       blockable=True),
        Velo((0, 0.01, 0), 0.05), State("Stun", 0.45), Wait(0.4),
    ]
    return Skill("Hundredfold Strikes", key=1, cooldown=14, line=line, branches=br,
                 props=AWAKENED(), tooltip="Catch, then 10 palms and a gong")


# ============================================ U2  KANEMAKI (DOJO-JI) ====
PRISON_FX = "BR_PRISON"


def _bell_strike(clip, start, wait_hit, dmg, target, pitch, size="medium", finisher=None):
    return [
        Anim(clip, start=start, speed=0.9), Sfx(S.SWING, vol=1.6, speed=0.9),
        trail("Right Arm", 0.4, GOLD),
        Wait(wait_hit),
        Hitbox(dmg, size=(10, 10, 10), pos=(0, 0, 7), stun=1.3, stun_anim=True,
               blockable=False, ignore_wakeup=True, hit_ragdoll=True, target=target,
               finisher=finisher),
        *gong(size, 2.2), chime(pitch, vol=1.6), shake("Medium", 0.4, 4), fov(-6, 0.3),
        *bell_ring(1.1, z=7), light(HRP, 16, 3, 0.3, GOLD, pos=(0, 2, 7)),
    ]


def build_kanemaki():
    """Awakened 2: drop a bell on the target, strike it three times, shatter it."""
    br = {}
    br["inside"] = Br([Velo((0, 0.01, 0), 0.05), *spark(1.0), Sfx(S.HEAVY_HIT, vol=1.8)])
    for i in (1, 2):
        br[f"rung{i}"] = Br([Visual("Distortion", time=0.3, size=4, alt_size=1.4, amount=1,
                                    opacity=0, alt_opacity=1), *spark(1.0 + 0.2 * i),
                             aura(HRP, 1.0, 0.5, GOLD, JADE, op=0.3, hold=False)])
    br["shatter"] = Br([*burst(2.0), Sfx(S.GLASS_BREAK, vol=2), Sfx(S.IMPACT_FRAMES, vol=2),
                        Velo((0, 25, 60), 0.15, rel_branch=True, ragdoll=1.6)])
    shatter = [CancelVisual(PRISON_FX), Sfx(S.GLASS_BREAK, vol=1.8, speed=0.8),
               *bell(1.3, z=7, time=0.35, op=0.3, grow=1.35, ease="Exponential", ease_dir="Out"),
               flash(PALE, 0.08), shake("Heavy", 0.6, 6)]
    br["trapped"] = Br([
        Grab(time=1.8, pos=(0, 0, 7), rot=(0, 180, 0), last_hit=1),   # releases just before the shatter
        CancelVisual(PRISON_FX),
        *bell(1.3, z=7, time=2.4, op=0.3, fade=False, vtag=PRISON_FX),
        Sfx(S.CHURCH_BELL_SOFT, vol=1.6, end=2, fade_out=0.6),
        Wait(0.25),
        *_bell_strike(A.M1_1, 0, 0.2, 5, "rung1", 1.0, finisher="fin"), Wait(0.45),
        *_bell_strike(A.M1_3, 0, 0.2, 5, "rung2", 1.15, finisher="fin"), Wait(0.45),
        *_bell_strike(A.DIVERGENT_1, 0.25, 0.3, 7, "shatter", 1.3, size="big", finisher="fin"),
        *shatter,
        Wait(0.4),
    ])
    br["fin"] = funeral_toll(shatter)
    line = [
        State("NoM1", 1.0), State("NoJump", 1.0), State("NoSprint", 1.0),
        Anim(A.CLAP_1), Sfx(S.CLAP, vol=2.2), chime(0.8, vol=1.6),
        glow(0.3, GOLD, 0.5), light(HRP, 12, 3, 0.4),
        Wait(0.2),
        *bell(1.3, z=8, drop=16, time=0.3, op=0.35, ease="Quad", ease_dir="In"),
        Wait(0.3),
        *gong("medium", 2.2), shake("Medium", 0.4, 4),
        Hitbox(5, size=(12, 12, 12), pos=(0, 0, 8), stun=1.4, stun_anim=True, blockable=False,
               ignore_wakeup=True, hit_ragdoll=True, branch="trapped", target="inside"),
        *bell(1.3, z=8, time=0.45, op=0.35, grow=1.05),
        *bell_ring(1.0, z=8),
        Wait(0.35), State("Stun", 0.3), Wait(0.3),
    ]
    return Skill("Kanemaki", key=2, cooldown=20, line=line, branches=br, props=AWAKENED(),
                 tooltip="The Bell of Dojo-ji: trap, strike thrice, shatter")


# =========================================== U3  SYMPATHETIC CASCADE ====
def _cascade_ring(n: int, width: float, dmg: float, stun: float, target: str, col):
    scale = width / 16.0
    return [
        *gong("small" if n < 3 else "medium", 1.8 + 0.2 * n), chime(0.9 + 0.15 * n, vol=1.6),
        Hitbox(dmg, size=(width, 6, width), pos=(0, -1, 0), stun=stun, stun_anim=True,
               blockable=False, hit_ragdoll=True, ignore_wakeup=True, target=target),
        Visual("Cylinder", time=0.5, size=1, alt_size=1, size2=(0.3, 2, 2),
               alt_size2=(0.05, width * 1.1, width * 1.1), col=col, alt_col=PALE, opacity=0.25,
               alt_opacity=1, pos=(0, GROUND + 0.1, 0), rot=(0, 0, 90), ease="Exponential",
               ease_dir="Out"),
        Visual("Mesh", amount=M.SOUND_RIPPLE, time=0.7, size=0.4 * scale, alt_size=3, col=col,
               alt_col=PALE, opacity=0.3, alt_opacity=1, pos=(0, GROUND + 0.4, 0),
               ease="Exponential", ease_dir="Out"),
        Visual("Mesh", amount=M.THIN_RINGS, time=0.6, size=0.5 * scale, alt_size=8, col=col,
               alt_col=PALE, opacity=0.4, alt_opacity=1, pos=(0, GROUND + 1, 0),
               ease="Exponential", ease_dir="Out"),
        shake("Medium" if n < 3 else "Heavy", 0.35, 3 + n),
    ]


def build_cascade():
    """Awakened 3: stomp, three expanding resonance rings."""
    br = {f"w{i}": Br([*spark(0.9, col=JADE if i % 2 else GOLD),
                       Visual("Distortion", time=0.2, size=3, alt_size=1.3, amount=1, opacity=0,
                              alt_opacity=1), Sfx(S.PUNCH_1, vol=1.6)]) for i in (1, 2)}
    br["w3"] = Br([*burst(1.3), Velo((0, 32, 0), 0.12, rel_branch=True, ragdoll=1.1),
                   Sfx(S.HEAVY_HIT, vol=1.8)])
    line = [
        State("NoM1", 1.6), State("NoJump", 1.6), State("NoSprint", 1.6),
        State("DirectionLock", 1.4),
        Anim(A.EARTHQUAKE),                                   # stomp lands at ~0.49 s
        Sfx(S.EARTHQUAKE_START, vol=1.8), chime(0.7, vol=1.6),
        aura(HRP, 1.4, 0.6, GOLD, JADE, op=0.25, hold=False), glow(0.4, JADE, 0.5),
        light(HRP, 14, 3, 0.6, JADE),
        Wait(0.45),
        Sfx(S.EARTHQUAKE, vol=2), Sfx(S.ROCK_IMPACT, vol=1.8), flash(PALE, 0.05),
        Visual("Mesh", amount=M.CRACKS, time=3, size=0.25, alt_size=1, col=DUSK, opacity=0,
               alt_opacity=1, pos=(0, GROUND + 0.05, 0), rot=(90, 0, 0),
               ease="Exponential", ease_dir="In"),
        *_cascade_ring(1, 16, 4, 0.9, "w1", GOLD),
        Wait(0.3),
        *_cascade_ring(2, 30, 4, 0.9, "w2", JADE),
        Wait(0.3),
        *_cascade_ring(3, 44, 5, 1.2, "w3", GOLD),
        fov(-10, 0.4),
        Wait(0.4),
    ]
    return Skill("Sympathetic Cascade", key=3, cooldown=16, line=line, branches=br,
                 props=AWAKENED(), tooltip="Three expanding resonance rings")


# ================================================ U4  THE 108TH TOLL ====
def build_108th_toll():
    """Awakened 4: palm thrust; on hit, a colossal bell descends, the tolls ring
    in a heartbeat and the 108th detonates."""
    tick = [Hitbox(1, size=(8, 8, 8), pos=(0, 0, 6), stun=1.0, stun_anim=True, blockable=False,
                   ignore_wakeup=True, hit_ragdoll=True, target="tick"),
            chime(1.25, vol=1.1), sound_ring((0, 2, 6), 1.1, GOLD, 0.2, forward=False),
            Wait(0.1),
            chime(1.4, vol=0.9), sound_ring((0, 3, 6), 1.3, JADE, 0.2, forward=False),
            Wait(0.1)]
    br = {
        "held": Br([Sfx(S.PUNCH_3, vol=2.2), *spark(1.2), aura(HRP, 1.0, 2.0, GOLD, JADE, op=0.3,
                                                             hold=False)]),
        "tick": Br([*spark(0.6, col=JADE), Visual("Distortion", time=0.15, size=3, alt_size=1.2,
                                                  amount=1, opacity=0, alt_opacity=1)]),
        "final": Br([*burst(2.5), *bell(1.0, time=0.5, op=0.4, grow=1.4, ease="Exponential",
                                        ease_dir="Out"),
                     Velo((0, 40, 90), 0.2, rel_branch=True, ragdoll=2.5),
                     Sfx(S.IMPACT_FRAMES, vol=2.2)]),
        "miss": Br([Anim(A.PIERCING_BLOOD, start=0.7, speed=1.0), Wait(0.5)]),
    }
    after = [*bell(3.2, z=3, time=0.9, op=0.35, grow=1.25, ease="Exponential", ease_dir="Out"),
             *bell_ring(3.0, z=6), ripple(3.5, time=1.0),
             Visual("Mesh", amount=M.CRACKS, time=5, size=0.45, alt_size=1, col=DUSK, opacity=0,
                    alt_opacity=1, pos=(0, GROUND + 0.05, 6), rot=(90, 0, 0),
                    ease="Exponential", ease_dir="In")]
    br["toll108"] = Br([
        State("IFrame", 2.6), Grab(time=1.8, pos=(0, 0, 6), rot=(0, 180, 0), last_hit=1),
        flash(DUSK, 0.6), fov(10, 1.2),
        Sfx(S.CHURCH_TOLLING, vol=2.2, end=2.6, fade_out=0.8, global_=True),
        Anim(A.HOLLOW_PURPLE, end=2.2, speed=1.2),
        aura(HRP, 1.8, 2.0, GOLD, JADE, op=0.2, hold=False), light(HRP, 22, 4, 2.0),
        *bell(3.2, z=3, drop=40, time=1.6, op=0.35, ease="Quad", ease_dir="In"),
        *tick, Loop(len(tick), 6),                         # 7 tolls x 0.2 s, 1 dmg each
        Wait(0.2),
        Anim(A.DIVERGENT_1, start=0.25, speed=1.2), Sfx(S.CURSED_STRIKE_STARTUP, vol=2),
        Wait(0.25),
        # --- the 108th toll ----------------------------------------------------
        *gong("huge", 2.8, global_=True),
        flash(IVORY, 0.12), shake("Heavy", 1.2, 9), fov(-20, 0.7),
        Hitbox(15, size=(14, 14, 14), pos=(0, 0, 6), stun=1.5, stun_anim=True, blockable=False,
               ignore_wakeup=True, hit_ragdoll=True, debree=8, target="final", finisher="fin"),
        *after,
        Wait(0.6),
    ])
    br["fin"] = funeral_toll(after)
    line = [
        State("NoM1", 1.0), State("NoJump", 1.0), State("NoSprint", 1.0),
        State("DirectionLock", 0.45),
        Anim(A.PIERCING_BLOOD, speed=1.6),                   # thrust at ~0.42 s
        Sfx(S.ENERGY_WINDUP, vol=2), chime(0.6, vol=1.8),
        glow(0.45, GOLD, 0.4), aura(HRP, 1.4, 0.5, GOLD, JADE, op=0.25, hold=False),
        light("Right Arm", 10, 4, 0.5), light("Left Arm", 10, 4, 0.5),
        Wait(0.4),
        Hitbox(4, size=(8, 8, 9), pos=(0, 0, 4), stun=2.0, stun_anim=True, branch="toll108",
               target="held"),
        HitCancel("miss", time=0.1, missed=True, endlag=0.6),
    ]
    return Skill("The 108th Toll", key=4, cooldown=30, line=line, branches=br,
                 props=AWAKENED(), tooltip="Finisher: the bell tolls 108 times")


# ============================================================ MILESTONES ====
def milestone_entries(stage: int):
    """Entries included at each milestone (cumulative)."""
    entries = [build_spawn(), build_m1(1), build_m1(2), build_m1(3), build_m4(),
               build_dash(polish=stage >= 12)]
    if stage >= 2:
        entries.append(build_striking_log())
    if stage >= 3:
        entries.append(build_reverb_palm())
    if stage >= 4:
        entries.append(build_toll_wave())
    if stage >= 5:
        entries.append(build_bell_toll())
    if stage >= 6:
        entries.append(build_special())
    if stage >= 7:
        entries.append(build_awakening())
    if stage >= 8:
        entries.append(build_hundredfold())
    if stage >= 9:
        entries.append(build_kanemaki())
    if stage >= 10:
        entries.append(build_cascade())
    if stage >= 11:
        entries.append(build_108th_toll())
    return entries


MILESTONES = [
    (1, "0.1", "M1s, dash and the Toll system"),
    (2, "0.2", "Move 1 - Striking Log (hold + air variants)"),
    (3, "0.3", "Move 2 - Reverb Palm (delayed echo, Knell)"),
    (4, "0.4", "Move 3 - Toll Wave (projectile, hold variant)"),
    (5, "0.5", "Move 4 - Bell Toll (launcher, Knell)"),
    (6, "0.6", "R - Strike the Bell / Grand Knell"),
    (7, "0.7", "Awakening - Joya no Kane: 108 Tolls"),
    (8, "0.8", "Ultimate 1 - Hundredfold Strikes"),
    (9, "0.9", "Ultimate 2 - Kanemaki, the Bell of Dojo-ji"),
    (10, "0.10", "Ultimate 3 - Sympathetic Cascade"),
    (11, "0.11", "Ultimate 4 - The 108th Toll"),
    (12, "1.0", "Release: awakened dash, kill flourish, verified combo guide"),
]


LOCKOUTS = {"NoM1", "NoJump", "NoSprint", "DirectionLock", "SpeedMultiplier"}


def end_lockouts_with_skill(entry):
    """Policy: in moves (not M1s), lockout states never outlive the move.
    STATE nodes default to CANCEL ON END = false, so a 0.75 s NoM1 on a move
    that recovers at 0.56 s would otherwise delay the M1 follow-up."""
    if entry.kind == "MELEE":
        return entry
    lines = [entry.line] + [b.line for b in entry.branches.values()]
    for line in lines:
        for n in line:
            if n.get("K_NAME") == "STATE" and n.get("STATE") in LOCKOUTS and not n.get("CHECK"):
                n["CANCEL ON END"] = True
    return entry


def build(stage: int) -> Character:
    version = dict((s, v) for s, v, _ in MILESTONES)[stage]
    ch = Character(NAME, version)
    ch.add(*[end_lockouts_with_skill(e) for e in milestone_entries(stage)])
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
    add("3 Toll Wave (point blank)", "Toll Wave", {})
    add("3 Sustained Note (hold)", "Toll Wave", {"branch:hold": True})
    add("4 Bell Toll (launch + bell slam, ragdoll)", "Bell Toll",
        {"hit": "launched", "tag:BR_TOLL": "bt_1"})
    add("4 Bell Toll (whiff)", "Bell Toll", {"miss": "miss", **W})
    add("4 ★ Knell Bell Toll (ragdoll)", "Bell Toll", {"tag:BR_TOLL": "knell", "hit": "klaunched"})
    add("R Strike the Bell (pulse hit)", "Strike the Bell", {"tag:BR_TOLL": "pt_1"})
    add("R Strike the Bell (whiff)", "Strike the Bell", {"miss": "whiff", **W})
    add("R ★ Grand Knell (ragdoll)", "Strike the Bell", {"tag:BR_TOLL": "grand"})
    add("U1 Hundredfold Strikes (ragdoll)", "Hundredfold Strikes", {"hit": "flurry"})
    add("U1 Hundredfold Strikes (whiff)", "Hundredfold Strikes", W)
    add("U2 Kanemaki (trapped, ragdoll)", "Kanemaki", {"hit": "trapped"})
    add("U2 Kanemaki (whiff)", "Kanemaki", W)
    add("U3 Sympathetic Cascade (all rings)", "Sympathetic Cascade", {})
    add("U4 The 108th Toll (hit, ragdoll)", "The 108th Toll", {"hit": "toll108"})
    add("U4 The 108th Toll (whiff)", "The 108th Toll", {"miss": "miss", **W})
    return rows


def combo_routes(ch: Character):
    """The documented combos as data. Each is simulated with analyze.check_combo
    against the real timelines; the build fails if one stops working."""
    doc = {e.name: e.to_json() for e in ch.entries}

    def P(ename, take=None):
        return analyze.entry_paths(doc[ename], {"x": take or {}})["x"]

    Step = analyze.ComboStep

    def m1(i, awk=False):
        take = {"branch:awk": True} if awk else ({"tag:BR_TOLL": "t_1"} if i == 2 else {})
        return Step(f"M1 #{i}", P(f"Palm {i}", take), is_m1=True)

    def m4(kind="normal", awk=False):
        p = "a" if awk else ""
        return Step({"normal": "M4", "up": "M4 ↑ uptilt", "down": "M4 ↓ downslam"}[kind],
                    P("Gong Palm", {f"branch:{p}{kind}": True, "tag:BR_TOLL": f"{kind}t_1"}),
                    is_m1=True)

    def mv(label, ename, take=None, delay=0.0):
        return Step(label, P(ename, take), delay=delay)

    m1x3 = [m1(1), m1(2), m1(3)]
    am1x3 = [m1(1, True), m1(2, True), m1(3, True)]
    log = lambda: mv("1 Striking Log", "Striking Log", {"hit": "hit"})  # noqa: E731
    wave = lambda: mv("3 Toll Wave (OTG)", "Toll Wave")                   # noqa: E731
    fall = lambda: mv("jump → 1 Falling Log", "Striking Log",              # noqa: E731
                      {"branch:air": True, "hit": "ahit"}, delay=0.25)
    routes = []
    if "Reverb Palm" in doc:
        routes.append(("First Toll — BnB", "Base", "Any Tolls. Ends with 2 Tolls.",
                       m1x3 + [mv("2 Reverb Palm (echo)", "Reverb Palm", {"tag:BR_TOLL": "rt_1"})]
                       + [m1(1), m1(2), m1(3), m4(), log()]))
    if "Bell Toll" in doc and "Toll Wave" in doc:
        routes.append(("Rising Knell", "Base", "Launcher route; the wave picks them up off the "
                       "floor.", m1x3 + [mv("4 Bell Toll", "Bell Toll", {"hit": "launched",
                                                                         "tag:BR_TOLL": "bt_1"}),
                                         wave()]))
        routes.append(("Bell Drop", "Base", "Uptilt into an air spike.",
                       m1x3 + [m4("up"), fall(), wave()]))
    if "Strike the Bell" in doc and "Reverb Palm" in doc:
        routes.append(("Clap Chain", "Base", "R pulse resets the M1 string.",
                       m1x3 + [mv("R Strike the Bell", "Strike the Bell", {"tag:BR_TOLL": "pt_1"})]
                       + m1x3 + [mv("2 Reverb Palm (echo)", "Reverb Palm",
                                    {"tag:BR_TOLL": "rt_1"})]))
    if "Strike the Bell" in doc and "Toll Wave" in doc:
        routes.append(("Grand Knell", "Base, 3 Tolls", "Spend the Knell on R, chase the launch.",
                       m1x3 + [mv("R ★ Grand Knell", "Strike the Bell", {"tag:BR_TOLL": "grand"}),
                               fall(), wave()]))
    if "Reverb Palm" in doc and "Toll Wave" in doc:
        routes.append(("Thrice-Rung", "Base, from 0 Tolls", "Builds exactly 3 Tolls (M1 #2, Log, "
                       "M1 #2) and cashes them in the same combo.",
                       [m1(1), m1(2), log(), m1(1), m1(2), m1(3),
                        mv("2 ★ Knell Reverb Palm", "Reverb Palm", {"tag:BR_TOLL": "knell"}),
                        wave()]))
    if "Hundredfold Strikes" in doc and "Sympathetic Cascade" in doc:
        routes.append(("Hundred Tolls", "Awakened", "",
                       am1x3 + [mv("U1 Hundredfold Strikes", "Hundredfold Strikes",
                                   {"hit": "flurry"}),
                                mv("U3 Sympathetic Cascade (OTG)", "Sympathetic Cascade")]))
    if "Kanemaki" in doc and "Sympathetic Cascade" in doc:
        routes.append(("Dōjō-ji", "Awakened", "The bell drops over the body the cascade threw.",
                       am1x3 + [mv("U3 Sympathetic Cascade", "Sympathetic Cascade"),
                                mv("U2 Kanemaki (OTG capture)", "Kanemaki", {"hit": "trapped"})]))
    if "The 108th Toll" in doc:
        routes.append(("One Hundred and Eight", "Awakened", "The finisher.",
                       am1x3 + [mv("U4 The 108th Toll", "The 108th Toll", {"hit": "toll108"})]))
    return routes


def write_combos(ch: Character, path: str):
    out = [f"# Combos — {NAME} v{ch.version}", "",
           "Every route below is simulated from the real timelines by "
           "`jjsforge.analyze.check_combo` on each build (the build fails if one breaks). "
           "Each step starts the moment the previous one recovers. *True combo* = the first hit "
           "lands while the target is still in hitstun (spare time shown); *OTG* = it lands on a "
           "ragdolled target with a hitbox that can hit ragdolls. Assumes the target is in range "
           "(lunges and pulls handle most spacing) and no burst/evasive is used.", ""]
    broken = []
    for name, mode, note, steps in combo_routes(ch):
        rows, total, ok = analyze.check_combo(steps)
        out += [f"## {name}  ·  _{mode}_", ""] + ([note, ""] if note else [])
        out += [analyze.combo_table(" → ".join(s.label for s in steps), rows, total, ok), ""]
        if not ok:
            broken.append(name)
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")
    return broken


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
        broken = write_combos(ch, os.path.join(HERE, "COMBOS.md"))
        if broken:
            raise SystemExit(f"documented combos broke: {broken}")
        print("combos verified:", len(combo_routes(ch)))


if __name__ == "__main__":
    main()
