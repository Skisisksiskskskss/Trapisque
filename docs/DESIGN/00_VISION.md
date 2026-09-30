# The Sift — Vision

**Status:** DRAFT, revised after critique round 1 (WP-014). It becomes FROZEN at Gate A.

Supporting work: `vision/concepts.md` (14 concepts, rubric, merge), `vision/entry_path.md`, `vision/rules.md`, `vision/systems.md`. Canon: `../RESEARCH.md`.

*Unofficial fan project, not affiliated with or endorsed by Mojang Studios or Microsoft.*

## 1. Fantasy
**The Sift is the living heart the Deep Dark lost: a luminous world of healthy sculk that answers sound instead of punishing it, where light, creatures and souls rise and fall with the Tides.**

## 2. Tone
- **Wonder first.** A teal sky over coral-orange grass and pale trees (the vanilla first look, D-002); flora that seems to glow; creatures that squeak, bounce and sing. The first minutes are beautiful and safe enough to look around.
- **The Deep Dark, inverted.** Down there, silence keeps you alive. Here, in Thrive, sound is how you are heard, welcomed and helped. The same sculk grammar the player already fears means something kinder. When Endure falls, the old rule returns: the hunters listen too.
- **A song with a shadow.**
  - Each cycle ends in Endure: the light fails, the stars come out, and stronger things walk.
  - The Illagers are here, draining souls from the ground. Where they work, the colour drains to the Deep Dark's black-teal. Their draining feeds an old disease; they didn't start it.
- **Vanilla restraint.** There are no dialogue windows and no quest log. Places tell the story: a caged echo golem, a patch of blight where a harvester stood, souls drifting into an Ancient City frame. Few new things, each doing a lot.

## 3. Pillars (every later decision is checked against these)
| # | Pillar | A feature passes if… |
|---|---|---|
| P1 | **Sound brings life**: the Sift listens and answers | the player can change it, or read it, through sound; that sound has a price or a risk somewhere (in Endure, the hunters hear it); and every audio cue has a visual and a subtitle |
| P2 | **The Tide sets the rules**: the world breathes on a readable cycle | it behaves differently in at least one Tide, and the difference can be seen or heard without UI |
| P3 | **Souls are the lifeblood**: life feeds the Sift, and you decide where your own souls go | souls visibly move because of it (drunk, offered, spent, freed or drained), and it never turns souls back into experience |
| P4 | **Wonder first, danger earned**: beauty up front, threat that telegraphs | a first-time player can survive their first Thrive by watching, and every lethal threat has a wind-up and a counter |

Tie-breakers: canon over invention; vanilla grammar over new UI; fewer, deeper features over more.

## 4. Why the Sift exists (the verbs no other dimension offers)
1. **Read the Tide.** Plan around a visible cycle with one rule per Tide.
   - **Thrive** for growth, when soul tools recharge twice as fast.
   - **Flow** for passage, when tide-bridges unfold and bounce blooms spring.
   - **Endure** for danger and rare blooms, when the hunters surface and hear every sound.
2. **Answer with sound.** Note blocks, jukeboxes and the Singer's gift of song spark growth, light and gates, and natives respond to music. In Endure the same music is a lure.
3. **Tend the flow of souls.**
   - Deaths near a bloom heart feed healthy sculk, as a vanilla catalyst would.
   - Players *offer* their own experience to wake frames and make soul blocks, which are fuel for golems, gates and upgrades.
   - Illagers steal souls, and blight spreads where they do.
   - Nothing turns souls back into experience.

**What comes home:**
- the gift of song (usable wherever there is Sift life);
- a large new building palette;
- companions (blubs, echo golems) running on soul blocks;
- soul-powered utilities;
- Tide-bound reagents for upgrades to your existing gear;
- new music.

Nothing from the Sift grows or spreads in the Overworld.

