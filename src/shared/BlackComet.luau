-- Black Comet's paths (shared, so the server and every client agree).

local BlackComet = {}

local UP = Vector3.yAxis

BlackComet.Times = {
	Slams = { 0.24, 0.45, 0.64 }, -- each time he hammers them into the ground
	Plant = 0.79, -- his feet touch down; he skids to a stop
	Stop = 0.92,
	Release = 1.0, -- the heave lets go of them
	Length = 1.4,
}
BlackComet.Distance = 30 -- the most he covers (walls cut it short)

local CRUISE = 0.5 -- studs above standing height he flies at
local DIP = 1.4 -- how far each slam drives him down (so his fist reaches the ground)
local DIP_WIDTH = 0.055 -- seconds
local START_TIME = 0.06 -- how fast he gets up to speed (an exponential's time)
local DIVE = 0.2 -- seconds to come down to the ground if he grabbed them in the air

local BODY = 4 -- throat to feet
local THROAT = 0.55 -- the hand to the middle of the neck
local SIDE = 2.8 -- their feet stay at least this far out at his left
local SIDE_START = 2 -- (eased out to SIDE from here over the take-off)
local GRAVITY = Vector3.new(0, -196.2, 0)
local FRICTION = 0.08 -- of their sliding speed lost each step on the ground
local DAMPING = 0.98
local HEAD_DOWN = 0.3 -- their feet stay this far under their neck (never upside down)
local STEP = 1 / 240

export type Plan = {
	origin: Vector3,
	forward: Vector3,
	right: Vector3,
	distance: number,
	floorY: number,
	above: number, -- how far over standing height he started
	victim: { CFrame }, -- (server) where they are, every 1/60 s up to Release
}

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function covered(u: number): number
	local k = START_TIME
	local slow = k * ((1 - 2 * k * k) - math.exp(-u / k) * (1 - u * u - 2 * k * u - 2 * k * k))
	return u - u * u * u / 3 - slow
end
local TOTAL = covered(1)

local function lift(t: number): number
	local times = BlackComet.Times
	local cruise = CRUISE * smooth(t / 0.14) * (1 - smooth((t - 0.66) / (times.Plant - 0.66)))
	local dips = 0
	for _, at in times.Slams do
		dips += math.exp(-((t - at) / DIP_WIDTH) ^ 2)
	end
	return cruise - DIP * dips
end

function BlackComet.Attacker(plan: Plan, t: number): CFrame
	local times = BlackComet.Times
	local along = plan.distance * covered(math.clamp(t / times.Stop, 0, 1)) / TOTAL
	local height = 3 + lift(t) + plan.above * (1 - smooth(t / DIVE))
	local position = Vector3.new(plan.origin.X, plan.floorY + height, plan.origin.Z) + plan.forward * along
	return CFrame.lookAt(position, position + plan.forward)
end

local HAND: { { any } } = {
	{ 0, Vector3.new(-1.6, 1.18, -1.08) },
	{ 0.05, Vector3.new(-2.48, 0.73, -0.49), "Quart", "Out" },
	{ 0.11, Vector3.new(-2.21, 0.07, -1.29), "Sine", "Out" },
	{ 0.17, Vector3.new(-1.94, -0.17, -1.59), "Sine", "InOut" },
	{ 0.24, Vector3.new(-2.1, -0.93, -0.65), "Quad", "In" },
	{ 0.34, Vector3.new(-1.96, -0.27, -1.55), "Sine", "Out" },
	{ 0.45, Vector3.new(-2.1, -0.95, -0.57), "Quad", "In" },
	{ 0.54, Vector3.new(-1.97, -0.36, -1.51), "Sine", "Out" },
	{ 0.64, Vector3.new(-2.1, -0.97, -0.48), "Quad", "In" },
	{ 0.7, Vector3.new(-2.1, -0.93, -0.65), "Sine", "Out" },
	{ 0.79, Vector3.new(-2.32, -0.65, -0.35), "Sine", "InOut" },
	{ 0.85, Vector3.new(-2.34, -0.52, 0.01), "Sine", "Out" },
	{ 0.94, Vector3.new(-2.41, 0.06, 0.1), "Sine", "InOut" },
	{ 1, Vector3.new(-1.38, 1.06, -1.99), "Quad", "In" },
}

local function ease(a: number, style: string?, direction: string?): number
	local function base(x: number): number
		if style == "Quart" then
			return x ^ 4
		elseif style == "Sine" then
			return 1 - math.cos(x * math.pi / 2)
		end
		return x * x
	end
	if direction == "In" then
		return base(a)
	elseif direction == "InOut" then
		return if a < 0.5 then base(2 * a) / 2 else 1 - base(2 * (1 - a)) / 2
	end
	return 1 - base(1 - a)
end

-- Where the clip has his free hand at `t` (world space).
function BlackComet.Hand(plan: Plan, t: number): Vector3
	local offset = HAND[#HAND][2]
	for i = 1, #HAND - 1 do
		local a, b = HAND[i], HAND[i + 1]
		if t < b[1] then
			local alpha = math.clamp((t - a[1]) / (b[1] - a[1]), 0, 1)
			offset = (a[2] :: Vector3):Lerp(b[2], ease(alpha, b[3], b[4]))
			break
		end
	end
	return BlackComet.Attacker(plan, t):PointToWorldSpace(offset)
end

export type Body = { feet: Vector3, last: Vector3, look: Vector3, neck: Vector3, t: number }

-- Starts them hanging straight down from `hand`, facing him (as the grab
-- held them).
function BlackComet.Body(plan: Plan, hand: Vector3): Body
	local look = -plan.forward
	local neck = hand - look * THROAT
	local feet = neck - UP * BODY
	return { feet = feet, last = feet, look = look, neck = neck, t = 0 }
end

function BlackComet.Step(plan: Plan, body: Body, hand: Vector3, t: number): CFrame
	local floor = plan.floorY + 0.5
	local from, fromTime = body.neck, body.t
	local target = hand - body.look * THROAT
	target = Vector3.new(target.X, math.max(target.Y, plan.floorY + 0.35), target.Z)
	local steps = math.clamp(math.floor((t - fromTime) / STEP + 0.5), 1, 24)
	local root = BlackComet.Attacker(plan, t).Position
	local side = SIDE_START + (SIDE - SIDE_START) * smooth(t / 0.15)
	for i = 1, steps do
		local neck = from:Lerp(target, i / steps)
		local feet = body.feet
		local velocity = (feet - body.last) * DAMPING
		body.last = feet
		feet += velocity + GRAVITY * STEP * STEP
		local function push(by: Vector3)
			feet += by
			body.last += by
		end
		for _ = 1, 3 do
			if feet.Y < floor then
				-- Scraping along the ground: no bounce, and it slows them.
				local slide = feet - body.last
				push(Vector3.new(0, floor - feet.Y, 0))
				body.last += Vector3.new(slide.X, 0, slide.Z) * FRICTION
			end
			local out = (feet - root):Dot(plan.right)
			if out > -side then
				push(plan.right * -(out + side))
			end
			if feet.Y > neck.Y - HEAD_DOWN then
				push(Vector3.new(0, neck.Y - HEAD_DOWN - feet.Y, 0))
			end
			local rod = feet - neck
			feet = neck + (if rod.Magnitude > 1e-4 then rod.Unit else -UP) * BODY
		end
		body.feet = feet
	end
	body.neck, body.t = target, t

	local axis = (target - body.feet).Unit
	local look = body.look - axis * body.look:Dot(axis)
	look = if look.Magnitude > 1e-3 then look.Unit else (UP - axis * axis.Y).Unit
	local upward = UP - axis * axis.Y
	if upward.Magnitude > 0.8 and look:Dot(upward) > 0 then
		local settle = math.clamp((upward.Magnitude - 0.8) / 0.2, 0, 1) * math.min((t - fromTime) * 6, 1)
		look = look:Lerp(upward.Unit, settle).Unit
	end
	body.look = look
	return CFrame.fromMatrix(target - axis, axis:Cross(-look), axis, -look)
end

function BlackComet.Plan(origin: Vector3, forward: Vector3, distance: number, floorY: number): Plan
	local plan: Plan = {
		origin = origin,
		forward = forward,
		right = forward:Cross(UP),
		distance = distance,
		floorY = floorY,
		above = math.clamp(origin.Y - (floorY + 3), 0, 40),
		victim = {},
	}
	-- Where the server holds them: the same body, on the clip's hand.
	local body = BlackComet.Body(plan, BlackComet.Hand(plan, 0))
	local release = BlackComet.Times.Release
	for i = 0, math.ceil(release * 60) do
		local t = math.min(i / 60, release)
		plan.victim[i + 1] = BlackComet.Step(plan, body, BlackComet.Hand(plan, t), t)
	end
	return plan
end

-- Where the server has them at `t` (up to Release).
function BlackComet.Victim(plan: Plan, t: number): CFrame
	local x = math.clamp(t, 0, BlackComet.Times.Release) * 60
	local i = math.floor(x)
	local a = plan.victim[i + 1]
	local b = plan.victim[math.min(i + 2, #plan.victim)]
	return a:Lerp(b, x - i)
end

return BlackComet
