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
type Palette = { hit: Color3, heavy: Color3, flash: Color3 }
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

---------------------------------------------------------------------------
-- Effects (names match what the server sends)
---------------------------------------------------------------------------

function Effects.Hit(data)
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
}

-- Adds (or replaces) a named effect the server can trigger.
function VFX.Register(name: string, effect: (data: any) -> ())
	Effects[name] = effect
end

function VFX.SetPalette(kitId: string, palette: Palette)
	palettes[kitId] = palette
end

-- Plays an effect locally (used for instant feedback on your own actions).
function VFX.Play(name: string, data: any)
	local effect = Effects[name]
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
