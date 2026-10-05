-- Server-simulated projectiles: moved every frame, swept hitboxes, stopped by walls.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Hitbox = require(script.Parent.Hitbox)

export type Options = {
	owner: Model,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	range: number,
	size: Vector3, -- hitbox: X width, Y height, Z extra length
	pierce: boolean?, -- keep going through people
	onHit: (victim: Model, position: Vector3) -> (),
	onEnd: ((position: Vector3) -> ())?,
}

local Projectile = {}

local function wallParams(owner: Model): RaycastParams
	local ignore: { Instance } = { owner }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(ignore, dummies)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

function Projectile.Fire(options: Options)
	local direction = options.direction.Unit
	local position = options.origin
	local travelled = 0
	local alreadyHit: { [Model]: boolean } = {}
	local params = wallParams(options.owner)

	local connection
	local function finish()
		connection:Disconnect()
		if options.onEnd then
			task.spawn(options.onEnd, position)
		end
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		local step = math.min(options.speed * dt, options.range - travelled)
		local wall = workspace:Raycast(position, direction * step, params)
		local nextPosition = if wall then wall.Position else position + direction * step

		-- Sweep the hitbox over everything covered this frame.
		local center = (position + nextPosition) / 2
		local length = (nextPosition - position).Magnitude + options.size.Z
		local box = CFrame.lookAt(center, center + direction)
		for _, victim in Hitbox.Box(options.owner, box, Vector3.new(options.size.X, options.size.Y, length)) do
			if not alreadyHit[victim] then
				alreadyHit[victim] = true
				task.spawn(options.onHit, victim, center)
				if not options.pierce then
					position = center
					finish()
					return
				end
			end
		end

		travelled += step
		position = nextPosition
		if wall or travelled >= options.range then
			finish()
		end
	end)
end

return Projectile
