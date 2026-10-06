local RunService = game:GetService("RunService")

local VFX = require(script.Parent.VFX)

local U = VFX.Util
local rad = math.rad
local UP = Vector3.yAxis
local TERRAIN = workspace.Terrain

local Soft = {}
Soft.U = U

Soft.WIND = Color3.fromRGB(120, 235, 175)
Soft.WIND_DEEP = Color3.fromRGB(35, 170, 110)
Soft.WIND_WHITE = Color3.fromRGB(228, 255, 240)
Soft.STAR = Color3.fromRGB(255, 226, 130)
Soft.STAR_WHITE = Color3.fromRGB(255, 250, 228)
Soft.STAR_FIRE = Color3.fromRGB(255, 140, 40)

Soft.SMOKE = U.textures.Smoke
Soft.SPARKLE = U.textures.Spark

local sheers: { number } = {}
local function sheerness(): number
	local k = 0
	for _, value in sheers do
		k = math.max(k, value)
	end
	return k
end
function Soft.sheer(k: number): () -> ()
	table.insert(sheers, k)
	local released = false
	return function()
		if not released then
			released = true
			local i = table.find(sheers, k)
			if i then
				table.remove(sheers, i)
			end
		end
	end
end
local function sheerValue(transparency: number): number
	local k = sheerness()
	return if k > 0 then 1 - (1 - transparency) * (1 - k) else transparency
end
local function sheerSequence(sequence: NumberSequence): NumberSequence
	local k = sheerness()
	if k <= 0 then
		return sequence
	end
	local points = {}
	for _, point in sequence.Keypoints do
		table.insert(
			points,
			NumberSequenceKeypoint.new(point.Time, 1 - (1 - point.Value) * (1 - k), point.Envelope * (1 - k))
		)
	end
	return NumberSequence.new(points)
end
Soft.sheerValue = sheerValue

local WIND, WIND_DEEP, WIND_WHITE = Soft.WIND, Soft.WIND_DEEP, Soft.WIND_WHITE
local STAR, STAR_WHITE = Soft.STAR, Soft.STAR_WHITE
local SMOKE, SPARKLE = Soft.SMOKE, Soft.SPARKLE

local KAPPA = 0.5523

function Soft.every(duration: number, step: (number, number) -> boolean?, finish: (() -> ())?)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local elapsed = os.clock() - start
		if elapsed >= duration or step(elapsed, dt) == false then
			connection:Disconnect()
			if finish then
				finish()
			end
		end
	end)
end
local every = Soft.every

function Soft.fadeOut(parts: { BasePart }, duration: number)
	for _, part in parts do
		U.tween(part, duration, { Transparency = 1 })
	end
	task.delay(duration + 0.05, function()
		for _, part in parts do
			part:Destroy()
		end
	end)
end
local fadeOut = Soft.fadeOut

function Soft.key(time: number, value: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(time, value)
end
local key = Soft.key

function Soft.quadratic(a: Vector3, b: Vector3, c: Vector3, s: number): Vector3
	return a * ((1 - s) * (1 - s)) + b * (2 * s * (1 - s)) + c * (s * s)
end
local quadratic = Soft.quadratic

function Soft.bar(from: Vector3, to: Vector3, width: number, color: Color3, transparency: number): BasePart
	if (to - from).Magnitude < 1e-3 then
		to = from + UP * 0.05
	end
	local length = math.max((to - from).Magnitude, 0.05)
	return U.newPart({
		Size = Vector3.new(width, width, length),
		CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to),
		Color = color,
		Transparency = sheerValue(transparency),
	})
end
local bar = Soft.bar

function Soft.tube(from: Vector3, to: Vector3, width: number, color: Color3, transparency: number): BasePart
	if (to - from).Magnitude < 1e-3 then
		to = from + UP * 0.05
	end
	local length = math.max((to - from).Magnitude, 0.05)
	return U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, width, width),
		CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to) * CFrame.Angles(0, rad(90), 0),
		Color = color,
		Transparency = sheerValue(transparency),
	})
end

function Soft.stretch(line: BasePart, from: Vector3, to: Vector3)
	line.Size = Vector3.new(line.Size.X, line.Size.Y, (to - from).Magnitude + 0.05)
	line.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
