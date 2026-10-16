#!/usr/bin/env python3
"""
A small Roblox-UI renderer for the offline previews (the other preview scripts build
screens with it).

Stage draws the primitives the game builds every screen from, the way Roblox draws
them, so each preview can follow its Lua component line by line:

  - Frames with UICorner (a number <= 1 is a scale of the shorter side, as Util.corner
    makes it) and UIStroke, which sits OUTSIDE its frame (Border mode, round joins)
  - transparency as in Roblox (0 = solid), CanvasGroup-style group transparency,
    UIScale (st.at(x, y, scale)), Rotation, clipping (ScrollingFrame)
  - TextLabels: TextSize is the em and the height of one line, text is centred on
    its line, TextScaled with a UITextSizeConstraint, TextWrapped, TextTruncate,
    outlined lettering (a Contextual UIStroke) and <font color> rich text
  - sticker art and icons (render.draw_ops with the sticker outline pass)

The widgets below mirror client/UI/Widgets.lua (candy buttons with a lip and gloss,
panels with the line stroke and a hard shadow, the tilted title ribbon, badges,
progress bars, choice rows, modals), Icons.medallion and Avatars.portrait.
Root.buildBackground (the night-purple screen with soft dots) is `background`.

Colours come from the game's Theme (dumped by tests/preview_skins.luau PreviewTheme).
"""
import math
import os
import re
import sys
from contextlib import contextmanager

sys.path.insert(0, os.path.dirname(__file__))
from render import Layer, Canvas, draw_ops, hex_rgba, font  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

WHITE = "#FFFFFF"
BLACK = "#000000"


# ----------------------------------------------------------------------------- colours
def rgba(c, alpha=1.0):
    """A colour (hex string or tuple) as RGBA with `alpha` (0..1) applied."""
    if isinstance(c, tuple):
        r, g, b = c[:3]
        a = c[3] if len(c) > 3 else 255
    else:
        r, g, b, a = hex_rgba(c)
    return (r, g, b, int(round(a * max(0.0, min(1.0, alpha)))))


def mix(a, b, t):
    """Color3:Lerp (Util.mix)."""
    ca, cb = rgba(a), rgba(b)
    return "#%02X%02X%02X" % tuple(int(round(ca[i] + (cb[i] - ca[i]) * t)) for i in range(3))


def shade(c, amt):
    """Util.shade: > 0 lightens toward white, < 0 darkens toward black."""
    return mix(c, WHITE, amt) if amt >= 0 else mix(c, BLACK, -amt)


# ----------------------------------------------------------------------------- text
_FONT_CACHE = {}


def get_font(kind, px):
    """Theme.Font: display / chunky = Luckiest Guy; body / heavy / regular = Nunito
    Bold / ExtraBold / SemiBold. px is the em in device pixels."""
    if kind == "display":
        kind = "chunky"
    key = (kind, max(1, int(round(px))))
    f = _FONT_CACHE.get(key)
    if f is None:
        f = font(kind, key[1])
        _FONT_CACHE[key] = f
    return f


_RICH = re.compile(r'<font color="?#?([0-9A-Fa-f]{6})"?>(.*?)</font>', re.S)


def rich_runs(text, color):
    """'<font color="#xxxxxx">Name</font> did a thing' -> [(text, colour), ...]."""
    runs, pos = [], 0
    for m in _RICH.finditer(text):
        if m.start() > pos:
            runs.append((text[pos:m.start()], color))
        runs.append((m.group(2), "#" + m.group(1)))
        pos = m.end()
    if pos < len(text):
        runs.append((text[pos:], color))
    return runs


def plain(text):
    return _RICH.sub(lambda m: m.group(2), text)


