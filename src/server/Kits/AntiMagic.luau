local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlackMoon = require(ReplicatedStorage:WaitForChild("Shared").BlackMoon)
local MeteorVortex = require(ReplicatedStorage:WaitForChild("Shared").MeteorVortex)
local CometPlan = require(ReplicatedStorage:WaitForChild("Shared").BlackComet)
local AscentPlan = require(ReplicatedStorage:WaitForChild("Shared").BlackAscent)
local CombatState = require(ReplicatedStorage:WaitForChild("Shared").CombatState)
local Projectile = require(script.Parent.Parent.Projectile)

local KIT_ID = "AntiMagic"
local UP = Vector3.yAxis

local HOVER = Vector3.new(0, 0.05, 0)
local ALL_TYPES = { Melee = true, Bolt = true, Explosion = true, Swarm = true, Zone = true }

local Kit = {}

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

type BladeMarks = {
	guard: number,
	tip: number,
	point: number,
}

local function assemble(model: Model, handle: BasePart, parts: { BasePart }, marks: BladeMarks): Model
	for _, part in parts do
		local weld = Instance.new("Weld")
		weld.Name = "Join"
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = part.CFrame
		weld.Parent = part
		part.Parent = model
	end

	local blade = model:FindFirstChild("Blade") :: Part
	blade:SetAttribute("GuardY", marks.guard)
	blade:SetAttribute("TipY", marks.tip)
	blade:SetAttribute("PointY", marks.point)
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.Position = Vector3.new(0, marks.guard + 0.23, 0)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.Position = Vector3.new(0, marks.tip - 0.46, 0)
	tip.Parent = blade
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = base
	trail.Attachment1 = tip
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

local function buildSlayer(): Model
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
		swordPart("GripLower", Vector3.new(0.26, 0.4, 0.26), CFrame.new(0, -0.67, 0), wrap, cloth),
		swordPart("WrapA", Vector3.new(0.3, 0.05, 0.3), CFrame.new(0, -0.76, 0), band, cloth),
		swordPart("WrapB", Vector3.new(0.3, 0.05, 0.3), CFrame.new(0, -0.5, 0), band, cloth),
		swordPart("WrapC", Vector3.new(0.32, 0.05, 0.32), CFrame.new(0, -0.15, 0), band, cloth),
		swordPart("WrapD", Vector3.new(0.32, 0.05, 0.32), CFrame.new(0, 0.2, 0), band, cloth),
		pommel,
		swordPart("Guard", Vector3.new(0.2, 0.15, 1.8), CFrame.new(0, 0.6, 0), bronze, metal),
		swordPart("GuardCapA", Vector3.new(0.24, 0.22, 0.12), CFrame.new(0, 0.6, 0.94), darkBronze, metal),
		swordPart("GuardCapB", Vector3.new(0.24, 0.22, 0.12), CFrame.new(0, 0.6, -0.94), darkBronze, metal),
		swordPart("Collar", Vector3.new(0.26, 0.2, 0.72), CFrame.new(0, 0.77, 0), darkBronze, metal),
		swordPart("Blade", Vector3.new(0.2, 3.74, 1.4), CFrame.new(0, 2.73, 0), black, metal),
		swordPart("TipA", Vector3.new(0.2, 1.2, 0.7), CFrame.new(0, 5.2, -0.35), black, metal, "WedgePart"),
		swordPart(
			"TipB",
			Vector3.new(0.2, 1.2, 0.7),
			CFrame.new(0, 5.2, 0.35) * CFrame.Angles(0, math.pi, 0),
			black,
			metal,
			"WedgePart"
		),
		swordPart("Ridge", Vector3.new(0.22, 4.2, 0.12), CFrame.new(0, 3.1, 0), ridge, Enum.Material.SmoothPlastic),
		swordPart("EdgeA", Vector3.new(0.14, 3.67, 0.08), CFrame.new(0, 2.765, -0.69), worn, metal),
		swordPart("EdgeB", Vector3.new(0.14, 3.67, 0.08), CFrame.new(0, 2.765, 0.69), worn, metal),
		swordPart(
			"PointEdgeA",
			Vector3.new(0.22, 0.1, 1.39),
			CFrame.new(0, 5.175, -0.307) * CFrame.Angles(math.rad(-59.74), 0, 0),
			worn,
			metal
		),
		swordPart(
			"PointEdgeB",
			Vector3.new(0.22, 0.1, 1.39),
			CFrame.new(0, 5.175, 0.307) * CFrame.Angles(math.rad(59.74), 0, 0),
			worn,
			metal
		),
		flat("StainA", Vector3.new(0.215, 0.9, 0.45), 1.7, 0.25, 20),
		flat("StainB", Vector3.new(0.215, 0.6, 0.35), 2.6, -0.3, -15),
		flat("StainC", Vector3.new(0.215, 1.1, 0.4), 3.6, 0.2, 10),
		flat("StainD", Vector3.new(0.215, 0.5, 0.3), 4.1, 0.25, 30),
		swordPart("NickA", Vector3.new(0.16, 0.22, 0.1), CFrame.new(0, 1.9, -0.66), nick, metal),
		swordPart("NickB", Vector3.new(0.16, 0.16, 0.1), CFrame.new(0, 3.2, 0.66), nick, metal),
		swordPart("NickC", Vector3.new(0.16, 0.26, 0.1), CFrame.new(0, 3.9, -0.66), nick, metal),
		swordPart("NickD", Vector3.new(0.16, 0.18, 0.1), CFrame.new(0, 2.5, 0.66), nick, metal),
	}
	return assemble(model, handle, parts, { guard = -1.87, tip = 2.62, point = 3.07 })
