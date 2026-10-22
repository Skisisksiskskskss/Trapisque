# The art

The board's playing pieces, the map props and landmarks, and the eight character
portraits are illustrations. They're drawn as SVG by the scripts in this folder and
packed into four image sheets, which the game builds itself from data shipped in the
place (or loads from Roblox, once you upload them):

| File | What it draws |
| --- | --- |
| `pieces.py` | the playing pieces (every character in every finish), and the mastery stands |
| `props.py` | everything that stands around the trail on the five maps, and the landmarks |
| `portraits.py` | the eight pirates, head and shoulders |

Everything else (the land, the water, the trail, the tiles, cards, icons, the UI) is
still built from UI frames in code, so it stays sharp at any zoom.

## One style

- smooth shapes, lit from the upper left (each shape's fill runs light to dark)
- a thin outline in a darker shade of each part's own colour, never black
- a soft shadow on the ground under things that stand; foam or ripples where something
  meets the water
- no faces on objects; only the pirates have them
- as little detail as reads at the size it's shown: a prop is often 50 to 100 pixels
  tall on screen

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

`tools/shots.sh boards crew` renders the maps and the pieces and portraits from the
sheet files, without Roblox, and so do the other screenshot scenarios.
