--[[
	Anti-Magic Knight (Asta), server side.

	Built like Vessel (JJS) / Hero Hunter (TSB): a close-range rushdown
	character with a rush combo, a grab, a timing-based heavy and a counter.
	Awakening swaps to a whole new move set like Sukuna / Rampage Mode.

	Base
	  1 Bull Thrust         charge in sword-first; on contact, slash flurry into a launcher
	                        (in the air: dives diagonally down)
	  2 Black Meteorite     anti-magic lunge grab, carry them up, slam into a crater (unblockable)
	  3 Black Divider       charged cleave. Press 3 again on the red flash for a
	                        perfect Divider: huge damage, unblockable
	  4 Anti-Magic Deflect  counters EVERY attack type. Melee attackers get slashed
	                        aside, ranged attacks are sent back as a Black Slash
	Black Form (G)
	  1 Black Hurricane     spinning anti-magic charge that drags enemies along
	  2 Black Slash         piercing anti-magic slash wave
	  3 Grand Divider       massive cleave plus a giant slash wave (guard break)
	  4 Demon-Destroyer     grab, carve, then release all the absorbed magic. Heals 30%.

	All visuals are in StarterPlayerScripts.Client.Kits.AntiMagic, which gets
	("Skill", {skill, phase, ...}) events from here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatState = require(ReplicatedStorage:WaitForChild("Shared").CombatState)
local Projectile = require(script.Parent.Parent.Projectile)

local KIT_ID = "AntiMagic"
local UP = Vector3.yAxis

-- Anti-magic cuts through everything.
local ALL_TYPES = { Melee = true, Bolt = true, Explosion = true, Swarm = true, Zone = true }

local Kit = {}

---------------------------------------------------------------------------
-- Demon-Slayer Sword model
---------------------------------------------------------------------------

local function swordPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	className: string?
): BasePart
	local part = Instance.new(className or "Part") :: BasePart
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- The Demon-Slayer Sword: a broad black blade a bit taller than Asta, with
-- a chisel tip, a fuller down the middle, a worn grey edge and a chipped
-- spine. The blade runs along the handle's +Y axis; built around the
-- handle at the origin, then welded.
local function buildSword(): Model
	local model = Instance.new("Model")
	model.Name = "KitWeapon"

	local black = Color3.fromRGB(20, 20, 24)
	local fuller = Color3.fromRGB(38, 38, 44)
	local edge = Color3.fromRGB(110, 110, 120)
	local steel = Color3.fromRGB(58, 58, 66)
	local wrap = Color3.fromRGB(42, 31, 26)
	local metal, cloth = Enum.Material.Metal, Enum.Material.Fabric

	local handle = swordPart("Handle", Vector3.new(0.28, 0.95, 0.28), CFrame.new(), wrap, cloth)
	handle.Parent = model
	model.PrimaryPart = handle

	local band = Color3.fromRGB(26, 20, 18)
	local parts = {
		-- Grip: diamond pommel and wrap bands.
		swordPart(
			"Pommel",
			Vector3.new(0.3, 0.3, 0.3),
			CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(45)),
			steel,
			metal
		),
		swordPart("WrapA", Vector3.new(0.32, 0.06, 0.32), CFrame.new(0, -0.3, 0), band, cloth),
		swordPart("WrapB", Vector3.new(0.32, 0.06, 0.32), CFrame.new(0, 0.02, 0), band, cloth),
		swordPart("WrapC", Vector3.new(0.32, 0.06, 0.32), CFrame.new(0, 0.34, 0), band, cloth),
		-- Guard and collar.
		swordPart("Guard", Vector3.new(0.36, 0.22, 1.15), CFrame.new(0, 0.6, 0), steel, metal),
		swordPart("Collar", Vector3.new(0.24, 0.12, 0.78), CFrame.new(0, 0.76, 0), black, metal),
		-- Blade (0.82 to 4.42). The thin side faces forward so horizontal
		-- swings lead with the edge.
		swordPart("Blade", Vector3.new(0.18, 3.6, 1.05), CFrame.new(0, 2.62, 0), black, metal),
		swordPart("Fuller", Vector3.new(0.2, 2.9, 0.16), CFrame.new(0, 2.5, 0.09), fuller, Enum.Material.SmoothPlastic),
		swordPart("Edge", Vector3.new(0.13, 3.5, 0.09), CFrame.new(0, 2.62, -0.55), edge, metal),
		-- Chisel tip: a wedge sloping from the spine down to the edge.
		swordPart("Tip", Vector3.new(0.18, 0.7, 1.05), CFrame.new(0, 4.77, 0), black, metal, "WedgePart"),
		-- Chips along the spine.
		swordPart("ChipA", Vector3.new(0.2, 0.2, 0.12), CFrame.new(0, 1.8, 0.55), black, metal),
		swordPart("ChipB", Vector3.new(0.2, 0.16, 0.12), CFrame.new(0, 3.4, 0.55), black, metal),
	}
	-- Plain Welds with the offset written into C0, not WeldConstraints:
	-- a WeldConstraint works its offset out from where the parts happen to
	-- be when it switches on, which differs between the server (builds the
	-- sword) and the client (simulates the character), so pieces ended up
	-- floating off or falling. C0 replicates, so every machine agrees.
	for _, part in parts do
		local weld = Instance.new("Weld")
		weld.Name = "Join"
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = part.CFrame -- built relative to the handle at the origin
		weld.Parent = part
		part.Parent = model
	end

	-- Swing trail between the blade's base and tip. Clients switch it on during attacks.
	local blade = model:FindFirstChild("Blade") :: Part
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.Position = Vector3.new(0, -1.6, 0)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.Position = Vector3.new(0, 1.7, 0)
	tip.Parent = blade

	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = base
	trail.Attachment1 = tip
	-- Subtle: just enough to read the blade's path.
	trail.Color = ColorSequence.new(Color3.fromRGB(30, 30, 34), Color3.fromRGB(90, 90, 100))
	trail.Transparency = NumberSequence.new(0.55, 1)
	trail.LightEmission = 0
	trail.LightInfluence = 0
	trail.Lifetime = 0.12
	trail.MinLength = 0
	trail.Enabled = false
	trail.Parent = blade

	return model
