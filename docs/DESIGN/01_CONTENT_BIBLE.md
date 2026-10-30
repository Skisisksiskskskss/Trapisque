# The Sift — Content bible and roadmap

**Status: FROZEN** (2026-09-30, Gate B self-review, D-014). It passed the round-3 fresh review. Later changes need a decision record.

Parts:
- `bible/world.md`: areas, biomes, spawn tables, terrain, blocks, art rules, flora, hazards, structures.
- `bible/creatures.md`: every canon mob's verdict, and the roster.
- `bible/items.md`: items, materials, the gift-of-song quest, gear, tools and companions, food, advancements, audio hooks, mechanics.

Every Core and Should row carries a milestone (MS). `tools/docs/check_bible.py` checks this.

Frozen vision: `00_VISION.md`. Decisions made here: D-016 (round 1) and D-017 (round 2). *Unofficial fan project, not affiliated with or endorsed by Mojang Studios or Microsoft.*

## 1. Tier summary (1.0 = Singer's Meadow, D-009)
| Area | Core (in 1.0) | Should | Could | Won't / later |
|---|---|---|---|---|
| **Biomes** | Singer's Meadow, Sift Hollows, Hymnstone Rise | Lullaby Hills | Radiant Ravines | Carapace, Echo Den, Humbler Huskland (1.1); soundtrack-only names |
| **Block families** | hymnstone, healthy sculk, songwood, blight (with blight hearts), bloom heart, soul block, tide flats, gate + membrane, lumen, camp machines (rig, tank, cage), chorus stone | musical gate | — | new ores; songwood boats |
| **Flora and hazards** | ichor, tidewrack, Endure bloom | glowcap, chime bell flower, meadow flowers | burst pod | — |
| **Structures** | Sift-side gate, frame logic, Illager camp, Singer's grove, Monstrosity hollow | choir circle | Sift ruins | Illager Keep (post-1.0) |
| **Creatures** | Blub, Nester, Bloombud, Echo Golem, Singer, pillager/vindicator (vanilla), Sculk Cube, Sculk Monstrosity (boss), enduring variants, Trills (particles) | Pollinator, Sprout, Slabber, Harmonizer (miniboss) + Seedlings | Ravager in camps, "Bubbles", blub towers as platforms | Tuner, Wobble, Sift Sheep, Shroomer (1.x); Sentinel, Dartback, sculkers, Monarch (1.1); High Council (post-1.0); cut entries in creatures.md §1 |
| **Items and materials** | ichor bucket, tidewrack frond, Endure petal, lumen lantern, soul block, Singer's horn, spawn eggs | Tide shell, trait templates, lullberries | music disc, raw tidewrack as food | — |
| **Tools, armour, companions** | the Singer's horn (the one new tool); companions Blub (pet) and Echo Golem (worker) | — | — | new tiers (vision §6); Sift Sickles and Warding Chimes (1.1, humbler husk) |
| **Advancements** | 11 | 3 | — | — |
| **Mechanics** | Tides and scope gate, ichor, basins, entry, gate, weather mixin, beds, music reactions (client-side, also at home), hearing and retreat, enduring variants, lumen repel, bloom hearts, blight, camps, gift of song (quest) | gear traits, musical gates | — | Tide lever (post-1.0) |

