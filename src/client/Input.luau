--[[
	Input
	Keyboard / mouse / gamepad / touch controls.
	  M1 (click, hold to chain)   basic attack, hold Space on the 4th hit to uppercut
	  Q                           dash in your movement direction (Evasive when stunned)
	  F (hold)                    block, press right before a hit to perfect block
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CombatState = require(Shared.CombatState)
local Impulse = require(Shared.Impulse)
local Remotes = require(Shared.Remotes)

local CameraShake = require(script.Parent.CameraShake)
local HUD = require(script.Parent.HUD)
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

-- Mirror of the server's combo counter so our animation plays instantly.
-- The server still decides what actually hits.
local predictedCombo = 0
local lastM1 = 0
local nextM1 = 0

local function getCharacter(): (Model?, Humanoid?, BasePart?)
	local character = localPlayer.Character
	if not character or not CombatState.IsAlive(character) then
		return nil, nil, nil
	end
	return character,
		character:FindFirstChildOfClass("Humanoid"),
		character:FindFirstChild("HumanoidRootPart") :: BasePart
end

-- Camera yaw only, so "forward" means where you're looking, flat on the ground.
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

local function tryM1()
	local character, humanoid, root = getCharacter()
	if not character or not humanoid or not root then
		return
	end
	if not CombatState.CanAct(character) or CombatState.IsBlocking(character) then
		return
	end
	local t = os.clock()
	if t < nextM1 then
		return
	end
	if t - lastM1 > Config.M1.ResetTime then
		predictedCombo = 0
	end
	predictedCombo += 1
	lastM1 = t

	local index = predictedCombo
	local jump = jumpHeld(humanoid)
	local variant = "Normal"
	if index >= Config.M1.ComboLength then
		predictedCombo = 0
		nextM1 = t + Config.M1.EndLag
		if jump then
			variant = "Uppercut"
		elseif humanoid.FloorMaterial == Enum.Material.Air then
			variant = "Downslam"
		else
			variant = "Knockback"
		end
	else
		nextM1 = t + Config.M1.SwingCooldown
	end

	Remotes.Action:FireServer("M1", { jump = jump })
	Moves.PlayM1(character, index, variant)

	-- Step into the swing a little so strings stay connected.
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	Impulse.Apply(root, forward * Config.M1.LungeSpeed, Config.M1.LungeTime, "Lunge")
end

local function performDash(direction: string)
	local character, _, root = getCharacter()
	if not character or not root then
		return
	end
	local speed = Config.Dash.Speed[direction]
	local localVector = DASH_VECTORS[direction]
	local basis = cameraBasis()
	local mover = Impulse.Apply(root, basis:VectorToWorldSpace(localVector) * speed, Config.Dash.Duration, "Dash")

	-- Front dash steers with the camera, side and back dashes keep their line.
	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not mover.Parent then
			connection:Disconnect()
			return
		end
		if direction == "Front" then
			basis = cameraBasis()
		end
		local alpha = (os.clock() - start) / Config.Dash.Duration
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

	-- While stunned or ragdolled, Q is the Evasive breakout instead.
	if CombatState.IsStunned(character) or CombatState.IsRagdolled(character) then
		if (tonumber(character:GetAttribute("Evasive")) or 0) >= Config.Evasive.Max then
			Remotes.Action:FireServer("Evasive")
		end
		return
	end

	local t = os.clock()
	if t < dashReadyAt then
		return
	end
	dashReadyAt = t + Config.Dash.Cooldown
	HUD.SetDashCooldown(Config.Dash.Cooldown)

	local direction = dashDirection(humanoid)
	Remotes.Action:FireServer("Dash", direction)
	performDash(direction)
end

local function setBlock(held: boolean)
	blockHeld = held
	lastBlockSent = os.clock()
	Remotes.Action:FireServer("Block", held)
end

-- Server owns ragdoll physics, but the client's Humanoid state must match
-- or it fights the ragdoll / stays floppy after getting up.
local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		if character:GetAttribute("Ragdolled") then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		else
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
	-- Don't let the default "fall over" states interrupt combat.
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

	RunService.Heartbeat:Connect(function()
		if m1Held then
			tryM1()
		end
		-- Holding F through a swing or stun: block as soon as it's allowed.
		local character = localPlayer.Character
		if blockHeld and character and not CombatState.IsBlocking(character) then
			if os.clock() - lastBlockSent > BLOCK_RETRY then
				lastBlockSent = os.clock()
				Remotes.Action:FireServer("Block", true)
			end
		end
	end)

	Remotes.Impulse.OnClientEvent:Connect(function(velocity, duration)
		local _, _, root = getCharacter()
		if root and typeof(velocity) == "Vector3" and type(duration) == "number" then
			Impulse.Apply(root, velocity, math.clamp(duration, 0, 1), "Knockback")
		end
	end)

	localPlayer.CharacterAdded:Connect(onCharacterAdded)
	if localPlayer.Character then
		task.spawn(onCharacterAdded, localPlayer.Character)
	end
end

return Input
