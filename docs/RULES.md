# Trapisque rules (Roblox edition)

These are the rules the game actually runs, in plain English. They come from the
original Trapisque description and the rulebook (`trapisquebooklet.html`). Where a
board-game rule had to be pinned down or changed for an online game, it is marked
**(digital)**, and every such change is listed at the end.

All the numbers live in `src/shared/Config.lua` (`Config.Rules`), and the rules
themselves are in `src/shared/Game/Engine.lua`. The test suite (`tests/`) checks them.

## The race

Each map is a path of hex tiles from the **Start** flag to the **Treasure** X.
Reaching the X banks a treasure and sends you back to the Start for another run
(a *cycle*). The first player, or the first team, with every treasure they need wins.

| Length | Treasures to win | Notes |
| --- | --- | --- |
| Quick | 2 | Quick Play always uses this length. **(digital)** |
| Standard | 3 | **(digital)** |
| Classic | 5 (4 in World War Four) | The full rulebook game. |

To stop a match from running forever, it ends on score after 50 / 75 / 120 rounds
(Quick / Standard / Classic), and the highest score wins. **(digital)**

## Setup

1. **Map.** Quick Play picks Blissful Tricks, Junction Dungeon or Slimy Snares at
   random. Practice and private matches let you choose.
2. **Characters.** Everyone gets a random character, and no two players share one.
3. **Tokens.** Every token spot gets a random token: Trap, Assist, Neutral or Potion
   Seller. Spots come every 3 tiles on Blissful Tricks and every 5 on Junction Dungeon
   and Slimy Snares. The mix is weighted (Trap 34, Assist 30, Neutral 22,
   Potion Seller 14), and every board has at least one Potion Seller. **(digital)**
   Tokens stay put for the whole match.
4. **Junction Dungeon** starts with two Spikes already set.
5. **Coins.** Everyone starts with 1 coin, so the Potion Seller is useful early.
   **(digital)**
6. **Turn order.** The Overseer always goes first. Everyone else is shuffled.
7. **Starting cards.** The Trapper starts with 2 random trap cards and the Fire Starter
   with 2 Fire cards.

## Your turn

On your turn you take **one main action**:

- **Roll** the die and move that many tiles, or
- **Play a card onto the board** (traps, Neutral cards, natural traps), or
- Use **Moonwalk**, a **Telepathy Potion** or **Double Jeopardy**, or
- **Recall** to your Time Travel anchor.

Before your main action you may also take any number of **free actions**:

- Use your character's **ability**, once per turn and only when it is charged.
- **Arm a boost** for this turn's roll: Speed Boost, Bounce Pad or Speed Potion.
- Play **Regeneration**.
- Drop a **Time Travel** anchor.
- **Give** a card to a teammate. Only a team player who has finished can do this.

**Landing on a token.** On a Trap, Assist or Neutral token you spin that token's wheel
and get the card it lands on. Every wheel also has a coin slot. On a Potion Seller
token the shop opens.

**Your hand.** You can hold at most 8 cards **(digital)**, and at most 5 copies of any
one card.

**Turn timer.** You have 35 seconds per turn (25 in the shop). **(digital)** If you time
out twice in a row, a bot plays for you until you do anything yourself. If you leave a
match, a bot takes your seat.

## Trap cards

Place one on any free tile to catch whoever lands there. You can't place it on the
Start, the Treasure, a token, a natural trap, a gated shortcut, or a tile that
already has something on it. A **Shield** in the victim's hand blocks the next trap
they trigger.