# ----------------------------------------------------------------------------- stage
class Stage:
    """A w x h stage (virtual pixels), drawn supersampled `ss` times."""

    def __init__(self, w, h, ss=3, bg=None, art=None, theme=None):
        self.w, self.h, self.ss = w, h, ss
        self.img = Image.new("RGBA", (int(round(w * ss)), int(round(h * ss))), rgba(bg) if bg else (0, 0, 0, 0))
        self.layers = []
        self.tf = (0.0, 0.0, 1.0)
        self.art = art or {}
        self.theme = theme or {}
        self.C = (theme or {}).get("C", {})

    # ---- transforms ---------------------------------------------------------
    @property
    def target(self):
        return self.layers[-1] if self.layers else self.img

    def X(self, x):
        ox, _, s = self.tf
        return (ox + x * s) * self.ss

    def Y(self, y):
        _, oy, s = self.tf
        return (oy + y * s) * self.ss

    def L(self, v):
        return v * self.tf[2] * self.ss

    def stage_pt(self, x, y):
        ox, oy, s = self.tf
        return ox + x * s, oy + y * s

    @contextmanager
    def at(self, x, y, scale=1.0):
        """Draw in a frame whose origin is (x, y) here, scaled by `scale` (a UIScale)."""
        prev = self.tf
        ox, oy, s = prev
        self.tf = (ox + x * s, oy + y * s, s * scale)
        try:
            yield
        finally:
            self.tf = prev

    @contextmanager
    def layer(self, alpha=1.0, clip=None, rot=0.0, center=None, mask=None):
        """Draw into a separate layer, then composite it: group transparency
        (CanvasGroup), clipping to a rect (x, y, w, h in local units), a rotation about
        `center` (local units), or an arbitrary L-mode `mask` (device pixels)."""
        lay = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        clip_dev = None
        if clip is not None:
            x, y, w, h = clip
            clip_dev = (self.X(x), self.Y(y), self.X(x + w), self.Y(y + h))
        center_dev = None
        if rot and center is not None:
            center_dev = (self.X(center[0]), self.Y(center[1]))
        self.layers.append(lay)
        try:
            yield
        finally:
            self.layers.pop()
            if rot:
                lay = lay.rotate(-rot, resample=Image.BICUBIC, center=center_dev)
            if clip_dev is not None:
                m = Image.new("L", lay.size, 0)
                ImageDraw.Draw(m).rectangle([clip_dev[0], clip_dev[1], clip_dev[2] - 1, clip_dev[3] - 1], fill=255)
                lay.putalpha(Image.composite(lay.getchannel("A"), Image.new("L", lay.size, 0), m))
            if mask is not None:
                lay.putalpha(Image.composite(lay.getchannel("A"), Image.new("L", lay.size, 0), mask))
            if alpha < 1:
                lay.putalpha(lay.getchannel("A").point(lambda v: int(v * alpha)))
            self.target.alpha_composite(lay)

    def blit(self, small, dx, dy):
        """Composite a device-pixel image at (dx, dy) (may hang off the edges)."""
        dx, dy = int(math.floor(dx)), int(math.floor(dy))
        T = self.target
        sx, sy = max(0, -dx), max(0, -dy)
        if sx >= small.width or sy >= small.height or dx >= T.width or dy >= T.height:
            return
        if sx or sy:
            small = small.crop((sx, sy, small.width, small.height))
        dx, dy = max(0, dx), max(0, dy)
        if dx + small.width > T.width or dy + small.height > T.height:
            small = small.crop((0, 0, min(small.width, T.width - dx), min(small.height, T.height - dy)))
        T.alpha_composite(small, (dx, dy))

    # ---- shapes ---------------------------------------------------------------
    @staticmethod
    def corner_px(corner, w, h):
        """Util.corner: <= 1 is a scale of the shorter side, more is pixels."""
        if not corner:
            return 0.0
        r = corner * min(w, h) if corner <= 1 else corner
        return min(r, min(w, h) / 2)

    def rect(self, x, y, w, h, color=None, corner=0, alpha=1.0, stroke=None, rot=0.0):
        """A Frame: fill `color` at `alpha` (None = no fill), UICorner `corner`, and
        stroke = (colour, thickness[, alpha]) outside it. Rotation about its centre."""
        if w <= 0 or h <= 0:
            return
        r = self.corner_px(corner, w, h)
        t = stroke[1] if stroke else 0
        pad = int(math.ceil(self.L(t))) + 4
        X0, Y0 = self.X(x), self.Y(y)
        W, H = self.L(w), self.L(h)
        R, T = self.L(r), self.L(t)
        size = (int(math.ceil(W + 2 * pad)) + 1, int(math.ceil(H + 2 * pad)) + 1)
        if rot:
            # leave room to turn
            diag = math.hypot(size[0], size[1])
            extra = int((diag - min(size)) / 2) + 2
        else:
            extra = 0
        img = Image.new("RGBA", (size[0] + 2 * extra, size[1] + 2 * extra), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        ox, oy = pad + extra + (X0 - math.floor(X0)), pad + extra + (Y0 - math.floor(Y0))
        inner = [ox, oy, ox + W, oy + H]
        if stroke and T > 0:
            sc = rgba(stroke[0], stroke[2] if len(stroke) > 2 else 1.0)
            d.rounded_rectangle([ox - T, oy - T, ox + W + T, oy + H + T], radius=R + T, fill=sc)
            d.rounded_rectangle(inner, radius=R, fill=(0, 0, 0, 0))
        if color is not None and alpha > 0:
            d.rounded_rectangle(inner, radius=R, fill=rgba(color, alpha))
        if rot:
            img = img.rotate(-rot, resample=Image.BICUBIC, center=(ox + W / 2, oy + H / 2))
        self.blit(img, math.floor(X0) - pad - extra, math.floor(Y0) - pad - extra)

    def circle(self, cx, cy, d, color=None, alpha=1.0, stroke=None):
        self.rect(cx - d / 2, cy - d / 2, d, d, color, corner=0.5, alpha=alpha, stroke=stroke)

    def poly(self, pts, color, alpha=1.0):
        P = [(self.X(px), self.Y(py)) for px, py in pts]
        x0, y0 = min(p[0] for p in P), min(p[1] for p in P)
        x1, y1 = max(p[0] for p in P), max(p[1] for p in P)
        bx, by = math.floor(x0) - 2, math.floor(y0) - 2
        img = Image.new("RGBA", (int(x1 - bx) + 4, int(y1 - by) + 4), (0, 0, 0, 0))
        ImageDraw.Draw(img).polygon([(px - bx, py - by) for px, py in P], fill=rgba(color, alpha))
        self.blit(img, bx, by)

    # ---- text -----------------------------------------------------------------
    def _measure(self, f, s):
        return f.getlength(s)

    def _wrap(self, runs, f, maxw, space):
        """Greedy word wrap of coloured runs into lines of [(word, colour, lead)].
        Breaks only at spaces (and newlines); pieces of one word in two colours stay
        together."""
        tokens = []
        for text, col in runs:
            for m in re.finditer(r"\n| +|[^ \n]+", text):
                s = m.group(0)
                if s == "\n":
                    tokens.append(("nl", None, col))
                elif s[0] == " ":
                    tokens.append(("sp", len(s), col))
                else:
                    tokens.append(("w", s, col))
        lines, cur, cur_w, pending = [], [], 0.0, 0.0
        for kind, val, col in tokens:
            if kind == "nl":
                lines.append((cur, cur_w))
                cur, cur_w, pending = [], 0.0, 0.0
            elif kind == "sp":
                pending += space * val
            else:
                ww = self._measure(f, val)
                lead = pending if cur else 0.0
                if maxw is not None and cur and pending > 0 and cur_w + lead + ww > maxw + 0.5:
                    lines.append((cur, cur_w))
                    cur, cur_w, lead = [], 0.0, 0.0
                cur.append((val, col, lead))
                cur_w += lead + ww
                pending = 0.0
        lines.append((cur, cur_w))
        return lines

    def text_size(self, text, kind="body", size=18):
        """Width of one line of text in local units (Roblox TextBounds.X)."""
        f = get_font(kind, self.L(size))
        return self._measure(f, plain(text)) / self.L(1)

    def label(self, x, y, w, h, text, kind="body", size=18, color=None, align="left", valign="center",
              wrap=False, scaled=False, max_size=None, min_size=1, truncate=False, outline=None, outline_t=2.0,
              alpha=1.0, rich=False, rot=0.0):
        """A TextLabel. Returns (text width, text height, text size used, line count)
        in local units."""
        color = color or self.C.get("text", WHITE)
        if text is None:
            return (0, 0, size, 0)
        runs = rich_runs(text, color) if rich else [(text, color)]
        lo = min_size if scaled else size
        hi = (max_size or size) if scaled else size
        if scaled and max_size is None:
            hi = 100

        def layout(sz):
            f = get_font(kind, self.L(sz))
            space = self._measure(f, " ")
            maxw = self.L(w) if wrap else None
            lines = self._wrap(runs, f, maxw, space)
            return f, lines

        sz = hi
        while True:
            f, lines = layout(sz)
            if not scaled:
                break
            widest = max((lw for _, lw in lines), default=0)
            if (widest <= self.L(w) + 0.5 and len(lines) * self.L(sz) <= self.L(h) + 0.5) or sz <= lo:
                break
            sz = max(lo, sz - (1 if sz > 12 else 0.5))
        line_h = self.L(sz)
        # truncation (TextTruncate.AtEnd)
        if truncate:
            maxw = self.L(w)
            max_lines = max(1, int((self.L(h) + 0.5) // line_h)) if wrap else 1
            if len(lines) > max_lines:
                lines = lines[:max_lines]
                words, lw = lines[-1]
                lines[-1] = (words + [("...", words[-1][1] if words else color, 0)], lw + self._measure(f, "..."))
            for i, (words, lw) in enumerate(lines):
                if lw > maxw + 0.5:
                    flat = [(wd, c, ld) for wd, c, ld in words]
                    ell = self._measure(f, "...")
                    while flat and lw + ell > maxw:
                        wd, c, ld = flat[-1]
                        if len(wd) > 1:
                            nw = wd[:-1]
                            lw -= self._measure(f, wd) - self._measure(f, nw)
                            flat[-1] = (nw, c, ld)
                        else:
                            lw -= self._measure(f, wd) + ld
                            flat.pop()
                    if flat:
                        wd, c, ld = flat[-1]
                        flat[-1] = (wd.rstrip(" .,") + "...", c, ld)
                    lines[i] = (flat, lw + ell)
        total = line_h * len(lines)
        X0, Y0, W, H = self.X(x), self.Y(y), self.L(w), self.L(h)
        if valign == "top":
            top = Y0
        elif valign == "bottom":
            top = Y0 + H - total
        else:
            top = Y0 + (H - total) / 2
        asc, desc = f.getmetrics()
        sw = int(round(self.L(outline_t))) if outline else 0
        widest = 0.0
        starts = []
        for words, lw in lines:
            if align == "center":
                starts.append(X0 + (W - lw) / 2)
            elif align == "right":
                starts.append(X0 + W - lw)
            else:
                starts.append(X0)
        # draw everything on one small image
        pad = int(line_h) + sw + 4
        minx = min(starts) if starts else X0
        maxx = max((s + lw for s, (_, lw) in zip(starts, lines)), default=X0)
        bx0 = int(math.floor(minx)) - pad
        by0 = int(math.floor(top)) - pad
        bw = int(math.ceil(maxx - bx0)) + pad
        bh = int(math.ceil(total)) + 2 * pad
        if rot:
            grow = int(max(bw, bh) * 0.5)
            bx0, by0, bw, bh = bx0 - grow, by0 - grow, bw + 2 * grow, bh + 2 * grow
        img = Image.new("RGBA", (max(1, bw), max(1, bh)), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for i, (words, lw) in enumerate(lines):
            widest = max(widest, lw)
            lx = starts[i]
            base = top + i * line_h + line_h / 2 + (asc - desc) / 2
            cx = lx
            for word, col, lead in words:
                cx += lead
                if word:
                    fill = rgba(col, alpha)
                    if sw:
                        d.text((cx - bx0, base - by0), word, font=f, fill=fill, anchor="ls", stroke_width=sw,
                               stroke_fill=rgba(outline, alpha))
                    else:
                        d.text((cx - bx0, base - by0), word, font=f, fill=fill, anchor="ls")
                    cx += self._measure(f, word)
        if rot:
            img = img.rotate(-rot, resample=Image.BICUBIC, center=(X0 + W / 2 - bx0, Y0 + H / 2 - by0))
        self.blit(img, bx0, by0)
        k = self.L(1)
        return (widest / k, total / k, sz, len(lines))

    # ---- art ------------------------------------------------------------------
    def ops(self, ops, x, y, size, colors=None, outline=0.0, alpha=1.0, rot=0.0, flip=False):
        """Icon / sticker ops drawn in the square (x, y, size) (Shapes.canvas)."""
        D = self.L(size)
        if D < 1:
            return
        M = int(D * 0.3) + 4
        side = int(math.ceil(D)) + 2 * M
        lay = Layer(side, side, ss=1)
        cols = {"ink": rgba("#1B1030"), "line": rgba(self.C.get("line", "#1B1030"))}
        for k, v in (colors or {}).items():
            cols[k] = rgba(v)
        X0, Y0 = self.X(x), self.Y(y)
        fx, fy = X0 - math.floor(X0), Y0 - math.floor(Y0)
        cv = Canvas(lay, M + fx, M + fy, D, cols)
        if rot or flip:
            ops = [{"__args": ["group"], "ops": ops, "rot": rot, "fx": flip}]
        draw_ops(cv, ops, outline=outline)
        im = lay.img
        if alpha < 1:
            im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
        self.blit(im, math.floor(X0) - M, math.floor(Y0) - M)

    def sticker(self, ops, cx, cy, size, outline=0.045, alpha=1.0):
        """Icons.sticker: sticker art on a square canvas centred at (cx, cy)."""
        C = self.C
        cols = {"ink": C.get("line"), "line": C.get("line"), "bg": C.get("cream"), "acc": C.get("sun"),
                "acc2": C.get("sun"), "hi": WHITE}
        self.ops(ops, cx - size / 2, cy - size / 2, size, cols, outline=outline, alpha=alpha)

    def icon(self, name, x, y, size, colors, outline=0.0):
        """Icons.make: an IconData glyph in the square (x, y, size)."""
        ops = self.art.get("icons", {}).get(name)
        if ops:
            self.ops(ops, x, y, size, colors, outline=outline)

    def sticker_for(self, name):
        """Icons.stickerFor: card art, then a character's mascot, then a misc sticker."""
        a = self.art
        if name in a.get("cards", {}):
            return a["cards"][name]
        if name in a.get("mascots", {}):
            return a["mascots"][name]
        return a.get("misc", {}).get(name)

    def medallion(self, name, cx, cy, d, color):
        """Icons.medallion: a coloured disc with the line stroke (ScaledSize 0.07), a soft
        shine, and the sticker art (0.86, outline 0.055) or a white glyph (0.62, 0.07)."""
        C = self.C
        self.circle(cx, cy, d, color, stroke=(C["line"], 0.07 * d))
        self.rect(cx - 0.33 * d, cy - 0.5 * d + 0.08 * d, 0.66 * d, 0.3 * d, WHITE, corner=0.5, alpha=0.2)
        art = self.sticker_for(name)
        if art:
            self.sticker(art, cx, cy, 0.86 * d, outline=0.055)
        else:
            g = 0.62 * d
            self.icon(name, cx - g / 2, cy - g / 2, g,
                      {"ink": WHITE, "bg": color, "acc": C["sunLight"], "acc2": C["sunLight"], "hi": color, "line": C["line"]},
                      outline=0.07)


# ============================================================================ widgets
def candy(face, lip=None, text=None, C=None):
    """Widgets candy(): face, a darker lip, outlined lettering."""
    return {"face": face, "dark": lip or mix(face, BLACK, 0.35), "stroke": C["line"], "text": text or WHITE, "outline": C["line"]}


def button_styles(C):
    """Widgets.ButtonStyles."""
    s = {
        "wood": candy("#5B45A0", "#3A2A6E", C["text"], C),
        "brass": candy(C["sun"], C["sunDark"], C=C),
        "red": candy(C["coral"], C["coralDark"], C=C),
        "green": candy(C["lime"], C["limeDark"], C=C),
        "blue": candy(C["sky"], C["skyDark"], C=C),
        "purple": candy(C["grape"], C["grapeDark"], C=C),
        "orange": candy(C["orange"], C["orangeDark"], C=C),
        "pink": candy(C["pink"], C["pinkDark"], C=C),
        "panel": candy(C["panelRaised"], C["panelDeep"], C["text"], C),
        "dark": candy(C["panelDeep"], "#0E0819", C["text"], C),
    }
    s["sun"] = s["brass"]
    s["parchment"] = s["panel"]
    return s


def background(st):
    """Root.buildBackground: C.bg with 24 soft C.panel dots (sizes relative to the
    screen height)."""
    C = st.C
    st.rect(0, 0, st.w, st.h, C["bg"])
    for i in range(24):
        size = (0.05 + (i % 3) * 0.02) * st.h
        cx = ((i * 37) % 100) / 100 * st.w
        cy = ((i * 61 + 13) % 100) / 100 * st.h
        st.circle(cx, cy, size, C["panel"])


def button(st, x, y, w, h, text=None, icon=None, style="wood", text_size=22, depth=5, corner=14, enabled=True,
           icon_scale=0.62, hover=False, font_kind="chunky"):
    """Widgets.button: the lip (Side) under the face, both with the 3 px line stroke, a
    gloss over the top of the face, then the icon and outlined lettering centred."""
    C = st.C
    S = button_styles(C)[style]
    a = 1.0 if enabled else 0.65
    fh = h - depth
    st.rect(x, y + depth, w, fh, S["dark"], corner=corner, alpha=a, stroke=(S["stroke"], 3))
    st.rect(x, y, w, fh, S["face"], corner=corner, alpha=a, stroke=(S["stroke"], 3))
    if enabled:
        st.rect(x + 5, y + 4, w - 10, fh * 0.36, WHITE, corner=8, alpha=0.18)
    if hover:
        st.rect(x, y, w, fh, WHITE, corner=corner, alpha=0.12)
    # content: icon (0.62 of the face height) and text, gap 8, centred
    isz = fh * icon_scale if icon else 0
    tw = st.text_size(text, font_kind, text_size) if text else 0
    gap = 8 if (icon and text) else 0
    total = isz + gap + tw
    cx = x + (w - total) / 2
    if icon:
        st.icon(icon, cx, y + (fh - isz) / 2, isz,
                {"ink": S["text"], "bg": S["face"], "acc": S["text"], "acc2": S["text"], "hi": S["face"], "line": C["line"]},
                outline=0.07)
    if text:
        th = fh * 0.8
        st.label(cx + isz + gap, y + (fh - th) / 2, tw, th, text, font_kind, text_size, S["text"], align="center",
                 outline=S["outline"], outline_t=2.5, alpha=1.0 if enabled else 0.6)


def icon_button(st, x, y, w, h, icon, style="wood", icon_scale=0.66, depth=4, corner=12, enabled=True):
    """Widgets.iconButton."""
    button(st, x, y, w, h, icon=icon, style=style, depth=depth, corner=corner, enabled=enabled, icon_scale=icon_scale)


def badge_width(st, text, text_size=16):
    return st.text_size(text, "chunky", text_size) + 16


def badge(st, x, y, text, color, height=24, text_size=16, text_color=None, stroke=None, anchor=(0, 0)):
    """Widgets.badge: a pill that hugs its text (8 px padding), the line stroke (2.5),
    white outlined lettering unless a text colour is given. Returns its rect."""
    C = st.C
    w = badge_width(st, text, text_size)
    x -= anchor[0] * w
    y -= anchor[1] * height
    st.rect(x, y, w, height, color, corner=0.5, stroke=(stroke or C["line"], 2.5))
    st.label(x + 8, y, w - 16, height, text, "chunky", text_size, text_color or WHITE, align="center",
             outline=None if text_color else C["line"], outline_t=1.5)
    return (x, y, w, height)


def progress(st, x, y, w, h, value, color=None, track=None):
    """Widgets.progress: a track with the line stroke (3), the fill and its shine."""
    C = st.C
    st.rect(x, y, w, h, track or C["panelDeep"], corner=0.5, stroke=(C["line"], 3))
    v = max(0.0, min(1.0, value))
    if v > 0:
        fw = w * v
        st.rect(x, y, fw, h, color or C["sun"], corner=0.5)
        st.rect(x + 3, y + 0.16 * h, fw - 6, 0.28 * h, WHITE, corner=0.5, alpha=0.4)


def ribbon(st, cx, top, width, text, color=None, height=46, tilt=-2, max_text=28):
    """Widgets.ribbon: a candy pill (with a darker lip 5 px under it) and white outlined
    lettering, tilted a touch like a sticker. (cx, top) is its top centre."""
    C = st.C
    color = color or C["sun"]
    x = cx - width / 2
    with st.layer(rot=tilt, center=(cx, top + height / 2)):
        st.rect(x, top + 5, width, height, mix(color, BLACK, 0.35), corner=14, stroke=(C["line"], 3))
        st.rect(x, top, width, height, color, corner=14, stroke=(C["line"], 3))
        lw, lh = width - 20, height - 10
        st.label(cx - lw / 2, top + 0.52 * height - lh / 2, lw, lh, text.upper(), "display", max_text, WHITE,
                 align="center", scaled=True, max_size=max_text, min_size=8, outline=C["line"], outline_t=2.5)


def panel(st, x, y, w, h, style="walnut", title=None, title_w=280, title_color=None, pad=18, corner=18, shadow=True,
          color=None):
    """Widgets.panel: a hard shadow 7 px down, the panel with the 4 px line stroke and a
    lighter rim along its top, the title ribbon inside the top edge. Returns the
    content rect (x, y, w, h)."""
    C = st.C
    if style == "parchment":
        style = "walnut"
    if shadow:
        st.rect(x, y + 7, w, h, C["shadow"], corner=corner, alpha=0.9)
    if style == "walnut":
        st.rect(x, y, w, h, C["panel"], corner=corner, stroke=(C["line"], 4))
        st.rect(x + corner, y + 4, w - 2 * corner, 3, C["panelHi"], corner=2, alpha=0.45)
    elif style in ("wood", "board"):
        st.rect(x, y, w, h, C["panelDeep"] if style == "board" else C["panelRaised"], corner=corner, stroke=(C["line"], 4))
    elif style == "dark":
        st.rect(x, y, w, h, C["panelDeep"], corner=corner, alpha=0.96, stroke=(C["line"], 3))
    elif style == "bright":
        st.rect(x, y, w, h, color or C["sun"], corner=corner, stroke=(C["line"], 4))
    if title:
        ribbon(st, x + w / 2, y + 14, title_w, title, color=title_color)
    top = pad + (54 if title else 0)
    return (x + pad, y + top, w - 2 * pad, h - top - pad)


def choice(st, x, y, w, h, options, value, text_size=17, enabled=True):
    """Widgets.choice: one rounded button per option (gap 6), the picked one sun."""
    C = st.C
    n = len(options)
    bw = w / n - 6 * (n - 1) / n
    for i, (label, v) in enumerate(options):
        on = v == value
        bx = x + i * (bw + 6)
        st.rect(bx, y, bw, h, C["sun"] if on else C["panelRaised"], corner=12, alpha=1.0 if (enabled or on) else 0.6,
                stroke=(C["line"], 3))
        st.label(bx + 4, y, bw - 8, h, label, "chunky", text_size, C["textOnLight"] if on else C["textSoft"],
                 align="center", scaled=True, max_size=text_size, min_size=8)


def dim(st, alpha=0.65):
    st.rect(0, 0, st.w, st.h, st.C["dim"], alpha=alpha)


def modal_frame(st, m, w, h, title=None, title_w=None, no_close=False, min_scale=0.5):
    """Widgets.modal: the dimmed backdrop and a panel fitted to the screen
    (Layout.modal / Layout.modalCenter, the same numbers the game uses), with the red
    close button tucked into its top-right corner. Yields nothing: returns
    (content rect in the panel's own units, origin x, origin y, scale) for st.at()."""
    room_w, room_h = modal_room(m)
    scale = min(1.0, room_w / w, room_h / h)
    scale = max(scale, min_scale)
    bw, bh = min(w, room_w / scale), min(h, room_h / scale)
    cx, cy = modal_center(m)
    dim(st, 0.65)
    ox, oy = cx - bw * scale / 2, cy - bh * scale / 2
    with st.at(ox, oy, scale):
        content = panel(st, 0, 0, bw, bh, title=title, title_w=title_w or 280)
        if not no_close:
            icon_button(st, bw - 14 - 40, 14, 40, 42, "close", style="red")
    return content, ox, oy, scale, bw, bh


def safe_rect(m, margin=0):
    s = m["safe"]
    return (s["l"] + margin, s["t"] + margin, m["vw"] - s["l"] - s["r"] - 2 * margin, m["vh"] - s["t"] - s["b"] - 2 * margin)


def modal_room(m):
    """Layout.modalRoom."""
    x, y, w, h = safe_rect(m, 16 if m["form"] == "wide" else 6)
    top = max(m["topbar"]["y1"] + 4, y)
    return w, y + h - top


def modal_center(m):
    """Layout.modalCenter."""
    x, y, w, h = safe_rect(m, 0)
    top = max(m["topbar"]["y1"], y)
    return x + w / 2, top + (y + h - top) / 2


def room(m):
    """Widgets.room: (w, h, narrow)."""
    w, h = modal_room(m)
    return w, h, w < 760


# ============================================================================ avatars
def headshot(st, cx, cy, d, back=None):
    """Where a real player's Roblox headshot goes (it loads from Roblox in game): a
    stand-in bust on the soft backing colour Avatars.portrait puts behind it."""
    C = st.C
    st.circle(cx, cy, d, back or C["panelHi"])
    with st.layer(mask=_circle_mask(st, cx, cy, d)):
        st.rect(cx - d * 0.38, cy + d * 0.22, d * 0.76, d * 0.5, "#3D7BD9", corner=0.45)
        st.rect(cx - d * 0.27, cy - d * 0.33, d * 0.54, d * 0.54, "#F5CD30", corner=0.28)
        for ex in (-0.1, 0.1):
            st.circle(cx + ex * d, cy - d * 0.09, d * 0.07, "#2B2B2B")
        st.rect(cx - d * 0.09, cy + d * 0.03, d * 0.18, d * 0.045, "#2B2B2B", corner=0.5)


def _circle_mask(st, cx, cy, d):
    m = Image.new("L", st.img.size, 0)
    ImageDraw.Draw(m).ellipse([st.X(cx - d / 2), st.Y(cy - d / 2), st.X(cx + d / 2), st.Y(cy + d / 2)], fill=255)
    return m


def portrait(st, info, cx, cy, d, ring=None, ring_px=3, back=None):
    """Avatars.portrait: a real player's headshot (stand-in) on its backing, or the
    character medallion for bots and players without a headshot; ring = seat colour."""
    C = st.C
    T = st.theme
    if info.get("userId") and not info.get("isBot"):
        headshot(st, cx, cy, d, back)
    else:
        ch = info.get("character") or "info"
        st.medallion(ch, cx, cy, d, T.get("Character", {}).get(ch) or C["textFaint"])
    if ring:
        st.circle(cx, cy, d, None, stroke=(ring, ring_px))
