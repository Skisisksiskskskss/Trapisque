# Blub (WP-048)

The M1 mob, finished end to end. Fixed by the frozen bible (creatures.md row "Blub", D-016, D-017):
it is an ambient critter and a **pet**; it hops, squeaks, **bathes in ichor** (immune), **gathers to
music** and **stacks into teetering towers**. A player **befriends one by playing music by hand**:
each note befriends at most one blub, the nearest one watching, with hearts and a happy squeak. It
needs **no fuel**, follows its player, **crosses the membrane** with them and comes home. Thrive: roams
and stacks. Flow: **follows the basin waterline**. Endure: **shelters under songwood leaves, curled
up**. Tidewrack treats (breeding, healing) are M2.

This doc decides what the bible leaves open: how befriending feels, what a befriended blub is *for*,
how it looks and moves, and its numbers.

## Concept ladder: what does a befriended blub do for you?
A pet with no purpose is a dead end (mission §7: no dead-end content); a pet with a job is a worker
and would need fuel (D-016). The question is the smallest *reason to keep one* that stays a pet.

### Diverge (written before scoring)
1. **Pure pet.** Follows, sits on command, cosmetic. The cat without its creeper trick.
2. **Tide herald.** A befriended blub telegraphs the coming Tide: restless hops and a rising chirp
   ~30 s before Flow; it starts looking for cover ~30 s before Endure. The player learns the clock
   through a friend instead of a HUD.
3. **Echo singer.** It squeaks back the note you play, at your pitch (note-block pitch maps to its
   squeak); several blubs make a chord. A musical toy that teaches the Sift's verb.
4. **Waterline guide.** In Flow it leads you to the nearest basin edge (the bible's waterline
   behaviour, aimed at the player).
5. **Ichor escort.** While it bathes beside you, ichor within a block of it doesn't burn you.
6. **Stack platform.** Befriended blubs stack on command into a tower you can climb (bible: Could).
7. **Endure lantern.** It glows softly at night (emissive), a beacon in Endure's dark; no block light.
8. **Hunter alarm.** It squeaks and hides when a hostile comes within 12 blocks (the Sift's hunters
   arrive in M2).
9. *(unusual)* **Soul nose.** It sniffs toward the nearest experience source (bloom hearts, M3).

### Converge: rubric (1–5; the same seven criteria as entry_path.md)
| # | Concept | Faithful | Vanilla-native | Readable | Meaningful | Distinct | Connected | Feasible | Total |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Pure pet | 4 | 5 | 5 | 1 | 1 | 2 | 5 | 23 |
| 2 | Tide herald | 3 | 4 | 4 | 4 | 4 | 5 | 4 | **28** |
| 3 | Echo singer | 3 | 4 | 5 | 3 | 5 | 5 | 4 | **29** |
| 4 | Waterline guide | 3 | 3 | 3 | 3 | 3 | 4 | 3 | 22 |
| 5 | Ichor escort | 2 | 3 | 3 | 4 | 4 | 4 | 3 | 23 |
| 6 | Stack platform | 4 | 3 | 4 | 3 | 4 | 3 | 2 | 23 |
| 7 | Endure lantern | 4 | 4 | 5 | 2 | 3 | 4 | 5 | 27 |
| 8 | Hunter alarm | 2 | 5 | 4 | 4 | 2 | 3 | 4 | 24 (M2) |
| 9 | Soul nose | 1 | 3 | 2 | 3 | 4 | 3 | 3 | 19 |

Notes on the calls:
- **Faithful.** Canon blubs are ambient, glowing (novel, L), squeaky, ichor-bathing, stacking. Nothing
  in canon gives them a job; 5 (escort) is the furthest from canon, 9 invents a sense.
- **Meaningful** is about a decision the player makes. 2 makes *where to be when the Tide turns*
  easier to plan; 3 rewards playing music (the Sift's core verb, P1); 1 and 7 change no decision.
- **5 Ichor escort** is a real power and would make the blub a worker by D-016's own test. Rejected.
- **6 Stack platform** stays the bible's Could: commanded riding stacks are the riskiest code (the
  WP-034 stacking spike) and the payoff (reach) overlaps vanilla scaffolding.
- **8 Hunter alarm** is good but has nothing to warn about until M2's hunters. Recorded for M2.

### Decision: **"The blub that sings back"**: 3 + 2, dressed with 7
- **Echo singer (3)** is the reason to befriend: play a note and your blub answers it. Each blub
  answers at its own interval above your note (a root, a third or a fifth, fixed when it is
  befriended), so three blubs make a chord. Music is how you befriend them and how you keep
  enjoying them.
