--[[
	Anti-Magic Knight (Asta), client side: sword animations, skill VFX and
	the Black Form look. The server sends ("Skill", {skill, phase, ...})
	events; see ServerScriptService.Server.Kits.AntiMagic for the gameplay.

	Visual language: black anti-magic with dark red edges, black smoke,
	sharp slash arcs and rock-cracking impacts.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraShake = require(script.Parent.Parent.CameraShake)
local PoseAnimator = require(script.Parent.Parent.PoseAnimator)
local VFX = require(script.Parent.Parent.VFX)

local U = VFX.Util

type Animation = PoseAnimator.Animation

local BLACK = Color3.fromRGB(8, 8, 10)
local RED = Color3.fromRGB(200, 25, 35)
local DARK_RED = Color3.fromRGB(110, 8, 18)
local WHITE = Color3.new(1, 1, 1)

local rad = math.rad
local UP = Vector3.yAxis

local Kit = {}

VFX.SetPalette("AntiMagic", {
	hit = Color3.fromRGB(220, 50, 60),
	heavy = Color3.fromRGB(170, 15, 25),
	flash = Color3.fromRGB(255, 225, 225),
	cleanM1 = true, -- sleek sword M1s: no sparks or rings on hit
})

---------------------------------------------------------------------------
-- Pose helpers (same conventions as M1Animations)
---------------------------------------------------------------------------

local function rot(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

local function limb(pitch: number, yaw: number?, roll: number?): CFrame
	return CFrame.Angles(0, rad(yaw or 0), 0) * CFrame.Angles(0, 0, rad(roll or 0)) * CFrame.Angles(rad(pitch), 0, 0)
end

-- Builds an animation from { {time, pose, easing?, direction?}, ... }.
-- The sword's wrist joint is always posed (neutral grip if not given),
-- otherwise the idle's shoulder-rest wrist would leak into other moves.
local function clip(keys: { any }, options: { [string]: any }?): Animation
	local keyframes = {}
	for _, key in keys do
		local pose = table.clone(key[2])
		pose.Sword = pose.Sword or CFrame.identity
		table.insert(keyframes, { time = key[1], pose = pose, easing = key[3], direction = key[4] })
	end
	local animation: any = options or {}
	animation.keyframes = keyframes
	return animation :: Animation
end

-- The grip the server welds the sword with (see Server/Kits/AntiMagic).
local GRIP = CFrame.Angles(rad(215), 0, 0)
local BLADE_REST = GRIP:VectorToWorldSpace(Vector3.yAxis) -- blade direction in arm space, neutral wrist

-- Wrist rotation that points the blade along `direction` (character space),
-- given the torso and arm poses of the same keyframe.
local function solveWrist(torso: CFrame, arm: CFrame, direction: Vector3): CFrame
	local armRotation = torso.Rotation * arm.Rotation
	local target = armRotation:VectorToObjectSpace(direction.Unit)
	local axis = BLADE_REST:Cross(target)
	local angle = math.acos(math.clamp(BLADE_REST:Dot(target), -1, 1))
	if axis.Magnitude < 1e-5 then
		return if angle < 1 then CFrame.identity else CFrame.fromAxisAngle(Vector3.xAxis, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, angle)
end

-- Turns generated animation data (Animations.luau) into a playable Animation.
local function build(raw: { [string]: any }): Animation
	local keyframes = {}
	for _, key in raw.keys do
		local pose: { [string]: CFrame } = {}
		local sword = nil
		for name, value in key[2] do
			if name == "Sword" then
				sword = value
			else
				pose[name] = value
			end
		end
		pose.Sword = if type(sword) == "table"
			then solveWrist(pose.Torso or CFrame.identity, pose.RightArm or CFrame.identity, sword.aim)
			else CFrame.identity
		table.insert(keyframes, {
			time = key[1],
			pose = pose,
			easing = if key[3] then (Enum.EasingStyle :: any)[key[3]] else nil,
			direction = if key[4] then (Enum.EasingDirection :: any)[key[4]] else nil,
		})
	end
	return {
		keyframes = keyframes,
		loop = raw.loop,
		fadeIn = raw.fadeIn,
		fadeOut = raw.fadeOut,
		additive = raw.additive,
		delays = raw.delays,
		events = raw.events,
	}
end

local Generated = require(script.Animations)
local ANIMS: { [string]: Animation } = {}
for name, raw in Generated do
	ANIMS[name] = build(raw)
end

local LEGS_ADDITIVE = { RightLeg = true, LeftLeg = true }
local BACK = Enum.EasingStyle.Back

-- Starting pose for skills: sword held up in front (neutral wrist).
local READY = {
	Torso = rot(0, -5),
	RightArm = limb(50, 15),
	LeftArm = limb(40, -20),
}

-- Signature stance: wide footing, the greatsword resting on the right
-- shoulder, slow breathing. Runs leaning forward with the sword bobbing on
-- his shoulder; knee up and free arm out in the air.
Kit.Idle = {
	stand = ANIMS.Idle,
	move = ANIMS.Run,
	air = ANIMS.Air,
	moveSpeed = 16,
}

-- Getting hit / blocking, with the sword (see Client/Reactions for the names).
Kit.Reactions = {
	FlinchA = ANIMS.FlinchA,
	FlinchB = ANIMS.FlinchB,
	FlinchBack = ANIMS.FlinchBack,
	HitHeavy = ANIMS.HitHeavy,
	Guard = ANIMS.Guard,
	GuardHit = ANIMS.GuardHit,
	Stagger = ANIMS.Stagger,
}

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------

local function getSword(character: Model): Model?
	return character:FindFirstChild("KitWeapon") :: Model?
end

-- Turns the blade's swing trail on for `duration` (locally).
local function swordTrail(character: Model, duration: number)
	local sword = getSword(character)
	local blade = sword and sword:FindFirstChild("Blade")
	local trail = blade and blade:FindFirstChild("SwingTrail")
	if trail and trail:IsA("Trail") then
		trail.Enabled = true
		task.delay(duration, function()
			trail.Enabled = false
		end)
	end
end

-- Red glow on the sword (charging, perfect timing flash).
local function swordGlow(character: Model, color: Color3, duration: number, fill: number?)
	local sword = getSword(character)
	if not sword then
		return
	end
	local glow = Instance.new("Highlight")
	glow.Adornee = sword
	glow.FillColor = color
	glow.OutlineColor = color
	glow.FillTransparency = fill or 0.2
	glow.OutlineTransparency = 0
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = U.folder
	U.tween(
		glow,
		duration,
		{ FillTransparency = 1, OutlineTransparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(duration, glow.Destroy, glow)
end

-- Black crescent with a red edge glow, following the character.
local function slashArc(character: Model, from: CFrame, to: CFrame, width: number, duration: number)
	local root = U.getRoot(character)
	if not root then
		return
	end
	local holder = U.newPart({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = root.CFrame })
	local forward = CFrame.Angles(0, rad(90), 0) -- attachment X axis forward, so the curve bulges out front
	local a0 = Instance.new("Attachment")
	a0.CFrame = from * forward
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.CFrame = to * forward
	a1.Parent = holder

	local function beam(color: Color3, emission: number, w: number, curve: number): Beam
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.CurveSize0 = curve
		b.CurveSize1 = -curve
		b.Segments = 24
		b.FaceCamera = true
		b.LightEmission = emission
		b.LightInfluence = 0
		b.Color = ColorSequence.new(color)
		b.Width0 = 0.1
		b.Width1 = w
		b.Parent = holder
		return b
	end
	local glow = beam(RED, 1, width * 1.35, 3.8)
	local core = beam(BLACK, 0, width, 3.6)

	local follow = RunService.RenderStepped:Connect(function()
		if root.Parent then
			holder.CFrame = root.CFrame
		end
	end)
	local start = os.clock()
	local fade
	fade = RunService.RenderStepped:Connect(function()
		local alpha = math.min((os.clock() - start) / duration, 1)
		local sequence = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.1 + 0.9 * alpha),
			NumberSequenceKeypoint.new(1, alpha),
		})
		core.Transparency = sequence
		glow.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.5 + 0.5 * alpha),
			NumberSequenceKeypoint.new(1, 0.4 + 0.6 * alpha),
		})
		if alpha >= 1 then
			fade:Disconnect()
			follow:Disconnect()
			holder:Destroy()
		end
	end)
