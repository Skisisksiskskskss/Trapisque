#!/usr/bin/env python3
"""Screen previews at real device sizes: the match screen and the lobby.

Every rect comes from the game's own Layout module (tests/dump_screens.luau dumps
Layout.match / Layout.lobby for each device), and each piece is drawn the way its
Lua component builds it (PlayerChips, HandView, ActionDock, Feed, LobbyScreen,
PlayPanel, PartyPanel, LeaderboardPanel). The board comes from board.py with the
tile skins recorded from TileSkins. Roblox's own top-bar buttons and the phone's
notch / home-bar insets are drawn in so you can see the HUD keeps clear of them.

Real avatar headshots load from Roblox in game; here people get a stand-in face.

Writes 07-match-*.png, 08-lobby-*.png, 09-treasure-chests.png and 10-tile-skins.png.

Usage: python3 tools/preview/hud.py <dir with icons/board/cosmetics/cards/screens .json> <outdir>
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from render import hex_rgba  # noqa: E402
from cards import CardPainter  # noqa: E402
import board as boardmod  # noqa: E402
from screens import (Screen, S, shade, PARCH, PARCH_MID, PARCH_EDGE, BURN, INK, INK_SOFT,  # noqa: E402
                     INK_FAINT, INK_RED, WOOD_PALE, BRASS, BRASS_LIGHT, BRASS_DARK, GOLD,
                     INFO, WHITE, TEXT_DARK, NEUTRAL, SEAT, CHAR, CAT, draw_chests,
                     BG, PANEL, PANEL_DEEP, PANEL_RAISED, PANEL_HI, PANEL_EDGE, MINE, TEXT, TEXT_SOFT, TEXT_FAINT,
                     TEXT_ON_LIGHT, INFO_SOFT, GOOD_SOFT)
from PIL import Image, ImageDraw  # noqa: E402

UNIT = 46
CHIP_BG, CHIP_BG_TURN, TEXT_FAINT = "#1F150E", "#3A2A14", "#BFA98A"
ABILITY_STYLE = {"mage": "blue", "trapper": "wood", "fire_starter": "red", "warper": "purple", "overseer": "brass"}
STATUS = [("burning", "fire", "#E2622B"), ("frozen", "ice", "#5DADE2"), ("held", "lock", "#8A9099"),
          ("skip", "snare", "#A0522D"), ("boots", "boots", "#8B6B3E"), ("anchor", "hourglass", "#8E6CEF")]
FACE_BACKS = ["#9FC2E8", "#E8B39F", "#B6D99A", "#E8D59F", "#C9A9E8", "#9FE0D9"]


def R(r):
    return r["x"], r["y"], r["w"], r["h"]


# ----------------------------------------------------------------------------- bits
def stand_in_face(sc, cx, cy, d, back):
    """Where a Roblox headshot goes: a plain round head with two eyes and a smile."""
    sc.circle(cx, cy, d, back)
    sc.circle(cx, cy + d * 0.08, d * 0.62, "#F5CD30")
    for ex in (-0.11, 0.11):
        sc.circle(cx + ex * d, cy + d * 0.02, d * 0.07, "#2B2B2B")
    r = d * 0.16
    box = [(cx - r) * S, (cy + d * 0.1 - r * 0.6) * S, (cx + r) * S, (cy + d * 0.1 + r) * S]
    sc.d.arc(box, start=20, end=160, fill=hex_rgba("#2B2B2B"), width=max(1, int(d * 0.035 * S)))


def portrait(sc, info, cx, cy, d, ring=None, ring_px=3, back=None, face_back=None):
    """Avatars.portrait: a headshot (stand-in) or the character medallion for bots."""
    if ring:
        sc.circle(cx, cy, d + 2 * ring_px, ring)
    if info.get("isBot"):
        ch = info.get("character") or "mage"
        sc.medallion(ch, cx, cy, d / 1.16, CHAR.get(ch, INK_SOFT))
    else:
        stand_in_face(sc, cx, cy, d, face_back or back or "#9FC2E8")


def counter(sc, x, y, icon, color, value, size):
    sc.icon(icon, x, y + 1, size, color, CHIP_BG)
    sc.text(x + size + 2, y, 20, size + 2, str(value), "chunky", size, WHITE)


def pips(sc, x, y, n, filled, size, gap):
    for i in range(n):
        sc.circle(x + i * (size + gap) + size / 2, y + size / 2, size, GOLD if i < filled else "#4A3A28")


# ----------------------------------------------------------------------------- board
def draw_board(sc, data, scr, focus, form):
    bd = scr["boards"]["tall" if form == "tall" else "wide"]
    layout = dict(bd["layout"])
    layout["rotated"] = bd.get("rotated", False)
    tb = layout["tileBounds"]
    ppu = min(focus["w"] / (tb["x1"] - tb["x0"]), focus["h"] / (tb["y1"] - tb["y0"]))  # stage px per hex unit
    ucx, ucy = (tb["x0"] + tb["x1"]) / 2, (tb["y0"] + tb["y1"]) / 2
    fcx, fcy = focus["x"] + focus["w"] / 2, focus["y"] + focus["h"] / 2
    k = ppu * S
    scene = {"layout": layout, "snapshot": scr["snapshot"], "skins": bd["skins"]}
    bdata = dict(data["board"])
    bdata["skins"] = scr["pawnSkins"]
    bdata["looks"] = scr["pawnLooks"]
    bs = boardmod.Scene(bdata, scene, width=int(round(layout["w"] * k)), pad=0)
    bs.table = lambda: None
    img = bs.render().convert("RGBA")
    ox = (fcx + (layout["x0"] - ucx) * ppu) * S
    oy = (fcy + (layout["y0"] - ucy) * ppu) * S
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=int(0.35 * k), fill=255)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=int(0.35 * k), fill=(0, 0, 0, 110))
    sc.img.alpha_composite(shadow, (int(ox), int(oy + 8 * S)), (0, 0)) if ox >= 0 and oy >= 0 else None
    layer = Image.new("RGBA", sc.img.size, (0, 0, 0, 0))
    layer.paste(img, (int(ox), int(oy)), mask)
    sc.img = Image.alpha_composite(sc.img, layer)

    def to_stage(ux, uy):
        return fcx + (ux - ucx) * ppu, fcy + (uy - ucy) * ppu
    return to_stage, ppu, layout


def name_tag(sc, x, y, text, color):
    """BoardView name tag over the current pawn (screen space)."""
    tw = sc.text_width(text, "heavy", 15)
    w, h = tw + 20, 24
    sc.frame(x - w / 2, y - h, w, h, h / 2, CHIP_BG, color, 2)
    sc.text(x - w / 2 + 10, y - h, tw + 2, h, text, "heavy", 15, WHITE)


# ----------------------------------------------------------------------------- HUD
def player_chips(sc, scr, spec, target, my_seat):
    chip = spec["chip"]
    w, h, kind = chip["w"], chip["h"], chip["kind"]
    players = {p["seat"]: p for p in scr["snapshot"]["players"]}
    seats = {s["seat"]: s for s in scr["seats"]}
    current = scr["snapshot"]["current"]
    r = spec["rect"]
    for i, seat in enumerate(sorted(players)):
        p, info = players[seat], seats[seat]
        x = r["x"] + (i * (w + spec["gap"]) if spec["dir"] == "x" else 0)
        y = r["y"] + (i * (h + spec["gap"]) if spec["dir"] == "y" else 0)
        color = SEAT[(seat - 1) % 6]
        on = seat == current
        sc.frame(x, y, w, h, min(12, h * 0.3), CHIP_BG_TURN if on else CHIP_BG, BRASS if on else shade(color, -0.35), 3 if on else 2,
                 falpha=0.94)
        name = info["name"] + (" (you)" if seat == my_seat else "")
        ch = scr["characters"].get(info.get("character") or "", {})
        active = [(ic, col) for key, ic, col in STATUS if p.get(key) is True or (isinstance(p.get(key), (int, float)) and
                                                                            not isinstance(p.get(key), bool) and p.get(key) > 0)]
        if kind == "full":
            av = h - 16
            portrait(sc, info, x + 8 + av / 2, y + h / 2, av, ring=color, ring_px=3, face_back=FACE_BACKS[seat % 6])
            tx = x + 8 + av + 10
            sc.text(tx, y + 5, w - (tx - x) - 8, 18, name, "heavy", 16, WHITE)
            if h >= 56:
                sub = ("Bot · " if info.get("isBot") else ("@" + info["username"] + " · " if info.get("username") else "")) + ch.get("name", "")
                sc.text(tx, y + 23, w - (tx - x) - 8, 14, sub, "body", 12, shade(CHAR.get(info.get("character"), TEXT_FAINT), 0.35))
            pips(sc, tx, y + h - 18, target, p.get("treasures", 0), 14, 4)
            cxr = x + w - 8 - 76
            counter(sc, cxr, y + h - 20, "coin", BRASS, p.get("coins", 0), 14)
            counter(sc, cxr + 40, y + h - 20, "book", "#D9A876", p.get("handCount", 0), 14)
            sx = x + w - 8
            for icon, col in active:
                sx -= 16
                sc.medallion(icon, sx + 8, y + 5 + 8, 16 / 1.16, col)
                sx -= 3
        elif kind == "band":
            av = h - 6
            portrait(sc, info, x + 3 + av / 2, y + h / 2, av, ring=color, ring_px=2, face_back=FACE_BACKS[seat % 6])
            tx = x + 3 + av + 5
            sc.text(tx, y + 3, w - (tx - x) - 4, 13, info["name"], "heavy", 11, WHITE)
            ps = max(6, min(11, int((w - (tx - x) - 6 - (target - 1) * 3) / target)))
            pips(sc, tx, y + h - ps - 5, target, p.get("treasures", 0), ps, 3)
            if active:
                sz = int(av * 0.42)
                sc.medallion(active[0][0], x + 3 + av * 0.86, y + 3 + av * 0.14, sz / 1.16, active[0][1])
        else:  # stack
            av = min(h - 30, w - 12)
            portrait(sc, info, x + w / 2, y + 4 + av / 2, av, ring=color, ring_px=2, face_back=FACE_BACKS[seat % 6])
            sc.text(x + 3, y + 4 + av + 1, w - 6, 13, info["name"], "heavy", 11, WHITE, align="center")
            ps = max(6, min(10, int((w - 10 - (target - 1) * 3) / target)))
            pw = target * ps + (target - 1) * 3
            pips(sc, x + (w - pw) / 2, y + h - ps - 5, target, p.get("treasures", 0), ps, 3)
            if active:
                sz = int(av * 0.42)
                sc.medallion(active[0][0], x + w / 2 - av / 2 + av * 0.86, y + 4 + av * 0.14, sz / 1.16, active[0][1])
        if on:
            sc.progress(x + 8, y + h - 4, w - 16, 3, 0.62, BRASS)


def hand(sc, data, spec, items, armed, touch, held=None, raised=None):
    """HandView. `held` = index of a card picked up (an empty, brass-rimmed spot);
    `raised` = index of the hovered card (sits 6 px higher). Returns the card rects."""
    spec = dict(spec)
    spec.setdefault("dir", "x")
    r = spec["rect"]
    n = len(items)
    gap = spec.get("gap", 6)
    cw, ch = spec["card"]["w"], spec["card"]["h"]
    if spec["dir"] == "y":
        fit = (r["h"] - 8 - (n - 1) * gap) / n
        ch = max(ch * 0.7, min(ch, fit))
        cw = ch * 0.72
    else:
        fit = (r["w"] - 12 - (n - 1) * gap) / n
        cw = max(cw * 0.7, min(cw, fit))
        ch = cw / 0.72
    painter = CardPainter(data["cards"])
    base = sc.img
    sc.img = Image.new("RGBA", base.size, (0, 0, 0, 0))
    if spec["dir"] == "y":
        x0, y0 = r["x"] + 4 + (r["w"] - 18 - cw) / 2, r["y"] + 4
    else:
        total = n * cw + (n - 1) * gap
        x0, y0 = r["x"] + max(6, (r["w"] - total) / 2), r["y"] + (r["h"] - ch) / 2
    rects = []
    for i, item in enumerate(items):
        x = x0 + (0 if spec["dir"] == "y" else i * (cw + gap))
        y = y0 + (i * (ch + gap) if spec["dir"] == "y" else 0)
        rects.append((x, y, cw, ch))
        if held is not None and i == held:
            gx, gy, gw, gh = x + cw * 0.04, y + ch * 0.03, cw * 0.92, ch * 0.94
            sc.frame(gx, gy, gw, gh, gw * 0.09, PANEL_DEEP, BRASS, 2, falpha=0.55, salpha=0.65)
            continue
        if raised is not None and i == raised:
            if spec["dir"] == "y":
                x += 6
            else:
                y -= 6
        if item in armed:
            if spec["dir"] == "y":
                x += 10
            else:
                y -= 10
            sc.outline(x, y, cw, ch, cw * 0.09, BRASS_LIGHT, 4)
        layer = Image.new("RGBA", (int((cw + 20) * S), int((ch + 20) * S)), (0, 0, 0, 0))
        painter.item_front(layer, 10 * S, 10 * S, cw * S, item)
        sc.img.alpha_composite(layer, (int((x - 10) * S), int((y - 10) * S)))
        if not touch and i < 9:
            bx, by = x + cw * 0.12 - 9, y + ch * 0.06 - 9
            sc.frame(bx, by, 18, 18, 5, CHIP_BG, BRASS, 1.5)
            sc.text(bx, by, 18, 18, str(i + 1), "chunky", 12, BRASS, align="center")
    # the hand is a scrolling frame: anything past its edges is cut off
    mask = Image.new("L", base.size, 0)
    ImageDraw.Draw(mask).rectangle([(r["x"] - 14) * S, (r["y"] - 14) * S, (r["x"] + r["w"] + 14) * S, (r["y"] + r["h"]) * S], fill=255)
    cards = sc.img
    cards.putalpha(Image.composite(cards.getchannel("A"), Image.new("L", base.size, 0), mask))
    sc.img = Image.alpha_composite(base, cards)
    return rects


def ability(sc, scr, rect, form, character):
    ch = scr["characters"][character]
    color = CHAR.get(character, INK_SOFT)
    x, y, w, h = R(rect)
    style = ABILITY_STYLE.get(character, "wood")
    name = (ch.get("ability") or "").upper()
    amount = ch.get("amount") or 2
    if form == "wide":
        sc.frame(x, y, w, h, 14, CHIP_BG, shade(color, -0.2), 2, falpha=0.94)
        ps = min(76, h - 40)
        sc.medallion(character, x + 10 + ps / 2, y + 10 + ps / 2, ps / 1.16, color)
        sc.text(x + ps + 18, y + 10, w - ps - 26, 24, ch["name"], "chunky", 20, PARCH)
        sc.button(x + ps + 18, y + 38, w - ps - 28, 42, text=name, style=style, size=18)
        bw = w - ps - 28
        px0 = x + ps + 18 + (bw - (amount * 12 + (amount - 1) * 5)) / 2
        for i in range(amount):
            sc.frame(px0 + i * 17, y + 86 + 3, 12, 12, 6, BRASS, BRASS_DARK, 1.5)
        sc.text(x + ps + 18, y + 104, bw, 14, "Charged!", "heavy", 12, WOOD_PALE, align="center")
        if h >= 150:
            sc.text(x + 8, y + h - 20, w - 16, 14, "Tap your portrait to read your card", "body", 11, "#8F7B60", align="center")
    elif form == "short":
        ps = min(40, h - 30)
        sc.medallion(character, x + ps / 2, y + 2 + ps / 2, ps / 1.16, color)
        bh = max(38, h - 30)
        sc.button(x + ps + 6, y, w - ps - 6, bh, text=name, style=style, size=15)
        px0 = x + (w - (amount * 12 + (amount - 1) * 5)) / 2
        for i in range(amount):
            sc.frame(px0 + i * 17, y + h - 24 + 3, 12, 12, 6, BRASS, BRASS_DARK, 1.5)
    else:
        sc.button(x, y, w, h, text=name + "  " + "●" * amount, style=style, size=14)


def roll(sc, rect, form, touch, clock="0:38"):
    x, y, w, h = R(rect)
    status_h = 40 if form == "wide" else 0
    sc.button(x, y, w, h - status_h, text="ROLL", icon="dice", style="brass", depth=7 if form == "wide" else 5,
              size=32 if form == "wide" else (24 if form == "short" else 22))
    # the button pulses on your turn: a soft brass glow
    sc.outline(x - 2, y - 2, w + 4, h - status_h + 4, 14, BRASS_LIGHT, 3, 0.6)
    # your turn's countdown (ActionDock:setClock): a clock badge inside ROLL's top corner
    bw, bh = (64, 26) if form == "wide" else (54, 22)
    sc.frame(x + w - 8 - bw, y + 8, bw, bh, bh / 2, PANEL_DEEP, BRASS, 1.5)
    sc.text(x + w - 8 - bw, y + 8, bw, bh, clock, "chunky", 17 if form == "wide" else 15, TEXT, align="center")
    if form == "wide":
        sc.text(x, y + h - 36, w, 36, "Your turn  ·  Space to roll", "heavy", 14, PARCH, align="center", outline=INK, ow=1.5)


def feed(sc, spec, lines):
    """Feed rows: dark pills, icon + text that wraps at the column's width (as the
    label's UISizeConstraint makes it in game)."""
    r = spec["rect"]
    size = 13 if r["w"] < 340 else 15
    max_text = max(120, r["w"] - 40) - (size + 2 + 6)
    lh = size + 4
    y = r["y"]
    align = spec.get("align", "right")
    for icon, icol, parts in lines[:spec.get("lines", 4)]:
        # lay the coloured words out in lines no wider than max_text
        rows, row, row_w = [], [], 0.0
        space = sc.text_width(" ", "heavy", size)
        for text, col in parts:
            for k, word in enumerate(text.split(" ")):
                if word == "":
                    continue
                lead = space if (row and (k > 0 or text.startswith(" "))) else 0
                ww = sc.text_width(word, "heavy", size)
                if row and row_w + lead + ww > max_text:
                    rows.append((row, row_w))
                    row, row_w, lead = [], 0.0, 0
                row.append((word, col, lead))
                row_w += lead + ww
        if row:
            rows.append((row, row_w))
        tw = max(w for _, w in rows)
        iw = size + 2
        w = 8 + iw + 6 + tw + 10
        h = len(rows) * lh + 6
        x = r["x"] + r["w"] - w if align == "right" else (r["x"] if align == "left" else r["x"] + (r["w"] - w) / 2)
        sc.rect(x, y, w, h, 8, CHIP_BG, 0.88)
        sc.medallion(icon, x + 8 + iw / 2, y + 3 + lh / 2, iw / 1.16, icol)
        for i, (words, _) in enumerate(rows):
            cx = x + 8 + iw + 6
            for word, col, lead in words:
                cx += lead
                ww = sc.text_width(word, "heavy", size)
                sc.text(cx, y + 3 + i * lh, ww + 2, lh, word, "heavy", size, col)
                cx += ww
        y += h + 4


