-- Yuno's Nova Vortex (Half-Crown 4), drawn: the star, the galaxy of wind and the nova.

local RunService = game:GetService("RunService")

local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local Soft = require(script.Parent.Parent.Parent.Soft)

local U = Soft.U
local UP = Vector3.yAxis
local key = Soft.key

local WIND, WIND_DEEP, WIND_WHITE = Soft.WIND, Soft.WIND_DEEP, Soft.WIND_WHITE
local STAR, STAR_WHITE = Soft.STAR, Soft.STAR_WHITE
local SMOKE = Soft.SMOKE

type Animation = PoseAnimator.Animation

-- What the kit lends this module.
export type Context = {
	anims: { [string]: Animation },
	play: (Model, Animation) -> (),
}

local Nova = {}

local ARMS = 4
local SPIRAL_IN, SPIRAL_OUT = 1.2, 14 -- studs from the eye the arms run between
local TWIST = 2.4 -- radians each arm curls round on its way out
local COLLAPSE = 0.15 -- (as the server's NOVA_COLLAPSE)

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function handOf(character: Model): Vector3?
	local arm = character:FindFirstChild("Right Arm")
	return if arm and arm:IsA("BasePart") then (arm.CFrame * CFrame.new(0, -1.3, 0)).Position else nil
end

-- The star in his hand, and its flight

type Forming = { stop: () -> () }
local forming: { [Model]: Forming } = setmetatable({}, { __mode = "k" }) :: any

-- A star grows over his open hand, wind streaming into it.
local function formStar(character: Model): Forming
	local star = Soft.makeStar(1.1)
	local alive = true
	Soft.every(0.6, function(elapsed)
		local hand = handOf(character)
		if not alive or not hand then
			return false
		end
		star.place(hand + UP * (0.6 + 0.2 * smooth(elapsed / 0.2)), elapsed * 6)
		return true
	end, function()
		if alive then
			alive = false
			star.fade(0.1)
		end
	end)
	for i = 0, 5 do
		task.delay(i * 0.04, function()
			local hand = handOf(character)
			if alive and hand then
				Soft.inflow(hand + UP * 0.8, 3.5, if i % 2 == 0 then WIND_WHITE else STAR)
			end
		end)
	end
	return {
		stop = function()
			if alive then
				alive = false
				star.fade(0.08)
			end
		end,
	}
end

-- The star flies from his hand to where the galaxy opens.
local function throwStar(from: Vector3, eye: Vector3, flight: number)
	local star = Soft.makeStar(1.5)
	local holder = U.newPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(from) })
	local light = Soft.trail(holder, Vector3.new(0, 0.45, 0), Vector3.new(0, -0.45, 0), {
		color = ColorSequence.new(STAR_WHITE, STAR),
		transparency = NumberSequence.new({ key(0, 0.15), key(1, 1) }),
		width = NumberSequence.new({ key(0, 1), key(1, 0) }),
		lifetime = 0.25,
		off = true,
	})
	local wind = Soft.trail(holder, Vector3.new(0, 1.1, 0), Vector3.new(0, -1.1, 0), {
		color = ColorSequence.new(WIND_WHITE, WIND),
		transparency = NumberSequence.new({ key(0, 0.5), key(1, 1) }),
		width = NumberSequence.new({ key(0, 1), key(1, 0.3) }),
		lifetime = 0.3,
		texture = SMOKE,
		off = true,
	})
	local begun = false
	Soft.every(flight, function(elapsed)
		local u = elapsed / flight
		local at = from:Lerp(eye, u) + UP * math.sin(u * math.pi) * 2.5
		holder.CFrame = CFrame.lookAt(at, eye)
		star.place(at, elapsed * 16)
		if not begun then
			begun = true
			Soft.beginTrail(light)
			Soft.beginTrail(wind)
		end
		return true
	end, function()
		star.fade(0.08)
		Soft.endTrail(light)
		Soft.endTrail(wind)
		Soft.linger(holder, 0.05, 0.5)
		U.flash(eye, STAR_WHITE, 3, 0.1)
		Soft.twinkle(eye, 6, STAR, 0.25)
	end)
end

-- The galaxy

type Galaxy = { collapse: () -> (), fade: () -> () }
local galaxies: { [Model]: Galaxy } = setmetatable({}, { __mode = "k" }) :: any

-- Wind rushing in across the ground to the eye.
local function drawIn(eye: Vector3, ground: Vector3, radius: number)
	local angle = math.random() * math.pi * 2
	local from = ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius + UP * (0.4 + math.random() * 2.2)
	local to = eye:Lerp(from, 0.15)
	local wisp = Soft.bar(from, from + (to - from).Unit * 2.4, 0.12, WIND_WHITE, 0.35)
	U.tween(wisp, 0.3, { CFrame = CFrame.lookAt(to, to + (to - from).Unit), Transparency = 1 })
	task.delay(0.32, wisp.Destroy, wisp)
