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

BlackMoon.Times = {
	Release = 0.12, -- they leave his hand
	Night = 0.45, -- night starts to fall
	Leap = 0.55, -- he jumps up to his perch
	Apex = 0.7, -- they reach the top
	Perch = 0.85, -- he's in front of the moon
	Glint = 1.35, -- the blade catches the moonlight
	Fly = 1.55, -- he flies at them
	Cut = 1.7, -- passing through them
	Arrive = 1.8, -- stopped past them, back turned
	Land = 2.25, -- the cut lands; both are let go
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
	local moon = perch + (perch - moonCamera).Unit * 260 + UP * 25
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
		moonRadius = 75,
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
	local tumble = math.max(held - T.Release, 0) * math.rad(150)
	return CFrame.lookAt(p, p + facing) * CFrame.Angles(-tumble, 0, 0)
end

--[[
	The camera for the two people in the cutscene: (cframe, field of view).
	Shots: the throw from low behind him, the moon shot (him silhouetted in
	front of the moon), the flight coming straight at the camera through
	them, the frozen moment after the cut, then whatever the client does
	after the cut lands (following them down).
]]
function BlackMoon.Camera(plan: Plan, t: number): (CFrame, number)
	local T = BlackMoon.Times
	local attacker = BlackMoon.Attacker(plan, t).Position
	if t < T.Leap then
		local victim = BlackMoon.Victim(plan, t).Position
		local eye = (plan.origin * CFrame.new(5.5, 1.2, 7)).Position
		return CFrame.lookAt(eye, (attacker + UP * 2):Lerp(victim, 0.65)), 70
	elseif t < T.Fly then
		-- Slowly pushing in on him while he waits.
		local eye = plan.moonCamera:Lerp(plan.perch, 0.05 * (t - T.Leap))
		return CFrame.lookAt(eye, attacker + UP * 0.5), 45
	elseif t < T.Arrive then
		local eye = plan.apex + plan.through * 10 + plan.right * 3 + UP * 1.5
		return CFrame.lookAt(eye, plan.perch), 55
	end
	local eye = plan.beyond + plan.through * 8 - plan.right * 2.5 + UP * 1
	return CFrame.lookAt(eye, plan.beyond - plan.through * 6), 50
end

return BlackMoon
