--[[
	Smoke test: the whole game, server and client, on the fake Roblox (tests/fake).

	A scripted player joins, looks around the lobby (every menu page, the quests, the
	character picker, the chests), starts a practice match against bots and plays it to
	the end with the real controls: on a PC it hovers and picks dice with Q / W / E,
	plays cards with the number keys and clicks the glowing tile when a card needs one,
	and uses its ability with Space; on a phone it taps everything instead (a die twice,
	a card and then PLAY, a tile and then the confirm button). It shops at the Potion
	Seller and answers every pop-up. Then it checks the results reached the screen and
	the profile, and that it got back to the lobby.

	Any Lua error in any thread, any warning, and any table Roblox would mangle on its
	way through a remote or into a DataStore fails the run.

	Bundle with tools/bundle.py --all, with a scenario file (SMOKE = {...}) first:
		SMOKE = { name, w, h, touch, safe, inset, barLeft, barRight, mode, bots, length,
		          map, character, seed, verbose }
	tools/smoke.sh runs every scenario.
]]

local F = Fake
local cfg = SMOKE or {}
F.verbose = cfg.verbose == true
local rng = Random.new(cfg.seed or 7)

-- the game's folders, where Roblox would have them
F.mount(F.ReplicatedStorage, "Shared", getNode("Shared"))
F.mount(game:GetService("ServerScriptService"), "Server", getNode("Server"))
F.mount(game:GetService("ReplicatedFirst"), "First", getNode("First"))
-- the tester is the game's owner (the owner panel gets a look too); not in store
-- screenshots, where an OWNER badge on a player's bubble would look odd
if cfg.store then
	requireModule("Shared/Config").Staff.StudioIsOwner = false
else
	requireModule("Shared/Config").Staff.OwnerIds = { 4242 }
end
-- MessagingService never answers (as in Studio with an unpublished place): the game
-- must still let everyone in
F.messagingHangs = true
-- screenshots draw the image art from the sheet files (art/sheets); plain smoke runs
-- keep the code-built art, as when Roblox can't build the sheets (the fake has no
-- EditableImage)
requireModule("Client/UI/Art").localSheets = cfg.shots == true
requireModule("Client/UI/Art").builtIn = false

F.setScreen({
	w = cfg.w or 1280,
	h = cfg.h or 720,
	touch = cfg.touch,
	safe = cfg.safe,
	inset = cfg.inset,
	barLeft = cfg.barLeft,
	barRight = cfg.barRight,
})
local touch = cfg.touch == true

local stats = {
	posters = 0, -- Wanted posters seen going up
	moves = 0,
	cards = 0,
	abilities = 0,
	tiles = 0,
	picks = 0,
	buys = 0,
	refused = 0,
	pages = 0,
	turns = 0,
}
local function say(fmt, ...)
	if F.verbose then
		F.print("[smoke] " .. string.format(fmt, ...))
	end
end

-- cfg.shots: screenshots along the way (tests/fake/shots.luau, tools/preview/shot.py)
local shotsTaken = {}
local function shot(name: string)
	if cfg.shots and F.shot and not shotsTaken[name] then
		shotsTaken[name] = true
		F.shot((cfg.name or "smoke") .. "-" .. name)
	end
end

local function fail(msg: string)
	error("[" .. (cfg.name or "smoke") .. "] " .. msg .. "\n" .. F.problems(), 0)
end

local function check(cond, msg: string)
	if not cond then
		fail(msg)
	end
end

local function noProblems(stage: string)
	local p = F.problems()
	if p ~= "" then
		fail("problems after " .. stage .. ":\n" .. p)
	end
end

---------------------------------------------------------------------------
-- finding things on screen
---------------------------------------------------------------------------

local function visibleNamed(root, name: string)
	for _, d in F.findAll(root, function(d)
		return d.Name == name and F.visible(d)
	end) do
		return d
	end
	return nil
end

-- The button a player would press for this widget: itself, or the first button in it.
local function buttonIn(inst)
	if inst:IsA("GuiButton") then
		return inst
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("GuiButton") and F.visible(d) then
			return d
		end
	end
	return nil
end

local function press(root, pattern: string): boolean
	local list = F.buttons(root, pattern)
	if #list == 0 then
		return false
	end
	F.click(list[1])
	return true
end

