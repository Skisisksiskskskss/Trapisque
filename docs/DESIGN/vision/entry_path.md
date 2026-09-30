# Entry and return path (WP-011)

## Constraints gathered first
- **Canon:** the Ancient City centre frame *is* the Sift portal (revealed 2026-03-21). Dungeons II opens it with the **Note Block Machine** (eight note blocks, three missing from across the Overworld) and **echo golems** ignite it; the Twisted Warden guards it; Singers can open it "with their song"; **rifts** are temporary portals to and from the Sift (RESEARCH.md canon #2–5).
- **Vanilla facts:** the frame is 22×8 reinforced deepslate with a 20×6 opening, one per Ancient City, unbreakable and unobtainable in survival (VANILLA_ANALOGS W6). **Deep Dark and Ancient Cities have no natural mob spawns** (spawn tables empty), so "kill mobs near the frame" cannot be the only soul source. Sculk, sensors, shriekers and catalysts all drop XP when mined; echo shards are city loot.
- **Prior art:** Mielon's The Sift (8-note melody on special note blocks), Deeper and Darker (warden trophy item), Sculk Depths (item on pedestals) all claim this frame (RESEARCH.md §8).
- **Pillars:** P1 sound, P3 souls, P4 readable wonder; plus §6 progression (mid-to-late, no Nether/End prerequisite).

## Diverge — 15 ideas (before scoring)
1. **Melody on note blocks** in front of the frame (the canonical machine as a puzzle).
2. **Three resonant note blocks** hidden in Overworld structures, set before the frame, then played (the canon "three missing note blocks" as an eyes-of-ender-style quest).
3. **Souls wake it, song opens it** — the dormant frame drinks souls (experience) released near it until it glows awake; then any music played before it opens the gate.
4. **Warden trophy** — a warden (Twisted Warden stand-in) drop activates the frame.
5. **Echo-shard tuning fork** — crafted from echo shards (recipe unlocks on pickup, like the recovery compass); strike the frame to open it.
6. **Rift first** — rare temporary rifts in the Deep Dark lead one-way into the Sift; the Singer then opens the frame from the inside (canon: the story's first entry is a rift).
7. **Illager rift incursions** — Illager bands come through rifts in the Overworld; beat them and step through before the rift closes.
8. **Sift music disc** found in the city, played in a jukebox before the frame.
9. **Goat horn "Sing"** (or a new horn) blown at the frame.
10. **Calibrated-sensor chord** — tune calibrated sculk sensors around the frame to a frequency set.
11. **Allay escort** — an allay handed a Sift relic flies to the frame and "dances it open" to music.
12. *(unusual)* **Soul journey** — die near the frame carrying an echo shard; your soul crosses and you wake in the Sift.
13. *(unusual)* **Build-your-own gate** — craft resonant frame blocks from echo shards and build a Sift gate anywhere, Nether-style.
14. *(unusual)* **Soul Sand Valley rifts** — rifts form in the Nether's soul valleys and lead to the Sift.
15. **Bottled echo** — Ancient City chests hold a sealed Singer's song that opens the frame for a short time; the Singer later teaches a permanent song.

## Converge — rubric (1–5)
| # | Idea | Faithful | Vanilla-native | Readable | Meaningful | Distinct | Connected | Feasible | Total |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Melody puzzle | 5 | 4 | 3 | 3 | 1 | 3 | 4 | 23 |
| 2 | Three resonant note blocks | 5 | 4 | 4 | 4 | 3 | 3 | 3 | 26 |
| **3** | **Souls wake it, song opens it** | 5 | 5 | 5 | 4 | 4 | 5 | 4 | **32** |
| 4 | Warden trophy | 3 | 4 | 4 | 3 | 1 | 2 | 5 | 22 |
| 5 | Echo tuning fork | 3 | 5 | 4 | 3 | 3 | 3 | 5 | 26 |
| 6 | Rift first | 5 | 3 | 3 | 5 | 5 | 4 | 3 | 28 |
| 7 | Illager rift incursions | 5 | 3 | 4 | 4 | 4 | 4 | 2 | 26 |
| 8 | Sift music disc | 3 | 5 | 4 | 2 | 3 | 3 | 5 | 25 |
| 9 | Goat horn | 2 | 4 | 3 | 2 | 4 | 2 | 5 | 22 |
| 10 | Calibrated chord | 3 | 4 | 2 | 3 | 4 | 3 | 4 | 23 |
| 11 | Allay escort | 2 | 3 | 3 | 3 | 5 | 3 | 3 | 22 |
| 12 | Soul journey | 2 | 2 | 2 | 3 | 5 | 4 | 3 | 21 |
| 13 | Build-your-own gate | 2 | 5 | 5 | 4 | 3 | 2 | 5 | 26 |
| 14 | Soul Sand Valley rifts | 2 | 3 | 3 | 3 | 5 | 3 | 3 | 22 |
| 15 | Bottled echo | 4 | 4 | 4 | 3 | 4 | 3 | 4 | 26 |

Decisive calls: #1 is canon but is exactly an existing mod's signature (distinct 1). #6 is the most dramatic but random rifts and one-way stranding fight P4 and vanilla's "you choose when to go" norm. #3 is the only idea that uses **both** canon ingredients (souls and music), teaches itself with visible feedback, and needs no new item.

## Chosen design — "Souls wake it, song opens it" (#3, with #6 kept for the Illager side)
**Dormant.** Every Ancient City frame starts dormant. While its opening is empty, **experience orbs within ~8 blocks drift into the frame** along a visible soul trail (vanilla `sculk_soul` particles) instead of to players. Mining the city's sculk, sensors and catalysts, killing mobs the player brings, throwing bottles o' enchanting, or dying nearby all feed it. That drift is the **rumor**: players who have mined sculk here since 1.19 will notice their XP being pulled into the frame.

**Waking.** The frame's charge shows in steps: faint cyan specks on the reinforced deepslate, then a pulsing glow along the inner edge, then a steady light with a low hum and drifting note particles. Full charge costs roughly the experience of an enchanting-table session (tuned in BALANCE.md; target ≈10 levels' worth of orbs). Feeding happens in warden country, and mining sculk trips sensors, so danger is earned rather than added.

**Opening.** When the frame is awake, **any music played within range opens it**: a note block, a jukebox, a goat horn, or later the Singer's song. There is no sequence to learn; the awake frame's drifting notes suggest what to do. The 20×6 opening fills with a bright cyan membrane (our portal block) with the canon look (RESEARCH.md S-I4). Advancement: *Note Block Virtuoso* style, in vanilla's voice.

**Crossing.** A standard portal transition (`Portal` + `TeleportTransition`, VANILLA_ANALOGS W5), about a Nether portal's delay with a soft chime and a music swell. Arrival is at the **Sift-side gate**: a natural hill of red healthy sculk with a Sift-stone frame, placed in the nearest **Singer's Meadow**-type biome within search range of the matching x/z (1:1 scale), generated on first use the way the Nether portal forcer does. The area around the gate is a **sanctuary**: no hostile spawns within a small radius, and echo golems gather there. Arriving mid-Endure is therefore still survivable (P4).

**Return.** Walking back through the Sift-side gate returns you to the frame it is linked to (POI pairing, as with Nether portals). A broken Sift-side gate can be re-opened with music, the same verb as entry. Dying in the Sift sends you to your Overworld respawn unless you set one in the Sift (rules: §8). Illager **rifts** (idea #6/#7) are *not* a player entry. They are how the occupation moves, and they become content in Phase 2.

## Why not rifts first? (evidence check after the press pass)
In Dungeons II, rifts are the everyday way in and the Deep Dark portal is late story: 77.7% of Steam players have "Brave the Unknown" (enter the Sift) but only 2.9% have "Note Block Virtuoso" (activate the machine) [RESEARCH.md §9]. A sandbox reverses that order on purpose:
1. **A landmark you can return to** beats a random event. Survival players plan trips, build bases and come back. The Nether portal and End portal are both places, not events.
2. **The frame is the Java mystery.** Players have wondered about the Ancient City frame since 1.19, and canon confirms it is the Sift's original portal.
3. **Random one-way portals fight P4** (they strand, and players can't choose when to go) and add Overworld-wide changes, which rule 9.4 (minimal vanilla footprint) discourages.
4. **Rifts stay canon on the Illager side.** In Phase 2 they are how the occupation moves (Illager rift camps inside the Sift; rift incursions tied to occupation events). They are content, not the front door. Recorded as an alternative at Gate A.

## Failure modes and edge cases (concept level)
| Case | Handling |
|---|---|
| Another mod's portal already fills the frame (Deeper and Darker etc.) | Our logic only runs while the opening is air, so the first mod to open it wins. Documented as a known interaction |
| Worlds created before the mod was installed | Frames are found from the saved Ancient City structure starts, so old worlds work too |
| No Ancient Cities (superflat, custom worlds) | No survival entry; operators can use `/execute in thesift:the_sift`. Documented |
| Frame edited in creative (broken reinforced deepslate) | Geometry check fails, so the frame stays dormant |
| XP pulled from players who didn't want it | Only within ~8 blocks of a *dormant* frame, and it stops once the frame is awake. The trail is visible, so the player understands and can step away |
| Wardens | Intended pressure; sculk mining near shriekers is the risk |
| Multiplayer | The gate is shared once open; each player's first crossing grants their own advancement |
| Peaceful | Works: sculk XP needs no mobs |
| Griefing | Frame unbreakable; the membrane obeys the portal rules; the Sift-side gate can be reopened with music |

## Performance notes
Frames are located from Ancient City structure pieces (known template and rotation → exact frame coordinates), cached per chunk in SavedData, and never found by scanning blocks. XP attraction queries a small box around each known dormant frame only while a player is within ~32 blocks. Music is detected by a vibration listener placed at the frame, so there is no per-tick polling.
