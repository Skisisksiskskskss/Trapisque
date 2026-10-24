--[[
	A small fake of the Roblox engine, so the real client and server code can run in the
	standalone Luau CLI (tests/smoke). Bundle tests/fake/classes.luau before this file.

	What it fakes, and how strictly:
	- Datatypes (Vector2, UDim2, Color3, Font, sequences, TweenInfo, Rect, Random...)
	  are immutable values with Roblox's operators and errors.
	- Instances know every real property, event and method of their class (from the
	  Roblox type definitions). Setting a property that doesn't exist, a value of the
	  wrong type, a read-only property or a destroyed instance's Parent errors the way
	  Roblox does. A method the fake doesn't implement errors and says so.
	- Time is simulated: task.wait / delay / defer, os.clock, tick, RenderStepped and
	  Heartbeat all run on Fake.step(). Event handlers run deferred (Roblox's default
	  signal behaviour), each in its own thread; errors in any thread are collected in
	  Fake.errors instead of stopping the run, like Roblox's output window.
	- GUI layout is computed on read (AbsoluteSize / AbsolutePosition with scale and
	  offset, UIScale, UIPadding, size and aspect constraints, list and grid layouts),
	  and AbsoluteSize / AbsolutePosition change events fire once per frame.
	- Tweens interpolate every frame through the normal property setter.
	- Remotes copy their arguments by Roblox's rules and report tables Roblox would mangle
	  (non-string keys in dictionaries, mixed tables, holes) in Fake.issues.
	- DataStores and MemoryStores keep values in memory and reject what Roblox can't
	  store (Fake.issues as well).

	Test controls live in the global `Fake` (see the end of the file).
]]

-- Without this the VM caches builtins (typeof, os.clock) at load time and our fakes
-- would be bypassed: touching the environment turns that optimisation off.
getfenv()

Fake = {}
local F = Fake

local realOs = os
local realTypeof = typeof
local realPrint = print

F.print = realPrint -- print() is captured; this one reaches the terminal
F.now = 0
F.frame = 0
F.frameDt = 1 / 30
F.epoch = 1760000000 -- os.time() at the start of the run
F.errors = {}
F.warnings = {}
F.issues = {}
F.logs = {}
F.verbose = false

local function report(kind: string, message: string, trace: string?)
	table.insert(F.errors, { kind = kind, message = message, trace = trace })
	if F.verbose then
		realPrint("[fake] " .. kind .. ": " .. message .. (if trace then "\n" .. trace else ""))
	end
end

local function issue(message: string)
	for _, m in F.issues do
		if m == message then
			return
		end
	end
	table.insert(F.issues, message)
end

---------------------------------------------------------------------------
-- threads and simulated time
---------------------------------------------------------------------------

local waiting = {} -- { co, wake, start, args?, seq }
local deferred = {} -- { co, args }
local seq = 0

local function resume(co: thread, ...)
	if coroutine.status(co) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		report("error", tostring(err), debug.traceback(co))
	end
end

local function threadOf(f)
	if type(f) == "thread" then
		return f
	end
	assert(type(f) == "function", "invalid argument #1 to 'spawn' (function or thread expected)")
	return coroutine.create(f)
end

local function schedule(co: thread, wake: number, args)
	seq += 1
	table.insert(waiting, { co = co, wake = wake, start = F.now, args = args, seq = seq })
end

local function defer(co: thread, args)
	table.insert(deferred, { co = co, args = args })
end

