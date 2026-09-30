# PLAN — The Sift (thesift)

Rolling-wave plan (§5.2). Only the current phase/milestone has fully specified WPs; later ones stay coarse.
Only one WP is IN PROGRESS at a time.

| WP | Title | Phase | Tier | Status |
|----|-------|-------|------|--------|
| WP-001 | Version ground truth & official-Sift check | 0 | S | DONE |
| WP-002 | Toolchain + mod scaffold (build, runServer, genSources) | 0 | M | DONE |
| WP-003 | Sift research I: canon, areas, Tides, access, lore, palette evidence | 0 | L | REVIEW |
| WP-004 | Sift research II: bestiary (every mob, boss, character) | 0 | L | REVIEW |
| WP-005 | Vanilla study I: world (dimension, noise, biomes, env attributes, portals, jigsaw) | 0 | L | DONE |
| WP-006 | Vanilla study II: entities (Brain, goals, vibrations/sculk, models/anims, boss bars) | 0 | L | DONE |
| WP-007 | Vanilla study III: plumbing (datagen, SavedData/attachments, payloads, GameTest) | 0 | M | DONE |
| WP-010 | Vision I: fantasy, tone, pillars, journey, progression | 1 | XL | DONE |
| WP-011 | Vision II: entry and return path (≥12 ideas) | 1 | L | DONE |
| WP-012 | Vision III: the dimension's rules (+ env-attribute mapping) | 1 | M | DONE |
| WP-013 | Vision IV: core systems (Tides, souls, sculk, sound, Illagers) | 1 | L | DONE |
| WP-014 | Vision critique, freeze, Gate A | 1 | XL | TODO |

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
- Status: REVIEW (round 2 of ≤3 pending)
- Depends on: —
- Goal: Verify/correct/expand §3 with cited sources: release facts, the dimension, Tides, souls, areas, access, lore, characters, blocks/items, and resolve the colour contradiction.
- Inputs (read ONLY these): docs/00_MISSION.md §3; minecraft.wiki Dungeons II pages; Xbox Wire; minecraft.net articles; reputable press; official trailer/gameplay descriptions.
- Deliverables: docs/RESEARCH.md sections: Sources index, Canon table (fact · source · confidence), Areas, Tides, Souls, Sculk, Access, Lore & characters, Blocks/items/materials, Visual/palette evidence, Contradictions, Unknowns.
- Definition of Done:
  - [x] Every §3.1 row verified, corrected, or marked unverifiable, each with a source. (RESEARCH §1a seed-row map)
  - [x] Every §3.2 observation tested against evidence and marked supported / unsupported / open. (RESEARCH §6)
  - [x] Colour contradiction addressed with evidence (or explicitly listed as unresolved with what would resolve it). (RESEARCH §5)
  - [x] Contradictions and Unknowns lists present. (RESEARCH §7: 14 items; §10)
  - [x] No claim without a source; uncertain facts labelled. (one H/M/L scale; 189 quotes machine-checked, see log)
