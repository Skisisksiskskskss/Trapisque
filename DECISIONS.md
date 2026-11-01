# DECISIONS.md: Beam a Brainrot

This file records design calls that weren't in the brief. Each line gives the decision and one line of reasoning.
Newest decisions are appended at the bottom of each section.

## Concept (from the owner's pitch)

- **Core idea (owner's):** You build your base. Every ~minute a brainrot comes to each base. A strong enough crystal on a
  pillar in the middle of the base beams it in. If the brainrot is too strong, it breaks the door, and other players can
  steal from you while the door is down. The crystal changes design every time the base is upgraded.
- **Working title: "[💎] Beam a Brainrot".** It follows the "verb + brainrot" naming that's working on the charts right now
  (Steal a Brainrot, Steal An Egg, Kick a Brainrot), and the verb is the game's core action.

## Solving the "end of the line" problem

- **One brainrot per player per wave, all released at the same moment from a central portal.** Bases sit in a ring, so
  every brainrot walks the same distance. Nobody is ever "last in line", and it still looks like a parade.
- **Escaped brainrots keep the owner's "passes by every base" idea.** A brainrot that beats your crystal runs a lap of the
  ring road. Any other base whose crystal is strong enough beams it as it passes. It's a bonus for strong players, and it
  makes good drama ("the kid next door got MY brainrot").

## Core rules

- **Crystal catches, door protects.** If crystal power is at least the brainrot's power, it's captured. If the crystal
  fails, the brainrot hits the door. If the door is stronger, it holds and the brainrot escapes. If not, the door breaks
  for 40s and the base can be raided. Two stats are easy for kids to read, and each one has a clear job.
- **CHARGE tapping during the walk-in** adds up to +30% crystal power. It gives the player something active to do in
  every wave, and tapping is the best possible input on mobile. It's capped, so autoclickers gain nothing extra.
- **Wave every 50s.** "Every minute or so" was the brief, and 50s keeps the first minute busy.
- **Every 5th wave is a BOSS wave.** The boss's power is picked to land between 1.1x and 2.2x your crystal, so it always
  needs charging or a boost. In simulation, normal waves were captured almost 100% of the time once upgraded, which
  removed all tension. Bosses bring back fail and door-break drama about 14% of the time, on a schedule kids can see coming.
- **Brainrot sizes: Normal / Big (x2) / Huge (x4) / Giant (x10)** multiply both power and income. They add variety and a
  visual "whoa" moment as a giant one stomps in, without needing more models.
- **Rarity window per tier.** Each base tier draws from 3–4 neighbouring rarities, and the lowest ones drop out as you
  climb, so late-game waves never hand you worthless Commons.
- **Base tier is gated on a maxed crystal** (crystal level must reach 10 x tier). It makes progress clear: fill the bar,
  then evolve the base.
- **10 base tiers, each with its own theme**: Wood Shack, Stone Fort, Iron Keep, Gold Palace, Ice Citadel, Lava Fortress,
  Jungle Temple, Neon Tower, Candy Castle, Galaxy Station. Each one changes the walls, floor, door, pillar and crystal
  shape, as the owner asked.
- **Pedestal slots per tier**: 4, 6, 8, 10, 12, 14, 16, 18, 21, 24. When your base is full, a better new brainrot
  automatically replaces your weakest one, and the old one goes to storage (50 max), where it can be placed or sold. Kids
  never have to manage a full base by hand.
- **Rebirth needs Tier 10, crystal level 100, and $1B x 3^rebirths.** It gives +50% cash and +15% crystal/door power per
  rebirth, and you KEEP your brainrots. In our sim, a fresh player reaches Tier 10 in about 6.4h, with each rebirth faster.
- **New-player shield:** players at Tier 1 with under 10 minutes of total playtime can't be raided after a door break.
  Their first door break teaches the rule without costing them anything.
- **Each player has their own newcomer wave.** A new player's first brainrot comes 6s after joining, and they're
  guaranteed to beam it. It's the best possible first 30 seconds.

## Economy constants (tuned by sim, see tests/economy.spec.luau)

| Stat | Formula |
|---|---|
| Crystal power | 12 x 1.12^(L-1) x (1 + 0.15 x rebirths) x passes |
| Door strength | 20 x 1.12^(L-1) x (1 + 0.15 x rebirths) x passes |
| Crystal upgrade cost | 22 x 1.165^(L-1) |
| Door upgrade cost | 0.8 x crystal cost |
| Tier T to T+1 cost | 600 x 6.5^(T-1) |
| Rarity base power | 10, 40, 120, 400, 3.5K, 30K, 300K, 2.5M |
| Rarity base income/s | 1, 4, 14, 50, 300, 2K, 15K, 90K |

## Social / stealing

- **Raid window:** the door is down for 40s (auto-repair). The owner can hold REPAIR at the door to speed it up, but then
  they can't defend at the same moment. That's a real choice.
- **Steal:** hold the prompt on a pedestal (1.2s), carry the brainrot above your head at 70% speed, and reach your own base
  to keep it. Getting bonked drops it, and it flies back home. A carry times out after 45s. Server checks: the door really
  is broken, you're not the owner, distance, and per-tick speed (teleport exploits cancel the steal).
- **Bonk Bat** for everyone (a tool built from parts). The server finds the target itself, so client hit reports are never
  trusted. Knockback runs on the victim's own client, because the client owns its character's physics. The part that
  matters (dropping the brainrot) happens on the server.
- **Doors are solid for everyone except the owner.** The owner's client locally turns off the door's collision, and the
  server teleports out any non-owner found inside a base whose door is intact. This blocks no-clip exploits without
  needing a collision group per base.
- **If the owner leaves while their brainrot is being carried, the steal is cancelled.** The owner's profile is saved on
  leave with the brainrot still in it, so completing the steal would duplicate it.

## Monetization

- **Gamepasses:** VIP (+25% cash, +10% luck, tag, daily gift), 2x Cash, Auto Collect, Double Wave (2 brainrots per
  wave), Super Crystal (+25% crystal power), Fortress Door (+50% door strength, 2x faster repair).
- **Developer products:** Overcharge (+50% crystal for one wave), Overcharge x5, Instant Repair, Iron Door (unbreakable
  for 5 min), Lucky Wave (next brainrot is from your top rarity or above and is guaranteed to be beamed), Server Luck
  (2x luck for everyone for 15 min, with the buyer's name announced), three cash packs scaled to your income with the exact
  amount shown before buying, and Double Offline Earnings (only offered in the welcome-back popup).
- **Lucky Wave is a paid random item.** Its odds are shown in the shop, and it's hidden when
  PolicyService.ArePaidRandomItemsRestricted is true.
- **Offers appear at the moment they'd be tempting, never as a wall:** a pulsing Overcharge button when the incoming
  brainrot is stronger than you, Instant Repair while your door is down, and "double it" on offline earnings.
  Everything can also be earned free (daily rewards, playtime gifts, codes, index rewards).

## Tech

- **Map, bases, brainrots and effects are all built from parts at runtime** by shared builders. There are no assets to
  upload. The map is generated by the server on start, so Studio shows an empty baseplate until you press Play.
- **Wave and escape brainrots are drawn and animated on each client** from server-sent timings. The server works out
  every outcome from those same timings, which keeps the motion smooth and the replication cheap. Pedestal brainrots are
  real server instances because they carry the steal prompts.
- **Custom session-locked save layer** (SaveStore): UpdateAsync with a lock {jobId, time}, a stale lock after 30 min,
  retries with exponential backoff, autosave every 60s, release on leave, BindToClose, versioned migrations, and
  reconcile against a template. In Studio, when API access is off, it falls back to an in-memory store. We use no
  third-party packages, so there's no dependency risk.
- **Purchases are idempotent.** PurchaseIds are stored in the profile (last 100). We return PurchaseGranted only after
  the grant has been recorded in a save that succeeded.
- **Global leaderboards use OrderedDataStores** with values stored as log10-scaled integers, because cash outgrows
  OrderedDataStore's integer range.
- **selene runs with a hand-maintained Roblox std file** (roblox.yml): selene's own generator can't reach the API dump
  through the sandbox's TLS proxy. Full API type checking is done by luau-lsp with the official Roblox definitions in
  strict mode.
- **The Rojo project lives at the repo root** next to the existing booklet file, which is left untouched.
- **Server size is 8 players**, which matches the 8 plots in the ring.
