--[[
	SettingsMenu: keybinds and preferences.

	CONTROLS  every action with its key; click a key, then press the new one
	          (Escape cancels). A key already in use swaps with the old one.
	          Plus Auto Run (run without double-tapping W).
	GAMEPLAY  screen shake, flashing lights / impact frames, damage counter,
	          damage numbers.
	AUDIO     sound effect volume.

	The menu's backdrop is a modal button, which frees the mouse even in
	shift lock.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Keybinds = require(script.Parent.Keybinds)
local Settings = require(script.Parent.Settings)
local Sounds = require(script.Parent.Sounds)
local Ui = require(script.Parent.Ui)

local SettingsMenu = {}

local player = Players.LocalPlayer

local gui: ScreenGui
local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local refreshers: { () -> () } = {}
local capturing: string? = nil

local TOGGLES = {
	{ key = "screenShake", label = "Screen shake" },
	{ key = "flashingLights", label = "Flashing lights and impact frames" },
	{ key = "damageCounter", label = "Combo damage counter" },
	{ key = "damageNumbers", label = "Floating damage numbers" },
}

local function refresh()
	for _, refresher in refreshers do
		refresher()
	end
end

local function row(parent: Instance, order: number, label: string): Frame
	local frame = Ui.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = if order % 2 == 0 then 0.96 else 1,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Ui.corner(4) })
	Ui.label({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 17,
		Text = label,
		Parent = frame,
	})
	return frame
end

local function pillButton(parent: Instance, text: string): TextButton
	return Ui.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 28),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.1,
		AutoButtonColor = true,
		Font = Ui.FONT,
		TextSize = 16,
		TextColor3 = Ui.TEXT,
		Text = text,
		Parent = parent,
	}, { Ui.corner(4), Ui.stroke(1, Color3.new(1, 1, 1), 0.7) })
end

