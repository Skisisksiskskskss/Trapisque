# Flora II (WP-064): the Tide's plants, the chime bell and the lights — DRAFT

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
8. **Glowcap pools as camps:** glowcaps' light (10) keeps spawns out of a cave pool's ring, so the
   Hollows have lit pockets you can find and use.
9. **Lumen that sleeps:** lumen blooms give light only in Endure.
10. **A fixed wild supply:** the tide plants never grow or spread. They come from world generation;
    shears (as seagrass) or Silk Touch move one, and it keeps its rules wherever it stands.

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
| 8 | Glowcap pools as camps | 4 | 5 | 5 | 4 | 3 | 4 | 5 | **30** |
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
- **10** is systems.md §2 applied: no bone meal and no spreading for tidewrack, Endure blooms and
  lumen blooms, so no farm makes reagents faster than the Tides allow.

### Decision: **"The patch you come back to"**: 1 + 2 + 3 + 4 + 10, with 7 and 8 in generation
- Tide plants switch like eyeblossoms (1), are picked like sweet berries (2) under the logical rule
  (3), and are heard when picked (4). Their supply is what the world grew (10).
- Lumen blooms come with drifts of chime bells (7). Glowcaps ring the Hollows' pools (8).

## The family
| Block (id) | What it is | Light | Tide rule | Drops (no tool) | Shears / Silk Touch |
|---|---|---|---|---|---|
| **Tidewrack** (`thesift:tidewrack`) | Ribbons of wrack lying on a tide basin's floor | 0 | Open in Thrive; closed otherwise | Open, unpicked, in Thrive: 1–2 fronds. Otherwise nothing | The plant |
| **Endure bloom** (`thesift:endure_bloom`) | A low star of petals on the waterline | 5 open, 0 closed | Open in Endure; closed otherwise | Open, unpicked, in Endure: 1 petal. Otherwise nothing | The plant |
| **Glowcap** (`thesift:glowcap`) | A cluster of small flat-topped cave fungi | 10 | — | Itself | Itself |
| **Chime bell flower** (`thesift:chime_bell_flower`) | Pale-blue bells hanging from an arched stem | 0 | Rings in every Tide; heard in Endure | Itself | Itself |
| **Lumen bloom** (`thesift:lumen_bloom`) | Three broad glassy petals cupped around a light | 12 | Lumen (repels hunters) in every Tide | Nothing | Silk Touch only: itself |
| Potted chime bell flower, potted glowcap | Flower-pot variants, as vanilla's | as above | — | The pot and the plant | — |

No potted Endure bloom, tidewrack or lumen bloom: a pot would show one state forever, and a potted
lumen bloom would be a second, cheaper lumen.

## Shared rules
- **Scope:** world.md §4: Sift plants grow, spread or take bone meal only where `sift_life` is true.
  At home, a tide plant never switches (the Tide attribute is −1) and a pick never yields, so a
  transplanted patch is decoration, as the bible says.
- **Switching (tidewrack, Endure bloom),** as `EyeblossomBlock`:
  - on a **random tick**, the block reads `thesift:gameplay/tide` at its position; if its open state
    is wrong for the Tide, it switches, clears `picked`, plays its long switch sound, sends one
    trail particle upward, emits `minecraft:block_change` with no entity source, and schedules a tick
    for every block of the same state within 3 horizontally and 2 vertically, after a delay of
    5–10 ticks per block of distance;
  - a **scheduled tick** does the same with the short switch sound (so a patch sounds like one long
    sweep followed by soft echoes);
  - at the default `random_tick_speed` 3, a block is picked about once every 1 365 ticks (4 096
    blocks in a section, 3 picks a tick), so a patch switches within about a minute of the Tide
    changing; the ripple makes it read as one event.
- **Picking (tidewrack, Endure bloom),** as `SweetBerryBushBlock.useWithoutItem`:
  - *use* on the plant with an empty hand, or with an item that has no use on it;
  - if it is open, unpicked, in the Sift, and the logical Tide is its Tide: it drops its harvest loot
    table at the plant, plays `thesift:block.flora.pick` (subtitle "Plant picked"), becomes picked,
    and emits `minecraft:block_change` with the player as source;
  - if it is open but the Tide has moved on, it closes at once (the short switch, no drop);
  - otherwise nothing happens (the hand swings as on any block).
