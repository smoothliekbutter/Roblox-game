local BlackAscent = {}

local UP = Vector3.yAxis

BlackAscent.Times = {
	Rise = 0.32,
	Cuts = { 0.4, 0.58 },
	Spike = 0.8,
	Land = 0.95,
	Length = 1.3,
}
BlackAscent.Height = 11

export type Key = { t: number, p: Vector3, yaw: number, pitch: number }
export type Plan = {
	origin: CFrame,
	start: Vector3,
	forward: Vector3,
	right: Vector3,
	floorY: number,
	top: Vector3,
	keys: { Key },
}

local function flat(v: Vector3, fallback: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else fallback
end

local function knock(t: number, at: number, time: number): number
	if t <= at then
		return 0
	end
	local u = (t - at) / time
	return u * math.exp(1 - u)
end

function BlackAscent.Plan(origin: CFrame, victimPosition: Vector3, floorY: number): Plan
	local toward = victimPosition - origin.Position
	local forward = flat(toward, flat(origin.LookVector, Vector3.new(0, 0, -1)))
	local right = forward:Cross(UP)
	local start = Vector3.new(victimPosition.X, floorY + 3, victimPosition.Z)
	local top = start + UP * BlackAscent.Height
	local times = BlackAscent.Times
	local cut1, cut2 = times.Cuts[1], times.Cuts[2]
	local landed = Vector3.new(start.X, floorY + 3, start.Z) - forward * 3
	local from = origin.Position
	local keys: { Key } = {
		{ t = 0, p = from, yaw = 0, pitch = 0 },
		{ t = 0.1, p = from + forward * 0.5 + UP * 1.2, yaw = -6, pitch = -8 },
		{ t = cut1 - 0.07, p = top - forward * 2.8 + right * 3.4 - UP * 0.3, yaw = -40, pitch = -6 },
		{ t = cut1, p = top - forward * 3.1 + UP * 0.1, yaw = -6, pitch = -10 },
		{ t = cut1 + 0.08, p = top - forward * 2.6 - right * 3.3 - UP * 0.7, yaw = 36, pitch = -4 },
		{ t = cut2, p = top - forward * 2.7 - right * 0.9 + UP * 1.1, yaw = 22, pitch = -8 },
		{ t = cut2 + 0.08, p = top - forward * 2.1 + right * 1.6 + UP * 3.2, yaw = -12, pitch = -14 },
		{ t = times.Spike - 0.05, p = top - forward * 1.1 + UP * 4.3, yaw = 0, pitch = -38 },
		{ t = times.Spike, p = top - forward * 1.4 + UP * 2.9, yaw = 0, pitch = -62 },
		{ t = times.Land + 0.07, p = landed + UP * 0.4, yaw = 0, pitch = -12 },
		{ t = times.Land + 0.15, p = landed, yaw = 0, pitch = 0 },
		{ t = times.Length, p = landed, yaw = 0, pitch = 0 },
	}
	return {
		origin = origin,
		start = start,
		forward = forward,
		right = right,
		floorY = floorY,
		top = top,
		keys = keys,
	}
end

local function slope(keys: { Key }, i: number, get: (Key) -> any): any
	if i == 1 or i == #keys then
		return get(keys[i]) * 0
	end
	local a, b = keys[i - 1], keys[i + 1]
	return (get(b) - get(a)) / (b.t - a.t)
end

local function through(keys: { Key }, t: number, get: (Key) -> any): any
	if t <= keys[1].t then
		return get(keys[1])
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then
			local span = b.t - a.t
			local s = (t - a.t) / span
			local s2, s3 = s * s, s * s * s
			return get(a) * (2 * s3 - 3 * s2 + 1)
				+ slope(keys, i, get) * (span * (s3 - 2 * s2 + s))
				+ get(b) * (-2 * s3 + 3 * s2)
				+ slope(keys, i + 1, get) * (span * (s3 - s2))
		end
	end
	return get(keys[#keys])
end

local function position(key: Key): Vector3
	return key.p
end
local function yaw(key: Key): number
	return key.yaw
end
local function pitch(key: Key): number
	return key.pitch
end

function BlackAscent.Attacker(plan: Plan, t: number): CFrame
	local p: Vector3 = through(plan.keys, t, position)
	if t > BlackAscent.Times.Land then
		p = Vector3.new(p.X, math.max(p.Y, plan.floorY + 3), p.Z)
	end
	local turn = math.rad(through(plan.keys, t, yaw) :: number)
	local lean = math.rad(through(plan.keys, t, pitch) :: number)
	local facing = plan.forward * math.cos(turn) + plan.right * math.sin(turn)
	return CFrame.lookAt(p, p + facing) * CFrame.Angles(lean, 0, 0)
end

function BlackAscent.Victim(plan: Plan, t: number): CFrame
	local times = BlackAscent.Times
	local cut1, cut2 = times.Cuts[1], times.Cuts[2]
	local toward = CFrame.lookAt(Vector3.zero, -plan.forward).Rotation
	local rise = 1 - (1 - math.clamp(t / times.Rise, 0, 1)) ^ 2.5
	local p = plan.start:Lerp(plan.top, rise) + UP * 0.7 * math.max(t - times.Rise, 0)
	local first = knock(t, cut1, 0.09)
	local second = knock(t, cut2, 0.1)
	p += -plan.right * 1.1 * first + UP * 0.3 * first + plan.right * 0.9 * second + UP * 0.9 * second
	local tumble = -50 * rise
		- 18 * math.min(math.max(t - cut1, 0) / 0.1, 1)
		- 22 * math.min(math.max(t - cut2, 0) / 0.12, 1)
	local roll = 14 * first - 18 * second
	if t <= times.Spike then
		return CFrame.new(p) * toward * CFrame.Angles(math.rad(tumble), 0, math.rad(roll))
	end
	local held = BlackAscent.Victim(plan, times.Spike)
	local a = math.clamp((t - times.Spike) / (times.Land - times.Spike), 0, 1)
	local floor = Vector3.new(plan.start.X, plan.floorY + 1.2, plan.start.Z)
	local down = held.Position:Lerp(floor, 0.45 * a + 0.55 * a * a)
	local face = CFrame.new(down) * toward * CFrame.Angles(math.rad(-95), 0, 0)
	return held.Rotation:Lerp(face.Rotation, math.min(a * 1.4, 1)) + down
end

return BlackAscent
