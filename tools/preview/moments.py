#!/usr/bin/env python3
"""Previews of reading and playing a card (developer preview tool).

Built on the match screen from hud.py (same Layout rects, board and HUD), with what
CardTip, BoardView:highlight / previewTile and Overlays.heldCard / Effects.place draw:

  11-card-hover-pc.png   hovering a card: it rises out of the hand with its rules
  12-placing-pc.png      placing it: glowing tiles, the tile under the card shows what
                         it'll look like, the card rides on the pointer
  13-placing-slam.gif    letting go: the card is slapped onto the tile, with the ring of
                         dust and the jolt, and the tile takes its new look

Usage: python3 tools/preview/moments.py <dir with icons/board/cosmetics/cards/screens .json> <outdir>
"""
import json
import math
import os
import sys
import textwrap

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font  # noqa: E402
from cards import CardPainter  # noqa: E402
import hud  # noqa: E402
from screens import (Screen, S, shade, BRASS, BRASS_LIGHT, BRASS_DARK, WHITE, CAT, PANEL_DEEP, PANEL_EDGE,  # noqa: E402
                     TEXT, TEXT_SOFT, TEXT_FAINT, mix)
from PIL import Image, ImageDraw  # noqa: E402

TILE_SCALE = 0.88
GAP = 10
INFO_W = 264
CATEGORY_LABEL = {"trap": "TRAP", "assist": "ASSIST", "neutral": "NEUTRAL", "potion": "POTION", "natural": "NATURAL"}


def hexagon_pts(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * i + 30)), cy + r * math.sin(math.radians(60 * i + 30))) for i in range(6)]


def wrap_lines(sc, txt, kind, size, width):
    """The line breaks Screen.text(wrap=True) makes."""
    f = font(kind, size * S)
    avg = sc.d.textbbox((0, 0), "abcdefghijklmnopqrstuvwxyz", font=f)
    cpl = max(4, int(width * S / ((avg[2] - avg[0]) / 26)))
    return textwrap.wrap(txt, cpl) or [""]


def cursor(sc, x, y, scale=1.0):
    """A mouse pointer, so it's clear where the player is pointing."""
    pts = [(0, 0), (0, 17), (4.5, 13), (8, 20), (11, 18.5), (7.5, 12), (13, 12)]
    poly = [((x + px * scale) * S, (y + py * scale) * S) for px, py in pts]
    sc.d.polygon(poly, fill=hex_rgba("#FFFFFF"), outline=hex_rgba("#111111"), width=max(1, int(1.6 * S)))


def card_img(painter, item, w):
    lay = Image.new("RGBA", (int((w + 20) * S), int((w / 0.72 + 20) * S)), (0, 0, 0, 0))
    painter.item_front(lay, 10 * S, 10 * S, w * S, item)
    return lay


def paste_card(sc, painter, item, cx, cy, w, rot=0.0, alpha=1.0):
    img = card_img(painter, item, w)
    if rot:
        img = img.rotate(rot, resample=Image.BICUBIC, expand=True)
    if alpha < 1:
        a = img.getchannel("A").point(lambda v: int(v * alpha))
        img.putalpha(a)
    sc.img.alpha_composite(img, (int(cx * S - img.width / 2), int(cy * S - img.height / 2)))


# --------------------------------------------------------------------- CardTip
def info_height(sc, info, use_text, hint, w):
    inner = w - 24
    h = 10 + 30 + 6
    h += len(wrap_lines(sc, info["text"], "body", 16, inner)) * 16 * 1.2 + 6
    how = (str(info["price"]) + " coins at the Potion Seller") if info.get("price") else use_text.get(info["use"], "")
    if how:
        h += len(wrap_lines(sc, how, "heavy", 13, inner)) * 13 * 1.2 + 6
    if hint:
        h += 2 + 6 + len(wrap_lines(sc, hint, "heavy", 15, inner)) * 15 * 1.2
    return h + 12, how


