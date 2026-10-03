--[[
	CombatService
	Server-authoritative core combat: M1 strings, blocking, perfect blocks,
	guard breaks, dashes, ragdolls and the Evasive breakout. Players and NPCs
	go through the same functions, so dummies fight with the real rules.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CombatState = require(Shared.CombatState)
local Impulse = require(Shared.Impulse)
local Remotes = require(Shared.Remotes)

local Hitbox = require(script.Parent.Hitbox)
local Ragdoll = require(script.Parent.Ragdoll)

export type CharData = {
	humanoid: Humanoid,
	combo: number,
	lastM1: number,
	nextM1: number,
	nextBlock: number,
	nextDash: number,
	ragdollToken: number,
	lastDamaged: number,
}

export type HitInfo = {
	damage: number,
	stun: number,
	guardBreak: boolean,
	variant: string, -- "Normal" | "Knockback" | "Uppercut" | "Downslam"
	airborne: boolean,
}

local DASH_DIRECTIONS = { Front = true, Back = true, Left = true, Right = true }

local registry: { [Model]: CharData } = {}

local CombatService = {}

local function getRoot(character: Model): BasePart?
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(vector: Vector3): Vector3
	local v = Vector3.new(vector.X, 0, vector.Z)
	return if v.Magnitude > 1e-3 then v.Unit else Vector3.new(0, 0, -1)
end

local function fireVFX(name: string, data: { [string]: any })
	Remotes.VFX:FireAllClients(name, data)
end

local function shake(character: Model, intensity: number)
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		Remotes.CameraShake:FireClient(player, intensity)
	end
end

-- Moves a character, routing to whoever owns its physics.
local function applyVelocity(character: Model, velocity: Vector3, duration: number)
	local root = getRoot(character)
	if not root then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if CombatState.IsRagdolled(character) then
		-- Server owns ragdolls, and a ragdoll has no Humanoid fighting the velocity.
		root.AssemblyLinearVelocity = velocity
	elseif player then
		Remotes.Impulse:FireClient(player, velocity, duration)
	else
		Impulse.Apply(root, velocity, duration, "Knockback")
	end
end

local function isAirborne(character: Model): boolean
	local root = getRoot(character)
	if not root then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), params) == nil
end

local function addEvasive(character: Model, amount: number)
	local current = character:GetAttribute("Evasive") or 0
	local value = math.clamp(current + amount, 0, Config.Evasive.Max)
	if value ~= current then
		character:SetAttribute("Evasive", value)
	end
end

local function ragdollFor(character: Model, duration: number)
	local data = registry[character]
	if not data then
		return
	end
	data.ragdollToken += 1
	local token = data.ragdollToken

	CombatState.SetBlocking(character, false)
	Ragdoll.Enable(character)
	CombatState.Stun(character, duration)

	task.delay(duration, function()
		if registry[character] == data and data.ragdollToken == token and CombatState.IsAlive(character) then
			Ragdoll.Disable(character)
		end
	end)
end

-- Fires the crater effect roughly when a downslammed victim reaches the ground.
local function scheduleCrater(victim: Model, attacker: Model)
	local root = getRoot(victim)
	if not root then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { victim, attacker }
	local result = workspace:Raycast(root.Position, Vector3.new(0, -80, 0), params)
	if not result then
		return
	end
	local fallTime = math.clamp((root.Position.Y - result.Position.Y - 2) / Config.M1.DownslamForce, 0, 1)
	task.delay(fallTime, function()
		fireVFX("Crater", { position = result.Position })
		shake(victim, 0.5)
		shake(attacker, 0.4)
	end)
end

function CombatService.GetData(character: Model): CharData?
	return registry[character]
end

function CombatService.Register(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or registry[character] then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)

	CombatState.Setup(character)
	humanoid.BreakJointsOnDeath = false
	humanoid.UseJumpPower = false

	local data: CharData = {
		humanoid = humanoid,
		combo = 0,
		lastM1 = 0,
		nextM1 = 0,
		nextBlock = 0,
		nextDash = 0,
		ragdollToken = 0,
		lastDamaged = 0,
	}
	registry[character] = data

	humanoid.Died:Connect(function()
		data.ragdollToken += 1 -- stop any pending get-up
		Ragdoll.Enable(character)
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			registry[character] = nil
			Ragdoll.Forget(character)
		end
	end)
end

