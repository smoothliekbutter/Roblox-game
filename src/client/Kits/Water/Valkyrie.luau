local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DivePlan = require(ReplicatedStorage:WaitForChild("Shared").MermaidDive)
local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local VFX = require(script.Parent.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Parent.Soft)

local U = VFX.Util
local rad = math.rad
local UP = Vector3.yAxis

local Fx = require(script.Parent.Fx)
local Base = require(script.Parent.Base)
local Lance = require(script.Parent.Lance)
local Look = require(script.Parent.Look)
local Serpent = require(script.Parent.Serpent)

local ANIMS, handlers, play, bump, live, handOf = Fx.ANIMS, Fx.handlers, Fx.play, Fx.bump, Fx.live, Fx.handOf
local easeOut = Fx.easeOut
local WATER, WATER_LIGHT, FOAM = Fx.WATER, Fx.WATER_LIGHT, Fx.FOAM
local ripple, shine, spray, mist, droplets, splash = Fx.ripple, Fx.shine, Fx.spray, Fx.mist, Fx.droplets, Fx.splash
local crown, puddle, bubbles, geyser, stream, whirl = Fx.crown, Fx.puddle, Fx.bubbles, Fx.geyser, Fx.stream, Fx.whirl
local every, key = Soft.every, Soft.key
local SMOKE = Soft.SMOKE
local near, gather, crater = Base.near, Base.gather, Base.crater

local function ellipsoid(size: Vector3, color: Color3, material: Enum.Material, transparency: number): BasePart
	local part = U.newPart({ Size = Vector3.one, Color = color, Material = material, Transparency = transparency })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = part
	return part
end

type Drill = { place: (CFrame, Vector3) -> (), stop: (number) -> () }

local function drill(scale: number): Drill
	local cone = ellipsoid(Vector3.new(1.5, 1.5, 4.4) * scale, WATER_LIGHT, Enum.Material.Glass, 0.5)
	local skin = ellipsoid(Vector3.new(1.7, 1.7, 4.8) * scale, WATER, Enum.Material.ForceField, 0)
	local rings: { Soft.Ring } = {}
	for i = 1, 3 do
		table.insert(
			rings,
			Soft.softRing({
				color = ColorSequence.new(FOAM, WATER_LIGHT),
				width0 = 0.35 * scale,
				width1 = 0.35 * scale,
				transparency = NumberSequence.new(0.3 + i * 0.1),
				texture = SMOKE,
				speed = 6,
				length = 2,
			})
		)
	end
	local fizz = bubbles(cone, 25, 0.3 * scale)
	local spin = 0
	local result = {}
	function result.place(frame: CFrame, tip: Vector3)
		spin += 0.6
		local along = frame.LookVector
		local center = tip - along * 1.6 * scale
		local spun = CFrame.lookAt(center, center + along) * CFrame.Angles(0, 0, spin)
		cone.CFrame = spun
		skin.CFrame = spun
		for i, ring in rings do
			local ringFrame = CFrame.lookAt(center, center + along) * CFrame.Angles(rad(90), 0, 0)
			ring.set(
				ringFrame * CFrame.new(0, (i - 2) * 1.1 * scale, 0) * CFrame.Angles(0, spin * (1 + i * 0.3), 0),
				(1.1 - (i - 1) * 0.3) * scale
			)
		end
	end
	function result.stop(duration: number)
		fizz.Enabled = false
		for _, ring in rings do
			ring.fade(duration)
		end
		Soft.fadeOut({ cone, skin }, duration)
		task.delay(1, fizz.Destroy, fizz)
	end
	return result
end

type Charge = { token: number, drill: Drill?, stopHelix: (() -> ())?, done: boolean, serpent: Serpent.Serpent? }
local charges: { [Model]: Charge } = setmetatable({}, { __mode = "k" }) :: any

local function endCharge(character: Model, fade: number)
	local state = charges[character]
	charges[character] = nil
	if not state then
		return
	end
	state.done = true
	if state.drill then
		state.drill.stop(fade)
	end
	if state.stopHelix then
		state.stopHelix()
	end
	if state.serpent then
		state.serpent.fade(fade)
	end
end

local function lanceTip(character: Model, root: BasePart): Vector3
	return Look.lanceTip(character) or (root.Position + root.CFrame.LookVector * 5)
end