task = {}
function task.spawn(f, ...)
	local co = threadOf(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = threadOf(f)
	defer(co, table.pack(...))
	return co
end
function task.delay(t: number?, f, ...)
	local co = threadOf(f)
	schedule(co, F.now + math.max(0, t or 0), table.pack(...))
	return co
end
function task.wait(t: number?)
	local co = coroutine.running()
	if not coroutine.isyieldable() then
		error("attempt to yield across a non-yieldable boundary (task.wait outside a thread)", 2)
	end
	schedule(co, F.now + math.max(0, t or 0), nil)
	return coroutine.yield()
end
function task.cancel(co: thread)
	for i = #waiting, 1, -1 do
		if waiting[i].co == co then
			table.remove(waiting, i)
		end
	end
	for i = #deferred, 1, -1 do
		if deferred[i].co == co then
			table.remove(deferred, i)
		end
	end
	if coroutine.status(co) == "suspended" then
		coroutine.close(co)
	end
end
function task.synchronize() end
function task.desynchronize() end

-- legacy globals
function wait(t)
	return task.wait(t)
end
function delay(t, f)
	return task.delay(t, f)
end
function spawn(f)
	return task.defer(f)
end

local function flushDeferred()
	local guard = 0
	while #deferred > 0 do
		guard += 1
		if guard > 100000 then
			report("error", "deferred threads keep re-queueing themselves (infinite loop?)")
			deferred = {}
			return
		end
		local d = table.remove(deferred, 1)
		if d.args then
			resume(d.co, table.unpack(d.args, 1, d.args.n))
		else
			resume(d.co)
		end
	end
end
F.flush = flushDeferred

os = setmetatable({
	clock = function()
		return F.now
	end,
	time = function(t)
		if t ~= nil then
			return realOs.time(t)
		end
		return F.epoch + math.floor(F.now)
	end,
}, { __index = realOs })
function tick()
	return F.epoch + F.now
end
function time()
	return F.now
end
function elapsedTime()
	return F.now
end

warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		table.insert(parts, tostring((select(i, ...))))
	end
	local msg = table.concat(parts, " ")
	table.insert(F.warnings, msg)
	if F.verbose then
		realPrint("[warn] " .. msg)
	end
end
print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		table.insert(parts, tostring((select(i, ...))))
	end
	table.insert(F.logs, table.concat(parts, " "))
	if F.verbose then
		realPrint(table.concat(parts, " "))
	end
end

---------------------------------------------------------------------------
-- signals
---------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal
Signal.__type = "RBXScriptSignal"
local Connection = {}
Connection.__index = Connection
Connection.__type = "RBXScriptConnection"

local function newSignal(name: string, immediate: boolean?)
	return setmetatable({ name = name, conns = {}, waiters = {}, immediate = immediate == true }, Signal)
end

function Signal:Connect(fn)
	if type(fn) ~= "function" then
		error("Attempt to connect failed: Passed value is not a function", 2)
	end
	local c = setmetatable({ Connected = true, fn = fn, signal = self }, Connection)
	table.insert(self.conns, c)
	return c
end
Signal.ConnectParallel = Signal.Connect
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Wait()
	local co = coroutine.running()
	if not coroutine.isyieldable() then
		error("attempt to yield across a non-yieldable boundary (Signal:Wait outside a thread)", 2)
	end
	table.insert(self.waiters, co)
	return coroutine.yield()
end
function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self.signal.conns
	local i = table.find(list, self)
	if i then
		table.remove(list, i)
	end
end

-- Fires the signal. Handlers run deferred unless the signal is immediate (frame events).
local function fire(sig, ...)
	if not sig then
		return
	end
	local args = table.pack(...)
	if #sig.conns > 0 then
		for _, c in table.clone(sig.conns) do
			if c.Connected then
				if sig.immediate then
					task.spawn(c.fn, table.unpack(args, 1, args.n))
				else
					defer(coroutine.create(function()
						if c.Connected then
							c.fn(table.unpack(args, 1, args.n))
						end
					end), nil)
				end
			end
		end
	end
	if #sig.waiters > 0 then
		local w = sig.waiters
		sig.waiters = {}
		for _, co in w do
			if sig.immediate then
				resume(co, table.unpack(args, 1, args.n))
			else
				defer(co, args)
			end
		end
	end
end

local function disconnectAll(sig)
	if sig then
		for _, c in table.clone(sig.conns) do
			c:Disconnect()
		end
		sig.waiters = {}
	end
end

local function hasListeners(sig): boolean
	return sig ~= nil and (#sig.conns > 0 or #sig.waiters > 0)
end

---------------------------------------------------------------------------
-- datatypes
---------------------------------------------------------------------------

local function readOnly(typeName: string)
	return function(_, key)
		error(tostring(key) .. " cannot be assigned to (" .. typeName .. " is immutable)", 2)
	end
end

local function checkNum(v, what: string, level: number?)
	if type(v) ~= "number" then
		error("invalid argument to " .. what .. " (number expected, got " .. realTypeof(v) .. ")", (level or 1) + 1)
	end
	return v
end

-- Vector2 ---------------------------------------------------------------
local V2 = { __type = "Vector2" }
local V2methods = {}
local function v2(x: number, y: number)
	return setmetatable({ _x = x, _y = y }, V2)
end
V2.__index = function(v, k)
	if k == "X" or k == "x" then
		return rawget(v, "_x")
	elseif k == "Y" or k == "y" then
		return rawget(v, "_y")
	elseif k == "Magnitude" then
		return math.sqrt(v._x * v._x + v._y * v._y)
	elseif k == "Unit" then
		local m = math.sqrt(v._x * v._x + v._y * v._y)
		return if m == 0 then v2(0 / 0, 0 / 0) else v2(v._x / m, v._y / m)
	end
	local m = V2methods[k]
	if m then
		return m
	end
	error(tostring(k) .. " is not a valid member of Vector2", 2)
end
V2.__newindex = readOnly("Vector2")
V2.__eq = function(a, b)
	return a._x == b._x and a._y == b._y
end
V2.__add = function(a, b)
	if getmetatable(a) ~= V2 or getmetatable(b) ~= V2 then
		error("attempt to perform arithmetic (add) on Vector2 and " .. realTypeof(if getmetatable(a) == V2 then b else a), 2)
	end
	return v2(a._x + b._x, a._y + b._y)
end
V2.__sub = function(a, b)
	if getmetatable(a) ~= V2 or getmetatable(b) ~= V2 then
		error("attempt to perform arithmetic (sub) on Vector2 and " .. realTypeof(if getmetatable(a) == V2 then b else a), 2)
	end
	return v2(a._x - b._x, a._y - b._y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b._x, a * b._y)
	elseif type(b) == "number" then
		return v2(a._x * b, a._y * b)
	elseif getmetatable(a) == V2 and getmetatable(b) == V2 then
		return v2(a._x * b._x, a._y * b._y)
	end
	error("attempt to perform arithmetic (mul) on Vector2", 2)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a._x / b, a._y / b)
	elseif getmetatable(a) == V2 and getmetatable(b) == V2 then
		return v2(a._x / b._x, a._y / b._y)
	end
	error("attempt to perform arithmetic (div) on Vector2", 2)
end
V2.__idiv = function(a, b)
	if type(b) == "number" then
		return v2(a._x // b, a._y // b)
	end
	return v2(a._x // b._x, a._y // b._y)
end
V2.__unm = function(a)
	return v2(-a._x, -a._y)
end
V2.__tostring = function(v)
	return string.format("%g, %g", v._x, v._y)
end
function V2methods.Lerp(a, b, t)
	return v2(a._x + (b._x - a._x) * t, a._y + (b._y - a._y) * t)
end
function V2methods.Dot(a, b)
	return a._x * b._x + a._y * b._y
end
function V2methods.Cross(a, b)
	return a._x * b._y - a._y * b._x
end
function V2methods.Abs(a)
	return v2(math.abs(a._x), math.abs(a._y))
end
function V2methods.Floor(a)
	return v2(math.floor(a._x), math.floor(a._y))
end
function V2methods.Ceil(a)
	return v2(math.ceil(a._x), math.ceil(a._y))
end
function V2methods.Sign(a)
	return v2(math.sign(a._x), math.sign(a._y))
end
function V2methods.Min(a, ...)
	local x, y = a._x, a._y
	for _, b in { ... } do
		x, y = math.min(x, b._x), math.min(y, b._y)
	end
	return v2(x, y)
end
function V2methods.Max(a, ...)
	local x, y = a._x, a._y
	for _, b in { ... } do
		x, y = math.max(x, b._x), math.max(y, b._y)
	end
	return v2(x, y)
end
function V2methods.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return math.abs(a._x - b._x) <= eps and math.abs(a._y - b._y) <= eps
end
function V2methods.Angle(a, b)
	return math.atan2(a._x * b._y - a._y * b._x, a._x * b._x + a._y * b._y)
end
Vector2 = {
	new = function(x, y)
		return v2(checkNum(x or 0, "Vector2.new", 2), checkNum(y or 0, "Vector2.new", 2))
	end,
	zero = v2(0, 0),
	one = v2(1, 1),
	xAxis = v2(1, 0),
	yAxis = v2(0, 1),
}

-- Vector3 (input positions) ----------------------------------------------
local V3 = { __type = "Vector3" }
local function v3(x, y, z)
	return setmetatable({ _x = x, _y = y, _z = z }, V3)
end
V3.__index = function(v, k)
	if k == "X" then
		return v._x
	elseif k == "Y" then
		return v._y
	elseif k == "Z" then
		return v._z
	elseif k == "Magnitude" then
		return math.sqrt(v._x ^ 2 + v._y ^ 2 + v._z ^ 2)
	end
	error(tostring(k) .. " is not a valid member of Vector3", 2)
end
V3.__newindex = readOnly("Vector3")
V3.__eq = function(a, b)
	return a._x == b._x and a._y == b._y and a._z == b._z
end
V3.__add = function(a, b)
	return v3(a._x + b._x, a._y + b._y, a._z + b._z)
end
V3.__sub = function(a, b)
	return v3(a._x - b._x, a._y - b._y, a._z - b._z)
end
V3.__tostring = function(v)
	return string.format("%g, %g, %g", v._x, v._y, v._z)
end
Vector3 = {
	new = function(x, y, z)
		return v3(x or 0, y or 0, z or 0)
	end,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
}

-- UDim / UDim2 ------------------------------------------------------------
local UD = { __type = "UDim" }
local function udim(s, o)
	return setmetatable({ _s = s, _o = o }, UD)
end
UD.__index = function(u, k)
	if k == "Scale" then
		return u._s
	elseif k == "Offset" then
		return u._o
	end
	error(tostring(k) .. " is not a valid member of UDim", 2)
end
UD.__newindex = readOnly("UDim")
UD.__eq = function(a, b)
	return a._s == b._s and a._o == b._o
end
UD.__add = function(a, b)
	return udim(a._s + b._s, a._o + b._o)
end
UD.__sub = function(a, b)
	return udim(a._s - b._s, a._o - b._o)
end
UD.__unm = function(a)
	return udim(-a._s, -a._o)
end
UD.__tostring = function(u)
	return string.format("%g, %g", u._s, u._o)
end
UDim = {
	new = function(s, o)
		return udim(checkNum(s or 0, "UDim.new", 2), checkNum(o or 0, "UDim.new", 2))
	end,
}

local UD2 = { __type = "UDim2" }
local function udim2(xs, xo, ys, yo)
	return setmetatable({ _xs = xs, _xo = xo, _ys = ys, _yo = yo }, UD2)
end
UD2.__index = function(u, k)
	if k == "X" or k == "Width" then
		return udim(u._xs, u._xo)
	elseif k == "Y" or k == "Height" then
		return udim(u._ys, u._yo)
	elseif k == "Lerp" then
		return function(a, b, t)
			return udim2(a._xs + (b._xs - a._xs) * t, a._xo + (b._xo - a._xo) * t, a._ys + (b._ys - a._ys) * t, a._yo + (b._yo - a._yo) * t)
		end
	end
	error(tostring(k) .. " is not a valid member of UDim2", 2)
end
UD2.__newindex = readOnly("UDim2")
UD2.__eq = function(a, b)
	return a._xs == b._xs and a._xo == b._xo and a._ys == b._ys and a._yo == b._yo
end
UD2.__add = function(a, b)
	if getmetatable(a) ~= UD2 or getmetatable(b) ~= UD2 then
		error("attempt to perform arithmetic (add) on UDim2 and " .. realTypeof(if getmetatable(a) == UD2 then b else a), 2)
	end
	return udim2(a._xs + b._xs, a._xo + b._xo, a._ys + b._ys, a._yo + b._yo)
end
UD2.__sub = function(a, b)
	if getmetatable(a) ~= UD2 or getmetatable(b) ~= UD2 then
		error("attempt to perform arithmetic (sub) on UDim2 and " .. realTypeof(if getmetatable(a) == UD2 then b else a), 2)
	end
	return udim2(a._xs - b._xs, a._xo - b._xo, a._ys - b._ys, a._yo - b._yo)
end
UD2.__unm = function(a)
	return udim2(-a._xs, -a._xo, -a._ys, -a._yo)
end
UD2.__tostring = function(u)
	return string.format("{%g, %g}, {%g, %g}", u._xs, u._xo, u._ys, u._yo)
end
UDim2 = {
	new = function(xs, xo, ys, yo)
		if getmetatable(xs) == UD then
			return udim2(xs._s, xs._o, xo._s, xo._o)
		end
		return udim2(checkNum(xs or 0, "UDim2.new", 2), checkNum(xo or 0, "UDim2.new", 2), checkNum(ys or 0, "UDim2.new", 2), checkNum(yo or 0, "UDim2.new", 2))
	end,
	fromOffset = function(x, y)
		return udim2(0, checkNum(x or 0, "UDim2.fromOffset", 2), 0, checkNum(y or 0, "UDim2.fromOffset", 2))
	end,
	fromScale = function(x, y)
		return udim2(checkNum(x or 0, "UDim2.fromScale", 2), 0, checkNum(y or 0, "UDim2.fromScale", 2), 0)
	end,
}

-- Color3 --------------------------------------------------------------------
local C3 = { __type = "Color3" }
local function color(r, g, b)
	return setmetatable({ _r = r, _g = g, _b = b }, C3)
end
local C3methods = {}
C3.__index = function(c, k)
	if k == "R" or k == "r" then
		return c._r
	elseif k == "G" or k == "g" then
		return c._g
	elseif k == "B" or k == "b" then
		return c._b
	end
	local m = C3methods[k]
	if m then
		return m
	end
	error(tostring(k) .. " is not a valid member of Color3", 2)
end
C3.__newindex = readOnly("Color3")
C3.__eq = function(a, b)
	return a._r == b._r and a._g == b._g and a._b == b._b
end
C3.__tostring = function(c)
	return string.format("%g, %g, %g", c._r, c._g, c._b)
end
function C3methods.Lerp(a, b, t)
	return color(a._r + (b._r - a._r) * t, a._g + (b._g - a._g) * t, a._b + (b._b - a._b) * t)
end
function C3methods.ToHex(c)
	local function h(x)
		return math.clamp(math.floor(x * 255 + 0.5), 0, 255)
	end
	return string.format("%02X%02X%02X", h(c._r), h(c._g), h(c._b))
end
function C3methods.ToHSV(c)
	local r, g, b = c._r, c._g, c._b
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, if mx == 0 then 0 else d / mx, mx
end
Color3 = {
	new = function(r, g, b)
		return color(checkNum(r or 0, "Color3.new", 2), checkNum(g or 0, "Color3.new", 2), checkNum(b or 0, "Color3.new", 2))
	end,
	fromRGB = function(r, g, b)
		return color((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end,
	fromHex = function(hex: string)
		if type(hex) ~= "string" then
			error("invalid argument #1 to 'fromHex' (string expected)", 2)
		end
		local s = hex:gsub("^#", "")
		if #s == 3 then
			s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2)
		end
		if not s:match("^%x%x%x%x%x%x$") then
			error("Unable to convert characters to hex value", 2)
		end
		return color(tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255)
	end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i %= 6
		if i == 0 then
			return color(v, t, p)
		elseif i == 1 then
			return color(q, v, p)
		elseif i == 2 then
			return color(p, v, t)
		elseif i == 3 then
			return color(p, q, v)
		elseif i == 4 then
			return color(t, p, v)
		end
		return color(v, p, q)
	end,
}
Color3.toHSV = function(c)
	return c:ToHSV()
end

-- Rect ------------------------------------------------------------------------
local RectMT = { __type = "Rect" }
RectMT.__index = function(r, k)
	if k == "Min" then
		return r._min
	elseif k == "Max" then
		return r._max
	elseif k == "Width" then
		return r._max.X - r._min.X
	elseif k == "Height" then
		return r._max.Y - r._min.Y
	end
	error(tostring(k) .. " is not a valid member of Rect", 2)
end
RectMT.__newindex = readOnly("Rect")
RectMT.__eq = function(a, b)
	return a._min == b._min and a._max == b._max
end
Rect = {
	new = function(a, b, c, d)
		if getmetatable(a) == V2 then
			return setmetatable({ _min = a, _max = b }, RectMT)
		end
		return setmetatable({ _min = v2(a or 0, b or 0), _max = v2(c or 0, d or 0) }, RectMT)
	end,
}

-- CFrame (only what parking the camera needs) ---------------------------------
local CF = { __type = "CFrame" }
CF.__index = function(c, k)
	if k == "Position" or k == "p" then
		return c._p
	elseif k == "X" then
		return c._p.X
	elseif k == "Y" then
		return c._p.Y
	elseif k == "Z" then
		return c._p.Z
	end
	error(tostring(k) .. " is not a valid member of CFrame", 2)
end
CF.__newindex = readOnly("CFrame")
CF.__eq = function(a, b)
	return a._p == b._p
end
CFrame = {
	new = function(x, y, z)
		if getmetatable(x) == V3 then
			return setmetatable({ _p = x }, CF)
		end
		return setmetatable({ _p = v3(x or 0, y or 0, z or 0) }, CF)
	end,
}
CFrame.identity = CFrame.new()

-- sequences, ranges -----------------------------------------------------------
local function immutable(typeName: string, fields)
	local mt = { __type = typeName }
	mt.__index = function(t, k)
		local v = rawget(t, "_" .. k)
		if v == nil and not fields[k] then
			error(tostring(k) .. " is not a valid member of " .. typeName, 2)
		end
		return v
	end
	mt.__newindex = readOnly(typeName)
	return mt
end

local CSK = immutable("ColorSequenceKeypoint", { Time = true, Value = true })
ColorSequenceKeypoint = {
	new = function(t, c)
		if getmetatable(c) ~= C3 then
			error("ColorSequenceKeypoint.new: Color3 expected", 2)
		end
		return setmetatable({ _Time = checkNum(t, "ColorSequenceKeypoint.new", 2), _Value = c }, CSK)
	end,
}
local CS = immutable("ColorSequence", { Keypoints = true })
CS.__eq = function(a, b)
	local ka, kb = rawget(a, "_Keypoints"), rawget(b, "_Keypoints")
	if #ka ~= #kb then
		return false
	end
	for i, k in ka do
		if k.Time ~= kb[i].Time or k.Value ~= kb[i].Value then
			return false
		end
	end
	return true
end
local function checkKeypoints(kps, what: string)
	if #kps < 2 then
		error(what .. ": requires at least 2 keypoints", 3)
	end
	if kps[1].Time ~= 0 or kps[#kps].Time ~= 1 then
		error(what .. ": keypoints must start at time 0 and end at time 1", 3)
	end
	for i = 2, #kps do
		if kps[i].Time < kps[i - 1].Time then
			error(what .. ": keypoints must be ordered by time", 3)
		end
	end
end
ColorSequence = {
	new = function(a, b)
		local kps
		if getmetatable(a) == C3 then
			kps = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) }
		else
			kps = a
			checkKeypoints(kps, "ColorSequence.new")
		end
		return setmetatable({ _Keypoints = table.clone(kps) }, CS)
	end,
}

local NSK = immutable("NumberSequenceKeypoint", { Time = true, Value = true, Envelope = true })
NumberSequenceKeypoint = {
	new = function(t, v, e)
		return setmetatable({ _Time = checkNum(t, "NumberSequenceKeypoint.new", 2), _Value = checkNum(v, "NumberSequenceKeypoint.new", 2), _Envelope = e or 0 }, NSK)
	end,
}
local NS = immutable("NumberSequence", { Keypoints = true })
NumberSequence = {
	new = function(a, b)
		local kps
		if type(a) == "number" then
			kps = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) }
		else
			kps = a
			checkKeypoints(kps, "NumberSequence.new")
		end
		return setmetatable({ _Keypoints = table.clone(kps) }, NS)
	end,
}

local NR = immutable("NumberRange", { Min = true, Max = true })
NumberRange = {
	new = function(a, b)
		return setmetatable({ _Min = a, _Max = b or a }, NR)
	end,
}

-- Random ------------------------------------------------------------------------
local RandomMT = { __type = "Random" }
RandomMT.__index = RandomMT
local randomSeeds = 0
local function nextRaw(r)
	-- xorshift32
	local x = r._s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	r._s = x
	return x / 4294967296
end
function RandomMT:NextNumber(a, b)
	local u = nextRaw(self)
	if a == nil then
		return u
	end
	return a + (b - a) * u
end
function RandomMT:NextInteger(a, b)
	if b < a then
		error("invalid argument #2 to 'NextInteger' (interval is empty)", 2)
	end
	return a + math.floor(nextRaw(self) * (b - a + 1))
end
function RandomMT:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RandomMT:Clone()
	return setmetatable({ _s = self._s }, RandomMT)
end
Random = {
	new = function(seed)
		if seed == nil then
			randomSeeds += 1
			seed = 12345 + randomSeeds * 7919
		end
		local s = math.floor(math.abs(seed)) % 4294967295
		if s == 0 then
			s = 2463534242
		end
		return setmetatable({ _s = s }, RandomMT)
	end,
}

---------------------------------------------------------------------------
-- Enum
---------------------------------------------------------------------------

local EnumItemMT = { __type = "EnumItem" }
EnumItemMT.__index = function(item, k)
	if k == "Name" then
		return item._name
	elseif k == "Value" then
		return item._value
	elseif k == "EnumType" then
		return item._enum
	elseif k == "IsA" then
		return function(self, name)
			return self._enum._name == name
		end
	end
	error(tostring(k) .. " is not a valid member of EnumItem", 2)
end
EnumItemMT.__newindex = readOnly("EnumItem")
EnumItemMT.__tostring = function(item)
	return "Enum." .. item._enum._name .. "." .. item._name
end

local EnumMT = { __type = "Enum" }
EnumMT.__index = function(e, k)
	local item = e._items[k]
	if item then
		return item
	end
	if k == "GetEnumItems" then
		return function(self)
			return table.clone(self._list)
		end
	elseif k == "FromName" then
		return function(self, name)
			return self._items[name]
		end
	elseif k == "FromValue" then
		return function(self, value)
			for _, it in self._list do
				if it._value == value then
					return it
				end
			end
			return nil
		end
	end
	error(tostring(k) .. " is not a valid member of \"Enum." .. e._name .. "\"", 2)
end
EnumMT.__newindex = readOnly("Enum")
EnumMT.__tostring = function(e)
	return e._name
end

local enums = {}
-- items Roblox has that the type definitions leave out
local EXTRA_ITEMS = { KeyCode = { "Unknown" } }
local function getEnum(name: string)
	local e = enums[name]
	if e then
		return e
	end
	local items = FAKE_ENUMS[name]
	if not items then
		return nil
	end
	if EXTRA_ITEMS[name] then
		items = table.clone(items)
		for _, extra in EXTRA_ITEMS[name] do
			table.insert(items, extra)
		end
	end
	e = setmetatable({ _name = name, _items = {}, _list = {} }, EnumMT)
	for i, itemName in items do
		local it = setmetatable({ _name = itemName, _value = i - 1, _enum = e }, EnumItemMT)
		rawget(e, "_items")[itemName] = it
		table.insert(rawget(e, "_list"), it)
	end
	enums[name] = e
	return e
end

Enum = setmetatable({}, {
	__type = "Enums",
	__index = function(_, name)
		local e = getEnum(name)
		if not e then
			error(tostring(name) .. " is not a valid member of \"Enum\" (or tests/fake/classes.luau needs regenerating)", 2)
		end
		return e
	end,
	__newindex = readOnly("Enums"),
})

-- Font --------------------------------------------------------------------------
local FontMT = { __type = "Font" }
FontMT.__index = function(f, k)
	if k == "Family" then
		return f._family
	elseif k == "Weight" then
		return f._weight
	elseif k == "Style" then
		return f._style
	elseif k == "Bold" then
		return f._weight._value >= getEnum("FontWeight")._items.Bold._value
	end
	error(tostring(k) .. " is not a valid member of Font", 2)
end
FontMT.__newindex = function(f, k, v)
	if k == "Weight" then
		rawset(f, "_weight", v)
	elseif k == "Style" then
		rawset(f, "_style", v)
	elseif k == "Bold" then
		rawset(f, "_weight", if v then Enum.FontWeight.Bold else Enum.FontWeight.Regular)
	else
		error(tostring(k) .. " cannot be assigned to", 2)
	end
end
FontMT.__eq = function(a, b)
	return a._family == b._family and a._weight == b._weight and a._style == b._style
end
local FONT_FAMILIES = {
	LuckiestGuy = "rbxasset://fonts/families/LuckiestGuy.json",
	Nunito = "rbxasset://fonts/families/Nunito.json",
	SourceSans = "rbxasset://fonts/families/SourceSansPro.json",
	FredokaOne = "rbxasset://fonts/families/FredokaOne.json",
}
Font = {
	new = function(family, weight, style)
		if type(family) ~= "string" then
			error("Font.new: family must be a string", 2)
		end
		if weight ~= nil and (getmetatable(weight) ~= EnumItemMT or weight._enum._name ~= "FontWeight") then
			error("Font.new: weight must be an Enum.FontWeight", 2)
		end
		return setmetatable({ _family = family, _weight = weight or Enum.FontWeight.Regular, _style = style or Enum.FontStyle.Normal }, FontMT)
	end,
	fromEnum = function(e)
		if getmetatable(e) ~= EnumItemMT or e._enum._name ~= "Font" then
			error("Font.fromEnum: Enum.Font expected", 2)
		end
		return Font.new(FONT_FAMILIES[e._name] or ("rbxasset://fonts/families/" .. e._name .. ".json"))
	end,
	fromName = function(name, weight, style)
		return Font.new("rbxasset://fonts/families/" .. name .. ".json", weight, style)
	end,
	fromId = function(id, weight, style)
		return Font.new("rbxassetid://" .. tostring(id), weight, style)
	end,
}

-- TweenInfo -----------------------------------------------------------------------
local TI = immutable("TweenInfo", { Time = true, EasingStyle = true, EasingDirection = true, RepeatCount = true, Reverses = true, DelayTime = true })
TweenInfo = {
	new = function(t, style, dir, repeatCount, reverses, delayTime)
		local function isEnum(v, name)
			return v == nil or (getmetatable(v) == EnumItemMT and v._enum._name == name)
		end
		if not isEnum(style, "EasingStyle") then
			error("TweenInfo.new: EasingStyle expected, got " .. tostring(style), 2)
		end
		if not isEnum(dir, "EasingDirection") then
			error("TweenInfo.new: EasingDirection expected, got " .. tostring(dir), 2)
		end
		return setmetatable({
			_Time = checkNum(t or 1, "TweenInfo.new", 2),
			_EasingStyle = style or Enum.EasingStyle.Quad,
			_EasingDirection = dir or Enum.EasingDirection.Out,
			_RepeatCount = repeatCount or 0,
			_Reverses = reverses == true,
			_DelayTime = delayTime or 0,
		}, TI)
	end,
}

---------------------------------------------------------------------------
-- typeof
---------------------------------------------------------------------------

typeof = function(v)
	local t = type(v)
	if t == "table" then
		local mt = getmetatable(v)
		if type(mt) == "table" then
			local tag = rawget(mt, "__type")
			if tag then
				return tag
			end
		end
	end
	return realTypeof(v)
end

---------------------------------------------------------------------------
-- instances
---------------------------------------------------------------------------

local S = setmetatable({}, { __mode = "k" }) -- instance -> state
local InstanceMT = { __type = "Instance" }
local layoutVersion = 0
local nextDebugId = 0

local classes = {}
local function classInfo(name: string)
	local c = classes[name]
	if c then
		return c
	end
	local raw = FAKE_CLASSES[name]
	if not raw then
		return nil
	end
	local super = if raw[1] ~= "" then classInfo(raw[1]) else nil
	c = {
		name = name,
		super = super,
		props = if super then table.clone(super.props) else {},
		signals = if super then table.clone(super.signals) else {},
		methods = if super then table.clone(super.methods) else {},
		isA = if super then table.clone(super.isA) else {},
	}
	c.isA[name] = true
	for k, v in raw[2] do
		c.props[k] = v
	end
	for _, s in raw[3] do
		c.signals[s] = true
	end
	for _, m in raw[4] do
		c.methods[m] = true
	end
	classes[name] = c
	return c
end

local READ_ONLY = {
	ClassName = true,
	AbsoluteSize = true,
	AbsolutePosition = true,
	AbsoluteRotation = true,
	AbsoluteContentSize = true,
	AbsoluteCanvasSize = true,
	AbsoluteWindowSize = true,
	TextBounds = true,
	TextFits = true,
	ContentText = true,
	IsLoaded = true,
	IsPlaying = true,
	IsPaused = true,
	TimeLength = true,
	PlaybackState = true,
	UserId = true,
	LocalPlayer = true,
	ViewportSize = true,
	GuiState = true,
	TotalGroupScale = true,
	CurrentCamera = false,
}

-- Defaults Roblox gives, where they matter (everything else gets its type's zero).
local DEFAULTS = {
	Visible = true,
	Enabled = true,
	Archivable = true,
	Interactable = true,
	AutoButtonColor = true,
	ScrollingEnabled = true,
	ResetOnSpawn = true,
	AutoLocalize = true,
	TextStrokeTransparency = 1,
	TextSize = 14,
	LineHeight = 1,
	MaxVisibleGraphemes = -1,
	Thickness = 1,
	Scale = 1,
	AspectRatio = 1,
	Volume = 0.5,
	PlaybackSpeed = 1,
	ResolutionScale = 1,
	ZIndex = 1,
	ScrollBarThickness = 12,
	ScrollRate = 1,
	MaxTextSize = 100,
	MinTextSize = 1,
	SliceScale = 1,
	FillDirectionMaxCells = 0,
	DisplayOrder = 0,
}
local function defaultFor(st, name: string, ptype: string)
	local d = DEFAULTS[name]
	if d ~= nil then
		return d
	end
	local cls = st.cls
	if name == "Name" then
		return cls.name
	elseif name == "Size" and cls.isA.GuiObject then
		return udim2(0, 100, 0, 100)
	elseif name == "CanvasSize" then
		return udim2(0, 0, 2, 0)
	elseif name == "CellSize" then
		return udim2(0, 100, 0, 100)
	elseif name == "CellPadding" then
		return udim2(0, 5, 0, 5)
	elseif name == "MaxSize" then
		return v2(math.huge, math.huge)
	elseif name == "Active" then
		return cls.isA.GuiButton == true or cls.isA.TextBox == true
	elseif name == "Selectable" then
		return cls.isA.GuiButton == true
	elseif name == "Font" and ptype == "EnumFont" then
		return Enum.Font.Legacy
	elseif name == "FillDirection" and cls.isA.UIGridLayout then
		return Enum.FillDirection.Horizontal
	elseif name == "HorizontalAlignment" then
		return Enum.HorizontalAlignment.Left
	elseif name == "VerticalAlignment" then
		return Enum.VerticalAlignment.Top
	elseif name == "SortOrder" then
		return Enum.SortOrder.LayoutOrder
	elseif name == "ZIndexBehavior" then
		return Enum.ZIndexBehavior.Sibling
	elseif name == "ScreenInsets" then
		return Enum.ScreenInsets.CoreUISafeInsets
	elseif name == "ApplyStrokeMode" then
		return Enum.ApplyStrokeMode.Contextual
	elseif name == "SizeConstraint" then
		return Enum.SizeConstraint.RelativeXY
	elseif name == "AspectType" then
		return Enum.AspectType.FitWithinMaxSize
	elseif name == "DominantAxis" then
		return Enum.DominantAxis.Width
	elseif name == "TextXAlignment" then
		return Enum.TextXAlignment.Center
	elseif name == "TextYAlignment" then
		return Enum.TextYAlignment.Center
	elseif name == "Color" and ptype == "ColorSequence" then
		return ColorSequence.new(color(1, 1, 1))
	elseif name == "Transparency" and ptype == "NumberSequence" then
		return NumberSequence.new(0)
	elseif name == "ImageColor3" or name == "GroupColor3" or name == "BackgroundColor3" then
		return color(1, 1, 1)
	end
	if ptype == "number" then
		return 0
	elseif ptype == "boolean" then
		return false
	elseif ptype == "string" then
		return ""
	elseif ptype == "UDim2" then
		return udim2(0, 0, 0, 0)
	elseif ptype == "UDim" then
		return udim(0, 0)
	elseif ptype == "Vector2" then
		return Vector2.zero
	elseif ptype == "Vector3" then
		return Vector3.zero
	elseif ptype == "Color3" then
		return color(0, 0, 0)
	elseif ptype == "Rect" then
		return Rect.new(0, 0, 0, 0)
	elseif ptype == "Font" then
		return Font.new(FONT_FAMILIES.SourceSans)
	elseif ptype == "CFrame" then
		return CFrame.identity
	elseif ptype == "NumberRange" then
		return NumberRange.new(0, 0)
	elseif ptype == "ColorSequence" then
		return ColorSequence.new(color(1, 1, 1))
	elseif ptype == "NumberSequence" then
		return NumberSequence.new(0)
	elseif ptype:sub(1, 4) == "Enum" then
		local e = getEnum(ptype:sub(5))
		return e and rawget(e, "_list")[1]
	end
	return nil
end

local function className(inst)
	local st = S[inst]
	return if st then st.cls.name else "?"
end

local function fullName(inst): string
	local parts = {}
	local node = inst
	while node and S[node] do
		local st = S[node]
		if st.cls.name == "DataModel" then
			break
		end
		table.insert(parts, 1, st.props.Name or st.cls.name)
		node = st.parent
	end
	return table.concat(parts, ".")
end

local function coerceEnum(ptype: string, value)
	local enumName = ptype:sub(5)
	if getmetatable(value) == EnumItemMT then
		if value._enum._name ~= enumName then
			return nil
		end
		return value
	end
	local e = getEnum(enumName)
	if not e then
		return nil
	end
	if type(value) == "string" then
		return rawget(e, "_items")[value]
	elseif type(value) == "number" then
		for _, it in rawget(e, "_list") do
			if it._value == value then
				return it
			end
		end
	end
	return nil
end

-- Returns the value to store, or raises Roblox's error for a wrong type.
local function checkValue(inst, name: string, ptype: string, value)
	if ptype == "any" then
		return value
	elseif ptype == "number" then
		if type(value) ~= "number" then
			error(string.format("Unable to assign property %s. number expected, got %s", name, typeof(value)), 4)
		end
		return value
	elseif ptype == "boolean" then
		if type(value) ~= "boolean" then
			error(string.format("Unable to assign property %s. bool expected, got %s", name, typeof(value)), 4)
		end
		return value
	elseif ptype == "string" then
		if type(value) == "number" then
			return tostring(value)
		end
		if type(value) ~= "string" then
			error(string.format("Unable to assign property %s. string expected, got %s", name, typeof(value)), 4)
		end
		return value
	elseif ptype:sub(1, 4) == "Enum" then
		local v = coerceEnum(ptype, value)
		if v == nil then
			error(string.format("Unable to assign property %s. %s expected, got %s", name, ptype, tostring(value)), 4)
		end
		return v
	elseif ptype:sub(1, 9) == "Instance:" then
		if value == nil then
			return nil
		end
		local st = S[value]
		if not st then
			error(string.format("Unable to assign property %s. Instance expected, got %s", name, typeof(value)), 4)
		end
		local want = ptype:sub(10)
		if not st.cls.isA[want] and want ~= "Instance" then
			error(string.format("Unable to assign property %s. %s expected, got %s", name, want, st.cls.name), 4)
		end
		return value
	elseif ptype == "Content" then
		return value
	end
	-- datatypes
	if typeof(value) ~= ptype then
		error(string.format("Unable to assign property %s. %s expected, got %s", name, ptype, typeof(value)), 4)
	end
	return value
end

local signalsOf -- forward
local computed -- forward
local methodsFor -- forward

local function propSignal(st, name: string)
	st.propSignals = st.propSignals or {}
	local sig = st.propSignals[name]
	if not sig then
		sig = newSignal(name)
		st.propSignals[name] = sig
	end
	return sig
end

local function eventOf(st, name: string)
	st.signals = st.signals or {}
	local sig = st.signals[name]
	if not sig then
		sig = newSignal(name)
		st.signals[name] = sig
	end
	return sig
end

local function fireEvent(st, name: string, ...)
	local sig = st.signals and st.signals[name]
	if sig and hasListeners(sig) then
		fire(sig, ...)
	end
end

local function changed(inst, st, name: string)
	layoutVersion += 1
	local ps = st.propSignals and st.propSignals[name]
	if ps and hasListeners(ps) then
		fire(ps)
	end
	if st.cls.isA.ValueBase then
		-- value objects say what the new value is, and only for Value
		if name == "Value" then
			fireEvent(st, "Changed", st.props.Value)
		end
	else
		fireEvent(st, "Changed", name)
	end
	local hook = st.onSet
	if hook then
		hook(inst, name)
	end
end

local function isDescendant(inst, ancestor): boolean
	local node = S[inst] and S[inst].parent
	while node do
		if node == ancestor then
			return true
		end
		node = S[node].parent
	end
	return false
end

local function setParent(inst, st, value)
	if st.locked then
		error(string.format("The Parent property of %s is locked, current parent: NULL, new parent %s", st.props.Name or st.cls.name, if value then tostring(value) else "NULL"), 3)
	end
	if value ~= nil and not S[value] then
		error("Unable to assign property Parent. Instance expected, got " .. typeof(value), 3)
	end
	if value == inst or (value ~= nil and isDescendant(value, inst)) then
		error(string.format("Attempt to set parent of %s to %s would result in circular reference", fullName(inst), fullName(value)), 3)
	end
	local old = st.parent
	if old == value then
		return
	end
	if old then
		local ost = S[old]
		local i = table.find(ost.children, inst)
		if i then
			table.remove(ost.children, i)
		end
		fireEvent(ost, "ChildRemoved", inst)
		local node = old
		while node do
			fireEvent(S[node], "DescendantRemoving", inst)
			node = S[node].parent
		end
	end
	st.parent = value
	if value then
		local nst = S[value]
		table.insert(nst.children, inst)
		fireEvent(nst, "ChildAdded", inst)
		local node = value
		while node do
			fireEvent(S[node], "DescendantAdded", inst)
			node = S[node].parent
		end
	end
	fireEvent(st, "AncestryChanged", inst, value)
	changed(inst, st, "Parent")
end

local function newInstance(cls: string, props: { [string]: any }?)
	local info = classInfo(cls)
	if not info then
		error("Unable to create an Instance of type \"" .. tostring(cls) .. "\" (not in tests/fake/classes.luau)", 3)
	end
	local inst = setmetatable({}, InstanceMT)
	nextDebugId += 1
	S[inst] = { cls = info, props = {}, children = {}, parent = nil, attrs = {}, tags = {}, id = nextDebugId }
	if props then
		for k, v in props do
			S[inst].props[k] = v
		end
	end
	return inst
end
F.newInstance = newInstance

InstanceMT.__index = function(inst, key)
	local st = S[inst]
	local cls = st.cls
	-- methods
	if cls.methods[key] then
		local impl = methodsFor(cls, key)
		if impl then
			return impl
		end
		return function()
			error(string.format("fake runtime: %s:%s() isn't implemented (tests/fake/roblox.luau)", cls.name, key), 2)
		end
	end
	-- properties
	local ptype = cls.props[key]
	if ptype then
		if key == "Parent" then
			return st.parent
		end
		local c = computed[key]
		if c then
			local v = c(inst, st)
			if v ~= nil then
				return v
			end
		end
		local v = st.props[key]
		if v ~= nil then
			return v
		end
		return defaultFor(st, key, ptype)
	end
	-- events
	if cls.signals[key] then
		return eventOf(st, key)
	end
	-- children
	for _, child in st.children do
		local cst = S[child]
		if (cst.props.Name or cst.cls.name) == key then
			return child
		end
	end
	if st.virtual and st.virtual[key] then
		return st.virtual[key]
	end
	error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), cls.name, fullName(inst)), 2)
