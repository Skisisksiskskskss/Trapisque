--[[
	VolumeRows
	The Music and Sound effects sliders, shown in Settings and in the match menu.
	Moving one changes the volume straight away; letting go saves it to your profile.

		VolumeRows.build(list, firstLayoutOrder)
]]

local UI = script.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)

local Client = UI.Parent
local Net = require(Client.Net)
local State = require(Client.State)
local Sound = require(Client.Sound)

local C = Theme.C

local VolumeRows = {}

local function save(key: string, v: number)
	local profile = State.get("profile")
	local settings = table.clone(profile and profile.settings or {})
	settings[key] = v
	if key == "musicVolume" then
		settings.music = v > 0
	else
		settings.sfx = v > 0
	end
	if profile then
		profile.settings = settings
	end
	task.spawn(Net.request, "settings.save", { settings = settings })
end

function VolumeRows.build(parent: Instance, order: number)
	local rows = {
		{ label = "Music", key = "musicVolume", get = Sound.getMusicVolume, set = Sound.setMusicVolume },
		{ label = "Sound effects", key = "sfxVolume", get = Sound.getVolume, set = Sound.setVolume },
	}
	for i, r in rows do
		local row = Util.frame(parent, { Name = r.key, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order + i - 1 })
		Widgets.label(row, {
			text = r.label,
			font = "heavy",
			size = 18,
			color = C.text,
			sizeUDim = UDim2.new(0.38, 0, 1, 0),
		})
		local pct = Widgets.label(row, {
			text = "",
			font = "chunky",
			size = 16,
			color = C.textSoft,
			align = "right",
			sizeUDim = UDim2.new(0, 50, 1, 0),
			anchor = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
		})
		local function showPct(v: number)
			pct.Text = if v <= 0 then "OFF" else (tostring(math.floor(v * 100 + 0.5)) .. "%")
		end
		local start = r.get()
		showPct(start)
		Widgets.slider(row, {
			value = start,
			size = UDim2.new(0.62, -56, 1, 0),
			position = UDim2.fromScale(0.38, 0),
			onChange = function(v)
				r.set(v)
				showPct(v)
			end,
			onRelease = function(v)
				save(r.key, v)
				if r.key == "sfxVolume" then
					-- a sample at the new level
					Sound.play("coin")
				end
			end,
		})
	end
end

return VolumeRows