def top_bar(sc, L, round_text):
    info = L.get("info")
    if info:
        x, y, w, h = R(info)
        sc.frame(x, y, w, h, min(10, h / 2), CHIP_BG, BRASS_DARK, 1.5, falpha=0.92)
        size = max(11, min(16, int(h * 0.5)))
        text = round_text if w >= 300 else ("Round 6  ·  First to 3" if w >= 160 else "Round 6")
        sc.text(x + 8, y, w - 16, h, text, "heavy", size, PARCH)
    b = L["buttons"]
    items = [("people", "dark"), ("map", "dark"), ("smile", "brass"), ("gear", "dark")][4 - b["count"]:]
    x = b["rect"]["x"] + b["rect"]["w"]
    for icon, style in reversed(items):
        x -= b["size"]
        sc.button(x, b["rect"]["y"] + (b["rect"]["h"] - b["size"]) / 2, b["size"], b["size"], icon=icon, style=style,
                  depth=4, corner=12, icon_scale=0.66)
        x -= b["gap"]


def roblox_chrome(sc, m):
    """Roblox's own top-bar buttons and the phone's notch / home-bar insets."""
    tb, safe = m["topbar"], m["safe"]
    h = tb["y1"] - tb["y0"]
    size = min(44 / m["scale"], h - 8)
    y = tb["y0"] + (h - size) / 2
    x = max(tb["l"] - 2 * size - 18, safe["l"] + 8)
    for i in range(2):
        bx = x + i * (size + 10)
        sc.rect(bx, y, size, size, size * 0.28, "#000000", 0.45)
        if i == 0:
            sc.rect(bx + size * 0.3, y + size * 0.3, size * 0.4, size * 0.4, 2, WHITE)
            sc.rect(bx + size * 0.42, y + size * 0.42, size * 0.16, size * 0.16, 1, "#3A3A3A")
        else:
            sc.rect(bx + size * 0.26, y + size * 0.3, size * 0.48, size * 0.32, size * 0.08, WHITE)
            sc.d.polygon([((bx + size * 0.36) * S, (y + size * 0.6) * S), ((bx + size * 0.48) * S, (y + size * 0.6) * S),
                          ((bx + size * 0.34) * S, (y + size * 0.74) * S)], fill=hex_rgba(WHITE))
    vw, vh = m["vw"], m["vh"]
    if safe["l"] > 0:
        sc.rect(0, 0, safe["l"] * 0.62, vh, 0, "#000000", 0.92)
        sc.rect(0, vh / 2 - vh * 0.2, safe["l"] * 0.8, vh * 0.4, safe["l"] * 0.3, "#000000", 1)
    if safe["r"] > 0:
        sc.rect(vw - safe["r"] * 0.62, 0, safe["r"] * 0.62, vh, 0, "#000000", 0.92)
    if safe["t"] > 0:
        sc.rect(vw / 2 - vw * 0.16, 6, vw * 0.32, safe["t"] * 0.62, safe["t"] * 0.3, "#000000", 1)
    if safe["b"] > 0:
        sc.rect(vw / 2 - vw * 0.17, vh - safe["b"] * 0.55, vw * 0.34, 5, 2.5, "#FFFFFF", 0.85)


