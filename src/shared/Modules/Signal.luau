--!strict
-- Minimal synchronous signal. Handlers run in order; errors in one handler don't stop the others.

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { { fn: (T...) -> (), conn: Connection } } = {}
	local self = {} :: Signal<T...>

	function self.Connect(_: Signal<T...>, handler: (T...) -> ()): Connection
		local entry = { fn = handler, conn = (nil :: any) :: Connection }
		local conn = {} :: Connection
		conn.Connected = true
		function conn.Disconnect(c: Connection)
			if not c.Connected then
				return
			end
			c.Connected = false
			local index = table.find(handlers, entry)
			if index then
				table.remove(handlers, index)
			end
		end
		entry.conn = conn
		table.insert(handlers, entry)
		return conn
	end

	function self.Once(s: Signal<T...>, handler: (T...) -> ()): Connection
		local conn: Connection
		conn = s:Connect(function(...: T...)
			conn:Disconnect()
			handler(...)
		end)
		return conn
	end

	function self.Fire(_: Signal<T...>, ...: T...)
		local snapshot = table.clone(handlers)
		for _, entry in snapshot do
			if entry.conn.Connected then
				local ok, err = pcall(entry.fn :: any, ...)
				if not ok then
					warn("[Signal] handler error: " .. tostring(err))
				end
			end
		end
	end

	return self
end

return Signal
