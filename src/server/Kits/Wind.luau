--[[
	Prince of Wind (Yuno), server side.

	A mid-range zoner, Asta's opposite: wind spells that pin people down and
	push them around from where a sword can't reach, star magic to be
	somewhere else in an instant. Less damage per move than Asta, more
	range and control. Spells are Bolt / Swarm / Zone attacks, so Asta's
	Deflect sends them back and his Conquering Eon drinks them in.

	Base: Prince of Wind
	  1 Wind Blades Shower   a rain of wind blades on whoever he faces (or a
	                         way ahead): six waves of hits, the last pops them up
	  2 Swift White Hawk     a hawk of wind that flies at them, curving after
	                         them, and blows them away
	  3 Heavenly Wind Ark    a crescent of wind rises out of the ground ahead and
	                         launches them; he rides the updraft after them
	                         (air: it sweeps down and spikes them)
	  4 Gale White Bow       a great bow of wind; six big arrows, aimed at whoever
	                         he faces
	  R Conjunction          a star goes down where he's moving (ahead if he's
	                         still); R again within 4s and he's there
	Half-Crown Spirit of Zephyr (G): Sylph on his left side
	  1 Spirit Storm         a dense beam of swirling wind out of his palm
	  2 Spirit's Hushed Dance  reads the mana around him: the next attack misses
	                         and he dances along the wind to behind them and strikes
	  3 Quartile Scutum      four stars and the light between them: a wall in
	                         front that stops everything, melee thrown back off it
	  4 Quartile Hasta       four star beams converge into one: guard-breaking
	Full-Crown Spirit of Zephyr (G again, once 45 damage is dealt in Half-Crown)
	  1 Spirit of Notos      the south wind bursts out of him, and blows spells
	                         thrown at him back where they came from
	  2 Spirit of Boreas     the wind sword becomes a halberd: he closes in and
	                         brings the axe down, guard break
	  3 Spirit of Euros      a recurve bow of wind; one arrow, too fast to see,
	                         through everything in a line (unblockable)
	  4 Neverland            he and Sylph raise a dome of turning stars: time stops
	                         for everyone inside, then they're weaker and slower
	                         while Sylph's clones strike them and he hits harder

	All visuals are in StarterPlayerScripts.Client.Kits.Wind, which gets
	("Skill", {skill, phase, ...}) events from here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatState = require(ReplicatedStorage:WaitForChild("Shared").CombatState)
local Projectile = require(script.Parent.Parent.Projectile)

local KIT_ID = "Wind"
local UP = Vector3.yAxis
-- Holds a character in the air (a tiny upward velocity switches on the
-- vertical force, so gravity stops pulling).
local HOVER = Vector3.new(0, 0.05, 0)
local SPELLS = { Bolt = true, Explosion = true, Swarm = true, Zone = true }
local ALL_TYPES = { Melee = true, Bolt = true, Explosion = true, Swarm = true, Zone = true }

local Kit = {}

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

local function rootOf(character: Model): BasePart?
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Interrupted by getting hit, ragdolled or dying.
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

-- How far a spell can go along `direction` before it meets the ground or a
-- wall (people don't stop it).
local function reach(ctx, origin: Vector3, direction: Vector3, maxRange: number): number
	local hit = workspace:Raycast(origin, direction * maxRange, rayParams(ctx))
	if hit and not isCharacterPart(hit.Instance) then
		return math.max((hit.Position - origin).Magnitude + 1, 6)
	end
	return maxRange
end

-- The floor under a point (or 3 studs under it when there's none in reach).
local function floorUnder(ctx, position: Vector3): Vector3
	local hit = workspace:Raycast(position + UP * 2, Vector3.new(0, -60, 0), rayParams(ctx))
	return if hit then hit.Position else position - UP * 3
end

-- Who he's most likely aiming at: the closest enemy within `range` studs
-- and `cone` degrees of where he faces.
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

-- Where a spell aims: straight at the soft target if there is one, else
-- ahead (and down at an angle from the air).
local function aimFrom(ctx, origin: Vector3, target: Model?, dip: number): Vector3
	local targetRoot = target and rootOf(target)
	if targetRoot then
		return (targetRoot.Position - origin).Unit
	end
	local forward = look(ctx)
	return if ctx.airborne then (forward + UP * -dip).Unit else forward
end

-- Everyone along a line (a beam).
local function lineVictims(ctx, origin: Vector3, direction: Vector3, length: number, width: number): { Model }
	local box = CFrame.lookAt(origin + direction * (length / 2), origin + direction * length)
	return ctx.combat.Box(ctx.character, box, Vector3.new(width, width + 1, length))
end

---------------------------------------------------------------------------
-- Base moves: Prince of Wind
---------------------------------------------------------------------------

-- Wind Blades Shower: blades of wind form in the sky over whoever he faces
-- (or a way ahead) and rain down in waves. The waves pin them in place; the
-- last one pops them up. The blades keep falling even if he's hit.
local SHOWER_CAST = 0.35
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
				c.Hit(character, victim, {
					damage = if last then 2.5 else 1.4,
					stun = if last then 0.8 else 0.5,
					attackType = "Swarm",
					heavy = last,
					velocity = if last then UP * 26 else nil,
					velocityTime = 0.15,
				})
			end
		end
		task.wait(SHOWER_GAP)
	end
end

-- Swift White Hawk: a hawk of wind that flies at them, curving after whoever
-- he faced when he threw it, and blows them away when it strikes.
local HAWK_CAST = 0.22
local HAWK_SPEED = 80
local HAWK_RANGE = 75
local HAWK_TURN = math.rad(140) -- per second

local function swiftWhiteHawk(ctx)
	local c, character = ctx.combat, ctx.character
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
					stun = 0.9,
					attackType = "Bolt",
					heavy = true,
					velocity = c.Flat(direction) * 38 + UP * 14,
					velocityTime = 0.2,
				})
			end
			fx(ctx, "SwiftWhiteHawk", "Burst", { position = position })
			return
		end
	end
	fx(ctx, "SwiftWhiteHawk", "Burst", { position = position, fade = true })
end

-- Heavenly Wind Ark: a great crescent of wind rises out of the ground in
-- front of him and launches whoever it catches; he rides the updraft up
-- after them for air M1s. In the air the ark sweeps down beneath him
-- instead and spikes them into the ground.
local ARK_CAST = 0.18

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
				heavy = true,
				ragdoll = 1.2,
				velocity = forward * 10 + UP * -70,
			})
		end
		c.ApplyVelocity(character, UP * 18, 0.12)
		return
	end
	local launched = false
	for _, victim in c.Box(character, ctx.root.CFrame * CFrame.new(0, 1, -5.5), Vector3.new(11, 9, 11)) do
		-- The M1 uppercut's launch: limp, up and straight back down, and
		-- still hittable on the way.
		if
			c.Hit(character, victim, {
				damage = 7,
				stun = 1.2,
				attackType = "Zone",
				heavy = true,
				variant = "Uppercut",
			}) == "Hit"
		then
			launched = true
		end
	end
	if launched then
		c.ApplyVelocity(character, UP * 50 + forward * 6, 0.25)
	end