-- Like press, scrolling through `root`'s scrolling lists until the button shows up.
local function pressScrolled(root, pattern: string): boolean
	if press(root, pattern) then
		return true
	end
	for _, sf in F.findAll(root, function(d)
		return d:IsA("ScrollingFrame") and F.visible(d)
	end) do
		local y = 0
		while y < sf.AbsoluteCanvasSize.Y do
			y += math.max(40, sf.AbsoluteSize.Y * 0.6)
			sf.CanvasPosition = Vector2.new(0, y)
			F.run(0.1)
			if press(root, pattern) then
				return true
			end
		end
	end
	return false
end

---------------------------------------------------------------------------
-- boot: the server, then the player joins and their scripts run
---------------------------------------------------------------------------

F.spawn(function()
	requireModule("Server/Main")
end)
F.run(1)
noProblems("server start")

local player = F.addPlayer(cfg.player or "Tester", 4242)
F.run(0.5)
F.spawn(function()
	requireModule("First/Loading")
end)
F.spawn(function()
	requireModule("Client/Main")
end)

-- store screenshots: everyone wears their character's portrait (the fake has no
-- avatar headshots to show)
if cfg.store then
	local Avatars = requireModule("Client/UI/Avatars")
	local StateModule = requireModule("Client/State")
	Avatars.headshot = function()
		return nil
	end
	local portrait = Avatars.portrait
	Avatars.portrait = function(parent, info, props, opts)
		local i = table.clone(info or {})
		if not i.character then
			local p = StateModule.get("profile")
			i.character = if i.userId == 4242 and p then p.character else "mage"
		end
		return portrait(parent, i, props, opts)
	end
end

