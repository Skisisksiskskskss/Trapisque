--[[
	Animations: the pose and clip library for the procedural R6 animator
	(client/Animator). No uploaded animation assets are needed.

	A pose sets angles (degrees) on some of the six R6 joints:
		Root  torso relative to the root: pitch (lean forward +), yaw (turn left +),
		      roll (lean right +), and x/y/z offsets in studs (root space)
		Neck  pitch (nod down +), yaw (look left +), roll
		RArm, LArm  pitch (raise forward +), roll (raise outward +), yaw (twist)
		RLeg, LLeg  pitch (kick forward +), roll (spread outward +)

	A clip is a list of timed keyframes. Joints a clip never mentions keep
	playing the walk/run/idle underneath, so swings layer over running legs.
]]

export type Joint = { pitch: number?, roll: number?, yaw: number?, x: number?, y: number?, z: number? }
export type Pose = { [string]: Joint }
export type Key = { t: number, pose: Pose, ease: string? }
export type Clip = { duration: number, keys: { Key }, joints: { [string]: boolean }?, loop: boolean? }

local Animations = {}

Animations.JOINTS = { "Root", "Neck", "RArm", "LArm", "RLeg", "LLeg" }

local function J(pitch: number?, roll: number?, yaw: number?): Joint
	return { pitch = pitch or 0, roll = roll or 0, yaw = yaw or 0 }
end

local function R(pitch: number?, yaw: number?, roll: number?, x: number?, y: number?, z: number?): Joint
	return { pitch = pitch or 0, yaw = yaw or 0, roll = roll or 0, x = x or 0, y = y or 0, z = z or 0 }
end

-- Neck poses read as (pitch, yaw, roll): nod, look left/right, tilt.
local function N(pitch: number?, yaw: number?, roll: number?): Joint
	return { pitch = pitch or 0, yaw = yaw or 0, roll = roll or 0 }
end

Animations.J = J
Animations.N = N
Animations.R = R

-- Clips ------------------------------------------------------------------------------
-- Swings follow a windup -> strike -> recover rhythm. Strike frames land at the
-- M1 hit frame (Config.M1_STARTUP = 0.2s).

local clips: { [string]: Clip } = {}

