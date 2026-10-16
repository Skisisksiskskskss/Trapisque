--[[
	Voice
	Reads chat lines out loud in the speaker's voice (Meta/Voices): Roblox's
	text-to-speech, pitched, sped up or slowed and run through a voice's effects, so a
	line sounds like a grumbly old mage or a parrot, never like a newsreader.

	Text-to-speech has a budget (Roblox rate-limits it), so a quick chat line is loaded
	once per voice and replayed from then on, and a line that can't get a voice in time
	is babbled instead: one squeaky syllable per word, pitched by its vowels, at the
	pace of speech. At most two lines talk at once; a line that waited too long is
	skipped (its bubble has moved on).

		Voice.say(text, voice)      -- voice: a Voices entry (Voices.resolve)
		Voice.setEnabled(on)        -- settings.voices
		Voice.sample(voice)         -- "Ahoy!" in that voice (the voice picker)
]]

local SoundService = game:GetService("SoundService")

local Client = script.Parent
local Sound = require(Client.Sound)

local Voice = {}

local enabled = true
local output: Instance? = nil
local buses: { [string]: Instance } = {}
local cache: { [string]: Instance } = {} -- [voice|text] = a loaded line (quick lines)
local cacheCount = 0
local talking = 0
local queue: { { text: string, voice: any, at: number } } = {}
local tokens, tokenAt = 3, 0
local broken = false -- text-to-speech isn't there at all: babble from now on

local MAX_TALKING = 2
local MAX_WAIT = 4 -- seconds a line may wait for its turn
local LOADS_PER_SECOND = 0.8
local LOAD_BURST = 3

local function set(inst: Instance, props: { [string]: any })
	for k, v in props do
		pcall(function()
			(inst :: any)[k] = v
		end)
	end
end

local function make(className: string, props: { [string]: any }?, parent: Instance?): Instance?
	local ok, inst = pcall(Instance.new, className)
	if not ok or not inst then
		return nil
	end
	if props then
		set(inst, props)
	end
	inst.Parent = parent
	return inst
end

local function wire(from: Instance, to: Instance)
	make("Wire", { SourceInstance = from, TargetInstance = to }, from)
end

-- What each voice's sound goes through on its way out.
local FX = {
	warm = {
		{ "AudioEqualizer", { LowGain = 4, MidGain = 0, HighGain = -6 } },
		{ "AudioReverb", { DecayTime = 0.6, WetLevel = -14, DryLevel = 0 } },
	},
	gravel = {
		{ "AudioDistortion", { Level = 0.2 } },
		{ "AudioEqualizer", { LowGain = 2, MidGain = 2, HighGain = -4 } },
	},
	squawk = {
		{ "AudioFlanger", { Depth = 0.6, Mix = 0.5, Rate = 3 } },
		{ "AudioDistortion", { Level = 0.15 } },
	},
	haunt = {
		{ "AudioChorus", { Depth = 0.5, Mix = 0.5, Rate = 0.4 } },
		{ "AudioEcho", { DelayTime = 0.28, Feedback = 0.45, DryLevel = 0, WetLevel = -6 } },
		{ "AudioReverb", { DecayTime = 2.5, WetLevel = -4, DryLevel = 0 } },
	},
	clockwork = {
		{ "AudioTremolo", { Depth = 0.7, Frequency = 22 } },
		{ "AudioFlanger", { Depth = 0.4, Mix = 0.4, Rate = 6 } },
	},
}

-- The chain a voice plays into (built once): a fader, its effects, the speakers.
local function busFor(voice): Instance?
	if buses[voice.id] then
		return buses[voice.id]
	end
	if not output then
		output = make("AudioDeviceOutput", { Name = "TrapisqueVoices" }, SoundService)
		if not output then
			return nil
		end
	end
	local folder = SoundService:FindFirstChild("TrapisqueVoiceBuses") or make("Folder", { Name = "TrapisqueVoiceBuses" }, SoundService)
	local fader = make("AudioFader", { Name = voice.id, Volume = 1 }, folder)
	if not fader then
		return nil
	end
	local last = fader
	for _, name in voice.fx or {} do
		for _, step in FX[name] or {} do
			local fx = make(step[1], step[2], fader)
			if fx then
				wire(last, fx)
				last = fx
			end
		end
	end
	wire(last, output :: Instance)
	buses[voice.id] = fader
	return fader
end

