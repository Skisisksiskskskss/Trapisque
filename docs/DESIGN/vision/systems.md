# Core systems at concept level (WP-013; revised after WP-014 critique rounds 1–3)

Rubric columns: F faithful · V vanilla-native · R readable · M meaningful · D distinct · C connected · Fe feasible (1–5). Concepts were written before scoring; *italic* = deliberately unusual. Scores changed by a critique round are marked ↓/↑, with the reason in §8.

**One-line model:** *souls are the fuel, music is the spark, the Tide is the season, and ichor is the tide.*

## 1. The Tides
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| T1 | Day-like cycle on one global clock: Thrive → Flow → Endure → Flow | 5 | 5 | 5 | 3↓ | 3↓ | 5 | 5 | 31 |
| T1′ | T1 plus one signature rule per Tide (growth / tide-bridges for passage / hunters) | 4↓ | 4 | 4 | 3↓ | 3↓ | 5 | 4 | 27 (round 2: bridges can be bypassed with blocks, and Flow contradicted "no effect") |
| **T1″** | **The tide is literal:** ichor rises and falls in the Sift's tide basins. Thrive is low tide, Flow is the tide moving, Endure is high tide. Each state changes what is exposed, what grows and who is hunting | 4 | 4 | 5 | 4 | 5 | 5 | 4 | **31** |
| T2 | Three equal thirds (Thrive → Flow → Endure) | 5 | 4 | 4 | 4 | 4 | 5 | 5 | 31 |
| T3 | Player lever: a costly act shifts the Tide for everyone, as sleeping skips the night | 4 | 5 | 4 | 4 | 4 | 4 | 5 | 30 |
| T4 | One Tide per in-game day (long cycle) | 4 | 4 | 3 | 3 | 3 | 4 | 5 | 26 |
| T5 | Regional Tides sweeping across the map | 3 | 2 | 3 | 4 | 5 | 4 | 2 | 23 |
| T6 | Random, weather-like Tides | 3 | 4 | 2 | 3 | 3 | 4 | 5 | 24 |
| T7 | Soul-driven: deaths push the cycle toward Endure | 3 | 3 | 2 | 4 | 5 | 5 | 4 | 26 |
| T8 | Occupation pressure: Illager draining lengthens Endure | 4 | 3 | 2 | 4 | 5 | 5 | 4 | 27 |
| T9 | *The Tide is a song in three movements; discs and music sync to it* | 4 | 3 | 3 | 3 | 5 | 4 | 3 | 25 |
| T10 | *Personal Tides per player* | 2 | 1 | 2 | 3 | 5 | 3 | 1 | 17 |

**Pick: T1″ (T3 stays a post-1.0 lever).**
- **Cycle:** one `thesift:tides` world clock with a **30 000-tick period (25 minutes)**, deliberately not the Overworld's 24 000. Canon doesn't give the order (RESEARCH §3); this order is our choice.

  | Tide | Ticks | Length |
  |---|---|---|
  | Thrive (low tide) | 0–12 000 | 10 min |
  | Flow (rising) | 12 000–15 000 | 2.5 min |
  | Endure (high tide) | 15 000–27 000 | 10 min |
  | Flow (falling) | 27 000–30 000 | 2.5 min |
