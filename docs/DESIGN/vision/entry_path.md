# Entry and return path (WP-011; revised after WP-014 critique rounds 1 and 2)

## Constraints gathered first
- **Canon** (RESEARCH.md canon #2–5, §6):
  - In Dungeons II the story portal is a large structure at the centre of the Ancient City. Official images show a dark frame with a wide opening, and eight rainbow-topped note blocks in front. It resembles the vanilla city-centre frame (M).
  - It is opened by the **Note Block Machine** (three missing note blocks returned, after the **Twisted Warden** falls), and **echo golems** ignite it.
  - That a Singer can open it "with their song" is novel-only (L).
  - **Rifts** are Dungeons II's everyday way in (official).
  - **No source says how Java will reach the Sift:** "Mojang isn’t talking too much about how to access the Sift" [XW1]. Using the vanilla frame is our design choice, grounded in Dungeons II; it is not a Java fact.
- **Vanilla facts** (VANILLA_ANALOGS W6, 26.3 source):
  - The frame is 22×8 reinforced deepslate with a 20×6 opening, one per Ancient City, unbreakable and unobtainable in survival.
  - Deep Dark and Ancient Cities have **no natural mob spawns**.
  - Mined sculk drops 1 XP; sensors, shriekers and catalysts drop 5; so the city's blocks are a thin XP source.
  - In vanilla, experience orbs never move away from a player.
- **Prior art on 26.3** (RESEARCH §8, `research/prior_art_2026-09-30.md`):
  - Mielon's The Sift (PA-1): an 8-note melody on custom note blocks on "Sonorous Deepslate"; "awaken it with sound".
  - Deeper and Darker (PA-2) and Sculk Depths (PA-3) have no 26.x release.
- **Pillars:** P1 sound, P3 souls, P4 readable wonder; plus §6 progression (mid-to-late, no Nether or End prerequisite).

## Diverge: 15 ideas (written before scoring)
1. **Melody on note blocks** in front of the frame (the canonical machine as a puzzle).
2. **Three resonant note blocks** hidden in Overworld structures, set before the frame, then played. This is the canon "three missing note blocks" as a quest like the eyes of ender.
3. **Souls wake it, song opens it.** The dormant frame drinks souls (experience) until it glows awake; then any music played before it opens the gate.
4. **Warden trophy**: a warden drop (standing in for the Twisted Warden) activates the frame.
5. **Echo-shard tuning fork**: crafted from echo shards (the recipe unlocks on pickup, like the recovery compass); strike the frame to open it.
6. **Rift first**: rare temporary rifts in the Deep Dark lead one way into the Sift; the Singer then opens the frame from the inside (canon: the story's first entry is a rift).
7. **Illager rift incursions**: Illager bands come through rifts in the Overworld; beat them and step through before the rift closes.
8. **Sift music disc** found in the city, played in a jukebox before the frame.
9. **Goat horn "Sing"** (or a new horn) blown at the frame.
10. **Calibrated-sensor chord**: tune calibrated sculk sensors around the frame to a set of frequencies.
11. **Allay escort**: an allay handed a Sift relic flies to the frame and "dances it open" to music.
12. *(unusual)* **Soul journey**: die near the frame carrying an echo shard; your soul crosses and you wake in the Sift.
13. *(unusual)* **Build-your-own gate**: craft resonant frame blocks from echo shards and build a Sift gate anywhere, Nether-style.
14. *(unusual)* **Soul Sand Valley rifts**: rifts form in the Nether's soul valleys and lead to the Sift.
15. **Bottled echo**: Ancient City chests hold a sealed Singer's song that opens the frame for a short time; the Singer later teaches a permanent song.

## Converge: rubric (1–5)
Round-1 rescoring is marked ↓/↑ (see the notes below).

| # | Idea | Faithful | Vanilla-native | Readable | Meaningful | Distinct | Connected | Feasible | Total |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Melody puzzle | 5 | 4 | 3 | 3 | 1 | 3 | 4 | 23 |
| 2 | Three resonant note blocks | 5 | 4 | 4 | 4 | 3 | 3 | 3 | 26 |
| 3 | Souls wake it (orbs pulled in passively), song opens it | 3↓ | 3↓ | 2↓ | 4 | 3↓ | 5 | 4 | 24 |
| **3′** | **Offer souls to wake it, song opens it** (the revised design below; since round 2, offering is a deliberate hold-use) | 4 | 4 | 4 | 4 | 4 | 5 | 4 | **29** |
| 4 | Warden trophy | 3 | 4 | 4 | 3 | 1 | 2 | 5 | 22 |
| 5 | Echo tuning fork | 3 | 5 | 4 | 3 | 3 | 3 | 5 | 26 |
| 6 | Rift first | 5 | 3 | 3 | 5 | 5 | 4 | 3 | **28** |
| 7 | Illager rift incursions | 5 | 3 | 4 | 4 | 4 | 4 | 2 | 26 |
| 8 | Sift music disc | 3 | 5 | 4 | 2 | 3 | 3 | 5 | 25 |
| 9 | Goat horn | 2 | 4 | 3 | 2 | 4 | 2 | 5 | 22 |
| 10 | Calibrated chord | 3 | 4 | 2 | 3 | 4 | 3 | 4 | 23 |
| 11 | Allay escort | 2 | 3 | 3 | 3 | 5 | 3 | 3 | 22 |
| 12 | Soul journey | 2 | 2 | 2 | 3 | 5 | 4 | 3 | 21 |
| 13 | Build-your-own gate | 2 | 5 | 5 | 4 | 3 | 2 | 5 | 26 |
| 14 | Soul Sand Valley rifts | 2 | 3 | 3 | 3 | 5 | 3 | 3 | 22 |
| 15 | Bottled echo | 4 | 4 | 4 | 3 | 4 | 3 | 4 | 26 |

**Rescoring notes (critique round 1):**
- #3 as first written loses Faithful: souls waking the frame is our invention, and only music opening it echoes canon.
- It loses Vanilla-native, because orbs never fly away from players in vanilla.
- It loses Readable, because its price can't be paid on purpose (MF5).
- It loses Distinct, because Mielon's mod also "awakens it with sound".

**Decisive calls:**
- **#3′ (29) edges #6 (28).** Distinct is scored 4: it is the only frame entry paid in souls. Music is a trigger, not a puzzle (unlike Mielon's melody), and the membrane previews the far side. Even at a tie, rift-first as the *player's* front door would scatter random portals across the Overworld. That runs against hard rule 9.4 (minimal vanilla footprint outside the Sift) and against P4, since one-way rifts strand players who can't choose when to go.
- #1 is canon, but it is exactly an existing 26.3 mod's signature (Distinct 1).
- #3′ wins: it uses both canon ingredients (souls and music), each state shows what it wants next, it needs no new key item, and it never takes anything without a deliberate action.
- Rift-first stays the main alternative at Gate A.

## Chosen design: "Offer souls to wake it; music opens it" (#3′)
1. **Rumor (free, cosmetic).** A dormant frame **breathes**: faint soul wisps rise from the city's sculk and drift into its opening. When a mob dies within ~16 blocks, its soul visibly streams into the frame. That is rare, because Ancient Cities spawn no mobs, so the breathing is the main hint. The XP is untouched, or taken by a vanilla catalyst nearby as usual: this is a hint, not a cost.
2. **Notice.** A player who comes near is noticed: the wisps curl toward them, the frame's inner edge brightens where they look, and a low hum deepens. Every cue has a visual and a subtitle.
3. **Offer (the price, taken only by a deliberate action).**
   - **Hold *use*** on the frame with an empty hand. Your XP bar visibly streams into it as souls, like brushing suspicious sand, at about 50 points per second. Release and it stops.
   - Nothing is taken by standing, crouching, walking through, or any accident. Vanilla spends XP only on a deliberate action too: the enchanting table, the anvil.
   - Charge is stored per frame, so several players and several visits can pool it.
   - **Price:** as much experience as reaching level 30 from zero, **1 395 points** (the level-30 enchantment milestone), about half a minute of offering. It is a one-time cost per frame, tuned in BALANCE.md.
   - Feeding happens in warden country: offering and playing music make vibrations, so the risk is earned, not added.
4. **Wake.**
   - The charge shows in steps: faint cyan specks on the reinforced deepslate, then a pulsing inner edge, then a steady light.
   - Once awake, the frame hums and **note particles drift from it**, which is the hint that it now wants music.
5. **Open.**
   - Any music played within range opens it: a note block or a goat horn (both vibrations), a jukebox, or later the gift of song.
   - A jukebox needs its own listener, at vanilla's radius of 10: `jukebox_play` isn't a vibration, and allays hear jukeboxes the same way.
   - The 20×6 opening fills with a cyan membrane, our portal block.
   - The membrane **shows the Tide on the far side** through colour and particle shape (systems.md §1).
   - The Tide clock stays paused at Thrive until the **first crossing** in the world. So the first arrival in a world is in Thrive; later arrivals see the far-side Tide before they step through.
6. **Cross.**
   - The standard portal transition (`Portal` + `TeleportTransition`, VANILLA_ANALOGS W5), with a Nether portal's delay, a soft chime and a music swell.
   - Arrival is at a **Sift-side gate**: a hill of red healthy sculk topped by an unbreakable Sift-stone frame.
   - The gate is placed in the nearest Singer's Meadow biome within **256 blocks** of the matching x/z (1:1). If there is none, it goes at the matching x/z on the highest safe surface.
   - Gates keep at least **64 blocks** from each other, so two cities never share one.
   - The frame ↔ gate link is stored explicitly in SavedData, not rediscovered through a POI search.
7. **Sanctuary.**
   - No hostile spawns within ~16 blocks of a gate, and echo golems gather there. So arriving mid-Endure is survivable.
   - A base built at a gate gets the protection any lit base gets; that is accepted.
8. **Return.**
   - Walking back through the gate returns you to its linked frame.
   - Gate frames can't be broken in survival and drop nothing, so this is never a build-your-own-gate (#13).
   - If a membrane is removed (by commands, creative mode or another mod), music reopens it: the same verb as entry.
   - Dying in the Sift sends you to your Overworld respawn unless you set one in the Sift (rules.md).
   - Illager **rifts** are *not* a player entry. They are how the occupation moves, and they come after 1.0 (systems.md §7).

## Why not rifts first? (evidence check)
In Dungeons II, rifts are the everyday way in, and the Deep Dark portal belongs to the later story (MC1). Steam rates one day after launch fit that order: 77.7% have "Brave the Unknown" and 2.9% have "Note Block Virtuoso". Being one day old, the numbers show the order players meet things, not their preferences [RESEARCH.md §9].

A sandbox reverses that order on purpose:
1. **A landmark you can return to beats a random event.** Survival players plan trips, build bases and come back. The Nether portal and the End portal are both places, not events.
2. **The frame is the Java mystery.** Players have wondered about the Ancient City frame since 1.19, and Dungeons II puts its story portal at the centre of the Ancient City. That grounds the choice in canon, though it doesn't make it Java canon.
3. **Random one-way portals fight P4 and hard rule 9.4.** They strand players, they take away the choice of when to go, and they add Overworld-wide changes.
4. **Rifts stay canon on the Illager side.** After 1.0 they are how the occupation moves. This is recorded as the main alternative at Gate A.

## Failure modes and edge cases (concept level)
| Case | Handling |
|---|---|
| Another mod's portal already fills the frame (Mielon's The Sift on 26.3; others if they port) | Our logic runs only while the opening is air, so the first mod to open it wins. Documented as a known interaction |
| A player walks through or crouches in the opening | Nothing is taken. Only holding *use* on the frame with an empty hand offers XP |
| A player holds *use* by mistake | The stream is loud and visible, and release stops it at once. What was given stays as charge, so nothing is wasted |
| Worlds created before the mod was installed | Frames are found from the saved Ancient City structure starts, so old worlds work too |
| No Ancient Cities (superflat, custom worlds) | No survival entry; operators can use `/execute in thesift:the_sift`. Documented |
| Frame edited in creative (reinforced deepslate broken) | The geometry check fails, so the frame stays dormant |
| Wardens | Intended pressure; mining sculk near shriekers is the risk. The first trip carries the danger; later trips are easier. Accepted, as in vanilla |
| Multiplayer | Charge pools across players. The gate is shared once open. Each player's first crossing grants their own advancement |
| Peaceful | Works: offering needs no mobs |
| `advance_time false` | The frame still opens. The Tide clock stays frozen where it is: at Thrive if nobody has crossed yet, otherwise wherever the admin set it (systems.md §1) |
| Griefing | Frames and gates are unbreakable; the membrane obeys the portal rules; music reopens a removed membrane |

## Performance notes
- Frames are located from Ancient City structure pieces (a known template and rotation give exact frame coordinates) and cached per chunk in SavedData, never found by scanning blocks.
- Offering is a use-block event (Fabric `UseBlockCallback`) checked against known frame positions. There is no per-tick scanning.
- Music is detected at each awake frame by a vibration listener (note blocks, goat horns) and a jukebox listener, so nothing polls every tick.
- The ambient "breathing" particles are client-side and run only near dormant frames.
