#!/usr/bin/env python3
"""Synthesizes every Sift sound (WP-043). Deterministic: `python3 tools/audio/synth.py`.

Original audio only (hard rule 9.1; mission §7.5): every sample is computed below from sines,
filtered noise and envelopes. Vanilla sounds are only *measured* (peak and RMS) to match loudness;
none is copied. Mono 44.1 kHz Ogg Vorbis, so positional sounds attenuate. Assets are All Rights
Reserved (D-003). Needs numpy and soundfile.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44100
REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "src" / "main" / "resources" / "assets" / "thesift" / "sounds"
ASSETS = Path(os.path.expanduser("~/.gradle/caches/fabric-loom/assets"))


# ---------------------------------------------------------------- DSP helpers
def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


def env(n: int, attack: float, release: float, curve: float = 3.0) -> np.ndarray:
    """Attack ramp then exponential-ish release over the rest (both in seconds)."""
    e = np.ones(n)
    a = max(1, int(attack * SR))
    e[:a] = np.linspace(0, 1, a) ** 1.5
    r = max(1, min(n - a, int(release * SR)))
    e[n - r:] *= np.linspace(1, 0, r) ** curve
    return e


def decay(n: int, seconds: float) -> np.ndarray:
    return np.exp(-np.arange(n) / SR / max(1e-4, seconds))


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def bandpass(x: np.ndarray, lo: float, hi: float, soft: float = 0.25) -> np.ndarray:
    """FFT band-pass with soft (cosine) skirts, `soft` as a fraction of each edge frequency."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.ones_like(f)
    lo_a, hi_b = lo * (1 - soft), hi * (1 + soft)
    m[f < lo_a] = 0
    rise = (f >= lo_a) & (f < lo)
    m[rise] = 0.5 - 0.5 * np.cos(np.pi * (f[rise] - lo_a) / max(1e-6, lo - lo_a))
    m[f > hi_b] = 0
    fall = (f > hi) & (f <= hi_b)
    m[fall] = 0.5 + 0.5 * np.cos(np.pi * (f[fall] - hi) / max(1e-6, hi_b - hi))
    return np.fft.irfft(X * m, len(x))


def tone(freq, seconds: float, phase: float = 0.0) -> np.ndarray:
    """A sine; `freq` may be a scalar or an array (a glide), integrated for a clean phase."""
    n = int(seconds * SR)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,)) if np.ndim(freq) == 0 else np.asarray(freq)[:n]
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def bell(freq: float, seconds: float, brightness: float = 1.0, ratios=(1.0, 2.76, 5.40, 8.93)) -> np.ndarray:
    """An inharmonic struck bell/chime: partials decaying faster the higher they are."""
    n = int(seconds * SR)
    out = np.zeros(n)
    for k, r in enumerate(ratios):
        out += (brightness ** k) * (0.6 ** k) * tone(freq * r, seconds) * decay(n, seconds / (1 + 1.6 * k))
    return out * env(n, 0.002, 0.05)


def reverb(x: np.ndarray, seconds: float, wet: float, rng: np.random.Generator) -> np.ndarray:
    """Convolution with decaying, low-passed noise (a simple diffuse room)."""
    n = int(seconds * SR)
    ir = bandpass(noise(n, rng), 120, 6000) * decay(n, seconds / 4)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    m = len(x) + n
    y = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)
    out = np.zeros(m)
    out[:len(x)] = x * (1 - wet)
    return out + y * wet


def mix(n: int, *parts: tuple[np.ndarray, float]) -> np.ndarray:
    """Sums (signal, start-seconds) pairs into an n-sample buffer, trimming what overruns."""
    out = np.zeros(n)
    for x, start in parts:
        s = int(start * SR)
        m = min(len(x), n - s)
        if m > 0:
            out[s:s + m] += x[:m]
    return out


def pad_tail(x: np.ndarray, seconds: float = 0.02) -> np.ndarray:
    fade = int(seconds * SR)
    x = x.copy()
    x[-fade:] *= np.linspace(1, 0, fade)
    x[:min(64, len(x))] *= np.linspace(0, 1, min(64, len(x)))
    return x


