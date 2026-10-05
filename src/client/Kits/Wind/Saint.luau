-- Yuno's Saint Spirit of Zephyr (Full-Crown 4) cutscene, drawn along Shared/SaintZephyr's flight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SaintPlan = require(ReplicatedStorage:WaitForChild("Shared").SaintZephyr)
local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local Cinematic = require(script.Parent.Parent.Parent.Cinematic)
local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local Soft = require(script.Parent.Parent.Parent.Soft)

local U = Soft.U
local rad = math.rad
local UP = Vector3.yAxis

local WIND, WIND_DEEP, WIND_WHITE = Soft.WIND, Soft.WIND_DEEP, Soft.WIND_WHITE
local STAR, STAR_WHITE = Soft.STAR, Soft.STAR_WHITE
local SMOKE, SPARKLE = Soft.SMOKE, Soft.SPARKLE
local every, key = Soft.every, Soft.key
local worldAnchor, softBeam, fadeBeams, softRing = Soft.worldAnchor, Soft.softBeam, Soft.fadeBeams, Soft.softRing
local windRing, lightRing, windEmitter, windPuff = Soft.windRing, Soft.lightRing, Soft.windEmitter, Soft.windPuff
local twinkle, starDust, streaks = Soft.twinkle, Soft.starDust, Soft.streaks

type Animation = PoseAnimator.Animation

-- What the kit lends this module (its animations, and his sword).
export type Context = {
	anims: { [string]: Animation },
	play: (Model, Animation) -> (),
	blade: (Model) -> BasePart?, -- his wind sword's blade (moves trail wind off it)
	hideSword: (Model, number) -> (),
}

local Saint = {}

local SAINT_BLADE = 40 -- the colossal blade's length
local SHEER = 0.4 -- how much more see-through everything in it is

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function easeOut(u: number): number
	return 1 - (1 - math.clamp(u, 0, 1)) ^ 3
end

local function handOf(character: Model, side: string): Vector3?
	local arm = character:FindFirstChild(side .. " Arm")
	return if arm and arm:IsA("BasePart") then (arm.CFrame * CFrame.new(0, -1.15, 0)).Position else nil
end

-- Any direction square to `direction`, and a second square to both.
local function across(direction: Vector3): (Vector3, Vector3)
	local side = direction:Cross(UP)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	return side, side:Cross(direction).Unit
end

-- Pieces

-- Outlines someone through all of it for the length of the cutscene.
local function outline(character: Model?, color: Color3, duration: number)
	if not character then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = color
	highlight.FillTransparency = 0.92
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 1
	highlight.Adornee = character
	highlight.Parent = character
	U.tween(highlight, 0.3, { OutlineTransparency = 0.35 })
	task.delay(duration, function()
		U.tween(highlight, 0.4, { OutlineTransparency = 1, FillTransparency = 1 })
		task.delay(0.45, highlight.Destroy, highlight)
	end)
end

local function groundSigil(center: Vector3, radius: number, duration: number)
	local rings = {
		softRing({
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 0.45,
			width1 = 0.45,
			transparency = NumberSequence.new(0.15),
		}),
		softRing({
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 1.1,
			width1 = 1.1,
			transparency = NumberSequence.new(0.35),
			texture = SPARKLE,
			wrap = true,
			length = 1.6,
			speed = 2,
		}),
		softRing({
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 1.8,
			width1 = 1.8,
			transparency = NumberSequence.new(0.55),
			texture = SMOKE,
			speed = 3,
			length = 5,
		}),
		softRing({
			color = ColorSequence.new(STAR_WHITE),
			width0 = 0.25,
			width1 = 0.25,
			transparency = NumberSequence.new(0.3),
		}),
	}
	local hub = rings[1].hub
	local points: { Attachment } = {}
	for i = 1, 8 do
		local point = Instance.new("Attachment")
		point.Parent = hub
		points[i] = point
	end
	local lines: { Beam } = {}
	for i = 1, 8 do
		table.insert(
			lines,
			softBeam(points[i], points[(i + 2) % 8 + 1], {
				color = ColorSequence.new(STAR_WHITE, STAR),
				width0 = 0.3,
				width1 = 0.3,
				transparency = NumberSequence.new(0.25),
			}, hub)
		)
	end
	local floor = CFrame.new(center + UP * 0.12)
	every(duration, function(elapsed)
		local r = radius * easeOut(elapsed / 0.3) + 0.05
		rings[1].set(floor * CFrame.Angles(0, elapsed * 0.8, 0), r)
		rings[2].set(floor * CFrame.Angles(0, -elapsed * 0.5, 0), r * 1.1)
		rings[3].set(floor * CFrame.Angles(0, elapsed * 1.6, 0), r * 0.62)
		rings[4].set(floor * CFrame.Angles(0, -elapsed * 1.2, 0), r * 0.3)
		for i, point in points do
			local angle = (i - 1) / 8 * math.pi * 2
			point.Position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * r * 0.97
		end
		return true
	end, function()
		fadeBeams(lines, 0.35)
		for _, ring in rings do
			ring.fade(0.45)
		end
	end)
end

local function windColumn(base: Vector3, height: number, radius: number, duration: number)
	U.pillar(base, WIND, radius, height, duration, Enum.Material.ForceField, 0.55)
	local foot, head = worldAnchor(base, UP), worldAnchor(base + UP * height, UP)
	local beams = {
		softBeam(foot, head, {
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = radius * 2.4,
			width1 = radius * 3.6,
			transparency = NumberSequence.new({ key(0, 0.85), key(0.12, 0.5), key(0.85, 0.6), key(1, 1) }),
			texture = SMOKE,
			speed = 7,
			length = 12,
		}),
		softBeam(foot, head, {
			color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
			width0 = radius * 0.5,
			width1 = radius * 0.25,
			transparency = NumberSequence.new({ key(0, 0.6), key(0.1, 0.3), key(0.9, 0.5), key(1, 1) }),
		}),
		softBeam(foot, head, {
			color = ColorSequence.new(WIND, WIND_DEEP),
			width0 = radius * 5,
			width1 = radius * 6,
			transparency = NumberSequence.new({ key(0, 0.95), key(0.2, 0.86), key(1, 1) }),
			texture = SMOKE,
			speed = 3,
			length = 20,
			emission = 0.6,
		}),
	}
	task.delay(duration * 0.55, fadeBeams, beams, duration * 0.45, { foot, head })
	local holder = U.newPart({
		Size = Vector3.new(radius * 2, 1, radius * 2),
		Transparency = 1,
		CFrame = CFrame.new(base),
	})
	local gusts = windEmitter(holder, {
		Size = NumberSequence.new({ key(0, radius * 0.6), key(1, radius * 1.5) }),
		Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new(height * 1.1, height * 1.6),
		SpreadAngle = Vector2.new(6, 6),
		Drag = 1.5,
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Disc,
		Rate = 90,
	})
	local rising = windEmitter(holder, {
		Texture = SPARKLE,
		Color = ColorSequence.new(WIND_WHITE),
		LightEmission = 1,
		Transparency = NumberSequence.new({ key(0, 0.3), key(1, 1) }),
		Size = NumberSequence.new({ key(0, 0.35), key(1, 0) }),
		Squash = NumberSequence.new(4),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(height * 1.8, height * 2.4),
		SpreadAngle = Vector2.new(4, 4),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Disc,
		Rate = 70,
	})
	task.delay(duration * 0.75, function()
		gusts.Enabled = false
		rising.Enabled = false
	end)
	task.delay(duration + 1, holder.Destroy, holder)
	Soft.helix(function()
		return base, base + UP * height
	end, radius * 1.4, 4, 0.5, 2.5, 0.9, duration)
	U.burst(base + UP * 0.5, {
		texture = SMOKE,
		color = Color3.fromRGB(196, 204, 194),
		count = 22,
		size = radius * 1.8,
		speed = NumberRange.new(22, 44),
		lifetime = NumberRange.new(0.5, 0.9),
		transparency = 0.5,
		lightEmission = 0,
		drag = 4,
		spread = 85,
		direction = UP,
	})
	windRing(base + UP * 0.3, UP, radius, radius * 5, 0.5)
	lightRing(base + UP * 0.2, UP, radius, radius * 4, 0.4, WIND_WHITE)
	U.groundCracks(base, 8, radius * 3, WIND, 1.2)
	U.groundRocks(base, 8, radius * 2, 1.3)
	U.debris(base, 12, 45, 0.7)
	U.light(base + UP * 4, WIND, 5, 40, duration)
end

type Circle = { update: (number, number) -> (), blowApart: () -> () }

local function skyCircle(center: Vector3, radius: number): Circle
	local rings = {
		outer = softRing({
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 0.5,
			width1 = 0.5,
			transparency = NumberSequence.new(0.25),
		}),
		glitter = softRing({
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 1.3,
			width1 = 1.3,
			transparency = NumberSequence.new(0.35),
			texture = SPARKLE,
			wrap = true,
			length = 2,
			speed = 3,
		}),
		wind = softRing({
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 2.4,
			width1 = 2.4,
			transparency = NumberSequence.new(0.62),
			texture = SMOKE,
			speed = 3,
			length = 6,
		}),
		inner = softRing({
			color = ColorSequence.new(WIND_WHITE),
			width0 = 0.35,
			width1 = 0.35,
			transparency = NumberSequence.new(0.35),
		}),
		slant = softRing({
			color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
			width0 = 0.3,
			width1 = 0.3,
			transparency = NumberSequence.new(0.45),
		}),
		cross = softRing({
			color = ColorSequence.new(WIND_WHITE, STAR),
			width0 = 0.25,
			width1 = 0.25,
			transparency = NumberSequence.new(0.5),
		}),
	}
	local spokes: { { Attachment } } = {}
	for _ = 1, 12 do
		local a0 = Instance.new("Attachment")
		a0.Parent = rings.outer.hub
		local a1 = Instance.new("Attachment")
		a1.Parent = rings.outer.hub
		table.insert(spokes, { a0, a1 })
		softBeam(a0, a1, {
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 0.2,
			width1 = 0.05,
			transparency = NumberSequence.new({ key(0, 0.4), key(1, 0.8) }),
		}, rings.outer.hub)
	end
	local current = 0
	local circle = {}
	function circle.update(t: number, open: number)
		local r = radius * open + 0.05
		current = r
		-- (Out of sight until it opens.)
		local at = CFrame.new(if open > 0 then center else center + UP * 5000)
		rings.outer.set(at * CFrame.Angles(0, t * 0.6, 0), r)
		rings.glitter.set(at * CFrame.Angles(0, -t * 0.35, 0), r * 1.07)
		rings.wind.set(at * CFrame.Angles(0, -t * 1.1, 0), r * 0.86)
		rings.inner.set(at * CFrame.Angles(0, t * 1.8, 0), r * 0.34)
		rings.slant.set(at * CFrame.Angles(0, t * 0.8, 0) * CFrame.Angles(rad(70), 0, 0), r * 1.05)
		rings.cross.set(at * CFrame.Angles(0, -t * 0.7 + 1.2, 0) * CFrame.Angles(rad(-62), 0, 0), r * 1.12)
		for i, pair in spokes do
			local angle = i / #spokes * math.pi * 2
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			pair[1].Position = out * r * 0.38
			pair[2].Position = out * r * 0.84
		end
	end
	function circle.blowApart()
		local from = current
		local frames: { [string]: CFrame } = {}
		for name, ring in rings do
			frames[name] = ring.hub.CFrame
		end
		every(0.45, function(elapsed)
			local grow = from * (1 + elapsed * 2.5)
			for name, ring in rings do
				ring.set(frames[name], grow * (if name == "inner" then 0.34 else 1))
			end
			return true
		end)
		for _, ring in rings do
			ring.fade(0.45)
		end
	end
	return circle
