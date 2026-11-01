--!strict
-- Modal panel manager: one centred panel at a time with a dimmed backdrop, title bar and close button.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Modules.Signal)
local Kit = require(script.Parent.Kit)

export type PanelApi = {
	Refresh: ((state: { [string]: any }) -> ())?,
	OnOpen: (() -> ())?,
	OnClose: (() -> ())?,
}

type Entry = {
	Name: string,
	Title: string,
	Root: Frame,
	Api: PanelApi,
	Size: Vector2,
}

local Panels = {}

Panels.Opened = Signal.new() :: Signal.Signal<string>
Panels.Closed = Signal.new() :: Signal.Signal<string>

local screen: ScreenGui
local backdrop: TextButton
local entries: { [string]: Entry } = {}
local current: Entry? = nil
local lastState: { [string]: any }? = nil
local scale = 1

function Panels.Init(gui: ScreenGui)
	screen = gui
	backdrop = Kit.new("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 20,
		Selectable = false,
		Parent = screen,
	})
	backdrop.Activated:Connect(function()
		Panels.Close()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB then
			Panels.Close()
		end
	end)
end

function Panels.SetScale(value: number)
	scale = value
	for _, entry in entries do
		local uiScale = entry.Root:FindFirstChild("PanelScale") :: UIScale?
		if uiScale then
			uiScale.Scale = scale
		end
	end
end

-- Registers a panel. build(content) fills the content frame and returns callbacks.
function Panels.Register(
	name: string,
	title: string,
	size: Vector2,
	build: (content: Frame, close: () -> ()) -> PanelApi
)
	local root = Kit.panelFrame({
		Name = name .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		ZIndex = 21,
		Parent = screen,
	})
	Kit.new("UIScale", { Name = "PanelScale", Scale = scale, Parent = root })
	Kit.gradient(Kit.Colors.PanelLight, Kit.Colors.Panel).Parent = root

	local titleBar = Kit.new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = root,
	})
	Kit.label({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -120, 1, -8),
		Position = UDim2.fromOffset(16, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Kit.Colors.Yellow,
		MaxTextSize = 36,
		ZIndex = 23,
		Parent = titleBar,
	})
	local closeButton = Kit.button({
		Name = "Close",
		Text = "✕",
		Color = Kit.Colors.Red,
		Size = UDim2.fromOffset(48, 44),
		Position = UDim2.new(1, -56, 0, 6),
		Parent = titleBar,
		OnClick = function()
			Panels.Close()
		end,
	})
	closeButton.ZIndex = 23

	local content = Kit.new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.new(1, -24, 1, -70),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = root,
	})
	local api = build(content, function()
		Panels.Close()
	end)
	entries[name] = { Name = name, Title = title, Root = root, Api = api, Size = size }
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiObject") and descendant.ZIndex < 22 then
			descendant.ZIndex = 22
		end
	end
	root.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiObject") and descendant.ZIndex < 22 then
			descendant.ZIndex = 22
		end
	end)
end

function Panels.Open(name: string)
	local entry = entries[name]
	if not entry then
		return
	end
	if current and current ~= entry then
		current.Root.Visible = false
		if current.Api.OnClose then
			current.Api.OnClose()
		end
		Panels.Closed:Fire(current.Name)
	end
	current = entry
	backdrop.Visible = true
	entry.Root.Visible = true
	Kit.popIn(entry.Root)
	if entry.Api.OnOpen then
		entry.Api.OnOpen()
	end
	local state = lastState
	if state and entry.Api.Refresh then
		entry.Api.Refresh(state)
	end
	if UserInputService.GamepadEnabled then
		local close = entry.Root:FindFirstChild("Close", true)
		if close and close:IsA("GuiObject") then
			GuiService.SelectedObject = close
		end
	end
	Panels.Opened:Fire(name)
end

function Panels.Close()
	local entry = current
	if not entry then
		return
	end
	entry.Root.Visible = false
	backdrop.Visible = false
	current = nil
	if entry.Api.OnClose then
		entry.Api.OnClose()
	end
	GuiService.SelectedObject = nil
	Panels.Closed:Fire(entry.Name)
end

function Panels.Toggle(name: string)
	if current and current.Name == name then
		Panels.Close()
	else
		Panels.Open(name)
	end
end

function Panels.IsOpen(name: string?): boolean
	if name == nil then
		return current ~= nil
	end
	return current ~= nil and current.Name == name
end

function Panels.Refresh(state: { [string]: any })
	lastState = state
	local entry = current
	if entry and entry.Api.Refresh then
		entry.Api.Refresh(state)
	end
end

return Panels
