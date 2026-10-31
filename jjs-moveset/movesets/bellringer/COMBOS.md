# Combos — The Bellringer v1.1

Every route below is simulated from the real timelines by `jjsforge.analyze.check_combo` on each build (the build fails if one breaks). Each step starts the moment the previous one recovers. *True combo* = the first hit lands while the target is still in hitstun (spare time shown); *OTG* = it lands on a ragdolled target with a hitbox that can hit ragdolls. Assumes the target is in range (lunges and pulls handle most spacing) and no burst/evasive is used.

## First Toll — BnB  ·  _Base_

Any Tolls. Ends with 2 Tolls.

**M1 #1 → M1 #2 → M1 #3 → 2 Reverb Palm (echo) → M1 #1 → M1 #2 → M1 #3 → M4 → 1 Striking Log** — 38 dmg — ✅ verified

| Step | Starts | First hit | Connects as | Dmg |
|---|---|---|---|---|
| M1 #1 | 0.00s | 0.20s | starter | 3 |
| M1 #2 | 0.35s | 0.55s | true combo (+0.40s spare) | 3 |
| M1 #3 | 0.70s | 0.90s | true combo (+0.40s spare) | 3.5 |
| 2 Reverb Palm (echo) | 1.05s | 1.35s | true combo (+0.30s spare) | 9 |
| M1 #1 | 2.05s | 2.25s | true combo (+0.60s spare) | 3 |
| M1 #2 | 2.40s | 2.60s | true combo (+0.40s spare) | 3 |
| M1 #3 | 2.75s | 2.95s | true combo (+0.40s spare) | 3.5 |
| M4 | 3.10s | 3.30s | true combo (+0.40s spare) | 4 |
| 1 Striking Log | 3.50s | 3.76s | OTG (hits ragdoll) | 6 |

## Rising Knell  ·  _Base_

Launcher route; the wave picks them up off the floor.

**M1 #1 → M1 #2 → M1 #3 → 4 Bell Toll → 3 Toll Wave (OTG)** — 23.5 dmg — ✅ verified

| Step | Starts | First hit | Connects as | Dmg |
|---|---|---|---|---|
| M1 #1 | 0.00s | 0.20s | starter | 3 |
| M1 #2 | 0.35s | 0.55s | true combo (+0.40s spare) | 3 |
| M1 #3 | 0.70s | 0.90s | true combo (+0.40s spare) | 3.5 |
| 4 Bell Toll | 1.05s | 1.27s | true combo (+0.38s spare) | 10 |
| 3 Toll Wave (OTG) | 1.92s | 2.23s | OTG (hits ragdoll) | 4 |

## Bell Drop  ·  _Base_

Uptilt into an air spike.

**M1 #1 → M1 #2 → M1 #3 → M4 ↑ uptilt → jump → 1 Falling Log → 3 Toll Wave (OTG)** — 23.5 dmg — ✅ verified

| Step | Starts | First hit | Connects as | Dmg |
|---|---|---|---|---|
| M1 #1 | 0.00s | 0.20s | starter | 3 |
| M1 #2 | 0.35s | 0.55s | true combo (+0.40s spare) | 3 |
| M1 #3 | 0.70s | 0.90s | true combo (+0.40s spare) | 3.5 |
| M4 ↑ uptilt | 1.05s | 1.25s | true combo (+0.40s spare) | 4 |
| jump → 1 Falling Log | 1.70s | 1.76s | OTG (hits ragdoll) | 6 |
| 3 Toll Wave (OTG) | 2.06s | 2.37s | OTG (hits ragdoll) | 4 |

## Clap Chain  ·  _Base_

R pulse resets the M1 string.

**M1 #1 → M1 #2 → M1 #3 → R Strike the Bell → M1 #1 → M1 #2 → M1 #3 → 2 Reverb Palm (echo)** — 30 dmg — ✅ verified

| Step | Starts | First hit | Connects as | Dmg |
|---|---|---|---|---|
| M1 #1 | 0.00s | 0.20s | starter | 3 |
| M1 #2 | 0.35s | 0.55s | true combo (+0.40s spare) | 3 |
| M1 #3 | 0.70s | 0.90s | true combo (+0.40s spare) | 3.5 |
| R Strike the Bell | 1.05s | 1.20s | true combo (+0.45s spare) | 2 |
| M1 #1 | 1.50s | 1.70s | true combo (+0.30s spare) | 3 |
| M1 #2 | 1.85s | 2.05s | true combo (+0.40s spare) | 3 |
| M1 #3 | 2.20s | 2.40s | true combo (+0.40s spare) | 3.5 |
| 2 Reverb Palm (echo) | 2.55s | 2.85s | true combo (+0.30s spare) | 9 |

