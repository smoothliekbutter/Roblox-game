local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatState = require(ReplicatedStorage:WaitForChild("Shared").CombatState)
local SaintPlan = require(ReplicatedStorage:WaitForChild("Shared").SaintZephyr)
local DivePlan = require(ReplicatedStorage:WaitForChild("Shared").TempestDive)
local WaltzPlan = require(ReplicatedStorage:WaitForChild("Shared").Zephyrus)
local Projectile = require(script.Parent.Parent.Projectile)

local KIT_ID = "Wind"
local UP = Vector3.yAxis
local HOVER = Vector3.new(0, 0.05, 0)
local ALL_TYPES = { Melee = true, Bolt = true, Explosion = true, Swarm = true, Zone = true }

local Kit = {}

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

local function rootOf(character: Model): BasePart?
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function interrupted(ctx): boolean
	local character = ctx.character
	return not CombatState.IsAlive(character) or CombatState.IsStunned(character) or CombatState.IsRagdolled(character)
end

local function rayParams(ctx): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.character }
	return params
end

local function isCharacterPart(part: Instance): boolean
	local model = part:FindFirstAncestorWhichIsA("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function reach(ctx, origin: Vector3, direction: Vector3, maxRange: number): number
	local hit = workspace:Raycast(origin, direction * maxRange, rayParams(ctx))
	if hit and not isCharacterPart(hit.Instance) then
		return math.max((hit.Position - origin).Magnitude + 1, 6)
	end
	return maxRange
end

local function floorUnder(ctx, position: Vector3): Vector3
	local params = rayParams(ctx)
	local ignore: { Instance } = { ctx.character }
	for _ = 1, 4 do
		local hit = workspace:Raycast(position + UP * 2, Vector3.new(0, -60, 0), params)
		if not hit then
			break
		end
		local model = hit.Instance:FindFirstAncestorWhichIsA("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			return hit.Position
		end
		table.insert(ignore, model)
		params.FilterDescendantsInstances = ignore
	end
	return position - UP * 3
end

local function softTarget(ctx, range: number, cone: number): Model?
	local forward = look(ctx)
	local minDot = math.cos(math.rad(cone))
	local best, bestDistance = nil, math.huge
	for _, victim in ctx.combat.Sphere(ctx.character, ctx.root.Position, range) do
		local victimRoot = rootOf(victim)
		if victimRoot then
			local offset = victimRoot.Position - ctx.root.Position
			if ctx.combat.Flat(offset):Dot(forward) >= minDot and offset.Magnitude < bestDistance then
				best, bestDistance = victim, offset.Magnitude
			end
		end
	end
	return best
end

local function aimFrom(ctx, origin: Vector3, target: Model?, dip: number): Vector3
	local targetRoot = target and rootOf(target)
	if targetRoot then
		return (targetRoot.Position - origin).Unit
	end
	local forward = look(ctx)
	return if ctx.airborne then (forward + UP * -dip).Unit else forward
end

local function lineVictims(ctx, origin: Vector3, direction: Vector3, length: number, width: number): { Model }
	local box = CFrame.lookAt(origin + direction * (length / 2), origin + direction * length)
	return ctx.combat.Box(ctx.character, box, Vector3.new(width, width + 1, length))
end

local SHOWER_CAST = 0.6
local SHOWER_WAVES = 6
local SHOWER_GAP = 0.15
local SHOWER_RADIUS = 9

local function windBladesShower(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, SHOWER_CAST + 0.25)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, SHOWER_CAST + 0.3)
	end
	local target = softTarget(ctx, 40, 50)
	local targetRoot = target and rootOf(target)
	local center = floorUnder(ctx, if targetRoot then targetRoot.Position else ctx.root.Position + look(ctx) * 18)
	fx(ctx, "WindBladesShower", "Cast", {
		center = center,
		radius = SHOWER_RADIUS,
		waves = SHOWER_WAVES,
		gap = SHOWER_GAP,
		delay = SHOWER_CAST,
		airborne = ctx.airborne,
	})
	task.wait(SHOWER_CAST)
	if interrupted(ctx) then
		fx(ctx, "WindBladesShower", "Cancel")
		return
	end
	for wave = 1, SHOWER_WAVES do
		local last = wave == SHOWER_WAVES
		for _, victim in c.Sphere(character, center + UP * 3, SHOWER_RADIUS + 2) do
			local victimRoot = rootOf(victim)
			local offset = if victimRoot then victimRoot.Position - center else Vector3.zero
			if victimRoot and Vector3.new(offset.X, 0, offset.Z).Magnitude <= SHOWER_RADIUS then
				local aloft = c.IsAirborne(victim)
				c.Hit(character, victim, {
					damage = if last then 2.5 else 1.4,
					stun = if last then 0.8 else 0.5,
					attackType = "Swarm",
					heavy = last,
					velocity = if last then UP * (if aloft then 40 else 26) elseif aloft then HOVER else nil,
					velocityTime = if last then 0.15 else 0.2,
				})
			end
		end
		task.wait(SHOWER_GAP)
	end
end

local HAWK_CAST = 0.22
local HAWK_SPEED = 80
local HAWK_RANGE = 75
local HAWK_TURN = math.rad(140)

local function swiftWhiteHawk(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, HAWK_CAST + 0.2)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, HAWK_CAST + 0.2)
	end
	fx(ctx, "SwiftWhiteHawk", "Cast", { airborne = ctx.airborne })
	task.wait(HAWK_CAST)
	if interrupted(ctx) then
		return
	end
	local target = softTarget(ctx, HAWK_RANGE, 45)
	local position = ctx.root.Position + look(ctx) * 2.5 + UP * 0.6
	local direction = aimFrom(ctx, position, nil, 0.3)
	fx(ctx, "SwiftWhiteHawk", "Fly", {
		origin = position,
		direction = direction,
		target = target,
		speed = HAWK_SPEED,
		turn = HAWK_TURN,
		range = HAWK_RANGE,
	})
	local params = rayParams(ctx)
	local travelled = 0
	local last = os.clock()
	while travelled < HAWK_RANGE do
		task.wait()
		local now = os.clock()
		local dt = now - last
		last = now
		local targetRoot = target and rootOf(target)
		if targetRoot and CombatState.IsAlive(target :: Model) then
			local want = (targetRoot.Position - position).Unit
			local angle = math.acos(math.clamp(direction:Dot(want), -1, 1))
			if angle > 1e-3 then
				direction = direction:Lerp(want, math.min(1, HAWK_TURN * dt / angle)).Unit
			end
		end
		local step = HAWK_SPEED * dt
		local wall = workspace:Raycast(position, direction * step, params)
		if wall and not isCharacterPart(wall.Instance) then
			fx(ctx, "SwiftWhiteHawk", "Burst", { position = wall.Position })
			return
		end
		position += direction * step
		travelled += step
		local victims = c.Sphere(character, position, 3.5)
		if #victims > 0 then
			for _, victim in victims do
				c.Hit(character, victim, {
					damage = 8,
					stun = if airborne then 1.2 else 0.9,
					attackType = "Bolt",
					heavy = true,
					velocity = if airborne then HOVER else c.Flat(direction) * 38 + UP * 14,
					velocityTime = if airborne then 1 else 0.2,
				})
			end
			local offset = position - ctx.root.Position
			if airborne and offset.Magnitude > 5 and not interrupted(ctx) then
				c.ApplyVelocity(character, offset.Unit * math.min((offset.Magnitude - 3) / 0.25, 90), 0.25)
				task.delay(0.25, function()
					if CombatState.IsAlive(character) then
						c.ApplyVelocity(character, HOVER, 0.6)
					end
				end)
			end
			fx(ctx, "SwiftWhiteHawk", "Burst", { position = position })
			return
		end
	end
	fx(ctx, "SwiftWhiteHawk", "Burst", { position = position, fade = true })
