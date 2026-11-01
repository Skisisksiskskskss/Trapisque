--!strict
-- Assigns plots, builds/rebuilds bases, owns door state (broken / repaired / shielded) and keeps intruders out
-- of bases whose door is intact.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local BaseBuilder = require(script.Parent.Parent.Modules.BaseBuilder)
local PlayerStats = require(script.Parent.Parent.Modules.PlayerStats)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

export type Plot = {
	Index: number,
	CFrame: CFrame,
	Folder: Folder,
	Owner: Player?,
	Parts: BaseBuilder.BaseParts?,
	Empty: Model?,
	DoorBrokenUntil: number, -- server time
}

local PlotService = {}

PlotService.BaseBuilt = Signal.new() :: Signal.Signal<Player, Plot>
PlotService.DoorChanged = Signal.new() :: Signal.Signal<Plot>

local plots: { Plot } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

function PlotService.Get(index: number): Plot?
	return plots[index]
end

function PlotService.All(): { Plot }
	return plots
end

function PlotService.ForPlayer(player: Player): Plot?
	local session = DataService.GetSession(player)
	if session and session.Plot then
		return plots[session.Plot]
	end
	return nil
end

function PlotService.IsShielded(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return true
	end
	return data.Tier <= 1 and (data.Stats.Playtime or 0) < GameConfig.NewbieShieldMinutes * 60 and data.Rebirths == 0
end

function PlotService.IsDoorBroken(plot: Plot): boolean
	return plot.DoorBrokenUntil > now()
end

-- Door is open for raiders: broken and the owner isn't protected by the newbie shield.
function PlotService.IsRaidable(plot: Plot): boolean
	local owner = plot.Owner
	if not owner or not PlotService.IsDoorBroken(plot) then
		return false
	end
	return not PlotService.IsShielded(owner)
end

local function setDoorVisual(plot: Plot, broken: boolean)
	local parts = plot.Parts
	if not parts then
		return
	end
	for _, child in parts.Door:GetDescendants() do
		if child:IsA("BasePart") then
			local base = child:GetAttribute("BaseTransparency")
			child.Transparency = if broken then 1 else (if type(base) == "number" then base else 0)
			if child.Name == "Panel" then
				child.CanCollide = not broken
			end
		end
	end
end

local function publishDoor(plot: Plot)
	local broken = PlotService.IsDoorBroken(plot)
	plot.Folder:SetAttribute("DoorBrokenUntil", if broken then plot.DoorBrokenUntil else 0)
	plot.Folder:SetAttribute("DoorOpen", PlotService.IsRaidable(plot))
	setDoorVisual(plot, broken)
	PlotService.DoorChanged:Fire(plot)
end

function PlotService.BreakDoor(plot: Plot, seconds: number)
	plot.DoorBrokenUntil = now() + seconds
	publishDoor(plot)
end

function PlotService.RepairDoor(plot: Plot)
	plot.DoorBrokenUntil = 0
	publishDoor(plot)
end

function PlotService.PublishStats(player: Player)
	local plot = PlotService.ForPlayer(player)
	local data = DataService.Get(player)
	local session = DataService.GetSession(player)
	if not plot or not data or not session then
		return
	end
	plot.Folder:SetAttribute("Tier", data.Tier)
	plot.Folder:SetAttribute("Rebirths", data.Rebirths)
	plot.Folder:SetAttribute("CrystalPower", PlayerStats.CrystalPower(data, session.Passes))
	plot.Folder:SetAttribute("DoorStrength", PlayerStats.DoorStrength(data, session.Passes))
	plot.Folder:SetAttribute("Shielded", PlotService.IsShielded(player))
	plot.Folder:SetAttribute("IronDoorUntil", session.IronDoorUntil)
end

local function buildFor(player: Player, plot: Plot)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if plot.Parts then
		plot.Parts.Model:Destroy()
		plot.Parts = nil
	end
	if plot.Empty then
		plot.Empty:Destroy()
		plot.Empty = nil
	end
	plot.Parts = BaseBuilder.Build(plot.CFrame, data.Tier, data.Rebirths, player.DisplayName, plot.Folder)
	publishDoor(plot)
	PlotService.PublishStats(player)
	PlotService.BaseBuilt:Fire(player, plot)
end

-- Rebuilds the base in the player's current tier theme (after a tier upgrade or rebirth).
function PlotService.Rebuild(player: Player)
	local plot = PlotService.ForPlayer(player)
	if plot then
		buildFor(player, plot)
	end
end

function PlotService.SpawnCFrame(plot: Plot): CFrame
	return plot.CFrame * CFrame.new(0, 4, -GameConfig.BaseSize / 2 + 8) * CFrame.Angles(0, math.rad(180), 0)
end

function PlotService.CrystalPosition(plot: Plot): Vector3
	return (plot.CFrame * CFrame.new(0, BaseBuilder.CrystalHeight, 0)).Position
end

function PlotService.DoorPosition(plot: Plot): Vector3
	return (plot.CFrame * CFrame.new(0, 1, -GameConfig.BaseSize / 2 + 1)).Position
end

-- True when a world position is inside the plot's walls.
function PlotService.Contains(plot: Plot, position: Vector3, margin: number?): boolean
	local localPos = plot.CFrame:PointToObjectSpace(position)
	local half = GameConfig.BaseSize / 2 - (margin or 1.5)
	return math.abs(localPos.X) < half and math.abs(localPos.Z) < half and localPos.Y < 60
end

local function teleportHome(player: Player)
	local plot = PlotService.ForPlayer(player)
	local character = player.Character
	if plot and character then
		character:PivotTo(PlotService.SpawnCFrame(plot))
	end
end
PlotService.TeleportHome = teleportHome

local function assign(player: Player)
	for _, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			local session = DataService.GetSession(player)
			if session then
				session.Plot = plot.Index
			end
			plot.Folder:SetAttribute("OwnerId", player.UserId)
			plot.Folder:SetAttribute("OwnerName", player.DisplayName)
			player:SetAttribute("Plot", plot.Index)
			plot.DoorBrokenUntil = 0
			buildFor(player, plot)
			if player.Character then
				teleportHome(player)
			end
			return
		end
	end
	player:Kick("This server is full. Please join another one!")
end

local function unassign(player: Player)
	for _, plot in plots do
		if plot.Owner == player then
			plot.Owner = nil
			plot.DoorBrokenUntil = 0
			plot.Folder:SetAttribute("OwnerId", 0)
			plot.Folder:SetAttribute("OwnerName", "")
			plot.Folder:SetAttribute("DoorOpen", false)
			plot.Folder:SetAttribute("DoorBrokenUntil", 0)
			if plot.Parts then
				plot.Parts.Model:Destroy()
				plot.Parts = nil
			end
			plot.Empty = BaseBuilder.BuildEmpty(plot.CFrame, plot.Folder)
		end
	end
end

local function onRepair(player: Player)
	if not DataService.Throttle(player, "Repair", 0.4) then
		return
	end
	local plot = PlotService.ForPlayer(player)
	local character = player.Character
	if not plot or not character or not PlotService.IsDoorBroken(plot) then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - PlotService.DoorPosition(plot)).Magnitude > 16 then
		return
	end
	local session = DataService.GetSession(player)
	local amount = GameConfig.DoorRepairPerHoldSecond * 1.5
	if session and session.Passes.Fortress then
		amount *= 2
	end
	plot.DoorBrokenUntil -= amount
	if plot.DoorBrokenUntil <= now() then
		PlotService.RepairDoor(plot)
	else
		publishDoor(plot)
	end
