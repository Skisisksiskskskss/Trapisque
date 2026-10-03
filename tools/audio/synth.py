#!/usr/bin/env python3
"""Synthesizes every Sift sound. Deterministic: `python3 tools/audio/synth.py`.

Owner playtest 3 (D-029): the first set was "random synthetic tones". This one is procedural foley:
each sound is built from a model of what makes it in the world, as a foley artist records it.
- Liquid: bubbles by Minnaert's law (a bubble of radius r rings at about 3.26/r Hz, damped, its
  pitch rising as it leaves; van den Doel's model), bursting films, splashes as an impact, a cloud
  of entrained bubbles and droplets falling back. Ichor is denser and thicker than water: its
  bubbles ring lower, die faster and burst with a heavy blop.
- Plants: granular rustle (thousands of tiny filtered noise grains), stems that snap through
  resonant bodies, wet fronds that squelch.
- Bells and glass: modal synthesis (measured partial ratios), each mode a close pair that beats,
  struck by a short click.
- The blub's voice: a voice source (harmonics with jitter and shimmer) through formant filters, so
  it has vowels, lips and breath like vanilla's creature recordings, not a sine.
- Bodies: thumps with a pitch drop, squishes through sweeping resonances.

Original audio only (hard rule 9.1; mission §7.5): every sample is computed below. Vanilla sounds
are only *measured* (peak and RMS) to match loudness; none is copied. Mono 44.1 kHz Ogg Vorbis, so
positional sounds attenuate. Assets are All Rights Reserved (D-003). Needs numpy, scipy, soundfile.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
NYQ = SR / 2
REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "src" / "main" / "resources" / "assets" / "thesift" / "sounds"
ASSETS = Path(os.path.expanduser("~/.gradle/caches/fabric-loom/assets"))


# ================================================================ DSP helpers
def n_of(seconds: float) -> int:
    return int(seconds * SR)


def t_axis(n: int) -> np.ndarray:
    return np.arange(n) / SR


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def _sos(kind: str, f, order: int):
    f = np.clip(np.asarray(f, dtype=float), 20.0, NYQ * 0.95)
    return signal.butter(order, f, btype=kind, fs=SR, output="sos")


def lp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("lowpass", f, order), x)


def hp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("highpass", f, order), x)


def bp(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(_sos("bandpass", [lo, hi], order), x)


def reson(x: np.ndarray, f: float, q: float) -> np.ndarray:
    """A two-pole resonator (constant peak gain): a body that rings at f."""
    w0 = 2 * np.pi * min(f, NYQ * 0.95) / SR
    alpha = np.sin(w0) / (2 * q)
    return signal.lfilter([alpha, 0, -alpha], [1 + alpha, -2 * np.cos(w0), 1 - alpha], x)


def sweep(x: np.ndarray, freq: np.ndarray, q: float, mode: str = "band") -> np.ndarray:
    """A state-variable filter whose cutoff moves sample by sample (Zavalishin's TPT form)."""
    g = np.tan(np.pi * np.clip(freq, 20, NYQ * 0.9) / SR)
    k = 1.0 / q
    a1 = 1 / (1 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    ic1 = ic2 = 0.0
    out = np.empty_like(x)
    for i in range(len(x)):
        v3 = x[i] - ic2
        v1 = a1[i] * ic1 + a2[i] * v3
        v2 = ic2 + a2[i] * ic1 + a3[i] * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        out[i] = v1 if mode == "band" else v2 if mode == "low" else x[i] - k * v1 - v2
    return out


def osc(freq, n: int, phase: float = 0.0) -> np.ndarray:
    """A sine; `freq` may be a scalar or an array (a glide), integrated for a clean phase."""
    f = np.full(n, float(freq)) if np.ndim(freq) == 0 else np.asarray(freq, dtype=float)[:n]
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def ar(n: int, attack: float, release: float, curve: float = 2.0) -> np.ndarray:
    """Attack ramp, hold, then a curved release over the last `release` seconds."""
    e = np.ones(n)
    a = max(1, min(n, n_of(attack)))
    e[:a] = np.linspace(0, 1, a) ** 1.5
    r = max(1, min(n - a, n_of(release)))
    e[n - r:] *= np.linspace(1, 0, r) ** curve
    return e


def expdecay(n: int, tau: float) -> np.ndarray:
    return np.exp(-t_axis(n) / max(1e-4, tau))


def swell(n: int, power: float = 2.0) -> np.ndarray:
    return np.sin(np.linspace(0, np.pi, n)) ** power


def place(out: np.ndarray, x: np.ndarray, start: float, gain: float = 1.0) -> None:
    s = n_of(start)
    if s >= len(out) or s < 0:
        return
    m = min(len(x), len(out) - s)
    out[s:s + m] += gain * x[:m]


def add(*parts: np.ndarray) -> np.ndarray:
    """Sums signals of different lengths, each from the start."""
    out = np.zeros(max(len(p) for p in parts))
    for p in parts:
        out[:len(p)] += p
    return out


def norm(x: np.ndarray) -> np.ndarray:
    return x / (np.max(np.abs(x)) + 1e-12)


def slow_noise(n: int, rate: float, rng: np.random.Generator) -> np.ndarray:
    """A smooth random curve in [-1, 1] wandering about `rate` times a second (gusts, wobbles)."""
    pts = max(4, int(n / SR * rate) + 3)
    knots = rng.uniform(-1, 1, pts)
    return np.interp(np.linspace(0, pts - 3, n), np.arange(pts), knots)


def reverb(x: np.ndarray, seconds: float, wet: float, rng: np.random.Generator, bright: float = 6000) -> np.ndarray:
    """A diffuse room: convolution with decaying noise whose highs die first (air absorbs them)."""
    n = n_of(seconds)
    t = t_axis(n)
    lo_band = lp(noise(n, rng), 900) * np.exp(-t / (seconds / 3.0))
    hi_band = bp(noise(n, rng), 900, bright) * np.exp(-t / (seconds / 6.0))
    ir = lo_band + 0.8 * hi_band
    ir[: n_of(0.012)] *= np.linspace(0, 1, n_of(0.012))  # a short pre-delay, as a room's first reflections
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    y = signal.fftconvolve(x, ir)
    out = np.zeros(len(y))
    out[:len(x)] = x * (1 - wet)
    return out + y * wet * 1.4


# ================================================================ liquid (van den Doel's bubbles)
def bubble(radius_mm: float, rng: np.random.Generator, dense: float = 1.0, visc: float = 1.0, rise: float = 0.1,
           amp: float = 1.0) -> np.ndarray:
    """One bubble ringing as it forms (Minnaert): f0 = 3.26/r, damping 0.043 f0 + 0.0014 f0^1.5,
    its pitch rising as it rises. `dense` lowers the ring (a denser liquid), `visc` damps it."""
    r = radius_mm * 1e-3
    f0 = 3.26 / r / np.sqrt(dense)
    d = (0.043 * f0 + 0.0014 * f0 ** 1.5) * visc
    n = max(64, min(n_of(0.6), int(7.0 / d * SR)))
    t = t_axis(n)
    f = f0 * (1 + rise * d * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR + rng.uniform(0, 0.4)) * np.exp(-d * t)
    x[:24] *= np.linspace(0, 1, 24)
    return amp * radius_mm ** 0.9 * x


def burst(radius_mm: float, rng: np.random.Generator, dense: float = 1.0) -> np.ndarray:
    """A bubble breaking the surface: the film tears (a click), then the open cavity rings down (a
    blop whose pitch falls as it fills). Thick liquids make the heavy pop of lava and mud."""
    cavity = 3.26 / (radius_mm * 1e-3) / np.sqrt(dense) * 0.55
    n = n_of(0.03 + radius_mm * 0.012)
    t = t_axis(n)
    blop = osc(cavity * (1.0 - 0.45 * t / t[-1]), n) * np.exp(-t / (0.006 + radius_mm * 0.0025))
    blop[:30] *= np.linspace(0, 1, 30)
    m = n_of(0.004)
    tear = hp(noise(m, rng), 2500) * expdecay(m, 0.0008)
    out = np.zeros(n)
    out[:m] += 0.18 * lp(tear, 9000)
    return radius_mm ** 0.8 * (out + blop)


def power_radius(rng: np.random.Generator, lo: float, hi: float, alpha: float = 2.2) -> float:
    """A radius from a power law: many small bubbles, few big ones (as a real bubble cloud)."""
    a = 1 - alpha
    return (lo ** a + rng.uniform() * (hi ** a - lo ** a)) ** (1 / a)


def babble(seconds: float, rate: float, lo: float, hi: float, rng: np.random.Generator, shape=None, dense: float = 1.0,
           visc: float = 1.0, rise: float = 0.1, alpha: float = 2.2) -> np.ndarray:
    """A cloud of bubbles: Poisson onsets at `rate` a second (scaled over time by `shape`, a function
    of 0..1), radii by a power law between lo and hi millimetres."""
    n = n_of(seconds)
    out = np.zeros(n + n_of(0.6))
    t = 0.0
    while True:
        t += rng.exponential(1 / rate)
        if t >= seconds:
            break
        if shape is not None and rng.uniform() > shape(t / seconds):
            continue
        b = bubble(power_radius(rng, lo, hi, alpha), rng, dense, visc, rise, rng.uniform(0.4, 1.0))
        place(out, b, t)
    return out[:n]


def splash(seconds: float, size: float, rng: np.random.Generator, dense: float = 1.0, visc: float = 1.0) -> np.ndarray:
    """Something meeting a liquid: the impact (a noise burst whose brightness falls as the crown
    collapses), a cloud of entrained bubbles, and droplets falling back as small high plinks."""
    n = n_of(seconds)
    m = n_of(0.05 + 0.08 * size)
    hit = sweep(noise(m, rng), np.geomspace(5200, 700, m), 0.9) * expdecay(m, 0.018 + 0.03 * size)
    hit += 0.6 * lp(noise(m, rng), 400) * expdecay(m, 0.03 + 0.04 * size)
    out = np.zeros(n)
    place(out, hit, 0.0, 1.4)
    cloud = babble(min(seconds, 0.45), 260 * size, 0.8, 3.5 + 4 * size, rng, lambda u: (1 - u) ** 2.5, dense, visc)
    place(out, cloud, 0.004, 0.35)
    drops = babble(max(0.05, seconds - 0.1), 40 * size, 0.5, 1.6, rng, lambda u: np.exp(-3 * u), dense, visc, 0.15)
    place(out, drops, 0.09, 0.25)
    return out


# ================================================================ plants and bodies
def rustle(seconds: float, density, rng: np.random.Generator, lo: float = 1500, hi: float = 7500, grain=(0.002, 0.016),
           q=(1.5, 4.0), rate: float = 600) -> np.ndarray:
    """Leaves: thousands of tiny filtered noise grains (each a leaf edge catching another), their
    density following `density` (a function of 0..1)."""
    n = n_of(seconds)
    out = np.zeros(n + n_of(grain[1]) + 8)
    t = 0.0
    while True:
        t += rng.exponential(1 / rate)
        if t >= seconds:
            break
        if rng.uniform() > density(t / seconds):
            continue
        g = n_of(rng.uniform(*grain))
        e = np.exp(-np.linspace(0, rng.uniform(3, 7), g))
        e[: max(1, g // 10)] *= np.linspace(0, 1, max(1, g // 10))
        x = reson(noise(g, rng), np.exp(rng.uniform(np.log(lo), np.log(hi))), rng.uniform(*q)) * e
        place(out, x, t, rng.lognormal(0, 0.6))
    return out[:n]


def snap(rng: np.random.Generator, body=(1300, 2700, 4300), q: float = 9.0, tau: float = 0.012) -> np.ndarray:
    """A stem breaking: two or three cracks a few milliseconds apart, ringing through the stem's body."""
    n = n_of(0.08)
    clicks = np.zeros(n)
    for k in range(rng.integers(2, 4)):
        s = n_of(rng.uniform(0, 0.008) + 0.004 * k)
        m = n_of(0.0015)
        clicks[s:s + m] += rng.uniform(0.5, 1.0) * noise(m, rng) * expdecay(m, 0.0004)
    out = sum(reson(clicks, f * rng.uniform(0.92, 1.08), q) for f in body)
    return (out + 0.3 * hp(clicks, 3000)) * expdecay(n, tau * 2)


def thump(rng: np.random.Generator, f0: float = 110, seconds: float = 0.12, weight: float = 1.0) -> np.ndarray:
    """A soft body landing: a low ring whose pitch drops as it settles, with a muffled impact."""
    n = n_of(seconds)
    t = t_axis(n)
    body = osc(f0 * (1 - 0.35 * t / seconds), n) * np.exp(-t / (seconds * 0.25))
    body[:40] *= np.linspace(0, 1, 40)
    hit = lp(noise(n, rng), 500 + 300 * weight) * np.exp(-t / 0.012)
    return weight * (body + 0.6 * hit)


def squish(rng: np.random.Generator, seconds: float = 0.09, f_hi: float = 1300, f_lo: float = 350, wet: float = 0.5) -> np.ndarray:
    """Something soft and wet squashing: noise through a resonance that sweeps down as it flattens."""
    n = n_of(seconds)
    x = lp(sweep(noise(n, rng), np.geomspace(f_hi, f_lo, n), 3.5), f_hi * 1.8) * ar(n, 0.006, seconds * 0.7)
    if wet:
        place(x, bubble(rng.uniform(4, 7), rng, 1.3, 1.6), seconds * 0.3, wet * 0.06)
    return x


# ================================================================ bells, glass, gongs (modal synthesis)
HANDBELL = [(1.0, 1.0, 1.0), (2.0, 0.55, 0.8), (2.76, 0.45, 0.55), (3.0, 0.3, 0.5), (4.18, 0.25, 0.35), (5.4, 0.22, 0.25),
            (6.73, 0.12, 0.18), (8.1, 0.08, 0.12)]
CHURCH = [(0.5, 0.7, 1.6), (1.0, 1.0, 1.0), (1.19, 0.6, 0.7), (1.5, 0.45, 0.6), (2.0, 0.55, 0.5), (2.51, 0.3, 0.35),
          (2.66, 0.25, 0.3), (3.01, 0.2, 0.25), (4.1, 0.12, 0.15)]
GLASS = [(1.0, 1.0, 1.0), (2.32, 0.5, 0.6), (4.25, 0.3, 0.35), (6.63, 0.15, 0.2)]
GONG = [(1.0, 1.0, 1.0), (1.52, 0.7, 0.85), (2.0, 0.5, 0.7), (2.44, 0.45, 0.6), (2.94, 0.4, 0.5), (3.43, 0.3, 0.42),
        (4.03, 0.25, 0.35), (4.62, 0.2, 0.3), (5.35, 0.15, 0.25), (6.1, 0.12, 0.2)]


def modal(f0: float, modes, seconds: float, rng: np.random.Generator, decay: float = 1.0, beat: float = 1.6,
          strike: float = 0.25, bright: float = 1.0, glide: float = 0.0) -> np.ndarray:
    """A struck body: each mode (ratio, amplitude, relative decay) rings as a close pair that beats,
    higher modes dying sooner; a short click is the striker. `glide` bends the low modes up (gongs)."""
    n = n_of(seconds)
    t = t_axis(n)
    out = np.zeros(n)
    for k, (ratio, a, rel) in enumerate(modes):
        f = f0 * ratio
        if f > NYQ * 0.9:
            continue
        tau = decay * rel * seconds * 0.35
        bend = 1 + glide * (1 - np.exp(-t / 0.6)) / (1 + k) if glide else 1.0
        d = beat * rng.uniform(0.5, 1.5) / 2
        pair = osc((f - d) * bend, n, rng.uniform(0, 6.28)) + rng.uniform(0.5, 0.9) * osc((f + d) * bend, n, rng.uniform(0, 6.28))
        out += a * (bright ** k) * pair * np.exp(-t / tau)
    m = n_of(0.004)
    click = hp(noise(m, rng), 3000) * expdecay(m, 0.0009)
    out[:m] += strike * 4 * click
    out[:30] *= np.linspace(0, 1, 30)
    return out


# ================================================================ the voice (source-filter)
VOWELS = {"m": (300, 900, 2300), "u": (330, 820, 2300), "o": (460, 880, 2450), "a": (760, 1250, 2600),
          "e": (480, 1900, 2650), "i": (300, 2250, 3000)}


def voice(f0, vowels, seconds: float, rng: np.random.Generator, scale: float = 1.6, tilt: float = 1.5,
          breath: float = 0.04, jitter: float = 0.006, shimmer: float = 0.08, open_close: bool = True) -> np.ndarray:
    """A small voice: harmonics of a wavering pitch (jitter, shimmer), each weighted by the formants
    of the vowel track as it moves; formants scaled up by `scale` for a tiny throat. `vowels` is a
    list of (position 0..1, vowel); `f0` a list of pitches spread over the sound. Lips open at the
    start and close at the end (a soft 'b' each side), as 'blub'."""
    n = n_of(seconds)
    u = np.linspace(0, 1, n)
    f = np.interp(u, np.linspace(0, 1, len(f0)), f0)
    f = f * (1 + jitter * slow_noise(n, 30, rng) + 0.5 * jitter * slow_noise(n, 7, rng))
    phase = 2 * np.pi * np.cumsum(f) / SR
    pos = [p for p, _ in vowels]
    tracks = [np.interp(u, pos, [VOWELS[v][i] * scale for _, v in vowels]) for i in range(3)]
    if open_close:  # lips: F1 low while closed
        lips = np.minimum(1, np.minimum(u / 0.12, (1 - u) / 0.15)) ** 0.7
        tracks[0] = tracks[0] * (0.45 + 0.55 * lips)
    widths = (90 * scale, 120 * scale, 170 * scale)
    gains = (1.0, 0.65, 0.35)
    out = np.zeros(n)
    for k in range(1, 60):
        fk = k * f
        if np.min(fk) > NYQ * 0.85:
            break
        h = sum(g / (1 + ((fk - F) / (W / 2)) ** 2) for F, W, g in zip(tracks, widths, gains))
        out += (h + 0.02) * k ** (-tilt) * np.sin(k * phase + k * 0.7) * (fk < NYQ * 0.85)
    out *= 1 + shimmer * slow_noise(n, 40, rng)
    asp = sum(g * reson(noise(n, rng), float(np.mean(F)), 3.0) for F, g in zip(tracks[1:], (0.6, 0.4)))
    out = out / (np.max(np.abs(out)) + 1e-9) + breath * asp / (np.std(asp) + 1e-9) * 0.3
    return lp(out, 6500) * ar(n, 0.012, seconds * 0.35)  # a small soft throat: no buzz above


def whisper(vowels, seconds: float, rng: np.random.Generator, scale: float = 1.0) -> np.ndarray:
    """Breath shaped by a mouth: noise through moving formants (a sigh, an inhale, a hush)."""
    n = n_of(seconds)
    u = np.linspace(0, 1, n)
    pos = [p for p, _ in vowels]
    out = np.zeros(n)
    src = noise(n, rng)
    for i, g in enumerate((0.8, 1.0, 0.6)):
        track = np.interp(u, pos, [VOWELS[v][i] * scale for _, v in vowels])
        out += g * sweep(src, track, 4.0 + 2 * i)
    return out


# ================================================================ loudness
def vanilla(path: str) -> np.ndarray | None:
    idx = next((ASSETS / "indexes").glob("*.json"), None)
    if idx is None:
        return None
    obj = json.loads(idx.read_text())["objects"].get("minecraft/sounds/" + path)
    if obj is None:
        return None
    h = obj["hash"]
    data, _ = sf.read(ASSETS / "objects" / h[:2] / h, always_2d=True)
    return data.mean(axis=1)


def levels(x: np.ndarray) -> tuple[float, float]:
    """Peak dBFS and RMS dBFS over the audible part (above -40 dB of the peak)."""
    peak = np.max(np.abs(x)) + 1e-12
    loud = x[np.abs(x) > peak * 0.01]
    rms = np.sqrt(np.mean(loud ** 2)) + 1e-12
    return 20 * np.log10(peak), 20 * np.log10(rms)


LOG: list[str] = []


def finish(x: np.ndarray) -> np.ndarray:
    """No DC, no clicks: a gentle high-pass under 30 Hz, a fade at each end."""
    x = hp(np.asarray(x, dtype=float), 30, 2)
    fade = min(len(x) // 4, n_of(0.02))
    x[-fade:] *= np.linspace(1, 0, fade)
    x[:64] *= np.linspace(0, 1, 64)
    return x


def write(name: str, x: np.ndarray, refs: list[str]) -> None:
    """Matches RMS to the mean of the vanilla references (peak capped at -1 dBFS), then writes."""
    x = finish(x)
    targets = [levels(v) for v in (vanilla(r) for r in refs) if v is not None]
    if targets:
        t_rms = float(np.mean([t[1] for t in targets]))
        _, rms = levels(x)
        x = x * 10 ** ((t_rms - rms) / 20)
    peak = np.max(np.abs(x))
    if peak > 10 ** (-1 / 20):
        x = x * 10 ** (-1 / 20) / peak
    out = OUT / (name + ".ogg")
    out.parent.mkdir(parents=True, exist_ok=True)
    sf.write(out, x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    p, r = levels(x)
    ref = " / ".join(f"{t[0]:.1f}, {t[1]:.1f}" for t in targets) or "—"
    LOG.append(f"| `{name}` | {len(x) / SR:.2f} s | {p:.1f} / {r:.1f} | {', '.join(refs) or '—'} | {ref} |")


# ================================================================ the sounds
# Ichor: denser than water (its bubbles ring about a fifth lower) and thicker (they die faster and
# burst heavily). One pair of numbers for every ichor sound, so they sound like one liquid.
ICHOR_DENSE = 1.45
ICHOR_VISC = 1.7


def ichor(rng: np.random.Generator) -> None:
    for i in range(1, 4):  # ambient: thick bubbles welling up and bursting at the surface, a murmur below
        d = rng.uniform(1.3, 1.9)
        n = n_of(d)
        out = np.zeros(n)
        under = babble(d, 18, 2.0, 6.0, rng, lambda u: np.sin(np.pi * u) ** 2, ICHOR_DENSE, ICHOR_VISC)
        place(out, under, 0.0, 0.25)
        for _ in range(rng.integers(1, 4)):
            r = rng.uniform(6, 12)
            s = rng.uniform(0.05, d - 0.35)
            place(out, bubble(r, rng, ICHOR_DENSE, ICHOR_VISC, 0.25), s, 0.35)
            place(out, burst(r, rng, ICHOR_DENSE), s + rng.uniform(0.12, 0.25), 0.9)
        write(f"ichor/ambient{i}", out, ["liquid/lavapop.ogg", "liquid/water.ogg"])
    for i in range(1, 3):  # filling a bucket: the scoop's splash, ichor rushing in, the pitch climbing as it fills
        d = 0.75
        n = n_of(d)
        out = np.zeros(n)
        place(out, splash(0.5, 0.7, rng, ICHOR_DENSE, ICHOR_VISC), 0.0, 0.8)
        m = n_of(0.5)
        rush = lp(sweep(noise(m, rng), np.geomspace(320 + 30 * i, 900 + 40 * i, m), 6.0), 1600) * swell(m, 1.2)
        place(out, rush, 0.06, 0.5)
        for k in range(5):  # glugs as air leaves the bucket, each higher than the last
            r = 9.0 - 1.2 * k + rng.uniform(-0.5, 0.5)
            place(out, bubble(r, rng, ICHOR_DENSE, ICHOR_VISC, 0.3), 0.08 + 0.085 * k + rng.uniform(0, 0.02), 0.5)
        write(f"ichor/bucket_fill{i}", out, ["item/bucket/fill1.ogg", "item/bucket/fill2.ogg", "item/bucket/fill_lava1.ogg"])
    for i in range(1, 3):  # emptying: glugs as air enters the bucket, the ichor slapping down in a thick splash
        d = 0.9
        n = n_of(d)
        out = np.zeros(n)
        for k in range(4):
            r = 8.0 + 1.5 * k + rng.uniform(-0.6, 0.6)
            place(out, bubble(r, rng, ICHOR_DENSE, ICHOR_VISC, 0.25), 0.02 + 0.1 * k, 0.45)
        place(out, splash(0.6, 1.0, rng, ICHOR_DENSE, ICHOR_VISC), 0.22 + 0.03 * i, 1.0)
        m = n_of(0.35)
        pour = lp(noise(m, rng), 900) * swell(m, 1.0)
        place(out, pour, 0.05, 0.25)
        write(f"ichor/bucket_empty{i}", out, ["item/bucket/empty1.ogg", "item/bucket/empty2.ogg", "item/bucket/empty_lava1.ogg"])
    # Evaporating (outside the Sift): a sizzle of tiny bursting bubbles, a hiss of vapour, fading.
    d = 1.3
    n = n_of(d)
    sizzle = babble(d, 2200, 0.25, 0.9, rng, lambda u: np.exp(-2.5 * u), 1.0, 2.5, 0.2)
    hiss = hp(noise(n, rng), 3500) * np.exp(-t_axis(n) / 0.35)
    steam = bp(noise(n, rng), 600, 2500) * swell(n, 1.0) * np.exp(-t_axis(n) / 0.6)
    write("ichor/evaporate", 0.6 * sizzle + 0.25 * hiss + 0.2 * steam, ["random/fizz.ogg"])


def tides(rng: np.random.Generator) -> None:
    # Thrive: dawn bells, a bright chord struck one by one and left to ring.
    d = 4.2
    n = n_of(d)
    out = np.zeros(n)
    for f, s in ((523.3, 0.0), (659.3, 0.14), (784.0, 0.28), (1046.5, 0.5)):
        place(out, modal(f, HANDBELL, d - s, rng, 1.2, 1.2, 0.3), s, 0.6)
    write("tide/thrive", reverb(out, 2.4, 0.4, rng), ["block/bell/bell_use01.ogg", "block/bell/resonate.ogg"])
    # Flow: the tide coming in, a long surge of thick ichor with foam fizzing on it and a low bell under it.
    d = 4.0
    n = n_of(d)
    surge_env = swell(n, 1.5) * (0.75 + 0.25 * slow_noise(n, 2, rng))
    surge = sweep(noise(n, rng), 250 + 900 * swell(n, 2.0), 0.8, "low") * surge_env
    foam = babble(d, 900, 0.3, 1.2, rng, lambda u: np.sin(np.pi * u) ** 3, ICHOR_DENSE, ICHOR_VISC)
    deep = babble(d, 14, 6, 14, rng, lambda u: np.sin(np.pi * u) ** 2, ICHOR_DENSE, ICHOR_VISC, 0.25)
    toll = modal(98.0, CHURCH, d, rng, 1.6, 0.8, 0.1, 0.8)
    write("tide/flow", reverb(surge + 0.3 * foam + 0.25 * deep + 0.35 * toll, 2.2, 0.35, rng), ["block/bell/resonate.ogg"])
    # Endure: a deep gong whose pitch blooms upward and whose high shimmer arrives late, as a tam-tam's.
    d = 6.0
    n = n_of(d)
    gong = modal(62.0, GONG, d, rng, 1.8, 0.7, 0.4, 0.92, glide=0.035)
    shimmer = bp(noise(n, rng), 1800, 6500) * (t_axis(n) / 0.9) * np.exp(-t_axis(n) / 0.9)
    strike = np.zeros(n)
    place(strike, modal(261.6, CHURCH, d * 0.7, rng, 0.9, 1.0, 0.2, 0.7), 0.0)
    write("tide/endure", reverb(gong + 0.08 * shimmer + 0.25 * strike, 3.0, 0.4, rng),
          ["block/bell/bell_use01.ogg", "block/bell/resonate.ogg"])
    for i in range(1, 4):  # a basin filling: ichor welling up through the vent, a gush under rising bubbles
        d = 1.5
        n = n_of(d)
        gush = lp(noise(n, rng), 380 + 60 * i) * (0.6 + 0.4 * np.sin(2 * np.pi * (3.2 + 0.4 * i) * t_axis(n))) * ar(n, 0.25, 0.5)
        rising = babble(d, 70, 2.5, 11, rng, lambda u: min(1.0, 3 * u) * (1.1 - u), ICHOR_DENSE, ICHOR_VISC, 0.2)
        pops = np.zeros(n)
        for _ in range(3):
            place(pops, burst(rng.uniform(7, 12), rng, ICHOR_DENSE), rng.uniform(0.3, d - 0.2), 0.6)
        write(f"tide/basin_fill{i}", 0.5 * gush + 0.7 * rising + pops,
              ["block/bubble_column/upwards_ambient1.ogg", "block/bubble_column/upwards_ambient2.ogg"])
    for i in range(1, 3):  # draining: a vortex at the vent, a sucking rush and glugs, slowing as it empties
        d = 1.7
        n = n_of(d)
        suck = sweep(noise(n, rng), np.geomspace(1400, 300, n), 2.5) * ar(n, 0.1, 0.8)
        swirl = lp(noise(n, rng), 300) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(np.linspace(7, 3, n)) / SR))
        out = 0.45 * suck + 0.4 * swirl
        s, k = 0.05, 0
        while s < d - 0.15:
            place(out, bubble(9 + k * 0.8 + rng.uniform(-1, 1), rng, ICHOR_DENSE, ICHOR_VISC, 0.15), s, 0.6)
            s += 0.12 + 0.03 * k + rng.uniform(0, 0.03)
            k += 1
        write(f"tide/basin_drain{i}", out, ["block/bubble_column/whirlpool_ambient1.ogg", "block/bubble_column/whirlpool_ambient2.ogg"])


def entry(rng: np.random.Generator) -> None:
    for i in range(1, 4):  # the offering: the soul stream drawn into the frame, sparkling as it goes
        d = 0.5
        n = n_of(d)
        draw = sweep(noise(n, rng), np.geomspace(500 + 100 * i, 3200 + 200 * i, n), 2.0) * swell(n, 2.0)
        out = 0.6 * draw
        for _ in range(7):
            f = rng.choice([1568.0, 1760.0, 2093.0, 2349.3, 2637.0]) * (1 + 0.003 * rng.standard_normal())
            place(out, modal(f, GLASS, 0.25, rng, 0.6, 3.0, 0.05, 0.6), rng.uniform(0.05, 0.4), 0.12)
        write(f"entry/offer{i}", out, ["block/respawn_anchor/charge1.ogg", "block/respawn_anchor/charge2.ogg"])
    # Waking: a deep swell, then a low choir of breathy voices opening onto bells.
    d = 3.2
    n = n_of(d)
    drone = (osc(55, n) + 0.5 * osc(110.3, n) + 0.25 * osc(164.8, n)) * ar(n, 0.9, 1.6, 1.5)
    choir = sum(voice([f, f * 1.003, f], [(0, "u"), (0.5, "o"), (1, "a")], d, rng, 1.0, 1.4, 0.15, 0.004, 0.05, False)
                for f in (220.0, 261.6, 329.6, 440.0))
    choir *= ar(n, 1.2, 1.4, 1.5)
    bells = np.zeros(n)
    for f, s in ((440, 0.6), (523.3, 0.75), (659.3, 0.9), (987.8, 1.1)):
        place(bells, modal(f, HANDBELL, d - s, rng, 1.0, 1.0, 0.2, 0.9), s, 0.25)
    write("entry/wake", reverb(0.6 * drone + 0.35 * norm(choir) + bells, 2.2, 0.4, rng), ["block/beacon/activate.ogg"])
    # Opening: a swirling phaser of air widening as partials climb an octave, then a bloom.
    d = 2.4
    n = n_of(d)
    u = np.linspace(0, 1, n)
    air = sweep(noise(n, rng), 300 + 2500 * u ** 1.5 + 400 * np.sin(2 * np.pi * 3 * u), 3.0) * ar(n, 0.7, 0.7)
    climb = sum((0.7 ** k) * osc(np.geomspace(f, 2 * f, n), n) for k, f in enumerate((220, 330, 440, 660))) * ar(n, 0.8, 0.8)
    write("entry/open", reverb(0.5 * air + 0.35 * climb, 1.8, 0.35, rng), ["block/end_portal/endportal.ogg", "block/conduit/activate.ogg"])
    for i in range(1, 3):  # the awake frame: a low resonant hum, slowly beating, with a flutter of air
        d = 2.6
        n = n_of(d)
        f = 73.4 * (1.0 if i == 1 else 1.122)
        hum = osc(f, n) + 0.5 * osc(f * 1.007, n) + 0.3 * osc(2 * f, n) + 0.12 * osc(3.003 * f, n)
        flutter = bp(noise(n, rng), 150, 900) * (0.5 + 0.5 * slow_noise(n, 6, rng)) * 0.15
        write(f"entry/hum{i}", (hum / 2 + flutter) * ar(n, 0.8, 1.2, 1.5), ["block/beacon/ambient.ogg"])
    for i in range(1, 4):  # the membrane: thin glass rung by the air, a few notes, a breath of wind
        d = 1.8
        n = n_of(d)
        out = 0.05 * bp(noise(n, rng), 2000, 7000) * swell(n, 1.0)
        for f, s in zip(rng.choice([1046.5, 1174.7, 1318.5, 1568.0, 1760.0], size=3, replace=False), (0.0, 0.2, 0.45)):
            place(out, modal(f, GLASS, d - s, rng, 1.3, 2.0, 0.08, 0.7), s, 0.35)
        write(f"entry/membrane{i}", reverb(out, 1.6, 0.4, rng), ["block/amethyst/shimmer.ogg", "portal/portal.ogg"])
    # Crossing: a long swirl of wind pulling upward, a rising choir, and a soft bell as you land.
    d = 3.4
    n = n_of(d)
    u = np.linspace(0, 1, n)
    wind = sweep(noise(n, rng), 400 + 1800 * u + 600 * np.sin(2 * np.pi * 5 * u), 2.0) * ar(n, 1.2, 1.0)
    rise = voice(list(np.geomspace(196, 392, 8)), [(0, "u"), (1, "a")], d, rng, 1.0, 1.3, 0.2, 0.004, 0.05, False) * ar(n, 1.4, 1.0)
    land = np.zeros(n)
    place(land, modal(784.0, HANDBELL, 1.4, rng, 1.0, 1.0, 0.3), d - 1.4, 0.4)
    write("entry/travel", reverb(0.55 * wind + 0.3 * rise + land, 1.8, 0.35, rng), ["portal/travel.ogg"])


def notice(rng: np.random.Generator) -> None:
    """The frame notices you (entry_path.md stage 2): a breath drawn in through an unseen mouth."""
    for i in range(1, 3):
        d = 1.4
        n = n_of(d)
        breath = whisper([(0, "u"), (0.6, "o"), (1, "a")], d, rng, 0.9 + 0.1 * i) * swell(n, 2.0) * np.linspace(0.6, 1, n)
        shimmer = 0.03 * osc(np.linspace(1480 + 40 * i, 1760 + 40 * i, n), n) * swell(n, 4.0)
        write(f"entry/notice{i}", reverb(norm(breath) * 0.5 + shimmer, 1.3, 0.35, rng), ["ambient/cave/cave1.ogg", "ambient/cave/cave2.ogg"])


def flute(f: float, seconds: float, rng: np.random.Generator) -> np.ndarray:
    """A breathy wooden flute: a chiff on the attack, breath riding on the harmonics, late vibrato."""
    n = n_of(seconds)
    u = np.linspace(0, 1, n)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t_axis(n)) * np.clip((u - 0.25) / 0.4, 0, 1)
    tone_ = osc(f * vib, n) + 0.25 * osc(2 * f * vib, n) + 0.08 * osc(3 * f * vib, n)
    breath = sum(reson(noise(n, rng), f * k, 30) * g for k, g in ((1, 1.0), (2, 0.5)))
    breath = breath / (np.std(breath) + 1e-9) * 0.12
    chiff = bp(noise(n, rng), f * 2, f * 5) * expdecay(n, 0.03) * 0.4
    return (tone_ + breath + chiff) * ar(n, 0.06, seconds * 0.4)


def meadow(rng: np.random.Generator) -> None:
    # The loop: wind over grass in gusts (a moving filter on noise, leaves rustling as each gust passes),
    # far flute notes, a chime bell now and then. Built twice as long, then cross-faded so it loops.
    d = 24.0
    n = n_of(d)
    gust = 0.55 + 0.45 * slow_noise(n, 0.35, rng)
    wind = sweep(noise(n, rng), 280 + 700 * gust, 0.7, "low") * gust
    leaves = rustle(d, lambda u: max(0.0, float(np.interp(u, np.linspace(0, 1, n), gust)) - 0.45) * 1.6, rng, 1800, 7000,
                    rate=900)
    out = norm(wind) * 0.35 + norm(leaves) * 0.08
    for _ in range(7):
        f = rng.choice([587.3, 659.3, 784.0, 880.0, 1046.5])
        dur = rng.uniform(1.4, 3.0)
        place(out, flute(f, dur, rng), rng.uniform(0, d - dur), 0.07)
    for _ in range(3):
        place(out, modal(rng.choice([1568.0, 1760.0, 2093.0]), HANDBELL, 1.0, rng, 0.8, 1.5, 0.2), rng.uniform(0, d - 1), 0.03)
    half = n // 2
    fade = np.linspace(0, 1, half)
    write("ambient/meadow_loop", out[:half] * fade + out[half:] * (1 - fade), ["ambient/nether/basalt_deltas/ambience.ogg"])
    for i in range(1, 5):  # mood: a far flute phrase in a wide space
        d = 5.0
        n = n_of(d)
        phrase = np.zeros(n)
        start = 0.2
        for f in rng.choice([392.0, 440.0, 523.3, 587.3, 659.3], size=3):
            dur = rng.uniform(0.7, 1.2)
            place(phrase, flute(f, dur, rng), start)
            start += dur * 0.85
        write(f"ambient/meadow_mood{i}", reverb(phrase, 3.2, 0.6, rng), ["ambient/cave/cave1.ogg", "ambient/cave/cave2.ogg"])


def blub(rng: np.random.Generator) -> None:
    """The Blub: a small round voice with lips ('blub'), a wet little throat, soft feet. The echo's
    note is F#5, so note-block pitches land in tune."""
    chirpy = ["mob/chicken/say1.ogg", "mob/chicken/say2.ogg", "mob/armadillo/ambient1.ogg", "mob/armadillo/ambient2.ogg"]
    for i in range(1, 5):  # ambient: a soft 'blub' coo, each its own contour, with a wet click at the lips
        base = rng.uniform(560, 760)
        d = rng.uniform(0.22, 0.32)
        x = voice([base * 0.92, base * 1.12, base * rng.uniform(0.9, 1.05)], [(0, "m"), (0.35, "u"), (1, "o")], d, rng, 1.7)
        lips = bubble(rng.uniform(3, 4.5), rng, 1.2, 1.4)
        out = np.zeros(len(x) + n_of(0.05))
        place(out, x, 0.012)
        place(out, lips, 0.0, 0.03)
        write(f"blub/ambient{i}", out, chirpy)
    for i in range(1, 3):  # listen: a curious rising 'mm?'
        d = 0.3
        write(f"blub/listen{i}", voice([560 + 30 * i, 640, 980 + 60 * i], [(0, "m"), (0.5, "u"), (1, "e")], d, rng, 1.7), chirpy)
    for i in range(1, 3):  # happy: a bright two-note 'bi-bip!'
        a = voice([820, 1050, 980], [(0, "m"), (0.4, "e"), (1, "i")], 0.13, rng, 1.8)
        b = voice([980, 1300 + 50 * i, 1180], [(0, "m"), (0.3, "i"), (1, "e")], 0.17, rng, 1.8)
        out = np.zeros(n_of(0.36))
        place(out, a, 0.0)
        place(out, b, 0.15)
        write(f"blub/happy{i}", out, chirpy)
    # sing: the echo, a clean sung 'oo' on F#5 with a little scoop and a late vibrato; pitch set per note in code.
    f0 = 739.99
    d = 0.55
    n = n_of(d)
    contour = [f0 * 0.95, f0, f0, f0, f0, f0, f0, f0]
    x = voice(contour, [(0, "m"), (0.15, "u"), (1, "u")], d, rng, 1.6, 1.4, 0.02, 0.002, 0.03)
    x *= 1 + 0.04 * np.sin(2 * np.pi * 5.5 * t_axis(n)) * np.clip(np.linspace(-1, 1, n), 0, 1)
    write("blub/sing", x, ["note/harp.ogg"])
    for i in range(1, 3):  # restless: quick nervous chitters
        out = np.zeros(n_of(0.55))
        for k in range(5):
            hi = 900 + 110 * ((k + i) % 2) + rng.uniform(-40, 40)
            place(out, voice([hi, hi * 1.15, hi * 0.95], [(0, "m"), (0.5, "i"), (1, "e")], 0.07, rng, 1.8), 0.1 * k + 0.01 * i)
        write(f"blub/restless{i}", out, chirpy)
    for i in range(1, 3):  # curl: a sleepy purr, breath pulsing at a purr's rate, a hummed note under it
        d = 1.3
        n = n_of(d)
        t = t_axis(n)
        purr_rate = 24 + 2 * i
        pulse = (0.5 + 0.5 * np.sin(2 * np.pi * purr_rate * t)) ** 3
        purr = lp(noise(n, rng), 1100) * pulse
        hum = voice([300 + 15 * i, 310 + 15 * i, 290 + 15 * i], [(0, "m"), (1, "u")], d, rng, 1.5, 1.3, 0.1, 0.008, 0.1)
        write(f"blub/curl{i}", (norm(purr) * 0.6 + 0.35 * hum) * swell(n, 1.0), ["mob/cat/purr2.ogg", "mob/armadillo/ambient1.ogg"])
    for i in range(1, 3):  # splash: a small body dropping into ichor, a plop and a few droplets
        d = 0.5
        out = np.zeros(n_of(d))
        place(out, splash(0.45, 0.45, rng, ICHOR_DENSE, ICHOR_VISC), 0.0)
        place(out, bubble(9 + i, rng, ICHOR_DENSE, ICHOR_VISC, 0.3), 0.02, 0.5)
        write(f"blub/splash{i}", out, ["mob/slime/small1.ogg", "mob/slime/small2.ogg"])
    for i in range(1, 3):  # topple: the tower tumbling, soft bodies landing one after another, a startled 'eep'
        out = np.zeros(n_of(0.75))
        for k in range(3):
            place(out, add(thump(rng, 120 - 15 * k, 0.12, 0.8), 0.6 * squish(rng, 0.08, 1500, 400, 0.3)), 0.05 + 0.11 * k + rng.uniform(0, 0.02))
        place(out, voice([1150, 1500 + 60 * i, 1250], [(0, "e"), (1, "i")], 0.14, rng, 1.8), 0.42, 0.6)
        write(f"blub/topple{i}", out, ["mob/slime/small1.ogg", "mob/slime/small3.ogg"])
    for i in range(1, 3):  # hurt: a sharp 'eep!'
        write(f"blub/hurt{i}", voice([1250 + 40 * i, 1650, 1100], [(0, "e"), (0.3, "i"), (1, "e")], 0.17, rng, 1.9, 1.1, 0.08),
              ["mob/axolotl/hurt1.ogg", "mob/axolotl/hurt2.ogg"])
    d = 0.8  # death: a squeak that deflates, more breath than voice by the end
    n = n_of(d)
    v = voice([1150, 1250, 850, 500, 320], [(0, "i"), (0.4, "o"), (1, "u")], d, rng, 1.8, 1.3, 0.2) * np.linspace(1, 0.35, n)
    air = whisper([(0, "o"), (1, "u")], d, rng, 1.6) * np.linspace(0, 1, n) ** 2 * ar(n, 0.01, 0.25)
    write("blub/death", v + 0.3 * norm(air), ["mob/axolotl/death1.ogg", "mob/axolotl/death2.ogg"])
    for i in range(1, 4):  # hop: pushing off with a squish, landing soft
        out = np.zeros(n_of(0.32))
        place(out, squish(rng, 0.07, 1100 + 100 * i, 500, 0.0), 0.0, 0.5)
        place(out, add(thump(rng, 130 + 10 * i, 0.1, 0.7), 0.5 * squish(rng, 0.06, 900, 300, 0.2)), 0.2)
        write(f"blub/hop{i}", out, ["mob/rabbit/hop1.ogg", "mob/rabbit/hop2.ogg", "mob/slime/small1.ogg"])
    for i in range(1, 5):  # step: a soft padded foot in the grass
        out = np.zeros(n_of(0.12))
        place(out, thump(rng, 150 + 12 * i, 0.06, 0.6), 0.0)
        place(out, rustle(0.08, lambda u: 1 - u, rng, 1500, 6000, (0.002, 0.008), rate=900), 0.003, 0.25)
        write(f"blub/step{i}", out, ["mob/frog/step1.ogg", "mob/frog/step2.ogg"])


def flora(rng: np.random.Generator) -> None:
    """Flora II: wrack unfurls wet and slippery, the Endure bloom's glassy petals rustle open, a pick
    is a stem snapping, chime bells ring small and sing along with music."""
    blossom = ["block/eyeblossom/eyeblossom_open1.ogg", "block/eyeblossom/eyeblossom_open2.ogg", "block/eyeblossom/eyeblossom_close1.ogg"]
    for i in range(1, 3):  # tidewrack: wet fronds sliding over each other, a squelch, a bubble let go
        d = 0.6 + 0.05 * i
        n = n_of(d)
        fronds = rustle(d, lambda u: np.sin(np.pi * u) ** 1.5, rng, 500, 2600, (0.006, 0.03), (2.0, 5.0), 500)
        out = norm(fronds) * 0.7
        place(out, squish(rng, 0.12, 900, 260, 0.0), 0.12 * i, 0.5)
        place(out, babble(0.3, 20, 2.5, 6, rng, None, ICHOR_DENSE, ICHOR_VISC), 0.2, 0.25)
        write(f"flora/tidewrack_open{i}", out, blossom)
        fronds = rustle(d, lambda u: (1 - u) ** 1.5, rng, 450, 2200, (0.006, 0.03), (2.0, 5.0), 500)
        out = norm(fronds) * 0.7
        place(out, squish(rng, 0.1, 700, 220, 0.0), 0.05, 0.5)
        write(f"flora/tidewrack_close{i}", out, blossom)
    for i in range(1, 3):  # the Endure bloom: crisp petals rustling apart, a faint glassy ring as they open
        d = 0.9
        n = n_of(d)
        petals = rustle(d, lambda u: np.sin(np.pi * u) ** 2, rng, 2500, 8000, (0.002, 0.01), (2.0, 4.0), 700)
        ring = modal(1318.5 * (1 + 0.06 * i), GLASS, d, rng, 1.0, 1.5, 0.0, 0.6) * swell(n, 1.5)
        write(f"flora/endure_bloom_open{i}", reverb(norm(petals) * 0.6 + 0.12 * ring, 1.0, 0.3, rng), blossom)
        petals = rustle(d, lambda u: np.sin(np.pi * u) ** 3, rng, 2200, 7000, (0.002, 0.01), (2.0, 4.0), 600)
        ring = modal(1174.7 * (1 + 0.06 * i), GLASS, d, rng, 0.8, 1.5, 0.0, 0.6) * swell(n, 2.0)
        write(f"flora/endure_bloom_close{i}", reverb(norm(petals) * 0.6 + 0.08 * ring, 1.0, 0.3, rng), blossom)
    for i in range(1, 4):  # a pick: the stem snapping, leaves shaking after it
        out = np.zeros(n_of(0.3))
        place(out, snap(rng, (1100 + 150 * i, 2500 + 200 * i, 4200)), 0.0, 1.0)
        place(out, rustle(0.25, lambda u: (1 - u) ** 2, rng, 1500, 6500, rate=800), 0.01, 0.35)
        write(f"flora/pick{i}", out, ["item/sweet_berries/pick_from_bush1.ogg", "item/sweet_berries/pick_from_bush2.ogg",
                                     "block/sweet_berry_bush/break1.ogg"])
    for i, f in enumerate([1568, 1760, 1976, 2093], start=1):  # a ring: three small bells knocking together
        d = 1.0
        out = np.zeros(n_of(d))
        for k, (ratio, s) in enumerate(((1.0, 0.0), (1.335, 0.035), (0.749, 0.07))):
            place(out, modal(f * ratio, HANDBELL, d - s, rng, 0.8, 2.0, 0.35, 0.8), s, 0.5 / (1 + 0.4 * k))
        place(out, rustle(0.15, lambda u: 1 - u, rng, 2000, 7000, rate=600), 0.0, 0.1)
        write(f"flora/chime_ring{i}", reverb(out, 1.0, 0.25, rng), ["block/amethyst/resonate1.ogg", "block/amethyst/resonate2.ogg"])
    for i in range(1, 3):  # a hum: the bells singing along, as a glass sings when its note is played near it
        d = 1.8
        n = n_of(d)
        f = 784 * (1.0 + 0.12 * (i - 1))
        hum = (osc(f, n) + 0.6 * osc(f * 1.0035, n) + 0.25 * osc(f * 2.0, n) + 0.1 * osc(f * 2.76, n)) * swell(n, 2.0)
        write(f"flora/chime_hum{i}", reverb(hum, 1.5, 0.4, rng), ["block/amethyst/resonate3.ogg", "block/amethyst/resonate4.ogg"])


def main() -> None:
    # One seed per family, so changing one family leaves the others' files byte-identical.
    entry(np.random.default_rng(20261001))
    tides(np.random.default_rng(20261011))
    ichor(np.random.default_rng(20261021))
    meadow(np.random.default_rng(20261031))
    blub(np.random.default_rng(20261041))
    notice(np.random.default_rng(20261002))
    flora(np.random.default_rng(20261003))
    log = REPO / "docs" / "DESIGN" / "audio_levels.md"
    log.write_text("# Audio levels\n\nGenerated by `tools/audio/synth.py` (procedural foley, D-029): each sound's peak / RMS (dBFS, audible part) after matching the RMS to the listed vanilla sounds' mean; the vanilla levels are measured from the game's own files, which are never copied. Mono 44.1 kHz Ogg Vorbis.\n\n| Sound | Length | Peak / RMS | Vanilla reference | Reference peak, RMS |\n|---|---|---|---|---|\n" + "\n".join(LOG) + "\n")
    print(f"{len(LOG)} sounds written")


if __name__ == "__main__":
    main()
