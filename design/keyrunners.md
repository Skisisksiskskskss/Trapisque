# Keyrunners (working title)

A heist-crew strategy game for two players. Each crew has a **safe** and a
**key**, and your key opens the *other* crew's safe. Get your key to their safe
without losing it, and stop them from doing the same.

Playable demo: `demos/keyrunners/index.html`, with a bot at three levels and
pass-and-play on one phone.

## Decided with the designer

- A 7 wide by 10 tall board. One player starts at the bottom, the other at the top.
- Players alternate turns and spend one mana pool on deploying, moving and
  abilities. Mana can be saved, and you can go into debt that comes out of the
  next turn.
- Each player picks a leader, and the leader starts the match holding the key.
- Units capture chess-style by moving onto an enemy. Some units have special cases.
- Keys can be passed and thrown.
- A stolen key has to be carried home by the thief, so the owner can chase it
  and win it back.
- Opening a safe takes a turn, which gives the defender one turn to stop it.
- A deck of 6 crew and 2 gadgets, chosen before the match. You hold 3 crew and
  1 gadget, and you only get the next 4 cards once you've used all 4.
- You deploy on your 2 home rows, or next to certain crew. Your leader never
  counts.
- The theme is heist crews.

Everything below that isn't in that list is a design choice, tuned with
bot-vs-bot games.

## Board

- 10 rows. Each side's two home rows are **9 tiles wide**. The six rows between
  them are **7 wide**, so the floor is shaped like a capital I.
- Six **pits** sit in the middle, mirrored top to bottom and left to right: a
  two-tile crack down the center, (4,4) and (4,5), and four pits at (2,3), (6,3),
  (2,6) and (6,6). Units can't stand on or move through pits. Keys fly over
  them, so a throw can cross a gap that units have to walk around.
- A unit shoved into a pit falls and is out. A key it carried stays on the edge
  of the pit.
- Blue plays from the bottom (home rows 8 and 9), Red from the top (rows 0 and 1).
  Each safe sits in the middle of its owner's back row: Blue (4,9), Red (4,0).
- Each leader starts on the tile in front of its own safe, holding its own key.

```
   0 1 2 3 4 5 6 7 8
0  . . . . R . . . .    R: Red safe
1  . . . . . . . . .
2    . . . . . . .
3    . X . . . X .      X: pit
4    . . . X . . .
5    . . . X . . .
6    . X . . . X .
7    . . . . . . .
8  . . . . . . . . .
9  . . . . B . . . .    B: Blue safe
```
- Nobody may stand on their own safe. The only exceptions are a unit carrying the
  enemy's stolen key, and a unit capturing an enemy that is standing there.

## Mana

- Every turn gives +5 mana, including the first.
- Unspent mana is saved, up to 10.
- You can spend down to -3. The debt comes out of your next turn's mana.

| Action | Cost |
|---|---|
| Deploy a crew card | The card's cost (1 to 4) |
| Move a unit | 1 |
| Throw your key | 2 |
| Ability | As printed (1 to 3) |
| Gadget | As printed (1 to 4) |
| Discard a card | 1 |

At 5 mana a turn you usually take 4 or 5 actions, with real choices about where
they go. Mana doesn't decide how fast the key moves; the key rules below do. A
well-supported key moves about 3 or 4 tiles a turn, so it takes several turns to
cross the board.

## A turn

1. **Win check.** If one of your wins is set up (see Winning), you win now.
2. **Income.** You gain your mana.
3. **Act.** Do any of these, in any order, while you can pay:
   - **Deploy** a crew card onto an empty tile in your home rows, or next to one
     of your Lookouts or Getaway Drivers. At most 6 crew on the board. New crew
     can't move or use abilities until your next turn, but they can catch keys.
   - **Move** each unit once, in its own pattern. Moving onto an enemy captures it
     and takes any key it holds. Moving onto a dropped key picks it up.
   - **Throw** your key up to 3 tiles in a straight line, in any of 8 directions,
     right over pits. Any unit can throw. The first unit in its path catches it,
     friend or foe. If nobody does, it lands on the floor.
   - A short, safe **pass** to a neighbor is not a basic action. Only the Wobbler
     can do it, with its ability.
   - **Use an ability.** Each unit can use its ability once a turn.
   - **Play** your gadget, or **discard** a card you can't use.
4. **End turn.**

## Keys

- **Keys are heavy.** A unit carrying a key moves only 1 tile and can't use
  movement abilities. The Runner and the Ghost ignore this.
