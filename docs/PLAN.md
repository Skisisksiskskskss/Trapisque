# PLAN — The Sift (thesift)

Rolling-wave plan (§5.2). Only the current phase/milestone has fully specified WPs; later ones stay coarse.
Only one WP is IN PROGRESS at a time.

| WP | Title | Phase | Tier | Status |
|----|-------|-------|------|--------|
| WP-001 | Version ground truth & official-Sift check | 0 | S | DONE |
| WP-002 | Toolchain + mod scaffold (build, runServer, genSources) | 0 | M | TODO |
| WP-003 | Sift research I: canon, areas, Tides, access, lore, palette evidence | 0 | L | TODO |
| WP-004 | Sift research II: bestiary (every mob, boss, character) | 0 | L | TODO |
| WP-005 | Vanilla study I: world (dimension, noise, biomes, env attributes, portals, jigsaw) | 0 | L | TODO |
| WP-006 | Vanilla study II: entities (Brain, goals, vibrations/sculk, models/anims, boss bars) | 0 | L | TODO |
| WP-007 | Vanilla study III: plumbing (datagen, SavedData/attachments, payloads, GameTest) | 0 | M | TODO |
| WP-010 | Vision (Phase 1, XL) | 1 | XL | TODO (coarse) |

---

## Phase 0 — Ground truth and toolchain

### WP-001 Version ground truth & official-Sift check
- Phase / Milestone: 0 / —
- Tier: S
- Status: DONE
- Depends on: —
- Goal: Establish, from live primary sources, the exact target Minecraft version and the matching Fabric toolchain; confirm whether Mojang has shipped any official Sift content for Java (§3.3).
- Inputs (read ONLY these): docs/00_MISSION.md §3.3, §4, §6 Phase 0; Mojang version manifest; meta.fabricmc.net; fabricmc.net/develop; Fabric blog 26.3 post; minecraft.wiki snapshot pages.
- Deliverables: toolchain matrix + deviations in docs/DECISIONS.md (D-001…); "Official Java Sift content" section in docs/RESEARCH.md.
- Definition of Done:
  - [x] Latest stable release confirmed from the manifest AND the jar's version.json (values recorded). — D-001 table (manifest latest.release=26.3; version.json protocol 777 / world 5023 / RP 97.1 / DP 121.0 / java 25 / stable true).
  - [x] Fabric Loader, Fabric API, Loom (+ plugin id), Gradle, JDK versions confirmed from live sources and recorded. — D-001 (0.19.5 / 0.161.0+26.3 / Loom 1.18.2 `net.fabricmc.fabric-loom` / Gradle 9.7.1 / Temurin 25.0.4.1+1).
  - [x] Every deviation from §4 recorded in DECISIONS.md. — D-001: Loom 1.17→1.18.2, Gradle 9.6.0→9.7.1 (template moved on); everything else matched.
  - [x] Latest snapshots' jars searched for Sift content (paths + contents) and changelogs/news checked; result recorded in RESEARCH.md with sources. — RESEARCH.md §0, D-002 (not triggered).
- Iteration budget: critique rounds ≤ 1, fix hypotheses ≤ 3
- Exit ramp: if a Fabric component has no 26.3 build, record it in BLOCKERS.md and choose the newest stable combination that builds.
- Log:
  - 2026-09-30: manifest → 26.3 latest release (26.4-snapshot-2 latest snapshot). Downloaded client jars 26.3 / 26.4-s1 / 26.4-s2; `unzip -p version.json`; recursive grep for "sift" → only META-INF base64 noise. Fabric meta: loader 0.19.5 stable, intermediary 0.0.0, no Yarn. Fabric maven: API 0.161.0+26.3 newest for 26.3. Loom module metadata: 1.17.21 (Gradle≥9.5, JVM21), 1.18.2 (Gradle≥9.7, JVM25). Example mod HEAD: 26.3 / loom 1.18-SNAPSHOT / Gradle 9.7.1. Blog 26.3 post read (porting notes match §4 and add: registrable number/float/int providers, block-state providers, material rules/conditions; reloadable dynamic registries incl. recipes/advancements; Block codecs removed; configured features → worldgen/feature + FEATURE_TYPE registry). Wiki: The Sift / Blub / Planned versions / LIVE Sept 2026 / 26.4 read.
  - Self-critique (1 round): weakness 1 — Loom 1.18.2 is newer than the blog's advice → mitigated by exit ramp to 1.17.21 in D-001; weakness 2 — minecraft.net recap not fetched directly (quoted via wiki) → WP-003 will try to fetch it; weakness 3 — Bedrock previews/betas not checked for Sift content → out of scope (Java target), noted in RESEARCH unknowns by WP-003.

