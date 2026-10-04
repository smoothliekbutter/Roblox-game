--[[
	Moves
	Plays move animations + their VFX on characters, routed to each
	character's kit (Client/Kits/<KitId>). Characters without a kit (the
	dummies) use the default fist M1s.

	Your own M1s play instantly when you click (predicted by Input), so they
	feel responsive at any ping. Everyone else's play when the server's
	"Swing" event arrives. Skills are driven by the server's "Skill" events.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Kits = require(ReplicatedStorage:WaitForChild("Shared").Kits)
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local M1Animations = require(script.Parent.M1Animations)
local PoseAnimator = require(script.Parent.PoseAnimator)
local Reactions = require(script.Parent.Reactions)
local VFX = require(script.Parent.VFX)

local localPlayer = Players.LocalPlayer

local TRAIL_TIME = 0.14

local clientKits: { [string]: any } = {}
for _, module in script.Parent:WaitForChild("Kits"):GetChildren() do
	if module:IsA("ModuleScript") then
		clientKits[module.Name] = require(module) :: any
	end
end

local Moves = {}

local function kitOf(character: Model): any
	local id = character:GetAttribute("Kit")
	return if type(id) == "string" then clientKits[id] else nil
end

-- Default M1s: punches and a kick.
local function playFistM1(character: Model, index: number, variant: string)
	local name = M1Animations.NameFor(index, variant)
	local animation = M1Animations.Clips[name]
	if not animation then
		return
	end
	local heavy = variant ~= "Normal"
	local strikers = M1Animations.Strikers[name] or {}

	PoseAnimator.Play(character, animation, function(event)
		if event == "Strike" then
			for _, limbName in strikers do
				VFX.LimbTrail(character, limbName, if heavy then TRAIL_TIME * 1.5 else TRAIL_TIME)
			end
			VFX.AirPop(character, heavy)
		end
	end)
end

function Moves.PlayM1(character: Model, index: number, variant: string)
	local kit = kitOf(character)
	if kit and kit.PlayM1 then
		kit.PlayM1(character, index, variant)
	else
		playFistM1(character, index, variant)
	end
end

---------------------------------------------------------------------------
-- Getting hit and blocking
---------------------------------------------------------------------------

-- A character's own reaction (Kit.Reactions) or the default one.
local function reactionFor(character: Model, name: string): PoseAnimator.Animation?
	local kit = kitOf(character)
	local own = kit and kit.Reactions and kit.Reactions[name]
	return own or Reactions[name]
end

local function asModel(value: unknown): Model?
	return if typeof(value) == "Instance" and value:IsA("Model") then value else nil
end

-- Characters being held in a grab (see pinGrab), by victim.
local grabs: { [Model]: { stop: () -> () } } = {}

local function react(character: Model, name: string)
	if character:GetAttribute("Ragdolled") == true then
		return -- the ragdoll is the reaction
	end
	if grabs[character] and name ~= "Grabbed" then
		return -- they keep struggling in the grip
	end
	local animation = reactionFor(character, name)
	if animation then
		PoseAnimator.Play(character, animation)
	end
end

local GUARD_ANIMS = { Guard = true, GuardHit = true }
local lastFlinchSide: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isGuardPlaying(character: Model): boolean
	local current = PoseAnimator.Current(character)
	if not current then
		return false
	end
	for name in GUARD_ANIMS do
		if current == reactionFor(character, name) then
			return true
		end
	end
	return false
end

local function onLandedHit(name: string, data)
	local victim = data.victim
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then
		return
	end
	if name == "HeavyHit" or name == "PerfectDivider" then
		react(victim, "HitHeavy")
		return
	end
	-- Hit from behind throws them forward; otherwise alternate sides.
	local victimRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attacker = data.attacker
	local attackerRoot = if typeof(attacker) == "Instance"
		then attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
		else nil
	if victimRoot and attackerRoot then
		local toAttacker = attackerRoot.Position - victimRoot.Position
		if victimRoot.CFrame.LookVector:Dot(Vector3.new(toAttacker.X, 0, toAttacker.Z).Unit) < -0.3 then
			react(victim, "FlinchBack")
			return
		end
	end
	local side = not lastFlinchSide[victim]
	lastFlinchSide[victim] = side
	react(victim, if side then "FlinchA" else "FlinchB")
end

--[[
	Grabs. The server holds the victim in place for hitboxes, but its
	position reaches us a ping late, which looks loose when the grabber is
	moving fast (Black Meteorite's rise and slam). So every client pins the
	victim to the grabber's hand itself, every frame: the hand's grip point
	is at their throat, facing the grabber, never sunk into the floor.
]]
local GRAB_NECK = 0.85 -- grip point to the victim's root
local GRAB_REACH = 0.6 -- the victim's root sits this far past the hand
local GRAB_FLOOR = 2.6 -- lowest the victim's root goes above the ground

local function pinGrab(data)
	local victim, attacker = asModel(data.victim), asModel(data.attacker)
	if not victim or not attacker then
		return
	end
	local victimRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not victimRoot or not attackerRoot then
		return
	end
	local existing = grabs[victim]
	if existing then
		existing.stop()
	end

	local offset: CFrame = if typeof(data.offset) == "CFrame" then data.offset else CFrame.new(0, 0, -3)
	local handName: string? = if type(data.hand) == "string" then data.hand else nil
	local duration = (tonumber(data.duration) or 2) + 0.3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { victim, attacker, VFX.Util.folder }
	local floorY: number? = nil
	local nextFloorCheck = 0
	local started = os.clock()

	local entry = {} :: { stop: () -> () }
	local connection
	entry.stop = function()
		if grabs[victim] ~= entry then
			return
		end
		grabs[victim] = nil
		connection:Disconnect()
		if PoseAnimator.Current(victim) == reactionFor(victim, "Grabbed") then
			PoseAnimator.FadeOut(victim, 0.2)
		end
	end
	grabs[victim] = entry

	connection = RunService.RenderStepped:Connect(function()
		if os.clock() - started > duration or not victimRoot.Parent or not attackerRoot.Parent then
			entry.stop()
			return
		end
		local target = attackerRoot.CFrame * offset
		local hand = if handName then attacker:FindFirstChild(handName) else nil
		if hand and hand:IsA("BasePart") then
			-- Hanging from the hand the way the grabber is the right way up:
			-- if he turns upside down (a head-first dive), so do they.
			local grip = (hand.CFrame * CFrame.new(0, -1, 0)).Position
			local up = attackerRoot.CFrame.UpVector
			local forward = attackerRoot.CFrame.LookVector
			local position = grip + forward * GRAB_REACH - up * GRAB_NECK
			target = CFrame.lookAt(position, position - forward, up)
		end
		local now = os.clock()
		if now >= nextFloorCheck then
			nextFloorCheck = now + 0.1
			local hit = workspace:Raycast(target.Position + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
			floorY = if hit then hit.Position.Y else nil
		end
		if floorY and target.Position.Y < floorY + GRAB_FLOOR then
			target += Vector3.new(0, floorY + GRAB_FLOOR - target.Position.Y, 0)
		end
		victimRoot.CFrame = target
	end)
	react(victim, "Grabbed")
end

-- Holding block shows the guard; letting go fades it out.
local function watchBlocking(character: Model)
	local function update()
		if character:GetAttribute("Blocking") == true then
			react(character, "Guard")
		elseif isGuardPlaying(character) then
			PoseAnimator.FadeOut(character, 0.15)
		end
	end
	character:GetAttributeChangedSignal("Blocking"):Connect(update)
	if character:GetAttribute("Blocking") == true then
		update()
	end
end

-- Kit stances and Black Form style looks follow the "Kit" and "Awakened"
-- attributes on every player.
local function watchCharacter(character: Model)
	-- The character can arrive before its joints have replicated.
	local torso = character:WaitForChild("Torso", 5)
	if torso then
		torso:WaitForChild("Right Shoulder", 5)
	end

	local function updateAwakened()
		local kit = kitOf(character)
		if kit and kit.SetAwakened then
			kit.SetAwakened(character, character:GetAttribute("Awakened") == true)
		end
	end
	local function updateKit()
		local kit = kitOf(character)
		PoseAnimator.SetIdle(character, if kit then kit.Idle else nil)
	end
	character:GetAttributeChangedSignal("Awakened"):Connect(updateAwakened)
	character:GetAttributeChangedSignal("Kit"):Connect(updateKit)
	updateAwakened()
	updateKit()
	watchBlocking(character)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

function Moves.Start()
	PoseAnimator.Start()

	-- Heavy hits: the attacker's swing also freezes for the hit-stop, so the
	-- impact feels like it connected.
	local HEAVY_EFFECTS = { HeavyHit = true, PerfectDivider = true }
	Remotes.VFX.OnClientEvent:Connect(function(name, data)
		if type(data) ~= "table" then
			return
		end
		if HEAVY_EFFECTS[name] and typeof(data.attacker) == "Instance" then
			PoseAnimator.Freeze(data.attacker :: Model, Config.Physics.HitStop)
		end

		if name == "Grabbed" then
			pinGrab(data)
			return
		elseif name == "GrabReleased" then
			local victim = asModel(data.victim)
			local grab = victim and grabs[victim]
			if grab then
				grab.stop()
			end
			return
		end

		-- Reactions on whoever got hit.
		if data.hitConfirm then
			onLandedHit(name, data)
		else
			local victim, attacker = asModel(data.victim), asModel(data.attacker)
			if name == "Block" and victim then
				react(victim, "GuardHit")
			elseif name == "GuardBreak" and victim then
				react(victim, "Stagger")
			elseif name == "PerfectBlock" and attacker then
				react(attacker, "Stagger")
			end
		end
	end)

	Remotes.VFX.OnClientEvent:Connect(function(name, data)
		if type(data) ~= "table" then
			return
		end
		local character = data.character
		if typeof(character) ~= "Instance" or not character:IsA("Model") then
			return
		end

		if name == "Swing" then
			-- Our own swing already played the moment we clicked.
			if character ~= localPlayer.Character then
				Moves.PlayM1(character, data.index or 1, data.variant or "Normal")
			end
		elseif name == "Skill" then
			local kit = if type(data.kit) == "string" then clientKits[data.kit] else nil
			if kit and kit.OnSkill then
				kit.OnSkill(data)
			end
		end
	end)

	-- Character switch: a flash in the new character's color.
	VFX.Register("KitSwitch", function(data)
		local character = data.character
		local kit = Kits.Get(data.kit)
		local root = VFX.Util.getRoot(character)
		if not root or not kit then
			return
		end
		VFX.Util.afterimage(character, kit.color, 0.5)
		VFX.Util.flash(root.Position, kit.color, 8, 0.3)
		VFX.Util.ringBurst(CFrame.new(root.Position - Vector3.new(0, 2.8, 0)), kit.color, 1, 8, 0.35, 0.25)
	end)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	-- Dummies block too.
	task.spawn(function()
		local dummies = workspace:WaitForChild("Dummies", 30)
		if dummies then
			dummies.ChildAdded:Connect(function(child)
				if child:IsA("Model") then
					watchBlocking(child)
				end
			end)
			for _, child in dummies:GetChildren() do
				if child:IsA("Model") then
					watchBlocking(child)
				end
			end
		end
	end)
end

return Moves