## Grand Knell  ·  _Base, 3 Tolls_

Spend the Knell on R, chase the launch.

**M1 #1 → M1 #2 → M1 #3 → R ★ Grand Knell → jump → 1 Falling Log → 3 Toll Wave (OTG)** — 31.5 dmg — ✅ verified

| Step | Starts | First hit | Connects as | Dmg |
|---|---|---|---|---|
| M1 #1 | 0.00s | 0.20s | starter | 3 |
| M1 #2 | 0.35s | 0.55s | true combo (+0.40s spare) | 3 |
| M1 #3 | 0.70s | 0.90s | true combo (+0.40s spare) | 3.5 |
| R ★ Grand Knell | 1.05s | 1.40s | true combo (+0.25s spare) | 12 |
| jump → 1 Falling Log | 2.15s | 2.21s | OTG (hits ragdoll) | 6 |
| 3 Toll Wave (OTG) | 2.51s | 2.82s | OTG (hits ragdoll) | 4 |

## Thrice-Rung  ·  _Base, from 0 Tolls_

Builds exactly 3 Tolls (M1 #2, Log, M1 #2) and cashes them in the same combo.

**M1 #1 → M1 #2 → 1 Striking Log → M1 #1 → M1 #2 → M1 #3 → 2 ★ Knell Reverb Palm → 3 Toll Wave (OTG)** — 43.5 dmg — ✅ verified

| Step | Starts | First hit | Connects as | Dmg |
|---|---|---|---|---|
| M1 #1 | 0.00s | 0.20s | starter | 3 |
| M1 #2 | 0.35s | 0.55s | true combo (+0.40s spare) | 3 |
| 1 Striking Log | 0.70s | 0.96s | true combo (+0.34s spare) | 6 |
| M1 #1 | 1.26s | 1.46s | true combo (+0.50s spare) | 3 |
| M1 #2 | 1.61s | 1.81s | true combo (+0.40s spare) | 3 |
| M1 #3 | 1.96s | 2.16s | true combo (+0.40s spare) | 3.5 |
| 2 ★ Knell Reverb Palm | 2.31s | 2.61s | true combo (+0.30s spare) | 18 |
| 3 Toll Wave (OTG) | 4.66s | 4.97s | OTG (hits ragdoll) | 4 |

## Hundred Tolls  ·  _Awakened_

**M1 #1 → M1 #2 → M1 #3 → U1 Hundredfold Strikes → U3 Sympathetic Cascade (OTG)** — 49 dmg — ✅ verified

| Step | Starts | First hit | Connects as | Dmg |
|---|---|---|---|---|
| M1 #1 | 0.00s | 0.20s | starter | 3.5 |
| M1 #2 | 0.35s | 0.55s | true combo (+0.40s spare) | 3.5 |
| M1 #3 | 0.70s | 0.90s | true combo (+0.40s spare) | 4 |
| U1 Hundredfold Strikes | 1.05s | 1.23s | true combo (+0.42s spare) | 25 |
| U3 Sympathetic Cascade (OTG) | 3.38s | 3.83s | OTG (hits ragdoll) | 13 |

## Dōjō-ji  ·  _Awakened_

The bell drops over the body the cascade threw.

**M1 #1 → M1 #2 → M1 #3 → U3 Sympathetic Cascade → U2 Kanemaki (OTG capture)** — 46 dmg — ✅ verified

| Step | Starts | First hit | Connects as | Dmg |
|---|---|---|---|---|
| M1 #1 | 0.00s | 0.20s | starter | 3.5 |
| M1 #2 | 0.35s | 0.55s | true combo (+0.40s spare) | 3.5 |
| M1 #3 | 0.70s | 0.90s | true combo (+0.40s spare) | 4 |
| U3 Sympathetic Cascade | 1.05s | 1.50s | true combo (+0.15s spare) | 13 |
| U2 Kanemaki (OTG capture) | 2.50s | 3.00s | OTG (hits ragdoll) | 22 |

## One Hundred and Eight  ·  _Awakened_

The finisher.

**M1 #1 → M1 #2 → M1 #3 → U4 The 108th Toll** — 37 dmg — ✅ verified

| Step | Starts | First hit | Connects as | Dmg |
|---|---|---|---|---|
| M1 #1 | 0.00s | 0.20s | starter | 3.5 |
| M1 #2 | 0.35s | 0.55s | true combo (+0.40s spare) | 3.5 |
| M1 #3 | 0.70s | 0.90s | true combo (+0.40s spare) | 4 |
| U4 The 108th Toll | 1.05s | 1.45s | true combo (+0.20s spare) | 26 |