end

-- Gale White Bow: a great bow of wind and six big arrows, one after the
-- other, each aimed at whoever he faces at that moment. The first five keep
-- them stunned, the sixth knocks them back.
local BOW_DRAW = 0.35
local BOW_ARROWS = 6
local BOW_GAP = 0.12

local function galeWhiteBow(ctx)
	local c, character = ctx.combat, ctx.character
	local volley = BOW_DRAW + BOW_ARROWS * BOW_GAP
	CombatState.SetCasting(character, volley + 0.2)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, volley + 0.1)
	end
	fx(ctx, "GaleWhiteBow", "Draw", { airborne = ctx.airborne, draw = BOW_DRAW, arrows = BOW_ARROWS, gap = BOW_GAP })
	task.wait(BOW_DRAW)
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
				c.Hit(character, victim, {
					damage = if last then 3 else 2,
					stun = if last then 0.9 else 0.55,
					attackType = "Bolt",
					heavy = last,
					velocity = if last then c.Flat(direction) * 40 + UP * 15 else c.Flat(direction) * 6,
					velocityTime = 0.15,
				})
			end,
		})
		task.wait(BOW_GAP)
	end
	CombatState.SetCasting(character, 0.2)
end

---------------------------------------------------------------------------
-- R: Conjunction (star magic)
---------------------------------------------------------------------------

-- A star goes down 22 studs the way he's moving (to the side or back for a
-- dodge), or straight ahead when he's standing still. R again within 4s and
-- he's there in an instant. A press while he's stunned does nothing.
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

---------------------------------------------------------------------------
-- Half-Crown Spirit of Zephyr
---------------------------------------------------------------------------

-- Spirit Storm: mana gathered in his palm, let out as a dense beam of
-- swirling wind that drags them along it; the last of it blows them away.
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

-- Spirit's Hushed Dance: he reads the mana around him. The next attack
-- (anything, from anywhere) misses; he dances along a stream of wind to
-- just behind whoever threw it and strikes, a launcher. From too far away
-- he just slips aside.
local DANCE_WINDOW = 0.9
local DANCE_REACH = 45