end

-- Black anti-magic smoke burst.
local function blackSmoke(position: Vector3, count: number, size: number, speed: number?)
	U.burst(position, {
		texture = U.textures.Smoke,
		color = BLACK,
		count = count,
		size = size,
		speed = NumberRange.new((speed or 10) * 0.5, speed or 10),
		lifetime = NumberRange.new(0.4, 0.8),
		lightEmission = 0,
		transparency = 0.1,
		drag = 4,
	})
end

local function redSparks(position: Vector3, count: number, size: number?, direction: Vector3?)
	U.burst(position, {
		color = RED,
		count = count,
		size = size or 1,
		speed = NumberRange.new(25, 50),
		streaks = true,
		direction = direction,
		spread = if direction then 40 else nil,
	})
end

-- Short black lightning bolts crackling around a point.
local function blackLightning(position: Vector3, count: number, radius: number)
	for _ = 1, count do
		local from = position + U.randomUnit() * radius * 0.3
		local to = position + U.randomUnit() * radius
		local mid = (from + to) / 2 + U.randomUnit() * radius * 0.25
		for _, segment in { { from, mid }, { mid, to } } do
			local a, b = segment[1], segment[2]
			local length = (b - a).Magnitude
			local bolt = U.newPart({
				Size = Vector3.new(0.15, 0.15, length),
				CFrame = CFrame.lookAt((a + b) / 2, b),
				Color = BLACK,
				Material = Enum.Material.SmoothPlastic,
			})
			U.tween(bolt, 0.18, { Transparency = 1, Size = Vector3.new(0.05, 0.05, length) })
			task.delay(0.2, bolt.Destroy, bolt)
		end
	end
end

local function play(character: Model, animation: Animation, onEvent: ((string) -> ())?)
	PoseAnimator.Play(character, animation, onEvent)
end

---------------------------------------------------------------------------
-- M1
---------------------------------------------------------------------------

local STRING = { "Slash1", "Slash2", "Slash3" }
local FINISHERS = { Knockback = "Cleave", Uppercut = "Rising", Downslam = "Chop" }

