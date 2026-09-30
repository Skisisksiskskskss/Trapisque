# DECISIONS

Numbered decision records (§8.5). Once decided, don't re-argue without new evidence; supersede with a new record instead.

Format: `## D-### <title> (<date>) [supersedes D-### if any]` then Context · Options considered · Decision · Why · Consequences · Revisit if …

---

## D-001 Target version and toolchain (2026-09-30)
**Context.** §4 lists 26.3, Java 25, Loader 0.19.5, Loom 1.17 (`net.fabricmc.fabric-loom`), Gradle 9.6.0, and asks us to verify every line from live sources (WP-001).

**Evidence (live, 2026-09-30).**
| Item | §4 said | Live value | Source |
|---|---|---|---|
| Latest stable MC | 26.3 (2026-09-15) | **26.3**, releaseTime 2026-09-15T11:23:02Z; latest snapshot 26.4-snapshot-2 (not a target) | piston-meta version_manifest_v2.json |
| version.json | protocol 777, data 5023, RP 97.1, DP 121.0, Java 25 | **identical**: protocol_version 777, world_version 5023, resource 97.1, data 121.0, java_version 25, stable true | `version.json` inside client.jar (sha1 e877b6a0…) |
| Obfuscation | unobfuscated | **confirmed**: version JSON has no `client_mappings`/`server_mappings`; Fabric intermediary for 26.3 = `0.0.0`; Yarn list for 26.3 is empty | piston-meta; meta.fabricmc.net |
| Fabric Loader | 0.19.5 | **0.19.5** (only stable 0.19.x) | meta.fabricmc.net/v2/versions/loader |
| Fabric API | "look it up" | **0.161.0+26.3** (newest `+26.3`; 0.161.1+ are `+26.4`) | maven.fabricmc.net fabric-api maven-metadata.xml |
| Loom | 1.17, id `net.fabricmc.fabric-loom` | Fabric blog (2026-09-15): "Loom 1.17 and Gradle 9.6.0 (at the time of writing)". Official example mod HEAD (26.3): `loom_version=1.18-SNAPSHOT`, same plugin id. Released: 1.17.21 (2026-09-15, needs Gradle ≥9.5.0, JVM 21), **1.18.2** (2026-09-16, needs Gradle ≥9.7.0, Gradle on JVM 25) | fabricmc.net/2026/09/15/263.html; raw.githubusercontent.com/FabricMC/fabric-example-mod/HEAD; Loom `.module` metadata |
| Gradle | 9.6.0 | Example mod wrapper: **9.7.1**; newest Gradle is 9.8.0 (2026-09-24) | example mod gradle-wrapper.properties; services.gradle.org |
| JDK | 25 minimum | **Temurin 25.0.4.1+1 (LTS)**, sha256 dbb69839…cf41e verified | api.adoptium.net |
| NeoForge | 26.3.0.26-beta | not re-checked (Loader = Fabric per §0) | — |

**Options.** (A) Loom 1.17.21 + Gradle 9.6.0 — the blog's snapshot-in-time recommendation. (B) Loom 1.18.2 + Gradle 9.7.1 — the line the official template now uses for 26.3, pinned to a release. (C) Loom 1.18-SNAPSHOT exactly as the template — floating, not reproducible.

**Decision.** MC 26.3 · Fabric Loader 0.19.5 · Fabric API 0.161.0+26.3 · **Loom 1.18.2** (`net.fabricmc.fabric-loom`) · **Gradle 9.7.1** · JDK 25 (Temurin 25.0.4.1+1), `--release 25`.

**Why.** §6 says trust live sources; the official template has already moved to the 1.18 line for 26.3, and pinning the newest *release* (not `-SNAPSHOT`) keeps builds reproducible. Gradle 9.7.1 matches the template's wrapper and satisfies Loom 1.18's ≥9.7.0.

**Consequences.** Gradle itself must run on JDK 25 (not just the compile toolchain). Fresh containers need JDK 25 provisioned (see WP-002 log for how).

**Revisit if.** Loom 1.18.2 fails to build/run 26.3 (exit ramp: option A); a 26.3.x hotfix release appears; the template pins a different Loom release; we move to a new MC release (never a snapshot).

