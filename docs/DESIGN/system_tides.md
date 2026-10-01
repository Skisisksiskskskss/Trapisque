# System: the Tides (numbers)

The source of truth for the Tide cycle's numbers and the tide basins' budgets. The *why* lives in
vision/systems.md §1 and rules.md; this page is what the code implements (WP-040, WP-045).

## The cycle (`thesift:tides` world clock)
| Phase | Clock ticks | Length | What it means |
|---|---|---|---|
| Thrive | 0 – 11 999 | 12 000 (10 min) | Low tide. Teal sky, full sky light, basins empty |
| Flow (rising) | 12 000 – 14 999 | 3 000 (2.5 min) | The tide comes in: amber sky, basins fill one layer per third |
| Endure | 15 000 – 26 999 | 12 000 (10 min) | High tide. Indigo night, sky light 4, basins full; beds can't skip it, but a bed out of monsters' reach resets the phantom timer |
| Flow (falling) | 27 000 – 29 999 | 3 000 (2.5 min) | The tide goes out, one layer per third |

- One cycle is **30 000 ticks (25 min)**, against vanilla's 24 000-tick day.
- The clock **stays paused at Thrive until the first crossing** in the world (`TideClock`), so a first arrival is always in daylight. `advance_time false` freezes it like any clock.
- The Tide reaches clients through vanilla clock sync; the `thesift:gameplay/tide` attribute (0–3) and `soul_flow` (1 / 0.25 / 0 / 0.25) are timeline tracks with constant easing.

## Tide basins
| Number | Value | Why |
|---|---|---|
| Size | Inner pool half-width 2–3 plus three 1-wide rings: 11–13 blocks across with rounded corners, always inside one chunk (centred, ≤ 6 from the middle) | world.md "≤ 14 × 14"; a chunk-local basin never waits on a neighbour |
| Depth | Pool 4 below the ground, climbing out in three 1-block steps (every step checked by a GameTest) | Deep enough to read as a basin; a 1-block climb at most, full or empty (the pre-release review's fix) |
| Ichor layers | 3; the top one a block below the rim | A full basin never spills; the rim is its lowest surrounding ground |
| Rarity | 1 in 3 chunks tried; kept only in lows (rim ≥ ground; the land 20 blocks out higher on average; the middle ≤ 3 above the rim) | "Tide basins sit in the lows" |
| Flow schedule | Rising: 1 layer at the start, 2 after a third, 3 after two thirds. Falling: the reverse, empty by the end | "One layer at a time during Flow" |
| Update rate | Each vent once a second, spread across ticks by position | Bounded work |
| Work per update | One layer: ≤ 169 block changes (13 × 13), flag 2 (no neighbour updates) | Under a chunk-section rebuild's cost |
| Catch-up after load | One update sets all 3 layers: ≤ 507 changes, under the 800 budget (GameTest `aReloadedVentCatchesUpAtOnce`) | rules.md: "snaps to the current level on load (under ~800 blocks)" |
| Player blocks | Never replaced; a player-placed vent is inert | No griefing tool, no base flooding |
| Measured cost | 50 basins through a whole Flow: vent work p95 0.005 ms per tick, max 5.6–10.4 ms on layer-change ticks (`SiftPerfTest`) | Six layer changes per cycle; vents spread over the second by a mixed position hash |

## Static ichor pools
Vanilla's lava lake with ichor in hymnstone: on the surface 1 in 8 chunks, underground 1 in 5 (y 8–90). They don't follow the Tide.
