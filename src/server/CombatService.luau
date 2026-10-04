--[[
	CombatService
	Server-authoritative combat: M1 strings, blocking, perfect blocks, guard
	breaks, dashes, ragdolls, Evasive, and the character kit layer (skills,
	cooldowns, counters, awakening, switching characters).

	Players and NPCs go through the same functions, so dummies fight with
	the real rules. Kit modules (Server/Kits/*) get this module through their
	context and use its public API to deal hits, move people and fire VFX.
]]

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
}

export type CharData = {
	humanoid: Humanoid,
	combo: number,
	lastM1: number,
	nextM1: number,
	nextBlock: number,
	nextDash: number,
	ragdollToken: number,
	juggleUntil: number, -- launched by an uppercut: can still be hit in the air until then
	awakenToken: number,
	lastDamaged: number, -- last time this character took damage
	lastCombat: number, -- last time it dealt or took a hit (blocks character switching)
	counter: Counter?,
	-- When each skill key was last pressed while already on cooldown. Lets a
	-- running skill read follow-up presses (timing inputs like Black Divider).
	skillInputs: { [number]: number },
	-- Whether that press was made in the air (the player's own client says).
	skillInputAir: { [number]: boolean },
	-- Bumped whenever a skill, special or awakening starts, so a move that
	-- listens for follow-ups (Anti-Magic Leap) knows another move took over.
	moveToken: number,
	grabbedBy: Model?,
}

export type HitInfo = {
	damage: number,
	stun: number,
	attackType: string?, -- "Melee" (default) | "Bolt" | "Explosion" | "Swarm" | "Zone"
	guardBreak: boolean?,
	unblockable: boolean?,
	variant: string?, -- M1 finishers: "Normal" | "Knockback" | "Uppercut" | "Downslam"
	airborne: boolean?, -- M1 hit while in the air
	velocity: Vector3?, -- knockback (world space)
	velocityTime: number?,
	ragdoll: number?, -- seconds of ragdoll
	heavy: boolean?, -- bigger hit effect
	effect: string?, -- VFX name to play instead of Hit / HeavyHit
}

-- Handed to kit skill functions.
export type Context = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	player: Player?,
	data: CharData,
	kit: Kits.KitInfo,
	awakened: boolean,
	-- In the air when the move was used (the player's own client says so,
	-- see onAction; the server's view of them is a ping behind).
	airborne: boolean,
	combat: any, -- this module
}

local DASH_DIRECTIONS = { Front = true, Back = true, Left = true, Right = true }

local registry: { [Model]: CharData } = {}

-- Server kit modules, by kit id.
local serverKits: { [string]: any } = {}
for _, module in script.Parent:WaitForChild("Kits"):GetChildren() do
	if module:IsA("ModuleScript") then
		serverKits[module.Name] = require(module) :: any
	end
end

local CombatService = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

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

-- Kit-specific M1 tuning, falling back to Config.M1.
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
	return if kit and CombatState.IsAwakened(character) then kit.awakening else nil
end

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

-- Shakes everyone's camera near a point, falling off with distance.
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

-- Moves a character, routing to whoever owns its physics.
-- `options.steer` (degrees per second) lets a player curve the push with
-- their camera / movement keys while it lasts (e.g. Bull Thrust).
-- `options.landStop`: a downward push (a dive) turns into a skid once the
-- player touches down, keeping `landKeep` of its speed.
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
		-- Server owns ragdolls, and a ragdoll has no Humanoid fighting the
		-- velocity. A gentle push (an air hit holding them up, the hang after
		-- an uppercut) holds the body there, still turning and limp; anything
		-- faster throws it.
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

-- Throws a ragdolled body: velocity plus a head-over-heels spin around the
-- axis across the direction of travel.
function CombatService.Tumble(root: BasePart, velocity: Vector3)
	local carry = Config.Physics.RagdollCarry
	local thrown = Vector3.new(velocity.X * carry, velocity.Y, velocity.Z * carry)
	local spin = Vector3.zero
	local across = Vector3.new(velocity.X, 0, velocity.Z):Cross(Vector3.yAxis)
	if across.Magnitude > 0.1 then
		spin = -across.Unit * math.min(velocity.Magnitude * Config.Physics.TumbleSpin, Config.Physics.MaxTumble)
	end
	-- The whole body flies, not just the torso: a ragdoll's limbs are their
	-- own assemblies, and launching the torso alone gets averaged out over
	-- the joints into a weak flop. Each part gets the velocity it would have
	-- if the body were turning as one piece.
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

-- Knockback for a hit. Ragdolled victims of heavy hits go limp for a split
-- second first (hit-stop), then fly. (Not by anchoring them: anchoring and
-- releasing a body mid-air restarts its physics replication, which every
-- screen sees as a hitch right as the launch starts.)
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

-- Heavier gravity on a ragdoll for `duration` (a multiplier on the world's):
-- a snappy launch that goes up fast and comes straight back down. Gone when
-- the time is up or the ragdoll ends.
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
	-- R6 stands with its root 3 studs up; a little more than that is air.
	return workspace:Raycast(root.Position, Vector3.new(0, -3.6, 0), params) == nil
end

-- In the air: for players, exactly what their own client says (their
-- physics are theirs; the server sees them a ping late both taking off and
-- landing). The server's raycast only decides for NPCs, which send nothing.
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

-- Characters in a box / sphere, excluding `attacker`.
CombatService.Box = Hitbox.Box
CombatService.Sphere = Hitbox.Sphere

-- While active, a hit of one of `types` on `character` calls onCounter
-- instead of landing.
function CombatService.SetCounter(
	character: Model,
	duration: number,
	types: { [string]: boolean },
	onCounter: (attacker: Model, hit: HitInfo) -> ()
)
	local data = registry[character]
	if data then
		data.counter = { untilTime = os.clock() + duration, types = types, onCounter = onCounter }
	end
end

function CombatService.ClearCounter(character: Model)
	local data = registry[character]
	if data then
		data.counter = nil
	end
end

-- Ki reading (Asta's Zetten): while watching, the first character within
-- `radius` of `character` to start a skill or special calls onStart with
-- them. Fires once, then stops.
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

-- True if `slot`'s key was pressed (while on cooldown) after `since`.
-- Whether the last on-cooldown press of `slot` was made in the air.
function CombatService.PressedAirborne(character: Model, slot: number): boolean
	local data = registry[character]
	return data ~= nil and data.skillInputAir[slot] == true
end

-- Changes whenever another skill, special or awakening starts.
function CombatService.MoveToken(character: Model): number
	local data = registry[character]
	return if data then data.moveToken else -1
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

--[[
	Grabs: the victim is pinned in front of the attacker (the server takes
	over its physics) until the returned release() is called or `maxTime`
	passes. `offset` is relative to the attacker's root. The victim is
	stunned for the whole grab.
]]
--[[
	Holds `victim` at `offset` from the attacker's root (server side: what
	hitboxes see) for up to `maxTime`. Every client draws them pinned to
	the attacker's `hand` part instead, playing their "Grabbed" struggle
	(see Client/Moves), so the hold looks solid at any ping. Returns
	release() and hold(newOffset) for moves that change grip mid-grab.
]]
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

--[[
	Cutscenes: holds characters on scripted paths. Each root is anchored and
	moved every frame to paths[character](t) until `length` (or stop()),
	then players get their physics back. Clients draw the same paths
	themselves for smoothness (see Shared/BlackMoon).
]]
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
		CombatService.FireVFX("Crater", { position = result.Position, small = true })
		CombatService.Shake(victim, 0.5)
		CombatService.Shake(attacker, 0.4)
	end)
end

---------------------------------------------------------------------------
-- Hits
---------------------------------------------------------------------------

--[[
	Lands (or fails to land) a hit. Returns what happened:
	"Hit" | "Blocked" | "Parried" | "GuardBreak" | "Countered" | "Immune" | "None"
]]
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
	-- No hitting people on the floor: stops infinites. A body still in the
	-- air from an uppercut can be hit for a moment, so the combo carries on.
	local juggled = victimData ~= nil and now < victimData.juggleUntil and CombatService.IsAirborne(victim)
	if CombatState.HasIFrames(victim) or (CombatState.IsRagdolled(victim) and not juggled) then
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
	if counter and now <= counter.untilTime and counter.types[attackType] then
		victimData.counter = nil
		task.spawn(counter.onCounter, attacker, hit)
		return "Countered"
	end

	local toAttacker = flat(attackerRoot.Position - victimRoot.Position)
	local look = flat(attackerRoot.CFrame.LookVector)
	local contact = victimRoot.Position + toAttacker * 1.2
	-- Whose weapons met, so clients can draw the right clash (sword sparks...).
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

		if blockAge <= Config.Block.PerfectWindow then
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

	-- The hit lands.
	local awakening = awakeningOf(attacker)
	local damage = hit.damage * (if awakening then awakening.damageMultiplier else 1)
	humanoid:TakeDamage(damage)
	CombatState.SetBlocking(victim, false)
	CombatState.Stun(victim, hit.stun)

	if victimData then
		victimData.lastDamaged = now
	end
	addMeter(victim, "Evasive", damage * Config.Evasive.GainPerDamage, Config.Evasive.Max)
	if not CombatState.IsAwakened(attacker) then
		addMeter(attacker, "Awakening", damage * Config.Awakening.GainPerDamageDealt, Config.Awakening.Max)
	end
	if not CombatState.IsAwakened(victim) then
		addMeter(victim, "Awakening", damage * Config.Awakening.GainPerDamageTaken, Config.Awakening.Max)
	end

	local variant = hit.variant
	local heavy = hit.heavy == true or (variant ~= nil and variant ~= "Normal")
	-- The finishers that knock them down end a juggle.
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
		-- Knocked off their feet and sent up tumbling, high and fast: about
		-- 10 studs on heavier gravity, so it snaps up and comes straight back
		-- down. They can still be hit on the way: jump after them.
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
			-- Kept up in the air (and limp) while the hits keep coming.
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
		-- Skill hits.
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
	})
	CombatService.Shake(attacker, if heavy then 0.45 else 0.18)
	CombatService.Shake(victim, if heavy then 0.7 else 0.3)
	return "Hit"
end

---------------------------------------------------------------------------
-- Core moves
---------------------------------------------------------------------------

-- One swing of the M1 string. `jump` = jump held, turns the finisher into an uppercut.
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
	-- Follow the player's own count of the string (the swing they see),
	-- so a click dropped on the way or a reset that landed differently
	-- here can't turn their uppercut into a normal hit and the next swing
	-- into a downslam. Swing timing is still enforced above.
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
		-- In the air the finisher is always the downslam (holding Space from
		-- the jump shouldn't turn it into an uppercut).
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
			then Config.M1.UppercutJumpAfter + 0.05 -- free to jump after them almost at once
			elseif finisher then Config.M1.FinisherBusy
			else Config.M1.Busy
	)

	CombatService.FireVFX("Swing", {
		character = character,
		index = index,
		finisher = finisher,
		variant = variant,
	})

	task.delay(if finisher then m1Value(character, "FinisherWindUp") else m1Value(character, "WindUp"), function()
		-- Getting hit during wind-up cancels the swing.
		if not CombatState.CanAct(character) then
			return
		end
		local root = getRoot(character)
		if not root then
			return
		end
		local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -m1Value(character, "HitboxOffset"))
		for _, victim in Hitbox.Box(character, hitboxCFrame, m1Value(character, "HitboxSize")) do
			CombatService.Hit(character, victim, {
				damage = if finisher then m1Value(character, "FinisherDamage") else m1Value(character, "Damage"),
				stun = if variant == "Uppercut" then Config.M1.UppercutStun else Config.M1.HitStun,
				attackType = "Melee",
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

-- Movement is client-side (the client owns its character), the server only
-- validates the cooldown and tells everyone else to draw the effect.
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
	if t < data.nextDash - Config.Dash.Tolerance then
		return false
	end
	local awakening = awakeningOf(character)
	data.nextDash = t + Config.Dash.Cooldown * (if awakening then awakening.cooldownMultiplier else 1)
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

---------------------------------------------------------------------------
-- Kits: skills, awakening, switching
---------------------------------------------------------------------------

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
	-- Small tolerance for clients whose clock/ping makes them a hair early.
	if CombatState.Cooldown(character, slot) > 0.1 then
		-- Pressing a key that's on cooldown can still matter to the skill
		-- that's running (e.g. timing the Black Divider).
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

-- The R special (Kits.special, run by the server kit's Special). Presses
-- while it's on cooldown are recorded like skill presses (PressedSince with
-- CombatState.SpecialSlot), so a special can have a follow-up.
function CombatService.UseSpecial(character: Model, clientAirborne: boolean?)
	local ctx = makeContext(character, inAir(character, clientAirborne))
	if not ctx then
		return
	end
	-- Awakened, a kit can have a different special (Asta swaps swords).
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

local function endAwakening(character: Model)
	local data = registry[character]
	if data then
		data.awakenToken += 1
	end
	if CombatState.IsAwakened(character) then
		character:SetAttribute("Awakened", false)
		CombatState.ResetCooldowns(character)
		local kit = Kits.Of(character)
		local serverKit = kit and serverKits[kit.id]
		local ctx = makeContext(character)
		if serverKit and serverKit.AwakenEnd and ctx then
			task.spawn(serverKit.AwakenEnd, ctx)
		end
	end
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
	if CombatState.IsAwakened(character) or not CombatState.CanAct(character) or CombatState.IsCasting(character) then
		return
	end
	if (tonumber(character:GetAttribute("Awakening")) or 0) < Config.Awakening.Max then
		return
	end

	local data = ctx.data
	data.awakenToken += 1
	local token = data.awakenToken
	character:SetAttribute("Awakened", true)
	CombatState.ResetCooldowns(character) -- fresh awakened move set
	ctx.awakened = true
	data.moveToken += 1
	task.spawn(serverKit.Awaken, ctx)

	-- The meter drains over the awakening's duration.
	task.spawn(function()
		local start = os.clock()
		while data.awakenToken == token and registry[character] == data do
			local remaining = 1 - (os.clock() - start) / awakening.duration
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

-- Puts `kitId` on a character: weapon model, fresh cooldowns, no awakening.
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

	-- Weapon first, then the attribute: clients react to "Kit" by animating
	-- the weapon, so it should already be there when they see the change.
	local serverKit = serverKits[kitId]
	if serverKit and serverKit.Equip then
		serverKit.Equip(character)
	end
	character:SetAttribute("Kit", kitId)
end

-- A kit's spawn entrance, if it has one. Slightly delayed so clients have
-- the freshly spawned character (and its weapon) before it starts.
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
		player:SetAttribute("Kit", kitId) -- applies on next spawn
		return
	end
	-- Same character again is allowed: it re-equips in place, which also
	-- repairs a missing weapon or a half-applied kit.
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

---------------------------------------------------------------------------
-- Registration and the main loop
---------------------------------------------------------------------------

function CombatService.Register(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or registry[character] then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)

	CombatState.Setup(character)
	humanoid.BreakJointsOnDeath = false
	humanoid.UseJumpPower = false
	-- Only our ragdoll should knock people over. (For players this has to be
	-- repeated on their client, see Input.)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	local data: CharData = {
		humanoid = humanoid,
		combo = 0,
		lastM1 = 0,
		nextM1 = 0,
		nextBlock = 0,
		nextDash = 0,
		ragdollToken = 0,
		juggleUntil = 0,
		awakenToken = 0,
		lastDamaged = 0,
		lastCombat = 0,
		counter = nil,
		skillInputs = {},
		skillInputAir = {},
		moveToken = 0,
		grabbedBy = nil,
	}
	registry[character] = data

	humanoid.Died:Connect(function()
		data.ragdollToken += 1 -- stop any pending get-up
		endAwakening(character)
		Ragdoll.Enable(character)
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			registry[character] = nil
			Ragdoll.Forget(character)
		end
	end)

	-- Players get their chosen character's kit. Dummies stay kit-less.
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		-- Wait for the avatar to be applied: it can replace the limbs a
		-- weapon would be welded to.
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
		CombatService.PlayEntrance(character)
	end
end

local function onAction(player: Player, action: unknown, payload: unknown, extra: unknown)
	-- Moves that have an air version say whether the player was in the air.
	-- nil when the client didn't say (the server's raycast decides then).
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
			-- The dasher already drew their own effect.
			for _, other in Players:GetPlayers() do
				if other ~= player then
					Remotes.VFX:FireClient(other, "Dash", { character = character, direction = payload })
				end
			end
		end
	elseif action == "Evasive" then
		CombatService.Evasive(character)
	elseif action == "Skill" then
		if type(payload) == "number" and payload >= 1 and payload <= CombatState.SkillSlots then
			CombatService.UseSkill(character, math.floor(payload), saysAirborne(extra))
		end
	elseif action == "Special" then
		CombatService.UseSpecial(character, saysAirborne(payload))
	elseif action == "Awaken" then
		CombatService.Awaken(character)
	end
end

-- Movement speed follows combat state every frame.
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

	-- Body impacts: a fast ragdoll that suddenly stops hit the floor or a wall.
	local lastVelocity: { [Model]: Vector3 } = {}
	local lastImpact: { [Model]: number } = {}
	local function detectImpacts()
		local now = os.clock()
		for character in registry do
			local root = getRoot(character)
			local data = registry[character]
			-- (Coming down from an uppercut is a soft landing, not a slam.)
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

		-- Attribute writes replicate, so the passive regen ticks 4 times a second.
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