end

local function wingsOfWind(character: Model, duration: number)
	local torso = character:FindFirstChild("Torso") :: BasePart?
	if not torso then
		return
	end
	type WingFeather = { vane: BasePart, glow: BasePart, side: number, index: number, length: number }
	local feathers: { WingFeather } = {}
	local trails: { Trail } = {}
	local shedding: { ParticleEmitter } = {}
	for side = -1, 1, 2 do
		for i = 1, 7 do
			local length = 5 + i * 0.8
			local vane = Soft.newWedge({
				Size = Vector3.new(0.12, 0.9, length),
				Color = WIND_WHITE,
				Material = Enum.Material.ForceField,
				Transparency = 0.15,
			})
			if i >= 5 then
				table.insert(
					shedding,
					windEmitter(vane, {
						Size = NumberSequence.new({ key(0, 0.8), key(1, 2.4) }),
						Lifetime = NumberRange.new(0.3, 0.6),
						Speed = NumberRange.new(2, 6),
						Drag = 3,
						Rate = 12,
						Enabled = false, -- (until the wings are posed)
					})
				)
			end
			local glow = U.newPart({ Size = Vector3.new(0.05, 1.9, length + 0.8), Color = WIND, Transparency = 0.82 })
			if i % 2 == 1 then
				-- Wind streaming off the feather tips as they beat.
				table.insert(
					trails,
					Soft.trail(
						glow,
						Vector3.new(0, 0.6, -(length + 0.8) / 2),
						Vector3.new(0, -0.6, -(length + 0.8) / 2),
						{
							color = ColorSequence.new(WIND_WHITE, WIND),
							transparency = NumberSequence.new({ key(0, 0.45), key(1, 1) }),
							lifetime = 0.3,
							off = true,
						}
					)
				)
			end
			table.insert(feathers, { vane = vane, glow = glow, side = side, index = i, length = length })
		end
	end
	every(duration, function(elapsed)
		if not torso.Parent then
			return false
		end
		local open = easeOut(elapsed / 0.3)
		local fold = math.clamp((elapsed - (duration - 0.25)) / 0.25, 0, 1)
		local spread = open * (1 - fold)
		local beat = math.sin(elapsed * 5) * 0.08
		local frame = torso.CFrame
		for _, f in feathers do
			local angle = rad(8 + (f.index - 1) * 15) * spread + beat
			local out = (
				frame.RightVector * f.side * math.cos(angle)
				+ frame.UpVector * math.sin(angle)
				- frame.LookVector * 0.35
			).Unit
			local base = (frame * CFrame.new(f.side * 0.45, 0.8, 0.55)).Position
			local length = f.length * (0.3 + 0.7 * spread)
			local pose = CFrame.lookAt(base, base + out, frame.LookVector) * CFrame.new(0, 0, -length / 2)
			f.vane.Size = Vector3.new(0.12, 0.9, length)
			f.vane.CFrame = pose
			f.glow.Size = Vector3.new(0.05, 1.9, length + 0.8)
			f.glow.CFrame = pose
		end
		for _, trail in trails do
			Soft.beginTrail(trail)
		end
		for _, emitter in shedding do
			emitter.Enabled = true
		end
		return true
	end, function()
		for _, trail in trails do
			Soft.endTrail(trail)
		end
		for _, f in feathers do
			Soft.fadeOut({ f.vane, f.glow }, 0.25)
		end
	end)
end

type Blade = {
	set: (Vector3, Vector3, number) -> (),
	tip: Attachment,
	dissolve: () -> (),
}

local function windBlade(): Blade
	local hub = U.newPart({ Size = Vector3.one, Transparency = 1 })
	local base = Instance.new("Attachment")
	base.Parent = hub
	local point = Instance.new("Attachment")
	point.Parent = hub
	local tipAnchor = worldAnchor(Vector3.zero)
	local layers = {
		softBeam(base, point, {
			color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
			width0 = 1.4,
			width1 = 0.45,
			transparency = NumberSequence.new({ key(0, 0.45), key(0.12, 0.05), key(0.88, 0.08), key(1, 0.5) }),
		}, hub),
		softBeam(base, point, {
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 2.8,
			width1 = 1.2,
			transparency = NumberSequence.new({ key(0, 0.75), key(0.2, 0.35), key(1, 0.45) }),
			texture = SPARKLE,
			wrap = true,
			length = 3,
			speed = 8,
		}, hub),
		softBeam(base, point, {
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 6,
			width1 = 2.5,
			transparency = NumberSequence.new({ key(0, 0.85), key(0.2, 0.5), key(1, 0.72) }),
			texture = SMOKE,
			speed = 3,
			length = 8,
		}, hub),
		softBeam(base, point, {
			color = ColorSequence.new(WIND, WIND_DEEP),
			width0 = 14,
			width1 = 7,
			transparency = NumberSequence.new({ key(0, 0.95), key(0.25, 0.82), key(1, 0.9) }),
			texture = SMOKE,
			speed = -2,
			length = 10,
		}, hub),
	}
	local flow = windEmitter(hub, {
		Size = NumberSequence.new({ key(0, 1.5), key(1, 4) }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(15, 15),
		EmissionDirection = Enum.NormalId.Front,
		Shape = Enum.ParticleEmitterShape.Box,
		Drag = 2,
		Rate = 60,
	})
	local glitter = windEmitter(hub, {
		Texture = SPARKLE,
		Color = ColorSequence.new(STAR),
		LightEmission = 1,
		Transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) }),
		Size = NumberSequence.new({ key(0, 0.6), key(1, 0) }),
		Lifetime = NumberRange.new(0.3, 0.7),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = 50,
	})
	local light = Instance.new("PointLight")
	light.Color = STAR
	light.Range = 50
	light.Brightness = 5
	light.Parent = hub
	local tip = Soft.softStar(5)
	local last = { from = Vector3.zero, to = Vector3.zero, length = 0 }
	local stopHelix = Soft.helix(function()
		return last.from, last.to
	end, 2.4, 3, 0.45, 3, 0.8, 4, WIND)
	local blade = { tip = tipAnchor }
	function blade.set(from: Vector3, direction: Vector3, length: number)
		local to = from + direction * length
		last.from, last.to, last.length = from, to, length
		hub.Size = Vector3.new(2, 2, math.max(length, 0.2))
		hub.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
		base.CFrame = CFrame.new(0, 0, length / 2)
		point.CFrame = CFrame.new(0, 0, -length / 2)
		tip.place(to, os.clock() * 6)
		tipAnchor.CFrame = CFrame.new(to)
	end
	function blade.dissolve()
		flow.Enabled = false
		glitter.Enabled = false
		light.Enabled = false
		stopHelix()
		for i = 1, 8 do
			windPuff(last.from:Lerp(last.to, i / 8), 2.5)
		end
		starDust(last.to, 16, 30)
		tip.fade(0.25)
		fadeBeams(layers, 0.3, { hub, tipAnchor })
	end
	return blade
end

local function windSeam(top: Vector3, ground: Vector3)
	local direction = (ground - top).Unit
	local from, to = top - direction * 90, ground + direction * 2
	local a = worldAnchor(from, direction)
	local b = worldAnchor(to, direction)
	local beams = {
		softBeam(a, b, {
			color = ColorSequence.new(STAR_WHITE),
			width0 = 1.3,
			width1 = 1.3,
			transparency = NumberSequence.new({ key(0, 0.7), key(0.2, 0.05), key(1, 0.05) }),
		}),
		softBeam(a, b, {
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 3,
			width1 = 2.4,
			transparency = NumberSequence.new({ key(0, 0.8), key(0.25, 0.3), key(1, 0.35) }),
			texture = SPARKLE,
			wrap = true,
			length = 4,
			speed = -20,
		}),
		softBeam(a, b, {
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 9,
			width1 = 7,
			transparency = NumberSequence.new({ key(0, 0.9), key(0.25, 0.5), key(1, 0.55) }),
			texture = SMOKE,
			speed = 8,
			length = 20,
		}),
		softBeam(a, b, {
			color = ColorSequence.new(WIND, WIND_DEEP),
			width0 = 40,
			width1 = 30,
			transparency = NumberSequence.new({ key(0, 0.96), key(0.3, 0.86), key(1, 0.88) }),
			texture = SMOKE,
			speed = 4,
			length = 30,
		}),
	}
	for i = 0, 8 do
		windPuff(from:Lerp(to, 0.35 + 0.65 * i / 8), 4, -direction)
	end
	task.delay(0.35, function()
		for _, beam in beams do
			U.tween(beam, 0.5, { Width0 = beam.Width0 * 0.05, Width1 = beam.Width1 * 0.05 })
		end
		fadeBeams(beams, 0.55, { a, b })
	end)
end

