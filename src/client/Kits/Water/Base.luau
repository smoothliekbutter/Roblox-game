local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local VFX = require(script.Parent.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Parent.Soft)

local U = VFX.Util
local UP = Vector3.yAxis

local Fx = require(script.Parent.Fx)
local Serpent = require(script.Parent.Serpent)

local ANIMS, handlers, play, bump, live, handOf = Fx.ANIMS, Fx.handlers, Fx.play, Fx.bump, Fx.live, Fx.handOf
local easeOut = Fx.easeOut
local WATER, WATER_LIGHT, FOAM = Fx.WATER, Fx.WATER_LIGHT, Fx.FOAM
local ripple, shine, spray, mist, glints, droplets = Fx.ripple, Fx.shine, Fx.spray, Fx.mist, Fx.glints, Fx.droplets
local crown, puddle, splash, bubbles = Fx.crown, Fx.puddle, Fx.splash, Fx.bubbles
local orb, stream, whirl = Fx.orb, Fx.stream, Fx.whirl
local every, key = Soft.every, Soft.key
local SMOKE = Soft.SMOKE

local function near(position: Vector3, distance: number): boolean
	return (workspace.CurrentCamera.CFrame.Position - position).Magnitude < distance
end

local function gather(target: Vector3, radius: number)
	local from = target + U.randomUnit() * radius
	local drop = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (0.25 + math.random() * 0.25),
		Color = if math.random() < 0.5 then WATER_LIGHT else FOAM,
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CFrame = CFrame.new(from),
	})
	U.tween(
		drop,
		0.24,
		{ CFrame = CFrame.new(target), Transparency = 0.8 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(0.26, drop.Destroy, drop)
end

local function crater(position: Vector3, radius: number)
	local ground = Fx.floorAt(position + UP * 2, 8)
	if not ground then
		return
	end
	U.groundRocks(ground.Position, math.floor(5 + radius), radius * 0.6, 0.6 + radius * 0.15)
	U.groundCracks(ground.Position, 8, radius * 1.2, WATER_LIGHT, 1.2)
	crown(ground.Position, radius * 0.6, radius * 1.1, 0.7, 16)
	puddle(ground.Position, radius * 1.2, 1.6)
end

type Held = { orbs: { [number]: Fx.Orb }, token: number }
local held: { [Model]: Held } = setmetatable({}, { __mode = "k" }) :: any
type Flight = { orb: Fx.Orb, done: boolean, position: Vector3 }
local flights: { [number]: Flight } = {}

local BALL_SPOTS = {
	{ side = 1.4, up = 1.4, radius = 1.5 },
	{ side = -1.4, up = 1.4, radius = 1.5 },
	{ side = 0, up = 2.4, radius = 2.5 },
}

local function heldSpot(root: BasePart, index: number, rise: number): CFrame
	local spot = BALL_SPOTS[index]
	local frame = root.CFrame
	return CFrame.new(
		frame.Position + frame.LookVector * 2.5 + frame.RightVector * spot.side + UP * (spot.up + 1.6 * (1 - rise))
	)
end

function handlers.Waterball(data, character, root)
	local phase = data.phase
	if phase == "Cast" then
		play(character, if data.airborne then ANIMS.WaterballAir else ANIMS.Waterball)
		local token = bump(character)
		local state: Held = { orbs = {}, token = token }
		held[character] = state
		for index, spot in BALL_SPOTS do
			state.orbs[index] = orb(spot.radius, 0.7, 0.35)
		end
		local delay: number = data.delay or 0.32
		local hold = delay + (data.gap or 0.18) * ((data.count or 3) - 1) + 0.1
		every(hold, function(elapsed)
			if not live(character, token) or held[character] ~= state then
				return false
			end
			local grow = easeOut(elapsed / delay)
			for index, ball in state.orbs do
				local swirl = CFrame.Angles(0, elapsed * 4 + index, 0)
				ball.place(heldSpot(root, index, grow) * swirl, 0.15 + 0.85 * grow)
			end
			if elapsed < delay then
				local spot = heldSpot(root, 1 + math.floor(elapsed * 30) % 3, grow).Position
				gather(spot, 4)
			end
			return true
		end)
		local feet = root.Position - UP * 2.8
		ripple(feet, UP, 1, 6, 0.5, 1)
		shine(feet, UP, 0.5, 5, 0.4)
		mist(feet + UP, 2, UP)
	elseif phase == "Throw" then
		local state = held[character]
		local index: number = data.index
		local ball = state and state.orbs[index]
		if state then
			state.orbs[index] = nil
		end
		local spot = BALL_SPOTS[index] or BALL_SPOTS[1]
		local flying = ball or orb(spot.radius, 0.7, 0.35)
		local origin: Vector3 = data.origin
		local direction: Vector3 = data.direction
		local flight: Flight = { orb = flying, done = false, position = origin }
		flights[data.id] = flight
		local trail =
			Soft.trail(flying.core, Vector3.new(0, spot.radius * 0.5, 0), Vector3.new(0, -spot.radius * 0.5, 0), {
				color = ColorSequence.new(FOAM, WATER),
				transparency = NumberSequence.new({ key(0, 0.3), key(1, 1) }),
				width = NumberSequence.new({ key(0, 1), key(1, 0.2) }),
				lifetime = 0.25,
			})
		local start = flying.core.Position
		every(data.range / data.speed + 0.2, function(elapsed)
			if flight.done then
				return false
			end
			local along = origin + direction * data.speed * elapsed
			local position = start:Lerp(along, easeOut(elapsed / 0.08))
			flight.position = position
			flying.place(CFrame.lookAt(position, position + direction) * CFrame.Angles(0, 0, elapsed * 12))
			return true
		end, function()
			flights[data.id] = nil
			Soft.endTrail(trail)
			flying.fade(0.1)
		end)
		local hand = handOf(character, if index == 2 then "Left" else "Right")
		if hand then
			spray(hand, 10, 26, direction, 30)
			shine(hand, direction, 0.3, if data.big then 4 else 2.6, 0.2)
		end
		ripple(origin, direction, spot.radius * 0.6, spot.radius * 2.2, 0.3, 0.8)
	elseif phase == "Splash" then
		local flight = flights[data.id]
		if flight then
			flight.done = true
		end
		local position: Vector3 = data.position
		if data.big then
			splash(position, 6)
			crater(position, 6)
			droplets(position, 16, 30, UP, 0.5)
			U.shockwave(position, WATER_LIGHT, 2, 12, 0.35, Enum.Material.ForceField)
			U.light(position, WATER, 5, 22, 0.4)
			if near(position, 45) then
				CameraShake.Add(0.2)
			end
		else
			splash(position, 3)
			glints(position, 8, 16)
		end
	elseif phase == "Cancel" then
		bump(character)
		local state = held[character]
		held[character] = nil
		if state then
			for _, ball in state.orbs do
				ball.fade(0.15)
			end
		end
	end
end

type Roar = { serpent: Serpent.Serpent, done: boolean, flying: boolean, frame: CFrame, stream: Fx.Stream? }
local roars: { [Model]: Roar } = setmetatable({}, { __mode = "k" }) :: any

function handlers.SeaDragonsRoar(data, character, root)
	local phase = data.phase
	if phase == "Cast" then
		play(character, if data.airborne then ANIMS.RoarAir else ANIMS.Roar)
		local token = bump(character)
		local serpent = Serpent.new(1, 9)
		local feed = stream(1.4, 10)
		local state: Roar = { serpent = serpent, done = false, flying = false, frame = root.CFrame, stream = feed }
		roars[character] = state
		local delay: number = data.delay or 0.55
		local feet = root.Position - UP * 2.8
		whirl(feet + UP * 0.1, UP, 6, delay + 0.2, 6)
		ripple(feet, UP, 1, 9, 0.6, 1.4)
		every(delay + 0.25, function(elapsed)
			if not live(character, token) or roars[character] ~= state or state.done or state.flying then
				return false
			end
			local frame = root.CFrame
			local center = frame.Position + UP * 7 + frame.LookVector * -0.5
			local w = elapsed * 9
			local radius = 2.6 * (1 - easeOut(elapsed / delay) * 0.6)
			local position = center + frame.RightVector * math.cos(w) * radius + frame.LookVector * math.sin(w) * radius
			local tangent = frame.RightVector * -math.sin(w) + frame.LookVector * math.cos(w)
			local settle = easeOut((elapsed - delay * 0.6) / (delay * 0.4))
			local facing = tangent:Lerp(frame.LookVector, settle)
			state.frame = CFrame.lookAt(position, position + facing + UP * 0.2 * (1 - settle))
			serpent.place(state.frame, 0.3 + 0.6 * settle)
			local hand = handOf(character, "Right") or root.Position + UP * 2
			feed.set(hand, position - UP * 1.5)
			if math.random() < 0.6 then
				gather(position, 5)
			end
			return true
		end, function()
			if roars[character] == state and state.stream then
				state.stream.fade(0.2)
				state.stream = nil
			end
		end)
		mist(root.Position + UP * 4, 3, UP)
	elseif phase == "Fire" then
		local state = roars[character]
		local serpent = if state then state.serpent else Serpent.new(1, 9)
		if not state then
			state = { serpent = serpent, done = false, flying = true, frame = CFrame.new(data.origin), stream = nil }
			roars[character] = state
		end
		local current = state :: Roar
		current.flying = true
		if current.stream then
			current.stream.fade(0.15)
			current.stream = nil
		end
		local origin: Vector3 = data.origin
		local direction: Vector3 = data.direction
		local from = current.frame.Position
		every(data.range / data.speed + 0.3, function(elapsed)
			if current.done then
				return false
			end
			local along = origin + direction * data.speed * elapsed
			local blend = easeOut(elapsed / 0.18)
			local position = (from + direction * data.speed * elapsed):Lerp(along, blend)
			current.frame = CFrame.lookAt(position, position + direction)
			serpent.place(current.frame, 0.85 + 0.15 * math.sin(elapsed * 14))
			local ground = Fx.floorAt(position, 10)
			if ground and math.random() < 0.35 then
				ripple(ground.Position + UP * 0.1, UP, 1, 5, 0.4, 0.8)
			end
			return true
		end, function()
			current.done = true
			serpent.fade(0.25)
		end)
		local hand = handOf(character, "Right") or origin
		spray(hand, 14, 30, direction, 30)
		shine(origin, direction, 1, 7, 0.3)
		ripple(origin, direction, 1, 8, 0.35, 1.2)
		U.flash(origin, FOAM, 5, 0.15)
		if U.isLocal(character) then
			CameraShake.Add(0.15)
			CameraShake.FovKick(5)
		end
	elseif phase == "Crash" then
		local state = roars[character]
		if state then
			state.done = true
		end
		local position: Vector3 = data.position
		local direction: Vector3 = data.direction
		splash(position, 8, -direction)
		droplets(position, 20, 34, UP, 0.6)
		U.shockwave(position, WATER_LIGHT, 3, 16, 0.4, Enum.Material.ForceField)
		U.impactSpikes(position, WATER, 10, 8, 0.28, FOAM)
		mist(position, 5)
		if Fx.floorAt(position, 6) then
			crater(position, 7)
		end
		U.light(position, WATER, 6, 30, 0.5)
		if near(position, 60) then
			CameraShake.Add(0.25)
		end
	elseif phase == "Cancel" then
		bump(character)
		local state = roars[character]
		roars[character] = nil
		if state then
			state.done = true
			state.serpent.fade(0.2)
			if state.stream then
				state.stream.fade(0.15)
			end
			splash(state.frame.Position, 4)
		end
	end
end

local charges: { [Model]: Fx.Orb } = setmetatable({}, { __mode = "k" }) :: any

function handlers.PointBlankRoar(data, character, root)
	local phase = data.phase
	if phase == "Cast" then
		play(character, if data.airborne then ANIMS.BlankAir else ANIMS.Blank)
		local token = bump(character)
		local ball = orb(0.8, 0.5, 0.3)
		charges[character] = ball
		local delay: number = data.delay or 0.25
		every(delay + 0.1, function(elapsed)
			if not live(character, token) or charges[character] ~= ball then
				return false
			end
			local hand = handOf(character, "Right") or root.Position
			ball.place(CFrame.new(hand) * CFrame.Angles(0, elapsed * 9, 0), 0.4 + 0.8 * easeOut(elapsed / delay))
			gather(hand, 3.5)
			return true
		end)
		local feet = root.Position - UP * 2.8
		ripple(feet, UP, 0.6, 5, 0.35, 0.9)
	elseif phase == "Blast" then
		local ball = charges[character]
		charges[character] = nil
		if ball then
			ball.fade(0.08)
		end
		local origin: Vector3 = data.origin
		local direction: Vector3 = data.direction
		local length: number = data.length or 14
		local hand = handOf(character, "Right") or origin
		local serpent = Serpent.new(0.9, 5)
		local surge = stream(3.2, 22)
		every(0.32, function(elapsed)
			local a = easeOut(elapsed / 0.16)
			local position = hand + direction * (length * 0.85) * a
			serpent.place(CFrame.lookAt(position, position + direction), 1)
			surge.set(hand, position)
			return true
		end, function()
			serpent.fade(0.18)
			surge.fade(0.2)
		end)
		local tip = origin + direction * length
		task.delay(0.16, function()
			splash(tip, 7, direction)
			droplets(tip, 18, 36, direction, 0.55)
			U.shockwave(tip, WATER_LIGHT, 2, 12, 0.3, Enum.Material.ForceField)
			U.impactSpikes(tip, WATER, 12, 9, 0.28, FOAM)
			ripple(tip, direction, 2, 12, 0.35, 2)
			U.light(tip, WATER, 6, 28, 0.4)
		end)
		spray(hand, 30, 70, direction, 22)
		mist(hand + direction * 4, 4, direction)
		shine(hand, direction, 0.5, 8, 0.25)
		ripple(hand, direction, 1, 9, 0.3, 1.6)
		U.flash(hand, FOAM, 6, 0.15)
		U.speedLines(root, direction, 0.25, WATER_LIGHT)
		if not data.airborne then
			local ground = Fx.floorAt(root.Position, 6)
			if ground then
				U.groove(
					ground.Position + direction * 2,
					ground.Position + Vector3.new(direction.X, 0, direction.Z).Unit * (length + 2),
					1.6,
					WATER_LIGHT,
					1.5,
					120
				)
			end
		end
		if U.isLocal(character) then
			CameraShake.Add(0.3)
			CameraShake.FovKick(9)
		elseif near(origin, 40) then
			CameraShake.Add(0.15)
		end
	elseif phase == "Cancel" then
		bump(character)
		local ball = charges[character]
		charges[character] = nil
		if ball then
			ball.fade(0.15)
		end
	end
end

type Dome = { ripple: (Vector3?) -> (), drop: () -> () }
local domes: { [Model]: Dome } = setmetatable({}, { __mode = "k" }) :: any

local function buildDome(root: BasePart, radius: number, duration: number): Dome
	local glass = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one,
		Color = WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.78,
	})
	local skin = U.newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one,
		Color = WATER_LIGHT,
		Material = Enum.Material.ForceField,
	})
	local bands: { Soft.Ring } = {}
	for i = 1, 3 do
		table.insert(
			bands,
			Soft.softRing({
				color = ColorSequence.new(FOAM, WATER_LIGHT),
				width0 = 1.2 - i * 0.2,
				width1 = 1.2 - i * 0.2,
				transparency = NumberSequence.new(0.45),
				texture = SMOKE,
				speed = if i % 2 == 0 then -3 else 3,
				length = 5,
			})
		)
	end
	type Pool = { arcs: { Soft.Arc }, yaw: number, lift: number, speed: number }
	local pools: { Pool } = {}
	for i = 1, 6 do
		local arcs: { Soft.Arc } = {}
		for _ = 1, 2 do
			table.insert(
				arcs,
				Soft.softArc({
					{
						color = ColorSequence.new(FOAM, WATER_LIGHT),
						width0 = 0.35,
						width1 = 0.06,
						transparency = NumberSequence.new({ key(0, 0.15), key(1, 0.9) }),
					},
					{
						color = ColorSequence.new(WATER_LIGHT, WATER),
						width0 = 0.9,
						width1 = 0.2,
						transparency = NumberSequence.new({ key(0, 0.5), key(1, 1) }),
						texture = SMOKE,
						speed = 3,
						length = 2,
					},
				})
			)
		end
		table.insert(pools, {
			arcs = arcs,
			yaw = (i - 1) / 6 * math.pi * 2 + (if i % 2 == 0 then 0.5 else 0),
			lift = if i % 2 == 0 then 0.55 else 0.3,
			speed = if i % 2 == 0 then 6 else -5,
		})
	end
	local well = U.newPart({ Size = Vector3.one * 0.2, Transparency = 1 })
	local fizz = bubbles(well, 30, 0.4)
	fizz.Shape = Enum.ParticleEmitterShape.Sphere
	fizz.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	local light = Instance.new("PointLight")
	light.Color = WATER
	light.Range = radius * 2
	light.Brightness = 1.5
	light.Parent = well
	local dropped = false
	local function center(): Vector3
		local ground = Fx.floorAt(root.Position, 8)
		return if ground then ground.Position else root.Position - UP * 3
	end
	every(duration + 0.1, function(elapsed)
		if dropped or not root.Parent then
			return false
		end
		local grow = easeOut(elapsed / 0.25)
		local r = radius * grow + 0.1
		local base = center()
		glass.Size = Vector3.one * r * 2
		glass.CFrame = CFrame.new(base)
		skin.Size = Vector3.one * (r * 2 + 0.3)
		skin.CFrame = glass.CFrame
		well.Size = Vector3.new(r * 1.6, r * 0.8, r * 1.6)
		well.CFrame = CFrame.new(base + UP * r * 0.4)
		for i, band in ipairs(bands) do
			local h = r * (0.25 + 0.27 * (i - 1))
			local ring = math.sqrt(math.max(r * r - h * h, 0.01))
			band.set(CFrame.new(base + UP * h) * CFrame.Angles(0, elapsed * (1.4 + i * 0.4), 0), ring + 0.1)
		end
		for _, pool in pools do
			local yaw = pool.yaw + elapsed * 0.6
			local normal = Vector3.new(
				math.cos(yaw) * math.cos(pool.lift * 1.6),
				math.sin(pool.lift * 1.6),
				math.sin(yaw) * math.cos(pool.lift * 1.6)
			)
			local spot = base + normal * (r + 0.15)
			local frame = Fx.flatFrame(spot, normal)
			for j, arc in pool.arcs do
				local from = elapsed * pool.speed + j * math.pi
				arc.set(spot, frame.RightVector, frame.LookVector, (1.5 - (j - 1) * 0.6) * grow, from, from + 2.2)
			end
		end
		return true
	end)
	local dome = {}
	function dome.ripple(from: Vector3?)
		local base = center()
		local toward = if from then from - base else root.CFrame.LookVector
		local flat = Vector3.new(toward.X, math.max(toward.Y, radius * 0.3), toward.Z)
		local normal = if flat.Magnitude > 1e-3 then flat.Unit else UP
		local spot = base + normal * radius
		ripple(spot, normal, 0.5, 5, 0.35, 1.2)
		shine(spot, normal, 0.3, 4, 0.25)
		spray(spot, 14, 26, normal, 50)
		U.flash(spot, FOAM, 4, 0.12)
		whirl(spot, normal, 2.5, 0.5, 9)
	end
	function dome.drop()
		if dropped then
			return
		end
		dropped = true
		local base = glass.Position
		local r = glass.Size.X / 2
		fizz.Enabled = false
		light.Enabled = false
		for _, band in bands do
			band.fade(0.2)
		end
		for _, pool in pools do
			for _, arc in pool.arcs do
				arc.fade(0.2)
			end
		end
		every(0.3, function(elapsed)
			local a = easeOut(elapsed / 0.3)
			glass.Size = Vector3.new(r * 2 * (1 + 0.15 * a), r * 2 * (1 - a), r * 2 * (1 + 0.15 * a))
			skin.Size = glass.Size + Vector3.one * 0.3
			return true
		end, function()
			glass:Destroy()
			skin:Destroy()
		end)
		U.tween(glass, 0.3, { Transparency = 1 })
		U.tween(skin, 0.3, { Transparency = 1 })
		crown(base, r * 0.95, 4, 0.7, 20)
		ripple(base + UP * 0.2, UP, r * 0.8, r * 1.7, 0.6, 1.6)
		mist(base + UP * 2, 4, UP)
		droplets(base + UP * r * 0.6, 14, 18, UP, 0.5)
		task.delay(1, well.Destroy, well)
	end
	task.delay(duration + 0.3, dome.drop)
	return dome
