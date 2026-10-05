-- Test dummies in front of spawn (standing, blocking, attacking), on the real combat rules.

local Players = game:GetService("Players")

local CombatService = require(script.Parent.CombatService)
local CombatState = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").CombatState)

type Spec = {
	name: string,
	behavior: "Idle" | "Block" | "Attack",
	color: Color3,
	position: Vector3,
}

local SPECS: { Spec } = {
	{ name = "Dummy", behavior = "Idle", color = Color3.fromRGB(225, 225, 225), position = Vector3.new(-12, 3, -28) },
	{
		name = "Blocking Dummy",
		behavior = "Block",
		color = Color3.fromRGB(80, 140, 255),
		position = Vector3.new(0, 3, -28),
	},
	{
		name = "Attacking Dummy",
		behavior = "Attack",
		color = Color3.fromRGB(255, 90, 90),
		position = Vector3.new(12, 3, -28),
	},
}

local RESPAWN_TIME = 3
local REGEN_DELAY = 3
local AGGRO_RANGE = 25
local ATTACK_RANGE = 6.5

local folder = Instance.new("Folder")
folder.Name = "Dummies"
folder.Parent = workspace

local Dummies = {}

local function nearestPlayerRoot(position: Vector3, range: number): BasePart?
	local best, bestDistance = nil, range
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and CombatState.IsAlive(character) then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = root, distance
			end
		end
	end
	return best
end

local function face(root: BasePart, target: Vector3)
	local flatTarget = Vector3.new(target.X, root.Position.Y, target.Z)
	if (flatTarget - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flatTarget)
	end
end

local function runBehavior(model: Model, spec: Spec, humanoid: Humanoid, root: BasePart)
	while model.Parent and humanoid.Health > 0 do
		local data = CombatService.GetData(model)

		-- Heal back to full when left alone.
		if data and os.clock() - data.lastDamaged > REGEN_DELAY and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end

		local target = nearestPlayerRoot(root.Position, AGGRO_RANGE)
		local canAct = CombatState.CanAct(model)

		if spec.behavior == "Block" then
			if target and canAct then
				face(root, target.Position)
			end
			if canAct and not CombatState.IsBlocking(model) then
				CombatService.SetBlock(model, true)
			end
			task.wait(0.1)
		elseif spec.behavior == "Attack" then
			if target and canAct then
				face(root, target.Position)
				if (target.Position - root.Position).Magnitude <= ATTACK_RANGE then
					-- A full 4 hit string, then a breather.
					for _ = 1, 4 do
						if not CombatState.CanAct(model) then
							break
						end
						face(root, target.Position)
						CombatService.M1(model)
						task.wait(0.34)
					end
					task.wait(2)
				end
			end
			task.wait(0.1)
		else
			task.wait(0.5)
		end
	end
end

local function spawnDummy(spec: Spec)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = spec.color
	description.TorsoColor = spec.color
	description.LeftArmColor = spec.color
	description.RightArmColor = spec.color
	description.LeftLegColor = spec.color
	description.RightLegColor = spec.color

	local model = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
	model.Name = spec.name

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayName = spec.name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer

	model:PivotTo(CFrame.lookAt(spec.position, Vector3.new(0, spec.position.Y, 0)))
	model.Parent = folder
	root:SetNetworkOwner(nil)

	CombatService.Register(model)

	humanoid.Died:Connect(function()
		task.delay(RESPAWN_TIME, function()
			model:Destroy()
			spawnDummy(spec)
		end)
	end)

	task.spawn(runBehavior, model, spec, humanoid, root)
end

function Dummies.Start()
	for _, spec in SPECS do
		task.spawn(spawnDummy, spec)
	end
end

return Dummies