end

function Kit.Equip(character: Model)
	character:WaitForChild("Right Arm", 5)
	local sword = buildSword()
	local handle = sword.PrimaryPart :: BasePart

	-- Held in the right hand, blade 35 degrees forward of the arm. A Motor6D
	-- rather than a Weld so clients can animate it like a wrist (resting the
	-- sword on the shoulder, angling it through swings).
	local weld = Instance.new("Motor6D")
	weld.Name = "SwordGrip"
	weld.Part1 = handle
	weld.Parent = handle

	local function currentArm(): BasePart?
		local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
		return if arm and arm:IsA("BasePart") then arm else nil
	end

	local function attach()
		local arm = currentArm()
		if not arm then
			return
		end
		local grip = CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(math.rad(215), 0, 0)
		-- Place the whole sword at the hand first, then join it.
		for _, part in sword:GetChildren() do
			if part:IsA("BasePart") then
				local join = part:FindFirstChild("Join") :: Weld?
				part.CFrame = arm.CFrame * grip * (if join then join.C0 else CFrame.identity)
			end
		end
		weld.Part0 = arm
		weld.C0 = grip
	end
	attach()
	sword.Parent = character

	-- Watchdog: if the arm gets rebuilt (avatar changes) or the grip breaks,
	-- re-grip instead of leaving the sword on the floor.
	task.spawn(function()
		local warned = false
		while sword.Parent == character and character.Parent do
			local arm = currentArm()
			if arm and (weld.Part0 ~= arm or not weld.Parent) then
				attach()
			elseif arm and (handle.Position - arm.Position).Magnitude > 6 then
				if not warned then
					warned = true
					warn("[AntiMagic] Sword drifted away from the hand, re-gripping.", character.Name)
				end
				attach()
			end
			task.wait(0.5)
		end
	end)
end

function Kit.Unequip(character: Model)
	local sword = character:FindFirstChild("KitWeapon")
	if sword then
		sword:Destroy()
	end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function fx(ctx, skill: string, phase: string, extra: { [string]: any }?)
	local data: { [string]: any } = { character = ctx.character, kit = KIT_ID, skill = skill, phase = phase }
	if extra then
		for key, value in extra do
			data[key] = value
		end
	end
	ctx.combat.FireVFX("Skill", data)
end

local function look(ctx): Vector3
	return ctx.combat.Flat(ctx.root.CFrame.LookVector)
end

-- Interrupted by getting hit, ragdolled or dying.
local function interrupted(ctx): boolean
	local character = ctx.character
	return not CombatState.IsAlive(character) or CombatState.IsStunned(character) or CombatState.IsRagdolled(character)
end

