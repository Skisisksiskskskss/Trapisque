# Living in the Sift: rifts, ores, food and new biomes (WP-080) — FROZEN 2026-10-03

The owner (2026-10-03): the dimension "is very incomplete and lacks basic things like ores,
progression, and biomes; I want to be able to spawn in this dimension in survival from nothing and be
able to actually progress and do stuff; incorporate rifts and how you don't necessarily need to go
through the Deep Dark to enter or exit the Sift." This doc decides how, and overrides D-007's
"entry through the Ancient City frame only" and D-009's "rifts after 1.0" (D-032).

**Canon used** (RESEARCH.md §2 rows 5, 6): rifts are "temporary portals leading to and from the Sift";
"there are lots of rifts that appear throughout the world. If you do stumble across and then into one,
it will transport you to the Sift"; the rift closes behind you; the Grand Illusioner's staff opens and
closes rifts "at will". The Sift is "red and orange stone, green vegetation, ichor, and sculk".

## 1. What a player needs, and where it comes from
A survival run from nothing, vanilla's ladder, with the Sift's materials:

| Step | Vanilla | In the Sift | New? |
|---|---|---|---|
| Wood, crafting table, sticks, wooden tools | logs, planks | songwood | — (already) |
| Stone tools, furnace | cobblestone | **cobbled hymnstone** (what a pickaxe gets from hymnstone, as cobblestone from stone) joins `#stone_tool_materials` and `#stone_crafting_materials`; the full stone family follows (D-033) | tags |
| Light | coal, torches | charcoal from songwood logs; **hymnstone coal ore** | ore |
| Iron, copper, gold, redstone, lapis, diamond | ores in stone | **hymnstone ores** of each, dropping vanilla's items | 7 ores |
| Emerald | mountain ore | **hymnstone emerald ore** in the Hymnstone Rise only (as mountains) | ore |
| Food | crops, animals, apples | **songfruit** (leaves), **glowcap stew**, **tide roots** (a crop) | 3 foods |
| String, wool, beds, bows | spiders, sheep | **3 songwood drapes → 1 string** (drapes need shears or Silk Touch, as vines) | recipe |
| Leather, feathers, bones, gunpowder, flint | animals, mobs, gravel | **the Overworld, through a rift**: the Sift is a place to live, not a closed world | — |
| A way home and back | portals | **rifts** (§2) and the **rift fork** (§2.4) | entity, item |

### Concept ladder: the Sift's food
- **Diverge:** (1) songwood drops a fruit, as oak drops apples; (2) glowcap stew, as mushroom stew;
  (3) a crop of the ichor shores; (4) blubs as food (rejected outright: the pet); (5) a fish in ichor;
  (6) Endure petals as a snack; (7) edible tidewrack fronds.