local function hushedDance(ctx)
	local c, character = ctx.combat, ctx.character
	local countered = false
	CombatState.SetCasting(character, DANCE_WINDOW + 0.1)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, DANCE_WINDOW)
	end
	fx(ctx, "HushedDance", "Stance", { window = DANCE_WINDOW })
	c.SetCounter(character, DANCE_WINDOW, ALL_TYPES, function(attacker: Model)
		countered = true
		CombatState.GiveIFrames(character, 0.7)
		CombatState.SetCasting(character, 0.5)
		local attackerRoot = rootOf(attacker)
		if not attackerRoot then
			return
		end
		local from = ctx.root.Position
		if (attackerRoot.Position - from).Magnitude <= DANCE_REACH then
			local behind = attackerRoot.Position - c.Flat(attackerRoot.CFrame.LookVector) * 3.5
			ctx.root.CFrame =
				CFrame.lookAt(behind, Vector3.new(attackerRoot.Position.X, behind.Y, attackerRoot.Position.Z))
			c.ApplyVelocity(character, if ctx.airborne then HOVER else Vector3.zero, 0.2)
			fx(ctx, "HushedDance", "Evade", { from = from, to = behind, target = attacker })
			task.wait(0.12)
			if CombatState.IsAlive(attacker) then
				c.Hit(character, attacker, {
					damage = 8,
					stun = 1.2,
					attackType = "Melee",
					unblockable = true,
					heavy = true,
					velocity = c.Flat(attackerRoot.Position - ctx.root.Position) * 25 + UP * 30,
					velocityTime = 0.2,
				})
			end
		else
			local side = ctx.root.CFrame.RightVector * (if math.random() < 0.5 then -9 else 9)
			ctx.root.CFrame += side
			fx(ctx, "HushedDance", "Evade", { from = from, to = ctx.root.Position })
		end
	end)
	task.wait(DANCE_WINDOW + 0.02)
	if not countered then
		c.ClearCounter(character)
		fx(ctx, "HushedDance", "End")
		CombatState.SetCasting(character, 0.4)
	end
end

-- Quartile Scutum: four stars in a rectangle in front of him and beams of
-- light between them, a wall that stops anything from the front for 2.5s
-- (even moves that break guards); whoever runs into it in melee is thrown
-- back off the light. He can still walk, slowly, but not attack.
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
		local close = attackerRoot ~= nil and (attackerRoot.Position - ctx.root.Position).Magnitude < 14
		if close and (hit.attackType or "Melee") == "Melee" and attackerRoot then
			c.Hit(character, attacker, {
				damage = 3,
				stun = 0.6,
				attackType = "Zone",
				unblockable = true,
				velocity = c.Flat(attackerRoot.Position - ctx.root.Position) * 45 + UP * 12,
				velocityTime = 0.18,
			})
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

-- Quartile Hasta: four stars around his outstretched hand, their beams
-- converging into one far bigger: a single, guard-breaking lance of light.
local HASTA_CHARGE = 0.5
local HASTA_LENGTH = 60

local function quartileHasta(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, HASTA_CHARGE + 0.45)
	if airborne then
		c.ApplyVelocity(character, HOVER, HASTA_CHARGE + 0.3)
	end
	fx(ctx, "QuartileHasta", "Stars", { airborne = airborne, duration = HASTA_CHARGE })
	task.wait(HASTA_CHARGE)
	if interrupted(ctx) then
		fx(ctx, "QuartileHasta", "Cancel")
		return
	end
	local origin = ctx.root.Position + look(ctx) * 3 + UP * 0.8
	local direction = aimFrom(ctx, origin, softTarget(ctx, HASTA_LENGTH, 25), 0.4)
	local length = reach(ctx, origin, direction, HASTA_LENGTH)
	fx(ctx, "QuartileHasta", "Fire", { origin = origin, direction = direction, length = length })
	for _, victim in lineVictims(ctx, origin, direction, length, 6) do
		c.Hit(character, victim, {
			damage = 14,
			stun = 1.2,
			attackType = "Bolt",
			guardBreak = true,
			heavy = true,
			ragdoll = 1.3,
			velocity = c.Flat(direction) * 55 + UP * 18,
		})
	end
	c.ShakeArea(origin, 45, 0.4)
	task.wait(0.3)
	CombatState.SetCasting(character, 0.2)
end

---------------------------------------------------------------------------
-- Full-Crown Spirit of Zephyr
---------------------------------------------------------------------------

