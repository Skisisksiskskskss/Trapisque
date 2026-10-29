--[[
	Per-combatant server state (players and training dummies). Other services
	read and write it directly; it is created when a combatant appears and
	dropped when it leaves.
]]

export type PlayerState = {
	key: any, -- the Player, or the dummy Model
	colorId: number,
	kit: string,
	form: string, -- "Normal" | "Swim" | "WallSwim"
	blocking: boolean,
	stunUntil: number,
	ragdollUntil: number,
	ragdollToken: number,
	meleeImmuneUntil: number, -- no M1 stun right after waking up
	invulnerableUntil: number,
	m1Step: number,
	m1At: number, -- when the current swing started
	m1ReadyAt: number,
	m1Variant: string,
	m1Hit: boolean, -- whether the current swing already landed
	skillReadyAt: { number },
	frontDashReadyAt: number,
	sideDashReadyAt: number,
	frontDashAt: number,
	frontDashHit: boolean,
	lastHitBy: Player?,
	lastHitAt: number,
	lastDamagedAt: number,
	comboDamage: number,
	comboAt: number,
	evasive: number, -- 0..100
	awakening: number, -- 0..100
	awakenedUntil: number,
	streak: number,
	spawnProtectedUntil: number,
	deathCause: string?,
	surface: string, -- "none" | "own" | "enemy"
	pendingSlamUntil: number,
	pendingRushUntil: number,
}

local State = {}

local states: { [any]: PlayerState } = {}

local function fresh(key: any, colorId: number): PlayerState
	return {
		key = key,
		colorId = colorId,
		kit = "Tagger",
		form = "Normal",
		blocking = false,
		stunUntil = 0,
		ragdollUntil = 0,
		ragdollToken = 0,
		meleeImmuneUntil = 0,
		invulnerableUntil = 0,
		m1Step = 0,
		m1At = 0,
		m1ReadyAt = 0,
		m1Variant = "Neutral",
		m1Hit = false,
		skillReadyAt = { 0, 0, 0, 0 },
		frontDashReadyAt = 0,
		sideDashReadyAt = 0,
		frontDashAt = 0,
		frontDashHit = false,
		lastHitBy = nil,
		lastHitAt = -math.huge,
		lastDamagedAt = -math.huge,
		comboDamage = 0,
		comboAt = 0,
		evasive = 100,
		awakening = 0,
		awakenedUntil = 0,
		streak = 0,
		spawnProtectedUntil = 0,
		deathCause = nil,
		surface = "none",
		pendingSlamUntil = 0,
		pendingRushUntil = 0,
	}
end

function State.create(key: any, colorId: number): PlayerState
	local st = fresh(key, colorId)
	states[key] = st
	return st
end

-- Resets everything that should not survive a respawn.
function State.resetForSpawn(st: PlayerState)
	local keep = fresh(st.key, st.colorId)
	keep.kit = st.kit
	keep.awakening = st.awakening
	keep.streak = st.streak
	for key, value in keep do
		(st :: any)[key] = value
	end
end

function State.get(key: any): PlayerState?
	return states[key]
end

function State.remove(key: any)
	states[key] = nil
end

function State.all(): { [any]: PlayerState }
	return states
end

function State.isAwakened(st: PlayerState): boolean
	return os.clock() < st.awakenedUntil
end

return State