end

local ARK_CAST = 0.18
local ARK_RISE = 46
local ARK_RISE_TIME = 0.3
local ARK_HANG = 0.9

local function heavenlyWindArk(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, ARK_CAST + 0.35)
	if airborne then
		c.ApplyVelocity(character, HOVER, ARK_CAST + 0.1)
	end
	fx(ctx, "HeavenlyWindArk", "Cast", { airborne = airborne })
	task.wait(ARK_CAST)
	if interrupted(ctx) then
		return
	end
	local forward = look(ctx)
	fx(ctx, "HeavenlyWindArk", "Rise", { airborne = airborne, origin = ctx.root.Position, direction = forward })
	if airborne then
		for _, victim in c.Box(character, ctx.root.CFrame * CFrame.new(0, -4, -4), Vector3.new(12, 11, 12)) do
			c.Hit(character, victim, {
				damage = 8,
				stun = 1,
				attackType = "Zone",
				guardBreak = true,
				hitsDowned = true,
				heavy = true,
				ragdoll = 1.2,
				velocity = forward * 10 + UP * -70,
			})
		end
		c.ApplyVelocity(character, UP * 18, 0.12)
		return
	end
	local launched = {}
	for _, victim in c.Box(character, ctx.root.CFrame * CFrame.new(0, 1, -5.5), Vector3.new(11, 9, 11)) do
		local result = c.Hit(character, victim, {
			damage = 7,
			stun = 1.6,
			attackType = "Zone",
			guardBreak = true,
			hitsDowned = true,
			heavy = true,
		})
		if result == "Hit" then
			table.insert(launched, victim)
		end
	end
	if #launched == 0 then
		return
	end
	fx(ctx, "HeavenlyWindArk", "Carry", { targets = launched, rise = ARK_RISE_TIME + ARK_HANG })
	for _, victim in launched do
		c.ApplyVelocity(victim, UP * ARK_RISE, ARK_RISE_TIME)
	end
	c.ApplyVelocity(character, UP * ARK_RISE + forward * 3, ARK_RISE_TIME)
	task.wait(ARK_RISE_TIME)
	for _, victim in launched do
		if CombatState.IsAlive(victim) then
			c.ApplyVelocity(victim, HOVER, ARK_HANG)
		end
	end
	if CombatState.IsAlive(character) and not interrupted(ctx) then
		c.ApplyVelocity(character, HOVER, ARK_HANG)
	end
