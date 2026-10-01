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
| `hymnstone` | `#3b1620` `#57222d` `#72303b` `#8c3f4a` `#a4525a` `#bb6a6c` `#cf8680` | Rose-crimson stone. Base `#8c3f4a` sits between netherrack and stone in value |
| `gatestone` | `#1d0c14` `#2c1520` `#3f1d2a` | Darker-than-hymnstone body for the unbreakable gate frame |
| `glyph` | `#2f7f8c` `#5fd3d6` `#b8fbf1` | Pale-cyan inlay: groove, fill, glint |
| `healthy_sculk` | `#7c2635` `#a9394a` `#cc4f5a` `#e3636c` `#f27b86` `#fb97a0` `#ffbdbd` | Coral-pink petals (the vanilla first look's grass) |
| `songwood_bark` | `#15122a` `#221d3d` `#2e2750` `#3c3463` `#4d4478` `#605a8f` | Dark blue-violet; the first entry is also a flute hole's bore |
| `flute` | `#8fa3d6` `#c4d4f2` `#eef4ff` | The pale lips of the flute holes |
| `songwood_planks` | `#3a374f` `#4f4b66` `#625e7c` `#75718f` `#8a86a3` `#a09cb8` | Muted violet-blue grey |
| `songwood_leaves` | `#6d86b8` `#9bb6e0` `#c6d9f2` `#e4edf9` `#f9fbff` | White leaves edged pale blue (untinted) |
| `tide_sand` | `#6e6680` `#857d98` `#9b94ac` `#afa9bf` `#c3bed1` `#d6d2e1` | Pale grey-violet silt |
| `ichor_violet` | `#140c26` `#28174a` `#4a2172` `#8a2f8e` `#d45fbf` `#f5c2ee` | Ichor's deep body and magenta sheen |
| `ichor_teal` | `#0d2b3b` `#155466` `#1e8088` `#3cc0bd` `#a8f6ec` | Ichor's teal body and cyan sheen |
| `membrane` | `#0b3f55` `#13687e` `#2598a8` `#55c8cc` `#a3eee8` `#e0fffa` | The Sift membrane's cyan shimmer (translucent) |
| `pail` | `#2b2b33` `#4b4b56` `#6d6d7a` `#9696a2` `#c2c2cb` `#e6e6ec` | Bucket metal |
| `blub` | `#2c4f8f` `#3f6fb8` `#5f93d8` `#8ab6ee` `#b9d8fa` `#e6f3ff` | The Blub's soft pale blue: the only pale-blue mob in the Sift (mob_blub.md) |
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
| `block/healthy_sculk_side.png` | healthy_sculk, hymnstone |
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
| `block/tide_sand.png` | tide_sand |
| `block/tide_sand_2.png` | tide_sand |
| `block/tide_sand_3.png` | tide_sand |
| `block/tide_vent_top.png` | hymnstone, ichor_violet, ichor_teal |
| `block/tide_vent_side.png` | hymnstone, ichor_violet, ichor_teal |
| `block/gatestone.png` | gatestone, hymnstone, glyph |
| `block/gatestone_top.png` | gatestone, hymnstone, glyph |
| `block/sift_membrane.png` | membrane |
| `block/ichor_still.png` | ichor_violet, ichor_teal |
| `block/ichor_flow.png` | ichor_violet, ichor_teal |
| `item/ichor_bucket.png` | pail, ichor_violet, ichor_teal |
| `particle/glow_petal.png` | healthy_sculk, particle |
| `particle/trill.png` | particle |
| `entity/blub/blub.png` | blub, songwood_bark, particle |
| `entity/blub/blub_glow.png` | membrane |
| `item/blub_spawn_egg.png` | blub, songwood_bark |