end

InstanceMT.__newindex = function(inst, key, value)
	local st = S[inst]
	local cls = st.cls
	local ptype = cls.props[key]
	if not ptype then
		if cls.signals[key] or cls.methods[key] then
			error(string.format("Unable to assign property %s. Property is read only", tostring(key)), 2)
		end
		error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), cls.name, fullName(inst)), 2)
	end
	if key == "Parent" then
		setParent(inst, st, value)
		return
	end
	if READ_ONLY[key] then
		error(string.format("Unable to assign property %s. Property is read only", key), 2)
	end
	local v = checkValue(inst, key, ptype, value)
	local old = st.props[key]
	if old == nil then
		old = defaultFor(st, key, ptype)
	end
	st.props[key] = v
	if old ~= v then
		changed(inst, st, key)
	end
end

InstanceMT.__tostring = function(inst)
	local st = S[inst]
	return st.props.Name or st.cls.name
end

F.isInstance = function(v)
	return S[v] ~= nil
end
F.state = function(inst)
	return S[inst]
end

---------------------------------------------------------------------------
-- GUI layout (computed on read)
---------------------------------------------------------------------------

F.screen = { w = 1280, h = 720, safe = { l = 0, t = 0, r = 0, b = 0 }, inset = 58, barLeft = 120, barRight = nil, touch = false }

local function gget(inst, key)
	return inst[key]
end

local function isUnderPlayerGui(inst): boolean
	local node = S[inst].parent
	while node do
		if S[node].cls.name == "PlayerGui" then
			return true
		end
		node = S[node].parent
	end
	return false
