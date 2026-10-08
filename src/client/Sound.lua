--[[
	Sound
	UI sound effects. These use sounds that ship with every Roblox client
	(rbxasset://sounds/...), so no uploads are needed. To swap in your own sounds,
	put audio asset ids ("rbxassetid://123") in the table below.
]]

local SoundService = game:GetService("SoundService")

local Sound = {}

local LIBRARY = {
	click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5 },
	hover = { id = "rbxasset://sounds/clickfast.wav", volume = 0.12, pitch = 1.6 },
	open = { id = "rbxasset://sounds/switch.wav", volume = 0.45 },
	close = { id = "rbxasset://sounds/switch.wav", volume = 0.35, pitch = 0.8 },
	hop = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.35, pitch = 1.4 },
	dice = { id = "rbxasset://sounds/collide.wav", volume = 0.5, pitch = 1.3 },
	diceLand = { id = "rbxasset://sounds/collide.wav", volume = 0.7, pitch = 0.9 },
	tick = { id = "rbxasset://sounds/clickfast.wav", volume = 0.25, pitch = 2 },
	card = { id = "rbxasset://sounds/swoosh.wav", volume = 0.45 },
	coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 1.5 },
	treasure = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 0.75 },
	trap = { id = "rbxasset://sounds/hit.wav", volume = 0.6 },
	death = { id = "rbxasset://sounds/glassbreak.wav", volume = 0.35 },
	splash = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.5 },
	magic = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 1.1 },
	turn = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35, pitch = 1.25 },
	error = { id = "rbxasset://sounds/clickfast.wav", volume = 0.4, pitch = 0.6 },
	win = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 0.6 },
	chest = { id = "rbxasset://sounds/swoosh.wav", volume = 0.6, pitch = 0.7 },
	reveal = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 1.8 },
}

local cache = {}
local enabled = true

function Sound.setEnabled(on: boolean)
	enabled = on
end

function Sound.play(name: string, pitchShift: number?)
	if not enabled then
		return
	end
	local def = LIBRARY[name]
	if not def then
		return
	end
	local s = cache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Sfx_" .. name
		s.SoundId = def.id
		s.Volume = def.volume or 0.5
		s.Parent = SoundService
		cache[name] = s
	end
	local clone = s:Clone()
	clone.PlaybackSpeed = (def.pitch or 1) * (pitchShift or 1)
	clone.Parent = SoundService
	clone:Play()
	clone.Ended:Once(function()
		clone:Destroy()
	end)
	task.delay(6, function()
		if clone.Parent then
			clone:Destroy()
		end
	end)
end

return Sound
