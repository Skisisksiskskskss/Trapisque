--[[
	Sounds: plays named sound effects, either flat (UI, your own feedback) or
	positioned in the world.

	Each sound uses its uploaded asset from shared/SoundIds when one is set, and
	otherwise falls back to a pitched built-in Roblox character sound, so the
	game always has audio even before the custom pack is uploaded.
]]

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage").Shared
local SoundIds = require(Shared.SoundIds)

local Sounds = {}

local BUILTIN = {
	land = "rbxasset://sounds/action_jump_land.mp3",
	jump = "rbxasset://sounds/action_jump.mp3",
	splash = "rbxasset://sounds/impact_water.mp3",
	swim = "rbxasset://sounds/action_swim.mp3",
	wind = "rbxasset://sounds/action_falling.mp3",
	getUp = "rbxasset://sounds/action_get_up.mp3",
	step = "rbxasset://sounds/action_footsteps_plastic.mp3",
}

type Def = {
	fallback: string,
	volume: number,
	pitch: { number }, -- random range used with the fallback
	cut: number?, -- stop the fallback after this many seconds
}

local DEFS: { [string]: Def } = {
	Shoot = { fallback = BUILTIN.jump, volume = 0.22, pitch = { 1.7, 2 } },
	Splat = { fallback = BUILTIN.splash, volume = 0.3, pitch = { 1.3, 1.7 } },
	Hit = { fallback = BUILTIN.land, volume = 0.8, pitch = { 1.15, 1.35 } },
	HeavyHit = { fallback = BUILTIN.land, volume = 1, pitch = { 0.6, 0.72 } },
	HitConfirm = { fallback = BUILTIN.step, volume = 0.7, pitch = { 2.3, 2.5 } },
	Hurt = { fallback = BUILTIN.land, volume = 0.7, pitch = { 0.85, 0.95 } },
	Blocked = { fallback = BUILTIN.step, volume = 0.9, pitch = { 0.6, 0.7 } },
	GuardBreak = { fallback = BUILTIN.getUp, volume = 1, pitch = { 0.5, 0.55 } },
	KO = { fallback = BUILTIN.splash, volume = 1, pitch = { 0.5, 0.55 } },
	Dash = { fallback = BUILTIN.wind, volume = 0.55, pitch = { 1.9, 2.1 }, cut = 0.25 },
	Dive = { fallback = BUILTIN.swim, volume = 0.45, pitch = { 1.25, 1.35 } },
	Surface = { fallback = BUILTIN.splash, volume = 0.3, pitch = { 1.8, 2 } },
	Leap = { fallback = BUILTIN.jump, volume = 0.5, pitch = { 1.1, 1.2 } },
	Burst = { fallback = BUILTIN.splash, volume = 1, pitch = { 0.45, 0.55 } },
	Slam = { fallback = BUILTIN.land, volume = 1, pitch = { 0.42, 0.48 } },
	Skill = { fallback = BUILTIN.jump, volume = 0.45, pitch = { 0.8, 0.9 } },
	Trap = { fallback = BUILTIN.getUp, volume = 0.8, pitch = { 1.4, 1.5 } },
	Hook = { fallback = BUILTIN.wind, volume = 0.5, pitch = { 2.6, 2.9 }, cut = 0.3 },
	Bounce = { fallback = BUILTIN.jump, volume = 0.7, pitch = { 0.7, 0.75 } },
	UiClick = { fallback = BUILTIN.step, volume = 0.5, pitch = { 1.8, 1.8 } },
	Warning = { fallback = BUILTIN.getUp, volume = 0.8, pitch = { 0.6, 0.6 } },
	Storm = { fallback = BUILTIN.wind, volume = 0.6, pitch = { 0.45, 0.45 } },
}

-- At most this many copies of one sound may start within RATE_WINDOW, so 20
-- players spamming shots never stack into noise.
local RATE_LIMIT = 6
local RATE_WINDOW = 0.1

local recent: { [string]: { count: number, since: number } } = {}
local random = Random.new()

local function allowed(name: string): boolean
	local now = os.clock()
	local entry = recent[name]
	if not entry or now - entry.since > RATE_WINDOW then
		recent[name] = { count = 1, since = now }
		return true
	end
	if entry.count >= RATE_LIMIT then
		return false
	end
	entry.count += 1
	return true
end

-- Creates a configured Sound for `name` (not parented). Returns nil if unknown.
function Sounds.create(name: string, volumeScale: number?): Sound?
	local def = DEFS[name]
	if not def then
		return nil
	end
	local custom = SoundIds[name]
	local sound = Instance.new("Sound")
	sound.Name = name
	if custom and custom ~= "" then
		sound.SoundId = custom
		sound.PlaybackSpeed = random:NextNumber(0.95, 1.05)
	else
		sound.SoundId = def.fallback
		sound.PlaybackSpeed = random:NextNumber(def.pitch[1], def.pitch[2])
	end
	sound.Volume = def.volume * (volumeScale or 1)
	return sound
end

local function playAndClean(sound: Sound, name: string)
	local def = DEFS[name]
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	local usesFallback = (SoundIds[name] or "") == ""
	local lifetime = if usesFallback and def.cut then def.cut else 6
	task.delay(lifetime, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Plays a non-positional sound (your own feedback, UI).
function Sounds.play(name: string, volumeScale: number?)
	if not allowed(name) then
		return
	end
	local sound = Sounds.create(name, volumeScale)
	if sound then
		sound.Parent = SoundService
		playAndClean(sound, name)
	end
end

-- Plays a sound from a point in the world.
function Sounds.playAt(name: string, position: Vector3, volumeScale: number?)
	if not allowed(name) then
		return
	end
	local sound = Sounds.create(name, volumeScale)
	if not sound then
		return
	end
	local emitter = Instance.new("Attachment")
	emitter.Parent = workspace.Terrain
	emitter.WorldPosition = position
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 220
	sound.Parent = emitter
	sound.Destroying:Connect(function()
		emitter:Destroy()
	end)
	playAndClean(sound, name)
end

return Sounds