end

local function openGalaxy(eye: Vector3, ground: Vector3, reach: number): Galaxy
	local made: { Instance } = {}
	local plane = ground + UP * 0.7
	local born = os.clock()
	local collapsing: number? = nil
	local spin = 0

	-- Where along an arm `s` (0 at the eye, 1 at the rim) is, and which way
	-- the arm runs there.
	local function spiral(base: number, s: number, scale: number): (Vector3, Vector3)
		local r = (SPIRAL_IN + (SPIRAL_OUT - SPIRAL_IN) * s) * scale
		local theta = base + TWIST * s
		local radial = Vector3.new(math.cos(theta), 0, math.sin(theta))
		local around = Vector3.new(-math.sin(theta), 0, math.cos(theta))
		local tangent = radial * (SPIRAL_OUT - SPIRAL_IN) * scale + around * r * TWIST
		return plane + radial * r, tangent
	end

	-- The arms: two curved spans each, wind with starlight running along it.
	type Span = { a: Attachment, b: Attachment, beams: { Beam }, from: number, to: number, arm: number }
	local spans: { Span } = {}
	for arm = 1, ARMS do
		for half = 0, 1 do
			local a, b = Soft.worldAnchor(plane), Soft.worldAnchor(plane)
			table.insert(made, a)
			table.insert(made, b)
			local inner = half == 0
			local beams = {
				Soft.softBeam(a, b, {
					color = ColorSequence.new(WIND_WHITE, if arm % 2 == 0 then WIND else WIND_DEEP),
					width0 = if inner then 3.4 else 2.4,
					width1 = if inner then 2.4 else 0.8,
					transparency = NumberSequence.new({ key(0, 0.5), key(1, if inner then 0.6 else 0.85) }),
					texture = SMOKE,
					speed = 4,
					length = 6,
				}),
				Soft.starStream(a, b, if inner then 1.3 else 0.9, 3),
			}
			for _, beam in beams do
				table.insert(made, beam)
			end
			table.insert(spans, { a = a, b = b, beams = beams, from = half * 0.5, to = half * 0.5 + 0.5, arm = arm })
		end
	end

	-- Stars strewn along the arms, glittering.
	type Mote = { part: BasePart, arm: number, s: number, lift: number, out: number, phase: number }
	local motes: { Mote } = {}
	for i = 1, 40 do
		local part = U.newPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.3 + math.random() * 0.5),
			Color = if i % 3 == 0 then STAR else STAR_WHITE,
			Transparency = 1,
		})
		table.insert(made, part)
		table.insert(motes, {
			part = part,
			arm = (i - 1) % ARMS + 1,
			s = math.random(),
			lift = 0.2 + math.random() * 1.6,
			out = (math.random() - 0.5) * 1.6,
			phase = math.random() * 6.28,
		})
	end

	-- The bright core in its eye.
	local core = Soft.makeStar(3)
	for _, part in core.parts do
		table.insert(made, part)
	end

	-- Rings of wind turning round it, and a ring of light at the edge of
	-- its pull.
	local rings = {
		Soft.softRing({
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 1.4,
			width1 = 1.4,
			transparency = NumberSequence.new(0.6),
			texture = SMOKE,
			speed = 5,
			length = 6,
		}),
		Soft.softRing({
			color = ColorSequence.new(WIND_WHITE, WIND_DEEP),
			width0 = 2,
			width1 = 2,
			transparency = NumberSequence.new(0.7),
			texture = SMOKE,
			speed = -4,
			length = 8,
			segments = 16,
		}),
	}
	local edge = Soft.softRing({
		color = ColorSequence.new(STAR_WHITE, STAR),
		width0 = 0.3,
		width1 = 0.3,
		transparency = NumberSequence.new(0.55),
		segments = 20,
	})
	for _, ring in { rings[1], rings[2], edge } do
		table.insert(made, ring.hub)
	end

	-- The column of wind twisting up out of its eye.
	local foot, top = Soft.worldAnchor(ground, UP), Soft.worldAnchor(ground + UP * 13, UP)
	table.insert(made, foot)
	table.insert(made, top)
	local column = Soft.softBeam(foot, top, {
		color = ColorSequence.new(WIND_WHITE, WIND),
		width0 = 2.6,
		width1 = 6,
		transparency = NumberSequence.new({ key(0, 0.55), key(1, 1) }),
		texture = SMOKE,
		speed = -10,
		length = 8,
	})
	table.insert(made, column)
	local stopHelix = Soft.helix(function()
		return ground, ground + UP * 12
	end, 1.8, 3, 0.45, 1.5, 0.7, 3, WIND_WHITE)

	-- Dust lifting off the ground under it.
	local floor = U.newPart({
		Size = Vector3.new(reach * 1.4, 0.2, reach * 1.4),
		Transparency = 1,
		CFrame = CFrame.new(ground + UP * 0.2),
	})
	table.insert(made, floor)
	local dust = Soft.windEmitter(floor, {
		Color = ColorSequence.new(Color3.fromRGB(214, 222, 210), Color3.fromRGB(176, 196, 182)),
		LightEmission = 0,
		Transparency = NumberSequence.new({ key(0, 1), key(0.3, 0.86), key(1, 1) }),
		Size = NumberSequence.new({ key(0, 2), key(1, 5) }),
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 26,
	})

	local nextDraw = 0
	local finished = false
	local connection: RBXScriptConnection
	local function destroy()
		if finished then
			return
		end
		finished = true
		connection:Disconnect()
		stopHelix()
		dust.Enabled = false
		for _, instance in made do
			instance:Destroy()
		end
	end
	connection = RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local t = now - born
		local grow = 1 - (1 - math.clamp(t / 0.3, 0, 1)) ^ 3
		local shrink = if collapsing then 1 - smooth((now - collapsing) / COLLAPSE) else 1
		local scale = math.max(grow * shrink, 0.02)
		if collapsing and now - collapsing >= COLLAPSE then
			destroy()
			return
		end
		-- Faster the longer it's open (and fastest as it falls in).
		spin += dt * (1.6 + 1.2 * math.min(t, 2) + (if collapsing then 10 else 0))

		for _, span in spans do
			local base = spin + (span.arm - 1) * math.pi * 2 / ARMS
			local p0, t0 = spiral(base, span.from, scale)
			local p1, t1 = spiral(base, span.to, scale)
			Soft.aim(span.a, p0, t0)
			Soft.aim(span.b, p1, t1)
			local step = span.to - span.from
			for _, beam in span.beams do
				beam.CurveSize0 = t0.Magnitude * step / 3
				beam.CurveSize1 = t1.Magnitude * step / 3
			end
		end
		for _, mote in motes do
			local base = spin + (mote.arm - 1) * math.pi * 2 / ARMS
			local p, tangent = spiral(base, mote.s, scale)
			local side = tangent:Cross(UP).Unit
			mote.part.CFrame = CFrame.new(p + side * mote.out * scale + UP * mote.lift * scale)
			local glint = 0.5 + 0.5 * math.sin(t * 7 + mote.phase)
			mote.part.Transparency = 1 - math.min(grow, shrink) * (0.25 + 0.6 * glint)
		end
		core.place(eye, t * 3)
		rings[1].set(CFrame.new(plane + UP * 0.2) * CFrame.Angles(0, spin, 0), 8 * scale)
		rings[2].set(CFrame.new(plane + UP * 0.4) * CFrame.Angles(0, -spin * 0.6, 0), SPIRAL_OUT * scale)
		edge.set(CFrame.new(ground + UP * 0.3), reach * (0.6 + 0.4 * grow) * shrink)
		for _, beam in edge.beams do
			beam.Transparency = NumberSequence.new(0.55 + 0.25 * (0.5 + 0.5 * math.sin(t * 6)))
		end
		column.Width0 = 2.6 * scale
		column.Width1 = 6 * scale

		-- Wind rushing in from all round, faster as it goes.
		if not collapsing and t >= nextDraw then
			nextDraw = t + 0.05
			drawIn(eye, ground, reach * (0.6 + math.random() * 0.4))
		end
	end)

	local galaxy = {}
	function galaxy.collapse()
		if not collapsing then
			collapsing = os.clock()
			-- The core flares as everything falls into it.
			Soft.twinkle(eye, 10, STAR, COLLAPSE + 0.05)
			U.flash(eye, STAR_WHITE, 5, COLLAPSE)
		end
	end
	function galaxy.fade()
		if not collapsing then
			collapsing = os.clock()
		end
	end
	return galaxy
