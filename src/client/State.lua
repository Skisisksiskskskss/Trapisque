--[[
	State (client)
	A tiny observable store for things several screens care about.
		State.set("profile", data)
		State.get("profile")
		State.watch("profile", function(value) ... end) -> disconnect function
	Keys: profile, party, queue, invite, teleporting, lobbyPlayers, role, studio
]]

local State = {}

local values = {}
local watchers = {}

function State.get(key: string): any
	return values[key]
end

function State.set(key: string, value: any)
	values[key] = value
	local list = watchers[key]
	if list then
		for _, fn in table.clone(list) do
			task.spawn(fn, value)
		end
	end
end

function State.watch(key: string, fn: (any) -> (), fireNow: boolean?): () -> ()
	watchers[key] = watchers[key] or {}
	table.insert(watchers[key], fn)
	if fireNow then
		task.spawn(fn, values[key])
	end
	return function()
		local list = watchers[key]
		if list then
			local i = table.find(list, fn)
			if i then
				table.remove(list, i)
			end
		end
	end
end

-- Convenience: does the local player own a cosmetic / pass?
function State.owns(itemId: string): boolean
	local p = values.profile
	return p ~= nil and table.find(p.owned, itemId) ~= nil
end

function State.hasPass(key: string): boolean
	local p = values.profile
	return p ~= nil and table.find(p.passes, key) ~= nil
end

return State
