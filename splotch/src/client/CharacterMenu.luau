--[[
	CharacterMenu: pick who you play. Opens automatically on your first spawn
	and with M afterwards. Picking a character respawns you as them (not allowed
	for a few seconds after taking damage).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Characters = require(Shared.Characters)
local Palette = require(Shared.Palette)
local Remotes = require(Shared.Remotes)

local CameraController = require(script.Parent.CameraController)
local Sounds = require(script.Parent.Sounds)
local Ui = require(script.Parent.Ui)

local CharacterMenu = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local cards: { [string]: UIStroke } = {}

local function setOpen(open: boolean)
	gui.Enabled = open
	CameraController.setCursorFree("menu", open)
end

local function refreshSelection()
	local current = player:GetAttribute("Kit")
	local color = Palette.color(player:GetAttribute("ColorId"))
	for name, stroke in cards do
		stroke.Color = if name == current then color else Color3.new(1, 1, 1)
		stroke.Transparency = if name == current then 0 else 0.8
	end
end

local function card(parent: Instance, order: number, def: Characters.Character)
	local stroke = Ui.stroke(3, Color3.new(1, 1, 1), 0.8)
	local button = Ui.create("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(330, 380),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.1,
		AutoButtonColor = true,
		Text = "",
		Parent = parent,
	}, {
		Ui.corner(14),
		stroke,
		Ui.create("UIPadding", {
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 16),
		}),
	})
	cards[def.name] = stroke

	Ui.label({
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT_HEAVY,
		TextSize = 36,
		Text = string.upper(def.name),
		Parent = button,
	})
	Ui.label({
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextSize = 15,
		TextColor3 = Ui.MUTED,
		Text = def.tagline,
		Parent = button,
	})

	local lines = {
		string.format(
			"<font color='#ff8c28'><b>HP</b></font> %d   <font color='#ff8c28'><b>M1</b></font> %s",
			def.maxHealth,
			def.primary.name
		),
		"",
	}
	for _, skill in def.skills do
		table.insert(lines, string.format("<font color='#ff8c28'><b>%s</b></font>  <b>%s</b>", skill.key, skill.name))
		table.insert(lines, string.format("<font color='#aaacb6'>%s</font>", skill.description))
	end
	Ui.label({
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 1, -92),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		RichText = true,
		TextSize = 15,
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
	refreshSelection()
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
	local backdrop = Ui.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Parent = gui,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.12, 0),
		Size = UDim2.fromOffset(700, 50),
		Font = Ui.FONT_HEAVY,
		TextSize = 44,
		Text = "PICK YOUR CHARACTER",
		Parent = backdrop,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.12, 52),
		Size = UDim2.fromOffset(700, 24),
		TextColor3 = Ui.MUTED,
		Text = "Press M any time to switch",
		Parent = backdrop,
	})
	local row = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(700, 380),
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
	refreshSelection()
	-- First time in: show the menu.
	setOpen(true)
end

return CharacterMenu
