local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CombatState = require(Shared.CombatState)
local Impulse = require(Shared.Impulse)
local Kits = require(Shared.Kits)
local Remotes = require(Shared.Remotes)

local CameraShake = require(script.Parent.CameraShake)
local Moves = require(script.Parent.Moves)
local VFX = require(script.Parent.VFX)

local localPlayer = Players.LocalPlayer

local DASH_VECTORS = {
	Front = Vector3.new(0, 0, -1),
	Back = Vector3.new(0, 0, 1),
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
}

local BLOCK_RETRY = 0.12

local Input = {}

local m1Held = false
local blockHeld = false
local lastBlockSent = 0
local dashReadyAt = 0
local frontDash: Instance? = nil
local airJumpsUsed = 0
local jumpReleasedInAir = false
local sideDashReadyAt = 0

local predictedCombo = 0
local lastM1 = 0
local nextM1 = 0
local noJumpUntil = 0
local jumpNeedsRelease = false
local uppercutPrimedUntil = 0
local jumpEnabled = true

local function getCharacter(): (Model?, Humanoid?, BasePart?)
	local character = localPlayer.Character
	if not character or not CombatState.IsAlive(character) then
		return nil, nil, nil
	end
	return character,
		character:FindFirstChildOfClass("Humanoid"),
		character:FindFirstChild("HumanoidRootPart") :: BasePart
end

local function cameraBasis(): CFrame
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(Vector3.zero, flat.Unit)
end

local function dashDirection(humanoid: Humanoid): string
	local move = humanoid.MoveDirection
	if move.Magnitude < 0.1 then
		return "Front"
	end
	local relative = cameraBasis():VectorToObjectSpace(move)
	if math.abs(relative.X) > math.abs(relative.Z) then
		return if relative.X > 0 then "Right" else "Left"
	end
	return if relative.Z > 0 then "Back" else "Front"
end

local function jumpHeld(humanoid: Humanoid): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
		or humanoid.Jump
end

local lastJumpRequest = 0

local function airborne(): boolean
	local _, humanoid = getCharacter()
	if not humanoid then
		return false
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		return true
	end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		return true
	end
	return jumpEnabled and humanoid.JumpHeight > 0 and os.clock() - lastJumpRequest < 0.06
end

local AIR_HOLD = Vector3.new(0, 0.05, 0)
local AIR_HOLD_TIME = 0.4

local function holdInAir(slot: number, airHold: boolean?)
	local character, _, root = getCharacter()
	if not character or not root or not airHold then
		return
	end
	if not CombatState.CanAct(character) or CombatState.IsCasting(character) then
		return
	end
	if CombatState.Cooldown(character, slot) > 0.1 then
		return
	end
	Impulse.Apply(root, AIR_HOLD, AIR_HOLD_TIME, "Knockback")
end

local function tryM1()
	local character, humanoid, root = getCharacter()
	if not character or not humanoid or not root then
		return
	end
	if
		not CombatState.CanAct(character)
		or CombatState.IsBlocking(character)
		or CombatState.IsCasting(character)
		or character:GetAttribute("SwordAway") == true
	then
		return
	end
	local t = os.clock()
	if t < nextM1 then
		return
	end
	if frontDash then
		if frontDash.Parent then
			frontDash:Destroy()
		end
		frontDash = nil
	end
	if t - lastM1 > Config.M1.ResetTime then
		predictedCombo = 0
	end
	predictedCombo += 1
	lastM1 = t

	local index = predictedCombo
	local inAir = humanoid.FloorMaterial == Enum.Material.Air
	local jump = not inAir and jumpHeld(humanoid)
	local variant = "Normal"
	if index >= Config.M1.ComboLength then
		predictedCombo = 0
		uppercutPrimedUntil = 0
		nextM1 = t + Config.M1.EndLag
		noJumpUntil = t + Config.M1.FinisherBusy
		if inAir then
			variant = "Downslam"
		elseif jump then
			variant = "Uppercut"
			nextM1 = t + Config.M1.UppercutEndLag
			noJumpUntil = t + Config.M1.UppercutJumpAfter
			jumpNeedsRelease = true
		else
			variant = "Knockback"
		end
	else
		nextM1 = t + Config.M1.SwingCooldown
		noJumpUntil = t + (if index == Config.M1.ComboLength - 1 then Config.M1.DownslamJumpAfter else Config.M1.Busy)
		if index == Config.M1.ComboLength - 1 and jumpHeld(humanoid) then
			uppercutPrimedUntil = t + Config.M1.ResetTime
		end
	end

	Remotes.Action:FireServer("M1", { jump = jump, airborne = inAir, index = index })
	Moves.PlayM1(character, index, variant)

	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	Impulse.Apply(root, forward * Config.M1.LungeSpeed, Config.M1.LungeTime, "Lunge", 0.6)
end

