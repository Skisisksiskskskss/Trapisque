# THE BELLRINGER — design document (v1.0)

> *"Every blow I land is a bell I've struck. Strike enough of them, and your body forgets how to stop ringing."*

An original Jujutsu Shenanigans character for the Skill Builder. A temple-bell monk whose cursed technique, **Bonshō (梵鐘, Temple Bell Technique)**, turns every strike into a lingering vibration. Bronze-gold and patina-jade palette; palm-strike martial style; a soundscape of the game's own punch/energy SFX layered with licensed temple bells, gongs and wooden temple blocks; bronze spark sprays, impact stars, lens-flare glints and floor shockwaves from the Particle Emitter block.

- Timings: [`FRAMEDATA.md`](FRAMEDATA.md) · Combos (machine-verified): [`COMBOS.md`](COMBOS.md) · Source: [`bellringer.py`](bellringer.py), [`fx.py`](fx.py)

## The gimmick — TOLLS → KNELL

| | |
|---|---|
| **Tolls (0–3)** | Landing hits rings you like a bell. **M1 #2, M1 #4 (any direction), Striking Log, Reverb Palm, Toll Wave, Bell Toll, the dash and the R pulse** each add **+1 Toll** (max 3) when they connect. Tolls fade **12 s** after your last gain. |
| **Readout** | 1 Toll: right palm glows gold. 2 Tolls: both palms (golden motes rise from the palm that lights up). **3 Tolls = RESONANT**: bronze/jade body aura, a burst of rising motes, and **a small spectral bell hangs over your head** (both players can see the Knell is ready). Each gain rings a small temple bell that rises in pitch; reaching 3 answers with a deeper brass bell. |
| **Knell** | At 3 Tolls the moves marked ★ — **Reverb Palm, Bell Toll, Strike the Bell (R)** — become their **Knell** version. Reverb Palm and Bell Toll consume the Tolls **only if they connect**; the R Grand Knell consumes on use (it doubles as an escape). |
| **Awakening** | *Joya no Kane*: the bell never stops ringing. Awakened M1s chime, the M1 finisher releases an echo ring, the dash echoes, and **every R is a Grand Knell** (12 s cooldown). |

The decision every exchange: spend the Knell on **Reverb Palm** (longest extension, 18 dmg), **Bell Toll** (biggest single hit + awakening meter, 18 dmg) or **R Grand Knell** (AoE launch, i-frames, +12 awakening) — or keep stacking toward the awakening.

## M1s — "Palm of the Monk"

