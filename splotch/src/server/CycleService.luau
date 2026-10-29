--[[
	CycleService: the Washout, a server-wide storm on a timer.

	Dry -> Warning -> Storm -> Dry ... The storm rinses away all paint, pushes
	anyone outside a shelter around with wind and slowly hurts them. Clients
	read the phase from workspace attributes:
		Phase        "Dry" | "Warning" | "Storm"
		PhaseEndsAt  workspace:GetServerTimeNow() when the phase ends
		Wind         Vector3, the storm's push direction (unit)
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)

local CombatService = require(script.Parent.CombatService)
local PaintService = require(script.Parent.PaintService)
local State = require(script.Parent.State)
local World = require(script.Parent.World)

local CycleService = {}

local TICK = 0.25

local phase = "Dry"
local phaseEndsAt = 0

local function setPhase(name: string, duration: number)
	phase = name
	phaseEndsAt = os.clock() + duration
	workspace:SetAttribute("Phase", name)
	workspace:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + duration)
end

local function startStorm()
	local angle = math.random() * math.pi * 2
	workspace:SetAttribute("Wind", Vector3.new(math.cos(angle), 0, math.sin(angle)))
	setPhase("Storm", Config.STORM_DURATION)
	PaintService.clearAll()
	PaintService.setLifetime(Config.STORM_PAINT_LIFETIME)
	Remotes.Notify:FireAllClients("THE WASHOUT IS HERE", "storm")
end

local function endStorm()
	PaintService.setLifetime(Config.PAINT_LIFETIME)
	setPhase("Dry", Config.DRY_DURATION)
	Remotes.Notify:FireAllClients("The storm has passed", "info")
end

local function advance()
	if phase == "Dry" then
		setPhase("Warning", Config.WARNING_DURATION)
		Remotes.Notify:FireAllClients("WASHOUT INCOMING - GET UNDER A ROOF", "warning")
	elseif phase == "Warning" then
		startStorm()
	else
		endStorm()
	end
end

local function stormTick(dt: number)
	for key in State.all() do
		local _, _, root = World.alive(key)
		if root and World.isPlayer(key) and not Zones.contains(Zones.SHELTER, root.Position) then
			CombatService.drain(key, Config.STORM_DAMAGE * dt, 0, "washout")
		end
	end
end

function CycleService.init()
	workspace:SetAttribute("Wind", Vector3.new(1, 0, 0))
	setPhase("Dry", Config.DRY_DURATION)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < TICK then
			return
		end
		if phase == "Storm" then
			stormTick(elapsed)
		end
		elapsed = 0
		if os.clock() >= phaseEndsAt then
			advance()
		end
	end)
end

return CycleService
