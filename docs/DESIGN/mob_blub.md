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
- **Echo singer (3)** is the reason to befriend: play a note and your blub answers at your pitch;
  a few blubs make chords. Music is how you befriend them and how you keep enjoying them.
- **Tide herald (2)** is the reason to keep one along: a befriended blub reacts ~30 s *before* each
  Tide change, so a player with a blub plans Flow and Endure without a clock.
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
- **Changed in translation:** it *walks* (canon look) and *hops when happy* (novel), so both readings
  stay. Only the Meadow skin ships in M1; the other variants become skins later. Befriending by music,
  the Tide herald and the echo are our additions (D-016), built on vanilla precedents (allay, cat).
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
FLOAT (in water) ─────────────────────────────────────────── always first
PANIC (hurt) ─► flee 2 s ─► back to normal
SIT (befriended, ordered) ── use toggles, like a cat
FOLLOW OWNER (befriended, owner > 6 blocks away; teleport if > 16, like vanilla pets)
SHELTER (Endure, or night outside the Sift): walk to the nearest block within 12 with leaves or any
        roof above, then CURL until Endure ends
WATERLINE (Flow, a basin within 16): walk to the basin's current waterline (the first dry terrace
        or rim cell next to the top ichor layer) and potter along it as it moves
LISTEN (music within 16, last 3 s): face the source, play `listen`; untamed blubs drift toward it
BATHE (Thrive, ichor within 8, now and then): walk into ichor and float for 10–30 s
STACK (Thrive, 2+ idle blubs within 3): one climbs onto another (max 3 tall); topples after 15–40 s,
        or at once if the bottom one moves, is hurt or the Tide changes
STROLL / LOOK AROUND
```
- **AI choice: goal selector**, as the rabbit, cat and wolf use (VANILLA_ANALOGS E3: goals for simple
  reactive critters). The Tide gates are plain `canUse` checks on `Tide.current(level)`; befriending
  and following reuse `TamableAnimal`'s owner, sit and teleport rules, so pets behave like vanilla
  pets. A Brain buys nothing here: the blub has no multi-step plans or long-lived memories.

### Befriending (D-016, refined)
1. **Notice.** Any music within 16 blocks makes untamed blubs *listen* for 10 s (ears up, a curious
   chirp, they turn toward it). Nothing is befriended yet.
2. **Befriend.** A note **played by a player's own hand** (a note block clicked by them, or a goat horn
   they blow: both game events name the player) while a blub is listening befriends **the nearest
   listening blub within 16 that can see the player**. One note, one blub. Hearts, a happy squeak and
   a `hop`.
3. A redstone-played note block, a jukebox, or another player's note never befriends (no hand, or
   another hand): they only make blubs listen.
4. No cost and no item, as with the allay.
5. **Sit and release.** *Use* with an empty hand toggles sitting, as with a cat. *Sneak-use* with an
   empty hand on a sitting blub releases it: it hops away untamed. Vanilla pets have no release; we
   add one so a player who befriends a crowd isn't stuck with it.

### Reactions
- **Players:** untamed blubs ignore players unless hurt (then panic). Befriended: follow the owner.
- **Music:** listen (all); the **echo** (befriended only): when its owner plays a note within 16, the
  blub answers 0.3 s later with a squeak at the same pitch (note-block pitch → sound pitch, as vanilla
  maps it). Several befriended blubs answer together: a chord. Max one answer per blub per 0.5 s.
- **Tide herald** (befriended only, in the Sift): ~30 s before Flow begins (in either direction) it
  gets restless (short hops, a rising chirp every few seconds); ~30 s before Endure it stops following
  to look for cover, then comes back. Untamed blubs simply switch behaviour at the Tide.
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
- **Telegraphs:** listening (ears up + chirp) tells the player the next hand-played note will befriend;
  hearts confirm. The Tide herald's restless hops and rising chirp precede a Tide change.
- **Counterplay / avoidance:** none needed; it is harmless.
- **Befriend rules:** above. Sit/stand: *use*; release: *sneak-use* while sitting. Leash: yes. Name
  tag: yes (a blub named "Bubbles" gets a special squeak, Could). Breeding and healing with tidewrack
  treats: **M2**. Until then a hurt blub regenerates 1 HP every 30 s; vanilla pets heal only by
  eating, but the blub has no food until M2, and a pet that can never heal is a slow dead end.
- **What the player gains:** a companion that sings back (music feels alive) and a Tide herald.
- **The decision it creates:** bring a blub along (and keep it safe in Endure) for warnings and
  company, or travel light. And: which note to play next.

## Loot and purpose
- Drops nothing but 1–3 XP (the axolotl precedent). No dead-end drops; a pet isn't harvested.

## Spawning
- Singer's Meadow, **creature** category, weight 10, groups 2–4, at world generation and by the
  vanilla creature spawner; on healthy sculk or tide sand.
- **Not in Endure:** the spawner skips Endure (a spawn predicate on `Tide.current`); blubs already
  out shelter.
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
| The membrane | A befriended, non-sitting blub within 16 blocks of its owner crosses with them (D-016), arriving next to them; sitting blubs stay |
| Nether portals | Vanilla rules (it can be pushed through; it doesn't follow on its own) |
| Owner offline / dead | Sits where it is until the owner returns, like vanilla pets |
| Peaceful | Exists (passive) |
| `mobGriefing` false | No effect: it changes no blocks |
| `/summon` | Untamed, Meadow skin |
| Spectators | Ignored for listening, befriending and following |
| Stack in a 2-high space | Doesn't stack if there is no room above |
| Stack toppling off a cliff | Toppled blubs get no fall damage under 4 blocks (a soft critter) |

## Tech notes
- **Class:** `Blub extends TamableAnimal` (owner, sit, teleport-to-owner from vanilla). Breeding is
  disabled until M2 (`isFood` false, no offspring).
- **Synced data:** `LISTENING_TICKS` (int), `CURLED` (bool), `RESTLESS` (bool), `VARIANT` (int, Meadow
  only in M1). Animation states (E5) start client-side from synced data and entity events.
- **Music hearing:** a `GameEventListener` per blub would cost a listener each; instead the existing
  game-event hook (D-020, `FrameMusic`) gains a second consumer that looks up blubs in a 16-block box
  only for music events (rare). Owner identity comes from the event's source entity.
- **Crossing with the owner:** `SiftGates.destination` already runs for the player; it collects
  eligible blubs (owned, not sitting, within 16) and teleports them to the arrival after the player.
- **Pathfinding:** ichor isn't water or lava to the path finder; blubs walk through it. Bathing picks
  an ichor cell with a solid floor ≤ 2 deep.
- **Expected counts:** ~1 group per 4–6 chunks; under 30 loaded around a player.
- **Risks:** stacking via riding (WP-034 spike: if riding stacks feel bad, stacking moves to M2 per
  PLAN.md's exit ramp); the echo's pitch mapping (vanilla `NoteBlock.getPitchFromNote`).

## BALANCE
The stats table above is the BALANCE.md entry (copied there on freeze).

## Critique log
- Round 1: pending.
