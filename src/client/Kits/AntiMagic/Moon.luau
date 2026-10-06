local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BlackMoon = require(ReplicatedStorage:WaitForChild("Shared").BlackMoon)

local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local Cinematic = require(script.Parent.Parent.Parent.Cinematic)
local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local Reactions = require(script.Parent.Parent.Parent.Reactions)
local VFX = require(script.Parent.Parent.Parent.VFX)

local U = VFX.Util

type Animation = PoseAnimator.Animation

local rad = math.rad

local Fx = require(script.Parent.Fx)
local BLACK, RED, DARK_RED, RIM_RED, WHITE, UP = Fx.BLACK, Fx.RED, Fx.DARK_RED, Fx.RIM_RED, Fx.WHITE, Fx.UP
local ANIMS, handlers, play, feetOf, bladePoint = Fx.ANIMS, Fx.handlers, Fx.play, Fx.feetOf, Fx.bladePoint
local swordGlow, swordAura, heavyTrail, blackSmoke = Fx.swordGlow, Fx.swordAura, Fx.heavyTrail, Fx.blackSmoke
local redSparks, blackLightning, slashMark = Fx.redSparks, Fx.blackLightning, Fx.slashMark
local impactFrame, lingerSmoke, partEmitter = Fx.impactFrame, Fx.lingerSmoke, Fx.partEmitter
local trailEmitter = Fx.trailEmitter
local Look = require(script.Parent.Look)
local awakenedVisuals = Look.awakenedVisuals

local MOON_LIGHT = Color3.fromRGB(238, 234, 220)
local MOON_SHADE = Color3.fromRGB(212, 207, 194)
local MOON_HALO = Color3.fromRGB(255, 226, 214)
local MOON_CUT = rad(35)
local MOON_SEGMENTS = 24

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function newWedge(color: Color3): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.CanQuery = false
	wedge.CanTouch = false
	wedge.CastShadow = false
	wedge.Material = Enum.Material.Neon
	wedge.Color = color
	wedge.Transparency = 1
	wedge.Parent = U.folder
	return wedge
end

local function triangle(a: Vector3, b: Vector3, c: Vector3, thickness: number): { { cframe: CFrame, size: Vector3 } }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	return {
		{
			cframe = CFrame.fromMatrix((a + b) / 2, right, up, back),
			size = Vector3.new(thickness, height, math.abs(ab:Dot(back))),
		},
		{
			cframe = CFrame.fromMatrix((a + c) / 2, -right, up, -back),
			size = Vector3.new(thickness, height, math.abs(ac:Dot(back))),
		},
	}
end

type MoonPiece = { part: BasePart, offset: CFrame, side: number, alpha: number, ray: boolean? }
type Moon = {
	update: (center: CFrame, visible: number, split: number, scar: number, spin: number) -> (),
	destroy: () -> (),
}

