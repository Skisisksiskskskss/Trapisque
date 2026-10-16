# Trapisque v2: design notes

Why the game changed, what was measured, and what's still worth watching. The rules
themselves are in [RULES.md](RULES.md).

The brief: make the game exciting at a glance for younger players without stripping
it down, deep enough for older players to keep coming back, fair whichever character
you get, hands-on instead of "press ROLL and watch", with cards you plan around, and
one look that holds together instead of a generic one.

## 1. Every turn is a decision

**Before:** roll one die, move that far. The only choice most turns was whether to
play the card you happened to have, and the answer was usually "yes, now".

**Now:** two dice are rolled for you and you pick one. That one choice carries a lot:

- **Where do I land?** Hovering a die shows the exact path and what's at the end:
  a token, a rival to bonk, a hazard that stops you, a trap you know about. Short and
  safe, or long and risky?
- **What do I charge?** The die you *don't* use fills your Power bar. Moving with the
  small die charges a lot of Power; moving with the big die charges little. Speed now
  or your ability sooner is a real trade-off on most turns.
- **Doubles** turn the second die around: it moves you **backwards** (grab a token you
  just walked past, or bonk someone right behind you) while the other die still
  charges Power. Or move the total, which charges nothing.

Each card answers a question too. One card per turn means you're always choosing which
card and when. Boosts (Speed Boost, Bounce Pad, Moonwalk) change which landing tiles
you can reach, so they're played *with* the dice, not instead of them.

**The underdog.** Whoever is clearly last (8 tiles or more behind the next player,
counting laps, so finishing a lap never makes you "last") rolls an extra **gold die**.
It only moves you: it never charges Power and never makes doubles, so it can't feed an
ability engine. It gives the player who's out of it a bigger choice each turn and a way
back into the race, without handing anyone a free win: with it on, no character's win
rate moved by more than the noise (tables below).

**Bonks** make the race physical: landing on a rival knocks them back 2 and bounces you
forward 1. Picking the die that lands on someone is the most satisfying move in the
game, and it reads at a glance ("BOING!"). Chains were tested and turned off: they made
ping-pong games roughly five times as bonk-heavy and much slower.

## 2. Cards you plan around: hidden traps

Traps are **hidden** from rivals and must go **within 5 tiles of you**, with **3 out
at most** (oldest replaced). That turns "throw a trap anywhere" into a small puzzle:

- Where will people land? Tokens draw players in, hazards stop them on known tiles,
  and the tile one short of a rival's reach is a classic.
- Rivals know *that* you hid something (they see a puff of smoke near you) but not
  where, so they read your position and play around it.
- Catching someone pays you (**GOTCHA!** +1 coin, +2 Power), so good placement snowballs
  into your ability.

Visible tools stayed visible (Wall, Teleporter, Conveyor Belt, Trampoline, Spore
Warper): they're about shaping the board, not ambushes. The Overseer sees every hidden
trap and the X-Ray Potion reveals them for a turn, so hidden information has counters.

Server-side, hidden information never leaves the server: each player's event stream
and snapshots only contain the traps they're allowed to see (`Engine:eventsFor`,
`Engine:snapshot(seat)`), and bots only use what their seat could see.

## 3. Fairness: fixing it structurally

The rule used throughout: **in a free-for-all, hurting one rival helps your other
rivals as much as it helps you.** Abilities that only harm one person are weak with 4+
players and dominant with 2. So every ability now either helps its user or reaches
everyone, and costs Power instead of recharging on a timer:

| Character | Before | Now | Why |
| --- | --- | --- | --- |
| Mage | Hex one player (freeze or burn) | **Blizzard**: freeze every rival for a turn, skate 1 ahead (7 Power) | Single-target harm; now hits the whole table but costs more. |
| Trapper | 2 free traps, Scavenge spins | Hides traps anywhere, 4 out, **hops 2 forward per catch**; Scavenge picks 1 of 2 traps | Traps only helped indirectly; now a catch moves you too. |
| Fire Starter | Ignite a player on your tile | Bonks set rivals on fire; **Blast Off** rockets 4 and leaves burning embers | Needed a self-benefit and a reason to get close. |
| Naturalist | Walked through everything incl. shortcuts | Ignores hazards; **Overgrow** grows the map's hazard nearby | Shortcut-walking was worth 11 to 17 tiles a lap on Junction. |
| Warper | Swap with anyone, once a game | **Warp** with someone up to 7 tiles away (10 Power) | Unlimited range let the Warper jump to the leader. |
| Overseer | Nudge 1, always went first | Sees hidden traps; **Nudge 2** anyone, cost 4 | Going first was a free edge; vision is a counter, not a bonus. |

