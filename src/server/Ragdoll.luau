--[[
	Ragdoll
	Swaps a character's Motor6Ds for BallSocketConstraints so it flops. The
	server takes network ownership while ragdolled so knockback is smooth and
	can't be ignored by the client. Works with R6 and R15.

	Physics tuning:
	  - Per-joint limits so limbs bend like a body, not like rope.
	  - Joint friction damps flailing without making limbs stiff.
	  - No bounce and decent friction, so bodies skid and settle.
	  - Getting up is a short smooth rise instead of a teleport.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

type JointSettings = { upper: number, twistLower: number, twistUpper: number, friction: number }

-- Degrees. The cone (upper) is the forward/back swing, twist the sideways
-- swing for limbs (nod for the neck). Friction is a fraction of what it
-- takes to hold the limb up against gravity, so limbs still fall naturally.
local JOINT_SETTINGS: { [string]: JointSettings } = {
	Neck = { upper = 35, twistLower = -30, twistUpper = 30, friction = 15 },
	["Right Shoulder"] = { upper = 100, twistLower = -55, twistUpper = 55, friction = 25 },
	["Left Shoulder"] = { upper = 100, twistLower = -55, twistUpper = 55, friction = 25 },
	["Right Hip"] = { upper = 70, twistLower = -20, twistUpper = 20, friction = 40 },
	["Left Hip"] = { upper = 70, twistLower = -20, twistUpper = 20, friction = 40 },
}
local DEFAULT_SETTINGS: JointSettings = { upper = 60, twistLower = -35, twistUpper = 35, friction = 20 }

-- Density, friction, elasticity, frictionWeight, elasticityWeight. The huge
-- elasticity weight makes "no bounce" win against whatever the floor is.
local BODY_PHYSICS = PhysicalProperties.new(0.9, 0.6, 0, 1, 100)

local GET_UP_TIME = 0.25

type Record = {
	created: { Instance },
	motors: { Motor6D },
	groups: { [BasePart]: string },
	physics: { [BasePart]: PhysicalProperties? },
}

local active: { [Model]: Record } = {}
local gettingUp: { [Model]: RBXScriptConnection } = {}

local Ragdoll = {}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Where the character should stand when it gets up: upright, on the
-- ground, facing the way the body was lying.
local function standingCFrame(character: Model, humanoid: Humanoid, root: BasePart): CFrame
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
	return CFrame.lookAt(position, position + facing.Unit)
end

local function cancelGetUp(character: Model)
	local connection = gettingUp[character]
	if connection then
		connection:Disconnect()
		gettingUp[character] = nil
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = false
		end
	end
end

function Ragdoll.IsActive(character: Model): boolean
	return active[character] ~= nil
end

function Ragdoll.Enable(character: Model)
	if active[character] then
		return
	end
	cancelGetUp(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end

	local record: Record = { created = {}, motors = {}, groups = {}, physics = {} }
	active[character] = record
	-- The Neck motor goes off below: without this a player dies on the spot.
	humanoid.RequiresNeck = false

	for _, joint in character:GetDescendants() do
		-- Body joints only: a weapon's grip (Part1 inside the weapon model) stays rigid.
		if
			joint:IsA("Motor6D")
			and not KEEP_JOINTS[joint.Name]
			and joint.Part0
			and joint.Part1
			and joint.Part1.Parent == character
		then
			local settings = JOINT_SETTINGS[joint.Name] or DEFAULT_SETTINGS

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
			socket.UpperAngle = settings.upper
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = settings.twistLower
			socket.TwistUpperAngle = settings.twistUpper
			socket.MaxFrictionTorque = settings.friction
			socket.Restitution = 0
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
			record.physics[part] = part.CustomPhysicalProperties
			part.CollisionGroup = GROUP
			part.CustomPhysicalProperties = BODY_PHYSICS

			if part ~= root then
				local collider = Instance.new("Part")
				collider.Name = "RagdollCollider"
				collider.Size = part.Size * 0.95
				collider.CFrame = part.CFrame
				collider.Transparency = 1
				collider.Massless = true
				collider.CanQuery = false
				collider.CanTouch = false
				collider.CollisionGroup = GROUP
				collider.CustomPhysicalProperties = BODY_PHYSICS

				local weld = Instance.new("Weld")
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

local function finishGettingUp(character: Model, humanoid: Humanoid, root: BasePart)
	character:SetAttribute("Ragdolled", false)
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		pcall(root.SetNetworkOwner, root, player)
	end
end

-- Ends the ragdoll. By default the body rises smoothly to its feet over a
-- quarter second; `instant` snaps upright (used by the Evasive breakout).
function Ragdoll.Disable(character: Model, instant: boolean?)
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
			part.CustomPhysicalProperties = record.physics[part]
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		character:SetAttribute("Ragdolled", false)
		return
	end

	local target = standingCFrame(character, humanoid, root)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	if instant then
		root.CFrame = target
		finishGettingUp(character, humanoid, root)
		return
	end

	-- Rise smoothly: the root is held (anchored) and eased from how the
	-- body was lying to standing. Still counts as ragdolled until done, so
	-- people can't be hit while getting up.
	local from = root.CFrame
	local start = os.clock()
	root.Anchored = true
	gettingUp[character] = RunService.Heartbeat:Connect(function()
		local alpha = smooth((os.clock() - start) / GET_UP_TIME)
		if root.Parent then
			root.CFrame = from:Lerp(target, alpha)
		end
		if alpha >= 1 or not root.Parent or humanoid.Health <= 0 then
			gettingUp[character]:Disconnect()
			gettingUp[character] = nil
			root.Anchored = false
			if humanoid.Health > 0 then
				finishGettingUp(character, humanoid, root)
			else
				character:SetAttribute("Ragdolled", false)
			end
		end
	end)
end

-- Drops bookkeeping for a character that was removed from the game.
function Ragdoll.Forget(character: Model)
	active[character] = nil
	local connection = gettingUp[character]
	if connection then
		connection:Disconnect()
		gettingUp[character] = nil
	end
end

return Ragdoll
