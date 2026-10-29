--[[
	Every gameplay tunable lives here so balancing never means hunting through systems.
	Units: studs, seconds, studs/second.

	Combat timings follow Jujutsu Shenanigans where its wiki documents them
	(M1 chain, dashes, ragdoll wake-up, evasive bar, wall jumps).
]]

local Config = {}

-- Paint ---------------------------------------------------------------------
Config.CELL_SIZE = 3 -- edge length of one paint cell
Config.PAINT_LIFETIME = 75 -- paint fades this long after it was laid
Config.STORM_PAINT_LIFETIME = 4 -- during a Washout, rain rinses paint almost instantly
Config.MAX_CELLS_PER_COLOR = 650 -- oldest paint of a color is erased past this
Config.PAINT_FLUSH_INTERVAL = 0.1 -- how often the server sends paint changes
Config.PAINT_VISUAL_LIFT = 0.05 -- gap between a surface and its paint
Config.PAINT_VISUAL_THICKNESS = 0.1
Config.SWING_SPLAT_RADIUS = 3.2 -- every M1 swing paints whatever is in front of you
Config.HIT_SPLAT_RADIUS = 4 -- landing a hit paints the ground under the victim

-- Health --------------------------------------------------------------------
Config.MAX_HEALTH = 100
Config.REGEN = 1 -- per second, starting REGEN_DELAY after the last damage
Config.REGEN_DELAY = 1
Config.SWIM_HEAL = 10 -- extra per second while diving in your own paint
Config.ENEMY_PAINT_DAMAGE = 4 -- per second standing in someone else's paint
Config.ENEMY_PAINT_FLOOR = 30 -- enemy paint alone never takes you below this
Config.STORM_DAMAGE = 3 -- per second outside a shelter during a Washout
Config.SPAWN_PROTECTION = 2.5
Config.RESPAWN_TIME = 3.5
Config.KO_CREDIT_WINDOW = 7 -- a KO within this long of a hit credits the hitter
Config.KO_HEAL = 25

-- M1 chain ------------------------------------------------------------------
Config.M1_DAMAGE = { 3, 3, 4, 4 }
Config.M1_STARTUP = 0.2 -- swing to hit frame
Config.M1_INTERVAL = 0.36 -- minimum time between swings
Config.M1_CHAIN_RESET = 1.1 -- the chain restarts if you wait longer than this
Config.M1_CHAIN_COOLDOWN = 1.6 -- downtime after the 4th hit
Config.M1_BLOCKED_ENDLAG = 0.6 -- extra lockout when an M1 is blocked
Config.M1_STUN = 0.75
Config.M1_PULL = 1 -- the attacker steps this far toward the target on hit
Config.M1_HITBOX = Vector3.new(8, 8, 8)
Config.M1_REACH = 4 -- hitbox centre distance in front of the attacker
Config.M1_FINISHER = {
	Neutral = { knockback = 62, up = 22, ragdoll = 0.9 },
	Uppercut = { knockback = 8, up = 82, ragdoll = 1.1 },
	Downslam = { knockback = 10, up = -60, ragdoll = 1.0 },
}

-- Knockback and ragdoll --------------------------------------------------------
-- Knockback is multiplied by (1 + missingHealthFraction * LOW_HP_KNOCKBACK) so
-- hurt players fly further, which is what makes ring-outs happen.
Config.LOW_HP_KNOCKBACK = 1.0
Config.MIN_LAUNCH_UP = 14
Config.WAKEUP_IMMUNITY = 0.75 -- no melee stun right after getting up
Config.MAX_RAGDOLL = 3.5

-- Evasive (ragdoll / stun cancel) ------------------------------------------------
Config.EVASIVE_TAKEN_FULL = 77 -- damage taken that fills the bar (above half health)
Config.EVASIVE_TAKEN_FULL_LOW = 62.5 -- ...at or below half health
Config.EVASIVE_DEALT_FULL = 200 -- damage dealt that fills the bar
Config.EVASIVE_DEALT_FULL_LOW = 100
Config.EVASIVE_IFRAMES = 1
Config.EVASIVE_DISTANCE = 17.5

-- Awakening -------------------------------------------------------------------------
Config.AWAKEN_DAMAGE_FULL = 220 -- damage dealt that fills the bar
Config.AWAKEN_DURATION = 50
Config.AWAKEN_HEAL = 30
Config.AWAKEN_IFRAMES = 1.5
Config.AWAKEN_DAMAGE_MULT = 1.25
Config.AWAKEN_COOLDOWN_MULT = 0.5

-- Blocking ------------------------------------------------------------------
Config.BLOCK_ARC = 0.05 -- dot product limit: blocks work in a bit under 180 degrees in front
Config.BLOCK_SKILL_DAMAGE_MULT = 0.3
Config.GUARD_BREAK_STUN = 1.2
Config.BLOCK_WALK_SPEED = 6

-- Movement ------------------------------------------------------------------
Config.WALK_SPEED = 16
Config.RUN_SPEED = 27
Config.LOW_HP_SPEED = 0.78 -- speed multiplier at 0 health (scales up to 1 at full)
Config.RUN_DOUBLE_TAP = 0.3
Config.JUMP_POWER = 50
Config.ENEMY_PAINT_SPEED = 10
Config.STUN_WALK_SPEED = 3
Config.SWING_WALK_SPEED = 7 -- while an M1 is winding up
Config.SWIM_SPEED = 36
Config.FLOP_SPEED = 8 -- diving where there is no paint of yours
Config.WALL_SWIM_SPEED = 28
Config.WALL_HOLD_DISTANCE = 1.15
Config.WALL_PROBE_DISTANCE = 2.6
Config.WALL_GRACE = 0.15 -- seconds you may cross unpainted gaps on a wall
Config.LEAP_UP = 64
Config.LEAP_FORWARD = 44
Config.WALL_LEAP_OUT = 34
Config.WALL_LEAP_UP = 58
Config.CREST_POP_UP = 46
Config.CREST_POP_FORWARD = 14
Config.REDIVE_LOCK = 0.3 -- after leaping out you stay surfaced at least this long
Config.DOWN_PROBE = 4.6 -- ray length from the root to find the floor
Config.WALL_JUMPS = { 3, 2, 1 } -- above 66% / 33% / below 33% health
Config.WALL_JUMP_OUT = 34
Config.WALL_JUMP_UP = 52

-- Dashes (Q) ----------------------------------------------------------------
Config.FRONT_DASH_DISTANCE = 25
Config.FRONT_DASH_TIME = 0.36
Config.FRONT_DASH_COOLDOWN = 6
Config.FRONT_DASH_DAMAGE = 4
Config.SIDE_DASH_DISTANCE = 17.5
Config.SIDE_DASH_TIME = 0.24
Config.SIDE_DASH_COOLDOWN = 2

-- World ---------------------------------------------------------------------
Config.VOID_Y = -22 -- just above the rinse sea (terrain water would let people float)

-- Washout cycle -------------------------------------------------------------
Config.DRY_DURATION = 420
Config.WARNING_DURATION = 20
Config.STORM_DURATION = 30
Config.STORM_WIND_ACCEL = 55 -- studs/s^2 pushed on anyone outside a shelter

return Config
