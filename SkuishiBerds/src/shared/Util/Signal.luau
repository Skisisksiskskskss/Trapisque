--[[
	Signal: a tiny synchronous event emitter (no Instances, safe to use anywhere).
]]

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local handlers = self._handlers
	local entry = { fn = fn, connected = true }
	table.insert(handlers, entry)
	return {
		Disconnect = function()
			entry.connected = false
			local idx = table.find(handlers, entry)
			if idx then
				table.remove(handlers, idx)
			end
		end,
	}
end

function Signal:Fire(...: any)
	-- copy so handlers can disconnect while firing
	local list = table.clone(self._handlers)
	for _, entry in list do
		if entry.connected then
			entry.fn(...)
		end
	end
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