### WP-002 Toolchain + mod scaffold
- Phase / Milestone: 0 / —
- Tier: M
- Status: TODO
- Depends on: WP-001
- Goal: A empty-but-real Fabric mod (`thesift`) that builds, boots a dedicated server on 26.3, and has generated/attached sources for study.
- Inputs (read ONLY these): D-001 toolchain record; the official Fabric template/example mod for 26.3; docs.fabricmc.net setup pages.
- Deliverables: build.gradle, settings.gradle, gradle.properties, gradle wrapper, src/main (common) + src/client (client) source sets, fabric.mod.json, entrypoints, LICENSE (MIT code) + asset licence note, .gitignore, CI workflow draft (optional here, required in Phase 3).
- Definition of Done:
  - [ ] JDK 25 available to Gradle (toolchain or installed) — evidence: `java -version`/Gradle toolchain output.
  - [ ] `./gradlew build` green — evidence: output excerpt.
  - [ ] `./gradlew runServer` boots to "Done" with our mod loaded, zero errors/warnings from `thesift` — evidence: log excerpt.
  - [ ] runClient attempted only if a display exists (record result either way).
  - [ ] Sources generated/available (genSources or sources jar) — evidence: path to readable 26.3 sources.
  - [ ] Split client/common source sets confirmed (client entrypoint lives in src/client).
  - [ ] fabric.mod.json description states "Unofficial fan project".
- Iteration budget: critique rounds ≤ 1, fix hypotheses ≤ 5
- Exit ramp: if the template can't be fetched, hand-write the minimal Loom build from docs.fabricmc.net and the Loom version's documented plugin id.
- Log:

### WP-003 Sift research I: canon, areas, Tides, access, lore, palette evidence
- Phase / Milestone: 0 / —
- Tier: L
- Status: TODO
- Depends on: —
- Goal: Verify/correct/expand §3 with cited sources: release facts, the dimension, Tides, souls, areas, access, lore, characters, blocks/items, and resolve the colour contradiction.
- Inputs (read ONLY these): docs/00_MISSION.md §3; minecraft.wiki Dungeons II pages; Xbox Wire; minecraft.net articles; reputable press; official trailer/gameplay descriptions.
- Deliverables: docs/RESEARCH.md sections: Sources index, Canon table (fact · source · confidence), Areas, Tides, Souls, Sculk, Access, Lore & characters, Blocks/items/materials, Visual/palette evidence, Contradictions, Unknowns.
- Definition of Done:
  - [ ] Every §3.1 row verified, corrected, or marked unverifiable, each with a source.
  - [ ] Every §3.2 observation tested against evidence and marked supported / unsupported / open.
  - [ ] Colour contradiction addressed with evidence (or explicitly listed as unresolved with what would resolve it).
  - [ ] Contradictions and Unknowns lists present.
  - [ ] No claim without a source; uncertain facts labelled.
- Iteration budget: critique rounds ≤ 3 (L), fix hypotheses n/a
- Exit ramp: facts that can't be verified in reachable sources are marked "unverified — reason" and moved to Unknowns.
- Log:

