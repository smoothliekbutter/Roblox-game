local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatState = require(Shared.CombatState)
local Config = require(Shared.Config)
local Impulse = require(Shared.Impulse)
local Kits = require(Shared.Kits)
local Remotes = require(Shared.Remotes)

local Hitbox = require(script.Parent.Hitbox)
local Ragdoll = require(script.Parent.Ragdoll)

type Counter = {
	untilTime: number,
	types: { [string]: boolean },
	onCounter: (attacker: Model, hit: HitInfo) -> (),
	filter: ((attacker: Model, hit: HitInfo) -> boolean)?,
}

export type CharData = {
	humanoid: Humanoid,
	combo: number,
	lastM1: number,
	nextM1: number,
	nextBlock: number,
	nextDash: number,
	nextSideDash: number,
	ragdollToken: number,
	juggleUntil: number,
	awakenToken: number,
	lastDamaged: number,
	lastCombat: number,
	counter: Counter?,
	skillInputs: { [number]: number },
	skillInputAir: { [number]: boolean },
	skillHeld: { [number]: boolean },
	moveToken: number,
	grabbedBy: Model?,
}

export type HitInfo = {
	damage: number,
	stun: number,
	attackType: string?,
	guardBreak: boolean?,
	unblockable: boolean?,
	variant: string?,
	airborne: boolean?,
	velocity: Vector3?,
	velocityTime: number?,
	ragdoll: number?,
	hitsDowned: boolean?,
	noShake: boolean?,
	noReaction: boolean?,
	reflected: boolean?,
	heavy: boolean?,
	effect: string?,
}

export type Context = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	player: Player?,
	data: CharData,
	kit: Kits.KitInfo,
	awakened: boolean,
	airborne: boolean,
	combat: any,
}

local DASH_DIRECTIONS = { Front = true, Back = true, Left = true, Right = true }

local registry: { [Model]: CharData } = {}

local serverKits: { [string]: any } = {}
for _, module in script.Parent:WaitForChild("Kits"):GetChildren() do
	if module:IsA("ModuleScript") then
		serverKits[module.Name] = require(module) :: any
	end
end

local CombatService = {}

local function getRoot(character: Model): BasePart?
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(vector: Vector3): Vector3
	local v = Vector3.new(vector.X, 0, vector.Z)
	return if v.Magnitude > 1e-3 then v.Unit else Vector3.new(0, 0, -1)
end

local function addMeter(character: Model, attribute: string, amount: number, max: number)
	local current = tonumber(character:GetAttribute(attribute)) or 0
	local value = math.clamp(current + amount, 0, max)
	if value ~= current then
		character:SetAttribute(attribute, value)
	end
end

local function m1Value(character: Model, key: string): any
	local kit = Kits.Of(character)
	local override = kit and kit.m1[key]
	if override ~= nil then
		return override
	end
	return (Config.M1 :: any)[key]
end

local function awakeningOf(character: Model)
	local kit = Kits.Of(character)
	if not kit or not CombatState.IsAwakened(character) then
		return nil
	end
	if kit.ascension and character:GetAttribute("Ascended") == true then
		return kit.ascension
	end
	return kit.awakening
end

local function pendingAscension(character: Model)
	local kit = Kits.Of(character)
	if kit and kit.ascension and CombatState.IsAwakened(character) and character:GetAttribute("Ascended") ~= true then
		return kit.ascension
	end
	return nil
end

function CombatService.ChargeAscension(character: Model, amount: number)
	local ascension = pendingAscension(character)
	if ascension then
		addMeter(character, "Ascension", amount, ascension.charge)
	end
end

local function stateActive(character: Model, attribute: string): boolean
	return (tonumber(character:GetAttribute(attribute)) or 0) > os.clock()
end
CombatService.StateActive = stateActive

function CombatService.Flat(vector: Vector3): Vector3
	return flat(vector)
end

function CombatService.GetData(character: Model): CharData?
	return registry[character]
end

function CombatService.FireVFX(name: string, data: { [string]: any })
	Remotes.VFX:FireAllClients(name, data)
end

function CombatService.Shake(character: Model, intensity: number)
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		Remotes.CameraShake:FireClient(player, intensity)
	end
end

function CombatService.ShakeArea(position: Vector3, radius: number, intensity: number)
	for _, player in Players:GetPlayers() do
		local root = player.Character and getRoot(player.Character)
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < radius then
				Remotes.CameraShake:FireClient(player, intensity * (1 - distance / radius))
			end
		end
	end
end

function CombatService.Notify(character: Model, text: string, color: Color3?)
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		Remotes.Notify:FireClient(player, text, color)
	end
end

function CombatService.ApplyVelocity(
	character: Model,
	velocity: Vector3,
	duration: number,
	options: { steer: number?, landStop: boolean?, landKeep: number? }?
)
	local root = getRoot(character)
	if not root then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if Ragdoll.IsActive(character) then
		if duration > 0.05 and velocity.Magnitude <= Config.Physics.RagdollHoldSpeed then
			Impulse.Apply(root, velocity, duration, "Knockback", 0.45)
		else
			CombatService.Tumble(root, velocity)
		end
	elseif player then
		Remotes.Impulse:FireClient(player, velocity, duration, options)
	else
		Impulse.Apply(root, velocity, duration, "Knockback", if options then nil else 0.45)
	end
