# Core systems at concept level (WP-013; revised after WP-014 critique round 1)

Rubric columns: F faithful · V vanilla-native · R readable · M meaningful · D distinct · C connected · Fe feasible (1–5). Concepts were written before scoring; *italic* = deliberately unusual. Scores changed by the critique are marked ↓/↑ with the reason in §8.

**One-line model:** *souls are the fuel, music is the spark, the Tide is the season.*

## 1. The Tides
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| T1 | Day-like cycle on one global clock: Thrive → Flow → Endure → Flow | 5 | 5 | 5 | 3↓ | 3↓ | 5 | 5 | 31 |
| T1′ | **T1 plus one signature rule per Tide that only the Sift has** (growth and recharge / passage / hunters and rare blooms) | 5 | 4 | 4 | 5 | 5 | 5 | 4 | **32** |
| T2 | Three equal thirds (Thrive → Flow → Endure) | 5 | 4 | 4 | 4 | 4 | 5 | 5 | 31 |
| T3 | Player lever: a costly act shifts the Tide for everyone, as sleeping skips the night | 4 | 5 | 4 | 4 | 4 | 4 | 5 | 30 |
| T4 | One Tide per in-game day (long cycle) | 4 | 4 | 3 | 3 | 3 | 4 | 5 | 26 |
| T5 | Regional Tides sweeping across the map | 3 | 2 | 3 | 4 | 5 | 4 | 2 | 23 |
| T6 | Random, weather-like Tides | 3 | 4 | 2 | 3 | 3 | 4 | 5 | 24 |
| T7 | Soul-driven: deaths push the cycle toward Endure | 3 | 3 | 2 | 4 | 5 | 5 | 4 | 26 |
| T8 | Occupation pressure: Illager draining lengthens Endure | 4 | 3 | 2 | 4 | 5 | 5 | 4 | 27 |
| T9 | *The Tide is a song in three movements; discs and music sync to it* | 4 | 3 | 3 | 3 | 5 | 4 | 3 | 25 |
| T10 | *Personal Tides per player* | 2 | 1 | 2 | 3 | 5 | 3 | 1 | 17 |

**Pick: T1′, plus T3 as a later lever (Should, with limits).**
- **Cycle:** one `thesift:tides` world clock with a **30 000-tick period (25 minutes)**, deliberately not the Overworld's 24 000. This way Endure never lines up with Overworld night by accident.

  | Tide | Ticks | Length |
  |---|---|---|
  | Thrive | 0–12 000 | 10 min |
  | Flow | 12 000–15 000 | 2.5 min |
  | Endure | 15 000–27 000 | 10 min |
  | Flow | 27 000–30 000 | 2.5 min |

  Canon doesn't give the order (RESEARCH §3); this order is our choice.
