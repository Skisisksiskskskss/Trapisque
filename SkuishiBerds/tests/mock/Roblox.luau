--!nocheck
--[[
	Mini Roblox: runs the game's real server script and real client scripts
	together in one Lune process (used by tests/smoke.luau).

	  * Instances are real Lune DOM instances, so property names and value
	    types are checked against Roblox's reflection database. They are
	    wrapped in proxies that add what Lune lacks: events, services, remotes,
	    DataStores, tweens, sounds and layout properties (AbsoluteSize...).
	  * Every "side" (the server, each player's client) has its own module
	    cache and its own proxies, so each client only receives its own remote
	    messages and RunService:IsServer() answers per side, like replication.
	  * Remote arguments follow Roblox's rules strictly: mixed tables, sparse
	    arrays, non-string keys, functions and metatables are reported, and
	    unreliable payloads over 900 bytes are dropped and reported.
	  * DataStores keep JSON rules (no NaN, no mixed tables), UpdateAsync
	    callbacks may not yield, OrderedDataStore values must be integers.
	  * Time is virtual: a deterministic 60 Hz clock drives task.wait/delay,
	    RunService events, os.clock and network latency.

	Problems (errors in any thread, warn() output, rule violations) are
	collected in Mock.problems instead of stopping the run.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local ApiIndex = require("./ApiIndex")

local Enum = roblox.Enum
local Vector2 = roblox.Vector2
local Vector3 = roblox.Vector3

local Mock = {}
Mock.Enum = Enum

-- Lune's enum table lacks KeyCode.Unknown (what touches report on Roblox)
local UNKNOWN_KEY = (function()
	local ok, v = pcall(function()
		return Enum.KeyCode.Unknown
	end)
	return if ok then v else Enum.KeyCode.Pause
end)()
Mock.latencyFrames = 4 -- one-way network delay (4 frames ~ 67 ms)
Mock.isStudio = false
Mock.dataStoresEnabled = true
Mock.UNRELIABLE_LIMIT = 900
Mock.viewport = Vector2.new(390, 844) -- portrait phone
Mock.SERVER_EPOCH = 1_760_000_000
Mock.timeOffset = 0 -- added to os.time() (lets a test skip days)
Mock.verbose = false

local Clock = { now = 0, frame = 0 }
Mock.Clock = Clock

---------------------------------------------------------------------------------------------
-- Problems
---------------------------------------------------------------------------------------------
Mock.problems = {}
local seenProblems = {}
Mock.allowWarnings = {} -- patterns of expected warn() output

local function errText(e)
	local s = tostring(e)
	local inner = string.match(s, "^<?LuaError%(%s*\n([^\n]*)")
	if inner then
		return inner
	end
	return s
end
Mock.errText = errText

local function problem(kind: string, msg: string)
	msg = tostring(msg)
	local key = kind .. ":" .. (string.match(msg, "^[^\n]*") or msg)
	local n = (seenProblems[key] or 0) + 1
	seenProblems[key] = n
	if n == 1 then
		table.insert(Mock.problems, { kind = kind, msg = msg, t = Clock.now })
		print(string.format("  !! [%s @%.2fs] %s", kind, Clock.now, msg))
	end
end
Mock.problem = problem

local function shortTrace(level)
	local tb = debug.traceback("", level or 3)
	local lines = {}
	for line in string.gmatch(tb, "[^\n]+") do
		if not string.find(line, "mock/Roblox", 1, true) and string.find(line, "src/", 1, true) then
			table.insert(lines, "      " .. (string.match(line, "src/.*") or line))
			if #lines >= 4 then
				break
			end
		end
	end
	return table.concat(lines, "\n")
end

---------------------------------------------------------------------------------------------
-- Scheduler (task library on the virtual clock)
---------------------------------------------------------------------------------------------
local timers = {}
local deferred = {}

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		problem("error", debug.traceback(co, errText(err)))
	end
	return ok
end
Mock.resume = resume

local function newThread(f)
	if type(f) == "thread" then
		return f
	end
	return coroutine.create(f)
end

local taskLib = {}
function taskLib.spawn(f, ...)
	local co = newThread(f)
	resume(co, ...)
	return co
end
function taskLib.defer(f, ...)
	local co = newThread(f)
	table.insert(deferred, { co = co, args = table.pack(...) })
	return co
end
function taskLib.delay(t, f, ...)
	local co = newThread(f)
	table.insert(timers, { at = Clock.now + (t or 0), minFrame = Clock.frame + 1, co = co, args = table.pack(...) })
	return co
end
function taskLib.wait(t)
	if not coroutine.isyieldable() then
		error("task.wait called from a non-yieldable context", 2)
	end
	local start = Clock.now
	table.insert(timers, {
		at = Clock.now + (t or 0),
		minFrame = Clock.frame + 1,
		co = coroutine.running(),
		args = { n = 0 },
	})
	coroutine.yield()
	return Clock.now - start
end
function taskLib.cancel(co)
	for i = #timers, 1, -1 do
		if timers[i].co == co then
			table.remove(timers, i)
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
function taskLib.synchronize() end
function taskLib.desynchronize() end
Mock.task = taskLib

local function runTimers()
	local guard = 0
	while true do
		local bestI, bestAt = nil, math.huge
		for i, t in timers do
			if t.at <= Clock.now + 1e-9 and t.minFrame <= Clock.frame and t.at < bestAt then
				bestI, bestAt = i, t.at
			end
		end
		if not bestI then
			break
		end
		local t = table.remove(timers, bestI)
		if coroutine.status(t.co) == "suspended" then
			resume(t.co, table.unpack(t.args, 1, t.args.n))
		end
		guard += 1
		if guard > 50000 then
			problem("scheduler", "more than 50000 timers resumed in one frame")
			break
		end
	end
end

local function runDeferred()
	local guard = 0
	while #deferred > 0 do
		local d = table.remove(deferred, 1)
		if coroutine.status(d.co) == "suspended" then
			resume(d.co, table.unpack(d.args, 1, d.args.n))
		end
		guard += 1
		if guard > 50000 then
			problem("scheduler", "more than 50000 deferred threads in one frame")
			break
		end
	end
end

---------------------------------------------------------------------------------------------
-- Signals (RBXScriptSignal stand-in)
---------------------------------------------------------------------------------------------
local Sig = {}
Sig.__index = Sig

function Sig.new(name)
	return setmetatable({ name = name, conns = {}, waiting = {} }, Sig)
end

function Sig:Connect(fn)
	if type(fn) ~= "function" then
		error("Attempt to connect failed: Passed value is not a function", 2)
	end
	local conns = self.conns
	local c = { Connected = true, fn = fn }
	function c.Disconnect()
		c.Connected = false
		local i = table.find(conns, c)
		if i then
			table.remove(conns, i)
		end
	end
	table.insert(conns, c)
	return c
end

function Sig:Once(fn)
	local c
	c = self:Connect(function(...)
		c.Disconnect()
		fn(...)
	end)
	return c
end

function Sig:Wait()
	if not coroutine.isyieldable() then
		error("Signal:Wait() from a non-yieldable context", 2)
	end
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end

function Sig:Fire(...)
	if #self.conns > 0 then
		for _, c in table.clone(self.conns) do
			if c.Connected then
				resume(coroutine.create(c.fn), ...)
			end
		end
	end
	if #self.waiting > 0 then
		local w = self.waiting
		self.waiting = {}
		for _, co in w do
			resume(co, ...)
		end
	end
end

function Sig:DisconnectAll()
	for _, c in self.conns do
		c.Connected = false
	end
	table.clear(self.conns)
end
Mock.Signal = Sig

---------------------------------------------------------------------------------------------
-- Class info from the API dump
---------------------------------------------------------------------------------------------
local classes = {}
local function toSet(s)
	local t = {}
	for w in string.gmatch(s, "[^,]+") do
		t[w] = true
	end
	return t
end
for name, row in ApiIndex do
	classes[name] = { super = row[1], events = toSet(row[2]), fns = toSet(row[3]), deprecated = toSet(row[4]) }
end

local function isA(className, target)
	local c = className
	while c and c ~= "" do
		if c == target then
			return true
		end
		local info = classes[c]
		if not info then
			return false
		end
		c = info.super
	end
	return false
end
Mock.isA = isA

local kindCache = {}
local function memberKind(className, key)
	local ck = className .. "." .. tostring(key)
	local k = kindCache[ck]
	if k == nil then
		k = false
		local c = className
		while c and c ~= "" do
			local info = classes[c]
			if not info then
				break
			end
			if info.events[key] then
				k = "event"
				break
			elseif info.fns[key] then
				k = "function"
				break
			elseif info.deprecated[key] then
				k = "deprecated"
				break
			end
			c = info.super
		end
		kindCache[ck] = k
	end
	return k
end

-- registry lookup walking the class hierarchy (memoized)
local NONE = {}
local function makeRegistry()
	local reg = {}
	local cache = {}
	local function lookup(className, key)
		local ck = className .. "." .. tostring(key)
		local v = cache[ck]
		if v == nil then
			v = NONE
			local c = className
			while c and c ~= "" do
				local r = reg[c]
				if r and r[key] ~= nil then
					v = r[key]
					break
				end
				local info = classes[c]
				if not info then
					break
				end
				c = info.super
			end
			cache[ck] = v
		end
		if v == NONE then
			return nil
		end
		return v
	end
	return reg, lookup
end

local Methods, lookupMethod = makeRegistry()
local Computed, lookupComputed = makeRegistry()
local Callbacks = { OnServerInvoke = true, OnClientInvoke = true, OnInvoke = true, ProcessReceipt = true }
local Inits = {}

---------------------------------------------------------------------------------------------
-- Proxies
---------------------------------------------------------------------------------------------
local meta = setmetatable({}, { __mode = "k" }) -- proxy -> state
local destroyed = {} -- raw instance -> true (Destroy is emulated: Lune panics on destroyed instances)
local Proxy = {}
local virtualOf = {} -- raw instance -> { name -> script node }

local function wrap(side, v)
	if typeof(v) ~= "Instance" then
		return v
	end
	local p = side.proxies[v]
	if p == nil then
		p = setmetatable({}, Proxy)
		local cls = v.ClassName
		local m = { inst = v, side = side, class = cls, events = {}, over = {} }
		meta[p] = m
		side.proxies[v] = p
		local init = Inits[cls]
		if init then
			init(side, p, m)
		end
	end
	return p
end
Mock.wrap = wrap

local function unwrap(v)
	if type(v) == "table" then
		local m = meta[v]
		if m then
			return m.inst
		end
	end
	return v
end
Mock.unwrap = unwrap

function Mock.state(p)
	return meta[p]
end

local function eventOf(p, name)
	local m = meta[p]
	local s = m.events[name]
	if not s then
		s = Sig.new(name)
		m.events[name] = s
	end
	return s
end
Mock.eventOf = eventOf

local function wrapResult(side, r)
	if typeof(r) == "Instance" then
		return wrap(side, r)
	elseif type(r) == "table" and getmetatable(r) == nil then
		for i, x in r do
			if typeof(x) == "Instance" then
				r[i] = wrap(side, x)
			end
		end
	end
	return r
end

local function getIndex(o, k)
	return o[k]
end
local function setIndex(o, k, v)
	o[k] = v
end

local methodWrappers = {}
local function genericMethod(cls, key)
	local id = cls .. "." .. key
	local w = methodWrappers[id]
	if not w then
		w = function(self, ...)
			local sm = meta[self]
			if not sm then
				error(string.format("Expected ':' not '.' calling member function %s", key), 2)
			end
			local args = table.pack(...)
			for i = 1, args.n do
				args[i] = unwrap(args[i])
			end
			local fn = sm.inst[key]
			local res = table.pack(fn(sm.inst, table.unpack(args, 1, args.n)))
			for i = 1, res.n do
				res[i] = wrapResult(sm.side, res[i])
			end
			return table.unpack(res, 1, res.n)
		end
		methodWrappers[id] = w
	end
	return w
end

Proxy.__index = function(p, key)
	local m = meta[p]
	local over = m.over[key]
	if over ~= nil then
		return over
	end
	local cls = m.class
	local mock = lookupMethod(cls, key)
	if mock then
		return mock
	end
	local comp = lookupComputed(cls, key)
	if comp ~= nil then
		if type(comp) == "function" then
			return comp(p, m)
		end
		return comp
	end
	local kind = memberKind(cls, key)
	if kind == "event" then
		return eventOf(p, key)
	end
	local virtual = virtualOf[m.inst]
	if virtual and virtual[key] then
		return virtual[key]
	end
	local ok, v = pcall(getIndex, m.inst, key)
	if not ok then
		if kind == "function" then
			error(string.format("[mock] %s:%s is a real Roblox method the mock does not implement", cls, key), 2)
		end
		error(errText(v), 2)
	end
	if type(v) == "function" then
		return genericMethod(cls, key)
	end
	if kind == "deprecated" then
		problem("deprecated", cls .. "." .. tostring(key) .. " is deprecated\n" .. shortTrace(3))
	end
	if typeof(v) == "Instance" then
		return wrap(m.side, v)
	end
	return v
end

local function hasNaN(v)
	local t = typeof(v)
	if t == "number" then
		return v ~= v
	elseif t == "UDim2" then
		return v.X.Scale ~= v.X.Scale or v.X.Offset ~= v.X.Offset or v.Y.Scale ~= v.Y.Scale or v.Y.Offset ~= v.Y.Offset
	elseif t == "UDim" then
		return v.Scale ~= v.Scale or v.Offset ~= v.Offset
	elseif t == "Vector2" then
		return v.X ~= v.X or v.Y ~= v.Y
	elseif t == "Color3" then
		return v.R ~= v.R or v.G ~= v.G or v.B ~= v.B
	end
	return false
end

Proxy.__newindex = function(p, key, value)
	local m = meta[p]
	if Callbacks[key] then
		m.over[key] = value
		return
	end
	local raw = unwrap(value)
	if key == "Parent" and destroyed[m.inst] then
		error(
			string.format(
				"The Parent property of %s is locked, current parent: NULL, new parent %s",
				m.inst.Name,
				if raw then tostring(raw) else "NULL"
			),
			2
		)
	end
	if hasNaN(raw) then
		problem("nan", string.format("%s.%s set to NaN (%s)\n%s", m.class, tostring(key), tostring(raw), shortTrace(3)))
	end
	local ok, err = pcall(setIndex, m.inst, key, raw)
	if not ok then
		local msg = errText(err)
		if type(raw) == "number" and string.find(msg, "into 'String'", 1, true) then
			ok, err = pcall(setIndex, m.inst, key, tostring(raw))
		end
		if not ok then
			error(
				string.format("%s.%s = %s (%s): %s", m.class, tostring(key), tostring(value), typeof(raw), errText(err)),
				2
			)
		end
	end
	if memberKind(m.class, key) == "deprecated" then
		problem("deprecated", m.class .. "." .. tostring(key) .. " is deprecated\n" .. shortTrace(3))
	end
	local ps = m.propSignals
	if ps and ps[key] then
		ps[key]:Fire()
	end
	local ch = m.events.Changed
	if ch then
		ch:Fire(key)
	end
end

Proxy.__tostring = function(p)
	return meta[p].inst.Name
end

local killEvents

-- Roblox Destroy(): parent set to nil and locked for the instance and every
-- descendant, all their connections disconnected.
function Mock.destroy(inst)
	if destroyed[inst] then
		return
	end
	local desc = inst:GetDescendants()
	for i = #desc, 1, -1 do
		local d = desc[i]
		destroyed[d] = true
		killEvents(d)
		d.Parent = nil
	end
	destroyed[inst] = true
	killEvents(inst)
	inst.Parent = nil
end

function Mock.isDestroyed(inst)
	return destroyed[unwrap(inst)] == true
end

function killEvents(inst)
	for _, side in Mock.sides do
		local p = side.proxies[inst]
		if p then
			local m = meta[p]
			for _, s in m.events do
				s:DisconnectAll()
			end
			if m.propSignals then
				for _, s in m.propSignals do
					s:DisconnectAll()
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Script tree (ModuleScripts loaded from src/)
---------------------------------------------------------------------------------------------
local Node = {}
local NodeMethods = {}
Node.__index = function(t, key)
	local c = rawget(t, "__children")[key]
	if c ~= nil then
		return c
	end
	local f = NodeMethods[key]
	if f then
		return f
	end
	if key == "ClassName" then
		return rawget(t, "__class")
	end
	error(string.format('%s is not a valid member of %s "%s"', tostring(key), rawget(t, "__class"), t.Name), 2)
end
Node.__tostring = function(t)
	return t.Name
end

function NodeMethods.FindFirstChild(self, name)
	return rawget(self, "__children")[name]
end
function NodeMethods.WaitForChild(self, name)
	local c = rawget(self, "__children")[name]
	if not c then
		problem("infinite-yield", "Infinite yield possible on " .. self.Name .. ':WaitForChild("' .. name .. '")')
		error("WaitForChild: " .. name .. " never appears under " .. self.Name, 2)
	end
	return c
end
function NodeMethods.GetChildren(self)
	local out = {}
	for _, c in rawget(self, "__children") do
		table.insert(out, c)
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end
function NodeMethods.GetDescendants(self)
	local out = {}
	local function walk(n)
		for _, c in NodeMethods.GetChildren(n) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function NodeMethods.IsA(self, cls)
	local mine = rawget(self, "__class")
	if cls == mine or cls == "Instance" then
		return true
	end
	if cls == "LuaSourceContainer" then
		return mine ~= "Folder"
	end
	if cls == "BaseScript" then
		return mine == "Script" or mine == "LocalScript"
	end
	return false
end
function NodeMethods.GetFullName(self)
	local parts = {}
	local n = self
	while n do
		table.insert(parts, 1, n.Name)
		n = rawget(n, "Parent")
	end
	return table.concat(parts, ".")
end

local function newNode(name, parent, path, class)
	-- sources are read now: Lune's async fs calls can't run inside our own coroutines
	local source = if path then fs.readFile(path) else nil
	return setmetatable(
		{ Name = name, Parent = parent, __path = path, __class = class, __source = source, __children = {} },
		Node
	)
end

local function stripExt(file)
	for _, pair in { { ".server.luau", "Script" }, { ".client.luau", "LocalScript" }, { ".luau", "ModuleScript" } } do
		local ext = pair[1]
		if string.sub(file, -#ext) == ext then
			return string.sub(file, 1, -#ext - 1), pair[2]
		end
	end
	return nil, nil
end

local function buildTree(dirPath, name, parent)
	local initPath = dirPath .. "/init.luau"
	local isModule = fs.isFile(initPath)
	local node =
		newNode(name, parent, if isModule then initPath else nil, if isModule then "ModuleScript" else "Folder")
	for _, entry in fs.readDir(dirPath) do
		local full = dirPath .. "/" .. entry
		if fs.isDir(full) then
			node.__children[entry] = buildTree(full, entry, node)
		elseif entry ~= "init.luau" then
			local base, class = stripExt(entry)
			if base then
				node.__children[base] = newNode(base, node, full, class)
			end
		end
	end
	return node
end

local LOADING = {}

local function loadChunk(side, node)
	local path = rawget(node, "__path")
	local env = setmetatable({ script = node }, { __index = side.env })
	return luau.load(rawget(node, "__source"), { debugName = path, environment = env, injectGlobals = false })
end

local function requireFor(side)
	return function(node)
		if type(node) ~= "table" or getmetatable(node) ~= Node then
			error("Attempted to call require with invalid argument(s).", 2)
		end
		if rawget(node, "__class") ~= "ModuleScript" then
			error("require: " .. node.Name .. " is not a ModuleScript", 2)
		end
		local path = rawget(node, "__path")
		local cached = side.modules[path]
		if cached == LOADING then
			-- another thread is loading it: Roblox makes this require wait
			if side.loaders[path] == coroutine.running() then
				error("Requested module was required recursively: " .. path, 2)
			end
			local waited = 0
			while side.modules[path] == LOADING do
				if not coroutine.isyieldable() then
					error("require of a loading module from a non-yieldable context: " .. path, 2)
				end
				waited += taskLib.wait()
				if waited > 10 then
					problem("infinite-yield", "require(" .. path .. ") waited 10 s for another thread to load it")
					waited = -math.huge
				end
			end
			cached = side.modules[path]
			if cached == nil then
				error("Requested module experienced an error while loading: " .. path, 2)
			end
		end
		if cached ~= nil then
			return cached
		end
		side.modules[path] = LOADING
		side.loaders[path] = coroutine.running()
		local fn = loadChunk(side, node)
		local ok, result = xpcall(fn, function(e)
			return debug.traceback(errText(e), 2)
		end)
		if not ok then
			side.modules[path] = nil
			error("Requested module experienced an error while loading: " .. path .. ": " .. tostring(result), 2)
		end
		if result == nil then
			side.modules[path] = nil
			error("Module code did not return exactly one value: " .. path, 2)
		end
		side.modules[path] = result
		return result
	end
end

---------------------------------------------------------------------------------------------
-- Network (remotes) with Roblox's argument rules
---------------------------------------------------------------------------------------------
local netQueue = {}

local function toWire(v, path, seen)
	local t = type(v)
	if t == "nil" or t == "boolean" or t == "number" or t == "string" or t == "vector" then
		return v
	end
	if t == "function" or t == "thread" then
		problem("remote", "cannot send a " .. t .. " (at " .. path .. ")\n" .. shortTrace(4))
		return nil
	end
	if t == "table" then
		local m = meta[v]
		if m then
			return m.inst
		end
		if getmetatable(v) == Node then
			return nil
		end
		if seen[v] then
			problem("remote", "cyclic table (at " .. path .. ")")
			return nil
		end
		seen[v] = true
		if getmetatable(v) ~= nil then
			problem("remote", "metatable would be stripped (at " .. path .. ")\n" .. shortTrace(4))
		end
		local nIdx, nStr, nOther, maxI = 0, 0, 0, 0
		for k in v do
			local kt = type(k)
			if kt == "number" and k >= 1 and k % 1 == 0 then
				nIdx += 1
				if k > maxI then
					maxI = k
				end
			elseif kt == "string" then
				nStr += 1
			else
				nOther += 1
			end
		end
		if nOther > 0 then
			problem("remote", "non-string keys (at " .. path .. "): Roblox converts them to strings\n" .. shortTrace(4))
		end
		if nIdx > 0 and nStr > 0 then
			problem(
				"remote",
				"mixed array/dictionary table (at " .. path .. "): Roblox drops part of it\n" .. shortTrace(4)
			)
		elseif nIdx > 0 and maxI ~= nIdx then
			problem("remote", "sparse array (at " .. path .. "): Roblox mangles arrays with holes\n" .. shortTrace(4))
		end
		local out = {}
		for k, x in v do
			out[k] = toWire(x, path .. "." .. tostring(k), seen)
		end
		seen[v] = nil
		return out
	end
	return v -- Roblox datatypes / raw instances
end

local function fromWire(side, v)
	if type(v) == "table" then
		local out = {}
		for k, x in v do
			out[k] = fromWire(side, x)
		end
		return out
	elseif typeof(v) == "Instance" then
		return wrap(side, v)
	end
	return v
end

local function wireSize(v)
	local t = type(v)
	if t == "nil" or t == "boolean" then
		return 1
	elseif t == "number" then
		return 9
	elseif t == "string" then
		return #v + 2
	elseif t == "table" then
		local s = 2
		for k, x in v do
			s += (if type(k) == "string" then #k + 2 else 0) + wireSize(x)
		end
		return s
	end
	local ty = typeof(v)
	if ty == "Instance" then
		return 8
	elseif ty == "Vector2" then
		return 9
	elseif ty == "Vector3" or ty == "Color3" then
		return 13
	end
	return 17
end
Mock.wireSize = wireSize

local function packArgs(...)
	local n = select("#", ...)
	local out = { n = n }
	for i = 1, n do
		out[i] = toWire((select(i, ...)), "arg" .. i, {})
	end
	return out
end

local function unpackArgs(side, args, first)
	local out = { n = args.n + (if first ~= nil then 1 else 0) }
	local o = 0
	if first ~= nil then
		out[1] = first
		o = 1
	end
	for i = 1, args.n do
		out[i + o] = fromWire(side, args[i])
	end
	return out
end

Mock.stats = { reliable = 0, unreliable = 0, maxUnreliable = 0, dropped = 0, bytes = 0 }

local function sizeOk(m, args)
	local size = 0
	for i = 1, args.n do
		size += wireSize(args[i])
	end
	Mock.stats.bytes += size
	if m.class == "UnreliableRemoteEvent" then
		Mock.stats.unreliable += 1
		Mock.stats.maxUnreliable = math.max(Mock.stats.maxUnreliable, size)
		if size > Mock.UNRELIABLE_LIMIT then
			Mock.stats.dropped += 1
			problem(
				"remote",
				string.format(
					"unreliable payload of ~%d bytes on %s would be DROPPED by Roblox (limit 900)",
					size,
					m.inst.Name
				)
			)
			return false
		end
	else
		Mock.stats.reliable += 1
	end
	return true
end

local function enqueue(to, inst, event, args, player)
	table.insert(netQueue, {
		at = Clock.frame + Mock.latencyFrames,
		to = to,
		inst = inst,
		event = event,
		args = args,
		player = player,
	})
end

local function flushNet()
	local i = 1
	while i <= #netQueue do
		local msg = netQueue[i]
		if msg.at <= Clock.frame then
			table.remove(netQueue, i)
			if not msg.to.gone then
				local p = wrap(msg.to, msg.inst)
				local args = unpackArgs(msg.to, msg.args, if msg.player then wrap(msg.to, msg.player) else nil)
				eventOf(p, msg.event):Fire(table.unpack(args, 1, args.n))
			end
		else
			i += 1
		end
	end
end

local function fireServer(self, ...)
	local m = meta[self]
	local side = m.side
	if side.isServer then
		problem("remote", "FireServer called on the server (" .. m.inst.Name .. ")\n" .. shortTrace(3))
		return
	end
	local args = packArgs(...)
	if sizeOk(m, args) then
		enqueue(Mock.server, m.inst, "OnServerEvent", args, side.playerRaw)
	end
end

local function fireClient(self, player, ...)
	local m = meta[self]
	if not m.side.isServer then
		problem("remote", "FireClient called on a client\n" .. shortTrace(3))
		return
	end
	local raw = unwrap(player)
	if typeof(raw) ~= "Instance" or raw.ClassName ~= "Player" then
		error("FireClient: player argument must be a Player object", 2)
	end
	local args = packArgs(...)
	if sizeOk(m, args) then
		local target = Mock.sideOfPlayer[raw]
		if target and not target.gone then
			enqueue(target, m.inst, "OnClientEvent", args, nil)
		end
	end
end

local function fireAllClients(self, ...)
	local m = meta[self]
	if not m.side.isServer then
		problem("remote", "FireAllClients called on a client\n" .. shortTrace(3))
		return
	end
	local args = packArgs(...)
	if sizeOk(m, args) then
		for _, side in Mock.sides do
			if not side.isServer and not side.gone then
				enqueue(side, m.inst, "OnClientEvent", args, nil)
			end
		end
	end
end

Methods.RemoteEvent = { FireServer = fireServer, FireClient = fireClient, FireAllClients = fireAllClients }
Methods.UnreliableRemoteEvent = { FireServer = fireServer, FireClient = fireClient, FireAllClients = fireAllClients }
Methods.RemoteFunction = {
	InvokeServer = function(self, ...)
		local m = meta[self]
		local side = m.side
		if side.isServer then
			error("InvokeServer can only be called from the client", 2)
		end
		if not coroutine.isyieldable() then
			error("InvokeServer called from a non-yieldable context", 2)
		end
		local args = packArgs(...)
		taskLib.wait(Mock.latencyFrames / 60)
		local sp = wrap(Mock.server, m.inst)
		local fn = meta[sp].over.OnServerInvoke
		local waited = 0
		while not fn do
			waited += taskLib.wait()
			fn = meta[sp].over.OnServerInvoke
			if waited > 10 then
				problem("remote", "InvokeServer: no OnServerInvoke callback after 10 s")
				return nil
			end
		end
		local inArgs = unpackArgs(Mock.server, args, wrap(Mock.server, side.playerRaw))
		local res = table.pack(pcall(fn, table.unpack(inArgs, 1, inArgs.n)))
		taskLib.wait(Mock.latencyFrames / 60)
		if not res[1] then
			error(errText(res[2]), 2)
		end
		local out = { n = res.n - 1 }
		for i = 2, res.n do
			out[i - 1] = fromWire(side, toWire(res[i], "result" .. (i - 1), {}))
		end
		return table.unpack(out, 1, out.n)
	end,
	InvokeClient = function()
		error("[mock] InvokeClient is not supported (and is unsafe on Roblox)", 2)
	end,
}
Methods.BindableEvent = {
	Fire = function(self, ...)
		eventOf(self, "Event"):Fire(...)
	end,
}

---------------------------------------------------------------------------------------------
-- DataStores
---------------------------------------------------------------------------------------------
Mock.dataStores = {}

local function asyncYield(what)
	if not coroutine.isyieldable() then
		error(what .. " yields and was called from a non-yieldable context", 3)
	end
	taskLib.wait()
end

local function dsCheck(v, path, seen)
	local t = type(v)
	if t == "nil" or t == "boolean" then
		return nil
	elseif t == "string" then
		if utf8.len(v) == nil then
			return "invalid UTF-8 string at " .. path
		end
		return nil
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return "NaN/inf at " .. path
		end
		return nil
	elseif t ~= "table" then
		return typeof(v) .. " can't be saved (at " .. path .. ")"
	end
	if meta[v] then
		return "Instance can't be saved (at " .. path .. ")"
	end
	if seen[v] then
		return "cyclic table at " .. path
	end
	seen[v] = true
	local nIdx, nStr, nOther, maxI = 0, 0, 0, 0
	for k in v do
		if type(k) == "number" and k >= 1 and k % 1 == 0 then
			nIdx += 1
			maxI = math.max(maxI, k)
		elseif type(k) == "string" then
			nStr += 1
		else
			nOther += 1
		end
	end
	if nOther > 0 then
		return "non-string keys at " .. path
	end
	if nIdx > 0 and nStr > 0 then
		return "mixed array/dictionary at " .. path
	end
	if nIdx > 0 and maxI ~= nIdx then
		return "sparse array at " .. path
	end
	for k, x in v do
		local e = dsCheck(x, path .. "." .. tostring(k), seen)
		if e then
			return e
		end
	end
	seen[v] = nil
	return nil
end

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end
Mock.deepCopy = deepCopy

local function newStore(name, ordered)
	local store = { name = name, ordered = ordered, data = {}, writes = 0, reads = 0 }
	local api = { __store = store }

	local function checkKey(key)
		if type(key) ~= "string" or #key == 0 or #key > 50 then
			error("DataStore key must be a string of 1-50 characters (got " .. tostring(key) .. ")", 3)
		end
		if not Mock.dataStoresEnabled then
			error(
				"502: API Services rejected request with error. Error code: 7 Reason: Studio access to APIs is not allowed.",
				3
			)
		end
	end
	local function validate(value)
		if ordered then
			if type(value) ~= "number" or value % 1 ~= 0 then
				error("OrderedDataStore values must be integers (got " .. tostring(value) .. ")", 4)
			end
			return
		end
		local e = dsCheck(value, "value", {})
		if e then
			problem("datastore", "can't save to " .. name .. ": " .. e)
			error("DataStore: " .. e, 4)
		end
		local ok, encoded = pcall(serde.encode, "json", value)
		if ok and #encoded > 4_000_000 then
			error("DataStore value too large", 4)
		end
	end
	local function keyInfo()
		return {
			Version = tostring(store.writes),
			CreatedTime = 0,
			UpdatedTime = 0,
			GetMetadata = function()
				return {}
			end,
			GetUserIds = function()
				return {}
			end,
		}
	end

	function api:GetAsync(key)
		checkKey(key)
		asyncYield("GetAsync")
		store.reads += 1
		return deepCopy(store.data[key]), keyInfo()
	end
	function api:SetAsync(key, value)
		checkKey(key)
		asyncYield("SetAsync")
		validate(value)
		store.data[key] = deepCopy(value)
		store.writes += 1
	end
	function api:UpdateAsync(key, transform)
		checkKey(key)
		asyncYield("UpdateAsync")
		local old = deepCopy(store.data[key])
		local co = coroutine.create(transform)
		local ok, new = coroutine.resume(co, old, keyInfo())
		if not ok then
			error("UpdateAsync callback errored: " .. errText(new), 2)
		end
		if coroutine.status(co) ~= "dead" then
			problem("datastore", "UpdateAsync callback yielded (not allowed on Roblox) for " .. name)
			coroutine.close(co)
			error("UpdateAsync callbacks cannot yield", 2)
		end
		if new == nil then
			return nil
		end
		validate(new)
		store.data[key] = deepCopy(new)
		store.writes += 1
		return deepCopy(new), keyInfo()
	end
	function api:RemoveAsync(key)
		checkKey(key)
		asyncYield("RemoveAsync")
		local old = store.data[key]
		store.data[key] = nil
		return deepCopy(old)
	end
	function api:IncrementAsync(key, delta)
		checkKey(key)
		asyncYield("IncrementAsync")
		local v = (store.data[key] or 0) + (delta or 1)
		validate(v)
		store.data[key] = v
		return v
	end
	if ordered then
		function api:GetSortedAsync(ascending, pageSize, minValue, maxValue)
			asyncYield("GetSortedAsync")
			if type(pageSize) ~= "number" or pageSize < 1 or pageSize > 100 then
				error("GetSortedAsync: pageSize must be 1-100", 2)
			end
			local items = {}
			for k, v in store.data do
				if (minValue == nil or v >= minValue) and (maxValue == nil or v <= maxValue) then
					table.insert(items, { key = k, value = v })
				end
			end
			table.sort(items, function(a, b)
				if a.value == b.value then
					return a.key < b.key
				end
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			local page = 1
			local pages = { IsFinished = #items <= pageSize }
			function pages:GetCurrentPage()
				local out = {}
				for i = (page - 1) * pageSize + 1, math.min(#items, page * pageSize) do
					table.insert(out, { key = items[i].key, value = items[i].value })
				end
				return out
			end
			function pages:AdvanceToNextPageAsync()
				asyncYield("AdvanceToNextPageAsync")
				page += 1
				pages.IsFinished = page * pageSize >= #items
			end
			return pages
		end
	end
	return api
end

local function getStore(name, scope, ordered)
	if type(name) ~= "string" or #name == 0 or #name > 50 then
		error("DataStore name must be 1-50 characters", 3)
	end
	local id = (if ordered then "ordered:" else "") .. name .. "/" .. (scope or "global")
	local s = Mock.dataStores[id]
	if not s then
		s = newStore(name, ordered)
		Mock.dataStores[id] = s
	end
	return s
end

function Mock.storeData(name, ordered)
	local s = Mock.dataStores[(if ordered then "ordered:" else "") .. name .. "/global"]
	return s and s.__store.data
end

Methods.DataStoreService = {
	GetDataStore = function(_, name, scope)
		return getStore(name, scope, false)
	end,
	GetOrderedDataStore = function(_, name, scope)
		return getStore(name, scope, true)
	end,
	GetGlobalDataStore = function()
		return getStore("global", nil, false)
	end,
	GetRequestBudgetForRequestType = function()
		return 100
	end,
}

---------------------------------------------------------------------------------------------
-- Services and other engine members
---------------------------------------------------------------------------------------------
Mock.closeHandlers = {}
Mock.prompts = {}
Mock.kicks = {}
Mock.userNames = {}

local function absSize(side, inst)
	if inst == nil then
		return Vector2.new(0, 0)
	end
	local cls = inst.ClassName
	if cls == "ScreenGui" or cls == "PlayerGui" or cls == "StarterGui" then
		return side.viewport
	end
	local parent = inst.Parent
	if not isA(cls, "GuiObject") then
		return if parent then absSize(side, parent) else Vector2.new(0, 0)
	end
	local ps = if parent then absSize(side, parent) else Vector2.new(0, 0)
	local s = inst.Size
	return Vector2.new(ps.X * s.X.Scale + s.X.Offset, ps.Y * s.Y.Scale + s.Y.Offset)
end

local function absPos(side, inst)
	if inst == nil then
		return Vector2.new(0, 0)
	end
	local cls = inst.ClassName
	local parent = inst.Parent
	if not isA(cls, "GuiObject") then
		return if parent and cls ~= "ScreenGui" then absPos(side, parent) else Vector2.new(0, 0)
	end
	local pp = if parent then absPos(side, parent) else Vector2.new(0, 0)
	local ps = if parent then absSize(side, parent) else Vector2.new(0, 0)
	local me = absSize(side, inst)
	local pos = inst.Position
	local a = inst.AnchorPoint
	return Vector2.new(
		pp.X + ps.X * pos.X.Scale + pos.X.Offset - a.X * me.X,
		pp.Y + ps.Y * pos.Y.Scale + pos.Y.Offset - a.Y * me.Y
	)
end

Computed.GuiBase2d = {
	AbsoluteSize = function(_, m)
		return absSize(m.side, m.inst)
	end,
	AbsolutePosition = function(_, m)
		return absPos(m.side, m.inst)
	end,
	AbsoluteRotation = 0,
}
local function textBounds(_, m)
	local text = m.inst.Text
	local size = m.inst.TextSize
	return Vector2.new(#text * size * 0.5, size)
end
Computed.TextLabel = { TextBounds = textBounds, TextFits = true }
Computed.TextButton = { TextBounds = textBounds, TextFits = true }
Computed.TextBox = { TextBounds = textBounds, TextFits = true }
Computed.UIGridStyleLayout = {
	AbsoluteContentSize = function(_, m)
		local parent = m.inst.Parent
		return if parent then absSize(m.side, parent) else Vector2.new(0, 0)
	end,
}
Computed.ScrollingFrame = {
	AbsoluteCanvasSize = function(_, m)
		return absSize(m.side, m.inst)
	end,
	AbsoluteWindowSize = function(_, m)
		return absSize(m.side, m.inst)
	end,
}
Computed.Camera = {
	ViewportSize = function(_, m)
		return m.side.viewport
	end,
}
Computed.Sound = {
	IsPlaying = function(_, m)
		return m.playing == true
	end,
	IsPaused = function(_, m)
		return m.playing ~= true
	end,
	IsLoaded = true,
	TimeLength = 2,
}
Computed.DataModel = {
	JobId = "mock-job-0001",
	PlaceId = 0,
	GameId = 0,
	PlaceVersion = 1,
	PrivateServerId = "",
	PrivateServerOwnerId = 0,
	CreatorId = 0,
}
Computed.Player = {
	AccountAge = 365,
	MembershipType = Enum.MembershipType.None,
	LocaleId = "en-us",
	FollowUserId = 0,
}
Computed.Players = {
	LocalPlayer = function(_, m)
		return if m.side.playerRaw then wrap(m.side, m.side.playerRaw) else nil
	end,
	MaxPlayers = 12,
}
Computed.Workspace = {
	CurrentCamera = function(_, m)
		return m.side.camera
	end,
}
Computed.UserInputService = {
	TouchEnabled = function(_, m)
		return m.side.touch
	end,
	KeyboardEnabled = function(_, m)
		return not m.side.touch
	end,
	MouseEnabled = function(_, m)
		return not m.side.touch
	end,
	GamepadEnabled = function(_, m)
		return #m.side.gamepads > 0
	end,
	AccelerometerEnabled = false,
	GyroscopeEnabled = false,
	VREnabled = false,
}

Methods.Instance = {
	FindFirstChild = function(self, name, recursive)
		local m = meta[self]
		local virtual = virtualOf[m.inst]
		if virtual and virtual[name] then
			return virtual[name]
		end
		return wrap(m.side, m.inst:FindFirstChild(name, recursive))
	end,
	WaitForChild = function(self, name, timeout)
		local m = meta[self]
		local start = Clock.now
		local warned = false
		while true do
			local c = Methods.Instance.FindFirstChild(self, name)
			if c then
				return c
			end
			if not coroutine.isyieldable() then
				error('WaitForChild("' .. name .. '") would yield in a non-yieldable context', 2)
			end
			if timeout and Clock.now - start >= timeout then
				return nil
			end
			if not warned and Clock.now - start > 5 then
				warned = true
				problem(
					"infinite-yield",
					"Infinite yield possible on '" .. m.inst:GetFullName() .. ':WaitForChild("' .. name .. "\")'"
				)
			end
			taskLib.wait()
		end
	end,
	GetChildren = function(self)
		local m = meta[self]
		local out = {}
		for _, c in m.inst:GetChildren() do
			table.insert(out, wrap(m.side, c))
		end
		local virtual = virtualOf[m.inst]
		if virtual then
			for _, v in virtual do
				table.insert(out, v)
			end
		end
		return out
	end,
	IsA = function(self, cls)
		return isA(meta[self].class, cls)
	end,
	Destroy = function(self)
		Mock.destroy(meta[self].inst)
	end,
	ClearAllChildren = function(self)
		local m = meta[self]
		for _, c in m.inst:GetChildren() do
			Methods.Instance.Destroy(wrap(m.side, c))
		end
	end,
	GetPropertyChangedSignal = function(self, prop)
		local m = meta[self]
		local ok, e = pcall(getIndex, m.inst, prop)
		if
			not ok
			and not string.find(errText(e), "missing default", 1, true)
			and lookupComputed(m.class, prop) == nil
		then
			error(tostring(prop) .. " is not a valid property name.", 2)
		end
		m.propSignals = m.propSignals or {}
		local s = m.propSignals[prop]
		if not s then
			s = Sig.new(prop)
			m.propSignals[prop] = s
		end
		return s
	end,
	GetAttributeChangedSignal = function(self, attr)
		local m = meta[self]
		m.attrSignals = m.attrSignals or {}
		local s = m.attrSignals[attr]
		if not s then
			s = Sig.new(attr)
			m.attrSignals[attr] = s
		end
		return s
	end,
}

Methods.DataModel = {
	GetService = function(self, name)
		local m = meta[self]
		local ok, s = pcall(function()
			return m.inst:GetService(name)
		end)
		if not ok then
			error("'" .. tostring(name) .. "' is not a valid Service name", 2)
		end
		return wrap(m.side, s)
	end,
	BindToClose = function(self, fn)
		if not meta[self].side.isServer then
			error("BindToClose can only be called on the server", 2)
		end
		table.insert(Mock.closeHandlers, fn)
	end,
	IsLoaded = function()
		return true
	end,
}

Methods.Workspace = {
	GetServerTimeNow = function()
		return Mock.SERVER_EPOCH + Clock.now
	end,
}

Methods.RunService = {
	IsServer = function(self)
		return meta[self].side.isServer
	end,
	IsClient = function(self)
		return not meta[self].side.isServer
	end,
	IsStudio = function()
		return Mock.isStudio
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
	BindToRenderStep = function(self, name, prio, fn)
		local m = meta[self]
		m.bound = m.bound or {}
		m.bound[name] = { prio = prio, fn = fn }
	end,
	UnbindFromRenderStep = function(self, name)
		local m = meta[self]
		if m.bound then
			m.bound[name] = nil
		end
	end,
}

Methods.Players = {
	GetPlayers = function(self)
		local m = meta[self]
		local out = {}
		for _, c in m.inst:GetChildren() do
			if c.ClassName == "Player" then
				table.insert(out, wrap(m.side, c))
			end
		end
		return out
	end,
	GetPlayerByUserId = function(self, id)
		for _, p in Methods.Players.GetPlayers(self) do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
	GetNameFromUserIdAsync = function(_, id)
		asyncYield("GetNameFromUserIdAsync")
		local name = Mock.userNames[id]
		if not name then
			error("HTTP 400 (Bad Request): unknown user " .. tostring(id), 2)
		end
		return name
	end,
	GetUserThumbnailAsync = function(_, id)
		asyncYield("GetUserThumbnailAsync")
		return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(id) .. "&w=150&h=150", true
	end,
}

Methods.Player = {
	Kick = function(self, msg)
		local m = meta[self]
		table.insert(Mock.kicks, { player = m.inst.Name, msg = msg })
		print("  [kick] " .. m.inst.Name .. ": " .. tostring(msg))
		local side = Mock.sideOfPlayer[m.inst]
		if side then
			taskLib.defer(function()
				Mock.removePlayer(side)
			end)
		end
	end,
}

Methods.MarketplaceService = {
	PromptProductPurchase = function(self, player, id)
		table.insert(Mock.prompts, { side = meta[self].side, player = unwrap(player), id = id })
	end,
	PromptGamePassPurchase = function(self, player, id)
		table.insert(Mock.prompts, { side = meta[self].side, player = unwrap(player), id = id, pass = true })
	end,
	GetProductInfo = function(_, id)
		asyncYield("GetProductInfo")
		return { Name = "Product " .. tostring(id), PriceInRobux = 49, ProductId = id, Description = "" }
	end,
	UserOwnsGamePassAsync = function()
		asyncYield("UserOwnsGamePassAsync")
		return false
	end,
}

local tweenable = {
	number = true,
	boolean = true,
	UDim = true,
	UDim2 = true,
	Vector2 = true,
	Vector3 = true,
	Color3 = true,
	CFrame = true,
	Rect = true,
	NumberRange = true,
}
Methods.TweenService = {
	Create = function(_, target, info, goals)
		if type(target) ~= "table" or not meta[target] then
			error("TweenService:Create: argument 1 must be an Instance", 2)
		end
		if type(info) ~= "table" or not rawget(info, "__tweenInfo") then
			error("TweenService:Create: argument 2 must be a TweenInfo", 2)
		end
		for k, v in goals do
			if not tweenable[typeof(v)] then
				error("TweenService:Create property " .. tostring(k) .. " cannot be tweened (" .. typeof(v) .. ")", 2)
			end
			local ok, e = pcall(getIndex, target, k)
			if not ok then
				error("TweenService:Create no property named '" .. tostring(k) .. "': " .. errText(e), 2)
			end
		end
		local tw = { PlaybackState = Enum.PlaybackState.Begin, Completed = Sig.new("Completed") }
		function tw.Play()
			for k, v in goals do
				local ok, e = pcall(setIndex, target, k, v)
				if not ok then
					problem("error", "tween apply " .. tostring(k) .. ": " .. errText(e))
				end
			end
			tw.PlaybackState = Enum.PlaybackState.Completed
			taskLib.defer(function()
				tw.Completed:Fire(Enum.PlaybackState.Completed)
			end)
		end
		function tw.Cancel()
			tw.PlaybackState = Enum.PlaybackState.Cancelled
		end
		function tw.Pause() end
		function tw.Destroy() end
		return tw
	end,
	GetValue = function(_, alpha)
		return alpha
	end,
}

Methods.Debris = {
	AddItem = function(_, item, t)
		taskLib.delay(t or 10, function()
			if meta[item] then
				Methods.Instance.Destroy(item)
			end
		end)
	end,
}

Methods.StarterGui = {
	SetCoreGuiEnabled = function(_, kind, enabled)
		if typeof(kind) ~= "EnumItem" or type(enabled) ~= "boolean" then
			error("SetCoreGuiEnabled: bad arguments", 2)
		end
	end,
	GetCoreGuiEnabled = function()
		return true
	end,
	SetCore = function(_, name)
		if type(name) ~= "string" then
			error("SetCore: bad name", 2)
		end
	end,
	GetCore = function()
		return nil
	end,
}

Methods.UserInputService = {
	GetConnectedGamepads = function(self)
		return table.clone(meta[self].side.gamepads)
	end,
	GetNavigationGamepads = function()
		return {}
	end,
	GetGamepadConnected = function(self, pad)
		return table.find(meta[self].side.gamepads, pad) ~= nil
	end,
	GetLastInputType = function(self)
		return if meta[self].side.touch then Enum.UserInputType.Touch else Enum.UserInputType.Keyboard
	end,
	IsKeyDown = function()
		return false
	end,
	GetKeysPressed = function()
		return {}
	end,
	GetMouseLocation = function()
		return Vector2.new(0, 0)
	end,
	GetStringForKeyCode = function()
		return ""
	end,
}

Methods.GuiService = {
	GetGuiInset = function()
		return Vector2.new(0, 58), Vector2.new(0, 0)
	end,
	IsTenFootInterface = function()
		return false
	end,
}

Methods.Sound = {
	Play = function(self)
		local m = meta[self]
		local id = m.inst.SoundId
		if id ~= "" and not string.match(id, "^rbxassetid://%d+$") and not string.match(id, "^rbxasset://sounds/") then
			problem("sound", "suspicious SoundId '" .. id .. "'")
		end
		m.playing = true
		m.playId = (m.playId or 0) + 1
		local id = m.playId
		taskLib.delay(2, function()
			if m.playing and m.playId == id and not destroyed[m.inst] and not m.inst.Looped then
				m.playing = false
				local ended = m.events.Ended
				if ended then
					ended:Fire(m.inst.SoundId)
				end
			end
		end)
	end,
	Stop = function(self)
		meta[self].playing = false
	end,
	Pause = function(self)
		meta[self].playing = false
	end,
	Resume = function(self)
		meta[self].playing = true
	end,
}

Methods.SoundService = {
	PlayLocalSound = function() end,
}

Methods.ContentProvider = {
	PreloadAsync = function(_, list, cb)
		asyncYield("PreloadAsync")
		if cb then
			for _, item in list do
				cb(if type(item) == "string" then item else "", Enum.AssetFetchStatus.Success)
			end
		end
	end,
}

Methods.TextService = {
	GetTextSize = function(_, text, size)
		return Vector2.new(#text * size * 0.5, size)
	end,
}

local guidCounter = 0
Methods.HttpService = {
	GenerateGUID = function(_, braces)
		guidCounter += 1
		local s = string.format("00000000-0000-4000-8000-%012d", guidCounter)
		return if braces == false then s else "{" .. s .. "}"
	end,
	JSONEncode = function(_, v)
		return serde.encode("json", v)
	end,
	JSONDecode = function(_, s)
		return serde.decode("json", s)
	end,
}

---------------------------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------------------------
local RandomMT = {}
RandomMT.__index = RandomMT
local RandomAPI = {}
function RandomAPI.new(seed)
	local s = if seed ~= nil then math.floor(seed) % 4294967296 else (Clock.frame * 7919 + 12345) % 4294967296
	return setmetatable({ s = s }, RandomMT)
end
function RandomMT:_next()
	self.s = (self.s * 1664525 + 1013904223) % 4294967296
	return self.s / 4294967296
end
function RandomMT:NextNumber(a, b)
	local x = self:_next()
	if a == nil then
		return x
	end
	return a + (b - a) * x
end
function RandomMT:NextInteger(a, b)
	if a > b then
		error("invalid argument #2 to 'NextInteger' (interval is empty)", 2)
	end
	return a + math.floor(self:_next() * (b - a + 1))
end
function RandomMT:NextUnitVector()
	local z = self:NextNumber(-1, 1)
	local t = self:NextNumber(0, math.pi * 2)
	local r = math.sqrt(1 - z * z)
	return Vector3.new(r * math.cos(t), r * math.sin(t), z)
end
function RandomMT:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RandomMT:Clone()
	return setmetatable({ s = self.s }, RandomMT)
end

local TweenInfoAPI = {}
function TweenInfoAPI.new(time, style, direction, repeatCount, reverses, delayTime)
	if style ~= nil and typeof(style) ~= "EnumItem" then
		error("TweenInfo.new: argument 2 must be an EasingStyle", 2)
	end
	if direction ~= nil and typeof(direction) ~= "EnumItem" then
		error("TweenInfo.new: argument 3 must be an EasingDirection", 2)
	end
	return {
		__tweenInfo = true,
		Time = time or 1,
		EasingStyle = style or Enum.EasingStyle.Quad,
		EasingDirection = direction or Enum.EasingDirection.Out,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	}
end

local function mockTypeof(v)
	if type(v) == "table" then
		if meta[v] then
			return "Instance"
		end
		local mt = getmetatable(v)
		if mt == Node then
			return "Instance"
		elseif mt == RandomMT then
			return "Random"
		elseif mt == Sig then
			return "RBXScriptSignal"
		elseif rawget(v, "__tweenInfo") then
			return "TweenInfo"
		end
	end
	return typeof(v)
end

local BUILTINS = {
	"assert",
	"error",
	"getmetatable",
	"ipairs",
	"next",
	"pairs",
	"pcall",
	"rawequal",
	"rawget",
	"rawlen",
	"rawset",
	"select",
	"setmetatable",
	"tonumber",
	"tostring",
	"type",
	"unpack",
	"xpcall",
	"gcinfo",
	"newproxy",
	"bit32",
	"buffer",
	"coroutine",
	"debug",
	"math",
	"string",
	"table",
	"utf8",
	"vector",
	"_VERSION",
}

local DATATYPES = {}
for _, name in
	{
		"Axes",
		"BrickColor",
		"CFrame",
		"Color3",
		"ColorSequence",
		"ColorSequenceKeypoint",
		"Content",
		"Faces",
		"Font",
		"NumberRange",
		"NumberSequence",
		"NumberSequenceKeypoint",
		"PhysicalProperties",
		"Ray",
		"Rect",
		"Region3",
		"Region3int16",
		"UDim",
		"UDim2",
		"Vector2",
		"Vector2int16",
		"Vector3",
		"Vector3int16",
		"Enum",
	}
do
	local ok, v = pcall(function()
		return roblox[name]
	end)
	if ok and v ~= nil then
		DATATYPES[name] = v
	end
end

local mockOs = {
	clock = function()
		return Clock.now
	end,
	time = function(t)
		if t then
			return os.time(t)
		end
		return Mock.SERVER_EPOCH + math.floor(Clock.now) + Mock.timeOffset
	end,
	date = os.date,
	difftime = os.difftime,
}

local function buildEnv(side)
	local env = {}
	for _, name in BUILTINS do
		local ok, v = pcall(function()
			return (getfenv(0) :: any)[name]
		end)
		if ok and v ~= nil then
			env[name] = v
		end
	end
	for k, v in DATATYPES do
		env[k] = v
	end
	env.typeof = mockTypeof
	env.task = taskLib
	env.Random = RandomAPI
	env.TweenInfo = TweenInfoAPI
	env.os = mockOs
	env.tick = function()
		return Mock.SERVER_EPOCH + Clock.now
	end
	env.time = function()
		return Clock.now
	end
	env.elapsedTime = env.time
	for _, legacy in { "wait", "spawn", "delay" } do
		env[legacy] = function()
			error("deprecated global " .. legacy .. "() used; use task." .. legacy, 2)
		end
	end
	env.print = function(...)
		if Mock.verbose then
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring((select(i, ...))))
			end
			print("  [" .. side.name .. "] " .. table.concat(parts, " "))
		end
	end
	env.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			table.insert(parts, tostring((select(i, ...))))
		end
		local msg = table.concat(parts, " ")
		for _, pat in Mock.allowWarnings do
			if string.find(msg, pat) then
				if Mock.verbose then
					print("  [" .. side.name .. " warn, expected] " .. msg)
				end
				return
			end
		end
		problem("warn", "[" .. side.name .. "] " .. msg)
	end
	env.shared = {}
	env._G = {}
	env.require = requireFor(side)
	env.Instance = {
		new = function(className, parent)
			local ok, inst = pcall(roblox.Instance.new, className)
			if not ok then
				error('Unable to create an Instance of type "' .. tostring(className) .. '"', 2)
			end
			local p = wrap(side, inst)
			if parent ~= nil then
				p.Parent = parent
			end
			return p
		end,
	}
	env.game = wrap(side, Mock.dm)
	env.workspace = wrap(side, Mock.dm:GetService("Workspace"))
	env.settings = function()
		error("[mock] settings() not supported", 2)
	end
	return env
end

---------------------------------------------------------------------------------------------
-- World setup
---------------------------------------------------------------------------------------------
Mock.sides = {}
Mock.sideOfPlayer = {}

local function newSide(name, isServer)
	local side = {
		name = name,
		isServer = isServer,
		proxies = {},
		modules = {},
		loaders = {},
		viewport = Mock.viewport,
		touch = true,
		gamepads = {},
	}
	local cam = roblox.Instance.new("Camera")
	cam.Name = "Camera_" .. name
	cam.Parent = Mock.dm:GetService("Workspace")
	side.camera = wrap(side, cam)
	side.env = buildEnv(side)
	table.insert(Mock.sides, side)
	return side
end

local function runScript(side, node)
	local fn = loadChunk(side, node)
	local co = coroutine.create(fn)
	resume(co)
	return co
end

function Mock.init(root: string)
	Mock.root = root
	Mock.dm = roblox.Instance.new("DataModel")
	local dm = Mock.dm
	for _, s in
		{ "Workspace", "ReplicatedStorage", "ServerScriptService", "Players", "StarterGui", "SoundService", "Lighting" }
	do
		dm:GetService(s)
	end
	Mock.trees = {
		Shared = buildTree(root .. "/src/shared", "Shared", nil),
		Server = buildTree(root .. "/src/server", "Server", nil),
		Client = buildTree(root .. "/src/client", "Client", nil),
	}
	virtualOf[dm:GetService("ReplicatedStorage")] = { Shared = Mock.trees.Shared }
	virtualOf[dm:GetService("ServerScriptService")] = { Server = Mock.trees.Server }
end

function Mock.startServer()
	local server = newSide("server", true)
	Mock.server = server
	runScript(server, Mock.trees.Server.Main)
	return server
end

function Mock.addPlayer(userId: number, name: string, opts)
	opts = opts or {}
	local plr = roblox.Instance.new("Player")
	plr.Name = name
	plr.DisplayName = name
	plr.UserId = userId
	Mock.userNames[userId] = name
	local pg = roblox.Instance.new("PlayerGui")
	pg.Parent = plr
	plr.Parent = Mock.dm:GetService("Players")

	local side = newSide("client:" .. name, false)
	side.playerRaw = plr
	side.touch = opts.touch ~= false
	side.viewport = opts.viewport or Mock.viewport
	side.gamepads = opts.gamepads or {}
	Mock.sideOfPlayer[plr] = side

	local players = wrap(Mock.server, Mock.dm:GetService("Players"))
	eventOf(players, "PlayerAdded"):Fire(wrap(Mock.server, plr))
	side.mainThread = runScript(side, Mock.trees.Client.Main)
	return side
end

function Mock.removePlayer(side)
	if side.gone then
		return
	end
	side.gone = true
	local players = wrap(Mock.server, Mock.dm:GetService("Players"))
	eventOf(players, "PlayerRemoving"):Fire(wrap(Mock.server, side.playerRaw))
	side.playerRaw.Parent = nil
end

local function fireIf(p, name, ...)
	local s = meta[p].events[name]
	if s then
		s:Fire(...)
	end
end

function Mock.step(dt)
	dt = dt or 1 / 60
	Clock.frame += 1
	Clock.now += dt
	flushNet()
	local rsRaw = Mock.dm:GetService("RunService")
	for _, side in Mock.sides do
		if not side.isServer and not side.gone then
			local rs = wrap(side, rsRaw)
			local m = meta[rs]
			if m.bound then
				local list = {}
				for _, b in m.bound do
					table.insert(list, b)
				end
				table.sort(list, function(a, b)
					return a.prio < b.prio
				end)
				for _, b in list do
					resume(coroutine.create(b.fn), dt)
				end
			end
			fireIf(rs, "RenderStepped", dt)
			fireIf(rs, "PreRender", dt)
		end
	end
	runTimers()
	for _, side in Mock.sides do
		if not side.gone then
			local rs = wrap(side, rsRaw)
			fireIf(rs, "Stepped", Clock.now, dt)
			fireIf(rs, "PreSimulation", dt)
			fireIf(rs, "Heartbeat", dt)
			fireIf(rs, "PostSimulation", dt)
		end
	end
	runDeferred()
end

function Mock.run(seconds: number, perFrame: (() -> ())?)
	local frames = math.floor(seconds * 60 + 0.5)
	for _ = 1, frames do
		if perFrame then
			perFrame()
		end
		Mock.step()
	end
end

-- Run fn(...) as a thread of the game (so it may yield), stepping frames until it finishes.
function Mock.call(fn, ...)
	local results
	local co = coroutine.create(function(...)
		results = table.pack(fn(...))
	end)
	resume(co, ...)
	local guard = 0
	while coroutine.status(co) ~= "dead" do
		Mock.step()
		guard += 1
		if guard > 60 * 60 then
			problem("harness", "Mock.call did not finish within 60 s")
			break
		end
	end
	if results then
		return table.unpack(results, 1, results.n)
	end
	return nil
end

-- A module as loaded on a side (requires it on that side if needed).
function Mock.module(side, path: string)
	local node = Mock.trees[string.match(path, "^[^/]+")]
	for part in string.gmatch(string.match(path, "^[^/]+/(.*)$") or "", "[^/]+") do
		node = node[part]
	end
	local cached = side.modules[rawget(node, "__path")]
	if cached ~= nil and cached ~= LOADING then
		return cached
	end
	return Mock.call(side.env.require, node)
end

function Mock.close()
	for _, fn in Mock.closeHandlers do
		Mock.call(fn)
	end
end

---------------------------------------------------------------------------------------------
-- Driving the UI and input
---------------------------------------------------------------------------------------------
function Mock.isVisible(inst)
	local cur = inst
	while cur do
		local cls = cur.ClassName
		if cls == "ScreenGui" then
			if not cur.Enabled then
				return false
			end
		elseif cls == "PlayerGui" then
			return true
		elseif isA(cls, "GuiObject") and not cur.Visible then
			return false
		end
		cur = cur.Parent
	end
	return false
end

local function buttonText(b)
	if b.ClassName == "TextButton" and b.Text ~= "" then
		return b.Text
	end
	for _, c in b:GetChildren() do
		if c.ClassName == "TextLabel" and c.Name == "Title" then
			return c.Text
		end
	end
	for _, c in b:GetChildren() do
		if c.ClassName == "TextLabel" then
			return c.Text
		end
	end
	return ""
end
Mock.buttonText = buttonText

function Mock.buttons(side, filter)
	local pg = side.playerRaw:FindFirstChild("PlayerGui")
	local out = {}
	for _, d in pg:GetDescendants() do
		if (d.ClassName == "TextButton" or d.ClassName == "ImageButton") and Mock.isVisible(d) then
			local text = buttonText(d)
			if
				filter == nil
				or (type(filter) == "string" and text == filter)
				or (type(filter) == "function" and filter(d, text))
			then
				table.insert(out, d)
			end
		end
	end
	return out
end

function Mock.labels(side, pattern)
	local pg = side.playerRaw:FindFirstChild("PlayerGui")
	local out = {}
	for _, d in pg:GetDescendants() do
		if (d.ClassName == "TextLabel" or d.ClassName == "TextButton") and Mock.isVisible(d) then
			if string.find(d.Text, pattern) then
				table.insert(out, d)
			end
		end
	end
	return out
end

function Mock.click(side, rawButton)
	local p = wrap(side, rawButton)
	local io = {
		UserInputType = Enum.UserInputType.Touch,
		UserInputState = Enum.UserInputState.Begin,
		KeyCode = UNKNOWN_KEY,
		Position = Vector3.new(0, 0, 0),
		Delta = Vector3.new(0, 0, 0),
	}
	fireIf(p, "MouseButton1Down", 0, 0)
	fireIf(p, "MouseButton1Up", 0, 0)
	fireIf(p, "MouseButton1Click")
	fireIf(p, "Activated", io, 1)
end

function Mock.clickText(side, text: string, index: number?)
	local list = Mock.buttons(side, text)
	if #list == 0 then
		error("no visible button '" .. text .. "'", 2)
	end
	Mock.click(side, list[index or 1])
end

local function uis(side)
	return wrap(side, Mock.dm:GetService("UserInputService"))
end

function Mock.key(side, keyCode, down: boolean)
	local io = {
		UserInputType = Enum.UserInputType.Keyboard,
		KeyCode = keyCode,
		UserInputState = if down then Enum.UserInputState.Begin else Enum.UserInputState.End,
		Position = Vector3.new(0, 0, 0),
		Delta = Vector3.new(0, 0, 0),
	}
	fireIf(uis(side), if down then "InputBegan" else "InputEnded", io, false)
end

local touches = {}
function Mock.touch(side, id, x: number, y: number, down: boolean)
	local io = touches[id]
	if not io then
		io = {
			UserInputType = Enum.UserInputType.Touch,
			KeyCode = UNKNOWN_KEY,
			Position = Vector3.new(x, y, 0),
			Delta = Vector3.new(0, 0, 0),
		}
		touches[id] = io
	end
	io.UserInputState = if down then Enum.UserInputState.Begin else Enum.UserInputState.End
	fireIf(uis(side), if down then "InputBegan" else "InputEnded", io, false)
	if not down then
		touches[id] = nil
	end
end

function Mock.countGui(side)
	local pg = side.playerRaw:FindFirstChild("PlayerGui")
	return #pg:GetDescendants()
end

-- Instance counts per ScreenGui child (and per screen inside the menu column)
function Mock.census(side): { [string]: number }
	local pg = side.playerRaw:FindFirstChild("PlayerGui")
	local out = {}
	for _, gui in pg:GetChildren() do
		for _, c in gui:GetChildren() do
			if c.Name == "Column" then
				for _, screen in c:GetChildren() do
					out[gui.Name .. "." .. screen.Name] = #screen:GetDescendants() + 1
				end
			else
				out[gui.Name .. "." .. c.Name] = (out[gui.Name .. "." .. c.Name] or 0) + #c:GetDescendants() + 1
			end
		end
	end
	return out
end

function Mock.censusDiff(a, b): string
	local parts = {}
	for k, v in b do
		local d = v - (a[k] or 0)
		if d ~= 0 then
			table.insert(parts, string.format("%s %+d", k, d))
		end
	end
	for k in a do
		if b[k] == nil then
			table.insert(parts, k .. " gone")
		end
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

-- Simulate Roblox calling ProcessReceipt for a developer product purchase
function Mock.purchase(side, productId: number, purchaseId: string)
	local mps = wrap(Mock.server, Mock.dm:GetService("MarketplaceService"))
	local fn = meta[mps].over.ProcessReceipt
	if not fn then
		error("ProcessReceipt was never set", 2)
	end
	return Mock.call(fn, {
		PlayerId = side.playerRaw.UserId,
		ProductId = productId,
		PurchaseId = purchaseId,
		CurrencySpent = 49,
		CurrencyType = Enum.CurrencyType.Robux,
		PlaceIdWherePurchased = 0,
	})
end

return Mock
