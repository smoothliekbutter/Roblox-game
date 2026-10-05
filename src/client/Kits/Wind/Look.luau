-- Yuno's Half-Crown / Full-Crown transformations and looks (wings, sword) and his spawn entrance.

local RunService = game:GetService("RunService")

local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local VFX = require(script.Parent.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Parent.Soft)
local Sword = require(script.Parent.Sword)
local Wings = require(script.Parent.Wings)

local U = VFX.Util
local rad = math.rad
local UP = Vector3.yAxis

-- The palette and the soft wind everything is drawn with (see Soft).
local WIND, WIND_WHITE = Soft.WIND, Soft.WIND_WHITE
local STAR, STAR_WHITE = Soft.STAR, Soft.STAR_WHITE
local SMOKE, SPARKLE = Soft.SMOKE, Soft.SPARKLE
local every, fadeOut, key = Soft.every, Soft.fadeOut, Soft.key
local inflow, gust = Soft.inflow, Soft.gust
local makeSprite = Soft.makeSprite
local worldAnchor, softBeam, fadeBeams, softRing = Soft.worldAnchor, Soft.softBeam, Soft.fadeBeams, Soft.softRing
local windRing, lightRing, windEmitter, windPuff = Soft.windRing, Soft.lightRing, Soft.windEmitter, Soft.windPuff
local twinkle, starDust = Soft.twinkle, Soft.starDust

local Fx = require(script.Parent.Fx)
local ANIMS, handlers, play, easeOut, featherBurst = Fx.ANIMS, Fx.handlers, Fx.play, Fx.easeOut, Fx.featherBurst

-- His look while crowned, per character; moves can hide his wind sword for a moment (the halberd, the bow).
local looks: { [Model]: { hideSword: number, blade: BasePart? } } = {}

local function hideSword(character: Model, duration: number)
	local look = looks[character]
	if look then
		look.hideSword = os.clock() + duration
	end
end

-- Half-Crown / Full-Crown: transformations and looks

