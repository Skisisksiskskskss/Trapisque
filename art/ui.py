"""
The menus' pictures, drawn like the rest of the art (lit from the upper left, outlined
in a dark shade of each part's own colour): the lobby's buttons and the badges on
titles. tools/art.py calls sprites(). Each on a 100 x 100 canvas, centred:

    ui/chest ui/quests ui/locker ui/shop ui/leaders ui/rules ui/settings ui/chat
    ui/party ui/watch ui/gem ui/crown          the lobby (Icons.make uses them)
    ui/anchor ui/skull ui/swords ui/coin ui/ghost ui/bottle ui/hook ui/cannonball
    ui/trap ui/compass ui/wave ui/flame ui/snowflake ui/star ui/barrel ui/shell
                                               title badges (Cosmetics look.icon)
    ui/wavelet                                 the foam crests on the sea behind the menus
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from badge import rrect, star  # noqa: E402
from props import INK, Art, circ, ell, mix  # noqa: E402

PX = 128
GOLD, GOLD_D = "#F2C230", "#B07F12"
WOOD, WOOD_D = "#A8703C", "#6E4520"
PAPER = "#F3E2B8"
STEEL = "#AEB7C4"
RED = "#D64545"


def new():
    return Art(PX, 1.15)


def hi(a, d, op=0.45):
    """A highlight on a shape's lit side."""
    a.fill(d, "#FFFFFF", op)


def chest():
    a = new()
    a.shadow(50, 88, 38, 5, 0.3)
    a.shape(rrect(12, 46, 76, 40, 5), "#9A6435")
    a.shape("M 12 50 L 12 40 C 12 22, 32 24, 50 24 C 68 24, 88 22, 88 40 L 88 50 Z", "#B27840")
    for x in (26, 74):
        a.shape(rrect(x - 4, 24, 8, 62, 2), GOLD)
    a.shape(rrect(41, 44, 18, 18, 4), GOLD)
    a.fill("M 50 50 C 47 50, 46 54, 48.5 56 L 47.5 59 L 52.5 59 L 51.5 56 C 54 54, 53 50, 50 50 Z", mix(GOLD_D, INK, 0.5))
    hi(a, ell(36, 31, 12, 3), 0.35)
    return a.svg()


def quests():
    a = new()
    a.shadow(50, 90, 34, 4, 0.25)
    a.shape("M 22 18 L 74 18 C 80 18, 80 30, 74 30 L 74 82 L 26 82 C 20 82, 20 70, 26 70 L 26 30 C 20 30, 16 18, 22 18 Z", PAPER, light=0.4, dark=0.2)
    a.shape(ell(24, 76, 6, 6), mix(PAPER, WOOD, 0.35))
    a.shape(ell(76, 24, 6, 6), mix(PAPER, WOOD, 0.35))
    for y in (40, 50, 60):
        a.line(f"M 34 {y} L 64 {y}", mix(PAPER, INK, 0.45), 2.6, 0.8)
    a.shape(circ(60, 70, 9), RED)
    a.fill(star(60, 70, 4.6, 2, 5), mix(RED, "#FFFFFF", 0.45))
    return a.svg()


def locker():
    # a captain's tricorn hat
    a = new()
    a.shadow(50, 84, 38, 5, 0.3)
    a.shape("M 10 66 C 18 46, 32 30, 50 30 C 68 30, 82 46, 90 66 C 76 74, 62 70, 50 76 C 38 70, 24 74, 10 66 Z", "#3B3A4A", light=0.35)
    a.shape("M 16 64 C 30 70, 40 66, 50 72 C 60 66, 70 70, 84 64 L 86 69 C 72 76, 62 72, 50 80 C 38 72, 28 76, 14 69 Z", GOLD)
    a.shape(circ(50, 48, 8), "#F7F1E3")
    a.fill("M 45 45 L 55 51 M 55 45 L 45 51", "#000000", 0)
    a.line("M 45.5 44.5 L 54.5 51.5 M 54.5 44.5 L 45.5 51.5", INK, 2.2)
    hi(a, ell(34, 42, 10, 3), 0.25)
    return a.svg()


