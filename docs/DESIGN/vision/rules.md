# The dimension's rules (WP-012; revised after WP-014 critique rounds 1–3)

## Diverge: six rule-set identities
| # | Identity | Idea | Verdict |
|---|---|---|---|
| A | **Overworld with another clock** | Everything behaves as at home, except that the Tides replace day and night | Comfortable, matches "serene" [RESEARCH §9], but says little |
| B | **Nether-style hostility** | Water boils, beds explode, no sleep, fast fluids | Contradicts "not evil" and "serene"; that identity belongs to the Nether, not the Sift |
| C | **End-style stasis** | Fixed time, no weather, beds explode | Contradicts canon: the Tides are a time cycle |
| D | **Sound world** | Vibrations carry farther; noise draws natives, friendly and hostile | Strong for P1, but global sound changes would be invisible to the player |
| E | **Soul world** | XP behaves as souls; ichor drains it; natives are immune to ichor | Strong for P3. Only blocks that visibly drink souls take XP, never the floor (systems.md §2) |
| F | **The Tide sets the rules** | Light, sky, fog, music, particles and growth follow the Tide; each Tide has one signature rule | Canon ("new rules to learn", "time cycle") and cheap to read |

**Choice:** F as the frame, A as the default, plus a few targeted rules from D and E. Anything without a Sift-specific reason behaves like the Overworld, not the Nether or End ("serene", not hostile). Where vanilla treats every non-Overworld dimension alike (clocks, phantoms, patrols), the Sift follows the Nether and End.

## Rules table
Routes are verified against the 26.3 source (VANILLA_ANALOGS W1/W4/W5 and the critique-round checks noted below).

Route key:
- **DT**: dimension-type field.
- **ATTR**: dimension or biome environment attribute.
- **TL**: keyframed on the `thesift:tides` timeline.
- **CODE**: our code.
- **VAN**: vanilla already does it.

