--[[
	Client entry point: starts every controller in dependency order.
]]

local StarterGui = game:GetService("StarterGui")

local CameraController = require(script.Parent.CameraController)
local CharacterMenu = require(script.Parent.CharacterMenu)
local CharacterVisuals = require(script.Parent.CharacterVisuals)
local CombatController = require(script.Parent.CombatController)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local MovementController = require(script.Parent.MovementController)
local PaintRenderer = require(script.Parent.PaintRenderer)
local Weather = require(script.Parent.Weather)

-- Health and tools are shown by our own HUD; there are no tools.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

PaintRenderer.init()
CameraController.init()
MovementController.init()
CharacterVisuals.init()
Hud.init()
Fx.init()
CombatController.init()
CharacterMenu.init()
CombatController.setMenuToggle(CharacterMenu.toggle)
Weather.init()
