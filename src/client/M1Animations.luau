local PoseAnimator = require(script.Parent.PoseAnimator)

type Animation = PoseAnimator.Animation

local rad = math.rad

local function rot(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

local function limb(pitch: number, yaw: number?, roll: number?): CFrame
	return CFrame.Angles(0, rad(yaw or 0), 0) * CFrame.Angles(0, 0, rad(roll or 0)) * CFrame.Angles(rad(pitch), 0, 0)
end

local LEGS_ADDITIVE = { RightLeg = true, LeftLeg = true }

local Clips: { [string]: Animation } = {}

local M1Animations = {}
M1Animations.Clips = Clips

Clips.Jab = {
	fadeIn = 0.03,
	fadeOut = 0.16,
	additive = LEGS_ADDITIVE,
	events = { { time = 0.04, name = "Strike" } },
	keyframes = {
		{
			time = 0,
			pose = {
				Torso = rot(0, -6),
				RightArm = limb(60, 20),
				LeftArm = limb(75, -25),
				RightLeg = rot(0, 6),
				LeftLeg = rot(0, 6),
			},
		},
		{
			time = 0.04,
			pose = {
				Torso = rot(0, -16),
				RightArm = limb(45, 10),
				LeftArm = limb(80, -28),
				Head = rot(0, 14),
				RightLeg = rot(0, 16),
				LeftLeg = rot(0, 16),
			},
		},
		{
			time = 0.1,
			easing = Enum.EasingStyle.Back,
			pose = {
				Torso = rot(-5, 22),
				RightArm = limb(94, 12),
				LeftArm = limb(62, -30),
				Head = rot(0, -18),
				RightLeg = rot(0, -22),
				LeftLeg = rot(0, -22),
			},
		},
		{
			time = 0.2,
			pose = {
				Torso = rot(-4, 18),
				RightArm = limb(90, 12),
				LeftArm = limb(62, -30),
				Head = rot(0, -15),
				RightLeg = rot(0, -18),
				LeftLeg = rot(0, -18),
			},
		},
	},
}

Clips.Cross = {
	fadeIn = 0.03,
	fadeOut = 0.16,
	additive = LEGS_ADDITIVE,
	events = { { time = 0.04, name = "Strike" } },
	keyframes = {
		{
			time = 0,
			pose = {
				Torso = rot(0, 10),
				RightArm = limb(80, 28),
				LeftArm = limb(60, -18),
				RightLeg = rot(0, -10),
				LeftLeg = rot(0, -10),
			},
		},
		{
			time = 0.04,
			pose = {
				Torso = rot(0, 18),
				RightArm = limb(80, 28),
				LeftArm = limb(42, -10),
				Head = rot(0, -14),
				RightLeg = rot(0, -18),
				LeftLeg = rot(0, -18),
			},
		},
		{
			time = 0.1,
			easing = Enum.EasingStyle.Back,
			pose = {
				Torso = rot(-6, -24),
				RightArm = limb(62, 30),
				LeftArm = limb(94, -12),
				Head = rot(0, 20),
				RightLeg = rot(0, 24),
				LeftLeg = rot(0, 24),
			},
		},
		{
			time = 0.2,
			pose = {
				Torso = rot(-5, -20),
				RightArm = limb(62, 30),
				LeftArm = limb(90, -12),
				Head = rot(0, 16),
				RightLeg = rot(0, 20),
				LeftLeg = rot(0, 20),
			},
		},
	},
}

Clips.Hook = {
	fadeIn = 0.03,
	fadeOut = 0.18,
	additive = LEGS_ADDITIVE,
	events = { { time = 0.05, name = "Strike" } },
	keyframes = {
		{
			time = 0,
			pose = {
				Torso = rot(0, -10),
				RightArm = limb(70, -10),
				LeftArm = limb(75, -25),
				RightLeg = rot(0, 10),
				LeftLeg = rot(0, 10),
			},
		},
		{
			time = 0.05,
			pose = {
				Torso = rot(0, -28),
				RightArm = limb(75, -55),
				LeftArm = limb(80, -28),
				Head = rot(0, 22),
				RightLeg = rot(0, 26),
				LeftLeg = rot(0, 26),
			},
		},
		{
			time = 0.12,
			easing = Enum.EasingStyle.Back,
			pose = {
				Torso = rot(-7, 32),
				RightArm = limb(88, 40),
				LeftArm = limb(65, -30),
				Head = rot(0, -26),
				RightLeg = rot(0, -30),
				LeftLeg = rot(0, -30),
			},
		},
		{
			time = 0.22,
			pose = {
				Torso = rot(-6, 28),
				RightArm = limb(85, 38),
				LeftArm = limb(65, -30),
				Head = rot(0, -22),
				RightLeg = rot(0, -26),
				LeftLeg = rot(0, -26),
			},
		},
	},
}

Clips.Kick = {
	fadeIn = 0.04,
	fadeOut = 0.22,
	events = { { time = 0.09, name = "Strike" } },
	keyframes = {
		{
			time = 0,
			pose = {
				Torso = rot(0, -8),
				RightArm = limb(70, 20),
				LeftArm = limb(75, -25),
			},
		},
		{
			time = 0.09,
			pose = {
				Torso = rot(8, -14),
				RightArm = limb(25, 0, 25),
				LeftArm = limb(60, -20),
				Head = rot(-6, 10),
				RightLeg = rot(-30),
				LeftLeg = rot(5),
			},
		},
		{
			time = 0.16,
			easing = Enum.EasingStyle.Back,
			pose = {
				Torso = rot(20, 16),
				RightArm = limb(-20, 0, 45),
				LeftArm = limb(10, 0, -70),
				Head = rot(-18, -12),
				RightLeg = rot(98),
				LeftLeg = rot(-20),
			},
		},
		{
			time = 0.32,
			pose = {
				Torso = rot(18, 14),
				RightArm = limb(-15, 0, 40),
				LeftArm = limb(10, 0, -65),
				Head = rot(-16, -10),
				RightLeg = rot(92),
				LeftLeg = rot(-18),
			},
		},
	},
}

Clips.Uppercut = {
	fadeIn = 0.04,
	fadeOut = 0.22,
	additive = LEGS_ADDITIVE,
	events = { { time = 0.09, name = "Strike" } },
	keyframes = {
		{
			time = 0,
			pose = {
				Torso = rot(0, -8),
				RightArm = limb(60, 15),
				LeftArm = limb(75, -25),
			},
		},
		{
			time = 0.09,
			pose = {
				Torso = rot(-18, -18),
				RightArm = limb(-25, 5),
				LeftArm = limb(80, -28),
				Head = rot(12, 12),
				RightLeg = rot(-8, 18),
				LeftLeg = rot(15, 18),
			},
		},
		{
			time = 0.16,
			easing = Enum.EasingStyle.Back,
			pose = {
				Torso = rot(14, 22),
				RightArm = limb(168, 10),
				LeftArm = limb(35, -20),
				Head = rot(-20, -16),
				RightLeg = rot(0, -20),
				LeftLeg = rot(0, -20),
			},
		},
		{
			time = 0.32,
			pose = {
				Torso = rot(12, 18),
				RightArm = limb(165, 10),
				LeftArm = limb(35, -20),
				Head = rot(-18, -14),
				RightLeg = rot(0, -16),
				LeftLeg = rot(0, -16),
			},
		},
	},
}

Clips.Downslam = {
	fadeIn = 0.04,
	fadeOut = 0.22,
	events = { { time = 0.09, name = "Strike" } },
	keyframes = {
		{
			time = 0,
			pose = {
				Torso = rot(0),
				RightArm = limb(80, 10),
				LeftArm = limb(80, -10),
			},
		},
		{
			time = 0.09,
			pose = {
				Torso = rot(18),
				RightArm = limb(172, 12),
				LeftArm = limb(172, -12),
				Head = rot(-15),
				RightLeg = rot(-20),
				LeftLeg = rot(10),
			},
		},
		{
			time = 0.16,
			easing = Enum.EasingStyle.Back,
			pose = {
				Torso = rot(-32),
				RightArm = limb(45, 15),
				LeftArm = limb(45, -15),
				Head = rot(18),
				RightLeg = rot(30),
				LeftLeg = rot(20),
			},
		},
		{
			time = 0.32,
			pose = {
				Torso = rot(-28),
				RightArm = limb(50, 15),
				LeftArm = limb(50, -15),
				Head = rot(15),
				RightLeg = rot(25),
				LeftLeg = rot(18),
			},
		},
	},
}

M1Animations.Strikers = {
	Jab = { "Right Arm" },
	Cross = { "Left Arm" },
	Hook = { "Right Arm" },
	Kick = { "Right Leg" },
	Uppercut = { "Right Arm" },
	Downslam = { "Right Arm", "Left Arm" },
}

local STRING = { "Jab", "Cross", "Hook" }
local FINISHERS = { Knockback = "Kick", Uppercut = "Uppercut", Downslam = "Downslam" }

function M1Animations.NameFor(index: number, variant: string): string
	if variant ~= "Normal" then
		return FINISHERS[variant] or "Kick"
	end
	return STRING[((index - 1) % #STRING) + 1]
end

return M1Animations
