--[[
	VFX
	Every visual effect is drawn on the client. The server only sends
	("EffectName", data), so effects cost no server performance and stay
	smooth regardless of ping. Built entirely from parts, beams, particles
	and lights using textures that ship with Roblox, so no uploads needed.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local CameraShake = require(script.Parent.CameraShake)

local TEXTURES = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

local COLORS = {
	Swing = Color3.fromRGB(255, 255, 255),
	Hit = Color3.fromRGB(255, 236, 190),
	Heavy = Color3.fromRGB(255, 120, 60),
	Block = Color3.fromRGB(110, 170, 255),
	Parry = Color3.fromRGB(120, 255, 255),
	GuardBreak = Color3.fromRGB(255, 170, 60),
	Dash = Color3.fromRGB(200, 225, 255),
	Evasive = Color3.fromRGB(235, 255, 255),
	Dust = Color3.fromRGB(150, 145, 135),
}

-- Characters can recolor their hit effects (VFX.SetPalette).
-- `cleanM1`: M1 hits only flash the victim and show damage (no sparks/rings).
type Palette = { hit: Color3, heavy: Color3, flash: Color3, cleanM1: boolean? }
local DEFAULT_PALETTE: Palette = { hit = COLORS.Hit, heavy = COLORS.Heavy, flash = Color3.new(1, 1, 1) }
local palettes: { [string]: Palette } = {}

local function paletteFor(data): Palette
	return (type(data.kit) == "string" and palettes[data.kit]) or DEFAULT_PALETTE
end

local localPlayer = Players.LocalPlayer

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFX"
fxFolder.Parent = workspace

local VFX = {}
local Effects: { [string]: (data: any) -> () } = {}

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------

local function newPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = fxFolder
	return part
end

local function tween(
	instance: Instance,
	duration: number,
	goals: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goals)
	t:Play()
	return t
end

local function randomUnit(): Vector3
	local v = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	return if v.Magnitude > 1e-3 then v.Unit else Vector3.yAxis
end

local function randomAngles(): CFrame
	return CFrame.Angles(math.random() * math.pi * 2, math.random() * math.pi * 2, math.random() * math.pi * 2)
end

local function getRoot(character: Model?): BasePart?
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isLocal(character: Model?): boolean
	return character ~= nil and character == localPlayer.Character
end

local function groundBelow(position: Vector3, ignore: { Instance }?): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { fxFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(filter, dummies)
	end
	if ignore then
		for _, instance in ignore do
			table.insert(filter, instance)
		end
	end
	params.FilterDescendantsInstances = filter
	return workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), params)
end

type BurstOptions = {
	texture: string?,
	color: Color3?,
	count: number?,
	size: number?,
	speed: NumberRange?,
	lifetime: NumberRange?,
	lightEmission: number?,
	transparency: number?,
	drag: number?,
	acceleration: Vector3?,
	spread: number?,
	streaks: boolean?,
	direction: Vector3?, -- aim the spread cone this way (default: straight up)
}

-- One-shot particle burst at a point.
local function burst(position: Vector3, options: BurstOptions)
	local cframe = if options.direction
		then CFrame.lookAt(position, position + options.direction)
		else CFrame.new(position)
	local holder = newPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = cframe })
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder

	local lifetime = options.lifetime or NumberRange.new(0.15, 0.35)
	local size = options.size or 1

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = options.texture or TEXTURES.Spark
	emitter.Color = ColorSequence.new(options.color or COLORS.Hit)
	emitter.LightEmission = options.lightEmission or 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(options.transparency or 0, 1)
	emitter.Lifetime = lifetime
	emitter.Speed = options.speed or NumberRange.new(20, 40)
	emitter.SpreadAngle = Vector2.one * (options.spread or 180)
	emitter.Drag = options.drag or 5
	emitter.Acceleration = options.acceleration or Vector3.zero
	if options.direction then
		emitter.EmissionDirection = Enum.NormalId.Front
	end
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	if options.streaks then
		-- Stretch along travel direction for speed-line sparks.
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Squash = NumberSequence.new(1.5)
	end
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(options.count or 12)

	Debris:AddItem(holder, lifetime.Max + 0.5)
end

-- Expanding glowing ball.
local function flash(position: Vector3, color: Color3, size: number, duration: number)
	local ball = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size * 0.3,
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = 0.1,
	})
	tween(ball, duration, { Size = Vector3.one * size, Transparency = 1 })
	Debris:AddItem(ball, duration + 0.05)
end

-- Ring of thin neon segments expanding outward in the cframe's XZ plane.
local function ringBurst(
	cframe: CFrame,
	color: Color3,
	startRadius: number,
	endRadius: number,
	duration: number,
	thickness: number?
)
	local segments = 16
	local width = thickness or 0.2
	for i = 1, segments do
		local spin = CFrame.Angles(0, (i / segments) * math.pi * 2, 0)
		local startLength = (2 * math.pi * startRadius / segments) * 1.15
		local endLength = (2 * math.pi * endRadius / segments) * 1.15
		local segment = newPart({
			Size = Vector3.new(startLength, width, width),
			CFrame = cframe * spin * CFrame.new(0, 0, -startRadius),
			Color = color,
			Transparency = 0.05,
		})
		tween(segment, duration, {
			Size = Vector3.new(endLength, width * 0.2, width * 0.2),
			CFrame = cframe * spin * CFrame.new(0, 0, -endRadius),
			Transparency = 1,
		})
		Debris:AddItem(segment, duration + 0.05)
	end
