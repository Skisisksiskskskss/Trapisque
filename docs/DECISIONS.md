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


---

## D-016 Content-bible round-1 fixes: the literal tide in M1, six milestones, and scope rules (2026-09-30)
**Context.** The fresh review of the content bible (WP-024 round 1) failed it with three must-fix findings:
- the gift of song had no quest;
- Core content had no milestone;
- the M1 Blub depended on M2 content.

It also found that M1's Tide changed nothing in play (SF4), since the mission asks for "the thinnest slice through **everything**".

**Options considered.**
- **Literal tide:** (a) keep it in M2 and accept an M1 Tide that is only the look; (b) move ichor and one basin into M1 *(chosen)*; (c) move all basin content, tide marks and tidewrack included, into M1 (too thick for a slice).
- **Milestones:** (a) keep five, with an overloaded M2; (b) split into six *(chosen)*.
- **Blub fuel:** (a) blubs need soul blocks as the vision says, which pushes the finished Blub past M3; (b) pets need no fuel and only work needs it *(chosen)*.
- **Quest:** (a) an NPC dialogue quest (not vanilla); (b) a place that shows its own progress, like an end portal frame *(chosen)*; (c) requiring a freed golem at the grove (it chains two AI systems).

**Decision.**
1. **The literal tide moves into M1.** M1 ships ichor in core form (wade, slow, burn, drain, bucket that evaporates outside the Sift) and **one kind of tide basin** (the vent controller, filling in Endure and draining in Thrive). Both are spiked in Phase 3 (WP-034) first. Tide marks, tidewrack and Endure blooms stay in M2.
2. **Six milestones.** M1 slice · M2 the hunt · M3 souls · M4 the occupation · M5 the Meadow's life · M6 the heart of the blight, plus a Could pool. Every Core and Should row names its milestone, and `tools/docs/check_bible.py` enforces it.
3. **Companion fuel applies to work.** The vision says companions run "on soul blocks" (00_VISION §3; rules.md "What comes home"). This narrows it: **working** companions (echo golems) need a soul block to work; the **Blub is a pet** and needs no fuel. A player befriends a blub by playing music for it, by hand: the game event of a hand-played note block or a goat horn names the player (verified in `NoteBlock.playNote` and `InstrumentItem`).
4. **The gift-of-song quest** (bible/items.md §1.1):
   - Three chorus stones per Singer's grove, each filled with a soul block. Soul blocks come from camp loot (stolen) or from your own XP at a bloom heart.
   - Music played at the Singer outside Endure completes it.
   - The grove's restored state is shared by the world. The horn is one per player per grove (the vault's `rewarded_players` precedent).
