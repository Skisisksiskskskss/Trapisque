--[[
	Rng: deterministic, platform-independent PRNG (mulberry32) built on bit32.

	Server and every client construct the same Rng from the same seed so event
	hazards (meteors, trains, bones, ...) play out identically everywhere without
	streaming their positions over the network.
]]

local Rng = {}
Rng.__index = Rng

local U32 = 4294967296

-- 32-bit multiply (like JS Math.imul, unsigned result). Splits into 16-bit halves
-- so the intermediate products stay exact in double precision.
local function imul(a: number, b: number): number
	a = bit32.band(a, 0xFFFFFFFF)
	b = bit32.band(b, 0xFFFFFFFF)
	local ah, al = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
	local bh, bl = bit32.rshift(b, 16), bit32.band(b, 0xFFFF)
	local hi = bit32.band(ah * bl + al * bh, 0xFFFF)
	return (hi * 65536 + al * bl) % U32
end
Rng.imul = imul

local function mix32(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = imul(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = imul(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end

-- Combine any number of integers into a well-mixed 32-bit seed.
function Rng.hash(...: number): number
	local h = 0x9E3779B9
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		v = math.floor(v) % U32
		h = mix32(bit32.bxor(h, imul(v + i * 0x27D4EB2F, 0x165667B1)))
	end
	return h
end

function Rng.new(seed: number)
	local self = setmetatable({}, Rng)
	self.state = math.floor(seed) % U32
	-- warm up so nearby seeds diverge immediately
	self:next()
	self:next()
	return self
end

-- Uniform float in [0, 1)
function Rng:next(): number
	local a = (self.state + 0x6D2B79F5) % U32
	self.state = a
	local t = imul(bit32.bxor(a, bit32.rshift(a, 15)), bit32.bor(a, 1))
	t = bit32.bxor((t + imul(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61))) % U32, t)
	return bit32.bxor(t, bit32.rshift(t, 14)) / U32
end

-- Uniform float in [a, b)
function Rng:range(a: number, b: number): number
	return a + (b - a) * self:next()
end

-- Uniform integer in [a, b] (inclusive)
function Rng:int(a: number, b: number): number
	return a + math.floor(self:next() * (b - a + 1))
end

function Rng:chance(p: number): boolean
	return self:next() < p
end

-- -1 or 1
function Rng:sign(): number
	return if self:next() < 0.5 then -1 else 1
end

-- Like JS (Math.random() - 0.5) * k
function Rng:spread(k: number): number
	return (self:next() - 0.5) * k
end

function Rng:pick<T>(list: { T }): T
	return list[self:int(1, #list)]
end

function Rng:shuffle<T>(list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Rng
