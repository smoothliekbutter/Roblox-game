-- Asta's Black Form look (wing, horn, black flames), the awakening into it and his spawn entrance.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local VFX = require(script.Parent.Parent.Parent.VFX)

local U = VFX.Util

local rad = math.rad

local Fx = require(script.Parent.Fx)
local BLACK, RED, DARK_RED, RIM_RED, WHITE, UP = Fx.BLACK, Fx.RED, Fx.DARK_RED, Fx.RIM_RED, Fx.WHITE, Fx.UP
local rot, ANIMS, handlers, play, feetOf, getSword = Fx.rot, Fx.ANIMS, Fx.handlers, Fx.play, Fx.feetOf, Fx.getSword
local bladeOf, alongBlade, heavyTrail, blackSmoke = Fx.bladeOf, Fx.alongBlade, Fx.heavyTrail, Fx.blackSmoke
local redSparks, blackLightning, crackle, crescent = Fx.redSparks, Fx.blackLightning, Fx.crackle, Fx.crescent
local inflow, impactFrame, lingerSmoke, trailEmitter = Fx.inflow, Fx.impactFrame, Fx.lingerSmoke, Fx.trailEmitter

-- Black Form look: a devil wing with its own idle, a horn, black flames

type WingParams = {
	lift: number,
	back: number,
	bend: number,
	fan: number,
	sway: number,
	beat: number,
	rate: number,
}

local WING_STATES: { [string]: WingParams } = {
	folded = { lift = -65, back = 55, bend = -125, fan = 0.1, sway = 0, beat = 0, rate = 0.4 },
	stand = { lift = 30, back = 26, bend = -32, fan = 1, sway = 1, beat = 0.22, rate = 0.42 },
	run = { lift = 26, back = 60, bend = -28, fan = 1.15, sway = 0.7, beat = 0.08, rate = 2.4 },
	air = { lift = 26, back = 22, bend = -12, fan = 1.25, sway = 0.45, beat = 1, rate = 1.35 },
	spread = { lift = 40, back = 10, bend = 0, fan = 1.4, sway = 0.5, beat = 0.55, rate = 0.85 },
	glide = { lift = 16, back = 62, bend = -24, fan = 0.8, sway = 0.3, beat = 0.06, rate = 3 },
}

local UPPER_BONE, FOREARM = 2.2, 2.6

local FEATHERS = {
	{ bone = 1, at = 0.25, angle = 4, length = 1.7, width = 0.55 },
	{ bone = 1, at = 0.55, angle = 10, length = 2.1, width = 0.58 },
	{ bone = 1, at = 0.85, angle = 16, length = 2.5, width = 0.6 },
	{ bone = 2, at = 0.15, angle = 22, length = 2.9, width = 0.6 },
	{ bone = 2, at = 0.4, angle = 30, length = 3.3, width = 0.6 },
	{ bone = 2, at = 0.62, angle = 40, length = 3.5, width = 0.58 },
	{ bone = 2, at = 0.82, angle = 52, length = 3.4, width = 0.55 },
	{ bone = 2, at = 1.0, angle = 66, length = 3.0, width = 0.5 },
	{ bone = 2, at = 1.0, angle = 84, length = 2.4, width = 0.45 },
}

-- Horn segments from the base up, curling out and back in.
local HORN = {
	{ size = Vector3.new(0.3, 0.42, 0.3), bend = rot(-10, 0, 14) },
	{ size = Vector3.new(0.23, 0.4, 0.23), bend = rot(-12, 0, 12) },
	{ size = Vector3.new(0.16, 0.36, 0.16), bend = rot(-14, 0, 10) },
	{ size = Vector3.new(0.09, 0.32, 0.09), bend = rot(0) },
}

-- Asta's grimoire (defined further down, with his entrance; the sword swap in Form opens it too).
type Grimoire = { open: (number) -> (), close: () -> (), burst: () -> () }
local grimoire: (character: Model, root: BasePart, place: ((t: number) -> CFrame)?) -> Grimoire

type BlackFormVisual = {
	-- His grimoire, circling him while Black Form lasts.
	book: Grimoire?,
	flap: (() -> ())?,
	-- Force a wing pose (a WING_STATES name), or nil to go back to normal.
	setPose: ((string?) -> ())?,
	-- A second wing on his right, for cutscenes (he normally has one).
	setPair: ((boolean) -> ())?,
	cleanup: { () -> () },
}
local awakenedVisuals: { [Model]: BlackFormVisual } = {}

local function lerpParams(from: WingParams, to: WingParams, alpha: number): WingParams
	local out = {} :: any
	for key, value in from do
		out[key] = value + ((to :: any)[key] - value) * alpha
	end
	return out
end