end

function handlers.SeaDragonsNest(data, character, root)
	local phase = data.phase
	if phase == "Raise" then
		play(character, ANIMS.Nest)
		local old = domes[character]
		if old then
			old.drop()
		end
		local radius: number = data.radius or 9
		domes[character] = buildDome(root, radius, data.duration or 2.5)
		local feet = root.Position - UP * 2.8
		crown(feet, radius * 0.9, 5, 0.5, 18)
		ripple(feet + UP * 0.1, UP, 1, radius + 2, 0.5, 1.6)
		shine(feet + UP * 0.1, UP, 1, radius, 0.4)
		spray(feet, 24, 34, UP, 70)
		U.light(root.Position, WATER, 4, 24, 0.5)
	elseif phase == "Block" then
		local dome = domes[character]
		if dome then
			dome.ripple(data.from)
		end
		if U.isLocal(character) then
			CameraShake.Add(0.1)
		end
	elseif phase == "Drop" then
		local dome = domes[character]
		domes[character] = nil
		if dome then
			dome.drop()
		end
	end
end

local cradles: { [Model]: { orb: Fx.Orb, done: boolean } } = setmetatable({}, { __mode = "k" }) :: any

function handlers.SeaDragonsCradle(data, character, root)
	local phase = data.phase
	if phase == "Form" then
		play(character, ANIMS.Cradle)
		local token = bump(character)
		local sphere = orb(3.3, 0.88, 0.6)
		local state = { orb = sphere, done = false }
		cradles[character] = state
		local duration: number = data.duration or 0.8
		local wake = Soft.trail(sphere.core, Vector3.new(0, 1.6, 0), Vector3.new(0, -1.6, 0), {
			color = ColorSequence.new(FOAM, WATER),
			transparency = NumberSequence.new({ key(0, 0.45), key(1, 1) }),
			width = NumberSequence.new({ key(0, 1), key(1, 0.3) }),
			lifetime = 0.35,
			texture = SMOKE,
		})
		every(duration + 0.25, function(elapsed)
			if state.done or not live(character, token) then
				return false
			end
			local grow = easeOut(elapsed / 0.15)
			sphere.place(
				CFrame.new(root.Position + UP * 0.3) * CFrame.Angles(elapsed * 5, elapsed * 2, 0),
				0.3 + 0.7 * grow
			)
			local ground = Fx.floorAt(root.Position, 8)
			if ground and math.random() < 0.3 then
				ripple(ground.Position + UP * 0.1, UP, 1, 4.5, 0.4, 0.8)
			end
			return true
		end, function()
			Soft.endTrail(wake)
			if not state.done then
				state.done = true
				sphere.fade(0.15)
			end
		end)
		splash(root.Position - UP * 2, 4)
		mist(root.Position, 3)
		U.flash(root.Position, FOAM, 6, 0.15)
	elseif phase == "Burst" or phase == "Fizzle" then
		local state = cradles[character]
		cradles[character] = nil
		if state and not state.done then
			state.done = true
			state.orb.fade(0.08)
		end
		if phase == "Burst" then
			local position: Vector3 = data.position or root.Position
			splash(position, 7)
			droplets(position, 18, 30, UP, 0.5)
			U.shockwave(position, WATER_LIGHT, 2, 12, 0.3, Enum.Material.ForceField)
			shine(position, UP, 1, 9, 0.3)
			if U.isLocal(character) then
				CameraShake.Add(0.12)
			end
		end
	end
end

return {
	near = near,
	gather = gather,
	crater = crater,
}