-- M1s are just the sword swinging: no trails, no extra effects.
function Kit.PlayM1(character: Model, index: number, variant: string)
	local name = if variant ~= "Normal" then FINISHERS[variant] or "Cleave" else STRING[((index - 1) % #STRING) + 1]
	play(character, ANIMS[name])
end

---------------------------------------------------------------------------
-- Skills
---------------------------------------------------------------------------

local THRUST = {
	Torso = rot(-22, 8),
	RightArm = limb(55, 5),
	LeftArm = limb(-30, 0, -20),
	Head = rot(15),
	RightLeg = rot(-30),
	LeftLeg = rot(35),
}

local CLIPS = {
	Thrust = clip({ { 0, READY }, { 0.08, THRUST, BACK }, { 0.45, THRUST } }, { fadeOut = 0.15 }),

	Flurry = clip({
		{ 0, { Torso = rot(-6, -20), RightArm = limb(80, -60), LeftArm = limb(40, -20) } },
		{ 0.08, { Torso = rot(-6, 25), RightArm = limb(80, 60), LeftArm = limb(40, -20) }, BACK },
		{ 0.16, { Torso = rot(-6, -25), RightArm = limb(85, -65), LeftArm = limb(40, -20) }, BACK },
		{ 0.24, { Torso = rot(-6, 25), RightArm = limb(80, 60), LeftArm = limb(40, -20) }, BACK },
		{ 0.32, { Torso = rot(-6, -25), RightArm = limb(85, -65), LeftArm = limb(40, -20) }, BACK },
		{ 0.44, { Torso = rot(-15, -15), RightArm = limb(-20, -10), LeftArm = limb(60, -20) } },
	}, { fadeOut = 0.05, additive = LEGS_ADDITIVE }),

	Launch = clip({
		{ 0, { Torso = rot(-15, -15), RightArm = limb(-20, -10), LeftArm = limb(60, -20) } },
		{ 0.08, { Torso = rot(15, 15), RightArm = limb(175, 10), LeftArm = limb(20, -20), Head = rot(-20) }, BACK },
		{ 0.3, { Torso = rot(12, 12), RightArm = limb(170, 10), LeftArm = limb(20, -20), Head = rot(-15) } },
	}, { fadeOut = 0.2, additive = LEGS_ADDITIVE }),

	Lunge = clip({
		{ 0, READY },
		{
			0.08,
			{
				Torso = rot(-25),
				RightArm = limb(-20, 0, 20),
				LeftArm = limb(95, -5),
				Head = rot(18),
				RightLeg = rot(-30),
				LeftLeg = rot(35),
			},
			BACK,
		},
		{
			0.4,
			{
				Torso = rot(-25),
				RightArm = limb(-20, 0, 20),
				LeftArm = limb(95, -5),
				Head = rot(18),
				RightLeg = rot(-30),
				LeftLeg = rot(35),
			},
		},
	}, { fadeOut = 0.1 }),

	Rise = clip({
		{ 0, { Torso = rot(-10), RightArm = limb(100), LeftArm = limb(95, -5) } },
		{
			0.2,
			{
				Torso = rot(18),
				RightArm = limb(178, 5),
				LeftArm = limb(95, -5),
				Head = rot(-15),
				RightLeg = rot(-20),
				LeftLeg = rot(40),
			},
			BACK,
		},
		{
			0.55,
			{
				Torso = rot(20),
				RightArm = limb(178, 5),
				LeftArm = limb(95, -5),
				Head = rot(-15),
				RightLeg = rot(-20),
				LeftLeg = rot(40),
			},
		},
	}, { fadeOut = 0.05 }),

	Slam = clip({
		{ 0, { Torso = rot(20), RightArm = limb(178, 5), LeftArm = limb(95, -5) } },
		{
			0.1,
			{
				Torso = rot(-38),
				RightArm = limb(30, 5),
				LeftArm = limb(50, -5),
				Head = rot(20),
				RightLeg = rot(40),
				LeftLeg = rot(10),
			},
			BACK,
		},
		{ 0.6, { Torso = rot(-35), RightArm = limb(30, 5), LeftArm = limb(50, -5), Head = rot(18) } },
	}, { fadeOut = 0.25 }),

	DividerCharge = clip({
		{ 0, READY },
		{
			0.15,
			{
				Torso = rot(5, -45),
				RightArm = limb(-40, -30),
				LeftArm = limb(75, -30),
				Head = rot(0, 35),
				RightLeg = rot(0, 45),
				LeftLeg = rot(0, 45),
			},
		},
		{
			0.62,
			{
				Torso = rot(8, -50),
				RightArm = limb(-45, -35),
				LeftArm = limb(80, -30),
				Head = rot(0, 40),
				RightLeg = rot(0, 50),
				LeftLeg = rot(0, 50),
			},
		},
	}, { fadeOut = 0.05, additive = LEGS_ADDITIVE }),

	DividerRelease = clip({
		{ 0, { Torso = rot(8, -50), RightArm = limb(-45, -35), LeftArm = limb(80, -30) } },
		{
			0.08,
			{
				Torso = rot(-10, 50),
				RightArm = limb(85, 85),
				LeftArm = limb(20, -40),
				Head = rot(0, -40),
				RightLeg = rot(0, -50),
				LeftLeg = rot(0, -50),
			},
			BACK,
		},
		{
			0.35,
			{
				Torso = rot(-8, 45),
				RightArm = limb(80, 80),
				LeftArm = limb(20, -40),
				Head = rot(0, -35),
				RightLeg = rot(0, -45),
				LeftLeg = rot(0, -45),
			},
		},
	}, { fadeOut = 0.25, additive = LEGS_ADDITIVE }),

	Stance = clip({
		{ 0, READY },
		{
			0.08,
			{ Torso = rot(-6, 10), RightArm = limb(30, 30), LeftArm = limb(60, 35), Head = rot(8) },
			BACK,
		},
		{ 0.82, { Torso = rot(-6, 10), RightArm = limb(30, 30), LeftArm = limb(60, 35), Head = rot(8) } },
	}, { fadeOut = 0.12 }),

	Counter = clip({
		{ 0, { Torso = rot(-6, 10), RightArm = limb(30, 30), LeftArm = limb(60, 35) } },
		{
			0.08,
			{ Torso = rot(-5, -40), RightArm = limb(80, -85), LeftArm = limb(20, 0, -40), Head = rot(0, 30) },
			BACK,
		},
		{ 0.35, { Torso = rot(-5, -35), RightArm = limb(80, -80), LeftArm = limb(20, 0, -40), Head = rot(0, 25) } },
	}, { fadeOut = 0.2, additive = LEGS_ADDITIVE }),

	SlashThrow = clip({
		{ 0, READY },
		{ 0.15, { Torso = rot(10, -30), RightArm = limb(155, -40), LeftArm = limb(50, -20) } },
		{ 0.24, { Torso = rot(-12, 35), RightArm = limb(40, 45), LeftArm = limb(20, -30), Head = rot(0, -25) }, BACK },
		{ 0.45, { Torso = rot(-10, 30), RightArm = limb(40, 45), LeftArm = limb(20, -30), Head = rot(0, -20) } },
	}, { fadeOut = 0.2, additive = LEGS_ADDITIVE }),

	GrandCharge = clip({
		{ 0, READY },
		{
			0.25,
			{ Torso = rot(15), RightArm = limb(172, 6), LeftArm = limb(168, -6), Head = rot(-12) },
		},
		{ 0.7, { Torso = rot(18), RightArm = limb(175, 6), LeftArm = limb(170, -6), Head = rot(-15) } },
	}, { fadeOut = 0.05 }),

	GrandRelease = clip({
		{ 0, { Torso = rot(18), RightArm = limb(175, 6), LeftArm = limb(170, -6) } },
		{
			0.09,
			{
				Torso = rot(-35),
				RightArm = limb(40, 6),
				LeftArm = limb(45, -6),
				Head = rot(18),
				RightLeg = rot(-25),
				LeftLeg = rot(30),
			},
			BACK,
		},
		{ 0.5, { Torso = rot(-32), RightArm = limb(40, 6), LeftArm = limb(45, -6), Head = rot(15) } },
	}, { fadeOut = 0.3 }),

	Grabbing = clip({
		{ 0, READY },
		{ 0.1, { Torso = rot(-10), RightArm = limb(-15, 0, 25), LeftArm = limb(92, -5) }, BACK },
		{ 0.3, { Torso = rot(-10), RightArm = limb(-15, 0, 25), LeftArm = limb(92, -5) } },
	}, { fadeOut = 0.05 }),

	Release = clip({
		{ 0, { Torso = rot(-10), RightArm = limb(-15, 0, 25), LeftArm = limb(92, -5) } },
		{ 0.15, { Torso = rot(10, -20), RightArm = limb(-40, -30), LeftArm = limb(95, -10) } },
		{
			0.3,
			{ Torso = rot(-18, 20), RightArm = limb(95, 10), LeftArm = limb(95, -10), Head = rot(10) },
			BACK,
		},
		{ 0.6, { Torso = rot(-15, 18), RightArm = limb(92, 10), LeftArm = limb(92, -10), Head = rot(8) } },
	}, { fadeOut = 0.25, additive = LEGS_ADDITIVE }),

	AwakenCrouch = clip({
		{ 0, READY },
		{
			0.2,
			{
				Torso = rot(-28),
				RightArm = limb(-15, 0, 35),
				LeftArm = limb(-15, 0, -35),
				Head = rot(18),
				RightLeg = rot(25),
				LeftLeg = rot(-5),
			},
		},
		{
			0.9,
			{
				Torso = rot(-30),
				RightArm = limb(-15, 0, 38),
				LeftArm = limb(-15, 0, -38),
				Head = rot(20),
				RightLeg = rot(28),
				LeftLeg = rot(-5),
			},
		},
	}, { fadeOut = 0.05 }),

	AwakenRoar = clip({
		{ 0, { Torso = rot(-30), RightArm = limb(-15, 0, 38), LeftArm = limb(-15, 0, -38) } },
		{
			0.1,
			{ Torso = rot(18), RightArm = limb(30, 0, 80), LeftArm = limb(30, 0, -80), Head = rot(-28) },
			BACK,
		},
		{ 0.6, { Torso = rot(15), RightArm = limb(30, 0, 75), LeftArm = limb(30, 0, -75), Head = rot(-22) } },
	}, { fadeOut = 0.35 }),
}

-- Black Hurricane: the whole body spins (RootJoint yaw in 90 degree steps).
do
	local keys = {}
	local spins, duration = 4, 0.9
	local steps = spins * 4
	for i = 0, steps do
		table.insert(keys, {
			i / steps * duration,
			{
				Torso = rot(-10, -90 * i),
				RightArm = limb(0, 0, 95),
				LeftArm = limb(0, 0, -95),
				Head = rot(5),
			},
			Enum.EasingStyle.Linear,
		})
	end
	CLIPS.Spin = clip(keys, { fadeIn = 0.05, fadeOut = 0.15 })
end

-- Anti-magic slash wave, drawn locally from the server's launch info.
local function slashWave(data)
	local origin: Vector3 = data.origin
	local direction: Vector3 = data.direction
	local speed: number = data.speed or 130
	local range: number = data.range or 90
	local width: number = data.width or 9
	local grand = data.grand == true

	local frame = CFrame.lookAt(origin, origin + direction)
	local holder = U.newPart({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = frame })
	-- Crescent across the direction of travel, bulging forward.
	local forward = CFrame.Angles(0, rad(90), 0)
	local tilt = if grand then 0 else rad(-25)
	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.Angles(0, 0, tilt) * CFrame.new(-width / 2, 0, 0) * forward
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.CFrame = CFrame.Angles(0, 0, tilt) * CFrame.new(width / 2, 0, 0) * forward
	a1.Parent = holder

	local function beam(color: Color3, emission: number, w: number, curve: number, transparency: number)
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.CurveSize0 = curve
		b.CurveSize1 = -curve
		b.Segments = 24
		b.FaceCamera = true
		b.LightEmission = emission
		b.LightInfluence = 0
		b.Color = ColorSequence.new(color)
		b.Width0 = w * 0.15
		b.Width1 = w * 0.15
		-- Fades out at the tips so it reads as a crescent.
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, transparency),
			NumberSequenceKeypoint.new(1, 1),
		})
		b.Parent = holder
		return b
	end
	local scale = width / 9
	beam(RED, 1, 5 * scale, width * 0.35, 0.3)
	beam(BLACK, 0, 3.6 * scale, width * 0.32, 0)

	local trail = Instance.new("ParticleEmitter")
	trail.Texture = U.textures.Smoke
	trail.Color = ColorSequence.new(BLACK)
	trail.LightEmission = 0
	trail.Size = NumberSequence.new(2 * scale, 0)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = NumberRange.new(0.3, 0.5)
	trail.Rate = 60
	trail.Speed = NumberRange.new(2, 5)
	trail.SpreadAngle = Vector2.new(180, 180)
	trail.Parent = holder

	local travelled = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		travelled += speed * dt
		holder.CFrame = frame + direction * travelled
		if travelled >= range then
			connection:Disconnect()
			trail.Enabled = false
			blackSmoke(holder.Position, 8, 3)
			task.delay(0.6, holder.Destroy, holder)
			for _, child in holder:GetChildren() do
				if child:IsA("Attachment") then
					child:Destroy()
				end
			end
		end
	end)
