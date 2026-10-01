# PLAYTEST

Step-by-step checklists the owner can run in-game. Produced at every gate.

## Preview `v0.1.0-alpha.preview` (2026-10-01): get in, watch the tide, get out
The first playable build (D-018). **In it:** the Sift dimension and Singer's Meadow (block set I), the Tides (sky, light, stars, beds, Trills by day and glow petals by night), music reactions, the way in through an Ancient City and the way back, ichor, tide basins and ichor pools.
**Not in it yet** (the rest of M1): creatures (the Blub), the Sift's own sounds and subtitles (vanilla stand-ins play), advancements, and the "breathing" hints on a frame nobody has touched.

### Install (≈5 minutes)
1. Minecraft Java **26.3**, **Fabric Loader 0.19.5** or newer, and **Fabric API 0.161.0+26.3** in `mods/`.
2. Put `thesift-0.1.0-alpha.preview.jar` in `mods/` (from the GitHub pre-release `v0.1.0-alpha.preview`, or the `thesift-jar` artifact of the latest CI run, or `./gradlew build` → `build/libs/`).
3. Launch. **Expect** the title screen, and `(thesift) The Sift initialized (unofficial fan project)` in `logs/latest.log`.

### P1. The way in and back (survival, ≈30–60 minutes)
1. In a new world, gather **30 levels** of experience, then find an **Ancient City** (with cheats: `/locate structure minecraft:ancient_city`). Mind the warden: offering and music both make vibrations.
2. At the city's centre stands the big reinforced-deepslate frame (22 × 8). With an **empty main hand, hold *use* (right-click) on the frame**.
   **Expect:** your XP bar drains in a steady stream, souls flow from you into the frame, faint cyan specks appear on it, and the action bar shows "Your soul flows into the frame (n%)". Releasing stops it at once, and what you gave stays. The full price is level 0 → 30 (1 395 points, ≈ 28 s). In creative it is free.
3. At 100%: "The frame wakes. It is listening for music", a glow burst, and note particles drift from the frame.
4. **Play music** near it: a note block (hit it, or power it) or a goat horn within 16 blocks, or a jukebox with a disc within 10. **Expect:** a cyan membrane fills the 20 × 6 opening.
5. Walk into the membrane and wait about 4 s, as with a Nether portal. **Expect:** you arrive in the Sift inside a gatestone gate on top of a coral-pink hill, in **Thrive** (teal sky). The first arrival in a world starts the Tide clock.
6. To go home, walk back into the gate's membrane. **Expect:** you come out inside the city frame.
7. **Tell me:** without this page, would you have thought to hold *use* on the frame, and to play music next? Were you ever stuck, lost, or killed by the trip itself?

### P2. The Tides (≈25 minutes, or with commands)
1. Stay in the Sift for a full cycle: **Thrive** 10 min (teal day) → **Flow** 2.5 min (amber) → **Endure** 10 min (indigo night, stars, sky light 4) → **Flow** 2.5 min.
   With cheats, jump between them: `/execute in thesift:the_sift run time of thesift:tides set thesift:endure` (or `thesift:thrive`, `thesift:flow_rising`, `thesift:flow_falling`).
2. Try a bed: you can't sleep in the Sift ("the Sift never goes quiet"). During Endure, with no monsters close, using a bed says "You rest a while" and resets the phantom timer.
3. Weather never happens in the Sift.

### P3. Ichor, basins and pools (≈15 minutes)
1. Find a **tide basin**: a rounded pit with a pale tide-sand floor, a terrace ring and a vent in the middle. **Expect:** empty in Thrive; in rising Flow it fills one layer at a time (3 layers); full through Endure; it drains through falling Flow.
2. Find an **ichor pool** (violet liquid in the hills and caves). Wade in. **Expect:** you are slowed (but can climb out), set on fire for a few seconds, and lose XP; with your head under, a thick violet haze (1/2/4 points a second on Easy/Normal/Hard); soul flames rise. With Fire Resistance you don't burn, but the drain goes on. Creative players are left alone.
3. Fill a bucket with ichor. **Expect:** it pours in the Sift; emptied in the Overworld it evaporates in soul smoke.
4. **Tell me:** does the drain feel like pressure or punishment? Is wading too slow or too quick?

### P4. Singer's Meadow and block set I (≈10 minutes)
1. Look around: rolling coral hills of healthy sculk, white-crowned songwood groves, pink grass.
2. The creative tab **The Sift** lists every block. Craft songwood planks and hymnstone bricks (stairs, slabs, walls; the stonecutter works too).
3. Saplings grow and bone meal works **only in the Sift**; healthy sculk covered by a block dies back to hymnstone.
4. **Music reactions:** play a note block, goat horn or jukebox near healthy sculk or songwood. **Expect:** glowing petals lift off the sculk and grass, and the songwood's flute holes puff notes (within 12 blocks). It works at home too, and with the sound muted.
5. **Tell me:** what reads well, and what looks off (colours, textures, the membrane's pattern, the ichor surface)?

### Known issues in this preview
- Sounds are vanilla stand-ins; so are the particles of the frame, the membrane and ichor (the sky's motes and the music petals are the Sift's own).
- The membrane and ichor show the same animation frame on every block (as vanilla water does); a faint per-block rhythm can show on wide sheets.
- Leaving through a gate always returns you to the frame you entered by. Dying in the Sift sends you to your Overworld spawn.
- Unofficial fan project, not affiliated with or endorsed by Mojang Studios or Microsoft.

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
3. Walk up to the frame and look at it. In the proposed design, faint souls would already be drifting from the city's sculk into the frame. As you came near, wisps would rise from *you* toward the frame while your XP bar flickers (nothing taken), more strongly with an empty hand. Holding *use* on the frame with an empty hand would stream your experience in until it wakes (≈ level 0 → 30, once per frame; nothing is ever taken otherwise). Then note particles would drift from it, and any music (a note block, goat horn or jukebox) would open it. Ask yourself: would you think to *use* the frame, and would you guess to play music next?
