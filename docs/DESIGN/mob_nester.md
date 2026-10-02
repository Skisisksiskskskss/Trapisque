# Nester (WP-061) — DRAFT

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
  only in Endure (D-013).
- **One-sentence fantasy:** a long-legged listener that comes galloping out of the dark at the sound
  you made, and dances around your sword.
- **Role:** hostile.
- **Home:** Singer's Meadow and Hymnstone Rise, on soil, in Endure only (world.md §2).

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
  - Eyes and the enduring glow use the existing `glyph` cyan (emissive layer).
- **Texture:** 64 × 64.
- **Model parts:** body; neck; head with snout and a hinged jaw; crest (three fins, one hinge each);
  four legs of two segments each (thigh, shin); a short tail tuft; **enduring only:** a second, larger
  crest row with spikes (a separate part, hidden on ordinary Nesters).
- **Animations** (procedural clips in the model, as the Blub's, D-021). Durations in ticks:
  - idle: head bobs, crest twitches, weight shifts;
  - walk: a long-legged trot; **gallop**: a bounding gait, body pitched forward;
  - **tell** (20): stops, head up and turned, crest fans upright;
  - **search** (60): head low, sweeping side to side, sniffing;
  - **lunge**: windup 8 (crouch, crest flat, jaw open), leap 6 (active: the bite lands on contact),
    recovery 12 (stands, crest down, head shake);
  - **circle**: a side-stepping gait facing its target; **dodge** (4): a quick hop sideways;
  - **emerge** (40): rises out of the soil, shaking off particles; **dig** (60): forelegs paw, it sinks;
  - hurt: a flinch; death: vanilla's tip-over.

## Behavior
### State machine
The hunt system's listener states (system_hunt.md §3: roam, tell, gallop, search, hunt) plus the
Nester's own:
```
emerge (40) ──► roam ──hears──► tell (20) ──► gallop ──► search (60) ──finds──► hunt
                  ▲                                         │ nothing             │
                  └─────────────────────────────────────────┘                     ▼
hunt: approach ──in range 2.5–6──► lunge windup (8) ──► leap (6) ──► recovery (12) ──► circle (30) ──► approach
      (closer than 2.5: a standing bite: windup 6, no leap)          blocked by a shield: recovery 30
falling Flow ──► retreat (system §4): to soil ──► dig (60) ──► gone
```
- **Emerge:** a naturally spawned Nester rises out of the soil over 40 ticks (it "surfaces", as the
  bible says), with the soil's particles and a sound subtitled "Nester surfaces". It doesn't listen
  while emerging. Nesters from spawn eggs and `/summon` skip it.
- **Lunge:** from 2.5 to 6 blocks, with line of sight. Windup 8 ticks (crouch and a hiss, subtitled
  "Nester hisses"), then a leap toward where the target is at the leap's start (0.8 horizontal, 0.35
  up), biting on contact during the 6 active ticks. Stepping aside or jumping during the windup makes it
  miss. Recovery 12 ticks, in which it can't dodge.
- **Shields:** a bite blocked by a shield staggers it: recovery 30 instead of 12. Shield the lunge,
  then hit it.
- **Circle:** after each lunge it circles its target at 4 blocks for 30 ticks, facing it.
- **Dodge** (canon): while circling, a melee hit from its target is dodged 50 % of the time (Easy
  30 %, Hard 60 %): the hit does nothing, and it hops 2 blocks sideways, with a sound subtitled
  "Nester dodges". At most one dodge per circle. It never dodges projectiles, in recovery, or while
  galloping or searching. Counterplay: shoot it while it circles; hit it in recovery.
- **The gallop is loud:** gallop steps play at volume 1.5 (heard about 24 blocks out), subtitled
  "Nester gallops". Ordinary steps are quiet and unsubtitled, as vanilla steps.

### AI
- **Goal selector**, as the wolf and spider (and the Blub, D-021): the states are few and linear, and
  a Brain adds memory plumbing for nothing. Priorities: 0 float; 1 retreat (falling Flow); 2 lumen
  rim and walk-out; 3 hunt (lunge, circle); 4 the hearing reaction (tell, gallop, search); 5 roam; 6
  look around. Targeting: hurt-by (retaliation) and the search's find; never by sight alone (system
  §3), except a target within 2 blocks.
- **Navigation:** ground navigation, step height 1.0 (long legs walk up a block without jumping, as a
  horse). It avoids water and ichor, the Sift's water (path malus 8; D-024).

### Reactions
| To | Reaction |
|---|---|
| Players | Hunted when heard and found, when they hurt it, or within 2 blocks. Never by sight alone |
| Sound and vibrations | The hearing rule (system §3) |
| Souls (M3) | None in M2 |
| Tides | Exists only in Endure: emerges with it, burrows at falling Flow, always (system §4, D-023) |
| Light | Lumen repels it (system §6); torches don't, but block light stops spawning |
| Other Sift mobs | Ignores other hunters (and their sounds). **Blubs** are targets when found |
| Illagers (M4) | Targets when found or when they hurt it |
| Ichor | The Sift's water (D-024): it swims across when it must, and paths around it |

