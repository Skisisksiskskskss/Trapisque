--!strict
-- Owned brainrots: adding/removing, auto-placement on pedestals, storage, selling, pedestal models,
-- per-second income and collection pads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Brainrots = require(Shared.Config.Brainrots)
local Economy = require(Shared.Config.Economy)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Sizes = require(Shared.Config.Sizes)
local BrainrotBuilder = require(Shared.Modules.BrainrotBuilder)
local BrainrotStats = require(Shared.Modules.BrainrotStats)
local DataSchema = require(Shared.Modules.DataSchema)
local Format = require(Shared.Modules.Format)
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local BaseBuilder = require(script.Parent.Parent.Modules.BaseBuilder)
local PlayerStats = require(script.Parent.Parent.Modules.PlayerStats)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local BrainrotService = {}

BrainrotService.Added = Signal.new() :: Signal.Signal<Player, DataSchema.BrainrotRecord, string>
BrainrotService.Discovered = Signal.new() :: Signal.Signal<Player, string, string>

type Spawned = { Model: Model, Uid: string }

-- spawned[player][slot]
local spawned: { [Player]: { [number]: Spawned } } = {}
-- Slots whose brainrot is currently being carried by a thief: income paused, model hidden.
local carried: { [Player]: { [number]: boolean } } = {}

local function notify(player: Player, text: string, kind: string?)
	Net.Event("Notify"):FireClient(player, text, kind or "info")
end
BrainrotService.Notify = notify

function BrainrotService.Income(record: DataSchema.BrainrotRecord): number
	return BrainrotStats.Income(record.Id, record.Mutation, record.Size)
end

local function placedSlots(data: DataSchema.PlayerData): { [number]: string }
	local result = {}
	local unlocked = Economy.Slots(data.Tier)
	for key, uid in data.Slots do
		local slot = tonumber(key)
		if slot and slot <= unlocked and data.Brainrots[uid] then
			result[slot] = uid
		end
	end
	return result
end
BrainrotService.PlacedSlots = placedSlots

local function slotOf(data: DataSchema.PlayerData, uid: string): number?
	for key, slotUid in data.Slots do
		if slotUid == uid then
			return tonumber(key)
		end
	end
	return nil
end
BrainrotService.SlotOf = slotOf

local function storageCount(data: DataSchema.PlayerData): number
	local placed: { [string]: boolean } = {}
	for _, uid in data.Slots do
		placed[uid] = true
	end
	local count = 0
	for uid in data.Brainrots do
		if not placed[uid] then
			count += 1
		end
	end
	return count
end
BrainrotService.StorageCount = storageCount

local function rarityColor(id: string): Color3
	local def = Brainrots.Get(id)
	return if def then Rarities.Get(def.Rarity).Color else Color3.new(1, 1, 1)
end

local function makeLabel(parent: Instance, name: string, text: string, color: Color3, order: number, height: number)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, height, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.Text = text
	label.Parent = parent
end

local function despawnSlot(player: Player, slot: number)
	local bySlot = spawned[player]
	local entry = bySlot and bySlot[slot]
	if bySlot and entry then
		entry.Model:Destroy()
		bySlot[slot] = nil
	end
end

local function spawnSlot(player: Player, slot: number)
	despawnSlot(player, slot)
	local data = DataService.Get(player)
	local plot = PlotService.ForPlayer(player)
	if not data or not plot or not plot.Parts then
		return
	end
	local uid = data.Slots[tostring(slot)]
	local record = uid and data.Brainrots[uid]
	if not record or not uid then
		return
	end
	local sizeIndex = 1
	for i, size in Sizes.List do
		if size.Name == record.Size then
			sizeIndex = i
		end
	end
	local fit = BrainrotBuilder.FitScale(record.Id, 5.2, 4.6) * (1 + (sizeIndex - 1) * 0.12)
	local model = BrainrotBuilder.Build(record.Id, { Mutation = record.Mutation, Scale = fit })
	model:PivotTo(plot.CFrame * BaseBuilder.SlotLocalCFrame(slot) * CFrame.new(0, 0.6, 0))
	model:SetAttribute("Uid", uid)
	model:SetAttribute("Slot", slot)
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("PlotIndex", plot.Index)
	model:SetAttribute("Size", record.Size)
	model:SetAttribute("StealImmuneUntil", (record.StolenAt or 0) + GameConfig.StealImmunitySeconds)

	local root = model.PrimaryPart
	if root then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Tag"
		billboard.Size = UDim2.fromOffset(190, 70)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, (model:GetAttribute("Height") :: number) + 1.6, 0)
		billboard.MaxDistance = 75
		billboard.LightInfluence = 0
		billboard.Parent = root
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = billboard
		local def = Brainrots.Get(record.Id)
		local tags = {}
		if record.Size ~= "Normal" then
			table.insert(tags, string.upper(record.Size))
		end
		if record.Mutation ~= "None" then
			table.insert(tags, string.upper(record.Mutation))
		end
		if #tags > 0 then
			makeLabel(billboard, "Tags", table.concat(tags, " · "), Color3.fromRGB(255, 235, 140), 1, 0.24)
		end
		makeLabel(billboard, "Name", if def then def.Name else record.Id, rarityColor(record.Id), 2, 0.38)
		makeLabel(
			billboard,
			"Income",
			Format.Cash(BrainrotService.Income(record)) .. "/s",
			Color3.fromRGB(120, 255, 120),
			3,
			0.3
		)
	end

	model.Parent = plot.Parts.Model
	local bySlot = spawned[player]
	if not bySlot then
		bySlot = {}
		spawned[player] = bySlot
	end
	bySlot[slot] = { Model = model, Uid = uid }
	if carried[player] and carried[player][slot] then
		BrainrotService.SetCarried(player, slot, true)
	end
