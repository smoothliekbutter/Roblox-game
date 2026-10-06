local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local VFX = require(script.Parent.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Parent.Soft)

type Animation = PoseAnimator.Animation

local U = VFX.Util
local rad = math.rad
local UP = Vector3.yAxis

local WATER = Color3.fromRGB(70, 165, 255)
local WATER_DEEP = Color3.fromRGB(25, 85, 200)
local WATER_LIGHT = Color3.fromRGB(150, 215, 255)
local FOAM = Color3.fromRGB(235, 248, 255)
local SILVER = Color3.fromRGB(200, 215, 235)
local SAINT = Color3.fromRGB(255, 244, 205)

local SMOKE, SPARKLE = Soft.SMOKE, Soft.SPARKLE
local every, key = Soft.every, Soft.key
local worldAnchor, softBeam, fadeBeams, softRing = Soft.worldAnchor, Soft.softBeam, Soft.fadeBeams, Soft.softRing
local GRAVITY = Vector3.new(0, -70, 0)

local function build(raw: { [string]: any }): Animation
	local keyframes = {}
	for _, frame in raw.keys do
		table.insert(keyframes, {
			time = frame[1],
			pose = frame[2],
			easing = if frame[3] then (Enum.EasingStyle :: any)[frame[3]] else nil,
			direction = if frame[4] then (Enum.EasingDirection :: any)[frame[4]] else nil,
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

local ANIMS: { [string]: Animation } = {}
for name, raw in require(script.Parent.Animations) do
	ANIMS[name] = build(raw)
end

local function play(character: Model, animation: Animation, onEvent: ((string) -> ())?)
	PoseAnimator.Play(character, animation, onEvent)
end

local handlers: { [string]: (data: any, character: Model, root: BasePart) -> () } = {}

local castTokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local function bump(character: Model): number
	local token = (castTokens[character] or 0) + 1
	castTokens[character] = token
	return token
end
local function live(character: Model, token: number): boolean
	return castTokens[character] == token and character.Parent ~= nil
end

local function handOf(character: Model, side: string): Vector3?
	local arm = character:FindFirstChild(side .. " Arm")
	return if arm and arm:IsA("BasePart") then (arm.CFrame * CFrame.new(0, -1.15, 0)).Position else nil
end

local function easeOut(u: number): number
	return 1 - (1 - math.clamp(u, 0, 1)) ^ 3
end

local function easeInOut(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function flatFrame(center: Vector3, normal: Vector3): CFrame
	return CFrame.lookAt(center, center + normal) * CFrame.Angles(rad(90), 0, 0)
end

local function ripple(
	center: Vector3,
	normal: Vector3,
	from: number,
	to: number,
	duration: number,
	width: number?,
	color: Color3?
)
	local w = width or 1.2
	local ring = softRing({
		color = ColorSequence.new(FOAM, color or WATER),
		width0 = w,
		width1 = w,
		transparency = NumberSequence.new(0.35),
		texture = SMOKE,
		speed = 2.5,
		length = 4,
	})
	local frame = flatFrame(center, normal)
	ring.set(frame, from)
	every(duration, function(elapsed)
		ring.set(frame, from + (to - from) * (1 - (1 - elapsed / duration) ^ 2))
		return true
	end)
	ring.fade(duration)
end

local function shine(center: Vector3, normal: Vector3, from: number, to: number, duration: number, color: Color3?)
	local ring = softRing({
		color = ColorSequence.new(FOAM, color or WATER_LIGHT),
		width0 = 0.35,
		width1 = 0.35,
		transparency = NumberSequence.new(0.1),
	})
	local frame = flatFrame(center, normal)
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

local function spray(position: Vector3, count: number, speed: number, direction: Vector3?, spread: number?)
	U.burst(position, {
		color = FOAM,
		count = count,
		size = 0.4,
		speed = NumberRange.new(speed * 0.5, speed),
		lifetime = NumberRange.new(0.2, 0.45),
		streaks = true,
		spread = spread or (if direction then 35 else 180),
		direction = direction,
		acceleration = GRAVITY,
		drag = 2,
	})
end

local function mist(position: Vector3, size: number, direction: Vector3?)
	U.burst(position, {
		texture = SMOKE,
		color = WATER_LIGHT,
		count = math.floor(5 + size),
		size = size,
		speed = NumberRange.new(size * 3, size * 7),
		lifetime = NumberRange.new(0.3, 0.6),
		transparency = 0.6,
		lightEmission = 0.4,
		drag = 5,
		spread = if direction then 50 else 180,
		direction = direction,
	})
end

local function glints(position: Vector3, count: number, speed: number, direction: Vector3?)
	U.burst(position, {
		color = WATER_LIGHT,
		count = count,
		size = 0.5,
		speed = NumberRange.new(speed * 0.4, speed),
		lifetime = NumberRange.new(0.3, 0.6),
		drag = 4,
		spread = if direction then 60 else 180,
		direction = direction,
	})
end

type Drop = { part: BasePart, velocity: Vector3, position: Vector3 }

local function droplets(position: Vector3, count: number, speed: number, up: Vector3?, size: number?)
	local drops: { Drop } = {}
	local life = 0.75
	for _ = 1, count do
		local d = (size or 0.35) * (0.6 + math.random() * 0.8)
		local part = U.newPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * d,
			Color = if math.random() < 0.5 then WATER_LIGHT else FOAM,
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			CFrame = CFrame.new(position),
		})
		local direction = U.randomUnit()
		if up then
			direction = (direction + up * 1.4).Unit
		end
		table.insert(
			drops,
			{ part = part, velocity = direction * speed * (0.5 + math.random() * 0.6), position = position }
		)
		U.tween(part, life, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	every(life, function(_, dt)
		for _, drop in drops do
			drop.velocity += GRAVITY * dt
			drop.position += drop.velocity * dt
			drop.part.CFrame = CFrame.new(drop.position)
		end
		return true
	end, function()
		for _, drop in drops do
			drop.part:Destroy()
		end
	end)
end

type Sheet = { part: BasePart, angle: number, width: number }

local function crown(position: Vector3, radius: number, height: number, duration: number, count: number?)
	local n = count or 12
	local sheets: { Sheet } = {}
	for i = 1, n do
		local width = 2 * math.pi * radius / n * 1.1
		table.insert(sheets, {
			part = U.newPart({
				Size = Vector3.new(width, 0.1, 0.12),
				Color = WATER_LIGHT,
				Material = Enum.Material.Glass,
				Transparency = 0.3,
			}),
			angle = (i / n) * math.pi * 2,
			width = width,
		})
	end
	every(duration, function(elapsed)
		local a = elapsed / duration
		local rise = math.sin(math.min(a / 0.55, 1) * math.pi / 2)
		local h = height * rise * (1 - math.max(0, (a - 0.55) / 0.45) * 0.65)
		local r = radius * (1 + a * 0.7)
		for _, sheet in sheets do
			local base = CFrame.new(position)
				* CFrame.Angles(0, sheet.angle, 0)
				* CFrame.new(0, 0, -r)
				* CFrame.Angles(rad(-18 - 34 * a), 0, 0)
			sheet.part.Size = Vector3.new(sheet.width * (1 + a * 0.7), math.max(h, 0.1), 0.12)
			sheet.part.CFrame = base * CFrame.new(0, h / 2, 0)
			sheet.part.Transparency = 0.3 + 0.7 * a * a
		end
		return true
	end, function()
		for _, sheet in sheets do
			sheet.part:Destroy()
		end
	end)
end

local function floorAt(position: Vector3, depth: number?): RaycastResult?
	return U.groundBelow(position, nil, depth or 10)
end

local function puddle(position: Vector3, radius: number, duration: number)
	local ground = floorAt(position + UP, 8)
	if not ground then
		return
	end
	local spot = ground.Position + UP * 0.04
	local frame = CFrame.lookAt(spot, spot + ground.Normal) * CFrame.Angles(0, rad(90), 0)
	local disc = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 0.4, 0.4),
		CFrame = frame,
		Color = WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	})
	local sheen = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 0.3, 0.3),
		CFrame = frame * CFrame.new(0.02, 0, 0),
		Color = WATER_LIGHT,
		Transparency = 0.75,
	})
	U.tween(disc, 0.2, { Size = Vector3.new(0.05, radius * 2, radius * 2) })
	U.tween(sheen, 0.25, { Size = Vector3.new(0.05, radius * 1.6, radius * 1.6) })
	task.delay(duration, function()
		U.tween(disc, 0.5, { Transparency = 1, Size = Vector3.new(0.05, radius * 2.3, radius * 2.3) })
		U.tween(sheen, 0.4, { Transparency = 1 })
	end)
	task.delay(duration + 0.55, function()
		disc:Destroy()
		sheen:Destroy()
	end)
	ripple(spot + UP * 0.05, ground.Normal, radius * 0.3, radius * 1.2, 0.5, 0.8)