end

function Soft.newWedge(props: { [string]: any }): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.CanQuery = false
	wedge.CanTouch = false
	wedge.CastShadow = false
	wedge.Material = Enum.Material.Neon
	for name, value in props do
		(wedge :: any)[name] = value
	end
	wedge.Transparency = sheerValue(wedge.Transparency)
	wedge.Parent = U.folder
	return wedge
end

function Soft.inflow(target: Vector3, radius: number, color: Color3?)
	local from = target + U.randomUnit() * radius
	local wisp = bar(from, from + (target - from).Unit * 1.2, 0.08, color or WIND_WHITE, 0.3)
	U.tween(wisp, 0.22, { CFrame = CFrame.lookAt(target, target + (target - from).Unit), Transparency = 1 })
	task.delay(0.25, wisp.Destroy, wisp)
end

function Soft.gust(position: Vector3, size: number, direction: Vector3?)
	U.burst(position, {
		color = WIND_WHITE,
		count = math.floor(8 + size * 3),
		size = 0.3 + size * 0.06,
		speed = NumberRange.new(14 + size * 4, 28 + size * 8),
		lifetime = NumberRange.new(0.15, 0.35),
		streaks = true,
		spread = if direction then 40 else 180,
		direction = direction,
	})
	U.ringBurst(CFrame.new(position), WIND, size * 0.2, size, 0.3, 0.12)
	U.light(position, WIND, 3, size * 2.5, 0.25)
end

export type Star = { place: (Vector3, number) -> (), fade: (number) -> (), parts: { BasePart } }

function Soft.makeStar(size: number, color: Color3?): Star
	local tint = color or STAR
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local function add(part: BasePart, offset: CFrame)
		table.insert(parts, part)
		table.insert(offsets, offset)
	end
	add(
		U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.32, Color = STAR_WHITE }),
		CFrame.identity
	)
	for i = 0, 3 do
		local long = i % 2 == 0
		add(
			U.newPart({
				Size = Vector3.new(size * 0.07, size * (if long then 1.15 else 0.55), size * 0.07),
				Color = tint,
				Transparency = 0.05,
			}),
			CFrame.Angles(0, 0, i * math.pi / 4)
		)
	end
	add(
		U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.95, Color = tint, Transparency = 0.82 }),
		CFrame.identity
	)
	for _, part in parts do
		part.Transparency = sheerValue(part.Transparency)
	end
	local light = Instance.new("PointLight")
	light.Color = tint
	light.Range = size * 6
	light.Brightness = 2.5
	light.Parent = parts[1]
	local glitter = Instance.new("ParticleEmitter")
	glitter.Texture = SPARKLE
	glitter.Color = ColorSequence.new(STAR_WHITE, tint)
	glitter.LightEmission = 1
	glitter.LightInfluence = 0
	glitter.Size = NumberSequence.new({ key(0, size * 0.5), key(1, 0) })
	glitter.Transparency = sheerSequence(NumberSequence.new({ key(0, 0.2), key(1, 1) }))
	glitter.Lifetime = NumberRange.new(0.25, 0.5)
	glitter.Rate = 10
	glitter.Speed = NumberRange.new(0.5, 1.5)
	glitter.SpreadAngle = Vector2.new(180, 180)
	glitter.Rotation = NumberRange.new(0, 90)
	glitter.Enabled = false
	glitter.Parent = parts[1]
	local placed, faded = false, false
	local star = { parts = parts }
	function star.place(position: Vector3, spin: number)
		local base = CFrame.lookAt(position, workspace.CurrentCamera.CFrame.Position) * CFrame.Angles(0, 0, spin)
		for i, part in parts do
			part.CFrame = base * offsets[i]
		end
		if not placed and not faded then
			placed = true
			glitter.Enabled = true
		end
	end
	function star.fade(duration: number)
		faded = true
		light.Enabled = false
		glitter.Enabled = false
		fadeOut(parts, duration)
	end
	return star
end
local makeStar = Soft.makeStar

function Soft.softStar(size: number, color: Color3?): Star
	local star = makeStar(size, color)
	for i, part in star.parts do
		if i > 1 then
			part.Transparency = math.max(part.Transparency, 0.35)
		end
	end
	return star
