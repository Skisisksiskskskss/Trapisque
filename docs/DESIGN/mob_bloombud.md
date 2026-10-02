# Bloombud (WP-062) — DRAFT

The M2 ambusher. Fixed by the frozen bible (creatures.md row "Bloombud"; world.md §1 and the §1.1
spawn table rows Singer's Meadow and Sift Hollows) and the hunt system (`system_hunt.md`, frozen, which this doc builds on and
doesn't repeat): a **melee sifter that mimics a closed flower bud in the dark**, in **groups of 3–5**;
its **petals open (the telegraph) before it lunges**; it **spawns in darkness** (Endure on the
surface, the Hollows any time) and **burrows at falling Flow on the surface**. Canon adds that
Bloombuds "bear many visual and behavioral similarities to vindicators", are slow in melee, wander
idly, and "spawn in large groups throughout the Singer's Meadow" (RESEARCH_BESTIARY "Bloombud",
[W:Bloombud]; its earlier name was "Snout Sifter").

It is a hunter (`#thesift:hunters`) but **not a listener**: it doesn't hear (system §3). Retreat,
lumen, the lull, enduring variants and the membrane rule apply to it as to every hunter.

This doc decides what the bible and the system leave open: how the ambush works and is read, what
fighting a patch is like, how it looks and sounds, and its numbers.

## Concept ladder: what makes a patch of buds a decision?
The Nester makes *noise* the danger. The Bloombud should make *where you walk* the danger, without
being a trap you can't see.

### Diverge (written before scoring)
1. **Still bud ambush** (the bible): it waits closed and rooted on soil, a bud among the grass. A
   target close enough wakes it: the petals open (the telegraph), then it strikes.
2. **Creeping buds** (the bible's "creeping ambush"): while no one looks at it, a closed bud shuffles
   a little closer to a target; watched, it is still.
3. **The patch wakes in a ripple**: one bud opening wakes the others nearby, one after another, so a
   group of 3–5 comes at you as the vindicator's band does.
4. **Vindicator charge**: once open, it runs at its target with an axe-like overhead snap.
5. **Pollen burst**: hit, it puffs pollen that slows you. (Area denial is the Pollinator's niche.)
6. **Light-shy**: it closes up in torchlight and stays shut.
7. **Rooted and soft**: a closed bud can't move; a hit on a closed bud is a sneak attack (double
   damage), so spotting buds pays.
8. **Thrive sleep**: cave buds stay closed in Thrive and can't be woken by sight, only by a hit.
9. **Perfect camouflage**: it looks exactly like Sift grass until it opens.
10. *(unusual)* **Seed scatter**: killed, it drops seeds that grow into new buds by the next Endure.

### Converge: rubric (1–5; the same seven criteria as mob_blub.md)
| # | Concept | Faithful | Vanilla-native | Readable | Meaningful | Distinct | Connected | Feasible | Total |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Still bud ambush | 5 | 4 | 4 | 5 | 4 | 4 | 5 | **31** |
| 2 | Creeping buds | 4 | 3 | 3 | 4 | 5 | 3 | 4 | **26** |
| 3 | Ripple wake | 5 | 5 | 5 | 4 | 3 | 3 | 5 | **30** |
| 4 | Vindicator charge | 4 | 5 | 4 | 3 | 1 | 2 | 5 | 24 |
| 5 | Pollen burst | 2 | 4 | 4 | 3 | 2 | 2 | 4 | 21 |
| 6 | Light-shy | 2 | 3 | 3 | 3 | 2 | 4 | 4 | 21 |
| 7 | Rooted and soft | 3 | 3 | 4 | 4 | 4 | 2 | 5 | 25 |
| 8 | Thrive sleep | 2 | 4 | 3 | 2 | 2 | 4 | 4 | 21 |
| 9 | Perfect camouflage | 3 | 2 | 1 | 2 | 3 | 2 | 5 | 18 |
| 10 | Seed scatter | 1 | 2 | 2 | 2 | 4 | 3 | 2 | 16 |

Notes on the calls:
- **1** is the bible's row; **3** is canon's "large groups" and its vindicator kinship made into
  something players see coming: the patch opens bud by bud, and each opening is a beat to back off.
- **2** is the bible's "creeping ambush". Kept, bounded: it only ever closes the distance to just
  outside the wake radius, so it builds dread without ever springing the trap by itself, and a
  rustle with a subtitle tells players it happened.
- **4** is the vindicator itself, not distinct; the Bloombud stays slow, as canon says. **9** is
  unreadable by design, and **10** farms itself. **5** is the Pollinator's job. **6** fights the
  hunt's single light rule (lumen repels; torches only stop spawns). **8** is covered by the light
  rule already: Thrive caves are dark, so cave buds behave the same in every Tide.
- **7**'s sneak-attack bonus is a hidden number; a plain "it can't move while closed" stays in 1.

### Decision: **"The patch that wakes"**: 1 + 3, with 2 bounded
- **The ambush (1):** closed and rooted, it wakes when a target comes within 5 blocks in sight.
- **The ripple (3):** each bud that opens wakes the closed buds within 8, one by one.
- **The creep (2):** unwatched, a closed bud may shift one block closer, never into the wake radius.
- **Why not more:** the Bloombud's whole job is "watch where you walk in the dark"; the fight itself
  stays a plain, slow melee crowd that a player can back away from.

## Identity
- **Canon** (RESEARCH_BESTIARY "Bloombud"): a hostile sifter of the Singer's Meadow with "many visual
  and behavioral similarities to vindicators", slow in melee, wandering idly, in "large groups"
  [W:Bloombud]; its working name was "Snout Sifter". **Changed in translation:** the bud mimicry and
  the petal telegraph are the bible's (canon shows no ambush); the snout stays as the thing inside
  the bud; it doesn't hear (the Nester owns hearing); it surfaces only in Endure (D-013).
- **One-sentence fantasy:** a cluster of closed buds in the dark grass that opens, bud by bud, into
  snouted things that come for you.
- **Role:** hostile.
- **Home:** Singer's Meadow on the surface (Endure only) and the Sift Hollows (any Tide, in the dark),
  as world.md §1.1's spawn table has it (Hymnstone Rise is the Nester's alone). Always on bare soil.

## Silhouette and look
- **Hitbox:** closed 0.7 × 0.9 (a bud on a short stalk, knee-high to a player); open 0.7 × 1.6 (a
  hunched biped, shorter than a vindicator's 1.95). It changes with the synced state, which calls
  `refreshDimensions()` when it changes (as the slime's size does; vanilla refreshes by itself only
  on a pose change). A bud roots only where two blocks of air stand above it, so it can always open;
  a bud that a player builds over can't bloom and stays a harmless bud until it has room.
- **Readable at 10 blocks:** **the Sift has no buds**: no plant in the Meadow is a round closed bud on
  a stalk, so any bud is a Bloombud. That is a constraint on WP-064's flora (tidewrack, the Endure
  bloom and the glowcap must never look like a closed bud on a stalk) and on spawning: a bud spawns
  and roots only on **bare** soil, with air at its feet, never inside a grass tuft. The petal tips
  glow steadily (emissive, never pulsing: pulsing is blight's grammar, world.md §3.1), a ring of five
  warm points low to the ground, seen in the dark in every Tide; open, the long snout and the five
  petals splayed back like a collar.
- **Palette** (new ramps, added to palette.md in WP-068; dark → light):
  - `bloombud`: `#24192f` `#33243f` `#463152` `#5b4068` `#73527f` `#8e6a96`: a dusky plum bud, dark
    against the coral-pink grass, nothing like the Nester's moss or the Blub's blue.
  - `bloombud_inner`: `#7c5a7a` `#a8819d` `#cfaac2` `#ecd6e4` `#fff1f7`: the pale inside of the petals,
    shown only when it opens (the colour change is part of the telegraph, never all of it).
  - Petal tips: the existing warm `particle` ramp, emissive and steady. An **enduring** bud adds the
    cyan `glyph` glow along its spiked second ring, with soul wisps (system §5), so it differs from
    every bud by shape, particles and colour together.
- **Texture:** 64 × 64.
- **Model parts:** body (a short torso); head (the snout, a long blunt muzzle with a hinged jaw);
  five petals around the head, one hinge each (closed: folded up over the head into a bud; open:
  peeled back into a collar); two long arms (folded around the body when closed); two short legs; a
  stalk (the legs and lower body tucked together when closed). **Enduring only:** a second ring of
  longer, spiked petals (a separate part, hidden on ordinary Bloombuds).
- **Animations** (procedural clips in the model, as the Blub's and the Nester's, D-021). Durations in
  ticks:
  - closed idle: the bud sways a little, as grass does (the tips' glow stays steady);
  - **creep** (10): the stalk leans and the bud slides one block, with a rustle;
  - **bloom** (15): petals peel back one after another, the snout pushes out, it rises to full height;
  - walk: a slow, rolling hunched gait, arms low (the vindicator's stance);
  - **strike**: windup 6 (snout drawn back, arms up), active 2, recovery 12: a short snapping lunge;
  - **close** (20): it crouches, folds its arms and petals, and becomes a bud again;
  - **emerge** (30): a bud pushes up out of the soil; **dig** (60): the bud sinks into it;
  - **lulled** (M4): the petals close halfway and sway to the song;
  - hurt: a flinch, petals flick; death: it wilts and falls over (vanilla's tip-over).

## Behavior
### State machine
```
emerge (30) ──► closed ──a target within 5 in sight, or hurt (starts a ripple); or rippled; or lumen within 6──► bloom (15) ──► open
                  ▲  │ unwatched, a target within 12: creep (1 block, at most every 40 ticks and 3 a minute; never within 6 of any target)
                  │  ▼                                                                         ▼
                  └──── close (20) ◄── bare soil, dark, no target for 100 ticks, wandered 200 ticks ◄── fight / wander
falling Flow (surface or enduring) ──► retreat (system §4): closed buds dig in place (60) ──► gone
a Singer's horn within 12 (M4) ──► lulled (200; system §3): open ones fold halfway and wander; closed ones stay closed
```
- **Closed** (rooted): it doesn't move or turn and takes damage normally. It **can't be pushed**, as
  a creaking that is being watched: `isPushable()` is false and `push` does nothing while closed, so
  mobs, players and boats can't shove or pick it up (a boat only picks up pushable mobs), and its
  movement is zeroed each tick, so an explosion's knockback doesn't move it either. It looks for a
  target every 10 ticks: a survival or adventure player or an illager within **5 blocks**, in line of
  sight, through vanilla's targeting conditions, so **sneaking and invisibility shrink the radius** as
  for every mob (`LivingEntity.getVisibilityPercent`: crouching ×0.8, 4 blocks). A closed bud with
  lumen within 6 (a lantern placed nearby) blooms and walks out to the rim (system §6.3), without a
  ripple: a lantern flushes out a patch, which is its own tell. Water reaching a closed bud, or its
  soil being broken, makes it bloom too, and it wanders.
- **Bloom** (the telegraph, 15 ticks): the petals open one after another with a sound subtitled
  "Bloombud blooms" and a puff of petal particles. It can't strike while blooming. A target that walks
  away during the bloom is still its target; one that is gone (out of 16, unseen) when it ends leaves
  it open and wandering.
- **The ripple:** a bud woken **by a target** (seen, or hurt by one) wakes the closed Bloombuds within
  **8** of it that can see it, one at a time, **10 ticks apart**, nearest first. **Rippled buds don't
  ripple further**: one wave per waking, so neighbouring patches never wake each other across the
  Meadow (the system rejects chains, §3 option 8). A patch of five opens over about 3.5 seconds (the
  first bloom of 15 ticks, four more 10 ticks apart, the last bloom of 15): the first bud is the
  warning, the rest are the reason to leave. Each rippled bud takes the nearest target it can see
  within 16, or wanders.
- **Open:** a slow melee mob. An open bud without a target looks for one every 10 ticks: a survival
  or adventure player or an illager within **8 blocks** in sight (×0.8 sneaking, the same vanilla
  conditions); an open bud stands tall and is easy to see, so it may notice a little farther than a
  closed one. It walks at its target and strikes: windup 6 ticks (snout back, arms up), then the bite
  lands on the active tick only if the target is within its melee reach then (vanilla's
  `isWithinMeleeAttackRange`, its hitbox widened by the default attack reach), so **stepping back
  during the windup avoids it**; recovery 12; a strike every 20 ticks at most (vanilla melee's
  interval). It drops a target that dies, leaves, is more than 16 blocks away, or has been out of
  sight for 100 ticks, then **wanders idly** (canon).
- **Close again:** an open Bloombud with no target for 100 ticks walks to bare soil within 8, where
  **block light is 0** (the spawn rule's light: buds never root in a glowcap pool or a torch-lit base)
  and outside every lumen radius, and, after wandering for at least 200 ticks, closes (20 ticks)
  there: a new bud in a new place. A target that comes within 5 during the close interrupts it: it
  blooms again (and ripples, as woken by a target). A Bloombud with no such soil in reach keeps
  wandering and looks again every 100 ticks.
- **The creep** (closed only), after the **creaking**, vanilla's mob that moves only when no one is
  looking: if a target is within 12 (the creaking's activation range) but no target is within 6, no
  player within 12 is looking at it (the creaking's own test, `isLookingAtMe` with 0.5: within 60°
  either side of the look direction, at three heights of the bud, with line of sight), and it hasn't
  moved in 40 ticks, it slides one block toward the target, onto bare soil where block light is 0,
  outside every lumen radius (system §6.1), with a rustle subtitled "Bloombud rustles". It never
  creeps to within 6 of **any** target (one block outside the wake radius): **the creep never springs
  the trap; walking into the patch does.** At most 3 creeps per minute per bud.
- **Retreat** (system §4): a surface or enduring Bloombud retreats at its moment in falling Flow. A
  closed one digs where it stands (it is already on soil); an open one walks to soil first. Cave
  Bloombuds that aren't enduring stay.

### AI
- **Goal selector**, as the vindicator, the zombie and the Nester: few, linear states. Priorities: 0
  float; 1 emerge (holds everything; a bud can't wake while emerging, and is closed when it ends); 1
  retreat (falling Flow); 2 lumen: rim, walk-out (closed buds bloom first) and the rim flee (system
  §6.5); 2 lulled; 3 melee strike; 4 bloom and ripple; 5 close and root; 6 creep (closed only); 7
  wander (open only); 8 look around (open only). Target selectors: hurt-by (retaliation, which wakes
  a closed bud), and the closed and open sight checks above.
- **Navigation:** ground navigation, step height 0.6 (vanilla's). It avoids water and ichor, the
  Sift's water (path malus 8; D-024). Closed, it has no navigation at all (the goal stops it).

### Reactions
| To | Reaction |
|---|---|
| Players | Woken by one within 5 in sight (4 sneaking), or by being hurt; then fought |
| Sound and vibrations | None: it doesn't listen (system §3). A loud player wakes Nesters, not buds |
| Souls (M3) | None of its own. Killed near a bloom heart, its death feeds the heart as any non-player death does (world.md, bloom heart) |
| Tides | Surface: spawns in Endure, burrows at falling Flow. Hollows: the same in every Tide, and stays (system §4); enduring ones leave |
| Light | Lumen repels it (system §6): it never roots within 6, a closed bud near new lumen blooms and walks out, and open ones keep out. Torches and glowcaps stop spawns, and buds never root or creep where block light is above 0, but an open bud walks through light |
| Other Sift mobs | Ignores other hunters. Ignores blubs: their hops past a bud are safe |
| Illagers (M4) | Targets, as players |
| Ichor | The Sift's water (D-024): it swims across when it must and paths around it; it never roots in it |

## Stats (vanilla analogs side by side)
| Stat | Bloombud | Analogs |
|---|---|---|
| Health | 14 | vindicator 24, zombie 20, husk 20 |
| Armor | 2 | zombie 2, vindicator 0 |
| Strike damage (Easy / Normal / Hard) | 3 / 4 / 6 against players; a flat 4 against illagers (vanilla scales only damage to players) | zombie 2.5 / 3 / 4.5, vindicator (iron axe) 7.5 / 13 / 19.5 |
| Movement speed | 0.23 (open); 0 (closed) | zombie 0.23, vindicator 0.35 |
| Follow range | 16 | zombie 35, vindicator 12 |
| Knockback resistance | 0 (closed: can't be pushed or moved at all) | creaking (unpushable while watched) |
| Wake radius | closed 5, open 8 (×0.8 sneaking, vanilla) | — |
| XP | 5 | most hostiles 5 |
| **Enduring** (system §5) | health 21, strike 3.5 / 5 / 7.5 against players (flat 5 against illagers), KB resistance 0.2 open, XP 10 | — |

A group of 3–5 is the threat, not one bud: a lone Bloombud is weaker than a zombie, and as slow, so a
player who backs away at the first bloom always gets out.

## Player interaction
- **Telegraphs:** the shape (the Sift has no buds), the glowing petal tips in the dark, the rustle of
  a creep; the bloom (petals, sound, subtitle, particles); the ripple's rhythm; each strike's windup.
- **Counterplay:**
  - *avoid:* look for bud clusters and go around; sneak past at 4 blocks instead of 5; carry lumen
    (no bud roots within 6); come back in Thrive, when surface buds are gone;
  - *fight:* wake the patch from range with an arrow and fight them as they come one by one; back up
    while they bloom; hit in the recovery after a strike.
- **Companion rules:** none. It can't be leashed: vanilla's default `Mob.canBeLeashed` refuses every
  `Enemy` (the hoglin and zoglin override it; the Bloombud doesn't).
- **Why the encounter is interesting:** it turns the Meadow at night into ground you read. The
  Nester punishes noise; the Bloombud punishes not looking. Together: walk slowly and you won't be
  heard, but you'd better watch the grass.

## Loot and purpose
- **Drops:** none but **XP 5** (enduring: 10), as the Nester: Endure's rewards are its blooms (Endure
  petals, lumen), and a patch is a hazard, not a resource. No drop means no reason to farm the
  Hollows' buds, which spawn in every Tide.

## Spawning
- **Where:** Singer's Meadow (surface) and the Sift Hollows (world.md §1.1); spawn category monster.
  No structure spawns.
- **When:** surface: Endure only (system §7); Hollows: any Tide, in the dark.
- **Rules,** in the system's order (§7; vanilla checks the monster cap first): the Tide (surface:
  Endure only); dark, by the Sift's dimension rules (as the Nester's); on **bare soil** (healthy
  sculk or Sift Soil with air at its feet, never hymnstone or tide sand); outside the gate sanctuary;
  no lumen within 8.
- **Groups:** 3–5 (the bible). **Weight:** set with the spawn tables in WP-070 (proposal: Bloombud 100
  against Nester 60, so buds are the commoner danger). A group spawns closed (it emerges as buds).
- **Enduring:** 25 % (Hard 35 %) per Bloombud at a natural spawn **in Endure** (system §5); cave buds
  spawned in Thrive or Flow never are.
- **BALANCE.md** rows go in on freeze, as for the Blub.
- **Despawn:** vanilla's monster rules (a closed bud far from players despawns like any monster),
  then the retreat (system §4).

## Audio
All original, synthesized in `tools/audio/synth.py`. Subtitles in brackets.
| Event | Description | Subtitle | Variants |
|---|---|---|---|
| `entity.bloombud.ambient` | Closed: a faint creak, like a stem bending (quiet, rare) | "Bloombud creaks" | 3 |
| `entity.bloombud.ambient_open` | Open: a wet snuffle through the snout | "Bloombud snuffles" | 3 |
| `entity.bloombud.ambient_enduring` | The snuffle, lower, with a rattle of petals | "Enduring Bloombud rattles" | 3 |
| `entity.bloombud.rustle` | Leaves dragged over soil (the creep) | "Bloombud rustles" | 3 |
| `entity.bloombud.bloom` | Petals peeling apart, a soft pop | "Bloombud blooms" | 3 |
| `entity.bloombud.strike` | A short snort and a snap | "Bloombud snaps" | 3 |
| `entity.bloombud.close` | Petals folding shut, a sigh | "Bloombud closes" | 2 |
| `entity.bloombud.emerge` | Soil parting | "Bloombud surfaces" | 2 |
| `entity.bloombud.burrow` | The bud sinking, soil closing | "Bloombud burrows" | 2 |
| `entity.bloombud.hurt` | A squeak and a petal flick | "Bloombud hurts" | 3 |
| `entity.bloombud.death` | A wilting hiss | "Bloombud dies" | 2 |
| `entity.bloombud.step` | Soft padding | (none, as vanilla steps) | 3 |
| `entity.bloombud.lulled` (M4) | A hum as the petals half-close | "Bloombud lulled" | 2 |

## Edge cases
| Case | Handling |
|---|---|
| Water | Floats and swims slowly; avoids water when pathing; never closes in water. Water flowing onto a closed bud makes it bloom |
| Lava | Vanilla (burns; avoids it) |
| Ichor | As water |
| Leashed | Can't be (vanilla's default for an `Enemy`, not overridden) |
| Name-tagged | Persistent: never retreats (system §4); closes and opens as usual |
| Boats and minecarts | A riding Bloombud is persistent (`requiresCustomPersistence`), can't close or creep while riding, and strikes from its seat as any melee mob |
| Portals | Can't cross the membrane (`#thesift:cannot_cross`, D-023) |
| Peaceful | Doesn't exist (`notInPeaceful()`) |
| `mobGriefing` false | No effect: it changes no blocks |
| `/summon` and spawn eggs | Appears open and wandering, no emerge; return-by as any hunter (system §4); outside the Sift it never retreats and despawns by vanilla's rules |
| Spectators and creative | Never wake it, never targeted (vanilla's targeting conditions) |
| A bud placed on a ledge | It roots only on bare soil with two blocks of air above; the creep only moves onto such soil at the same height or one block up or down |
| The soil under a closed bud is broken | It blooms and wanders, then roots elsewhere |
| A target appears mid-close | The close is interrupted: it blooms again and ripples |
| A block placed over a closed bud | It can't bloom while there is no room; a harmless bud until there is |
| A patch around a gate | The sanctuary stops spawns there (system §7); a bud can still root inside it after wandering in, as any hunter may walk in |
| A player standing still at 6 blocks | Nothing happens: the creep stops at 6, and the wake radius is 5 |

## Tech notes
- **Synced data:** `STATE` (a byte: closed, creeping, blooming, open, striking, closing, emerge, dig,
  lulled) drives the model's clips and, through `refreshDimensions()` on change, the hitbox;
  `ENDURING` (bool). Saved: `State` (closed or open), `Surface`, `Enduring`, `ReturnBy`, the lull
  (system §11).
- **Closed cost:** a closed bud runs one goal, a target check every 10 ticks over a 5-block box, and
  the creep check every 40 ticks (only when a target is within 12); no pathfinding.
- **Pathfinding cost:** open buds repath as vanilla's `MeleeAttackGoal` does (every 4–10 ticks while
  they see the target); wandering uses vanilla's random stroll.
- **The creep's "unwatched" test:** the creaking's `isLookingAtMe` for each player within 12 (a dot
  product and line-of-sight rays at three heights); no client data.
- **Cost budget (WP-068):** 30 closed buds plus 10 open and fighting cost ≤ 1.5× 40 zombies (idle and
  attacking in the same numbers), measured by the `SiftPerfTest` method.
- **Expected counts:** shared monster cap of 70; Bloombuds commoner than Nesters, in groups, so a few
  patches of 3–5 around a player in Endure, and a steady few in the Hollows.
- **Risks:** players not noticing buds (the glowing tips and the "Sift has no buds" rule, checked in
  previews and the playtest); the creep reading as unfair (bounded at 6, subtitled, at most 3 a
  minute); a patch in a one-wide tunnel blocking it (they are slow and weak alone; arrows work).

## Critique log
- **Round 1 (2026-10-02): FAIL**, 8 must-fix; scores faithful 4, vanilla-native 3, readable 4,
  meaningful 4, distinct 3, connected 3, feasible 4, template 4, frozen-doc consistency 2. Each
  vanilla claim checked in the 26.3 sources before acting (`LivingEntity.knockback` is the only user
  of knockback resistance; the shulker overrides `push`; the creaking's `isPushable`, `push`, its
  144 activation range and `isLookingAtMe(player, 0.5, …)`). Fixed:
  - M1, Hymnstone Rise isn't Bloombud country (world.md §1.1): dropped; citations corrected.
  - M2, knockback resistance doesn't stop pushing: closed buds are unpushable as a watched creaking.
  - M3, leashing: vanilla's default, which the hoglin overrides.
  - M4, enduring Easy damage: 3.5, from vanilla's formula; non-players take flat damage.
  - M5, the ripple chained across patches: only a bud woken by a target ripples; one wave.
  - M6, open buds had no targeting rule: an 8-block sight check every 10 ticks.
  - M7, a closed bud stayed inside new lumen: it blooms and walks out (a lantern flushes a patch).
  - M8, buds rooted in lit pockets: they root and creep only where block light is 0.
  - Should-fix, all taken: the creep follows the creaking (its range and look test, "within 60°
    either side"), with lumen-checked destinations and "any target"; the hitbox refreshes with the
    state, and buds root with two blocks of headroom; emerge, lull and the rim flee in the
    priorities; closed buds stay closed when lulled; the strike's reach in vanilla terms; "the Sift
    has no buds" bound on WP-064 and bare-soil spawning; a steady, warm glow (pulsing is blight's),
    in every Tide, with the enduring marker distinct; enduring rolls only in Endure; bloom hearts;
    no structure spawns, the system's check order, BALANCE on freeze; three edge cases; a cost
    budget; the ripple's 3.5 s.