function handlers.ValkyrieLance(data, character, root)
	local phase = data.phase
	if phase == "Ready" then
		play(character, ANIMS.LanceReady)
		Look.hold(character, "Aim", 1.4)
		endCharge(character, 0.1)
		local token = bump(character)
		every(0.2, function()
			if not live(character, token) then
				return false
			end
			gather(lanceTip(character, root), 3)
			return true
		end)
		whirl(root.Position - UP * 2.8, UP, 4, 0.4, 7)
		shine(lanceTip(character, root), root.CFrame.LookVector, 0.3, 2.5, 0.2)
	elseif phase == "Charge" then
		play(character, ANIMS.LanceRush)
		local duration: number = data.duration or 0.42
		local dragon = data.dragon == true
		Look.hold(character, "Aim", duration + 0.6)
		Look.spin(character, duration + 0.5)
		local token = bump(character)
		local spiral = drill(if dragon then 1.35 else 1)
		local state: Charge = { token = token, drill = spiral, stopHelix = nil, done = false, serpent = nil }
		charges[character] = state
		if dragon then
			state.serpent = Serpent.new(0.55, 6)
		end
		state.stopHelix = Soft.helix(function()
			local tip = lanceTip(character, root)
			return root.Position - root.CFrame.LookVector * 2, tip
		end, if dragon then 1.6 else 1.2, 3, 0.25, 2.5, 0.5, duration + 0.4, WATER)
		local wake = stream(1.3, 18)
		every(duration + 0.4, function()
			if state.done or charges[character] ~= state then
				return false
			end
			local tip = lanceTip(character, root)
			local frame = CFrame.lookAt(root.Position, root.Position + root.CFrame.LookVector)
			spiral.place(frame, tip)
			if state.serpent then
				state.serpent.place(CFrame.lookAt(tip, tip + root.CFrame.LookVector), 0.9)
			end
			wake.set(root.Position - root.CFrame.LookVector * 1.5, root.Position - root.CFrame.LookVector * 7)
			local ground = Fx.floorAt(root.Position, 8)
			if ground and math.random() < 0.4 then
				ripple(ground.Position + UP * 0.1, UP, 0.6, 4, 0.35, 0.8)
				spray(ground.Position, 3, 16, UP - root.CFrame.LookVector, 30)
			end
			return true
		end, function()
			wake.fade(0.25)
			if charges[character] == state then
				endCharge(character, 0.2)
			end
		end)
		U.afterimage(character, WATER_LIGHT, 0.3)
		U.bodyTrail(character, WATER_LIGHT, duration)
		spray(root.Position, 16, 30, -root.CFrame.LookVector, 40)
		ripple(root.Position, root.CFrame.LookVector, 1, 6, 0.3, 1.2)
		if U.isLocal(character) then
			CameraShake.FovKick(8)
			U.speedLines(root, root.CFrame.LookVector, duration, WATER_LIGHT)
		end
	elseif phase == "Pierce" then
		local tip = lanceTip(character, root)
		splash(tip, 4, root.CFrame.LookVector)
		shine(tip, root.CFrame.LookVector, 0.5, 5, 0.25)
		U.flash(tip, FOAM, 4, 0.12)
		U.burst(tip, {
			color = FOAM,
			count = 16,
			size = 0.5,
			speed = NumberRange.new(20, 40),
			lifetime = NumberRange.new(0.2, 0.4),
			streaks = true,
			spread = 70,
			direction = -root.CFrame.LookVector,
		})
		if U.isLocal(character) then
			CameraShake.Add(0.1)
		end
	elseif phase == "Drill" then
		play(character, ANIMS.LanceDrill)
		local duration = (data.count or 3) * (data.gap or 0.1) + 0.1
		Look.hold(character, "Aim", duration + 0.6)
		Look.spin(character, duration + 0.4)
		local target: Model? = data.target
		local targetRoot = target and U.getRoot(target)
		if targetRoot then
			whirl(targetRoot.Position, root.CFrame.LookVector, 2.5, duration, 12)
			U.bodyTrail(target, WATER_LIGHT, duration)
		end
	elseif phase == "Twist" then
		local tip = lanceTip(character, root)
		local direction = root.CFrame.LookVector
		spray(tip, 12, 30, direction, 60)
		ripple(tip, direction, 0.4, 3 + (data.index or 1) * 0.6, 0.2, 0.7)
		U.flash(tip, FOAM, 2.5, 0.08)
		droplets(tip, 4, 14, direction, 0.3)
	elseif phase == "Thrust" then
		play(character, ANIMS.LanceFinish)
		Look.hold(character, "Aim", 0.6)
		endCharge(character, 0.15)
		local tip = lanceTip(character, root)
		local direction = root.CFrame.LookVector
		local dragon = data.dragon == true
		local surge = stream(if dragon then 3.2 else 2.4, 26)
		every(0.3, function(elapsed)
			local a = easeOut(elapsed / 0.12)
			surge.set(tip - direction, tip + direction * (if dragon then 16 else 11) * a)
			return true
		end, function()
			surge.fade(0.25)
		end)
		splash(tip + direction * 2, if dragon then 7 else 5, direction)
		droplets(tip, 14, 30, direction, 0.45)
		U.shockwave(tip, WATER_LIGHT, 2, if dragon then 14 else 10, 0.3, Enum.Material.ForceField)
		U.impactSpikes(tip, WATER, 10, if dragon then 9 else 7, 0.25, FOAM)
		shine(tip, direction, 0.5, if dragon then 9 else 6, 0.3)
		U.light(tip, WATER, 5, 22, 0.35)
		if U.isLocal(character) then
			CameraShake.Add(0.2)
			CameraShake.FovKick(7)
		end
	elseif phase == "Whiff" or phase == "Interrupted" or phase == "Cancel" then
		endCharge(character, 0.15)
		if phase == "Whiff" then
			spray(lanceTip(character, root), 10, 20, root.CFrame.LookVector, 40)
			mist(lanceTip(character, root), 1.5, root.CFrame.LookVector)
		end
	end
