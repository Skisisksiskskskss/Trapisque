# The art

The board's playing pieces, the map props and landmarks, what the board shows on its
tiles, the characters' emblems, the cards' badges and the Kraken's frames are
illustrations. They're drawn as SVG by the scripts in this folder and packed into image
sheets, which the game builds itself from data shipped in the place (or loads from
Roblox, once you upload them). The map vote's pictures of the maps (`maps/*.png`) are
the game's own boards, rendered offline (`tools/shots.sh thumbs`) and packed with the
rest:

| File | What it draws |
| --- | --- |
| `pieces.py` | the playing pieces (every character in every finish), and the mastery stands |
| `props.py` | everything that stands around the trail on the eight maps, and the landmarks |
| `ground.py` | what lies on the ground: the soft spot used for the shallows, patches and shadows, tufts, pebbles, shells, flowers, leaves, swells on the sea, and the worn faces of the tile stones |
| `items.py` | what stands on a tile, as the thing itself: a banana peel, spikes, a Grog in its hole, a campfire, a snare, a wall, a locked gate, a mushroom, the treasure chest, the start flag |
| `tiles.py` | what a tile turns into when something covers it, in both tile shapes (`_round` stones, `_square` slabs), drawn bigger than the tile and cut to its outline: ice, thin ice (cracked, given way), mud, water, lava, slime, sand, a portal, embers, a conveyor's rubber, brass cogs, a drawbridge's planks and the canal under it (the board lays a conveyor's ridges and the sands' ripples on top, moving). And what stands across the trail turned to face it: a wall and a gate in seven turns, and a raised drawbridge leaf leaning sixteen ways |
| `badge.py` | the emblem style the next two share: a round badge (rim, ring, field) and a bold symbol, outlined thick, cut darker along its lower right, a soft shadow |
| `emblems.py` | the characters' emblems: a classic one each (a cream symbol on a field of their colour), a Ghost Crew one (another symbol, glowing mint on a dark field, a wispy rim) and a Gilded one (another symbol in gold, a sunburst rim and a gem) |
| `cards.py` | every card's badge (its symbol in its own colours on a cream field, the rim in its category's colour) and the board's tokens (the kind's symbol in cream on its colour) |
| `kraken.py` | the Kraken of Kraken's Reach as frames: its arm rising out of the water, swaying, rearing, arching and slamming eight ways round on the ground; its lair's turning white water, its head (ahead, left, right, blinking, angry) and the arms that loop out of the water round it |

The shapes of the land, the water, the trail and the tiles are still built in code
(`MapArt`, `BoardView`) from plain shapes (`ground.py`'s white disc and rounded square,
stretched and tinted), so they stay sharp at any zoom. The board is seen a little from
the side, the way the props and pieces are drawn: the ground is squashed top to bottom
(`BoardLayout.Style.squash`), so a round tile is an ellipse, and what stands on it
stands straight up, its foot on its spot. The land is a slab with a cliff under the
edges that face you, foam at the waterline and a lit lip along the edges that face the
light; the trail is worn into it; rivers, lava streams and slime pools are cut into it
like the coast (a low bank in the land's own cliff colours along the far side, foam or
a dark crust at the water, the near side's lit lip), and a river that reaches the cliff
pours off it. The tiles are low stones with a short side, a bevel and a shadow.

What's on a tile sits on it like a prop: a standing thing's foot is at (50, 80) of its
canvas, put on the tile's middle; a cover is drawn from straight above and squashed onto
the tile's top. A hidden trap shows only to whoever may see it (its owner, a teammate,
X-Ray), see-through and ringed in its owner's colour; for everyone else the tile is
untouched.

## One style

- smooth shapes, lit from the upper left (each shape's fill runs light to dark)
- a thin outline in a darker shade of each part's own colour, never black
- things that stand on the ground sit in it: a rounded foot and a shadow, never a flat
  cut-off bottom
- a soft shadow on the ground under things that stand; foam or ripples where something
  meets the water
- no faces on objects (only the Kraken and the Grog, which are creatures)
- as little detail as reads at the size it's shown: a prop is often 50 to 100 pixels
  tall on screen

The emblems and the cards' badges are bolder: a symbol in two or three flat colours,
outlined thick in one dark ink, with a darker cut along its lower right edge and a soft
shadow on the badge, so it reads at 24 pixels on a chip as well as at 200 on a card.
The characters have no faces: each emblem is a symbol of theirs, never their head.

## Building the sheets

```sh
python3 tools/art.py
```

It needs Python 3 with `cairosvg`, Pillow and `zstandard`
(`pip install cairosvg pillow zstandard`). It writes:

- `art/sheets/*.png`: the four sheets (1024 x 1024 each)
- `art/contact.png`: every sprite at a glance, for review
- `src/client/UI/ArtAtlas.lua`: where each sprite sits in the sheets
- `src/client/UI/ArtAssets.lua`: one line per sheet for an uploaded image id (ids
  already filled in are kept)
- `src/client/UI/ArtData/<sheet>.lua`: the pixels of each sheet that has no id, so
  the game can build it itself

## How the game gets the art

Nothing has to be uploaded. When the game starts, it builds each sheet from its pixels
in `ArtData` as an `EditableImage`:

- **In Studio** this just works: press Play.
- **In a published game** Roblox blocks `EditableImage` until the owner turns it on:
  in Studio, **File → Experience Settings → Security → Allow Mesh / Image APIs** (or
  on the Creator Dashboard: the experience's **Configure → Settings → Enable Mesh /
  Image APIs**). Roblox asks for an age- and ID-verified account for that.

If the images can't be built (that setting is off, or a phone is short of memory), the
game draws plainer stand-ins and says why in the Output window.

**Or upload the sheets** (works everywhere, with no setting to turn on):

1. Open the place in Studio and open **View → Asset Manager**.
2. Click **Bulk Import** and pick the four files in `art/sheets/`
   (`scenery_1.png`, `scenery_2.png`, `pieces_1.png`, `pieces_2.png`).
3. In the Asset Manager's **Images** folder, right-click each one and choose
   **Copy Asset ID**.
4. Put each id next to its sheet's name in `src/client/UI/ArtAssets.lua`, for example
   `pieces_1 = 1234567890,`, then run `tools/art.py` again: it drops the pixels of the
   uploaded sheets from the place, since they're no longer needed. Edits made only in
   Studio are overwritten by the next place file built from the repository.

Uploaded sheets are used first. Upload them again after the art changes: the sprites
move around the sheets, so the old ids no longer fit.

## Previews offline

`tools/shots.sh boards crew` renders the maps and the pieces and emblems from the
sheet files, without Roblox, and so do the other screenshot scenarios.
