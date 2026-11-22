# Strategy game demos

Playable phone demos of the four highest-scoring pitches from
[`design/brainstorm.html`](../design/brainstorm.html). Each demo is one
self-contained HTML file: open it in a phone browser, with nothing to install.

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

## Layout

- `demos/<game>/index.html` is the built, playable game.
- `demos/src/kit/` holds the shared shell: menus, cover screens, sound and layout.
- `demos/src/<game>/` holds each game's sources. `logic.js` is the rules and
  bot with no DOM, so Node can test it. `ui.js` is the interface.
- `demos/src/build.py` inlines everything into the single-file games.
- `demos/src/test/` holds headless rule tests and bot-vs-bot balance runs.
