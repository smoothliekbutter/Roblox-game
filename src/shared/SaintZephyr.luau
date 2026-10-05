--[[
	SaintZephyr
	Yuno's Full-Crown 4, the blow that cut Zenon in half: Saint Spirit of
	Zephyr. A star flicked onto whoever is in front of him binds them and
	lifts them into the air, and five stars open round them in a pentagram.
	Conjunction takes him from star to star, each time straight through
	them (every cut hangs in the air). Then he's high above them with a blade
	of wind and starlight, and splits them with one strike straight down
	through them to the ground. The hanging cuts burst and they're driven
	into the ground behind him, his back to them.

	Shared so the server (which holds them both on the paths) and every
	client (which draws them on it smoothly) agree on where they are.
	t = 0 is the star binding them.
]]

local SaintZephyr = {}

local UP = Vector3.yAxis

SaintZephyr.Times = {
	Lift = 0.45, -- bound by the star and lifted
	Cuts = { 0.6, 0.8, 1.0, 1.2, 1.4 }, -- through them from each star
	Rise = 1.6, -- high above them, the blade raised
	Strike = 2.25, -- the one strike, straight down through them
	Burst = 2.45, -- every cut left hanging in the air bursts
	Land = 2.75, -- they hit the ground
	Length = 3.3, -- he's standing, his back to them
}
SaintZephyr.Height = 8 -- how high the star lifts them
SaintZephyr.Ring = 8.5 -- the pentagram's radius round them
SaintZephyr.Above = 12 -- how far above them he raises the blade
SaintZephyr.Appear = 0.12 -- he appears at a star this long before cutting
SaintZephyr.Through = 0.08 -- the cut itself, star to star through them

export type Plan = {
	origin: CFrame,
	start: Vector3,
	forward: Vector3,
	right: Vector3,
	floorY: number,
	center: Vector3, -- where they hang
	stars: { Vector3 }, -- in the order he cuts from them
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
	-- A pentagram: the first star on his side of them, each next one two
	-- points on (144 degrees), alternately a little above and below them.
	local stars = {}
	for i = 1, #SaintZephyr.Times.Cuts do
		local angle = math.pi + (i - 1) * math.pi * 4 / 5
		local lift = if i % 2 == 0 then 2.5 else -1.5
		table.insert(
			stars,
			center + (forward * math.cos(angle) + right * math.sin(angle)) * SaintZephyr.Ring + UP * lift
		)
	end
	-- The strike runs from above them, through them, to the floor on his
	-- side of them.
	local reach = 3
	local top = center + UP * SaintZephyr.Above + forward * reach
	local ground = start - forward * (reach * SaintZephyr.Height / SaintZephyr.Above)
	return {
		origin = origin,
		start = start,
		forward = forward,
		right = right,
		floorY = floorY,
		center = center,
		stars = stars,
		top = top,
		ground = ground,
	}
end

-- Out the far side of them from star i.
function SaintZephyr.Exit(plan: Plan, i: number): Vector3
	return plan.center + (plan.center - plan.stars[i])
end

local function facing(from: Vector3, to: Vector3, fallback: Vector3): CFrame
	local look = to - from
	if look.Magnitude < 1e-3 then
		look = fallback
	end
	return CFrame.lookAt(from, from + look)
end

function SaintZephyr.Attacker(plan: Plan, t: number): CFrame
	local times = SaintZephyr.Times
	local cuts = times.Cuts
	if t < cuts[1] - SaintZephyr.Appear then
		return plan.origin
	end
	if t < times.Rise - 0.1 then
		-- From star to star, through them each time.
		local index = 1
		for i, at in cuts do
			if t >= at - SaintZephyr.Appear then
				index = i
			end
		end
		local at = cuts[index]
		local star, exit = plan.stars[index], SaintZephyr.Exit(plan, index)
		local half = SaintZephyr.Through / 2
		if t < at - half then
			return facing(star, plan.center, plan.forward)
		end
		local a = math.clamp((t - (at - half)) / SaintZephyr.Through, 0, 1)
		return facing(star:Lerp(exit, a), exit + (exit - star), plan.forward)
	end
	if t < times.Strike - 0.04 then
		-- High above them, looking down at them, the blade raised.
		return CFrame.new(plan.top)
			* CFrame.lookAt(Vector3.zero, plan.forward).Rotation
			* CFrame.Angles(math.rad(-25), 0, 0)
	end
	if t < times.Strike + 0.1 then
		local a = smooth((t - (times.Strike - 0.04)) / 0.14)
		return CFrame.new(plan.top:Lerp(plan.ground, a)) * CFrame.lookAt(Vector3.zero, plan.forward).Rotation
	end
	-- Landed, turned away from them.
	return CFrame.lookAt(plan.ground, plan.ground - plan.forward)
end

function SaintZephyr.Victim(plan: Plan, t: number): CFrame
	local times = SaintZephyr.Times
	local toward = CFrame.lookAt(Vector3.zero, -plan.forward).Rotation -- facing him
	if t <= times.Lift then
		local a = smooth(t / times.Lift)
		return CFrame.new(plan.start:Lerp(plan.center, a)) * toward * CFrame.Angles(math.rad(-20) * a, 0, 0)
	end
	if t <= times.Burst then
		-- Hung there, knocked about by each cut.
		local offset = Vector3.zero
		for i, at in times.Cuts do
			if t >= at then
				local push = SaintZephyr.Exit(plan, i) - plan.stars[i]
				offset += push.Unit * 0.7 * math.exp(-(t - at) * 14)
			end
		end
		local sway = math.sin(t * 9) * math.rad(8)
		return CFrame.new(plan.center + offset) * toward * CFrame.Angles(math.rad(-20), sway, 0)
	end
	-- Driven into the ground, faster and faster.
	local a = math.clamp((t - times.Burst) / (times.Land - times.Burst), 0, 1)
	local floor = Vector3.new(plan.start.X, plan.floorY + 1.5, plan.start.Z)
	return CFrame.new(plan.center:Lerp(floor, a * a)) * toward * CFrame.Angles(math.rad(-20 - 60 * a), 0, 0)
end

return SaintZephyr