## Stats (vanilla analogs side by side)
| Stat | Nester | Analogs |
|---|---|---|
| Health | 20 | zombie 20, spider 16, wolf (wild) 8 |
| Armor | 2 | zombie 2 |
| Bite damage (Easy / Normal / Hard) | 3 / 4 / 6 | wolf 3 / 4 / 6 |
| Movement speed | 0.3; gallop and hunt ×1.3, roam ×0.6 | spider 0.3, wolf 0.3 |
| Follow range | 24 (the hunt's drop distance) | zombie 35, spider 16 |
| Knockback resistance | 0 | most mobs 0 |
| Step height | 1.0 | horse 1.0 |
| XP | 5 | most hostiles 5 |
| **Enduring** (system §5) | health 30, bite 3.75 / 5 / 7.5, KB resistance 0.2, XP 10 | — |

At gallop it is a little slower than a sprinting player: a player who reacts to the tell gets away;
one who doesn't, doesn't.

## Player interaction
- **Telegraphs:** the vibration particle, then the tell (crest, sound, subtitle); the gallop's thud;
  the lunge's crouch and hiss; the circle.
- **Counterplay:**
  - *avoid:* sneak, wool, lures, lumen (system); stay under a one-block-high gap;
  - *fight:* shield the lunge and hit the stagger; hit in recovery; shoot it while it circles;
    don't swing while it circles (it dodges).
- **Companion rules:** none. It can't be leashed (vanilla: no `Enemy` can).
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
  (`#thesift:hunter_burrowable`), no lumen within 8, outside the gate sanctuary (system §7).
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
| `entity.nester.dodge` | A quick whoosh | "Nester dodges" | 2 |
| `entity.nester.emerge` | Soil crumbling, a shake | "Nester surfaces" | 2 |
| `entity.nester.burrow` | Pawing, soil closing over | "Nester burrows" | 2 |
| `entity.nester.hurt` | A sharp squawk | "Nester hurts" | 3 |
| `entity.nester.death` | A falling whistle and a collapse | "Nester dies" | 2 |
| `entity.nester.step` | Light quick steps | (none, as vanilla steps) | 4 |
| `entity.nester.lulled` (M4) | A soft trill as the crest folds | "Nester lulled" | 2 |

## Edge cases
| Case | Handling |
|---|---|
| Water | Floats and swims slowly; avoids water when pathing (malus 8) |
| Lava | Vanilla (burns; avoids it) |
| Ichor | As water: floats and swims slowly; avoids it when pathing |
| Leashed | Can't be (vanilla: no `Enemy` can be leashed) |
| Name-tagged | Persistent: never retreats; listens and hunts in Endure; outside Endure it roams and only fights back |
| Boats and minecarts | Vanilla lets mobs ride them; a riding Nester is persistent (vanilla's `requiresCustomPersistence`), can't gallop or lunge, and still hears |
| Portals | Can't cross the membrane (`#thesift:cannot_cross`, D-023). Fire lights no other portal in the Sift (vanilla lights them only in the Overworld and the Nether) |
| Peaceful | Doesn't exist (`notInPeaceful()`) |
| `mobGriefing` false | No effect: it changes no blocks |
| `/summon` and spawn eggs | No emerge animation. Outside Endure it digs away at once (Nesters don't stay out of Endure); a name tag or `PersistenceRequired` keeps one |
| Spectators and creative | Not heard, never targeted (system §3) |
| Two-block ceilings, one-wide corridors | Fits; a one-block-high gap stops it |
| A target that dodges every lunge | The circle and the next lunge repeat; it drops the target at 24 blocks or 100 ticks unseen |

## Tech notes
- **Synced data:** `STATE` (a byte: roam, tell, gallop, search, windup, leap, recovery, circle, dodge,
  emerge, dig) drives the model's clips; `ENDURING` (bool). Saved: `Surface`, `Enduring`, the listener
  data (system §11).
- **Dodge:** in `hurtServer`, before damage: if circling, the source is its target's direct melee
  attack, the roll passes and it hasn't dodged this circle, cancel and hop.
- **Pathfinding cost:** the gallop paths to one spot per sound (not to a moving entity); the hunt paths
  every 10 ticks, as a zombie's melee goal does.
- **Expected counts:** shared monster cap of 70; with Bloombuds commoner, about 10–20 Nesters around a
  player in Endure.
- **Risks:** the lunge's contact bite (test on slopes and half-blocks); the dodge feeling unfair (the
  numbers are per difficulty, and projectiles always land).

## Critique log
