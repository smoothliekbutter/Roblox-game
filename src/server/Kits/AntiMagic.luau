--[[
	Anti-Magic Knight (Asta), server side.

	Built like Vessel (JJS) / Hero Hunter (TSB): a close-range rushdown
	character with a rush combo, a grab, a timing-based heavy and a counter.
	Awakening swaps to a whole new move set like Sukuna / Rampage Mode.

	Base
	  1 Bull Thrust         charge in sword-first; on contact, a five-hit sword combo
	                        ending in a thrust (in the air: dives diagonally down,
	                        and if it catches no one he slams the ground, guard break)
	  2 Black Meteorite     standing anti-magic grab (no dash), carry them up, slam into
	                        a crater (unblockable)
	  3 Black Divider       charged cleave. Press 3 again on the red flash for a
	                        perfect Divider: huge damage, unblockable
	  4 Anti-Magic Deflect  counters EVERY attack type. Melee attackers get slashed
	                        aside, ranged attacks are sent back as a Black Slash
	Black Form (G)
	  1 Black Hurricane     spinning anti-magic charge that drags enemies along
	  2 Black Slash         piercing anti-magic slash wave
	  3 Grand Divider       massive cleave plus a giant slash wave (guard break)
	  4 Black Moon          cutscene grab: hurls them into the sky, hangs in front
	                        of a giant moon, flies through them and cuts them down

	All visuals are in StarterPlayerScripts.Client.Kits.AntiMagic, which gets
	("Skill", {skill, phase, ...}) events from here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlackMoon = require(ReplicatedStorage:WaitForChild("Shared").BlackMoon)
local MeteorVortex = require(ReplicatedStorage:WaitForChild("Shared").MeteorVortex)
local CombatState = require(ReplicatedStorage:WaitForChild("Shared").CombatState)
local Projectile = require(script.Parent.Parent.Projectile)

local KIT_ID = "AntiMagic"
local UP = Vector3.yAxis

-- Anti-magic cuts through everything.
-- Holds a character in the air (a tiny upward velocity switches on the
-- vertical force, so gravity stops pulling).
local HOVER = Vector3.new(0, 0.05, 0)
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

-- The Demon-Slayer Sword, as in the series: a huge, broad black greatsword
-- (about as tall as Asta), battered and stained, with a chisel tip, a faint
-- ridge down the middle and worn edges; a thin bronze crossbar and a long
-- two-handed grip ending in a round pommel. The blade runs along the
-- handle's +Y axis; built around the handle at the origin, then welded.
-- (Only the look: hitboxes don't depend on it. The animation checker in
-- tools/anim/rig.py models the blade from 0.86 to the tip, keep in step.)
local function buildSword(): Model
	local model = Instance.new("Model")
	model.Name = "KitWeapon"

	local black = Color3.fromRGB(22, 22, 26)
	local ridge = Color3.fromRGB(44, 44, 52)
	local worn = Color3.fromRGB(64, 64, 72)
	local stain = Color3.fromRGB(46, 48, 56)
	local nick = Color3.fromRGB(14, 14, 16)
	local bronze = Color3.fromRGB(92, 70, 42)
	local darkBronze = Color3.fromRGB(52, 40, 28)
	local wrap = Color3.fromRGB(60, 44, 30)
	local band = Color3.fromRGB(34, 26, 20)
	local metal, cloth = Enum.Material.Metal, Enum.Material.Fabric

	local handle = swordPart("Handle", Vector3.new(0.28, 0.95, 0.28), CFrame.new(), wrap, cloth)
	handle.Parent = model
	model.PrimaryPart = handle

	local function flat(name: string, size: Vector3, y: number, z: number, tilt: number): BasePart
		-- A patch lying on both flats of the blade, turned `tilt` degrees.
		return swordPart(
			name,
			size,
			CFrame.new(0, y, z) * CFrame.Angles(math.rad(tilt), 0, 0),
			stain,
			Enum.Material.Slate
		)
	end

	local pommel = swordPart("Pommel", Vector3.new(0.32, 0.32, 0.32), CFrame.new(0, -0.92, 0), bronze, metal) :: Part
	pommel.Shape = Enum.PartType.Ball

	local parts = {
		-- Long two-handed grip, wrapped, with a round pommel.
		swordPart("GripLower", Vector3.new(0.26, 0.4, 0.26), CFrame.new(0, -0.67, 0), wrap, cloth),
		swordPart("WrapA", Vector3.new(0.3, 0.05, 0.3), CFrame.new(0, -0.76, 0), band, cloth),
		swordPart("WrapB", Vector3.new(0.3, 0.05, 0.3), CFrame.new(0, -0.5, 0), band, cloth),
		swordPart("WrapC", Vector3.new(0.32, 0.05, 0.32), CFrame.new(0, -0.15, 0), band, cloth),
		swordPart("WrapD", Vector3.new(0.32, 0.05, 0.32), CFrame.new(0, 0.2, 0), band, cloth),
		pommel,
		-- Thin crossbar, a little wider than the blade, capped at the ends.
		swordPart("Guard", Vector3.new(0.2, 0.15, 1.8), CFrame.new(0, 0.6, 0), bronze, metal),
		swordPart("GuardCapA", Vector3.new(0.24, 0.22, 0.12), CFrame.new(0, 0.6, 0.94), darkBronze, metal),
		swordPart("GuardCapB", Vector3.new(0.24, 0.22, 0.12), CFrame.new(0, 0.6, -0.94), darkBronze, metal),
		swordPart("Collar", Vector3.new(0.26, 0.2, 0.72), CFrame.new(0, 0.77, 0), darkBronze, metal),
		-- The blade: full width right up to the guard (from 0.86), and cut off
		-- in one long straight slant across its whole width, from 4.3 on one
		-- edge to the point at 5.8 on the other. The thin side faces forward
		-- so swings lead with an edge.
		swordPart("Blade", Vector3.new(0.2, 3.44, 1.4), CFrame.new(0, 2.58, 0), black, metal),
		swordPart("Tip", Vector3.new(0.2, 1.5, 1.4), CFrame.new(0, 5.05, 0), black, metal, "WedgePart"),
		swordPart("Ridge", Vector3.new(0.22, 3.7, 0.12), CFrame.new(0, 2.85, 0), ridge, Enum.Material.SmoothPlastic),
		-- Worn edges: the short one stops at the cut, the long one runs on
		-- to the point, and a worn bevel runs along the cut itself.
		swordPart("EdgeA", Vector3.new(0.14, 3.37, 0.08), CFrame.new(0, 2.615, -0.69), worn, metal),
		swordPart("EdgeB", Vector3.new(0.14, 4.87, 0.08), CFrame.new(0, 3.365, 0.69), worn, metal),
		swordPart(
			"CutEdge",
			Vector3.new(0.22, 0.1, 2.05),
			CFrame.new(0, 5.016, 0.037) * CFrame.Angles(math.rad(-46.97), 0, 0),
			worn,
			metal
		),
		-- Stains and scars across the flats.
		flat("StainA", Vector3.new(0.215, 0.9, 0.45), 1.7, 0.25, 20),
		flat("StainB", Vector3.new(0.215, 0.6, 0.35), 2.6, -0.3, -15),
		flat("StainC", Vector3.new(0.215, 1.1, 0.4), 3.6, 0.2, 10),
		flat("StainD", Vector3.new(0.215, 0.5, 0.3), 4.1, 0.25, 30),
		-- Nicks along the edges.
		swordPart("NickA", Vector3.new(0.16, 0.22, 0.1), CFrame.new(0, 1.9, -0.66), nick, metal),
		swordPart("NickB", Vector3.new(0.16, 0.16, 0.1), CFrame.new(0, 3.2, 0.66), nick, metal),
		swordPart("NickC", Vector3.new(0.16, 0.26, 0.1), CFrame.new(0, 3.9, -0.66), nick, metal),
		swordPart("NickD", Vector3.new(0.16, 0.18, 0.1), CFrame.new(0, 2.5, 0.66), nick, metal),
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
	-- Where the guard and the business end are, along the blade, for the
	-- clients' effects (see alongBlade in the client kit).
	blade:SetAttribute("GuardY", -1.72)
	blade:SetAttribute("TipY", 2.77)
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.Position = Vector3.new(0, -1.49, 0)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.Position = Vector3.new(0, 2.31, 0)
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

-- How long the server (a ping behind) gets to see a dive leave the ground.
-- If it never does (a dive from a tiny hop), being on the ground after
-- this counts as having landed.
local TAKEOFF_GRACE = 0.25

-- Charges forward for `duration`, returning the first character caught.
-- With `steer` (degrees per second) the player can curve it as it goes; the
-- hitbox follows their root, so it catches whatever they curve into.
-- A downward lunge (an air version) skids along the ground once it lands
-- instead of pushing into it (the player's client handles that: landStop).
-- With `untilLanded` it stops dead where it lands instead, and ends right
-- there; the second result says it landed.
local function lunge(
	ctx,
	velocity: Vector3,
	duration: number,
	reach: Vector3,
	steer: number?,
	untilLanded: boolean?
): (Model?, boolean)
	local options = if steer or velocity.Y < 0
		then { steer = steer, landStop = velocity.Y < 0, landKeep = if untilLanded then 0 else 0.7 }
		else nil
	ctx.combat.ApplyVelocity(ctx.character, velocity, duration, options)
	local start = os.clock()
	local seenAir = false
	while os.clock() - start < duration + 0.05 do
		if interrupted(ctx) then
			return nil, false
		end
		local hits = ctx.combat.Box(ctx.character, ctx.root.CFrame * CFrame.new(0, 0, -reach.Z / 2), reach)
		if #hits > 0 then
			ctx.combat.ApplyVelocity(ctx.character, Vector3.zero, 0.05)
			return hits[1], false
		end
		if untilLanded then
			local up = ctx.combat.IsAirborne(ctx.character)
			seenAir = seenAir or up
			if not up and (seenAir or os.clock() - start > TAKEOFF_GRACE) then
				return nil, true
			end
		end
		task.wait()
	end
	return nil, false
end

-- The server sees a player's own movement about a ping late: wait (with a
-- limit) until it has seen them leave the ground before treating "not
-- airborne" as having landed.
local function waitForTakeoff(ctx, timeout: number)
	local start = os.clock()
	while not ctx.combat.IsAirborne(ctx.character) and os.clock() - start < timeout do
		if interrupted(ctx) then
			return
		end
		task.wait()
	end
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
-- the first person in the way and cuts them up in a five-hit combo, the
-- last a thrust that leaves them stunned in range so he can M1 straight
-- into a string (a combo starter, like Vessel's Cursed Strikes).
local PROPEL_SPEED = 85
local PROPEL_TIME = 0.55 -- the Propel animation holds for this long
local PROPEL_STEER = 200 -- degrees per second: up to a ~110 degree curve

-- The combo. Each hit lands on its strike key in the BullCombo animation
-- (COMBO_STRIKES in tools/anim/asta_anims.py), so keep `at` in step with
-- it. Until the next hit they're held `reach` studs in front of him while
-- he steps on at `drift` studs per second.
local COMBO = {
	{ kind = "Rising", at = 0.14, damage = 1.5, reach = 3.8, drift = 5 },
	{ kind = "Sweep", at = 0.3, damage = 1.5, reach = 3.8, drift = 3 },
	{ kind = "Spin", at = 0.54, damage = 1.5, reach = 3.8, drift = 3 },
	-- Knocked back a step, clear of the point while he coils for the thrust.
	{ kind = "Chop", at = 0.76, damage = 2, reach = 4.6, drift = 0 },
	-- The finisher: nothing holds them after it (see THRUST_PUSH).
	{ kind = "Thrust", at = 1.1, damage = 3, reach = 0, drift = 0 },
}
-- The thrust drives them back about 2.5 studs, still stunned: an M1 still
-- reaches them.
local THRUST_PUSH = 17
local MAX_PULL = 30 -- fastest (studs per second) they're eased back in front of him

-- The air version, when the dive catches no one: he drives the sword into
-- the ground where he lands and the blast breaks guards all around him.
local SLAM_RADIUS = 11
local SLAM_DAMAGE = 6
local SLAM_RECOVERY = 0.45 -- the PlungeImpact stab he lands in
-- Still falling when the propel runs out (dove from high up): how long he
-- has to reach the ground for the slam to happen.
local LAND_WINDOW = 0.5

-- How fast to move someone so that `time` from now they're `reach` studs in
-- front of him, while he steps on at `drift`. Flat, so gravity still works.
local function holdInFront(ctx, target: Model, forward: Vector3, reach: number, drift: number, time: number): Vector3
	local velocity = forward * drift
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if targetRoot then
		local offset = ctx.root.Position + forward * reach - targetRoot.Position
		local pull = Vector3.new(offset.X, 0, offset.Z) / time
		if pull.Magnitude > MAX_PULL then
			pull = pull.Unit * MAX_PULL
		end
		velocity += pull
	end
	return velocity
end

-- True once he's on the ground, within `timeout`.
local function landsWithin(ctx, timeout: number): boolean
	local start = os.clock()
	while os.clock() - start < timeout do
		if interrupted(ctx) then
			return false
		end
		if not ctx.combat.IsAirborne(ctx.character) then
			return true
		end
		task.wait()
	end
	return false
end

-- The air version's landing: the sword goes into the ground and anti-magic
-- blows a crater out around him, throwing everyone in it up and away.
local function bullSlam(ctx)
	local c, character = ctx.combat, ctx.character
	local forward = look(ctx)
	c.ApplyVelocity(character, Vector3.zero, 0.05)
	-- Where the blade bites, just in front of his feet.
	local impact = groundBelow(ctx) + forward * 1.5
	local victims = c.Sphere(character, impact + UP * 2, SLAM_RADIUS)
	fx(ctx, "BullThrust", "Land", { position = impact, targets = victims })
	c.ShakeArea(impact, 45, 0.55)
	for _, victim in victims do
		local victimRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
		if victimRoot then
			local away = victimRoot.Position - impact
			local out = if Vector3.new(away.X, 0, away.Z).Magnitude > 0.5 then c.Flat(away) else forward
			c.Hit(character, victim, {
				damage = SLAM_DAMAGE,
				stun = 1,
				attackType = "Melee",
				guardBreak = true,
				heavy = true,
				ragdoll = 1,
				velocity = out * 40 + UP * 38,
			})
		end
	end
	CombatState.SetCasting(character, SLAM_RECOVERY)
end

local function bullThrust(ctx)
	local c, character = ctx.combat, ctx.character
	local forward = look(ctx)
	local airborne = ctx.airborne
	local direction = if airborne then (forward + UP * -0.6).Unit else forward

	CombatState.SetCasting(character, PROPEL_TIME + 0.25)
	fx(ctx, "BullThrust", "Propel", { airborne = airborne, direction = direction, duration = PROPEL_TIME })
	-- The air version ends the moment it lands (the slam replaces the skid).
	local target, landed =
		lunge(ctx, direction * PROPEL_SPEED, PROPEL_TIME, Vector3.new(6, 6, 7), PROPEL_STEER, airborne)
	if not target then
		-- Dove from high up: still falling when the propel runs out.
		if airborne and not landed and not interrupted(ctx) then
			CombatState.SetCasting(character, LAND_WINDOW + 0.1)
			landed = landsWithin(ctx, LAND_WINDOW)
		end
		if landed and not interrupted(ctx) then
			bullSlam(ctx)
			return
		end
		fx(ctx, "BullThrust", "Whiff")
		-- Whiffing it leaves him open.
		CombatState.SetCasting(character, 0.45)
		return
	end

	-- Wherever they curved to is forward now.
	forward = look(ctx)
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local contact = if targetRoot then targetRoot.Position else ctx.root.Position + forward * 3
	if c.Hit(character, target, { damage = 2, stun = 1.6, attackType = "Melee" }) ~= "Hit" then
		CombatState.SetCasting(character, 0.4)
		return
	end
	fx(ctx, "BullThrust", "Catch", { target = target, position = contact })

	-- The combo: five hits, each on its own swing, with them held in front
	-- of him the whole way.
	CombatState.SetCasting(character, COMBO[#COMBO].at + 0.2)
	fx(ctx, "BullThrust", "Combo", { target = target })
	local first = COMBO[1]
	c.ApplyVelocity(target, holdInFront(ctx, target, forward, first.reach, 0, first.at), first.at)
	c.ApplyVelocity(character, Vector3.zero, first.at)
	local start = os.clock()
	for index, cut in COMBO do
		-- Timed from the start so the waits don't add up and fall behind the animation.
		local remaining = cut.at - (os.clock() - start)
		if remaining > 0 then
			task.wait(remaining)
		end
		if interrupted(ctx) or not CombatState.IsAlive(target) then
			fx(ctx, "BullThrust", "Interrupted")
			CombatState.SetCasting(character, 0.3)
			return
		end
		local nextCut = COMBO[index + 1]
		local hit: { [string]: any } = { damage = cut.damage, stun = 1, attackType = "Melee" }
		if nextCut then
			hit.velocity = holdInFront(ctx, target, forward, cut.reach, cut.drift, nextCut.at - cut.at)
			hit.velocityTime = nextCut.at - cut.at
		else
			-- The thrust: drives them back, still stunned, so an M1 string
			-- connects right after.
			hit.stun = 1.1
			hit.heavy = true
			hit.velocity = forward * THRUST_PUSH + UP * 4
			hit.velocityTime = 0.15
		end
		if c.Hit(character, target, hit) ~= "Hit" then
			-- They broke out (Evasive) or can't be hit any more.
			fx(ctx, "BullThrust", "Interrupted")
			CombatState.SetCasting(character, 0.3)
			return
		end
		fx(ctx, "BullThrust", "Strike", { target = target, index = index, kind = cut.kind })
		if nextCut then
			c.ApplyVelocity(character, forward * cut.drift, nextCut.at - cut.at)
		end
	end
	CombatState.ClearCasting(character)
	-- Start a fresh M1 string.
	ctx.data.combo = 0
	ctx.data.nextM1 = 0
end

-- Where his free (left) hand holds a grabbed victim, in root space and
-- facing him, roughly matching the animations (tools/anim). This is what
-- the server's hitboxes see; every client pins them to the actual hand.
local FACING = CFrame.Angles(0, math.pi, 0)
local HOLD_SEIZE = CFrame.new(-1.6, 0.35, -1.75) * FACING
-- Kept level with him server-side so they never end up under the floor on
-- landing; clients show them driven down in front of him.
-- In the head-first dive: out in front of his face, upside down like him.
local HOLD_DRILL = CFrame.new(-0.6, 0.6, -2.4) * FACING
-- Held out at arm's length while he spins them round.
local HOLD_SPIN = CFrame.new(-1.7, 0.5, -2.3) * FACING

-- Seizes `target` by the throat with his free hand. Grabs can't be
-- blocked, but counters and i-frames still beat them, and leave him open
-- for a moment. Returns release() and hold() when it lands.
local function seize(ctx, target: Model, grabTime: number): ((() -> ())?, ((CFrame) -> ())?)
	local c, character = ctx.combat, ctx.character
	if c.Hit(character, target, { damage = 1, stun = 2, attackType = "Melee", unblockable = true }) ~= "Hit" then
		CombatState.SetCasting(character, 0.5)
		return nil, nil
	end
	CombatState.SetCasting(character, grabTime + 0.2)
	CombatState.GiveIFrames(character, grabTime)
	return c.Grab(character, target, HOLD_SEIZE, grabTime, "Left Arm")
end

-- The grab (Black Meteorite and Black Moon): no dash. He plants (in the air he hangs there)
-- and his free hand shoots out. At full stretch it seizes whoever is right
-- in front of him, for a moment. The startup is the MeteorReach
-- animation's thrust (REACH_AT in tools/anim/asta_anims.py): keep them in
-- step.
local REACH_STARTUP = 0.16
local REACH_WINDOW = 0.1 -- the hand stays open this long (slack for ping)
-- Reaches 5.5 studs out in front of him: catches someone about 6 studs away.
local REACH_BOX = Vector3.new(5, 7, 5)
local REACH_STEP = 6 -- studs per second: the half-step he takes into it
local REACH_WHIFF = 0.55 -- left open after grabbing at nothing

-- The closest person in reach who can be grabbed (not on the floor, not
-- untouchable).
local function inReach(ctx): Model?
	local c, character = ctx.combat, ctx.character
	local box = ctx.root.CFrame * CFrame.new(0, if ctx.airborne then -0.5 else 0, -(0.5 + REACH_BOX.Z / 2))
	local closest: Model? = nil
	local closestDistance = math.huge
	for _, victim in c.Box(character, box, REACH_BOX) do
		local victimRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
		if victimRoot and not CombatState.HasIFrames(victim) and not CombatState.IsRagdolled(victim) then
			local distance = (victimRoot.Position - ctx.root.Position).Magnitude
			if distance < closestDistance then
				closest, closestDistance = victim, distance
			end
		end
	end
	return closest
end

local function reachGrab(ctx, grabTime: number, skill: string?): (Model?, (() -> ())?, ((CFrame) -> ())?)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, REACH_STARTUP + REACH_WINDOW + 0.1)
	local name = skill or "BlackMeteorite"
	fx(ctx, name, "Reach", { airborne = airborne })
	if airborne then
		c.ApplyVelocity(character, HOVER, REACH_STARTUP + REACH_WINDOW)
	else
		c.ApplyVelocity(character, look(ctx) * REACH_STEP, REACH_STARTUP)
	end
	task.wait(REACH_STARTUP)
	if interrupted(ctx) then
		fx(ctx, name, "Cancel")
		return nil, nil, nil
	end
	if not airborne then
		-- Planted while the hand is out.
		c.ApplyVelocity(character, Vector3.zero, REACH_WINDOW)
	end

	local start = os.clock()
	local target = inReach(ctx)
	while not target and os.clock() - start < REACH_WINDOW do
		task.wait()
		if interrupted(ctx) then
			fx(ctx, name, "Cancel")
			return nil, nil, nil
		end
		target = inReach(ctx)
	end
	if not target then
		-- The hand closes on nothing and he's left open.
		fx(ctx, name, "Whiff", { airborne = airborne })
		CombatState.SetCasting(character, REACH_WHIFF)
		return nil, nil, nil
	end
	local release, hold = seize(ctx, target, grabTime)
	if not release then
		return nil, nil, nil
	end
	return target, release, hold
end

-- The grab. His free hand shoots out (no dash), seizes them by the throat
-- and hoists them up while anti-magic surges through them. Then a vortex:
-- he whirls round with them held out, bobbing up and down as it carries
-- them into the sky (Shared/MeteorVortex), and slams them down like a
-- meteor. In the air: hangs there, seizes whoever is in front of him and
-- does the same from where he is, with a shorter climb.
local SEIZE_TIME = 0.4 -- the Seize animation's hoist
local SURGE_AT = 0.2

local function blackMeteorite(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	-- (The grab lasts the whole move: spin, flip, the longest dive, landing.)
	local target, release, hold = reachGrab(ctx, (if airborne then 0.3 else SEIZE_TIME) + MeteorVortex.Length + 1.8)
	if not target or not release or not hold then
		return
	end
	local forward = look(ctx)

	-- The seize: he plants and hoists them up. In the air he rises a little
	-- with them, so the spike has somewhere to fall from.
	fx(ctx, "BlackMeteorite", "Seize", { target = target, airborne = airborne })
	local seize = if airborne then 0.3 else SEIZE_TIME
	c.ApplyVelocity(character, if airborne then UP * 10 else Vector3.zero, seize)
	task.wait(SURGE_AT)
	if interrupted(ctx) then
		release()
		return
	end
	c.Hit(character, target, { damage = 2, stun = 1.5, attackType = "Melee", unblockable = true })
	task.wait(seize - SURGE_AT)
	if interrupted(ctx) then
		release()
		return
	end

	-- The vortex, the head-first dive and the landing: he's held on the
	-- shared path (Shared/MeteorVortex) the whole way; every client draws
	-- the same.
	hold(HOLD_SPIN)
	local origin = CFrame.lookAt(ctx.root.Position, ctx.root.Position + forward)
	local top = if airborne then MeteorVortex.AirTop else MeteorVortex.Top
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, target }
	local floor = workspace:Raycast(origin.Position + UP * 2, UP * -250, params)
	local floorY = if floor then floor.Position.Y else nil
	local plan = MeteorVortex.Plan(origin, top, floorY)
	CombatState.SetCasting(character, plan.length + 0.3)
	fx(ctx, "BlackMeteorite", "Vortex", {
		target = target,
		origin = origin,
		top = top,
		floorY = floorY,
		airborne = airborne,
	})
	local stop = c.Cutscene({
		[character] = function(t: number): CFrame
			return MeteorVortex.At(plan, t)
		end,
	}, plan.length)
	local start = os.clock()
	local function waitUntil(time: number): boolean
		while os.clock() - start < time do
			task.wait()
			if interrupted(ctx) or not CombatState.IsAlive(target) then
				stop()
				release()
				return false
			end
		end
		return true
	end

	-- The vortex tears at them as it spins: three small hits.
	for tick = 1, 3 do
		if not waitUntil(MeteorVortex.Length * tick / 3) then
			return
		end
		c.Hit(character, target, { damage = 1, stun = 1.5, attackType = "Melee", unblockable = true })
	end

	-- Over the top and down, head-first, spinning.
	hold(HOLD_DRILL)
	fx(ctx, "BlackMeteorite", "Slam", {
		target = target,
		airborne = airborne,
		dive = plan.impactAt - plan.flipAt,
	})
	if not waitUntil(plan.impactAt) then
		return
	end
	release()

	-- The client draws its own (much bigger) crater for this one.
	local impact = Vector3.new(plan.diveEnd.X, floorY or (plan.diveEnd.Y - 3), plan.diveEnd.Z)
	fx(ctx, "BlackMeteorite", "Impact", { position = impact, target = target, grounded = floorY ~= nil })
	c.ShakeArea(impact, 45, 0.6)
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local away = if targetRoot then c.Flat(targetRoot.Position - ctx.root.Position) else Vector3.zero
	away = if away.Magnitude > 0.1 then away.Unit else forward
	c.Hit(character, target, {
		damage = if airborne then 4 else 6, -- plus the seize and the vortex's three
		stun = 1,
		attackType = "Melee",
		unblockable = true,
		heavy = true,
		ragdoll = 1.6,
		velocity = away * 25 + UP * 35,
	})
	-- He rolls back onto his feet (the rest of the path), then he's free.
	waitUntil(plan.length)
	CombatState.SetCasting(character, 0.2)
end

local DIVIDER_CHARGE = 0.62
local PERFECT_FROM, PERFECT_TO = 0.36, 0.66 -- generous for ping; client shows the flash at 0.38

-- In the air he hangs while it charges, then front-flips the blade down
-- onto whatever's below and in front, spiking them into the ground.
local function blackDivider(ctx)
	local c, character = ctx.combat, ctx.character
	local data = ctx.data
	local airborne = ctx.airborne
	CombatState.SetCasting(character, DIVIDER_CHARGE + 0.45)
	if airborne then
		c.ApplyVelocity(character, HOVER, DIVIDER_CHARGE + 0.05)
	end

	local start = os.clock()
	fx(ctx, "BlackDivider", "Charge", { flashAt = 0.38, airborne = airborne })

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
	fx(ctx, "BlackDivider", "Release", { perfect = perfect, airborne = airborne })
	if airborne then
		local below = ctx.root.CFrame * CFrame.new(0, -2.5, -3)
		for _, victim in c.Box(character, below, Vector3.new(10, 11, 10)) do
			c.Hit(character, victim, {
				damage = if perfect then 12 else 7,
				stun = if perfect then 1.2 else 1,
				attackType = "Melee", -- the air version can be blocked
				heavy = true,
				ragdoll = if perfect then 1.6 else 1.3,
				velocity = forward * 18 + UP * -85,
				effect = if perfect then "PerfectDivider" else nil,
			})
		end
		-- The flip carries him up a touch before he drops.
		c.ApplyVelocity(character, UP * 22 + forward * 6, 0.12)
		c.ShakeArea(ctx.root.Position, if perfect then 60 else 25, if perfect then 0.8 else 0.35)
		CombatState.SetCasting(character, 0.35)
		return
	end
	local box = ctx.root.CFrame * CFrame.new(0, 0, -4.5)
	for _, victim in c.Box(character, box, Vector3.new(9, 7, 9)) do
		if perfect then
			c.Hit(character, victim, {
				damage = 14,
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

local DEFLECT_WINDOW = 0.65

local function antiMagicDeflect(ctx)
	local c, character = ctx.combat, ctx.character
	local countered = false
	CombatState.SetCasting(character, DEFLECT_WINDOW + 0.1)
	-- In the air he hangs there, guard up.
	local airborne = ctx.airborne
	if airborne then
		c.ApplyVelocity(character, HOVER, DEFLECT_WINDOW)
	end
	fx(ctx, "Deflect", "Stance", { airborne = airborne, window = DEFLECT_WINDOW })

	c.SetCounter(character, DEFLECT_WINDOW, ALL_TYPES, function(attacker: Model)
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
				damage = 7,
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
			blackSlash(ctx, ctx.root.Position + direction * 2 + UP * 0.5, direction, { damage = 6 })
		end
	end)

	task.wait(DEFLECT_WINDOW + 0.02)
	if not countered then
		-- Guessed wrong: a moment where he's wide open.
		c.ClearCounter(character)
		fx(ctx, "Deflect", "End")
		CombatState.SetCasting(character, 0.45)
	end
end

---------------------------------------------------------------------------
-- Black Form moves
---------------------------------------------------------------------------

-- Black Hurricane. In the air he drills down on them, spinning.
local function blackHurricane(ctx)
	local c, character = ctx.combat, ctx.character
	local forward = look(ctx)
	local airborne = ctx.airborne
	local push = if airborne then forward * 40 + UP * -35 else forward * 55
	CombatState.SetCasting(character, 1.15)
	fx(ctx, "BlackHurricane", "Spin", { duration = 0.9, airborne = airborne })
	c.ApplyVelocity(character, push, 0.9, if airborne then { landStop = true, landKeep = 0.8 } else nil)

	local caught: { [Model]: boolean } = {}
	for _ = 1, 9 do
		task.wait(0.1)
		if interrupted(ctx) then
			fx(ctx, "BlackHurricane", "Stop")
			return
		end
		for _, victim in c.Sphere(character, ctx.root.Position, 7) do
			-- Dragged along with the spin.
			if
				c.Hit(character, victim, {
					damage = 1,
					stun = 0.6,
					attackType = "Melee",
					velocity = Vector3.new(push.X, math.max(push.Y, 0), push.Z) + UP * 2,
					velocityTime = 0.12,
				}) == "Hit"
			then
				caught[victim] = true
			end
		end
	end

	fx(ctx, "BlackHurricane", "Finish", { airborne = airborne })
	for victim in caught do
		if CombatState.IsAlive(victim) then
			c.Hit(character, victim, {
				damage = 5,
				stun = 1,
				attackType = "Melee",
				heavy = true,
				ragdoll = 1.4,
				-- In the air they're driven into the ground instead of thrown up.
				velocity = if airborne then forward * 30 + UP * -60 else forward * 45 + UP * 45,
			})
		end
	end
	CombatState.SetCasting(character, 0.3)
end

-- How far a wave can fly along `direction` before it hits the ground (a wave
-- thrown down out of the air stops there instead of tunnelling on).
local function waveRange(ctx, origin: Vector3, direction: Vector3, maxRange: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.character }
	local hit = workspace:Raycast(origin, direction * maxRange, params)
	return if hit then math.max((hit.Position - origin).Magnitude + 2, 8) else maxRange
end

-- Black Slash. In the air he hangs for the throw and hurls it down ahead.
local function blackSlashMove(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, 0.5)
	if airborne then
		c.ApplyVelocity(character, HOVER, 0.4)
	end
	fx(ctx, "BlackSlash", "Windup", { airborne = airborne })
	task.wait(0.22)
	if interrupted(ctx) then
		return
	end
	local forward = look(ctx)
	local direction = if airborne then (forward + UP * -0.45).Unit else forward
	local origin = ctx.root.Position + direction * 2 + UP * 0.5
	blackSlash(ctx, origin, direction, {
		damage = 9,
		range = if airborne then waveRange(ctx, origin, direction, 90) else nil,
	})
end

-- Grand Divider. In the air he hangs while it charges, then brings it down
-- on whatever is below and in front, and the wave is driven into the ground.
local function grandDivider(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, 1.3)
	if airborne then
		c.ApplyVelocity(character, HOVER, 0.75)
	end
	fx(ctx, "GrandDivider", "Charge", { airborne = airborne })
	task.wait(0.7)
	if interrupted(ctx) then
		fx(ctx, "GrandDivider", "Cancel")
		return
	end

	local forward = look(ctx)
	fx(ctx, "GrandDivider", "Release", { airborne = airborne })
	local struck: { [Model]: boolean } = {}
	local box = if airborne then ctx.root.CFrame * CFrame.new(0, -3, -4) else ctx.root.CFrame * CFrame.new(0, 0, -5)
	local size = if airborne then Vector3.new(14, 12, 12) else Vector3.new(12, 9, 10)
	for _, victim in c.Box(character, box, size) do
		struck[victim] = true
		c.Hit(character, victim, {
			damage = 10,
			stun = 1.2,
			attackType = "Explosion",
			guardBreak = true,
			heavy = true,
			ragdoll = 1.6,
			velocity = if airborne then forward * 20 + UP * -95 else forward * 70 + UP * 25,
		})
	end
	local direction = if airborne then (forward + UP * -0.6).Unit else forward
	local origin = ctx.root.Position + direction * 4 + UP * 1
	blackSlash(ctx, origin, direction, {
		damage = 9,
		size = Vector3.new(18, 8, 3),
		speed = 95,
		range = if airborne then waveRange(ctx, origin, direction, 55) else 55,
		grand = true,
		skip = struck,
	})
	if airborne then
		c.ApplyVelocity(character, UP * 22 + forward * 6, 0.12)
	end
	c.ShakeArea(ctx.root.Position, 70, 0.7)
	task.wait(0.3)
	CombatState.SetCasting(character, 0.3)
end

--[[
	Black Moon (Black Form 4): seizes them by the throat and hurls them into
	the sky. Night falls; he hangs in front of a giant moon, then flies
	through them, and a beat later the cut lands. A cutscene for the two of
	them: the timeline is Shared/BlackMoon, the camera work and effects are
	client side.
]]
local MOON_SEIZE = 0.4

local function blackMoon(ctx)
	local c, character = ctx.combat, ctx.character
	local target, release = reachGrab(ctx, MOON_SEIZE + 0.3, "BlackMoon")
	if not target or not release then
		return
	end
	fx(ctx, "BlackMoon", "Seize", { target = target })
	c.ApplyVelocity(character, Vector3.zero, MOON_SEIZE)
	task.wait(SURGE_AT)
	if interrupted(ctx) then
		release()
		return
	end
	c.Hit(character, target, { damage = 2, stun = 3.5, attackType = "Melee", unblockable = true })
	task.wait(MOON_SEIZE - SURGE_AT)
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if interrupted(ctx) or not targetRoot or not CombatState.IsAlive(target) then
		release()
		return
	end

	-- The cutscene takes over from the grab.
	local plan = BlackMoon.Plan(ctx.root.CFrame, targetRoot.Position)
	release()
	local length = BlackMoon.Times.Land
	CombatState.SetCasting(character, length + 0.6)
	CombatState.GiveIFrames(character, length + 0.4)
	CombatState.Stun(target, length + 0.6)
	fx(ctx, "BlackMoon", "Begin", { target = target, origin = plan.origin, victimStart = plan.victimStart })
	local stop = c.Cutscene({
		[character] = function(t)
			return BlackMoon.Attacker(plan, t)
		end,
		[target] = function(t)
			return BlackMoon.Victim(plan, t)
		end,
	}, length)
	task.wait(length)
	stop()

	-- The cut lands: they're cut down out of the sky.
	if CombatState.IsAlive(target) then
		c.Hit(character, target, {
			damage = 18,
			stun = 1.5,
			attackType = "Melee",
			unblockable = true,
			heavy = true,
			ragdoll = 2.4,
			velocity = UP * -110 + plan.forward * 8,
			effect = "BlackMoonCut",
		})
	end
	c.ShakeArea(plan.apex, 120, 0.7)
	-- He glides back down on his wing.
	c.ApplyVelocity(character, UP * -32 + plan.forward * 4, 1)
	CombatState.SetCasting(character, 0.7)
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

---------------------------------------------------------------------------
-- Special (R): Anti-Magic Leap / Meteor Plunge
---------------------------------------------------------------------------

local SPECIAL = CombatState.SpecialSlot
local LEAP_TIME = 0.22
local PLUNGE_HANG = 0.12 -- the Plunge animation's wind-up

-- Meteor Plunge: hangs for a beat with the sword raised, dives behind it
-- (steerable) and stabs it into the ground, blasting everyone around away.
local function plunge(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, 1.2)
	fx(ctx, "Special", "Plunge")
	c.ApplyVelocity(character, HOVER, PLUNGE_HANG)
	task.wait(PLUNGE_HANG)
	if interrupted(ctx) then
		return
	end
	fx(ctx, "Special", "Dive")
	c.ApplyVelocity(character, look(ctx) * 40 + UP * -140, 1, { steer = 140, landStop = true, landKeep = 0 })
	waitForTakeoff(ctx, 0.5)
	waitForGround(ctx, 1)
	if interrupted(ctx) or c.IsAirborne(character) then
		CombatState.SetCasting(character, 0.2)
		return
	end
	c.ApplyVelocity(character, Vector3.zero, 0.05)
	local impact = groundBelow(ctx)
	fx(ctx, "Special", "Impact", { position = impact })
	c.ShakeArea(impact, 35, 0.45)
	for _, victim in c.Sphere(character, impact + UP * 2, 8) do
		local victimRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
		if victimRoot then
			c.Hit(character, victim, {
				damage = 5,
				stun = 0.9,
				attackType = "Melee",
				heavy = true,
				velocity = c.Flat(victimRoot.Position - impact) * 34 + UP * 30,
				velocityTime = 0.2,
			})
		end
	end
	CombatState.SetCasting(character, 0.35)
end

-- Anti-Magic Leap: blasts off the ground toward where he's heading
-- (steerable). Press R again in the air to turn it into the plunge. Stops
-- listening as soon as another move starts or he's back on the ground.
local function leap(ctx)
	local c, character = ctx.combat, ctx.character
	local token = c.MoveToken(character)
	local start = os.clock()
	CombatState.SetCasting(character, 0.25)
	fx(ctx, "Special", "Leap")
	c.ApplyVelocity(character, look(ctx) * 60 + UP * 62, LEAP_TIME, { steer = 200 })
	task.wait(0.15)
	local since = start + 0.1
	local seenAir = false
	while os.clock() - start < 1.6 do
		if interrupted(ctx) or c.MoveToken(character) ~= token then
			return
		end
		local up = c.IsAirborne(character)
		seenAir = seenAir or up
		if c.PressedSince(character, SPECIAL, since) then
			-- The press says whether he was in the air (his own client knows).
			if c.PressedAirborne(character, SPECIAL) then
				plunge(ctx)
				return
			end
			since = os.clock()
		end
		-- Landed, once the server (a ping behind) has seen him go up.
		if seenAir and not up then
			return
		end
		if not seenAir and os.clock() - start > 1 then
			return
		end
		task.wait()
	end
end

function Kit.Special(ctx)
	if ctx.airborne then
		plunge(ctx)
	else
		leap(ctx)
	end
end

Kit.Skills = { bullThrust, blackMeteorite, blackDivider, antiMagicDeflect }
Kit.AwakenedSkills = { blackHurricane, blackSlashMove, grandDivider, blackMoon }

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