end

local BOW_SLOT = 4
local BOW_DRAW = 0.5
local BOW_ARROWS = 6
local BOW_GAP = 0.12
local GREAT_MIN = 0.2
local GREAT_MAX = 0.6
local GREAT_SPEED = 160
local GREAT_RANGE = 110
local GREAT_SLOW = 2.5

local function greatArrow(ctx)
	local c, character = ctx.combat, ctx.character
	local started = os.clock()
	fx(ctx, "GaleWhiteBow", "Charge", { max = GREAT_MAX })
	while os.clock() - started < GREAT_MAX do
		if interrupted(ctx) then
			fx(ctx, "GaleWhiteBow", "Cancel")
			return
		end
		if os.clock() - started >= GREAT_MIN and not c.IsHeld(character, BOW_SLOT) then
			break
		end
		CombatState.SetCasting(character, 0.4)
		task.wait()
	end
	local drawn = math.clamp((os.clock() - started) / GREAT_MAX, 0, 1)
	local origin = ctx.root.Position + look(ctx) * 2 + UP * 0.8
	local direction = aimFrom(ctx, origin, softTarget(ctx, GREAT_RANGE, 25), 0.3)
	fx(ctx, "GaleWhiteBow", "Great", {
		origin = origin,
		direction = direction,
		speed = GREAT_SPEED,
		range = GREAT_RANGE,
	})
	Projectile.Fire({
		owner = character,
		origin = origin,
		direction = direction,
		speed = GREAT_SPEED,
		range = GREAT_RANGE,
		size = Vector3.new(4, 4, 7),
		pierce = true,
		onHit = function(victim)
			local result = c.Hit(character, victim, {
				damage = 6 + 2 * drawn,
				stun = 1.1,
				attackType = "Bolt",
				guardBreak = true,
				heavy = true,
				ragdoll = 1,
				velocity = c.Flat(direction) * 60 + UP * 22,
			})
			if result == "Hit" or result == "GuardBreak" then
				local slowUntil = math.max(tonumber(victim:GetAttribute("SlowUntil")) or 0, os.clock() + GREAT_SLOW)
				victim:SetAttribute("SlowUntil", slowUntil)
			end
		end,
	})
	c.ApplyVelocity(character, -look(ctx) * 18, 0.12)
	CombatState.SetCasting(character, 0.35)
end

local function galeWhiteBow(ctx)
	local c, character = ctx.combat, ctx.character
	local volley = BOW_DRAW + BOW_ARROWS * BOW_GAP
	CombatState.SetCasting(character, volley + 0.2)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, volley + 0.1)
	end
	fx(ctx, "GaleWhiteBow", "Draw", { airborne = ctx.airborne, draw = BOW_DRAW, arrows = BOW_ARROWS, gap = BOW_GAP })
	task.wait(BOW_DRAW)
	if not ctx.airborne and not interrupted(ctx) and c.IsHeld(character, BOW_SLOT) then
		greatArrow(ctx)
		return
	end
	for i = 1, BOW_ARROWS do
		if interrupted(ctx) then
			fx(ctx, "GaleWhiteBow", "Cancel")
			return
		end
		local last = i == BOW_ARROWS
		local side = ctx.root.CFrame.RightVector * (if i % 2 == 0 then 0.5 else -0.5)
		local origin = ctx.root.Position + look(ctx) * 2 + UP * 0.8 + side
		local direction = aimFrom(ctx, origin, softTarget(ctx, 90, 30), 0.3)
		fx(
			ctx,
			"GaleWhiteBow",
			"Arrow",
			{ origin = origin, direction = direction, speed = 170, range = 90, last = last }
		)
		Projectile.Fire({
			owner = character,
			origin = origin,
			direction = direction,
			speed = 170,
			range = 90,
			size = Vector3.new(2.5, 2.5, 5),
			onHit = function(victim)
				local aloft = c.IsAirborne(victim)
				local push = if last and aloft
					then c.Flat(direction) * 12 + UP * -60
					elseif last then c.Flat(direction) * 40 + UP * 15
					elseif aloft then HOVER
					else c.Flat(direction) * 6
				c.Hit(character, victim, {
					damage = if last then 3 else 2,
					stun = if last then 0.9 else 0.55,
					attackType = "Bolt",
					heavy = last,
					ragdoll = if last and aloft then 1.2 else nil,
					velocity = push,
					velocityTime = if aloft and not last then 0.25 else 0.15,
				})
			end,
		})
		task.wait(BOW_GAP)
	end
	CombatState.SetCasting(character, 0.2)
end

local STAR_DISTANCE = 22
local STAR_LIFE = 4

