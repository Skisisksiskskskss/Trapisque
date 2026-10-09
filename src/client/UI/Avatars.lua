--[[
	Avatars
	Players' Roblox avatar headshots, drawn round. Bots (and Studio test players, whose
	ids aren't real) get their character's emblem instead, so every seat has a face.

		Avatars.portrait(parent, info, props) -> Frame
			info = { userId, character, isBot, name }   props go on the root frame
]]

local UI = script.Parent
local Util = require(UI.Util)
local Theme = require(UI.Theme)
local Icons = require(UI.Icons)

local C = Theme.C

local Avatars = {}

-- rbxthumb content ids load straight into an ImageLabel (no web request needed).
function Avatars.headshot(userId: number?): string?
	if type(userId) ~= "number" or userId <= 0 then
		return nil
	end
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

--[[
	A round portrait: the headshot on a soft backing colour (the photo is a bust on a
	transparent background), or the character emblem for bots.
	opts.ring = Color3 draws a ring around it (seat colour); opts.ringPx its thickness.
]]
function Avatars.portrait(parent: Instance?, info, props: { [string]: any }?, opts: { [string]: any }?): Frame
	local o = opts or {}
	local root = Util.frame(nil, {
		Name = "Portrait",
		AnchorPoint = Vector2.new(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	})
	if props then
		for k, v in props do
			(root :: any)[k] = v
		end
	end
	local image = Avatars.headshot(info and info.userId)
	if image and not (info and info.isBot) then
		local back = Util.new("Frame", {
			Name = "Back",
			BackgroundColor3 = o.back or Theme.C.panelHi,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			Parent = root,
		})
		Util.corner(back, 0.5)
		local img = Util.new("ImageLabel", {
			Name = "Headshot",
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = root,
		})
		Util.corner(img, 0.5)
	else
		local character = info and info.character or "info"
		local color = Theme.Character[character] or C.textFaint
		Icons.medallion(root, character, color, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	end
	if o.ring then
		local ring = Util.new("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = root,
		})
		Util.corner(ring, 0.5)
		Util.stroke(ring, o.ring, o.ringPx or 3)
	end
	root.Parent = parent
	return root
end

return Avatars
