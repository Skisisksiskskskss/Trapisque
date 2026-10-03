# PLAYTEST

Step-by-step checklists the owner can run in-game. Produced at every gate.

## `v0.1.9-alpha` (2026-10-03): rifts, the rift fork, and starting in the Sift
You asked to get in and out of the Sift without the Deep Dark (D-032, survival_sift.md §2-3). What to try:
- **Natural rifts:** tall shimmering tears that open on their own. In the Overworld one opens about every 40 minutes near each player; in the Sift, about every 10. They open 24-48 blocks away, and you hear them hum and open.
  - Walk into one and you arrive at the same x and z in the other world, on safe ground.
  - Friends have 10 seconds to follow before it closes. A rift lasts 5 minutes otherwise.
- **Rift fork:** two echo shards over two gold ingots (a tuning fork). Right-click to open a rift 3 blocks ahead for a minute; it has 8 uses and a 5-second cooldown. Echo shards come from **echo ore** deep in the Hollows, or from the Deep Dark.
- **Start in the Sift:** in Create World → Game Rules, turn on **Start in the Sift**. New players then begin on the Sift's surface near 0, 0 with nothing, and respawn there.
- **Game rules:** `/gamerule thesift:spawn_rifts false` turns natural rifts off.
- **Advancements:** Through the Rift, Tuned In (make a rift fork), Sift-Born (get a diamond in the Sift).
- To find one fast: `/summon thesift:rift ~ ~ ~3`.

## `v0.1.8-alpha` (2026-10-03): the Nester, as Dungeons II shows it
Your note: the Nesters didn't look good, and the mod should follow what Mojang showed (D-034). The Nester is redrawn from Dungeons II's official render:
- a big boxy head, teal over a tan jaw, with navy eyes at its corners and two feathery antennae;
- a thin neck on four long legs with tan feet.

It gallops leaning forward and rears up to pounce with its whole mouth gaping. Enduring Nesters are pale glowing cyan, like Dungeons II's soul-corrupted Nester. When one hears you, its antennae shoot up. Try `/summon thesift:nester` and `/summon thesift:nester ~ ~ ~ {Enduring:1b}` in the Sift.

## `v0.1.7-alpha` (2026-10-03): living in the Sift, part 1: ores, food, hymnstone as stone
Your notes: the Sift needs ores and a way to progress from nothing; hymnstone should work as stone (D-032, D-033, survival_sift.md). What to try in a **new world** (ores generate in new chunks only):
- **Hymnstone works as stone:** a pickaxe gets **cobbled hymnstone**. It makes stone tools and a furnace, and smelts back into hymnstone. Smelting hymnstone gives **smooth hymnstone**; 2 × 2 smooth gives **polished**. Smelting hymnstone bricks gives **cracked** bricks, and two brick slabs make **chiseled** bricks. Stairs, slabs and walls are on the crafting table and the stonecutter.
- **Ores in the hymnstone:** coal, copper, iron, gold, redstone, lapis and diamond, at the heights you know from the Overworld (diamonds deep, iron in the mountains and below). Each drops vanilla's item and takes the same pickaxe.
- **Echo ore**, deep in the **Hollows** only (y −64 to 0): faintly lit dark-teal specks that pulse. It needs iron and gives 1–2 echo shards.
- **Food:**
  - **Tide roots** grow wild where tide sand meets ichor. Replant them on tide sand beside ichor, in light; eat raw or bake.
  - **Songfruit** sometimes drops from songwood leaves (as apples do).
  - **Glowcap stew** is two glowcaps and a bowl.
  - **Three songwood drapes** make a **string**.
- **Still to come** (WP-082/083): rifts (the way in and out without the Deep Dark), the rift fork, the `start_in_sift` gamerule, and the Hymnstone Rise (emeralds) and Lullaby Hills biomes.

## `v0.1.6-alpha` (2026-10-03): ichor's colours move
Your note: the multicoloured gradient had stopped moving (D-031). Still ichor now shows the soap-film colours as a slowly swirling pattern that spans many blocks and drifts about a block a second. Flowing ichor keeps its colours still. With Sodium or Iris the colours stay still, as before: those renderers draw fluids their own way.

