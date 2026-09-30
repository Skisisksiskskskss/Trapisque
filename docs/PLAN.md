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
| WP-020 | Content bible I: world (areas, biomes, terrain, blocks, flora, hazards, materials, structures) | 2 | L | IN PROGRESS |
| WP-021 | Content bible II: creatures (canon-mob verdicts, natives, hostiles, companions, bosses) | 2 | L | TODO |
| WP-022 | Content bible III: items, gear, food, advancements, audio hooks, mechanics | 2 | M | TODO |
| WP-023 | Dependency graph, milestones, Phase 3 WPs and fully specified M1 WPs | 2 | L | TODO |
| WP-024 | Content bible critique, freeze, Gate B (self-review) | 2 | L | TODO |

Phase 0 and Phase 1 WP details (with evidence logs) are in `docs/archive/PLAN_phase0-1.md`.

---

## Phase 2 — Content bible and roadmap

Deliverable: `docs/DESIGN/01_CONTENT_BIBLE.md` (index, tier summary, dependency graph, milestones) plus its parts `docs/DESIGN/bible/{world,creatures,items}.md`.
Tier key (mission §6 Phase 2): **Core** (in 1.0) · **Should** · **Could** · **Won't** (with a reason). The frozen vision's Must/Should/Could map to Core/Should/Could.

### WP-020 Content bible I: world
- Phase / Milestone: 2 / —
- Tier: L
- Status: IN PROGRESS
- Depends on: WP-014 (frozen vision)
- Goal: A tiered inventory of everything in the world layer, each entry with its purpose and at least two Sift-system links.
- Inputs (read ONLY these): docs/DESIGN/00_VISION.md, docs/DESIGN/vision/{systems,rules}.md, docs/RESEARCH.md §2 and §5, docs/VANILLA_ANALOGS.md W2/W3/W6/W7.
- Deliverables: docs/DESIGN/bible/world.md.
- Definition of Done:
  - [ ] Areas and biomes (sub-biomes of Singer's Meadow for 1.0; later areas as Won't-for-1.0 with a milestone), terrain features, block families (vanilla-style sets where sensible), flora, hazardous blocks, materials, structures — each tiered, with purpose and system links.
  - [ ] Every Core entry names its vanilla analog and the route (data or code).
  - [ ] Canon-sourced vs invented is marked on every entry.
- Iteration budget: self-critique ≤ 2 passes (the bible-wide critique is WP-024).
- Exit ramp: entries that can't be justified go to Could or Won't with a reason.
- Log:

### WP-021 Content bible II: creatures
- Phase / Milestone: 2 / —
- Tier: L
- Status: TODO
- Depends on: WP-020
- Goal: A verdict for every canon mob (adapt / merge / defer / cut, with a reason) and a tiered creature roster.
- Inputs (read ONLY these): docs/RESEARCH_BESTIARY.md, docs/DESIGN/00_VISION.md, docs/DESIGN/vision/systems.md, docs/DESIGN/bible/world.md.
- Deliverables: docs/DESIGN/bible/creatures.md.
- Definition of Done:
  - [ ] Every species, character and boss in the bestiary has a verdict and reason (variants may share a base design).
  - [ ] The roster is tiered and each creature has a role (niche), a Tide behaviour, and at least two system links.
  - [ ] Vanilla analog named for each Core creature.
- Iteration budget: self-critique ≤ 2 passes.
- Exit ramp: unclear creatures are deferred with a revisit trigger.
- Log:

### WP-022 Content bible III: items, gear, food, advancements, audio, mechanics
- Phase / Milestone: 2 / —
- Tier: M
- Status: TODO
- Depends on: WP-020, WP-021
- Goal: A tiered inventory of items, gear traits, food, advancements, ambience and music hooks, and mechanics.
- Inputs (read ONLY these): docs/DESIGN/00_VISION.md, docs/DESIGN/vision/systems.md, docs/DESIGN/bible/{world,creatures}.md.
- Deliverables: docs/DESIGN/bible/items.md.
- Definition of Done:
  - [ ] Items, tools and gear traits, armour (if any), food, advancements (a tree in vanilla's voice), ambience and music hooks, mechanics — tiered, each with purpose and links.
  - [ ] Every item has a source and a sink (where it comes from, what it's for).
  - [ ] Nothing breaks the vision's "never gives" list (checked item by item).
- Iteration budget: self-critique ≤ 1 pass.
- Exit ramp: items without a sink are cut.
- Log:

### WP-023 Dependency graph, milestones, Phase 3 and M1 WPs
- Phase / Milestone: 2 / —
- Tier: L
- Status: TODO
- Depends on: WP-020..022
- Goal: Order the work so systems come before the content that depends on them, and plan M1 in full.
- Inputs (read ONLY these): docs/DESIGN/01_CONTENT_BIBLE.md and its parts; docs/DECISIONS.md D-008, D-010..D-013.
- Deliverables: dependency graph and milestones in 01_CONTENT_BIBLE.md; Phase 3 WPs and fully specified M1 WPs in PLAN.md.
- Definition of Done:
  - [ ] A dependency graph covering every Core entry.
  - [ ] Milestones M1 (vertical slice) → M2 … → 1.0, each ending shippable.
  - [ ] M1 meets the mission's minimum: entry and return, one area with its own terrain, a small block set with final art, one mob fully finished, the Tide cycle in core form, entry advancements.
  - [ ] Phase 3 and M1 WPs written with the §5.3 template.
- Iteration budget: self-critique ≤ 2 passes.
- Exit ramp: if M1 is too big for the mission's "thin" slice, move items to M2.
- Log:

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

## Phase 2+ (very coarse)
- Phase 3: architecture decisions, CI, first GameTest.
- Phase 4: M1 vertical slice → Gate C.
- Phases 5–8: production milestones, polish, hardening, release.
