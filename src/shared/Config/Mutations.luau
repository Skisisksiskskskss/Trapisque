--!strict
-- Mutations recolour a brainrot and multiply its income and power.

export type Mutation = {
	Name: string,
	Chance: number, -- percent per wave
	IncomeMult: number,
	PowerMult: number,
	Color: Color3?,
	Material: Enum.Material?,
	Announce: boolean,
}

local list: { Mutation } = {
	{ Name = "None", Chance = 0, IncomeMult = 1, PowerMult = 1, Announce = false },
	{
		Name = "Gold",
		Chance = 4,
		IncomeMult = 2,
		PowerMult = 1.25,
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Foil,
		Announce = false,
	},
	{
		Name = "Diamond",
		Chance = 1.2,
		IncomeMult = 3,
		PowerMult = 1.5,
		Color = Color3.fromRGB(150, 230, 255),
		Material = Enum.Material.Glass,
		Announce = false,
	},
	{
		Name = "Rainbow",
		Chance = 0.35,
		IncomeMult = 5,
		PowerMult = 2,
		Color = Color3.fromRGB(255, 80, 200),
		Material = Enum.Material.Neon,
		Announce = true,
	},
	{
		Name = "Galaxy",
		Chance = 0.05,
		IncomeMult = 10,
		PowerMult = 3,
		Color = Color3.fromRGB(70, 30, 140),
		Material = Enum.Material.Neon,
		Announce = true,
	},
}

local byName: { [string]: Mutation } = {}
for _, mutation in list do
	byName[mutation.Name] = mutation
end

local Mutations = {
	List = list,
	ByName = byName,
}

function Mutations.Get(name: string): Mutation
	return byName[name] or byName.None
end

return Mutations
