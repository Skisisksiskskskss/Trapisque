--[[
	Gamepad
	Playing with a controller (Xbox, PlayStation, or a pad on PC). The whole game is
	buttons and tiles on the screen, so a controller gets Roblox's virtual cursor: the
	left stick points, A clicks, and everything works the way it does with a mouse.
	A few buttons do the common things directly:

		B          close the window on top
		X          open the chat
		Y          use your ability (in a match)
		L1 / R1    zoom the board out / in (in a match)

	Screens listen with Gamepad.on(action, fn) -> disconnect, for "chat", "ability",
	"zoomIn" and "zoomOut". Gamepad.active() says whether a controller is in use.
]]

local UserInputService = game:GetService("UserInputService")

local Client = script.Parent
local Widgets = require(Client.UI.Widgets)

local Gamepad = {}

local listeners: { [string]: { (() -> ()) } } = {}
local using = false

local GAMEPAD = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
}

local BUTTONS = {
	[Enum.KeyCode.ButtonX] = "chat",
	[Enum.KeyCode.ButtonY] = "ability",
	[Enum.KeyCode.ButtonL1] = "zoomOut",
	[Enum.KeyCode.ButtonR1] = "zoomIn",
}

local function cursor(on: boolean)
	pcall(function()
		local GamepadService = game:GetService("GamepadService")
		if on then
			GamepadService:EnableGamepadCursor(nil)
		else
			GamepadService:DisableGamepadCursor()
		end
	end)
end

local function setUsing(on: boolean)
	if using == on then
		return
	end
	using = on
	cursor(on)
end

function Gamepad.active(): boolean
	return using
end

function Gamepad.on(action: string, fn: () -> ()): () -> ()
	listeners[action] = listeners[action] or {}
	table.insert(listeners[action], fn)
	return function()
		local list = listeners[action]
		local i = list and table.find(list, fn)
		if i then
			table.remove(list, i)
		end
	end
end

local function fire(action: string)
	for _, fn in table.clone(listeners[action] or {}) do
		task.spawn(fn)
	end
end

function Gamepad.init()
	setUsing(GAMEPAD[UserInputService:GetLastInputType()] == true)
	UserInputService.LastInputTypeChanged:Connect(function(kind)
		if GAMEPAD[kind] then
			setUsing(true)
		elseif kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.Keyboard then
			setUsing(false)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not GAMEPAD[input.UserInputType] then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB then
			Widgets.closeTop()
			return
		end
		if processed then
			return
		end
		local action = BUTTONS[input.KeyCode]
		if action then
			fire(action)
		end
	end)
end

return Gamepad
