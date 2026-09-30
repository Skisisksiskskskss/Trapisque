# The Sift — Vision

**Status:** DRAFT (WP-010…013) → critique (WP-014) → FROZEN at Gate A.
Supporting work: `vision/concepts.md` (14 concepts, rubric, merge), `vision/entry_path.md`, `vision/rules.md`, `vision/systems.md`. Canon: `../RESEARCH.md`.
*Unofficial fan project, not affiliated with or endorsed by Mojang Studios or Microsoft.*

## 1. Fantasy
**The Sift is the living heart the Deep Dark lost: a luminous world of healthy sculk that answers sound instead of punishing it, where light, creatures and souls rise and fall with the Tides.**

## 2. Tone
- **Wonder first.** Pastel stone, glowing cyan flora, a teal sky; creatures that squeak, bounce and sing. The first minutes are beautiful and safe enough to look around.
- **The Deep Dark, inverted.** Down there, silence keeps you alive. Here, sound is how you are heard, welcomed and helped. The same sculk grammar the player already fears means something kinder.
- **A song with a shadow.** Each cycle ends in Endure: the light fails, the flora glows, stronger things walk. And the Illagers are here, draining souls from the ground. Where they work, the colour dies.
- **Vanilla restraint.** No dialogue windows, no quest log. The story is told by places: a caged echo golem, a grey scar where a harvester stood, souls drifting into an Ancient City frame. Few new things, each doing a lot.

## 3. Pillars (every later decision is checked against these)
| # | Pillar | A feature passes if… |
|---|---|---|
| P1 | **Sound brings life** — the Sift listens and answers | the player can change it, or read it, through sound, **and** every audio cue has a visual one |
| P2 | **The Tide sets the rules** — the world breathes on a readable cycle | it behaves differently in at least one Tide, and the difference can be seen or heard without UI |
| P3 | **Souls are the lifeblood** — life feeds the sculk, and you choose how to take | it produces, carries, spends or reacts to souls, using vanilla's soul/XP/sculk grammar where it can |
| P4 | **Wonder first, danger earned** — beauty up front, threat that telegraphs | a first-time player can survive their first Thrive by watching, and every lethal threat has a wind-up and a counter |

Tie-breakers: canon over invention; vanilla grammar over new UI; fewer, deeper features over more.

## 4. Why the Sift exists (the verbs no other dimension offers)
1. **Read the Tide.** Plan around a visible cycle: Thrive for bounty, Flow for passage, Endure for danger and rare rewards.
2. **Answer with sound.** Note blocks, jukeboxes and the Singer's songs make healthy sculk bloom, light, bridge and open; natives respond to music.
3. **Tend the flow of souls.** Souls released by life and death feed healthy sculk and can be condensed into soul blocks that power golems, tools and gates. Illagers take them by force, and the land sickens where they do.

**What comes home:** the Singer's song (a sound tool with uses in the Deep Dark), a large new building palette, companions (blubs, echo golems), soul-powered utilities, Tide-bound materials for sidegrade gear, and new music.

## 5. Player journey
| Stage | What happens | What teaches it |
|---|---|---|
| **Rumor** | In an Ancient City, souls released near sculk drift *into* the old reinforced-deepslate frame, and the frame hums back when music plays near it | Particles and sound at a landmark players have wondered about since 1.19 |
| **Discovery** | The frame visibly reacts to souls and sound, then opens (entry design: §7) | Feedback at every step: the glow rises, the hum answers |
| **First entry** | Singer's Meadow in Thrive: teal sky, coral grass, blubs, echo golems dancing near the Sift-side gate on its hill | The safest Tide comes first |
| **Survival** | The first Endure: the sky darkens, flora glows, sculkers and stronger sifters walk, soul flow stops. Find shelter or allies, and learn ichor burns souls | The sky, music and spawns all change at once, so the rule is easy to see |
| **Mastery** | Receive the Singer's gift of song; grow healthy sculk with souls and music; befriend blubs and echo golems; free caged golems from Illager camps; craft Sift gear | Each native reacts on sight or sound; recipes unlock from Sift materials |
| **Endgame** | Three canon bosses — the **Sculk Monstrosity**, the **Monarch** in the sculker nest, the **Harmonizer** — and the Illager keep at the heart of the occupation | Boss bars, arenas that telegraph, advancements in vanilla's voice |
| **Why come back** | Tide-bound materials renew; soul gardens keep growing; Endure-only creatures and blooms; companions; building palette; music discs | Changing states give a reason to return |

