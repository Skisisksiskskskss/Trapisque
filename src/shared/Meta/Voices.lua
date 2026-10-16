--[[
	Voices
	How chat bubbles sound. Lines are read out loud (made speakable first by Speech:
	numbers as words, "gg" as "gee gee"), but not by a newsreader: Roblox's
	text-to-speech is pitched up or down a little, sped up or slowed, and some voices go
	through a light echo or a clockwork shimmer, so every voice is a character and every
	line stays easy to understand (client Voice.lua plays them).

	Each character has its own voice; the Voice Pack lets you pick any of them.
		tts      Roblox text-to-speech: its voice (VoiceId), pitch (semitones), speed
		fx       effects it goes through (see Voice.lua)
		pitch, spread, speed   the babble used when text-to-speech can't be had: one
		         squeaky syllable per word, pitched by the word's vowels
]]

local Voices = {}

Voices.list = {
	{ id = "auto", name = "My character's" },
	{
		id = "grumbly",
		name = "Grumbly",
		tts = { voice = "1", pitch = -3, speed = 0.95 },
		fx = { "warm" },
		pitch = 0.62,
		spread = 0.12,
		speed = 7,
	},
	{
		id = "salty",
		name = "Salty",
		tts = { voice = "7", pitch = -1, speed = 1 },
		fx = {},
		pitch = 0.8,
		spread = 0.22,
		speed = 8,
	},
	{
		id = "captain",
		name = "Captain",
		tts = { voice = "3", pitch = -2, speed = 0.96 },
		fx = { "warm" },
		pitch = 0.75,
		spread = 0.15,
		speed = 7,
	},
	{
		id = "dandy",
		name = "Dandy",
		tts = { voice = "5", pitch = 2, speed = 1.1 },
		fx = {},
		pitch = 1.1,
		spread = 0.3,
		speed = 10,
	},
	{
		id = "chipper",
		name = "Chipper",
		tts = { voice = "8", pitch = 2, speed = 1.08 },
		fx = {},
		pitch = 1.25,
		spread = 0.25,
		speed = 10,
	},
	{
		id = "squeaky",
		name = "Squeaky",
		tts = { voice = "4", pitch = 5, speed = 1.12 },
		fx = {},
		pitch = 1.6,
		spread = 0.3,
		speed = 12,
	},
	{
		id = "parrot",
		name = "Parrot",
		tts = { voice = "6", pitch = 7, speed = 1.15 },
		fx = { "squawk" },
		pitch = 1.9,
		spread = 0.45,
		speed = 13,
	},
	{
		id = "ghostly",
		name = "Ghostly",
		tts = { voice = "2", pitch = -2, speed = 0.9 },
		fx = { "haunt" },
		pitch = 0.7,
		spread = 0.4,
		speed = 5,
	},
	{
		id = "robot",
		name = "Clockwork",
		tts = { voice = "9", pitch = 0, speed = 1 },
		fx = { "clockwork" },
		pitch = 1.05,
		spread = 0,
		speed = 10,
	},
}

Voices.byId = {}
for _, v in Voices.list do
	Voices.byId[v.id] = v
end

-- each character's own voice (what "auto" means)
Voices.character = {
	mage = "grumbly",
	trapper = "chipper",
	fire_starter = "salty",
	naturalist = "squeaky",
	warper = "dandy",
	overseer = "captain",
}

-- The voice someone speaks in: their pick (with the Voice Pack), else their character's.
function Voices.resolve(voiceId: string?, character: string?)
	local v = Voices.byId[voiceId or "auto"]
	if not v or v.id == "auto" then
		v = Voices.byId[Voices.character[character or ""] or "salty"]
	end
	return v or Voices.byId.salty
end

return Voices