local function page(name: string, parent: Instance): Frame
	local frame = Ui.create("ScrollingFrame", {
		Name = name,
		Position = UDim2.fromOffset(20, 110),
		Size = UDim2.new(1, -40, 1, -170),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = parent,
	}, {
		Ui.create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	pages[name] = frame
	return frame
end

local function showPage(name: string)
	for pageName, frame in pages do
		frame.Visible = pageName == name
		local tab = tabButtons[pageName]
		if tab then
			tab.TextColor3 = if pageName == name then Ui.ACCENT else Ui.MUTED
		end
	end
end

local function toggleRow(parent: Instance, order: number, key: string, label: string)
	local frame = row(parent, order, label)
	local button = pillButton(frame, "")
	button.Size = UDim2.fromOffset(80, 28)
	table.insert(refreshers, function()
		local on = Settings.get(key) == true
		button.Text = if on then "ON" else "OFF"
		button.TextColor3 = if on then Ui.ACCENT else Ui.MUTED
	end)
	button.Activated:Connect(function()
		Settings.set(key, not Settings.get(key))
		Sounds.play("UiClick")
	end)
end

local function buildControls(parent: Instance)
	local controls = page("CONTROLS", parent)
	for order, action in Keybinds.ACTIONS do
		local frame = row(controls, order, action.label)
		local button = pillButton(frame, "")
		table.insert(refreshers, function()
			if capturing == action.id then
				button.Text = "PRESS A KEY..."
				button.TextColor3 = Ui.ACCENT
			else
				button.Text = Keybinds.label(action.id)
				button.TextColor3 = Ui.TEXT
			end
		end)
		button.Activated:Connect(function()
			capturing = action.id
			Keybinds.capturing = true
			Sounds.play("UiClick")
			refresh()
		end)
	end
	toggleRow(controls, #Keybinds.ACTIONS + 1, "autoRun", "Auto run (no double-tap W)")

	local resetRow = row(controls, #Keybinds.ACTIONS + 2, "Movement: WASD, Space, Left Shift = shift lock")
	local reset = pillButton(resetRow, "RESET KEYS")
	reset.Activated:Connect(function()
		Keybinds.reset()
		Sounds.play("UiClick")
	end)
end

local function buildGameplay(parent: Instance)
	local gameplay = page("GAMEPLAY", parent)
	for order, toggle in TOGGLES do
		toggleRow(gameplay, order, toggle.key, toggle.label)
	end
end

local function buildAudio(parent: Instance)
	local audio = page("AUDIO", parent)
	local frame = row(audio, 1, "Sound effects volume")
	local value = Ui.label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -60, 0.5, 0),
		Size = UDim2.fromOffset(70, 28),
		Font = Ui.FONT_NUMBERS,
		TextSize = 22,
		Parent = frame,
	})
	local minus = pillButton(frame, "-")
	minus.Size = UDim2.fromOffset(40, 28)
	minus.Position = UDim2.new(1, -140, 0.5, 0)
	local plus = pillButton(frame, "+")
	plus.Size = UDim2.fromOffset(40, 28)
	table.insert(refreshers, function()
		value.Text = string.format("%d%%", math.floor((Settings.get("sfxVolume") or 1) * 100 + 0.5))
	end)
	local function change(delta: number)
		local volume = math.clamp((Settings.get("sfxVolume") or 1) + delta, 0, 2)
		Settings.set("sfxVolume", math.floor(volume * 10 + 0.5) / 10)
		Sounds.play("UiClick")
	end
	minus.Activated:Connect(function()
		change(-0.1)
	end)
	plus.Activated:Connect(function()
		change(0.1)
	end)
end

function SettingsMenu.toggle()
	gui.Enabled = not gui.Enabled
	if not gui.Enabled then
		capturing = nil
		Keybinds.capturing = false
	end
	refresh()
end

function SettingsMenu.init()
	gui = Ui.create("ScreenGui", {
		Name = "SettingsMenu",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- A modal button as the backdrop frees the mouse while the menu is open.
	Ui.create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Modal = true,
		Text = "",
		Parent = gui,
	})
	local panel = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 560),
		BackgroundColor3 = Color3.fromRGB(16, 16, 22),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(1, Color3.new(1, 1, 1), 0.8) })
	Ui.label({
		Position = UDim2.fromOffset(22, 12),
		Size = UDim2.fromOffset(300, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT_TAG,
		TextSize = 34,
		Text = "SETTINGS",
		Parent = panel,
	})
	local close = Ui.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Ui.PANEL,
		Font = Ui.FONT,
		TextSize = 20,
		TextColor3 = Ui.TEXT,
		Text = "X",
		Parent = panel,
	}, { Ui.corner(6) })
	close.Activated:Connect(SettingsMenu.toggle)

	local tabs = Ui.create("Frame", {
		Position = UDim2.fromOffset(20, 64),
		Size = UDim2.new(1, -40, 0, 36),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, name in { "CONTROLS", "GAMEPLAY", "AUDIO" } do
		local tab = Ui.create("TextButton", {
			LayoutOrder = order,
			Size = UDim2.fromOffset(110, 32),
			BackgroundTransparency = 1,
			Font = Ui.FONT,
			TextSize = 20,
			TextColor3 = Ui.MUTED,
			Text = name,
			Parent = tabs,
		})
		tab.Activated:Connect(function()
			showPage(name)
			Sounds.play("UiClick")
		end)
		tabButtons[name] = tab
	end

	buildControls(panel)
	buildGameplay(panel)
	buildAudio(panel)
	showPage("CONTROLS")

	Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -40, 0, 20),
		TextSize = 14,
		TextColor3 = Ui.MUTED,
		Text = "Saved automatically to your account.",
		Parent = panel,
	})

	-- Key capture for rebinding.
	UserInputService.InputBegan:Connect(function(input)
		if not capturing then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			capturing = nil
			Keybinds.capturing = false
			refresh()
			return
		end
		local name = Keybinds.inputName(input)
		if name then
			Keybinds.set(capturing, name)
			capturing = nil
			-- Let this key's own release pass before actions see keys again.
			task.delay(0.15, function()
				Keybinds.capturing = false
			end)
			Sounds.play("UiClick")
			refresh()
		end
	end)

	Keybinds.onChanged(refresh)
	Settings.onChanged(refresh)
	refresh()
end

return SettingsMenu
