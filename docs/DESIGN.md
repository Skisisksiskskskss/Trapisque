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

Visible tools stayed visible (Wall, Teleporter, Conveyor Belt, Shifting Sands, Spore
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
| Naturalist | Walked through everything incl. shortcuts | Ignores hazards; **Stampede** charges 2 tiles and knocks rivals in the way back 2 (12 Power) | Shortcut-walking was worth 11 to 17 tiles a lap on Junction. Stampede replaced Overgrow (growing hazards) because it was no fun to play: a charge you feel beats a puddle for someone else. |
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

**After** (v2 with backwards doubles, the underdog's gold die and the Naturalist's
Stampede; 600 games per map for 4-player Quick and 300 for the others, so about ±2.5
points is noise in the Quick table and ±3.5 in the rest):

| 4 players, Quick | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer |
| --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 27.0% | 22.7% | 21.5% | 25.4% | 28.2% | 25.1% |
| Junction Dungeon | 29.3% | 22.5% | 24.2% | 25.4% | 25.4% | 23.1% |
| Slimy Snares | 26.8% | 25.7% | 20.5% | 28.7% | 25.7% | 22.6% |

| 4 players, Standard | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer |
| --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 29.1% | 30.0% | 20.0% | 19.7% | 30.3% | 20.7% |
| Junction Dungeon | 26.6% | 30.0% | 25.0% | 19.7% | 20.7% | 27.8% |
| Slimy Snares | 28.1% | 29.1% | 20.5% | 23.2% | 22.7% | 26.3% |

| 2 players, Quick (fair 50%) | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer |
| --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 55.4% | 37.1% | 53.3% | 50.0% | 46.1% | 59.8% |
| Junction Dungeon | 50.5% | 49.5% | 49.5% | 42.9% | 48.0% | 60.9% |
| Slimy Snares | 51.5% | 44.8% | 50.5% | 56.1% | 45.1% | 52.9% |

| 6 players, Quick (fair 16.7%; all six play every game) | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer |
| --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 15.7% | 22.7% | 13.0% | 17.0% | 19.7% | 12.0% |
| Junction Dungeon | 18.3% | 21.7% | 13.7% | 14.7% | 17.3% | 14.3% |
| Slimy Snares | 15.3% | 21.3% | 15.7% | 14.3% | 20.7% | 12.7% |

Stampede was tuned on 4-player Quick. At 8 Power with a 3-tile charge it won 33 to
40%; 10 Power and a 2-tile charge brought it to 27 to 32%, and 12 Power with a 2-tile
charge (knocking rivals back 2) landed on 25 to 29%. It's a little behind in Standard,
where games are long enough for the cheaper abilities to come round more often.

The underdog's gap was tuned with these runs: at 6 tiles, the gold die also charged
Power and pushed the Overseer to 31% in 4-player games; as a move-only die with an
8-tile gap, every 4-player number stays within the noise of the v2 tables. Taking the
doubles total away (backwards only) was tried first and dropped the Naturalist to 13
to 17%, so doubles keep the total as a choice.

**With eight characters and five maps** (the Gambler, the Cannoneer, Haunted Hollow
and Mount Kaboom added; each game seats a random set of characters, so each one plays
about half the 4-player games). 4-player Quick, 1000 games per map, about ±4 points
is noise:

| 4 players, Quick | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer | Gambler | Cannoneer |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 20.7% | 22.4% | 26.6% | 27.0% | 29.2% | 21.2% | 26.4% | 26.6% |
| Junction Dungeon | 24.7% | 22.0% | 27.6% | 25.0% | 26.6% | 21.0% | 31.5% | 21.7% |
| Slimy Snares | 20.3% | 25.0% | 24.1% | 29.5% | 28.6% | 20.2% | 29.5% | 22.9% |
| Haunted Hollow | 27.4% | 21.4% | 22.5% | 28.7% | 24.6% | 22.6% | 29.1% | 23.7% |
| Mount Kaboom | 20.9% | 23.2% | 24.3% | 28.3% | 29.2% | 20.2% | 29.9% | 24.1% |

(This table is from after the card rework: Shifting Sands for the Trampoline, the
Snare's roll to break free, the Compass and the Thief Potion. The spread is the same
as before it, 20 to 32%; the Mage and the Overseer sit lowest and the Gambler highest,
worth watching. The 2- and 6-player tables below are from before the rework.)

2 players (500 games per map; each character plays about a quarter of them, so about
±9 points is noise) and 6 players (400 games per map, about ±4 points):

| 2 players, Quick (fair 50%) | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer | Gambler | Cannoneer |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 48.4% | 32.3% | 58.7% | 47.2% | 44.3% | 50.8% | 63.2% | 54.0% |
| Junction Dungeon | 51.6% | 41.7% | 57.1% | 50.4% | 37.4% | 44.3% | 62.4% | 53.2% |
| Slimy Snares | 59.5% | 43.3% | 50.8% | 48.8% | 37.4% | 49.2% | 57.1% | 52.4% |
| Haunted Hollow | 48.4% | 47.2% | 47.6% | 51.2% | 47.8% | 43.4% | 54.1% | 59.7% |
| Mount Kaboom | 46.0% | 46.5% | 50.0% | 59.8% | 41.7% | 54.1% | 47.4% | 54.0% |

| 6 players, Quick (fair 16.7%) | Mage | Trapper | Fire Starter | Naturalist | Warper | Overseer | Gambler | Cannoneer |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Blissful Tricks | 18.8% | 14.3% | 15.1% | 16.8% | 22.1% | 16.3% | 18.6% | 11.2% |
| Junction Dungeon | 14.5% | 13.6% | 14.8% | 16.5% | 23.8% | 16.3% | 18.3% | 15.6% |
| Slimy Snares | 13.9% | 16.3% | 15.8% | 19.8% | 23.2% | 10.3% | 22.9% | 11.2% |
| Haunted Hollow | 12.5% | 16.6% | 15.4% | 17.8% | 19.8% | 14.6% | 24.3% | 12.2% |
| Mount Kaboom | 14.5% | 18.3% | 15.8% | 18.8% | 19.1% | 13.0% | 18.6% | 15.3% |

How the new pieces were tuned:

- **Gambler.** Its first ability, High Roller, left it winning 5 to 13%. **Double
  Down** started as just a doubled move, which was strong where hazards are few and
  weak where they stop you; leaping every hazard on the way made it the same on every
  map, and 17 Power (the most of anyone) brought it into line. Loaded Dice (never a 1)
  stays modest because you still choose which die to move with.
- **Cannoneer.** Broadside (bonks push 3, not 2) plus **Cannonball** (fly up to 6 at
  the nearest rival and bonk them, or fly 3) for 8 Power. A move and a bonk in one, so
  it's useful whether you're behind or ahead. It's the weakest with 6 players (11 to
  16%), where bonks help the other four as much as you.