end

function CombatService.Tumble(root: BasePart, velocity: Vector3)
	local carry = Config.Physics.RagdollCarry
	local thrown = Vector3.new(velocity.X * carry, velocity.Y, velocity.Z * carry)
	local spin = Vector3.zero
	local across = Vector3.new(velocity.X, 0, velocity.Z):Cross(Vector3.yAxis)
	if across.Magnitude > 0.1 then
		spin = -across.Unit * math.min(velocity.Magnitude * Config.Physics.TumbleSpin, Config.Physics.MaxTumble)
	end
	local character = root.Parent
	if character then
		for _, part in character:GetChildren() do
			if part:IsA("BasePart") and not part.Anchored and part ~= root then
				part.AssemblyLinearVelocity = thrown + spin:Cross(part.Position - root.Position)
				part.AssemblyAngularVelocity = spin
			end
		end
	end
	root.AssemblyLinearVelocity = thrown
	root.AssemblyAngularVelocity = spin
end

function CombatService.Launch(victim: Model, velocity: Vector3, duration: number, hitStop: number?)
	local root = getRoot(victim)
	if not root then
		return
	end
	if not hitStop or hitStop <= 0 or not Ragdoll.IsActive(victim) then
		CombatService.ApplyVelocity(victim, velocity, duration)
		return
	end
	task.delay(hitStop, function()
		if root.Parent and Ragdoll.IsActive(victim) then
			CombatService.Tumble(root, velocity)
		end
	end)
end

function CombatService.HeavyFall(character: Model, multiplier: number, duration: number)
	local extra = workspace.Gravity * (multiplier - 1)
	if extra <= 0 then
		return
	end
	local forces: { Instance } = {}
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and not part.Massless then
			local attachment = Instance.new("Attachment")
			attachment.Name = "HeavyFall"
			attachment.Parent = part
			local force = Instance.new("VectorForce")
			force.Attachment0 = attachment
			force.RelativeTo = Enum.ActuatorRelativeTo.World
			force.ApplyAtCenterOfMass = true
			force.Force = Vector3.new(0, -extra * part:GetMass(), 0)
			force.Parent = attachment
			table.insert(forces, attachment)
		end
	end
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() - started < duration and Ragdoll.IsActive(character) then
			return
		end
		connection:Disconnect()
		for _, attachment in forces do
			attachment:Destroy()
		end
	end)
end

function CombatService.IsAirborne(character: Model): boolean
	local root = getRoot(character)
	if not root then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return workspace:Raycast(root.Position, Vector3.new(0, -3.6, 0), params) == nil
end

local function inAir(character: Model, clientSaysAirborne: boolean?): boolean
	if clientSaysAirborne ~= nil then
		return clientSaysAirborne
	end
	return CombatService.IsAirborne(character)
end

function CombatService.Ragdoll(character: Model, duration: number)
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

CombatService.Box = Hitbox.Box
CombatService.Sphere = Hitbox.Sphere

function CombatService.SetCounter(
	character: Model,
	duration: number,
	types: { [string]: boolean },
	onCounter: (attacker: Model, hit: HitInfo) -> (),
	filter: ((attacker: Model, hit: HitInfo) -> boolean)?
)
	local data = registry[character]
	if data then
		data.counter = { untilTime = os.clock() + duration, types = types, onCounter = onCounter, filter = filter }
	end
end

function CombatService.ClearCounter(character: Model)
	local data = registry[character]
	if data then
		data.counter = nil
	end
end

type SkillWatch = { radius: number, untilTime: number, onStart: (user: Model) -> () }
local skillWatchers: { [Model]: SkillWatch } = {}

function CombatService.WatchSkills(character: Model, radius: number, duration: number, onStart: (user: Model) -> ())
	skillWatchers[character] = { radius = radius, untilTime = os.clock() + duration, onStart = onStart }
end

function CombatService.StopWatchingSkills(character: Model)
	skillWatchers[character] = nil
end

local function notifySkillStart(user: Model)
	local userRoot = getRoot(user)
	if not userRoot then
		return
	end
	for watcher, watch in skillWatchers do
		local watcherRoot = getRoot(watcher)
		if os.clock() > watch.untilTime or not watcherRoot then
			skillWatchers[watcher] = nil
		elseif watcher ~= user and (watcherRoot.Position - userRoot.Position).Magnitude <= watch.radius then
			skillWatchers[watcher] = nil
			task.spawn(watch.onStart, user)
		end
	end
end

function CombatService.PressedAirborne(character: Model, slot: number): boolean
	local data = registry[character]
	return data ~= nil and data.skillInputAir[slot] == true
end

function CombatService.MoveToken(character: Model): number
	local data = registry[character]
	return if data then data.moveToken else -1
end

function CombatService.IsHeld(character: Model, slot: number): boolean
	local data = registry[character]
	return data ~= nil and data.skillHeld[slot] == true
end

function CombatService.PressedSince(character: Model, slot: number, since: number): boolean
	local data = registry[character]
	local pressed = data and data.skillInputs[slot]
	return pressed ~= nil and pressed >= since
