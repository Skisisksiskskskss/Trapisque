# Core systems at concept level (WP-013)

Rubric columns: F faithful · V vanilla-native · R readable · M meaningful · D distinct · C connected · Fe feasible (1–5). Concepts were written before scoring; *italic* = deliberately unusual.

## 1. The Tides
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| T1 | **Day-like cycle** on one global clock: Thrive (day) → Flow (dusk) → Endure (night) → Flow (dawn) | 5 | 5 | 5 | 4 | 4 | 5 | 5 | **33** |
| T2 | Three equal thirds (Thrive → Flow → Endure) | 5 | 4 | 4 | 4 | 4 | 5 | 5 | 31 |
| T3 | Player lever: a costly act shifts the Tide for everyone, as sleeping skips the night | 4 | 5 | 4 | 4 | 4 | 4 | 5 | 30 |
| T4 | One Tide per in-game day (long cycle) | 4 | 4 | 3 | 3 | 3 | 4 | 5 | 26 |
| T5 | Regional Tides sweeping across the map | 3 | 2 | 3 | 4 | 5 | 4 | 2 | 23 |
| T6 | Random, weather-like Tides | 3 | 4 | 2 | 3 | 3 | 4 | 5 | 24 |
| T7 | Soul-driven: deaths push the cycle toward Endure | 3 | 3 | 2 | 4 | 5 | 5 | 4 | 26 |
| T8 | Occupation pressure: Illager draining lengthens Endure | 4 | 3 | 2 | 4 | 5 | 5 | 4 | 27 |
| T9 | *The Tide is a song in three movements; discs and music sync to it* | 4 | 3 | 3 | 3 | 5 | 4 | 3 | 25 |
| T10 | *Personal Tides per player* | 2 | 1 | 2 | 3 | 5 | 3 | 1 | 17 |

