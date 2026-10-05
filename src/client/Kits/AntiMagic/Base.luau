-- Asta's base moves: Bull Thrust, Black Meteorite, Black Divider, Anti-Magic Deflect and the R special.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MeteorVortex = require(ReplicatedStorage:WaitForChild("Shared").MeteorVortex)

local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local VFX = require(script.Parent.Parent.Parent.VFX)

local U = VFX.Util

local rad = math.rad

local Fx = require(script.Parent.Fx)
local BLACK, RED, DARK_RED, WHITE, HOT, WHITE_HOT = Fx.BLACK, Fx.RED, Fx.DARK_RED, Fx.WHITE, Fx.HOT, Fx.WHITE_HOT
local UP, ANIMS, handlers, play, bump, live = Fx.UP, Fx.ANIMS, Fx.handlers, Fx.play, Fx.bump, Fx.live
local involves, feetOf, bladeOf, bladePoint = Fx.involves, Fx.feetOf, Fx.bladeOf, Fx.bladePoint
local swordTrail, swordGlow, swordAura, heavyTrail = Fx.swordTrail, Fx.swordGlow, Fx.swordAura, Fx.heavyTrail
local edgeGlow, blackSmoke, redSparks, blackLightning = Fx.edgeGlow, Fx.blackSmoke, Fx.redSparks, Fx.blackLightning
local crackle, crescent, inflow, slashWave, slashMark = Fx.crackle, Fx.crescent, Fx.inflow, Fx.slashWave, Fx.slashMark
local markAngle, impactFrame, lingerSmoke, partEmitter = Fx.markAngle, Fx.impactFrame, Fx.lingerSmoke, Fx.partEmitter
local trailEmitter, glowBurst, bloomPulse, meteorTail = Fx.trailEmitter, Fx.glowBurst, Fx.bloomPulse, Fx.meteorTail
type CrescentOptions = Fx.CrescentOptions

-- Bull Thrust: propel, catch, then a five-hit sword combo (in the air, a
-- dive that slams the ground if it catches no one)

local COMBO_SWINGS: { [string]: CrescentOptions } = {
	-- From low behind him on the right, up through them to high on his left.
	Rising = {
		center = CFrame.new(1, 0.5, 0) * CFrame.Angles(rad(5), 0, 0),
		radius = 5.2,
		from = 130,
		to = -80,
		tilt = -41,
		width = 1.7,
		sweep = 0.06,
		fade = 0.24,
	},
	-- Back across the waist, left to right.
	Sweep = {
		center = CFrame.new(1, 0.5, 0) * CFrame.Angles(rad(-5), 0, 0),
		radius = 5,
		from = -100,
		to = 122,
		tilt = -2,
		width = 1.7,
		sweep = 0.06,
		fade = 0.24,
	},
	-- The turn: round behind him, then on through them, dipping in front.
	Spin = {
		center = CFrame.new(0, 0.5, 0) * CFrame.Angles(rad(-12), 0, 0),
		radius = 5.9,
		from = 160,
		to = 425,
		tilt = 3,
		width = 2.1,
		sweep = 0.16,
		fade = 0.3,
	},
	-- Up over his head and straight down through them.
	Chop = {
		center = CFrame.new(0.4, 0.8, 0) * CFrame.Angles(0, rad(5), 0),
		radius = 5,
		from = 135,
		to = -28,
		tilt = 90,
		width = 2.3,
		sweep = 0.06,
		fade = 0.3,
	},
}

local COMBO_CUTS: { [string]: { cut: Vector3, size: number } } = {
	Rising = { cut = Vector3.new(-0.75, 0.65, 0), size = 1 },
	Sweep = { cut = Vector3.new(1, 0, 0), size = 1 },
	Spin = { cut = Vector3.new(1, 0.05, 0), size = 1.25 },
	Chop = { cut = Vector3.new(0, -1, 0.25), size = 1.5 },
}