- **Tide herald (2)** is the reason to keep one along: a befriended blub gets restless ~30 s before
  each Flow begins, i.e. at the end of Thrive and at the end of Endure, the two changes the sky
  gives no countdown for.
- **Endure lantern (7)** as dressing: its belly glows softly in Endure (render only), which makes
  the curled-up shelter behaviour readable at night and costs nothing.
- **Why not more:** escort (5) is power; platform (6) is Could; alarm (8) waits for M2's hunters.

## Identity
- **Canon** (RESEARCH_BESTIARY "Blub"; RESEARCH.md): the Dungeons II vanilla first look shows "a tiny
  rabbitlike blub [that] walks casually through the grasses" [S-W2]: a small pale-blue box-bodied
  critter with ear tufts [OBS]; "bunny-like creatures that walk rather than hop" [P-PCGAMER]. Novel:
  glowing, rabbitlike, squeaks, soft and squishy, hops [W:Blub] (L). "Blubs enjoy bathing in ichor"
  [W:Blub]. Four variants (Carapace, Meadows, fungal, ravines). Kotaku's "blue bunnies" stack into
  teetering towers that topple [R-KOT] (M; that these are blubs is our reading).
- **Changed in translation:** it *walks* when calm (canon look) and *hops* when happy, dancing or
  hurrying (novel, and the bible's "it hops"), so both readings stay. Only the Meadow skin ships in
  M1; the other variants become skins later. Canon makes it "a Deluxe Edition pet", which grounds the
  pet role. **Our inventions:** befriending by music (D-016) and, in this doc, the echo and the Tide
  herald, built on vanilla precedents (allay, cat).
- **One-sentence fantasy:** a soft blue bunny-thing that bathes in ichor, sings your notes back, and
  follows you home if you play for it.
- **Role:** ambient → companion (pet) once befriended.
- **Home:** Singer's Meadow, near tide basins and ichor pools. Reacts to every Tide (below).

## Silhouette and look
- **Hitbox:** 0.5 × 0.5 blocks (rabbit 0.49 × 0.6, allay 0.35 × 0.6). About a third of a player's
  height: smaller than a cat, bigger than a silverfish.
- **Readable at 10 blocks:** a rounded pale-blue box with two upright ear tufts and a bright belly;
  it is the only pale-blue mob in the Sift (the meadow is coral, the sky teal, the trees white).
- **Palette:** new ramp `blub` in palette.md (pale blue, dark → light): `#2c4f8f` `#3f6fb8` `#5f93d8`
  `#8ab6ee` `#b9d8fa` `#e6f3ff`; belly glow uses `membrane` 4–5; eyes `songwood_bark` 0 with a
  `particle` 3 catch-light. Texture 32 × 32.
- **Model parts** (pixels): `body` 7 × 6 × 7 (the box), `belly` (front face, emissive layer),
  `ear_left` / `ear_right` 2 × 4 × 1 (tufts, pivot at the base), `foot` × 4 2 × 1 × 2, `tail` 2 × 2 × 1.
  No separate head: the eyes are on the body's front, as the vanilla first look shows.
- **Animations** (keyframes, E5):
  | Clip | Length | Notes |
  |---|---|---|
  | idle | 2 s loop | breathing squash (scale y 1 → 0.95), ear twitch every few loops |
  | walk | 0.5 s loop | waddle: body roll ±6°, feet alternate |
  | hop | 0.6 s | happy/befriended: squash 0.1 s, jump, stretch, land squash |
  | listen | 1 s loop | ears straight up, body sways to the beat (played while music is near) |
  | sing | 0.4 s | the echo: ears flick back, mouth-squash; played when it answers a note |
  | bathe | 2 s loop | floating in ichor up to the belly, gentle bob |
  | curl | 1 s in, loop | Endure shelter: ears flat, body flattened to 0.7, belly glow on |
  | stack wobble | 1.5 s loop | when ridden or riding: sway ±8°, growing before a topple |
  | hurt / death | vanilla | red flash; death poof |

## Behavior
### State machine (goals, priority order)
```
FLOAT (in water) ──────────────────────────────────────────── always first
PANIC (hurt) ─► flee 2 s ─► back to normal
SIT (befriended, ordered) ── use toggles, like a cat
FOLLOW OWNER (befriended; owner > 6 blocks away): vanilla FollowOwnerGoal (hop-walk after them;
        teleport at > 12 blocks, TamableAnimal.TELEPORT_WHEN_DISTANCE_IS_SQ = 144). Our one addition:
        while the owner stands still in Endure, SHELTER below takes over (the "is the owner moving"
        check is ours, not vanilla's)
SHELTER (Endure; or night outside the Sift): untamed blubs walk to a roof within 12 blocks
        (songwood leaves first, then any leaves, then any solid block overhead) and CURL until the
        Tide changes; with no roof in reach they curl where they stand. A befriended blub curls only
        when its owner has stood still for 5 s, under a roof within 6 blocks or at the owner's feet,
        and uncurls to follow as soon as the owner moves away
WATERLINE (Flow, a basin within 16): walk to the basin's current waterline and potter along it as
        it moves, dipping into the edge now and then: the top ichor layer is one block deep over each
        ring (system_tides.md), so the waterline is where blubs bathe every cycle
LISTEN + DANCE (music heard in the last 10 s: note blocks and goat horns within 16, jukeboxes within
        10): face the source and play `listen`; untamed blubs drift toward it and hop to the beat
STACK (starts only while listening, in Thrive or outside the Sift): listening blubs within 3 blocks
        of each other climb onto one another, up to 3 tall, and sway. The goal claims MOVE for the
        bottom blub, which stands and sways instead of drifting. Once built, the tower doesn't need the
        music: it topples 15–40 s after the music stops, or at once if the bottom blub moves more than
        0.5 block, is hurt, the Tide changes, or a befriended rider's owner walks away
BATHE (Thrive, ichor within 8, now and then): walk into a cell where the ichor is one block deep over
        a solid floor and sit in it for 10–30 s, shown "up to the belly" by a model offset (ichor has
        no buoyancy, so a blub never wades deeper than one block on purpose)
STROLL / LOOK AROUND
```
- **AI choice: goal selector**, as the rabbit, cat and wolf use (VANILLA_ANALOGS E3: goals for simple
  reactive critters). E3 prefers a Brain for behaviour players learn to read over time; the blub's
  readable states are few and each is one goal with a plain `canUse` (the Tide, music, the owner), and
  `TamableAnimal` already brings owner, sit and teleport goals that behave exactly like vanilla pets.
  A Brain would rebuild those for no gain.
- **Outside the Sift** `Tide.current` is null: night stands in for Endure (shelter), there is no
  waterline and no ichor to bathe in, and blubs still listen, dance and stack to music (the vision's
  "dance and stack" at home).

### Befriending (D-016, refined)
1. **Notice.** Any music (a note block or goat horn within 16, a jukebox within 10) makes untamed
   blubs *listen* for 10 s: ears up, a curious chirp, they turn and drift toward it. Nothing is
   befriended yet.
2. **Befriend.** A note **played by a player's own hand** (a note block they click or punch, or a goat
   horn they blow: both game events name the player; a redstone-played note names no one) befriends
   **the nearest untamed blub within 4 blocks of that player that was already listening** and can see
   them. The befriend check runs before the note marks blubs as listening, so the first note of a
   tune only gets attention; the next one befriends. One note,
   one blub. Hearts, a happy squeak and a `hop`. The 4-block rule copies the allay (you hand it the
   item) and shows which blub is "the one watching"; it also keeps a long tune near a herd from
   befriending the whole herd by accident.