-- Charges forward for `duration`, returning the first character caught.
local function lunge(ctx, velocity: Vector3, duration: number, reach: Vector3): Model?
	ctx.combat.ApplyVelocity(ctx.character, velocity, duration)
	local start = os.clock()
	while os.clock() - start < duration + 0.05 do
		if interrupted(ctx) then
			return nil
		end
		local hits = ctx.combat.Box(ctx.character, ctx.root.CFrame * CFrame.new(0, 0, -reach.Z / 2), reach)
		if #hits > 0 then
			ctx.combat.ApplyVelocity(ctx.character, Vector3.zero, 0.05)
			return hits[1]
		end
		task.wait()
	end
	return nil
end

local function waitForGround(ctx, timeout: number)
	local start = os.clock()
	repeat
		task.wait()
	until not ctx.combat.IsAirborne(ctx.character) or os.clock() - start > timeout
end

local function groundBelow(ctx): Vector3
	return ctx.root.Position - Vector3.new(0, 3, 0)
end

-- Anti-magic slash wave. Used by Black Slash, Grand Divider and Deflect.
local function blackSlash(
	ctx,
	origin: Vector3,
	direction: Vector3,
	options: {
		damage: number,
		size: Vector3?,
		speed: number?,
		range: number?,
		grand: boolean?,
		skip: { [Model]: boolean }?,
	}
)
	local speed = options.speed or 130
	local range = options.range or 90
	local size = options.size or Vector3.new(9, 4, 2)
	fx(ctx, "BlackSlash", "Projectile", {
		origin = origin,
		direction = direction,
		speed = speed,
		range = range,
		width = size.X,
		grand = options.grand == true,
	})
	Projectile.Fire({
		owner = ctx.character,
		origin = origin,
		direction = direction,
		speed = speed,
		range = range,
		size = size,
		pierce = true,
		onHit = function(victim)
			if options.skip and options.skip[victim] then
				return
			end
			ctx.combat.Hit(ctx.character, victim, {
				damage = options.damage,
				stun = 0.9,
				attackType = "Bolt",
				heavy = true,
				guardBreak = options.grand == true,
				velocity = direction * 38 + UP * 14,
				velocityTime = 0.2,
				ragdoll = if options.grand then 1.4 else nil,
			})
		end,
	})
end

---------------------------------------------------------------------------
-- Base moves
---------------------------------------------------------------------------

-- Bull Thrust: propels himself forward on a burst of anti-magic, catches
-- the first person in the way and unloads a slash barrage, finishing with
-- a push that leaves them stunned in range so he can M1 straight into a
-- string (a combo starter, like Vessel's Cursed Strikes).
local BARRAGE_HITS = 8
local BARRAGE_STEP = 0.1 -- matches the Barrage animation (tools/anim)

local function bullThrust(ctx)
	local c, character = ctx.combat, ctx.character
	local forward = look(ctx)
	local airborne = c.IsAirborne(character)
	local direction = if airborne then (forward + UP * -0.6).Unit else forward

	CombatState.SetCasting(character, 0.6)
	fx(ctx, "BullThrust", "Propel", { airborne = airborne, direction = direction })
	local target = lunge(ctx, direction * 95, 0.32, Vector3.new(6, 6, 7))
	if not target then
		if airborne then
			waitForGround(ctx, 0.5)
			fx(ctx, "BullThrust", "Land", { position = groundBelow(ctx) })
		end
		fx(ctx, "BullThrust", "Whiff")
		CombatState.SetCasting(character, 0.3)
		return
	end

	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local contact = if targetRoot then targetRoot.Position else ctx.root.Position + forward * 3
	if c.Hit(character, target, { damage = 2.5, stun = 1.6, attackType = "Melee" }) ~= "Hit" then
		CombatState.SetCasting(character, 0.4)
		return
	end
	fx(ctx, "BullThrust", "Catch", { target = target, position = contact })

	-- The barrage: rapid slashes that keep them pinned in front of him.
	CombatState.SetCasting(character, BARRAGE_HITS * BARRAGE_STEP + 0.2)
	fx(ctx, "BullThrust", "Barrage", { target = target })
	for index = 1, BARRAGE_HITS do
		task.wait(BARRAGE_STEP)
		if interrupted(ctx) or not CombatState.IsAlive(target) then
			fx(ctx, "BullThrust", "Interrupted")
			return
		end
		c.Hit(character, target, {
			damage = 1,
			stun = 1,
			attackType = "Melee",
			velocity = forward * 6,
			velocityTime = BARRAGE_STEP,
		})
		c.ApplyVelocity(character, forward * 6, BARRAGE_STEP)
		fx(ctx, "BullThrust", "BarrageHit", { target = target, index = index })
	end

	-- Pushing thrust: shoves them back a few studs, still stunned, so an M1
	-- string connects right after.
	task.wait(0.12)
	if interrupted(ctx) then
		return
	end
	fx(ctx, "BullThrust", "Push", { target = target })
	c.Hit(character, target, {
		damage = 3,
		stun = 1.1,
		attackType = "Melee",
		velocity = forward * 22 + UP * 4,
		velocityTime = 0.15,
	})
	CombatState.ClearCasting(character)
	-- Start a fresh M1 string.
	ctx.data.combo = 0
	ctx.data.nextM1 = 0
end

-- Shared by Black Meteorite and Demon-Destroyer: lunge, and if someone is
-- caught (and not countering/immune), grab them.
local function lungeGrab(ctx, skill: string, grabTime: number): (Model?, (() -> ())?)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, 0.55)
	fx(ctx, skill, "Lunge")
	local target = lunge(ctx, look(ctx) * 72, 0.3, Vector3.new(4.5, 6, 5))
	if not target then
		CombatState.SetCasting(character, 0.35)
		return nil, nil
	end
	-- Grabs can't be blocked, but counters and i-frames still beat them.
	if c.Hit(character, target, { damage = 2, stun = 2, attackType = "Melee", unblockable = true }) ~= "Hit" then
		CombatState.SetCasting(character, 0.4)
		return nil, nil
	end
	CombatState.SetCasting(character, grabTime + 0.2)
	CombatState.GiveIFrames(character, grabTime)
	local release = c.Grab(character, target, CFrame.new(0, 0.3, -3.2), grabTime)
	return target, release