-- Flat direction from him to them (his facing if they're on top of him).
local function towardTarget(root: BasePart, targetRoot: BasePart): Vector3
	local offset = targetRoot.Position - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	return if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
end

-- One beat of the combo animation: a swing starting, the coil, the thrust.
local function comboSwing(character: Model, root: BasePart, event: string)
	local swing = COMBO_SWINGS[event]
	if swing then
		heavyTrail(character, (swing.sweep or 0.06) + 0.06)
		swing.glow = swing.glow or 0.7 -- the cuts glow
		crescent(character, swing)
		edgeGlow(character, (swing.sweep or 0.06) + 0.1, 0.8)
		-- His footwork scuffs up a little anti-magic.
		blackSmoke(feetOf(character, root) + UP * 0.3, 3, 1.6, 5)
		if event == "Spin" then
			-- The turn throws a ring of wind off him.
			U.ringBurst(CFrame.new(root.Position + UP * 0.2), BLACK, 1.5, 7, 0.28, 0.22)
			task.delay(0.06, U.ringBurst, CFrame.new(root.Position + UP * 0.3), DARK_RED, 1.2, 5.5, 0.24, 0.14)
			task.delay(0.08, function()
				if character.Parent then
					U.afterimage(character, DARK_RED, 0.18)
				end
			end)
		elseif event == "Chop" then
			-- The blade catches the light at the top of the swing.
			local tip = bladePoint(character, 2.1)
			if tip then
				U.glint(tip, 1.2, RED)
			end
		end
	elseif event == "Coil" then
		-- Drawn back for the thrust: anti-magic floods the blade and the air
		-- pulls in around him.
		swordGlow(character, RED, 0.18, 0.35)
		swordAura(character, 0.16, 40)
		U.ringBurst(CFrame.new(feetOf(character, root) + UP * 0.1), BLACK, 5, 1.2, 0.16, 0.2)
		local blade = bladeOf(character)
		if blade then
			for _ = 1, 5 do
				inflow(blade.Position, 3.5)
			end
			crackle(blade, 0.14, 0.04, 2)
		end
		task.delay(0.06, function()
			local tip = bladePoint(character, 2.1)
			if tip and character.Parent then
				U.glint(tip, 1.6, RED)
				task.delay(0.03, U.glint, tip, 1, WHITE)
			end
		end)
		if U.isLocal(character) then
			CameraShake.FovKick(-4)
		end
	elseif event == "Thrust" then
		heavyTrail(character, 0.14)
		U.afterimage(character, BLACK, 0.2)
		local feet = feetOf(character, root)
		blackSmoke(feet + UP * 0.3, 6, 2.2, 10)
		U.ringBurst(CFrame.new(feet + UP * 0.1), BLACK, 0.8, 5, 0.25, 0.2)
	end
end

local function comboImpact(data, character: Model, root: BasePart)
	local target = data.target
	local targetRoot = U.getRoot(target)
	local how = COMBO_CUTS[data.kind] or COMBO_CUTS.Sweep
	if not targetRoot then
		return
	end
	local k = how.size
	local center = targetRoot.Position + UP * 0.4
	local cut = root.CFrame:VectorToWorldSpace(how.cut).Unit
	local toward = towardTarget(root, targetRoot)
	slashMark(center, markAngle(center, cut), 4 + 1.6 * k, 0.2 + 0.05 * k)
	U.impactSpikes(center, RED, math.floor(6 + 2 * k), 4 + 2 * k, 0.2, WHITE_HOT)
	U.flash(center, WHITE, 1.6 * k, 0.07)
	U.flash(center, BLACK, 3 * k, 0.16)
	glowBurst(center, 2.2 * k, 0.22)
	redSparks(center, math.floor(8 * k), 0.45 + 0.15 * k, cut)
	U.impactRing(center, toward, RED, 0.4 * k, 3.2 * k, 0.2)
	task.delay(0.03, U.impactRing, center, toward, BLACK, 0.3 * k, 2.6 * k, 0.2)
	blackLightning(center, if k > 1 then 3 else 2, 2 + k, 0.15)
	U.light(center, RED, 4 * k, 8 + 4 * k, 0.15)
	if data.kind == "Chop" then
		-- Driven down through them into the ground at their feet.
		local feet = feetOf(target, targetRoot)
		U.groundCracks(feet, 5, 4, RED, 1.2)
		U.groundRocks(feet, 6, 2.2, 1)
		U.ringBurst(CFrame.new(feet + UP * 0.1), BLACK, 0.8, 6, 0.3, 0.25)
		blackSmoke(feet + UP * 0.3, 6, 2.4, 10)
	elseif data.kind == "Spin" then
		-- The turn's wind rings out around them.
		U.ringBurst(CFrame.new(center), WHITE, 0.6, 4.5, 0.2, 0.08)
	end
	if involves(data, character) then
		CameraShake.Add(0.05 + 0.05 * k)
	end
end

local function pierce(from: Vector3, direction: Vector3, length: number)
	local frame = CFrame.lookAt(from, from + direction)
	local out = frame * CFrame.new(0, 0, -length / 2)
	local glow = U.newPart({ Size = Vector3.new(0.5, 0.5, 0.4), CFrame = frame, Color = RED, Transparency = 0.15 })
	local core = U.newPart({
		Size = Vector3.new(0.22, 0.22, 0.4),
		CFrame = frame,
		Color = BLACK,
		Material = Enum.Material.SmoothPlastic,
	})
	U.tween(glow, 0.08, { Size = Vector3.new(0.45, 0.45, length), CFrame = out })
	U.tween(core, 0.08, { Size = Vector3.new(0.2, 0.2, length * 0.95), CFrame = out })
	task.delay(0.08, function()
		U.tween(glow, 0.24, { Size = Vector3.new(0.02, 0.02, length * 1.1), Transparency = 1 })
		U.tween(core, 0.24, { Size = Vector3.new(0.01, 0.01, length), Transparency = 1 })
	end)
	task.delay(0.35, function()
		glow:Destroy()
		core:Destroy()
	end)
end

-- The finisher: the thrust goes clean through them and blows them back.
local function comboFinisher(data, character: Model, root: BasePart)
	local target = data.target
	local targetRoot = U.getRoot(target)
	if not targetRoot then
		return
	end
	local toward = towardTarget(root, targetRoot)
	local center = targetRoot.Position + UP * 0.2
	pierce(center - toward * 1.2, toward, 8)
	U.impactSpikes(center, RED, 14, 10, 0.3, WHITE_HOT)
	U.flash(center, WHITE, 5, 0.1)
	U.flash(center, BLACK, 9, 0.24)
	U.flash(center, RED, 6, 0.18)
	glowBurst(center, 6, 0.35)
	task.delay(0.05, glowBurst, center + toward * 4, 3.5, 0.3)
	edgeGlow(character, 0.35, 1.2)
	bloomPulse(center, 0.9, 0.25)
	U.shockwave(center, RED, 1.5, 9, 0.3)
	U.impactRing(center, toward, WHITE, 0.8, 7, 0.25)
	task.delay(0.04, U.impactRing, center + toward * 1.5, toward, RED, 0.6, 6, 0.28)
	task.delay(0.08, U.impactRing, center + toward * 3, toward, BLACK, 0.5, 8, 0.32)
	blackSmoke(center + toward * 1.5, 16, 3.2, 22)
	U.burst(center, {
		color = RED,
		count = 24,
		size = 0.7,
		speed = NumberRange.new(35, 60),
		lifetime = NumberRange.new(0.15, 0.35),
		streaks = true,
		spread = 25,
		direction = toward,
	})
	blackLightning(center, 6, 5.5, 0.25)
	U.light(center, RED, 12, 22, 0.35)
	U.highlight(target, RED, 0.25)
	U.bodyTrail(target, DARK_RED, 0.35)
	-- They skid back across the ground, tearing a groove in it.
	local feet = feetOf(target, targetRoot)
	U.ringBurst(CFrame.new(feet + UP * 0.1), BLACK, 1, 8, 0.3, 0.3)
	U.groove(feet, feet + toward * 9, 0.8, RED, 1.8, 40)
	U.dustWave(feet, 8)
	U.burst(feet, {
		texture = U.textures.Smoke,
		color = Color3.fromRGB(150, 140, 130),
		count = 8,
		size = 3,
		speed = NumberRange.new(8, 16),
		lifetime = NumberRange.new(0.4, 0.8),
		lightEmission = 0,
		transparency = 0.45,
		drag = 3,
		spread = 50,
		direction = (toward + UP).Unit,
	})
	if involves(data, character) then
		impactFrame()
		CameraShake.Add(0.3)
		CameraShake.FovKick(8)
	end
end

local function bullSlam(data, character: Model)
	local position: Vector3 = data.position
	local center = position + UP
	U.flash(center, WHITE, 6, 0.08)
	U.flash(center, BLACK, 15, 0.32)
	U.flash(center, RED, 10, 0.24)
	U.impactSpikes(center + UP, RED, 16, 14, 0.32, WHITE_HOT)
	U.scorch(position, 7, RED, 3)
	U.dustWave(position, 16)
	glowBurst(center, 9, 0.45)
	bloomPulse(center, 1, 0.3)
	U.shockwave(position, BLACK, 4, 26, 0.45, Enum.Material.Glass, 0.4)
	U.shockwave(position, RED, 3, 22, 0.4)
	task.delay(0.1, U.shockwave, position, BLACK, 2, 32, 0.55, Enum.Material.Glass, 0.55)
	U.ringBurst(CFrame.new(position + UP * 0.2), BLACK, 1.5, 18, 0.45, 0.6)
	task.delay(0.05, U.ringBurst, CFrame.new(position + UP * 0.3), RED, 1, 13, 0.38, 0.3)
	task.delay(0.1, U.ringBurst, CFrame.new(position + UP * 0.4), WHITE, 0.5, 9, 0.25, 0.12)

	-- The ground splits open and is thrown up around the blade.
	U.groundCracks(position, 11, 12, RED, 2.8)
	U.groundRocks(position, 14, 5.5, 2.6)
	task.delay(0.05, U.groundRocks, position, 8, 2.6, 1.8)
	U.debris(position, 18, 50, 1.3)
	U.pillar(position, BLACK, 2.6, 22, 0.5, Enum.Material.SmoothPlastic, 0.15)
	U.pillar(position, RED, 1.3, 26, 0.4)

	blackLightning(center, 7, 7, 0.28)
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2 + math.random() * 0.45
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		U.lightning(position + UP * 0.4, position + out * (8 + math.random() * 5) + UP * 0.3, BLACK, RED, 0.18, 0.28)
	end

	blackSmoke(center, 22, 5.5, 28)
	U.burst(position, {
		texture = U.textures.Smoke,
		color = Color3.fromRGB(150, 140, 130),
		count = 14,
		size = 6,
		speed = NumberRange.new(18, 34),
		lifetime = NumberRange.new(0.7, 1.2),
		lightEmission = 0,
		transparency = 0.4,
		drag = 2,
		spread = 70,
	})
	redSparks(center, 24, 1.2)
	U.light(position + UP * 2, RED, 12, 34, 0.5)
	lingerSmoke(position, 1.2, 6)

	-- The blade, buried in the ground, flares red.
	swordGlow(character, RED, 0.3, 0.3)
	task.delay(0.05, function()
		local point = bladePoint(character, 0)
		if point and character.Parent then
			U.glint(point, 1.6, RED)
		end
	end)

	local mine = U.isLocal(character)
	if type(data.targets) == "table" then
		for _, victim in data.targets do
			if typeof(victim) == "Instance" and victim:IsA("Model") then
				U.highlight(victim, RED, 0.3)
				mine = mine or U.isLocal(victim)
			end
		end
	end
	if mine then
		impactFrame()
		CameraShake.Add(0.2)
		CameraShake.FovKick(12)
	end
end

function handlers.BullThrust(data, character, root)
	local phase = data.phase
	if phase == "Propel" then
		local direction: Vector3 = if typeof(data.direction) == "Vector3"
			then data.direction
			else root.CFrame.LookVector
		-- The server says how long the (steerable) propel lasts.
		local duration = if type(data.duration) == "number" then data.duration else 0.55
		local air = data.airborne == true
		play(character, if air then ANIMS.AirPropel else ANIMS.Propel)
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
		U.flash(back, RED, 3.5, 0.12)
		blackLightning(back, 3, 3, 0.2)
		task.delay(0.08, U.impactRing, back, direction, BLACK, 0.5, 6.5, 0.28)
		glowBurst(back, 5, 0.3)
		edgeGlow(character, duration + 0.1, 1)
		bloomPulse(root.Position, 0.6, 0.25)
		trailEmitter(root, {
			Texture = U.textures.Spark,
			Color = ColorSequence.new(WHITE_HOT, HOT),
			LightEmission = 1,
			Size = NumberSequence.new(0.7, 0),
			Transparency = NumberSequence.new(0.1, 1),
			Lifetime = NumberRange.new(0.12, 0.22),
			Rate = 80,
			Speed = NumberRange.new(6, 12),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(12, 12),
		}, duration)
		if air then
			local token = bump(character)
			meteorTail(root, duration, function()
				return live(character, token)
			end)
		else
			U.ringBurst(CFrame.new(feetOf(character, root) + UP * 0.1), BLACK, 0.8, 5, 0.3, 0.2)
			task.delay(0.05, U.ringBurst, CFrame.new(feetOf(character, root) + UP * 0.15), RED, 0.6, 4, 0.25, 0.15)
		end

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
		U.speedLines(root, if air then direction else nil, duration)
		local trench: Vector3? = if air then nil else feetOf(character, root)
		for i = 0, math.floor(duration / 0.06) do
			task.delay(i * 0.06, function()
				if character.Parent then
					U.afterimage(character, if i % 2 == 0 then BLACK else DARK_RED, 0.28)
					if i % 3 == 1 then
						blackLightning(root.Position, 1, 2.2, 0.12) -- anti-magic crackling off him
					end
					if not air then
						local feet = feetOf(character, root)
						blackSmoke(feet + UP * 0.3, 2, 1.6, 4)
						local from = trench
						if from and (feet - from).Magnitude > 0.5 and (feet - from).Magnitude < 14 then
							U.groove(from, feet, 0.7, RED, 1.6)
						end
						trench = feet
					end
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
		U.impactSpikes(position, RED, 10, 7, 0.24, WHITE_HOT)
		U.flash(position, BLACK, 5, 0.15)
		U.flash(position, WHITE, 3, 0.08)
		U.impactRing(position, direction, RED, 0.6, 4.5, 0.22)
		redSparks(position, 16, 0.8, direction)
		blackLightning(position, 4, 3.2)
		U.light(position, RED, 8, 14, 0.25)
		task.delay(0.04, U.impactRing, position, direction, BLACK, 0.5, 5.5, 0.24)
		U.highlight(data.target, RED, 0.15)
		if U.isLocal(character) or U.isLocal(data.target) then
			CameraShake.Add(0.25)
		end
	elseif phase == "Combo" then
		-- The cuts follow the animation's beats, so they keep time with the blade.
		local token = bump(character)
		play(character, ANIMS.BullCombo, function(event)
			if live(character, token) then
				comboSwing(character, root, event)
			end
		end)
		swordTrail(character, 1.2)
	elseif phase == "Strike" then
		if data.kind == "Thrust" then
			comboFinisher(data, character, root)
		else
			comboImpact(data, character, root)
		end
	elseif phase == "Land" then
		-- Air version, nobody caught: he lands driving the sword into the
		-- ground and the slam goes off.
		bump(character)
		play(character, ANIMS.PlungeImpact)
		bullSlam(data, character)
		if data.stuck then
			-- It hit nobody: the sword sticks in the ground a moment (end lag).
			task.delay(0.05, PoseAnimator.Freeze, character, data.stuck)
		end
	elseif phase == "Interrupted" then
		-- Cut short (he got hit, or they broke out): no more swings.
		bump(character)
		if PoseAnimator.Current(character) == ANIMS.BullCombo then
			PoseAnimator.FadeOut(character, 0.2)
		end
	end
end

-- Black Meteorite: standing grab, carry them up, crater slam (Black Moon's
-- lunge grab is drawn here too)

-- His free hand's fist, where the grab closes.
local function gripPoint(character: Model): Vector3?
	local hand = character:FindFirstChild("Left Arm")
	return if hand and hand:IsA("BasePart") then (hand.CFrame * CFrame.new(0, -1, 0)).Position else nil
end

local function handSwirl(arm: BasePart, duration: number, alive: () -> boolean)
	local colors = { BLACK, RED, BLACK, DARK_RED }
	local ribbons: { BasePart } = {}
	for _, color in colors do
		local part = U.newPart({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = arm.CFrame })
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.14, 0)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.14, 0)
		a1.Parent = part
		local dark = color == BLACK
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(color)
		trail.LightEmission = if dark then 0 else 1
		trail.LightInfluence = 0
		trail.Lifetime = 0.16
		trail.MinLength = 0
		trail.FaceCamera = true
		trail.Transparency = NumberSequence.new(if dark then 0.05 else 0.15, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Parent = part
		table.insert(ribbons, part)
	end
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) / duration
		if t >= 1 or not arm.Parent or not alive() then
			connection:Disconnect()
			for _, part in ribbons do
				for _, child in part:GetChildren() do
					if child:IsA("Trail") then
						child.Enabled = false
					end
				end
				task.delay(0.3, part.Destroy, part)
			end
			return
		end
		local radius = 1.2 * (1 - 0.6 * t)
		for i, part in ribbons do
			local angle = t * math.pi * 6 + (i / #ribbons) * math.pi * 2
			-- Half round the fist, half further up the forearm.
			local along = if i % 2 == 0 then -0.95 else -0.4
			part.CFrame = arm.CFrame * CFrame.new(math.cos(angle) * radius, along, math.sin(angle) * radius)
		end
	end)