def shop():
    # a fat coin purse with coins spilling
    a = new()
    a.shadow(50, 88, 36, 5, 0.3)
    a.shape("M 30 34 C 14 46, 14 86, 50 86 C 86 86, 86 46, 70 34 Z", "#8E5A9E")
    a.shape("M 30 34 C 36 28, 64 28, 70 34 C 64 38, 36 38, 30 34 Z", mix("#8E5A9E", INK, 0.2))
    a.shape("M 34 22 L 42 32 L 58 32 L 66 22 C 58 26, 42 26, 34 22 Z", "#A673B6")
    a.line("M 30 36 C 40 40, 60 40, 70 36", GOLD, 3.4)
    for (x, y) in ((72, 74), (82, 80)):
        a.shape(ell(x, y, 9, 6), GOLD)
    a.fill(star(50, 62, 9, 4, 5), GOLD)
    hi(a, ell(32, 56, 4, 10), 0.3)
    return a.svg()


def leaders():
    # the trophy cup
    a = new()
    a.shadow(50, 90, 30, 4, 0.3)
    a.shape("M 26 20 C 12 20, 12 44, 30 46 L 30 40 C 20 38, 20 26, 28 26 Z", GOLD)
    a.shape("M 74 20 C 88 20, 88 44, 70 46 L 70 40 C 80 38, 80 26, 72 26 Z", GOLD)
    a.shape("M 26 16 L 74 16 L 72 40 C 70 56, 60 62, 50 62 C 40 62, 30 56, 28 40 Z", GOLD)
    a.shape(rrect(44, 60, 12, 12, 2), GOLD_D)
    a.shape(rrect(30, 72, 40, 12, 3), WOOD)
    a.shape(rrect(38, 75, 24, 5, 1), mix(GOLD, "#FFFFFF", 0.2))
    a.fill(star(50, 36, 9, 4, 5), "#FFF3B0")
    hi(a, "M 32 20 L 38 20 L 38 44 C 36 46, 33 42, 32 36 Z", 0.4)
    return a.svg()


def rules():
    # the treasure map
    a = new()
    a.shadow(50, 88, 38, 5, 0.25)
    a.shape("M 12 24 L 36 16 L 64 24 L 88 16 L 88 78 L 64 86 L 36 78 L 12 86 Z", PAPER, light=0.35, dark=0.2)
    a.fill("M 36 16 L 64 24 L 64 86 L 36 78 Z", mix(PAPER, WOOD, 0.18))
    a.line("M 22 70 C 30 56, 40 66, 48 52 C 54 42, 62 50, 68 40", mix(RED, INK, 0.2), 2.6)
    a.line("M 22 70 L 26 66", "#000000", 0)
    a.line("M 66 30 L 76 40 M 76 30 L 66 40", RED, 4.2)
    a.shape(ell(26, 34, 8, 6), "#7FC28A", flat=True)
    return a.svg()


def settings():
    # a ship's wheel
    a = new()
    a.shadow(50, 92, 30, 4, 0.25)
    for k in range(8):
        ang = math.radians(k * 45 + 22.5)
        x1, y1 = 50 + math.cos(ang) * 14, 50 + math.sin(ang) * 14
        x2, y2 = 50 + math.cos(ang) * 44, 50 + math.sin(ang) * 44
        a.line(f"M {x1:.1f} {y1:.1f} L {x2:.1f} {y2:.1f}", mix(WOOD, INK, 0.6), 9.5)
        a.line(f"M {x1:.1f} {y1:.1f} L {x2:.1f} {y2:.1f}", WOOD, 6.4)
        a.shape(circ(x2, y2, 5.2), "#B47E46")
    a.parts.append(f'<circle cx="50" cy="50" r="30" fill="none" stroke="{mix(WOOD, INK, 0.6)}" stroke-width="12"/>')
    a.parts.append(f'<circle cx="50" cy="50" r="30" fill="none" stroke="{WOOD}" stroke-width="8"/>')
    a.parts.append('<path d="M 26 38 A 30 30 0 0 1 44 21" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="3" stroke-linecap="round"/>')
    a.shape(circ(50, 50, 11), GOLD)
    return a.svg()


