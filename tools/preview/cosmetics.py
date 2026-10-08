#!/usr/bin/env python3
"""Preview sheet of every collectible cosmetic (mirrors client/UI/CosmeticArt.lua).

Usage: python3 tools/preview/cosmetics.py cosmetics.json out.png
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

SEATS = ["#E35D5D", "#4E8FDB", "#5DB866", "#EDBB36", "#A56CDB", "#F0883A"]
RAINBOW = ["#FF5E5E", "#FFB13B", "#FFE45C", "#5EE07A", "#4FC3FF", "#8E7CFF", "#FF6FD8"]


def rgb(h):
    return hex_rgba(h)[:3]


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(h, amt):
    c = rgb(h)
    if amt >= 0:
        return mix(c, (255, 255, 255), amt)
    return mix(c, (0, 0, 0), -amt)


def to_hex(c):
    return "#%02X%02X%02X" % c


def gradient_img(size, stops, angle_deg):
    """Linear gradient across a square image along angle (Roblox-style rotation)."""
    w = h = size
    img = Image.new("RGBA", (w, h))
    px = img.load()
    a = math.radians(angle_deg)
    ux, uy = math.cos(a), math.sin(a)
    proj = [((x - w / 2) * ux + (y - h / 2) * uy) for x, y in ((0, 0), (w, 0), (0, h), (w, h))]
    lo, hi = min(proj), max(proj)
    n = len(stops)
    for y in range(h):
        for x in range(w):
            t = (((x - w / 2) * ux + (y - h / 2) * uy) - lo) / (hi - lo)
            f = t * (n - 1)
            i = min(int(f), n - 2)
            c = mix(stops[i], stops[i + 1], f - i)
            px[x, y] = (c[0], c[1], c[2], 255)
    return img


def disc(layer_img, cx, cy, d, fill_img=None, color=None, alpha=255):
    S = layer_img.size
    mask = Image.new("L", S, 0)
    ImageDraw.Draw(mask).ellipse([cx - d / 2, cy - d / 2, cx + d / 2, cy + d / 2], fill=alpha)
    if fill_img is None:
        fill_img = Image.new("RGBA", S, color + (255,))
    else:
        big = Image.new("RGBA", S, (0, 0, 0, 0))
        big.paste(fill_img, (int(cx - fill_img.width / 2), int(cy - fill_img.height / 2)))
        fill_img = big
    out = Image.new("RGBA", S, (0, 0, 0, 0))
    out.paste(fill_img, (0, 0), mask)
    return Image.alpha_composite(layer_img, out)


def aa_rrect(img, box, radius, fill=None, outline=None, width=0, ss=4):
    """Anti-aliased rounded rectangle; `outline` is drawn outside the box like a UIStroke."""
    x0, y0, x1, y1 = box
    m = width + 2
    W, H = int((x1 - x0 + 2 * m) * ss), int((y1 - y0 + 2 * m) * ss)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    if outline and width:
        d.rounded_rectangle([(m - width) * ss, (m - width) * ss, W - (m - width) * ss, H - (m - width) * ss],
                            radius=(radius + width) * ss, fill=outline)
    if fill:
        d.rounded_rectangle([m * ss, m * ss, W - m * ss, H - m * ss], radius=radius * ss, fill=fill)
    out = lay.resize((W // ss, H // ss), Image.LANCZOS)
    img.alpha_composite(out, (int(x0 - m), int(y0 - m)))


def draw_pawn(img, x, y, size, item, data, seat="#4E8FDB"):
    """CosmeticArt.pawn in a square (x, y, size): flat face (blend only for gradient skins),
    seat-coloured rim outside the face, and the chip edge peeking out below."""
    ss = 4
    S = int(size * ss)
    pad = int(S * 0.1)
    W = S + 2 * pad
    lay = Layer(W // ss, W // ss, ss=ss)
    look = item["look"]
    seat_c = rgb(seat)
    if look.get("fill") == "seat":
        fill, fill2 = seat_c, shade(seat, -0.22)
    elif look.get("fill") == "rainbow":
        fill, fill2 = (255, 255, 255), (255, 255, 255)
    else:
        fill = rgb(look["fill"])
        fill2 = rgb(look.get("fill2", to_hex(shade(look["fill"], -0.2))))
    accent = rgb(look.get("accent", "#FFFFFF"))
    o = pad / ss
    cv = Canvas(lay, o, o, size, {})
    side = mix(seat_c, (0, 0, 0), 0.45)
    cv.circle(0.5, 0.54, 0.92, to_hex(side))
    cv.circle(0.5, 0.47, 0.78 + 2 * 0.09 * 0.78, seat)
    if look.get("gradient"):
        stops = [rgb(h) for h in RAINBOW] if look.get("fill") == "rainbow" else [fill, fill2]
        grad = gradient_img(int(0.78 * S) + 2, stops, 60)
        lay.img = disc(lay.img, pad + 0.5 * S, pad + 0.47 * S, 0.78 * S, fill_img=grad)
    else:
        cv.circle(0.5, 0.47, 0.78, to_hex(fill))
    pat = data["patterns"].get(look.get("pattern", "ring"))
    if pat:
        colors = {"ink": accent + (255,), "acc": accent + (255,), "acc2": fill2 + (255,), "bg": fill + (255,), "hi": fill + (255,)}
        face = Canvas(lay, o + (0.5 - 0.39) * size, o + (0.47 - 0.39) * size, 0.78 * size, colors)
        draw_ops(face, pat)
    img.alpha_composite(lay.final(), (int(x - o), int(y - o)))


def draw_die(img, x, y, size, item, data, value=5):
    """CosmeticArt.die: flat face (blend only for gradient skins), edge stroke, side below."""
    ss = 4
    S = int(size * ss)
    pad = int(S * 0.1)
    W = S + 2 * pad
    lay = Layer(W // ss, W // ss, ss=ss)
    look = item["look"]
    face, face2, pip, edge = rgb(look["face"]), rgb(look["face2"]), look["pip"], look["edge"]
    o = pad / ss
    cv = Canvas(lay, o, o, size, {})
    side = mix(face2, (0, 0, 0), 0.35)
    cv.rect(0.5, 0.538, 0.924, 0.924, to_hex(side), r=0.24)
    outer = 0.84 + 2 * 0.05 * 0.84
    cv.rect(0.5, 0.462, outer, outer, edge, r=(0.22 * 0.84 + 0.042) / outer)
    if look.get("gradient"):
        grad = gradient_img(int(0.84 * S), [face, face2], 70)
        mask = Image.new("L", grad.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, grad.width - 1, grad.height - 1], radius=0.22 * grad.width, fill=255)
        lay.img.paste(grad, (int(pad + (0.5 - 0.42) * S), int(pad + (0.462 - 0.42) * S)), mask)
    else:
        cv.rect(0.5, 0.462, 0.84, 0.84, to_hex(face), r=0.22)
    fc = Canvas(lay, o + 0.08 * size, o + 0.042 * size, 0.84 * size, {})
    for p in data["pips"][value - 1]:
        fc.circle(p[0], p[1], 0.19, pip)
    img.alpha_composite(lay.final(), (int(x - o), int(y - o)))


def draw_trail(img, x, y, size, item, data):
    look = item["look"]
    layer = Layer(int(size), int(size), ss=4)
    color = hex_rgba(look.get("color", "#FFFFFF"))
    color2 = hex_rgba(look.get("color2", look.get("color", "#FFFFFF")))
    cv = Canvas(layer, 0, 0, size, {"ink": color, "acc": color2, "bg": hex_rgba("#3B2A1E")})
    kind = look["kind"]
    if kind == "none":
        draw_ops(cv, data["icons"]["close"])
    elif kind == "rainbow":
        for i in range(6):
            cv.circle(0.18 + i * 0.13, 0.62 - math.sin(i * 0.9) * 0.18, 0.16 - i * 0.012, rgb_to_hex(hsv(i / 6, 0.6, 1)))
    else:
        for i in range(3):
            px, py, d = 0.24 + i * 0.27, 0.66 - i * 0.18, 0.3 - i * 0.05
            c = "acc" if i == 1 else "ink"
            if kind == "heart":
                draw_ops(cv, [{"__args": ["group"], "s": d, "dx": px - 0.5, "dy": py - 0.5, "ops": data["icons"]["heart"], "c": c}])
            elif kind == "bubble":
                cv.ring(px, py, d, d * 0.15, c)
            elif kind == "leaf":
                cv.drop(px, py, d * 0.45, c, dir=45)
            elif kind == "sparkle":
                cv.sparkle(px, py, d, c)
            elif kind == "star":
                cv.star(px, py, d, c)
            else:
                cv.circle(px, py, d * 0.8, c)
    img.alpha_composite(layer.final(), (int(x), int(y)))


def hsv(h, s, v):
    import colorsys
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


def rgb_to_hex(c):
    return "#%02X%02X%02X" % c


def card(img, x, y, w, h, rarity_color):
    """Locker tile: flat dark panel, rarity-coloured rim, name strip along the bottom."""
    aa_rrect(img, (x, y, x + w, y + h), 14, fill=(59, 42, 30, 255), outline=rgb(rarity_color) + (255,), width=4)
    aa_rrect(img, (x + 6, y + h - 46, x + w - 6, y + h - 6), 10, fill=(42, 29, 20, 255))


def main():
    data = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    rar = {r["id"]: r for r in data["rarities"]}
    order = {r["id"]: r["order"] for r in data["rarities"]}
    cats = [("pawn", "Pawn skins"), ("dice", "Dice"), ("trail", "Trails"), ("emote", "Emotes"), ("title", "Titles")]
    cw, ch, gap = 150, 186, 14
    cols = 11
    W = cols * (cw + gap) + gap
    rows = 0
    for cat, _ in cats:
        n = len([i for i in data["items"] if i["category"] == cat])
        rows += (n + cols - 1) // cols
    H = 80 + len(cats) * 50 + rows * (ch + gap) + 20
    img = Image.new("RGBA", (W, H), hex_rgba("#22170F"))
    d = ImageDraw.Draw(img)
    d.text((gap, 18), "Treasure Chest collectibles (cosmetic only)", font=font("display", 34), fill=hex_rgba("#FFE39A"))
    lx = W - 900
    for r in data["rarities"]:
        d.rounded_rectangle([lx, 26, lx + 22, 48], radius=5, fill=hex_rgba(r["color"]))
        d.text((lx + 30, 24), r["name"], font=font("chunky", 22), fill=hex_rgba(r["color"]))
        lx += 170
    y = 80
    for cat, title in cats:
        d = ImageDraw.Draw(img)
        d.text((gap, y), title, font=font("chunky", 28), fill=hex_rgba("#E3B04B"))
        y += 44
        items = sorted([i for i in data["items"] if i["category"] == cat], key=lambda i: (order[i["rarity"]], i["name"]))
        for k, it in enumerate(items):
            col, row = k % cols, k // cols
            x0 = gap + col * (cw + gap)
            y0 = y + row * (ch + gap)
            r = rar[it["rarity"]]
            card(img, x0, y0, cw, ch, r["color"])
            seat = SEATS[k % 6]
            if cat == "pawn":
                draw_pawn(img, x0 + 25, y0 + 18, 100, it, data, seat=seat)
            elif cat == "dice":
                draw_die(img, x0 + 30, y0 + 24, 90, it, data, value=(k % 6) + 1)
            elif cat == "trail":
                draw_trail(img, x0 + 25, y0 + 18, 100, it, data)
            elif cat == "emote":
                d = ImageDraw.Draw(img)
                f = font("chunky", 22)
                txt = it["look"]["text"]
                bb = d.textbbox((0, 0), txt, font=f)
                tw = min(cw - 20, bb[2] - bb[0] + 24)
                if bb[2] - bb[0] + 24 > cw - 20:
                    f = font("chunky", 22 * (cw - 44) / (bb[2] - bb[0]))
                    bb = d.textbbox((0, 0), txt, font=f)
                bx, by = x0 + cw / 2 - tw / 2, y0 + 50
                aa_rrect(img, (bx, by, bx + tw, by + 40), 12, fill=hex_rgba("#F3E4C1"), outline=hex_rgba(it["look"]["color"]), width=3)
                d = ImageDraw.Draw(img)
                d.text((x0 + cw / 2 - (bb[2] - bb[0]) / 2 - bb[0], by + 20 - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f, fill=hex_rgba("#3A2414"))
            elif cat == "title":
                # CosmeticArt.title: the text on a dark nameplate filling 90% x 30% of the preview
                txt = it["look"]["text"]
                if txt:
                    px0, py0, pw_, ph_ = x0 + 10, y0 + 45, cw - 20, 38
                    aa_rrect(img, (px0, py0, px0 + pw_, py0 + ph_), 6, fill=hex_rgba("#4E2E14"))
                    d = ImageDraw.Draw(img)
                    f = font("body", 20)
                    bb = d.textbbox((0, 0), txt, font=f)
                    if bb[2] - bb[0] > pw_ - 16:
                        f = font("body", 20 * (pw_ - 16) / (bb[2] - bb[0]))
                        bb = d.textbbox((0, 0), txt, font=f)
                    d.text((x0 + cw / 2 - (bb[2] - bb[0]) / 2 - bb[0], py0 + ph_ / 2 - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f,
                           fill=hex_rgba(it["look"]["color"]))
            d = ImageDraw.Draw(img)
            f = font("body", 16)
            nm = it["name"]
            bb = d.textbbox((0, 0), nm, font=f)
            if bb[2] - bb[0] > cw - 16:
                f = font("body", 16 * (cw - 16) / (bb[2] - bb[0]))
                bb = d.textbbox((0, 0), nm, font=f)
            d.text((x0 + cw / 2 - (bb[2] - bb[0]) / 2 - bb[0], y0 + ch - 40), nm, font=f, fill=hex_rgba("#FFF5DE"))
            tag = r["name"].upper()
            if it["source"] == "vip":
                tag = "VIP PASS"
            elif it["source"] == "emotepack":
                tag = "EMOTE PACK"
            elif it["source"] == "default":
                tag = "STARTER"
            f2 = font("chunky", 13)
            bb = d.textbbox((0, 0), tag, font=f2)
            d.text((x0 + cw / 2 - (bb[2] - bb[0]) / 2 - bb[0], y0 + ch - 20), tag, font=f2, fill=hex_rgba(r["color"]))
        y += ((len(items) + cols - 1) // cols) * (ch + gap) + 10
    img.convert("RGB").save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    main()