end

function BrainrotService.SpawnAll(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local bySlot = spawned[player]
	if bySlot then
		for slot in bySlot do
			despawnSlot(player, slot)
		end
	end
	spawned[player] = {}
	-- Drop slot assignments that point at missing brainrots or pedestals locked by a lower tier (after rebirth).
	local unlocked = Economy.Slots(data.Tier)
	for key, uid in data.Slots do
		local slot = tonumber(key)
		if slot == nil or slot > unlocked or data.Brainrots[uid] == nil then
			data.Slots[key] = nil
		end
	end
	for slot in placedSlots(data) do
		spawnSlot(player, slot)
	end
end

function BrainrotService.ModelAt(player: Player, slot: number): Model?
	local bySlot = spawned[player]
	local entry = bySlot and bySlot[slot]
	return if entry then entry.Model else nil
end

function BrainrotService.SetCarried(player: Player, slot: number, isCarried: boolean)
	local map = carried[player]
	if not map then
		map = {}
		carried[player] = map
	end
	if isCarried then
		map[slot] = true
	else
		map[slot] = nil
	end
	local model = BrainrotService.ModelAt(player, slot)
	if model then
		for _, child in model:GetDescendants() do
			if child:IsA("BasePart") and child.Name ~= "Root" then
				if isCarried then
					child:SetAttribute("PrevTransparency", child.Transparency)
					child.Transparency = 1
				else
					local prev = child:GetAttribute("PrevTransparency")
					child.Transparency = if type(prev) == "number" then prev else 0
				end
			elseif child:IsA("BillboardGui") or child:IsA("ParticleEmitter") or child:IsA("PointLight") then
				(child :: any).Enabled = not isCarried
			end
		end
	end
end

-- Recomputes cached income/s and publishes it.
function BrainrotService.RefreshIncome(player: Player)
	local data = DataService.Get(player)
	local session = DataService.GetSession(player)
	if not data or not session then
		return
	end
	local total = 0
	for _, uid in placedSlots(data) do
		total += BrainrotService.Income(data.Brainrots[uid])
	end
	session.CashMultiplier = PlayerStats.CashMultiplier(data, session.Passes)
	session.IncomeCache = total * session.CashMultiplier
	player:SetAttribute("Income", session.IncomeCache)
	DataService.MarkDirty(player)
end

local function weakestPlaced(data: DataSchema.PlayerData): (number?, number)
	local weakestSlot, weakestIncome = nil, math.huge
	for slot, uid in placedSlots(data) do
		local income = BrainrotService.Income(data.Brainrots[uid])
		if income < weakestIncome then
			weakestSlot, weakestIncome = slot, income
		end
	end
	return weakestSlot, weakestIncome
end

local function firstFreeSlot(data: DataSchema.PlayerData): number?
	local unlocked = Economy.Slots(data.Tier)
	for slot = 1, unlocked do
		local uid = data.Slots[tostring(slot)]
		if uid == nil or data.Brainrots[uid] == nil then
			return slot
		end
	end
	return nil
end
BrainrotService.FirstFreeSlot = firstFreeSlot

local function placeInto(player: Player, data: DataSchema.PlayerData, uid: string, slot: number)
	data.Slots[tostring(slot)] = uid
	spawnSlot(player, slot)
end

-- Adds a brainrot. Auto-places it in a free slot, or swaps out the weakest placed brainrot if the new one earns
-- more. If there is no room anywhere it is sold instantly. Returns the new uid (or nil if sold) and the slot.
function BrainrotService.Add(
	player: Player,
	id: string,
	mutation: string,
	size: string,
	source: string,
	stolenAt: number?
): (string?, number?)
	local data = DataService.Get(player)
	if not data or Brainrots.Get(id) == nil then
		return nil, nil
	end
	local record: DataSchema.BrainrotRecord = {
		Uid = DataSchema.NewUid(data),
		Id = id,
		Mutation = mutation,
		Size = size,
		Obtained = os.time(),
		StolenAt = stolenAt,
	}
	local income = BrainrotService.Income(record)

	-- Index discovery
	local baseKey = BrainrotStats.IndexKey(id, "None")
	local mutationKey = BrainrotStats.IndexKey(id, mutation)
	local newBase = not data.Index[baseKey]
	if newBase then
		data.Index[baseKey] = true
		BrainrotService.Discovered:Fire(player, id, "None")
	end
	if mutation ~= "None" and not data.Index[mutationKey] then
		data.Index[mutationKey] = true
		BrainrotService.Discovered:Fire(player, id, mutation)
	end

	local slot = firstFreeSlot(data)
	if slot == nil then
		local weakSlot, weakIncome = weakestPlaced(data)
		if weakSlot and income > weakIncome and storageCount(data) < GameConfig.StorageMax then
			slot = weakSlot
		end
	end
	if slot == nil and storageCount(data) >= GameConfig.StorageMax then
		local value =
			Economy.SellValue(income * PlayerStats.CashMultiplier(data, (DataService.GetSession(player) :: any).Passes))
		DataService.AddCash(player, value)
		notify(
			player,
			string.format(
				"Storage full! Auto-sold %s for %s",
				BrainrotStats.DisplayName(id, mutation, size),
				Format.Cash(value)
			),
			"warn"
		)
		BrainrotService.RefreshIncome(player)
		return nil, nil
	end

	data.Brainrots[record.Uid] = record
	if slot then
		placeInto(player, data, record.Uid, slot)
	end
	if newBase then
		notify(
			player,
			string.format(
				"NEW! %s added to your Index (+%d%% cash)",
				Brainrots.ById[id].Name,
				math.floor(Economy.IndexBonusPerEntry * 100)
			),
			"new"
		)
	end
	BrainrotService.RefreshIncome(player)
	BrainrotService.Added:Fire(player, record, source)
	return record.Uid, slot
end

-- Removes a brainrot entirely (sold or stolen). Returns the removed record.
function BrainrotService.Remove(player: Player, uid: string): DataSchema.BrainrotRecord?
	local data = DataService.Get(player)
	local session = DataService.GetSession(player)
	if not data or not session then
		return nil
	end
	local record = data.Brainrots[uid]
	if not record then
		return nil
	end
	local slot = slotOf(data, uid)
	if slot then
		data.Slots[tostring(slot)] = nil
		session.Pending[slot] = nil
		despawnSlot(player, slot)
		local map = carried[player]
		if map then
			map[slot] = nil
		end
	end
	data.Brainrots[uid] = nil
	BrainrotService.RefreshIncome(player)
	return record
end

-- Arranges the highest-earning brainrots onto the unlocked pedestals.
function BrainrotService.PlaceBest(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local busy = carried[player]
	if busy and next(busy) ~= nil then
		notify(player, "Can't rearrange while a brainrot is being stolen!", "warn")
		return
	end
	local list: { DataSchema.BrainrotRecord } = {}
	for _, record in data.Brainrots do
		table.insert(list, record)
	end
	table.sort(list, function(a, b)
		return BrainrotService.Income(a) > BrainrotService.Income(b)
	end)
	data.Slots = {}
	local unlocked = Economy.Slots(data.Tier)
	for i = 1, math.min(unlocked, #list) do
		data.Slots[tostring(i)] = list[i].Uid
	end
	BrainrotService.SpawnAll(player)
	BrainrotService.RefreshIncome(player)
end

function BrainrotService.CollectSlot(player: Player, slot: number)
	local session = DataService.GetSession(player)
	if not session then
		return
	end
	local amount = session.Pending[slot]
	if amount and amount >= 1 then
		session.Pending[slot] = 0
		DataService.AddCash(player, amount)
		Net.Event("Effect"):FireClient(player, "Collect", { Slot = slot, Amount = amount })
	end
end

function BrainrotService.CollectAll(player: Player): number
	local session = DataService.GetSession(player)
	if not session then
		return 0
	end
	local total = 0
	for slot, amount in session.Pending do
		total += amount
		session.Pending[slot] = 0
	end
	if total > 0 then
		DataService.AddCash(player, total)
	end
	return total
end

local function onInventory(player: Player, action: unknown, uid: unknown): (boolean, string)
	if not DataService.Throttle(player, "Inventory", 0.15) then
		return false, "Slow down!"
	end
	if type(action) ~= "string" then
		return false, "Bad request"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Not loaded"
	end
	if action == "PlaceBest" then
		BrainrotService.PlaceBest(player)
		return true, "Placed your best brainrots!"
	end
	if type(uid) ~= "string" or data.Brainrots[uid] == nil then
		return false, "Brainrot not found"
	end
	local record = data.Brainrots[uid]
	local slot = slotOf(data, uid)
	local busy = carried[player]
	if slot and busy and busy[slot] then
		return false, "That brainrot is being stolen!"
	end
	if action == "Place" then
		if slot then
			return false, "Already placed"
		end
		local free = firstFreeSlot(data)
		if not free then
			return false, "Your base is full! Store one first."
		end
		placeInto(player, data, uid, free)
		BrainrotService.RefreshIncome(player)
		return true, "Placed!"
	elseif action == "Store" then
		if not slot then
			return false, "Already in storage"
		end
		if storageCount(data) >= GameConfig.StorageMax then
			return false, "Storage is full"
		end
		BrainrotService.CollectSlot(player, slot)
		data.Slots[tostring(slot)] = nil
		despawnSlot(player, slot)
		BrainrotService.RefreshIncome(player)
		return true, "Moved to storage"
	elseif action == "Sell" then
		local session = DataService.GetSession(player)
		local mult = if session then session.CashMultiplier else 1
		local value = Economy.SellValue(BrainrotService.Income(record) * mult)
		if slot then
			BrainrotService.CollectSlot(player, slot)
		end
		BrainrotService.Remove(player, uid)
		DataService.AddCash(player, value)
		return true, "Sold for " .. Format.Cash(value)
	end
	return false, "Unknown action"
end

local function hookPads(player: Player, plot: PlotService.Plot)
	local parts = plot.Parts
	if not parts then
		return
	end
	for slot, pedestal in parts.Pedestals do
		if pedestal.Locked then
			continue
		end
		local pad = pedestal.Pad
		pad.CanTouch = true
		local label = Instance.new("BillboardGui")
		label.Name = "PendingTag"
		label.Size = UDim2.fromOffset(120, 34)
		label.StudsOffset = Vector3.new(0, 1.4, 0)
		label.MaxDistance = 45
		label.LightInfluence = 0
		label.Parent = pad
		local text = Instance.new("TextLabel")
		text.Name = "Amount"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(130, 255, 130)
		text.TextStrokeTransparency = 0.1
		text.Text = ""
		text.Parent = label
		pad.Touched:Connect(function(hit)
			local character = player.Character
			if character and hit:IsDescendantOf(character) then
				if DataService.Throttle(player, "Pad" .. slot, 0.25) then
					BrainrotService.CollectSlot(player, slot)
				end
			end
		end)
	end
end

local function updatePadLabels(plot: PlotService.Plot, pending: { [number]: number })
	local parts = plot.Parts
	if not parts then
		return
	end
	for slot, pedestal in parts.Pedestals do
		local tag = pedestal.Pad:FindFirstChild("PendingTag")
		local label = tag and tag:FindFirstChild("Amount") :: TextLabel?
		if label then
			local amount = pending[slot] or 0
			local text = if amount >= 1 then Format.Cash(amount) else ""
			if label.Text ~= text then
				label.Text = text
			end
		end
	end
end

function BrainrotService.Start()
	Net.Function("Inventory").OnServerInvoke = onInventory

	PlotService.BaseBuilt:Connect(function(player, plot)
		hookPads(player, plot)
		BrainrotService.SpawnAll(player)
		BrainrotService.RefreshIncome(player)
	end)

	DataService.Releasing:Connect(function(player)
		-- Bank anything left on the pads so leaving never loses money.
		BrainrotService.CollectAll(player)
		spawned[player] = nil
		carried[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		spawned[player] = nil
		carried[player] = nil
	end)

	-- Income tick
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in DataService.Players() do
				local data = DataService.Get(player)
				local session = DataService.GetSession(player)
				local plot = PlotService.ForPlayer(player)
				if not data or not session or not plot then
					continue
				end
				local mult = session.CashMultiplier
				local busy = carried[player] or {}
				local direct = 0
				for slot, uid in placedSlots(data) do
					if busy[slot] then
						continue
					end
					local amount = BrainrotService.Income(data.Brainrots[uid]) * mult
					if session.Passes.AutoCollect then
						direct += amount
					else
						session.Pending[slot] = (session.Pending[slot] or 0) + amount
					end
				end
				if direct > 0 then
					DataService.AddCash(player, direct)
				end
				updatePadLabels(plot, session.Pending)
			end
		end
	end)
end

return BrainrotService
