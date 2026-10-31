# JJS Skill Builder character codes — format reference

Reverse-engineered from 224 real exports (≈250,000 timeline nodes) plus the open-source `libjjs` library, which carries the in-game tooltip text for most fields. Current game version when written: **V1.84**.

## Encoding

```
code = base64( zstd( utf8( JSON ) ) )
```

- Every code starts with `KLUv/` (the zstd magic `28 B5 2F FD`).
- The game writes standard single-segment zstd frames (content size present, no checksum) and standard padded base64. Any conforming encoder works.
- The JSON is an **array of entries**. Each entry stores its timeline in a **JSON string** under `DATA` (JSON inside JSON).

## Entries

| `K_NAME` | Meaning | Extra fields |
|---|---|---|
| `SKILL` | a hotbar move | `KEY` (slot; 1–4 shown), `COOLDOWN`, `TOOL TIP`, `ADD` |
| `MELEE` | one M1 of the string; entries are used in order (4 entries = 4 hits) | — |
| `CHASE` | the front dash | `COOLDOWN` |
| `SPECIAL` | the R ability | `COOLDOWN` |
| `AWAKENING` | the G awakening; its Line runs once on activation | `DURATION` (s), `DELAY`, `COLOR` (gradient `"r,g,b r,g,b"`) |

`DATA` = `{"Line": [...], "Prop": {...} or [], "Req": [...], "Branch": {name: {"Req": [...], "Line": [...]}}}`.

### Prop (skill properties)

| Key | Meaning |
|---|---|
| `AWK` | hidden while awakened → a **base** move |
| `AWK2` | hidden while not awakened → an **awakening** move |
| `USE` | runs automatically when obtained (spawn/passives) |
| `USEONDEATH` | runs when the user dies |
| `NOSTUN` | other skills usable while it runs |
| `NOCANCEL` | taking damage does not cancel it |
| `INV` | invincible while active |
| `REP` / `REP2` | replace if slot occupied / prevent override |
| `KEEP` | kept when the moveset switches |
| `DMG`, `KNOCK` | damage / knockback multipliers (**strings**) |
| `VAR` | variant tag |

An empty Prop is written as `[]` (empty Lua table).

### Req (conditions — entry level, or per branch)

`{"K_NAME": X, "FLIP": bool}` with X in `AIR`, `JUMP` (holding jump), `AIM` (cursor on a player), `ULT` (awakened), `HOLD` (key still held), `DOMAIN`; plus `BAR` / `HP` with `AMOUNT` (≥ amount; FLIP = less than). `FLIP` inverts.

## Control flow

- Nodes run top to bottom; `WAIT` advances time; everything else fires immediately.
- A branch transfer is a **goto**: control leaves the current line for the branch's Line and does not return.
- `BRANCH` node: enters its branch **only if that branch's Req passes**, otherwise falls through. A chain `BRANCH down / BRANCH up / BRANCH normal` with Reqs `AIR` / `JUMP` / none is how M4 variants are dispatched.
- `HITBOX.BRANCH` — the **user** goes there on hit. `HITBOX.BRANCH TARGET` — the **hit target runs that branch** (knockback VELO, victim ANIMs, HPGIB damage, STATE stun, self-hitting HITBOX with `HIT USER` all execute on the victim). `BRANCH FINISHER` — on a kill.
- `HITCNCL` (hit cancel): `FLIP=true` → jump if nothing was hit in the last `TIME` s, `FLIP=false` → jump if something was. With a missing branch it just ends the skill with `ENDLAG` stun.
- `TAG` / `STATE` with `CHECK` jump to `BRANCH` when the check passes.
- `LOOP` replays the previous `LOOP BACK` nodes `LOOP AMOUNT` times.
- `LAST HIT = x > 0` on VELO / VISUAL / STATE / ANIM / TELEPORT / GRAB makes the node act on (or relative to) the target hit within the last x seconds. `-1` = off.

## Nodes (field → type; reference fields like `BRANCH` are omitted when unused, numbers/booleans are always written)

