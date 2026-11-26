--[[
	GameConfig: every core tuning number in one place.

	Physics values are per simulation tick at 60 ticks/second, ported 1:1 from the
	original Skuishi Berds (which ran its physics per frame at 60 fps), so the
	birds keep the exact flap/fall/speed feel of the web version.
]]

local GameConfig = {}

GameConfig.GAME_NAME = "Skuishi Berds"
GameConfig.VERSION = "1.0.0"

-- Simulation clock
GameConfig.TICK_RATE = 60
GameConfig.DT = 1 / 60

-- Arena in world units (portrait, 3:5). Rendered scaled to fit any screen.
GameConfig.W = 480
GameConfig.H = 800
GameConfig.MID_X = 240

-- Bird physics (per tick)
GameConfig.GRAVITY = 0.5
GameConfig.FLAP = 10 -- flap sets vertical speed to -10 (or +10 for an upside-down bird)
GameConfig.SPEED = 3 -- horizontal speed
GameConfig.RADIUS = 15
GameConfig.MAX_VY = 18
GameConfig.SPEEDUP_PER_CROSSING = 0.015
GameConfig.MAX_SPEED_MULT = 3.0

-- Lives / damage
GameConfig.LIVES = 4
GameConfig.VERSUS_LIVES = 3
GameConfig.INVULN_TICKS = 120 -- 2 s of blinking after a hit
GameConfig.DEATH_GAMEOVER_DELAY = 60 -- 1 s

-- Spikes
GameConfig.SPIKE_SIZE = 10
GameConfig.SPIKE_ZAP_TICKS = 24 -- spike is invisible + harmless while the zap flies (400 ms)
GameConfig.SPIKE_SOLIDIFY_TICKS = 18 -- hologram phase (harmful), 300 ms
GameConfig.SPIKE_LIFETIME_STRUMS = 20 -- co-op/solo: spikes vanish after 20 score strums
GameConfig.SPIKE_VANISH_TICKS = 48 -- 800 ms fade
GameConfig.VERSUS_SPIKE_LIFETIME = 600 -- 10 s
GameConfig.VERSUS_ZAP_TICKS = 15 -- aimed zap is faster

-- Events
GameConfig.EVENT_DEFAULT_TICKS = 240 -- 4 s
GameConfig.EVENT_FIRST_DELAY = 330 -- first event ~5.5 s into a run
GameConfig.EVENT_GAP_MIN = 150 -- 2.5 s between events (scaled by game speed)
GameConfig.EVENT_GAP_MAX = 228 -- 3.8 s
GameConfig.EVENT_ANNOUNCE_TICKS = 30 -- server announces events 0.5 s before they start
GameConfig.SOLO_EVENT_GAP_MULT = 1.6
GameConfig.TEST_PHASE_TICKS = 180 -- "TESTING POWERS" pin for item/movement events

-- Abilities
GameConfig.ABILITY_MAX_CHARGE = 6

-- Coins / XP
GameConfig.COINS_PER_10_STRUMS = 10 -- original milestone payout: 10 * (milestone / 10)
GameConfig.COINS_EVENT_DISCOVERY = 50
GameConfig.XP_PER_STRUM = 2
GameConfig.VERSUS_PLACEMENT_COINS = { 60, 35, 20, 12, 8, 5 }

-- Matches
GameConfig.COUNTDOWN_TICKS = 180 -- 3 s "3-2-1" before play
GameConfig.VERSUS_MAX_BIRDS = 6
GameConfig.VERSUS_MIN_BIRDS = 4 -- bots fill up to this many
GameConfig.VERSUS_ROUND_TICKS = 120 * 60 -- 2 min then Sudden Death
GameConfig.QUEUE_FILL_SECONDS = 12 -- how long a queue waits for humans before bots fill in
GameConfig.DUO_QUEUE_SECONDS = 20

-- Networking
GameConfig.SNAPSHOT_EVERY = 3 -- server sends bird snapshots every 3 ticks (20 Hz)
GameConfig.CLIENT_STATE_EVERY = 2 -- client sends own bird state every 2 ticks (30 Hz)
GameConfig.INTERP_DELAY_TICKS = 7 -- remote birds render ~115 ms in the past

return GameConfig