end

-- A ring facing along `direction`, for impacts.
local function impactRing(position: Vector3, direction: Vector3, color: Color3, startRadius, endRadius, duration)
	local cframe = CFrame.lookAt(position, position + direction) * CFrame.Angles(math.rad(90), 0, 0)
	ringBurst(cframe, color, startRadius, endRadius, duration, 0.18)
end

local function light(position: Vector3, color: Color3, brightness: number, range: number, duration: number)
	local holder = newPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(position) })
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Brightness = brightness
	pointLight.Range = range
	pointLight.Shadows = false
	pointLight.Parent = holder
	tween(pointLight, duration, { Brightness = 0 })
	Debris:AddItem(holder, duration + 0.05)
end

-- Body glow on hit.
local function highlight(character: Model?, color: Color3, duration: number)
	if not character then
		return
	end
	local h = Instance.new("Highlight")
	h.Adornee = character
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.15
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = fxFolder
	tween(h, duration, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(h, duration + 0.05)
end

-- Neon ghost copy of a character that fades out.
local function afterimage(character: Model, color: Color3, duration: number)
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
			local ghost = part:Clone()
			if ghost then
				for _, child in ghost:GetChildren() do
					if not child:IsA("DataModelMesh") then
						child:Destroy()
					end
				end
				ghost.Anchored = true
				ghost.CanCollide = false
				ghost.CanQuery = false
				ghost.CanTouch = false
				ghost.CastShadow = false
				ghost.Massless = true
				ghost.Material = Enum.Material.Neon
				ghost.Color = color
				ghost.Transparency = 0.35
				if ghost:IsA("MeshPart") then
					ghost.TextureID = ""
				end
				ghost.Parent = fxFolder
				tween(ghost, duration, { Transparency = 1 })
				Debris:AddItem(ghost, duration + 0.05)
			end
		end
	end
end

-- Wind trail streaming off a flying character.
local function bodyTrail(character: Model?, color: Color3, duration: number)
	local root = getRoot(character)
	if not root then
		return
	end
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 1.2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -1.2, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = 0.25
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.FaceCamera = true
	trail.Parent = root

	task.delay(duration, function()
		trail.Enabled = false
		task.wait(trail.Lifetime)
		trail:Destroy()
		top:Destroy()
		bottom:Destroy()
	end)
end

-- Flying shards (unanchored, local physics only).
local function shards(position: Vector3, color: Color3, count: number)
	for _ = 1, count do
		local shard = newPart({
			Size = Vector3.new(0.25, 0.6 + math.random() * 0.6, 0.08),
			CFrame = CFrame.new(position) * randomAngles(),
			Color = color,
			Material = Enum.Material.Glass,
			Transparency = 0.1,
		})
		shard.Anchored = false
		shard.AssemblyLinearVelocity = randomUnit() * (20 + math.random() * 15) + Vector3.new(0, 15, 0)
		shard.AssemblyAngularVelocity = randomUnit() * 20
		tween(shard, 0.6, { Transparency = 1, Size = shard.Size * 0.3 })
		Debris:AddItem(shard, 0.65)
	end
end

-- Rocks bursting up from the ground in a ring, plus dust.
local function groundRocks(position: Vector3, count: number, radius: number, maxSize: number)
	local ground = groundBelow(position)
	if not ground then
		return
	end
	local hitPart = ground.Instance
	local color = if hitPart:IsA("BasePart") then hitPart.Color else COLORS.Dust
	local material = ground.Material

	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.3
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + math.random() * 1.5)
		local size = maxSize * (0.5 + math.random() * 0.5)
		local resting = CFrame.new(ground.Position + offset)
			* CFrame.Angles(math.random() * 0.8, math.random() * math.pi, math.random() * 0.8)
		local rock = newPart({
			Size = Vector3.one * size,
			CFrame = resting - Vector3.new(0, size, 0),
			Color = color,
			Material = material,
		})
		rock.CastShadow = true
		tween(rock, 0.15, { CFrame = resting }, Enum.EasingStyle.Back)
		task.delay(1.6 + math.random() * 0.4, function()
			tween(
				rock,
				0.5,
				{ CFrame = resting - Vector3.new(0, size * 1.2, 0) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
		end)
		Debris:AddItem(rock, 2.6)
	end

	burst(ground.Position, {
		texture = TEXTURES.Smoke,
		color = color:Lerp(Color3.new(1, 1, 1), 0.3),
		count = 14,
		size = 4,
		speed = NumberRange.new(8, 18),
		lifetime = NumberRange.new(0.6, 1.2),
		lightEmission = 0,
		transparency = 0.4,
		drag = 3,
		spread = 80,
	})
end

-- "PERFECT", damage numbers, etc.
local function popup(position: Vector3, text: string, color: Color3, scale: number?)
	local holder = newPart({
		Size = Vector3.one * 0.2,
		Transparency = 1,
		CFrame = CFrame.new(position + Vector3.new((math.random() - 0.5) * 2, 1, (math.random() - 0.5) * 2)),
	})

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160 * (scale or 1), 48 * (scale or 1))
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = holder

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.7
	uiScale.Parent = label
	tween(uiScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)

	tween(holder, 0.9, { CFrame = holder.CFrame + Vector3.new(0, 2.5, 0) })
	task.delay(0.45, function()
		tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(holder, 0.95)
end

local function screenFlash(color: Color3, duration: number)
	local correction = Instance.new("ColorCorrectionEffect")
	correction.TintColor = color
	correction.Brightness = 0.2
	correction.Parent = workspace.CurrentCamera
	tween(correction, duration, { TintColor = Color3.new(1, 1, 1), Brightness = 0 })
	Debris:AddItem(correction, duration + 0.05)
end

-- Four-point star glint facing the camera (metal catching the light).
local function glint(position: Vector3, scale: number, color: Color3?)
	local camera = workspace.CurrentCamera
	local base = CFrame.lookAt(position, camera.CFrame.Position)
	local tint = color or Color3.fromRGB(255, 236, 190)
	for i = 0, 1 do
		local bar = newPart({
			Size = Vector3.new(0.1, 0.1, 0.04),
			CFrame = base * CFrame.Angles(0, 0, math.rad(45 + i * 90)),
			Color = tint,
		})
		tween(bar, 0.05, { Size = Vector3.new((if i == 0 then 3.4 else 2.2) * scale, 0.14 * scale, 0.04) })
		task.delay(0.05, function()
			tween(
				bar,
				0.14,
				{ Size = Vector3.new(0.2, 0.02, 0.02), Transparency = 1 },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
		end)
		Debris:AddItem(bar, 0.22)
	end
	flash(position, tint, 1.4 * scale, 0.1)
end

local SPARK_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 225)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 205, 90)),
	ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 125, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 35, 10)),
})

