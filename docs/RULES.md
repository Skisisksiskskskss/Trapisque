# Trapisque rules (Roblox edition, v2)

These are the rules the game actually runs, in plain English. They started from the
original Trapisque description and the rulebook (`trapisquebooklet.html`), then were
reworked so every turn has a real decision in it, hidden traps make you think about
where people will land, and every character wins about as often as the others. Where
the game differs from the board game it is marked **(digital)**; the big changes are
listed at the end, and `docs/DESIGN.md` explains why each one was made.

All the numbers live in `src/shared/Config.lua` (`Config.Rules`, `Config.Characters`);
the rules themselves are in `src/shared/Game/Engine.lua`. The test suite (`tests/`)
checks them, and `tests/balance.luau` plays thousands of bot games to check fairness.

## The race

Each map is a path of hex tiles from the **Start** flag to the **Treasure** chest.
Reaching the chest banks a treasure, pays 2 coins and sends you back to the Start for
another run. The first player (or team) with enough treasures wins.

| Length | Treasures to win | Notes |
| --- | --- | --- |
| Quick | 2 | Quick Play always uses this length. **(digital)** |
| Standard | 3 | **(digital)** |
| Classic | 4 (3 in World War Four) | The long game. |

In team modes teammates **pool** their treasures: a team of two playing Quick needs 4
between them, however they split them. **(digital)**

A match ends on score after 40 / 60 / 80 rounds (Quick / Standard / Classic): most
treasures, then whoever is closest to the next one. **(digital)**

## Setup

1. **Map.** Quick Play picks Blissful Tricks, Junction Dungeon or Slimy Snares at
   random. Practice and private matches let you choose.
2. **Characters.** You pick yours in the lobby; two players may pick the same one.
   Bots get a random character nobody else has.
3. **Tokens.** Every token spot gets a random token: Trap, Assist, Board Piece or
   Potion Seller (weighted 34 / 30 / 22 / 14, with at least one Potion Seller). Spots
   come every 3 tiles on Blissful Tricks and every 5 on the other two maps. A used
   token jumps to a random free tile, so the board keeps changing.
4. **Coins.** Everyone starts with 1.
5. **Turn order** is shuffled.
6. **Starting cards.** Everyone gets one random assist card. The Trapper also gets a
   random trap and the Fire Starter a Fire card.

## Your turn

Your **two dice are rolled for you** as your turn starts. Then:

1. **Play one card**, if you want (traps, boosts, potions... see below). Cards marked
   *works by itself* never need playing: they act from your hand.
2. **Use your ability**, if your Power bar is full.
3. **Pick a die and move.** The die you move with is your move; the best of the dice
   you *don't* use charges your **Power**. Rolled doubles? You have three ways to go:
   forwards with the first die, **backwards** with the second (the other one still
   charges your Power: back onto a token you just passed, or onto a rival right behind
   you), or the **total** of both (that charges no Power).

**The underdog.** Whoever is clearly last rolls an extra **gold die** on their turn:
move with any of the three, but the gold die never charges Power (and never makes
doubles). Clearly last means behind every other player by **8 tiles or more**, where
every treasure counts as a whole lap: banking a treasure and starting a new run from
the Start never makes you the underdog. The player list marks the underdog. A frozen
underdog still rolls just the one frozen die. **(digital)**

**Wanted.** From the end of round 2, whoever leads the race clearly (**4 tiles or more**
ahead of every rival, a treasure counting as a whole lap) gets a **Wanted poster**: a
price of **3 coins** on their head. It goes up by a coin at the end of every round they
stay clearly ahead, and with every rival they bonk or catch in a hidden trap (their
"crimes"). If someone else pulls clearly ahead, the poster moves to them at 3 coins.

- **Claim it** by bonking the Wanted (Cannonball and Stampede count) or catching them in
  your hidden trap: you get the coins and one random card from their hand (only the two
  of you see which). The poster comes down until the end of the round.
- At **8 coins** they're **Most Wanted**: every hidden trap of theirs is turned face up
  for everyone, and so is every trap they hide after that.
- **Getaway:** if the Wanted reaches the treasure with the poster still up, they cash it
  in themselves.

A private match's host can switch Wanted posters off. **(digital)**

You choose in any order, but moving ends your turn. Hovering a die (tapping it once on
a phone) shows on the board exactly where it takes you and what happens there: a
bonk, a token, a hazard, a trap you know about. **(digital)**

Instead of moving you may **Recall** to a Time Travel anchor you dropped earlier.

### Power

