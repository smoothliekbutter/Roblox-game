--[[
	Input
	Keyboard / mouse / gamepad / touch controls.
	  M1 (click, hold to chain)   basic attack, hold Space on the 4th hit to uppercut
	  Q                           dash in your movement direction (Evasive when stunned)
	  F (hold)                    block, press right before a hit to perfect block
	  1-4                         character skills (sent even on cooldown: some skills
	                              read follow-up presses, like timing Black Divider)
	  R                           the character's special (also sent on cooldown)
	  G                           awaken when the meter is full
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
local dashReadyAt = 0 -- front and back
-- The front dash's push while it lasts: an M1 cuts it short.
local frontDash: Instance? = nil
-- Extra jumps in the air (Kits airJumps), used since leaving the ground.
local airJumpsUsed = 0
local jumpReleasedInAir = false
local sideDashReadyAt = 0 -- left and right: their own, shorter cooldown

-- Mirror of the server's combo counter so our animation plays instantly.
-- The server still decides what actually hits.
local predictedCombo = 0
local lastM1 = 0
local nextM1 = 0
-- Jumping is locked while swinging. The server enforces it too (JumpHeight 0),
-- but locking it here as well means there's no ping delay.
local noJumpUntil = 0
-- The uppercut is thrown with Space held: that same press mustn't then jump
-- you up after them. Jumping waits until Space has been let go.
local jumpNeedsRelease = false
-- Space already held when the 3rd hit lands: they're lining up the uppercut,
-- so stay on the ground for the 4th (until it's thrown, the string runs out,
-- or Space is let go: a fresh press then jumps, for the downslam).
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

local lastJumpRequest = 0

-- In the air, from our own physics (exact; the server sees us a ping
-- late). A jump pressed this very frame counts too: it only lifts off on
-- the next physics step.
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

-- The server's hover or dive for an air move reaches us a round trip late,
-- and a jump only lasts ~0.4s, so hold still where the key was pressed
-- until it arrives. Same "Knockback" name as Remotes.Impulse, so the real
-- impulse replaces it. Only for moves that are ready (a rejected press or a
-- follow-up tap, like timing Black Divider, never freezes you).
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
		or character:GetAttribute("SwordAway") == true -- thrown (Slayer Recall)
	then
		return
	end
	local t = os.clock()
	if t < nextM1 then
		return
	end
	-- An M1 during a front dash cuts the dash short and swings out of it.
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
	-- Jump only means uppercut on the ground; in the air it's the downslam.
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
			-- A launcher: back in action quickly, and free to jump after them.
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
		-- Jumping after the 3rd hit is the downslam (3 hits, jump, hit). But
		-- Space already held here means the uppercut is coming: no hop.
		if index == Config.M1.ComboLength - 1 and jumpHeld(humanoid) then
			uppercutPrimedUntil = t + Config.M1.ResetTime
		end
	end

	-- Our count of the string goes along, so the server's swing is the one we see.
	Remotes.Action:FireServer("M1", { jump = jump, airborne = inAir, index = index })
	Moves.PlayM1(character, index, variant)

	-- Step into the swing a little so strings stay connected.
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	Impulse.Apply(root, forward * Config.M1.LungeSpeed, Config.M1.LungeTime, "Lunge", 0.6)
end

-- Someone right in front, for a front dash to stop at.
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
	-- Side dashes are a quicker, smaller hop.
	local duration = if direction == "Left" or direction == "Right"
		then Config.Dash.SideDuration
		else Config.Dash.Duration
	local mover = Impulse.Apply(root, basis:VectorToWorldSpace(localVector) * speed, duration, "Dash")
	if direction == "Front" then
		frontDash = mover.Parent
	end

	-- Front dash steers with the camera, side and back dashes keep their line.
	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not mover.Parent then
			connection:Disconnect()
			-- A front dash always ends in an M1, when it runs its course (not
			-- cut short or knocked out of). Side and back dashes don't.
			if direction == "Front" and os.clock() - start >= duration - 0.05 then
				tryM1()
			end
			return
		end
		if direction == "Front" then
			basis = cameraBasis()
			-- Every front dash goes into an M1: reaching someone, it stops
			-- and swings at them.
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

	-- While stunned or ragdolled, Q is the Evasive breakout instead.
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

-- A steerable push from a skill (Bull Thrust): it turns toward where you're
-- heading (movement keys, or the camera when none are held) at up to
-- `turnRate` degrees per second, keeping its speed, and you face the way
-- you're going. Shift lock lets go of your facing meanwhile.
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

-- Server owns ragdoll physics, but the client's Humanoid state must match
-- or it fights the ragdoll / stays floppy after getting up.
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
	-- Ragdolls disable the Neck motor: don't die of a "broken neck".
	humanoid.RequiresNeck = false
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

	-- Skills 1-4 and awakening. The server checks cooldowns and state.
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
				-- Some moves do something else when the key is held.
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
		-- Air jumps come back on landing, and need a fresh press in the air.
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
			-- The server gives the jump back a ping late after a move ends;
			-- don't eat a jump pressed in between.
			if
				canJump
				and humanoid.JumpHeight < Config.Movement.JumpHeight
				and character:GetAttribute("Rooted") ~= true
			then
				humanoid.JumpHeight = Config.Movement.JumpHeight
			end
		end

		-- Holding F through a swing or stun: block as soon as it's allowed.
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
		-- Plain knockback eases out; dives and steered pushes keep their speed.
		local plain = type(options) ~= "table"
		local mover =
			Impulse.Apply(root, velocity, math.clamp(duration, 0, 1), "Knockback", if plain then 0.45 else nil)
		-- Dives (air Bull Thrust, the Meteorite slam, Plunge): once we touch down,
		-- stop pushing into the floor and carry on as a skid.
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
		-- One more jump in the air for kits that ride the wind (Yuno).
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
