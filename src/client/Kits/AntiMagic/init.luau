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
-- his shoulder, walks upright when slowed down; knee up and free arm out
-- in the air.
Kit.Idle = {
	stand = ANIMS.Idle,
	move = ANIMS.Run,
	walk = ANIMS.Walk,
	air = ANIMS.Air,
	moveSpeed = 16,
	walkSpeed = 8,
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
	Grabbed = ANIMS.Grabbed,
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

-- Jagged black lightning with a red sheath, crackling out around a point.
local function blackLightning(position: Vector3, count: number, radius: number, life: number?)
	for _ = 1, count do
		local from = position + U.randomUnit() * radius * 0.2
		U.lightning(from, position + U.randomUnit() * radius, BLACK, RED, 0.1 + radius * 0.012, life or 0.2)
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

local CLIPS = {
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

local handlers: { [string]: (data: any, character: Model, root: BasePart) -> () } = {}

---------------------------------------------------------------------------
-- Bull Thrust: propel, catch, barrage, push
---------------------------------------------------------------------------

-- Attaches a short-lived particle emitter to a part (a continuous trail).
local function trailEmitter(part: BasePart, props: { [string]: any }, duration: number)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = attachment
	task.delay(duration, function()
		emitter.Enabled = false
		task.wait(1)
		attachment:Destroy()
	end)
end

-- A slash mark drawn on the target: black blade core with a red glow,
-- slicing in fast and thinning out. Faces the camera.
local function slashMark(position: Vector3, angle: number, length: number, duration: number)
	local camera = workspace.CurrentCamera
	local base = CFrame.lookAt(position, camera.CFrame.Position) * CFrame.Angles(0, 0, angle)
	local glow = U.newPart({ Size = Vector3.new(0.1, 0.32, 0.03), CFrame = base, Color = RED, Transparency = 0.2 })
	local core = U.newPart({
		Size = Vector3.new(0.1, 0.14, 0.03),
		CFrame = base * CFrame.new(0, 0, 0.02),
		Color = BLACK,
		Material = Enum.Material.SmoothPlastic,
	})
	U.tween(glow, duration * 0.35, { Size = Vector3.new(length * 1.08, 0.32, 0.03) })
	U.tween(core, duration * 0.35, { Size = Vector3.new(length, 0.14, 0.03) })
	task.delay(duration * 0.35, function()
		U.tween(glow, duration * 0.65, { Size = Vector3.new(length * 1.1, 0.02, 0.02), Transparency = 1 })
		U.tween(core, duration * 0.65, { Size = Vector3.new(length, 0.01, 0.01), Transparency = 1 })
	end)
	task.delay(duration + 0.05, function()
		glow:Destroy()
		core:Destroy()
	end)
end

local function feetOf(character: Model, root: BasePart): Vector3
	local ground = U.groundBelow(root.Position, { character })
	return if ground then ground.Position else root.Position - UP * 3
end

local barrageAngles = { 0.35, -0.5, 1.2, -1.25, 0.05, 2.6, -0.9, 0.7 }

function handlers.BullThrust(data, character, root)
	local phase = data.phase
	if phase == "Propel" then
		local direction: Vector3 = if typeof(data.direction) == "Vector3"
			then data.direction
			else root.CFrame.LookVector
		-- The server says how long the (steerable) propel lasts.
		local duration = if type(data.duration) == "number" then data.duration else 0.55
		play(character, ANIMS.Propel)
		swordTrail(character, duration + 0.05)

		-- Ignition: an anti-magic blast behind him.
		local back = root.Position - direction * 1.5
		U.flash(back, BLACK, 6, 0.18)
		U.impactRing(back, direction, BLACK, 0.8, 5.5, 0.25)
		task.delay(0.05, U.impactRing, back, direction, RED, 0.6, 4, 0.22)
		blackSmoke(back, 14, 3.2, 16)
		U.burst(back, {
			color = RED,
			count = 14,
			size = 0.5,
			speed = NumberRange.new(25, 45),
			lifetime = NumberRange.new(0.15, 0.35),
			streaks = true,
			spread = 35,
			direction = -direction,
		})
		U.light(back, RED, 6, 14, 0.3)
		U.ringBurst(CFrame.new(feetOf(character, root) + UP * 0.1), BLACK, 0.8, 5, 0.3, 0.2)

		-- The jet: smoke and embers streaming off his back, afterimages,
		-- speed lines, dust kicked up along the ground.
		trailEmitter(root, {
			Texture = U.textures.Smoke,
			Color = ColorSequence.new(BLACK),
			LightEmission = 0,
			Size = NumberSequence.new(1.4, 3.2),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.35, 0.6),
			Rate = 110,
			Speed = NumberRange.new(2, 6),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(25, 25),
			Drag = 3,
		}, duration)
		trailEmitter(root, {
			Texture = U.textures.Spark,
			Color = ColorSequence.new(RED, DARK_RED),
			LightEmission = 1,
			Size = NumberSequence.new(0.35, 0),
			Lifetime = NumberRange.new(0.15, 0.3),
			Rate = 60,
			Speed = NumberRange.new(10, 18),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(30, 30),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Squash = NumberSequence.new(1.5),
		}, duration)
		U.bodyTrail(character, BLACK, duration + 0.05)
		U.speedLines(root, nil, duration)
		for i = 0, math.floor(duration / 0.06) do
			task.delay(i * 0.06, function()
				if character.Parent then
					U.afterimage(character, if i % 2 == 0 then BLACK else DARK_RED, 0.28)
					blackSmoke(feetOf(character, root) + UP * 0.3, 2, 1.6, 4)
				end
			end)
		end
		if U.isLocal(character) then
			CameraShake.FovKick(10)
			CameraShake.Add(0.15)
		end
	elseif phase == "Catch" then
		local position: Vector3 = data.position
		local direction = root.CFrame.LookVector
		U.flash(position, BLACK, 5, 0.15)
		U.flash(position, WHITE, 3, 0.08)
		U.impactRing(position, direction, RED, 0.6, 4.5, 0.22)
		redSparks(position, 12, 0.8, direction)
		blackLightning(position, 3, 3)
		U.light(position, RED, 8, 14, 0.25)
		if U.isLocal(character) or U.isLocal(data.target) then
			CameraShake.Add(0.25)
		end
	elseif phase == "Barrage" then
		play(character, ANIMS.Barrage)
		swordTrail(character, 0.95)
		local target = data.target
		for i = 0, 7 do
			task.delay(i * 0.11, function()
				if character.Parent then
					blackSmoke(feetOf(character, root) + UP * 0.2, 2, 1.4, 3)
					if typeof(target) == "Instance" and target:IsA("Model") then
						local targetRoot = U.getRoot(target)
						if targetRoot then
							blackSmoke(feetOf(target, targetRoot) + UP * 0.2, 2, 1.4, 3)
						end
					end
				end
			end)
		end
	elseif phase == "BarrageHit" then
		local targetRoot = U.getRoot(data.target)
		if not targetRoot then
			return
		end
		local index = data.index or 1
		local center = targetRoot.Position + UP * 0.6
		local jitter = U.randomUnit() * Vector3.new(0.8, 0.9, 0.8)
		local angle = barrageAngles[((index - 1) % #barrageAngles) + 1]
		-- Two crossing phantom slashes on the target, then sparks.
		slashMark(center + jitter, angle, 5, 0.16)
		task.delay(0.03, slashMark, center - jitter * 0.5, angle + 1.4, 4, 0.14)
		redSparks(center, 6, 0.6)
		U.burst(center, {
			color = WHITE,
			count = 4,
			size = 0.4,
			speed = NumberRange.new(25, 40),
			lifetime = NumberRange.new(0.08, 0.16),
			streaks = true,
		})
		U.light(center, RED, 4, 9, 0.1)
		if index % 2 == 0 then
			U.afterimage(character, DARK_RED, 0.15)
		end
		if U.isLocal(character) or U.isLocal(data.target) then
			CameraShake.Add(0.08)
		end
	elseif phase == "Push" then
		local direction = root.CFrame.LookVector
		local front = root.Position + direction * 3
		U.flash(front, WHITE, 4, 0.1)
		U.flash(front, BLACK, 7, 0.2)
		U.impactRing(front, direction, WHITE, 0.8, 6, 0.25)
		task.delay(0.05, U.impactRing, front + direction, direction, RED, 0.6, 5, 0.25)
		blackSmoke(front, 12, 3, 18)
		U.burst(front, {
			color = RED,
			count = 16,
			size = 0.6,
			speed = NumberRange.new(30, 55),
			lifetime = NumberRange.new(0.15, 0.35),
			streaks = true,
			spread = 30,
			direction = direction,
		})
		blackLightning(front, 4, 4)
		U.light(front, RED, 10, 18, 0.3)
		U.bodyTrail(data.target, WHITE, 0.3)
		if U.isLocal(character) or U.isLocal(data.target) then
			CameraShake.Add(0.3)
			CameraShake.FovKick(5)
		end
	elseif phase == "Land" then
		U.groundRocks(data.position, 8, 3, 1.6)
		blackSmoke(data.position, 10, 3, 12)
	end
end

---------------------------------------------------------------------------
-- Shared skill effects
---------------------------------------------------------------------------

local function bladeOf(character: Model): BasePart?
	local sword = getSword(character)
	local blade = sword and sword:FindFirstChild("Blade")
	return if blade and blade:IsA("BasePart") then blade else nil
end

-- A point along the blade: 0 is its middle, 2.1 the tip, -1.8 the guard.
local function bladePoint(character: Model, along: number): Vector3?
	local blade = bladeOf(character)
	return if blade then (blade.CFrame * CFrame.new(0, along, 0)).Position else nil
end

-- Heavy swing trail for skills: a black core inside a wider red glow that
-- runs past the tip. Built on the spot and thrown away after.
local function heavyTrail(character: Model, duration: number)
	local blade = bladeOf(character)
	if not blade then
		return
	end
	local made: { Instance } = {}
	local function attachment(y: number): Attachment
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, y, 0)
		a.Parent = blade
		table.insert(made, a)
		return a
	end
	local function trail(from: number, to: number, color: ColorSequence, emission: number, lifetime: number, t0: number)
		local t = Instance.new("Trail")
		t.Attachment0 = attachment(from)
		t.Attachment1 = attachment(to)
		t.Color = color
		t.LightEmission = emission
		t.LightInfluence = 0
		t.Lifetime = lifetime
		t.MinLength = 0
		t.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, t0),
			NumberSequenceKeypoint.new(0.6, 0.55 + t0 * 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		t.WidthScale = NumberSequence.new(1, 0.35)
		t.Parent = blade
		table.insert(made, t)
	end
	trail(-1.9, 2.5, ColorSequence.new(RED, DARK_RED), 1, 0.2, 0.25)
	trail(-1.5, 2.0, ColorSequence.new(BLACK), 0, 0.15, 0)
	task.delay(duration, function()
		for _, instance in made do
			if instance:IsA("Trail") then
				instance.Enabled = false
			end
		end
		task.wait(0.3)
		for _, instance in made do
			instance:Destroy()
		end
	end)
end

-- A particle emitter living on a part for `duration` (emits from the part's volume).
local function partEmitter(part: BasePart, props: { [string]: any }, duration: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.LightInfluence = 0
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = part
	task.delay(duration, function()
		emitter.Enabled = false
		task.wait(1.2)
		emitter:Destroy()
	end)
	return emitter
end

-- Anti-magic coating the blade: black wisps peeling off it, red embers.
local function swordAura(character: Model, duration: number, rate: number)
	local blade = bladeOf(character)
	if not blade then
		return
	end
	partEmitter(blade, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(BLACK),
		LightEmission = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.4) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.25, 0.45),
		Rate = rate,
		Speed = NumberRange.new(0.5, 2.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 5, 0),
		Drag = 2,
	}, duration)
	partEmitter(blade, {
		Texture = U.textures.Spark,
		Color = ColorSequence.new(RED),
		LightEmission = 1,
		Size = NumberSequence.new(0.22, 0),
		Lifetime = NumberRange.new(0.2, 0.4),
		Rate = rate * 0.35,
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
	}, duration)
end

--[[
	A crescent slash sweeping from `from` to `to` (degrees around him: 0 is
	straight ahead, positive is his right) at `radius`, tilted `tilt`
	degrees about his forward axis (0 flat, 90 vertical). Drawn segment by
	segment over `sweep` seconds so it trails the blade, tapered at both
	ends: a black core, a red glow and a hot outer edge. Follows the root.
]]
type CrescentOptions = {
	center: CFrame?,
	radius: number,
	from: number,
	to: number,
	tilt: number?,
	width: number,
	sweep: number?,
	fade: number?,
}

local CRESCENT_SEGMENTS = 14

local function crescent(character: Model, options: CrescentOptions)
	local root = U.getRoot(character)
	if not root then
		return
	end
	local holder = U.newPart({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = root.CFrame })
	local frame = (options.center or CFrame.identity) * CFrame.Angles(0, 0, rad(options.tilt or 0))
	local n = CRESCENT_SEGMENTS

	local function ring(radius: number): { Attachment }
		local list = {}
		for i = 0, n do
			local angle = rad(options.from + (options.to - options.from) * i / n)
			local a = Instance.new("Attachment")
			a.Position = frame:PointToWorldSpace(Vector3.new(math.sin(angle) * radius, 0, -math.cos(angle) * radius))
			a.Parent = holder
			list[i] = a
		end
		return list
	end
	local inner = ring(options.radius)
	local outer = ring(options.radius + options.width * 0.42)

	-- Thickest just past the middle, pointed at both ends.
	local function profile(i: number): number
		local x = i / n
		return math.sin(math.pi * x ^ 0.85) ^ 0.7
	end

	type Layer = { beam: Beam, width: number, base: number }
	local segments: { { Layer } } = {}
	local function layer(
		a0: Attachment,
		a1: Attachment,
		color: Color3,
		emission: number,
		width: number,
		z: number
	): Beam
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.FaceCamera = true
		b.Segments = 2
		b.Color = ColorSequence.new(color)
		b.LightEmission = emission
		b.LightInfluence = 0
		b.ZOffset = z
		b.Width0 = width
		b.Width1 = width
		b.Transparency = NumberSequence.new(1)
		b.Parent = holder
		return b
	end
	local w = options.width
	for i = 0, n - 1 do
		local list: { Layer } = {}
		local glow = layer(inner[i], inner[i + 1], RED, 1, 0, 0)
		local core = layer(inner[i], inner[i + 1], BLACK, 0, 0, 0.05)
		local edge = layer(outer[i], outer[i + 1], Color3.fromRGB(255, 170, 170), 1, 0, 0.1)
		table.insert(list, { beam = glow, width = w * 1.6, base = 0.3 })
		table.insert(list, { beam = core, width = w, base = 0 })
		table.insert(list, { beam = edge, width = w * 0.16, base = 0.1 })
		segments[i + 1] = list
	end

	local sweep = options.sweep or 0.08
	local fade = options.fade or 0.25
	local hold = 0.04
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if root.Parent then
			holder.CFrame = root.CFrame
		end
		for i, list in segments do
			local appear = sweep * (i - 1) / n
			local alpha = if t < appear then -1 else math.clamp((t - appear - hold) / fade, 0, 1)
			local w0, w1 = profile(i - 1), profile(i)
			for _, entry in list do
				local beam = entry.beam
				if alpha < 0 then
					beam.Transparency = NumberSequence.new(1)
				else
					local thin = 1 - 0.65 * alpha
					beam.Width0 = entry.width * w0 * thin
					beam.Width1 = entry.width * w1 * thin
					beam.Transparency = NumberSequence.new(entry.base + (1 - entry.base) * alpha)
				end
			end
		end
		if t > sweep + hold + fade then
			connection:Disconnect()
			holder:Destroy()
		end
	end)