end

export type Sprite = { place: (CFrame, number) -> (), fade: (number) -> () }

function Soft.makeSprite(scale: number): Sprite
	local body = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.5, 0.5, 0.5) * scale,
		Color = WIND_WHITE,
	})
	local glow = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.3 * scale,
		Color = WIND,
		Transparency = 0.7,
	})
	local wings = {
		U.newPart({ Size = Vector3.new(0.9, 0.05, 0.5) * scale, Color = WIND, Transparency = 0.35 }),
		U.newPart({ Size = Vector3.new(0.9, 0.05, 0.5) * scale, Color = WIND, Transparency = 0.35 }),
	}
	for _, part in { body, glow, wings[1], wings[2] } do
		part.Transparency = sheerValue(part.Transparency)
	end
	local light = Instance.new("PointLight")
	light.Color = WIND
	light.Range = 6 * scale
	light.Brightness = 2
	light.Parent = body
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.25 * scale, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.25 * scale, 0)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(WIND_WHITE, WIND)
	trail.Transparency = sheerSequence(NumberSequence.new({ key(0, 0.2), key(1, 1) }))
	trail.WidthScale = NumberSequence.new({ key(0, 1), key(1, 0) })
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = body
	local started = false
	local sprite = {}
	function sprite.place(cframe: CFrame, t: number)
		body.CFrame = cframe
		glow.CFrame = cframe
		if not started then
			started = true
			trail:Clear()
			trail.Enabled = true
		end
		local flap = math.sin(t * 30) * rad(40)
		wings[1].CFrame = cframe * CFrame.Angles(0, 0, flap) * CFrame.new(0.45 * scale, 0, 0)
		wings[2].CFrame = cframe * CFrame.Angles(0, 0, -flap) * CFrame.new(-0.45 * scale, 0, 0)
	end
	function sprite.fade(duration: number)
		light.Enabled = false
		trail.Enabled = false
		fadeOut({ glow, wings[1], wings[2] }, duration)
		Soft.linger(body, duration, trail.Lifetime + 0.15)
	end
	return sprite
end

function Soft.arcPoints(
	center: Vector3,
	right: Vector3,
	up: Vector3,
	radius: number,
	from: number,
	to: number,
	count: number
): { Vector3 }
	local points = {}
	for i = 0, count do
		local angle = from + (to - from) * i / count
		table.insert(points, center + (right * math.cos(angle) + up * math.sin(angle)) * radius)
	end
	return points
end

function Soft.arcParts(points: { Vector3 }, width: number, color: Color3, transparency: number): { BasePart }
	local parts = {}
	for i = 1, #points - 1 do
		table.insert(parts, bar(points[i], points[i + 1], width, color, transparency))
	end
	return parts
end

function Soft.poseArc(parts: { BasePart }, points: { Vector3 })
	for i, part in parts do
		local a, b = points[i], points[i + 1]
		part.Size = Vector3.new(part.Size.X, part.Size.Y, (b - a).Magnitude + 0.05)
		part.CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b)
	end
end

function Soft.worldAnchor(position: Vector3, axis: Vector3?): Attachment
	local x = if axis and axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis
	local y = if math.abs(x.Y) > 0.98 then Vector3.zAxis else UP
	local z = x:Cross(y).Unit
	local attachment = Instance.new("Attachment")
	attachment.CFrame = CFrame.fromMatrix(position, x, z:Cross(x).Unit)
	attachment.Parent = TERRAIN
	return attachment
end
local worldAnchor = Soft.worldAnchor

function Soft.aim(attachment: Attachment, position: Vector3, axis: Vector3?)
	local x = if axis and axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis
	local y = if math.abs(x.Y) > 0.98 then Vector3.zAxis else UP
	local z = x:Cross(y).Unit
	attachment.CFrame = CFrame.fromMatrix(position, x, z:Cross(x).Unit)
end

export type BeamStyle = {
	color: ColorSequence,
	width0: number,
	width1: number,
	transparency: NumberSequence,
	curve0: number?,
	curve1: number?,
	texture: string?,
	speed: number?,
	length: number?,
	emission: number?,
	wrap: boolean?,
	segments: number?,
}

