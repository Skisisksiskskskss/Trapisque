--[[
	Scene events: the whole page transforms (flood, dirt, sandstorm, subway
	tunnel, lava, night ice, bone gauntlet, forest, neon grid).
]]

local GameConfig = require(script.Parent.Parent.Parent.Config.GameConfig)
local MathUtil = require(script.Parent.Parent.MathUtil)
local EventUtil = require(script.Parent.Parent.EventUtil)

local W, H, MID = GameConfig.W, GameConfig.H, GameConfig.MID_X

------------------------------------------------------------------------------
-- LOG JAM helpers
------------------------------------------------------------------------------
local function respawnLog(log, rng, fromTop: boolean)
	log.dir = if fromTop then 1 else -1
	log.x = rng:next() * (W - log.w - 40) + 20
	log.h = 120 + rng:next() * 40
	log.y = if fromTop then -log.h - rng:next() * 120 else H + rng:next() * 120
	log.speed = 1.2 + rng:next() * 0.8
end

-- Original Log.checkCollision: AABB, resolve along the smallest penetration.
-- Returns "top" | "bottom" | "left" | "right" | nil
local function logCollide(log, bird): string?
	local r = bird.radius
	local bl, br, bt, bb = bird.x - r, bird.x + r, bird.y - r, bird.y + r
	local ll, lr, lt, lb = log.x, log.x + log.w, log.y, log.y + log.h
	if not (br > ll and bl < lr and bb > lt and bt < lb) then
		return nil
	end
	local penLeft, penRight = math.abs(br - ll), math.abs(lr - bl)
	local penTop, penBottom = math.abs(bb - lt), math.abs(lb - bt)
	local minPen = math.min(penLeft, penRight, penTop, penBottom)
	if minPen == penTop then
		bird.y = lt - r
		bird.vy = 0
		return "top"
	elseif minPen == penBottom then
		bird.y = lb + r + 2
		if bird.vy < 0 then
			bird.vy *= -0.4
		end
		return "bottom"
	elseif minPen == penLeft then
		bird.x = ll - r - 2
		bird.dir = -1
		bird.vy *= 0.6
		return "left"
	else
		bird.x = lr + r + 2
		bird.dir = 1
		bird.vy *= 0.6
		return "right"
	end
end

------------------------------------------------------------------------------
local DRILL_FILL = 150 -- 2.5 s of dirt filling the page before drilling starts
local TREE_W = 110
local TREE_SEG = 120

