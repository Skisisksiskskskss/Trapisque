# STATUS (session 1, 2026-10-01)
- **Phase / Milestone:** Phase 4 (M1). Phases 0–3 are done; Gates A and B were self-reviewed.
- **Autonomy:** **full-auto** (D-014). **Deadline (D-018):** the owner tries the mod by 2026-10-04. **`v0.1.0-alpha.preview` is published** as a GitHub pre-release: dimension, Meadow, Tides, entry and return, ichor, basins, all sounds. Its playtest guide is `docs/PLAYTEST.md`.
- **Current WP:** WP-052 (entry advancements, lang pass), then WP-053 (M1 integration, Gate C) and `v0.1.0-alpha`.
- **Done this session:** WP-020..024; WP-030..033; WP-043; the Blub, WP-048..051 (design frozen, art, audio, AI, 12 GameTests). The cores of WP-040, 041, 042, 044, 045, 046 and 047 are done; PLAN.md logs list what is left in each.
- **Next 3 actions:**
  1. A fresh adversarial review of the Blub code; fix what it finds.
  2. WP-052: the Sift advancement tab and a lang pass.
  3. WP-053: the M1 leftovers (dormant-frame cues, cost measurements), Gate C, and release `v0.1.0-alpha`.
- **Build:** ✅ `./gradlew build` (with GameTests) · datagen no-diff ✅ · `check_bible.py` ✅ (144 rows) · `check_palette.py` ✅ (34 textures)
- **Tests:** 65/65 server GameTests. The client GameTest finds a natural Ancient City, opens it and crosses. It screenshots the Tides, a basin, the gate and the blubs (`docs/previews/`).
- **Server boot:** ✅ (through the GameTest server on every build).
- **Blockers:** none. The Netlify site `magnificent-gelato-563c55` fails on every PR because of its own configuration (owner-side; see the PR comment).
- **Awaiting owner:** nothing (full-auto). The preview's playtest questions are in `docs/PLAYTEST.md`.

## Gate B: the content bible and roadmap (Phase 2) — self-reviewed (D-014)
**Situation.**
- The content bible (`docs/DESIGN/01_CONTENT_BIBLE.md` + `bible/`) went through three fresh reviews: FAIL (3 must-fix), FAIL (1 must-fix), then **PASS** (all scores 4). It is frozen.
- D-016 and D-017 record the design changes the reviews forced.

**What 1.0 contains (Singer's Meadow):**
- Biomes: the Meadow, the Hollows and Hymnstone Rise.
- The literal ichor tide.
- Entry through Ancient City frames.
- Creatures: Blub, Nester, Bloombud, Echo Golem, the Singer (with its gift-of-song quest), Illager camps, and the Sculk Monstrosity as boss.
- Roughly 60 blocks across hymnstone, healthy sculk, songwood and blight.
- 11 Core advancements.

**Roadmap:** M1 slice → M2 the hunt → M3 souls → M4 the occupation → M5 the Meadow's life → M6 the heart of the blight → 1.0.

**Recommendation: approve the frozen bible.**
- **Alternatives:** keep five milestones (M2 would be overloaded); keep the literal tide out of M1 (the slice wouldn't show why the dimension exists); give blubs soul-block fuel (the finished Blub would slip to M3).
- **Outcome:** full-auto, so the recommendation is taken and Phase 3 has started.

## Gate A: the vision (Phase 1) — self-reviewed (D-014)
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

**Outcome:** the owner asked for full autonomy (D-014), so the recommendation was taken: the vision stays frozen as written, and Phase 2 started.

## Environment notes for a fresh session
- Gradle downloads JDK 25 itself (`gradle-daemon-jvm.properties`).
- Headless client: `tools/dev/headless-client.sh start|screenshot|stop` (installs xvfb and mesa-vulkan-drivers if missing).
- To study vanilla: run `./gradlew genSources`, then unzip `.gradle/loom-cache/minecraftMaven/net/minecraft/minecraft-{common,clientOnly}-*/26.3/*-sources.jar`.
- Research page text lives only in the session scratchpad (third-party copyright); its metadata is in `docs/research/`.