def draw_info(sc, info, item, x, y, w, h, how, hint, ready):
    color = CAT.get(info["category"], BRASS)
    sc.frame(x, y, w, h, 12, PANEL_DEEP, color, 2)
    cx, cy = x + 12, y + 10
    sc.medallion(item, cx + 15, cy + 15, 30 / 1.16, color)
    sc.text(cx + 38, cy, w - 24 - 112, 30, info["name"], "chunky", 19, TEXT)
    sc.badge(x + w - 12, cy + 4, CATEGORY_LABEL.get(info["category"], ""), color, h=22, size=13, anchor_right=True)
    cy += 36
    inner = w - 24
    lines = wrap_lines(sc, info["text"], "body", 16, inner)
    sc.text(cx, cy, inner, len(lines) * 16 * 1.2, info["text"], "body", 16, TEXT, wrap=True, valign="top")
    cy += len(lines) * 16 * 1.2 + 6
    if how:
        n = len(wrap_lines(sc, how, "heavy", 13, inner))
        sc.text(cx, cy, inner, n * 13 * 1.2, how, "heavy", 13, TEXT_SOFT, wrap=True, valign="top")
        cy += n * 13 * 1.2 + 6
    if hint:
        sc.rect(cx, cy, inner, 2, 1, PANEL_EDGE, 0.8)
        cy += 8
        n = len(wrap_lines(sc, hint, "heavy", 15, inner))
        sc.text(cx, cy, inner, n * 15 * 1.2, hint, "heavy", 15, BRASS_LIGHT if ready else TEXT_FAINT, wrap=True, valign="top")


def card_tip(sc, painter, scr, item, anchor, hint, ready):
    """CardTip:show + _arrange, side "up", rules beside the big card."""
    ax, ay, aw, ah = anchor
    info = scr["itemInfo"][item]
    card_w = max(116, min(186, int(aw * 1.5)))
    card_h = int(card_w / 0.72)
    info_w = min(INFO_W, int(sc.w - card_w - 3 * GAP - 16))
    info_h, how = info_height(sc, info, scr["useText"], hint, info_w)
    info_h = max(info_h, min(card_h, 150))
    w, h = card_w + GAP + info_w, max(card_h, info_h)
    cx = ax + aw / 2
    rules_right = cx + card_w / 2 + GAP + info_w <= sc.w - 8
    card_x = 0 if rules_right else info_w + GAP
    x = max(8, min(cx - card_w / 2 - card_x, sc.w - w - 8))
    y = max(8, ay - 8 - h)
    paste_card(sc, painter, item, x + card_x + card_w / 2, y + h - card_h / 2, card_w)
    ix = x + (card_w + GAP if rules_right else 0)
    draw_info(sc, info, item, ix, y + h - info_h, info_w, info_h, how, hint, ready)