local function spendToken(): boolean
	local now = os.clock()
	tokens = math.min(LOAD_BURST, tokens + (now - tokenAt) * LOADS_PER_SECOND)
	tokenAt = now
	if tokens < 1 then
		return false
	end
	tokens -= 1
	return true
end

-- A loaded text-to-speech line for `text` in `voice`, or nil (no budget, or it failed).
local function load(text: string, voice, keep: boolean): Instance?
	if broken or not voice.tts then
		return nil
	end
	local key = voice.id .. "|" .. text
	local hit = cache[key]
	if hit and hit.Parent then
		return hit
	end
	if not spendToken() then
		return nil
	end
	local bus = busFor(voice)
	if not bus then
		broken = true
		return nil
	end
	local tts = make("AudioTextToSpeech", {
		Name = "Line",
		VoiceId = voice.tts.voice,
		Pitch = voice.tts.pitch,
		Speed = voice.tts.speed,
		Text = text,
		Volume = 1,
	}, bus)
	if not tts then
		broken = true
		return nil
	end
	wire(tts, bus)
	local ok, status = pcall(function()
		return (tts :: any):LoadAsync()
	end)
	if not ok or status ~= Enum.AssetFetchStatus.Success then
		tts:Destroy()
		return nil
	end
	if keep then
		if cacheCount >= 40 then
			for k, v in cache do
				v:Destroy()
				cache[k] = nil
			end
			cacheCount = 0
		end
		cache[key] = tts
		cacheCount += 1
	end
	return tts
end

local VOWEL_PITCH = { a = 0, e = 0.3, i = 0.55, o = -0.2, u = -0.4, y = 0.4 }

-- One squeaky syllable per word, at the pace of speech (when no voice could be had).
local function babble(text: string, voice)
	local base = voice.pitch or 1
	local spread = voice.spread or 0.2
	local gap = 1 / (voice.speed or 9)
	local words = {}
	for word, punct in string.gmatch(text, "([%w']+)([^%w']*)") do
		table.insert(words, { word = string.lower(word), punct = punct })
	end
	for i, w in words do
		if i > 18 then
			break
		end
		local vowels = {}
		for v in string.gmatch(w.word, "[aeiouy]") do
			table.insert(vowels, v)
		end
		local syllables = math.clamp(math.ceil(#vowels / 2), 1, 2)
		for s = 1, syllables do
			local v = vowels[math.min(#vowels, s * 2 - 1)] or "a"
			local pitch = base * (1 + spread * (VOWEL_PITCH[v] or 0))
			if i == #words and s == syllables and string.find(w.punct, "[!?]") then
				pitch *= 1.18 -- a lift at the end of a shout or a question
			end
			Sound.play("blip", pitch)
			task.wait(gap)
		end
		if string.find(w.punct, "[%.,!?;:]") then
			task.wait(gap * 2)
		else
			task.wait(gap * 0.4)
		end
	end
end

local function speak(text: string, voice)
	local quick = #text <= 24
	local tts = load(text, voice, quick)
	if tts then
		set(tts, { Volume = 1.6 * Sound.getVolume(), TimePosition = 0 })
		local done = false
		local conn = (tts :: any).Ended:Connect(function()
			done = true
		end)
		pcall(function()
			(tts :: any):Play()
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 10 do
			task.wait(0.1)
		end
		conn:Disconnect()
		if not quick then
			tts:Destroy()
		end
	else
		babble(text, voice)
	end
end

local function pump()
	while talking < MAX_TALKING and #queue > 0 do
		local item = table.remove(queue, 1) :: any
		if os.clock() - item.at <= MAX_WAIT then
			talking += 1
			task.spawn(function()
				pcall(speak, item.text, item.voice)
				talking -= 1
				pump()
			end)
		end
	end
end

function Voice.say(text: string, voice)
	if not enabled or not Sound.isEnabled() or type(text) ~= "string" or text == "" or not voice then
		return
	end
	if #queue >= 4 then
		table.remove(queue, 1)
	end
	table.insert(queue, { text = string.sub(text, 1, 140), voice = voice, at = os.clock() })
	pump()
end

function Voice.sample(voice)
	if voice then
		local was = enabled
		enabled = true
		Voice.say("Ahoy there, matey!", voice)
		enabled = was
	end
end

function Voice.setEnabled(on: boolean)
	enabled = on
	if not on then
		table.clear(queue)
	end
end

function Voice.isEnabled(): boolean
	return enabled
end

return Voice