end

type Hurl = { done: boolean, serpent: Serpent.Serpent?, coil: Serpent.Serpent?, token: number }
local hurls: { [Model]: Hurl } = setmetatable({}, { __mode = "k" }) :: any

function handlers.LanceOfTheSeaDragon(data, character, root)
	local phase = data.phase
	if phase == "Draw" then
		play(character, ANIMS.Hurl)
		local delay: number = data.delay or 0.4
		local dragon = data.dragon == true
		Look.hold(character, "Aim", delay + 0.15, nil)
		local token = bump(character)
		local coil = Serpent.new(if dragon then 0.75 else 0.55, 7)
		local state: Hurl = { done = false, serpent = nil, coil = coil, token = token }
		hurls[character] = state
		every(delay + 0.1, function(elapsed)
			if not live(character, token) or hurls[character] ~= state or state.coil ~= coil then
				return false
			end
			local tip = lanceTip(character, root)
			local axis = root.CFrame.LookVector
			local side = axis:Cross(UP)
			side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
			local other = side:Cross(axis)
			local angle = elapsed * 14
			local radius = 1.6 * (1 - easeOut(elapsed / delay) * 0.7)
			local position = tip
				- axis * 3 * (1 - elapsed / delay)
				+ (side * math.cos(angle) + other * math.sin(angle)) * radius
			local tangent = (-side * math.sin(angle) + other * math.cos(angle)) + axis * 0.8
			coil.place(CFrame.lookAt(position, position + tangent), 0.3 + 0.5 * elapsed / delay)
			if math.random() < 0.5 then
				gather(tip, 3.5)
			end
			return true
		end)
		whirl(root.Position - UP * 2.8, UP, 5, delay + 0.1, 6)
		ripple(root.Position - UP * 2.8, UP, 6, 1, delay, 1)
	elseif phase == "Hurl" then
		local dragon = data.dragon == true
		Look.hideLance(character, 0.9)
		local state = hurls[character]
		if state and state.coil then
			state.coil.fade(0.1)
			state.coil = nil
		end
		local flight: Hurl = state or { done = false, serpent = nil, coil = nil, token = 0 }
		flight.done = false
		hurls[character] = flight
		local origin: Vector3 = data.origin
		local direction: Vector3 = data.direction
		local lance = Lance.new(dragon)
		lance.show(1)
		local serpent = Serpent.new(if dragon then 1.1 else 0.8, if dragon then 9 else 7)
		flight.serpent = serpent
		local wake = Soft.trail(lance.blade, Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0), {
			color = ColorSequence.new(FOAM, WATER),
			transparency = NumberSequence.new({ key(0, 0.25), key(1, 1) }),
			width = NumberSequence.new({ key(0, 1), key(1, 0.2) }),
			lifetime = 0.3,
		})
		every(data.range / data.speed + 0.3, function(elapsed)
			if flight.done then
				return false
			end
			local position = origin + direction * data.speed * elapsed
			local frame = CFrame.lookAt(position, position + direction)
			lance.place(frame, elapsed * 30)
			serpent.place(frame * CFrame.new(0, 0, -lance.length * 0.55), 0.7 + 0.3 * math.sin(elapsed * 16))
			local ground = Fx.floorAt(position, 10)
			if ground and math.random() < 0.3 then
				ripple(ground.Position + UP * 0.1, UP, 1, 4, 0.35, 0.8)
			end
			return true
		end, function()
			flight.done = true
			Soft.endTrail(wake)
			lance.fade(0.2)
			serpent.fade(0.25)
		end)
		local hand = handOf(character, "Right") or origin
		spray(hand, 16, 34, direction, 25)
		shine(origin, direction, 0.5, 6, 0.25)
		ripple(origin, direction, 1, 7, 0.3, 1.2)
		U.flash(origin, FOAM, 4, 0.12)
		task.delay(0.9, function()
			local back = handOf(character, "Right")
			if back and character.Parent then
				spray(back, 10, 14, UP, 60)
				shine(back, UP, 0.3, 2.5, 0.2)
			end
		end)
		if U.isLocal(character) then
			CameraShake.Add(0.12)
			CameraShake.FovKick(6)
		end
	elseif phase == "Crash" then
		local flight = hurls[character]
		if flight then
			flight.done = true
		end
		local position: Vector3 = data.position
		local direction: Vector3 = data.direction
		local big = data.dragon == true
		splash(position, if big then 9 else 7, -direction)
		droplets(position, 20, 32, UP, 0.55)
		U.shockwave(position, WATER_LIGHT, 3, if big then 18 else 14, 0.4, Enum.Material.ForceField)
		U.impactSpikes(position, WATER, 12, if big then 10 else 8, 0.28, FOAM)
		mist(position, 4)
		if Fx.floorAt(position, 6) then
			crater(position, if big then 8 else 6)
			geyser(position - UP * 1, if big then 16 else 11, if big then 2.2 else 1.6, 0.8)
		end
		U.light(position, WATER, 6, 28, 0.45)
		if near(position, 60) then
			CameraShake.Add(0.22)
		end
	elseif phase == "Cancel" then
		bump(character)
		local state = hurls[character]
		hurls[character] = nil
		if state and state.coil then
			state.coil.fade(0.15)
		end
	end