end

-- A dark mote with a red tail streaking into `target` (anti-magic gathering).
local function inflow(target: Vector3, radius: number)
	local from = target + U.randomUnit() * radius
	local orb = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (0.25 + math.random() * 0.25),
		CFrame = CFrame.new(from),
		Color = BLACK,
		Material = Enum.Material.SmoothPlastic,
	})
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.12, 0)
	a0.Parent = orb
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.12, 0)
	a1.Parent = orb
	local tail = Instance.new("Trail")
	tail.Attachment0 = a0
	tail.Attachment1 = a1
	tail.Color = ColorSequence.new(BLACK, DARK_RED)
	tail.LightEmission = 0
	tail.LightInfluence = 0
	tail.Lifetime = 0.12
	tail.MinLength = 0
	tail.FaceCamera = true
	tail.WidthScale = NumberSequence.new(1, 0)
	tail.Parent = orb
	U.tween(
		orb,
		0.2,
		{ CFrame = CFrame.new(target), Size = Vector3.one * 0.05 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(0.35, orb.Destroy, orb)
end

-- Little black bolts snapping around a part for `duration`.
local function crackle(part: BasePart, duration: number, interval: number, radius: number)
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < duration and part.Parent do
			local from = part.Position + U.randomUnit() * radius * 0.3
			U.lightning(from, from + U.randomUnit() * radius, BLACK, RED, 0.1, 0.14, false)
			task.wait(interval)
		end
	end)
end

-- One-frame monochrome "impact frame", for the people involved in a big hit.
local function impactFrame(strength: number?)
	local k = strength or 1
	U.colorGrade({ Brightness = 0.25 * k, Contrast = 0.85 * k, Saturation = -1 }, 0, 0.06, 0.22)
end

local function involves(data, character: Model): boolean
	return U.isLocal(character) or U.isLocal(data.target)
end

-- Bumped whenever a skill phase starts, so a charge loop stops as soon as
-- that skill is released or cancelled.
local castTokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local function bump(character: Model): number
	local token = (castTokens[character] or 0) + 1
	castTokens[character] = token
	return token
end
local function live(character: Model, token: number): boolean
	return castTokens[character] == token and character.Parent ~= nil
end

-- Smoke that hangs over a spot for a while after a big impact.
local function lingerSmoke(position: Vector3, duration: number, size: number)
	local holder = U.newPart({ Size = Vector3.new(size, 0.2, size), Transparency = 1, CFrame = CFrame.new(position) })
	partEmitter(holder, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(Color3.fromRGB(28, 26, 28)),
		LightEmission = 0,
		Size = NumberSequence.new(size * 0.4, size * 0.8),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1, 1.6),
		Rate = 14,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, 2, 0),
		EmissionDirection = Enum.NormalId.Top,
	}, duration)
	task.delay(duration + 1.8, holder.Destroy, holder)
end

---------------------------------------------------------------------------
-- Black Meteorite: lunge grab, carry them up, crater slam
---------------------------------------------------------------------------