- **Haunted Hollow.** Ghosts drift 2 tiles back every round and scare you 1 tile back.
  More ghosts or a bigger scare handed the map to the Naturalist (who walks through
  them); 2 ghosts with a 1-tile scare keep everyone close.
- **Mount Kaboom.** Several designs were tried: a molten wall that only the Naturalist
  could cross (98% Naturalist), lava you wade through slowly, and finally two lava
  streams that stop you like rivers, with an eruption every third round that scorches
  anyone standing in one (Burning, 2 tiles back). The eruption is what stops the
  Naturalist from treating the streams as free: she can still be standing in one when
  it goes off.

**Still worth watching:**

- **2 players** stays the widest (38 to 61%): with one rival, the Trapper's hidden
  traps have one target who can often play around them, and the Overseer's vision
  matters most. Buffing the Trapper's bounty to 3 tiles barely helped with 2 players
  but pushed the Trapper to 31 to 43% with 4, so it stays.
- **Warper with 6 players** (20 to 24% vs 16.7%): with six on the board someone is
  always within 7 tiles ahead. Raising Warp to 11 Power helped there but made the
  Warper weak in 4-player Standard games (19 to 22%).
- **Gambler** sits at the top of most tables (and 62 to 63% with 2 players on the
  first two maps); if real games agree, Double Down's cost (`Config.Characters.gambler`)
  is the dial. The **Cannoneer** and the **Overseer** are the ones to lift for 6
  players.
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
| Character unlocks | Four characters free, four unlocked at levels 3, 5, 7 and 10: a reason to keep playing the first week, and fewer rules to learn at once. | Character picker |
| Mastery bases | The character's own base under them on the board at mastery 5, gold at 10. Not for sale, so it says "I know this one" to everyone in the match. | `UI/BaseArt`, `Meta/Progress` |
| Badges | 20 Roblox badges for funny or rare moments (Snake Eyes, getting scared by a ghost, the Golden Fish, playing with the owner), never for grinding. They show on players' Roblox profiles, which brings their friends. | `Meta/Badges`, Collection |
| Fishing | Something to do on other players' turns that never changes the match (one coin a round at most). Each map has its own waters (three local fish, a few shared), so the log is a reason to play every map; a shadow hints at the size, nibbles punish an early pull, rarer fish give less time to reel, and the log keeps your biggest of each. | `Meta/Fishing`, `Match/FishingRod` |
| Rematch | The results screen's Rematch: when everyone still at the table asks, the same players start again on the same map. A good table stays together instead of scattering back to the queue. | `Match:voteRematch`, `MatchService` |
| Daily deals | Four cosmetics for Gems, new every day, so there's always a reason to open the Shop. | `Meta/DailyShop`, Shop |
| The first match | A guided Blitz game with the Overseer as coach, scripted for a win. New players learn the dice, the cards and the Power bar by doing, in five minutes. | `Meta/Tutorial`, `Match/Coach` |