end

-- Persistent Black Form look per character.
local awakenedVisuals: { [Model]: { cleanup: { () -> () } } } = {}

local function setAwakened(character: Model, on: boolean)
	local existing = awakenedVisuals[character]
	if existing then
		for _, cleanup in existing.cleanup do
			cleanup()
		end
		awakenedVisuals[character] = nil
	end
	if not on then
		return
	end

	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local cleanup: { () -> () } = {}
	awakenedVisuals[character] = { cleanup = cleanup }

	-- Rising black anti-magic aura.
	local aura = Instance.new("ParticleEmitter")
	aura.Texture = U.textures.Smoke
	aura.Color = ColorSequence.new(BLACK)
	aura.LightEmission = 0
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3) })
	aura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	aura.Lifetime = NumberRange.new(0.6, 1)
	aura.Rate = 35
	aura.Speed = NumberRange.new(2, 4)
	aura.Acceleration = Vector3.new(0, 6, 0)
	aura.SpreadAngle = Vector2.new(60, 60)
	aura.Parent = torso
	table.insert(cleanup, function()
		aura:Destroy()
	end)

	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(RED)
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.25, 0)
	embers.Lifetime = NumberRange.new(0.4, 0.8)
	embers.Rate = 18
	embers.Speed = NumberRange.new(3, 7)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Acceleration = Vector3.new(0, 4, 0)
	embers.Parent = torso
	table.insert(cleanup, function()
		embers:Destroy()
	end)

	-- Single black devil wing on the left shoulder blade.
	local wing = Instance.new("Model")
	wing.Name = "BlackWing"
	local feathers = {
		{ size = Vector3.new(0.25, 2.6, 0.9), offset = CFrame.new(-0.9, 1.4, 0.75) * rot(-15, 0, 35) },
		{ size = Vector3.new(0.22, 2.2, 0.8), offset = CFrame.new(-1.7, 1.2, 0.85) * rot(-15, 0, 60) },
		{ size = Vector3.new(0.2, 1.8, 0.7), offset = CFrame.new(-2.3, 0.6, 0.9) * rot(-15, 0, 85) },
		{ size = Vector3.new(0.18, 1.3, 0.6), offset = CFrame.new(-2.6, -0.1, 0.95) * rot(-15, 0, 110) },
	}
	for _, feather in feathers do
		local part = U.newPart({
			Size = feather.size,
			Color = BLACK,
			Material = Enum.Material.SmoothPlastic,
			CFrame = torso.CFrame * feather.offset,
		})
		part.Anchored = false
		part.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = part
		weld.C0 = feather.offset
		weld.Parent = part
		part.Parent = wing
	end
	wing.Parent = character
	table.insert(cleanup, function()
		wing:Destroy()
	end)

	-- Anti-magic creeping up the right arm.
	local arm = character:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		local original = arm.Color
		arm.Color = BLACK
		table.insert(cleanup, function()
			if arm.Parent then
				arm.Color = original
			end
		end)
	end

	local outline = Instance.new("Highlight")
	outline.Adornee = character
	outline.FillColor = BLACK
	outline.FillTransparency = 0.8
	outline.OutlineColor = DARK_RED
	outline.OutlineTransparency = 0.2
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = character
	table.insert(cleanup, function()
		outline:Destroy()
	end)
