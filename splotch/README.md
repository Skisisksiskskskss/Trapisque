# Splotch (working title)

A Roblox **paint battlegrounds** game that plays like Jujutsu Shenanigans. It uses R6 characters, a 4-hit M1 chain, short dashes, block, ragdolls and evasives. You fight with a paint brush or a paint roller instead of fists, and the paint matters: dive into your own color to swim, heal and climb walls. Knock hurt players off the island. Every few minutes a storm (the Washout) rinses the map.

The design (rules, characters, map, roadmap) is in [docs/DESIGN.md](docs/DESIGN.md).

## Play it in Roblox Studio

1. Install [Roblox Studio](https://create.roblox.com/) if you don't have it.
2. Download [`Splotch.rbxl`](Splotch.rbxl) (on GitHub: open it and click **Download raw file**).
3. Double-click it to open it in Studio. The world looks empty in the editor: the map is built when the game starts.
4. Press **Play** (F5). Pick a character, then walk out of the spawn gallery to the right, to the **Practice Yard**. One training dummy stands still and one always blocks.

**To test with several players on one PC:** go to the **Test** tab, choose **2 Players** under *Clients and Servers*, and click **Start**.

### Controls (all rebindable in Settings, P)

| Key | Action |
| --- | --- |
| WASD | Move. Double-tap **W** to run, or turn on Auto Run |
| Left Shift | Shift lock (Roblox's own, like JJS) |
| M1 | Attack chain (hold to keep swinging). The 4th hit: jump = uppercut, falling = downslam |
| 1 2 3 4 | Skills |
| Q | Dash: forward (with a jab), or hold A / D / S to side-step. While ragdolled or stunned with a full blue bar: **evasive** |
| F (hold) | Block (front only) |
| R (hold) | Dive into your own paint: swim, heal, climb painted walls. Space leaps out |
| G | Awaken (when the gold bar is full) |
| Space | Jump. Near a wall in the air: wall jump |
| P / M | Settings / pick character |

**Try this first:**
- Swing at a wall a few times to paint it.
- Hold **R** and run into the wall to climb it.
- Press **Space** at the top to leap off.

### What to send back after playing

This build was written and checked outside Studio (linting, unit tests, a Roblox API check, offline renders of the map, poses and paint), but it has not been played yet. After a session, tell me:

- **Errors:** open **View > Output** and copy anything red.
- **Feel:** M1 speed, dash distance, run speed, ragdoll length, knockback, camera.
- **Anything that looked wrong:** an animation, the map, the UI.

The numbers live in `src/shared/Config.luau` and `src/shared/Characters.luau`, and the animations in `src/shared/Animations.luau`, so tuning is quick.

## Sound effects

The game has an original sound pack in [`assets/sfx`](assets/sfx): 26 sounds, synthesized by `tools/make_sfx.py`, no third-party audio. Roblox only plays audio uploaded to Roblox, so until these are uploaded the game uses pitched built-in Roblox sounds as stand-ins. To switch to the pack, do one of these:

- Add an Open Cloud API key with asset upload permission to this environment, and I'll upload and wire them.
- Bulk-import `assets/sfx` in Studio (**View > Asset Manager > Bulk Import**), then send me the IDs (or paste them into `src/shared/SoundIds.luau`).

## Publishing

In Studio: **File > Publish to Roblox**. Settings and keybinds save to a DataStore, which only works in a published game. To use DataStores while testing in Studio, turn on **Game Settings > Security > Enable Studio Access to API Services**.

## Development

The code lives in this repo and is synced into Studio with [Rojo](https://rojo.space). `Splotch.rbxl` is a build of `src/`.

| Command (run in `splotch/`) | What it does |
| --- | --- |
| `rojo build -o Splotch.rbxl` | Build the place file |
| `rojo serve` | Live-sync into Studio (needs the Rojo Studio plugin) |
| `stylua src tests tools` / `selene src tests tools` | Format / lint |
| `lune run tests/run.luau` | Unit tests (paint grid, paint store, geometry, animations) |
| `tools/fetch_api_dump.sh && python3 tools/check_api.py build/api-dump.json src` | Check every Roblox class, enum, property and method name against the real API |
| `lune run tools/dump-map.luau > build/map.json && python3 tools/render_map.py build/map.json docs/map-preview.png` | Render the map preview |
| `lune run tools/dump-poses.luau > build/poses.json && python3 tools/render_poses.py build/poses.json build/poses.png` | Render every animation keyframe (front / side / top) |
| `lune run tools/dump-paint.luau > build/paint.json && python3 tools/render_paint.py build/paint.json build/paint.png` | Render how paint splats look |
| `python3 tools/make_sfx.py assets/sfx` | Regenerate the sound pack |

CI (`.github/workflows/splotch.yml`) runs the checks on every push.

### Layout

```
src/shared/   ReplicatedStorage.Shared   config, characters, animations, paint grid, remotes
src/server/   ServerScriptService        R6 spawning, ragdolls, combat, kits, paint, map, dummies, Washout, settings
src/client/   StarterPlayerScripts       animator, movement, combat input, effects, HUD, menus, settings
tests/        Lune unit tests
tools/        API checker, map / pose / paint renderers, sound generator
assets/sfx/   original sound pack (.ogg)
docs/         design doc and map preview
```

### How it fits together

- **Characters are always R6.** The server spawns everyone itself (CharacterAutoLoads is off), building an R6 rig from each player's own avatar. That gives JJS's look without needing a game setting.
- **Animation is procedural.** `client/Animator` drives the six R6 joints every frame for every character. Locomotion comes from velocity, then stances, then action clips from `shared/Animations`. No animation uploads are needed. Your own actions play instantly; other players' arrive as events.
- **Ragdolls are real physics.** The server swaps the limb Motor6Ds for ball sockets, so everyone sees the same ragdoll. The ragdolled player's client switches its humanoid to physics and applies the launch.
- **The server is the authority** on damage, cooldowns, meters and paint. Clients predict their own movement, animations and M1 hitboxes (so hits match what you see), and the server validates every report.
- **Paint** is a grid of cells on every paintable block face. The server stores the owners. Clients draw round splats that merge into blobs, with square cells at part edges so paint never overhangs.

## Known limitations of this build

- PC controls only. Mobile and gamepad are on the roadmap.
- No saving of progress yet (settings and keybinds do save).
