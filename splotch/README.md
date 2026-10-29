# Splotch (working title)

A Roblox **paint battlegrounds** game. Shoot paint and throw paint skills, dive into your own paint to swim, heal and climb walls, and knock hurt players off the map. Every few minutes a storm (the Washout) rinses the arena and everyone runs for cover.

The design (rules, characters, map, roadmap) is in [docs/DESIGN.md](docs/DESIGN.md).

## Play it in Roblox Studio

1. Install [Roblox Studio](https://create.roblox.com/) if you don't have it.
2. Download [`Splotch.rbxl`](Splotch.rbxl): open it on GitHub and click **Download raw file**.
3. Double-click the file to open it in Studio. The world looks empty in the editor: the map is built when the game starts.
4. Press **Play** (F5).

**To test with several players on one PC:** on the **Test** tab, under *Clients and Servers*, choose **2 Players** (or 3), then click **Start**. Each player gets their own window. Close the windows with **Cleanup** when you're done.

### Controls

| Key | Action |
| --- | --- |
| WASD / mouse | Move / aim |
| M1 (hold) | Paint shot |
| 1 2 3 | Skills |
| Q | Dash |
| F (hold) | Block |
| Shift (hold) | Dive into your own paint (fast, heals, refills, climbs painted walls) |
| Space | Jump, or leap out of paint |
| M | Pick character |
| Alt (hold) | Free the mouse |
| H | Show or hide controls |

**Try this first:** shoot a wall, hold Shift, and run into it. You'll swim up it. Press Space at the top to leap off.

### What to send back after playing

This build was written and checked outside Studio (linting, unit tests, API checks), but it has not been played yet. After a session, tell me:

- **Errors:** open **View > Output** and copy anything red.
- **Feel:** dash length, swim speed, how floaty the leaps are, camera sensitivity, how hard knockback hits.
- **Anything that looked or felt wrong:** for example, getting stuck on walls, the camera clipping, or hits that didn't register.

Every number is in `src/shared/Config.luau` and `src/shared/Characters.luau`, so tuning is quick.

## Sound effects

The game ships with an original sound pack in [`assets/sfx`](assets/sfx), synthesized by `tools/make_sfx.py` (no third-party audio). Roblox can only play audio that has been uploaded to Roblox, so until these are uploaded the game uses pitched built-in Roblox sounds as stand-ins.

To switch to the real pack, do one of these:

- **Easiest:** create an Open Cloud API key with asset upload permission and add it to this environment. I can then upload the sounds and wire them in.
- **By hand:** in Studio, open **View > Asset Manager > Bulk Import** and select every `.ogg` in `assets/sfx`. Then send me the IDs, or paste each one into `src/shared/SoundIds.luau` as `"rbxassetid://<id>"`.

## Publishing

In Studio: **File > Publish to Roblox**. No extra settings are needed: the game uses no HTTP requests or DataStores yet.

## Development

The code lives in this repo and is synced into Studio with [Rojo](https://rojo.space). `Splotch.rbxl` is a build of `src/`, rebuilt with every change.

| Command (run in `splotch/`) | What it does |
| --- | --- |
| `rojo build -o Splotch.rbxl` | Build the place file |
| `rojo serve` | Live-sync into Studio (needs the Rojo Studio plugin) |
| `stylua src tests tools` | Format |
| `selene src tests tools` | Lint |
| `lune run tests/run.luau` | Unit tests (paint grid, paint store, geometry) |
| `tools/fetch_api_dump.sh && python3 tools/check_api.py build/api-dump.json src` | Check every Roblox class, enum, property and method name against the real API |
| `lune run tools/dump-map.luau > build/map.json && python3 tools/render_map.py build/map.json docs/map-preview.png` | Render the map preview |
| `python3 tools/make_sfx.py assets/sfx` | Regenerate the sound pack |

CI (`.github/workflows/splotch.yml`) runs all of these checks on every push.

### Layout

```
src/shared/     ReplicatedStorage.Shared  config, characters, paint grid, remotes
src/server/     ServerScriptService       map, paint, combat, projectiles, kits, Washout
src/client/     StarterPlayerScripts      camera, movement, input, effects, HUD, menus
src/character/  StarterCharacterScripts   disables default health regen
tests/          Lune unit tests
tools/          API checker, map preview, sound generator
assets/sfx/     original sound pack (.ogg)
docs/           design doc and map preview
```

### How it fits together

- **The server is the authority** on paint, damage, cooldowns and projectiles. Clients send inputs through one `Action` remote. The server validates them (cooldowns, range, state) and broadcasts results.
- **Clients own their movement**, as on Roblox in general. That covers dives, wall-swims, dashes and ragdolls. They predict their own shots and cooldowns so input feels instant.
- **Paint** is a grid of cells on every paintable block face (`PaintGrid`). The server stores cell owners (`PaintStore`: cap plus fade), sends changes 10 times a second, and clients draw each cell as a thin slab (`PaintRenderer`).
- **Everything visual is built from plain parts, particles, trails and beams**, so the game needs no uploaded assets except the sounds.

## Known limitations of this build

- Characters use default Roblox animations. Custom attack animations need uploaded animation assets (planned for M2).
- PC controls only. Mobile and gamepad are on the roadmap.
- There's no saving yet (no unlocks or stats between sessions).
