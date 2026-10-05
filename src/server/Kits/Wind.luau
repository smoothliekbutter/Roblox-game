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
	                         carries them and him up together, held there for an
	                         air string that ends in the downslam (air: it sweeps
	                         down and spikes them); breaks guards, hits people
	                         who are down
	  4 Gale White Bow       a great bow of wind; six big arrows, aimed at whoever
	                         he faces (held on the ground: one great arrow)
	  R Conjunction          a star goes down where he's moving (ahead if he's
	                         still); R again within 4s and he's there
	Half-Crown Spirit of Zephyr (G): Sylph on his left side
	  1 Spirit Storm         a dense beam of swirling wind out of his palm
	  2 Tempest Dive         grab: he drags them straight up into the sky, then
	                         drives them head-first down into the ground, a
	                         tornado forming behind them on the way down.
	                         Landing it twice is what unlocks the Full-Crown
	  3 Quartile Scutum      four stars and the light between them: a wall in
	                         front that stops everything, melee thrown back off it
	  4 Quartile Hasta       four stars round his hand: tapped, a barrage of star
	                         bolts; held, a beam he keeps on them; in the air,
	                         star-fire raining on the ground below
	Full-Crown Spirit of Zephyr (G again, once Tempest Dive has landed twice)
	  1 Spirit of Boreas     a great axe of wind; one huge chop splits the ground in
	                         a line ahead, through guards, launching them
	  2 Spirit of Zephyrus   his sword of wind grows long and he lunges at them
	                         (steerable); caught, three cuts and a thrust
	  3 Spirit of Euros      a recurve bow of wind; one arrow, too fast to see,
	                         through everything in a line (unblockable)
	  4 Saint Spirit of      cutscene: a star binds them in the air in a pentagram;
	    Zephyr               he cuts through them from star to star (Conjunction),
	                         then splits them with one strike from above
	Air combos: he can jump again in the air (Kits airJumps), and from the air
	the hawk holds them up and pulls him in, the blades and arrows keep them
	up there (the last spikes them down), Tempest Dive takes them both up.

	All visuals are in StarterPlayerScripts.Client.Kits.Wind, which gets
	("Skill", {skill, phase, ...}) events from here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatState = require(ReplicatedStorage:WaitForChild("Shared").CombatState)
local SaintPlan = require(ReplicatedStorage:WaitForChild("Shared").SaintZephyr)
local DivePlan = require(ReplicatedStorage:WaitForChild("Shared").TempestDive)
local Projectile = require(script.Parent.Parent.Projectile)

local KIT_ID = "Wind"
local UP = Vector3.yAxis
-- Holds a character in the air (a tiny upward velocity switches on the
-- vertical force, so gravity stops pulling).
local HOVER = Vector3.new(0, 0.05, 0)
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

-- The floor under a point (or 3 studs under it when there's none in reach),
-- looking past anyone standing there.
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
local SHOWER_CAST = 0.6 -- the wind-up: blades gather overhead before the first wave
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
				-- Someone in the air is held up there by the blades, and the
				-- last wave throws them higher: a juggle.
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

-- Swift White Hawk: a hawk of wind that flies at them, curving after whoever
-- he faced when he threw it, and blows them away when it strikes.
local HAWK_CAST = 0.22
local HAWK_SPEED = 80
local HAWK_RANGE = 75
local HAWK_TURN = math.rad(140) -- per second

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
			-- Thrown from the air it holds them up there and pulls him in after
			-- them, for an air string; from the ground it blows them away.
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

-- Heavenly Wind Ark: a great crescent of wind rises out of the ground in
-- front of him and carries whoever it catches up into the air, and him
-- right behind them; both hang there for an air string (M1s in the air
-- keep them both up, the 4th slams them down). In the air the ark sweeps
-- down beneath him instead and spikes them into the ground. Either way it
-- breaks guards (a broken guard isn't carried up, just left open) and hits
-- people who are down.
local ARK_CAST = 0.18
local ARK_RISE = 46 -- studs a second, for ARK_RISE_TIME: about 14 studs up
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
			hitsDowned = true, -- scoops people up off the floor too
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

-- Gale White Bow: a great bow of wind and six big arrows, one after the
-- other, each aimed at whoever he faces at that moment. The first five keep
-- them stunned, the sixth knocks them back. Held on the ground instead, he
-- keeps drawing: one great arrow that goes through everyone in its path,
-- breaks guards and leaves them slowed for a moment. Light on damage
-- (a little more the longer he draws).
local BOW_SLOT = 4
local BOW_DRAW = 0.5
local BOW_ARROWS = 6
local BOW_GAP = 0.12
local GREAT_MIN = 0.2 -- the great arrow draws at least this much longer
local GREAT_MAX = 0.6 -- and at most this much (fully drawn)
local GREAT_SPEED = 160
local GREAT_RANGE = 110
local GREAT_SLOW = 2.5 -- seconds of SlowUntil from the hit (about half of it after the ragdoll)

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
			-- Slowed for a moment after it (a broken guard too).
			if result == "Hit" or result == "GuardBreak" then
				local slowUntil = math.max(tonumber(victim:GetAttribute("SlowUntil")) or 0, os.clock() + GREAT_SLOW)
				victim:SetAttribute("SlowUntil", slowUntil)
			end
		end,
	})
	-- The bow kicks him back a step.
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
				-- In the air the arrows pin them there; the last spikes them down.
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