def bubbles(seconds: float, count: int, f_lo: float, f_hi: float, rng: np.random.Generator, rising: bool = True) -> np.ndarray:
    """Short chirped sine 'pops' scattered in time: thick-liquid bubbles."""
    n = int(seconds * SR)
    out = np.zeros(n)
    for _ in range(count):
        start = rng.integers(0, max(1, n - int(0.08 * SR)))
        dur = rng.uniform(0.025, 0.07)
        f0 = rng.uniform(f_lo, f_hi)
        glide = np.linspace(f0, f0 * (1.8 if rising else 0.6), int(dur * SR))
        pop = tone(glide, dur) * decay(len(glide), dur / 3) * rng.uniform(0.4, 1.0)
        pop *= env(len(pop), 0.003, 0.012, 1.0)  # no clicks at either end
        out[start:start + len(pop)] += pop
    return out


# ---------------------------------------------------------------- loudness
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


def write(name: str, x: np.ndarray, refs: list[str]) -> None:
    """Matches RMS to the mean of the vanilla references (peak capped at -1 dBFS), then writes."""
    x = pad_tail(np.asarray(x, dtype=float))
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


# ---------------------------------------------------------------- the sounds
def entry(rng: np.random.Generator) -> None:
    for i in range(1, 4):  # the offering stream: a soft rising breath with a shimmer
        d = 0.38
        n = int(d * SR)
        breath = bandpass(noise(n, rng), 700 + 150 * i, 3200) * np.sin(np.linspace(0, np.pi, n)) ** 2
        shimmer = 0.25 * tone(np.linspace(1100 + 80 * i, 1500 + 80 * i, n), d) * np.sin(np.linspace(0, np.pi, n)) ** 3
        write(f"entry/offer{i}", breath + shimmer, ["block/respawn_anchor/charge1.ogg", "block/respawn_anchor/charge2.ogg"])
    # Waking: a low swell under a chord of chimes.
    d = 3.0
    n = int(d * SR)
    drone = sum(a * tone(f, d) for f, a in ((55, 1.0), (110, 0.6), (165, 0.3))) * env(n, 0.8, 1.6, 2.0)
    chord = mix(n, *((bell(f, d - o, 0.9), o) for f, o in ((440, 0.4), (523.3, 0.55), (659.3, 0.7), (987.8, 0.9))))
    write("entry/wake", reverb(0.7 * drone + 0.5 * chord, 1.8, 0.35, rng), ["block/beacon/activate.ogg"])
    # Opening: partials gliding up an octave over a widening noise wash.
    d = 2.2
    n = int(d * SR)
    glide = sum(tone(np.linspace(f, 2 * f, n), d) * (0.7 ** k) for k, f in enumerate((220, 330, 440, 660)))
    wash = bandpass(noise(n, rng), 500, 2500) * 0.12
    write("entry/open", reverb((glide + wash) * env(n, 0.6, 0.9), 1.5, 0.3, rng), ["block/end_portal/endportal.ogg", "block/conduit/activate.ogg"])
    for i in range(1, 3):  # the awake frame's hum
        d = 2.5
        n = int(d * SR)
        f = 73.4 * (1.0 if i == 1 else 1.122)
        hum = (tone(f, d) + 0.5 * tone(f * 1.006, d) + 0.25 * tone(2 * f, d)) * env(n, 0.7, 1.2, 2.0)
        write(f"entry/hum{i}", hum, ["block/beacon/ambient.ogg"])
    for i in range(1, 4):  # the membrane: a few glassy chimes from a pentatonic set
        d = 1.6
        notes = rng.choice([1046.5, 1174.7, 1318.5, 1568.0, 1760.0], size=3, replace=False)
        x = mix(int(d * SR), *((bell(f, d - o, 0.7, (1.0, 2.0, 3.01)), o) for f, o in zip(notes, (0.0, 0.18, 0.4))))
        write(f"entry/membrane{i}", reverb(x, 1.4, 0.4, rng), ["block/amethyst/shimmer.ogg", "portal/portal.ogg"])
    # Crossing: a swirling rise with a soft landing chime.
    d = 3.2
    n = int(d * SR)
    swirl = bandpass(noise(n, rng), 300, 2500) * (0.5 + 0.5 * np.sin(np.linspace(0, 18 * np.pi, n))) * env(n, 1.4, 1.2)
    rise = tone(np.geomspace(180, 720, n), d) * env(n, 1.6, 0.9) * 0.6
    land = mix(n, (bell(784.0, 1.2, 0.8), d - 1.2))
    write("entry/travel", reverb(swirl + rise + 0.6 * land, 1.6, 0.3, rng), ["portal/travel.ogg"])