def match_screen(data, scr, dev, out, save=True, held=None, raised=None, overlay=None):
    """The match HUD around the board. `overlay(sc, ctx)` draws over the board before the
    HUD (glows, a tile preview); held / raised go to the hand. Returns (sc, ctx)."""
    m, L = dev["m"], dev["match"]
    sc = Screen(data, w=int(round(m["vw"])), h=int(round(m["vh"])))
    sc.table()
    form = L["form"]
    to_stage, ppu, layout = draw_board(sc, data, scr, L["focus"], form)
    snap = scr["snapshot"]
    # name tag over the current pawn
    me = next(p for p in snap["players"] if p["seat"] == snap["current"])
    t = layout["tiles"][me["tile"] - 1]
    group = sorted(q["seat"] for q in snap["players"] if q["tile"] == me["tile"])
    slot = data["board"]["slots"][len(group) - 1]
    at = slot["at"][group.index(me["seat"])]
    sx, sy = to_stage(t["x"] + at[0], t["y"] + at[1] - 1.3 * 0.62 * slot["scale"])
    name_tag(sc, sx, sy - 4, "You", SEAT[0])
    ctx = {"to_stage": to_stage, "ppu": ppu, "layout": layout, "L": L, "m": m}
    if overlay:
        overlay(sc, ctx)

    player_chips(sc, scr, L["players"], snap.get("target", 3) or 3, 1)
    ctx["hand"] = hand(sc, data, L["hand"], snap["hand"], set(snap.get("armed") or []), m["touch"], held=held, raised=raised)
    ability(sc, scr, L["ability"], form, "mage")
    roll(sc, L["roll"], form, m["touch"])
    feed(sc, L["feed"], [
        ("x_mark", INK_RED, [("You", "#F3A0A0"), (" found a treasure! (1 / 3)", GOLD)]),
        ("spike", CAT["trap"], [("Bot Marlo", "#9DE09A"), (" hit ", PARCH), ("your", "#F3A0A0"), (" Spike", PARCH)]),
        ("dice", BRASS_DARK, [("Bot Pip", "#A9CBF2"), (" rolled a 4", PARCH)]),
    ])
    top_bar(sc, L, "Round 6  ·  Chaos  ·  Quick  ·  First to 3")
    roblox_chrome(sc, m)
    if save:
        sc.save(out, out_w=dev["w"] * (2 if dev["w"] < 1000 else 1))
    return sc, ctx