function handlers.BlackMeteorite(data, character, root)
	local phase = data.phase
	if phase == "Lunge" then
		local direction = root.CFrame.LookVector
		play(character, ANIMS.MeteorLunge)
		swordTrail(character, 0.35)
		-- Anti-magic coats him for the lunge.
		U.highlight(character, BLACK, 0.35)
		local back = root.Position - direction * 1.2
		U.flash(back, BLACK, 5, 0.16)
		U.impactRing(back, direction, BLACK, 0.6, 4.5, 0.22)
		task.delay(0.04, U.impactRing, back, direction, RED, 0.4, 3.2, 0.2)
		blackSmoke(back, 10, 2.6, 14)
		U.ringBurst(CFrame.new(feetOf(character, root) + UP * 0.1), BLACK, 0.6, 4, 0.25, 0.18)
		U.speedLines(root, direction, 0.3)
		U.bodyTrail(character, BLACK, 0.35)
		crackle(root, 0.3, 0.06, 2.6)
		for i = 0, 3 do
			task.delay(i * 0.06, function()
				if character.Parent then
					U.afterimage(character, if i % 2 == 0 then BLACK else DARK_RED, 0.25)
				end
			end)
		end
		if U.isLocal(character) then
			CameraShake.FovKick(8)
		end
	elseif phase == "Seize" then
		-- The grab: his free hand clamps on their throat and hoists them,
		-- anti-magic pouring out of his grip and through them.
		play(character, ANIMS.Seize)
		local target = data.target
		local mine = involves(data, character)
		local function grip(): Vector3?
			local hand = character:FindFirstChild("Left Arm")
			return if hand and hand:IsA("BasePart") then (hand.CFrame * CFrame.new(0, -1, 0)).Position else nil
		end
		task.delay(0.07, function()
			local at = grip()
			if not at or not character.Parent then
				return
			end
			U.flash(at, WHITE, 3, 0.08)
			U.flash(at, BLACK, 5, 0.18)
			U.impactRing(at, root.CFrame.LookVector, RED, 0.4, 3.5, 0.2)
			redSparks(at, 12, 0.7)
			U.highlight(target, BLACK, 0.3)
			blackSmoke(feetOf(character, root) + UP * 0.3, 6, 2.2, 6)
			U.ringBurst(CFrame.new(feetOf(character, root) + UP * 0.1), BLACK, 0.8, 5, 0.25, 0.2)
			if mine then
				CameraShake.Add(0.25)
				CameraShake.FovKick(-6)
			end
		end)
		-- The surge (it lands with the server's 2-damage hit).
		task.delay(0.2, function()
			local at = grip()
			local targetRoot = U.getRoot(target)
			if not at or not targetRoot or not character.Parent then
				return
			end
			for _ = 1, 6 do
				local point = targetRoot.Position + U.randomUnit() * Vector3.new(1.1, 1.8, 0.6)
				U.lightning(at, point, BLACK, RED, 0.12, 0.2)
			end
			crackle(targetRoot, 0.25, 0.04, 2.5)
			U.highlight(target, RED, 0.25)
			U.flash(targetRoot.Position, RED, 5, 0.15)
			U.light(targetRoot.Position, RED, 9, 14, 0.3)
			for _ = 1, 4 do
				inflow(at, 3.5)
			end
			if mine then
				CameraShake.Add(0.2)
			end
		end)
	elseif phase == "Rise" then
		play(character, ANIMS.MeteorRise)
		local target = data.target
		local feet = feetOf(character, root)

		-- Take-off: the ground blows out under them.
		U.flash(feet + UP, BLACK, 9, 0.25)
		U.shockwave(feet, RED, 2, 14, 0.35)
		U.ringBurst(CFrame.new(feet + UP * 0.15), BLACK, 1, 10, 0.35, 0.45)
		task.delay(0.04, U.ringBurst, CFrame.new(feet + UP * 0.2), RED, 0.8, 7, 0.3, 0.2)
		U.groundCracks(feet, 7, 6, RED, 2)
		U.groundRocks(feet, 8, 3, 1.6)
		U.debris(feet, 8, 38, 1)
		blackSmoke(feet + UP * 0.5, 16, 3.5, 18)
		U.pillar(feet, BLACK, 1.6, 18, 0.45, Enum.Material.SmoothPlastic, 0.2)
		U.light(feet, RED, 8, 18, 0.35)

		-- Rocketing up together: trails, spiralling anti-magic, speed lines.
		U.bodyTrail(character, BLACK, 0.55)
		U.bodyTrail(target, DARK_RED, 0.55)
		U.spiral(root, BLACK, 3.2, 3, 0.5, 3, 0.55, 0.3)
		U.spiral(root, RED, 2.6, 3, 0.5, 2, 0.22, 0.3)
		U.speedLines(root, UP, 0.4)

		-- At the top: the blade drinks in anti-magic before the slam.
		task.delay(0.36, function()
			if not character.Parent then
				return
			end
			swordGlow(character, BLACK, 0.3, 0)
			swordAura(character, 0.5, 45)
			local tip = bladePoint(character, 2.1)
			if tip then
				U.glint(tip, 1.8, RED)
				blackLightning(tip, 4, 3)
				U.light(tip, RED, 8, 14, 0.3)
			end
			for _ = 1, 6 do
				local blade = bladeOf(character)
				if blade then
					inflow(blade.Position, 4)
				end
			end
		end)
		if involves(data, character) then
			CameraShake.Add(0.3)
			CameraShake.FovKick(10)
		end
	elseif phase == "Slam" then
		play(character, ANIMS.MeteorSlam)
		heavyTrail(character, 0.5)
		U.bodyTrail(character, RED, 0.5)
		U.bodyTrail(data.target, BLACK, 0.5)
		local down = (-UP + root.CFrame.LookVector * 0.05).Unit
		U.speedLines(root, down, 0.45)
		-- A meteor's tail: black smoke and red streaks pouring off upward.
		trailEmitter(root, {
			Texture = U.textures.Smoke,
			Color = ColorSequence.new(BLACK),
			LightEmission = 0,
			Size = NumberSequence.new(1.8, 4),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.3, 0.55),
			Rate = 140,
			Speed = NumberRange.new(4, 10),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(30, 30),
			Drag = 3,
		}, 0.45)
		trailEmitter(root, {
			Texture = U.textures.Spark,
			Color = ColorSequence.new(RED, DARK_RED),
			LightEmission = 1,
			Size = NumberSequence.new(0.4, 0),
			Lifetime = NumberRange.new(0.15, 0.3),
			Rate = 70,
			Speed = NumberRange.new(14, 24),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(25, 25),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Squash = NumberSequence.new(1.6),
		}, 0.45)
		-- Air compressing under them on the way down.
		for i = 0, 6 do
			task.delay(i * 0.06, function()
				if root.Parent then
					U.ringBurst(
						CFrame.new(root.Position - UP * 3.4),
						if i % 2 == 0 then BLACK else RED,
						1.2,
						3.8,
						0.18,
						0.15
					)
				end
			end)
		end
		if U.isLocal(character) then
			CameraShake.FovKick(12)
		end
	elseif phase == "Impact" then
		local position: Vector3 = data.position
		play(character, ANIMS.MeteorImpact)
		local victim = data.target
		U.flash(position + UP, WHITE, 6, 0.08)
		U.flash(position + UP, BLACK, 16, 0.35)
		U.flash(position + UP, RED, 10, 0.25)
		U.shockwave(position, BLACK, 4, 30, 0.5, Enum.Material.Glass, 0.35)
		U.shockwave(position, RED, 3, 24, 0.45)
		U.ringBurst(CFrame.new(position + UP * 0.2), BLACK, 1.5, 20, 0.5, 0.7)
		task.delay(0.05, U.ringBurst, CFrame.new(position + UP * 0.3), RED, 1, 15, 0.4, 0.35)
		task.delay(0.1, U.ringBurst, CFrame.new(position + UP * 0.4), WHITE, 0.5, 10, 0.25, 0.12)
		U.groundCracks(position, 12, 13, RED, 3)
		U.groundRocks(position, 16, 6, 2.8)
		task.delay(0.05, U.groundRocks, position, 9, 2.8, 2)
		U.debris(position, 22, 55, 1.5)
		U.pillar(position, BLACK, 3.2, 26, 0.55, Enum.Material.SmoothPlastic, 0.15)
		U.pillar(position, RED, 1.6, 30, 0.45)
		blackSmoke(position + UP, 26, 6, 32)
		U.burst(position, {
			texture = U.textures.Smoke,
			color = Color3.fromRGB(150, 140, 130),
			count = 18,
			size = 7,
			speed = NumberRange.new(20, 40),
			lifetime = NumberRange.new(0.8, 1.4),
			lightEmission = 0,
			transparency = 0.35,
			drag = 2,
			spread = 30,
			direction = (UP + Vector3.new(0.01, 0, 0)).Unit,
		})
		for i = 1, 10 do
			local angle = (i / 10) * math.pi * 2 + math.random() * 0.4
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			U.lightning(position + UP * 0.4, position + out * (9 + math.random() * 7) + UP * 0.3, BLACK, RED, 0.2, 0.3)
		end
		redSparks(position + UP, 30, 1.4)
		U.light(position + UP * 2, RED, 14, 40, 0.6)
		lingerSmoke(position, 1.5, 7)
		if victim then
			U.highlight(victim, RED, 0.35)
		end
		if involves(data, character) then
			impactFrame()
			CameraShake.FovKick(14)
		end
	end
end

---------------------------------------------------------------------------
-- Black Divider: charged cleave; press again on the red flash for a perfect
---------------------------------------------------------------------------

