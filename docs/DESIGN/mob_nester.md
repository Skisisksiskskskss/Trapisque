# Nester (WP-061) — FROZEN 2026-10-02

The M2 hunter. Fixed by the frozen bible (creatures.md row "Nester", D-011, D-013) and the hunt system
(`system_hunt.md`, which this doc builds on and doesn't repeat): it **surfaces in Endure**, **hears
vibrations out to 16 blocks**, **gallops and lunges**, **circles on cooldown**, **burrows away at
falling Flow**, avoids lumen, and attacks illagers too. Canon adds that it "rapidly gallop[s] towards
heroes, lunging and biting" and **can dodge melee** (RESEARCH_BESTIARY "Nester", [W:Nester]).

This doc decides what the bible and the system leave open: what fighting one is like, how it looks
and moves, what it sounds like, and its numbers.

## Concept ladder: what makes meeting a Nester a decision?
The hunt system already makes *avoiding* one a decision (sneak, wool, lumen, lures). The question here
is the fight: when a Nester has found you, what can you do besides trade hits?

### Diverge (written before scoring)
1. **Lunge-and-circle duelist** (canon): it lunges from a few blocks, bites, then circles you while
   its lunge recharges, and sidesteps melee swings while circling. You shield the lunge and strike
   in its recovery, or shoot it while it circles.
2. **Ring the crest**: a critical hit while its crest is flared deafens it for 5 s. A stealth player's
   tool.
3. **Nests**: Nesters surface from nest mounds (a worldgen feature) at Endure's start, and the mounds
   lie quiet in Thrive, so players can scout where the danger will be.
4. **Scent memory**: after losing you, it returns once to where it last saw you.
5. **Loud gallop**: its gallop thuds far and wide (heard at 24 blocks with a subtitle), so you hear it
   coming and have the tell's second to react.
6. **Pairs**: spawns in pairs that circle from opposite sides.
7. **Mimic call**: it whistles your footsteps' rhythm to draw blubs out of shelter.
8. **Threat display**: it rears and rattles before lunging at anyone who looks straight at it, like an
   enderman's stare, inverted.
9. *(unusual)* **Shed crest**: a heavy hit knocks its crest off; crestless, it can't hear until it
   regrows at the next Endure.

### Converge: rubric (1–5; the same seven criteria as mob_blub.md)
| # | Concept | Faithful | Vanilla-native | Readable | Meaningful | Distinct | Connected | Feasible | Total |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Lunge-and-circle duelist | 5 | 4 | 4 | 5 | 4 | 3 | 4 | **29** |
| 2 | Ring the crest | 2 | 2 | 2 | 3 | 4 | 4 | 4 | 21 |
| 3 | Nests | 2 | 3 | 4 | 3 | 4 | 4 | 2 | 22 |
| 4 | Scent memory | 3 | 4 | 3 | 2 | 2 | 2 | 4 | 20 |
| 5 | Loud gallop | 4 | 5 | 5 | 4 | 3 | 4 | 5 | **30** |
| 6 | Pairs | 3 | 4 | 4 | 3 | 2 | 2 | 5 | 23 |
| 7 | Mimic call | 1 | 3 | 2 | 3 | 5 | 4 | 3 | 21 |
| 8 | Threat display | 2 | 3 | 3 | 2 | 2 | 1 | 4 | 17 |
| 9 | Shed crest | 1 | 2 | 4 | 3 | 4 | 4 | 3 | 21 |

Notes on the calls:
- **1** is canon nearly word for word (gallop, lunge, bite, circle, dodge). It turns a found player's
  panic into a read: watch the crouch, shield, punish.
- **5** is cheap and the fairest thing here: the tell is a second; the gallop's thud makes the threat
  audible before it's visible, which matters in Endure's dark and for players who rely on subtitles.
- **2** and **9** hang power on hits players can't aim (no hit locations in vanilla). **3** is a new
  worldgen feature for a mob the bible says "surfaces" anywhere; recorded in IDEAS.md. **7** and **8**
  invent senses or tells the bible doesn't have.
- **6** stays a spawn-table knob (groups of 1–2), not a behaviour.

### Decision: **"The galloping duelist"**: 1 + 5
- **The duel (1):** lunge (crouch, leap, bite), then circle for the lunge's cooldown, sidestepping
  melee swings while circling. Shields and timing beat it; arrows catch it circling.
- **The gallop (5):** loud on purpose. A heard player hears it back.
- **Why not more:** each of the others adds a rule to a mob whose job is to make *one* rule (the
  hearing rule) felt.

## Identity
- **Canon** (RESEARCH_BESTIARY "Nester"): "a long-legged, hostile sifter" [W:Sifter] that will
  "rapidly gallop towards heroes, lunging and biting" [W:Nester], circles while on cooldown and can
  dodge melee; surface, Singer's Meadow. Soul corruption (our enduring variants) affects it.
  **Changed in translation:** Dungeons II's top-down combat becomes a first-person duel with vanilla
  verbs (shield, critical hits, bows); its hearing is the Sift's rule (D-011), not canon; it surfaces
  only in Endure (D-013). Canon gives only "long-legged" for its look, and no teaser shows it (the
  stills D-025 sampled have none), so the crest, the snout and the moss-and-gold palette are our
  inventions, made to read against the teasers' Meadow.
- **One-sentence fantasy:** a long-legged listener that comes galloping out of the dark at the sound
  you made, and dances around your sword.
- **Role:** hostile.
- **Home:** Singer's Meadow (M2) and Hymnstone Rise once it ships (M3), on soil, in Endure only
  (world.md §1.1). No structure spawns.

## Silhouette and look
- **Hitbox:** 0.9 × 1.5 blocks: a body high on four long legs, head level with a player's chest.
  It fits under a two-block ceiling and through a one-wide corridor; a one-block-high gap stops it.
- **Readable at 10 blocks:** the stilt legs (no other Sift mob is long-legged), the forward-thrust
  neck and long snout, and the **crest**: three fins folded flat along the neck, fanned upright and
  pale when it hears.
- **Palette** (new ramps, added to palette.md in WP-067; dark → light):
  - `nester`: `#1e2a24` `#2c3d33` `#3d5143` `#526a55` `#6c8566` `#8aa27c`: moss green, so it reads
    against the coral-pink healthy sculk underfoot and is nothing like the Blub's blue.
  - `nester_crest`: `#6e5330` `#a07c45` `#cfaa63` `#f0d690` `#fff1c4`: pale gold fins; the fanned crest
    shows its light side.
  - Eyes are plain texture on an ordinary Nester; an enduring one's eyes and glow use the existing
    `glyph` cyan on an emissive layer, so the glow stays a marker.
- **Texture:** 64 × 64.
- **Model parts:** body; neck; head with snout and a hinged jaw; crest (three fins, one hinge each);
  four legs of two segments each (thigh, shin); a short tail tuft; **enduring only:** a second, larger
  crest row with spikes (a separate part, hidden on ordinary Nesters).
- **Animations** (procedural clips in the model, as the Blub's, D-021). Durations in ticks:
  - idle: head bobs, crest twitches, weight shifts;
  - walk: a long-legged trot; **gallop**: a bounding gait, body pitched forward;
  - **tell** (20): stops, head up and turned, crest fans upright;
  - **search** (60): head low, sweeping side to side, sniffing;
  - **lunge**: windup 8 (crouch, crest flat, jaw open), leap (until it lands, about 9–10 ticks; the
    bite is live throughout), recovery 12 (stands, crest drooped, head shake);
  - **standing bite**: windup 6 (crouch, crest flat, a step in), snap 2;
  - **circle**: a side-stepping gait facing its target; **guard**: crest fanned upright and rattling
    (as the tell's alert, so a raised crest always means "it's ready"); **dodge** (4): a quick hop
    sideways;
  - **stagger** (30): reels back, head low, crest drooped;
  - **emerge** (40): rises out of the soil, shaking off particles; **dig** (60): forelegs paw, it sinks;
  - **lulled** (M4): crest folds flat, head sways to the song;
  - hurt: a flinch; death: vanilla's tip-over.

## Behavior
### State machine
The hunt system's listener states (system_hunt.md §3: roam, tell, gallop, search, hunt) plus the
Nester's own:
```
emerge (40) ──► roam ──hears──► tell (20) ──► gallop ──► search (60) ──finds──► hunt
                  ▲                                         │ nothing             │
                  └─────────────────────────────────────────┘                     ▼
hunt: approach ──beyond melee reach, within 4──► lunge windup (8) ──► leap (until it lands, ≤ 12) ──► recovery (12) ──► circle (30) ──► approach
      (within melee reach: a standing bite: windup 6, stepping in; hit or miss, then recovery and the circle)   blocked by a shield: stagger 30
falling Flow ──► retreat (system §4): to soil ──► dig (60) ──► gone
a Singer's horn within 12 (M4) ──► lulled (200; system §3) ──► roam
```
What a sound does in each state is the system's (§3): roam hears it (the tell), gallop and search
re-aim to the new spot without a tell, hunt ignores it.
- **Emerge:** a naturally spawned Nester rises out of the soil over 40 ticks (it "surfaces", as the
  bible says), with the soil's particles and a sound subtitled "Nester surfaces" at volume 2 (heard
  32 blocks out: natural spawns are at least 24 blocks from any player, so the sound is how players
  learn that Nesters come up out of the ground; the sight is rare, and that's accepted). It doesn't
  listen while emerging. Nesters from spawn eggs and `/summon` skip it.
- **Lunge:** from just beyond its melee reach out to **4 blocks** (vanilla's `LeapAtTargetGoal`
  reaches 2–4), with line of sight. The aim is **locked when the windup starts**: windup 8 ticks
  (crouch and a hiss, subtitled "Nester hisses"), then a leap toward that locked spot, 0.35 up and
  with its horizontal speed scaled to the locked distance (up to about 0.6, which carries about 2.7
  blocks in its ~9 airborne ticks, enough for a target 4 blocks away with its reach; tuned and
  checked by a GameTest in WP-067), so a short lunge doesn't overshoot. The bite is live from
  take-off until it lands (at most 12 ticks) and lands once, on the first tick a target is within
  its melee reach (`isWithinMeleeAttackRange`). So the windup is the read: **step sideways during
  the 8 ticks** and the leap lands where you were. From 4 blocks the bite comes about 17 ticks after
  the crouch, time to sidestep; from close in it comes sooner, so **up close, raise the shield early**
  (a shield blocks only after it has been up 5 ticks) or back off. Recovery 12 ticks, in which it
  can't dodge.
- **Close quarters:** a target within its melee reach (`isWithinMeleeAttackRange`, a box aligned to
  the world's axes: about 1.6 blocks centre to centre along an axis, about 2.2 on the diagonal) gets a **standing bite**: windup 6 ticks in which
  it steps in toward the target, then the snap, which lands only if the target is still in reach on
  that tick. Hit or miss, the usual recovery and circle follow. A target that presses into melee
  reach during the circle ends the circle early with a standing bite. With no room to circle (a
  one-wide corridor), it backs off along its path to 3 blocks for the circle's time instead.
- **Shields:** a bite blocked by a shield **staggers** it: 30 ticks instead of the recovery, with a
  sound subtitled "Nester staggers" (the ravager's stun when its bite is blocked is the precedent;
  the ravager is stunned half the time, the Nester always).
  Shield the lunge, then hit it.
- **Circle:** after each bite it circles its target at 4 blocks for 30 ticks (system §3), facing it.
  The circle is a **strafe** (it moves while facing its target, as vanilla's `strafe` does), tuned to
  about 2.5 blocks/s and checked in the speed GameTest. A target that walks at it closes in, since
  it backs off slower than a walk, so a player can close to sword reach (3 blocks) to bait the
  guard, and into melee reach for the standing bite.
- **Dodge** (canon), **never a coin flip:** as a circle starts, its crest fans upright and rattles
  (its **guard**, subtitled "Nester guards"). While the guard is up, the **first** melee hit from its
  target is dodged (on Hard, the first two): any damage whose type is in `#minecraft:is_player_attack`
  (a swing, a spear's jab or charge, a mace smash) or `minecraft:mob_attack` (an illager's axe). The
  hit does nothing, and it hops 2 blocks sideways onto standable ground (never into lumen's radius,
  water, ichor, or off a drop of more than 2; with no such side, it ducks in place and the hit still
  misses), with a sound subtitled "Nester dodges". Then its crest drops: the guard is down until the
  next circle. The guard lasts the circle and ends with it, used or not; the **rattle** marks it,
  not the raised crest alone (the crest is also up while it gallops, system §3, when it never
  dodges). It never dodges projectiles, in recovery, in a stagger, or while galloping or
  searching. The read: **bait the dodge with a swing, then strike**; or hit it in recovery; or shoot
  it while it circles. As the enderman always evades projectiles, the rule is always the same.
- **The gallop is loud:** gallop steps play at volume 1.5 (heard about 24 blocks out), subtitled
  "Nester gallops". Ordinary steps play at volume 0.15, as vanilla mobs' steps do, subtitled
  "Nester steps" (as "Warden steps" and "Ravager steps" are), so a deaf player can notice a roaming
  Nester before it hears them.
- **Out of reach:** a target it can't path to (on a pillar, across a wide ichor lake beyond its path
  range) is dropped after 200 ticks without a path (the gallop's limit), and it roams.
- **Several players:** its own rule, not vanilla's: it switches to whoever **last** hurt it (the hunt
  goal watches `getLastHurtByMobTimestamp`; vanilla's `HurtByTargetGoal` would keep its first
  attacker while that goal runs), and the duel starts over (a new approach, a new guard). Intended:
  a second player can pull it off a friend. A GameTest checks it in WP-067.

### AI
- **Goals hosting one explicit state machine**, not a Brain. VANILLA_ANALOGS E3's rule points to a
  Brain for phased behaviour players read, and the warden (the hearing analog) has one. But the
  Nester's phases are one strict sequence with one owner: the listener's states (system §3) and the
  duel are a single `NesterHuntGoal` with an enum state (synced, below), as the evoker's spell goals
  run a windup and a cast as goal-driven phases, and as the Blub's states are (D-021). A Brain would
  add memories and sensors for data the goal already holds. Priorities: 0 float; 1 emerge (holds
  everything else); 1 retreat (falling Flow; it waits while the Nester fights a target within 16, as
  system §4 says, and the Thrive sweep caps it); 2 lumen: rim, walk-out and the rim flee
  (system §6.5); 2 lulled; 3 the hunt goal (tell, gallop, search, lunge, circle); 5 roam; 6 look
  around. Targeting: hurt-by (retaliation), the search's find, and a **player** within 2 blocks (the
  bump, system §3); never by sight alone. So a roaming Nester walks past a curled blub.
- **Navigation:** ground navigation, step height 1.0 (long legs walk up a block without jumping, as a
  horse). It avoids water and ichor, the Sift's water (path malus 8, vanilla's default for water;
  D-024).

### Reactions
| To | Reaction |
|---|---|
| Players | Hunted when heard and found, when they hurt it, or within 2 blocks. Never by sight alone |
| Sound and vibrations | The hearing rule (system §3) |
| Souls (M3) | None of its own. Killed near a bloom heart, its death feeds the heart as any non-player death does (world.md, bloom heart) |
| Tides | Lives through Endure: emerges with it, burrows at falling Flow, always, in caves too (system §4, D-023); its return-by tick is saved at spawn |
| Light | Lumen repels it (system §6); torches don't, but block light stops spawning |
| Other Sift mobs | Ignores other hunters (and their sounds). **Blubs** are targets when found |
| Illagers (M4) | Targets when found or when they hurt it |
| Ichor | The Sift's water (D-024): it swims across when it must, and paths around it |

## Stats (vanilla analogs side by side)
| Stat | Nester | Analogs |
|---|---|---|
| Health | 20 | zombie 20, spider 16, wolf (wild) 8 |
| Armor | 2 | zombie 2 |
| Bite damage (Easy / Normal / Hard) | 3.5 / 5 / 7.5 against players; a flat 5 against blubs and illagers (vanilla scales only damage to players) | wolf 3 / 4 / 6 |
| Movement speed | 0.3; gallop and hunt ×1.12 (about **5.0 blocks/s**), roam ×0.6 (about 1.4) | player: walk 4.3, sprint 5.6; wolf 4.0; spider 4.0; zombie 2.3 |
| Follow range | 24 (the hunt's drop distance) | zombie 35, spider 16 |
| Knockback resistance | 0 | most mobs 0 |
| Step height | 1.0 | horse 1.0 |
| XP | 5 | most hostiles 5 |
| **Enduring** (system §5) | health 30, bite 4.1 / 6.25 / 9.4 (flat 6.25 against non-players), KB resistance 0.2, XP 10 | — |

Mob speed in vanilla is quadratic: a mob's `zza` is its speed and `moveRelative` multiplies by it
again, so on the ground it settles at about speed² / 0.454 blocks a tick. At ×1.12 (0.336) that is
about 5.0 blocks/s: faster than a walking player, slower than a sprinting one, so **a player who
sprints at the tell gets away; one who walks doesn't**, and the system's "fights until the target is
16 blocks away" can be met (a GameTest checks the speeds in WP-067).

**Damage over time:** a lunge cycle (windup 8, leap ≤ 12, recovery 12, circle 30, closing in) lasts
about 70 ticks, so about 1.4 damage a second on Normal, against a zombie's 3 and a spider's 2 in
contact. That's intended: the Nester's threat is finding you in the dark, its speed and its company
(pairs, enduring ones, Bloombud patches), not raw damage. Time to kill on Normal: an unarmoured
player about 14 s (4 bites); in iron armour about 28 s (8 bites, as armour halves 5); with a shield
used well, much longer. **In diamond** (most players arrive through an Ancient City geared) a bite
does about 1.25 (an enduring one about 1.6), and a well-fed player's fast regeneration (1 health
every 10 ticks with a full food bar and saturation) outpaces even a pair. But saturation buys only
about 13 health; after it, regeneration is 1 every 80 ticks, which one ordinary Nester outpaces. So
the danger to a geared player is **hunger** in a long Endure, and what the noise brings: as a
zombie is to a player in diamond, a lone Nester is a nuisance until the food runs low. That is the
intent, as vanilla's own night is for players in diamond.

## Player interaction
- **Telegraphs:** "Nester surfaces" and "Nester steps" before it hears you; the vibration particle,
  then the tell (crest, sound, subtitle); the gallop's thud; the lunge's crouch and hiss; the
  guard's raised, rattling crest; the circle.
- **Counterplay:**
  - *avoid:* sneak, wool, lures, lumen (system); stay under a one-block-high gap;
  - *fight:* sidestep the lunge from range, or shield it early up close, and hit the stagger; hit in
    recovery; shoot it while it circles; while its crest is up, bait the dodge with one swing, then
    strike.
- **Companion rules:** none. It can't be leashed: vanilla's default `Mob.canBeLeashed` refuses every
  `Enemy` (the hoglin and zoglin override it; the Nester doesn't).
- **Why the encounter is interesting:** the hearing rule gives the before (should I move?), the duel
  the during (wait for the crouch), and the tide the after (hold out until dawn, and it leaves).

## Loot and purpose
- **Drops:** none but **XP 5** (enduring: 10), like the vex and silverfish: it is the price of being
  out in Endure, not a resource. Endure's rewards are its blooms (Endure petals, lumen). No drop means
  no reason to farm Nesters, and no dead-end item.

## Spawning
- **Where:** Singer's Meadow and Hymnstone Rise; spawn category monster.
- **When:** Endure only.
- **Rules:** dark, by the Sift's dimension rules (block light 0, then vanilla's 0–7 light roll, which
  Endure's sky light of 4 often passes and Thrive's 15 never does), on **soil**
  (`#thesift:hunter_burrowable`: healthy sculk or Sift Soil, never hymnstone or tide sand), no lumen
  within 8, outside the gate sanctuary (system §7).
- **Groups:** 1–2. **Weight:** set with the spawn tables in WP-070 (proposal: Nester 60 against
  Bloombud 100, so Bloombuds are commoner and Nesters are the event).
- **Enduring:** 25 % (Hard 35 %) at a natural spawn.
- **Despawn:** vanilla's monster rules, then the retreat (system §4).

## Audio
All original, synthesized in `tools/audio/synth.py`. Subtitles in brackets.
| Event | Description | Subtitle | Variants |
|---|---|---|---|
| `entity.nester.ambient` | Dry clicks and a low chirr | "Nester clicks" | 4 |
| `entity.nester.ambient_enduring` | The chirr, deeper, with a rasp | "Enduring Nester growls" | 3 |
| `entity.nester.hear` | A fan snapping open and a rising whistle | "Nester hears something" | 3 |
| `entity.nester.gallop` | Heavy, quick double thuds (loud) | "Nester gallops" | 4 |
| `entity.nester.sniff` | Short sniffs | "Nester sniffs" | 3 |
| `entity.nester.hiss` | A hiss with a click (lunge windup) | "Nester hisses" | 3 |
| `entity.nester.bite` | A wet snap | "Nester bites" | 3 |
| `entity.nester.guard` | A dry rattle of fins | "Nester guards" | 2 |
| `entity.nester.dodge` | A quick whoosh | "Nester dodges" | 2 |
| `entity.nester.stagger` | A dazed, rattling grunt | "Nester staggers" | 2 |
| `entity.nester.emerge` | Soil crumbling, a shake | "Nester surfaces" | 2 |
| `entity.nester.burrow` | Pawing, soil closing over | "Nester burrows" | 2 |
| `entity.nester.hurt` | A sharp squawk | "Nester hurts" | 3 |
| `entity.nester.death` | A falling whistle and a collapse | "Nester dies" | 2 |
| `entity.nester.step` | Light quick steps (volume 0.15) | "Nester steps" | 4 |
| `entity.nester.lulled` (M4) | A soft trill as the crest folds | "Nester lulled" | 2 |

## Edge cases
| Case | Handling |
|---|---|
| Water | Floats and swims slowly; avoids water when pathing (malus 8) |
| Lava | Vanilla (burns; avoids it) |
| Ichor | As water: floats and swims slowly; avoids it when pathing |
| Leashed | Can't be (vanilla's default for an `Enemy`, not overridden) |
| Name-tagged | Persistent: never retreats; listens and hunts in Endure; outside Endure it roams, bumps and fights back (system §13) |
| Boats and minecarts | Vanilla lets mobs ride them; a riding Nester is persistent (vanilla's `requiresCustomPersistence`), can't gallop, lunge or circle, still hears, and gives a standing bite to a target in melee reach every 30 ticks |
| Portals | Can't cross the membrane (`#thesift:cannot_cross`, D-023). Fire lights no other portal in the Sift (vanilla lights them only in the Overworld and the Nether) |
| Peaceful | Doesn't exist (`notInPeaceful()`) |
| `mobGriefing` false | No effect: it changes no blocks |
| `/summon` and spawn eggs | No emerge animation. Its return-by is the next Thrive after it appears (system §4): one summoned in Thrive roams without hearing (nobody listens outside Endure), hears through the coming Endure, and digs away at falling Flow. A name tag or `PersistenceRequired` keeps one |
| Outside the Sift (spawn eggs only) | No Tide: it never hears, never retreats, never becomes enduring; it roams, bumps and fights back, and despawns by vanilla's rules (system §13) |
| Enduring and name-tagged | Persistent, so it doesn't retreat: at Thrive it loses enduring (system §5) |
| Spectators and creative | Not heard, never targeted (system §3) |
| Two-block ceilings, one-wide corridors | Fits; a one-block-high gap stops it |
| A target that dodges every lunge | The circle and the next lunge repeat; it drops the target at 24 blocks or 100 ticks unseen |

## Tech notes
- **Synced data:** `STATE` (a byte: roam, tell, gallop, search, windup, leap, bite, recovery, stagger,
  circle, guard, dodge, emerge, dig, lulled) drives the model's clips; `ENDURING` (bool). This refines system §11,
  which named entity events for the crest flare, the lull and the dig: a synced state lets a client
  that starts tracking a Nester mid-dig or mid-lull still show it. Saved: `Surface`, `Enduring`,
  `ReturnBy`, the lull, the listener data (system §11).
- **Dodge:** in `hurtServer`, before damage: if the guard is up, the source's entity is its target,
  the damage type is in `#minecraft:is_player_attack` or is `minecraft:mob_attack`, and dodges remain
  this circle (1; Hard 2), cancel and hop.
- **Stagger:** vanilla's `LivingEntity.applyItemBlocking` calls `blockedByItem` on the attacker when a
  shield blocks it; the Nester overrides it to start the stagger, as the ravager's override starts
  its 40-tick stun.
- **Pathfinding cost:** the gallop paths to one spot per sound (not to a moving entity); the hunt
  repaths as vanilla's `MeleeAttackGoal` does: every 4–10 ticks while it can see the target, +5
  beyond 16 blocks, +10 beyond 32, +15 after a failed path.
- **Cost budget:** two measurements by the `SiftPerfTest` method, both ≤ 1.5×: the mob's own (WP-067:
  30 Nesters roaming plus 10 hunting against the same numbers of wolves) and the system's (§12, in
  WP-066: 30 Nesters hunting in Endure against 30 zombies).
