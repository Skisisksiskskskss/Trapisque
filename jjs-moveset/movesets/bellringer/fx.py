"""Bellringer look & sound kit: palette, sound layers and composite VFX.

All parameters stay inside the ranges creators use for each built-in effect
(see docs/FORMAT.md), so effects read well even though they are authored
outside the game. Cylinder / Sphere effects are sized in studs; ALT SIZE is a
multiplier, ALT SIZE 2 an absolute size.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))

from jjsforge.assets import MESH as M  # noqa: E402
from jjsforge.assets import SFX as S  # noqa: E402
from jjsforge.nodes import Sfx, Visual  # noqa: E402

# ------------------------------------------------------------- palette ----
GOLD = (255, 196, 92)       # bell bronze, lit
PALE = (255, 233, 176)      # bell shine
BRONZE = (196, 122, 48)     # cast bronze
JADE = (92, 224, 186)       # verdigris patina
IVORY = (255, 246, 228)
EMBER = (255, 146, 54)
DUSK = (70, 40, 14)

HRP = "HumanoidRootPart"
GROUND = -2.9                # HumanoidRootPart -> floor offset


# --------------------------------------------------------------- sound ----
def tok(i: int = 1, vol: float = 1.3):
    """Wooden temple-block tap layered under light hits."""
    return Sfx(S.TEMPLE_BLOCK_1, vol=vol, speed=0.9 + 0.1 * i)


def chime(pitch: float = 1.0, vol: float = 1.6, **kw):
    """Small cast-iron temple bell."""
    return Sfx(S.TEMPLE_HANDBELL, vol=vol, speed=pitch, end=1.6, fade_out=0.6, **kw)


def gong(size: str = "small", vol: float = 2.0, **kw):
    """Bell / gong layers, trimmed so they punch instead of droning."""
    if size == "small":
        return [Sfx(S.GONG_CRASH_3, vol=vol, speed=1.15, end=1.1, fade_out=0.5, **kw)]
    if size == "medium":
        return [Sfx(S.GONG_RESONANT, vol=vol, speed=1.05, end=2.2, fade_out=1.0, **kw),
                Sfx(S.CHURCH_BELL_4, vol=vol * 0.6, speed=1.0, end=1.6, fade_out=0.8, **kw)]
    if size == "big":
        return [Sfx(S.DEATH_TOLL, vol=vol, speed=1.0, end=3.5, fade_out=1.4, **kw),
                Sfx(S.GONG_CRASH_1, vol=vol * 0.8, speed=0.9, end=3.0, fade_out=1.2, **kw)]
    if size == "huge":
        return [Sfx(S.APOCALYPSE_GONG, vol=vol, speed=1.0, end=6.0, fade_out=2.0, **kw),
                Sfx(S.DEATH_TOLL, vol=vol * 0.8, speed=0.85, end=4.5, fade_out=2.0, **kw)]
    raise ValueError(size)


# ------------------------------------------------------------- effects ----
def spark(scale: float = 1.0, col=GOLD, alt=PALE, part: str = HRP, **kw):
    """Compact impact flash (Clash + Mass Hit) at the part."""
    return [
        Visual("Clash", time=0.2, size=0.5 * scale, alt_size=2, amount=0.07, col=col,
               alt_col=alt, opacity=0, alt_opacity=1, part=part, **kw),
        Visual("Mass Hit", time=0.45, size=0.6 * scale, alt_size=0.2, amount=0.03, col=alt,
               alt_col=col, opacity=0, alt_opacity=1.5, part=part, **kw),
    ]


def burst(scale: float = 1.0, col=GOLD, alt=PALE, part: str = HRP, **kw):
    """Heavier impact: sparks + star + ring of wind."""
    return spark(scale * 1.6, col, alt, part, **kw) + [
        Visual("Star", time=0.25, size=0.35 * scale, alt_size=2, amount=1, col=alt,
               alt_col=col, opacity=0, alt_opacity=1, ease="Exponential", ease_dir="Out",
               part=part, **kw),
        Visual("Wind Ring", time=0.45, size=1.2 * scale, alt_size=3, amount=3, col=col,
               alt_col=alt, opacity=0.85, alt_opacity=1, part=part, **kw),
    ]


def ripple(scale: float = 1.0, y: float = GROUND, col=GOLD, alt=PALE, time: float = 0.5,
           op: float = 0.35, **kw):
    """Flat expanding disc of light hugging the floor (sound hitting the ground)."""
    d0, d1 = 2.0 * scale, 22.0 * scale
    return Visual("Cylinder", time=time, size=1, alt_size=1, size2=(0.25, d0, d0),
                  alt_size2=(0.05, d1, d1), col=col, alt_col=alt, opacity=op,
                  alt_opacity=1, pos=(0, y, 0), rot=(0, 0, 90), ease="Exponential",
                  ease_dir="Out", **kw)


def sound_ring(pos=(0, 0, 3), scale: float = 1.0, col=GOLD, time: float = 0.35,
               forward: bool = True, **kw):
    """Thin ring of sound (circle mesh) - upright facing forward, or flat."""
    return Visual("Mesh", amount=M.RING_LINE, time=time, size=0.03 * scale, alt_size=6,
                  col=col, alt_col=PALE, opacity=0.2, alt_opacity=1, pos=pos,
                  rot=(90, 0, 0) if forward else (0, 0, 0), ease="Exponential",
                  ease_dir="Out", **kw)


def shake(level: str = "Light", time: float = 1, amount: float = 1, **kw):
    return Visual(f"Shake {level}", time=time, amount=amount, opacity=0, alt_opacity=0, **kw)


def fov(amount: float, time: float = 0.35, **kw):
    return Visual("Field of View", time=time, amount=amount, opacity=0, alt_opacity=0,
                  ease="Exponential", ease_dir="Out", **kw)


def flash(col=PALE, time: float = 0.08, **kw):
    return Visual("Screen Color", time=time, col=col, alt_col=(255, 255, 255), opacity=0,
                  alt_opacity=0, **kw)


def light(part: str = HRP, size: float = 10, bright: float = 2, time: float = 0.3,
          col=GOLD, hold: bool = False, **kw):
    return Visual("Light", time=time, size=size, opacity=bright,
                  alt_opacity=bright if hold else 0, col=col, part=part, **kw)


def trail(part: str, time: float = 0.35, col=GOLD, **kw):
    return Visual("Melee Trail", time=time, size=1, col=col, alt_col=PALE, opacity=0.35,
                  alt_opacity=1, part=part, **kw)


def glow(time: float = 0.25, col=GOLD, op: float = 0.55, **kw):
    return Visual("Glow", time=time, size=0.95, col=col, opacity=op, alt_opacity=1, **kw)


def aura(part: str = HRP, size: float = 1.0, time: float = 1.0, col=GOLD, alt=JADE,
         op: float = 0.25, hold: bool = True, **kw):
    return Visual("Cursed Energy", time=time, size=size, col=col, alt_col=alt, opacity=op,
                  alt_opacity=op if hold else 1, part=part, **kw)


def afterimage(time: float = 0.4, col=GOLD, **kw):
    return Visual("Afterimage", time=time, size=1, col=col, alt_col=PALE, opacity=0.5,
                  alt_opacity=1, **kw)


def bell(scale: float = 1.0, y: float = 0.0, z: float = 0.0, drop: float = 0.0,
         time: float = 0.5, col=GOLD, op: float = 0.45, fade: bool = True,
         ease: str = "Quad", ease_dir: str = "In", grow: float = 1.0, rise: float = 0.0,
         **kw):
    """A spectral temple bell (bonshō) built from Cylinder + Sphere primitives.

    Its rim sits on the floor under the part (plus `y`), `z` studs in front.
    drop > 0: the bell falls from `drop` studs higher during `time`;
    rise > 0: it lifts `rise` studs into the sky instead."""
    s = scale
    bottom = GROUND + y
    end_op = 1 if fade else op

    def cyl(length, dia, cy, c, o):
        return Visual("Cylinder", time=time, size=1, alt_size=1,
                      size2=(length, dia, dia), alt_size2=(length, dia * grow, dia * grow),
                      col=c, alt_col=PALE, opacity=o, alt_opacity=end_op,
                      pos=(0, cy + drop, z), alt_pos=(0, cy + rise, z), rot=(0, 0, 90),
                      ease=ease, ease_dir=ease_dir, **kw)

    crown_y = bottom + 7.6 * s
    return [
        cyl(7.4 * s, 6.0 * s, bottom + 3.8 * s, col, op),            # body
        cyl(0.7 * s, 7.0 * s, bottom + 0.35 * s, BRONZE, op * 0.8),  # lip
        cyl(0.35 * s, 6.3 * s, bottom + 5.4 * s, BRONZE, op * 0.8),  # band
        cyl(0.35 * s, 6.3 * s, bottom + 2.2 * s, BRONZE, op * 0.8),  # band
        Visual("Sphere", time=time, size=5.2 * s, alt_size=grow, col=col, alt_col=PALE,
               opacity=op, alt_opacity=end_op, pos=(0, crown_y + drop, z),
               alt_pos=(0, crown_y + rise, z), ease=ease, ease_dir=ease_dir, **kw),
        Visual("Light", time=time, size=14 * s, opacity=2.5, alt_opacity=0, col=GOLD,
               pos=(0, bottom + 4 * s + drop, z), alt_pos=(0, bottom + 4 * s + rise, z), **kw),
    ]


def bell_ring(scale: float = 1.0, z: float = 0.0, col=GOLD, **kw):
    """The moment a bell rings: floor ripples, wind rings, sparks."""
    return [
        Visual("Cylinder", time=0.55, size=1, alt_size=1, size2=(0.25, 3 * scale, 3 * scale),
               alt_size2=(0.05, 26 * scale, 26 * scale), col=col, alt_col=PALE, opacity=0.3,
               alt_opacity=1, pos=(0, GROUND, z), rot=(0, 0, 90), ease="Exponential",
               ease_dir="Out", **kw),
        Visual("Cylinder", time=0.8, size=1, alt_size=1, size2=(0.2, 2 * scale, 2 * scale),
               alt_size2=(0.05, 40 * scale, 40 * scale), col=JADE, alt_col=PALE, opacity=0.5,
               alt_opacity=1, pos=(0, GROUND + 0.1, z), rot=(0, 0, 90), ease="Exponential",
               ease_dir="Out", **kw),
        Visual("Wind Ring", time=0.6, size=1.5 * scale, alt_size=4, amount=4, col=col,
               alt_col=PALE, opacity=0.8, alt_opacity=1, pos=(0, 0, z), **kw),
        Visual("Mesh", amount=M.THIN_RINGS, time=0.7, size=0.5 * scale, alt_size=12,
               col=col, alt_col=PALE, opacity=0.5, alt_opacity=1, pos=(0, GROUND + 1, z),
               ease="Exponential", ease_dir="Out", **kw),
    ]