end

-- Black lightning crawling down his arm, shoulder to fist, hop by hop.
local function armCrawl(arm: BasePart, duration: number, alive: () -> boolean)
	local start = os.clock()
	task.spawn(function()
		local hop = 0
		while os.clock() - start < duration and arm.Parent and alive() do
			-- R6 arms are 2 studs long: the shoulder is at +1, the fist at -1.
			local from = 0.9 - (hop % 4) * 0.45
			local a = arm.CFrame:PointToWorldSpace(Vector3.new(0, from, 0) + U.randomUnit() * 0.3)
			local b = arm.CFrame:PointToWorldSpace(Vector3.new(0, from - 0.65, 0) + U.randomUnit() * 0.35)
			U.lightning(a, b, BLACK, RED, 0.08, 0.12, false)
			hop += 1
			task.wait(0.035)
		end
	end)
end

local function grasp(character: Model, root: BasePart, air: boolean)
	local at = gripPoint(character)
	if not at then
		return
	end
	local forward = root.CFrame.LookVector
	U.impactSpikes(at, RED, 8, 4, 0.2, WHITE_HOT)
	U.flash(at, WHITE, 2, 0.06)
	U.flash(at, BLACK, 4.5, 0.2)
	U.flash(at, RED, 2.6, 0.12)
	U.glint(at, 0.8, RED)
	U.impactRing(at, forward, RED, 2.4, 0.2, 0.1)
	task.delay(0.03, U.impactRing, at + forward * 0.5, forward, BLACK, 0.4, 3.4, 0.22)
	U.burst(at, {
		color = RED,
		count = 10,
		size = 0.4,
		speed = NumberRange.new(18, 34),
		lifetime = NumberRange.new(0.1, 0.25),
		streaks = true,
		spread = 30,
		direction = forward,
	})
	blackSmoke(at, 5, 1.6, 6)
	blackLightning(at, 3, 2.4, 0.16)
	U.light(at, RED, 7, 12, 0.3)
	if not air then
		local feet = feetOf(character, root)
		U.ringBurst(CFrame.new(feet + UP * 0.1), BLACK, 0.6, 4, 0.25, 0.16)
		U.groundCracks(feet + forward * 0.8, 4, 3, RED, 1)
		blackSmoke(feet + UP * 0.3, 4, 1.6, 5)
	end
	if U.isLocal(character) then
		CameraShake.Add(0.12)
	end
