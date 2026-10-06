local PoseAnimator = require(script.Parent.Parent.PoseAnimator)
local VFX = require(script.Parent.Parent.VFX)

local U = VFX.Util
local UP = Vector3.yAxis

local Fx = require(script.Fx)
local ANIMS, handlers, play = Fx.ANIMS, Fx.handlers, Fx.play
local WATER, WATER_LIGHT, FOAM = Fx.WATER, Fx.WATER_LIGHT, Fx.FOAM
local ripple, shine, spray, mist, droplets, splash = Fx.ripple, Fx.shine, Fx.spray, Fx.mist, Fx.droplets, Fx.splash
local crown, geyser, stream = Fx.crown, Fx.geyser, Fx.stream
require(script.Base)
local Look = require(script.Look)
require(script.Valkyrie)
require(script.Dragon)

local LIFT = 1.8

local Kit = {}

VFX.SetPalette("Water", { hit = WATER_LIGHT, heavy = WATER, flash = FOAM })

Kit.Idle = {
	stand = ANIMS.Idle,
	move = ANIMS.Run,
	walk = ANIMS.Walk,
	air = ANIMS.Air,
	moveSpeed = 16,
	walkSpeed = 8,
	moveStride = 10.47,
	walkStride = 5.69,
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

local LASHES = { "Lash1", "Lash2", "Lash3" }
local FINISHERS = { Knockback = "TidalPalm", Uppercut = "Geyser", Downslam = "Torrent" }
local ARCS: { [string]: { from: Vector3?, to: Vector3?, limbs: { string } } } = {
	Lash1 = { from = Vector3.new(-3, 0.4, -1.6), to = Vector3.new(3.4, 0.8, -1.4), limbs = { "Right Arm" } },
	Lash2 = { from = Vector3.new(3, 0.4, -1.6), to = Vector3.new(-3.4, 0.8, -1.4), limbs = { "Left Arm" } },
	Lash3 = { from = Vector3.new(0.6, 4, -1.2), to = Vector3.new(-0.2, -1.4, -2.8), limbs = { "Right Arm" } },
	TidalPalm = { limbs = { "Right Arm" } },
	Geyser = { from = Vector3.new(0.4, -2.2, -2), to = Vector3.new(-0.3, 4.4, -2), limbs = { "Right Arm" } },
	Torrent = {
		from = Vector3.new(-0.4, 3.6, -2),
		to = Vector3.new(0.4, -3.4, -2.6),
		limbs = { "Right Arm", "Left Arm" },
	},
}

function Kit.PlayM1(character: Model, index: number, variant: string)
	local name = if variant ~= "Normal" then FINISHERS[variant] or "TidalPalm" else LASHES[((index - 1) % #LASHES) + 1]
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
			VFX.LimbTrail(character, limbName, if heavy then 0.2 else 0.13, WATER_LIGHT)
		end
		local frame = root.CFrame
		local forward = frame.LookVector
		if arc.from and arc.to then
			local from, to = frame * arc.from, frame * arc.to
			local whip = Fx.lash(from, to, forward * (if heavy then 2.6 else 2), if heavy then 0.7 else 0.42, 0.05)
			if heavy then
				whip.flare()
			end
			task.delay(if heavy then 0.18 else 0.08, whip.fade, if heavy then 0.3 else 0.2)
			local middle = from:Lerp(to, 0.5) + forward * 1.6
			mist(middle, if heavy then 1.4 else 0.7, forward)
			droplets(middle, if heavy then 6 else 3, 14, forward, 0.3)
		end
		if name == "TidalPalm" then
			local at = frame * Vector3.new(0, 0.4, -2.8)
			splash(at, 3.2, forward)
			ripple(at, forward, 0.6, 4.5, 0.3, 1)
			shine(at + forward * 0.6, forward, 0.4, 3.2, 0.22)
			spray(at, 18, 40, forward, 25)
			U.flash(at, FOAM, 3.2, 0.12)
		elseif name == "Geyser" then
			local ground = Fx.floorAt(frame.Position + forward * 3.5, 8)
			if ground then
				geyser(ground.Position, 7, 1.2, 0.6)
				crown(ground.Position, 1.4, 2.5, 0.5, 12)
			end
			ripple(frame.Position - UP * 2.6, UP, 0.8, 5.5, 0.3, 0.9)
		elseif name == "Torrent" then
			local below = U.groundBelow(frame.Position + forward * 2, { character }, 30)
			local top = frame * Vector3.new(0, 1, -2.4)
			local bottom = if below then below.Position else top - UP * 8
			local fall = stream(1.6, 24)
			fall.set(top, bottom)
			task.delay(0.18, fall.fade, 0.25)
			if below then
				task.delay(0.08, splash, below.Position + UP * 0.4, 4)
			end
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
	PoseAnimator.SetLift(character, if on then LIFT else 0)
	if not on then
		return
	end
	local function rebuild()
		local old = destroyLook[character]
		if old then
			old()
		end
		destroyLook[character] = Look.build(character, character:GetAttribute("Ascended") == true)
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

VFX.RegisterKitEffect("Water", "Dash", function(data)
	local character: Model? = data.character
	local root = U.getRoot(character)
	if not character or not root then
		return
	end
	local direction = if type(data.direction) == "string" then data.direction else "Front"
	U.afterimage(character, WATER_LIGHT, 0.3)
	for i = 1, 3 do
		task.delay(i * 0.05, function()
			if character.Parent then
				U.afterimage(character, if i == 3 then FOAM else WATER, 0.25)
			end
		end)
	end
	U.bodyTrail(character, WATER_LIGHT, 0.28)
	local ground = U.groundBelow(root.Position, { character })
	local feet = if ground then ground.Position else root.Position - UP * 3
	local away = -(root.CFrame:VectorToWorldSpace(DASH_VECTORS[direction] or DASH_VECTORS.Front))
	ripple(feet + UP * 0.1, UP, 0.6, 4.5, 0.35, 0.9)
	shine(feet + UP * 0.1, UP, 0.4, 3.6, 0.25)
	spray(root.Position - UP * 1.5, 12, 26, away + UP * 0.4, 35)
	mist(root.Position - UP * 1.5, 1.4, away)
	droplets(feet + UP * 0.5, 4, 12, UP, 0.3)
	U.light(root.Position, WATER, 2, 10, 0.25)
end)

VFX.RegisterKitEffect("Water", "Hit", function(data)
	VFX.PlayDefault("Hit", data)
	if data.kit ~= "Water" or typeof(data.position) ~= "Vector3" then
		return
	end
	local position: Vector3 = data.position
	local direction: Vector3 = if typeof(data.direction) == "Vector3" then data.direction else UP
	spray(position, 8, 20, direction, 50)
	shine(position, direction, 0.3, 2.4, 0.15)
end)

VFX.RegisterKitEffect("Water", "HeavyHit", function(data)
	VFX.PlayDefault("HeavyHit", data)
	if data.kit ~= "Water" or typeof(data.position) ~= "Vector3" then
		return
	end
	local position: Vector3 = data.position
	local direction: Vector3 = if typeof(data.direction) == "Vector3" then data.direction else UP
	U.impactSpikes(position, WATER, 8, 5, 0.22, FOAM)
	splash(position, 3, direction)
	ripple(position, direction, 0.5, 5, 0.25, 1)
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
