#!/usr/bin/env python3
"""Synthesises Splotch's original sound effects (no samples, no third-party audio).

  python3 tools/make_sfx.py assets/sfx

Writes one .ogg per sound name in shared/SoundIds.luau. Needs numpy and ffmpeg.
Every sound is built from noise, sine sweeps and envelopes, so the pack is
ours to use and change freely. Re-running produces identical files.
"""

import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 44100
rng = np.random.default_rng(7)


# Building blocks ---------------------------------------------------------------


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def env(seconds, attack=0.003, decay=None, curve=4.0):
    """Fast attack, exponential-ish decay to silence at the end."""
    t = t_axis(seconds)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = (1 - np.clip((t - attack) / max(seconds - attack, 1e-4), 0, 1)) ** curve
    return a * d


def noise(seconds):
    return rng.uniform(-1, 1, int(seconds * RATE))


def lowpass(signal, cutoff):
    """One-pole lowpass; cutoff may be a number or a per-sample array (Hz)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), signal.shape)
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.empty_like(signal)
    y = 0.0
    for i, (x, a) in enumerate(zip(signal, alpha)):
        y += a * (x - y)
        out[i] = y
    return out


def highpass(signal, cutoff):
    return signal - lowpass(signal, cutoff)


def band(signal, low, high):
    return lowpass(highpass(signal, low), high)


def sweep(seconds, f0, f1, shape="exp"):
    """Sine whose frequency glides from f0 to f1."""
    t = t_axis(seconds)
    if shape == "exp":
        freq = f0 * (f1 / f0) ** (t / seconds)
    else:
        freq = f0 + (f1 - f0) * (t / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase)


def tone(seconds, freq):
    return np.sin(2 * np.pi * freq * t_axis(seconds))


def thump(seconds, f0=160, f1=45):
    """Kick-drum style body: a sine that drops in pitch."""
    return sweep(seconds, f0, f1) * env(seconds, 0.002, curve=3)


def pad(signal, seconds):
    out = np.zeros(int(seconds * RATE))
    out[: len(signal)] = signal[: len(out)]
    return out


def mix(*layers):
    length = max(len(layer) for layer in layers)
    out = np.zeros(length)
    for layer in layers:
        out[: len(layer)] += layer
    return out


def at(signal, offset):
    return np.concatenate([np.zeros(int(offset * RATE)), signal])


def saturate(signal, drive=2.0):
    return np.tanh(signal * drive) / np.tanh(drive)


def finish(signal, peak=0.89):
    signal = signal - np.mean(signal)
    fade = int(0.004 * RATE)
    signal[:fade] *= np.linspace(0, 1, fade)
    signal[-fade:] *= np.linspace(1, 0, fade)
    top = np.max(np.abs(signal))
    return signal * (peak / top) if top > 0 else signal


def bloop(seconds, f0, f1):
    return sweep(seconds, f0, f1) * env(seconds, 0.004, curve=2)


# Sounds ------------------------------------------------------------------------------


def shoot():
    body = band(noise(0.11), 900, 4500) * env(0.11, 0.002, curve=3)
    pop = bloop(0.07, 900, 380) * 0.6
    return mix(body, pop)


def splat():
    wet = lowpass(noise(0.22), np.linspace(5000, 600, int(0.22 * RATE))) * env(0.22, 0.002, curve=3)
    drops = mix(*(at(bloop(0.05, f, f * 1.6) * 0.35, o) for f, o in ((420, 0.02), (610, 0.06), (520, 0.1))))
    return mix(wet, drops)


def hit():
    smack = band(noise(0.06), 1200, 5000) * env(0.06, 0.001, curve=4)
    return mix(thump(0.16, 190, 60) * 0.9, smack * 0.8, splat()[: int(0.1 * RATE)] * 0.35)


def heavy_hit():
    body = saturate(thump(0.38, 140, 34), 2.5)
    crunch = band(noise(0.18), 300, 3500) * env(0.18, 0.001, curve=3)
    return mix(body, crunch * 0.8, at(lowpass(noise(0.4), 900) * env(0.4, 0.01, curve=3) * 0.3, 0.02))


def hit_confirm():
    ping = (tone(0.09, 1850) + 0.5 * tone(0.09, 2780)) * env(0.09, 0.001, curve=5)
    click = highpass(noise(0.012), 3000) * env(0.012, 0.0005)
    return mix(ping, click * 0.5)


def hurt():
    body = thump(0.22, 120, 50)
    muffled = lowpass(noise(0.2), 1200) * env(0.2, 0.002, curve=3)
    return mix(body, muffled * 0.6)


def blocked():
    partials = [(523, 1.0), (1187, 0.6), (1840, 0.45), (2630, 0.3)]
    ring = sum(tone(0.35, f) * a for f, a in partials) * env(0.35, 0.001, curve=6)
    click = band(noise(0.02), 2000, 8000) * env(0.02, 0.0005)
    return mix(ring * 0.7, click, thump(0.1, 200, 90) * 0.4)


def guard_break():
    shards = mix(*(at(band(noise(0.08), 2500, 9000) * env(0.08, 0.001, curve=5) * g, o) for o, g in ((0, 1), (0.05, 0.7), (0.11, 0.5), (0.18, 0.35))))
    return mix(saturate(thump(0.4, 110, 30), 2), shards, sweep(0.5, 900, 120) * env(0.5, 0.01, curve=2) * 0.25)


def ko():
    drop = sweep(0.7, 420, 70) * env(0.7, 0.01, curve=1.6)
    splash = lowpass(noise(0.6), np.linspace(6000, 400, int(0.6 * RATE))) * env(0.6, 0.002, curve=2.5)
    return mix(saturate(thump(0.45, 130, 30), 2), splash * 0.8, drop * 0.5)


def dash():
    n = int(0.3 * RATE)
    centre = np.concatenate([np.linspace(700, 3800, n // 2), np.linspace(3800, 1200, n - n // 2)])
    whoosh = lowpass(highpass(noise(0.3), 400), centre) * np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return whoosh


def dive():
    n = int(0.35 * RATE)
    slosh = lowpass(noise(0.35), np.linspace(4000, 300, n)) * env(0.35, 0.01, curve=2)
    return mix(slosh, bloop(0.25, 600, 160) * 0.6)


def surface():
    return mix(bloop(0.12, 260, 900) * 0.8, lowpass(noise(0.12), 3000) * env(0.12, 0.002, curve=3) * 0.5)


def leap():
    rise = sweep(0.3, 220, 720) * env(0.3, 0.005, curve=2) * 0.6
    air = dash()[: int(0.25 * RATE)] * 0.6
    return mix(rise, air, surface() * 0.6)


def burst():
    boom = saturate(thump(0.7, 120, 28), 3)
    blast = lowpass(noise(0.9), np.linspace(7000, 300, int(0.9 * RATE))) * env(0.9, 0.002, curve=2.2)
    crackle = mix(*(at(band(noise(0.03), 1500, 7000) * env(0.03, 0.001) * 0.5, o) for o in rng.uniform(0.05, 0.4, 9)))
    return mix(boom, blast * 0.9, crackle)


def slam():
    sub = saturate(thump(0.8, 90, 24), 3)
    crunch = band(noise(0.35), 150, 2500) * env(0.35, 0.001, curve=2.5)
    rumble = lowpass(noise(1.0), 220) * env(1.0, 0.02, curve=1.5) * 2.5
    return mix(sub, crunch, rumble)


def skill():
    n = int(0.35 * RATE)
    swell = lowpass(noise(0.35), np.linspace(500, 5000, n)) * np.linspace(0, 1, n) ** 2
    return mix(swell * 0.7, at(bloop(0.15, 300, 700) * 0.7, 0.2))


def trap():
    snap = highpass(noise(0.015), 2500) * env(0.015, 0.0005)
    ring = (tone(0.25, 1320) + 0.5 * tone(0.25, 1980)) * env(0.25, 0.001, curve=5)
    goo = bloop(0.2, 180, 420)
    return mix(snap, ring * 0.5, at(goo * 0.7, 0.03))


def hook():
    zip_ = sweep(0.25, 1600, 280) * env(0.25, 0.002, curve=2)
    air = band(noise(0.25), 1500, 6000) * env(0.25, 0.002, curve=2)
    return mix(zip_ * 0.6, air * 0.5, at(hit_confirm() * 0.3, 0.2))


def bounce():
    t = t_axis(0.5)
    freq = 170 + 300 * (1 - np.exp(-t * 9)) + 18 * np.sin(2 * np.pi * 14 * t)
    boing = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * env(0.5, 0.003, curve=2)
    return mix(boing, thump(0.12, 160, 70) * 0.5)


def ui_click():
    return mix(tone(0.03, 1250) * env(0.03, 0.001, curve=4), highpass(noise(0.008), 4000) * env(0.008) * 0.3)


def warning():
    out = []
    for freq in (330, 262, 330, 262):
        horn = (tone(0.28, freq) + 0.4 * tone(0.28, freq * 2) + 0.2 * tone(0.28, freq * 3)) * env(0.28, 0.02, curve=0.8)
        out.append(horn)
        out.append(np.zeros(int(0.04 * RATE)))
    return lowpass(np.concatenate(out), 2500)


def storm():
    seconds = 6.0
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / seconds) ** 2
    wind = lowpass(noise(seconds), 300 + 500 * gust) * gust
    rain = highpass(noise(seconds), 2500) * 0.25
    loop = wind * 1.6 + rain
    # Crossfade the end into the start so the loop is seamless.
    fade = int(0.5 * RATE)
    ramp = np.linspace(0, 1, fade)
    loop[:fade] = loop[:fade] * ramp + loop[-fade:] * (1 - ramp)
    return loop[:-fade]


SOUNDS = {
    "Shoot": shoot,
    "Splat": splat,
    "Hit": hit,
    "HeavyHit": heavy_hit,
    "HitConfirm": hit_confirm,
    "Hurt": hurt,
    "Blocked": blocked,
    "GuardBreak": guard_break,
    "KO": ko,
    "Dash": dash,
    "Dive": dive,
    "Surface": surface,
    "Leap": leap,
    "Burst": burst,
    "Slam": slam,
    "Skill": skill,
    "Trap": trap,
    "Hook": hook,
    "Bounce": bounce,
    "UiClick": ui_click,
    "Warning": warning,
    "Storm": storm,
}


def write_ogg(signal, path, loop=False):
    data = finish(signal, 0.7 if loop else 0.89)
    pcm = (data * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "5", str(path)],
            check=True,
        )


def main():
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/sfx")
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        signal = make()
        write_ogg(signal, out_dir / f"{name}.ogg", loop=(name == "Storm"))
        print(f"{name:11s} {len(signal) / RATE:5.2f}s")


if __name__ == "__main__":
    main()