# ----------------------------------------------------------------------------- lobby
def profile_full(sc, r):
    x, y, w, h = R(r)
    sc.frame(x, y, w, h, 14, PANEL, BRASS_DARK, 2)
    av = h - 20
    portrait(sc, {"isBot": False}, x + 10 + av / 2, y + h / 2, av, ring=BRASS, ring_px=3, face_back=PANEL_HI)
    tx = x + av + 20
    sc.text(tx, y + h / 2 - 27, w - (tx - x) - 150, 20, "Explorer", "heavy", 18, TEXT)
    tw = sc.text_width("Trap Master", "heavy", 12)
    sc.rect(tx, y + h / 2 - 6, tw + 16, 18, 6, "#4E2E14")
    sc.text(tx + 8, y + h / 2 - 6, tw + 2, 18, "Trap Master", "heavy", 12, "#F2C445")
    sc.text(tx, y + h / 2 + 13, 40, 16, "LV 7", "chunky", 14, INFO_SOFT)
    sc.progress(tx + 44, y + h / 2 + 17, w - (tx - x) - 44 - 150, 8, 0.6, INFO)
    sc.medallion("gem", x + w - 16 - 12, y + h / 2, 24 / 1.16, NEUTRAL)
    gw = sc.text_width("1,240", "chunky", 24)
    sc.text(x + w - 16 - 24 - 6 - gw, y + h / 2 - 14, gw + 2, 28, "1,240", "chunky", 24, TEXT)


