--[[
	TempestDive
	Yuno's Half-Crown grab, start to finish:
	  1. the drag: he flies straight up, dragging them by the collar below
	     him;
	  2. the turn: at the top he swings over them, both head-down;
	  3. the dive: he drives them straight down head-first, spinning, faster
	     and faster, and a tornado forms behind them on the way down, its
	     funnel standing over the crater when they hit;
	  4. he flips back off the crater onto his feet.

	Shared so the server (which holds them both on the paths) and every
	client (which draws them on it smoothly) agree on where they are.
	t = 0 is the grab.
]]

local TempestDive = {}

local UP = Vector3.yAxis

TempestDive.Times = {
	Lift = 1.1, -- dragged to the top
	Flip = 1.55, -- a beat up there, then he's over them, both head-down
	Ticks = { 1.85, 2.1, 2.3 }, -- the tornado cuts them on the way down
	Land = 2.5, -- into the ground
	Length = 3.1, -- he's back on his feet
}
TempestDive.Height = 34 -- how high he drags them
TempestDive.Hold = 2.6 -- how far above them he flies, dragging them
TempestDive.Spins = 4 -- drill turns on the way down

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

local function facing(direction: Vector3): CFrame
	return CFrame.lookAt(Vector3.zero, direction)
end

local function rise(a: number): number
	return TempestDive.Height * (1 - (1 - math.clamp(a, 0, 1)) ^ 2)
end

-- Where they are, head-down, when their head meets the ground.
function TempestDive.Impact(plan: Plan): Vector3
	return Vector3.new(plan.start.X, plan.floorY + 2.5, plan.start.Z)
end

local function top(plan: Plan): Vector3
	return plan.start + UP * TempestDive.Height
end

-- Where they are at fraction a of the dive: faster and faster.
function TempestDive.DiveAt(plan: Plan, a: number): Vector3
	return top(plan):Lerp(TempestDive.Impact(plan), a * a)
end

function TempestDive.Victim(plan: Plan, t: number): CFrame
	local times = TempestDive.Times
	local toward = facing(-plan.forward) -- facing him
	if t <= times.Lift then
		-- Dragged straight up by the collar, legs swinging.
		local a = t / times.Lift
		return CFrame.new(plan.start + UP * rise(a))
			* toward
			* CFrame.Angles(math.rad(-15) * math.sin(a * math.pi), 0, 0)
	end
	if t <= times.Flip then
		local a = smooth((t - times.Lift) / (times.Flip - times.Lift))
		return CFrame.new(top(plan)) * toward * CFrame.Angles(math.pi * a, 0, 0)
	end
	local a = math.clamp((t - times.Flip) / (times.Land - times.Flip), 0, 1)
	local spin = a * TempestDive.Spins * 2 * math.pi
	return CFrame.new(TempestDive.DiveAt(plan, a)) * CFrame.Angles(0, -spin, 0) * toward * CFrame.Angles(math.pi, 0, 0)
end

function TempestDive.Attacker(plan: Plan, t: number): CFrame
	local times = TempestDive.Times
	local ahead = facing(plan.forward)
	local holding = UP * TempestDive.Hold - plan.forward * 0.8
	if t <= times.Lift then
		-- Flying straight up above them, dragging them.
		local position = plan.start + UP * rise(t / times.Lift) + holding
		return CFrame.new(plan.origin.Position:Lerp(position, smooth(t / 0.2))) * ahead
	end
	local above = top(plan) + UP * 3.2
	if t <= times.Flip then
		-- Swinging over them, turning head-down.
		local a = smooth((t - times.Lift) / (times.Flip - times.Lift))
		local position = (top(plan) + holding):Lerp(above, a) + UP * math.sin(a * math.pi) * 1.5
		return CFrame.new(position) * ahead * CFrame.Angles(math.pi * a, 0, 0)
	end
	if t <= times.Land then
		-- Driving them down, right on top of them.
		local a = (t - times.Flip) / (times.Land - times.Flip)
		local spin = a * TempestDive.Spins * 2 * math.pi
		return CFrame.new(TempestDive.DiveAt(plan, a) + UP * 3.2)
			* CFrame.Angles(0, -spin, 0)
			* ahead
			* CFrame.Angles(math.pi, 0, 0)
	end
	-- Off the crater in a backflip, landing on his feet just short of it.
	local a = math.clamp((t - times.Land) / (times.Length - times.Land), 0, 1)
	local from = TempestDive.Impact(plan) + UP * 3.2
	local to = Vector3.new(plan.start.X, plan.floorY + 3, plan.start.Z) - plan.forward * 5
	local position = from:Lerp(to, smooth(a)) + UP * math.sin(a * math.pi) * 5
	return CFrame.new(position) * ahead * CFrame.Angles(math.pi * (1 + smooth(a)), 0, 0)
end

return TempestDive