function Kit.Special(ctx)
	local c, character = ctx.combat, ctx.character
	local velocity = ctx.root.AssemblyLinearVelocity
	local moving = Vector3.new(velocity.X, 0, velocity.Z)
	local direction = if moving.Magnitude > 4 then moving.Unit else look(ctx)
	local origin = ctx.root.Position
	local wall = workspace:Raycast(origin, direction * STAR_DISTANCE, rayParams(ctx))
	local star = if wall and not isCharacterPart(wall.Instance)
		then wall.Position - direction * 2
		else origin + direction * STAR_DISTANCE
	local placedAt = os.clock()
	local since = placedAt
	fx(ctx, "Conjunction", "Place", { origin = origin, star = star, life = STAR_LIFE })
	while os.clock() - placedAt < STAR_LIFE and CombatState.IsAlive(character) do
		task.wait()
		if c.PressedSince(character, CombatState.SpecialSlot, since) then
			if not CombatState.CanAct(character) or CombatState.IsCasting(character) then
				since = os.clock()
				continue
			end
			local from = ctx.root.Position
			CombatState.GiveIFrames(character, 0.3)
			ctx.root.CFrame = CFrame.lookAt(star, star + c.Flat(ctx.root.CFrame.LookVector))
			c.ApplyVelocity(character, Vector3.zero, 0.05)
			fx(ctx, "Conjunction", "Warp", { from = from, star = star })
			return
		end
	end
	fx(ctx, "Conjunction", "Fade", { star = star })
end

local STORM_CHARGE = 0.45
local STORM_TICKS = 6
local STORM_TICK = 0.1
local STORM_LENGTH = 50

local function spiritStorm(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	local beam = STORM_TICKS * STORM_TICK
	CombatState.SetCasting(character, STORM_CHARGE + beam + 0.3)
	if airborne then
		c.ApplyVelocity(character, HOVER, STORM_CHARGE + beam + 0.1)
	end
	fx(ctx, "SpiritStorm", "Charge", { airborne = airborne, duration = STORM_CHARGE })
	task.wait(STORM_CHARGE)
	if interrupted(ctx) then
		fx(ctx, "SpiritStorm", "Cancel")
		return
	end
	local origin = ctx.root.Position + look(ctx) * 2 + UP * 0.6
	local direction = aimFrom(ctx, origin, softTarget(ctx, STORM_LENGTH, 25), 0.4)
	local length = reach(ctx, origin, direction, STORM_LENGTH)
	fx(ctx, "SpiritStorm", "Fire", { origin = origin, direction = direction, length = length, duration = beam })
	for tick = 1, STORM_TICKS do
		local last = tick == STORM_TICKS
		for _, victim in lineVictims(ctx, origin, direction, length, 5) do
			c.Hit(character, victim, {
				damage = if last then 3 else 1.6,
				stun = if last then 1 else 0.45,
				attackType = "Bolt",
				heavy = last,
				velocity = direction * (if last then 55 else 22) + UP * (if last then 18 else 2),
				velocityTime = if last then 0.2 else 0.12,
			})
		end
		task.wait(STORM_TICK)
	end
	CombatState.SetCasting(character, 0.25)
end

local DIVE_REACH = 0.16

local function tempestDive(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, DIVE_REACH + 0.5)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, DIVE_REACH + 0.3)
	end
	fx(ctx, "TempestDive", "Reach")
	task.wait(DIVE_REACH)
	if interrupted(ctx) then
		return
	end
	local target: Model? = nil
	for _, victim in c.Box(character, ctx.root.CFrame * CFrame.new(0, 0, -3.5), Vector3.new(6, 7, 7)) do
		if not CombatState.HasIFrames(victim) and not CombatState.IsRagdolled(victim) then
			target = victim
			break
		end
	end
	local targetRoot = target and rootOf(target)
	if
		not target
		or not targetRoot
		or c.Hit(
				character,
				target,
				{ damage = 2, stun = 3, attackType = "Melee", unblockable = true, noShake = true }
			)
			~= "Hit"
	then
		fx(ctx, "TempestDive", "Whiff")
		CombatState.SetCasting(character, 0.55)
		return
	end

	local origin = ctx.root.CFrame + UP * SaintPlan.Lift
	local plan = DivePlan.Plan(origin, targetRoot.Position, floorUnder(ctx, targetRoot.Position).Y)
	local times = DivePlan.Times
	CombatState.SetCasting(character, times.Length + 0.25)
	CombatState.GiveIFrames(character, times.Length + 0.15)
	CombatState.Stun(target, times.Land + 0.6)
	fx(ctx, "TempestDive", "Begin", { target = target, origin = plan.origin, start = plan.start, floorY = plan.floorY })
	local stopHim = c.Cutscene({
		[character] = function(t)
			return DivePlan.Attacker(plan, t)
		end,
	}, times.Length)
	local stopThem = c.Cutscene({
		[target] = function(t)
			return DivePlan.Victim(plan, t)
		end,
	}, times.Land)
	local started = os.clock()
	local function waitUntil(at: number)
		task.wait(math.max(at - (os.clock() - started), 0))
	end
	for _, at in times.Ticks do
		waitUntil(at)
		if CombatState.IsAlive(target) then
			c.Hit(
				character,
				target,
				{ damage = 1.4, stun = 3, attackType = "Melee", unblockable = true, noShake = true }
			)
		end
	end

	waitUntil(times.Land)
	stopThem()
	local impact = Vector3.new(plan.start.X, plan.floorY, plan.start.Z)
	if CombatState.IsAlive(target) then
		c.Hit(character, target, {
			damage = 12,
			stun = 1.4,
			attackType = "Melee",
			unblockable = true,
			heavy = true,
			ragdoll = 2,
			velocity = UP * 26 + plan.forward * 8,
		})
		c.ChargeAscension(character, 1)
	end
	fx(ctx, "TempestDive", "Impact", { position = impact })
	c.ShakeArea(impact, 70, 0.7)
	waitUntil(times.Length)
	stopHim()
