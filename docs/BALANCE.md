# BALANCE

Stat tables for every Sift mob and item next to 2–3 vanilla analogs, with reasoning (§7.7). Difficulty scaling (Easy/Normal/Hard) defined per entry.

## Ichor (WP-044; D-024, owner playtest)
The Sift's water: it behaves as vanilla water does, and is clear turquoise.

| Property | Ichor | Water | Reasoning |
|---|---|---|---|
| Movement | Swimming, currents, buoyancy, breath (it is in `#minecraft:water`) | The same | The owner's playtest: it played like lava. Now it plays like water |
| Harm | None; it puts out fire | None; puts out fire | Endure's danger is the hunters (M2), not the flood |
| Flow | 7 blocks (drop-off 1, slope search 4), a step per 5 ticks; two sources make a third | The same | Water's rules, so lakes, rivers and buckets behave as players expect |
| Light | 4 | 0 | A faint glow, as the teasers' pools; readable in Endure's dark |
| Look | Translucent turquoise, turquoise haze underneath (fog to 64 blocks) | Tinted by biome, fog to 96 | The teasers' blue pools |
| Outside the Sift | A bucket evaporates (soul smoke) | Places | rules.md: nothing from the Sift spreads at home |
| Cost (20 mobs swimming) | 1.08× water | 1× | Measured, `SiftPerfTest` |

## Frame offering (WP-046)
| Property | Value | Vanilla analog | Reasoning |
|---|---|---|---|
| Price | 1 395 XP points (level 0 → 30), once per frame | Enchanting table's level-30 tier; anvil's "too expensive" cap at 40 | A milestone everyone recognises, paid once; pooled across players and visits |
| Rate | 10 points per use, about 50 points per second while *use* is held (~28 s for the full price) | Brushing suspicious sand | Long enough to feel like an offering, short enough not to bore; release stops it at once |
| Creative | Free (charge still fills at the same pace) | Enchanting in creative | Testing and building |

## Blub (WP-048, frozen 2026-10-01)
A pet, never a fighter (mob_blub.md). Passive: no difficulty scaling.

| Stat | Blub | Rabbit | Allay | Axolotl | Why |
|---|---|---|---|---|---|
| Max health | 8 | 3 | 20 | 14 | Sturdier than a rabbit so a pet survives a stray hit; far below a fighter |
| Armor / attacks | 0 / never | 0 / never | 0 / never | 0 / 2 damage | A pet, never a fighter |
| Speed | 0.25 (walk), ×1.6 when following or panicking | 0.3 | 0.1 fly | 1.0 swim | A waddle; keeps up with a walking player while following |
| Follow range | 16 | 16 | 16 | 16 | Vanilla default |
| Knockback resistance | 0 | 0 | 0 | 0 | |
| XP on death | 1–3 | 1–3 | 0 | 1–3 | Animal norm |
| Difficulty scaling | none | none | none | none | Passive |

| Behaviour number | Value | Vanilla analog | Reasoning |
|---|---|---|---|
| Spawning | Singer's Meadow, creature, weight 10, groups 2–5; world-gen probability 0.03; no natural spawns in Endure | Rabbit 4 / 2–3; default probability 0.1 | ~50 blubs in a 10-chunk all-Meadow view; they never despawn, so this is the steady state |
| Befriend | One hand-played note, the nearest *listening* untamed blub within 4 blocks | Allay: hand it an item | Free, deliberate, never a whole herd by accident |
| Echo | 0.3 s after the owner's note, at +0/+4/+7 semitones, at most once per 0.5 s | Note block pitch table | Three blubs make a chord |
| Herald | Restless in the last 30 s before each Flow | — | A warning for the two Tide changes the sky doesn't count down |
| Healing | 1 HP per 30 s, only while sitting or curled | Pets heal only by eating | No food until M2's treats; resting heals |
| Towers | Up to 5 tall; topple 15–40 s after the music stops | — | The bible's "Stacked" advancement needs five |
| Falls | Safe fall distance 4 | 3 | A soft critter: topples never hurt |
