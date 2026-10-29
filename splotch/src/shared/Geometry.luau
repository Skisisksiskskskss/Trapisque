--[[
	Small pure-math helpers shared by hit detection and aiming.
]]

local Geometry = {}

local EPSILON = 1e-8

--[[
	Closest distance between segments p1->q1 and p2->q2, plus the parameter
	(0..1) along the first segment where it happens. From Ericson, "Real-Time
	Collision Detection", 5.1.9.
]]
function Geometry.segmentSegment(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3): (number, number)
	local d1 = q1 - p1
	local d2 = q2 - p2
	local r = p1 - p2
	local a = d1:Dot(d1)
	local e = d2:Dot(d2)
	local f = d2:Dot(r)
	local s, t
	if a <= EPSILON and e <= EPSILON then
		return r.Magnitude, 0
	end
	if a <= EPSILON then
		s = 0
		t = math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= EPSILON then
			t = 0
			s = math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b
			s = if denom ~= 0 then math.clamp((b * f - c * e) / denom, 0, 1) else 0
			t = (b * s + f) / e
			if t < 0 then
				t = 0
				s = math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t = 1
				s = math.clamp((b - c) / a, 0, 1)
			end
		end
	end
	local closest1 = p1 + d1 * s
	local closest2 = p2 + d2 * t
	return (closest1 - closest2).Magnitude, s
end

-- Horizontal unit vector of `v`, or `fallback` when `v` is (nearly) vertical.
function Geometry.flat(v: Vector3, fallback: Vector3?): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-4 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return f.Unit
end

--[[
	Launch direction that makes a projectile with `speed` under downward
	`gravity` pass through `target` from `origin`, taking the flatter of the two
	ballistic arcs. Out of range, it falls back to a 45 degree throw.
]]
function Geometry.ballisticDirection(origin: Vector3, target: Vector3, speed: number, gravity: number): Vector3
	local delta = target - origin
	if gravity <= EPSILON then
		return if delta.Magnitude > EPSILON then delta.Unit else Vector3.new(0, 0, -1)
	end
	local horizontal = Vector3.new(delta.X, 0, delta.Z)
	local x = horizontal.Magnitude
	local y = delta.Y
	if x < 0.5 then
		return if y >= 0 then Vector3.new(0, 1, 0) else Vector3.new(0, -1, 0)
	end
	local flatDir = horizontal / x
	local s2 = speed * speed
	local disc = s2 * s2 - gravity * (gravity * x * x + 2 * y * s2)
	local angle
	if disc < 0 then
		angle = math.rad(45)
	else
		angle = math.atan((s2 - math.sqrt(disc)) / (gravity * x))
	end
	return (flatDir * math.cos(angle) + Vector3.new(0, math.sin(angle), 0)).Unit
end

-- Position at time `t` of a projectile launched from `origin` with `velocity`.
function Geometry.ballisticPosition(origin: Vector3, velocity: Vector3, gravity: number, t: number): Vector3
	return origin + velocity * t + Vector3.new(0, -0.5 * gravity * t * t, 0)
end

-- True when `point` is inside a box of `size` centred `reach` studs in front of `cframe`.
function Geometry.inFrontBox(cframe: CFrame, reach: number, size: Vector3, point: Vector3, slack: number?): boolean
	local localPoint = cframe:PointToObjectSpace(point) - Vector3.new(0, 0, -reach)
	local extra = slack or 0
	return math.abs(localPoint.X) <= size.X / 2 + extra
		and math.abs(localPoint.Y) <= size.Y / 2 + extra
		and math.abs(localPoint.Z) <= size.Z / 2 + extra
end

return Geometry
