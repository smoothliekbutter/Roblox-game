--[[
	Impulse
	Pushes a character for a short time using a LinearVelocity. A plain
	AssemblyLinearVelocity gets eaten by the Humanoid's controller, this
	doesn't. Must run on whoever owns the physics: the client for its own
	character, the server for NPCs and ragdolled characters.
]]

local Impulse = {}

-- Applies `velocity` for `duration` seconds. Only one impulse per `name`
-- exists at a time, so a new dash replaces an old dash. Vertical force is
-- only applied when velocity has a Y component, so gravity still works on
-- flat pushes. Returns the LinearVelocity so callers can steer it.
function Impulse.Apply(root: BasePart, velocity: Vector3, duration: number, name: string?): LinearVelocity
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
