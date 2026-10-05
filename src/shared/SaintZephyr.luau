--[[
	SaintZephyr
	Yuno's Full-Crown 4, the blow that cut Zenon in half: Saint Spirit of
	Zephyr. A star flicked onto whoever is in front of him binds them, and a
	column of wind carries them high into the sky with him flying up beside
	them. A constellation of eight stars opens round them. From his own star
	he charges straight through them, and then he never stops: out round a
	star, back through them, out round the next, every pass a cut, faster
	and faster (the path he flies is a flower of eight petals round them,
	one star at the tip of each). He finishes it with a rising X.
	Then he's high above them with a colossal blade of wind and starlight,
	and splits them with one strike straight down through them to the
	ground. The hanging cuts detonate and they fall like a meteor into the
	ground behind him, his back to them.

	Every move he makes is one smooth curve (position and speed never jump;
	he always faces the way he's flying, leaning into it), so nothing snaps
	or teleports, at any frame rate.

	Shared so the server (which holds them both on the paths) and every
	client (which draws them on it smoothly) agree on where they are.
	t = 0 is the star binding them.
]]

local SaintZephyr = {}

local UP = Vector3.yAxis

-- The flight is laid out on its own clock (PATH). Real time runs the same
-- except round the strike, where it slows right down as the blade goes
-- through them and picks up again (SlowMo), so everything after the
-- strike happens a little later in real time. SaintZephyr.Times is the
-- real timeline: schedule on that.
local PATH = {
	Lift = 1.0, -- carried up to Height
	Open = 1.15, -- the constellation has opened round them
	Hover = 1.2, -- he's up beside them, at his star
	-- Each cut: the moment he's in the middle of them. The gaps shrink
	-- (faster and faster).
	Cuts = { 1.62, 1.89, 2.15, 2.4, 2.64, 2.87, 3.09, 3.3 },
	Cross = 3.6, -- the X (him in the middle of them again)
	Rise = 3.94, -- high above them, the blade growing
	Strike = 4.72, -- the one strike, straight down through them
	Burst = 4.97, -- the hanging cuts detonate
	Land = 5.32, -- they hit the ground
	Length = 6.3, -- he's standing, his back to them
}
SaintZephyr.SlowMo = 0.16 -- half the slow motion round the strike (real seconds)
SaintZephyr.Linger = 0.15 -- how much longer the strike takes than at full speed

local function smoother(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

-- (Real time at which the slow motion starts: placed so its slowest moment,
-- halfway through, is the blade going through them.)
local SLOW_FROM = PATH.Strike - SaintZephyr.SlowMo + SaintZephyr.Linger / 2

-- The path's clock at real time `t`.
function SaintZephyr.PathTime(t: number): number
	return t - SaintZephyr.Linger * smoother((t - SLOW_FROM) / (2 * SaintZephyr.SlowMo))
end

-- The real time at which the path's clock reads `p`.
function SaintZephyr.RealTime(p: number): number
	if p <= SLOW_FROM then
		return p
	end
	local t = p + SaintZephyr.Linger / 2
	for _ = 1, 12 do
		-- Newton's method on PathTime(t) = p (it only ever speeds up again,
		-- so this settles at once).
		local x = (t - SLOW_FROM) / (2 * SaintZephyr.SlowMo)
		local slope = if x > 0 and x < 1
			then 1 - SaintZephyr.Linger / (2 * SaintZephyr.SlowMo) * 30 * x * x * (1 - x) * (1 - x)
			else 1
		t -= (SaintZephyr.PathTime(t) - p) / slope
	end
	return t
end

SaintZephyr.Times = {
	Lift = PATH.Lift,
	Open = PATH.Open,
	Hover = PATH.Hover,
	Cuts = table.clone(PATH.Cuts),
	Cross = PATH.Cross,
	Rise = PATH.Rise,
	Strike = SaintZephyr.RealTime(PATH.Strike),
	Burst = SaintZephyr.RealTime(PATH.Burst),
	Land = SaintZephyr.RealTime(PATH.Land),
	Length = SaintZephyr.RealTime(PATH.Length),
}
SaintZephyr.Height = 32 -- how high they're carried
SaintZephyr.Ring = 12 -- the constellation's radius round them
SaintZephyr.Above = 22 -- how far above them he raises the blade
SaintZephyr.Charge = 0.26 -- from his star to the first cut
SaintZephyr.Drift = 2 -- how far he rises above the top while the blade grows
SaintZephyr.Dive = 0.18 -- the strike, from the top to the floor
-- How high his body hovers over his root in the Full-Crown (the client's
-- lift, Client/Kits/Wind). The server starts the path that much higher and
-- the client drops the lift at the same moment, so his body doesn't move.
SaintZephyr.Lift = 1.8

-- How far each star sits above (or below) them, degrees, in the order he
-- goes round them. High and low by turns, so the cuts cross each other.
local ELEVATIONS = { 24, -18, 28, -24, 16, -28, 22, -20 }
local HOVER_ELEVATION = -12 -- his own star, a little below them
local CROSS_ELEVATION = 38 -- how steeply the X rises
local HALF_PETAL = math.rad(22.5) -- each petal's half-width round them
local PASS_REACH = 1.45 -- the speed through them, as rings per half-petal
local TIP_SPEED = 0.25 -- round a star, against the speed through them
local SWAY = 0.35 -- how much of each turn he saves for round the star (0: an even turn)
local LEAN = math.rad(16) -- leaning into the flight at full speed

export type Plan = {
	origin: CFrame,
	start: Vector3,
	forward: Vector3,
	right: Vector3,
	floorY: number,
	center: Vector3, -- where they hang
	hover: Vector3, -- his star, beside them, where the first cut starts
	stars: { Vector3 }, -- the constellation, in the order he goes round it
	passes: { Vector3 }, -- the way he's going through them at each cut (then the X)
	speeds: { number }, -- how fast (studs/s) at each of those
	tangents: { Vector3 }, -- the way he's going round each star
	top: Vector3, -- where he raises the blade
	ground: Vector3, -- where the strike ends, his feet on the floor
}

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

-- Round them at `azimuth` (radians, from `forward` toward `right`) and
-- `elevation` (radians).
local function direction(plan: Plan, azimuth: number, elevation: number): Vector3
	local flat = plan.forward * math.cos(azimuth) + plan.right * math.sin(azimuth)
	return flat * math.cos(elevation) + UP * math.sin(elevation)
end

-- The pass times in order: the eight cuts, then the X.
local function passTimes(): { number }
	local times = table.clone(PATH.Cuts)
	table.insert(times, PATH.Cross)
	return times
end

function SaintZephyr.Plan(origin: CFrame, victimPosition: Vector3, floorY: number): Plan
	local toward = victimPosition - origin.Position
	local flat = Vector3.new(toward.X, 0, toward.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(origin.LookVector.X, 0, origin.LookVector.Z)
	end
	local forward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local right = forward:Cross(UP)
	local start = Vector3.new(victimPosition.X, floorY + 3, victimPosition.Z)
	local center = start + UP * SaintZephyr.Height
	local ring = SaintZephyr.Ring
	local plan: Plan = {
		origin = origin,
		start = start,
		forward = forward,
		right = right,
		floorY = floorY,
		center = center,
		hover = center,
		stars = {},
		passes = {},
		speeds = {},
		tangents = {},
		top = center,
		ground = start,
	}

	-- His star is on his side of them; he charges from it straight through
	-- them. Then each petal's star is a petal and a half round from the
	-- last (225 degrees: the eight-pointed star drawn in one line), its
	-- petal opening 22.5 degrees either side of it.
	local home = math.pi
	local hoverElevation = math.rad(HOVER_ELEVATION)
	plan.hover = center + direction(plan, home, hoverElevation) * ring
	local azimuths, elevations = {}, {}
	for i = 1, #ELEVATIONS do
		azimuths[i] = home + math.pi + HALF_PETAL + (i - 1) * math.rad(225)
		elevations[i] = math.rad(ELEVATIONS[i])
		table.insert(plan.stars, center + direction(plan, azimuths[i], elevations[i]) * ring)
	end

	-- Through them: the first from his star; each after that from where the
	-- last petal comes back in to where the next one goes out; the X rising
	-- steeply from his side to the far side.
	table.insert(plan.passes, (center - plan.hover).Unit)
	for i = 2, #ELEVATIONS do
		local from = direction(plan, azimuths[i - 1] + HALF_PETAL, elevations[i - 1])
		local to = direction(plan, azimuths[i] - HALF_PETAL, elevations[i])
		table.insert(plan.passes, (to - from).Unit)
	end
	local cross = math.rad(CROSS_ELEVATION)
	table.insert(plan.passes, (direction(plan, 0, cross) - direction(plan, math.pi, -cross)).Unit + right * 0.12)
	plan.passes[#plan.passes] = plan.passes[#plan.passes].Unit

	-- The faster the petals come, the faster he goes through them. The first
	-- cut's speed is the charge's (from standing still at his star).
	local times = passTimes()
	for i, at in times do
		if i == 1 then
			plan.speeds[i] = 3 * ring / SaintZephyr.Charge
		else
			local before = (at - times[i - 1]) / 2
			local after = if times[i + 1] then (times[i + 1] - at) / 2 else before
			plan.speeds[i] = PASS_REACH * ring / ((before + after) / 2)
		end
	end
	-- Round each star: across the petal, from the side he went out on to the
	-- side he comes back in on.
	for i, star in plan.stars do
		local radial = (star - center).Unit
		local across = -(plan.passes[i] + plan.passes[i + 1])
		across -= radial * radial:Dot(across)
		plan.tangents[i] = if across.Magnitude > 1e-3 then across.Unit else plan.right
	end

	-- The strike runs from above them on the far side (where the X carries
	-- him), down through them, to the floor on his side of them (so he
	-- lands with his back to them).
	local reach = 7 -- (he lands well clear of where they hit)
	plan.top = center + UP * SaintZephyr.Above + forward * reach
	plan.ground = start - forward * (reach * SaintZephyr.Height / (SaintZephyr.Above + SaintZephyr.Drift))
	return plan
end

-- A cubic Hermite curve from p0 to p1 leaving at velocity v0 and arriving at
-- v1 (studs/s) over `duration`: the position and velocity `s` (0 to 1)
-- along it.
local function hermite(
	p0: Vector3,
	v0: Vector3,
	p1: Vector3,
	v1: Vector3,
	duration: number,
	s: number
): (Vector3, Vector3)
	local s2, s3 = s * s, s * s * s
	local m0, m1 = v0 * duration, v1 * duration
	local position = p0 * (2 * s3 - 3 * s2 + 1) + m0 * (s3 - 2 * s2 + s) + p1 * (3 * s2 - 2 * s3) + m1 * (s3 - s2)
	local velocity = p0 * (6 * s2 - 6 * s) + m0 * (3 * s2 - 4 * s + 1) + p1 * (6 * s - 6 * s2) + m1 * (3 * s2 - 2 * s)
	return position, velocity / duration
end

-- Where he is and how he's moving, from the first cut to the top (the
-- passes and the petals between them).
local function petals(plan: Plan, t: number): (Vector3, Vector3)
	local times = passTimes()
	local count = #times
	if t >= times[count] then
		-- After the X: up and back over to the top.
		local duration = PATH.Rise - times[count]
		local s = math.clamp((t - times[count]) / duration, 0, 1)
		return hermite(plan.center, plan.passes[count] * plan.speeds[count], plan.top, UP * 4, duration, s)
	end
	local index = 1
	for i = 1, count - 1 do
		if t >= times[i] then
			index = i
		end
	end
	local from, to = times[index], times[index + 1]
	local tip = (from + to) / 2
	local half = (to - from) / 2
	local star = plan.stars[index]
	local tipVelocity = plan.tangents[index] * plan.speeds[index] * TIP_SPEED
	if t < tip then
		return hermite(plan.center, plan.passes[index] * plan.speeds[index], star, tipVelocity, half, (t - from) / half)
	end
	return hermite(
		star,
		tipVelocity,
		plan.center,
		plan.passes[index + 1] * plan.speeds[index + 1],
		half,
		(t - tip) / half
	)
end

-- Up on the blade, above them: turned back toward his side, looking down
-- at them.
local function poised(plan: Plan, position: Vector3, pitch: number): CFrame
	return CFrame.new(position) * CFrame.lookAt(Vector3.zero, -plan.forward).Rotation * CFrame.Angles(pitch, 0, 0)
end

-- Leaning into the flight, the faster he goes.
local function lean(speed: number): CFrame
	return CFrame.Angles(-LEAN * math.min(speed / 120, 1), 0, 0)
end

-- Round a petal he turns the long way round from the heading he went
-- through them on to the one he comes back on, steadily, a little quicker
-- round the star.
local function turning(from: Vector3, to: Vector3, u: number): Vector3
	local axis = to:Cross(from)
	if axis.Magnitude < 1e-4 then
		axis = if math.abs(from.Y) < 0.9 then UP:Cross(from) else Vector3.xAxis
	end
	local short = math.acos(math.clamp(from:Dot(to), -1, 1))
	local eased = u - SWAY * math.sin(2 * math.pi * u) / (2 * math.pi)
	return CFrame.fromAxisAngle(axis.Unit, (2 * math.pi - short) * eased):VectorToWorldSpace(from)
end

local POISED_PITCH = math.rad(-18)

-- The heading (radians round the vertical) a flat direction points along.
local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

-- An angle taken the short way round (-pi to pi).
local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- Pitch kept under about 55 degrees: unchanged up to 30, then easing off
-- (so it never stops dead against a limit).
local function softPitch(pitch: number): number
	local k, m = math.rad(30), math.rad(55)
	local over = math.abs(pitch) - k
	if over <= 0 then
		return pitch
	end
	return math.sign(pitch) * (k + (m - k) * math.tanh(over / (m - k)))
end

-- Where he is and how he's moving at `t` (only meaningful while he's in
-- the air: from flying up to the strike).
local function flight(plan: Plan, t: number): (Vector3, Vector3)
	local times = PATH
	local cuts = times.Cuts
	local charge = cuts[1] - SaintZephyr.Charge
	if t < times.Hover then
		-- Up beside them on the wind, curving out round the column.
		local a = smooth((t - 0.25) / (times.Hover - 0.25))
		local from, to = plan.origin.Position, plan.hover
		local bow = plan.right * 4 + UP * 2
		local position = from:Lerp(to, a) + bow * math.sin(a * math.pi)
		return position, Vector3.zero
	elseif t < charge then
		-- Waiting at his star (a breath of drift).
		local u = (t - times.Hover) / (charge - times.Hover)
		return plan.hover + UP * 0.35 * math.sin(u * math.pi) ^ 2, Vector3.zero
	elseif t < cuts[1] then
		-- The charge: from standing still, faster and faster, straight in.
		local s = (t - charge) / SaintZephyr.Charge
		local line = plan.center - plan.hover
		return plan.hover + line * (s * s * s), line * (3 * s * s / SaintZephyr.Charge)
	end
	return petals(plan, t)
end

-- When the strike's dive starts and when he lands: timed so he's in the
-- middle of them at Times.Strike (the dive speeds up all the way down).
local function diveTimes(): (number, number)
	local above = SaintZephyr.Above + SaintZephyr.Drift
	local through = math.sqrt(above / (above + SaintZephyr.Height))
	local strike = PATH.Strike
	return strike - through * SaintZephyr.Dive, strike + (1 - through) * SaintZephyr.Dive
end

local victimAt: (Plan, number) -> CFrame

local function attackerAt(plan: Plan, t: number): CFrame
	local times = PATH
	local cuts = times.Cuts
	if t < 0.25 then
		return plan.origin
	end
	if t < times.Hover then
		-- Flying up beside them, looking up at them as they're carried up,
		-- turning to them from the way he was standing (by the angle, so
		-- however far round it is it's one steady turn).
		local position = flight(plan, t)
		local look = victimAt(plan, math.min(t, times.Lift)).Position - position
		local flat = Vector3.new(look.X, 0, look.Z)
		local heading = if flat.Magnitude > 1e-3 then flat.Unit else plan.forward
		local first = victimAt(plan, 0.25).Position - plan.origin.Position
		first = Vector3.new(first.X, 0, first.Z)
		first = if first.Magnitude > 1e-3 then first.Unit else plan.forward
		local start = plan.origin.LookVector
		start = Vector3.new(start.X, 0, start.Z)
		start = if start.Magnitude > 1e-3 then start.Unit else plan.forward
		local ease = smooth((t - 0.25) / 0.35)
		local turn = wrap(yawOf(first) - yawOf(start)) + wrap(yawOf(heading) - yawOf(first))
		local yaw = yawOf(start) + turn * ease
		local pitch = softPitch(math.atan2(look.Y, math.max(flat.Magnitude, 1e-3))) * ease
		return CFrame.new(position) * CFrame.fromOrientation(pitch, yaw, 0)
	end
	if t < cuts[1] then
		-- At his star and charging from it: facing straight through them.
		local position, velocity = flight(plan, t)
		return CFrame.lookAt(position, position + plan.passes[1]) * lean(velocity.Magnitude)
	end
	if t < times.Cross then
		-- Round the petals, turning with them.
		local position, velocity = flight(plan, t)
		local passes = passTimes()
		local index = 1
		for i = 1, #passes - 1 do
			if t >= passes[i] then
				index = i
			end
		end
		local u = (t - passes[index]) / (passes[index + 1] - passes[index])
		local heading = turning(plan.passes[index], plan.passes[index + 1], u)
		return CFrame.lookAt(position, position + heading) * lean(velocity.Magnitude)
	end
	if t < times.Rise then
		-- Up out of the X and over to the top, turning round to face down at
		-- them.
		local position = flight(plan, t)
		local count = #plan.passes
		local x = plan.passes[count]
		local out = CFrame.lookAt(position, position + x) * lean(plan.speeds[count])
		local w = smooth((t - times.Cross) / (times.Rise - times.Cross))
		return out:Lerp(poised(plan, position, POISED_PITCH), w)
	end
	local hold, landed = diveTimes()
	if t < hold then
		-- High above them, rising a little as the blade grows.
		local s = math.clamp((t - times.Rise) / (hold - times.Rise), 0, 1)
		local position =
			hermite(plan.top, UP * 4, plan.top + UP * SaintZephyr.Drift, Vector3.zero, hold - times.Rise, s)
		return poised(plan, position, POISED_PITCH)
	end
	if t < landed then
		-- The strike: dropping faster and faster, down through them.
		local s = (t - hold) / (landed - hold)
		local from = plan.top + UP * SaintZephyr.Drift
		return poised(plan, from:Lerp(plan.ground, s * s), POISED_PITCH * (1 - smooth(s)))
	end
	-- Landed on his side of them, his back to them, his head turning a
	-- little.
	local turn = smooth((t - landed) / 0.9)
	return CFrame.new(plan.ground)
		* CFrame.lookAt(Vector3.zero, -plan.forward).Rotation
		* CFrame.Angles(0, math.rad(14) * turn, 0)
end

-- A knock that throws them `amount` along and eases back: no jump in where
-- they are, only in how they're moving (the blow landing).
local function knock(t: number, at: number, peak: number): number
	if t < at then
		return 0
	end
	local u = (t - at) / peak
	return u * math.exp(1 - u)
end

-- Where they hang, knocked about by each cut (between the lift and the burst).
local function hanging(plan: Plan, t: number): CFrame
	local times = PATH
	local toward = CFrame.lookAt(Vector3.zero, -plan.forward).Rotation -- facing him
	local offset = Vector3.zero
	local twist, tip = 0, 0
	local passes = passTimes()
	for i, at in passes do
		local k = knock(t, at, 0.05)
		local big = i == #passes
		offset += plan.passes[i] * (if big then 1.2 else 0.7) * k
		twist += (if i % 2 == 1 then 1 else -1) * math.rad(if big then 22 else 12) * k
		tip += math.rad(if big then -14 else -6) * k
	end
	-- Split by the strike: driven down hard.
	local struck = knock(t, times.Strike, 0.08)
	offset += -UP * 2.4 * struck
	tip += math.rad(-25) * struck
	local sway = math.sin(t * 9) * math.rad(8) * (1 - smooth((t - times.Rise) / 0.4))
	return CFrame.new(plan.center + offset) * toward * CFrame.Angles(math.rad(-20) + tip, sway + twist, 0)
end

function victimAt(plan: Plan, t: number): CFrame
	local times = PATH
	if t <= times.Lift then
		-- Carried up in the column, turning once, coming to rest as they
		-- reach the top (exactly as they then hang).
		local a = smooth(t / times.Lift)
		local hang = hanging(plan, t)
		local toward = CFrame.lookAt(Vector3.zero, -plan.forward).Rotation
		return CFrame.new(plan.start:Lerp(plan.center, a))
			* CFrame.Angles(0, (a - 1) * math.pi * 2, 0)
			* toward:Lerp(hang.Rotation, a)
	end
	if t <= times.Burst then
		return hanging(plan, t)
	end
	-- Falling like a meteor, faster and faster, into the ground.
	local from = hanging(plan, times.Burst)
	local a = math.clamp((t - times.Burst) / (times.Land - times.Burst), 0, 1)
	local floor = Vector3.new(plan.start.X, plan.floorY + 1.5, plan.start.Z)
	return CFrame.new(from.Position:Lerp(floor, a * a)) * from.Rotation * CFrame.Angles(math.rad(-70) * smooth(a), 0, 0)
end

-- Where he is at real time `t` (t = 0: the star binding them).
function SaintZephyr.Attacker(plan: Plan, t: number): CFrame
	return attackerAt(plan, SaintZephyr.PathTime(t))
end

-- Where they are at real time `t`.
function SaintZephyr.Victim(plan: Plan, t: number): CFrame
	return victimAt(plan, SaintZephyr.PathTime(t))
end

-- When the strike's dive starts and when he lands, in real time.
function SaintZephyr.DiveTimes(): (number, number)
	local hold, landed = diveTimes()
	return SaintZephyr.RealTime(hold), SaintZephyr.RealTime(landed)
end

return SaintZephyr
