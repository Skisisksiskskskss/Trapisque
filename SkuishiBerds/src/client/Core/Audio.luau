--[[
	Audio: one-shots, looped ambience per event, music, and musical strums.

	Every crossing plays the strum one step further along a pentatonic scale,
	layered with a slightly detuned copy (like the original's 3-layer chord), so
	a long rally turns into a melody. In co-op the top bird plays a harmony.
]]

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SoundDefs = require(Shared.Config.Sounds)

local Audio = {}

local folder = Instance.new("Folder")
folder.Name = "SkuishiAudio"
folder.Parent = SoundService

local volumes = { music = 0.5, sfx = 0.8 }
local ambient: Sound? = nil
local music: Sound? = nil
local musicKey: string? = nil
local rng = Random.new()

local SCALE = { 0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 21, 19, 16, 14, 12, 9, 7, 4, 2 }
local strumStep = { 0, 0, 0, 0, 0, 0 }

local function soundId(key: string): string?
	local def = SoundDefs[key]
	if not def then
		return nil
	end
	if def.id and def.id ~= "" then
		return def.id
	end
	return def.fallback
end

local function make(key: string): Sound?
	local id = soundId(key)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = SoundDefs[key].volume
	s.Parent = folder
	return s
end

function Audio.setVolumes(musicVol: number?, sfxVol: number?)
	volumes.music = musicVol or volumes.music
	volumes.sfx = sfxVol or volumes.sfx
	if music then
		music.Volume = SoundDefs[musicKey or "title_music"].volume * volumes.music
	end
end

-- opts: rate, volume (multiplier), delay
function Audio.play(key: string, rate: number?, volume: number?)
	if volumes.sfx <= 0 then
		return
	end
	local s = make(key)
	if not s then
		return
	end
	s.PlaybackSpeed = rate or 1
	s.Volume *= (volume or 1) * volumes.sfx
	s:Play()
	Debris:AddItem(s, 6)
end

function Audio.flap()
	Audio.play("flap", 1 + (rng:NextNumber() - 0.5) * 0.15, 0.85)
end

function Audio.bounce()
	Audio.play("bounce", 0.95 + rng:NextNumber() * 0.2, 0.9)
end

-- voice: which bird (slot) strummed; harmony shifts the top bird up a fourth
function Audio.strum(voice: number, harmony: boolean?)
	local v = math.clamp(voice, 1, 6)
	strumStep[v] = (strumStep[v] % #SCALE) + 1
	local semis = SCALE[strumStep[v]] - 5 + (if harmony then 5 else 0)
	local rate = 2 ^ (semis / 12)
	Audio.play("strum", rate, 0.55)
	Audio.play("strum", rate * 1.055, 0.3)
end

function Audio.resetMelody()
	strumStep = { 0, 0, 0, 0, 0, 0 }
end

function Audio.ambient(key: string?, volume: number?)
	if ambient then
		ambient:Stop()
		ambient:Destroy()
		ambient = nil
	end
	if not key then
		return
	end
	local s = make(key)
	if not s then
		return
	end
	s.Looped = true
	s.Volume = (volume or SoundDefs[key].volume) * volumes.sfx
	s:Play()
	ambient = s
end

function Audio.music(key: string?)
	if key == musicKey then
		return
	end
	musicKey = key
	local old = music
	music = nil
	if old then
		task.spawn(function()
			for i = 10, 0, -1 do
				old.Volume *= i / 10
				task.wait(0.05)
			end
			old:Destroy()
		end)
	end
	if not key then
		return
	end
	local s = make(key)
	if not s then
		return
	end
	s.Looped = true
	s.Volume = SoundDefs[key].volume * volumes.music
	s:Play()
	music = s
end

return Audio
