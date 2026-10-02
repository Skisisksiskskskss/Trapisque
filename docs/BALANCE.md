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

## The hunt (WP-060, frozen 2026-10-02)
The system every Sift hunter shares (system_hunt.md); each mob's own stats are in its section.
**Difficulty:** Peaceful removes hunters (`notInPeaceful()`); the enduring chance is 25 % on Easy and
Normal and 35 % on Hard; everything else is the same on every difficulty, as the warden's hearing is.

| Number | Value | Vanilla analog | Reasoning |
|---|---|---|---|
| Hearing range | 16 (Endure only) | warden 16, sculk sensor 8 | Bible |
| Jukebox range | 10 | allay 10 | Bible |
| Reaction cooldown | 40 ticks, from each accepted sound | warden's vibration cooldown 40 | Vanilla rhythm |
| Tell before gallop | 20 ticks | warden's sniff/roar telegraphs | Time to sneak or flee |
| Gallop give-up | 200 ticks | — | A spot it can't reach |
| Search radius / time | 6 blocks (2 for sneakers), line of sight / 60 ticks | — | A lure works; sneaking saves you |
| Hunt: circling, drop | 30 ticks after a lunge; dropped at 24 blocks or 100 ticks unseen | wolf, spider | The bible's "circles on cooldown" |
| Bump | a player within 2 blocks of a roaming listener | — | Walking into one is a mistake |
| Retreat moment | cycle ticks 27 000–29 000, by UUID | — | Staggered |
| Soil search, dig | 16 blocks across, 6 up or down; 60-tick dig | warden dig 100 ticks | Shorter for a common mob |
| Fight-on distance | until the target is 16 away, capped by the Thrive sweep | — | Vision, capped (D-023) |
| Enduring chance | 25 % (Hard 35 %) | zombie leader 5 %, spider effects | Common enough to matter, not every mob |
| Enduring stats | health ×1.5, damage ×1.25, KB res. +0.2 | — | Tougher, not unfair |
| Enduring reward | XP ×2; one extra loot roll if it has a table | — | Worth the risk |
| Repel radius | 6; rim at 7; no spawns within 8 | piglin repellents 8 | A lantern makes a small camp |
| Rim flee | 16 blocks for 100 ticks | — | Not a weapon |
| Cave dweller | spawned in the Hollows biome | — | Decided once, by biome alone |
| Lull | 200 ticks, hunters within 12 | — | items.md §1.2 |
| Return-by | the next Thrive's first tick, saved at spawn | — | Spawn eggs and `/summon` too |
| Chime bell | once per 10 ticks, not when sneaking | — | — |

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