- **Breaking** uses the block loot table: the same harvest under the same conditions, plus nothing
  else. With shears or Silk Touch it drops the plant instead (never both), as seagrass needs shears.
  Pistons pop it (`PushReaction.POPPED`, as poppies), which drops as a break with no tool.
- **No growth:** tidewrack, Endure blooms and lumen blooms take no bone meal and never spread
  (systems.md §2). A moved plant keeps its rules: an Endure bloom planted by a player's doorstep still
  opens in Endure, and still gives one petal a night. The number of plants is the number the world
  grew.

## 1. Tidewrack
- **Identity:** the low-tide reagent of the tide flats (world.md §4): you go down onto the bare basin
  floor in Thrive and pick it. Its fronds become cyan dye, gear traits and blub treats (WP-065).
- **Where it grows:** the tide basin feature places it on its own floor: each tide-sand floor cell
  has a 25 % chance, except the vent and the four cells beside it (the vent stays visible). A 14 × 14
  basin holds about 35. Basins are one chunk in five (D-026), so a basin is a short walk away.
  Placeable by players on tide sand, healthy sculk, Sift Soil or `#minecraft:dirt`, as other Sift
  plants (SiftPlants).
- **Holding ichor.** Basins flood over tidewrack every Endure, so it holds ichor as kelp holds water:
  - a boolean state `submerged`; its fluid state is an ichor source while it is true;
  - it is a `LiquidBlockContainer` for ichor only (`canPlaceLiquid` is true for ichor while dry), and
    a `BucketPickup` that gives up its ichor, as a waterlogged block does;
  - so flowing ichor and an ichor bucket submerge it, and the vent's fill and drain handle it: the
    vent's fill also submerges dry tidewrack, and its drain dries it (one line each in
    `TideVentBlockEntity`). Any other fluid washes it away (as `washed_away_by_fluids` blocks).
- **States:** `open` (bool), `picked` (bool), `submerged` (bool).
- **Properties:** no collision, instant break, `SoundType.WET_GRASS` (seagrass's), offset XZ, map
  colour `WATER` (as kelp), pushes `POPPED`, not flammable, random ticks.
- **Look** (cutout, 16 × 16, a ramp `tidewrack` added to palette.md: deep teal to bright cyan-green,
  with an olive shade for the stems):
  - **closed:** the ribbons curled tight into a flat knot about 3 px high and 10 px across, lying on
    the sand: dark and dull;
  - **open:** the ribbons spread flat across the block in a loose star, 1–2 px high, glossy, showing
    their bright cyan undersides;
  - **picked:** the bare olive stems, flat, with no ribbons;
  - nothing round and nothing on a stalk: wrack lies down.
  Model: a flat plane 1 px above the floor (as a carpet's height) plus a low cross for the knot.
- **Sounds:** `tidewrack.open` (a wet unfurling rustle, 2 variants, subtitle "Tidewrack opens"),
  `tidewrack.close` (a wet curl, 2 variants, "Tidewrack closes"); long and short versions as the
  eyeblossom's (the short one quieter).
- **Loot:** harvest (and break, under the conditions): 1–2 fronds (uniform), as sweet berries give
  1–2 at age 2. Fortune doesn't apply, as for berries.
- **Tags:** `#thesift:tide_flora` (new: the two tide plants, for tests and future rules).
- **Compost:** low (as kelp and seagrass).

## 2. Endure bloom
- **Identity:** the high tide's flower (world.md §4): it opens along the waterline as Endure begins,
  and its petal is the rare reagent for lumen lanterns and traits (items.md). You take it in the dark,
  while the hunters listen.
- **Where it grows:** on the waterline: a ground block (healthy sculk, Sift Soil, tide sand) with air
  above and an ichor block beside it at the same height. A feature, `thesift:endure_blooms`, run once
  per chunk with a 1-in-3 chance, scans the chunk's surface columns (the heightmap, as the Flats'
  pools feature does) for waterline cells; if any exist, it picks one and places 2–5 blooms on
  waterline cells within 3 blocks of it. The basin feature also gives a basin's rim (its Endure
  waterline) 2–4 blooms with a 30 % chance. Measured in the worldgen sample (target: about one patch
  per 4–6 chunks with any shore; tuned there).
