--[[
	MathUtil: small pure-math helpers shared by the simulation and renderer.
]]

local MathUtil = {}

function MathUtil.clamp(v: number, lo: number, hi: number): number
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

function MathUtil.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function MathUtil.hypot(x: number, y: number): number
	return math.sqrt(x * x + y * y)
end

function MathUtil.sign(v: number): number
	if v > 0 then
		return 1
	elseif v < 0 then
		return -1
	end
	return 0
end

-- Positive modulo
function MathUtil.mod(a: number, n: number): number
	return a - n * math.floor(a / n)
end

-- Fold a value into [lo, hi] as if it bounced off both ends (used for analytic
-- "walking spike" positions so server and clients agree without per-tick sync).
function MathUtil.fold(v: number, lo: number, hi: number): number
	local span = hi - lo
	if span <= 0 then
		return lo
	end
	local u = MathUtil.mod(v - lo, span * 2)
	if u > span then
		u = span * 2 - u
	end
	return lo + u
end

-- Shortest vertical distance on a wrapping arena of height h
function MathUtil.wrapDy(dy: number, h: number): number
	local d = math.abs(dy)
	return math.min(d, h - d)
end

-- Distance from point (px,py) to segment (ax,ay)-(bx,by)
function MathUtil.distToSegment(px: number, py: number, ax: number, ay: number, bx: number, by: number): number
	local cx, cy = bx - ax, by - ay
	local lenSq = cx * cx + cy * cy
	local t = 0
	if lenSq > 0 then
		t = ((px - ax) * cx + (py - ay) * cy) / lenSq
		t = MathUtil.clamp(t, 0, 1)
	end
	local qx, qy = ax + cx * t, ay + cy * t
	return MathUtil.hypot(px - qx, py - qy)
end

-- Angle difference normalized to (-pi, pi]
function MathUtil.angleDiff(a: number, b: number): number
	local d = a - b
	while d > math.pi do
		d -= math.pi * 2
	end
	while d <= -math.pi do
		d += math.pi * 2
	end
	return d
end

return MathUtil
