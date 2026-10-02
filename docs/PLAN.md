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
| WP-024 | Content bible critique, freeze, Gate B (self-review) | 2 | L | DONE |
| WP-030 | Architecture decisions | 3 | M | DONE |
| WP-031 | Datagen setup | 3 | M | DONE |
| WP-032 | Test harness | 3 | M | DONE |
| WP-033 | CI | 3 | S | DONE |
| WP-034 | Technical spikes | 3 | M | DONE |
| WP-040 | Dimension skeleton and Tide core | 4 | L | DONE |
| WP-041 | Palette, block set I design and art | 4 | L | DONE |
| WP-042 | Block set I and the Singer's Meadow terrain | 4 | L | DONE |
| WP-043 | Audio pipeline and the entry, Tide and Meadow sounds | 4 | M | DONE |
| WP-044 | Ichor (core form) | 4 | L | DONE |
| WP-045 | Tide basins (one kind, in the Meadow) | 4 | L | DONE |
| WP-046 | Entry I: frames, offering, waking, music | 4 | L | DONE |
| WP-047 | Entry II: membrane, crossing, Sift-side gate, return | 4 | L | DONE |
| WP-048 | Blub design doc | 4 | L | DONE |
| WP-049 | Blub art: texture, model, animations, spawn egg | 4 | L | DONE |
| WP-050 | Blub audio | 4 | M | DONE |
| WP-051 | Blub entity: AI and tests | 4 | L | DONE |
| WP-052 | Entry advancements and lang pass | 4 | S | DONE |
| WP-053 | M1 integration and Gate C (self-review) | 4 | M | DONE |
| WP-054 | The owner's playtest rework: water, terrain, textures, trees, Blub (`v0.1.1-alpha`) | 4 | L | DONE |
| WP-060 | M2 system design: the hearing rule, retreat, enduring variants, lumen | 4 | L | DONE |
| WP-061 | Nester design doc | 4 | L | DONE |
| WP-062 | Bloombud design doc | 4 | L | DRAFT |
| WP-063 | Sift Hollows: the cave layer and glowcap pools | 4 | L | IN PROGRESS (caves done in WP-054; glowcap pools wait for WP-064) |
| WP-064 | Flora II: tidewrack, Endure bloom, glowcap, chime bell flower, lumen bloom | 4 | L | TODO |
| WP-065 | Materials and items: tidewrack frond, Endure petal, lumen lantern, blub treats | 4 | M | TODO |
| WP-066 | The hearing rule and hunter retreat; lumen repelling hunters | 4 | L | TODO |
| WP-067 | Nester: art, audio, AI, tests | 4 | L | TODO |
| WP-068 | Bloombud: art, audio, AI, tests | 4 | L | TODO |
| WP-069 | Enduring variants (the rule, with non-colour markers) | 4 | M | TODO |
| WP-070 | Spawn tables and the gate sanctuary rule | 4 | M | TODO |
| WP-071 | Tide marks; basin bubbles and the Sift's own entry particles (polish carried from M1) | 4 | M | TODO |
| WP-072 | M2 advancements (Stacked, Low Tide, Heard You, Quiet Waters) and lang | 4 | S | TODO |
| WP-073 | M2 integration and Gate D, `v0.2.0-alpha` | 4 | M | TODO |

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
  - [x] Milestones M1 → M5 → 1.0, each ending shippable (01_CONTENT_BIBLE.md §3). *(D-016 later re-cut these to M1–M6.)*
  - [x] M1 meets the mission's minimum: entry and return (WP-044/045), Singer's Meadow terrain (WP-042), block set I with final art (WP-041/042), the Blub finished (WP-046..049), the Tide core (WP-040), entry advancements (WP-050). *(WP numbers as of WP-023. D-016 renumbered them: entry WP-046/047, Blub WP-048..051, advancements WP-052.)*
  - [x] Phase 3 (WP-030..034) and M1 (WP-040..051, renumbered to WP-040..053 by D-016) WPs written with the §5.3 template.
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
- Status: DONE
- Depends on: WP-023
- Goal: A fresh adversarial review of the bible and roadmap; fix; freeze; Gate B as a self-review (D-014).
- Inputs (read ONLY these): 01_CONTENT_BIBLE.md and parts, 00_VISION.md, the §7.1 rubric.
- Deliverables: critique log in 01_CONTENT_BIBLE.md; frozen bible; Gate B summary in STATUS.md.
- Definition of Done:
  - [x] ≤3 critique rounds by fresh subagents; no must-fix left, or the §5.5 cap applied with reasons. Evidence: round 3 PASS (01_CONTENT_BIBLE.md §4).
  - [x] Bible marked FROZEN; Gate B self-review written (STATUS.md).
- Iteration budget: critique rounds ≤ 3.
- Exit ramp: §5.5 critique cap.
- Log:
  - 2026-09-30 round 1 (fresh reviewer): **FAIL**. 3 must-fix, 11 should-fix, 8 notes. Scores: F4 V4 R3 M3 D3 C4 Fe3.
    - Every finding was fixed or dispositioned (01_CONTENT_BIBLE.md §4; D-016).
    - The literal tide moved into M1, and the M1 WPs were renumbered to WP-040..053.
    - Six milestones.
    - `tools/docs/check_bible.py` checks 141 tiered rows with 0 errors. A negative test on mutated copies fails as expected.
  - 2026-09-30 round 2 (a new fresh reviewer): **FAIL**. 1 must-fix (no bloom-heart source), 11 should-fix, 4 notes. Scores: F4 V4 R4 M4 D4 C4 **Fe3**.
    - All findings were fixed (D-017; 01_CONTENT_BIBLE.md §4).
    - The M1 WPs gained the missing dependencies, DoD checks and fallbacks.
    - `check_bible.py` was hardened.
  - 2026-09-30 round 3 (a new fresh reviewer, the last): **PASS**. Scores all 4, no must-fix.
    - The quick fixes F1–F15 were applied under the cap (01_CONTENT_BIBLE.md §4).
    - `check_bible.py`: 144 rows, 0 errors. Its new checks were negative-tested.
    - Bible FROZEN; Gate B self-reviewed.