local function enemyAhead(character: Model, root: BasePart): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	for _, part in workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0, 0, -3), Vector3.new(4.5, 5, 4), params) do
		local model = part:FindFirstAncestorWhichIsA("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and model ~= character then
			return true
		end
	end
	return false
end

local function performDash(direction: string)
	local character, _, root = getCharacter()
	if not character or not root then
		return
	end
	local speed = Config.Dash.Speed[direction]
	local localVector = DASH_VECTORS[direction]
	local basis = cameraBasis()
	local duration = if direction == "Left" or direction == "Right"
		then Config.Dash.SideDuration
		else Config.Dash.Duration
	local mover = Impulse.Apply(root, basis:VectorToWorldSpace(localVector) * speed, duration, "Dash")
	if direction == "Front" then
		frontDash = mover.Parent
	end

	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not mover.Parent then
			connection:Disconnect()
			if direction == "Front" and os.clock() - start >= duration - 0.05 then
				tryM1()
			end
			return
		end
		if direction == "Front" then
			basis = cameraBasis()
			if enemyAhead(character, root) then
				connection:Disconnect()
				if mover.Parent then
					mover.Parent:Destroy()
				end
				frontDash = nil
				tryM1()
				return
			end
		end
		local alpha = (os.clock() - start) / duration
		mover.VectorVelocity = basis:VectorToWorldSpace(localVector) * speed * (1 - alpha * 0.4)
	end)

	VFX.Play("Dash", { character = character, direction = direction })
	CameraShake.FovKick(6)
end

local function tryDash()
	local character, humanoid = getCharacter()
	if not character or not humanoid then
		return
	end

	if CombatState.IsStunned(character) or CombatState.IsRagdolled(character) then
		if (tonumber(character:GetAttribute("Evasive")) or 0) >= Config.Evasive.Max then
			Remotes.Action:FireServer("Evasive")
		end
		return
	end

	if CombatState.IsCasting(character) then
		return
	end
	local direction = dashDirection(humanoid)
	local side = direction == "Left" or direction == "Right"
	local t = os.clock()
	if t < (if side then sideDashReadyAt else dashReadyAt) then
		return
	end
	local kit = Kits.Of(character)
	local awakening = kit and CombatState.IsAwakened(character) and kit.awakening
	local multiplier = if awakening then awakening.cooldownMultiplier else 1
	if side then
		sideDashReadyAt = t + Config.Dash.SideCooldown * multiplier
	else
		dashReadyAt = t + Config.Dash.Cooldown * multiplier
	end

	Remotes.Action:FireServer("Dash", direction)
	performDash(direction)
end

local function steerImpulse(
	mover: LinearVelocity,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	turnRate: number
)
	local autoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
	character:SetAttribute("Steering", true)
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not mover.Parent or not root.Parent then
			connection:Disconnect()
			character:SetAttribute("Steering", nil)
			humanoid.AutoRotate = autoRotate
			return
		end
		local velocity = mover.VectorVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = flat.Magnitude
		if speed < 1 then
			return
		end
		local want = humanoid.MoveDirection
		if want.Magnitude < 0.1 then
			want = cameraBasis().LookVector
		end
		want = Vector3.new(want.X, 0, want.Z)
		if want.Magnitude < 1e-3 then
			return
		end
		want = want.Unit
		local current = flat / speed
		local angle = math.acos(math.clamp(current:Dot(want), -1, 1))
		if angle > 1e-3 then
			local turn = math.min(angle, math.rad(turnRate) * dt)
			local sign = if current:Cross(want).Y > 0 then 1 else -1
			current = CFrame.Angles(0, turn * sign, 0):VectorToWorldSpace(current)
		end
		mover.VectorVelocity = current * speed + Vector3.new(0, velocity.Y, 0)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + current)
	end)
end

local function setBlock(held: boolean)
	blockHeld = held
	lastBlockSent = os.clock()
	Remotes.Action:FireServer("Block", held)
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	jumpEnabled = true
	character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		if character:GetAttribute("Ragdolled") then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		else
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
	humanoid.RequiresNeck = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
end