## 5. Player journey
| Stage | What happens | What teaches it |
|---|---|---|
| **Rumor** | In an Ancient City, faint souls rise from the sculk and drift into the old reinforced-deepslate frame; a mob that dies nearby sends its soul streaming in | Particles at a landmark players have wondered about since 1.19. The frame "breathes" souls, so it wants souls |
| **Discovery** | Step into the opening: the souls curl toward you. Crouch, as you already do in the Deep Dark, and your experience flows in. The frame wakes in steps, drifts note particles, and opens to music (§7) | Each state shows what it wants next: souls, then music |
| **First entry** | Singer's Meadow in Thrive (the Tide clock starts at the first opening): teal sky, coral grass, blubs, echo golems near the Sift-side gate on its hill | The safest Tide comes first, guaranteed |
| **Survival** | The first Endure: the sky darkens, stars appear, sculkers and stronger sifters surface, growth stops, and music now draws hunters. Find shelter, or go quiet. Learn that ichor burns souls | The sky, the music and the spawns all change at once, so the rule is easy to see |
| **Mastery** | Earn the Singer's gift of song by restoring the Meadow's stolen harmony. Cross ichor lakes in Flow. Grow healthy sculk around bloom hearts. Free caged golems from Illager camps and lure Endure's hunters into them. Upgrade your gear with Sift reagents | Each native reacts on sight or sound; recipes unlock from Sift materials |
| **Endgame (1.0)** | One canon boss, the **Sculk Monstrosity**, heart of the blight; beating it cures the land around its arena. One miniboss, the **Harmonizer** | Boss bars, arenas that telegraph, advancements in vanilla's voice |
| **Why come back** | Growth renews around your bloom hearts; Endure-only blooms; companions; the building palette; Tide music. After 1.0: the Monarch, the Illager Keep, rifts | Changing states give a reason to return |

## 6. Progression placement
- **Requires:**
  - reaching an Ancient City, which is deep warden country, so in practice iron or diamond gear;
  - paying the frame's price: the experience of reaching level 30 from zero, once per frame, which can be pooled.

  There is no Nether or End prerequisite. The Sift is a **mid-to-late side branch beside the Nether**, not a step before or after the End.
- **Gives:**
  - new *capabilities and sidegrades*: sound tools, soul utilities, companions, blocks and music;
  - **upgrades applied to the gear you already have**, each adding a utility trait, as a smithing template does.

  There is never a new tool or armour tier, and mining tiers are untouched.