-- Sylph circles in and merges into him at the burst; wind gathers, then
-- blasts out.
local function transformation(data, character: Model, root: BasePart, full: boolean)
	if data.phase == "Start" then
		play(character, if full then ANIMS.Ascend else ANIMS.Awaken)
		local sylph = makeSprite(1.4)
		every(0.8, function(elapsed)
			if not root.Parent then
				return false
			end
			local t = elapsed / 0.8
			local angle = t * math.pi * 4
			local radius = 5 * (1 - t) + 0.5
			sylph.place(
				CFrame.new(root.Position + Vector3.new(math.cos(angle) * radius, 3 - t * 2, math.sin(angle) * radius)),
				elapsed
			)
			inflow(root.Position, 7)
			return true
		end, function()
			sylph.fade(0.15)
		end)
		if full then
			U.spiral(root, WIND, 4, 10, 1.3, 4, 0.2, 0.5)
		end
		U.ringBurst(CFrame.new(root.Position - UP * 2.8), WIND, 12, 2, 0.8, 0.2)
		local feet = root.Position - UP * 2.85
		local circle = {
			softRing({
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 1.8,
				width1 = 1.8,
				transparency = NumberSequence.new(0.5),
				texture = SMOKE,
				speed = 3,
				length = 5,
			}),
			softRing({
				color = ColorSequence.new(if full then STAR_WHITE else WIND_WHITE, if full then STAR else WIND),
				width0 = 0.9,
				width1 = 0.9,
				transparency = NumberSequence.new(0.35),
				texture = SPARKLE,
				wrap = true,
				length = 1.4,
				speed = 2,
			}),
		}
		local well = U.newPart({ Size = Vector3.one * 16, Transparency = 1, CFrame = CFrame.new(root.Position) })
		local drawn = {
			windEmitter(well, {
				Size = NumberSequence.new({ key(0, 4), key(1, 1) }),
				Lifetime = NumberRange.new(0.5, 0.6),
				Speed = NumberRange.new(14, 16),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				Rate = 40,
			}),
			windEmitter(well, {
				Texture = SPARKLE,
				Color = ColorSequence.new(STAR_WHITE, if full then STAR else WIND_WHITE),
				LightEmission = 1,
				Transparency = NumberSequence.new({ key(0, 1), key(0.3, 0.2), key(1, 0.6) }),
				Size = NumberSequence.new({ key(0, 0.7), key(1, 0.1) }),
				Lifetime = NumberRange.new(0.5, 0.6),
				Speed = NumberRange.new(14, 16),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				Rate = 50,
			}),
		}
		Soft.helix(function()
			return root.Position - UP * 3, root.Position + UP * 4
		end, 3.5, if full then 4 else 3, 0.45, 2, 0.8, 0.8)
		every(0.8, function(elapsed)
			if not root.Parent then
				return false
			end
			local close = easeOut(elapsed / 0.8)
			circle[1].set(CFrame.new(feet) * CFrame.Angles(0, elapsed * 3, 0), 11 - 8 * close)
			circle[2].set(CFrame.new(feet + UP * 0.05) * CFrame.Angles(0, -elapsed * 2, 0), 12 - 8.5 * close)
			return true
		end, function()
			for _, ring in circle do
				ring.fade(0.15)
			end
			for _, emitter in drawn do
				emitter.Enabled = false
			end
			task.delay(0.7, well.Destroy, well)
		end)
	elseif data.phase == "Burst" then
		local position = root.Position
		U.shockwave(position, WIND, 3, if full then 40 else 28, 0.6, Enum.Material.ForceField)
		U.ringBurst(CFrame.new(position - UP * 2.8), WIND_WHITE, 2, if full then 22 else 16, 0.5, 0.4)
		U.pillar(position - UP * 3, WIND, 4, if full then 40 else 26, 0.6, Enum.Material.ForceField, 0.3)
		U.burst(position, {
			color = WIND_WHITE,
			count = 40,
			size = 0.6,
			speed = NumberRange.new(40, 90),
			lifetime = NumberRange.new(0.3, 0.6),
			streaks = true,
			spread = 180,
		})
		if full then
			U.flash(position + UP * 3, STAR, 10, 0.3)
			twinkle(position + UP * 3, 16, STAR, 0.4)
			starDust(position + UP * 2, 30, 40)
		else
			twinkle(position + UP * 2, 10, WIND, 0.35)
		end
		local foot, head =
			worldAnchor(position - UP * 3, UP), worldAnchor(position + UP * (if full then 44 else 30), UP)
		local column = {
			softBeam(foot, head, {
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 8,
				width1 = 14,
				transparency = NumberSequence.new({ key(0, 0.8), key(0.15, 0.45), key(1, 1) }),
				texture = SMOKE,
				speed = 14,
				length = 14,
			}),
			softBeam(foot, head, {
				color = ColorSequence.new(STAR_WHITE, if full then STAR else WIND_WHITE),
				width0 = 2.5,
				width1 = 4,
				transparency = NumberSequence.new({ key(0, 0.6), key(0.15, 0.25), key(1, 1) }),
				texture = SPARKLE,
				wrap = true,
				length = 3,
				speed = 24,
			}),
		}
		for _, beam in column do
			U.tween(beam, 0.6, { Width0 = beam.Width0 * 0.2, Width1 = beam.Width1 * 0.2 })
		end
		fadeBeams(column, 0.6, { foot, head })
		windRing(position - UP * 2.6, UP, 2, if full then 30 else 22, 0.55)
		windRing(position, UP, 1, if full then 22 else 16, 0.45, WIND_WHITE)
		lightRing(position - UP * 2.7, UP, 1, if full then 26 else 18, 0.4, if full then STAR else WIND_WHITE)
		windPuff(position, 6)
		featherBurst(position + UP, if full then 22 else 14, 26)
		U.light(position, WIND, 6, 40, 0.8)
		if U.isLocal(character) then
			U.colorGrade({ Brightness = 0.15, Saturation = 0.3 }, 0, 0.1, 0.5)
			CameraShake.Add(0.35)
			CameraShake.FovKick(12)
		end
	elseif data.phase == "End" then
		gust(root.Position, 6)
		windRing(root.Position - UP * 2.6, UP, 1, 10, 0.4)
		featherBurst(root.Position + UP, 8, 14)
	end