## 2. Dependency graph (systems before the content that needs them)
```
Architecture (Phase 3: registration, datagen, tests, CI; spikes: weather mixin, wade-through ichor, basins, blub stacking)
  └─► Dimension skeleton (type, noise, biome source, weather mixin, attributes sift_life/soul_flow/tide)
        ├─► Tide core (clock, timeline: light, sky, stars, Trills; beds) ───────────────────┐
        ├─► Block set I (hymnstone, healthy sculk, songwood base, tide sand, vent, gate)  │
        │     └─► Singer's Meadow terrain (material rules, trees, grass, ichor pools)      │
        ├─► Ichor fluid ──► Tide basins (vent controller, fill/drain by Tide) ◄──────────────┤
        └─► Entry (frame, offering, awake, listeners, membrane) ──► Gate (arrival, links, sanctuary)
  Blub (design, art, anim, audio, AI) ◄── listeners + Tide core + basins + ichor + songwood
  ── M1 (vertical slice) ──
  Hearing rule + retreat ──► Nester, Bloombud, enduring variants; Sift Hollows; spawn tables
  Basins ──► tide marks, tidewrack (Thrive), Endure bloom (Endure) ──► lumen (repels hunters)
  ── M2 ──
  Bloom patches (worldgen) ──► bloom hearts ──► soul blocks, growth, healthy-sculk variants
  Hymnstone Rise (lullvine curtains) ◄── songwood full set + lullvine; hymnstone full family
  ── M3 ──
  Blight family ──► rigs, tanks, cages ──► Illager camps (stolen soul blocks) ──► Echo Golem (freed, fuelled by soul blocks)
  Soul blocks + camps ──► Singer's grove, chorus stones ──► Singer ──► gift of song (per-player charges); blight seams in the Hollows
  ── M4 ──
  Camps' templates + tidewrack/petals/soul blocks ──► gear traits; Pollinator, Sprout, Slabber; Lullaby Hills + choir circles (need golems); Tide shell; lullberries; Tide music
  ── M5 ──
  Gift of song ──► musical gates ──► Monstrosity hollow (blight hearts) ──► Sculk Monstrosity + Sculk Cubes; Harmonizer + Seedlings
  ── M6 ──
  Could pool (only if the budget allows) ──► Phase 6 polish ──► Phase 7 hardening ──► Phase 8 release (1.0)
```

## 3. Milestones
Every milestone ends **shippable**: it builds, boots, runs datagen with no diff, and passes its tests. Each one also gets an integration pass, a balance review, a performance check, an updated PLAYTEST.md and a tag.

Work packages: Phase 3 = WP-030..034, M1 = WP-040..053 (PLAN.md). Later milestones are broken into WPs when they start.

