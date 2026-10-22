-- Map layout tests: the tiles follow their winding route without touching, and nothing
-- drawn around the trail (props, rivers) lands on it.
local Maps = requireModule("Shared/Game/Maps")
local Board = requireModule("Shared/Game/Board")
local Rng = requireModule("Shared/Game/Rng")
local BoardLayout = requireModule("Client/UI/Match/BoardLayout")
local MapScenes = requireModule("Client/UI/Match/MapScenes")

local S = BoardLayout.Style
local EPS = 1e-6

local function dist(ax, ay, bx, by)
	return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- distance from (px, py) to the segment (ax, ay)-(bx, by)
local function segDist(px, py, ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	local len2 = dx * dx + dy * dy
	local t = if len2 < 1e-12 then 0 else math.clamp(((px - ax) * dx + (py - ay) * dy) / len2, 0, 1)
	return dist(px, py, ax + dx * t, ay + dy * t)
end

for _, def in Maps.list do
	for _, rotate in { false, true } do
		local board = Board.get(def)
		local L = BoardLayout.build(board, def, Rng, { rotate = rotate })
		local name = def.id .. (if rotate then " (upright)" else "")
		local byId = {}
		for _, t in L.tiles do
			byId[t.id] = t
		end
		local linked = {}
		for id, list in board.forward do
			for _, to in list do
				linked[id .. ":" .. to] = true
				linked[to .. ":" .. id] = true
			end
		end

		test(name .. ": every tile is on the map, evenly spaced along its route", function()
			eq(#L.tiles, board.totalTiles, "tiles")
			for id, list in board.forward do
				for _, to in list do
					local a, b = byId[id], byId[to]
					local d = dist(a.x, a.y, b.x, b.y)
					truthy(d >= 1.6 and d <= 2.9, string.format("tiles %d and %d are %.2f apart", id, to, d))
				end
			end
		end)

		test(name .. ": tiles that aren't next to each other never touch", function()
			for i, a in L.tiles do
				for j, b in L.tiles do
					if j > i and not linked[a.id .. ":" .. b.id] then
						local d = dist(a.x, a.y, b.x, b.y)
						local need = S.tileR * ((a.scale or 1) + (b.scale or 1)) + 0.5
						truthy(d >= need, string.format("tiles %d and %d are only %.2f apart", a.id, b.id, d))
					end
				end
			end
		end)

		test(name .. ": props stand clear of the trail, the tiles and each other", function()
			truthy(#L.props >= 6 and #L.props <= 14, "expected a few props, not a cluttered map: got " .. #L.props)
			for i, p in L.props do
				truthy(MapScenes ~= nil and p.size > 0, "prop size")
				if not p.ground then
					local reach = p.size * S.reach
					for _, s in L.trail do
						truthy(segDist(p.x, p.y, s.x1, s.y1, s.x2, s.y2) >= S.trailW / 2 + reach - EPS, p.kind .. " stands on the trail")
					end
					for j, q in L.props do
						if j > i and not q.ground then
							truthy(dist(p.x, p.y, q.x, q.y) >= reach + q.size * S.reach - EPS, p.kind .. " overlaps " .. q.kind)
						end
					end
				end
				if not p.ground then
					for _, t in L.tiles do
						local d = dist(p.x, p.y, t.x, t.y)
						truthy(d >= S.tileR * (t.scale or 1) + p.size * 0.3, string.format("%s covers tile %d", p.kind, t.id))
					end
				end
			end
		end)

		test(name .. ": rivers run through their tile and out to sea or into a pond", function()
			for _, r in L.rivers do
				local t = byId[r.tile]
				local through = false
				for _, q in r.points do
					if dist(q[1], q[2], t.x, t.y) < 0.01 then
						through = true
					end
				end
				truthy(through, "river misses tile " .. r.tile)
				truthy(#r.points >= 4, "river at " .. r.tile .. " is a stub")
				truthy(r.endA == "sea" or r.endB == "sea", "river at " .. r.tile .. " never reaches the sea")
			end
			if MapScenes[def.id].rivers then
				eq(#L.rivers, 2, "rivers")
			end
		end)

		test(name .. ": the camera box holds every tile, the map holds everything", function()
			local box = L.tileBounds
			for _, t in L.tiles do
				truthy(t.x - S.tileR >= box.x0 and t.x + S.tileR <= box.x1 and t.y - S.tileR >= box.y0 and t.y + S.tileR <= box.y1, "tile " .. t.id .. " outside the camera box")
			end
			local x1, y1 = L.x0 + L.w, L.y0 + L.h
			for _, c in L.land do
				truthy(c.x - c.r >= L.x0 and c.x + c.r <= x1 and c.y - c.r >= L.y0 and c.y + c.r <= y1, "land outside the map")
			end
		end)
	end
end

test("the scenes' routes are as long as their maps need", function()
	for _, def in Maps.list do
		local board = Board.get(def)
		local L = BoardLayout.build(board, def, Rng)
		truthy(L.spacing >= 1.85 and L.spacing <= 2.15, string.format("%s: tiles %.2f apart", def.id, L.spacing))
	end
end)

test("shared-tile pawn slots never overlap and stay on the tile", function()
	for n, layout in BoardLayout.PawnSlots do
		local r = S.pawn * layout.scale * S.pawnDisc / 2
		eq(#layout, n, "slot count")
		for i, a in ipairs(layout) do
			truthy(math.abs(a[1]) + r <= S.tileR + 0.01, "slot " .. n .. "/" .. i .. " leaves the tile")
			for j, b in ipairs(layout) do
				if j > i then
					truthy(dist(a[1], a[2], b[1], b[2]) >= 2 * r - 0.01, "slots " .. n .. ":" .. i .. "/" .. j .. " overlap")
				end
			end
		end
	end
end)

test("smoothing fills the corner where two discs meet, and stays out of the water", function()
	local discs = { { x = 0, y = 0, r = 2 }, { x = 3, y = 0, r = 2 } }
	local fill = BoardLayout.fillets(discs, 1, { 0 })[1]
	truthy(#fill > 0, "corners filled")
	-- the ball that rolls into each corner sits 3 from both centres; nothing fills it
	local qy = math.sqrt(9 - 2.25)
	for _, c in fill do
		for _, side in { 1, -1 } do
			truthy(dist(c.x, c.y, 1.5, side * qy) >= 1 + c.r - 1e-6, "a fill disc pokes into the water")
		end
	end
	-- and each corner's tip, where the two circles cross, is covered
	local py = math.sqrt(4 - 2.25)
	for _, side in { 1, -1 } do
		local covered = false
		for _, c in fill do
			covered = covered or dist(c.x, c.y, 1.5, side * py) < c.r
		end
		truthy(covered, "the corner's tip is left open")
	end
end)

test("smoothing plugs the hole left where three discs nearly meet", function()
	local discs = { { x = 0, y = 0, r = 1.05 }, { x = 2, y = 0, r = 1.05 }, { x = 1, y = math.sqrt(3), r = 1.05 } }
	local cx, cy = 1, math.sqrt(3) / 3
	for _, c in discs do
		truthy(dist(cx, cy, c.x, c.y) > c.r, "the middle is a hole to begin with")
	end
	local covered = false
	for _, c in BoardLayout.fillets(discs, 1, { 0 })[1] do
		covered = covered or dist(cx, cy, c.x, c.y) < c.r
	end
	truthy(covered, "the hole is still open")
end)

test("every prop, piece, stand and portrait has its art in the sheets", function()
	local ArtAtlas = requireModule("Client/UI/ArtAtlas")
	local Cosmetics = requireModule("Shared/Meta/Cosmetics")
	local Characters = requireModule("Shared/Game/Characters")
	local kinds = {}
	for _, scene in MapScenes do
		if type(scene) == "table" and scene.props then
			for _, list in { scene.props.land or {}, scene.props.water or {} } do
				for _, w in list do
					kinds[w[1]] = true
				end
			end
			if scene.props.grove then
				kinds[scene.props.grove] = true
			end
			for _, m in scene.landmarks or {} do
				kinds[m[1]] = true
			end
		end
	end
	for kind in kinds do
		truthy(ArtAtlas.sprites["props/" .. kind], "no art for the " .. kind)
	end
	for _, id in Characters.ids do
		truthy(ArtAtlas.sprites["portraits/" .. id], "no portrait of the " .. id)
		truthy(ArtAtlas.sprites["pieces/plinth_" .. id], "no stand for the " .. id)
		for _, def in Cosmetics.byCategory.finish do
			truthy(ArtAtlas.sprites["pieces/" .. def.look.finish .. "_" .. id], "no " .. def.id .. " " .. id)
		end
	end
	truthy(ArtAtlas.sprites["pieces/plinth_gold"], "no gold stand")
	for name, sp in ArtAtlas.sprites do
		truthy(table.find(ArtAtlas.sheets, sp.sheet), name .. "'s sheet isn't listed")
		truthy(sp.x >= 0 and sp.y >= 0 and sp.x + sp.w <= 1024 and sp.y + sp.h <= 1024, name .. " runs off its sheet")
		truthy(sp.ox >= 0 and sp.oy >= 0 and sp.ox + sp.w <= sp.ow and sp.oy + sp.h <= sp.oh, name .. " runs off its canvas")
	end
end)
