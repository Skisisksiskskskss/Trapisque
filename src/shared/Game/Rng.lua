--[[
	Rng
	A tiny deterministic random number generator (Park-Miller "minimal standard" LCG).

	The rules engine never touches Roblox's Random or math.random directly, so a match
	can be replayed from its seed and the engine can be unit-tested outside Roblox.
]]

local Rng = {}
Rng.__index = Rng

local MODULUS = 2147483647 -- 2^31 - 1
local MULTIPLIER = 48271

function Rng.new(seed: number?)
	local self = setmetatable({}, Rng)
	local s = math.floor(math.abs(seed or os.time())) % MODULUS
	if s == 0 then
		s = 1234567
	end
	self.state = s
	-- warm up so nearby seeds diverge quickly
	for _ = 1, 8 do
		self:_next()
	end
	return self
end

function Rng:_next(): number
	self.state = (self.state * MULTIPLIER) % MODULUS
	return self.state
end

-- Float in [0, 1)
function Rng:float(): number
	return (self:_next() - 1) / (MODULUS - 1)
end

-- Integer in [a, b] (inclusive)
function Rng:int(a: number, b: number): number
	if b < a then
		a, b = b, a
	end
	return a + math.floor(self:float() * (b - a + 1))
end

function Rng:chance(p: number): boolean
	return self:float() < p
end

function Rng:pick(list: { any }): any
	if #list == 0 then
		return nil
	end
	return list[self:int(1, #list)]
end

-- In-place Fisher-Yates shuffle. Returns the same table for convenience.
function Rng:shuffle(list: { any }): { any }
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- entries = { {value, weight}, ... }
function Rng:weighted(entries: { { any } }): any
	local total = 0
	for _, e in entries do
		total += e[2]
	end
	local roll = self:float() * total
	for _, e in entries do
		roll -= e[2]
		if roll < 0 then
			return e[1]
		end
	end
	return entries[#entries][1]
end

return Rng