--[[
	Lands (or fails to land) a hit. Returns what happened:
	"Hit" | "Blocked" | "Parried" | "GuardBreak" | "Immune" | "None"
]]
function CombatService.Hit(attacker: Model, victim: Model, hit: HitInfo): string
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	local victimRoot = getRoot(victim)
	local attackerRoot = getRoot(attacker)
	if not humanoid or not victimRoot or not attackerRoot or humanoid.Health <= 0 then
		return "None"
	end
	-- No hitting people on the floor: stops infinites.
	if CombatState.HasIFrames(victim) or CombatState.IsRagdolled(victim) then
		return "Immune"
	end

	local toAttacker = flat(attackerRoot.Position - victimRoot.Position)
	local look = flat(attackerRoot.CFrame.LookVector)
	local contact = victimRoot.Position + toAttacker * 1.2

	local facing = victimRoot.CFrame.LookVector:Dot(toAttacker) > Config.Block.FacingDot
	if CombatState.IsBlocking(victim) and facing then
		local blockAge = CombatState.Now() - (victim:GetAttribute("BlockStart") or 0)

		if blockAge <= Config.Block.PerfectWindow then
			CombatState.Stun(attacker, Config.Block.ParryStun)
			fireVFX("PerfectBlock", { position = contact, attacker = attacker, victim = victim })
			shake(attacker, 0.6)
			shake(victim, 0.35)
			return "Parried"
		end

		if hit.guardBreak then
			CombatState.SetBlocking(victim, false)
			CombatState.Stun(victim, Config.Block.GuardBreakStun)
			fireVFX("GuardBreak", { position = contact, victim = victim })
			shake(attacker, 0.4)
			shake(victim, 0.6)
			return "GuardBreak"
		end

		fireVFX("Block", { position = contact, victim = victim })
		applyVelocity(victim, -toAttacker * Config.Block.Pushback, 0.12)
		shake(victim, 0.12)
		return "Blocked"
	end

	-- The hit lands.
	humanoid:TakeDamage(hit.damage)
	CombatState.SetBlocking(victim, false)
	CombatState.Stun(victim, hit.stun)

	local victimData = registry[victim]
	if victimData then
		victimData.lastDamaged = os.clock()
	end
	addEvasive(victim, hit.damage * Config.Evasive.GainPerDamage)

	local heavy = hit.variant ~= "Normal"
	if hit.variant == "Knockback" then
		ragdollFor(victim, Config.Ragdoll.Duration)
		applyVelocity(victim, look * Config.M1.KnockbackForce + Vector3.new(0, Config.M1.KnockbackLift, 0), 0.2)
	elseif hit.variant == "Uppercut" then
		local lift = Vector3.new(0, Config.M1.UppercutForce, 0)
		applyVelocity(victim, lift + look * 4, 0.25)
		applyVelocity(attacker, lift, 0.25)
	elseif hit.variant == "Downslam" then
		ragdollFor(victim, Config.Ragdoll.Duration)
		applyVelocity(victim, look * 10 + Vector3.new(0, -Config.M1.DownslamForce, 0), 0.2)
		scheduleCrater(victim, attacker)
	elseif hit.airborne then
		local float = Vector3.new(0, 3, 0) + look * 3
		applyVelocity(victim, float, Config.M1.AirFloat)
		applyVelocity(attacker, float, Config.M1.AirFloat)
	else
		applyVelocity(victim, look * Config.M1.Push, 0.15)
	end

	fireVFX(if heavy then "HeavyHit" else "Hit", {
		position = contact,
		direction = look,
		attacker = attacker,
		victim = victim,
		damage = hit.damage,
		variant = hit.variant,
	})
	shake(attacker, if heavy then 0.45 else 0.18)
	shake(victim, if heavy then 0.7 else 0.3)
	return "Hit"
end

-- One swing of the M1 string. `jump` = jump held, turns the finisher into an uppercut.
function CombatService.M1(character: Model, jump: boolean?)
	local data = registry[character]
	if not data or not CombatState.CanAct(character) or CombatState.IsBlocking(character) then
		return
	end
	local t = os.clock()
	if t < data.nextM1 then
		return
	end
	if t - data.lastM1 > Config.M1.ResetTime then
		data.combo = 0
	end

	data.combo += 1
	data.lastM1 = t
	local index = data.combo
	local finisher = index >= Config.M1.ComboLength
	local airborne = isAirborne(character)

	local variant = "Normal"
	if finisher then
		data.combo = 0
		data.nextM1 = t + Config.M1.EndLag
		if jump then
			variant = "Uppercut"
		elseif airborne then
			variant = "Downslam"
		else
			variant = "Knockback"
		end
	else
		data.nextM1 = t + Config.M1.SwingCooldown
	end
	CombatState.SetBusy(character, if finisher then Config.M1.FinisherBusy else Config.M1.Busy)

	fireVFX("Swing", { character = character, index = index, finisher = finisher, variant = variant })

	task.delay(Config.M1.WindUp, function()
		-- Getting hit during wind-up cancels the swing.
		if not CombatState.CanAct(character) then
			return
		end
		local root = getRoot(character)
		if not root then
			return
		end
		local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -Config.M1.HitboxOffset)
		for _, victim in Hitbox.Box(character, hitboxCFrame, Config.M1.HitboxSize) do
			CombatService.Hit(character, victim, {
				damage = if finisher then Config.M1.FinisherDamage else Config.M1.Damage,
				stun = if variant == "Uppercut" then Config.M1.UppercutStun else Config.M1.HitStun,
				guardBreak = finisher,
				variant = variant,
				airborne = airborne,
			})
		end
	end)