function Soft.softBeam(a0: Attachment, a1: Attachment, style: BeamStyle, parent: Instance?): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = style.color
	beam.Width0 = style.width0
	beam.Width1 = style.width1
	beam.Transparency = sheerSequence(style.transparency)
	beam.CurveSize0 = style.curve0 or 0
	beam.CurveSize1 = style.curve1 or 0
	beam.FaceCamera = true
	beam.LightEmission = style.emission or 1
	beam.LightInfluence = 0
	local curved = (style.curve0 or 0) ~= 0 or (style.curve1 or 0) ~= 0
	beam.Segments = style.segments or (if curved then 20 else 10)
	if style.texture then
		beam.Texture = style.texture
		beam.TextureMode = if style.wrap then Enum.TextureMode.Wrap else Enum.TextureMode.Stretch
		beam.TextureLength = style.length or 1
		beam.TextureSpeed = style.speed or 0
	end
	beam.Parent = parent or TERRAIN
	return beam
end
local softBeam = Soft.softBeam

function Soft.fadeBeams(beams: { Beam }, duration: number, extra: { any }?)
	local originals: { { NumberSequenceKeypoint } } = {}
	for i, beam in beams do
		originals[i] = beam.Transparency.Keypoints
	end
	every(duration, function(elapsed)
		local a = math.clamp(elapsed / duration, 0, 1)
		for i, beam in beams do
			if beam.Parent then
				local points = {}
				for _, point in originals[i] do
					table.insert(points, key(point.Time, point.Value + (1 - point.Value) * a))
				end
				beam.Transparency = NumberSequence.new(points)
			end
		end
		return true
	end, function()
		for _, beam in beams do
			beam:Destroy()
		end
		if extra then
			for _, instance in extra do
				instance:Destroy()
			end
		end
	end)
end
local fadeBeams = Soft.fadeBeams

function Soft.scaleBeams(beams: { Beam }, scale: number, base: { { number } })
	for i, beam in beams do
		beam.Width0 = base[i][1] * scale
		beam.Width1 = base[i][2] * scale
	end
end

function Soft.widths(beams: { Beam }): { { number } }
	local base = {}
	for i, beam in beams do
		base[i] = { beam.Width0, beam.Width1 }
	end
	return base
end

export type Ring = { hub: BasePart, beams: { Beam }, set: (CFrame, number) -> (), fade: (number) -> () }

function Soft.softRing(style: BeamStyle): Ring
	local hub = U.newPart({ Size = Vector3.one * 0.1, Transparency = 1 })
	local anchors: { Attachment } = {}
	for _ = 1, 4 do
		local attachment = Instance.new("Attachment")
		attachment.Parent = hub
		table.insert(anchors, attachment)
	end
	local beams: { Beam } = {}
	for i = 1, 4 do
		local beam = softBeam(anchors[i], anchors[i % 4 + 1], style, hub)
		beam.Segments = style.segments or 12
		table.insert(beams, beam)
	end
	local ring = { hub = hub, beams = beams }
	function ring.set(frame: CFrame, radius: number)
		hub.CFrame = frame
		for i, attachment in anchors do
			local angle = (i - 1) * math.pi / 2
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			attachment.CFrame = CFrame.fromMatrix(out * radius, Vector3.new(-math.sin(angle), 0, math.cos(angle)), UP)
		end
		for _, beam in beams do
			beam.CurveSize0 = radius * KAPPA
			beam.CurveSize1 = radius * KAPPA
		end
	end
	function ring.fade(duration: number)
		fadeBeams(beams, duration, { hub })
	end
	return ring
end
local softRing = Soft.softRing

function Soft.windRing(
	center: Vector3,
	normal: Vector3,
	from: number,
	to: number,
	duration: number,
	color: Color3?,
	width: number?
)
	local w = width or 1.4
	local ring = softRing({
		color = ColorSequence.new(WIND_WHITE, color or WIND),
		width0 = w,
		width1 = w,
		transparency = NumberSequence.new(0.3),
		texture = SMOKE,
		speed = 2,
		length = 4,
	})
	local frame = CFrame.lookAt(center, center + normal) * CFrame.Angles(rad(90), 0, 0)
	ring.set(frame, from)
	every(duration, function(elapsed)
		ring.set(frame, from + (to - from) * (1 - (1 - elapsed / duration) ^ 2))
		return true
	end)
	ring.fade(duration)
