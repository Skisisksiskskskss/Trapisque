# PLAYTEST

Step-by-step checklists the owner can run in-game. Produced at every gate.

## Gate A (vision) — 2026-09-30
Nothing Sift-specific is playable yet: Gate A approves the *design*. The only testable artifact is the empty mod scaffold, which proves the toolchain works on your machine.

### A1. The scaffold loads (≈5 minutes)
1. Install **Minecraft Java 26.3**, **Fabric Loader 0.19.5** (fabricmc.net installer) and put **Fabric API 0.161.0+26.3** in `mods/`.
2. Build the mod: `./gradlew build` in the repository root. Gradle will download JDK 25 itself if needed. Copy `build/libs/thesift-0.0.1-dev.jar` into `mods/`.
3. Launch the game. **Expect:** it reaches the title screen, and `logs/latest.log` contains `(thesift) The Sift initialized (unofficial fan project)`.
4. Create any world. **Expect:** it loads normally. Nothing new exists yet, and that is correct.
5. Report anything else in the log with `thesift` in it (there should be nothing).

### A2. Optional: see the entry-path landmark in vanilla
1. In a creative test world, run `/locate structure minecraft:ancient_city` and teleport there.
2. Find the large reinforced-deepslate frame at the city centre (22×8 with a 20×6 opening). This is the frame the vision (00_VISION.md §7) proposes to wake with souls and open with music.
3. Mine some sculk near it and watch your XP orbs. In the proposed design they would drift *into* the frame. Ask yourself: would you notice, and would you guess to play a note block next?
