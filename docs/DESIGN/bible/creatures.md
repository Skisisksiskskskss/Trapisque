# Content bible II: creatures (WP-021)

Part of `../01_CONTENT_BIBLE.md`. Source: `../../RESEARCH_BESTIARY.md`; the frozen vision `../00_VISION.md`. Decisions: D-016, D-017.

**Legend.**
- **Verdict:** **Adapt** (redesigned for first-person sandbox, keeping identity and name) · **Merge** (folded into another design) · **Defer** (a later version, named; its tier is Won't for 1.0) · **Cut** (never, with a reason).
- **Tier:** Core / Should / Could / Won't. **MS** = milestone.
- **Links:** T Tides · S souls · K sculk/blight · N sound · I Illagers · Cr creatures · W world (blocks, flora).
- **Translation rule (mission §3.2 observation 5):** keep each creature's identity, fantasy and name. Redesign its behaviour for a first-person camera: telegraphs you can see, counters you can learn, no isometric barrages.

## 1. Verdicts: every canon entry
| Canon entry | Verdict | Tier | MS | Reason |
|---|---|---|---|---|
| **Blub** (+ variant captions Grim Blub, Blubberfly) | **Adapt**. Variants merge into the Blub as skins; the Meadow skin ships first | **Core** (M1's finished mob) | M1 | Mascot and vanilla-teaser creature (V, D-002). Simple and loved, which makes it the ideal vertical-slice mob |
| **Echo Golem** | **Adapt** | **Core** | M4 | Canon ties it to soul blocks, the portal and the camps; it carries the occupation story (I5′) |
| **Slabber** | **Adapt** | **Should** | M5 | Canon ambient turtle-like grazer. Its niche: it licks blight, slowly curing small patches (K) |
| **Trill** | **Adapt as particles** (canon: "They are particle effects") | **Core** (part of the Tide timeline; no entity; D-016 gives the reason for moving it up from the vision's Could) | M1 | Canon says it is a screen effect; the vanilla analog is ambient particles |
| **Tuner** | **Defer** | Won't (1.0) → 1.x | — | A cute carriable golem, but no sandbox role yet. Candidate: a carried "key" for musical gates |
| **Wobble** (+ **Soul Blocker**, merged by the deletion tag) | **Defer** | Won't (1.0) → 1.x | — | Quest-only colour-changing critter; fine as a hide-and-seek ambient mob later |
| **Prickle** | **Cut** | Won't | — | A talisman-summoned companion (a Dungeons-only item mechanic); conjecture name |
| **Antenna Sifter**, **Nuzzle** | **Cut** | Won't | — | Name only or conjecture name; no known behaviour to adapt (revisit if canon reveals one) |
| **Sift Sheep** | **Defer** | Won't (1.0) → 1.x | — | "sheep-like": a candidate Sift farm animal |
| "Bird-like creatures", "goat things", the Sniffer claim | **Cut** | Won't | — | Unidentified or likely misidentified (RESEARCH §7 #14) |
| **Singer** | **Adapt** | **Core** | M4 | The gift of song's source and the Meadow's soul (canon, official look S-I8) |
| **Bubbles** (novel) | **Merge** into the Blub (a blub name-tagged "Bubbles" gets a special squeak) | Could | — | Novel character; vanilla-style easter egg (like "jeb_" sheep) |
| Harlow, Iliana, Fergus, Murph, Lucky (novel) | **Cut** | Won't | — | Named novel characters would need dialogue. Vanilla restraint: no NPC stories |
| **High Council** (Grand Illusioner, Prime Enchanter, Supreme Evoker) | **Defer** | Won't (1.0) → post-1.0 with the Illager Keep | — | The Keep is post-1.0 (D-009) |
| **Bloombud** | **Adapt** | **Core** | M2 | The Meadow's common melee sifter (canon: "spawn in large groups throughout the Singer's Meadow"; we keep the groups) |
| **Nester** | **Adapt** | **Core** | M2 | The Meadow's listening hunter (the hearing rule, D-011) |
| **Seedling** | **Merge** into the Harmonizer (summons only) | Should | M6 | Canon: "the Harmonizer summons them" |
| **Pollinator** (+ **Blubber**'s slowing goo, merged) | **Adapt** | **Should** | M5 | The ranged sifter; the goo slows, one readable status for both |
| **Sprout** | **Adapt** | **Should** | M5 | The support buffer ("beams a buff to allies"), countered by hitting it |
| **Sentinel** | **Defer** | Won't (1.0) → 1.1 | — | A homing-barrage turret; too close to the shulker without a new twist |
| **Shroomer** | **Defer** | Won't (1.0) → 1.x | — | A stationary turret; a candidate cave hazard for the Sift Hollows |
| **Forager** | **Cut** | Won't | — | "explodes after being killed": a creeper overlap with no Sift identity |
| Fusefly, Hurler, Roamroot | **Cut** | Won't | — | Names only |
| **Stalker**, **Scavenger**, **Hunter** (sculkers) | **Defer** | Won't (1.0) → **1.1** | — | The Carapace is 1.1 (D-009); there they become that area's listening hunters |
| **Sculk Cube** | **Adapt** as the Monstrosity's summon (a rolling blight cube) | **Core** (with the boss) | M6 | Canon: summoned by the Sculk Monstrosity |
| **Sculk Stunner** | **Cut** | Won't | — | The page is tagged for deletion (unreliable) |
| **Sculk Monstrosity** | **Adapt** | **Core** (the 1.0 boss) | M6 | D-009 |
| **Harmonizer** | **Adapt** | **Should** (miniboss) | M6 | D-009. It is a sifter, with a screech shockwave and buff beams |
| **Monarch** | **Defer** | Won't (1.0) → **1.1** | — | With the Carapace |
| **Dartback** | **Defer** | Won't (1.0) → 1.1 | — | An ichor-arena miniboss; canon places it with "Lost Harmonies: Find the stolen soul blocks", which our camps' stolen soul blocks now carry |
| Soul-corrupted status (canon: mobs "glow, emit soul particles, and are far more resilient") | **Merge** into the **enduring** variants for common hostiles. Soul-corrupted boss **re-fights** are **cut**: vanilla bosses are one-off encounters | Core (as the variant rule) | M2 | Our Endure variant rule, with non-colour markers |
| **Monstrous Opus** | **Cut** | Won't | — | Dungeons II's final boss, illager-associated; its Sift tie is unknown |
| **Humbler Husk** | **Defer** | Won't (1.0) → 1.1 | — | A Carapace fossil structure |
| **Twisted Warden** | **Merge** into the vanilla warden | Won't (merged: the vanilla warden plays the role) | — | The vanilla warden already guards the frame's city. A "twisted" warden would change vanilla Ancient Cities (hard rule 9.4) |
| **Pillager**, **Vindicator** (illagers in the Sift) | **Adapt** with vanilla types: pillagers (camp respawns), vindicators (a first garrison only) | Core | M4 | D-012/D-013: camps respawn pillagers only |
| **Enchanter**, **Royal Guard** | **Cut** | Won't | — | Dungeons-only illager types; vanilla restraint (no new illager types unless a role is missing) |
| **Ravager** (in camps) | **Adapt** as a rare camp guard | Could | — | A vanilla type; only if camps feel thin |

## 2. The 1.0 roster (Core and Should)
| Creature | Role (niche) | Tide behaviour | Links | Vanilla analog | Tier / MS |
|---|---|---|---|---|---|
| **Blub** | Ambient critter and **pet**. It hops (a vanilla-style clip), squeaks, bathes in ichor (immune to its burn and drain) and gathers to music. Blubs **stack into teetering towers** that topple (our reading of Kotaku's "blue bunnies"). A player befriends one by **playing music for it** by hand (a note block or a goat horn, whose game event names the player). Each note befriends at most one blub: the nearest one watching the player. It shows hearts and a happy squeak. Like the allay, it costs nothing. A befriended blub follows, crosses the membrane with its player, and comes home. It needs no fuel (D-016). **M2 addition:** tidewrack treats for breeding and healing | Thrive: roams, stacks to music. Flow: follows the basin waterline as it moves. Endure: shelters under songwood leaves, curled up | T N S Cr W | rabbit (ambient), allay (music), axolotl (liquid-adapted) | **Core**, **M1** (the fully finished mob) |
| **Nester** | The **listening hunter**: surfaces in Endure, hears vibrations out to 16 blocks, gallops and lunges, circles on cooldown, and burrows away at falling Flow. It avoids lumen light | Endure only (hearing rule); burrows at dawn | T N Cr I (it attacks illagers too) | warden (hearing), wolf or spider (gallop and lunge) | **Core**, M2 |
| **Bloombud** | A melee sifter that mimics a closed flower bud in the dark, in groups of 3–5. Its petals open (the telegraph) before it lunges | Spawns in darkness (Endure, caves); burrows at falling Flow on the surface | T W Cr | vindicator (canon look) plus a creeping ambush | **Core**, M2 |
| **Echo Golem** | Caged in Illager camps; freed ones become working companions. It dances to music, carries a soul block (fuel) and, while it has one, **slowly heals blight** and tends bloom hearts | Thrive: works (heals); Endure: gathers at gates and camps it has freed | I K S N | iron golem (protector), allay (carrier) | **Core**, M4 |
| **Singer** | A rare, tall, passive native, one per Singer's grove. It speaks only in song and grants the **gift of song** (items.md §1.1). It can be hurt; hurt, it flees and falls silent for a full Tide cycle. It **can't die**: at zero health it fades into its grove (with soul particles and the subtitle "Singer fades") and returns to the grove heart at the next Thrive. It drops nothing, so no grove is ever softlocked and nothing can be farmed | Sings in Thrive and Flow; silent in Endure | N S I | wandering trader (a rare visitor with a purpose), allay | **Core**, M4 |
| **Pillager / Vindicator** (vanilla) | Camp garrison and respawns (pillagers only); they patrol camp grounds in Thrive and Flow and run the rigs that drain souls | Patrol in Thrive and Flow; hide in camp in Endure, where Nesters hunt them | I K S Cr | pillager outpost | **Core** (vanilla types), M4 |
| **Pollinator** | A ranged sifter that keeps its distance and lobs goo globs that burst after 3 s. The goo **slows** (readable yellow puddles with a drip particle) | Endure and caves | T W Cr | witch (ranged), stray (slowing) | **Should**, M5 |
| **Sprout** | A support sifter that beams a buff to an ally (it prefers Pollinators). It can't move while beaming, and a hit cancels the beam | Endure and caves | T Cr | evoker (support), end crystal (beam) | **Should**, M5 |
| **Slabber** | A large ambient grazer that licks blight, slowly clearing small patches | Grazes in Thrive, rests in Endure | K W Cr | sniffer (a big gentle grazer) | **Should**, M5 |
| **Sculk Cube** | The Monstrosity's summon: a rolling blight cube that bursts into blight veins | Boss fight only | K Cr W | slime (rolling cube) | **Core**, M6 |
| **Sculk Monstrosity** | The **boss**, heart of the blight (our design), behind a musical gate. It fights with heavy swings, a soul-flame charge, summoned Sculk Cubes, and **catalysis**: blight hearts erupt and web the arena. Beating it cures the land around its arena | Arena only; stronger in Endure | K S N I | warden (weight), wither (boss bar, arena) | **Core**, M6 |
| **Harmonizer** | The **miniboss**: a massive sprout with a screech shockwave (telegraphed), summoned Seedlings, buff beams to allies (cut by killing the ally) and a tentacle grab. It guards the Monstrosity hollow's antechamber. It drops soul blocks and a guaranteed Muffled Steps trait template | Arena only | N T Cr | elder guardian (miniboss), evoker | **Should**, M6 |

### 2.1 Could (only if the budget allows)
| Entry | What | Tier | MS |
|---|---|---|---|
| **Blub towers as platforms** | Players can stand on a blub stack to reach high blooms (vision N2′'s platform idea) | Could | — |

**Enduring variants** (merged from canon soul corruption) apply to Nester, Bloombud, Pollinator and Sprout in Endure: more health and damage, readable by a **larger crest or spikes and trailing soul particles** as well as a glow (not colour alone). They are tuned in BALANCE.md.

## 3. Self-critique
**WP-021, pass 1.**
- **Every canon entry has a verdict:** every row of the bestiary's tables, aliases and invaders included (over 50 names; checked row by row).
- **Role overlap check:**
  - Bloombud (ambush melee), Nester (hearing hunter) and Pollinator (ranged area denial) have distinct niches.
  - Sprout is support only.
  - None copies a vanilla mob's niche exactly: the Nester's listen-and-gallop differs from the warden's single-location guard.
- **The Blub as the M1 mob** fits the mission's "one mob completely finished" bar without needing combat systems first. Its AI exercises the Tide, sound and ichor systems M1 must prove: music attraction, stacking, waterline following, ichor bathing and Tide shelter.
- **Risk:** blub stacking needs entity-on-entity riding with a topple. That is feasible with vanilla passenger mechanics (`startRiding`), but it is spiked first (WP-034).

**WP-023, pass 2.** The Blub's ichor and waterline behaviour depended on later content. D-016 moves ichor and one basin type into M1, so the M1 Blub is complete. Only its tidewrack treats wait for M2.

**WP-024, round-1 fixes (D-016).**
- The Blub is a pet, so it needs no soul-block fuel. Fuel is only for companions that work.
- Befriending the Blub uses music, so it needs nothing beyond M1.
- Deferred entries are all tiered "Won't (1.0) → version".
- The Twisted Warden, Enchanter and Royal Guard have their own tiers.
- Boss re-fights are cut.
- The Singer's silence lasts a Tide cycle; the Sift has no days.
- Links were fixed: every Core row has ≥2.

**WP-024, round-2 fixes (D-017).**
- Befriending has a limit (one blub per note, the nearest watching one) and a tell. The allay is the precedent for no cost.
- A befriended blub crosses the membrane with its player.
- The Singer can't die.
- "Blub towers as platforms" has its Could row.
