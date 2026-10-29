--[[
	Keybinds: one rebindable input per action. Players change them in the
	settings menu; Settings saves them with the rest of their preferences.

	Inputs are stored by name ("KeyCode.Q", "UserInputType.MouseButton1") so
	they serialise cleanly. WASD, Space and shift lock stay Roblox's own.
]]

local Keybinds = {}

export type Action = { id: string, label: string }

Keybinds.ACTIONS = {
	{ id = "M1", label = "Attack" },
	{ id = "Skill1", label = "Skill 1" },
	{ id = "Skill2", label = "Skill 2" },
	{ id = "Skill3", label = "Skill 3" },
	{ id = "Skill4", label = "Skill 4" },
	{ id = "Dash", label = "Dash / Evasive" },
	{ id = "Block", label = "Block" },
	{ id = "Dive", label = "Dive into paint" },
	{ id = "Awaken", label = "Awaken" },
	{ id = "Characters", label = "Characters menu" },
	{ id = "Settings", label = "Settings menu" },
} :: { Action }

Keybinds.DEFAULTS = {
	M1 = "UserInputType.MouseButton1",
	Skill1 = "KeyCode.One",
	Skill2 = "KeyCode.Two",
	Skill3 = "KeyCode.Three",
	Skill4 = "KeyCode.Four",
	Dash = "KeyCode.Q",
	Block = "KeyCode.F",
	Dive = "KeyCode.R",
	Awaken = "KeyCode.G",
	Characters = "KeyCode.M",
	Settings = "KeyCode.P",
}

-- Inputs that can never be bound (they belong to Roblox or to movement).
local RESERVED = {
	["KeyCode.W"] = true,
	["KeyCode.A"] = true,
	["KeyCode.S"] = true,
	["KeyCode.D"] = true,
	["KeyCode.Space"] = true,
	["KeyCode.Escape"] = true,
	["KeyCode.Slash"] = true,
	["KeyCode.Backquote"] = true,
	["KeyCode.LeftShift"] = true, -- shift lock
	["KeyCode.RightShift"] = true,
	["KeyCode.Tab"] = true, -- player list
	["UserInputType.MouseMovement"] = true,
	["UserInputType.MouseWheel"] = true,
}

local SHORT_NAMES = {
	["UserInputType.MouseButton1"] = "M1",
	["UserInputType.MouseButton2"] = "M2",
	["UserInputType.MouseButton3"] = "M3",
	["KeyCode.One"] = "1",
	["KeyCode.Two"] = "2",
	["KeyCode.Three"] = "3",
	["KeyCode.Four"] = "4",
	["KeyCode.Five"] = "5",
	["KeyCode.Six"] = "6",
	["KeyCode.Seven"] = "7",
	["KeyCode.Eight"] = "8",
	["KeyCode.Nine"] = "9",
	["KeyCode.Zero"] = "0",
	["KeyCode.LeftControl"] = "CTRL",
	["KeyCode.LeftAlt"] = "ALT",
	["KeyCode.CapsLock"] = "CAPS",
}

-- True while the settings menu is waiting for a key to bind; actions ignore input then.
Keybinds.capturing = false

local current: { [string]: string } = table.clone(Keybinds.DEFAULTS)
local listeners: { () -> () } = {}

local function notify()
	for _, listener in listeners do
		task.spawn(listener)
	end
end

-- Stable name for an input, or nil if it is not bindable.
function Keybinds.inputName(input: InputObject): string?
	local name
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.Unknown then
			return nil
		end
		name = "KeyCode." .. input.KeyCode.Name
	else
		name = "UserInputType." .. input.UserInputType.Name
	end
	if RESERVED[name] then
		return nil
	end
	return name
end

-- The action bound to an input, or nil.
function Keybinds.match(input: InputObject): string?
	local name = Keybinds.inputName(input)
	if not name or Keybinds.capturing then
		return nil
	end
	for action, bound in current do
		if bound == name then
			return action
		end
	end
	return nil
end

function Keybinds.get(action: string): string
	return current[action] or ""
end

-- Short label for the HUD and menus ("Q", "M1", "1").
function Keybinds.label(action: string): string
	local name = current[action]
	if not name then
		return "?"
	end
	return SHORT_NAMES[name] or string.upper((string.gsub(name, "^%a+%.", "")))
end

-- Binds `inputName` to `action`. Whatever used that input before swaps to
-- the action's old input, so nothing ends up unbound.
function Keybinds.set(action: string, inputName: string)
	if not Keybinds.DEFAULTS[action] or RESERVED[inputName] then
		return
	end
	local previous = current[action]
	for other, bound in current do
		if bound == inputName and other ~= action then
			current[other] = previous
		end
	end
	current[action] = inputName
	notify()
end

function Keybinds.reset()
	current = table.clone(Keybinds.DEFAULTS)
	notify()
end

function Keybinds.serialize(): { [string]: string }
	return table.clone(current)
end

-- Loads saved binds, ignoring anything malformed or duplicated.
function Keybinds.load(saved: any)
	if typeof(saved) ~= "table" then
		return
	end
	local merged = table.clone(Keybinds.DEFAULTS)
	local used = {}
	for action in Keybinds.DEFAULTS do
		local name = saved[action]
		if typeof(name) == "string" and not RESERVED[name] and not used[name] and #name < 64 then
			merged[action] = name
		end
		used[merged[action]] = true
	end
	current = merged
	notify()
end

function Keybinds.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

return Keybinds
