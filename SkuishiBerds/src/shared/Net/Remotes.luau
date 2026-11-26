--[[
	Remotes: the three network channels.

	  Net   (RemoteEvent, reliable)            discrete messages: (msgName, ...args)
	  Fast  (UnreliableRemoteEvent)            bird states / snapshots ~20-30 Hz
	  Ask   (RemoteFunction)                   request/response (profile, shop, leaderboards)

	The server creates them; clients wait for them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "SkuishiRemotes"

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function get(className: string, name: string): Instance
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = folder
		return inst
	end
	return folder:WaitForChild(name)
end

function Remotes.net(): RemoteEvent
	return get("RemoteEvent", "Net") :: RemoteEvent
end

function Remotes.fast(): UnreliableRemoteEvent
	return get("UnreliableRemoteEvent", "Fast") :: UnreliableRemoteEvent
end

function Remotes.ask(): RemoteFunction
	return get("RemoteFunction", "Ask") :: RemoteFunction
end

return Remotes
