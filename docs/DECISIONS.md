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
**Context.** WP-011: a survival entry and return path. Canon: the Ancient City centre frame is the Sift portal, opened by the Note Block Machine / a Singer's song; rifts are the Illagers' temporary portals. Three fan mods already use the frame (RESEARCH.md §8).

**Options considered.** 15 ideas scored in `docs/DESIGN/vision/entry_path.md`: melody puzzle (23), three resonant note blocks (26), **souls wake it + song opens it (32)**, warden trophy (22), echo tuning fork (26), rift first (28), Illager rift incursions (26), Sift disc (25), goat horn (22), calibrated chord (23), allay escort (22), soul journey* (21), build-your-own gate* (26), Soul Sand Valley rifts* (22), bottled echo (26). (* unusual)

**Decision.** Every Ancient City frame starts dormant. It absorbs nearby experience orbs as visible souls until it is awake, and any music played before an awake frame opens it. Arrival is at a generated Sift-side gate in the nearest Singer's Meadow-type biome at 1:1 coordinates, with a no-hostile-spawn sanctuary radius. Return is through the linked gate; a broken gate reopens with music.

**Why.** It is the only option using both canon ingredients (souls and music) with self-teaching feedback and no new key item. It suits a sandbox better than Dungeons II's rift-first order (a landmark beats a random event; P4; minimal vanilla footprint), and it is distinct from existing mods' activations (melody puzzle, warden trophy, pedestal item).

**Consequences.** We need: frame location from Ancient City structure pieces (no block scans); an XP-orb attraction zone around known dormant frames; a vibration/music listener at awake frames; a portal block, a POI type, a Sift-side gate feature and a biome search for arrival. Soul cost is tuned in BALANCE.md. If another mod's portal occupies the frame, we don't act.

**Revisit if.** The owner prefers the canonical melody, rift-first, or a build-your-own gate at Gate A; Mojang reveals the vanilla access method; playtests show the XP pull is confusing or annoying.

---

## D-007 Core systems at concept level (2026-09-30)
**Context.** WP-013: concept designs for the Tides, soul economy, healthy vs corrupted sculk, sound, and the Illager occupation, each linked to ≥2 others.

**Options considered.** `docs/DESIGN/vision/systems.md`: Tides T1–T10, souls S1–S10, sculk H1–H6, sound N1–N7, Illagers I1–I6 (unusual ones in italics), all rubric-scored.

**Decision.** (Feasibility of the Tide architecture verified by spike — VANILLA_ANALOGS W4.) Tides = **T1** day-like 24 000-tick cycle (Thrive 10k · Flow 2k · Endure 10k · Flow 2k) on a `thesift:tides` clock + timeline, with Sift gameplay values as **our own registered environment attributes** keyed on that timeline; T3 (Tide-shifting lever) as Should. Souls = **S1+S3+S4+S8**: souls *are* XP; healthy sculk banks and blooms with it; lossy soul blocks; Illager soul tanks. No HUD meter. Sculk = **H1+H2** (inversion + blight). Sound = **N1+N2+N3** (+N4/N5 content). Illagers = **I1+I5+I6** core, **I2** endgame, I3 deferred.

**Why.** Highest rubric totals; each keeps canon while using vanilla grammar (XP/catalyst, allay-style music liking, day-night-style timelines, outposts). Together they form one loop where every system feeds at least three others (systems.md §6).

**Consequences.** Phase 2 inventory derives from this loop. BALANCE.md must pin the soul↔XP loss rates and the Endure spawn buffs. Phase 3 must confirm custom environment-attribute registration and client sync.

**Revisit if.** The critique (WP-014) or the owner at Gate A rejects a system; implementation shows custom attributes can't be keyframed or synced as expected.
