--[[
	BlackAscent
	Black Ascent (Black Form, Demon-Slasher Katana 1): a rising cut launches
	them; he springs up after them, cuts them twice in the air, from one
	side then the other, and cuts them back down into the ground.

	Shared so the server (which holds them both on the paths) and every
	client (which draws them on it smoothly) agree on where they are.
	t = 0 is the launching cut landing.
]]

local BlackAscent = {}

local UP = Vector3.yAxis

BlackAscent.Times = {
	Rise = 0.3, -- they're carried up
	Cuts = { 0.38, 0.56 }, -- the two cuts in the air
	Spike = 0.78, -- the cut back down
	Land = 0.95, -- they hit the ground
	Length = 1.1, -- he's landed
}
BlackAscent.Height = 11

export type Plan = {
	origin: CFrame,
	start: Vector3,
	forward: Vector3,
	right: Vector3,
	floorY: number,
	top: Vector3,
}

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

function BlackAscent.Plan(origin: CFrame, victimPosition: Vector3, floorY: number): Plan
	local toward = victimPosition - origin.Position
	local flat = Vector3.new(toward.X, 0, toward.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(origin.LookVector.X, 0, origin.LookVector.Z)
	end
	local forward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local start = Vector3.new(victimPosition.X, floorY + 3, victimPosition.Z)
	return {
		origin = origin,
		start = start,
		forward = forward,
		right = forward:Cross(UP),
		floorY = floorY,
		top = start + UP * BlackAscent.Height,
	}
end

function BlackAscent.Victim(plan: Plan, t: number): CFrame
	local times = BlackAscent.Times
	local toward = CFrame.lookAt(Vector3.zero, -plan.forward).Rotation
	if t <= times.Rise then
		local a = 1 - (1 - t / times.Rise) ^ 2
		return CFrame.new(plan.start:Lerp(plan.top, a)) * toward * CFrame.Angles(math.rad(-50) * a, 0, 0)
	end
	if t <= times.Spike then
		-- Knocked one way, then the other, by the cuts.
		local offset = Vector3.zero
		for i, at in times.Cuts do
			if t >= at then
				local side = if i % 2 == 1 then -1 else 1
				offset += plan.right * side * 0.8 * math.exp(-(t - at) * 12)
			end
		end
		return CFrame.new(plan.top + offset) * toward * CFrame.Angles(math.rad(-50), 0, 0)
	end
	local a = math.clamp((t - times.Spike) / (times.Land - times.Spike), 0, 1)
	local floor = Vector3.new(plan.start.X, plan.floorY + 1.5, plan.start.Z)
	return CFrame.new(plan.top:Lerp(floor, a * a)) * toward * CFrame.Angles(math.rad(-50 - 40 * a), 0, 0)
end

function BlackAscent.Attacker(plan: Plan, t: number): CFrame
	local times = BlackAscent.Times
	local look = CFrame.lookAt(Vector3.zero, plan.forward).Rotation
	local front = plan.top - plan.forward * 3 -- in front of them, up there
	if t < 0.08 then
		return plan.origin
	end
	if t < times.Cuts[1] - 0.05 then
		-- Springing up after them.
		local a = smooth((t - 0.08) / (times.Cuts[1] - 0.13))
		local from = plan.origin.Position
		return CFrame.new(from:Lerp(front, a) + UP * math.sin(a * math.pi) * 1.5) * look
	end
	if t < times.Cuts[2] - 0.05 then
		-- From his right side...
		local at = front + plan.right * 2.5
		return CFrame.lookAt(at, plan.top)
	end
	if t < times.Spike - 0.08 then
		-- ...then his left.
		local at = front - plan.right * 2.5
		return CFrame.lookAt(at, plan.top)
	end
	local above = plan.top + UP * 3.5 - plan.forward * 1.5
	local landed = Vector3.new(plan.start.X, plan.floorY + 3, plan.start.Z) - plan.forward * 3
	if t < times.Spike then
		return CFrame.new(above) * look * CFrame.Angles(math.rad(-30), 0, 0)
	end
	-- Down with them, landing just short of where they hit.
	local a = math.clamp((t - times.Spike) / (times.Land - times.Spike), 0, 1)
	return CFrame.new(above:Lerp(landed, a * a)) * look
end

return BlackAscent