| Card | Effect |
| --- | --- |
| Spike | The lander dies and restarts their cycle from the Start. |
| Fire | The lander **burns** until their cycle ends. Trap penalties are doubled, assist cards are halved, and dying also costs a treasure (the rulebook's "repeat double the cycles"). |
| Ice | The lander is **frozen** until their cycle ends. Even rolls are halved and odd rolls lose 1. |
| Mudslide | The lander slides back 2 tiles. |
| Mud | The lander slips back 1 tile. |
| Wall | Nobody gets past unless they move 5 or more. Landing exactly on it is fine. It crumbles once someone gets over it. **(digital)** |
| Snare | The lander skips their next turn. |
| Grog | The lander must roll 4 or more, or the Grog eats them. |

Traps are used up when they trigger.

## Assist cards

| Card | Effect |
| --- | --- |
| Regeneration | Free: instantly recharges your character's ability. |
| Bounce Pad | Boost: move 2 extra tiles this turn. |
| Speed Boost | Boost: double this turn's move. |
| Bridge | Automatic: carries you across one river. |
| Key | Automatic: opens one locked gate or gated shortcut. |
| Boots | Automatic: the first time slime would slow you, you put them on and ignore slime for the rest of the cycle. |
| Shield | Automatic: blocks the next trap you trigger. |
| Moonwalk | Action: step back 1 to 3 tiles. You land there like a normal move. |

The Assist wheel's Bridge/Key/Boots slot gives the counter for the current map's
natural trap. The Naturalist gets that map's natural trap card instead.

## Neutral cards

| Card | Effect |
| --- | --- |
| Teleporter | Must go at least 8 tiles from the Treasure. Teleporters link in pairs, in the order they were placed, and landing on one sends you to its partner. They stay for the whole match. |
| Spore Warper | The lander swaps places with the nearest player. |
| Conveyor Belt | A 3-tile belt facing forward or back. Anyone who lands on it rides it off the end. It wears out after 3 rides. **(digital)** |
| Shifting Sands | On an even cycle the lander moves forward by the number of treasures they have. On an odd cycle they move back. It wears out after 2 uses. **(digital)** |

## Potions

The Potion Seller sells potions for coins and has 9 of each per match. You get coins
from the wheels' coin slots and 1 for every treasure you bank. **(digital)**

| Potion | Price | Effect |
| --- | --- | --- |
| Speed Potion | 1 | Boost: move 1 extra tile this turn. |
| Phoenix Potion | 2 | Automatic: the next time you would die, you survive instead. |
| Time Travel Potion | 3 | Free: drop an anchor where you stand. On a later turn, use your action to warp back to it. |
| Telepathy Potion | 4 | Action: move any player 1 to 3 tiles forward or back. |
| Double Jeopardy | 5 | Action: swap hands with a player, push them back 6 tiles and jump forward 6 yourself. |

## Natural traps

Each map has its own hazard, some built into the board and more placed by the
Naturalist. Only the Naturalist can place natural traps, and the Naturalist walks
through all of them.

| Map | Hazard | Without the counter |
| --- | --- | --- |
| Blissful Tricks | River (counter: Bridge) | You fall in and your move ends at the river. **(digital)** |
| Junction Dungeon | Locked gate and gated shortcuts (counter: Key) | You stop at the gate and are stuck until you roll 4 or more on a later turn. **(digital)** A gated shortcut only opens with a Key. |
| Slimy Snares | Slime (counter: Boots) | Moving through it halves your move (odd moves lose 1). |

## Characters

| Character | Passive | Ability (recharge) |
| --- | --- | --- |
| Mage | Immune to Ice and freezing. | **Hex:** freeze or burn any player until their cycle ends. Recharges every 2 cycles. |
| Trapper | Starts with 2 random trap cards. | **Scavenge:** spin the Trap wheel for a free card. Recharges every 2 cycles. |
| Fire Starter | Starts with 2 Fire cards. | **Ignite:** burn a player standing on your tile. Usable every turn. |
| Naturalist | Walks through rivers, gates, slime and gated shortcuts. Gets natural trap cards instead of Bridge/Key/Boots. Takes double penalties from trap cards. | None. |
| Warper | Immune to swaps. | **Warp:** swap places with any player. Once per game, but Regeneration restores it. |
| Overseer | Always takes the first turn. | **Nudge:** move any player (including yourself) 1 tile forward or back. Recharges every 2 rounds. |

In Quick games the Mage's and Trapper's abilities recharge every cycle instead of every
two, because there are only two cycles to play. **(digital)**

## Modes

| Mode | Players | Teams | Win |
| --- | --- | --- | --- |
| Chaos Trapisque | 2 to 6 | Free-for-all | First to the target. |
| Assist Trapisque | 4 | 2 vs 2 | Both teammates reach the target. |
| Factions | 6 | Three teams of 2 | Both teammates reach the target. |
| World War Four | 6 | 3 vs 3 | Every teammate reaches 4 in Classic (or the length's target if lower). |

**Finished teammates keep playing.** In team modes, once you have all your treasures
you stay in the game to help: you can give your cards to teammates and use your
ability on the other team. Your laps no longer count for anyone and earn nothing,
exactly as the rulebook says.

Bots fill empty seats in Quick Play if a human has waited 45 seconds **(digital)**, and
in practice matches.

## Everything that differs from the board game

1. **Match lengths.** Quick (2 treasures) and Standard (3) were added next to Classic.
   Quick Play uses Quick.
2. **Round cap.** Matches end on score after 50 / 75 / 120 rounds.
3. **Coins.** You start with 1 coin and earn 1 for every treasure, on top of the
   wheels' coin slots.
4. **Hand limit.** At most 8 cards in hand.
5. **Token mix.** Token types are weighted and every board has a Potion Seller.
6. **Slimy Snares** has a token every 5 tiles instead of every 6, to keep the smaller
   swamp lively.
7. **Rivers.** Without a Bridge you fall in and your move ends there. The rulebook
   doesn't say what a river does.
8. **Locked gates.** Without a Key you are held until you roll 4 or more on a later
   turn.
9. **Wear.** Walls crumble after one crossing, Conveyor Belts last 3 rides and Shifting
   Sands 2 uses. Teleporters are permanent, and other traps go after one trigger.
10. **Quick-game recharge.** In Quick games the Mage's and Trapper's abilities recharge
    every cycle.
11. **Timers and leavers.** Turns are timed, players who are away get a bot until they
    return, and leavers are replaced by bots.
12. **Teleporter distance** uses the rulebook's 8 tiles (the first description said 10).

Values that are listed in the code as **rulebook v1** (Trapper's 2 starting traps, the
Fire Starter's 2 Fire cards, abilities recharging every 2 cycles) follow the original
description, which is more detailed than the later booklet.
