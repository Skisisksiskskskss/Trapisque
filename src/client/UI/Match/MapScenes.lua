--[[
	MapScenes
	How each map looks: the winding route its tiles follow, the land it runs through, the
	colours, and the landmarks. Pure data (BoardLayout turns it into positions, MapArt
	draws it).

	Units are map units (about one tile radius). y runs down.

	path       points the trail passes through, Start first and the Treasure last; the
	           main-route tiles are spaced evenly along a smooth curve through them
	branches   extra bend points for each gated shortcut, between its two main tiles
	land       r: how far the land reaches either side of the trail; jitter: how ragged
	           the coast is (inner ground grows in patches away from the trail);
	           fill: water narrower than about twice this, between bends, becomes land;
	           add: extra land { x, y, r }
	islets     little islands { x, y, r } (none for now: a bare islet reads as a stray shape)
	props      what grows or stands around: { kind, weight } lists for the land and the
	           water, and how many to place on each (a few: the board is for playing on)
	landmarks  fixed props: { kind, x, y, size } or { kind, tile, dx, dy, size }; one that
	           doesn't fit (on the trail, a tile, the wrong side of the coast) is left out
	colors     the map's inks (the outline is always the UI's ink)
	tile       stone = round stepping stones, slab = square slabs turned along the trail
	lava       its lava tiles get lava streams (like rivers, in the scene's lava inks)
]]

local MapScenes = {}

MapScenes.blissful = {
	path = {
		{ 2.5, 12.8 }, { 5, 14.8 }, { 8.5, 15 }, { 11, 13.4 }, { 13.8, 14.8 }, { 17, 15.2 }, { 20.4, 14.2 },
		{ 22.8, 12 }, { 22.2, 9.2 }, { 19.6, 7.8 }, { 16.6, 9 }, { 13.6, 10.6 }, { 10.4, 9.8 }, { 8.2, 7.2 },
		{ 9.6, 4.2 }, { 13, 3 }, { 16.6, 4.2 }, { 19.8, 3 }, { 23.4, 2.8 }, { 26.6, 4.6 }, { 27.6, 8.2 },
		{ 26.8, 11.6 },
	},
	land = {
		r = 2.5,
		jitter = 0.12,
		beach = 1.05,
		fill = 3,
		add = {
			{ 16.4, 12.6, 1.9 }, { 19.6, 11.2, 1.6 }, { 6.6, 11.2, 1.7 }, { 12.2, 6.8, 1.9 },
			{ 15.6, 6.6, 1.6 }, { 24.6, 7.4, 1.7 }, { 23.4, 15.6, 1.4 },
		},
	},
	rivers = true,
	props = {
		land = { { "palm", 6 }, { "bush", 3 }, { "rock", 2 }, { "hut", 1 } },
		landCount = 6,
		water = { { "rock", 3 }, { "barrel", 1 }, { "gull", 2 } },
		waterCount = 2,
	},
	landmarks = {
		{ "dock", tile = 1, size = 3.2 },
		{ "ship", x = 6.2, y = 2.6, size = 3.8 },
		{ "wreck", x = 27.4, y = 16.4, size = 3 },
		{ "skullrock", x = 16.6, y = 12.2, size = 2.4 },
	},
	colors = {
		water = "#2A8FBF",
		waterMark = "#1F74A0",
		shallows = "#6CC9DB",
		land = "#F2C879",
		inner = "#4FA548",
		innerMark = "#3E8E41",
		trail = "#E2B06A",
		tile = "#FFF8E7",
		tileSide = "#D9A54A",
		number = "#A88B5E",
		start = "#7FD1E0",
	},
	tile = "stone",
}

