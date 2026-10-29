--[[
	Computes R6 part positions for animation keyframes with the game's own pose
	maths (shared/R6Pose + shared/Animations) and prints them as JSON, so
	tools/render_poses.py can draw them for review without Studio.

	lune run tools/dump-poses.luau > build/poses.json
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local env = setmetatable({
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
}, { __index = getfenv() })

local function load(path: string): any
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end

local R6Pose = load("src/shared/R6Pose.luau")
local Animations = load("src/shared/Animations.luau")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local SIZES = {
	Torso = Vector3.new(2, 2, 1),
	Head = Vector3.new(2, 1, 1),
	["Right Arm"] = Vector3.new(1, 2, 1),
	["Left Arm"] = Vector3.new(1, 2, 1),
	["Right Leg"] = Vector3.new(1, 2, 1),
	["Left Leg"] = Vector3.new(1, 2, 1),
}

local WEAPON_TIP = {
	Brush = CFrame.new(0, -1, -2.45),
	Roller = CFrame.new(0, -1.15, -2.95),
}

local function solve(pose: any, weapon: string?): { any }
	R6Pose.plantLegs(pose)
	local c0 = R6Pose.c0s(R6Pose.DEFAULT_C0, pose)
	local c1 = R6Pose.DEFAULT_C1
	local root = CFrame.new(0, 3, 0)
	local torso = root * c0.Root * c1.Root:Inverse()
	local parts = {
		Torso = torso,
		Head = torso * c0.Neck * c1.Neck:Inverse(),
		["Right Arm"] = torso * c0.RArm * c1.RArm:Inverse(),
		["Left Arm"] = torso * c0.LArm * c1.LArm:Inverse(),
		["Right Leg"] = torso * c0.RLeg * c1.RLeg:Inverse(),
		["Left Leg"] = torso * c0.LLeg * c1.LLeg:Inverse(),
	}
	local out = {}
	for name, cf in parts do
		table.insert(
			out,
			{ name = name, cframe = { cf:GetComponents() }, size = { SIZES[name].X, SIZES[name].Y, SIZES[name].Z } }
		)
	end
	if weapon then
		local tip = parts["Right Arm"] * WEAPON_TIP[weapon]
		table.insert(out, { name = "Weapon", cframe = { tip:GetComponents() }, size = { 0.8, 0.5, 1 } })
	end
	return out
end

local function partial(p: any): any
	local full = R6Pose.empty()
	R6Pose.blend(full, p, 1)
	return full
end

local frames = {}
local function frame(group: string, label: string, pose: any, weapon: string?)
	table.insert(frames, { group = group, label = label, parts = solve(pose, weapon) })
end

-- Reference poses.
frame("Reference", "rest", R6Pose.empty())
frame("Reference", "RArm pitch 90", partial({ RArm = Animations.J(90) }))
frame("Reference", "RArm roll 90", partial({ RArm = Animations.J(0, 90) }))
frame("Reference", "Root pitch 30", partial({ Root = Animations.R(30) }))
frame("Reference", "Root yaw 45", partial({ Root = Animations.R(0, 45) }))
frame("Reference", "Neck yaw 45", partial({ Neck = Animations.N(0, 45) }))

-- Locomotion and stances (Brush hold).
local function withHold(p: any, weapon: string): any
	local full = partial(p)
	R6Pose.add(full, Animations.HOLD[weapon])
	return full
end
frame("Locomotion", "idle", withHold(Animations.idle(0), "Brush"), "Brush")
frame("Locomotion", "walk 0", withHold(Animations.walk(math.pi / 2), "Brush"), "Brush")
frame("Locomotion", "run 0", withHold(Animations.run(math.pi / 2), "Brush"), "Brush")
frame("Locomotion", "run 1", withHold(Animations.run(-math.pi / 2), "Brush"), "Brush")
frame("Locomotion", "jump", withHold(Animations.jump(), "Brush"), "Brush")
frame("Locomotion", "fall", withHold(Animations.fall(0), "Brush"), "Brush")
frame("Locomotion", "block", partial(Animations.BLOCK), "Brush")
frame("Locomotion", "stunned", partial(Animations.STUNNED), "Brush")

-- Every clip at each of its keyframes (over an idle base, like in game).
local names = {}
for name in Animations.CLIPS do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	local clip = Animations.CLIPS[name]
	local weapon = if string.find(name, "Roller") then "Roller" else "Brush"
	for _, key in clip.keys do
		local base = withHold(Animations.idle(0), weapon)
		R6Pose.blend(base, R6Pose.sample(clip, key.t), 1, clip.joints)
		frame(name, string.format("t=%.2f", key.t), base, weapon)
	end
end

print(serde.encode("json", frames, false))
