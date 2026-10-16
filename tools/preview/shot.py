#!/usr/bin/env python3
"""
Draws screenshots of the game from the GUI dumps printed by tests/fake/shots.luau
("@@SHOT <json>" lines): every frame, corner, outline, gradient and text the game's own
Lua built, in Roblox's drawing order.

Usage:
    luau build/shots.run.luau | python3 tools/preview/shot.py OUT_DIR [--scale 1]

Fonts come from tools/preview/fonts (or the folder named by TRAPISQUE_FONTS); a
family that isn't there falls back to Nunito.
"""
import json
import math
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = os.environ.get("TRAPISQUE_FONTS", os.path.join(HERE, "fonts"))
SS = 2  # supersampling

# Roblox font family -> file (and whether it's a variable-weight font)
FONT_FILES = {
    "LuckiestGuy": ["LuckiestGuy-Regular.ttf"],
    "Nunito": ["Nunito[wght].ttf", "Nunito-Regular.ttf"],
    "FredokaOne": ["FredokaOne-Regular.ttf"],
    "Bangers": ["Bangers-Regular.ttf"],
    "PatrickHand": ["PatrickHand-Regular.ttf"],
    "PermanentMarker": ["PermanentMarker-Regular.ttf"],
    "SpecialElite": ["SpecialElite-Regular.ttf"],
    "Oswald": ["Oswald[wght].ttf"],
    "Merriweather": ["Merriweather[opsz,wdth,wght].ttf"],
    "Kalam": ["Kalam-Bold.ttf", "Kalam-Regular.ttf"],
    "AmaticSC": ["AmaticSC-Bold.ttf"],
    "DenkOne": ["DenkOne-Regular.ttf"],
    "Fondamento": ["Fondamento-Regular.ttf"],
    "PirataOne": ["PirataOne-Regular.ttf"],
    "Rye": ["Rye-Regular.ttf"],
    "BuilderSans": ["Nunito[wght].ttf"],
}
WEIGHTS = {"Thin": 100, "ExtraLight": 200, "Light": 300, "Regular": 400, "Medium": 500, "SemiBold": 600, "Bold": 700, "ExtraBold": 800, "Heavy": 900}
_font_cache = {}


def get_font(family, weight, size):
    size = max(1, int(round(size)))
    key = (family, weight, size)
    f = _font_cache.get(key)
    if f:
        return f
    files = FONT_FILES.get(family) or FONT_FILES["Nunito"]
    path = None
    for name in files:
        p = os.path.join(FONT_DIR, name)
        if os.path.exists(p) and os.path.getsize(p) > 1000:
            path = p
            break
    if path is None:
        for name in FONT_FILES["Nunito"]:
            p = os.path.join(FONT_DIR, name)
            if os.path.exists(p):
                path = p
                break
    f = ImageFont.truetype(path, size)
    if "[" in os.path.basename(path):
        try:
            axes = f.get_variation_axes()
            vals = []
            for ax in axes:
                nm = ax.get("name", b"")
                nm = nm.decode() if isinstance(nm, bytes) else str(nm)
                if nm.lower().startswith("weight") or nm == "wght":
                    vals.append(max(ax["minimum"], min(ax["maximum"], WEIGHTS.get(weight, 400))))
                else:
                    vals.append(ax.get("default", ax["minimum"]))
            f.set_variation_by_axes(vals)
        except Exception:
            pass
    _font_cache[key] = f
    return f


RICH = re.compile(r"<[^>]+>")


def strip_rich(s):
    return RICH.sub("", s).replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&").replace("&quot;", '"')


def rich_runs(s, color):
    """[(text, color)] from <font color="#hex">...</font> (other tags dropped)."""
    runs = []
    stack = [tuple(color)]
    pos = 0
    for m in re.finditer(r"<(/?)([a-zA-Z]+)([^>]*)>", s):
        if m.start() > pos:
            runs.append((s[pos:m.start()], stack[-1]))
        pos = m.end()
        closing, tag, attrs = m.group(1), m.group(2).lower(), m.group(3)
        if tag == "font":
            if closing:
                if len(stack) > 1:
                    stack.pop()
            else:
                cm = re.search(r'color\s*=\s*"#?([0-9a-fA-F]{6})"', attrs)
                if cm:
                    h = cm.group(1)
                    stack.append((int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)))
                else:
                    stack.append(stack[-1])
    if pos < len(s):
        runs.append((s[pos:], stack[-1]))
    return [(strip_rich(t), c) for t, c in runs if t]