end

function handlers.Awaken(data, character, root)
	transformation(data, character, root, false)
end

function handlers.Ascend(data, character, root)
	transformation(data, character, root, true)
end

local GRIMOIRE_COVER = Color3.fromRGB(28, 70, 58)
local GRIMOIRE_PAPER = Color3.fromRGB(226, 234, 214)

type Spike = { left: BasePart, right: BasePart, angle: number, height: number }
type Page = { part: BasePart, offset: CFrame, side: number }

local function buildLook(character: Model, full: boolean): () -> ()
	local torso = character:FindFirstChild("Torso") :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	local root = U.getRoot(character)
	if not torso or not head or not root then
		return function() end
	end
	local look: { hideSword: number, blade: BasePart? } = { hideSword = 0, blade = nil }
	looks[character] = look
	local entries: { { part: BasePart, base: number } } = {}
	local baseOf: { [BasePart]: number } = {}
	local function part(props: { [string]: any }, base: number, wedge: boolean?): BasePart
		local p: BasePart
		if wedge then
			p = Instance.new("WedgePart")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			for key, value in props do
				(p :: any)[key] = value
			end
			p.Parent = U.folder
		else
			p = U.newPart(props)
		end
		p.Transparency = 1
		table.insert(entries, { part = p, base = base })
		baseOf[p] = base
		return p
	end
	local sides = if full then { -1, 1 } else { -1 } -- -1: his left

	-- Wings (see Wings): beating slowly as he hovers, swept back into a
	-- glide as he moves.
	local wings: { Wings.Wing } = {}
	local emitters: { ParticleEmitter } = {}
	local wingTrails: { Trail } = {}
	local wingBeams: { Beam } = {}
	for _, side in sides do
		local wing = Wings.new(part, side)
		table.insert(wings, wing)
		for _, trail in wing.trails do
			table.insert(wingTrails, trail)
		end
		for _, beam in wing.beams do
			beam.Enabled = false -- (once the wing's in)
			table.insert(wingBeams, beam)
		end
		for _, emitter in wing.emitters do
			table.insert(emitters, emitter)
		end
	end
	local wingsStarted = false
	local phase = 0 -- how far through a beat (radians)
	local glide, gliding = 0, 0

	local spikes: { Spike } = {}
	local spikeCount = if full then 10 else 5
	for i = 1, spikeCount do
		local angle, height
		if full then
			angle = (i - 1) / spikeCount * math.pi * 2
			height = if i == 1 then 1 elseif i % 2 == 1 then 0.72 else 0.48
		else
			local f = (i - 1) / (spikeCount - 1)
			angle = -(0.1 + 0.8 * f) * math.pi
			height = 0.45 + 0.5 * math.sin(f * math.pi)
		end
		table.insert(spikes, {
			left = part({ Size = Vector3.new(0.06, height, 0.15), Color = STAR }, 0.02, true),
			right = part({ Size = Vector3.new(0.06, height, 0.15), Color = STAR }, 0.02, true),
			angle = angle,
			height = height,
		})
	end
	local bandCount = if full then 16 else 8
	local band = {}
	for _ = 1, bandCount do
		table.insert(band, part({ Size = Vector3.new(0.09, 0.14, 0.3), Color = STAR }, 0.05))
	end
	local gem = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.22, Color = WIND }, 0)

	local shells: { { part: BasePart, limb: BasePart, offset: CFrame } } = {}
	for _, side in sides do
		for _, name in { if side < 0 then "Left Arm" else "Right Arm", if side < 0 then "Left Leg" else "Right Leg" } do
			local limb = character:FindFirstChild(name) :: BasePart?
			if limb then
				table.insert(shells, {
					part = part({
						Size = limb.Size + Vector3.new(0.08, 0.08, 0.08),
						Color = WIND,
						Material = Enum.Material.ForceField,
					}, 0),
					limb = limb,
					offset = CFrame.identity,
				})
			end
		end
		table.insert(shells, {
			part = part({ Size = Vector3.new(1.06, 2.08, 1.08), Color = WIND, Material = Enum.Material.ForceField }, 0),
			limb = torso,
			offset = CFrame.new(side * 0.5, 0, 0),
		})
		local arm = character:FindFirstChild(if side < 0 then "Left Arm" else "Right Arm") :: BasePart?
		if arm then
			local wisp = Instance.new("ParticleEmitter")
			wisp.Texture = U.textures.Smoke
			wisp.Color = ColorSequence.new(WIND)
			wisp.LightEmission = 0.8
			wisp.LightInfluence = 0
			wisp.Size = NumberSequence.new(0.5, 0)
			wisp.Transparency = NumberSequence.new(0.5, 1)
			wisp.Lifetime = NumberRange.new(0.4, 0.7)
			wisp.Rate = 18
			wisp.Speed = NumberRange.new(0.5, 1.5)
			wisp.Acceleration = Vector3.new(0, 3, 0)
			wisp.Parent = arm
			table.insert(emitters, wisp)
		end
	end

	-- His grimoire: a dark green book with a four-leaf clover of light over
	-- its open pages.
	local book: { Page } = {}
	local function page(props: { [string]: any }, base: number, offset: CFrame, side: number)
		table.insert(book, { part = part(props, base), offset = offset, side = side })
	end
	page(
		{ Size = Vector3.new(1.1, 1.45, 0.08), Color = GRIMOIRE_COVER, Material = Enum.Material.Fabric },
		0,
		CFrame.new(-0.55, 0, 0),
		-1
	)
	page(
		{ Size = Vector3.new(1.1, 1.45, 0.08), Color = GRIMOIRE_COVER, Material = Enum.Material.Fabric },
		0,
		CFrame.new(0.55, 0, 0),
		1
	)
	page(
		{ Size = Vector3.new(1, 1.35, 0.12), Color = GRIMOIRE_PAPER, Material = Enum.Material.SmoothPlastic },
		0,
		CFrame.new(-0.5, 0, -0.08),
		-1
	)
	page(
		{ Size = Vector3.new(1, 1.35, 0.12), Color = GRIMOIRE_PAPER, Material = Enum.Material.SmoothPlastic },
		0,
		CFrame.new(0.5, 0, -0.08),
		1
	)
	page(
		{ Size = Vector3.new(0.14, 1.45, 0.14), Color = GRIMOIRE_COVER, Material = Enum.Material.Fabric },
		0,
		CFrame.new(0, 0, 0.02),
		0
	)
	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2 + math.pi / 4
		page(
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.3, Color = WIND },
			0.05,
			CFrame.new(math.cos(angle) * 0.17, 1.05 + math.sin(angle) * 0.17, -0.4),
			0
		)
	end
	page({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.14, Color = STAR }, 0, CFrame.new(0, 1.05, -0.4), 0)
	local bookLight = Instance.new("PointLight")
	bookLight.Color = WIND
	bookLight.Range = 8
	bookLight.Brightness = 1.5
	bookLight.Parent = book[#book].part

	-- The wind sword (Full-Crown), in his right hand (see Sword).
	local sword: Sword.Sword? = nil
	if full then
		local made = Sword.new(part)
		sword = made
		look.blade = made.blade
	end
	local swordShown = true

	-- Hovering: a ring of wind turning on the ground under him and a soft
	-- downdraft off his feet.
	local hoverRing = softRing({
		color = ColorSequence.new(WIND_WHITE, WIND),
		width0 = 0.9,
		width1 = 0.9,
		transparency = NumberSequence.new(0.6),
		texture = U.textures.Smoke,
		speed = 2,
		length = 4,
	})
	local draft = U.newPart({ Size = Vector3.new(1.6, 0.2, 1.6), Transparency = 1 })
	local downdraft = windEmitter(draft, {
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.2) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.78),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Bottom,
		Drag = 2,
		Rate = 14,
	})

	local start = os.clock()
	local last = start
	local faded = false
	local connection: RBXScriptConnection
	local function destroy()
		connection:Disconnect()
		if looks[character] == look then
			looks[character] = nil
		end
		hoverRing.fade(0.3)
		downdraft.Enabled = false
		for _, trail in wingTrails do
			trail.Enabled = false
		end
		Soft.fadeBeams(wingBeams, 0.3)
		if sword then
			for _, beam in sword.beams do
				beam.Enabled = false
			end
			for _, emitter in sword.emitters do
				emitter.Enabled = false
			end
		end
		task.delay(1, draft.Destroy, draft)
		for _, emitter in emitters do
			emitter.Enabled = false
			task.delay(1, emitter.Destroy, emitter)
		end
		local parts = {}
		for _, entry in entries do
			table.insert(parts, entry.part)
		end
		fadeOut(parts, 0.4)
	end
	connection = RunService.RenderStepped:Connect(function()
		if not torso.Parent or not head.Parent or not root.Parent then
			-- He's gone (died, left): the look goes with him.
			destroy()
			return
		end
		local now = os.clock()
		local t = now - start
		local dt = math.min(now - last, 0.1)
		last = now
		local alpha = math.min(t / 0.5, 1)
		local fading = not faded
		if fading then
			for _, entry in entries do
				entry.part.Transparency = 1 - (1 - entry.base) * alpha
			end
			if alpha >= 1 then
				faded = true
				for _, beam in wingBeams do
					beam.Enabled = true
				end
			end
		end
		hoverRing.set(
			CFrame.new(root.Position - UP * 2.95) * CFrame.Angles(0, t * 1.2, 0),
			(2.2 + 0.25 * math.sin(t * 2)) * alpha + 0.05
		)
		draft.CFrame = root.CFrame * CFrame.new(0, -1.1, 0)

		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		gliding += ((math.clamp((speed - 6) / 14, 0, 1) - glide) * 16 - gliding * 8) * dt
		glide += gliding * dt
		if glide <= 0 or glide >= 1 then
			glide = math.clamp(glide, 0, 1)
			gliding = 0
		end
		local hold = Wings.Blend(Wings.Hover, Wings.Glide, glide)
		phase = (phase + dt * hold.rate * math.pi * 2) % (math.pi * 2)
		for _, wing in wings do
			Wings.Place(wing, torso.CFrame, hold, phase, glide, t)
		end
		if not wingsStarted then
			-- (The tips are in place now: their trails start here.)
			wingsStarted = true
			for _, trail in wingTrails do
				Soft.beginTrail(trail)
			end
		end

		-- Crown.
		local crown = head.CFrame * CFrame.new(0, 0.3, 0)
		local function around(a: number): Vector3
			return Vector3.new(math.sin(a), 0, -math.cos(a))
		end
		local function along(a: number): Vector3
			return crown:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
		end
		for i, segment in band do
			local a = if full then (i - 0.5) / bandCount * math.pi * 2 else -((i - 0.5) / bandCount) * math.pi
			local position = crown * (around(a) * 0.66)
			segment.CFrame = CFrame.lookAt(position, position + along(a), crown.UpVector)
		end
		for _, spike in spikes do
			local center = crown * (around(spike.angle) * 0.66) + crown.UpVector * (spike.height / 2 + 0.05)
			local frame = CFrame.lookAt(center, center + along(spike.angle), crown.UpVector)
			local half = spike.left.Size.Z / 2
			spike.left.CFrame = frame * CFrame.new(0, 0, -half)
			spike.right.CFrame = frame * CFrame.new(0, 0, half) * CFrame.Angles(0, math.pi, 0)
		end
		gem.CFrame =
			CFrame.new(crown * ((if full then around(0) else around(-math.pi / 2)) * 0.7 + Vector3.new(0, 0.12, 0)))

		-- Mana.
		for _, shell in shells do
			if shell.limb.Parent then
				shell.part.CFrame = shell.limb.CFrame * shell.offset
			end
		end

		-- Grimoire: circling him, turned to keep its pages towards him.
		local orbit = t * 1.15
		local position = root.Position
			+ Vector3.new(math.cos(orbit) * 3, 1.3 + math.sin(t * 2.1) * 0.3, math.sin(orbit) * 3)
		local bookFrame = CFrame.lookAt(position, root.Position + UP * 1.3) * CFrame.Angles(rad(-15), 0, 0)
		local open = rad((62 + math.sin(t * 6) * 6) * alpha)
		for _, p in book do
			local hinge = CFrame.Angles(0, -p.side * open, 0)
			local spin = if p.side == 0 and p.offset.Y > 0.5
				then CFrame.new(0, 1.05, -0.4) * CFrame.Angles(0, 0, t * 1.5) * CFrame.new(0, -1.05, 0.4)
				else CFrame.identity
			p.part.CFrame = bookFrame * hinge * spin * p.offset
		end

		-- Sword (hidden while a move has it put away).
		if sword then
			local arm = character:FindFirstChild("Right Arm") :: BasePart?
			if arm then
				Sword.Place(sword, arm.CFrame * CFrame.new(0, -1.1, 0) * CFrame.Angles(rad(-90), 0, 0))
			end
			local hidden = now < look.hideSword
			if hidden and (swordShown or fading) then
				for _, p in sword.parts do
					p.Transparency = 1
				end
			elseif not hidden and not swordShown and not fading then
				for _, p in sword.parts do
					p.Transparency = baseOf[p]
				end
			end
			swordShown = not hidden
			for _, beam in sword.beams do
				beam.Enabled = not hidden and faded
			end
			for _, emitter in sword.emitters do
				emitter.Enabled = not hidden
			end
		end
	end)

	return function()
		if connection.Connected then
			destroy()
		end
	end