--[[
	Molten metal sparks, for sword clashes: hot streaks that fly out along
	`direction` and arc down under gravity, slower embers that linger, a
	glint, a flash of orange light and a puff of metal dust.
]]
local function sparks(position: Vector3, direction: Vector3, scale: number?)
	local k = scale or 1
	local aim = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.yAxis
	local holder =
		newPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.lookAt(position, position + aim) })
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder

	local streaks = Instance.new("ParticleEmitter")
	streaks.Texture = TEXTURES.Spark
	streaks.Color = SPARK_COLORS
	streaks.LightEmission = 1
	streaks.LightInfluence = 0
	streaks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.24 * k), NumberSequenceKeypoint.new(1, 0) })
	streaks.Squash = NumberSequence.new(2.5)
	streaks.Orientation = Enum.ParticleOrientation.VelocityParallel
	streaks.EmissionDirection = Enum.NormalId.Front
	streaks.SpreadAngle = Vector2.new(55, 55)
	streaks.Speed = NumberRange.new(30 * k, 62 * k)
	streaks.Acceleration = Vector3.new(0, -95, 0)
	streaks.Drag = 1.5
	streaks.Lifetime = NumberRange.new(0.25, 0.55)
	streaks.Enabled = false
	streaks.Parent = attachment
	streaks:Emit(math.floor(26 * k))

	local embers = Instance.new("ParticleEmitter")
	embers.Texture = TEXTURES.Spark
	embers.Color = SPARK_COLORS
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3 * k), NumberSequenceKeypoint.new(1, 0) })
	embers.EmissionDirection = Enum.NormalId.Front
	embers.SpreadAngle = Vector2.new(85, 85)
	embers.Speed = NumberRange.new(6 * k, 16 * k)
	embers.Acceleration = Vector3.new(0, -45, 0)
	embers.Drag = 2
	embers.Lifetime = NumberRange.new(0.5, 1)
	embers.Rotation = NumberRange.new(0, 360)
	embers.RotSpeed = NumberRange.new(-300, 300)
	embers.Enabled = false
	embers.Parent = attachment
	embers:Emit(math.floor(10 * k))

	glint(position, k)
	light(position, Color3.fromRGB(255, 160, 60), 7 * k, 12 * k, 0.22)
	burst(position, {
		texture = TEXTURES.Smoke,
		color = Color3.fromRGB(150, 140, 130),
		count = 3,
		size = 1.2 * k,
		speed = NumberRange.new(2, 5),
		lifetime = NumberRange.new(0.3, 0.6),
		lightEmission = 0,
		transparency = 0.6,
		drag = 3,
	})
	Debris:AddItem(holder, 1.2)
end

-- Thin white speed lines rushing past a moving character for `duration`.
-- Without a direction they follow the way it's actually moving (curves).
local function speedLines(root: BasePart, direction: Vector3?, duration: number, color: Color3?)
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < duration and root.Parent do
			local heading = direction or root.AssemblyLinearVelocity
			local aim = if heading.Magnitude > 1 then heading.Unit else root.CFrame.LookVector
			for _ = 1, 3 do
				local offset = randomUnit() * Vector3.new(2.6, 2.2, 2.6)
				local from = root.Position + offset + aim * 4
				local line = newPart({
					Size = Vector3.new(0.05, 0.05, 2.5 + math.random() * 2),
					CFrame = CFrame.lookAt(from, from + aim),
					Color = color or Color3.new(1, 1, 1),
					Transparency = 0.25,
				})
				tween(line, 0.16, {
					CFrame = CFrame.lookAt(from - aim * 9, from - aim * 8),
					Transparency = 1,
				}, Enum.EasingStyle.Linear)
				Debris:AddItem(line, 0.18)
			end
			task.wait(0.035)
		end
	end)