end

function handlers.BlackMeteorite(data, character, root)
	local phase = data.phase
	if phase == "Reach" then
		local air = data.airborne == true
		local token = bump(character)
		local function alive(): boolean
			return live(character, token)
		end
		play(character, if air then ANIMS.AirMeteorReach else ANIMS.MeteorReach, function(event)
			if event == "Grasp" and alive() then
				grasp(character, root, air)
			end
		end)
		local arm = character:FindFirstChild("Left Arm")
		if arm and arm:IsA("BasePart") then
			handSwirl(arm, 0.45, alive)
			armCrawl(arm, 0.4, alive)
			-- Black wisps peeling off the arm, red embers.
			partEmitter(arm, {
				Texture = U.textures.Smoke,
				Color = ColorSequence.new(BLACK),
				LightEmission = 0,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.3) }),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(0.25, 0.45),
				Rate = 40,
				Speed = NumberRange.new(0.5, 2),
				SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, 4, 0),
				Drag = 2,
			}, 0.4)
			partEmitter(arm, {
				Texture = U.textures.Spark,
				Color = ColorSequence.new(RED),
				LightEmission = 1,
				Size = NumberSequence.new(0.2, 0),
				Lifetime = NumberRange.new(0.15, 0.35),
				Rate = 18,
				Speed = NumberRange.new(2, 5),
				SpreadAngle = Vector2.new(180, 180),
			}, 0.4)
		end
		-- Anti-magic streaking in to the hand as it draws back.
		for i = 0, 5 do
			task.delay(i * 0.025, function()
				local at = gripPoint(character)
				if at and alive() then
					inflow(at, 3)
				end
			end)
		end
		U.light(root.Position, RED, 3, 10, 0.45)
	elseif phase == "Whiff" then
		-- Nobody there: the hand closes on nothing and the anti-magic
		-- gutters out of it.
		bump(character)
		local at = gripPoint(character)
		if at then
			U.flash(at, BLACK, 2.4, 0.18)
			blackSmoke(at, 7, 1.4, 4)
			U.burst(at, {
				color = RED,
				count = 6,
				size = 0.3,
				speed = NumberRange.new(2, 6),
				lifetime = NumberRange.new(0.4, 0.7),
				acceleration = Vector3.new(0, -14, 0),
				drag = 1,
			})
		end
	elseif phase == "Cancel" then
		-- Hit out of the reach.
		bump(character)
		local current = PoseAnimator.Current(character)
		if current == ANIMS.MeteorReach or current == ANIMS.AirMeteorReach then
			PoseAnimator.FadeOut(character, 0.15)
		end
	elseif phase == "Seize" then
		local air = data.airborne == true
		play(character, if air then ANIMS.AirSeize else ANIMS.Seize)
		local target = data.target
		task.delay(0.07, function()
			local at = gripPoint(character)
			if not at or not character.Parent then
				return
			end
			U.flash(at, WHITE, 3, 0.08)
			U.flash(at, BLACK, 5, 0.18)
			U.impactSpikes(at, RED, 10, 6, 0.24, WHITE_HOT)
			U.impactRing(at, root.CFrame.LookVector, RED, 0.4, 3.5, 0.2)
			redSparks(at, 12, 0.7)
			U.highlight(target, BLACK, 0.3)
			if air then
				-- Nothing under them: the burst rings out around the grip.
				blackSmoke(at, 6, 2.2, 6)
				U.ringBurst(CFrame.new(at) * CFrame.Angles(rad(90), 0, 0), BLACK, 0.8, 5, 0.25, 0.2)
			else
				blackSmoke(feetOf(character, root) + UP * 0.3, 6, 2.2, 6)
				U.ringBurst(CFrame.new(feetOf(character, root) + UP * 0.1), BLACK, 0.8, 5, 0.25, 0.2)
			end
			blackLightning(at, 3, 2.5, 0.2)
		end)
		-- The surge (it lands with the server's 2-damage hit).
		task.delay(0.2, function()
			local at = gripPoint(character)
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
		end)
	elseif phase == "Vortex" then
		play(character, ANIMS.MeteorSpin)
		local target = data.target
		local air = data.airborne == true
		local length = MeteorVortex.Length
		if typeof(data.origin) == "CFrame" then
			-- The whole move from here: spin, flip, head-first dive, landing.
			local top = if type(data.top) == "number" then data.top else MeteorVortex.Top
			local floorY = if type(data.floorY) == "number" then data.floorY else nil
			local plan = MeteorVortex.Plan(data.origin, top, floorY)
			local start = os.clock()
			local bind = "CloverVortex" .. tostring(start)
			-- After shift lock and the camera, so the path has the last word.
			RunService:BindToRenderStep(bind, Enum.RenderPriority.Camera.Value + 3, function()
				local t = os.clock() - start
				if t >= plan.length or not root.Parent then
					RunService:UnbindFromRenderStep(bind)
					return
				end
				root.CFrame = MeteorVortex.At(plan, t)
			end)
		end

		-- Take-off: the ground blows out under them.
		local ground = U.groundBelow(root.Position, { character })
		if ground and not air then
			local feet = ground.Position
			U.flash(feet + UP, BLACK, 9, 0.25)
			U.shockwave(feet, RED, 2, 14, 0.35)
			U.ringBurst(CFrame.new(feet + UP * 0.15), BLACK, 1, 12, 0.35, 0.45)
			task.delay(0.04, U.ringBurst, CFrame.new(feet + UP * 0.2), RED, 0.8, 8, 0.3, 0.2)
			U.groundCracks(feet, 8, 6, RED, 2)
			U.groundRocks(feet, 8, 3, 1.6)
			U.debris(feet, 8, 38, 1)
			U.scorch(feet, 4.5, RED, 2.5)
			U.dustWave(feet, 14)
			blackSmoke(feet + UP * 0.5, 16, 3.5, 18)
			U.light(feet, RED, 8, 18, 0.35)
		else
			U.flash(root.Position, BLACK, 8, 0.25)
			U.ringBurst(CFrame.new(root.Position), BLACK, 1, 10, 0.35, 0.4)
		end

		U.bodyTrail(character, BLACK, length)
		U.bodyTrail(target, DARK_RED, length)
		U.spiral(root, BLACK, 4.8, 3, length, 5, 0.9, 0.15)
		U.spiral(root, RED, 3.8, 3, length, 3, 0.3, 0.15)
		partEmitter(root, {
			Texture = U.textures.Smoke,
			Color = ColorSequence.new(BLACK),
			LightEmission = 0,
			Size = NumberSequence.new(1.8, 4.5),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.4, 0.7),
			Rate = 110,
			Speed = NumberRange.new(6, 14),
			SpreadAngle = Vector2.new(180, 30),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-360, 360),
		}, length)
		crackle(root, length, 0.08, 5)
		for turn = 0, MeteorVortex.Turns - 1 do
			-- A full circle of steel each time round (faster in the middle).
			local at = length * (0.18 + turn * 0.27)
			task.delay(at, function()
				if character.Parent then
					crescent(character, {
						center = CFrame.new(0, 0.2, 0),
						radius = 6,
						from = 90,
						to = 450,
						tilt = 0,
						width = 1.6,
						sweep = 0.16,
						fade = 0.22,
					})
				end
			end)
		end
		for i = 0, math.floor(length / 0.1) - 1 do
			task.delay(i * 0.1, function()
				if not character.Parent then
					return
				end
				local here = root.Position
				U.ringBurst(CFrame.new(here - UP * 1.5), if i % 2 == 0 then BLACK else RED, 3, 9, 0.25, 0.25)
				if i % 3 == 0 then
					blackLightning(here, 2, 5, 0.15)
				end
				-- The ground below gets torn up into the vortex.
				local below = if not air then U.groundBelow(here, { character }, 40) else nil
				if below and i % 2 == 0 then
					U.ringBurst(CFrame.new(below.Position + UP * 0.2), BLACK, 4, 12, 0.3, 0.35)
					U.debris(below.Position, 3, 30, 0.8)
				end
			end)
		end

		-- At the top: the blade drinks in anti-magic before the slam.
		task.delay(MeteorVortex.Length - 0.3, function()
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
	elseif phase == "Slam" then
		local dive = if type(data.dive) == "number" then data.dive else 0.55
		play(character, ANIMS.MeteorDrill)
		heavyTrail(character, dive)
		U.bodyTrail(character, RED, dive)
		U.bodyTrail(data.target, BLACK, dive)
		U.speedLines(root, -UP, dive)
		U.spiral(root, BLACK, 3.4, 3, dive, 4, 0.9, 0.12)
		U.spiral(root, RED, 2.6, 3, dive, 3, 0.3, 0.12)
		-- Spinning afterimages all the way down.
		for i = 0, math.floor((dive - MeteorVortex.Flip) / 0.05) do
			task.delay(MeteorVortex.Flip + i * 0.05, function()
				if character.Parent then
					U.afterimage(character, if i % 2 == 0 then BLACK else DARK_RED, 0.22)
				end
			end)
		end
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
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(30, 30),
			Drag = 3,
		}, dive)
		trailEmitter(root, {
			Texture = U.textures.Spark,
			Color = ColorSequence.new(RED, DARK_RED),
			LightEmission = 1,
			Size = NumberSequence.new(0.4, 0),
			Lifetime = NumberRange.new(0.15, 0.3),
			Rate = 70,
			Speed = NumberRange.new(14, 24),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(25, 25),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Squash = NumberSequence.new(1.6),
		}, dive)
		-- Air compressing under them on the way down.
		for i = 0, math.floor(dive / 0.06) do
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
	elseif phase == "Impact" then
		local position: Vector3 = data.position
		-- (He rolls back over onto his feet: the end of the shared path.)
		play(character, ANIMS.MeteorLand)
		local victim = data.target
		U.flash(position + UP, WHITE, 6, 0.08)
		U.flash(position + UP, BLACK, 16, 0.35)
		U.flash(position + UP, RED, 10, 0.25)
		U.impactSpikes(position + UP * 2, RED, 18, 16, 0.36, WHITE_HOT)
		U.scorch(position, 9, RED, 3.5)
		U.dustWave(position, 22)
		U.shockwave(position, BLACK, 4, 30, 0.5, Enum.Material.Glass, 0.35)
		U.shockwave(position, RED, 3, 24, 0.45)
		U.ringBurst(CFrame.new(position + UP * 0.2), BLACK, 1.5, 20, 0.5, 0.7)
		task.delay(0.05, U.ringBurst, CFrame.new(position + UP * 0.3), RED, 1, 15, 0.4, 0.35)
		task.delay(0.1, U.ringBurst, CFrame.new(position + UP * 0.4), WHITE, 0.5, 10, 0.25, 0.12)
		task.delay(0.12, U.shockwave, position, BLACK, 2, 36, 0.6, Enum.Material.Glass, 0.5)
		blackLightning(position + UP, 8, 8, 0.3)
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
		end
	end