local function buildMoon(radius: number): Moon
	local pieces: { MoonPiece } = {}
	for i = 0, MOON_SEGMENTS - 1 do
		local a0 = MOON_CUT + (i / MOON_SEGMENTS) * math.pi * 2
		local a1 = MOON_CUT + ((i + 1) / MOON_SEGMENTS) * math.pi * 2
		local p0 = Vector3.new(math.cos(a0), math.sin(a0), 0) * radius
		local p1 = Vector3.new(math.cos(a1), math.sin(a1), 0) * radius
		local side = if i < MOON_SEGMENTS / 2 then 1 else -1
		for _, tri in triangle(Vector3.zero, p0, p1, 0.4) do
			local part = newWedge(MOON_LIGHT)
			part.Size = tri.size
			table.insert(pieces, { part = part, offset = tri.cframe, side = side, alpha = 0 })
		end
	end
	local face = CFrame.Angles(0, rad(90), 0)
	local cut = Vector2.new(math.cos(MOON_CUT), math.sin(MOON_CUT))
	for _, sea in
		{
			{ 0.25, 0.3, 0.28 },
			{ -0.35, 0.1, 0.22 },
			{ -0.1, -0.4, 0.18 },
			{ 0.45, -0.25, 0.14 },
			{ -0.5, 0.45, 0.12 },
			{ 0.1, 0.62, 0.1 },
		}
	do
		local x, y, r = sea[1] * radius, sea[2] * radius, sea[3] * radius
		local part = U.newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, r * 2, r * 2),
			Color = MOON_SHADE,
			Transparency = 1,
		})
		local side = if cut.X * y - cut.Y * x > 0 then 1 else -1
		table.insert(pieces, { part = part, offset = CFrame.new(x, y, -0.35) * face, side = side, alpha = 0.15 })
	end
	local rimSegments = 36
	for i = 0, rimSegments - 1 do
		local angle = MOON_CUT + ((i + 0.5) / rimSegments) * math.pi * 2
		local part = U.newPart({
			Size = Vector3.new(2 * math.pi * radius * 1.015 / rimSegments * 1.1, radius * 0.025, 0.3),
			Color = RED,
			Transparency = 1,
		})
		table.insert(pieces, {
			part = part,
			offset = CFrame.Angles(0, 0, angle) * CFrame.new(radius * 1.015, 0, -0.2) * CFrame.Angles(0, 0, rad(90)),
			side = if i < rimSegments / 2 then 1 else -1,
			alpha = 0.3,
		})
	end
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2 + (if i % 2 == 0 then 0.1 else -0.07)
		local length = radius * (if i % 2 == 0 then 1.9 else 1.4)
		local part = U.newPart({
			Size = Vector3.new(length, radius * (if i % 2 == 0 then 0.07 else 0.045), 0.2),
			Color = MOON_HALO,
			Transparency = 1,
		})
		table.insert(pieces, {
			part = part,
			offset = CFrame.Angles(0, 0, angle) * CFrame.new(radius * 0.95 + length / 2, 0, 3),
			side = 0,
			alpha = if i % 2 == 0 then 0.86 else 0.9,
			ray = true,
		})
	end
	for _, halo in { { 1.1, 0.68 }, { 1.28, 0.84 }, { 1.6, 0.93 } } do
		local part = U.newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, radius * 2 * halo[1], radius * 2 * halo[1]),
			Color = MOON_HALO,
			Transparency = 1,
		})
		table.insert(pieces, { part = part, offset = CFrame.new(0, 0, 1 + halo[1]) * face, side = 0, alpha = halo[2] })
	end
	local scarGlow = U.newPart({ Size = Vector3.new(radius * 2.3, 1, 0.3), Color = RED, Transparency = 1 })
	local scarCore = U.newPart({ Size = Vector3.new(radius * 2.3, 1, 0.3), Color = WHITE, Transparency = 1 })

	local across = Vector3.new(-math.sin(MOON_CUT), math.cos(MOON_CUT), 0)
	return {
		update = function(center: CFrame, visible: number, split: number, scar: number, spin: number)
			for _, piece in pieces do
				local offset = piece.offset
				if piece.ray then
					offset = CFrame.Angles(0, 0, spin) * offset
				elseif piece.side ~= 0 then
					offset = CFrame.new(across * piece.side * split * radius * 0.4)
						* CFrame.Angles(0, 0, piece.side * split * 0.12)
						* offset
				end
				piece.part.CFrame = center * offset
				local shown = if piece.side == 0 then math.max(visible - split, 0) else visible
				piece.part.Transparency = 1 - shown * (1 - piece.alpha)
			end
			local line = center * CFrame.new(0, 0, -0.7) * CFrame.Angles(0, 0, MOON_CUT)
			scarGlow.CFrame = line
			scarGlow.Size = Vector3.new(radius * 2.3, math.max(scar * radius * 0.07, 0.05), 0.3)
			scarGlow.Transparency = 1 - scar * 0.85
			scarCore.CFrame = line * CFrame.new(0, 0, -0.1)
			scarCore.Size = Vector3.new(radius * 2.3, math.max(scar * radius * 0.02, 0.05), 0.3)
			scarCore.Transparency = 1 - scar
		end,
		destroy = function()
			for _, piece in pieces do
				piece.part:Destroy()
			end
			scarGlow:Destroy()
			scarCore:Destroy()
		end,
	}
end

local function launchedFor(victim: Model): Animation?
	if victim:GetAttribute("Kit") == "AntiMagic" then
		return ANIMS.Launched
	end
	return Reactions.Launched
end