def chat():
    a = new()
    a.shadow(50, 90, 30, 4, 0.25)
    a.shape("M 20 18 L 80 18 C 88 18, 92 24, 92 32 L 92 56 C 92 64, 88 70, 80 70 L 46 70 L 28 86 L 32 70 L 20 70 C 12 70, 8 64, 8 56 L 8 32 C 8 24, 12 18, 20 18 Z", "#FFFDF6", light=0.2, dark=0.15)
    for x in (30, 50, 70):
        a.shape(circ(x, 44, 5.5), "#3C82C4")
    return a.svg()


def party():
    # the crew's flag
    a = new()
    a.shadow(40, 92, 22, 3, 0.25)
    a.shape(rrect(20, 10, 6, 82, 2), WOOD)
    a.shape("M 26 14 C 46 8, 60 22, 88 14 L 88 56 C 60 64, 46 50, 26 56 Z", "#2A2A35", light=0.25)
    a.shape("M 48 26 C 48 18, 66 18, 66 26 C 66 32, 63 33, 62 36 L 52 36 C 51 33, 48 32, 48 26 Z", "#F3EFE4")
    a.fill(circ(53.5, 26, 2.6), "#2A2A35")
    a.fill(circ(60.5, 26, 2.6), "#2A2A35")
    a.line("M 46 40 L 68 48 M 68 40 L 46 48", "#F3EFE4", 3.4)
    a.shape(circ(23, 9, 4.5), GOLD)
    return a.svg()


def watch():
    # a spyglass
    a = new()
    a.shadow(50, 84, 38, 5, 0.25)
    a.group("rotate(-28 50 50)")
    a.shape(rrect(8, 40, 30, 20, 4), "#7A4A26")
    a.shape(rrect(36, 37, 28, 26, 3), GOLD)
    a.shape(rrect(62, 34, 30, 32, 4), "#7A4A26")
    a.shape(rrect(88, 32, 6, 36, 2), GOLD)
    a.end()
    hi(a, "M 22 50 L 70 26", 0)
    return a.svg()


def gem():
    a = new()
    a.shadow(50, 90, 26, 4, 0.3)
    base = "#3FA7F5"
    a.shape("M 22 36 L 36 18 L 64 18 L 78 36 L 50 86 Z", base, light=0.35)
    a.fill("M 22 36 L 78 36 L 50 86 Z", mix(base, INK, 0.2), 0.5)
    a.fill("M 36 18 L 44 36 L 50 18 Z", "#FFFFFF", 0.35)
    a.line("M 22 36 L 78 36 M 44 36 L 50 86 M 56 36 L 50 86 M 44 36 L 50 18 L 56 36", mix(base, INK, 0.5), 1.4, 0.7)
    a.fill(star(34, 28, 5, 1.3, 4), "#FFFFFF", 0.9)
    return a.svg()


def crown():
    a = new()
    a.shadow(50, 86, 34, 4, 0.3)
    a.shape("M 14 34 L 32 50 L 50 20 L 68 50 L 86 34 L 80 76 L 20 76 Z", GOLD)
    a.shape(rrect(18, 70, 64, 12, 3), GOLD_D)
    for (x, c) in ((32, RED), (50, "#3FA7F5"), (68, "#3E9F5B")):
        a.shape(circ(x, 76, 4), c)
    for (x, y) in ((14, 32), (50, 18), (86, 32)):
        a.shape(circ(x, y, 5), "#FFF3B0")
    hi(a, "M 26 52 L 32 56 L 30 68 L 24 68 Z", 0.35)
    return a.svg()


