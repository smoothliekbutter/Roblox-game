local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local Soft = require(script.Parent.Parent.Parent.Soft)
local VFX = require(script.Parent.Parent.Parent.VFX)

local U = VFX.Util

type Animation = PoseAnimator.Animation

local rad = math.rad

local BLACK = Color3.fromRGB(8, 8, 10)
local RED = Color3.fromRGB(200, 25, 35)
local DARK_RED = Color3.fromRGB(110, 8, 18)
local RIM_RED = Color3.fromRGB(235, 40, 50)
local WHITE = Color3.new(1, 1, 1)

local UP = Vector3.yAxis

local function rot(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

local GRIP = CFrame.Angles(rad(215), 0, 0)
local BLADE_REST = GRIP:VectorToWorldSpace(Vector3.yAxis)

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

local Generated = require(script.Parent.Animations)
local ANIMS: { [string]: Animation } = {}
for name, raw in Generated do
	ANIMS[name] = build(raw)
end

local function getSword(character: Model): Model?
	return character:FindFirstChild("KitWeapon") :: Model?
end

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

local function blackLightning(position: Vector3, count: number, radius: number, life: number?)
	for _ = 1, count do
		local from = position + U.randomUnit() * radius * 0.2
		U.lightning(from, position + U.randomUnit() * radius, BLACK, RED, 0.1 + radius * 0.012, life or 0.2)
	end
end

local function play(character: Model, animation: Animation, onEvent: ((string) -> ())?)
	PoseAnimator.Play(character, animation, onEvent)
end

local WAVE_POINTS = 12

local function slashWave(data)
	local origin: Vector3 = data.origin
	local direction: Vector3 = data.direction
	local speed: number = data.speed or 130
	local range: number = data.range or 90
	local width: number = data.width or 9
	local grand = data.grand == true
	local scale = width / 9

	local frame = CFrame.lookAt(origin, origin + direction)
	local holder = U.newPart({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = frame })
	local tilt = CFrame.Angles(0, 0, if grand then 0 else rad(25))
	local bulge = width * 0.32

	local function ring(lead: number): { Attachment }
		local list = {}
		for i = 0, WAVE_POINTS do
			local theta = -math.pi / 2 + math.pi * i / WAVE_POINTS
			local a = Instance.new("Attachment")
			a.Position =
				tilt:PointToWorldSpace(Vector3.new(math.sin(theta) * width / 2, 0, -math.cos(theta) * (bulge + lead)))
			a.Parent = holder
			list[i] = a
		end
		return list
	end
	local body = ring(0)
	local front = ring(width * 0.06)
	local function profile(i: number): number
		return math.sin(math.pi * i / WAVE_POINTS) ^ 0.8
	end
	local function layer(
		points: { Attachment },
		color: Color3,
		emission: number,
		thickness: number,
		transparency: number,
		z: number
	)
		for i = 0, WAVE_POINTS - 1 do
			local b = Instance.new("Beam")
			b.Attachment0 = points[i]
			b.Attachment1 = points[i + 1]
			b.FaceCamera = true
			b.Segments = 2
			b.Color = ColorSequence.new(color)
			b.LightEmission = emission
			b.LightInfluence = 0
			b.ZOffset = z
			b.Width0 = thickness * profile(i)
			b.Width1 = thickness * profile(i + 1)
			b.Transparency = NumberSequence.new(transparency)
			b.Parent = holder
		end
	end
	layer(body, RED, 1, 2.6 * scale, 0.3, 0)
	layer(body, BLACK, 0, 1.7 * scale, 0, 0.05)
	layer(front, Color3.fromRGB(255, 190, 190), 1, 0.35 * scale, 0.1, 0.1)

	local glow = Instance.new("PointLight")
	glow.Color = RED
	glow.Brightness = 4
	glow.Range = 10 * scale + 4
	glow.Shadows = false
	glow.Parent = holder

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = U.textures.Smoke
	smoke.Color = ColorSequence.new(BLACK)
	smoke.LightEmission = 0
	smoke.LightInfluence = 0
	smoke.Size = NumberSequence.new(2.4 * scale, 0.5)
	smoke.Transparency = NumberSequence.new(0.2, 1)
	smoke.Lifetime = NumberRange.new(0.3, 0.6)
	smoke.Rate = 80
	smoke.Speed = NumberRange.new(2, 6)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Parent = holder
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = U.textures.Spark
	embers.Color = ColorSequence.new(RED, DARK_RED)
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Size = NumberSequence.new(0.35 * scale + 0.1, 0)
	embers.Lifetime = NumberRange.new(0.2, 0.45)
	embers.Rate = 60
	embers.Speed = NumberRange.new(6, 14)
	embers.SpreadAngle = Vector2.new(60, 60)
	embers.EmissionDirection = Enum.NormalId.Back
	embers.Orientation = Enum.ParticleOrientation.VelocityParallel
	embers.Squash = NumberSequence.new(1.4)
	embers.Parent = holder

	local lastGroove = origin
	local nextDust = 0

	local travelled = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		travelled += speed * dt
		holder.CFrame = frame + direction * travelled
		local here = holder.Position
		if (here - lastGroove).Magnitude > 3 then
			local floorA = U.groundBelow(lastGroove)
			local floorB = U.groundBelow(here)
			lastGroove = here
			if floorA and floorB and here.Y - floorB.Position.Y < 4.5 then
				local a = floorA.Position + UP * 0.05
				local b = floorB.Position + UP * 0.05
				local length = (b - a).Magnitude
				local look = CFrame.lookAt((a + b) / 2, b)
				local groove = U.newPart({
					Size = Vector3.new(0.9 * scale + 0.4, 0.06, length + 0.3),
					CFrame = look,
					Color = Color3.fromRGB(14, 13, 13),
					Material = Enum.Material.SmoothPlastic,
				})
				local hot = U.newPart({
					Size = Vector3.new(0.35 * scale + 0.15, 0.08, length + 0.3),
					CFrame = look + Vector3.new(0, 0.01, 0),
					Color = RED,
				})
				U.tween(hot, 0.8, { Transparency = 1, Size = Vector3.new(0.05, 0.08, length) })
				task.delay(1.6, function()
					U.tween(groove, 0.6, { Transparency = 1 })
				end)
				task.delay(2.3, function()
					groove:Destroy()
					hot:Destroy()
				end)
				if travelled >= nextDust then
					nextDust = travelled + (if grand then 6 else 9)
					U.burst(b, {
						texture = U.textures.Smoke,
						color = Color3.fromRGB(150, 140, 130),
						count = if grand then 5 else 3,
						size = 2.5 * scale + 1,
						speed = NumberRange.new(4, 10),
						lifetime = NumberRange.new(0.4, 0.8),
						lightEmission = 0,
						transparency = 0.5,
						drag = 3,
						spread = 60,
					})
					if grand then
						U.groundRocks(b, 4, 2, 1.3)
					end
				end
			end
		end
		if travelled >= range then
			connection:Disconnect()
			smoke.Enabled = false
			embers.Enabled = false
			glow:Destroy()
			blackSmoke(here, if grand then 16 else 8, 3 * scale, 10)
			U.flash(here, BLACK, 4 * scale + 2, 0.2)
			redSparks(here, if grand then 16 else 8, 0.8)
			for _, child in holder:GetChildren() do
				if child:IsA("Attachment") or child:IsA("Beam") then
					child:Destroy()
				end
			end
			task.delay(0.7, holder.Destroy, holder)
		end
	end)
