# Content bible III: items, gear, food, advancements, audio, mechanics (WP-022)

Part of `../01_CONTENT_BIBLE.md`. Frozen vision: `../00_VISION.md` (§6 "never gives" list). Decisions: D-016.

Legend: Tier Core / Should / Could / Won't · **MS** = milestone · Links T S K N I Cr W (as in world.md) · every item names its **source → sink**.

## 1. Items and materials
| Item | Source → sink | Tier | MS | Links | Vanilla analog |
|---|---|---|---|---|---|
| **Ichor bucket** | Bucket an ichor source (in the Sift) → traps and moats inside the Sift. It evaporates if emptied elsewhere (rules.md) | **Core** | M1 | T S W | lava bucket |
| **Tidewrack frond** (material) | Gathered from tidewrack on tide flats, Thrive only → gear traits (the material), cyan dye, blub treats (breeding and healing) | **Core** | M2 | T S W Cr | kelp / sweet berries |
| **Endure petal** (material) | Endure blooms at the waterline, Endure only → lumen lanterns, gear traits | **Core** | M2 | T N W | torchflower seeds (a rare flora drop) |
| **Lumen lantern** | Crafted (Endure petals + hymnstone) → a light that repels the Sift's hunters (world.md §3) | **Core** | M2 | T Cr N | lantern; soul fire repelling piglins |
| **Soul block** (material) | Offering at a bloom heart (hold *use*; your XP), or looted from camps as **stolen soul blocks** → fuel for echo-golem work, musical gates, gear traits; the Singer's chorus stones; also a placeable decorative block | **Core** | M3 | S Cr I N | respawn-anchor glowstone charge |
| **Singer's horn** (the gift of song) | Granted by a Singer when its grove's harmony is restored (§1.1) → sings: opens musical gates, sparks growth in a radius, cures blight in a small radius, calms Sift natives. Holds 3 charges. Recharge: Thrive twice Flow's rate, none in Endure (D-016). Its **Sift effects** act only where `sift_life` is true. Elsewhere it plays as an instrument, like a goat horn, so it can open an awake frame (entry_path.md) | **Core** | M4 | N S T Cr K | goat horn (an instrument with a cooldown) |
| **Tide shell** | Crafted from tidewrack + hymnstone → shows the current Tide and its progress **in the Sift** (its model changes, like a clock). In other dimensions it spins. Needs a small client model property (a range dispatch on our Tide clock), since vanilla's `time` sources are only daytime, moon phase and random | **Should** | M5 | T W | clock (our own item, so the vanilla clock is never overridden) |
| **Trait templates** (Ichor Wading, Muffled Steps, Tide Sense) | Loot in camp chests (M4 structures) and the Monstrosity hollow; duplicated with hymnstone like smithing templates → applied at a smithing table with a Sift material | **Should** | M5 | S T N I | armour trim templates |
| **Songwood items** (sign, hanging sign; see world.md) | Songwood → building | Core (with the wood set) | M4 | W N | cherry wood items |
| **Blub spawn egg** (and one per later mob) | Creative / commands (26.3 registers one per mob) | Core | with each mob | Cr | every vanilla spawn egg |
| **Music disc "Tidesong"** | Monstrosity hollow loot → jukebox; plays our original track | **Could** | — | N | Pigstep / Otherside discs (a human asset brief is likely) |
| **Name-tag easter egg "Bubbles"** | Name a blub "Bubbles" → a special squeak | **Could** | — | Cr N | "jeb_" sheep |

### 1.1 The gift of song: the quest (canon shapes "Lost Harmonies: Find the stolen soul blocks", "Guardian of the Golems")
Vanilla has no quest log, so the quest is **a place that shows its own progress**, like an end portal frame filling with eyes.

1. **Find a grove.** A Singer's grove stands in the Meadow (a rare structure, several per world). Its Singer is silent and dim, and its three **chorus stones** are empty and dark. Playing music near the Singer makes it turn and hum one broken phrase, then fall silent. That shows it wants something musical.
2. **Recover the stolen harmonies.** Each chorus stone takes **one soul block** (hold *use*). There are two ways to get soul blocks:
   - **Fight:** raid Illager camps, whose loot chests hold one or two stolen soul blocks.
   - **Pay:** condense your own XP at a bloom heart.

   This is the decision: risk a camp, or pay in levels.