def anchor():
    a = new()
    a.shadow(50, 92, 28, 4, 0.25)
    iron = "#5C6B80"
    a.parts.append(f'<circle cx="50" cy="20" r="8" fill="none" stroke="{mix(iron, INK, 0.55)}" stroke-width="9"/>')
    a.parts.append(f'<circle cx="50" cy="20" r="8" fill="none" stroke="{iron}" stroke-width="5.5"/>')
    a.shape(rrect(45, 26, 10, 54, 3), iron)
    a.shape(rrect(30, 34, 40, 8, 3), iron)
    a.shape("M 14 56 L 22 50 C 24 70, 36 80, 50 80 C 64 80, 76 70, 78 50 L 86 56 L 82 60 C 78 80, 64 88, 50 88 C 36 88, 22 80, 18 60 Z", iron)
    hi(a, rrect(47, 30, 3, 40, 1.5), 0.3)
    return a.svg()


def skull():
    a = new()
    a.shadow(50, 92, 30, 4, 0.25)
    bone = "#F3EFE4"
    for (x1, y1, x2, y2) in ((18, 70, 82, 88), (82, 70, 18, 88)):
        a.line(f"M {x1} {y1} L {x2} {y2}", mix(bone, INK, 0.55), 10)
        a.line(f"M {x1} {y1} L {x2} {y2}", bone, 6.5)
        for (x, y) in ((x1, y1), (x2, y2)):
            a.shape(circ(x, y, 5), bone)
    a.shape("M 22 40 C 22 14, 78 14, 78 40 C 78 54, 70 58, 68 64 L 68 72 L 32 72 L 32 64 C 30 58, 22 54, 22 40 Z", bone)
    a.shape(ell(38, 44, 8, 9), "#2A2830", flat=True)
    a.shape(ell(62, 44, 8, 9), "#2A2830", flat=True)
    a.fill("M 50 54 L 46 62 L 54 62 Z", "#2A2830")
    for x in (40, 47, 54, 61):
        a.line(f"M {x} 66 L {x} 72", mix(bone, INK, 0.5), 1.6)
    hi(a, ell(36, 26, 8, 3), 0.6)
    return a.svg()


def swords():
    a = new()
    a.shadow(50, 92, 30, 4, 0.25)
    for flip in (1, -1):
        a.group(f"translate(100 0) scale(-1 1)" if flip < 0 else "")
        a.shape("M 26 74 L 76 16 C 80 14, 84 16, 82 20 L 32 80 Z", STEEL, light=0.45)
        a.shape(rrect(14, 70, 24, 7, 3), GOLD, )
        a.shape("M 22 80 L 30 72 L 36 78 L 28 86 Z", WOOD)
        a.shape(circ(22, 88, 4.5), GOLD)
        a.end()
    return a.svg()


def coin():
    a = new()
    a.shadow(50, 90, 30, 4, 0.3)
    a.shape(circ(50, 50, 36), GOLD)
    a.shape(circ(50, 50, 27), mix(GOLD, GOLD_D, 0.3))
    a.fill(star(50, 50, 16, 7, 5), "#FFE58A")
    hi(a, "M 22 40 C 26 26, 38 18, 50 16 C 40 22, 30 30, 26 44 Z", 0.5)
    return a.svg()


def ghost():
    a = new()
    a.glow(50, 50, 44, 44, "#7CFFC4", 0.3)
    body = "#D9FFF0"
    a.shape("M 22 84 L 22 44 C 22 16, 78 16, 78 44 L 78 84 L 68 76 L 59 86 L 50 76 L 41 86 L 32 76 Z", body, outline="#3E9F86", light=0.3, dark=0.15)
    a.shape(ell(40, 46, 6, 8), "#1E3A34", flat=True)
    a.shape(ell(60, 46, 6, 8), "#1E3A34", flat=True)
    a.shape(ell(50, 64, 6, 5), "#1E3A34", flat=True)
    hi(a, ell(36, 30, 7, 3), 0.7)
    return a.svg()


def bottle():
    a = new()
    a.shadow(50, 92, 22, 4, 0.3)
    glass = "#3E9F5B"
    a.shape("M 42 10 L 58 10 L 58 32 C 72 38, 74 48, 74 60 L 74 82 C 74 88, 70 90, 64 90 L 36 90 C 30 90, 26 88, 26 82 L 26 60 C 26 48, 28 38, 42 32 Z", glass, opacity=0.95)
    a.shape(rrect(40, 6, 20, 10, 2), "#B98A5A")
    a.shape(rrect(30, 56, 40, 22, 3), PAPER)
    a.line("M 40 63 L 60 63 M 40 70 L 56 70", mix(PAPER, INK, 0.5), 2.2)
    hi(a, "M 32 52 C 32 44, 36 40, 40 38 L 38 82 L 33 82 Z", 0.35)
    return a.svg()


