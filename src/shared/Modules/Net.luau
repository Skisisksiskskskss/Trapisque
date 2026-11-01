--!strict
-- Remote definitions. The server creates every remote at boot; clients wait for them by name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.EventNames = {
	-- server -> client
	"State", -- full player state snapshot
	"Notify", -- toast for one player
	"Announce", -- big banner for everyone
	"WaveStart", -- list of incoming brainrots
	"WaveResult", -- outcome per plot
	"EscapeStart", -- an escaped brainrot starts its lap
	"EscapeEnd", -- escaped brainrot captured or gone
	"Knockback", -- bonk impulse to apply locally
	"Effect", -- generic VFX cue (cash pop, tier up, etc.)
	"OfflineEarnings", -- welcome-back popup
	"ServerInfo", -- event + timers broadcast
	-- client -> server
	"Charge", -- one tap of the charge button
	"Settings", -- toggle music / sfx
	"TutorialStep", -- tutorial progress
	"Repair", -- hold-to-repair tick at your own broken door
	"Steal", -- (plotIndex, slot) grab a brainrot from a raidable base
}

Net.FunctionNames = {
	"Upgrade", -- ("Crystal" | "Door" | "Tier") -> (ok, message)
	"Rebirth",
	"Inventory", -- (action, uid) -> (ok, message)
	"ClaimDaily",
	"RedeemCode",
	"ClaimGift",
	"UseBoost",
	"GetShopInfo", -- odds + scaled cash amounts for the shop UI
}

local FOLDER_NAME = "Remotes"

function Net.Setup()
	assert(RunService:IsServer(), "Net.Setup is server-only")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in Net.EventNames do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in Net.FunctionNames do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

local function folder(): Instance
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Net.Event(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

return Net
