--[[
	Every gameplay tunable lives here so balancing never means hunting through systems.
	Units: studs, seconds, studs/second.
]]

local Config = {}

-- Paint ---------------------------------------------------------------------
Config.CELL_SIZE = 3 -- edge length of one paint cell
Config.PAINT_LIFETIME = 75 -- paint fades this long after it was laid
Config.STORM_PAINT_LIFETIME = 4 -- during a Washout, rain rinses paint almost instantly
Config.MAX_CELLS_PER_COLOR = 650 -- oldest paint of a color is erased past this
Config.PAINT_FLUSH_INTERVAL = 0.1 -- how often the server sends paint changes
Config.PAINT_VISUAL_LIFT = 0.06 -- gap between a surface and its paint
Config.PAINT_VISUAL_THICKNESS = 0.12

-- Paint tank ----------------------------------------------------------------
Config.TANK_MAX = 100
Config.TANK_REGEN = 10 -- per second, always
Config.TANK_REGEN_SWIM = 50 -- per second while diving in your own paint

-- Health --------------------------------------------------------------------
Config.SWIM_HEAL = 22 -- per second while diving in your own paint
Config.OUT_OF_COMBAT_DELAY = 5
Config.OUT_OF_COMBAT_REGEN = 4
Config.ENEMY_PAINT_DAMAGE = 6 -- per second standing in someone else's paint
Config.ENEMY_PAINT_FLOOR = 30 -- enemy paint alone never takes you below this
Config.STORM_DAMAGE = 3 -- per second outside a shelter during a Washout
Config.SPAWN_PROTECTION = 2.5
Config.KO_CREDIT_WINDOW = 7 -- a KO within this long of a hit credits the hitter
Config.KO_HEAL = 25 -- health given to whoever gets the KO

-- Knockback -----------------------------------------------------------------
-- Knockback is multiplied by (1 + missingHealthFraction * LOW_HP_KNOCKBACK) so
-- hurt players fly further, which is what makes ring-outs happen.
Config.LOW_HP_KNOCKBACK = 1.3
Config.MIN_LAUNCH_UP = 14 -- knockback always lifts a little so grounded players unstick

-- Blocking ------------------------------------------------------------------
Config.BLOCK_DAMAGE_MULT = 0.25
Config.BLOCK_KNOCKBACK_MULT = 0.25
Config.GUARD_BREAK_STUN = 0.9
Config.BLOCK_WALK_SPEED = 7

-- Movement ------------------------------------------------------------------
Config.WALK_SPEED = 18
Config.JUMP_POWER = 52
Config.ENEMY_PAINT_SPEED = 10
Config.STUN_WALK_SPEED = 4
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

-- Dash (Q) ------------------------------------------------------------------
Config.DASH_SPEED = 88
Config.DASH_TIME = 0.16 -- ~14 studs: short and snappy
Config.DASH_COOLDOWN = 1.6

-- Camera --------------------------------------------------------------------
Config.CAMERA_SENSITIVITY = 0.0042
Config.CAMERA_SHOULDER = 1.9
Config.CAMERA_HEIGHT = 1.9
Config.CAMERA_DEFAULT_ZOOM = 12
Config.CAMERA_MIN_ZOOM = 6
Config.CAMERA_MAX_ZOOM = 22
Config.CAMERA_FOV = 70

-- World ---------------------------------------------------------------------
Config.VOID_Y = -55

-- Washout cycle -------------------------------------------------------------
Config.DRY_DURATION = 420
Config.WARNING_DURATION = 20
Config.STORM_DURATION = 30
Config.STORM_WIND_ACCEL = 55 -- studs/s^2 pushed on anyone outside a shelter

return Config
