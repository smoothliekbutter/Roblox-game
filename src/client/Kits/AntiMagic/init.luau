-- Anti-Magic Knight (Asta), client: M1s, skill events and dash / block effects. The moves are drawn by
-- Base and Form, the Black Form look by Look, the cutscenes by Moon, Comet and Ascent (shared pieces: Fx).

local CameraShake = require(script.Parent.Parent.CameraShake)
local VFX = require(script.Parent.Parent.VFX)

local U = VFX.Util

local Fx = require(script.Fx)
local BLACK, RED, DARK_RED, UP, ANIMS, handlers = Fx.BLACK, Fx.RED, Fx.DARK_RED, Fx.UP, Fx.ANIMS, Fx.handlers
local play, swordTrail, blackSmoke, blackLightning = Fx.play, Fx.swordTrail, Fx.blackSmoke, Fx.blackLightning
local Look = require(script.Look)
local setAwakened, revealAt = Look.setAwakened, Look.revealAt
require(script.Moon)
require(script.Base)
require(script.Form)

local Kit = {}

VFX.SetPalette("AntiMagic", {
	hit = Color3.fromRGB(220, 50, 60),
	heavy = Color3.fromRGB(170, 15, 25),
	flash = Color3.fromRGB(255, 225, 225),
	cleanM1 = true, -- sleek sword M1s: no sparks or rings on hit
})

Kit.Idle = {
	stand = ANIMS.Idle,
	move = ANIMS.Run,
	walk = ANIMS.Walk,
	air = ANIMS.Air,
	moveSpeed = 16,
	walkSpeed = 8,
	moveStride = 11.32,
	walkStride = 6.57,
}

-- Getting hit / blocking, with the sword (see Client/Reactions for the names).
Kit.Reactions = {
	FlinchA = ANIMS.FlinchA,
	FlinchB = ANIMS.FlinchB,
	FlinchBack = ANIMS.FlinchBack,
	HitHeavy = ANIMS.HitHeavy,
	Guard = ANIMS.Guard,
	GuardHit = ANIMS.GuardHit,
	Stagger = ANIMS.Stagger,
	Grabbed = ANIMS.Grabbed,
	Launched = ANIMS.Launched,
}

-- M1

local STRING = { "Slash1", "Slash2", "Slash3" }
local FINISHERS = { Knockback = "Cleave", Uppercut = "Rising", Downslam = "Chop" }

-- M1s are just the sword swinging: no trails, no extra effects.
function Kit.PlayM1(character: Model, index: number, variant: string)
	local name = if variant ~= "Normal" then FINISHERS[variant] or "Cleave" else STRING[((index - 1) % #STRING) + 1]
	play(character, ANIMS[name])
end

-- Skills (each module adds its own to Fx's handlers)

function Kit.OnSkill(data)
	local character = data.character
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	local root = U.getRoot(character)
	local handler = handlers[data.skill]
	if root and handler then
		handler(data, character, root)
	end
end

local DASH_DIRECTIONS = {
	Front = Vector3.new(0, 0, -1),
	Back = Vector3.new(0, 0, 1),
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
}

VFX.RegisterKitEffect("AntiMagic", "Dash", function(data)
	local character: Model? = data.character
	local root = U.getRoot(character)
	if not character or not root then
		return
	end
	local direction = if type(data.direction) == "string" then data.direction else "Front"
	local animation = ANIMS["Dash" .. direction]
	if animation then
		play(character, animation)
	end
	swordTrail(character, 0.26)

	U.afterimage(character, BLACK, 0.3)
	for i = 1, 3 do
		task.delay(i * 0.05, function()
			if character.Parent then
				U.afterimage(character, if i == 3 then DARK_RED else BLACK, 0.25)
			end
		end)
	end

	local ground = U.groundBelow(root.Position, { character })
	local feet = if ground then ground.Position else root.Position - UP * 3
	blackSmoke(feet + UP * 0.4, 6, 2.2, 7)
	U.ringBurst(CFrame.new(feet + UP * 0.1), BLACK, 0.6, 3.5, 0.25, 0.14)
	if ground then
		U.dustWave(feet, 4, nil, 8)
	end

	-- Sparks fly off opposite to the dash.
	local away = -(root.CFrame:VectorToWorldSpace(DASH_DIRECTIONS[direction] or DASH_DIRECTIONS.Front))
	U.burst(root.Position - UP * 0.5, {
		color = RED,
		count = 7,
		size = 0.35,
		speed = NumberRange.new(14, 26),
		lifetime = NumberRange.new(0.12, 0.25),
		streaks = true,
		spread = 30,
		direction = away,
	})
end)

local function clashDirection(data): Vector3
	local victimRoot = U.getRoot(data.victim)
	local attackerRoot = U.getRoot(data.attacker)
	if victimRoot and attackerRoot then
		local toward = attackerRoot.Position - victimRoot.Position
		return (Vector3.new(toward.X, 0, toward.Z).Unit + UP * 0.7).Unit
	end
	return UP
end

VFX.RegisterKitEffect("AntiMagic", "Block", function(data)
	local position: Vector3 = data.position
	U.sparks(position, clashDirection(data), 1)
	U.highlight(data.victim, Color3.fromRGB(255, 170, 80), 0.1)
	if U.isLocal(data.attacker) or U.isLocal(data.victim) then
		CameraShake.Add(0.12)
	end
end)

VFX.RegisterKitEffect("AntiMagic", "GuardBreak", function(data)
	local position: Vector3 = data.position
	local direction = clashDirection(data)
	U.sparks(position, direction, 1.8)
	task.delay(0.05, U.sparks, position, (direction + U.randomUnit() * 0.4).Unit, 1.2)
	U.shards(position, Color3.fromRGB(255, 160, 60), 12)
	U.flash(position, Color3.fromRGB(255, 190, 110), 6, 0.2)
	U.light(position, Color3.fromRGB(255, 140, 50), 10, 18, 0.35)
	U.highlight(data.victim, Color3.fromRGB(255, 140, 50), 0.35)
	U.popup(position + UP * 2, "GUARD BREAK", Color3.fromRGB(255, 170, 60), 1.5)
	if U.isLocal(data.attacker) or U.isLocal(data.victim) then
		CameraShake.Add(0.4)
	end
end)

VFX.RegisterKitEffect("AntiMagic", "PerfectBlock", function(data)
	VFX.PlayDefault("PerfectBlock", data)
	U.sparks(data.position, clashDirection(data), 1.4)
end)

function Kit.SetAwakened(character: Model, on: boolean)
	-- During the transformation the look waits for the burst.
	if on and (revealAt[character] or 0) > os.clock() then
		return
	end
	setAwakened(character, on)
end

-- A brighter, black-lightning version of the heavy hit for perfect Dividers.
VFX.Register("PerfectDivider", function(data)
	VFX.Play("HeavyHit", data)
	local position: Vector3 = data.position
	blackLightning(position, 8, 6)
	blackSmoke(position, 12, 4, 20)
	U.flash(position, BLACK, 9, 0.25)
	if U.isLocal(data.attacker) or U.isLocal(data.victim) then
		CameraShake.Add(0.5)
	end
end)

return Kit
