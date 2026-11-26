# Skuishi Berds for Roblox

A Roblox remake of the websim game **Skuishi Berds**: a squishy bird bounces between two
walls, every crossing of the middle line *strums* it and arms the walls with spikes, and
69 chaotic events keep changing the rules. It's built for Roblox from the ground up:
flat 2D like the original (drawn entirely with Roblox UI, no 3D world), portrait on
phones, real online multiplayer, couch play on one device, saving, leaderboards and a
kid-friendly shop.

## What's in the game

**Modes**

| Mode | Players | What happens |
| --- | --- | --- |
| Solo | 1 | The original game: both walls, 4 lives, events. |
| Bot Buddy | 1 + AI | Co-op with a bot bird on the top half. |
| Couch Co-op | 2, one device | Top bird + bottom bird, shared score. |
| Couch Duel | 2, one device | Your strums arm the walls on your rival's side. 3 lives each. |
| Duos | 2 online | Online co-op. Bots fill in after 20 s, and a couch pair can join as one team. |
| Versus | 2–6 online | Last bird flapping wins. Bots fill empty seats after 12 s, sudden death at 2 minutes. |

**Birds.** Every bird has one ability that charges by strumming. They're sidegrades, not
upgrades, so Versus stays fair. Berd is free; the rest cost coins (or Robux if you enable
the products).

| Bird | Ability (strums) | Coins |
| --- | --- | --- |
| Berd | U-Turn (3): instant direction flip | free |
| Zippy | Dash (3): 0.4 s burst, phases through event hazards | 600 |
| Blinky | Blink (3): short teleport "up" | 750 |
| Puff | Puff Up (4): spike-proof for 1.5 s but bigger and heavier | 900 |
| Pecky | Peck (4): the next spike you touch shatters | 900 |
| Hoot | Focus (4): your bird moves at half speed and shows its path | 1100 |
| Flippy | Flip (3): toggle your own gravity | 1100 |
| Honk | HONK (5): pops nearby hazards and shoves rivals in Versus | 1300 |

**Events.** All 69 original events are here. A few that borrowed other games' names are
renamed: Soul Mode → *Bone Zone*, Frogger → *Log Jam*, Subway → *Rail Rush*,
Guns → *Blasters*. The Event Journal tracks the ones you've found (new ones pay 50 coins)
and lets you practice any discovered event in the Event Lab.

**Cosmetics.** 44 body colors, 19 patterns, 46 hats (all 43 from the original plus 2
exclusives), and 15 death animations replacing the single splat. Couch player 2 has
their own look.

**Progress.** Coins, XP levels, daily reward with a streak, revive tokens, stats, and
three global leaderboards (Solo best, Duo best, Versus wins). Data uses session-locked
DataStore profiles, so it can't be overwritten when a player hops servers.

**Shop rules (on purpose).** Only impulse buys a kid would actually want: cosmetics,
birds, coin packs, revives. No 2x coins, no VIP, no paid mystery boxes, and nothing you
can buy gives an edge in Versus (revives are Solo/co-op only).

## Getting it into Roblox Studio

