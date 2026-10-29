--[[
	PaintStore: authoritative paint state, with no Roblox dependencies so it can
	be unit tested.

	Each cell key maps to the ColorId that owns it and the time it was painted.
	Every color keeps a FIFO of (key, time) entries in paint order; the head of the
	FIFO is that color's oldest paint. That one structure gives us both rules:
	  * cap: a color past maxCells loses its oldest cells first
	  * decay: cells older than the lifetime are erased from the head
	Repainting a cell pushes a fresh entry; the old one goes stale and is skipped
	when it reaches the head.
]]

export type Queue = { keys: { number }, times: { number }, head: number, tail: number }

local PaintStore = {}
PaintStore.__index = PaintStore

export type PaintStore = typeof(setmetatable(
	{} :: {
		owner: { [number]: number },
		stamp: { [number]: number },
		count: { [number]: number },
		queues: { [number]: Queue },
		changes: { [number]: number },
		maxCells: number,
	},
	PaintStore
))

function PaintStore.new(maxCells: number): PaintStore
	local self = setmetatable({
		owner = {},
		stamp = {},
		count = {},
		queues = {},
		changes = {},
		maxCells = maxCells,
	}, PaintStore)
	return self
end

local function queueFor(self: PaintStore, color: number): Queue
	local q = self.queues[color]
	if not q then
		q = { keys = {}, times = {}, head = 1, tail = 0 }
		self.queues[color] = q
	end
	return q
end

local function push(q: Queue, key: number, t: number)
	q.tail += 1
	q.keys[q.tail] = key
	q.times[q.tail] = t
end

local function pop(q: Queue): (number, number)
	local key, t = q.keys[q.head], q.times[q.head]
	q.keys[q.head] = nil
	q.times[q.head] = nil
	q.head += 1
	if q.head > q.tail then
		q.head, q.tail = 1, 0
	end
	return key, t
end

function PaintStore.erase(self: PaintStore, key: number)
	local color = self.owner[key]
	if color == nil then
		return
	end
	self.owner[key] = nil
	self.stamp[key] = nil
	self.count[color] -= 1
	self.changes[key] = 0
end

-- Paints one cell. Returns true if the cell changed color.
function PaintStore.paint(self: PaintStore, key: number, color: number, now: number): boolean
	local previous = self.owner[key]
	self.stamp[key] = now
	push(queueFor(self, color), key, now)
	if previous == color then
		return false
	end
	if previous ~= nil then
		self.count[previous] -= 1
	end
	self.owner[key] = color
	self.count[color] = (self.count[color] or 0) + 1
	self.changes[key] = color

	local q = queueFor(self, color)
	while self.count[color] > self.maxCells and q.head <= q.tail do
		local oldKey, oldTime = pop(q)
		if self.owner[oldKey] == color and self.stamp[oldKey] == oldTime then
			self:erase(oldKey)
		end
	end
	return true
end

-- Erases every cell painted at or before now - lifetime.
function PaintStore.decay(self: PaintStore, now: number, lifetime: number)
	local cutoff = now - lifetime
	for color, q in self.queues do
		while q.head <= q.tail and q.times[q.head] <= cutoff do
			local key, t = pop(q)
			if self.owner[key] == color and self.stamp[key] == t then
				self:erase(key)
			end
		end
	end
end

function PaintStore.clearColor(self: PaintStore, color: number)
	local q = self.queues[color]
	if not q then
		return
	end
	while q.head <= q.tail do
		local key = pop(q)
		if self.owner[key] == color then
			self:erase(key)
		end
	end
	self.queues[color] = nil
end

-- Wipes everything. Pending changes are dropped: the caller broadcasts a clear.
function PaintStore.clearAll(self: PaintStore)
	self.owner = {}
	self.stamp = {}
	self.count = {}
	self.queues = {}
	self.changes = {}
end

function PaintStore.ownerOf(self: PaintStore, key: number): number?
	return self.owner[key]
end

function PaintStore.countOf(self: PaintStore, color: number): number
	return self.count[color] or 0
end

-- Returns and resets pending changes as parallel arrays (color 0 = erased).
function PaintStore.takeChanges(self: PaintStore): ({ number }, { number })
	local keys, colors = {}, {}
	for key, color in self.changes do
		table.insert(keys, key)
		table.insert(colors, color)
	end
	self.changes = {}
	return keys, colors
end

function PaintStore.snapshot(self: PaintStore): ({ number }, { number })
	local keys, colors = {}, {}
	for key, color in self.owner do
		table.insert(keys, key)
		table.insert(colors, color)
	end
	return keys, colors
end

return PaintStore
