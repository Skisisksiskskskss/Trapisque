--!nocheck
-- Lune test runner. Loads pure modules from src/ with a fake `script` tree so `require(script.Parent.X)` works
-- exactly like it does in Roblox, then runs every tests/*.spec.luau file.
-- Usage: lune run tests/run

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Lune's CFrame.lookAt returns wrong orientations for some directions; Roblox's is correct. Use a faithful version
-- so previews and checks match the real engine.
local function fixedLookAt(at, target, upVector)
	local look = (target - at).Unit
	local up = upVector or roblox.Vector3.new(0, 1, 0)
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(roblox.Vector3.new(0, 0, 1))
	end
	right = right.Unit
	local up2 = right:Cross(look).Unit
	return roblox.CFrame.fromMatrix(at, right, up2, -look)
end
local CFrameShim = setmetatable({ lookAt = fixedLookAt }, { __index = roblox.CFrame })

local moduleCache = {}
local makeNode

local function resolveModuleFile(path)
	if fs.isFile(path .. ".luau") then
		return path .. ".luau"
	end
	if fs.isDir(path) and fs.isFile(path .. "/init.luau") then
		return path .. "/init.luau"
	end
	return nil
end

local function loadModule(nodePath)
	if moduleCache[nodePath] ~= nil then
		return moduleCache[nodePath]
	end
	local file = resolveModuleFile(nodePath)
	assert(file, "cannot require " .. nodePath)
	local source = fs.readFile(file)
	local chunk = luau.load(source, {
		debugName = file,
		environment = {
			script = makeNode(nodePath),
			require = function(node)
				return loadModule(rawget(node, "__path"))
			end,
			Color3 = roblox.Color3,
			Vector3 = roblox.Vector3,
			Vector2 = roblox.Vector2,
			CFrame = CFrameShim,
			UDim2 = roblox.UDim2,
			UDim = roblox.UDim,
			Enum = roblox.Enum,
			NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			ColorSequence = roblox.ColorSequence,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			NumberRange = roblox.NumberRange,
			Instance = roblox.Instance,
			BrickColor = roblox.BrickColor,
		},
	})
	local result = chunk()
	moduleCache[nodePath] = result
	return result
end

function makeNode(nodePath)
	local node = { __path = nodePath }
	return setmetatable(node, {
		__index = function(_, key)
			if key == "Parent" then
				local parent = string.match(nodePath, "^(.*)/[^/]+$")
				return makeNode(parent)
			elseif key == "Name" then
				return string.match(nodePath, "([^/]+)$")
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, name)
					return makeNode(nodePath .. "/" .. name)
				end
			end
			return makeNode(nodePath .. "/" .. key)
		end,
	})
end

-- Simple deterministic RNG matching Roblox's Random:NextNumber() shape.
local function newRng(seed)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return {
		NextNumber = function(_self)
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end,
	}
end

local passed, failed = 0, 0
local failures = {}

local function makeContext(fileName)
	local ctx = {}
	function ctx.test(name, fn)
		local ok, err = pcall(fn)
		if ok then
			passed += 1
		else
			failed += 1
			table.insert(failures, fileName .. " :: " .. name .. "\n    " .. tostring(err))
		end
	end
	function ctx.expect(condition, message)
		if not condition then
			error(message or "expectation failed", 2)
		end
	end
	function ctx.near(a, b, epsilon, message)
		if math.abs(a - b) > (epsilon or 1e-6) then
			error((message or "values differ") .. string.format(": %s vs %s", tostring(a), tostring(b)), 2)
		end
	end
	function ctx.require(path)
		return loadModule(path)
	end
	ctx.newRng = newRng
	return ctx
end

local specs = {}
for _, entry in fs.readDir("tests") do
	if string.match(entry, "%.spec%.luau$") then
		table.insert(specs, entry)
	end
end
table.sort(specs)

for _, spec in specs do
	local source = fs.readFile("tests/" .. spec)
	local chunk = luau.load(source, { debugName = spec })
	local run = chunk()
	run(makeContext(spec))
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	for _, failure in failures do
		print("FAIL " .. failure)
	end
	process.exit(1)
end