| Milestone | Theme | Contents | Tag |
|---|---|---|---|
| **M1 — vertical slice** (Phase 4) | Get in, watch the tide, get out | Dimension + Singer's Meadow terrain; block set I with final art (with the songwood sapling); music reactions; **ichor and one kind of tide basin** (the literal tide, D-016); the Tide core (clock, light, sky, stars, Trills, beds, weather mixin); Meadow ambience; entry and return (frame, offering, music, membrane, gate); **the Blub finished** (design → art → animation → audio → AI → tests); advancements The Sift (root) / An Offering / Where Souls Drift / The Tide Turns | `v0.1.0-alpha` |
| **M2 — the hunt** | Endure means danger | Hearing rule and retreat; Nester, Bloombud, enduring variants; Sift Hollows with glowcap pools; spawn tables; tide marks, tidewrack, Endure bloom; lumen; chime bell flower; the Blub's tidewrack treats; advancements Stacked, Low Tide, Heard You, Quiet Waters | `v0.2.0-alpha` |
| **M3 — souls** | Grow the land | Bloom patches and bloom hearts, soul blocks, growth; healthy-sculk variants; Hymnstone Rise with spires; the full hymnstone and songwood families (with lullvine); advancement Condensed | `v0.3.0-alpha` |
| **M4 — the occupation** | Something to fight for | Blight family (with the Hollows' seams); rigs, tanks, cages, camps; Echo Golem; the Singer, its grove, the chorus stones and the gift of song; advancements Broken Chains, Rig Wrecker, The Singer's Gift | `v0.4.0-alpha` |
| **M5 — the Meadow's life** | Should content | Pollinator, Sprout, Slabber; Lullaby Hills and choir circles; gear traits; Tide shell; lullberries; meadow flowers; Tide music; advancement Mended Ground | `v0.5.0-beta` |
| **M6 — the heart of the blight** | The endgame | Musical gates; Monstrosity hollow with blight hearts; Sculk Monstrosity and Sculk Cubes; Harmonizer and Seedlings; advancement Heart of the Blight | `v0.6.0-beta` |
| **Could pool** | Only if the budget allows | Radiant Ravines, burst pod, Sift ruins, Ravager, music disc, "Bubbles", raw tidewrack, blub towers as platforms. Anything left over goes to post-1.0 (IDEAS.md) | — |
| **1.0** (Phases 6–8) | Polish, harden, release | Walkthrough, advancement-tree review, lang proofreading, sound mix, particle pass, lineup sheet; profiling, multiplayer, edge-case matrix; README, changelog, page copy | `v1.0.0` |

## 4. Critique log (WP-024)
**Round 1 (fresh reviewer): FAIL.** 3 must-fix, 11 should-fix, 8 notes.
- **Scores:** Sift-faithful 4 · Vanilla-native 4 · Readable 3 · Meaningful 3 · Distinct 3 · Connected 4 · Feasible 3.
- **Must-fix, all fixed (D-016):**
  - **MF1:** the gift-of-song quest is now specified (items.md §1.1).
  - **MF2:** every Core and Should row has a milestone, with a check script.
  - **MF3:** the Blub is complete in M1 (ichor and basins moved into M1), befriended by music, and a pet with no fuel.
- **Should-fix:**
  - **SF1–SF3:** WP dependencies, DoD checks and deliverables fixed in PLAN.md.
  - **SF4:** the literal tide moved to M1.
  - **SF5:** tools, armour and companions made explicit.
  - **SF6:** new rows for the cage, the chorus stone, the blight heart and the glowcap; the "red-sculk hill" corrected.
  - **SF7:** songwood got its flute holes; lumen now repels hunters.
  - **SF8:** tiers and counts made consistent.
  - **SF9:** links fixed.
  - **SF10:** art rules written (world.md §3.1).
  - **SF11:** spawn tables added.
- **Notes:**
  - **N1:** boss re-fights cut.
  - **N2:** the Singer's silence lasts a Tide cycle.
  - **N3:** the horn plays as an instrument anywhere; its Sift effects need the Sift.
  - **N4:** the graph was corrected.
  - **N5:** the naming legend was reworded.
  - **N6:** the horn's recharge ratio (D-016).
  - **N7:** M2 was split, giving M1–M6.
  - **N8:** the Tide shell's client property was noted.

**Round 2 (a new fresh reviewer): FAIL.** 1 must-fix, 11 should-fix, 4 notes.
- **Scores:** F4 V4 R4 M4 D4 C4 **Fe3**.
- **Must-fix, fixed (D-017):** the bloom heart now has a source in M3, the bloom-patch feature (world.md §3).
- **Should-fix:**
  - **Milestone ordering:** the songwood set moved to M3, and the blight seams are marked as an M4 addition.
  - **M1 WP dependencies and inputs:** fixed in PLAN.md, and the ichor pools moved into WP-045.
  - **Basin and Tide performance DoDs:** they now use Flow-boundary levels and p95/max MSPT, with the budgets in system_tides.md.
  - **Music reactions:** they now have a mechanism, a client listener (world.md §3.2).
  - **The horn:** its rules are in items.md §1.2: per-player charges, calm defined as a lull, and gate keys.
  - **Singer edge cases:** it can't die, it reacts to a held soul block, and late arrivals get no horn.
  - **Songwood sapling:** added.
  - **Vision changes:** recorded in D-017 (the blight colour is back to the vision's; the gate mound; home reactions).
  - **Fallbacks:** one per spike.
  - **check_bible.py:** hardened.
  - **M1 quality bars:** added (BALANCE, Blub previews, a Flow membrane shot, ichor numbers).
- **Notes:**
  - M4 is lighter now.
  - Befriending is limited and has a tell (the allay precedent).
  - The advancement root is now "The Sift".
  - The PLAN and decision housekeeping is done.

**Round 3 (a new fresh reviewer, the last allowed): PASS.** No must-fix.
- **Scores:** F4 V4 R4 M4 D4 C4 Fe4.
- **Fixed after the round, under the critique cap:**
  - **F1:** jukebox reactions stay live while the record plays.
  - **F2:** the headless client needs a null audio backend, or a client test feeds the buffer directly.
  - **F3:** the grove heart is an unbreakable anchor, so the Singer's return point can't be taken.
  - **F4:** the Harmonizer guards the hollow's antechamber and drops a trait template.
  - **F5:** the M1 row names the root advancement, and the Could pool lists blub towers.
  - **F6:** no more "sway" wording; music shows as petal particles.
  - **F7:** WP-047 and WP-051 gained the missing inputs.
  - **F8:** the lull covers every hunter within 12 blocks.
  - **F9:** charges are kept on death, and a song outside the Sift spends no charge.
  - **F10:** the ichor fog goes through an access widener.
  - **F11:** Trill particle art was added to WP-041.
  - **F12:** the checker now reads indented tables and flags stray tier words.
  - **F13:** the Sift-only growth rule covers all flora.
  - **F14:** the measuring DoDs have pass thresholds.
  - **F15:** the song must be played by hand.
- **Not re-reviewed:** the post-round changes are small and local, which the §5.5 cap allows.