-- Brush: quick one-handed slashes.
clips.BrushM1_1 = {
	duration = 0.34,
	keys = {
		{ t = 0, pose = { Root = R(4, -28), RArm = J(75, 55, 10), Neck = N(0, 20) } },
		{ t = 0.12, pose = { Root = R(6, -32), RArm = J(85, 70, 20), LArm = J(10, 25) } },
		{
			t = 0.2,
			pose = { Root = R(10, 30, 0, 0, 0, -0.3), RArm = J(88, -35, -10), LArm = J(-15, 30) },
			ease = "out",
		},
		{ t = 0.34, pose = { Root = R(4, 10), RArm = J(40, 0), LArm = J(5, 15) } },
	},
}
clips.BrushM1_2 = {
	duration = 0.34,
	keys = {
		{ t = 0, pose = { Root = R(4, 25), RArm = J(80, -35, -10), Neck = N(0, -15) } },
		{ t = 0.12, pose = { Root = R(6, 32), RArm = J(85, -45, -15), LArm = J(15, 20) } },
		{ t = 0.2, pose = { Root = R(10, -30, 0, 0, 0, -0.3), RArm = J(85, 65, 15), LArm = J(-10, 35) }, ease = "out" },
		{ t = 0.34, pose = { Root = R(4, -8), RArm = J(40, 15), LArm = J(5, 15) } },
	},
}
clips.BrushM1_3 = {
	duration = 0.36,
	keys = {
		{ t = 0, pose = { Root = R(-6, -10), RArm = J(150, 20, 0), LArm = J(30, 20) } },
		{ t = 0.12, pose = { Root = R(-10, -14), RArm = J(170, 25, 0), LArm = J(40, 25) } },
		{
			t = 0.2,
			pose = { Root = R(20, 8, 0, 0, -0.1, -0.4), RArm = J(35, -15, 0), LArm = J(-20, 30) },
			ease = "out",
		},
		{ t = 0.36, pose = { Root = R(6, 0), RArm = J(35, 5), LArm = J(5, 15) } },
	},
}
clips.BrushNeutral = {
	duration = 0.5,
	keys = {
		{ t = 0, pose = { Root = R(0, -45), RArm = J(70, 75, 10), LArm = J(40, -20), Neck = N(0, 30) } },
		{ t = 0.14, pose = { Root = R(4, -55), RArm = J(80, 85, 20), LArm = J(45, -25) } },
		{
			t = 0.22,
			pose = { Root = R(14, 55, 0, 0, 0, -0.6), RArm = J(90, -45, -20), LArm = J(-30, 45), Neck = N(5, -20) },
			ease = "out",
		},
		{ t = 0.5, pose = { Root = R(6, 15), RArm = J(45, 5), LArm = J(5, 15) } },
	},
}
clips.BrushUppercut = {
	duration = 0.5,
	keys = {
		{ t = 0, pose = { Root = R(18, -10, 0, 0, -0.3), RArm = J(-35, 15), LArm = J(20, 15), Neck = N(-10) } },
		{ t = 0.14, pose = { Root = R(22, -12, 0, 0, -0.4), RArm = J(-45, 20), LArm = J(25, 20) } },
		{
			t = 0.22,
			pose = { Root = R(-18, 10, 0, 0, 0.2), RArm = J(175, -10), LArm = J(-25, 35), Neck = N(-25) },
			ease = "out",
		},
		{ t = 0.5, pose = { Root = R(-4, 0), RArm = J(60, 5), LArm = J(5, 20), Neck = N(-5) } },
	},
}
clips.BrushDownslam = {
	duration = 0.5,
	keys = {
		{ t = 0, pose = { Root = R(-12, 0), RArm = J(170, 10), LArm = J(150, 10), Neck = N(-10) } },
		{ t = 0.14, pose = { Root = R(-16, 0), RArm = J(178, 10), LArm = J(165, 10) } },
		{
			t = 0.22,
			pose = { Root = R(38, 0, 0, 0, -0.3), RArm = J(25, 5), LArm = J(30, 5), Neck = N(15) },
			ease = "out",
		},
		{ t = 0.5, pose = { Root = R(10, 0), RArm = J(40, 5), LArm = J(10, 10) } },
	},
}

-- Roller: heavy two-handed swings with bigger windups.
clips.RollerM1_1 = {
	duration = 0.36,
	keys = {
		{ t = 0, pose = { Root = R(2, -35), RArm = J(60, 60, 15), LArm = J(55, -15), Neck = N(0, 25) } },
		{ t = 0.13, pose = { Root = R(4, -42), RArm = J(65, 75, 20), LArm = J(60, -10) } },
		{
			t = 0.2,
			pose = { Root = R(10, 35, 0, 0, -0.1, -0.3), RArm = J(85, -25, -10), LArm = J(75, -45) },
			ease = "out",
		},
		{ t = 0.36, pose = { Root = R(4, 8), RArm = J(35, 5), LArm = J(25, -10) } },
	},
}
clips.RollerM1_2 = {
	duration = 0.36,
	keys = {
		{ t = 0, pose = { Root = R(2, 32), RArm = J(70, -30, -10), LArm = J(65, -35), Neck = N(0, -20) } },
		{ t = 0.13, pose = { Root = R(4, 40), RArm = J(75, -40, -15), LArm = J(70, -45) } },
		{
			t = 0.2,
			pose = { Root = R(10, -35, 0, 0, -0.1, -0.3), RArm = J(80, 70, 15), LArm = J(60, 0) },
			ease = "out",
		},
		{ t = 0.36, pose = { Root = R(4, -6), RArm = J(35, 15), LArm = J(25, -5) } },
	},
}
clips.RollerM1_3 = {
	duration = 0.38,
	keys = {
		{ t = 0, pose = { Root = R(-10, 0), RArm = J(165, 10), LArm = J(160, -10), Neck = N(-10) } },
		{ t = 0.13, pose = { Root = R(-14, 0), RArm = J(175, 10), LArm = J(170, -10) } },
		{ t = 0.2, pose = { Root = R(28, 0, 0, 0, -0.2, -0.4), RArm = J(40, -5), LArm = J(45, -20) }, ease = "out" },
		{ t = 0.38, pose = { Root = R(6, 0), RArm = J(35, 5), LArm = J(25, -10) } },
	},
}
clips.RollerNeutral = {
	duration = 0.55,
	keys = {
		{ t = 0, pose = { Root = R(0, -60), RArm = J(55, 80, 15), LArm = J(50, 10), Neck = N(0, 35) } },
		{ t = 0.15, pose = { Root = R(4, -70), RArm = J(60, 90, 20), LArm = J(55, 15) } },
		{
			t = 0.23,
			pose = { Root = R(16, 65, 0, 0, -0.1, -0.7), RArm = J(90, -40, -20), LArm = J(80, -50), Neck = N(5, -25) },
			ease = "out",
		},
		{ t = 0.55, pose = { Root = R(6, 15), RArm = J(40, 5), LArm = J(25, -5) } },
	},
}
clips.RollerUppercut = clips.BrushUppercut
clips.RollerDownslam = clips.BrushDownslam