end

local function splash(position: Vector3, size: number, direction: Vector3?)
	local up = direction or UP
	spray(position, math.floor(10 + size * 4), 18 + size * 6, up, 55)
	mist(position, size * 0.7, up)
	droplets(position, math.floor(5 + size * 2), 14 + size * 4, up, 0.3 + size * 0.04)
	U.flash(position, FOAM, size * 1.6, 0.14)
	shine(position, up, size * 0.2, size * 1.4, 0.25)
	ripple(position, up, size * 0.2, size * 1.1, 0.35, 0.7 + size * 0.15)
	U.light(position, WATER, 3, size * 3, 0.25)
	local ground = floorAt(position + UP * 0.5, 4)
	if ground then
		crown(ground.Position, size * 0.45, size * 0.8, 0.55)
		puddle(ground.Position, size * 0.9, 0.9)
	end
end

local function bubbles(parent: Instance, rate: number, size: number?): ParticleEmitter
	local s = size or 0.3
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(FOAM, WATER_LIGHT)
	emitter.LightEmission = 0.8
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ key(0, s), key(0.6, s * 0.8), key(1, 0) })
	emitter.Transparency = NumberSequence.new({ key(0, 0.6), key(0.3, 0.15), key(1, 1) })
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.Acceleration = Vector3.new(0, 4, 0)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Rate = rate
	emitter.Parent = parent
	return emitter