end

local function ball(part: BasePart): BasePart
	(part :: Part).Shape = Enum.PartType.Ball
	return part
end

local function alongBlade(blade: BasePart, point: Vector3): number
	return blade.CFrame:PointToObjectSpace(point).Y
end

local function buildDestroyer(): Model
	local model = Instance.new("Model")
	model.Name = "KitWeapon"
	local black = Color3.fromRGB(22, 22, 25)
	local edge = Color3.fromRGB(72, 72, 80)
	local metal = Enum.Material.Metal

	local handle = swordPart(
		"Handle",
		Vector3.new(0.26, 0.9, 0.26),
		CFrame.new(),
		Color3.fromRGB(45, 36, 30),
		Enum.Material.Fabric
	)
	handle.Parent = model
	model.PrimaryPart = handle
	local plate = swordPart(
		"GuardPlate",
		Vector3.new(0.12, 0.5, 0.5),
		CFrame.new(0, 0.55, 0),
		Color3.fromRGB(120, 15, 25),
		Enum.Material.Neon
	);
	(plate :: Part).Shape = Enum.PartType.Cylinder
	local parts = {
		swordPart("Pommel", Vector3.new(0.3, 0.2, 0.3), CFrame.new(0, -0.55, 0), black, metal),
		swordPart("Guard", Vector3.new(0.18, 0.16, 0.85), CFrame.new(0, 0.55, 0), black, metal),
		plate,
	}
	local at = CFrame.new(0, 0.63, 0)
	local blade: BasePart? = nil
	for i, width in { 0.34, 0.42, 0.52, 0.62 } do
		local piece = swordPart(
			if i == 1 then "Blade" else "Blade" .. i,
			Vector3.new(0.14, 0.68, width),
			at * CFrame.new(0, 0.33, width / 2 - 0.17),
			black,
			metal
		)
		blade = blade or piece
		table.insert(parts, piece)
		table.insert(
			parts,
			swordPart("Edge" .. i, Vector3.new(0.1, 0.68, 0.06), at * CFrame.new(0, 0.33, -0.16), edge, metal)
		)
		at = at * CFrame.new(0, 0.66, 0) * CFrame.Angles(math.rad(5), 0, 0)
	end
	local head = at * CFrame.new(0, 0.3, 0.18)
	table.insert(parts, swordPart("Head", Vector3.new(0.14, 0.6, 0.7), head, black, metal))
	table.insert(parts, swordPart("HeadEdge", Vector3.new(0.1, 0.6, 0.06), head * CFrame.new(0, 0, -0.34), edge, metal))
	local tipFrame = head * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, math.pi, 0)
	table.insert(parts, swordPart("HeadTip", Vector3.new(0.14, 0.5, 0.7), tipFrame, black, metal, "WedgePart"))
	local clover = head * CFrame.new(0, 0.05, 0.2)
	for i, leaf in
		{ Vector3.new(0, 0.09, 0), Vector3.new(0, -0.09, 0), Vector3.new(0, 0, 0.09), Vector3.new(0, 0, -0.09) }
	do
		table.insert(
			parts,
			ball(
				swordPart(
					"Clover" .. i,
					Vector3.one * 0.16,
					clover * CFrame.new(leaf),
					Color3.fromRGB(230, 230, 230),
					Enum.Material.SmoothPlastic
				)
			)
		)
	end
	local bladePart = blade :: BasePart
	local point = (head * CFrame.new(0, 0.8, -0.35)).Position
	local pointY = alongBlade(bladePart, point)
	return assemble(model, handle, parts, {
		guard = alongBlade(bladePart, Vector3.new(0, 0.63, 0)),
		tip = pointY - 0.2,
		point = pointY,
	})
end