-- Spirit of Notos: the south wind bursts out of him and throws everyone
-- near away; for a moment after, spells thrown at him are blown back at
-- whoever threw them.
local NOTOS_RADIUS = 16
local NOTOS_GUARD = 0.8

local function spiritOfNotos(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, 0.45)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, 0.45)
	end
	fx(ctx, "SpiritOfNotos", "Blast", { airborne = ctx.airborne })
	task.wait(0.1)
	for _, victim in c.Sphere(character, ctx.root.Position, NOTOS_RADIUS) do
		local victimRoot = rootOf(victim)
		if victimRoot then
			c.Hit(character, victim, {
				damage = 6,
				stun = 0.9,
				attackType = "Zone",
				heavy = true,
				ragdoll = 1,
				velocity = c.Flat(victimRoot.Position - ctx.root.Position) * 70 + UP * 22,
			})
		end
	end
	local guardFrom = os.clock()
	local function blowBack(attacker: Model)
		local attackerRoot = rootOf(attacker)
		if attackerRoot then
			local origin = ctx.root.Position + UP * 0.6
			local direction = (attackerRoot.Position - origin).Unit
			fx(ctx, "SpiritOfNotos", "Gust", { origin = origin, direction = direction })
			Projectile.Fire({
				owner = character,
				origin = origin + direction * 2,
				direction = direction,
				speed = 120,
				range = 90,
				size = Vector3.new(6, 6, 3),
				onHit = function(victim)
					c.Hit(character, victim, {
						damage = 7,
						stun = 0.9,
						attackType = "Bolt",
						heavy = true,
						velocity = c.Flat(direction) * 45 + UP * 15,
					})
				end,
			})
		end
		local left = NOTOS_GUARD - (os.clock() - guardFrom)
		if left > 0.02 then
			c.SetCounter(character, left, SPELLS, blowBack)
		end
	end
	c.SetCounter(character, NOTOS_GUARD, SPELLS, blowBack)
	c.ShakeArea(ctx.root.Position, 40, 0.35)
end

-- Spirit of Boreas: the wind sword condenses into a halberd with an axe
-- head. He closes in, then the axe comes down: a guard-breaking cleave, and
-- the wind off the impact hits everyone around it.
local BOREAS_LUNGE = 0.3

local function spiritOfBoreas(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, 0.95)
	fx(ctx, "SpiritOfBoreas", "Form", { airborne = airborne })
	task.wait(0.12)
	if interrupted(ctx) then
		return
	end
	local forward = look(ctx)
	c.ApplyVelocity(
		character,
		forward * 70 + (if airborne then UP * -30 else Vector3.zero),
		BOREAS_LUNGE,
		if airborne then { landStop = true, landKeep = 0 } else nil
	)
	local start = os.clock()
	while os.clock() - start < BOREAS_LUNGE do
		if interrupted(ctx) then
			return
		end
		if #c.Box(character, ctx.root.CFrame * CFrame.new(0, 0, -3), Vector3.new(6, 7, 6)) > 0 then
			c.ApplyVelocity(character, Vector3.zero, 0.05)
			break
		end
		task.wait()
	end
	fx(ctx, "SpiritOfBoreas", "Chop", { airborne = airborne })
	task.wait(0.14)
	if interrupted(ctx) then
		return
	end
	local impact = floorUnder(ctx, (ctx.root.CFrame * CFrame.new(0, 0, -5)).Position)
	local struck: { [Model]: boolean } = {}
	for _, victim in c.Box(character, ctx.root.CFrame * CFrame.new(0, -0.5, -5), Vector3.new(9, 9, 10)) do
		struck[victim] = true
		c.Hit(character, victim, {
			damage = 14,
			stun = 1.3,
			attackType = "Melee",
			guardBreak = true,
			heavy = true,
			ragdoll = 1.5,
			velocity = forward * 30 + UP * -40,
		})
	end
	for _, victim in c.Sphere(character, impact, 11) do
		local victimRoot = rootOf(victim)
		if not struck[victim] and victimRoot then
			c.Hit(character, victim, {
				damage = 5,
				stun = 0.7,
				attackType = "Zone",
				velocity = c.Flat(victimRoot.Position - impact) * 35 + UP * 15,
				velocityTime = 0.18,
			})
		end
	end
	fx(ctx, "SpiritOfBoreas", "Impact", { position = impact })
	c.ShakeArea(impact, 50, 0.5)
	CombatState.SetCasting(character, 0.3)
end

-- Spirit of Euros: a recurve bow of wind, drawn while the wind spirals into
-- the arrow. Loosed, it's too fast to see: everyone along its line is hit
-- at once, through guards and through each other.
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
	for _, victim in lineVictims(ctx, origin, direction, length, 3.5) do
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