- **You can only pass or throw your own key**, and not on a turn it changed hands.
  A stolen key has to be walked home, so the owner gets time to chase it.
- A unit that catches a pass or throw can't move again that turn. The Catcher can.

## Winning

Both wins land at the start of your turn, so the other side always gets one
last turn to stop them.

- **Crack:** a unit of yours holding your key is on or next to their safe.
- **Stash:** a unit of yours holding their key is standing on your own safe.
- If round 30 ends with neither, it's a draw.

## Cards and hand

- Before the match, pick 1 leader (of 3), 6 crew (of 14) and 2 gadgets (of 6).
- You hold 3 crew and 1 gadget. You only get a new hand once all four are used,
  by playing or discarding them. The next hand is the other 3 crew and the other
  gadget, and after that the whole deck reshuffles. The screen always shows what's
  up next.
- Your opponent can't see your hand or your tripwires.

## Leaders (pick 1)

| Leader | Passive | Ability |
|---|---|---|
| The Boss | **Untouchable:** can't be captured while 2 or more of your crew stand next to it. | **Orders (2):** one of your crew that already moved this turn may move again. |
| The Fixer | **Connected:** you get +1 mana every turn. | **Inside Man (1):** this turn you may deploy next to any of your crew. |
| The Ghost | **Phantom:** moves up to 2 tiles in any direction, even carrying a key. | **Vanish (2):** swap places with one of your crew up to 3 tiles away. |

Leaders move 1 tile in any direction unless their passive says otherwise, and
they can be captured like any other unit.

## Crew (pick 6 of 14)

Crew move 1 tile in any direction unless their passive says otherwise.

| Crew | Cost | Passive | Ability |
|---|---|---|---|
| Wobbler | 1 | **Wobbly:** moves 1 tile in any direction. The basic crew member. | **Pass (1):** hand your key to a teammate right next to it. Nothing can intercept it. |
| Greaser | 2 | **Slick Moves:** moves any distance diagonally, like a chess bishop. One diagonal step while carrying a key. | **Slippery (1):** until your next turn, if anyone captures it, takes it out or grabs its key, the key flies to your nearest teammate instead. The board shows where it would go, so both players can plan around it. |
| Lookout | 1 | **Hideout:** you can deploy crew next to it. | **Dash (1):** run up to 3 tiles in a straight line. No captures, and not while carrying a key. |
| Decoy | 1 | **Bait:** whoever captures it is stunned on their next turn. | **Switch (1):** swap places with an ally up to 2 tiles away. |
| Runner | 2 | **Breakaway:** moves up to 3 tiles straight (no diagonals), even carrying a key. | **Juke (1):** step 1 tile left or right. |
| Catcher | 2 | **Soft Hands:** catches your throws that land next to it and steals enemy throws that fly next to it. Can still move after a catch. | **Call for It (1):** take the key from an ally up to 3 tiles away. |
| Pickpocket | 2 | **Nimble:** moves up to 2 tiles in any direction. | **Swipe (2):** take the key from an enemy next to it. |
| Acrobat | 2 | **Leaper:** moves in an L like a chess knight, jumping over anything. | **Vault (1):** jump over a unit next to it. An enemy jumped over is stunned. |
| Guard | 2 | **Watchful:** enemies carrying a key can't stop next to it. | **Brace (1):** can't be captured until your next turn. |
| Brute | 3 | **Armored:** survives the first time it would be captured or taken out. | **Shove (2):** push an enemy next to it 2 tiles away. If it hits something, it's stunned. |
| Sniper | 3 | **Scope:** can't capture by moving. | **Long Shot (3):** take out an enemy 2 or 3 tiles away in a clear straight line. Its key drops. |
| Bodyguard | 3 | **Shield:** your units next to it can't be captured. | **Rush In (1):** jump next to an ally up to 3 tiles away. |
| Hacker | 3 | **Firewall:** your units within 2 tiles ignore enemy gadgets. | **Glitch (2):** an enemy up to 3 tiles away loses its passive and can't use abilities until your next turn. |
| Getaway Driver | 4 | **Getaway Van:** moves up to 3 tiles straight. You can deploy crew next to it. | **Floor It (2):** after it moves, move it again. |

*Stunned* units can't move, use abilities, pass or throw on their next turn.

## Gadgets (pick 2 of 6)

