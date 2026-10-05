-- Spirit of Zephyrus's waltz paths (shared, so the server and every client agree).

local Zephyrus = {}

local UP = Vector3.yAxis

local TURNS = 2
local ORBIT = 0.9 -- seconds round them

Zephyrus.Radius = 4.6 -- how far out he circles them
Zephyrus.Lift = 1.6 -- how high the wind holds them (and him) up

local WIND_UP = 6 -- studs out from them as he draws back for the thrust
local THROUGH = 2.6 -- studs from them when the thrust lands

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- When (in seconds) the eased turn reaches `fraction` of the way round.
local function whenAround(fraction: number): number
	local lo, hi = 0, 1
	for _ = 1, 40 do
		local mid = (lo + hi) / 2
		if smooth(mid) < fraction then
			lo = mid
		else
			hi = mid
		end
	end
	return (lo + hi) / 2 * ORBIT
end

-- A cut every half turn: each time he's out at their side.
local cuts = {}
for i = 1, TURNS * 2 do
	table.insert(cuts, whenAround((i - 0.5) / (TURNS * 2)))
end

Zephyrus.Times = {
	Cuts = cuts,
	Out = ORBIT, -- round twice: he's back out in front of them
	Thrust = 1.0, -- the thrust lands (the spear goes through them)
	Length = 1.3, -- he's held his follow-through
}

export type Plan = {
	center: Vector3, -- where they're held (before the wind lifts them)
	out: Vector3, -- from them toward where he caught them (flat)
	side: Vector3, -- a quarter turn round from `out`
	start: number, -- how far from them he caught them
	height: number, -- his root's height over theirs when he caught them
}

function Zephyrus.Plan(attacker: Vector3, victim: Vector3): Plan
	local flat = Vector3.new(attacker.X - victim.X, 0, attacker.Z - victim.Z)
	local out = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, 1)
	return {
		center = victim,
		out = out,
		side = UP:Cross(out).Unit,
		start = math.max(flat.Magnitude, 1.5),
		height = attacker.Y - victim.Y,
	}
end

-- How far round him (radians) and how far out (studs), at `t`.
local function around(t: number): number
	return TURNS * 2 * math.pi * smooth(t / ORBIT)
end

local function outward(plan: Plan, t: number): number
	local times = Zephyrus.Times
	local r = plan.start + (Zephyrus.Radius - plan.start) * smooth(t / 0.15)
	-- Out a little as he comes round the last time, drawing back...
	r += (WIND_UP - Zephyrus.Radius) * smooth((t - (ORBIT - 0.14)) / 0.2)
	-- ...then in, faster and faster, for the thrust.
	local a = math.clamp((t - (times.Thrust - 0.1)) / 0.1, 0, 1)
	r += (THROUGH - WIND_UP) * a * a
	return r
end

local function lifted(t: number): number
	return Zephyrus.Lift * smooth(t / 0.3)
end

function Zephyrus.Attacker(plan: Plan, t: number): CFrame
	local angle = around(t)
	local radial = plan.out * math.cos(angle) + plan.side * math.sin(angle)
	local position = plan.center + radial * outward(plan, t) + UP * (plan.height + lifted(t))
	local spin = 1.5 * TURNS * 2 * math.pi / ORBIT -- the fastest it goes round
	local speed = if t < ORBIT then (6 * (t / ORBIT) * (1 - t / ORBIT)) * TURNS * 2 * math.pi / ORBIT else 0
	local pace = speed / spin
	local lead = math.rad(18) * pace
	local facing = -radial * math.cos(lead) + UP:Cross(radial).Unit * math.sin(lead)
	return CFrame.lookAt(position, position + facing) * CFrame.Angles(math.rad(-14) * pace, 0, 0)
end

-- A shove from a cut: out fast, easing back (u e^(1-u)).
local function knock(t: number, at: number): number
	if t <= at then
		return 0
	end
	local u = (t - at) / 0.08
	return u * math.exp(1 - u)
end

function Zephyrus.Victim(plan: Plan, t: number): CFrame
	local position = plan.center + UP * lifted(t)
	-- Facing where he caught them from, knocked about by each cut.
	local roll, pitch = 0, 0
	for i, at in Zephyrus.Times.Cuts do
		local k = knock(t, at)
		roll += (if i % 2 == 1 then 14 else -14) * k
		pitch -= 8 * k
	end
	return CFrame.lookAt(position, position + plan.out) * CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
end

return Zephyrus
