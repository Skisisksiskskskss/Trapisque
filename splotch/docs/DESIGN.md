# Splotch: design

*Working title.* A Roblox paint battlegrounds game for about 20 players per server.

## Pitch

A free-for-all battlegrounds game that **plays like Jujutsu Shenanigans**, with R6 characters, a 4-hit M1 chain, short dashes, block, ragdolls and evasives. You fight with **paint tools instead of fists**, and **paint is movement and healing**: every swing paints what it hits, and you can dive into your own color to swim, heal and climb walls. Knock hurt players off the island. Every few minutes a storm (the Washout) rinses the whole map and sends everyone running for cover.

## Pillars

1. **Feels like JJS.** The M1 chain, dash types, block, ragdolls, evasive bar, awakening, running and wall jumps follow the JJS wiki's documented rules (see *Sources*).
2. **Paint is the identity.** Swings paint surfaces, your paint is a highway and a heal, enemy paint slows and hurts. Every skill must create a way to move, interact with paint, or push people around.
3. **Every hit reads.** Hit flash, hit reaction animation, weapon trails, colored impact bursts, damage numbers, the combo damage counter, screen shake, impact frames on KOs, and distinct sounds.
4. **Drop in, drop out.** No rounds. Spawn, pick a character, practise on dummies, fight. The Washout gives each session a rhythm.

## Controls (PC, rebindable in Settings)