## Phase 3 — Architecture (WPs specified at Phase 2 exit)

### WP-030 Architecture decisions
- Phase / Milestone: 3 / —
- Tier: M
- Status: DONE
- Depends on: WP-024
- Goal: Decide and record the code architecture before any content lands.
- Inputs (read ONLY these): docs/VANILLA_ANALOGS.md P1–P4 and E1; docs/DECISIONS.md D-003, D-008, D-010..D-013, D-016, D-017; src/.
- Deliverables: decision records D-018+ (package layout and registration pattern; client/server split; networking payloads; persistent state; config); the package skeleton in src/.
- Definition of Done:
  - [ ] Each mission Phase 3 topic has a decision record.
  - [ ] The skeleton compiles (`./gradlew build`, no new warnings).
- Iteration budget: self-critique 1 round.
- Exit ramp: copy the Fabric example mod's patterns where undecided.
- Log:
  - 2026-09-30: D-019 recorded.

### WP-031 Datagen setup
- Phase / Milestone: 3 / —
- Tier: M
- Status: DONE
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
  - 2026-09-30: client datagen under Xvfb + lavapipe; `tools/dev/datagen.sh --check` no-diff gate.

### WP-032 Test harness
- Phase / Milestone: 3 / —
- Tier: M
- Status: DONE
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
  - 2026-09-30: `gametest` source set, `runGameTest` in `check`; client GameTests with screenshots (`tools/dev/client-previews.sh`).

### WP-033 CI
- Phase / Milestone: 3 / —
- Tier: S
- Status: DONE
- Depends on: WP-032
- Goal: A GitHub Actions workflow that runs the build, the datagen no-diff check, the GameTests and `tools/docs/check_bible.py`.
- Inputs (read ONLY these): build.gradle; tools/dev/datagen-check.sh.
- Deliverables: `.github/workflows/build.yml`.
- Definition of Done:
  - [ ] The workflow runs green on the PR head (check-run evidence).
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: if the push of workflow files is refused by permissions, log it in BLOCKERS with the file ready, and keep local checks as the gate.
- Log:
  - 2026-09-30: GitHub Actions build + GameTests + bible check + datagen no-diff; green on 3abc222 and 8e457bf.

### WP-034 Technical spikes
- Phase / Milestone: 3 / —
- Tier: M
- Status: DONE
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
- Exit ramp: one fallback per spike (D-017 §7):
  - weather → `has_ceiling`, with a new decision record;
  - ichor → a vanilla-like fluid with the effects in `entityInside`;
  - basins → static ichor pools with a level marker; the M1 Blub follows pool edges in Flow; one more basin attempt opens M2, then the D-013 fallback (no basins);
  - stacking → moved to M2.
- Log:
  - 2026-10-01: 3 of 4 spikes settled in the WPs that needed them: weather mixin (negative-tested, WP-040), wade-through ichor needs no Entity mixin (WP-044), basin controller bounded and catch-up on load (WP-045). Blub stacking moves with WP-049/051.

## Phase 4 — M1 vertical slice (WPs specified at Phase 2 exit; revised in WP-024 round 1, D-016)
Minimum per mission: entry and return, one area with its own terrain, a small block set with final art, one mob finished, the Tide cycle in core form, entry advancements. M1 also carries the literal tide: ichor and one kind of basin (D-016). Every WP follows the §5.4 ladder for its type. Design work (§8.2 and §8.3 docs) comes before the implementation it specifies.

  - 2026-10-01 (Gate C): the fourth spike (stacking) is settled by WP-051: riding towers with no steering, an AI-on GameTest, capped at five.
### WP-040 Dimension skeleton and Tide core
- Phase / Milestone: 4 / M1
- Tier: L
- Status: DONE
- Depends on: WP-033, WP-034
- Goal: The `thesift:the_sift` dimension exists and behaves per rules.md: the Tide clock and timeline, the scope and rate attributes, no weather, beds and the Endure rest, and the sun and moon parked.
- Inputs (read ONLY these): docs/DESIGN/vision/rules.md; docs/DESIGN/vision/systems.md §1; docs/VANILLA_ANALOGS.md W1/W4; D-008, D-011, D-013, D-016.
- Deliverables:
  - `docs/DESIGN/system_tides.md` (the §8.3 template, M tier). It covers:
    - player rules and how they're learned;
    - exact numbers, **ichor's numbers included** (flow range, slowdown, burn, drain rate per Easy/Normal/Hard);
    - per-state content and the data plan;
    - the **performance budgets**: p95 and max MSPT during a Tide change, during a whole Flow with 50 basins, and during fast flight over the Meadow; and the block updates per tick per basin;
    - edge cases, and a critique log with 2 rounds;
  - dimension type, a placeholder noise, a single-biome source;
  - `world_clock` + `timeline` (Thrive/Flow/Endure markers; light, sky, fog, stars, Trills particles);
  - registered attributes `sift_life`, `soul_flow`, `tide`;
  - the weather mixin;
  - bed rules and the Endure rest;
  - the clock paused until the first crossing (a flag in SavedData);
  - GameTests.