end

local handlers: { [string]: (data: any, character: Model, root: BasePart) -> () } = {}

function handlers.BullThrust(data, character, root)
	local phase = data.phase
	if phase == "Charge" then
		play(character, CLIPS.Thrust)
		swordTrail(character, 0.4)
		U.afterimage(character, DARK_RED, 0.3)
		U.bodyTrail(character, BLACK, 0.4)
		blackSmoke(root.Position, 6, 2.5, 8)
	elseif phase == "Flurry" then
		play(character, CLIPS.Flurry)
		swordTrail(character, 0.45)
		for i = 0, 3 do
			task.delay(0.02 + i * 0.08, function()
				if character.Parent then
					local from = if i % 2 == 0 then CFrame.new(3, 1, -1.2) else CFrame.new(-3, 0.8, -1.2)
					local to = if i % 2 == 0 then CFrame.new(-3, -0.4, -1.2) else CFrame.new(3, -0.4, -1.2)
					slashArc(character, from, to, 1.1, 0.14)
				end
			end)
		end
	elseif phase == "Launch" then
		play(character, CLIPS.Launch)
		swordTrail(character, 0.25)
		slashArc(character, CFrame.new(0.4, -2.4, -1.6), CFrame.new(-0.4, 4.5, -1.6), 2, 0.3)
	elseif phase == "Land" then
		U.groundRocks(data.position, 8, 3, 1.6)
		blackSmoke(data.position, 10, 3, 12)
	end
end

function handlers.BlackMeteorite(data, character, root)
	local phase = data.phase
	if phase == "Lunge" then
		play(character, CLIPS.Lunge)
		U.afterimage(character, BLACK, 0.3)
		U.bodyTrail(character, BLACK, 0.35)
		blackLightning(root.Position, 3, 3)
	elseif phase == "Rise" then
		play(character, CLIPS.Rise)
		blackSmoke(root.Position - UP * 2.5, 10, 3, 14)
		U.ringBurst(CFrame.new(root.Position - UP * 2.8), RED, 1, 6, 0.3, 0.2)
		U.bodyTrail(character, BLACK, 0.5)
	elseif phase == "Slam" then
		play(character, CLIPS.Slam)
		swordTrail(character, 0.4)
		U.bodyTrail(character, RED, 0.4)
	elseif phase == "Impact" then
		local position: Vector3 = data.position
		U.groundRocks(position, 14, 5, 2.6)
		blackSmoke(position, 18, 5, 20)
		U.ringBurst(CFrame.new(position + UP * 0.3), BLACK, 1, 14, 0.4, 0.5)
		U.ringBurst(CFrame.new(position + UP * 0.3), RED, 1, 10, 0.35, 0.3)
		blackLightning(position + UP, 6, 7)
		U.light(position, RED, 8, 24, 0.4)
	end
end