end

-- Expanding sphere shell; centered on the ground it reads as a dome.
-- ForceField material gives a shimmering wave, Glass a solid-looking shell.
local function shockwave(
	position: Vector3,
	color: Color3,
	fromSize: number,
	toSize: number,
	duration: number,
	material: Enum.Material?,
	transparency: number?
)
	local ball = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * fromSize,
		CFrame = CFrame.new(position),
		Color = color,
		Material = material or Enum.Material.ForceField,
		Transparency = transparency or 0,
	})
	tween(ball, duration, { Size = Vector3.one * toSize, Transparency = 1 }, Enum.EasingStyle.Quart)
	Debris:AddItem(ball, duration + 0.05)
end

--[[
	Jagged cracks splitting outward across the ground from `position`. Each
	crack grows segment by segment, glows `glow` inside for a moment, then
	stays dark for `duration` before fading.
]]
local function groundCracks(position: Vector3, count: number, length: number, glow: Color3?, duration: number?)
	local ground = groundBelow(position)
	if not ground then
		return
	end
	local floor = ground.Position + Vector3.new(0, 0.04, 0)
	local life = duration or 2.5
	local dark = Color3.fromRGB(14, 13, 13)

	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.7
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local point = floor + direction * (0.5 + math.random() * 0.8)
		local remaining = length * (0.6 + math.random() * 0.5)
		local width = 0.42
		local delay = 0
		while remaining > 0.3 do
			local segment = math.min(remaining, 1.1 + math.random() * 1.5)
			direction = CFrame.Angles(0, (math.random() - 0.5) * 1.1, 0):VectorToWorldSpace(direction)
			local nextPoint = point + direction * segment
			local from, to, w = point, nextPoint, width
			task.delay(delay, function()
				local look = CFrame.lookAt(from, to)
				local crack = newPart({
					Size = Vector3.new(w, 0.06, 0.05),
					CFrame = look,
					Color = dark,
					Material = Enum.Material.SmoothPlastic,
				})
				tween(crack, 0.06, {
					Size = Vector3.new(w, 0.06, segment + w * 0.5),
					CFrame = look * CFrame.new(0, 0, -segment / 2),
				}, Enum.EasingStyle.Linear)
				if glow then
					local hot = newPart({
						Size = Vector3.new(w * 0.45, 0.08, segment + w * 0.4),
						CFrame = look * CFrame.new(0, 0.01, -segment / 2),
						Color = glow,
						Transparency = 0.05,
					})
					tween(hot, 0.9, { Transparency = 1, Size = Vector3.new(0.02, 0.08, segment) })
					Debris:AddItem(hot, 0.95)
				end
				task.delay(life, function()
					tween(crack, 0.6, { Transparency = 1 })
				end)
				Debris:AddItem(crack, life + 0.65)
			end)
			point = nextPoint
			remaining -= segment
			width *= 0.72
			delay += 0.03
		end
	end
end

--[[
	Chunks of the ground blasted out of `position`: they fly out, fall,
	bounce once and settle, then sink away. Simulated here (no physics
	parts), so they never shove characters around.
]]
local function debris(position: Vector3, count: number, speed: number, size: number)
	local ground = groundBelow(position)
	local color = if ground and ground.Instance:IsA("BasePart") then ground.Instance.Color else COLORS.Dust
	local material = if ground then ground.Material else Enum.Material.Slate
	local floorY = if ground then ground.Position.Y else position.Y - 3
	local gravity = workspace.Gravity * 0.8

	local chunks = {}
	for _ = 1, count do
		local s = size * (0.35 + math.random() * 0.65)
		local angle = math.random() * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local part = newPart({
			Size = Vector3.new(s, s * (0.55 + math.random() * 0.5), s * (0.7 + math.random() * 0.4)),
			CFrame = CFrame.new(Vector3.new(position.X, floorY + s / 2, position.Z) + out * 0.8) * randomAngles(),
			Color = color,
			Material = material,
		})
		part.CastShadow = true
		table.insert(chunks, {
			part = part,
			velocity = out * speed * (0.45 + math.random() * 0.6)
				+ Vector3.new(0, speed * (0.55 + math.random() * 0.7), 0),
			spin = randomUnit() * (5 + math.random() * 10),
			bounced = false,
			resting = false,
		})
	end

	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		for _, chunk in chunks do
			if not chunk.resting then
				chunk.velocity -= Vector3.new(0, gravity * dt, 0)
				local cframe = chunk.part.CFrame
				local nextPosition = cframe.Position + chunk.velocity * dt
				local half = chunk.part.Size.Y / 2
				if chunk.velocity.Y < 0 and nextPosition.Y - half < floorY then
					nextPosition = Vector3.new(nextPosition.X, floorY + half * 0.6, nextPosition.Z)
					if chunk.bounced or chunk.velocity.Y > -20 then
						chunk.resting = true
					else
						chunk.bounced = true
						chunk.velocity =
							Vector3.new(chunk.velocity.X * 0.35, -chunk.velocity.Y * 0.28, chunk.velocity.Z * 0.35)
						chunk.spin *= 0.4
					end
				end
				local spin = chunk.spin * dt
				chunk.part.CFrame = CFrame.new(nextPosition) * cframe.Rotation * CFrame.Angles(spin.X, spin.Y, spin.Z)
			end
		end
		if os.clock() - start > 2.2 then
			connection:Disconnect()
			for _, chunk in chunks do
				local part = chunk.part
				tween(part, 0.6, { CFrame = part.CFrame - Vector3.new(0, part.Size.Y, 0), Transparency = 1 })
				Debris:AddItem(part, 0.65)
			end
		end
	end)