local function buildSlasher(): Model
	local model = Instance.new("Model")
	model.Name = "KitWeapon"
	local steel = Color3.fromRGB(15, 15, 17)
	local edge = Color3.fromRGB(90, 90, 96)
	local fitting = Color3.fromRGB(55, 52, 48)
	local metal = Enum.Material.Metal

	local handle =
		swordPart("Handle", Vector3.new(0.2, 0.9, 0.22), CFrame.new(), Color3.fromRGB(28, 28, 32), Enum.Material.Fabric)
	handle.Parent = model
	model.PrimaryPart = handle
	local tsuba = swordPart(
		"Tsuba",
		Vector3.new(0.06, 0.52, 0.52),
		CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		fitting,
		metal
	);
	(tsuba :: Part).Shape = Enum.PartType.Cylinder
	local parts = {
		swordPart("Kashira", Vector3.new(0.22, 0.08, 0.24), CFrame.new(0, -0.49, 0), fitting, metal),
		tsuba,
		swordPart("Habaki", Vector3.new(0.12, 0.12, 0.2), CFrame.new(0, 0.58, 0), Color3.fromRGB(150, 120, 60), metal),
	}
	for i, y in { -0.3, -0.05, 0.2 } do
		table.insert(
			parts,
			swordPart(
				"Diamond" .. i,
				Vector3.new(0.21, 0.11, 0.11),
				CFrame.new(0, y, 0) * CFrame.Angles(math.rad(45), 0, 0),
				Color3.fromRGB(140, 140, 145),
				Enum.Material.Fabric
			)
		)
	end
	local at = CFrame.new(0, 0.64, 0)
	local blade: BasePart? = nil
	for i = 1, 4 do
		local piece = swordPart(
			if i == 1 then "Blade" else "Blade" .. i,
			Vector3.new(0.09, 0.62, 0.19),
			at * CFrame.new(0, 0.31, 0),
			steel,
			metal
		)
		blade = blade or piece
		table.insert(parts, piece)
		table.insert(
			parts,
			swordPart("Hamon" .. i, Vector3.new(0.095, 0.62, 0.04), at * CFrame.new(0, 0.31, -0.08), edge, metal)
		)
		at = at * CFrame.new(0, 0.62, 0) * CFrame.Angles(math.rad(3), 0, 0)
	end
	table.insert(
		parts,
		swordPart("Kissaki", Vector3.new(0.09, 0.3, 0.19), at * CFrame.new(0, 0.15, 0), steel, metal, "WedgePart")
	)
	local bladePart = blade :: BasePart
	local pointY = alongBlade(bladePart, (at * CFrame.new(0, 0.3, 0.09)).Position)
	return assemble(model, handle, parts, {
		guard = alongBlade(bladePart, Vector3.new(0, 0.64, 0)),
		tip = pointY - 0.15,
		point = pointY,
	})
end

local SWORDS: { [string]: () -> Model } = {
	Slayer = buildSlayer,
	Destroyer = buildDestroyer,
	Slasher = buildSlasher,
}

local function wield(character: Model, sword: Model)
	local handle = sword.PrimaryPart :: BasePart
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

local function setSword(character: Model, kind: string)
	local build = SWORDS[kind]
	if not build then
		return
	end
	local old = character:FindFirstChild("KitWeapon")
	if old then
		old:Destroy()
	end
	character:SetAttribute("Sword", kind)
	wield(character, build())
end

function Kit.Equip(character: Model)
	character:WaitForChild("Right Arm", 5)
	setSword(character, "Slayer")
end

function Kit.Unequip(character: Model)
	local sword = character:FindFirstChild("KitWeapon")
	if sword then
		sword:Destroy()
	end
	character:SetAttribute("Sword", nil)
end

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

local function interrupted(ctx): boolean
	local character = ctx.character
	return not CombatState.IsAlive(character) or CombatState.IsStunned(character) or CombatState.IsRagdolled(character)
end

local TAKEOFF_GRACE = 0.25

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

local PROPEL_SPEED = 85
local PROPEL_TIME = 0.55
local PROPEL_STEER = 200

local COMBO = {
	{ kind = "Rising", at = 0.14, damage = 1.5, reach = 3.8, drift = 5 },
	{ kind = "Sweep", at = 0.3, damage = 1.5, reach = 3.8, drift = 3 },
	{ kind = "Spin", at = 0.54, damage = 1.5, reach = 3.8, drift = 3 },
	{ kind = "Chop", at = 0.76, damage = 2, reach = 4.6, drift = 0 },
	{ kind = "Thrust", at = 1.1, damage = 3, reach = 0, drift = 0 },
}
local THRUST_PUSH = 24
local DIVE_THRUST = 60
local DIVE_THRUST_LIFT = 26
local MAX_PULL = 30

local DIVE_AFTER_LEAP = 2.5
local leapedAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local SLAM_RADIUS = 11
local SLAM_DAMAGE = 6
local SLAM_RECOVERY = 0.45
local SLAM_WHIFF_RECOVERY = 1.6
local DIVE_WHIFF_RECOVERY = 1.4
local LAND_WINDOW = 0.5

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

local function bullSlam(ctx)
	local c, character = ctx.combat, ctx.character
	local forward = look(ctx)
	c.ApplyVelocity(character, Vector3.zero, 0.05)
	local impact = groundBelow(ctx) + forward * 1.5
	local victims = c.Sphere(character, impact + UP * 2, SLAM_RADIUS)
	local whiff = #victims == 0
	fx(ctx, "BullThrust", "Land", {
		position = impact,
		targets = victims,
		stuck = if whiff then SLAM_WHIFF_RECOVERY - SLAM_RECOVERY else nil,
	})
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
				velocity = out * 85 + UP * 60,
			})
		end
	end
	CombatState.SetCasting(character, if whiff then SLAM_WHIFF_RECOVERY else SLAM_RECOVERY)
end