return {
	{
		name = "LOG_JAM",
		start = function(_w, ev)
			local rng = ev.rng
			ev.s.logs = {}
			for _ = 1, 6 do
				local x = rng:next() * (W - 120) + 60
				local fromTop = rng:next() > 0.5
				local w = 40 + rng:next() * 20
				local h = 200 + rng:next() * 80
				table.insert(ev.s.logs, {
					x = x,
					w = w,
					h = h,
					dir = if fromTop then 1 else -1,
					speed = 2.5 + rng:next() * 1.5,
					y = if fromTop then -h - rng:next() * H * 0.5 else H + rng:next() * H * 0.5,
				})
			end
		end,
		step = function(_w, ev)
			for _, log in ev.s.logs do
				log.y += log.dir * log.speed
				if log.dir == 1 and log.y > H + log.h then
					respawnLog(log, ev.rng, true)
				elseif log.dir == -1 and log.y < -log.h then
					respawnLog(log, ev.rng, false)
				end
			end
		end,
		afterVertical = function(world, ev, bird, m)
			local landed
			for _, log in ev.s.logs do
				local side = logCollide(log, bird)
				if side then
					world:fx("logBump", bird)
					if side == "top" then
						landed = log
						break
					end
				end
			end
			if landed then
				-- ride the log (it moves vertically)
				bird.y += landed.dir * landed.speed
				bird.vy = 0
			else
				-- water: drag + buoyancy
				bird.vy *= 0.98
				bird.vy += (if bird.upside then 0.3 else -0.3) * m.time
			end
			return 0
		end,
	},
	{
		name = "DRILL",
		applyBird = function(_w, _ev, bird)
			bird.pendingDrill = true
		end,
		step = function(world, ev)
			if EventUtil.t(world, ev) == DRILL_FILL then
				for _, b in world.birdList do
					if b.sim and b.pendingDrill then
						b.pendingDrill = false
						b.drill = true
					end
				end
				world:fx("drillFilled", nil)
			end
		end,
		mods = function(world, ev, _b, m)
			if EventUtil.t(world, ev) >= DRILL_FILL then
				m.speed *= 0.35
				m.preDrag *= 0.45
			end
		end,
		onFlap = function(world, ev, bird)
			if EventUtil.t(world, ev) >= DRILL_FILL and not bird.rocketBoots then
				bird.vy *= 0.85
			end
		end,
		clearBird = function(_w, _ev, bird)
			bird.drill = false
			bird.pendingDrill = false
		end,
	},
	{
		name = "QUICKSAND",
		mods = function(_w, _ev, _b, m)
			m.flap *= 0.55
		end,
	},
	{
		name = "RAIL_RUSH",
		start = function(_w, ev)
			ev.s.nextSpawn = 7 + ev.rng:next() * 24
			ev.s.warnings = {}
			ev.s.trains = {}
		end,
		step = function(world, ev)
			local t = EventUtil.t(world, ev)
			local rng = ev.rng
			local s = ev.s
			local duration = ev.endTick - ev.startTick
			if t >= s.nextSpawn and t < duration then
				local laneY = rng:next() * (H * 0.6) + H * 0.2
				local dir = if rng:next() > 0.5 then 1 else -1
				table.insert(s.warnings, {
					x = if dir > 0 then 60 else W - 60,
					y = laneY,
					start = t,
					spawnAt = t + 48,
					dir = dir,
				})
				s.nextSpawn = t + 48 + rng:next() * 120
			end
			for i = #s.warnings, 1, -1 do
				local wn = s.warnings[i]
				if t >= wn.spawnAt then
					local speed = 12 + rng:next() * 6
					table.insert(s.trains, {
						x = if wn.dir > 0 then -600 else W + 600,
						y = wn.y,
						w = 400,
						h = 70,
						vx = wn.dir * speed,
						dir = wn.dir,
					})
					table.remove(s.warnings, i)
					world:fx("train", wn)
				end
			end
			for i = #s.trains, 1, -1 do
				local tr = s.trains[i]
				tr.x += tr.vx
				if (tr.vx > 0 and tr.x > W + 200) or (tr.vx < 0 and tr.x < -600) then
					table.remove(s.trains, i)
				end
			end
		end,
		hit = function(_w, ev, bird)
			for _, tr in ev.s.trains do
				if bird.x > tr.x and bird.x < tr.x + tr.w and math.abs(bird.y - tr.y) < tr.h / 2 + bird.radius then
					return "train", nil
				end
			end
			return nil
		end,
	},
	{
		name = "MAGMA_FLOW",
		start = function(_w, ev)
			local rng = ev.rng
			ev.s.rocks = {}
			for _ = 1, 8 do
				table.insert(ev.s.rocks, {
					x = rng:next() * W,
					y = H + rng:next() * 200,
					vx = rng:spread(1.2),
					vy = -(1 + rng:next() * 0.6),
					size = 6 + rng:next() * 16,
				})
			end
		end,
		step = function(world, ev)
			local t = EventUtil.t(world, ev)
			ev.s.height = math.min(H, 0.9 * t)
			for i = #ev.s.rocks, 1, -1 do
				local r = ev.s.rocks[i]
				r.x += r.vx
				r.y += r.vy
				r.vy += 0.08
				if r.y < -40 or r.x < -80 or r.x > W + 80 then
					table.remove(ev.s.rocks, i)
				end
			end
		end,
		hit = function(_w, ev, bird)
			local height = ev.s.height or 0
			if height > 0 and height < H * 0.75 and bird.y + bird.radius > H - height then
				return "magma", nil
			end
			return nil
		end,
	},
	{
		name = "ICE_FIELD",
		start = function(_w, ev)
			local rng = ev.rng
			ev.s.patches = {}
			for _ = 1, 4 + rng:int(0, 2) do
				local w = 80 + rng:next() * 140
				table.insert(ev.s.patches, {
					x = rng:next() * (W - w),
					y = rng:next() * (H - 200) + 60,
					w = w,
				})
			end
			ev.s.flakes = {}
		end,
		step = function(_w, ev)
			local rng = ev.rng
			local flakes = ev.s.flakes
			if rng:chance(0.12) and #flakes < 60 then
				table.insert(flakes, {
					id = EventUtil.nextId(ev),
					x = rng:next() * W,
					y = -10 - rng:next() * 50,
					vx = rng:spread(0.4),
					vy = 1.2 + rng:next() * 1.6,
					size = 1.6 + rng:next() * 3.2,
				})
			end
			for i = #flakes, 1, -1 do
				local f = flakes[i]
				f.x += f.vx
				f.y += f.vy
				f.vy += 0.01
				if f.y > H + 60 then
					table.remove(flakes, i)
				end
			end
		end,
		touch = function(world, ev, bird)
			if world.tick < bird.frozenUntil or bird.freezeAt >= 0 then
				return
			end
			for _, f in ev.s.flakes do
				if not ev.removed[f.id] and EventUtil.circleHit(bird, f.x, f.y, f.size) then
					bird.vy += if bird.upside then -4 else 4
					bird.freezeAt = world.tick + 7
					EventUtil.report(world, ev, f.id, "consume", bird)
					world:fx("snowHit", bird)
					return
				end
			end
		end,
		forces = function(world, ev, bird, _m)
			if world.tick < bird.frozenUntil then
				return
			end
			for _, p in ev.s.patches do
				if bird.x > p.x and bird.x < p.x + p.w and math.abs(bird.y - (p.y + 10)) < 42 then
					bird.x += bird.dir * 0.9
				end
			end
		end,
	},
	{
		-- (originally SOUL_MODE) birds are held in the middle column while bone walls scroll in
		name = "BONE_ZONE",
		serverStart = function(world, _ev)
			for _, s in world.spikes do
				s.vanishStart = world.tick
			end
			world:call("onSpikesChanged")
		end,
		start = function(_w, ev)
			ev.s.bones = {}
			ev.s.spawnAt = 30
			ev.s.lastGap = H / 2
		end,
		mods = function(_w, _ev, _b, m)
			m.lockCenter = true
		end,
		step = function(world, ev)
			local t = EventUtil.t(world, ev)
			local rng = ev.rng
			local s = ev.s
			if t >= s.spawnAt then
				local gap = 220
				local minY = math.max(50, s.lastGap - 250)
				local maxY = math.min(H - gap - 50, s.lastGap + 250)
				local gapY = rng:next() * (maxY - minY) + minY
				s.lastGap = gapY
				local speed = 4 + rng:next() * 2
				if gapY > 40 then
					table.insert(s.bones, { kind = "bone", x = W, y = 0, w = 20, h = gapY, vx = -speed })
				end
				if H - (gapY + gap) > 40 then
					table.insert(s.bones, { kind = "bone", x = W, y = gapY + gap, w = 20, h = H - (gapY + gap), vx = -speed })
				end
				if rng:next() < 0.3 then
					table.insert(s.bones, {
						kind = "floating",
						x = W + 200,
						y = rng:next() * (H - 40) + 20,
						w = 100,
						h = 16,
						vx = -speed * 1.5,
					})
				end
				s.spawnAt = t + 72
			end
			for i = #s.bones, 1, -1 do
				local b = s.bones[i]
				b.x += b.vx
				if b.x < -200 then
					table.remove(s.bones, i)
				end
			end
		end,
		hit = function(_w, ev, bird)
			local r = bird.radius
			for _, b in ev.s.bones do
				if b.kind == "floating" then
					if bird.x + r > b.x - 10 and bird.x - r < b.x + b.w + 10 and bird.y + r > b.y - 12 and bird.y - r < b.y + 12 then
						return "bone", nil
					end
				else
					if EventUtil.aabbHit(bird, b.x, b.y, b.w, b.h) then
						return "bone", nil
					end
					local endY = if b.y == 0 then b.h else b.y
					if EventUtil.circleHit(bird, b.x + b.w / 2, endY, 10) then
						return "bone", nil
					end
				end
			end
			return nil
		end,
	},
	{
		-- A tree grows in the middle. Bonking the trunk chops it; at 60% chopped it falls.
		name = "TIMBER",
		start = function(_w, ev)
			ev.s.treeTop = H
			ev.s.target = 100
			ev.s.falling = false
			ev.s.fallAngle = 0
			ev.s.fallVel = 0
			ev.s.landed = false
			ev.s.chopAt = {}
		end,
		step = function(world, ev)
			local s = ev.s
			if not s.falling then
				s.treeTop += (s.target - s.treeTop) * 0.1
				if s.target > H * 0.6 then
					s.falling = true
					s.fallVel = 0.05
					world:fx("timberCreak", nil)
				end
			elseif not s.landed then
				s.fallAngle += s.fallVel
				s.fallVel += 0.005
				if s.fallAngle > math.pi / 2 then
					s.landed = true
					world:fx("timberLand", nil)
				end
			end
		end,
		isDone = function(_w, ev)
			return ev.s.landed == true
		end,
		signal = function(_w, ev, key, value)
			if key == "target" then
				ev.s.target = value
			end
		end,
		touch = function(world, ev, bird)
			local s = ev.s
			if s.falling then
				return
			end
			local r = bird.radius
			local trunkX = MID - TREE_W / 2
			if bird.x + r > trunkX and bird.x - r < trunkX + TREE_W and bird.y + r > s.treeTop then
				if bird.y < s.treeTop + 20 and bird.vy > 0 then
					-- canopy trampoline
					bird.y = s.treeTop - r
					bird.vy = -12
					world:fx("canopyBounce", bird)
				else
					if bird.x < MID then
						bird.x = trunkX - r - 2
						bird.dir = -1
					else
						bird.x = trunkX + TREE_W + r + 2
						bird.dir = 1
					end
					bird.prevX = bird.x
					bird.vy *= 0.6
					if world.tick - (s.chopAt[bird.slot] or -100) > 15 then
						s.chopAt[bird.slot] = world.tick
						if not world.isServer then
							s.target += TREE_SEG -- predicted; the server rebroadcasts the real value
						end
						world:call("onEntity", ev, 0, "chop", bird)
					end
					world:fx("chop", bird)
				end
			end
		end,
	},
	{
		-- every bird leaves a 2.5 s neon trail; touching a trail zaps you away (no damage)
		name = "NEON_TRAILS",
		start = function(_w, ev)
			ev.s.trails = {}
		end,
		step = function(world, ev)
			local tick = world.tick
			for _, b in world.birdList do
				local trail = ev.s.trails[b.slot]
				if not trail then
					trail = {}
					ev.s.trails[b.slot] = trail
				end
				if not b.dead then
					table.insert(trail, { b.x, b.y, tick })
				end
				while #trail > 0 and tick - trail[1][3] > 150 do
					table.remove(trail, 1)
				end
			end
		end,
		touch = function(world, ev, bird)
			for slot, trail in ev.s.trails do
				local count = #trail
				local safe = if slot == bird.slot then count - 15 else count
				for i = 1, safe - 1 do
					local p1, p2 = trail[i], trail[i + 1]
					if p2 and math.abs(p1[1] - p2[1]) <= 100 and math.abs(p1[2] - p2[2]) <= 100 then
						local d = MathUtil.distToSegment(bird.x, bird.y, p1[1], p1[2], p2[1], p2[2])
						if d < bird.radius + 2 then
							bird.vy *= -1.2
							-- push away from the trail segment's midpoint
							local mx, my = (p1[1] + p2[1]) / 2, (p1[2] + p2[2]) / 2
							local dx, dy = bird.x - mx, bird.y - my
							local len = math.max(0.001, MathUtil.hypot(dx, dy))
							bird.x += dx / len * 10
							bird.y += dy / len * 10
							world:fx("neonHit", { bird = bird, slot = slot })
							return
						end
					end
				end
			end
		end,
	},
}
