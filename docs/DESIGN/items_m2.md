# M2 materials and the lumen lantern (WP-065) — FROZEN 2026-10-03

Fixed by the bible (items.md rows "Tidewrack frond", "Endure petal", "Lumen lantern"; mob_blub.md's M2
hook "breeding and healing with tidewrack treats"), system_hunt.md §6 (lumen: the `thesift:lumen` POI,
lanterns don't burn out, their cost is Endure petals) and block_flora_ii.md (how fronds and petals are
gathered, the petal economy). This doc decides the recipes, the treat and the lantern.

## Concept ladder: what should a frond and a petal buy?
### Diverge
1. **The frond is the treat** (as seagrass for turtles, wheat for cows): feed it to a blub to heal or breed.
2. **A crafted "blub treat"** (frond + something): one more item for the same job.
3. **Frond → cyan dye**, one to one, as a flower to its dye.
4. **Lantern from petals around hymnstone** (4 petals), a light that is lumen.
5. **Lantern that burns out** each Endure (rejected by system_hunt.md §6, recorded there).
6. ***Petal tea*** (unusual): a drink that muffles your footsteps for a minute (overlaps M5's Muffled Steps trait).
7. ***Blubs carry lanterns*** (unusual): a befriended blub fed a petal glows as lumen for one Endure.

### Converge (1–5: faithful, vanilla-native, readable, meaningful, distinct, connected, feasible)
| # | Concept | F | V | R | M | D | C | Fe | Σ |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Frond is the treat | 5 | 5 | 5 | 4 | 3 | 4 | 5 | **31** |
| 2 | Crafted treat | 4 | 3 | 4 | 3 | 2 | 4 | 5 | 25 |
| 3 | Frond → cyan dye | 5 | 5 | 5 | 3 | 2 | 3 | 5 | **28** |
| 4 | Petal lantern | 5 | 5 | 5 | 5 | 4 | 5 | 5 | **34** |
| 5 | Burn-out lantern | 2 | 3 | 3 | 3 | 3 | 4 | 4 | 22 |
| 6 | Petal tea | 2 | 3 | 3 | 3 | 4 | 4 | 4 | 23 |
| 7 | Blub lantern | 3 | 2 | 3 | 4 | 5 | 5 | 3 | 25 |

**Decision: 1 + 3 + 4.** 6 overlaps the M5 trait; 7 is parked in IDEAS.md (a lovely idea that needs the
hunt in code first); 2 is a second item for one job.

## Tidewrack frond (`thesift:tidewrack_frond`)
- **Source:** picked from tidewrack in Thrive (1–2 a plant a cycle).
- **Cyan dye:** shapeless, 1 frond → 1 cyan dye (as a cornflower → blue dye).
- **The blub's treat** (`Blub.isFood`): *use* on a befriended blub heals 4 (2 hearts; a blub has 8) and
  enters love mode, as vanilla's animals do; two blubs in love make a **baby blub** (vanilla's
  `AgeableMob` rules: grows up in 20 minutes, which fronds speed up as wheat speeds up calves). Wild
  blubs don't eat (they're befriended by music, mob_blub.md). The baby inherits the owner (as wolves)
  and is drawn at 0.6 scale.
- **Compost:** low (as kelp).

## Endure petal (`thesift:endure_petal`)
- **Source:** picked from an open Endure bloom in Endure (1 a bloom a night).
- **Lumen lantern:** shaped, 4 petals around 1 hymnstone → 1 lantern (the planning price block_flora_ii.md
  used). Gear traits (M5) are its other sink.
- **Compost:** none (a reagent; nobody should compost one by accident).

## Lumen lantern (`thesift:lumen_lantern`)
- **What it does:** a lantern whose light hunters won't enter: its states join the `thesift:lumen` POI
  (system_hunt.md §6: no hunter within 6, no spawns within 8). It never burns out.
- **Block:** vanilla's `LanternBlock` (stands or hangs, waterloggable), light **15** (a lantern's),
  `SoundType.LANTERN`, pickaxe, drops itself (unlike the wild lumen bloom: you made it).
- **Look:** a hymnstone-capped glass lantern with a pale blue-white petal flame (the `lumen` ramp and
  hymnstone), so it reads as the bloom's light caught in a lantern.
- **Until WP-066** the hunters aren't in the game, so it is a light that waits for them.

## Advancement
- **Low Tide** (items.md, Core): "Gather tidewrack at low tide", `minecraft:inventory_changed` with a
  tidewrack frond, under the Sift tab.

## Numbers (BALANCE.md)
| Number | Value | Vanilla analogs | Why |
|---|---|---|---|
| Treat heal | 4 HP | wolf eating meat (heals by food value); horse wheat 2 | A real heal on the move; the rest-heal stays slow |
| Baby growth | 20 min (24 000 ticks), fronds speed it | all vanilla babies | Vanilla's rule |
| Lantern price | 4 petals + 1 hymnstone | lantern (iron nuggets + torch) | About one careful Endure's picking (block_flora_ii.md) |
| Lantern light | 15 | lantern 15, soul lantern 10 | A lantern |

## Edge cases
| Case | Rule |
|---|---|
| Feeding a wild blub | Nothing (not befriended) |
| A blub at full health | Love mode only, as vanilla |
| Lantern in water | Waterlogs, as vanilla's |
| Lantern outside the Sift | A light; lumen matters only where hunters are |

## Critique log
- **Self-review (2026-10-03).** The owner asked for credit efficiency, so this medium-tier doc had one
  explicit self-review pass instead of fresh-reviewer rounds (§5.6's without-subagents form). Weaknesses
  found and fixed: the treat must not befriend wild blubs (music does, mob_blub.md), now stated; a
  petal-to-compost path would leak the rare reagent, now none; the lantern dropping itself contradicts
  nothing (D-027 covers only the wild bloom), kept; the baby needs a visible size difference, 0.6 scale.
- **Frozen 2026-10-03.**
