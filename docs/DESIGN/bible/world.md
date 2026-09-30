# Content bible I: the world (WP-020)

Part of `../01_CONTENT_BIBLE.md`. Frozen vision: `../00_VISION.md`. Decisions: D-016 (bible round-1 fixes).

**Legend.**
- **Tier:** **Core** (in 1.0) · **Should** · **Could** (after M6 only if the budget allows; otherwise post-1.0) · **Won't** (with a reason; deferred entries name their version).
- **MS:** the milestone that ships the entry (M1…M6; see `../01_CONTENT_BIBLE.md` §3). Every Core and Should row has one; `tools/docs/check_bible.py` fails if one is missing.
- **Source:** **C** = canon-grounded (RESEARCH ids) · **V** = the vanilla first look (the top visual authority, D-002) · **I** = our invention.
- **Links:** the Sift systems each entry touches: Tides (T), souls (S), sculk and blight (K), sound (N), Illagers (I), creatures (Cr), world blocks and flora (W).
- **Route:** DATA = datapack JSON produced by datagen · CODE = Java.
- **Names.** Canon names are kept where canon has them (Singer's Meadow, Lullaby Hills, soul block, musical gate). Every other name is our own, and none copies a fan mod's names (RESEARCH §8).

## 1. Areas and biomes
1.0 is one region, **Singer's Meadow** (D-009), built from a few biomes so the terrain has variety. Following vanilla precedent, one "area" can be several biomes (the Nether's first release had one; today it has five).

| Biome (id) | What it is | Tier | MS | Source | Links | Vanilla analog · route |
|---|---|---|---|---|---|---|
| **Singer's Meadow** (`thesift:singers_meadow`) | Rolling hills of coral-orange healthy-sculk grass under a teal sky, with songwood groves. Ichor pools fracture the ground, and tide basins sit in the lows. Home of the Singer, blubs and echo golems | **Core** | M1 | C (RESEARCH §2: "red sculk, teal grass, and blue trees"; "many pools of ichor, fracturing the terrain") + V (coral grass, teal sky, pale trees, Blub) | T S K N I Cr | meadow / cherry grove · DATA: biome JSON with attributes, features and spawns |
| **Sift Hollows** (`thesift:sift_hollows`) | The cave layer beneath the meadow: hymnstone caverns and glowcap pools. Dark, so the Sift's own hostiles spawn there. Blight seams near camps | **Core** | M2 | I (canon has "caves and forgotten ruins", MC3, but not for the Sift) | T K N Cr | dripstone caves / lush caves · DATA (underground multi-noise) |
| **Hymnstone Rise** (`thesift:hymnstone_rise`) | Steep cliffs and canyon walls of red hymnstone that bound the meadow, with overhangs, lullvine curtains and cave mouths | **Core** | M3 | C ("bounded by 'walls of darker red sculk'"; Dungeons II palette 1 "rose/crimson stone") | K N Cr W | stony peaks / badlands walls · DATA |
| **Lullaby Hills** (`thesift:lullaby_hills`) | Taller, rounder hills with pale-blue chime bell flowers and quiet, where echo-golem choir circles stand | **Should** | M5 | C (canon area: "contains echo golems"; quest "Choir Conductor") | N Cr S | flower forest · DATA |
| **Radiant Ravines** | Deep bright ravines lit by lumen growths | **Could** | — | C (name only: soundtrack title, L) | T K | — |
| The Carapace, Echo Den, Humbler Huskland | Dry blue-stone flats with fossils, sculker nests and humbler husks | **Won't (1.0)** → **1.1** | — | C | — | deferred by D-009 |
| Wild Meadows, Ravaged Meadow, Mites, Hollowed Islands, Illager Stronghold/Keep | Soundtrack-only names | **Won't (1.0)**: no content known beyond a title (L) | — | C (names only) | — | revisit when canon reveals them |

### 1.1 Spawn tables (per biome; weights are tuned in BALANCE.md)
The Sift spawns **no vanilla monsters** in any biome. Like the End with its endermen, it has its own ecosystem, so the Overworld's night mobs never appear. Illagers come only from camp structures.