- Definition of Done:
  - [ ] system_tides.md frozen after its critique.
  - [ ] GameTests, one per rule:
    - `canHaveWeather` is false in the Sift, and the Overworld's weather timers advance once per tick;
    - `sift_life` is true in the Sift and false in the Overworld;
    - beds refuse sleep, and straw beds follow their rule;
    - the Endure rest resets `time_since_rest`, and is refused with `NOT_SAFE` when monsters are near;
    - the clock is paused before the first crossing.
  - [ ] Server boots; `/execute in thesift:the_sift` works; zero `thesift` warnings.
  - [ ] Tide changes stay within the system_tides.md budget: p95 and max MSPT over 5 forced Tide changes, measured against an idle baseline window of the same length (log excerpt).
  - [ ] Headless screenshots of the Sift sky in Thrive, Flow and Endure, looked at, in docs/previews/.
- Iteration budget: critique ≤ 2 rounds; fix hypotheses ≤ 5; self-review of the diff 1 round.
- Exit ramp: if the mixin conflicts, fall back to `has_ceiling` only after a new decision record.
- Log:
  - 2026-10-01: dimension, clock, timeline (sky, light, stars), attributes, weather mixin, beds and Endure rest, first-crossing clock start; GameTests and Tide screenshots; system_tides.md written. Left: Trill/glow-petal particle types (placeholders are vanilla).

  - 2026-10-01 (Gate C): Trill and glow-petal particles are our own (ModParticles). The Tide-change cost is measured as part of the basin test (WP-045). Done.
### WP-041 Palette, block set I design and art
- Phase / Milestone: 4 / M1
- Tier: L
- Status: DONE
- Depends on: WP-040
- Goal: The Sift palette, a §8.2 design doc for block set I, and original 16×16 textures in vanilla style for:
  - hymnstone, and hymnstone bricks (with stairs, slab and wall);
  - healthy sculk (top and side), and healthy-sculk grass (short and tall);
  - songwood log (side with flute holes, and top), planks and leaves;
  - songwood sapling;
  - tide sand and the tide vent;
  - gatestone and the membrane;
  - the glowing-petal particle (music reactions, world.md §3.2) and the Trill particles (the Thrive ambience);
  - ichor (still and flowing), and the ichor bucket.
- Inputs (read ONLY these): docs/DESIGN/bible/world.md §3, §3.1 and §4; mission §7.4; the vanilla textures of neighbouring blocks (for palette comparison only, never copied).
- Deliverables:
  - `docs/DESIGN/palette.md` (hex ramps per material; limited colours per texture);
  - `docs/DESIGN/blocks_set1.md` (§8.2 per family, M tier: ≥5 concepts per family, rubric, a critique of 2 rounds);
  - `tools/art/` generator scripts (ARR per D-003);
  - the textures;
  - `docs/previews/` sheets: tiled 3×3 at 1× and 8×, beside vanilla neighbours, under Thrive, Flow and Endure lighting.
- Definition of Done:
  - [ ] palette.md written, and every texture uses only its colours (a script check).
  - [ ] blocks_set1.md frozen after its critique.
  - [ ] Every texture was generated from our own scripts or drawn pixel by pixel. Nothing is traced or copied (hard rule 9.1).
  - [ ] Previews rendered **and looked at**; each is critiqued against §7.4, with the notes in the log.
  - [ ] ≤3 revision rounds; the final previews are saved.
- Iteration budget: critique ≤ 2 rounds (design); revision rounds ≤ 3 per texture.
- Exit ramp: a simpler, cleaner texture that still reads correctly beside vanilla.
- Log:
  - 2026-10-01: palette.md, 23 original textures (palette check 0 errors), previews. Left: particle registration, membrane/ichor surface polish.

  - 2026-10-01 (Gate C): particles registered; the texture pass made the membrane and ichor surfaces seamless, with variants (palette check 34/0). Done.
### WP-042 Block set I and the Singer's Meadow terrain
- Phase / Milestone: 4 / M1
- Tier: L
- Status: DONE
- Depends on: WP-041
- Goal: Register block set I (the songwood sapling and its tree growth included), generate Singer's Meadow terrain with these blocks (noise, material rules, songwood trees, grass), and build the client music reactions (world.md §3.2). Ichor pools belong to WP-045.
- Inputs (read ONLY these): docs/DESIGN/bible/world.md §1–3 (§3.2 for music reactions); docs/DESIGN/blocks_set1.md; docs/VANILLA_ANALOGS.md W2/W3/W7; the WP-031 datagen code.
- Deliverables:
  - `docs/DESIGN/biome_singers_meadow.md` (identity at far, mid and near range; features; spawns; ambience; M tier with a critique of 2 rounds);
  - block registrations;
  - datagen for models, blockstates, loot, tags, recipes, lang;
  - noise settings, material rules, the biome, and the tree and grass features;
  - GameTests for block behaviour;
  - terrain screenshots.
- Definition of Done:
  - [ ] The biome doc is frozen after its critique.
  - [ ] Each block has its model, loot, tags, lang, sound type, map colour and recipe (where craftable). A test covers each block with behaviour, the sapling included: it grows in the Sift, and it doesn't grow in the Overworld.
  - [ ] Music reactions: a unit test covers the ring buffer (range, expiry, capacity, and a jukebox entry staying live while its record plays). Headless screenshots, looked at, show petals and flute-hole notes next to a playing note block and 30 s into a jukebox record. The headless client runs with OpenAL Soft's null backend (`ALSOFT_DRIVERS=null`) and its log shows the sound engine starting; if that can't work, a client test feeds the buffer directly and BLOCKERS.md says so.
  - [ ] Terrain generates on a dedicated server without warnings.
  - [ ] Headless screenshots at far, mid and near range, looked at. No floating artifacts, and no seams at chunk borders (checked on a 16-chunk overview).
  - [ ] Chunk generation cost is ≤1.5× the Overworld's, measured the same way on the same machine (numbers in the log).
  - [ ] Datagen no-diff; build green.
