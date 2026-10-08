--[[
	MemoryUtil
	Small, failure-tolerant wrappers around MemoryStoreService sorted maps.
	Every call is pcall'd and retried once; callers get (ok, result).
]]

local MemoryStoreService = game:GetService("MemoryStoreService")

local MemoryUtil = {}

local maps = {}
local failures = 0

function MemoryUtil.map(name: string): MemoryStoreSortedMap
	local m = maps[name]
	if not m then
		m = MemoryStoreService:GetSortedMap(name)
		maps[name] = m
	end
	return m
end

local function attempt(fn)
	local ok, result = pcall(fn)
	if not ok then
		task.wait(0.4)
		ok, result = pcall(fn)
	end
	if ok then
		failures = 0
	else
		failures += 1
		warn("[Trapisque] MemoryStore error: " .. tostring(result))
	end
	return ok, result
end

function MemoryUtil.get(mapName: string, key: string)
	return attempt(function()
		return MemoryUtil.map(mapName):GetAsync(key)
	end)
end

function MemoryUtil.set(mapName: string, key: string, value: any, ttl: number)
	return attempt(function()
		return MemoryUtil.map(mapName):SetAsync(key, value, ttl)
	end)
end

function MemoryUtil.remove(mapName: string, key: string)
	return attempt(function()
		return MemoryUtil.map(mapName):RemoveAsync(key)
	end)
end

-- transform(old) -> new value, or nil to cancel
function MemoryUtil.update(mapName: string, key: string, transform, ttl: number)
	return attempt(function()
		return MemoryUtil.map(mapName):UpdateAsync(key, transform, ttl)
	end)
end

-- Oldest-first list of { key, value } (up to `count`).
function MemoryUtil.range(mapName: string, count: number)
	return attempt(function()
		return MemoryUtil.map(mapName):GetRangeAsync(Enum.SortDirection.Ascending, count)
	end)
end

-- True when MemoryStore keeps failing (used to fall back to in-server queues).
function MemoryUtil.unhealthy(): boolean
	return failures >= 6
end

return MemoryUtil
