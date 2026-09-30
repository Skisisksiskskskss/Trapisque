# Content bible I: the world (WP-020)

Part of `../01_CONTENT_BIBLE.md`. Frozen vision: `../00_VISION.md`.

**Legend.**
- **Tier:** **Core** (in 1.0) · **Should** · **Could** · **Won't** (with a reason; later milestones are named).
- **Source:** **C** = canon-grounded (RESEARCH ids) · **V** = the vanilla first look (the top visual authority, D-002) · **I** = our invention.
- **Links:** the Sift systems each entry touches: Tides (T), souls (S), sculk (K), sound (N), Illagers (I), creatures (Cr).
- **Route:** DATA = datapack JSON produced by datagen · CODE = Java.
- **Names** are working names, all original. None copies a fan mod's names (RESEARCH §8).

## 1. Areas and biomes
1.0 is one region, **Singer's Meadow** (D-009), built from a few biomes so the terrain has variety. Following vanilla precedent, one "area" can be several biomes (the Nether's first release had one; today it has five).

| Biome (id) | What it is | Tier | Source | Links | Vanilla analog · route |
|---|---|---|---|---|---|
| **Singer's Meadow** (`thesift:singers_meadow`) | Rolling hills of coral-orange healthy-sculk grass under a teal sky, with pale songwood groves. Ichor pools fracture the ground, and tide basins sit in the lows. Home of the Singer, blubs and echo golems | **Core** | C (RESEARCH §2: "red sculk, teal grass, and blue trees"; "many pools of ichor, fracturing the terrain") + V (coral grass, teal sky, pale trees, Blub) | T S K N I Cr | meadow / cherry grove · DATA: biome JSON with attributes, features and spawns |
| **Hymnstone Rise** (`thesift:hymnstone_rise`) | Steep cliffs and canyon walls of red hymnstone that bound the meadow, with overhangs, vine curtains and cave mouths | **Core** | C ("bounded by 'walls of darker red sculk'"; Dungeons II palette 1 "rose/crimson stone") | K N Cr | stony peaks / badlands walls · DATA |
| **Sift Hollows** (`thesift:sift_hollows`) | The cave layer beneath the meadow: hymnstone caverns, glowcap pools, dark (so hostiles spawn), blight seams near camps | **Core** | I (canon has "caves and forgotten ruins", MC3, but not for the Sift) | T K N Cr | dripstone caves / lush caves · DATA (underground multi-noise) |
| **Lullaby Hills** (`thesift:lullaby_hills`) | Taller, rounder hills with pale-blue flowers and quiet, where echo-golem choir circles stand | **Should** | C (canon area: "contains echo golems"; quest "Choir Conductor") | N Cr S | flower forest · DATA |
| **Radiant Ravines** | Deep bright ravines lit by lumen growths | **Could** | C (name only: soundtrack title, L) | T K | — |
| The Carapace, Echo Den, Humbler Huskland | Dry blue-stone flats with fossils, sculker nests and humbler husks | **Won't (1.0)** → **1.1** | C | — | deferred by D-009 |
| Wild Meadows, Ravaged Meadow, Mites, Hollowed Islands, Illager Stronghold/Keep | Soundtrack-only names | **Won't (1.0)**: no content known beyond a title (L) | C (names only) | — | revisit when canon reveals them |