end

function CombatService.Heal(character: Model, amount: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth)
	end
end

function CombatService.Grab(
	attacker: Model,
	victim: Model,
	offset: CFrame,
	maxTime: number,
	hand: string?
): (() -> (), (CFrame) -> ())
	local victimData = registry[victim]
	local victimRoot = getRoot(victim)
	local attackerRoot = getRoot(attacker)
	local humanoid = victimData and victimData.humanoid
	if not victimData or not victimRoot or not attackerRoot or not humanoid then
		return function() end, function() end
	end

	victimData.grabbedBy = attacker
	CombatState.SetBlocking(victim, false)
	CombatState.Stun(victim, maxTime + 0.2)
	local player = Players:GetPlayerFromCharacter(victim)
	if player then
		pcall(victimRoot.SetNetworkOwner, victimRoot, nil)
	end
	humanoid.PlatformStand = true
	CombatService.FireVFX("Grabbed", {
		victim = victim,
		attacker = attacker,
		offset = offset,
		duration = maxTime,
		hand = hand,
	})

	local released = false
	local connection
	local function release()
		if released then
			return
		end
		released = true
		connection:Disconnect()
		victimData.grabbedBy = nil
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
		if player and victimRoot.Parent and not Ragdoll.IsActive(victim) then
			pcall(victimRoot.SetNetworkOwner, victimRoot, player)
		end
		CombatService.FireVFX("GrabReleased", { victim = victim })
	end

	connection = RunService.Heartbeat:Connect(function()
		if not attackerRoot.Parent or not victimRoot.Parent or humanoid.Health <= 0 then
			release()
			return
		end
		victimRoot.AssemblyLinearVelocity = Vector3.zero
		victimRoot.CFrame = attackerRoot.CFrame * offset
	end)
	task.delay(maxTime, release)
	return release, function(newOffset: CFrame)
		offset = newOffset
	end
end

function CombatService.Cutscene(paths: { [Model]: (number) -> CFrame }, length: number): () -> ()
	type Held = { character: Model, root: BasePart, path: (number) -> CFrame, player: Player? }
	local held: { Held } = {}
	for character, path in paths do
		local root = getRoot(character)
		if root then
			root.Anchored = true
			table.insert(held, {
				character = character,
				root = root,
				path = path,
				player = Players:GetPlayerFromCharacter(character),
			})
		end
	end

	local start = os.clock()
	local stopped = false
	local connection
	local function stop()
		if stopped then
			return
		end
		stopped = true
		connection:Disconnect()
		for _, entry in held do
			local root = entry.root
			if root.Parent then
				root.Anchored = false
				root.AssemblyLinearVelocity = Vector3.zero
				if entry.player and not Ragdoll.IsActive(entry.character) then
					pcall(root.SetNetworkOwner, root, entry.player)
				end
			end
		end
	end
	connection = RunService.Heartbeat:Connect(function()
		local t = math.min(os.clock() - start, length)
		for _, entry in held do
			if entry.root.Parent then
				entry.root.CFrame = entry.path(t)
			end
		end
		if t >= length then
			stop()
		end
	end)
	return stop
end

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
		CombatService.FireVFX("Crater", { position = result.Position, small = true })
		CombatService.Shake(victim, 0.5)
		CombatService.Shake(attacker, 0.4)
	end)
end

