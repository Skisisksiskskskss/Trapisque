--[[
	EventUtil: helpers shared by the event behaviour modules (kept separate from
	Events/init so the group modules never require their own registry).
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local MathUtil = require(script.Parent.MathUtil)

local W, H = GameConfig.W, GameConfig.H

local EventUtil = {}

-- ticks since the event started (>= 0)
function EventUtil.t(world, ev): number
	return world.tick - ev.startTick
end

function EventUtil.nextId(ev): number
	ev.s.__nextId = (ev.s.__nextId or 0) + 1
	return ev.s.__nextId
end

function EventUtil.isRemoved(ev, id: number): boolean
	return ev.removed[id] == true
end

function EventUtil.remove(ev, id: number)
	ev.removed[id] = true
end

-- Original "ms" based animations converted to ticks: ms(t) = t * 1000/60
function EventUtil.ms(ticks: number): number
	return ticks * (1000 / 60)
end

function EventUtil.circleHit(bird, x: number, y: number, r: number): boolean
	local dx, dy = bird.x - x, bird.y - y
	local rr = bird.radius + r
	return dx * dx + dy * dy < rr * rr
end

function EventUtil.aabbHit(bird, x: number, y: number, w: number, h: number): boolean
	local r = bird.radius
	return bird.x + r > x and bird.x - r < x + w and bird.y + r > y and bird.y - r < y + h
end

-- Nearest other living bird (for magnet-style events)
function EventUtil.nearestOther(world, bird)
	local best, bestD = nil, math.huge
	for _, b in world.birdList do
		if b ~= bird and not b.dead then
			local d = MathUtil.hypot(b.x - bird.x, b.y - bird.y)
			if d < bestD then
				best, bestD = b, d
			end
		end
	end
	return best, bestD
end

-- Report a pickup / destroyed entity through the match layer (it confirms it)
function EventUtil.report(world, ev, id: number, action: string, bird)
	if ev.removed[id] then
		return
	end
	-- optimistic local removal; the server rebroadcasts the authoritative result
	ev.removed[id] = true
	world:call("onEntity", ev, id, action, bird)
end

-- Random helpers that mirror the original's Math.random() expressions
function EventUtil.randX(rng, margin: number): number
	return rng:range(margin, W - margin)
end

function EventUtil.randY(rng, margin: number): number
	return rng:range(margin, H - margin)
end

return EventUtil
