#!/usr/bin/env python3
"""Preview renderer for geometry dumped by tests/runtime.luau.

Ray-casts Roblox primitives (block, wedge, cylinder, ball, sphere-mesh ellipsoid) with numpy so the map, bases
and brainrots can be eyeballed without Roblox Studio. Not shipped with the game; it's a development aid.

Usage: python3 scripts/render.py dump.json out.png --eye X Y Z --look X Y Z [--size 960x540] [--fov 60]
"""
import argparse
import json
import math

import numpy as np
from PIL import Image

SUN = np.array([-0.45, 0.8, -0.35])
SUN = SUN / np.linalg.norm(SUN)


def load(path):
    with open(path) as f:
        parts = json.load(f)
    out = []
    for p in parts:
        if p["t"] > 0.6:
            continue
        cf = p["cf"]
        pos = np.array(cf[0:3])
        rot = np.array(cf[3:12]).reshape(3, 3)
        out.append((p["s"], np.array(p["sz"]) / 2.0, pos, rot, np.array(p["c"]), p["n"]))
    return out


def intersect(shape, half, o, d):
    """o, d: (N,3) rays in part-local space. Returns t (N,) with inf for misses and local normals (N,3)."""
    n = o.shape[0]
    t_hit = np.full(n, np.inf)
    normal = np.zeros((n, 3))
    if shape in ("Block", "Wedge"):
        with np.errstate(divide="ignore", invalid="ignore"):
            inv = 1.0 / d
            t1 = (-half - o) * inv
            t2 = (half - o) * inv
        tmin = np.minimum(t1, t2)
        tmax = np.maximum(t1, t2)
        tnear = np.nanmax(tmin, axis=1)
        tfar = np.nanmin(tmax, axis=1)
        axis = np.nanargmax(tmin, axis=1)
        if shape == "Wedge":
            # Half-space y/hy - z/hz <= 0
            pn = np.array([0.0, 1.0 / half[1], -1.0 / half[2]])
            denom = d @ pn
            num = -(o @ pn)
            with np.errstate(divide="ignore", invalid="ignore"):
                tp = num / denom
            entering = denom < 0
            inside0 = (o @ pn) <= 0
            plane_enter = np.where(entering, tp, -np.inf)
            plane_exit = np.where(~entering, tp, np.inf)
            use_plane = plane_enter > tnear
            tnear2 = np.maximum(tnear, plane_enter)
            tfar = np.minimum(tfar, np.where(denom == 0, np.where(inside0, np.inf, -np.inf), plane_exit))
            hit = (tnear2 <= tfar) & (tfar > 0) & (tnear2 > 0)
            t_hit = np.where(hit, tnear2, np.inf)
            nrm = np.zeros((n, 3))
            nrm[np.arange(n), axis] = -np.sign(d[np.arange(n), axis])
            pn_unit = pn / np.linalg.norm(pn)
            nrm[use_plane] = pn_unit
            return t_hit, nrm
        hit = (tnear <= tfar) & (tfar > 0) & (tnear > 0)
        t_hit = np.where(hit, tnear, np.inf)
        normal[np.arange(n), axis] = -np.sign(d[np.arange(n), axis])
        return t_hit, normal
    if shape in ("Ellipsoid", "Ball"):
        if shape == "Ball":
            r = half.min()
            half = np.array([r, r, r])
        os_ = o / half
        ds = d / half
        a = np.sum(ds * ds, axis=1)
        b = 2 * np.sum(os_ * ds, axis=1)
        c = np.sum(os_ * os_, axis=1) - 1
        disc = b * b - 4 * a * c
        ok = disc >= 0
        sq = np.sqrt(np.where(ok, disc, 0))
        t0 = (-b - sq) / (2 * a)
        t_hit = np.where(ok & (t0 > 0), t0, np.inf)
        p = o + d * np.where(np.isfinite(t_hit), t_hit, 0)[:, None]
        normal = p / (half * half)
        normal /= np.linalg.norm(normal, axis=1, keepdims=True) + 1e-9
        return t_hit, normal
    if shape == "Cylinder":
        r = min(half[1], half[2])
        hx = half[0]
        oy, oz, dy, dz = o[:, 1], o[:, 2], d[:, 1], d[:, 2]
        a = dy * dy + dz * dz
        b = 2 * (oy * dy + oz * dz)
        c = oy * oy + oz * oz - r * r
        disc = b * b - 4 * a * c
        ok = (disc >= 0) & (a > 1e-12)
        sq = np.sqrt(np.where(ok, disc, 0))
        with np.errstate(divide="ignore", invalid="ignore"):
            ts = (-b - sq) / (2 * a)
        xs = o[:, 0] + d[:, 0] * ts
        side = ok & (ts > 0) & (np.abs(xs) <= hx)
        with np.errstate(divide="ignore", invalid="ignore"):
            tc1 = (-hx - o[:, 0]) / d[:, 0]
            tc2 = (hx - o[:, 0]) / d[:, 0]
        tcap = np.where(np.minimum(tc1, tc2) > 0, np.minimum(tc1, tc2), np.maximum(tc1, tc2))
        pc = o + d * np.nan_to_num(tcap, posinf=0, neginf=0)[:, None]
        cap = (tcap > 0) & (pc[:, 1] ** 2 + pc[:, 2] ** 2 <= r * r)
        t_side = np.where(side, ts, np.inf)
        t_cap = np.where(cap, tcap, np.inf)
        t_hit = np.minimum(t_side, t_cap)
        p = o + d * np.where(np.isfinite(t_hit), t_hit, 0)[:, None]
        normal = np.zeros((n, 3))
        use_cap = t_cap < t_side
        normal[use_cap, 0] = np.sign(p[use_cap, 0])
        normal[~use_cap, 1] = p[~use_cap, 1]
        normal[~use_cap, 2] = p[~use_cap, 2]
        normal /= np.linalg.norm(normal, axis=1, keepdims=True) + 1e-9
        return t_hit, normal
    return t_hit, normal