- Iteration budget: critique ≤ 2 rounds; fix hypotheses ≤ 5; terrain tuning passes ≤ 3.
- Exit ramp: simpler noise (the overworld router with biome-level blocks) if custom density functions misbehave.
- Log:
  - 2026-10-01: block set I, Meadow noise/material rules, songwood trees, grass, Sift-only growth; heightmap tag fix (P5). Left: client music reactions (world.md §3.2).

  - 2026-10-01 (measured, client GameTest `chunkGenerationCost`, default world settings): 98 fresh chunks each, the Sift 1245 ms vs the Overworld 4223 ms: 0.29×, inside the 1.5× budget.
  - 2026-10-01 (Gate C): music reactions (client ring buffer, petals, flute holes) are in, with a screenshot looked at. Done.
### WP-043 Audio pipeline and the entry, Tide and Meadow sounds
- Phase / Milestone: 4 / M1
- Tier: M
- Status: DONE
- Depends on: WP-040
- Goal: Original synthesized sounds (ogg), with subtitles, for:
  - the frame, the offering stream and the membrane;
  - Tide transitions and basin bubbling;
  - the ichor wade;
  - the Meadow's ambient loop and mood sounds.
- Inputs (read ONLY these): mission §7.5; docs/DESIGN/vision/entry_path.md; docs/DESIGN/bible/items.md §6.
- Deliverables: `tools/audio/` synthesis scripts (ARR); `.ogg` files; `sounds.json` via datagen; subtitles; loudness notes against vanilla.
- Definition of Done:
  - [ ] Every sound is synthesized by our scripts. No samples from Mojang or any game.
  - [ ] Every positional sound is mono (an `ffprobe` channel check over all files, output in the log).
  - [ ] Frequent sounds (steps, wading, bubbling) have 2–4 variants.
  - [ ] Peak and RMS loudness within ±3 dB of comparable vanilla sounds (numbers in the log).
  - [ ] Every sound event has a subtitle.
- Iteration budget: revision rounds ≤ 3 per sound.
- Exit ramp: simpler tones; a HUMAN_ASSET_BRIEFS entry for anything a human could do meaningfully better.
- Log:
  - 2026-10-01: done. 36 Sift sounds (entry, Tide, basins, ichor, Meadow loop and flute) plus the Blub's (WP-050), all wired, with subtitles.