end

function Soft.lightRing(center: Vector3, normal: Vector3, from: number, to: number, duration: number, color: Color3?)
	local ring = softRing({
		color = ColorSequence.new(STAR_WHITE, color or STAR),
		width0 = 0.35,
		width1 = 0.35,
		transparency = NumberSequence.new(0.1),
	})
	local frame = CFrame.lookAt(center, center + normal) * CFrame.Angles(rad(90), 0, 0)
	ring.set(frame, from)
	every(duration, function(elapsed)
		local a = 1 - (1 - elapsed / duration) ^ 3
		ring.set(frame, from + (to - from) * a)
		for _, beam in ring.beams do
			beam.Width0 = 0.35 * (1 - a) + 0.05
			beam.Width1 = beam.Width0
		end
		return true
	end)
	ring.fade(duration)
end

export type Arc = {
	beams: { Beam },
	set: (Vector3, Vector3, Vector3, number, number, number) -> (),
	fade: (number) -> (),
}

function Soft.softArc(styles: { BeamStyle }): Arc
	local a0, a1 = worldAnchor(Vector3.zero), worldAnchor(Vector3.zero)
	local beams: { Beam } = {}
	for _, style in styles do
		local beam = softBeam(a0, a1, style)
		beam.Segments = style.segments or 16
		table.insert(beams, beam)
	end
	local arc = { beams = beams }
	function arc.set(center: Vector3, right: Vector3, up: Vector3, radius: number, from: number, to: number)
		local function at(angle: number): Vector3
			return center + (right * math.cos(angle) + up * math.sin(angle)) * radius
		end
		local function tangent(angle: number): Vector3
			return up * math.cos(angle) - right * math.sin(angle)
		end
		local k = 4 / 3 * math.tan((to - from) / 4) * radius
		Soft.aim(a0, at(from), tangent(from))
		Soft.aim(a1, at(to), tangent(to))
		for _, beam in beams do
			beam.CurveSize0 = k
			beam.CurveSize1 = k
		end
	end
	function arc.fade(duration: number)
		fadeBeams(beams, duration, { a0, a1 })
	end
	return arc
end

function Soft.windEmitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SMOKE
	emitter.Color = ColorSequence.new(WIND_WHITE, WIND)
	emitter.LightEmission = 0.5
	emitter.LightInfluence = 0
	emitter.Transparency = NumberSequence.new({ key(0, 1), key(0.2, 0.65), key(0.7, 0.8), key(1, 1) })
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	for name, value in props do
		(emitter :: any)[name] = value
	end
	emitter.Transparency = sheerSequence(emitter.Transparency)
	emitter.Parent = parent
	return emitter
end
local windEmitter = Soft.windEmitter

function Soft.glow(parent: Instance, color: Color3, size: number, transparency: number?): ParticleEmitter
	local base = transparency or 0.6
	return windEmitter(parent, {
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Transparency = NumberSequence.new({ key(0, 1), key(0.25, base), key(0.75, base), key(1, 1) }),
		Size = NumberSequence.new(size),
		Lifetime = NumberRange.new(0.2, 0.26),
		Speed = NumberRange.new(0),
		RotSpeed = NumberRange.new(-40, 40),
		LockedToPart = true,
		Rate = 20,
	})
end

function Soft.windPuff(position: Vector3, size: number, direction: Vector3?)
	U.burst(position, {
		texture = SMOKE,
		color = WIND_WHITE,
		count = math.floor(5 + size),
		size = size,
		speed = NumberRange.new(size * 4, size * 9),
		lifetime = NumberRange.new(0.25, 0.5),
		transparency = 0.55,
		lightEmission = 0.6,
		drag = 5,
		spread = if direction then 50 else 180,
		direction = direction,
	})
end

function Soft.starDust(position: Vector3, count: number, speed: number, direction: Vector3?, color: Color3?)
	U.burst(position, {
		color = color or STAR,
		count = count,
		size = 0.5,
		speed = NumberRange.new(speed * 0.4, speed),
		lifetime = NumberRange.new(0.3, 0.7),
		drag = 4,
		spread = if direction then 60 else 180,
		direction = direction,
	})
