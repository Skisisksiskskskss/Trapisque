# The dimension's rules (WP-012)

## Diverge — six rule-set identities
| # | Identity | Idea | Verdict |
|---|---|---|---|
| A | **Overworld with another clock** | Everything behaves as at home except that the Tides replace day/night | Comfortable, matches "serene" [RESEARCH §9], but says little |
| B | **Nether-style hostility** | Water boils, beds explode, no sleep, fast fluids | Contradicts "not evil" and "serene"; that is the Nether's identity, not the Sift's |
| C | **End-style stasis** | Fixed time, no weather, beds explode | Contradicts canon: the Tides are a time cycle |
| D | **Sound world** | Vibrations carry farther; noise draws natives, friendly and hostile | Strong for P1, but global sound changes would be invisible to the player |
| E | **Soul world** | XP behaves as souls: it drifts to healthy sculk; ichor drains it; natives are immune to ichor | Strong for P3; must not steal XP the player earned |
| F | **The Tide sets the rules** | Light, sky, fog, music, particles and spawns all keyframed by the Tide; vanilla "night" behaviours follow Endure | Canon ("new rules to learn", "time cycle") and cheap to read |

**Choice: F as the frame, A as the default, and a few targeted rules from D and E.** Anything without a Sift-specific reason behaves like the Overworld, not the Nether or End ("serene", not hostile). This replaces the WP-012 exit-ramp default of "Nether/End precedent", which the press pass showed is the wrong precedent for a serene dimension.

## Rules table (implementation routes verified in VANILLA_ANALOGS W1/W4/W5)
Route key: **DT** = dimension-type field · **ATTR** = dimension/biome environment attribute · **TL** = keyframed on the `thesift:tides` timeline (clock `thesift:tides`) · **CODE** = our code · **VAN** = vanilla already does it.

| Topic | Rule | Tide-dependent? | Route |
|---|---|---|---|
| Day/night | None. The Tide cycle replaces it. `/time` in the Sift acts on the Tide clock (`/time set thesift:endure` jumps to Endure) | — | DT `default_clock`, `timelines: #thesift:in_sift`; TL time markers |
| Sky light | Thrive 15, Flow ramps, Endure ≈4 (night-like) | yes | TL `gameplay/sky_light_level` |
| Hostile spawning | Follows light (standard 0–7): monsters appear on the surface only when Endure darkens it, which is the canon "stronger mobs" moment | yes (via light) | DT `monster_spawn_light_level`; VAN |
| Spawn tables | Thrive: native passives abundant. Flow: mixed. Endure: hostile sifters, sculkers, stronger variants | yes | TL `gameplay/natural_mob_spawns` (overlay); CODE for "stronger" buffs |
| Sky & fog colour | Thrive: teal sky, pale fog. Flow: peach-gold. Endure: deep indigo with stars | yes | TL `visual/sky_color`, `visual/fog_color`, `visual/star_brightness`, `visual/cloud_color` |
| Aurora | Blocky teal/pink aurora bands (canon look) | brighter in Endure | CODE (client sky rendering) — **Should**; feasibility in Phase 3 |
| Ambient particles | Thrive: drifting pollen-like motes (trills). Endure: glowing soul motes | yes | TL `visual/ambient_particles` |
| Music | Each area has a Thrive / Flow / Endure version (canon OST pattern) | yes | TL/biome ATTR `audio/background_music` |
| Weather | None: no rain or snow. The Tide is the weather | — | biome `has_precipitation: false` |
| Beds | Can set spawn; **can't sleep** ("You can't sleep here: the Sift never goes quiet"); no explosion | — | ATTR `gameplay/bed_rule {can_set_spawn: always, can_sleep: never}`; straw bed mirrors, no spawn |
| Respawn anchors | Don't work | — | ATTR `gameplay/respawn_anchor_works: false` (VAN default) |
| Clocks | **Show the Tide**: the needle follows the Tide cycle (day face = Thrive, night face = Endure) | yes | TL `visual/sun_angle` (the clock reads it); VAN |
| Compasses | Spin, as in any non-spawn dimension; lodestone and recovery compasses work | — | VAN |
| Maps | Work normally (no ceiling) | — | VAN |
| Nether portals | Cannot be lit (vanilla only lights them in the Overworld/Nether) | — | VAN (`BaseFireBlock.inPortalDimension`) |
| Coordinates | 1:1 with the Overworld (no travel shortcut) | — | DT `coordinate_scale: 1` |
| Fall damage, water | Normal | — | VAN |
| **Ichor** | A new liquid: sets non-natives alight with soul fire and drains their XP ("souls"). Sift natives are immune and some thrive in it (blubs bathe). Canon hazard | behaviour may vary by Tide (systems) | CODE (fluid) + tag `#thesift:ichor_adapted` |
| Raids & patrols | No raids or pillager patrols; the Illager presence is the occupation | — | ATTR `gameplay/can_start_raid: false`, `gameplay/can_pillager_patrol_spawn: false` |
| Sculk shriekers | Placed in the Sift, they never summon wardens (no wardens live here; Singers soothe them) | — | CODE (targeted) |
| Night-bound vanilla behaviour | Follows Endure: bees stay in hives, eyeblossoms open | yes | TL `gameplay/bees_stay_in_hive`, `gameplay/eyeblossom_open` |
| Monsters burning | Never (no sun burns in the Sift) | — | ATTR `gameplay/monsters_burn: false` |
| Ambient light | Slightly raised (≈0.05) so Endure is dark but readable; glowing flora supplies most light | — | DT `ambient_light` |

## Accessibility checks (P1/§7.6)
- Every Tide change is shown by sky, light, particles **and** music, never by sound alone.
- Ichor is readable without colour: it steams soul-fire particles and has a distinct surface animation.
