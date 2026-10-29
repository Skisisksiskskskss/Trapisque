--[[
	SettingsService: saves each player's settings and keybinds in a DataStore
	and sends them back when they join. Everything is wrapped in pcall: in
	Studio without API access, or if DataStores are down, settings simply last
	for the session.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Remotes = require(Shared.Remotes)

local SettingsService = {}

local STORE_NAME = "SplotchSettings_v1"
local MAX_BYTES = 4000
local SAVE_COOLDOWN = 6

local store: DataStore? = nil
local pending: { [Player]: any } = {}
local lastSave: { [Player]: number } = {}
local warned = false

local function storeOrNil(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	elseif not warned then
		warned = true
		warn("Splotch: settings will not be saved (DataStores unavailable):", result)
	end
	return store
end

-- Only plain data within a size limit is accepted from clients.
local function sanitize(data: any): any
	if typeof(data) ~= "table" then
		return nil
	end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
	if not ok or #encoded > MAX_BYTES then
		return nil
	end
	return HttpService:JSONDecode(encoded)
end

local function save(player: Player)
	local data = pending[player]
	local ds = storeOrNil()
	if not data or not ds or player.UserId <= 0 then
		return
	end
	pending[player] = nil
	lastSave[player] = os.clock()
	local ok, err = pcall(function()
		ds:SetAsync("user_" .. player.UserId, data)
	end)
	if not ok and not warned then
		warned = true
		warn("Splotch: could not save settings:", err)
	end
end

local function load(player: Player)
	local ds = storeOrNil()
	if not ds or player.UserId <= 0 then
		return
	end
	local ok, data = pcall(function()
		return ds:GetAsync("user_" .. player.UserId)
	end)
	if ok and typeof(data) == "table" and player.Parent then
		Remotes.Settings:FireClient(player, data)
	end
end

function SettingsService.init()
	Remotes.SaveSettings.OnServerEvent:Connect(function(player, data)
		local clean = sanitize(data)
		if not clean then
			return
		end
		pending[player] = clean
		local since = os.clock() - (lastSave[player] or 0)
		if since >= SAVE_COOLDOWN then
			task.spawn(save, player)
		else
			task.delay(SAVE_COOLDOWN - since, function()
				if pending[player] then
					save(player)
				end
			end)
		end
	end)
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		pending[player] = nil
		lastSave[player] = nil
	end)
end

return SettingsService
