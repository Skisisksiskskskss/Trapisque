# PLAN — The Sift (thesift)

Rolling-wave plan (§5.2). Only the current phase/milestone has fully specified WPs; later ones stay coarse.
Only one WP is IN PROGRESS at a time.

| WP | Title | Phase | Tier | Status |
|----|-------|-------|------|--------|
| WP-001 | Version ground truth & official-Sift check | 0 | S | DONE |
| WP-002 | Toolchain + mod scaffold (build, runServer, genSources) | 0 | M | DONE |
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
- Status: DONE
- Depends on: WP-001
- Goal: An empty-but-real Fabric mod (`thesift`) that builds, boots a dedicated server on 26.3, and has generated/attached sources for study.
- Inputs (read ONLY these): D-001 toolchain record; the official Fabric template/example mod for 26.3; docs.fabricmc.net setup pages.
- Deliverables: build.gradle, settings.gradle, gradle.properties, gradle wrapper, src/main (common) + src/client (client) source sets, fabric.mod.json, entrypoints, LICENSE (MIT code) + LICENSE-ASSETS.md, .gitignore, README, gradle/gradle-daemon-jvm.properties, tools/dev/headless-client.sh.
- Definition of Done:
  - [x] JDK 25 available to Gradle — `./gradlew --version`: "Daemon JVM: Compatible with Java 25, Eclipse Temurin … (from gradle/gradle-daemon-jvm.properties)"; fresh-machine path proven: with no local JDK 25, `./gradlew help` auto-downloaded Temurin 25.0.4.1 into ~/.gradle/jdks and succeeded.
  - [x] `./gradlew build` green — "BUILD SUCCESSFUL in 33s", `-Xlint:all` with zero warnings; jar contains thesift/TheSift.class, thesift/client/TheSiftClient.class, fabric.mod.json (version expanded), licences.
  - [x] `./gradlew runServer` boots — "Loading Minecraft 26.3 with Fabric Loader 0.19.5", "- thesift 0.0.1-dev", "(thesift) The Sift initialized (unofficial fan project)", "Done (3.282s)!", clean `stop` → "BUILD SUCCESSFUL". Zero WARN/ERROR from `thesift`. (One vanilla ERROR on first boot: "Failed to load properties from file: server.properties" — the file doesn't exist yet; vanilla creates it.)
  - [x] runClient attempted — display: none, but Xvfb + Mesa exist. Works headless via Vulkan on lavapipe (`tools/dev/headless-client.sh`); title screen rendered and screenshotted. Only env errors (no flite TTS library, no OpenAL device); none from `thesift`.
  - [x] Sources generated — `./gradlew genSources` (Vineflower): `.gradle/loom-cache/minecraftMaven/net/minecraft/minecraft-{common,clientOnly}-7e9a32a5b8/26.3/*-sources.jar` (5,037 + 2,264 files).
  - [x] Split client/common source sets — `loom.splitEnvironmentSourceSets()`; client entrypoint in src/client/java/thesift/client/.
  - [x] fabric.mod.json description states "Unofficial fan project, not affiliated with or endorsed by Mojang Studios or Microsoft."
- Iteration budget: critique rounds ≤ 1, fix hypotheses ≤ 5
- Exit ramp: if the template can't be fetched, hand-write the minimal Loom build from docs.fabricmc.net and the Loom version's documented plugin id.
- Log:
  - 2026-09-30: template fetched via raw.githubusercontent.com (api.github.com/github.com UI are 403 through the proxy; raw works). Wrapper jar sha256 7a9ce74c… = official gradle-9.7.1-wrapper.jar.sha256; distributionSha256Sum pinned (acd53f1e…). Loom 1.18.2 needs the Gradle daemon on JVM 25 → added foojay-resolver-convention 1.0.0 + `updateDaemonJvm --jvm-version=25 --jvm-vendor=adoptium`. Root package `thesift` (D-003). No mixins (none needed yet; every future mixin needs a decision record).
  - Server: EULA accepted in git-ignored `run/eula.txt` for local dev testing (owner's instruction to runServer). Stdin `stop` works through Gradle (FIFO).
  - Client (3 hypotheses, within budget): H1 Xvfb `+extension GLX` + llvmpipe → still "Couldn't find matching GLX visual". Diagnosis: 26.3 GlBackend asks SDL for GL 3.3 core fwd-compat **with SDL_GL_FRAMEBUFFER_SRGB_CAPABLE=1**; Xvfb advertises GLX_ARB_framebuffer_sRGB but exposes 0 sRGB-capable fbconfigs (240 total). H3: apt-installed mesa-vulkan-drivers (lavapipe) and forced `--graphicsBackend vulkan` → "Using graphics backend Vulkan … llvmpipe Mesa 25.2.8". Scripted in tools/dev/headless-client.sh (installs packages if missing; start/screenshot/stop by PID). Lesson: never `pkill -f <pattern>` from a shell whose own command line contains the pattern (it killed the tool shell twice) — use PID files.
  - Self-critique (1 round): (1) container-local apt packages vanish with the container → script self-installs; (2) Gradle "Class path entries reference missing files: build/resources/client" WARN from FabricLoader/Knot until we ship client resources — goes away when the first client asset lands (Phase 3/4); (3) `-Xlint:all` may be noisy once Minecraft types are subclassed (e.g. serial) → Phase 3 decides the final lint set (-Werror or not).

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