3. Redstone-played note blocks and jukeboxes never befriend (no hand): they only make blubs listen.
   Every player befriends for themselves: a note befriends a blub for the player who played it.
4. No cost and no fuel, as with the allay.
5. **Sit and release.** *Use* with an empty hand toggles sitting, as with a cat. *Sneak-use* with an
   empty hand on a sitting blub releases it: it hops away untamed. Vanilla pets have no release; we
   add one so a player who befriends a crowd isn't stuck with it.
6. **Its voice.** At befriending, a blub takes a fixed interval for its echo: +0, +4 or +7 semitones
   (root, third, fifth), cycling through a per-player counter (a Fabric attachment), so any three a
   player befriends in a row make a chord.

### Reactions
- **Players:** untamed blubs ignore players unless hurt (then panic). Befriended: follow the owner.
- **Music:** listen and dance (all); the **echo** (befriended only): when its owner plays a note
  within 16, the blub answers 0.3 s later with its squeak at the owner's note plus its own interval
  (pitch as vanilla's `NoteBlock.getPitchFromNote`; past note 24 it drops an octave rather than
  clamping, so high chords stay chords). The echo is a plain sound and particle: it emits no
  `note_block_play` or `instrument_play` game event, so echoes never open frames or set off other
  blubs. A goat horn,
  or a note block with a mob head on it, has no note: the echo then uses note 12 (pitch 1.0). Each
  answer also shows vanilla's note particle above the blub, coloured by note / 24 as
  `NoteBlock.triggerEvent` does, so the echo reads without sound (mission §7.6). Several befriended
  blubs answer together: a chord. At most one answer per blub per 0.5 s.
