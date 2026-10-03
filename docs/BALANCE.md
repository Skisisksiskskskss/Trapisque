# BALANCE

Stat tables for every Sift mob and item next to 2–3 vanilla analogs, with reasoning (§7.7). Difficulty scaling (Easy/Normal/Hard) defined per entry.

## Ichor (WP-044; D-024, D-026, owner playtests)
The Sift's water: it swims as vanilla water does, but is a little thicker and carries a soap bubble's sheen.

| Property | Ichor | Water | Reasoning |
|---|---|---|---|
| Movement | Swimming, currents, buoyancy, breath (it is in `#minecraft:water`) | The same | The owner's playtest: it played like lava. Now it plays like water |
| Lift | +0.025 a tick upward, up to 0.18 a tick; none while sneaking | None (you sink slowly unless you swim) | Playtest 2: it acted "too much like water". You bob up in it; sneak to dive |
| Harm | None; it puts out fire | None; puts out fire | Endure's danger is the hunters (M2), not the flood |
| Flow | 7 blocks (drop-off 1, slope search 4), a step per 8 ticks; two sources make a third | 7 blocks, a step per 5 ticks | Water's rules, so buckets behave as players expect, but slower: it reads as thicker (playtest 2) |
| Light | 4 | 0 | A faint glow, as the teasers' pools; readable in Endure's dark |
| Look | Alpha 214; a pale shimmer tinted by position along a soap film's colours (mostly turquoise); turquoise haze underneath (fog to 64 blocks) | Alpha 180; grey, tinted by biome; fog to 96 | The teasers' blue pools, "slightly less transparent" and "like the surface of a thin bubble" (playtest 2) |
| Outside the Sift | A bucket evaporates (soul smoke) | Places | rules.md: nothing from the Sift spreads at home |
| Cost (20 mobs swimming) | 1.08× water | 1× | Measured, `SiftPerfTest` |