end

-- A column of energy shooting up out of the ground, then thinning out.
local function pillar(
	position: Vector3,
	color: Color3,
	radius: number,
	height: number,
	duration: number,
	material: Enum.Material?,
	transparency: number?
)
	-- Cylinders run along X; turn X up.
	local base = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	local column = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = base,
		Color = color,
		Material = material or Enum.Material.Neon,
		Transparency = transparency or 0.05,
	})
	local rise = duration * 0.25
	tween(column, rise, {
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = base * CFrame.new(height / 2, 0, 0),
	}, Enum.EasingStyle.Quart)
	task.delay(rise, function()
		tween(column, duration - rise, {
			Size = Vector3.new(height * 1.15, 0.1, 0.1),
			CFrame = base * CFrame.new(height * 0.58, 0, 0),
			Transparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
	Debris:AddItem(column, duration + 0.05)
end

--[[
	Ribbons spiralling around `anchor` (following it) for `duration`: they
	climb from `height` below to `height` above (negative height spirals
	down) while the radius closes in by `tighten` (0 to 1).
]]
local function spiral(
	anchor: BasePart,
	color: Color3,
	radius: number,
	height: number,
	duration: number,
	strands: number?,
	width: number?,
	tighten: number?
)
	local count = strands or 3
	local w = width or 0.45
	local glows = color.R + color.G + color.B > 0.3
	local ribbons: { BasePart } = {}
	for _ = 1, count do
		local part = newPart({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = anchor.CFrame })
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, w / 2, 0)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -w / 2, 0)
		a1.Parent = part
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(color)
		trail.LightEmission = if glows then 1 else 0
		trail.LightInfluence = 0
		trail.Lifetime = 0.22
		trail.MinLength = 0
		trail.FaceCamera = true
		trail.Transparency = NumberSequence.new(if glows then 0.15 else 0.05, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Parent = part
		table.insert(ribbons, part)
	end
	local close = tighten or 0.5
	local turns = 2.2
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) / duration
		if t >= 1 or not anchor.Parent then
			connection:Disconnect()
			for _, part in ribbons do
				for _, child in part:GetChildren() do
					if child:IsA("Trail") then
						child.Enabled = false
					end
				end
				Debris:AddItem(part, 0.3)
			end
			return
		end
		local r = radius * (1 - t * close)
		for i, part in ribbons do
			local angle = t * math.pi * 2 * turns + (i / count) * math.pi * 2
			part.CFrame = CFrame.new(
				anchor.Position + Vector3.new(math.cos(angle) * r, -height + height * 2 * t, math.sin(angle) * r)
			)
		end
	end)
end