- Iteration budget: critique rounds ≤ 3 (L), fix hypotheses n/a
- Exit ramp: facts that can't be verified in reachable sources are marked "unverified — reason" and moved to Unknowns.
- Log:
  - 2026-09-30 pass 1 (wiki): 572 minecraft.wiki pages fetched (all 536 Dungeons II pages + 36 others); metadata in research/wiki_pages_2026-09-30.tsv. Pass 2 (official + press): 90 sources, bibliography in research/press_sources_2026-09-30.md; 558 quotes in the working notes machine-checked, 0 mismatches.
  - Review round 1 (fresh reviewer; artifact + rubric only): **FAIL**, 3 must-fix (bestiary gaps; §6 observation 2 overstated; confidence labels above the doc's own rubric), 6 should-fix, 2 notes. Accepted all but one: the reviewer read the Tides tutorial as using "," where the screenshot shows ";" (checked at 6× zoom; kept, and the cursor-hidden "[erf]" is now marked).
  - Fixes: one confidence scale for both docs; observation 2 now "supported for Dungeons II; open for Java"; seed-row → verdict map (§1a); §5 now cites the official "soft orange" audio description, the wiki's "Orange … dark salmon" block names, the press origin of "neon blue and pink" (Game Rant 20:03 UTC, gHacks 21:08 UTC) and TechJuice's misattribution (P-TJ added); §7 grew from 7 to 14 items; design opinion removed or marked *Inference*; unknowns updated (the Singer short and the note-sequence video exist but were unreachable).
  - New evidence found while fixing: two official images of the Dungeons II portal (S-I6 launcher asset, S-I7 Steam asset: a dark frame, eight rainbow-topped note blocks in front); "The illagers take control of Souls" is a review (R-GT), not official text; Deeper and Darker and Sculk Depths have no 26.x release (research/prior_art_2026-09-30.md, PA-1…3); the Steam rates are a snapshot one day after launch (caveat added).
  - Quote check: a second script checked every quote in RESEARCH.md and RESEARCH_BESTIARY.md against the saved source text: 189 verified, 0 mismatched, 1 skipped (the tutorial screenshot, checked by eye). Source page text stays in the session scratchpad (third-party copyright); only metadata is committed.

### WP-004 Sift research II: bestiary
- Phase / Milestone: 0 / —
- Tier: L
- Status: REVIEW (round 2 of ≤3 pending)
- Depends on: WP-003 (sources index)
- Goal: A short cited entry for every Sift mob, boss and named character: appearance, Dungeons II behaviour, faction, area.
- Inputs (read ONLY these): docs/RESEARCH.md sources index; minecraft.wiki mob/boss pages.
- Deliverables: docs/RESEARCH.md "Bestiary" section (or docs/RESEARCH_BESTIARY.md if RESEARCH.md would sprawl).
- Definition of Done:
  - [x] Entry for every species in §3.1 plus any discovered since, each with source + confidence. (all 22 seed names mapped, incl. renames; plus Soul Blocker alias, unnamed "bird-like creatures" and "goat things", the Sniffer claim, the Monstrous Opus)
  - [x] Bosses and characters covered. (Characters table: Singer, Bubbles, the four novel Visitors, Lucky, High Council)
  - [x] Faction (Sift native / sculk / Illager / other) and area recorded where known; "unknown" stated otherwise. (boss table has a Faction column; blanks replaced by "unknown")
- Iteration budget: critique rounds ≤ 3
- Exit ramp: species with no reachable information get a stub entry marked "name only — no data", listed in Unknowns.
- Log:
  - 2026-09-30: bestiary written from the wiki pass, plus press observations and our own look at official images ([OBS]).
  - Review round 1 (shared with WP-003): FAIL on DoD 6 (missing Visitors and creatures; no boss faction column; blanks instead of "unknown"; descriptors cited to the wrong wiki pages; H defined more loosely than in RESEARCH.md). All fixed: descriptors now cite [W:Sifter]/[W:Sculker]; novel-only lore marked L inline; IGN's "dancing automatons" left unidentified in RESEARCH, while the wiki's own gallery captions ("Echo golems dancing in front of the Deep Dark portal") support dancing echo golems.

### WP-005 Vanilla study I: world
- Phase / Milestone: 0 / —
- Tier: L
- Status: DONE
- Depends on: WP-002 (sources available)
- Goal: Document how 26.3 implements dimensions, dimension types, noise settings, biomes, environment attributes, portals/teleport transitions and jigsaw structures — with file/class locations, patterns and gotchas.
- Inputs (read ONLY these): 26.3 sources + vanilla data in the jar; Fabric docs for worldgen/dynamic registries.
- Deliverables: docs/VANILLA_ANALOGS.md sections W1–W7.
- Definition of Done:
  - [x] Each section names real 26.3 classes/paths (verified by grep in sources/jar), key patterns, and gotchas. — W1–W7 written from the decompiled sources + jar data; two from-memory claims (Nether delay, cardinal_light values) re-verified and corrected.
  - [x] Environment attributes: full list + what can be per-dimension/per-biome and whether they can be time/state-driven. — W4: all 51 ids, flags, types/modifiers, layer order (dimension → biome → timelines → weather), clock API + `/time` support; registries are mod-extensible.
  - [x] Portal/teleport path traced end-to-end for Nether + End. — W5: `entityInside` → `setAsInsidePortal` → `PortalProcessor` → `getPortalDestination` → `TeleportTransition`; Nether traced to `PortalForcer.findClosestPortalPosition/createPortal` (POI-based), End to `EndPlatformFeature.createEndPlatform` + respawn return.
- Iteration budget: critique rounds ≤ 2, fix hypotheses n/a
- Exit ramp: any system not fully traced is marked "partial — traced up to X" with the next file to read.
- Log:
  - 2026-09-30: key discovery — 26.3 world clocks + timelines + environment attributes are a complete, synced, persisted, command-controllable, data-driven "time-varying rules" system → prime Tide implementation candidate (to be weighed in Phase 1). Ancient City frame measured from NBT (22×8, 20×6 opening, anchor jigsaw on top).
  - Self-critique round 1 (weaknesses first): (1) W2 has no worked density-function recipe — partial, next read `density_function/overworld/final_density.json` + `nether/base_3d_noise.json` when the first terrain WP starts; (2) W3 lacks the multi-noise parameter-list schema — partial, next read `multi_noise_biome_source_parameter_list/nether.json` + `MultiNoiseBiomeSourceParameterList.java`; (3) W6 covers the Ancient City only — Trial Chambers (`worldgen/structure/trial_chambers.json`, pool aliases) deferred to the first structure WP. No must-fix for Phase 1 needs; strengths: W4/W5/W6 facts are measured, not remembered.

### WP-006 Vanilla study II: entities
- Phase / Milestone: 0 / —
- Tier: L
- Status: DONE
- Depends on: WP-002
- Goal: Document Brain AI (Warden, Allay, Sniffer), goal-selector AI, vibrations & sculk (spreader, catalyst, listeners), code models + keyframe animations, and boss bars in 26.3.
- Inputs (read ONLY these): 26.3 sources.
- Deliverables: docs/VANILLA_ANALOGS.md sections E1–E5.
- Definition of Done:
  - [x] Each section names real 26.3 classes (verified), key patterns, gotchas. — E1–E5 from sources; every API detail written from reading patterns was re-checked (`looping()/build()`, `LINEAR/CATMULLROM`, `POSITION/ROTATION/SCALE`, `broadcastEntityEvent`, frequency range 1–15, and the Fabric `FabricDefaultAttributeRegistry` / `EntityRendererRegistry` / `ModelLayerRegistry` signatures via `javap`).
  - [x] Entity registration + attributes + renderer/model/layer registration path noted. — E1 (constants moved to `EntityTypes`/`EntityTypeIds`; `ValueOutput`/`ValueInput` save API).
- Iteration budget: critique rounds ≤ 2
- Exit ramp: as WP-005.
- Log:
  - 2026-09-30: key findings — 26.3 Brain API is `Brain.provider(memories, sensors, activitiesFn)` + `ActivityData.create(...)` + `setActiveActivityToFirstValid`; Creaking gating by env attribute keyed from a timeline = template for Tide-gated mobs; catalyst turns death XP into sculk charge + `sculk_soul` bloom (vanilla "soul" hook); `LivingEntityEmissiveLayer` = glowing-body tool.
  - Self-critique round 1 (weaknesses first): (1) Breeze/Happy Ghast only skimmed (jump attack / riding) — partial, read `BreezeAi` + `HappyGhast#travel` when a flying/riding mob is designed; (2) no read of `NaturalSpawner` spawn-cost logic — partial, read when spawn balancing starts; (3) animation *authoring* ergonomics (how to preview keyframes) untested — covered later by the headless client + client GameTests (WP-007/Phase 3). No must-fix for Phase 1.

### WP-007 Vanilla study III: plumbing
- Phase / Milestone: 0 / —
- Tier: M
- Status: DONE
- Depends on: WP-002
- Goal: Document datagen (Fabric), SavedData & data attachments, networking payloads, and GameTest APIs (server + client if present) for 26.3.
- Inputs (read ONLY these): 26.3 sources; Fabric API sources/jars; docs.fabricmc.net.
- Deliverables: docs/VANILLA_ANALOGS.md sections P1–P4.
- Definition of Done:
  - [x] Each section names real classes/entrypoints (verified), patterns, gotchas. — P1–P4 from Fabric API sources jars (datagen 27.2.4, gametest 4.0.32, client-gametest 6.0.7, attachment 2.2.30, networking 6.3.8, object-builder) + Loom 1.18.2 `javap`; entrypoint keys `fabric-datagen` / `fabric-gametest` / `fabric-client-gametest` read from sources.
  - [x] States whether a client GameTest API exists. — Yes: `FabricClientGameTest` + `ClientGameTestContext` with screenshot capture/compare, input, world builder (P4).
- Iteration budget: critique rounds ≤ 2
- Exit ramp: as WP-005.
- Log:
  - 2026-09-30: findings — `@GameTest(dimension=…)` can run tests inside our dimension; Fabric's `SavedDataStorageMixin` makes a null `DataFixTypes` safe; `FabricCodecDataProvider` can generate timeline/clock JSON; Loom `configureTests { eula = true }` exists.
  - Self-critique round 1 (weaknesses first): (1) nothing here is exercised yet — Phase 3's exit (datagen no-diff, one GameTest, CI) is the real test; (2) client GameTests under Xvfb need the Vulkan argument wired into Loom's run config — unverified, flagged in P4; (3) no networking example compiled — acceptable, P3 recommends avoiding custom packets. No must-fix.

## Phase 1 — Vision (Tier XL design; detailed at Phase 0 exit)

Deliverable: `docs/DESIGN/00_VISION.md` (the frozen vision) + focused appendices in `docs/DESIGN/vision/` holding the diverge/converge tables, so the vision itself stays short. Every choice is scored on the §7.1 rubric and recorded in DECISIONS.md.

### WP-010 Vision I: fantasy, tone, pillars, player journey, progression placement
- Phase / Milestone: 1 / —
- Tier: XL
- Status: DONE
- Depends on: WP-003, WP-004, WP-005..007
- Goal: Choose the Sift's fantasy (one sentence), tone and 3–5 pillars from ≥12 distinct vision concepts; write the player journey (rumor → … → why you come back) and where the Sift sits in vanilla progression.
- Inputs (read ONLY these): RESEARCH.md §0–8, RESEARCH_BESTIARY.md (patterns section), VANILLA_ANALOGS W4/E4, D-002.
- Deliverables: docs/DESIGN/vision/concepts.md (≥12 concepts, ≥2 deliberately unusual, rubric table); 00_VISION.md sections Fantasy/Tone/Pillars/Journey/Progression; D-005.
- Definition of Done:
  - [x] ≥12 concepts written before any scoring; ≥2 marked unusual. — 14 concepts, 3 unusual (vision/concepts.md §2).
  - [x] Rubric table (7 criteria × concepts) and a pick/merge with reasons in D-005. — concepts.md §3–4; D-005.
  - [x] Pillars are testable. — 00_VISION.md §3 table ("A feature passes if…").
  - [x] Progression placement names requirements and rewards and explains why no vanilla step becomes pointless. — 00_VISION.md §6 (requires / gives / never gives / why intact).
- Iteration budget: critique happens in WP-014; self-check 1 pass here.
- Exit ramp: if no concept scores ≥4 everywhere, merge the two best and log the weak criterion.
- Log:
  - 2026-09-30: research → 14 concepts → rubric → merge (D-005); 00_VISION.md §1–6 written; 4 parked ideas → IDEAS.md. Self-check (weaknesses first): (1) rubric scores are one author's judgement — WP-014's fresh reviewer re-scores; (2) "what comes home" lists capabilities whose balance is unproven — Phase 2/BALANCE; (3) journey's Rumor stage depends on the WP-011 entry design — kept generic until then.

### WP-011 Vision II: entry and return path
- Phase / Milestone: 1 / —
- Tier: L
- Status: DONE
- Depends on: WP-010 (pillars)
- Goal: Pick the survival entry path and the way home from ≥12 ideas, including the Ancient City frame and a note-block/sound activation, weighing canon, distinctness from existing fan mods (RESEARCH §8) and modpack compatibility.
- Inputs (read ONLY these): 00_VISION.md pillars, RESEARCH.md canon #2–5 and §8, VANILLA_ANALOGS W5/W6.
- Deliverables: docs/DESIGN/vision/entry_path.md (ideas + rubric table + chosen design at concept level); D-006.
- Definition of Done:
  - [x] ≥12 ideas incl. the frame and a sound activation; ≥2 unusual. — 15 ideas (#1 melody, #3 souls+song, #8 disc, #9 horn, #10 chord…), 3 unusual (entry_path.md).
  - [x] Scored table; choice + return path + failure modes (portal griefing, multiplayer, frame shared with other mods). — entry_path.md rubric, chosen design, failure-mode table, perf notes; D-006.
- Iteration budget: self-check 1 pass; critique in WP-014.
- Exit ramp: fall back to the canonical frame with a distinct activation.
- Log:
  - 2026-09-30: key constraint found: Deep Dark/Ancient Cities have no natural spawns, so souls must also come from sculk-mining XP. Press pass showed rifts are the everyday DII entry; the sandbox reversal is justified in entry_path.md. Self-check (weaknesses first): (1) the XP pull might surprise players who aren't looking for the Sift (mitigated: small radius, visible trail, stops once awake; playtest item); (2) the 'any music' opener may feel too easy (the gate is the journey plus the soul cost; revisit if playtests say so); (3) arrival biome search can be slow on huge worlds (bounded radius, async-friendly; Phase 3 perf check).

### WP-012 Vision III: the dimension's rules
- Phase / Milestone: 1 / —
- Tier: M
- Status: DONE
- Depends on: WP-010
- Goal: Decide light, sky, fog, day/night, weather, beds/respawn, compasses/clocks/maps, natural spawning, fall/fluids, and what vanilla items do differently — marking which are environment attributes, timelines, or code.
- Inputs (read ONLY these): 00_VISION.md pillars, VANILLA_ANALOGS W1/W4/W5, RESEARCH.md §3.
- Deliverables: 00_VISION.md "Rules" table; docs/DESIGN/vision/rules.md if the table needs rationale.
- Definition of Done:
  - [x] Every rule listed in §6 Phase 1 has a decision and an implementation route. — rules.md table (light, sky, fog, day/night, weather, beds/respawn, compass/clock/maps, spawning, fall/fluids, vanilla items) with DT/ATTR/TL/CODE/VAN routes.
  - [x] ≥5 rule-set identities compared before choosing. — 6 identities (A–F) in rules.md.
- Iteration budget: self-check 1 pass.
- Exit ramp: default to Nether/End precedent for any rule without a Sift-specific reason.
- Log:
  - 2026-09-30: verified in source that vanilla clocks read `visual/sun_angle` (so clocks show the Tide for free) and that Nether portals only light in the Overworld/Nether. Changed the exit-ramp default from 'Nether/End precedent' to 'Overworld precedent', because the evidence says the Sift is serene, not hostile. Self-check (weaknesses first): (1) the aurora needs client sky code whose Fabric hook is unverified (marked Should); (2) the sun_angle track may draw a visible sun if the skybox is 'overworld' (decide in Phase 3: accept a Sift 'sun', or use skybox none plus a custom sky); (3) the shrieker rule needs a targeted hook (mixin record if no event exists).

### WP-013 Vision IV: core systems at concept level
- Phase / Milestone: 1 / —
- Tier: L
- Status: DONE
- Depends on: WP-010, WP-012
- Goal: Concept designs for the Tides (cycle, triggers, per-Tide changes, how players read/use them), the soul economy, healthy vs corrupted sculk, sound as a mechanic (if it survives the pillars), and the Illager occupation — each connected to ≥2 others.
- Inputs (read ONLY these): 00_VISION.md, RESEARCH.md §3–4, RESEARCH_BESTIARY.md, VANILLA_ANALOGS W4/E2/E4.
- Deliverables: docs/DESIGN/vision/systems.md (per system: ≥5 concepts (Tides/souls ≥8), rubric, pick); 00_VISION.md "Core systems" section; D-007….
- Definition of Done:
  - [x] Each system: diverge → rubric → pick, with the link map. — systems.md §1–6 (Tides 10 concepts, souls 10, sculk 6, sound 7, Illagers 6; link diagram); D-007.
  - [x] Tides mapped onto a clock/timeline feasibility sketch (no code). — systems.md §1 Feasibility (files, markers, tracks, custom attributes).
- Iteration budget: self-check 1 pass.
- Exit ramp: cut a system to "concept only / later" with a reason if it fails the pillars.
- Log:
  - 2026-09-30: feasibility spike (scratch copy, not committed code): custom env attribute + clock + timeline + custom dimension type all load and behave as designed; `/time` drives the Tide (evidence in VANILLA_ANALOGS W4). This retires weakness (2) below.
  - 2026-09-30: self-check (weaknesses first): (1) 'souls = XP' competes with enchanting; this is intended as a trade-off but needs BALANCE numbers; (2) custom environment attributes keyed on timelines are an untested assumption (Phase 3 spike); (3) Endure 'stronger variants' may read as a stat check unless the glow and behaviour changes are designed per mob (Phase 2).

### WP-014 Vision critique, freeze and Gate A
- Phase / Milestone: 1 / —
- Tier: XL
- Status: IN PROGRESS (critique round 2 of ≤3)
- Depends on: WP-010..013
- Goal: Independent adversarial review of 00_VISION.md (fresh reviewer, rubric only), fix, freeze, and present Gate A.
- Inputs (read ONLY these): 00_VISION.md, docs/DESIGN/vision/*, §7.1 rubric.
- Deliverables: critique log in 00_VISION.md; frozen vision; STATUS.md gate summary; Gate A message.
- Definition of Done:
  - [ ] ≤3 critique rounds by a fresh subagent; no must-fix left; every rubric score ≥4 (or accepted/cut/parked per §5.5 with reasons).
  - [ ] Vision marked FROZEN; Gate A presented (recommendation first, alternatives, default on "go").
- Iteration budget: critique rounds ≤ 3.
- Exit ramp: §5.5 critique cap.
- Log:
  - 2026-09-30 round 1 (fresh adversarial reviewer; vision docs + RESEARCH + 26.3 source, read-only): **FAIL**, 5 must-fix, 12 should-fix, 5 notes; 27 of 63 scores < 4. Full dispositions are in 00_VISION.md §10.
  - Before changing any design, every engine claim was re-checked in the 26.3 source, and all held:
    - weather is server-global (`Level.canHaveWeather`, `ServerLevel.advanceWeatherCycle`, `WeatherAttributes`);
    - `advance_time` gates all clocks;
    - a charged anchor explodes when `respawn_anchor_works` is false;
    - SkyRenderer draws the sun and moon at the attribute angles;
    - sculk XP is 1/5.
  - The same checks found one more error of that kind: the vanilla clock model reads the sun only in `minecraft:overworld` (26.3 jar `items/clock.json`), so "clocks show the Tide" was false.
  - Also recorded in VANILLA_ANALOGS W1/W4/E4:
    - the vanilla catalyst eats XP from any death;
    - `has_ceiling` side effects;
    - custom spawners are Overworld-only;
    - no Fabric per-dimension sky hook in 26.3.
  - Revisions: systems.md (T1′ per-Tide rules, a 30 000-tick cycle, the one-way soul ledger, N8, blight = vanilla sculk, 1.0 scope); rules.md (weather mixin, no sun or moon, clocks spin, bed rest, per-biome spawns, full attribute map); entry_path.md (crouch-to-offer, price 1 395 points, staged hints, bounded arrival search, explicit links); 00_VISION.md; D-006/D-007 revisions; new D-008 (weather mixin) and D-009 (1.0 scope).

## Phase 2+ (very coarse)
- Phase 2: content bible + roadmap → Gate B.
- Phase 3: architecture decisions, CI, first GameTest.
- Phase 4: M1 vertical slice → Gate C.
- Phases 5–8: production milestones, polish, hardening, release.