## Flora II (WP-064, frozen 2026-10-03)
The M2 plants (block_flora_ii.md, D-027): tidewrack and the Endure bloom are picked once per cycle, only in their own Tide; the glowcap and the lumen bloom are lights; the chime bell rings.
**Difficulty:** none of these numbers change with difficulty (as vanilla's plants).

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

## Frame offering (WP-046)
| Property | Value | Vanilla analog | Reasoning |
|---|---|---|---|
| Price | 1 395 XP points (level 0 → 30), once per frame | Enchanting table's level-30 tier; anvil's "too expensive" cap at 40 | A milestone everyone recognises, paid once; pooled across players and visits |
| Rate | 10 points per use, about 50 points per second while *use* is held (~28 s for the full price) | Brushing suspicious sand | Long enough to feel like an offering, short enough not to bore; release stops it at once |
| Creative | Free (charge still fills at the same pace) | Enchanting in creative | Testing and building |

## Materials (WP-065, frozen 2026-10-03)
| Number | Value | Vanilla analogs | Why |
|---|---|---|---|
| Treat heal | 4 HP (a blub has 8) | wolf eating meat (food value); horse wheat 2 | A real heal on the move; the rest-heal stays slow |
| Baby growth | 20 min (24 000 ticks), fronds speed it | all vanilla babies | Vanilla's rule |
| Baby scale | 0.6 | vanilla babies 0.5 | A blub is small already; 0.5 would vanish in grass |
| Frond → dye | 1 → 1 cyan | cornflower → 1 blue | A flower's rate |
| Lantern price | 4 petals + 1 hymnstone | lantern (iron nuggets + torch) | About one careful Endure's picking (block_flora_ii.md) |
| Lantern light | 15 | lantern 15, soul lantern 10 | A lantern |
| Frond compost | low (30%) | kelp | A sea plant |

## Rework 4 (D-029, 2026-10-03)
| Number | Value | Vanilla analogs | Why |
|---|---|---|---|
| Ichor lily light | 9 | glow lichen 7, sea pickles 6–15, frog light 15 | Lights a blot of ichor without washing out the night |
| Ichor lilies | 2 patches a Flats chunk, 14 tries each, only on an ichor source | swamp lily pads (4 patches of 10) | The Flats' blots are smaller than a swamp's water |
| Lumen in the Flats | 1 in 6 chunks (Meadow 1 in 12) | — | "More light" in the Flats |
| Glowcaps in the Flats | a patch (10 tries) 1 chunk in 3 | swamp mushrooms | A swamp's mushrooms |
| Greet | after 30 s away (out of 24 blocks, or gone) | — | Long enough to mean "came back" |
| Forage | ready tidewrack within 12 blocks; every 2–4 min at most, Thrive only | allay, fox | Helpful, but a basin visit still pays |
| Tag | 8–12 s, 1 chance in about a minute of idleness | — | Seen now and then, never a constant blur |
| Grain softening | jitter ×0.4, clumps ×0.6, contrast ×0.72 | vanilla stone, dirt | "A slight change will come far" |
| Still ichor frame | 3 ticks (was 5) | water 2 | "Slightly faster" |

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

## Nester (WP-061, frozen 2026-10-02)
The listening hunter (mob_nester.md), on the hunt system above. **Difficulty:** damage to players
scales as vanilla's (Easy min(d/2+1, d), Hard ×1.5); the guard dodges one swing (Hard two); the
enduring chance is the system's (25 %, Hard 35 %); Peaceful removes it.

| Stat | Nester | Wolf | Spider | Zombie | Why |
|---|---|---|---|---|---|
| Max health | 20 (enduring 30) | 8 | 16 | 20 | A duelist that lasts a few exchanges |
| Armor | 2 | 0 | 0 | 2 | |
| Bite (Easy / Normal / Hard) | 3.5 / 5 / 7.5 (enduring 4.1 / 6.25 / 9.4); flat 5 against non-players | 3 / 4 / 6 | 2 / 2 / 3 | 2.5 / 3 / 4.5 | Few, telegraphed bites that matter |
| Speed | 0.3; gallop and hunt ×1.12 (about 5.0 blocks/s), roam ×0.6 (1.4), circle a strafe of about 2.5 | 0.3 (4.0) | 0.3 (4.0) | 0.23 (2.3) | Catches a walker (4.3), not a sprinter (5.6) |
| Follow range | 24 | 16 | 16 | 35 | The hunt's drop distance |
| Knockback resistance | 0 (enduring 0.2) | 0 | 0 | 0 | |
| Step height | 1.0 | 0.6 | 0.6 | 0.6 | Long legs (the horse's 1.0) |
| XP | 5 (enduring 10) | 1–3 | 5 | 5 | No drops: the price of Endure, not a resource |

| Behaviour number | Value | Vanilla analog | Reasoning |
|---|---|---|---|
| Lunge | beyond melee reach to 4 blocks; aim locked at an 8-tick windup; leap up to 0.6 / 0.35, scaled to distance; bite live until it lands (≤ 12 ticks) | `LeapAtTargetGoal` 2–4 | The windup is the sidestep window; about 17 ticks from crouch to bite at 4 blocks |
| Standing bite | at melee reach; windup 6 stepping in; hit or miss, then recovery | melee attack | Close in, shield early |
| Recovery / stagger | 12 ticks / 30 when a shield blocks the bite | ravager stun 40 (half the time) | Shield it, then hit it |
| Circle | 30 ticks at 4 blocks, a strafe of about 2.5 blocks/s | wolf, spider | The system's "circles on cooldown" |
| Guard | the first melee hit of each circle dodged (Hard: two); player attacks, spears, mace smashes, mob attacks; never projectiles | enderman (projectiles, always) | Never a coin flip: bait it, then strike |
| Damage rate | about 1.4 per second on Normal (one cycle ≈ 70 ticks) | zombie 3, spider 2 | Its threat is being found, its speed and its company |
| Time to kill (Normal) | unarmoured ≈ 14 s; iron ≈ 28 s; diamond: regeneration wins until hunger | — | Hunger is the long-Endure danger |
| Sounds | gallop volume 1.5 (24 blocks), emerge volume 2 (32), steps 0.15 subtitled | warden steps | Heard before it hears you |
| Out of reach | target dropped after 200 ticks without a path | — | Pillars are safe, as in vanilla |
| Spawning | Singer's Meadow (Hymnstone Rise from M3), Endure only, on soil, groups 1–2; weight in WP-070 (proposal 60 against the Bloombud's 100) | — | Nesters are the event; buds the commoner danger |

## Bloombud (WP-062, frozen 2026-10-02)
The ambusher (mob_bloombud.md), a hunter that doesn't listen. **Difficulty:** damage to players
scales as vanilla's; the enduring chance is the system's; Peaceful removes it.

| Stat | Bloombud | Zombie | Vindicator | Why |
|---|---|---|---|---|
| Max health | 14 (enduring 21) | 20 | 24 | Weak alone; the patch is the threat |
| Armor | 2 | 2 | 0 | |
| Strike (Easy / Normal / Hard) | 3 / 4 / 6 (enduring 3.5 / 5 / 7.5); flat 4 against illagers | 2.5 / 3 / 4.5 | 7.5 / 13 / 19.5 (iron axe) | |
| Speed | 0.23 open (about 2.3 blocks/s), 0 closed | 0.23 | 0.35 | Slow, as canon says: a walking player (4.3) always gets away |
| Follow range | 16 | 35 | 12 | |
| Knockback resistance | 0 (closed: no pushing or knockback) | 0 | 0 | Rooted as a watched creaking |
| XP | 5 (enduring 10; none if killed digging away from a cap) | 5 | 5 | No drops: a hazard, not a resource |

| Behaviour number | Value | Vanilla analog | Reasoning |
|---|---|---|---|
| Wake radius | closed 5, open 8, in sight (×0.8 sneaking) | `TargetingConditions` | Sneak past at 4 |
| Bloom | 15 ticks, the telegraph | — | The window to step away |
| Ripple | only from a target-woken bud; neighbours within 8 that it sees, nearest first, the first as the bloom ends, then 10 ticks apart; no chains | — | A patch of five is open after 60 ticks (3 s) |
| Bloom lunge | once per waking, if the target is within 4 at the bloom's end; aim locked at the bloom's start; hop scaled to distance, at most about 3 | `LeapAtTargetGoal` | The bible's "before it lunges" |
| Strike | windup 10, active 3, recovery 16; about one per 30 ticks | `MeleeAttackGoal` 20 | Step back in the windup |
| Damage rate (Normal) | about 2.7 per second for one bud in reach; a patch of five around you up to about 13 | zombie 3 | A patch punishes standing in it |
| Time to kill (Normal, one bud) | unarmoured about 7.5 s; iron about 16 s; diamond under 1 a strike | — | One bud is a nuisance; five are not |
| Creep | one block, at most every 40 ticks and 3 a minute, only unwatched, never within 6 of a target | creaking (activation 12, look test 0.5) | Dread, never a sprung trap |
| Rooting light | block light 0 and raw brightness ≤ 7 | Sift monster spawn light 0–7 | Never in a lit pocket |
| Spawning | Singer's Meadow (Endure) and the Sift Hollows (any Tide, dark), on bare soil, groups 3–5; weight in WP-070 (proposal 100 against the Nester's 60) | — | The commoner danger |

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
