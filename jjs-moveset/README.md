# The Bellringer — a custom Jujutsu Shenanigans moveset

An original JJS character for the in-game **Skill Builder**: a temple-bell monk whose hits build **Tolls** that cash out as **Knells**. Full design: [`movesets/bellringer/DESIGN.md`](movesets/bellringer/DESIGN.md) · timings: [`movesets/bellringer/FRAMEDATA.md`](movesets/bellringer/FRAMEDATA.md).

## Import it

1. Open **`dist/bellringer_latest.txt`** and copy the whole line (it starts with `KLUv/`). Every milestone also has its own file, e.g. `dist/bellringer_v0.1.txt`.
2. In JJS, open a **private server** with Build Mode, open your **Character Block → Configure** (the Skill Builder) and paste the code into **Import**.
3. Any base character works (every slot is custom). A fist-fighter base such as **Vessel** gives the best idle/run animations.

The code must be pasted complete; one missing character breaks it. The `.json` files next to each code are the same moveset in readable form (for reading/diffing, not for import).

## Milestones

| Version | Contents | Code |
|---|---|---|
| v0.1 | M1 string (4 palms, uptilt, downslam, awakened variants), dash, **Toll system** | `dist/bellringer_v0.1.txt` |
| v0.2 | + **1 Striking Log** (lunge palm; hold = Charged Log, air = Falling Log) | `dist/bellringer_v0.2.txt` |
| v0.3 | + **2 ★ Reverb Palm** (palm + delayed echo; Knell = triple echo + launch) | `dist/bellringer_v0.3.txt` |
| v0.4 | + **3 Toll Wave** (ring-of-sound projectile that pulls; hold = Sustained Note multi-hit) | `dist/bellringer_v0.4.txt` |
| v0.5 | + **4 ★ Bell Toll** (launch + spectral bell slam; Knell = giant bell crater) — full base kit | `dist/bellringer_v0.5.txt` |
| v0.6 | + **R ★ Strike the Bell** (clap pulse; 3 Tolls = Grand Knell AoE) | `dist/bellringer_v0.6.txt` |
| v0.7 | + **Awakening: Joya no Kane** (bell-drop activation, 100 s aura; awakened M1s/R). Ultimate slots fill in from v0.8 | `dist/bellringer_v0.7.txt` |
| v0.8 | + **Ult 1 Hundredfold Strikes** (catch, 10 chiming palms, gong launcher) | `dist/bellringer_v0.8.txt` |
| v0.9 | + **Ult 2 Kanemaki** (trap the target in a bell, strike it thrice, shatter) | `dist/bellringer_v0.9.txt` |

## Rebuild from source

```bash
pip install zstandard
```

```bash
python3 movesets/bellringer/bellringer.py
```

`tools/jjsforge` is the small toolchain written for this: node constructors that emit exactly the field names/types the game exports, a validator (branch references, loop bounds, value types, verified animation ids) and a timing analyzer that produces the frame-data tables. The file format itself is documented in [`docs/FORMAT.md`](docs/FORMAT.md).