end

type Tail = { pieces: { { part: BasePart, offset: CFrame } }, stop: (number) -> () }

local function mermaidTail(character: Model): Tail?
	local torso = character:FindFirstChild("Torso") :: BasePart?
	if not torso then
		return nil
	end
	local pieces: { { part: BasePart, offset: CFrame } } = {}
	local function add(part: BasePart, offset: CFrame)
		table.insert(pieces, { part = part, offset = offset })
	end
	add(ellipsoid(Vector3.new(2.1, 2.6, 1.3), WATER, Enum.Material.Glass, 0.3), CFrame.new(0, -2, 0))
	add(ellipsoid(Vector3.new(2.2, 2.7, 1.4), WATER_LIGHT, Enum.Material.ForceField, 0), CFrame.new(0, -2, 0))
	add(ellipsoid(Vector3.new(1.3, 1.7, 0.9), WATER, Enum.Material.Glass, 0.3), CFrame.new(0, -3.5, 0.15))
	add(ellipsoid(Vector3.new(0.7, 0.9, 0.5), WATER_LIGHT, Enum.Material.Glass, 0.25), CFrame.new(0, -4.3, 0.25))
	for side = -1, 1, 2 do
		add(
			ellipsoid(Vector3.new(0.12, 1.6, 1.1), FOAM, Enum.Material.ForceField, 0),
			CFrame.new(side * 0.6, -4.8, 0.35) * CFrame.Angles(0, 0, rad(side * 50))
		)
		add(
			ellipsoid(Vector3.new(0.1, 1.4, 0.9), WATER_LIGHT, Enum.Material.Glass, 0.3),
			CFrame.new(side * 0.55, -4.75, 0.3) * CFrame.Angles(0, 0, rad(side * 50))
		)
	end
	for i = 0, 3 do
		add(
			ellipsoid(Vector3.new(1.6 - i * 0.25, 0.3, 0.25), FOAM, Enum.Material.Neon, 0.55),
			CFrame.new(0, -1.4 - i * 0.7, -0.6 + i * 0.1)
		)
	end
	local start = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		if not torso.Parent then
			return
		end
		local sway = CFrame.Angles(math.sin((os.clock() - start) * 14) * 0.12, 0, 0)
		for i, piece in pieces do
			piece.part.CFrame = torso.CFrame * (if i > 2 then sway else CFrame.identity) * piece.offset
		end
	end)
	local tail = { pieces = pieces }
	function tail.stop(duration: number)
		connection:Disconnect()
		local parts = {}
		for _, piece in pieces do
			table.insert(parts, piece.part)
		end
		Soft.fadeOut(parts, duration)
	end
	return tail