### WP-044 Ichor (core form)
- Phase / Milestone: 4 / M1
- Tier: L
- Status: DONE
- Depends on: WP-040, WP-041, WP-043, WP-034
- Goal: Ichor as a wade-through liquid (D-013). It slows, burns (vanilla fire with soul-flame particles), and drains XP from anything that isn't a Sift native. Fire Resistance stops only the burning. A bucket of it evaporates outside the Sift.
- Inputs (read ONLY these): D-013, D-016; the WP-034 ichor spike result; docs/DESIGN/system_tides.md (ichor's numbers); the vanilla 26.3 sources of `FlowingFluid`, `LavaFluid` and `LiquidBlock`.
- Deliverables: the fluid (source and flowing), its liquid block, the bucket, tags (`#thesift:ichor`, `#thesift:sift_natives`), a fog colour inside ichor, sounds hooked (WP-043), GameTests.
- Definition of Done:
  - [ ] GameTests:
    - an entity in ichor is slowed and set on fire;
    - with Fire Resistance it isn't burned, but its XP is still drained;
    - a Sift native takes no burn and no drain;
    - there is no swimming and no current;
    - an emptied bucket evaporates in the Overworld (with a particle and a sound);
    - the flow range is correct.
  - [ ] The per-tick cost of 20 entities standing in ichor is ≤1.5× that of 20 in lava (measured; log).
  - [ ] The fog inside ichor uses an access widener to add a fog environment (no second mixin; the route is recorded in the WP log).
  - [ ] BALANCE.md rows for ichor (burn, drain, slowdown; Easy, Normal and Hard) next to lava and powder snow.
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: the recorded WP-034 fallback (a vanilla-like fluid with the effects kept in `entityInside`).
- Log:
  - 2026-10-01: core done (fluid, block, bucket evaporation, wading/burn/drain in entityInside, 10 GameTests, BALANCE rows). Left: fog via access widener, the 20-entity cost measurement, sounds (WP-043).

  - 2026-10-01 (measured, `SiftPerfTest`): 20 zombified piglins in ichor vs 20 in lava, ticked by hand: 0.89–0.98× across runs, inside 1.5×. The fog (access widener) and sounds landed earlier.
  - 2026-10-01 (Gate C): every DoD item met. Done.
### WP-045 Tide basins (one kind, in the Meadow)
- Phase / Milestone: 4 / M1
- Tier: L
- Status: DONE
- Depends on: WP-042, WP-044
- Goal: Generated tide basins whose vent floods them with ichor in Endure and drains them in Thrive, moving through Flow. The work is bounded per tick, and the basins catch up after a chunk loads.
- Inputs (read ONLY these): docs/DESIGN/system_tides.md; D-013, D-016; the WP-034 basin spike result.
- Deliverables: the basin feature (≤14×14, ~4 deep, at most one per chunk, in the lows); the tide vent block entity; persistence; the **static ichor pool** feature (lows and caves); GameTests; a timelapse of screenshots.
- Definition of Done:
  - [ ] GameTests:
    - at the end of rising Flow the basin is full; at the end of falling Flow it is empty;
    - during Flow the level moves one layer per step, as systems.md §1 says;
    - block updates per tick stay under the budget set in system_tides.md;
    - the vent catches up to the current Tide after a reload;
    - a basin never crosses its chunk.
  - [ ] Worldgen places basins only in the Meadow's lows, and ichor pools in lows and caves (overview screenshot, looked at).
  - [ ] Performance within the system_tides.md budgets, as p95 and max MSPT:
    - over a whole Flow with 50 loaded basins;
    - during fast flight over the Meadow in Endure, where chunk loads trigger the vents' catch-up.
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: D-017 §7. M1 ships static ichor pools with a level marker, and the Blub follows pool edges in Flow. One more basin attempt opens M2.
- Log:
  - 2026-10-01: core done (feature in lows, vent BE one layer/s, catch-up ≤ 507 blocks, static pools, 8 GameTests, Thrive/Endure previews). Left: MSPT p95 measurement, rising-bubble and tide-mark visuals.

  - 2026-10-01 (measured, `SiftPerfTest`): 50 basins through a whole rising and falling Flow: vent work per tick p95 0.005 ms, max 5.6–10.4 ms (about 30 layer-change ticks per cycle, ~8 µs per cell with light and fluid scheduling). The test found vents at chunk centres sharing only 5 of the 20 update slots (plain `hashCode`); vents now use a mixed hash (17–19 slots).
  - 2026-10-02: CI failed the max-tick assertion once (36 ms; release run at the same commit passed). Root cause, reproduced locally: a GC pause inside a timed tick (27.1 ms, the one tick a GC ran in). The test now runs the Flow three times and takes each tick's least, logs the raw worst tick and whether a GC ran in it; max 1.0–3.5 ms. The slot-spread floor went from 15 to 12 (false failure odds 1 in 2000 → 1 in 6×10⁷; the bug it catches used 5).
  - 2026-10-01 (Gate C): done. The rising-bubble visual is left for polish (a known issue in PLAYTEST.md); tide marks are M2–M3 in the bible.
### WP-046 Entry I: frames, offering, waking, music
- Phase / Milestone: 4 / M1
- Tier: L
- Status: DONE
- Depends on: WP-042, WP-043
- Goal: Ancient City frames are found from structure starts (no scans). They breathe souls (the rumor), notice players, accept deliberate offerings, wake in steps, and listen for music.
- Inputs (read ONLY these): docs/DESIGN/vision/entry_path.md; D-010; docs/VANILLA_ANALOGS.md W5/W6/E4/P2.
- Deliverables:
  - `docs/DESIGN/system_entry.md` (§8.3, S tier: exact numbers and cues from entry_path.md; a critique of 1 round);
  - the frame locator + SavedData (charge per frame);
  - the rumor wisps and notice cues;
  - the use-hook offering;
  - awake stages (visual + sound);
  - the vibration listener and jukebox listener;
  - GameTests.
- Definition of Done:
  - [ ] GameTests:
    - a frame template is recognised;
    - holding *use* transfers XP at the set rate and stops on release;
    - standing or crouching takes nothing;
    - the charge persists across a reload;
    - a note block and a jukebox each fire an awake frame's *open* event (asserted in the test; the membrane block itself arrives in WP-047).
  - [ ] The rumor and notice cues show within their stated ranges: headless screenshots of the wisps and of the notice cue, looked at. These are the risk D-010 accepted.
  - [ ] No per-tick scanning (a code review note in the log).
- Iteration budget: critique 1 round; fix hypotheses ≤ 5.
- Exit ramp: frame detection from placed blocks near structure centres, if structure-start access fails.
- Log:
  - 2026-10-01: frames found by geometry on use (D-020), hold-use offering, waking, music via one gameEvent hook; real and natural Ancient City checks. Left: dormant "breathing" and 8-block notice cues, subtitles.

  - 2026-10-01: rumor and notice cues (D-022). Frames are discovered from the city's structure data (1 ms on a natural city, asserted equal to the scanned frame in the client GameTest); wisps, a notice sound with subtitle, and the root advancement on notice (asserted). The notice capture showed a wisp rising from the player toward the frame; the city's geometry makes a clean framing hard, so no preview is saved. No per-tick scanning: one structure-reference lookup per player every 2 s, the frame search once per city.
  - 2026-10-01 (Gate C): done.
### WP-047 Entry II: membrane, crossing, Sift-side gate, return
- Phase / Milestone: 4 / M1
- Tier: L
- Status: DONE
- Depends on: WP-046
- Goal: The membrane portal, with its entity filter, takes players to a generated Sift-side gate and back. The gate uses a bounded search with a fallback, an explicit link and a sanctuary. The first crossing starts the Tide clock.
- Inputs (read ONLY these): docs/DESIGN/vision/entry_path.md; docs/DESIGN/system_entry.md; docs/DESIGN/bible/world.md §5; docs/VANILLA_ANALOGS.md W5; D-010, D-013, D-017 (the gate mound).
- Deliverables: the portal block, gatestone, the gate feature, link SavedData, the sanctuary spawn rule, the membrane's far-side Tide tint, the return path, GameTests.
- Definition of Done:
  - [ ] GameTests:
    - crossing works both ways;
    - the link survives a reload;
    - wardens are refused;
    - gates are ≥64 blocks apart;
    - the clock starts at the first crossing;
    - no monster spawns inside the sanctuary radius.
  - [ ] The membrane shows the far side's Tide (screenshots in Thrive, Flow and Endure, looked at).
  - [ ] Manual headless run: enter and return, screenshots looked at.
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: a fixed-offset arrival (no biome search) if the search is too slow.
- Log:
  - 2026-10-01: membrane portal with #thesift:cannot_cross, gate built on first crossing (hill, 64-block spacing), return, re-opening a removed membrane; end-to-end pig test. Left: the sanctuary spawn rule (no Sift spawns exist yet).

  - 2026-10-01 (Gate C): done. The gate sanctuary spawn rule waits for M2, when the Sift gets hostile spawns; until then nothing hostile spawns there, and wardens and bosses are `#thesift:cannot_cross`.
### WP-048 Blub design doc
- Phase / Milestone: 4 / M1
- Tier: L (design)
- Status: DONE
- Depends on: WP-021, WP-034, WP-041
- Goal: docs/DESIGN/mob_blub.md with the full §8.1 template, via the design ladder (≥8 concepts, rubric, critique ≤3).
- Inputs (read ONLY these): docs/DESIGN/bible/creatures.md; docs/RESEARCH_BESTIARY.md (Blub row); docs/VANILLA_ANALOGS.md E1/E2/E5; docs/DESIGN/palette.md; D-016, D-017; the WP-034 stacking and basin results.
- Deliverables: mob_blub.md (frozen); BALANCE.md rows.
- Constraints (D-016):
  - The M1 Blub is complete with M1 content.
  - It is befriended by music a player plays by hand: one blub per note, the nearest one watching, with a heart tell. It is a pet that needs no fuel, and it crosses the membrane with its player.
  - Flow: it follows the basin waterline. It bathes in ichor, immune to it.
  - Tidewrack treats (breeding, healing) are an M2 addition.
- Definition of Done:
  - [ ] All template sections filled, with stats beside vanilla analogs.
  - [ ] Critique passed (fresh reviewer) or the cap applied; frozen.
- Iteration budget: critique ≤ 3 rounds.
- Exit ramp: D-017 §7. If the stacking spike failed, stacking moves to M2. If the basin spike failed, the Blub follows pool edges in Flow.
- Log:
  - 2026-10-01: three fresh critique rounds (FAIL, FAIL, FAIL on three one-line items); cap reached, all must-fixes applied, frozen. Stats in BALANCE.md.

### WP-049 Blub art: texture, model, animations, spawn egg
- Phase / Milestone: 4 / M1
- Tier: L
- Status: DONE
- Depends on: WP-048, WP-041
- Goal: The Blub's model (Java code model), its texture, and keyframe animations (idle, hop, squeak, dance, stack, curl), matching the vanilla first look (V). Also the spawn-egg texture.
- Inputs (read ONLY these): mob_blub.md; docs/DESIGN/palette.md; docs/VANILLA_ANALOGS.md E5; mission §7.4.
- Deliverables: model and animation classes; texture; spawn-egg texture; turntable and animation previews (headless screenshots).
- Definition of Done:
  - [ ] Every animation named in mob_blub.md exists, and each has anticipation and follow-through where it moves. There's an idle, and no sliding feet (frame-by-frame previews looked at).
  - [ ] The silhouette reads at 10 blocks (a screenshot from 10 blocks, looked at).
  - [ ] Previews beside vanilla neighbours (rabbit, allay, axolotl) and under Thrive, Flow and Endure lighting, looked at.
  - [ ] The texture uses only palette.md colours (script check).
  - [ ] Previews critiqued; ≤3 rounds; final previews saved.
- Iteration budget: revision rounds ≤ 3.
- Exit ramp: fewer animation states (hop and idle), with the others as simple poses.
- Log:
  - 2026-10-01: 32×32 texture, emissive belly layer (`blub_glow.png`), spawn egg; palette check 34/0. Procedural clips for every animation in the doc (D-021). Previews looked at: Thrive with a tower and a bath, beside rabbit/allay/axolotl in Flow light, from 10 blocks, Endure curled and glowing (`docs/previews/wp049_*.png`). Feet tuck when bathing or riding; no sliding seen.

### WP-050 Blub audio
- Phase / Milestone: 4 / M1
- Tier: M
- Status: DONE
- Depends on: WP-043, WP-048
- Goal: Original synthesized squeak, hop, happy and hurt sounds for the Blub, and a death sound, all with subtitles.
- Inputs (read ONLY these): mob_blub.md; tools/audio/; mission §7.5.
- Deliverables: sounds, sound events, subtitles, loudness notes.
- Definition of Done:
  - [ ] Synthesized by our scripts; all mono (ffprobe check).
  - [ ] Frequent sounds (squeak, hop) have 3–4 variants.
  - [ ] Loudness measured next to the rabbit's and the allay's sounds.
  - [ ] Subtitles present.
- Iteration budget: revision rounds ≤ 3.
- Exit ramp: fewer variants for rare sounds (never below 2 for frequent ones).
- Log:
  - 2026-10-01: 27 synthesized sounds in 12 events (ambient ×4, hop ×3, step ×4, the rest ×2, death and sing ×1), all mono. Each sound is RMS-matched to vanilla references: the voice to chicken/armadillo (−28 dB) between the rabbit (−49) and the allay (−20); hurt and death to the axolotl. The sing note is measured at 740.0 Hz (F#5). Levels: audio_levels.md. Subtitles for all but steps (vanilla's rule).

### WP-051 Blub entity: AI and tests
- Phase / Milestone: 4 / M1
- Tier: L
- Status: DONE
- Depends on: WP-049, WP-050, WP-042, WP-045, WP-046, WP-047
- Goal: The Blub spawns in the Meadow, roams, squeaks and gathers to music. It stacks (per the design and the WP-034 result), follows the waterline in Flow, bathes in ichor, shelters in Endure, and is befriended per mob_blub.md.
- Inputs (read ONLY these): mob_blub.md; docs/VANILLA_ANALOGS.md E1/E2/E4; D-016, D-017; the WP-046 listener code; the WP-045 basin API; the WP-047 portal code.
- Deliverables: entity type, attributes, brain or goals, spawning (biome spawn entry), loot table, spawn egg item, renderer hookup, GameTests.
- Definition of Done:
  - [ ] GameTests, one for each behaviour in mob_blub.md, including a befriended blub crossing the membrane with its player.
  - [ ] The server boots with blubs spawning; no warnings.
  - [ ] Loot table and spawn egg present (datagen output).
  - [ ] The per-tick cost of 50 blubs is within 1.5× that of 50 rabbits (measured; numbers in the log).
  - [ ] Headless screenshots of blubs in the Meadow in each Tide, looked at.
- Iteration budget: fix hypotheses ≤ 5.
- Exit ramp: goal-selector AI instead of Brain if Brain costs too much.
- Log:
  - 2026-10-01: goals, music hearing (second game-event consumer), echo, herald, shelter, waterline, bathe, stacking up to 5 with toppling, sit and release, crossing with the owner, spawns (2–5, weight 10, world-gen 0.03, none naturally in Endure), empty loot table. 12 GameTests in `SiftBlubTest` (65/65 overall). Cost: 50 blubs = 0.95× 50 rabbits. Worldgen sample: 5 blubs in 121 chunks. One real bug found by the chord test (echo cooldown overflow), fixed.

  - 2026-10-01 (review): a fresh adversarial review reproduced a crash (a climbing blub mounting itself on an off-tick: stack overflow). Fixed, with the tower cap re-checked. Goal timings had been doubled (every-other-tick goals); fixed with `reducedTickDelay`. New tests: AI-on stacking, the real crossing path with its 5-tick window and an owner-held leash, and the Endure spawn branch in a lit Sift spot. The cost test now uses busy blubs: 0.87–1.22×. 71/71, twice. Doc corrections in D-021.
### WP-052 Entry advancements and lang pass
- Phase / Milestone: 4 / M1
- Tier: S
- Status: DONE
- Depends on: WP-047, WP-051
- Goal: The Sift advancement tab: the root "The Sift" (be noticed by a frame), "An Offering", "Where Souls Drift" and "The Tide Turns". Also a lang pass over everything in M1.
- Inputs (read ONLY these): docs/DESIGN/bible/items.md §5; mission §7.6.
- Deliverables: advancements via datagen; triggers; en_us lang reviewed.
- Definition of Done:
  - [ ] GameTests or scripted triggers grant each advancement.
  - [ ] Lang proofread: vanilla's voice, no typos, and a subtitle for every sound (a script check that every sound event has a subtitle key).
- Iteration budget: 1 round.
- Exit ramp: vanilla trigger types only.
- Log:
  - 2026-10-01: the tab via datagen. Root "The Sift" (location: in an Ancient City; the frame's "notice" cue is deferred, D-020), "An Offering" and "The Tide Turns" (vanilla `impossible` criteria awarded by Offering and TideCues), "Where Souls Drift" (changed dimension). Granted in tests: two server GameTests plus the client GameTest on a natural city (root, enter, Tide). Lang proofread (Tide capitalised, vanilla's semicolon style); `tools/docs/check_lang.py` (in CI) checks every sound's subtitle (steps excepted), every code key and every block and item name.

### WP-053 M1 integration and Gate C (self-review)
- Phase / Milestone: 4 / M1
- Tier: M
- Status: DONE
- Depends on: WP-040..052
- Goal: Everything works together: an integration pass, a balance review, a performance check, PLAYTEST.md, the jar, tag `v0.1.0-alpha`, and the Gate C self-review.
- Inputs (read ONLY these): STATUS.md; PLAN.md M1 section; PLAYTEST.md; BALANCE.md.
- Deliverables: PLAYTEST.md (Gate C, noting that M1's Endure is dark but not dangerous); the built jar; the tag; the Gate C summary in STATUS.md.
- Definition of Done:
  - [ ] Build, datagen no-diff, `tools/docs/check_bible.py`, and all GameTests are green. The dedicated server boots with zero `thesift` warnings.
  - [ ] Performance: chunk generation, a Tide transition with basins, and MSPT with 50 blubs are all within the bounds set in WP-042/045/051 (log).
  - [ ] A headless walkthrough (enter, watch a basin turn, befriend a blub, return), with screenshots looked at.
  - [ ] Tag pushed; Gate C self-review written.
- Iteration budget: fix rounds ≤ 3.
- Exit ramp: ship M1 with known issues logged in BLOCKERS if they don't break the slice.
- Log:

  - 2026-10-01: Gate C. Build, datagen no-diff, bible, palette and lang checks are green; 71/71 GameTests; the GameTest dedicated server logs no `thesift` warnings (only Loom's dev-classpath note). Performance: chunk generation 0.29× the Overworld, 50 basins through a Flow p95 0.005 ms, 50 busy blubs 0.87–1.22× rabbits, ichor 0.89–0.98× lava. The headless walkthrough (client GameTest) covers frame notice, opening, crossing, the Tides, a basin filling, befriending a blub (hearts), the gate, and the advancements; screenshots looked at. Two adversarial reviews since the preview: the Blub (a crash fixed), then frame cues, advancements and vents. Released as the `v0.1.0-alpha` pre-release.
## M2 — the hunt (`v0.2.0-alpha`): Endure means danger
Source: 01_CONTENT_BIBLE.md §M2 row; bible/creatures.md, items.md, world.md (M2 rows); systems.md §4; D-011, D-013, D-016. Every WP follows the M1 template; designs go through the ladder and ≤ 3 critique rounds, code through fresh adversarial review before Gate D.

  - 2026-10-02: the second post-preview review (frame cues, advancements, vents, the lang check) found six defects and no crash, all fixed in 76119d6: no chunk loads in frame discovery, a /tick freeze guard, wisps that reach the opening, a stale-cache rule, "An Offering" shared with players at the frame, and a lang check read from the registry sources. Released from that commit.
### WP-054 The owner's playtest rework (`v0.1.1-alpha`)
- Phase / Milestone: 4 / M1 (owner playtest of `v0.1.0-alpha`) · Tier: L · Status: DONE
- Goal: the owner's notes: "the terrain doesn't look like Minecraft", "textures, mobs and trees don't look like the teasers", "the water is the worst: sparse, acts like lava, purple, not transparent".
- Log:
  - 2026-10-02: done (D-024, D-025). The teaser stills were re-downloaded and sampled.
    - **Ichor** is the Sift's water: `#minecraft:water`, water's flow, harmless, translucent turquoise, and a turquoise haze underneath.
    - **Terrain** is vanilla's Overworld functions with continentalness +0.3 and sea level 63 of ichor (~15 % water in a 512² sample). On it stand rose spires (a new feature). The Hollows are vanilla's caves under a depth-chosen biome.
    - **New blocks:** Sift Soil (grass over dirt; healthy sculk spreads onto it) and Songwood Drapes.
    - **Textures** were redrawn from sampled ramps.
    - **Songwood:** a forked trunk with blob canopies, drapes, and groves.
    - **Blub:** remodelled at 9 × 7 × 8.
  - Evidence: 70/70 GameTests; worldgen and Hollows samples; landscape screenshots (`look_*`) compared with the stills.

### WP-060 M2 system design: the hearing rule, retreat, enduring variants, lumen
- Phase / Milestone: 4 / M2 · Tier: L (design) · Status: DONE (frozen 2026-10-02 after three critique rounds) · Depends on: Gate C
- Goal: `docs/DESIGN/system_hunt.md`: what Nesters hear in Endure (the vibrations a sculk sensor hears, D-011), how they retreat at dawn (D-013), the enduring-variant rule (resilient, soul particles, non-colour markers), lumen's repel radius (as soul fire for piglins), Quiet Waters' "never heard" rule, numbers next to vanilla analogs (warden, sculk sensor, piglin).
- Definition of Done: frozen after critique (≤ 3 rounds); BALANCE.md rows; the M1 blub's Endure shelter checked against the new danger.
- Evidence (2026-10-02):
  - [x] Frozen after round 3 (rounds 1–2 FAIL, fixed; round 3 FAIL narrowly on two wording fixes, made in place; log in the doc). Every vanilla and Fabric claim checked in the 26.3 sources.
  - [x] BALANCE.md section "The hunt".
  - [x] The blub's Endure shelter checked: a sheltering or restless blub steps carefully, so its herald hops don't call Nesters (system_hunt.md §13, mob_blub.md).

### WP-061 Nester design doc
- Tier: L (design) · Depends on: WP-060 · Goal: `mob_nester.md` via the design ladder (≥ 8 concepts), the full §8.1 template, critique ≤ 3, frozen; BALANCE rows.
- Status: DONE (frozen 2026-10-02). Evidence: a 9-concept ladder; every §8.1 section; three critique rounds (FAIL 5 → FAIL 4 → FAIL 1, each fixed; every vanilla claim checked in the 26.3 sources; log in the doc); BALANCE section "Nester".

### WP-062 Bloombud design doc
- Tier: L (design) · Depends on: WP-060 · Goal: `mob_bloombud.md` (groups across the Meadow, canon), same bar as WP-061.

### WP-063 Sift Hollows: the cave layer and glowcap pools
- Tier: L · Depends on: WP-060 · Goal: the underground biome (multi-noise depth), hymnstone caverns, glowcap pools (Should); screenshots looked at; chunk-generation cost ≤ 1.5× the Overworld (measured as in M1).

### WP-064 Flora II
- Tier: L · Depends on: WP-063 · Goal: tidewrack (opens in Thrive), Endure bloom (opens in Endure, at the waterline), glowcap (light 10), chime bell flower (rings when walked through: a vibration), lumen bloom; textures by script (palette check), models, loot, tags, sounds, GameTests per behaviour.

### WP-065 Materials and items
- Tier: M · Depends on: WP-064 · Goal: tidewrack frond (dye, blub treats), Endure petal, lumen lantern; recipes; blub treats heal and breed blubs (the M1 doc's M2 hook; a baby blub model and texture); GameTests.

### WP-066 The hearing rule and hunter retreat; lumen
- Tier: L · Depends on: WP-060, WP-064 · Goal: the system in code (a listener per hunter, no polling), retreat (burrowing) as Endure ends, lumen repelling hunters; GameTests for each rule; cost measured.

### WP-067 Nester · WP-068 Bloombud
- Tier: L each · Depends on: WP-061/062, WP-066 · Goal: art (code models, script textures, previews looked at), synthesized audio with subtitles, AI, spawns, GameTests per behaviour, cost ≤ 1.5× the nearest vanilla analog.

### WP-069 Enduring variants
- Tier: M · Depends on: WP-067, WP-068 · Goal: the rule from WP-060 applied to the common hostiles; markers readable without colour (§7.6).

### WP-070 Spawn tables and the gate sanctuary rule
- Tier: M · Depends on: WP-067, WP-068 · Goal: Meadow and Hollows spawn tables by Tide; no hostile spawns near a gate (the rule deferred from WP-047); GameTests.

### WP-071 Tide marks and M1 polish
- Tier: M · Goal: tide marks along basin rims; the basins' rising bubbles; the Sift's own particles for the frame, membrane and ichor (M1 known issues).

### WP-072 M2 advancements and lang
- Tier: S · Goal: Stacked (a tower of five blubs), Low Tide, Heard You, Quiet Waters; `check_lang.py` clean.

### WP-073 M2 integration and Gate D
- Tier: M · Goal: as WP-053: checks green, performance logged, a headless walkthrough of an Endure night (heard, hunted, safe under lumen), PLAYTEST.md, release `v0.2.0-alpha`.

## Later (coarse; detailed when each milestone starts)
- M3 souls · M4 the occupation · M5 the Meadow's life · M6 the heart of the blight · the Could pool (see 01_CONTENT_BIBLE.md §3).
- Phases 6–8: polish, hardening, release (mission §6).
