--[[
	Ragdoll
	Swaps a character's Motor6Ds for BallSocketConstraints so it flops. The
	server takes network ownership while ragdolled so knockback is smooth and
	can't be ignored by the client. Works with R6 and R15.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP = "Ragdoll"
if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
	PhysicsService:RegisterCollisionGroup(GROUP)
end
-- Body parts of a ragdoll don't collide with each other (stops jitter at the joints).
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)

-- The root joint stays a motor so the HumanoidRootPart follows the torso.
local KEEP_JOINTS = {
	RootJoint = true,
	Root = true,
}

type Record = {
	created: { Instance },
	motors: { Motor6D },
	groups: { [BasePart]: string },
}

local active: { [Model]: Record } = {}

local Ragdoll = {}

-- The Humanoid's own "get up" can fail on a body lying flat, so snap it
-- upright, standing on the ground, facing the way the body was lying.
local function standUp(character: Model, humanoid: Humanoid, root: BasePart)
	local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if facing.Magnitude < 0.2 then
		-- Lying on its back/front: the head direction is the best guess.
		facing = root.CFrame.UpVector * Vector3.new(1, 0, 1)
	end
	if facing.Magnitude < 0.01 then
		facing = Vector3.new(0, 0, -1)
	end

	local position = root.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local ground = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), params)
	if ground then
		local legLength = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
		position = Vector3.new(position.X, ground.Position.Y + legLength + root.Size.Y / 2, position.Z)
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(position, position + facing.Unit)
end

function Ragdoll.IsActive(character: Model): boolean
	return active[character] ~= nil
end

function Ragdoll.Enable(character: Model)
	if active[character] then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end

	local record: Record = { created = {}, motors = {}, groups = {} }
	active[character] = record

	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and not KEEP_JOINTS[joint.Name] and joint.Part0 and joint.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollAttachment"
			a0.CFrame = joint.C0
			a0.Parent = joint.Part0

			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollAttachment"
			a1.CFrame = joint.C1
			a1.Parent = joint.Part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "RagdollSocket"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = 70
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -45
			socket.TwistUpperAngle = 45
			socket.Parent = joint.Parent

			joint.Enabled = false
			table.insert(record.motors, joint)
			table.insert(record.created, a0)
			table.insert(record.created, a1)
			table.insert(record.created, socket)
		end
	end

	-- Limbs normally don't collide, so give each one an invisible collider.
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			record.groups[part] = part.CollisionGroup
			part.CollisionGroup = GROUP

			if part ~= root then
				local collider = Instance.new("Part")
				collider.Name = "RagdollCollider"
				collider.Size = part.Size * 0.85
				collider.CFrame = part.CFrame
				collider.Transparency = 1
				collider.Massless = true
				collider.CanQuery = false
				collider.CanTouch = false
				collider.CollisionGroup = GROUP

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = part
				weld.Part1 = collider
				weld.Parent = collider

				collider.Parent = part
				table.insert(record.created, collider)
			end
		end
	end

	if Players:GetPlayerFromCharacter(character) then
		pcall(root.SetNetworkOwner, root, nil)
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	character:SetAttribute("Ragdolled", true)
end

function Ragdoll.Disable(character: Model)
	local record = active[character]
	if not record then
		return
	end
	active[character] = nil

	for _, instance in record.created do
		instance:Destroy()
	end
	for _, motor in record.motors do
		if motor.Parent then
			motor.Enabled = true
		end
	end
	for part, group in record.groups do
		if part.Parent then
			part.CollisionGroup = group
		end
	end
	character:SetAttribute("Ragdolled", false)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 then
		if root then
			standUp(character, humanoid, root)
		end
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		local player = Players:GetPlayerFromCharacter(character)
		if player and root then
			pcall(root.SetNetworkOwner, root, player)
		end
	end
end

-- Drops bookkeeping for a character that was removed from the game.
function Ragdoll.Forget(character: Model)
	active[character] = nil
end

return Ragdoll
