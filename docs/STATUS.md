# STATUS (session 1, 2026-10-02)
- **Phase / Milestone:** M1 done; the owner's playtest reworks (`v0.1.1-alpha`, `v0.1.2-alpha`) done; M2 "the hunt" in design.
- **Autonomy:** **full-auto** (D-014). **The build to try:** https://github.com/Skisisksiskskskss/Trapisque/releases/tag/v0.1.2-alpha, the owner's second playtest rework (D-026); steps in `docs/PLAYTEST.md` (top section). **Use a new world.** The previous build: https://github.com/Skisisksiskskskss/Trapisque/releases/tag/v0.1.1-alpha
- **Current WP:** WP-064, the M2 blocks' design (lumen, tidewrack, the Endure bloom, the chime bell flower). M2's designs so far are frozen with their BALANCE sections: WP-060 (the hunt system), WP-061 (the Nester), WP-062 (the Bloombud).
- **Done this session:**
  - Phases 0–3 and M1 (WP-040..053).
  - The owner's playtest rework:
    - ichor became the Sift's water;
    - the terrain was rebuilt on vanilla's terrain functions, with rose spires and the Hollows;
    - textures redrawn from the teaser stills;
    - new blocks Sift Soil and Songwood Drapes;
    - songwood trees reshaped into groves;
    - the Blub remodelled after the first look.
  - The owner's second playtest rework (D-026):
    - ichor: a soap bubble's sheen blended corner to corner, less see-through, buoyant and slower;
    - no seas: Meadow ponds and the new Ichor Flats biome;
    - two songwood shapes (forking and tall) placed by biome noise;
    - a vanilla-grain texture pass.
- **Next 3 actions:**
  1. Answer the owner's notes on `v0.1.2-alpha` the moment they arrive.
  2. WP-064: the M2 blocks' design doc and critique (the "Sift has no buds" constraint binds its flora).
  3. The M2 code: WP-063 (Hollows, glowcap pools), WP-066 (the hunt system), WP-067/068 (Nester, Bloombud).
- **Build:** ✅ `./gradlew build` (with GameTests) · datagen no-diff ✅ · `check_bible.py` ✅ · `check_palette.py` ✅ (38 textures) · `check_lang.py` ✅
- **Tests:** 71/71 server GameTests. The client GameTest walks the entry, the Tides, a basin and the blubs, and its landscape shots (`look_*`) compare the land with the teasers.
- **Server boot:** ✅ (the GameTest dedicated server on every build).
- **Blockers:** none. The Netlify site `magnificent-gelato-563c55` fails on every PR because of its own configuration (owner-side; see the PR comment).
- **Awaiting owner:** nothing (full-auto). The playtest questions are in `docs/PLAYTEST.md`.

## Gate C: the M1 vertical slice — self-reviewed (D-014), 2026-10-01
**Situation.** M1 is complete. Every WP-040..053 DoD item is met or has a logged deviation:
- the rising-bubble basin visual is left for polish;
- the gate sanctuary rule waits for M2's hostile spawns;
- blub animations are procedural (D-021).

Two fresh adversarial reviews ran after the preview. The first found and reproduced a server crash (a blub riding itself); it is fixed and covered by an AI-on test. The second covered the frame cues, the advancements and the vents: it found six defects and no crash, all fixed in 76119d6 before the release.

**What M1 contains:**
- The Sift (Singer's Meadow) behind an Ancient City frame: breathe, notice, offer 30 levels, play music, cross.
- The Tide cycle with literal ichor basins.
- Ichor and its pools.
- The Blub, befriended by music: it sings back, heralds the Tide, shelters in Endure, bathes, stacks into towers and crosses with you.
- Four advancements and every sound with subtitles.

**Measured:**
- chunk generation 0.29× the Overworld;
- 50 basins p95 0.005 ms per tick;
- 50 busy blubs 0.87–1.22× rabbits;
- ichor 0.89–0.98× lava.

**Recommendation: ship `v0.1.0-alpha` as a pre-release and start M2.**
- **Alternatives:** hold for keyframed blub animations (cost: days, for little gain at this size); hold for basin bubbles (cosmetic).
- **Outcome:** full-auto, so it is released.

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
