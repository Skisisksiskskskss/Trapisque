# PROGRESS.md: Beam a Brainrot

> **Next session: read this file first, then continue from "Next up" without asking.**
> Design decisions live in DECISIONS.md. Milestone history is in CHANGELOG.md.

## How to work on this repo

```bash
bash scripts/setup-tools.sh            # downloads rojo, selene, luau-lsp, lune, stylua into ./tools (gitignored)
bash scripts/check.sh builds/X.rbxlx   # format check, lint, strict types, unit tests, build, headless runtime check
```

- **Previews without Studio:** `lune run tests/runtime builds/X.rbxlx /tmp/dump.json`, then
  `python3 scripts/render.py /tmp/dump.json out.png --eye 0 230 -260 --look 0 0 10`
  (overview; for plot 1's base use `--eye 72 34 -30 --look 124 6 0`).
- **Branch:** `claude/beam-a-brainrot`. Each milestone build is saved as `builds/BeamABrainrot_M<n>.rbxlx`.

## Status

| Milestone | Status |
|---|---|
| M0 Scaffold, toolchain, design | ✅ done |
| M1 Core loop playable | ✅ done |
| M2 Saving, progression, upgrades, rebirth | ⏳ next |
| M3 Multiplayer stealing, bonk, escapes | ⬜ |
| M4 Monetization | ⬜ |
| M5 Retention (daily, offline, events, leaderboards, codes) | ⬜ |
| M6 UI polish, onboarding, SFX/VFX, mobile pass | ⬜ |
| M7 Launch kit | ⬜ |

## Done

- **World:** a ring of 8 plots around a central Brainrot Portal, with a plaza, ring road, red carpets, scenery,
  lighting and leaderboard anchors.
- **Bases:** 10 themed tiers, each with its own crystal style, decor, door, pedestals (4 to 24), upgrade kiosk and
  owner sign.
- **Brainrots:** a catalog of 36 original brainrots across 8 rarities, 5 mutations and 4 sizes. The procedural part
  builder is tested headlessly for every brainrot and mutation.
- **Waves:**
  - One brainrot per player per wave, every 50s, with a boss every 5th wave.
  - CHARGE tapping (server-validated, capped at +30%).
  - Outcomes: captured, door held, door broken, or shielded.
  - Escaped brainrots run a lap of the ring road and can be beamed by other crystals.
  - Brand-new players get a welcome wave.
- **Economy:** income ticks into pedestal pads, and stepping on a pad collects. Auto-place / swap-weakest / storage /
  sell are in. Crystal, door and tier upgrades and rebirth are wired server-side, with the upgrade panel on the
  client.
- **Saving infrastructure:** SaveStore (session locks, retries, release, in-memory fallback in Studio) plus
  DataService (autosave, BindToClose, migrations via DataSchema). It's already active.
- **Boosts:** Overcharge, Iron Door, Lucky Wave, Golden Wave and Instant Repair (activation path).
- **Client:**
  - HUD with cash, wave timer, incoming card with live power-vs-crystal bar, CHARGE button (F / R2 / tap), boosts,
    door alarm, toasts and announcements.
  - Upgrade and Brainrots panels.
  - Wave, escape, beam, capture and door-smash animations.
  - Owner-only door pass-through, repair prompt, crystal spin, idle brainrot bob, and rainbow cycling.
- **Quality gate:** stylua, selene, luau-lsp strict type check, 22 unit tests, rojo build, and the headless runtime
  check.

## Next up (M2)

1. Write an economy pacing test (tests/economy.spec.luau) that simulates the real Economy config, and assert tier
   timings stay in the 4–9h band for the first rebirth.
2. Build an Index panel (collection book plus index cash bonus display) and the rebirth confirmation.
3. Add a playtest of saves in the SaveStore memory backend: unit-test the lock logic with a fake backend.
4. Then M3: StealService (Steal remote, carry, speed checks, deposit), bonk tool, and the cancel-on-owner-leave rule.

## Known issues / notes

- Lune's `CFrame.lookAt` is wrong for some directions. The test harnesses shim it. Real Roblox is fine.
- Sound ids are empty placeholders (see Config/Sounds.luau). ASSETS.md will list what to search for.
- Product ids are 0 until the owner creates them (see Config/Products.luau). The README will explain this.