function handlers.BlackDivider(data, character, root)
	local phase = data.phase
	local token = bump(character)
	if phase == "Charge" then
		play(character, if data.airborne then ANIMS.AirDividerCharge else ANIMS.DividerCharge)
		local flashAt = data.flashAt or 0.38
		swordGlow(character, BLACK, 0.62, 0.35)
		swordAura(character, 0.62, 30)
		-- The air gets pulled in toward him (around him when he's hanging in the air).
		local center = if data.airborne then root.Position else feetOf(character, root) + UP * 0.1
		U.ringBurst(CFrame.new(center), BLACK, 9, 1.5, 0.6, 0.25)
		task.delay(0.2, U.ringBurst, CFrame.new(center + UP * 0.02), DARK_RED, 7, 1, 0.42, 0.15)
		blackSmoke(center + UP * 0.2, 8, 2.4, 6)
		if not data.airborne then
			task.delay(0.15, U.groundCracks, center, 5, 3.5, RED, 1.2)
		end

		-- Anti-magic streaming into the blade, crackling as it builds.
		local start = os.clock()
		task.spawn(function()
			while os.clock() - start < 0.6 and live(character, token) do
				local blade = bladeOf(character)
				if blade then
					inflow(blade.Position, 4.5)
					if math.random() < 0.45 then
						blackLightning(blade.Position, 1, 2.2, 0.12)
					end
				end
				if U.isLocal(character) then
					CameraShake.Add(0.03)
				end
				task.wait(0.045)
			end
		end)

		-- The timing flash: press 3 right now for a perfect Divider.
		task.delay(flashAt, function()
			if not live(character, token) then
				return
			end
			swordGlow(character, RED, 0.25, 0)
			local tip = bladePoint(character, 1.6)
			if tip then
				U.glint(tip, 2.4, RED)
				task.delay(0.03, U.glint, tip, 1.4, WHITE)
				U.impactRing(tip, workspace.CurrentCamera.CFrame.Position - tip, RED, 0.3, 3.2, 0.2)
				U.light(tip, RED, 12, 16, 0.25)
				redSparks(tip, 10, 0.6)
			end
			if U.isLocal(character) then
				CameraShake.FovKick(-5)
			end
		end)
	elseif phase == "Cancel" then
		local blade = bladeOf(character)
		if blade then
			blackSmoke(blade.Position, 6, 2, 5)
		end
	elseif phase == "Release" and data.airborne then
		-- Air version: a front flip, the blade going all the way round and
		-- down onto whoever is below.
		local perfect = data.perfect == true
		local look = root.CFrame.LookVector
		play(character, ANIMS.AirDividerRelease)
		heavyTrail(character, 0.35)
		crescent(character, {
			center = CFrame.new(0, 0.3, 0),
			radius = if perfect then 6.4 else 5.6,
			from = 150,
			to = -170,
			tilt = 90,
			width = if perfect then 2.8 else 2,
			sweep = 0.18,
			fade = 0.3,
		})
		blackSmoke(root.Position, if perfect then 16 else 8, 3.5, 14)
		U.burst(root.Position - UP * 2 + look * 2, {
			color = RED,
			count = if perfect then 24 else 12,
			size = 0.7,
			speed = NumberRange.new(35, 65),
			lifetime = NumberRange.new(0.15, 0.35),
			streaks = true,
			spread = 35,
			direction = (look - UP * 1.4).Unit,
		})
		-- The blow lands on the ground below.
		task.delay(0.16, function()
			local ground = U.groundBelow(root.Position + look * 3, { character })
			if not ground then
				return
			end
			local spot = ground.Position
			U.flash(spot + UP, BLACK, if perfect then 12 else 7, 0.25)
			U.ringBurst(CFrame.new(spot + UP * 0.2), BLACK, 1, if perfect then 14 else 9, 0.35, 0.4)
			task.delay(0.04, U.ringBurst, CFrame.new(spot + UP * 0.3), RED, 0.8, if perfect then 10 else 6, 0.3, 0.2)
			U.groundCracks(spot, if perfect then 10 else 6, if perfect then 9 else 5, RED, 2)
			U.groundRocks(spot, if perfect then 10 else 6, 3, 1.6)
			blackSmoke(spot + UP, if perfect then 16 else 8, 4, 18)
			U.light(spot + UP, RED, if perfect then 12 else 6, 22, 0.35)
			if perfect then
				U.shockwave(spot, RED, 2, 18, 0.4)
				U.debris(spot, 12, 40, 1.1)
				blackLightning(spot + UP, 8, 7, 0.28)
			end
		end)
		if perfect then
			U.popup(root.Position + UP * 4.5, "PERFECT DIVIDER", RED, 1.8)
			if U.isLocal(character) then
				impactFrame()
				U.screenFlash(RED, 0.35)
				CameraShake.FovKick(14)
			end
		elseif U.isLocal(character) then
			CameraShake.FovKick(7)
		end
	elseif phase == "Release" then
		local perfect = data.perfect == true
		local look = root.CFrame.LookVector
		play(character, ANIMS.DividerRelease)
		heavyTrail(character, 0.3)
		-- The cleave: a wide crescent sweeping right to left with the blade.
		crescent(character, {
			center = CFrame.new(0, 0.2, 0.3),
			radius = if perfect then 6.6 else 5.8,
			from = 120,
			to = -125,
			tilt = -6,
			width = if perfect then 3 else 2.1,
			sweep = 0.09,
			fade = if perfect then 0.35 else 0.26,
		})
		if perfect then
			task.delay(0.03, crescent, character, {
				center = CFrame.new(0, 0.5, 0.3),
				radius = 8.2,
				from = 100,
				to = -105,
				tilt = -10,
				width = 1.2,
				sweep = 0.09,
				fade = 0.3,
			})
		end

		local front = root.Position + look * 5
		local feet = feetOf(character, root)
		-- The cut's wind: rings, dust and a cone of sparks.
		U.ringBurst(CFrame.new(root.Position + UP * 0.2), WHITE, 2, if perfect then 16 else 10, 0.3, 0.12)
		U.ringBurst(CFrame.new(root.Position + UP * 0.2), BLACK, 2, if perfect then 20 else 12, 0.4, 0.35)
		blackSmoke(front, if perfect then 20 else 10, 4, 24)
		U.burst(front, {
			color = RED,
			count = if perfect then 26 else 14,
			size = 0.7,
			speed = NumberRange.new(35, 65),
			lifetime = NumberRange.new(0.15, 0.35),
			streaks = true,
			spread = 50,
			direction = look,
		})
		U.burst(feet, {
			texture = U.textures.Smoke,
			color = Color3.fromRGB(150, 140, 130),
			count = 10,
			size = 3.5,
			speed = NumberRange.new(10, 20),
			lifetime = NumberRange.new(0.5, 0.9),
			lightEmission = 0,
			transparency = 0.45,
			drag = 3,
			spread = 75,
		})
		U.light(front, RED, if perfect then 14 else 7, if perfect then 30 else 18, 0.35)

		if perfect then
			U.popup(root.Position + UP * 4.5, "PERFECT DIVIDER", RED, 1.8)
			task.delay(0.08, function()
				U.flash(front, BLACK, 14, 0.3)
				U.shockwave(front, RED, 3, 22, 0.4)
				U.shockwave(front, BLACK, 4, 18, 0.35, Enum.Material.Glass, 0.4)
				blackLightning(front, 10, 9, 0.28)
				U.groundCracks(front, 9, 10, RED, 2.5)
				U.debris(front, 12, 40, 1.1)
				-- The cut keeps going: a black crescent rushing on ahead.
				slashWave({
					origin = root.Position + UP * 0.4 + look * 3,
					direction = look,
					speed = 150,
					range = 26,
					width = 16,
					grand = true,
				})
			end)
			if U.isLocal(character) then
				impactFrame()
				U.screenFlash(RED, 0.35)
				CameraShake.FovKick(14)
			end
		elseif U.isLocal(character) then
			CameraShake.FovKick(7)
		end
	end
end

---------------------------------------------------------------------------
-- Anti-Magic Deflect: an anti-magic barrier on the blade that counters
-- anything; melee gets slashed aside, projectiles get sent back
---------------------------------------------------------------------------

local barriers: { [Model]: (shatter: boolean) -> () } = setmetatable({}, { __mode = "k" }) :: any

-- A shimmering black disc held up in front of him with a spinning red rim.
local function openBarrier(character: Model, root: BasePart, duration: number)
	local offset = CFrame.new(0, 0.6, -2.4)
	local face = CFrame.Angles(0, rad(90), 0) -- cylinders run along X; turn X forward
	local radius = 3.2
	local disc = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 0.5, 0.5),
		Color = BLACK,
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	local shimmer = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 0.5, 0.5),
		Color = RED,
		Material = Enum.Material.ForceField,
	})
	local rim: { BasePart } = {}
	local count = 20
	for i = 1, count do
		table.insert(
			rim,
			U.newPart({
				Size = Vector3.new(2 * math.pi * radius / count * 0.75, 0.12, 0.12),
				Color = if i % 2 == 0 then RED else DARK_RED,
			})
		)
	end
	local inner: { BasePart } = {}
	for i = 1, 10 do
		table.insert(
			inner,
			U.newPart({
				Size = Vector3.new(2 * math.pi * radius * 0.5 / 10 * 0.6, 0.08, 0.08),
				Color = RED,
				Transparency = 0.3,
			})
		)
	end
	local all: { BasePart } = { disc, shimmer }
	for _, part in rim do
		table.insert(all, part)
	end
	for _, part in inner do
		table.insert(all, part)
	end

	local start = os.clock()
	local closed = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local grow = math.min(t / 0.08, 1)
		local scale = (0.3 + 0.7 * grow) * (1 + 0.04 * math.sin(t * 22))
		local base = root.CFrame * offset
		local r = radius * scale
		disc.Size = Vector3.new(0.1, r * 2, r * 2)
		disc.CFrame = base * face
		shimmer.Size = Vector3.new(0.12, r * 2.05, r * 2.05)
		shimmer.CFrame = base * face
		for i, part in rim do
			part.CFrame = base * CFrame.Angles(0, 0, t * 2.5 + (i / count) * math.pi * 2) * CFrame.new(0, r, 0)
		end
		for i, part in inner do
			part.CFrame = base * CFrame.Angles(0, 0, -t * 4 + (i / 10) * math.pi * 2) * CFrame.new(0, r * 0.5, -0.05)
		end
		if t > duration + 0.5 then
			barriers[character] = nil
			connection:Disconnect()
			for _, part in all do
				part:Destroy()
			end
		end
	end)

	local function close(shatter: boolean)
		if closed then
			return
		end
		closed = true
		barriers[character] = nil
		local center = disc.Position
		if shatter then
			U.shards(center, BLACK, 10)
			U.shards(center, RED, 6)
			U.flash(center, WHITE, 5, 0.1)
			U.impactRing(center, root.CFrame.LookVector, RED, radius, radius * 2.2, 0.22)
		end
		connection:Disconnect()
		for _, part in all do
			if shatter then
				part:Destroy()
			else
				U.tween(part, 0.15, { Transparency = 1 })
				task.delay(0.16, part.Destroy, part)
			end
		end
	end
	barriers[character] = close
	task.delay(duration, close, false)
end

local function closeBarrier(character: Model, shatter: boolean)
	local close = barriers[character]
	if close then
		close(shatter)
	end
end

