--[[
	Tiny UI construction helpers. Ui.create("Class", { Prop = value }, children)
	builds an instance in one expression; tools/check_api.py validates the
	property names used in these calls against the Roblox API.
]]

local Ui = {}

Ui.FONT = Enum.Font.GothamBold
Ui.FONT_HEAVY = Enum.Font.FredokaOne
Ui.PANEL = Color3.fromRGB(16, 17, 22)
Ui.TEXT = Color3.fromRGB(245, 245, 248)
Ui.MUTED = Color3.fromRGB(170, 172, 182)
Ui.ACCENT = Color3.fromRGB(255, 140, 40)

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
	return Ui.create("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Ui.stroke(thickness: number?, color: Color3?, transparency: number?): UIStroke
	return Ui.create("UIStroke", {
		Thickness = thickness or 1.5,
		Color = color or Color3.fromRGB(0, 0, 0),
		Transparency = transparency or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.textStroke(thickness: number?): UIStroke
	return Ui.create("UIStroke", {
		Thickness = thickness or 1.5,
		Color = Color3.fromRGB(10, 10, 14),
		Transparency = 0.2,
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

function Ui.hex(color: Color3): string
	return color:ToHex()
end

return Ui
