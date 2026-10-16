# Trapisque

Trapisque is a race to the treasure across a trap-filled board, for 2 to 6 players. It
started as a board game, and this repository is its Roblox version: a purely top-down
2D game that uses the Roblox engine but doesn't look like a Roblox game. There is no 3D
world. Apart from players' own Roblox avatar headshots, everything you see is drawn
from plain UI frames, with no uploaded images, in one pirate look: printed simply like
an old board-game box (flat colour, a short list of inks, cream card on the open sea)
and inked like a comic (one heavy ink line around everything, hard shadows, punchy
lettering). Only the characters have faces.

| Match (PC) | Lobby (PC) | Match (upright phone) |
| --- | --- | --- |
| ![Match on a PC](docs/previews/pc-match.png) | ![Lobby on a PC](docs/previews/pc-lobby.png) | ![Match on an upright phone](docs/previews/upright-match.png) |

More in [docs/previews](docs/previews): the three maps, the character picker, the
locker, results, and phones held both ways. They're real screenshots of the game,
rendered offline (see [Screenshots](#screenshots)).

## What's in the game

- **Turns you play, not watch.** Your two dice are rolled for you and you pick which
  one to move with; the other one charges your Power bar. Hover a die and the board
  shows exactly where it takes you and what happens there. Roll doubles and the second
  die takes you backwards instead (or move the total). Whoever is clearly last (laps
  count) rolls an extra gold die that only moves.
- **Hidden traps.** Trap cards hide near you where only your team can see them. Guess
  where rivals will land; when one steps on yours: GOTCHA! (coins and Power for you).
- **Bonks.** Land on a rival and they fly back 2 tiles. BOING.
- **Six characters, all fair.** Mage, Trapper, Fire Starter, Naturalist, Warper and
  Overseer, each with a passive and a Power ability, tuned with thousands of bot games
  per map so each one wins about as often as the others (see
  [docs/DESIGN.md](docs/DESIGN.md)).
- **Cards you plan around.** One card per turn: traps, boosts that change which tiles
  you can reach, board pieces (teleporters, trampolines, conveyor belts) and potions
  from the Potion Seller.
- **Three maps**, each a place the trail winds through: Blissful Tricks (a tropical
  island cut by two rivers), Junction Dungeon (a rocky sea fortress with locked gates
  and secret tunnels for its shortcuts) and Slimy Snares (a swamp boardwalk spiralling
  in to the treasure, past slime pools). Each has its own hazard. **Five modes**: Chaos (free-for-all), Assist (2 vs 2), Factions (three
  teams of 2), World War Four (3 vs 3) and a **Weekly Event** with a twist on the
  rules (Trap Frenzy, Bonk Bonanza, Power Surge, Triple Dice). See
  [docs/RULES.md](docs/RULES.md) for the rules as played.
- **Reasons to come back.** Character mastery (levels, Gems and titles), three daily
  quests (with a free swap and a bonus chest), a 7-day login streak, trophies and ranks
  from Quick Play with a trophy leaderboard.
- **Match lengths.** Quick (2 treasures), Standard (3) and Classic (4).
- **Quick Play matchmaking.** Queue for any mode on your own or as a party. Queues are
  shared by every server, and bots fill empty seats if you wait long enough.
- **Parties.** Create a party and invite friends with Roblox invites, or share its
  6-letter code. A party can be open to its code or invite-only. Joining a party on
  another server takes you to that server.
- **Practice and private matches.** Pick the mode, map, length and number of bots.
- **Bots.** They play every character and card using only what their seat can see, and
  step in for anyone who goes away or leaves.
- **Turn timer.** Practice games have none. Elsewhere you get 45 seconds, with a
  countdown on your dice. If it runs out, your highest die is moved for you. Only
  someone who touches nothing for two turns in a row counts as away. A bot then plays
  for them, and any tap or click hands control back. Every screen keeps pace with the
  server, so your turn never shows up late.
- **Cards you can feel.** Hover a card to lift it out of your hand with its rules
  beside it. Click it to play it, or drag it onto the board: a trap rides on the
  pointer over the tiles you may hide it on, and is slapped down with a thud.
- **Your character is your colour.** Each of the six characters has one colour, and
  it's its player's colour everywhere (on the board, the player list, the feed). One of
  each character per match: if two players want the same one, a random one of them
  gets it and the other gets a free pick.
- **Treasure Chests.** A cosmetic-only collection: accessory packs your character
  wears on the board (a monocle and moustache, a captain's hat and hook, a parrot on
  your shoulder; the epic ones move, like a spinning propeller cap or a little cloud
  raining on you), dice, trails, emotes and titles. You open chests with Gems, which
  you earn by playing.
- **Gamepasses** that never touch gameplay (see below).
- **Any screen.** The layout follows the device: the board fills the screen on a PC,
  phones held sideways keep the cards under your left thumb and the dice under your
  right, and phones held upright stand the board up. Nothing sits over Roblox's own
  buttons, notches or the home bar.
- **Sound.** Dice on felt, steps, card swishes, bonks and a thud when a card hits the
  board, all from Roblox's free audio library. Music and sound effects each have a
  volume slider (in Settings and the match menu), saved to your profile.
- **Music that follows the game.** Three moods, each a short playlist that's
  shuffled so no track plays twice in a row. Each track crossfades into the next
  just before its own ending, so nothing loops or cuts. The music steps back for a
  moment when someone finds a treasure, turns tense when a player (or team) is one
  treasure from winning, and bows out under the winner's fanfare.

  | Mood | Tracks (APM, Roblox audio library) |
  | --- | --- |
  | Lobby | [Les Voyages de la Mappa Mundi](https://create.roblox.com/store/asset/1837137568), [Magic - The Harp](https://create.roblox.com/store/asset/1844347220), [Clair De Lune (harp)](https://create.roblox.com/store/asset/96767255237081) |
  | Match | [Shards Shimmer](https://create.roblox.com/store/asset/9048197244), [Exploring Concepts (Underscore)](https://create.roblox.com/store/asset/9040054834), [Puzzles in Twilight (Alt)](https://create.roblox.com/store/asset/79301554757012), [Mystery Islands](https://create.roblox.com/store/asset/1844986119) |
  | Endgame | [Mind Puzzle (b)](https://create.roblox.com/store/asset/1839856504), [Curious Crime (Pulse Only)](https://create.roblox.com/store/asset/129673998145182) |

## Project layout

```
src/shared/          ReplicatedStorage.Shared: code used by both server and client
  Config.lua         every tunable number (rules, timers, rewards, gamepass ids)
  Game/              the rules engine: Engine, Items, Characters, Maps, Modes, Bot...
  Meta/              cosmetics, chests, gamepasses, matchmaking, progression (Progress)
src/server/          ServerScriptService.Server: data, parties, matchmaking, matches
src/client/          StarterPlayerScripts.Client: all screens and the art library
  UI/                Icons, Cards, Shapes, Widgets... plus Lobby/ and Match/ screens
src/first/           ReplicatedFirst loading screen
tests/               rules, simulation, meta and board-layout tests (plain Luau)
tools/               test bundler, type-check, smoke test and screenshot scripts
docs/                rules, design notes (balance tables) and screenshots
trapisquebooklet.html  the original rulebook
```

The rules engine (`src/shared/Game`) is pure Luau with no Roblox APIs. The server runs
it authoritatively and streams events to clients, which animate them. The tests run
the same engine outside Roblox.

## Building and running

You need [Rojo](https://rojo.space) 7.x.

```sh
rojo build default.project.json -o Trapisque.rbxlx   # a place file to open in Studio
# or, to live-sync while editing:
rojo serve                                            # then connect with the Rojo plugin
```

In Studio:

1. Open **Game Settings → Security** and turn on **Enable Studio Access to API
   Services**, so profiles can load and save. The game still runs without it, but
   progress isn't kept.
2. Press **Play**. Studio can't teleport, so matchmaking, parties and matches all run
   on the one test server. Every gamepass counts as owned in Studio
   (`Config.StudioOwnsAllPasses`), so you can try everything.
3. To test with several players, use **Test → Clients and Servers**.

## Publishing

1. Publish the place to Roblox. It's a single place: public servers are lobbies, and
   each Quick Play match runs on a reserved server of the same place.
2. The game uses DataStores (profiles), MemoryStores (matchmaking queues and party
   codes), TeleportService (reserved match servers, cross-server party joins),
   SocialService (invites), MarketplaceService (gamepasses) and PolicyService. They
   all work in a published experience without extra setup.
3. Create the gamepasses (next section) and paste their ids into
   `src/shared/Config.lua`.

## Gamepasses

Create these on the Creator Dashboard (**Monetization → Passes**) and put their ids in
`Config.GamePasses`. A pass left at `0` is hidden from the in-game Shop.

| Key | Name | What it gives |
| --- | --- | --- |
| `VIP` | VIP | +25% Gems from every match, a free Explorer Chest every day, the Royal Crown accessory and VIP title, and a gold name in parties and matches. |
| `DoubleGems` | 2x Gems | Double Gems from every match (stacks with VIP). |
| `LuckyCharm` | Lucky Charm | Legendary and Mythic chest odds ×1.5, and the chest screens show your boosted odds. Hidden for players whose region doesn't allow paid random items. |
| `EmotePack` | Emote Pack | 6 extra emotes, and up to 6 emotes equipped in matches. |

None of them changes how a match plays. They only speed up or add to the cosmetic
collection.

## Treasure Chests

- **Explorer Chest:** 100 Gems (10 for 900). Odds are Common 62%, Rare 26%, Epic 9%,
  Legendary 2.5% and Mythic 0.5%. You're guaranteed an Epic or better at least every
  10 chests and a Legendary or better every 50.
- **Royal Chest:** 350 Gems (10 for 3,150). Odds are Rare 58%, Epic 30%, Legendary 10%
  and Mythic 2%. You're guaranteed a Legendary or better at least every 20 chests.
- Items you don't own yet are 3× as likely within a rarity, and duplicates turn back
  into Gems.
- Gems can't be bought with Robux. They come from matches (finishing, treasures,
  winning, levelling up), character mastery levels, daily quests, the login streak and
  the starting gift.

The odds, prices and rewards are in `src/shared/Meta/Gacha.lua` and `Config.Rewards`.

## Development

### Tests

The tests run the rules, bot simulations, chest maths and board layouts with the
standalone [Luau](https://github.com/luau-lang/luau/releases) CLI:

```sh
python3 tools/bundle.py build/tests.luau tests/harness.luau tests/engine_spec.luau \
  tests/sim_spec.luau tests/clock_spec.luau tests/meta_spec.luau tests/layout_spec.luau \
  tests/ui_layout_spec.luau tests/zz_run.luau
luau build/tests.luau
```

### Balance report

`tests/balance.luau` has bots play thousands of free-for-all games and prints how often
each character wins on each map (fair is 1 / players). It takes a few minutes:

```sh
python3 tools/bundle.py build/balance.luau tests/balance.luau && luau build/balance.luau
```

Set `BALANCE_GAMES`, `BALANCE_SETUPS` or `BALANCE_MAPS` in a small script bundled
before it to change the sample. The latest results are in
[docs/DESIGN.md](docs/DESIGN.md).

`tools/bundle.py` fakes just enough of Roblox's `script` tree for the shared modules to
`require` each other outside Studio.

### Type checking

```sh
DEFS=/path/to/globalTypes.d.luau tools/typecheck.sh
```

This needs `rojo` and [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) on your
`PATH`, plus Roblox's type definitions (`globalTypes.d.luau` from the luau-lsp repo;
without `DEFS` the script looks in `.luau/globalTypes.d.luau`). It checks every file
in strict mode and reports only real mistakes, like unknown properties or wrong
argument counts.

### Screenshots

`tools/shots.sh` takes real screenshots of the game without Studio: it plays the smoke
test (below) on the fake Roblox and draws what's on screen at a few moments (the
lobby and its pages, the character picker, a match, the results) on a PC and on
phones held both ways; `tools/shots.sh boards` draws just the three maps. The fake
measures text with the game's real fonts (`tests/fake/fonts.luau`, from
`tools/gen_font_metrics.py`), so layouts wrap and truncate as they do in Roblox. It
needs Python 3 with Pillow and the Bangers and Oswald fonts from Google Fonts in
`tools/preview/fonts` (or a folder named by `TRAPISQUE_FONTS`):

```sh
LUAU=/path/to/luau OUT=docs/previews tools/shots.sh pc phone upright boards
```

### Smoke test

`tools/smoke.sh` plays the whole game (server and client) on a fake Roblox in
`tests/fake`: a scripted player tours the lobby and plays a match to the end with the
real controls on a PC, on phones held both ways, in a team mode, in the weekly event
and through Quick Play (going idle until a bot takes over, then coming back). Any Lua
error, warning, table Roblox would mangle on a remote or in a DataStore, or work left
running after the match fails it. It takes about two minutes:

```sh
LUAU=/path/to/luau tools/smoke.sh
```

### Art rules

Everything is built from Frames with `UICorner` and `UIStroke`. Card art, characters,
accessories, tokens, hazards, map props and the maps themselves are data
(`StickerArt`, `AccessoryArt`, `MapProps`, `MapScenes`, `IconData`) drawn by `Icons`,
`Shapes` and `MapArt`. The style has a few strict rules so every screen comes out of
the same kit:

- one ink line (`Theme.C.line`) around everything, drawn as a real outline pass, and
  light lettering always outlined in it
- a short list of flat pirate inks from `Theme` (no purple, no gradients, no glow);
  hard ink shadows down and to the right, never blurred ones
- only the six characters have faces; everything else is a plain object
- a character's colour is its player's colour, everywhere
- two fonts: Bangers for anything loud, Oswald for reading
- the same sticker drawing wherever a thing appears (card, board, effects, menus)

The fonts are built into Roblox, and the sounds and music are free Roblox audio
library assets (listed in `src/client/Sound.lua`), so the game needs no uploads.