end

function handlers.MermaidDive(data, character, root)
	local phase = data.phase
	if phase == "Begin" then
		play(character, ANIMS.Mermaid)
		local plan = DivePlan.Plan(data.start, data.target, data.floorFrom, data.floorTo)
		local erupt = DivePlan.Erupt(plan)
		local entry = DivePlan.Entry(plan)
		local tail = mermaidTail(character)
		local hideFrom, hideUntil = DivePlan.Sink * 0.75, erupt + 0.04
		Look.hide(character, hideUntil + 0.05)
		local started = os.clock()
		local hidden = false
		local bind = "CloverMermaidDive" .. tostring(started)
		local splashed, surfaced = false, false
		local nextWake = 0
		local fin = ellipsoid(Vector3.new(0.12, 1.5, 1.6), FOAM, Enum.Material.Glass, 1)
		local finSkin = ellipsoid(Vector3.new(0.16, 1.6, 1.7), WATER_LIGHT, Enum.Material.ForceField, 1)
		local function finish()
			pcall(function()
				RunService:UnbindFromRenderStep(bind)
			end)
			if hidden then
				Fx.hideBody(character, false)
				hidden = false
			end
			fin:Destroy()
			finSkin:Destroy()
			if tail then
				tail.stop(0.3)
			end
		end
		RunService:BindToRenderStep(bind, Enum.RenderPriority.Camera.Value - 1, function()
			local t = os.clock() - started
			if t > plan.length + 0.05 or not root.Parent then
				finish()
				return
			end
			root.CFrame = DivePlan.At(plan, t)
			local hide = t >= hideFrom and t < hideUntil
			if hide ~= hidden or hide then
				hidden = hide
				Fx.hideBody(character, hide)
			end
			if not splashed and t >= DivePlan.Sink * 0.6 then
				splashed = true
				splash(entry, 5)
				crown(entry, 2, 3.5, 0.6, 14)
				puddle(entry, 3.5, plan.swim + 0.8)
			end
			local swimming = t >= DivePlan.Sink and t < erupt
			if swimming then
				local position = root.Position
				local ground = Vector3.new(
					position.X,
					plan.from.Y + (plan.to.Y - plan.from.Y) * ((t - DivePlan.Sink) / plan.swim),
					position.Z
				)
				local finFrame = CFrame.lookAt(ground, ground + plan.forward)
					* CFrame.new(0, 0.6, 0)
					* CFrame.Angles(rad(-20), 0, 0)
				fin.CFrame = finFrame
				finSkin.CFrame = finFrame
				fin.Transparency = 0.2
				finSkin.Transparency = 0
				if t > nextWake then
					nextWake = t + 0.05
					ripple(ground + UP * 0.08, UP, 0.5, 3.2, 0.5, 0.7)
					spray(ground, 4, 18, UP - plan.forward * 0.5, 30)
				end
			else
				fin.Transparency = 1
				finSkin.Transparency = 1
			end
			if not surfaced and t >= erupt then
				surfaced = true
				U.afterimage(character, WATER_LIGHT, 0.3)
			end
		end)
		task.delay(plan.length + 0.3, finish)
		spray(root.Position, 10, 18, UP, 40)
		mist(root.Position, 2, UP)
		if U.isLocal(character) then
			CameraShake.FovKick(6)
		end
	elseif phase == "Erupt" then
		local position: Vector3 = data.position
		geyser(position, 16, 3, 1.1)
		splash(position + UP, 8)
		crown(position, 4, 6, 0.8, 18)
		droplets(position + UP * 4, 22, 30, UP, 0.6)
		U.shockwave(position + UP, WATER_LIGHT, 2, 16, 0.4, Enum.Material.ForceField)
		ripple(position + UP * 0.1, UP, 1, 16, 0.5, 1.6)
		shine(position + UP * 0.1, UP, 1, 12, 0.4)
		mist(position + UP * 2, 5, UP)
		puddle(position, 6, 1.8)
		U.light(position, WATER, 6, 30, 0.6)
		if U.isLocal(character) then
			CameraShake.Add(0.3)
			CameraShake.FovKick(10)
		elseif near(position, 55) then
			CameraShake.Add(0.2)
		end
	end
end

return {}