None of it touches fairness inside a match: mastery and trophies are cosmetic and
social, Gems buy cosmetics only.

## 5. One look: a calm tabletop

The comic look before this one read as machine-made: outlined lettering everywhere,
a tilted ribbon on every panel, thick ink and hard shadows, a rainbow of button
colours, a number on every tile, faces on objects. Every screen was loud in the same
way. The current look is the one a small studio would ship, with a few strict rules
so every screen comes out of the same kit:

- **One UI font** (Nunito), with Fredoka One only for the logo and the big moments.
  Sentence case everywhere: no outlined lettering, no all-caps.
- **Flat colours and light borders.** Cream panels with a thin warm border, white
  cards; a button's edge is a darker shade of its own face. No gradients, no glow,
  no hard shadows.
- **One accent.** Orange marks the main action on a screen (Find a match, Rematch).
  Secondary buttons are white with a border, green means done, red means danger.
- **Only the characters have faces.** Cards, tokens and hazards are plain objects in
  two tones at most, with a thin outline. Each character has **one colour**, and that
  colour is its player's everywhere: on the board, the player list, the feed.
- **Less on the board.** A handful of props per map, a number on every fifth tile
  only, no stray islets or decorative marks.
- **Playing pieces, not figures.** Each player is a piece shaped like a pawn, in their
  character's colour, with the character's emblem on top (the Mage's hat, the
  Trapper's trap, the Fire Starter's flame...). It reads from across the board the way
  a real board game's pieces do, and a mastery stand goes under it at mastery 5 (gold
  at 10). The pirates themselves stay on the cards, the portraits and the results.
- **Finishes instead of accessory packs:** what your piece is made of (oak, clay,
  pearl, marble, sea glass, porcelain, metallic, obsidian, solid gold, crystal,
  glowstone; Royal and Admiralty from the passes), always in your character's colour,
  so the board stays readable. Saves that owned packs got the finishes they became,
  and a second pack that became the same finish was paid back in Gems.

**The maps are places, not grids.** Each map's route is a hand-drawn winding curve
(`MapScenes`); the tiles are spaced evenly along it and the land grows around the
trail (`BoardLayout`), so the path runs through the environment: a tropical island
whose two rivers cross the trail exactly at its river tiles, a rocky sea fortress with
gate towers at its gates and secret tunnels for its shortcuts, and a swamp boardwalk
that spirals in to the treasure past bubbling slime pools. Props (palms, huts, ships,
cannons, mangroves) are placed clear of the trail. The board graph (tile count,
shortcuts, hazards) is the rulebook's, so none of this touches balance.

