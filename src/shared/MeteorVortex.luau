--[[
	MeteorVortex
	Black Meteorite's spin: holding them out by the throat, Asta whirls
	round in an anti-magic vortex, bobbing up and down as it carries him
	into the sky, and finishes facing the way he started, sword raised for
	the slam.

	Shared so the server (which holds him on the path) and every client
	(which draws him on it smoothly) agree on where he is. t = 0 is the
	start of the spin; `origin` is his root then, level.
]]

local MeteorVortex = {}

MeteorVortex.Length = 1.2 -- seconds of spinning
MeteorVortex.Turns = 3 -- whole turns, so he ends facing forward
MeteorVortex.Top = 20 -- studs he ends up above where he started (on the ground)
MeteorVortex.AirTop = 8 -- the same, when it starts in the air
MeteorVortex.Bob = 4 -- how far each bob dips and rises
MeteorVortex.Radius = 1.5 -- the little circle his body traces

local UP = Vector3.yAxis

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

-- How far round he has turned (radians) at fraction a: slow to start,
-- fastest in the middle, easing out facing forward again.
function MeteorVortex.Angle(a: number): number
	return MeteorVortex.Turns * 2 * math.pi * smooth(math.clamp(a, 0, 1))
end

-- His root at time t. `top` is how high the spin carries him.
function MeteorVortex.At(origin: CFrame, t: number, top: number?): CFrame
	local a = math.clamp(t / MeteorVortex.Length, 0, 1)
	local angle = MeteorVortex.Angle(a)
	-- Rising overall, bobbing down and up twice on the way.
	local height = (top or MeteorVortex.Top) * smooth(a) + MeteorVortex.Bob * math.sin(a * math.pi * 4)
	local circle = (origin.RightVector * math.sin(angle) + origin.LookVector * (math.cos(angle) - 1))
		* MeteorVortex.Radius
	local position = origin.Position + UP * height + circle
	return CFrame.new(position) * origin.Rotation * CFrame.Angles(0, -angle, 0)
end

return MeteorVortex
