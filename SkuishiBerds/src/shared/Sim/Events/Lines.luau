--[[
	Line events: the middle line itself changes.
]]

local GameConfig = require(script.Parent.Parent.Parent.Config.GameConfig)
local MathUtil = require(script.Parent.Parent.MathUtil)

local W, H, MID = GameConfig.W, GameConfig.H, GameConfig.MID_X

local SPLIT_LINES = { W * 0.33, W * 0.5, W * 0.67 }

return {
	{
		-- crossing sends out a shockwave that shoves birds outward
		name = "LINE_PULSE",
		start = function(_w, ev)
			ev.s.waves = {}
		end,
		onCross = function(_w, ev, bird, _lineX, _own)
			table.insert(ev.s.waves, { y = bird.y, radius = 0, alpha = 1 })
		end,
		step = function(_w, ev)
			local waves = ev.s.waves
			for i = #waves, 1, -1 do
				local wv = waves[i]
				wv.radius += 8
				wv.alpha -= 0.02
				if wv.alpha <= 0 then
					table.remove(waves, i)
				end
			end
		end,
		forces = function(_w, ev, bird, _m)
			for _, wv in ev.s.waves do
				local dx = bird.x - MID
				if math.abs(math.abs(dx) - wv.radius) < 20 then
					bird.x += MathUtil.sign(dx) * 8
				end
			end
		end,
	},
	{
		-- three lines; every line crossing is a strum
		name = "LINE_SPLIT",
		lines = function(_w, _ev)
			return SPLIT_LINES
		end,
	},
	{
		name = "LINE_MAGNET",
		forces = function(_w, _ev, bird, _m)
			bird.x += (MID - bird.x) * 0.4 * 0.05
		end,
	},
	{
		-- crossing warps you to a random height
		name = "LINE_TELEPORT",
		onCross = function(world, _ev, bird, _lineX, own)
			if own then
				bird.y = world.fxRng:range(50, H - 50)
				bird.lastWrapTick = world.tick
				world:fx("teleport", bird)
			end
		end,
	},
}
