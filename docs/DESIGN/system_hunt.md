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
  steps, a door, a thrown snowball landing, a playing jukebox within 10. Sneaking and wool keep you
  quiet, as in the Deep Dark.
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
| Soil | Hunters dig into it at dawn in plain view; nothing ever spawns on the hymnstone of a gate mound |

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
   the thrower. Vanilla does this only in one narrow case: a warden that hears a second projectile
   from the same owner within 100 ticks, with the owner within 30 blocks, goes to the owner.
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
  `#ignore_vibrations_sneaking` (steps, landing, swimming, shooting, eating), as with every sensor.
- **Jukeboxes ride the same listener** (9). Its listenable events are a tag of our own,
  `#thesift:hunter_can_listen` = `#minecraft:vibrations` + `minecraft:jukebox_play`, as the warden's
  `#warden_can_listen` widens its own. A playing jukebox repeats its event every second, so a base
  playing music in Endure calls the listeners until it stops. The particle, the delay and wool
  occlusion apply to jukeboxes too (a jukebox boxed in wool is muffled). rules.md's tech note named a
  second, allay-style listener; one listener with a wider tag does the same with less code (D-023).
- **What a listener ignores** (its `canReceiveVibration`, as the warden's filters through
  `canTargetEntity`):
  - any event while it is in its cooldown, its tell, retreating, or dead, or outside Endure;
  - events whose source entity, or whose projectile's owner, is itself or any hunter (so it never
    reacts to its own steps, and a gallop never sets off the next Nester: no pack chains);
  - events from creative or spectator players (vanilla's `NO_CREATIVE_OR_SPECTATOR`, as the warden;
    vanilla already drops spectators' events);
  - `jukebox_play` farther than 10 blocks. The event's own radius is 10, but the dispatcher picks
    listeners by whole sections, so the distance is checked here.

### The reaction, exactly
A listener is always in one of these states.
1. **Roam.** It wanders. It does not target by sight: a player it sees but doesn't hear is safe,
   except one within 2 blocks (a bump), or one that hurts it (it hunts the attacker).
2. **Tell** (20 ticks), on a heard sound, after vanilla's travel delay. It stops, turns to the sound's
   position, and flares its crest, with a sound subtitled "Nester hears something". Its **cooldown**
   (40 ticks, the warden's vibration cooldown) starts now. The cause of the sound (the source entity,
   or the projectile's owner) gets **Heard You** if it's a player.
3. **Gallop** to the sound's position (not its source entity), at a sprint. A sound heard once the
   cooldown is over moves the spot (the latest wins) without a new tell: the crest is already up, as a
   warden re-aims at each new disturbance. A gallop that can't reach the spot within 200 ticks ends
   where it stands, and the search starts there.
4. **Search** (60 ticks). It sniffs around the spot. It attacks the nearest **target** within 6 blocks
   of the spot that it can see (line of sight from its eyes: no finding players through stone).
   A sneaking player is found only within 2. Targets: survival and adventure players, illagers, blubs.
   Nothing found: it goes back to roaming.
5. **Hunt.** It chases and lunges. After each lunge it circles the target for 30 ticks (the bible's
   "circles on cooldown"), then lunges again. It drops the target, and roams, when the target dies or
   leaves, is more than 24 blocks away, has been out of sight for 100 ticks, steps inside lumen's
   radius, or turns creative or spectator.

Lumen changes steps 3 to 5 (section 6), and dawn ends them (section 4).

## 4. Retreat at dawn
- **Who retreats:**
  - every **Nester**: it spawns only in Endure (creatures.md, "Endure only"), so it always goes home,
    in caves too;
  - every hunter flagged **surface** at spawn.
  - Never a persistent mob: vanilla's rule is `isPersistenceRequired()` (a name tag, picked-up gear)
    or `requiresCustomPersistence()` (riding a boat or minecart, or leashed). Those stay, as they would
    stay from vanilla's despawn.
- **Surface or cave, decided once at spawn** (any spawn reason, saved with the mob): a hunter is a
  **cave dweller** if it spawns in `thesift:sift_hollows` or more than 8 blocks below the
  `WORLD_SURFACE` heightmap of its column; otherwise it is **surface**. The flag never changes, so a
  surface Bloombud under a songwood canopy, an overhang or a player's roof still retreats, and a cave
  Bloombud that wanders up still stays. (Sky access would be wrong: leaves and roofs block sky light.)
- **When:** each picks its moment from its UUID, in the first two thirds of falling Flow (cycle ticks
  27 000 to 29 000), so 30 Nesters don't dig on one tick.
- **How:** it stops what it's doing (but see "fighting" below) and goes to soil:
  1. the soil block it stands on, if any; else the nearest soil with air above within 16 blocks,
     searched a few columns per tick; it walks there (up to 200 ticks);
  2. it **digs**: 60 ticks of sinking into the block, with the block's particles and a digging sound
     subtitled "Nester burrows" (the warden's dig, shortened for a common mob);
  3. it is removed: no drops, no XP. It left; it wasn't killed. Hurt mid-dig, it keeps digging;
     killed mid-dig, it drops as any kill does.
  - No soil within 16 (a hymnstone floor, a bridge): it walks 8 blocks on and looks again every 100
    ticks.
- **Fighting:** a hunter hunting at its moment keeps fighting until its target is 16 blocks away (the
  vision's rule), then retreats.
- **The guarantee, by Thrive:** at Thrive's first tick, a sweep removes every non-persistent hunter that
  should have retreated and is still there (still fighting, or never found soil), with a burst of soul
  wisps and the burrow sound: the tide takes it. A retreating hunter in an unloaded chunk is removed
  the same way on its first tick outside Endure and falling Flow. So **no retreating hunter is ever
  present in Thrive or rising Flow.** The vision's "keeps fighting until 16 blocks away" is capped by
  this sweep (D-023): without the cap, a player who stays close would keep a Nester into Thrive.

## 5. Enduring variants
- **Which:** the common hunters: Nester, Bloombud (M2); Pollinator, Sprout (M5). Never bosses.
- **When:** at a natural spawn in Endure, with a chance of **25 %** (on Hard 35 %).
- **How long:** until the next Thrive. Surface ones have burrowed by then. A cave dweller loses it at
  Thrive's first tick: its modifiers go, the trail stops, and a few wisps leave it (the Endure leaves
  it). So enduring variants exist only around Endure, as the bible says.
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

### Decision: **6, with 7 as the tell**
Lumen blocks (lumen bloom, lumen lantern) are a **point-of-interest type**, `thesift:lumen`, as vanilla
finds lightning rods and nether portals. A hunter asks "is there lumen within 6 of this position?" for
**the position it is about to go to**, not only where it stands, and the POI index answers from the
few sections that hold any. Repel radius **6**:
1. **Destinations.** Every destination a hunter picks (the gallop spot, the search, a wander target,
   soil to burrow in, each chase step) is checked. One inside the radius is replaced by **the rim
   point**: 7 blocks from the lumen, on the side facing the hunter.
2. **The rim.** A listener whose sound came from inside the radius gallops to the rim point, turns to
   the sound, keeps its crest up and paces along the rim for the search's 60 ticks, then roams away.
   That is the tell: players watch it come close and stop.
3. **Paths.** While moving, a hunter checks its own position every 5 ticks; inside 6.5 it stops and
   walks back out to the rim. A hunter that finds itself inside (lumen placed next to it) walks out.
4. **Hunting.** A target that steps inside the radius is dropped: the hunter goes to the rim.
5. **Not a weapon.** A hunter hurt by an attacker who stands inside a radius doesn't stand and take it:
   it flees 16 blocks from the lumen for 100 ticks, then roams. No free kills from a lumen camp, and
   no stand-off.
- **No hunter spawns within 8** of lumen (the spawn rules ask the POI index, last, after the cheap
  checks).
- **Ranged hunters** (M5's Pollinator) can still lob from outside the rim: a lumen camp is a camp, not
  a fortress. Lanterns don't burn out (their cost is the Endure petals to craft them, WP-065).
- **The gate sanctuary** (WP-070) works the same way, centred on the gate (its position is in
  `SiftLinks`, so it needs no POI). The vision says about 16; WP-070 sets the number.
- The POI type is a fixed list of block states, so a datapack can't add repellents. That is accepted
  (lightning rods and portals work the same way).

## 7. Spawning (shared by all hunters; each mob's doc adds its own)
In this order, cheapest first: the Tide (Nesters: Endure only); light (Endure's dark, or caves); the
block below is **soil** (a stone floor is a safe floor); the monster cap (vanilla's 70 per spawning
area); **no lumen within 8** (the POI index); outside the gate sanctuary. Hunter types are built
with `EntityType.Builder.notInPeaceful()`, so Peaceful removes them (vanilla's `allowedInPeaceful`
defaults to true).

## 8. Advancements (items.md §5, M2)
- **Heard You:** a listener reacts (the tell) to a sound the player caused: the event's source entity,
  or its projectile's owner. Creative players aren't heard, so it's earned in survival.
- **Quiet Waters (Should):** be in the Sift for a **whole Endure**, from its first tick to its last,
  without leaving the dimension, and never cause a reaction. Tracked in a player attachment
  `thesift:quiet_endure` (not persistent, so logging out clears it): the Endure's number (the Tide
  clock's total ticks / 30 000), set at Endure's first tick for each player in the Sift. It is
  cleared when the player causes a reaction or changes dimension (death and respawn included). At
  falling Flow's first tick, each player in the Sift whose number is this Endure's gets it.
- **Stacked** (a tower of five blubs) and **Low Tide** (gather tidewrack) are WP-072's.

## 9. Per Tide: what each piece does
| | Thrive | Flow (rising) | Endure | Flow (falling) |
|---|---|---|---|---|
| Nester | None (the sweep removed any) | None | Spawns on soil in the dark; listens to 16; hunts | Burrows at its moment; a fighting one keeps fighting until 16 away |
| Bloombud, surface | None | None | Spawns in the dark on soil; ambushes | Burrows |
| Bloombud, cave | Present (dark) | Present | Present; may spawn enduring | Stays |
| Enduring variants | Gone, or reverted (caves) | None | 25 % (Hard 35 %) of natural spawns | Burrow with the rest |
| Lumen | Repels | Repels | Repels (this is when it matters) | Repels |
| Jukebox | Nobody listens | Nobody listens | Calls listeners within 10 | Nobody listens |
| Chime bell flower | Rings; nobody listens | Rings | Rings, and is heard | Rings |
| Quiet Waters | — | — | Tracked | Awarded on the first tick |

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
| Retreat moment | cycle ticks 27 000–29 000, by UUID | — | Staggered |
| Soil search, dig | 16 blocks; 60-tick dig | warden dig 100 ticks | Shorter for a common mob |
| Fight-on distance | until the target is 16 away, capped by the Thrive sweep | — | Vision, capped (D-023) |
| Enduring chance | 25 % (Hard 35 %) | zombie leader 5 %, spider effects | Common enough to matter, not every mob |
| Enduring stats | health ×1.5, damage ×1.25, KB res. +0.2 | — | Tougher, not unfair |
| Repel radius | 6; rim at 7; no spawns within 8 | piglin repellents 8 | A lantern makes a small camp |
| Rim flee | 16 blocks for 100 ticks | — | Not a weapon |
| Cave dweller depth | > 8 below `WORLD_SURFACE`, or in the Hollows | — | Decided once |
| Chime bell | once per 10 ticks, not when sneaking | — | — |

## 11. Data and implementation plan
- **Listener:** each listener implements `VibrationSystem` (as `Warden` and `Allay` do) with a
  `DynamicGameEventListener`, `getListenerRadius()` 16 in Endure and 0 otherwise (vanilla reads it on
  every event), `getListenableEvents()` `#thesift:hunter_can_listen`, and the filters of section 3 in
  `canReceiveVibration`. Its vibration data is saved with the entity, as the warden saves its own.
  No polling, and no third game-event consumer.
- **Entity data:** synced `ENDURING` (the model part, the trail and the glow are client-side); the
  crest flare and the dig as entity events (no payloads). Saved: `Surface`, `Enduring`, the listener
  data. The retreat moment is computed from the UUID (not saved).
- **Tags:** entity `#thesift:hunters`; block `#thesift:hunter_burrowable`; game event
  `#thesift:hunter_can_listen`. `#thesift:cannot_cross` gains `#thesift:hunters` (WP-061's DoD): a
  hunter that wandered through the membrane would land in an Ancient City, where there is no Tide, so
  it would never hear and never leave (D-023).
- **POI:** `thesift:lumen` (Fabric `PoiHelper.register`), the lumen blocks' states.
- **Player attachment:** `thesift:quiet_endure` (int, not persistent).
- **Tide hooks:** one server tick check per level for Endure's first tick and falling Flow's first tick
  (Quiet Waters), and Thrive's first tick (the sweep and the enduring reversion), as `TideCues` does.
- **No new environment attributes or payloads.**

## 12. Performance plan
| Cost | Plan | Budget (measured in WP-066/067) |
|---|---|---|
| Listening | Vanilla dispatch by section; radius 0 outside Endure | 30 listening Nesters ≤ 30 wardens' vibration handling |
| Lumen | A POI query per destination, and every 5 ticks per moving hunter; sections without POIs cost a lookup | ≤ 0.05 ms per tick for 30 hunters near 10 lumen blocks |
| Soil search | Underfoot first (almost always soil in the Meadow); else a few columns per tick, by heightmap | No tick over 0.5 ms from the search |
| Retreat and sweep | One check per hunter per second in falling Flow; the sweep once per cycle | Negligible; logged |
| Spawning | Cheap checks first, the POI last | Within the monster cap; no measurable change to spawn cost |
| Whole system | 30 Nesters hunting in Endure in a 10-chunk view | ≤ 2× the same number of zombies, by the `SiftPerfTest` method |

## 13. Failure modes and edge cases
| Case | Handling |
|---|---|
| A listener hearing itself or another hunter | Filtered (section 3): no self-trigger, no pack chains |
| Peaceful | No hunters spawn; existing ones are removed (`notInPeaceful()`) |
| Creative and spectator players | Not heard (as the warden); never targets. No Heard You in creative |
| Blubs | Their steps and hops are vibrations, so a following blub can draw a Nester (accepted, as with wolves near a warden). A curled or sitting blub makes none. Searches find blubs; M1's Endure shelter keeps untamed blubs still |
| Illagers (M4) | Nesters hunt them too (creatures.md); the camp's Endure behaviour hides them |
| `mobGriefing` false | Burrowing still removes the hunter (it changes no blocks; the dig is cosmetic) |
| Unloaded chunks at dawn | A retreating hunter is removed on its first tick outside Endure and falling Flow |
| No soil nearby at dawn | It keeps looking; the Thrive sweep takes it if it never finds any |
| A fight that won't end | The Thrive sweep ends it |
| Persistent hunters (name tag, boat, minecart, leash) | Never retreat, never swept, as vanilla never despawns them. They don't listen outside Endure |
| The membrane | Hunters can't cross (`#thesift:cannot_cross`); none ever reach the Overworld |
| Overworld | No hunters there; nothing in this doc applies |
| Lumen placed beside a hunter | It walks out to the rim |
| Lumen broken mid-Endure | The POI goes with it; the next check lets hunters in |
| The gate sanctuary (WP-070) | Treated as a lumen radius centred on the gate; size per the vision (~16), set in WP-070 |
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
