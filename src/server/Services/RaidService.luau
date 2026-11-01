--!strict
-- Stealing and bonking. A thief may grab a brainrot only from a raidable base (door broken, no newbie shield),
-- carries it above their head at reduced speed, and keeps it only by reaching their own base. Any bonk makes them
-- drop it and it flies home. Every step is validated on the server: ownership, door state, distance, room in the
-- thief's base, per-tick movement speed (teleport exploits cancel the steal) and carry timeout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Config.Brainrots)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local BrainrotBuilder = require(Shared.Modules.BrainrotBuilder)
local BrainrotStats = require(Shared.Modules.BrainrotStats)
local DataSchema = require(Shared.Modules.DataSchema)
local Net = require(Shared.Modules.Net)
local BrainrotService = require(script.Parent.BrainrotService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

type Carry = {
	Thief: Player,
	Victim: Player,
	Uid: string,
	Slot: number,
	Record: DataSchema.BrainrotRecord,
	Started: number,
	Model: Model,
	LastPosition: Vector3,
	LastCheck: number,
}

local RaidService = {}

local carries: { [Player]: Carry } = {}
local toolTemplate: Tool

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function notify(player: Player, text: string, kind: string)
	Net.Event("Notify"):FireClient(player, text, kind)
end

local function announce(text: string, color: Color3)
	Net.Event("Announce"):FireAllClients(text, color)
end

local function setSpeed(player: Player, carrying: boolean)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = GameConfig.PlayerWalkSpeed * (if carrying then GameConfig.CarrySpeedMultiplier else 1)
	end
	player:SetAttribute("Carrying", carrying)
end

local function endCarry(carry: Carry)
	carries[carry.Thief] = nil
	if carry.Model.Parent then
		carry.Model:Destroy()
	end
	if carry.Thief.Parent then
		setSpeed(carry.Thief, false)
	end
	if carry.Victim.Parent then
		BrainrotService.SetCarried(carry.Victim, carry.Slot, false)
	end
end

-- The brainrot flies back to its owner's pedestal.
local function returnHome(carry: Carry, reason: string)
	local position = carry.Model.PrimaryPart and carry.Model.PrimaryPart.Position
	endCarry(carry)
	if position then
		Net.Event("Effect"):FireAllClients("Return", { From = position, Plot = carry.Victim:GetAttribute("Plot") })
	end
	if carry.Thief.Parent then
		notify(carry.Thief, reason, "bad")
	end
	if carry.Victim.Parent then
		notify(
			carry.Victim,
			"Your " .. (Brainrots.ById[carry.Record.Id] or Brainrots.List[1]).Name .. " came back home!",
			"good"
		)
	end
end

local function complete(carry: Carry)
	local victimData = DataService.Get(carry.Victim)
	if not victimData or victimData.Brainrots[carry.Uid] == nil then
		endCarry(carry)
		return
	end
	endCarry(carry)
	local record = BrainrotService.Remove(carry.Victim, carry.Uid)
	if not record then
		return
	end
	BrainrotService.Add(carry.Thief, record.Id, record.Mutation, record.Size, "Steal", os.time())
	DataService.AddStat(carry.Thief, "Steals", 1)
	DataService.AddStat(carry.Victim, "Stolen", 1)
	local name = BrainrotStats.DisplayName(record.Id, record.Mutation, record.Size)
	notify(carry.Thief, "You stole " .. name .. "! 😈", "good")
	notify(carry.Victim, carry.Thief.DisplayName .. " stole your " .. name .. "! Upgrade your door!", "bad")
	Net.Event("Effect"):FireClient(carry.Thief, "Stolen", { Name = name })
	local def = Brainrots.ById[record.Id]
	if def and def.Rarity >= 4 then
		local rarity = Rarities.Get(def.Rarity)
		announce(
			string.format(
				"%s STOLE %s's %s %s!",
				carry.Thief.DisplayName,
				carry.Victim.DisplayName,
				string.upper(rarity.Name),
				def.Name
			),
			rarity.Color
		)
	end
end

local function canHold(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	return BrainrotService.FirstFreeSlot(data) ~= nil or BrainrotService.StorageCount(data) < GameConfig.StorageMax
end

local function onSteal(thief: Player, plotIndex: unknown, slot: unknown)
	if not DataService.Throttle(thief, "Steal", 0.5) then
		return
	end
	if type(plotIndex) ~= "number" or type(slot) ~= "number" or carries[thief] then
		return
	end
	local thiefPlot = PlotService.ForPlayer(thief)
	local plot = PlotService.Get(plotIndex)
	local victim = plot and plot.Owner
	if not thiefPlot or not plot or not victim or victim == thief then
		return
	end
	if not PlotService.IsRaidable(plot) then
		notify(thief, "That door isn't broken!", "warn")
		return
	end
	local victimData = DataService.Get(victim)
	if not victimData then
		return
	end
	local uid = victimData.Slots[tostring(slot)]
	local record = uid and victimData.Brainrots[uid]
	if not uid or not record then
		return
	end
	for _, other in carries do
		if other.Victim == victim and other.Uid == uid then
			return
		end
	end
	if (record.StolenAt or 0) + GameConfig.StealImmunitySeconds > os.time() then
		notify(thief, "That brainrot was just stolen. It's protected for a bit!", "warn")
		return
	end
	if not canHold(thief) then
		notify(thief, "Your base and storage are full!", "warn")
		return
	end
	local pedestal = BrainrotService.ModelAt(victim, slot)
	local thiefRoot = rootOf(thief)
	if not pedestal or not pedestal.PrimaryPart or not thiefRoot then
		return
	end
	if (thiefRoot.Position - pedestal.PrimaryPart.Position).Magnitude > 14 then
		return
	end

	-- Build the carried brainrot above the thief's head.
	local scale = BrainrotBuilder.FitScale(record.Id, 3.2, 3.2)
	local model = BrainrotBuilder.Build(record.Id, { Mutation = record.Mutation, Scale = scale })
	model.Name = "Carried"
	local carriedRoot = model.PrimaryPart :: BasePart
	model:PivotTo(thiefRoot.CFrame * CFrame.new(0, 3.4, 0))
	carriedRoot.Anchored = false
	carriedRoot.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = thiefRoot
	weld.Part1 = carriedRoot
	weld.Parent = carriedRoot
	model.Parent = thief.Character

	local carry: Carry = {
		Thief = thief,
		Victim = victim,
		Uid = uid,
		Slot = slot,
		Record = table.clone(record),
		Started = os.clock(),
		Model = model,
		LastPosition = thiefRoot.Position,
		LastCheck = os.clock(),
	}
	carries[thief] = carry
	BrainrotService.SetCarried(victim, slot, true)
	setSpeed(thief, true)
	local name = BrainrotStats.DisplayName(record.Id, record.Mutation, record.Size)
	notify(thief, "Got it! Run back to YOUR base before you get bonked!", "good")
	notify(victim, "🚨 " .. thief.DisplayName .. " is stealing your " .. name .. "! BONK THEM!", "bad")
	Net.Event("Effect"):FireClient(victim, "Alarm", {})
	local def = Brainrots.ById[record.Id]
	if def and def.Rarity >= 5 then
		announce(
			string.format("🚨 %s is stealing %s's %s!", thief.DisplayName, victim.DisplayName, def.Name),
			Color3.fromRGB(255, 90, 90)
		)
	end
end

-- Bonk: server picks the target itself (never trusts the client) within range and roughly in front.
local function bonk(attacker: Player)
	local session = DataService.GetSession(attacker)
	local root = rootOf(attacker)
	if not session or not root then
		return
	end
	local clock = os.clock()
	if clock - session.LastBonk < GameConfig.BonkCooldown then
		return
	end
	session.LastBonk = clock
	local best: Player? = nil
	local bestDistance = GameConfig.BonkRange
	for _, other in Players:GetPlayers() do
		if other ~= attacker then
			local otherRoot = rootOf(other)
			local humanoid = humanoidOf(other)
			if otherRoot and humanoid and humanoid.Health > 0 then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				local facing = if distance > 0.01 then root.CFrame.LookVector:Dot(offset.Unit) else 1
				if distance < bestDistance and facing > -0.2 then
					best = other
					bestDistance = distance
				end
			end
		end
	end
	if not best then
		return
	end
	local targetRoot = rootOf(best)
	if not targetRoot then
		return
	end
	local direction = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
	direction = if direction.Magnitude > 0.01 then direction.Unit else root.CFrame.LookVector
	Net.Event("Knockback"):FireClient(best, direction * GameConfig.BonkKnockback + Vector3.new(0, 28, 0))
	Net.Event("Effect"):FireAllClients("Bonk", { Position = targetRoot.Position })
	local carry = carries[best]
	if carry then
		returnHome(carry, "BONKED! You dropped the brainrot!")
		notify(attacker, "BONK! You stopped the thief! 🔨", "good")
		if carry.Victim ~= attacker and carry.Victim.Parent then
			notify(carry.Victim, attacker.DisplayName .. " bonked the thief for you!", "good")
		end
	end
end

local function buildTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bonk Bat"
	tool.ToolTip = "Bonk thieves to make them drop your brainrot!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 3.2, 0.5)
	handle.Color = Color3.fromRGB(150, 100, 60)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Cylinder
	head.Size = Vector3.new(2.2, 1.4, 1.4)
	head.Color = Color3.fromRGB(255, 90, 160)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	head.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head
	local band = Instance.new("Part")
	band.Name = "Band"
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.4, 1.5, 1.5)
	band.Color = Color3.fromRGB(255, 220, 60)
	band.Material = Enum.Material.Neon
	band.CanCollide = false
	band.Massless = true
	band.CFrame = head.CFrame
	band.Parent = tool
	local bandWeld = Instance.new("WeldConstraint")
	bandWeld.Part0 = head
	bandWeld.Part1 = band
	bandWeld.Parent = band
	return tool
end

local function giveTool(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild(toolTemplate.Name) then
		return
	end
	local tool = toolTemplate:Clone()
	tool.Activated:Connect(function()
		bonk(player)
	end)
	tool.Parent = backpack
end

function RaidService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
end

function RaidService.Init()
	toolTemplate = buildTool()
	toolTemplate.Parent = ServerStorage
end

function RaidService.Start()
	Net.Event("Steal").OnServerEvent:Connect(onSteal)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			local carry = carries[player]
			if carry then
				returnHome(carry, "You lost the brainrot!")
			end
			character:WaitForChild("Humanoid", 10)
			task.wait(0.2)
			giveTool(player)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Died:Connect(function()
					local current = carries[player]
					if current then
						returnHome(current, "You lost the brainrot!")
					end
				end)
			end
		end)
		if player.Character then
			giveTool(player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	-- Owner leaving: cancel every carry of their brainrots BEFORE their final save (prevents duplication).
	DataService.Releasing:Connect(function(player)
		for _, carry in carries do
			if carry.Victim == player or carry.Thief == player then
				endCarry(carry)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, carry in carries do
			if carry.Victim == player or carry.Thief == player then
				endCarry(carry)
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		for thief, carry in carries do
			if clock - carry.LastCheck < 0.2 then
				continue
			end
			local dt = clock - carry.LastCheck
			carry.LastCheck = clock
			local root = rootOf(thief)
			if not root or not thief.Parent or not carry.Victim.Parent then
				endCarry(carry)
				continue
			end
			if clock - carry.Started > GameConfig.CarryTimeout then
				returnHome(carry, "Too slow! The brainrot ran home.")
				continue
			end
			local moved = ((root.Position - carry.LastPosition) * Vector3.new(1, 0, 1)).Magnitude
			carry.LastPosition = root.Position
			local maxSpeed = GameConfig.PlayerWalkSpeed * GameConfig.CarrySpeedMultiplier * 1.6 + 8
			if moved / dt > maxSpeed then
				returnHome(carry, "The brainrot slipped away!")
				continue
			end
			local thiefPlot = PlotService.ForPlayer(thief)
			if thiefPlot and PlotService.Contains(thiefPlot, root.Position, 2) then
				complete(carry)
			end
		end
	end)
end

return RaidService
