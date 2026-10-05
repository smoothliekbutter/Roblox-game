--[[
	Prince of Wind (Yuno): Saint Spirit of Zephyr (Full-Crown 4), drawn.
	The flight is Shared/SaintZephyr (the server holds them both on it);
	this draws it, about 6 seconds:

	  the bind    the flicked star strikes them and a seal of starlight
	              closes on them; a magic circle opens on the ground under
	              them and a column of wind tears up out of it, carrying them
	              high into the sky, him flying up beside them.
	  the stars   eight stars open round them in the sky, joined in one line
	              of streaming starlight (an eight-pointed star) over turning
	              rings of light and wind; light pours from each into them.
	  the dance   from his own star he charges through them, then never
	              stops: out round a star, back through them, every pass a
	              cut you see him make (his sword sweeping a sheet of wind,
	              the cut left hanging in the air), the ribbon of wind he
	              trails painting a flower of eight petals round them, faster
	              and faster. Then a rising X.
	  the blade   up and over to the top: wings of wind open, Sylph dives
	              into his raised hands and a colossal blade of wind and
	              starlight grows out of them, wind spiralling up it, the
	              light of every star in the constellation pouring into it,
	              a shaft of wind opening into the sky over him.
	  the strike  one stroke straight down through them: the swing leaves
	              a crescent of wind the height of the sky and a seam of
	              light from the heavens to the ground.
	  the fall    every cut left hanging bursts, one after another, the
	              stars burst, the rings blow apart; they fall like a meteor,
	              a comet's tail of wind behind them, into a crater, a
	              tornado of wind tearing up out of it, starlight falling,
	              him standing with his back to it.

	Everything is wind and light you can see through, and both of them are
	outlined through it, so the fight stays readable. The light changes
	only a little (a touch brighter, greener, a soft bloom). The camera
	moves smoothly: eased shots and eased blends, no shake.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SaintPlan = require(ReplicatedStorage:WaitForChild("Shared").SaintZephyr)
local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local Cinematic = require(script.Parent.Parent.Parent.Cinematic)
local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local Soft = require(script.Parent.Soft)

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

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------

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

-- A magic circle on the ground: rings of starlight and wind turning
-- opposite ways, an eight-pointed star drawn in one line inside them.
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

-- A column of wind tearing up out of the ground: a broad stream of wind
-- flowing up it round a bright core, ribbons spiralling up round it, gusts
-- and streaks racing up it, and the ground bursting where it comes out.
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

-- The constellation's rings, round them and turning: a ring of starlight
-- and a chain of sparkles outside it, a ring of wind turning the other way,
-- a small ring round them, two rings standing up through them crossed at a
-- slant, and twelve spokes of light. They open out of them, and at the end
-- are blown apart.
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

-- Wings of wind: two fans of shimmering, see-through feathers open out of
-- his back for the strike, wind streaming off them, beat slowly and fold.
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

-- The colossal blade: a white-hot core in a glittering edge inside layers
-- of wind flowing up it, ribbons of wind spiralling up it, wind and
-- sparkles pouring off it, a star at its point. See-through where it's
-- nearest him.
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

-- The strike's seam through the whole sky: a white-hot line, wind racing
-- down it and a broad haze of wind round it, there and gone.
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
		U.tween(feather, 0.3, { Transparency = 0.2 })
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

---------------------------------------------------------------------------
-- The cutscene
---------------------------------------------------------------------------

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

	-- Both of them stay readable through everything.
	outline(character, WIND_WHITE, times.Length)
	outline(target, STAR, times.Land)

	-- For whoever's watching close up, the light shifts ever so slightly
	-- (a touch brighter, greener and richer, nothing darker) and a bloom
	-- makes the wind and starlight glow; for the two of them, depth of field
	-- on him.
	if mine or near then
		U.colorGrade(
			{ TintColor = Color3.fromRGB(238, 255, 244), Saturation = 0.12, Contrast = 0.06, Brightness = 0.03 },
			0.6,
			times.Length - 0.5,
			0.9
		)
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

	-- The seal that binds them: a star on them and rings of starlight and
	-- wind turning round them (little stars riding them), wind swirling
	-- round them while they hang there.
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

	-- The constellation: the eight stars, joined in the order he goes round
	-- them (one line drawing an eight-pointed star) by streams of sparkles
	-- over thin lines of light; and his own star where he waits.
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
			-- Swung over in front of him (round his right), from straight up
			-- to down along the strike, at an even sweep of the angle.
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

	-- The bind: the star strikes them, a magic circle opens on the ground
	-- under them and a column of wind tears up out of it and carries them
	-- up; he flies up beside them.
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

	-- The constellation opens round them; wind swirls round them; light
	-- pours from every star into them.
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

	-- The dance: he leaves a ribbon of wind behind him (painting the
	-- petals round them), his sword sweeps a sheet of wind as it swings and
	-- sheds starlight, and he glows.
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

	-- Each pass: the swing (just before he's in the middle of them), the cut
	-- itself (a stroke of light through them, left hanging as a crescent of
	-- wind), and round each star a kick off it (a ghost of him left there).
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
			end)
		end
	end

	-- High above them: wings of wind open, wind pours in, Sylph dives into
	-- his hands and the blade grows out of them; the light of every star
	-- pours into it.
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

	-- The strike: the swing leaves a crescent of wind the height of the
	-- sky, and a seam of light from the heavens to the ground; it goes
	-- through them (a beat of hit-stop), and he lands.
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
		if mine then
			CameraShake.Add(0.18)
			CameraShake.FovKick(7)
		end
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

	-- The camera: every shot moving, smoothly (eased, no shake), him always
	-- in shot. Pushing in over his shoulder as the star strikes; craning up
	-- the column with them; behind him at his star as the constellation
	-- opens (he charges away from us, through them); circling them wide
	-- through the dance; side-on for the X; from below them up at him and
	-- the blade; wide for the strike; falling with them; and round him at
	-- the crater to his face, his back to it.
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
				local eye = (origin - forward * 6 + right * 2.5 + UP * 2.8):Lerp(
					origin - forward * 3 + right * 1.8 + UP * 2.2,
					e
				)
				return eye, them(t) + UP * 0.5, -2 * e, 72 - 10 * e
			end,
		},
		{
			from = 0.35,
			to = times.Hover + 0.05,
			blend = 0.3,
			get = function(u, t)
				local e = smooth(u)
				local victim = them(t)
				local angle = rad(-20 + 60 * e)
				local around = forward * math.sin(angle) + right * math.cos(angle)
				local eye = Vector3.new(start.X, start.Y + 1.5 + (victim.Y - start.Y) * 0.8, start.Z) + around * 13
				return eye, victim:Lerp(him(t), 0.35) + UP, 3, 84 - 8 * e
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
				local radius = 30 - 4 * u
				local around = -forward * math.cos(angle) + right * math.sin(angle)
				local eye = center + around * radius + UP * (6 + 3 * math.sin(u * math.pi))
				return eye, center:Lerp(follow(t), 0.18), -3 + 2 * u, 72 + 6 * u
			end,
		},
		{
			from = times.Cross - 0.12,
			to = times.Rise - 0.05,
			blend = 0.25,
			get = function(u, t)
				local e = smooth(u)
				local look = center:Lerp(him(t), smooth((u - 0.35) / 0.65))
				return center + xSide * (20 - 2 * e) + UP * (1 + 4 * e), look, 3 * e, 66 - 4 * e
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
				local eye = center - UP * (10 - 3 * e) + around * (14 - 4 * e)
				return eye, top + UP * 4, -5 + 3 * e, 72 - 16 * e
			end,
		},
		{
			from = dive,
			to = times.Burst + 0.05,
			blend = 0,
			get = function(u, _)
				return center + right * (50 + 6 * u) + UP * (2 + u), center - UP * 8, 0, 74 + 6 * u
			end,
		},
		{
			from = times.Burst + 0.05,
			to = times.Land + 0.1,
			blend = 0.25,
			get = function(_, t)
				local victim = them(t)
				return victim + right * 16 + UP * 10 + forward * 6, victim:Lerp(start, 0.4), 4, 82
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
	-- Where a shot puts the camera at `t` (past its end it carries on as
	-- it was going, for blending out of it).
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
	if (workspace.CurrentCamera.CFrame.Position - position).Magnitude < 80 then
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