end

local handlers: { [string]: (data: any, character: Model, root: BasePart) -> () } = {}

local function bladeOf(character: Model): BasePart?
	local sword = getSword(character)
	local blade = sword and sword:FindFirstChild("Blade")
	return if blade and blade:IsA("BasePart") then blade else nil
end

local function bladeY(blade: BasePart, along: number): number
	local guard, tip = blade:GetAttribute("GuardY"), blade:GetAttribute("TipY")
	if type(guard) == "number" and type(tip) == "number" then
		return guard + (along + 1.8) / 3.9 * (tip - guard)
	end
	return along * blade.Size.Y / 3.6
end

local function alongBlade(blade: BasePart, along: number): CFrame
	return blade.CFrame * CFrame.new(0, bladeY(blade, along), 0)
end

local function bladePoint(character: Model, along: number): Vector3?
	local blade = bladeOf(character)
	return if blade then alongBlade(blade, along).Position else nil
end

local function heavyTrail(character: Model, duration: number)
	local blade = bladeOf(character)
	if not blade then
		return
	end
	local made: { Instance } = {}
	local function attachment(y: number): Attachment
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, bladeY(blade, y), 0)
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

export type CrescentOptions = {
	center: CFrame?,
	radius: number,
	from: number,
	to: number,
	tilt: number?,
	width: number,
	sweep: number?,
	fade: number?,
	glow: number?,
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
	local shine = options.glow or 0
	for i = 0, n - 1 do
		local list: { Layer } = {}
		local glow = layer(inner[i], inner[i + 1], RED, 1, 0, 0)
		local core = layer(inner[i], inner[i + 1], BLACK, 0, 0, 0.05)
		local edge = layer(outer[i], outer[i + 1], Color3.fromRGB(255, 170, 170), 1, 0, 0.1)
		table.insert(list, { beam = glow, width = w * 1.6, base = 0.3 })
		table.insert(list, { beam = core, width = w, base = 0 })
		table.insert(list, { beam = edge, width = w * 0.16, base = 0.1 })
		if shine > 0 then
			local aura = layer(inner[i], inner[i + 1], RED, 1, 0, -0.05)
			local hot = layer(outer[i], outer[i + 1], Color3.fromRGB(255, 228, 228), 1, 0, 0.15)
			table.insert(list, { beam = aura, width = w * 2.8 * shine, base = 0.62 })
			table.insert(list, { beam = hot, width = w * 0.07 * (1 + shine), base = 0 })
		end
		segments[i + 1] = list
	end

	local sweep = options.sweep or 0.08
	local fade = options.fade or 0.25
	local hold = 0.04
	local start = os.clock()
	local wisped = false
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
		if not wisped and t > sweep + hold then
			wisped = true
			for _, i in { math.floor(n * 0.3), math.floor(n * 0.6), n } do
				local point = inner[i].WorldPosition
				U.burst(point, {
					texture = U.textures.Smoke,
					color = BLACK,
					count = 2,
					size = options.width * 0.9,
					speed = NumberRange.new(1, 3),
					lifetime = NumberRange.new(0.3, 0.5),
					lightEmission = 0,
					transparency = 0.35,
					drag = 3,
				})
			end
		end
		if t > sweep + hold + fade then
			connection:Disconnect()
			holder:Destroy()
		end
	end)
