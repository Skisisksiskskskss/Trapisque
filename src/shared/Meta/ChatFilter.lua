--[[
	ChatFilter
	The game's own pass over a typed chat line, before Roblox's text filter (which every
	line still goes through, for each person who reads it). Roblox's filter lets mild
	meanness through and doesn't mind spam; this keeps the table friendly:

	  - insults ("idiot", "trash", "loser"...), even spelt l1ke th1s or s.p.a.c.e.d, are
	    hashed out, the way Roblox hashes what it filters
	  - links, handles and long numbers (ways to take a chat somewhere else) are hashed
	  - SHOUTING is brought down to normal case, and a letter held down (noooooooo) is
	    cut to three
	  - the same line twice in a row within a little while is refused

		ChatFilter.clean(text, recent?) -> text?, why?
	`recent` is the speaker's latest lines { { text, t } } (newest last) with t in
	seconds; on a refusal it returns nil and the reason to show them.
]]

local ChatFilter = {}

ChatFilter.RepeatSeconds = 20

-- Words that are only ever used to be mean (whole words, after undoing look-alikes).
ChatFilter.words = {
	"idiot", "idiots", "stupid", "dumb", "dumbo", "moron", "loser", "losers", "trash",
	"garbage", "noob", "noobs", "nub", "bozo", "clown", "ugly", "fatso", "cringe",
	"pathetic", "worthless", "useless", "kys", "stfu", "shutup", "hateyou", "uninstall",
	"braindead", "dumbass", "retard", "retarded", "freak", "weirdo", "suck", "sucks",
	"ez", "ezz", "ezpz",
}
local WORDS = {}
for _, w in ChatFilter.words do
	WORDS[w] = true
end
-- a few that take two words
ChatFilter.phrases = { "shut up", "hate you", "you suck", "go away", "get lost", "nobody likes you" }
-- where people go to talk off the game
local PLACES = { discord = true, dsc = true, insta = true, instagram = true, snap = true, snapchat = true, tiktok = true, whatsapp = true, telegram = true }

-- what look-alike characters stand for
local LOOKS = { ["0"] = "o", ["1"] = "i", ["3"] = "e", ["4"] = "a", ["5"] = "s", ["7"] = "t", ["8"] = "b", ["@"] = "a", ["$"] = "s", ["!"] = "i", ["|"] = "l" }

-- Runs of one character cut to `keep` ("noooo", 2 -> "noo").
local function squeeze(s: string, keep: number): string
	local out, last, run = {}, "", 0
	for c in string.gmatch(s, ".") do
		if c == last then
			run += 1
		else
			last, run = c, 1
		end
		if run <= keep then
			table.insert(out, c)
		end
	end
	return table.concat(out)
end

local function plain(word: string): string
	local s = string.lower(word)
	s = string.gsub(s, ".", function(c)
		return LOOKS[c] or c
	end)
	s = string.gsub(s, "[^%a]", "")
	-- "stuuupid" reads as "stupid"
	return squeeze(s, 1)
end

local function isMean(word: string): boolean
	local p = plain(word)
	if WORDS[p] then
		return true
	end
	-- doubled letters belong to some words ("idiot" has none, "noob" has two)
	local q = string.gsub(string.lower(word), "[^%w@$!|]", "")
	q = string.gsub(q, ".", function(c)
		return LOOKS[c] or c
	end)
	return WORDS[squeeze(q, 2)] == true
end

local function hash(s: string): string
	return string.rep("#", math.max(1, #s))
end

-- links, @handles, #tags and long numbers
local function isContact(word: string): boolean
	local w = string.lower(word)
	if string.find(w, "https?:") or string.find(w, "www%.") then
		return true
	end
	if string.find(w, "%w%.%a%a%a?$") or string.find(w, "%w%.%a%a%a?/") then
		return true
	end
	if string.find(w, "^@%w") or string.find(w, "#%d%d%d%d") then
		return true
	end
	if PLACES[string.gsub(w, "[^%a]", "")] or string.find(w, "discord") then
		return true
	end
	return string.find(w, "%d%d%d%d%d%d") ~= nil
end

function ChatFilter.clean(text: string, recent: { { text: string, t: number } }?, now: number?): (string?, string?)
	local s = string.gsub(text, "%s+", " ")
	s = string.match(s, "^%s*(.-)%s*$") or ""
	if s == "" then
		return nil, "Nothing to say."
	end
	-- a key held down: three is plenty
	s = squeeze(s, 3)
	-- shouting
	local upper = #string.gsub(s, "[^%u]", "")
	local letters = #string.gsub(s, "[^%a]", "")
	if letters >= 6 and upper / letters > 0.7 then
		s = string.upper(string.sub(s, 1, 1)) .. string.lower(string.sub(s, 2))
	end
	-- word by word
	s = string.gsub(s, "%S+", function(word)
		if isMean(word) or isContact(word) then
			return hash(word)
		end
		return word
	end)
	for _, phrase in ChatFilter.phrases do
		local lower = string.lower(s)
		local i, j = string.find(lower, phrase, 1, true)
		while i do
			s = string.sub(s, 1, i - 1) .. hash(string.sub(s, i, j)) .. string.sub(s, j + 1)
			lower = string.lower(s)
			i, j = string.find(lower, phrase, j + 1, true)
		end
	end
	-- letters spread out to slip past ("i d i o t", "s.t.u.p.i.d")
	local joined = string.gsub(string.lower(s), "[%s%._%-%*]", "")
	for w in WORDS do
		if #w >= 4 and string.find(plain(joined), w, 1, true) and not string.find(string.lower(s), w, 1, true) then
			local spread = true
			for _, word in string.split(s, " ") do
				if #word > 2 then
					spread = false
				end
			end
			if spread then
				s = hash(s)
				break
			end
		end
	end
	-- the same thing again, straight away
	if recent then
		local t = now or os.clock()
		for i = #recent, math.max(1, #recent - 1), -1 do
			local r = recent[i]
			if string.lower(r.text) == string.lower(s) and t - r.t < ChatFilter.RepeatSeconds then
				return nil, "You just said that!"
			end
		end
	end
	return s, nil
end

return ChatFilter
