-- Prince of Wind (Yuno), client: M1s, skill events and dash / air jump effects. The moves are drawn by
-- Base, Half and Full, the Crown looks by Look (shared pieces: Fx; cutscenes: Saint, Nova, Waltz).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaintPlan = require(ReplicatedStorage:WaitForChild("Shared").SaintZephyr)
local M1Animations = require(script.Parent.Parent.M1Animations)
local PoseAnimator = require(script.Parent.Parent.PoseAnimator)
local VFX = require(script.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Soft)

local U = VFX.Util
local UP = Vector3.yAxis

-- The palette and the soft wind everything is drawn with (see Soft).
local WIND, WIND_DEEP, WIND_WHITE = Soft.WIND, Soft.WIND_DEEP, Soft.WIND_WHITE
local STAR_WHITE = Soft.STAR_WHITE
local windRing, lightRing, windPuff = Soft.windRing, Soft.lightRing, Soft.windPuff
local twinkle = Soft.twinkle

local Fx = require(script.Fx)
local ANIMS, handlers, play, featherBurst = Fx.ANIMS, Fx.handlers, Fx.play, Fx.featherBurst
require(script.Base)
require(script.Half)
local Look = require(script.Look)
local buildLook = Look.buildLook
require(script.Full)

local Kit = {}

VFX.SetPalette("Wind", { hit = WIND, heavy = WIND_DEEP, flash = WIND_WHITE })

Kit.Idle = {
	stand = ANIMS.Idle,
	move = ANIMS.Run,
	walk = ANIMS.Walk,
	air = ANIMS.Air,
	moveSpeed = 16,
	walkSpeed = 8,
	moveStride = 10.88,
	walkStride = 6.13,
}

