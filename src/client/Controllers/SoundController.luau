--!strict
-- Plays configured sounds (2D or positional) and the background music loop. Slots with empty ids are skipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)

local SoundController = {}

local sfxEnabled = true
local musicEnabled = true
local music: Sound? = nil
local pool: { [string]: Sound } = {}

local function assetId(id: string): string
	return "rbxassetid://" .. id
end

function SoundController.Play(name: string, position: Vector3?)
	if not sfxEnabled then
		return
	end
	local def = Sounds[name]
	if not def or def.Id == "" then
		return
	end
	if position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = position
		holder.Parent = Workspace
		local sound = Instance.new("Sound")
		sound.SoundId = assetId(def.Id)
		sound.Volume = def.Volume
		sound.PlaybackSpeed = def.Pitch or 1
		sound.RollOffMaxDistance = 260
		sound.RollOffMinDistance = 20
		sound.Parent = holder
		sound:Play()
		task.delay(6, function()
			holder:Destroy()
		end)
		return
	end
	local sound = pool[name]
	if not sound then
		local created = Instance.new("Sound")
		created.SoundId = assetId(def.Id)
		created.Volume = def.Volume
		created.PlaybackSpeed = def.Pitch or 1
		created.Parent = SoundService
		pool[name] = created
		sound = created
	end
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

function SoundController.SetSfx(enabled: boolean)
	sfxEnabled = enabled
end

function SoundController.SetMusic(enabled: boolean)
	musicEnabled = enabled
	if music then
		if enabled then
			music:Resume()
		else
			music:Pause()
		end
	end
end

function SoundController.Start()
	local def = Sounds.Music
	if def.Id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Music"
		sound.SoundId = assetId(def.Id)
		sound.Volume = def.Volume
		sound.Looped = true
		sound.Parent = SoundService
		music = sound
		if musicEnabled then
			sound:Play()
		end
	end
end

return SoundController
