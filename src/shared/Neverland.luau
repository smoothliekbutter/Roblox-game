--[[
	Neverland
	Yuno's Full-Crown cutscene, start to finish:
	  1. time stops: the star dome flashes over them and the victim is
	     lifted off the ground, frozen;
	  2. the triangle: three stars stand round them, and he warps from star
	     to star, punching them up each time (two laps, six punches), the
	     triangle rising with them;
	  3. the hammer: he's above them at the top and brings both fists down;
	  4. they fall through the middle of it all into the ground, and he
	     glides down after them.

	Shared so the server (which holds them both on the paths) and every
	client (which draws them on it smoothly) agree on where they are.
	t = 0 is the grab.
]]

local Neverland = {}

local UP = Vector3.yAxis

Neverland.Times = {
	Freeze = 0.45, -- time has stopped; they're lifted
	Strikes = { 0.55, 0.85, 1.15, 1.45, 1.75, 2.05 },
	Apex = 2.3, -- he's above them
	Slam = 2.45, -- the hammer lands
	Land = 2.8, -- they hit the ground
	Length = 3.25, -- he's down too
}
Neverland.Warp = 0.08 -- he appears at the next star this long before each punch
Neverland.Rise = 4.2 -- how far each punch knocks them up
Neverland.Lift = 2 -- lifted off the ground as time stops
Neverland.Radius = 4.6 -- the triangle round them
Neverland.Above = 3.5 -- how far above them he is for the hammer

export type Plan = {
	origin: CFrame, -- him at the grab
	start: Vector3, -- them at the grab
	forward: Vector3, -- flat, from him to them
	floorY: number,
}

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

function Neverland.Plan(origin: CFrame, victimPosition: Vector3, floorY: number): Plan
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

-- How high they are above where they started at time t.
function Neverland.Height(t: number): number
	local times = Neverland.Times
	local height = Neverland.Lift * smooth(t / times.Freeze)
	for _, at in times.Strikes do
		height += Neverland.Rise * smooth((t - at) / 0.16)
	end
	return height
end

-- Corner `index` (1 to 3) of the triangle of stars round them, at height
-- `height` above where they started.
function Neverland.Corner(plan: Plan, index: number, height: number): Vector3
	local right = plan.forward:Cross(UP)
	local angle = math.pi + (index - 1) * (math.pi * 2 / 3)
	local direction = plan.forward * math.cos(angle) + right * math.sin(angle)
	return plan.start + UP * height + direction * Neverland.Radius
end

-- Which punch (1 to 6) he's on at time t, if any.
function Neverland.StrikeAt(t: number): number?
	local times = Neverland.Times
	local current = nil
	for i, at in times.Strikes do
		if t >= at - Neverland.Warp then
			current = i
		end
	end
	return if current and t < times.Apex - 0.05 then current else nil
end

local function top(plan: Plan): Vector3
	return plan.start + UP * Neverland.Height(Neverland.Times.Slam)
end

local function landing(plan: Plan): Vector3
	return Vector3.new(plan.start.X, plan.floorY + 3, plan.start.Z)
end

function Neverland.Victim(plan: Plan, t: number): CFrame
	local times = Neverland.Times
	local facing = -plan.forward
	if t <= times.Slam then
		local position = plan.start + UP * Neverland.Height(t)
		-- Tipping back as they're knocked up.
		local tip = math.rad(55) * smooth((t - times.Strikes[1]) / (times.Slam - times.Strikes[1]))
		return CFrame.lookAt(position, position + facing) * CFrame.Angles(tip, 0, 0)
	end
	-- Down, faster and faster, turning over onto their back.
	local a = math.clamp((t - times.Slam) / (times.Land - times.Slam), 0, 1)
	local position = top(plan):Lerp(landing(plan), a * a)
	return CFrame.lookAt(position, position + facing) * CFrame.Angles(math.rad(55) + math.rad(35) * a, 0, 0)
end

function Neverland.Attacker(plan: Plan, t: number): CFrame
	local times = Neverland.Times
	local strike = Neverland.StrikeAt(t)
	if t < times.Strikes[1] - Neverland.Warp then
		return plan.origin
	end
	if strike then
		-- At the star for this punch, punching in; he rises a little with
		-- them after it.
		local at = times.Strikes[strike]
		local height = Neverland.Height(at)
		local follow = Neverland.Rise * 0.6 * smooth((t - at) / 0.2)
		local corner = Neverland.Corner(plan, ((strike - 1) % 3) + 1, height - 0.5) + UP * follow
		local target = plan.start + UP * (height + follow)
		return CFrame.lookAt(corner, Vector3.new(target.X, corner.Y, target.Z))
	end
	local above = top(plan) + UP * Neverland.Above
	if t < times.Slam then
		return CFrame.lookAt(above, above + plan.forward)
	end
	-- Gliding down after them, landing just short of the crater.
	local a = math.clamp((t - times.Slam) / (times.Length - times.Slam), 0, 1)
	local eased = 1 - (1 - a) * (1 - a)
	local down = landing(plan) - plan.forward * 4
	local position = above:Lerp(down, eased)
	return CFrame.lookAt(position, position + plan.forward)
end

return Neverland