function handlers.Deflect(data, character, root)
	local phase = data.phase
	local look = root.CFrame.LookVector
	if phase == "Stance" then
		play(character, ANIMS.DeflectStance)
		swordGlow(character, BLACK, 0.85, 0.25)
		swordAura(character, 0.8, 26)
		task.delay(0.08, function()
			local tip = bladePoint(character, 1.8)
			if tip and character.Parent then
				U.glint(tip, 1.6, RED)
			end
		end)
		openBarrier(character, root, if type(data.window) == "number" then data.window else 0.65)
		local feet = feetOf(character, root)
		U.ringBurst(CFrame.new(feet + UP * 0.1), DARK_RED, 1, 5, 0.3, 0.15)
		blackSmoke(feet + UP * 0.3, 6, 2, 5)
		if U.isLocal(character) then
			CameraShake.FovKick(-3)
		end
	elseif phase == "Counter" then
		closeBarrier(character, true)
		play(character, ANIMS.DeflectCounter)
		local target = data.target
		local targetRoot = U.getRoot(target)
		local contact = if targetRoot
			then (root.Position + targetRoot.Position) / 2 + UP * 0.6
			else root.Position + look * 2.5
		local toward = if targetRoot then targetRoot.Position - root.Position else look
		local flat = Vector3.new(toward.X, 0, toward.Z)
		flat = if flat.Magnitude > 0.1 then flat.Unit else look

		-- Their attack lands on the anti-magic blade.
		U.sparks(contact, (flat + UP * 0.6).Unit, 1.6)
		U.flash(contact, WHITE, 6, 0.12)
		if involves(data, character) then
			impactFrame(1.2)
			CameraShake.Add(0.45)
			CameraShake.FovKick(12)
		end
		PoseAnimator.Freeze(character, 0.08)
		U.popup(root.Position + UP * 4, "DEFLECT", RED, 1.6)

		-- Then the answer: a diagonal slash that throws them aside (the
		-- swing lands at 0.13s, plus the 0.08s freeze).
		task.delay(0.14, function()
			heavyTrail(character, 0.25)
			crescent(character, {
				center = CFrame.new(0, 0.6, 0),
				radius = 6,
				from = -110,
				to = 110,
				tilt = -35,
				width = 2.6,
				sweep = 0.07,
				fade = 0.3,
			})
		end)
		task.delay(0.2, function()
			if not targetRoot then
				return
			end
			local p = targetRoot.Position + UP * 0.5
			local side = root.CFrame.RightVector
			slashMark(p, -0.6, 8, 0.35)
			task.delay(0.03, slashMark, p, -0.52, 6, 0.3)
			blackLightning(p, 6, 4.5)
			U.impactRing(p, side, RED, 0.8, 7, 0.3)
			task.delay(0.04, U.impactRing, p, side, BLACK, 0.6, 6, 0.3)
			blackSmoke(p, 14, 3.5, 20)
			U.burst(p, {
				color = RED,
				count = 18,
				size = 0.7,
				speed = NumberRange.new(30, 55),
				lifetime = NumberRange.new(0.15, 0.35),
				streaks = true,
				spread = 35,
				direction = side,
			})
			U.light(p, RED, 12, 22, 0.35)
		end)
	elseif phase == "Reflect" then
		closeBarrier(character, true)
		play(character, ANIMS.DeflectReflect)
		local direction: Vector3 = if typeof(data.direction) == "Vector3" then data.direction else look
		heavyTrail(character, 0.3)
		-- Wind-up to the left until 0.08s, then the swing across.
		task.delay(0.07, crescent, character, {
			center = CFrame.new(0, 0.4, 0),
			radius = 5.6,
			from = -120,
			to = 70,
			tilt = 4,
			width = 2.2,
			sweep = 0.08,
			fade = 0.26,
		})
		local front = root.Position + direction * 3
		U.sparks(front, direction, 1.3)
		U.flash(front, BLACK, 8, 0.2)
		U.impactRing(front, direction, RED, 0.6, 6, 0.25)
		task.delay(0.05, U.impactRing, front + direction, direction, BLACK, 0.5, 5, 0.25)
		blackSmoke(front, 10, 3, 18)
		U.popup(root.Position + UP * 4, "REFLECT", RED, 1.5)
		if U.isLocal(character) then
			CameraShake.FovKick(8)
			CameraShake.Add(0.25)
		end
	elseif phase == "End" then
		closeBarrier(character, false)
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
		play(character, ANIMS.MeteorLunge)
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

---------------------------------------------------------------------------
-- Special (R): Anti-Magic Leap / Meteor Plunge
---------------------------------------------------------------------------

-- The black meteor tail and air rings while diving (Meteorite slam, Plunge).
local function meteorTail(root: BasePart, duration: number)
	trailEmitter(root, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(BLACK),
		LightEmission = 0,
		Size = NumberSequence.new(1.8, 4),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.3, 0.55),
		Rate = 140,
		Speed = NumberRange.new(4, 10),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(30, 30),
		Drag = 3,
	}, duration)
	trailEmitter(root, {
		Texture = U.textures.Spark,
		Color = ColorSequence.new(RED, DARK_RED),
		LightEmission = 1,
		Size = NumberSequence.new(0.4, 0),
		Lifetime = NumberRange.new(0.15, 0.3),
		Rate = 70,
		Speed = NumberRange.new(14, 24),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = NumberSequence.new(1.6),
	}, duration)
	for i = 0, math.floor(duration / 0.06) do
		task.delay(i * 0.06, function()
			if root.Parent then
				U.ringBurst(
					CFrame.new(root.Position - UP * 3.4),
					if i % 2 == 0 then BLACK else RED,
					1.2,
					3.8,
					0.18,
					0.15
				)
			end
		end)
	end
end

function handlers.Special(data, character, root)
	local phase = data.phase
	if phase == "Leap" then
		play(character, ANIMS.Leap)
		local feet = feetOf(character, root)
		-- Blasting off a burst of anti-magic.
		U.flash(feet + UP * 0.5, BLACK, 8, 0.22)
		U.shockwave(feet, RED, 2, 12, 0.3)
		U.ringBurst(CFrame.new(feet + UP * 0.15), BLACK, 1, 9, 0.32, 0.4)
		task.delay(0.04, U.ringBurst, CFrame.new(feet + UP * 0.2), RED, 0.8, 6, 0.28, 0.18)
		U.groundCracks(feet, 6, 4.5, RED, 1.6)
		U.debris(feet, 7, 34, 0.9)
		blackSmoke(feet + UP * 0.4, 14, 3.2, 16)
		U.burst(feet, {
			texture = U.textures.Smoke,
			color = Color3.fromRGB(150, 140, 130),
			count = 10,
			size = 3.5,
			speed = NumberRange.new(10, 20),
			lifetime = NumberRange.new(0.5, 0.9),
			lightEmission = 0,
			transparency = 0.45,
			drag = 3,
			spread = 75,
		})
		U.light(feet, RED, 7, 16, 0.3)
		U.bodyTrail(character, BLACK, 0.6)
		U.speedLines(root, nil, 0.3)
		swordTrail(character, 0.5)
		for i = 0, 3 do
			task.delay(i * 0.06, function()
				if character.Parent then
					U.afterimage(character, if i % 2 == 0 then BLACK else DARK_RED, 0.25)
				end
			end)
		end
		if U.isLocal(character) then
			CameraShake.FovKick(10)
			CameraShake.Add(0.15)
		end
	elseif phase == "Plunge" then
		play(character, ANIMS.Plunge)
		swordGlow(character, BLACK, 0.4, 0.1)
		swordAura(character, 0.6, 40)
		crackle(root, 0.15, 0.04, 2.5)
		U.ringBurst(CFrame.new(root.Position), BLACK, 1, 5, 0.2, 0.15)
		task.delay(0.08, function()
			local tip = bladePoint(character, 2.1)
			if tip and character.Parent then
				U.glint(tip, 1.6, RED)
			end
		end)
	elseif phase == "Dive" then
		heavyTrail(character, 0.6)
		U.bodyTrail(character, RED, 0.6)
		U.speedLines(root, nil, 0.6)
		meteorTail(root, 0.5)
		if U.isLocal(character) then
			CameraShake.FovKick(10)
		end
	elseif phase == "Impact" then
		local position: Vector3 = data.position
		play(character, ANIMS.PlungeImpact)
		U.flash(position + UP, WHITE, 4, 0.07)
		U.flash(position + UP, BLACK, 11, 0.28)
		U.flash(position + UP, RED, 7, 0.2)
		U.shockwave(position, RED, 2, 17, 0.35)
		U.shockwave(position, BLACK, 3, 20, 0.4, Enum.Material.Glass, 0.45)
		U.ringBurst(CFrame.new(position + UP * 0.2), BLACK, 1, 13, 0.4, 0.5)
		task.delay(0.05, U.ringBurst, CFrame.new(position + UP * 0.3), RED, 0.8, 9, 0.32, 0.25)
		U.groundCracks(position, 9, 8, RED, 2.2)
		U.groundRocks(position, 10, 4, 2)
		U.debris(position, 12, 45, 1.1)
		U.pillar(position, BLACK, 1.6, 14, 0.4, Enum.Material.SmoothPlastic, 0.2)
		blackSmoke(position + UP, 18, 4.5, 24)
		for i = 1, 6 do
			local angle = (i / 6) * math.pi * 2 + math.random() * 0.5
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			U.lightning(
				position + UP * 0.4,
				position + out * (6 + math.random() * 5) + UP * 0.3,
				BLACK,
				RED,
				0.16,
				0.25
			)
		end
		redSparks(position + UP, 18, 1)
		U.light(position + UP * 2, RED, 10, 26, 0.45)
		lingerSmoke(position, 1, 5)
		if U.isLocal(character) then
			CameraShake.FovKick(10)
		end
	end
end

---------------------------------------------------------------------------
-- Black Form look: a devil wing with its own idle, a horn, black flames
---------------------------------------------------------------------------

--[[
	The wing is a two-bone arm (shoulder to wrist, wrist to tip) with
	feathers fanned off it, posed every frame from a few numbers:
	  lift  how high the upper bone rises (degrees)
	  back  how far it sweeps behind him
	  bend  the forearm's angle at the wrist (negative droops)
	  fan   how far the feathers spread apart
	  sway  how much the feathers ripple
	  beat  flap strength, at `rate` flaps per second
	Each state below sets targets and the live values ease toward them, so
	the wing breathes slowly when he stands, tucks back and flutters when he
	runs, beats hard in the air and snaps open in a big stretch now and then.
]]
type WingParams = {
	lift: number,
	back: number,
	bend: number,
	fan: number,
	sway: number,
	beat: number,
	rate: number,
}