function CombatService.Hit(attacker: Model, victim: Model, hit: HitInfo): string
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	local victimRoot = getRoot(victim)
	local attackerRoot = getRoot(attacker)
	if not humanoid or not victimRoot or not attackerRoot or humanoid.Health <= 0 then
		return "None"
	end
	local attackerData = registry[attacker]
	local victimData = registry[victim]
	local now = os.clock()
	local juggled = victimData ~= nil and now < victimData.juggleUntil and CombatService.IsAirborne(victim)
	if CombatState.HasIFrames(victim) or (CombatState.IsRagdolled(victim) and not juggled and not hit.hitsDowned) then
		return "Immune"
	end

	if attackerData then
		attackerData.lastCombat = now
	end
	if victimData then
		victimData.lastCombat = now
	end

	local attackType = hit.attackType or "Melee"
	local counter = victimData and victimData.counter
	if
		counter
		and now <= counter.untilTime
		and counter.types[attackType]
		and (not counter.filter or counter.filter(attacker, hit))
	then
		victimData.counter = nil
		task.spawn(counter.onCounter, attacker, hit)
		return "Countered"
	end

	local toAttacker = flat(attackerRoot.Position - victimRoot.Position)
	local look = flat(attackerRoot.CFrame.LookVector)
	local contact = victimRoot.Position + toAttacker * 1.2
	local clash = {
		position = contact,
		victim = victim,
		attacker = attacker,
		kit = attacker:GetAttribute("Kit"),
		victimKit = victim:GetAttribute("Kit"),
	}

	local facing = victimRoot.CFrame.LookVector:Dot(toAttacker) > Config.Block.FacingDot
	if CombatState.IsBlocking(victim) and facing and not hit.unblockable then
		local blockAge = CombatState.Now() - (tonumber(victim:GetAttribute("BlockStart")) or 0)

		local perfectReady = CombatState.Now() >= (tonumber(victim:GetAttribute("PerfectCD")) or 0)
		if blockAge <= Config.Block.PerfectWindow and perfectReady then
			victim:SetAttribute("PerfectCD", CombatState.Now() + Config.Block.PerfectCooldown)
			CombatState.Stun(attacker, Config.Block.ParryStun)
			CombatService.FireVFX("PerfectBlock", clash)
			CombatService.Shake(attacker, 0.6)
			CombatService.Shake(victim, 0.35)
			return "Parried"
		end

		if hit.guardBreak then
			CombatState.SetBlocking(victim, false)
			CombatState.Stun(victim, Config.Block.GuardBreakStun)
			CombatService.FireVFX("GuardBreak", clash)
			CombatService.Shake(attacker, 0.4)
			CombatService.Shake(victim, 0.6)
			return "GuardBreak"
		end

		CombatService.FireVFX("Block", clash)
		CombatService.ApplyVelocity(victim, -toAttacker * Config.Block.Pushback, 0.12)
		CombatService.Shake(victim, 0.12)
		return "Blocked"
	end

	local awakening = awakeningOf(attacker)
	local damage = hit.damage * (if awakening then awakening.damageMultiplier else 1)
	if stateActive(attacker, "PowerUntil") then
		damage *= Config.States.PowerMultiplier
	end
	if stateActive(attacker, "WeakUntil") then
		damage *= Config.States.WeakMultiplier
	end
	humanoid:TakeDamage(damage)
	CombatState.SetBlocking(victim, false)
	CombatState.Stun(victim, hit.stun)

	if victimData then
		victimData.lastDamaged = now
	end
	addMeter(victim, "Evasive", damage * Config.Evasive.GainPerDamage, Config.Evasive.Max)
	if not CombatState.IsAwakened(attacker) then
		addMeter(attacker, "Awakening", damage * Config.Awakening.GainPerDamageDealt, Config.Awakening.Max)
	else
		local ascension = pendingAscension(attacker)
		if ascension and not ascension.chargeByKit then
			addMeter(attacker, "Ascension", damage, ascension.charge)
		end
	end
	if not CombatState.IsAwakened(victim) then
		addMeter(victim, "Awakening", damage * Config.Awakening.GainPerDamageTaken, Config.Awakening.Max)
	end

	local variant = hit.variant
	local heavy = hit.heavy == true or (variant ~= nil and variant ~= "Normal")
	if victimData and (variant == "Knockback" or variant == "Downslam") then
		victimData.juggleUntil = 0
	end
	if variant == "Knockback" then
		CombatService.Ragdoll(victim, Config.Ragdoll.Duration)
		CombatService.Launch(
			victim,
			look * Config.M1.KnockbackForce + Vector3.new(0, Config.M1.KnockbackLift, 0),
			0.2,
			Config.Physics.HitStop
		)
	elseif variant == "Uppercut" then
		CombatService.Ragdoll(victim, Config.M1.UppercutRagdoll)
		if victimData then
			victimData.juggleUntil = now + Config.M1.JuggleTime
		end
		CombatService.Launch(victim, Vector3.new(0, Config.M1.UppercutForce, 0) + look * 5, 0.2, Config.Physics.HitStop)
		CombatService.HeavyFall(victim, Config.M1.UppercutGravity, Config.M1.UppercutRagdoll)
	elseif variant == "Downslam" then
		CombatService.Ragdoll(victim, Config.Ragdoll.Duration)
		CombatService.Launch(
			victim,
			look * 10 + Vector3.new(0, -Config.M1.DownslamForce, 0),
			0.2,
			Config.Physics.HitStop
		)
		scheduleCrater(victim, attacker)
	elseif variant == "Normal" then
		if juggled and victimData then
			CombatService.Ragdoll(victim, Config.M1.AirFloat + 0.9)
			victimData.juggleUntil = now + Config.M1.AirFloat + 0.6
		end
		if hit.airborne then
			local float = Vector3.new(0, 3, 0) + look * 3
			CombatService.ApplyVelocity(victim, float, Config.M1.AirFloat)
			CombatService.ApplyVelocity(attacker, float, Config.M1.AirFloat)
		else
			CombatService.ApplyVelocity(victim, look * Config.M1.Push, Config.M1.PushTime)
		end
	else
		if hit.ragdoll then
			CombatService.Ragdoll(victim, hit.ragdoll)
		end
		if hit.velocity then
			CombatService.Launch(
				victim,
				hit.velocity,
				hit.velocityTime or 0.2,
				if heavy then Config.Physics.HitStop else nil
			)
		end
	end

	CombatService.FireVFX(hit.effect or (if heavy then "HeavyHit" else "Hit"), {
		position = contact,
		direction = look,
		attacker = attacker,
		victim = victim,
		damage = math.floor(damage * 10 + 0.5) / 10,
		variant = variant,
		kit = attacker:GetAttribute("Kit"),
		hitConfirm = true,
		noReaction = hit.noReaction,
	})
	if not hit.noShake then
		CombatService.Shake(attacker, if heavy then 0.45 else 0.18)
		CombatService.Shake(victim, if heavy then 0.7 else 0.3)
	end
	return "Hit"
