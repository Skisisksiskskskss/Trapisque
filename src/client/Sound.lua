--[[
	Sound
	Sound effects and background music.

	Effects play through the "Effects" sound group and music through "Music", each with
	its own volume (Settings, or the match menu). Effects that repeat quickly (pawn steps, wheel ticks, coins) get a little
	random pitch so they don't sound like a machine gun, and the same effect never
	stacks more than a few copies.

	Music comes in moods, each a short playlist: the lobby, a calm match, and the
	endgame of a match (someone is a treasure away from winning). Tracks are shuffled so
	the same one never plays twice in a row, and each one hands over to the next with a
	slow crossfade before its own ending, so nothing loops or cuts. Big moments (a
	treasure, the winner) duck the music for a breath so they land.

		Sound.play(name, pitchShift?)
		Sound.music("lobby" | "match" | "tension" | nil)
		Sound.duck(level?, seconds?)
		Sound.setVolume(0..1) ; Sound.setMusicVolume(0..1)
		Sound.applySettings(profile.settings)

	Every id below is a free Roblox audio library asset (Creator Store, public domain
	for Roblox experiences).
]]

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local Sound = {}

type Def = {
	id: string,
	variants: { string }?, -- same-family takes, picked at random (footsteps)
	volume: number?,
	pitch: number?,
	jitter: number?, -- random pitch spread (+/-)
	max: number?, -- most copies playing at once
	start: number?, -- skip this much silence at the front (seconds)
	loopEnd: number?, -- music: loop before the track's fade-out
}

local function asset(n: number): string
	return "rbxassetid://" .. n
end