MapScenes.junction = {
	path = {
		{ 1.6, 14.8 }, { 4.6, 15.9 }, { 8, 15.2 }, { 11.4, 15.8 }, { 15, 15.2 }, { 18.4, 16 }, { 21.6, 14.8 },
		{ 23, 12 }, { 21.8, 8 }, { 18.6, 8.2 }, { 15.6, 7 }, { 12.4, 8 }, { 9.2, 8.6 }, { 6, 8.8 },
		{ 3.4, 7.2 }, { 3, 4.8 }, { 5, 2.6 }, { 7.8, 2.8 }, { 9.6, 4.8 }, { 12.4, 4.8 }, { 15.4, 3 },
		{ 18.4, 1.4 }, { 21.8, 2.2 }, { 25, 1.4 }, { 27.8, 3.4 }, { 27.6, 6.8 }, { 26, 11 }, { 26.6, 14 },
		{ 28.2, 16 },
	},
	branches = {
		{ { 11.4, 12.2 } },
		{},
	},
	land = {
		r = 2.4,
		jitter = 0.12,
		beach = 0.95,
		fill = 1.5,
		add = {
			{ 16.6, 12.4, 2.6 }, { 6.2, 5.8, 1.9 }, { 24.4, 8.4, 1.8 }, { 13.6, 12.6, 1.5 },
			{ 30.4, 14.6, 1.9 },
		},
	},
	props = {
		land = { { "barrel", 4 }, { "crate", 4 }, { "torch", 3 }, { "cannon", 2 }, { "rock", 1 } },
		landCount = 6,
		water = { { "rock", 4 }, { "barrel", 1 } },
		waterCount = 2,
	},
	landmarks = {
		{ "dock", tile = 1, size = 3 },
		{ "keep", x = 30.5, y = 14.2, size = 2.6 },
		{ "ship", x = 4, y = 18.6, size = 3.8 },
		{ "flag", x = 16.8, y = 12.4, size = 2 },
	},
	gates = true,
	tunnels = true,
	colors = {
		water = "#1D5E80",
		waterMark = "#174C68",
		shallows = "#3F86A0",
		land = "#A39B8B",
		inner = "#6E685E",
		innerMark = "#5E5A52",
		trail = "#CFC3A6",
		tunnel = "#2A2836",
		tile = "#F2EAD8",
		tileSide = "#8C8476",
		number = "#8C8476",
		start = "#7FB6C9",
	},
	tile = "slab",
}

MapScenes.slimy = {
	path = {
		{ 2.4, 13.2 }, { 4.6, 15.4 }, { 8, 15.2 }, { 11.2, 16 }, { 14.6, 15 }, { 18, 15.6 }, { 21.2, 14.6 },
		{ 23.4, 12.2 }, { 23, 9 }, { 23.8, 5.8 }, { 22, 3.2 }, { 18.6, 2.6 }, { 15.4, 3.4 }, { 12.2, 2.4 },
		{ 8.8, 2.8 }, { 5.8, 3.4 }, { 3.8, 5.8 }, { 4.2, 8.8 }, { 6.6, 10.6 }, { 9.8, 11.6 }, { 13.2, 12 },
		{ 16.6, 11.2 }, { 19, 9 }, { 18.4, 6.4 }, { 15.2, 6.4 }, { 12, 7.4 }, { 10.2, 7.6 },
	},
	land = {
		r = 2.2,
		jitter = 0.12,
		beach = 0.9,
		fill = 2,
		add = { { 13.6, 9.4, 1.4 }, { 7.6, 6.6, 1.5 } },
	},
	pools = true,
	props = {
		land = { { "mangrove", 4 }, { "reeds", 4 }, { "log", 2 }, { "stump", 2 } },
		landCount = 6,
		water = { { "lily", 6 }, { "reeds", 2 } },
		waterCount = 2,
	},
	landmarks = {
		{ "dock", tile = 1, size = 3 },
		{ "sunken", x = 27.2, y = 9.6, size = 3.2 },
		{ "deadtree", x = 13.4, y = 9.2, size = 2.2 },
	},
	colors = {
		water = "#3D6E5C",
		waterMark = "#2F5A4B",
		shallows = "#5F927A",
		land = "#8A7442",
		inner = "#55803A",
		innerMark = "#466C30",
		trail = "#B87333",
		trailMark = "#7A4A1F",
		pool = "#9BCF2E",
		tile = "#EBC48F",
		tileSide = "#7A4A1F",
		number = "#9C6B3A",
		start = "#B8D98A",
	},
	tile = "slab",
}

