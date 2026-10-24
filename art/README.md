# The art

The board's playing pieces, the map props and landmarks, what the board shows on its
tiles, the characters' emblems, the cards' badges, the Kraken's frames, the dice, the
trails' particles, the fish, the fishing spot, the Treasure Chests and the marks a
piece wears (burning, frozen, Wanted, snared) are illustrations. They're drawn as SVG by the scripts in this folder and packed into image
sheets, which are uploaded to Roblox (see "How the game gets the art" below). The map vote's pictures of the maps (`maps/*.png`) are
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
| `dice.py` | every dice skin: the die without its pips (its face over the side facing you, in its material: ivory grain, ruby facets, jade veins, speckled bone, a neon rim, frost, brushed gold, a beaded doubloon, a cosmic nebula) and one carved pip, which the game puts on the face for each spot of the number |
| `trails.py` | the trails' particles, a few of each kind: dust puffs, bubbles, leaves, sparkles, embers, hearts, stars, rainbows, doubloons, seashells, parrot feathers, snowflakes, cherry blossoms, fireflies, music notes, ghost wisps, jewels, ink, thunder, confetti, paw prints and the Fish School's little fish |
| `fish.py` | every catch in the fish log, side on and head to the right (and the gold coin); the game draws one dark and see-through as the shadow under the bobber |
| `fishing.py` | the fishing spot: its pool, the rod, the bobber, a ripple and the splash of a bite |
| `chests.py` | the Treasure Chests, each as its box and its lid, so the reveal can send the lid flying |
| `marks.py` | what a piece wears when something's happened to it: a flame (Burning), a block of ice (Frozen), the Wanted poster (and the Most Wanted's gold one; the game writes on it) and Zzz (Snared) |

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

It needs Python 3 with `cairosvg`, Pillow, numpy and `zstandard`
(`pip install cairosvg pillow numpy zstandard`). It writes:

- `art/sheets/*.png`: the eleven sheets (up to 1024 x 1024 each), the files to upload:
  three each of scenery, pieces and icons, `extras_1` (the dice, the trails, the fishing
  spot, the chests and the marks) and `fish_1`. A group added later goes on sheets of its
  own, so the sheets already uploaded keep their uploads
- `art/contact.png`: every sprite at a glance, for review
- `src/client/UI/ArtAtlas.lua`: where each sprite sits in the sheets, and each sheet's
  version (a hash of what's on it, from the sprites' sources)
- `src/client/UI/ArtAssets.lua`: each sheet's uploaded image id and the version it was
  uploaded at (kept from run to run)
- `src/client/UI/ArtData/<sheet>.lua`: the pixels of each sheet that has no current
  upload, so the game can try to build it itself

The see-through pixels round each sprite take the colour of its edge (alpha bleeding),
so a sprite scaled down on screen fades into its own colours, not into a dark fringe.
When the art changes, only the sheets whose sprites changed get a new version; it lists
them as "to upload".

## How the game gets the art

**Upload the sheets.** That's what works in every game, on every device. The quickest
way, with nothing to rebuild:

1. Upload the files in `art/sheets/` that aren't uploaded yet (the art note names them)
   to Roblox, as **Decals** on create.roblox.com
   (Creations → Decals → Upload Asset; keep each file's name) or with Studio's Asset
   Manager import. Uploads go to whoever uploads them, so do it as the game's owner (or
   to the group, for a group's game).
2. Play the game (in Studio or live) as its owner. The lobby shows the art note: paste
   their ids into it, in any order (decal ids, image ids or their links all work),
   and press **Save ids**.

The server looks each id up, finds the image behind a decal, matches it to its sheet by
the name it was uploaded under (or else by the order the note lists them in), keeps them
in a DataStore for every server (`ArtService`), and the art loads straight away, for
everyone. (In Studio, DataStores need Game Settings → Security → Enable Studio Access to
API Services, or the ids last only until the game closes.)

Or write the ids into the place itself:

1. In Studio (with the place published), open the **Asset Manager** (the **Window**
   menu, or the **Home** tab), click its import button (**Bulk Import**) and pick the
   files in `art/sheets/`. They go to whoever owns the game, user or group.
2. Once they're through moderation, right-click each image and choose **Copy Asset ID**.
3. Write the ids in with `python3 tools/upload_art.py scenery_1=<id> scenery_2=<id> ...`
   (or put each in `src/client/UI/ArtAssets.lua` where its sheet says `id = 0`, leaving
   its version as it is), then build the place again.

Or let `tools/upload_art.py` upload them itself with Open Cloud: give it an API key
(Creator Hub → Open Cloud → API Keys, with the **Assets** API's Read and Write, made by
the user or group that owns the game) and whose they are:

```sh
ROBLOX_API_KEY=... ROBLOX_CREATOR=user:<user id> python3 tools/upload_art.py
```

(`group:<group id>` for a group's game.) It uploads only the sheets that have no current
upload and writes their ids into `ArtAssets.lua`. Either way, the pixels of the uploaded
sheets are dropped from the place, which makes it smaller and quicker to join.

An upload is used only while its version is the sheet's current one: when a sheet's art
changes, its sprites move, so it's drawn the other way (below) until it's uploaded
again. The other sheets keep their uploads.

**Without uploads**, the game builds each sheet itself from its pixels in `ArtData`, as
an `EditableImage`. Roblox only allows that once the owner (an age- and ID-verified
account) turns on **File → Experience Settings → Security → Allow Mesh / Image APIs**
(on the Creator Dashboard: the experience's **Configure → Settings → Enable Mesh / Image
APIs**), and phones have little memory for it.

**When an upload won't load** (Roblox refuses it in this game, or it's still being
moderated), the game draws that sheet from Roblox's own thumbnail of the upload
instead (`rbxthumb`, 420 pixels to the sheet's 1024, so a little softer), which loads in
any game.

When a sheet can't be had any of these ways, the game draws plainer stand-ins in code.
The Output says which sheets and why, and the owner (and anyone playing in Studio) gets
a note in the lobby saying the same, with how to fix it. Players never see the note.

The owner (and anyone playing in Studio) also sees a small tag in the lobby's top right
corner, with the version that's running and how many sheets loaded: `v1.2.0 · art 11/11`,
plus `(N as thumbnails)` when some came from their thumbnails. If the tag is missing,
or shows an older version, the game running isn't the latest place file.

## Previews offline

`tools/shots.sh boards crew` renders the maps and the pieces and emblems from the
sheet files, without Roblox, and so do the other screenshot scenarios.