4-hit palm string on the Honored One melee clips (the community's most-used set). 3 / 3 / 3.5 / 4 damage, 0.75 s hitstun on hits 1–3, 0.35 s per swing.
- **M1 #2** and **M1 #4** add a Toll.
- **M4**: gong palm knockback. **Hold jump**: rising palm uptilt. **In the air**: downslam.
- Whiffs play out the swing; blocked swings cost extra recovery (an unblockable 0-damage probe tells a block from a miss).
- Awakened: +0.5 damage per hit, chime + jade ring on every hit, M4 releases an echo ring.

## Dash (Q) — "Shumoku Step" · 6 s

Front dash that checks for a hit every 0.08 s. On hit: 3 dmg, short stun, +1 Toll, M1 string resets so you go straight into M1s. Awakened: jade afterimages and an echo ring instead of a Toll.

## Base moves

| Key | Move | CD | What it does | Variants |
|---|---|---|---|---|
| 1 | **Striking Log** (Shumoku) | 10 s | Lunging palm thrust (6 dmg, 1.0 s stun) that also catches knocked-back bodies. Resets the M1 string. | **Hold**: Charged Log — 0.6 s charge, 9-dmg ram with heavy knockback. **Air**: Falling Log — diving spike (6 dmg). |
| 2 | ★ **Reverb Palm** (Hankyō-shō) | 12 s | Double-palm thrust plants a vibration; **0.5 s later the echo detonates** (4 + 5 dmg). Resets the M1 string. | **Knell**: three ascending echoes, then a bell burst launch — 18 dmg, +6 awakening. |
| 3 | **Toll Wave** (Kane no Hamon) | 9 s | Palm pushes a fast ring of sound (projectile, 4 dmg) that **pulls** the target in and can pick up downed targets. | **Hold**: Sustained Note — a slow, wide wave that passes through and hits up to 3×. |
| 4 | ★ **Bell Toll** (Tsurigane Otoshi) | 14 s | Rising palm launches; a clap summons a spectral bell that slams them back down (4 + 6 dmg). | **Knell**: a giant bell crushes them into a cracked crater (4 + 14 dmg, +10 awakening). |
| R | ★ **Strike the Bell** (Kane-uchi) | 7 s | Resonant clap: short-range pulse (2 dmg, 0.8 s stun). Resets the M1 string — the "extender". | **3 Tolls → Grand Knell**: a colossal bell drops around you and rings everyone inside straight up (12 dmg, 0.6 s i-frames, +12 awakening). |

## Awakening — "Joya no Kane: One Hundred and Eight Tolls" · 100 s

Named after the Buddhist New-Year rite of striking the temple bell 108 times to dispel the 108 earthly desires. Requires a full bar. Invulnerable 2.2 s activation: a hollow gong swells, a colossal bell descends over the Bellringer and tolls (global), blasting nearby enemies upward; a bronze/jade aura, golden motes drifting off the body and a spectral bell hanging over the Bellringer then last the whole awakening. Base Tolls are cleared — awakened moves are always at full power.

| Key | Ultimate | CD | What it does |
|---|---|---|---|
| 1 | **Hundredfold Strikes** | 14 s | Lunging catch → holds the target → 10 chiming palms → gong palm launch. **25 dmg.** |
| 2 | **Kanemaki — The Bell of Dōjō-ji** | 20 s | A bell drops in front of you (captures downed targets too); a caught target is held inside while you strike the bell three times, the third strike shatters it. **22 dmg.** |
| 3 | **Sympathetic Cascade** | 16 s | Stomp → three resonance rings expand across the floor (≈8 / 15 / 22 studs, 0.3 s apart, hit downed targets); the third pops everyone up. **Up to 13 dmg.** |
| 4 | **The 108th Toll** | 30 s | Palm thrust; on hit you turn invulnerable, a colossal bell descends over you both, seven rapid tolls ring, the 108th detonates. **26 dmg.** |

## Kill flourish

When a big move lands the killing blow (Knell Reverb burst, Knell Bell Toll, Grand Knell, and the final hits of all ultimates), the Bellringer presses palms in prayer while a funeral bell tolls three times and a spectral bell rises over the fallen.

## Combo routes (all verified — see COMBOS.md for the frame-by-frame)

| Route | Mode | Inputs | Dmg |
|---|---|---|---|
| **First Toll** (BnB) | base | `M1×3 → 2 → M1×4 → 1` | 38 |
| **Rising Knell** | base | `M1×3 → 4 → 3` | 23.5 |
| **Bell Drop** | base | `M1×3 → M4↑ → jump 1 → 3` | 23.5 |
| **Clap Chain** | base | `M1×3 → R → M1×3 → 2` | 30 |
| **Grand Knell** | 3 Tolls | `M1×3 → R★ → jump 1 → 3` | 31.5 |
| **Thrice-Rung** | from 0 Tolls | `M1×2 → 1 → M1×3 → 2★ → 3` | 43.5 |
| **Hundred Tolls** | awakened | `M1×3 → 1 → 3` | 49 |
| **Dōjō-ji** | awakened | `M1×3 → 3 → 2` | 46 |
| **One Hundred and Eight** | awakened | `M1×3 → 4` | 37 |

Thrice-Rung is the signature: it builds exactly three Tolls (M1 #2, Striking Log, M1 #2) and cashes them in the same combo.

## Look

- **Every hit** sprays bronze spark streaks (Particle Emitter, velocity-aligned, falling); heavy hits add a textured impact star.
- **Every bell that rings** lays a golden shockwave flat on the floor and kicks up dust; Knell finishers and the ultimates' last hits flash a lens-flare glint, the "ding" of struck bronze.
- **Toll Wave** sends visible rings of sound out of the palm; **Sympathetic Cascade**'s floor waves are drawn exactly as wide as their hitboxes.
- Particle textures are Roblox Image assets other JJS creators already use for particles; every emitter is a short burst except the awakening's mote stream, which the spawn passive also clears.

## Why it plays like a JJS character

- One readable resource with both a visible meter (palm glow → aura) and an audible one (rising chimes), like Hakari's jackpot or Kashimo's charge.
- Every move has a combo role: starter (dash / Log), extender (Reverb Palm / R pulse), launcher (Bell Toll / uptilt), neutral (Toll Wave), ender (Knells, Charged Log).
- Moves reset the M1 counter (`SETMELEE`) so routes chain M1 strings instead of `1 2 3 4`.
- Hitboxes that should catch knocked-down bodies say so (`HIT RAGDOLL`), and only those: Log, Falling Log, Toll Wave, the bells and the cascade.
- Lockouts (NoM1 / NoJump / NoSprint / direction lock) end with the move, so recovery is exactly the timeline length.
- Damage and stun live in the base roster's range (100 HP; 3–4 per M1, 6–18 per move, 22–26 per ultimate).