def tides(rng: np.random.Generator) -> None:
    d = 4.0
    n = int(d * SR)
    thrive = mix(n, *((bell(f, d - o, 1.0), o) for f, o in ((523.3, 0.0), (659.3, 0.12), (784.0, 0.24), (1046.5, 0.5))))
    write("tide/thrive", reverb(thrive, 2.2, 0.45, rng), ["block/bell/bell_use01.ogg", "block/bell/resonate.ogg"])
    swell = (bandpass(noise(n, rng), 90, 600) * 0.6 + tone(np.linspace(110, 98, n), d) * 0.8) * env(n, 1.6, 1.8, 2.0)
    write("tide/flow", reverb(swell, 2.0, 0.4, rng), ["block/bell/resonate.ogg"])
    d = 5.5
    # A deep gong, with a higher strike so small speakers still carry it.
    gong = mix(int(d * SR), (bell(65.4, d, 1.1, (1.0, 1.48, 2.11, 2.73, 3.37)), 0.0), (0.4 * bell(98.0, d, 0.8), 0.0),
               (0.35 * bell(261.6, d * 0.7, 0.7), 0.02))
    write("tide/endure", reverb(gong, 2.8, 0.45, rng), ["block/bell/bell_use01.ogg", "block/bell/resonate.ogg"])
    for i in range(1, 4):  # a basin filling: bubbles rising through thick ichor
        d = 1.2
        n = int(d * SR)
        x = bubbles(d, 14, 180, 520, rng) + 0.5 * bandpass(noise(n, rng), 60, 300) * env(n, 0.2, 0.6)
        write(f"tide/basin_fill{i}", x, ["block/bubble_column/upwards_ambient1.ogg", "block/bubble_column/upwards_ambient2.ogg"])
    for i in range(1, 3):  # draining: a falling gurgle
        d = 1.4
        n = int(d * SR)
        x = bubbles(d, 10, 220, 600, rng, rising=False) + 0.6 * bandpass(noise(n, rng), 50, 260) * env(n, 0.1, 1.0)
        write(f"tide/basin_drain{i}", x, ["block/bubble_column/whirlpool_ambient1.ogg", "block/bubble_column/whirlpool_ambient2.ogg"])


def ichor(rng: np.random.Generator) -> None:
    for i in range(1, 5):  # wading: a thick slosh with one bubble
        d = 0.35
        n = int(d * SR)
        slosh = bandpass(noise(n, rng), 150 + 30 * i, 900) * np.sin(np.linspace(0, np.pi, n)) ** 1.5
        write(f"ichor/wade{i}", slosh + 0.4 * bubbles(d, 1, 200, 350, rng), ["liquid/swim1.ogg", "liquid/swim2.ogg"])
    for i in range(1, 4):  # ambient: a heavy pop and a little fizz
        d = 0.6
        n = int(d * SR)
        pop = bubbles(0.3, 1, 140, 220, rng)
        fizz = bandpass(noise(n, rng), 2500, 7000) * decay(n, 0.08) * 0.06
        write(f"ichor/ambient{i}", mix(n, (pop, 0.0)) + fizz, ["liquid/lavapop.ogg"])
    for kind in ("fill", "empty"):
        for i in range(1, 3):
            d = 0.6
            n = int(d * SR)
            x = bandpass(noise(n, rng), 120, 1100) * env(n, 0.04, 0.4) + 0.5 * bubbles(d, 4, 160, 400, rng, rising=(kind == "fill"))
            write(f"ichor/bucket_{kind}{i}", x, [f"item/bucket/{kind}_lava1.ogg", f"item/bucket/{kind}_lava2.ogg"])
    d = 1.2
    n = int(d * SR)
    hiss = bandpass(noise(n, rng), 3000, 9000) * decay(n, 0.35) + 0.4 * tone(np.linspace(900, 300, n), d) * decay(n, 0.4)
    write("ichor/evaporate", hiss, ["random/fizz.ogg"])


