local PoseAnimator = require(script.Parent.PoseAnimator)

type Animation = PoseAnimator.Animation

local rad = math.rad
local QUART, SINE, LINEAR = Enum.EasingStyle.Quart, Enum.EasingStyle.Sine, Enum.EasingStyle.Linear
local OUT, IN_OUT = Enum.EasingDirection.Out, Enum.EasingDirection.InOut

local function rot(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

local function limb(pitch: number, yaw: number?, roll: number?): CFrame
	return CFrame.Angles(0, rad(yaw or 0), 0) * CFrame.Angles(0, 0, rad(roll or 0)) * CFrame.Angles(rad(pitch), 0, 0)
end

local function clip(keys: { any }, options: { [string]: any }): Animation
	local keyframes = {}
	for _, key in keys do
		table.insert(keyframes, { time = key[1], pose = key[2], easing = key[3], direction = key[4] })
	end
	local animation: any = options
	animation.keyframes = keyframes
	return animation :: Animation
end

local LEGS = { RightLeg = true, LeftLeg = true }

local NEUTRAL = {
	Torso = rot(0),
	Head = rot(0),
	RightArm = limb(0),
	LeftArm = limb(0),
	RightLeg = rot(0),
	LeftLeg = rot(0),
}

local function settle(twist: number)
	return {
		Torso = rot(5, twist),
		Head = rot(-6, twist * 1.5),
		RightArm = limb(6, 0, 10),
		LeftArm = limb(6, 0, -12),
		RightLeg = rot(-2),
		LeftLeg = rot(2),
	}
end

local Reactions: { [string]: Animation } = {}

Reactions.FlinchA = clip({
	{ 0, NEUTRAL },
	{
		0.05,
		{
			Torso = rot(14, 14, 5),
			Head = rot(-20, 18),
			RightArm = limb(20, 0, 35),
			LeftArm = limb(15, 0, -40),
			RightLeg = rot(-6),
			LeftLeg = rot(6),
		},
		QUART,
		OUT,
	},
	{ 0.3, settle(4), SINE, OUT },
}, { fadeIn = 0.045, fadeOut = 0.22, additive = LEGS })

Reactions.FlinchB = clip({
	{ 0, NEUTRAL },
	{
		0.05,
		{
			Torso = rot(14, -14, -5),
			Head = rot(-20, -18),
			RightArm = limb(15, 0, 40),
			LeftArm = limb(20, 0, -35),
			RightLeg = rot(6),
			LeftLeg = rot(-6),
		},
		QUART,
		OUT,
	},
	{ 0.3, settle(-4), SINE, OUT },
}, { fadeIn = 0.045, fadeOut = 0.22, additive = LEGS })

Reactions.FlinchBack = clip({
	{ 0, NEUTRAL },
	{
		0.05,
		{
			Torso = rot(-16),
			Head = rot(18),
			RightArm = limb(-25, 0, 25),
			LeftArm = limb(-25, 0, -25),
			RightLeg = rot(-6),
			LeftLeg = rot(6),
		},
		QUART,
		OUT,
	},
	{ 0.3, settle(0), SINE, OUT },
}, { fadeIn = 0.045, fadeOut = 0.22, additive = LEGS })

Reactions.HitHeavy = clip({
	{ 0, NEUTRAL },
	{
		0.06,
		{
			Torso = rot(26),
			Head = rot(-35),
			RightArm = limb(110, 0, 40),
			LeftArm = limb(110, 0, -40),
			RightLeg = rot(20),
			LeftLeg = rot(-12),
		},
		QUART,
		OUT,
	},
	{ 0.5, settle(0), SINE, IN_OUT },
}, { fadeIn = 0.05, fadeOut = 0.25, additive = LEGS })

local GUARD = {
	Torso = rot(-8, 6),
	Head = rot(12),
	RightArm = limb(120, 42),
	LeftArm = limb(118, -42),
}
local GUARD_PUSHED = {
	Torso = rot(6, 10),
	Head = rot(-4),
	RightArm = limb(105, 48),
	LeftArm = limb(100, -36),
}

Reactions.Guard = clip({
	{ 0, { Torso = rot(0), Head = rot(0), RightArm = limb(0), LeftArm = limb(0) } },
	{ 0.08, GUARD, QUART, OUT },
	{ 60, GUARD, LINEAR },
}, { fadeIn = 0.05, fadeOut = 0.15 })

Reactions.GuardHit = clip({
	{ 0, GUARD },
	{ 0.05, GUARD_PUSHED, QUART, OUT },
	{ 0.2, GUARD, SINE, OUT },
	{ 60, GUARD, LINEAR },
}, { fadeIn = 0.02, fadeOut = 0.15 })

local STAGGER = {
	Torso = rot(20, -10),
	Head = rot(-25, 8),
	RightArm = limb(140, 0, 30),
	LeftArm = limb(120, 0, -35),
	RightLeg = rot(16),
	LeftLeg = rot(-14),
}

Reactions.Stagger = clip({
	{ 0, NEUTRAL },
	{ 0.08, STAGGER, QUART, OUT },
	{ 1.0, STAGGER, LINEAR },
	{ 1.3, settle(0), SINE, IN_OUT },
}, { fadeIn = 0.02, fadeOut = 0.25 })

do
	local function grabbed(kick: number, arch: number)
		return {
			Torso = rot(10 + arch),
			Head = rot(-26 - arch),
			RightArm = limb(150 + arch * 2, -14, 6),
			LeftArm = limb(150 + arch * 2, 14, -6),
			RightLeg = rot(14 * kick),
			LeftLeg = rot(-12 * kick),
		}
	end
	local keys: { any } = { { 0, grabbed(0, 0) } }
	for i = 1, 14 do
		table.insert(
			keys,
			{ i * 0.18, grabbed(if i % 2 == 1 then 1 else -1, if i % 2 == 1 then 3 else 0), SINE, IN_OUT }
		)
	end
	Reactions.Grabbed = clip(keys, { fadeIn = 0.08, fadeOut = 0.2 })
end

do
	local function launched(flail: number)
		return {
			Torso = rot(20 + flail),
			Head = rot(-30),
			RightArm = limb(160 - flail * 3, 0, 30),
			LeftArm = limb(150 + flail * 3, 0, -35),
			RightLeg = rot(30 - flail * 2),
			LeftLeg = rot(-20 + flail * 2),
		}
	end
	local keys: { any } = { { 0, launched(0) } }
	for i = 1, 24 do
		table.insert(keys, { i * 0.25, launched(if i % 2 == 1 then 6 else -6), SINE, IN_OUT })
	end
	Reactions.Launched = clip(keys, { fadeIn = 0.1, fadeOut = 0.2 })
end

return Reactions