end

function Soft.streaks(position: Vector3, count: number, speed: number, direction: Vector3?, spread: number?)
	U.burst(position, {
		color = WIND_WHITE,
		count = count,
		size = 0.4,
		speed = NumberRange.new(speed * 0.5, speed),
		lifetime = NumberRange.new(0.12, 0.3),
		streaks = true,
		spread = spread or (if direction then 35 else 180),
		direction = direction,
	})
end

function Soft.twinkle(position: Vector3, size: number, color: Color3?, duration: number?)
	local life = duration or 0.25
	local holder = U.newPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(position) })
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local flare = Instance.new("ParticleEmitter")
	flare.Texture = SPARKLE
	flare.Color = ColorSequence.new(STAR_WHITE, color or STAR)
	flare.LightEmission = 1
	flare.LightInfluence = 0
	flare.Size = NumberSequence.new({ key(0, size * 0.4), key(0.25, size), key(1, 0) })
	flare.Transparency = sheerSequence(NumberSequence.new({ key(0, 0), key(0.7, 0.2), key(1, 1) }))
	flare.Lifetime = NumberRange.new(life)
	flare.Speed = NumberRange.new(0)
	flare.Rotation = NumberRange.new(-10, 10)
	flare.RotSpeed = NumberRange.new(-60, 60)
	flare.Enabled = false
	flare.Parent = attachment
	flare:Emit(1)
	local halo = flare:Clone()
	halo.Texture = SMOKE
	halo.Color = ColorSequence.new(color or STAR)
	halo.Size = NumberSequence.new({ key(0, size * 0.6), key(1, size * 1.2) })
	halo.Transparency = sheerSequence(NumberSequence.new({ key(0, 0.55), key(1, 1) }))
	halo.Parent = attachment
	halo:Emit(1)
	task.delay(life + 0.1, holder.Destroy, holder)
end

export type TrailStyle = {
	color: ColorSequence,
	transparency: NumberSequence,
	lifetime: number,
	width: NumberSequence?,
	texture: string?,
	faceCamera: boolean?,
	emission: number?,
	off: boolean?,
}

function Soft.trail(part: BasePart, a: Vector3, b: Vector3, style: TrailStyle): Trail
	local a0 = Instance.new("Attachment")
	a0.Position = a
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = b
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = style.color
	trail.Transparency = sheerSequence(style.transparency)
	trail.Lifetime = style.lifetime
	trail.WidthScale = style.width or NumberSequence.new(1)
	trail.LightEmission = style.emission or 1
	trail.LightInfluence = 0
	trail.FaceCamera = style.faceCamera ~= false
	trail.MinLength = 0
	trail.Enabled = not style.off
	if style.texture then
		trail.Texture = style.texture
		trail.TextureMode = Enum.TextureMode.Stretch
		trail.TextureLength = 1
	end
	trail.Parent = part
	trail.Destroying:Connect(function()
		a0:Destroy()
		a1:Destroy()
	end)
	return trail
end

function Soft.beginTrail(trail: Trail)
	if not trail.Enabled then
		trail:Clear()
		trail.Enabled = true
	end
end

function Soft.endTrail(trail: Trail)
	trail.Enabled = false
	task.delay(trail.Lifetime + 0.1, trail.Destroy, trail)
end

function Soft.linger(part: BasePart, fade: number, keep: number)
	U.tween(part, fade, { Transparency = 1 })
	task.delay(keep, part.Destroy, part)
end

