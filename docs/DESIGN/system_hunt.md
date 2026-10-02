# The hunt (WP-060)

M2's system: **Endure means danger**. The vision (systems.md §4 N8, §1) and the frozen bible fix the
rules (D-011, D-013, creatures.md rows Nester, Bloombud, "enduring variants"; world.md "Lumen";
items.md M2 advancements). This doc decides how they work, and their numbers, so the M2 mobs
(WP-061/062) and blocks (WP-064) can be designed against one system.

Fixed by the bible (not reopened here):
- **Who listens:** each area's hunters, only in Endure. In 1.0 that's the **Nester** (Singer's Meadow).
- **What they hear:** what a sculk sensor hears (`#vibrations`) out to a warden's **16 blocks**, plus
  **jukeboxes within 10** (not a vibration). The vanilla vibration particle is the tell.
- **Retreat:** at falling Flow, surface hostiles burrow away (telegraphed) and are gone by Thrive. Cave
  dwellers stay.
- **Enduring variants** of the common hostiles (Nester, Bloombud; later Pollinator, Sprout) in Endure:
  more health and damage, marked by shape and particles, not colour alone.
- **Lumen** repels hunters: a small radius they won't enter, as piglins avoid soul fire.

## 1. Hearing: how a hunter hears, and what it does next
### Diverge (written before scoring)
1. **Vanilla vibration listener per hunter** (`VibrationSystem`, as the warden, sculk sensor and allay):
   the engine routes `#vibrations` events, checks occlusion (wool), draws the particle, and delays by
   distance. Radius 16 only in Endure; 0 otherwise.
2. **Our global game-event hook** (the blub's route, D-021): one consumer looks up hunters near each
   vibration. Cheap per event, but we'd re-implement occlusion, the particle and the travel delay.
3. **Brain sensor** polling nearby players' movement every N ticks. Polling; not what a sensor hears.
4. **Hear only players**: filter the vibration's source entity to players. Simple, but snowballs,
   arrows and doors (vanilla lures) would stop working.
5. **Hear everything, investigate first**: on a vibration the hunter turns, flares its crest, gallops to
   the *spot*, sniffs, and attacks only what it finds there. Lures work; sneaking works.
6. **Hear everything, attack the source entity directly**: faster, but a thrown snowball would "teleport"
   aggression to the thrower, which vanilla never does (the warden goes to the spot).
7. **Anger meter** like the warden's: repeated sounds raise anger until it locks on. Rich, but the
   warden owns that idea, and the Nester is a common mob, not a boss.
8. **Pack call**: a hearing Nester howls, and others within 24 come. Strong drama; risks chains that
   sweep the Meadow.
9. **Jukebox as a magnet**: a playing jukebox draws hunters every 2 s while it plays (jukebox events
   repeat every 20 ticks). A base with music is a deliberate beacon.

### Converge: rubric (1–5; the vision's criteria)
| # | Fantasy | Vanilla-feel | Readable | Fair | Feasible | Cheap | Σ |
|---|---|---|---|---|---|---|---|
| 1 | 4 | 5 | 5 | 5 | 5 | 4 | **28** |
| 2 | 4 | 3 | 3 | 4 | 4 | 5 | 23 |
| 3 | 2 | 2 | 2 | 3 | 4 | 3 | 16 |
| 4 | 3 | 2 | 4 | 3 | 5 | 5 | 22 |
| 5 | 5 | 5 | 5 | 5 | 4 | 4 | **28** |
| 6 | 3 | 2 | 3 | 2 | 5 | 5 | 20 |
| 7 | 4 | 3 | 4 | 4 | 3 | 4 | 22 |
| 8 | 5 | 3 | 4 | 2 | 4 | 3 | 21 |
| 9 | 4 | 4 | 5 | 4 | 5 | 4 | **26** |

### Decision: **1 + 5, with 9 as a consequence**
- Each hunter carries a **vanilla vibration listener** (1). Its radius is 16 in Endure and 0 in any other
  Tide, so outside Endure it hears nothing at no cost. Occlusion (wool), the travel delay and the
  vibration particle are vanilla's, unchanged. Sneaking muffles steps, as with every sensor.
- **Jukeboxes**: the listener can't hear `jukebox_play`, so the existing game-event hook (D-020/D-021)
  gains a third consumer: a playing jukebox within 10 blocks of a hunter in Endure counts as a heard
  sound at the jukebox, every time the event repeats (every second). That makes **9** happen naturally:
  a base playing music in Endure calls the hunters, until it stops.
- **Investigate, then hunt** (5). A heard sound:
  1. **Tell** (1 s): the hunter turns to the sound, its crest flares (a model pose and a sound with
     the subtitle "Nester hears you"), then
  2. **Gallop** to the sound's position (not to its source entity), at a sprint, then
  3. **Search** for 3 s: any non-sneaking player, illager or blub within 6 blocks of the spot is
     attacked (sneaking players within 6 are found only if within 2). Nothing found: it sniffs and goes
     back to roaming.
  4. **Cooldown**: 2 s before it can react to another sound (vanilla's vibration cooldown is 40 ticks
     for the warden; we keep 40).
- **Why not 7 or 8:** the warden owns anger; a pack call makes Endure unplayable for anyone without
  lumen. One Nester, one sound, one lunge keeps the rule readable.

## 2. Retreat at dawn
- **When:** falling Flow (cycle ticks 27 000–30 000). Each surface hunter picks a random moment in the
  first two thirds of falling Flow (staggered, so 30 Nesters don't dig on one tick).
- **Surface vs cave:** a hunter is a **cave dweller** if the block above its head has no sky access
  (`level.canSeeSky` false). Cave dwellers stay (they live in the Hollows, WP-063). A surface hunter
  that walks into a cave during falling Flow stops counting as surface.
- **How:** the warden's dig, retold: a 3 s animation (sinking with the ground's block particles), a
  digging sound with the subtitle "Nester burrows", then it is removed (no drops, no XP: it left, it
  wasn't killed). A hunter mid-chase finishes its current lunge first, then digs within 20 s at most.
- **Guarantee:** by Thrive (cycle tick 0), no surface hunter remains. A safety sweep at the start of
  Thrive removes any left (e.g. one that was in an unloaded chunk during falling Flow: it digs when its
  chunk next ticks, if it's Thrive or Flow).
- **Persistence:** name-tagged or leashed hunters don't dig (vanilla rule: persistent mobs stay).

## 3. Enduring variants
- **Which:** the common hostiles: Nester, Bloombud (M2); Pollinator, Sprout (M5). Never bosses.
- **When:** at spawn, in Endure, with a chance of **25 %** (on Hard 35 %). The variant keeps its status
  until it leaves (it burrows at dawn anyway).
- **What:** health ×1.5, attack damage ×1.25, knockback resistance +0.2. It drops one extra item roll.
- **Read without colour (mission §7.6):** a **larger crest / extra spikes** (a model part only the
  variant shows), **trailing soul particles** every few ticks, and a faint emissive glow. A subtitle
  difference on its idle sound ("Enduring Nester growls").
- Analogs: the zombie's spawn-reinforcement and leader bonuses, the warden's emissive spots, the
  charged creeper (a variant read by shape and effect).

## 4. Lumen: light the hunters won't enter
### Diverge
1. **Repel radius**, as piglins and soul fire (`#piglin_repellents`, a brain memory of the nearest one).
2. **No-spawn radius** only (a torch's job).
3. **Damage aura**: hunters take damage near lumen. Combat-y; lumen becomes a weapon.
4. **Blind**: hunters can't hear inside the radius. Elegant but invisible.
5. **Fear on sight**: a hunter that sees lumen flees for 5 s.
6. **Repel + no-spawn** (1 + 2).
7. **Lumen dims the vibration particle** so the player sees they're safe. Cosmetic.
8. **Charge**: lanterns burn out each Endure.

### Decision: **6, with 7 as the tell**
- **`#thesift:hunter_repellents`** (lumen bloom, lumen lantern; later blocks can join). Hunters keep a
  memory of the nearest repellent within 8, refreshed every 2 s (as piglins' sensor does), and
  **won't path into, chase into, or search within 6 blocks** of it. A hunter already inside walks out.
- **No hunter spawns within 8** of a repellent (the spawn predicate checks the tag in a small box).
- **The tell:** inside the radius, vibration particles from the player still fly, but a hunter's
  reaction stops at the edge: it turns, flares, and paces the rim. Visible and audible, so players learn
  the radius.
- **Not a weapon, not permanent danger removal:** ranged hunters (M5's Pollinator) can still lob at the
  edge. Lanterns don't burn out (the cost is the Endure petals to craft them, WP-065).

## 5. Advancements (items.md §5, M2)
- **Heard You:** a hunter reacts (step 1, the tell) to a vibration caused by the player.
- **Quiet Waters (Should):** be in the Sift for a **whole Endure** (from its start to its end, without
  leaving the dimension) and never cause a hunter's reaction. Tracked per player per Endure in a Fabric
  attachment: `endureStartedInSift` and `heardThisEndure`, reset at each Endure's start.
- **Stacked** (a tower of five blubs) and **Low Tide** (gather tidewrack) are WP-072's.

## 6. Numbers (BALANCE.md on freeze)
| Number | Value | Vanilla analog | Why |
|---|---|---|---|
| Hearing range | 16 (Endure only) | warden 16, sculk sensor 8 | Bible |
| Jukebox range | 10 | allay 10 | Bible |
| Reaction cooldown | 40 ticks | warden's vibration cooldown 40 | Vanilla rhythm |
| Tell before gallop | 20 ticks | warden's sniff/roar telegraphs | Time to sneak or flee |
| Search radius / time | 6 blocks (2 for sneakers) / 3 s | — | A lure works; sneaking saves you |
| Retreat window | first two thirds of falling Flow, ≤ 20 s mid-chase grace | warden dig 100 ticks | Gone by Thrive |
| Enduring chance | 25 % (Hard 35 %) | zombie leader 5 %, spider effects | Common enough to matter, not every mob |
| Enduring stats | health ×1.5, damage ×1.25, KB res. +0.2 | — | Tougher, not unfair |
| Repel radius | 6 (no spawns within 8) | piglin repellents 8 | A lantern makes a small camp |

## 7. Edge cases
| Case | Handling |
|---|---|
| Peaceful | No hunters spawn; existing ones are removed by vanilla's Peaceful rule |
| Players in creative / spectator | Their vibrations are heard (vanilla sensors hear creative steps), but the search ignores them (as mob targeting does) |
| Blubs | Their steps and hops are vibrations, so a following blub can draw a Nester (accepted, as with wolves near a warden). A curled or sitting blub makes none. Nesters attack blubs found in a search; M1's Endure shelter keeps untamed blubs still |
| Illagers (M4) | Nesters hunt them too (creatures.md); the camp's Endure behaviour hides them |
| `mobGriefing` false | Burrowing still removes the hunter (it changes no blocks; the dig is cosmetic) |
| Unloaded chunks at dawn | The hunter digs when its chunk next ticks; the Thrive sweep catches the rest |
| Overworld | No hunters there; nothing in this doc applies |
| The gate sanctuary (WP-070) | No hostile spawns within 32 of a gate; a hunter chasing a player into the gate's hill stops at 16 |

## 8. Tech notes
- **Listener:** each hunter implements vanilla's `VibrationSystem` (as `Warden` and `Allay` do), with
  `getListenerRadius()` returning 16 in Endure and 0 otherwise, `canReceiveVibration` false outside
  Endure or during cooldown/retreat, and the vanilla `DynamicGameEventListener`. No polling.
- **Jukebox:** a third consumer of `ServerLevelGameEventMixin` (after FrameMusic and BlubMusic): only
  for `jukebox_play`, only in the Sift, only in Endure; looks up hunters in a 20-block box.
- **Repellents:** a sensor-like check every 40 ticks per hunter, over a block tag, in the box piglins
  use (`PiglinSpecificSensor.findNearestRepellent`: 8 blocks out, 4 up and down, by Manhattan
  distance; vanilla runs it on its sensor's schedule), cached in the mob.
- **Retreat:** a goal with top priority in falling Flow; the moment is `hash(uuid) % window`.
- **Quiet Waters / Heard You:** the reaction step calls one award hook with the player that caused the
  vibration (the event's source entity, or the projectile's owner).
- **Cost:** a listener per hunter is what wardens and sensors cost. Hunters count against vanilla's
  monster cap (70 per spawning area), and the cost is measured in WP-066/067 against the warden.

## Critique log
