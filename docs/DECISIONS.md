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
