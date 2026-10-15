"""
Offline preview renderer for Trapisque's UI-drawn art.

The game draws everything with Roblox UI frames (see src/client/UI/Shapes.lua and
IconData.lua). This module reproduces the same primitives with Pillow so the art
can be previewed and iterated on without opening Roblox Studio.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Luckiest Guy, Fondamento and Nunito (Google Fonts); set TRAPISQUE_FONTS to use another folder
FONT_DIR = os.environ.get("TRAPISQUE_FONTS", os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts"))


# The sticker outline colour (Theme.C.line): a deep purple-black.
LINE = "#1B1030"


def hex_rgba(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


_WEIGHTS = {"body": "Bold", "heavy": "ExtraBold", "regular": "SemiBold"}


def font(kind, size):
    """Theme.Font: chunky = Luckiest Guy, display = Fondamento, body/heavy/regular = Nunito."""
    files = {
        "chunky": "LuckiestGuy-Regular.ttf",
        "display": "Fondamento-Regular.ttf",
        "body": "Nunito[wght].ttf",
    }
    path = os.path.join(FONT_DIR, files.get(kind, files["body"]))
    try:
        f = ImageFont.truetype(path, max(1, int(size)))
        if kind not in ("chunky", "display"):
            try:
                f.set_variation_by_name(_WEIGHTS.get(kind, "Bold"))
            except Exception:
                pass
        return f
    except Exception:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", max(1, int(size)))


class Layer:
    """Draws primitives into an RGBA image at supersampled resolution."""

    def __init__(self, w, h, ss=4):
        self.ss = ss
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))

    def paste_shape(self, shape_img):
        self.img = Image.alpha_composite(self.img, shape_img)

    def blank(self):
        return Image.new("RGBA", self.img.size, (0, 0, 0, 0))

    def final(self):
        return self.img.resize((self.w, self.h), Image.LANCZOS)


class Canvas:
    """Normalized square canvas placed at (ox, oy) with side `size` (in output px)."""

    def __init__(self, layer, ox, oy, size, colors):
        self.layer = layer
        self.ox, self.oy, self.size = ox, oy, size
        self.colors = colors

    def P(self, x, y):
        s = self.layer.ss
        return ((self.ox + x * self.size) * s, (self.oy + y * self.size) * s)

    def L(self, v):
        return v * self.size * self.layer.ss

    def col(self, c, alpha=1.0):
        if c is None:
            c = "ink"
        if isinstance(c, str) and c.startswith("#"):
            rgba = hex_rgba(c)
        elif c == "line":
            rgba = self.colors.get("line", hex_rgba(LINE))
        else:
            rgba = self.colors.get(c, self.colors["ink"])
        return (rgba[0], rgba[1], rgba[2], int(rgba[3] * alpha))

    # ---- primitives -------------------------------------------------------
    def _rotated(self, draw_fn, cx, cy, rot):
        img = self.layer.blank()
        d = ImageDraw.Draw(img)
        draw_fn(d)
        if rot:
            img = img.rotate(-rot, resample=Image.BICUBIC, center=self.P(cx, cy))
        self.layer.paste_shape(img)

    def rect(self, cx, cy, w, h, color, r=0, rot=0, t=0):
        x0, y0 = self.P(cx - w / 2, cy - h / 2)
        x1, y1 = self.P(cx + w / 2, cy + h / 2)
        rad = r * min(self.L(w), self.L(h))
        fill = self.col(color, 1 - t)
        self._rotated(lambda d: d.rounded_rectangle([x0, y0, x1, y1], radius=rad, fill=fill), cx, cy, rot)

    def circle(self, cx, cy, dd, color, t=0):
        x0, y0 = self.P(cx - dd / 2, cy - dd / 2)
        x1, y1 = self.P(cx + dd / 2, cy + dd / 2)
        img = self.layer.blank()
        ImageDraw.Draw(img).ellipse([x0, y0, x1, y1], fill=self.col(color, 1 - t))
        self.layer.paste_shape(img)

    def pill(self, cx, cy, w, h, color, rot=0):
        self.rect(cx, cy, w, h, color, r=0.5, rot=rot)

    def line(self, x1, y1, x2, y2, th, color, square=False, t=0):
        dx, dy = x2 - x1, y2 - y1
        ln = math.hypot(dx, dy)
        rot = math.degrees(math.atan2(dy, dx))
        self.rect((x1 + x2) / 2, (y1 + y2) / 2, ln + (0 if square else th), th, color, r=0 if square else 0.5, rot=rot, t=t)

    def path(self, pts, th, color, closed=False):
        seq = list(pts) + ([pts[0]] if closed else [])
        for a, b in zip(seq, seq[1:]):
            self.line(a[0], a[1], b[0], b[1], th, color)

    def tri(self, bx, by, width, color, dir=0):
        a = math.radians(dir - 90)
        ux, uy = math.cos(a), math.sin(a)
        px, py = -uy, ux
        half = width / 2
        pts = [
            self.P(bx + px * half, by + py * half),
            self.P(bx - px * half, by - py * half),
            self.P(bx + ux * half, by + uy * half),
        ]
        img = self.layer.blank()
        ImageDraw.Draw(img).polygon(pts, fill=self.col(color))
        self.layer.paste_shape(img)

    def half(self, cx, cy, dd, color, dir=0):
        x0, y0 = self.P(cx - dd / 2, cy - dd / 2)
        x1, y1 = self.P(cx + dd / 2, cy + dd / 2)
        start = dir - 180  # PIL: 0 deg = 3 o'clock, clockwise; dome (dir 0) spans 180..360
        img = self.layer.blank()
        ImageDraw.Draw(img).pieslice([x0, y0, x1, y1], start=start, end=start + 180, fill=self.col(color))
        self.layer.paste_shape(img)

    def ring(self, cx, cy, dd, th, color, keep_dir=None, keep=0.5, t=0):
        x0, y0 = self.P(cx - dd / 2, cy - dd / 2)
        x1, y1 = self.P(cx + dd / 2, cy + dd / 2)
        img = self.layer.blank()
        ImageDraw.Draw(img).ellipse([x0, y0, x1, y1], outline=self.col(color, 1 - t), width=max(1, int(self.L(th))))
        if keep_dir is not None:
            # keep the part of the ring on the `keep_dir` side of a cut line
            mask = Image.new("L", img.size, 0)
            md = ImageDraw.Draw(mask)
            a = math.radians(keep_dir - 90)
            ux, uy = math.cos(a), math.sin(a)
            px, py = -uy, ux
            off = (keep - 0.5) * dd  # positive keeps more
            cxp, cyp = cx - ux * off, cy - uy * off
            big = 3
            pts = [
                self.P(cxp + px * big, cyp + py * big),
                self.P(cxp - px * big, cyp - py * big),
                self.P(cxp - px * big + ux * big, cyp - py * big + uy * big),
                self.P(cxp + px * big + ux * big, cyp + py * big + uy * big),
            ]
            md.polygon(pts, fill=255)
            img.putalpha(Image.composite(img.getchannel("A"), Image.new("L", img.size, 0), mask))
        self.layer.paste_shape(img)

    def arc(self, cx, cy, dd, th, color, dir=0, keep=0.5, t=0):
        self.ring(cx, cy, dd, th, color, keep_dir=dir, keep=keep, t=t)

    def drop(self, cx, cy, r, color, dir=0):
        self.circle(cx, cy, 2 * r, color)
        a = math.radians(dir - 90)
        ux, uy = math.cos(a), math.sin(a)
        self.tri(cx + ux * 0.7071 * r, cy + uy * 0.7071 * r, 1.4142 * r, color, dir=dir)

    def hex(self, cx, cy, dd, color, rot=0):
        R = dd / 2
        pts = []
        for i in range(6):
            a = math.radians(60 * i + 30 + rot)
            pts.append(self.P(cx + R * math.cos(a), cy + R * math.sin(a)))
        img = self.layer.blank()
        ImageDraw.Draw(img).polygon(pts, fill=self.col(color))
        self.layer.paste_shape(img)

    def star(self, cx, cy, dd, color, points=5, extra=0):
        # rounded cartoon star: a thick pentagram stroke plus a filled middle
        th = dd * 0.18
        R = dd / 2 - th / 2
        pts = [(cx + R * math.cos(math.radians(-90 + 72 * k)), cy + R * math.sin(math.radians(-90 + 72 * k))) for k in range(5)]
        for k in range(5):
            a, b = pts[k], pts[(k + 2) % 5]
            self.line(a[0], a[1], b[0], b[1], th + 2 * extra, color)
        self.circle(cx, cy, dd * 0.42 + 2 * extra, color)

    def sparkle(self, cx, cy, dd, color, extra=0):
        # 4-point twinkle: thin rounded strokes from each tip to the waist
        R = dd / 2
        th = dd * 0.12 + 2 * extra
        r = R * 0.22
        outer = [(cx, cy - R + th / 2), (cx + R - th / 2, cy), (cx, cy + R - th / 2), (cx - R + th / 2, cy)]
        inner = [(cx + r, cy - r), (cx + r, cy + r), (cx - r, cy + r), (cx - r, cy - r)]
        for i in range(4):
            o = outer[i]
            self.line(o[0], o[1], inner[i][0], inner[i][1], th, color)
            self.line(o[0], o[1], inner[i - 1][0], inner[i - 1][1], th, color)
        self.circle(cx, cy, r * 2.4 + 2 * extra, color)

    def taper(self, pts, th0, th1, color, steps=5):
        """Brush stroke along a path whose thickness goes from th0 to th1 (smooth curve)."""
        dense = _smooth(pts, steps)
        n = len(dense)
        for i in range(n - 1):
            a, b = dense[i], dense[i + 1]
            t = (i + 0.5) / (n - 1)
            self.line(a[0], a[1], b[0], b[1], th0 + (th1 - th0) * t, color)

    def oring(self, cx, cy, w, h, th, color, t=0):
        x0, y0 = self.P(cx - w / 2, cy - h / 2)
        x1, y1 = self.P(cx + w / 2, cy + h / 2)
        img = self.layer.blank()
        ImageDraw.Draw(img).rounded_rectangle([x0, y0, x1, y1], radius=min(x1 - x0, y1 - y0) / 2, outline=self.col(color, 1 - t), width=max(1, int(self.L(th))))
        self.layer.paste_shape(img)

    def chevron(self, cx, cy, size, th, color, dir=90, extra=0):
        th = th + 2 * extra
        a = math.radians(dir - 90)
        ux, uy = math.cos(a), math.sin(a)
        px, py = -uy, ux
        tx, ty = cx + ux * size * 0.3, cy + uy * size * 0.3
        s = size * 0.5
        self.line(tx - ux * s + px * s, ty - uy * s + py * s, tx, ty, th, color)
        self.line(tx - ux * s - px * s, ty - uy * s - py * s, tx, ty, th, color)

    def arrow(self, cx, cy, ln, th, color, dir=90, extra=0):
        a = math.radians(dir - 90)
        ux, uy = math.cos(a), math.sin(a)
        x1, y1 = cx - ux * ln / 2, cy - uy * ln / 2
        x2, y2 = cx + ux * ln / 2, cy + uy * ln / 2
        self.line(x1, y1, x2 - ux * th, y2 - uy * th, th + 2 * extra, color)
        bx, by, bw = x2 - ux * th * 1.6, y2 - uy * th * 1.6, th * 3.2
        if extra:
            bx, by, bw = bx - ux * extra, by - uy * extra, bw + extra / 0.2071
        self.tri(bx, by, bw, color, dir=dir)

    def text(self, cx, cy, w, h, s, color, fnt="chunky", rot=0, stroke=0, stroke_color="line"):
        px_h = self.L(h)
        f = font(fnt, px_h * 0.9)
        img = self.layer.blank()
        d = ImageDraw.Draw(img)
        bbox = d.textbbox((0, 0), s, font=f)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        maxw = self.L(w)
        if tw > maxw:
            f = font(fnt, px_h * 0.9 * maxw / tw)
            bbox = d.textbbox((0, 0), s, font=f)
            tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        x, y = self.P(cx, cy)
        sw = int(round(self.L(stroke))) if stroke else 0
        d.text((x - tw / 2 - bbox[0], y - th / 2 - bbox[1]), s, font=f, fill=self.col(color),
               stroke_width=sw, stroke_fill=self.col(stroke_color) if sw else None)
        if rot:
            img = img.rotate(-rot, resample=Image.BICUBIC, center=(x, y))
        self.layer.paste_shape(img)


def _smooth(pts, steps):
    """Catmull-Rom spline through pts, `steps` samples per segment."""
    if len(pts) < 3:
        out = []
        a, b = pts[0], pts[-1]
        for i in range(steps + 1):
            t = i / steps
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
        return out
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    out.append(tuple(pts[-1]))
    return out


def _transform(op, rot, s, dx, dy, fx=False):
    """Apply a group transform (mirror, scale, rotate about the center, then shift)."""
    import copy

    op = copy.deepcopy(op)
    if isinstance(op, dict):
        args, opts = op["__args"], {k: v for k, v in op.items() if k != "__args"}
    else:
        args, opts = op, {}
    kind = args[0]
    th = math.radians(rot)

    def tp(x, y):
        if fx:
            x = 1 - x
        x, y = 0.5 + (x - 0.5) * s, 0.5 + (y - 0.5) * s
        rx = 0.5 + (x - 0.5) * math.cos(th) - (y - 0.5) * math.sin(th)
        ry = 0.5 + (x - 0.5) * math.sin(th) + (y - 0.5) * math.cos(th)
        return rx + dx, ry + dy

    a = list(args)
    if kind == "group":
        # nested group: its own transform first, then ours; its colour passes down
        flat = []
        for child in opts.get("ops", []):
            inner = _transform(child, opts.get("rot", 0), opts.get("s", 1), opts.get("dx", 0), opts.get("dy", 0), opts.get("fx", False))
            if opts.get("c") is not None:
                inner = _with_color(inner, opts["c"])
            flat.append(_transform(inner, rot, s, dx, dy, fx))
        return {"__args": a, "ops": flat}
    if kind == "line":
        a[1], a[2] = tp(a[1], a[2])
        a[3], a[4] = tp(a[3], a[4])
        a[5] *= s
    elif kind == "path":
        a[1] = [list(tp(p[0], p[1])) for p in a[1]]
        a[2] *= s
    elif kind == "taper":
        a[1] = [list(tp(p[0], p[1])) for p in a[1]]
        a[2] *= s
        a[3] *= s
    else:
        a[1], a[2] = tp(a[1], a[2])
        sizes = {"rect": [3, 4], "circle": [3], "pill": [3, 4], "tri": [3], "half": [3], "ring": [3, 4], "oring": [3, 4, 5],
                 "arc": [3, 4], "drop": [3], "hex": [3], "star": [3], "sparkle": [3], "chevron": [3, 4],
                 "arrow": [3, 4], "text": [3, 4]}
        for i in sizes.get(kind, []):
            a[i] *= s
        if kind in ("rect", "pill", "hex", "text"):
            r0 = opts.get("rot", 0)
            if fx and kind != "text":
                r0 = -r0
            opts["rot"] = r0 + rot
        if kind in ("tri", "half", "arc", "drop", "chevron", "arrow"):
            d0 = opts.get("dir", 0 if kind in ("tri", "half", "arc", "drop") else 90)
            if fx:
                d0 = -d0
            opts["dir"] = d0 + rot
    if opts:
        d = dict(opts)
        d["__args"] = a
        return d
    return a


def _with_color(op, c):
    """Give an op colour `c` unless it already has one."""
    if isinstance(op, dict):
        if op.get("c") is None:
            op = dict(op)
            op["c"] = c
        return op
    return {"__args": list(op), "c": c}


FACE_KINDS = ("eyes", "eye", "mouth", "blush", "shine")


def _split(op):
    if isinstance(op, dict):
        return list(op["__args"]), {k: v for k, v in op.items() if k != "__args"}
    return list(op), {}


def _join(args, o):
    if o:
        d = dict(o)
        d["__args"] = args
        return d
    return args


def flatten(ops, color=None):
    """Expand groups into one flat list in canvas coordinates (colours passed down)."""
    out = []
    for op in ops:
        args, o = _split(op)
        if color is not None and o.get("c") is None:
            o["c"] = color
        if args[0] == "group":
            sub = [_transform(x, o.get("rot", 0), o.get("s", 1), o.get("dx", 0), o.get("dy", 0), o.get("fx", False)) for x in o["ops"]]
            # faces inside a group keep their own geometry args; scale them like circles
            out.extend(flatten(sub, o.get("c")))
        else:
            out.append(_join(args, o))
    return out


def inflate(op, w):
    """The op grown by w on every side (the sticker outline behind it), or None."""
    args, o = _split(op)
    kind = args[0]
    if o.get("ol") is False or o.get("c") == "bg" or kind in FACE_KINDS or kind == "text" or (o.get("t") or 0) > 0.5:
        return None
    a = list(args)
    o = dict(o)
    o["c"] = "line"
    o.pop("t", None)
    if kind == "rect":
        m = min(a[3], a[4])
        r = o.get("r", 0) or 0
        o["r"] = (r * m + w) / (m + 2 * w)
        a[3] += 2 * w
        a[4] += 2 * w
    elif kind in ("circle",):
        a[3] += 2 * w
    elif kind == "pill":
        a[3] += 2 * w
        a[4] += 2 * w
    elif kind == "line":
        a[5] += 2 * w
    elif kind == "path":
        a[2] += 2 * w
    elif kind == "taper":
        a[2] += 2 * w
        a[3] += 2 * w
    elif kind == "tri":
        dr = math.radians(o.get("dir", 0) - 90)
        a[1] -= math.cos(dr) * w
        a[2] -= math.sin(dr) * w
        a[3] += w / 0.2071
    elif kind == "half":
        a[3] += 2 * w
    elif kind in ("ring", "arc"):
        a[3] += 2 * w
        a[4] += 2 * w
    elif kind == "oring":
        a[3] += 2 * w
        a[4] += 2 * w
        a[5] += 2 * w
    elif kind == "drop":
        a[3] += w
    elif kind == "hex":
        a[3] += 4 * w / math.sqrt(3)
    elif kind in ("star", "sparkle", "chevron", "arrow"):
        o["extra"] = w
    else:
        return None
    return _join(a, o)


def draw_face(cv, kind, a, o):
    """Eyes, mouths and cheeks: drawn on top, with their own ink lines (never outlined)."""
    line = "line"
    if kind == "blush":
        cx, cy, gap, d = a[1], a[2], a[3], a[4]
        for sx in (-1, 1):
            cv.rect(cx + sx * gap / 2, cy, d, d * 0.62, o.get("c") or "#FF7BAC", r=0.5, t=0.45)
        return
    if kind == "shine":
        cx, cy, d = a[1], a[2], a[3]
        cv.rect(cx, cy, d * 0.28, d, "#FFFFFF", r=0.5, rot=o.get("rot", 35), t=o.get("t", 0.15))
        return
    if kind == "mouth":
        cx, cy, w = a[1], a[2], a[3]
        mood = o.get("mood", "smile")
        th = max(w * 0.16, 0.02)
        if mood == "smile":
            cv.arc(cx, cy - w * 0.25, w, th, line, dir=180, keep=0.5)
        elif mood == "frown":
            cv.arc(cx, cy + w * 0.25, w, th, line, dir=0, keep=0.5)
        elif mood == "flat":
            cv.line(cx - w / 2, cy, cx + w / 2, cy, th, line)
        elif mood == "smirk":
            cv.line(cx - w / 2, cy + w * 0.06, cx + w * 0.25, cy - w * 0.04, th, line)
            cv.arc(cx + w * 0.3, cy - w * 0.12, w * 0.4, th, line, dir=135, keep=0.5)
        elif mood == "o":
            cv.circle(cx, cy, w * 0.55, line)
            cv.circle(cx, cy + w * 0.08, w * 0.28, "#FF6B8A")
        elif mood in ("grin", "open", "teeth"):
            cv.half(cx, cy - w * 0.12, w, line, dir=180)
            if mood == "open":
                cv.half(cx, cy + w * 0.14, w * 0.5, "#FF6B8A", dir=0)
            elif mood == "grin":
                cv.rect(cx, cy - w * 0.05, w * 0.72, w * 0.16, "#FFFFFF", r=0.3)
            else:
                n = 4
                for i in range(n):
                    tx = cx - w * 0.34 + i * w * 0.68 / (n - 1)
                    cv.tri(tx, cy - w * 0.12, w * 0.2, "#FFFFFF", dir=180)
        return
    # eyes
    if kind == "eye":
        cx, cy, d = a[1], a[2], a[3]
        spots = [(cx, cy)]
    else:
        cx, cy, gap, d = a[1], a[2], a[3], a[4]
        spots = [(cx - gap / 2, cy), (cx + gap / 2, cy)]
    mood = o.get("mood", "normal")
    look = o.get("look") or [0, 0]
    for i, (ex, ey) in enumerate(spots):
        m = mood
        if mood == "wink":
            m = "happy" if i == 1 else "normal"
        if m == "happy":
            cv.arc(ex, ey + d * 0.15, d * 0.9, d * 0.2, line, dir=0, keep=0.5)
            continue
        if m == "closed":
            cv.line(ex - d * 0.4, ey, ex + d * 0.4, ey, d * 0.18, line)
            continue
        if m == "dizzy":
            cv.line(ex - d * 0.3, ey - d * 0.3, ex + d * 0.3, ey + d * 0.3, d * 0.18, line)
            cv.line(ex - d * 0.3, ey + d * 0.3, ex + d * 0.3, ey - d * 0.3, d * 0.18, line)
            continue
        cv.circle(ex, ey, d, line)
        cv.circle(ex, ey, d * 0.78, "#FFFFFF")
        pd = d * (0.3 if m == "shock" else 0.46)
        px, py = ex + look[0] * d * 0.16, ey + look[1] * d * 0.16
        cv.circle(px, py, pd, line)
        cv.circle(px - pd * 0.22, py - pd * 0.24, pd * 0.36, "#FFFFFF")
        if m == "sleepy":
            lid = o.get("lid", "#000000")
            cv.half(ex, ey, d * 0.82, lid, dir=0)
            cv.line(ex - d * 0.42, ey, ex + d * 0.42, ey, d * 0.12, line)
        if m in ("angry", "sad"):
            s = 1 if (i == 0) == (m == "angry") else -1
            if kind == "eye":
                s = 0
            cv.line(ex - d * 0.5, ey - d * 0.62 - s * d * 0.14, ex + d * 0.5, ey - d * 0.62 + s * d * 0.14, d * 0.2, line)


def draw_ops(cv, ops, outline=0):
    flat = flatten(ops)
    if outline:
        for op in flat:
            big = inflate(op, outline)
            if big is not None:
                _draw_one(cv, big)
    for op in flat:
        _draw_one(cv, op)


def _draw_one(cv, op):
    args, o = _split(op)
    kind = args[0]
    if kind in FACE_KINDS:
        draw_face(cv, kind, args, o)
        return
    _draw_list(cv, [op])


def _draw_list(cv, ops):
    for op in ops:
        if isinstance(op, dict):
            args = op["__args"]
            o = {k: v for k, v in op.items() if k != "__args"}
        else:
            args, o = op, {}
        kind = args[0]
        c = o.get("c")
        if kind == "group":
            sub = [
                _transform(x, o.get("rot", 0), o.get("s", 1), o.get("dx", 0), o.get("dy", 0), o.get("fx", False))
                for x in o["ops"]
            ]
            if c is not None:
                sub = [_with_color(x, c) for x in sub]
            draw_ops(cv, sub)
        elif kind in FACE_KINDS:
            draw_face(cv, kind, args, o)
        elif kind == "rect":
            cv.rect(args[1], args[2], args[3], args[4], c, r=o.get("r", 0) or 0, rot=o.get("rot", 0) or 0, t=o.get("t", 0) or 0)
        elif kind == "circle":
            cv.circle(args[1], args[2], args[3], c, t=o.get("t", 0) or 0)
        elif kind == "pill":
            cv.pill(args[1], args[2], args[3], args[4], c, rot=o.get("rot", 0))
        elif kind == "line":
            cv.line(args[1], args[2], args[3], args[4], args[5], c, square=o.get("square", False), t=o.get("t", 0) or 0)
        elif kind == "path":
            cv.path(args[1], args[2], c, closed=o.get("closed", False))
        elif kind == "taper":
            cv.taper(args[1], args[2], args[3], c, steps=o.get("steps", 5))
        elif kind == "oring":
            cv.oring(args[1], args[2], args[3], args[4], args[5], c, t=o.get("t", 0))
        elif kind == "tri":
            cv.tri(args[1], args[2], args[3], c, dir=o.get("dir", 0))
        elif kind == "half":
            cv.half(args[1], args[2], args[3], c, dir=o.get("dir", 0))
        elif kind == "ring":
            cv.ring(args[1], args[2], args[3], args[4], c, t=o.get("t", 0) or 0)
        elif kind == "arc":
            cv.arc(args[1], args[2], args[3], args[4], c, dir=o.get("dir", 0), keep=o.get("keep", 0.5), t=o.get("t", 0) or 0)
        elif kind == "drop":
            cv.drop(args[1], args[2], args[3], c, dir=o.get("dir", 0))
        elif kind == "hex":
            cv.hex(args[1], args[2], args[3], c, rot=o.get("rot", 0))
        elif kind == "star":
            cv.star(args[1], args[2], args[3], c, points=o.get("points", 5), extra=o.get("extra", 0))
        elif kind == "sparkle":
            cv.sparkle(args[1], args[2], args[3], c, extra=o.get("extra", 0))
        elif kind == "chevron":
            cv.chevron(args[1], args[2], args[3], args[4], c, dir=o.get("dir", 90), extra=o.get("extra", 0))
        elif kind == "arrow":
            cv.arrow(args[1], args[2], args[3], args[4], c, dir=o.get("dir", 90), extra=o.get("extra", 0))
        elif kind == "text":
            cv.text(args[1], args[2], args[3], args[4], args[5], c, fnt=o.get("font", "chunky"), rot=o.get("rot", 0), stroke=o.get("stroke", 0))
        else:
            raise ValueError("unknown op " + str(kind))
