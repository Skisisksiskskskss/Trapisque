--!strict
-- Size traits. Bigger brainrots are worth more and hit harder.

export type Size = {
	Name: string,
	Weight: number,
	Mult: number, -- power and income multiplier
	Scale: number, -- visual scale while walking (pedestal display is clamped)
}

local list: { Size } = {
	{ Name = "Normal", Weight = 75, Mult = 1, Scale = 1 },
	{ Name = "Big", Weight = 18, Mult = 2, Scale = 1.35 },
	{ Name = "Huge", Weight = 6, Mult = 4, Scale = 1.8 },
	{ Name = "Giant", Weight = 1, Mult = 10, Scale = 2.6 },
}

local byName: { [string]: Size } = {}
for _, size in list do
	byName[size.Name] = size
end

local Sizes = {
	List = list,
	ByName = byName,
}

function Sizes.Get(name: string): Size
	return byName[name] or byName.Normal
end

return Sizes