end

local rectOf -- forward

local function layerRect(gui)
	local scr = F.screen
	if not isUnderPlayerGui(gui) then
		return 0, 0, 0, 0
	end
	local insets = gget(gui, "ScreenInsets")
	if insets == Enum.ScreenInsets.DeviceSafeInsets then
		local s = scr.safe
		return s.l, s.t, scr.w - s.l - s.r, scr.h - s.t - s.b
	end
	if not gget(gui, "IgnoreGuiInset") and insets ~= Enum.ScreenInsets.None then
		return 0, scr.inset, scr.w, scr.h - scr.inset
	end
	return 0, 0, scr.w, scr.h
end

local function childrenOfClass(inst, cls: string)
	local out = {}
	for _, c in S[inst].children do
		if S[c].cls.isA[cls] then
			table.insert(out, c)
		end
	end
	return out
end

local function firstChildOfClass(inst, cls: string)
	for _, c in S[inst].children do
		if S[c].cls.name == cls then
			return c
		end
	end
	return nil
end

local function ownScale(inst): number
	local k = 1
	for _, c in S[inst].children do
		if S[c].cls.name == "UIScale" then
			k *= gget(c, "Scale")
		end
	end
	return k
end

local function textLength(s: string): number
	local ok, n = pcall(utf8.len, s)
	return if ok and n then n else #s
end

local function stripRich(s: string): string
	return (s:gsub("<[^>]->", ""))
end

local function contentText(inst): string
	local text = tostring(rawget(S[inst].props, "Text") or "")
	if S[inst].props.RichText then
		text = stripRich(text)
	end
	return text
end

-- Width and height a text object's text takes, at its TextSize (unscaled).
-- Character widths for the object's font (tests/fake/fonts.luau), or nil.
local function metricsFor(st)
	local fonts = FAKE_FONTS
	if not fonts then
		return nil
	end
	local family, weight = nil, "Regular"
	local face = st.props.FontFace
	if face then
		family = tostring(rawget(face, "_family") or ""):match("families/([%w_]+)%.json")
		local wt = rawget(face, "_weight")
		weight = if wt then wt._name else "Regular"
	elseif st.props.Font then
		family = st.props.Font._name
	end
	local fam = family and fonts[family]
	if not fam then
		return nil
	end
	return fam[weight] or fam.Bold or fam.Regular or select(2, next(fam))
end

local function wordWidth(m, word: string, size: number): number
	local w = 0
	for i = 1, #word do
		local b = string.byte(word, i)
		w += if m and b >= 32 and b <= 126 then m.w[b - 31] else 0.52
	end
	return w * size
end

-- Width and height a text object's text takes, at its TextSize (unscaled), wrapping
-- words at maxWidth when TextWrapped.
local function textExtent(inst, maxWidth: number?): (number, number)
	local st = S[inst]
	local size = st.props.TextSize or 14
	local text = contentText(inst)
	local m = metricsFor(st)
	local wrap = st.props.TextWrapped and maxWidth and maxWidth > 0
	local space = wordWidth(m, " ", size)
	local lines = 0
	local widest = 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		lines += 1
		if not wrap then
			widest = math.max(widest, wordWidth(m, line, size))
		else
			local x = 0
			for word in line:gmatch("%S+") do
				local ww = wordWidth(m, word, size)
				if x > 0 and x + space + ww > (maxWidth :: number) then
					widest = math.max(widest, x)
					lines += 1
					x = ww
				else
					x += (if x > 0 then space else 0) + ww
				end
			end
			widest = math.max(widest, x)
		end
	end
	local lineH = if m then m.line else 1
	return widest, math.max(1, lines) * size * lineH * (st.props.LineHeight or 1)
end

local function constrain(inst, w: number, h: number): (number, number)
	for _, c in S[inst].children do
		local cn = S[c].cls.name
		if cn == "UISizeConstraint" then
			local mn, mx = gget(c, "MinSize"), gget(c, "MaxSize")
			w = math.clamp(w, mn.X, math.max(mn.X, mx.X))
			h = math.clamp(h, mn.Y, math.max(mn.Y, mx.Y))
		end
	end
	for _, c in S[inst].children do
		if S[c].cls.name == "UIAspectRatioConstraint" then
			local r = gget(c, "AspectRatio")
			if r > 0 and h > 0 then
				if w / h > r then
					w = h * r
				else
					h = w / r
				end
			end
		end
	end
	return w, h
end

-- Unscaled size of a GuiObject given its parent's unscaled content size.
local layoutChildren -- (below) a frame sized to fit its children needs them laid out

-- A frame's padding (UIPadding) in unscaled pixels: left + right, top + bottom.
local function paddingOf(inst, w: number, h: number): (number, number)
	for _, c in S[inst].children do
		if S[c].cls.name == "UIPadding" then
			local pl, pr, pt, pb = gget(c, "PaddingLeft"), gget(c, "PaddingRight"), gget(c, "PaddingTop"), gget(c, "PaddingBottom")
			return pl._s * w + pl._o + pr._s * w + pr._o, pt._s * h + pt._o + pb._s * h + pb._o
		end
	end
	return 0, 0
end

local sizeIn
sizeIn = function(inst, pw: number, ph: number): (number, number)
	local size = gget(inst, "Size")
	local sc = gget(inst, "SizeConstraint")
	local bw, bh = pw, ph
	if sc == Enum.SizeConstraint.RelativeXX then
		bh = pw
	elseif sc == Enum.SizeConstraint.RelativeYY then
		bw = ph
	end
	local w = size._xs * bw + size._xo
	local h = size._ys * bh + size._yo
	local auto = gget(inst, "AutomaticSize")
	if auto ~= Enum.AutomaticSize.None then
		local st = S[inst]
		if st.cls.isA.TextLabel or st.cls.isA.TextButton or st.cls.isA.TextBox then
			local tw, th = textExtent(inst, if auto == Enum.AutomaticSize.Y then w else nil)
			if auto ~= Enum.AutomaticSize.Y then
				w = math.max(w, tw)
			end
			if auto ~= Enum.AutomaticSize.X then
				h = math.max(h, th)
			end
		else
			-- a frame grows to fit what's inside it (its list, or its children's offsets)
			local px, py = paddingOf(inst, w, h)
			local cw, ch = 0, 0
			local map, lw, lh = layoutChildren(inst, math.max(0, w - px), math.max(0, h - py))
			if map then
				cw, ch = lw, lh
			else
				for _, c in S[inst].children do
					local cst = S[c]
					if cst.cls.isA.GuiObject and gget(c, "Visible") then
						local kw, kh = sizeIn(c, math.max(0, w - px), math.max(0, h - py))
						local pos = gget(c, "Position")
						cw = math.max(cw, pos._xo + kw)
						ch = math.max(ch, pos._yo + kh)
					end
				end
			end
			if auto ~= Enum.AutomaticSize.Y then
				w = math.max(w, cw + px)
			end
			if auto ~= Enum.AutomaticSize.X then
				h = math.max(h, ch + py)
			end
		end
	end
	return constrain(inst, w, h)
end