| Input | Action |
| --- | --- |
| WASD | Move. Double-tap W to run (or Auto Run) |
| Left Shift | Shift lock (Roblox's own, as in JJS) |
| M1 | 4-hit chain. Hold to keep swinging |
| 1-4 | Skills |
| Q | Front dash, or side / back step while holding A / D / S. Evasive when ragdolled or stunned with a full bar |
| F (hold) | Block |
| R (hold) | Dive into your paint |
| G | Awaken |
| Space | Jump. Wall jump in the air next to a wall. Leap out of paint |
| P / M | Settings / characters |

## Combat rules

Numbers in parentheses are what the JJS wiki documents; Splotch uses the same.

- **M1 chain:** 4 hits doing 3 / 3 / 4 / 4 damage (14 total). The hit lands about 0.2s after the swing starts, using an 8×8×8 hitbox in front of you.
  - A landed M1 stuns for 0.75s and pulls the attacker 1 stud forward.
  - A blocked M1 adds extra endlag.
  - After the 4th hit the chain has a short downtime.
- **4th hit variants:**
  - **Neutral** knocks the target back and ragdolls them.
  - **Uppercut** (jumping, or holding jump) launches them up for a longer ragdoll.
  - **Downslam** (falling after a jump) slams them down, can't be blocked, and hits even someone already ragdolled.
- **Dashes:**
  - **Front dash** (~25 studs, 6s cooldown) slides in with a jab. It ragdolls a target it catches in its first half and stuns one caught later.
  - **Side / back step** (~17.5 studs, 2s cooldown) can be used during attack startup.
  - Both can be steered by turning the camera.
- **Block:** works in a bit under 180° in front of you.
  - M1s do nothing to a blocking target.
  - Skills do 30% damage and don't ragdoll.
  - Guard breakers (Tidal Slam) break the block and stun you.
  - Blocking slows you, and you can't attack or dash while doing it.
- **Ragdoll:** real physics. The timer runs after landing. Waking up gives 0.75s where melee can't stun you.
- **Evasive:** dash while ragdolled or stunned to get up with 1s of i-frames. It needs a full bar, which fills from:
  - ~77 damage taken (62.5 at half health or lower)
  - or 200 damage dealt (100 at half health or lower)
- **Awakening:** the bar fills from damage dealt. G heals 30 HP, gives brief i-frames and, for 50s, +25% damage and half cooldowns.
- **Health:** 100 HP. Regenerates 1 HP/s starting 1s after damage. Diving in your own paint heals faster.
- **Knockback** grows as health drops (up to ×2 at 0 HP), which is what produces ring-outs. Walking and running also get slower as you get hurt.
- **Wall jumps:** 3, 2 or 1 depending on health (above 66% / above 33% / below).
- **KOs** are credited to whoever hit you last within 7s, even if the sea, the canal or the storm finished you off. A KO heals the killer 25 and refills their evasive bar.

## Paint rules

- Every player owns a color. Paint lands on a 3-stud grid over every paintable surface. It fades after 75s, and each player has a 650-cell cap with the oldest paint disappearing first.
- **Every M1 swing paints** the wall or ground in front of you, and landed hits paint under the target. Skills paint big areas.
- **Your paint:** dive into it to swim at 36 studs/s, heal 10 HP/s, and climb any wall it covers. Leap out with momentum.
- **Enemy paint:** slows you and drains 4 HP/s (never below 30 HP on its own).

## Characters

Every character has the same M1 chain; the weapon changes how swings look and sound.

### Tagger (paint brush): fast, sets things up
1. **Streak:** dash ~25 studs laying a paint lane. Anyone you pass is knocked aside.
2. **Stencil Trap:** a sticky trap. The first enemy to step on it is stuck, then popped into the air.
3. **Burst Can:** a lobbed can that bursts into a huge splat. Burst it at your feet to rocket jump.
4. **Spray Volley:** four quick paint shots, each with a brief stun.

### Plaster (paint roller): heavy, sends people flying
1. **Tidal Slam:** leap and crash down. A 12-stud ring that launches people and breaks blocks.
2. **Hook Line:** hook an enemy and yank them in, or hook a wall and zip to it.
3. **Drench Wave:** a cone of paint that shoves enemies back.
4. **Roller Rush:** charge forward. The first enemy hit is flattened and launched.

Animations are procedural R6 poses (`src/shared/Animations.luau`): idle, walk, a JJS-style forward-leaning sprint, jumps, falls, a crossed-arm block, a stun flinch, all M1 swings and finishers for both weapons, the four dash directions, every skill, the awakening and the evasive.

## Map: Dye District

A city block on an island in a rinse sea (see `docs/map-preview.png`):

- **Mixer Plaza**, a marble stage with a spinning paint-mixer arm. Jump it or get launched.
- **Apartment buildings, a tall tower with a water tank, a warehouse and a print shop.** Every wall is paintable and climbable; windows and graffiti are surface graphics so they never block a climb. A **sky bridge** connects two rooftops.
- **Roads, lamps, benches, cones and barrels** for street dressing, and a distant skyline for depth.
- **The rinse canal** on the west is an instant KO, crossed by two bridges. The island's edges drop into the sea.
- **The Gallery** is the spawn area and safe zone. The **Practice Yard** next to it has a standing dummy and a blocking dummy.
- **Four striped kiosks plus the Gallery** are the Washout shelters.
- **Bounce pads** give fast routes up.

## The Washout

Every 7 minutes: a 20s warning, then a 30s storm. The storm:
- wipes all paint, and keeps rinsing new paint within about 4s,
- pushes anyone outside a shelter around with gusty wind,
- drains 3 HP/s from anyone outside a shelter.

## Feedback

- **Attacker:**
  - the combo damage counter (JJS style: the combo total, with the latest hit above it)
  - a hit-confirm sound and FOV punch
  - an impact frame and a "SPLASHED name" callout on a KO
- **Victim:**
  - a red vignette that scales with damage, and screen shake
  - a hurt sound, the hit reaction animation, and a stun pose
  - the ragdoll, a "RAGDOLLED" status, and an evasive prompt
- **Everyone:**
  - a white hit flash and a paint burst in the attacker's color
  - optional floating damage numbers
  - weapon swing trails
  - 3D impact sounds and the kill feed

Screen shake, flashing lights and impact frames, the damage counter and damage numbers can each be turned off in Settings.

## Roadmap

- **M2, battlegrounds depth.**
  - Full awakened movesets per character.
  - Two more characters.
  - Combo routes tuned from playtests.
  - Emotes.
  - Crews: up to 4 friends share a color and can't hit each other.
- **M3, progression.**
  - Unlock characters through in-world feats.
  - Mastery levels, cosmetics (paint patterns, trails, splat shapes), and bounties on streaks.
- **M4, world.**
  - Turf Bloom zones, a paint-eating creature and player race flags.
  - A second map.
  - Mobile and gamepad controls.

## Sources

The JJS mechanics come from the community wiki's [Controls & Mechanics](https://jujutsushenaniganswiki.com/wiki/controls-mechanics/) and [Settings](https://jujutsushenaniganswiki.com/wiki/settings/) pages. The Fandom wiki itself couldn't be fetched from the build environment.
