--[[
	Anti-Magic Knight (Asta): Black Comet (Black Form, Demon-Destroyer 2),
	drawn. The paths are Shared/BlackComet (the server holds them both on
	them); this draws it, about 1.4 seconds:

	  take-off  both wings beat once: a ring of black wind bursts off his
	            back, the ground under him cracks red and blows out, and he
	            is gone, low and flat, black flame streaming off him.
	  the drag  they hang from his real hand, dragged along on their back:
	            the ground tears open under them in a glowing trench, dirt
	            and sparks spray off it. Three times he hammers them flat
	            into it, each harder than the last: a crater, rocks, red
	            cracks, a ring of dust and a ring of red racing out.
	  the heave he swings his legs down and lands skidding, his feet
	            ploughing two furrows; hauls them round past his side and
	            heaves them away: rings of black and red blow out after them
	            and they fly off as a black comet, red embers streaming.

	The camera (for the two of them) runs low alongside, a touch behind as
	they tear off, swinging round behind him for the heave. No shake: each
	blow is an eased zoom.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CometPlan = require(ReplicatedStorage:WaitForChild("Shared").BlackComet)
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
local HOT = Color3.fromRGB(255, 110, 110)
local WHITE_HOT = Color3.fromRGB(255, 225, 225)
local DUST = Color3.fromRGB(150, 138, 122)

type Animation = PoseAnimator.Animation

export type Wings = { flap: (() -> ())?, setPose: ((string?) -> ())?, setPair: ((boolean) -> ())? }

-- What the kit lends this module.
export type Context = {
	anims: { [string]: Animation },
	play: (Model, Animation) -> (),
	held: (Model) -> Animation?, -- their "held by the throat" struggle
	wings: (Model) -> Wings?,
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

local Comet = {}

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function gripPoint(character: Model): Vector3?
	local hand = character:FindFirstChild("Left Arm")
	return if hand and hand:IsA("BasePart") then (hand.CFrame * CFrame.new(0, -1, 0)).Position else nil
end

-- A flat dark strip laid on the ground from `a` to `b` (both on it), with a
-- glowing red seam down its middle that cools first.
local function groove(a: Vector3, b: Vector3, width: number, life: number)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return
	end
	local frame = CFrame.lookAt((a + b) / 2, b)
	local dark = U.newPart({
		Size = Vector3.new(width, 0.12, length + width * 0.5),
		CFrame = frame,
		Color = Color3.fromRGB(26, 22, 22),
		Material = Enum.Material.Slate,
		Transparency = 0.05,
	})
	local seam = U.newPart({
		Size = Vector3.new(width * 0.28, 0.14, length + 0.1),
		CFrame = frame,
		Color = RED,
		Transparency = 0.1,
	})
	task.delay(0.25, U.tween, seam, life * 0.5, { Transparency = 1, Color = DARK_RED })
	task.delay(life * 0.6, U.tween, dark, life * 0.4, { Transparency = 1 })
	task.delay(life + 0.05, function()
		dark:Destroy()
		seam:Destroy()
	end)
end

-- An emitter on a little invisible part that's moved along with whatever
-- it's spraying off.
local function sprayer(props: { [string]: any }): (BasePart, ParticleEmitter)
	local holder = U.newPart({ Size = Vector3.one * 0.2, Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.LightInfluence = 0
	emitter.Enabled = false
	for name, value in props do
		(emitter :: any)[name] = value
	end
	emitter.Parent = holder
	return holder, emitter
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
		transparency = NumberSequence.new(0.15),
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
		for _, beam in ring.beams do
			beam.Width0 = width * (1 - 0.6 * a)
			beam.Width1 = beam.Width0
		end
		return true
	end)
	ring.fade(duration)
end

-- A thin bright ring (white-hot inside, red out) racing out across `normal`.
local function redRing(center: Vector3, normal: Vector3, from: number, to: number, duration: number)
	Soft.lightRing(center, normal, from, to, duration, RED)
end

-- Draws it (t = 0 now). Returns stop(), which cuts it short.
function Comet.Play(ctx: Context, data, character: Model, root: BasePart): (() -> ())?
	if typeof(data.origin) ~= "Vector3" or typeof(data.forward) ~= "Vector3" then
		return nil
	end
	local times = CometPlan.Times
	local plan = CometPlan.Plan(data.origin, data.forward, tonumber(data.distance) or 4, tonumber(data.floorY) or 0)
	local forward, right = plan.forward, plan.right
	local floorY = plan.floorY
	local victim: Model? = if typeof(data.target) == "Instance" and data.target:IsA("Model") then data.target else nil
	local victimRoot = U.getRoot(victim)
	local mine = U.isLocal(character) or U.isLocal(victim)
	local started = os.clock()
	local finished = false

	local function at(time: number, fn: () -> ())
		task.delay(math.max(time - (os.clock() - started), 0), function()
			if not finished and character.Parent then
				fn()
			end
		end)
	end
	local function ground(position: Vector3): Vector3
		return Vector3.new(position.X, floorY, position.Z)
	end

	ctx.play(character, ctx.anims.Comet)
	if victim then
		local held = ctx.held(victim)
		if held then
			PoseAnimator.Play(victim, held)
		end
	end

	-- His wings: both out for this, one huge beat to launch him, swept back
	-- for speed; flared open as he lands; back to normal after.
	local wings = ctx.wings(character)
	if wings then
		if wings.setPair then
			wings.setPair(true)
		end
		if wings.flap then
			wings.flap()
		end
		task.delay(0.12, function()
			if wings.setPose then
				wings.setPose("glide")
			end
		end)
	end

	-- What's sprayed off them as they're dragged: dirt and grit thrown up
	-- off the back of them, dust clouds rolling behind, red sparks.
	local dirtHolder, dirt = sprayer({
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(Color3.fromRGB(120, 104, 88), Color3.fromRGB(90, 78, 66)),
		LightEmission = 0,
		Size = NumberSequence.new({ key(0, 0.5), key(1, 1.6) }),
		Transparency = NumberSequence.new({ key(0, 0.15), key(1, 1) }),
		Lifetime = NumberRange.new(0.3, 0.55),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -70, 0),
		Drag = 1,
		Rate = 130,
		EmissionDirection = Enum.NormalId.Front,
	})
	local cloudHolder, cloud = sprayer({
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(DUST, Color3.fromRGB(110, 102, 94)),
		LightEmission = 0,
		Size = NumberSequence.new({ key(0, 2), key(1, 6) }),
		Transparency = NumberSequence.new({ key(0, 0.55), key(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, 3, 0),
		Drag = 2,
		Rate = 45,
	})
	local sparkHolder, sparks = sprayer({
		Texture = U.textures.Spark,
		Color = ColorSequence.new(HOT, RED),
		LightEmission = 1,
		Size = NumberSequence.new({ key(0, 0.35), key(1, 0) }),
		Lifetime = NumberRange.new(0.12, 0.3),
		Speed = NumberRange.new(18, 34),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, -40, 0),
		Rate = 70,
		EmissionDirection = Enum.NormalId.Front,
	})
	local spray = { dirtHolder, cloudHolder, sparkHolder }

	-- Their body, hung from his real hand (it's where the clip puts it, so
	-- they stay in his grip at any speed), eased in from where the grab
	-- held them.
	local body: CometPlan.Body? = nil
	local heldFrom = if victimRoot then victimRoot.CFrame else nil
	local lastTrench: Vector3? = nil
	local nextTrench = 0
	local bind = "CloverBlackComet" .. tostring(started)
	local stop: () -> ()
	function stop()
		if finished then
			return
		end
		finished = true
		pcall(function()
			RunService:UnbindFromRenderStep(bind)
		end)
		dirt.Enabled, cloud.Enabled, sparks.Enabled = false, false, false
		for _, holder in spray do
			task.delay(1.4, holder.Destroy, holder)
		end
	end
	RunService:BindToRenderStep(bind, Enum.RenderPriority.Camera.Value + 3, function()
		local t = os.clock() - started
		if t > times.Length or not root.Parent then
			stop()
			return
		end
		root.CFrame = CometPlan.Attacker(plan, t)
		local dragging = t < times.Release and victimRoot ~= nil and victimRoot.Parent ~= nil
		if dragging and victimRoot then
			local hand = gripPoint(character) or CometPlan.Hand(plan, t)
			if not body then
				body = CometPlan.Body(plan, hand)
			end
			local frame = CometPlan.Step(plan, body :: CometPlan.Body, hand, t)
			if heldFrom and t < 0.1 then
				frame = heldFrom:Lerp(frame, smooth(t / 0.1))
			end
			victimRoot.CFrame = frame

			-- Where they meet the ground: along their back when they're
			-- down flat, their heels when he's lifted them.
			local feet = (body :: CometPlan.Body).feet
			local low = math.clamp((frame.Position.Y - floorY - 0.6) / 1.6, 0, 1)
			local contact = ground(frame.Position:Lerp(feet, 0.35 + 0.65 * low))
			local touching = feet.Y < floorY + 0.9 and t > 0.08
			local back = (-forward + UP * 0.9).Unit
			dirtHolder.CFrame = CFrame.lookAt(contact + UP * 0.3, contact + UP * 0.3 + back)
			cloudHolder.CFrame = CFrame.new(contact + UP * 0.8)
			sparkHolder.CFrame = CFrame.lookAt(contact + UP * 0.2, contact + UP * 0.2 - forward + UP * 0.3)
			dirt.Enabled = touching
			cloud.Enabled = touching
			sparks.Enabled = touching and low < 0.6
			-- The trench they tear open, wider where they're slammed flat.
			if touching and t >= nextTrench then
				nextTrench = t + 1 / 45
				if lastTrench then
					groove(lastTrench, contact + UP * 0.03, 0.8 + 1.4 * (1 - low), 2.4)
				end
				lastTrench = contact + UP * 0.03
			elseif not touching then
				lastTrench = nil
			end
		elseif dirt.Enabled then
			dirt.Enabled, cloud.Enabled, sparks.Enabled = false, false, false
		end
	end)
	task.delay(times.Length + 0.5, stop)

	-- Take-off: the wings beat and he's gone.
	local start = CometPlan.Attacker(plan, 0)
	local feetAt = ground(start.Position)
	local backOf = start.Position - forward * 1.4 + UP * 0.8
	smokeRing(backOf, forward, 1, 10, 0.4, BLACK, 2.2)
	task.delay(0.03, redRing, backOf, forward, 0.8, 8, 0.3)
	ctx.glowBurst(backOf, 4, 0.3)
	ctx.blackSmoke(backOf - forward, 10, 3.5, 14)
	ctx.blackLightning(start.Position, 5, 6, 0.22)
	U.shockwave(feetAt, BLACK, 1, 12, 0.35)
	U.groundCracks(feetAt, 7, 5, RED, 1.4)
	U.debris(feetAt, 8, 30, 0.7)
	U.burst(feetAt + UP * 0.4, {
		texture = U.textures.Smoke,
		color = DUST,
		count = 14,
		size = 3.5,
		speed = NumberRange.new(14, 26),
		lifetime = NumberRange.new(0.5, 0.9),
		lightEmission = 0,
		transparency = 0.45,
		drag = 4,
		spread = 80,
		direction = UP,
	})
	U.light(start.Position, RED, 6, 16, 0.35)

	-- In flight: black flame streaming off him, the Destroyer burning, and
	-- the air torn past him.
	ctx.trailEmitter(root, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(BLACK, Color3.fromRGB(30, 8, 10)),
		LightEmission = 0,
		Size = NumberSequence.new({ key(0, 1.6), key(1, 3.6) }),
		Transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) }),
		Lifetime = NumberRange.new(0.22, 0.38),
		Rate = 140,
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(40, 40),
		Drag = 3,
	}, times.Plant)
	ctx.trailEmitter(root, {
		Texture = U.textures.Spark,
		Color = ColorSequence.new(HOT, RED),
		LightEmission = 1,
		Size = NumberSequence.new({ key(0, 0.3), key(1, 0) }),
		Lifetime = NumberRange.new(0.2, 0.4),
		Rate = 50,
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(180, 180),
	}, times.Plant)
	U.bodyTrail(character, RED, times.Plant)
	ctx.heavyTrail(character, times.Release + 0.2)
	ctx.edgeGlow(character, times.Release + 0.15, 0.7)
	ctx.swordAura(character, times.Length, 30)
	U.speedLines(root, forward, times.Plant - 0.1, Color3.fromRGB(255, 235, 235))

	-- Each slam into the ground, harder than the last.
	for i, slam in times.Slams do
		at(slam, function()
			local where = CometPlan.Victim(plan, slam).Position
			if victimRoot and victimRoot.Parent then
				where = victimRoot.Position
			end
			local point = ground(where)
			local k = 1 + 0.2 * (i - 1)
			U.groundCracks(point, 5 + 2 * i, 4 + 1.5 * i, RED, 1.4)
			U.groundRocks(point, 4 + 2 * i, 2.5 + i, 1 + 0.25 * i)
			U.debris(point, 7 + 3 * i, 28 + 6 * i, 0.6 + 0.1 * i)
			U.shockwave(point, RED, 1, 9 * k, 0.3)
			smokeRing(point + UP * 0.4, UP, 1, 8 * k, 0.45, Color3.fromRGB(70, 62, 56), 1.8)
			ctx.blackSmoke(point + UP * 0.6, 7 + i, 3, 8)
			ctx.glowBurst(point + UP * 0.7, 3 + i, 0.25)
			ctx.redSparks(point + UP * 0.5, 10 + 4 * i, 0.5, UP)
			ctx.blackLightning(point + UP * 0.5, 2 + i, 4 + i, 0.18)
			U.flash(point + UP * 0.6, BLACK, 4 + i, 0.14)
			ctx.bloomPulse(point, 0.3 + 0.15 * i, 0.25)
			if mine and i == #times.Slams then
				ctx.impactFrame(0.35)
			end
		end)
	end

	-- Landing: his feet plough two furrows as he skids to a stop; the wings
	-- flare open to brake.
	at(times.Plant, function()
		if wings and wings.setPose then
			wings.setPose("spread")
		end
		local skidHolder, skid = sprayer({
			Texture = U.textures.Smoke,
			Color = ColorSequence.new(Color3.fromRGB(130, 116, 100)),
			LightEmission = 0,
			Size = NumberSequence.new({ key(0, 0.8), key(1, 2.6) }),
			Transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) }),
			Lifetime = NumberRange.new(0.35, 0.6),
			Speed = NumberRange.new(10, 20),
			SpreadAngle = Vector2.new(30, 30),
			Acceleration = Vector3.new(0, -40, 0),
			Drag = 1.5,
			Rate = 110,
			EmissionDirection = Enum.NormalId.Front,
		})
		skid.Enabled = true
		local feet = { root.Position - right * 0.5, root.Position + right * 0.5 }
		local last = { ground(feet[1]), ground(feet[2]) }
		Soft.every(times.Stop - times.Plant + 0.05, function()
			if not root.Parent then
				return false
			end
			local here = ground(root.Position)
			skidHolder.CFrame = CFrame.lookAt(here + UP * 0.3, here + UP * 0.3 + (forward + UP * 0.7).Unit)
			for side = 1, 2 do
				local foot = ground(root.Position + right * (if side == 1 then -0.5 else 0.5)) + UP * 0.03
				groove(last[side], foot, 0.55, 1.6)
				last[side] = foot
			end
			return true
		end, function()
			skid.Enabled = false
			task.delay(0.8, skidHolder.Destroy, skidHolder)
		end)
		U.ringBurst(CFrame.new(ground(root.Position) + UP * 0.2), Color3.fromRGB(150, 138, 122), 1, 7, 0.35, 0.3)
		ctx.blackSmoke(ground(root.Position) + UP * 0.5, 8, 3, 8)
	end)

	-- The haul: black smoke wound round him as he twists.
	at(times.Release - 0.08, function()
		local hand = gripPoint(character) or root.Position
		ctx.blackSmoke(hand, 6, 2.5, 6)
		ctx.blackLightning(hand, 3, 3, 0.15)
	end)

	-- The heave: they're thrown away as a black comet.
	at(times.Release, function()
		local hand = gripPoint(character) or root.Position + forward * 2 + UP
		local direction = (forward * 85 + UP * 30).Unit
		local feet = ground(root.Position)
		ctx.glowBurst(hand, 6, 0.35)
		U.flash(hand, WHITE_HOT, 4, 0.08)
		U.flash(hand, BLACK, 8, 0.2)
		smokeRing(hand, direction, 1.5, 13, 0.45, BLACK, 2.6)
		task.delay(0.03, smokeRing, hand + direction, direction, 1, 9, 0.35, RED, 1.2)
		task.delay(0.05, redRing, hand + direction * 2, direction, 1, 11, 0.3)
		U.impactRing(hand, direction, RED, 1, 8, 0.3)
		U.burst(hand, {
			texture = U.textures.Smoke,
			color = BLACK,
			count = 16,
			size = 3,
			speed = NumberRange.new(20, 45),
			lifetime = NumberRange.new(0.3, 0.6),
			lightEmission = 0,
			transparency = 0.15,
			drag = 4,
			spread = 25,
			direction = direction,
		})
		ctx.redSparks(hand, 20, 0.7, direction)
		ctx.blackLightning(hand, 6, 7, 0.22)
		U.shockwave(feet, RED, 1, 16, 0.4)
		U.groundCracks(feet + forward * 2, 8, 7, RED, 1.6)
		ctx.lingerSmoke(feet, 1.4, 8)
		ctx.bloomPulse(hand, 0.9, 0.4)
		U.light(hand, RED, 9, 22, 0.4)
		if wings and wings.flap then
			wings.flap()
		end
		if mine then
			ctx.impactFrame(0.7)
		end
		-- The comet: a black tail and red embers streaming off them.
		if victimRoot and victimRoot.Parent then
			ctx.trailEmitter(victimRoot, {
				Texture = U.textures.Smoke,
				Color = ColorSequence.new(BLACK, Color3.fromRGB(40, 10, 12)),
				LightEmission = 0,
				Size = NumberSequence.new({ key(0, 2.6), key(1, 5) }),
				Transparency = NumberSequence.new({ key(0, 0.15), key(1, 1) }),
				Lifetime = NumberRange.new(0.3, 0.5),
				Rate = 150,
				Speed = NumberRange.new(2, 5),
				SpreadAngle = Vector2.new(50, 50),
				Drag = 3,
			}, 0.8)
			ctx.trailEmitter(victimRoot, {
				Texture = U.textures.Spark,
				Color = ColorSequence.new(HOT, RED),
				LightEmission = 1,
				Size = NumberSequence.new({ key(0, 0.4), key(1, 0) }),
				Lifetime = NumberRange.new(0.25, 0.5),
				Rate = 80,
				Speed = NumberRange.new(4, 10),
				SpreadAngle = Vector2.new(180, 180),
			}, 0.8)
			local tail = Soft.trail(victimRoot, Vector3.new(0, 1.2, 0), Vector3.new(0, -1.2, 0), {
				color = ColorSequence.new(RED, DARK_RED),
				transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) }),
				lifetime = 0.25,
				width = NumberSequence.new(1, 0.2),
			})
			task.delay(0.8, Soft.endTrail, tail)
		end
	end)

	at(times.Length + 0.3, function()
		if wings then
			if wings.setPose then
				wings.setPose(nil)
			end
			if wings.setPair then
				wings.setPair(false)
			end
		end
	end)
	-- (If it's cut short, the wings still go back.)
	task.delay(times.Length + 0.6, function()
		if wings and finished then
			if wings.setPose then
				wings.setPose(nil)
			end
			if wings.setPair then
				wings.setPair(false)
			end
		end
	end)

	-- For the two of them: the light deepens a touch (never dark) and the
	-- reds bloom.
	if mine then
		U.colorGrade(
			{ Contrast = 0.12, Saturation = -0.12, TintColor = Color3.fromRGB(255, 238, 238) },
			0.15,
			times.Length - 0.25,
			0.4
		)
		local release = Comet.Camera(plan)
		local stopDrawing = stop
		stop = function()
			stopDrawing()
			release()
		end
	end

	return stop
end

--[[
	The camera: low, at their side (the side he holds them on), riding
	along a touch behind them so they pull ahead as he tears off, coming
	round behind his shoulder for the heave and watching them go. Each slam
	and the heave is an eased zoom in and out; nothing shakes.
]]
function Comet.Camera(plan: CometPlan.Plan): () -> ()
	local times = CometPlan.Times
	local forward, right = plan.forward, plan.right
	local function him(t: number): Vector3
		return CometPlan.Attacker(plan, t).Position
	end
	local function them(t: number): Vector3
		if t <= times.Release then
			return CometPlan.Victim(plan, t).Position
		end
		-- Thrown: where they're flying, roughly.
		local s = t - times.Release
		local from = CometPlan.Victim(plan, times.Release).Position
		return from + forward * 85 * s + UP * (30 * s - 70 * s * s)
	end
	-- Steady: their ground track at a fixed height, so the camera doesn't
	-- bob with every slam (only the dive down from the air, if any).
	local function level(p: Vector3, height: number, t: number): Vector3
		return Vector3.new(p.X, plan.floorY + height + plan.above * (1 - smooth(t / 0.2)), p.Z)
	end
	local function blow(t: number, at: number, amount: number): number
		if t < at then
			return 0
		end
		local u = (t - at) / 0.07
		return amount * u * math.exp(1 - u)
	end
	local release = times.Release
	return Cinematic.Camera(function(elapsed)
		local t = math.min(elapsed, times.Length)
		-- Riding along with them, a touch behind (more as they take off).
		local lag = 0.05 * smooth(t / 0.2) * (1 - smooth((t - 0.6) / 0.3))
		local anchor = level(him(t - lag):Lerp(them(math.min(t - lag, release)), 0.5), 2.2, t)
		-- Round from in front of them at their side to behind his
		-- shoulder for the heave.
		local swing = smooth((t - 0.05) / 0.75) * 0.55 + smooth((t - 0.78) / 0.4) * 0.45
		local angle = rad(55 + 95 * swing)
		local around = forward * math.cos(angle) - right * math.sin(angle)
		local distance = 8.5 + 1.5 * smooth((t - 0.8) / 0.4)
		local eye = anchor + around * distance + UP * (1.6 + 1.4 * smooth((t - 0.75) / 0.5))
		eye = Vector3.new(eye.X, math.max(eye.Y, plan.floorY + 1), eye.Z)
		-- Looking at the pair, then after them as they fly.
		local pair = level(him(t):Lerp(them(math.min(t, release)), 0.5), 1.6, t) + forward * 1.2
		local follow = smooth((t - release) / 0.3)
		local focus = pair:Lerp(him(t):Lerp(them(t), 0.55), follow)
		local roll = -3 + 6 * swing
		local fov = 74 - 4 * swing
		for i, slam in times.Slams do
			fov -= blow(t, slam, 2 + i)
		end
		fov -= blow(t, release, 9)
		return CFrame.lookAt(eye, focus) * CFrame.Angles(0, 0, rad(roll)), fov
	end, times.Length + 0.05)
end

return Comet