--[[
	Effects. A pirate's table: wood, dice, coins, a ship's bell and a cutlass. Pro Sound
	Effects and APM library clips (Roblox's licensed audio library) plus a few of Roblox's
	own interface sounds. Pawns hop on wooden taps (five takes), a bonk is a deep wooden
	thump instead of a cartoon boing, the dice rattle and land on a felt-topped wooden
	table, your turn rings the ship's bell (pitched down so it stays warm, not piercing)
	and an ability draws a cutlass. Volumes are loudness-matched, so the interface is
	quietest (hover is barely there: it plays a lot) and rewards loudest.
]]
local LIBRARY: { [string]: Def } = {
	-- interface
	click = { id = asset(9120917438), volume = 0.8, jitter = 0.04 }, -- soft wooden tok
	hover = { id = asset(17208348006), volume = 0.2, jitter = 0.05, max = 1 }, -- a whisper of a tick
	open = { id = asset(15675037413), volume = 0.32 }, -- paper swipe
	close = { id = asset(17208186900), volume = 0.4 },
	error = { id = asset(17208353912), volume = 0.37 },
	pop = { id = asset(9119708437), volume = 0.6, jitter = 0.06 }, -- quick card fwip
	blip = { id = asset(9119983245), volume = 0.3, jitter = 0.03, max = 4 }, -- a babbled syllable (Voice)
	-- the board
	step = {
		id = asset(9114559553), -- a wooden piece tapped down, one per tile
		variants = { asset(9114559553), asset(9114559675), asset(9114559668), asset(9114559697), asset(9114559804) },
		volume = 0.27,
		jitter = 0.05,
		max = 3,
	},
	whoosh = { id = asset(9120704978), volume = 0.45, jitter = 0.05 },
	dice = { id = asset(9114072590), volume = 0.56, jitter = 0.04, start = 0.04 }, -- dice rattled in a cup
	diceLand = { id = asset(9114072359), volume = 0.7 }, -- ...landing on a felt-topped wooden table
	tick = { id = asset(9119983245), volume = 0.32, max = 3 }, -- the wheel's pointer
	card = { id = asset(9119707474), volume = 0.45, jitter = 0.06, max = 3 }, -- card sliding off the deck
	reveal = { id = asset(9114035710), volume = 1.6, jitter = 0.04 }, -- card flick and snap
	place = { id = asset(9125576068), volume = 0.75 }, -- set down on wood
	coin = { id = asset(9113848418), volume = 0.62, jitter = 0.05, max = 3 },
	coins = { id = asset(9113848871), volume = 0.6 },
	treasure = { id = asset(9040172806), volume = 0.48 }, -- pizzicato and glockenspiel sting
	trap = { id = asset(9116723368), volume = 0.45 }, -- metal latch snap
	death = { id = asset(9120885662), volume = 0.6 }, -- a deep wooden thump (a bonk, or back to start)
	bonk = { id = asset(9120885662), volume = 0.6 }, -- the same thump by its own name (a stampede plays it low)
	splash = { id = asset(9117947535), volume = 0.84 },
	fire = { id = asset(9114445792), volume = 0.57 },
	ice = { id = asset(9125611419), volume = 0.1, start = 0.15 },
	slime = { id = asset(9117284472), volume = 0.51 },
	magic = { id = asset(9116395089), volume = 1.5 }, -- soft chimes
	ability = { id = asset(9119742538), volume = 0.88, jitter = 0.04, start = 0.42 }, -- a cutlass drawn
	teleport = { id = asset(9125635426), volume = 0.22 }, -- sparkling pass-by
	turn = { id = asset(9113583408), volume = 0.33, pitch = 0.8, start = 0.14 }, -- the ship's bell, ding-ding
	win = { id = asset(1846251701), volume = 0.31, start = 0.4 },
	lose = { id = asset(1846251702), volume = 0.23 },
	chest = { id = asset(9120881818), volume = 0.56 }, -- wooden chest creaking open
	levelUp = { id = asset(1839866243), volume = 0.34 },
}

--[[
	Music moods: a pirate tavern in the lobby, a light Celtic adventure under the board
	and drums when someone is a treasure from winning. Each track has its volume
	(loudness-matched: every track sits at the same level under the effects, about
	-27 LUFS in the lobby, -29 in a match and -28 for the drums at full music volume),
	where its music starts (skipping silence) and where its ending begins (the next
	track fades in from there). All instrumental, from APM's library on Roblox, chosen
	by measuring them: steady loudness, no vocals, nothing comedic.
]]
type Track = { id: string, name: string, volume: number, start: number?, fadeAt: number? }

local PLAYLISTS: { [string]: { Track } } = {
	-- the tavern: accordion, fiddle and a light beat, easy to sit with for a while
	lobby = {
		{ id = asset(1846419945), name = "Step Dance", volume = 0.245, start = 0.2, fadeAt = 137 },
		{ id = asset(1845746272), name = "Sailing Boots", volume = 0.389, start = 0.3, fadeAt = 124 },
		{ id = asset(1840406291), name = "Swig Yer Jig (A)", volume = 0.316, start = 1, fadeAt = 176 },
		{ id = asset(1840678834), name = "Captains All", volume = 0.202, start = 0.2, fadeAt = 118 },
	},
	-- a match: light Celtic adventure that stays under the board
	match = {
		{ id = asset(1835239421), name = "Celtic Shanty Main ALT light", volume = 0.2, start = 0.3, fadeAt = 140 },
		{ id = asset(9047779811), name = "Irish Journey (Underscore)", volume = 0.136, fadeAt = 98 },
		{ id = asset(1836969461), name = "Celtic Adventures", volume = 0.245, fadeAt = 125 },
		{ id = asset(1846637377), name = "Treasure Island A", volume = 0.157, start = 0.2, fadeAt = 254 },
	},
	-- someone is a treasure away from winning: drums
	tension = {
		{ id = asset(1845091505), name = "Pinnacle - Percussion Only", volume = 0.224, start = 0.3, fadeAt = 103 },
		{ id = asset(1842899524), name = "Crucial (Underscore Version)", volume = 0.275, fadeAt = 104 },
		{ id = asset(1842868865), name = "Visions (Underscore Version)", volume = 0.232, fadeAt = 118 },
	},
}

local CROSSFADE = 2.5 -- seconds a track takes to hand over to the next
local MOOD_FADE = 1.6 -- seconds to switch moods (lobby -> match...)

local groups = {}
local cache: { [string]: Sound } = {}
local playing: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}
local enabled = true
local musicEnabled = true
local sfxVolume = 1
local musicVolume = 0.7
local duckLevel = 1

local function group(name: string, volume: number): SoundGroup
	local g = groups[name]
	if not g then
		g = SoundService:FindFirstChild(name)
		if not (g and g:IsA("SoundGroup")) then
			g = Instance.new("SoundGroup")
			g.Name = name
			g.Volume = volume
			g.Parent = SoundService
		end
		groups[name] = g
	end
	return g
