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


def draw_pawn(img, x, y, size, item, data, seat="#4E8FDB"):
    """Draw a pawn whose bounding square is (x, y, size)."""
    ss = 4
    S = int(size * ss)
    pad = int(S * 0.15)
    W = S + 2 * pad
    lay = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    look = item["look"]
    c0 = pad + S / 2
    U = lambda v: v * S  # noqa: E731
    seat_c = rgb(seat)
    if look.get("fill") == "seat":
        fill, fill2 = seat_c, shade(seat, -0.22)
    elif look.get("fill") == "rainbow":
        fill, fill2 = (255, 255, 255), (255, 255, 255)
    else:
        fill = rgb(look["fill"])
        fill2 = rgb(look.get("fill2", to_hex(shade(look["fill"], -0.2))))
    accent = rgb(look.get("accent", "#FFFFFF"))
    # shadow
    sh = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([c0 - U(0.4), c0 + U(0.42) - U(0.1), c0 + U(0.4), c0 + U(0.42) + U(0.1)], fill=(0, 0, 0, 90))
    lay = Image.alpha_composite(lay, sh.filter(ImageFilter.GaussianBlur(U(0.03))))
    if look.get("glow"):
        g = rgb(look["glow"])
        gl = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        ImageDraw.Draw(gl).ellipse([c0 - U(0.56), c0 - U(0.56), c0 + U(0.56), c0 + U(0.56)], fill=g + (120,))
        lay = Image.alpha_composite(lay, gl.filter(ImageFilter.GaussianBlur(U(0.05))))
    side = mix(seat_c, (0, 0, 0), 0.45)
    lay = disc(lay, c0, c0 + U(0.07), U(0.88) + U(0.0792) * 2, color=side)
    # seat ring (outer stroke) then gradient face
    lay = disc(lay, c0, c0, U(0.88) + U(0.0792) * 2, color=seat_c)
    if look.get("fill") == "rainbow":
        stops = [rgb(h) for h in RAINBOW]
    else:
        stops = [mix(fill, (255, 255, 255), 0.12), fill, fill2]
    grad = gradient_img(int(U(0.88)) + 2, stops, 60)
    lay = disc(lay, c0, c0, U(0.88), fill_img=grad)
    # pattern
    pat = data["patterns"].get(look.get("pattern", "ring"))
    if pat:
        sub = Layer(W // ss, W // ss, ss=ss)
        sub.img = lay
        colors = {"ink": accent + (255,), "acc": accent + (255,), "acc2": fill2 + (255,), "bg": fill + (255,), "hi": fill + (255,)}
        cv = Canvas(sub, (c0 - U(0.44)) / ss, (c0 - U(0.44)) / ss, U(0.88) / ss, colors)
        draw_ops(cv, pat)
        lay = sub.img
    # shine
    shine = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sx, sy = c0 + (0.33 - 0.5) * U(0.88), c0 + (0.27 - 0.5) * U(0.88)
    ImageDraw.Draw(shine).rounded_rectangle([sx - U(0.15), sy - U(0.057), sx + U(0.15), sy + U(0.057)], radius=U(0.057),
                                            fill=(255, 255, 255, 165 if look.get("shine") else 95))
    shine = shine.rotate(35, resample=Image.BICUBIC, center=(sx, sy))
    lay = Image.alpha_composite(lay, shine)
    out = lay.resize((W // ss, W // ss), Image.LANCZOS)
    img.alpha_composite(out, (int(x - pad / ss), int(y - pad / ss)))


def draw_die(img, x, y, size, item, data, value=5):
    ss = 4
    S = int(size * ss)
    pad = int(S * 0.15)
    W = S + 2 * pad
    lay = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    look = item["look"]
    U = lambda v: v * S  # noqa: E731
    c0 = pad + S / 2
    face, face2, pip, edge = rgb(look["face"]), rgb(look["face2"]), rgb(look["pip"]), rgb(look["edge"])
    d = ImageDraw.Draw(lay)
    if look.get("glow"):
        gl = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        ImageDraw.Draw(gl).rounded_rectangle([c0 - U(0.55), c0 - U(0.55), c0 + U(0.55), c0 + U(0.55)], radius=U(0.24), fill=rgb(look["glow"]) + (110,))
        lay = Image.alpha_composite(lay, gl.filter(ImageFilter.GaussianBlur(U(0.05))))
        d = ImageDraw.Draw(lay)
    side = mix(face2, (0, 0, 0), 0.35)
    d.rounded_rectangle([c0 - U(0.46), c0 - U(0.46) + U(0.06), c0 + U(0.46), c0 + U(0.46) + U(0.06)], radius=U(0.2), fill=side + (255,))
    grad = gradient_img(int(U(0.92)), [mix(face, (255, 255, 255), 0.1), face, face2], 70)
    mask = Image.new("L", grad.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, grad.width - 1, grad.height - 1], radius=U(0.2), fill=255)
    lay.paste(grad, (int(c0 - U(0.46)), int(c0 - U(0.46))), mask)
    d = ImageDraw.Draw(lay)
    d.rounded_rectangle([c0 - U(0.46), c0 - U(0.46), c0 + U(0.46), c0 + U(0.46)], radius=U(0.2), outline=edge + (255,), width=max(1, int(U(0.046))))
    for p in data["pips"][value - 1]:
        px, py = c0 - U(0.46) + p[0] * U(0.92), c0 - U(0.46) + p[1] * U(0.92)
        r = U(0.19) * 0.92 / 2
        d.ellipse([px - r, py - r, px + r, py + r], fill=pip + (255,))
    out = lay.resize((W // ss, W // ss), Image.LANCZOS)
    img.alpha_composite(out, (int(x - pad / ss), int(y - pad / ss)))


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


def card(img, x, y, w, h, rarity_color, glow):
    d = ImageDraw.Draw(img)
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).rounded_rectangle([x + 3, y + 6, x + w + 3, y + h + 6], radius=14, fill=(0, 0, 0, 110))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(5)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x, y, x + w, y + h], radius=14, fill=(59, 42, 30, 255))
    gl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gl).ellipse([x + w * 0.1, y + h * 0.05, x + w * 0.9, y + h * 0.75], fill=rgb(glow) + (70,))
    img.alpha_composite(gl.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x, y, x + w, y + h], radius=14, outline=rgb(rarity_color) + (255,), width=4)
    d.rounded_rectangle([x + 6, y + h - 46, x + w - 6, y + h - 6], radius=10, fill=(42, 29, 20, 255))


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
            card(img, x0, y0, cw, ch, r["color"], r["glow"])
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
                d.rounded_rectangle([bx, by, bx + tw, by + 40], radius=12, fill=hex_rgba("#F3E4C1"), outline=hex_rgba(it["look"]["color"]), width=3)
                d.polygon([(bx + tw * 0.3, by + 38), (bx + tw * 0.3 + 14, by + 38), (bx + tw * 0.3 + 2, by + 52)], fill=hex_rgba("#F3E4C1"))
                d.text((x0 + cw / 2 - (bb[2] - bb[0]) / 2 - bb[0], by + 20 - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f, fill=hex_rgba("#3A2414"))
            elif cat == "title":
                d = ImageDraw.Draw(img)
                txt = it["look"]["text"] or "(none)"
                f = font("body", 22)
                bb = d.textbbox((0, 0), txt, font=f)
                if bb[2] - bb[0] > cw - 20:
                    f = font("body", 22 * (cw - 20) / (bb[2] - bb[0]))
                    bb = d.textbbox((0, 0), txt, font=f)
                col_t = hex_rgba(it["look"]["color"]) if it["look"]["text"] else hex_rgba("#7B5B3E")
                d.text((x0 + cw / 2 - (bb[2] - bb[0]) / 2 - bb[0], y0 + 64 - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f, fill=col_t)
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