end

local SCUTUM_TIME = 2.5

local function quartileScutum(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, SCUTUM_TIME)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, SCUTUM_TIME)
	end
	local raisedAt = os.clock()
	fx(ctx, "QuartileScutum", "Raise", { duration = SCUTUM_TIME })
	local function inFront(attacker: Model): boolean
		local attackerRoot = rootOf(attacker)
		return attackerRoot ~= nil and c.Flat(attackerRoot.Position - ctx.root.Position):Dot(look(ctx)) > 0.1
	end
	local function absorb(attacker: Model, hit: any)
		local attackerRoot = rootOf(attacker)
		fx(ctx, "QuartileScutum", "Block", { from = if attackerRoot then attackerRoot.Position else nil })
		local damage = (tonumber(hit.damage) or 0) * 2
		if attackerRoot and damage > 0 and not hit.reflected and CombatState.IsAlive(attacker) then
			local origin = ctx.root.Position + look(ctx) * 3.2 + UP * 0.5
			local offset = attackerRoot.Position - origin
			if offset.Magnitude < 14 then
				fx(ctx, "QuartileScutum", "Reflect", { origin = origin, target = attackerRoot.Position })
				c.Hit(character, attacker, {
					damage = damage,
					stun = 0.8,
					attackType = "Zone",
					unblockable = true,
					reflected = true,
					heavy = damage >= 8,
					velocity = c.Flat(offset) * 45 + UP * 12,
					velocityTime = 0.18,
				})
			else
				local direction = offset.Unit
				local range = offset.Magnitude + 10
				fx(
					ctx,
					"QuartileScutum",
					"Reflect",
					{ origin = origin, direction = direction, speed = 150, range = range }
				)
				Projectile.Fire({
					owner = character,
					origin = origin,
					direction = direction,
					speed = 150,
					range = range,
					size = Vector3.new(3, 3, 4),
					onHit = function(victim)
						c.Hit(character, victim, {
							damage = damage,
							stun = 0.8,
							attackType = "Bolt",
							reflected = true,
							heavy = damage >= 8,
							velocity = c.Flat(direction) * 35 + UP * 10,
							velocityTime = 0.18,
						})
					end,
				})
			end
		end
		local left = SCUTUM_TIME - (os.clock() - raisedAt)
		if left > 0.05 then
			c.SetCounter(character, left, ALL_TYPES, absorb, inFront)
		end
	end
	c.SetCounter(character, SCUTUM_TIME, ALL_TYPES, absorb, inFront)
	task.wait(SCUTUM_TIME)
	c.ClearCounter(character)
	fx(ctx, "QuartileScutum", "Drop")
end

local NOVA_SLOT = 4
local NOVA_CAST = 0.28
local NOVA_SPEED = 120
local NOVA_RANGE = 45
local NOVA_AHEAD = 24
local NOVA_PULL = 22
local NOVA_EYE = 5
local NOVA_LIFT = 4
local NOVA_OPEN = 1.1
local NOVA_HELD = 2.2
local NOVA_TICK = 0.1
local NOVA_CUT = 0.25
local NOVA_COLLAPSE = 0.15
local NOVA_BLAST = 9