Each character has a **Power bar** as long as their ability costs (4 to 10). The die
you don't move with adds its pips, a trap you hid catching someone adds 2, and a
Regeneration card fills it. When it's full you may use your ability (once a turn); using it empties
the bar. Frozen players charge no Power.

### Landing

Whatever way you arrive on a tile (your move, a bonk, a Nudge, a conveyor...), you
deal with what's there, in this order:

1. **Hidden traps** of other teams go off (your own team's never catch you).
2. **Embers** from a Blast Off set you Burning.
3. A **board piece** works: Teleporter, Spore Warper, Shifting Sands, Conveyor Belt; a
   Wall crumbles if you land right on it.
4. **Bonk:** if you moved there yourself and rivals are standing there, each of them
   is knocked back 2 tiles and you bounce 1 forward. A Shield blocks a bonk. No bonks
   on the Start or between teammates, and a pushed player landing on someone doesn't
   bonk again. **(digital)**
5. **Tokens:** Trap, Assist and Board Piece tokens spin their wheel for a card (every
   wheel has a coin slot); a Potion Seller opens the shop, but only for the player
   whose turn it is.

### Your hand

You hold at most **5 cards**. A card you'd get with a full hand is lost.

### Timer and leaving

You have 45 seconds per turn (30 in the shop); practice games have no timer. If time
runs out your highest die is moved for you. Touch nothing for two of your turns and a
bot plays for you until you tap, click or press anything. If you leave, a bot takes
your seat. **(digital)**

## Hidden traps

Trap cards are **hidden**: only your team sees them (and the Overseer, and anyone who
drinks an X-Ray Potion). Rivals just see a puff of smoke next to you.

- Hide one on a free tile **within 5 tiles of you** along the race (the Trapper can
  hide them anywhere). Not on the Start, the Treasure, a token, a hazard, a gated
  shortcut or a board piece.
- You can have **3 out at once** (the Trapper 4). Hiding another removes your oldest.
- Several traps can hide on the same tile; a lander sets them off oldest first.
- When yours catches someone: **GOTCHA!** You get 1 coin and 2 Power.
- A **Shield** in the lander's hand blocks the trap (and is used up).
- Traps are used up when they go off.

| Card | Effect on whoever lands there |
| --- | --- |
| Spike | Knocked out: back to the Start. |
| Grog | Rolls a die: 1 to 3 and the Grog eats them (back to the Start). |
| Fire | Burning: hops back 1 tile at the start of their next 2 turns. |
| Ice | Frozen: their next 2 turns they roll one die, halved (rounded up), and charge no Power. |
| Snare | Caught: at the start of their next turn they roll a die, and on 1 to 3 they lose that turn. |
| Mudslide | Slides back 3 tiles. |
| Banana Peel | Slips back 2 tiles and drops a random card. |
| Wall | Not hidden: everyone sees it. Nobody gets past unless they move 5 or more; it crumbles once someone gets over it. |

## Assist cards

| Card | How it's played | Effect |
| --- | --- | --- |
| Speed Boost | Play before moving | The die you pick counts double. |
| Bounce Pad | Play before moving | Move 3 extra tiles. |
| Moonwalk | Play before moving | This turn you move backwards (along the way you came). |
| Lucky Clover | Play | Roll your dice again. |
| Compass | Play | Turn one of your dice to any number (not while Frozen). **(digital)** |
| Regeneration | Play | Fills your Power bar. |
| Shield | Works by itself | Blocks the next trap or bonk that would hit you. |
| Bridge | Works by itself | Carries you across one river. |
| Key | Works by itself | Opens one locked gate or gated shortcut. |
| Boots | Works by itself | Carries you through one slime pool. |
| Lantern | Works by itself | Shines one ghost out of your way, so it can't scare you. **(digital)** |
| Fire Cloak | Works by itself | Carries you across one lava stream, or keeps you safe from one eruption. **(digital)** |

The Assist wheel's counter-card slot gives the current map's counter card (Bridge,
Key, Boots, Lantern or Fire Cloak).

## Board pieces

Placed within 5 tiles of you, where everyone can see them.

| Card | Effect |
| --- | --- |
| Teleporter | At least 8 tiles from the Treasure. Teleporters link in pairs: landing on one sends you to its partner. |
| Spore Warper | Whoever lands here swaps places with the nearest other player (Warpers can't be swapped). Used once. |
| Conveyor Belt | A 3-tile belt facing forward or back; landing on it rides you off the end. Wears out after 3 rides. |
| Shifting Sands | Slides whoever lands here 3 tiles: forward in even rounds, backwards in odd rounds (the piece shows +3 or -3). Sinks after 3 slides. |

## Potions

The Potion Seller sells potions for coins and has 6 of each per match. You get coins
from treasures (2), gotchas (1) and the wheels' coin slots.

| Potion | Price | Effect |
| --- | --- | --- |
| Thief Potion | 2 | Steal a random card from a rival's hand (only the two of you see which). |
| Phoenix Potion | 2 | Works by itself: the next time you'd be knocked out, you survive instead. |
| X-Ray Potion | 2 | See every hidden trap on the board right now. |
| Telepathy Potion | 3 | Move any player 1 to 3 tiles forward or back. |
| Time Travel Potion | 4 | Drop an anchor where you stand; on any later turn you can Recall to it instead of moving. |
| Double Jeopardy | 5 | Swap hands with a player, push them back 6 tiles and jump forward 6 yourself. |

Playing a potion counts as your card for the turn.

## Hazards

Each map has its own hazard; the Naturalist walks straight through all of them.

| Map | Hazard | Without the counter card |
| --- | --- | --- |
| Blissful Tricks (36 tiles, 2 rivers) | River (counter: Bridge) | It stops you. |
| Junction Dungeon (46 tiles, 3 gates) | Locked gate (counter: Key) | It stops you. A Key also opens a gated shortcut, which you take automatically. |
| Slimy Snares (43 tiles, 3 pools) | Slime pool (counter: Boots) | It eats 5 of your steps; with 5 or fewer left you're stuck in it. **(digital)** |
| Haunted Hollow (40 tiles, 2 ghosts) | Ghost (counter: Lantern) | Walking into a ghost stops you: BOO! You run 1 tile back the way you came. At the end of every round each ghost drifts 2 tiles back along the trail (from the start it wraps round to just before the Treasure). **(digital)** |
| Mount Kaboom (42 tiles, 2 lava streams) | Lava stream (counter: Fire Cloak) | It stops you, like a river. The volcano erupts at the end of every 3rd round: anyone standing in a stream is set Burning and scrambles 2 tiles back (a Fire Cloak saves you). The board rumbles the round before. **(digital)** |

The counter card is used up when it carries you past (or saves you). The Naturalist
walks through every hazard, but an eruption still catches anyone standing in a stream
when it goes off. A Gambler's Double Down leaps over all of them.

## Characters

| Character | Passive | Ability (Power) |
| --- | --- | --- |
| Mage | **Frostproof:** can't be Frozen. | **Blizzard (7):** every rival is Frozen for their next turn, and you skate 1 tile ahead. |
| Trapper | **Bounty Hunter:** hides traps anywhere on the board and keeps up to 4 out; each time one catches someone, you hop 2 tiles forward. | **Scavenge (6):** pick one of two random trap cards. |
| Fire Starter | **Hot Hands:** your bonks set rivals on fire. Starts with a Fire card. | **Blast Off (10):** rocket 4 tiles forward; the tiles you fly over burn until your next turn. |
| Naturalist | **Wild Walker:** rivers, locked gates and slime never stop or slow you. | **Stampede (12):** charge 2 tiles forward with a herd of wild boars; every rival on those tiles (or where you land) is knocked back 2 tiles. **(digital)** |
| Warper | **Slippery:** can't be swapped by anyone else. | **Warp (10):** swap places with a player up to 7 tiles away. |
| Overseer | **All-Seeing:** sees every hidden trap. | **Nudge (4):** move any player, even yourself, 2 tiles forward or back. |
| Gambler | **Loaded Dice:** your dice never roll a 1. | **Double Down (17):** this turn your move counts double, and you leap right over rivers, gates, slime, ghosts and lava. **(digital)** |
| Cannoneer | **Broadside:** your bonks knock rivals back 3 tiles instead of 2. | **Cannonball (8):** fire yourself at the nearest rival up to 6 tiles ahead and bonk them; with nobody there you still fly 3 tiles. **(digital)** |

Mage, Trapper, Fire Starter and Naturalist are free. The others unlock with your
account level: Warper at 3, Overseer at 5, Gambler at 7, Cannoneer at 10. **(digital)**

## Modes

| Mode | Players | Teams |
| --- | --- | --- |
| Chaos Trapisque | 2 to 6 | Free-for-all |
| Blitz | 2 to 6 | Free-for-all: the first treasure wins, 30-second turns **(digital)** |
| Assist Trapisque | 4 | 2 vs 2 (pooled treasures) |
| Factions | 6 | Three teams of 2 (pooled) |
| Weekly Event | 2 to 6 | Free-for-all with this week's twist **(digital)** |
| World War Four | 6 | 3 vs 3 (pooled) |

Team modes: your traps never catch teammates, you can't bonk them, and you can give
a teammate a card (it counts as your card for the turn).

**Weekly events** rotate every week (Thursday 00:00 UTC):

| Event | Twist |
| --- | --- |
| Trap Frenzy | Everyone starts with two hidden traps, and traps can be hidden up to 10 tiles away. |
| Bonk Bonanza | Bonks knock rivals back 4 tiles. |
| Power Surge | Power charges twice as fast. |
| Triple Dice | Roll three dice and pick one; the best leftover charges Power. |

Bots fill empty seats in Quick Play when a human has waited long enough, and in
practice matches. Every Quick Play match opens with a 10-second vote between three
maps (the most votes wins; a tie or no votes picks one of the tied at random). In a
free-for-all Quick Play match, for its first 6 rounds and before anyone has found a
treasure, someone new in the queue can drop into a bot's seat (the one furthest
along) and play on from there.

## Outside the match (digital)

- **Mastery:** every match with a character earns them mastery XP (more for treasures,
  wins, bonks, gotchas and abilities). Levels 1 to 10 pay Gems; levels 3, 6 and 10
  give a title ("Mage Fan", "Mage Pro", "Mage Legend").
- **Daily quests:** three a day (for example "Bonk 5 rivals", "Catch 3 rivals with
  hidden traps", "Play a match as the Warper"), one free swap a day, Gems for each and
  a free Explorer Chest for finishing all three.
- **Login streak:** coming back on consecutive days pays 30, 40, 50, 60, 80, 100 and
  150 Gems, with a free chest on day 7, then the week starts over. Missing a day
  resets it.
- **Trophies and ranks:** Quick Play free-for-all matches move your trophies (the
  winner gains the most, last place loses a few, new players lose less). Ranks: Wood,
  Bronze (100), Silver (300), Gold (600), Diamond (1000), Legend (1600). There's a
  trophy leaderboard.
- **Mastery bases:** at mastery 5 a character gets their own base to stand on in
  matches (embers for the Fire Starter, a poker chip for the Gambler...), and it turns
  gold at mastery 10. They can't be bought.
- **Fishing between turns:** while someone else plays, cast the rod in the board's
  corner and tap fast when it bites. Catches fill your fish log; a coin catch (once a
  round at most) adds a coin for this match. It never changes anything else.
- **The guided first match:** a Blitz game on Blissful Tricks against gentle bots,
  with the Overseer explaining each part as it comes up. It's scripted so you win,
  pays 100 Gems the first time, and can be replayed from How to Play.
- **Badges:** 20 Roblox badges for moments in matches and around them (listed in the
  Collection, with your fish log).
- **Daily deals:** four cosmetics for Gems in the Shop, a new set every day (00:00 UTC).
- **The group:** joining the game's Roblox group pays 150 Gems, once.
- **Watching:** you can watch a friend's match; spectators see only what every player
  sees.
- Practice matches pay half rewards. Cosmetics (pawns, dice, trails, emotes, titles)
  never change how a match plays.

## Everything that differs from the board game

1. **Two dice, pick one.** You choose your move every turn and the other die charges
   Power, instead of rolling one die and moving.
2. **Power abilities.** Abilities cost Power instead of recharging on a timer, and
   several were reworked so each one helps the player using it (Blizzard, Blast Off,
   Stampede, Scavenge, the Trapper's bounty).
3. **Hidden traps** placed near you, with a cap, instead of open traps anywhere.
4. **One card per turn.**
5. **Bonks** when you land on a rival.
6. **Statuses last turns** (Frozen, Burning: 2 turns) instead of the rest of the cycle.
7. **Hazards stop you** (slime eats 5 steps) instead of each map's special rule, and
   Junction Dungeon has a third gate and no starting Spikes, so every map rewards the
   same things.
8. **Match lengths** (Quick 2 / Standard 3 / Classic 4) and pooled team treasures.
9. **Round cap** of 40 / 60 / 80 rounds.
10. **Coins:** start with 1, 2 per treasure, 1 per gotcha.
11. **Hand limit** of 5 cards; potions stock 6 of each.
12. **New cards:** Banana Peel, Lucky Clover, Compass, X-Ray Potion, Thief Potion.
    Removed: Mud. The Snare gives you a roll to break free instead of always costing
    the turn.
13. **Moving tokens:** a used token jumps to a random free tile.
14. **Timers, away bots and leavers** replaced by bots.
15. **Two more maps** (Haunted Hollow's drifting ghosts, Mount Kaboom's eruptions), two
    more characters (Gambler, Cannoneer) and Blitz (first treasure wins).
