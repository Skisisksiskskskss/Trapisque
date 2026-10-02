# The hunt (WP-060)

M2's system: **Endure means danger**. The vision (systems.md §4 N8, §1) and the frozen bible fix the
rules (D-011, D-013; creatures.md rows Nester, Bloombud and "enduring variants"; world.md rows Lumen,
hymnstone and chime bell flower; items.md M2 advancements). This doc decides how they work, and their
numbers, so the M2 mobs (WP-061/062) and blocks (WP-064) can be designed against one system.

Fixed by the bible (not reopened here):
- **Who listens:** each area's hunters, only in Endure. In 1.0 that's the **Nester** (Singer's Meadow).
- **What they hear:** what a sculk sensor hears (`#vibrations`) out to a warden's **16 blocks**, plus
  **jukeboxes within 10** (not a vibration). The vanilla vibration particle is the tell.
- **Retreat:** at falling Flow, surface hostiles burrow away (telegraphed) and are gone by Thrive. Cave
  dwellers stay. Hunters burrow in soil, not stone (world.md, hymnstone).
- **Enduring variants** of the common hostiles (Nester, Bloombud; later Pollinator, Sprout) in Endure:
  more health and damage, marked by shape and particles, not colour alone.
- **Lumen** repels hunters: a small radius they won't enter, as piglins avoid soul fire.

**Words used here:**
- A **hunter** is any Sift hostile: the entity tag `#thesift:hunters` (Nester, Bloombud; later
  Pollinator, Sprout). Retreat, lumen, enduring variants and the membrane rule apply to all hunters.
- A **listener** is a hunter that hears (section 3). In 1.0 only the Nester listens.
- **Soil** is `#thesift:hunter_burrowable` (healthy sculk, the Meadow's surface over hymnstone; later
  soils join). Hymnstone, bricks, planks and every vanilla block are not soil.

## 1. The rules, in plain language
- **In Endure, Nesters listen.** Anything a sculk sensor would hear, they hear from 16 blocks away: your
  steps, a door, a thrown snowball landing, a playing jukebox within 10, a blight shrieker's cry.
  Sneaking and wool keep you quiet, as in the Deep Dark, though eating and drinking are heard even
  while sneaking.
- **A Nester that hears goes to the sound, not to you.** It flares its crest, gallops to where the sound
  was and sniffs around. Whatever it finds there, it attacks. A snowball thrown far away sends it there.
- **Dawn sends them home.** As the tide falls, surface hunters dig into the soil and are gone by Thrive.
  If one is fighting you, it keeps at it until you get 16 blocks away, but no later than Thrive.
- **Some come back tougher.** In Endure, about a quarter of hunters are *enduring*: bigger crest, a trail
  of soul wisps, more health and harder hits.
- **Lumen keeps them out.** No hunter comes within 6 blocks of lumen, or spawns within 8. A Nester that
  hears you inside the light stops at its edge and paces there.
- **A stone floor is a safe floor.** Hunters come up out of soil, so they never spawn on hymnstone,
  bricks or planks.

## 2. How players learn them
| Rule | How it's learned |
|---|---|
| They hear | The vanilla vibration particle flies from you to the Nester, then the crest flares and the subtitle "Nester hears something" shows. The first time grants **Heard You** |
| Sneaking works | The same as a sculk sensor, which players know from the Deep Dark; the particle doesn't fly |
| They go to the sound | A Nester galloping past you toward a snowball's landing spot; the sniff at the spot |
| Dawn | The Blub's herald song before falling Flow (M1), then hunters digging with particles, a sound and the subtitle "Nester burrows" |
| Enduring | Shape (the larger crest), the trail of wisps, the glow, and a different idle subtitle ("Enduring Nester growls") |
| Lumen | A Nester pacing the light's edge, turned toward you, close but not coming in. Lumen's tooltip line says "Hunters keep away" |
| Soil | Hunters dig into it at dawn in plain view, and come up out of it: a player's stone or plank floor never has one spawn on it |

## 3. Hearing: how a listener hears, and what it does next
### Diverge (written before scoring)
1. **Vanilla vibration listener per listener** (`VibrationSystem`, as the warden, sculk sensor and
   allay): the engine routes `#vibrations` events, checks occlusion (wool), draws the particle, and
   delays by distance. Radius 16 only in Endure; 0 otherwise.
2. **Our global game-event hook** (the blub's route, D-021): one consumer looks up hunters near each
   vibration. Cheap per event, but we'd re-implement occlusion, the particle and the travel delay.
3. **Brain sensor** polling nearby players' movement every N ticks. Polling; not what a sensor hears.
4. **Hear only players**: filter the vibration's source entity to players. Simple, but snowballs,
   arrows and doors (vanilla lures) would stop working.
5. **Hear everything, investigate first**: on a vibration the hunter turns, flares its crest, gallops to
   the *spot*, sniffs, and attacks only what it finds there. Lures work; sneaking works.
6. **Hear everything, attack the source entity directly**: faster, but every snowball would send it at
   the thrower. Vanilla does this only in one narrow case: a warden that hears a projectile within 100
   ticks of an earlier one (any projectile, from anyone: `RECENT_PROJECTILE` isn't per owner), with
   this one's owner within 30 blocks, aims at the owner instead of the landing spot, and only while
   it isn't yet angry (an angry warden is already chasing its target).
7. **Anger meter** like the warden's: repeated sounds raise anger until it locks on. Rich, but the
   warden owns that idea, and the Nester is a common mob, not a boss.
8. **Pack call**: a hearing Nester howls, and others within 24 come. Strong drama; risks chains that
   sweep the Meadow.
9. **Jukebox as a magnet**: a playing jukebox draws listeners every second while it plays (its event
   repeats every 20 ticks, `JukeboxSongPlayer`). A base with music is a deliberate beacon.

### Converge: rubric (1–5; the vision's criteria)
| # | Fantasy | Vanilla-feel | Readable | Fair | Feasible | Cheap | Σ |
|---|---|---|---|---|---|---|---|
| 1 | 4 | 5 | 5 | 5 | 5 | 4 | **28** |
| 2 | 4 | 3 | 3 | 4 | 4 | 5 | 23 |
| 3 | 2 | 2 | 2 | 3 | 4 | 3 | 16 |
| 4 | 3 | 2 | 4 | 3 | 5 | 5 | 22 |
| 5 | 5 | 5 | 5 | 5 | 4 | 4 | **28** |
| 6 | 3 | 3 | 3 | 2 | 5 | 5 | 21 |
| 7 | 4 | 3 | 4 | 4 | 3 | 4 | 22 |
| 8 | 5 | 3 | 4 | 2 | 4 | 3 | 21 |
| 9 | 4 | 4 | 5 | 4 | 5 | 4 | **26** |

### Decision: **1 + 5, with 9 as a consequence**
- Each listener carries **one vanilla vibration listener** (1). Its radius is 16 in Endure and 0 in
  any other Tide, so outside Endure it hears nothing at no cost. Occlusion (wool), the travel delay and
  the vibration particle are vanilla's, unchanged. Sneaking muffles the events in
  `#ignore_vibrations_sneaking` (steps, landings, swimming, shooting, and starting or finishing an
  item's use, such as a shield or a spyglass), as with every sensor. Eating and drinking
  (`minecraft:eat`, `minecraft:drink`) aren't in that tag, so they are heard while sneaking too.
- **Jukeboxes ride the same listener** (9). Its listenable events are a tag of our own,
  `#thesift:hunter_can_listen` = `#minecraft:vibrations` + `minecraft:jukebox_play` +
  `minecraft:shriek`, as the warden's `#warden_can_listen` widens its own (it adds `shriek` too). A playing jukebox repeats its event every second, so a base
  playing music in Endure calls the listeners until it stops. The particle, the delay and wool
  occlusion apply to jukeboxes too (a jukebox boxed in wool is muffled). rules.md's tech note named a
  second, allay-style listener; one listener with a wider tag does the same with less code (D-023).
- **Blight shriekers alert hunters** (D-012, M4) through the same listener. A shriek is vanilla's
  `minecraft:shriek` event, which names the player who set the shrieker off as its source (as
  `SculkShriekerBlockEntity.shriek` does), so it's a sound that player caused: listeners within 16 go
  to the shrieker, and the player gets Heard You. Sneaking doesn't muffle it (it isn't in the
  sneaking tag). Hunters also hear a vanilla shrieker a player placed; the shrieker itself stays
  vanilla, and neither kind touches the warden warning tracker.
- **What a listener ignores** (its `canReceiveVibration`, as the warden's filters through
  `canTargetEntity`):
  - any event while it is in its cooldown (which covers its tell), hunting, retreating, or dead, or
    outside Endure;
  - events whose source entity, or whose projectile's owner, is itself or any hunter (so it never
    reacts to its own steps, and a gallop never sets off the next Nester: no pack chains);
  - events from creative or spectator players (vanilla's `NO_CREATIVE_OR_SPECTATOR`, as the warden;
    vanilla already drops spectators' events);
  - `jukebox_play` farther than 10 blocks. The event's own radius is 10, but the dispatcher picks
    listeners by whole sections, so the distance is checked here;
  - events caused by a player who lulled this hunter in the last 10 s (the Singer's horn, M4; the
    Lulled state below), which covers the song's own vibration, as items.md §1.2 asks;
  - `minecraft:step` and `minecraft:hit_ground` from a player whose leggings carry **Muffled Steps**
    (items.md §2, M5): the tag `#thesift:muffled_steps` holds the two events, and the trait is read
    from the player's leggings slot. Mining, building, projectiles and music are still heard.
- **When the filters run.** Vanilla runs `canReceiveVibration` when the sound is made, then delivers
  it after the travel delay (`onReceiveVibration`). The listener runs the filters again on delivery,
  since its state can change during the delay (it found a target, was lulled, or Endure ended). A
  sound is **accepted** only if it passes both times; only an accepted sound is a reaction.

### The reaction, exactly
A listener is always in one of these states. Each says what it does with a sound. Its **cooldown**
(40 ticks, the warden's vibration cooldown) starts at each accepted sound; a sound made during the
cooldown is ignored in every state.
1. **Roam.** It wanders. It does not target by sight: a player it sees but doesn't hear is safe,
   except one within 2 blocks of it (a bump), or one that hurts it (it hunts the attacker).
   *A sound:* the tell.
2. **Tell** (20 ticks), on an accepted sound. It stops, turns to the sound's position, and flares its
   crest, with a sound subtitled "Nester hears something". *A sound:* none can arrive (the cooldown
   outlasts the tell).
3. **Gallop** to the sound's position (not its source entity), at a sprint. A gallop that can't reach
   the spot within 200 ticks ends where it stands, and the search starts there. *A sound:* it
   **re-aims**: the spot moves to the new sound (the latest wins), with no new tell, since the crest
   is already up, as a warden re-aims at each new disturbance.
4. **Search** (60 ticks). It sniffs around the spot. It attacks the nearest **target** within 6 blocks
   of the spot that it can see (line of sight from its eyes: no finding players through stone).
   A sneaking target is found only within 2 blocks of the listener. Targets: survival and adventure
   players, illagers, blubs. Nothing found: it goes back to roaming. *A sound:* it re-aims, galloping
   to the new spot without a tell.
5. **Hunt.** It chases and lunges. After each lunge it circles the target for 30 ticks (the bible's
   "circles on cooldown"), then lunges again. It drops the target, and roams, when the target dies or
   leaves, is more than 24 blocks away, has been out of sight for 100 ticks, steps inside lumen's
   radius, or turns creative or spectator. *A sound:* ignored (`canReceiveVibration` is false while
   hunting): it's busy with what it found, as a fighting wolf ignores a thrown stick.
6. **Lulled** (M4, 200 ticks), when a Singer's horn plays within 12 blocks (items.md §1.2). It drops
   any target, folds its crest, shows note particles, with the subtitle "Nester lulled", and can't
   target the player who played for the 200 ticks. It then roams. *A sound:* that player's are
   filtered (above); another's is heard as in Roam and ends the lull with a tell, though the player
   who played still can't be targeted until the 200 ticks are up. Hunters that don't listen
   (Bloombud) are lulled the same way, without the sound rules.

A **reaction** is a tell or a re-aim. Both count for Heard You (the cause, the source entity or the
projectile's owner, gets it if it's a player) and both break Quiet Waters.

Lumen changes steps 3 to 5 (section 6), and dawn ends them (section 4).

## 4. Retreat at dawn
- **Who retreats:**
  - every **Nester**: it spawns only in Endure (creatures.md, "Endure only"), so it always goes home,
    in caves too;
  - every hunter flagged **surface** at spawn.
  - Never a persistent mob: vanilla's rule is `isPersistenceRequired()` (a name tag, picked-up gear)
    or `requiresCustomPersistence()` (riding any vehicle, or leashed). Those stay, as they would stay
    from vanilla's despawn.
- **Surface or cave, decided once at spawn** (any spawn reason, saved with the mob): a hunter is a
  **cave dweller** if it spawns in the Hollows biome (`thesift:sift_hollows`, which begins some 20 to
  30 blocks under the ground, WP-063); otherwise it is **surface**. The biome alone decides: sky
  access and heightmaps would be wrong, since leaves and roofs block sky light and `WORLD_SURFACE`
  counts songwood crowns. The flag never changes, so a surface Bloombud under a canopy, an overhang
  or a player's roof still retreats, and a cave Bloombud that wanders up still stays.
- **Return-by:** a hunter that retreats saves, at spawn, the Tide clock's total tick at which the
  next Thrive begins (the clock's total ticks rounded up to the next multiple of 30 000). Spawn
  eggs and `/summon` work the same way: one summoned in Thrive lives through the coming Endure and
  leaves after it. If the clock is set back so that the return-by is more than a cycle ahead, it is
  recomputed.
- **When:** each picks its moment from its UUID, in the first two thirds of falling Flow (cycle ticks
  27 000 to 29 000), so 30 Nesters don't dig on one tick.
- **How:** it stops what it's doing (but see "fighting" below) and goes to soil:
  1. the soil block it stands on, if any; else the nearest soil with air above within 16 blocks and
     outside every lumen radius, searched a few columns per tick; it walks there (up to 200 ticks);
  2. it **digs**: 60 ticks of sinking into the block, with the block's particles and a digging sound
     subtitled "Nester burrows" (the warden's dig, shortened for a common mob);
  3. it is removed: no drops, no XP. It left; it wasn't killed. Hurt mid-dig, it keeps digging;
     killed mid-dig, it drops as any kill does.
  - No soil within 16 (a hymnstone floor, a bridge): it walks 8 blocks on and looks again every 100
    ticks.
- **Fighting:** a hunter hunting at its moment keeps fighting until its target is 16 blocks away (the
  vision's rule), then retreats.
- **The guarantee, by Thrive:** at Thrive's first tick, a sweep goes through every loaded hunter
  (`ServerLevel.getAllEntities()`, which includes those in border chunks that don't tick) and removes
  each non-persistent one past its return-by (still fighting, or never found soil), with a burst of
  soul wisps and the burrow sound: the tide takes it. A hunter in an unloaded chunk is checked when it
  loads (`ServerEntityEvents.ENTITY_LOAD`), and every hunter checks on its own tick too. So **no
  retreating hunter is ever present in Thrive or rising Flow.** The vision's "keeps fighting until 16 blocks away" is capped by
  this sweep (D-023): without the cap, a player who stays close would keep a Nester into Thrive.

## 5. Enduring variants
- **Which:** the common hunters: Nester, Bloombud (M2); Pollinator, Sprout (M5). Never bosses.
- **When:** at a natural spawn in Endure, with a chance of **25 %** (on Hard 35 %).
- **How long:** until the next Thrive, for **every** hunter: surface, cave and persistent alike. An
  enduring hunter saves the same return-by tick; past it (at the Thrive sweep, on load or on its own
  tick) its modifiers go, the trail stops, and a few wisps leave it (the Endure leaves it). Surface
  ones have usually burrowed by then. So enduring variants exist only around Endure, as the bible
  says.
- **What:** health ×1.5, attack damage ×1.25, knockback resistance +0.2 (attribute modifiers with the
  id `thesift:enduring`, so they can be removed cleanly). One extra loot roll while enduring.
- **Read without colour (mission §7.6):** a **larger crest / extra spikes** (a model part only the
  variant shows), **trailing soul wisps** every 10 ticks, a faint emissive glow, and a different idle
  subtitle ("Enduring Nester growls").
- Analogs: the zombie's spawn-reinforcement and leader bonuses, the warden's emissive spots, the
  charged creeper (a variant read by shape and effect).

## 6. Lumen: light the hunters won't enter
### Diverge
1. **Repel radius**, as piglins and soul fire (`#piglin_repellents`, a brain memory of the nearest one).
2. **No-spawn radius** only (a torch's job).
3. **Damage aura**: hunters take damage near lumen. Combat-y; lumen becomes a weapon.
4. **Blind**: hunters can't hear inside the radius. Elegant but invisible.
5. **Fear on sight**: a hunter that sees lumen flees for 5 s.
6. **Repel + no-spawn** (1 + 2).
7. **The reaction stops at the edge**, so players see the radius working.
8. **Charge**: lanterns burn out each Endure.

### Converge: rubric (1–5)
| # | Fantasy | Vanilla-feel | Readable | Fair | Feasible | Cheap | Σ |
|---|---|---|---|---|---|---|---|
| 1 | 4 | 5 | 3 | 4 | 4 | 4 | 24 |
| 2 | 2 | 5 | 2 | 4 | 5 | 5 | 23 |
| 3 | 3 | 2 | 4 | 2 | 4 | 4 | 19 |
| 4 | 4 | 3 | 1 | 3 | 4 | 4 | 19 |
| 5 | 3 | 3 | 3 | 3 | 3 | 3 | 18 |
| 6 | 4 | 5 | 3 | 5 | 4 | 4 | **25** |
| 7 | 5 | 4 | 5 | 5 | 4 | 4 | **27** |
| 8 | 3 | 3 | 3 | 3 | 3 | 4 | 19 |

7 isn't a rule on its own (it says what players see, not what keeps them safe), so it joins 6.

### Decision: **6, with 7 as the tell**
Lumen blocks (lumen bloom, lumen lantern) are a **point-of-interest type**, `thesift:lumen`, as vanilla
finds lightning rods and nether portals. A hunter asks "is there lumen within 6 of this position?" for
**the position it is about to go to**, not only where it stands, and the POI index answers from the
few sections that hold any. Repel radius **6**:
1. **Destinations.** Every destination a hunter picks (the gallop spot, the search, a wander target,
   soil to burrow in, each chase step) is checked. One inside the radius is replaced by **the rim
   point**: 7 blocks from the lumen, on the side facing the hunter. If that point is inside another
   lumen's radius, it moves outward a block at a time, up to 16 from the first lumen, until it is
   outside every radius; if none is, the hunter drops the destination and roams away.
2. **The rim.** A listener whose sound came from inside the radius gallops to the rim point, turns to
   the sound, keeps its crest up and paces along the rim for the search's 60 ticks, then roams away.
   That is the tell: players watch it come close and stop.
3. **Paths.** Paths aren't planned around radii (that would ask the POI index at every path node).
   While moving, a hunter checks its own position every 5 ticks; inside 6.5 it stops, walks back out
   to the rim, and plans its path once more. A second entry on the way to the same destination drops
   it, and the hunter roams away. A hunter that finds itself inside (lumen placed next to it) walks
   out.
4. **Hunting.** A target that steps inside the radius is dropped: the hunter goes to the rim.
5. **Not a weapon.** A hunter hurt by an attacker who stands inside a radius doesn't stand and take it:
   it flees 16 blocks from the lumen for 100 ticks, then roams. No free kills from a lumen camp, and
   no stand-off.
- **No hunter spawns within 8** of lumen (the spawn rules ask the POI index, last, after the cheap
  checks).
- **Ranged hunters** (M5's Pollinator) can still lob from outside the rim: a lumen camp is a camp, not
  a fortress. Lanterns don't burn out (their cost is the Endure petals to craft them, WP-065).
- **The gate sanctuary** stays what entry_path.md §7 makes it: no hostile spawns within about 16
  blocks of a gate (WP-070 sets the number; the gate's position is in `SiftLinks`, so it needs no
  POI). It doesn't repel: hunters may walk in, as mobs walk into a lit base, and only lumen holds
  them off.
- The POI type is a fixed list of block states, so a datapack can't add repellents. That is accepted
  (lightning rods and portals work the same way).

## 7. Spawning (shared by all hunters; each mob's doc adds its own)
In this order, cheapest first: the Tide (Nesters: Endure only; every **surface** spawn: Endure only,
because sky light ramps through the spawnable range during Flow, so a light rule alone would let
hunters spawn at dusk); light (Endure's dark, or the Hollows' dark in any Tide); the block below is
**soil** (a stone floor is a safe floor); the monster cap (vanilla's 70 per spawning area); outside
the gate sanctuary; **no lumen within 8** (the POI index, last). Hunter types are built
with `EntityType.Builder.notInPeaceful()`, so Peaceful removes them (vanilla's `allowedInPeaceful`
defaults to true).

## 8. Advancements (items.md §5, M2)
- **Heard You:** a listener reacts (the tell) to a sound the player caused: the event's source entity,
  or its projectile's owner. Creative players aren't heard, so it's earned in survival.
- **Quiet Waters (Should):** be in the Sift for a **whole Endure**, from its first tick to its last,
  without leaving the dimension, and never cause a reaction. Tracked in a player attachment
  `thesift:quiet_endure` (not persistent, so logging out clears it, and not copied on respawn, so
  death clears it): the Endure's number (the Tide clock's total ticks / 30 000), set at Endure's
  first tick for each player in the Sift. It is cleared when the player causes a reaction (judged
  when the sound is accepted, section 3) and on `ServerEntityLevelChangeEvents.AFTER_PLAYER_CHANGE_LEVEL`.
  At falling Flow's first tick, each player in the Sift whose number is this Endure's gets it.
- **Stacked** (a tower of five blubs) and **Low Tide** (gather tidewrack) are WP-072's.

## 9. Per Tide: what each piece does
| | Thrive | Flow (rising) | Endure | Flow (falling) |
|---|---|---|---|---|
| Nester | None (the sweep removed any) | None | Spawns on soil in the dark; listens to 16; hunts | Burrows at its moment; a fighting one keeps fighting until 16 away |
| Bloombud, surface | None | None | Spawns in the dark on soil; ambushes | Burrows |
| Bloombud, cave | Present (dark) | Present | Present; may spawn enduring | Stays |
| Enduring variants | Gone, or reverted (caves and persistent) | None | 25 % (Hard 35 %) of natural spawns | Burrow with the rest |
| Lumen | Repels | Repels | Repels (this is when it matters) | Repels |
| Jukebox | Nobody listens | Nobody listens | Calls listeners within 10 | Nobody listens |
| Chime bell flower | Rings; nobody listens | Rings | Rings, and is heard | Rings |
| Quiet Waters | — | — | Tracked | Awarded on the first tick |
| Singer's horn (M4) | Lulls within 12 | Lulls within 12 | Lulls within 12, and its song calls listeners farther out | Lulls within 12 |
| Blight shriekers (M4) | Shriek; nobody listens | Shriek | Shriek, and listeners within 16 come | Shriek |

**Chime bell flower** (world.md, Should, M2): an entity moving through it rings it, unless it's
sneaking (the flower is the careful-walking test). A ring is a `minecraft:block_activate` game event
(a vibration) with the walker as its source, so a Nester walking through chime bells doesn't alert
the others. A flower rings at most once every 10 ticks.

## 10. Numbers (BALANCE.md on freeze)
| Number | Value | Vanilla analog | Why |
|---|---|---|---|
| Hearing range | 16 (Endure only) | warden 16, sculk sensor 8 | Bible |
| Jukebox range | 10 | allay 10 | Bible |
| Reaction cooldown | 40 ticks, from the tell | warden's vibration cooldown 40 | Vanilla rhythm |
| Tell before gallop | 20 ticks | warden's sniff/roar telegraphs | Time to sneak or flee |
| Gallop give-up | 200 ticks | — | A spot it can't reach |
| Search radius / time | 6 blocks (2 for sneakers), line of sight / 60 ticks | — | A lure works; sneaking saves you |
| Hunt: circling, drop | 30 ticks after a lunge; dropped at 24 blocks or 100 ticks unseen | wolf, spider | The bible's "circles on cooldown" |
| Bump | a player within 2 blocks of a roaming listener | — | Walking into one is a mistake |
| Retreat moment | cycle ticks 27 000–29 000, by UUID | — | Staggered |
| Soil search, dig | 16 blocks; 60-tick dig | warden dig 100 ticks | Shorter for a common mob |
| Fight-on distance | until the target is 16 away, capped by the Thrive sweep | — | Vision, capped (D-023) |
| Enduring chance | 25 % (Hard 35 %) | zombie leader 5 %, spider effects | Common enough to matter, not every mob |
| Enduring stats | health ×1.5, damage ×1.25, KB res. +0.2 | — | Tougher, not unfair |
| Repel radius | 6; rim at 7; no spawns within 8 | piglin repellents 8 | A lantern makes a small camp |
| Rim flee | 16 blocks for 100 ticks | — | Not a weapon |
| Cave dweller | spawned in the Hollows biome | — | Decided once, by biome alone |
| Lull | 200 ticks, hunters within 12 | — | items.md §1.2 |
| Return-by | the next Thrive's first tick, saved at spawn | — | Spawn eggs and `/summon` too |
| Chime bell | once per 10 ticks, not when sneaking | — | — |

## 11. Data and implementation plan
- **Listener:** each listener implements `VibrationSystem` (as `Warden` and `Allay` do) with a
  `DynamicGameEventListener`, `getListenerRadius()` 16 in Endure and 0 otherwise (vanilla reads it on
  every event), `getListenableEvents()` `#thesift:hunter_can_listen`, and the filters of section 3 in
  `canReceiveVibration`. Its vibration data is saved with the entity, as the warden saves its own.
  No polling, and no third game-event consumer.
- **Entity data:** synced `ENDURING` (the model part, the trail and the glow are client-side); the
  crest flare, the lull and the dig as entity events (no payloads). Saved: `Surface`, `Enduring`,
  `ReturnBy`, the lull (player UUID and end tick), the listener data. The retreat moment is computed
  from the UUID (not saved).
- **Tags:** entity `#thesift:hunters`; block `#thesift:hunter_burrowable`; game events
  `#thesift:hunter_can_listen` (with `minecraft:shriek`) and `#thesift:muffled_steps` (M5). `#thesift:cannot_cross` gains `#thesift:hunters` (WP-061's DoD): a
  hunter that wandered through the membrane would land in an Ancient City, where there is no Tide, so
  it would never hear and never leave (D-023).
- **POI:** `thesift:lumen` (Fabric `PoiHelper.register`), the lumen blocks' states.
- **Player attachment:** `thesift:quiet_endure` (int, not persistent).
- **Tide hooks:** one server tick check per level for Endure's first tick and falling Flow's first tick
  (Quiet Waters), and Thrive's first tick (the sweep and the enduring reversion), as `TideCues` does.
  `ServerEntityEvents.ENTITY_LOAD` checks return-by for hunters loaded later;
  `ServerEntityLevelChangeEvents.AFTER_PLAYER_CHANGE_LEVEL` clears Quiet Waters.
- **Inputs from later milestones:** the horn (M4) calls one method on hunters within 12 (`lull(player)`);
  blight shriekers (M4) need nothing beyond the vanilla `shriek` event; Muffled Steps (M5) is read from
  the leggings in the filter.
- **No new environment attributes or payloads.**

## 12. Performance plan
| Cost | Plan | Budget (measured in WP-066/067) |
|---|---|---|
| Listening | Vanilla dispatch by section; radius 0 outside Endure | 30 listening Nesters ≤ 30 wardens' vibration handling |
| Lumen | A POI query per destination, and every 5 ticks per moving hunter; sections without POIs cost a lookup | ≤ 0.05 ms per tick for 30 hunters near 10 lumen blocks |
| Soil search | Underfoot first (almost always soil in the Meadow); else a few columns per tick, by heightmap | No tick over 0.5 ms from the search |
| Retreat and sweep | One check per hunter per second in falling Flow; the sweep once per cycle | Negligible; logged |
| Spawning | Cheap checks first, the POI last | Within the monster cap; no measurable change to spawn cost |
| Whole system | 30 Nesters hunting in Endure in a 10-chunk view | ≤ 1.5× the same number of the nearest vanilla analog (zombies; PLAN WP-067), by the `SiftPerfTest` method |

## 13. Failure modes and edge cases
| Case | Handling |
|---|---|
| A listener hearing itself or another hunter | Filtered (section 3): no self-trigger, no pack chains |
| Peaceful | No hunters spawn; existing ones are removed (`notInPeaceful()`) |
| Creative and spectator players | Not heard (as the warden); never targets. No Heard You in creative |
| Blubs | Their steps and hops are vibrations, so a following blub can draw a Nester (accepted, as with wolves near a warden). A curled or sitting blub makes none. Searches find blubs; M1's Endure shelter keeps untamed blubs still |
| Illagers (M4) | Nesters hunt them too (creatures.md); the camp's Endure behaviour hides them |
| `mobGriefing` false | Burrowing still removes the hunter (it changes no blocks; the dig is cosmetic) |
| Unloaded chunks at dawn | A retreating hunter past its return-by is removed when it loads |
| Spawn eggs and `/summon` | A return-by like any spawn: it leaves after the coming Endure |
| The clock set back by a command | A return-by more than a cycle ahead is recomputed |
| No soil nearby at dawn | It keeps looking; the Thrive sweep takes it if it never finds any |
| A fight that won't end | The Thrive sweep ends it |
| Persistent hunters (name tag, boat, minecart, leash) | Never retreat, never swept, as vanilla never despawns them. They don't listen outside Endure |
| The membrane | Hunters can't cross (`#thesift:cannot_cross`); none ever reach the Overworld |
| Overworld | No hunters there; nothing in this doc applies |
| Lumen placed beside a hunter | It walks out to the rim |
| Lumen broken mid-Endure | The POI goes with it; the next check lets hunters in |
| The gate sanctuary (WP-070) | No spawns within ~16 (entry_path.md §7); not a repel, so only lumen holds hunters off |
| Two lumen radii side by side | The rim point moves out until it is outside both, or the destination is dropped |
| Eating while sneaking in Endure | Heard: `eat` and `drink` aren't in vanilla's sneaking tag |
| A jukebox boxed in wool | Muffled (vanilla occlusion) |
| Logging out mid-Endure | Quiet Waters' tracking is lost (not persistent); a later Endure starts it again |

## Critique log
- **Round 1 (2026-10-02): FAIL**, 5 must-fix; scores template 3, canon 3, vanilla-feel 4, player value 3,
  readability 4, feasibility 3, bible consistency 2. Every vanilla claim was checked in the 26.3 sources
  before acting. Fixed:
  - M1, the listener heard itself and other hunters: filtered, as the warden filters through
    `canTargetEntity` (section 3).
  - M2, `canSeeSky` (sky light 15) put hunters under leaves and roofs into the cave class: the class is
    decided once at spawn, by biome and depth (section 4).
  - M3, burrowing ignored world.md ("soil, not stone") and systems.md (go to sculk; fight until 16):
    soil is required and searched for, the 16-block rule is kept and capped by the Thrive sweep (D-023).
  - M4, hunters could cross the membrane into a Tide-less Overworld: `#thesift:hunters` joins
    `cannot_cross` (D-023).
  - M5, a hunter-centred lumen memory couldn't judge a sound's spot 16 blocks away: lumen is a POI,
    queried at each destination (section 6).
  - Should-fix, all taken: spectators and creative (not heard); option 6's text (the warden's projectile
    case); the jukebox interval (every 20 ticks) and route (the listener's own tag, no mixin consumer);
    the state machine (cooldown start, retargeting, sight, drop rules, circling); `notInPeaceful()`;
    vanilla's persistence rule (boats, minecarts, leashes); damage mid-dig; enduring variants in caves
    (they revert at Thrive); not a weapon at the rim (flee); the spawn check order; Quiet Waters by
    Endure number, cleared on logout and dimension change; the chime bell flower; the sanctuary deferred
    to WP-070 at the vision's ~16; "hunter" and "listener" defined; the template's sections (how players
    learn, per Tide, data, performance); the subtitle "Nester hears something".
- **Round 2 (2026-10-02): FAIL**, 4 must-fix; scores template 5, canon 4, vanilla-feel 4, player value 3,
  readability 4, feasibility 3, bible consistency 3. Parked for the owner's playtest rework, then fixed
  (every vanilla claim checked again in the 26.3 sources: `GameEventTagsProvider`, `Warden`,
  `VibrationSystem`, `Mob.requiresCustomPersistence`, `PersistentEntitySectionManager`). All taken:
  - M1, sounds per state: each state says what a sound does (Hunt ignores; Gallop and Search re-aim
    without a tell); a re-aim is a reaction, for Heard You and Quiet Waters alike (section 3).
  - M2, `WORLD_SURFACE` counts songwood crowns: cave dwellers are decided by the Hollows biome alone
    (section 4).
  - M3, frozen rules missing: the Lulled state and its filter (the horn, M4), the Muffled Steps
    filter (M5), and blight shriekers heard through `minecraft:shriek` in the listen tag (D-012, M4);
    each with its input in the data plan.
  - M4, false vanilla claims: eating and drinking are heard while sneaking (the tag's real contents
    listed); option 6 states the warden's projectile rule as the source has it.
  - Should-fix: Quiet Waters cleared on death and `AFTER_PLAYER_CHANGE_LEVEL`, judged on acceptance
    (filters run again on delivery); every hunter loses enduring at Thrive; a saved return-by covers
    spawn eggs, `/summon`, unloaded chunks and a clock set back; surface spawns in Endure only; rim
    points outside every radius, soil inside a radius skipped, one re-plan then give up; "within 2 of
    it"; the sweep covers border chunks, and `ENTITY_LOAD` the rest; the §2 soil row; the sanctuary
    is no-spawn only; the 1.5× budget; the lumen rubric; "any vehicle".