local function novaVortex(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, NOVA_CAST + 0.15)
	if airborne then
		c.ApplyVelocity(character, HOVER, NOVA_CAST + 0.1)
	end
	fx(ctx, "NovaVortex", "Form", { airborne = airborne })
	task.wait(NOVA_CAST)
	if interrupted(ctx) then
		fx(ctx, "NovaVortex", "Cancel")
		return
	end

	local forward = look(ctx)
	local aimed = softTarget(ctx, NOVA_RANGE, 35)
	local aimedRoot = aimed and rootOf(aimed)
	local from = ctx.root.Position + forward * 2 + UP * 1.5
	local spot = if aimedRoot then aimedRoot.Position else ctx.root.Position + forward * NOVA_AHEAD
	local flat = c.Flat(spot - ctx.root.Position)
	local along = if flat.Magnitude > 1e-3 then flat.Unit else forward
	local distance = math.min(flat.Magnitude, reach(ctx, from, along, NOVA_RANGE))
	local ground = floorUnder(ctx, ctx.root.Position + along * math.max(distance, 4))
	local eye = ground + UP * 2.5
	local flight = math.clamp((eye - from).Magnitude / NOVA_SPEED, 0.08, 0.45)
	fx(ctx, "NovaVortex", "Throw", { from = from, eye = eye, flight = flight })
	task.wait(flight)
	if not CombatState.IsAlive(character) then
		fx(ctx, "NovaVortex", "Fizzle")
		return
	end

	fx(ctx, "NovaVortex", "Open", { eye = eye, ground = ground, reach = NOVA_PULL })
	local opened = os.clock()
	local lastCut = -1
	local hold = ground + UP * (NOVA_LIFT + 3)
	while true do
		local t = os.clock() - opened
		if not CombatState.IsAlive(character) then
			fx(ctx, "NovaVortex", "Fizzle")
			return
		end
		if t >= NOVA_HELD or (t >= NOVA_OPEN and not c.IsHeld(character, NOVA_SLOT)) then
			break
		end
		local cut = t - lastCut >= NOVA_CUT
		if cut then
			lastCut = t
		end
		for _, victim in c.Sphere(character, eye, NOVA_PULL) do
			local victimRoot = rootOf(victim)
			if victimRoot then
				local offset = hold - victimRoot.Position
				local level = Vector3.new(offset.X, 0, offset.Z)
				if level.Magnitude < NOVA_EYE then
					local pull = offset / 0.15
					c.ApplyVelocity(victim, if pull.Magnitude > 40 then pull.Unit * 40 else pull, NOVA_TICK + 0.05)
					if cut then
						c.Hit(character, victim, { damage = 0.6, stun = 0.6, attackType = "Zone", noShake = true })
					end
				elseif level.Magnitude > 1e-3 then
					local strength = 16 + 20 * (1 - level.Magnitude / NOVA_PULL)
					c.ApplyVelocity(victim, level.Unit * strength + UP * 2, NOVA_TICK + 0.05)
				end
			end
		end
		task.wait(NOVA_TICK)
	end

	fx(ctx, "NovaVortex", "Nova", { eye = eye, ground = ground })
	task.wait(NOVA_COLLAPSE)
	for _, victim in c.Sphere(character, eye + UP * 2, NOVA_BLAST) do
		local victimRoot = rootOf(victim)
		local out = if victimRoot then c.Flat(victimRoot.Position - eye) else Vector3.zero
		c.Hit(character, victim, {
			damage = 5,
			stun = 1,
			attackType = "Explosion",
			guardBreak = true,
			heavy = true,
			ragdoll = 1.2,
			velocity = UP * 72 + (if out.Magnitude > 1e-3 then out.Unit * 6 else Vector3.zero),
		})
	end
	c.ShakeArea(eye, 45, 0.35)
end

local BOREAS_RAISE = 0.42
local BOREAS_REACH = 28
local BOREAS_WIDTH = 7

local function spiritOfBoreas(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, BOREAS_RAISE + 0.6)
	if airborne then
		c.ApplyVelocity(character, HOVER, BOREAS_RAISE + 0.25)
	end
	fx(ctx, "SpiritOfBoreas", "Raise", { airborne = airborne, duration = BOREAS_RAISE })
	task.wait(BOREAS_RAISE)
	if interrupted(ctx) then
		fx(ctx, "SpiritOfBoreas", "Cancel")
		return
	end
	local forward = look(ctx)
	local direction = if airborne then (forward - UP * 0.8).Unit else forward
	local origin = ctx.root.Position + forward * 1.5
	local length = reach(ctx, origin, direction, BOREAS_REACH)
	fx(ctx, "SpiritOfBoreas", "Chop", { origin = origin, direction = direction, length = length, airborne = airborne })
	for _, victim in lineVictims(ctx, origin, direction, length, BOREAS_WIDTH) do
		c.Hit(character, victim, {
			damage = 10,
			stun = 1.2,
			attackType = "Melee",
			guardBreak = true,
			hitsDowned = true,
			heavy = true,
			ragdoll = 1,
			velocity = if airborne then forward * 10 + UP * -45 else forward * 8 + UP * 38,
		})
	end
	c.ShakeArea(origin + direction * length * 0.5, 55, 0.45)
	task.wait(0.15)
	CombatState.SetCasting(character, 0.4)
end

local LUNGE_SPEED = 100
local LUNGE_TIME = 0.34
local LUNGE_STEER = 180

