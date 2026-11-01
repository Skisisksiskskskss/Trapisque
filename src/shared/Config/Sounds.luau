--!strict
-- Sound slots. Paste a Creator Store audio id (numbers only) into Id; empty ids are skipped silently.
-- See ASSETS.md for what to search for each slot.

export type SoundDef = {
	Id: string,
	Volume: number,
	Pitch: number?,
}

local Sounds: { [string]: SoundDef } = {
	Music = { Id = "", Volume = 0.25 },
	WaveHorn = { Id = "", Volume = 0.5 },
	Stampede = { Id = "", Volume = 0.7 },
	Capture = { Id = "", Volume = 0.6 },
	DoorBreak = { Id = "", Volume = 0.8 },
	DoorBlock = { Id = "", Volume = 0.6 },
	Charge = { Id = "", Volume = 0.35 },
	Collect = { Id = "", Volume = 0.45 },
	Upgrade = { Id = "", Volume = 0.5 },
	TierUp = { Id = "", Volume = 0.7 },
	Click = { Id = "", Volume = 0.35 },
	Error = { Id = "", Volume = 0.4 },
	Bonk = { Id = "", Volume = 0.6 },
	Steal = { Id = "", Volume = 0.6 },
	Alarm = { Id = "", Volume = 0.6 },
	Reward = { Id = "", Volume = 0.6 },
	Announce = { Id = "", Volume = 0.5 },
}

return Sounds
