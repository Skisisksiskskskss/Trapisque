--[[
	All RemoteEvents in one place. The server creates them; clients wait for them.

	Client -> server
		Action(name, ...)        every player input (fire, skills, dash, block, dive, kit select)
		PaintReady()             ask for the full paint snapshot once the client can render it

	Server -> client
		PaintSync(mode, keys, colors)   mode: "snapshot" | "delta" | "clear"
		Fx(kind, ...)                   cosmetic events (projectiles, skills, dashes)
		Hit(victimCharacter, position, damage, attackerColorId, heavy, blocked)
		HitConfirm(damage, combo, ko)   only to the attacker
		Knockback(velocity, ragdollTime, stunTime)   only to the victim
		Feed(killerName, killerColorId, victimName, victimColorId, verb)
		Notify(text, kind)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Action",
	"PaintReady",
	"PaintSync",
	"Fx",
	"Hit",
	"HitConfirm",
	"Knockback",
	"Feed",
	"Notify",
}

local FOLDER_NAME = "Remotes"

local Remotes = {} :: { [string]: RemoteEvent }

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
end

return Remotes