end

-- Black Divider: charged cleave; press again on the red flash for a perfect

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

		-- The edges burn brighter as it builds, and a glowing orb swells at
		-- the point.
		edgeGlow(character, 0.62, 0.7)
		local orb = U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, Color = HOT, Transparency = 0.2 })
		local orbHalo =
			U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, Color = RED, Transparency = 0.5 })
		local orbStart = os.clock()
		local orbConnection
		orbConnection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - orbStart
			local tip = bladePoint(character, 2.1)
			if t > 0.7 or not tip or not live(character, token) then
				orbConnection:Disconnect()
				orb:Destroy()
				orbHalo:Destroy()
				return
			end
			local grow = math.min(t / 0.6, 1)
			local pulse = 1 + 0.12 * math.sin(t * 30)
			orb.CFrame = CFrame.new(tip)
			orb.Size = Vector3.one * (0.3 + 0.9 * grow) * pulse
			orbHalo.CFrame = CFrame.new(tip)
			orbHalo.Size = Vector3.one * (0.6 + 2 * grow) * pulse
		end)

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
				glowBurst(tip, 3, 0.22)
				bloomPulse(tip, 0.7, 0.2)
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
			glow = if perfect then 1.4 else 1,
		})
		edgeGlow(character, 0.35, if perfect then 1.4 else 1)
		bloomPulse(root.Position, if perfect then 1.1 else 0.7, 0.3)
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
			U.impactSpikes(spot + UP, RED, if perfect then 14 else 10, if perfect then 12 else 8, 0.28, WHITE_HOT)
			U.scorch(spot, if perfect then 6 else 4, RED, 2.5)
			U.dustWave(spot, if perfect then 14 else 10)
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
			glow = if perfect then 1.4 else 1,
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
				glow = 1,
			})
		end
		-- The cut burns: glowing edges, hot flares along the arc, the bloom swells.
		edgeGlow(character, 0.3, if perfect then 1.4 else 1)
		for i, angle in { 60, 0, -60 } do
			local along = root.CFrame
				* CFrame.Angles(0, rad(angle), 0)
				* CFrame.new(0, 0.2, -(if perfect then 6.6 else 5.8))
			task.delay(0.02 * i, glowBurst, along.Position, if perfect then 3.4 else 2.4, 0.25)
		end
		bloomPulse(root.Position, if perfect then 1.2 else 0.75, 0.3)

		local front = root.Position + look * 5
		local feet = feetOf(character, root)
		U.impactSpikes(front, RED, if perfect then 14 else 10, if perfect then 11 else 8, 0.28, WHITE_HOT)
		U.dustWave(feet, if perfect then 14 else 10)
		-- The crescent it burns into the ground in front of him, as it sweeps.
		local reach = if perfect then 6.6 else 5.8
		local arc: { Vector3 } = {}
		for i = 0, 8 do
			local angle = rad(70 - 140 * i / 8)
			arc[i + 1] = feet + (root.CFrame.RightVector * math.sin(angle) + look * math.cos(angle)) * reach
		end
		for i = 1, 8 do
			task.delay(0.1 * (i - 1) / 8, U.groove, arc[i], arc[i + 1], if perfect then 0.8 else 0.6, RED, 1.8)
		end
		-- The cut's wind: rings, dust and a cone of sparks.
		U.ringBurst(CFrame.new(root.Position + UP * 0.2), WHITE, 2, if perfect then 16 else 10, 0.3, 0.12)
		U.ringBurst(CFrame.new(root.Position + UP * 0.2), BLACK, 2, if perfect then 20 else 12, 0.4, 0.35)
		task.delay(
			0.05,
			U.ringBurst,
			CFrame.new(root.Position + UP * 0.3),
			RED,
			1.5,
			if perfect then 15 else 9,
			0.35,
			0.2
		)
		blackLightning(front, if perfect then 6 else 4, 5, 0.22)
		U.light(front, RED, 9, 18, 0.3)
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

