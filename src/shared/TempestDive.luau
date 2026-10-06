local TempestDive = {}

local UP = Vector3.yAxis

TempestDive.Times = {
	Lift = 1.1,
	Flip = 1.55,
	Ticks = { 1.85, 2.1, 2.3 },
	Land = 2.5,
	Length = 3.1,
}
TempestDive.Height = 34
TempestDive.Hold = 2.6
TempestDive.Spins = 3

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

function TempestDive.Impact(plan: Plan): Vector3
	return Vector3.new(plan.start.X, plan.floorY + 2.5, plan.start.Z)
end

local function top(plan: Plan): Vector3
	return plan.start + UP * TempestDive.Height
end

function TempestDive.DiveAt(plan: Plan, a: number): Vector3
	return top(plan):Lerp(TempestDive.Impact(plan), a * a)
end

function TempestDive.Spin(a: number): number
	return a * a * TempestDive.Spins * 2 * math.pi
end

function TempestDive.Victim(plan: Plan, t: number): CFrame
	local times = TempestDive.Times
	local toward = facing(-plan.forward)
	if t <= times.Lift then
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
	return CFrame.new(TempestDive.DiveAt(plan, a))
		* CFrame.Angles(0, -TempestDive.Spin(a), 0)
		* toward
		* CFrame.Angles(math.pi, 0, 0)
end

function TempestDive.Attacker(plan: Plan, t: number): CFrame
	local times = TempestDive.Times
	local ahead = facing(plan.forward)
	local holding = UP * TempestDive.Hold - plan.forward * 0.8
	if t <= times.Lift then
		local position = plan.start + UP * rise(t / times.Lift) + holding
		return CFrame.new(plan.origin.Position:Lerp(position, smooth(t / 0.2))) * ahead
	end
	local above = top(plan) + UP * 3.2
	if t <= times.Flip then
		local a = smooth((t - times.Lift) / (times.Flip - times.Lift))
		local position = (top(plan) + holding):Lerp(above, a) + UP * math.sin(a * math.pi) * 1.5
		return CFrame.new(position) * ahead * CFrame.Angles(math.pi * a, 0, 0)
	end
	if t <= times.Land then
		local a = (t - times.Flip) / (times.Land - times.Flip)
		return CFrame.new(TempestDive.DiveAt(plan, a) + UP * 3.2)
			* CFrame.Angles(0, -TempestDive.Spin(a), 0)
			* ahead
			* CFrame.Angles(math.pi, 0, 0)
	end
	local a = math.clamp((t - times.Land) / (times.Length - times.Land), 0, 1)
	local from = TempestDive.Impact(plan) + UP * 3.2
	local to = Vector3.new(plan.start.X, plan.floorY + 3, plan.start.Z) - plan.forward * 5
	local position = from:Lerp(to, smooth(a)) + UP * math.sin(a * math.pi) * 5
	return CFrame.new(position) * ahead * CFrame.Angles(math.pi * (1 + smooth(a)), 0, 0)
end

return TempestDive
