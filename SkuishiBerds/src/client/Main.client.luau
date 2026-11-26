--[[
	Skuishi Berds - client entry point.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The whole game is drawn in 2D UI: hide the default 3D-game HUD pieces
for _, kind in
	{
		Enum.CoreGuiType.Backpack,
		Enum.CoreGuiType.Health,
		Enum.CoreGuiType.EmotesMenu,
		Enum.CoreGuiType.PlayerList,
	}
do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(kind, false)
	end)
end

-- Portrait on phones (like the original web game); no effect on PC/console
playerGui.ScreenOrientation = Enum.ScreenOrientation.Portrait

-- No character is spawned; park the camera
local camera = workspace.CurrentCamera
if camera then
	camera.CameraType = Enum.CameraType.Scriptable
end

local App = require(script.Parent.UI.App)
App.init()
