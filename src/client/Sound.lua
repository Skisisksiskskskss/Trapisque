--[[
	Sound
	Sound effects and background music.

	Effects play through the "Effects" sound group and music through "Music", so each
	can be switched off on its own (Settings, or the match menu). Effects that repeat
	quickly (pawn steps, wheel ticks, coins) get a little random pitch so they don't
	sound like a machine gun, and the same effect never stacks more than a few copies.

	Music loops and crossfades when the screen changes (lobby <-> match).

		Sound.play(name, pitchShift?)
		Sound.music("lobby" | "match" | nil)
		Sound.setEnabled(on) ; Sound.setMusicEnabled(on)
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

-- Background music: APM library cues, quiet enough that the effects sit on top.
local MUSIC: { [string]: Def } = {
	lobby = { id = asset(129583940918501), volume = 0.21, loopEnd = 103 }, -- "At The Tavern"
	match = { id = asset(93749688703091), volume = 0.19, loopEnd = 73 }, -- "Board Games"
}

local MUSIC_FADE = 1.2

local groups = {}
local cache: { [string]: Sound } = {}
local playing: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}
local enabled = true
local musicEnabled = true
local track: string? = nil
local trackSound: Sound? = nil

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

function Sound.isEnabled(): boolean
	return enabled
end

function Sound.setEnabled(on: boolean)
	enabled = on
	group("Effects", 1).Volume = if on then 1 else 0
end

function Sound.isMusicEnabled(): boolean
	return musicEnabled
end

function Sound.setMusicEnabled(on: boolean)
	musicEnabled = on
	group("Music", 1).Volume = if on then 1 else 0
	if on and trackSound and not trackSound.IsPlaying then
		trackSound:Play()
	end
end

function Sound.applySettings(settings)
	if type(settings) ~= "table" then
		return
	end
	Sound.setEnabled(settings.sfx ~= false)
	Sound.setMusicEnabled(settings.music ~= false)
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

-- Switches the background music (nil: silence). Crossfades.
function Sound.music(name: string?)
	if name == track then
		return
	end
	track = name
	local old = trackSound
	if old then
		local fade = TweenService:Create(old, TweenInfo.new(MUSIC_FADE), { Volume = 0 })
		fade:Play()
		fade.Completed:Once(function()
			old:Stop()
		end)
	end
	trackSound = nil
	local def = if name then MUSIC[name] else nil
	if not (name and def) then
		return
	end
	local s = template(name, def, "Music")
	s.Looped = true
	if def.loopEnd then
		-- loop before the fade-out and silence at the end of the track
		s.PlaybackRegionsEnabled = true
		s.LoopRegion = NumberRange.new(0, def.loopEnd)
	end
	s.Volume = 0
	s.TimePosition = 0
	s:Play()
	TweenService:Create(s, TweenInfo.new(MUSIC_FADE), { Volume = def.volume or 0.3 }):Play()
	trackSound = s
end

return Sound
