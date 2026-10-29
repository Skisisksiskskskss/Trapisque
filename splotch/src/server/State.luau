--[[
	Per-player server state. Other services read and write it directly; it is
	created when a player joins and dropped when they leave.
]]

export type PlayerState = {
	player: Player,
	colorId: number,
	kit: string,
	paint: number,
	form: string, -- "Normal" | "Swim" | "WallSwim"
	blocking: boolean,
	stunUntil: number,
	nextPrimaryAt: number,
	skillReadyAt: { number },
	dashReadyAt: number,
	lastHitBy: Player?,
	lastHitAt: number,
	lastDamagedAt: number,
	combo: number,
	comboAt: number,
	streak: number,
	spawnProtectedUntil: number,
	deathCause: string?,
	surface: string, -- "none" | "own" | "enemy"
	traps: { any },
	pendingSlamUntil: number,
}

local State = {}

local states: { [Player]: PlayerState } = {}

function State.create(player: Player, colorId: number): PlayerState
	local st: PlayerState = {
		player = player,
		colorId = colorId,
		kit = "Tagger",
		paint = 100,
		form = "Normal",
		blocking = false,
		stunUntil = 0,
		nextPrimaryAt = 0,
		skillReadyAt = { 0, 0, 0 },
		dashReadyAt = 0,
		lastHitBy = nil,
		lastHitAt = -math.huge,
		lastDamagedAt = -math.huge,
		combo = 0,
		comboAt = 0,
		streak = 0,
		spawnProtectedUntil = 0,
		deathCause = nil,
		surface = "none",
		traps = {},
		pendingSlamUntil = 0,
	}
	states[player] = st
	return st
end

function State.get(player: Player): PlayerState?
	return states[player]
end

function State.remove(player: Player)
	states[player] = nil
end

function State.all(): { [Player]: PlayerState }
	return states
end

-- The player currently using `colorId`, if any.
function State.playerWithColor(colorId: number): Player?
	for player, st in states do
		if st.colorId == colorId then
			return player
		end
	end
	return nil
end

return State
