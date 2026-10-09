--[[
	Sound
	Sound effects and background music.

	Effects play through the "Effects" sound group and music through "Music" (with a
	quiet "Ambience" bed under it), each with its own volume (Settings, or the match
	menu). Effects that repeat quickly (pawn steps, wheel ticks, coins) get a little
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
	Effects. Wood, cards and felt to match the board: Pro Sound Effects and APM library
	clips (Roblox's licensed audio library) plus a few of Roblox's own interface sounds.
	Volumes are loudness-matched, so the interface is quietest and rewards loudest.
]]
local LIBRARY: { [string]: Def } = {
	-- interface
	click = { id = asset(9120917438), volume = 0.8, jitter = 0.04 }, -- soft wooden tok
	hover = { id = asset(17208348006), volume = 0.35, max = 1 },
	open = { id = asset(15675037413), volume = 0.32 }, -- paper swipe
	close = { id = asset(17208186900), volume = 0.4 },
	error = { id = asset(17208353912), volume = 0.37 },
	pop = { id = asset(9119708437), volume = 0.6, jitter = 0.06 }, -- quick card fwip
	-- the board
	step = {
		id = asset(9119976006), -- temple-block pops, one per tile
		variants = { asset(9119976006), asset(9119976314), asset(9119976306), asset(9119976519), asset(9119976693) },
		volume = 0.6,
		jitter = 0.05,
		max = 3,
	},
	whoosh = { id = asset(9120704978), volume = 0.45, jitter = 0.05 },
	dice = { id = asset(9114074033), volume = 1.5 }, -- a die shaken and rolled
	diceLand = { id = asset(9114072359), volume = 0.7 }, -- ...landing on a felt-topped table
	tick = { id = asset(9119983245), volume = 0.32, max = 3 }, -- the wheel's pointer
	card = { id = asset(9119707474), volume = 0.45, jitter = 0.06, max = 3 }, -- card sliding off the deck
	reveal = { id = asset(9114035710), volume = 1.6, jitter = 0.04 }, -- card flick and snap
	place = { id = asset(9125576068), volume = 0.75 }, -- set down on wood
	coin = { id = asset(9113848418), volume = 0.62, jitter = 0.05, max = 3 },
	coins = { id = asset(9113848871), volume = 0.6 },
	treasure = { id = asset(9040172806), volume = 0.48 }, -- pizzicato and glockenspiel sting
	trap = { id = asset(9116723368), volume = 0.45 }, -- metal latch snap
	death = { id = asset(9113854388), volume = 1.05 }, -- cartoon bonk
	splash = { id = asset(9117947535), volume = 0.84 },
	fire = { id = asset(9114445792), volume = 0.57 },
	ice = { id = asset(9125611419), volume = 0.1, start = 0.15 },
	slime = { id = asset(9117284472), volume = 0.51 },
	magic = { id = asset(9116395089), volume = 1.5 }, -- soft chimes
	ability = { id = asset(9116422213), volume = 0.35 }, -- short shimmering transformation
	teleport = { id = asset(9125635426), volume = 0.22 }, -- sparkling pass-by
	turn = { id = asset(17208361335), volume = 0.28 },
	win = { id = asset(1846251701), volume = 0.31, start = 0.4 },
	lose = { id = asset(1846251702), volume = 0.23 },
	chest = { id = asset(9120881818), volume = 0.56 }, -- wooden chest creaking open
	levelUp = { id = asset(1839866243), volume = 0.34 },
}

--[[
	Music moods. Each track: its volume (loudness-matched, so every track sits at the same
	level under the effects), where its music starts (skipping silence) and where its
	ending begins (the next track fades in from there).
]]
type Track = { id: string, name: string, volume: number, start: number?, fadeAt: number? }

local PLAYLISTS: { [string]: { Track } } = {
	lobby = {
		{ id = asset(129583940918501), name = "At The Tavern", volume = 0.21, fadeAt = 101 },
	},
	match = {
		{ id = asset(93749688703091), name = "Board Games", volume = 0.19, fadeAt = 71 },
	},
	tension = {
		{ id = asset(93749688703091), name = "Board Games", volume = 0.19, fadeAt = 71 },
	},
}

-- A quiet night-time bed under the lobby music (nil: none).
local AMBIENCE: { [string]: Track } = {}

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
function Sound.preload()
	task.spawn(function()
		local list = {}
		for name, def in LIBRARY do
			table.insert(list, template(name, def, "Effects"))
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

local function applyVolumes()
	group("Effects", 1).Volume = if enabled then sfxVolume else 0
	local music = if musicEnabled then musicVolume else 0
	group("Music", 1).Volume = music * duckLevel
	group("Ambience", 1).Volume = music
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
local ambience: Sound? = nil
local ambienceMood: string? = nil
local switching = 0

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

local function setAmbience(name: string?)
	local def = if name then AMBIENCE[name] else nil
	local key = if def then name else nil
	if key == ambienceMood then
		return
	end
	ambienceMood = key
	if ambience then
		fadeOut(ambience, MOOD_FADE)
		ambience = nil
	end
	if def then
		local snd = Instance.new("Sound")
		snd.Name = "Ambience_" .. def.name
		snd.SoundId = def.id
		snd.Looped = true
		snd.Volume = 0
		snd.SoundGroup = group("Ambience", 1)
		snd.Parent = SoundService
		snd:Play()
		TweenService:Create(snd, TweenInfo.new(MOOD_FADE * 2), { Volume = def.volume }):Play()
		ambience = snd
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
	switching += 1
	local old = current
	current = nil
	if old then
		fadeOut(old.sound, MOOD_FADE)
	end
	setAmbience(name)
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

return Sound
