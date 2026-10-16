--[[
	Speech
	Turns a chat line into words a text-to-speech voice reads well, before Voice.lua
	speaks it:
	  numbers become words      "12" -> "twelve", "3rd" -> "third", "50%" -> "fifty
	                            percent", "2v2" -> "two versus two", "x2" -> "times two"
	  chat slang is spelled     "gg" -> "gee gee", "ez" -> "ee zee", "brb" -> "be right
	  out or said in full       back", "u" -> "you", "pls" -> "please"
	  letter-words are spelled  "NPC" -> "en pee see", "XP" -> "ex pee"
	  symbols are said or       "&" -> "and", "<3" -> "heart", ":)" dropped,
	  dropped                   "!!!" -> "!", "sooooo" -> "soo"

		Speech.normalize(text) -> string
		Speech.number(n) -> string      12 -> "twelve"
]]

local Speech = {}

local ONES = {
	"one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
	"eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
}
local TENS = { "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety" }
local DIGITS = { [0] = "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" }

local LETTERS = {
	a = "ay", b = "bee", c = "see", d = "dee", e = "ee", f = "eff", g = "gee", h = "aitch",
	i = "eye", j = "jay", k = "kay", l = "el", m = "em", n = "en", o = "oh", p = "pee",
	q = "cue", r = "ar", s = "ess", t = "tee", u = "you", v = "vee", w = "double you",
	x = "ex", y = "why", z = "zee",
}

-- chat words, said the way people say them
local SLANG = {
	gg = "gee gee",
	ggs = "gee gees",
	ggwp = "gee gee, well played",
	ez = "ee zee",
	ezz = "ee zee",
	gl = "good luck",
	hf = "have fun",
	glhf = "good luck, have fun",
	wp = "well played",
	gj = "good job",
	np = "no problem",
	ty = "thank you",
	tysm = "thank you so much",
	thx = "thanks",
	thnx = "thanks",
	thanx = "thanks",
	pls = "please",
	plz = "please",
	u = "you",
	ur = "your",
	r = "are",
	y = "why",
	k = "okay",
	kk = "okay",
	ok = "okay",
	lol = "el oh el",
	lmao = "el mao",
	omg = "oh em gee",
	idk = "I don't know",
	brb = "be right back",
	afk = "ay eff kay",
	gtg = "got to go",
	g2g = "got to go",
	btw = "by the way",
	imo = "in my opinion",
	tbh = "to be honest",
	ngl = "not gonna lie",
	smh = "ess em aitch",
	rn = "right now",
	bc = "because",
	cuz = "because",
	coz = "because",
	nvm = "never mind",
	wdym = "what do you mean",
	xd = "ex dee",
	op = "oh pee",
	pvp = "pee vee pee",
	npc = "en pee see",
	xp = "ex pee",
	irl = "in real life",
	fr = "for real",
	ikr = "I know, right",
	wb = "welcome back",
	gm = "good morning",
	gn = "good night",
	hbu = "how about you",
	wyd = "what are you doing",
	bro = "bro",
	w = "dub",
}

-- sounds that are fine as they are, though they're capitals with no vowel
local SOUNDS = { hm = true, hmm = true, mm = true, mhm = true, sh = true, shh = true, psst = true, grr = true, brr = true, tsk = true, pfft = true }