3. **Visible progress.** Each filled stone lights and chimes, and the Singer's phrase grows by one more bar (a subtitle for each: "Singer hums", "Singer sings"). The grove's healthy sculk sways further out.
4. **The song.** With all three stones filled, the next music a player plays near the Singer, in Thrive or Flow (it is silent in Endure), makes it sing the full song. Notes rise from the stones and the grove's blight is cured. The Singer then **grants a horn to each player within 16 blocks who hasn't received one from this grove**.

**Scope.**
- **Per grove, shared by the world:** the chorus stones stay filled, and the grove stays restored.
- **Per player:** one horn per grove. The grove's block entity keeps the set of rewarded players, the precedent of the trial chamber's vault (`rewarded_players`).
- A lost horn can be earned again at another grove.

**Why not a golem step:** "Guardian of the Golems" is served by freeing caged golems in the same camps. Making the quest require a freed golem would chain two AI systems for one reward (feasibility), so it isn't a step.

**Advancement:** "The Singer's Gift" (§4).

## 2. Gear traits (Should, M5)
Traits add **Sift-only utility**. They work only where `sift_life` is true, and never add damage, protection, mining speed or durability (00_VISION §6).

| Trait | Slot | Effect (in the Sift only) | Material |
|---|---|---|---|
| **Ichor Wading** | boots | No slowdown and no burning in ichor (the soul drain remains) | tidewrack |
| **Muffled Steps** | leggings | Your steps and landings aren't heard by Sift hunters (the hearing rule). Mining, building, projectiles and music are still heard, so staying quiet in Endure remains a choice about what you do, not only how you walk. It never affects wardens or sculk sensors, because it acts only in the Sift | Endure petal |
| **Tide Sense** | helmet | A soft chime and a particle shimmer 20 s before each Tide change (a non-colour, non-HUD cue) | soul block |

Check against the "never gives" list: no flight, no storage, nothing above netherite (utility only), no travel speed, no renewable diamonds or netherite, no XP creation, no power over wardens. **Pass.**

## 3. Tools, weapons, armour and companions
| Category | Decision | Tier | MS | Reason |
|---|---|---|---|---|
| **New tool or armour tiers** | None | **Won't** | — | 00_VISION §6: the Sift adds sidegrades and utility, never a tier above netherite |
| **Canon gear: Sift Sickles, Warding Chimes** (both "crafted from humbler husk", RESEARCH_BESTIARY) | **Defer** with the humbler husks | **Won't (1.0)** → **1.1** | — | Their material comes from the Carapace (1.1) |
| **Instruments** | The Singer's horn (§1) is the Sift's one new tool | Core | M4 | The vision's "sound tools" |
| **Companions** | **Blub** (a pet: befriended with music, follows and comes home; needs no fuel). **Echo golem** (a working companion: heals blight and tends bloom hearts while it carries a soul block; without one it only follows and dances) | Core | M1 (Blub), M4 (golem) | D-016: soul-block fuel applies to *work*, so only working companions need it |