-- Neverland: he and Sylph raise a dome of turning stars over everything
-- around him. Time stops for everyone caught inside; then, for as long as
-- it stands, they're weaker and slower while Sylph's clones strike them,
-- and he hits harder inside it.
local NEVERLAND_CAST = 1.0
local NEVERLAND_TIME = 7
local NEVERLAND_RADIUS = 28

local function neverland(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, NEVERLAND_CAST + 0.2)
	CombatState.GiveIFrames(character, NEVERLAND_CAST + 0.1)
	if ctx.airborne then
		c.ApplyVelocity(character, HOVER, NEVERLAND_CAST)
	else
		character:SetAttribute("Rooted", true)
	end
	local center = floorUnder(ctx, ctx.root.Position)
	fx(ctx, "Neverland", "Horn", {
		center = center,
		radius = NEVERLAND_RADIUS,
		cast = NEVERLAND_CAST,
		duration = NEVERLAND_TIME,
	})
	task.wait(NEVERLAND_CAST)
	character:SetAttribute("Rooted", false)
	if not CombatState.IsAlive(character) then
		fx(ctx, "Neverland", "Close", { center = center })
		return
	end
	fx(ctx, "Neverland", "Open", { center = center, radius = NEVERLAND_RADIUS })
	local frozen = {}
	for _, victim in c.Sphere(character, center, NEVERLAND_RADIUS) do
		if
			c.Hit(
				character,
				victim,
				{ damage = 4, stun = 1.5, attackType = "Zone", unblockable = true, noShake = true }
			) == "Hit"
		then
			c.ApplyVelocity(victim, Vector3.zero, 1.4)
			table.insert(frozen, victim)
		end
	end
	if #frozen > 0 then
		fx(ctx, "Neverland", "Freeze", { targets = frozen, duration = 1.4 })
	end
	local opened = os.clock()
	local nextStrike = opened + 1.5
	while os.clock() - opened < NEVERLAND_TIME and character.Parent do
		local now = os.clock()
		local inside = c.Sphere(character, center, NEVERLAND_RADIUS)
		for _, victim in inside do
			victim:SetAttribute("WeakUntil", now + 0.4)
			victim:SetAttribute("SlowUntil", now + 0.4)
		end
		if (ctx.root.Position - center).Magnitude <= NEVERLAND_RADIUS then
			character:SetAttribute("PowerUntil", now + 0.4)
		end
		if now >= nextStrike then
			nextStrike += 1
			local struck = {}
			for _, victim in inside do
				if
					c.Hit(character, victim, {
						damage = 2,
						stun = 0.35,
						attackType = "Zone",
						unblockable = true,
						noShake = true,
					}) == "Hit"
				then
					table.insert(struck, victim)
				end
			end
			if #struck > 0 then
				fx(ctx, "Neverland", "Strike", { targets = struck })
			end
		end
		task.wait(0.2)
	end
	fx(ctx, "Neverland", "Close", { center = center })
end

---------------------------------------------------------------------------
-- Move sets
---------------------------------------------------------------------------

Kit.Skills = { windBladesShower, swiftWhiteHawk, heavenlyWindArk, galeWhiteBow }

-- Awakened, the moves follow the stage: Half-Crown, or Full-Crown once he's
-- ascended (the "Ascended" attribute; names and cooldowns in Shared/Kits).
local HALF_CROWN = { spiritStorm, hushedDance, quartileScutum, quartileHasta }
local FULL_CROWN = { spiritOfNotos, spiritOfBoreas, spiritOfEuros, neverland }
local function stageMove(slot: number): (any) -> ()
	return function(ctx)
		local moves = if ctx.character:GetAttribute("Ascended") == true then FULL_CROWN else HALF_CROWN
		moves[slot](ctx)
	end
end
Kit.AwakenedSkills = { stageMove(1), stageMove(2), stageMove(3), stageMove(4) }

---------------------------------------------------------------------------
-- Half-Crown / Full-Crown Spirit of Zephyr
---------------------------------------------------------------------------

-- The client's Awaken / Ascend animations: wind gathers round him, Sylph
-- merges into him at the burst, and he settles into the new stance. Rooted
-- and untouchable the whole time.
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

function Kit.AwakenEnd(ctx)
	fx(ctx, "Awaken", "End")
end

function Kit.Unequip(character: Model)
	for _, attribute in { "PowerUntil", "WeakUntil", "SlowUntil", "Rooted" } do
		character:SetAttribute(attribute, nil)
	end
end

return Kit
