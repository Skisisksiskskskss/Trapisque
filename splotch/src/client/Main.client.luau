--[[
	Client entry point: starts every controller in dependency order.
]]

local StarterGui = game:GetService("StarterGui")

local Animator = require(script.Parent.Animator)
local CameraController = require(script.Parent.CameraController)
local CharacterMenu = require(script.Parent.CharacterMenu)
local CharacterVisuals = require(script.Parent.CharacterVisuals)
local CombatController = require(script.Parent.CombatController)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local MovementController = require(script.Parent.MovementController)
local PaintRenderer = require(script.Parent.PaintRenderer)
local Settings = require(script.Parent.Settings)
local SettingsMenu = require(script.Parent.SettingsMenu)
local Weather = require(script.Parent.Weather)

-- Health and tools are shown by our own HUD; there are no tools.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

Settings.init()
PaintRenderer.init()
CameraController.init()
Animator.init()
MovementController.init()
CharacterVisuals.init()
Hud.init()
Fx.init()
CombatController.init()
CharacterMenu.init()
SettingsMenu.init()
Weather.init()

for name, toggle in { Characters = CharacterMenu.toggle, Settings = SettingsMenu.toggle } do
	CombatController.setMenuToggle(name, toggle)
	Hud.setMenuCallback(name, toggle)
end
