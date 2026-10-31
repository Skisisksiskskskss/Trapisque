# The Bellringer — a custom Jujutsu Shenanigans moveset

An original JJS character for the in-game **Skill Builder**: a temple-bell monk whose hits build **Tolls** that cash out as **Knells**. 4 base moves, 4 ultimates, an R special, custom M1s (uptilt/downslam), dash, awakening, a kill flourish, and nine machine-verified combo routes.

- Design: [`movesets/bellringer/DESIGN.md`](movesets/bellringer/DESIGN.md)
- Combos (verified frame by frame): [`movesets/bellringer/COMBOS.md`](movesets/bellringer/COMBOS.md)
- Frame data: [`movesets/bellringer/FRAMEDATA.md`](movesets/bellringer/FRAMEDATA.md)

## Import it

1. Open **`dist/bellringer_latest.txt`** (= v1.0) and copy the whole single line (it starts with `KLUv/`).
2. In JJS, open a **private server** with Build Mode, open your **Character Block → Configure** (the Skill Builder) and paste the code into **Import**.
3. Any base character works (every slot is custom). A fist-fighter base such as **Vessel** gives the best idle/run animations.

The code must be pasted complete; one missing character breaks it. The `.json` next to each code is the same moveset in readable form (for reading/diffing, not for import).

## Play it in 30 seconds

- Land hits to stack **Tolls** (max 3): M1 #2, M1 #4, any move that connects, the dash hit, the R pulse. Your palms glow per Toll; at 3 your whole body glows and a deep bell answers.
- At 3 Tolls, **2 Reverb Palm**, **4 Bell Toll** and **R** become **Knells** (much stronger versions).
- **Hold 1** for a charged ram, use **1 in the air** to dive. **Hold 3** for the multi-hit Sustained Note.
- BnB: `M1 M1 M1 → 2 → M1 M1 M1 M4 → 1`. Signature: `M1 M1 → 1 → M1 M1 M1 → 2 (Knell) → 3`.
- **G** (full bar): *Joya no Kane* — four new ultimates; R is always the Grand Knell.

## Milestones

Every milestone file is regenerated from the current source, so fixes found later are applied to all of them.

| Version | Contents | Code |
|---|---|---|
| v0.1 | M1 string (4 palms, uptilt, downslam, awakened variants), dash, **Toll system** | `dist/bellringer_v0.1.txt` |
| v0.2 | + **1 Striking Log** (lunge palm; hold = Charged Log, air = Falling Log) | `dist/bellringer_v0.2.txt` |
| v0.3 | + **2 ★ Reverb Palm** (palm + delayed echo; Knell = triple echo + launch) | `dist/bellringer_v0.3.txt` |
| v0.4 | + **3 Toll Wave** (ring-of-sound projectile that pulls; hold = Sustained Note multi-hit) | `dist/bellringer_v0.4.txt` |
| v0.5 | + **4 ★ Bell Toll** (launch + spectral bell slam; Knell = giant bell crater) — full base kit | `dist/bellringer_v0.5.txt` |
| v0.6 | + **R ★ Strike the Bell** (clap pulse; 3 Tolls = Grand Knell AoE) | `dist/bellringer_v0.6.txt` |
| v0.7 | + **Awakening: Joya no Kane** (bell-drop activation, 100 s aura; awakened M1s/R) | `dist/bellringer_v0.7.txt` |
| v0.8 | + **Ult 1 Hundredfold Strikes** (catch, 10 chiming palms, gong launcher) | `dist/bellringer_v0.8.txt` |
| v0.9 | + **Ult 2 Kanemaki** (trap the target in a bell, strike it thrice, shatter) | `dist/bellringer_v0.9.txt` |
| v0.10 | + **Ult 3 Sympathetic Cascade** (stomp, three expanding resonance rings) | `dist/bellringer_v0.10.txt` |
| v0.11 | + **Ult 4 The 108th Toll** (finisher cinematic) — every slot filled | `dist/bellringer_v0.11.txt` |
| **v1.0** | + awakened dash, **kill flourish** on big finishers, lockouts end with each move, verified combo guide | **`dist/bellringer_v1.0.txt`** |

## How it was built — and what is (not) verified

- The code format was reverse-engineered from 224 real game exports and cross-checked with the open-source `libjjs` library: [`docs/FORMAT.md`](docs/FORMAT.md).
- `tools/jjsforge` emits exactly the field names and value types the game exports, validates every build (branch references, loop bounds, value types, animation ids seen in real exports) and simulates timings; `tools/test_jjsforge.py` runs the checks.
- Animations are built-in JJS clips; impact timings come from where hundreds of creators place hitboxes on each clip. Sounds are the JJS developer's own uploads plus Roblox's licensed ProSoundEffects/APM bell & gong library — all checked as public and approved.
- **Not yet imported in-game.** Everything is structurally identical to working exports and the combos are verified against the timelines, but visual sizes (the spectral bell is built from Cylinder/Sphere effects) and exact feel should get one pass in a private server.

## Rebuild from source

```bash
pip install zstandard
```

```bash
python3 movesets/bellringer/bellringer.py
```

```bash
python3 tools/test_jjsforge.py
```