local WING_STATES: { [string]: WingParams } = {
	folded = { lift = -65, back = 55, bend = -125, fan = 0.1, sway = 0, beat = 0, rate = 0.4 },
	stand = { lift = 30, back = 26, bend = -32, fan = 1, sway = 1, beat = 0.22, rate = 0.42 },
	run = { lift = 26, back = 60, bend = -28, fan = 1.15, sway = 0.7, beat = 0.08, rate = 2.4 },
	air = { lift = 26, back = 22, bend = -12, fan = 1.25, sway = 0.45, beat = 1, rate = 1.35 },
}

local UPPER_BONE, FOREARM = 2.2, 2.6

-- Feathers: which bone, where along it (0 to 1), fan angle out from
-- hanging straight down, length and width. Longest out at the tip.
local FEATHERS = {
	{ bone = 1, at = 0.25, angle = 4, length = 1.7, width = 0.55 },
	{ bone = 1, at = 0.55, angle = 10, length = 2.1, width = 0.58 },
	{ bone = 1, at = 0.85, angle = 16, length = 2.5, width = 0.6 },
	{ bone = 2, at = 0.15, angle = 22, length = 2.9, width = 0.6 },
	{ bone = 2, at = 0.4, angle = 30, length = 3.3, width = 0.6 },
	{ bone = 2, at = 0.62, angle = 40, length = 3.5, width = 0.58 },
	{ bone = 2, at = 0.82, angle = 52, length = 3.4, width = 0.55 },
	{ bone = 2, at = 1.0, angle = 66, length = 3.0, width = 0.5 },
	{ bone = 2, at = 1.0, angle = 84, length = 2.4, width = 0.45 },
}

-- Horn segments from the base up, curling out and back in.
local HORN = {
	{ size = Vector3.new(0.3, 0.42, 0.3), bend = rot(-10, 0, 14) },
	{ size = Vector3.new(0.23, 0.4, 0.23), bend = rot(-12, 0, 12) },
	{ size = Vector3.new(0.16, 0.36, 0.16), bend = rot(-14, 0, 10) },
	{ size = Vector3.new(0.09, 0.32, 0.09), bend = rot(0) },
}

type BlackFormVisual = {
	flap: (() -> ())?,
	cleanup: { () -> () },
}
local awakenedVisuals: { [Model]: BlackFormVisual } = {}

local function lerpParams(from: WingParams, to: WingParams, alpha: number): WingParams
	local out = {} :: any
	for key, value in from do
		out[key] = value + ((to :: any)[key] - value) * alpha
	end
	return out
end