- **Never gives:**
  - flight (the elytra stays the End's);
  - bulk portable storage (shulkers);
  - armour or tools above netherite;
  - faster travel than the Nether (coordinate scale 1:1);
  - renewable diamonds or netherite;
  - **any way to create experience or turn souls back into it;**
  - **any power over wardens or the Deep Dark's sculk.**
- **Why vanilla stays intact:**
  - The Sift's rewards change *how* you play (sound, souls, Tides, friends) without skipping a vanilla milestone.
  - The gift of song and every soul effect work only on Sift life, and curing blight needs the Sift's soul flow, so the Ancient City stays exactly as dangerous.
  - The Sift's weather rule leaves the Overworld's weather untouched (§8).

## 7. Entry and return path (details and scoring: `vision/entry_path.md`, D-006)
**"Offer souls to wake it; music opens it."** 15 ideas were scored, and the revised design ties rift-first at 28/35. It wins on hard rule 9.4 and P4.
1. **Rumor.** A dormant frame breathes: souls drift from the city's sculk into its opening. Nearby deaths send their souls in too, as a cosmetic effect (their XP still drops).
2. **Offer.**
   - Crouch inside the opening and your XP bar flows into the frame. Stand up and it stops. Nothing is taken any other way.
   - The price is 1 395 points (level 0 → 30), once per frame, and can be pooled.
   - The charge shows in visible steps.
3. **Open.**
   - The awake frame drifts note particles. Any music played before it (a note block, jukebox, goat horn, or later the gift of song) fills the 20×6 opening with a cyan membrane.
   - The membrane shows the Tide on the far side.
   - The first opening in a world starts the Tide clock at Thrive.
4. **Cross.**
   - Nether-style portal timing.
   - You arrive at an unbreakable **Sift-side gate** on a red-sculk hill, in the nearest Singer's Meadow within 256 blocks of the matching x/z, with a fallback. The link is stored explicitly.
   - The gate area is a sanctuary: no hostile spawns within ~16 blocks.
5. **Return.** Walk back through the gate to its linked frame. A removed membrane reopens with music. Rifts remain the Illagers' tool after 1.0, not the player's front door.

Why: it uses both canon ingredients (souls and music), each state teaches the next, it needs no new key item, and its cost is chosen, never taken. Canon places Dungeons II's story portal at the Ancient City's centre. Mojang hasn't said how Java will reach the Sift, so this is a design choice grounded in canon. Known interaction: if another mod's portal already fills the frame (Mielon's The Sift runs on 26.3), we stand aside.

## 8. The dimension's rules (full table and routes: `vision/rules.md`)
**Rule identity:** *the Tide sets the rules; everything else behaves like home.* The Sift is serene, not hostile, so the default precedent is the Overworld. Where vanilla treats every non-Overworld dimension alike, the Sift follows the Nether and End.
- **No day or night; the Tide instead.**
  - A 25-minute cycle keyframes sky light, sky and fog colour, stars (Endure only), motes and music on one timeline.
  - Surface monsters appear only when Endure darkens the land (vanilla light rules).
  - **No sun or moon** is drawn. Clocks spin, as in the Nether and End. An inverted daylight detector senses Endure.
  - `/time set thesift:thrive` moves the Tide.
- **Beds:**
  - Beds set your spawn and let you rest, which resets the phantom timer, but you can't sleep, and nothing skips the Tide except the late lever, and only toward Thrive.
  - A charged respawn anchor explodes if used, as in the Overworld.
- **No weather, and the Overworld's weather is untouched.** Weather in 26.3 is server-global, so this takes one small mixin (D-008). The data-only alternative breaks maps. There are no raids, patrols or phantoms. Nether portals can't be lit. Coordinates are 1:1.
- Compasses spin; lodestone and recovery compasses work; maps work.
- **Ichor** (canon hazard): a liquid that sets outsiders alight with soul fire and drains their XP while they stand in it. Natives are immune, and some thrive in it (Mojang: "mobs that thrive through things that hurt the player"). It evaporates outside the Sift.
- **Night-bound vanilla behaviour follows Endure:** bees stay home, eyeblossoms open, turtle eggs hatch faster, villagers rest.
- **Shriekers** in the Sift never summon wardens.
- **Code** is needed only for the weather mixin, bed rest, ichor, the shrieker rule, enduring variants, soul growth, and the frame and gate. Everything else is dimension-type, attribute and timeline data.

## 9. Core systems (concepts, scores and link map: `vision/systems.md`, D-007)
*Souls are the fuel, music is the spark, the Tide is the season.*
- **The Tides.**
  - One global `thesift:tides` clock with a 30 000-tick (25-minute) cycle: **Thrive** 10 min → **Flow** 2.5 → **Endure** 10 → **Flow** 2.5. Its length is deliberately unlike the Overworld's day.
  - Each Tide has a signature rule:
    - Thrive: growth and double recharge.
    - Flow: tide-bridges and bounce blooms open passages.
    - Endure: hunters, sound draws them, rare blooms open, growth and recharge stop.
  - It is data-driven: a vanilla timeline keyframes the look and our own attributes (`thesift:gameplay/soul_flow`, 0 everywhere outside the Sift). Sync, saving and `/time` come free.
  - The clock starts paused at Thrive until the first frame opens.
  - `advance_time false` freezes it like the sun; admins choose the frozen Tide.
- **Souls: a one-way ledger.**
  - Souls enter two ways: from deaths near a **bloom heart**, which works like a vanilla catalyst (that XP never drops), and from **offerings** of a player's own experience.
  - They leave as growth (blooms, light, reagents), as **soul blocks** (fuel, never a bank), or as a frame's price.
  - Thrive raises the growth *rate*, never the yield. Healthy sculk never drops XP. Illager **soul tanks** are finite; breaking one returns its souls to the land.
- **Healthy vs corrupted sculk.**
  - Healthy sculk is colourful and answers music.
  - **Blight *is* vanilla sculk**, so its pulse, creeping veins, sensors and shriekers set it apart without colour. Where Illagers drain souls, the old disease takes hold.
  - Souls or song cure it, but only where the Sift's soul flow runs, never in the Overworld's Deep Dark.
- **Sound.**
  - Music sparks growth and opens gates, and natives answer it. In Endure, sound draws sculkers.
  - The Singer's **gift of song** is earned by restoring the Meadow's stolen harmony (canon quest shapes). Its charges refill twice as fast in Thrive and not at all in Endure, and it affects only Sift life.
  - Every sound has a visual and a subtitle, and musical gates show their key as a carved instrument glyph.
- **The Illager occupation (1.0).**
  - Finite soul-harvester camps sit over blight, with caged echo golems (freed ones become allies) and soul tanks. Like outposts, their grounds keep spawning illagers.
  - Endure's hunters attack camps, a war the player can steer with sound.
  - The **Illager Keep** and **rifts** come after 1.0.
- **Scope for 1.0 (fewer, deeper):**
  - two canon areas (Singer's Meadow with Lullaby Hills, and the Carapace);
  - four natives and six hostiles from canon;
  - ichor, the gift of song and camps;
  - **one boss (the Sculk Monstrosity) and one miniboss (the Harmonizer).**

  The Monarch, the Keep, rifts, the Tide lever and an aurora sky come after 1.0 (systems.md §7).
- **Everything connects:**
  - Tides → light, growth rate, what sound does;
  - souls → growth, soul blocks → golems, gates and upgrades;
  - Illagers → blight → cured by souls or song;
  - sound → growth, natives, gates, hunters.

## 10. Critique log (WP-014)
**Round 1** (fresh adversarial reviewer; artifact + rubric + 26.3 source; 2026-09-30).

**Verdict: FAIL.** 5 must-fix, 12 should-fix, 5 notes; 27 of 63 scores below 4.

The engine claims were re-checked against the 26.3 source before any design changed, and all held. We found one more error of the same kind: vanilla clocks show time only in the Overworld.

| Finding | Disposition |
|---|---|
| MF1 soul-economy loops (×1.5 re-harvest, non-player kills, XP battery, Mending) | **Fixed:** a one-way ledger; nothing converts back to XP; bloom hearts follow catalyst rules; Thrive raises rate, never yield (§9, systems §2) |
| MF2 the Tide is day/night with a palette, and Flow does nothing | **Fixed:** one signature rule per Tide (Flow = passage); a 30 000-tick period (§9, systems §1) |
| MF3 warden soothing; gear before diamonds | **Fixed:** the song and souls affect only Sift life; gear upgrades existing tiers, never replaces them (§6) |
| MF4 weather leaks in and doubles the Overworld's weather speed | **Fixed:** targeted `canHaveWeather` mixin (D-008); the data-only route rejected with evidence (rules.md) |
| MF5 the entry price can't be paid on purpose; unclear target; XP taken without consent | **Fixed:** crouch-to-offer from the XP bar; price 1 395 points; nothing taken otherwise; staged hints (§7, entry_path) |
| SF1 42% of first arrivals in Endure | **Fixed:** the clock starts at the first opening, in Thrive; the membrane shows the far-side Tide |
| SF2 `advance_time`, one player forcing Endure, lever vs "can't skip", `/time set day` | **Fixed:** documented freeze; lever only toward Thrive, with consent; wording aligned; admin commands noted |
| SF3 anchor text; a vanilla sun and moon in the Sift sky | **Fixed:** anchors explode (vanilla); sun and moon parked below the horizon; clocks spin (verified in the 26.3 jar) |
| SF4 how Tide changes reach blocks; flora light vs spawns; spawn overlay flattens biomes | **Fixed:** random ticks for slow changes, 20-tick block-entity checks for bridges; emissive-only flora; per-biome spawn tables |
| SF5 arrival search, two cities → one gate, "broken gate" | **Fixed:** bounded search with a fallback; gates ≥64 blocks apart; explicit links; unbreakable gates |
| SF6 what comes home | **Fixed:** `soul_flow` is 0 outside the Sift; ichor evaporates; companions need fuel |
| SF7 blight readable only by colour | **Fixed:** blight is vanilla sculk |
| SF8 lore: Illagers originating the disease; blight breeding sculkers | **Fixed:** Illagers speed up an old disease; sculkers are native hunters |
| SF9 sound has no cost; colour-only gate keys; how the song is earned | **Fixed:** sound draws hunters in Endure; glyph keys with subtitles; the song is earned by restoring the Meadow |
| SF10 scope | **Fixed:** 1.0 has one boss and one miniboss; the Monarch, Keep, rifts, lever and aurora come later |
| SF11 unmapped vanilla attributes; phantoms | **Fixed:** attributes mapped (rules.md); resting resets the phantom timer |
| SF12 finite camps and tanks | **Fixed:** finite; tanks don't refill; outposts-style spawning |
| Notes (inflated self-scores; loose P3 test; gate-side bases; one-time warden risk; blocking other mods' portals) | Scores lowered (systems §8, entry_path rescoring); P3 test tightened; the others accepted and documented |

**Round 2:** pending (fresh reviewer).