def hook():
    a = new()
    a.shadow(50, 92, 24, 3, 0.25)
    a.parts.append(f'<path d="M 56 14 L 56 62 C 56 80, 26 82, 26 62 L 26 54" fill="none" stroke="{mix(STEEL, INK, 0.55)}" stroke-width="11" stroke-linecap="round"/>')
    a.parts.append(f'<path d="M 56 14 L 56 62 C 56 80, 26 82, 26 62 L 26 54" fill="none" stroke="{STEEL}" stroke-width="7" stroke-linecap="round"/>')
    a.shape("M 18 58 L 26 44 L 34 58 Z", STEEL)
    a.parts.append(f'<circle cx="56" cy="12" r="6" fill="none" stroke="{mix(STEEL, INK, 0.55)}" stroke-width="5"/>')
    a.shape(ell(72, 36, 10, 6), "#3FA7F5")
    a.fill("M 80 36 L 90 30 L 90 42 Z", "#3FA7F5")
    a.fill(circ(68, 34, 1.8), INK)
    return a.svg()


def cannonball():
    a = new()
    a.shadow(54, 90, 32, 4, 0.3)
    a.glow(26, 30, 22, 16, "#FFC23A", 0.4)
    a.shape(circ(54, 56, 30), "#3C3C46", light=0.4)
    a.line("M 66 24 C 74 14, 84 16, 88 10", "#B98A5A", 4)
    a.fill(star(88, 10, 8, 3, 6), "#FFC23A")
    hi(a, ell(42, 44, 9, 6), 0.35)
    return a.svg()


def trap():
    a = new()
    a.shadow(50, 86, 40, 5, 0.3)
    iron = "#7E8794"
    a.shape(ell(50, 72, 38, 12), iron)
    for side in (-1, 1):
        y0 = 72
        pts = " ".join(f"L {50 + side * (34 - k * 8)} {y0 - (22 if k % 2 == 0 else 12) - 10}" for k in range(5))
        a.shape(f"M {50 + side * 38} {y0} {pts} L 50 {y0 - 6} Z", STEEL)
    a.shape(rrect(40, 64, 20, 10, 3), "#C9A227")
    return a.svg()


def compass():
    a = new()
    a.shadow(50, 92, 32, 4, 0.3)
    a.shape(circ(50, 50, 38), GOLD)
    a.shape(circ(50, 50, 30), "#F7F1E3", light=0.2, dark=0.1)
    a.fill("M 50 22 L 56 50 L 50 78 L 44 50 Z", mix("#F7F1E3", INK, 0.2))
    a.fill("M 50 22 L 56 50 L 44 50 Z", RED)
    a.fill("M 22 50 L 50 45 L 78 50 L 50 55 Z", mix("#F7F1E3", INK, 0.35))
    a.shape(circ(50, 50, 4), GOLD)
    return a.svg()


def wave():
    a = new()
    a.shadow(50, 90, 38, 4, 0.2)
    sea = "#2F8FD0"
    a.shape("M 8 84 C 8 52, 26 22, 56 18 C 78 16, 92 30, 88 44 C 84 34, 70 30, 62 38 C 54 46, 62 58, 72 56 C 64 66, 46 62, 44 48 C 40 64, 50 80, 92 84 Z", sea, light=0.4)
    a.line("M 64 22 C 76 22, 86 30, 86 40", "#FFFFFF", 3.2, 0.85)
    a.line("M 16 76 C 18 60, 26 44, 40 34", "#FFFFFF", 2.4, 0.4)
    return a.svg()