MapScenes.haunted = {
	path = {
		{ 2.4, 15.6 }, { 5.5, 16.6 }, { 9, 16 }, { 12.5, 16.8 }, { 16, 16 }, { 19.5, 16.8 }, { 23, 16 }, { 26, 14.6 },
		{ 27, 11.8 }, { 24.5, 10 }, { 21, 10.8 }, { 17.5, 9.8 }, { 14, 10.6 }, { 10.5, 9.6 }, { 7, 10.4 }, { 4, 9.2 },
		{ 3.2, 6.4 }, { 5.6, 4.4 }, { 9, 4.8 }, { 12.5, 3.8 }, { 16, 4.6 }, { 19.5, 3.6 }, { 23, 4.4 }, { 25.6, 3.6 },
		{ 27.4, 5.6 },
	},
	land = {
		r = 2.4,
		jitter = 0.12,
		beach = 0.9,
		fill = 2.4,
		add = { { 30.2, 8.8, 2.2 }, { 14.6, 13.4, 1.6 }, { 9.4, 7.2, 1.5 }, { 20.6, 7.2, 1.5 } },
	},
	props = {
		land = { { "grave", 6 }, { "pumpkin", 3 }, { "deadtree", 2 }, { "lamp", 2 }, { "fence", 2 }, { "rock", 1 } },
		landCount = 6,
		water = { { "rock", 4 }, { "mist", 3 }, { "barrel", 1 } },
		waterCount = 2,
	},
	landmarks = {
		{ "dock", tile = 1, size = 3 },
		{ "crypt", x = 30.2, y = 8.8, size = 2.8 },
		{ "ghostship", x = 6.6, y = 19.6, size = 3.8 },
		{ "deadtree", x = 14.6, y = 13.4, size = 2.2 },
	},
	colors = {
		water = "#1E3A55",
		waterMark = "#172E45",
		shallows = "#2F5674",
		land = "#7A7F6A",
		inner = "#46603E",
		innerMark = "#3A5134",
		trail = "#A99B82",
		tile = "#ECE6D4",
		tileSide = "#8C8476",
		number = "#8C8476",
		start = "#9FB8C9",
	},
	tile = "slab",
}

MapScenes.volcano = {
	path = {
		{ 2.4, 16.4 }, { 5.8, 17.6 }, { 9.4, 16.6 }, { 13, 17.8 }, { 16.6, 16.6 }, { 20.2, 17.8 }, { 23.8, 16.8 }, { 26.6, 15 },
		{ 26.8, 12.4 }, { 24, 11.2 }, { 20.6, 12.4 }, { 17, 11.2 }, { 13.4, 12.4 }, { 9.8, 11.2 }, { 6.4, 12.2 }, { 3.4, 11.2 },
		{ 2.6, 8.4 }, { 4.6, 6 }, { 8, 6.8 }, { 11.6, 5.6 }, { 15.2, 6.8 }, { 18.6, 5.6 }, { 21.4, 3.4 }, { 21.6, 1.2 },
	},
	land = {
		r = 2.4,
		jitter = 0.12,
		beach = 0.9,
		fill = 2.4,
		add = { { 27.2, 6.4, 3.6 }, { 24.4, 7.4, 2.2 }, { 15, 14.4, 1.4 } },
	},
	lava = true,
	props = {
		land = { { "palm", 3 }, { "lavarock", 4 }, { "charred", 3 }, { "vent", 2 }, { "rock", 2 } },
		landCount = 6,
		water = { { "rock", 4 }, { "barrel", 1 }, { "gull", 1 } },
		waterCount = 2,
	},
	landmarks = {
		{ "dock", tile = 1, size = 3 },
		{ "volcano", x = 27.2, y = 6.6, size = 5.2 },
		{ "ship", x = 9, y = 1.4, size = 3.6 },
	},
	colors = {
		water = "#24839F",
		waterMark = "#1C6A82",
		shallows = "#58B7C9",
		land = "#6B5A50",
		inner = "#4A3E38",
		innerMark = "#3A302C",
		trail = "#D4B088",
		tile = "#F4E6CC",
		tileSide = "#8A6A4A",
		number = "#8A6A4A",
		start = "#7FD1E0",
		lava = "#F2541B",
		lavaGlow = "#FFB000",
		lavaCrust = "#7A1E0C",
	},
	tile = "stone",
}

return MapScenes
