local RunService = game:GetService("RunService")

local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local VFX = require(script.Parent.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Parent.Soft)

local U = VFX.Util
local rad = math.rad
local UP = Vector3.yAxis

local Fx = require(script.Parent.Fx)
local Lance = require(script.Parent.Lance)
local Serpent = require(script.Parent.Serpent)

local ANIMS, handlers, play, easeOut = Fx.ANIMS, Fx.handlers, Fx.play, Fx.easeOut
local WATER, WATER_DEEP, WATER_LIGHT, FOAM, SILVER, SAINT =
	Fx.WATER, Fx.WATER_DEEP, Fx.WATER_LIGHT, Fx.FOAM, Fx.SILVER, Fx.SAINT
local ripple, shine, spray, mist, droplets, splash = Fx.ripple, Fx.shine, Fx.spray, Fx.mist, Fx.droplets, Fx.splash
local crown, puddle, bubbles, water, geyser, orb, stream, whirl =
	Fx.crown, Fx.puddle, Fx.bubbles, Fx.water, Fx.geyser, Fx.orb, Fx.stream, Fx.whirl
local every, fadeOut, key = Soft.every, Soft.fadeOut, Soft.key
local SMOKE, SPARKLE = Soft.SMOKE, Soft.SPARKLE

local GLASS = Enum.Material.Glass
local SHIMMER = Enum.Material.ForceField
local NEON = Enum.Material.Neon

type State = {
	mode: string,
	modeUntil: number,
	direction: Vector3?,
	spinUntil: number,
	hiddenUntil: number,
	lanceHiddenUntil: number,
	lanceFrame: CFrame?,
	lance: Lance.Lance?,
}

local looks: { [Model]: State } = {}

local Look = {}

function Look.hold(character: Model, mode: string, duration: number, direction: Vector3?)
	local state = looks[character]
	if state then
		state.mode = mode
		state.modeUntil = os.clock() + duration
		state.direction = direction
	end
end

function Look.spin(character: Model, duration: number)
	local state = looks[character]
	if state then
		state.spinUntil = os.clock() + duration
	end
end

function Look.hide(character: Model, duration: number)
	local state = looks[character]
	if state then
		state.hiddenUntil = os.clock() + duration
	end
end

function Look.hideLance(character: Model, duration: number)
	local state = looks[character]
	if state then
		state.lanceHiddenUntil = os.clock() + duration
	end
end

function Look.lanceTip(character: Model): Vector3?
	local state = looks[character]
	local lance = state and state.lance
	if state and lance and state.lanceFrame then
		return lance.tip(state.lanceFrame)
	end
	return nil
end

local function ellipsoid(size: Vector3, color: Color3, material: Enum.Material): BasePart
	local part = U.newPart({ Size = Vector3.one, Color = color, Material = material, Transparency = 1 })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = part
	return part
end

local function wedge(color: Color3, material: Enum.Material): WedgePart
	local part = Instance.new("WedgePart")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = color
	part.Material = material
	part.Transparency = 1
	part.Size = Vector3.one * 0.1
	part.Parent = U.folder
	return part
end

local function triangle(w1: BasePart, w2: BasePart, a: Vector3, b: Vector3, c: Vector3, thickness: number)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-4 or bc.Magnitude < 1e-4 then
		return
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.max(math.abs(ab:Dot(up)), 0.05)
	w1.Size = Vector3.new(thickness, height, math.max(math.abs(ab:Dot(back)), 0.05))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	w2.Size = Vector3.new(thickness, height, math.max(math.abs(ac:Dot(back)), 0.05))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
end

type Piece = { part: BasePart, limb: BasePart, offset: CFrame }
type Bone = { part: BasePart, length: number, elevation: number, sweep: number }
type Wing = { side: number, bones: { Bone }, panels: { { BasePart } } }

