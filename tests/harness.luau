-- Minimal test harness (globals so every test file can use it).
TESTS = {}

function test(name, fn)
	table.insert(TESTS, { name = name, fn = fn })
end

local function fmt(v)
	if type(v) == "table" then
		local parts = {}
		for k, x in pairs(v) do
			table.insert(parts, tostring(k) .. "=" .. tostring(x))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

function eq(actual, expected, msg)
	if actual ~= expected then
		error((msg or "values differ") .. ": expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
	end
end

function truthy(v, msg)
	if not v then
		error(msg or "expected a truthy value", 2)
	end
end

function falsy(v, msg)
	if v then
		error((msg or "expected a falsy value") .. " (got " .. fmt(v) .. ")", 2)
	end
end

-- A scripted RNG: int() pops values from a queue (falls back to `a`), float() returns 0.5.
function scriptedRng(values)
	local rng = { queue = values or {} }
	function rng:int(a, b)
		local v = table.remove(self.queue, 1)
		if v == nil then
			return a
		end
		assert(v >= a and v <= b, "scripted value " .. v .. " outside " .. a .. ".." .. b)
		return v
	end
	function rng:float()
		return 0.5
	end
	function rng:chance(p)
		return 0.5 < p
	end
	function rng:pick(list)
		return list[1]
	end
	function rng:shuffle(list)
		return list
	end
	function rng:weighted(entries)
		return entries[1][1]
	end
	function rng:push(...)
		for _, v in { ... } do
			table.insert(self.queue, v)
		end
	end
	return rng
end

function findEvent(events, t, pred)
	for _, e in events do
		if e.t == t and (pred == nil or pred(e)) then
			return e
		end
	end
	return nil
end