end

function PlotService.Init()
	for index = 1, GameConfig.MaxPlots do
		local folder = Instance.new("Folder")
		folder.Name = "Plot" .. index
		folder:SetAttribute("PlotIndex", index)
		folder:SetAttribute("OwnerId", 0)
		folder:SetAttribute("Angle", MapService.PlotAngle(index))
		folder.Parent = MapService.PlotsFolder()
		local plot: Plot = {
			Index = index,
			CFrame = MapService.PlotCFrame(index),
			Folder = folder,
			Owner = nil,
			Parts = nil,
			Empty = nil,
			DoorBrokenUntil = 0,
		}
		plot.Empty = BaseBuilder.BuildEmpty(plot.CFrame, folder)
		plots[index] = plot
	end
end

function PlotService.Start()
	DataService.Loaded:Connect(function(player)
		assign(player)
	end)
	DataService.Releasing:Connect(function(player)
		unassign(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		unassign(player)
	end)

	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.1)
			teleportHome(player)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = GameConfig.PlayerWalkSpeed
			end
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
	end

	Net.Event("Repair").OnServerEvent:Connect(onRepair)

	-- Door timers + intruder enforcement.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local t = now()
			for _, plot in plots do
				local owner = plot.Owner
				if not owner then
					continue
				end
				if plot.DoorBrokenUntil > 0 and plot.DoorBrokenUntil <= t then
					PlotService.RepairDoor(plot)
				end
				if PlotService.IsRaidable(plot) then
					continue
				end
				for _, other in Players:GetPlayers() do
					if other == owner then
						continue
					end
					local character = other.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and PlotService.Contains(plot, root.Position) then
						local outside = plot.CFrame * CFrame.new(0, 4, -GameConfig.BaseSize / 2 - 6)
						if character then
							character:PivotTo(outside)
						end
					end
				end
			end
		end
	end)
end

return PlotService