-- Feathers of light drifting down round him afterwards.
local function featherFall(center: Vector3, count: number, duration: number)
	for i = 1, count do
		local feather = Soft.newWedge({
			Size = Vector3.new(0.05, 0.3, 1),
			Color = WIND_WHITE,
			Material = Enum.Material.ForceField,
			Transparency = 1,
		})
		U.tween(feather, 0.3, { Transparency = Soft.sheerValue(0.2) })
		local from = center + Vector3.new(math.random(-70, 70) / 10, 5 + math.random() * 7, math.random(-70, 70) / 10)
		local life = duration * (0.7 + math.random() * 0.3)
		every(life, function(elapsed)
			local drift =
				Vector3.new(math.sin(elapsed * 2.6 + i) * 1.3, -elapsed * 2.4, math.cos(elapsed * 2 + i) * 0.8)
			feather.CFrame = CFrame.new(from + drift)
				* CFrame.Angles(elapsed * 1.5 + i, elapsed * 2.5, math.sin(elapsed * 4 + i) * 0.7)
			return true
		end, function()
			Soft.fadeOut({ feather }, 0.3)
		end)
	end
end

-- Starlight sifting down over an area, glittering as it falls.
local function starfall(center: Vector3, radius: number, duration: number)
	local sky = U.newPart({
		Size = Vector3.new(radius * 2, 1, radius * 2),
		Transparency = 1,
		CFrame = CFrame.new(center + UP * 16),
	})
	local motes = windEmitter(sky, {
		Texture = SPARKLE,
		Color = ColorSequence.new(STAR_WHITE, STAR),
		LightEmission = 1,
		Transparency = NumberSequence.new({ key(0, 1), key(0.15, 0.2), key(0.8, 0.4), key(1, 1) }),
		Size = NumberSequence.new({ key(0, 0.35), key(0.5, 0.55), key(1, 0) }),
		Lifetime = NumberRange.new(1.4, 2.2),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(12, 12),
		EmissionDirection = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
		Drag = 0.5,
		Rate = 45,
	})
	task.delay(duration, function()
		motes.Enabled = false
	end)
	task.delay(duration + 2.5, sky.Destroy, sky)
end

-- The cutscene

export type ZephyrSky = {
	update: (number) -> (), -- (run every frame on its own: seconds since it opened)
	gather: () -> (),
	flare: () -> (),
	scatter: () -> (),
	close: (number) -> (),
}

local SKY_GOLD = Color3.fromRGB(255, 214, 140)
local SKY_SUN = Color3.fromRGB(255, 240, 200)

local function zephyrSky(plan: SaintPlan.Plan): ZephyrSky
	local center = plan.center
	local made: { Instance } = {}
	local beams: { { beam: Beam, base: number } } = {}
	local function track(beam: Beam, base: number): Beam
		table.insert(beams, { beam = beam, base = base })
		table.insert(made, beam)
		beam.Transparency = NumberSequence.new(1)
		return beam
	end
	local function anchor(position: Vector3, axis: Vector3?): Attachment
		local attachment = worldAnchor(position, axis)
		table.insert(made, attachment)
		return attachment
	end

	local toSun = Cinematic.DawnSun()
	toSun = Vector3.new(toSun.X, math.max(toSun.Y, 0.1), toSun.Z).Unit
	local sun = center + toSun * 420
	local halos: { { part: BasePart, base: number } } = {}
	for i, layer in { { 46, 0.5, SKY_SUN }, { 110, 0.76, SKY_GOLD }, { 210, 0.9, SKY_GOLD } } do
		local part = U.newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, layer[1], layer[1]),
			CFrame = CFrame.lookAt(sun - toSun * i, center) * CFrame.Angles(0, rad(90), 0),
			Color = layer[3],
			Transparency = 1,
		})
		table.insert(made, part)
		table.insert(halos, { part = part, base = layer[2] })
	end
	local sunAnchor = anchor(sun)
	local sunUp = (UP - toSun * toSun.Y).Unit
	local sunSide = toSun:Cross(sunUp).Unit
	for i = 1, 9 do
		local angle = rad(-80 + (i - 1) * 20)
		local out = sunUp * math.cos(angle) + sunSide * math.sin(angle)
		track(
			softBeam(sunAnchor, anchor(sun + out * 360 - toSun * 60), {
				color = ColorSequence.new(SKY_SUN, SKY_GOLD),
				width0 = 26,
				width1 = 90,
				transparency = NumberSequence.new(0),
				emission = 1,
			}),
			0.92
		)
	end

	-- Stars of his star magic all over the sky, glittering.
	type Twinkle = { part: BasePart, phase: number, speed: number }
	local stars: { Twinkle } = {}
	for i = 1, 140 do
		local direction
		repeat
			direction = U.randomUnit()
		until direction.Y > 0.12
		local part = U.newPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (1 + math.random() * 1.8),
			CFrame = CFrame.new(center + direction * (280 + math.random() * 40)),
			Color = if i % 4 == 0 then STAR else STAR_WHITE,
			Transparency = 1,
		})
		table.insert(made, part)
		table.insert(stars, { part = part, phase = math.random() * 6.28, speed = 2 + math.random() * 4 })
	end

	-- Streams of wind sweeping across the sky, high over the fight.
	for i = 1, 6 do
		local angle = rad(i * 60 + math.random() * 20)
		local across = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local side = across:Cross(UP)
		local height = UP * (36 + i * 8)
		local from = center + height - across * 260 + side * (i * 14 - 50)
		local to = center + height + across * 260 + side * (i * 14 - 50)
		track(
			softBeam(anchor(from, across + UP * 0.15), anchor(to, across - UP * 0.15), {
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 14,
				width1 = 14,
				transparency = NumberSequence.new(0),
				texture = SMOKE,
				speed = 18 + i * 3,
				length = 60,
				curve0 = 40,
				curve1 = 40,
			}),
			0.88
		)
	end

	local eye = center + UP * 92
	type Swirl = { ring: Soft.Ring, radius: number, height: number, speed: number, tilt: number }
	local swirls: { Swirl } = {}
	for i, radius in { 34, 62, 95, 132, 175 } do
		local ring = softRing({
			color = ColorSequence.new(WIND_WHITE, if i % 2 == 0 then WIND else WIND_DEEP),
			width0 = 6 + i * 3,
			width1 = 6 + i * 3,
			transparency = NumberSequence.new(0),
			texture = SMOKE,
			speed = 6,
			length = 30,
			segments = 24,
		})
		table.insert(made, ring.hub)
		for _, beam in ring.beams do
			track(beam, 0.7 + i * 0.04)
		end
		table.insert(
			swirls,
			{ ring = ring, radius = radius, height = -i * 7, speed = 0.5 - i * 0.07, tilt = (i % 2) * 4 - 2 }
		)
	end
	type Arm = { from: Attachment, to: Attachment, beam: Beam, phase: number }
	local arms: { Arm } = {}
	for i = 1, 6 do
		local from, to = anchor(eye), anchor(eye)
		local beam = softBeam(from, to, {
			color = ColorSequence.new(WIND, WIND_WHITE),
			width0 = 22,
			width1 = 5,
			transparency = NumberSequence.new(0),
			texture = SMOKE,
			speed = 10,
			length = 40,
			segments = 20,
		})
		track(beam, 0.76)
		table.insert(arms, { from = from, to = to, beam = beam, phase = (i - 1) * math.pi / 3 })
	end

	-- The star in its eye, and light falling from it onto them.
	local star = Soft.softStar(30)
	for _, part in star.parts do
		table.insert(made, part)
		part.Transparency = 1
	end
	local starLight = star.parts[1]:FindFirstChildOfClass("PointLight")
	if starLight then
		starLight.Enabled = false
	end
	local eyeAnchor = anchor(eye)
	local fall: { Beam } = {}
	for i = 1, 6 do
		local angle = (i - 1) * math.pi / 3
		local foot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 16 - UP * 6
		table.insert(
			fall,
			track(
				softBeam(eyeAnchor, anchor(foot), {
					color = ColorSequence.new(SKY_SUN, STAR),
					width0 = 16,
					width1 = 4,
					transparency = NumberSequence.new(0),
					emission = 1,
				}),
				0.94
			)
		)
	end

	local shown = 0 -- 0 to 1: how far in it's faded
	local target = 0
	-- Eased toward their targets every frame (nothing jumps).
	local scale, scaleTarget = 1, 1 -- the star in the eye
	local spin, spinTarget = 1, 1
	local spread, spreadTarget = 1, 1
	local sky = {} :: ZephyrSky
	function sky.update(t: number)
		shown += (target - shown) * 0.08
		scale += (scaleTarget - scale) * 0.12
		spin += (spinTarget - spin) * 0.05
		spread += (spreadTarget - spread) * 0.06
		local a = smooth(shown)
		for _, entry in beams do
			entry.beam.Transparency = NumberSequence.new(1 - (1 - entry.base) * a)
		end
		for _, halo in halos do
			halo.part.Transparency = 1 - (1 - halo.base) * a
		end
		for _, twinkle_ in stars do
			local glint = 0.5 + 0.5 * math.sin(t * twinkle_.speed + twinkle_.phase)
			twinkle_.part.Transparency = 1 - a * (0.25 + 0.45 * glint)
		end
		-- The spiral turns; its arms curl in from the outer ring to the eye.
		for _, swirl in swirls do
			swirl.ring.set(
				CFrame.new(eye + UP * swirl.height) * CFrame.Angles(rad(swirl.tilt), t * swirl.speed * spin, 0),
				swirl.radius * spread
			)
		end
		for _, arm in arms do
			local angle = arm.phase + t * 0.35 * spin
			local outer = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local inner = Vector3.new(math.cos(angle + 1.6), 0, math.sin(angle + 1.6))
			local outerAt = eye + outer * 160 * spread - UP * 30
			local innerAt = eye + inner * 22 * spread
			-- Leaving the rim along it, arriving round the eye.
			Soft.aim(arm.from, outerAt, Vector3.new(-outer.Z, 0, outer.X))
			Soft.aim(arm.to, innerAt, Vector3.new(-inner.Z, 0, inner.X))
			arm.beam.CurveSize0 = 70 * spread
			arm.beam.CurveSize1 = 18 * spread
		end
		star.place(eye, t * 0.6)
		local glow = a * (0.25 + 0.15 * math.sin(t * 3))
		for i, part in star.parts do
			part.Transparency = if i == 1 then 1 - 0.6 * a * math.min(scale, 1) else 1 - glow * 1.6 * math.min(scale, 1)
			if i == 1 then
				part.Size = Vector3.one * 30 * 0.32 * math.max(scale, 0.05)
			end
		end
	end
	function sky.gather()
		-- The blade grows toward it: the star swells, the spiral turns faster.
		scaleTarget, spinTarget = 1.8, 2.2
	end
	function sky.flare()
		-- The strike: the star flares white and the light falls hard.
		scale, scaleTarget = 2.8, 2.2
		for _, beam in fall do
			beam.Width0, beam.Width1 = 30, 10
			U.tween(beam, 0.5, { Width0 = 16, Width1 = 4 })
		end
		twinkle(eye, 60, STAR, 0.45)
		U.flash(eye, SKY_SUN, 40, 0.3)
	end
	function sky.scatter()
		-- They fall: the spiral blows apart and thins out, the star goes out.
		spinTarget, spreadTarget, scaleTarget = 3, 1.6, 0
	end
	local born = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		sky.update(os.clock() - born)
	end)
	function sky.close(duration: number)
		target = 0
		task.delay(duration + 0.6, function()
			connection:Disconnect()
			for _, instance in made do
				instance:Destroy()
			end
		end)
	end
	sky.update(0)
	target = 1
	return sky