def profile_compact(sc, r):
    x, y, w, h = R(r)
    sc.frame(x, y, w, h, h / 2, PANEL, BRASS_DARK, 2)
    av = h - 8
    portrait(sc, {"isBot": False}, x + 4 + av / 2, y + h / 2, av, ring=BRASS, ring_px=2, face_back=PANEL_HI)
    sc.text(x + av + 12, y, w - av - 12 - 170, h, "Explorer", "heavy", 15, TEXT)
    sc.text(x + w - 108 - 52, y + h / 2 - 10, 52, 20, "LV 7", "chunky", 14, INFO_SOFT, align="right")
    sc.medallion("gem", x + w - 12 - 9, y + h / 2, 18 / 1.16, NEUTRAL)
    gw = sc.text_width("1,240", "chunky", 18)
    sc.text(x + w - 12 - 18 - 6 - gw, y + h / 2 - 11, gw + 2, 22, "1,240", "chunky", 18, TEXT)


MODES = [
    ("chaos", "Chaos Trapisque", "Chaos", "2-6 players", "Free-for-all. First to 5 treasures wins.", "bolt"),
    ("assist", "Assist Trapisque", "Assist", "4 players", "2 vs 2. A team wins when both teammates have 5 treasures.", "people"),
    ("factions", "Factions", "Factions", "6 players", "Three teams of 2. Both teammates need 5 treasures.", "people"),
    ("ww4", "World War Four", "WW4", "6 players", "3 vs 3. Every teammate needs 4 treasures.", "people"),
]