local function setAwakened(character: Model, on: boolean)
	local existing = awakenedVisuals[character]
	if existing then
		awakenedVisuals[character] = nil
		for _, cleanup in existing.cleanup do
			cleanup()
		end
	end
	if not on then
		return
	end

	local torso = character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")
	local root = U.getRoot(character)
	if not (torso and torso:IsA("BasePart") and head and head:IsA("BasePart") and root) then
		return
	end
	local cleanup: { () -> () } = {}
	local visual: BlackFormVisual = { cleanup = cleanup }
	awakenedVisuals[character] = visual

	local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		e.LightInfluence = 0
		for key, value in props do
			(e :: any)[key] = value
		end
		e.Parent = parent
		table.insert(cleanup, function()
			e.Enabled = false
			task.delay(1.2, e.Destroy, e)
		end)
		return e
	end

	-- Black flames rolling up off him, licks of dark red at the edges.
	emitter(torso, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, BLACK),
			ColorSequenceKeypoint.new(0.7, BLACK),
			ColorSequenceKeypoint.new(1, DARK_RED),
		}),
		LightEmission = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 3.4) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(0.25, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.6, 1),
		Rate = 40,
		Speed = NumberRange.new(2, 4),
		Acceleration = Vector3.new(0, 8, 0),
		SpreadAngle = Vector2.new(70, 70),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	})
	emitter(torso, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(BLACK),
		LightEmission = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) }),
		Squash = NumberSequence.new(-0.6),
		Transparency = NumberSequence.new(0.15, 1),
		Lifetime = NumberRange.new(0.35, 0.6),
		Rate = 30,
		Speed = NumberRange.new(4, 8),
		Acceleration = Vector3.new(0, 16, 0),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
	})
	emitter(torso, {
		Texture = U.textures.Spark,
		Color = ColorSequence.new(RED),
		LightEmission = 1,
		Size = NumberSequence.new(0.25, 0),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 16,
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 5, 0),
	})

	-- Anti-magic swallowing the right arm.
	local arm = character:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		local original = arm.Color
		arm.Color = BLACK
		emitter(arm, {
			Texture = U.textures.Smoke,
			Color = ColorSequence.new(BLACK),
			LightEmission = 0,
			Size = NumberSequence.new(0.7, 1.4),
			Transparency = NumberSequence.new(0.3, 1),
			Lifetime = NumberRange.new(0.3, 0.5),
			Rate = 18,
			Speed = NumberRange.new(0.5, 2),
			Acceleration = Vector3.new(0, 6, 0),
			SpreadAngle = Vector2.new(180, 180),
		})
		table.insert(cleanup, function()
			if arm.Parent then
				arm.Color = original
			end
		end)
	end

	-- The sword smoulders too.
	local sword = getSword(character)
	local blade = bladeOf(character)
	if sword and blade then
		emitter(blade, {
			Texture = U.textures.Smoke,
			Color = ColorSequence.new(BLACK),
			LightEmission = 0,
			Size = NumberSequence.new(0.5, 1.1),
			Transparency = NumberSequence.new(0.35, 1),
			Lifetime = NumberRange.new(0.25, 0.45),
			Rate = 14,
			Speed = NumberRange.new(0.5, 2),
			Acceleration = Vector3.new(0, 5, 0),
			SpreadAngle = Vector2.new(180, 180),
		})
		emitter(blade, {
			Texture = U.textures.Spark,
			Color = ColorSequence.new(RED),
			LightEmission = 1,
			Size = NumberSequence.new(0.18, 0),
			Lifetime = NumberRange.new(0.2, 0.4),
			Rate = 5,
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180),
		})
		local swordLook = Instance.new("Highlight")
		swordLook.Adornee = sword
		swordLook.FillColor = BLACK
		swordLook.FillTransparency = 0.6
		swordLook.OutlineColor = DARK_RED
		swordLook.OutlineTransparency = 0.25
		swordLook.DepthMode = Enum.HighlightDepthMode.Occluded
		swordLook.Parent = U.folder
		table.insert(cleanup, function()
			swordLook:Destroy()
		end)
	end

	local outline = Instance.new("Highlight")
	outline.Adornee = character
	outline.FillColor = BLACK
	outline.FillTransparency = 0.82
	outline.OutlineColor = DARK_RED
	outline.OutlineTransparency = 0.2
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = character
	table.insert(cleanup, function()
		outline:Destroy()
	end)

	-----------------------------------------------------------------------
	-- Wing, horn and ground aura: anchored parts posed every frame.
	-----------------------------------------------------------------------
	local parts: { BasePart } = {}
	local function piece(props: { [string]: any }): BasePart
		local part = U.newPart(props)
		table.insert(parts, part)
		return part
	end
	local matte = Enum.Material.SmoothPlastic
	local upperBone = piece({ Size = Vector3.new(UPPER_BONE, 0.32, 0.32), Color = BLACK, Material = matte })
	local forearm = piece({ Size = Vector3.new(FOREARM, 0.24, 0.24), Color = BLACK, Material = matte })
	local upperEdge = piece({ Size = Vector3.new(UPPER_BONE, 0.07, 0.07), Color = DARK_RED, Transparency = 0.2 })
	local forearmEdge = piece({ Size = Vector3.new(FOREARM, 0.06, 0.06), Color = DARK_RED, Transparency = 0.2 })
	local wrist = piece({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.42, Color = BLACK, Material = matte })
	local claw = piece({ Size = Vector3.new(0.14, 0.7, 0.14), Color = BLACK, Material = matte })
	local feathers: { { plate: BasePart, tip: BasePart } } = {}
	for _, feather in FEATHERS do
		table.insert(feathers, {
			plate = piece({ Size = Vector3.new(feather.width, feather.length, 0.07), Color = BLACK, Material = matte }),
			tip = piece({
				Size = Vector3.new(feather.width * 0.7, feather.width * 0.7, 0.065),
				Color = BLACK,
				Material = matte,
			}),
		})
	end
	local hornParts: { BasePart } = {}
	for _, segment in HORN do
		table.insert(hornParts, piece({ Size = segment.size, Color = BLACK, Material = matte }))
	end
	local disc = piece({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, 7, 7),
		Color = BLACK,
		Material = matte,
		Transparency = 0.55,
	})
	local discRim = piece({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 7.6, 7.6),
		Color = DARK_RED,
		Transparency = 0.65,
	})

	-- Hidden until the first frame poses them (they're built at the origin).
	for _, part in parts do
		part.Transparency = 1
	end

	-- Smoke streaming off the wingtip, embers off the forearm.
	local tipFeather = feathers[#feathers - 1].tip
	emitter(tipFeather, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(BLACK),
		LightEmission = 0,
		Size = NumberSequence.new(0.6, 1.6),
		Transparency = NumberSequence.new(0.35, 1),
		Lifetime = NumberRange.new(0.4, 0.7),
		Rate = 16,
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = Vector3.new(0, 4, 0),
		SpreadAngle = Vector2.new(180, 180),
	})
	emitter(forearm, {
		Texture = U.textures.Spark,
		Color = ColorSequence.new(RED),
		LightEmission = 1,
		Size = NumberSequence.new(0.2, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Rate = 6,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 3, 0),
	})

	local current: WingParams = table.clone(WING_STATES.folded)
	local phase = 0
	local state = "stand"
	local born = os.clock()
	local flapStart = -10
	local nextStretch = os.clock() + 4 + math.random() * 4
	local nextCrackle = os.clock() + 0.5
	local nextPulse = os.clock() + 1
	local groundY: number? = nil
	local nextGroundCheck = 0
	local fading: number? = nil
	local FADE = 0.4

	-- A big beat: the Stance in the awakening, and now and then when idle.
	visual.flap = function()
		flapStart = os.clock()
	end

	local shoulder = CFrame.new(-0.6, 0.55, 0.55) -- upper back, left side
	local hornBase = CFrame.new(0.42, 0.42, -0.1) * rot(0, 0, -34)
	local face = CFrame.Angles(0, 0, rad(90)) -- cylinder X axis up

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if not torso.Parent or not head.Parent or not root.Parent then
			connection:Disconnect()
			for _, part in parts do
				part:Destroy()
			end
			return
		end

		-- What is he doing? Ground check a few times a second.
		if now >= nextGroundCheck then
			nextGroundCheck = now + 0.1
			local ground = U.groundBelow(root.Position, { character })
			groundY = if ground and root.Position.Y - ground.Position.Y < 4.4 then ground.Position.Y else nil
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local newState = if groundY == nil then "air" elseif speed > 4 then "run" else "stand"
		if newState == "air" and state ~= "air" then
			phase = 0.25 -- start the first beat from the top
		end
		state = newState

		-- Ease toward the state's pose; unfurl from folded when it appears.
		local unfurl = math.clamp((now - born) / 0.55, 0, 1)
		local reveal = TweenService:GetValue(unfurl, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local target = lerpParams(WING_STATES.folded, WING_STATES[state], reveal)
		local ease = 1 - math.exp(-dt * (if unfurl < 1 then 30 else 7))
		current = lerpParams(current, target, ease)
		phase = (phase + dt * current.rate) % 1

		-- Idle stretch every so often.
		if state == "stand" and now >= nextStretch then
			nextStretch = now + 7 + math.random() * 5
			flapStart = now
		end
		local flapAge = now - flapStart
		local flap = if flapAge < 0.9 then math.sin(math.pi * flapAge / 0.9) else 0
		local flapLag = if flapAge > 0.12 and flapAge < 1.02 then math.sin(math.pi * (flapAge - 0.12) / 0.9) else 0

		local wave = math.sin(phase * math.pi * 2)
		local waveLag = math.sin(phase * math.pi * 2 - 0.9)
		local lift = current.lift + 28 * current.beat * wave + 34 * flap
		local bend = current.bend + 22 * current.beat * waveLag + 26 * flapLag
		local back = current.back - 10 * flap
		local fan = current.fan + 0.3 * flap

		-- Bones.
		local shoulderFrame = torso.CFrame * shoulder * CFrame.Angles(0, rad(back), 0) * CFrame.Angles(0, 0, rad(-lift))
		local wristFrame = shoulderFrame
			* CFrame.new(-UPPER_BONE, 0, 0)
			* CFrame.Angles(0, rad(10 + current.back * 0.2), 0)
			* CFrame.Angles(0, 0, rad(-bend))
		upperBone.CFrame = shoulderFrame * CFrame.new(-UPPER_BONE / 2, 0, 0)
		upperEdge.CFrame = shoulderFrame * CFrame.new(-UPPER_BONE / 2, 0.17, -0.05)
		forearm.CFrame = wristFrame * CFrame.new(-FOREARM / 2, 0, 0)
		forearmEdge.CFrame = wristFrame * CFrame.new(-FOREARM / 2, 0.13, -0.05)
		wrist.CFrame = wristFrame
		claw.CFrame = wristFrame * CFrame.Angles(0, 0, rad(40)) * CFrame.new(0, 0.4, 0)

		-- Feathers: fanned out, rippling from the root to the tip.
		local t = now - born
		for i, feather in FEATHERS do
			local frame = if feather.bone == 1 then shoulderFrame else wristFrame
			local length = if feather.bone == 1 then UPPER_BONE else FOREARM
			local ripple = math.sin(t * 2.6 - i * 0.45) * 4 * current.sway
				+ math.sin(t * 13 - i * 0.7) * 3 * (if state == "run" then 1 else 0)
			local twist = math.sin(t * 1.9 - i * 0.5) * 7 * current.sway - 9 * current.beat * waveLag
			local joint = frame
				* CFrame.new(-length * feather.at, 0, 0.03 * i)
				* CFrame.Angles(rad(twist), 0, 0)
				* CFrame.Angles(0, 0, rad(-(feather.angle * fan + ripple)))
			local pair = feathers[i]
			pair.plate.CFrame = joint * CFrame.new(0, -feather.length / 2, 0)
			pair.tip.CFrame = joint * CFrame.new(0, -feather.length, 0) * CFrame.Angles(0, 0, rad(45))
		end

		-- Horn.
		local hornFrame = head.CFrame * hornBase
		for i, segment in HORN do
			local height = segment.size.Y
			hornParts[i].CFrame = hornFrame * CFrame.new(0, height / 2, 0)
			hornFrame = hornFrame * CFrame.new(0, height * 0.9, 0) * segment.bend
		end

		-- Dark pool under his feet (only when standing on something).
		if groundY then
			local pulse = 1 + 0.06 * math.sin(t * 2)
			local spot = Vector3.new(root.Position.X, groundY + 0.06, root.Position.Z)
			disc.CFrame = CFrame.new(spot) * face
			disc.Size = Vector3.new(0.06, 7 * pulse, 7 * pulse)
			discRim.CFrame = CFrame.new(spot - Vector3.new(0, 0.01, 0)) * face
			discRim.Size = Vector3.new(0.05, 7.7 * pulse, 7.7 * pulse)
		end
		local poolShown = groundY ~= nil and not fading
		disc.Transparency = if poolShown then 0.55 else 1
		discRim.Transparency = if poolShown then 0.65 else 1

		-- Little things: crackles off his body, pressure rings on the ground.
		if not fading and now >= nextCrackle then
			nextCrackle = now + 0.45 + math.random() * 0.7
			local from = torso.Position + U.randomUnit() * 1.2
			U.lightning(from, from + U.randomUnit() * 3.2, BLACK, RED, 0.08, 0.14, false)
		end
		if not fading and groundY and now >= nextPulse then
			nextPulse = now + 1.6
			U.ringBurst(CFrame.new(root.Position.X, groundY + 0.1, root.Position.Z), DARK_RED, 2, 6, 0.6, 0.08)
		end

		-- Grow in when it appears, dissolve when Black Form ends.
		local visible = math.clamp((now - born) / 0.3, 0, 1)
		if fading then
			visible = 1 - (now - fading) / FADE
			if visible <= 0 then
				connection:Disconnect()
				for _, part in parts do
					part:Destroy()
				end
				return
			end
		end
		if visible < 1 or fading or now - born < 0.35 then
			for _, part in parts do
				if part ~= disc and part ~= discRim then
					local base = if part == upperEdge or part == forearmEdge then 0.2 else 0
					part.Transparency = base + (1 - base) * (1 - visible)
				end
			end
		end
	end)
	table.insert(cleanup, function()
		fading = os.clock()
		if torso.Parent then
			U.burst(torso.Position + torso.CFrame.LookVector * -1, {
				color = BLACK,
				count = 14,
				size = 0.5,
				speed = NumberRange.new(4, 10),
				lifetime = NumberRange.new(0.8, 1.4),
				lightEmission = 0,
				acceleration = Vector3.new(0, -6, 0),
				drag = 1,
			})
		end
	end)
end

---------------------------------------------------------------------------
-- Awakening: the transformation into Black Form
---------------------------------------------------------------------------

local AWAKEN_BURST = 0.92 -- the roar in the Awaken animation; the server bursts here too

-- When the Black Form look should pop in (at the burst, not before).
local revealAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function refreshAwakened(character: Model)
	local on = character:GetAttribute("Awakened") == true
	if on and awakenedVisuals[character] then
		return
	end
	setAwakened(character, on)
end

-- What the burst consumes from the gathering: the pool and floating rocks.
local gathering: { [Model]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any

local function awakenGather(character: Model, root: BasePart)
	local feet = feetOf(character, root)
	local mine = U.isLocal(character)
	local made: { BasePart } = {}
	gathering[character] = made

	-- Darkness pooling out under him, a red rim at its edge.
	local face = CFrame.Angles(0, 0, rad(90))
	local pool = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, 1, 1),
		CFrame = CFrame.new(feet + UP * 0.06) * face,
		Color = BLACK,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
	})
	local rim = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, 1.4, 1.4),
		CFrame = CFrame.new(feet + UP * 0.05) * face,
		Color = DARK_RED,
		Transparency = 0.45,
	})
	U.tween(pool, 0.9, { Size = Vector3.new(0.08, 22, 22) }, Enum.EasingStyle.Quart)
	U.tween(rim, 0.9, { Size = Vector3.new(0.06, 23.2, 23.2) }, Enum.EasingStyle.Quart)
	table.insert(made, pool)
	table.insert(made, rim)

	-- Rocks tearing loose and floating up around him.
	local ground = U.groundBelow(feet + UP)
	local rockColor = if ground and ground.Instance:IsA("BasePart")
		then ground.Instance.Color
		else Color3.fromRGB(90, 88, 85)
	local rockMaterial = if ground then ground.Material else Enum.Material.Slate
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2 + math.random() * 0.5
		local distance = 3.5 + math.random() * 5
		local size = 0.5 + math.random() * 0.9
		local start = feet + Vector3.new(math.cos(angle) * distance, -size, math.sin(angle) * distance)
		local rock = U.newPart({
			Size = Vector3.one * size,
			CFrame = CFrame.new(start) * U.randomAngles(),
			Color = rockColor,
			Material = rockMaterial,
		})
		rock.CastShadow = true
		local lift = 1.5 + math.random() * 4
		U.tween(rock, 0.9, {
			CFrame = CFrame.new(start + UP * lift) * U.randomAngles(),
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		table.insert(made, rock)
	end

	-- Anti-magic spiralling in and crawling up his body.
	U.spiral(root, BLACK, 6.5, 2.5, 0.9, 4, 0.7, 0.85)
	U.spiral(root, RED, 5.5, 2.5, 0.9, 2, 0.2, 0.85)
	task.delay(0.35, U.groundCracks, feet, 6, 5, RED, 2.5)
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < AWAKEN_BURST - 0.02 and root.Parent do
			local angle = math.random() * math.pi * 2
			local from = feet + Vector3.new(math.cos(angle), 0.2, math.sin(angle)) * (1 + math.random() * 2.5)
			U.lightning(from, root.Position + U.randomUnit() * Vector3.new(1, 2, 1), BLACK, RED, 0.1, 0.12)
			if math.random() < 0.5 then
				inflow(root.Position + UP * 0.5, 6)
			end
			if math.random() < 0.3 then
				blackSmoke(feet + U.randomUnit() * Vector3.new(4, 0, 4) + UP * 0.3, 2, 2.5, 3)
			end
			if mine then
				CameraShake.Add(0.035)
			end
			task.wait(0.06)
		end
	end)

	-- For whoever is transforming: the world dims and the view closes in.
	if mine then
		U.colorGrade({
			Brightness = -0.12,
			Contrast = 0.3,
			Saturation = -0.65,
			TintColor = Color3.fromRGB(255, 225, 225),
		}, 0.85, 0.05, 0.6)
		local camera = workspace.CurrentCamera
		TweenService
			:Create(
				camera,
				TweenInfo.new(0.88, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ FieldOfView = 56 }
			)
			:Play()
		-- The burst kicks it back out; if the burst never comes, restore it.
		task.delay(AWAKEN_BURST + 0.6, function()
			if camera.FieldOfView < 69 then
				TweenService:Create(camera, TweenInfo.new(0.3), { FieldOfView = 70 }):Play()
			end
		end)
	end
end

local function awakenBurst(character: Model, root: BasePart)
	local feet = feetOf(character, root)
	local center = root.Position

	-- The gathering gets blown away.
	local consumed = gathering[character]
	if consumed then
		for _, part in consumed do
			if part.Parent then
				if part.Shape == Enum.PartType.Cylinder then
					U.tween(part, 0.3, { Size = part.Size * Vector3.new(1, 1.6, 1.6), Transparency = 1 })
				else
					local out = part.Position - center
					out = Vector3.new(out.X, 0, out.Z).Unit
					U.tween(part, 0.4, {
						CFrame = CFrame.new(part.Position + out * 16 + UP * 5) * U.randomAngles(),
						Transparency = 1,
					}, Enum.EasingStyle.Quad)
				end
				task.delay(0.45, part.Destroy, part)
			end
		end
	end
	gathering[character] = nil

	-- The blast.
	U.flash(center, WHITE, 5, 0.08)
	U.flash(center, BLACK, 24, 0.45)
	U.flash(center, RED, 14, 0.3)
	U.shockwave(feet, BLACK, 4, 52, 0.7, Enum.Material.Glass, 0.3)
	U.shockwave(center, RED, 3, 40, 0.55)
	task.delay(0.08, U.shockwave, center, DARK_RED, 2, 28, 0.5)
	U.ringBurst(CFrame.new(feet + UP * 0.2), BLACK, 2, 34, 0.6, 0.9)
	task.delay(0.04, U.ringBurst, CFrame.new(feet + UP * 0.3), RED, 2, 26, 0.5, 0.45)
	task.delay(0.08, U.ringBurst, CFrame.new(feet + UP * 0.4), WHITE, 1, 18, 0.3, 0.15)
	U.impactRing(center, root.CFrame.LookVector, BLACK, 2, 18, 0.5)
	U.impactRing(center, root.CFrame.RightVector, RED, 2, 14, 0.45)

	-- A black pillar punching up into the sky.
	U.pillar(feet, BLACK, 4.5, 80, 1.1, Enum.Material.SmoothPlastic, 0.1)
	U.pillar(feet, RED, 2.4, 90, 0.9)
	task.delay(0.05, U.pillar, feet, WHITE, 1, 95, 0.4)

	-- The ground splits and erupts.
	U.groundCracks(feet, 16, 18, RED, 4)
	U.groundRocks(feet, 18, 8, 3)
	task.delay(0.06, U.groundRocks, feet, 10, 4, 2.2)
	U.debris(feet, 26, 65, 1.6)
	blackSmoke(center, 40, 7, 40)
	U.burst(feet, {
		texture = U.textures.Smoke,
		color = Color3.fromRGB(150, 140, 130),
		count = 24,
		size = 8,
		speed = NumberRange.new(30, 55),
		lifetime = NumberRange.new(0.9, 1.6),
		lightEmission = 0,
		transparency = 0.35,
		drag = 2.5,
		spread = 85,
	})
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2 + math.random() * 0.3
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		U.lightning(feet + UP * 0.5, feet + out * (10 + math.random() * 10) + UP * 0.3, BLACK, RED, 0.24, 0.35)
	end
	for _ = 1, 5 do
		U.lightning(center, center + UP * (10 + math.random() * 8) + U.randomUnit() * 4, BLACK, RED, 0.22, 0.3)
	end
	redSparks(center, 40, 1.6)
	U.light(center, RED, 18, 60, 0.9)
	U.highlight(character, BLACK, 0.6)
	U.popup(center + UP * 6, "BLACK FORM", RED, 2.4)
	lingerSmoke(feet, 2, 10)

	-- He keeps erupting while he roars.
	trailEmitter(root, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(BLACK),
		LightEmission = 0,
		Size = NumberSequence.new(2, 5),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 120,
		Speed = NumberRange.new(8, 18),
		Acceleration = Vector3.new(0, 10, 0),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Drag = 2,
	}, 0.6)
	crackle(root, 0.6, 0.05, 4)

	if U.isLocal(character) then
		impactFrame(1.3)
		U.screenFlash(RED, 0.4)
		task.delay(0.1, U.colorGrade, {
			TintColor = Color3.fromRGB(255, 175, 175),
			Saturation = -0.3,
			Contrast = 0.2,
		}, 0, 0.3, 0.6)
		CameraShake.FovKick(18)
	end
