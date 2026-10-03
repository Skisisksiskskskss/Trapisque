# Flora II (WP-064): the Tide's plants, the chime bell and the lights — FROZEN 2026-10-03

The M2 plants. Five entries are fixed by the frozen documents; this doc decides how each one works,
looks and sounds, where it grows, and its numbers. Sources:
- **world.md §4** (the rows Tidewrack, Endure bloom, Glowcap, Chime bell flower) and **§2** (Lumen:
  "lumen bloom (natural light plant)"; "natural blooms make safe pockets in Endure").
- **items.md** (Tidewrack frond: "Thrive only"; Endure petal: "Endure only", "a rare flora drop").
- **systems.md §1** (the frozen Tides):
  - tidewrack follows the **logical** Tide ("closed and drop nothing, even if a player keeps the ichor
    out");
  - "Endure blooms open along the waterline, and their reagents can be taken only then";
  - "slow organic changes (blooms, tidewrack opening) use random ticks, as eyeblossoms do";
  - `thesift:gameplay/tide` is what tidewrack reads.
- **systems.md §2:** growth never produces tide-flat reagents or Endure blooms.
- **system_hunt.md:**
  - §6: lumen is a POI, `thesift:lumen`, repel radius 6, no spawns within 8;
  - §9: the chime bell rings as a `minecraft:block_activate` vibration, once per 10 ticks, not while
    sneaking.
- **mob_bloombud.md:** "**the Sift has no buds**": none of these plants may look like a round closed
  bud on a stalk, or show a ring of five warm glowing points low to the ground (the Bloombud's tell).
- **world.md §3.1:** healthy sculk "and its flora" give **no block light** and keep a warm palette;
  blight is teal-black with cyan veins, angular, and pulses. Only the glowcap (10) and lumen are given
  light by the bible.
- **D-026:** the Sift has no seas. Ichor lies in Meadow ponds, the Ichor Flats' blots, the Hollows'
  pools, and the tide basins (one chunk in five, in the Meadow's lows).

Items made from these plants (fronds, petals, the lumen lantern, blub treats, recipes) are WP-065's;
this doc names only what the blocks drop.

## Concept ladder: what makes gathering by the Tide a decision?
The bible already says *when* each reagent can be had. The question is what a player does, sees and
risks while gathering, so the Tides are felt through the plants rather than read off a timer.

### Diverge (written before scoring)
1. **Eyeblossom switching.** Each tide plant reads `thesift:gameplay/tide` on its random tick and
   switches open or closed, with a sound and a rising trail particle; same-state neighbours within
   3 blocks follow on short scheduled delays, so a patch ripples open over a few seconds. Vanilla's
   own day/night flower (`EyeblossomBlock`).
2. **Pick and keep** (sweet berries): *use* on an open plant drops its reagent and leaves the plant,
   marked picked until its next window. Breaking it gives the same once, but loses the plant.
3. **The logical pick:** a pick yields only if the logical Tide is right at that moment, whatever the
   plant looks like, so a patch that hasn't switched yet (random-tick lag, a chunk just loaded) can't
   be milked: picking it out of its window closes it at once instead.
4. **Picking is heard:** a pick is a `block_change` with the player as source (as sweet berries), so
   in Endure, picking Endure petals within 16 of a listener calls it. The blooms' own opening (as the
   eyeblossom's switch) is a `block_change` too, with no entity: as Endure begins, hunters near a
   waterline turn toward it.
5. ***Drifting wrack*** (unusual): in rising Flow, open fronds tear loose and drift to the basin's rim
   as item entities, to be scooped up before they sink.
6. ***The waterline follows the water*** (unusual): during rising Flow, Endure blooms open layer by
   layer as the ichor reaches them, a physical rule.
7. ***Bells around the light*** (unusual): chime bells grow in drifts around lumen blooms, so the
   safe pocket is ringed by noise: you reach it carefully, sneaking through the bells.
8. **Glowcap pools as lit pockets:** glowcaps' light (10) keeps spawns out of a cave pool's ring, so
   the Hollows have pockets where nothing appears beside you (hunters may still walk in).
9. **Lumen that sleeps:** lumen blooms give light only in Endure.
10. **A fixed wild supply:** the tide plants never grow, spread or move. They come from world
    generation and stay where the world put them: no tool gives the plant itself (as budding amethyst
    gives nothing), so fronds come only from the flats and petals only from the waterline.

### Converge: rubric (1–5; the same seven criteria as mob_blub.md)
| # | Concept | Faithful | Vanilla-native | Readable | Meaningful | Distinct | Connected | Feasible | Total |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Eyeblossom switching | 5 | 5 | 5 | 3 | 3 | 4 | 5 | **30** |
| 2 | Pick and keep | 4 | 5 | 5 | 4 | 3 | 3 | 5 | **29** |
| 3 | The logical pick | 5 | 4 | 4 | 4 | 3 | 4 | 5 | **29** |
| 4 | Picking is heard | 4 | 5 | 4 | 5 | 4 | 5 | 5 | **32** |
| 5 | Drifting wrack | 3 | 2 | 4 | 3 | 5 | 3 | 2 | 22 |
| 6 | The waterline follows the water | 2 | 3 | 4 | 3 | 4 | 3 | 3 | 22 |
| 7 | Bells around the light | 4 | 4 | 4 | 4 | 5 | 5 | 4 | **30** |
| 8 | Glowcap pools as lit pockets | 4 | 5 | 5 | 4 | 3 | 4 | 5 | **30** |
| 9 | Lumen that sleeps | 2 | 3 | 3 | 2 | 3 | 3 | 4 | 20 |
| 10 | A fixed wild supply | 5 | 5 | 4 | 4 | 3 | 4 | 5 | **30** |

Notes on the calls:
- **1** is the frozen systems.md line, and the eyeblossom is vanilla's answer to "a flower that keeps
  time". It makes each switch a moment you can see and hear across a basin.
- **2 + 3** turn the bible's "only then" into an action with a rule players can trust: an open plant
  in its window gives once; anything else gives nothing. The plant staying put is what makes a
  patch a place you come back to.
- **4** is free (vanilla already emits these events, and the hunters already listen to
  `#minecraft:vibrations`), and it is the decision: Endure petals are taken in Endure, in the dark,
  and taking one makes a sound a Nester can hear. Sneaking doesn't muffle a pick (`block_change`
  isn't in `#ignore_vibrations_sneaking`); wool does, as for every vibration.
- **5** churns item entities through a fluid at every Flow. **6** breaks systems.md's logical rule.
  **9** contradicts system_hunt.md §9 (lumen repels in every Tide) and leaves Thrive's lumen
  pointless. All three are recorded in IDEAS.md.
- **7** costs one generation rule and links three systems (lumen, the hearing rule, the chime bell).
- **8** is the bible's glowcap pool, stated as a mechanic: vanilla's monster spawn rule needs block
  light 0 (`monster_spawn_block_light_limit` 0 in our dimension type, as the Overworld's).
- **10** is systems.md §2 applied ("those come only from the flats and the waterline"): no bone meal,
  no spreading and no transplanting for tidewrack, Endure blooms and lumen blooms, so no farm makes
  reagents faster than the Tides allow, and no garden takes the petal out of Endure's dark.

### Decision: **"The patch you come back to"**: 1 + 2 + 3 + 4 + 10, with 7 and 8 in generation
- Tide plants switch like eyeblossoms (1), are picked like sweet berries (2) under the logical rule
  (3), and are heard when picked (4). Their supply is what the world grew (10).
- Lumen blooms come with rings of chime bells on the approach (7). Glowcaps ring the Hollows' pools
  (8).

## The family
| Block (id) | What it is | Block light | Tide rule | Drops (any tool, Silk Touch included) |
|---|---|---|---|---|
| **Tidewrack** (`thesift:tidewrack`) | Ribbons of wrack lying on a tide basin's floor | 0 | Open in Thrive; closed otherwise | Ready (open, unpicked this cycle, Thrive): 1–2 fronds. Otherwise nothing. Never the plant |
| **Endure bloom** (`thesift:endure_bloom`) | A low star of petals on the waterline | 0 (open: emissive centre and petal edges) | Open in Endure; closed otherwise | Ready (open, unpicked this cycle, Endure): 1 petal. Otherwise nothing. Never the plant |
| **Glowcap** (`thesift:glowcap`) | A cluster of small flat-topped cave fungi | 10 | — | Itself |
| **Chime bell flower** (`thesift:chime_bell_flower`) | Pale-blue flared bells hanging from an arched stem | 0 | Rings in every Tide; heard in Endure | Itself |
| **Lumen bloom** (`thesift:lumen_bloom`) | Three broad glassy petals splayed flat around a light | 12 | Lumen (repels hunters) in every Tide | Nothing, even with Silk Touch |
| Potted chime bell flower, potted glowcap | Flower-pot variants, as vanilla's | as above | — | The pot and the plant |

The three that drop nothing as a plant (tidewrack, the Endure bloom, the lumen bloom) follow budding
amethyst: the world's own, to be used where they stand. Like budding amethyst they still have block
items, for the creative tab and pick-block, but no survival source (no loot, no recipe, no trade).
This narrows world.md §4 (tidewrack "grows on tide flats" stays true; "at home it is decoration" no
longer applies to these three, which can't be carried home): recorded as **D-027**.

## Shared rules
- **Scope:** world.md §4: Sift plants grow, spread or take bone meal only where `sift_life` is true.
- **Survival:** instant break with any tool or none, as flowers (no tool tag). Each needs its ground
  (below); losing it pops the plant, dropping as a break with no tool.
- **Switching (tidewrack, Endure bloom),** as `EyeblossomBlock` (`randomTick`, `tick`,
  `tryChangingState`):
  - on a **random tick**, the block reads `thesift:gameplay/tide` at its position; if its `open` state
    is wrong for the Tide, it switches, plays its long switch sound, sends one trail particle upward,
    emits `minecraft:block_change` with no entity source, and schedules a tick for every block **of the
    same block with the same `open` value** within 3 horizontally and 2 vertically, after 5–10 ticks
    per block of distance (the eyeblossom matches the exact state; ours ignores `picked_cycle`
    and `submerged`, so a patch ripples as one);
  - a **scheduled tick** does the same with the short switch sound;
  - **picked is a stamp, not a flag.** The state `picked_cycle` (0–15) holds 0 for unpicked, or the
    cycle it was picked in: (Tide clock ticks ÷ 30 000, rounded down, mod 15) + 1. A plant counts as
    picked only if its stamp is the **current** cycle's, so a plant left in an unloaded chunk is fresh
    again when its next window comes, with no tick needed. A random tick that finds a stale stamp sets
    it to 0 (so the model shows unpicked again), and closing sets it to 0. World generation, commands
    and creative items place plants at 0: a new patch yields in its first window. (A plant picked and
    left unloaded for exactly a multiple of 15 cycles, 6.25 hours, would read as picked until its next
    window: accepted.)
  - **a stale state** is fixed by the first *use* too: a use on a plant whose `open` state is wrong for
    the Tide switches it at once (the short sound, no drop), so a fresh patch generated mid-window can
    be opened by hand and picked with a second use;
  - at the default `random_tick_speed` 3, one block is picked about once every 1 365 ticks (4 096 blocks
    in a section, 3 picks a tick): a lone plant's mean wait is about 68 s, and about 5 % wait longer
    than 3.4 minutes; in a patch the first switch ripples through the rest within seconds.
- **Picking (tidewrack, Endure bloom),** as `SweetBerryBushBlock.useWithoutItem`:
  - *use* on the plant (with an empty hand, or an item that has no use on it);
  - if it is **ready** (open, not picked this cycle, in the Sift, and the logical Tide is its Tide): it
    drops its harvest loot table at the plant, plays `thesift:block.flora.pick` (3 variants, subtitle
    "Plant picked"), stamps the current cycle, and emits `minecraft:block_change` with the player as
    source (as the bush does); the use succeeds (the hand swings);
  - if its `open` state is wrong for the Tide (or it is outside the Sift and open), it switches at once
    (the short switch and its ownerless `block_change`, no drop); the use succeeds;
  - otherwise the use passes (`InteractionResult.PASS`, the default), as on any plain block.
- **Breaking** uses the block loot table: the harvest if the plant is ready, and nothing otherwise,
  whatever the tool. "Ready" needs the cycle stamp, which no vanilla loot predicate can compare, so it
  is one loot condition of our own, `thesift:tide_flora_ready` (a `MapCodec` registered in
  `BuiltInRegistries.LOOT_CONDITION_TYPE`, as vanilla's own conditions are), used by the block tables
  (a pick checks readiness in code before it rolls the harvest table). No Fortune on either table (sweet berries'
  break table applies Fortune; a reagent's yield stays fixed). Pistons pop it (`PushReaction.POPPED`,
  as poppies), dropping as a break with no tool. Breaking is the worse choice: the harvest once, and
  the plant gone for good.
- **No growth:** tidewrack, Endure blooms and lumen blooms take no bone meal, never spread, and can't
  be moved (systems.md §2). The world's count of them only falls.
- **Souls (systems.md §2):** a bloom heart's growth (M4) may place **chime bell flowers** and
  **glowcaps** among its "blooms, light and common Sift materials"; it never places tidewrack, Endure
  blooms or lumen blooms.
- **Fluids** (`FlowingFluid.canHoldAnyFluid`: a block takes a fluid only if it is a
  `LiquidBlockContainer` or in `#minecraft:washed_away_by_fluids`):
  - **tidewrack** is a container for ichor only (§1);
  - **glowcaps and chime bells** are washed away (in `#minecraft:washed_away_by_fluids`, as mushrooms,
    glow lichen and every vanilla small flower: poppies, dandelions, blue orchids, spore blossoms and
    eyeblossoms are all in it), dropping as a break with no tool;
  - **Endure blooms and lumen blooms** hold fluids back (not in the tag, not containers), as **sugar
    cane** does: they are wild and irreplaceable, so flowing fluid can't wash a petal patch or a camp
    away. Ichor laps against a bloom on the waterline without breaking it. (A bucket emptied into a
    plant's own cell still replaces it, as with any plant: the same as breaking it.)

## 1. Tidewrack
- **Identity:** the low-tide reagent of the tide flats (world.md §4): you go down onto the bare basin
  floor in Thrive and pick it. Its fronds become cyan dye, gear traits and blub treats (WP-065).
- **Where it grows:** only where the basin feature puts it: on the floor cells that flood in Endure
  (the pool and rings 1–2; `TideBasin.floorY` and three layers), each with a 35 % chance, except the
  vent and the four cells beside it (the vent stays visible). A basin is 11 or 13 blocks across
  (`TideBasinFeature`: inner 2–3, three rings), with 72 or 112 such cells: **about 25–39 plants**.
  Ring 3 never floods (its floor is level with the top layer); it is the Endure waterline (§2).
  Survives on tide sand only; WP-071's tide marks will be a state of tide sand, so tidewrack keeps
  its footing on a marked floor.
- **Holding ichor,** as a waterloggable block holds water (`SimpleWaterloggedBlock`), with ichor:
  - a boolean state `submerged`; while it is true the fluid state is an ichor source;
  - `LiquidBlockContainer.canPlaceLiquid` is true only for the **ichor source** while dry, and
    `placeLiquid` accepts only a source (flowing ichor doesn't enter, as flowing water doesn't
    waterlog a slab); `BucketPickup` gives the ichor back into a bucket;
  - the **vent** sets and clears `submerged` directly: its fill also submerges dry tidewrack, its drain
    dries it (one branch each in `TideVentBlockEntity`);
  - **the ichor bucket** needs two overrides: vanilla's `BucketItem.use` makes the clicked block the
    target only for water (`this.content == Fluids.WATER`), and `emptyContents` otherwise treats a
    non-solid plant as replaceable and puts the fluid in its place. `IchorBucketItem` overrides
    **`use`** (a clicked dry tidewrack is the target) and **`emptyContents`** (a dry tidewrack target
    gets `placeLiquid`), as vanilla does for water. Vanilla's dispensers know only vanilla buckets
    (others are ejected), so the ichor bucket registers its own dispenser behaviour, modelled on
    vanilla's filled bucket: `emptyContents` on the block in front, and an empty bucket back. A
    dispensed ichor bucket therefore submerges a tidewrack in front of it too;
  - water and lava don't enter dry tidewrack (a container that refuses them, as a waterloggable block
    refuses lava); submerged, it is full. A **water bucket** clicked on dry tidewrack is lost, as on
    kelp (vanilla targets any container with water and reports success even when `placeLiquid`
    refuses): vanilla's own quirk, kept.
- **States:** `open`, `submerged` (booleans); `picked_cycle` (0–15).
- **Properties:** no collision, instant break, `SoundType.WET_GRASS` (seagrass's), offset XZ, map
  colour `WATER` (as kelp), pushes `POPPED`, not flammable (as kelp), random ticks.
- **Look** (cutout, 16 × 16, a ramp `tidewrack`: olive green to ochre gold, warm, with sea-green
  undersides; never teal-black or cyan veins, which are blight's):
  - **closed:** the ribbons curled tight into a flat knot about 3 px high and 10 px across, dull olive;
  - **open:** the ribbons spread flat in a loose star, 1–2 px high, glossy, the sea-green undersides
    showing;
  - **picked:** bare ochre stems, flat;
  - soft, rounded ribbons, nothing angular, nothing round and nothing on a stalk: wrack lies down.
  Model: a flat plane 1 px above the floor (a carpet's height) plus a low cross for the knot.
- **Sounds:** `tidewrack.open` (a wet unfurling rustle, 2 variants, "Tidewrack opens"),
  `tidewrack.close` (a wet curl, 2 variants, "Tidewrack closes"); long and short versions, as the
  eyeblossom's.
- **Loot:** 1–2 fronds (uniform), as sweet berries give 1–2 at age 2.
- **Tags:** `#thesift:tide_flora` (the two tide plants, for tests and rules).
- **Advancement:** "Low Tide" (items.md, WP-072): `minecraft:inventory_changed` with a tidewrack frond.
- **Compost:** not compostable (a creative-only item).

## 2. Endure bloom
- **Identity:** the high tide's flower (world.md §4): it opens along the waterline as Endure begins,
  and its petal is the rare reagent for lumen lanterns and traits (items.md). You take it in the dark,
  while the hunters listen.
- **Where it grows:** on the waterline: a ground block (healthy sculk, Sift Soil, tide sand) with air
  above and an ichor block beside it at the same height.
  - A feature, `thesift:endure_blooms`, runs once per chunk with a **1-in-16** chance. It scans the
    chunk's surface columns (the heightmap, as the Flats' pools feature does) for waterline cells; if
    there are any, it picks one and places **2–4 blooms** on waterline cells within 3 blocks of it.
  - The basin feature gives a basin's ring 3 (its Endure waterline, dry in every Tide) 2–4 blooms
    with a 30 % chance.
  - Survives on healthy sculk, Sift Soil, tide sand and `#minecraft:dirt`.
- **States:** `open` (boolean); `picked_cycle` (0–15).
- **Properties:** no collision, instant break, `SoundType.GRASS`, offset XZ, map colour `PLANT`,
  pushes `POPPED`, **not flammable** (a wild supply one fire could end; as kelp and tidewrack), random
  ticks. **No block light** (world.md §3.1): the open bloom's centre and petal edges are drawn with an
  emissive element (`light_emission` 15 in the model, as vanilla's open eyeblossom uses
  `cross_emissive`), so an open patch shows in Endure's dark without lighting the ground or changing
  where mobs spawn.
- **Look** (cutout, a ramp `endure_bloom`: grey-green leaves; **cool** periwinkle to pale blue petals
  and a pale blue-white centre, inside world.md §3.1's healthy "pale blue"; no pink and no warm white,
  which belong to the Bloombud's `particle` tips):
  - **closed:** a flat rosette of grey-green leaves, 2 px high, no stalk, nothing furled into a ball;
  - **open:** an eight-pointed star of periwinkle-to-pale-blue petals lying flat 2 px above the ground;
    only the centre and the petal edges are emissive, so it glows as a thin cool outline of a star;
  - **picked:** the green star of sepals, not emissive;
  - a flat cool outline on the ground, never points on a bud and never warm: unlike the Bloombud's
    ring of five warm tips held up on a plum bud (mob_bloombud.md).
- **Sounds:** `endure_bloom.open` (a soft glassy swell, 2 variants, "Endure bloom opens"),
  `endure_bloom.close` (the swell falling, 2 variants, "Endure bloom closes"), long and short.
- **Loot:** 1 petal.
- **The decision it makes:** a patch opening at Endure's start is a `block_change` (no entity), so
  listeners within 16 turn toward the waterline then; each pick is a `block_change` with you as the
  source, which sneaking doesn't muffle (it isn't in `#ignore_vibrations_sneaking`). So you pick fast
  and leave, or wait out the first minute while the hunters come to look and go. Wool on the straight
  line between the bloom and a listener blocks the sound (vanilla's six rays are that one line nudged
  by 1e-5, so one wool block on it occludes them all).
- **Lanterns change it, on purpose.** A lumen lantern by a patch makes picking there safe: a sound
  from inside the radius only sends a hunter to the rim to pace, and a target inside is dropped
  (system_hunt.md §6). That is the progression the lantern is for: your first petals are taken in the dark, and they
  buy the light that makes the next ones safe. Petals stay paced by the Tide (one per bloom per
  Endure, one Endure every 25 minutes, about 2.4 an hour) and by how many patches a player has found
  and lit; they are spent on lanterns (WP-065) and gear traits (M5's Muffled Steps and others).
- **Compost:** not compostable (a creative-only item).

## 3. Glowcap
- **Identity:** a small luminous cave fungus (world.md §4, light 10) that rings glowcap pools: the
  Hollows' lit pockets, where **nothing spawns** (vanilla's rule: `monster_spawn_block_light_limit` 0
  in the Sift's dimension type). Hunters may still walk in; only lumen holds them off
  (system_hunt.md §6).
- **Where it grows:** WP-063's glowcap pools (a Should): ichor pools in the Hollows ringed by
  glowcaps on the bank (dry floor cells within 2 of the edge, never in the pool, where they would wash
  away); and scattered clusters on Hollows floors, much
  rarer than glow lichen (which places 104–157 attempts a chunk): 2–6 clusters a chunk below the skin.
  On the surface, nowhere.
- **Properties:** no collision, instant break, `SoundType.FUNGUS`, offset XZ, map colour
  `COLOR_LIGHT_GREEN`, pushes `POPPED`, not flammable (as mushrooms), washed away by fluids (as
  mushrooms), light **10** (the soul lantern's). Survives on a floor whose top `isSolidRender` (the
  mushrooms' placement test), in any light. No random spread. **Bone meal**, in the Sift only: one new
  glowcap on a free solid floor in the 3 × 3 × 3 around it, unless 5 glowcaps already stand in the
  9 × 3 × 9 box around it (the cap vanilla's mushroom spread uses: a 1-in-25 random tick, at most 5 in
  that box; vanilla's bone meal instead grows a huge mushroom). So bone meal can light a cave, but not
  fill it.
- **Look** (cutout, a ramp `glowcap`: pale seafoam-green caps, grey-green gills and stems): three
  small caps on short stems, each cap a flat disc wider than it is tall (4 px wide, 1 px thick),
  ankle-high (6 px). Flat shelves, never a dome on a stalk, and cool, never warm.
- **Loot:** itself. **Compost:** medium (as mushrooms). **Potted** variant.

## 4. Chime bell flower
- **Identity:** canon's "pale-blue flowers" (world.md §4) with a sound: walking through it rings it,
  a vibration, so in Endure a careless step is heard (system_hunt.md §9).
- **Where it grows:**
  - flower patches in Singer's Meadow (1 chunk in 4: a random patch of 12 tries within 6 blocks) and
    the Ichor Flats (1 chunk in 6); vanilla's default flower patch is 1 in 32, so the Sift is a
    flowerier place, as the teasers show;
  - a ring around half of the lumen blooms (concept 7): a **dense band 2 blocks wide, 7–8 blocks** from
    the bloom (about 70 % of the band's ~100 cells filled, so about 70 flowers), just outside the repel
    radius (6), all the way round, and only on the surface (chime bells need the Meadow's ground; in
    1.0 only the surface Nester listens). You cross it by sneaking, or by building over it. A ring rung
    there is outside the radius, so a Nester comes to the bell itself; its search (6 blocks) can reach
    into the camp, where any target is dropped (system_hunt.md §6): the band warns, the light keeps;
  - Lullaby Hills (M5) will be its home.
  - Survives on healthy sculk, Sift Soil and `#minecraft:dirt` (`SiftPlants.isSiftGround`).
- **Ringing** (system_hunt.md §9, decided there):
  - a living entity that isn't a spectator, moving through the block, and not stepping carefully
    (`Entity.isSteppingCarefully()`, which is `isShiftKeyDown()`), rings it. "Moving" is the berry
    bush's test: `isClientAuthoritative() ? getKnownMovement() : oldPosition() − position()`, with a
    horizontal component of at least 0.003 a tick (players' movement is client-authoritative, so their
    position doesn't change on the server's tick);
  - the state `ringing` becomes true, and a scheduled tick 10 later sets it false; while it is true the
    flower doesn't ring again. A flower placed already ringing (`/setblock`, a structure, a
    `block_state` item) schedules its reset in `onPlace`, so it never sticks silent;
  - a ring plays `chime_bell.ring` (4 variants, pitch-varied, subtitle "Chime bell rings") and emits
    `minecraft:block_activate` with the walker as source;
  - the model shows the bells swung while `ringing` is true.
- **Music:** in the M1 music reaction (`animateTick` and the client music buffer, world.md §3.2), a
  chime bell within 12 blocks of music now and then hums on the client alone: its own sound,
  `chime_bell.hum` (a soft sustained tone, 2 variants, subtitle **"Chime bell hums"**), and a note
  particle. It makes no vibration, so a player reading subtitles can tell the harmless hum from a
  ring the hunters hear.
- **Properties:** a `FlowerBlock` (suspicious stew: Slow Falling, 7 s, by a recipe of its own in
  WP-065, as each vanilla flower has its own `suspicious_stew_from_*` recipe; vanilla's common flowers
  already give brewable effects: allium Fire Resistance, poppy Night Vision, cornflower Jump Boost);
  no collision, instant break, `SoundType.SMALL_AMETHYST_BUD` (a glassy chink: world.md §3.1's
  amethyst register, for the one plant whose nature is a chime; D-027), offset XZ, map colour `PLANT`,
  pushes `POPPED`, flammable as flowers (60, 100), washed away by fluids (as every small flower).
- **Tags:** `#minecraft:small_flowers`, block and item (so `#minecraft:flowers`, and endermen carry it,
  as they carry small flowers: `#enderman_holdable` includes `#small_flowers`; a mooshroom takes it as
  any `FlowerBlock`), `#minecraft:washed_away_by_fluids`, `#minecraft:bee_attractive` and the item tag
  `#minecraft:bee_food` (as vanilla's small flowers: bees follow it and breed on it), so
  bees visit it whenever they are out (in the Sift, every Tide but Endure: the timeline keeps
  `bees_stay_in_hive` false before 15 000 and from 27 000). A light blue dye recipe (WP-065, one
  flower → one dye, as blue orchid).
- **Look** (cutout, a ramp `chime_bell`: pale ice-blue bells, a muted green stem): an arched stem
  10 px high with three bells hanging from its curve, each **flared**: narrow at the top, wide and open
  at the mouth, the dark inside of the mouth showing from the side. Hanging open cups, nothing round,
  nothing upright.
- **Loot:** itself. **Compost:** medium (as flowers). **Potted** variant.

## 5. Lumen bloom
- **Identity:** the natural lumen (world.md §2): a rare plant whose light hunters won't enter
  (system_hunt.md §6: no hunter within 6, no spawns within 8). Finding one in Endure is finding a camp;
  making your own takes Endure petals (the lumen lantern, WP-065).
- **Where it grows:** alone or in pairs on healthy sculk or Sift Soil in Singer's Meadow and the Ichor
  Flats (1 chunk in 12), and on hymnstone floors in the Hollows (1 chunk in 24). About half of the
  surface ones come with a chime bell ring (§4). Survives on healthy sculk, Sift Soil, `#minecraft:dirt` and hymnstone.
- **Properties:** no collision, instant break, `SoundType.SPORE_BLOSSOM`, no offset (it stands
  centred, as a light should), map colour `COLOR_LIGHT_BLUE`, pushes `POPPED`, light **12**, not
  flammable (unlike the spore blossom: a camp's light shouldn't burn down with the grass), no random
  ticks, no bone meal. Its states belong to the `thesift:lumen` POI type (system_hunt.md §11,
  registered with Fabric's `PoiHelper`).
- **Look** (cutout, a ramp `lumen`: cool white to pale moonlit blue, with a white core): three broad
  glassy petals **splayed outward and down**, wider than tall (14 px across, 6 px high), around a
  bright core, sitting straight on the ground with no stalk. Always open. Now and then (`animateTick`,
  1 in 8) a pale mote drifts up from the core. Shape, colour and motes read as lumen at a glance,
  never as a bud's warm points or a closed tulip.
- **Loot:** nothing, even with Silk Touch (as budding amethyst). A natural lumen is a place.
- **Compost:** not compostable (a creative-only item).

## 6. Per Tide
| | Thrive | Flow (rising) | Endure | Flow (falling) |
|---|---|---|---|---|
| Tidewrack | Opens; picked for fronds; the basin is bare | Closes (and unpicks); the basin floods over it | Closed, submerged | Closed; the basin drains |
| Endure bloom | Closed | Closed | Opens (a sweep of glowing stars along the waterline); picked for petals; picking is heard | Closes (and unpicks) |
| Glowcap | Light 10 | Light 10 | Light 10 | Light 10 |
| Chime bell | Rings; nobody listens | Rings | Rings, and is heard | Rings |
| Lumen bloom | Repels | Repels | Repels | Repels |

## 7. Numbers (copied to BALANCE.md on freeze)
| Number | Value | Vanilla analogs | Why |
|---|---|---|---|
| Tidewrack harvest | 1–2 fronds per Thrive per plant | sweet berries 1–2 (age 2) and 2–3 (age 3); glow berries 1 per pick; kelp | ~25–39 plants a basin give ~40–60 fronds a cycle: plenty for dye and treats, paced by Thrive |
| Endure petal harvest | 1 per Endure per bloom | glow berries 1 per pick; torchflower seeds (rare by source: sniffers); pitcher pods | Rare by where it grows |
| Endure bloom frequency | patches in 1 of 16 chunks with a shore (2–4 blooms); basin ring 3 in 30 % of basins (2–4) | pumpkin patch 1 in 300 chunks; vanilla default flower patch 1 in 32 | About 0.19 blooms a shore chunk. A careful, sneaking Endure (about 1.3 blocks/s, so ~780 blocks in 10 minutes, seeing ~50–100 chunks) passes ~25–50 shore chunks: ~2–4 patches, ~6–12 blooms; a first night picks perhaps 5–10 petals, one or two lanterns at WP-065's planning price of 4. Later nights add the patches already found and lit, so petals grow with a player's map, never faster than one per bloom per Endure (about 2.4 an hour per bloom) |
| Switch timing | random tick (lone plant ~68 s mean; 5 % > 3.4 min), ripple 5–10 ticks per block within 3 | eyeblossom (same mechanism) | A patch switches as one event |
| Light | glowcap 10; lumen bloom 12; Endure bloom 0 (emissive) | soul lantern 10; glow berries 14; glow lichen 7; lantern 15 | A glowcap a pocket, lumen a camp, the bloom a mark that lights nothing |
| Chime cooldown | 10 ticks (system_hunt.md §9) | sculk sensor: active 30, cooldown 10 | Footsteps ring, a herd doesn't spam |
| Tidewrack density | 35 % of a basin's flooding floor | — | A short pick, not a field |
| Chime bell patches | Meadow 1 chunk in 4, Flats 1 in 6 | vanilla default flower patch 1 in 32 | Common enough to step in |
| Lumen bloom | surface 1 chunk in 12; Hollows 1 in 24 | pumpkin patch 1 in 300 | Rare enough to be a find; common enough that most Endures pass one |

## 8. Edge cases
| Case | Rule |
|---|---|
| A cofferdam keeps the ichor out in Endure | Tidewrack stays closed and gives nothing (the logical Tide, systems.md) |
| Pick, then break or shear the plant | Breaking gives nothing (it's picked); no tool gives the plant |
| A plant placed by `/setblock` or a creative item | Starts unpicked (stamp 0); creative-only, so no survival source |
| A patch generated in its window, still closed | Opens on its first random tick, or at once on a use; then yields |
| Picked, left unloaded, back in the next window | Yields: the stamp is the old cycle's (§ Shared rules). If it was unloaded while open, it shows picked until its first random tick (about 68 s), though a use already yields: accepted |
| A tide plant outside the Sift (only by commands) | Never switches; a use closes it; never yields |
| A chunk unloaded through a Tide change | Its plants switch on their next random ticks after loading; a use checks the logical Tide, so a stale plant switches instead of yielding. Stale tidewrack closing in Endure emits its ownerless `block_change`, so a Nester near a basin may come to look: harmless, listed |
| `advance_time false` | The Tides stop, so the plants stop switching (as eyeblossoms when the sun stops) |
| `random_tick_speed 0` | Plants never switch; picks still follow the logical Tide (so an open-looking plant may give nothing) |
| Bone meal on a tide plant or a lumen bloom | No effect (not bonemealable) |
| Pistons | Pop all five (`POPPED`), dropping as a break with no tool |
| Ichor bucket on dry tidewrack (clicked or dispensed) | Submerges it (our bucket's overrides and its dispenser behaviour); an empty bucket takes the ichor back |
| Water bucket on dry tidewrack | The water is lost, as on kelp (vanilla's quirk) |
| Flowing ichor, water or lava against dry tidewrack | Doesn't enter (sources of ichor only, as waterlogging takes source water only) |
| Ichor or water flowing onto a plant | Chime bells and glowcaps wash away (as every small flower and mushroom); Endure blooms and lumen blooms hold it back (as sugar cane) |
| Hoppers, dispensers | A dispensed ichor bucket follows the bucket's rule (its own dispenser behaviour); dispensed bone meal does nothing to the three wild plants |
| Spectators, items, arrows | Don't ring chime bells (living, non-spectator entities only) |
| Many entities in one chime bell | One ring per 10 ticks |
| Endermen | Carry chime bells (small flowers); nothing else here is holdable |
| Bees | Visit chime bells outside Endure |
| Multiplayer | Server-authoritative; the first pick wins and the second finds it picked; states sync as block states |

## 9. Tech notes
- **Cost:** a tide plant's random tick is one attribute read. A switch scans 7 × 5 × 7 = 245
  positions (as the eyeblossom's): a basin's ~35 tidewrack switching costs about 8 600 block reads,
  twice a cycle (every 12.5 minutes), and each scheduled tick is one block. Chime bells do work only
  while something stands in them, and flip state at most once per 10 ticks. Lumen blooms add POIs
  (the hunt's cost budget already counts them). The Endure bloom feature reads the chunk's heightmap
  once per chunk, as the Flats' pools feature does; generation cost is measured with WP-063's sample
  (≤ 1.5× the Overworld, §7.3).
- **Synced data:** block states only.
- **Client:** cutout render type for all five; the Endure bloom's open model adds an emissive element;
  the hum is client-only.
- **Code touched:** `TideVentBlockEntity` (fill and drain handle tidewrack), `IchorBucketItem` (`use`
  and `emptyContents` fill a dry tidewrack), the basin feature (tidewrack on flooding floors, blooms on
  ring 3), a new `EndureBloomsFeature`, `SiftPlants` (ground rules), the loot condition
  `thesift:tide_flora_ready`, and a helper for the cycle stamp (`Tide.clockTicks` ÷ 30 000).
- **States:** tidewrack 2 × 2 × 16 = 64, Endure bloom 2 × 16 = 32; the models depend only on `open`,
  `submerged` and whether the stamp is 0, so the blockstate files map the 16 stamps onto two models.
- **en_us:** "Tidewrack", "Endure Bloom", "Glowcap", "Chime Bell Flower", "Lumen Bloom", "Potted Glowcap",
  "Potted Chime Bell Flower"; subtitles "Tidewrack opens", "Tidewrack closes", "Endure bloom opens",
  "Endure bloom closes", "Plant picked", "Chime bell rings", "Chime bell hums".
- **Risks:** the pick being heard could feel harsh: checked in the playtest notes. Emissive petals
  must read at 10 blocks in Endure's light without looking like eyes: checked in the previews.

## 10. Tests (GameTests, WP-064)
- Tidewrack opens in Thrive and closes in rising Flow (random tick forced); the ripple reaches a
  neighbour within 3 even if one of them is picked.
- A Thrive pick yields 1–2 fronds and stamps it; a second pick yields nothing; the next cycle's window
  yields again.
- **No duplication:** pick → break → nothing; no tool (Silk Touch, shears) drops the plant.
- **Fresh and returning patches:** a worldgen patch yields in its first window; a plant picked, then
  left without ticks while the clock advances a full cycle, yields in the next window.
- The logical pick: an open tidewrack picked in Endure (set by the clock) yields nothing and closes.
- Tidewrack holds ichor: the vent's fill submerges it and its drain dries it; an ichor bucket
  (clicked, and dispensed) submerges it and an empty bucket empties it; flowing ichor and water don't
  enter it.
- Fluids: flowing ichor washes away a chime bell and a glowcap and stops at an Endure bloom and a
  lumen bloom.
- An Endure bloom opens in Endure and closes after; it gives no block light; a pick yields 1 petal and
  emits `block_change` with the player as source (a test listener); the opening emits `block_change`
  with no source.
- A chime bell rings when a mob walks through (`block_activate` with the mob as source), not when a
  sneaking player does, at most once per 10 ticks; a bell set ringing by `/setblock` resets.
- Glowcap light 10; bone meal stops at 5 in the 9 × 3 × 9 box. Lumen bloom light 12, a `thesift:lumen`
  POI at its position, and no drop with Silk Touch.
- Outside the Sift: no switching, no yield.
- Worldgen sample (the fixed patches): tidewrack in basins (25–39 each), Endure blooms per shore chunk
  (target 0.1–0.3), chime bell patches, and surface lumen blooms with their rings 7–8 out (±1 for
  rounding).

## 11. Art and audio brief
- Five new ramps (`tidewrack`, `endure_bloom`, `glowcap`, `chime_bell`, `lumen`) added to palette.md
  with the textures; textures by `tools/art/build_textures.py`, checked by `check_palette.py`. All in
  world.md §3.1's healthy palette (warm, green, pale blue: the tidewrack olive and ochre, the bloom and
  the bells pale blue, the glowcap green, the lumen white-blue); none teal-black with cyan veins
  (blight).
- Previews: each plant in every state, 3 × 3 at 1× and 8×, beside vanilla neighbours (seagrass,
  eyeblossom, glow lichen, blue orchid, spore blossom), under each Tide's light, and from 10 blocks in
  Endure's light; with the Bloombud, **closed and open, tips glowing**, beside all five at 10 blocks in
  Endure's light, to check "the Sift has no buds" by eye (the open Endure bloom above all). The check
  passes on shape, not colour (§7.6): the open bloom reads as one continuous flat outline 2 px off the
  ground, the Bloombud as five separate points held at bud height. Blight's textures (M4) are checked against these when they are drawn.
- Sounds synthesized by `tools/audio/`, mono, matched for loudness against the eyeblossom's switch,
  sweet berries' pick and the small amethyst chimes.

## Critique log
- **Round 1 (2026-10-02): FAIL**, 5 must-fix; scores faithful 3, vanilla-native 3, readable 4,
  meaningful 3, distinct 4, connected 5, feasible 3, template 3, frozen-doc consistency 2. Each claim
  was checked in the 26.3 sources before acting (`BucketItem.emptyContents` waterlogs only with water;
  `FlowingFluid.canHoldAnyFluid` and `#washed_away_by_fluids`, which holds mushrooms and glow lichen
  but not poppies; `cross_emissive`'s `light_emission`; the bush's movement test and its break
  table's Fortune; `FireBlock`'s odds; `TideBasin`'s rings). Fixed:
  - M1, replanting duplicated the harvest: closing alone unpicks, every placement starts picked, and
    (with M2) no tool gives the plant.
  - M2, reagents could leave the flats and the waterline: tidewrack and Endure blooms drop no plant
    with any tool, as budding amethyst.
  - M3, the fluid model: the waterlogging pattern for ichor sources only, the vent setting the state
    directly, our bucket's own branch, and each plant's fluid rule stated.
  - M4, block light on healthy flora broke world.md §3.1: the open bloom is emissive (as the
    eyeblossom) and gives no light.
  - M5, Silk Touch made cheap lumen: the lumen bloom drops nothing.
  - Should-fix, all taken: the bell ring 7–11 out, on the approach; bees by `#bee_attractive`, stew by
    its own recipe, endermen carry chime bells, bees out in both Flows; no Fortune; the bush's movement
    test and the ringing reset in `onPlace`; the music hum its own sound and subtitle; flatter, splayed
    and flared shapes and a warm, non-blight tidewrack; souls, flammability, surfaces, tools and the
    Low Tide trigger; petal numbers against a lantern's planning price, with analogs.
  - Notes taken: basin sizes and the dry ring 3; `PASS`, not a swing; the ripple matches block and
    `open`; the switch's cost and its timing spread.
- **Round 2 (2026-10-02): FAIL**, 2 must-fix; scores faithful 4, vanilla-native 3, readable 4,
  meaningful 3, distinct 4, connected 5, feasible 3, template 4, frozen-doc consistency 3. Checked
  before acting: `#washed_away_by_fluids` **does** hold poppies, dandelions, blue orchids, spore
  blossoms and eyeblossoms (round 1's note said otherwise: its search matched only names containing
  "flower", "grass" and the like, and missed them; corrected here); sugar cane isn't in it;
  `BucketItem.use` targets a container only for water; `MushroomBlock`'s spread (1 in 25, at most 5 in
  9 × 3 × 9) and placement (`isSolidRender`); vanilla flowers' stew effects; the amethyst sound types.
  Fixed:
  - M1, a picked flag that only closing cleared stuck in unloaded chunks (fresh patches placed picked,
    returning patches never unpicked): a **cycle stamp** (`picked_cycle`), current-cycle only;
    worldgen places plants unpicked; a use fixes a stale open state; tests for both cases.
  - M2, the fluid rule rested on the false poppy claim: chime bells and glowcaps wash away (as every
    small flower and mushroom); Endure blooms and lumen blooms hold fluids back, as sugar cane.
  - Should-fix, all taken: the ichor bucket overrides `use` and `emptyContents` (dispensers too), and
    the water-bucket quirk is kept as kelp's; a cool, non-pink Endure bloom with only its centre and
    edges emissive, previewed beside the open and closed Bloombud; the bell ring a dense band at 7–8;
    lanterns making picking safe stated as the intended progression, with petals per hour and sinks;
    the sound register and the wild-only plants recorded as D-027 (the chime bell takes an amethyst
    sound type); the glowcap's bone meal restated against vanilla's mushrooms with their cap of 5;
    the Endure bloom not flammable; creative-only block items; "no spawns", not "keeps hostiles out".
  - Notes taken: the loot condition `thesift:tide_flora_ready`; the occlusion wording; the use's
    result, pick variants, en_us names and the small-flowers item tag; the stew's precedent; the
    route numbers; stale tidewrack closing in Endure listed.
- **Round 3 (2026-10-03, the last): PASS**, no must-fix; scores faithful 4, vanilla-native 4,
  readable 4, meaningful 4, distinct 4, connected 5, feasible 4, template 4, frozen-doc consistency
  4. The cycle stamp, the pick and break rules, and the fluid rules held against the 26.3 sources and
  our code. (A first run of this round stopped on a usage limit before reporting; it was run again.)
  The should-fix items, all taken:
  - S1, vanilla's dispensers know only vanilla buckets: the ichor bucket registers its own dispenser
    behaviour.
  - S2, there is no `LootItemConditionType` in 26.3: the condition is a `MapCodec` in
    `LOOT_CONDITION_TYPE`.
  - S3, the bell ring's test reads 7–8, and rings are surface only.
  - S4, lavender wasn't in §3.1's healthy palette: the bloom is periwinkle to pale blue.
  - Notes taken: a bucket into a plant's own cell is a break; mooshrooms read `FlowerBlock`, and the
    chime bell joins `#bee_food`; the stale-picked look listed; the band's citation; the preview's
    shape test; tide marks as a state of tide sand; glowcaps on the bank; the tide shell's
    "tidewrack" means fronds (D-027).
- **Frozen 2026-10-03** after round 3. Numbers in BALANCE.md.
