# Content bible III: items, gear, food, advancements, audio, mechanics (WP-022)

Part of `../01_CONTENT_BIBLE.md`. Frozen vision: `../00_VISION.md` (§6 "never gives" list).

Legend: Tier Core / Should / Could / Won't · Links T S K N I W · every item names its **source → sink**.

## 1. Items and materials
| Item | Source → sink | Tier | Links | Vanilla analog |
|---|---|---|---|---|
| **Soul block** | Offering at a bloom heart (hold *use*; your XP) → fuel for echo-golem work, musical gates, gear traits; also a placeable decorative block | **Core** | S Cr I N | respawn-anchor glowstone charge |
| **Tidewrack frond** | Gathered from tidewrack on tide flats, Thrive only → gear traits (the material), cyan dye, blub treat | **Core** | T S W | kelp / sweet berries |
| **Endure petal** | Endure blooms at the waterline, Endure only → lumen lanterns, gear traits, the Singer's quest | **Core** | T N | torchflower seeds (a rare flora drop) |
| **Ichor bucket** | Bucket an ichor source (in the Sift) → traps and moats inside the Sift. It evaporates if emptied elsewhere (rules.md) | **Core** | T S W | lava bucket |
| **Singer's horn** (the gift of song) | Granted by the Singer when the Meadow's harmony is restored (quest) → sings: opens musical gates, sparks growth in a radius, calms Sift natives. It holds 3 charges; recharge is ×2 in Thrive and 0 in Endure. It acts only in the Sift | **Core** | N S T Cr K | goat horn (an instrument with a cooldown) |
| **Tide shell** | Crafted from tidewrack + hymnstone → shows the current Tide and its progress **in the Sift** (its model changes, like a clock). In other dimensions it spins | **Should** | T | clock (our own item, so the vanilla clock is never overridden) |
| **Trait templates** (Ichor Wading, Muffled Steps, Tide Sense) | Loot in camps and the Monstrosity hollow; duplicated with hymnstone like smithing templates → applied at a smithing table with a Sift material | **Should** | S T N I | armour trim templates |
| **Lumen lantern** | Crafted (Endure petals + hymnstone) → one of the Sift's few real light sources | **Core** | T | lantern |
| **Songwood items** (sign, hanging sign; see world.md) | Songwood → building | Core (with the wood set) | W N | cherry wood items |
| **Music disc "Tidesong"** | Monstrosity hollow loot → jukebox; plays our original track | **Could** | N | Pigstep / Otherside discs (a human asset brief is likely) |
| **Name-tag easter egg "Bubbles"** | Name a blub "Bubbles" → a special squeak | Could | — | "jeb_" sheep |

## 2. Gear traits (Should)
Traits add **Sift-only utility**. They work only where `sift_life` is true, and never add damage, protection, mining speed or durability (00_VISION §6).

| Trait | Slot | Effect (in the Sift only) | Material |
|---|---|---|---|
| **Ichor Wading** | boots | No slowdown and no burning in ichor (the soul drain remains) | tidewrack |
| **Muffled Steps** | leggings | Your steps and landings aren't heard by Sift hunters (the hearing rule). It never affects wardens or sculk sensors, because it acts only in the Sift | Endure petal |
| **Tide Sense** | helmet | A soft chime and a particle shimmer 20 s before each Tide change (a non-colour, non-HUD cue) | soul block |

Check against the "never gives" list: no flight, no storage, nothing above netherite (utility only), no travel speed, no renewable diamonds or netherite, no XP creation, no power over wardens. **Pass.**