end

-- The sword comes down into his Black Form stance and the wing beats once.
local function awakenStance(character: Model, root: BasePart)
	heavyTrail(character, 0.3)
	crescent(character, {
		center = CFrame.new(0, 0.5, 0),
		radius = 6,
		from = 55,
		to = -10,
		tilt = 45,
		width = 2.4,
		sweep = 0.1,
		fade = 0.35,
	})
	local feet = feetOf(character, root)
	U.ringBurst(CFrame.new(feet + UP * 0.15), BLACK, 1, 9, 0.35, 0.3)
	blackSmoke(feet + UP * 0.4, 10, 3, 12)
	local visual = awakenedVisuals[character]
	if visual and visual.flap then
		visual.flap()
	end
	local torso = character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		-- Loose feathers shaken off by the beat.
		U.burst(torso.Position - torso.CFrame.RightVector * 2 - torso.CFrame.LookVector, {
			color = BLACK,
			count = 16,
			size = 0.6,
			speed = NumberRange.new(8, 18),
			lifetime = NumberRange.new(0.8, 1.4),
			lightEmission = 0,
			acceleration = Vector3.new(0, -8, 0),
			drag = 1.5,
		})
	end
	if U.isLocal(character) then
		CameraShake.Add(0.2)
	end
end

function handlers.Awaken(data, character, root)
	local phase = data.phase
	if phase == "Start" then
		-- The look pops in at the burst, not before.
		revealAt[character] = os.clock() + AWAKEN_BURST
		if awakenedVisuals[character] then
			setAwakened(character, false)
		end
		task.delay(AWAKEN_BURST, refreshAwakened, character)
		play(character, ANIMS.Awaken, function(event)
			if event == "Stance" and character.Parent then
				awakenStance(character, root)
			end
		end)
		awakenGather(character, root)
	elseif phase == "Burst" then
		awakenBurst(character, root)
	elseif phase == "End" then
		blackSmoke(root.Position, 16, 3.5, 10)
		U.afterimage(character, BLACK, 0.5)
		U.ringBurst(CFrame.new(feetOf(character, root) + UP * 0.1), DARK_RED, 1, 6, 0.4, 0.15)
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

-- Sword clashes: whenever Asta's sword is blocked, or he blocks with it,
-- molten orange sparks fly off the contact point.
local function clashDirection(data): Vector3
	local victimRoot = U.getRoot(data.victim)
	local attackerRoot = U.getRoot(data.attacker)
	if victimRoot and attackerRoot then
		local toward = attackerRoot.Position - victimRoot.Position
		return (Vector3.new(toward.X, 0, toward.Z).Unit + UP * 0.7).Unit
	end
	return UP
end

VFX.RegisterKitEffect("AntiMagic", "Block", function(data)
	local position: Vector3 = data.position
	U.sparks(position, clashDirection(data), 1)
	U.highlight(data.victim, Color3.fromRGB(255, 170, 80), 0.1)
	if U.isLocal(data.attacker) or U.isLocal(data.victim) then
		CameraShake.Add(0.12)
	end
end)

VFX.RegisterKitEffect("AntiMagic", "GuardBreak", function(data)
	local position: Vector3 = data.position
	local direction = clashDirection(data)
	U.sparks(position, direction, 1.8)
	task.delay(0.05, U.sparks, position, (direction + U.randomUnit() * 0.4).Unit, 1.2)
	U.shards(position, Color3.fromRGB(255, 160, 60), 12)
	U.flash(position, Color3.fromRGB(255, 190, 110), 6, 0.2)
	U.light(position, Color3.fromRGB(255, 140, 50), 10, 18, 0.35)
	U.highlight(data.victim, Color3.fromRGB(255, 140, 50), 0.35)
	U.popup(position + UP * 2, "GUARD BREAK", Color3.fromRGB(255, 170, 60), 1.5)
	if U.isLocal(data.attacker) or U.isLocal(data.victim) then
		CameraShake.Add(0.4)
	end
end)

VFX.RegisterKitEffect("AntiMagic", "PerfectBlock", function(data)
	VFX.PlayDefault("PerfectBlock", data)
	U.sparks(data.position, clashDirection(data), 1.4)
end)

function Kit.SetAwakened(character: Model, on: boolean)
	-- During the transformation the look waits for the burst.
	if on and (revealAt[character] or 0) > os.clock() then
		return
	end
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
