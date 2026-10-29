# Splotch: design

*Working title.* A Roblox paint battlegrounds game for about 20 players per server.

## Pitch

A free-for-all battlegrounds game where **paint is your weapon, your movement and your health**. Shoot paint and fling skills at people. Dive into your own paint to swim, heal and climb walls. Knock hurt players off the map. Every few minutes a storm (the Washout) rinses the whole arena and sends everyone running for cover.

It aims for the feel of Jujutsu Shenanigans (snappy controls, short dashes, readable hits, a moveset on 1/2/3), without hand-to-hand fighting-game combos. Attacks are paint shots, throws and paint-powered movement.

## Pillars

1. **Paint is everything.** It's territory, movement, healing and ammo at once. Every ability must create a way to move, interact with paint, or push people around. If it does none of these, it gets cut.
2. **Every hit feels great.** Damage numbers, white hit-flash, hitmarker and combo counter, screen shake, punchy sounds.
3. **Chaos with skill underneath.** Knockback grows as health drops, so ring-outs happen. Movement tech (dive, leap, wall-swim, dash, rocket-jump) separates good players from new ones.
4. **Drop in, drop out.** No rounds and no queue. You spawn, pick a character and play. The Washout gives each session a rhythm.

## What changed from the first idea, and why

| First idea | Now | Why |
| --- | --- | --- |
| Pure social sandbox, no goals | Battlegrounds free-for-all (KOs, streaks, kill feed) plus the Washout cycle | Goal-free sandboxes get 3-minute sessions. Battlegrounds is a proven Roblox loop |
| Smash-style knockback % ("Soak") | Normal HP bars, plus knockback that grows as HP drops | Battlegrounds players expect health bars. The scaling keeps the Slap Battles ring-outs |
| 20 colors fighting over territory | Personal colors. Enemy paint slows and hurts, your own heals. Paint fades and is capped per player | Keeps 20 colors readable and the server load bounded |
| Huge open world | One dense, vertical arena with ring-out edges | 20 players need to actually meet |
| Players build challenges | Deferred (a "race my ghost" flag idea is on the roadmap) | A level editor is a whole game by itself |
| Rain World inspiration | The Washout: a timed storm you shelter from | Gives shared moments and structure without rounds |

## Controls (PC)

| Input | Action |
| --- | --- |
| WASD / mouse | Move / aim (the mouse is always locked, like permanent shift lock) |
| M1 (hold) | Primary paint shot |
| 1, 2, 3 | Character skills |
| Q | Dash in the direction you're holding (~14 studs, 1.6s cooldown) |
| F (hold) | Block: 75% less damage and knockback from the front. Guard-breakers ignore it |
| Shift (hold) | Dive into your own paint |
| Space | Jump, or leap out of paint while diving |
| M | Character menu |
| Alt (hold) | Free the mouse cursor |
| H | Toggle the controls panel |

Every binding lives in `src/client/Keybinds.luau`.

## Paint rules

- Every player owns one color for the session.
- Paint lands on a 3-stud grid of cells on any paintable surface. It fades after 75s, and each player can have at most 650 cells at once, with the oldest disappearing first.
- **Your paint:** dive into it to swim fast (36 studs/s vs 18 walking), heal 22 HP/s, refill your tank 5x faster, and climb any wall it covers.
- **Enemy paint:** slows you to 10 studs/s and drains 6 HP/s. It can't take you below 30 HP on its own.
- **Paint tank:** 100. Shots and skills cost paint. It refills slowly on its own and fast while diving in your color.

## Combat rules

- HP is 100 (Tagger) or 125 (Plaster). Out-of-combat regen kicks in after 5s.
- Knockback is multiplied by `1 + missingHealth% x 1.3`, so a nearly dead player flies more than twice as far.
- Stun stops you from acting, and heavy hits ragdoll you (tumble physics) briefly.
- A KO is credited to whoever hit you last within 7s, even if the void, the rinse trench or the storm finished you off. The KO heals the killer 25.
- Hitting someone ends your spawn protection. Nobody can hit or be hit inside the spawn pavilion.

## Characters

### Tagger: fast, low damage, sets things up
- **M1 Quick Splat:** fast shots, 4 damage, small splats.
- **1 Streak:** dash ~25 studs while painting a lane. Anyone you pass gets knocked aside (10).
- **2 Stencil Trap:** lob a sticky trap. The first enemy to step on it is stuck for 0.5s, then popped into the air (6 + 8). Max 2 traps.
- **3 Burst Can:** lob a can that bursts into a huge splat (up to 22 damage, big knockback). Burst it at your own feet to rocket jump.

### Plaster: slow, sturdy, sends people flying
- **M1 Slosh:** slow heavy blobs, 10 damage, big splats.
- **1 Tidal Slam:** leap up, crash down. A 12-stud ring of paint launches everyone and breaks blocks.
- **2 Hook Line:** hook an enemy and yank them to you, or hook a surface and zip to it.
- **3 Drench Wave:** a cone of paint that soaks the ground and shoves enemies back.

All numbers live in `src/shared/Characters.luau` and `src/shared/Config.luau`.

## The map: The Gallery

A 240 x 240 stud island over the void (see `docs/map-preview.png`):

- **Central stage** with a spinning **sweeper** bar. Jump it or get launched.
- **Four towers** and a **sky bridge** for wall-swimming and high ground.
- **Gallery buildings**, walls and crates for cover.
- The **Rinse trench** on the west side is an instant KO, crossed by two bridges.
- **Bounce pads** for fast vertical routes.
- The **spawn pavilion** is a safe zone.
- **Four huts plus the pavilion** are Washout shelters.

## The Washout

Every 7 minutes: a 20s warning (the sky darkens, a horn, a countdown banner), then a 30s storm. The storm:
- wipes all paint, and keeps rinsing new paint within about 4s,
- pushes anyone outside a shelter around with gusty wind (good for ring-outs),
- drains 3 HP/s from anyone outside a shelter.

Shelters fill up, and fights break out inside them as people try to shove each other back into the storm.

## Feedback checklist

- Attacker: hitmarker (red on a KO), combo counter, a crisp confirm sound, an FOV punch on KOs, a "SPLASHED name" banner.
- Victim: a red vignette that scales with damage, screen shake, a hurt sound, ragdoll on heavy hits, and a STUNNED status.
- Everyone: damage numbers (white, then orange, then red as damage rises; blue when blocked), a white flash on the hit character, a paint burst in the attacker's color, 3D impact sounds, and a kill feed.

## Roadmap

**M1, playable core (this build).** Paint, swimming, wall-swim and leap, dash, block, HP and knockback, two characters, the HUD, hit feedback, the map, the Washout, and a synthesized sound pack.

**M2, battlegrounds depth.**
- Ultimates on G, charged by dealing damage (the JJS "awakening" equivalent).
- Two more characters.
- Custom animations (needs uploads).
- Combo-friendly stun tuning.
- Crews: up to 4 friends share a color and can't hit each other.

**M3, progression and retention.**
- Unlock characters through in-world feats (Slap Battles style), saved with DataStores.
- Badges, cosmetics (paint patterns, trails, splat shapes), and bounties on players with long streaks.

**M4, world events and polish.**
- Turf Bloom zones (paint to win).
- A paint-eating creature.
- Player-placed race flags.
- A second map.
- Mobile and gamepad controls.