end

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

local function impactFrame(strength: number?)
	local k = strength or 1
	U.colorGrade({ Brightness = 0.25 * k, Contrast = 0.85 * k, Saturation = -1 }, 0, 0.06, 0.22)
end

local function involves(data, character: Model): boolean
	return U.isLocal(character) or U.isLocal(data.target)
end

local castTokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local function bump(character: Model): number
	local token = (castTokens[character] or 0) + 1
	castTokens[character] = token
	return token
end
local function live(character: Model, token: number): boolean
	return castTokens[character] == token and character.Parent ~= nil
end

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

local function trailEmitter(part: BasePart, props: { [string]: any }, duration: number): ParticleEmitter
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
	return emitter
end

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

local function markAngle(position: Vector3, direction: Vector3): number
	local facing = CFrame.lookAt(position, workspace.CurrentCamera.CFrame.Position)
	local along = facing:VectorToObjectSpace(direction)
	return math.atan2(along.Y, along.X)
end

local function feetOf(character: Model, root: BasePart): Vector3
	local ground = U.groundBelow(root.Position, { character })
	return if ground then ground.Position else root.Position - UP * 3
end

local HOT = Color3.fromRGB(255, 110, 110)
local WHITE_HOT = Color3.fromRGB(255, 225, 225)

local function edgeGlow(character: Model, duration: number, strength: number?)
	local blade = bladeOf(character)
	if not blade then
		return
	end
	local k = strength or 1
	local half = blade.Size.Z / 2
	local top = blade.Size.Y / 2
	local guard = bladeY(blade, -1.8)
	local pointY = blade:GetAttribute("PointY")
	local point = if type(pointY) == "number" then pointY else top + 0.6
	local made: { Instance } = {}
	local function at(y: number, z: number): Attachment
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, y, z)
		a.Parent = blade
		table.insert(made, a)
		return a
	end
	local apex = at(point, 0)
	local beams: { Beam } = {}
	for _, side in { -1, 1 } do
		local base, shoulder = at(guard, side * half), at(top, side * half)
		for _, pair in { { base, shoulder }, { shoulder, apex } } do
			for layer = 1, 2 do
				local beam = Instance.new("Beam")
				beam.Attachment0 = pair[1]
				beam.Attachment1 = pair[2]
				beam.FaceCamera = true
				beam.Segments = 1
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Color = ColorSequence.new(if layer == 1 then RED else HOT)
				local width = (if layer == 1 then 0.6 else 0.16) * k
				beam.Width0 = width
				beam.Width1 = width
				beam.Transparency = NumberSequence.new(1)
				beam.Parent = blade
				table.insert(beams, beam)
				table.insert(made, beam)
			end
		end
	end
	local glow = Instance.new("PointLight")
	glow.Color = RED
	glow.Range = 10
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = blade
	table.insert(made, glow)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local a = if t < 0.06 then t / 0.06 elseif t < duration then 1 else 1 - (t - duration) / 0.25
		if a <= 0 or not blade.Parent then
			connection:Disconnect()
			for _, instance in made do
				instance:Destroy()
			end
			return
		end
		local flicker = 0.88 + 0.12 * math.sin(t * 38)
		for i, beam in beams do
			local base = if i % 2 == 1 then 0.4 else 0.05
			beam.Transparency = NumberSequence.new(1 - (1 - base) * a * flicker)
		end
		glow.Brightness = 3 * k * a
	end)