function Soft.helix(
	axis: (number) -> (Vector3, Vector3),
	radius: number,
	strands: number,
	climb: number,
	turns: number,
	width: number,
	duration: number,
	color: Color3?
): () -> ()
	type Runner = { part: BasePart, trail: Trail, phase: number }
	local runners: { [number]: Runner } = {}
	local function retire(runner: Runner)
		Soft.endTrail(runner.trail)
		task.delay(runner.trail.Lifetime + 0.2, runner.part.Destroy, runner.part)
	end
	local function spawnRunner(i: number, at: Vector3, phase: number): Runner
		local part = U.newPart({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = CFrame.new(at) })
		local trail = Soft.trail(part, Vector3.new(0, width / 2, 0), Vector3.new(0, -width / 2, 0), {
			color = ColorSequence.new(if i % 2 == 0 then WIND_WHITE else color or WIND, color or WIND),
			transparency = NumberSequence.new({ key(0, 0.25), key(1, 1) }),
			width = NumberSequence.new({ key(0, 1), key(1, 0.2) }),
			lifetime = 0.25,
		})
		return { part = part, trail = trail, phase = phase }
	end
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		for i = 1, strands do
			local runner = runners[i]
			if runner then
				runners[i] = nil
				retire(runner)
			end
		end
	end
	every(duration, function(elapsed)
		if stopped then
			return false
		end
		local foot, top = axis(elapsed)
		local along = top - foot
		local length = along.Magnitude
		if length < 1e-3 then
			return true
		end
		local up = along / length
		local side = up:Cross(if math.abs(up.Y) > 0.9 then Vector3.xAxis else UP).Unit
		local other = up:Cross(side)
		for i = 1, strands do
			local phase = (elapsed / climb + (i - 1) / strands) % 1
			local angle = phase * turns * math.pi * 2 + i * 2.1
			local r = radius * (1 - phase * 0.35)
			local position = foot + up * (length * phase) + (side * math.cos(angle) + other * math.sin(angle)) * r
			local runner = runners[i]
			if runner and phase < runner.phase then
				retire(runner)
				runner = nil
			end
			if runner then
				runner.part.CFrame = CFrame.new(position)
				runner.phase = phase
			else
				runners[i] = spawnRunner(i, position, phase)
			end
		end
		return true
	end, stop)
	return stop
end

function Soft.starStream(a0: Attachment, a1: Attachment, width: number, speed: number, parent: Instance?): Beam
	return softBeam(a0, a1, {
		color = ColorSequence.new(STAR_WHITE, STAR),
		width0 = width,
		width1 = width * 0.6,
		transparency = NumberSequence.new({ key(0, 0.5), key(0.15, 0.1), key(0.85, 0.1), key(1, 0.5) }),
		texture = SPARKLE,
		wrap = true,
		length = width * 1.6,
		speed = speed,
	}, parent)
end

export type Slash = {
	flare: () -> (),
	fade: (number) -> (),
	move: (Vector3, number) -> (),
	apex: Vector3,
	from: Vector3,
	to: Vector3,
}