## 3. Food
| Food | Source | Tier | Note |
|---|---|---|---|
| **Lullberries** | Clusters on lullvines (songwood's hanging vines) | **Should** | 2 hunger, like sweet berries. Blubs like them |
| Tidewrack (raw) | Tide flats | Could | Edible in a pinch (1 hunger), like dried kelp |

## 4. Advancements (a tab "The Sift", in vanilla's voice)
Titles are our own. None copies Dungeons II's achievement names, so nothing implies an official status.

| Advancement | Trigger | Tier | Milestone |
|---|---|---|---|
| **Where Souls Drift** (root) | Enter the Sift | **Core** | M1 |
| **An Offering** | Wake an Ancient City frame | **Core** | M1 |
| **The Tide Turns** | Be in the Sift when the Tide changes | **Core** | M1 |
| **Low Tide** | Gather tidewrack | Core | M2 |
| **Heard You** | Be heard by a Nester | Core | M2 |
| **Quiet Waters** | Spend a whole Endure in the Sift without being heard | Should | M2 |
| **Stacked** | See a tower of five blubs | Should | M4 |
| **Broken Chains** | Free a caged echo golem | Core | M3 |
| **Rig Wrecker** | Break a harvester rig | Core | M3 |
| **The Singer's Gift** | Receive the Singer's horn | Core | M3 |
| **Harmony Restored** | Cure 100 blight blocks | Should | M4 |
| **Heart of the Blight** (challenge) | Defeat the Sculk Monstrosity | Core | M5 |
| **Condensed** | Make a soul block | Core | M2 |

## 5. Ambience, music and sound hooks
| Hook | What | Tier | Route |
|---|---|---|---|
| Biome ambient loops and mood sounds | Meadow wind through songwood, a distant hum; Hollows drips and echoes | **Core** | biome attributes `audio/ambient_sounds`; original sounds (§7.5) |
| Tide music | A track per biome in Thrive, Flow and Endure variants (canon OST pattern) | **Should** | TL / `audio/background_music`; likely a human asset brief |
| Creature sounds | Blub squeaks and bounces, Nester gallop and ear-flare, echo-golem hum, Singer phrases | **Core** (per creature) | sound events + subtitles |
| Interaction sounds | Offering stream, frame steps, membrane, bloom-heart pulse, blight shriek, basin bubbling, tide marks drying | **Core** | sound events + subtitles |
| Subtitles | For **every** Sift sound (P1) | **Core** | lang |

## 6. Mechanics (system list; each has or gets a system doc)
| Mechanic | Where specified | Tier | Milestone |
|---|---|---|---|
| Tide clock and timeline; the scope gate `sift_life`; the `soul_flow` rate | systems.md §1, D-011/D-013 | **Core** | M1 |
| Tide basins (controller, logical flats, tide marks) | systems.md §1, D-013 | **Core** | M2 |
| Hearing rule and hunter retreat | systems.md §4, D-011/D-013 | **Core** | M2 |
| Entry: frame detection, offering, awake stages, music listeners, membrane, first-crossing clock start | entry_path.md, D-010 | **Core** | M1 |
| Sift-side gate, arrival search, explicit links, sanctuary, portal filter | entry_path.md | **Core** | M1 |
| Weather mixin | D-008 | **Core** | M1 |
| Bed rest (Endure, `NOT_SAFE` check); bed and straw-bed rules | rules.md | **Core** | M1 |
| Ichor fluid (wade, burn, drain, Fire Resistance ruling, evaporation) | D-013 | **Core** | M2 |
| Bloom hearts: drinking, offering, soul blocks, growth | systems.md §2 | **Core** | M2 |
| Blight: spread around rigs, cure, shriekers | systems.md §3, D-012 | **Core** | M3 |
| Camps: rigs, tanks, cages, pillager respawns | systems.md §5 | **Core** | M3 |
| Gift of song (charges, effects) | systems.md §4 | **Core** | M3 |
| Musical gates (glyph keys, click-count notches) | systems.md §4 | **Should** | M5 |
| Enduring variants | creatures.md §2 | **Core** | M2 |
| Gear traits | §2 | **Should** | M4 |

## Self-critique (WP-022, pass 1)
- **Every item has a source and a sink.** The music disc's sink is the jukebox, and blub treats count as a sink for tidewrack.
- **Checked against the "never gives" list:** pass (§2).
- **The Tide shell** answers round 2's "clocks don't show the Tide" without touching the vanilla clock. It is Should, because the sky and basins already carry the Tide.
- **Removed:** a bone-meal-like "bloom dust". It would have been a growth accelerator that competes with Thrive's rate rule.
