# The Sift palette (WP-041)

The colour source of truth for every Sift texture. The generators in `tools/art/` read the ramps from this file, and
`tools/art/check_palette.py` fails the build of art if any texture uses a colour that is not in the ramps its row
below allows.

**Rules.**
- **Each texture draws only from its material ramps** (the table at the end). A new colour means a new ramp entry here first.
- Ramps run dark → light. Light comes from the top-left: highlights take the right end of a ramp, shadows the left.
- A texture uses roughly 4–10 of these colours, as vanilla does (animated liquids: per frame).
- Alpha is free for fully transparent pixels (cutout plants, leaves, particles) and for the two translucent strips
  (membrane 176–224); every visible pixel's RGB must still come from a ramp.
- Hue shifts along a ramp on purpose: shadows lean cooler, highlights warmer, as vanilla ramps do.
- **Tiling:** every block texture tiles seamlessly and avoids features the eye can follow from block to block (no lines or tufts on a grid). Ground blocks ship variants (`_2`, `_3`), and healthy sculk's top also takes random rotations, as vanilla grass does.

## Ramps

| Ramp | Colours (dark → light) | Notes |
|---|---|---|
| `hymnstone` | `#5a2f3d` `#74404f` `#8e5262` `#a86474` `#bd7a87` `#d1949c` `#e2b0b3` | Rose-mauve stone of the teasers' spires and canyon walls (owner rework) |
| `gatestone` | `#1d0c14` `#2c1520` `#3f1d2a` | Darker-than-hymnstone body for the unbreakable gate frame |
| `glyph` | `#2f7f8c` `#5fd3d6` `#b8fbf1` | Pale-cyan inlay: groove, fill, glint |
| `healthy_sculk` | `#b9475a` `#d95a67` `#e4626a` `#ed717f` `#f37e8e` `#f9909d` `#ffaab4` | The teaser's pink-coral grass, sampled from the vanilla first look (owner rework) |
| `songwood_bark` | `#1a2426` `#233236` `#2d4044` `#3a5054` `#4a6165` `#5d7579` | Dark charcoal-teal trunks of the teasers' trees; the first entry is a flute hole's bore |
| `flute` | `#8fa3d6` `#c4d4f2` `#eef4ff` | The pale lips of the flute holes |
| `songwood_planks` | `#2f4246` `#3a5054` `#4b6266` `#5d767a` `#708a8e` `#86a0a3` | Teal-grey planks cut from the dark trunks |
| `songwood_leaves` | `#6f8790` `#8ea6af` `#a9c0c8` `#c2d5dc` `#d9e7ec` | Pale icy grey-blue canopy of the teasers' trees (untinted) |
| `tide_sand` | `#6e6680` `#857d98` `#9b94ac` `#afa9bf` `#c3bed1` `#d6d2e1` | Pale grey-violet silt |
| `ichor` | `#0f5e7c` `#177e9e` `#229cb8` `#3abccb` `#78dad9` `#c2f5ee` | Ichor, the Sift's clear turquoise water (D-024); textures are translucent |
| `membrane` | `#0b3f55` `#13687e` `#2598a8` `#55c8cc` `#a3eee8` `#e0fffa` | The Sift membrane's cyan shimmer (translucent) |
| `pail` | `#2b2b33` `#4b4b56` `#6d6d7a` `#9696a2` `#c2c2cb` `#e6e6ec` | Bucket metal |
| `blub` | `#3f6a8e` `#4f81a8` `#5f95ba` `#7aabc8` `#9cc2d6` `#c4dde8` | The Blub's blue, sampled from the first look (owner rework): the only blue mob in the Sift |
| `blub_eye` | `#24204a` `#3d3570` | The Blub's dark violet slit eyes (first look) |
| `soil` | `#3e2a2c` `#524145` `#6e4a4e` `#875457` `#a2636a` `#c27076` | Sift soil: the maroon earth under the teaser's grass hill (owner rework) |
| `particle` | `#f0cf8c` `#f9e6b0` `#fff4d6` `#fffdf5` `#ffd9d2` | Glow cores, trill motes |

## Texture → allowed ramps

| Texture (under `assets/thesift/textures/`) | Ramps |
|---|---|
| `block/hymnstone.png` | hymnstone |
| `block/hymnstone_2.png` | hymnstone |
| `block/hymnstone_3.png` | hymnstone |
| `block/hymnstone_bricks.png` | hymnstone |
| `block/healthy_sculk_top.png` | healthy_sculk |
| `block/healthy_sculk_top_2.png` | healthy_sculk |
| `block/healthy_sculk_top_3.png` | healthy_sculk |
| `block/healthy_sculk_side.png` | healthy_sculk, soil |
| `block/healthy_sculk_grass.png` | healthy_sculk |
| `block/tall_healthy_sculk_grass_bottom.png` | healthy_sculk |
| `block/tall_healthy_sculk_grass_top.png` | healthy_sculk |
| `block/songwood_log.png` | songwood_bark, flute |
| `block/songwood_log_2.png` | songwood_bark, flute |
| `block/songwood_log_top.png` | songwood_bark, songwood_planks, flute |
| `block/songwood_planks.png` | songwood_planks |
| `block/songwood_leaves.png` | songwood_leaves |
| `block/songwood_leaves_2.png` | songwood_leaves |
| `block/songwood_sapling.png` | songwood_bark, songwood_leaves, flute |
| `block/songwood_drapes.png` | songwood_leaves |
| `block/songwood_drapes_tip.png` | songwood_leaves |
| `block/sift_soil.png` | soil |
| `block/tide_sand.png` | tide_sand |
| `block/tide_sand_2.png` | tide_sand |
| `block/tide_sand_3.png` | tide_sand |
| `block/tide_vent_top.png` | hymnstone, ichor |
| `block/tide_vent_side.png` | hymnstone, ichor |
| `block/gatestone.png` | gatestone, hymnstone, glyph |
| `block/gatestone_top.png` | gatestone, hymnstone, glyph |
| `block/sift_membrane.png` | membrane |
| `block/ichor_still.png` | ichor |
| `block/ichor_flow.png` | ichor |
| `block/ichor_overlay.png` | ichor |
| `item/ichor_bucket.png` | pail, ichor |
| `particle/glow_petal.png` | healthy_sculk, particle |
| `particle/trill.png` | particle |
| `entity/blub/blub.png` | blub, blub_eye |
| `entity/blub/blub_glow.png` | membrane |
| `item/blub_spawn_egg.png` | blub, songwood_bark |