end

-- The nova

local function nova(eye: Vector3, ground: Vector3)
	-- A pillar of starlight bursting up into the sky, twisting with wind.
	local foot, top = Soft.worldAnchor(ground, UP), Soft.worldAnchor(ground + UP * 46, UP)
	local pillar = {
		Soft.softBeam(foot, top, {
			color = ColorSequence.new(STAR_WHITE),
			width0 = 3.2,
			width1 = 1.2,
			transparency = NumberSequence.new({ key(0, 0.05), key(1, 0.5) }),
		}),
		Soft.softBeam(foot, top, {
			color = ColorSequence.new(STAR_WHITE, STAR),
			width0 = 8,
			width1 = 3,
			transparency = NumberSequence.new({ key(0, 0.45), key(1, 0.85) }),
		}),
		Soft.softBeam(foot, top, {
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 13,
			width1 = 5,
			transparency = NumberSequence.new({ key(0, 0.65), key(1, 0.95) }),
			texture = SMOKE,
			speed = -22,
			length = 14,
		}),
	}
	table.insert(pillar, Soft.starStream(foot, top, 2.4, -30))
	local widths = Soft.widths(pillar)
	-- Thin to wide in a flash, then thinning out as it fades.
	Soft.every(0.6, function(elapsed)
		local k = if elapsed < 0.06 then 0.2 + 1.1 * elapsed / 0.06 else 1.3 - 0.9 * (elapsed - 0.06) / 0.54
		Soft.scaleBeams(pillar, k, widths)
		return true
	end)
	task.delay(0.15, Soft.fadeBeams, pillar, 0.45, { foot, top })
	local stopSpiral = Soft.helix(function()
		return ground, ground + UP * 40
	end, 3.2, 4, 0.35, 2, 1.1, 0.45, STAR)
	task.delay(0.5, stopSpiral)

	-- Out over the ground: a ring of wind and light, the ground cracked gold.
	Soft.windRing(ground + UP * 0.4, UP, 2, 22, 0.5)
	Soft.lightRing(ground + UP * 0.3, UP, 1, 18, 0.4, STAR)
	U.shockwave(ground, STAR, 2, 30, 0.45)
	U.groundCracks(ground, 10, 8, STAR, 1.6)
	U.debris(ground, 14, 40, 0.8)

	-- And the burst itself: light, stars scattering.
	U.flash(eye, STAR_WHITE, 10, 0.25)
	Soft.twinkle(eye, 16, STAR, 0.4)
	Soft.starDust(eye, 40, 50)
	Soft.streaks(eye, 24, 80, UP, 50)
	Soft.windPuff(eye, 6, UP)
	U.light(eye, STAR, 6, 40, 0.5)