5. **The horn's recharge** keeps the vision's ratio: Thrive is twice Flow, and Endure gives nothing. It is read from the Tide, not proportional to `soul_flow` (whose 1.0 / 0.25 / 0.0 would make Thrive 4×). `soul_flow` still drives growth.
6. **The horn outside the Sift** plays as an instrument, like a goat horn. So it can open an awake frame, as entry_path.md says, while its Sift effects still need `sift_life`.
7. **Tier moves:**
   - Trills go from the vision's Could to Core. They are the Tide timeline's ambient particle, a non-colour Thrive cue (P1), and cost nothing beyond the timeline WP.
   - Lumen gains a Sift-only function: it repels the Sift's hunters, on the precedent of piglins avoiding soul fire.
   - "Blub towers as platforms" stays Could. Stacking itself is Core (the vision's pick N2′).

**Why.**
- The literal tide is the vision's first pillar, and Gate A accepted a Tides · Distinct score of 3 because of the basins. A slice without it can't show why the dimension exists.
- The companion and quest rules close gaps the vision left for Phase 2, and they use vanilla precedents (the vault, soul fire).

**Consequences.**
- M1 grows by two WPs, for ichor and the basins (PLAN.md WP-044/045). The Phase 4 WPs are renumbered to WP-040..053.
- The M2+ content moves down a milestone as listed in the bible.

**Revisit if.** The WP-034 spikes fail, in which case M1 falls back to static ichor pools and the basins move to M2. Also revisit if playtests show music befriending is too easy.

---

## D-017 Content-bible round-2 fixes: sources, music reactions, horn rules, fallbacks (2026-09-30)
**Context.** Round 2 of the fresh bible review (WP-024) failed on:
- one must-fix: the bloom heart had no source before M4;
- Feasible 3;
- 11 should-fix items, among them unplanned music reactions, horns that could be stacked, Singer edge cases, milestone-order slips, and fallbacks that disagreed.

**Options considered.**
- **Bloom heart source:** (a) a crafting recipe from M2 reagents, which would make a catalyst-like block craftable, something vanilla never does; (b) a rare worldgen **bloom patch**, taken with Silk Touch like a sculk catalyst *(chosen)*.
- **Music reactions:**
  - (a) server-side block entities or scans (too costly, §7.8);
  - (b) a mixin into game-event dispatch;
  - (c) a client `SoundEventListener`, the vanilla subtitle hook, feeding `animateTick` *(chosen: no mixin, no server cost)*.
- **Horn charges:** (a) stored on the item, which lets several horns bypass "none in Endure"; (b) stored on the player *(chosen)*.
- **Singer death:** (a) it can die (the grove softlocks); (b) it's invulnerable (vanilla has almost none); (c) it fades at zero health and returns at the next Thrive *(chosen)*.

**Decision.**
1. **Bloom patches** (M3): rare, in the Meadow and the Hollows. A heart drops itself with Silk Touch; otherwise it drops nothing, and never XP.
2. **Music reactions are client-side and cosmetic** (world.md §3.2). They run in every dimension, so the vision's Could "home-decoration reactions" ships as Core in M1 at no extra cost. Healthy sculk has **no block light**: its music "glow" is glowing petal particles. This replaces the "soft, steady glow" wording.
3. **The Singer's horn** (items.md §1.2):
   - Charges are a persistent per-player attachment, shared by every horn the player holds.
   - "Calm" means a 10-second **lull** on hunters targeting the singer. The song is still a vibration that calls hunters from farther out.
   - A song opens a musical gate whatever its key.
4. **The Singer can't die.** At zero health it fades into its grove's bloom heart and returns at the next Thrive.
   - A held soul block makes it point to an empty chorus stone.
   - Horns go only to players present when the song completes.
5. **Songwood** gets a sapling in M1. It grows only where `sift_life` is true. The full songwood set, with lullvine, moves to M3, before Hymnstone Rise's lullvine curtains need it. The Hollows' blight seams are an M4 addition.
6. **Recorded changes from the frozen vision:**
   - Blight keeps the vision's colour ("the colour of the Deep Dark"). It is told apart from vanilla sculk by shape, not by a new palette. Round 1's §3.1 draft had changed the colour, and that change is undone.
   - The Sift-side gate's "hill of red healthy sculk" (entry_path.md) is built from red hymnstone capped with coral healthy sculk, because the bible defines no red sculk block.
   - "Blub towers as platforms" stays Could, and now has its own row.
7. **One fallback per spike** (WP-034):
   - **Stacking fails:** stacking moves to M2.
   - **Basins fail:** M1 ships static ichor pools with a level marker. The M1 Blub follows the pool edges in Flow instead of a moving waterline. One more basin attempt opens M2; if that also fails, the vision's D-013 fallback (no basins) applies.
8. **The advancement tab's root** is "The Sift" (be noticed by a frame), the easy first step, as vanilla roots are.

**Why.**
- The fixes remove a survival dead end (M3) and an exploit (stacked horns), and close a softlock (a dead Singer).
- They turn two paper features (the songwood and healthy-sculk reactions) into a mechanism that costs the server nothing.

**Consequences.**
- The M1 WPs gain dependencies and DoD checks (PLAN.md).
- `check_bible.py` is hardened.
- WP-030 records its architecture decisions as D-018 onward.

**Revisit if.** Client-side reactions feel detached from gameplay music in multiplayer. A player far away hears less, so they see less. That matches vanilla subtitles.

---

## D-018 Schedule: a playable build by the end of the week (2026-09-30)
**Context.** The owner wants to try the mod by the end of this week (2026-10-04). They said: "im not saying go back to working carelessly … every second counts, and try saving some times."

**Options considered.**
- (a) Keep the full sequence and ship M1 when it's done; that probably misses the week.
- (b) Cut quality bars to hit the date; the owner ruled this out.
- (c) Keep every quality bar, pipeline the work, and ship an early **preview build** as soon as the core loop runs *(chosen)*.

**Decision.**
- **Pipelining.** Phase 3 code starts while the last bible review runs, and WPs that don't touch the same files overlap. Commits stay per WP.
- **Preview build first.** It needs the dimension, Meadow terrain with block set I, entry and return, the Tide core, and ichor with basins. It is tagged `v0.1.0-alpha.preview` when it builds, boots, passes its tests and runs in a headless walkthrough. The Blub, the final art passes, audio and advancements follow in the M1 build (`v0.1.0-alpha`).
- **Right-sized ceremony.**
  - Small design docs (system_entry.md, the biome doc) get one critique round.
  - system_tides.md and blocks_set1.md get one round plus a self-review.
  - The Blub, the one finished mob, keeps the full three rounds.
  - Tests, datagen no-diff, a clean server boot and previews that are actually looked at stay mandatory.

**Why.** The owner's date is a real constraint. Pipelining and a preview build move the first playable moment forward without lowering any bar.

**Consequences.** PLAN.md gets a "Preview build" line in Phase 4. STATUS.md tracks the date.

**Revisit if.** The preview slips past 2026-10-03. In that case ship whatever runs, with its known issues written into PLAYTEST.md.

---

## D-019 Architecture: packages, registration, split, payloads, state, config, tests, CI (2026-09-30) [WP-030]
**Context.** Mission Phase 3 requires a recorded decision for each architecture topic before content lands. Facts checked in the 26.3 sources and Fabric API 0.161.0:
- Vanilla registers blocks and items with `Properties.setId(key)`. `Blocks.register(ResourceKey, …)` is access-widened to public by Fabric.
- World clocks sync to clients in `ClientboundSetTimePacket`.
- `DimensionEvents.MODIFY_ATTRIBUTES` sets attribute values per dimension.
- `SavedDataType` is a record of id, constructor, codec and data-fixer type.
- Fabric client datagen runs inside `Minecraft.<init>` after the render backend starts, so it needs a display.
- Loom 1.18 offers `fabricApi.configureDataGeneration` and `configureTests`.

**Options considered.**
- **Registration:** DeferredRegister-style suppliers (not Fabric's idiom) vs static holder classes that mirror vanilla *(chosen)*.
- **Datagen:** hand-written JSON (error-prone) vs Fabric datagen *(chosen)*, with client datagen under xvfb.
- **Tide sync:** a custom payload vs vanilla's clock sync *(chosen: no payload)*.
- **Tests:** tests in the main jar vs a separate `gametest` source set that doesn't ship *(chosen)*.

**Decision.**
1. **Packages.**
   - Common: `thesift` (entry, `id()`) and `thesift.registry` (`ModBlocks`, `ModItems`, `ModFluids`, `ModEntities`, `ModBlockEntities`, `ModSounds`, `ModAttributes`, `ModParticles`, `ModTags`, `ModCreativeTab`).
   - Feature packages: `thesift.world` (dimension keys, Tide logic, saved data), `thesift.block`, `thesift.fluid`, `thesift.entity.<mob>`, `thesift.entry` (frames, membrane, gate).
   - Mixins: `thesift.mixin` (the weather mixin only, D-008).
   - Client: `thesift.client` (renderers, models, animations, fluid rendering, music reactions, item properties).
   - Datagen: `thesift.datagen` in the client source set (`fabric-datagen` entrypoint).
   - Tests: `thesift.test` in the `gametest` source set.
2. **Registration.** Static final fields in holder classes. The helpers mirror vanilla: `register(name, factory, properties)` calls `properties.setId(key)`, then `Registry.register`. `TheSift.onInitialize` calls each holder's `init()` in a fixed order. **Dynamic registries** are authored in datagen: bootstrap methods on a `RegistrySetBuilder` for the dimension type, noise settings, biomes, configured and placed features, the world clock and the timeline, written by a `FabricDynamicRegistryProvider`. The keys live in `thesift.world.ModWorldgen`.
3. **Client/server split.** Loom's split source sets. Common code never references client classes. The server is authoritative, and client code only renders.
4. **Networking.** No custom payloads in M1: the Tide state reaches clients through vanilla clock sync and environment attributes. A later payload is a record with a `StreamCodec`, registered through `PayloadTypeRegistry`, one per message.
5. **Persistent state.**
   - World-global state (first-crossing flag, frame charges, gate links) is `SavedData` with a `SavedDataType` codec, stored in the Overworld's data storage.
   - Per-location state (tide vents, chorus stones) lives in block entities.
   - Per-player state (song charges, M4) is a persistent Fabric data attachment.
6. **Config.** None. Server-admin switches, if any, are gamerules (vanilla's idiom).
7. **Tests.** Server GameTests live in the `gametest` source set, mod id `thesift-gametest`, and run with `./gradlew runGameTest`, which is wired into `check`. Client GameTests with screenshots are a later option, under xvfb.
8. **CI.** GitHub Actions on Ubuntu with JDK 25:
   - `./gradlew build` (runs the GameTests through `check`);
   - `tools/docs/check_bible.py`;
   - `xvfb-run ./gradlew runDatagen` followed by `git diff --exit-code` for the no-diff check.

**Why.** It matches vanilla and Fabric idioms, keeps test code out of the jar, needs no custom networking for M1, and makes every generated file reproducible.

**Consequences.**
- Datagen needs a display, so developers and CI run it under xvfb (`tools/dev/datagen.sh`).
- Generated files are committed under `src/main/generated`.

**Revisit if.** Client datagen proves flaky in CI. The fallback is to run the no-diff check locally before each push and log it in BLOCKERS.md.

## D-020 Entry implementation: frames by geometry on use, a game-event mixin, gates built on first crossing (2026-10-01) [WP-046/047]
**Context.** entry_path.md says frames are "located from Ancient City structure pieces … cached per chunk", music is heard by "a vibration listener … and a jukebox listener", and the gate stands on a hill at the matching x/z. Building it for the preview turned up three facts:
- A generated frame spans y −35…−28 (one below the anchor's `start_height`); the template reading in W6 was off by one.
- Natural frames grow **sculk veins** into the opening. A vein is not `canBeReplaced()` without context, so a "replaceable only" rule would never open a real city. The client GameTest on a natural city caught this.
- `/place structure` skips terrain carving, so only naturally generated cities show what players will find.

**Options considered.**
1. Locate frames from structure starts on chunk load and cache them. Needs a bounded scan per city anyway (templates don't give the frame's offset directly), and only matters for the ambient cues.
2. **Find the frame when a player uses a block of it** (chosen). Try every 22 × 8 rectangle in both vertical planes whose border passes through the touched block, and accept one whose whole border is reinforced deepslate.
3. A listener block entity per frame for music. That means adding blocks to the Ancient City.

**Decision.**
- **Frames** are found by geometry on a deliberate use (`FrameShapes`) and stored in `SiftLinks` (SavedData: frame, charge, gate). There is no structure check. Reinforced deepslate is unobtainable in survival, so every survival frame is a natural one, and operators can build test frames.
- **Music** is heard through one injection at the head of `ServerLevel.gameEvent`. It returns at once unless the event is `note_block_play`, `instrument_play` (16 blocks) or `jukebox_play` (10 blocks), and then checks only known awake frames.
- **The membrane** replaces air, replaceable blocks and multiface growths (sculk veins, glow lichen) and nothing else. Another mod's portal already in the frame wins.
- **Gates** are built on the first crossing: a hill of radius 7 with a flat top of radius 3, and a 6 × 7 gatestone frame facing like the city's. Each gate keeps 64 blocks from every other gate. Crossing either way re-opens a removed membrane, so nobody is stranded. Arrival is inside the opening, as with a Nether portal; the portal cooldown stops a bounce.
- **Deferred to the rest of M1, not the preview:** the dormant frame's "breathing" and the 8-block "notice" cues (they need frames known before anyone touches them, i.e. option 1), the sanctuary spawn rule (the Sift has no spawns yet), subtitles and the first-crossing advancement (WP-043/052).

**Why.** Option 2 costs nothing per tick, needs no new blocks in vanilla structures, and was proven on a real city. The mixin is the smallest hook Fabric allows for hearing music.

**Consequences.** A player who never touches the frame gets no hint in the preview. PLAYTEST.md says what to do.

**Revisit if.** Playtests show players don't find the frame without the ambient cues (bring option 1 forward), or the game-event injection shows up in a profiler.

## D-021 Blub implementation: goals, a second game-event consumer, procedural clips (2026-10-01) [WP-049..051]
**Context.** mob_blub.md (frozen after three critique rounds) fixes the behaviour. Building it settled how.

**Decision.**
- **Hearing music.** `ServerLevelGameEventMixin` now passes the event's `GameEvent.Context` on, and `BlubMusic` is a second consumer next to `FrameMusic` (D-020). It looks blubs up in a box only for music events. The hand that played comes from the context's source entity; the note is read from the world.
- **AI** is a goal selector: vanilla's Float, Panic, Sit and Follow Owner, plus our Shelter, Waterline, Stack, Listen and Bathe, in that order. Stack ranks above Listen, because a running higher-priority goal keeps MOVE. Towers are toppled by the bottom blub's own tick.
- **Animations are procedural clips** (idle, walk, hop, listen, sing, bathe, curl, stack wobble). They are driven by synced booleans and three entity events, not by vanilla's keyframe `AnimationDefinition`s (E5). The clips have the doc's timings, and the code stays small. The belly glow is vanilla's `LivingEntityEmissiveLayer` (the warden's) with our alpha.
- **Spawning** uses 26.3's `creature_world_gen_spawn_probability` environment attribute (0.03), not a spawn-settings field. The predicate adds the Endure rule.
- **Crossing:** `SiftGates.destination` records a player's entry. `AFTER_PLAYER_CHANGE_LEVEL` consumes it within 5 ticks and brings eligible blubs along.
- **The chord counter** is a Fabric attachment on the player, saved and copied on death.

**Measured.** 50 busy blubs (half befriended, all listening) tick at 0.87–1.22× the cost of 50 rabbits across runs (GameTest `fiftyBlubsCostAboutAsMuchAsFiftyRabbits`), inside the 1.5× budget. Idle blubs measured 0.82–0.95×. A 121-chunk worldgen sample held 5 blubs.

**Corrections to the frozen mob_blub.md** (found by the post-implementation adversarial review; the code follows these):
- *Owner offline, dead or in the other dimension:* vanilla's `SitWhenOrderedToGoal` holds a pet in its sitting pose while `getOwner()` is null or in another level. The blub does the same; it doesn't wander as the edge-case table said.
- *A mounted owner* (boat, horse) crosses as the vehicle's passenger. The membrane records only players who cross on foot, so mounted owners' blubs stay behind, consistent with "crosses on foot".
- *Listening after a reload:* the saved end tick restores the listening state (toward no particular source) until it runs out. A queued echo is not saved.

**Review fixes.** A climbing blub could mount itself, because `tick()` runs on the off-ticks without `canContinueToUse()`, and that crashed the server with a stack overflow. Towers could also pass five. Both are guarded, and an AI-on GameTest (`listeningBlubsStackOnTheirOwn`) covers them. Goal counters now use `reducedTickDelay`, since `canUse` and most `tick()`s run every other tick and the timings had been doubled.

**Revisit if** players want smoother motion than the procedural clips give (move to keyframes), or towers misbehave in multiplayer.

## D-022 Frame cues: frames found from the city's structure data (2026-10-01) [WP-046]
**Context.** D-020 deferred the dormant frame's "breathing" and 8-block "notice" cues, because frames were only known once someone touched them. The preview's main playtest question is whether players would think to try the frame at all.

**Decision.** `FrameCues` takes D-020's option 1, cheaply, and **never loads a chunk**. Every 2 s, for each Overworld player, the structure references stored in the player's own chunk name the city's start chunk. That start is read only if its chunk is already loaded. The first time, the city's `city_center` piece (18×31×41 in all three templates) is searched once for the reinforced-deepslate frame, again only with all its chunks loaded. It took 1 ms on a natural city, and the result is cached per city for the run. A cached frame whose border has been broken is forgotten, so a broken frame stays dormant with no cues. A city where no frame was found is searched again after 5 minutes. The cues pause under `/tick freeze`. Then:
- **Rumor:** within 32 blocks of a dormant frame, soul wisps appear just in front of its opening and drift in. That is once per frame every 4 ticks, however many players are near, and they are sent past the 32-block particle limit so everyone in range sees the same wisps.
- **Notice:** within 8 blocks of the frame, a player with experience sends wisps toward it, twice as many with an empty hand. A breathy cue plays to that player only, with the subtitle "Your soul stirs toward the frame". Nothing is taken. Being noticed grants the tab's root (an OR with "in an Ancient City", so a city whose frame can't be found still opens the tab).

**An Offering** goes to the player whose offering wakes the frame and to every player within 16 blocks at that moment. The charge is pooled, and the moment is shared, as vanilla's "Hero of the Village" goes to everyone in the raid.

**Not done:** the XP bar's flicker, the inner edge brightening where the player looks, and the hum deepening as the player nears. The first two are client rendering; the cue reads without all three.

**Revisit if** playtests show the cue is missed (make it stronger, never a posture trigger; D-010).


## D-023 The hunt: one listener, a capped fight at dawn, hunters stay in the Sift (2026-10-02) [WP-060]
**Context.** The hunt system (`docs/DESIGN/system_hunt.md`) has to keep three frozen promises at once: hunters listen only in Endure, Thrive is safe, and the Deep Dark's rules (sneaking, wool, the particle) work unchanged. Critique round 1 found places where the vision's own wording, or a tech note, couldn't keep them.

**Options considered.**
- For jukeboxes, a second listener per hunter as the allay has (rules.md's tech note), a third consumer of our game-event mixin, or the vibration listener with a wider event tag.
- For a hunter still fighting at dawn, the vision's rule as written (fight until the target is 16 blocks away), or that rule capped by the start of Thrive.
- For the membrane, letting hunters cross as ordinary mobs do (rules.md), or adding them to `#thesift:cannot_cross`.

**Decision.**
1. Each listener has **one** vanilla vibration listener whose events are `#thesift:hunter_can_listen` (`#minecraft:vibrations` plus `minecraft:jukebox_play`), as the warden widens its own with `#warden_can_listen`. Jukeboxes get the particle, the delay and wool occlusion for free; the 10-block range is checked in `canReceiveVibration`.
2. A hunter fighting at its retreat moment keeps fighting until its target is 16 blocks away (the vision), **and** a sweep at Thrive's first tick removes any retreating hunter still present, with wisps and the burrow sound.
3. `#thesift:hunters` joins `#thesift:cannot_cross`.
4. Nesters always retreat, in caves too (creatures.md: "Endure only"), while other hunters that spawned in caves stay (systems.md). Enduring variants stay enduring until the next Thrive.

**Why.**
1. One listener is less code than two, uses vanilla's dispatch, and makes a muffled jukebox work as players expect.
2. Without the cap, a player who stays close keeps a Nester into Thrive, and "Thrive is safe" breaks.
3. A hunter in the Overworld has no Tide: it would never hear and never leave.
4. A Nester is an Endure creature by the bible's own row, and an enduring Bloombud living on in the Hollows would make enduring variants permanent.

**Consequences.** WP-061 implements the listener and the retreat as specified and adds the tag to `cannot_cross`. The Thrive sweep is a server tick check alongside `TideCues`. rules.md's tech note on an allay-style jukebox listener is superseded by this entry.

**Revisit if** playtests show the dawn sweep reads as a pop rather than a retreat (lengthen the falling-Flow window or the dig), or that jukebox calls through walls feel unfair (they follow vanilla occlusion, so wool is the answer to teach).

## D-024 Ichor is the Sift's water (2026-10-02) [owner playtest] [supersedes D-013's ichor hazard]
**Context.** The owner's playtest of `v0.1.0-alpha`: the dimension's "water" was the worst part. It was sparse, it acted like lava (slow wading, fire, XP drain, lava-like spread), it was purple, and it wasn't transparent (opaque textures put it in the solid layer). The teasers show clear blue pools at canyon bottoms [S-I4]. Canon calls ichor "a multicolored, thick liquid" that burns heroes [W:Ichor], but the owner's call outranks that reading.

**Decision.**
- Ichor keeps its name and its own fluid (tide basins, the Blub's bathing, the bucket that evaporates outside the Sift) but behaves as water:
  - it is in `#minecraft:water`, so swimming, currents, breath, boats and putting out fire are vanilla's;
  - it flows 7 blocks with water's timing and renews between two sources (the water source conversion rule).
- It is harmless: no fire, no slowing, no XP drain. A soul wisp now and then rises from still ichor, a quiet trace of canon.
- It looks like the teasers' pools: translucent turquoise textures (which put it in the translucent layer), a water-style overlay, and a turquoise underwater haze (`water_fog_color`), replacing the purple fog.
- There is far more of it: lakes and rivers come with the terrain rework.

**Consequences.**
- The hazard tests are replaced by water-behaviour tests.
- The wading sound and the `#thesift:ichor_adapted` tag are retired.
- The M5 trait "Ichor Wading" (items.md) has nothing left to do; it is to be replaced when M5 is designed.
- Endure's danger now rests on the hunters (M2), not the flood.

**Revisit if** the owner wants a mild hazard back, for example a slow soul drain only while fully submerged in Endure.

## D-025 The Sift looks like the teasers (2026-10-02) [owner playtest] [supersedes D-016/D-017 on the Meadow's look; world.md healthy sculk; mob_blub.md look]
**Context.** The owner's playtest of `v0.1.0-alpha`: the terrain "doesn't look like Minecraft at all", and the textures, the mob and the trees "don't look like the teasers"; "be as faithful to the teasers as possible". Our terrain was a single gradient with 2D noise, which gave uniform stepped mounds. Our textures came from palette ramps chosen by eye. The teaser stills were re-downloaded and sampled for this rework [S-I1, S-I3, S-I4].

**Decision.**
- **Terrain.** Vanilla's own Overworld terrain functions, registered again under `thesift:sift/*`:
  - continentalness is raised by 0.3, so the Sift is land with lakes, rivers and a few inland seas (about 15 % water);
  - the height is the Overworld's (-64 to 320), with sea level 63 filled with ichor;
  - vanilla's caves and aquifers become the Sift Hollows below (a multi-noise source: the Meadow at the surface, `sift_hollows` from depth 0.2).
  On that land stand the teasers' **rose hymnstone spires** (14–33 tall, most with a mushroom cap, one in five chunks).
- **Ground.** Healthy sculk becomes the Sift's grass over a new **Sift Soil**, as grass over dirt (the teaser's hill shows pink grass on maroon earth):
  - it dies back to soil when covered and spreads onto soil in light;
  - it drops soil without Silk Touch, and both are shovel blocks;
  - steep slopes show hymnstone; shores and lake floors are tide sand.
- **Textures.** Ramps sampled from the stills: the first look's pink-coral grass (vanilla-grass speckle), maroon soil, rose-mauve hymnstone with faint strata, dense jagged pink grass tufts, dark charcoal-teal bark, pale icy leaves that fray into drips, and the first look's sky (#60D5C8).
- **Trees.** Songwood: a forked trunk (6–11) with large blob canopies and **Songwood Drapes** (vanilla's hanging-moss rules) hanging beneath, in noise-placed groves of four a chunk, with an occasional lone tree out on the open meadow.
- **Blub.** The first look's shape: a 9 × 7 × 8 body (hitbox 0.55 × 0.5), long ears at the front of its top, dark violet slit eyes, short legs, and a blue sampled from the still.

**Consequences.**
- Old worlds' Sift chunks don't match new ones, so playtests use a new world.
- Basins are rarer, because many lows are now lakes: they are placed one chunk in two, and only in dry lows with rock all round.
- The worldgen tests measure the new land (caves, biomes, basins, trees in groves).
- The look is checked by client screenshots (`SIFT_LOOK_ONLY=1 tools/dev/client-previews.sh`).

**Revisit if** the owner's next playtest says it still doesn't read as the teasers (next steps: teal grass patches as in the Dungeons II stills, an aurora sky).

## D-026 Ponds and flats, not seas; a bubble's sheen; trees and textures, second pass (2026-10-02) [owner playtest 2] [supersedes D-024 on ichor's look and flow speed, D-025 on sea level, songwood's shape and the texture style]
**Context.** The owner's playtest of `v0.1.1-alpha`: "this is great, but":
- the ichor "looks too much like water and acts too much like water"; it should be "slightly less transparent" and "multi colored, like the surface of a thin bubble"; its pattern is "hard on the eyes" and not seamless;
- it generates "like oceans"; "the max it should be is like a pond", with two kinds: ponds, and "the flats, where its more spread out but its blotty and kinda like a mangrove";
- the trees have "only like one canopy", their textures aren't seamless, and the forests look "very synthetic";
- the textures are "too close to the minecraft trailer artstyle" ("cell shaded, flat, simplistic"); "minecraft doesn't look like that".

**Decision.**
- **Ichor's look.** Its textures are a faint, pale shimmer, as vanilla's water textures are grey, at alpha 214 (water's is 180). The colour is laid on as the fluid is drawn (`thesift.client.IchorSheen`), blended from corner to corner so no block edge shows: a smooth, swirled field over x and z walks a soap film's colour cycle (turquoise, mint, gold, rose, lilac, periwinkle), lingering in turquoise. A pond therefore shows broad bands of colour that differ from pond to pond, and no pattern repeats from block to block.
- **Ichor's feel.** It is still water for swimming, breath and fire, but thicker:
  - it lifts whatever floats in it (0.025 a tick, up to 0.18), so you bob up unless you sneak;
  - it spreads a step every 8 ticks (water: 5).
- **No seas.** Sea level drops below the world, as the bible first said (world.md, "No sea and no aquifers"). Ichor now comes in three kinds:
  - **Ponds** in Singer's Meadow (a lake feature, one chunk in six, with a tide-sand rim).
  - **The Ichor Flats** (`thesift:ichor_flats`), a new biome on the wetter, flatter fifth of the surface. A world-seeded noise lays ichor one or two blocks deep in blots among the grass and trees, filling only where every side is solid, so nothing runs downhill.
  - **Pools in the Hollows**, as before.
  Basins stay in the Meadow's lows, now one chunk in five, nudged off the chunk grid.
- **Trees.** Songwood comes in two shapes:
  - a forking songwood (vanilla's cherry trunk: one to three branches, each with its own canopy);
  - a tall songwood (vanilla's fancy-oak shape: a tall trunk with several canopy lobes at different heights).
  Both carry drapes. Groves are placed by vanilla's biome noise (zero to five trees a chunk), so woods thin out into open meadow instead of falling on a grid. The Flats carry a looser wood.
- **Textures.** Redrawn in vanilla's style, not the trailers': per-pixel grain in six to twelve close shades with small clumps, not flat bands of three or four tones. The ramps widen to eight or nine shades. The leaves are overlapping lit clumps with gaps. The bark has furrows. Grass sides hang over the soil. Nothing lines up from block to block.

**Consequences.**
- Old worlds' Sift chunks don't match new ones: the sea is gone and the biomes moved. Playtests use a new world.
- Tests:
  - the worldgen tests look for dry land rather than land above sea level, and accept the Flats as a surface biome;
  - the basin test allows the vent's ±1 nudge;
  - a buoyancy test covers the lift.
- The dump test also draws a biome map.
- BALANCE's ichor row records the lift, the 8-tick step and the alpha.

**Revisit if** the owner's next playtest finds the ichor too unlike water to swim comfortably (lower the lift), the sheen too busy (widen the bands), or the Flats too common or too rare (move `FLATS_HUMIDITY`).

## D-027 The M2 flora: tide plants picked by the cycle, wild-only reagents and lumen, plant sounds (2026-10-02) [WP-064] [narrows world.md §4 "at home it is decoration" for three plants; amends world.md §3.1's sound register for plants]
**Context.** WP-064 designs the M2 plants (`docs/DESIGN/block_flora_ii.md`): tidewrack, the Endure bloom, the glowcap, the chime bell flower and the lumen bloom. The frozen documents say when the reagents can be had (systems.md §1), that growth never produces them (systems.md §2), that they come "only from the flats and the waterline", and that lumen lanterns are how players make their own lumen (world.md §2). Critique round 1 found that any way of moving these plants (shears, Silk Touch) let players duplicate the harvest, garden petals away from Endure's dark, or carry natural lumen for free.

**Decision.**
- **"The patch you come back to."** Tide plants switch open and closed as eyeblossoms do (a random tick reading `thesift:gameplay/tide`, then a ripple to neighbours). They are picked as sweet berries are (*use* leaves the plant), only when the logical Tide is theirs, once per cycle (a cycle stamp in the block state). A pick is a vibration with the player as source, so in Endure the hunters can hear petals being taken.
- **Wild-only.** Tidewrack, the Endure bloom and the lumen bloom drop no plant with any tool, Silk Touch included, as budding amethyst. They have creative-only block items. They never grow or spread. So world.md §4's "at home it is decoration" no longer applies to these three (they can't be carried home), and tidewrack still "grows on tide flats".
- **Sounds.** world.md §3.1 puts healthy sculk's step and break sounds "in the amethyst register". M1 shipped vanilla plant sound types for its plants (grass, pink petals, cherry sapling, moss carpet), and crystal sounds on every flower would grate. So plants keep vanilla plant sound types (tidewrack wet grass, the Endure bloom grass, the glowcap fungus, the lumen bloom spore blossom). The chime bell, whose nature is a chime, takes the small amethyst bud's. §3.1's "chimes and soft hums" are carried by the chime bell's ring and hum.

**Consequences.**
- Fronds and petals are paced by the Tides and by how many patches a player has found. Lanterns make picking safe once owned, which is the intended progression.
- The harvest needs one loot condition of our own (`thesift:tide_flora_ready`), and the ichor bucket gets overrides to fill tidewrack.
- items.md's tide shell, "crafted from tidewrack + hymnstone", means tidewrack **fronds** (the plant has no survival item); WP-065 and M5 read it so.

**Revisit if** players want tidewrack or blooms at home as decoration (a separate decorative variant could be added without reopening the reagent loop), or the playtest finds picking in Endure too punishing.


## D-028 Shader-safe sky, renderer-safe ichor colour, leaves that match their drapes (2026-10-03) [owner playtest 3] [supersedes rules.md "Sun & moon: none visible" and the daylight-detector row]
**Context.** The owner's third look: with shaders "everything turns pitch black"; the ichor showed white (their renderer, Sodium under Iris, draws fluids itself and skips our per-vertex colouring); the ichor's pattern should span many blocks; the leaves were ugly and a different colour from the drapes.

**Decision.**
- **Sky.** Shader packs light the world from the sun and moon. Both were parked at 180°, below the horizon, so a pack saw a moonless night. Now the sun crosses the sky through Thrive and sets in rising Flow, and the moon rides through Endure: one turn per Tide cycle (the `thesift:tides` timeline). Vanilla's lighting is unchanged (it reads the sky-light tracks). A plain daylight detector now reads the Tide too (day in Thrive, dark in Endure); an inverted one still senses Endure's darkness.
- **Ichor colour.** The fluid model gets a real tint source: the bubble field's colour at each block's centre. Renderers that tint fluids per block (Sodium, Iris) draw it and blend it as they blend water's biome colour. Vanilla's renderer keeps the smoother path: `IchorSheen` swaps each vertex's block tint for the field at its own corner, so the bands flow across blocks with no edge. The field's bands are many blocks wide, so the pattern is a large one, not a block-sized one.
- **Leaves.** Redrawn as vanilla draws leaves (a fine grain, small lit leaf dabs, scattered gaps), in the same pale shades as the drapes.

**Consequences.** rules.md's "none visible" sun row and its daylight-detector note are superseded. The sky shows a sun in Thrive and a moon in Endure.

**Revisit if** a shader pack still renders the Sift wrongly (then the dimension's id may need a shader-pack mapping note in the README), or the moving sun reads as un-Sift-like.

## D-029 Quieter textures, livelier ichor, the Flats' lights, a pet that does things, foley not tones (2026-10-03) [owner playtest 4] [supersedes D-026 on the texture grain, mob_blub.md on the face and the glow strip, the WP-043 synthesis method]
**Context.** The owner's notes on `v0.1.3-alpha`:
- the "vanilla" grain is "honestly just grain": hard on the eyes, and the blocks don't flow with vanilla's; "a slight change will come far";
- ichor: "slightly faster animation and less uniform gradient, more wiggly";
- the Ichor Flats: "more light producing fauna, and even an exclusive to that biome";
- the blub: more faithful to the trailer but drawn like vanilla, "less cell shaded", with a small mouth "and not only at night"; "more dynamic behaviour and AI and actual stuff that it does as a pet, not just exists";
- sound: "full rework", more vanilla, with effort behind it, "not just random synthetic tones, especially for ichor".

**Decision.**
- **Textures.** The shared grain gives most of its per-pixel jitter (×0.4) and some of its block-sized clumps (×0.6) to 2-pixel blotches, and the shade bands sit closer together (contrast ×0.72), so blocks read as vanilla's quiet stone and dirt. Hymnstone's pits and flecks are a shade softer. Every grain texture changes a little; none changes its palette.
- **Ichor.** The still texture animates faster (a frame every 3 ticks; it was 5). The colour field is swirled twice: a broad swirl, then a finer wiggle on it, plus a slow term that stretches and squeezes the bands. It reads as oil on water, not even rings.
- **The Ichor Flats' lights.**
  - **Ichor lily** (`thesift:ichor_lily`), the Flats' own plant: vanilla's lily pad that floats only on an ichor source, with a glowing lilac bud (light 9; glow lichen 7, sea pickles 6–15). It lets **glimmers** drift up, drawn and moving as vanilla's fireflies. It drops itself, composts as a lily pad does, and boats break it. Two patches a Flats chunk (14 tries each), only where it survives.
  - Lumen blooms are twice as common in the Flats (1 in 6 chunks; the Meadow keeps 1 in 12). Glowcaps grow in the Flats' grass as mushrooms do in a swamp (a patch 1 chunk in 3).
- **The blub.**
  - Redrawn as vanilla draws its mobs: soft top-to-bottom gradients with low-contrast fur clumps and a little dither, round dark eyes with a catch-light, a small mouth and cheeks that are always there. The Endure glow stays on the belly only: the lit strip on the front read as a mouth that came out at night.
  - New pet behaviours (goals), each built on a vanilla precedent:
    - **Greet** (a dog at the door): an owner back after 30 s away (out of 24 blocks, or gone) is run to, met with hearts and hops.
    - **Beg** (the wolf's head tilt): a frond in the owner's hand within 8 blocks.
    - **Forage** (the allay and fox): in Thrive, every 2 to 4 minutes at most, it picks ready tidewrack within 12 blocks. It picks exactly as a player does, so the cycle stamp holds. It carries the frond in its mouth (drawn) and drops it at its owner's feet.
    - **Play** (tag): two idle befriended blubs of one owner chase each other for 8–12 s with hops; a catch is a chirp and swaps who is "it".
- **Leaves.** Their gaps are fewer (about 8 %) and spread evenly as single pixels and pairs, and each keeps a deep leaf colour under zero alpha, as vanilla's do. The canopy's dark inside showing through scattered pixel holes read as black speckle on the pale leaves.
- **Sound.** `tools/audio/synth.py` is rewritten as procedural foley. Every one of the 78 files is regenerated, with the same names and vanilla-matched levels:
  - Liquids: Minnaert bubbles with van den Doel's damping and rising pitch, bursting films, splashes with entrained bubble clouds and droplets. Ichor is a denser, thicker liquid, so its bubbles ring lower and die faster.
  - Plants: granular leaf rustle and snapping stems.
  - Bells, glass and gongs: modal synthesis with beating partial pairs.
  - The blub: source-filter formant synthesis, a voice with lips, vowels and breath.
  - Bodies: thumps and squishes.
  - Ambience: wind gusts and a breathy flute.

**Consequences.**
- mob_blub.md's face, glow strip and goal list are superseded here.
- Tests: the lily's footing and light, begging, a forage delivered to the owner (83 GameTests).
- The sounds were checked by spectrogram, not by ear (the build machine has no speakers). The owner's ears are the test.

**Revisit if** the grain now reads as blurry, the foraging blub fetches so much that it sidesteps a visit to the basin (raise the cooldown), or a sound reads wrong in game.