-- Dashes.
clips.DashFront = {
	duration = 0.36,
	keys = {
		{
			t = 0,
			pose = { Root = R(28, 0, 0, 0, -0.2), RArm = J(-50, 20), LArm = J(-50, 20), RLeg = J(35), LLeg = J(-30) },
		},
		{
			t = 0.28,
			pose = { Root = R(32, 0, 0, 0, -0.25), RArm = J(85, -10), LArm = J(-55, 25), RLeg = J(30), LLeg = J(-25) },
		},
		{ t = 0.36, pose = { Root = R(10, 0), RArm = J(30), LArm = J(0, 15) } },
	},
}
clips.DashLeft = {
	duration = 0.24,
	keys = {
		{
			t = 0,
			pose = {
				Root = R(6, 10, -18, 0, -0.3),
				RArm = J(10, 35),
				LArm = J(-10, 50),
				RLeg = J(0, 25),
				LLeg = J(0, -5),
			},
		},
		{ t = 0.18, pose = { Root = R(6, 12, -22, 0, -0.35), RArm = J(15, 40), LArm = J(-15, 60), RLeg = J(0, 30) } },
		{ t = 0.24, pose = { Root = R(4, 0, 0), RArm = J(20, 10), LArm = J(0, 15) } },
	},
}
clips.DashRight = {
	duration = 0.24,
	keys = {
		{
			t = 0,
			pose = {
				Root = R(6, -10, 18, 0, -0.3),
				RArm = J(-10, 50),
				LArm = J(10, 35),
				RLeg = J(0, -5),
				LLeg = J(0, 25),
			},
		},
		{ t = 0.18, pose = { Root = R(6, -12, 22, 0, -0.35), RArm = J(-15, 60), LArm = J(15, 40), LLeg = J(0, 30) } },
		{ t = 0.24, pose = { Root = R(4, 0, 0), RArm = J(20, 10), LArm = J(0, 15) } },
	},
}
clips.DashBack = {
	duration = 0.24,
	keys = {
		{
			t = 0,
			pose = { Root = R(-16, 0, 0, 0, -0.2), RArm = J(40, 25), LArm = J(40, 25), RLeg = J(25), LLeg = J(-10) },
		},
		{ t = 0.24, pose = { Root = R(-4, 0), RArm = J(20, 10), LArm = J(5, 15) } },
	},
}