## 2. Terrain and dimension shape
| Entry | Decision | Tier | Source | Route |
|---|---|---|---|---|
| **Dimension type** `thesift:the_sift` | Sky light yes, ceiling no, `coordinate_scale` 1, `min_y` 0, `height` 256, the Overworld's monster light rule, `ambient_light` ≈0.05, `skybox: overworld` with the sun and moon parked (rules.md), `default_clock: thesift:tides` | **Core** | I + rules.md | DATA (D-008 adds the weather mixin) |
| **Noise settings** `thesift:sift` | Overworld-style router, retuned: gentle hills (meadow), sharp cliffs (Rise), caves (Hollows). **No sea and no aquifers** (`default_fluid` air, `sea_level` below the world). Material rules place healthy-sculk soil over hymnstone. Designed so `default_block` isn't needed (26.4 forward-compatibility, W2) | **Core** | I | DATA (material rules + density functions) |
| **Biome source** | Multi-noise with our own parameter list (3 surface + 1 cave biome in 1.0) | **Core** | I | DATA |
| **Tide basins** | Generated sunken flats (≤14×14, ~4 deep, one per chunk at most, in the meadow's lows) with a **tide vent** (the controller) at the centre | **Core** | I (the literal tide, D-011/D-013) | CODE (feature + block entity) |
| **Ichor pools** | Static pools and springs (they don't follow the tide), in lows and caves | **Core** | C ("many pools of ichor") | DATA (lake-style feature with our fluid) |
| **Hymnstone spires** | Freestanding red pillars and arches, the meadow's landmarks | **Should** | C (Dungeons II canyon images, mood only) | DATA (feature) |
| **Glowcap pools** | Cave pools of luminous fungus: safe, lit pockets underground | **Should** | I | DATA |

## 3. Block families
Every family follows vanilla's full sets where vanilla does. Every block gets its model, blockstate, loot table, recipe (where craftable), tags, lang, sound type, map colour and a GameTest where it has behaviour.

| Family | Members | Purpose | Tier | Source | Links | Vanilla analog |
|---|---|---|---|---|---|---|
| **Hymnstone** (red rose-coloured stone) | hymnstone, cobbled hymnstone, polished hymnstone, hymnstone bricks, cracked hymnstone bricks, chiseled hymnstone; stairs, slabs and walls for cobbled, polished and bricks | The Sift's bedrock-to-surface stone and main building palette | **Core** (the base block and bricks set in M1; the rest by 1.0) | C (red stone, RESEARCH §2/§5) | K Cr (hunters burrow in soil, not stone) | deepslate / blackstone family |
| **Healthy sculk** | healthy sculk (coral-orange soil with a petalled top), mossy variant (green), healthy sculk **grass** (short, tall; coral, pink, green) | Surface cover. It grows with bloom hearts and reacts to music (lights, sways) | **Core** | V (orange/salmon/pink/green healthy-sculk grass, S-I1) + C | S K N T | grass block, moss block, short/tall grass |
| **Songwood** (pale-barked tree with white leaves and pale-blue hanging vines; hollow branches hum in the wind) | log, wood, stripped log and wood, planks, stairs, slab, fence, fence gate, door, trapdoor, button, pressure plate, sign, hanging sign; leaves; **lullvine** (hanging vine) | The Sift's wood. Its hum marks groves, and it gives a building set | **Core** (M1: log, planks, leaves; full set by 1.0) | V (pale trees with dark trunks) + C ("blue trees", "pale-blue vines") | N Cr (blubs shelter under it) | cherry / pale oak families (no boat: see §6) |
| **Blight** (our own XP-free family, D-012) | blight (block), blight veins, blight tendril (hears vibrations), blight shrieker | Occupation scar; readable by pulse and motion | **Core** | C (corrupted sculk is a Sift disease) + I (the family) | I K S N | sculk, sculk vein, sculk sensor, sculk shrieker (look and behaviour grammar only; no XP) |
| **Bloom heart** | bloom heart (one block) | Drinks nearby non-player deaths like a catalyst; the offering altar that condenses soul blocks | **Core** | I | S K T | sculk catalyst |
| **Soul block** | soul block (placeable block and fuel item) | Condensed souls: fuel for golems, gates, traits | **Core** | C (soul blocks are in the game, M; lore L) | S Cr I | respawn-anchor charge / glowstone as fuel |
| **Tide flats** | tide sand (the basin floor), tide marks (wet state), **tide vent** (the controller, visible) | Basin floor that shows the tide's history (non-colour cue) | **Core** | I | T | mud / sand |
| **Sift gate** | gatestone (unbreakable frame), the **Sift membrane** (portal) | Arrival gate and return | **Core** | I | T N S | end portal frame, nether portal |
| **Lumen** | lumen bloom (natural light plant), lumen lantern (craftable) | The Sift's few real light sources: safe pockets in Endure | **Core** | I | T Cr | glow berries, lantern |
| **Musical gate** | gate block with a carved glyph and notches (see bible/items.md for the key rules) | Door keyed to an instrument and pitch; guards the boss arena | **Should** | C ("Musical Gate") | N Cr | iron door with a redstone lock (the key is sound) |
| **Rig and tanks** (Illager machines) | harvester rig (spreads blight), soul tank (breakable, returns souls) | Camp props with behaviour | **Core** | C (camps) + I (rigs) | I K S | outpost structures; the tank breaks like a decorated pot |

## 4. Flora and hazards
| Entry | What it does | Tier | Source | Links |
|---|---|---|---|---|
| **Tidewrack** | Low-tide reagent that grows on tide flats. It opens only in Thrive (logical tide) and drops fronds used for gear traits and dyes | **Core** | I | T S |
| **Endure bloom** | A flower along the waterline that opens only in Endure. Its petals are a rare reagent (lumen lanterns, traits) | **Core** | I (canon: "rare rewards" framing is ours) | T N |
| **Chime bell flower** | A pale-blue flower that rings softly when walked through: a vibration, so the hearing rule applies in Endure | **Should** | C ("pale-blue flowers") + I (the chime) | N T |
| **Meadow flowers** | Two decorative flowers (green, yellow) with dyes | **Should** | C ("green flowers, yellow flower patches") | — (decor) |
| **Ichor** (fluid) | Thick wade-through liquid: slows, burns (vanilla fire), drains XP from outsiders; Fire Resistance stops the burning only (D-013) | **Core** | C (canon hazard) | T S Cr |
| **Burst pod** | A hazardous plant that pops when stepped on in Endure, stunning briefly (canon "hazardous new blocks") | **Could** | C (the phrase) + I | T N |

## 5. Structures
| Structure | Purpose | Tier | Source | Links | Vanilla analog |
|---|---|---|---|---|---|
| **Sift-side gate** | Generated on first crossing (not worldgen): red-sculk hill, gatestone frame, sanctuary radius | **Core** | I (entry_path.md) | T N S | end exit portal; nether portal forcer |
| **Ancient City frame** (Overworld, vanilla structure) | We add only the membrane and the frame logic: no new blocks placed in vanilla worldgen | **Core** | C (Dungeons II portal location) | S N | — |
| **Illager camp** | Rig, tanks, caged echo golems, tents; the pillager-only respawn area | **Core** | C (camps, "Breaking Camps", "Guardian of the Golems") | I K S Cr | pillager outpost |
| **Singer's grove** | Where the Singer lives and the gift-of-song quest ends: a songwood ring around a bloom heart | **Core** | C (Singer's Meadow is the Singer's home) | N S Cr | — (a unique structure, like a woodland mansion is unique in feel) |
| **Monstrosity hollow** | The boss arena: a blight-choked hollow behind a musical gate, with blight hearts that erupt (catalysis) | **Core** (gate **Should**; without it the arena has a plain entrance) | C (the questline's Musical Gate, P-SK3; "catalysis") | I K N | trial chamber vault room / end island arena |
| **Choir circle** | Standing songwood stones where silenced echo golems wait to be woken by music | **Should** | C (Lullaby Hills; "Choir Conductor") | N Cr S | — |
| **Sift ruins** | Small ruins with loot (musical glyphs, records of the Singers) | **Could** | I (MC3's "forgotten ruins" is not Sift-specific) | N | trail ruins |

## 6. Won't (with reasons)
- **Boats for songwood.** The Sift has no water; we follow the Nether-wood precedent (crimson and warped have no boats). Revisit if players ask.
- **A new ore.** The vision gives no new tiers, and diamonds and netherite stay the Overworld's and Nether's (00_VISION §6).
- **Weather blocks and snow.** There is no weather in the Sift (D-008).
- **Aurora sky.** It needs a client mixin (IDEAS); post-1.0.

## Self-critique (WP-020, pass 1)
- **Is the block count still "fewer, deeper"?** There are four block families: hymnstone, healthy sculk, songwood and blight. That matches vanilla's Cherry Grove update, which added one wood family plus a few flora. Kept. M1 takes only the base blocks.
- **Does each entry have ≥2 links?** Meadow flowers have none (decor), so they are Should, not Core. Musical gates, rigs and tanks are Core only where a system needs them.
- **Canon vs invention** is marked on every row. The invented Core entries (tide basins, bloom heart, lumen, tidewrack, Endure bloom, Singer's grove) each serve a frozen-vision system.