end

local function water(parent: Instance, props: { [string]: any }): ParticleEmitter
	local merged: { [string]: any } = { Color = ColorSequence.new(FOAM, WATER), LightEmission = 0.5 }
	for name, value in props do
		merged[name] = value
	end
	return Soft.windEmitter(parent, merged)
end

local function geyser(base: Vector3, height: number, radius: number, duration: number)
	local up = CFrame.Angles(0, 0, rad(90))
	local column = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, radius * 2, radius * 2),
		CFrame = CFrame.new(base) * up,
		Color = WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	})
	local skin = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, radius * 2.2, radius * 2.2),
		CFrame = CFrame.new(base) * up,
		Color = WATER_LIGHT,
		Material = Enum.Material.ForceField,
	})
	local core = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, radius * 0.8, radius * 0.8),
		CFrame = CFrame.new(base) * up,
		Color = FOAM,
		Transparency = 0.55,
	})
	local cap = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2.6,
		CFrame = CFrame.new(base),
		Color = FOAM,
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	local foam = water(cap, {
		Size = NumberSequence.new({ key(0, radius * 1.2), key(1, radius * 2.6) }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(radius * 3, radius * 6),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -40, 0),
		Rate = 40,
	})
	local light = Instance.new("PointLight")
	light.Color = WATER
	light.Range = height
	light.Brightness = 3
	light.Parent = cap
	local parts = { column, skin, core, cap }
	local rise, hold = duration * 0.16, duration * 0.55
	every(duration, function(elapsed)
		local top
		if elapsed < rise then
			top = height * easeOut(elapsed / rise)
		elseif elapsed < hold then
			top = height * (1 + 0.04 * math.sin((elapsed - rise) * 18))
		else
			top = height * (1 - ((elapsed - hold) / (duration - hold)) ^ 2)
		end
		top = math.max(top, 0.1)
		local wobble = 1 + 0.08 * math.sin(elapsed * 25)
		column.Size = Vector3.new(top, radius * 2 * wobble, radius * 2 * wobble)
		column.CFrame = CFrame.new(base + UP * top / 2) * up
		skin.Size = Vector3.new(top * 1.02, radius * 2.25 / wobble, radius * 2.25 / wobble)
		skin.CFrame = column.CFrame
		core.Size = Vector3.new(top, radius * 0.8, radius * 0.8)
		core.CFrame = column.CFrame
		cap.CFrame = CFrame.new(base + UP * top)
		return true
	end, function()
		foam.Enabled = false
		light.Enabled = false
		Soft.fadeOut(parts, 0.15)
		task.delay(1, foam.Destroy, foam)
	end)
	task.delay(hold, function()
		foam.Rate = 12
		droplets(base + UP * height, 12, 22, UP, 0.5)
	end)
end

export type Orb = {
	parts: { BasePart },
	core: BasePart,
	place: (CFrame, number?) -> (),
	fade: (number) -> (),
}