end

local function blackMeteorite(ctx)
	local c, character = ctx.combat, ctx.character
	local target, release = lungeGrab(ctx, "BlackMeteorite", 1.7)
	if not target or not release then
		return
	end
	local forward = look(ctx)

	fx(ctx, "BlackMeteorite", "Rise", { target = target })
	c.ApplyVelocity(character, UP * 75 + forward * 6, 0.3)
	task.wait(0.55)

	fx(ctx, "BlackMeteorite", "Slam", { target = target })
	c.ApplyVelocity(character, UP * -125 + forward * 8, 0.4)
	waitForGround(ctx, 0.6)
	release()

	-- The client draws its own (much bigger) crater for this one.
	local impact = groundBelow(ctx) + forward * 3
	fx(ctx, "BlackMeteorite", "Impact", { position = impact, target = target })
	c.ShakeArea(impact, 45, 0.6)
	c.Hit(character, target, {
		damage = 9,
		stun = 1,
		attackType = "Melee",
		unblockable = true,
		heavy = true,
		ragdoll = 1.6,
		velocity = forward * 25 + UP * 35,
	})
	CombatState.SetCasting(character, 0.3)
end

local DIVIDER_CHARGE = 0.62
local PERFECT_FROM, PERFECT_TO = 0.36, 0.66 -- generous for ping; client shows the flash at 0.38

local function blackDivider(ctx)
	local c, character = ctx.combat, ctx.character
	local data = ctx.data
	CombatState.SetCasting(character, DIVIDER_CHARGE + 0.45)

	local start = os.clock()
	fx(ctx, "BlackDivider", "Charge", { flashAt = 0.38 })

	-- Only the FIRST press after starting counts, so mashing doesn't work.
	local firstPress: number? = nil
	while os.clock() - start < DIVIDER_CHARGE do
		if interrupted(ctx) then
			fx(ctx, "BlackDivider", "Cancel")
			return
		end
		local pressed = data.skillInputs[3]
		if not firstPress and pressed and pressed > start then
			firstPress = pressed
		end
		task.wait()
	end
	local perfect = firstPress ~= nil and firstPress - start >= PERFECT_FROM and firstPress - start <= PERFECT_TO

	local forward = look(ctx)
	fx(ctx, "BlackDivider", "Release", { perfect = perfect })
	local box = ctx.root.CFrame * CFrame.new(0, 0, -4.5)
	for _, victim in c.Box(character, box, Vector3.new(9, 7, 9)) do
		if perfect then
			c.Hit(character, victim, {
				damage = 15,
				stun = 1.2,
				attackType = "Melee",
				unblockable = true,
				heavy = true,
				ragdoll = 1.8,
				velocity = forward * 85 + UP * 25,
				effect = "PerfectDivider",
			})
		else
			c.Hit(character, victim, {
				damage = 8,
				stun = 1,
				attackType = "Melee",
				guardBreak = true,
				heavy = true,
				ragdoll = 1.4,
				velocity = forward * 60 + UP * 18,
			})
		end
	end
	c.ShakeArea(ctx.root.Position, if perfect then 60 else 25, if perfect then 0.8 else 0.35)
	CombatState.SetCasting(character, 0.35)