local function bullThrust(ctx)
	local c, character = ctx.combat, ctx.character
	local forward = look(ctx)
	local leaped = leapedAt[character]
	leapedAt[character] = nil
	local airborne = ctx.airborne and leaped ~= nil and os.clock() - leaped < DIVE_AFTER_LEAP
	local direction = if airborne then (forward + UP * -0.6).Unit else forward

	CombatState.SetCasting(character, PROPEL_TIME + 0.25)
	fx(ctx, "BullThrust", "Propel", { airborne = airborne, direction = direction, duration = PROPEL_TIME })
	local target, landed =
		lunge(ctx, direction * PROPEL_SPEED, PROPEL_TIME, Vector3.new(6, 6, 7), PROPEL_STEER, airborne)
	if not target then
		if airborne and not landed and not interrupted(ctx) then
			CombatState.SetCasting(character, LAND_WINDOW + 0.1)
			landed = landsWithin(ctx, LAND_WINDOW)
		end
		if landed and not interrupted(ctx) then
			bullSlam(ctx)
			return
		end
		fx(ctx, "BullThrust", "Whiff")
		CombatState.SetCasting(character, if airborne then DIVE_WHIFF_RECOVERY else 0.45)
		return
	end

	forward = look(ctx)
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local contact = if targetRoot then targetRoot.Position else ctx.root.Position + forward * 3
	local caught = c.Hit(character, target, { damage = 2, stun = 1.6, attackType = "Melee", guardBreak = airborne })
	if caught ~= "Hit" and caught ~= "GuardBreak" then
		CombatState.SetCasting(character, 0.4)
		return
	end
	fx(ctx, "BullThrust", "Catch", { target = target, position = contact })

	CombatState.SetCasting(character, COMBO[#COMBO].at + 0.2)
	fx(ctx, "BullThrust", "Combo", { target = target })
	local first = COMBO[1]
	c.ApplyVelocity(target, holdInFront(ctx, target, forward, first.reach, 0, first.at), first.at)
	c.ApplyVelocity(character, Vector3.zero, first.at)
	local start = os.clock()
	for index, cut in COMBO do
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
		elseif airborne then
			hit.stun = 1.1
			hit.heavy = true
			hit.ragdoll = 1.2
			hit.velocity = forward * DIVE_THRUST + UP * DIVE_THRUST_LIFT
		else
			hit.stun = 1.1
			hit.heavy = true
			hit.velocity = forward * THRUST_PUSH + UP * 4
			hit.velocityTime = 0.15
		end
		if c.Hit(character, target, hit) ~= "Hit" then
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
	ctx.data.combo = 0
	ctx.data.nextM1 = 0
end

local FACING = CFrame.Angles(0, math.pi, 0)
local HOLD_SEIZE = CFrame.new(-1.6, 0.35, -1.75) * FACING
local HOLD_DRILL = CFrame.new(-0.6, 0.6, -2.4) * FACING
local HOLD_SPIN = CFrame.new(-1.7, 0.5, -2.3) * FACING

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

local REACH_STARTUP = 0.16
local REACH_WINDOW = 0.1
local REACH_BOX = Vector3.new(5, 7, 5)
local REACH_STEP = 6
local REACH_WHIFF = 0.55

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

local SEIZE_TIME = 0.4
local SURGE_AT = 0.2
local METEOR_TICKS = 2
local METEOR_TICK = 1
local METEOR_SLAM = 6
local METEOR_AIR_SLAM = 3.5
local METEOR_SPLASH = 11
local METEOR_SPLASH_DAMAGE = 4
local METEOR_AIR_SPLASH_DAMAGE = 2.5

local function blackMeteorite(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	local target, release, hold = reachGrab(ctx, (if airborne then 0.3 else SEIZE_TIME) + MeteorVortex.Length + 1.8)
	if not target or not release or not hold then
		return
	end
	local forward = look(ctx)

	fx(ctx, "BlackMeteorite", "Seize", { target = target, airborne = airborne })
	local seize = if airborne then 0.3 else SEIZE_TIME
	c.ApplyVelocity(character, if airborne then UP * 10 else Vector3.zero, seize)
	task.wait(SURGE_AT)
	if interrupted(ctx) then
		release()
		return
	end
	c.Hit(character, target, { damage = 2, stun = 1.5, attackType = "Melee", unblockable = true, noShake = true })
	task.wait(seize - SURGE_AT)
	if interrupted(ctx) then
		release()
		return
	end

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

	for tick = 1, METEOR_TICKS do
		if not waitUntil(MeteorVortex.Length * tick / METEOR_TICKS) then
			return
		end
		c.Hit(
			character,
			target,
			{ damage = METEOR_TICK, stun = 1.5, attackType = "Melee", unblockable = true, noShake = true }
		)
	end

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

	local impact = Vector3.new(plan.diveEnd.X, floorY or (plan.diveEnd.Y - 3), plan.diveEnd.Z)
	fx(ctx, "BlackMeteorite", "Impact", { position = impact, target = target, grounded = floorY ~= nil })
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local away = if targetRoot then c.Flat(targetRoot.Position - ctx.root.Position) else Vector3.zero
	away = if away.Magnitude > 0.1 then away.Unit else forward
	local slam = if airborne then METEOR_AIR_SLAM else METEOR_SLAM
	c.Hit(character, target, {
		damage = slam,
		stun = 1,
		attackType = "Melee",
		unblockable = true,
		heavy = true,
		noShake = true,
		ragdoll = 1.6,
		velocity = away * 25 + UP * 35,
	})
	for _, victim in c.Sphere(character, impact + UP * 2, METEOR_SPLASH) do
		local victimRoot = victim:FindFirstChild("HumanoidRootPart") :: BasePart?
		if victim ~= target and victimRoot then
			local out = victimRoot.Position - impact
			out = if Vector3.new(out.X, 0, out.Z).Magnitude > 0.5 then c.Flat(out) else forward
			c.Hit(character, victim, {
				damage = if airborne then METEOR_AIR_SPLASH_DAMAGE else METEOR_SPLASH_DAMAGE,
				stun = 0.9,
				attackType = "Melee",
				guardBreak = true,
				heavy = true,
				ragdoll = 1,
				velocity = out * 45 + UP * 30,
			})
		end
	end
	waitUntil(plan.length)
	CombatState.SetCasting(character, 0.2)
end

local DIVIDER_CHARGE = 0.62
local PERFECT_FROM, PERFECT_TO = 0.36, 0.66

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
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local floor = workspace:Raycast(ctx.root.Position, Vector3.new(0, -40, 0), params)
		local depth = if floor then ctx.root.Position.Y - floor.Position.Y + 1 else 8
		local height = math.clamp(depth + 3, 11, 40)
		local below = ctx.root.CFrame * CFrame.new(0, 3 - height / 2, -3)
		for _, victim in c.Box(character, below, Vector3.new(10, height, 10)) do
			c.Hit(character, victim, {
				damage = if perfect then 12 else 7,
				stun = if perfect then 1.2 else 1,
				attackType = "Melee",
				hitsDowned = true,
				heavy = true,
				ragdoll = if perfect then 1.6 else 1.3,
				velocity = forward * 18 + UP * -85,
				effect = if perfect then "PerfectDivider" else nil,
			})
		end
		c.ApplyVelocity(character, UP * 22 + forward * 6, 0.12)
		c.ShakeArea(ctx.root.Position, if perfect then 60 else 25, if perfect then 0.8 else 0.35)
		CombatState.SetCasting(character, 0.35)
		return
	end
	local box = ctx.root.CFrame * CFrame.new(0, 0, -4.5)
	for _, victim in c.Box(character, box, Vector3.new(9, 7, 9)) do
		if perfect then
			c.Hit(character, victim, {
				damage = 17,
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
				damage = 11,
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
			local direction = c.Flat(offset)
			fx(ctx, "Deflect", "Reflect", { direction = direction })
			blackSlash(ctx, ctx.root.Position + direction * 2 + UP * 0.5, direction, { damage = 6 })
		end
	end)

	task.wait(DEFLECT_WINDOW + 0.02)
	if not countered then
		c.ClearCounter(character)
		fx(ctx, "Deflect", "End")
		CombatState.SetCasting(character, 0.45)
	end
end

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
				velocity = if airborne then forward * 30 + UP * -60 else forward * 45 + UP * 45,
			})
		end
	end
	CombatState.SetCasting(character, 0.3)
end

local function waveRange(ctx, origin: Vector3, direction: Vector3, maxRange: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.character }
	local hit = workspace:Raycast(origin, direction * maxRange, params)
	return if hit then math.max((hit.Position - origin).Magnitude + 2, 8) else maxRange
end

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
	c.Hit(character, target, { damage = 3, stun = 3.5, attackType = "Melee", unblockable = true })
	task.wait(MOON_SEIZE - SURGE_AT)
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if interrupted(ctx) or not targetRoot or not CombatState.IsAlive(target) then
		release()
		return
	end

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

	if CombatState.IsAlive(target) then
		c.Hit(character, target, {
			damage = 25,
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
	c.ApplyVelocity(character, UP * -32 + plan.forward * 4, 1)
	CombatState.SetCasting(character, 0.7)
end

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

local SPECIAL = CombatState.SpecialSlot
local LEAP_TIME = 0.22
local PLUNGE_HANG = 0.12

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

local function forgetLeapOnLanding(ctx, start: number)
	local c, character = ctx.combat, ctx.character
	task.spawn(function()
		local seenAir = false
		while leapedAt[character] == start and os.clock() - start < DIVE_AFTER_LEAP do
			local up = c.IsAirborne(character)
			seenAir = seenAir or up
			if seenAir and not up then
				break
			end
			task.wait()
		end
		if leapedAt[character] == start then
			leapedAt[character] = nil
		end
	end)
end

local function leap(ctx)
	local c, character = ctx.combat, ctx.character
	local token = c.MoveToken(character)
	local start = os.clock()
	leapedAt[character] = start
	forgetLeapOnLanding(ctx, start)
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
			if c.PressedAirborne(character, SPECIAL) then
				leapedAt[character] = nil
				plunge(ctx)
				return
			end
			since = os.clock()
		end
		if seenAir and not up then
			leapedAt[character] = nil
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

local function rootOf(character: Model): BasePart?
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local RECALL_RELEASE = 0.28
local RECALL_RANGE = 34
local RECALL_OUT = 0.42
local RECALL_HANG = 1.2
local RECALL_SPEED = 95
local RECALL_RADIUS = 5

local function slayerRecall(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, 0.45)
	if airborne then
		c.ApplyVelocity(character, HOVER, 0.4)
	end
	fx(ctx, "SlayerRecall", "Wind", { airborne = airborne })
	task.wait(RECALL_RELEASE)
	if interrupted(ctx) then
		fx(ctx, "SlayerRecall", "Cancel")
		return
	end
	local forward = look(ctx)
	local direction = if airborne then (forward + UP * -0.3).Unit else forward
	local origin = ctx.root.Position + direction * 2 + UP * 0.5
	local stop = origin + direction * math.min(waveRange(ctx, origin, direction, RECALL_RANGE), RECALL_RANGE)
	local thrownAt = os.clock()
	local token = c.MoveToken(character)
	local function moved(): boolean
		return c.MoveToken(character) ~= token
	end
	character:SetAttribute("SwordAway", true)
	fx(ctx, "SlayerRecall", "Throw", { origin = origin, target = stop, out = RECALL_OUT })

	local cut: { [Model]: boolean } = {}
	local function sweep(position: Vector3, onHit: (Model) -> ())
		for _, victim in c.Sphere(character, position, RECALL_RADIUS) do
			if not cut[victim] then
				cut[victim] = true
				onHit(victim)
			end
		end
	end

	while os.clock() - thrownAt < RECALL_OUT and not moved() do
		local a = (os.clock() - thrownAt) / RECALL_OUT
		sweep(origin:Lerp(stop, 1 - (1 - a) ^ 2), function(victim)
			c.Hit(character, victim, {
				damage = 8,
				stun = 0.9,
				attackType = "Bolt",
				velocity = direction * 18 + UP * 6,
				velocityTime = 0.15,
			})
		end)
		task.wait()
	end

	while os.clock() - thrownAt < RECALL_OUT + RECALL_HANG do
		if c.PressedSince(character, 2, thrownAt) or moved() or not CombatState.IsAlive(character) then
			break
		end
		task.wait()
	end

	table.clear(cut)
	local position = stop
	if not moved() then
		fx(ctx, "SlayerRecall", "Return", { from = position, speed = RECALL_SPEED })
	end
	local started = os.clock()
	local last = started
	while CombatState.IsAlive(character) and not moved() and os.clock() - started < 1.5 do
		task.wait()
		local now = os.clock()
		local offset = ctx.root.Position - position
		local step = RECALL_SPEED * (now - last)
		last = now
		if offset.Magnitude <= math.max(step, 2.5) then
			break
		end
		position += offset.Unit * step
		sweep(position, function(victim)
			local victimRoot = rootOf(victim)
			local toward = if victimRoot then ctx.root.Position - victimRoot.Position else -direction
			local pull = math.clamp((toward.Magnitude - 5) / 0.3, 0, 110)
			c.Hit(character, victim, {
				damage = 6,
				stun = 1.1,
				attackType = "Bolt",
				heavy = true,
				velocity = c.Flat(toward) * pull + UP * 8,
				velocityTime = 0.3,
			})
		end)
	end
	character:SetAttribute("SwordAway", nil)
	if CombatState.IsAlive(character) then
		fx(ctx, "SlayerRecall", "Catch", { instant = moved() })
	end
end

local CAUSALITY_STAB = 0.42
local CAUSALITY_RADIUS = 18
local CAUSALITY_TARGETS = 4

local function causalityBreak(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, 1.0)
	if airborne then
		c.ApplyVelocity(character, HOVER, CAUSALITY_STAB + 0.35)
	end
	fx(ctx, "CausalityBreak", "Plant", { airborne = airborne })
	task.wait(CAUSALITY_STAB)
	if interrupted(ctx) then
		fx(ctx, "CausalityBreak", "Cancel")
		return
	end

	local center = ctx.root.Position
	local nearby = c.Sphere(character, center, CAUSALITY_RADIUS)
	local function distance(victim: Model): number
		local victimRoot = rootOf(victim)
		return if victimRoot then (victimRoot.Position - center).Magnitude else math.huge
	end
	table.sort(nearby, function(a, b)
		return distance(a) < distance(b)
	end)
	local targets = {}
	for i = 1, math.min(#nearby, CAUSALITY_TARGETS) do
		table.insert(targets, nearby[i])
	end
	fx(ctx, "CausalityBreak", "Break", { targets = targets, airborne = airborne })
	for _, victim in targets do
		c.ClearCounter(victim)
		c.StopWatchingSkills(victim)
		CombatState.SetBlocking(victim, false)
		c.Hit(character, victim, {
			damage = 10,
			stun = 0.8,
			attackType = "Zone",
			unblockable = true,
			heavy = true,
			velocity = UP * 24,
			velocityTime = 0.15,
		})
	end
	c.ShakeArea(center, 45, 0.5)
	task.wait(0.25)
	if CombatState.IsAlive(character) then
		fx(ctx, "CausalityBreak", "Pull")
	end
	CombatState.SetCasting(character, 0.3)
end

local function sceneRay(ctx, origin: Vector3, direction: Vector3, ignore: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = table.clone(ignore)
	table.insert(skip, ctx.character)
	for _ = 1, 4 do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorWhichIsA("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			return hit
		end
		table.insert(skip, model)
	end
	return nil
end

local function floorAt(ctx, position: Vector3, ignore: { Instance }): number
	local hit = sceneRay(ctx, position + UP * 2, UP * -60, ignore)
	return if hit then hit.Position.Y else position.Y - 3
end

local function blackComet(ctx)
	local c, character = ctx.combat, ctx.character
	local times = CometPlan.Times
	local target, release = reachGrab(ctx, times.Length + 0.4, "BlackComet")
	if not target or not release then
		return
	end
	local forward = look(ctx)
	local origin = ctx.root.Position
	local wall = sceneRay(ctx, origin + UP, forward * (CometPlan.Distance + 4), { target })
	local distance = if wall then math.max((wall.Position - (origin + UP)).Magnitude - 4, 4) else CometPlan.Distance
	local plan = CometPlan.Plan(origin, forward, distance, floorAt(ctx, origin, { target }))

	release()
	CombatState.SetCasting(character, times.Length + 0.3)
	CombatState.GiveIFrames(character, times.Length)
	CombatState.Stun(target, times.Length + 0.5)
	fx(ctx, "BlackComet", "Drag", {
		target = target,
		origin = origin,
		forward = forward,
		distance = distance,
		floorY = plan.floorY,
	})
	local stopHim = c.Cutscene({
		[character] = function(t)
			return CometPlan.Attacker(plan, t)
		end,
	}, times.Length)
	local stopThem = c.Cutscene({
		[target] = function(t)
			return CometPlan.Victim(plan, t)
		end,
	}, times.Release)
	local started = os.clock()
	local function waitUntil(at: number): boolean
		task.wait(math.max(at - (os.clock() - started), 0))
		return CombatState.IsAlive(character) and CombatState.IsAlive(target)
	end
	local function abort()
		stopThem()
		stopHim()
		fx(ctx, "BlackComet", "Abort", { target = target })
	end
	for _, at in times.Slams do
		if not waitUntil(at) then
			abort()
			return
		end
		c.Hit(character, target, {
			damage = 2,
			stun = 2,
			attackType = "Melee",
			unblockable = true,
			noShake = true,
			noReaction = true,
		})
	end

	if not waitUntil(times.Release) then
		abort()
		return
	end
	stopThem()
	c.Hit(character, target, {
		damage = 5,
		stun = 1,
		attackType = "Melee",
		unblockable = true,
		heavy = true,
		ragdoll = 1.4,
		noShake = true,
		velocity = forward * 85 + UP * 30,
	})
	waitUntil(times.Length)
	stopHim()
	CombatState.SetCasting(character, 0.3)
end

local ASCENT_STARTUP = 0.14

local function blackAscent(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, ASCENT_STARTUP + 0.3)
	fx(ctx, "BlackAscent", "Cut", { airborne = ctx.airborne })
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, ASCENT_STARTUP + 0.1)
	else
		c.ApplyVelocity(character, look(ctx) * 14, ASCENT_STARTUP)
	end
	task.wait(ASCENT_STARTUP)
	if interrupted(ctx) then
		return
	end
	local target: Model? = nil
	for _, victim in c.Box(character, ctx.root.CFrame * CFrame.new(0, 0.5, -3.5), Vector3.new(6, 7, 6)) do
		if not CombatState.IsRagdolled(victim) then
			target = victim
			break
		end
	end
	local targetRoot = target and rootOf(target)
	if not target or not targetRoot then
		fx(ctx, "BlackAscent", "Whiff")
		CombatState.SetCasting(character, 0.45)
		return
	end
	if c.Hit(character, target, { damage = 2, stun = 1.5, attackType = "Melee", heavy = true }) ~= "Hit" then
		CombatState.SetCasting(character, 0.45)
		return
	end

	local plan = AscentPlan.Plan(ctx.root.CFrame, targetRoot.Position, floorAt(ctx, targetRoot.Position, { target }))
	local times = AscentPlan.Times
	CombatState.SetCasting(character, times.Length + 0.25)
	CombatState.GiveIFrames(character, times.Length)
	CombatState.Stun(target, times.Length + 0.5)
	fx(ctx, "BlackAscent", "Launch", {
		target = target,
		origin = plan.origin,
		start = targetRoot.Position,
		floorY = plan.floorY,
	})
	local stopHim = c.Cutscene({
		[character] = function(t)
			return AscentPlan.Attacker(plan, t)
		end,
	}, times.Length)
	local stopThem = c.Cutscene({
		[target] = function(t)
			return AscentPlan.Victim(plan, t)
		end,
	}, times.Land)
	local started = os.clock()
	local function waitUntil(at: number)
		task.wait(math.max(at - (os.clock() - started), 0))
	end
	for _, at in times.Cuts do
		waitUntil(at)
		if CombatState.IsAlive(target) then
			c.Hit(character, target, {
				damage = 2,
				stun = 1.5,
				attackType = "Melee",
				unblockable = true,
				noShake = true,
				noReaction = true,
			})
		end
	end
	waitUntil(times.Land)
	stopThem()
	if CombatState.IsAlive(target) then
		c.Hit(character, target, {
			damage = 4,
			stun = 1,
			attackType = "Melee",
			unblockable = true,
			heavy = true,
			ragdoll = 1.2,
			noShake = true,
			velocity = UP * -12 + plan.forward * 8,
		})
	end
	waitUntil(times.Length)
	stopHim()
	CombatState.SetCasting(character, 0.25)
end

local ZETTEN_STANCE = 1.0
local ZETTEN_RADIUS = 20

local function zetten(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	local done = false
	CombatState.SetCasting(character, ZETTEN_STANCE + 0.1)
	if airborne then
		c.ApplyVelocity(character, HOVER, ZETTEN_STANCE)
	end
	fx(ctx, "Zetten", "Stance", { airborne = airborne, duration = ZETTEN_STANCE })

	local function strike(target: Model)
		local targetRoot = rootOf(target)
		if done or interrupted(ctx) or not targetRoot or not CombatState.IsAlive(target) then
			return
		end
		done = true
		c.StopWatchingSkills(character)
		c.ClearCounter(character)
		local from = ctx.root.Position
		local through = c.Flat(targetRoot.Position - from)
		local to = targetRoot.Position + through * 4
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, target }
		local wall = workspace:Raycast(targetRoot.Position, through * 4, params)
		if wall then
			to = wall.Position - through * 1.5
		end
		CombatState.GiveIFrames(character, 0.5)
		CombatState.SetCasting(character, 0.55)
		ctx.root.CFrame = CFrame.lookAt(to, to + through)
		c.ApplyVelocity(character, if airborne then HOVER else Vector3.zero, 0.3)
		fx(ctx, "Zetten", "Strike", { from = from, to = to, target = target })
		c.Hit(character, target, {
			damage = 15,
			stun = 1.3,
			attackType = "Melee",
			guardBreak = true,
			heavy = true,
			ragdoll = 1.3,
			velocity = through * 30 + UP * 26,
		})
		c.ShakeArea(to, 50, 0.5)
	end

	c.WatchSkills(character, ZETTEN_RADIUS, ZETTEN_STANCE, strike)
	c.SetCounter(character, ZETTEN_STANCE, { Melee = true }, strike)
	local start = os.clock()
	while not done and os.clock() - start < ZETTEN_STANCE do
		if interrupted(ctx) then
			done = true
			c.StopWatchingSkills(character)
			c.ClearCounter(character)
			fx(ctx, "Zetten", "Cancel")
			return
		end
		task.wait()
	end
	if done then
		return
	end
	done = true
	c.StopWatchingSkills(character)
	c.ClearCounter(character)
	fx(ctx, "Zetten", "Cut", { airborne = airborne })
	for _, victim in c.Box(character, ctx.root.CFrame * CFrame.new(0, 0, -4.5), Vector3.new(9, 7, 9)) do
		c.Hit(character, victim, {
			damage = 7,
			stun = 0.8,
			attackType = "Melee",
			heavy = true,
			velocity = look(ctx) * 30 + UP * 10,
		})
	end
	CombatState.SetCasting(character, 0.35)
end

Kit.Skills = { bullThrust, blackMeteorite, blackDivider, antiMagicDeflect }

local SWORD_MOVES: { [string]: { (any) -> () } } = {
	Slayer = { blackHurricane, slayerRecall },
	Destroyer = { causalityBreak, blackComet },
	Slasher = { blackAscent, zetten },
}
local function swordMove(slot: number): (any) -> ()
	return function(ctx)
		local moves = SWORD_MOVES[ctx.character:GetAttribute("Sword")] or SWORD_MOVES.Slayer
		moves[slot](ctx)
	end
end
Kit.AwakenedSkills = { swordMove(1), swordMove(2), grandDivider, blackMoon }

local SWORD_KINDS = { "Slayer", "Destroyer", "Slasher" }
local SWAP_DRAW = 0.22

function Kit.AwakenedSpecial(ctx)
	local character = ctx.character
	local current = character:GetAttribute("Sword")
	if character:GetAttribute("SwordAway") then
		return
	end
	local index = table.find(SWORD_KINDS, current) or 0
	local kind = SWORD_KINDS[index % #SWORD_KINDS + 1]
	CombatState.SetCasting(character, 0.4)
	fx(ctx, "SwordSwap", "Swap", { sword = kind })
	task.wait(SWAP_DRAW)
	if CombatState.IsAlive(character) and character.Parent then
		setSword(character, kind)
	end
end

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
	local character = ctx.character
	if character:GetAttribute("Sword") ~= "Slayer" and character.Parent then
		setSword(character, "Slayer")
	end
end

return Kit
