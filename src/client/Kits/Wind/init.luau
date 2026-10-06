local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaintPlan = require(ReplicatedStorage:WaitForChild("Shared").SaintZephyr)
local PoseAnimator = require(script.Parent.Parent.PoseAnimator)
local VFX = require(script.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Soft)

local U = VFX.Util
local UP = Vector3.yAxis

local WIND, WIND_DEEP, WIND_WHITE = Soft.WIND, Soft.WIND_DEEP, Soft.WIND_WHITE
local STAR_WHITE = Soft.STAR_WHITE
local windRing, lightRing, windPuff = Soft.windRing, Soft.lightRing, Soft.windPuff
local twinkle = Soft.twinkle

local Fx = require(script.Fx)
local ANIMS, handlers, play, featherBurst = Fx.ANIMS, Fx.handlers, Fx.play, Fx.featherBurst
local gust = Soft.gust
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
	air = ANIMS.HoverIdle,
	moveSpeed = 16,
}

function Kit.IdleFor(character: Model): PoseAnimator.IdleSet
	return if character:GetAttribute("Awakened") == true then HOVER else Kit.Idle
end

local SWIPES = { "Swipe1", "Swipe2", "Swipe3" }
local FINISHERS = { Knockback = "GalePush", Uppercut = "GaleRise", Downslam = "GaleFall" }
local ARCS: { [string]: { from: Vector3?, to: Vector3?, limbs: { string } } } = {
	Swipe1 = { from = Vector3.new(3.2, 0.6, -1.4), to = Vector3.new(-3.2, 0.6, -1.4), limbs = { "Right Arm" } },
	Swipe2 = { from = Vector3.new(-3.2, 0.4, -1.4), to = Vector3.new(3.2, 0.6, -1.4), limbs = { "Left Arm" } },
	Swipe3 = { from = Vector3.new(-2.6, -1.4, -1.6), to = Vector3.new(2.4, 2.8, -1.6), limbs = { "Right Arm" } },
	GalePush = { limbs = { "Right Arm", "Left Arm" } },
	GaleRise = {
		from = Vector3.new(0.4, -2.4, -2),
		to = Vector3.new(-0.4, 4.2, -2),
		limbs = { "Right Arm", "Left Arm" },
	},
	GaleFall = {
		from = Vector3.new(-0.4, 3.6, -2),
		to = Vector3.new(0.4, -3.4, -2.6),
		limbs = { "Right Arm", "Left Arm" },
	},
}

function Kit.PlayM1(character: Model, index: number, variant: string)
	local name = if variant ~= "Normal" then FINISHERS[variant] or "GalePush" else SWIPES[((index - 1) % #SWIPES) + 1]
	local animation = ANIMS[name]
	local arc = ARCS[name]
	if not animation or not arc then
		return
	end
	local heavy = variant ~= "Normal"
	play(character, animation, function(event)
		local root = U.getRoot(character)
		if event ~= "Strike" or not root then
			return
		end
		for _, limbName in arc.limbs do
			VFX.LimbTrail(character, limbName, if heavy then 0.2 else 0.13, WIND)
		end
		local frame = root.CFrame
		local forward = frame.LookVector
		if arc.from and arc.to then
			local from, to = frame * arc.from, frame * arc.to
			local slash =
				Soft.windSlash(from, to, forward * (if heavy then 2.6 else 2), if heavy then 0.7 else 0.42, 0.05)
			if heavy then
				slash.flare()
			end
			task.delay(if heavy then 0.18 else 0.08, slash.fade, if heavy then 0.3 else 0.2)
			local middle = from:Lerp(to, 0.5) + forward * 1.6
			windPuff(middle, if heavy then 1.6 else 0.8, forward)
			Soft.streaks(middle, if heavy then 8 else 4, 26, forward, 30)
		end
		if name == "GalePush" then
			local at = frame * Vector3.new(0, 0.4, -2.6)
			gust(at, 3.2, forward)
			windRing(at, forward, 0.6, 4.5, 0.3)
			lightRing(at + forward * 0.6, forward, 0.4, 3.2, 0.22, WIND_WHITE)
			Soft.streaks(at, 12, 44, forward, 18)
			featherBurst(at, 5, 14)
			U.flash(at, WIND_WHITE, 3.2, 0.12)
		elseif name == "GaleRise" then
			windRing(frame.Position - UP * 2.6, UP, 0.8, 5.5, 0.3)
			gust(frame * Vector3.new(0, -0.5, -2.4), 3, UP)
			featherBurst(frame * Vector3.new(0, 1, -2.4), 4, 12)
		elseif name == "GaleFall" then
			local below = U.groundBelow(frame.Position + forward * 2, { character }, 30)
			if below then
				task.delay(0.08, windRing, below.Position + UP * 0.2, UP, 1, 6.5, 0.35)
				task.delay(0.08, windPuff, below.Position + UP * 0.6, 2.4, UP)
			end
			gust(frame * Vector3.new(0, -1, -2.4), 3, -UP)
		end
		if heavy then
			twinkle(frame * Vector3.new(0, 0.5, -3), 2.5, WIND, 0.2)
		end
	end)
end

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