local function spiritOfZephyrus(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	local forward = look(ctx)
	local aimed = softTarget(ctx, 30, 35)
	local aimedRoot = aimed and rootOf(aimed)
	local direction = if aimedRoot
		then (aimedRoot.Position - ctx.root.Position).Unit
		elseif airborne then (forward - UP * 0.5).Unit
		else forward
	if not airborne then
		direction = c.Flat(direction)
	end
	CombatState.SetCasting(character, LUNGE_TIME + 0.3)
	fx(ctx, "SpiritOfZephyrus", "Lunge", { direction = direction, duration = LUNGE_TIME, airborne = airborne })
	c.ApplyVelocity(
		character,
		direction * LUNGE_SPEED,
		LUNGE_TIME,
		{ steer = LUNGE_STEER, landStop = direction.Y < 0, landKeep = 0.4 }
	)
	local start = os.clock()
	local target: Model? = nil
	while os.clock() - start < LUNGE_TIME + 0.05 do
		if interrupted(ctx) then
			return
		end
		local hits = c.Box(character, ctx.root.CFrame * CFrame.new(0, 0, -3.5), Vector3.new(6, 7, 7))
		if #hits > 0 then
			target = hits[1]
			break
		end
		task.wait()
	end
	if not target then
		fx(ctx, "SpiritOfZephyrus", "Whiff")
		CombatState.SetCasting(character, 0.45)
		return
	end
	c.ApplyVelocity(character, Vector3.zero, 0.05)
	if c.Hit(character, target, { damage = 3, stun = 1.4, attackType = "Melee" }) ~= "Hit" then
		fx(ctx, "SpiritOfZephyrus", "Whiff")
		CombatState.SetCasting(character, 0.4)
		return
	end
	local caught = target :: Model
	local caughtRoot = rootOf(caught)
	if not caughtRoot then
		return
	end

	local plan = WaltzPlan.Plan(ctx.root.Position, caughtRoot.Position)
	local times = WaltzPlan.Times
	CombatState.SetCasting(character, times.Length + 0.2)
	CombatState.GiveIFrames(character, times.Length)
	CombatState.Stun(caught, times.Length + 0.4)
	fx(ctx, "SpiritOfZephyrus", "Waltz", {
		target = caught,
		attacker = ctx.root.Position,
		victim = caughtRoot.Position,
	})
	local stopHim = c.Cutscene({
		[character] = function(t)
			return WaltzPlan.Attacker(plan, t)
		end,
	}, times.Length)
	local stopThem = c.Cutscene({
		[caught] = function(t)
			return WaltzPlan.Victim(plan, t)
		end,
	}, times.Thrust)
	local started = os.clock()
	local function waitUntil(at: number): boolean
		task.wait(math.max(at - (os.clock() - started), 0))
		return CombatState.IsAlive(character) and CombatState.IsAlive(caught)
	end
	local function abort()
		stopThem()
		stopHim()
		fx(ctx, "SpiritOfZephyrus", "Abort", { target = caught })
	end
	for _, at in times.Cuts do
		if not waitUntil(at) then
			abort()
			return
		end
		c.Hit(character, caught, {
			damage = 1.2,
			stun = 1.2,
			attackType = "Melee",
			unblockable = true,
			noShake = true,
			noReaction = true,
		})
	end
	if not waitUntil(times.Thrust) then
		abort()
		return
	end
	stopThem()
	c.Hit(character, caught, {
		damage = 4.5,
		stun = 1,
		attackType = "Melee",
		unblockable = true,
		heavy = true,
		ragdoll = 1.2,
		noShake = true,
		velocity = -plan.out * 70 + UP * 22,
	})
	waitUntil(times.Length)
	stopHim()
	CombatState.SetCasting(character, 0.25)
end

local EUROS_DRAW = 0.8
local EUROS_RANGE = 120

local function spiritOfEuros(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, EUROS_DRAW + 0.35)
	if airborne then
		c.ApplyVelocity(character, HOVER, EUROS_DRAW + 0.2)
	else
		character:SetAttribute("Rooted", true)
	end
	fx(ctx, "SpiritOfEuros", "Draw", { airborne = airborne, duration = EUROS_DRAW })
	task.wait(EUROS_DRAW)
	character:SetAttribute("Rooted", false)
	if interrupted(ctx) then
		fx(ctx, "SpiritOfEuros", "Cancel")
		return
	end
	local origin = ctx.root.Position + look(ctx) * 2 + UP * 0.8
	local direction = aimFrom(ctx, origin, softTarget(ctx, EUROS_RANGE, 20), 0.3)
	local length = reach(ctx, origin, direction, EUROS_RANGE)
	fx(ctx, "SpiritOfEuros", "Loose", { origin = origin, direction = direction, length = length })
	for _, victim in lineVictims(ctx, origin, direction, length, 6) do
		c.Hit(character, victim, {
			damage = 16,
			stun = 1.3,
			attackType = "Bolt",
			unblockable = true,
			heavy = true,
			ragdoll = 1.4,
			velocity = c.Flat(direction) * 70 + UP * 14,
		})
	end
	c.ShakeArea(origin, 40, 0.35)
end

local SAINT_FLICK = 0.2
local SAINT_BOX = Vector3.new(5, 7, 15)

local function saintSpiritOfZephyr(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, SAINT_FLICK + 0.5)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, SAINT_FLICK + 0.3)
	end
	fx(ctx, "SaintSpiritOfZephyr", "Flick", { range = SAINT_BOX.Z })
	task.wait(SAINT_FLICK)
	if interrupted(ctx) then
		return
	end
	local target: Model? = nil
	local nearest = math.huge
	for _, victim in c.Box(character, ctx.root.CFrame * CFrame.new(0, 0, -SAINT_BOX.Z / 2), SAINT_BOX) do
		local victimRoot = rootOf(victim)
		local distance = if victimRoot then (victimRoot.Position - ctx.root.Position).Magnitude else math.huge
		if not CombatState.HasIFrames(victim) and not CombatState.IsRagdolled(victim) and distance < nearest then
			target, nearest = victim, distance
		end
	end
	local targetRoot = target and rootOf(target)
	if
		not target
		or not targetRoot
		or c.Hit(
				character,
				target,
				{ damage = 2, stun = 4, attackType = "Melee", unblockable = true, noShake = true }
			)
			~= "Hit"
	then
		fx(ctx, "SaintSpiritOfZephyr", "Whiff")
		CombatState.SetCasting(character, 0.55)
		return
	end

	local origin = ctx.root.CFrame + UP * SaintPlan.Lift
	local plan = SaintPlan.Plan(origin, targetRoot.Position, floorUnder(ctx, targetRoot.Position).Y)
	local times = SaintPlan.Times
	CombatState.SetCasting(character, times.Length + 0.3)
	CombatState.GiveIFrames(character, times.Length + 0.2)
	CombatState.Stun(target, times.Length + 0.6)
	fx(ctx, "SaintSpiritOfZephyr", "Begin", {
		target = target,
		origin = plan.origin,
		start = targetRoot.Position,
		floorY = plan.floorY,
	})
	local stopHim = c.Cutscene({
		[character] = function(t)
			return SaintPlan.Attacker(plan, t)
		end,
	}, times.Length)
	local stopThem = c.Cutscene({
		[target] = function(t)
			return SaintPlan.Victim(plan, t)
		end,
	}, times.Land)
	local started = os.clock()
	local function waitUntil(at: number)
		task.wait(math.max(at - (os.clock() - started), 0))
	end
	local function cut(damage: number)
		if CombatState.IsAlive(target) then
			c.Hit(
				character,
				target,
				{ damage = damage, stun = 3, attackType = "Melee", unblockable = true, noShake = true }
			)
		end
	end
	for _, at in times.Cuts do
		waitUntil(at)
		cut(1.35)
	end
	waitUntil(times.Cross)
	cut(2)
	waitUntil(times.Strike)
	if CombatState.IsAlive(target) then
		c.Hit(character, target, { damage = 3, stun = 3, attackType = "Melee", unblockable = true, noShake = true })
	end

	waitUntil(times.Land)
	stopThem()
	local center = Vector3.new(plan.start.X, plan.floorY, plan.start.Z)
	if CombatState.IsAlive(target) then
		c.Hit(character, target, {
			damage = 10,
			stun = 1.4,
			attackType = "Melee",
			unblockable = true,
			heavy = true,
			ragdoll = 2.4,
			velocity = UP * -20 + plan.forward * 4,
		})
	end
	fx(ctx, "SaintSpiritOfZephyr", "Impact", { position = center })
	c.ShakeArea(center, 90, 0.8)
	waitUntil(times.Length)
	stopHim()
