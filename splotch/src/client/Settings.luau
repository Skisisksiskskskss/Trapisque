--[[
	Settings: the player's preferences (toggles, volume) and keybinds. Loaded
	from the server once after joining and saved back, debounced, whenever
	something changes.
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Remotes = require(Shared.Remotes)

local Keybinds = require(script.Parent.Keybinds)

local Settings = {}

Settings.DEFAULTS = {
	autoRun = false,
	screenShake = true,
	flashingLights = true,
	damageCounter = true,
	damageNumbers = true,
	sfxVolume = 1,
}

local values: { [string]: any } = table.clone(Settings.DEFAULTS)
local listeners: { () -> () } = {}
local saveQueued = false

local SAVE_DELAY = 2

local function notify()
	for _, listener in listeners do
		task.spawn(listener)
	end
end

local function queueSave()
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(SAVE_DELAY, function()
		saveQueued = false
		local data = table.clone(values)
		data.binds = Keybinds.serialize()
		Remotes.SaveSettings:FireServer(data)
	end)
end

function Settings.get(name: string): any
	return values[name]
end

function Settings.set(name: string, value: any)
	if Settings.DEFAULTS[name] == nil or typeof(value) ~= typeof(Settings.DEFAULTS[name]) then
		return
	end
	values[name] = value
	notify()
	queueSave()
end

function Settings.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

function Settings.init()
	Remotes.Settings.OnClientEvent:Connect(function(data)
		if typeof(data) ~= "table" then
			return
		end
		for name, default in Settings.DEFAULTS do
			if typeof(data[name]) == typeof(default) then
				values[name] = data[name]
			end
		end
		Keybinds.load(data.binds)
		notify()
	end)
	Keybinds.onChanged(queueSave)
end

return Settings