Maps were evened out too, so no character's passive is worth far more on one map:

- Ranges are measured **along the race**, not through shortcuts (a shortcut made
  "within 5 tiles" mean 20 tiles of progress on Junction).
- **Junction Dungeon** lost its two starting Spikes (frozen players couldn't avoid
  them, so Mage and Overseer feasted there) and gained a third gate, so its hazard
  density matches the other maps.
- On **Slimy Snares**, slime **eats 5 steps** instead of stopping you outright. With
  plain stopping, the Naturalist (who ignores slime) won about 31% of 4-player games
  there. Making slime merely slow you overcorrected (12 to 20%). Five steps lands
  everyone at 24.7 to 25.5%.

### How it was measured

Bots play each character on each map, thousands of games per setup
(`tests/balance.luau`; 900 games per map per setup below). Bots pick dice by
evaluating every landing tile, hide traps where opponents are most likely to land
(over all 36 dice outcomes), and use abilities with per-character heuristics. They
only use what their seat can see. The tables show how often each character wins;
fair is 1 ÷ players. With 900 games, about ±2 points is noise in the 4-player tables.

**Before** (the v1 rules with the v1 bots, 600 games per map):

| 4 players, Quick | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer |
| --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 32.7% | **7.8%** | 12.2% | 17.9% | **50.7%** | 28.8% |
| Junction Dungeon | 23.9% | **8.3%** | **7.5%** | **57.3%** | 32.3% | 21.2% |
| Slimy Snares | 35.5% | 10.5% | 11.5% | 22.7% | **49.3%** | 20.8% |

**After** (v2 with backwards doubles and the underdog's gold die, 600 games per map;
with 600 games, about ±2.5 points is noise in the 4-player tables):

| 4 players, Quick | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer |
| --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 27.0% | 21.0% | 22.5% | 25.9% | 27.5% | 26.1% |
| Junction Dungeon | 25.1% | 22.2% | 25.2% | 24.7% | 25.9% | 26.9% |
| Slimy Snares | 25.3% | 24.7% | 26.0% | 24.2% | 25.7% | 24.1% |

| 4 players, Standard | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer |
| --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 28.3% | 25.7% | 22.2% | 24.4% | 23.2% | 26.1% |
| Junction Dungeon | 25.8% | 29.4% | 24.0% | 23.4% | 21.4% | 25.9% |
| Slimy Snares | 27.0% | 26.7% | 22.5% | 23.7% | 26.2% | 23.9% |

| 2 players, Quick (fair 50%) | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer |
| --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 50.3% | 38.3% | 53.1% | 55.0% | 46.3% | 58.2% |
| Junction Dungeon | 53.8% | 46.4% | 50.7% | 50.0% | 39.3% | 60.9% |
| Slimy Snares | 55.8% | 42.6% | 53.6% | 52.5% | 43.8% | 52.2% |

| 6 players, Quick (fair 16.7%; all six play every game) | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer |
| --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 13.3% | 18.2% | 15.5% | 16.0% | 22.2% | 14.8% |
| Junction Dungeon | 15.7% | 18.8% | 14.0% | 16.7% | 19.7% | 15.2% |
| Slimy Snares | 13.0% | 19.7% | 16.0% | 16.8% | 21.8% | 12.7% |

The underdog's gap was tuned with these runs: at 6 tiles, the gold die also charged
Power and pushed the Overseer to 31% in 4-player games; as a move-only die with an
8-tile gap, every 4-player number stays within the noise of the v2 tables. Taking the
doubles total away (backwards only) was tried first and dropped the Naturalist to 13
to 17%, so doubles keep the total as a choice.