--[[
	A jagged lightning bolt from `from` to `to`: a `color` core inside a
	wider `glow` sheath (optional), with a side branch, flickering out over
	`duration`. Dark colors use a matte core so black lightning stays black.
]]
local function lightning(
	from: Vector3,
	to: Vector3,
	color: Color3,
	glow: Color3?,
	thickness: number?,
	duration: number?,
	branch: boolean?
)
	local width = thickness or 0.16
	local life = duration or 0.2
	local offset = to - from
	local length = offset.Magnitude
	if length < 0.1 then
		return
	end
	local segments = math.clamp(math.floor(length / 1.1), 3, 12)
	local points = { from }
	for i = 1, segments - 1 do
		table.insert(points, from + offset * (i / segments) + randomUnit() * length * 0.09)
	end
	table.insert(points, to)

	local matte = color.R + color.G + color.B < 0.3
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local segment = (b - a).Magnitude
		local cframe = CFrame.lookAt((a + b) / 2, b)
		local core = newPart({
			Size = Vector3.new(width, width, segment + width),
			CFrame = cframe,
			Color = color,
			Material = if matte then Enum.Material.SmoothPlastic else Enum.Material.Neon,
		})
		tween(
			core,
			life,
			{ Transparency = 1, Size = Vector3.new(width * 0.3, width * 0.3, segment) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		Debris:AddItem(core, life + 0.05)
		if glow then
			local sheath = newPart({
				Size = Vector3.new(width * 3.2, width * 3.2, segment + width * 2),
				CFrame = cframe,
				Color = glow,
				Transparency = 0.55,
			})
			tween(sheath, life * 0.8, { Transparency = 1, Size = Vector3.new(width, width, segment) })
			Debris:AddItem(sheath, life + 0.05)
		end
	end

	if branch ~= false and length > 3 and #points > 3 then
		local fork = points[math.random(2, #points - 2)]
		local direction = (offset.Unit + randomUnit() * 1.2).Unit
		lightning(fork, fork + direction * length * 0.4, color, glow, width * 0.7, life * 0.85, false)
	end
end

-- A full-screen color grade for the local camera: eases into `goal`
-- (ColorCorrectionEffect properties), holds, then eases back out.
local function colorGrade(goal: { [string]: any }, fadeIn: number, hold: number, fadeOut: number)
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Parent = workspace.CurrentCamera
	if fadeIn <= 0 then
		for key, value in goal do
			(correction :: any)[key] = value
		end
	else
		tween(correction, fadeIn, goal, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end
	task.delay(fadeIn + hold, function()
		tween(correction, fadeOut, {
			Brightness = 0,
			Contrast = 0,
			Saturation = 0,
			TintColor = Color3.new(1, 1, 1),
		})
	end)
	Debris:AddItem(correction, fadeIn + hold + fadeOut + 0.05)
end

---------------------------------------------------------------------------
-- Effects (names match what the server sends)
---------------------------------------------------------------------------

-- M1 hit for kits with a clean style: a quick body flash and the number.
local function cleanM1Hit(data, heavy: boolean): boolean
	local palette = paletteFor(data)
	if not palette.cleanM1 or data.variant == nil then
		return false
	end
	highlight(data.victim, Color3.new(1, 1, 1), if heavy then 0.18 else 0.1)
	if data.damage then
		popup(data.position, string.format("%g", data.damage), Color3.new(1, 1, 1), if heavy then 1.2 else 1)
	end
	-- Finishers get a touch of motion: a small burst in the launch direction.
	local victimRoot = getRoot(data.victim)
	if victimRoot and (data.variant == "Uppercut" or data.variant == "Downslam") then
		local up = data.variant == "Uppercut"
		local direction = if up then Vector3.yAxis else -Vector3.yAxis
		burst(victimRoot.Position, {
			color = Color3.new(1, 1, 1),
			count = 6,
			size = 0.45,
			speed = NumberRange.new(18, 30),
			lifetime = NumberRange.new(0.12, 0.22),
			streaks = true,
			spread = 22,
			direction = direction,
		})
		ringBurst(CFrame.new(victimRoot.Position - direction * 1.2), Color3.new(1, 1, 1), 0.6, 2.4, 0.18, 0.08)
		bodyTrail(data.victim, Color3.new(1, 1, 1), if up then 0.45 else 0.3)
	end
	if heavy and (isLocal(data.attacker) or isLocal(data.victim)) then
		CameraShake.FovKick(4)
	end
	return true
end

function Effects.Hit(data)
	if cleanM1Hit(data, false) then
		return
	end
	local position: Vector3 = data.position
	local direction: Vector3 = data.direction or Vector3.zAxis
	local palette = paletteFor(data)

	burst(position, {
		color = palette.hit,
		count = 10,
		size = 0.9,
		speed = NumberRange.new(20, 38),
		streaks = true,
	})
	flash(position, palette.flash, 3.2, 0.12)
	impactRing(position, direction, palette.flash, 0.5, 2.8, 0.18)
	light(position, palette.hit, 4, 10, 0.15)
	highlight(data.victim, Color3.new(1, 1, 1), 0.15)
	if data.damage then
		popup(position, string.format("%g", data.damage), Color3.new(1, 1, 1))
	end
end

function Effects.HeavyHit(data)
	if cleanM1Hit(data, true) then
		return
	end
	local position: Vector3 = data.position
	local direction: Vector3 = data.direction or Vector3.zAxis
	local palette = paletteFor(data)

	burst(position, {
		color = palette.heavy,
		count = 22,
		size = 1.4,
		speed = NumberRange.new(30, 60),
		lifetime = NumberRange.new(0.2, 0.45),
		streaks = true,
	})
	burst(position, {
		color = Color3.new(1, 1, 1),
		count = 8,
		size = 2,
		speed = NumberRange.new(5, 12),
	})
	flash(position, palette.flash, 6.5, 0.18)
	impactRing(position, direction, palette.heavy, 0.8, 5.5, 0.25)
	task.delay(0.06, impactRing, position, direction, palette.flash, 0.5, 4, 0.22)
	light(position, palette.heavy, 8, 18, 0.3)
	highlight(data.victim, palette.heavy, 0.25)
	if data.damage then
		popup(position, string.format("%g", data.damage), palette.heavy, 1.3)
	end

	if data.variant == "Knockback" or data.variant == "Uppercut" or data.variant == nil then
		bodyTrail(data.victim, Color3.new(1, 1, 1), 0.6)
	end
	if isLocal(data.attacker) or isLocal(data.victim) then
		CameraShake.FovKick(8)
	end
end

function Effects.Block(data)
	local position: Vector3 = data.position
	local root = getRoot(data.victim)

	burst(position, {
		color = COLORS.Block,
		count = 8,
		size = 0.7,
		speed = NumberRange.new(12, 25),
	})
	if root then
		local shield = newPart({
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.ForceField,
			Color = COLORS.Block,
			Size = Vector3.one * 5,
			CFrame = root.CFrame,
		})
		tween(shield, 0.25, { Size = Vector3.one * 6.5, Transparency = 1 })
		Debris:AddItem(shield, 0.3)
	end
	highlight(data.victim, COLORS.Block, 0.12)
end

function Effects.PerfectBlock(data)
	local position: Vector3 = data.position
	local victimRoot = getRoot(data.victim)
	local direction = if victimRoot then victimRoot.CFrame.LookVector else Vector3.zAxis

	flash(position, COLORS.Parry, 8, 0.25)
	impactRing(position, direction, COLORS.Parry, 1, 7, 0.3)
	task.delay(0.08, impactRing, position, direction, Color3.new(1, 1, 1), 0.6, 5, 0.25)
	burst(position, {
		color = COLORS.Parry,
		count = 24,
		size = 1.2,
		speed = NumberRange.new(25, 50),
		streaks = true,
	})
	light(position, COLORS.Parry, 10, 20, 0.35)
	highlight(data.victim, COLORS.Parry, 0.3)
	highlight(data.attacker, Color3.fromRGB(255, 60, 60), 0.4)
	popup(position + Vector3.new(0, 2, 0), "PERFECT", COLORS.Parry, 1.4)

	if isLocal(data.attacker) or isLocal(data.victim) then
		screenFlash(COLORS.Parry, 0.3)
		CameraShake.FovKick(-6)
	end
end

function Effects.GuardBreak(data)
	local position: Vector3 = data.position
	shards(position, COLORS.Block, 14)
	flash(position, COLORS.GuardBreak, 6, 0.2)
	burst(position, {
		color = COLORS.GuardBreak,
		count = 16,
		size = 1.1,
		speed = NumberRange.new(25, 45),
		streaks = true,
	})
	light(position, COLORS.GuardBreak, 8, 16, 0.3)
	highlight(data.victim, COLORS.GuardBreak, 0.35)
	popup(position + Vector3.new(0, 2, 0), "GUARD BREAK", COLORS.GuardBreak, 1.5)
end

function Effects.Dash(data)
	local character: Model? = data.character
	local root = getRoot(character)
	if not character or not root then
		return
	end

	afterimage(character, COLORS.Dash, 0.35)
	for i = 1, 2 do
		task.delay(i * 0.06, function()
			if character.Parent then
				afterimage(character, COLORS.Dash, 0.3)
			end
		end)
	end

	local ground = groundBelow(root.Position, { character })
	if ground then
		burst(ground.Position, {
			texture = TEXTURES.Smoke,
			color = COLORS.Dust,
			count = 6,
			size = 2.5,
			speed = NumberRange.new(4, 10),
			lifetime = NumberRange.new(0.4, 0.7),
			lightEmission = 0,
			transparency = 0.5,
			spread = 70,
		})
		ringBurst(CFrame.new(ground.Position + Vector3.new(0, 0.1, 0)), COLORS.Dash, 0.6, 3.5, 0.25, 0.12)
	end
end

function Effects.Evasive(data)
	local character: Model? = data.character
	local root = getRoot(character)
	if not character or not root then
		return
	end
	afterimage(character, COLORS.Evasive, 0.5)
	flash(root.Position, COLORS.Evasive, 7, 0.25)
	ringBurst(CFrame.new(root.Position), COLORS.Evasive, 1, 8, 0.35, 0.25)
	burst(root.Position, {
		color = COLORS.Evasive,
		count = 20,
		size = 1,
		speed = NumberRange.new(20, 40),
		streaks = true,
	})
	popup(root.Position + Vector3.new(0, 3, 0), "EVASIVE", COLORS.Evasive, 1.2)
	if isLocal(character) then
		screenFlash(COLORS.Evasive, 0.25)
	end
end

-- A ragdoll slamming into the floor or a wall.
function Effects.BodyImpact(data)
	local position: Vector3 = data.position
	local strength: number = math.clamp(tonumber(data.strength) or 0.5, 0.2, 1)
	local ground = groundBelow(position)
	local spot = if ground then ground.Position else position
	local dustColor = if ground and ground.Instance:IsA("BasePart") then ground.Instance.Color else COLORS.Dust

	burst(spot, {
		texture = TEXTURES.Smoke,
		color = dustColor:Lerp(Color3.new(1, 1, 1), 0.35),
		count = math.floor(6 + 10 * strength),
		size = 2 + 2.5 * strength,
		speed = NumberRange.new(6, 14 * strength + 6),
		lifetime = NumberRange.new(0.5, 1),
		lightEmission = 0,
		transparency = 0.35,
		drag = 3,
		spread = 75,
	})
	ringBurst(CFrame.new(spot + Vector3.new(0, 0.15, 0)), Color3.new(1, 1, 1), 0.8, 3 + 4 * strength, 0.25, 0.12)
	if strength > 0.6 and ground then
		groundRocks(spot, math.floor(4 + 6 * strength), 1.5 + 1.5 * strength, 1 + strength)
	end
end

function Effects.Crater(data)
	local position: Vector3 = data.position
	if data.small then
		-- M1 downslams: a modest dent, not a skill-sized crater.
		groundRocks(position, 6, 2, 1.1)
		ringBurst(CFrame.new(position + Vector3.new(0, 0.2, 0)), Color3.new(1, 1, 1), 0.6, 5, 0.25, 0.15)
		return
	end
	groundRocks(position, 12, 4, 2.2)
	ringBurst(CFrame.new(position + Vector3.new(0, 0.2, 0)), Color3.new(1, 1, 1), 1, 10, 0.35, 0.3)
	flash(position, COLORS.Heavy, 6, 0.2)
	light(position, COLORS.Heavy, 6, 20, 0.35)

	-- Anyone nearby feels the slam.
	local myRoot = getRoot(localPlayer.Character)
	if myRoot then
		local distance = (myRoot.Position - position).Magnitude
		if distance < 40 then
			CameraShake.Add(0.35 * (1 - distance / 40))
		end
	end
end

---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Public helpers used by the move animations
---------------------------------------------------------------------------

-- Streak behind a striking limb (fist or foot) for `duration` seconds.
function VFX.LimbTrail(character: Model, limbName: string, duration: number, color: Color3?)
	local limbPart = character:FindFirstChild(limbName)
	if not limbPart or not limbPart:IsA("BasePart") then
		return
	end
	-- Two points near the end of the limb (R6 limbs are 2 studs long).
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(0, -1.1, 0)
	tip.Parent = limbPart
	local mid = Instance.new("Attachment")
	mid.Position = Vector3.new(0, -0.3, 0)
	mid.Parent = limbPart

	local trail = Instance.new("Trail")
	trail.Attachment0 = tip
	trail.Attachment1 = mid
	trail.Color = ColorSequence.new(color or COLORS.Swing)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = 0.12
	trail.MinLength = 0
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.FaceCamera = true
	trail.Parent = limbPart

	task.delay(duration, function()
		trail.Enabled = false
		task.wait(trail.Lifetime)
		trail:Destroy()
		tip:Destroy()
		mid:Destroy()
	end)
end

-- Burst of displaced air in front of a punch or kick.
function VFX.AirPop(character: Model, heavy: boolean)
	local root = getRoot(character)
	if not root then
		return
	end
	local look = root.CFrame.LookVector
	local position = root.Position + look * (if heavy then 3.5 else 3) + Vector3.new(0, 0.5, 0)
	impactRing(position, look, COLORS.Swing, 0.3, if heavy then 3.2 else 1.8, if heavy then 0.2 else 0.14)
	burst(position, {
		color = COLORS.Swing,
		count = if heavy then 8 else 4,
		size = 0.5,
		speed = NumberRange.new(10, 20),
		lifetime = NumberRange.new(0.1, 0.2),
		streaks = true,
		spread = 35,
		direction = look,
	})
	if heavy then
		flash(position, COLORS.Swing, 2.5, 0.1)
	end
end

-- Building blocks for character kits (Client/Kits/*).
VFX.Util = {
	folder = fxFolder,
	textures = TEXTURES,
	newPart = newPart,
	tween = tween,
	randomUnit = randomUnit,
	randomAngles = randomAngles,
	getRoot = getRoot,
	isLocal = isLocal,
	groundBelow = groundBelow,
	burst = burst,
	flash = flash,
	ringBurst = ringBurst,
	impactRing = impactRing,
	light = light,
	highlight = highlight,
	afterimage = afterimage,
	bodyTrail = bodyTrail,
	shards = shards,
	groundRocks = groundRocks,
	popup = popup,
	screenFlash = screenFlash,
	glint = glint,
	sparks = sparks,
	speedLines = speedLines,
	shockwave = shockwave,
	groundCracks = groundCracks,
	debris = debris,
	pillar = pillar,
	spiral = spiral,
	lightning = lightning,
	colorGrade = colorGrade,
}

-- Adds (or replaces) a named effect the server can trigger.
function VFX.Register(name: string, effect: (data: any) -> ())
	Effects[name] = effect
end

-- A character-specific version of an effect (e.g. Asta's own dash). Used
-- when data.character is playing that kit.
local kitEffects: { [string]: { [string]: (data: any) -> () } } = {}
function VFX.RegisterKitEffect(kitId: string, name: string, effect: (data: any) -> ())
	kitEffects[kitId] = kitEffects[kitId] or {}
	kitEffects[kitId][name] = effect
end

function VFX.SetPalette(kitId: string, palette: Palette)
	palettes[kitId] = palette
end

-- Plays an effect locally (used for instant feedback on your own actions).
-- The kit whose version of `name` should play: the attacker's (data.kit),
-- then the acting character's, then the defender's (data.victimKit), so a
-- block against Asta's sword, or by it, makes sword sparks.
local function overrideFor(name: string, data: any): ((data: any) -> ())?
	if type(data) ~= "table" then
		return nil
	end
	local candidates = { data.kit }
	if typeof(data.character) == "Instance" then
		table.insert(candidates, data.character:GetAttribute("Kit"))
	end
	table.insert(candidates, data.victimKit)
	for _, kitId in candidates do
		local overrides = if type(kitId) == "string" then kitEffects[kitId] else nil
		if overrides and overrides[name] then
			return overrides[name]
		end
	end
	return nil
end

-- Plays the built-in version of an effect, ignoring kit overrides (lets an
-- override add to the default instead of replacing it).
function VFX.PlayDefault(name: string, data: any)
	local effect = Effects[name]
	if effect then
		task.spawn(effect, data)
	end
end

function VFX.Play(name: string, data: any)
	local effect = overrideFor(name, data) or Effects[name]
	if effect then
		task.spawn(effect, data)
	end
end

function VFX.Start()
	Remotes.VFX.OnClientEvent:Connect(function(name, data)
		if type(name) == "string" and type(data) == "table" then
			VFX.Play(name, data)
		end
	end)
end

return VFX