- **Converge** (faithful, vanilla-native, readable, distinct, feasible; 1–5): 1 = 23, 2 = 24, 3 = 24, 5 = 17
  (a new mob for one food), 6 = 14 (the rare reagent), 7 = 16 (the blub's treat).
- **Decision: 1 + 2 + 3.** A forager's fruit, a cook's stew from a farmable fungus, and a farmer's crop.

**Tide root** (`thesift:tide_roots`): a pale root crop that grows on **tide sand next to ichor**, as
sugar cane needs water beside it. Plant a tide root on tide sand beside ichor; it grows in 4 stages,
as carrots do (random ticks), and bone meal speeds it. Wild patches grow at ichor shores. A ripe crop
drops 2–4 roots (Fortune adds, as carrots). Raw: 2 hunger (a potato's 1, a carrot's 3); **baked**: 5
hunger, saturation 6.0 (a baked potato's). Not on farmland: ichor isn't water, and this keeps vanilla's
farmland rule untouched.

**Songfruit** (`thesift:songfruit`): songwood leaves drop it as oak leaves drop apples (0.5 %, Fortune
raises it as vanilla's apple). 4 hunger, 2.4 saturation (an apple's).

**Glowcap stew**: a bowl and two glowcaps (shapeless); 6 hunger, 7.2 saturation (mushroom stew's).
Glowcaps already grow from bone meal in the Sift.

## 2. Rifts
### Concept ladder: how rifts work
- **Diverge:** (1) natural temporary rifts that open near players in both worlds; (2) fixed rift
  structures; (3) a craftable rift item; (4) rifts only at the frame; (5) rifts in Endure only;
  (6) a portal frame you build (as the Nether's).
- **Converge** (canon, vanilla-feel, player value, readable, feasible; 1–5): 1 = 24 (canon's "lots of
  rifts that appear throughout the world", "temporary"), 2 = 17 (canon calls them temporary),
  3 = 21 (canon: the staff opens rifts "at will"), 4 = 10, 5 = 15, 6 = 14 (not canon).
- **Decision: 1 + 3.** Natural rifts are the everyday way in and out; the rift fork is the player's
  way to make one, earned by going deep.

### 2.1 The rift
A rift is an entity: a tall shimmering tear in the air (1.5 wide, 3 high), the membrane's cyan and the
ichor's film colours swirling in it, with drifting motes. It hums (subtitle "Rift hums") and can be
heard 32 blocks off. **Walk into it** and it carries you through at once (an end gateway's speed), with
the membrane's crossing sound; whoever follows within 10 s goes too, then it closes behind you (canon).
A rift also closes when its time runs out, with a sound subtitled "Rift closes".
- **Lifetime:** a natural rift stays open 6 000 ticks (5 minutes); a rift-fork rift, 1 200 (1 minute).
- **Where it leads:** the Overworld ↔ the Sift, at the same x and z (both scale 1), onto the highest
  standable ground of that column (in the Sift: never into ichor deeper than 1; in the Overworld: never
  into water or lava, never under the world's roof). With no ground in that column, the nearest within
  32 blocks; with none, a 3 × 3 platform of the world's stone (hymnstone in the Sift, cobblestone in the
  Overworld) at the column's surface. Nothing else crosses: mobs, items and hunters can't (they would
  strand, D-023).
- Rifts can't open in other dimensions (the Nether, the End) and never lead to them.

### 2.2 Natural rifts
- **In the Overworld:** about one rift opens near each player every 40 minutes of play (two in-game
  days), 24–48 blocks away, on the surface or in caves, wherever a 2 × 3 space stands on solid ground.
  The hum and the opening sound (subtitle "Rift opens", heard 64 blocks off) tell players one is near.
- **In the Sift:** about one every 10 minutes per player, so nobody is stranded.
- A rift never opens within 16 blocks of another.
- **Gamerule** `thesift:spawn_rifts` (default true) turns natural rifts off.

### 2.3 The gate stays
The Ancient City frame and the Sift-side gate are unchanged (D-007's ritual): a fixed, always-open way.
Rifts are the wandering, temporary way.

### 2.4 The rift fork
- **Use:** right-click to strike it: a note rings and a rift-fork rift opens 3 blocks ahead (1 minute),
  in the Overworld or the Sift only. 8 uses (durability), a 5-second cooldown.
- **Recipe:** two echo shards (the prongs) over a gold ingot over a gold ingot (the stem), shaped as a
  tuning fork.
- **Echo shards** come from the Deep Dark's chests (vanilla) and now from **echo ore** deep in the
  Sift Hollows (y −64 to 0, rare: a diamond's frequency at half the vein size). So a Sift-born player
  earns the fork by mining deep; an Overworld player by the Deep Dark or a lucky rift.

## 3. Starting in the Sift
- **Gamerule** `thesift:start_in_sift` (default false; set it in Create World → Game Rules). A player
  joining for the first time is put on the Sift's surface near x 0, z 0 (the nearest standable, dry
  ground in a 64-block spiral), with nothing, and their respawn point is set there (a forced respawn
  point, as `/spawnpoint` sets). Beds in the Sift set the respawn point as before (nobody sleeps).
- From there, the ladder of §1, and rifts or the fork to reach the Overworld.

## 4. Ores
Hymnstone ores (`thesift:hymnstone_<x>_ore`), each the stone's rose with the ore's specks, mined as
vanilla's ores (tool tier, Fortune, Silk Touch, XP), dropping vanilla's items. Distributions copy the
Overworld's (the Sift's height is the Overworld's, D-025):

| Ore | Veins / chunk | Size | Heights | Drop | Analog |
|---|---|---|---|---|---|
| Coal | 20 (+30 upper) | 17 | 0–192 (136–320) | coal | coal |
| Copper | 16 | 10 | −16–112 | 2–5 raw copper | copper |
| Iron | 10 + 90 upper + 10 small | 9 / 4 | −24–56, 80–384 | raw iron | iron |
| Gold | 4 | 9 | −64–32 | raw gold | gold |
| Redstone | 4 + 8 lower | 8 | −64–15 | 4–5 redstone | redstone |
| Lapis | 2 + 4 buried | 7 | −64–64 | 4–9 lapis | lapis |
| Diamond | 7 + 4 buried | 4 / 8 | −64–16 | diamond | diamond |
| Emerald | 100 tries, size 3 | 3 | −16–320, Lullaby Hills only (D-035) | emerald | emerald |
| **Echo** | 4 tries | 4 | −64–0, Hollows only | 1–2 echo shards (Fortune +) | the Sift's own |

Echo ore glows faintly (light 3) and its specks pulse slowly (an animated texture), so it reads in a
dark cave as the Deep Dark's echo; it is hard (as deepslate ores: 4.5) and needs iron.

## 5. Biomes
*Revised by D-035, canon first: Dungeons II names the Carapace and Lullaby Hills. The first draft's
invented "Hymnstone Rise" is dropped.* Biomes don't shape vanilla-style terrain (the noise router
does). Each takes the land where its character already is:
- **The Carapace** (`thesift:carapace`). Canon: "a flat, dry biome composed of dark blue stone and vast
  fields of sand and dust", "red and yellow grass patches", "colossal fossils … the largest of these
  are the humbler husks, which can be entered".
  - It takes the flat, dry land (humidity < −0.3, erosion > 0.3): **Sift dust** over **carapace stone**,
    carapace stone on steep faces.
  - **Red and yellow carapace grass** in patches.
  - A **husk fossil** about every ten chunks: a half-buried rib cage you can walk into, with a hollow
    skull.
  - Nesters come up out of the dust in Endure (canon spawns them in Humbler Huskland); no Blubs.
  - Not yet: sculkers (canon: "the home of sculkers"), bouncy slimes, enterable humbler husks with
    rooms.
- **Lullaby Hills** (`thesift:lullaby_hills`). The name is canon; the look is ours, since the wiki
  doesn't describe it.
  - The hilly, dry land (erosion < −0.35): the rolling high country.
  - Chime bell flowers in drifts in every chunk; lumen blooms half again as common; songwood in loose
    groves only.
  - **Emerald ore**, as the Overworld's mountains have.
  - Blubs and Nesters (canon spawns Nesters there).
- **Singer's Meadow** keeps the gentler middle land; the **Ichor Flats** keep the wet, flat land; the
  **Sift Hollows** stay below.

## 6. Advancements
- **Through the Rift:** travel through a rift.
- **Tuned In:** craft a rift fork.
- **Sift-Born:** get a diamond while in the Sift (anyone can earn it; it marks the ladder's top).

## 7. Numbers (BALANCE.md)
| Number | Value | Vanilla analog | Why |
|---|---|---|---|
| Natural rift, Overworld | about 1 per player per 40 min, 24–48 blocks away, open 5 min | wandering trader's ~1 per 20–40 min | Found by exploring, never forced |
| Natural rift, Sift | about 1 per player per 10 min | — | Nobody stranded |
| Rift closes behind you | 10 s after the first crossing | — | Canon; friends can follow |
| Rift fork | 8 uses, 5 s cooldown, rift open 60 s | — | A tool, not a door you leave open |
| Tide root | 4 stages; raw 2 hunger, baked 5 / 6.0 | potato 1, baked potato 5 / 6.0 | A staple |
| Songfruit | 0.5 % from leaves; 4 / 2.4 | apple | — |
| Glowcap stew | 6 / 7.2 | mushroom stew | — |
| Echo ore | 4 tries, size 4, y −64–0, Hollows; 1–2 shards | diamond's rarity | Deep and rare |

## 8. Edge cases
| Case | Rule |
|---|---|
| A rift opening by a player on a boat or riding | They pass through when the vehicle enters: the passengers cross together, the vehicle stays |
| A rift in the Overworld over an ocean | The search finds land within 32; else the platform |
| Hunters, mobs and items | Never carried (D-023) |
| Creative and spectator | Spectators pass through too (as through portals); creative players as anyone |
| A player in the Nether or the End | No natural rifts; the fork does nothing there |
| `start_in_sift` turned on mid-game | Only players joining for the first time after that start in the Sift |
| Multiplayer | Each joining player gets their own respawn point at the shared start spot |

## Critique log
- **Self-review (2026-10-03),** the owner's credit request standing (§5.6's without-subagents form).
  Weaknesses found and fixed:
  - Rifts in every dimension would strand players in the Nether: now Overworld ↔ Sift only.
  - Natural rifts on a fixed timer would be predictable: now a per-player chance.
  - Tide roots on farmland would need ichor to hydrate farmland, which changes a vanilla rule: now
    they grow on tide sand beside ichor, as sugar cane does.
  - Echo shards only from the Ancient City would lock a Sift-born player out of the fork: echo ore.
  - A rift that drops you into an ocean or lava: the safe-ground search and the platform.
  - D-023's "nothing chases you through" is kept: rifts carry players only.
- **Frozen 2026-10-03.**