local playerGui = player:FindFirstChild("PlayerGui")
local MatchScreen = requireModule("Client/UI/Match/MatchScreen")
-- every event the match screen plays, by kind (the newest maps' own ones are checked)
local screenEvents: { [string]: number } = {}
do
	local play = MatchScreen._play
	MatchScreen._play = function(self, e)
		screenEvents[e.t] = (screenEvents[e.t] or 0) + 1
		return play(self, e)
	end
end
local Root = requireModule("Client/UI/Root")
local State = requireModule("Client/State")
local Widgets = requireModule("Client/UI/Widgets")
local Net = requireModule("Client/Net")
local Items = requireModule("Shared/Game/Items")

-- every toast, and every command the screen sends
local toasts = {}
local realToast = Widgets.toast
Widgets.toast = function(text, kind, ...)
	table.insert(toasts, { text = tostring(text), kind = kind, t = F.now })
	say("toast (%s): %s", tostring(kind), tostring(text))
	return realToast(text, kind, ...)
end
local commands = {}
local realRequest = Net.request
Net.request = function(action, payload)
	local ok, data = realRequest(action, payload)
	if action == "match.cmd" then
		table.insert(commands, { cmd = payload.cmd, ok = ok, err = if ok then nil else data, t = F.now })
		if not ok then
			stats.refused += 1
		end
		say("cmd %s %s -> %s %s", payload.cmd.type, tostring(payload.cmd.die or payload.cmd.item or payload.cmd.option or ""), tostring(ok), if ok then "" else tostring(data))
	end
	return ok, data
end

check(F.run(20, function()
	return State.get("profile") ~= nil and Root.currentName() == "lobby"
end), "the lobby never showed up")
F.run(3)
check(playerGui:FindFirstChild("TrapisqueLoading") == nil, "the loading screen never went away")
noProblems("joining")
say("lobby up at %.1fs", F.now)
shot("lobby")

---------------------------------------------------------------------------
-- the lobby
---------------------------------------------------------------------------

-- Open dialogs (Widgets.modal backdrops), oldest first.
local function modals()
	local out = F.findAll(Root.gui, function(d)
		return d.Name == "Modal" and d:IsA("GuiButton") and F.visible(d)
	end)
	table.sort(out, function(a, b)
		return F.state(a).id < F.state(b).id
	end)
	return out
end

local function closeModals()
	for _ = 1, 4 do
		local list = modals()
		if #list == 0 then
			return
		end
		F.click(list[#list])
		F.run(0.5)
	end
end

local function openNav(id: string): boolean
	local item = visibleNamed(Root.screens, id)
	if not item then
		return false
	end
	local b = buttonIn(item)
	if not b then
		return false
	end
	local before = #modals()
	F.click(b)
	F.run(1.2)
	stats.pages += 1
	return #modals() > before
end

-- every page from the menu, with a few of the things on it
local PAGES = {
	{ id = "chests", try = { "SEE ODDS" } },
	{ id = "quests", try = { "SWAP" } },
	{ id = "locker", try = {} },
	{ id = "shop", try = {} },
	{ id = "leaders", try = {} },
	{ id = "rules", try = {} },
	{ id = "settings", try = {} },
}
for _, page in PAGES do
	local opened = openNav(page.id)
	if opened then
		for _, pattern in page.try do
			local top = modals()
			if press(top[#top], pattern) then
				F.run(1.5)
			end
		end
		F.run(0.6)
		shot("page-" .. page.id)
		-- page tabs and pagers (How to Play, Top Players)
		local top = modals()
		if top[#top] then
			for _, b in F.buttons(top[#top]) do
				local text = F.textOf(b):upper()
				if text:find("NEXT") or text:find("WINS") or text:find("LEVEL") then
					F.click(b)
					F.run(0.6)
				end
			end
		end
		closeModals()
		say("page %s ok", page.id)
	else
		say("page %s: no button on this screen", page.id)
	end
	noProblems("the " .. page.id .. " page")
end

-- the chat: a quick line from the chat window, one with it closed (a bubble drops in
-- under the button), then the owner panel gives me the Chat pass and I type a line
local Chat = requireModule("Client/Chat")
do
	local button = visibleNamed(Root.screens, "Chat")
	check(button ~= nil, "no chat button in the lobby")
	F.click(buttonIn(button))
	F.run(1)
	local top = modals()
	check(top[#top] ~= nil, "the chat window didn't open")
	check(press(top[#top], "^AHOY!$"), "no quick lines in the chat window")
	F.run(1.5)
	check(#Chat.history() >= 1, "my quick line never came back from the server")
	shot("chat")
	closeModals()
	F.spawn(Net.request, "chat.send", { quick = "nice" })
	F.run(1)
	local bubbles = visibleNamed(Root.screens, "ChatBubbles")
	check(bubbles ~= nil and #bubbles:GetChildren() >= 2, "no chat bubble under the chat button")
	shot("chat-bubble")
	F.run(10)
	noProblems("the lobby chat")

	if not cfg.store then
		check(openNav("settings"), "Settings didn't open")
		top = modals()
		check(press(top[#top], "OWNER PANEL"), "the owner has no OWNER PANEL button in Settings")
		F.run(2)
		top = modals()
		for _, tab in { "FIND", "SERVER", "ADMINS", "BANS", "LOG", "PLAYERS" } do
			check(press(top[#top], "^" .. tab .. "$"), "no " .. tab .. " tab in the owner panel")
			F.run(0.8)
		end
		shot("owner-panel")
		check(press(top[#top], "^MANAGE$"), "no MANAGE button on the owner panel's players")
		F.run(1.2)
		local sheet = modals()
		shot("owner-sheet")
		-- (offline every pass reads as bought, so it may already say ON)
		check(pressScrolled(sheet[#sheet], "^GIVE CHAT$") or pressScrolled(sheet[#sheet], "^CHAT: ON$"), "no Chat pass button on a player's sheet")
		F.run(1.5)
		check(pressScrolled(sheet[#sheet], "^%+100 GEMS$"), "no +100 GEMS button on a player's sheet")
		F.run(1.5)
		closeModals()
		check(State.hasPass("Chat"), "the owner panel didn't give the Chat pass")
		noProblems("the owner panel")
	end

	F.click(buttonIn(visibleNamed(Root.screens, "Chat")))
	F.run(1)
	top = modals()
	local box = F.findAll(top[#top], function(d)
		return d:IsA("TextBox")
	end)[1]
	check(box ~= nil, "no text box in the chat window with the Chat pass")
	box.Text = "Ahoy from the smoke test"
	check(press(top[#top], "^SEND$"), "no SEND button in the chat window")
	F.run(1.5)
	local last = Chat.history()[#Chat.history()]
	check(last ~= nil and last.text == "Ahoy from the smoke test", "my typed line never came back")
	closeModals()
	F.run(1)
	noProblems("typing in the chat")
end

-- open a chest with the starting gems, through the reveal
do
	if openNav("chests") then
		local top = modals()
		local opened = false
		-- the free chest if there is one, else the first one with a price
		for _, b in F.buttons(top[#top], "OPEN FREE") do
			if not opened then
				F.click(b)
				opened = true
			end
		end
		for _, b in F.buttons(top[#top]) do
			if not opened and F.textOf(b):match("^%d") then
				F.click(b)
				opened = true
			end
		end
		if opened then
			F.run(12, function()
				return #F.buttons(Root.gui, "^COLLECT$") > 0
			end)
			F.run(0.6)
			shot("chest-reveal")
			press(Root.gui, "^COLLECT$")
			F.run(1.5)
		end
		closeModals()
		-- the reveal can still be on its way: wait for it and collect it
		if F.run(15, function()
			return #F.buttons(Root.gui, "^COLLECT$") > 0
		end) then
			F.run(0.6)
			shot("chest-reveal")
			press(Root.gui, "^COLLECT$")
			F.run(1.5)
		end
	end
	noProblems("opening a chest")
end

-- the character picker
local character = cfg.character
do
	local strip = visibleNamed(Root.screens, "YourCharacter")
	if strip then
		F.click(buttonIn(strip))
		F.run(1.2)
		local top = modals()
		shot("characters")
		if top[#top] then
			local picks = F.buttons(top[#top], "^PICK$")
			if character then
				for _, b in picks do
					local card = b.Parent
					local found = false
					while card and not found do
						if F.textOf(card):upper():find(character:upper()) then
							found = true
						else
							card = card.Parent
						end
					end
					if found then
						F.click(b)
						break
					end
				end
			elseif #picks > 0 then
				F.click(picks[rng:NextInteger(1, #picks)])
			end
			F.run(1)
		end
		closeModals()
	end
	noProblems("picking a character")
	local profile = State.get("profile")
	say("character: %s", tostring(profile and profile.character))
end

-- the owner's unlock-all switch (offline, the tester is the owner; not in the store
-- screenshots): a locked character can be picked while it's on, and switching it off
-- goes back to real progress
if not cfg.store then
	local before = State.get("profile").character
	local function ask(list)
		local done = false
		local results = {}
		F.spawn(function()
			for i, r in list do
				results[i] = Net.request(r[1], r[2])
			end
			done = true
		end)
		check(F.run(5, function()
			return done
		end), "the unlock-all requests never came back")
		F.run(0.5)
		return results
	end
	local r = ask({ { "owner.unlockAll", { on = true } }, { "character.select", { character = "cannoneer" } } })
	local profile = State.get("profile")
	check(r[1] == true and r[2] == true and profile.unlockAll == true and profile.character == "cannoneer", "unlock-all didn't let the owner pick a locked character")
	r = ask({ { "owner.unlockAll", { on = false } } })
	profile = State.get("profile")
	check(r[1] == true and profile.unlockAll == false and profile.character ~= "cannoneer", "switching unlock-all off didn't go back to real progress")
	ask({ { "character.select", { character = before } } })
	check(State.get("profile").character == before, "couldn't go back to the character picked before")
	noProblems("the unlock-all switch")
end

---------------------------------------------------------------------------
-- a practice match
---------------------------------------------------------------------------

-- what the lobby costs per frame, to compare with after the match
F.run(3)
local lobbyLoad = F.load()
local lobbyCount = F.count(Root.gui)
say("lobby load: %d frame connections, %d tweens, %d waiting threads, %d GUI objects", lobbyLoad.frameConns, lobbyLoad.tweens, lobbyLoad.waiting, lobbyCount)

local mode = cfg.mode or "chaos"
if cfg.tutorial then
	-- the guided first match, from How to Play
	check(openNav("rules"), "the rules page didn't open")
	local top = modals()
	check(press(top[#top], "GUIDED MATCH"), "no GUIDED MATCH button")
elseif cfg.quickplay then
	-- Quick Play: queue, and bots fill the empty seats after a while
	local tile = visibleNamed(Root.screens, mode)
	check(tile ~= nil, "no tile for mode " .. mode)
	F.click(buttonIn(tile))
	F.run(0.5)
	check(press(Root.screens, "FIND A MATCH"), "no FIND A MATCH button")
	F.run(3)
	local q = State.get("queue")
	check(q ~= nil and q.state == "searching", "not searching after FIND A MATCH")
	check(F.run(150, function()
		return MatchScreen.current() ~= nil
	end), "Quick Play never found a match")
elseif cfg.private then
	-- a private match: a party of one plus bots, house rules, a roulette map vote
	local function switchFor(root, note: string): boolean
		for _, d in F.findAll(root, function(d)
			return d:IsA("TextLabel") and d.Text == note and F.visible(d)
		end) do
			local holder = d.Parent
			for _ = 1, 3 do
				local t = holder and holder:FindFirstChild("Toggle")
				if t then
					F.click(t)
					return true
				end
				holder = holder and holder.Parent
			end
		end
		return false
	end
	check(press(Root.screens, "CREATE PARTY"), "no CREATE PARTY button")
	check(F.run(5, function()
		return State.get("party") ~= nil
	end), "the party was never made")
	check(press(Root.screens, "PRIVATE"), "no PRIVATE MATCH button")
	F.run(1)
	local top = modals()
	local panel = top[#top]
	check(panel ~= nil, "the private match settings didn't open")
	check(press(panel, "^ROULETTE$"), "no Roulette map vote")
	F.run(0.3)
	check(switchFor(panel, "A map with a random twist among the cards"), "no twist card switch")
	F.run(0.3)
	shot("private-match")
	check(press(panel, "^HOUSE RULES$"), "no House rules tab")
	F.run(0.3)
	check(press(panel, "^SHORT$"), "no Short board")
	check(press(panel, "^3$"), "no 3 starting cards")
	check(switchFor(panel, "Characters' abilities and the Power bar"), "no abilities switch")
	F.run(0.3)
	shot("private-rules")
	check(press(panel, "^CARDS$"), "no Cards tab")
	F.run(0.3)
	check(press(panel, "BANANA"), "no Banana Peel to ban")
	F.run(0.5)
	shot("private-bans")
	local rules = State.get("party").settings.rules
	check(rules.vote == "roulette" and rules.wildcard == true, "the vote settings weren't saved")
	check(rules.board == "short" and rules.cards == 3 and rules.abilities == false, "the house rules weren't saved")
	check(rules.banned.banana == true, "the ban wasn't saved")
	check(press(panel, "START MATCH"), "no START MATCH button")
	-- the vote: four cards (two maps, the Mystery map, a map with a twist); vote for the last
	local vote
	check(F.run(10, function()
		vote = visibleNamed(Root.gui, "MapVote")
		return vote ~= nil
	end), "the map vote never opened")
	F.run(0.6)
	local card = visibleNamed(vote, "Option4")
	check(card ~= nil, "no twist card in the vote")
	check(visibleNamed(vote, "Twist") ~= nil, "the twist card has no twist on it")
	F.click(card)
	F.run(1)
	shot("private-vote")
	check(F.run(20, function()
		return visibleNamed(Root.gui, "Roulette") ~= nil or MatchScreen.current() ~= nil
	end), "the roulette never spun")
	F.run(1.2)
	shot("private-roulette")
else
	local tile = visibleNamed(Root.screens, mode)
	check(tile ~= nil, "no tile for mode " .. mode)
	F.click(buttonIn(tile))
	F.run(0.5)
	check(press(Root.screens, "^PRACTICE$") or press(Root.screens, "PRACTICE"), "no PRACTICE button")
	F.run(1)
	local top = modals()
	check(top[#top] ~= nil, "the practice settings didn't open")
	local panel = top[#top]
	if cfg.map then
		check(press(panel, "^" .. cfg.map:upper() .. "$"), "no button for the map " .. cfg.map)
	end
	press(panel, "^" .. (cfg.length or "Quick"):upper() .. "$")
	if cfg.bots then
		press(panel, "^" .. tostring(cfg.bots) .. "$")
	end
	F.run(0.3)
	check(press(panel, "START"), "no START button")
end

check(F.run(15, function()
	return MatchScreen.current() ~= nil
end), "the match never started")
local screen = MatchScreen.current()
say("match started at %.1fs (seat %d, %s)", F.now, screen.mySeat, screen.mapDef.id)
if cfg.map and not cfg.private then
	check(screen.mapDef.name == cfg.map, "the match is on " .. tostring(screen.mapDef.name) .. ", not " .. cfg.map)
end
noProblems("starting the match")
if cfg.private then
	check(screen.boardKind == "short", "the match isn't on a short board")
	check(screen.houseRules ~= nil, "the match doesn't know its house rules")
	check(screen.twist ~= nil, "the twist card won, but the match has no twist")
	-- the connection drops mid-match: the seat is kept (the match waits: nobody else is
	-- in it), and it's handed back when they're back on the server
	F.run(6)
	local MatchService = requireModule("Server/MatchService")
	local me = game:GetService("Players").LocalPlayer
	local match = MatchService.get(me)
	check(match ~= nil, "the server has no match for me")
	F.removePlayer(me)
	F.run(3)
	check(match:heldSeat(me.UserId) ~= nil, "my seat wasn't kept when my connection dropped")
	check(not match.closed, "the match closed when I dropped out")
	F.reconnect(me)
	check(F.run(20, function()
		return MatchService.get(me) == match
	end), "I never got my seat back")
	check(F.run(10, function()
		local s = MatchScreen.current()
		return s ~= nil and s ~= screen
	end), "the match screen didn't come back after rejoining")
	screen = MatchScreen.current()
	check(not screen.view.players[screen.mySeat].isBot, "I'm still a bot after rejoining")
	say("rejoined at %.1fs", F.now)
	noProblems("rejoining after a dropped connection")
end
if cfg.tutorial then
	check(screen.coach ~= nil, "no coach in the guided match")
	check(F.run(10, function()
		return screen.coach.root.Visible
	end), "the coach never spoke")
	shot("tutorial-coach")
end

-- say something: the say button, a quick line, a bubble over my character
do
	F.run(3)
	local sayButton = visibleNamed(Root.screens, "emote")
	check(sayButton ~= nil, "no say button in the match")
	F.click(buttonIn(sayButton))
	F.run(1)
	local top = modals()
	check(top[#top] ~= nil, "the say window didn't open")
	check(press(top[#top], "^GOOD LUCK!$"), "no quick lines in the match's say window")
	F.run(1)
	check(screen.board.bubbles[screen.mySeat] ~= nil, "my line didn't pop up over my character")
	shot("match-bubble")
	closeModals()
	noProblems("saying something in the match")
end

-- The player's hands: one decision every so often, like a person.
local nextThink = F.now + 2
local lastTurn = nil
local lastPoster = nil
-- cfg.idle: touch nothing until the screen says a bot is playing for me, then come back
local idle = cfg.idle == true
local idleRound = nil
local sawAway = false
local function think()
	if F.now < nextThink then
		return
	end
	nextThink = F.now + 0.35 + rng:NextNumber() * 0.4
	local s = MatchScreen.current()
	if not s or not s.alive then
		return
	end
	if s.awayBar then
		if not sawAway then
			say("away bar up at %.1fs", F.now)
		end
		sawAway = true
		idle = false
		press(s.awayBar, "BACK")
		return
	end
	if idle then
		if s.view.current == s.mySeat and s.view.round ~= idleRound then
			idleRound = s.view.round
			say("idle through my turn in round %d", s.view.round)
		end
		return
	end

	-- pop-ups first: the shop, a card to pick, a direction, a choice
	local top = modals()
	local panel = top[#top]
	if not panel and #F.buttons(s.popups) > 0 then
		panel = s.popups -- an overlay that isn't a dialog (Scavenge's pick)
	end
	if panel then
		local buttons = F.buttons(panel)
		local options = {}
		for _, b in buttons do
			local text = F.textOf(b):upper()
			-- (a greyed-out button does nothing: Fill Power on a full bar)
			if text ~= "" and b.Active and not text:find("CLOSE") and not text:find("LEAVE") and not text:find("MENU") then
				table.insert(options, { b = b, text = text })
			end
		end
		-- shop: buy one thing now and then, then finish
		for _, o in options do
			if o.text:find("DONE SHOPPING") then
				local buys = {}
				for _, x in options do
					if x.text:match("^%d") then
						table.insert(buys, x)
					end
				end
				if #buys > 0 and rng:NextNumber() < 0.5 then
					F.click(buys[rng:NextInteger(1, #buys)].b)
					stats.buys += 1
				else
					F.click(o.b)
				end
				return
			end
		end
		if #options > 0 then
			local o = options[rng:NextInteger(1, #options)]
			say("pop-up: %s", o.text)
			F.click(o.b)
			if o.text:find("TAKE") then
				stats.picks += 1
			end
			return
		end
		-- nothing useful in it: close it
		for _, b in buttons do
			if F.textOf(b):upper():find("CLOSE") then
				F.click(b)
				return
			end
		end
		if panel ~= s.popups then
			F.click(panel)
		end
		return
	end

	-- a card or ability waiting for a target
	if s.targeting then
		local h = s.board._highlight
		if h and #h.tiles > 0 then
			local tile = h.tiles[rng:NextInteger(1, #h.tiles)]
			local hit = s.board.hits[tile]
			F.click(hit)
			stats.tiles += 1
			if touch then
				F.run(0.3)
				-- the confirm button in the hint strip across the board
				local hint = s.root:FindFirstChild("Hint")
				say("tile %d tapped; hint %s", tile, if hint then F.whyHidden(hint) else "missing")
				if hint and F.visible(hint) then
					for _, b in F.buttons(hint) do
						say("  hint button: %s", F.textOf(b))
					end
					for _, b in F.buttons(hint) do
						local text = F.textOf(b):upper()
						if not text:find("CANCEL") then
							F.click(b)
							break
						end
					end
				end
			end
			return
		end
		if s.chips.pickable then
			local seats = {}
			for seat in s.chips.pickable do
				table.insert(seats, seat)
			end
			if #seats > 0 then
				F.click(s.chips.chips[seats[rng:NextInteger(1, #seats)]].root)
				return
			end
		end
		return
	end

	if not s:_myTurn() then
		return
	end
	if lastTurn ~= s.view.round then
		lastTurn = s.view.round
		stats.turns += 1
		-- (a Wanted poster on someone, and its mark over their piece)
		local w = s.view.wanted
		local poster = if w then (w.seat .. (if w.most then "!" else "")) else nil
		if poster and poster ~= lastPoster then
			stats.posters += 1
			local pawn = s.board and s.board.pawns[w.seat]
			check(pawn ~= nil and pawn.lift:FindFirstChild("Wanted") ~= nil, "the Wanted has no poster on their piece")
		end
		lastPoster = poster
	end
	local me = s.view.players[s.mySeat]
	local roll = rng:NextNumber()

	-- a card now and then (one a turn)
	local ids = s.hand:ids()
	if #ids > 0 and (s.view.cardsPlayed or 0) == 0 and roll < 0.45 then
		local i = rng:NextInteger(1, #ids)
		local def = Items.get(ids[i])
		if def and def.use ~= "passive" then
			say("card %s", ids[i])
			stats.cards += 1
			if touch then
				local entry = s.hand.list[i]
				local hit = nil
				for _, d in entry.card.root:GetChildren() do
					if d:IsA("TextButton") then
						hit = d
					end
				end
				if hit then
					F.click(hit)
					F.run(0.4)
					-- the card's action buttons in its tip
					for _, b in F.buttons(s.root) do
						local text = F.textOf(b):upper()
						local verb = text:find("^PLAY") or text:find("^HIDE") or text:find("^PLACE") or text:find("^USE") or text:find("^THROW") or text:find("^FILL")
						if verb and b.Active then
							F.click(b)
							break
						end
					end
				end
			else
				F.key(Enum.KeyCode.One.EnumType:FromName(({ "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" })[i]))
			end
			return
		end
	end

	-- the ability once the bar is full
	local cost = me and me.powerCost or nil
	if me and me.power and s.dock and s.dock.powerInfo and s.dock.powerInfo.usable and roll < 0.8 then
		say("ability")
		stats.abilities += 1
		if touch then
			local b = visibleNamed(s.root, "AbilityButton")
			if b then
				F.click(b)
			end
		else
			F.key(Enum.KeyCode.Space)
		end
		return
	end
	local _ = cost

	-- move: look at a die or two, then go
	local dice = s.view.dice or {}
	if #dice == 0 then
		return
	end
	local keys = {}
	for i in dice do
		table.insert(keys, i)
	end
	local pickIndex = keys[rng:NextInteger(1, #keys)]
	local w = s.dock.dieWidgets and s.dock.dieWidgets[pickIndex]
	if touch then
		if w then
			F.click(w.button)
			F.run(0.3)
			if stats.turns >= 4 then
				shot("match")
			end
			F.click(w.button)
			stats.moves += 1
		end
	else
		for _, k in keys do
			local dw = s.dock.dieWidgets and s.dock.dieWidgets[k]
			if dw then
				F.hover(dw.button, true)
				F.run(0.1)
				if stats.turns >= 4 and k == keys[#keys] then
					shot("match")
				end
				F.hover(dw.button, false)
			end
		end
		local key = ({ Enum.KeyCode.Q, Enum.KeyCode.W, Enum.KeyCode.E })[pickIndex]
		F.key(key)
		stats.moves += 1
	end
end
table.insert(F.onFrame, think)

local finished = F.run(cfg.matchTime or 2400, function()
	local s = MatchScreen.current()
	return s ~= nil and s.view.phase == "over"
end)
if not finished then
	local standing = {}
	for seat, p in screen.view.players do
		table.insert(standing, string.format("seat %d: tile %s, %s treasures", seat, tostring(p.tile), tostring(p.treasures)))
	end
	fail(string.format("the match didn't finish in time (round %s, phase %s)\n%s", tostring(screen.view.round), tostring(screen.view.phase), table.concat(standing, "\n")))
end
say("match over at %.1fs: %d moves, %d cards, %d abilities, %d tiles, %d buys, %d refused", F.now, stats.moves, stats.cards, stats.abilities, stats.tiles, stats.buys, stats.refused)
noProblems("the match")
-- (the screen's autopilot stops here: the results are pressed below, on purpose)
table.remove(F.onFrame, table.find(F.onFrame, think))
if cfg.tutorial then
	-- the guided match is scripted for a first win
	local me = screen:_player(screen.mySeat)
	check(me ~= nil and (me.treasures or 0) >= (screen.target or 1), "the guided match wasn't won: " .. tostring(me and me.treasures) .. " treasures")
end

-- the results, then back to the lobby
check(F.run(12, function()
	return #F.buttons(Root.gui, "^LOBBY") > 0
end), "the results never showed a LOBBY button")
F.run(3)
shot("results")
if cfg.tutorial then
	check(#F.buttons(Root.gui, "^REMATCH") == 0, "the guided match offers a rematch")
	press(Root.gui, "^LOBBY")
else
	-- a rematch: with nobody else at the table it starts at once, the same table again
	check(press(Root.gui, "^REMATCH$"), "the results have no REMATCH button")
	local again = F.run(15, function()
		local s = MatchScreen.current()
		return s ~= nil and s ~= screen
	end)
	check(again, "REMATCH didn't start a new match")
	if again then
		local s = MatchScreen.current()
		check(s.mapDef == screen.mapDef and s.mode == screen.mode, "the rematch changed the map or the mode")
		F.run(3)
		task.spawn(Net.request, "match.leave")
	else
		press(Root.gui, "^LOBBY")
	end
end
check(F.run(20, function()
	return Root.currentName() == "lobby"
end), "never got back to the lobby")
F.run(3)
noProblems("going back to the lobby")

-- nothing from the match keeps running
F.run(5)
local after = F.load()
local afterCount = F.count(Root.gui)
say("after the match: %d frame connections, %d tweens, %d waiting threads, %d GUI objects", after.frameConns, after.tweens, after.waiting, afterCount)
check(after.frameConns <= lobbyLoad.frameConns, string.format("frame connections grew from %d to %d after the match (something from the match still runs every frame)", lobbyLoad.frameConns, after.frameConns))
check(after.looping <= lobbyLoad.looping, string.format("looping tweens grew from %d to %d after the match", lobbyLoad.looping, after.looping))
check(afterCount <= lobbyCount * 1.25 + 50, string.format("the lobby has %d GUI objects after the match, %d before", afterCount, lobbyCount))

-- the profile saw the match
local profile = State.get("profile")
check(profile ~= nil and profile.stats ~= nil and (profile.stats.games or 0) + (profile.stats.practice or 0) >= 1, "the profile doesn't count the match")
if cfg.tutorial then
	check(profile.tutorialDone == true, "the guided match didn't count as done")
end
local played = screen.view.players[screen.mySeat].character
check((profile.mastery and profile.mastery[played] or 0) > 0, "no mastery for " .. tostring(played) .. " after playing them")

if cfg.idle then
	check(sawAway, "idle for the whole match and the screen never said a bot was playing for me")
end

-- the UI really played: every one of my turns was a command from the screen
local moves = 0
for _, c in commands do
	if c.cmd.type == "move" and c.ok then
		moves += 1
	end
end
check(moves >= 3, "the screen sent only " .. moves .. " moves")
-- and never offered something the server then refused
for _, c in commands do
	if not c.ok then
		local fields = {}
		for k, v in c.cmd do
			table.insert(fields, tostring(k) .. "=" .. tostring(v))
		end
		table.sort(fields)
		fail(string.format("the server refused a %s command the screen sent at %.1fs (%s): %s", c.cmd.type, c.t, table.concat(fields, ", "), tostring(c.err)))
	end
end

local summary = string.format(
	"%s: %d turns, %d moves, %d cards, %d abilities, %d tile clicks, %d picks, %d buys, %d refused commands, %d pages, %d toasts, %d Wanted posters, %.0fs of game time",
	cfg.name or "smoke",
	stats.turns,
	moves,
	stats.cards,
	stats.abilities,
	stats.tiles,
	stats.picks,
	stats.buys,
	stats.refused,
	stats.pages,
	#toasts,
	stats.posters,
	F.now
)
F.print(summary)
-- the newest maps' hazards turned up, and played
local MAP_EVENTS = { frostbite = { "ice" }, kraken = { "krakenMark", "krakenSlam" }, clockwork = { "bridge" } }
local mapId = screen and screen.mapDef and screen.mapDef.id
local seen = {}
for _, kind in { "ice", "refreeze", "krakenMark", "krakenSlam", "grabbed", "bridge", "gears" } do
	if (screenEvents[kind] or 0) > 0 then
		table.insert(seen, kind .. " x" .. screenEvents[kind])
	end
end
if #seen > 0 then
	F.print("  map events: " .. table.concat(seen, ", "))
end
for _, kind in MAP_EVENTS[mapId] or {} do
	check((screenEvents[kind] or 0) > 0, "no " .. kind .. " event in a match on " .. tostring(mapId))
end
for _, t in toasts do
	if t.kind == "error" then
		F.print("  error toast: " .. t.text)
	end
end