def meadow(rng: np.random.Generator) -> None:
    # The loop: wind through flute holes. Built twice as long, then cross-faded so it loops seamlessly.
    d = 24.0
    n = int(d * SR)
    lfo = 0.55 + 0.45 * np.sin(np.linspace(0, 2 * np.pi * 3, n) + 1.0) * np.sin(np.linspace(0, 2 * np.pi * 1, n))
    wind = bandpass(noise(n, rng), 180, 1300) * lfo
    whistles = np.zeros(n)
    for _ in range(9):
        f = rng.choice([587.3, 659.3, 784.0, 880.0, 1046.5])
        dur = rng.uniform(1.5, 3.5)
        start = int(rng.uniform(0, d - dur) * SR)
        m = int(dur * SR)
        breath = bandpass(noise(m, rng), f * 0.9, f * 1.1, 0.05)
        vib = tone(f * (1 + 0.004 * np.sin(np.linspace(0, 2 * np.pi * 5 * dur, m))), dur)
        whistles[start:start + m] += (0.5 * breath / (np.std(breath) + 1e-9) * 0.2 + 0.25 * vib) * np.sin(np.linspace(0, np.pi, m)) ** 2
    x = wind / (np.std(wind) + 1e-9) * 0.25 + whistles
    half = n // 2
    fade = np.linspace(0, 1, half)
    looped = x[:half] * fade + x[half:] * (1 - fade)  # the tail flows into the head
    write("ambient/meadow_loop", looped, ["ambient/nether/basalt_deltas/ambience.ogg"])
    for i in range(1, 5):  # mood: a far flute phrase in heavy reverb
        d = 5.0
        n = int(d * SR)
        phrase = np.zeros(n)
        start = 0.2
        for f in rng.choice([392.0, 440.0, 523.3, 587.3, 659.3], size=3):
            dur = rng.uniform(0.6, 1.1)
            m = int(dur * SR)
            s = int(start * SR)
            note = tone(f * (1 + 0.005 * np.sin(np.linspace(0, 2 * np.pi * 5 * dur, m))), dur) + 0.3 * bandpass(noise(m, rng), f * 0.9, f * 1.1, 0.05) / 4
            phrase[s:s + m] += note * np.sin(np.linspace(0, np.pi, m)) ** 1.5
            start += dur * 0.8
        write(f"ambient/meadow_mood{i}", reverb(phrase, 3.0, 0.65, rng), ["ambient/cave/cave1.ogg", "ambient/cave/cave2.ogg"])


def squeak(contour: list[float], seconds: float, brightness: float = 0.35, vibrato: float = 0.0) -> np.ndarray:
    """A small voice: a gliding pitch through the contour's points, two soft overtones, a quick attack."""
    n = int(seconds * SR)
    f = np.interp(np.linspace(0, len(contour) - 1, n), np.arange(len(contour)), contour)
    if vibrato:
        f = f * (1 + vibrato * np.sin(np.linspace(0, 2 * np.pi * 6 * seconds, n)) * np.linspace(0, 1, n))
    x = tone(f, seconds) + brightness * tone(2 * f, seconds) + brightness ** 2 * tone(3 * f, seconds)
    return x * env(n, 0.008, seconds * 0.45)


