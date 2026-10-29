--[[
	CharacterMenu: pick who you play. Opens on your first spawn and with the
	Characters key (M) afterwards. Picking a character respawns you as them
	(not allowed for a few seconds after taking damage). The backdrop is a
	modal button, which frees the mouse even in shift lock.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Palette = require(Shared.Palette)
local Remotes = require(Shared.Remotes)

local Keybinds = require(script.Parent.Keybinds)
local Sounds = require(script.Parent.Sounds)
local Ui = require(script.Parent.Ui)

local CharacterMenu = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local cards: { [string]: UIStroke } = {}
local footer: TextLabel

local WEAPON_LINES = {
	Brush = "Weapon: wide paint brush (fast swings)",
	Roller = "Weapon: giant paint roller (heavy swings)",
}

local function refreshSelection()
	local current = player:GetAttribute("Kit")
	local color = Palette.color(player:GetAttribute("ColorId"))
	for name, stroke in cards do
		stroke.Color = if name == current then color else Color3.new(1, 1, 1)
		stroke.Transparency = if name == current then 0 else 0.8
		stroke.Thickness = if name == current then 3 else 1
	end
	footer.Text = string.format(
		"Press [%s] any time to switch  ·  Training dummies are next to the spawn",
		Keybinds.label("Characters")
	)
end

local function setOpen(open: boolean)
	gui.Enabled = open
	if open then
		refreshSelection()
	end
end

local function card(parent: Instance, order: number, def: Characters.Character)
	local stroke = Ui.stroke(1, Color3.new(1, 1, 1), 0.8)
	local button = Ui.create("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(360, 430),
		BackgroundColor3 = Color3.fromRGB(16, 16, 22),
		BackgroundTransparency = 0.04,
		AutoButtonColor = true,
		Text = "",
		Parent = parent,
	}, {
		Ui.corner(10),
		stroke,
		Ui.create("UIPadding", {
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 16),
		}),
	})
	cards[def.name] = stroke

	Ui.label({
		Size = UDim2.new(1, 0, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT_TAG,
		TextSize = 40,
		Text = string.upper(def.name),
		Parent = button,
	})
	Ui.label({
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextSize = 16,
		TextColor3 = Ui.MUTED,
		Text = def.tagline,
		Parent = button,
	})
	Ui.label({
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 15,
		TextColor3 = Ui.ACCENT,
		Text = WEAPON_LINES[def.weapon] or "",
		Parent = button,
	})

	local lines = {}
	for index, skill in def.skills do
		table.insert(
			lines,
			string.format("<font color='#ffc440'><b>%d</b></font>  <b>%s</b>", index, string.upper(skill.name))
		)
		table.insert(lines, string.format("<font color='#a5a8b4'>%s</font>", skill.description))
	end
	Ui.label({
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 1, -116),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		RichText = true,
		TextSize = 15,
		LineHeight = 1.05,
		Text = table.concat(lines, "\n"),
		Parent = button,
	})

	button.Activated:Connect(function()
		Sounds.play("UiClick")
		if player:GetAttribute("Kit") ~= def.name or not player.Character then
			Remotes.Action:FireServer("SelectKit", def.name)
		end
		setOpen(false)
	end)
end

function CharacterMenu.toggle()
	setOpen(not gui.Enabled)
end

function CharacterMenu.init()
	gui = Ui.create("ScreenGui", {
		Name = "CharacterMenu",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local backdrop = Ui.create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		AutoButtonColor = false,
		Modal = true,
		Text = "",
		Parent = gui,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.1, 0),
		Size = UDim2.fromOffset(760, 56),
		Font = Ui.FONT_TAG,
		TextSize = 48,
		Text = "PICK YOUR PAINTER",
		Parent = backdrop,
	})
	footer = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.1, 58),
		Size = UDim2.fromOffset(760, 22),
		TextColor3 = Ui.MUTED,
		TextSize = 17,
		Text = "",
		Parent = backdrop,
	})
	local row = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.57),
		Size = UDim2.fromOffset(760, 430),
		BackgroundTransparency = 1,
		Parent = backdrop,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 30),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, name in Characters.ORDER do
		card(row, index, Characters.DEFS[name])
	end

	player:GetAttributeChangedSignal("Kit"):Connect(refreshSelection)
	Keybinds.onChanged(refreshSelection)
	refreshSelection()
	-- First time in: show the menu.
	setOpen(true)
end

return CharacterMenu
