--[[
	BlackComet
	Black Comet (Black Form, Demon-Destroyer Sword 2), a short grab
	cutscene: with them by the throat, his wings throw him forward low over
	the ground and he hammers them into it again and again as they streak
	along, then he plants and heaves them away.

	Shared so the server (which holds him on the path; they hang from his
	hand) and every client (which draws it smoothly) agree on where he is.
	t = 0 is the take-off, right after the seize.
]]

local BlackComet = {}

local UP = Vector3.yAxis

BlackComet.Times = {
	Slams = { 0.22, 0.47, 0.72 }, -- into the ground as his arm comes down
	Drag = 0.9, -- along the ground
	Throw = 0.14, -- the heave lets go of them
	Length = 1.25,
}
BlackComet.Distance = 30 -- the most he covers (walls cut it short)
BlackComet.Low = 1.2 -- how far above standing height he flies

export type Plan = { origin: Vector3, forward: Vector3, distance: number, floorY: number }

function BlackComet.Plan(origin: Vector3, forward: Vector3, distance: number, floorY: number): Plan
	return { origin = origin, forward = forward, distance = distance, floorY = floorY }
end

function BlackComet.At(plan: Plan, t: number): CFrame
	local times = BlackComet.Times
	local base = Vector3.new(plan.origin.X, plan.floorY + 3, plan.origin.Z)
	local a = math.clamp(t / times.Drag, 0, 1)
	-- Off fast, slowing to a stop; up off the ground at once, back down
	-- for the heave.
	local along = plan.distance * (1 - (1 - a) ^ 2)
	local lift = BlackComet.Low * math.min(a / 0.15, 1) * (1 - math.clamp((a - 0.85) / 0.15, 0, 1))
	local position = base + plan.forward * along + UP * lift
	return CFrame.lookAt(position, position + plan.forward)
end

return BlackComet