def blub(rng: np.random.Generator) -> None:
    """The Blub (WP-050): a small, round voice. The echo's note is F#5, so note-block pitches land in tune."""
    # Soft but audible: a chicken's cluck and an armadillo's mutter (an axolotl out of water is near silent).
    chirpy = ["mob/chicken/say1.ogg", "mob/chicken/say2.ogg", "mob/armadillo/ambient1.ogg", "mob/armadillo/ambient2.ogg"]
    for i in range(1, 5):  # ambient: one soft squeak, each with its own little contour
        base = rng.uniform(950, 1250)
        d = rng.uniform(0.14, 0.22)
        x = squeak([base * 0.9, base * 1.15, base * rng.uniform(0.85, 1.05)], d)
        write(f"blub/ambient{i}", x + 0.02 * bandpass(noise(len(x), rng), 2000, 6000) * env(len(x), 0.005, d * 0.3), chirpy)
    for i in range(1, 3):  # listen: a curious rising chirp
        d = 0.26
        write(f"blub/listen{i}", squeak([720 + 40 * i, 900, 1500 + 80 * i], d, 0.3), chirpy)
    for i in range(1, 3):  # happy: two bright squeaks, the second higher
        a = squeak([1000, 1350, 1250], 0.12, 0.4)
        b = squeak([1200, 1650 + 60 * i, 1500], 0.15, 0.4)
        n = int(0.34 * SR)
        write(f"blub/happy{i}", mix(n, (a, 0.0), (b, 0.15)), chirpy)
    # sing: the echo. A clean F#5 with a little scoop and a late vibrato; pitch is set per note in code.
    f0 = 739.99
    write("blub/sing", squeak([f0 * 0.944, f0, f0, f0, f0, f0, f0, f0], 0.5, 0.22, vibrato=0.006), ["note/harp.ogg"])
    for i in range(1, 3):  # restless: quick chirps, back and forth
        n = int(0.5 * SR)
        parts = []
        for k in range(4):
            hi = 1300 + 120 * ((k + i) % 2)
            parts.append((squeak([hi, hi * 1.1, hi * 0.95], 0.065, 0.35), 0.11 * k + 0.01 * i))
        write(f"blub/restless{i}", mix(n, *parts), chirpy)
    for i in range(1, 3):  # curl: a sleepy hum, low and breathy
        d = 1.1
        n = int(d * SR)
        f = 330 + 25 * i
        hum = squeak([f, f * 1.02, f * 0.97, f * 0.94], d, 0.18, vibrato=0.01)
        breath = bandpass(noise(n, rng), 300, 1200) * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.08
        write(f"blub/curl{i}", hum * np.sin(np.linspace(0, np.pi, n)) + breath, ["mob/cat/purr2.ogg", "mob/armadillo/ambient1.ogg"])
    for i in range(1, 3):  # splash: a soft bloop and a little water
        d = 0.35
        n = int(d * SR)
        bloop = tone(np.linspace(520 + 40 * i, 240, int(0.09 * SR)), 0.09) * env(int(0.09 * SR), 0.004, 0.06)
        water = bandpass(noise(n, rng), 500, 3500) * env(n, 0.01, 0.25) * 0.25
        write(f"blub/splash{i}", mix(n, (bloop, 0.0), (water, 0.02)) + 0.3 * bubbles(d, 2, 300, 600, rng), ["mob/slime/small1.ogg", "mob/slime/small2.ogg"])
    for i in range(1, 3):  # topple: a bouncy thud, a boing, a surprised squeak
        d = 0.6
        n = int(d * SR)
        m = int(0.18 * SR)
        thud = tone(np.linspace(140, 60, m), 0.18) * decay(m, 0.06)
        k = int(0.25 * SR)
        boing = tone(260 * (1 + 0.12 * np.sin(np.linspace(0, 2 * np.pi * 7, k)) * np.linspace(1, 0, k)), 0.25) * decay(k, 0.1)
        yelp = squeak([1100, 1500 + 100 * i, 1300], 0.12, 0.35)
        write(f"blub/topple{i}", mix(n, (thud, 0.0), (boing, 0.04), (yelp * 0.6, 0.3)), ["mob/slime/small1.ogg", "mob/slime/small3.ogg"])
    for i in range(1, 3):  # hurt: a sharp, bright squeak
        write(f"blub/hurt{i}", squeak([1350 + 50 * i, 1850, 1150], 0.16, 0.5), ["mob/axolotl/hurt1.ogg", "mob/axolotl/hurt2.ogg"])
    d = 0.75  # death: a squeak that deflates, more breath than voice by the end
    n = int(d * SR)
    voice = squeak([1250, 1350, 900, 520, 320], d, 0.3) * np.linspace(1, 0.4, n)
    air = bandpass(noise(n, rng), 800, 4000) * np.linspace(0, 1, n) ** 2 * env(n, 0.01, 0.2) * 0.25
    write("blub/death", voice + air, ["mob/axolotl/death1.ogg", "mob/axolotl/death2.ogg"])
    for i in range(1, 4):  # hop: a springy little boing with a pat on landing
        d = 0.3
        n = int(d * SR)
        k = int(0.16 * SR)
        boing = tone(np.linspace(380 + 30 * i, 620 + 40 * i, k), 0.16) * env(k, 0.005, 0.1)
        m = int(0.06 * SR)
        pat = bandpass(noise(m, rng), 150, 900) * decay(m, 0.015)
        write(f"blub/hop{i}", mix(n, (boing, 0.0), (pat * 0.6, 0.2)), ["mob/rabbit/hop1.ogg", "mob/rabbit/hop2.ogg", "mob/slime/small1.ogg"])
    for i in range(1, 5):  # step: a soft pat
        d = 0.09
        n = int(d * SR)
        pat = bandpass(noise(n, rng), 150, 900 + 100 * i) * decay(n, 0.018) + 0.6 * tone(150 + 10 * i, d) * decay(n, 0.02)
        write(f"blub/step{i}", pat, ["mob/frog/step1.ogg", "mob/frog/step2.ogg"])


