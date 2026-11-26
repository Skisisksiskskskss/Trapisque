# Strategy game demos

Playable phone demos of the four highest-scoring pitches from
[`design/brainstorm.html`](../design/brainstorm.html), plus **Keyrunners**, the
designer's own heist game ([`design/keyrunners.md`](../design/keyrunners.md)).
Each demo is one self-contained HTML file: open it in a phone browser, with
nothing to install.

Every demo has:

- **Play vs bot** with Easy, Normal and Hard difficulty.
- **Pass & play** on one device, with cover screens wherever a player needs
  to hide information from the other.
- **How to play** inside the game.

## Ranking

Each pitch is scored out of 25 on four factors, for 100 in total.

- **Engagement:** "one more game" pull, tension, memorable moments, short sessions.
- **Creativity:** how fresh the hook is next to games that already exist.
- **Strategic depth:** thinking and planning, how high the skill ceiling goes, and whether you can learn from a loss.
- **Roblox & friends:** how well it plays with friends, fits Roblox players, reads on a phone and entertains people watching.

Ties are broken by strategic depth, since strategy was the first thing asked for.

| Rank | Pitch | Engagement | Creativity | Depth | Roblox & friends | Total |
|---:|---|---:|---:|---:|---:|---:|
| 1 | Leviathan Hunt | 22 | 17 | 21 | 24 | **84** |
| 2 | Liar's Gambit | 21 | 22 | 22 | 18 | **83** |
| 3 | Echoes | 18 | 24 | 24 | 13 | **79** |
| 4 | Second Guess | 20 | 16 | 22 | 19 | **77** |
| 5 | Last Lantern | 20 | 14 | 21 | 22 | 77 |
| 6 | Fusion Duel | 21 | 16 | 19 | 20 | 76 |
| 7 | Last Realm | 19 | 17 | 23 | 16 | 75 |
| 8 | Critical Mass | 22 | 15 | 18 | 20 | 75 |
| 9 | Checkmate FC | 20 | 13 | 19 | 19 | 71 |
| 10 | Shake On It | 17 | 16 | 18 | 17 | 68 |
| 11 | Lasso | 20 | 13 | 16 | 19 | 68 |
| 12 | Trapisque Reloaded | 18 | 15 | 17 | 17 | 67 |

The four built here are ranks 1 to 4.

## Play

| Game | Link | Single file |
|---|---|---|
| Leviathan Hunt | [claude.ai/artifact/UNK9xcCkVLyh2acUw6yUqw](https://claude.ai/artifact/UNK9xcCkVLyh2acUw6yUqw) | `demos/leviathan/index.html` |
| Liar's Gambit | [claude.ai/artifact/UMTHLFrnUeM9LP7QiaPFMy](https://claude.ai/artifact/UMTHLFrnUeM9LP7QiaPFMy) | `demos/liars/index.html` |
| Echoes | [claude.ai/artifact/83ejGkseT1t9j6Zn4shpLr](https://claude.ai/artifact/83ejGkseT1t9j6Zn4shpLr) | `demos/echoes/index.html` |
| Second Guess | [claude.ai/artifact/39PNs9nKTevbZZyzGUGCBP](https://claude.ai/artifact/39PNs9nKTevbZZyzGUGCBP) | `demos/second/index.html` |
| Keyrunners | [claude.ai/artifact/2P5yPWUcmA829PvyKFi84U](https://claude.ai/artifact/2P5yPWUcmA829PvyKFi84U) | `demos/keyrunners/index.html` |

The claude.ai links are private until shared from each page's Share menu.
Each `index.html` also works on its own, opened from any web host or straight
from the file.

## What each demo does

**Leviathan Hunt.** Gnasher the Leviathan hides in a random hex sea, and four
hunters have until dawn to harpoon it three times. The crew are Pip (sonar),
Captain Hask (harpoon whaler), Big Marta (nets) and Old Lumen (lighthouse beam),
drawn as blocky Roblox-style characters who talk as they work. There are no
mode buttons: tap a boat, then tap a dot to sail or a target to use its tool.
Undo takes back a sail that found nothing. You can play either side against the
bot, or both sides on one phone with cover screens. A red haze shows every tile
Gnasher could be on, worked out exactly from the clues so far. In bot-vs-bot
games the hunters win about 50% at Normal and at Hard.

**Liar's Gambit.** A 6x7 board where every piece is masked, any piece can move in
any pattern, and the pattern is its claim. Each player has 3 accusations, and a
wrong call costs one of them plus a piece. The bot keeps an exact probability
over every possible arrangement of your hidden pieces, estimates how often you
really bluff, and bluffs about 1 move in 10 itself. Hard beats Normal 57-33 and
Normal beats Easy 52-35.

**Echoes.** Five rounds of 6 ticks. You get a new hero each round, and every
earlier hero replays its moves as an echo. Echoes can't be struck, only blocked
into a paradox. Doors slam when their plate empties. A vault worth 3 sits behind
a door whose plate is in the contested middle row. The bot searches each round
and values its echoes by replaying future rounds. Hard beats Normal 6-2 and
Normal beats Easy 8-0.

**Second Guess.** Both players give secret orders to a Brute, Archer, Scout and
Mage. Moves resolve together, then attacks land on the squares they were aimed
at. First to 10 points from the control points wins. The bot samples plans
against likely enemy replies, and Hard also re-scores them against the replies
that would counter its best ideas. Hard beats Normal 19-11, Normal beats Easy
30-0, and the two colours split 30-29.

**Keyrunners.** The designer's own idea, filled in from two rounds of questions.
Each crew has a safe and a key, and the key opens the other crew's safe. Pick a
leader, 6 crew and 2 gadgets, then deploy, move and throw with 5 mana a turn.
The board is 9 wide at the ends and 7 in the middle, with pits you can throw
keys over. Wobblers pass to a neighbor, and a slippery Greaser flings the key to
the nearest teammate when it's attacked. Everyone is drawn as a blocky,
Roblox-style figure. Win by getting your key next to their safe, or by stealing
their key and walking it onto your own safe. Either win lands at the start of
your next turn, so the other side always gets one last chance. The bot searches
whole turns, watches for two-step threats on its key, and on Hard plays out your
best reply before it commits. The full rules, and what bot testing changed, are
in [`design/keyrunners.md`](../design/keyrunners.md).

## Tests

```
node demos/src/test/leviathan.sim.js 200           # bot-vs-bot balance + rule invariants
node demos/src/test/liars.sim.js 60 hard normal
node demos/src/test/echoes.sim.js 10
node demos/src/test/second.sim.js 30
node demos/src/test/keyrunners.sim.js 10 hard normal   # add CFG='{"throwRange":4}' to try rule changes
node demos/src/test/ui-smoke-keyrunners.js OUTDIR
node demos/src/test/ui-smoke-leviathan.js OUTDIR   # drives the built page in headless Chromium
python3 demos/src/build.py                         # rebuild every demos/<game>/index.html
```

## Layout

- `demos/<game>/index.html` is the built, playable game.
- `demos/src/kit/` holds the shared shell: menus, cover screens, sound and layout.
- `demos/src/<game>/` holds each game's sources. `logic.js` is the rules and
  bot with no DOM, so Node can test it. `ui.js` is the interface.
- `demos/src/build.py` inlines everything into the single-file games.
- `demos/src/test/` holds headless rule tests and bot-vs-bot balance runs.