local function buildLook(character: Model, dragon: boolean): () -> ()
	local torso = character:FindFirstChild("Torso") :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	local root = U.getRoot(character)
	if not torso or not head or not root then
		return function() end
	end
	local state: State = {
		mode = "Carry",
		modeUntil = 0,
		direction = nil,
		spinUntil = 0,
		hiddenUntil = 0,
		lanceHiddenUntil = 0,
		lanceFrame = nil,
		lance = nil,
	}
	looks[character] = state
	local bases: { [BasePart]: number } = {}
	local pieces: { Piece } = {}
	local loose: { BasePart } = {}
	local function on(limb: BasePart?, part: BasePart, offset: CFrame, base: number): BasePart
		bases[part] = base
		if limb then
			table.insert(pieces, { part = part, limb = limb, offset = offset })
		else
			table.insert(loose, part)
		end
		return part
	end
	local function block(size: Vector3, color: Color3, material: Enum.Material): BasePart
		return U.newPart({ Size = size, Color = color, Material = material, Transparency = 1 })
	end

	on(torso, ellipsoid(Vector3.new(2.15, 1.25, 1.2), WATER, GLASS), CFrame.new(0, 0.42, -0.22), 0.35)
	on(torso, ellipsoid(Vector3.new(2.22, 1.32, 1.26), WATER_LIGHT, SHIMMER), CFrame.new(0, 0.42, -0.22), 0)
	on(
		torso,
		U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.34, Color = FOAM, Transparency = 1 }),
		CFrame.new(0, 0.5, -0.82),
		0.05
	)
	for side = -1, 1, 2 do
		on(
			torso,
			block(Vector3.new(0.95, 0.08, 0.1), FOAM, NEON),
			CFrame.new(side * 0.52, 0.93, -0.56) * CFrame.Angles(0, 0, rad(side * -14)),
			0.25
		)
		on(
			torso,
			block(Vector3.new(0.08, 0.9, 0.1), FOAM, NEON),
			CFrame.new(side * 0.18, 0.3, -0.83) * CFrame.Angles(0, 0, rad(side * 18)),
			0.35
		)
	end
	on(torso, block(Vector3.new(2.08, 0.2, 1.08), SILVER, GLASS), CFrame.new(0, -0.78, 0), 0.2)
	on(torso, block(Vector3.new(2.12, 0.07, 1.12), FOAM, NEON), CFrame.new(0, -0.7, 0), 0.3)
	local faulds = {
		{ x = -0.52, z = -0.62, yaw = 0 },
		{ x = 0.52, z = -0.62, yaw = 0 },
		{ x = -1.1, z = 0, yaw = 90 },
		{ x = 1.1, z = 0, yaw = -90 },
		{ x = -0.52, z = 0.62, yaw = 180 },
		{ x = 0.52, z = 0.62, yaw = 180 },
	}
	for _, f in faulds do
		local frame = CFrame.new(f.x, -1.25, f.z) * CFrame.Angles(0, rad(f.yaw), 0) * CFrame.Angles(rad(14), 0, 0)
		on(torso, ellipsoid(Vector3.new(0.95, 1.35, 0.14), WATER, GLASS), frame, 0.35)
		on(torso, ellipsoid(Vector3.new(1, 1.4, 0.2), WATER_LIGHT, SHIMMER), frame, 0)
		on(torso, block(Vector3.new(0.85, 0.06, 0.06), FOAM, NEON), frame * CFrame.new(0, -0.62, -0.04), 0.3)
	end

	for _, side in { -1, 1 } do
		local arm = character:FindFirstChild(if side < 0 then "Left Arm" else "Right Arm") :: BasePart?
		local leg = character:FindFirstChild(if side < 0 then "Left Leg" else "Right Leg") :: BasePart?
		if arm then
			local out = CFrame.Angles(0, 0, rad(side * -12))
			on(arm, ellipsoid(Vector3.new(1.5, 0.82, 1.4), WATER, GLASS), CFrame.new(side * 0.12, 0.85, 0) * out, 0.3)
			on(
				arm,
				ellipsoid(Vector3.new(1.56, 0.88, 1.46), WATER_LIGHT, SHIMMER),
				CFrame.new(side * 0.12, 0.85, 0) * out,
				0
			)
			on(arm, ellipsoid(Vector3.new(1.55, 0.12, 1.45), FOAM, NEON), CFrame.new(side * 0.12, 0.6, 0) * out, 0.35)
			on(arm, block(Vector3.new(1.12, 0.95, 1.12), WATER_LIGHT, GLASS), CFrame.new(0, -0.5, 0), 0.4)
			on(arm, block(Vector3.new(1.16, 0.1, 1.16), FOAM, NEON), CFrame.new(0, -0.97, 0), 0.25)
			on(
				arm,
				ellipsoid(Vector3.new(0.1, 0.9, 0.7), WATER_LIGHT, SHIMMER),
				CFrame.new(side * 0.6, -0.4, 0.2) * CFrame.Angles(rad(-20), 0, 0),
				0
			)
			if dragon then
				for i = 0, 2 do
					on(
						arm,
						ellipsoid(Vector3.new(0.75, 0.45, 0.2), WATER_DEEP, GLASS),
						CFrame.new(0, -0.2 - i * 0.3, -0.58) * CFrame.Angles(rad(-15), 0, 0),
						0.25
					)
				end
				on(
					arm,
					ellipsoid(Vector3.new(0.1, 1.3, 1.1), FOAM, SHIMMER),
					CFrame.new(side * 0.62, -0.45, 0.35) * CFrame.Angles(rad(-35), 0, 0),
					0
				)
			end
		end
		if leg then
			on(leg, block(Vector3.new(1.1, 1.1, 1.1), WATER, GLASS), CFrame.new(0, -0.45, 0), 0.4)
			on(leg, ellipsoid(Vector3.new(0.85, 0.6, 0.5), WATER_LIGHT, GLASS), CFrame.new(0, 0.08, -0.55), 0.3)
			on(leg, block(Vector3.new(1.14, 0.08, 1.14), FOAM, NEON), CFrame.new(0, -0.95, 0), 0.3)
			on(leg, ellipsoid(Vector3.new(1, 0.45, 1.35), WATER_LIGHT, GLASS), CFrame.new(0, -0.85, -0.22), 0.35)
			if dragon then
				on(
					leg,
					ellipsoid(Vector3.new(0.1, 1.1, 1.2), FOAM, SHIMMER),
					CFrame.new(side * 0.6, -0.5, 0.35) * CFrame.Angles(rad(-30), 0, 0),
					0
				)
			end
		end
	end

	local crest = CFrame.new(0, 0.55, -0.56)
	on(head, ellipsoid(Vector3.new(0.14, 0.75, 0.35), FOAM, GLASS), crest * CFrame.new(0, 0.12, 0), 0.15)
	on(
		head,
		U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.26, Color = WATER_LIGHT, Transparency = 1 }),
		crest * CFrame.new(0, -0.2, -0.05),
		0.05
	)
	for side = -1, 1, 2 do
		on(
			head,
			ellipsoid(Vector3.new(0.1, 0.55, 0.8), FOAM, SHIMMER),
			CFrame.new(side * 0.5, 0.45, -0.3) * CFrame.Angles(rad(25), 0, rad(side * -35)),
			0
		)
		on(
			head,
			ellipsoid(Vector3.new(0.1, 0.38, 0.6), WATER_LIGHT, GLASS),
			CFrame.new(side * 0.42, 0.42, -0.4) * CFrame.Angles(rad(25), 0, rad(side * -30)),
			0.25
		)
	end
	for i = 1, 9 do
		local a = -((i - 0.5) / 9) * math.pi
		local spot = Vector3.new(math.cos(a) * 0.64, 0.3, math.sin(a) * 0.62)
		local along = Vector3.new(-math.sin(a), 0, math.cos(a))
		on(head, block(Vector3.new(0.08, 0.12, 0.28), SILVER, NEON), CFrame.lookAt(spot, spot + along), 0.25)
	end
	if dragon then
		for side = -1, 1, 2 do
			on(
				head,
				ellipsoid(Vector3.new(0.32, 0.32, 1.4), FOAM, GLASS),
				CFrame.lookAt(Vector3.new(side * 0.45, 0.62, 0.05), Vector3.new(side * 0.75, 1.2, 1.1))
					* CFrame.new(0, 0, -0.55),
				0.15
			)
			on(
				head,
				ellipsoid(Vector3.new(0.2, 0.2, 1.1), WATER_LIGHT, NEON),
				CFrame.lookAt(Vector3.new(side * 0.68, 1.05, 0.85), Vector3.new(side * 0.8, 1.15, 1.9))
					* CFrame.new(0, 0, -0.4),
				0.4
			)
			on(
				head,
				ellipsoid(Vector3.new(0.08, 0.9, 1.1), WATER_LIGHT, SHIMMER),
				CFrame.new(side * 0.64, 0.1, 0.2) * CFrame.Angles(rad(-30), rad(side * -20), 0),
				0
			)
		end
	end

	local emitters: { ParticleEmitter } = {}
	for _, name in { "Left Arm", "Right Arm" } do
		local arm = character:FindFirstChild(name)
		if arm then
			local drip = water(arm, {
				Size = NumberSequence.new({ key(0, 0.4), key(1, 0) }),
				Transparency = NumberSequence.new({ key(0, 0.5), key(1, 1) }),
				Lifetime = NumberRange.new(0.4, 0.7),
				Speed = NumberRange.new(0.5, 1.5),
				Acceleration = Vector3.new(0, -6, 0),
				Rate = 10,
			})
			table.insert(emitters, drip)
		end
	end
	table.insert(emitters, bubbles(torso, if dragon then 10 else 5, 0.25))

	local lance = Lance.new(dragon)
	state.lance = lance

	local jet = stream(0.9, 14)
	local wake: { Trail } = {}
	for side = -1, 1, 2 do
		table.insert(
			wake,
			Soft.trail(torso, Vector3.new(side * 0.7, -1, 0.4), Vector3.new(side * 0.2, -1.2, 0.6), {
				color = ColorSequence.new(FOAM, WATER),
				transparency = NumberSequence.new({ key(0, 0.5), key(1, 1) }),
				width = NumberSequence.new({ key(0, 1), key(1, 0.2) }),
				lifetime = 0.4,
				texture = SMOKE,
				off = true,
			})
		)
	end

	local wings: { Wing } = {}
	local tail: { BasePart } = {}
	local halo: Soft.Ring? = nil
	if dragon then
		for _, side in { -1, 1 } do
			local wing: Wing = { side = side, bones = {}, panels = {} }
			for i, spec in { { 3.4, 50, 95 }, { 4.2, 20, 110 }, { 3.2, -12, 125 } } do
				local bone = on(
					nil,
					U.newPart({
						Size = Vector3.new(0.2, 0.2, spec[1]),
						Color = FOAM,
						Material = GLASS,
						Transparency = 1,
					}),
					CFrame.identity,
					0.15
				)
				table.insert(wing.bones, { part = bone, length = spec[1], elevation = spec[2], sweep = spec[3] })
				if i < 3 then
					local panel = {}
					for _ = 1, 2 do
						table.insert(panel, on(nil, wedge(WATER_LIGHT, SHIMMER), CFrame.identity, 0))
						table.insert(panel, on(nil, wedge(WATER, GLASS), CFrame.identity, 0.55))
					end
					table.insert(wing.panels, panel)
				end
			end
			table.insert(wings, wing)
		end
		for i = 1, 7 do
			local radius = 0.55 - i * 0.055
			table.insert(
				tail,
				on(nil, ellipsoid(Vector3.new(radius * 2, radius * 2, 1.2), WATER, GLASS), CFrame.identity, 0.3)
			)
		end
		halo = Soft.softRing({
			color = ColorSequence.new(SAINT, FOAM),
			width0 = 0.2,
			width1 = 0.2,
			transparency = NumberSequence.new(0.25),
			texture = SPARKLE,
			wrap = true,
			length = 0.6,
			speed = 1.5,
		})
	end

	local start = os.clock()
	local last = start
	local faded = false
	local shown = 0
	local lanceShown = 0
	local glide, gliding = 0, 0
	local aim = 0
	local spin = 0
	local nextRipple = 0
	local nextGround = 0
	local ground: RaycastResult? = nil
	local connection: RBXScriptConnection
	local function destroy()
		connection:Disconnect()
		if looks[character] == state then
			looks[character] = nil
		end
		jet.fade(0.3)
		for _, trail in wake do
			Soft.endTrail(trail)
		end
		if halo then
			halo.fade(0.3)
		end
		for _, emitter in emitters do
			emitter.Enabled = false
			task.delay(1, emitter.Destroy, emitter)
		end
		lance.fade(0.4)
		local parts = {}
		for part in bases do
			table.insert(parts, part)
		end
		fadeOut(parts, 0.4)
	end
	connection = RunService.RenderStepped:Connect(function()
		if not torso.Parent or not head.Parent or not root.Parent then
			destroy()
			return
		end
		local now = os.clock()
		local t = now - start
		local dt = math.min(now - last, 0.1)
		last = now
		local hidden = now < state.hiddenUntil
		local want = if hidden then 0 else 1
		if want ~= shown then
			shown = if want < shown then 0 else math.min(shown + dt * 2.5, 1)
			for part, base in bases do
				part.Transparency = 1 - (1 - base) * shown
			end
			for _, emitter in emitters do
				emitter.Enabled = shown >= 1
			end
		end
		if not faded and shown >= 1 then
			faded = true
		end

		for _, piece in pieces do
			piece.part.CFrame = piece.limb.CFrame * piece.offset
		end

		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		gliding += ((math.clamp((speed - 6) / 14, 0, 1) - glide) * 16 - gliding * 8) * dt
		glide += gliding * dt
		if glide <= 0 or glide >= 1 then
			glide = math.clamp(glide, 0, 1)
			gliding = 0
		end

		local feet = root.Position - UP * 1.2
		if now >= nextGround then
			nextGround = now + 0.1
			ground = Fx.floorAt(root.Position, 9)
		end
		if ground and not hidden then
			local spot = Vector3.new(root.Position.X, ground.Position.Y, root.Position.Z)
			jet.set(feet, spot - root.CFrame.LookVector * glide * 1.5)
			if now > nextRipple then
				nextRipple = now + (if glide > 0.3 then 0.12 else 0.45)
				ripple(spot + UP * 0.08, UP, 0.6, 2.6 + glide * 2, 0.45, 0.6)
			end
		else
			jet.set(feet, feet)
		end
		for _, trail in wake do
			trail.Enabled = glide > 0.35 and not hidden
		end

		local arm = character:FindFirstChild("Right Arm") :: BasePart?
		if arm then
			local hand = (arm.CFrame * CFrame.new(0, -1.05, 0)).Position
			local mode = if now < state.modeUntil then state.mode else "Carry"
			local aiming = mode == "Aim"
			aim += ((if aiming then 1 else 0) - aim) * math.min(dt * 16, 1)
			local carry = arm.CFrame * CFrame.new(0, -1.05, -0.62) * CFrame.Angles(rad(90), 0, 0)
			local look = root.CFrame.LookVector
			local direction = state.direction or Vector3.new(look.X, look.Y - 0.1 * glide, look.Z)
			local couch = CFrame.lookAt(hand, hand + (if direction.Magnitude > 1e-3 then direction else look))
			local resting = carry:Lerp(couch, if aiming then 0 else glide * 0.85)
			local frame = resting:Lerp(couch, aim)
			if now < state.spinUntil then
				spin += dt * 32
			end
			state.lanceFrame = frame
			lance.place(frame, spin + t * 1.5)
			local lanceWant = if hidden or now < state.lanceHiddenUntil then 0 else shown
			if lanceWant ~= lanceShown then
				lanceShown += math.clamp(lanceWant - lanceShown, -dt * 8, dt * 5)
				if math.abs(lanceWant - lanceShown) < 0.02 then
					lanceShown = lanceWant
				end
				lance.show(lanceShown)
			end
		end

		if dragon then
			local back = torso.CFrame * CFrame.new(0, 0.55, 0.55)
			local beat = math.sin(t * (2.4 + glide * 2.6)) * (0.22 - glide * 0.08)
			for _, wing in wings do
				local side = wing.side
				local tips: { Vector3 } = {}
				local origin = (back * CFrame.new(side * 0.45, 0, 0)).Position
				for _, bone in wing.bones do
					local frame = back
						* CFrame.new(side * 0.45, 0, 0)
						* CFrame.Angles(0, -side * rad(bone.sweep + 30 * glide), 0)
						* CFrame.Angles(rad(bone.elevation - 10 * glide) + beat, 0, 0)
					local tip = (frame * CFrame.new(0, 0, -bone.length)).Position
					bone.part.CFrame = CFrame.lookAt(origin:Lerp(tip, 0.5), tip)
					table.insert(tips, tip)
				end
				for i, panel in wing.panels do
					local a, b = tips[i], tips[i + 1]
					if a and b then
						triangle(panel[1], panel[3], origin, a, b, 0.06)
						triangle(panel[2], panel[4], origin, a, b, 0.12)
					end
				end
			end
			local link = torso.CFrame * CFrame.new(0, -0.9, 0.55)
			local position = link.Position
			local heading = (link.LookVector * -1 - UP * 0.6).Unit
			for i, segment in tail do
				local sway = math.sin(t * 2.2 - i * 0.45) * 0.35
				heading = CFrame.fromAxisAngle(UP, sway * 0.25):VectorToWorldSpace(heading)
				local step = 0.55
				position += heading * step
				segment.CFrame = CFrame.lookAt(position, position + heading)
			end
			if halo then
				local crownFrame = head.CFrame * CFrame.new(0, 1.05, 0.35) * CFrame.Angles(rad(-18), t * 0.8, 0)
				halo.set(crownFrame, 0.62 * shown + 0.01)
			end
		end
	end)

	return function()
		if connection.Connected then
			destroy()
		end
	end