local function orb(radius: number, glow: number?, clear: number?): Orb
	local d = radius * 2
	local body = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * d,
		Color = WATER,
		Material = Enum.Material.Glass,
		Transparency = clear or 0.4,
	})
	local skin = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * d * 1.06,
		Color = WATER_LIGHT,
		Material = Enum.Material.ForceField,
	})
	local core = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * d * 0.45,
		Color = FOAM,
		Transparency = glow or 0.75,
	})
	local bands = {
		softRing({
			color = ColorSequence.new(FOAM, WATER_LIGHT),
			width0 = radius * 0.35,
			width1 = radius * 0.35,
			transparency = NumberSequence.new(0.35),
			texture = SMOKE,
			speed = 3,
			length = radius * 2,
		}),
		softRing({
			color = ColorSequence.new(WATER_LIGHT, WATER),
			width0 = radius * 0.25,
			width1 = radius * 0.25,
			transparency = NumberSequence.new(0.45),
			texture = SMOKE,
			speed = -2,
			length = radius * 2,
		}),
	}
	local light = Instance.new("PointLight")
	light.Color = WATER
	light.Range = radius * 4
	light.Brightness = 2
	light.Parent = core
	local fizz = bubbles(core, radius * 6, radius * 0.18)
	local start = os.clock()
	local size = 1
	local result = { parts = { body, skin, core }, core = core }
	function result.place(frame: CFrame, scale: number?)
		local s = scale or 1
		if s ~= size then
			size = s
			body.Size = Vector3.one * d * s
			skin.Size = Vector3.one * d * 1.06 * s
			core.Size = Vector3.one * d * 0.45 * s
		end
		body.CFrame = frame
		skin.CFrame = frame
		core.CFrame = frame
		local t = os.clock() - start
		bands[1].set(frame * CFrame.Angles(0, t * 2.2, 0) * CFrame.Angles(rad(28), 0, 0), radius * 1.02 * s)
		bands[2].set(frame * CFrame.Angles(0, -t * 3, 0) * CFrame.Angles(rad(-52), 0, 0), radius * 0.95 * s)
	end
	function result.fade(duration: number)
		light.Enabled = false
		fizz.Enabled = false
		for _, band in bands do
			band.fade(duration)
		end
		Soft.fadeOut({ body, skin, core }, duration)
		task.delay(1, fizz.Destroy, fizz)
	end
	return result
end

export type Stream = { set: (Vector3, Vector3) -> (), fade: (number) -> (), beams: { Beam } }

local function stream(width: number, speed: number?): Stream
	local flow = speed or 6
	local a0, a1 = worldAnchor(Vector3.zero), worldAnchor(Vector3.zero)
	local beams = {
		softBeam(a0, a1, {
			color = ColorSequence.new(FOAM),
			width0 = width * 0.3,
			width1 = width * 0.3,
			transparency = NumberSequence.new(0.25),
		}),
		softBeam(a0, a1, {
			color = ColorSequence.new(WATER_LIGHT, WATER),
			width0 = width,
			width1 = width,
			transparency = NumberSequence.new(0.4),
			texture = SMOKE,
			speed = flow,
			length = width * 2,
		}),
		softBeam(a0, a1, {
			color = ColorSequence.new(WATER, WATER_DEEP),
			width0 = width * 2,
			width1 = width * 2,
			transparency = NumberSequence.new(0.8),
			texture = SMOKE,
			speed = -flow * 0.5,
			length = width * 3,
			emission = 0.4,
		}),
	}
	local result = { beams = beams }
	function result.set(from: Vector3, to: Vector3)
		local along = to - from
		Soft.aim(a0, from, along)
		Soft.aim(a1, to, along)
	end
	function result.fade(duration: number)
		fadeBeams(beams, duration, { a0, a1 })
	end
	return result
end

local function whirl(center: Vector3, normal: Vector3, radius: number, duration: number, spin: number?)
	local frame = flatFrame(center, normal)
	local right, along = frame.RightVector, frame.LookVector
	local turn = spin or 5
	local arcs: { Soft.Arc } = {}
	for _ = 1, 3 do
		table.insert(
			arcs,
			Soft.softArc({
				{
					color = ColorSequence.new(FOAM, WATER_LIGHT),
					width0 = 0.45,
					width1 = 0.08,
					transparency = NumberSequence.new({ key(0, 0.15), key(1, 0.85) }),
				},
				{
					color = ColorSequence.new(WATER_LIGHT, WATER),
					width0 = radius * 0.35,
					width1 = radius * 0.1,
					transparency = NumberSequence.new({ key(0, 0.55), key(1, 1) }),
					texture = SMOKE,
					speed = 3,
					length = 3,
				},
			})
		)
	end
	every(duration, function(elapsed)
		local grow = easeOut(elapsed / 0.25)
		for i, arc in arcs do
			local r = radius * (1 - (i - 1) * 0.28) * grow + 0.05
			local from = elapsed * turn * (1 + (i - 1) * 0.6) + (i - 1) * 2.1
			arc.set(center, right, along, r, from, from + 2.4)
		end
		return true
	end, function()
		for _, arc in arcs do
			arc.fade(0.25)
		end
	end)