| Node | Fields |
|---|---|
| `WAIT` | `TIME` |
| `ANIM` | `ANIM_USE` `[character, clip]` or an emote name string; `PREVIEW` `[start, end]` = clip window played; `SPEED` (0 = freeze), `FADE IN`, `FADE OUT`, `LOOPED`, `LAST HIT` |
| `SFX` | `ID`, `VOLUME`, `SPEED`, `START`, `END`, `FADE IN`, `FADE OUT`, `CANCEL` (stop other sounds), `GLOBAL` (no falloff), `CLIENT SIDED`, `LAST HIT`, `PROJECTILE TAG` |
| `VISUAL` | `EFFECT`, `TIME`, `SIZE`, `ALT SIZE` (**multiplier**), `SIZE 2`/`ALT SIZE 2` (absolute per-axis, `-1,-1,-1` = off), `COLOR`/`ALT COLOR`, `OPACITY`/`ALT OPACITY` (transparency; for `Light` = brightness), `POSITION`/`ALT POSITION`, `ROTATION`/`ALT ROTATION`, `AMOUNT` (count/intensity; mesh id for `Mesh`), `TEXTURE`, `BODY PART`, `EASING STYLE`/`DIRECTION`, `RUN ON SERVER`, `CLIENT SIDED`, `CANCEL ON INTERRUPT`, `RELATIVE FROM BRANCH`, `CAN COLLIDE`, `LAST HIT`, `VISUAL TAG` (an `EFFECT: Cancel` node removes visuals with that tag), `PROJECTILE TAG` |
| `HITBOX` | `DAMAGE`, `SIZE`, `POSITION`, `ROTATION`, `STUN`, `STUN ANIM`, `IGNORE WAKEUP`, `DEBREE`, `ATTACK TYPE` (Melee/Bullet/Explosion/Swarm/Domain), `BLOCKABLE`, `360 BLOCK`, `CANCEL ENEMY`, `CLEAR KNOCKBACK`, `CAN KILL`, `HIT RAGDOLL`, `HIT USER`, `SINGLE TARGET`, `LINK USER` (V1.81), `BRANCH`, `BRANCH TARGET`, `BRANCH FINISHER`, `PROJECTILE TAG`, `PREVIEW` (always `[0, 15]`) |
| `PROJECTILE` | hitbox fields plus `SPEED`, `TIME`, `CONTINUE`, `FILTER INTERVAL`, `REFLECT COUNT`, `AIM LAST HIT`, `CACHE`, `CANCEL PROJECTILE`, `ID CHECK`, `BRANCH COLLIDED`, `SPAWN AT PROJECTILE TAG` |
| `VELO` | `FORCE` (local X right, Y up, Z forward), `TIME`, `FADE`, `TRACK`, `RAGDOLL` (s), `TRUE RAGDOLL`, `RELATIVE FROM BRANCH`, `LAST HIT` |
| `STATE` | `STATE`, `VALUE`, `TIME`, `CANCEL ON END`, `DISABLE BURST`, `LAST HIT`, `CHECK`, `BRANCH`, `STATE TAG` |
| `TAG` | `TAG`, `VALUE` (string; `<n`/`>n` for comparisons), `TIME` (lifetime after a change), `CHECK`, `SET`, `ADD/REMOVE`, `BRANCH`, `LAST HIT` |
| `BRANCH` | `BRANCH`, `RANDOM` (`"a, b, c"`), `LAST HIT` |
| `HITCNCL` | `TIME`, `FLIP`, `ENDLAG`, `BRANCH` |
| `LOOP` | `LOOP BACK`, `LOOP AMOUNT`, `HOLD` |
| `SKILL` / `SPECIAL` | run a built-in move (`MOVE` / `SPEC`), `SPEED`, `START`, `HOLD FOR`, `ENABLE VARIANTS`, `CANCEL LAST`; `MOVE: "Cancel"` stops one |
| `GRAB` | `BODY PART`, `BODY PART2`, `TIME`, `POSITION`, `ROTATION`, `LAST HIT` |
| `TELEPORT` | `POSITION`, `ROTATION`, `LAST HIT`, `PROJECTILE TAG`, `RELATIVE FROM BRANCH`, `IGNORE WALLS` |
| `COUNTER` | `TIME`, `STUN`, `ATTACK TYPE2` (comma list), `CANCEL ENEMY`, `REMOVE ON HIT`, `REFLECT`, `CONTINUE`, `BRANCH`, `BRANCH TARGET` |
| `LOOK` | `TIME`, `SMOOTHNESS`, `CAMERA DIRECTION`, `HORIZONTAL ONLY`, `GROUNDED`, `RELATIVE FROM BRANCH`, `LAST HIT`, `PROJECTILE TAG` |
| `SETMELEE` | `COMBO` (M1 counter), `OFFSET`, `LAST HIT` |
| `SETCD` | `KEY` (-1 = this move), `COOLDOWN` (-1 = default) |
| `HPGIB` / `ULTGIB` / `EVGIB` | `AMOUNT` (health / awakening / evasive), `CAN KILL` for HPGIB |
| `PARTICLE` | a full ParticleEmitter (`TEXTURE`, `RATE`, `EMIT COUNT`, sequences as strings) |
| `CONNECT` | `SIGNAL`, `TIME`, `RANGE` (Build Mode signals) |

Infinite numbers appear as `{"m": null, "t": "numeric", "v": "inf"}` (Roblox's JSON form of `math.huge`).

## Animations

`ANIM_USE: [c, i]` — `c` is the base character folder (1 Honored One, 2 Vessel, 3 Restless Gambler, 4 Ten Shadows, 5 Mahoraga, 6 Perfection, 7 Blood Manipulator, 8 Switcher, 9 Locust Guy, 10 Defense Attorney, 11 Star Rage, 12 Heian, 13 Cursed Partners, 14 Aspiring Mangaka, 15 Puppet Master, 16 Head of the Hei, 17 Salaryman, 18 Monkey Kid, 19 Lucky Coward, 20 Crow Charmer, 21 Disaster Plants, 22 True Cannon, 23 Black Death, later characters after), `i` the clip's index in that folder. `tools/data/anim_catalog.json` lists every pair seen in exports with clip length and the median impact frame (where creators put the first hitbox).

## Tolerances seen in real exports

The game accepts numeric strings for numbers, booleans for `DEBREE`, branch names that do not exist (the jump just does nothing / the HITCNCL just ends the move) and nodes with missing fields (defaults apply). The toolchain here is stricter on purpose.