-- Anti-Magic Deflect: an anti-magic barrier on the blade that counters
-- anything; melee gets slashed aside, projectiles get sent back

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
	crackle(disc, duration, 0.1, radius * 0.9)
	partEmitter(disc, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(BLACK),
		LightEmission = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.25, 0.45),
		Rate = 30,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 2,
	}, duration)
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
		local air = data.airborne == true
		play(character, if air then ANIMS.AirDeflectStance else ANIMS.DeflectStance)
		swordGlow(character, BLACK, 0.85, 0.25)
		swordAura(character, 0.8, 26)
		task.delay(0.08, function()
			local tip = bladePoint(character, 1.8)
			if tip and character.Parent then
				U.glint(tip, 1.6, RED)
			end
		end)
		local window = if type(data.window) == "number" then data.window else 0.65
		openBarrier(character, root, window)
		edgeGlow(character, window, 0.9)
		glowBurst(root.Position + root.CFrame.LookVector * 2.4 + UP * 0.6, 3, 0.25)
		U.light(root.Position + root.CFrame.LookVector * 2.4, RED, 4, 14, window)
		local base = if air then root.Position - UP * 2.8 else feetOf(character, root) + UP * 0.1
		U.ringBurst(CFrame.new(base), DARK_RED, 1, 5, 0.3, 0.15)
		task.delay(0.05, U.ringBurst, CFrame.new(base + UP * 0.1), BLACK, 0.8, 6, 0.3, 0.2)
		blackSmoke(base + UP * 0.2, 6, 2, 5)
		U.flash(root.Position + root.CFrame.LookVector * 1.5, BLACK, 4, 0.15)
		U.light(root.Position, RED, 5, 12, 0.3)
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
		U.impactSpikes(contact, RED, 14, 10, 0.3, WHITE_HOT)
		U.flash(contact, WHITE, 6, 0.12)
		glowBurst(contact, 5, 0.3)
		bloomPulse(contact, 1, 0.3)
		if involves(data, character) then
			impactFrame(1.2)
			CameraShake.Add(0.45)
			CameraShake.FovKick(12)
		end
		PoseAnimator.Freeze(character, 0.08)
		U.popup(root.Position + UP * 4, "DEFLECT", RED, 1.6)

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
				glow = 1.1,
			})
			edgeGlow(character, 0.3, 1.2)
		end)
		task.delay(0.2, function()
			if not targetRoot then
				return
			end
			local p = targetRoot.Position + UP * 0.5
			local side = root.CFrame.RightVector
			slashMark(p, -0.6, 8, 0.35)
			U.impactSpikes(p, RED, 10, 8, 0.26, WHITE_HOT)
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
			glow = 1,
		})
		edgeGlow(character, 0.35, 1.1)
		local front = root.Position + direction * 3
		task.delay(0.12, glowBurst, front, 4, 0.28)
		task.delay(0.12, bloomPulse, front, 0.8, 0.25)
		task.delay(0.15, blackLightning, front, 4, 3.5, 0.2)
		task.delay(0.15, U.flash, front, RED, 4, 0.12)
		U.sparks(front, direction, 1.3)
		U.impactSpikes(front, RED, 12, 8, 0.26, WHITE_HOT)
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

-- Special (R): Anti-Magic Leap / Meteor Plunge

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
		U.scorch(feet, 3.5, RED, 2)
		U.dustWave(feet, 12)
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
		U.impactSpikes(position + UP * 1.5, RED, 14, 12, 0.3, WHITE_HOT)
		U.scorch(position, 6, RED, 3)
		U.dustWave(position, 16)
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

return {}
