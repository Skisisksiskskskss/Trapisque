# CHANGELOG

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