**Illustrations where shapes from code looked machine-made.** The pieces, the props
and landmarks, and the portraits used to be assembled at runtime from circles and
rectangles; up close they looked like it (a coastline of scalloped discs, a palm made
of three ellipses, flat green circles for jungle). They're now illustrations in one
style (smooth shapes lit from the upper left, outlines in a darker shade of each
part's colour, a soft shadow; `art/README.md`), drawn as SVG and uploaded as four image
sheets. The land, water, trail and tiles are still built from UI frames so they stay
sharp at any zoom, but the coast is smoothed: wherever two of the land's discs meet,
the corner is filled with a curve (`BoardLayout.fillets`, a morphological closing),
the little holes where three discs nearly meet are plugged, small lagoons are shallow
all over, and the jungle patches became groves of the map's own trees.
`tools/shots.sh` renders real screenshots offline for review.

**One point of view for everything on the board.** The props and pieces are drawn a
little from above and in front, so a perfectly flat map under them looked like a
sticker sheet. The map is now seen the same way: the land is a slab, with a cliff
under the edges that face you (darker at its foot), a waterline and foam where it
meets the sea, a lit lip along the edges that face the light, and soft lighter water
in the shallows round it; lagoons show their far bank. The trail and the rivers, lava
and slime are worn into the ground, so their far banks are in shadow. Tiles are stones
with a side, a bevel and a soft shadow, their faces worn (each turned its own way).
Soft patches of lighter and darker ground and a few small things (tufts, pebbles,
shells, leaves) keep the land from being one colour. Props sit in the ground with a
rounded foot instead of a flat, cut-off bottom, and every prop stands wholly inside
what the camera shows, so none is cut in half by the edge of the screen. The land's
disc copies that the ground hides completely are left out, so the richer map costs
no more UI objects than the flat one did.

**Portraits of people, not one face in eight hats.** The first illustrated portraits
shared a single front-on face with the costume changed. Each pirate now has their own
head, nose, eyes, brows and mouth, an expression (the Fire Starter's wink and grin,
the Trapper's squint and smirk, the Overseer's stern brow), a pose and something in
their hands (a match, a card, a cannonball, a parrot on the Naturalist's shoulder),
turned three-quarters and cel-shaded.

## 6. Talking at the table

A board game is loud. Players can't see each other here, and many can't use Roblox's
chat at all, so the game has its own:

- **Quick lines are free for everyone.** Six fixed lines ("Ahoy!", "Good luck!",
  "Nice move!", "Oops!", "Thanks!", "GG!") need no filtering, so anyone can use them
  whatever their settings. Six is enough to be friendly; anything more is what the
  Chat pass is for. Bots use them too (an "Oops!" when they're sent home, a "GG!" at
  the end), which keeps a table of bots from feeling dead.
- **Easy to reach.** A gold CHAT button in the lobby's top bar, the speech-bubble
  button in a match, and T on a keyboard everywhere.
- **Typing is the Chat pass** (10 Robux), and only for accounts whose Roblox settings
  allow chat. Every typed line is filtered for each reader and only reaches people
  who may chat with the speaker. Staff mutes stop typing but not quick lines.
- **Bubbles come from the players.** A line pops up over the speaker's character on
  the board, bigger than anything else on it, with their name on a tab in their
  colour; the character bobs as it talks, and the bubble stays on screen even when
  the speaker is off it. Emotes use the same bubbles. In the lobby, lines drop in
  under the chat button with the speaker's avatar.
- **Read out loud, with character.** Roblox's text-to-speech is used, but never plain:
  each voice is a base voice, a pitch, a pace and sometimes a light effect (a warm low
  growl, a squeaky high one, a flanged parrot, an echoing ghost, a clockwork shimmer),
  kept light enough that every word stays clear. Before a line is spoken it's made
  speakable (`Meta/Speech`): numbers become words ("12" twelve, "3rd" third, "2v2" two
  versus two), chat slang is said the way people say it ("gg" gee gee, "ez" ee zee,
  "brb" be right back) and faces like ":)" are dropped. Each character has a voice;
  the Voice Pack picks any. Text-to-speech is rate-limited, so
  quick lines load once per voice and replay, and a line that can't get a voice in
  time is babbled (one squeaky syllable per word, pitched by its vowels). In the lobby
  only your own and your party's lines speak, or a full lobby would be a racket.
- **Safe to be around.** Tap anyone's line to hide them (just for you), block them
  through Roblox's own block prompt, or report them. People you've blocked on Roblox
  never appear in the chat, bubbles included. A report carries that person's last
  few lines (filtered for everyone, never the raw text) to the staff panel on every
  server, and the thank-you points players at Roblox's own Report for anything serious.

The owner and admin panels exist so the game can be run without opening Studio:
moderation (mutes, kicks, timed bans, ending a stuck match) for admins, and gifts,
events, announcements and shutdowns for the owner. The server checks every action
again, and every action is logged.