### WP-004 Sift research II: bestiary
- Phase / Milestone: 0 / —
- Tier: L
- Status: TODO
- Depends on: WP-003 (sources index)
- Goal: A short cited entry for every Sift mob, boss and named character: appearance, Dungeons II behaviour, faction, area.
- Inputs (read ONLY these): docs/RESEARCH.md sources index; minecraft.wiki mob/boss pages.
- Deliverables: docs/RESEARCH.md "Bestiary" section (or docs/RESEARCH_BESTIARY.md if RESEARCH.md would sprawl).
- Definition of Done:
  - [ ] Entry for every species in §3.1 plus any discovered since, each with source + confidence.
  - [ ] Bosses and characters covered.
  - [ ] Faction (Sift native / sculk / Illager / other) and area recorded where known; "unknown" stated otherwise.
- Iteration budget: critique rounds ≤ 3
- Exit ramp: species with no reachable information get a stub entry marked "name only — no data", listed in Unknowns.
- Log:

### WP-005 Vanilla study I: world
- Phase / Milestone: 0 / —
- Tier: L
- Status: TODO
- Depends on: WP-002 (sources available)
- Goal: Document how 26.3 implements dimensions, dimension types, noise settings, biomes, environment attributes, portals/teleport transitions and jigsaw structures — with file/class locations, patterns and gotchas.
- Inputs (read ONLY these): 26.3 sources + vanilla data in the jar; Fabric docs for worldgen/dynamic registries.
- Deliverables: docs/VANILLA_ANALOGS.md sections W1–W7.
- Definition of Done:
  - [ ] Each section names real 26.3 classes/paths (verified by grep in sources/jar), key patterns, and gotchas.
  - [ ] Environment attributes: full list of attributes + what can be per-dimension/per-biome and whether they can be time/state-driven (answers "how far they go").
  - [ ] Portal/teleport path traced end-to-end for Nether + End (classes named).
- Iteration budget: critique rounds ≤ 2, fix hypotheses n/a
- Exit ramp: any system not fully traced is marked "partial — traced up to X" with the next file to read.
- Log:

### WP-006 Vanilla study II: entities
- Phase / Milestone: 0 / —
- Tier: L
- Status: TODO
- Depends on: WP-002
- Goal: Document Brain AI (Warden, Allay, Sniffer), goal-selector AI, vibrations & sculk (spreader, catalyst, listeners), code models + keyframe animations, and boss bars in 26.3.
- Inputs (read ONLY these): 26.3 sources.
- Deliverables: docs/VANILLA_ANALOGS.md sections E1–E5.
- Definition of Done:
  - [ ] Each section names real 26.3 classes (verified), key patterns, gotchas.
  - [ ] Entity registration + attributes + renderer/model/layer registration path noted.
- Iteration budget: critique rounds ≤ 2
- Exit ramp: as WP-005.
- Log:

### WP-007 Vanilla study III: plumbing
- Phase / Milestone: 0 / —
- Tier: M
- Status: TODO
- Depends on: WP-002
- Goal: Document datagen (Fabric), SavedData & data attachments, networking payloads, and GameTest APIs (server + client if present) for 26.3.
- Inputs (read ONLY these): 26.3 sources; Fabric API sources/jars; docs.fabricmc.net.
- Deliverables: docs/VANILLA_ANALOGS.md sections P1–P4.
- Definition of Done:
  - [ ] Each section names real classes/entrypoints (verified), patterns, gotchas.
  - [ ] States whether a client GameTest API exists in this Fabric API version.
- Iteration budget: critique rounds ≤ 2
- Exit ramp: as WP-005.
- Log:

---

## Phase 1 — Vision (coarse; detailed when Phase 0 exits)

### WP-010 Vision (XL)
- Produce docs/DESIGN/00_VISION.md per §6 Phase 1: fantasy, tone, pillars; player journey; progression placement; entry path (≥12 ideas incl. Ancient City frame + sound activation); dimension rules (+ which env attributes express them); core systems at concept level (Tides, souls, healthy vs corrupted sculk, sound, Illager occupation). Independent critique ≤3 rounds → Gate A.

## Phase 2+ (very coarse)
- Phase 2: content bible + roadmap → Gate B.
- Phase 3: architecture decisions, CI, first GameTest.
- Phase 4: M1 vertical slice → Gate C.
- Phases 5–8: production milestones, polish, hardening, release.