function Input.Start()
	ContextActionService:BindAction("CloverM1", function(_, state)
		if state == Enum.UserInputState.Begin then
			m1Held = true
			tryM1()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			m1Held = false
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	ContextActionService:BindAction("CloverDash", function(_, state)
		if state == Enum.UserInputState.Begin then
			tryDash()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

	ContextActionService:BindAction("CloverBlock", function(_, state)
		if state == Enum.UserInputState.Begin then
			setBlock(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setBlock(false)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)

	ContextActionService:SetTitle("CloverM1", "M1")
	ContextActionService:SetTitle("CloverDash", "Dash")
	ContextActionService:SetTitle("CloverBlock", "Block")

	local skillKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
	for slot, key in skillKeys do
		local action = "CloverSkill" .. slot
		ContextActionService:BindAction(action, function(_, state)
			if state == Enum.UserInputState.Begin and getCharacter() then
				local inAir = airborne()
				if inAir then
					local info = Kits.SkillsOf(localPlayer.Character :: Model)[slot]
					holdInAir(slot, info and info.airHold)
				end
				Remotes.Action:FireServer("Skill", slot, { airborne = inAir })
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				Remotes.Action:FireServer("SkillRelease", slot)
			end
			return Enum.ContextActionResult.Sink
		end, true, key)
		ContextActionService:SetTitle(action, tostring(slot))
	end
	ContextActionService:BindAction("CloverSpecial", function(_, state)
		if state == Enum.UserInputState.Begin and getCharacter() then
			local inAir = airborne()
			if inAir then
				local kit = Kits.Of(localPlayer.Character :: Model)
				holdInAir(CombatState.SpecialSlot, kit and kit.special and kit.special.airHold)
			end
			Remotes.Action:FireServer("Special", { airborne = inAir })
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("CloverSpecial", "R")
	ContextActionService:BindAction("CloverAwaken", function(_, state)
		if state == Enum.UserInputState.Begin and getCharacter() then
			Remotes.Action:FireServer("Awaken")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.G)
	ContextActionService:SetTitle("CloverAwaken", "G")

	RunService.Heartbeat:Connect(function()
		if m1Held then
			tryM1()
		end

		local character, humanoid = getCharacter()
		if humanoid and not jumpHeld(humanoid) then
			jumpNeedsRelease = false
			uppercutPrimedUntil = 0
		end
		if humanoid then
			if humanoid.FloorMaterial ~= Enum.Material.Air then
				airJumpsUsed = 0
				jumpReleasedInAir = false
			elseif not jumpHeld(humanoid) then
				jumpReleasedInAir = true
			end
		end
		if character and humanoid then
			local canJump = os.clock() >= noJumpUntil
				and not jumpNeedsRelease
				and os.clock() >= uppercutPrimedUntil
				and CombatState.CanAct(character)
				and not CombatState.IsBlocking(character)
				and not CombatState.IsBusy(character)
				and not CombatState.IsCasting(character)
			if canJump ~= jumpEnabled then
				jumpEnabled = canJump
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, canJump)
			end
			if
				canJump
				and humanoid.JumpHeight < Config.Movement.JumpHeight
				and character:GetAttribute("Rooted") ~= true
			then
				humanoid.JumpHeight = Config.Movement.JumpHeight
			end
		end

		if blockHeld and character and not CombatState.IsBlocking(character) then
			if os.clock() - lastBlockSent > BLOCK_RETRY then
				lastBlockSent = os.clock()
				Remotes.Action:FireServer("Block", true)
			end
		end
	end)

	Remotes.Impulse.OnClientEvent:Connect(function(velocity, duration, options)
		local character, humanoid, root = getCharacter()
		if not (character and humanoid and root) or typeof(velocity) ~= "Vector3" or type(duration) ~= "number" then
			return
		end
		local plain = type(options) ~= "table"
		local mover =
			Impulse.Apply(root, velocity, math.clamp(duration, 0, 1), "Knockback", if plain then 0.45 else nil)
		if type(options) == "table" and options.landStop == true and velocity.Y < 0 then
			local connection
			connection = RunService.Heartbeat:Connect(function()
				if not mover.Parent or not root.Parent then
					connection:Disconnect()
					return
				end
				if humanoid.FloorMaterial ~= Enum.Material.Air then
					connection:Disconnect()
					local v = mover.VectorVelocity
					local keep = if type(options.landKeep) == "number" then options.landKeep else 1
					mover.VectorVelocity = Vector3.new(v.X, 0, v.Z) * keep
					mover.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
				end
			end)
		end
		if type(options) == "table" and type(options.steer) == "number" then
			steerImpulse(mover, character, humanoid, root, options.steer)
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		lastJumpRequest = os.clock()
		local character, humanoid, root = getCharacter()
		local kit = character and Kits.Of(character)
		if
			not character
			or not humanoid
			or not root
			or not kit
			or (kit.airJumps or 0) <= airJumpsUsed
			or humanoid.FloorMaterial ~= Enum.Material.Air
			or not jumpReleasedInAir
			or not CombatState.CanAct(character)
			or CombatState.IsCasting(character)
			or CombatState.IsBlocking(character)
			or character:GetAttribute("Rooted") == true
		then
			return
		end
		airJumpsUsed += 1
		jumpReleasedInAir = false
		local velocity = root.AssemblyLinearVelocity
		Impulse.Apply(
			root,
			Vector3.new(velocity.X, Config.Movement.AirJumpSpeed, velocity.Z),
			Config.Movement.AirJumpTime,
			"AirJump"
		)
		VFX.Play("AirJump", { character = character })
		Remotes.Action:FireServer("AirJump")
	end)

	localPlayer.CharacterAdded:Connect(onCharacterAdded)
	if localPlayer.Character then
		task.spawn(onCharacterAdded, localPlayer.Character)
	end
end

return Input