def notice(rng: np.random.Generator) -> None:
    """The frame notices you (entry_path.md stage 2): a breath drawn in toward it, a faint high shimmer."""
    for i in range(1, 3):
        d = 1.3
        n = int(d * SR)
        x = np.linspace(0, 1, n)
        # A low band fading out under a higher one fading in: the breath slides upward, as if drawn.
        low = bandpass(noise(n, rng), 280, 650)
        high = bandpass(noise(n, rng), 700 + 60 * i, 1600 + 80 * i)
        breath = (low / (np.std(low) + 1e-9) * (1 - x) + high / (np.std(high) + 1e-9) * x) * np.sin(np.pi * x) ** 2 * 0.2
        shimmer = 0.08 * tone(np.linspace(1480 + 40 * i, 1760 + 40 * i, n), d) * np.sin(np.pi * x) ** 4
        write(f"entry/notice{i}", reverb(breath + shimmer, 1.2, 0.35, rng), ["ambient/cave/cave1.ogg", "ambient/cave/cave2.ogg"])

def main() -> None:
    rng = np.random.default_rng(20261001)
    entry(rng)
    tides(rng)
    ichor(rng)
    meadow(rng)
    blub(rng)
    notice(np.random.default_rng(20261002))  # its own seed: adding it leaves every earlier sound unchanged
    log = REPO / "docs" / "DESIGN" / "audio_levels.md"
    log.write_text("# Audio levels (WP-043)\n\nGenerated by `tools/audio/synth.py`: each sound's peak / RMS (dBFS, audible part) after matching the RMS to the listed vanilla sounds' mean; the vanilla levels are measured from the game's own files, which are never copied. Mono 44.1 kHz Ogg Vorbis.\n\n| Sound | Length | Peak / RMS | Vanilla reference | Reference peak, RMS |\n|---|---|---|---|---|\n" + "\n".join(LOG) + "\n")
    print(f"{len(LOG)} sounds written")


if __name__ == "__main__":
    main()
