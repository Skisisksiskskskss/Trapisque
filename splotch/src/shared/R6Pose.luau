--[[
	R6Pose: pure maths that turns Animations poses into R6 joint C0s, plus clip
	sampling and blending. Shared by client/Animator and the offline pose
	renderer (tools/render-poses), so what the tools draw is what the game does.
]]

export type Values = { [string]: number }
export type FullPose = { [string]: Values }

local R6Pose = {}

R6Pose.FIELDS = { "pitch", "roll", "yaw", "x", "y", "z" }
R6Pose.JOINTS = { "Root", "Neck", "RArm", "LArm", "RLeg", "LLeg" }

-- Default R6 joint frames (Part0 side = C0, Part1 side = C1).
R6Pose.DEFAULT_C0 = {
	Root = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	Neck = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	RArm = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	LArm = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	RLeg = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	LLeg = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
}
R6Pose.DEFAULT_C1 = {
	Root = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	Neck = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	RArm = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	LArm = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	RLeg = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	LLeg = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
}

function R6Pose.empty(): FullPose
	local pose = {}
	for _, joint in R6Pose.JOINTS do
		pose[joint] = { pitch = 0, roll = 0, yaw = 0, x = 0, y = 0, z = 0 }
	end
	return pose
end

-- Moves `into` toward a partial pose by `weight`. Fields a named joint leaves
-- out count as 0; joints it leaves out are untouched (or limited to `only`).
function R6Pose.blend(into: FullPose, pose: { [string]: any }, weight: number, only: { [string]: boolean }?)
	for joint, values in pose do
		local target = into[joint]
		if target and (not only or only[joint]) then
			for _, field in R6Pose.FIELDS do
				local value = values[field] or 0
				target[field] += (value - target[field]) * weight
			end
		end
	end
end

-- Adds a partial pose's angles on top of `into`.
function R6Pose.add(into: FullPose, pose: { [string]: any })
	for joint, values in pose do
		local target = into[joint]
		if target then
			for _, field in R6Pose.FIELDS do
				target[field] += values[field] or 0
			end
		end
	end
end

local function ease(alpha: number, style: string?): number
	if style == "out" then
		return 1 - (1 - alpha) * (1 - alpha)
	end
	return alpha * alpha * (3 - 2 * alpha)
end

-- The clip's pose at time `t`, for the joints the clip uses.
function R6Pose.sample(clip: any, t: number): FullPose
	local keys = clip.keys
	local out = R6Pose.empty()
	local previous = keys[1]
	local nextKey = keys[#keys]
	for index = 1, #keys do
		if keys[index].t <= t then
			previous = keys[index]
			nextKey = keys[math.min(index + 1, #keys)]
		end
	end
	local span = nextKey.t - previous.t
	local alpha = if span > 0 then math.clamp((t - previous.t) / span, 0, 1) else 1
	alpha = ease(alpha, nextKey.ease)
	for joint in clip.joints or {} do
		local a = previous.pose[joint] :: any
		local b = nextKey.pose[joint] :: any
		local target = out[joint]
		for _, field in R6Pose.FIELDS do
			local va = if a then a[field] or 0 else 0
			local vb = if b then b[field] or 0 else 0
			target[field] = va + (vb - va) * alpha
		end
	end
	return out
end

-- Leaning the torso swings the legs with it; this keeps them under the body.
function R6Pose.plantLegs(pose: FullPose)
	pose.RLeg.pitch += pose.Root.pitch
	pose.LLeg.pitch += pose.Root.pitch
end

local rad = math.rad

local function limbRotation(j: Values, mirrored: boolean): CFrame
	local pitch, roll, yaw = rad(j.pitch), rad(j.roll), rad(j.yaw)
	if mirrored then
		return CFrame.Angles(0, 0, -pitch) * CFrame.Angles(-roll, 0, 0) * CFrame.Angles(0, -yaw, 0)
	end
	return CFrame.Angles(0, 0, pitch) * CFrame.Angles(-roll, 0, 0) * CFrame.Angles(0, yaw, 0)
end

local function axialRotation(pitch: number, yaw: number, roll: number): CFrame
	return CFrame.Angles(0, 0, rad(yaw)) * CFrame.Angles(rad(pitch), 0, 0) * CFrame.Angles(0, rad(roll), 0)
end

-- Joint C0s for a full pose, given each joint's rest C0.
function R6Pose.c0s(base: { [string]: CFrame }, pose: FullPose): { [string]: CFrame }
	local root = pose.Root
	return {
		Root = CFrame.new(root.x, root.y, root.z) * base.Root * axialRotation(root.pitch, root.yaw, -root.roll),
		Neck = base.Neck * axialRotation(pose.Neck.pitch, pose.Neck.yaw, pose.Neck.roll),
		RArm = base.RArm * limbRotation(pose.RArm, false),
		LArm = base.LArm * limbRotation(pose.LArm, true),
		RLeg = base.RLeg * limbRotation(pose.RLeg, false),
		LLeg = base.LLeg * limbRotation(pose.LLeg, true),
	}
end

return R6Pose