function handlers.BlackDivider(data, character, root)
	local phase = data.phase
	if phase == "Charge" then
		play(character, CLIPS.DividerCharge)
		-- Anti-magic gathering into the blade.
		for i = 0, 3 do
			task.delay(i * 0.09, function()
				local sword = getSword(character)
				local blade = sword and sword:FindFirstChild("Blade")
				if blade and blade:IsA("BasePart") then
					blackSmoke(blade.Position, 3, 1.8, 4)
				end
			end)
		end
		swordGlow(character, BLACK, 0.6, 0.4)
		-- The timing flash: press 3 right now for a perfect Divider.
		task.delay(data.flashAt or 0.38, function()
			if not character.Parent then
				return
			end
			swordGlow(character, RED, 0.22, 0)
			local sword = getSword(character)
			local blade = sword and sword:FindFirstChild("Blade")
			if blade and blade:IsA("BasePart") then
				U.flash(blade.Position, RED, 4, 0.15)
				U.light(blade.Position, RED, 10, 14, 0.2)
			end
			if U.isLocal(character) then
				CameraShake.FovKick(-4)
			end
		end)
	elseif phase == "Release" then
		play(character, CLIPS.DividerRelease)
		swordTrail(character, 0.3)
		local perfect = data.perfect == true
		slashArc(character, CFrame.new(4.8, 1, -0.6), CFrame.new(-4.8, -0.2, -0.6), if perfect then 3 else 2.2, 0.32)
		local front = root.Position + root.CFrame.LookVector * 5
		blackSmoke(front, if perfect then 16 else 8, 3.5, 22)
		if perfect then
			U.popup(root.Position + UP * 4, "PERFECT DIVIDER", RED, 1.6)
			blackLightning(front, 8, 7)
			if U.isLocal(character) then
				U.screenFlash(RED, 0.35)
			end
		end
	end
end

function handlers.Deflect(data, character, root)
	local phase = data.phase
	if phase == "Stance" then
		play(character, CLIPS.Stance)
		swordGlow(character, DARK_RED, 0.8, 0.6)
		U.ringBurst(CFrame.new(root.Position - UP * 2.8), DARK_RED, 3, 3.5, 0.8, 0.1)
	elseif phase == "Counter" then
		play(character, CLIPS.Counter)
		swordTrail(character, 0.25)
		slashArc(character, CFrame.new(-3.5, 0.8, -1.2), CFrame.new(3.5, -0.4, -1.2), 2.2, 0.25)
		U.flash(root.Position + root.CFrame.LookVector * 2, WHITE, 7, 0.2)
		U.popup(root.Position + UP * 3.5, "DEFLECT", RED, 1.3)
		blackLightning(root.Position, 5, 5)
		if U.isLocal(character) then
			U.screenFlash(BLACK, 0.25)
		end
	elseif phase == "Reflect" then
		play(character, CLIPS.SlashThrow)
		swordTrail(character, 0.3)
		U.popup(root.Position + UP * 3.5, "REFLECT", RED, 1.3)
	end
end

function handlers.BlackHurricane(data, character, root)
	if data.phase == "Spin" then
		play(character, CLIPS.Spin)
		swordTrail(character, 0.9)
		local start = os.clock()
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if os.clock() - start > (data.duration or 0.9) or not root.Parent then
				connection:Disconnect()
				return
			end
			if math.random() < 0.35 then
				blackSmoke(root.Position + U.randomUnit() * 2, 2, 3, 10)
			end
		end)
		for i = 0, 3 do
			task.delay(i * 0.22, function()
				if root.Parent then
					U.ringBurst(CFrame.new(root.Position), BLACK, 2, 7, 0.25, 0.3)
				end
			end)
		end
	elseif data.phase == "Finish" then
		redSparks(root.Position + UP, 16, 1.2)
		U.flash(root.Position, RED, 8, 0.2)
	end
end

function handlers.BlackSlash(data, character)
	if data.phase == "Windup" then
		play(character, CLIPS.SlashThrow)
		task.delay(0.15, swordTrail, character, 0.2)
	elseif data.phase == "Projectile" then
		slashWave(data)
		U.flash(data.origin, RED, if data.grand then 9 else 4, 0.15)
	end
end

function handlers.GrandDivider(data, character, root)
	if data.phase == "Charge" then
		play(character, CLIPS.GrandCharge)
		swordGlow(character, BLACK, 0.75, 0.3)
		for i = 0, 6 do
			task.delay(i * 0.1, function()
				if root.Parent then
					blackSmoke(root.Position + UP * 4, 4, 4, 6)
					blackLightning(root.Position + UP * 5, 1, 3)
				end
			end)
		end
		U.ringBurst(CFrame.new(root.Position - UP * 2.8), BLACK, 8, 2, 0.7, 0.3)
	elseif data.phase == "Release" then
		play(character, CLIPS.GrandRelease)
		swordTrail(character, 0.3)
		slashArc(character, CFrame.new(0, 5, -1.8), CFrame.new(0, -2.6, -1.8), 3.5, 0.35)
		local front = root.Position + root.CFrame.LookVector * 5
		U.groundRocks(front, 12, 4, 2.4)
		blackSmoke(front, 16, 5, 18)
		if U.isLocal(character) then
			U.screenFlash(RED, 0.3)
		end
	end
end

function handlers.DemonDestroyer(data, character, root)
	local phase = data.phase
	if phase == "Lunge" then
		play(character, CLIPS.Lunge)
		U.afterimage(character, RED, 0.3)
		U.bodyTrail(character, BLACK, 0.35)
	elseif phase == "Grab" then
		play(character, CLIPS.Grabbing)
		blackLightning(root.Position, 4, 4)
	elseif phase == "Carve" then
		local i = data.index or 1
		local from = if i % 2 == 0 then CFrame.new(3, 1.5, -2) else CFrame.new(-3, 1.2, -2)
		local to = if i % 2 == 0 then CFrame.new(-3, -1, -2) else CFrame.new(3, -1, -2)
		swordTrail(character, 0.12)
		slashArc(character, from, to, 1.4, 0.15)
		redSparks(root.Position + root.CFrame.LookVector * 3, 5, 0.8)
	elseif phase == "Release" then
		play(character, CLIPS.Release)
		local front = root.Position + root.CFrame.LookVector * 3
		task.delay(0.28, function()
			U.flash(front, BLACK, 12, 0.3)
			U.flash(front, RED, 8, 0.25)
			U.ringBurst(CFrame.lookAt(front, front + root.CFrame.LookVector) * rot(90), RED, 1, 12, 0.35, 0.4)
			blackSmoke(front, 20, 5, 25)
			blackLightning(front, 10, 9)
			U.light(front, RED, 12, 30, 0.5)
			if U.isLocal(character) then
				U.screenFlash(BLACK, 0.4)
			end
		end)
	elseif phase == "Heal" then
		U.popup(root.Position + UP * 4, "+30% HP", Color3.fromRGB(120, 255, 140), 1.3)
		U.highlight(character, Color3.fromRGB(120, 255, 140), 0.5)
	end
