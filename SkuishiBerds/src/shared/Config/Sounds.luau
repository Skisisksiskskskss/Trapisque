--[[
	Sounds. Your original sounds are in assets/audio/. Upload them once
	(Studio > View > Asset Manager > Bulk Import, or Creator Hub > Audio),
	then paste each asset ID below as "rbxassetid://123...".

	Until an ID is filled in, the `fallback` (a sound that ships inside the
	Roblox client) plays instead, so the game is never silent.
]]

export type SoundDef = { id: string, fallback: string?, volume: number, looped: boolean? }

local function s(id: string, fallback: string?, volume: number?, looped: boolean?): SoundDef
	return { id = id, fallback = fallback, volume = volume or 0.8, looped = looped }
end

local Sounds: { [string]: SoundDef } = {
	-- core
	flap = s("", "rbxasset://sounds/swoosh.wav", 0.7),
	bounce = s("", "rbxasset://sounds/collide.wav", 0.6),
	strum = s("", "rbxasset://sounds/electronicpingshort.wav", 0.7),
	lose_life = s("", "rbxasset://sounds/hit.wav", 0.8),
	splat = s("", "rbxasset://sounds/splat.wav", 0.9),
	shield = s("", "rbxasset://sounds/electronicpingshort.wav", 0.6),
	zap = s("", "rbxasset://sounds/flashbulb.wav", 0.6),
	thunder = s("", "rbxasset://sounds/Launching rocket.wav", 0.8),
	comet = s("", "rbxasset://sounds/Rocket shot.wav", 0.5),
	train_pass = s("", "rbxasset://sounds/Launching rocket.wav", 0.9),
	flood = s("", "rbxasset://sounds/action_swim.mp3", 0.9),
	gun_fire = s("", "rbxasset://sounds/paintball.wav", 0.7),
	drill_motor = s("", "rbxasset://sounds/Rocket shot.wav", 0.6),
	dirt_fall = s("", nil, 0.4, true),

	-- ambience (looped while an event runs)
	ambient_blackhole = s("", nil, 0.6, true),
	ambient_wormhole = s("", nil, 0.45, true),
	ambient_meteor = s("", nil, 0.35, true),
	ambient_portal = s("", nil, 0.25, true),
	ambient_lightning = s("", nil, 0.45, true),
	ambient_bubble = s("", nil, 0.35, true),
	ambient_tornado = s("", nil, 0.5, true),
	ambient_kaleidoscope = s("", nil, 0.35, true),
	ambient_forest = s("", nil, 0.8, true),

	-- music
	title_music = s("", nil, 0.5, true),
	ingame_music = s("", nil, 0.4, true),

	-- UI (no originals; built-in sounds)
	ui_click = s("", "rbxasset://sounds/button.wav", 0.5),
	ui_buy = s("", "rbxasset://sounds/electronicpingshort.wav", 0.6),
	ui_win = s("", "rbxasset://sounds/victory.wav", 0.7),
	ui_countdown = s("", "rbxasset://sounds/clickfast.wav", 0.6),
	honk = s("", "rbxasset://sounds/action_jump.mp3", 0.9),
	glass = s("", "rbxasset://sounds/glassbreak.wav", 0.6),
	pop = s("", "rbxasset://sounds/snap.wav", 0.8),
}

return Sounds
