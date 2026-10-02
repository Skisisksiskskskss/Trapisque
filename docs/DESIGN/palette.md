# The Sift palette (WP-041)

The colour source of truth for every Sift texture. The generators in `tools/art/` read the ramps from this file, and
`tools/art/check_palette.py` fails the build of art if any texture uses a colour that is not in the ramps its row
below allows.

**Rules.**
- **Each texture draws only from its material ramps** (the table at the end). A new colour means a new ramp entry here first.
- Ramps run dark → light. Light comes from the top-left: highlights take the right end of a ramp, shadows the left.
- A texture uses roughly 6–12 of these colours, as vanilla does (animated liquids: per frame). Owner playtest 2 (D-026): vanilla's
  look is per-pixel grain in many close shades with small clumps, not flat bands of three or four tones.
- Alpha is free for fully transparent pixels (cutout plants, leaves, particles) and for the two translucent strips
  (membrane 176–224, ichor 200–230, its overlay 150); every visible pixel's RGB must still come from a ramp.
- Hue shifts along a ramp on purpose: shadows lean cooler, highlights warmer, as vanilla ramps do.
- **Tiling:** every block texture tiles seamlessly and avoids features the eye can follow from block to block (no lines or tufts on a grid). Ground blocks ship variants (`_2`, `_3`), and healthy sculk's top also takes random rotations, as vanilla grass does.

## Ramps

| Ramp | Colours (dark → light) | Notes |
|---|---|---|
| `hymnstone` | `#3f2030` `#50293a` `#623244` `#743d4f` `#87495b` `#9a5768` `#ad6776` `#c07b86` `#d39498` | Rose-mauve stone of the teasers' spires and canyon walls; nine shades for vanilla-stone grain (owner playtest 2) |
| `gatestone` | `#1d0c14` `#2c1520` `#3f1d2a` | Darker-than-hymnstone body for the unbreakable gate frame |
| `glyph` | `#2f7f8c` `#5fd3d6` `#b8fbf1` | Pale-cyan inlay: groove, fill, glint |
| `healthy_sculk` | `#9c384d` `#b9475a` `#cd5263` `#de5f6b` `#ea6d79` `#f37e8a` `#f9929d` `#ffaab4` | The teaser's pink-coral grass, sampled from the vanilla first look; eight shades for vanilla grass's per-pixel speckle (owner playtest 2) |
| `songwood_bark` | `#141c20` `#1b262a` `#223035` `#2b3b40` `#35474c` `#42565b` `#52676b` `#657b7e` | Dark charcoal-teal trunks of the teasers' trees; the first entry is a flute hole's bore |
| `flute` | `#8fa3d6` `#c4d4f2` `#eef4ff` | The pale lips of the flute holes |
| `songwood_planks` | `#2f4246` `#3a5054` `#4b6266` `#5d767a` `#708a8e` `#86a0a3` | Teal-grey planks cut from the dark trunks |
| `songwood_leaves` | `#3f5361` `#50677a` `#66808f` `#7f99a6` `#99b2bd` `#b3c9d2` `#cddde4` `#e6f0f3` | Pale icy grey-blue canopy of the teasers' trees, with blue shade inside the clumps so it reads as leaves (owner playtest 2; untinted) |
| `tide_sand` | `#5f5873` `#6e6680` `#857d98` `#9b94ac` `#afa9bf` `#c3bed1` `#d6d2e1` | Pale grey-violet silt |
| `ichor` | `#1f7a92` `#23879d` `#2f96aa` `#3fa7b6` `#56b9c0` `#72c8c3` `#93d4bf` `#b6dcae` `#d4dd9f` `#ecd79a` `#f2c7a2` `#f1b4b5` `#e8a7c8` `#d7a3dc` `#bea5ea` `#a3aaf0` `#889fe4` `#6d97d2` `#5590c3` `#3a86ae` `#155a73` `#e8f8f6` | Ichor, the Sift's water (D-024) with a soap bubble's sheen (owner playtest 2, D-026): the first twenty run once round the film's colour cycle (turquoise, mint, gold, rose, lilac, periwinkle and back), so neighbouring entries are close and the sheen flows without hard edges; then a deep shade and a highlight. Not dark → light. The fluid renderer (`thesift.client.IchorSheen`) lays the film cycle across the world in broad bands, blended corner to corner; the bucket and the vents draw from the ramp directly |
| `ichor_sheen` | `#b4c8ce` `#c3d5da` `#d0dfe3` `#dce8ea` `#e6eff0` `#eff5f4` `#f7faf8` | Ichor's shimmer: the pale, nearly grey still, flowing and overlay textures that the tint colours, as vanilla's water textures are grey under the biome's tint. Translucent (alpha 150–230) |
| `membrane` | `#0b3f55` `#13687e` `#2598a8` `#55c8cc` `#a3eee8` `#e0fffa` | The Sift membrane's cyan shimmer (translucent) |
| `pail` | `#2b2b33` `#4b4b56` `#6d6d7a` `#9696a2` `#c2c2cb` `#e6e6ec` | Bucket metal |
| `blub` | `#3f6a8e` `#4f81a8` `#5f95ba` `#7aabc8` `#9cc2d6` `#c4dde8` | The Blub's blue, sampled from the first look (owner rework): the only blue mob in the Sift |
| `blub_eye` | `#24204a` `#3d3570` | The Blub's dark violet slit eyes (first look) |
| `soil` | `#34222a` `#432d33` `#533a3f` `#64454a` `#765155` `#8a5e60` `#9f6d6d` `#b5807c` | Sift soil: the maroon earth under the teaser's grass hill, eight shades as vanilla dirt (owner playtest 2) |
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
| `block/ichor_still.png` | ichor_sheen |
| `block/ichor_flow.png` | ichor_sheen |
| `block/ichor_overlay.png` | ichor_sheen |
| `item/ichor_bucket.png` | pail, ichor |
| `particle/glow_petal.png` | healthy_sculk, particle |
| `particle/trill.png` | particle |
| `entity/blub/blub.png` | blub, blub_eye |
| `entity/blub/blub_glow.png` | membrane |
| `item/blub_spawn_egg.png` | blub, songwood_bark |