local function flightStreak(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local cframe = CFrame.lookAt((from + to) / 2, to)
	local glow = U.newPart({ Size = Vector3.new(1.2, 1.2, length), CFrame = cframe, Color = RED, Transparency = 0.45 })
	local core = U.newPart({
		Size = Vector3.new(0.45, 0.45, length),
		CFrame = cframe,
		Color = BLACK,
		Material = Enum.Material.SmoothPlastic,
	})
	U.tween(glow, 0.6, { Size = Vector3.new(0.05, 0.05, length), Transparency = 1 })
	U.tween(core, 0.8, { Size = Vector3.new(0.02, 0.02, length), Transparency = 1 })
	task.delay(0.85, function()
		glow:Destroy()
		core:Destroy()
	end)
end

local function moonCrater(position: Vector3)
	U.flash(position + UP, BLACK, 14, 0.3)
	U.flash(position + UP, RED, 8, 0.22)
	U.shockwave(position, RED, 3, 24, 0.45)
	U.shockwave(position, BLACK, 4, 28, 0.5, Enum.Material.Glass, 0.4)
	U.ringBurst(CFrame.new(position + UP * 0.2), BLACK, 1, 22, 0.5, 0.8)
	task.delay(0.05, U.ringBurst, CFrame.new(position + UP * 0.3), RED, 1, 16, 0.4, 0.35)
	U.groundCracks(position, 16, 16, RED, 4)
	U.groundRocks(position, 16, 7, 3)
	task.delay(0.05, U.groundRocks, position, 9, 3.5, 2.2)
	U.debris(position, 24, 60, 1.6)
	U.pillar(position, BLACK, 3, 30, 0.6, Enum.Material.SmoothPlastic, 0.15)
	blackSmoke(position + UP, 28, 6.5, 34)
	U.burst(position, {
		texture = U.textures.Smoke,
		color = Color3.fromRGB(150, 140, 130),
		count = 20,
		size = 7,
		speed = NumberRange.new(20, 42),
		lifetime = NumberRange.new(0.8, 1.5),
		lightEmission = 0,
		transparency = 0.35,
		drag = 2,
		spread = 35,
		direction = (UP + Vector3.new(0.01, 0, 0)).Unit,
	})
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2 + math.random() * 0.4
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		U.lightning(position + UP * 0.4, position + out * (10 + math.random() * 8) + UP * 0.3, BLACK, RED, 0.22, 0.32)
	end
	U.light(position + UP * 2, RED, 14, 45, 0.6)
	lingerSmoke(position, 2.2, 10)
	local mine = U.getRoot(Players.LocalPlayer.Character)
	if mine then
		local distance = (mine.Position - position).Magnitude
		if distance < 70 then
			CameraShake.Add(0.6 * (1 - distance / 70))
		end
	end
end

type NightSetting = { update: (t: number, visible: number) -> (), destroy: () -> () }

local function buildNightSetting(plan: BlackMoon.Plan): NightSetting
	local made: { Instance } = {}
	local function holder(cframe: CFrame, size: Vector3): BasePart
		local part = U.newPart({ Size = size, CFrame = cframe, Transparency = 1 })
		table.insert(made, part)
		return part
	end
	local center = plan.origin.Position + UP * 30

	type Star = { part: BasePart, phase: number, speed: number, base: number }
	local stars: { Star } = {}
	local toMoon = (plan.moon - center).Unit
	for i = 1, 170 do
		local direction
		repeat
			direction = U.randomUnit()
		until direction.Y > 0.08
		if i % 3 == 0 then
			direction = (direction + toMoon * 1.2).Unit
		end
		local size = 0.6 + math.random() * 1.4
		local part = U.newPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = CFrame.new(center + direction * (380 + math.random() * 60)),
			Color = if i % 5 == 0 then Color3.fromRGB(255, 220, 220) else Color3.fromRGB(225, 232, 255),
			Transparency = 1,
		})
		table.insert(made, part)
		table.insert(
			stars,
			{ part = part, phase = math.random() * 6.28, speed = 2 + math.random() * 4, base = math.random() * 0.3 }
		)
	end

	local function clouds(position: Vector3, size: Vector3, color: Color3, scale: number, count: number)
		local part = holder(CFrame.lookAt(position, plan.moonCamera), size)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = U.textures.Smoke
		emitter.Color = ColorSequence.new(color, color:Lerp(Color3.fromRGB(120, 130, 170), 0.35))
		emitter.LightEmission = 0.05
		emitter.LightInfluence = 0
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, scale * 0.7),
			NumberSequenceKeypoint.new(1, scale * 1.2),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.55),
			NumberSequenceKeypoint.new(0.75, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(6, 9)
		emitter.Rate = count / 7
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(8, 8)
		emitter.EmissionDirection = Enum.NormalId.Right
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-4, 4)
		emitter.Parent = part
		emitter:Emit(count)
		return emitter
	end
	local toMoonFromPerch = (plan.moon - plan.perch).Unit
	local cloudFront = clouds(
		plan.perch + toMoonFromPerch * 140 + UP * 10,
		Vector3.new(260, 60, 30),
		Color3.fromRGB(26, 28, 44),
		46,
		14
	)
	local cloudLow = clouds(
		plan.perch + toMoonFromPerch * 210 - UP * 40,
		Vector3.new(420, 30, 40),
		Color3.fromRGB(20, 22, 36),
		70,
		12
	)

	local ground = U.groundBelow(plan.origin.Position, nil, 300)
	local floorY = if ground then ground.Position.Y else plan.origin.Position.Y - 3
	local groundMist: ParticleEmitter? = nil
	if ground then
		local mistHolder =
			holder(CFrame.new(plan.origin.Position.X, floorY + 0.5, plan.origin.Position.Z), Vector3.new(110, 1, 110))
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = U.textures.Smoke
		mist.Color = ColorSequence.new(Color3.fromRGB(150, 162, 200))
		mist.LightEmission = 0.1
		mist.LightInfluence = 0
		mist.Size = NumberSequence.new(8, 16)
		mist.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.78),
			NumberSequenceKeypoint.new(1, 1),
		})
		mist.Lifetime = NumberRange.new(3, 5)
		mist.Rate = 20
		mist.Speed = NumberRange.new(0.5, 1.5)
		mist.EmissionDirection = Enum.NormalId.Top
		mist.SpreadAngle = Vector2.new(70, 70)
		mist.Rotation = NumberRange.new(0, 360)
		mist.Parent = mistHolder
		mist:Emit(25)
		groundMist = mist
	end

	local airHolder = holder(CFrame.new((plan.apex + plan.perch) / 2), Vector3.new(70, 40, 70))
	local ash = Instance.new("ParticleEmitter")
	ash.Texture = U.textures.Spark
	ash.Color = ColorSequence.new(BLACK)
	ash.LightEmission = 0
	ash.LightInfluence = 0
	ash.Size = NumberSequence.new(0.35, 0.2)
	ash.Lifetime = NumberRange.new(2, 4)
	ash.Rate = 40
	ash.Speed = NumberRange.new(0.5, 2)
	ash.Acceleration = Vector3.new(0, -1.5, 0)
	ash.Rotation = NumberRange.new(0, 360)
	ash.RotSpeed = NumberRange.new(-90, 90)
	ash.SpreadAngle = Vector2.new(180, 180)
	ash.Parent = airHolder
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = U.textures.Spark
	embers.Color = ColorSequence.new(RED)
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Size = NumberSequence.new(0.3, 0)
	embers.Lifetime = NumberRange.new(1.5, 3)
	embers.Rate = 18
	embers.Speed = NumberRange.new(0.5, 2)
	embers.Acceleration = Vector3.new(0, 1.5, 0)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Parent = airHolder
	local emitters = { cloudFront, cloudLow, ash, embers }
	if groundMist then
		table.insert(emitters, groundMist)
	end
	local baseFade: { { NumberSequenceKeypoint } } = {}
	for i, emitter in emitters do
		baseFade[i] = emitter.Transparency.Keypoints
	end
	local lastFade = -1

	type Rock = { part: BasePart, from: CFrame, rise: number, spin: Vector3 }
	local rocks: { Rock } = {}
	local rockColor = if ground and ground.Instance:IsA("BasePart")
		then ground.Instance.Color
		else Color3.fromRGB(90, 88, 85)
	for i = 1, if ground then 14 else 0 do
		local angle = (i / 14) * math.pi * 2 + math.random() * 0.4
		local distance = 9 + math.random() * 20
		local size = 0.7 + math.random() * 1.6
		local from = CFrame.new(
			plan.origin.Position.X + math.cos(angle) * distance,
			floorY - size * 0.4,
			plan.origin.Position.Z + math.sin(angle) * distance
		) * U.randomAngles()
		local part = U.newPart({
			Size = Vector3.one * size,
			CFrame = from,
			Color = rockColor,
			Material = if ground then ground.Material else Enum.Material.Slate,
			Transparency = 1,
		})
		part.CastShadow = true
		table.insert(made, part)
		table.insert(rocks, { part = part, from = from, rise = 3 + math.random() * 7, spin = U.randomUnit() * 0.8 })
	end

	local function shootingStar()
		local side = plan.right * (if math.random() < 0.5 then 1 else -1)
		local from = plan.moon + side * 220 + UP * (60 + math.random() * 60)
		local to = from - side * 260 - UP * 70
		local streak = U.newPart({
			Size = Vector3.new(0.6, 0.6, 26),
			CFrame = CFrame.lookAt(from, to),
			Color = Color3.fromRGB(235, 240, 255),
			Transparency = 0.1,
		})
		U.tween(
			streak,
			0.7,
			{ CFrame = CFrame.lookAt(to, to + (to - from)), Transparency = 1 },
			Enum.EasingStyle.Linear
		)
		task.delay(0.75, streak.Destroy, streak)
	end
	task.delay(BlackMoon.Times.Perch + 0.4, shootingStar)
	task.delay(BlackMoon.Times.Close + 0.7, shootingStar)

	local stopped = false
	return {
		update = function(t: number, visible: number)
			for _, star in stars do
				local twinkle = 0.5 + 0.5 * math.sin(t * star.speed + star.phase)
				star.part.Transparency = 1 - visible * (1 - star.base - 0.35 * twinkle)
			end
			local lift =
				TweenService:GetValue(math.clamp(visible, 0, 1), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			for _, rock in rocks do
				local drift = math.sin(t * 1.3 + rock.rise) * 0.25
				rock.part.CFrame = rock.from + UP * (rock.rise * lift + drift * lift)
				rock.part.CFrame *= CFrame.Angles(rock.spin.X * t, rock.spin.Y * t, rock.spin.Z * t)
				rock.part.Transparency = if visible > 0.02 then 0 else 1
			end
			local fade = math.floor((1 - math.clamp(visible, 0, 1)) * 40 + 0.5) / 40
			if fade ~= lastFade then
				lastFade = fade
				for i, emitter in emitters do
					local points = {}
					for j, point in baseFade[i] do
						points[j] = NumberSequenceKeypoint.new(point.Time, point.Value + (1 - point.Value) * fade)
					end
					emitter.Transparency = NumberSequence.new(points)
				end
			end
			for _, emitter in emitters do
				emitter.Enabled = visible > 0.5 and not stopped
			end
		end,
		destroy = function()
			stopped = true
			for _, emitter in emitters do
				emitter.Enabled = false
				emitter:Clear()
			end
			for _, rock in rocks do
				U.tween(rock.part, 0.6, { CFrame = rock.from - UP * 1, Transparency = 1 })
			end
			task.delay(2.5, function()
				for _, instance in made do
					instance:Destroy()
				end
			end)
		end,
	}
end

local function playBlackMoon(data, character: Model, root: BasePart)
	if typeof(data.origin) ~= "CFrame" or typeof(data.victimStart) ~= "Vector3" then
		return
	end
	local T = BlackMoon.Times
	local plan = BlackMoon.Plan(data.origin, data.victimStart)
	local victim: Model? = if typeof(data.target) == "Instance" and data.target:IsA("Model") then data.target else nil
	local victimRoot = U.getRoot(victim)
	local start = os.clock()
	local mine = U.isLocal(character) or U.isLocal(victim)
	local myRoot = U.getRoot(Players.LocalPlayer.Character)
	local nearby = mine or (myRoot ~= nil and (myRoot.Position - plan.origin.Position).Magnitude < 180)
	local cutAt = plan.cut

	local function at(time: number, fn: () -> ())
		task.delay(math.max(time - (os.clock() - start), 0), function()
			if character.Parent then
				fn()
			end
		end)
	end

	local moon = buildMoon(plan.moonRadius)
	local setting = if nearby then buildNightSetting(plan) else nil
	local bind = "CloverBlackMoon" .. tostring(start)
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		RunService:UnbindFromRenderStep(bind)
		moon.destroy()
		if setting then
			setting.destroy()
		end
	end
	RunService:BindToRenderStep(bind, Enum.RenderPriority.Camera.Value + 3, function()
		local t = os.clock() - start
		if t <= T.Land then
			if root.Parent then
				root.CFrame = BlackMoon.Attacker(plan, t)
			end
			if victimRoot and victimRoot.Parent then
				victimRoot.CFrame = BlackMoon.Victim(plan, t)
			end
		end
		local visible = smoothstep((t - T.Night) / 0.6) * (1 - smoothstep((t - T.Land - 0.3) / 1.2))
		local split = TweenService:GetValue(
			math.clamp((t - T.Land) / 0.9, 0, 1),
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out
		)
		local scar = if t < T.Cut then 0 else math.min((t - T.Cut) / 0.08, 1) * (1 - smoothstep((t - T.Land) / 0.5))
		moon.update(CFrame.lookAt(plan.moon, workspace.CurrentCamera.CFrame.Position), visible, split, scar, t * 0.05)
		if setting then
			setting.update(t, visible)
		end
		if t > T.Land + 1.6 then
			finish()
		end
	end)
	task.delay(T.Land + 3, finish)

	if mine then
		Cinematic.Camera(function(t)
			if t < T.Land then
				return BlackMoon.Camera(plan, t)
			end
			local v = if victimRoot and victimRoot.Parent then victimRoot.Position else plan.apex
			return CFrame.lookAt(v + plan.right * 14 + UP * 7 - plan.forward * 4, v), 65
		end, T.Done)
	end

	local lift: ((number?) -> ())? = nil
	if nearby then
		at(T.Night, function()
			lift = Cinematic.Night(0.9)
		end)
		task.delay(T.Land + 0.3, function()
			if lift then
				lift(1.3)
			end
		end)
	end

	local moonlights: { PointLight } = {}
	local MOONLIT = { 1.1, 2 }
	for _, part in { root, victimRoot } :: { BasePart? } do
		if part then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(165, 180, 235)
			light.Brightness = 0
			light.Range = 18
			light.Shadows = false
			light.Parent = part
			table.insert(moonlights, light)
		end
	end
	task.delay(T.Night, function()
		for i, light in moonlights do
			U.tween(light, 0.6, { Brightness = MOONLIT[i] or 2 })
		end
	end)
	task.delay(T.Land, function()
		for _, light in moonlights do
			U.tween(light, 0.4, { Brightness = 0 })
			task.delay(0.45, light.Destroy, light)
		end
	end)

	task.delay(T.Land + 0.9, function()
		local visual = awakenedVisuals[character]
		if visual then
			if visual.setPose then
				visual.setPose(nil)
			end
			if visual.setPair then
				visual.setPair(false)
			end
		end
	end)

	play(character, ANIMS.MoonThrow)
	at(T.Release, function()
		if victim then
			local animation = launchedFor(victim)
			if animation then
				PoseAnimator.Play(victim, animation)
			end
		end
		local hand = character:FindFirstChild("Left Arm")
		local from = if hand and hand:IsA("BasePart")
			then (hand.CFrame * CFrame.new(0, -1, 0)).Position
			else root.Position
		U.flash(from, WHITE, 4, 0.1)
		U.flash(from, BLACK, 7, 0.2)
		U.ringBurst(CFrame.new(from), BLACK, 1, 9, 0.3, 0.35)
		task.delay(0.04, U.ringBurst, CFrame.new(from + UP), RED, 0.8, 6, 0.25, 0.2)
		local feet = feetOf(character, root)
		if U.groundBelow(root.Position, { character }) then
			U.groundCracks(feet, 7, 5, RED, 2)
			U.debris(feet, 8, 30, 0.9)
			blackSmoke(feet + UP * 0.4, 12, 3, 14)
		end
		if victimRoot then
			trailEmitter(victimRoot, {
				Texture = U.textures.Smoke,
				Color = ColorSequence.new(BLACK),
				LightEmission = 0,
				Size = NumberSequence.new(1.6, 3.2),
				Transparency = NumberSequence.new(0.25, 1),
				Lifetime = NumberRange.new(0.35, 0.6),
				Rate = 90,
				Speed = NumberRange.new(1, 3),
				SpreadAngle = Vector2.new(180, 180),
				Drag = 3,
			}, 0.55)
			trailEmitter(victimRoot, {
				Texture = U.textures.Spark,
				Color = ColorSequence.new(RED, DARK_RED),
				LightEmission = 1,
				Size = NumberSequence.new(0.35, 0),
				Lifetime = NumberRange.new(0.2, 0.4),
				Rate = 50,
				Speed = NumberRange.new(4, 10),
				SpreadAngle = Vector2.new(180, 180),
			}, 0.55)
			U.bodyTrail(victim, BLACK, 0.6)
			U.speedLines(victimRoot, (UP + Vector3.new(0.01, 0, 0)).Unit, 0.45)
		end
		if mine then
			CameraShake.Add(0.3)
		end
	end)

	at(T.Leap, function()
		play(character, ANIMS.Leap)
		local feet = feetOf(character, root)
		U.flash(feet + UP * 0.5, BLACK, 8, 0.22)
		U.shockwave(feet, RED, 2, 12, 0.3)
		U.ringBurst(CFrame.new(feet + UP * 0.15), BLACK, 1, 10, 0.32, 0.45)
		if U.groundBelow(root.Position, { character }) then
			U.debris(feet, 8, 36, 1)
			blackSmoke(feet + UP * 0.4, 14, 3.2, 16)
		end
		U.bodyTrail(character, BLACK, 0.35)
		for i = 0, 3 do
			task.delay(i * 0.05, function()
				if character.Parent then
					U.afterimage(character, if i % 2 == 0 then BLACK else DARK_RED, 0.3)
				end
			end)
		end
	end)

	local silhouette: Highlight? = nil
	at(T.Perch, function()
		play(character, ANIMS.MoonPerch)
		local outline = Instance.new("Highlight")
		outline.Adornee = character
		outline.FillColor = BLACK
		outline.FillTransparency = 0.72
		outline.OutlineColor = RIM_RED
		outline.OutlineTransparency = 0.05
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = character
		silhouette = outline
		task.delay(T.Fly - T.Perch + 0.1, outline.Destroy, outline)
		local visual = awakenedVisuals[character]
		if visual then
			if visual.setPair then
				visual.setPair(true)
			end
			if visual.setPose then
				visual.setPose("spread")
			end
			if visual.flap then
				visual.flap()
			end
		end
		if moonlights[1] then
			U.tween(moonlights[1], 0.2, { Brightness = 0 })
		end
		blackSmoke(root.Position, 14, 3.5, 7)
		redSparks(root.Position, 14, 0.8)
		for beat = 0, 4 do
			at(T.Perch + 0.15 + beat * 0.42, function()
				local back = root.Position - root.CFrame.LookVector * 1.5 + UP
				blackSmoke(back, 6, 3, 10)
				redSparks(back, 8, 0.6, -UP)
				U.ringBurst(CFrame.new(root.Position) * CFrame.Angles(rad(90), 0, 0), BLACK, 2, 8, 0.4, 0.4)
				U.light(root.Position, RED, 4, 12, 0.3)
			end)
		end
		partEmitter(root, {
			Texture = U.textures.Smoke,
			Color = ColorSequence.new(BLACK),
			LightEmission = 0,
			Size = NumberSequence.new(1.6, 3.6),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 45,
			Speed = NumberRange.new(2, 5),
			Acceleration = Vector3.new(0, 7, 0),
			SpreadAngle = Vector2.new(180, 180),
		}, T.Fly - T.Perch)
		partEmitter(root, {
			Texture = U.textures.Spark,
			Color = ColorSequence.new(RED),
			LightEmission = 1,
			Size = NumberSequence.new(0.25, 0),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 20,
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(180, 180),
		}, T.Fly - T.Perch)
	end)

	at(T.Point, function()
		swordGlow(character, RED, 0.5, 0.5)
		swordAura(character, T.Fly - T.Point, 40)
		local tip = bladePoint(character, 2.1)
		if tip then
			blackLightning(tip, 7, 4.5)
			U.light(tip, RED, 8, 16, 0.4)
			U.impactRing(tip, workspace.CurrentCamera.CFrame.Position - tip, RED, 0.5, 6, 0.35)
			U.flash(tip, RED, 4, 0.15)
		end
		U.ringBurst(CFrame.new(root.Position) * CFrame.Angles(rad(90), 0, 0), BLACK, 1, 9, 0.45, 0.3)
		blackSmoke(root.Position, 16, 4, 10)
		redSparks(root.Position, 18, 1)
		local visual = awakenedVisuals[character]
		if visual and visual.flap then
			visual.flap()
		end
		if mine then
			CameraShake.Add(0.15)
		end
	end)

	at(T.Glint, function()
		local tip = bladePoint(character, 2.1)
		if tip then
			U.glint(tip, 2.6, RED)
			task.delay(0.03, U.glint, tip, 1.4, WHITE)
			U.impactRing(tip, workspace.CurrentCamera.CFrame.Position - tip, RED, 0.3, 4, 0.25)
			U.light(tip, RED, 12, 18, 0.3)
		end
	end)

	at(T.Fly, function()
		play(character, ANIMS.MoonFlight)
		if silhouette then
			silhouette:Destroy()
			silhouette = nil
		end
		local visual = awakenedVisuals[character]
		if visual and visual.setPose then
			visual.setPose("glide")
		end
		if moonlights[1] then
			U.tween(moonlights[1], 0.15, { Brightness = MOONLIT[1] })
		end
		heavyTrail(character, 0.45)
		U.bodyTrail(character, BLACK, 0.3)
		U.speedLines(root, plan.through, 0.25)
		U.flash(plan.perch, BLACK, 10, 0.2)
		U.impactRing(plan.perch, plan.through, RED, 1, 7, 0.25)
		blackSmoke(plan.perch, 14, 3.5, 16)
		for i = 1, 5 do
			task.delay(i * 0.025, function()
				local along = plan.perch:Lerp(plan.beyond, i / 6)
				U.impactRing(along, plan.through, if i % 2 == 0 then RED else BLACK, 0.6, 6 + i, 0.3)
			end)
		end
		U.flash(plan.perch, RED, 6, 0.15)
		for i = 0, 6 do
			task.delay(i * 0.03, function()
				if character.Parent then
					U.afterimage(character, if i % 2 == 0 then BLACK else DARK_RED, 0.35)
				end
			end)
		end
	end)

	at(T.Cut, function()
		PoseAnimator.Freeze(character, 0.1)
		if victim then
			PoseAnimator.Freeze(victim, T.Land - T.Cut + 0.4)
		end
		flightStreak(plan.perch, plan.beyond)
		U.flash(cutAt, WHITE, 8, 0.1)
		U.flash(cutAt, BLACK, 12, 0.25)
		slashMark(cutAt, -0.5, 16, 0.5)
		U.burst(cutAt, {
			color = RED,
			count = 24,
			size = 0.7,
			speed = NumberRange.new(35, 70),
			lifetime = NumberRange.new(0.15, 0.4),
			streaks = true,
			spread = 30,
			direction = plan.through,
		})
		U.light(cutAt, RED, 12, 24, 0.3)
		redSparks(cutAt, 30, 1.1, plan.through)
		blackLightning(cutAt, 6, 5, 0.25)
		U.impactRing(cutAt, plan.through, WHITE, 0.4, 9, 0.25)
		task.delay(0.03, U.impactRing, cutAt, plan.through, RED, 0.5, 13, 0.3)
		if mine then
			impactFrame(1.4)
			CameraShake.Add(0.4)
		end
	end)

	at(T.Arrive, function()
		swordAura(character, T.Land - T.Arrive, 20)
		local hang = U.newPart({ Size = Vector3.new(3, 4, 3), Transparency = 1, CFrame = CFrame.new(cutAt) })
		partEmitter(hang, {
			Texture = U.textures.Spark,
			Color = ColorSequence.new(RED, DARK_RED),
			LightEmission = 1,
			Size = NumberSequence.new(0.3, 0),
			Lifetime = NumberRange.new(0.6, 1.1),
			Rate = 30,
			Speed = NumberRange.new(0.5, 2),
			Acceleration = Vector3.new(0, 1.5, 0),
			SpreadAngle = Vector2.new(180, 180),
		}, T.Land - T.Arrive)
		U.light(cutAt, RED, 3, 10, T.Land - T.Arrive)
		task.delay(T.Land - T.Arrive + 1.5, hang.Destroy, hang)
		local visual = awakenedVisuals[character]
		if visual and visual.setPose then
			visual.setPose("spread")
		end
		if mine then
			U.colorGrade({ Saturation = -0.7, Contrast = 0.25, Brightness = 0.02 }, 0.05, T.Land - T.Arrive - 0.1, 0.15)
		end
	end)

	at(T.Land, function()
		slashMark(cutAt, 0.6, 18, 0.6)
		task.delay(0.04, slashMark, cutAt, -0.5, 18, 0.6)
		U.flash(cutAt, WHITE, 6, 0.08)
		U.flash(cutAt, BLACK, 22, 0.4)
		U.flash(cutAt, RED, 14, 0.3)
		U.shockwave(cutAt, BLACK, 4, 40, 0.6, Enum.Material.Glass, 0.3)
		U.shockwave(cutAt, RED, 3, 32, 0.5)
		local toCamera = workspace.CurrentCamera.CFrame.Position - cutAt
		U.impactRing(cutAt, toCamera, BLACK, 2, 22, 0.5)
		task.delay(0.05, U.impactRing, cutAt, toCamera, RED, 1.5, 16, 0.45)
		blackLightning(cutAt, 12, 10, 0.35)
		blackSmoke(cutAt, 30, 7, 35)
		redSparks(cutAt, 40, 1.6)
		U.light(cutAt, RED, 16, 60, 0.7)
		U.popup(cutAt + UP * 5, "BLACK MOON", RED, 2.6)
		task.delay(0.08, U.shockwave, cutAt, WHITE, 2, 30, 0.45, Enum.Material.Glass, 0.6)
		U.pillar(cutAt - UP * 6, BLACK, 2.4, 22, 0.5, Enum.Material.SmoothPlastic, 0.2)
		U.pillar(cutAt - UP * 6, RED, 1.2, 26, 0.45)
		U.burst(cutAt, {
			color = RED,
			count = 30,
			size = 0.6,
			speed = NumberRange.new(30, 60),
			lifetime = NumberRange.new(0.3, 0.6),
			streaks = true,
			spread = 180,
		})
		lingerSmoke(cutAt, 2.5, 14)
		if mine then
			impactFrame(0.9)
			U.screenFlash(RED, 0.35)
			CameraShake.Add(0.8)
		end
		if victimRoot then
			local fallStart = os.clock()
			local connection
			connection = RunService.Heartbeat:Connect(function()
				if not victimRoot.Parent or os.clock() - fallStart > 1.6 then
					connection:Disconnect()
					return
				end
				local ground = U.groundBelow(victimRoot.Position, { victim :: Model })
				if ground and victimRoot.Position.Y - ground.Position.Y < 4 then
					connection:Disconnect()
					moonCrater(ground.Position)
				end
			end)
		end
	end)
end

function handlers.BlackMoon(data, character, root)
	if data.phase == "Begin" then
		playBlackMoon(data, character, root)
	else
		handlers.BlackMeteorite(data, character, root)
	end
end

VFX.Register("BlackMoonCut", function(data)
	U.highlight(data.victim, RED, 0.4)
	if data.damage and typeof(data.position) == "Vector3" then
		U.popup(data.position, string.format("%g", data.damage), RED, 1.6)
	end
end)

return {
	launchedFor = launchedFor,
}
