--[[
	BlackMoon
	The timeline of Black Moon (Asta's Black Form 4th move): he hurls them
	into the sky, night falls, he hangs in front of a giant moon, then flies
	through them and cuts them down.

	Shared so the server (which holds both fighters on these paths) and
	every client (which draws them there smoothly, with the camera work and
	effects) agree on where everyone is at every moment. Everything is
	worked out from where he stood when he threw them. t = 0 is the throw.
]]

local BlackMoon = {}

-- About six seconds, plus the grab before it.
BlackMoon.Times = {
	Release = 0.15, -- they leave his hand
	Night = 0.5, -- night starts to fall
	Rise = 0.6, -- shot: watching them rise against the moon
	Leap = 1.0, -- he jumps up after them
	Apex = 1.35, -- they reach the top
	Perch = 1.4, -- he's hovering in front of the moon
	Close = 2.5, -- shot: close on him, the moon behind
	Point = 2.9, -- he levels the sword at them
	Glint = 3.4, -- the blade catches the moonlight
	Fly = 3.75, -- he flies at them
	Cut = 3.9, -- passing through them
	Arrive = 4.0, -- stopped past them, back turned; everything goes still
	Land = 4.9, -- the cut lands; both are let go
	Done = 5.9, -- the camera comes back
}

local UP = Vector3.yAxis

export type Plan = {
	origin: CFrame, -- his root at the throw, level
	forward: Vector3,
	right: Vector3,
	victimStart: Vector3,
	apex: Vector3, -- where they hang in the sky
	perch: Vector3, -- where he waits, in front of the moon
	through: Vector3, -- direction of his flight
	beyond: Vector3, -- where he stops after the cut
	moonCamera: Vector3, -- the camera for the moon shot
	moon: Vector3, -- the moon, behind him from that camera
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
	local through = (apex - perch).Unit
	local beyond = apex + through * 14
	local moonCamera = apex + (perch - apex) * 0.2 + right * 2.5 + UP * 0.8
	local moon = perch + (perch - moonCamera).Unit * 280 + UP * 30
	return {
		origin = level,
		forward = forward,
		right = right,
		victimStart = victimStart,
		apex = apex,
		perch = perch,
		through = through,
		beyond = beyond,
		moonCamera = moonCamera,
		moon = moon,
		moonRadius = 95,
	}
end

-- Where Asta's root is at time t.
function BlackMoon.Attacker(plan: Plan, t: number): CFrame
	local T = BlackMoon.Times
	local toVictim = flat(plan.apex - plan.perch, plan.forward)
	if t < T.Leap then
		return plan.origin
	elseif t < T.Perch then
		-- The leap: an arc up to the perch.
		local a = (t - T.Leap) / (T.Perch - T.Leap)
		local p = plan.origin.Position:Lerp(plan.perch, easeOut(a)) + UP * math.sin(a * math.pi) * 4
		return CFrame.lookAt(p, p + toVictim)
	elseif t < T.Fly then
		-- Hovering on his wings: rising and falling with the beats, drifting.
		local hover = t - T.Perch
		local p = plan.perch + UP * math.sin(hover * 5.3) * 0.6 + plan.right * math.sin(hover * 1.8) * 0.35
		return CFrame.lookAt(p, p + toVictim)
	elseif t < T.Arrive then
		-- Straight through them, flat out.
		local a = (t - T.Fly) / (T.Arrive - T.Fly)
		local p = plan.perch:Lerp(plan.beyond, a)
		return CFrame.lookAt(p, p + toVictim)
	end
	return CFrame.lookAt(plan.beyond, plan.beyond + toVictim)
end

-- Where the victim's root is at time t: hurled up, drifting and tumbling
-- at the top, then frozen still from the cut until it lands.
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
		p = plan.apex + UP * (held - T.Apex) * 1.2
	end
	local tumble = math.max(held - T.Release, 0) * math.rad(110)
	return CFrame.lookAt(p, p + facing) * CFrame.Angles(-tumble, 0, 0)
end

--[[
	The camera for the two people in the cutscene: (cframe, field of view).
	Shots: the throw from low behind him; a wide low shot of them rising
	against the moon as he leaps after them; the moon shot (him a
	silhouette in front of it, slowly pushing in); a close-up circling him
	as he levels the sword; the flight straight at the camera through them;
	the frozen moment after the cut, circling slowly. After the cut lands
	the client follows them down.
]]
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
		-- From the ground out in front, looking back up past them at the moon.
		local eye = plan.origin.Position + plan.forward * 26 + plan.right * 6 + UP * 2.5
		return CFrame.lookAt(eye, victim:Lerp(plan.perch, 0.35)), 62
	elseif t < T.Close then
		local eye = plan.moonCamera:Lerp(plan.perch, 0.05 * (t - T.Perch))
		return CFrame.lookAt(eye, attacker + UP * 0.5), 45
	elseif t < T.Fly then
		-- Close and a little below him, drifting round; the moon fills the back.
		local start = plan.perch + (plan.moonCamera - plan.perch).Unit * 10 - UP * 1.5
		local eye = orbit(plan.perch, start, (t - T.Close) * 10 - 6)
		return CFrame.lookAt(eye, attacker + UP * 1), 38
	elseif t < T.Arrive then
		local eye = plan.apex + plan.through * 10 + plan.right * 3 + UP * 1.5
		return CFrame.lookAt(eye, plan.perch), 55
	end
	local start = plan.beyond + plan.through * 8 - plan.right * 2.5 + UP * 1
	local eye = orbit(plan.beyond, start, (t - T.Arrive) * -14)
	return CFrame.lookAt(eye, plan.beyond - plan.through * 6), 50
end

return BlackMoon