local function below1000(n: number): string
	local parts = {}
	if n >= 100 then
		table.insert(parts, ONES[n // 100] .. " hundred")
		n %= 100
	end
	if n >= 20 then
		local t = TENS[n // 10]
		if n % 10 > 0 then
			t ..= "-" .. ONES[n % 10]
		end
		table.insert(parts, t)
	elseif n > 0 then
		table.insert(parts, ONES[n])
	end
	return table.concat(parts, " ")
end

-- A whole number in words (up to the billions; longer ones are read digit by digit).
function Speech.number(n: number): string
	n = math.floor(n)
	if n == 0 then
		return "zero"
	end
	if n < 0 then
		return "minus " .. Speech.number(-n)
	end
	if n >= 1e12 then
		local digits = {}
		for d in string.gmatch(tostring(n), "%d") do
			table.insert(digits, DIGITS[tonumber(d) :: number])
		end
		return table.concat(digits, " ")
	end
	local out = {}
	for _, scale in { { 1e9, "billion" }, { 1e6, "million" }, { 1e3, "thousand" } } do
		if n >= scale[1] then
			table.insert(out, below1000(n // scale[1]) .. " " .. scale[2])
			n %= scale[1]
		end
	end
	if n > 0 then
		table.insert(out, below1000(n))
	end
	return table.concat(out, " ")
end

local ORDINAL = { one = "first", two = "second", three = "third", five = "fifth", eight = "eighth", nine = "ninth", twelve = "twelfth" }

-- "twenty-one" -> "twenty-first", "forty" -> "fortieth"
local function ordinal(words: string): string
	local head, last = string.match(words, "^(.-)(%a+)$")
	if not last then
		return words
	end
	local o = ORDINAL[last]
	if not o then
		if string.sub(last, -1) == "y" then
			o = string.sub(last, 1, -2) .. "ieth"
		else
			o = last .. "th"
		end
	end
	return (head or "") .. o
end

local function spell(word: string): string
	local out = {}
	for ch in string.gmatch(string.lower(word), "%a") do
		table.insert(out, LETTERS[ch])
	end
	return table.concat(out, " ")
end

local function digitsAfterPoint(d: string): string
	local out = {}
	for ch in string.gmatch(d, "%d") do
		table.insert(out, DIGITS[tonumber(ch) :: number])
	end
	return table.concat(out, " ")
end

function Speech.normalize(text: string): string
	local s = string.gsub(text, "[%c]", " ")
	-- faces and hearts
	s = string.gsub(s, "<3+", " heart ")
	s = string.gsub(s, "[:;=]['%-]?[%)%(%]%[DPpOo/\\|3]+", " ")
	-- shouting and stretching: "!!!" -> "!", "noooo" -> "noo"
	s = string.gsub(s, "!+", "!")
	s = string.gsub(s, "%?+", "?")
	s = string.gsub(s, "%.%.%.+", "...")
	repeat
		local n
		s, n = string.gsub(s, "(%a)%1%1", "%1%1")
	until n == 0
	-- numbers in their settings
	s = string.gsub(s, "(%d),(%d%d%d)", "%1%2")
	s = string.gsub(s, "(%d+)%s*[vV]%s*(%d+)", function(a, b)
		return Speech.number(tonumber(a) :: number) .. " versus " .. Speech.number(tonumber(b) :: number)
	end)
	s = string.gsub(s, "#(%d+)", function(n)
		return "number " .. n
	end)
	s = string.gsub(s, "%f[%w][xX](%d+)%f[%W]", function(n)
		return "times " .. n
	end)
	s = string.gsub(s, "(%d+)%%", function(n)
		return n .. " percent"
	end)
	s = string.gsub(s, "(%d+)(%a%a)%f[%A]", function(n, suffix)
		local lower = string.lower(suffix)
		if lower == "st" or lower == "nd" or lower == "rd" or lower == "th" then
			return ordinal(Speech.number(tonumber(n) :: number))
		end
		return nil
	end)
	s = string.gsub(s, "(%d+)%.(%d+)", function(a, b)
		return Speech.number(tonumber(a) :: number) .. " point " .. digitsAfterPoint(b)
	end)
	s = string.gsub(s, "%d+", function(n)
		if #n > 12 then
			return digitsAfterPoint(n)
		end
		return " " .. Speech.number(tonumber(n) :: number) .. " "
	end)
	-- symbols said out loud
	s = string.gsub(s, "&", " and ")
	s = string.gsub(s, "@", " at ")
	s = string.gsub(s, "%s%+%s", " plus ")
	s = string.gsub(s, "%s=%s", " equals ")
	-- words: slang in full, letter-words spelled, single letters named
	s = string.gsub(s, "[%a']+", function(word)
		local lower = string.lower(word)
		local said = SLANG[lower]
		if said then
			return said
		end
		local plain = string.gsub(lower, "'", "")
		if #plain == 1 and plain ~= "a" and plain ~= "i" and plain ~= "o" then
			return LETTERS[plain] or word
		end
		-- capitals without a vowel to say ("NPC", "PVP"): spell them
		if #word >= 2 and #word <= 5 and word == string.upper(word) and not string.find(lower, "[aeiouy]") and not SOUNDS[lower] then
			return spell(word)
		end
		return word
	end)
	s = string.gsub(s, "%s+", " ")
	s = string.gsub(s, " ([%.,!%?])", "%1")
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

return Speech