end

local function glowBurst(position: Vector3, size: number, duration: number?)
	local life = duration or 0.3
	local halo = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size * 0.4,
		CFrame = CFrame.new(position),
		Color = RED,
		Transparency = 0.3,
	})
	local core = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size * 0.16,
		CFrame = CFrame.new(position),
		Color = WHITE_HOT,
	})
	U.tween(halo, life, { Size = Vector3.one * size * 1.4, Transparency = 1 })
	U.tween(core, life * 0.6, { Size = Vector3.one * size * 0.45, Transparency = 1 })
	task.delay(life + 0.05, function()
		halo:Destroy()
		core:Destroy()
	end)
	U.burst(position, {
		color = HOT,
		count = math.floor(6 + size * 2),
		size = 0.45,
		speed = NumberRange.new(10, 26),
		lifetime = NumberRange.new(0.15, 0.35),
		streaks = true,
		spread = 180,
	})
	U.light(position, RED, 8, size * 4, life * 1.5)
	local toEye = workspace.CurrentCamera.CFrame.Position - position
	if toEye.Magnitude > 1 then
		Soft.lightRing(position, toEye.Unit, size * 0.3, size * 1.5, life * 0.8, RED)
	end
end

local bloomSwells = 0
local bloomBase: { Intensity: number, Threshold: number }? = nil
local function bloomPulse(position: Vector3, strength: number, duration: number)
	if (workspace.CurrentCamera.CFrame.Position - position).Magnitude > 140 then
		return
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		return
	end
	bloomBase = bloomBase or { Intensity = bloom.Intensity, Threshold = bloom.Threshold }
	local base = bloomBase :: { Intensity: number, Threshold: number }
	bloomSwells += 1
	U.tween(bloom, 0.06, {
		Intensity = base.Intensity + 0.7 * strength,
		Threshold = math.max(base.Threshold - 0.5 * strength, 0.8),
	})
	task.delay(duration, function()
		bloomSwells -= 1
		if bloomSwells == 0 then
			U.tween(bloom, 0.35, { Intensity = base.Intensity, Threshold = base.Threshold })
		end
	end)
end

local function meteorTail(root: BasePart, duration: number, alive: (() -> boolean)?)
	local smoke = trailEmitter(root, {
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
	local sparks = trailEmitter(root, {
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
	if alive then
		local start = os.clock()
		task.spawn(function()
			while os.clock() - start < duration and alive() do
				task.wait()
			end
			smoke.Enabled = false
			sparks.Enabled = false
		end)
	end
	for i = 0, math.floor(duration / 0.06) do
		task.delay(i * 0.06, function()
			if root.Parent and (not alive or alive()) then
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

return {
	BLACK = BLACK,
	RED = RED,
	DARK_RED = DARK_RED,
	RIM_RED = RIM_RED,
	WHITE = WHITE,
	UP = UP,
	rot = rot,
	ANIMS = ANIMS,
	getSword = getSword,
	swordTrail = swordTrail,
	swordGlow = swordGlow,
	blackSmoke = blackSmoke,
	redSparks = redSparks,
	blackLightning = blackLightning,
	play = play,
	slashWave = slashWave,
	handlers = handlers,
	bladeOf = bladeOf,
	alongBlade = alongBlade,
	bladePoint = bladePoint,
	heavyTrail = heavyTrail,
	partEmitter = partEmitter,
	swordAura = swordAura,
	crescent = crescent,
	inflow = inflow,
	crackle = crackle,
	impactFrame = impactFrame,
	involves = involves,
	bump = bump,
	live = live,
	lingerSmoke = lingerSmoke,
	trailEmitter = trailEmitter,
	slashMark = slashMark,
	markAngle = markAngle,
	feetOf = feetOf,
	HOT = HOT,
	WHITE_HOT = WHITE_HOT,
	edgeGlow = edgeGlow,
	glowBurst = glowBurst,
	bloomPulse = bloomPulse,
	meteorTail = meteorTail,
}