function Soft.windSlash(from: Vector3, to: Vector3, bend: Vector3, scale: number, swipe: number?): Slash
	local middle = from:Lerp(to, 0.5)
	local apex = middle + bend
	local control = middle + bend * 2
	local a = worldAnchor(from, control - from)
	local m = worldAnchor(apex, to - from)
	local b = worldAnchor(to, to - control)
	local k1 = (apex - from).Magnitude * 0.42
	local k2 = (to - apex).Magnitude * 0.42
	local white = ColorSequence.new(STAR_WHITE, WIND_WHITE)
	local green = ColorSequence.new(WIND_WHITE, WIND)
	local haze = ColorSequence.new(WIND, WIND_DEEP)
	local function half(first: boolean, style: BeamStyle): Beam
		style.curve0 = if first then k1 else k2
		style.curve1 = style.curve0
		return softBeam(if first then a else m, if first then m else b, style)
	end
	local function taper(first: boolean, wide: number, thin: number): (number, number)
		if first then
			return thin, wide
		end
		return wide, thin
	end
	local function fadeEnds(first: boolean, edge: number, middleValue: number): NumberSequence
		if first then
			return NumberSequence.new({ key(0, 1), key(0.5, (edge + middleValue) / 2), key(1, middleValue) })
		end
		return NumberSequence.new({ key(0, middleValue), key(0.5, (edge + middleValue) / 2), key(1, 1) })
	end
	local beams: { Beam } = {}
	for _, first in { true, false } do
		local w0, w1 = taper(first, 0.5 * scale, 0.05)
		table.insert(
			beams,
			half(first, { color = white, width0 = w0, width1 = w1, transparency = fadeEnds(first, 0.2, 0.05) })
		)
		w0, w1 = taper(first, 0.9 * scale, 0.1)
		table.insert(
			beams,
			half(first, {
				color = ColorSequence.new(STAR_WHITE, STAR),
				width0 = w0,
				width1 = w1,
				transparency = fadeEnds(first, 0.4, 0.25),
				texture = SPARKLE,
				wrap = true,
				length = 1.4 * scale,
				speed = if first then 3 else -3,
			})
		)
		w0, w1 = taper(first, 3 * scale, 0.4)
		table.insert(
			beams,
			half(first, {
				color = green,
				width0 = w0,
				width1 = w1,
				transparency = fadeEnds(first, 0.72, 0.6),
				texture = SMOKE,
				speed = 1.5,
				length = 3,
			})
		)
		w0, w1 = taper(first, 7 * scale, 1)
		table.insert(
			beams,
			half(first, {
				color = haze,
				width0 = w0,
				width1 = w1,
				transparency = fadeEnds(first, 0.94, 0.87),
				texture = SMOKE,
				speed = -1,
				length = 6,
				emission = 0.6,
			})
		)
	end
	for _, beam in beams do
		beam.Enabled = false
	end
	local wisps = windEmitter(m, {
		Size = NumberSequence.new({ key(0, 1.2 * scale), key(1, 3 * scale) }),
		Transparency = NumberSequence.new({ key(0, 1), key(0.3, 0.8), key(1, 1) }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 2,
		Rate = 0,
	})
	local sweep = swipe or 0.06
	local runner = U.newPart({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = CFrame.new(from) })
	local swipeTrail = Soft.trail(runner, Vector3.new(0, 1.3 * scale, 0), Vector3.new(0, -1.3 * scale, 0), {
		color = ColorSequence.new(STAR_WHITE, WIND),
		transparency = NumberSequence.new({ key(0, 0.1), key(1, 1) }),
		width = NumberSequence.new({ key(0, 1), key(1, 0.15) }),
		lifetime = 0.3,
	})
	every(sweep, function(elapsed)
		runner.CFrame = CFrame.new(quadratic(from, control, to, elapsed / sweep))
		return true
	end, function()
		runner.CFrame = CFrame.new(to)
		for _, beam in beams do
			beam.Enabled = true
		end
		wisps.Rate = 14
		Soft.endTrail(swipeTrail)
		task.delay(0.45, runner.Destroy, runner)
	end)
	local slash = { apex = apex, from = from, to = to }
	local base = Soft.widths(beams)
	function slash.flare()
		every(0.12, function(elapsed)
			Soft.scaleBeams(beams, 1 + 1.6 * math.sin(math.min(elapsed / 0.12, 1) * math.pi / 2), base)
			return true
		end)
	end
	function slash.fade(duration: number)
		wisps.Enabled = false
		fadeBeams(beams, duration, { a, m, b })
	end
	function slash.move(offset: Vector3, duration: number)
		for _, anchor in { a, m, b } do
			U.tween(anchor, duration, { CFrame = anchor.CFrame + offset })
		end
	end
	return slash
end

function Soft.focusLines(duration: number)
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local viewport = workspace.CurrentCamera.ViewportSize
	local gui = Instance.new("ScreenGui")
	gui.Name = "FocusLines"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45
	gui.Parent = playerGui
	local half = viewport.Magnitude / 2
	local lines: { Frame } = {}
	for i = 1, 56 do
		local angle = (i / 56) * math.pi * 2 + math.random() * 0.08
		local length = half * (0.55 + math.random() * 0.35)
		local reach = half * (0.42 + math.random() * 0.2) + length / 2
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position =
			UDim2.fromOffset(viewport.X / 2 + math.cos(angle) * reach, viewport.Y / 2 + math.sin(angle) * reach)
		line.Size = UDim2.fromOffset(length, 1 + math.random() * 3)
		line.Rotation = math.deg(angle)
		line.BackgroundColor3 = if i % 7 == 0 then STAR else Color3.new(1, 1, 1)
		line.BorderSizePixel = 0
		line.BackgroundTransparency = 0.1
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({ key(0, 1), key(0.45, 0.4), key(1, 0) })
		gradient.Parent = line
		line.Parent = gui
		table.insert(lines, line)
	end
	for _, line in lines do
		U.tween(line, duration, { BackgroundTransparency = 1 })
	end
	task.delay(duration + 0.05, gui.Destroy, gui)
end

return Soft