def flame():
    a = new()
    a.glow(50, 70, 36, 26, "#FFB000", 0.35)
    a.shape("M 50 92 C 26 92, 18 72, 26 56 C 30 64, 36 66, 36 58 C 36 42, 44 28, 56 10 C 58 28, 70 32, 74 50 C 78 44, 78 38, 76 32 C 88 48, 86 92, 50 92 Z", "#FF8A1C", outline="#A8341A", light=0.45)
    a.fill("M 50 90 C 38 90, 34 78, 40 68 C 42 74, 46 74, 46 68 C 46 58, 50 50, 56 42 C 58 54, 66 60, 64 74 C 62 86, 58 90, 50 90 Z", "#FFE45C")
    return a.svg()


def snowflake():
    a = new()
    a.glow(50, 50, 40, 40, "#BFE7FF", 0.35)
    ice, edge = "#E8F8FF", "#3F8FC0"
    for k in range(6):
        ang = k * 60
        a.group(f"rotate({ang} 50 50)")
        a.line("M 50 50 L 50 12 M 50 26 L 40 18 M 50 26 L 60 18", edge, 8)
        a.line("M 50 50 L 50 12 M 50 26 L 40 18 M 50 26 L 60 18", ice, 4.4)
        a.end()
    a.shape(circ(50, 50, 7), ice, outline=edge)
    return a.svg()


def star_icon():
    a = new()
    a.shadow(50, 90, 30, 4, 0.25)
    a.shape(star(50, 50, 40, 18, 5), GOLD, light=0.45)
    a.fill(star(44, 40, 8, 2, 4), "#FFFFFF", 0.8)
    return a.svg()


def barrel():
    a = new()
    a.shadow(50, 92, 30, 4, 0.3)
    a.shape("M 26 14 L 74 14 C 82 34, 82 66, 74 86 L 26 86 C 18 66, 18 34, 26 14 Z", WOOD)
    for x in (38, 50, 62):
        a.line(f"M {x} 16 C {x + (x - 50) * 0.3} 40, {x + (x - 50) * 0.3} 60, {x} 84", WOOD_D, 1.4, 0.7)
    for y in (28, 72):
        a.shape(f"M 21 {y - 3} L 79 {y - 3} L 80 {y + 3} L 20 {y + 3} Z", "#5C6B80")
    a.shape(ell(50, 14, 24, 4), "#C99563")
    hi(a, "M 28 20 C 24 40, 24 60, 28 80 L 32 80 C 28 60, 28 40, 32 20 Z", 0.3)
    return a.svg()


def shell():
    a = new()
    a.shadow(50, 88, 34, 4, 0.25)
    pink = "#F49AB8"
    a.shape("M 50 84 C 22 84, 10 56, 18 36 C 26 18, 74 18, 82 36 C 90 56, 78 84, 50 84 Z", pink, light=0.35)
    for k in range(-3, 4):
        a.line(f"M 50 82 L {50 + k * 11} {26 + abs(k) * 3}", mix(pink, INK, 0.45), 1.8, 0.8)
    a.shape(rrect(40, 78, 20, 10, 3), pink)
    return a.svg()


def wavelet():
    a = new()
    # a crest rolling over, with the foam trailing behind it
    a.line("M 6 66 C 24 60, 40 50, 56 48 C 70 46, 80 54, 78 62 C 76 68, 68 68, 66 62", "#FFFFFF", 5, 0.9)
    a.line("M 20 76 C 34 72, 48 72, 60 74", "#FFFFFF", 3, 0.5)
    return a.svg()


def sprites():
    return [
        ("chest", chest()), ("quests", quests()), ("locker", locker()), ("shop", shop()),
        ("leaders", leaders()), ("rules", rules()), ("settings", settings()), ("chat", chat()),
        ("party", party()), ("watch", watch()), ("gem", gem()), ("crown", crown()),
        ("anchor", anchor()), ("skull", skull()), ("swords", swords()), ("coin", coin()),
        ("ghost", ghost()), ("bottle", bottle()), ("hook", hook()), ("cannonball", cannonball()),
        ("trap", trap()), ("compass", compass()), ("wave", wave()), ("flame", flame()),
        ("snowflake", snowflake()), ("star", star_icon()), ("barrel", barrel()), ("shell", shell()),
        ("wavelet", wavelet()),
    ]
