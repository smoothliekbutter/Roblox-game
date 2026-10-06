local Zephyrus = {}

local UP = Vector3.yAxis

local TURNS = 2
local ORBIT = 0.9

Zephyrus.Radius = 4.6
Zephyrus.Lift = 1.6

local WIND_UP = 6
local THROUGH = 2.6

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

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

local cuts = {}
for i = 1, TURNS * 2 do
	table.insert(cuts, whenAround((i - 0.5) / (TURNS * 2)))
end

Zephyrus.Times = {
	Cuts = cuts,
	Out = ORBIT,
	Thrust = 1.0,
	Length = 1.3,
}

export type Plan = {
	center: Vector3,
	out: Vector3,
	side: Vector3,
	start: number,
	height: number,
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

local function around(t: number): number
	return TURNS * 2 * math.pi * smooth(t / ORBIT)
end

local function outward(plan: Plan, t: number): number
	local times = Zephyrus.Times
	local r = plan.start + (Zephyrus.Radius - plan.start) * smooth(t / 0.15)
	r += (WIND_UP - Zephyrus.Radius) * smooth((t - (ORBIT - 0.14)) / 0.2)
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
	local spin = 1.5 * TURNS * 2 * math.pi / ORBIT
	local speed = if t < ORBIT then (6 * (t / ORBIT) * (1 - t / ORBIT)) * TURNS * 2 * math.pi / ORBIT else 0
	local pace = speed / spin
	local lead = math.rad(18) * pace
	local facing = -radial * math.cos(lead) + UP:Cross(radial).Unit * math.sin(lead)
	return CFrame.lookAt(position, position + facing) * CFrame.Angles(math.rad(-14) * pace, 0, 0)
end

local function knock(t: number, at: number): number
	if t <= at then
		return 0
	end
	local u = (t - at) / 0.08
	return u * math.exp(1 - u)
end

function Zephyrus.Victim(plan: Plan, t: number): CFrame
	local position = plan.center + UP * lifted(t)
	local roll, pitch = 0, 0
	for i, at in Zephyrus.Times.Cuts do
		local k = knock(t, at)
		roll += (if i % 2 == 1 then 14 else -14) * k
		pitch -= 8 * k
	end
	return CFrame.lookAt(position, position + plan.out) * CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
end

return Zephyrus