end

Look.build = buildLook

type Book = { place: (CFrame, number) -> (), fade: (number) -> () }

local function makeBook(): Book
	local pages: { { part: BasePart, offset: CFrame, side: number } } = {}
	local function page(props: { [string]: any }, offset: CFrame, side: number)
		table.insert(pages, { part = U.newPart(props), offset = offset, side = side })
	end
	local cover = Color3.fromRGB(34, 56, 118)
	local paper = Color3.fromRGB(230, 236, 246)
	for side = -1, 1, 2 do
		page(
			{ Size = Vector3.new(1.1, 1.45, 0.08), Color = cover, Material = Enum.Material.Fabric },
			CFrame.new(side * 0.55, 0, 0),
			side
		)
		page(
			{ Size = Vector3.new(1, 1.35, 0.12), Color = paper, Material = Enum.Material.SmoothPlastic },
			CFrame.new(side * 0.5, 0, -0.08),
			side
		)
	end
	page(
		{ Size = Vector3.new(0.14, 1.45, 0.14), Color = cover, Material = Enum.Material.Fabric },
		CFrame.new(0, 0, 0.02),
		0
	)
	for i = 1, 3 do
		local angle = (i - 1) * math.pi * 2 / 3 + math.pi / 2
		page(
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.32, Color = SILVER },
			CFrame.new(math.cos(angle) * 0.17, 1.05 + math.sin(angle) * 0.17, -0.4),
			0
		)
	end
	page({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.14, Color = WATER_LIGHT }, CFrame.new(0, 1.05, -0.4), 0)
	local light = Instance.new("PointLight")
	light.Color = WATER
	light.Range = 8
	light.Brightness = 2
	light.Parent = pages[#pages].part
	local book = {}
	function book.place(frame: CFrame, open: number)
		for _, p in pages do
			p.part.CFrame = frame * CFrame.Angles(0, -p.side * rad(open), 0) * p.offset
		end
	end
	function book.fade(duration: number)
		light.Enabled = false
		local parts = {}
		for _, p in pages do
			table.insert(parts, p.part)
		end
		fadeOut(parts, duration)
	end
	return book
end

function handlers.Entrance(data, character, root)
	if data.phase ~= "Start" then
		return
	end
	play(character, ANIMS.Entrance)
	local book = makeBook()
	local feet = root.Position - UP * 2.85
	puddle(feet, 5, 2)
	whirl(feet + UP * 0.1, UP, 5, 1.3, 5)
	every(2.2, function(elapsed)
		if not root.Parent then
			return false
		end
		local forward = root.CFrame.LookVector
		local right = root.CFrame.RightVector
		local position, open
		if elapsed < 0.6 then
			local eased = 1 - (1 - elapsed / 0.6) ^ 2
			position = root.Position + forward * 2.5 + UP * (1.5 + 16 * (1 - eased)) - right * 5 * (1 - eased)
			open = 0
		elseif elapsed < 1.3 then
			local a = (elapsed - 0.6) / 0.7
			local angle = a * math.pi * 2
			position = root.Position + (forward * math.cos(angle) + right * math.sin(angle)) * 2.6 + UP * 1.5
			open = 75 * a
		else
			position = root.Position + forward * 2.2 + UP * (1.8 + math.min((elapsed - 1.3) * 2, 0.6))
			open = 75
		end
		book.place(CFrame.lookAt(position, root.Position + UP * 1.5) * CFrame.Angles(rad(-15), 0, 0), open)
		if elapsed < 1.3 and math.random() < 0.5 then
			local spot = root.Position + Vector3.new((math.random() - 0.5) * 6, -2.5, (math.random() - 0.5) * 6)
			spray(spot, 3, 14, UP, 25)
		end
		return true
	end, function()
		book.fade(0.3)
	end)
	Soft.helix(function()
		return root.Position - UP * 3, root.Position + UP * 3.5
	end, 3, 3, 0.5, 2, 0.7, 1.3, WATER)
	task.delay(1.35, function()
		if not root.Parent then
			return
		end
		local position = root.Position
		local base = position - UP * 2.85
		crown(base, 3, 5, 0.7, 16)
		splash(position + root.CFrame.LookVector * 2, 5)
		droplets(position + UP, 16, 26, UP, 0.45)
		ripple(base + UP * 0.1, UP, 1, 14, 0.5, 1.4)
		shine(base + UP * 0.1, UP, 1, 11, 0.4)
		mist(position, 4, UP)
		U.flash(position + root.CFrame.LookVector * 2.2 + UP * 2, FOAM, 6, 0.25)
		U.light(position, WATER, 5, 26, 0.5)
		if U.isLocal(character) then
			CameraShake.Add(0.15)
		end
	end)
end

local function transformation(data, character: Model, root: BasePart, dragon: boolean)
	if data.phase == "Start" then
		play(character, if dragon then ANIMS.Ascend else ANIMS.Awaken)
		local feet = root.Position - UP * 2.85
		local sphere = orb(3.6, 0.85, 0.55)
		every(0.8, function(elapsed)
			if not root.Parent then
				return false
			end
			local grow = easeOut(elapsed / 0.45)
			sphere.place(CFrame.new(root.Position + UP * 0.4) * CFrame.Angles(0, elapsed * 4, 0), 0.2 + 0.8 * grow)
			return true
		end, function()
			sphere.fade(0.1)
		end)
		whirl(feet + UP * 0.1, UP, 8, 0.9, 6)
		crown(feet, 4, 4, 0.8, 16)
		ripple(feet + UP * 0.1, UP, 9, 2, 0.8, 1.6)
		Soft.helix(function()
			return root.Position - UP * 3, root.Position + UP * 4.5
		end, 3.8, if dragon then 4 else 3, 0.4, 2.2, 0.9, 0.8, WATER)
		local well = U.newPart({ Size = Vector3.one * 16, Transparency = 1, CFrame = CFrame.new(root.Position) })
		local drawn = water(well, {
			Size = NumberSequence.new({ key(0, 3), key(1, 1) }),
			Lifetime = NumberRange.new(0.5, 0.6),
			Speed = NumberRange.new(14, 16),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			Rate = 40,
		})
		task.delay(0.8, function()
			drawn.Enabled = false
			task.delay(0.7, well.Destroy, well)
		end)
		if dragon then
			local serpent = Serpent.new(1.3, 11)
			every(0.85, function(elapsed)
				if not root.Parent then
					return false
				end
				local a = elapsed / 0.85
				local angle = a * math.pi * 3.2
				local radius = 7 * (1 - a) + 1
				local position = root.Position
					+ Vector3.new(math.cos(angle) * radius, -1 + a * 6, math.sin(angle) * radius)
				local tangent = Vector3.new(-math.sin(angle), 0.35, math.cos(angle))
				serpent.place(CFrame.lookAt(position, position + tangent), 0.4 + 0.5 * a)
				return true
			end, function()
				serpent.fade(0.15)
			end)
			local undine = orb(0.7, 0.3, 0.2)
			every(0.8, function(elapsed)
				if not root.Parent then
					return false
				end
				local angle = -elapsed * 7
				local radius = 4 * (1 - elapsed / 0.8) + 0.4
				undine.place(
					CFrame.new(
						root.Position + Vector3.new(math.cos(angle) * radius, 3 - elapsed * 2, math.sin(angle) * radius)
					)
				)
				return true
			end, function()
				undine.fade(0.1)
			end)
		end
	elseif data.phase == "Burst" then
		local position = root.Position
		local base = position - UP * 2.85
		splash(position, 9)
		geyser(base, if dragon then 34 else 24, if dragon then 3.4 else 2.6, 1)
		crown(base, 5, 7, 0.9, 20)
		droplets(position + UP * 2, 28, 34, UP, 0.6)
		U.shockwave(position, WATER_LIGHT, 3, if dragon then 40 else 28, 0.6, Enum.Material.ForceField)
		ripple(base + UP * 0.1, UP, 2, if dragon then 30 else 22, 0.6, 2)
		ripple(position, UP, 1, if dragon then 20 else 15, 0.45, 1.2, FOAM)
		shine(base + UP * 0.1, UP, 1, if dragon then 26 else 18, 0.45, if dragon then SAINT else WATER_LIGHT)
		mist(position, 7)
		puddle(base, 10, 2.5)
		if dragon then
			U.flash(position + UP * 3, SAINT, 10, 0.3)
			Soft.twinkle(position + UP * 3, 14, SAINT, 0.4)
		else
			U.flash(position + UP * 2, FOAM, 8, 0.25)
		end
		U.light(position, WATER, 6, 40, 0.8)
		if U.isLocal(character) then
			U.colorGrade(
				{ Brightness = 0.12, Saturation = 0.25, TintColor = Color3.fromRGB(225, 240, 255) },
				0,
				0.1,
				0.5
			)
			CameraShake.Add(0.35)
			CameraShake.FovKick(12)
		end
	elseif data.phase == "End" then
		splash(root.Position, 5)
		droplets(root.Position + UP, 14, 20, UP, 0.45)
		ripple(root.Position - UP * 2.7, UP, 1, 10, 0.45, 1.2)
	end
end

function handlers.Awaken(data, character, root)
	transformation(data, character, root, false)
end

function handlers.Ascend(data, character, root)
	transformation(data, character, root, true)
end

return Look
