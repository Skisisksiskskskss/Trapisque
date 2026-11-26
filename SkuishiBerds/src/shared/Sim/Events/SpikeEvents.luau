--[[
	Spike events. The server owns spikes, so these transform the server's spike
	list (serverStart/serverStop) and then sync it; clients only show effects.
	All spike animation is analytic (see Spikes.yAt/angleAt) so walking and
	spinning spikes stay in lockstep everywhere.
]]

local GameConfig = require(script.Parent.Parent.Parent.Config.GameConfig)
local Spikes = require(script.Parent.Parent.Spikes)

local H = GameConfig.H

local function neutralSpike(world, side: number, y: number, size: number?)
	local id = world:newSpikeId()
	local spike = Spikes.new(id, side, y, world.tick, {
		size = size,
		createdAtStrum = world.arenaStrums,
	})
	if world.mode.versus then
		spike.expireTick = world.tick + GameConfig.VERSUS_SPIKE_LIFETIME
	end
	world:addSpike(spike)
	return spike
end

local function changed(world)
	world:call("onSpikesChanged")
end

local function solidSpikes(world)
	local out = {}
	for _, s in world.spikes do
		if Spikes.isSolid(s, world.tick) and not s.vanishStart and not s.meltStart then
			table.insert(out, s)
		end
	end
	return out
end

return {
	{
		-- four extra spikes on each wall
		name = "SPIKE_RAIN",
		serverStart = function(world, ev)
			local rng = ev.rng
			local size = GameConfig.SPIKE_SIZE
			for _ = 1, 4 do
				neutralSpike(world, -1, rng:range(size * 2, H - size * 2))
				neutralSpike(world, 1, rng:range(size * 2, H - size * 2))
			end
			changed(world)
		end,
	},
	{
		name = "SPIKE_MELT",
		serverStart = function(world, ev)
			for _, s in world.spikes do
				s.meltStart = world.tick
				s.meltDur = ev.rng:int(60, 90)
			end
			changed(world)
		end,
	},
	{
		name = "SPIKE_SHATTER",
		serverStart = function(world, _ev)
			world:clearSpikes()
			changed(world)
		end,
	},
	{
		name = "SPIKE_VANISH",
		serverStart = function(world, _ev)
			for _, s in world.spikes do
				s.vanishStart = world.tick
			end
			changed(world)
		end,
	},
	{
		-- spikes grow legs and pace up and down their wall, then sit down where they end up
		name = "SPIKE_WALK",
		serverStart = function(world, ev)
			for _, s in solidSpikes(world) do
				s.walkVy = ev.rng:spread(1.5)
				s.walkStart = world.tick
				s.walkEnd = ev.endTick
			end
			changed(world)
		end,
	},
	{
		-- same-wall spikes within 80 units fuse into one bigger spike
		name = "SPIKE_MERGE",
		serverStart = function(world, _ev)
			local list = solidSpikes(world)
			local merged = {}
			for i, a in list do
				if merged[a.id] then
					continue
				end
				local group = { a }
				for j = i + 1, #list do
					local b = list[j]
					if not merged[b.id] and b.side == a.side and math.abs(Spikes.yAt(a, world.tick) - Spikes.yAt(b, world.tick)) < 80 then
						table.insert(group, b)
						merged[b.id] = true
					end
				end
				if #group > 1 then
					local sum = 0
					for _, s in group do
						sum += Spikes.yAt(s, world.tick)
					end
					a.y = sum / #group
					a.walkVy = nil
					a.walkStart = nil
					a.walkEnd = nil
					a.size = math.min(30, a.size + (#group - 1) * 4)
					a.merged = true
					for k = 2, #group do
						world:removeSpike(group[k].id)
					end
				end
			end
			changed(world)
		end,
	},
	{
		name = "SPIKE_SPIN",
		serverStart = function(world, ev)
			for _, s in solidSpikes(world) do
				s.spinSpeed = 0.15 + ev.rng:next() * 0.1
				s.spinStart = world.tick
				s.spinEnd = ev.endTick
			end
			changed(world)
		end,
	},
	{
		name = "SPIKE_SHRINK",
		serverStart = function(world, _ev)
			for _, s in solidSpikes(world) do
				if not s.origSize then
					s.origSize = s.size
				end
				s.size = s.origSize * 0.4
			end
			changed(world)
		end,
		serverStop = function(world, _ev)
			for _, s in world.spikes do
				if s.origSize then
					s.size = s.origSize
					s.origSize = nil
				end
			end
			changed(world)
		end,
	},
	{
		-- every spike splits into 2-3 smaller spikes, 40 apart
		name = "SPIKE_MULTIPLY",
		serverStart = function(world, ev)
			for _, s in solidSpikes(world) do
				local n = ev.rng:int(2, 3)
				local baseY = Spikes.yAt(s, world.tick)
				for i = 0, n - 1 do
					local child = neutralSpike(world, s.side, baseY + (i - (n - 1) / 2) * 40, s.size * 0.6)
					child.spawnTick = world.tick - child.zapTicks -- already solid
					child.owner = s.owner
					child.team = s.team
					child.createdAtStrum = s.createdAtStrum
					child.expireTick = s.expireTick
				end
				world:removeSpike(s.id)
			end
			changed(world)
		end,
	},
}
