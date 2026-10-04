--[[
	Impulse
	Pushes a character for a short time using a LinearVelocity. A plain
	AssemblyLinearVelocity gets eaten by the Humanoid's controller, this
	doesn't. Must run on whoever owns the physics: the client for its own
	character, the server for NPCs and ragdolled characters.
]]

local RunService = game:GetService("RunService")

local Impulse = {}

-- Applies `velocity` for `duration` seconds. Only one impulse per `name`
-- exists at a time, so a new dash replaces an old dash. Vertical force is
-- only applied when velocity has a Y component, so gravity still works on
-- flat pushes. `taper` (a fraction of the duration) eases the push out to
-- a stop over its last part instead of cutting it dead, which is what makes
-- knockback feel snappy rather than jerky. Returns the LinearVelocity so
-- callers can steer it (steered pushes shouldn't taper).
function Impulse.Apply(
	root: BasePart,
	velocity: Vector3,
	duration: number,
	name: string?,
	taper: number?
): LinearVelocity
	local id = "Impulse_" .. (name or "Default")
	local existing = root:FindFirstChild(id)
	if existing then
		existing:Destroy()
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = id
	attachment.Parent = root

	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local vertical = if math.abs(velocity.Y) > 0.01 then 1e6 else 0
	mover.MaxAxesForce = Vector3.new(1e6, vertical, 1e6)
	mover.VectorVelocity = velocity
	mover.Parent = attachment

	if taper and taper > 0 and duration > 0 then
		local start = os.clock()
		local easeFrom = duration * (1 - math.min(taper, 1))
		local from: Vector3? = nil
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if not mover.Parent then
				connection:Disconnect()
				return
			end
			local t = os.clock() - start
			if t < easeFrom then
				return
			end
			from = from or mover.VectorVelocity
			local a = math.clamp((t - easeFrom) / (duration - easeFrom), 0, 1)
			mover.VectorVelocity = (from :: Vector3) * (1 - a * a * (3 - 2 * a))
		end)
	end

	task.delay(duration, function()
		attachment:Destroy()
	end)

	return mover
end

function Impulse.Clear(root: BasePart)
	for _, child in root:GetChildren() do
		if child:IsA("Attachment") and string.sub(child.Name, 1, 8) == "Impulse_" then
			child:Destroy()
		end
	end
end

return Impulse