- **What each Tide changes.** These are canon effects translated to a sandbox (RESEARCH canon #7–8).
  - **Thrive: growth and recharge.** Canon: "Faster Soul regeneration and artifact cooldowns".
    - Healthy sculk turns stored souls into growth (§2).
    - Soul-powered tools recharge **twice as fast**. The gift of song is the first of these.
    - Natives roam; the light is full.
  - **Flow: passage.** Canon: "Flow: No effect" on the hero; the Tides "affect … traversing".
    - Flow changes the *land*, not the player: **tide-bridges** unfold across ichor and chasms, and **bounce blooms** turn springy (canon: "bouncy slimes used to access higher areas").
    - Both fold away at the end of Flow, with a warning 20 seconds ahead: petals curl, a rising creak sounds, and a subtitle appears.
    - So Flow is when you cross. The rest of the cycle, those routes are closed or harder.
  - **Endure: hunters and rare blooms.** Canon: "More powerful mobs will spawn and your passive soul regeneration will stop".
    - The sky darkens, so light-gated hostile sifters and sculkers surface, some as "enduring" variants that show a readable glow.
    - Soul tools stop recharging, and healthy sculk stops growing.
    - **Sound draws hunters** (§4).
    - Rare **Endure blooms** open, and their reagents can be taken only then.
- **First arrival is in Thrive.** The clock is created **paused at Thrive** and starts the first time any frame in the world opens. After that, the gate's membrane shows the Tide on the far side: bright cyan for Thrive, amber for Flow, violet for Endure, each with its own particle shape. Players choose when to cross. A small sanctuary around every Sift-side gate covers arrivals in Endure (entry_path.md).
- **How players read it:**
  - sky and fog colour, stars in Endure, soul motes (all keyframed);
  - Tide music variants (canon: OST);
  - native behaviour: blubs shelter, echo golems gather at gates;
  - Endure blooms opening; bridges folding.
  - An **inverted daylight detector** senses Endure, because Endure lowers sky light. That makes it a vanilla-native redstone Tide sensor (rules.md).
  - Clocks do **not** show the Tide. In 26.3 the clock model reads the sun only in `minecraft:overworld` and spins elsewhere (VANILLA_ANALOGS; verified in the 26.3 client jar).
- **The lever (T3, Should):** a costly act (a soul block offered at a late-game bell) moves the clock **only toward Thrive**, never toward Endure. That mirrors sleep, which only ever skips toward safety.
  - Multiplayer consent follows `players_sleeping_percentage`, counted among players in the Sift.
  - Beds never skip the Tide.
- **Admins:**
  - `/time set thesift:thrive` (or `/time of thesift:tides …`) works in the Sift. Vanilla `/time set day` doesn't, because the Sift's markers are `thesift:*`. Documented.
  - **`advance_time false` freezes every world clock, the Tides included** (verified: `ServerClockManager.tick`). This matches freezing the sun.
  - Servers that disable it should pick the frozen Tide with `/time of thesift:tides set thesift:thrive`. This is documented in the server notes, and no code overrides the gamerule.
- **Feasibility** (26.3, VANILLA_ANALOGS W4; the core was spike-verified):
  - Data: `world_clock/tides.json`; `timeline/tides.json` with `period_ticks` 30000, Tide markers and tracks (light, sky, fog, stars, particles, music); a dimension type with `default_clock: thesift:tides`.
  - Gameplay reads **our own registered environment attributes** keyframed on that timeline: `thesift:gameplay/soul_flow` (Thrive 1.0, Flow 0.25, Endure 0.0, **default 0.0 everywhere else**) and `thesift:gameplay/tide`.
  - Blocks that change with the Tide read those attributes. Slow, organic changes (blooms opening) use random ticks, as eyeblossoms do. Changes that must be prompt (bridges, bounce blooms) use a block-entity check every 20 ticks, as the daylight detector does, and exist only in limited, generated numbers.

## 2. The soul economy: a one-way ledger
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| S1 | **Souls are experience in physical form**: no new currency; Sift sinks and sources work in XP (vanilla's catalyst precedent) | 4 | 5 | 5 | 4 | 4 | 5 | 5 | **32** |
| S2 | Soul-mote items dropped by mobs, used like blaze powder | 3 | 4 | 4 | 3 | 3 | 4 | 5 | 26 |
| S3 | **Soul blocks** (canon artifact): condensed souls that power golems and devices | 4↓ | 4 | 4 | 4 | 5 | 5 | 4 | **30** |
| S4 | Healthy sculk as a soul **bank** that song draws back out | 4 | 4 | 4 | 4 | 5 | 5 | 4 | ~~30~~ **rejected** (XP amplifier loop, MF1) |
| S4′ | **Healthy sculk drinks deaths like a catalyst and turns them into growth, never back into XP** | 4 | 5 | 4 | 4 | 4 | 5 | 5 | **31** |
| S5 | A Dungeons-style soul meter on the HUD | 4 | 1 | 4 | 3 | 2 | 3 | 4 | 21 |
| S6 | Soul-powered gear with active abilities (the artifact translation) | 4 | 3 | 4 | 4 | 3 | 4 | 4 | 26 |
| S7 | Trading souls to natives for songs or items | 4 | 4 | 4 | 3 | 3 | 4 | 4 | 26 |
| S8 | **Illager soul tanks**: loot; breaking one frees souls and heals the land | 5 | 4 | 5 | 4 | 4 | 5 | 4 | **31** |
| S9 | *Per-chunk soul level simulation* | 4 | 2 | 2 | 4 | 5 | 5 | 2 | 24 |
| S10 | *Echoes of the dead fight beside you* | 2 | 2 | 3 | 3 | 5 | 3 | 3 | 21 |

**Pick: S1 + S3 + S4′ + S8, as a one-way ledger.** S6 is parked for Phase 2 gear design; S5 is rejected (no new HUD meters).
- **Two ways souls enter:**
  1. **Deaths near a bloom heart.** A bloom heart is the healthy-sculk counterpart of the vanilla catalyst (working name). It takes a nearby death's experience **exactly as a vanilla catalyst does**: the same event, the same radius, the same "that XP never drops" rule. It stores that experience as charge.
  2. **Offering.** A player crouches at a soul-drinking block (a bloom heart, or a dormant Ancient City frame) and their XP bar visibly flows into it. Stepping away stops it at once. Crouching is already the Deep Dark's posture, and nothing takes a player's experience unless they offer it.
- **Where souls go.** Nothing converts back into XP.
  - **Growth.** Charge spreads as blooms, light and Sift reagents (soul blossoms, Endure blooms) at a rate set by `soul_flow`: fast in Thrive, slow in Flow, none in Endure, **none outside the Sift**. Thrive raises the **rate**, never the **yield**. Healthy sculk and its products never drop experience. Vanilla sculk drops XP when mined, so this closes the sculk-XP-farm loop.
  - **Soul blocks.** An offering at a bloom heart condenses the player's XP into a **soul block**, which is **fuel, not a bank**. Soul blocks are spent to power an echo golem's work, a musical gate, a Sift gear upgrade, or the Tide lever. They cannot be turned back into XP.
  - **Waking a frame** (entry_path.md) is a one-time offering.
- **Hazards take souls.** Ichor and soul fire drain XP from outsiders who stand in them, as a readable hazard (canon: ichor "drains their souls"). Natives are immune.
- **Illager soul tanks (S8)** are finite containers in camps. Breaking one releases its souls into nearby healthy sculk as growth, which cures blight. The souls never go to a player as XP, and tanks don't refill.
- **Why this holds** (the critic's probe a):
  - No Sift path creates experience.
  - Automatic kill chambers can feed *growth*, exactly as they feed vanilla catalysts, but growth yields materials, not XP.
  - Mending works everywhere except near a bloom heart, which is the same rule as near a vanilla catalyst.
  - Soul blocks can't be used to store XP and dodge the death penalty, because they never convert back.

## 3. Healthy vs corrupted sculk
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| H1 | **Inversion**: healthy sculk is colourful and listens to *reward*; corrupted sculk listens to *punish* | 5 | 5 | 5 | 4 | 5 | 5 | 4 | **33** |
| H2 | **Blight**: where Illagers drain souls, healthy sculk sickens into corrupted sculk; returning souls or song cures it | 5 | 4 | 5 | 5 | 4 | 5 | 4 | **32** |
| H3 | Cure the Overworld's Deep Dark with Sift sculk | 4 | 3 | 4 | 4 | 4 | 4 | 3 | 26 |
| H4 | Sculk terrain that grows in Thrive and recedes in Endure | 3 | 3 | 4 | 3 | 4 | 4 | 2 | 23 |
| H5 | Quarantine: corrupted sculk carried in infects healthy sculk | 4 | 3 | 3 | 3 | 4 | 4 | 3 | 24 |
| H6 | *Healthy sculk as the Sift's nerves: breaking it alarms natives* | 3 | 3 | 3 | 3 | 5 | 4 | 3 | 24 |

**Pick: H1 + H2**, with three changes from critique round 1.
- **Blight *is* vanilla sculk.** Corrupted sculk in the Sift uses the vanilla blocks: sculk, veins, sensors, shriekers and catalysts. It is told apart from healthy sculk by **behaviour and shape**, not only colour: it pulses, its veins creep, and its sensors and shriekers react (SF7).
  - Its shriekers give Darkness and alert nearby hostiles, but **never summon wardens**; no wardens live here (rules.md).
  - Tone: where Illagers work, the colour drains to the Deep Dark's black-teal.
- **The Illagers speed the disease up; they didn't start it.** Canon says the disease that corrupted sculk "originated in the Sift" from "an unknown factor", and the Deep Dark is ancient. So the Illagers' soul-draining **weakens** healthy sculk and lets the old blight take hold faster (SF8).
  - Blight doesn't breed sculkers. Sculkers are the Carapace's native hunters, part of the "independent ecosystem" (XW2).
- **Curing needs the Sift.** Returning souls (a broken tank, or growth from a bloom heart) or the gift of song turns blight back into healthy sculk. It works only where `soul_flow` > 0, which means **never in the Overworld's Deep Dark** (MF3). H3 stays parked.

## 4. Sound as a mechanic
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| N1 | **Healthy sculk answers music** (note blocks, jukeboxes, horns): growth expresses faster, blooms open, light rises | 5 | 5 | 4 | 4 | 5 | 5 | 4 | **32** |
| N2 | **Natives answer music**: blubs gather, echo golems dance (wiki gallery captions: "Echo golems dancing in front of the Deep Dark portal"), like allays and note blocks | 5 | 5 | 5 | 3 | 3↓ | 4 | 4 | 29 |
| N3 | **The Singer's gift of song** (canon achievement "Receive the Singer's gift of song"): an earned instrument that opens gates, sparks growth in a radius and calms Sift natives | 5 | 4 | 4 | 5 | 5 | 5 | 4 | **32** |
| N4 | **Musical gates** (canon "Musical Gate"): structure doors keyed to an instrument and note | 5 | 4 | 3 | 4 | 4 | 4 | 4 | 28 |
| N5 | Sonic threats: screeching bosses, stunning plants (canon Harmonizer, "hazardous blocks") | 5 | 4 | 4 | 4 | 3 | 4 | 4 | 28 |
| N6 | *Echolocation pings reveal paths* | 3 | 3 | 2 | 3 | 5 | 3 | 3 | 22 |
| N7 | *Composing Tide-synced melodies on terrain* | 3 | 2 | 2 | 3 | 5 | 4 | 2 | 21 |
| N8 | **Sound has a Tide cost**: in Endure, music and loud sounds draw sculkers within range (the Deep Dark's rule returns at night) | 4 | 5 | 4 | 5 | 4 | 5 | 4 | **31** |

**Pick: N1 + N2 + N3 + N8, with N4/N5 as content.**
- **Music is a spark, not a source.** Music makes existing charge express faster as growth and light. It never creates growth from nothing, so a note-block clock can't grow the Sift without souls (SF6/SF9).
- **The choice:** in Thrive the Sift answers sound; in Endure the hunters do. Playing in Endure is a real decision, whether to lure sculkers into an Illager camp (I6) or to stay quiet.
- **Gift of song (N3):**
  - **Earned** from the Singer after the player restores the Meadow's stolen harmony. The route follows canon quest shapes: "Lost Harmonies: Find the stolen soul blocks", "Guardian of the Golems". Exact steps are Phase 2.
  - **Charges:** it refills twice as fast in Thrive and not at all in Endure (canon Tide effects).
  - **Scope:** it affects **only Sift life** (healthy sculk, blight, natives, gates). It never affects wardens or Overworld sculk (MF3).
- **Accessibility (P1):** every Sift sound has a **subtitle** and a **visual**.
  - A musical gate shows its key as a **carved instrument glyph**: the note block's base block, for example gold for bells. It also shows the note's position on a carved staff, plays the note, and shows a subtitle.
  - No step depends on colour alone, or on sound alone.

## 5. The Illager occupation
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| I1 | **Soul-harvester camps**: rigs over blight, caged echo golems, soul tanks, patrols by day-Tides | 5 | 5 | 5 | 4 | 3↓ | 5 | 4 | 31 |
| I2 | **The Illager Keep** (canon track "Illager Keep"): endgame stronghold, rift hub, a High Council lieutenant | 5 | 4 | 4 | 4 | 4 | 4 | 3 | 28 |
| I3 | Rift incursions into the Overworld | 5 | 3 | 4 | 4 | 4 | 4 | 2 | 26 |
| I4 | Occupation meter per region | 3 | 3 | 3 | 3 | 3 | 4 | 3 | 22 |
| I5 | **Freeing natives**: caged golems become allies when freed (canon "Guardian of the Golems", track "Caged") | 5 | 4 | 5 | 4 | 3↓ | 5 | 4 | 30 |
| I6 | *Endure brings sculkers against the camps; players can exploit the war* | 4 | 4 | 4 | 5 | 5 | 5 | 3 | **30** |

**Pick: I1 + I5 + I6 for 1.0.** I2 (the Keep) and I3 (rifts) come after 1.0 (§7).
- **Camps are finite.** They are generated structures, and their tanks don't refill. Freed golems stay free.
- Like vanilla pillager outposts, a camp's grounds keep spawning illagers (the structure-spawn precedent). Camps stay dangerous but are no richer an XP source than outposts (SF12).
- Illagers reuse vanilla illager types; new kinds appear only where a role is missing.

## 6. How the systems feed each other
```
          ┌──────── TIDES (clock + timeline) ────────┐
   light/spawns │   soul_flow (growth rate) │         │ camp patrols (day-Tides)
                ▼                          ▼          ▼
   HUNTERS (sifters, sculkers) ◄─ Endure ─ SOUND ─ Thrive ─► HEALTHY SCULK (growth, light, reagents)
        │ attack camps (I6)                  │ spark                  ▲ charge
        ▼                                    ▼                        │
   ILLAGER CAMPS ──drain──► BLIGHT (vanilla sculk)     DEATHS ──► BLOOM HEARTS ◄── OFFERINGS (your XP)
        │ break tanks ───────────── cures ◄──┘                        │
        └──► freed ECHO GOLEMS ◄── fuel ── SOUL BLOCKS ◄── offering ───┘
```
Every system touches at least three others. No arrow leads back to experience.

## 7. Scope for 1.0 vs later (SF10: "fewer, deeper")
- **1.0 must:**
  - the Tides (T1′);
  - the entry and return (entry_path.md);
  - two canon areas (Singer's Meadow and the Carapace; Lullaby Hills as a Meadow sub-biome);
  - healthy sculk, blight and bloom hearts; soul blocks;
  - natives (Blub, Echo Golem, Slabber, Trill as particles);
  - a small hostile set (Bloombud, Nester, Pollinator + Sprout, Stalker, Scavenger);
  - ichor; the gift of song; Illager camps with caged golems and tanks;
  - **one boss and one miniboss.**
- **The boss (recommended): the Sculk Monstrosity** as the heart of the blight. Its canon "catalysis" attack is vanilla catalyst grammar turned into a weapon, and beating it cures the land around its arena. The miniboss is the Harmonizer (a sifter). The alternative is the Monarch (apex hunter of Endure); this choice is for Gate A.
- **After 1.0 (roadmap):** the Monarch and the sculker nest; the Illager Keep; rifts (I3); the Tide lever (T3); an aurora sky (it needs a client mixin, because 26.3 Fabric API has no per-dimension sky hook); more areas from the soundtrack's names.

## 8. Critique round 1: score changes
| Score | Change | Reason |
|---|---|---|
| T1 M/D | ↓ | Alone it is day/night with a new palette (MF2). T1′ adds the per-Tide rules. |
| S3 F | ↓ | Soul blocks exist in canon, but the Singer forming them and golems running on them are novel or fan-sourced (RESEARCH canon #13, L). |
| S4 | rejected | Banked souls drawn back out by song form an XP amplifier and battery (MF1). |
| N2 D | ↓ | Allays already dance to note blocks. |
| I1/I5 D | ↓ | Vanilla outposts and mansions already cage iron golems and allays. |

## 9. Parked (to IDEAS.md)
T5 regional Tides · T9 Tide-synced music · S9 soul simulation · S10 echoes of the dead · H4 breathing sculk terrain · N6 echolocation · N7 composing · a clock that shows the Tide (needs an override of the vanilla clock model, a resource-pack conflict risk).
