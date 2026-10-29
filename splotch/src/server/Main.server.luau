--[[
	Server entry point. Builds the map synchronously (before anyone can spawn)
	and starts every service.
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Paintables = require(Shared.Paintables)
require(Shared.Remotes) -- creates the RemoteEvents

local ActionService = require(script.Parent.ActionService)
local CycleService = require(script.Parent.CycleService)
local HazardService = require(script.Parent.HazardService)
local MapBuilder = require(script.Parent.MapBuilder)
local PaintService = require(script.Parent.PaintService)
local PlayerService = require(script.Parent.PlayerService)
local ProjectileService = require(script.Parent.ProjectileService)
local World = require(script.Parent.World)

local map, zones = MapBuilder.build()
map.Parent = workspace
zones.Parent = workspace
World.setMap(map)
map:SetAttribute("PaintableCount", Paintables.assignIds())

PaintService.init()
ProjectileService.init()
PlayerService.init()
ActionService.init()
HazardService.init()
CycleService.init()
