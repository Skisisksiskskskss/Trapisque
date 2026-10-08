--[[
	Net (client)
	Net.request(action, payload) -> ok, dataOrError   (yields)
	Net.on(kind, fn)                                  server pushes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = ReplicatedStorage:WaitForChild("TrapisqueNet")
local request = folder:WaitForChild("Request") :: RemoteFunction
local push = folder:WaitForChild("Push") :: RemoteEvent

local listeners = {}
local backlog = {}

function Net.request(action: string, payload: { [string]: any }?): (boolean, any)
	local ok, result = pcall(function()
		return request:InvokeServer(action, payload or {})
	end)
	if not ok then
		return false, "Connection problem. Try again."
	end
	if type(result) ~= "table" then
		return false, "Unexpected reply."
	end
	if result.ok then
		return true, result.data
	end
	return false, result.err or "That didn't work."
end

function Net.on(kind: string, fn: (any) -> ())
	listeners[kind] = listeners[kind] or {}
	table.insert(listeners[kind], fn)
	-- deliver anything that arrived before the listener existed
	local queued = backlog[kind]
	if queued then
		backlog[kind] = nil
		for _, data in queued do
			task.spawn(fn, data)
		end
	end
end

push.OnClientEvent:Connect(function(kind: string, data: any)
	local list = listeners[kind]
	if not list then
		backlog[kind] = backlog[kind] or {}
		table.insert(backlog[kind], data)
		return
	end
	for _, fn in list do
		task.spawn(fn, data)
	end
end)

return Net