end

function CombatService.SetBlock(character: Model, wantBlock: boolean)
	local data = registry[character]
	if not data then
		return
	end
	if wantBlock then
		if CombatState.IsBlocking(character) or not CombatState.CanAct(character) or CombatState.IsBusy(character) then
			return
		end
		if os.clock() < data.nextBlock then
			return
		end
		CombatState.SetBlocking(character, true)
	elseif CombatState.IsBlocking(character) then
		CombatState.SetBlocking(character, false)
		data.nextBlock = os.clock() + Config.Block.Cooldown
	end
end

-- Movement is client-side (the client owns its character), the server only
-- validates the cooldown and tells everyone else to draw the effect.
function CombatService.Dash(character: Model, direction: string): boolean
	local data = registry[character]
	if not data or not DASH_DIRECTIONS[direction] or not CombatState.CanAct(character) then
		return false
	end
	local t = os.clock()
	if t < data.nextDash - Config.Dash.Tolerance then
		return false
	end
	data.nextDash = t + Config.Dash.Cooldown
	CombatState.SetBlocking(character, false)
	return true
end

-- Breaks out of a combo or ragdoll when the Evasive bar is full.
function CombatService.Evasive(character: Model): boolean
	local data = registry[character]
	if not data or not CombatState.IsAlive(character) then
		return false
	end
	if not (CombatState.IsStunned(character) or CombatState.IsRagdolled(character)) then
		return false
	end
	if (character:GetAttribute("Evasive") or 0) < Config.Evasive.Max then
		return false
	end

	data.ragdollToken += 1
	character:SetAttribute("Evasive", 0)
	Ragdoll.Disable(character)
	CombatState.ClearStun(character)
	CombatState.GiveIFrames(character, Config.Evasive.IFrames)

	local root = getRoot(character)
	if root then
		local back = -flat(root.CFrame.LookVector)
		applyVelocity(character, back * Config.Evasive.Speed + Vector3.new(0, 8, 0), 0.2)
	end
	fireVFX("Evasive", { character = character })
	return true
end

local function onAction(player: Player, action: unknown, payload: unknown)
	local character = player.Character
	if not character or not registry[character] or type(action) ~= "string" then
		return
	end

	if action == "M1" then
		local jump = type(payload) == "table" and (payload :: any).jump == true
		CombatService.M1(character, jump)
	elseif action == "Block" then
		CombatService.SetBlock(character, payload == true)
	elseif action == "Dash" then
		if type(payload) == "string" and CombatService.Dash(character, payload) then
			-- The dasher already drew their own effect.
			for _, other in Players:GetPlayers() do
				if other ~= player then
					Remotes.VFX:FireClient(other, "Dash", { character = character, direction = payload })
				end
			end
		end
	elseif action == "Evasive" then
		CombatService.Evasive(character)
	end
end

-- Movement speed follows combat state every frame.
local function updateMovement()
	for character, data in registry do
		local humanoid = data.humanoid
		if humanoid.Health > 0 then
			local speed, jump = Config.Movement.WalkSpeed, Config.Movement.JumpHeight
			if CombatState.IsRagdolled(character) then
				speed, jump = 0, 0
			elseif CombatState.IsStunned(character) then
				speed, jump = Config.Movement.StunnedSpeed, 0
			elseif CombatState.IsBlocking(character) then
				speed, jump = Config.Movement.BlockingSpeed, 0
			elseif CombatState.IsBusy(character) then
				speed = Config.Movement.AttackingSpeed
			end
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
			if humanoid.JumpHeight ~= jump then
				humanoid.JumpHeight = jump
			end
		end
	end
end

function CombatService.Start()
	Remotes.Action.OnServerEvent:Connect(onAction)

	local evasiveTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		updateMovement()

		-- Attribute writes replicate, so the passive regen ticks 4 times a second.
		evasiveTimer += dt
		if evasiveTimer >= 0.25 then
			for character in registry do
				addEvasive(character, Config.Evasive.RegenPerSecond * evasiveTimer)
			end
			evasiveTimer = 0
		end
	end)
end

return CombatService