end

local function template(name: string, def: Def, groupName: string): Sound
	local s = cache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = (if groupName == "Music" then "Music_" else "Sfx_") .. name
		s.SoundId = def.id
		s.Volume = def.volume or 0.5
		s.SoundGroup = group(groupName, 1)
		s.Parent = SoundService
		cache[name] = s
	end
	return s :: Sound
end

-- Loads every effect in the background so the first dice roll isn't silent.
--[[
	Loads the sounds in the background once you're in: every effect and the lobby's
	music first (onProgress(done, total) follows those), then the match music quietly.
	Nothing waits for it: a sound that isn't in yet just plays once it is.
]]
function Sound.preload(onProgress: ((number, number) -> ())?)
	task.spawn(function()
		local first: { any } = {}
		for name, def in LIBRARY do
			table.insert(first, template(name, def, "Effects"))
			for _, id in def.variants or {} do
				if id ~= def.id then
					table.insert(first, id)
				end
			end
		end
		for _, t in PLAYLISTS.lobby do
			table.insert(first, t.id)
		end
		local total, done = #first, 0
		if onProgress then
			onProgress(0, total)
		end
		pcall(function()
			ContentProvider:PreloadAsync(first, function()
				done = math.min(total, done + 1)
				if onProgress then
					onProgress(done, total)
				end
			end)
		end)
		if onProgress and done < total then
			onProgress(total, total)
		end
		local rest = {}
		for mood, list in PLAYLISTS do
			if mood ~= "lobby" then
				for _, t in list do
					table.insert(rest, t.id)
				end
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(rest)
		end)
	end)
end

local function applyVolumes()
	group("Effects", 1).Volume = if enabled then sfxVolume else 0
	local music = if musicEnabled then musicVolume else 0
	group("Music", 1).Volume = music * duckLevel
end

function Sound.isEnabled(): boolean
	return enabled and sfxVolume > 0
end

function Sound.setEnabled(on: boolean)
	enabled = on
	applyVolumes()
end

function Sound.isMusicEnabled(): boolean
	return musicEnabled and musicVolume > 0
end

function Sound.setMusicEnabled(on: boolean)
	musicEnabled = on
	applyVolumes()
end

-- 0..1 (0 is off).
function Sound.getVolume(): number
	return if enabled then sfxVolume else 0
end

function Sound.setVolume(v: number)
	sfxVolume = math.clamp(v, 0, 1)
	enabled = sfxVolume > 0
	applyVolumes()
end

function Sound.getMusicVolume(): number
	return if musicEnabled then musicVolume else 0
end

function Sound.setMusicVolume(v: number)
	musicVolume = math.clamp(v, 0, 1)
	musicEnabled = musicVolume > 0
	applyVolumes()
end

function Sound.applySettings(settings)
	if type(settings) ~= "table" then
		return
	end
	if type(settings.sfxVolume) == "number" then
		sfxVolume = math.clamp(settings.sfxVolume, 0, 1)
	end
	if type(settings.musicVolume) == "number" then
		musicVolume = math.clamp(settings.musicVolume, 0, 1)
	end
	enabled = settings.sfx ~= false and sfxVolume > 0
	musicEnabled = settings.music ~= false and musicVolume > 0
	applyVolumes()
end