end

Kit.Skills = { windBladesShower, swiftWhiteHawk, heavenlyWindArk, galeWhiteBow }

local HALF_CROWN = { spiritStorm, tempestDive, quartileScutum, novaVortex }
local FULL_CROWN = { spiritOfBoreas, spiritOfZephyrus, spiritOfEuros, saintSpiritOfZephyr }
local function stageMove(slot: number): (any) -> ()
	return function(ctx)
		local moves = if ctx.character:GetAttribute("Ascended") == true then FULL_CROWN else HALF_CROWN
		moves[slot](ctx)
	end
end
Kit.AwakenedSkills = { stageMove(1), stageMove(2), stageMove(3), stageMove(4) }

local TRANSFORM_TIME = 1.5
local TRANSFORM_BURST = 0.8

local function transform(ctx, skill: string, radius: number)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, TRANSFORM_TIME)
	CombatState.GiveIFrames(character, TRANSFORM_TIME + 0.1)
	character:SetAttribute("Rooted", true)
	fx(ctx, skill, "Start")
	c.ShakeArea(ctx.root.Position, 30, 0.2)
	task.wait(TRANSFORM_BURST)
	if CombatState.IsAlive(character) then
		fx(ctx, skill, "Burst")
		c.ShakeArea(ctx.root.Position, 70, 0.6)
		for _, victim in c.Sphere(character, ctx.root.Position, radius) do
			local victimRoot = rootOf(victim)
			if victimRoot and not CombatState.HasIFrames(victim) and not CombatState.IsRagdolled(victim) then
				c.ApplyVelocity(victim, c.Flat(victimRoot.Position - ctx.root.Position) * 55 + UP * 18, 0.2)
			end
		end
	end
	task.wait(TRANSFORM_TIME - TRANSFORM_BURST)
	if character.Parent then
		character:SetAttribute("Rooted", false)
	end
end

function Kit.Awaken(ctx)
	transform(ctx, "Awaken", 14)
end

function Kit.Ascend(ctx)
	transform(ctx, "Ascend", 18)
end

local ENTRANCE_TIME = 2.2

function Kit.Entrance(ctx)
	local character = ctx.character
	CombatState.SetCasting(character, ENTRANCE_TIME)
	CombatState.GiveIFrames(character, ENTRANCE_TIME + 0.1)
	character:SetAttribute("Rooted", true)
	fx(ctx, "Entrance", "Start")
	task.wait(ENTRANCE_TIME)
	if character.Parent then
		character:SetAttribute("Rooted", false)
	end
end

function Kit.AwakenEnd(ctx)
	fx(ctx, "Awaken", "End")
end

function Kit.Unequip(character: Model)
	for _, attribute in { "PowerUntil", "WeakUntil", "SlowUntil", "Rooted" } do
		character:SetAttribute(attribute, nil)
	end
end

return Kit
