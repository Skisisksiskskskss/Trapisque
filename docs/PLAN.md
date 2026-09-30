# PLAN — The Sift (thesift)

Rolling-wave plan (§5.2). Only the current phase/milestone has fully specified WPs; later ones stay coarse.
Only one WP is IN PROGRESS at a time.

| WP | Title | Phase | Tier | Status |
|----|-------|-------|------|--------|
| WP-001 | Version ground truth & official-Sift check | 0 | S | DONE |
| WP-002 | Toolchain + mod scaffold (build, runServer, genSources) | 0 | M | DONE |
| WP-003 | Sift research I: canon, areas, Tides, access, lore, palette evidence | 0 | L | DONE |
| WP-004 | Sift research II: bestiary (every mob, boss, character) | 0 | L | DONE |
| WP-005 | Vanilla study I: world (dimension, noise, biomes, env attributes, portals, jigsaw) | 0 | L | DONE |
| WP-006 | Vanilla study II: entities (Brain, goals, vibrations/sculk, models/anims, boss bars) | 0 | L | DONE |
| WP-007 | Vanilla study III: plumbing (datagen, SavedData/attachments, payloads, GameTest) | 0 | M | DONE |
| WP-010 | Vision I: fantasy, tone, pillars, journey, progression | 1 | XL | DONE |
| WP-011 | Vision II: entry and return path (≥12 ideas) | 1 | L | DONE |
| WP-012 | Vision III: the dimension's rules (+ env-attribute mapping) | 1 | M | DONE |
| WP-013 | Vision IV: core systems (Tides, souls, sculk, sound, Illagers) | 1 | L | DONE |
| WP-014 | Vision critique, freeze, Gate A | 1 | XL | DONE (Gate A self-reviewed, D-014) |

---
| WP-020 | Content bible I: world (areas, biomes, terrain, blocks, flora, hazards, materials, structures) | 2 | L | DONE |
| WP-021 | Content bible II: creatures (canon-mob verdicts, natives, hostiles, companions, bosses) | 2 | L | DONE |
| WP-022 | Content bible III: items, gear, food, advancements, audio hooks, mechanics | 2 | M | DONE |
| WP-023 | Dependency graph, milestones, Phase 3 WPs and fully specified M1 WPs | 2 | L | DONE |
| WP-024 | Content bible critique, freeze, Gate B (self-review) | 2 | L | IN PROGRESS |
| WP-030 | Architecture decisions | 3 | M | TODO |
| WP-031 | Datagen setup | 3 | M | TODO |
| WP-032 | Test harness | 3 | M | TODO |
| WP-033 | CI | 3 | S | TODO |
| WP-034 | Technical spikes | 3 | M | TODO |
| WP-040 | Dimension skeleton and Tide core | 4 | L | TODO |
| WP-041 | Art pipeline and block set I art | 4 | L | TODO |
| WP-042 | Block set I and the Singer's Meadow terrain | 4 | L | TODO |
| WP-043 | Audio pipeline and the entry and Tide sounds | 4 | M | TODO |
| WP-044 | Entry I: frames, offering, waking, music | 4 | L | TODO |
| WP-045 | Entry II: membrane, crossing, Sift-side gate, return | 4 | L | TODO |
| WP-046 | Blub design doc | 4 | L | TODO |
| WP-047 | Blub art: texture, model, animations | 4 | L | TODO |
| WP-048 | Blub audio | 4 | M | TODO |
| WP-049 | Blub entity: AI and tests | 4 | L | TODO |
| WP-050 | Entry advancements and lang pass | 4 | S | TODO |
| WP-051 | M1 integration and Gate C (self-review) | 4 | M | TODO |

Phase 0 and Phase 1 WP details (with evidence logs) are in `docs/archive/PLAN_phase0-1.md`.

---

## Phase 2 — Content bible and roadmap

Deliverable: `docs/DESIGN/01_CONTENT_BIBLE.md` (index, tier summary, dependency graph, milestones) plus its parts `docs/DESIGN/bible/{world,creatures,items}.md`.
Tier key (mission §6 Phase 2): **Core** (in 1.0) · **Should** · **Could** · **Won't** (with a reason). The frozen vision's Must/Should/Could map to Core/Should/Could.