local function setAwakened(character: Model, on: boolean)
	local existing = awakenedVisuals[character]
	if existing then
		awakenedVisuals[character] = nil
		for _, cleanup in existing.cleanup do
			cleanup()
		end
	end
	if not on then
		return
	end

	local torso = character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")
	local root = U.getRoot(character)
	if not (torso and torso:IsA("BasePart") and head and head:IsA("BasePart") and root) then
		return
	end
	local cleanup: { () -> () } = {}
	local visual: BlackFormVisual = { cleanup = cleanup }
	awakenedVisuals[character] = visual

	local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		e.LightInfluence = 0
		for key, value in props do
			(e :: any)[key] = value
		end
		e.Parent = parent
		table.insert(cleanup, function()
			e.Enabled = false
			task.delay(1.2, e.Destroy, e)
		end)
		return e
	end

	-- Black flames rolling up off him, licks of dark red at the edges.
	emitter(torso, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, BLACK),
			ColorSequenceKeypoint.new(0.7, BLACK),
			ColorSequenceKeypoint.new(1, DARK_RED),
		}),
		LightEmission = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 3.4) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(0.25, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.6, 1),
		Rate = 40,
		Speed = NumberRange.new(2, 4),
		Acceleration = Vector3.new(0, 8, 0),
		SpreadAngle = Vector2.new(70, 70),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	})
	emitter(torso, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(BLACK),
		LightEmission = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) }),
		Squash = NumberSequence.new(-0.6),
		Transparency = NumberSequence.new(0.15, 1),
		Lifetime = NumberRange.new(0.35, 0.6),
		Rate = 30,
		Speed = NumberRange.new(4, 8),
		Acceleration = Vector3.new(0, 16, 0),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
	})
	emitter(torso, {
		Texture = U.textures.Spark,
		Color = ColorSequence.new(RED),
		LightEmission = 1,
		Size = NumberSequence.new(0.25, 0),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 16,
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 5, 0),
	})

	-- Anti-magic swallowing the right arm.
	local arm = character:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		local original = arm.Color
		arm.Color = BLACK
		emitter(arm, {
			Texture = U.textures.Smoke,
			Color = ColorSequence.new(BLACK),
			LightEmission = 0,
			Size = NumberSequence.new(0.7, 1.4),
			Transparency = NumberSequence.new(0.3, 1),
			Lifetime = NumberRange.new(0.3, 0.5),
			Rate = 18,
			Speed = NumberRange.new(0.5, 2),
			Acceleration = Vector3.new(0, 6, 0),
			SpreadAngle = Vector2.new(180, 180),
		})
		table.insert(cleanup, function()
			if arm.Parent then
				arm.Color = original
			end
		end)
	end

	local swordDressing: { Instance } = {}
	local function dressSword()
		for _, instance in swordDressing do
			instance:Destroy()
		end
		table.clear(swordDressing)
		local sword = getSword(character)
		local blade = bladeOf(character)
		if not sword or not blade then
			return
		end
		table.insert(
			swordDressing,
			emitter(blade, {
				Texture = U.textures.Smoke,
				Color = ColorSequence.new(BLACK),
				LightEmission = 0,
				Size = NumberSequence.new(0.5, 1.1),
				Transparency = NumberSequence.new(0.35, 1),
				Lifetime = NumberRange.new(0.25, 0.45),
				Rate = 14,
				Speed = NumberRange.new(0.5, 2),
				Acceleration = Vector3.new(0, 5, 0),
				SpreadAngle = Vector2.new(180, 180),
			})
		)
		table.insert(
			swordDressing,
			emitter(blade, {
				Texture = U.textures.Spark,
				Color = ColorSequence.new(RED),
				LightEmission = 1,
				Size = NumberSequence.new(0.18, 0),
				Lifetime = NumberRange.new(0.2, 0.4),
				Rate = 5,
				Speed = NumberRange.new(1, 3),
				SpreadAngle = Vector2.new(180, 180),
			})
		)
		local swordLook = Instance.new("Highlight")
		swordLook.Adornee = sword
		swordLook.FillColor = BLACK
		swordLook.FillTransparency = 0.6
		swordLook.OutlineColor = RIM_RED
		swordLook.OutlineTransparency = 0.2
		swordLook.DepthMode = Enum.HighlightDepthMode.Occluded
		swordLook.Parent = U.folder
		table.insert(swordDressing, swordLook)
	end
	dressSword()
	local swordAdded = character.ChildAdded:Connect(function(child)
		if child.Name == "KitWeapon" then
			task.defer(dressSword)
		end
	end)
	table.insert(cleanup, function()
		swordAdded:Disconnect()
		for _, instance in swordDressing do
			instance:Destroy()
		end
	end)

	local outline = Instance.new("Highlight")
	outline.Adornee = character
	outline.FillColor = Color3.fromRGB(45, 4, 10)
	outline.FillTransparency = 0.8
	outline.OutlineColor = RIM_RED
	outline.OutlineTransparency = 0.12
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = character
	local rimGlow = Instance.new("PointLight")
	rimGlow.Color = RIM_RED
	rimGlow.Brightness = 0.6
	rimGlow.Range = 7
	rimGlow.Shadows = false
	rimGlow.Parent = torso
	table.insert(cleanup, function()
		outline:Destroy()
		rimGlow:Destroy()
	end)

	-- Wing, horn and ground aura: anchored parts posed every frame.
	local parts: { BasePart } = {}
	local function piece(props: { [string]: any }): BasePart
		local part = U.newPart(props)
		table.insert(parts, part)
		return part
	end
	local matte = Enum.Material.SmoothPlastic

	type Wing = {
		parts: { BasePart },
		edges: { [BasePart]: boolean },
		emitters: { ParticleEmitter },
		shown: number,
		target: number,
		applied: number,
		pose: (
			torsoFrame: CFrame,
			lift: number,
			back: number,
			bend: number,
			fan: number,
			sweep: number,
			sway: number,
			beat: number,
			waveLag: number,
			t: number,
			running: boolean
		) -> (),
	}
	local function newWing(mirror: number, shown: number): Wing
		local m = mirror
		local wingParts: { BasePart } = {}
		local function wingPiece(props: { [string]: any }): BasePart
			local part = piece(props)
			table.insert(wingParts, part)
			return part
		end
		local upperBone = wingPiece({ Size = Vector3.new(UPPER_BONE, 0.32, 0.32), Color = BLACK, Material = matte })
		local forearm = wingPiece({ Size = Vector3.new(FOREARM, 0.24, 0.24), Color = BLACK, Material = matte })
		local upperEdge = wingPiece({ Size = Vector3.new(UPPER_BONE, 0.07, 0.07), Color = DARK_RED })
		local forearmEdge = wingPiece({ Size = Vector3.new(FOREARM, 0.06, 0.06), Color = DARK_RED })
		local wrist =
			wingPiece({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.42, Color = BLACK, Material = matte })
		local claw = wingPiece({ Size = Vector3.new(0.14, 0.7, 0.14), Color = BLACK, Material = matte })
		local feathers: { { plate: BasePart, tip: BasePart } } = {}
		for _, feather in FEATHERS do
			table.insert(feathers, {
				plate = wingPiece({
					Size = Vector3.new(feather.width, feather.length, 0.07),
					Color = BLACK,
					Material = matte,
				}),
				tip = wingPiece({
					Size = Vector3.new(feather.width * 0.7, feather.width * 0.7, 0.065),
					Color = BLACK,
					Material = matte,
				}),
			})
		end

		-- Smoke streaming off the wingtip, embers off the forearm.
		local wingEmitters = {
			emitter(feathers[#feathers - 1].tip, {
				Texture = U.textures.Smoke,
				Color = ColorSequence.new(BLACK),
				LightEmission = 0,
				Size = NumberSequence.new(0.6, 1.6),
				Transparency = NumberSequence.new(0.35, 1),
				Lifetime = NumberRange.new(0.4, 0.7),
				Rate = 16,
				Speed = NumberRange.new(0.5, 1.5),
				Acceleration = Vector3.new(0, 4, 0),
				SpreadAngle = Vector2.new(180, 180),
			}),
			emitter(forearm, {
				Texture = U.textures.Spark,
				Color = ColorSequence.new(RED),
				LightEmission = 1,
				Size = NumberSequence.new(0.2, 0),
				Lifetime = NumberRange.new(0.4, 0.8),
				Rate = 6,
				Speed = NumberRange.new(1, 3),
				SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, 3, 0),
			}),
		}

		local function pose(
			torsoFrame: CFrame,
			lift: number,
			back: number,
			bend: number,
			fan: number,
			sweep: number,
			sway: number,
			beat: number,
			waveLag: number,
			t: number,
			running: boolean
		)
			-- Bones.
			local shoulderFrame = torsoFrame
				* CFrame.new(-0.6 * m, 0.55, 0.55) -- upper back
				* CFrame.Angles(0, rad(back) * m, 0)
				* CFrame.Angles(0, 0, rad(-lift) * m)
			local wristFrame = shoulderFrame
				* CFrame.new(-UPPER_BONE * m, 0, 0)
				* CFrame.Angles(0, rad(10 + sweep * 0.2) * m, 0)
				* CFrame.Angles(0, 0, rad(-bend) * m)
			upperBone.CFrame = shoulderFrame * CFrame.new(-UPPER_BONE / 2 * m, 0, 0)
			upperEdge.CFrame = shoulderFrame * CFrame.new(-UPPER_BONE / 2 * m, 0.17, -0.05)
			forearm.CFrame = wristFrame * CFrame.new(-FOREARM / 2 * m, 0, 0)
			forearmEdge.CFrame = wristFrame * CFrame.new(-FOREARM / 2 * m, 0.13, -0.05)
			wrist.CFrame = wristFrame
			claw.CFrame = wristFrame * CFrame.Angles(0, 0, rad(40) * m) * CFrame.new(0, 0.4, 0)

			-- Feathers: fanned out, rippling from the root to the tip.
			for i, feather in FEATHERS do
				local frame = if feather.bone == 1 then shoulderFrame else wristFrame
				local length = if feather.bone == 1 then UPPER_BONE else FOREARM
				local ripple = math.sin(t * 2.6 - i * 0.45) * 4 * sway
					+ math.sin(t * 13 - i * 0.7) * 3 * (if running then 1 else 0)
				local twist = math.sin(t * 1.9 - i * 0.5) * 7 * sway - 9 * beat * waveLag
				local joint = frame
					* CFrame.new(-length * feather.at * m, 0, 0.03 * i)
					* CFrame.Angles(rad(twist), 0, 0)
					* CFrame.Angles(0, 0, rad(-(feather.angle * fan + ripple)) * m)
				local pair = feathers[i]
				pair.plate.CFrame = joint * CFrame.new(0, -feather.length / 2, 0)
				pair.tip.CFrame = joint * CFrame.new(0, -feather.length, 0) * CFrame.Angles(0, 0, rad(45))
			end
		end

		return {
			parts = wingParts,
			edges = { [upperEdge] = true, [forearmEdge] = true },
			emitters = wingEmitters,
			shown = shown,
			target = shown,
			applied = -1,
			pose = pose,
		}
	end
	local wings = { newWing(1, 1), newWing(-1, 0) }

	local hornParts: { BasePart } = {}
	for _, segment in HORN do
		table.insert(hornParts, piece({ Size = segment.size, Color = BLACK, Material = matte }))
	end
	local disc = piece({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, 7, 7),
		Color = BLACK,
		Material = matte,
		Transparency = 0.55,
	})
	local discRim = piece({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 7.6, 7.6),
		Color = DARK_RED,
		Transparency = 0.65,
	})

	-- Hidden until the first frame poses them (they're built at the origin).
	for _, part in parts do
		part.Transparency = 1
	end

	local current: WingParams = table.clone(WING_STATES.folded)
	local phase = 0
	local state = "stand"
	local born = os.clock()
	local flapStart = -10
	local nextStretch = os.clock() + 4 + math.random() * 4
	local nextCrackle = os.clock() + 0.5
	local nextPulse = os.clock() + 1
	local groundY: number? = nil
	local nextGroundCheck = 0
	local fading: number? = nil
	local FADE = 0.4

	-- A big beat: the Stance in the awakening, and now and then when idle.
	visual.flap = function()
		flapStart = os.clock()
	end
	local forcedPose: string? = nil
	visual.setPose = function(name: string?)
		forcedPose = if name and WING_STATES[name] then name else nil
	end
	visual.setPair = function(on: boolean)
		local second = wings[2]
		second.target = if on then 1 else 0
		if on and second.shown < 0.5 then
			-- It forms out of black smoke.
			blackSmoke(torso.Position + torso.CFrame.RightVector * 2.5 + torso.CFrame.LookVector * -1, 10, 3, 6)
		end
	end
	local hornBase = CFrame.new(0.42, 0.42, -0.1) * rot(0, 0, -34)
	local face = CFrame.Angles(0, 0, rad(90)) -- cylinder X axis up

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if not torso.Parent or not head.Parent or not root.Parent then
			connection:Disconnect()
			for _, part in parts do
				part:Destroy()
			end
			return
		end
		-- The rim breathes: a slow, soft swell.
		local breath = 0.5 + 0.5 * math.sin((now - born) * 2.2)
		outline.OutlineTransparency = 0.18 - 0.12 * breath
		rimGlow.Brightness = 0.45 + 0.35 * breath

		-- What is he doing? Ground check a few times a second.
		if now >= nextGroundCheck then
			nextGroundCheck = now + 0.1
			local ground = U.groundBelow(root.Position, { character })
			groundY = if ground and root.Position.Y - ground.Position.Y < 4.4 then ground.Position.Y else nil
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local newState = if groundY == nil then "air" elseif speed > 4 then "run" else "stand"
		if newState == "air" and state ~= "air" then
			phase = 0.25 -- start the first beat from the top
		end
		state = newState

		-- Ease toward the state's pose; unfurl from folded when it appears.
		local unfurl = math.clamp((now - born) / 0.55, 0, 1)
		local reveal = TweenService:GetValue(unfurl, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local target = lerpParams(WING_STATES.folded, WING_STATES[forcedPose or state], reveal)
		local ease = 1 - math.exp(-dt * (if unfurl < 1 then 30 else 7))
		current = lerpParams(current, target, ease)
		phase = (phase + dt * current.rate) % 1

		-- Idle stretch every so often.
		if state == "stand" and now >= nextStretch then
			nextStretch = now + 7 + math.random() * 5
			flapStart = now
		end
		local flapAge = now - flapStart
		local flap = if flapAge < 0.9 then math.sin(math.pi * flapAge / 0.9) else 0
		local flapLag = if flapAge > 0.12 and flapAge < 1.02 then math.sin(math.pi * (flapAge - 0.12) / 0.9) else 0

		local wave = math.sin(phase * math.pi * 2)
		local waveLag = math.sin(phase * math.pi * 2 - 0.9)
		local lift = current.lift + 28 * current.beat * wave + 34 * flap
		local bend = current.bend + 22 * current.beat * waveLag + 26 * flapLag
		local back = current.back - 10 * flap
		local fan = current.fan + 0.3 * flap

		-- Both wings (the second only shows in cutscenes).
		local t = now - born
		for _, wing in wings do
			wing.shown += (wing.target - wing.shown) * math.min(dt * 6, 1)
			if wing.shown > 0.01 then
				wing.pose(
					torso.CFrame,
					lift,
					back,
					bend,
					fan,
					current.back,
					current.sway,
					current.beat,
					waveLag,
					t,
					state == "run" and forcedPose == nil
				)
			end
		end

		-- Horn.
		local hornFrame = head.CFrame * hornBase
		for i, segment in HORN do
			local height = segment.size.Y
			hornParts[i].CFrame = hornFrame * CFrame.new(0, height / 2, 0)
			hornFrame = hornFrame * CFrame.new(0, height * 0.9, 0) * segment.bend
		end

		-- Dark pool under his feet (only when standing on something).
		if groundY then
			local pulse = 1 + 0.06 * math.sin(t * 2)
			local spot = Vector3.new(root.Position.X, groundY + 0.06, root.Position.Z)
			disc.CFrame = CFrame.new(spot) * face
			disc.Size = Vector3.new(0.06, 7 * pulse, 7 * pulse)
			discRim.CFrame = CFrame.new(spot - Vector3.new(0, 0.01, 0)) * face
			discRim.Size = Vector3.new(0.05, 7.7 * pulse, 7.7 * pulse)
		end
		local poolShown = groundY ~= nil and not fading
		disc.Transparency = if poolShown then 0.55 else 1
		discRim.Transparency = if poolShown then 0.65 else 1

		-- Little things: crackles off his body, pressure rings on the ground.
		if not fading and now >= nextCrackle then
			nextCrackle = now + 0.45 + math.random() * 0.7
			local from = torso.Position + U.randomUnit() * 1.2
			U.lightning(from, from + U.randomUnit() * 3.2, BLACK, RED, 0.08, 0.14, false)
		end
		if not fading and groundY and now >= nextPulse then
			nextPulse = now + 1.6
			U.ringBurst(CFrame.new(root.Position.X, groundY + 0.1, root.Position.Z), DARK_RED, 2, 6, 0.6, 0.08)
		end

		-- Grow in when it appears, dissolve when Black Form ends.
		local visible = math.clamp((now - born) / 0.3, 0, 1)
		if fading then
			visible = 1 - (now - fading) / FADE
			if visible <= 0 then
				connection:Disconnect()
				for _, part in parts do
					part:Destroy()
				end
				return
			end
		end
		if visible < 1 or fading or now - born < 0.35 then
			for _, part in hornParts do
				part.Transparency = 1 - visible
			end
		end
		for _, wing in wings do
			local alpha = math.floor(visible * wing.shown * 50 + 0.5) / 50
			if alpha ~= wing.applied then
				wing.applied = alpha
				for _, part in wing.parts do
					local base = if wing.edges[part] then 0.2 else 0
					part.Transparency = base + (1 - base) * (1 - alpha)
				end
				for _, e in wing.emitters do
					e.Enabled = alpha > 0.5 and not fading
				end
			end
		end
	end)
	local book = grimoire(character, root, function(t: number): CFrame
		local angle = t * 1.3
		local position = root.Position
			+ Vector3.new(math.cos(angle) * 2.8, 1.2 + math.sin(t * 2.1) * 0.35, math.sin(angle) * 2.8)
		return CFrame.lookAt(position, root.Position + UP * 1.2) * CFrame.Angles(rad(-15), 0, math.sin(t * 1.7) * 0.15)
	end)
	book.open(0.6)
	visual.book = book
	table.insert(cleanup, book.close)

	table.insert(cleanup, function()
		fading = os.clock()
		if torso.Parent then
			U.burst(torso.Position + torso.CFrame.LookVector * -1, {
				color = BLACK,
				count = 14,
				size = 0.5,
				speed = NumberRange.new(4, 10),
				lifetime = NumberRange.new(0.8, 1.4),
				lightEmission = 0,
				acceleration = Vector3.new(0, -6, 0),
				drag = 1,
			})
		end
	end)
end

-- Awakening: the transformation into Black Form

local AWAKEN_BURST = 0.92 -- the roar in the Awaken animation; the server bursts here too

-- When the Black Form look should pop in (at the burst, not before).
local revealAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function refreshAwakened(character: Model)
	local on = character:GetAttribute("Awakened") == true
	if on and awakenedVisuals[character] then
		return
	end
	setAwakened(character, on)
end

-- What the burst consumes from the gathering: the pool and floating rocks.
local gathering: { [Model]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any

local function awakenGather(character: Model, root: BasePart)
	local feet = feetOf(character, root)
	local mine = U.isLocal(character)
	local made: { BasePart } = {}
	gathering[character] = made

	-- Darkness pooling out under him, a red rim at its edge.
	local face = CFrame.Angles(0, 0, rad(90))
	local pool = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, 1, 1),
		CFrame = CFrame.new(feet + UP * 0.06) * face,
		Color = BLACK,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
	})
	local rim = U.newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, 1.4, 1.4),
		CFrame = CFrame.new(feet + UP * 0.05) * face,
		Color = DARK_RED,
		Transparency = 0.45,
	})
	U.tween(pool, 0.9, { Size = Vector3.new(0.08, 22, 22) }, Enum.EasingStyle.Quart)
	U.tween(rim, 0.9, { Size = Vector3.new(0.06, 23.2, 23.2) }, Enum.EasingStyle.Quart)
	table.insert(made, pool)
	table.insert(made, rim)

	-- Rocks tearing loose and floating up around him.
	local ground = U.groundBelow(feet + UP)
	local rockColor = if ground and ground.Instance:IsA("BasePart")
		then ground.Instance.Color
		else Color3.fromRGB(90, 88, 85)
	local rockMaterial = if ground then ground.Material else Enum.Material.Slate
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2 + math.random() * 0.5
		local distance = 3.5 + math.random() * 5
		local size = 0.5 + math.random() * 0.9
		local start = feet + Vector3.new(math.cos(angle) * distance, -size, math.sin(angle) * distance)
		local rock = U.newPart({
			Size = Vector3.one * size,
			CFrame = CFrame.new(start) * U.randomAngles(),
			Color = rockColor,
			Material = rockMaterial,
		})
		rock.CastShadow = true
		local lift = 1.5 + math.random() * 4
		U.tween(rock, 0.9, {
			CFrame = CFrame.new(start + UP * lift) * U.randomAngles(),
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		table.insert(made, rock)
	end

	-- Anti-magic spiralling in and crawling up his body.
	U.spiral(root, BLACK, 6.5, 2.5, 0.9, 4, 0.7, 0.85)
	U.spiral(root, RED, 5.5, 2.5, 0.9, 2, 0.2, 0.85)
	task.delay(0.35, U.groundCracks, feet, 6, 5, RED, 2.5)
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < AWAKEN_BURST - 0.02 and root.Parent do
			local angle = math.random() * math.pi * 2
			local from = feet + Vector3.new(math.cos(angle), 0.2, math.sin(angle)) * (1 + math.random() * 2.5)
			U.lightning(from, root.Position + U.randomUnit() * Vector3.new(1, 2, 1), BLACK, RED, 0.1, 0.12)
			if math.random() < 0.5 then
				inflow(root.Position + UP * 0.5, 6)
			end
			if math.random() < 0.3 then
				blackSmoke(feet + U.randomUnit() * Vector3.new(4, 0, 4) + UP * 0.3, 2, 2.5, 3)
			end
			if mine then
				CameraShake.Add(0.035)
			end
			task.wait(0.06)
		end
	end)

	-- For whoever is transforming: the world dims and the view closes in.
	if mine then
		U.colorGrade({
			Brightness = -0.12,
			Contrast = 0.3,
			Saturation = -0.65,
			TintColor = Color3.fromRGB(255, 225, 225),
		}, 0.85, 0.05, 0.6)
		local camera = workspace.CurrentCamera
		TweenService
			:Create(
				camera,
				TweenInfo.new(0.88, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ FieldOfView = 56 }
			)
			:Play()
		-- The burst kicks it back out; if the burst never comes, restore it.
		task.delay(AWAKEN_BURST + 0.6, function()
			if camera.FieldOfView < 69 then
				TweenService:Create(camera, TweenInfo.new(0.3), { FieldOfView = 70 }):Play()
			end
		end)
	end
end

local function awakenBurst(character: Model, root: BasePart)
	local feet = feetOf(character, root)
	local center = root.Position

	-- The gathering gets blown away.
	local consumed = gathering[character]
	if consumed then
		for _, part in consumed do
			if part.Parent then
				if part.Shape == Enum.PartType.Cylinder then
					U.tween(part, 0.3, { Size = part.Size * Vector3.new(1, 1.6, 1.6), Transparency = 1 })
				else
					local out = part.Position - center
					out = Vector3.new(out.X, 0, out.Z).Unit
					U.tween(part, 0.4, {
						CFrame = CFrame.new(part.Position + out * 16 + UP * 5) * U.randomAngles(),
						Transparency = 1,
					}, Enum.EasingStyle.Quad)
				end
				task.delay(0.45, part.Destroy, part)
			end
		end
	end
	gathering[character] = nil

	-- The blast.
	U.flash(center, WHITE, 5, 0.08)
	U.flash(center, BLACK, 24, 0.45)
	U.flash(center, RED, 14, 0.3)
	U.shockwave(feet, BLACK, 4, 52, 0.7, Enum.Material.Glass, 0.3)
	U.shockwave(center, RED, 3, 40, 0.55)
	task.delay(0.08, U.shockwave, center, DARK_RED, 2, 28, 0.5)
	U.ringBurst(CFrame.new(feet + UP * 0.2), BLACK, 2, 34, 0.6, 0.9)
	task.delay(0.04, U.ringBurst, CFrame.new(feet + UP * 0.3), RED, 2, 26, 0.5, 0.45)
	task.delay(0.08, U.ringBurst, CFrame.new(feet + UP * 0.4), WHITE, 1, 18, 0.3, 0.15)
	U.impactRing(center, root.CFrame.LookVector, BLACK, 2, 18, 0.5)
	U.impactRing(center, root.CFrame.RightVector, RED, 2, 14, 0.45)

	-- A black pillar punching up into the sky.
	U.pillar(feet, BLACK, 4.5, 80, 1.1, Enum.Material.SmoothPlastic, 0.1)
	U.pillar(feet, RED, 2.4, 90, 0.9)
	task.delay(0.05, U.pillar, feet, WHITE, 1, 95, 0.4)

	-- The ground splits and erupts.
	U.groundCracks(feet, 16, 18, RED, 4)
	U.groundRocks(feet, 18, 8, 3)
	task.delay(0.06, U.groundRocks, feet, 10, 4, 2.2)
	U.debris(feet, 26, 65, 1.6)
	blackSmoke(center, 40, 7, 40)
	U.burst(feet, {
		texture = U.textures.Smoke,
		color = Color3.fromRGB(150, 140, 130),
		count = 24,
		size = 8,
		speed = NumberRange.new(30, 55),
		lifetime = NumberRange.new(0.9, 1.6),
		lightEmission = 0,
		transparency = 0.35,
		drag = 2.5,
		spread = 85,
	})
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2 + math.random() * 0.3
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		U.lightning(feet + UP * 0.5, feet + out * (10 + math.random() * 10) + UP * 0.3, BLACK, RED, 0.24, 0.35)
	end
	for _ = 1, 5 do
		U.lightning(center, center + UP * (10 + math.random() * 8) + U.randomUnit() * 4, BLACK, RED, 0.22, 0.3)
	end
	redSparks(center, 40, 1.6)
	U.light(center, RED, 18, 60, 0.9)
	U.highlight(character, BLACK, 0.6, 0.65)
	U.popup(center + UP * 6, "BLACK FORM", RED, 2.4)
	lingerSmoke(feet, 2, 10)

	-- He keeps erupting while he roars.
	trailEmitter(root, {
		Texture = U.textures.Smoke,
		Color = ColorSequence.new(BLACK),
		LightEmission = 0,
		Size = NumberSequence.new(2, 5),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 120,
		Speed = NumberRange.new(8, 18),
		Acceleration = Vector3.new(0, 10, 0),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Drag = 2,
	}, 0.6)
	crackle(root, 0.6, 0.05, 4)

	if U.isLocal(character) then
		impactFrame(1.3)
		U.screenFlash(RED, 0.4)
		task.delay(0.1, U.colorGrade, {
			TintColor = Color3.fromRGB(255, 175, 175),
			Saturation = -0.3,
			Contrast = 0.2,
		}, 0, 0.3, 0.6)
		CameraShake.FovKick(18)
	end
end

-- The sword comes down into his Black Form stance and the wing beats once.
local function awakenStance(character: Model, root: BasePart)
	heavyTrail(character, 0.3)
	crescent(character, {
		center = CFrame.new(0, 0.5, 0),
		radius = 6,
		from = 55,
		to = -10,
		tilt = 45,
		width = 2.4,
		sweep = 0.1,
		fade = 0.35,
	})
	local feet = feetOf(character, root)
	U.ringBurst(CFrame.new(feet + UP * 0.15), BLACK, 1, 9, 0.35, 0.3)
	blackSmoke(feet + UP * 0.4, 10, 3, 12)
	local visual = awakenedVisuals[character]
	if visual and visual.flap then
		visual.flap()
	end
	local torso = character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		-- Loose feathers shaken off by the beat.
		U.burst(torso.Position - torso.CFrame.RightVector * 2 - torso.CFrame.LookVector, {
			color = BLACK,
			count = 16,
			size = 0.6,
			speed = NumberRange.new(8, 18),
			lifetime = NumberRange.new(0.8, 1.4),
			lightEmission = 0,
			acceleration = Vector3.new(0, -8, 0),
			drag = 1.5,
		})
	end
	if U.isLocal(character) then
		CameraShake.Add(0.2)
	end
end

function handlers.Awaken(data, character, root)
	local phase = data.phase
	if phase == "Start" then
		-- The look pops in at the burst, not before.
		revealAt[character] = os.clock() + AWAKEN_BURST
		if awakenedVisuals[character] then
			setAwakened(character, false)
		end
		task.delay(AWAKEN_BURST, refreshAwakened, character)
		play(character, ANIMS.Awaken, function(event)
			if event == "Stance" and character.Parent then
				awakenStance(character, root)
			end
		end)
		awakenGather(character, root)
	elseif phase == "Burst" then
		awakenBurst(character, root)
	elseif phase == "End" then
		blackSmoke(root.Position, 16, 3.5, 10)
		U.afterimage(character, BLACK, 0.5)
		U.ringBurst(CFrame.new(feetOf(character, root) + UP * 0.1), DARK_RED, 1, 6, 0.4, 0.15)
	end
end

-- Spawn entrance

local function easeInOut(alpha: number): number
	return TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local function setSwordVisible(character: Model, visible: boolean, fade: number?)
	local sword = getSword(character)
	if not sword then
		return
	end
	for _, part in sword:GetDescendants() do
		if part:IsA("BasePart") then
			if fade and visible then
				part.Transparency = 1
				U.tween(part, fade, { Transparency = 0 })
			else
				part.Transparency = if visible then 0 else 1
			end
		end
	end
end

function grimoire(character: Model, root: BasePart, place: ((t: number) -> CFrame)?): Grimoire
	local parts: { { part: BasePart, offset: CFrame, side: number } } = {}
	local function piece(size: Vector3, color: Color3, material: Enum.Material, offset: CFrame, side: number): BasePart
		local part = U.newPart({ Size = size, Color = color, Material = material, Transparency = 1 })
		table.insert(parts, { part = part, offset = offset, side = side })
		return part
	end
	local cover = Color3.fromRGB(24, 22, 26)
	local paper = Color3.fromRGB(205, 195, 170)
	-- side -1 = left half (rotates open one way), 1 = right half, 0 = fixed
	piece(Vector3.new(1.1, 1.45, 0.08), cover, Enum.Material.Fabric, CFrame.new(-0.55, 0, 0), -1)
	piece(Vector3.new(1.1, 1.45, 0.08), cover, Enum.Material.Fabric, CFrame.new(0.55, 0, 0), 1)
	piece(Vector3.new(1, 1.35, 0.12), paper, Enum.Material.SmoothPlastic, CFrame.new(-0.5, 0, -0.08), -1)
	piece(Vector3.new(1, 1.35, 0.12), paper, Enum.Material.SmoothPlastic, CFrame.new(0.5, 0, -0.08), 1)
	piece(Vector3.new(0.14, 1.45, 0.14), cover, Enum.Material.Fabric, CFrame.new(0, 0, 0.02), 0)
	-- Five-leaf clover hovering over the pages.
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		piece(
			Vector3.new(0.34, 0.34, 0.06),
			BLACK,
			Enum.Material.SmoothPlastic,
			CFrame.new(math.cos(angle) * 0.24, 1.1 + math.sin(angle) * 0.24, -0.4) * CFrame.Angles(0, 0, angle),
			0
		)
	end
	local glowHolder = piece(Vector3.one * 0.1, RED, Enum.Material.Neon, CFrame.new(0, 1.1, -0.4), 0)
	local glow = Instance.new("PointLight")
	glow.Color = RED
	glow.Brightness = 0
	glow.Range = 8
	glow.Parent = glowHolder

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = U.textures.Smoke
	smoke.Color = ColorSequence.new(BLACK)
	smoke.LightEmission = 0
	smoke.Size = NumberSequence.new(0.8, 1.6)
	smoke.Transparency = NumberSequence.new(0.5, 1)
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Rate = 25
	smoke.Speed = NumberRange.new(0.5, 1.5)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Acceleration = Vector3.new(0, 2, 0)
	smoke.Parent = glowHolder

	local openAngle, visible = 0, 0
	local anchorOffset = CFrame.new(-1.9, 0.6, -1.7)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			-- He's gone (died, left): the book goes with him.
			connection:Disconnect()
			for _, entry in parts do
				entry.part:Destroy()
			end
			return
		end
		local t = os.clock() - start
		local base, flutter
		if place then
			base, flutter = place(t), math.sin(t * 6) * 7 + math.sin(t * 13) * 3
		else
			local position = (root.CFrame * anchorOffset).Position + Vector3.new(0, math.sin(t * 3) * 0.12, 0)
			-- Faces Asta, tilted back like it's being read.
			base = CFrame.lookAt(position, root.Position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(rad(-20), 0, 0)
			flutter = 0
		end
		for _, entry in parts do
			local hinge = CFrame.Angles(0, -entry.side * rad(openAngle + flutter * visible), 0)
			local spin = if entry.side == 0 and entry.offset.Y > 0.5
				then CFrame.new(0, 1.1, -0.4) * CFrame.Angles(0, 0, t * 1.5) * CFrame.new(0, -1.1, 0.4)
				else CFrame.identity
			entry.part.CFrame = base * hinge * spin * entry.offset
			entry.part.Transparency = 1 - visible
		end
		glowHolder.Transparency = 1
		glow.Brightness = 3 * visible
	end)

	local function animateTo(duration: number, toOpen: number, toVisible: number)
		local fromOpen, fromVisible = openAngle, visible
		local t0 = os.clock()
		local c
		c = RunService.RenderStepped:Connect(function()
			local a = math.min((os.clock() - t0) / duration, 1)
			local e = easeInOut(a)
			openAngle = fromOpen + (toOpen - fromOpen) * e
			visible = fromVisible + (toVisible - fromVisible) * e
			if a >= 1 then
				c:Disconnect()
			end
		end)
	end

	return {
		open = function(duration: number)
			animateTo(duration, 65, 1)
		end,
		burst = function()
			blackSmoke(glowHolder.Position, 10, 2.5, 8)
			U.flash(glowHolder.Position, RED, 3, 0.2)
			U.light(glowHolder.Position, RED, 6, 12, 0.3)
		end,
		close = function()
			animateTo(0.3, 0, 0)
			smoke.Enabled = false
			task.delay(0.35, function()
				blackSmoke(glowHolder.Position, 6, 1.5, 4)
				connection:Disconnect()
				for _, entry in parts do
					entry.part:Destroy()
				end
			end)
		end,
	}
end

function handlers.Entrance(data, character, root)
	if data.phase ~= "Start" then
		return
	end
	setSwordVisible(character, false)
	blackSmoke(root.Position - UP * 2.6, 10, 3, 6)
	U.ringBurst(CFrame.new(root.Position - UP * 2.9), BLACK, 1, 7, 0.4, 0.25)

	local book: any = nil
	local finished = false
	local function cleanup()
		if finished then
			return
		end
		finished = true
		setSwordVisible(character, true)
		if book then
			book.close()
		end
	end
	-- Whatever happens (death, interruption), never leave the sword hidden.
	task.delay(3, cleanup)

	play(character, ANIMS.Entrance, function(event)
		if not character.Parent then
			cleanup()
			return
		end
		if event == "Grimoire" then
			book = grimoire(character, root)
			book.open(0.45)
		elseif event == "Draw" then
			if book then
				book.burst()
			end
			setSwordVisible(character, true, 0.08)
			redSparks(root.Position + UP * 1.5, 10, 0.8)
		elseif event == "Slam" then
			local sword = getSword(character)
			local blade = sword and sword:FindFirstChild("Blade")
			local tip = if blade and blade:IsA("BasePart")
				then alongBlade(blade, 2.1).Position
				else root.Position + root.CFrame.LookVector * 5
			U.groundRocks(tip, 9, 2, 1.4)
			blackSmoke(tip, 12, 3.5, 14)
			U.ringBurst(CFrame.new(tip + UP * 0.2), BLACK, 0.6, 9, 0.35, 0.3)
			blackLightning(tip + UP, 5, 5)
			U.light(tip, RED, 6, 18, 0.35)
			if U.isLocal(character) then
				CameraShake.Add(0.35)
			end
		elseif event == "Settle" then
			cleanup()
		end
	end)
end

return {
	grimoire = grimoire,
	awakenedVisuals = awakenedVisuals,
	setAwakened = setAwakened,
	revealAt = revealAt,
}