**Pick: T1, plus T3 as a later lever (Should).**
- **Cycle:** one `thesift:tides` world clock; period 24 000 ticks (a familiar 20 minutes). Thrive 0–10 000 · Flow 10 000–12 000 · Endure 12 000–22 000 · Flow 22 000–24 000. Flow is the short, calm hinge between the two, as canon says ("no effect").
- **Per Tide (from canon, translated):**
  - **Thrive:** souls flow freely. Healthy sculk regrows and blooms, soul harvests yield more, natives are out and about, and it's brightest.
  - **Flow:** baseline. Tide-bound features change state (the traversal windows: see §2 links).
  - **Endure:** soul flow stops (sculk dims and can't be harvested), the sky darkens so hostile sifters and sculkers surface, "stronger" variants show a readable glow, and rare **Endure blooms** open. Danger for rewards.
- **How players read it:** sky colour and light, fog, stars, music variant, drifting motes, clocks, native behaviour (blubs shelter, echo golems gather at gates), flowers opening.
- **The lever (T3, Should):** a costly act (e.g. a soul-powered bell earned late) moves the clock to the next Tide marker for everyone, the way beds skip the night. It needs multiplayer consent rules like `playersSleepingPercentage`.
- **Feasibility (26.3, VANILLA_ANALOGS W4):** `data/thesift/world_clock/tides.json` = `{}`; `data/thesift/timeline/tides.json` = clock `thesift:tides`, `period_ticks` 24000, time markers `thesift:thrive` / `thesift:flow` / `thesift:endure` / `thesift:dawn`, tracks for light, sky, fog, stars, particles, music, spawns and `visual/sun_angle`; dimension type `timelines: #thesift:in_sift`, `default_clock: thesift:tides`. Sift gameplay reads **our own registered environment attributes** keyframed on the same timeline, for example `thesift:gameplay/soul_flow` (float: Thrive 1.5, Flow 1.0, Endure 0.0) and `thesift:gameplay/tide` (integer). Data packs can retune the Tides without code, and client sync, persistence and `/time` come free.

## 2. The soul economy
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| S1 | **Souls are experience in physical form**: no new currency; Sift sinks and sources work in XP (vanilla's catalyst precedent) | 4 | 5 | 5 | 4 | 4 | 5 | 5 | **32** |
| S2 | Soul-mote items dropped by mobs, used like blaze powder | 3 | 4 | 4 | 3 | 3 | 4 | 5 | 26 |
| S3 | **Soul blocks** (canon): condensed souls that power golems and devices | 5 | 4 | 4 | 4 | 5 | 5 | 4 | **31** |
| S4 | **Healthy sculk as a soul bank**: it absorbs souls and blooms, and song draws them back out | 4 | 4 | 4 | 4 | 5 | 5 | 4 | **30** |
| S5 | A Dungeons-style soul meter on the HUD | 4 | 1 | 4 | 3 | 2 | 3 | 4 | 21 |
| S6 | Soul-powered gear with active abilities (the artifact translation) | 4 | 3 | 4 | 4 | 3 | 4 | 4 | 26 |
| S7 | Trading souls to natives for songs or items | 4 | 4 | 4 | 3 | 3 | 4 | 4 | 26 |
| S8 | **Illager soul tanks**: loot; breaking one frees souls and heals the land | 5 | 4 | 5 | 4 | 4 | 5 | 4 | **31** |
| S9 | *Per-chunk soul level simulation* | 4 | 2 | 2 | 4 | 5 | 5 | 2 | 24 |
| S10 | *Echoes of the dead fight beside you* | 2 | 2 | 3 | 3 | 5 | 3 | 3 | 21 |

**Pick: S1 + S3 + S4 + S8** (S6 parked for Phase 2 gear design; S5 rejected: no new HUD meters).
- **Loop:** life and death release souls (XP). Healthy sculk drinks them and blooms, most in Thrive. Players draw souls back out with song, or *condense* them into **soul blocks**, a deliberately **lossy** store (target: about 30% lost, so there are no infinite loops). Soul blocks power echo golems (canon: golems carry them and share soul energy), wake gates, and craft Sift gear. Illagers pump souls out of the ground into **soul tanks**; breaking a tank returns them and heals the scar.
- **Hazards take souls:** ichor and soul fire drain XP from outsiders (canon: ichor drains souls).
- **Guardrails:** Endure turns soul flow off (canon). No XP is created from nothing: every conversion loses value, and Sift harvests are rate-limited by Tide and growth.

## 3. Healthy vs corrupted sculk
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| H1 | **Inversion**: healthy sculk is colourful and listens to *reward* (blooms, grows, lights up when it hears music); corrupted sculk (vanilla) listens to *punish* | 5 | 5 | 5 | 4 | 5 | 5 | 4 | **33** |
| H2 | **Blight**: where Illagers drain souls, healthy sculk sickens into grey corrupted sculk that shrieks and breeds sculkers; returning souls or song cures it | 5 | 4 | 5 | 5 | 4 | 5 | 4 | **32** |
| H3 | Cure the Overworld's Deep Dark with Sift sculk | 4 | 3 | 4 | 4 | 4 | 4 | 3 | 26 |
| H4 | Sculk terrain that grows in Thrive and recedes in Endure | 3 | 3 | 4 | 3 | 4 | 4 | 2 | 23 |
| H5 | Quarantine: corrupted sculk carried in infects healthy sculk | 4 | 3 | 3 | 3 | 4 | 4 | 3 | 24 |
| H6 | *Healthy sculk as the Sift's nerves: breaking it alarms natives* | 3 | 3 | 3 | 3 | 5 | 4 | 3 | 24 |

**Pick: H1 + H2** (H3 parked as Could; it needs a vanilla-footprint decision in Phase 2). This gives canon a mechanism: corrupted sculk is "a disease that originated in the Sift", and our Illagers' soul-draining is what spreads it.

## 4. Sound as a mechanic — survives the pillars (it *is* P1)
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| N1 | **Healthy sculk answers music** (note blocks, jukeboxes, horns): blooms, spreads, lets souls go | 5 | 5 | 4 | 4 | 5 | 5 | 4 | **32** |
| N2 | **Natives answer music**: blubs gather, echo golems dance (canon "dancing automatons"), like allays and note blocks | 5 | 5 | 5 | 3 | 4 | 4 | 4 | **30** |
| N3 | **The Singer's gift of song** (canon): an instrument earned from the Singer; opens gates, blooms sculk in a radius, briefly soothes sculkers and wardens at a soul cost | 5 | 4 | 4 | 5 | 5 | 5 | 4 | **32** |
| N4 | **Musical gates** (canon "Musical Gate"): structure doors keyed to a note or chord; every note also shows as a coloured particle for accessibility | 5 | 4 | 3 | 4 | 4 | 4 | 4 | 28 |
| N5 | Sonic threats: screeching bosses, stunning plants (canon Harmonizer, "hazardous blocks") | 5 | 4 | 4 | 4 | 3 | 4 | 4 | 28 |
| N6 | *Echolocation pings reveal paths* | 3 | 3 | 2 | 3 | 5 | 3 | 3 | 22 |
| N7 | *Composing Tide-synced melodies on terrain* | 3 | 2 | 2 | 3 | 5 | 4 | 2 | 21 |

**Pick: N1 + N2 + N3, with N4/N5 as content.** Accessibility rule: every sound interaction has a visual (notes, glow, particles, animation).

## 5. The Illager occupation
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| I1 | **Soul-harvester camps**: rigs over grey blight, caged echo golems, soul tanks, patrols by day-Tides | 5 | 5 | 5 | 4 | 4 | 5 | 4 | **32** |
| I2 | **The Illager Keep** (canon track "Illager Keep"): endgame stronghold, rift hub, a High Council lieutenant | 5 | 4 | 4 | 4 | 4 | 4 | 3 | 28 |
| I3 | Rift incursions into the Overworld | 5 | 3 | 4 | 4 | 4 | 4 | 2 | 26 |
| I4 | Occupation meter per region | 3 | 3 | 3 | 3 | 3 | 4 | 3 | 22 |
| I5 | **Freeing natives**: caged golems become allies when freed (canon "Guardian of the Golems", track "Caged") | 5 | 4 | 5 | 4 | 4 | 5 | 4 | **31** |
| I6 | *Endure brings sculkers against the camps; players can exploit the war* | 4 | 4 | 4 | 5 | 5 | 5 | 3 | **30** |

**Pick: I1 + I5 + I6 core, I2 as the endgame; I3 decided in Phase 2** (vanilla footprint). Illagers reuse vanilla illager types; new illager kinds only where a role is missing.

## 6. How the systems feed each other
```
          ┌──────── TIDES (clock + timeline) ────────┐
   light/spawns │           soul_flow │              │ camp activity
                ▼                     ▼              ▼
   HOSTILES (sifters, sculkers)   HEALTHY SCULK ◄── SOUND (music, Singer's song)
        ▲   │ attack                ▲  │ blooms/yields    │ opens gates, calms
        │   ▼                       │  ▼                  ▼
   BLIGHT ◄── ILLAGER CAMPS ──► SOUL TANKS ──► SOULS (XP) ──► SOUL BLOCKS ──► ECHO GOLEMS / GATES / GEAR
 (corrupted)   drain souls        (free them)            ▲
        └─────── cured by returning souls / song ────────┘
```
Every system touches at least three others, which meets the "Connected" criterion.

## 7. Parked here (to IDEAS.md)
T5 regional Tides · T9 Tide-synced music · S9 soul simulation · S10 echoes of the dead · H4 breathing sculk terrain · N6 echolocation · N7 composing.