- **Expected counts:** shared monster cap of 70; with Bloombuds commoner, about 10–20 Nesters around a
  player in Endure.
- **Risks:** the lunge's contact bite (test on slopes and half-blocks, and the 4-block reach); the
  guard being missed (the raised crest, its rattle and subtitle, and the same rule every time).

## Critique log
- **Round 1 (2026-10-02): FAIL**, 5 must-fix; scores faithful 4, vanilla-native 3, readable 3,
  meaningful 4, distinct 4, connected 3, feasible 4, template 4, frozen-doc consistency 4. Each
  vanilla claim was checked in the 26.3 sources before acting (`Mob.setSpeed` sets `zza`, so speed is
  quadratic; `LeapAtTargetGoal` 2–4 blocks; `Player.hurtServer`'s Easy scaling; `Mob.canBeLeashed`
  and the hoglin; `MeleeAttackGoal`'s repath). Fixed:
  - M1, the gallop outran a sprinting player (0.39 is about 6.7 blocks/s): ×1.12, about 5.0, between
    walking and sprinting, with the blocks/s figures and a GameTest.
  - M2, the lunge contradicted itself and couldn't land from 6: aim locked at the windup's start
    (the sidestep window), range 2–4, the bite live until landing, "contact" defined.
  - M3, the dodge was a coin flip: a guard (a crest signal, a sound) that always dodges the first swing
    of a circle (Hard: two).
  - M4, enduring Easy damage: recomputed from vanilla's formula; non-players take flat damage.
  - M5, two vanilla claims: leashing (the default, which the hoglin overrides) and the repath rate.
  - Should-fix, all taken: the bump is players only; name-tagged Nesters bump; close quarters and
    riding; the synced state refines §11; home cites world.md §1.1, Meadow only until M3, no
    structures; the look's inventions flagged; the AI choice argued against E3, with emerge, lull
    and the rim flee in the priorities; souls feed a bloom heart; damage per second and time to
    kill; the cost budget; eyes. BALANCE rows go in on freeze, as for the Blub. Bite raised to 5
    (Easy 3.5, Hard 7.5), so a found player is in real danger; the circle stays the frozen
    system's 30 ticks.
- **Round 2 (2026-10-02): FAIL**, 4 must-fix; scores faithful 4, vanilla-native 4, readable 3,
  meaningful 4, distinct 4, connected 3, feasible 4, template 4, frozen-doc consistency 4. Round 1's
  fixes were all confirmed in the sources (speed 4.97 blocks/s; the leap reaches 4 blocks with about
  0.1 to spare). Checked before acting: the ravager's roar and stun are counters in `aiStep`, its
  stun comes from `blockedByItem`; `#minecraft:is_player_attack` holds `player_attack`, `spear` and
  `mace_smash`; vanilla subtitles "Warden steps", "Ravager steps" and others. Fixed:
  - M1, the ravager isn't a goal-phase precedent: dropped there, cited for the stagger's hook.
  - M2, steps are subtitled in vanilla: "Nester steps".
  - M3, the standing bite fired outside its reach: it now fires at melee reach, steps in during
    the windup, and a miss still goes to recovery and the circle; the lunge starts beyond reach.
  - M4, spears and the circle: the dodge is defined by damage type (player attacks, spears, mace
    smashes, mob attacks), and the circle backs off slower than a walk, so a sword can bait it.
  - Should-fix, all taken: a raised crest always means ready (the guard fans it; recovery droops it);
    guard and stagger sounds; up close, shield early; leap timing, the standing-bite clip, and a leap
    scaled to its distance; retreat waits for a fight within 16; both cost budgets; the emerge heard
    at 32 blocks; time to kill in diamond, and the intent; several players; out-of-reach targets;
    the dodge hop's footing.
- **Round 3 (2026-10-02, the last): FAIL, narrowly**, 1 must-fix, small enough to fix in place;
  scores faithful 5, vanilla-native 4, readable 4, meaningful 4, distinct 4, connected 4, feasible 4,
  template 5, frozen-doc consistency 5. Every other vanilla claim confirmed; no contradiction with
  the frozen system. Fixed:
  - M1, vanilla's `HurtByTargetGoal` keeps its first attacker while running: switching to the last
    attacker is the Nester's own rule (`getLastHurtByMobTimestamp`), with a GameTest.
  - Should-fix, all taken: the circle is a strafe tuned to about 2.5 blocks/s; melee reach along a
    world axis; diamond's real danger is hunger once saturation runs out; "across ichor" narrowed
    (ichor is water, with a path cost); the guard lasts the circle and the rattle marks it; the
    ravager stuns half the time; regeneration needs a full food bar.
- **Frozen 2026-10-02** after round 3 (the cap of three rounds). Numbers in BALANCE.md.