- **Tide herald** (befriended only, in the Sift): ~30 s before each Flow begins (the end of Thrive and
  the end of Endure) it gets restless: short hops and a rising chirp every few seconds, with a small
  note particle. Restless wakes a curled blub (the end of Endure is when it matters). Untamed blubs
  simply switch behaviour when the Tide changes.
- **Souls / vibrations:** none in M1 (no XP interaction; it isn't a vibration listener).
- **Light:** none; its belly glows in Endure and at night (render only).
- **Ichor:** immune (in `#thesift:ichor_adapted`): no slow, no burn, no drain; it floats in it.
- **Other Sift mobs:** none in M1. **Illagers** (M4): flee from them like a rabbit from a wolf.

## Stats (with vanilla analogs)
| Stat | Blub | Rabbit | Allay | Axolotl | Why |
|---|---|---|---|---|---|
| Max health | 8 | 3 | 20 | 14 | Sturdier than a rabbit so a pet survives a stray hit; far below a fighter |
| Armor / damage | 0 / none | 0 / none | 0 / none | 0 / 2 | A pet, never a fighter |
| Speed | 0.25 (walk), ×1.6 when following or panicking | 0.3 | 0.1 fly | 1.0 swim | A waddle; keeps up with a walking player while following |
| Follow range | 16 | 16 | 16 | 16 | Vanilla default |
| Knockback resistance | 0 | 0 | 0 | 0 | |
| XP on death | 1–3 | 1–3 | 0 | 1–3 | Animal norm |
| Difficulty scaling | none | none | none | none | Passive |

## Player interaction
- **Telegraphs:** listening (ears up, a chirp, it comes closer) tells the player the next hand-played
  note will befriend the blub at their feet; hearts confirm. The Tide herald's restless hops, chirp
  and note particle precede each Flow.
- **Counterplay / avoidance:** none needed; it is harmless.
- **Befriend rules:** above. Sit/stand: *use*; release: *sneak-use* while sitting. Leash: yes. Name
  tag: yes (a blub named "Bubbles" gets a special squeak, Could). Breeding and healing with tidewrack
  treats: **M2**. Until then a hurt blub regenerates 1 HP every 30 s **only while sitting or curled**;
  vanilla pets heal only by eating, but the blub has no food until M2, and a pet that can never heal
  is a slow dead end. Resting to heal leaves M2's treats a clear job (fast healing on the move).
- **What the player gains:** a companion that sings back (music feels alive) and a Tide herald.
- **The decision it creates, honestly:** in M1, little. A blub costs nothing and nothing hunts it yet,
  so it is a toy and a Tide warning: the choices are which notes to play and whether to bring a
  chord's worth of blubs. M2's Endure hunters make keeping blubs safe a real choice (lumen light,
  shelter, leaving them home), and M2's treats add breeding and healing on the move.

## Loot and purpose
- Drops nothing but 1–3 XP (the axolotl precedent). No dead-end drops; a pet isn't harvested.

## Spawning
- Singer's Meadow, **creature** category, weight 10, groups 2–4; on healthy sculk or tide sand, with
  raw brightness above 8 (the vanilla animal rule, `Animal.isBrightEnoughToSpawn`).
- **At world generation:** the biome's `creature_spawn_probability` is 0.03, so about one group per
  30 chunks, independent of the Tide (a chunk generated in Endure still gets its blubs).
- **Natural spawning** (the vanilla creature spawner, capped by the creature mob cap): **not in
  Endure.** The light rule alone would not stop it: `isBrightEnoughToSpawn` reads stored sky light,
  which stays 15 under open sky, and Endure's darker sky only changes `skyDarken`. So the spawn
  predicate adds `Tide.current(level) != ENDURE` for NATURAL spawns. Blubs already out shelter.
- **Despawn:** never (an animal), so the meadow keeps its blubs.
- **Not at home:** blubs don't spawn outside the Sift; a befriended one can live there.

## Audio (WP-050)
| Event | Description | Subtitle | Variants |
|---|---|---|---|
| `entity.thesift.blub.ambient` | soft squeak | Blub squeaks | 4 |
| `entity.thesift.blub.listen` | curious rising chirp | Blub listens | 2 |
| `entity.thesift.blub.happy` | bright double squeak (befriended) | Blub is happy | 2 |
| `entity.thesift.blub.sing` | pitched squeak (the echo; pitch set in code) | Blub sings | 1 |
| `entity.thesift.blub.restless` | quick chirps (Tide herald) | Blub is restless | 2 |
| `entity.thesift.blub.curl` | sleepy hum (Endure) | Blub hums | 2 |
| `entity.thesift.blub.splash` | soft bloop (bathing) | Blub splashes | 2 |
| `entity.thesift.blub.topple` | bouncy thud (a stack falls) | Blubs topple | 2 |
| `entity.thesift.blub.hurt` | squeak | Blub hurts | 2 |
| `entity.thesift.blub.death` | deflating squeak | Blub dies | 1 |
| `entity.thesift.blub.step` | soft pat | (none, like vanilla steps) | 4 |

## Edge cases
| Case | Handling |
|---|---|
| Water | Floats and swims slowly (FloatGoal); it is not a water mob |
| Lava, fire | Normal damage; ichor immunity doesn't cover them |
| Leashed | Yes, like any animal |
| Name-tagged | Keeps the name; "Bubbles" squeaks differently (Could) |
| Boats / minecarts | Can ride, like small animals |
| The membrane | No blub walks through a membrane on its own: the blub type is in `#thesift:cannot_cross`, so untamed blubs never wander into an Ancient City. When its owner crosses, a befriended blub that isn't sitting and is within 16 blocks of where the owner entered is brought along to the arrival (D-016); sitting blubs stay |
| Leashed at the membrane | A leash its owner holds comes along: 26.3 copies leash data when an entity changes dimension and re-attaches it by UUID. A blub leashed to anything else (a fence knot, another player) stays behind like a sitting one, so no phantom knot appears in the other world |
| Arriving in an Ancient City | Accepted risk, as with wolves: a blub's steps and hops are vibrations a warden can hear. A sitting blub makes none |
| Nether portals | Vanilla rules (it can be pushed through; it doesn't follow on its own) |
| Owner offline / dead | Vanilla behaviour: with no owner to find (`getOwner()` is null) the follow goal never starts, so it wanders nearby until the owner returns |
| Peaceful | Exists (passive) |
| `mobGriefing` false | No effect: it changes no blocks |
| `/summon` | Untamed, Meadow skin |
| Spectators | Ignored for listening, befriending and following |
| Stack in a 2-high space | Doesn't stack if there is no room above |
| Sitting or following blubs | Never stack: sitting blubs sit; a blub following its owner leaves a tower first (vanilla pets can't reach their owner while riding) |
| Falls | A soft critter: `SAFE_FALL_DISTANCE` 4 for all falls (topples included) |

## Tech notes
- **Class:** `Blub extends TamableAnimal` (owner, sit, teleport-to-owner from vanilla). Breeding is
  disabled until M2 (`isFood` false, no offspring).
- **Synced data:** `LISTENING` (bool: set when listening starts and ends, never ticked, so a crowd at
  a jukebox sends no packet storm), `CURLED` (bool), `RESTLESS` (bool), `VARIANT` (int, Meadow only in
  M1). Saved only: `ECHO_INTERVAL` (0, 4 or 7) and the listening end tick. Animation states (E5) start client-side from synced data and entity events.
- **Music hearing:** a `GameEventListener` per blub would cost a listener each; instead the existing
  game-event hook (D-020, `ServerLevelGameEventMixin`) gains a second consumer that looks up blubs in
  a 16-block box only for music events (rare). The mixin must pass the event's `GameEvent.Context` on:
  the hand that played comes from its source entity. The note comes from the world, not the context
  (a note block's context carries no block state): `level.getBlockState(BlockPos.containing(pos))`,
  read only if it is a note block. Recorded in D-020 when implemented.
- **Crossing with the owner:** `SiftGates.destination` runs for every entity that crosses (and from
  tests), so it isn't a "player crossed" signal. Instead it records, for players only, where they
  entered, keyed by player and stamped with the game tick. Fabric's
  `ServerEntityLevelChangeEvents.AFTER_PLAYER_CHANGE_LEVEL` (which also fires for Nether and End
  portals, `/tp` and respawns) consumes the record once, and acts only on an Overworld↔Sift change
  recorded within the last few ticks: it then teleports the owner's eligible blubs from around that
  spot to the player's arrival. Blubs never use the portal themselves (`#thesift:cannot_cross`).
- **Stacking without steering:** a mob riding a mob steers it by default (`Mob.getControllingPassenger`)
  and the bottom mob's move and look goals switch off (`Mob.updateControlFlags`). `Blub` overrides
  `getControllingPassenger` to return null, so riders never steer and the bottom blub keeps its goals.
- **Pathfinding:** ichor isn't water or lava to the path finder; blubs walk through it. Bathing picks
  an ichor cell one block deep over a solid floor.
- **Search costs:** every blub reacting to the same Tide change would search at once, so each waits a
  random 0–5 s first. Roof search is bounded to 12 blocks and reads heightmap columns (a roof is a
  column whose MOTION_BLOCKING height is above the blub), not a block scan. Basins are found from
  the tide vents' block entities in the blub's own and neighbouring chunks, never by scanning.
- **Expected counts:** about one group per 30 chunks from generation (~40 blubs in a 10-chunk view
  of all-Meadow), plus what the creature spawner adds up to the vanilla creature cap. Blubs don't
  despawn, so this is the steady state.
- **Risks:** stacking via riding (WP-034 spike: if riding stacks feel bad, stacking moves to M2 per
  PLAN.md's exit ramp); the echo's pitch mapping (vanilla `NoteBlock.getPitchFromNote`); if basins
  ever fail (D-017 #7's fallback), Flow's waterline behaviour follows static pool edges instead.

## BALANCE
The stats table above is the BALANCE.md entry (copied there on freeze).

## Critique log
- **Round 1 (fresh reviewer): FAIL.** Scores: template 4, canon/honesty 4, vanilla-feel 4, player value
  3, readability 3, feasibility 3, bible consistency 3. Must-fix, all fixed in this revision:
  1. Stacking triggered by idleness and pre-empted by music, against the bible's "stacks to music" →
     stacking now happens only while listening and topples after the music ends.
  2. False vanilla claims: pets teleport at 12 blocks (not 16); with the owner offline they wander
     (they don't sit) → corrected.
  3. "Chords" were unison → each blub keeps a fixed interval (+0/+4/+7).
  4. Endure behaviour of a befriended blub contradicted itself → one rule: follow while the owner
     moves, curl when the owner stands still.
  5. Membrane crossing: `destination` runs for every entity; untamed blubs could wander through →
     blubs are in `#thesift:cannot_cross`; owners' blubs come along through
     `AFTER_PLAYER_CHANGE_LEVEL`.
  Should-fix, taken: befriending wording (nearest *untamed*, within 4 blocks of the player who
  played; 10-s listening; jukebox at 10); the echo's pitch for horns and mob heads, plus a note
  particle; the spawn light rule; behaviour outside the Sift; shelter without a roof; stacking without
  steering; an honest "decision" paragraph; walking vs hopping; regeneration only at rest; the
  herald's warnings moved to the two unannounced Tide changes; leashes at the membrane.
- **Round 2 (fresh reviewer): FAIL.** Scores: template 5, canon 4, vanilla-feel 4, player value 4,
  readability 4, feasibility 3, bible 4. Round 1's fixes held. Must-fix, all fixed:
  1. "Not in Endure, for free" was false (spawn light reads stored sky light, 15 under open sky) →
     an explicit Tide check for natural spawns; generation spawns stay Tide-free.
  2. Leashes do cross dimensions in 26.3 (data copied, re-attached by UUID); fence-tied blubs would
     make phantom knots → owner-held leashes come along, others stay.
  3. A note block's event context has no block state → the note is read from the world.
  Should-fix, taken: a synced boolean instead of a ticking counter; bathing one block deep (no
  buoyancy) and at every Flow's waterline; the first note never befriends; the stack's base holds
  still and towers outlive the music; one-shot, tick-stamped crossing records; honest spawn numbers
  (`creature_spawn_probability` 0.03); staggered, bounded searches; the D-017 fallback; Ancient City
  arrivals. Notes taken: the echo emits no game events; high chords drop an octave; intervals cycle
  through a per-player counter; restless wakes a curled blub; FOLLOW's addition named as ours;
  `SAFE_FALL_DISTANCE` 4.
