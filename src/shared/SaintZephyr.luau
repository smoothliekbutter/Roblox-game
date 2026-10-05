--[[
	SaintZephyr
	Yuno's Full-Crown 4, the blow that cut Zenon in half: Saint Spirit of
	Zephyr. A star flicked onto whoever is in front of him binds them, and a
	column of wind carries them high into the sky with him flying up beside
	them. A constellation of eight stars opens round them. He flies round
	them from star to star and cuts straight through them from each, every
	cut one you can see him make (and each left hanging in the air), and he
	finishes it with an X.
	Then he's high above them with a colossal blade of wind and starlight,
	and splits them with one strike straight down through them to the
	ground. The hanging cuts detonate and they fall like a meteor into the
	ground behind him, his back to them.

	Shared so the server (which holds them both on the paths) and every
	client (which draws them on it smoothly) agree on where they are.
	t = 0 is the star binding them.
]]

local SaintZephyr = {}

local UP = Vector3.yAxis

SaintZephyr.Times = {
	Lift = 1.0, -- carried up to Height
	Open = 1.2, -- the constellation opens round them
	-- Each cut: a short dash round them to a star, then straight through
	-- them (he's in the middle of them at these times).
	Cuts = { 1.6, 1.82, 2.04, 2.26, 2.48, 2.7, 2.92, 3.14 },
	Cross = 3.4, -- the X
	Rise = 3.7, -- high above them, the blade growing
	Strike = 4.55, -- the one strike, straight down through them
	Burst = 4.8, -- the hanging cuts detonate
	Land = 5.15, -- they hit the ground
	Length = 6.1, -- he's standing, his back to them
}
SaintZephyr.Height = 32 -- how high they're carried
SaintZephyr.Ring = 12 -- the constellation's radius round them
SaintZephyr.Above = 22 -- how far above them he raises the blade
SaintZephyr.Dash = 0.09 -- round them to the next star
SaintZephyr.Through = 0.12 -- the cut itself, star to the far side, through them

-- How far each star sits above (or below) them, degrees.
local ELEVATIONS = { 24, -18, 14, -26, 30, -10, 18, -22 }

export type Plan = {
	origin: CFrame,
	start: Vector3,
	forward: Vector3,
	right: Vector3,
	floorY: number,
	center: Vector3, -- where they hang
	hover: Vector3, -- where he flies up to beside them
	stars: { Vector3 }, -- in the order he cuts from them
	cross: Vector3, -- where the X starts (his half of it)
	top: Vector3, -- where he raises the blade
	ground: Vector3, -- where the strike ends, his feet on the floor
}

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
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
	-- An eight-pointed star: each next star three points on, so every cut
	-- crosses the last at a wide angle, and the next star is only a short
	-- way round from where the last cut came out (a quick dash).
	local count = #SaintZephyr.Times.Cuts
	local stars = {}
	for i = 1, count do
		local step = ((i - 1) * 3) % count
		local angle = math.pi + step / count * math.pi * 2
		local elevation = math.rad(ELEVATIONS[(i - 1) % #ELEVATIONS + 1])
		local around = forward * math.cos(angle) + right * math.sin(angle)
		table.insert(
			stars,
			center + around * SaintZephyr.Ring * math.cos(elevation) + UP * SaintZephyr.Ring * math.sin(elevation)
		)
	end
	-- The strike runs from above them, through them, to the floor on his
	-- side of them.
	local reach = 3
	return {
		origin = origin,
		start = start,
		forward = forward,
		right = right,
		floorY = floorY,
		center = center,
		hover = center - forward * 7 + right * 2 - UP,
		stars = stars,
		cross = center + (UP - right).Unit * SaintZephyr.Ring,
		top = center + UP * SaintZephyr.Above + forward * reach,
		ground = start - forward * (reach * SaintZephyr.Height / SaintZephyr.Above),
	}
end

-- Out the far side of them from `from`.
function SaintZephyr.Exit(plan: Plan, from: Vector3): Vector3
	return plan.center + (plan.center - from)
end

local function facing(from: Vector3, to: Vector3, fallback: Vector3): CFrame
	local look = to - from
	if look.Magnitude < 1e-3 then
		look = fallback
	end
	return CFrame.lookAt(from, from + look)
end

-- Round them from one point to another (keeping about the same distance).
local function around(plan: Plan, from: Vector3, to: Vector3, a: number): Vector3
	local d0, d1 = from - plan.center, to - plan.center
	local direction = d0.Unit:Lerp(d1.Unit, a)
	direction = if direction.Magnitude > 1e-3 then direction.Unit else d1.Unit
	return plan.center + direction * (d0.Magnitude + (d1.Magnitude - d0.Magnitude) * a)
end

-- One cut, centred on `at`: a dash round them from `from` to `star`, then
-- straight through them to the far side, where he stays.
local function cut(plan: Plan, from: Vector3, star: Vector3, at: number, t: number): CFrame
	local half = SaintZephyr.Through / 2
	local exit = SaintZephyr.Exit(plan, star)
	if t < at - half then
		local a = smooth((t - (at - half - SaintZephyr.Dash)) / SaintZephyr.Dash)
		return facing(around(plan, from, star, a), plan.center, plan.forward)
	end
	local a = math.clamp((t - (at - half)) / SaintZephyr.Through, 0, 1)
	return facing(star:Lerp(exit, a), exit + (exit - star), plan.forward)
end

-- When the dash before the cut at `at` starts.
function SaintZephyr.DashFrom(at: number): number
	return at - SaintZephyr.Through / 2 - SaintZephyr.Dash
end

function SaintZephyr.Attacker(plan: Plan, t: number): CFrame
	local times = SaintZephyr.Times
	local cuts = times.Cuts
	local dashFrom = SaintZephyr.DashFrom
	if t < 0.25 then
		return plan.origin
	end
	if t < dashFrom(cuts[1]) then
		-- Flying up beside them on the wind.
		local a = smooth((t - 0.25) / (times.Lift - 0.1))
		local position = plan.origin.Position:Lerp(plan.hover, a)
		local lean = CFrame.Angles(math.rad(25) * math.sin(a * math.pi), 0, 0)
		return facing(position, plan.center, plan.forward) * lean
	end
	if t < dashFrom(times.Cross) then
		local index = 1
		for i, at in cuts do
			if t >= dashFrom(at) then
				index = i
			end
		end
		local from = if index == 1 then plan.hover else SaintZephyr.Exit(plan, plan.stars[index - 1])
		return cut(plan, from, plan.stars[index], cuts[index], t)
	end
	if t < times.Rise - 0.15 then
		return cut(plan, SaintZephyr.Exit(plan, plan.stars[#cuts]), plan.cross, times.Cross, t)
	end
	if t < times.Strike - 0.04 then
		-- Up above them in a rush of wind, then high there, looking down at
		-- them, the blade raised.
		local a = smooth((t - (times.Rise - 0.15)) / 0.15)
		return CFrame.new(SaintZephyr.Exit(plan, plan.cross):Lerp(plan.top, a))
			* CFrame.lookAt(Vector3.zero, plan.forward).Rotation
			* CFrame.Angles(math.rad(-25) * a, 0, 0)
	end
	if t < times.Strike + 0.1 then
		local a = smooth((t - (times.Strike - 0.04)) / 0.14)
		return CFrame.new(plan.top:Lerp(plan.ground, a)) * CFrame.lookAt(Vector3.zero, plan.forward).Rotation
	end
	-- Landed, turning his back to them.
	local turn = smooth((t - (times.Strike + 0.1)) / 0.25)
	return CFrame.new(plan.ground)
		* CFrame.lookAt(Vector3.zero, plan.forward).Rotation
		* CFrame.Angles(0, math.pi * turn, 0)
end

function SaintZephyr.Victim(plan: Plan, t: number): CFrame
	local times = SaintZephyr.Times
	local toward = CFrame.lookAt(Vector3.zero, -plan.forward).Rotation -- facing him
	if t <= times.Lift then
		-- Carried up in the column, turning once.
		local a = smooth(t / times.Lift)
		return CFrame.new(plan.start:Lerp(plan.center, a))
			* CFrame.Angles(0, a * math.pi * 2, 0)
			* toward
			* CFrame.Angles(math.rad(-20) * a, 0, 0)
	end
	if t <= times.Burst then
		-- Hung there, knocked about by each cut.
		local offset = Vector3.zero
		local function knock(from: Vector3, at: number)
			if t >= at then
				local push = SaintZephyr.Exit(plan, from) - from
				offset += push.Unit * 0.6 * math.exp(-(t - at) * 14)
			end
		end
		for i, at in times.Cuts do
			knock(plan.stars[i], at)
		end
		knock(plan.cross, times.Cross)
		local sway = if t < times.Strike then math.sin(t * 9) * math.rad(8) else 0
		return CFrame.new(plan.center + offset) * toward * CFrame.Angles(math.rad(-20), sway, 0)
	end
	-- Falling like a meteor, faster and faster, into the ground.
	local a = math.clamp((t - times.Burst) / (times.Land - times.Burst), 0, 1)
	local floor = Vector3.new(plan.start.X, plan.floorY + 1.5, plan.start.Z)
	return CFrame.new(plan.center:Lerp(floor, a * a)) * toward * CFrame.Angles(math.rad(-20 - 70 * a), 0, 0)
end

return SaintZephyr