- **The tide is ichor.** Canon: the Meadow has "many pools of ichor, fracturing the terrain"; the Tides "affect … traversing" (RESEARCH §2, canon #8).
  - Generated **tide basins** (sunken flats up to ~14×14 blocks and ~4 deep, each inside one chunk) fill with ichor at high tide and drain at low tide.
  - That makes the Tide visible from anywhere a basin can be seen, and it changes the land itself.
  - **The tide is a logical state, not only a physical one.** Each basin's flats follow the current Tide, whatever the physical water does. So a cofferdam, a sand fill or an emptied bucket doesn't keep tidewrack open in Endure.
  - Ordinary ichor pools elsewhere don't move.
- **What each Tide changes.** These translate canon's effects (RESEARCH canon #7).
  - **Thrive: low tide, growth.** Canon: "Faster Soul regeneration and artifact cooldowns".
    - The basins lie bare as **tide flats**. Flat-only reagents (tidewrack: working name) open and can be gathered only now. In every other Tide they are closed and drop nothing, even if a player keeps the ichor out.
    - Healthy sculk turns stored souls into growth, and the gift of song recharges twice as fast.
    - Natives roam; blubs gather to music (§4).
  - **Flow: the tide moves.** Canon: "Flow: No effect". Flow has **no effect on the player** (no buff, no debuff).
    - The ichor visibly rises or falls, one layer at a time.
    - Rising Flow: the waterline creeps up with bubbles, and the membrane's particles drift upward.
    - Falling Flow: the ichor ebbs and leaves wet **tide marks** on basin walls, which dry over Thrive, and the membrane's particles drift down.
    - There are no currents, so nothing pushes the player (canon: "Flow: No effect").
    - **At falling Flow the hunters retreat** (below).
    - Natives migrate with the waterline.
    - It is the Tide you *watch*.
  - **Endure: high tide, hunters.** Canon: "More powerful mobs will spawn and your passive soul regeneration will stop".
    - The basins are flooded, and anyone who isn't native burns in ichor.
    - The sky darkens, so light-gated hostiles surface. Some are **enduring** variants, marked by a larger crest and trailing soul particles as well as a glow.
    - The stars wheel across the sky over the course of Endure, which shows how much of it is left.
    - **The hunters listen** (the hearing rule, §4). Growth pauses and the gift of song stops recharging. Everything else keeps working: bloom hearts, cures, the song itself and gear traits.
    - **Endure blooms** open along the waterline, and their reagents can be taken only then.
- **The hunters retreat, so Thrive is safe.** Vanilla's daylight burning doesn't exist here (`gameplay/monsters_burn` is off, and our mobs don't burn anyway). Mobs also despawn only far from players (`Mob.checkDespawn`). So the retreat is our own rule, and it is telegraphed:
  - During falling Flow, surface hostiles (Nesters, enduring variants and the other Sift hostiles) stop, turn toward the nearest healthy-sculk mound, and **burrow**: a visible dig animation, particles, a sound and a subtitle, as the warden digs.
  - They are gone by the start of Thrive. A hunter already fighting keeps fighting until its target is 16 blocks away, then burrows. *(Capped by D-023: a sweep at Thrive's first tick takes any hunter still fighting, so Thrive stays safe.)*
  - Hostiles in dark caves stay, as vanilla monsters do.
  - Outside Endure, Nesters never spawn on the surface (light), and none linger.
- **First arrival is in Thrive.**
  - The clock is **paused at Thrive until the first player crosses** into the Sift. It starts then.
  - World clocks default to unpaused (`ServerClockManager`), so this needs a line of startup code, not just data.
  - After that, the membrane shows the far-side Tide: bright cyan for Thrive, amber for Flow, violet for Endure, each with its own particle shape. Every gate has a sanctuary.
- **How players read it:**
  - the waterline (the clearest cue);
  - sky and fog colour; stars in Endure; soul motes;
  - Tide music variants (canon: OST);
  - native behaviour; Endure blooms opening.
  - An **inverted daylight detector** senses Endure's darkness, which makes it a vanilla-native redstone Tide sensor (rules.md).
  - Clocks spin, as in the Nether and End.
- **The lever (T3):** after 1.0. It moves the clock **only toward Thrive**, with sleep-style consent. Beds never skip the Tide.
- **Admins and gamerules:**
  - `/time set thesift:thrive` works in the Sift; `/time set day` doesn't (the markers are `thesift:*`).
  - `advance_time false` freezes every world clock, the Tides included, just as it freezes the sun. Endure-only reagents then need an admin's `/time`, as night-only things do in the Overworld.
  - `random_tick_speed 0` freezes growth, as it freezes crops.
  - All of this is documented; no code overrides the gamerules.
- **Feasibility (26.3):**
  - Clock, timeline, markers, sky, light, stars, particles and music are data (VANILLA_ANALOGS W4, spike-verified). Gameplay values are our own registered environment attributes:
    - **`thesift:gameplay/sift_life`**: a boolean, true in the Sift in every Tide and false everywhere else. It is the **scope gate**: whether bloom hearts drink, cures work, the gift of song and gear traits act, and growth is possible at all.
    - **`thesift:gameplay/soul_flow`**: a **rate only** (Thrive 1.0, Flow 0.25, Endure 0.0). It sets how fast growth expresses and how fast the gift of song recharges. It never switches a feature off.
    - `thesift:gameplay/tide`: the current Tide, which tidewrack, hunters and basins read.
  - **Tide basins** are a bounded world-generation feature with one controller block entity each.
    - During Flow, the controller raises or lowers the ichor one layer at a time. It works only while its chunk is loaded, and it snaps to the current Tide's level when the chunk loads.
    - The basin's ichor never spreads beyond the basin volume.
    - The cost is roughly a few thousand block changes per basin, spread over 3 000 ticks.
  - Slow organic changes (blooms, tidewrack opening) use random ticks, as eyeblossoms do.

## 2. The soul economy: a one-way ledger
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| S1 | **Souls are experience in physical form**: no new currency; Sift sinks and sources work in XP (vanilla's catalyst precedent) | 4 | 5 | 5 | 4 | 4 | 5 | 5 | **32** |
| S2 | Soul-mote items dropped by mobs, used like blaze powder | 3 | 4 | 4 | 3 | 3 | 4 | 5 | 26 |
| S3 | **Soul blocks**: condensed souls that power golems and devices (in the game per canon; their lore is novel-sourced) | 4 | 4 | 4 | 4 | 5 | 5 | 4 | **30** |
| S4 | Healthy sculk as a soul **bank** that song draws back out | — | — | — | — | — | — | — | **rejected** (XP amplifier loop, round 1) |
| S4′ | **Bloom hearts drink deaths like a catalyst and turn them into growth, never back into XP** | 4 | 5 | 4 | 4 | 4 | 5 | 5 | **31** |
| S5 | A Dungeons-style soul meter on the HUD | 4 | 1 | 4 | 3 | 2 | 3 | 4 | 21 |
| S6 | Soul-powered gear with active abilities (the artifact translation) | 4 | 3 | 4 | 4 | 3 | 4 | 4 | 26 |
| S7 | Trading souls to natives for songs or items | 4 | 4 | 4 | 3 | 3 | 4 | 4 | 26 |
| S8 | **Illager soul tanks**: they hold the souls a camp drains; breaking one returns them to the land | 5 | 4 | 5 | 4 | 4 | 5 | 4 | **31** |
| S9 | *Per-chunk soul level simulation* | 4 | 2 | 2 | 4 | 5 | 5 | 2 | 24 |
| S10 | *Echoes of the dead fight beside you* | 2 | 2 | 3 | 3 | 5 | 3 | 3 | 21 |

**Pick: S1 + S3 + S4′ + S8, as a one-way ledger.** S6 is parked for Phase 2 gear design; S5 is rejected (no new HUD meters).
- **Souls enter two ways:**
  1. **Deaths near a bloom heart.** A bloom heart is the healthy counterpart of the vanilla catalyst (working name). It takes a nearby death's experience **as a vanilla catalyst does** (same event, same radius, and that XP never drops), with two differences: it works only where `sift_life` is true (in every Tide), and it **ignores player deaths**. A bloom heart carried home is decorative and never takes XP there.
  2. **Offering, a deliberate action.**
     - **Hold *use*** on a bloom heart, or on a dormant Ancient City frame, with an empty hand. Your XP visibly streams into it, like brushing suspicious sand. Release and it stops.
     - Rate: about 50 points per second (tuned in BALANCE).
     - Nothing is ever taken from posture, proximity or accident. The one exception is a hazard you walk into and can see: ichor drains XP from outsiders standing in it.
- **Souls leave three ways.** Nothing converts back into XP.
  - **Growth.** A bloom heart's charge spreads as blooms, light and **common** Sift materials, at a rate set by `soul_flow`: fast in Thrive, slow in Flow, paused in Endure (the charge waits), and none outside the Sift.
    - Thrive raises the **rate**, never the **yield**.
    - Growth never produces tide-flat reagents or Endure blooms; those come only from the flats and the waterline, so an XP farm can't bypass the Tides.
    - Healthy sculk and its products never drop experience, and no Sift item gives smelting XP.
  - **Soul blocks.** An offering at a bloom heart condenses your XP into a **soul block**: **fuel, not a bank.** It powers an echo golem's work, a musical gate or a Sift gear trait, and it can't be turned back into XP.
  - **A frame's price** (entry_path.md), paid once.
- **Hazards take souls.** Ichor drains XP from outsiders standing in it, alongside the soul fire (canon: ichor "drains their souls"). The soul fire and hissing steam come first, so the danger shows before any XP is lost.
- **Illager soul tanks (S8)** fill as a camp drains the land (§5). Breaking one returns its souls to the surrounding sculk as growth, which cures blight. It never pays a player XP. Tanks are finite; a broken tank doesn't refill.
- **Why this holds** (the round-1 probe a):
  - No Sift path creates experience.
  - Automatic kill chambers can feed a bloom heart's *growth*, exactly as they feed vanilla catalysts, but growth yields materials, not XP.
  - Only XP from **deaths** near a bloom heart is intercepted, as with a catalyst. XP from mining, smelting, breeding or trading is untouched, and so is Mending.
  - Soul blocks can't store XP past death.
  - Blight is XP-free (§3).

## 3. Healthy vs corrupted sculk
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| H1 | **Inversion**: healthy sculk is colourful and listens to *reward*; corrupted sculk listens to *punish* | 5 | 5 | 5 | 4 | 5 | 5 | 4 | **33** |
| H2 | **Blight**: where Illagers drain souls, healthy sculk sickens; returning souls or song cures it | 5 | 4 | 5 | 5 | 4 | 5 | 4 | **32** |
| H3 | Cure the Overworld's Deep Dark with Sift sculk | 4 | 3 | 4 | 4 | 4 | 4 | 3 | 26 |
| H4 | Sculk terrain that grows in Thrive and recedes in Endure | 3 | 3 | 4 | 3 | 4 | 4 | 2 | 23 |
| H5 | Quarantine: corrupted sculk carried in infects healthy sculk | 4 | 3 | 3 | 3 | 4 | 4 | 3 | 24 |
| H6 | *Healthy sculk as the Sift's nerves: breaking it alarms natives* | 3 | 3 | 3 | 3 | 5 | 4 | 3 | 24 |

**Pick: H1 + H2.**
- **Blight is its own block family, and it drops no XP.** Round 2 found that using vanilla sculk leaked XP: mined sculk drops 1–5, and every vanilla catalyst would have made a blight patch a sculk farm.
  - Blight copies the Deep Dark's **grammar**:
    - a pulsing animated texture;
    - veins that creep;
    - tendril sensors that wiggle when they hear;
    - shriekers.
  - Healthy sculk is petalled and grassy and **never pulses**. So the two differ in shape and motion, not only in colour.
  - Every blight block drops itself or nothing, never XP.
- **Blight shriekers** shriek like vanilla ones, give Darkness and alert nearby hunters. They **never touch the vanilla warden warning tracker**, so nothing follows players home.
  - Vanilla sculk that players bring and place behaves exactly as vanilla, wherever it is. (Checked: player-placed vanilla shriekers can't summon and never raise warnings.)
- **The Illagers speed the disease up; they didn't start it.** Canon says the disease "originated in the Sift" from "an unknown factor", and it is ancient. Illager rigs drain souls, which weakens healthy sculk and lets blight take hold.
  - Blight doesn't breed hunters. Hunters are native: part of the "independent ecosystem" (XW2).
- **Blight is dynamic, but bounded:**
  - It spreads only around **active** camps: within a fixed radius of the camp's rig, up to a cap, slowly.
  - It stops when the rig is broken.
  - Cured land stays cured, because no new camps appear.
- **Curing needs the Sift.** Returning souls (a broken tank, or growth from a bloom heart), the gift of song, or freed echo golems (§5) turn blight back into healthy sculk. Cures work only where `sift_life` is true (in every Tide), which means **never in the Overworld's Deep Dark**. Growth-based curing follows the growth rate. H3 stays parked.

## 4. Sound as a mechanic
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| N1 | **Healthy sculk answers music** (note blocks, jukeboxes, goat horns): growth expresses faster, blooms open, light rises | 5 | 5 | 4 | 4 | 5 | 5 | 4 | **32** |
| N2 | Natives answer music: echo golems dance (wiki gallery: "Echo golems dancing in front of the Deep Dark portal") | 5 | 5 | 5 | 3 | 3↓ | 4 | 4 | 29 |
| **N2′** | N2, plus **blubs gather and stack into teetering towers** that topple over (Kotaku's "blue bunnies … form teetering towers that occasionally topple over"; that these are Blubs is our reading, RESEARCH §9). A stack also makes a live platform to reach high blooms | 5 | 5 | 5 | 4 | 5 | 4 | 4 | **32** |
| N3 | **The Singer's gift of song** (canon achievement "Receive the Singer's gift of song"): an earned instrument that opens gates, sparks growth in a radius and calms Sift natives | 5 | 4 | 4 | 5 | 5 | 5 | 4 | **32** |
| N4 | **Musical gates** (canon "Musical Gate"): structure doors keyed to an instrument and note | 5 | 4 | 3 | 4 | 4 | 4 | 4 | 28 |
| N5 | Sonic threats: screeching bosses, stunning plants (canon Harmonizer, "hazardous blocks") | 5 | 4 | 4 | 4 | 3 | 4 | 4 | 28 |
| N6 | *Echolocation pings reveal paths* | 3 | 3 | 2 | 3 | 5 | 3 | 3 | 22 |
| N7 | *Composing Tide-synced melodies on terrain* | 3 | 2 | 2 | 3 | 5 | 4 | 2 | 21 |
| N8 | **The hearing rule**: in Endure, the hunters listen (the Deep Dark's rule returns at night) | 4 | 5 | 4 | 5 | 4 | 5 | 4 | **31** |

**Pick: N1 + N2′ + N3 + N8, with N4/N5 as content.**
- **Music is a spark, not a source.** It makes existing charge express faster as growth and light, and it never creates growth from nothing.
- **The hearing rule (N8)**, one definition everywhere:
  - **Who listens:** each area's hunter species, **only in Endure**. In 1.0 that is the **Nester** in Singer's Meadow (canon: it will "rapidly gallop towards heroes, lunging and biting"). The Carapace's sculkers come after 1.0 (§7).
  - **What they hear:** the vibrations a sculk sensor hears, at a warden's range.
    - The vanilla `#vibrations` game events within **16 blocks** of the hunter (a sculk sensor hears 8; a warden hears 16): steps, block changes, projectiles, note blocks (`note_block_play`), goat horns (`instrument_play`) and more. Sneaking suppresses steps as vanilla does, and wool muffles.
    - **Jukeboxes**, heard through a separate listener at vanilla's radius of 10. `jukebox_play` isn't a vibration; this is how allays hear music (checked).
  - **The tell:** the vanilla vibration particle flies from the sound to the hunter, as it does to a sensor. The hunter turns, and its crest flares. Then it gallops to the source. Every cue is visual, audible and subtitled.
  - **The consequence:** a noisy base in the Meadow draws Nesters only within their hearing range. Players dampen it the vanilla way.
  - In Thrive, the hunters are gone (they retreat at falling Flow, §1), and **the Sift answers music instead**. That gives the choice: sing in Thrive; stay quiet, or use sound as a lure, in Endure.
- **Gift of song (N3):**
  - **Earned** from the **Singer** after the player restores the Meadow's stolen harmony. The route follows canon quest shapes: "Lost Harmonies: Find the stolen soul blocks", "Guardian of the Golems". Exact steps are Phase 2.
  - **Charges:** it refills twice as fast in Thrive and not at all in Endure.
  - **Scope:** it affects only Sift life (healthy sculk, blight, natives, gates), and only where `sift_life` is true. It works in every Tide, including Endure, where it doesn't recharge. It never affects wardens or Overworld sculk.
  - **At home**, Sift blocks and companions still *react* to any music, as decoration only: healthy sculk lights and sways, blubs dance and stack. Nothing grows, spreads, cures or takes XP there.
- **Music detection** at frames, bloom hearts and gates uses the same pair of listeners: a vibration listener for note blocks and goat horns, plus the jukebox listener.
- **Accessibility (P1):** every Sift sound has a **subtitle** and a **visual**.
  - A musical gate shows its key as a **carved instrument glyph** (the note block's base block, for example gold for bells) plus **carved notches that count the clicks** (0–24) needed to tune a note block to that pitch. It plays the note and shows a subtitle, so the key can be read without hearing or colour.
  - No step depends on colour alone, or on sound alone.

## 5. The Illager occupation
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| I1 | Soul-harvester camps: rigs over blight, caged echo golems, soul tanks, patrols by day-Tides | 5 | 5 | 5 | 4 | 3↓ | 5 | 4 | 31 |
| **I1′** | **Living occupation**: each active camp's rig drains the land. Blight visibly spreads in a capped radius while its tanks fill; breaking the rig stops it; breaking the tanks heals it | 5 | 4 | 5 | 5 | 4 | 5 | 4 | **32** |
| I2 | **The Illager Keep** (canon track "Illager Keep"): endgame stronghold, rift hub, a High Council lieutenant | 5 | 4 | 4 | 4 | 4 | 4 | 3 | 28 |
| I3 | Rift incursions into the Overworld | 5 | 3 | 4 | 4 | 4 | 4 | 2 | 26 |
| I4 | Occupation meter per region | 3 | 3 | 3 | 3 | 3 | 4 | 3 | 22 |
| I5 | Freeing natives: caged golems become allies when freed (canon "Guardian of the Golems", track "Caged") | 5 | 4 | 5 | 4 | 3↓ | 5 | 4 | 30 |
| **I5′** | I5, plus **freed echo golems are restorers**: carrying a soul block, a golem slowly heals blight around it and tends bloom hearts | 5 | 4 | 5 | 5 | 4 | 5 | 4 | **32** |
| I6 | *Endure's hunters against the camps; players can steer the war with sound* | 4 | 4 | 4 | 5 | 5 | 5 | 3 | **30** |

**Pick: I1′ + I5′ + I6 for 1.0.** I2 (the Keep) and I3 (rifts) come after 1.0 (§7).
- **Camps are finite** (generated structures); no new camps appear.
- A camp is *active* while its rig stands. While it's active, blight spreads around it and its tanks fill. That gives the occupation urgency and a visible cost, unlike static outposts.
- Like vanilla pillager outposts, a camp's grounds keep spawning **pillagers only** (the structure-spawn precedent), so camps stay dangerous. Vindicators appear only in a camp's first garrison, and there are no evokers, so camps are no renewable source of emeralds or totems and no richer an XP source than outposts.
- Hunters attack illagers as readily as players. A player can lure Endure's Nesters into a camp with a goat horn or a jukebox (I6).
- Illagers reuse vanilla illager types; new kinds appear only where a role is missing.

## 6. How the systems feed each other
```
            ┌──────────── TIDES (clock + timeline) ────────────┐
   ichor level │   soul_flow (growth rate) │   light / hunters  │ camp patrols
               ▼                           ▼                    ▼
   TIDE FLATS (low-tide reagents)   HEALTHY SCULK ◄─ spark ─ SOUND ─ Endure ─► HUNTERS (Nesters)
                                        ▲  growth                   lure │  attack camps (I6)
      DEATHS ──► BLOOM HEARTS ──────────┘                                ▼
      OFFERINGS (your XP) ──► BLOOM HEARTS ──► SOUL BLOCKS ──► ECHO GOLEMS / GATES / TRAITS
                                                                 │ restorers heal
   ILLAGER CAMPS ── rigs drain ──► BLIGHT (own blocks, no XP) ◄───┘
        └── tanks ── broken ──► souls return as growth ──► cures blight
```
Every system touches at least three others. No arrow leads back to experience.

## 7. Scope for 1.0 vs later ("fewer, deeper")
**1.0 is one region done deeply: Singer's Meadow**, with Lullaby Hills as a sub-biome and the tide basins. Vanilla precedent: the Nether and the End each shipped as one biome at first. Every item is tiered; Phase 2 (the content bible) may move items down a tier, never up without a reason.

| Tier | Contents |
|---|---|
| **Must** | the dimension, the Tide clock, timeline and hunter retreat; tide basins and ichor; the entry frame, gate and return; healthy sculk, blight and bloom hearts; soul blocks; the gift of song and the **Singer**; natives **Blub** and **Echo Golem**; hostiles **Nester** (the listener) and **Bloombud**; Illager camps (rigs, tanks, caged golems); **one boss, the Sculk Monstrosity** |
| **Should** | Pollinator and Sprout; the Slabber; the **Harmonizer** miniboss (with its Seedlings); musical gates; gear traits; Tide versions of the area music |
| **Could** | blub towers as platforms; home-decoration reactions; Trills as particles; a large building palette beyond the core sets |

- **The boss.** The Sculk Monstrosity sits behind a musical gate. A guide puts a Musical Gate on its questline, leading to Humbler Huskland [RESEARCH §2, P-SK3]. Its canon "catalysis" attack is rebuilt on our blight blocks. Calling it "the heart of the blight", and having its defeat cure the land around its arena, is our design, not canon.
- **After 1.0 (roadmap):**
  - **1.1:** the Carapace, with its sculkers (Stalker, Scavenger) as that area's listening hunters, and the **Monarch**.
  - The Illager Keep; rifts (I3); the Tide lever (T3).
  - An aurora sky: it needs a client mixin, because 26.3 Fabric API has no per-dimension sky hook.
  - More areas from the soundtrack's names.

## 8. Critique rounds: score changes
| Score | Change | Reason |
|---|---|---|
| T1 M/D | ↓ (round 1) | Alone it is day/night with a new palette. |
| T1′ | ↓ (round 2) | Tide-bridges could be bypassed with blocks, and Flow's bespoke rules contradicted canon "Flow: No effect". Replaced by T1″. |
| S3 F | ↓ then restored to 4 (round 2) | Soul blocks *are* in the game (research round 2). Only their lore and the Singer claim are L. |
| S4 | rejected (round 1) | An XP amplifier and battery. |
| N2 D | ↓ (round 1) | Allays already dance to note blocks. N2′ adds blub towers (canon, distinct). |
| I1/I5 D | ↓ (round 1) | Vanilla outposts cage golems. I1′/I5′ make the occupation change the land and make freed golems restorers. |

## 9. Parked (to IDEAS.md)
T5 regional Tides · T9 Tide-synced music · S9 soul simulation · S10 echoes of the dead · H4 breathing sculk terrain · N6 echolocation · N7 composing · a clock that shows the Tide (needs an override of the vanilla clock model, a resource-pack conflict risk) · tide-bridges and bounce blooms as Tide rules (cut in round 2; bounce blooms may return as static terrain).