---

## D-002 Official-Sift-content check (§3.3): not triggered (2026-09-30)
**Context.** §3.3: if Mojang has shipped official Sift content for Java (snapshots, experimental toggles, feature announcements), stop and tell the owner before building anything.

**Evidence.** (1) Full-content grep (paths, class constant pools, lang, data, built-in datapacks) of client jars 26.3, 26.4-snapshot-1, 26.4-snapshot-2: zero matches for "sift" other than random base64 in `META-INF` signatures. (2) minecraft.wiki changelog pages for 26.4 / its snapshots: no Sift content (26.4 = "Fourth Drop 2026": ice caves, frozen zombie, Freezing). (3) minecraft.wiki "Planned versions": the Sift is an "Unnamed 2027 release", "a version number has not been made public". (4) The only Java/Bedrock-side material is the Minecraft LIVE (2026-09-26) announcement with a short first-look clip (Blub + healthy-sculk grasses + pale-trunked trees under a teal sky) — see RESEARCH.md §0.

**Decision.** Not a §3.3 stop: nothing has shipped, and the LIVE announcement predates the mission and is its stated premise (§2). Continue Phase 0/1 as planned. Treat the LIVE first-look as the **highest-authority visual canon for a vanilla-styled Sift** (above Dungeons II visuals, which are a different art style), and flag this at Gate A.

**Why.** The mission's own premise already includes the announcement; no Java design detail (access method, Tides, mechanics) has been announced that could change the plan.

**Consequences.** Our Blub and first biome must be visibly compatible with the LIVE footage (teal sky, soft orange grass on hills, small glowing rabbit-like Blub).

**Revisit if.** Any Java snapshot/experimental toggle/feature announcement mentions the Sift → stop and tell the owner (§3.3). Re-check at every milestone start.

---

## D-003 Root package, entrypoints and licence scope (2026-09-30)
**Context.** The scaffold needs a Java root package now; Phase 3 decides the internal layout. The owner set MIT for code and All Rights Reserved for original assets.

**Options (package).** (A) reverse-DNS on the GitHub account (`io.github.skisisksiskskskss.thesift`) — conventional but long and tied to a username that may change; (B) `com.thesift` — implies a domain we don't own; (C) single-segment `thesift` — equals MOD_ID; established precedent among large mods (`twilightforest`, `mekanism`, `appeng`).

**Decision.** (C): common code in `thesift`, client-only code in `thesift.client` (split source sets: `src/main` / `src/client`). Entry points `thesift.TheSift` / `thesift.client.TheSiftClient`. Copyright holder "The Sift contributors". Licence scope (LICENSE-ASSETS.md): textures, sounds/music, previews **and the art/audio generator scripts under `tools/art/` and `tools/audio/`** are All Rights Reserved; everything else MIT.

**Why.** Short, collision-free in practice (namespaced by mod id), no borrowed domain. Generator scripts encode the artwork itself — leaving them MIT would make the "ARR assets" licence regenerable by anyone.

**Consequences.** Phase 3 decides sub-packages (registries, worldgen, entity, …) under `thesift`.

**Revisit if.** The owner wants a different package/copyright holder, or wants the generator scripts under MIT (flagged at Gate A).

---

## D-004 00_MISSION.md uses the owner's markdown source (2026-09-30)
**Context.** §10 says copy the prompt verbatim into `docs/00_MISSION.md`. The first copy was taken from the chat message, whose markdown had been flattened (tables → tab-separated text, headings/bold/code fences lost). The owner's original markdown is `sift-mod-prompt/SIFT_MOD_PROMPT.md` on branch `claude/minecraft-sift-mod-c88i2r` (open draft PR Skisisksiskskskss/Trapisque#1), whose README says to paste "everything below the first horizontal rule".

**Decision.** `docs/00_MISSION.md` = that file's text below the first `---`, byte-for-byte. Replaced once, in session 1, before anything depended on it.

**Why.** It is the same prompt (word-for-word identical after stripping markdown syntax: 33,884 normalized characters, zero differences) and it renders correctly, which matters for a file every session re-reads.

**Consequences.** None to content. From now on the "never edit" rule applies without exception.