| Biome | Creature category | Monster category (the Sift's own; light ≤ the Overworld's rule) | Structure spawns |
|---|---|---|---|
| Singer's Meadow | Blub (groups of 2–5), Slabber (M5) | Nester (Endure, surface), Bloombud (groups of 3–5, the canon "large groups", in darkness) | camps: pillagers (M4); Singer's grove: the Singer (M4) |
| Sift Hollows | — | Bloombud; Pollinator and Sprout (M5) | — |
| Hymnstone Rise | Blub (rare) | Nester (Endure) | — |
| Lullaby Hills | Blub, Slabber | Pollinator (M5) | choir circles: silenced echo golems (M5) |

**By milestone.** In M1 only blubs spawn, so Endure is dark and quiet but not yet dangerous. That is stated in PLAYTEST.md. Hostiles arrive in M2.

## 2. Terrain and dimension shape
| Entry | Decision | Tier | MS | Source | Route |
|---|---|---|---|---|---|
| **Dimension type** `thesift:the_sift` | Sky light yes, ceiling no, `coordinate_scale` 1, `min_y` 0, `height` 256, the Overworld's monster light rule, `ambient_light` ≈0.05, `skybox: overworld` with the sun and moon parked (rules.md), `default_clock: thesift:tides` | **Core** | M1 | I + rules.md | DATA (D-008 adds the weather mixin) |
| **Noise settings** `thesift:sift` | Overworld-style router, retuned: gentle hills (meadow), sharp cliffs (Rise), caves (Hollows). **No sea and no aquifers** (`default_fluid` air, `sea_level` below the world). Material rules place healthy-sculk soil over hymnstone. Designed so `default_block` isn't needed (26.4 forward-compatibility, W2) | **Core** | M1 (meadow + caves), M3 (cliffs) | I | DATA (material rules + density functions) |
| **Biome source** | Multi-noise with our own parameter list (M1: the Meadow alone; then 3 surface + 1 cave biome) | **Core** | M1 | I | DATA |
| **Tide basins** | Generated sunken flats (≤14×14, ~4 deep, one per chunk at most, in the meadow's lows) with a **tide vent** (the controller) at the centre. They flood with ichor in Endure and drain in Thrive; Flow is the tide moving | **Core** | M1 (D-016) | I (the literal tide, D-011/D-013) | CODE (feature + block entity) |
| **Ichor pools** | Static pools and springs (they don't follow the tide), in lows and caves | **Core** | M1 | C ("many pools of ichor") | DATA (lake-style feature with our fluid) |
| **Hymnstone spires** | Freestanding red pillars and arches, landmarks at the meadow's edge | **Should** | M3 | C (Dungeons II canyon images, mood only) | DATA (feature) |
| **Glowcap pools** | Cave pools ringed by glowcaps: safe, lit pockets underground | **Should** | M2 | I | DATA |

## 3. Block families
Every family follows vanilla's full sets where vanilla does. Every block gets its model, blockstate, loot table, recipe (where craftable), tags, lang, sound type, map colour and a GameTest where it has behaviour. Each family gets a §8.2 design doc in the milestone that ships it.

| Family | Members | Purpose | Tier | MS | Source | Links | Vanilla analog |
|---|---|---|---|---|---|---|---|
| **Hymnstone** (red rose-coloured stone) | **M1:** hymnstone, hymnstone bricks, brick stairs, brick slab, brick wall. **M3:** cobbled hymnstone, polished hymnstone, cracked hymnstone bricks, chiseled hymnstone; stairs, slabs and walls for cobbled and polished | The Sift's stone and main building palette | **Core** | M1, M3 | C (red stone, RESEARCH §2/§5) | K Cr W (hunters burrow in soil, not stone) | deepslate / blackstone family |
| **Healthy sculk** | **M1:** healthy sculk (coral-orange soil with a petalled top), healthy-sculk grass (short, tall). **M3:** mossy healthy sculk (green), pink and green grass colourings (they spread from bloom-heart growth) | Surface cover. It sways to music; in M3 it grows from bloom hearts | **Core** | M1, M3 | V (orange/salmon/pink/green healthy-sculk grass, S-I1) + C | S K N T | grass block, moss block, short/tall grass |
| **Songwood** (dark blue-violet bark pierced by pale **flute holes**; white leaves edged pale blue; pale-blue **lullvines** hang from it) | **M1:** log, planks, leaves. **M4:** wood, stripped log and wood, stairs, slab, fence, fence gate, door, trapdoor, button, pressure plate, sign, hanging sign; lullvine | The Sift's wood. Its tell is the flute holes, which puff faint note particles when music plays nearby or in Thrive (a visual for its hum). It gives a building set | **Core** | M1, M4 | V (pale trees with dark trunks) + C ("blue trees", "pale-blue vines") | N Cr W (blubs shelter under it) | cherry / pale oak families (no boat: see §6). It differs from pale oak by bark colour, flute holes and its reaction to music |
| **Blight** (our own XP-free family, D-012) | blight (block), blight veins, blight tendril (hears vibrations), blight shrieker; **blight heart** (boss arena only: erupts during the Monstrosity's catalysis, M6) | Occupation scar | **Core** | M4 (heart M6) | C (corrupted sculk is a Sift disease) + I (the family) | I K S N | sculk, sculk vein, sculk sensor, sculk shrieker (look and behaviour grammar only; no XP) |
| **Bloom heart** | bloom heart (one block) | Drinks nearby non-player deaths like a catalyst; the offering altar that condenses soul blocks | **Core** | M3 | I | S K T | sculk catalyst |
| **Soul block** | soul block (placeable block and fuel item) | Condensed souls: fuel for golems, gates, traits; the Singer's chorus stones | **Core** | M3 | C (soul blocks are in the game, M; lore L) | S Cr I | respawn-anchor charge / glowstone as fuel |
| **Tide flats** | **M1:** tide sand (the basin floor), **tide vent** (the controller, visible). **M2:** tide marks (the floor's wet state, which shows the tide's history) | Basin floor; tidewrack grows on it | **Core** | M1, M2 | I | T W Cr (blubs follow the waterline) | mud / sand |
| **Sift gate** | gatestone (unbreakable frame), the **Sift membrane** (portal) | Arrival gate and return | **Core** | M1 | I | T N S | end portal frame, nether portal |
| **Lumen** | lumen bloom (natural light plant), lumen lantern (crafted from Endure petals) | Light that **repels the Sift's hunters**: Nesters and Bloombuds avoid a small radius around it, as piglins avoid soul fire. Natural blooms make safe pockets in Endure; lanterns let players make their own | **Core** | M2 | I | T Cr N | glow berries, lantern; soul fire as a piglin repellent |
| **Musical gate** | gate block with a carved glyph and notches (see bible/items.md for the key rules) | Door keyed to an instrument and pitch; guards the boss arena | **Should** | M6 | C ("Musical Gate") | N Cr | iron door with a redstone lock (the key is sound) |
| **Camp machines** (Illager) | harvester rig (spreads blight), soul tank (breakable, returns souls), **golem cage** (holds an echo golem; opened by breaking its lock) | Camp props with behaviour | **Core** | M4 | C (camps, "Guardian of the Golems", track "Caged") + I (rigs) | I K S Cr | outpost structures and cages; the tank breaks like a decorated pot |
| **Chorus stone** | a songwood-and-hymnstone socket in the Singer's grove that holds one soul block | The gift-of-song quest's visible progress (items.md §1.1) | **Core** | M4 | I (canon: "Lost Harmonies: Find the stolen soul blocks") | S N Cr | end portal frame's eyes (visible progress) |

### 3.1 Art rules: healthy sculk vs blight (D-012's consequence)
The two families must be told apart **without colour**: by shape, motion, light and sound.

| Cue | Healthy sculk (and its flora) | Blight |
|---|---|---|
| **Shape** | Petals, leaves and rounded tufts; soft edges; the top face shows petal clusters | Veins, cracks and a mesh of branching lines; hard, angular edges |
| **Motion** | **Still** blocks. Plants **sway** (grass, lullvines). Nothing pulses | **Pulses**: an animated texture (`.mcmeta`) whose veins brighten and fade on a slow beat, like vanilla sculk |
| **Light** | No light at rest. A soft, steady glow only while music plays nearby (a short ramp, then back) | Faint light from the pulse only; never steady |
| **Sound** | Chimes and soft hums (step and break sounds in the amethyst register) | Wet, clicking sounds in the sculk register |
| **Palette** | Warm: coral, salmon, pink, green, pale blue (palette.md) | Cold and bruised: violet-black with sickly cyan-grey veins. Deliberately **not** vanilla sculk's teal, so blight never reads as vanilla sculk |

## 4. Flora and hazards
| Entry | What it does | Tier | MS | Source | Links |
|---|---|---|---|---|---|
| **Ichor** (fluid) | Thick wade-through liquid: slows, burns (vanilla fire), drains XP from anything that isn't a Sift native; Fire Resistance stops the burning only (D-013). A bucket of it evaporates outside the Sift | **Core** | M1 (D-016) | C (canon hazard) | T S Cr |
| **Tidewrack** | Low-tide reagent that grows on tide flats. It opens only in Thrive (logical tide) and drops fronds used for gear traits, dye and blub treats | **Core** | M2 | I | T S W Cr |
| **Endure bloom** | A flower along the waterline that opens only in Endure. Its petals are a rare reagent (lumen lanterns, traits) | **Core** | M2 | I | T N W |
| **Glowcap** | A small luminous cave fungus (light 10) that rings glowcap pools | **Should** | M2 | I | W Cr (Bloombuds avoid lit pockets by the light rule) |
| **Chime bell flower** | A pale-blue flower that rings softly when walked through: a vibration, so the hearing rule applies in Endure | **Should** | M2 | C ("pale-blue flowers") + I (the chime) | N T |
| **Meadow flowers** | Two decorative flowers (green, yellow) with dyes | **Should** | M5 | C ("green flowers, yellow flower patches") | W (decor; the one Should row below two links, accepted as decoration) |
| **Burst pod** | A hazardous plant that pops when stepped on in Endure, stunning briefly (canon "hazardous new blocks") | **Could** | — | C (the phrase) + I | T N |

## 5. Structures
| Structure | Purpose | Tier | MS | Source | Links | Vanilla analog |
|---|---|---|---|---|---|---|
| **Sift-side gate** | Generated on first crossing (not worldgen): a low mound of hymnstone capped with healthy sculk, the gatestone frame and a sanctuary radius | **Core** | M1 | I (entry_path.md) | T N S | end exit portal; nether portal forcer |
| **Ancient City frame** (Overworld, vanilla structure) | We add only the membrane and the frame logic: no new blocks placed in vanilla worldgen | **Core** | M1 | C (Dungeons II portal location) | S N | — |
| **Illager camp** | Rig, tanks, golem cages, tents and a loot chest holding one or two **stolen soul blocks**; the pillager-only respawn area | **Core** | M4 | C (camps, "Breaking Camps", "Guardian of the Golems", "Lost Harmonies") | I K S Cr | pillager outpost |
| **Singer's grove** | Where a Singer lives: a songwood ring around a bloom heart, with three empty **chorus stones**. The gift-of-song quest ends here | **Core** | M4 | C (Singer's Meadow is the Singer's home) | N S Cr | — (a unique structure, like a woodland mansion is unique in feel) |
| **Monstrosity hollow** | The boss arena: a blight-choked hollow behind a musical gate, with blight hearts that erupt (catalysis) | **Core** (gate **Should**; without it the arena has a plain entrance) | M6 | C (the questline's Musical Gate, P-SK3; "catalysis") | I K N | trial chamber vault room / end island arena |
| **Choir circle** | Standing songwood stones where silenced echo golems wait to be woken by music | **Should** | M5 | C (Lullaby Hills; "Choir Conductor") | N Cr S | — |
| **Sift ruins** | Small ruins with loot (musical glyphs, records of the Singers) | **Could** | — | I (MC3's "forgotten ruins" is not Sift-specific) | N | trail ruins |

## 6. Won't (with reasons)
- **Boats for songwood.** The Sift has no water; we follow the Nether-wood precedent (crimson and warped have no boats). Revisit if players ask.
- **A new ore.** The vision gives no new tiers, and diamonds and netherite stay the Overworld's and Nether's (00_VISION §6).
- **Weather blocks and snow.** There is no weather in the Sift (D-008).
- **Aurora sky.** It needs a client mixin (IDEAS); post-1.0.

## Self-critique
**WP-020, pass 1.**
- **Is the block count still "fewer, deeper"?** There are four block families: hymnstone, healthy sculk, songwood and blight. That matches vanilla's Cherry Grove update, which added one wood family plus a few flora. Kept. M1 takes only the base blocks.
- **Canon vs invention** is marked on every row. The invented Core entries (tide basins, bloom heart, lumen, tidewrack, Endure bloom, Singer's grove) each serve a frozen-vision system.

**WP-024, round-1 fixes (D-016).**
- Every Core and Should row has a milestone.
- Spawn tables were added.
- The art rules for healthy sculk vs blight were written (§3.1).
- Songwood got its own tell, and lumen a Sift-only function.
- The cage, the chorus stone, the blight heart and the glowcap got rows.
- **Links:** every Core row has ≥2. The only Should row with fewer is the meadow flowers (decor).
