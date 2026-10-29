--[[
	Character (kit) definitions shared by server and client: names, weapon,
	stats and skill numbers. Server logic lives in ServerScriptService
	Server/Kits/<Name>; client-side movement and aim live in client/KitClient.

	Every character uses the same JJS-style M1 chain (Config.M1_*); the weapon
	only changes how the swings look and sound.
]]

export type Skill = {
	name: string,
	cooldown: number,
	description: string,
	animation: string,
	params: { [string]: number },
}

export type Character = {
	name: string,
	tagline: string,
	weapon: string, -- "Brush" | "Roller"
	maxHealth: number,
	swimSpeedMultiplier: number,
	knockbackTaken: number,
	skills: { Skill },
}

local Characters = {}

Characters.ORDER = { "Tagger", "Plaster" }
Characters.DEFAULT = "Tagger"

Characters.DEFS = {
	Tagger = {
		name = "Tagger",
		tagline = "Quick street artist with a wide brush. Lays paint fast and never stands still.",
		weapon = "Brush",
		maxHealth = 100,
		swimSpeedMultiplier = 1.15,
		knockbackTaken = 1,
		skills = {
			{
				name = "Streak",
				cooldown = 7,
				animation = "SkillDashForward",
				description = "Dash forward laying a paint lane. Anyone you pass is knocked aside.",
				params = { speed = 80, time = 0.32, radius = 4.5, damage = 9, knockback = 48 },
			},
			{
				name = "Stencil Trap",
				cooldown = 10,
				animation = "SkillThrow",
				description = "Lob a sticky stencil. The first enemy to step on it is stuck, then popped into the air.",
				params = {
					speed = 70,
					gravity = 110,
					triggerRadius = 4.5,
					duration = 14,
					stickTime = 0.5,
					damage = 5,
					popDamage = 8,
					popUp = 90,
					maxTraps = 2,
				},
			},
			{
				name = "Burst Can",
				cooldown = 12,
				animation = "SkillThrow",
				description = "Lob a pressurised can that bursts into a huge splat. Burst it at your feet to rocket jump.",
				params = {
					speed = 80,
					gravity = 120,
					radius = 10,
					damage = 16,
					knockback = 70,
					up = 40,
					selfLaunch = 58,
				},
			},
			{
				name = "Spray Volley",
				cooldown = 9,
				animation = "SkillSpray",
				description = "Fire four quick paint shots where you aim. Each one stuns briefly.",
				params = { shots = 4, interval = 0.1, speed = 170, gravity = 30, damage = 3, stun = 0.35, splat = 3.5 },
			},
		},
	} :: Character,

	Plaster = {
		name = "Plaster",
		tagline = "Heavy decorator with a giant roller. Slow, sturdy, sends people flying.",
		weapon = "Roller",
		maxHealth = 100,
		swimSpeedMultiplier = 0.95,
		knockbackTaken = 0.85,
		skills = {
			{
				name = "Tidal Slam",
				cooldown = 9,
				animation = "SkillSlamRise",
				description = "Leap up and crash down. A ring of paint launches everyone nearby and breaks blocks.",
				params = {
					up = 72,
					forward = 22,
					rise = 0.3,
					dropSpeed = 150,
					radius = 12,
					damage = 14,
					knockback = 75,
					launchUp = 45,
				},
			},
			{
				name = "Hook Line",
				cooldown = 9,
				animation = "SkillThrow",
				description = "Fire a paint line. Hooks an enemy and yanks them in, or zips you to a wall.",
				params = { speed = 220, lifetime = 0.3, damage = 5, stun = 0.8 },
			},
			{
				name = "Drench Wave",
				cooldown = 10,
				animation = "SkillSweep",
				description = "Throw a wave of paint in a wide cone that soaks the ground and shoves enemies back.",
				params = { range = 22, halfAngle = 35, damage = 11, knockback = 70, up = 32 },
			},
			{
				name = "Roller Rush",
				cooldown = 11,
				animation = "SkillCharge",
				description = "Charge forward rolling a wide lane. The first enemy you hit is flattened and launched.",
				params = { speed = 70, time = 0.5, radius = 5, damage = 12, knockback = 85, up = 35 },
			},
		},
	} :: Character,
}

function Characters.get(name: string?): Character
	return Characters.DEFS[name or ""] or Characters.DEFS[Characters.DEFAULT]
end

return Characters
