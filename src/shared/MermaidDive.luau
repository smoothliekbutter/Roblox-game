local MermaidDive = {}

local UP = Vector3.yAxis

MermaidDive.Sink = 0.24
MermaidDive.Rise = 0.22
MermaidDive.Depth = 1.4
MermaidDive.Height = 7
MermaidDive.SwimSpeed = 62

export type Plan = {
	start: CFrame,
	from: Vector3,
	to: Vector3,
	forward: Vector3,
	swim: number,
	length: number,
}

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

function MermaidDive.Plan(start: CFrame, target: Vector3, floorFrom: number, floorTo: number): Plan
	local offset = target - start.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local look = Vector3.new(start.LookVector.X, 0, start.LookVector.Z)
	local forward = if flat.Magnitude > 1e-3
		then flat.Unit
		elseif look.Magnitude > 1e-3 then look.Unit
		else Vector3.new(0, 0, -1)
	local swim = math.clamp(flat.Magnitude / MermaidDive.SwimSpeed, 0.2, 0.55)
	return {
		start = start,
		from = Vector3.new(start.X, floorFrom, start.Z),
		to = Vector3.new(target.X, floorTo, target.Z),
		forward = forward,
		swim = swim,
		length = MermaidDive.Sink + swim + MermaidDive.Rise,
	}
end

function MermaidDive.Erupt(plan: Plan): number
	return MermaidDive.Sink + plan.swim
end

local function facing(position: Vector3, forward: Vector3, pitch: number): CFrame
	return CFrame.lookAt(position, position + forward) * CFrame.Angles(pitch, 0, 0)
end

function MermaidDive.Entry(plan: Plan): Vector3
	return plan.from + plan.forward * 3
end

function MermaidDive.At(plan: Plan, t: number): CFrame
	local under = -UP * MermaidDive.Depth
	local entry = MermaidDive.Entry(plan) + under
	local exit = plan.to - plan.forward * 0.5 + under
	if t < MermaidDive.Sink then
		local a = t / MermaidDive.Sink
		local position = plan.start.Position:Lerp(entry, a * a) + UP * 2.2 * math.sin(math.pi * a)
		return facing(position, plan.forward, -math.rad(70) * smooth(a))
	end
	local swum = t - MermaidDive.Sink
	if swum < plan.swim then
		local a = swum / plan.swim
		return facing(entry:Lerp(exit, smooth(a)), plan.forward, -math.rad(70) + math.rad(55) * smooth(a * 3))
	end
	local a = math.clamp((swum - plan.swim) / MermaidDive.Rise, 0, 1)
	local top = plan.to + UP * (3 + MermaidDive.Height)
	return facing(exit:Lerp(top, 1 - (1 - a) ^ 2), plan.forward, math.rad(35) * (1 - smooth(a)))
end

return MermaidDive
