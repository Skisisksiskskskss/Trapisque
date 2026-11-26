--[[
	Spikes: wall spikes, the core hazard.

	The server owns the spike list; clients receive adds/updates/removals. All
	spike animation (walking, spinning, melting, vanishing) is an analytic
	function of the tick, so every machine shows and collides with the exact same
	spike without streaming positions.

	side: -1 = left wall, 1 = right wall
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local MathUtil = require(script.Parent.MathUtil)

local W, H = GameConfig.W, GameConfig.H

local Spikes = {}

export type Spike = {
	id: number,
	side: number,
	y: number, -- base y (walking/melting offsets are applied by Spikes.yAt)
	size: number,
	owner: number, -- bird slot that armed it (0 = neutral)
	team: number, -- 0 = hurts everyone
	spawnTick: number,
	zapTicks: number,
	zapFromX: number,
	zapFromY: number,
	createdAtStrum: number,
	expireTick: number?, -- versus lifetime
	-- modifiers (all analytic)
	walkVy: number?,
	walkStart: number?,
	walkEnd: number?,
	spinSpeed: number?,
	spinStart: number?,
	spinEnd: number?,
	origSize: number?,
	merged: boolean?,
	meltStart: number?,
	meltDur: number?,
	vanishStart: number?,
	shardColor: string?,
}

function Spikes.new(id: number, side: number, y: number, spawnTick: number, opts: { [string]: any }?): Spike
	local o = opts or {}
	local size = o.size or GameConfig.SPIKE_SIZE
	return {
		id = id,
		side = side,
		y = y,
		size = size,
		owner = o.owner or 0,
		team = o.team or 0,
		spawnTick = spawnTick,
		zapTicks = o.zapTicks or GameConfig.SPIKE_ZAP_TICKS,
		zapFromX = o.zapFromX or (if side < 0 then 0 else W),
		zapFromY = o.zapFromY or y,
		createdAtStrum = o.createdAtStrum or 0,
		expireTick = o.expireTick,
	}
end

function Spikes.tipX(spike: Spike): number
	if spike.side < 0 then
		return spike.size * 1.5
	end
	return W - spike.size * 1.5
end

-- Current y including walking and melt drift
function Spikes.yAt(spike: Spike, tick: number): number
	local y = spike.y
	if spike.walkVy and spike.walkStart then
		local t1 = math.min(tick, spike.walkEnd or tick)
		local dt = math.max(0, t1 - spike.walkStart)
		local lo = spike.size * 2
		y = MathUtil.fold(y + spike.walkVy * dt, lo, H - lo)
	end
	if spike.meltStart and spike.meltDur and tick > spike.meltStart then
		local p = math.min(1, (tick - spike.meltStart) / spike.meltDur)
		y += spike.meltDur * p * p
	end
	return y
end

function Spikes.angleAt(spike: Spike, tick: number): number
	if spike.spinSpeed and spike.spinStart then
		local t1 = math.min(tick, spike.spinEnd or tick)
		return spike.spinSpeed * math.max(0, t1 - spike.spinStart)
	end
	return 0
end

-- 0..1 how "solid" the spike is: 0 while the zap is in flight, then 1.
function Spikes.isSolid(spike: Spike, tick: number): boolean
	return tick >= spike.spawnTick + spike.zapTicks
end

function Spikes.opacityAt(spike: Spike, tick: number): number
	local a = 1
	if spike.vanishStart and tick >= spike.vanishStart then
		a = math.min(a, 1 - (tick - spike.vanishStart) / GameConfig.SPIKE_VANISH_TICKS)
	end
	if spike.meltStart and spike.meltDur and tick >= spike.meltStart then
		a = math.min(a, 1 - (tick - spike.meltStart) / spike.meltDur)
	end
	return math.max(0, a)
end

-- Spikes that are fading/melting stop hurting once they're mostly gone.
function Spikes.isHarmful(spike: Spike, tick: number): boolean
	if not Spikes.isSolid(spike, tick) then
		return false
	end
	return Spikes.opacityAt(spike, tick) > 0.45
end

-- true once a spike has fully faded and can be deleted
function Spikes.isFinished(spike: Spike, tick: number): boolean
	if spike.vanishStart and tick >= spike.vanishStart + GameConfig.SPIKE_VANISH_TICKS then
		return true
	end
	if spike.meltStart and spike.meltDur and tick >= spike.meltStart + spike.meltDur then
		return true
	end
	return false
end

--[[
	Original collision: circle around the spike TIP (radius size*0.5) vs bird,
	including the vertical wrap-around distance.
]]
function Spikes.touches(spike: Spike, bx: number, by: number, radius: number, tick: number): boolean
	local tipX = Spikes.tipX(spike)
	local dx = bx - tipX
	local dy = MathUtil.wrapDy(by - Spikes.yAt(spike, tick), H)
	local r = radius + spike.size * 0.5
	return dx * dx + dy * dy < r * r
end

-- Should this spike hurt the given bird (team rules for Versus)?
function Spikes.hurtsTeam(spike: Spike, team: number): boolean
	return spike.team == 0 or spike.team ~= team
end

-- Network packing (reliable messages)
function Spikes.pack(s: Spike): { any }
	return {
		s.id,
		s.side,
		math.floor(s.y * 10 + 0.5) / 10,
		s.size,
		s.owner,
		s.team,
		s.spawnTick,
		s.zapTicks,
		s.zapFromX,
		s.zapFromY,
		s.createdAtStrum,
		s.expireTick or -1,
		s.walkVy or 0,
		s.walkStart or -1,
		s.walkEnd or -1,
		s.spinSpeed or 0,
		s.spinStart or -1,
		s.spinEnd or -1,
		s.origSize or 0,
		if s.merged then 1 else 0,
		s.meltStart or -1,
		s.meltDur or 0,
		s.vanishStart or -1,
	}
end

local function opt(v: number, none: number): number?
	if v == none then
		return nil
	end
	return v
end

function Spikes.unpack(d: { any }): Spike
	return {
		id = d[1],
		side = d[2],
		y = d[3],
		size = d[4],
		owner = d[5],
		team = d[6],
		spawnTick = d[7],
		zapTicks = d[8],
		zapFromX = d[9],
		zapFromY = d[10],
		createdAtStrum = d[11],
		expireTick = opt(d[12], -1),
		walkVy = opt(d[13], 0),
		walkStart = opt(d[14], -1),
		walkEnd = opt(d[15], -1),
		spinSpeed = opt(d[16], 0),
		spinStart = opt(d[17], -1),
		spinEnd = opt(d[18], -1),
		origSize = opt(d[19], 0),
		merged = d[20] == 1,
		meltStart = opt(d[21], -1),
		meltDur = opt(d[22], 0),
		vanishStart = opt(d[23], -1),
	}
end

return Spikes
