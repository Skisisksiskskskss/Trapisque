--!strict
-- Tiny declarative UI kit: consistent chunky, kid-friendly style that scales from phones to TVs.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Kit = {}

Kit.Font = Enum.Font.FredokaOne
Kit.Colors = {
	Panel = Color3.fromRGB(32, 30, 64),
	PanelLight = Color3.fromRGB(52, 48, 98),
	Stroke = Color3.fromRGB(14, 12, 30),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(190, 185, 230),
	Yellow = Color3.fromRGB(255, 205, 50),
	Green = Color3.fromRGB(70, 215, 110),
	Blue = Color3.fromRGB(60, 170, 255),
	Pink = Color3.fromRGB(255, 80, 200),
	Red = Color3.fromRGB(255, 80, 80),
	Orange = Color3.fromRGB(255, 150, 40),
	Purple = Color3.fromRGB(150, 90, 255),
	Grey = Color3.fromRGB(120, 120, 140),
	Cash = Color3.fromRGB(120, 255, 120),
}

export type Props = { [string]: any }

-- Creates an instance with properties and children. Children may be instances or arrays of instances.
function Kit.new(className: string, props: Props?, children: { any }?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			if typeof(child) == "Instance" then
				child.Parent = instance
			end
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Kit.corner(radius: number?): any
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Kit.stroke(thickness: number?, color: Color3?): any
	return Kit.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Kit.Colors.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.textStroke(thickness: number?): any
	return Kit.new("UIStroke", {
		Thickness = thickness or 2,
		Color = Kit.Colors.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Kit.padding(px: number): any
	return Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Kit.gradient(top: Color3, bottom: Color3): any
	return Kit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function Kit.list(
	direction: Enum.FillDirection,
	spacing: number,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
): any
	return Kit.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, spacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Center,
	})
end

function Kit.label(props: Props): TextLabel
	local defaults: Props = {
		BackgroundTransparency = 1,
		Font = Kit.Font,
		TextColor3 = Kit.Colors.Text,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 28),
	}
	for key, value in props do
		defaults[key] = value
	end
	local label = Kit.new("TextLabel", defaults)
	Kit.textStroke(2).Parent = label
	local constraint = Kit.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 40, MinTextSize = 8 })
	constraint.Parent = label
	return label
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end
Kit.lighten = lighten

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end
Kit.darken = darken

-- Press feedback: squish on press, pop back on release.
function Kit.bouncy(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = button })
	local function tweenTo(value: number, time: number)
		TweenService
			:Create(scale, TweenInfo.new(time, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = value })
			:Play()
	end
	button.MouseButton1Down:Connect(function()
		tweenTo(0.9, 0.08)
	end)
	button.MouseButton1Up:Connect(function()
		tweenTo(1, 0.2)
	end)
	button.MouseLeave:Connect(function()
		tweenTo(1, 0.2)
	end)
	button.MouseEnter:Connect(function()
		if not UserInputService.TouchEnabled then
			tweenTo(1.05, 0.12)
		end
	end)
end

export type ButtonOptions = {
	Text: string,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	TextSize: number?,
	Parent: Instance?,
	Name: string?,
	OnClick: (() -> ())?,
}

function Kit.button(options: ButtonOptions): TextButton
	local color = options.Color or Kit.Colors.Green
	local button = Kit.new("TextButton", {
		Name = options.Name or "Button",
		Size = options.Size or UDim2.fromOffset(160, 52),
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		LayoutOrder = options.LayoutOrder or 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = options.Text,
		Font = Kit.Font,
		TextColor3 = Kit.Colors.Text,
		TextScaled = true,
		Selectable = true,
	}, {
		Kit.corner(14),
		Kit.stroke(3),
		Kit.gradient(lighten(color, 0.2), darken(color, 0.15)),
		Kit.new("UITextSizeConstraint", { MaxTextSize = options.TextSize or 30, MinTextSize = 8 }),
		Kit.new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
	Kit.textStroke(2).Parent = button
	Kit.bouncy(button)
	if options.OnClick then
		local callback = options.OnClick
		button.Activated:Connect(function()
			callback()
		end)
	end
	if options.Parent then
		button.Parent = options.Parent
	end
	return button
end

function Kit.setButtonColor(button: GuiObject, color: Color3)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(lighten(color, 0.2), darken(color, 0.15))
	end
end

function Kit.panelFrame(props: Props): Frame
	local defaults: Props = {
		BackgroundColor3 = Kit.Colors.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
	}
	for key, value in props do
		defaults[key] = value
	end
	local frame = Kit.new("Frame", defaults, {
		Kit.corner(16),
		Kit.stroke(3),
	})
	return frame
end

function Kit.tween(
	instance: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- Pop-in animation for a GuiObject that has (or gets) a UIScale.
function Kit.popIn(gui: GuiObject)
	local scale = gui:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = gui })
	scale.Scale = 0.6
	Kit.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- A ViewportFrame showing a 3D model, slowly turning.
function Kit.viewport(model: Model, size: UDim2, distanceScale: number?): ViewportFrame
	local viewport = Kit.new("ViewportFrame", {
		Size = size,
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1.5, -1),
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model.Parent = viewport
	local _, extents = model:GetBoundingBox()
	local radius = extents.Magnitude / 2
	local height = (model:GetAttribute("Height") :: number?) or extents.Y
	local focus = model:GetPivot().Position + Vector3.new(0, height / 2, 0)
	local distance = radius / math.tan(math.rad(15)) * (distanceScale or 1.05)
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, radius * 0.35, -distance), focus)
	return viewport
end

return Kit