end

export type Spirit = { raise: () -> (), dissolve: (BasePart) -> (), close: () -> () }

local SPIRIT_HEIGHT = 84

local function sylphSpirit(plan: SaintPlan.Plan): Spirit
	local made: { Instance } = {}
	local H = SPIRIT_HEIGHT
	type Limb = { a: Attachment, b: Attachment, beam: Beam, base: number, curve: number }
	local limbs: { [string]: Limb } = {}
	local function limb(name: string, style: Soft.BeamStyle, base: number, curve: number?)
		local a, b = worldAnchor(plan.center), worldAnchor(plan.center)
		local beam = softBeam(a, b, style)
		beam.Transparency = NumberSequence.new(1)
		table.insert(made, a)
		table.insert(made, b)
		table.insert(made, beam)
		limbs[name] = { a = a, b = b, beam = beam, base = base, curve = curve or 0 }
	end
	local wind = ColorSequence.new(WIND_WHITE, WIND)
	limb("body", {
		color = ColorSequence.new(WIND_WHITE),
		width0 = 0.09 * H,
		width1 = 0.14 * H,
		transparency = NumberSequence.new(0),
	}, 0.82)
	limb("head", {
		color = ColorSequence.new(WIND_WHITE),
		width0 = 0.1 * H,
		width1 = 0.085 * H,
		transparency = NumberSequence.new(0),
	}, 0.76)
	limb("dress", {
		color = wind,
		width0 = 0.17 * H,
		width1 = 0.02 * H,
		transparency = NumberSequence.new(0),
		texture = SMOKE,
		speed = -8,
		length = 30,
	}, 0.86, 0.25)
	for _, side in { "L", "R" } do
		limb("arm" .. side, {
			color = ColorSequence.new(WIND_WHITE),
			width0 = 0.035 * H,
			width1 = 0.022 * H,
			transparency = NumberSequence.new(0),
		}, 0.84, 0.1)
		limb("wingHigh" .. side, {
			color = wind,
			width0 = 0.2 * H,
			width1 = 0.05 * H,
			transparency = NumberSequence.new(0),
			texture = SMOKE,
			speed = 5,
			length = 26,
		}, 0.9, 0.18)
		limb("wingLow" .. side, {
			color = wind,
			width0 = 0.16 * H,
			width1 = 0.03 * H,
			transparency = NumberSequence.new(0),
			texture = SMOKE,
			speed = 5,
			length = 26,
		}, 0.92, 0.15)
	end
	for i = 1, 3 do
		limb("hair" .. i, {
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 0.07 * H,
			width1 = 0.006 * H,
			transparency = NumberSequence.new(0),
			texture = SMOKE,
			speed = 6 + i,
			length = 18,
		}, 0.82, 0.14)
	end
	local halo = softRing({
		color = ColorSequence.new(STAR_WHITE, STAR),
		width0 = 0.012 * H,
		width1 = 0.012 * H,
		transparency = NumberSequence.new(0.2),
	})
	table.insert(made, halo.hub)
	local core = U.newPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(plan.center) })
	table.insert(made, core)
	local glow = Soft.glow(core, WIND_WHITE, 0.3 * H, 0.88)

	local shown, target = 0, 1 -- faded in
	local raise, raiseTarget = 0, 0 -- arms open to arms over her head
	local shrink = 0 -- pouring herself into him
	local into: BasePart? = nil
	local born = os.clock()
	local function place(t: number)
		local camera = workspace.CurrentCamera.CFrame.Position
		local toward = Vector3.new(plan.center.X - camera.X, 0, plan.center.Z - camera.Z)
		toward = if toward.Magnitude > 1 then toward.Unit else plan.forward
		local heart = plan.center + toward * 150 + UP * (34 + math.sin(t * 1.2) * 1.5)
		local look = (heart - camera).Unit
		local r = look:Cross(UP).Unit
		local u = r:Cross(look).Unit
		local size = H * (1 - 0.9 * shrink)
		if into and shrink > 0 then
			heart = heart:Lerp(into.Position + UP * 3, shrink * shrink)
		end
		local function at(x: number, y: number): Vector3
			return heart + (r * x + u * y) * size
		end
		local function pose(name: string, from: Vector3, to: Vector3, axisFrom: Vector3?, axisTo: Vector3?)
			local limb_ = limbs[name]
			Soft.aim(limb_.a, from, axisFrom or (to - from))
			Soft.aim(limb_.b, to, axisTo or (to - from))
			limb_.beam.CurveSize0 = limb_.curve * size
			limb_.beam.CurveSize1 = -limb_.curve * size * 0.5
		end
		local sway = math.sin(t * 1.7) * 0.02
		pose("body", at(0, 0.25), at(0.01, -0.14))
		pose("head", at(0, 0.285), at(0, 0.375))
		pose("dress", at(0.01, -0.12), at(0.16 + sway * 3, -0.66), -u, (-u + r * 0.6).Unit)
		-- Arms: open, palms out, or lifted over her head.
		for i, side in { "L", "R" } do
			local s = if i == 1 then -1 else 1
			local open = Vector3.new(s * 0.4, 0.3 + sway, 0)
			local up = Vector3.new(s * 0.15, 0.58, 0)
			local hand = open:Lerp(up, smooth(raise))
			pose("arm" .. side, at(s * 0.07, 0.22), at(hand.X, hand.Y), r * s + u * 0.4, u)
			local beat = math.sin(t * 1.4) * 0.04
			pose("wingHigh" .. side, at(s * 0.04, 0.18), at(s * 0.56, 0.64 + beat), r * s + u * 1.6, r * s + u * 0.4)
			pose("wingLow" .. side, at(s * 0.04, 0.1), at(s * 0.46, -0.16 + beat * 0.6), r * s - u * 0.2, r * s - u)
		end
		-- Hair streaming out in the wind.
		for i = 1, 3 do
			local wave = math.sin(t * 2.2 + i) * 0.03
			local tip = ({ Vector3.new(-0.4, 0.26), Vector3.new(-0.46, 0.36), Vector3.new(-0.34, 0.14) })[i]
			pose("hair" .. i, at(0, 0.37), at(tip.X, tip.Y + wave), -r + u * 0.3, -r - u * 0.2)
		end
		halo.set(CFrame.fromMatrix(at(0, 0.43), r, -look), 0.08 * size)
		core.CFrame = CFrame.new(at(0, 0.08))
		local a = smooth(shown) * (1 - shrink)
		for _, limb_ in limbs do
			limb_.beam.Transparency =
				NumberSequence.new({ key(0, 1 - (1 - limb_.base) * a), key(1, 1 - (1 - limb_.base) * a * 0.6) })
		end
		for _, beam in halo.beams do
			beam.Transparency = NumberSequence.new(1 - 0.5 * a)
		end
		glow.Enabled = a > 0.05
	end
	local connection = RunService.RenderStepped:Connect(function()
		shown += (target - shown) * 0.06
		raise += (raiseTarget - raise) * 0.1
		place(os.clock() - born)
	end)
	local closed = false
	local spirit = {} :: Spirit
	function spirit.raise()
		raiseTarget = 1
	end
	function spirit.dissolve(root: BasePart)
		-- Down into him as a stream of wind, getting smaller as she goes.
		into = root
		every(0.45, function(elapsed)
			shrink = smooth(elapsed / 0.45)
			return true
		end, function()
			shrink = 1
			spirit.close()
		end)
		windPuff(root.Position + UP * 3, 6)
		twinkle(root.Position + UP * 3, 10, STAR, 0.3)
	end
	function spirit.close()
		if closed then
			return
		end
		closed = true
		target = 0
		task.delay(0.8, function()
			connection:Disconnect()
			glow.Enabled = false
			for _, instance in made do
				instance:Destroy()
			end
		end)
	end
	place(0)
	return spirit
end