function Sound.play(name: string, pitchShift: number?)
	if not enabled then
		return
	end
	local def = LIBRARY[name]
	if not def then
		return
	end
	-- the same sound twice in one frame is one sound
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.03 then
		return
	end
	if (playing[name] or 0) >= (def.max or 4) then
		return
	end
	lastPlayed[name] = now
	local clone = template(name, def, "Effects"):Clone()
	local variants = def.variants
	if variants then
		clone.SoundId = variants[math.random(1, #variants)]
	end
	if def.start then
		clone.TimePosition = def.start
	end
	local jitter = def.jitter or 0
	clone.PlaybackSpeed = (def.pitch or 1) * (pitchShift or 1) * (1 + (math.random() * 2 - 1) * jitter)
	clone.Parent = SoundService
	playing[name] = (playing[name] or 0) + 1
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		playing[name] = math.max(0, (playing[name] or 1) - 1)
		clone:Destroy()
	end
	clone.Ended:Once(finish)
	task.delay(8, finish)
	clone:Play()
end

---------------------------------------------------------------------------
-- music
---------------------------------------------------------------------------

local mood: string? = nil
local current: { sound: Sound, track: Track }? = nil
local bags: { [string]: { Track } } = {}
local lastTrack: { [string]: Track } = {}

local function fadeOut(s: Sound, time: number)
	local tw = TweenService:Create(s, TweenInfo.new(time, Enum.EasingStyle.Sine), { Volume = 0 })
	tw:Play()
	tw.Completed:Once(function()
		s:Stop()
		s:Destroy()
	end)
end

-- The next track for a mood: a shuffled bag, never the one that just played.
local function nextTrack(name: string): Track?
	local list = PLAYLISTS[name]
	if not list or #list == 0 then
		return nil
	end
	local bag = bags[name]
	if not bag or #bag == 0 then
		bag = table.clone(list)
		for i = #bag, 2, -1 do
			local j = math.random(1, i)
			bag[i], bag[j] = bag[j], bag[i]
		end
		if #bag > 1 and bag[#bag] == lastTrack[name] then
			bag[1], bag[#bag] = bag[#bag], bag[1]
		end
		bags[name] = bag
	end
	local t = table.remove(bag) :: Track
	lastTrack[name] = t
	return t
end

local advance: () -> ()

-- Starts `t` from silence and fades it in.
local function start(t: Track, fade: number)
	local snd = Instance.new("Sound")
	snd.Name = "Music_" .. t.name
	snd.SoundId = t.id
	snd.Volume = 0
	snd.SoundGroup = group("Music", 1)
	snd.Parent = SoundService
	snd.TimePosition = t.start or 0
	snd:Play()
	TweenService:Create(snd, TweenInfo.new(fade, Enum.EasingStyle.Sine), { Volume = t.volume }):Play()
	current = { sound = snd, track = t }
	-- a track that ran out before its hand-over (a short one) still hands over
	snd.Ended:Once(function()
		if current and current.sound == snd then
			advance()
		end
	end)
end

-- The current track hands over to the next one in its mood.
advance = function()
	local c = current
	if not c or not mood then
		return
	end
	local nextT = nextTrack(mood)
	if nextT then
		current = nil
		fadeOut(c.sound, CROSSFADE)
		start(nextT, CROSSFADE)
	end
end

--[[
	Switches the music to a mood ("lobby", "match", "tension"; nil: silence). The old
	track fades out while the new one fades in.
]]
function Sound.music(name: string?)
	if name == mood then
		return
	end
	mood = name
	local old = current
	current = nil
	if old then
		fadeOut(old.sound, MOOD_FADE)
	end
	local t = if name then nextTrack(name) else nil
	if t then
		start(t, MOOD_FADE)
	end
end

function Sound.mood(): string?
	return mood
end

--[[
	Ducks the music for a moment (a treasure, the winner) so the moment lands, then
	brings it back. level = how loud the music stays (0..1).
]]
local duckToken = 0
function Sound.duck(level: number?, seconds: number?)
	duckToken += 1
	local token = duckToken
	duckLevel = math.clamp(level or 0.35, 0, 1)
	local g = group("Music", 1)
	local base = if musicEnabled then musicVolume else 0
	TweenService:Create(g, TweenInfo.new(0.15), { Volume = base * duckLevel }):Play()
	task.delay(seconds or 1.6, function()
		if duckToken ~= token then
			return
		end
		duckLevel = 1
		local now = if musicEnabled then musicVolume else 0
		TweenService:Create(g, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Volume = now }):Play()
	end)
end

-- Hands each track over to the next one in its mood just before its ending.
task.spawn(function()
	while true do
		task.wait(0.5)
		local c = current
		if c and mood then
			local snd, t = c.sound, c.track
			local length = snd.TimeLength
			local fadeAt = t.fadeAt or (if length > 0 then length - CROSSFADE - 0.5 else math.huge)
			if snd.TimePosition >= fadeAt then
				advance()
			end
		end
	end
end)

applyVolumes()

return Sound
