local BlackMoon = {}

BlackMoon.Times = {
	Release = 0.15,
	Night = 0.5,
	Rise = 0.6,
	Leap = 1.0,
	Apex = 1.35,
	Perch = 1.4,
	Close = 2.5,
	Point = 2.9,
	Glint = 3.4,
	Fly = 3.75,
	Cut = 3.9,
	Arrive = 4.0,
	Land = 4.9,
	Done = 5.9,
}

local UP = Vector3.yAxis
local DRIFT = 1.2

export type Plan = {
	origin: CFrame,
	forward: Vector3,
	right: Vector3,
	victimStart: Vector3,
	apex: Vector3,
	cut: Vector3,
	perch: Vector3,
	through: Vector3,
	beyond: Vector3,
	moonCamera: Vector3,
	moon: Vector3,
	moonRadius: number,
}

local function flat(v: Vector3, fallback: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else fallback
end

local function easeOut(a: number): number
	return 1 - (1 - a) * (1 - a)
end

function BlackMoon.Plan(origin: CFrame, victimStart: Vector3): Plan
	local forward = flat(origin.LookVector, Vector3.new(0, 0, -1))
	local right = forward:Cross(UP)
	local level = CFrame.lookAt(origin.Position, origin.Position + forward)
	local apex = origin.Position + forward * 5 + UP * 34
	local perch = apex - forward * 22 - UP * 5 + right * 5
	local cut = apex + UP * (BlackMoon.Times.Cut - BlackMoon.Times.Apex) * DRIFT
	local through = (cut - perch).Unit
	local beyond = cut + through * 14
	local moonCamera = apex + (perch - apex) * 0.2 + right * 2.5 - UP * 7
	local moon = perch + (perch - moonCamera).Unit * 280 + UP * 10
	return {
		origin = level,
		forward = forward,
		right = right,
		victimStart = victimStart,
		apex = apex,
		cut = cut,
		perch = perch,
		through = through,
		beyond = beyond,
		moonCamera = moonCamera,
		moon = moon,
		moonRadius = 95,
	}
end

function BlackMoon.Attacker(plan: Plan, t: number): CFrame
	local T = BlackMoon.Times
	local toVictim = flat(plan.apex - plan.perch, plan.forward)
	if t < T.Leap then
		return plan.origin
	elseif t < T.Perch then
		local a = (t - T.Leap) / (T.Perch - T.Leap)
		local p = plan.origin.Position:Lerp(plan.perch, easeOut(a)) + UP * math.sin(a * math.pi) * 4
		return CFrame.lookAt(p, p + toVictim)
	elseif t < T.Fly then
		local hover = t - T.Perch
		local p = plan.perch + UP * math.sin(hover * 5.3) * 0.6 + plan.right * math.sin(hover * 1.8) * 0.35
		return CFrame.lookAt(p, p + toVictim)
	elseif t < T.Arrive then
		local a = (t - T.Fly) / (T.Arrive - T.Fly)
		local p = plan.perch:Lerp(plan.beyond, a)
		return CFrame.lookAt(p, p + toVictim)
	end
	return CFrame.lookAt(plan.beyond, plan.beyond + toVictim)
end

function BlackMoon.Victim(plan: Plan, t: number): CFrame
	local T = BlackMoon.Times
	local facing = flat(plan.perch - plan.apex, -plan.forward)
	local held = math.min(t, T.Cut)
	local p
	if held < T.Release then
		p = plan.victimStart
	elseif held < T.Apex then
		p = plan.victimStart:Lerp(plan.apex, easeOut((held - T.Release) / (T.Apex - T.Release)))
	else
		p = plan.apex + UP * (held - T.Apex) * DRIFT
	end
	local tumble = math.max(held - T.Release, 0) * math.rad(110)
	return CFrame.lookAt(p, p + facing) * CFrame.Angles(-tumble, 0, 0)
end

local function orbit(center: Vector3, eye: Vector3, degrees: number): Vector3
	return center + CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(eye - center)
end

function BlackMoon.Camera(plan: Plan, t: number): (CFrame, number)
	local T = BlackMoon.Times
	local attacker = BlackMoon.Attacker(plan, t).Position
	local victim = BlackMoon.Victim(plan, t).Position
	if t < T.Rise then
		local eye = (plan.origin * CFrame.new(5.5, 1.2, 7)).Position
		return CFrame.lookAt(eye, (attacker + UP * 2):Lerp(victim, 0.65)), 70
	elseif t < T.Perch then
		local eye = plan.origin.Position + plan.forward * 26 + plan.right * 6 + UP * 2.5
		return CFrame.lookAt(eye, victim:Lerp(plan.perch, 0.35)), 62
	elseif t < T.Close then
		local eye = plan.moonCamera:Lerp(plan.perch, 0.05 * (t - T.Perch))
		return CFrame.lookAt(eye, attacker + UP * 0.5), 45
	elseif t < T.Fly then
		local start = plan.perch + (plan.moonCamera - plan.perch).Unit * 10 - UP * 1.5
		local eye = orbit(plan.perch, start, (t - T.Close) * 10 - 6)
		return CFrame.lookAt(eye, attacker + UP * 1), 38
	elseif t < T.Arrive then
		local eye = plan.cut + plan.through * 10 + plan.right * 3 + UP * 1.5
		return CFrame.lookAt(eye, plan.perch), 55
	end
	local start = plan.beyond + plan.through * 8 - plan.right * 2.5 + UP * 1
	local eye = orbit(plan.beyond, start, (t - T.Arrive) * -14)
	return CFrame.lookAt(eye, plan.beyond - plan.through * 6), 50
end

return BlackMoon