end

export type Lash = { fade: (number) -> (), flare: () -> (), apex: Vector3 }

local function lash(from: Vector3, to: Vector3, bend: Vector3, scale: number, sweep: number?): Lash
	local middle = from:Lerp(to, 0.5)
	local apex = middle + bend
	local control = middle + bend * 2
	local a = worldAnchor(from, control - from)
	local m = worldAnchor(apex, to - from)
	local b = worldAnchor(to, to - control)
	local k1 = (apex - from).Magnitude * 0.42
	local k2 = (to - apex).Magnitude * 0.42
	local function half(first: boolean, style: Soft.BeamStyle): Beam
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
	local function ends(first: boolean, edge: number, mid: number): NumberSequence
		if first then
			return NumberSequence.new({ key(0, 1), key(0.5, (edge + mid) / 2), key(1, mid) })
		end
		return NumberSequence.new({ key(0, mid), key(0.5, (edge + mid) / 2), key(1, 1) })
	end
	local beams: { Beam } = {}
	for _, first in { true, false } do
		local w0, w1 = taper(first, 0.4 * scale, 0.04)
		table.insert(
			beams,
			half(
				first,
				{ color = ColorSequence.new(FOAM), width0 = w0, width1 = w1, transparency = ends(first, 0.2, 0.05) }
			)
		)
		w0, w1 = taper(first, 1.7 * scale, 0.2)
		table.insert(
			beams,
			half(first, {
				color = ColorSequence.new(FOAM, WATER_LIGHT),
				width0 = w0,
				width1 = w1,
				transparency = ends(first, 0.6, 0.38),
				texture = SMOKE,
				speed = if first then 4 else -4,
				length = 2,
			})
		)
		w0, w1 = taper(first, 4.2 * scale, 0.6)
		table.insert(
			beams,
			half(first, {
				color = ColorSequence.new(WATER, WATER_DEEP),
				width0 = w0,
				width1 = w1,
				transparency = ends(first, 0.93, 0.84),
				texture = SMOKE,
				speed = -1.5,
				length = 5,
				emission = 0.5,
			})
		)
	end
	for _, beam in beams do
		beam.Enabled = false
	end
	local time = sweep or 0.06
	local runner = U.newPart({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = CFrame.new(from) })
	local wake = Soft.trail(runner, Vector3.new(0, 1.1 * scale, 0), Vector3.new(0, -1.1 * scale, 0), {
		color = ColorSequence.new(FOAM, WATER),
		transparency = NumberSequence.new({ key(0, 0.15), key(1, 1) }),
		width = NumberSequence.new({ key(0, 1), key(1, 0.15) }),
		lifetime = 0.25,
	})
	every(time, function(elapsed)
		runner.CFrame = CFrame.new(Soft.quadratic(from, control, to, elapsed / time))
		return true
	end, function()
		runner.CFrame = CFrame.new(to)
		for _, beam in beams do
			beam.Enabled = true
		end
		Soft.endTrail(wake)
		task.delay(0.4, runner.Destroy, runner)
		spray(apex, math.floor(6 + 6 * scale), 20, if bend.Magnitude > 1e-3 then bend.Unit else nil, 60)
	end)
	local base = Soft.widths(beams)
	local result = { apex = apex }
	function result.flare()
		every(0.12, function(elapsed)
			Soft.scaleBeams(beams, 1 + 1.4 * math.sin(math.min(elapsed / 0.12, 1) * math.pi / 2), base)
			return true
		end)
	end
	function result.fade(duration: number)
		fadeBeams(beams, duration, { a, m, b })
	end
	return result
end

local function hideBody(character: Model, hidden: boolean)
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			item.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

return {
	ANIMS = ANIMS,
	play = play,
	handlers = handlers,
	bump = bump,
	live = live,
	handOf = handOf,
	easeOut = easeOut,
	easeInOut = easeInOut,
	flatFrame = flatFrame,
	floorAt = floorAt,
	ripple = ripple,
	shine = shine,
	spray = spray,
	mist = mist,
	glints = glints,
	droplets = droplets,
	crown = crown,
	puddle = puddle,
	splash = splash,
	bubbles = bubbles,
	water = water,
	geyser = geyser,
	orb = orb,
	stream = stream,
	whirl = whirl,
	lash = lash,
	hideBody = hideBody,
	WATER = WATER,
	WATER_DEEP = WATER_DEEP,
	WATER_LIGHT = WATER_LIGHT,
	FOAM = FOAM,
	SILVER = SILVER,
	SAINT = SAINT,
}
