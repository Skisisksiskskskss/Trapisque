--[[
	Tiny UI construction helpers and the HUD's visual language.

	Ui.create("Class", { Prop = value }, children) builds an instance in one
	expression; tools/check_api.py validates the property names used in these
	calls against the Roblox API.

	Type: Oswald (condensed) for labels, Bangers for numbers, PermanentMarker
	for big callouts. Panels are near-black with a faint white edge.
]]

local Ui = {}

Ui.FONT = Enum.Font.Oswald
Ui.FONT_NUMBERS = Enum.Font.Bangers
Ui.FONT_TAG = Enum.Font.PermanentMarker
Ui.PANEL = Color3.fromRGB(12, 12, 16)
Ui.TEXT = Color3.fromRGB(245, 245, 248)
Ui.MUTED = Color3.fromRGB(165, 168, 180)
Ui.ACCENT = Color3.fromRGB(255, 196, 64)
Ui.DANGER = Color3.fromRGB(255, 72, 72)
Ui.EVASIVE = Color3.fromRGB(70, 110, 230)

function Ui.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: number?): UICorner
	return Ui.create("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

function Ui.stroke(thickness: number?, color: Color3?, transparency: number?): UIStroke
	return Ui.create("UIStroke", {
		Thickness = thickness or 1,
		Color = color or Color3.fromRGB(255, 255, 255),
		Transparency = transparency or 0.85,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.textStroke(thickness: number?): UIStroke
	return Ui.create("UIStroke", {
		Thickness = thickness or 1.5,
		Color = Color3.fromRGB(8, 8, 12),
		Transparency = 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Ui.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Ui.FONT,
		TextColor3 = Ui.TEXT,
		TextScaled = false,
		TextSize = 16,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.create("TextLabel", defaults)
end

-- A vertical sheen so flat fills read as bars, not boxes.
function Ui.sheen(): UIGradient
	return Ui.create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.05),
			NumberSequenceKeypoint.new(1, 0.35),
		}),
	})
end

function Ui.hex(color: Color3): string
	return color:ToHex()
end

return Ui
