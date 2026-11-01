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
| M2 Saving, progression, upgrades, rebirth | ✅ done |
| M3 Multiplayer stealing, bonk, escapes | ✅ done |
| M4 Monetization | ⏳ next |
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
- **Quality gate:** stylua, selene, luau-lsp strict type check, 37 unit tests (catalog, rolls, save schema, save
  locks, economy pacing, builder), rojo build, and the headless runtime check.
- **M3 additions:** RaidService (steal, carry, bonk, anti-teleport, owner-leave cancel), RaidController (knockback,
  swing, guide beam), and tests/sim.luau, an end-to-end server simulation in the gate.
- **M2 additions:** Index panel with set rewards, Settings panel, RewardService, rebirth confirm, and testable
  SaveStore (`fromBackend`).

## Next up (M4)

1. MonetizationService:
   - Gamepass ownership is cached into `session.Passes` on join, and PromptGamePassPurchaseFinished grants passes
     live.
   - ProcessReceipt: record the receipt in data, grant the product, `DataService.SaveNow`, then return Granted,
     with idempotency through `DataSchema.HasReceipt`.
   - Products: Overcharge1/5, IronDoor, LuckyWave, InstantRepair, ServerLuck, cash packs, DoubleOffline.
   - Check `PolicyService.ArePaidRandomItemsRestricted` and hide Lucky Wave where it's restricted.
2. GetShopInfo remote: Lucky Wave odds for the player's tier, scaled cash pack amounts, and policy flags.
3. ShopPanel with Passes / Boosts / Cash / Server tabs, live prices from MarketplaceService, and odds shown on Lucky
   Wave.
4. Contextual offers: a boost button with zero count opens a product prompt, and "Fix Now" on the door alarm prompts
   InstantRepair. Wire them through `UIController.OnMenu("Boost:<name>")` and `"InstantRepair"`.
5. Overhead tags for VIP and Rebirth. Add the VIP daily gift (with M5 daily).

## Known issues / notes

- In the Lune harnesses: instances are new wrapper objects per access (cache by path / compare with ==),
  `Part.Position` isn't derived (sim rewrites part `.Position` reads to `.CFrame.Position`), and Humanoid.Health
  needs setting.
- Lune's `CFrame.lookAt` is wrong for some directions. The test harnesses shim it. Real Roblox is fine.
- Sound ids are empty placeholders (see Config/Sounds.luau). ASSETS.md will list what to search for.
- Product ids are 0 until the owner creates them (see Config/Products.luau). The README will explain this.
