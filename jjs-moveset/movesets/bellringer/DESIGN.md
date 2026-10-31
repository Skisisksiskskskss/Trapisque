# THE BELLRINGER — design document

> *"Every blow I land is a bell I've struck. Strike enough of them, and your body forgets how to stop ringing."*

An original Jujutsu Shenanigans character built for the Skill Builder. A temple-bell monk whose cursed technique, **Bonshō (梵鐘, Temple Bell Technique)**, turns every strike into a lingering vibration. Bronze-gold and patina-jade palette, temple-bell / gong / wooden-block soundscape, palm-strike martial style.

## The gimmick — TOLLS → KNELL

| | |
|---|---|
| **Tolls (0–3)** | Landing hits rings you like a bell. **M1 #2, M1 #4, every move that connects, the dash hit and the R pulse** each add **+1 Toll** (max 3). Tolls fade **12 s** after your last gain. |
| **Readout** | 1 Toll: your right palm glows gold. 2 Tolls: both palms. **3 Tolls = RESONANT**: full bronze/jade aura and a hum. Each gain plays a rising temple-bell chime. |
| **Knell** | At 3 Tolls the moves marked ★ (**Reverb Palm, Bell Toll, Strike the Bell**) become their **Knell** version and consume all Tolls. |
| **Awakening** | *Joya no Kane* — the bell never stops ringing: every R is a Grand Knell and every M1 finisher sends out an echo. |

The decision every round: spend the Knell on **Reverb Palm** (longest combo extension), **Bell Toll** (biggest single hit, best ender) or **R Grand Knell** (AoE, escape, awakening meter), or keep building for the awakening transition.

## M1s — "Palm of the Monk"

4-hit palm string (Honored One melee clips, the community's most-used set). 3 / 3 / 3.5 / 4 damage, 0.75 s hitstun on 1–3.
- **M1 #2** and **M1 #4** add a Toll on hit.
- **M4**: heavy gong palm (knockback). **Hold jump**: rising palm uptilt. **In the air**: downslam.
- Blocked M1s cost you extra recovery; whiffs play out the full swing.
- Awakened M1s chime on every hit and the finisher releases an echo shockwave.

## Dash (Q) — "Shumoku Step"

Front dash that checks for a hit every 0.1 s. On hit: short stun, +1 Toll, M1 string resets so you can go straight into M1s.

## Base moves

| Key | Move | What it does | Variants |
|---|---|---|---|
| 1 | **Striking Log** (Shumoku) | Lunging palm thrust, like ramming the log into a bell. 6 dmg, 1.0 s stun, resets the M1 string. | **Hold**: charged ram (9 dmg, knockback). **Air**: Falling Log dive that spikes the target. |
| 2 | ★ **Reverb Palm** (Hankyō-shō) | Double-palm thrust that plants a vibration; **0.55 s later an echo detonates** inside the target (4 + 5 dmg). Resets the M1 string. | **Knell**: the echo rings **three times** then bursts into a launch (18 dmg total). |
| 3 | **Toll Wave** (Kane no Hamon) | Pushes a ring of sound forward (projectile). 4 dmg, pulls the target toward you. | **Hold**: Sustained Note — a slower, larger wave that hits up to 3 times. |
| 4 | ★ **Bell Toll** (Tsurigane Otoshi) | Rising palm launches the target, then a spectral temple bell slams them back to the ground (4 + 6 dmg). | **Knell**: a giant bell crushes them into a crater (4 + 14 dmg, +awakening). |
| R | ★ **Strike the Bell** (Kane-uchi) | A resonant clap: short-range pulse, 2 dmg, stun. Combo extender / anti-pressure. | **Knell (3 Tolls)**: **Grand Knell** — a colossal bell drops around you and rings out (AoE, 12 dmg, launch, +awakening). |

## Awakening — "Joya no Kane: One Hundred and Eight Tolls"

Named after the Buddhist New-Year ritual of striking the temple bell 108 times to dispel the 108 earthly desires. On activation a spectral bell descends over the Bellringer and tolls, blasting nearby enemies away. 100 s.

| Key | Ultimate | What it does |
|---|---|---|
| 1 | **Hundredfold Strikes** | Rushes in and holds the target for a 10-hit palm barrage (every hit chimes), finished by a gong palm that blasts them away. |
| 2 | **Kanemaki — The Bell of Dōjō-ji** | Drops a bell over the target, trapping them; you strike it three times from outside, the third strike shatters it. |
| 3 | **Sympathetic Cascade** | Stomp that sends out three expanding resonance rings (AoE, each ring hits). |
| 4 | **The 108th Toll** | Palm thrust; on hit, a colossal bell descends, 107 phantom tolls ring in a heartbeat and the 108th detonates (≈26 dmg). |

## Combo routes

Verified against frame data (see `FRAMEDATA.md`, generated from the actual timelines). Notation: `M1×3` = first three M1s, `M4↑` = uptilt, `M4↓` = downslam, `(T)` = needs 3 Tolls.

1. **First Toll** (BnB): `M1×3 → 2 Reverb Palm → (echo) → M1×4 → 1 Striking Log`
2. **Rising Knell**: `M1×3 → 4 Bell Toll → 3 Toll Wave (on the bounce)`
3. **Grand Knell** (T): `M1×3 → R Grand Knell → Dash → M1×4`
4. **Thrice-rung** (T): `M1×2 → 1 Striking Log → M1×3 → 2 Knell Reverb Palm → M4`
5. **Bell Drop**: `M1×3 → M4↑ (uptilt) → jump → 1 Falling Log → 3 Toll Wave`

## Why it feels like a JJS character

- One readable resource with a visible meter (palm glow / aura) and an audible one (rising chimes), like Hakari's jackpot or Kashimo's charge.
- Every move has a combo role: starter (Dash / Log), extender (Reverb Palm / R), launcher (Bell Toll / uptilt), neutral (Toll Wave), ender (Knells).
- Moves that hit reset the M1 counter (`SETMELEE`) so routes chain M1 strings instead of `1 2 3 4`.
- Damage and stun numbers sit in the same range as the base roster (100 HP).