| Gadget | Cost | Effect |
|---|---|---|
| Smoke Bomb | 2 | No one in a 3x3 area can be captured until your next turn. |
| Grappling Hook | 2 | One of your units zips up to 4 tiles in a straight line, even carrying a key or after moving. |
| Tripwire | 1 | Hide a trap on an empty tile outside the enemy's home rows. The first enemy to land there is taken out. |
| EMP | 2 | Stun every enemy in a 3x3 area. |
| Alarm | 1 | Push every enemy within 2 tiles of your safe 1 tile away from it. |
| Bribe | 4 | An enemy crew member next to your leader joins your side, with any key it holds. |

## Ready-made crews

| Crew | Leader | Crew cards | Gadgets |
|---|---|---|---|
| Runners | Ghost | Runner, Catcher, Wobbler, Acrobat, Greaser, Bodyguard | Grappling Hook, Smoke Bomb |
| Fortress | Boss | Guard, Brute, Bodyguard, Sniper, Wobbler, Catcher | Alarm, EMP |
| Tricksters | Fixer | Lookout, Getaway Driver, Hacker, Pickpocket, Greaser, Decoy | Tripwire, Bribe |
| All-rounders | Boss | Wobbler, Runner, Catcher, Guard, Sniper, Lookout | Smoke Bomb, EMP |

## What testing changed

Bot-vs-bot games caught five problems in the first draft:

1. **Parked safes.** Leaders started on their own safe, and defenders could park a
   tough unit there forever, so games stalled. Now nobody stands on their own
   safe, and leaders start one tile in front of it.
2. **Stealing was too strong.** A stolen key only had to reach the thief's back
   row, and it could be passed. Steals usually happen in midfield, so the thief
   passed it home in a turn or two and stashes won almost every game. Now a
   stolen key can't be passed or thrown, it has to be walked onto the thief's own
   safe, and the stash only counts if it survives one more turn.
3. **Cracks almost never happened.** Standing on the safe itself let defenders
   guard a single tile, and Hard-level bots cracked 0 safes in 10 games. Cracking
   from on or next to the safe brought that to about 4 in 10.
4. **Games ran long.** At 4 mana a turn, games took about 16 rounds. At 5 mana a
   turn, saving up to 10, they take about 12 to 15.
5. **Moving second was an advantage.** With Blue getting 4 mana on its first turn,
   Red won 60% of 48 even games. With 5 for both, Blue wins 48%.

After those changes, about 70% of bot games end in a stash and 25% in a crack. That fits
the idea that keeping your key safe is the heart of the game, but it's the
number to watch in human playtests. If cracks feel too rare, the next things to
try are a 4-tile throw, or letting a crack land even if the carrier is stunned
next to the safe.

## Second pass (designer's changes)

- The board became 9 wide at the ends and 7 wide in the middle, with mirrored pits
  that keys can be thrown over.
- Passing is no longer a basic action. Everyone can still throw, and the new
  Wobbler is the one unit that passes to a neighbor.
- New crew: the Wobbler and the Greaser. The Ghost's passive was renamed Phantom
  so "Slippery" only means the Greaser's ability.
- Units shoved into a pit fall and are out; their key stays on the edge.
- Every character is now drawn as a blocky, Roblox-style figure, with portraits
  on the cards.

With the new board, bots finish games in about 14 rounds. Normal beats Easy 10-0,
Hard beats Normal 10-5 (1 draw), and Blue wins 16 of 28 decided Normal games. The
bots rarely use the Wobbler's Pass or the Greaser's Slippery yet. Those cards
work for human players, but teaching the bot to set them up is still to do.

## Bot

The bot plans a whole turn by searching sequences of actions within its mana. It
scores each result by key progress, key safety (what the opponent could capture
or take next turn, including two-step threats like a dash and then a capture),
material and position. Hard also plays out your best reply to its top plans
before it commits. The bot never sees your hand or your tripwires.

| Matchup (final rules) | Games | Result |
|---|---|---|
| Normal vs Easy | 20 | 16 - 4 |
| Hard vs Normal | 52 | 34 - 15, 3 draws |
| Normal vs Normal, Blue vs Red | 48 | 22 - 24, 2 draws |

## Roblox notes

- The rules engine (`demos/src/keyrunners/logic.js`) has no UI code, so it ports
  to Luau almost line for line. Server-side, it would check every action a client
  sends, which also stops cheating.
- Hidden hands and tripwires need the server to send each player only their own
  cards and traps.
- A match is 12 to 15 rounds at about 30 to 60 seconds a turn, so roughly 10 to
  20 minutes. A turn timer would keep it moving.