end

local function antiMagicDeflect(ctx)
	local c, character = ctx.combat, ctx.character
	local countered = false
	CombatState.SetCasting(character, 0.9)
	fx(ctx, "Deflect", "Stance")

	c.SetCounter(character, 0.8, ALL_TYPES, function(attacker: Model)
		countered = true
		CombatState.GiveIFrames(character, 0.7)
		CombatState.SetCasting(character, 0.45)
		local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not attackerRoot then
			return
		end
		local offset = attackerRoot.Position - ctx.root.Position
		if offset.Magnitude <= 14 then
			-- Slash them aside, like Manji Kick.
			fx(ctx, "Deflect", "Counter", { target = attacker })
			c.Hit(character, attacker, {
				damage = 8,
				stun = 1.2,
				attackType = "Melee",
				unblockable = true,
				heavy = true,
				ragdoll = 1.4,
				velocity = ctx.root.CFrame.RightVector * 45 + UP * 22,
			})
		else
			-- Ranged attack: send it back as a Black Slash, like Prey's Peril.
			local direction = c.Flat(offset)
			fx(ctx, "Deflect", "Reflect", { direction = direction })
			blackSlash(ctx, ctx.root.Position + direction * 2 + UP * 0.5, direction, { damage = 7 })
		end
	end)

	task.wait(0.82)
	if not countered then
		c.ClearCounter(character)
		fx(ctx, "Deflect", "End")
		CombatState.SetCasting(character, 0.35)
	end
end

---------------------------------------------------------------------------
-- Black Form moves
---------------------------------------------------------------------------

local function blackHurricane(ctx)
	local c, character = ctx.combat, ctx.character
	local forward = look(ctx)
	CombatState.SetCasting(character, 1.15)
	fx(ctx, "BlackHurricane", "Spin", { duration = 0.9 })
	c.ApplyVelocity(character, forward * 55, 0.9)

	local caught: { [Model]: boolean } = {}
	for _ = 1, 9 do
		task.wait(0.1)
		if interrupted(ctx) then
			return
		end
		for _, victim in c.Sphere(character, ctx.root.Position, 7) do
			-- Dragged along at the same speed as the spin.
			if
				c.Hit(character, victim, {
					damage = 1.2,
					stun = 0.6,
					attackType = "Melee",
					velocity = forward * 55 + UP * 2,
					velocityTime = 0.12,
				}) == "Hit"
			then
				caught[victim] = true
			end
		end
	end

	fx(ctx, "BlackHurricane", "Finish")
	for victim in caught do
		if CombatState.IsAlive(victim) then
			c.Hit(character, victim, {
				damage = 5,
				stun = 1,
				attackType = "Melee",
				heavy = true,
				ragdoll = 1.4,
				velocity = forward * 45 + UP * 45,
			})
		end
	end
	CombatState.SetCasting(character, 0.3)
end

local function blackSlashMove(ctx)
	local character = ctx.character
	CombatState.SetCasting(character, 0.5)
	fx(ctx, "BlackSlash", "Windup")
	task.wait(0.22)
	if interrupted(ctx) then
		return
	end
	local forward = look(ctx)
	blackSlash(ctx, ctx.root.Position + forward * 2 + UP * 0.5, forward, { damage = 10 })
end

local function grandDivider(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, 1.3)
	fx(ctx, "GrandDivider", "Charge")
	task.wait(0.7)
	if interrupted(ctx) then
		fx(ctx, "GrandDivider", "Cancel")
		return
	end

	local forward = look(ctx)
	fx(ctx, "GrandDivider", "Release")
	local struck: { [Model]: boolean } = {}
	for _, victim in c.Box(character, ctx.root.CFrame * CFrame.new(0, 0, -5), Vector3.new(12, 9, 10)) do
		struck[victim] = true
		c.Hit(character, victim, {
			damage = 12,
			stun = 1.2,
			attackType = "Explosion",
			guardBreak = true,
			heavy = true,
			ragdoll = 1.6,
			velocity = forward * 70 + UP * 25,
		})
	end
	blackSlash(ctx, ctx.root.Position + forward * 4 + UP * 1, forward, {
		damage = 10,
		size = Vector3.new(18, 8, 3),
		speed = 95,
		range = 55,
		grand = true,
		skip = struck,
	})
	c.ShakeArea(ctx.root.Position, 70, 0.7)
	task.wait(0.3)
	CombatState.SetCasting(character, 0.3)
