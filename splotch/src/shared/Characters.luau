--[[
	Character (kit) definitions shared by server and client: names, stats,
	primary fire and skill numbers. Server logic lives in ServerScriptService
	Server/Kits/<Name>; client-side movement and aim live in client/KitClient.
]]

export type Primary = {
	name: string,
	cooldown: number,
	cost: number,
	speed: number,
	gravity: number,
	lifetime: number,
	damage: number,
	knockback: number,
	splatRadius: number,
	hitRadius: number,
	size: number,
}

export type Skill = {
	name: string,
	key: string,
	cooldown: number,
	description: string,
	params: { [string]: number },
}

export type Character = {
	name: string,
	tagline: string,
	maxHealth: number,
	swimSpeedMultiplier: number,
	knockbackTaken: number,
	primary: Primary,
	skills: { Skill },
}

local Characters = {}

Characters.ORDER = { "Tagger", "Plaster" }
Characters.DEFAULT = "Tagger"

Characters.DEFS = {
	Tagger = {
		name = "Tagger",
		tagline = "Quick street artist. Paints fast, hits fast, never stands still.",
		maxHealth = 100,
		swimSpeedMultiplier = 1.15,
		knockbackTaken = 1,
		primary = {
			name = "Quick Splat",
			cooldown = 0.13,
			cost = 5,
			speed = 165,
			gravity = 45,
			lifetime = 0.75,
			damage = 4,
			knockback = 7,
			splatRadius = 4.5,
			hitRadius = 0.6,
			size = 0.7,
		},
		skills = {
			{
				name = "Streak",
				key = "1",
				cooldown = 6,
				description = "Dash forward laying a paint lane. Anyone you pass is knocked aside.",
				params = { speed = 80, time = 0.32, radius = 4.5, damage = 10, knockback = 48 },
			},
			{
				name = "Stencil Trap",
				key = "2",
				cooldown = 9,
				description = "Lob a sticky stencil. The first enemy to step on it is stuck, then popped into the air.",
				params = {
					speed = 70,
					gravity = 110,
					triggerRadius = 4.5,
					duration = 14,
					stickTime = 0.5,
					damage = 6,
					popDamage = 8,
					popUp = 95,
					maxTraps = 2,
				},
			},
			{
				name = "Burst Can",
				key = "3",
				cooldown = 10,
				description = "Lob a pressurised can that bursts into a huge splat and blasts people away. Burst it at your feet to rocket jump.",
				params = {
					speed = 80,
					gravity = 120,
					radius = 10,
					damage = 22,
					knockback = 70,
					up = 40,
					selfLaunch = 58,
				},
			},
		},
	} :: Character,

	Plaster = {
		name = "Plaster",
		tagline = "Heavy decorator. Slow, sturdy, and sends people flying.",
		maxHealth = 125,
		swimSpeedMultiplier = 0.95,
		knockbackTaken = 0.8,
		primary = {
			name = "Slosh",
			cooldown = 0.42,
			cost = 11,
			speed = 105,
			gravity = 85,
			lifetime = 1.1,
			damage = 10,
			knockback = 20,
			splatRadius = 7,
			hitRadius = 1.1,
			size = 1.5,
		},
		skills = {
			{
				name = "Tidal Slam",
				key = "1",
				cooldown = 8,
				description = "Leap up and crash down. A ring of paint launches everyone nearby and breaks blocks.",
				params = {
					up = 72,
					forward = 22,
					rise = 0.3,
					dropSpeed = 150,
					radius = 12,
					damage = 18,
					knockback = 75,
					launchUp = 45,
				},
			},
			{
				name = "Hook Line",
				key = "2",
				cooldown = 8,
				description = "Fire a paint line. Hooks an enemy and yanks them in, or zips you to a wall.",
				params = { speed = 220, lifetime = 0.3, damage = 6, stun = 0.7 },
			},
			{
				name = "Drench Wave",
				key = "3",
				cooldown = 9,
				description = "Throw a wave of paint in a wide cone that soaks the ground and shoves enemies back.",
				params = { range = 22, halfAngle = 35, damage = 14, knockback = 70, up = 32 },
			},
		},
	} :: Character,
}

function Characters.get(name: string?): Character
	return Characters.DEFS[name or ""] or Characters.DEFS[Characters.DEFAULT]
end

return Characters