## `v0.1.5-alpha` (2026-10-03): the hunt begins: Nesters in Endure
The Sift's first danger (system_hunt.md, mob_nester.md, D-030). What to try:
- **In Endure (high tide), Nesters come up out of the Meadow's grass.** They don't see you; they **hear** you, like a warden: steps, blocks, doors, eating, a jukebox within 10. A vibration particle flies to the Nester, its gold crest fans up ("Nester hears something"), and it gallops to **where the sound was**.
- **Stay quiet:** sneak (and don't eat), walk on wool, or throw a snowball while sneaking. It lands far off, and the Nester goes there instead.
- **If it finds you, it duels:**
  - it crouches and hisses before a lunge, so step sideways;
  - up close, raise a shield early: a blocked bite staggers it, so hit it then;
  - after each bite it circles with its crest rattling, and it dodges your first swing then, so bait it with one swing and strike with the next;
  - arrows catch it circling.
- **Lumen keeps them out:** no Nester comes within 6 blocks of a lumen bloom or a **lumen lantern**, or spawns within 8. Watch one pace at the edge of the light.
- **Stone floors are safe:** they only come up out of soil (grass and Sift soil), never hymnstone, planks or bricks.
- **At dawn** (falling Flow) they dig back into the soil and are gone by Thrive. **Enduring** Nesters (spikes, soul wisps, glowing eyes) are tougher and worth double XP.
- Advancement: **Heard You**.

## `v0.1.4-alpha` (2026-10-03): quieter textures, livelier ichor, the Flats' lights, a real pet, new sounds
Your notes on `v0.1.3-alpha`, and what changed (D-029, items_m2.md):
- **Textures:** the grain is calmer: smaller noise, closer shades, so blocks sit beside vanilla's.
- **Ichor:** animates a little faster; its colours wiggle and swirl unevenly, like oil on water.
- **Ichor Flats:** the new **ichor lily** grows only there, a glowing lily pad on ichor that lets glimmers drift up like fireflies. Place it on ichor as you would a lily pad. Lumen blooms are twice as common there, and glowcaps grow in the Flats' grass.
- **Blub:** redrawn in vanilla's style with a small mouth that's always there. As a pet it now:
  - runs to greet you when you come back after a while;
  - tilts its head and begs when you hold a tidewrack frond;
  - in Thrive, fetches fronds from ready tidewrack nearby and drops them at your feet (every few minutes at most);
  - plays tag with your other blubs.
- **Feeding and babies:** right-click your blub with a **tidewrack frond** to heal it (2 hearts); at full health it looks for a mate, and two make a **baby blub** that is yours.
- **Uses for the new plants:** a frond crafts into **cyan dye**. Four **Endure petals** around a **hymnstone** make a **lumen lantern** (light 15, hunters will avoid it). Picking your first frond gives the **Low Tide** advancement.
- **Sound:** every sound was rebuilt as foley:
  - ichor bubbles, glugs, splashes and bursts like a thick liquid;
  - plants rustle and snap;
  - bells ring with real partials;
  - the blub has a little voice.

  I checked them by their spectrograms, not by ear, so tell me which ones sound wrong.

**A new world is best** for the lilies (they generate with new chunks). Install as below with `thesift-0.1.4-alpha.jar`.

## `v0.1.3-alpha` (2026-10-03): shaders, ichor colour, leaves, and new plants
Your notes on `v0.1.2-alpha`: white ichor, ugly leaves that didn't match the drapes, pitch black with shaders. What changed (D-028, D-027):
- **Shaders:** the Sift has a sun again. It crosses the sky through Thrive and the moon rides through Endure, so shader packs light the Sift as day and as a moonlit night instead of black.
- **Ichor:** colourful with Sodium and Iris too (it was white there); the colours flow in bands across many blocks rather than repeating per block.
- **Leaves:** redrawn in vanilla's leaf style, in the same pale colour as the drapes.
- **New plants (things to find and do):**
  - **Tidewrack** on tide basin floors: right-click it in Thrive (low tide) for **tidewrack fronds**, once per Tide cycle.
  - **Endure blooms** on ichor shores: they open, glowing faintly, in Endure (high tide); right-click for an **Endure petal**. Careful: picking makes a sound the coming hunters will hear.
  - **Chime bell flowers** in the Meadow: they ring when you walk through them (sneak to pass quietly), and hum when music plays.
  - **Lumen blooms**: rare glowing plants, often ringed by chime bells; the Sift's hunters will keep away from them.
  - **Glowcaps** light the Hollows' caves.
  Fronds and petals get their uses next (dye, blub treats, lumen lanterns).

**A new world is best** (the plants generate with new chunks; old chunks keep what they had). Install as below with `thesift-0.1.3-alpha.jar`.

## `v0.1.2-alpha` (2026-10-02): the owner's second playtest
Your notes on `v0.1.1-alpha`: the ichor looked and acted too much like water and generated like oceans; the trees had one canopy and the forests looked synthetic; the textures were too close to the trailers' flat look. What changed (D-026):
- **Ichor:** a little less see-through, with a soap bubble's colours (turquoise, mint, gold, rose and lilac in broad bands that blend across the pond, different in every pond); the old busy pattern is gone. It is thicker: it lifts you up (sneak to dive) and spreads more slowly.
- **No more seas:** ichor now comes as **ponds** in Singer's Meadow, and as the new **Ichor Flats** biome, where shallow ichor lies in blots among the grass and trees, like a mangrove swamp's water.
- **Trees:** two shapes, a forking songwood (one to three branches, each with its own canopy) and a tall songwood with canopy lobes at several heights, both with drapes. Woods thin out into open meadow instead of standing on a grid.
- **Textures:** redrawn in vanilla's style rather than the trailers': many close shades with per-pixel grain (grass, soil, hymnstone, bark, planks, leaves, drapes, tide sand). Leaves are clumpy with gaps; grass sides hang over the soil.

**Use a new world** (or delete `<world>/dimensions/thesift/the_sift`): the sea is gone and the biomes moved, so old Sift chunks won't match new ones. Install as below with `thesift-0.1.2-alpha.jar`.

**Tell me:** is the ichor's sheen right (too busy, too faint)? Do the ponds and the Flats feel right in size and number? Do the trees and woods look natural now? Do the textures read as Minecraft?

## `v0.1.1-alpha` (2026-10-02): the owner's playtest rework
Your notes on `v0.1.0-alpha`: the terrain didn't look like Minecraft, the textures, mob and trees didn't look like the teasers, and the water was the worst part. What changed (D-024, D-025):
- **Water:** ichor is now the Sift's water. It is clear turquoise, see-through, and it swims, flows and refills like water; it no longer burns, slows or drains you. There is much more of it: lakes, rivers and shores.
- **Terrain:** built on vanilla's own Overworld terrain (hills, valleys, plateaus, caves, lakes, rivers), with the teasers' rose hymnstone spires and their mushroom caps standing on it, and the Sift Hollows (caves) below.
- **Textures:** redrawn from the teaser stills: the first look's pink-coral grass over a new maroon **Sift Soil**, rose-mauve hymnstone, dense jagged pink grass, dark teal trunks, pale icy leaves.
- **Trees:** tall dark trunks with big pale canopies and **Songwood Drapes** hanging underneath, in groves with open meadow between.
- **Blub:** the first look's shape: a bigger blue cube with long ears, slit eyes and short legs.

**Use a new world** (or delete `<world>/dimensions/thesift/the_sift`): the Sift's terrain and height changed, so old Sift chunks won't match new ones. Install as below with `thesift-0.1.1-alpha.jar`.

**Tell me:** does it look like the teasers now? What still looks off: colours, grass, trees, spires, water, the Blub?

## Gate C: M1 `v0.1.0-alpha` (2026-10-01): get in, watch the tide, befriend a blub, get out
The M1 vertical slice (it supersedes the `v0.1.0-alpha.preview` build). **In it:**
- the Sift dimension and Singer's Meadow (block set I);
- the Tides: sky, light, stars, beds, Trills by day and glow petals by night;
- music reactions;
- the way in through an Ancient City (the dormant frame breathes and notices you) and the way back;
- ichor, tide basins and ichor pools;
- **the Blub**, befriended by music;
- the **advancement tab "The Sift"**.

Every sound is our own, synthesized, with subtitles.
**Not in M1, by design:** Endure is dark but **not dangerous**, because its hunters arrive in M2. Tidewrack, treats and blub breeding are M2. The other biomes are M2–M3.

### Install (≈5 minutes)
1. Minecraft Java **26.3**, **Fabric Loader 0.19.5** or newer, and **Fabric API 0.161.0+26.3** in `mods/`.
2. Put `thesift-0.1.0-alpha.jar` in `mods/`. Get it from the GitHub pre-release `v0.1.0-alpha`, from the `thesift-jar` artifact of the latest CI run, or by running `./gradlew build` → `build/libs/`. Remove any older `thesift-*.jar` first.
3. Launch. **Expect** the title screen, and `(thesift) The Sift initialized (unofficial fan project)` in `logs/latest.log`.

### P1. The way in and back (survival, ≈30–60 minutes)
1. In a new world, gather **30 levels** of experience, then find an **Ancient City** (with cheats: `/locate structure minecraft:ancient_city`). Mind the warden: offering and music both make vibrations.
2. At the city's centre stands the big reinforced-deepslate frame (22 × 8). **Expect:** the tab "The Sift" opens. As you get near the frame, soul wisps drift into its opening; within 8 blocks, wisps rise from *you* toward it (more with an empty hand), and the subtitle reads "Your soul stirs toward the frame". With an **empty main hand, hold *use* (right-click) on the frame**.
   **Expect:** your XP bar drains in a steady stream, souls flow from you into the frame, faint cyan specks appear on it, and the action bar shows "Your soul flows into the frame (n%)". Releasing stops it at once, and what you gave stays. The full price is level 0 → 30 (1 395 points, ≈ 28 s). In creative it is free.
3. At 100%: "The frame wakes; it is listening for music", a glow burst, and note particles drift from the frame.
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
1. Find a **tide basin**: a rounded pit that steps down in one-block rings to a pale tide-sand floor with a vent in the middle. **Expect:** empty in Thrive; in rising Flow it fills one layer at a time (3 layers); full through Endure; it drains through falling Flow.
2. Find ichor (since `v0.1.1-alpha`: lakes, rivers and pools of clear turquoise). Swim in it. **Expect:** it behaves as water: you swim, hold your breath, get carried by its current, and fire goes out; under it, a clear turquoise haze. A soul wisp rises from it now and then.
3. Fill a bucket with ichor. **Expect:** it pours in the Sift; emptied in the Overworld it evaporates in soul smoke.
4. **Tell me:** does it look and feel like the teasers' water?

### P4. Singer's Meadow and block set I (≈10 minutes)
1. Look around: pink-coral meadow over maroon soil, dense pink grass, rose spires, rivers and lakes, groves of dark-trunked songwood with pale drooping canopies.
2. The creative tab **The Sift** lists every block. Craft songwood planks and hymnstone bricks (stairs, slabs, walls; the stonecutter works too).
3. Saplings grow and bone meal works **only in the Sift**; healthy sculk covered by a block dies back to Sift Soil, and spreads back onto soil in the light, as grass does.
4. **Music reactions:** play a note block, goat horn or jukebox near healthy sculk or songwood. **Expect:** glowing petals lift off the sculk and grass, and the songwood's flute holes puff notes (within 12 blocks). It works at home too, and with the sound muted.
5. **Tell me:** what reads well, and what looks off (colours, textures, the membrane's pattern, the ichor surface)?

### P5. Blubs and advancements (≈15 minutes)
1. Find blubs on the Meadow: small pale-blue bunny-things, in groups of 2–5 (with cheats, a **Blub Spawn Egg** from the creative tab).
2. Place a **note block** next to them and play it once. **Expect:** they stop, ears up, chirp, and drift toward the music. Nobody is befriended yet.
3. Stand within 4 blocks of one and play again. **Expect:** hearts, a happy squeak and a hop. That blub is yours. Each note befriends one more, the nearest one watching. Redstone-played notes and jukeboxes only make them listen.
4. Play notes near your blubs. **Expect:** each answers 0.3 s later with a squeak at your note plus its own interval. Three befriended in a row make a chord (root, third, fifth), with a note particle each.
5. *Use* with an empty hand sits a blub, as with a cat. *Sneak-use* on a sitting one releases it. It heals slowly while sitting.
6. Walk through the membrane. **Expect:** your free-roaming blubs within 16 blocks come along; sitting ones stay.
7. Watch a Tide cycle with blubs around. Near the end of Thrive and of Endure, yours get **restless** (hops, chirps, note particles): Flow is 30 s away. In **Flow** they potter along the basin waterline. In **Endure** they curl up under leaves with their bellies glowing. In **Thrive**, music makes nearby blubs stack into wobbly towers of up to 5, which topple later. Now and then a blub sits in shallow ichor up to its belly.
8. **Advancements:** a tab **The Sift** opens when you walk an Ancient City, then "An Offering" (wake a frame), "Where Souls Drift" (enter the Sift) and "The Tide Turns" (be there when it changes). Befriending a blub also counts for vanilla's "Best Friends Forever".
9. **Tell me:** does befriending feel deliberate or fiddly? Is the echo charming or noisy? Do the towers topple too soon or too late?

### Known issues in M1
- The frame's, membrane's and ichor's particles are vanilla stand-ins (the sky's motes and the music petals are the Sift's own).
- Basins have no rising-bubble visual yet (the bubbling is heard). Blub animations are simple procedural poses, not keyframed clips.
- Towers of blubs need a few listening blubs close together; a jukebox works best.
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