--[[
	Tempest Dive (Half-Crown 2): a grab. His hand shoots out; whoever it
	catches he drags straight up into the sky by the collar, then swings
	over them and drives them head-first down into the ground, hard enough
	to bounce them, a tornado forming behind them on the way down (it cuts
	them twice). The timeline is Shared/TempestDive. Landing it charges the
	Full-Crown: twice, and G can be pressed again.
]]
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

	local plan = DivePlan.Plan(ctx.root.CFrame, targetRoot.Position, floorUnder(ctx, targetRoot.Position).Y)
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

	-- Into the ground, hard enough to bounce them.
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
	-- Whatever it stops goes back at whoever sent it, twice as hard: straight
	-- back into them up close, as a bolt of starlight from range. (What it
	-- sends back is never sent back again, so two barriers can't trade it.)
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

--[[
	Quartile Hasta (Half-Crown 4): four stars open round his outstretched
	hand, and then, depending on the key:
	  tapped    a mini barrage: the stars fire star bolts at whoever he
	            faces, one after another;
	  held      their light converges into a beam he keeps on them for as
	            long as the key is down (up to 1.6s, turning with him),
	            ending in a blast that breaks guards;
	  in the air  star-fire rains down on the ground below him.
]]
local HASTA_SLOT = 4
local HASTA_CHARGE = 0.25 -- the stars open; still held after this, it's the beam
local HASTA_LENGTH = 60
local HASTA_BOLTS = 5
local HASTA_BOLT_GAP = 0.09
local HASTA_BEAM_MAX = 1.6
local HASTA_BEAM_TICK = 0.12
local HASTA_RAIN = 12
local HASTA_RAIN_RADIUS = 11
local HASTA_RAIN_TIME = 1

local function hastaBarrage(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, HASTA_BOLTS * HASTA_BOLT_GAP + 0.25)
	for i = 1, HASTA_BOLTS do
		if interrupted(ctx) then
			return
		end
		local last = i == HASTA_BOLTS
		local origin = ctx.root.Position + look(ctx) * 3 + UP * 0.8
		local direction = aimFrom(ctx, origin, softTarget(ctx, HASTA_LENGTH, 30), 0.3)
		fx(
			ctx,
			"QuartileHasta",
			"Bolt",
			{ index = (i - 1) % 4 + 1, direction = direction, speed = 190, range = 70, last = last }
		)
		Projectile.Fire({
			owner = character,
			origin = origin,
			direction = direction,
			speed = 190,
			range = 70,
			size = Vector3.new(2, 2, 3),
			onHit = function(victim)
				c.Hit(character, victim, {
					damage = if last then 3 else 2,
					stun = if last then 0.9 else 0.5,
					attackType = "Bolt",
					heavy = last,
					velocity = if last then c.Flat(direction) * 40 + UP * 12 else c.Flat(direction) * 5,
					velocityTime = 0.15,
				})
			end,
		})
		task.wait(HASTA_BOLT_GAP)
	end
end

local function hastaBeam(ctx)
	local c, character = ctx.combat, ctx.character
	local started = os.clock()
	character:SetAttribute("Rooted", true)
	local origin, direction, length = ctx.root.Position, look(ctx), HASTA_LENGTH
	while os.clock() - started < HASTA_BEAM_MAX and not interrupted(ctx) do
		if not c.IsHeld(character, HASTA_SLOT) and os.clock() - started > 0.4 then
			break
		end
		CombatState.SetCasting(character, HASTA_BEAM_TICK + 0.3)
		origin = ctx.root.Position + look(ctx) * 3 + UP * 0.8
		direction = aimFrom(ctx, origin, softTarget(ctx, HASTA_LENGTH, 25), 0.4)
		length = reach(ctx, origin, direction, HASTA_LENGTH)
		fx(ctx, "QuartileHasta", "Beam", { origin = origin, direction = direction, length = length })
		for _, victim in lineVictims(ctx, origin, direction, length, 5) do
			c.Hit(character, victim, {
				damage = 1.1,
				stun = 0.45,
				attackType = "Bolt",
				noShake = true,
				velocity = c.Flat(direction) * 8,
				velocityTime = 0.12,
			})
		end
		task.wait(HASTA_BEAM_TICK)
	end
	character:SetAttribute("Rooted", false)
	if interrupted(ctx) then
		return
	end
	-- One last burst along it, breaking guards.
	fx(ctx, "QuartileHasta", "BeamEnd", { origin = origin, direction = direction, length = length })
	for _, victim in lineVictims(ctx, origin, direction, length, 6) do
		c.Hit(character, victim, {
			damage = 4,
			stun = 1,
			attackType = "Bolt",
			guardBreak = true,
			heavy = true,
			ragdoll = 1,
			velocity = c.Flat(direction) * 45 + UP * 15,
		})
	end
	c.ShakeArea(origin, 45, 0.4)
end

local function hastaRain(ctx)
	local c, character = ctx.combat, ctx.character
	CombatState.SetCasting(character, HASTA_RAIN_TIME + 0.3)
	c.ApplyVelocity(character, HOVER, HASTA_RAIN_TIME + 0.2)
	local center = floorUnder(ctx, ctx.root.Position + look(ctx) * 6)
	fx(ctx, "QuartileHasta", "Rain", { center = center, radius = HASTA_RAIN_RADIUS, duration = HASTA_RAIN_TIME })
	for _ = 1, HASTA_RAIN do
		if interrupted(ctx) then
			return
		end
		-- Half of them at whoever is in it, the rest anywhere in the circle.
		local spot
		local victims = c.Sphere(character, center + UP * 3, HASTA_RAIN_RADIUS)
		local victimRoot = if #victims > 0 and math.random() < 0.5
			then rootOf(victims[math.random(1, #victims)])
			else nil
		if victimRoot then
			spot = floorUnder(
				ctx,
				victimRoot.Position + Vector3.new(math.random(-15, 15) / 10, 0, math.random(-15, 15) / 10)
			)
		else
			local angle = math.random() * math.pi * 2
			spot = center
				+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * HASTA_RAIN_RADIUS * math.sqrt(math.random())
		end
		local from = ctx.root.Position + Vector3.new(math.random(-20, 20) / 10, 1, math.random(-20, 20) / 10)
		fx(ctx, "QuartileHasta", "Fall", { from = from, spot = spot })
		task.delay(0.18, function()
			for _, victim in c.Sphere(character, spot + UP * 2, 4) do
				c.Hit(character, victim, { damage = 1.8, stun = 0.5, attackType = "Explosion", noShake = true })
			end
		end)
		task.wait(HASTA_RAIN_TIME / HASTA_RAIN)
	end
end

local function quartileHasta(ctx)
	local c, character = ctx.combat, ctx.character
	local airborne = ctx.airborne
	CombatState.SetCasting(character, HASTA_CHARGE + 0.3)
	if airborne then
		c.ApplyVelocity(character, HOVER, HASTA_CHARGE + 0.2)
	end
	fx(ctx, "QuartileHasta", "Stars", { airborne = airborne })
	task.wait(HASTA_CHARGE)
	if interrupted(ctx) then
		fx(ctx, "QuartileHasta", "Done")
		return
	end
	if airborne then
		hastaRain(ctx)
	elseif c.IsHeld(character, HASTA_SLOT) then
		hastaBeam(ctx)
	else
		hastaBarrage(ctx)
	end
	fx(ctx, "QuartileHasta", "Done")
	CombatState.SetCasting(character, 0.2)
end

---------------------------------------------------------------------------
-- Full-Crown Spirit of Zephyr
---------------------------------------------------------------------------

--[[
	Spirit of Boreas (Full-Crown 1, the north wind): a great axe of wind
	forms in his hands, raised high, and he brings it down in one huge chop
	that splits the ground in a line ahead of him, through guards, throwing
	whoever is on it into the air. From the air he chops down at the ground
	ahead and below, spiking them.
]]
local BOREAS_RAISE = 0.42 -- the axe forms, raised (BoreasForm, then BoreasChop)
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
			heavy = true,
			ragdoll = 1,
			velocity = if airborne then forward * 10 + UP * -45 else forward * 8 + UP * 38,
		})
	end
	c.ShakeArea(origin + direction * length * 0.5, 55, 0.45)
	task.wait(0.15)
	CombatState.SetCasting(character, 0.4)
end

--[[
	Spirit of Zephyrus (Full-Crown 2, the west wind): his sword of wind grows
	long and he lunges at whoever he's facing on a burst of wind (steerable).
	Caught, they're cut three times in a blur of wind, held in front of him,
	and run through with a thrust that blows them away. From the air the
	lunge dives at them.
]]
local LUNGE_SPEED = 100
local LUNGE_TIME = 0.34
local LUNGE_STEER = 180
local LUNGE_CUTS = { 0.12, 0.24, 0.36 } -- after the catch
local LUNGE_THRUST = 0.52
local LUNGE_HOLD = 3.6 -- studs in front of him while he cuts

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
		direction = c.Flat(direction) -- a lunge, not a jump
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
	forward = look(ctx)
	if c.Hit(character, target, { damage = 3, stun = 1.4, attackType = "Melee" }) ~= "Hit" then
		fx(ctx, "SpiritOfZephyrus", "Whiff")
		CombatState.SetCasting(character, 0.4)
		return
	end

	-- The cuts, held in front of him in a blur of wind, then the thrust.
	CombatState.SetCasting(character, LUNGE_THRUST + 0.3)
	fx(ctx, "SpiritOfZephyrus", "Catch", { target = target })
	local caught = target :: Model
	local started = os.clock()
	local function pull(): Vector3
		local targetRoot = rootOf(caught)
		if not targetRoot then
			return Vector3.zero
		end
		local offset = ctx.root.Position + forward * LUNGE_HOLD - targetRoot.Position
		local flat = Vector3.new(offset.X, 0, offset.Z) / 0.12
		return if flat.Magnitude > 30 then flat.Unit * 30 else flat
	end
	for index, at in LUNGE_CUTS do
		task.wait(math.max(at - (os.clock() - started), 0))
		if interrupted(ctx) or not CombatState.IsAlive(caught) then
			return
		end
		local hit = c.Hit(character, caught, {
			damage = 1.5,
			stun = 1,
			attackType = "Melee",
			noShake = true,
			velocity = pull(),
			velocityTime = 0.12,
		})
		if hit ~= "Hit" then
			return
		end
		fx(ctx, "SpiritOfZephyrus", "Cut", { target = caught, index = index })
	end
	task.wait(math.max(LUNGE_THRUST - (os.clock() - started), 0))
	if interrupted(ctx) or not CombatState.IsAlive(caught) then
		return
	end
	fx(ctx, "SpiritOfZephyrus", "Thrust", { target = caught, direction = forward })
	c.Hit(character, caught, {
		damage = 4,
		stun = 1,
		attackType = "Melee",
		heavy = true,
		ragdoll = 1,
		velocity = forward * 65 + UP * 18,
	})
	c.ShakeArea(ctx.root.Position, 40, 0.3)
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
	for _, victim in lineVictims(ctx, origin, direction, length, 6) do -- a giant arrow
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

--[[
	Saint Spirit of Zephyr (Full-Crown 4): a 6-second cutscene. He flicks a
	star at whoever is in front of him (about 15 studs); it binds them and a
	column of wind carries them 32 studs into the sky, him flying up beside
	them. A constellation of twelve stars opens round them and Conjunction
	takes him through them from star to star, faster and faster, then an X;
	then he's high above them and splits them with one strike of wind and
	starlight down through them to the ground. The cuts left hanging in the
	air detonate and they fall like a meteor into the ground. The timeline
	is Shared/SaintZephyr, the camera work and effects client side.
]]
local SAINT_FLICK = 0.2 -- the star leaves his hand (Conjunction's point)
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

	local plan = SaintPlan.Plan(ctx.root.CFrame, targetRoot.Position, floorUnder(ctx, targetRoot.Position).Y)
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
		cut(0.9)
	end
	waitUntil(times.Cross)
	cut(2)
	waitUntil(times.Strike)
	if CombatState.IsAlive(target) then
		c.Hit(character, target, { damage = 3, stun = 3, attackType = "Melee", unblockable = true, noShake = true })
	end

	-- The cuts burst and drive them into the ground.
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

---------------------------------------------------------------------------
-- Move sets
---------------------------------------------------------------------------

Kit.Skills = { windBladesShower, swiftWhiteHawk, heavenlyWindArk, galeWhiteBow }

-- Awakened, the moves follow the stage: Half-Crown, or Full-Crown once he's
-- ascended (the "Ascended" attribute; names and cooldowns in Shared/Kits).
local HALF_CROWN = { spiritStorm, tempestDive, quartileScutum, quartileHasta }
local FULL_CROWN = { spiritOfBoreas, spiritOfZephyrus, spiritOfEuros, saintSpiritOfZephyr }
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

-- Spawn entrance: wind gathers round him and his grimoire comes down out of
-- the sky to him, Sylph darting round him; he raises a hand, the clover
-- flares and the wind bursts out. Untouchable and rooted while it plays
-- (the animation and effects are client side).
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