local HOVER = {
	stand = ANIMS.HoverIdle,
	move = ANIMS.HoverMove,
	air = ANIMS.HoverIdle, -- still carried on the wind (so a jump doesn't drop him)
	moveSpeed = 16,
}

-- The idle set for him right now (Moves asks when the kit is put on).
function Kit.IdleFor(character: Model): PoseAnimator.IdleSet
	return if character:GetAttribute("Awakened") == true then HOVER else Kit.Idle
end

-- M1: wind-wrapped strikes (the shared fist string), each with a gust

function Kit.PlayM1(character: Model, index: number, variant: string)
	local name = M1Animations.NameFor(index, variant)
	local animation = M1Animations.Clips[name]
	if not animation then
		return
	end
	local heavy = variant ~= "Normal"
	local strikers = M1Animations.Strikers[name] or {}
	play(character, animation, function(event)
		if event ~= "Strike" then
			return
		end
		for _, limbName in strikers do
			VFX.LimbTrail(character, limbName, if heavy then 0.2 else 0.13, WIND)
			local limb = character:FindFirstChild(limbName)
			if limb and limb:IsA("BasePart") then
				local tip = (limb.CFrame * CFrame.new(0, -1, 0)).Position
				local out = (limb.CFrame.LookVector * -1 + limb.CFrame.UpVector * -1).Unit
				U.burst(tip, {
					color = WIND_WHITE,
					count = if heavy then 10 else 5,
					size = 0.35,
					speed = NumberRange.new(10, 24),
					lifetime = NumberRange.new(0.1, 0.22),
					streaks = true,
					spread = 50,
					direction = out,
				})
				-- A breath of wind off the blow (a ring of it on the heavy ones).
				windPuff(tip, if heavy then 1.4 else 0.8, out)
				if heavy then
					lightRing(tip, out, 0.3, 2.4, 0.16, WIND_WHITE)
				end
			end
		end
		VFX.AirPop(character, heavy)
	end)
end

-- Half-Crown / Full-Crown (the looks are built by Look)

local destroyLook: { [Model]: () -> () } = {}
local stageWatch: { [Model]: RBXScriptConnection } = {}

function Kit.SetAwakened(character: Model, on: boolean)
	local watch = stageWatch[character]
	if watch then
		watch:Disconnect()
		stageWatch[character] = nil
	end
	local destroy = destroyLook[character]
	if destroy then
		destroyLook[character] = nil
		destroy()
	end
	PoseAnimator.SetIdle(character, if on then HOVER else Kit.Idle)
	-- Hovering under everything he does (attacks too), not only standing.
	PoseAnimator.SetLift(character, if on then SaintPlan.Lift else 0)
	if not on then
		return
	end
	local function rebuild()
		local old = destroyLook[character]
		if old then
			old()
		end
		destroyLook[character] = buildLook(character, character:GetAttribute("Ascended") == true)
	end
	rebuild()
	stageWatch[character] = character:GetAttributeChangedSignal("Ascended"):Connect(function()
		if character:GetAttribute("Awakened") == true then
			rebuild()
		end
	end)
end

-- Movement: a green dash on the wind, and the gust under his air jump

local DASH_VECTORS = {
	Front = Vector3.new(0, 0, -1),
	Back = Vector3.new(0, 0, 1),
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
}

VFX.RegisterKitEffect("Wind", "Dash", function(data)
	local character: Model? = data.character
	local root = U.getRoot(character)
	if not character or not root then
		return
	end
	local direction = if type(data.direction) == "string" then data.direction else "Front"
	U.afterimage(character, WIND, 0.3)
	for i = 1, 3 do
		task.delay(i * 0.05, function()
			if character.Parent then
				U.afterimage(character, if i == 3 then WIND_WHITE else WIND, 0.25)
			end
		end)
	end
	U.bodyTrail(character, WIND, 0.28)
	local ground = U.groundBelow(root.Position, { character })
	local feet = if ground then ground.Position else root.Position - UP * 3
	U.ringBurst(CFrame.new(feet + UP * 0.1), WIND, 0.6, 3.8, 0.25, 0.14)
	featherBurst(root.Position, 3, 7)
	local away = -(root.CFrame:VectorToWorldSpace(DASH_VECTORS[direction] or DASH_VECTORS.Front))
	windRing(feet + UP * 0.2, UP, 0.6, 4.5, 0.3)
	windPuff(root.Position - UP * 1.5, 1.6, away)
	U.burst(root.Position - UP * 0.5, {
		color = WIND_WHITE,
		count = 10,
		size = 0.35,
		speed = NumberRange.new(16, 30),
		lifetime = NumberRange.new(0.12, 0.25),
		streaks = true,
		spread = 35,
		direction = away,
	})
	U.light(root.Position, WIND, 2, 10, 0.25)
end)

VFX.RegisterKitEffect("Wind", "Hit", function(data)
	VFX.PlayDefault("Hit", data)
	if data.kit ~= "Wind" or typeof(data.position) ~= "Vector3" then
		return
	end
	local position: Vector3 = data.position
	local direction: Vector3 = if typeof(data.direction) == "Vector3" then data.direction else UP
	featherBurst(position, 2, 8)
	lightRing(position, direction, 0.3, 2.4, 0.15, WIND_WHITE)
end)

VFX.RegisterKitEffect("Wind", "HeavyHit", function(data)
	VFX.PlayDefault("HeavyHit", data)
	if data.kit ~= "Wind" or typeof(data.position) ~= "Vector3" then
		return
	end
	local position: Vector3 = data.position
	local direction: Vector3 = if typeof(data.direction) == "Vector3" then data.direction else UP
	U.impactSpikes(position, WIND, 8, 5, 0.22, STAR_WHITE)
	featherBurst(position, 6, 14)
	windRing(position, direction, 0.5, 5, 0.25)
	twinkle(position, 2.5, WIND, 0.2)
end)

VFX.RegisterKitEffect("Wind", "AirJump", function(data)
	local character: Model? = data.character
	local root = U.getRoot(character)
	if not character or not root then
		return
	end
	local feet = root.Position - UP * 3
	U.ringBurst(CFrame.new(feet), WIND, 0.8, 4.2, 0.3, 0.16)
	windRing(feet, UP, 0.6, 5, 0.3)
	windPuff(feet, 1.6, -UP)
	U.burst(feet, {
		color = WIND_WHITE,
		count = 12,
		size = 0.4,
		speed = NumberRange.new(12, 26),
		lifetime = NumberRange.new(0.15, 0.3),
		streaks = true,
		spread = 50,
		direction = -UP,
	})
	U.afterimage(character, WIND, 0.2)
	featherBurst(feet, 3, 6)
end)

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

return Kit
