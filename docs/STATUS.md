# STATUS (session 1, 2026-09-30)
- **Phase / Milestone:** Phase 1 complete → **Gate A (waiting for the owner)**. Phase 0 is complete (WP-001 to WP-007 DONE).
- **Current WP:** none in progress. WP-014 is DONE; the vision is FROZEN for Gate A.
- **Last session:**
  - **Phase 0:**
    - toolchain pinned (D-001); no official Java Sift content (D-002);
    - the scaffold builds, the dedicated server boots, and the headless client works;
    - 26.3 sources studied (VANILLA_ANALOGS).
    - Research passed review round 3: 273 quotes machine-verified against the saved sources, 0 mismatches.
  - **Phase 1:** the vision went through 3 adversarial critique rounds (5 → 3 → 2 must-fix, all fixed), then the §5.5 cap (D-005 to D-013).
- **Next 3 actions (after the owner replies):**
  1. Apply any Gate A changes the owner asks for.
  2. Phase 2: write the Phase 2 WPs into PLAN.md (content bible, roadmap, M1 slice).
  3. Start the content bible (01_CONTENT_BIBLE.md) from the frozen vision's Must/Should/Could tiers.
- **Build:** ✅ scaffold (`./gradlew build` green, `-Xlint:all` clean)
- **Tests:** 0/0 (none yet; Phase 3)
- **Server boot:** ✅ (runServer "Done", no `thesift` warnings)
- **Blockers:** none. The Netlify site `magnificent-gelato-563c55` fails on every PR because of how it is configured (owner-side; see the PR comment).
- **Awaiting owner:** Gate A (below).

## Gate A: the vision (Phase 1)
**Situation.**
- Phase 0 and Phase 1 are done. The empty mod builds and both the server and a headless client boot on 26.3. Mojang has shipped no Sift content for Java.
- The canon research passed review.
- The vision (`docs/DESIGN/00_VISION.md`) survived three adversarial rounds and is frozen. Changes made after the last round were not re-reviewed; their scores are dispositioned in §10.

**Recommendation: approve the vision as frozen.**
- **Entry:** hold *use* on an Ancient City frame to offer your experience (level 0 → 30, once per frame, and players can pool it). Then any music opens it into the Sift.
- **Tides:** a 25-minute cycle, and the tide is literal. Ichor basins drain in Thrive and flood in Endure; Flow is the tide moving.
- **Endure:** Nesters hear what a sculk sensor hears, out to a warden's range, and burrow away at dawn.
- **Souls:** a one-way soul ledger; nothing ever turns back into XP.
- **Blight:** our own XP-free blocks, spreading only around active Illager camps.
- **1.0:** one region done deeply, Singer's Meadow. One boss, the Sculk Monstrosity.

*Why:* it uses canon's own ingredients (souls, music, the Tides, ichor). Each step teaches the next. It keeps vanilla intact: no free XP, no power over wardens, and the Overworld's weather untouched, needing one small mixin. It scopes 1.0 to what can be done well.

**Alternatives (one line each):**
- **Entry = the canonical 8-note melody:** closest to Dungeons II, but it is exactly what the fan mod "Mielon's The Sift" already does on 26.3.
- **Entry = rift-first:** canon's everyday way in, but random Overworld portals strand players and widen the vanilla footprint.
- **1.0 scope:** keep the Carapace (sculkers) in 1.0 and move the Sculk Monstrosity to 1.1.
- **1.0 boss:** the Monarch instead (needs the Carapace in 1.0).
- **Tides:** a plain day-like cycle without the ichor tide. Cheaper, but the reviewers judged it too close to vanilla day and night.

**Also for you (no action needed unless you object):**
- **Name:** "Mielon's The Sift" (mod id `the_sift`) is a different mod with a near-identical name. Ours is `thesift`, so nothing collides, but players may confuse them. Every listing carries the unofficial disclaimer.
- **Licence:** the ARR assets licence also covers the art and audio generator scripts (D-003).
- **EULA:** the Minecraft EULA was accepted in the git-ignored `run/` folder so the dev server could start.
- **Mixins:** one planned (weather, D-008). Phase 3 will spike the wade-through ichor and the tide basins first (D-013), with a fallback to static pools.
- **Netlify:** the site `magnificent-gelato-563c55` fails on every PR because of its own configuration.

**If you reply "go":** the vision stays frozen as recommended, and Phase 2 starts: the content bible and roadmap, ending at Gate B.

## Environment notes for a fresh session
- Gradle downloads JDK 25 itself (`gradle-daemon-jvm.properties`).
- Headless client: `tools/dev/headless-client.sh start|screenshot|stop` (installs xvfb and mesa-vulkan-drivers if missing).
- To study vanilla: run `./gradlew genSources`, then unzip `.gradle/loom-cache/minecraftMaven/net/minecraft/minecraft-{common,clientOnly}-*/26.3/*-sources.jar`.
- Research page text lives only in the session scratchpad (third-party copyright); its metadata is in `docs/research/`.