end

-- Spawn entrance

type Book = { place: (CFrame, number, number) -> (), fade: (number) -> () }

local function makeBook(): Book
	local pages: { { part: BasePart, offset: CFrame, side: number } } = {}
	local function page(props: { [string]: any }, offset: CFrame, side: number)
		table.insert(pages, { part = U.newPart(props), offset = offset, side = side })
	end
	local cover = Color3.fromRGB(28, 70, 58)
	local paper = Color3.fromRGB(226, 234, 214)
	page(
		{ Size = Vector3.new(1.1, 1.45, 0.08), Color = cover, Material = Enum.Material.Fabric },
		CFrame.new(-0.55, 0, 0),
		-1
	)
	page(
		{ Size = Vector3.new(1.1, 1.45, 0.08), Color = cover, Material = Enum.Material.Fabric },
		CFrame.new(0.55, 0, 0),
		1
	)
	page(
		{ Size = Vector3.new(1, 1.35, 0.12), Color = paper, Material = Enum.Material.SmoothPlastic },
		CFrame.new(-0.5, 0, -0.08),
		-1
	)
	page(
		{ Size = Vector3.new(1, 1.35, 0.12), Color = paper, Material = Enum.Material.SmoothPlastic },
		CFrame.new(0.5, 0, -0.08),
		1
	)
	page(
		{ Size = Vector3.new(0.14, 1.45, 0.14), Color = cover, Material = Enum.Material.Fabric },
		CFrame.new(0, 0, 0.02),
		0
	)
	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2 + math.pi / 4
		page(
			{ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.3, Color = WIND },
			CFrame.new(math.cos(angle) * 0.17, 1.05 + math.sin(angle) * 0.17, -0.4),
			0
		)
	end
	page({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.14, Color = STAR }, CFrame.new(0, 1.05, -0.4), 0)
	local light = Instance.new("PointLight")
	light.Color = WIND
	light.Range = 8
	light.Brightness = 2
	light.Parent = pages[#pages].part
	local book = {}
	function book.place(frame: CFrame, open: number, t: number)
		for _, p in pages do
			local hinge = CFrame.Angles(0, -p.side * rad(open), 0)
			local spin = if p.side == 0 and p.offset.Y > 0.5
				then CFrame.new(0, 1.05, -0.4) * CFrame.Angles(0, 0, t * 1.5) * CFrame.new(0, -1.05, 0.4)
				else CFrame.identity
			p.part.CFrame = frame * hinge * spin * p.offset
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
	local sylph = makeSprite(1.2)
	every(2.2, function(elapsed)
		if not root.Parent then
			return false
		end
		local forward = root.CFrame.LookVector
		local right = root.CFrame.RightVector
		local position, open
		if elapsed < 0.6 then
			local eased = 1 - (1 - elapsed / 0.6) ^ 2
			position = root.Position + forward * 2.5 + UP * (1.5 + 18 * (1 - eased)) + right * 6 * (1 - eased)
			open = 0
		elseif elapsed < 1.2 then
			local a = (elapsed - 0.6) / 0.6
			local angle = a * math.pi * 2
			position = root.Position + (forward * math.cos(angle) + right * math.sin(angle)) * 2.5 + UP * 1.5
			open = 70 * a
		else
			position = root.Position + forward * 2.2 + UP * (1.8 + math.min((elapsed - 1.2) * 2, 0.8))
			open = 70
		end
		book.place(CFrame.lookAt(position, root.Position + UP * 1.5) * CFrame.Angles(rad(-15), 0, 0), open, elapsed)
		if elapsed < 1.2 then
			local angle = elapsed * 7
			sylph.place(
				CFrame.new(
					root.Position
						+ Vector3.new(math.cos(angle) * 3.5, 1.5 + math.sin(elapsed * 9), math.sin(angle) * 3.5)
				),
				elapsed
			)
			inflow(root.Position, 7)
		end
		return true
	end, function()
		book.fade(0.3)
	end)
	U.spiral(root, WIND, 3, 6, 1.2, 3, 0.1, 0.4)
	task.delay(1.2, function()
		sylph.fade(0.15)
		if not root.Parent then
			return
		end
		local position = root.Position
		gust(position + UP, 8, UP)
		U.shockwave(position, WIND, 3, 20, 0.45, Enum.Material.ForceField)
		U.ringBurst(CFrame.new(position - UP * 2.8), WIND_WHITE, 2, 14, 0.4, 0.35)
		windRing(position - UP * 2.7, UP, 1, 16, 0.45)
		lightRing(position - UP * 2.75, UP, 1, 12, 0.35, WIND_WHITE)
		featherBurst(position + UP, 12, 18)
		twinkle(position + root.CFrame.LookVector * 2.2 + UP * 2, 7, STAR, 0.3)
		U.flash(position + root.CFrame.LookVector * 2.2 + UP * 2, STAR, 6, 0.25)
		U.light(position, WIND, 5, 26, 0.5)
		if U.isLocal(character) then
			CameraShake.Add(0.2)
			CameraShake.FovKick(8)
		end
	end)
end

return {
	looks = looks,
	hideSword = hideSword,
	buildLook = buildLook,
}
