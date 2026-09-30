# The Sift — Content bible and roadmap

**Status:** DRAFT (WP-020..023) → critique (WP-024) → FROZEN at Gate B (a self-review, D-014).

Parts:
- `bible/world.md`: areas, biomes, terrain, blocks, flora, hazards, structures.
- `bible/creatures.md`: every canon mob's verdict, and the roster.
- `bible/items.md`: items, gear traits, food, advancements, audio hooks, mechanics.

Frozen vision: `00_VISION.md`. *Unofficial fan project, not affiliated with or endorsed by Mojang Studios or Microsoft.*

## 1. Tier summary (1.0 = Singer's Meadow, D-009)
| Area | Core (in 1.0) | Should | Could | Won't / later |
|---|---|---|---|---|
| **Biomes** | Singer's Meadow, Hymnstone Rise, Sift Hollows | Lullaby Hills | Radiant Ravines | Carapace, Echo Den, Humbler Huskland (1.1); soundtrack-only names |
| **Block families** | hymnstone, healthy sculk, songwood, blight, bloom heart, soul block, tide flats, gate + membrane, lumen, rigs and tanks | musical gate | — | new ores; songwood boats |
| **Flora and hazards** | ichor, tidewrack, Endure bloom | chime bell flower, meadow flowers | burst pod | — |
| **Structures** | Sift-side gate, frame logic, Illager camp, Singer's grove, Monstrosity hollow | choir circle | Sift ruins | Illager Keep (post-1.0) |
| **Creatures** | Blub, Echo Golem, Singer, Nester, Bloombud, Sculk Cube, Sculk Monstrosity (boss), pillager/vindicator (vanilla), enduring variants, Trills (particles) | Pollinator, Sprout, Slabber, Harmonizer (miniboss) + Seedlings | Tuner, Wobble, Sift Sheep, Sentinel, Shroomer, Dartback, Ravager | sculkers and the Monarch (1.1); High Council (post-1.0); cut entries in creatures.md §1 |
| **Items** | soul block, tidewrack frond, Endure petal, ichor bucket, Singer's horn, lumen lantern | Tide shell, trait templates, lullberries | music disc, "Bubbles" | — |
| **Advancements** | 9 Core (3 in M1) | 3 | — | — |
| **Mechanics** | Tides and scope gate, basins, hearing and retreat, entry, gate, weather mixin, beds, ichor, bloom hearts, blight, camps, gift of song, enduring variants | musical gates, gear traits | — | Tide lever (post-1.0) |

## 2. Dependency graph (systems before the content that needs them)
```
Architecture (Phase 3: registration, datagen, tests, CI; spikes: weather mixin, wade-through ichor, basins, blub stacking)
  └─► Dimension skeleton (type, noise, biome source, weather mixin, attributes sift_life/soul_flow/tide)
        ├─► Tide core (clock, timeline: light, sky, stars, particles; beds) ─────────────┐
        ├─► Block set I (hymnstone, healthy sculk, songwood base, gatestone, membrane)   │
        │     └─► Singer's Meadow terrain (material rules, features: trees, grass)       │
        └─► Entry (frame detection, offering, awake, listeners, membrane) ──► Gate (arrival, links, sanctuary)
                                                                                         │
  Blub (design, art, anim, audio, AI) ◄── music listeners + Tide core + songwood ◄────────┘
  ── M1 ends here (vertical slice) ──
  Ichor fluid ──► Tide basins (+ tidewrack, tide flats) ──► Endure bloom, lumen
  Hearing rule + retreat ──► Nester, Bloombud, enduring variants
  Bloom hearts ──► soul blocks ──► (M3) echo golems, gates, traits
  Hymnstone Rise + Sift Hollows biomes
  ── M2 ──
  Blight family + rigs + tanks ──► Illager camps ──► caged Echo Golems (freeing, healing)
  Singer + Singer's grove ──► gift of song (needs soul blocks, camps)
  Songwood full set
  ── M3 ──
  Should content: Pollinator, Sprout, Slabber, Lullaby Hills, gear traits, Tide shell, lullberries, blub towers, choir circle
  ── M4 ──
  Musical gates ──► Monstrosity hollow ──► Sculk Monstrosity (+ Sculk Cubes); Harmonizer; music disc
  ── M5 ──
  Phase 6 polish ──► Phase 7 hardening ──► Phase 8 release (1.0)
```

## 3. Milestones
Work packages: Phase 3 = WP-030..034, M1 = WP-040..051 (PLAN.md). Later milestones are broken into WPs when they start.

Every milestone ends **shippable**: it builds, boots, runs datagen with no diff, and passes its tests. Each one also gets an integration pass, a balance review, a performance check, an updated PLAYTEST.md and a tag.

| Milestone | Theme | Contents | Tag |
|---|---|---|---|
| **M1 — vertical slice** (Phase 4) | Get in, look around, get out | Dimension + Singer's Meadow terrain; block set I with final art; entry and return (frame, offering, music, membrane, gate); the Tide cycle in core form (clock, light, sky, stars, particles, beds, weather mixin); Meadow ambience; **the Blub finished** with M1 content only (design → art → animation → audio → AI → tests); advancements Where Souls Drift / An Offering / The Tide Turns | `v0.1.0-alpha` |
| **M2 — the tide and the hunt** | Endure means something | Ichor; tide basins with tidewrack and tide marks; the Blub's ichor bathing and tidewrack treats; Endure blooms; lumen; the hearing rule and retreat; Nester, Bloombud, enduring variants; bloom hearts and soul blocks; Hymnstone Rise and Sift Hollows | `v0.2.0-alpha` |
| **M3 — the occupation** | Something to fight for | Blight family; rigs, tanks, camps; Echo Golem (caged → freed → healer); the Singer, Singer's grove and the gift of song; the songwood full set | `v0.3.0-alpha` |
| **M4 — the Meadow's life** | Should content | Pollinator, Sprout, Slabber; Lullaby Hills and choir circles; gear traits; Tide shell; lullberries; blub towers | `v0.4.0-beta` |
| **M5 — the heart of the blight** | The endgame | Musical gates; Monstrosity hollow; Sculk Monstrosity and Sculk Cubes; Harmonizer and Seedlings; music disc | `v0.5.0-beta` |
| **1.0** (Phases 6–8) | Polish, harden, release | Walkthrough, advancement-tree review, lang proofreading, sound mix, particle pass, lineup sheet; profiling, multiplayer, edge-case matrix; README, changelog, page copy | `v1.0.0` |

## 4. Critique log (WP-024)
Pending.