def render(parts, eye, look, width, height, fov):
    eye = np.array(eye, dtype=float)
    look = np.array(look, dtype=float)
    forward = look - eye
    forward /= np.linalg.norm(forward)
    right = np.cross(forward, np.array([0.0, 1.0, 0.0]))
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    aspect = width / height
    scale = math.tan(math.radians(fov) / 2)
    xs = (np.arange(width) + 0.5) / width * 2 - 1
    ys = 1 - (np.arange(height) + 0.5) / height * 2
    gx, gy = np.meshgrid(xs * aspect * scale, ys * scale)
    dirs = forward[None, None, :] + gx[..., None] * right + gy[..., None] * up
    dirs = dirs.reshape(-1, 3)
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    npx = dirs.shape[0]
    depth = np.full(npx, np.inf)
    color = np.zeros((npx, 3))
    # sky gradient
    sky_t = (dirs[:, 1] + 0.2).clip(0, 1)
    color[:] = np.array([0.72, 0.85, 1.0]) * (1 - sky_t[:, None]) + np.array([0.35, 0.6, 0.95]) * sky_t[:, None]

    # project bounding spheres to cull pixels per part
    pix_idx = np.arange(npx)
    for shape, half, pos, rot, col, neon in parts:
        radius = np.linalg.norm(half)
        rel = pos - eye
        zc = rel @ forward
        if zc < -radius:
            continue
        dist = np.linalg.norm(rel)
        if dist < radius:
            sel = pix_idx
        else:
            if zc <= 0.1:
                continue
            sx = (rel @ right) / (zc * scale * aspect)
            sy = (rel @ up) / (zc * scale)
            ry = radius / (zc * scale) * 1.5
            rx = ry / aspect
            if sx + rx < -1 or sx - rx > 1 or sy + ry < -1 or sy - ry > 1:
                continue
            px0 = max(0, int(math.floor(((sx - rx) + 1) / 2 * width)) - 1)
            px1 = min(width, int(math.ceil(((sx + rx) + 1) / 2 * width)) + 1)
            py0 = max(0, int(math.floor((1 - (sy + ry)) / 2 * height)) - 1)
            py1 = min(height, int(math.ceil((1 - (sy - ry)) / 2 * height)) + 1)
            if px0 >= px1 or py0 >= py1:
                continue
            rows = np.arange(py0, py1)
            cols = np.arange(px0, px1)
            sel = (rows[:, None] * width + cols[None, :]).ravel()
        d_local = dirs[sel] @ rot  # world->local: R^T * v  == v @ R
        o_local = np.broadcast_to((eye - pos) @ rot, d_local.shape)
        t, nrm_local = intersect(shape, half, o_local, d_local)
        closer = t < depth[sel]
        if not closer.any():
            continue
        idx = sel[closer]
        depth[idx] = t[closer]
        nrm = nrm_local[closer] @ rot.T
        if neon:
            shade = np.ones(len(idx)) * 1.15
        else:
            lam = np.clip(nrm @ SUN, 0, 1)
            shade = 0.42 + 0.68 * lam
        color[idx] = np.clip(col[None, :] * shade[:, None], 0, 1)
    # distance fog
    fog = np.clip((depth - 260) / 500, 0, 0.7)
    fog = np.where(np.isfinite(depth), fog, 0)
    color = color * (1 - fog[:, None]) + np.array([0.75, 0.85, 1.0]) * fog[:, None]
    img = (color.reshape(height, width, 3) * 255).astype(np.uint8)
    return Image.fromarray(img)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dump")
    ap.add_argument("out")
    ap.add_argument("--eye", nargs=3, type=float, required=True)
    ap.add_argument("--look", nargs=3, type=float, required=True)
    ap.add_argument("--size", default="960x540")
    ap.add_argument("--fov", type=float, default=60)
    args = ap.parse_args()
    w, h = (int(v) for v in args.size.split("x"))
    parts = load(args.dump)
    img = render(parts, args.eye, args.look, w, h, args.fov)
    img.save(args.out)
    print(f"saved {args.out} ({len(parts)} parts)")


if __name__ == "__main__":
    main()