local function play(data, character: Model, root: BasePart, context: Context)
	local anims = context.anims
	local target: Model? = data.target
	local targetRoot = target and U.getRoot(target)
	local plan = SaintPlan.Plan(data.origin, data.start, data.floorY)
	local times = SaintPlan.Times
	local cuts = times.Cuts
	local dive, landed = SaintPlan.DiveTimes()
	local started = os.clock()
	local mine = U.isLocal(character) or U.isLocal(target)
	local near = (workspace.CurrentCamera.CFrame.Position - plan.center).Magnitude < 120
	local forward, right = plan.forward, plan.right
	local center = plan.center
	local charge = cuts[1] - SaintPlan.Charge
	-- Every pass through them: the eight cuts, then the X.
	local passes = table.clone(cuts)
	table.insert(passes, times.Cross)

	PoseAnimator.SettleLift(character, times.Length)

	local unsheer = Soft.sheer(SHEER)
	task.delay(times.Length + 0.3, unsheer)

	-- Both of them stay readable through everything.
	outline(character, WIND_WHITE, times.Length)
	outline(target, STAR, times.Land)

	local nearby = mine or (workspace.CurrentCamera.CFrame.Position - plan.center).Magnitude < 180
	local sky: ZephyrSky? = nil
	local spirit: Spirit? = nil
	if nearby then
		task.delay(times.Lift - 0.35, function()
			local lift = Cinematic.Dawn(0.9)
			local opened = zephyrSky(plan)
			sky = opened
			task.delay(0.6, function()
				spirit = sylphSpirit(plan)
			end)
			task.delay(times.Land + 0.6 - (times.Lift - 0.35), function()
				opened.close(1.2)
				lift(1.4)
			end)
		end)
	end
	local bloom: BloomEffect? = nil
	local depth: DepthOfFieldEffect? = nil
	if mine or near then
		local effect = Instance.new("BloomEffect")
		effect.Intensity = 0
		effect.Size = 28
		effect.Threshold = 0.9
		effect.Parent = workspace.CurrentCamera
		U.tween(effect, 0.4, { Intensity = 0.6 })
		bloom = effect
	end
	if mine then
		local effect = Instance.new("DepthOfFieldEffect")
		effect.FarIntensity = 0.3
		effect.NearIntensity = 0.1
		effect.InFocusRadius = 16
		effect.FocusDistance = 20
		effect.Parent = workspace.CurrentCamera
		depth = effect
	end
	task.delay(times.Length + 0.2, function()
		for _, effect in { bloom, depth } :: { PostEffect? } do
			if effect then
				U.tween(
					effect,
					0.4,
					if effect:IsA("BloomEffect") then { Intensity = 0 } else { FarIntensity = 0, NearIntensity = 0 }
				)
				task.delay(0.45, effect.Destroy, effect)
			end
		end
	end)
	local function punch(intensity: number, decay: number)
		if bloom then
			bloom.Intensity = intensity
			U.tween(bloom, decay, { Intensity = 0.6 })
		end
	end

	local seal = Soft.softStar(3)
	local bindRings = {
		softRing({
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 0.4,
			width1 = 0.4,
			transparency = NumberSequence.new(0.3),
		}),
		softRing({
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 1.2,
			width1 = 1.2,
			transparency = NumberSequence.new(0.55),
			texture = SMOKE,
			speed = 3,
			length = 4,
		}),
		softRing({
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 0.7,
			width1 = 0.7,
			transparency = NumberSequence.new(0.45),
			texture = SPARKLE,
			wrap = true,
			length = 1.2,
			speed = 2,
		}),
	}
	local shackles: { Soft.Star } = {}
	for _ = 1, 3 do
		table.insert(shackles, Soft.softStar(0.9))
	end
	local swirlHolder = U.newPart({ Size = Vector3.one * 9, Transparency = 1, CFrame = CFrame.new(center) })
	local swirl = windEmitter(swirlHolder, {
		Transparency = NumberSequence.new({ key(0, 1), key(0.3, 0.85), key(1, 1) }),
		Size = NumberSequence.new({ key(0, 3), key(1, 8) }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Sphere,
		Drag = 1,
		Rate = 0,
	})

	local stars: { Soft.Star } = {}
	local starAnchors: { Attachment } = {}
	local lines: { Beam } = {}
	for _ = 1, #plan.stars do
		table.insert(stars, Soft.softStar(2.4))
		table.insert(starAnchors, worldAnchor(center))
	end
	for i = 1, #plan.stars do
		local a, b = starAnchors[i], starAnchors[i % #plan.stars + 1]
		local stream = Soft.starStream(a, b, 0.55, 3)
		local thread = softBeam(a, b, {
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 0.12,
			width1 = 0.12,
			transparency = NumberSequence.new({ key(0, 0.3), key(0.5, 0.6), key(1, 0.3) }),
		})
		stream.Enabled = false
		thread.Enabled = false
		table.insert(lines, stream)
		table.insert(lines, thread)
	end
	local homeStar = Soft.softStar(1.8)
	local circle = skyCircle(center, SaintPlan.Ring + 3)
	local slashes: { Soft.Slash } = {}
	local blade: Blade? = nil
	local tailTop = worldAnchor(center, UP)
	local tailEnd = worldAnchor(center, UP)
	local tail = {
		softBeam(tailEnd, tailTop, {
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 1.6,
			width1 = 0.2,
			transparency = NumberSequence.new({ key(0, 0.1), key(1, 1) }),
		}),
		softBeam(tailEnd, tailTop, {
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 5,
			width1 = 1,
			transparency = NumberSequence.new({ key(0, 0.5), key(1, 1) }),
			texture = SMOKE,
			speed = -6,
			length = 10,
		}),
		softBeam(tailEnd, tailTop, {
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 2.6,
			width1 = 0.6,
			transparency = NumberSequence.new({ key(0, 0.3), key(1, 1) }),
			texture = SPARKLE,
			wrap = true,
			length = 2.5,
			speed = -10,
		}),
	}
	for _, beam in tail do
		beam.Enabled = false
	end
	local burst = false

	-- His sword, and the light pouring from the stars into the blade.
	local swordBlade = context.blade(character)
	local gathering: { Beam } = {}
	local gatherExtra: { Instance } = {}

	local bind = "CloverSaintZephyr" .. tostring(started)
	local function finish()
		pcall(function()
			RunService:UnbindFromRenderStep(bind)
		end)
	end
	RunService:BindToRenderStep(bind, Enum.RenderPriority.Camera.Value + 3, function()
		local t = os.clock() - started
		if t > times.Length + 0.1 then
			finish()
			return
		end
		if root.Parent then
			root.CFrame = SaintPlan.Attacker(plan, t)
		end
		local victim = SaintPlan.Victim(plan, math.min(t, times.Land))
		if targetRoot and targetRoot.Parent and t <= times.Land then
			targetRoot.CFrame = victim
		end

		if not burst then
			local at = victim.Position
			seal.place(at + victim.LookVector * 0.9 + UP * 0.4, t * 4)
			local grow = easeOut(t / 0.25)
			bindRings[1].set(CFrame.new(at + UP * 0.9) * CFrame.Angles(0, t * 3, 0), 2.6 * grow + 0.05)
			bindRings[2].set(CFrame.new(at - UP * 0.5) * CFrame.Angles(0, -t * 4, 0), 3 * grow + 0.05)
			bindRings[3].set(
				CFrame.new(at) * CFrame.Angles(0, t * 2, 0) * CFrame.Angles(rad(64), 0, 0),
				3.4 * grow + 0.05
			)
			for i, shackle in shackles do
				local angle = t * 3 + (i - 1) * math.pi * 2 / 3
				local ring = bindRings[1].hub.CFrame
				shackle.place(
					(ring * CFrame.new(math.cos(angle) * 2.6 * grow, 0, math.sin(angle) * 2.6 * grow)).Position,
					t * 6
				)
			end
			-- The stars open out of them one by one, joined up as they go.
			local placed: { Vector3 } = {}
			local opened: { boolean } = {}
			for i, star in stars do
				local open = math.clamp((t - times.Lift - i * 0.025) / 0.2, 0, 1)
				opened[i] = open > 0
				placed[i] = if open > 0 then center:Lerp(plan.stars[i], easeOut(open)) else center + UP * 5000
				star.place(placed[i], t * 2 + i)
				starAnchors[i].CFrame = CFrame.new(placed[i])
			end
			for i = 1, #stars do
				local shown = opened[i] and opened[i % #stars + 1]
				lines[i * 2 - 1].Enabled = shown
				lines[i * 2].Enabled = shown
			end
			circle.update(t, easeOut((t - times.Lift) / 0.35))
			-- His own star, under him while he waits, left behind when he goes.
			local home = if t < times.Hover - 0.1 then center + UP * 5000 else plan.hover - UP * 1.2
			homeStar.place(home, t * 3)
		end

		-- The blade: up out of his raised hands, then down along the strike.
		if blade then
			local hand, other = handOf(character, "Right"), handOf(character, "Left")
			local hands = if hand and other then hand:Lerp(other, 0.5) else root.Position + UP * 2.5
			local grow = easeOut((t - (times.Rise - 0.1)) / 0.35)
			local down = (plan.ground - (plan.top + UP * SaintPlan.Drift)).Unit
			local swing = smooth((t - dive) / 0.1)
			local arc = math.acos(math.clamp(UP:Dot(down), -1, 1))
			local direction = CFrame.fromAxisAngle(right, swing * arc):VectorToWorldSpace(UP)
			blade.set(hands, direction, SAINT_BLADE * grow + 0.5)
		end

		-- Falling like a meteor: a comet's tail of wind behind them.
		if t >= times.Burst and t <= times.Land then
			local length = 4 + 26 * math.clamp((t - times.Burst) / (times.Land - times.Burst), 0, 1)
			tailEnd.CFrame = CFrame.new(victim.Position)
			tailTop.CFrame = CFrame.new(victim.Position + UP * length)
			for _, beam in tail do
				beam.Enabled = true
			end
		end
	end)

	twinkle(plan.start + UP, 9, STAR, 0.35)
	U.flash(plan.start + UP, STAR_WHITE, 4, 0.15)
	lightRing(plan.start + UP, UP, 0.5, 7, 0.35)
	lightRing(plan.start + UP, forward, 0.5, 5, 0.3)
	starDust(plan.start + UP, 18, 26)
	windPuff(plan.start + UP, 4)
	local ground = Vector3.new(plan.start.X, plan.floorY, plan.start.Z)
	groundSigil(ground, 7, times.Lift + 0.5)
	windColumn(ground, SaintPlan.Height + 14, 3.4, times.Lift + 0.5)
	if targetRoot then
		U.spiral(targetRoot, WIND_WHITE, 4, 5, times.Lift, 4, 0.6, 0.3)
	end
	task.delay(0.25, function()
		context.play(character, anims.SaintAscend)
		windPuff(root.Position - UP * 2.5, 3, UP)
		U.spiral(root, WIND, 3, 4, times.Lift, 3, 0.5, 0.3)
		U.bodyTrail(character, WIND, times.Lift)
	end)
	if mine then
		CameraShake.FovKick(4)
	end

	-- The ground far below stirs: dust lifting off it in the downdraft of
	-- the fight over it.
	task.delay(times.Lift, function()
		local below = U.newPart({
			Size = Vector3.new(28, 1, 28),
			Transparency = 1,
			CFrame = CFrame.new(ground + UP * 0.5),
		})
		local stir = windEmitter(below, {
			Color = ColorSequence.new(Color3.fromRGB(205, 214, 204), Color3.fromRGB(170, 190, 175)),
			LightEmission = 0,
			Transparency = NumberSequence.new({ key(0, 1), key(0.3, 0.82), key(1, 1) }),
			Size = NumberSequence.new({ key(0, 3), key(1, 7) }),
			Lifetime = NumberRange.new(1.2, 1.8),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Top,
			Shape = Enum.ParticleEmitterShape.Disc,
			Rate = 14,
		})
		task.delay(times.Burst - times.Lift, function()
			stir.Enabled = false
		end)
		task.delay(times.Burst - times.Lift + 2, below.Destroy, below)
	end)

	task.delay(times.Lift, function()
		swirl.Rate = 22
		windRing(center, UP, 2, SaintPlan.Ring + 6, 0.5)
		lightRing(center, UP, 1, SaintPlan.Ring + 4, 0.45)
		U.shockwave(center, WIND, 2, SaintPlan.Ring * 2.4, 0.5)
		U.light(center, STAR, 6, 70, times.Burst - times.Lift)
		for i, at in plan.stars do
			task.delay(i * 0.025 + 0.15, function()
				twinkle(at, 4, STAR, 0.3)
				lightRing(at, (center - at).Unit, 0.3, 3.5, 0.3)
				local from, into = worldAnchor(at), worldAnchor(center)
				local ray = softBeam(from, into, {
					color = ColorSequence.new(STAR_WHITE, STAR),
					width0 = 0.9,
					width1 = 0.15,
					transparency = NumberSequence.new({ key(0, 0.3), key(1, 0.8) }),
				})
				fadeBeams({ ray }, 0.4, { from, into })
			end)
		end
	end)
	task.delay(times.Hover - 0.1, function()
		context.play(character, anims.SaintPoise)
	end)
	task.delay(times.Hover - 0.05, function()
		twinkle(plan.hover - UP * 1.2, 3, STAR, 0.3)
		windRing(plan.hover - UP * 1.4, UP, 0.5, 4, 0.35)
	end)

	local torso = character:FindFirstChild("Torso") :: BasePart?
	task.delay(charge, function()
		windPuff(plan.hover, 3, -plan.passes[1])
		windRing(plan.hover, plan.passes[1], 1, 6, 0.3)
		U.afterimage(character, WIND, 0.4)
		twinkle(plan.hover - UP * 1.2, 4, STAR, 0.25)
		if not torso then
			return
		end
		local dance = times.Rise - charge
		local trails = {
			Soft.trail(torso, Vector3.new(0, 1.7, 0), Vector3.new(0, -1.7, 0), {
				color = ColorSequence.new(WIND_WHITE, WIND),
				transparency = NumberSequence.new({ key(0, 0.4), key(0.4, 0.65), key(1, 1) }),
				width = NumberSequence.new({ key(0, 1), key(1, 0.35) }),
				lifetime = 0.75,
				texture = SMOKE,
			}),
			Soft.trail(torso, Vector3.new(0, 0.3, 0), Vector3.new(0, -0.3, 0), {
				color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
				transparency = NumberSequence.new({ key(0, 0.1), key(1, 1) }),
				lifetime = 0.22,
			}),
		}
		local aura = Soft.glow(torso, WIND, 5, 0.9)
		local lamp = Instance.new("PointLight")
		lamp.Color = WIND
		lamp.Range = 18
		lamp.Brightness = 3
		lamp.Shadows = false
		lamp.Parent = torso
		local dust = windEmitter(torso, {
			Texture = SPARKLE,
			Color = ColorSequence.new(STAR_WHITE, STAR),
			LightEmission = 1,
			Transparency = NumberSequence.new({ key(0, 0.3), key(1, 1) }),
			Size = NumberSequence.new({ key(0, 0.45), key(1, 0) }),
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(0.5, 2),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 60,
		})
		local swordTrails: { Trail } = {}
		local swordGlitter: ParticleEmitter? = nil
		if swordBlade then
			table.insert(
				swordTrails,
				Soft.trail(swordBlade, Vector3.new(0, -2.6, 0), Vector3.new(0, 2.7, 0), {
					color = ColorSequence.new(WIND_WHITE, WIND),
					transparency = NumberSequence.new({ key(0, 0.1), key(1, 1) }),
					lifetime = 0.22,
					faceCamera = false,
				})
			)
			swordGlitter = windEmitter(swordBlade, {
				Texture = SPARKLE,
				Color = ColorSequence.new(STAR_WHITE, STAR),
				LightEmission = 1,
				Transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) }),
				Size = NumberSequence.new({ key(0, 0.4), key(1, 0) }),
				Lifetime = NumberRange.new(0.2, 0.4),
				Speed = NumberRange.new(0),
				Shape = Enum.ParticleEmitterShape.Box,
				Rate = 70,
			})
		end
		task.delay(dance, function()
			for _, trail in trails do
				Soft.endTrail(trail)
			end
			for _, trail in swordTrails do
				Soft.endTrail(trail)
			end
			aura.Enabled = false
			dust.Enabled = false
			U.tween(lamp, 0.3, { Brightness = 0 })
			task.delay(0.35, lamp.Destroy, lamp)
			task.delay(1, aura.Destroy, aura)
			task.delay(1, dust.Destroy, dust)
			if swordGlitter then
				swordGlitter.Enabled = false
				task.delay(0.6, swordGlitter.Destroy, swordGlitter)
			end
		end)
	end)

	for i, at in passes do
		local direction = plan.passes[i]
		local last = i == #passes
		local swing = if last or i % 2 == 1 then anims.SaintCut else anims.SaintCutBack
		task.delay(math.max(at - 0.05, 0), function()
			context.play(character, swing)
		end)
		local side, lift = across(direction)
		local scale = if last then 1.5 else 0.68 + i * 0.04
		local reach = if last then 13 else 10
		-- The crescent is swept along with him (centred on him being in the
		-- middle of them).
		task.delay(math.max(at - 0.025, 0), function()
			if burst then
				return
			end
			local bend = (if i % 2 == 1 then lift else side) * (2.4 + i * 0.25) * (if i % 4 < 2 then 1 else -1)
			table.insert(
				slashes,
				Soft.windSlash(center - direction * reach, center + direction * reach, bend, scale, 0.05)
			)
		end)
		task.delay(at, function()
			if burst then
				return
			end
			-- The stroke through them.
			local a0, a1 =
				worldAnchor(center - direction * 5, direction), worldAnchor(center + direction * 6, direction)
			local stroke = {
				softBeam(a0, a1, {
					color = ColorSequence.new(STAR_WHITE),
					width0 = 0.15,
					width1 = 0.7,
					transparency = NumberSequence.new({ key(0, 0.6), key(0.5, 0), key(1, 0.3) }),
				}),
				softBeam(a0, a1, {
					color = ColorSequence.new(WIND_WHITE, WIND),
					width0 = 0.6,
					width1 = 2.6,
					transparency = NumberSequence.new({ key(0, 0.8), key(0.5, 0.35), key(1, 0.55) }),
					texture = SMOKE,
					speed = 6,
					length = 4,
				}),
			}
			fadeBeams(stroke, 0.16, { a0, a1 })
			twinkle(center + direction * 0.4, if last then 9 else 4.5, STAR, 0.22)
			lightRing(center, direction, 0.8, if last then 12 else 6, if last then 0.35 else 0.22)
			streaks(center + direction, if last then 30 else 12, if last then 110 else 80, direction)
			windPuff(center + direction * 2, if last then 4 else 2, direction)
			if target then
				U.highlight(target, WIND_WHITE, 0.1, 0.6)
			end
			if last then
				-- The X: its mirror stroke at once, a wider shock, a flash.
				local mirror = Vector3.new(direction.X, -direction.Y, direction.Z).Unit
				table.insert(
					slashes,
					Soft.windSlash(center - mirror * reach, center + mirror * reach, right * 3, scale, 0.05)
				)
				windRing(center, side, 2, 20, 0.4)
				U.shockwave(center, WIND, 2, 22, 0.35)
				starDust(center, 30, 40)
				-- Rays of light thrown out from them every way.
				local rays: { Beam } = {}
				local ends: { Attachment } = {}
				local hub = worldAnchor(center)
				table.insert(ends, hub)
				for k = 1, 12 do
					local out = U.randomUnit()
					local tip = worldAnchor(center + out * (14 + math.random() * 8), out)
					table.insert(ends, tip)
					table.insert(
						rays,
						softBeam(hub, tip, {
							color = ColorSequence.new(STAR_WHITE, if k % 2 == 0 then STAR else WIND_WHITE),
							width0 = 1.6,
							width1 = 0.05,
							transparency = NumberSequence.new({ key(0, 0.15), key(1, 0.9) }),
						})
					)
				end
				for _, ray in rays do
					U.tween(ray, 0.3, { Width0 = 0.1 })
				end
				fadeBeams(rays, 0.32, ends)
				punch(1.2, 0.35)
				if mine or near then
					U.colorGrade({ Brightness = 0.08, Contrast = 0.25, Saturation = -0.3 }, 0, 0.05, 0.18)
				end
				if mine then
					CameraShake.FovKick(4)
				end
			end
		end)
		-- Round the star after this pass (the X has none: he goes up).
		local star = plan.stars[i]
		if star and passes[i + 1] then
			local tipAt = (at + passes[i + 1]) / 2
			task.delay(tipAt - 0.02, function()
				if burst then
					return
				end
				U.afterimage(character, WIND, 0.35)
				twinkle(star, 3.2, STAR, 0.22)
				lightRing(star, (center - star).Unit, 0.3, 3, 0.25)
				windPuff(star, 1.4)
				-- The lines of light meeting at this star flare up and settle.
				local count = #plan.stars
				for _, line in { (i - 1) % count + 1, (i - 2) % count + 1 } do
					local stream = lines[line * 2 - 1]
					if stream.Parent then
						stream.Width0, stream.Width1 = 1.6, 1
						U.tween(stream, 0.3, { Width0 = 0.55, Width1 = 0.33 })
					end
				end
			end)
		end
	end

	task.delay(times.Rise - 0.35, function()
		if spirit then
			spirit.raise()
		end
	end)
	task.delay(times.Rise + 0.05, function()
		if spirit then
			spirit.dissolve(root)
		end
	end)
	task.delay(times.Rise + 0.12, function()
		if sky then
			sky.gather()
		end
	end)
	task.delay(times.Strike, function()
		if sky then
			sky.flare()
		end
		if mine then
			Soft.focusLines(0.35)
		end
	end)
	task.delay(times.Burst, function()
		if sky then
			sky.scatter()
		end
		if mine then
			Soft.focusLines(0.3)
		end
	end)
	task.delay(times.Length, function()
		if spirit then
			spirit.close()
		end
	end)
	task.delay(times.Rise - 0.1, function()
		context.play(character, anims.SaintRise)
		local hold = dive - (times.Rise - 0.1)
		context.hideSword(character, hold + 0.4)
		local made = windBlade()
		made.set(root.Position + UP * 2.5, UP, 0.5) -- (in his hands from the first frame)
		blade = made
		wingsOfWind(character, hold + 0.3)
		windPuff(plan.top, 5)
		windRing(plan.top, forward, 2, 16, 0.45)
		lightRing(plan.top, UP, 1, 14, 0.4)
		U.shockwave(plan.top, WIND, 2, 18, 0.45)
		local gather = U.newPart({ Size = Vector3.one * 34, Transparency = 1, CFrame = CFrame.new(plan.top + UP * 12) })
		local inward = windEmitter(gather, {
			Size = NumberSequence.new({ key(0, 4), key(1, 1) }),
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(22, 34),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			Rate = 70,
		})
		task.delay(hold, function()
			inward.Enabled = false
		end)
		task.delay(hold + 1, gather.Destroy, gather)
		U.light(plan.top, STAR, 6, 60, hold + 0.2)
		-- The heavens open over him: a shaft of wind up into the sky.
		local low, high = worldAnchor(plan.top, UP), worldAnchor(plan.top + UP * 220, UP)
		local shaft = {
			softBeam(low, high, {
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 7,
				width1 = 20,
				transparency = NumberSequence.new({ key(0, 0.6), key(1, 1) }),
				texture = SMOKE,
				speed = 5,
				length = 30,
			}),
			softBeam(low, high, {
				color = ColorSequence.new(STAR_WHITE),
				width0 = 1.2,
				width1 = 3,
				transparency = NumberSequence.new({ key(0, 0.3), key(1, 1) }),
			}),
			softBeam(low, high, {
				color = ColorSequence.new(STAR_WHITE, STAR),
				width0 = 3,
				width1 = 6,
				transparency = NumberSequence.new({ key(0, 0.5), key(1, 1) }),
				texture = SPARKLE,
				wrap = true,
				length = 5,
				speed = 12,
			}),
		}
		task.delay(hold, fadeBeams, shaft, 0.3, { low, high })
		-- Sylph circles him, then dives into the blade.
		local sylph = Soft.makeSprite(1.4)
		local into = dive - 0.18
		every(into - (times.Rise - 0.1) + 0.1, function(elapsed)
			local t = elapsed + (times.Rise - 0.1)
			local head = root.Position + UP * 2.5
			if t < into then
				local angle = elapsed * 7
				local at = head + Vector3.new(math.cos(angle) * 3.5, math.sin(elapsed * 5) * 1.2, math.sin(angle) * 3.5)
				sylph.place(CFrame.lookAt(at, at + Vector3.new(-math.sin(angle), 0, math.cos(angle))), elapsed)
			else
				local a = math.clamp((t - into) / 0.1, 0, 1)
				sylph.place(CFrame.new(head:Lerp(head + UP * SAINT_BLADE, a)), elapsed)
			end
			return true
		end, function()
			sylph.fade(0.1)
			twinkle(root.Position + UP * (SAINT_BLADE + 2.5), 8, STAR, 0.3)
			windPuff(root.Position + UP * (SAINT_BLADE + 2.5), 4)
		end)
		if mine then
			CameraShake.FovKick(3)
		end
	end)
	task.delay(times.Rise + 0.12, function()
		local current = blade
		if burst or not current then
			return
		end
		-- Every star pours its light up into the blade's point.
		for i, anchor in starAnchors do
			table.insert(gathering, Soft.starStream(anchor, current.tip, 0.8, 9))
			twinkle(plan.stars[i], 3, STAR, 0.25)
		end
		local from = worldAnchor(center)
		table.insert(gathering, Soft.starStream(from, current.tip, 1.2, 12))
		table.insert(gatherExtra, from)
	end)

	task.delay(dive, function()
		context.play(character, anims.SaintStrike)
		fadeBeams(gathering, 0.15, gatherExtra)
		local top = plan.top + UP * SaintPlan.Drift
		local down = (plan.ground - top).Unit
		table.insert(slashes, Soft.windSlash(top + UP * 38, top + down * 38, -forward * 30, 3, 0.1))
	end)
	task.delay(times.Strike, function()
		windSeam(plan.top + UP * SaintPlan.Drift, plan.ground)
		twinkle(center, 18, STAR, 0.35)
		U.flash(center, STAR_WHITE, 9, 0.25)
		for k = 1, 3 do
			windRing(center, UP, 2, 14 + k * 9, 0.3 + k * 0.08, if k == 2 then STAR else WIND)
		end
		lightRing(center, UP, 1, 30, 0.35)
		lightRing(center, forward, 1, 18, 0.3)
		U.shockwave(center, WIND, 3, 36, 0.4)
		windPuff(center, 6)
		U.burst(center, {
			color = STAR_WHITE,
			count = 40,
			size = 0.6,
			speed = NumberRange.new(60, 120),
			lifetime = NumberRange.new(0.2, 0.45),
			streaks = true,
			spread = 180,
		})
		U.light(center, STAR_WHITE, 8, 90, 0.45)
		-- Hit-stop: both of them frozen for a beat.
		PoseAnimator.Freeze(character, 0.12)
		if target then
			PoseAnimator.Freeze(target, 0.12)
		end
		punch(1.5, 0.5)
		if mine or near then
			-- An impact frame: a flash of stark black and white.
			U.colorGrade({ Brightness = 0.25, Contrast = 0.85, Saturation = -1 }, 0, 0.07, 0.22)
		end
		-- (No shake: the cutscene camera's own eased zoom is the blow.)
	end)
	task.delay(landed, function()
		context.play(character, anims.SaintLand)
		local feet = plan.ground - UP * 2.6
		windPuff(feet, 4, UP)
		windRing(feet, UP, 1, 12, 0.4)
		lightRing(feet + UP * 0.1, UP, 0.5, 8, 0.3, WIND_WHITE)
		U.groundCracks(feet, 6, 6, WIND, 1.4)
		U.burst(feet, {
			texture = SMOKE,
			color = Color3.fromRGB(196, 204, 194),
			count = 14,
			size = 3,
			speed = NumberRange.new(14, 30),
			lifetime = NumberRange.new(0.4, 0.8),
			transparency = 0.5,
			lightEmission = 0,
			drag = 4,
			spread = 80,
			direction = UP,
		})
		if blade then
			blade.dissolve()
			blade = nil
		end
	end)

	-- Every hanging cut bursts, one after another; the stars burst; the rings
	-- blow apart; they fall.
	task.delay(times.Burst, function()
		burst = true
		swirl.Enabled = false
		task.delay(1.5, swirlHolder.Destroy, swirlHolder)
		for i, slash in slashes do
			task.delay((i - 1) * 0.03, function()
				slash.flare()
				task.delay(0.1, function()
					windPuff(slash.apex, 2.5)
					starDust(slash.apex, 8, 24)
					twinkle(slash.apex, 4, STAR, 0.2)
					slash.fade(0.25)
				end)
			end)
		end
		for i, star in stars do
			twinkle(plan.stars[i], 6, STAR, 0.3)
			starDust(plan.stars[i], 10, 30)
			windPuff(plan.stars[i], 2)
			star.fade(0.2)
		end
		homeStar.fade(0.2)
		fadeBeams(lines, 0.2, starAnchors)
		circle.blowApart()
		seal.fade(0.15)
		for _, shackle in shackles do
			shackle.fade(0.15)
		end
		for _, ring in bindRings do
			ring.fade(0.15)
		end
		local nova = Soft.softStar(9)
		nova.place(center, 0)
		task.delay(0.1, nova.fade, 0.45)
		twinkle(center, 22, STAR, 0.45)
		windRing(center, UP, 3, 40, 0.5, STAR)
		windRing(center, forward, 3, 32, 0.45)
		lightRing(center, UP, 2, 46, 0.5)
		U.shockwave(center, STAR, 3, 44, 0.5)
		windPuff(center, 8)
		U.burst(center, {
			color = STAR,
			count = 50,
			size = 0.6,
			speed = NumberRange.new(40, 100),
			lifetime = NumberRange.new(0.3, 0.6),
			streaks = true,
			spread = 180,
		})
		if targetRoot then
			U.spiral(targetRoot, WIND_WHITE, 3, -5, times.Land - times.Burst, 3, 0.6, 0.2)
			-- A comet's trail of smoke and glitter as they fall.
			local smoke = windEmitter(targetRoot, {
				Size = NumberSequence.new({ key(0, 2), key(1, 5) }),
				Transparency = NumberSequence.new({ key(0, 0.5), key(1, 1) }),
				Lifetime = NumberRange.new(0.4, 0.8),
				Speed = NumberRange.new(1, 3),
				Rate = 70,
			})
			local glitter = windEmitter(targetRoot, {
				Texture = SPARKLE,
				Color = ColorSequence.new(STAR_WHITE, STAR),
				LightEmission = 1,
				Transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) }),
				Size = NumberSequence.new({ key(0, 0.6), key(1, 0) }),
				Lifetime = NumberRange.new(0.4, 0.8),
				Speed = NumberRange.new(1, 4),
				SpreadAngle = Vector2.new(180, 180),
				Rate = 60,
			})
			task.delay(times.Land - times.Burst, function()
				smoke.Enabled = false
				glitter.Enabled = false
				task.delay(1, smoke.Destroy, smoke)
				task.delay(1, glitter.Destroy, glitter)
			end)
			-- Rings of wind torn off them as they fall.
			for k = 1, 4 do
				task.delay(k * 0.07, function()
					if targetRoot.Parent then
						windRing(targetRoot.Position, UP, 1, 5 + k, 0.25)
					end
				end)
			end
		end
		if mine or near then
			U.colorGrade({ Brightness = 0.1, TintColor = Color3.fromRGB(255, 246, 222) }, 0, 0.08, 0.3)
		end
		punch(1.2, 0.4)
		if mine then
			CameraShake.FovKick(5)
		end
	end)

	task.delay(times.Land, function()
		fadeBeams(tail, 0.2, { tailTop, tailEnd })
		featherFall(plan.ground, 18, times.Length - times.Land + 1.2)
	end)
	task.delay(times.Length - 0.35, function()
		local hand = handOf(character, "Right")
		if hand then
			U.glint(hand, 2, STAR_WHITE)
			twinkle(hand, 3, STAR, 0.3)
		end
	end)
	task.delay(times.Length + 0.3, finish)

	if not mine then
		return
	end
	local origin, start, top, landing = plan.origin.Position, plan.start, plan.top, plan.ground
	local function him(t: number): Vector3
		return SaintPlan.Attacker(plan, t).Position
	end
	local function them(t: number): Vector3
		return SaintPlan.Victim(plan, math.min(t, times.Land)).Position
	end
	-- Through the dance the camera follows him smoothly (not every dart).
	local followed: Vector3? = nil
	local lastT = 0
	local function follow(t: number): Vector3
		local dt = math.max(t - lastT, 0)
		lastT = t
		local target = him(t)
		followed = if followed then followed:Lerp(target, math.min(dt * 5, 1)) else target
		return followed :: Vector3
	end
	local x = plan.passes[#plan.passes]
	local xSide = Vector3.new(x.X, 0, x.Z)
	xSide = if xSide.Magnitude > 1e-3 then xSide.Unit:Cross(UP) else right
	type Shot = {
		from: number,
		to: number,
		blend: number, -- ease in from the last shot over this long (0: a cut)
		get: (number, number) -> (Vector3, Vector3, number, number), -- eye, focus, roll (degrees), field of view
	}
	local shots: { Shot } = {
		{
			from = 0,
			to = 0.35,
			blend = 0,
			get = function(u, t)
				local e = smooth(u)
				local eye = (origin - forward * 9.5 + right * 3.5 + UP * 2.4):Lerp(
					origin - forward * 7.5 + right * 3 + UP * 2,
					e
				)
				return eye, them(t):Lerp(him(t), 0.55) + UP * 0.3, -2 * e, 74 - 6 * e
			end,
		},
		{
			from = 0.35,
			to = times.Hover + 0.05,
			blend = 0.3,
			get = function(u, t)
				local e = smooth(u)
				local victim, attacker = them(t), him(t)
				local middle = victim:Lerp(attacker, 0.5)
				local angle = rad(-20 + 60 * e)
				local around = forward * math.sin(angle) + right * math.cos(angle)
				local eye = Vector3.new(start.X, start.Y + 1.5 + (middle.Y - start.Y) * 0.85, start.Z) + around * 16
				return eye, middle + UP, 3, 84 - 6 * e
			end,
		},
		{
			from = times.Hover + 0.05,
			to = cuts[1] - 0.04,
			blend = 0,
			get = function(u, _)
				local e = smooth(u)
				local behind = plan.hover - plan.passes[1] * (9 - 2 * e) + UP * 2.6 + right * 2.2
				return behind, center + UP * 0.5, -3, 72 - 4 * e
			end,
		},
		{
			from = cuts[1] - 0.04,
			to = times.Cross - 0.12,
			blend = 0.35,
			get = function(u, t)
				local angle = rad(-35) + u * rad(110)
				local radius = 23 - 3 * u
				local around = -forward * math.cos(angle) + right * math.sin(angle)
				local eye = center + around * radius + UP * (5 + 3 * math.sin(u * math.pi))
				return eye, center:Lerp(follow(t), 0.18), -3 + 2 * u, 66 + 6 * u
			end,
		},
		{
			from = times.Cross - 0.12,
			to = times.Rise - 0.05,
			blend = 0.25,
			get = function(u, t)
				local e = smooth(u)
				-- Pulling back as he rises out of it, to keep them both.
				local rise = smooth((u - 0.35) / 0.65)
				local look = center:Lerp(him(t), 0.5 * rise)
				return center + xSide * (20 + 12 * rise) + UP * (1 + 4 * e), look, 3 * e, 66 - 4 * e + 10 * rise
			end,
		},
		{
			from = times.Rise - 0.05,
			to = dive,
			blend = 0.3,
			get = function(u, _)
				local e = smooth(u)
				local angle = rad(-30 + 50 * e)
				local around = right * math.cos(angle) + forward * math.sin(angle)
				local reveal = smooth((u - 0.15) / 0.6)
				local eye = center - UP * 4 + around * (24 + 10 * reveal)
				local focus = center:Lerp(top + UP * 6, 0.44):Lerp(top + UP * 19, reveal)
				return eye, focus, -5 + 3 * e, 78 - 4 * e
			end,
		},
		{
			from = dive,
			to = times.Burst + 0.05,
			blend = 0,
			get = function(u, _)
				return center + right * (48 + 6 * u) + UP * (1 + u), center - UP * 4, 0, 80 + 3 * u
			end,
		},
		{
			from = times.Burst + 0.05,
			to = times.Land + 0.1,
			blend = 0.25,
			get = function(_, t)
				-- Held still, panning down with them as they fall (so nothing
				-- lurches when they hit).
				local eye = start + UP * 18 + right * 30 + forward * 6
				return eye, them(t):Lerp(start, 0.4), 4, 80
			end,
		},
		{
			from = times.Land + 0.1,
			to = times.Length + 0.3,
			blend = 0.3,
			get = function(u, _)
				local e = smooth(u)
				-- In front of him, the crater and the tornado behind him,
				-- coming round to his face.
				local angle = rad(140 + 40 * e)
				local around = forward * math.cos(angle) + right * math.sin(angle)
				return landing + around * (13 - 5 * e) + UP * (2.4 - 0.6 * e),
					landing + UP * (1.6 + 0.2 * e),
					0,
					70 - 12 * e
			end,
		},
	}
	-- A blow's zoom: in fast, eased back out (never a jump).
	local function blow(t: number, at: number, amount: number): number
		if t < at then
			return 0
		end
		local u = (t - at) / 0.08
		return amount * u * math.exp(1 - u)
	end
	local function zoom(t: number): number
		local total = 0
		for i, at in passes do
			total += blow(t, at, if i == #passes then 6 else 2)
		end
		return total + blow(t, times.Strike, 8) + blow(t, times.Burst, 4)
	end
	local function evaluate(shot: Shot, t: number, hold: boolean): (CFrame, number)
		local u = (t - shot.from) / math.max(shot.to - shot.from, 1e-3)
		if hold then
			u = math.clamp(u, 0, 1)
		end
		local eye, focus, roll, fov = shot.get(u, t)
		return CFrame.lookAt(eye, focus) * CFrame.Angles(0, 0, rad(roll)), fov
	end
	Cinematic.Camera(function(t)
		local index = #shots
		for i, shot in shots do
			if t < shot.to then
				index = i
				break
			end
		end
		local shot = shots[index]
		local cframe, fov = evaluate(shot, t, true)
		local previous = shots[index - 1]
		if shot.blend > 0 and previous and t - shot.from < shot.blend then
			-- Eased both ways, from where the last shot is now: no jolt
			-- starting or finishing the move.
			local b = smooth((t - shot.from) / shot.blend)
			local fromFrame, fromFov = evaluate(previous, t, false)
			cframe = fromFrame:Lerp(cframe, b)
			fov = fromFov + (fov - fromFov) * b
		end
		fov -= zoom(t)
		if depth then
			depth.FocusDistance = (cframe.Position - him(t)).Magnitude
		end
		return cframe, fov
	end, times.Length + 0.3)
end

-- The crater, and a tornado of wind tearing up out of it, starlight
-- falling round it.
local function impact(position: Vector3)
	twinkle(position + UP * 2, 14, STAR, 0.35)
	U.flash(position + UP * 2, STAR_WHITE, 10, 0.25)
	U.shockwave(position, WIND, 3, 50, 0.6)
	U.shockwave(position, STAR, 3, 36, 0.5)
	windRing(position + UP * 0.3, UP, 2, 30, 0.55)
	windRing(position + UP * 0.6, UP, 2, 40, 0.75, STAR)
	lightRing(position + UP * 0.2, UP, 1, 34, 0.5)
	U.groundCracks(position, 14, 16, WIND, 2.5)
	U.groundRocks(position, 14, 10, 2.2)
	U.debris(position, 26, 60, 1.2)
	windColumn(position, 70, 4.5, 1.2) -- (narrow enough to stand clear of him)
	starfall(position, 18, 1.4)
	U.burst(position + UP, {
		texture = SMOKE,
		color = Color3.fromRGB(170, 178, 170),
		count = 26,
		size = 6,
		speed = NumberRange.new(20, 45),
		lifetime = NumberRange.new(0.6, 1.2),
		lightEmission = 0,
		transparency = 0.45,
		spread = 80,
		direction = UP,
		drag = 3,
	})
	U.light(position, STAR, 6, 60, 0.9)
	-- Bystanders feel it; the cutscene's own camera never shakes.
	local me = Players.LocalPlayer.Character
	local watching = me ~= nil and me:GetAttribute("Cinematic") == true
	if not watching and (workspace.CurrentCamera.CFrame.Position - position).Magnitude < 80 then
		CameraShake.Add(0.2)
	end
end

function Saint.Handle(data, character: Model, root: BasePart, context: Context)
	local phase = data.phase
	if phase == "Flick" then
		-- The star flies out ahead of him on a thread of starlight.
		context.play(character, context.anims.Conjunction)
		local hand = handOf(character, "Right") or root.Position
		local forward = root.CFrame.LookVector
		local range: number = data.range or 15
		local star = Soft.softStar(1.4)
		local from, at = worldAnchor(hand), worldAnchor(hand)
		local thread = Soft.starStream(from, at, 0.4, 6)
		twinkle(hand, 2.5, STAR, 0.2)
		windPuff(hand, 1.5, forward)
		every(0.2, function(elapsed)
			local position = hand + forward * range * (elapsed / 0.2)
			star.place(position, elapsed * 20)
			at.CFrame = CFrame.new(position)
			return true
		end, function()
			star.fade(0.15)
			fadeBeams({ thread }, 0.2, { from, at })
		end)
	elseif phase == "Whiff" then
		local at = root.Position + root.CFrame.LookVector * 15
		windPuff(at, 2)
		starDust(at, 10, 14)
	elseif phase == "Begin" then
		play(data, character, root, context)
	elseif phase == "Impact" then
		impact(data.position)
	end
end

return Saint