- **States:** `open` (bool), `picked` (bool).
- **Properties:** no collision, instant break, `SoundType.GRASS`, offset XZ, map colour `PLANT`,
  pushes `POPPED`, flammable as flowers, random ticks. Light: **5 when open, 0 when closed** (so an
  open patch is seen in Endure's dark, and the light changes with the state, as a redstone lamp's).
- **Look** (cutout, a ramp `endure_bloom`: grey-violet leaves, pale lavender to silver-white petals;
  cool, never the Bloombud's warm tips):
  - **closed:** a low rosette of furled grey-violet leaves, 3 px high, no stalk;
  - **open:** an eight-pointed star of pale lavender petals lying flat 2 px above the ground with a
    silver-white centre: a star on the ground, not points on a bud;
  - **picked:** the open sepals without petals;
  - its light is a low, even glow (no particles but the switch's trail), so it reads as a flower
    lying open, not as eyes.
- **Sounds:** `endure_bloom.open` (a soft glassy swell, 2 variants, "Endure bloom opens"),
  `endure_bloom.close` (the swell falling, 2 variants, "Endure bloom closes"), long and short.
- **Loot:** harvest: 1 petal. Rare by where it grows (a few per shore patch, one petal each per
  Endure), as torchflower seeds are rare by their source.
- **The decision it makes:** a patch opening at Endure's start is a `block_change` (no entity), so
  listeners within 16 turn toward the waterline then; each pick is a `block_change` with you as the
  source, which sneaking doesn't muffle. So you pick fast and leave, or wait out the first minute
  while the hunters come to look and go, or wall the shore with wool first (wool between a sound and
  a listener blocks it, as vanilla's occlusion does).

## 3. Glowcap
- **Identity:** a small luminous cave fungus (world.md §4, light 10) that rings glowcap pools: the
  Hollows' lit pockets, where vanilla's spawn rule (block light 0) keeps hostiles out.
- **Where it grows:** WP-063's glowcap pools (a Should): ichor pools in the Hollows ringed by
  glowcaps on their floor cells within 2 of the edge; and scattered clusters on Hollows floors, about
  as common as glow lichen's patches. On the surface, nowhere.
- **Properties:** no collision, instant break, `SoundType.FUNGUS`, offset XZ, map colour
  `COLOR_LIGHT_GREEN`, pushes `POPPED`, light **10** (the soul lantern's). Survives on any sturdy top
  face (a cave floor of any stone). Bone meal, in the Sift only: one new glowcap on a free sturdy floor
  within 2 blocks whose light is below 13 (as mushrooms, which need light below 13 to spread).
- **Look** (cutout, a ramp `glowcap`: pale seafoam caps, darker teal-grey gills and stems): three
  small caps on short stems, each cap a flat disc wider than it is tall (4 px wide, 1 px thick),
  ankle-high (6 px). Flat shelves, never a dome on a stalk, and cool, never warm.
- **Loot:** itself. **Compost:** medium (as mushrooms). **Potted** variant.

## 4. Chime bell flower
- **Identity:** canon's "pale-blue flowers" (world.md §4) with a sound: walking through it rings it,
  a vibration, so in Endure a careless step is heard (system_hunt.md §9).
- **Where it grows:** flower patches in Singer's Meadow (a random patch: 1 chunk in 4, 12 tries
  within 6 blocks) and the Ichor Flats (1 chunk in 6); a drift around half of the lumen blooms
  (concept 7: 6–10 flowers at 2–5 blocks from the bloom). Lullaby Hills (M5) will be its home.
- **Ringing** (system_hunt.md §9, decided there): a living entity that isn't a spectator, moving
  through the block (its position changed this tick) and not stepping carefully
  (`isSteppingCarefully`: a sneaking player), rings it:
  - the state `ringing` becomes true, a scheduled tick 10 later sets it false, and while it is true
    the flower doesn't ring again (so at most once per 10 ticks, with no block entity);
  - a ring plays `chime_bell.ring` (4 variants, pitch-varied, subtitle "Chime bell rings") and emits
    `minecraft:block_activate` with the walker as source;
  - the model shows the bells swung while `ringing` is true.
- **Music:** in the M1 music reaction (`animateTick` and the client music buffer, world.md §3), a
  chime bell within 12 blocks of music now and then chimes softly on the client alone (a local sound
  and a note particle). It is decoration, makes no vibration, and is heard in every Tide.
- **Properties:** a `FlowerBlock` (suspicious stew: Slow Falling, 7 s); no collision, instant break,
  `SoundType.GRASS`, offset XZ, map colour `PLANT`, pushes `POPPED`. Tags: `#minecraft:flowers` and
  `#minecraft:small_flowers` (bees, stew), so bees visit it in Thrive. A light blue dye recipe
  (WP-065, one flower → one dye, as blue orchid).
- **Look** (cutout, a ramp `chime_bell`: pale ice-blue bells, a muted green stem): an arched stem
  10 px high with three bells hanging mouth-down from its curve. Open bells, hanging: nothing closed,
  nothing upright.
- **Loot:** itself. **Compost:** medium (as flowers). **Potted** variant.

## 5. Lumen bloom
- **Identity:** the natural lumen (world.md §2): a rare plant whose light hunters won't enter
  (system_hunt.md §6: no hunter within 6, no spawns within 8). Finding one in Endure is finding a
  camp.
- **Where it grows:** alone or in pairs on healthy sculk or Sift Soil in Singer's Meadow and the
  Ichor Flats (1 chunk in 12), and on Hollows floors (1 chunk in 24). About half come with a chime
  bell drift (§4), so the safe pocket is reached by sneaking.
- **Properties:** no collision, instant break, `SoundType.SPORE_BLOSSOM`, no offset (it stands
  centred, as a light should), map colour `COLOR_LIGHT_BLUE`, pushes `POPPED`, light **12**, no random
  ticks, no bone meal. Its states belong to the `thesift:lumen` POI type (system_hunt.md §11,
  registered with Fabric's `PoiHelper`).
- **Look** (cutout, a ramp `lumen`: cool white to pale moonlit blue, with a white core): three broad
  glassy petals cupped open around a bright core, 10 px high, facing up. Always open. Now and then
  (`animateTick`, 1 in 8) a pale mote drifts up from the core, so a lumen bloom reads as lumen at a
  glance, by shape, colour and motes, never as a bud's warm points.
- **Loot:** nothing without Silk Touch; with it, itself. A natural lumen can be moved but never
  multiplied, and the lumen lantern (Endure petals) stays the way to make more (WP-065).
- **Compost:** low (the Silk-Touched item).

## 6. Per Tide
| | Thrive | Flow (rising) | Endure | Flow (falling) |
|---|---|---|---|---|
| Tidewrack | Opens; picked for fronds; the basin is bare | Closes; the basin floods over it | Closed, submerged | Closed; the basin drains |
| Endure bloom | Closed | Closed | Opens (a sweep of light along the waterline); picked for petals; picking is heard | Closes |
| Glowcap | Light 10 | Light 10 | Light 10 | Light 10 |
| Chime bell | Rings; nobody listens | Rings | Rings, and is heard | Rings |
| Lumen bloom | Repels | Repels | Repels | Repels |

## 7. Numbers (copied to BALANCE.md on freeze)
| Number | Value | Vanilla analog | Why |
|---|---|---|---|
| Tidewrack harvest | 1–2 fronds per Thrive per plant | sweet berries 1–2 (age 2), 2–3 (age 3) | A basin's ~35 plants give about 50 fronds a cycle |
| Endure petal harvest | 1 per Endure per bloom | torchflower seeds (rare by source) | Rare: a few blooms per shore patch |
| Switch timing | random tick (~68 s mean), ripple 5–10 ticks per block within 3 | eyeblossom | A patch switches as one event |
| Light | glowcap 10; lumen bloom 12; Endure bloom 5 open | soul lantern 10; glow berries 14; glow lichen 7 | Glowcap a pocket, lumen a camp, the bloom a mark |
| Chime cooldown | 10 ticks (system_hunt.md §9) | — | — |
| Tidewrack density | 25 % of a basin's floor | — | A short pick, not a field |
| Endure bloom patches | 1 chunk in 3 tries; 2–5 on shore cells; basin rims 30 % | — | Tuned in the sample |
| Chime bell patches | Meadow 1 in 4 chunks, Flats 1 in 6 | vanilla flower patches | Common enough to step in |
| Lumen bloom | surface 1 chunk in 12; Hollows 1 in 24 | — | Rare: a find, not a given |

## 8. Edge cases
| Case | Rule |
|---|---|
| A cofferdam keeps the ichor out in Endure | Tidewrack stays closed and gives nothing (the logical Tide, systems.md) |
| An Endure bloom moved into a dry field | Opens in Endure anyway; one petal a night |
| A tide plant at home | Never switches; never yields; decoration |
| A chunk unloaded through a Tide change | Its plants switch on their next random ticks after loading; a pick checks the logical Tide, so a stale open plant gives nothing and closes |
| `advance_time false` | The Tides stop, so the plants stop switching (as eyeblossoms when the sun stops) |
| `random_tick_speed 0` | Plants never switch; picks still follow the logical Tide (so they may give nothing) |
| Bone meal on a tide plant or a lumen bloom | No effect (not bonemealable) |
| Pistons | Pop all five (`POPPED`), dropping as a break with no tool |
| Ichor bucket on dry tidewrack | Submerges it; a bucket picks the ichor back up |
| Water (a modded or carried bucket) | Washes tidewrack, blooms and flowers away, as vanilla fluids do |
| Spectators, items, arrows | Don't ring chime bells (living entities only) |
| Many entities in one chime bell | One ring per 10 ticks |
| Endermen | Don't carry these plants (not in `#enderman_holdable`) |
| Silk Touch on a picked plant | Drops the plant; it comes back unpicked and closed |
| Two players picking the same plant | The first wins; the second finds it picked |

## 9. Tech notes
- **Cost:** the tide plants' random ticks are one attribute read; a switch scans 7 × 5 × 7 = 245
  positions (as the eyeblossom's) and schedules a few ticks. A basin's ~35 tidewrack switching twice
  a cycle is a few thousand reads every 12.5 minutes. Chime bells do work only while something
  stands in them, and a state flip per 10 ticks at most. Lumen blooms add POIs (the hunt's cost
  budget already counts them). The Endure bloom feature reads the chunk's heightmap once per chunk,
  as the Flats' pools feature does; generation cost is measured in WP-063/064's sample (≤ 1.5× the
  Overworld, §7.3).
- **Synced data:** block states only.
- **Client:** cutout render type for all five; the music chime is client-only.
- **Vent change:** the vent fills air, flowing ichor, and dry tidewrack (to submerged); it drains
  ichor and submerged tidewrack (to dry).
- **Risks:** the Endure bloom's light toggling causes light updates at every switch (bounded by the
  patch sizes); the pick being heard could feel harsh, so it is checked in the playtest notes.

## 10. Tests (GameTests, WP-064)
- Tidewrack opens in Thrive and closes in rising Flow (random tick forced); the ripple reaches a
  neighbour within 3.
- A Thrive pick yields 1–2 fronds and marks it picked; a second pick yields nothing; it unpicks on
  closing.
- The logical pick: an open tidewrack picked in Endure (set by the clock) yields nothing and closes.
- Tidewrack holds ichor: the vent's fill submerges it, its drain dries it; a bucket submerges it.
- An Endure bloom opens in Endure (light 5) and closes after (light 0); a pick yields 1 petal; the pick
  emits `block_change` with the player as source (a test listener).
- Shears give the plant, not the harvest.
- A chime bell rings when a mob walks through (`block_activate` with the mob as source), not when a
  sneaking player does, at most once per 10 ticks.
- Glowcap light 10; lumen bloom light 12 and a `thesift:lumen` POI at its position.
- At home (the Overworld test level): no switching, no yield.
- Worldgen sample (the fixed patches): tidewrack in basins, Endure blooms on shores, chime bells and
  lumen blooms counted against the targets above.

## 11. Art and audio brief
- Five new ramps (`tidewrack`, `endure_bloom`, `glowcap`, `chime_bell`, `lumen`) added to palette.md
  with the textures; textures by `tools/art/build_textures.py`, checked by `check_palette.py`.
- Previews: each plant in every state, 3 × 3 at 1× and 8×, beside vanilla neighbours (seagrass,
  eyeblossom, glow lichen, blue orchid, spore blossom), under each Tide's light; and the Bloombud's
  closed bud beside all five, to check "the Sift has no buds" by eye.
- Sounds synthesized by `tools/audio/`, mono, matched against the eyeblossom's switch, sweet berries'
  pick and the small amethyst chimes for loudness.

## Critique log
*(none yet)*