-- Layout-controlled positions of a parent's children: child -> {x, y, w, h} unscaled,
-- relative to the parent's content box.
layoutChildren = function(parent, pw: number, ph: number)
	local st = S[parent]
	local cache = st.layoutCache
	if cache and cache.ver == layoutVersion and cache.pw == pw and cache.ph == ph then
		return cache.map, cache.cw, cache.ch
	end
	local list = firstChildOfClass(parent, "UIListLayout")
	local grid = firstChildOfClass(parent, "UIGridLayout")
	if list and grid and not st.warnedLayouts then
		-- Roblox lays a frame out with only one of them (here, the list), so a grid
		-- added next to a list never arranges anything
		st.warnedLayouts = true
		warn("two layouts in " .. fullName(parent) .. ": Roblox uses only one, so the UIGridLayout is ignored")
	end
	local layout = list or grid
	if not layout then
		st.layoutCache = { ver = layoutVersion, pw = pw, ph = ph, map = false, cw = 0, ch = 0 }
		return false, 0, 0
	end
	local kids = {}
	for _, c in st.children do
		local cst = S[c]
		if cst.cls.isA.GuiObject and gget(c, "Visible") then
			table.insert(kids, c)
		end
	end
	local byName = gget(layout, "SortOrder") == Enum.SortOrder.Name
	table.sort(kids, function(a, b)
		if byName then
			return tostring(a) < tostring(b)
		end
		local la, lb = gget(a, "LayoutOrder"), gget(b, "LayoutOrder")
		if la ~= lb then
			return la < lb
		end
		return S[a].id < S[b].id
	end)
	local map = {}
	local cw, ch = 0, 0
	local horizontal = gget(layout, "FillDirection") == Enum.FillDirection.Horizontal
	if list then
		local pad = gget(layout, "Padding")
		local gap = pad._s * (if horizontal then pw else ph) + pad._o
		local pos = 0
		local sizes = {}
		for i, c in kids do
			local w, h = sizeIn(c, pw, ph)
			sizes[i] = { w, h }
			if horizontal then
				ch = math.max(ch, h)
			else
				cw = math.max(cw, w)
			end
		end
		for i, c in kids do
			local w, h = sizes[i][1], sizes[i][2]
			if horizontal then
				map[c] = { pos, 0, w, h }
				pos += w + (if i < #kids then gap else 0)
			else
				map[c] = { 0, pos, w, h }
				pos += h + (if i < #kids then gap else 0)
			end
		end
		if horizontal then
			cw = pos
		else
			ch = pos
		end
		-- alignment
		local ha, va = gget(layout, "HorizontalAlignment"), gget(layout, "VerticalAlignment")
		for _, c in kids do
			local r = map[c]
			if horizontal then
				if ha == Enum.HorizontalAlignment.Center then
					r[1] += (pw - cw) / 2
				elseif ha == Enum.HorizontalAlignment.Right then
					r[1] += pw - cw
				end
				if va == Enum.VerticalAlignment.Center then
					r[2] = (ph - r[4]) / 2
				elseif va == Enum.VerticalAlignment.Bottom then
					r[2] = ph - r[4]
				end
			else
				if va == Enum.VerticalAlignment.Center then
					r[2] += (ph - ch) / 2
				elseif va == Enum.VerticalAlignment.Bottom then
					r[2] += ph - ch
				end
				if ha == Enum.HorizontalAlignment.Center then
					r[1] = (pw - r[3]) / 2
				elseif ha == Enum.HorizontalAlignment.Right then
					r[1] = pw - r[3]
				end
			end
		end
	else
		local cell, cpad = gget(grid, "CellSize"), gget(grid, "CellPadding")
		local w = cell._xs * pw + cell._xo
		local h = cell._ys * ph + cell._yo
		local gx = cpad._xs * pw + cpad._xo
		local gy = cpad._ys * ph + cpad._yo
		local fit = (pw + gx) / math.max(1, w + gx)
		local perRow = math.max(1, math.floor(fit))
		if cell._xs ~= 0 and fit >= 1.99 and math.abs(fit - math.floor(fit + 0.5)) < 0.01 and not st.warnedGrid then
			-- scaled cells that add up to exactly the row: Roblox's rounding wraps a row a
			-- cell early now and then, and the last cell falls out of the frame (the map
			-- picker lost Clockwork Cove that way); Util.grid places the cells itself
			st.warnedGrid = true
			warn("grid cells fill a row exactly in " .. fullName(parent) .. ": Roblox can wrap a cell early (use Util.grid)")
		end
		local maxCells = gget(grid, "FillDirectionMaxCells")
		if maxCells > 0 then
			perRow = math.min(perRow, maxCells)
		end
		for i, c in kids do
			local col = (i - 1) % perRow
			local row = (i - 1) // perRow
			local cw2, ch2 = constrain(c, w, h)
			map[c] = { col * (w + gx), row * (h + gy), cw2, ch2 }
		end
		local rows = math.ceil(#kids / perRow)
		cw = math.min(#kids, perRow) * (w + gx) - gx
		ch = rows * (h + gy) - gy
		if gget(grid, "HorizontalAlignment") == Enum.HorizontalAlignment.Center then
			for _, c in kids do
				map[c][1] += (pw - cw) / 2
			end
		end
	end
	st.layoutCache = { ver = layoutVersion, pw = pw, ph = ph, map = map, cw = math.max(0, cw), ch = math.max(0, ch) }
	return map, math.max(0, cw), math.max(0, ch)
end

-- The box children are laid out in: absolute x, y, w, h and the scale on offsets.
local function contentBox(inst): (number, number, number, number, number)
	local st = S[inst]
	if st.cls.isA.LayerCollector then
		local x, y, w, h = layerRect(inst)
		return x, y, w, h, 1
	end
	local x, y, w, h, s = rectOf(inst)
	local pad = firstChildOfClass(inst, "UIPadding")
	if pad then
		local pl, pr, pt, pb = gget(pad, "PaddingLeft"), gget(pad, "PaddingRight"), gget(pad, "PaddingTop"), gget(pad, "PaddingBottom")
		local l = pl._s * w + pl._o * s
		local r = pr._s * w + pr._o * s
		local t = pt._s * h + pt._o * s
		local b = pb._s * h + pb._o * s
		x, y, w, h = x + l, y + t, math.max(0, w - l - r), math.max(0, h - t - b)
	end
	if st.cls.name == "ScrollingFrame" then
		local cs = gget(inst, "CanvasSize")
		local cp = gget(inst, "CanvasPosition")
		local cw = cs._xs * w + cs._xo * s
		local ch = cs._ys * h + cs._yo * s
		local auto = gget(inst, "AutomaticCanvasSize")
		if auto ~= Enum.AutomaticSize.None then
			local _, lw, lh = layoutChildren(inst, w / s, h / s)
			if auto ~= Enum.AutomaticSize.Y then
				cw = math.max(cw, lw * s)
			end
			if auto ~= Enum.AutomaticSize.X then
				ch = math.max(ch, lh * s)
			end
		end
		x -= cp.X * s
		y -= cp.Y * s
		w, h = math.max(w, cw), math.max(h, ch)
	end
	return x, y, w, h, s
end

rectOf = function(inst): (number, number, number, number, number)
	local st = S[inst]
	local rc = st.rectCache
	if rc and rc[1] == layoutVersion and rc[7] == F.screenVersion then
		return rc[2], rc[3], rc[4], rc[5], rc[6]
	end
	local parent = st.parent
	local x, y, w, h, s = 0, 0, 0, 0, 1
	if parent and (S[parent].cls.isA.GuiObject or S[parent].cls.isA.LayerCollector) then
		local px, py, pw, ph, ps = contentBox(parent)
		local upw, uph = pw / ps, ph / ps
		local map = layoutChildren(parent, upw, uph)
		local k = ownScale(inst)
		local sc = ps * k
		local slot = map and map[inst]
		if slot then
			x = px + slot[1] * ps
			y = py + slot[2] * ps
			w = slot[3] * sc
			h = slot[4] * sc
		else
			local w0, h0 = sizeIn(inst, upw, uph)
			local pos = gget(inst, "Position")
			local anchor = gget(inst, "AnchorPoint")
			local ax = px + (pos._xs * upw + pos._xo) * ps
			local ay = py + (pos._ys * uph + pos._yo) * ps
			w, h = w0 * sc, h0 * sc
			x = ax - anchor.X * w
			y = ay - anchor.Y * h
		end
		s = sc
	end
	st.rectCache = { layoutVersion, x, y, w, h, s, F.screenVersion }
	return x, y, w, h, s
end
F.screenVersion = 0

computed = {
	ClassName = function(_inst, st)
		return st.cls.name
	end,
	Name = function(_inst, st)
		return st.props.Name or st.cls.name
	end,
	AbsoluteSize = function(inst, st)
		if st.cls.isA.LayerCollector then
			local _, _, w, h = layerRect(inst)
			return v2(w, h)
		elseif st.cls.isA.GuiObject then
			local _, _, w, h = rectOf(inst)
			return v2(w, h)
		end
		return nil
	end,
	AbsolutePosition = function(inst, st)
		if st.cls.isA.LayerCollector then
			local x, y = layerRect(inst)
			return v2(x, y)
		elseif st.cls.isA.GuiObject then
			local x, y = rectOf(inst)
			return v2(x, y)
		end
		return nil
	end,
	AbsoluteRotation = function(inst, st)
		local r = 0
		local node = inst
		while node and S[node].cls.isA.GuiObject do
			r += gget(node, "Rotation")
			node = S[node].parent
		end
		return r
	end,
	TextBounds = function(inst, st)
		if not st.cls.props.TextBounds then
			return nil
		end
		local _, _, w, _, s = rectOf(inst)
		local tw, th = textExtent(inst, if w > 0 then w / s else nil)
		return v2(tw * s, th * s)
	end,
	TextFits = function(inst, st)
		local _, _, w, h, s = rectOf(inst)
		local tw, th = textExtent(inst, if w > 0 then w / s else nil)
		return tw * s <= w + 0.5 and th * s <= h + 0.5
	end,
	ContentText = function(inst, st)
		if not st.cls.props.ContentText then
			return nil
		end
		return contentText(inst)
	end,
	AbsoluteContentSize = function(inst, st)
		local parent = st.parent
		if not parent or not (S[parent].cls.isA.GuiObject or S[parent].cls.isA.LayerCollector) then
			return Vector2.zero
		end
		local _, _, pw, ph, ps = contentBox(parent)
		local _, cw, ch = layoutChildren(parent, pw / ps, ph / ps)
		return v2(cw * ps, ch * ps)
	end,
	AbsoluteWindowSize = function(inst, st)
		local _, _, w, h = rectOf(inst)
		return v2(w, h)
	end,
	AbsoluteCanvasSize = function(inst, st)
		local _, _, w, h = contentBox(inst)
		return v2(w, h)
	end,
	ViewportSize = function(inst, st)
		if st.cls.name == "Camera" then
			return v2(F.screen.w, F.screen.h)
		end
		return nil
	end,
	IsPlaying = function(inst, st)
		if st.cls.name == "Sound" then
			return st.props.Playing == true
		end
		return nil
	end,
	TimeLength = function(inst, st)
		if st.cls.name == "Sound" then
			return st.timeLength or 1.5
		end
		return nil
	end,
	IsLoaded = function(_inst, st)
		if st.cls.name == "Sound" then
			return true
		end
		return nil
	end,
}

-- Absolute* change events, checked once per frame for instances someone listens to.
local ABS_PROPS = { "AbsoluteSize", "AbsolutePosition", "TextBounds", "AbsoluteContentSize", "AbsoluteCanvasSize", "AbsoluteWindowSize" }
local watched = setmetatable({}, { __mode = "k" })
local function startWatching(inst, prop)
	local w = watched[inst]
	if not w then
		w = {}
		watched[inst] = w
	end
	if w[prop] == nil then
		w[prop] = inst[prop]
	end
end
local function checkWatched()
	for inst, w in watched do
		local st = S[inst]
		if st and not st.destroyed and st.propSignals then
			for prop, last in w do
				local sig = st.propSignals[prop]
				if sig and hasListeners(sig) then
					local now = inst[prop]
					if now ~= last then
						w[prop] = now
						fire(sig)
						fireEvent(st, "Changed", prop)
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- instance methods
---------------------------------------------------------------------------

local METHODS = {}
methodsFor = function(cls, name)
	local c = cls
	while c do
		local m = METHODS[c.name]
		if m and m[name] then
			return m[name]
		end
		c = c.super
	end
	return nil
end

local function children(inst)
	return S[inst].children
end

local function nameOf(inst)
	local st = S[inst]
	return st.props.Name or st.cls.name
end

local function findChild(inst, name, recursive)
	for _, c in children(inst) do
		if nameOf(c) == name then
			return c
		end
	end
	local st = S[inst]
	if st.virtual and st.virtual[name] then
		return st.virtual[name]
	end
	if recursive then
		for _, c in children(inst) do
			local found = findChild(c, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

local function descendants(inst, out)
	for _, c in children(inst) do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end

local destroy
destroy = function(inst)
	local st = S[inst]
	if st.destroyed then
		return
	end
	st.destroyed = true
	fireEvent(st, "Destroying")
	for _, c in table.clone(st.children) do
		destroy(c)
	end
	if st.parent then
		setParent(inst, st, nil)
	end
	st.locked = true
	F.onDestroy(inst)
	-- connections die with the instance (deferred ones queued above still run)
	task.defer(function()
		if st.signals then
			for _, sig in st.signals do
				disconnectAll(sig)
			end
		end
		if st.propSignals then
			for _, sig in st.propSignals do
				disconnectAll(sig)
			end
		end
		if st.attrSignals then
			for _, sig in st.attrSignals do
				disconnectAll(sig)
			end
		end
	end)
end
F.onDestroy = function(_inst) end

local function clone(inst)
	local st = S[inst]
	if st.props.Archivable == false then
		return nil
	end
	local copy = newInstance(st.cls.name)
	local cst = S[copy]
	for k, v in st.props do
		cst.props[k] = v
	end
	for k, v in st.attrs do
		cst.attrs[k] = v
	end
	for k in st.tags do
		cst.tags[k] = true
	end
	cst.timeLength = st.timeLength
	for _, c in st.children do
		local cc = clone(c)
		if cc then
			setParent(cc, S[cc], copy)
		end
	end
	return copy
end

local ATTR_TYPES = {
	string = true, boolean = true, number = true, UDim = true, UDim2 = true, BrickColor = true, Color3 = true,
	Vector2 = true, Vector3 = true, NumberSequence = true, ColorSequence = true, NumberRange = true, Rect = true, Font = true, CFrame = true, EnumItem = true,
}

METHODS.Object = {
	IsA = function(self, name)
		return S[self].cls.isA[name] == true
	end,
	GetPropertyChangedSignal = function(self, prop)
		local st = S[self]
		if not st.cls.props[prop] then
			error(string.format("%s is not a valid property name.", tostring(prop)), 2)
		end
		for _, p in ABS_PROPS do
			if p == prop then
				startWatching(self, prop)
			end
		end
		return propSignal(st, prop)
	end,
}

METHODS.Instance = {
	FindFirstChild = function(self, name, recursive)
		return findChild(self, name, recursive)
	end,
	FindFirstChildOfClass = function(self, cls)
		for _, c in children(self) do
			if S[c].cls.name == cls then
				return c
			end
		end
		return nil
	end,
	FindFirstChildWhichIsA = function(self, cls, recursive)
		for _, c in children(self) do
			if S[c].cls.isA[cls] then
				return c
			end
		end
		if recursive then
			for _, c in children(self) do
				local f = METHODS.Instance.FindFirstChildWhichIsA(c, cls, true)
				if f then
					return f
				end
			end
		end
		return nil
	end,
	FindFirstDescendant = function(self, name)
		return findChild(self, name, true)
	end,
	FindFirstAncestor = function(self, name)
		local node = S[self].parent
		while node do
			if nameOf(node) == name then
				return node
			end
			node = S[node].parent
		end
		return nil
	end,
	FindFirstAncestorOfClass = function(self, cls)
		local node = S[self].parent
		while node do
			if S[node].cls.name == cls then
				return node
			end
			node = S[node].parent
		end
		return nil
	end,
	FindFirstAncestorWhichIsA = function(self, cls)
		local node = S[self].parent
		while node do
			if S[node].cls.isA[cls] then
				return node
			end
			node = S[node].parent
		end
		return nil
	end,
	WaitForChild = function(self, name, timeout)
		local found = findChild(self, name)
		if found then
			return found
		end
		local co = coroutine.running()
		if not coroutine.isyieldable() then
			error("WaitForChild(" .. tostring(name) .. ") would yield outside a thread", 2)
		end
		local start = F.now
		local warned = false
		while true do
			task.wait()
			found = findChild(self, name)
			if found then
				return found
			end
			if timeout and F.now - start >= timeout then
				return nil
			end
			if not timeout and not warned and F.now - start >= 5 then
				warned = true
				warn(string.format("Infinite yield possible on '%s:WaitForChild(\"%s\")'", fullName(self), tostring(name)))
			end
			local _ = co
		end
	end,
	GetChildren = function(self)
		return table.clone(children(self))
	end,
	GetDescendants = function(self)
		return descendants(self, {})
	end,
	IsDescendantOf = function(self, ancestor)
		return isDescendant(self, ancestor)
	end,
	IsAncestorOf = function(self, descendant)
		return isDescendant(descendant, self)
	end,
	GetFullName = function(self)
		return fullName(self)
	end,
	Destroy = function(self)
		destroy(self)
	end,
	Remove = function(self)
		local st = S[self]
		setParent(self, st, nil)
	end,
	Clone = function(self)
		return clone(self)
	end,
	ClearAllChildren = function(self)
		for _, c in table.clone(children(self)) do
			destroy(c)
		end
	end,
	GetAttribute = function(self, name)
		return S[self].attrs[name]
	end,
	SetAttribute = function(self, name, value)
		if type(name) ~= "string" or #name == 0 or #name > 100 or name:match("[^%w_]") or name:sub(1, 3) == "RBX" then
			error("SetAttribute: '" .. tostring(name) .. "' isn't a valid attribute name", 2)
		end
		if value ~= nil and not ATTR_TYPES[typeof(value)] then
			error("SetAttribute: " .. typeof(value) .. " is not a supported attribute type", 2)
		end
		local st = S[self]
		if st.attrs[name] ~= value then
			st.attrs[name] = value
			fireEvent(st, "AttributeChanged", name)
			local sig = st.attrSignals and st.attrSignals[name]
			if sig then
				fire(sig)
			end
		end
	end,
	GetAttributes = function(self)
		return table.clone(S[self].attrs)
	end,
	GetAttributeChangedSignal = function(self, name)
		local st = S[self]
		st.attrSignals = st.attrSignals or {}
		local sig = st.attrSignals[name]
		if not sig then
			sig = newSignal("attr:" .. name)
			st.attrSignals[name] = sig
		end
		return sig
	end,
	AddTag = function(self, tag)
		S[self].tags[tag] = true
	end,
	RemoveTag = function(self, tag)
		S[self].tags[tag] = nil
	end,
	HasTag = function(self, tag)
		return S[self].tags[tag] == true
	end,
	GetTags = function(self)
		local out = {}
		for t in S[self].tags do
			table.insert(out, t)
		end
		return out
	end,
	GetActor = function()
		return nil
	end,
	GetDebugId = function(self)
		return tostring(S[self].id)
	end,
}

---------------------------------------------------------------------------
-- Instance.new
---------------------------------------------------------------------------

local SERVICE_CLASSES = {}
Instance = {
	new = function(cls: string, parent)
		if SERVICE_CLASSES[cls] then
			error("Unable to create an Instance of type \"" .. cls .. "\"", 2)
		end
		local info = classInfo(cls)
		if not info then
			error("Unable to create an Instance of type \"" .. tostring(cls) .. "\" (unknown to the fake: add it to tools/gen_fake_roblox.py)", 2)
		end
		local inst = newInstance(cls)
		local hook = F.onCreate[cls]
		if hook then
			hook(inst, S[inst])
		end
		if parent ~= nil then
			inst.Parent = parent
		end
		return inst
	end,
}
F.onCreate = {}

---------------------------------------------------------------------------
-- tweens
---------------------------------------------------------------------------

local TWEENABLE = { number = true, UDim2 = true, UDim = true, Vector2 = true, Vector3 = true, Color3 = true, Rect = true, CFrame = true, boolean = true }
local tweens = {} -- playing tweens

local function ease(style, dir, t: number): number
	local name = style._name
	local function inF(x)
		if name == "Linear" then
			return x
		elseif name == "Sine" then
			return 1 - math.cos(x * math.pi / 2)
		elseif name == "Back" then
			local c = 1.70158
			return (c + 1) * x ^ 3 - c * x ^ 2
		elseif name == "Bounce" then
			local function out(y)
				if y < 1 / 2.75 then
					return 7.5625 * y * y
				elseif y < 2 / 2.75 then
					y -= 1.5 / 2.75
					return 7.5625 * y * y + 0.75
				elseif y < 2.5 / 2.75 then
					y -= 2.25 / 2.75
					return 7.5625 * y * y + 0.9375
				end
				y -= 2.625 / 2.75
				return 7.5625 * y * y + 0.984375
			end
			return 1 - out(1 - x)
		elseif name == "Elastic" then
			if x == 0 or x == 1 then
				return x
			end
			return -(2 ^ (10 * x - 10)) * math.sin((x * 10 - 10.75) * (2 * math.pi) / 3)
		elseif name == "Exponential" then
			return if x == 0 then 0 else 2 ^ (10 * x - 10)
		elseif name == "Circular" then
			return 1 - math.sqrt(1 - x * x)
		elseif name == "Quart" then
			return x ^ 4
		elseif name == "Quint" then
			return x ^ 5
		elseif name == "Cubic" then
			return x ^ 3
		end
		return x * x -- Quad
	end
	local d = dir._name
	if d == "In" then
		return inF(t)
	elseif d == "Out" then
		return 1 - inF(1 - t)
	end
	if t < 0.5 then
		return inF(t * 2) / 2
	end
	return 1 - inF((1 - t) * 2) / 2
end

local function lerpValue(a, b, t: number)
	local ty = typeof(a)
	if ty == "number" then
		return a + (b - a) * t
	elseif ty == "boolean" then
		return if t >= 1 then b else a
	elseif ty == "UDim2" or ty == "Vector2" or ty == "Color3" then
		return a:Lerp(b, t)
	elseif ty == "UDim" then
		return udim(a._s + (b._s - a._s) * t, a._o + (b._o - a._o) * t)
	end
	return if t >= 1 then b else a
end

local function finishTween(tw, state)
	local i = table.find(tweens, tw)
	if i then
		table.remove(tweens, i)
	end
	local st = S[tw]
	st.props.PlaybackState = state
	fire(eventOf(st, "Completed"), state)
end

local function stepTweens()
	for _, tw in table.clone(tweens) do
		local st = S[tw]
		local info = st.tweenInfo
		local target = st.target
		local elapsed = F.now - st.startedAt - info.DelayTime
		if elapsed >= 0 then
			local dur = math.max(info.Time, 1e-6)
			local cycle = if info.Reverses then dur * 2 else dur
			local count = info.RepeatCount
			local done = count >= 0 and elapsed >= cycle * (count + 1)
			local t
			if done then
				t = if info.Reverses then 0 else 1
			else
				local into = elapsed % cycle
				t = if into <= dur then into / dur else 1 - (into - dur) / dur
			end
			local a = ease(info.EasingStyle, info.EasingDirection, math.clamp(t, 0, 1))
			for prop, goal in st.goals do
				local from = st.from[prop]
				local ok, err = pcall(function()
					target[prop] = lerpValue(from, goal, a)
				end)
				if not ok then
					report("error", "tween of " .. prop .. " failed: " .. tostring(err))
					st.goals[prop] = nil
				end
			end
			if done then
				finishTween(tw, Enum.PlaybackState.Completed)
			end
		end
	end
end

METHODS.TweenBase = {
	Play = function(self)
		local st = S[self]
		if table.find(tweens, self) then
			return
		end
		-- a newer tween takes over the properties it shares with older ones
		for _, other in table.clone(tweens) do
			local ost = S[other]
			if ost.target == st.target then
				for prop in st.goals do
					ost.goals[prop] = nil
				end
				if next(ost.goals) == nil then
					finishTween(other, Enum.PlaybackState.Cancelled)
				end
			end
		end
		st.from = {}
		for prop in st.goals do
			st.from[prop] = st.target[prop]
		end
		st.startedAt = F.now
		st.props.PlaybackState = Enum.PlaybackState.Playing
		table.insert(tweens, self)
	end,
	Cancel = function(self)
		if table.find(tweens, self) then
			finishTween(self, Enum.PlaybackState.Cancelled)
		end
	end,
	Pause = function(self)
		local i = table.find(tweens, self)
		if i then
			table.remove(tweens, i)
			S[self].props.PlaybackState = Enum.PlaybackState.Paused
		end
	end,
}

---------------------------------------------------------------------------
-- remote / storage serialisation rules
---------------------------------------------------------------------------

local function isArray(t): (boolean, number)
	local n = 0
	for k in t do
		if type(k) ~= "number" or k % 1 ~= 0 or k < 1 then
			return false, 0
		end
		n = math.max(n, k)
	end
	for i = 1, n do
		if t[i] == nil then
			return false, n
		end
	end
	return true, n
end

-- Copies a remote argument the way Roblox does, reporting what Roblox would change.
local function remoteCopy(v, path: string, seen)
	local ty = type(v)
	if ty == "function" then
		issue("remote: a function at " .. path .. " arrives as nil")
		return nil
	elseif ty ~= "table" then
		return v
	end
	if S[v] or getmetatable(v) ~= nil and rawget(getmetatable(v), "__type") then
		return v -- Instances and datatypes pass through
	end
	seen = seen or {}
	if seen[v] then
		issue("remote: a cyclic table at " .. path)
		return nil
	end
	seen[v] = true
	local arr, n = isArray(v)
	local out = {}
	if arr then
		for i = 1, n do
			out[i] = remoteCopy(v[i], path .. "[" .. i .. "]", seen)
		end
	else
		local hasNum, hasStr = false, false
		for k in v do
			if type(k) == "string" then
				hasStr = true
			else
				hasNum = true
			end
		end
		if hasNum and hasStr then
			issue("remote: mixed table (number and string keys) at " .. path)
		elseif hasNum then
			issue("remote: sparse/non-sequential number keys at " .. path .. " (Roblox turns them into strings)")
		end
		for k, x in v do
			local key = if type(k) == "string" then k else tostring(k)
			out[key] = remoteCopy(x, path .. "." .. key, seen)
		end
	end
	seen[v] = nil
	return out
end
F.remoteCopy = remoteCopy

local function storable(v, path: string, seen)
	local ty = type(v)
	if ty == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			issue("store: NaN or infinity at " .. path)
		end
		return
	elseif ty == "string" or ty == "boolean" or v == nil then
		return
	elseif ty ~= "table" or getmetatable(v) ~= nil then
		issue("store: can't save a " .. typeof(v) .. " at " .. path)
		return
	end
	seen = seen or {}
	if seen[v] then
		issue("store: cyclic table at " .. path)
		return
	end
	seen[v] = true
	local arr = isArray(v)
	local hasNum = false
	for k, x in v do
		if type(k) ~= "string" then
			hasNum = true
		end
		storable(x, path .. "." .. tostring(k), seen)
	end
	if hasNum and not arr then
		issue("store: table with non-string keys that isn't an array at " .. path)
	end
	seen[v] = nil
end

local function deepCopy(v)
	if type(v) ~= "table" or getmetatable(v) ~= nil then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

---------------------------------------------------------------------------
-- JSON (HttpService)
---------------------------------------------------------------------------

local function jsonEncode(v, out)
	local ty = type(v)
	if v == nil then
		table.insert(out, "null")
	elseif ty == "boolean" then
		table.insert(out, tostring(v))
	elseif ty == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			error("JSONEncode: can't encode NaN or infinity", 0)
		end
		table.insert(out, if v % 1 == 0 and math.abs(v) < 1e15 then string.format("%d", v) else string.format("%.17g", v))
	elseif ty == "string" then
		table.insert(out, '"' .. v:gsub('[%c"\\]', function(c)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
			return map[c] or string.format("\\u%04x", c:byte())
		end) .. '"')
	elseif ty == "table" then
		local arr, n = isArray(v)
		if arr and (n > 0 or next(v) == nil) then
			table.insert(out, "[")
			for i = 1, n do
				if i > 1 then
					table.insert(out, ",")
				end
				jsonEncode(v[i], out)
			end
			table.insert(out, "]")
		else
			table.insert(out, "{")
			local first = true
			for k, x in v do
				if type(k) ~= "string" then
					error("Cannot convert mixed or non-array tables: keys must be strings", 0)
				end
				if not first then
					table.insert(out, ",")
				end
				first = false
				jsonEncode(k, out)
				table.insert(out, ":")
				jsonEncode(x, out)
			end
			table.insert(out, "}")
		end
	else
		error("JSONEncode: can't encode a " .. ty, 0)
	end
end

local function jsonDecode(s: string)
	local i = 1
	local function ws()
		i = s:find("[^ \t\r\n]", i) or (#s + 1)
	end
	local value
	local function str()
		local out = {}
		i += 1
		while true do
			local c = s:sub(i, i)
			if c == "" then
				error("JSONDecode: unterminated string", 0)
			elseif c == '"' then
				i += 1
				return table.concat(out)
			elseif c == "\\" then
				local e = s:sub(i + 1, i + 1)
				local map = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if e == "u" then
					table.insert(out, utf8.char(tonumber(s:sub(i + 2, i + 5), 16)))
					i += 6
				else
					table.insert(out, map[e] or e)
					i += 2
				end
			else
				table.insert(out, c)
				i += 1
			end
		end
	end
	value = function()
		ws()
		local c = s:sub(i, i)
		if c == "{" then
			local t = {}
			i += 1
			ws()
			if s:sub(i, i) == "}" then
				i += 1
				return t
			end
			while true do
				ws()
				local k = str()
				ws()
				i += 1 -- :
				t[k] = value()
				ws()
				local d = s:sub(i, i)
				i += 1
				if d == "}" then
					return t
				end
			end
		elseif c == "[" then
			local t = {}
			i += 1
			ws()
			if s:sub(i, i) == "]" then
				i += 1
				return t
			end
			while true do
				table.insert(t, value())
				ws()
				local d = s:sub(i, i)
				i += 1
				if d == "]" then
					return t
				end
			end
		elseif c == '"' then
			return str()
		elseif s:sub(i, i + 3) == "true" then
			i += 4
			return true
		elseif s:sub(i, i + 4) == "false" then
			i += 5
			return false
		elseif s:sub(i, i + 3) == "null" then
			i += 4
			return nil
		end
		local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
		if not num or num == "" then
			error("JSONDecode: unexpected character at " .. i, 0)
		end
		i += #num
		return tonumber(num)
	end
	return value()
end

---------------------------------------------------------------------------
-- the DataModel and services
---------------------------------------------------------------------------

local services = {}
game = newInstance("DataModel", { Name = "Game" })
S[game].props.PlaceId = 0
local gameExtras = {
	PlaceId = 1234567,
	GameId = 7654321,
	JobId = "fake-job-1",
	PrivateServerId = "",
	PrivateServerOwnerId = 0,
	CreatorId = 1,
	PlaceVersion = 1,
}
for k, v in gameExtras do
	if classInfo("DataModel").props[k] then
		S[game].props[k] = v
	end
end
F.closeHandlers = {}

local function service(name: string)
	local s = services[name]
	if s then
		return s
	end
	if not FAKE_CLASSES[name] then
		error("fake runtime: service " .. name .. " isn't faked", 3)
	end
	SERVICE_CLASSES[name] = true
	s = newInstance(name, { Name = name })
	services[name] = s
	setParent(s, S[s], game)
	local hook = F.onService[name]
	if hook then
		hook(s, S[s])
	end
	return s
end
F.onService = {}

METHODS.ServiceProvider = {
	GetService = function(_self, name)
		return service(name)
	end,
	FindService = function(_self, name)
		return services[name]
	end,
}
METHODS.DataModel = {
	IsLoaded = function()
		return true
	end,
	BindToClose = function(_self, fn)
		table.insert(F.closeHandlers, fn)
	end,
	GetJobsInfo = function()
		return {}
	end,
}

-- Workspace
workspace = nil
F.onService.Workspace = function(ws, st)
	local cam = newInstance("Camera", { Name = "Camera" })
	setParent(cam, S[cam], ws)
	st.props.CurrentCamera = cam
end
METHODS.Workspace = {
	GetServerTimeNow = function()
		return F.epoch + F.now
	end,
	GetRealPhysicsFPS = function()
		return 60
	end,
}
workspace = service("Workspace")
Workspace = workspace

-- RunService
local RunServiceInst = service("RunService")
do
	local st = S[RunServiceInst]
	st.signals = {
		RenderStepped = newSignal("RenderStepped", true),
		Heartbeat = newSignal("Heartbeat", true),
		Stepped = newSignal("Stepped", true),
		PreRender = newSignal("PreRender", true),
		PreSimulation = newSignal("PreSimulation", true),
		PostSimulation = newSignal("PostSimulation", true),
		PreAnimation = newSignal("PreAnimation", true),
	}
end
local renderBindings = {}
METHODS.RunService = {
	IsStudio = function()
		return true
	end,
	IsClient = function()
		return true
	end,
	IsServer = function()
		return true
	end,
	IsRunning = function()
		return true
	end,
	IsRunMode = function()
		return false
	end,
	IsEdit = function()
		return false
	end,
	BindToRenderStep = function(_self, name, priority, fn)
		renderBindings[name] = { priority = priority, fn = fn }
	end,
	UnbindFromRenderStep = function(_self, name)
		renderBindings[name] = nil
	end,
}

-- Players
local PlayersInst = service("Players")
F.players = {}
METHODS.Players = {
	GetPlayers = function()
		return table.clone(F.players)
	end,
	GetPlayerByUserId = function(_self, id)
		for _, p in F.players do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
	GetUserThumbnailAsync = function(_self, userId, kind, size)
		return string.format("rbxthumb://type=%s&id=%d&w=150&h=150", tostring(kind), userId), true
	end,
	GetNameFromUserIdAsync = function(_self, id)
		return "User" .. tostring(id)
	end,
	GetUserIdFromNameAsync = function()
		return 1
	end,
	GetFriendsAsync = function()
		error("fake runtime: Players:GetFriendsAsync isn't faked", 2)
	end,
}
METHODS.Player = {
	Kick = function(self, msg)
		table.insert(F.logs, "kicked " .. tostring(self) .. ": " .. tostring(msg))
		F.kicked = msg or true
	end,
	GetJoinData = function()
		return { LaunchData = "", Members = {} }
	end,
	IsFriendsWithAsync = function()
		return false
	end,
	IsFriendsWith = function()
		return false
	end,
	GetRankInGroupAsync = function()
		return 0
	end,
	GetRankInGroup = function()
		return 0
	end,
	IsInGroupAsync = function()
		return false
	end,
	GetMouse = function()
		error("fake runtime: Player:GetMouse isn't faked", 2)
	end,
}

-- Adds a player to the game: returns the Player (fires PlayerAdded).
function F.addPlayer(name: string, userId: number)
	local p = newInstance("Player", { Name = name })
	local st = S[p]
	st.props.DisplayName = name
	st.props.UserId = userId
	st.props.AccountAge = 400
	st.props.LocaleId = "en-us"
	st.props.MembershipType = Enum.MembershipType.None
	local gui = newInstance("PlayerGui", { Name = "PlayerGui" })
	setParent(gui, S[gui], p)
	local scripts = newInstance("PlayerScripts", { Name = "PlayerScripts" })
	setParent(scripts, S[scripts], p)
	local pack = newInstance("Backpack", { Name = "Backpack" })
	setParent(pack, S[pack], p)
	setParent(p, st, PlayersInst)
	table.insert(F.players, p)
	if not S[PlayersInst].props.LocalPlayer then
		S[PlayersInst].props.LocalPlayer = p
	end
	fireEvent(S[PlayersInst], "PlayerAdded", p)
	return p
end

-- A player who left comes back on the same server (a dropped connection).
function F.reconnect(p)
	setParent(p, S[p], PlayersInst)
	if not table.find(F.players, p) then
		table.insert(F.players, p)
	end
	fireEvent(S[PlayersInst], "PlayerAdded", p)
end

function F.removePlayer(p)
	local i = table.find(F.players, p)
	if i then
		table.remove(F.players, i)
	end
	fireEvent(S[PlayersInst], "PlayerRemoving", p)
	task.defer(function()
		setParent(p, S[p], nil)
	end)
end

-- UserInputService
local UIS = service("UserInputService")
F.mouse = Vector2.new(640, 360)
local keysDown = {}
METHODS.UserInputService = {
	GetMouseLocation = function()
		return F.mouse
	end,
	GetLastInputType = function()
		return if F.screen.touch then Enum.UserInputType.Touch else Enum.UserInputType.MouseMovement
	end,
	IsKeyDown = function(_self, key)
		return keysDown[key] == true
	end,
	IsMouseButtonPressed = function()
		return false
	end,
	GetFocusedTextBox = function()
		return nil
	end,
	GetKeysPressed = function()
		return {}
	end,
	GetMouseButtonsPressed = function()
		return {}
	end,
	GetNavigationGamepads = function()
		return {}
	end,
	GetConnectedGamepads = function()
		return {}
	end,
	GetStringForKeyCode = function(_self, key)
		return key.Name
	end,
	GetImageForKeyCode = function()
		return ""
	end,
}
local function applyInputKind()
	local st = S[UIS]
	local touch = F.screen.touch
	st.props.TouchEnabled = touch
	st.props.MouseEnabled = not touch
	st.props.KeyboardEnabled = not touch
	st.props.GamepadEnabled = false
	st.props.AccelerometerEnabled = touch
	st.props.MouseIconEnabled = true
end
applyInputKind()

-- GuiService
local GuiServiceInst = service("GuiService")
METHODS.GuiService = {
	GetGuiInset = function()
		return v2(0, F.screen.inset), v2(0, 0)
	end,
	IsTenFootInterface = function()
		return false
	end,
	GetEmotesMenuOpen = function()
		return false
	end,
	SetEmotesMenuOpen = function() end,
	GetInspectMenuEnabled = function()
		return false
	end,
	SetInspectMenuEnabled = function() end,
	CloseInspectMenu = function() end,
}
local function applyTopbar()
	local scr = F.screen
	S[GuiServiceInst].props.TopbarInset = Rect.new(scr.barLeft or 120, 0, scr.barRight or (scr.w - 60), scr.inset)
end
applyTopbar()

-- StarterGui
service("StarterGui")
F.coreGui = {}
METHODS.StarterGui = {
	SetCoreGuiEnabled = function(_self, kind, on)
		F.coreGui[tostring(kind)] = on
	end,
	GetCoreGuiEnabled = function(_self, kind)
		return F.coreGui[tostring(kind)] ~= false
	end,
	SetCore = function(_self, name, value)
		F.coreGui["core:" .. tostring(name)] = value
	end,
	GetCore = function(_self, name)
		return F.coreGui["core:" .. tostring(name)]
	end,
}

-- TweenService
service("TweenService")
METHODS.TweenService = {
	Create = function(_self, target, info, goals)
		if not S[target] then
			error("TweenService:Create: argument #1 must be an Instance, got " .. typeof(target), 2)
		end
		if typeof(info) ~= "TweenInfo" then
			error("TweenService:Create: argument #2 must be a TweenInfo, got " .. typeof(info), 2)
		end
		if type(goals) ~= "table" then
			error("TweenService:Create: argument #3 must be a table", 2)
		end
		local tst = S[target]
		local clean = {}
		for prop, goal in goals do
			local ptype = tst.cls.props[prop]
			if not ptype then
				error(string.format("TweenService:Create no property named '%s' for object '%s'", tostring(prop), tostring(target)), 2)
			end
			local want = if ptype:sub(1, 4) == "Enum" then "EnumItem" else ptype
			if not TWEENABLE[want] then
				error(string.format("TweenService:Create property named '%s' on object '%s' is not a data type that can be tweened", prop, tostring(target)), 2)
			end
			if typeof(goal) ~= want then
				error(string.format("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a '%s', but given type is '%s')", prop, want, typeof(goal)), 2)
			end
			clean[prop] = goal
		end
		local tw = newInstance("Tween", { Name = "Tween" })
		local st = S[tw]
		st.target = target
		st.tweenInfo = info
		st.goals = clean
		st.props.PlaybackState = Enum.PlaybackState.Begin
		return tw
	end,
	GetValue = function(_self, alpha, style, dir)
		return ease(style, dir, alpha)
	end,
}

-- sounds
service("SoundService")
local playingSounds = {}
METHODS.Sound = {
	Play = function(self)
		local st = S[self]
		st.props.TimePosition = 0
		st.props.Playing = true
		playingSounds[self] = true
		fireEvent(st, "Played", st.props.SoundId or "")
	end,
	Stop = function(self)
		local st = S[self]
		st.props.Playing = false
		st.props.TimePosition = 0
		playingSounds[self] = nil
		fireEvent(st, "Stopped", st.props.SoundId or "")
	end,
	Pause = function(self)
		local st = S[self]
		st.props.Playing = false
		playingSounds[self] = nil
		fireEvent(st, "Paused", st.props.SoundId or "")
	end,
	Resume = function(self)
		local st = S[self]
		st.props.Playing = true
		playingSounds[self] = true
		fireEvent(st, "Resumed", st.props.SoundId or "")
	end,
}
-- music is long, effects are short
F.soundLength = function(sound)
	local id = tostring(S[sound].props.SoundId or "")
	local n = tonumber(id:match("(%d+)")) or 0
	return if S[sound].props.Looped then 30 + n % 60 else 1 + (n % 7) / 10
end
F.onCreate.Sound = function(inst, st)
	st.onSet = function(s, prop)
		if prop == "SoundId" or prop == "Looped" then
			S[s].timeLength = F.soundLength(s)
		elseif prop == "Playing" then
			playingSounds[s] = if S[s].props.Playing then true else nil
		end
	end
end
local function stepSounds(dt: number)
	for sound in table.clone(playingSounds) do
		local st = S[sound]
		if not st or st.destroyed then
			playingSounds[sound] = nil
		else
			local len = st.timeLength or F.soundLength(sound)
			local pos = (st.props.TimePosition or 0) + dt * (st.props.PlaybackSpeed or 1)
			if pos >= len then
				if st.props.Looped then
					pos %= len
					fireEvent(st, "DidLoop", st.props.SoundId or "", 1)
				else
					st.props.Playing = false
					playingSounds[sound] = nil
					pos = 0
					fireEvent(st, "Ended", st.props.SoundId or "")
				end
			end
			st.props.TimePosition = pos
		end
	end
end

-- misc client services
service("ContentProvider")
-- content ids that won't load (F.failAssets[id] = true), like an image a game may not use
F.failAssets = {}
METHODS.ContentProvider = {
	PreloadAsync = function(_self, list, callback)
		if callback then
			for _, item in list do
				local id = tostring(item)
				callback(id, if F.failAssets[id] then Enum.AssetFetchStatus.Failure else Enum.AssetFetchStatus.Success)
			end
		end
	end,
}
service("TextService")
METHODS.TextService = {
	-- measured with the real fonts' widths (tests/fake/fonts.luau), wrapping words at
	-- frame.X like Roblox does
	GetTextSize = function(_self, text, size, font, frame)
		local fam = FAKE_FONTS and font and FAKE_FONTS[font._name]
		local m = fam and (fam.Regular or select(2, next(fam)))
		local maxW = if frame and frame.X > 0 then frame.X else math.huge
		local space = wordWidth(m, " ", size)
		local lines, widest = 0, 0
		for line in (tostring(text) .. "\n"):gmatch("(.-)\n") do
			lines += 1
			local x = 0
			for word in line:gmatch("%S+") do
				local ww = wordWidth(m, word, size)
				if x > 0 and x + space + ww > maxW then
					widest = math.max(widest, x)
					lines += 1
					x = ww
				else
					x += (if x > 0 then space else 0) + ww
				end
			end
			widest = math.max(widest, x)
		end
		return v2(widest, math.max(1, lines) * size * (if m then m.line else 1))
	end,
}
-- typed chat goes through the filter (the fake lets everything through)
METHODS.TextService.FilterStringAsync = function(_self, text, _fromUserId, _context)
	local r = newInstance("TextFilterResult", { Name = "TextFilterResult" })
	S[r].text = text
	return r
end
METHODS.TextFilterResult = {
	GetChatForUserAsync = function(self)
		return S[self].text
	end,
	GetNonChatStringForBroadcastAsync = function(self)
		return S[self].text
	end,
	GetNonChatStringForUserAsync = function(self)
		return S[self].text
	end,
}
service("TextChatService")
METHODS.TextChatService = {
	CanUserChatAsync = function()
		return true
	end,
	CanUsersChatAsync = function()
		return true
	end,
}
-- one server: what's published comes straight back to its subscribers
service("MessagingService")
F.subscriptions = {}
METHODS.MessagingService = {
	PublishAsync = function(_self, topic, message)
		for _, fn in F.subscriptions[topic] or {} do
			task.spawn(fn, { Data = message, Sent = os.time() })
		end
	end,
	SubscribeAsync = function(_self, topic, fn)
		-- F.messagingHangs: never answers, like Studio can in a place that isn't published
		while F.messagingHangs do
			task.wait(3600)
		end
		F.subscriptions[topic] = F.subscriptions[topic] or {}
		table.insert(F.subscriptions[topic], fn)
		return { Disconnect = function() end }
	end,
}
-- text-to-speech never loads offline, so the chat voices babble instead
METHODS.AudioTextToSpeech = {
	LoadAsync = function()
		return Enum.AssetFetchStatus.Failure
	end,
	Play = function() end,
	Pause = function() end,
	Unload = function() end,
}
service("SocialService")
F.invites = 0
METHODS.SocialService = {
	CanSendGameInviteAsync = function()
		return true
	end,
	PromptGameInvite = function()
		F.invites += 1
	end,
	CanSendCallInviteAsync = function()
		return false
	end,
}
service("MarketplaceService")
F.prompts = {}
-- assets the fake Roblox knows by id: F.assetInfo[id] = { Name, AssetTypeId (1 image,
-- 13 decal), Image = a decal's image id }
F.assetInfo = {}
METHODS.MarketplaceService = {
	UserOwnsGamePassAsync = function()
		return false
	end,
	PromptGamePassPurchase = function(_self, _player, id)
		table.insert(F.prompts, id)
	end,
	PromptProductPurchase = function(_self, _player, id)
		table.insert(F.prompts, id)
	end,
	GetProductInfo = function(_self, id)
		local asset = F.assetInfo[id]
		if asset then
			return { Name = asset.Name, AssetTypeId = asset.AssetTypeId, Description = "" }
		end
		return { Name = "Pass " .. tostring(id), PriceInRobux = 99, IconImageAssetId = 0, Description = "" }
	end,
}
service("InsertService")
METHODS.InsertService = {
	-- a decal comes as a Model holding the Decal, its Texture the image's address
	LoadAsset = function(_self, id)
		local asset = F.assetInfo[id]
		if not asset or asset.AssetTypeId ~= 13 then
			error("HTTP 403 (Forbidden)", 2)
		end
		local model = Instance.new("Model")
		local decal = Instance.new("Decal")
		decal.Texture = "http://www.roblox.com/asset/?id=" .. tostring(asset.Image)
		decal.Parent = model
		return model
	end,
}
service("HttpService")
local guids = 0
METHODS.HttpService = {
	GenerateGUID = function(_self, braces)
		guids += 1
		local s = string.format("%08x-0000-4000-8000-%012x", guids, guids * 7919)
		if braces == false then
			return s
		end
		return "{" .. s .. "}"
	end,
	JSONEncode = function(_self, v)
		local out = {}
		jsonEncode(v, out)
		return table.concat(out)
	end,
	JSONDecode = function(_self, s)
		return jsonDecode(s)
	end,
	UrlEncode = function(_self, s)
		return (tostring(s):gsub("[^%w%-_%.~]", function(c)
			return string.format("%%%02X", c:byte())
		end))
	end,
}
service("PolicyService")
METHODS.PolicyService = {
	GetPolicyInfoForPlayerAsync = function()
		return {
			ArePaidRandomItemsRestricted = false,
			AllowedExternalLinkReferences = {},
			IsPaidItemTradingAllowed = true,
			IsSubjectToChinaPolicies = false,
			IsContentSharingAllowed = true,
			AreAdsAllowed = true,
		}
	end,
}
service("UserService")
METHODS.UserService = {
	GetUserInfosByUserIdsAsync = function(_self, ids)
		local out = {}
		for _, id in ids do
			table.insert(out, { Id = id, Username = "User" .. id, DisplayName = "User" .. id, HasVerifiedBadge = false })
		end
		return out
	end,
}
service("TeleportService")
METHODS.TeleportService = {
	ReserveServer = function()
		error("fake runtime: teleports don't work in Studio (and so not here)", 2)
	end,
	TeleportAsync = function()
		error("fake runtime: teleports don't work in Studio (and so not here)", 2)
	end,
	GetLocalPlayerTeleportData = function()
		return nil
	end,
}
service("Debris")
METHODS.Debris = {
	AddItem = function(_self, inst, t)
		task.delay(t or 10, function()
			if S[inst] and not S[inst].destroyed then
				destroy(inst)
			end
		end)
	end,
}

-- DataStores ----------------------------------------------------------------------
service("DataStoreService")
F.stores = {}
F.dataStoreFails = false
local function storeFor(kind: string, name: string, scope: string?)
	local key = kind .. ":" .. name .. ":" .. (scope or "global")
	local s = F.stores[key]
	if not s then
		s = newInstance(if kind == "ordered" then "OrderedDataStore" else "DataStore", { Name = name })
		S[s].data = {}
		F.stores[key] = s
	end
	return s
end
local function storeGate()
	if F.dataStoreFails then
		error("502: API Services rejected request (fake: Studio access to API services is off)", 3)
	end
	task.wait(0.05)
end
METHODS.DataStoreService = {
	GetDataStore = function(_self, name, scope)
		return storeFor("plain", name, scope)
	end,
	GetOrderedDataStore = function(_self, name, scope)
		return storeFor("ordered", name, scope)
	end,
	GetRequestBudgetForRequestType = function()
		return 100
	end,
}
local function checkKey(key)
	if type(key) ~= "string" or #key == 0 or #key > 50 then
		error("DataStore key must be a 1-50 character string, got " .. tostring(key), 3)
	end
end
METHODS.GlobalDataStore = {
	GetAsync = function(self, key)
		storeGate()
		checkKey(key)
		return deepCopy(S[self].data[key]), nil
	end,
	SetAsync = function(self, key, value)
		storeGate()
		checkKey(key)
		storable(value, tostring(self) .. "/" .. key)
		S[self].data[key] = deepCopy(value)
		return "v1"
	end,
	UpdateAsync = function(self, key, fn)
		storeGate()
		checkKey(key)
		local new = fn(deepCopy(S[self].data[key]), nil)
		if new ~= nil then
			storable(new, tostring(self) .. "/" .. key)
			S[self].data[key] = deepCopy(new)
		end
		return deepCopy(new), nil
	end,
	RemoveAsync = function(self, key)
		storeGate()
		local old = S[self].data[key]
		S[self].data[key] = nil
		return old
	end,
	IncrementAsync = function(self, key, delta)
		storeGate()
		local v = (S[self].data[key] or 0) + (delta or 1)
		S[self].data[key] = v
		return v
	end,
}
METHODS.OrderedDataStore = {
	SetAsync = function(self, key, value)
		storeGate()
		if type(value) ~= "number" or value % 1 ~= 0 then
			error("OrderedDataStore values must be integers, got " .. tostring(value), 2)
		end
		S[self].data[key] = value
		return "v1"
	end,
	GetSortedAsync = function(self, ascending, pageSize)
		storeGate()
		local list = {}
		for k, v in S[self].data do
			table.insert(list, { key = k, value = v })
		end
		table.sort(list, function(a, b)
			if ascending then
				return a.value < b.value
			end
			return a.value > b.value
		end)
		local page = {}
		for i = 1, math.min(pageSize, #list) do
			page[i] = list[i]
		end
		local pages = newInstance("DataStorePages", { Name = "Pages" })
		S[pages].page = page
		S[pages].props.IsFinished = #list <= pageSize
		return pages
	end,
}
METHODS.Pages = {
	GetCurrentPage = function(self)
		return S[self].page
	end,
	AdvanceToNextPageAsync = function(self)
		S[self].page = {}
		S[self].props.IsFinished = true
	end,
}

-- MemoryStores ----------------------------------------------------------------------
service("MemoryStoreService")
F.memory = {}
METHODS.MemoryStoreService = {
	GetSortedMap = function(_self, name)
		local m = F.memory[name]
		if not m then
			m = newInstance("MemoryStoreSortedMap", { Name = name })
			S[m].data = {}
			F.memory[name] = m
		end
		return m
	end,
}
local function memLive(m)
	local out = {}
	for k, e in S[m].data do
		if e.exp > F.now then
			out[k] = e
		else
			S[m].data[k] = nil
		end
	end
	return out
end
METHODS.MemoryStoreSortedMap = {
	GetAsync = function(self, key)
		task.wait(0.02)
		local e = memLive(self)[key]
		return if e then deepCopy(e.value) else nil, if e then e.sortKey else nil
	end,
	SetAsync = function(self, key, value, ttl, sortKey)
		task.wait(0.02)
		storable(value, "memory " .. tostring(self) .. "/" .. key)
		S[self].data[key] = { value = deepCopy(value), exp = F.now + (ttl or 60), sortKey = sortKey }
		return true
	end,
	UpdateAsync = function(self, key, fn, ttl)
		task.wait(0.02)
		local e = memLive(self)[key]
		local new, sortKey = fn(if e then deepCopy(e.value) else nil, if e then e.sortKey else nil)
		if new ~= nil then
			storable(new, "memory " .. tostring(self) .. "/" .. key)
			S[self].data[key] = { value = deepCopy(new), exp = F.now + (ttl or 60), sortKey = sortKey }
		end
		return deepCopy(new)
	end,
	RemoveAsync = function(self, key)
		task.wait(0.02)
		S[self].data[key] = nil
	end,
	GetRangeAsync = function(self, direction, count)
		task.wait(0.02)
		local list = {}
		for k, e in memLive(self) do
			table.insert(list, { key = k, value = deepCopy(e.value), sortKey = e.sortKey })
		end
		table.sort(list, function(a, b)
			if direction == Enum.SortDirection.Descending then
				return a.key > b.key
			end
			return a.key < b.key
		end)
		local out = {}
		for i = 1, math.min(count, #list) do
			out[i] = list[i]
		end
		return out
	end,
}

-- containers
local ReplicatedStorageInst = service("ReplicatedStorage")
service("ReplicatedFirst")
service("ServerScriptService")
service("ServerStorage")
service("StarterPlayer")
service("Lighting")
METHODS.ReplicatedFirst = {
	RemoveDefaultLoadingScreen = function()
		F.defaultLoadingRemoved = true
	end,
	SetDefaultLoadingGuiRemoved = function() end,
	IsFinishedReplicating = function()
		return true
	end,
	IsDefaultLoadingGuiRemoved = function()
		return F.defaultLoadingRemoved == true
	end,
}

-- Mounts a bundle node (a fake module folder) as a child of an instance.
function F.mount(inst, name: string, node)
	local st = S[inst]
	st.virtual = st.virtual or {}
	st.virtual[name] = node
end
F.ReplicatedStorage = ReplicatedStorageInst

---------------------------------------------------------------------------
-- remotes
---------------------------------------------------------------------------

F.latency = 0.05
local function copyArgs(path: string, ...)
	local out = table.pack(...)
	for i = 1, out.n do
		out[i] = remoteCopy(out[i], path .. " arg" .. i)
	end
	return out
end

METHODS.RemoteEvent = {
	FireClient = function(self, player, ...)
		if not S[player] or S[player].cls.name ~= "Player" then
			error("FireClient: argument #1 must be a Player", 2)
		end
		local args = copyArgs(tostring(self) .. ":FireClient", ...)
		local st = S[self]
		task.delay(F.latency, function()
			if table.find(F.players, player) then
				fireEvent(st, "OnClientEvent", table.unpack(args, 1, args.n))
			end
		end)
	end,
	FireAllClients = function(self, ...)
		for _, p in F.players do
			METHODS.RemoteEvent.FireClient(self, p, ...)
		end
	end,
	FireServer = function(self, ...)
		local args = copyArgs(tostring(self) .. ":FireServer", ...)
		local st = S[self]
		local player = F.players[1]
		task.delay(F.latency, function()
			fireEvent(st, "OnServerEvent", player, table.unpack(args, 1, args.n))
		end)
	end,
}
METHODS.UnreliableRemoteEvent = METHODS.RemoteEvent

METHODS.BindableEvent = {
	Fire = function(self, ...)
		local args = copyArgs(tostring(self) .. ":Fire", ...)
		fireEvent(S[self], "Event", table.unpack(args, 1, args.n))
	end,
}
METHODS.BindableFunction = {
	Invoke = function(self, ...)
		local fn = S[self].props.OnInvoke
		if not fn then
			error("BindableFunction:Invoke: OnInvoke isn't set", 2)
		end
		return fn(...)
	end,
}

local SERVER_ERROR = {}
METHODS.RemoteFunction = {
	InvokeServer = function(self, ...)
		local co = coroutine.running()
		if not coroutine.isyieldable() then
			error("InvokeServer must be called from a thread that can yield", 2)
		end
		local st = S[self]
		local args = copyArgs(tostring(self) .. ":InvokeServer", ...)
		local player = F.players[1]
		task.delay(F.latency, function()
			local fn = st.props.OnServerInvoke
			while not fn do
				task.wait()
				fn = st.props.OnServerInvoke
			end
			local results = table.pack(pcall(fn, player, table.unpack(args, 1, args.n)))
			task.delay(F.latency, function()
				if results[1] then
					local copied = copyArgs(tostring(self) .. " reply", table.unpack(results, 2, results.n))
					resume(co, table.unpack(copied, 1, copied.n))
				else
					resume(co, SERVER_ERROR, results[2])
				end
			end)
		end)
		local first, second = coroutine.yield()
		if first == SERVER_ERROR then
			error(second, 2)
		end
		return first, second
	end,
}

---------------------------------------------------------------------------
-- frames
---------------------------------------------------------------------------

F.onFrame = {}

function F.step(dt: number?)
	dt = dt or F.frameDt
	F.frame += 1
	F.now += dt
	local rs = S[RunServiceInst].signals
	fire(rs.PreRender, dt)
	local binds = {}
	for _, b in renderBindings do
		table.insert(binds, b)
	end
	table.sort(binds, function(a, b)
		return a.priority < b.priority
	end)
	for _, b in binds do
		task.spawn(b.fn, dt)
	end
	fire(rs.RenderStepped, dt)
	stepTweens()
	fire(rs.Stepped, F.now, dt)
	fire(rs.Heartbeat, dt)
	stepSounds(dt)
	-- threads that are due, in the order they asked
	local due = {}
	for i = #waiting, 1, -1 do
		local w = waiting[i]
		if w.wake <= F.now + 1e-9 then
			table.insert(due, w)
			table.remove(waiting, i)
		end
	end
	table.sort(due, function(a, b)
		if a.wake ~= b.wake then
			return a.wake < b.wake
		end
		return a.seq < b.seq
	end)
	for _, w in due do
		if w.args then
			resume(w.co, table.unpack(w.args, 1, w.args.n))
		else
			resume(w.co, F.now - w.start)
		end
	end
	flushDeferred()
	checkWatched()
	flushDeferred()
	for _, fn in table.clone(F.onFrame) do
		fn(dt)
	end
	flushDeferred()
end

-- Runs frames for `seconds` of game time, or until `untilFn()` is true. Returns
-- whether `untilFn` became true.
function F.run(seconds: number, untilFn: (() -> boolean)?): boolean
	local stop = F.now + seconds
	while F.now < stop do
		F.step()
		if untilFn and untilFn() then
			return true
		end
	end
	return untilFn == nil
end

-- Runs a function in a new thread (so it may yield), then flushes deferred work.
function F.spawn(fn, ...)
	local co = task.spawn(fn, ...)
	flushDeferred()
	return co
end

---------------------------------------------------------------------------
-- the screen and input
---------------------------------------------------------------------------

function F.setScreen(o)
	local scr = F.screen
	scr.w = o.w or scr.w
	scr.h = o.h or scr.h
	scr.safe = o.safe or { l = 0, t = 0, r = 0, b = 0 }
	scr.inset = o.inset or 58
	scr.barLeft = o.barLeft
	scr.barRight = o.barRight
	scr.touch = o.touch == true
	F.screenVersion += 1
	layoutVersion += 1
	applyInputKind()
	applyTopbar()
	local cam = S[workspace].props.CurrentCamera
	if cam then
		local ps = S[cam].propSignals and S[cam].propSignals.ViewportSize
		if ps then
			fire(ps)
		end
	end
	local ts = S[GuiServiceInst].propSignals and S[GuiServiceInst].propSignals.TopbarInset
	if ts then
		fire(ts)
	end
	fireEvent(S[UIS], "LastInputTypeChanged", METHODS.UserInputService.GetLastInputType())
end

local function inputObject(kind, keyCode, state, pos: Vector2?)
	local input = newInstance("InputObject", { Name = "InputObject" })
	local st = S[input]
	st.props.UserInputType = kind
	st.props.KeyCode = keyCode or Enum.KeyCode.Unknown
	st.props.UserInputState = state
	local p = pos or F.mouse
	st.props.Position = v3(p.X, p.Y - F.screen.inset, 0)
	st.props.Delta = v3(0, 0, 0)
	return input
end
F.inputObject = inputObject

function F.key(keyCode, processed: boolean?)
	keysDown[keyCode] = true
	local began = inputObject(Enum.UserInputType.Keyboard, keyCode, Enum.UserInputState.Begin)
	fireEvent(S[UIS], "InputBegan", began, processed == true)
	flushDeferred()
	keysDown[keyCode] = nil
	local ended = inputObject(Enum.UserInputType.Keyboard, keyCode, Enum.UserInputState.End)
	fireEvent(S[UIS], "InputEnded", ended, processed == true)
	flushDeferred()
end

function F.moveMouse(pos: Vector2)
	F.mouse = pos
	local input = inputObject(Enum.UserInputType.MouseMovement, nil, Enum.UserInputState.Change, pos)
	fireEvent(S[UIS], "InputChanged", input, false)
	flushDeferred()
end

-- Is this GUI object on screen (it and every ancestor visible, inside an enabled
-- ScreenGui in a PlayerGui, with some size)?
function F.visible(inst): boolean
	local st = S[inst]
	if not st or st.destroyed then
		return false
	end
	local node = inst
	while node do
		local nst = S[node]
		if nst.cls.isA.GuiObject then
			if not gget(node, "Visible") then
				return false
			end
			if nst.cls.name == "CanvasGroup" and gget(node, "GroupTransparency") > 0.95 then
				return false
			end
		elseif nst.cls.isA.LayerCollector then
			if not gget(node, "Enabled") then
				return false
			end
			if not isUnderPlayerGui(node) then
				return false
			end
			local abs = gget(inst, "AbsoluteSize")
			return abs.X > 0.5 and abs.Y > 0.5
		else
			return false
		end
		node = nst.parent
	end
	return false
end

-- Why F.visible(inst) is false (for debugging a test).
function F.whyHidden(inst): string
	local st = S[inst]
	if not st then
		return "not an instance"
	elseif st.destroyed then
		return "destroyed"
	end
	local node = inst
	while node do
		local nst = S[node]
		if nst.cls.isA.GuiObject then
			if not gget(node, "Visible") then
				return fullName(node) .. " is not Visible"
			end
			if nst.cls.name == "CanvasGroup" and gget(node, "GroupTransparency") > 0.95 then
				return fullName(node) .. " is a faded-out CanvasGroup"
			end
		elseif nst.cls.isA.LayerCollector then
			if not gget(node, "Enabled") then
				return fullName(node) .. " is disabled"
			end
			if not isUnderPlayerGui(node) then
				return fullName(node) .. " isn't in a PlayerGui"
			end
			local abs = gget(inst, "AbsoluteSize")
			if abs.X <= 0.5 or abs.Y <= 0.5 then
				return "zero size " .. tostring(abs)
			end
			return "visible"
		else
			return fullName(node) .. " (" .. nst.cls.name .. ") isn't a GUI object or ScreenGui"
		end
		node = nst.parent
	end
	return "not parented"
end

-- Clicks (or taps) a GUI button the way a player would.
function F.click(button)
	assert(S[button], "click: not an instance")
	local abs = gget(button, "AbsolutePosition") + gget(button, "AbsoluteSize") / 2
	F.mouse = abs
	local touch = F.screen.touch
	local kind = if touch then Enum.UserInputType.Touch else Enum.UserInputType.MouseButton1
	local st = S[button]
	local began = inputObject(kind, nil, Enum.UserInputState.Begin, abs)
	if not touch then
		fireEvent(st, "MouseEnter", abs.X, abs.Y)
	end
	fireEvent(st, "InputBegan", began)
	fireEvent(S[UIS], "InputBegan", began, true)
	if st.cls.isA.GuiButton then
		fireEvent(st, "MouseButton1Down", abs.X, abs.Y)
	end
	flushDeferred()
	-- Roblox keeps one InputObject for a press from start to end
	local ended = began
	S[ended].props.UserInputState = Enum.UserInputState.End
	if st.cls.isA.GuiButton then
		fireEvent(st, "MouseButton1Up", abs.X, abs.Y)
		fireEvent(st, "MouseButton1Click")
		fireEvent(st, "Activated", ended, 1)
	end
	fireEvent(st, "InputEnded", ended)
	fireEvent(S[UIS], "InputEnded", ended, true)
	flushDeferred()
end

function F.hover(inst, on: boolean)
	local st = S[inst]
	local abs = gget(inst, "AbsolutePosition") + gget(inst, "AbsoluteSize") / 2
	if on then
		F.mouse = abs
		fireEvent(st, "MouseEnter", abs.X, abs.Y)
	else
		fireEvent(st, "MouseLeave", abs.X, abs.Y)
	end
	flushDeferred()
end

-- Every descendant of `root` for which pred(inst) is true.
function F.findAll(root, pred)
	local out = {}
	for _, d in descendants(root, {}) do
		if pred(d) then
			table.insert(out, d)
		end
	end
	return out
end

-- The text a button shows (its own Text or its labels').
function F.textOf(inst): string
	local parts = {}
	local own = S[inst].props.Text
	if own and own ~= "" then
		table.insert(parts, own)
	end
	for _, d in descendants(inst, {}) do
		local t = S[d].props.Text
		if t and t ~= "" and S[d].cls.isA.GuiObject then
			table.insert(parts, t)
		end
	end
	return table.concat(parts, " ")
end

-- Visible buttons under `root` whose text matches the Lua pattern.
function F.buttons(root, pattern: string?)
	return F.findAll(root, function(d)
		local st = S[d]
		return st.cls.isA.GuiButton and F.visible(d) and (pattern == nil or F.textOf(d):upper():find(pattern:upper()) ~= nil)
	end)
end

function F.firePlayerGone(p)
	F.removePlayer(p)
end

function F.close()
	for _, fn in F.closeHandlers do
		task.spawn(fn)
	end
	flushDeferred()
end

-- What's still running every frame: connections to RunService's frame events, tweens
-- playing, threads waiting. A screen that's gone should leave none of its own behind.
function F.load()
	local rs = S[RunServiceInst].signals
	local frameConns = 0
	for _, sig in rs do
		frameConns += #sig.conns
	end
	local looping = 0
	for _, tw in tweens do
		if S[tw].tweenInfo.RepeatCount < 0 then
			looping += 1
		end
	end
	return { frameConns = frameConns, tweens = #tweens, looping = looping, waiting = #waiting }
end

-- Number of GUI objects under an instance.
function F.count(root): number
	return #descendants(root, {})
end

-- A summary of what went wrong (empty string when nothing did).
function F.problems(allowWarnings: { string }?): string
	local lines = {}
	for _, e in F.errors do
		table.insert(lines, "ERROR " .. e.message .. (if e.trace then "\n" .. e.trace else ""))
	end
	for _, w in F.warnings do
		local allowed = false
		for _, pat in allowWarnings or {} do
			if w:find(pat) then
				allowed = true
			end
		end
		if not allowed then
			table.insert(lines, "WARN " .. w)
		end
	end
	for _, m in F.issues do
		table.insert(lines, "ISSUE " .. m)
	end
	return table.concat(lines, "\n")
end

-- The scale a GUI object's offsets are drawn at (the UIScales above it, and its own).
function F.scaleOf(inst): number
	local st = S[inst]
	if not st or not st.cls.isA.GuiObject then
		return 1
	end
	local _, _, _, _, s = rectOf(inst)
	return s
end
