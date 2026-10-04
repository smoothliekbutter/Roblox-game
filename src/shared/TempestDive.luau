--[[
	TempestDive
	Yuno's Half-Crown grab, start to finish:
	  1. the tornado: whoever he caught is torn up into the sky on a spiral
	     of wind, tumbling over until they're head-down, and he rides it up
	     across the spiral from them;
	  2. the turn: at the top he swings over them, head-down too;
	  3. the dive: he drives them straight down head-first, spinning like a
	     drill, faster and faster, through three rings of wind and into the
	     ground;
	  4. he flips back off the crater onto his feet.

	Shared so the server (which holds them both on the paths) and every
	client (which draws them on it smoothly) agree on where they are.
	t = 0 is the grab.
]]

local TempestDive = {}

local UP = Vector3.yAxis

TempestDive.Times = {
	Ticks = { 0.35, 0.7 }, -- the tornado cuts them on the way up
	Lift = 0.95, -- at the top
	Flip = 1.15, -- he's over them, both head-down
	Land = 1.5, -- into the ground
	Length = 1.95, -- he's back on his feet
}
TempestDive.Height = 26 -- how high the tornado takes them
TempestDive.Turns = 2 -- times round the spiral on the way up
TempestDive.Radius = 2.4 -- the spiral
TempestDive.Spins = 3 -- drill turns on the way down
TempestDive.Rings = { 0.3, 0.55, 0.78 } -- fractions of the dive where they go through the rings

export type Plan = {
	origin: CFrame,
	start: Vector3,
	forward: Vector3,
	floorY: number,
}

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

function TempestDive.Plan(origin: CFrame, victimPosition: Vector3, floorY: number): Plan
	local toward = victimPosition - origin.Position
	local forward = Vector3.new(toward.X, 0, toward.Z)
	if forward.Magnitude < 1e-3 then
		forward = Vector3.new(origin.LookVector.X, 0, origin.LookVector.Z)
	end
	return {
		origin = origin,
		start = victimPosition,
		forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1),
		floorY = floorY,
	}
end

local function liftAngle(a: number): number
	return TempestDive.Turns * 2 * math.pi * smooth(a)
end

local function liftHeight(a: number): number
	return TempestDive.Height * (1 - (1 - math.clamp(a, 0, 1)) ^ 2)
end

local function around(plan: Plan, angle: number): Vector3
	return plan.forward * math.cos(angle) + plan.forward:Cross(UP) * math.sin(angle)
end

local function facing(plan: Plan): CFrame
	return CFrame.lookAt(Vector3.zero, plan.forward)
end

-- Where they are, head-down, when their head meets the ground.
function TempestDive.Impact(plan: Plan): Vector3
	return Vector3.new(plan.start.X, plan.floorY + 2.5, plan.start.Z)
end

local function top(plan: Plan): Vector3
	return plan.start + UP * TempestDive.Height
end

-- Their height on the way down at fraction a of the dive.
function TempestDive.DiveAt(plan: Plan, a: number): Vector3
	return top(plan):Lerp(TempestDive.Impact(plan), a * a)
end

function TempestDive.Victim(plan: Plan, t: number): CFrame
	local times = TempestDive.Times
	local base = facing(plan)
	if t <= times.Lift then
		local a = t / times.Lift
		local angle = liftAngle(a)
		local position = plan.start + around(plan, angle) * TempestDive.Radius * (1 - 0.4 * a) + UP * liftHeight(a)
		-- Tumbling over as the wind takes them, head-down by the top.
		return CFrame.new(position) * base * CFrame.Angles(0, -angle, 0) * CFrame.Angles(math.pi * smooth(a), 0, 0)
	end
	if t <= times.Flip then
		local a = smooth((t - times.Lift) / (times.Flip - times.Lift))
		local liftEnd = plan.start + around(plan, liftAngle(1)) * TempestDive.Radius * 0.6 + UP * TempestDive.Height
		return CFrame.new(liftEnd:Lerp(top(plan), a)) * base * CFrame.Angles(math.pi, 0, 0)
	end
	local a = math.clamp((t - times.Flip) / (times.Land - times.Flip), 0, 1)
	local spin = a * TempestDive.Spins * 2 * math.pi
	return CFrame.new(TempestDive.DiveAt(plan, a)) * CFrame.Angles(0, -spin, 0) * base * CFrame.Angles(math.pi, 0, 0)
end

function TempestDive.Attacker(plan: Plan, t: number): CFrame
	local times = TempestDive.Times
	local base = facing(plan)
	if t <= times.Lift then
		-- Riding the tornado up across the spiral from them, facing them.
		local a = t / times.Lift
		local angle = liftAngle(a)
		local side = around(plan, angle)
		local victim = plan.start + side * TempestDive.Radius * (1 - 0.4 * a) + UP * liftHeight(a)
		local position = plan.start - side * TempestDive.Radius * 1.4 + UP * (liftHeight(a) + 0.6)
		position = plan.origin.Position:Lerp(position, smooth(t / 0.25))
		return CFrame.lookAt(position, Vector3.new(victim.X, position.Y, victim.Z))
	end
	local above = top(plan) + UP * 3.2
	if t <= times.Flip then
		-- Swinging over the top of them, turning head-down.
		local a = smooth((t - times.Lift) / (times.Flip - times.Lift))
		local from = plan.start
			- around(plan, liftAngle(1)) * TempestDive.Radius * 1.4
			+ UP * (TempestDive.Height + 0.6)
		local position = from:Lerp(above, a) + UP * math.sin(a * math.pi) * 2
		return CFrame.new(position) * base * CFrame.Angles(math.pi * a, 0, 0)
	end
	if t <= times.Land then
		-- Driving them down, right on top of them.
		local a = (t - times.Flip) / (times.Land - times.Flip)
		local spin = a * TempestDive.Spins * 2 * math.pi
		return CFrame.new(TempestDive.DiveAt(plan, a) + UP * 3.2)
			* CFrame.Angles(0, -spin, 0)
			* base
			* CFrame.Angles(math.pi, 0, 0)
	end
	-- Off the crater in a backflip, landing on his feet just short of it.
	local a = math.clamp((t - times.Land) / (times.Length - times.Land), 0, 1)
	local from = TempestDive.Impact(plan) + UP * 3.2
	local to = Vector3.new(plan.start.X, plan.floorY + 3, plan.start.Z) - plan.forward * 5
	local position = from:Lerp(to, smooth(a)) + UP * math.sin(a * math.pi) * 5
	return CFrame.new(position) * base * CFrame.Angles(math.pi * (1 + smooth(a)), 0, 0)
end

return TempestDive
