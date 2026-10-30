-- Map layout tests: the tiles follow their winding route without touching, and nothing
-- drawn around the trail (props, rivers) lands on it. The map is seen a little from the
-- side, so a standing prop reaches up the screen from its foot: what it may cover is
-- checked on screen (BoardLayout.toScreen).
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
					for _, s in L.trail do
						truthy(segDist(p.x, p.y, s.x1, s.y1, s.x2, s.y2) >= S.trailW / 2 + p.size * S.foot - EPS, p.kind .. " stands on the trail")
					end
					local sx, sy = BoardLayout.toScreen(p.x, p.y)
					for j, q in L.props do
						if j > i and not q.ground then
							local qx, qy = BoardLayout.toScreen(q.x, q.y)
							truthy(dist(sx, sy, qx, qy) >= (p.size + q.size) * S.reach * 0.9 - EPS, p.kind .. " stands in " .. q.kind)
						end
					end
					-- one that stands in front of a tile never hides it (or whoever is on it)
					local a0, b0, a1, b1 = BoardLayout.inkBox(sx, sy, p.size)
					for _, t in L.tiles do
						truthy(dist(p.x, p.y, t.x, t.y) >= S.tileR * (t.scale or 1) + p.size * S.foot - EPS, string.format("%s stands on tile %d", p.kind, t.id))
						local tx, ty = BoardLayout.toScreen(t.x, t.y)
						if ty <= sy then
							truthy(not BoardLayout.overlaps(a0, b0, a1, b1, BoardLayout.tileBox(tx, ty, t.scale)), string.format("%s hides tile %d", p.kind, t.id))
						end
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

		test(name .. ": every prop is wholly in view; the ground's little things lie on the land, off the trail", function()
			local v = L.view
			for _, p in L.props do
				if not p.ground then
					local sx, sy = BoardLayout.toScreen(p.x, p.y)
					local a0, b0, a1, b1 = BoardLayout.inkBox(sx, sy, p.size)
					truthy(a0 >= v.x0 - EPS and a1 <= v.x1 + EPS and b0 >= v.y0 - EPS and b1 <= v.y1 + EPS, p.kind .. " is cut off by the edge of the view")
				end
			end
			for _, d in L.details do
				truthy(L.landDepth(d.x, d.y) > 0.5, d.kind .. " lies in the water")
				for _, s in L.trail do
					truthy(segDist(d.x, d.y, s.x1, s.y1, s.x2, s.y2) >= S.trailW / 2 + 0.3, d.kind .. " lies on the trail")
				end
			end
			if MapScenes[def.id].details then
				truthy(#L.details >= 6, "expected a few things on the ground, got " .. #L.details)
			end
		end)

		test(name .. ": the camera box holds every tile and whoever stands on it, the map holds everything", function()
			local v = L.view
			for _, t in L.tiles do
				local x0, y0, x1, y1 = BoardLayout.tileBox(BoardLayout.toScreen(t.x, t.y))
				truthy(x0 >= v.x0 and x1 <= v.x1 and y0 >= v.y0 and y1 <= v.y1, "tile " .. t.id .. " outside the camera box")
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

test("an art sheet's upload is used only while it's of the sheet's current version", function()
	local Art = requireModule("Client/UI/Art")
	local versions = { scenery_1 = "abc" }
	eq(Art.uploadedId("scenery_1", { scenery_1 = { id = 5, version = "abc" } }, versions), 5)
	eq(Art.uploadedId("scenery_1", { scenery_1 = { id = 5, version = "old" } }, versions), nil, "an upload of older art isn't used")
	eq(Art.uploadedId("scenery_1", { scenery_1 = { id = 0, version = "abc" } }, versions), nil, "not uploaded")
	eq(Art.uploadedId("scenery_1", { scenery_1 = 7 }, versions), 7, "an id written in by hand, without its version")
	eq(Art.uploadedId("scenery_1", {}, versions), nil)
end)

test("pasted art ids: read from text or links, matched to their sheets by name, then by order", function()
	local ArtIds = requireModule("Shared/ArtIds")
	local ids = ArtIds.parse("123456\nhttps://www.roblox.com/library/7654321/scenery-1, 12 and 9988776655")
	eq(#ids, 3)
	eq(ids[1], 123456)
	eq(ids[2], 7654321)
	eq(ids[3], 9988776655)
	local sheets = { "scenery_1", "scenery_2", "icons_1" }
	eq(ArtIds.sheetNamed("Images/scenery_1", sheets), "scenery_1")
	eq(ArtIds.sheetNamed("scenery_2.png", sheets), "scenery_2")
	eq(ArtIds.sheetNamed("Trapisque icons_1", sheets), "icons_1")
	eq(ArtIds.sheetNamed("scenery_10", sheets), nil, "scenery_10 isn't scenery_1")
	eq(ArtIds.sheetNamed("my decal", sheets), nil)
	-- named ones go to their sheets, the rest in the order given
	local m = ArtIds.match({ { image = 3, name = "icons_1" }, { image = 1, name = "Decal" }, { image = 2 } }, sheets)
	eq(m.icons_1, 3)
	eq(m.scenery_1, 1)
	eq(m.scenery_2, 2)
	-- the same sheet named twice: the second fills a free one
	m = ArtIds.match({ { image = 5, name = "scenery_2" }, { image = 6, name = "scenery_2" } }, sheets)
	eq(m.scenery_2, 5)
	eq(m.scenery_1, 6)
	-- the note asked for icons_1 only: an id whose name doesn't say goes there, never to a
	-- sheet that already has its upload (a name that does say still counts)
	m = ArtIds.match({ { image = 7, name = "Decal" }, { image = 8, name = "scenery_2" } }, sheets, { "icons_1" })
	eq(m.icons_1, 7)
	eq(m.scenery_1, nil, "an unnamed id was taken for a sheet the note didn't ask for")
	eq(m.scenery_2, 8)
end)

test("the owner's pasted uploads come before the place's own, and only while current", function()
	local Art = requireModule("Client/UI/Art")
	local ArtAtlas = requireModule("Client/UI/ArtAtlas")
	local sheet = ArtAtlas.sheets[1]
	local before = Art.uploadedId(sheet)
	truthy(Art.setUploads({ [sheet] = { id = 4242, version = "000000000000" } }), "a new upload is a change")
	eq(Art.uploadedId(sheet), before, "an upload of older art isn't used")
	truthy(Art.setUploads({ [sheet] = { id = 4242, version = ArtAtlas.versions[sheet] } }))
	eq(Art.uploadedId(sheet), 4242)
	falsy(Art.setUploads({ [sheet] = { id = 4242, version = ArtAtlas.versions[sheet] } }), "the same again is no change")
	falsy(Art.setUploads("nonsense"))
	Art.setUploads({ [sheet] = { id = 0, version = ArtAtlas.versions[sheet] } })
	eq(Art.uploadedId(sheet), before)
end)

test("every art sheet has a version and an upload entry, and one without a current upload ships its pixels", function()
	local Art = requireModule("Client/UI/Art")
	local ArtAtlas = requireModule("Client/UI/ArtAtlas")
	local ArtAssets = requireModule("Client/UI/ArtAssets")
	for _, sheet in ArtAtlas.sheets do
		local version = ArtAtlas.versions[sheet]
		truthy(type(version) == "string" and #version == 12, sheet .. " has no version")
		local entry = ArtAssets[sheet]
		truthy(type(entry) == "table" and type(entry.id) == "number" and type(entry.version) == "string", sheet .. " isn't in ArtAssets")
		if not Art.uploadedId(sheet) then
			truthy(rawget(getNode("Client/UI/ArtData/" .. sheet), "__module"), sheet .. " has neither a current upload nor its pixels")
		end
	end
end)

test("every dice skin, trail, catch, chest and status mark has its art in the sheets", function()
	local ArtAtlas = requireModule("Client/UI/ArtAtlas")
	local Cosmetics = requireModule("Shared/Meta/Cosmetics")
	local Fishing = requireModule("Shared/Meta/Fishing")
	local Gacha = requireModule("Shared/Meta/Gacha")
	for _, def in Cosmetics.byCategory.dice do
		local skin = string.gsub(def.id, "^dice_", "")
		local group = if ArtAtlas.sprites["dice/" .. skin] then "dice/" else "dice_more/"
		truthy(ArtAtlas.sprites[group .. skin], "no die for " .. def.id)
		truthy(ArtAtlas.sprites[group .. skin .. "_pip"], "no pip for " .. def.id)
	end
	for _, def in Cosmetics.byCategory.trail do
		if def.look.kind ~= "none" then
			truthy(ArtAtlas.sprites["trails/" .. def.look.kind .. "_1"], "no particles for " .. def.id)
		end
	end
	for _, c in Fishing.catches do
		truthy(ArtAtlas.sprites["fish/" .. c.id], "no art for the " .. c.id)
	end
	for _, chest in Gacha.chests do
		truthy(chest.look.art, chest.id .. " has no art name")
		truthy(ArtAtlas.sprites["chests/" .. chest.look.art .. "_base"] and ArtAtlas.sprites["chests/" .. chest.look.art .. "_lid"], "no art for the " .. chest.id)
	end
	for _, name in { "flame", "ice", "poster", "poster_gold", "zzz" } do
		truthy(ArtAtlas.sprites["marks/" .. name], "no marks/" .. name)
	end
	for _, name in { "water", "bobber", "ripple", "splash", "rod" } do
		truthy(ArtAtlas.sprites["fishing/" .. name], "no fishing/" .. name)
	end
	-- the effects borrow two of the trails' particles
	truthy(ArtAtlas.sprites["trails/bolt_1"] and ArtAtlas.sprites["trails/snow_1"])
end)

test("the art added later is on sheets of its own, so the uploaded ones keep their ids", function()
	local ArtAtlas = requireModule("Client/UI/ArtAtlas")
	local ArtAssets = requireModule("Client/UI/ArtAssets")
	local old = { scenery = true, pieces = true, icons = true }
	for name, sp in ArtAtlas.sprites do
		local group = string.match(name, "^([^/]+)/")
		local run = string.match(sp.sheet, "^(%a+)_")
		if group == "dice" or group == "trails" or group == "fishing" or group == "chests" or group == "marks" or group == "fish" then
			falsy(old[run], name .. " is on " .. sp.sheet)
		end
	end
	-- (and the sheets already uploaded are still of the version they were uploaded at)
	for sheet, entry in ArtAssets do
		if type(entry) == "table" and entry.id > 0 then
			eq(entry.version, ArtAtlas.versions[sheet], sheet .. "'s upload is out of date")
		end
	end
end)

test("every prop, ground sprite, piece, stand, emblem, card badge and Kraken frame has its art in the sheets", function()
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
	for _, scene in MapScenes do
		if type(scene) == "table" and scene.details then
			for _, w in scene.details.kinds do
				truthy(ArtAtlas.sprites["ground/" .. w[1]], "no art for the " .. w[1] .. " on the ground")
			end
		end
	end
	for _, name in { "soft", "wave", "stone", "slab", "disc", "rsq", "ring" } do
		truthy(ArtAtlas.sprites["ground/" .. name], "no ground/" .. name)
	end
	for _, id in Characters.ids do
		truthy(ArtAtlas.sprites["pieces/plinth_" .. id], "no stand for the " .. id)
		for _, def in Cosmetics.byCategory.finish do
			truthy(ArtAtlas.sprites["pieces/" .. def.look.finish .. "_" .. id], "no " .. def.id .. " " .. id)
		end
	end
	truthy(ArtAtlas.sprites["pieces/plinth_gold"], "no gold stand")
	-- every emblem a character can wear, every card's badge, every token's
	for _, def in Cosmetics.byCategory.emblem do
		local char, set = string.match(def.look.emblem, "^([%w_]+):([%w_]+)$")
		local name = if char then "emblems/" .. char .. "_" .. set else "emblems/" .. def.look.emblem
		truthy(ArtAtlas.sprites[name] or (char and ArtAtlas.sprites["emblems_more/" .. char .. "_" .. set]), "no art for the " .. def.id)
	end
	local ItemList = requireModule("Shared/Game/Items")
	for _, def in ItemList.list do
		truthy(ArtAtlas.sprites["cards/" .. def.id], "no badge for the " .. def.id .. " card")
	end
	for _, kind in { "trap", "assist", "neutral", "potion", "coin" } do
		truthy(ArtAtlas.sprites["cards/token_" .. kind], "no badge for the " .. kind .. " token")
	end
	-- the Kraken's frames: rising, swaying, rearing, arching and slamming every way, and
	-- its lair (the swirl, its head, the arms arching round it)
	for k = 0, 2 do
		truthy(ArtAtlas.sprites["kraken/rise_" .. k], "no rise_" .. k)
	end
	for k = 0, 5 do
		truthy(ArtAtlas.sprites["kraken/arm_" .. k], "no arm_" .. k)
	end
	for k = 0, 7 do
		truthy(ArtAtlas.sprites["kraken/arc_" .. k], "no arc_" .. k)
		truthy(ArtAtlas.sprites["kraken/hit_" .. k], "no hit_" .. k)
	end
	for _, name in { "rear_l", "rear_r", "swirl_0", "swirl_1", "swirl_2", "swirl_3", "head_ahead", "head_left", "head_right", "head_blink", "head_angry", "coil_0", "coil_1" } do
		truthy(ArtAtlas.sprites["kraken/" .. name], "no kraken/" .. name)
	end
	-- what the board shows on a tile: every card placed on it, every map feature (and
	-- the newest maps' cracked ice, open water, cogs and drawbridges), the Start, the
	-- treasure, a gated shortcut, embers. A tile turns into a face, in both tile shapes;
	-- a thing stands on it, turned to face the trail if it does
	local Items = requireModule("Shared/Game/Items")
	local Board = requireModule("Shared/Game/Board")
	local need = { start = true, treasure = true, shortcutGate = true, embers = true, thinice_cracked = true, hole = true, cog = true, deck = true, gap = true }
	for _, def in Items.list do
		if def.use == "place" then
			need[def.id] = true
		end
	end
	for _, def in Maps.list do
		for _, kind in Board.get(def).naturalInit do
			need[kind] = true
		end
	end
	for kind in need do
		local look = BoardLayout.TileLooks[kind]
		truthy(look, "nothing to show for " .. kind .. " on a tile")
		if look and look.face then
			for _, shape in { "round", "square" } do
				truthy(ArtAtlas.sprites["tiles/" .. look.face .. "_" .. shape], "no tiles/" .. look.face .. "_" .. shape)
			end
		elseif look then
			truthy(ArtAtlas.sprites["items/" .. look.stand], "no items/" .. look.stand)
			if look.facing then
				for k = 0, 7 do
					local turn = BoardLayout.facingTurn(k * 22.5 - 90)
					truthy(ArtAtlas.sprites["tiles/" .. look.stand .. "_" .. turn], "no tiles/" .. look.stand .. "_" .. turn)
				end
			end
		end
	end
	for k = 0, 15 do
		truthy(ArtAtlas.sprites["tiles/leaf_" .. k], "no raised drawbridge leaf " .. k)
	end
	for name, sp in ArtAtlas.sprites do
		truthy(table.find(ArtAtlas.sheets, sp.sheet), name .. "'s sheet isn't listed")
		truthy(sp.x >= 0 and sp.y >= 0 and sp.x + sp.w <= 1024 and sp.y + sp.h <= 1024, name .. " runs off its sheet")
		truthy(sp.ox >= 0 and sp.oy >= 0 and sp.ox + sp.w <= sp.ow and sp.oy + sp.h <= sp.oh, name .. " runs off its canvas")
	end
end)