**Still worth watching:**

- **2 players** stays the widest (38 to 61%): with one rival, the Trapper's hidden
  traps have one target who can often play around them, and the Overseer's vision
  matters most. Buffing the Trapper's bounty to 3 tiles barely helped with 2 players
  but pushed the Trapper to 31 to 43% with 4, so it stays.
- **Warper with 6 players** (20 to 22% vs 16.7%): with six on the board someone is
  always within 7 tiles ahead. Raising Warp to 11 Power helped there but made the
  Warper weak in 4-player Standard games (19 to 22%).
- These are bot-vs-bot numbers. Real players will find different lines; the balance
  report (`tests/balance.luau`) is the tool to re-check after any tuning, and every
  number lives in `Config.Characters` / `Config.Rules`.

## 4. Reasons to come back

| System | Hook | Where |
| --- | --- | --- |
| Character mastery | Every match levels up the character you played; Gems each level, titles at 3 / 6 / 10 ("Mage Fan", "Mage Pro", "Mage Legend"). Gives players a reason to try every character. | `Meta/Progress`, lobby character picker, results |
| Daily quests | Three a day ("Bonk 5 rivals", "Catch 3 rivals with hidden traps", "Play as the Warper"), one free swap, a chest for all three. They point players at the game's best moments and at characters they haven't tried. | Lobby QUESTS, results |
| Login streak | 30 → 150 Gems over a week, a chest on day 7. | Toast on login, QUESTS page |
| Trophies and ranks | Quick Play results move your trophies (placement-based, gentle for new players); Wood to Legend; a trophy leaderboard. The long-term goal for older players. | Profile chip, results, Top Players |
| Weekly event | A rotating twist (Trap Frenzy, Bonk Bonanza, Power Surge, Triple Dice) with its own queue, so the game feels different week to week without changing the core. | Play panel, How to Play |

None of it touches fairness inside a match: mastery and trophies are cosmetic and
social, Gems buy cosmetics only.

## 5. One look: pirates, printed simply, inked like a comic

The candy-night look (purple table, faces on everything) read as generic. The new
direction is a pirate board game, printed simply like an old game box and inked like a
comic, with a few strict rules so every screen comes out of the same kit:

- **One ink line** (`#1C1A24`) around everything: tiles, cards, buttons, art, the
  coastlines. Light lettering is always outlined in it, so it reads on cream card and
  on the sea alike.
- **A short list of flat inks** (sea blue, pirate red, gold, jungle green, cream card;
  no purple, no gradients, no glow) with hard ink shadows down and to the right.
- **Only the characters have faces.** Traps, tokens and hazards are plain objects. Each
  character has **one colour**, and that colour is its player's everywhere: on the
  board, the player list, the feed. There are no pawns and no colour rings; the
  character stands on its tile itself, and one of each plays per match.
- **Accessory packs instead of pawn skins:** two pieces a pack, drawn on the character
  (a monocle and moustache; a tricorn and a hook; a parrot and an eye patch). The epic
  and better ones move in simple, physical ways (a spinning propeller, a rain cloud,
  bubbles from a pipe, a waving octopus, circling gulls), never rainbow or glowing.
- **Two fonts:** Bangers for anything loud, Oswald for reading.

**The maps are places, not grids.** Each map's route is a hand-drawn winding curve
(`MapScenes`); the tiles are spaced evenly along it and the land grows around the
trail (`BoardLayout`), so the path runs through the environment: a tropical island
whose two rivers cross the trail exactly at its river tiles, a rocky sea fortress with
gate towers at its gates and secret tunnels for its shortcuts, and a swamp boardwalk
that spirals in to the treasure past bubbling slime pools. Props (palms, huts, ships,
cannons, mangroves) are placed clear of the trail. The board graph (tile count,
shortcuts, hazards) is the rulebook's, so none of this touches balance.

Everything is still drawn from UI frames at runtime (no uploaded images), so it stays
crisp at any size. `tools/shots.sh` renders real screenshots offline for review.