def play_panel(sc, r, compact, titled=True):
    x, y, w, h = R(r)
    cx, cy, cw, ch = sc.panel(x, y, w, h, title="Play" if (titled and not compact) else None, title_w=200, pad=12 if compact else 18)
    find_h, small_h = (50, 42) if compact else (58, 48)
    buttons_h = find_h + 8 + small_h
    grid_h = ch - (buttons_h + 12)
    cols, rows = (4, 1) if compact else (2, 2)
    tw, th = (cw - 12 * (cols - 1)) / cols, (grid_h - 12 * (rows - 1)) / rows
    for i, (mid, name, short, count, blurb, icon) in enumerate(MODES):
        tx, ty = cx + (i % cols) * (tw + 12), cy + (i // cols) * (th + 12)
        on = mid == "chaos"
        sc.frame(tx, ty, tw, th, 12, MINE if on else PANEL_RAISED, BRASS if on else PANEL_EDGE, 3 if on else 2)
        pad = 8 if compact else 12
        isz = 24 if compact else 34
        sc.icon(icon, tx + pad, ty + pad, isz, BRASS, PANEL_RAISED)
        tx2 = pad + isz + 8
        sc.text(tx + tx2, ty + (8 if compact else 10), tw - tx2 - pad, 22 if compact else 24, short if compact else name, "chunky",
                17 if compact else 20, TEXT, scaled=True)
        if compact:
            sc.text(tx + pad, ty + 36, tw - 2 * pad, 16, count, "heavy", 12, TEXT_SOFT)
        else:
            sc.text(tx + tx2, ty + 34, tw - tx2 - pad, 16, count, "heavy", 13, TEXT_SOFT)
        top = 56 if compact else 58
        sc.text(tx + pad, ty + top, tw - 2 * pad, th - top - pad, blurb, "body", 13 if compact else 15, TEXT, wrap=True,
                valign="top", scaled=compact)
    by = cy + ch - buttons_h
    sc.button(cx, by, cw, find_h, text="FIND A MATCH", icon="play", style="green", depth=6, size=22 if compact else 26)
    sc.button(cx, by + find_h + 8, cw / 2 - 6, small_h, text="PRACTICE", icon="dice", style="wood", size=16 if compact else 19)
    sc.button(cx + cw / 2 + 6, by + find_h + 8, cw / 2 - 6, small_h, text="PRIVATE" if compact else "PRIVATE MATCH", icon="people",
              style="blue", size=16 if compact else 19)


def party_panel(sc, r, compact, titled=True):
    x, y, w, h = R(r)
    cx, cy, cw, ch = sc.panel(x, y, w, h, title="Party" if (titled and not compact) else None, title_w=200, pad=12 if compact else 18)
    code_h, buttons_h = (54, 42) if compact else (64, 48)
    sc.frame(cx, cy, cw, code_h, 10, PANEL_DEEP, PANEL_EDGE, 2)
    sc.text(cx + 12, cy + (4 if compact else 6), cw * 0.55, 16, "PARTY CODE", "heavy", 11 if compact else 13, TEXT_SOFT)
    sc.text(cx + 12, cy + (20 if compact else 24), cw * 0.55, 30 if compact else 34, "K7QX4M", "chunky", 26 if compact else 30, BRASS_LIGHT)
    sc.choice(cx + cw * 0.58, cy + (code_h - 38) / 2, cw * 0.42 - 10, 38, [("Code", "code"), ("Invite only", "invite")], "code",
              size=15)
    members = [("Explorer", "explorer_42", True, "#9FC2E8"), ("Mika", "mika_plays", False, "#E8B39F"), ("Jojo", "jojo_rbx", False, "#B6D99A")]
    # the members list is a scrolling frame between the code box and the buttons
    list_top, list_bottom = cy + code_h + 8, cy + ch - (buttons_h + 10)
    base = sc.img
    sc.img = Image.new("RGBA", base.size, (0, 0, 0, 0))
    rh = 38 if compact else 44
    av = rh - 8
    my = list_top + 2
    for i, (name, user, leader, back) in enumerate(members):
        mw, mx = cw - 10 - 4, cx + 2
        sc.frame(mx, my, mw, rh, 10, MINE if i == 0 else PANEL_RAISED, BRASS_DARK if i == 0 else PANEL_EDGE, 1.5)
        portrait(sc, {"isBot": False}, mx + 5 + av / 2, my + rh / 2, av, ring=SEAT[i], ring_px=2, face_back=back)
        nx = mx + av + 14
        if leader:
            sc.icon("crown", nx, my + (rh - 22) / 2, 22, BRASS, PANEL)
            nx += 28
        sc.text(nx, my + (2 if compact else 4), mw - (nx - mx) - 100, 18, name + ("  (you)" if i == 0 else ""), "heavy",
                15 if compact else 16, TEXT)
        sc.text(nx, my + (20 if compact else 24), mw - (nx - mx) - 100, 15, "@" + user, "body", 11 if compact else 12, TEXT_SOFT)
        if i > 0:
            bh = rh - 10
            sc.button(mx + mw - 6 - 82, my + 5, 38, bh, icon="crown", style="brass", depth=4, icon_scale=0.66)
            sc.button(mx + mw - 6 - 38, my + 5, 38, bh, icon="close", style="red", depth=4, icon_scale=0.66)
        my += rh + 6
    sc.text(cx, my, cw, 20, "3 more can join", "body", 14, TEXT_FAINT, align="center")
    mask = Image.new("L", base.size, 0)
    ImageDraw.Draw(mask).rectangle([cx * S, list_top * S, (cx + cw) * S, list_bottom * S], fill=255)
    rows = sc.img
    rows.putalpha(Image.composite(rows.getchannel("A"), Image.new("L", base.size, 0), mask))
    sc.img = Image.alpha_composite(base, rows)
    sc.button(cx, cy + ch - buttons_h, cw * 0.62 - 6, buttons_h, text="INVITE", icon="plus", style="blue", size=18)
    sc.button(cx + cw * 0.62 + 6, cy + ch - buttons_h, cw * 0.38 - 6, buttons_h, text="LEAVE", icon="exit", style="red", size=18)


LEADERS = [("Marlo", "marlo_the_great", 214), ("Juniper", "junibug", 188), ("Pipsqueak", "pipsqueak77", 171), ("Rowan", "rowan_rbx", 150),
           ("Nib", "nibbles", 133), ("Explorer", "explorer_42", 121), ("Fennel", "fennelfox", 117), ("Quill", "quillpen", 98),
           ("Tamsin", "tamsin_t", 91), ("Odo", "odo_plays", 84)]
MEDALS = ["#E2B53C", "#B8C0C8", "#C98A4B"]


def leaderboard(sc, r, titled=True):
    x, y, w, h = R(r)
    cx, cy, cw, ch = sc.panel(x, y, w, h, title="Top Players" if titled else None, title_w=220)
    sc.choice(cx, cy, cw, 38, [("Wins", "wins"), ("Treasures", "treasures"), ("Level", "level")], "wins", size=16)
    ry = cy + 46 + 2
    bottom = cy + ch - 40
    for i, (name, user, value) in enumerate(LEADERS):
        if ry + 46 > bottom:
            break
        mine = name == "Explorer"
        rw, rx = cw - 10 - 4, cx + 2
        sc.frame(rx, ry, rw, 46, 10, MINE if mine else PANEL_RAISED, BRASS if mine else PANEL_EDGE, 2 if mine else 1.5)
        if i < 3:
            sc.frame(rx + 6, ry + 9, 28, 28, 14, MEDALS[i], shade(MEDALS[i], -0.35), 2)
        sc.text(rx + 6, ry + 9, 28, 28, str(i + 1), "chunky", 17, TEXT_ON_LIGHT if i < 3 else TEXT_SOFT, align="center")
        portrait(sc, {"isBot": False}, rx + 40 + 17, ry + 23, 34, ring=BRASS if mine else PANEL_EDGE, ring_px=2,
                 face_back=["#9FC2E8", "#E8B39F", "#B6D99A", "#E8D59F", "#C9A9E8", "#9FE0D9"][i % 6])
        name_w = rw - (82 + 58 + 12)
        sc.text(rx + 82, ry + 4, name_w, 20, name + (" (you)" if mine else ""), "heavy", 15, TEXT)
        sc.text(rx + 82, ry + 25, name_w, 16, "@" + user, "body", 12, TEXT_SOFT)
        sc.text(rx + rw - 10 - 58, ry + 10, 58, 26, format(value, ","), "chunky", 18, MEDALS[i] if i < 3 else TEXT,
                align="right")
        ry += 51
    sc.text(cx, cy + ch - 32, cw, 32, "You're #6 with 121 wins", "heavy", 15, TEXT_SOFT, align="center")


NAV = [("chests", "FREE CHEST!", "CHESTS", "chest", "green"), ("locker", "LOCKER", "LOCKER", "hanger", "wood"),
       ("shop", "SHOP", "SHOP", "bag", "wood"), ("leaders", "TOP PLAYERS", "TOP", "crown", "wood"),
       ("rules", "HOW TO PLAY", "RULES", "book", "wood"), ("settings", "SETTINGS", "SETTINGS", "gear", "wood")]


def nav(sc, spec, with_leaders):
    x, y, w, h = R(spec["rect"])
    items = [n for n in NAV if n[0] != "leaders" or with_leaders]
    n = len(items)
    gap = 14 if spec["kind"] == "full" else 8
    bw = (w - gap * (n - 1)) / n
    for i, (nid, text, short, icon, style) in enumerate(items):
        bx = x + i * (bw + gap)
        if spec["kind"] == "icon":
            size = h - 18
            sc.button(bx + (bw - size) / 2, y, size, size, icon=icon, style=style, depth=4, icon_scale=0.66)
            sc.text(bx, y + h - 14, bw, 14, short, "heavy", 11, TEXT, align="center", outline=BG, ow=1)
            if nid == "chests":
                sc.badge(bx + (bw + size) / 2 + 6, y - 8, "1", "#D9534F", h=22, size=14, anchor_right=True)
        else:
            sc.button(bx, y, bw, h, text=text if spec["kind"] == "full" else short, icon=icon, style=style,
                      size=19 if spec["kind"] == "full" else 15)
            if nid == "chests":
                # the free chest's count (Widgets button:setBadge) instead of a looping pulse
                sc.badge(bx + bw + 6, y - 8, "1", "#D9534F", h=22, size=14, anchor_right=True)


def lobby_screen(data, dev, out, tab="play", save=True):
    m, L = dev["m"], dev["lobby"]
    sc = Screen(data, w=int(round(m["vw"])), h=int(round(m["vh"])))
    sc.table()
    if L.get("title"):
        t = L["title"]
        size = int(min(60, t["h"] * 0.86))
        sc.text(t["x"], t["y"], t["w"], t["h"], "Trapisque", "display", size, BRASS_LIGHT, align="center" if L["form"] == "tall" else "left",
                outline=BG, ow=3 if t["h"] >= 60 else 2)
    if L["profile"]["kind"] == "compact":
        profile_compact(sc, L["profile"]["rect"])
    else:
        profile_full(sc, L["profile"]["rect"])
    if L.get("tabs"):
        tr = L["tabs"]
        sc.choice(tr["x"], tr["y"], tr["w"], tr["h"], [("Play", "play"), ("Party", "party"), ("Top", "leaders")], tab, size=18)
        if tab == "play":
            play_panel(sc, L["play"], False, titled=False)
        elif tab == "party":
            party_panel(sc, L["party"], False, titled=False)
        else:
            leaderboard(sc, L["leaders"], titled=False)
    else:
        play_panel(sc, L["play"], L["compact"])
        party_panel(sc, L["party"], L["compact"])
        if L.get("leaders"):
            leaderboard(sc, L["leaders"])
    nav(sc, L["nav"], L.get("leaders") is None)
    roblox_chrome(sc, m)
    if save:
        sc.save(out, out_w=dev["w"] * (2 if dev["w"] < 1000 else 1))
    return sc


# ----------------------------------------------------------------------------- tile skins
def skin_sheet(data, scr, out):
    sheet = scr["sheet"]
    cols = 5
    cell_w, cell_h = 220, 230
    rows = math.ceil(len(sheet) / cols)
    W, H = cols * cell_w + 40, rows * cell_h + 110
    sc = Screen(data, w=W, h=H)
    sc.table()
    sc.text(0, 18, W, 44, "Tiles change with whatever is on them", "display", 34, PARCH, align="center", outline=INK, ow=2)
    sc.text(0, 60, W, 24, "Traps and neutral cards reskin the tile (the card sits on top); natural hazards too.", "heavy", 16,
            WOOD_PALE, align="center")
    U = 62  # preview px per hex unit
    pts = lambda cx, cy, r: [(cx + r * math.cos(math.radians(60 * i + 30)), cy + r * math.sin(math.radians(60 * i + 30)))  # noqa: E731
                             for i in range(6)]
    from render import Layer, Canvas, draw_ops
    for i, sk in enumerate(sheet):
        cx = 20 + (i % cols) * cell_w + cell_w / 2
        cy = 100 + (i // cols) * cell_h + 88
        top = sk["top"] or "#E9BE84"
        for (r, col, dy) in ((0.93, shade(top, -0.5), 0.16), (0.93, "#4A2C14", 0), (0.88, top, 0)):
            sc.d.polygon([(px * S, py * S) for px, py in pts(cx, cy + dy * U, r * U)], fill=hex_rgba(col))
        side = 2 * U
        lay = Layer(int(side) + 8, int(side) + 8, ss=3)
        draw_ops(Canvas(lay, 4, 4, side, {"ink": hex_rgba(INK)}), sk["ops"])
        img = lay.final().resize((int((side + 8) * S), int((side + 8) * S)), Image.LANCZOS)
        sc.img.alpha_composite(img, (int((cx - side / 2 - 4) * S), int((cy - side / 2 - 4) * S)))
        if sk["category"] == "natural":
            icon = {"slime": "slime_trap", "river": "river_trap", "gate": "lock"}[sk["kind"]]
            sc.icon(icon, cx - 0.36 * U, cy - 0.36 * U, 0.72 * U, WHITE, top)
        else:
            w, h, sw = 0.6 * U, 0.8 * U, 0.07 * U
            sc.frame(cx - w / 2, cy - h / 2, w, h, 0.12 * U, "#2A1C13", SEAT[i % 4], sw)
            sc.icon(sk["kind"], cx - 0.24 * U, cy - 0.24 * U, 0.48 * U, WHITE, "#2A1C13")
        sc.text(cx - cell_w / 2, cy + 0.95 * U + 8, cell_w, 24, sk["name"], "chunky", 18, PARCH, align="center")
    sc.save(out, out_w=W * 2 // 2 * 1)


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    data = {}
    for name in ("icons", "board", "cosmetics", "cards"):
        data[name] = json.load(open(os.path.join(src, name + ".json")))
    data["looks"] = {i["id"]: i["look"] for i in data["cosmetics"]["items"]}
    data["patterns"] = data["cosmetics"]["patterns"]
    scr = json.load(open(os.path.join(src, "screens.json")))
    for dev in scr["devices"]:
        match_screen(data, scr, dev, os.path.join(outdir, "07-match-%s.png" % dev["file"]))
        lobby_screen(data, dev, os.path.join(outdir, "08-lobby-%s.png" % dev["file"]))
        if dev["lobby"].get("tabs"):
            lobby_screen(data, dev, os.path.join(outdir, "08-lobby-%s-top-players.png" % dev["file"]), tab="leaders")
        if dev["file"] == "pc":
            sc = lobby_screen(data, dev, None, save=False)
            draw_chests(sc, data)
            sc.save(os.path.join(outdir, "09-treasure-chests.png"), out_w=dev["w"])
    skin_sheet(data, scr, os.path.join(outdir, "10-tile-skins.png"))


if __name__ == "__main__":
    main()
