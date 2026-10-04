--[[
	MeteorVortex
	Black Meteorite after the grab, start to finish:
	  1. the vortex: holding them out by the throat, Asta whirls round,
	     bobbing up and down as it carries him into the sky, and finishes
	     facing the way he started;
	  2. the flip: he tips forward over the top until he's head-down;
	  3. the dive: head-first, spinning like a drill (a whole number of
	     turns, faster as he falls) down into the ground with them;
	  4. the recovery: the somersault finishes and he lands on his feet.

	Shared so the server (which holds him on the path) and every client
	(which draws him on it smoothly) agree on where he is. t = 0 is the
	start of the spin; `origin` is his root then, level.
]]

local MeteorVortex = {}

MeteorVortex.Length = 1.2 -- seconds of spinning up
MeteorVortex.Turns = 3 -- whole turns, so he ends facing forward
MeteorVortex.Top = 20 -- studs he ends up above where he started (on the ground)
MeteorVortex.AirTop = 8 -- the same, when it starts in the air
MeteorVortex.Bob = 4 -- how far each bob dips and rises
MeteorVortex.Radius = 1.5 -- the little circle his body traces

MeteorVortex.Flip = 0.14 -- tipping over head-down at the top
MeteorVortex.DiveSpeed = 45 -- studs/s, on average, on the way down
MeteorVortex.SpinRate = 9 -- turns per second while diving
MeteorVortex.Recover = 0.26 -- rolling back over onto his feet
MeteorVortex.ImpactHeight = 3.2 -- his root above the ground when he hits (head-first)
MeteorVortex.NoFloorDrop = 16 -- how far he dives when there's no ground in reach

local UP = Vector3.yAxis

export type Plan = {
	origin: CFrame,
	top: number,
	floorY: number?, -- the ground under him (nil: none in reach)
	topPosition: Vector3, -- where the spin ends
	diveEnd: Vector3, -- where he hits
	drop: number,
	spins: number, -- whole turns in the dive
	flipAt: number,
	diveAt: number,
	impactAt: number,
	length: number,
}

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

-- Everything about one Meteorite, worked out from where he grabbed them.
function MeteorVortex.Plan(origin: CFrame, top: number, floorY: number?): Plan
	local topPosition = origin.Position + UP * top
	local forward = origin.LookVector
	local endY = if floorY then floorY + MeteorVortex.ImpactHeight else topPosition.Y - MeteorVortex.NoFloorDrop
	endY = math.min(endY, topPosition.Y - 2)
	local drop = topPosition.Y - endY
	local dive = math.clamp(drop / MeteorVortex.DiveSpeed, 0.35, 0.9)
	local flipAt = MeteorVortex.Length
	local diveAt = flipAt + MeteorVortex.Flip
	local impactAt = diveAt + dive
	return {
		origin = origin,
		top = top,
		floorY = floorY,
		topPosition = topPosition,
		diveEnd = Vector3.new(topPosition.X, endY, topPosition.Z) + forward * 1.8,
		drop = drop,
		spins = math.max(2, math.floor(MeteorVortex.SpinRate * dive + 0.5)),
		flipAt = flipAt,
		diveAt = diveAt,
		impactAt = impactAt,
		length = impactAt + MeteorVortex.Recover,
	}
end

-- How far round he has turned (radians) at fraction a of the spin-up: slow
-- to start, fastest in the middle, easing out facing forward again.
function MeteorVortex.Angle(a: number): number
	return MeteorVortex.Turns * 2 * math.pi * smooth(math.clamp(a, 0, 1))
end

-- The spin-up alone: his root at time t (0 to Length).
function MeteorVortex.Spin(origin: CFrame, t: number, top: number?): CFrame
	local a = math.clamp(t / MeteorVortex.Length, 0, 1)
	local angle = MeteorVortex.Angle(a)
	-- Rising overall, bobbing down and up twice on the way (the bobs ease in
	-- and out, so it starts and ends without a jolt).
	local height = (top or MeteorVortex.Top) * smooth(a)
		+ MeteorVortex.Bob * math.sin(a * math.pi * 4) * math.sin(a * math.pi)
	local circle = (origin.RightVector * math.sin(angle) + origin.LookVector * (math.cos(angle) - 1))
		* MeteorVortex.Radius
	local position = origin.Position + UP * height + circle
	-- He banks into the turn and leans back against their weight, most at
	-- full speed.
	local pull = 4 * a * (1 - a)
	return CFrame.new(position)
		* origin.Rotation
		* CFrame.Angles(0, -angle, 0)
		* CFrame.Angles(math.rad(10) * pull, 0, -math.rad(12) * pull)
end

-- His root at time t, over the whole move. Each stage starts exactly where
-- the last one left him, so nothing snaps.
function MeteorVortex.At(plan: Plan, t: number): CFrame
	if t <= plan.flipAt then
		return MeteorVortex.Spin(plan.origin, t, plan.top)
	end
	local forward = plan.origin.LookVector
	if t <= plan.diveAt then
		-- Tipping forward over the top until he's head-down.
		local a = (t - plan.flipAt) / (plan.diveAt - plan.flipAt)
		local e = smooth(a)
		local position = plan.topPosition + UP * math.sin(a * math.pi) * 1.2 + forward * 0.6 * e
		return CFrame.new(position) * plan.origin.Rotation * CFrame.Angles(-math.pi * e, 0, 0)
	end
	if t <= plan.impactAt then
		-- Head-first, spinning like a drill, faster as he falls.
		local a = (t - plan.diveAt) / (plan.impactAt - plan.diveAt)
		local from = plan.topPosition + forward * 0.6
		local position = from:Lerp(plan.diveEnd, a) - UP * plan.drop * (a ^ 1.7 - a)
		local spin = plan.spins * 2 * math.pi * a
		return CFrame.new(position) * CFrame.Angles(0, -spin, 0) * plan.origin.Rotation * CFrame.Angles(-math.pi, 0, 0)
	end
	-- The somersault finishes and he lands on his feet.
	local a = math.clamp((t - plan.impactAt) / (plan.length - plan.impactAt), 0, 1)
	local e = smooth(a)
	local landY = if plan.floorY then plan.floorY + 3 else plan.diveEnd.Y
	local position = Vector3.new(plan.diveEnd.X, plan.diveEnd.Y + (landY - plan.diveEnd.Y) * e, plan.diveEnd.Z)
		+ UP * math.sin(a * math.pi) * 1.5
		+ forward * 1.5 * e
	return CFrame.new(position) * plan.origin.Rotation * CFrame.Angles(-math.pi * (1 + e), 0, 0)
end

return MeteorVortex
