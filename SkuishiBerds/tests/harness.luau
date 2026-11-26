--[[
	Test harness: loads the Rojo source tree as a fake Roblox instance hierarchy
	so modules using `require(script.Parent.X)` run unmodified under Lune.

	Usage (from the SkuishiBerds folder):  lune run tests/run
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Harness = {}

local cache = {}
local globalEnv = getfenv(1)

local Node = {}

local function newNode(name: string, parent, path: string?, isModule: boolean)
	local node = {
		Name = name,
		Parent = parent,
		__path = path,
		__isModule = isModule,
		__children = {},
	}
	return setmetatable(node, Node)
end

Node.__index = function(t, key)
	local children = rawget(t, "__children")
	local child = children[key]
	if child ~= nil then
		return child
	end
	if key == "FindFirstChild" then
		return function(self, n)
			return rawget(self, "__children")[n]
		end
	elseif key == "GetChildren" then
		return function(self)
			local out = {}
			for _, c in rawget(self, "__children") do
				table.insert(out, c)
			end
			return out
		end
	end
	error(string.format("%s is not a valid member of %s", tostring(key), rawget(t, "Name")), 2)
end

local function stripExt(file: string): (string, boolean)
	for _, ext in { ".server.luau", ".client.luau", ".luau", ".lua" } do
		if string.sub(file, -#ext) == ext then
			return string.sub(file, 1, -#ext - 1), true
		end
	end
	return file, false
end

local function build(dirPath: string, name: string, parent)
	local initPath = dirPath .. "/init.luau"
	local node = newNode(name, parent, if fs.isFile(initPath) then initPath else nil, fs.isFile(initPath))
	for _, entry in fs.readDir(dirPath) do
		local full = dirPath .. "/" .. entry
		if fs.isDir(full) then
			node.__children[entry] = build(full, entry, node)
		elseif entry ~= "init.luau" then
			local base, ok = stripExt(entry)
			if ok then
				node.__children[base] = newNode(base, node, full, true)
			end
		end
	end
	return node
end

local function requireNode(node)
	if type(node) ~= "table" or getmetatable(node) ~= Node then
		error("harness require expects a module node, got " .. typeof(node), 2)
	end
	local path = rawget(node, "__path")
	if not path then
		error("not a module: " .. rawget(node, "Name"), 2)
	end
	local cached = cache[path]
	if cached ~= nil then
		if cached == "__loading" then
			error("Requested module was required recursively: " .. path, 2)
		end
		return cached
	end
	cache[path] = "__loading"
	local source = fs.readFile(path)
	local env = setmetatable({ script = node, require = requireNode }, { __index = globalEnv })
	local fn = luau.load(source, { debugName = path, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

function Harness.load(root: string)
	local shared = build(root .. "/src/shared", "Shared", nil)
	return {
		Shared = shared,
		require = requireNode,
	}
end

return Harness