**Revisit if.** Never (unless the owner supplies a new mission text).

---

## D-005 Vision direction: "the Deep Dark inverted, breathing with the Tides" (2026-09-30)
**Context.** Phase 1 needs one fantasy, a tone and 3–5 pillars (WP-010). Mojang's bar for a dimension: a functional "reason to exist" that distinguishes it (RESEARCH.md S-W1). Three fan mods already use the Ancient City frame, so distinctness must come from what the Sift is *for*.

**Options considered.** 14 concepts in `docs/DESIGN/vision/concepts.md` (Song Dimension, Soul Ecology, Tide World, Healing the Sculk, Resistance, Menagerie, Frontier, Mirror of the Deep Dark, Great Instrument*, Living Giant*, Echo Navigation*, Soul Storm Runs, Pastoral Haven, Singer's Choir; * = deliberately unusual), scored on the §7.1 rubric.

**Decision.** Merge **Mirror of the Deep Dark (33) + Tide World (33)**, made tangible by **song (30)** and **souls (29)**, with the Illager occupation and companions as content. Fantasy: *"The Sift is the living heart the Deep Dark lost: a luminous world of healthy sculk that answers sound instead of punishing it, where light, creatures and souls rise and fall with the Tides."* Pillars P1 Sound brings life · P2 The Tide sets the rules · P3 Souls are the lifeblood · P4 Wonder first, danger earned.

**Why.** It is the only combination whose reason to exist is a pair of verbs no dimension offers (*read the Tide, answer with sound*), taken straight from canon (the Tides are a "time cycle"; song opens the portal; healthy sculk thrives there), expressed in vanilla grammar (vibrations, note blocks, timelines), and it gives the Overworld something back.

**Consequences.** Every later feature must pass at least one pillar test (00_VISION.md §3) and link to ≥2 Sift systems. Unusual concepts are parked (single ideas may return via IDEAS.md).

**Revisit if.** The owner rejects the direction at Gate A, or Mojang reveals Java Sift mechanics that contradict it.

---

## D-006 Entry and return path: "souls wake it, song opens it" (2026-09-30)
**Status: superseded in part.** The payment and clock-start details below were revised twice. The current entry design is **D-010** and `DESIGN/vision/entry_path.md`.

**Context.** WP-011: a survival entry and return path. Canon: the Ancient City centre frame is the Sift portal, opened by the Note Block Machine / a Singer's song; rifts are the Illagers' temporary portals. Three fan mods already use the frame (RESEARCH.md §8).

**Options considered.** 15 ideas scored in `docs/DESIGN/vision/entry_path.md`: melody puzzle (23), three resonant note blocks (26), **souls wake it + song opens it (32)**, warden trophy (22), echo tuning fork (26), rift first (28), Illager rift incursions (26), Sift disc (25), goat horn (22), calibrated chord (23), allay escort (22), soul journey* (21), build-your-own gate* (26), Soul Sand Valley rifts* (22), bottled echo (26). (* unusual)

**Decision.** Every Ancient City frame starts dormant. It absorbs nearby experience orbs as visible souls until it is awake, and any music played before an awake frame opens it. Arrival is at a generated Sift-side gate in the nearest Singer's Meadow-type biome at 1:1 coordinates, with a no-hostile-spawn sanctuary radius. Return is through the linked gate; a broken gate reopens with music.

**Why.** It is the only option using both canon ingredients (souls and music) with self-teaching feedback and no new key item. It suits a sandbox better than Dungeons II's rift-first order (a landmark beats a random event; P4; minimal vanilla footprint), and it is distinct from existing mods' activations (melody puzzle, warden trophy, pedestal item).

**Consequences.** We need: frame location from Ancient City structure pieces (no block scans); an XP-orb attraction zone around known dormant frames; a vibration/music listener at awake frames; a portal block, a POI type, a Sift-side gate feature and a biome search for arrival. Soul cost is tuned in BALANCE.md. If another mod's portal occupies the frame, we don't act.

**Revisit if.** The owner prefers the canonical melody, rift-first, or a build-your-own gate at Gate A; Mojang reveals the vanilla access method; playtests show the XP pull is confusing or annoying.

**Revision (2026-09-30, WP-014 critique round 1).**
- **What changed.** The passive orb pull is replaced by a **crouch-to-offer** payment from the player's XP bar.
  - Price: 1 395 points (level 0 → 30), once per frame, which can be pooled.
  - Nothing is taken without consent.
  - Hints come in stages: souls "breathe" into the frame, it notices you, it wakes in steps, then note particles drift from it.
- **Why.** The critic showed the original price couldn't be paid on purpose: Ancient Cities have no mob spawns, and sculk drops 1–5 XP. Its target was also ambiguous, and it took XP without consent (MF5).
- **Also changed:**
  - The first opening starts the Tide clock at Thrive.
  - The membrane shows the far-side Tide.
  - Arrival search is bounded (256 blocks) with a fallback; gates stay ≥64 blocks apart; frame ↔ gate links are stored explicitly.
  - Gates are unbreakable.
- **Rescoring.** #3′ scores 28, tying rift-first. The tie is broken by hard rule 9.4 and P4.
- **Canon wording corrected.** The frame is Dungeons II's story portal location, not Java canon (RESEARCH §6).

---

## D-007 Core systems at concept level (2026-09-30)
**Status: superseded in part.** See the revision below, then **D-011** (the Tides) and **D-012** (blight). `DESIGN/vision/systems.md` is authoritative.

**Context.** WP-013: concept designs for the Tides, soul economy, healthy vs corrupted sculk, sound, and the Illager occupation, each linked to ≥2 others.

**Options considered.** `docs/DESIGN/vision/systems.md`: Tides T1–T10, souls S1–S10, sculk H1–H6, sound N1–N7, Illagers I1–I6 (unusual ones in italics), all rubric-scored.

**Decision.** (Feasibility of the Tide architecture verified by spike — VANILLA_ANALOGS W4.) Tides = **T1** day-like 24 000-tick cycle (Thrive 10k · Flow 2k · Endure 10k · Flow 2k) on a `thesift:tides` clock + timeline, with Sift gameplay values as **our own registered environment attributes** keyed on that timeline; T3 (Tide-shifting lever) as Should. Souls = **S1+S3+S4+S8**: souls *are* XP; healthy sculk banks and blooms with it; lossy soul blocks; Illager soul tanks. No HUD meter. Sculk = **H1+H2** (inversion + blight). Sound = **N1+N2+N3** (+N4/N5 content). Illagers = **I1+I5+I6** core, **I2** endgame, I3 deferred.

**Why.** Highest rubric totals; each keeps canon while using vanilla grammar (XP/catalyst, allay-style music liking, day-night-style timelines, outposts). Together they form one loop where every system feeds at least three others (systems.md §6).

**Consequences.** Phase 2 inventory derives from this loop. BALANCE.md must pin the soul↔XP loss rates and the Endure spawn buffs. Phase 3 must confirm custom environment-attribute registration and client sync.

**Revisit if.** The critique (WP-014) or the owner at Gate A rejects a system; implementation shows custom attributes can't be keyframed or synced as expected.

**Revision (2026-09-30, WP-014 critique round 1)** (systems.md is authoritative):
- **Tides = T1′.**
  - A 30 000-tick cycle (Thrive 12k · Flow 3k · Endure 12k · Flow 3k), one signature rule per Tide (growth and recharge / passage / hunters and rare blooms).
  - The clock starts paused at Thrive until the first opening.
  - The T3 lever moves only toward Thrive.
- **Souls = S1 + S3 + S4′ + S8, as a one-way ledger.**
  - S4, a sculk bank drawn out by song, is rejected: it was an XP amplifier (MF1).
  - Bloom hearts drink deaths like vanilla catalysts. Players offer XP by crouching.
  - Souls leave only as growth, fuel (soul blocks) or a frame's price. Nothing converts back to XP.
  - `soul_flow` defaults to 0 outside the Sift.
- **Sculk.** Blight is vanilla sculk. Illagers speed up an old disease rather than causing it. Cures work only in the Sift.
- **Sound.** Adds N8: in Endure, sound draws hunters. The gift of song affects only Sift life and never wardens.
- **Illagers.** Finite camps for 1.0; the Keep (I2) moves after 1.0.
- **Consequence for BALANCE.md.** No soul↔XP loss rates are needed any more, because no conversion back exists. It must instead pin the frame price, growth rates and soul-block cost.

---

## D-008 A weatherless Sift through one targeted mixin (2026-09-30)
**Context.** The rules say the Sift has no weather. In 26.3, weather state is **server-global** (`MinecraftServer.getWeatherData()`). Every level whose `Level.canHaveWeather()` is true, meaning it has sky light, no ceiling and isn't the End, counts down the shared timers each tick in `ServerLevel.advanceWeatherCycle`, and takes rain and thunder into its environment attributes (`WeatherAttributes`). An open-sky Sift would therefore:
- roughly **double the Overworld's weather speed**, which breaks hard rule 9.4;
- receive the Overworld's storms: a grey sky, no stars, and thunder-darkness that lets monsters spawn in Thrive.

These were verified in the 26.3 sources during WP-014.

**Options.**
- (A) `has_ceiling: true` in the dimension type (data only). It disables weather, but it also halves map radius and paints maps as ceiling noise (`MapItem`), changes world-generation spawn placement (`NaturalSpawner.getTopNonCollidingPos`), and changes respawn-height logic (`PlayerSpawnFinder`).
- (B) `has_skylight: false`. This kills Thrive's daylight.
- (C) A mixin making `Level.canHaveWeather()` return false when `dimension() == thesift:the_sift`.
- (D) Accept shared weather.

**Decision.** (C). One `@Inject(at = HEAD, cancellable = true)` into `Level.canHaveWeather()`, active only for our dimension key. It lives in common code, because `ClientLevel` inherits the method.

**Why.**
- It is the smallest change that keeps maps and spawns vanilla and leaves the Overworld's weather exactly as it is.
- Every other weather path (`isRaining`, `isThundering`, the attribute layer, weather packets) already keys off this method.
- It is the project's first mixin; D-003 requires a record for each.

**Consequences.**
- The mixin config is added in Phase 3 with this single target.
- A GameTest must check two things: the Sift never rains while the Overworld does, and the Overworld's weather timers advance one step per tick with the Sift loaded.
- Commands like `/weather` in the Sift affect the Overworld (shared state) but never show in the Sift.

**Revisit if.** Fabric API or vanilla adds a data-driven weather switch for dimensions; the mixin conflicts with another mod targeting the same method (then use a lower-priority injector or an API).

---

## D-009 Scope of 1.0: one boss, one miniboss (2026-09-30)
**Status: revised after critique round 2** (see the revision at the end of this record).

**Context.** Critique round 1 (SF10) found the draft over-scoped against "fewer, deeper". It promised four bosses (Monstrosity, Monarch, Harmonizer, a Keep lieutenant), plus a new fluid, an aurora, companions, gear, camps, tanks and gates. Vanilla dimensions have at most one boss each.

**Options.**
- (A) Keep all canon bosses.
- (B) One boss, the **Sculk Monstrosity** (the blight's heart, fought in the Meadow's questline), plus the Harmonizer as miniboss.
- (C) One boss, the **Monarch** (apex hunter of Endure, in the Carapace), plus the Harmonizer.

**Decision (proposed, confirmed at Gate A).** (B).
- The Monstrosity's canon "catalysis" attack is vanilla catalyst grammar turned into a weapon, and beating it cures the land around its arena. That closes the blight storyline (P3).
- The Monarch, the Illager Keep, rifts, the Tide lever and an aurora sky go to the post-1.0 roadmap. The aurora needs a client mixin, because 26.3 Fabric API has no per-dimension sky hook.

**Why.** It is the smallest endgame that still exercises every pillar, and it matches vanilla's one-boss-per-dimension rhythm.

**Consequences.** The Phase 2 inventory lists only these two bosses as Must. The Monarch's sculker nest is designed as a post-1.0 expansion hook.

**Revisit if.** The owner prefers (C) or (A) at Gate A.

**Revision (2026-09-30, WP-014 critique round 2).** The reviewer found 1.0 still too large, and the Singer, who grants the gift of song, missing.
- **1.0 is now one region done deeply: Singer's Meadow.** It includes Lullaby Hills as a sub-biome and the tide basins.
  - **Natives:** Blub, Echo Golem, Slabber, **Singer**; Trills as particles.
  - **Hostiles:** Bloombud, Nester (the listening hunter), Pollinator, Sprout.
  - **Bosses:** the Sculk Monstrosity (boss) and the Harmonizer (miniboss).
- **1.1:** the Carapace, its sculkers (Stalker, Scavenger) and the Monarch.
- **Precedent:** the Nether and the End each shipped as one biome at first.
- **Alternative for Gate A:** keep the Carapace in 1.0 and move the Monstrosity to 1.1.

---

## D-010 Entry payment by deliberate action; the Tide clock starts at the first crossing (2026-09-30)
**Context.** Critique round 2 (MF2) showed that paying by crouching in the opening inferred consent from the Deep Dark's stealth posture: `#ignore_vibrations_sneaking` makes crouching the default there. It also found jukeboxes aren't vibrations (SF3), and that starting the clock at the first *opening* doesn't guarantee a Thrive arrival (SF4).

**Decision.**
- Offering is a **deliberate hold-*use*** with an empty hand, on the frame or on a bloom heart. XP streams at about 50 points per second; releasing stops it. Detection uses Fabric `UseBlockCallback` on known frame positions, with no per-tick scan.
- Music is detected by a vibration listener (`note_block_play`, `instrument_play`) plus a separate `jukebox_play` listener at vanilla's radius of 10, as `Allay.JukeboxListener` does.
- The Tide clock is paused at Thrive by startup code (clocks default to unpaused) until the world's **first crossing**.

**Why.** Vanilla spends XP only on a deliberate action (the enchanting table, the anvil), so this matches vanilla grammar. Brushing is the precedent for a hold-to-act verb. Each part was checked in the 26.3 source.

**Consequences.** BALANCE.md pins the offer rate and the 1 395-point price. The frame needs a use hook, two listeners and a saved "first crossing" flag.

**Revisit if.** Playtests show players don't think to *use* the frame. The fallback is a stronger visual hint, not a posture trigger.

---

## D-011 The Tides are literal ichor tides; one hearing rule (2026-09-30)
**Context.** Critique round 2 (MF1) found three problems:
- T1′ was still day/night plus one rule each.
- Flow's tide-bridges could be bypassed with blocks.
- Giving Flow bespoke rules contradicted the H-level canon "Flow: No effect".

Hearing was also defined two ways.

**Decision.**
- **T1″: ichor rises and falls in generated tide basins.** Thrive is low tide (the flats are bare; flat-only reagents; growth). Flow is the tide moving (no effect on the player). Endure is high tide (flooded flats; hunters; Endure blooms at the waterline).
- **The hearing rule:** only in Endure, each area's hunters (1.0: Nesters) hear the vibrations a sculk sensor hears, out to a warden's 16 blocks (a sensor hears 8; corrected in D-013's round), plus jukeboxes within 10. A vanilla vibration particle is the tell.
- Tide-bridges are cut.

**Why.**
- It gives each Tide a visible state that blocks can't bypass: what is *exposed* changes, not who can cross.
- It reads canon's "affect … traversing" literally, and keeps Flow effect-free for the player.
- It reuses ichor, a canon hazard, instead of adding a new system.

**Consequences.**
- One controller block entity per basin: it moves one layer at a time during Flow, only in loaded chunks, and snaps to the current level on chunk load.
- Basin ichor never spreads outside the basin.
- Hunters need a `VibrationSystem` and a jukebox listener.

**Revisit if.** Basin updates cost too much in profiling (fallback: smaller or fewer basins); playtests show the waterline is too subtle.

---

## D-012 Blight is its own XP-free block family, spreading only around active camps (2026-09-30)
**Context.** Critique round 2 (MF3) found that making blight *vanilla* sculk (the round-1 fix) leaked experience: mined sculk drops 1–5 XP, and every vanilla catalyst would have made a blight patch a sculk farm. It also left open whether the occupation is static or dynamic (SF6).

**Decision.**
- Blight is **our own block family** copying the Deep Dark's grammar: a pulsing texture, creeping veins, tendrils that listen, shriekers.
  - It drops no XP.
  - Its shriekers give Darkness and alert hunters, and never touch the vanilla warden warning tracker.
- Healthy sculk is petalled and **never pulses**, so the two differ in shape and motion, not only in colour.
- Blight spreads only within a capped radius of an **active** Illager rig. It stops when the rig is broken. Cured land stays cured.
- Vanilla sculk placed by players behaves exactly as vanilla.

**Why.** It closes the XP side door without mixins into vanilla blocks, and keeps non-colour readability. It also makes the occupation visibly change the land, which vanilla outposts don't do.

**Consequences.** Phase 2 must write the art rules (pulse vs still, vein vs petal) into the content bible. Spread is a bounded, per-camp operation.

**Revisit if.** Art review shows the two families aren't distinguishable without colour.

---

## D-013 Round-3 system fixes: a scope gate, a hunter retreat, wade-through ichor (2026-09-30)
**Context.** Critique round 3 (the last) found four problems:
- `soul_flow` served as both a **scope** gate and a **rate**. At 0 in Endure, it switched off bloom hearts, the gift of song and gear traits exactly when they matter (MF1).
- Thrive never cleared Endure's hunters: `monsters_burn` is off, and mobs despawn only far from players (MF2).
- Ichor as described needed undisclosed engine work, because vanilla gives currents and swimming only to water and lava (`Entity.FLUIDS_WITH_CURRENT`) (SF2).
- Wardens could follow players through the membrane (SF4).

**Decision.**
- **Scope vs rate.** A boolean attribute `thesift:gameplay/sift_life` (true in the Sift in every Tide, false elsewhere) gates scope. `soul_flow` is a rate only.
- **Hunter retreat.** At falling Flow, surface hostiles burrow away with a telegraphed dig animation, particles, a sound and a subtitle, and are gone by Thrive. Cave dwellers stay.
- **Ichor.** It is a thick liquid you **wade** through: no swimming, no currents. Slowing, burning (vanilla fire plus soul-flame particles) and the XP drain happen in our liquid block's `entityInside`, so no Entity mixin is needed. Fire Resistance stops the burning but not the drain. Tide basins sit inside one chunk each, and their flats follow the Tide logically.
- **Portal filter.** Our portal block passes only entities outside `#thesift:cannot_cross` (wardens and bosses).

**Why.** Every part avoids a second mixin, keeps vanilla grammar (the warden's dig, powder-snow-style wading, vanilla fire and Fire Resistance), and closes a hole the reviewer demonstrated in the source.

**Consequences.** Phase 3 must spike the wade-through ichor and a basin controller before either counts as feasible. The fallback is static ichor pools and no basins (the Tides would then rely on sky, hearing, retreat and growth).

**Revisit if.** The spike shows a wading liquid feels wrong. The alternative is a small Entity mixin extending fluid physics to `#thesift:ichor`, with its own decision record.

---

## D-014 AUTONOMY is full-auto from Gate A on (2026-09-30) [overrides §0 AUTONOMY = checkpoints]
**Context.** `00_MISSION.md` §0 set `AUTONOMY: checkpoints` (stop at Gates A/B/C). At Gate A the owner wrote: "If u want my input, DONT … I want everything to be done without me being there." The mission file is never edited, so the change is recorded here.

**Decision.** From 2026-09-30 the project runs as **full-auto** (§0: "never stop. Decide, log the decision in DECISIONS.md, keep going").
- Gates A, B and C become **self-reviews**: the gate summary goes into STATUS.md, the recommended option is taken, and work continues (§5.7).
- The remaining reasons to stop are the mission's own exceptions: §3.3 (official Sift content found), a legal or licensing question, or a problem that makes a Core feature impossible. Even then, I write the issue down, take the safest reversible option, and keep going wherever I can.

**Gate A self-review.** The recommendation in STATUS.md's Gate A section is taken as the owner's default:
- the vision stays frozen as written;
- the entry is the soul offering plus music;
- the Tides are the literal ichor tide;
- 1.0 is Singer's Meadow only;
- the boss is the Sculk Monstrosity.

The listed alternatives remain recorded in D-006/D-009/D-011 if the owner ever wants them.

**Revisit if.** The owner says otherwise.