## 6. Progression placement
- **Requires:** reaching an Ancient City (deep, warden country: in practice iron or diamond gear) and completing the entry (§7). No Nether or End prerequisite: the Sift is a **mid-to-late side branch beside the Nether**, not a step before or after the End.
- **Gives:** new *capabilities and sidegrades*, not higher tiers: sound tools, soul utilities, companions, blocks, music, and utility-focused gear at or below diamond power.
- **Never gives:** flight (the elytra stays the End's), bulk portable storage (shulkers), armour or tools above netherite, faster travel than the Nether (coordinate scale 1:1), renewable diamonds or netherite, or free experience (every soul↔XP conversion loses value).
- **Why vanilla stays intact:** the Sift's rewards change *how* you play (sound, souls, Tides, friends) without skipping a vanilla milestone. Deep Dark help (calming sculk with song) is temporary and costs souls, so the Ancient City stays dangerous.

## 7. Entry and return path (details and scoring: `vision/entry_path.md`, D-006)
**"Souls wake it, song opens it."** 15 ideas were scored; this one won (32/35).
1. **Rumor.** Every Ancient City frame starts dormant. While its opening is empty, experience orbs within ~8 blocks drift into it along a visible soul trail. Players mining the city's sculk will see their XP pulled into the frame.
2. **Wake.** Enough souls (target ≈10 levels' worth of orbs, tuned in BALANCE) make the frame glow in visible steps until it is awake: a steady light, a low hum, drifting note particles. You feed it in warden country, so the risk is real.
3. **Open.** Any music played before an awake frame (note block, jukebox, goat horn, later the Singer's song) fills the 20×6 opening with a cyan membrane. There is no melody puzzle and no new key item.
4. **Cross.** Nether-style portal timing. You arrive at a **Sift-side gate** on a red-sculk hill in the nearest Singer's Meadow-type biome at the matching x/z (1:1). The gate area is a sanctuary: no hostile spawns nearby, and echo golems gather there. That makes a mid-Endure arrival survivable.
5. **Return.** Walk back through the gate to its linked frame (POI pairing). A broken Sift-side gate reopens with music. Rifts remain the Illagers' tool (Phase 2 content), not the player's front door.
Why: it uses both canon ingredients (souls and music), teaches itself through feedback, needs no new key item, and differs from the three fan mods that already use this frame. Known interaction: if another mod's portal already fills the frame, we stand aside.

## 8. The dimension's rules (full table and routes: `vision/rules.md`)
**Rule identity:** *the Tide sets the rules; everything else behaves like home.* The Sift is serene, not hostile, so the default precedent is the Overworld, not the Nether or End.
- **No day or night; the Tide instead.** Sky light, sky/fog colour, stars, ambient motes, music and spawn tables are keyframed on one Tide timeline. Surface monsters appear only when Endure darkens the sky, so "stronger mobs spawn" falls out of vanilla light rules. `/time` in the Sift moves the Tide, and **ordinary clocks show the Tide** (no new item).
- **Beds set your spawn but you can't sleep:** there is no night to skip, and the Tide cannot be skipped. Respawn anchors don't work. No explosions.
- **No weather; no raids or pillager patrols** (the occupation replaces them). Nether portals can't be lit (vanilla). Coordinates are 1:1.
- **Compasses spin; lodestone and recovery compasses work; maps work.**
- **Ichor** (canon hazard): a liquid that sets outsiders alight with soul fire and drains their XP. Natives are immune, and some thrive in it (Mojang: "mobs that thrive through things that hurt the player").
- **Night-bound vanilla behaviour follows Endure** (bees stay home, eyeblossoms open). Shriekers placed in the Sift never summon wardens.
- About 80% of this is vanilla data (dimension type + environment attributes + one timeline). Code is needed only for ichor, the shrieker rule, "stronger" spawns, and an optional aurora sky.

## 9. Core systems (concepts, scores and link map: `vision/systems.md`, D-007)
- **The Tides.** One global `thesift:tides` clock with a 20-minute cycle: **Thrive** (≈8 min, day-like: souls flow, sculk blooms, natives are out) → **Flow** (≈2 min, the calm hinge) → **Endure** (≈8 min, night-like: soul flow stops, hostiles and sculkers surface with a readable glow, rare Endure blooms open) → **Flow** (dawn). Data-driven: a vanilla timeline keyframes the look, spawns and our own registered attributes (`thesift:gameplay/soul_flow`, `thesift:gameplay/tide`), so data packs can retune it and sync, saving and `/time` come free. Later lever (Should): a costly act shifts the Tide for everyone, as beds skip the night.
- **Souls = experience in physical form.** No new currency and no HUD meter. Life and death release souls (XP). **Healthy sculk** drinks them and blooms, most in Thrive, and song draws them back out. Souls can be condensed into **soul blocks**, a deliberately lossy store (≈30% lost) that powers echo golems, gates and Sift gear. Ichor and soul fire drain souls from outsiders. **Illagers** pump souls into **soul tanks**; breaking a tank frees them.
- **Healthy vs corrupted sculk.** Healthy sculk is colourful and listens to *reward*: music makes it bloom, spread and release souls. Where Illagers drain souls, it sickens into grey **blight** (corrupted sculk) that shrieks and breeds sculkers. Returning souls, or song, cures it. This gives canon's "disease that originated in the Sift" a mechanism.
- **Sound.** Healthy sculk and natives answer music (blubs gather; echo golems dance). The Singer's **gift of song** is an earned instrument that opens gates, blooms sculk in a radius, and briefly soothes sculkers and wardens at a soul cost. Musical gates guard key places. Every sound has a visual.
- **The Illager occupation.** Soul-harvester camps with rigs over blight, caged echo golems (freed ones become allies), soul tanks, and patrols during the day-Tides. Endure sculkers attack the camps, a war the player can exploit. The **Illager Keep** is an endgame stronghold and rift hub. Rift incursions into the Overworld are decided in Phase 2 (vanilla footprint).
- **Everything connects:** Tides → light, spawns, soul flow, camp activity; souls → sculk, gates, golems; Illagers → blight → sculkers; sound → sculk, natives, gates.

## 10. Critique log — *WP-014 (pending)*
