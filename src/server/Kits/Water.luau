local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatState = require(ReplicatedStorage:WaitForChild("Shared").CombatState)
local DivePlan = require(ReplicatedStorage:WaitForChild("Shared").MermaidDive)
local Projectile = require(script.Parent.Parent.Projectile)

local KIT_ID = "Water"
local UP = Vector3.yAxis
local HOVER = Vector3.new(0, 0.05, 0)
local ALL_TYPES = { Melee = true, Bolt = true, Explosion = true, Swarm = true, Zone = true }
local SPELLS = { Bolt = true, Explosion = true, Swarm = true, Zone = true }
local PURIFY = 1.25

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

local function level(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function outward(vector: Vector3, fallback: Vector3): Vector3
	local flat = level(vector)
	return if flat.Magnitude > 0.5 then flat.Unit else fallback
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

local function devil(victim: Model): boolean
	return victim:GetAttribute("Kit") == "AntiMagic" and victim:GetAttribute("Awakened") == true
end

local function strike(ctx, victim: Model, hit: { [string]: any }): string
	local character = ctx.character
	local purifying = character:GetAttribute("Ascended") == true and devil(victim)
	if purifying then
		hit.damage *= PURIFY
	end
	local result = ctx.combat.Hit(character, victim, hit :: any)
	if purifying and result == "Hit" then
		fx(ctx, "Purify", "Hit", { victim = victim })
	end
	return result
end

local BALL_CAST = 0.32
local BALL_GAP = 0.18
local BALL_RANGE = 70

type Ball = { size: number, speed: number, damage: number, splash: number, splashDamage: number, big: boolean }
local BALLS: { Ball } = {
	{ size = 3, speed = 95, damage = 2, splash = 4, splashDamage = 1, big = false },
	{ size = 3, speed = 95, damage = 2, splash = 4, splashDamage = 1, big = false },
	{ size = 5, speed = 85, damage = 3, splash = 7, splashDamage = 2, big = true },
}
local thrown = 0

local function waterball(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	local volley = BALL_CAST + (#BALLS - 1) * BALL_GAP
	CombatState.SetCasting(character, volley + 0.25)
	if airborne then
		c.ApplyVelocity(character, HOVER, volley + 0.2)
	end
	fx(ctx, "Waterball", "Cast", { airborne = airborne, delay = BALL_CAST, gap = BALL_GAP, count = #BALLS })
	task.wait(BALL_CAST)
	for index, ball in BALLS do
		if interrupted(ctx) then
			fx(ctx, "Waterball", "Cancel")
			return
		end
		thrown += 1
		local id = thrown
		local side = if index == 1 then 1.4 elseif index == 2 then -1.4 else 0
		local origin = ctx.root.Position
			+ look(ctx) * 2.5
			+ ctx.root.CFrame.RightVector * side
			+ UP * (if ball.big then 2.4 else 1.4)
		local direction = aimFrom(ctx, origin, softTarget(ctx, BALL_RANGE, 45), 0.35)
		fx(ctx, "Waterball", "Throw", {
			id = id,
			index = index,
			origin = origin,
			direction = direction,
			speed = ball.speed,
			range = BALL_RANGE,
			big = ball.big,
		})
		local struck: Model? = nil
		Projectile.Fire({
			owner = character,
			origin = origin,
			direction = direction,
			speed = ball.speed,
			range = BALL_RANGE,
			size = Vector3.one * ball.size,
			onHit = function(victim)
				struck = victim
				local aloft = c.IsAirborne(victim)
				strike(ctx, victim, {
					damage = ball.damage,
					stun = if ball.big then 1 else 0.6,
					attackType = "Bolt",
					heavy = ball.big,
					ragdoll = if ball.big then 1 else nil,
					velocity = if ball.big
						then c.Flat(direction) * 55 + UP * 22
						elseif aloft then HOVER
						else c.Flat(direction) * 8,
					velocityTime = if ball.big then 0.2 elseif aloft then 0.25 else 0.12,
				})
			end,
			onEnd = function(position)
				fx(ctx, "Waterball", "Splash", { id = id, position = position, big = ball.big })
				for _, victim in c.Sphere(character, position, ball.splash) do
					local victimRoot = rootOf(victim)
					if victim ~= struck and victimRoot then
						local out = outward(victimRoot.Position - position, c.Flat(direction))
						strike(ctx, victim, {
							damage = ball.splashDamage,
							stun = 0.5,
							attackType = "Bolt",
							velocity = out * (if ball.big then 30 else 12) + UP * (if ball.big then 12 else 4),
							velocityTime = 0.15,
						})
					end
				end
				if ball.big then
					c.ShakeArea(position, 35, 0.3)
				end
			end,
		})
		if index < #BALLS then
			task.wait(BALL_GAP)
		end
	end
	CombatState.SetCasting(character, 0.2)
end

local ROAR_CAST = 0.55
local ROAR_SPEED = 100
local ROAR_RANGE = 80
local ROAR_SIZE = Vector3.new(8, 8, 10)

local function seaDragonsRoar(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, ROAR_CAST + 0.4)
	if airborne then
		c.ApplyVelocity(character, HOVER, ROAR_CAST + 0.3)
	end
	fx(ctx, "SeaDragonsRoar", "Cast", { airborne = airborne, delay = ROAR_CAST })
	task.wait(ROAR_CAST)
	if interrupted(ctx) then
		fx(ctx, "SeaDragonsRoar", "Cancel")
		return
	end
	local origin = ctx.root.Position + look(ctx) * 3 + UP * 2
	local direction = aimFrom(ctx, origin, softTarget(ctx, ROAR_RANGE, 35), 0.35)
	fx(
		ctx,
		"SeaDragonsRoar",
		"Fire",
		{ origin = origin, direction = direction, speed = ROAR_SPEED, range = ROAR_RANGE }
	)
	Projectile.Fire({
		owner = character,
		origin = origin,
		direction = direction,
		speed = ROAR_SPEED,
		range = ROAR_RANGE,
		size = ROAR_SIZE,
		pierce = true,
		onHit = function(victim)
			strike(ctx, victim, {
				damage = 8,
				stun = 1.1,
				attackType = "Bolt",
				guardBreak = true,
				heavy = true,
				ragdoll = 1.2,
				velocity = c.Flat(direction) * 60 + UP * 25,
			})
		end,
		onEnd = function(position)
			fx(ctx, "SeaDragonsRoar", "Crash", { position = position, direction = direction })
			c.ShakeArea(position, 40, 0.3)
		end,
	})
	c.ApplyVelocity(character, -c.Flat(direction) * 14 + (if airborne then UP * 4 else Vector3.zero), 0.15)
	CombatState.SetCasting(character, 0.35)
end

local BLANK_CAST = 0.25
local BLANK_LENGTH = 14
local BLANK_WIDTH = 9

local function pointBlankRoar(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, BLANK_CAST + 0.5)
	if airborne then
		c.ApplyVelocity(character, HOVER, BLANK_CAST + 0.1)
	end
	fx(ctx, "PointBlankRoar", "Cast", { airborne = airborne, delay = BLANK_CAST })
	task.wait(BLANK_CAST)
	if interrupted(ctx) then
		fx(ctx, "PointBlankRoar", "Cancel")
		return
	end
	local origin = ctx.root.Position + look(ctx) * 1.5 + UP * 0.6
	local direction = if airborne then aimFrom(ctx, origin, softTarget(ctx, BLANK_LENGTH + 6, 50), 0.6) else look(ctx)
	fx(ctx, "PointBlankRoar", "Blast", {
		origin = origin,
		direction = direction,
		length = BLANK_LENGTH,
		airborne = airborne,
	})
	local box = CFrame.lookAt(origin + direction * (BLANK_LENGTH / 2), origin + direction * BLANK_LENGTH)
	for _, victim in c.Box(character, box, Vector3.new(BLANK_WIDTH, BLANK_WIDTH, BLANK_LENGTH)) do
		local aloft = c.IsAirborne(victim)
		strike(ctx, victim, {
			damage = 9,
			stun = 1.2,
			attackType = "Explosion",
			unblockable = true,
			heavy = true,
			ragdoll = 1.4,
			velocity = if direction.Y < -0.2
				then direction * 90
				else c.Flat(direction) * 85 + UP * (if aloft then 20 else 30),
		})
	end
	c.ApplyVelocity(character, -c.Flat(direction) * 30 + (if airborne then UP * 12 else Vector3.zero), 0.18)
	c.ShakeArea(origin + direction * 6, 45, 0.45)
	CombatState.SetCasting(character, 0.3)
end

local NEST_TIME = 2.5
local NEST_RADIUS = 9
local NEST_TICK = 0.4

local function seaDragonsNest(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, NEST_TIME)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, NEST_TIME)
	end
	local raisedAt = os.clock()
	fx(ctx, "SeaDragonsNest", "Raise", { duration = NEST_TIME, radius = NEST_RADIUS })
	local function repel(attacker: Model, hit: any)
		local attackerRoot = rootOf(attacker)
		fx(ctx, "SeaDragonsNest", "Block", { from = if attackerRoot then attackerRoot.Position else nil })
		if
			attackerRoot
			and not hit.reflected
			and CombatState.IsAlive(attacker)
			and (attackerRoot.Position - ctx.root.Position).Magnitude < NEST_RADIUS + 6
		then
			strike(ctx, attacker, {
				damage = 1.5,
				stun = 0.6,
				attackType = "Zone",
				unblockable = true,
				reflected = true,
				velocity = outward(attackerRoot.Position - ctx.root.Position, look(ctx)) * 45 + UP * 12,
				velocityTime = 0.18,
			})
		end
		local left = NEST_TIME - (os.clock() - raisedAt)
		if left > 0.05 then
			c.SetCounter(character, left, ALL_TYPES, repel)
		end
	end
	c.SetCounter(character, NEST_TIME, ALL_TYPES, repel)
	local lastTick = -NEST_TICK
	while os.clock() - raisedAt < NEST_TIME do
		if not CombatState.IsAlive(character) then
			c.ClearCounter(character)
			fx(ctx, "SeaDragonsNest", "Drop")
			return
		end
		local t = os.clock() - raisedAt
		if t - lastTick >= NEST_TICK then
			lastTick = t
			for _, victim in c.Sphere(character, ctx.root.Position, NEST_RADIUS) do
				local victimRoot = rootOf(victim)
				if victimRoot then
					strike(ctx, victim, {
						damage = 0.5,
						stun = 0.4,
						attackType = "Zone",
						noShake = true,
						velocity = outward(victimRoot.Position - ctx.root.Position, look(ctx)) * 34 + UP * 6,
						velocityTime = 0.2,
					})
				end
			end
		end
		task.wait()
	end
	c.ClearCounter(character)
	fx(ctx, "SeaDragonsNest", "Drop")
end

local CRADLE_TIME = 0.8
local CRADLE_SPEED = 34
local CRADLE_STEER = 420
local CRADLE_BURST = 7

function Kit.Special(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, CRADLE_TIME + 0.15)
	CombatState.GiveIFrames(character, CRADLE_TIME + 0.05)
	local moving = level(ctx.humanoid.MoveDirection)
	local direction = if moving.Magnitude > 0.1 then moving.Unit else look(ctx)
	fx(ctx, "SeaDragonsCradle", "Form", { duration = CRADLE_TIME, airborne = airborne, direction = direction })
	c.ApplyVelocity(
		character,
		direction * CRADLE_SPEED + (if airborne then UP * 2 else Vector3.zero),
		CRADLE_TIME,
		{ steer = CRADLE_STEER }
	)
	task.wait(CRADLE_TIME)
	if not CombatState.IsAlive(character) then
		fx(ctx, "SeaDragonsCradle", "Fizzle")
		return
	end
	local center = ctx.root.Position
	fx(ctx, "SeaDragonsCradle", "Burst", { position = center })
	for _, victim in c.Sphere(character, center, CRADLE_BURST) do
		local victimRoot = rootOf(victim)
		if victimRoot then
			strike(ctx, victim, {
				damage = 1.5,
				stun = 0.7,
				attackType = "Zone",
				velocity = outward(victimRoot.Position - center, look(ctx)) * 40 + UP * 14,
				velocityTime = 0.2,
			})
		end
	end
	if airborne then
		c.ApplyVelocity(character, HOVER, 0.3)
	end
end

local MAX_PULL = 40

local function holdInFront(ctx, target: Model, forward: Vector3, distance: number, time: number): Vector3
	local targetRoot = rootOf(target)
	if not targetRoot then
		return HOVER
	end
	local offset = ctx.root.Position + forward * distance - targetRoot.Position
	local pull = Vector3.new(offset.X, offset.Y * 0.6, offset.Z) / time
	if pull.Magnitude > MAX_PULL then
		pull = pull.Unit * MAX_PULL
	end
	return pull + HOVER
end

local function lunge(ctx, velocity: Vector3, duration: number, box: Vector3, steer: number): Model?
	local c, character = ctx.combat, ctx.character
	c.ApplyVelocity(character, velocity, duration, { steer = steer, landStop = velocity.Y < 0, landKeep = 0.7 })
	local start = os.clock()
	while os.clock() - start < duration + 0.05 do
		if interrupted(ctx) then
			return nil
		end
		for _, victim in c.Box(character, ctx.root.CFrame * CFrame.new(0, 0, -box.Z / 2), box) do
			if not CombatState.HasIFrames(victim) then
				c.ApplyVelocity(character, HOVER, 0.05)
				return victim
			end
		end
		task.wait()
	end
	return nil
end

local LANCE_READY = 0.14
local LANCE_TIME = 0.42
local LANCE_SPEED = 80
local LANCE_STEER = 150
local LANCE_REACH = Vector3.new(5.5, 6, 7)
local LANCE_DRILLS = 3
local LANCE_GAP = 0.1

local function valkyrieLance(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	local dragon = character:GetAttribute("Ascended") == true
	CombatState.SetCasting(character, LANCE_READY + LANCE_TIME + 0.3)
	if airborne then
		c.ApplyVelocity(character, HOVER, LANCE_READY + 0.05)
	end
	fx(ctx, "ValkyrieLance", "Ready", { airborne = airborne, dragon = dragon })
	task.wait(LANCE_READY)
	if interrupted(ctx) then
		fx(ctx, "ValkyrieLance", "Cancel")
		return
	end
	local direction = if airborne then aimFrom(ctx, ctx.root.Position, softTarget(ctx, 40, 35), 0.45) else look(ctx)
	local started = os.clock()
	local function inFront(attacker: Model): boolean
		local attackerRoot = rootOf(attacker)
		return attackerRoot ~= nil and c.Flat(attackerRoot.Position - ctx.root.Position):Dot(look(ctx)) > 0.2
	end
	local function pierce(attacker: Model)
		local attackerRoot = rootOf(attacker)
		fx(ctx, "ValkyrieLance", "Pierce", { from = if attackerRoot then attackerRoot.Position else nil })
		local left = LANCE_TIME - (os.clock() - started)
		if left > 0.05 then
			c.SetCounter(character, left, SPELLS, pierce, inFront)
		end
	end
	c.SetCounter(character, LANCE_TIME, SPELLS, pierce, inFront)
	fx(ctx, "ValkyrieLance", "Charge", { direction = direction, duration = LANCE_TIME, dragon = dragon })
	local caught = lunge(ctx, direction * LANCE_SPEED, LANCE_TIME, LANCE_REACH, LANCE_STEER)
	c.ClearCounter(character)
	if not caught then
		fx(ctx, "ValkyrieLance", "Whiff")
		CombatState.SetCasting(character, 0.35)
		if airborne then
			c.ApplyVelocity(character, HOVER, 0.3)
		end
		return
	end
	local forward = look(ctx)
	CombatState.SetCasting(character, LANCE_DRILLS * LANCE_GAP + 0.4)
	fx(ctx, "ValkyrieLance", "Drill", { target = caught, count = LANCE_DRILLS, gap = LANCE_GAP, dragon = dragon })
	c.ApplyVelocity(character, HOVER, LANCE_DRILLS * LANCE_GAP + 0.1)
	for i = 1, LANCE_DRILLS do
		if interrupted(ctx) or not CombatState.IsAlive(caught) then
			fx(ctx, "ValkyrieLance", "Interrupted")
			CombatState.SetCasting(character, 0.3)
			return
		end
		local result = strike(ctx, caught, {
			damage = 1,
			stun = 1,
			attackType = "Melee",
			noShake = true,
			velocity = holdInFront(ctx, caught, forward, 3.6, LANCE_GAP),
			velocityTime = LANCE_GAP,
		})
		if result ~= "Hit" then
			fx(ctx, "ValkyrieLance", "Interrupted")
			CombatState.SetCasting(character, 0.35)
			return
		end
		fx(ctx, "ValkyrieLance", "Twist", { target = caught, index = i, dragon = dragon })
		task.wait(LANCE_GAP)
	end
	if interrupted(ctx) or not CombatState.IsAlive(caught) then
		fx(ctx, "ValkyrieLance", "Interrupted")
		return
	end
	strike(ctx, caught, {
		damage = 3,
		stun = 1.1,
		attackType = "Melee",
		heavy = true,
		ragdoll = 1.1,
		velocity = forward * 58 + UP * 20,
	})
	fx(ctx, "ValkyrieLance", "Thrust", { target = caught, dragon = dragon })
	CombatState.SetCasting(character, 0.25)
end

local HURL_DRAW = 0.4
local HURL_SPEED = 130
local HURL_RANGE = 100

local function lanceOfTheSeaDragon(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	local dragon = character:GetAttribute("Ascended") == true
	CombatState.SetCasting(character, HURL_DRAW + 0.35)
	if airborne then
		c.ApplyVelocity(character, HOVER, HURL_DRAW + 0.3)
	end
	fx(ctx, "LanceOfTheSeaDragon", "Draw", { airborne = airborne, delay = HURL_DRAW, dragon = dragon })
	task.wait(HURL_DRAW)
	if interrupted(ctx) then
		fx(ctx, "LanceOfTheSeaDragon", "Cancel")
		return
	end
	local origin = ctx.root.Position + look(ctx) * 2 + UP * 1.8 + ctx.root.CFrame.RightVector * 0.8
	local direction = aimFrom(ctx, origin, softTarget(ctx, HURL_RANGE, 30), 0.3)
	fx(ctx, "LanceOfTheSeaDragon", "Hurl", {
		origin = origin,
		direction = direction,
		speed = HURL_SPEED,
		range = HURL_RANGE,
		dragon = dragon,
	})
	Projectile.Fire({
		owner = character,
		origin = origin,
		direction = direction,
		speed = HURL_SPEED,
		range = HURL_RANGE,
		size = if dragon then Vector3.new(7, 7, 10) else Vector3.new(5, 5, 9),
		pierce = true,
		onHit = function(victim)
			strike(ctx, victim, {
				damage = 9,
				stun = 1.2,
				attackType = "Bolt",
				guardBreak = true,
				heavy = true,
				ragdoll = 1.2,
				velocity = c.Flat(direction) * 62 + UP * 22,
			})
		end,
		onEnd = function(position)
			fx(ctx, "LanceOfTheSeaDragon", "Crash", { position = position, direction = direction, dragon = dragon })
			c.ShakeArea(position, 40, 0.3)
		end,
	})
	c.ApplyVelocity(character, -c.Flat(direction) * 16 + (if airborne then UP * 3 else Vector3.zero), 0.12)
	CombatState.SetCasting(character, 0.3)
end

local DIVE_RANGE = 34
local DIVE_AHEAD = 22
local GEYSER_RADIUS = 6.5

local function mermaidDive(ctx)
	local c, character = ctx.combat, ctx.character
	local forward = look(ctx)
	local aimed = softTarget(ctx, DIVE_RANGE, 60)
	local aimedRoot = aimed and rootOf(aimed)
	local spot = if aimedRoot then aimedRoot.Position else ctx.root.Position + forward * DIVE_AHEAD
	local flat = level(spot - ctx.root.Position)
	local along = if flat.Magnitude > 1e-3 then flat.Unit else forward
	local distance =
		math.clamp(math.min(flat.Magnitude, reach(ctx, ctx.root.Position, along, DIVE_RANGE) - 2), 6, DIVE_RANGE)
	local target = ctx.root.Position + along * distance
	local floorFrom = floorUnder(ctx, ctx.root.Position).Y
	local floorTo = floorUnder(ctx, target).Y
	local plan = DivePlan.Plan(CFrame.lookAt(ctx.root.Position, ctx.root.Position + along), target, floorFrom, floorTo)
	local erupt = DivePlan.Erupt(plan)
	CombatState.SetCasting(character, plan.length + 0.25)
	CombatState.GiveIFrames(character, plan.length + 0.1)
	fx(ctx, "MermaidDive", "Begin", { start = plan.start, target = target, floorFrom = floorFrom, floorTo = floorTo })
	local stop = c.Cutscene({
		[character] = function(t)
			return DivePlan.At(plan, t)
		end,
	}, plan.length)
	task.wait(erupt)
	if not CombatState.IsAlive(character) then
		stop()
		return
	end
	local ground = plan.to
	fx(ctx, "MermaidDive", "Erupt", { position = ground })
	for _, victim in c.Sphere(character, ground + UP * 3, GEYSER_RADIUS) do
		local victimRoot = rootOf(victim)
		local out = if victimRoot then outward(victimRoot.Position - ground, Vector3.zero) else Vector3.zero
		strike(ctx, victim, {
			damage = 7,
			stun = 1.2,
			attackType = "Zone",
			unblockable = true,
			hitsDowned = true,
			heavy = true,
			ragdoll = 1.3,
			velocity = UP * 70 + out * 8,
		})
	end
	c.ShakeArea(ground, 50, 0.45)
	task.wait(plan.length - erupt)
	stop()
end

local TAIL_WINDUP = 0.35
local TAIL_LENGTH = 15
local TAIL_WIDTH = 8

local function seaDragonGodsTail(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, TAIL_WINDUP + 0.45)
	if airborne then
		c.ApplyVelocity(character, HOVER, TAIL_WINDUP + 0.3)
	end
	fx(ctx, "SeaDragonGodsTail", "Raise", { airborne = airborne, delay = TAIL_WINDUP })
	task.wait(TAIL_WINDUP)
	if interrupted(ctx) then
		fx(ctx, "SeaDragonGodsTail", "Cancel")
		return
	end
	local forward = look(ctx)
	local origin = ctx.root.Position
	local center = origin + forward * (TAIL_LENGTH / 2)
	local ground = floorUnder(ctx, center)
	local height = math.max(origin.Y - ground.Y + 6, 10)
	fx(ctx, "SeaDragonGodsTail", "Slam", {
		origin = origin,
		direction = forward,
		length = TAIL_LENGTH,
		ground = ground,
		airborne = airborne,
	})
	local middle = Vector3.new(center.X, ground.Y + height / 2 - 1, center.Z)
	for _, victim in
		c.Box(character, CFrame.lookAt(middle, middle + forward), Vector3.new(TAIL_WIDTH, height, TAIL_LENGTH))
	do
		local aloft = c.IsAirborne(victim)
		strike(ctx, victim, {
			damage = 9,
			stun = 1.2,
			attackType = "Melee",
			guardBreak = true,
			hitsDowned = true,
			heavy = true,
			ragdoll = 1.3,
			velocity = if aloft then forward * 10 - UP * 80 else forward * 22 + UP * 30,
		})
	end
	c.ShakeArea(ground, 55, 0.5)
	CombatState.SetCasting(character, 0.35)
end

local VORTEX_TIME = 1.6
local VORTEX_RADIUS = 9
local VORTEX_TICK = 0.2
local VORTEX_EYE = 3.5
local VORTEX_BURST = 10

local function seaDragonGodsVortex(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, VORTEX_TIME + 0.3)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, VORTEX_TIME + 0.2)
	end
	local started = os.clock()
	fx(ctx, "SeaDragonGodsVortex", "Spin", { duration = VORTEX_TIME, radius = VORTEX_RADIUS })
	local function deflect(attacker: Model, hit: any)
		local attackerRoot = rootOf(attacker)
		fx(ctx, "SeaDragonGodsVortex", "Deflect", { from = if attackerRoot then attackerRoot.Position else nil })
		if
			attackerRoot
			and not hit.reflected
			and CombatState.IsAlive(attacker)
			and (attackerRoot.Position - ctx.root.Position).Magnitude < VORTEX_RADIUS + 5
		then
			strike(ctx, attacker, {
				damage = 1,
				stun = 0.7,
				attackType = "Zone",
				unblockable = true,
				reflected = true,
				velocity = outward(attackerRoot.Position - ctx.root.Position, look(ctx)) * 40 + UP * 14,
				velocityTime = 0.18,
			})
		end
		local left = VORTEX_TIME - (os.clock() - started)
		if left > 0.05 then
			c.SetCounter(character, left, ALL_TYPES, deflect)
		end
	end
	c.SetCounter(character, VORTEX_TIME, ALL_TYPES, deflect)
	while os.clock() - started < VORTEX_TIME do
		if not CombatState.IsAlive(character) then
			c.ClearCounter(character)
			fx(ctx, "SeaDragonGodsVortex", "Fizzle")
			return
		end
		for _, victim in c.Sphere(character, ctx.root.Position, VORTEX_RADIUS) do
			local victimRoot = rootOf(victim)
			if victimRoot then
				local offset = level(ctx.root.Position - victimRoot.Position)
				local inward = if offset.Magnitude > 0.5 then offset.Unit else Vector3.zero
				local swirl = inward * math.clamp((offset.Magnitude - VORTEX_EYE) * 6, -10, 24)
					+ inward:Cross(UP) * 14
					+ HOVER
				if
					strike(ctx, victim, {
						damage = 0.6,
						stun = 0.5,
						attackType = "Melee",
						hitsDowned = true,
						noShake = true,
						velocity = swirl,
						velocityTime = VORTEX_TICK + 0.05,
					}) == "Blocked"
				then
					c.ApplyVelocity(victim, swirl, VORTEX_TICK + 0.05)
				end
			end
		end
		task.wait(VORTEX_TICK)
	end
	c.ClearCounter(character)
	local center = ctx.root.Position
	fx(ctx, "SeaDragonGodsVortex", "Burst", { position = center })
	for _, victim in c.Sphere(character, center, VORTEX_BURST) do
		local victimRoot = rootOf(victim)
		if victimRoot then
			strike(ctx, victim, {
				damage = 3,
				stun = 1,
				attackType = "Zone",
				guardBreak = true,
				hitsDowned = true,
				heavy = true,
				ragdoll = 1.2,
				velocity = outward(victimRoot.Position - center, look(ctx)) * 50 + UP * 40,
			})
		end
	end
	c.ShakeArea(center, 50, 0.45)
end

Kit.Skills = { waterball, seaDragonsRoar, pointBlankRoar, seaDragonsNest }

local VALKYRIE = { valkyrieLance, lanceOfTheSeaDragon, mermaidDive, seaDragonsNest }
local DRAGON = { valkyrieLance, lanceOfTheSeaDragon, seaDragonGodsTail, seaDragonGodsVortex }
local function stageMove(slot: number): (any) -> ()
	return function(ctx)
		local moves = if ctx.character:GetAttribute("Ascended") == true then DRAGON else VALKYRIE
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
				c.ApplyVelocity(victim, outward(victimRoot.Position - ctx.root.Position, look(ctx)) * 55 + UP * 18, 0.2)
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