end

function handlers.Awaken(data, character, root)
	local phase = data.phase
	if phase == "Start" then
		play(character, CLIPS.AwakenCrouch)
		for i = 0, 8 do
			task.delay(i * 0.1, function()
				if root.Parent then
					blackSmoke(root.Position - UP * 2 + U.randomUnit() * 2, 3, 3, 4)
					blackLightning(root.Position, 1, 4)
				end
			end)
		end
		U.ringBurst(CFrame.new(root.Position - UP * 2.8), BLACK, 10, 2, 0.9, 0.3)
		if U.isLocal(character) then
			U.screenFlash(BLACK, 0.9)
		end
	elseif phase == "Burst" then
		play(character, CLIPS.AwakenRoar)
		U.flash(root.Position, BLACK, 18, 0.4)
		U.flash(root.Position, RED, 12, 0.3)
		U.ringBurst(CFrame.new(root.Position - UP * 2.5), BLACK, 2, 22, 0.5, 0.6)
		U.ringBurst(CFrame.new(root.Position - UP * 2.5), RED, 2, 16, 0.45, 0.35)
		U.groundRocks(root.Position, 16, 7, 2.8)
		blackSmoke(root.Position, 30, 6, 30)
		blackLightning(root.Position, 12, 10)
		U.light(root.Position, RED, 14, 40, 0.6)
		U.popup(root.Position + UP * 5, "BLACK FORM", RED, 2)
		if U.isLocal(character) then
			U.screenFlash(RED, 0.5)
			CameraShake.FovKick(12)
		end
	elseif phase == "End" then
		blackSmoke(root.Position, 12, 3, 8)
	end
end

---------------------------------------------------------------------------
-- Spawn entrance
---------------------------------------------------------------------------

local function easeInOut(alpha: number): number
	return TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local function setSwordVisible(character: Model, visible: boolean, fade: number?)
	local sword = getSword(character)
	if not sword then
		return
	end
	for _, part in sword:GetDescendants() do
		if part:IsA("BasePart") then
			if fade and visible then
				part.Transparency = 1
				U.tween(part, fade, { Transparency = 0 })
			else
				part.Transparency = if visible then 0 else 1
			end
		end
	end
end

-- Asta's grimoire: a tattered black book with a five-leaf clover floating
-- over it. Anchored parts posed every frame around a moving anchor.
local function grimoire(character: Model, root: BasePart): { open: (number) -> (), close: () -> (), burst: () -> () }
	local parts: { { part: BasePart, offset: CFrame, side: number } } = {}
	local function piece(size: Vector3, color: Color3, material: Enum.Material, offset: CFrame, side: number): BasePart
		local part = U.newPart({ Size = size, Color = color, Material = material, Transparency = 1 })
		table.insert(parts, { part = part, offset = offset, side = side })
		return part
	end
	local cover = Color3.fromRGB(24, 22, 26)
	local paper = Color3.fromRGB(205, 195, 170)
	-- side -1 = left half (rotates open one way), 1 = right half, 0 = fixed
	piece(Vector3.new(1.1, 1.45, 0.08), cover, Enum.Material.Fabric, CFrame.new(-0.55, 0, 0), -1)
	piece(Vector3.new(1.1, 1.45, 0.08), cover, Enum.Material.Fabric, CFrame.new(0.55, 0, 0), 1)
	piece(Vector3.new(1, 1.35, 0.12), paper, Enum.Material.SmoothPlastic, CFrame.new(-0.5, 0, -0.08), -1)
	piece(Vector3.new(1, 1.35, 0.12), paper, Enum.Material.SmoothPlastic, CFrame.new(0.5, 0, -0.08), 1)
	piece(Vector3.new(0.14, 1.45, 0.14), cover, Enum.Material.Fabric, CFrame.new(0, 0, 0.02), 0)
	-- Five-leaf clover hovering over the pages.
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		piece(
			Vector3.new(0.34, 0.34, 0.06),
			BLACK,
			Enum.Material.SmoothPlastic,
			CFrame.new(math.cos(angle) * 0.24, 1.1 + math.sin(angle) * 0.24, -0.4) * CFrame.Angles(0, 0, angle),
			0
		)
	end
	local glowHolder = piece(Vector3.one * 0.1, RED, Enum.Material.Neon, CFrame.new(0, 1.1, -0.4), 0)
	local glow = Instance.new("PointLight")
	glow.Color = RED
	glow.Brightness = 0
	glow.Range = 8
	glow.Parent = glowHolder

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = U.textures.Smoke
	smoke.Color = ColorSequence.new(BLACK)
	smoke.LightEmission = 0
	smoke.Size = NumberSequence.new(0.8, 1.6)
	smoke.Transparency = NumberSequence.new(0.5, 1)
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Rate = 25
	smoke.Speed = NumberRange.new(0.5, 1.5)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Acceleration = Vector3.new(0, 2, 0)
	smoke.Parent = glowHolder

	local openAngle, visible = 0, 0
	local anchorOffset = CFrame.new(-1.9, 0.6, -1.7)
	local start = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			return
		end
		local t = os.clock() - start
		local position = (root.CFrame * anchorOffset).Position + Vector3.new(0, math.sin(t * 3) * 0.12, 0)
		-- Faces Asta, tilted back like it's being read.
		local base = CFrame.lookAt(position, root.Position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(rad(-20), 0, 0)
		for _, entry in parts do
			local hinge = CFrame.Angles(0, -entry.side * rad(openAngle), 0)
			local spin = if entry.side == 0 and entry.offset.Y > 0.5
				then CFrame.new(0, 1.1, -0.4) * CFrame.Angles(0, 0, t * 1.5) * CFrame.new(0, -1.1, 0.4)
				else CFrame.identity
			entry.part.CFrame = base * hinge * spin * entry.offset
			entry.part.Transparency = 1 - visible
		end
		glowHolder.Transparency = 1
		glow.Brightness = 3 * visible
	end)

	local function animateTo(duration: number, toOpen: number, toVisible: number)
		local fromOpen, fromVisible = openAngle, visible
		local t0 = os.clock()
		local c
		c = RunService.RenderStepped:Connect(function()
			local a = math.min((os.clock() - t0) / duration, 1)
			local e = easeInOut(a)
			openAngle = fromOpen + (toOpen - fromOpen) * e
			visible = fromVisible + (toVisible - fromVisible) * e
			if a >= 1 then
				c:Disconnect()
			end
		end)
	end

	return {
		open = function(duration: number)
			animateTo(duration, 65, 1)
		end,
		burst = function()
			blackSmoke(glowHolder.Position, 10, 2.5, 8)
			U.flash(glowHolder.Position, RED, 3, 0.2)
			U.light(glowHolder.Position, RED, 6, 12, 0.3)
		end,
		close = function()
			animateTo(0.3, 0, 0)
			smoke.Enabled = false
			task.delay(0.35, function()
				blackSmoke(glowHolder.Position, 6, 1.5, 4)
				connection:Disconnect()
				for _, entry in parts do
					entry.part:Destroy()
				end
			end)
		end,
	}