| Topic | Rule | Tide-dependent? | Route |
|---|---|---|---|
| Day/night | None; the Tide cycle (30 000 ticks) replaces it. `/time set thesift:endure` jumps to Endure; `/time set day` doesn't apply in the Sift | — | DT `default_clock: thesift:tides`, `timelines`; TL markers |
| Sun & moon | **None visible.** `sun_angle` and `moon_angle` are fixed at **180°**, below the horizon; the sunrise/sunset colour is transparent | — | ATTR `visual/sun_angle`, `visual/moon_angle`, `visual/sunrise_sunset_color`. Checked: SkyRenderer draws both bodies at these angles. The daylight detector pulls the angle 20% toward 0/360°, so a normal detector reads 0 only for angles between 112.5° and 247.5°; 180° is safely inside |
| Sky light | Thrive 15; ramps through Flow; Endure ≈4 (dark) | yes | TL `gameplay/sky_light_level` |
| Stars | Only in Endure | yes | TL `visual/star_brightness` |
| Flora light | Sift flora *looks* luminous through emissive model elements. Only a few blocks emit real block light, so the darkness that lets monsters spawn in Endure isn't undone | — | block models (`light_emission` is per model element in 26.3, checked in `CuboidModelElement`); block light only where it's meant to create safe pockets |
| Hostile spawning | Follows light (the Overworld's 0–7 rule): surface monsters appear only when Endure darkens the land | yes (via light) | DT `monster_spawn_light_level`; VAN |
| Spawn tables | **Per biome** (1.0 has the Meadow's sub-biomes; the Carapace comes in 1.1). The Tide doesn't swap tables; light gates monsters, and CODE picks "enduring" variants in Endure | via light | biome ATTR `gameplay/natural_mob_spawns`; CODE for variants. The timeline doesn't override spawns, because an overlay would flatten biome differences (SF4) |
| **Hearing (Endure)** | Each area's hunters (1.0: Nesters) listen only in Endure. They hear the vibrations a sculk sensor hears, out to a warden's range of 16 blocks (a sensor hears 8), plus jukeboxes within 10. Sneaking and wool work as in vanilla. A vanilla vibration particle flies to the hunter as its tell. At falling Flow, surface hunters **burrow away** (telegraphed), so Thrive is safe | yes | CODE: `VibrationSystem` on the hunter, plus a separate `jukebox_play` listener as the allay has (checked: `jukebox_play` isn't in `#vibrations`); the retreat reads `thesift:gameplay/tide` |
| Sky & fog colour | Thrive: teal sky, pale fog. Flow: peach-gold. Endure: deep indigo | yes | TL `visual/sky_color`, `visual/fog_color`, `visual/cloud_color` |
| Ambient particles | Thrive: drifting pollen-like motes (trills). Endure: glowing soul motes | yes | TL `visual/ambient_particles` |
| Music | Each area has Thrive, Flow and Endure versions (canon OST pattern) | yes | TL or biome ATTR `audio/background_music` |
| **Weather** | **None, and the Overworld's weather timers are untouched.** In 26.3 weather state is server-global, and every level whose `canHaveWeather()` is true counts it down each tick. An open-sky dimension would therefore double the Overworld's weather speed and receive its storms (MF4, verified: `Level.canHaveWeather`, `ServerLevel.advanceWeatherCycle`, `WeatherAttributes`). One targeted mixin makes `canHaveWeather()` false for `thesift:the_sift` | — | CODE (mixin, D-008). The data-only route `has_ceiling: true` was rejected: it halves map radius and paints maps as ceiling noise (`MapItem`), and it changes where world-generation spawns are placed (`NaturalSpawner`) |
| Beds | Beds set spawn; **nobody can sleep**, in beds or straw beds ("You can't sleep here: the Sift never goes quiet"); no explosion. **Resting** in a bed **during Endure** resets the phantom timer, as sleeping at night does in vanilla, so long stays don't bring phantoms home. As with vanilla sleep, it is refused while hostile monsters are near (the same `NOT_SAFE` check). It skips nothing | — | ATTR `gameplay/bed_rule {can_sleep: never, can_set_spawn: always}` **and** `gameplay/straw_bed_rule {can_sleep: never, can_set_spawn: never, destroy_on_leave: true}`. Checked: an unset straw-bed rule defaults to "sleep when dark", and sleeping would move the Sift's clock. CODE: reset `time_since_rest` on bed use in Endure; vanilla resets it in `ServerPlayer.startSleeping` |
| Respawn anchors | Don't set spawn; a charged anchor **explodes when used**, as in the Overworld | — | ATTR `gameplay/respawn_anchor_works: false` (VAN; checked `RespawnAnchorBlock`) |
| Clocks | **Spin**, as in the Nether and End. The vanilla clock model reads the sun only in `minecraft:overworld` | — | VAN (checked in the 26.3 jar: `items/clock.json` selects on `context_dimension`) |
| Daylight detectors | Read no sun (0), as in the Nether and End. **Inverted, they sense Endure's darkness**, which makes them a vanilla-native Tide sensor for redstone | yes | VAN (`DaylightDetectorBlock` uses sky brightness × cos(sun angle)) |
| Compasses | Spin, as in any non-spawn dimension; lodestone and recovery compasses work | — | VAN |
| Maps | Work normally (no ceiling) | — | VAN |
| Nether portals | Can't be lit (vanilla lights them only in the Overworld and Nether) | — | VAN (`BaseFireBlock.inPortalDimension`) |
| Crossing the membrane | Players and ordinary mobs can cross. **Wardens and bosses can't**, so nothing chases a player into the gate's sanctuary | — | CODE: our portal block calls `setAsInsidePortal` only for entities outside the tag `#thesift:cannot_cross`. Checked: the warden doesn't override `canUsePortal` |
| Coordinates | 1:1 with the Overworld (no travel shortcut) | — | DT `coordinate_scale: 1` |
| Fall damage, water, lava | Normal (lava as in the Overworld) | — | VAN (`gameplay/fast_lava` false, `water_evaporates` false) |
| **Ichor** | A new liquid (canon hazard; a "thick liquid"). You **wade** through it slowly and can't swim in it; there are no currents. Outsiders who stand in it are set on fire (vanilla fire, with soul-flame particles) and lose XP. **Fire Resistance stops the burning but not the soul drain**, a vanilla counter with a Sift twist. Sift natives are immune, and some thrive in it (blubs bathe). **It evaporates outside the Sift**: a bucket can't place it at home, like water in the Nether | — | CODE: our fluid and liquid block. Wading, burning and the drain happen in the block's own `entityInside`, so no Entity mixin is needed: vanilla gives currents and swimming only to water and lava (`Entity.FLUIDS_WITH_CURRENT`, checked). Tag `#thesift:ichor_adapted`; evaporation follows the `water_evaporates` precedent (D-013) |
| **Tide basins** | The tide is literal: generated basins (each inside one chunk) fill with ichor at high tide (Endure) and drain at low tide (Thrive), one layer at a time during Flow. Rising Flow bubbles upward; falling Flow leaves tide marks. The flats' reagents follow the Tide **logically**, so walling out the ichor doesn't keep them open | yes | CODE: one controller per basin, in the same chunk. It works only while the chunk is loaded and snaps to the current level on load (under ~800 blocks) (systems.md §1) |
| Raids | Never start in the Sift | — | ATTR `gameplay/can_start_raid: false` |
| Patrols, phantoms, wandering traders, cats | Never spawn in the Sift: vanilla attaches these spawners only to the Overworld | — | VAN (checked `MinecraftServer`: other levels get no custom spawners) |
| Sculk and shriekers | **Blight** is the Sift's own block family: it pulses, creeps and shrieks, drops no XP, and its shriekers give Darkness and alert hunters without ever touching the vanilla warden warning tracker. **Vanilla sculk** that players place behaves exactly as vanilla | — | our blocks; VAN. Checked `SculkShriekerBlockEntity`: only shriekers that can summon warn; player-placed ones can't |
| Night-bound vanilla behaviour | Follows Endure: bees stay in hives, eyeblossoms open, turtle eggs hatch faster, villagers brought here rest | yes | TL `gameplay/bees_stay_in_hive`, `gameplay/eyeblossom_open`, `gameplay/turtle_egg_hatch_chance`, `gameplay/villager_activity`, `gameplay/baby_villager_activity` |
| Other vanilla attributes | Creakings never activate (no pale gardens); cat morning gifts don't apply (no sleep); no surface slimes; snow golems don't melt; piglins zombify as in the Overworld | — | ATTR `gameplay/creaking_active: false`, `gameplay/cat_waking_up_gift_chance: 0`, `gameplay/surface_slime_spawn_chance: 0`, defaults otherwise |
| Monsters burning | Never (no sun burns in the Sift) | — | ATTR `gameplay/monsters_burn: false` |
| Ambient light | Slightly raised (≈0.05), so Endure is dark but readable | — | DT `ambient_light` |
| What comes home | Nothing from the Sift grows or spreads in the Overworld. Healthy sculk and blight are decorative there, and bloom hearts take no XP there (`sift_life` is false). Ichor evaporates. Sift gear traits work only in the Sift. Sift blocks and companions still **react to music** at home as decoration. Companions keep working but need soul blocks as fuel | — | our scope attribute `thesift:gameplay/sift_life`, false outside the Sift |

**Code, all small and targeted:**
- the weather mixin (D-008);
- bed rest in Endure;
- ichor and tide basins (no Entity mixin; D-013);
- the hearing rule and the hunter retreat;
- the portal filter (wardens and bosses can't cross);
- enduring variants;
- growth reading `soul_flow`;
- the blight blocks;
- the frame and gate (entry_path.md).

No vanilla block or block entity is modified.

Everything else is dimension-type, attribute and timeline data. An earlier draft said "80% data"; that figure has been dropped as unmeasured.

## Accessibility checks (P1, §7.6)
- Every Tide change shows in the sky, the light, particles **and** music, never through sound alone.
- Every Sift sound has a subtitle.
- Ichor is readable without colour: it steams soul-fire particles and has a distinct surface animation.
- Blight pulses and creeps, and healthy sculk never pulses, so the two are told apart without colour.
- Hunters show that they heard you with a flying vibration particle and a flared crest.