## 4. Food
| Food | Source | Tier | MS | Note |
|---|---|---|---|---|
| **Lullberries** | Clusters on lullvines (songwood's hanging vines) | **Should** | M5 | 2 hunger, like sweet berries. Blubs like them |
| Tidewrack (raw) | Tide flats | **Could** | — | Edible in a pinch (1 hunger), like dried kelp |

## 5. Advancements (a tab "The Sift", in vanilla's voice)
Titles are our own. None copies Dungeons II's achievement names, so nothing implies an official status. **10 Core and 3 Should.**

| Advancement | Trigger | Tier | MS |
|---|---|---|---|
| **Where Souls Drift** (root) | Enter the Sift | **Core** | M1 |
| **An Offering** | Wake an Ancient City frame | **Core** | M1 |
| **The Tide Turns** | Be in the Sift when the Tide changes | **Core** | M1 |
| **Stacked** | See a tower of five blubs | **Should** | M2 |
| **Low Tide** | Gather tidewrack | **Core** | M2 |
| **Heard You** | Be heard by a Nester | **Core** | M2 |
| **Quiet Waters** | Spend a whole Endure in the Sift without being heard | **Should** | M2 |
| **Condensed** | Make a soul block | **Core** | M3 |
| **Broken Chains** | Free a caged echo golem | **Core** | M4 |
| **Rig Wrecker** | Break a harvester rig | **Core** | M4 |
| **The Singer's Gift** | Receive the Singer's horn | **Core** | M4 |
| **Mended Ground** | Cure 100 blight blocks with the Singer's horn (a custom statistic) | **Should** | M5 |
| **Heart of the Blight** (challenge) | Defeat the Sculk Monstrosity | **Core** | M6 |

## 6. Ambience, music and sound hooks
| Hook | What | Tier | MS | Route |
|---|---|---|---|---|
| Biome ambient loops and mood sounds | Meadow: wind through the songwood's flute holes, a distant hum. Hollows: drips and echoes | **Core** | M1 (Meadow), M2 (Hollows), M3 (Rise) | biome attributes `audio/ambient_sounds`; original sounds (§7.5) |
| Tide music | A track per biome in Thrive, Flow and Endure variants (canon OST pattern) | **Should** | M5 | TL / `audio/background_music`; likely a human asset brief |
| Creature sounds | Blub squeaks and hops, Nester gallop and crest flare, echo-golem hum, Singer phrases | **Core** (per creature) | with each creature | sound events + subtitles |
| Interaction sounds | Offering stream, frame steps, membrane, basin bubbling (M1); bloom-heart pulse, tide marks drying (M2–M3); blight shriek (M4) | **Core** | M1–M4 (as listed) | sound events + subtitles |
| Subtitles | For **every** Sift sound (P1) | **Core** | M1 on | lang |

## 7. Mechanics (system list; each gets a §8.3 system doc in its milestone)
| Mechanic | Where specified | Tier | MS |
|---|---|---|---|
| Tide clock and timeline; the scope gate `sift_life`; the `soul_flow` rate | systems.md §1, D-011/D-013 | **Core** | M1 |
| Ichor fluid (wade, burn, drain, Fire Resistance ruling, evaporation) | D-013 | **Core** | M1 (D-016) |
| Tide basins (controller, logical flats) | systems.md §1, D-013 | **Core** | M1 (D-016); tide marks M2 |
| Entry: frame detection, offering, awake stages, music listeners, membrane, first-crossing clock start | entry_path.md, D-010 | **Core** | M1 |
| Sift-side gate, arrival search, explicit links, sanctuary, portal filter | entry_path.md | **Core** | M1 |
| Weather mixin | D-008 | **Core** | M1 |
| Bed rest (Endure, `NOT_SAFE` check); bed and straw-bed rules | rules.md | **Core** | M1 |
| Hearing rule and hunter retreat | systems.md §4, D-011/D-013 | **Core** | M2 |
| Enduring variants | creatures.md §2 | **Core** | M2 |
| Lumen repelling hunters | world.md §3, D-016 | **Core** | M2 |
| Bloom hearts: drinking, offering, soul blocks, growth | systems.md §2 | **Core** | M3 |
| Blight: spread around rigs, cure, shriekers | systems.md §3, D-012 | **Core** | M4 |
| Camps: rigs, tanks, cages, pillager respawns | systems.md §5 | **Core** | M4 |
| Gift of song (quest, charges, effects) | §1.1, systems.md §4 | **Core** | M4 |
| Gear traits | §2 | **Should** | M5 |
| Musical gates (glyph keys, click-count notches) | systems.md §4 | **Should** | M6 |

## Self-critique
**WP-022, pass 1.**
- **Every item has a source and a sink.** The music disc's sink is the jukebox, and blub treats count as a sink for tidewrack.
- **Checked against the "never gives" list:** pass (§2).
- **The Tide shell** answers round 2's "clocks don't show the Tide" without touching the vanilla clock. It is Should, because the sky and basins already carry the Tide.
- **Removed:** a bone-meal-like "bloom dust". It would have been a growth accelerator that competes with Thrive's rate rule.

**WP-024, round-1 fixes (D-016).**
- The gift-of-song quest is specified (§1.1).
- The tools, armour and companion categories are explicit (§3).
- "Harmony Restored" was renamed "Mended Ground", so it no longer shares the quest's phrase.
- The horn's recharge ratio was aligned with the vision.
- Every row has a milestone.