end

function handlers.Entrance(data, character, root)
	if data.phase ~= "Start" then
		return
	end
	setSwordVisible(character, false)
	blackSmoke(root.Position - UP * 2.6, 10, 3, 6)
	U.ringBurst(CFrame.new(root.Position - UP * 2.9), BLACK, 1, 7, 0.4, 0.25)

	local book: any = nil
	local finished = false
	local function cleanup()
		if finished then
			return
		end
		finished = true
		setSwordVisible(character, true)
		if book then
			book.close()
		end
	end
	-- Whatever happens (death, interruption), never leave the sword hidden.
	task.delay(3, cleanup)

	play(character, ANIMS.Entrance, function(event)
		if not character.Parent then
			cleanup()
			return
		end
		if event == "Grimoire" then
			book = grimoire(character, root)
			book.open(0.45)
		elseif event == "Draw" then
			if book then
				book.burst()
			end
			setSwordVisible(character, true, 0.08)
			redSparks(root.Position + UP * 1.5, 10, 0.8)
		elseif event == "Slam" then
			local sword = getSword(character)
			local blade = sword and sword:FindFirstChild("Blade")
			local tip = if blade and blade:IsA("BasePart")
				then (blade.CFrame * CFrame.new(0, 2.1, 0)).Position
				else root.Position + root.CFrame.LookVector * 5
			U.groundRocks(tip, 9, 2, 1.4)
			blackSmoke(tip, 12, 3.5, 14)
			U.ringBurst(CFrame.new(tip + UP * 0.2), BLACK, 0.6, 9, 0.35, 0.3)
			blackLightning(tip + UP, 5, 5)
			U.light(tip, RED, 6, 18, 0.35)
			if U.isLocal(character) then
				CameraShake.Add(0.35)
			end
		elseif event == "Settle" then
			cleanup()
		end
	end)
end

function Kit.OnSkill(data)
	local character = data.character
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	local root = U.getRoot(character)
	local handler = handlers[data.skill]
	if root and handler then
		handler(data, character, root)
	end
end

-- Asta's dash: leans into it with the sword trailing, leaving black
-- afterimages and anti-magic smoke, red sparks streaming off behind.
local DASH_DIRECTIONS = {
	Front = Vector3.new(0, 0, -1),
	Back = Vector3.new(0, 0, 1),
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
}

VFX.RegisterKitEffect("AntiMagic", "Dash", function(data)
	local character: Model? = data.character
	local root = U.getRoot(character)
	if not character or not root then
		return
	end
	local direction = if type(data.direction) == "string" then data.direction else "Front"
	local animation = ANIMS["Dash" .. direction]
	if animation then
		play(character, animation)
	end
	swordTrail(character, 0.26)

	U.afterimage(character, BLACK, 0.3)
	for i = 1, 3 do
		task.delay(i * 0.05, function()
			if character.Parent then
				U.afterimage(character, if i == 3 then DARK_RED else BLACK, 0.25)
			end
		end)
	end

	local ground = U.groundBelow(root.Position, { character })
	local feet = if ground then ground.Position else root.Position - UP * 3
	blackSmoke(feet + UP * 0.4, 6, 2.2, 7)
	U.ringBurst(CFrame.new(feet + UP * 0.1), BLACK, 0.6, 3.5, 0.25, 0.14)

	-- Sparks fly off opposite to the dash.
	local away = -(root.CFrame:VectorToWorldSpace(DASH_DIRECTIONS[direction] or DASH_DIRECTIONS.Front))
	U.burst(root.Position - UP * 0.5, {
		color = RED,
		count = 7,
		size = 0.35,
		speed = NumberRange.new(14, 26),
		lifetime = NumberRange.new(0.12, 0.25),
		streaks = true,
		spread = 30,
		direction = away,
	})
end)

function Kit.SetAwakened(character: Model, on: boolean)
	setAwakened(character, on)
end

-- A brighter, black-lightning version of the heavy hit for perfect Dividers
-- and the Demon-Destroyer finisher.
VFX.Register("PerfectDivider", function(data)
	VFX.Play("HeavyHit", data)
	local position: Vector3 = data.position
	blackLightning(position, 8, 6)
	blackSmoke(position, 12, 4, 20)
	U.flash(position, BLACK, 9, 0.25)
	if U.isLocal(data.attacker) or U.isLocal(data.victim) then
		CameraShake.Add(0.5)
	end
end)

return Kit