end

local function demonDestroyer(ctx)
	local c, character = ctx.combat, ctx.character
	local target, release = lungeGrab(ctx, "DemonDestroyer", 2.1)
	if not target or not release then
		return
	end

	fx(ctx, "DemonDestroyer", "Grab", { target = target })
	task.wait(0.25)
	for i = 1, 5 do
		if not CombatState.IsAlive(character) then
			release()
			return
		end
		fx(ctx, "DemonDestroyer", "Carve", { target = target, index = i })
		c.Hit(character, target, { damage = 2, stun = 1, attackType = "Melee", unblockable = true })
		task.wait(0.15)
	end

	fx(ctx, "DemonDestroyer", "Release", { target = target })
	task.wait(0.3)
	release()
	local forward = look(ctx)
	c.Hit(character, target, {
		damage = 12,
		stun = 1.2,
		attackType = "Melee",
		unblockable = true,
		heavy = true,
		ragdoll = 2,
		velocity = forward * 90 + UP * 30,
		effect = "PerfectDivider",
	})
	-- Like Hero Hunter's Final Hunt: the finisher restores health.
	c.Heal(character, ctx.humanoid.MaxHealth * 0.3)
	fx(ctx, "DemonDestroyer", "Heal")
	c.ShakeArea(ctx.root.Position, 70, 0.9)
	CombatState.SetCasting(character, 0.35)
end

-- Spawn entrance: the grimoire appears, he draws the sword from it, twirls
-- it and slams it into the ground. Untouchable and rooted while it plays;
-- the animation itself is client-side (Client/Kits/AntiMagic).
local ENTRANCE_TIME = 2.45

function Kit.Entrance(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, ENTRANCE_TIME)
	CombatState.GiveIFrames(character, ENTRANCE_TIME)
	character:SetAttribute("Rooted", true)
	fx(ctx, "Entrance", "Start")
	task.wait(1.7)
	if CombatState.IsAlive(character) then
		c.ShakeArea(ctx.root.Position, 35, 0.3)
	end
	task.wait(ENTRANCE_TIME - 1.7)
	character:SetAttribute("Rooted", false)
end

Kit.Skills = { bullThrust, blackMeteorite, blackDivider, antiMagicDeflect }
Kit.AwakenedSkills = { blackHurricane, blackSlashMove, grandDivider, demonDestroyer }

---------------------------------------------------------------------------
-- Awakening: Black Form (Devil Union)
---------------------------------------------------------------------------

-- Matches the client's Awaken animation (tools/anim): anti-magic gathers
-- while he crouches, bursts out on the roar at 0.92s, then he drops into
-- his Black Form stance. Rooted and untouchable the whole time.
local AWAKEN_BURST = 0.92
local AWAKEN_TIME = 2.0

function Kit.Awaken(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, AWAKEN_TIME)
	CombatState.GiveIFrames(character, AWAKEN_TIME + 0.1)
	character:SetAttribute("Rooted", true)
	fx(ctx, "Awaken", "Start")
	c.ShakeArea(ctx.root.Position, 40, 0.25)
	task.wait(AWAKEN_BURST)

	if CombatState.IsAlive(character) then
		fx(ctx, "Awaken", "Burst")
		c.ShakeArea(ctx.root.Position, 90, 0.9)
		-- The anti-magic burst blows everyone nearby away.
		for _, victim in c.Sphere(character, ctx.root.Position, 18) do
			local victimRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
			if victimRoot and not CombatState.HasIFrames(victim) and not CombatState.IsRagdolled(victim) then
				c.Ragdoll(victim, 1)
				c.ApplyVelocity(victim, c.Flat(victimRoot.Position - ctx.root.Position) * 65 + UP * 24, 0.2)
			end
		end
	end

	task.wait(AWAKEN_TIME - AWAKEN_BURST)
	if character.Parent then
		character:SetAttribute("Rooted", false)
	end
end

function Kit.AwakenEnd(ctx)
	fx(ctx, "Awaken", "End")
end

return Kit