-- Skills.
clips.SkillThrow = {
	duration = 0.4,
	keys = {
		{ t = 0, pose = { Root = R(-8, -25), RArm = J(165, 25), LArm = J(40, -10), Neck = N(-5, 15) } },
		{ t = 0.12, pose = { Root = R(-10, -30), RArm = J(175, 30), LArm = J(50, -10) } },
		{ t = 0.2, pose = { Root = R(16, 20, 0, 0, 0, -0.3), RArm = J(45, -15), LArm = J(-20, 30) }, ease = "out" },
		{ t = 0.4, pose = { Root = R(4, 5), RArm = J(30, 5), LArm = J(5, 15) } },
	},
}
-- The brush points along the hand, so a low arm aims it forward like a nozzle.
clips.SkillSpray = {
	duration = 0.5,
	keys = {
		{ t = 0, pose = { Root = R(4, -10), RArm = J(22, 4), LArm = J(45, -38), Neck = N(0, 10) } },
		{ t = 0.1, pose = { Root = R(0, -10, 0, 0, 0, 0.15), RArm = J(30, 4), LArm = J(48, -38) } },
		{ t = 0.2, pose = { Root = R(4, -10), RArm = J(22, 4), LArm = J(45, -38) } },
		{ t = 0.3, pose = { Root = R(0, -10, 0, 0, 0, 0.15), RArm = J(30, 4), LArm = J(48, -38) } },
		{ t = 0.5, pose = { Root = R(2, 0), RArm = J(25, 5), LArm = J(10, 15) } },
	},
}
clips.SkillDashForward = {
	duration = 0.34,
	keys = {
		{
			t = 0,
			pose = { Root = R(26, 0, 0, 0, -0.25), RArm = J(95, -5), LArm = J(-45, 25), RLeg = J(35), LLeg = J(-35) },
		},
		{
			t = 0.28,
			pose = { Root = R(30, 0, 0, 0, -0.3), RArm = J(95, 5), LArm = J(-50, 30), RLeg = J(30), LLeg = J(-30) },
		},
		{ t = 0.34, pose = { Root = R(8, 0), RArm = J(35, 5), LArm = J(5, 15) } },
	},
}
clips.SkillCharge = {
	duration = 0.55,
	keys = {
		{
			t = 0,
			pose = { Root = R(24, 0, 0, 0, -0.25), RArm = J(70, 5), LArm = J(65, -30), RLeg = J(40), LLeg = J(-35) },
		},
		{
			t = 0.25,
			pose = { Root = R(28, 0, 0, 0, -0.3), RArm = J(75, 5), LArm = J(70, -30), RLeg = J(-35), LLeg = J(40) },
		},
		{
			t = 0.5,
			pose = { Root = R(28, 0, 0, 0, -0.3), RArm = J(75, 5), LArm = J(70, -30), RLeg = J(40), LLeg = J(-35) },
		},
		{ t = 0.55, pose = { Root = R(8, 0), RArm = J(35, 5), LArm = J(20, -5) } },
	},
}
clips.SkillSweep = {
	duration = 0.5,
	keys = {
		{ t = 0, pose = { Root = R(4, -50), RArm = J(65, 70), LArm = J(60, -10), Neck = N(0, 30) } },
		{ t = 0.12, pose = { Root = R(6, -58), RArm = J(70, 80), LArm = J(65, -5) } },
		{ t = 0.22, pose = { Root = R(12, 50, 0, 0, 0, -0.4), RArm = J(85, -40), LArm = J(80, -45) }, ease = "out" },
		{ t = 0.5, pose = { Root = R(4, 10), RArm = J(35, 5), LArm = J(15, 5) } },
	},
}
clips.SkillSlamRise = {
	duration = 0.75,
	keys = {
		{
			t = 0,
			pose = { Root = R(15, 0, 0, 0, -0.3), RArm = J(-30, 20), LArm = J(-30, 20), RLeg = J(20), LLeg = J(20) },
		},
		{ t = 0.12, pose = { Root = R(-15, 0), RArm = J(175, 15), LArm = J(175, 15), RLeg = J(55), LLeg = J(35) } },
		{ t = 0.35, pose = { Root = R(-10, 0), RArm = J(178, 10), LArm = J(178, 10), RLeg = J(60), LLeg = J(40) } },
		{
			t = 0.45,
			pose = { Root = R(35, 0), RArm = J(40, 10), LArm = J(40, 10), RLeg = J(20), LLeg = J(-10) },
			ease = "out",
		},
		{ t = 0.75, pose = { Root = R(8, 0), RArm = J(35, 5), LArm = J(15, 10) } },
	},
}
clips.Awaken = {
	duration = 1.2,
	keys = {
		{ t = 0, pose = { Root = R(20, 0, 0, 0, -0.3), RArm = J(10, -20), LArm = J(10, -20), Neck = N(20) } },
		{ t = 0.35, pose = { Root = R(24, 0, 0, 0, -0.35), RArm = J(15, -30), LArm = J(15, -30), Neck = N(25) } },
		{
			t = 0.5,
			pose = {
				Root = R(-18, 0),
				RArm = J(30, 85),
				LArm = J(30, 85),
				Neck = N(-30),
				RLeg = J(10, 15),
				LLeg = J(-10, 15),
			},
			ease = "out",
		},
		{ t = 1, pose = { Root = R(-15, 0), RArm = J(30, 80), LArm = J(30, 80), Neck = N(-25) } },
		{ t = 1.2, pose = { Root = R(2, 0), RArm = J(20, 10), LArm = J(5, 15) } },
	},
}
clips.HitReact = {
	duration = 0.28,
	keys = {
		{ t = 0, pose = { Root = R(-14, 6, 0, 0, 0, 0.2), Neck = N(-18), RArm = J(-15, 25), LArm = J(-10, 30) } },
		{ t = 0.28, pose = { Root = R(0, 0), Neck = N(0), RArm = J(15, 10), LArm = J(5, 10) } },
	},
}
clips.Evasive = {
	duration = 0.3,
	keys = {
		{
			t = 0,
			pose = {
				Root = R(10, 0, -20, 0, -0.4),
				RArm = J(-20, 50),
				LArm = J(-20, 50),
				RLeg = J(30, 20),
				LLeg = J(-20, 20),
			},
		},
		{ t = 0.3, pose = { Root = R(4, 0, 0), RArm = J(15, 10), LArm = J(5, 15) } },
	},
}

