--[[
	Anti-Magic Knight (Asta): Black Ascent (Black Form, Demon-Slasher 1),
	drawn. The paths are Shared/BlackAscent (the server holds them both on
	them); this draws it, about 1.3 seconds:

	  launch    the rising cut throws them up, a black streak trailing off
	            them, the ground split red under them; he springs up after
	            them on a beat of his wings.
	  the cuts  he glides across in front of them cutting right to left,
	            then sweeps back up the other way: each cut is a crescent of
	            black and red, and the line it cut through them stays
	            hanging in the air, the two making an X.
	  the spike over the top of them, one cut straight down: the X bursts,
	            they're driven into the ground like a stake, a crater, red
	            cracks, rocks and a ring of dust, and he lands beside it.

	The camera (for the two of them) circles them up in the air, then
	cranes down after them as they fall. No shake: eased zooms.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AscentPlan = require(ReplicatedStorage:WaitForChild("Shared").BlackAscent)
local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local Cinematic = require(script.Parent.Parent.Parent.Cinematic)
local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local Soft = require(script.Parent.Parent.Parent.Soft)

local U = Soft.U
local rad = math.rad
local UP = Vector3.yAxis
local key = Soft.key

local BLACK = Color3.fromRGB(8, 8, 10)
local RED = Color3.fromRGB(200, 25, 35)
local DARK_RED = Color3.fromRGB(110, 8, 18)
local DUST = Color3.fromRGB(150, 138, 122)

type Animation = PoseAnimator.Animation
type Wings = { flap: (() -> ())?, setPose: ((string?) -> ())?, setPair: ((boolean) -> ())? }

-- What the kit lends this module.
export type Context = {
	anims: { [string]: Animation },
	play: (Model, Animation) -> (),
	launched: (Model) -> Animation?, -- their thrown-in-the-air flail
	wings: (Model) -> Wings?,
	crescent: (Model, { [string]: any }) -> (),
	cutLine: (Vector3, Vector3, number, number) -> (),
	blackSmoke: (Vector3, number, number, number?) -> (),
	redSparks: (Vector3, number, number?, Vector3?) -> (),
	blackLightning: (Vector3, number, number, number?) -> (),
	glowBurst: (Vector3, number, number?) -> (),
	bloomPulse: (Vector3, number, number) -> (),
	heavyTrail: (Model, number) -> (),
	edgeGlow: (Model, number, number?) -> (),
	swordAura: (Model, number, number) -> (),
	trailEmitter: (BasePart, { [string]: any }, number) -> ParticleEmitter,
	impactFrame: (number?) -> (),
	lingerSmoke: (Vector3, number, number) -> (),
}

local Ascent = {}

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- A soft ring racing out across `normal`, smoke flowing round it.
local function smokeRing(
	center: Vector3,
	normal: Vector3,
	from: number,
	to: number,
	duration: number,
	color: Color3,
	width: number
)
	local ring = Soft.softRing({
		color = ColorSequence.new(color),
		width0 = width,
		width1 = width,
		transparency = NumberSequence.new(0.2),
		texture = Soft.SMOKE,
		speed = 3,
		length = 3,
		emission = if color == BLACK then 0 else 1,
	})
	local frame = CFrame.lookAt(center, center + normal) * CFrame.Angles(rad(90), 0, 0)
	ring.set(frame, from)
	Soft.every(duration, function(elapsed)
		local a = 1 - (1 - elapsed / duration) ^ 3
		ring.set(frame, from + (to - from) * a)
		return true
	end)
	ring.fade(duration)
end

-- A streak trailing off someone for a moment: black smoke and a red trail.
local function streak(ctx: Context, part: BasePart, duration: number)
	ctx.trailEmitter(part, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(BLACK, Color3.fromRGB(40, 10, 12)),
		LightEmission = 0,
		Size = NumberSequence.new({ key(0, 1.8), key(1, 3.6) }),
		Transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) }),
		Lifetime = NumberRange.new(0.25, 0.4),
		Rate = 120,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(40, 40),
		Drag = 3,
	}, duration)
	local trail = Soft.trail(part, Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), {
		color = ColorSequence.new(RED, DARK_RED),
		transparency = NumberSequence.new({ key(0, 0.25), key(1, 1) }),
		lifetime = 0.2,
		width = NumberSequence.new(1, 0.2),
	})
	task.delay(duration, Soft.endTrail, trail)