You need [Rojo](https://rojo.space) 7 (CLI plus the Studio plugin).

1. Build a place file and open it in Studio:
   ```
   rojo build default.project.json -o SkuishiBerds.rbxlx
   ```
   Or, to live-sync while you edit: run `rojo serve`, open a new Baseplate in Studio, and
   press **Connect** in the Rojo plugin.
2. **File → Publish to Roblox** (the place must be published for saving to work).
3. **Game Settings → Security → Enable Studio Access to API Services.** Without it the
   game still runs, but progress isn't saved in Studio and a toast says so.
4. Press **Play**. For multiplayer, use **Test → Clients and Servers** with 2+ players.
   For phones, use the **Device Emulator** (the game locks to portrait).

## Hooking up your original sounds

Your 25 original sounds are in `assets/audio/`. Until you upload them, the game plays
built-in Roblox sounds as stand-ins. Some of those may not exist in every Roblox
version; a missing one just stays silent.

1. Studio → **View → Asset Manager → Bulk Import**, and select everything in
   `assets/audio/`. Roblox limits monthly audio uploads, and unverified accounts get
   fewer, so you may need to do it in batches.
2. Open `src/shared/Config/Sounds.luau` and paste each ID into its entry, for example
   `flap = s("rbxassetid://1234567890", ...)`.

## Robux products (optional)

Create developer products under **Creator Dashboard → your experience → Monetization →
Developer Products**, then paste their IDs into `src/shared/Config/Products.luau`. Each
line has a suggested price. Any product left at `0` stays hidden. With none set, the
shop shows players "The Robux shop opens soon!".

Receipts are granted exactly once (the PurchaseId is saved with the profile), even if
Roblox delivers the same receipt twice.

## Custom art (optional, e.g. ForgeGUI)

Everything is drawn with UI shapes, so no images are needed. To use your own art, upload
it and paste the IDs into `src/shared/Config/Images.luau` (logo, menu background, coin
icon, play button, mode icons, bird portraits). Any filled-in slot replaces the drawn
version.

## Controls

* **Solo / online.** Flap: tap, click, Space, W or Up (gamepad A/R2). Ability: E, Q,
  Shift, S or Down, right-click, the on-screen ability button (gamepad X/L2).
* **Couch.** Phone: top half of the screen is player 1, bottom half is player 2.
  Keyboard: P1 = W (flap) / S (ability), P2 = Up / Down. Two gamepads: one each. One
  gamepad: L1/L2 = P1, R1/R2 = P2.

## How the multiplayer works

* Every bird is simulated by its owner's device at a fixed 60 ticks per second, locked
  to the server clock, so flaps feel instant even on a laggy connection.
* The server owns everything shared: spikes, events, scoring, lives, bots. Event hazards
  come from a shared seed, so every device sees the same meteors, trains and bones without
  streaming them.
* Each device sends its bird's state 30 times a second, and the server relays snapshots
  20 times a second, both on `UnreliableRemoteEvent`s. Each state keeps the tick its
  owner recorded it at, and other players replay it on that timeline with an
  interpolation delay that adapts to their measured latency. Motion stays smooth instead
  of stepping at the network rate.
* The server double-checks hits. A bird reported sitting on a live spike without
  reporting the hit takes it anyway. Strums and ability charges are validated too.

## Project layout

```
default.project.json   Rojo project (ReplicatedStorage.Shared, ServerScriptService.Server,
                       StarterPlayerScripts.Client)
assets/audio/          your original sounds, ready to upload
src/shared/Config/     tuning, modes, birds, events, cosmetics, products, sounds, images
src/shared/Sim/        deterministic simulation shared by server and clients
                       (physics, spikes, 69 events, abilities, bots)
src/server/            match runner, matchmaking, DataStores, shop, receipts, leaderboards
src/client/            2D renderer (arena, birds, hats, patterns, deaths, event visuals),
                       input, audio, menus
tests/                 simulation tests, headless end-to-end tests, screenshot tool
```

## Tests you can run without Studio

These need [Lune](https://lune-org.github.io/docs) 0.11:

```
lune run tests/run              # simulation: physics parity, all 69 events, determinism, bots
lune run tests/smoke quick      # the real server + client scripts playing through the game
lune run tests/smoke            # same, plus practicing every one of the 69 events
lune run tests/smoke studio     # Studio without API access (DataStores rejected)
lune run tests/snap             # approximate screenshots as HTML in build/snapshots/
node tests/snap_png.js build/snapshots   # turn them into PNGs (needs Playwright)
```

`tests/mock` is a small stand-in for Roblox. Instances are real Lune DOM instances, so
property names and value types are checked against Roblox's API. Remotes follow
Roblox's argument rules, DataStores follow their JSON rules, and time runs on a
deterministic 60 Hz clock with simulated latency. Two players tap the actual menu
buttons, and an autopilot (the game's own bot brain) plays the matches.

## Known limits

* This was developed without Roblox Studio. Everything above ran in the headless
  harness, which catches script errors, bad properties, network-rule violations and
  logic bugs, but it is not Roblox. Expect a first playtest to turn up visual details
  the approximate screenshots can't show.
* Movement is client-authoritative (that's what makes flaps instant). The server
  validates strums, ability use and spike hits, but a determined exploiter could still
  fake their bird's position in Versus.