for _, clip in clips do
	local joints = {}
	for _, key in clip.keys do
		for joint in key.pose do
			joints[joint] = true
		end
	end
	clip.joints = joints
end

Animations.CLIPS = clips

-- Locomotion -----------------------------------------------------------------------------
-- Procedural cycles, sampled by the animator from speed and a running phase.

-- How each weapon is held at rest (added to every locomotion pose).
Animations.HOLD = {
	Brush = { RArm = J(22, 6, -8) },
	Roller = { RArm = J(18, 10, -5), LArm = J(10, -4) },
}

function Animations.idle(t: number): Pose
	local breathe = math.sin(t * 2.2)
	return {
		Root = R(3 + breathe * 1.2, 0, 0, 0, breathe * 0.03),
		Neck = N(-3 - breathe * 1),
		RArm = J(8 + breathe * 2, 9),
		LArm = J(6 + breathe * 2, 9),
		RLeg = J(5, 4),
		LLeg = J(-4, 4),
	}
end

function Animations.walk(phase: number): Pose
	local s = math.sin(phase)
	local bob = math.abs(math.cos(phase))
	return {
		Root = R(5, s * 4, 0, 0, -bob * 0.08),
		Neck = N(-4, 0, -s * 3),
		RArm = J(-s * 32 + 6, 8),
		LArm = J(s * 32 + 6, 8),
		RLeg = J(s * 34),
		LLeg = J(-s * 34),
	}
end

-- JJS-style sprint: hard forward lean and big arm pumps.
function Animations.run(phase: number): Pose
	local s = math.sin(phase)
	local bob = math.abs(math.cos(phase))
	return {
		Root = R(18, s * 8, 0, 0, -bob * 0.18),
		Neck = N(-14, 0, -s * 4),
		RArm = J(-s * 68 + 5, 12, 0),
		LArm = J(s * 68 + 5, 12, 0),
		RLeg = J(s * 62),
		LLeg = J(-s * 62),
	}
end

function Animations.jump(): Pose
	return {
		Root = R(-6, 0),
		Neck = N(-6),
		RArm = J(25, 30),
		LArm = J(15, 35),
		RLeg = J(35),
		LLeg = J(-12),
	}
end

function Animations.fall(t: number): Pose
	local flutter = math.sin(t * 9) * 4
	return {
		Root = R(4, 0),
		Neck = N(5),
		RArm = J(15, 62 + flutter),
		LArm = J(15, 62 - flutter),
		RLeg = J(14, 6),
		LLeg = J(-10, 6),
	}
end

Animations.BLOCK = {
	Root = R(-4, 0, 0, 0, -0.15),
	Neck = N(8),
	RArm = J(92, -42, 10),
	LArm = J(96, -48, -10),
	RLeg = J(-10, 6),
	LLeg = J(16, 6),
}

Animations.STUNNED = {
	Root = R(-10, 5),
	Neck = N(-14, 8),
	RArm = J(-10, 22),
	LArm = J(-14, 26),
}

return Animations