# --------------------------------------------------------------------- placing
def tile_look(sc, ctx, scr, tile, kind, alpha=1.0, scale=1.0, owner_color=None, ghost_rim=None):
    """A tile reskinned for `kind` (the TileSkins ops recorded by dump_screens), with the
    little card on it. ghost_rim draws BoardView:previewTile's coloured rim."""
    layout, to_stage, ppu = ctx["layout"], ctx["to_stage"], ctx["ppu"]
    t = layout["tiles"][tile - 1]
    cx, cy = to_stage(t["x"], t["y"])
    sheet = {s["kind"]: s for s in scr["sheet"]}
    sk = sheet[kind]
    u = ppu * scale
    side = 2 * u
    pad = 6
    lay = Image.new("RGBA", (int((side + 2 * pad) * S), int((side + 2 * pad) * S)), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    o = (side / 2 + pad) * S
    if ghost_rim:
        d.polygon([(o + px * S, o + py * S) for px, py in hexagon_pts(0, 0, TILE_SCALE * 1.06 * u)], fill=hex_rgba(ghost_rim))
    d.polygon([(o + px * S, o + py * S) for px, py in hexagon_pts(0, 0, TILE_SCALE * u)], fill=hex_rgba(sk["top"] or "#E9BE84"))
    skin = Layer(int(side * S) + 8, int(side * S) + 8, ss=1)
    draw_ops(Canvas(skin, 4, 4, side * S, {"ink": hex_rgba("#4A3020")}), sk["ops"])
    lay.alpha_composite(skin.final(), (int(pad * S) - 4, int(pad * S) - 4))
    # the little card (BoardView plaque): 0.6 x 0.8 units, owner-coloured rim
    pw, ph, sw = 0.6 * u, 0.8 * u, 0.07 * u
    rim = owner_color or ghost_rim or BRASS
    d = ImageDraw.Draw(lay)
    d.rounded_rectangle([o - (pw / 2 + sw) * S, o - (ph / 2 + sw) * S, o + (pw / 2 + sw) * S, o + (ph / 2 + sw) * S],
                        radius=(0.12 * u + sw) * S, fill=hex_rgba(rim))
    d.rounded_rectangle([o - pw / 2 * S, o - ph / 2 * S, o + pw / 2 * S, o + ph / 2 * S], radius=0.12 * u * S, fill=hex_rgba("#2A1C13"))
    isz = 0.48 * u
    ic = Layer(int(isz * S) + 8, int(isz * S) + 8, ss=3)
    colors = {"ink": hex_rgba(WHITE), "bg": hex_rgba("#2A1C13"), "acc": hex_rgba(WHITE), "acc2": hex_rgba(WHITE), "hi": hex_rgba("#2A1C13")}
    draw_ops(Canvas(ic, 4, 4, isz * S, colors), sc.icons[kind])
    lay.alpha_composite(ic.final(), (int(o - isz / 2 * S) - 4, int(o - isz / 2 * S) - 4))
    if alpha < 1:
        lay.putalpha(lay.getchannel("A").point(lambda v: int(v * alpha)))
    sc.img.alpha_composite(lay, (int((cx - side / 2 - pad) * S), int((cy - side / 2 - pad) * S)))
    return cx, cy


def glows(sc, ctx, tiles, color, alpha=0.5):
    layout, to_stage, ppu = ctx["layout"], ctx["to_stage"], ctx["ppu"]
    lay = Image.new("RGBA", sc.img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for tid in tiles:
        t = layout["tiles"][tid - 1]
        cx, cy = to_stage(t["x"], t["y"])
        d.polygon([(px * S, py * S) for px, py in hexagon_pts(cx, cy, TILE_SCALE * 1.1 * ppu)], fill=hex_rgba(color, int(255 * alpha)))
    sc.img = Image.alpha_composite(sc.img, lay)


def hint_strip(sc, L, text):
    """MatchScreen:_hint: the strip across the top of the board with CANCEL."""
    r = L["hint"]
    h = max(44, r["h"])
    sc.frame(r["x"], r["y"], r["w"], h, 12, PANEL_DEEP, BRASS, 2)
    bw = 86 if r["w"] < 420 else 110
    sc.button(r["x"] + r["w"] - 6 - bw, r["y"] + 6, bw, h - 12, text="CANCEL", style="red", size=15)
    sc.text(r["x"] + 12, r["y"], r["w"] - (24 + bw + 6), h, text, "heavy", 13 if r["w"] < 420 else 16, TEXT)


def pick_target(scr, ctx):
    """A glowing tile near the middle of the board's lower row, clear of pawns."""
    layout = ctx["layout"]
    taken = {p["tile"] for p in scr["snapshot"]["players"]}
    valid = [t for t in scr["valid"]["spike"] if t not in taken]
    tb = layout["tileBounds"]
    mx = (tb["x0"] + tb["x1"]) / 2
    best = min(valid, key=lambda t: abs(layout["tiles"][t - 1]["x"] - mx) + 0.6 * abs(layout["tiles"][t - 1]["y"] - tb["y1"]))
    return best, valid


# --------------------------------------------------------------------- scenes
def hover_scene(data, scr, dev, out, painter):
    sc, ctx = hud.match_screen(data, scr, dev, None, save=False, raised=0)
    x, y, w, h = ctx["hand"][0]
    card_tip(sc, painter, scr, "spike", (x, y - 6, w, h), "Click it, or drag it onto a glowing tile.", True)
    cursor(sc, x + w * 0.58, y + h * 0.42)
    sc.save(out, out_w=dev["w"])


def placing_scene(data, scr, dev, out, painter):
    state = {}

    def overlay(sc, ctx):
        target, valid = pick_target(scr, ctx)
        state["target"] = target
        glows(sc, ctx, valid, CAT["trap"], 0.48)
        state["spot"] = tile_look(sc, ctx, scr, target, "spike", alpha=0.7, scale=1.04, ghost_rim=CAT["trap"])

    sc, ctx = hud.match_screen(data, scr, dev, None, save=False, held=0, overlay=overlay)
    hint_strip(sc, ctx["L"], "Click a glowing tile for Spike (right-click: cancel)")
    tx, ty = state["spot"]
    w = max(70, min(120, ctx["L"]["hand"]["card"]["w"]))
    # the held card over a tile it can go on (Overlays.heldCard:over): shrunk and lifted off
    # beside the pointer, leaning a little, so the tile shows what it'll become
    px, py = tx + 6, ty - 4
    paste_card(sc, painter, "spike", px + 0.42 * w, py - 0.62 * w, w * 0.66, rot=-7)
    cursor(sc, px, py)
    sc.save(out, out_w=dev["w"])


def slam_gif(data, scr, dev, out, painter):
    """The moment of letting go, cropped around the tile, as a short loop."""
    state = {}

    def overlay(sc, ctx):
        state["target"], _ = pick_target(scr, ctx)

    base, ctx = hud.match_screen(data, scr, dev, None, save=False, held=0, overlay=overlay)
    target = state["target"]
    t = ctx["layout"]["tiles"][target - 1]
    tx, ty = ctx["to_stage"](t["x"], t["y"])
    ppu = ctx["ppu"]
    cw, ch = 520, 330
    cx0, cy0 = int(max(0, min(tx - cw / 2, base.w - cw))), int(max(0, min(ty - ch * 0.6, base.h - ch)))
    base_img = base.img.copy()
    w = max(70, min(120, ctx["L"]["hand"]["card"]["w"]))
    frames, durations = [], []

    def frame(draw, dur, jolt=(0, 0)):
        sc = Screen(data, w=base.w, h=base.h)
        sc.img = base_img.copy()
        draw(sc)
        crop = sc.img.crop((int((cx0 + jolt[0]) * S), int((cy0 + jolt[1]) * S), int((cx0 + jolt[0] + cw) * S), int((cy0 + jolt[1] + ch) * S)))
        frames.append(crop.convert("RGB"))
        durations.append(dur)

    def ghost(sc):
        tile_look(sc, ctx, scr, target, "spike", alpha=0.7, scale=1.04, ghost_rim=CAT["trap"])

    # 1. over the tile: the card is lifted off beside the pointer, the tile shows its new look
    for i, (dx, dy, rot) in enumerate([(30, -26, -8), (16, -14, -6), (6, -4, -4)]):
        def f(sc, dx=dx, dy=dy, rot=rot):
            px, py = tx + dx, ty + dy
            ghost(sc)
            paste_card(sc, painter, "spike", px + 0.42 * w, py - 0.62 * w, w * 0.66, rot=rot)
            cursor(sc, px, py)
        frame(f, 420 if i == 2 else 90)
    # 2. click: it's lifted a touch, then slapped down
    def lift(sc):
        ghost(sc)
        paste_card(sc, painter, "spike", tx, ty - 14, w * 0.9, rot=0)
        cursor(sc, tx + 6, ty - 4)
    frame(lift, 90)
    def slap(sc):
        ghost(sc)
        paste_card(sc, painter, "spike", tx, ty - 2, w * 0.5, rot=0)
        cursor(sc, tx + 6, ty - 4)
    frame(slap, 70)
    # 3. impact: the tile takes its look, a ring and dust go out, the board jolts
    dust = [(math.cos(i / 9 * math.tau + 0.3), math.sin(i / 9 * math.tau + 0.3)) for i in range(9)]
    for k, (ring_r, dust_d, alpha, jolt, settle) in enumerate([(0.7, 0.15, 1.0, (3, -2), 1.08), (1.2, 0.45, 0.85, (-3, 2), 1.05),
                                                              (1.7, 0.75, 0.6, (2, 1), 1.02), (2.1, 0.95, 0.35, (0, 0), 1.0),
                                                              (2.4, 1.05, 0.12, (0, 0), 1.0)]):
        def f(sc, ring_r=ring_r, dust_d=dust_d, alpha=alpha, settle=settle):
            tile_look(sc, ctx, scr, target, "spike", alpha=1.0, scale=settle, owner_color=hud.SEAT[0])
            r = ring_r * ppu / 2
            sc.outline(tx - r, ty - r, 2 * r, 2 * r, r, CAT["trap"], 5 * alpha + 1, alpha)
            for dx, dy in dust:
                px, py = tx + dx * dust_d * ppu, ty + 0.25 * ppu + dy * dust_d * ppu
                dd = 0.15 * ppu * (1 - 0.6 * (dust_d / 1.05))
                sc.rect(px - dd / 2, py - dd / 2, dd, dd, dd / 2, "#CDB894", alpha)
            cursor(sc, tx + 6, ty - 4)
        frame(f, 60 if k < 4 else 80, jolt)
    # 4. placed
    def done(sc):
        tile_look(sc, ctx, scr, target, "spike", alpha=1.0, owner_color=hud.SEAT[0])
        cursor(sc, tx + 6, ty - 4)
    frame(done, 1400)
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=True)
    print("wrote", out, frames[0].size, len(frames), "frames")


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    data = {}
    for name in ("icons", "board", "cosmetics", "cards"):
        data[name] = json.load(open(os.path.join(src, name + ".json")))
    data["looks"] = {i["id"]: i["look"] for i in data["cosmetics"]["items"]}
    data["patterns"] = data["cosmetics"]["patterns"]
    scr = json.load(open(os.path.join(src, "screens.json")))
    painter = CardPainter(data["cards"])
    pc = next(d for d in scr["devices"] if d["file"] == "pc")
    hover_scene(data, scr, pc, os.path.join(outdir, "11-card-hover-pc.png"), painter)
    placing_scene(data, scr, pc, os.path.join(outdir, "12-placing-pc.png"), painter)
    slam_gif(data, scr, pc, os.path.join(outdir, "13-placing-slam.gif"), painter)


if __name__ == "__main__":
    main()
