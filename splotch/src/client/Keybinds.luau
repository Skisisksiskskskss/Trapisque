--[[
	Every PC control in one table. Each action lists the inputs that trigger it
	(KeyCode or UserInputType), so rebinding is a one-line change.
]]

local Keybinds = {
	Primary = { Enum.UserInputType.MouseButton1 },
	Skill1 = { Enum.KeyCode.One },
	Skill2 = { Enum.KeyCode.Two },
	Skill3 = { Enum.KeyCode.Three },
	Dash = { Enum.KeyCode.Q },
	Block = { Enum.KeyCode.F },
	Dive = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
	Leap = { Enum.KeyCode.Space },
	Menu = { Enum.KeyCode.M },
	FreeCursor = { Enum.KeyCode.LeftAlt },
	Help = { Enum.KeyCode.H },
}

-- The action an input belongs to, or nil.
function Keybinds.match(input: InputObject): string?
	for action, inputs in Keybinds do
		if typeof(inputs) == "table" then
			for _, bound in inputs do
				if bound == input.KeyCode or bound == input.UserInputType then
					return action
				end
			end
		end
	end
	return nil
end

-- Short label for the first input of an action (for the HUD).
function Keybinds.label(action: string): string
	local inputs = Keybinds[action]
	local first = if typeof(inputs) == "table" then inputs[1] else nil
	if first == Enum.UserInputType.MouseButton1 then
		return "M1"
	elseif first == Enum.KeyCode.LeftShift then
		return "SHIFT"
	elseif first == Enum.KeyCode.One then
		return "1"
	elseif first == Enum.KeyCode.Two then
		return "2"
	elseif first == Enum.KeyCode.Three then
		return "3"
	elseif typeof(first) == "EnumItem" then
		return string.upper(first.Name)
	end
	return "?"
end

return Keybinds
