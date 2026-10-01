# BALANCE

Stat tables for every Sift mob and item next to 2–3 vanilla analogs, with reasoning (§7.7). Difficulty scaling (Easy/Normal/Hard) defined per entry.

## Ichor (WP-044)
A hazard you walk into and can see (systems.md §2): it shows its danger (soul fire, steam, the burn) before any XP goes.

| Property | Ichor | Lava (Overworld) | Powder snow | Cobweb | Reasoning |
|---|---|---|---|---|---|
| Movement | ×0.5 horizontal, ×1.0 vertical; no swimming, no current | swim, ×0.5-ish, current | ×0.9, sinks | ×0.25 / ×0.05 | Slow enough to read as "thick" and to cost time; vertical untouched so a 1-block bank is always climbable |
| Burn | Ignites for 4 s (vanilla fire: 1 dmg/s, so ~4 dmg after leaving) | 4 dmg per hit + 15 s of fire | — (freezes: 1 dmg / 2 s after 7 s) | — | A warning burn, far below lava: ichor is meant to be waded on purpose, not to kill |
| Fire Resistance | Stops the burn; the drain stays (D-013) | Stops all | — | — | The vanilla counter works, with a Sift twist |
| XP drain (players, survival/adventure) | Easy/Peaceful 1, Normal 2, Hard 4 points per second | — | — | — | Level 30 → 0 takes ~12 min on Normal: a pressure, not a trap. Creative and spectators are exempt |
| Flow | 3 blocks on flat ground (drop-off 2, slope search 2), a step per 20 ticks; no infinite sources | 3 blocks, a step per 30 ticks | — | — | Lava-like reach, a little quicker so basins visibly fill; finite so buckets can't farm it |
| Light | 4 | 15 | 0 | 0 | A faint glow for readability in Endure's dark |
| Outside the Sift | A bucket evaporates (soul smoke) | Places | — | — | rules.md: nothing from the Sift spreads at home |

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