end

-- Draws it (t = 0 now). Returns stop(), which cuts it short.
function Ascent.Play(ctx: Context, data, character: Model, root: BasePart): (() -> ())?
	if typeof(data.origin) ~= "CFrame" or typeof(data.start) ~= "Vector3" then
		return nil
	end
	local times = AscentPlan.Times
	local plan = AscentPlan.Plan(data.origin, data.start, tonumber(data.floorY) or data.start.Y - 3)
	local right = plan.right
	local victim: Model? = if typeof(data.target) == "Instance" and data.target:IsA("Model") then data.target else nil
	local victimRoot = U.getRoot(victim)
	local mine = U.isLocal(character) or U.isLocal(victim)
	local started = os.clock()
	local finished = false
	local floor = Vector3.new(plan.start.X, plan.floorY, plan.start.Z)

	local function at(time: number, fn: () -> ())
		task.delay(math.max(time - (os.clock() - started), 0), function()
			if not finished and character.Parent then
				fn()
			end
		end)
	end
	local function them(t: number): Vector3
		if victimRoot and victimRoot.Parent and t <= times.Land then
			return victimRoot.Position
		end
		return AscentPlan.Victim(plan, math.min(t, times.Land)).Position
	end

	-- Both of them on the paths.
	local bind = "CloverBlackAscent" .. tostring(started)
	local stop: () -> ()
	function stop()
		if finished then
			return
		end
		finished = true
		pcall(function()
			RunService:UnbindFromRenderStep(bind)
		end)
	end
	RunService:BindToRenderStep(bind, Enum.RenderPriority.Camera.Value + 3, function()
		local t = os.clock() - started
		if t > times.Length then
			stop()
			return
		end
		if root.Parent then
			root.CFrame = AscentPlan.Attacker(plan, t)
		end
		if victimRoot and victimRoot.Parent and t <= times.Land then
			victimRoot.CFrame = AscentPlan.Victim(plan, t)
		end
	end)
	task.delay(times.Length + 0.5, stop)

	ctx.play(character, ctx.anims.Ascent)
	if victim then
		local flail = ctx.launched(victim)
		if flail then
			PoseAnimator.Play(victim, flail)
		end
	end
	local wings = ctx.wings(character)
	local function wing(pose: string?, flap: boolean?)
		if wings then
			if wings.setPose then
				wings.setPose(pose)
			end
			if flap and wings.flap then
				wings.flap()
			end
		end
	end

	-- The launch: the ground splits under them and they're thrown up, a
	-- black streak trailing off them.
	U.groundCracks(floor, 7, 6, RED, 1.6)
	U.debris(floor, 10, 34, 0.8)
	U.burst(floor + UP * 0.5, {
		texture = U.textures.Smoke,
		color = DUST,
		count = 14,
		size = 3.5,
		speed = NumberRange.new(10, 22),
		lifetime = NumberRange.new(0.5, 0.9),
		lightEmission = 0,
		transparency = 0.45,
		drag = 4,
		spread = 70,
	})
	smokeRing(floor + UP * 0.4, UP, 1, 10, 0.4, Color3.fromRGB(70, 62, 56), 1.8)
	ctx.glowBurst(plan.start + UP, 4, 0.3)
	ctx.redSparks(plan.start, 14, 0.6, UP)
	if victimRoot then
		streak(ctx, victimRoot, times.Rise)
	end

	-- He springs up after them on a beat of his wings.
	at(0.08, function()
		local feet = Vector3.new(root.Position.X, plan.floorY, root.Position.Z)
		U.ringBurst(CFrame.new(feet + UP * 0.2), DUST, 1, 7, 0.35, 0.3)
		ctx.blackSmoke(feet + UP * 0.5, 8, 3, 10)
		U.groundCracks(feet, 4, 3, RED, 1)
		wing("spread", true)
	end)
	U.bodyTrail(character, RED, times.Land)
	ctx.heavyTrail(character, times.Length)
	ctx.swordAura(character, times.Length, 30)

	-- The two cuts in the air, left hanging as an X until the last cut.
	local cuts = {
		{ from = 70, to = -110, tilt = 12, side = -right, line = right * 5.5 + UP * 0.8 },
		{ from = -100, to = 80, tilt = 62, side = right + UP * 0.6, line = right * 4.5 + UP * 4 },
	}
	for i, when in times.Cuts do
		local cut = cuts[i]
		at(when - 0.06, function()
			ctx.edgeGlow(character, 0.2, 1)
			ctx.crescent(character, {
				center = CFrame.new(0, 0.5, 0),
				radius = 5.2,
				from = cut.from,
				to = cut.to,
				tilt = cut.tilt,
				width = 1.8,
				sweep = 0.07,
				fade = 0.3,
				glow = 0.8,
			})
		end)
		at(when, function()
			local point = them(when)
			local side = (cut.side :: Vector3).Unit
			ctx.cutLine(point - cut.line, point + cut.line, 0.32, times.Spike - when)
			ctx.glowBurst(point, 4, 0.25)
			ctx.redSparks(point, 16, 0.6, side)
			ctx.blackLightning(point, 3, 4, 0.18)
			U.impactRing(point, side, RED, 1, 6, 0.25)
			smokeRing(point, side, 1, 7, 0.3, BLACK, 1.4)
			U.afterimage(character, RED, 0.3)
			ctx.bloomPulse(point, 0.45, 0.2)
		end)
	end

	-- Over the top and one cut straight down: the X bursts and they're
	-- driven into the ground.
	at(times.Spike - 0.07, function()
		wing("spread", true)
		ctx.edgeGlow(character, 0.25, 1.2)
		ctx.crescent(character, {
			center = CFrame.new(0, 0.6, 0),
			radius = 6,
			from = 110,
			to = -60,
			tilt = 90,
			width = 2.2,
			sweep = 0.08,
			fade = 0.35,
			glow = 1,
		})
	end)
	at(times.Spike, function()
		local point = them(times.Spike)
		ctx.cutLine(point + UP * 5, point - UP * 5, 0.4, 0.12)
		ctx.glowBurst(point, 6, 0.3)
		ctx.redSparks(point, 20, 0.7, -UP)
		ctx.blackLightning(point, 5, 6, 0.2)
		U.flash(point, BLACK, 7, 0.18)
		smokeRing(point, UP, 1.5, 11, 0.35, BLACK, 2)
		Soft.lightRing(point, UP, 1, 10, 0.3, RED)
		ctx.bloomPulse(point, 0.7, 0.3)
		if victimRoot then
			streak(ctx, victimRoot, times.Land - times.Spike + 0.05)
		end
		if mine then
			ctx.impactFrame(0.45)
		end
	end)

	-- The crater.
	at(times.Land, function()
		U.shockwave(floor, RED, 2, 18, 0.4)
		U.shockwave(floor, BLACK, 2, 13, 0.5)
		U.groundCracks(floor, 10, 9, RED, 2.2)
		U.groundRocks(floor, 10, 6, 1.6)
		U.debris(floor, 16, 42, 0.9)
		smokeRing(floor + UP * 0.5, UP, 2, 16, 0.55, Color3.fromRGB(80, 72, 64), 2.6)
		Soft.lightRing(floor + UP * 0.3, UP, 1, 14, 0.4, RED)
		ctx.blackSmoke(floor + UP, 14, 4, 12)
		ctx.glowBurst(floor + UP, 5, 0.35)
		ctx.blackLightning(floor + UP * 0.5, 5, 7, 0.22)
		ctx.lingerSmoke(floor, 1.6, 9)
		ctx.bloomPulse(floor, 0.8, 0.35)
		U.light(floor + UP * 2, RED, 8, 24, 0.45)
		if mine then
			ctx.impactFrame(0.6)
		elseif (workspace.CurrentCamera.CFrame.Position - floor).Magnitude < 50 then
			CameraShake.Add(0.2)
		end
	end)
	-- He lands beside it.
	at(times.Land + 0.15, function()
		local feet = Vector3.new(root.Position.X, plan.floorY, root.Position.Z)
		U.ringBurst(CFrame.new(feet + UP * 0.2), DUST, 1, 6, 0.3, 0.25)
		ctx.blackSmoke(feet + UP * 0.5, 6, 2.5, 6)
		wing(nil)
	end)
	task.delay(times.Length + 0.6, function()
		wing(nil)
	end)

	if mine then
		U.colorGrade(
			{ Contrast = 0.12, Saturation = -0.12, TintColor = Color3.fromRGB(255, 238, 238) },
			0.15,
			times.Length - 0.25,
			0.4
		)
		local release = Ascent.Camera(plan)
		local stopDrawing = stop
		stop = function()
			stopDrawing()
			release()
		end
	end
	return stop