### WP-020 Content bible I: world
- Phase / Milestone: 2 / —
- Tier: L
- Status: DONE
- Depends on: WP-014 (frozen vision)
- Goal: A tiered inventory of everything in the world layer, each entry with its purpose and at least two Sift-system links.
- Inputs (read ONLY these): docs/DESIGN/00_VISION.md, docs/DESIGN/vision/{systems,rules}.md, docs/RESEARCH.md §2 and §5, docs/VANILLA_ANALOGS.md W2/W3/W6/W7.
- Deliverables: docs/DESIGN/bible/world.md.
- Definition of Done:
  - [x] Areas and biomes (sub-biomes of Singer's Meadow for 1.0; later areas as Won't-for-1.0 with a milestone), terrain features, block families (vanilla-style sets where sensible), flora, hazardous blocks, materials, structures — each tiered, with purpose and system links. (bible/world.md §1–5)
  - [x] Every Core entry names its vanilla analog and the route (data or code). (tables' analog/route columns)
  - [x] Canon-sourced vs invented is marked on every entry. (Source column: C/V/I)
- Iteration budget: self-critique ≤ 2 passes (the bible-wide critique is WP-024).
- Exit ramp: entries that can't be justified go to Could or Won't with a reason.
- Log:
  - 2026-09-30: world.md written.
    - **Biomes:** 3 Core biomes (Singer's Meadow, Hymnstone Rise, Sift Hollows), 1 Should (Lullaby Hills).
    - **Block families:** hymnstone, healthy sculk, songwood, blight; bloom heart, soul block, tide flats, gate, lumen.
    - **Flora and hazards:** tidewrack, Endure bloom, ichor.
    - **Structures:** gate, camp, Singer's grove, Monstrosity hollow.
    - Self-critique pass 1: decor-only flowers moved to Should, and the block count was checked against vanilla's cherry-grove update. Won't list with reasons.

### WP-021 Content bible II: creatures
- Phase / Milestone: 2 / —
- Tier: L
- Status: DONE
- Depends on: WP-020
- Goal: A verdict for every canon mob (adapt / merge / defer / cut, with a reason) and a tiered creature roster.
- Inputs (read ONLY these): docs/RESEARCH_BESTIARY.md, docs/DESIGN/00_VISION.md, docs/DESIGN/vision/systems.md, docs/DESIGN/bible/world.md.
- Deliverables: docs/DESIGN/bible/creatures.md.
- Definition of Done:
  - [x] Every species, character and boss in the bestiary has a verdict and reason (variants may share a base design). (creatures.md §1, every bestiary row)
  - [x] The roster is tiered and each creature has a role (niche), a Tide behaviour, and at least two system links. (creatures.md §2)
  - [x] Vanilla analog named for each Core creature. (creatures.md §2 analog column)
- Iteration budget: self-critique ≤ 2 passes.
- Exit ramp: unclear creatures are deferred with a revisit trigger.
- Log:
  - 2026-09-30: creatures.md written.
    - **Verdicts:** canon soul corruption became the enduring variants; the Twisted Warden merged into the vanilla warden (hard rule 9.4); novel characters cut (no dialogue).
    - **The Blub** is chosen as M1's fully finished mob.
    - **Risk logged:** blub stacking (passenger mechanics) needs a spike.

### WP-022 Content bible III: items, gear, food, advancements, audio, mechanics
- Phase / Milestone: 2 / —
- Tier: M
- Status: DONE
- Depends on: WP-020, WP-021
- Goal: A tiered inventory of items, gear traits, food, advancements, ambience and music hooks, and mechanics.
- Inputs (read ONLY these): docs/DESIGN/00_VISION.md, docs/DESIGN/vision/systems.md, docs/DESIGN/bible/{world,creatures}.md.
- Deliverables: docs/DESIGN/bible/items.md.
- Definition of Done:
  - [x] Items, tools and gear traits, armour (if any), food, advancements (a tree in vanilla's voice), ambience and music hooks, mechanics — tiered, each with purpose and links. (items.md §1–6)
  - [x] Every item has a source and a sink (where it comes from, what it's for). (items.md §1 "source → sink")
  - [x] Nothing breaks the vision's "never gives" list (checked item by item). (items.md §2 check)
- Iteration budget: self-critique ≤ 1 pass.
- Exit ramp: items without a sink are cut.
- Log:
  - 2026-09-30: items.md written.
    - A Tide shell (our own item) replaces the idea of overriding the vanilla clock.
    - Three Sift-only traits.
    - An advancement tab with 13 entries (3 in M1); titles are our own, never canon's.
    - A bone-meal-like accelerator was cut, because it would bypass Thrive's rate.

### WP-023 Dependency graph, milestones, Phase 3 and M1 WPs
- Phase / Milestone: 2 / —
- Tier: L
- Status: DONE
- Depends on: WP-020..022
- Goal: Order the work so systems come before the content that depends on them, and plan M1 in full.
- Inputs (read ONLY these): docs/DESIGN/01_CONTENT_BIBLE.md and its parts; docs/DECISIONS.md D-008, D-010..D-013.
- Deliverables: dependency graph and milestones in 01_CONTENT_BIBLE.md; Phase 3 WPs and fully specified M1 WPs in PLAN.md.
- Definition of Done:
  - [x] A dependency graph covering every Core entry (01_CONTENT_BIBLE.md §2; checked against the §1 tier table).
  - [x] Milestones M1 → M5 → 1.0, each ending shippable (01_CONTENT_BIBLE.md §3).
  - [x] M1 meets the mission's minimum: entry and return (WP-044/045), Singer's Meadow terrain (WP-042), block set I with final art (WP-041/042), the Blub finished (WP-046..049), the Tide core (WP-040), entry advancements (WP-050).
  - [x] Phase 3 (WP-030..034) and M1 (WP-040..051) WPs written with the §5.3 template.
- Iteration budget: self-critique ≤ 2 passes.
- Exit ramp: if M1 is too big for the mission's "thin" slice, move items to M2.
- Log:
  - 2026-09-30: graph and milestones written; Phase 3 and M1 WPs specified.
  - Self-critique pass 1:
    - The M1 Blub depended on M2 content (ichor bathing, tidewrack treats). Added a WP-046 constraint: the M1 Blub is complete with M1 content, and those interactions are M2 additions (creatures.md updated).
    - The spikes that D-013 and creatures.md promised had no WP. Added WP-034; WP-040 depends on it.
    - The Meadow's ambience (Core) had no M1 WP. Added it to WP-043.
  - Self-critique pass 2: M1 is 12 WPs. It is not thin, but each WP is one of the mission's required minimum items, so nothing moves to M2. Block set I stays at 9 blocks plus derived shapes.

### WP-024 Content bible critique, freeze, Gate B
- Phase / Milestone: 2 / —
- Tier: L
- Status: TODO
- Depends on: WP-023
- Goal: A fresh adversarial review of the bible and roadmap; fix; freeze; Gate B as a self-review (D-014).
- Inputs (read ONLY these): 01_CONTENT_BIBLE.md and parts, 00_VISION.md, the §7.1 rubric.
- Deliverables: critique log in 01_CONTENT_BIBLE.md; frozen bible; Gate B summary in STATUS.md.
- Definition of Done:
  - [ ] ≤3 critique rounds by fresh subagents; no must-fix left, or the §5.5 cap applied with reasons.
  - [ ] Bible marked FROZEN; Gate B self-review written.
- Iteration budget: critique rounds ≤ 3.
- Exit ramp: §5.5 critique cap.
- Log:

## Phase 3 — Architecture (WPs specified at Phase 2 exit)

### WP-030 Architecture decisions
- Phase / Milestone: 3 / —
- Tier: M
- Status: TODO
- Depends on: WP-024
- Goal: Decide and record the code architecture before any content lands.
- Inputs (read ONLY these): docs/VANILLA_ANALOGS.md P1–P4 and E1; docs/DECISIONS.md D-003, D-008, D-010..D-013; src/.
- Deliverables: decision records D-015+ (package layout and registration pattern; client/server split; networking payloads; persistent state; config); the package skeleton in src/.
- Definition of Done:
  - [ ] Each mission Phase 3 topic has a decision record.
  - [ ] The skeleton compiles (`./gradlew build`, no new warnings).
- Iteration budget: self-critique 1 round.
- Exit ramp: copy the Fabric example mod's patterns where undecided.
- Log:

### WP-031 Datagen setup
- Phase / Milestone: 3 / —
- Tier: M
- Status: TODO
- Depends on: WP-030
- Goal: One datagen pipeline for models, blockstates, loot, recipes, tags, lang, advancements and the dynamic registries (dimension, dimension type, noise, biomes, timeline, world clock).
- Inputs (read ONLY these): docs/VANILLA_ANALOGS.md P1; build.gradle; src/.
- Deliverables: a `fabric-datagen` entrypoint and providers; output in `src/main/generated`; `tools/dev/datagen-check.sh` (runs datagen twice, fails on any diff).
- Definition of Done:
  - [ ] `./gradlew runDatagen` succeeds, and a second run produces **no diff** (script output as evidence).
  - [ ] The generated resources are on the classpath, and the build stays green.
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: hand-written JSON for any provider Fabric doesn't cover, listed in the log.
- Log:

### WP-032 Test harness
- Phase / Milestone: 3 / —
- Tier: M
- Status: TODO
- Depends on: WP-031
- Goal: Server GameTests, plus client GameTests with screenshots if the API works headless.
- Inputs (read ONLY these): docs/VANILLA_ANALOGS.md P4; tools/dev/headless-client.sh; build.gradle.
- Deliverables: a `fabric-gametest` entrypoint with one trivial test; a client GameTest with one screenshot if feasible; the commands documented in STATUS.
- Definition of Done:
  - [ ] One trivial server GameTest passes (`./gradlew runGameTest`; log excerpt).
  - [ ] A client GameTest takes a screenshot under the headless client, or a BLOCKERS entry explains why not.
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: server GameTests only.
- Log:

### WP-033 CI
- Phase / Milestone: 3 / —
- Tier: S
- Status: TODO
- Depends on: WP-032
- Goal: A GitHub Actions workflow that runs the build, the datagen no-diff check and the GameTests.
- Inputs (read ONLY these): build.gradle; tools/dev/datagen-check.sh.
- Deliverables: `.github/workflows/build.yml`.
- Definition of Done:
  - [ ] The workflow runs green on the PR head (check-run evidence).
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: if the push of workflow files is refused by permissions, log it in BLOCKERS with the file ready, and keep local checks as the gate.
- Log:

### WP-034 Technical spikes
- Phase / Milestone: 3 / —
- Tier: M
- Status: TODO
- Depends on: WP-032
- Goal: Prove, or disprove, the four risky mechanics before content depends on them (D-008, D-013, creatures.md §3).
- Inputs (read ONLY these): D-008; D-013; docs/VANILLA_ANALOGS.md W1/W4/E1; docs/DESIGN/bible/creatures.md §3.
- Deliverables: one GameTest per spike, on a `spike/` package that is deleted or promoted afterwards; a result line per spike in DECISIONS.md.
  1. **Weather mixin:** an extra level must not speed up the Overworld's weather.
  2. **Wade-through ichor:** a liquid block that slows and burns through `entityInside`, with no Entity mixin.
  3. **Basin controller:** one chunk's basin fills and drains from a logical tide state with bounded block updates per tick.
  4. **Blub stacking:** five entities riding each other, toppling without desync or suffocation.
- Definition of Done:
  - [ ] Each spike has a pass or fail GameTest, and a recorded result with its fallback if it failed.
- Iteration budget: fix hypotheses ≤ 5 per spike.
- Exit ramp: fall back as recorded (weather → `has_ceiling`; ichor → a vanilla-like fluid; basins → static pools; stacking → dropped to M4).
- Log:

## Phase 4 — M1 vertical slice (WPs specified at Phase 2 exit)
Minimum per mission: entry and return, one area with its own terrain, a small block set with final art, one mob finished, the Tide cycle in core form, entry advancements. Every WP follows the §5.4 ladder for its type.

### WP-040 Dimension skeleton and Tide core
- Phase / Milestone: 4 / M1
- Tier: L
- Status: TODO
- Depends on: WP-033, WP-034
- Goal: The `thesift:the_sift` dimension exists and behaves per rules.md: the Tide clock and timeline, the scope and rate attributes, no weather, beds, sun and moon parked.
- Inputs (read ONLY these): docs/DESIGN/vision/rules.md; docs/DESIGN/vision/systems.md §1; docs/VANILLA_ANALOGS.md W1/W4; D-008, D-011, D-013.
- Deliverables:
  - dimension type, a placeholder noise, a single-biome source;
  - `world_clock` + `timeline` (Thrive/Flow/Endure markers; light, sky, fog, stars, particles);
  - registered attributes `sift_life`, `soul_flow`, `tide`;
  - the weather mixin;
  - bed rules and the Endure rest;
  - the clock paused until the first crossing (a flag in SavedData);
  - GameTests.
- Definition of Done:
  - [ ] GameTests: `canHaveWeather` is false in the Sift and the Overworld's weather timers advance once per tick; `sift_life` is true in the Sift and false in the Overworld; beds refuse sleep; the clock is paused before the first crossing.
  - [ ] Server boots; `/execute in thesift:the_sift` works; zero `thesift` warnings.
  - [ ] A headless screenshot of the Sift sky in Thrive and in Endure, looked at, in docs/previews/.
- Iteration budget: fix hypotheses ≤ 5; self-review of the diff 1 round.
- Exit ramp: if the mixin conflicts, fall back to `has_ceiling` only after a new decision record.
- Log:

### WP-041 Art pipeline and block set I art
- Phase / Milestone: 4 / M1
- Tier: L
- Status: TODO
- Depends on: WP-040
- Goal: Original 16×16 textures, in vanilla style, for block set I: hymnstone, hymnstone bricks, healthy sculk (top and side), healthy-sculk grass (short and tall), songwood log (side and top), planks, leaves, gatestone, membrane.
- Inputs (read ONLY these): docs/DESIGN/bible/world.md §3; mission §7.4; the vanilla textures of neighbouring blocks (for palette comparison only, never copied).
- Deliverables: `tools/art/` generator scripts (ARR per D-003); the textures; `docs/previews/` sheets (tiled 3×3, beside vanilla neighbours, the palette).
- Definition of Done:
  - [ ] Every texture was generated from our own scripts or drawn pixel by pixel. Nothing is traced or copied (hard rule 9.1).
  - [ ] Previews rendered **and looked at**; each is critiqued against §7.4, with the notes in the log.
  - [ ] ≤3 revision rounds; the final previews are saved.
- Iteration budget: revision rounds ≤ 3 per texture.
- Exit ramp: a simpler, cleaner texture that still reads correctly beside vanilla.
- Log:

### WP-042 Block set I and the Singer's Meadow terrain
- Phase / Milestone: 4 / M1
- Tier: L
- Status: TODO
- Depends on: WP-041
- Goal: Register block set I (stairs, slabs and walls where the family calls for them), and generate Singer's Meadow terrain with these blocks: noise, material rules, songwood trees, grass.
- Inputs (read ONLY these): docs/DESIGN/bible/world.md §1–3; docs/VANILLA_ANALOGS.md W2/W3/W7; the WP-031 datagen code.
- Deliverables: block registrations; datagen for models, blockstates, loot, tags, recipes, lang; noise settings + material rules + biome + tree and grass features; GameTests for block behaviour; terrain screenshots.
- Definition of Done:
  - [ ] Each block has its model, loot, tags, lang, sound type and recipe (where craftable). A test covers each block with behaviour.
  - [ ] Terrain generates on a dedicated server without warnings; a headless screenshot of the Meadow, looked at.
  - [ ] Datagen no-diff; build green.
- Iteration budget: fix hypotheses ≤ 5; terrain tuning passes ≤ 3.
- Exit ramp: simpler noise (the overworld router with biome-level blocks) if custom density functions misbehave.
- Log:

### WP-043 Audio pipeline and the entry and Tide sounds
- Phase / Milestone: 4 / M1
- Tier: M
- Status: TODO
- Depends on: WP-040
- Goal: Original synthesized sounds (ogg), with subtitles, for the frame, the offering stream, the membrane, Tide transitions, and the Meadow's ambient loop and mood sounds.
- Inputs (read ONLY these): mission §7.5; docs/DESIGN/vision/entry_path.md; docs/DESIGN/bible/items.md §5.
- Deliverables: `tools/audio/` synthesis scripts (ARR); `.ogg` files; `sounds.json` via datagen; subtitles; loudness notes against vanilla.
- Definition of Done:
  - [ ] Every sound is synthesized by our scripts. No samples from Mojang or any game.
  - [ ] Peak and RMS loudness measured next to comparable vanilla sounds (numbers in the log).
  - [ ] Every sound event has a subtitle.
- Iteration budget: revision rounds ≤ 3 per sound.
- Exit ramp: simpler tones; a HUMAN_ASSET_BRIEFS entry for anything a human could do meaningfully better.
- Log:

### WP-044 Entry I: frames, offering, waking, music
- Phase / Milestone: 4 / M1
- Tier: L
- Status: TODO
- Depends on: WP-042, WP-043
- Goal: Ancient City frames are found (from structure starts, no scans), breathe souls, notice players, accept deliberate offerings, wake in steps, and listen for music.
- Inputs (read ONLY these): docs/DESIGN/vision/entry_path.md; D-010; docs/VANILLA_ANALOGS.md W5/W6/E4/P2.
- Deliverables: frame locator + SavedData (charge per frame); the use-hook offering; awake stages (visual + sound); the vibration listener and jukebox listener; GameTests.
- Definition of Done:
  - [ ] GameTests: a frame template is recognised; holding *use* transfers XP at the set rate and stops on release; standing or crouching takes nothing; the charge persists across a reload; a note block and a jukebox each open an awake frame.
  - [ ] No per-tick scanning (code review note in the log).
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: frame detection from placed blocks near structure centres, if structure-start access fails.
- Log:

### WP-045 Entry II: membrane, crossing, Sift-side gate, return
- Phase / Milestone: 4 / M1
- Tier: L
- Status: TODO
- Depends on: WP-044
- Goal: The membrane portal (with the entity filter) takes players to a generated Sift-side gate (bounded search, fallback, explicit link, sanctuary) and back. The first crossing starts the Tide clock.
- Inputs (read ONLY these): docs/DESIGN/vision/entry_path.md; docs/VANILLA_ANALOGS.md W5; D-010, D-013.
- Deliverables: portal block, gatestone, gate feature, link SavedData, sanctuary spawn rule, return path, GameTests.
- Definition of Done:
  - [ ] GameTests: crossing both ways; the link survives a reload; wardens are refused; gates ≥64 blocks apart; the clock starts at the first crossing.
  - [ ] Manual headless run: enter and return, screenshots looked at.
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: a fixed-offset arrival (no biome search) if the search is too slow.
- Log:

### WP-046 Blub design doc
- Phase / Milestone: 4 / M1
- Tier: L (design)
- Status: TODO
- Depends on: WP-021
- Goal: docs/DESIGN/mob_blub.md with the full §8.1 template, via the design ladder (≥8 concepts, rubric, critique ≤3).
- Inputs (read ONLY these): docs/DESIGN/bible/creatures.md; docs/RESEARCH_BESTIARY.md (Blub row); docs/VANILLA_ANALOGS.md E1/E2/E5.
- Deliverables: mob_blub.md (frozen); BALANCE.md rows.
- Constraint: the M1 Blub is complete with M1 content alone (befriending and treats use only what M1 ships). Its ichor bathing and tidewrack treats are listed as M2 additions.
- Definition of Done:
  - [ ] All template sections filled, with stats beside vanilla analogs.
  - [ ] Critique passed (fresh reviewer) or the cap applied; frozen.
- Iteration budget: critique ≤ 3 rounds.
- Exit ramp: cut stacking to M4 if the spike fails, and record it.
- Log:

### WP-047 Blub art: texture, model, animations
- Phase / Milestone: 4 / M1
- Tier: L
- Status: TODO
- Depends on: WP-046, WP-041
- Goal: The Blub's model (Java code model), texture and keyframe animations (walk, idle, squeak, dance, stack), matching the vanilla first look (V).
- Inputs (read ONLY these): mob_blub.md; docs/VANILLA_ANALOGS.md E5; mission §7.4.
- Deliverables: model and animation classes; texture; turntable and animation previews (headless screenshots).
- Definition of Done:
  - [ ] Previews looked at and critiqued; ≤3 rounds; final previews saved.
- Iteration budget: revision rounds ≤ 3.
- Exit ramp: fewer animation states (walk and idle) with the others as simple poses.
- Log:

### WP-048 Blub audio
- Phase / Milestone: 4 / M1
- Tier: M
- Status: TODO
- Depends on: WP-043, WP-046
- Goal: Original synthesized squeak, hop or step, happy and hurt sounds for the Blub, with subtitles.
- Inputs (read ONLY these): mob_blub.md; tools/audio/; mission §7.5.
- Deliverables: sounds, sound events, subtitles, loudness notes.
- Definition of Done:
  - [ ] Synthesized, measured next to the rabbit's and allay's sounds; subtitles present.
- Iteration budget: revision rounds ≤ 3.
- Exit ramp: fewer variants per sound.
- Log:

### WP-049 Blub entity: AI and tests
- Phase / Milestone: 4 / M1
- Tier: L
- Status: TODO
- Depends on: WP-047, WP-048
- Goal: The Blub spawns in the Meadow, roams, squeaks, gathers to music, stacks (per the design and the WP-034 result), shelters in Endure, and is befriendable per mob_blub.md.
- Inputs (read ONLY these): mob_blub.md; docs/VANILLA_ANALOGS.md E1/E2/E4; the WP-044 listener code.
- Deliverables: entity type, attributes, brain or goals, spawning, renderer hookup, GameTests.
- Definition of Done:
  - [ ] GameTests for each behaviour in mob_blub.md; the server boots with blubs spawning; no warnings.
  - [ ] Headless screenshots of blubs in the Meadow, looked at.
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: goal-selector AI instead of Brain if Brain costs too much.
- Log:

### WP-050 Entry advancements and lang pass
- Phase / Milestone: 4 / M1
- Tier: S
- Status: TODO
- Depends on: WP-045
- Goal: The Sift advancement tab (root, An Offering, The Tide Turns) and a lang pass over everything in M1.
- Inputs (read ONLY these): docs/DESIGN/bible/items.md §4; mission §7.6.
- Deliverables: advancements via datagen; triggers; en_us lang reviewed.
- Definition of Done:
  - [ ] GameTests or scripted triggers grant each advancement.
  - [ ] Lang proofread (vanilla's voice; no typos; subtitles present).
- Iteration budget: 1 round.
- Exit ramp: vanilla trigger types only.
- Log:

### WP-051 M1 integration and Gate C (self-review)
- Phase / Milestone: 4 / M1
- Tier: M
- Status: TODO
- Depends on: WP-040..050
- Goal: Everything works together: an integration pass, balance, performance, PLAYTEST.md, the jar, tag `v0.1.0-alpha`, and the Gate C self-review.
- Inputs (read ONLY these): STATUS.md; PLAN.md M1 section; PLAYTEST.md.
- Deliverables: PLAYTEST.md (Gate C); the built jar; the tag; the Gate C summary in STATUS.md.
- Definition of Done:
  - [ ] Build, datagen no-diff, and all GameTests green; the dedicated server boots with zero `thesift` warnings.
  - [ ] A headless walkthrough (enter, look around, return), screenshots looked at.
  - [ ] Tag pushed; Gate C self-review written.
- Iteration budget: fix rounds ≤ 3.
- Exit ramp: ship M1 with known issues logged in BLOCKERS if they don't break the slice.
- Log:

## Later (coarse; detailed when each milestone starts)
- M2 — the tide and the hunt · M3 — the occupation · M4 — the Meadow's life · M5 — the heart of the blight (see 01_CONTENT_BIBLE.md §3).
- Phases 6–8: polish, hardening, release (mission §6).