end

function Nova.Handle(ctx: Context, data, character: Model, root: BasePart)
	local phase = data.phase
	local anims = ctx.anims
	if phase == "Form" then
		ctx.play(character, if data.airborne then anims.NovaFormAir else anims.NovaForm)
		local old = forming[character]
		if old then
			old.stop()
		end
		forming[character] = formStar(character)
		Soft.twinkle(root.Position + root.CFrame.LookVector * 1.5 + UP * 1.5, 3, STAR, 0.25)
	elseif phase == "Cancel" then
		local star = forming[character]
		forming[character] = nil
		if star then
			star.stop()
		end
		local current = PoseAnimator.Current(character)
		if current == anims.NovaForm or current == anims.NovaFormAir then
			PoseAnimator.FadeOut(character, 0.15)
		end
	elseif phase == "Throw" then
		ctx.play(
			character,
			if PoseAnimator.Current(character) == anims.NovaFormAir then anims.NovaFlickAir else anims.NovaFlick
		)
		local star = forming[character]
		forming[character] = nil
		if star then
			star.stop()
		end
		if typeof(data.from) == "Vector3" and typeof(data.eye) == "Vector3" then
			throwStar(data.from, data.eye, tonumber(data.flight) or 0.2)
			Soft.windPuff(data.from, 2, (data.eye - data.from).Unit)
		end
	elseif phase == "Open" then
		if typeof(data.eye) ~= "Vector3" or typeof(data.ground) ~= "Vector3" then
			return
		end
		local old = galaxies[character]
		if old then
			old.fade()
		end
		galaxies[character] = openGalaxy(data.eye, data.ground, tonumber(data.reach) or 22)
		Soft.windRing(data.ground + UP * 0.5, UP, 1, 14, 0.35)
		Soft.lightRing(data.ground + UP * 0.4, UP, 0.5, 10, 0.3, STAR)
		Soft.twinkle(data.eye, 8, STAR, 0.3)
	elseif phase == "Nova" then
		local galaxy = galaxies[character]
		galaxies[character] = nil
		if galaxy then
			galaxy.collapse()
		end
		if typeof(data.eye) == "Vector3" and typeof(data.ground) == "Vector3" then
			local eye, ground = data.eye, data.ground
			task.delay(COLLAPSE, nova, eye, ground)
		end
	elseif phase == "Fizzle" then
		local galaxy = galaxies[character]
		galaxies[character] = nil
		if galaxy then
			galaxy.fade()
		end
	end
end

return Nova