end

function CombatService.M1(character: Model, jump: boolean?, clientAirborne: boolean?, clientIndex: number?)
	local data = registry[character]
	if
		not data
		or not CombatState.CanAct(character)
		or CombatState.IsBlocking(character)
		or CombatState.IsCasting(character)
		or character:GetAttribute("SwordAway") == true
	then
		return
	end
	local t = os.clock()
	if t < data.nextM1 - Config.M1.InputTolerance then
		return
	end
	if t - data.lastM1 > Config.M1.ResetTime then
		data.combo = 0
	end

	data.combo += 1
	if clientIndex and clientIndex >= 1 and clientIndex <= Config.M1.ComboLength then
		data.combo = clientIndex
	end
	data.lastM1 = t
	local index = data.combo
	local finisher = index >= Config.M1.ComboLength
	local airborne = inAir(character, clientAirborne)

	local variant = "Normal"
	if finisher then
		data.combo = 0
		data.nextM1 = t + Config.M1.EndLag
		if airborne then
			variant = "Downslam"
		elseif jump then
			variant = "Uppercut"
			data.nextM1 = t + Config.M1.UppercutEndLag
		else
			variant = "Knockback"
		end
	else
		data.nextM1 = t + Config.M1.SwingCooldown
	end
	CombatState.SetBusy(
		character,
		if variant == "Uppercut"
			then Config.M1.UppercutJumpAfter + 0.05
			elseif finisher then Config.M1.FinisherBusy
			elseif index == Config.M1.ComboLength - 1 then Config.M1.DownslamJumpAfter
			else Config.M1.Busy
	)

	CombatService.FireVFX("Swing", {
		character = character,
		index = index,
		finisher = finisher,
		variant = variant,
	})

	task.delay(if finisher then m1Value(character, "FinisherWindUp") else m1Value(character, "WindUp"), function()
		if not CombatState.CanAct(character) then
			return
		end
		local root = getRoot(character)
		if not root then
			return
		end
		local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -m1Value(character, "HitboxOffset"))
		local hitboxSize = m1Value(character, "HitboxSize")
		if variant == "Downslam" then
			hitboxCFrame *= CFrame.new(0, -3.5, -0.5)
			hitboxSize += Vector3.new(1, 7, 1)
		end
		for _, victim in Hitbox.Box(character, hitboxCFrame, hitboxSize) do
			CombatService.Hit(character, victim, {
				damage = if finisher then m1Value(character, "FinisherDamage") else m1Value(character, "Damage"),
				stun = if variant == "Uppercut"
					then Config.M1.UppercutStun
					elseif index == Config.M1.ComboLength - 1 then Config.M1.SetupStun
					else Config.M1.HitStun,
				attackType = "Melee",
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
		if
			CombatState.IsBlocking(character)
			or not CombatState.CanAct(character)
			or CombatState.IsBusy(character)
			or CombatState.IsCasting(character)
		then
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

function CombatService.Dash(character: Model, direction: string): boolean
	local data = registry[character]
	if
		not data
		or not DASH_DIRECTIONS[direction]
		or not CombatState.CanAct(character)
		or CombatState.IsCasting(character)
	then
		return false
	end
	local t = os.clock()
	local side = direction == "Left" or direction == "Right"
	if t < (if side then data.nextSideDash else data.nextDash) - Config.Dash.Tolerance then
		return false
	end
	local awakening = awakeningOf(character)
	local multiplier = if awakening then awakening.cooldownMultiplier else 1
	if side then
		data.nextSideDash = t + Config.Dash.SideCooldown * multiplier
	else
		data.nextDash = t + Config.Dash.Cooldown * multiplier
	end
	CombatState.SetBlocking(character, false)
	return true
end

function CombatService.Evasive(character: Model): boolean
	local data = registry[character]
	if not data or not CombatState.IsAlive(character) then
		return false
	end
	if not (CombatState.IsStunned(character) or CombatState.IsRagdolled(character)) then
		return false
	end
	if (tonumber(character:GetAttribute("Evasive")) or 0) < Config.Evasive.Max then
		return false
	end

	data.ragdollToken += 1
	character:SetAttribute("Evasive", 0)
	Ragdoll.Disable(character, true)
	CombatState.ClearStun(character)
	CombatState.ClearCasting(character)
	CombatState.GiveIFrames(character, Config.Evasive.IFrames)

	local root = getRoot(character)
	if root then
		local back = -flat(root.CFrame.LookVector)
		CombatService.ApplyVelocity(character, back * Config.Evasive.Speed + Vector3.new(0, 8, 0), 0.2)
	end
	CombatService.FireVFX("Evasive", { character = character })
	return true
end

local function makeContext(character: Model, airborne: boolean?): Context?
	local data = registry[character]
	local kit = Kits.Of(character)
	local root = getRoot(character)
	if not data or not kit or not root then
		return nil
	end
	return {
		character = character,
		humanoid = data.humanoid,
		root = root,
		player = Players:GetPlayerFromCharacter(character),
		data = data,
		kit = kit,
		awakened = CombatState.IsAwakened(character),
		airborne = airborne == true,
		combat = CombatService,
	}
end

function CombatService.UseSkill(character: Model, slot: number, clientAirborne: boolean?)
	local ctx = makeContext(character, inAir(character, clientAirborne))
	if not ctx then
		return
	end
	local info = Kits.SkillsOf(character)[slot]
	local serverKit = serverKits[ctx.kit.id]
	local moveSet = serverKit and (if ctx.awakened then serverKit.AwakenedSkills else serverKit.Skills)
	local run = moveSet and moveSet[slot]
	if not info or not run then
		return
	end
	if CombatState.Cooldown(character, slot) > 0.1 then
		ctx.data.skillInputs[slot] = os.clock()
		ctx.data.skillInputAir[slot] = ctx.airborne
		return
	end
	if not CombatState.CanAct(character) or CombatState.IsCasting(character) then
		return
	end
	ctx.data.skillInputs[slot] = nil

	local awakening = awakeningOf(character)
	CombatState.StartCooldown(character, slot, info.cooldown * (if awakening then awakening.cooldownMultiplier else 1))
	CombatState.SetBlocking(character, false)
	ctx.data.moveToken += 1
	notifySkillStart(character)
	task.spawn(run, ctx)
end

function CombatService.UseSpecial(character: Model, clientAirborne: boolean?)
	local ctx = makeContext(character, inAir(character, clientAirborne))
	if not ctx then
		return
	end
	local serverKit = serverKits[ctx.kit.id]
	local awakenedSpecial = ctx.awakened and ctx.kit.awakenedSpecial ~= nil and serverKit and serverKit.AwakenedSpecial
	local info = if awakenedSpecial then ctx.kit.awakenedSpecial else ctx.kit.special
	local run = if awakenedSpecial then serverKit.AwakenedSpecial else serverKit and serverKit.Special
	if not info or not run then
		return
	end
	local slot = CombatState.SpecialSlot
	if CombatState.Cooldown(character, slot) > 0.1 then
		ctx.data.skillInputs[slot] = os.clock()
		ctx.data.skillInputAir[slot] = ctx.airborne
		return
	end
	if not CombatState.CanAct(character) or CombatState.IsCasting(character) then
		return
	end
	ctx.data.skillInputs[slot] = nil
	local awakening = awakeningOf(character)
	CombatState.StartCooldown(character, slot, info.cooldown * (if awakening then awakening.cooldownMultiplier else 1))
	CombatState.SetBlocking(character, false)
	ctx.data.moveToken += 1
	notifySkillStart(character)
	task.spawn(run, ctx)
end

local function infiniteAwakening(character: Model): boolean
	if not Config.PlayTest.InfiniteAwakening then
		return false
	end
	local player = Players:GetPlayerFromCharacter(character)
	return player ~= nil and player:GetAttribute("InfiniteAwakening") == true
end

local function endAwakening(character: Model)
	local data = registry[character]
	if data then
		data.awakenToken += 1
	end
	if CombatState.IsAwakened(character) then
		character:SetAttribute("Awakened", false)
		character:SetAttribute("Ascended", false)
		character:SetAttribute("Ascension", 0)
		CombatState.ResetCooldowns(character)
		local kit = Kits.Of(character)
		local serverKit = kit and serverKits[kit.id]
		local ctx = makeContext(character)
		if serverKit and serverKit.AwakenEnd and ctx then
			task.spawn(serverKit.AwakenEnd, ctx)
		end
	end
end

local function drainAwakening(character: Model, data: CharData, duration: number)
	data.awakenToken += 1
	local token = data.awakenToken
	character:SetAttribute("Awakening", Config.Awakening.Max)
	task.spawn(function()
		local start = os.clock()
		while data.awakenToken == token and registry[character] == data do
			if infiniteAwakening(character) then
				start = os.clock()
			end
			local remaining = 1 - (os.clock() - start) / duration
			if remaining <= 0 then
				character:SetAttribute("Awakening", 0)
				endAwakening(character)
				break
			end
			character:SetAttribute("Awakening", Config.Awakening.Max * remaining)
			task.wait(0.25)
		end
	end)
end

local function ascend(ctx: Context)
	local character, data = ctx.character, ctx.data
	local ascension = pendingAscension(character)
	local serverKit = serverKits[ctx.kit.id]
	if not ascension or not serverKit or not serverKit.Ascend then
		return
	end
	if not CombatState.CanAct(character) or CombatState.IsCasting(character) then
		return
	end
	if (tonumber(character:GetAttribute("Ascension")) or 0) < ascension.charge then
		return
	end
	character:SetAttribute("Ascended", true)
	character:SetAttribute("Ascension", 0)
	CombatState.ResetCooldowns(character)
	data.moveToken += 1
	drainAwakening(character, data, ascension.duration)
	task.spawn(serverKit.Ascend, ctx)
end

function CombatService.Awaken(character: Model)
	local ctx = makeContext(character)
	if not ctx then
		return
	end
	local awakening = ctx.kit.awakening
	local serverKit = serverKits[ctx.kit.id]
	if not awakening or not serverKit or not serverKit.Awaken then
		return
	end
	if CombatState.IsAwakened(character) then
		ascend(ctx)
		return
	end
	if not CombatState.CanAct(character) or CombatState.IsCasting(character) then
		return
	end
	if (tonumber(character:GetAttribute("Awakening")) or 0) < Config.Awakening.Max then
		return
	end

	local data = ctx.data
	character:SetAttribute("Awakened", true)
	character:SetAttribute("Ascension", 0)
	CombatState.ResetCooldowns(character)
	ctx.awakened = true
	data.moveToken += 1
	drainAwakening(character, data, awakening.duration)
	task.spawn(serverKit.Awaken, ctx)
end

function CombatService.EquipKit(character: Model, kitId: string)
	local oldId = character:GetAttribute("Kit")
	if type(oldId) == "string" and serverKits[oldId] and serverKits[oldId].Unequip then
		serverKits[oldId].Unequip(character)
	end
	endAwakening(character)
	character:SetAttribute("Awakening", 0)
	CombatState.ResetCooldowns(character)
	CombatState.ResetSpecial(character)
	CombatService.ClearCounter(character)

	local serverKit = serverKits[kitId]
	if serverKit and serverKit.Equip then
		serverKit.Equip(character)
	end
	character:SetAttribute("Kit", kitId)
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		player:SetAttribute("Kit", kitId)
	end
end

function CombatService.PlayEntrance(character: Model)
	task.delay(0.35, function()
		local ctx = makeContext(character)
		local serverKit = ctx and serverKits[ctx.kit.id]
		if ctx and serverKit and serverKit.Entrance and CombatState.IsAlive(character) then
			serverKit.Entrance(ctx)
		end
	end)
end

function CombatService.SelectKit(player: Player, kitId: string)
	local kit = Kits.Get(kitId)
	if not kit or not kit.playable then
		return
	end
	local character = player.Character
	local data = character and registry[character]
	if not character or not data or not CombatState.IsAlive(character) then
		player:SetAttribute("Kit", kitId)
		return
	end
	if
		os.clock() - data.lastCombat < Config.KitSwitchCombatLock
		or not CombatState.CanAct(character)
		or CombatState.IsCasting(character)
	then
		CombatService.Notify(character, "You can't switch characters in combat!", Color3.fromRGB(255, 90, 90))
		return
	end

	player:SetAttribute("Kit", kitId)
	CombatService.EquipKit(character, kitId)
	CombatService.FireVFX("KitSwitch", { character = character, kit = kitId })
	CombatService.PlayEntrance(character)
	CombatService.Notify(character, "Now playing: " .. kit.title, kit.color)
end

function CombatService.Register(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or registry[character] then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)

	CombatState.Setup(character)
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.UseJumpPower = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	local data: CharData = {
		humanoid = humanoid,
		combo = 0,
		lastM1 = 0,
		nextM1 = 0,
		nextBlock = 0,
		nextDash = 0,
		nextSideDash = 0,
		ragdollToken = 0,
		juggleUntil = 0,
		awakenToken = 0,
		lastDamaged = 0,
		lastCombat = 0,
		counter = nil,
		skillInputs = {},
		skillInputAir = {},
		skillHeld = {},
		moveToken = 0,
		grabbedBy = nil,
	}
	registry[character] = data

	humanoid.Died:Connect(function()
		data.ragdollToken += 1
		local owner = Players:GetPlayerFromCharacter(character)
		if owner then
			owner:SetAttribute("SavedAwakening", tonumber(character:GetAttribute("Awakening")) or 0)
			owner:SetAttribute("SavedAwakeningKit", character:GetAttribute("Kit"))
		end
		endAwakening(character)
		Ragdoll.Enable(character)
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			registry[character] = nil
			Ragdoll.Forget(character)
		end
	end)

	local player = Players:GetPlayerFromCharacter(character)
	if player then
		local waited = 0
		while character:GetAttribute("AvatarLoaded") ~= true and waited < 6 and character.Parent do
			waited += task.wait(0.1)
		end
		if not character.Parent then
			return
		end
		local kitId = player:GetAttribute("Kit")
		local kit = Kits.Get(if type(kitId) == "string" then kitId else nil)
		if not kit or not kit.playable then
			kitId = Kits.Default
			player:SetAttribute("Kit", kitId)
		end
		CombatService.EquipKit(character, kitId :: string)
		local saved = player:GetAttribute("SavedAwakening")
		if type(saved) == "number" and player:GetAttribute("SavedAwakeningKit") == kitId then
			character:SetAttribute("Awakening", math.clamp(saved, 0, Config.Awakening.Max))
		end
		player:SetAttribute("SavedAwakening", nil)
		player:SetAttribute("SavedAwakeningKit", nil)
		CombatService.PlayEntrance(character)
	end
end

local lastAirJump: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function onAction(player: Player, action: unknown, payload: unknown, extra: unknown)
	local function saysAirborne(value: unknown): boolean?
		if type(value) ~= "table" or type((value :: any).airborne) ~= "boolean" then
			return nil
		end
		return (value :: any).airborne
	end
	local character = player.Character
	if type(action) ~= "string" then
		return
	end
	if action == "SelectKit" then
		if type(payload) == "string" then
			CombatService.SelectKit(player, payload)
		end
		return
	end
	if action == "InfiniteAwakening" then
		if Config.PlayTest.InfiniteAwakening and type(payload) == "boolean" then
			player:SetAttribute("InfiniteAwakening", payload)
		end
		return
	end
	if not character or not registry[character] then
		return
	end

	if action == "M1" then
		local jump = type(payload) == "table" and (payload :: any).jump == true
		local index = if type(payload) == "table" and type((payload :: any).index) == "number"
			then math.floor((payload :: any).index)
			else nil
		CombatService.M1(character, jump, saysAirborne(payload), index)
	elseif action == "Block" then
		CombatService.SetBlock(character, payload == true)
	elseif action == "Dash" then
		if type(payload) == "string" and CombatService.Dash(character, payload) then
			for _, other in Players:GetPlayers() do
				if other ~= player then
					Remotes.VFX:FireClient(other, "Dash", { character = character, direction = payload })
				end
			end
		end
	elseif action == "AirJump" then
		local kit = Kits.Of(character)
		local now = os.clock()
		if kit and kit.airJumps and CombatState.IsAlive(character) and now - (lastAirJump[character] or 0) > 0.2 then
			lastAirJump[character] = now
			for _, other in Players:GetPlayers() do
				if other ~= player then
					Remotes.VFX:FireClient(other, "AirJump", { character = character })
				end
			end
		end
	elseif action == "Evasive" then
		CombatService.Evasive(character)
	elseif action == "Skill" then
		if type(payload) == "number" and payload >= 1 and payload <= CombatState.SkillSlots then
			registry[character].skillHeld[math.floor(payload)] = true
			CombatService.UseSkill(character, math.floor(payload), saysAirborne(extra))
		end
	elseif action == "SkillRelease" then
		if type(payload) == "number" and payload >= 1 and payload <= CombatState.SkillSlots then
			registry[character].skillHeld[math.floor(payload)] = nil
		end
	elseif action == "Special" then
		CombatService.UseSpecial(character, saysAirborne(payload))
	elseif action == "Awaken" then
		CombatService.Awaken(character)
	end
end

local function updateMovement()
	for character, data in registry do
		local humanoid = data.humanoid
		if humanoid.Health > 0 then
			local awakening = awakeningOf(character)
			local bonus = if awakening then awakening.speedBonus else 0
			local speed, jump = Config.Movement.WalkSpeed + bonus, Config.Movement.JumpHeight
			if CombatState.IsRagdolled(character) or character:GetAttribute("Rooted") == true then
				speed, jump = 0, 0
			elseif CombatState.IsStunned(character) then
				speed, jump = Config.Movement.StunnedSpeed, 0
			elseif CombatState.IsCasting(character) then
				speed, jump = Config.Movement.CastingSpeed, 0
			elseif CombatState.IsBlocking(character) then
				speed, jump = Config.Movement.BlockingSpeed, 0
			elseif CombatState.IsBusy(character) then
				speed, jump = Config.Movement.AttackingSpeed + bonus, 0
			end
			if stateActive(character, "SlowUntil") then
				speed *= Config.States.SlowMultiplier
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

	if Config.PlayTest.InfiniteAwakening then
		task.spawn(function()
			while true do
				for _, player in Players:GetPlayers() do
					local character = player.Character
					if character and registry[character] and infiniteAwakening(character) then
						if not CombatState.IsAwakened(character) then
							character:SetAttribute("Awakening", Config.Awakening.Max)
						end
						local ascension = pendingAscension(character)
						if ascension then
							character:SetAttribute("Ascension", ascension.charge)
						end
					end
				end
				task.wait(0.25)
			end
		end)
	end

	local lastVelocity: { [Model]: Vector3 } = {}
	local lastImpact: { [Model]: number } = {}
	local function detectImpacts()
		local now = os.clock()
		for character in registry do
			local root = getRoot(character)
			local data = registry[character]
			local juggling = data ~= nil and now < data.juggleUntil + 0.6
			if root and Ragdoll.IsActive(character) and not root.Anchored and not juggling then
				local velocity = root.AssemblyLinearVelocity
				local previous = lastVelocity[character]
				if
					previous
					and previous.Magnitude > Config.Physics.ImpactSpeed
					and (previous - velocity).Magnitude > previous.Magnitude * 0.5
					and now - (lastImpact[character] or 0) > 0.35
				then
					lastImpact[character] = now
					local strength = math.clamp(previous.Magnitude / 90, 0.3, 1)
					CombatService.FireVFX("BodyImpact", { position = root.Position, strength = strength })
					CombatService.ShakeArea(root.Position, 35, 0.3 * strength)
				end
				lastVelocity[character] = velocity
			else
				lastVelocity[character] = nil
			end
		end
		for character in lastImpact do
			if not registry[character] then
				lastImpact[character] = nil
			end
		end
	end

	local regenTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		updateMovement()
		detectImpacts()

		regenTimer += dt
		if regenTimer >= 0.25 then
			for character in registry do
				addMeter(character, "Evasive", Config.Evasive.RegenPerSecond * regenTimer, Config.Evasive.Max)
			end
			regenTimer = 0
		end
	end)
end

return CombatService