end

--[[
	The camera: low behind his shoulder as they're thrown up, rising and
	circling round them in the air through the cuts, then held and craned
	down after them as they're driven into the ground, coming to rest low
	on the crater with him beside it.
]]
function Ascent.Camera(plan: AscentPlan.Plan): () -> ()
	local times = AscentPlan.Times
	local forward, right, top = plan.forward, plan.right, plan.top
	local function him(t: number): Vector3
		return AscentPlan.Attacker(plan, t).Position
	end
	local function them(t: number): Vector3
		return AscentPlan.Victim(plan, math.min(t, times.Land)).Position
	end
	local function blow(t: number, at: number, amount: number): number
		if t < at then
			return 0
		end
		local u = (t - at) / 0.07
		return amount * u * math.exp(1 - u)
	end
	local ground = Vector3.new(plan.start.X, plan.floorY, plan.start.Z)
	return Cinematic.Camera(function(elapsed)
		local t = math.min(elapsed, times.Length)
		-- Up with them behind his right shoulder (the cuts sweep across the
		-- shot), then round to their side for the cut down.
		local up = smooth(t / 0.45)
		local angle = rad(25 + 25 * smooth(t / 0.35) + 50 * smooth((t - 0.6) / 0.35))
		local around = -forward * math.cos(angle) + right * math.sin(angle)
		local height = plan.start.Y + 0.5 + (top.Y - 1.5 - plan.start.Y - 0.5) * up
		local eye = Vector3.new(top.X, height, top.Z) + around * (11 + 3 * up)
		-- After the cut down: held there, craning down onto the crater and
		-- sinking toward the ground.
		local fall = smooth((t - times.Spike) / (times.Land + 0.2 - times.Spike))
		eye = eye:Lerp(ground + around * 13 + UP * 4, fall * 0.75)
		local pair = them(t):Lerp(him(t), 0.4)
		local focus = pair:Lerp(ground + UP * 1.5 - forward * 1, fall)
		local fov = 72 - 4 * up + 4 * fall
		for i, cut in times.Cuts do
			fov -= blow(t, cut, 3 + i)
		end
		fov -= blow(t, times.Spike, 6) + blow(t, times.Land, 8)
		return CFrame.lookAt(eye, focus) * CFrame.Angles(0, 0, rad(-2 + 4 * up - 2 * fall)), fov
	end, times.Length + 0.05)
end

return Ascent