def text_width(font, s):
    if not s:
        return 0
    return font.getlength(s)


def wrap_runs(runs, font, max_w):
    """Breaks coloured runs into lines no wider than max_w (None = no wrapping)."""
    lines = [[]]
    width = 0.0
    for text, color in runs:
        parts = re.split(r"(\n| )", text)
        for part in parts:
            if part == "\n":
                lines.append([])
                width = 0.0
                continue
            if part == "":
                continue
            w = text_width(font, part)
            if max_w is not None and width + w > max_w and width > 0 and part != " ":
                lines.append([])
                width = 0.0
            if part == " " and width == 0 and len(lines) > 1:
                continue
            lines[-1].append((part, color))
            width += w
    return lines


def line_width(font, line):
    return sum(text_width(font, t) for t, _ in line)


def gradient_image(w, h, gr, base):
    """The UIGradient as an RGBA image: colour multiplies `base`, transparency multiplies alpha."""
    img = Image.new("RGBA", (max(1, w), max(1, h)))
    px = img.load()
    rot = math.radians(gr.get("rot", 0))
    dx, dy = math.cos(rot), math.sin(rot)
    ox, oy = gr.get("ox", 0), gr.get("oy", 0)
    ck = gr["c"]
    tk = gr["t"]

    def sample_c(t):
        for i in range(len(ck) - 1):
            a, b = ck[i], ck[i + 1]
            if a[0] <= t <= b[0]:
                u = 0 if b[0] == a[0] else (t - a[0]) / (b[0] - a[0])
                return [a[1 + k] + (b[1 + k] - a[1 + k]) * u for k in range(3)]
        return ck[-1][1:4] if t > ck[-1][0] else ck[0][1:4]

    def sample_t(t):
        for i in range(len(tk) - 1):
            a, b = tk[i], tk[i + 1]
            if a[0] <= t <= b[0]:
                u = 0 if b[0] == a[0] else (t - a[0]) / (b[0] - a[0])
                return a[1] + (b[1] - a[1]) * u
        return tk[-1][1] if t > tk[-1][0] else tk[0][1]

    step = max(1, min(w, h) // 64)
    for y in range(0, h, step):
        for x in range(0, w, step):
            u = (x + 0.5) / w - 0.5 - ox
            v = (y + 0.5) / h - 0.5 - oy
            t = max(0.0, min(1.0, u * dx + v * dy + 0.5))
            c = sample_c(t)
            tr = sample_t(t)
            col = (int(base[0] * c[0] / 255), int(base[1] * c[1] / 255), int(base[2] * c[2] / 255), int(255 * (1 - tr)))
            for yy in range(y, min(h, y + step)):
                for xx in range(x, min(w, x + step)):
                    px[xx, yy] = col
    return img


def draw_op(canvas, op, scale):
    k = SS * scale
    w, h = op["w"] * k, op["h"] * k
    if w < 0.5 or h < 0.5:
        return
    a = op.get("a", 1)
    strokes = op.get("st") or []
    border = [s for s in strokes if s["mode"] == "border"]
    text_strokes = [s for s in strokes if s["mode"] == "text"]
    pad = int(max([s["th"] for s in border] + [0]) * k) + 4
    lw, lh = int(math.ceil(w)) + pad * 2, int(math.ceil(h)) + pad * 2
    if lw > 8000 or lh > 8000:
        return
    layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0 = pad, pad
    x1, y1 = pad + max(w - 1, 0.0), pad + max(h - 1, 0.0)
    cr = max(0.0, min((op.get("cr") or 0.0) * k, (x1 - x0) / 2, (y1 - y0) / 2))
    bg_alpha = (1 - op.get("bt", 0)) * a
    if bg_alpha > 0.003:
        col = tuple(op["bg"])
        if op.get("gr"):
            g = gradient_image(int(math.ceil(w)), int(math.ceil(h)), op["gr"], col)
            mask = Image.new("L", g.size, 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, g.size[0] - 1, g.size[1] - 1], radius=cr, fill=int(255 * bg_alpha))
            g.putalpha(_mul(g.getchannel("A"), mask))
            layer.alpha_composite(g, (pad, pad))
        else:
            d.rounded_rectangle([x0, y0, x1, y1], radius=cr, fill=col + (int(255 * bg_alpha),))
    for s in border:
        sa = (1 - s["t"]) * a
        th = s["th"] * k
        if sa <= 0.003 or th <= 0:
            continue
        if s.get("gr"):
            # the outline is cut (or tinted) by its own gradient: draw it alone, then mask
            sl = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
            ImageDraw.Draw(sl).rounded_rectangle([x0 - th, y0 - th, x1 + th, y1 + th], radius=cr + th, outline=tuple(s["color"]) + (int(255 * sa),), width=max(1, int(round(th))))
            g = gradient_image(lw, lh, s["gr"], (255, 255, 255))
            sl.putalpha(_mul(sl.getchannel("A"), g.getchannel("A")))
            layer.alpha_composite(sl)
            continue
        d.rounded_rectangle([x0 - th, y0 - th, x1 + th, y1 + th], radius=cr + th, outline=tuple(s["color"]) + (int(255 * sa),), width=max(1, int(round(th))))
    img = op.get("img")
    if img and img.get("id"):
        ia = (1 - img.get("t", 0)) * a
        if ia > 0.003 and "rbxthumb" in img["id"]:
            # an avatar headshot: a stand-in head
            cx, cy, r = (x0 + x1) / 2, (y0 + y1) / 2, min(w, h) * 0.42
            d.ellipse([cx - r, cy - r * 0.95, cx + r, cy + r * 0.95], fill=(245, 205, 60, int(255 * ia)))
            d.ellipse([cx - r * 0.35, cy - r * 0.2, cx - r * 0.15, cy + r * 0.05], fill=(30, 30, 30, int(255 * ia)))
            d.ellipse([cx + r * 0.15, cy - r * 0.2, cx + r * 0.35, cy + r * 0.05], fill=(30, 30, 30, int(255 * ia)))
    t = op.get("text")
    if t:
        draw_text(layer, t, x0, y0, w, h, k, a, text_strokes)
    rot = op.get("r") or 0
    if abs(rot) > 0.01:
        layer = layer.rotate(-rot, resample=Image.BICUBIC, expand=True)
    cx = (op["x"] + op["w"] / 2) * k
    cy = (op["y"] + op["h"] / 2) * k
    px = int(round(cx - layer.width / 2))
    py = int(round(cy - layer.height / 2))
    clip = op.get("clip")
    cw, ch = canvas.size
    if clip:
        cx0, cy0, cx1, cy1 = [v * k for v in clip[:4]]
    else:
        cx0, cy0, cx1, cy1 = 0, 0, cw, ch
    cx0, cy0 = max(cx0, 0, px), max(cy0, 0, py)
    cx1, cy1 = min(cx1, cw, px + layer.width), min(cy1, ch, py + layer.height)
    if cx1 <= cx0 or cy1 <= cy0:
        return
    piece = layer.crop((int(cx0 - px), int(cy0 - py), int(cx1 - px), int(cy1 - py)))
    rounded = clip[4] if clip and len(clip) > 4 and clip[4] else None
    if rounded:
        # a CanvasGroup with a UICorner: clip to its rounded box
        from PIL import ImageChops
        rx0, ry0, rx1, ry1, rad = [v * k for v in rounded]
        mask = Image.new("L", piece.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([rx0 - cx0, ry0 - cy0, rx1 - cx0 - 1, ry1 - cy0 - 1], radius=max(0, rad), fill=255)
        piece.putalpha(ImageChops.multiply(piece.getchannel("A"), mask))
    canvas.alpha_composite(piece, (int(cx0), int(cy0)))


def _mul(a, b):
    from PIL import ImageChops
    return ImageChops.multiply(a, b)


def draw_text(layer, t, x0, y0, w, h, k, a, strokes):
    ta = (1 - t.get("t", 0)) * a
    if ta <= 0.003:
        return
    family, weight = t.get("font", "Nunito"), t.get("weight", "Regular")
    raw = t["s"]
    runs = rich_runs(raw, t["color"]) if t.get("rich") else [(raw, tuple(t["color"]))]
    wrap = t.get("wrap") or t.get("scaled")
    size = t["size"] * SS if not t.get("scaled") else None
    lh_mul = t.get("lh", 1) or 1
    if t.get("scaled"):
        lo, hi = 1, max(1, int(min(t.get("max", 100) * SS, h)))
        best = lo
        while lo <= hi:
            mid = (lo + hi) // 2
            f = get_font(family, weight, mid)
            lines = wrap_runs(runs, f, w)
            asc, desc = f.getmetrics()
            th = len(lines) * (asc + desc) * lh_mul
            tw = max(line_width(f, ln) for ln in lines) if lines else 0
            if th <= h + 1 and tw <= w + 1:
                best = mid
                lo = mid + 1
            else:
                hi = mid - 1
        size = best
    size = size * (k / SS) if not t.get("scaled") else size
    f = get_font(family, weight, size)
    lines = wrap_runs(runs, f, w if wrap else None)
    asc, desc = f.getmetrics()
    line_h = (asc + desc) * lh_mul
    total_h = line_h * len(lines)
    ya = t.get("ya", "Center")
    if ya == "Top":
        ty = y0
    elif ya == "Bottom":
        ty = y0 + h - total_h
    else:
        ty = y0 + (h - total_h) / 2
    d = ImageDraw.Draw(layer)
    sw, sc = 0, None
    for s in strokes:
        sa = (1 - s["t"]) * a
        if sa > 0.003:
            sw = max(1, int(round(s["th"] * k)))
            sc = tuple(s["color"]) + (int(255 * sa),)
    ls = t.get("ls")
    if not sw and ls:
        sw = max(1, int(round(k)))
        sc = tuple(ls[0]) + (int(255 * (1 - ls[1]) * a),)
    if t.get("trunc") == "AtEnd" and not wrap:
        # cut with an ellipsis to fit
        plain = "".join(x for x, _ in runs)
        # the fake measures with rounded widths: only cut text that clearly overflows
        if text_width(f, plain) > w * 1.04 + 2 * SS:
            while plain and text_width(f, plain + "...") > w:
                plain = plain[:-1]
            lines = [[(plain + "...", runs[0][1] if runs else tuple(t["color"]))]]
    xa = t.get("xa", "Center")
    for i, line in enumerate(lines):
        lw_ = line_width(f, line)
        if xa == "Left":
            tx = x0
        elif xa == "Right":
            tx = x0 + w - lw_
        else:
            tx = x0 + (w - lw_) / 2
        yy = ty + i * line_h
        for part, color in line:
            col = tuple(color) + (int(255 * ta),)
            if sw:
                d.text((tx, yy), part, font=f, fill=col, stroke_width=sw, stroke_fill=sc)
            else:
                d.text((tx, yy), part, font=f, fill=col)
            tx += text_width(f, part)


def render(shot, out_dir, scale=1.0):
    W, H = shot["w"], shot["h"]
    canvas = Image.new("RGBA", (int(W * SS * scale), int(H * SS * scale)), (0, 0, 0, 255))
    for op in shot["ops"]:
        try:
            draw_op(canvas, op, scale)
        except Exception as e:  # one odd element shouldn't lose the whole picture
            print("  skipped", op.get("c"), op.get("n"), e, file=sys.stderr)
    img = canvas.resize((int(W * scale), int(H * scale)), Image.LANCZOS).convert("RGB")
    path = os.path.join(out_dir, shot["name"] + ".png")
    img.save(path)
    return path


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)
    out_dir = args[0]
    scale = 1.0
    if "--scale" in args:
        scale = float(args[args.index("--scale") + 1])
    os.makedirs(out_dir, exist_ok=True)
    for line in sys.stdin:
        if line.startswith("@@SHOT "):
            shot = json.loads(line[7:])
            if os.environ.get("SHOT_JSON"):
                with open(os.path.join(out_dir, shot["name"] + ".json"), "w") as jf:
                    json.dump(shot, jf)
            print("wrote", render(shot, out_dir, scale))
        elif line.strip():
            sys.stderr.write(line)


if __name__ == "__main__":
    main()
