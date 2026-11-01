# CHANGELOG

## M3: Multiplayer, stealing, bonk, escapes (`builds/BeamABrainrot_M3.rbxlx`)

- **Raids:** when a brainrot smashes your door, everyone else can see STEAL prompts on your pedestals. A thief holds
  the prompt, carries the brainrot above their head at 70% speed, and keeps it only by reaching their own base
  before the 45s timeout. A glowing beam shows the thief the way home.
- **Bonk Bat:** every player gets one, built from parts. A bonk knocks the target flying, and a bonked thief drops the
  brainrot, which flies back home.
- **Anti-cheat on the server:**
  - The server checks door state, ownership, distance, the thief's free space, the carry timeout and per-tick
    movement speed. Teleporting home cancels the steal.
  - Freshly stolen brainrots are protected for 60s.
  - A carry is cancelled if the owner leaves, so a brainrot can never be duplicated.
- **Notifications, alarms and server announcements** for steals, bonks and rare raids. Steals and times-stolen-from
  are tracked as stats.
- **End-to-end server simulation (tests/sim.luau):** boots the real server inside Lune with fake players and checks
  39 behaviours. It covers join, the welcome wave, capture, income and pad collection, the upgrade gates, tier
  rebuild, global waves, door-locked steal refusal, a full steal, the teleport exploit, bonk drop, cancel when the
  owner leaves, save and rejoin, rebirth, and inventory and boost validation.

## M2: Saving, progression, upgrades, rebirth (`builds/BeamABrainrot_M2.rbxlx`)

- **Saves you can trust:** session locks stop two servers writing the same save. Stale locks from crashed servers
  are taken over after 10 min. Every DataStore call retries with backoff, saves are versioned and migrated, and
  leaving or shutting down saves and releases. 9 unit tests run against a simulated two-server DataStore.
- **Progression:** crystal and door levels (10 per tier), 10 themed base tiers, and Rebirth (+50% cash, +15% power,
  keep your brainrots) with a confirm tap.
- **Index (collection book):** all 36 brainrots shown by rarity as discovered or "???" silhouettes, mutation stamps,
  +2% cash per discovery, and one-time boost rewards for completing each rarity.
- **Settings:** music and sound-effect toggles are saved to your profile.
- **Shared reward system** for Index sets now (and daily, codes and gifts later), with income-scaled cash.
- **Economy pacing test:** a simulated active player against the real config reaches tier 2 in about 5 min,
  tier 5 in about 40 min and tier 10 in about 6.5 h, losing about 12% of showdowns.

## M1: Core loop playable (`builds/BeamABrainrot_M1.rbxlx`)

- **World:** an 8-base ring map around the Brainrot Portal, generated from parts at server start.
- **Brainrots:** 36 original fake-Italian brainrots, built from parts, each with sizes, mutations and rarity glow.
- **Waves:** every 50s, each player's brainrot marches out of the portal to their door. Tap CHARGE (or press
  F / R2) to power up your crystal.
  - If the crystal wins, the brainrot is beamed into it and lands on a pedestal, where it earns cash.
  - If it loses, the brainrot smashes your door (or your door holds) and escapes around the ring road, where
    other crystals can beam it.
- **Boss waves:** every 5th wave is a boss, always stronger than your crystal.
- **Collecting:** step on the glowing pads to collect cash. Upgrade your crystal, door and base tier, which gives a
  new theme and crystal design every tier.
- **HUD:** cash, wave timer, incoming brainrot card with live power bar, CHARGE button, door alarm, toasts and
  announcements.
- **Saving:** the session-locked save system is already active. M2 rounds out progression.
