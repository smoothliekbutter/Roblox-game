local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local VFX = require(script.Parent.Parent.Parent.VFX)
local Hawk = require(script.Parent.Hawk)
local Soft = require(script.Parent.Parent.Parent.Soft)

local U = VFX.Util
local rad = math.rad
local UP = Vector3.yAxis

local WIND, WIND_WHITE = Soft.WIND, Soft.WIND_WHITE
local STAR, STAR_WHITE = Soft.STAR, Soft.STAR_WHITE
local SMOKE, SPARKLE = Soft.SMOKE, Soft.SPARKLE
local every, fadeOut, key = Soft.every, Soft.fadeOut, Soft.key
local bar, newWedge = Soft.bar, Soft.newWedge
local inflow, gust = Soft.inflow, Soft.gust
local arcPoints, arcParts, poseArc = Soft.arcPoints, Soft.arcParts, Soft.poseArc
local worldAnchor, softBeam, fadeBeams, softRing = Soft.worldAnchor, Soft.softBeam, Soft.fadeBeams, Soft.softRing
local windRing, lightRing, windEmitter, windPuff = Soft.windRing, Soft.lightRing, Soft.windEmitter, Soft.windPuff
local windSlash, twinkle, starDust = Soft.windSlash, Soft.twinkle, Soft.starDust

local Fx = require(script.Parent.Fx)
local ANIMS, handlers, play, bump, live, handOf = Fx.ANIMS, Fx.handlers, Fx.play, Fx.bump, Fx.live, Fx.handOf
local easeOut, featherBurst = Fx.easeOut, Fx.featherBurst

type Twister = { cyclone: (delay: number) -> (), burst: (cyclone: boolean) -> (), stop: () -> () }
local twisters: { [Model]: Twister } = {}

local function featherIn(target: Vector3, radius: number)
	local from = target + U.randomUnit() * radius
	local feather = newWedge({
		Size = Vector3.new(0.05, 0.28, 0.9),
		Color = WIND_WHITE,
		Material = Enum.Material.ForceField,
		Transparency = 0.15,
		CFrame = CFrame.new(from) * U.randomAngles(),
	})
	U.tween(
		feather,
		0.22,
		{ CFrame = CFrame.new(target) * U.randomAngles(), Transparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(0.25, feather.Destroy, feather)
end

local function featherDrift(position: Vector3, count: number)
	for _ = 1, count do
		local start = position + U.randomUnit() * 2.5
		local feather = newWedge({
			Size = Vector3.new(0.05, 0.28, 0.9),
			Color = WIND_WHITE,
			Material = Enum.Material.ForceField,
			Transparency = 0.15,
			CFrame = CFrame.new(start),
		})
		local life = 1 + math.random() * 0.6
		local turn = (math.random() - 0.5) * 3
		local seed = math.random() * math.pi * 2
		every(life, function(elapsed)
			local drift =
				Vector3.new(math.sin(elapsed * 4 + seed) * 0.8, -elapsed * 2.2, math.cos(elapsed * 3 + seed) * 0.5)
			feather.CFrame = CFrame.new(start + drift)
				* CFrame.Angles(math.sin(elapsed * 5 + seed) * 0.6, seed + elapsed * turn, math.cos(elapsed * 4) * 0.5)
			feather.Transparency = 0.15 + 0.85 * (elapsed / life) ^ 2
			return true
		end, function()
			feather:Destroy()
		end)
	end
end

local function fallingBlade(target: Vector3, formDelay: number, fallAt: number, alive: () -> boolean)
	local start = target + Vector3.new(math.random(-30, 30) / 10, 20 + math.random() * 6, math.random(-30, 30) / 10)
	local cframe = CFrame.lookAt(start, target) * CFrame.Angles(0, 0, math.random() * math.pi)
	local blade = U.newPart({ Size = Vector3.new(0.08, 0.5, 2.4), Color = WIND_WHITE, Transparency = 1 })
	local parts: { BasePart } = {
		blade,
		newWedge({ Size = Vector3.new(0.08, 0.25, 1.1), Color = WIND_WHITE, Transparency = 1 }),
		newWedge({ Size = Vector3.new(0.08, 0.25, 1.1), Color = WIND_WHITE, Transparency = 1 }),
		U.newPart({ Size = Vector3.new(0.04, 1.3, 4), Color = WIND, Transparency = 1 }),
	}
	local offsets = {
		CFrame.identity,
		CFrame.new(0, 0.125, -1.75),
		CFrame.new(0, -0.125, -1.75) * CFrame.Angles(0, 0, math.pi),
		CFrame.new(0, 0, -0.3),
	}
	local shown = { 0.05, 0.05, 0.05, 0.6 }
	for i, part in parts do
		part.CFrame = cframe * offsets[i]
	end
	local trails = {
		Soft.trail(blade, Vector3.new(0, 0.25, 1.2), Vector3.new(0, -0.25, 1.2), {
			color = ColorSequence.new(WIND_WHITE, WIND),
			transparency = NumberSequence.new(0.2, 1),
			lifetime = 0.12,
		}),
		Soft.trail(blade, Vector3.new(0, 0.9, 1.2), Vector3.new(0, -0.9, 1.2), {
			color = ColorSequence.new(WIND_WHITE, WIND),
			transparency = NumberSequence.new({ key(0, 0.55), key(1, 1) }),
			width = NumberSequence.new({ key(0, 1), key(1, 0.3) }),
			lifetime = 0.25,
			texture = SMOKE,
		}),
	}
	task.delay(formDelay, function()
		for i, part in parts do
			U.tween(part, 0.2, { Transparency = shown[i] })
		end
		if alive() then
			twinkle(start, 1.4, WIND, 0.2)
		end
	end)
	task.delay(fallAt, function()
		if not alive() then
			for _, trail in trails do
				Soft.endTrail(trail)
			end
			fadeOut(parts, 0.15)
			return
		end
		local drop = target - start
		for _, part in parts do
			U.tween(part, 0.14, { CFrame = part.CFrame + drop }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.delay(0.14, function()
			for _, trail in trails do
				Soft.endTrail(trail)
			end
			for i, part in parts do
				if i == 1 then
					Soft.linger(part, 0, 0.4)
				else
					part:Destroy()
				end
			end
			U.burst(target, {
				color = WIND_WHITE,
				count = 5,
				size = 0.35,
				speed = NumberRange.new(10, 22),
				lifetime = NumberRange.new(0.12, 0.25),
				streaks = true,
				spread = 70,
			})
			local across = cframe.UpVector
			across = Vector3.new(across.X, 0, across.Z)
			across = if across.Magnitude > 0.1 then across.Unit else Vector3.xAxis
			U.groove(target - across * 0.9, target + across * 0.9, 0.3, WIND_WHITE, 1.2)
			windPuff(target + UP * 0.3, 1.2, UP)
			lightRing(target + UP * 0.15, UP, 0.3, 2.6, 0.22, WIND_WHITE)
			U.ringBurst(CFrame.new(target + UP * 0.1), WIND, 0.4, 2.4, 0.22, 0.08)
			U.flash(target + UP * 0.3, WIND_WHITE, 1.6, 0.1)
		end)
	end)
end

local showers: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

function handlers.WindBladesShower(data, character, root)
	if data.phase == "Cast" then
		play(character, ANIMS.Shower)
		local cyclone = data.cyclone == true
		local twist = twisters[character]
		if cyclone and twist then
			twist.cyclone(data.delay)
		end
		local id = (showers[character] or 0) + 1
		showers[character] = id
		local function alive(): boolean
			return showers[character] == id and character.Parent ~= nil
		end
		local center: Vector3 = data.center
		local radius: number = data.radius
		local delay: number = data.delay
		local length = delay + data.waves * data.gap
		local start = os.clock()
		local sky = center + UP * 22
		local marks = {
			softRing({
				color = ColorSequence.new(WIND_WHITE),
				width0 = 0.25,
				width1 = 0.25,
				transparency = NumberSequence.new(0.35),
			}),
			softRing({
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 1.2,
				width1 = 1.2,
				transparency = NumberSequence.new(0.65),
				texture = SMOKE,
				speed = 2,
				length = 4,
			}),
			softRing({
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 2.8,
				width1 = 2.8,
				transparency = NumberSequence.new(0.5),
				texture = SMOKE,
				speed = 3,
				length = 6,
			}),
			softRing({
				color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
				width0 = 0.9,
				width1 = 0.9,
				transparency = NumberSequence.new(0.4),
				texture = SPARKLE,
				wrap = true,
				length = 1.5,
				speed = 2,
			}),
			softRing({
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 1.6,
				width1 = 1.6,
				transparency = NumberSequence.new(0.6),
				texture = SMOKE,
				speed = -2,
				length = 5,
			}),
		}
		local cloud =
			U.newPart({ Size = Vector3.new(radius * 2, 1, radius * 2), Transparency = 1, CFrame = CFrame.new(sky) })
		local pour = windEmitter(cloud, {
			Size = NumberSequence.new({ key(0, 2), key(1, 4.5) }),
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(14, 22),
			SpreadAngle = Vector2.new(6, 6),
			EmissionDirection = Enum.NormalId.Bottom,
			Shape = Enum.ParticleEmitterShape.Disc,
			Rate = 30,
		})
		local glitter = windEmitter(cloud, {
			Texture = SPARKLE,
			Color = ColorSequence.new(WIND_WHITE, WIND),
			LightEmission = 1,
			Transparency = NumberSequence.new({ key(0, 0.3), key(1, 1) }),
			Size = NumberSequence.new({ key(0, 0.4), key(1, 0) }),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(16, 26),
			SpreadAngle = Vector2.new(5, 5),
			EmissionDirection = Enum.NormalId.Bottom,
			Shape = Enum.ParticleEmitterShape.Disc,
			Rate = 25,
		})
		every(length + 0.2, function(elapsed)
			if not alive() then
				return false
			end
			local open = easeOut(elapsed / 0.3)
			marks[1].set(CFrame.new(center + UP * 0.15) * CFrame.Angles(0, elapsed * 0.6, 0), radius * open + 0.05)
			marks[2].set(
				CFrame.new(center + UP * 0.2) * CFrame.Angles(0, -elapsed * 1.4, 0),
				radius * 0.9 * open + 0.05
			)
			marks[3].set(CFrame.new(sky) * CFrame.Angles(0, elapsed * 2.2, 0), (radius + 2) * open + 0.05)
			marks[4].set(CFrame.new(sky - UP * 0.4) * CFrame.Angles(0, -elapsed * 1.6, 0), (radius + 0.5) * open + 0.05)
			marks[5].set(CFrame.new(sky + UP * 0.6) * CFrame.Angles(0, elapsed * 3, 0), radius * 0.55 * open + 0.05)
			return true
		end, function()
			for _, ring in marks do
				ring.fade(0.3)
			end
			pour.Enabled = false
			glitter.Enabled = false
			task.delay(1.2, cloud.Destroy, cloud)
		end)
		windRing(sky, UP, 1, radius + 4, 0.4)
		U.light(sky, WIND, 3, radius * 3, length)
		local pouring = Soft.helix(function()
			return sky, center + UP * 0.5
		end, radius * 0.8, 4, 0.55, 1.4, 0.55, length, WIND)
		task.spawn(function()
			while alive() and os.clock() - start < length do
				task.wait(0.05)
			end
			pouring()
		end)
		local hand = handOf(character, "Right")
		if hand then
			gust(hand, 3, UP)
		end
		every(delay, function()
			local palm = handOf(character, "Right")
			if not alive() or not palm then
				return false
			end
			inflow(palm, 5)
			return true
		end)
		local spread = if cyclone then 3.5 else radius
		for wave = 1, data.waves do
			for _ = 1, 3 do
				local angle = math.random() * math.pi * 2
				local spot = center
					+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * spread * math.sqrt(math.random())
				fallingBlade(spot, math.random() * delay * 0.6, delay + (wave - 1) * data.gap, alive)
			end
		end
		task.delay(length, function()
			if not alive() then
				return
			end
			gust(center + UP, 6, UP)
			windRing(center + UP * 0.3, UP, 1, radius + 5, 0.45)
			lightRing(center + UP * 0.2, UP, 1, radius + 3, 0.35, WIND_WHITE)
			U.groundCracks(center, 6, radius * 0.7, WIND, 1)
			U.impactSpikes(center + UP * 1.5, WIND, 12, 9, 0.28, STAR_WHITE)
			U.dustWave(center, radius + 3)
			featherBurst(center + UP, 10, 16)
			local foot, top = worldAnchor(center, UP), worldAnchor(center + UP * 16, UP)
			fadeBeams({
				softBeam(foot, top, {
					color = ColorSequence.new(WIND_WHITE, WIND),
					width0 = radius * 0.9,
					width1 = radius * 1.3,
					transparency = NumberSequence.new({ key(0, 0.85), key(0.2, 0.55), key(1, 1) }),
					texture = SMOKE,
					speed = 10,
					length = 8,
				}),
			}, 0.5, { foot, top })
			if (workspace.CurrentCamera.CFrame.Position - center).Magnitude < 40 then
				CameraShake.Add(0.12)
			end
		end)
	elseif data.phase == "Cancel" then
		showers[character] = (showers[character] or 0) + 1
	end
end

local hawks: { [Model]: { done: boolean, position: Vector3, direction: Vector3 } } = {}

function handlers.SwiftWhiteHawk(data, character, root)
	if data.phase == "Cast" then
		play(character, ANIMS.Hawk)
		local hand = handOf(character, "Right")
		if hand then
			for _ = 1, 6 do
				inflow(hand, 4)
			end
			twinkle(hand, 2, WIND, 0.2)
		end
		for i = 0, 7 do
			task.delay(i * 0.025, function()
				local palm = handOf(character, "Right")
				if palm then
					featherIn(palm, 3.5)
				end
			end)
		end
	elseif data.phase == "Fly" then
		local direction: Vector3 = data.direction
		local state = { done = false, position = data.origin :: Vector3, direction = direction }
		hawks[character] = state
		local target: Model? = data.target
		local hawk = Hawk.new(CFrame.lookAt(state.position, state.position + direction))
		local glow = Soft.glow(hawk.body, WIND, 4.5, 0.86)
		local light = Instance.new("PointLight")
		light.Color = WIND
		light.Range = 14
		light.Brightness = 3
		light.Parent = hawk.body
		local travelled = 0
		local beat = 0
		local bank = 0
		every(data.range / data.speed + 0.3, function(_, dt)
			if state.done then
				return false
			end
			local before = direction
			local targetRoot = target and U.getRoot(target)
			if targetRoot then
				local want = (targetRoot.Position - state.position).Unit
				local angle = math.acos(math.clamp(direction:Dot(want), -1, 1))
				if angle > 1e-3 then
					direction = direction:Lerp(want, math.min(1, data.turn * dt / angle)).Unit
				end
			end
			state.direction = direction
			local step = data.speed * dt
			state.position += direction * step
			travelled += step
			local turning = if dt > 0 then before:Cross(direction).Y / dt else 0
			bank += (math.clamp(turning * 0.35, -0.9, 0.9) - bank) * math.min(dt * 10, 1)
			beat += dt * 22
			Hawk.Place(hawk, CFrame.lookAt(state.position, state.position + direction), beat, bank)
			return travelled < data.range
		end, function()
			hawks[character] = nil
			glow.Enabled = false
			light.Enabled = false
			Hawk.Release(hawk, 0.12)
		end)
		local hand = handOf(character, "Right")
		if hand then
			U.flash(hand, WIND_WHITE, 2.6, 0.12)
			gust(hand, 3, direction)
			windRing(hand, direction, 0.4, 4, 0.25)
			lightRing(hand, direction, 0.2, 2.6, 0.18, WIND_WHITE)
			featherBurst(hand, 6, 9)
		end
	elseif data.phase == "Burst" then
		local state = hawks[character]
		local direction = if state then state.direction else root.CFrame.LookVector
		if state then
			state.done = true
		end
		local position: Vector3 = data.position
		if data.fade then
			gust(position, 3)
			featherBurst(position, 6, 10)
			featherDrift(position, 3)
			return
		end
		U.flash(position, WIND_WHITE, 5, 0.12)
		U.impactSpikes(position, WIND, 10, 7, 0.26, STAR_WHITE)
		twinkle(position, 4, WIND, 0.25)
		gust(position, 7)
		U.shockwave(position, WIND, 2, 9, 0.3)
		windRing(position, direction, 1, 9, 0.3)
		task.delay(0.05, windRing, position, direction, 0.5, 6, 0.28)
		lightRing(position, direction, 0.5, 6, 0.22, WIND_WHITE)
		windPuff(position, 3, direction)
		featherBurst(position, 14, 18)
		featherDrift(position, 7)
		U.burst(position, {
			color = WIND,
			count = 18,
			size = 0.6,
			speed = NumberRange.new(20, 40),
			lifetime = NumberRange.new(0.25, 0.5),
			spread = 180,
			drag = 3,
		})
		Soft.helix(function()
			return position - UP * 1.5, position + UP * 2.5
		end, 2.2, 3, 0.3, 1.2, 0.45, 0.4, WIND)
		U.light(position, WIND, 5, 16, 0.3)
		if (workspace.CurrentCamera.CFrame.Position - position).Magnitude < 30 then
			CameraShake.Add(0.15)
		end
	end
end

function handlers.HeavenlyWindArk(data, character, root)
	if data.phase == "Cast" then
		play(character, if data.airborne then ANIMS.AirArk else ANIMS.Ark)
	elseif data.phase == "Carry" then
		for _, target in data.targets do
			local targetRoot = U.getRoot(target)
			if targetRoot then
				U.spiral(targetRoot, WIND, 2.5, 6, data.rise, 3, 0.12, 0.3)
				U.bodyTrail(target, WIND, 0.35)
			end
		end
		U.spiral(root, WIND_WHITE, 2.5, 6, 0.4, 2, 0.1, 0.3)
		U.bodyTrail(character, WIND, 0.35)
	elseif data.phase == "Rise" then
		local forward: Vector3 = data.direction
		local right = forward:Cross(UP).Unit
		local air = data.airborne == true
		local center = data.origin + forward * 5.5 + (if air then UP * -2 else UP * -3)
		local from, to = if air then math.pi * 1.05 else -0.05, if air then math.pi * 1.95 else math.pi * 1.05
		local points = arcPoints(center, right, UP, 6, from, to, 12)
		local outer = arcParts(points, 0.9, WIND, 0.45)
		local inner = arcParts(points, 0.3, WIND_WHITE, 0.05)
		local shift = if air then UP * -8 else UP * 9
		for _, part in outer do
			U.tween(part, 0.45, { CFrame = part.CFrame + shift, Transparency = 1 })
		end
		for _, part in inner do
			U.tween(part, 0.4, { CFrame = part.CFrame + shift, Transparency = 1 })
		end
		task.delay(0.5, function()
			for _, part in outer do
				part:Destroy()
			end
			for _, part in inner do
				part:Destroy()
			end
		end)
		local crescent = windSlash(points[1], points[#points], (if air then -UP else UP) * 6, 1.3, 0.08)
		crescent.move(shift, 0.45)
		task.delay(0.15, crescent.fade, 0.35)
		task.delay(0.05, function()
			local echo = windSlash(points[1], points[#points], (if air then -UP else UP) * 5, 0.8, 0.08)
			echo.move(shift * 0.8, 0.45)
			task.delay(0.1, echo.fade, 0.3)
		end)
		U.impactSpikes(center + (if air then -UP else UP) * 1.5, WIND, 10, 8, 0.26, STAR_WHITE)
		if air then
			U.burst(center, {
				color = WIND_WHITE,
				count = 20,
				size = 0.5,
				speed = NumberRange.new(30, 60),
				lifetime = NumberRange.new(0.2, 0.4),
				streaks = true,
				spread = 30,
				direction = -UP,
			})
			windRing(center, UP, 1, 10, 0.35)
			windPuff(center, 3, -UP)
			local below = U.groundBelow(center, { character }, 16)
			if below then
				local at = below.Position
				task.delay(0.12, function()
					U.flash(at + UP, WIND_WHITE, 6, 0.14)
					windRing(at + UP * 0.3, UP, 1, 12, 0.4)
					lightRing(at + UP * 0.2, UP, 0.5, 9, 0.3, WIND_WHITE)
					U.dustWave(at, 10)
					U.groundCracks(at, 6, 5, WIND, 1)
					U.debris(at, 8, 34, 0.7)
					gust(at + UP, 5, UP)
				end)
			end
		else
			U.pillar(center, WIND, 3.5, 14, 0.4, Enum.Material.ForceField, 0.3)
			local foot, head = worldAnchor(center, UP), worldAnchor(center + UP * 16, UP)
			local column = {
				softBeam(foot, head, {
					color = ColorSequence.new(WIND_WHITE, WIND),
					width0 = 7,
					width1 = 9,
					transparency = NumberSequence.new({ key(0, 0.85), key(0.2, 0.5), key(1, 1) }),
					texture = SMOKE,
					speed = 8,
					length = 8,
				}),
				softBeam(foot, head, {
					color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
					width0 = 1.4,
					width1 = 0.6,
					transparency = NumberSequence.new({ key(0, 0.5), key(0.2, 0.25), key(1, 1) }),
				}),
			}
			fadeBeams(column, 0.45, { foot, head })
			U.burst(center, {
				color = WIND_WHITE,
				count = 24,
				size = 0.5,
				speed = NumberRange.new(35, 70),
				lifetime = NumberRange.new(0.2, 0.45),
				streaks = true,
				spread = 25,
				direction = UP,
			})
			windRing(center + UP * 0.3, UP, 1, 11, 0.4)
			lightRing(center + UP * 0.2, UP, 0.5, 8, 0.3, WIND_WHITE)
			windPuff(center + UP, 3, UP)
			U.groundCracks(center, 4, 5, WIND, 0.8)
			U.debris(center, 6, 30, 0.6)
			U.dustWave(center, 10)
			featherBurst(center + UP * 2, 8, 14)
			Soft.helix(function()
				return center, center + UP * 16
			end, 4.5, 3, 0.35, 1.2, 0.7, 0.45, WIND)
		end
		U.light(center, WIND, 4, 18, 0.35)
		if U.isLocal(character) then
			CameraShake.Add(0.14)
			CameraShake.FovKick(5)
		end
	end
end

type Arrow = { place: (CFrame) -> (), destroy: (number) -> () }

local function makeArrow(scale: number): Arrow
	local s = scale
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local function add(part: BasePart, offset: CFrame)
		table.insert(parts, part)
		table.insert(offsets, offset)
	end
	add(U.newPart({ Size = Vector3.new(0.12, 0.12, 3.4) * s, Color = WIND_WHITE }), CFrame.identity)
	add(
		U.newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.6, 0.5, 0.5) * s,
			Color = WIND,
			Material = Enum.Material.ForceField,
		}),
		CFrame.Angles(0, rad(90), 0)
	)
	for blade = 0, 1 do
		local turn = CFrame.Angles(0, 0, blade * math.pi / 2)
		local color = if blade == 0 then WIND_WHITE else STAR
		add(
			newWedge({ Size = Vector3.new(0.06, 0.28, 0.9) * s, Color = color }),
			turn * CFrame.new(0, 0.14 * s, -2.15 * s)
		)
		add(
			newWedge({ Size = Vector3.new(0.06, 0.28, 0.9) * s, Color = color }),
			turn * CFrame.new(0, -0.14 * s, -2.15 * s) * CFrame.Angles(0, 0, math.pi)
		)
	end
	for fin = 0, 2 do
		add(
			newWedge({ Size = Vector3.new(0.04, 0.36, 0.8) * s, Color = WIND, Transparency = 0.15 }),
			CFrame.Angles(0, 0, fin * math.pi * 2 / 3) * CFrame.new(0, 0.22 * s, 1.35 * s)
		)
	end
	local glow =
		U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7 * s, Color = STAR, Transparency = 0.45 })
	add(glow, CFrame.new(0, 0, -1.75 * s))
	local light = Instance.new("PointLight")
	light.Color = WIND
	light.Range = 8 * s
	light.Brightness = 2
	light.Parent = glow
	local trails = {
		Soft.trail(parts[1], Vector3.new(0, 0.18 * s, 1.6 * s), Vector3.new(0, -0.18 * s, 1.6 * s), {
			color = ColorSequence.new(WIND_WHITE, WIND),
			transparency = NumberSequence.new(0.15, 1),
			lifetime = 0.2,
			off = true,
		}),
		Soft.trail(parts[1], Vector3.new(0, 0.7 * s, 1.6 * s), Vector3.new(0, -0.7 * s, 1.6 * s), {
			color = ColorSequence.new(WIND_WHITE, WIND),
			transparency = NumberSequence.new({ key(0, 0.5), key(1, 1) }),
			width = NumberSequence.new({ key(0, 0.6), key(0.3, 1), key(1, 0.2) }),
			lifetime = 0.4,
			texture = SMOKE,
			off = true,
		}),
	}
	local glitter = windEmitter(glow, {
		Texture = SPARKLE,
		Color = ColorSequence.new(STAR_WHITE, STAR),
		LightEmission = 1,
		Transparency = NumberSequence.new({ key(0, 0.25), key(1, 1) }),
		Size = NumberSequence.new({ key(0, 0.35 * s), key(1, 0) }),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(0.5, 2),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 30,
	})
	local placed = false
	local arrow = {}
	function arrow.place(frame: CFrame)
		for i, part in parts do
			part.CFrame = frame * offsets[i]
		end
		if not placed then
			placed = true
			for _, trail in trails do
				Soft.beginTrail(trail)
			end
		end
	end
	function arrow.destroy(duration: number)
		for _, trail in trails do
			Soft.endTrail(trail)
		end
		glitter.Enabled = false
		light.Enabled = false
		local rest = {}
		for i, part in parts do
			if i ~= 1 and part ~= glow then
				table.insert(rest, part)
			end
		end
		fadeOut(rest, duration)
		Soft.linger(parts[1], duration, 0.55)
		Soft.linger(glow, duration, 0.5)
	end
	return arrow
end

local function arrowStrike(position: Vector3, direction: Vector3, scale: number)
	U.flash(position, WIND_WHITE, 2 * scale, 0.12)
	U.impactRing(position, direction, WIND_WHITE, 0.4, 2.6 * scale, 0.22)
	windRing(position, direction, 0.5, 4 * scale, 0.28)
	lightRing(position, direction, 0.3, 3 * scale, 0.2, WIND_WHITE)
	windPuff(position, 1.5 * scale, -direction)
	twinkle(position, 2.5 * scale, STAR, 0.2)
	gust(position, 2 + 2 * scale, -direction)
end

local function fly(
	origin: Vector3,
	direction: Vector3,
	speed: number,
	range: number,
	place: (Vector3, number) -> (),
	strike: (Vector3) -> (),
	done: () -> ()
)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { U.folder }
	local position = origin
	local travelled = 0
	place(position, 0)
	every(range / speed + 0.1, function(elapsed, dt)
		local step = speed * dt
		local wall = workspace:Raycast(position, direction * step, params)
		local model = wall and wall.Instance:FindFirstAncestorWhichIsA("Model")
		if wall and not (model and model:FindFirstChildOfClass("Humanoid")) then
			strike(wall.Position)
			return false
		end
		position += direction * step
		travelled += step
		place(position, elapsed)
		return travelled < range
	end, done)
end

local function flyingArrow(
	origin: Vector3,
	direction: Vector3,
	speed: number,
	range: number,
	scale: number,
	drawn: Arrow?
)
	local arrow = drawn or makeArrow(scale)
	fly(origin, direction, speed, range, function(position, elapsed)
		arrow.place(CFrame.lookAt(position, position + direction) * CFrame.Angles(0, 0, elapsed * 14))
	end, function(position)
		arrowStrike(position, direction, scale)
	end, function()
		arrow.destroy(0.12)
	end)
end

type Bow = {
	stop: () -> (),
	nocked: Arrow?,
	scale: number,
	ends: number,
	charging: number?,
	glow: BasePart?,
	well: BasePart?,
}

local function bowArc(): Soft.Arc
	return Soft.softArc({
		{
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 1.1,
			width1 = 1.1,
			transparency = NumberSequence.new({ key(0, 0.9), key(0.5, 0.5), key(1, 0.9) }),
			texture = SMOKE,
			speed = 3,
			length = 3,
		},
		{
			color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
			width0 = 0.5,
			width1 = 0.5,
			transparency = NumberSequence.new({ key(0, 0.8), key(0.5, 0.35), key(1, 0.8) }),
			texture = SPARKLE,
			wrap = true,
			length = 0.8,
			speed = 2,
		},
	})
end
local bows: { [Model]: Bow } = {}

function handlers.GaleWhiteBow(data, character, root)
	if data.phase == "Draw" then
		play(character, ANIMS.Bow)
		local token = bump(character)
		local length = data.draw + data.arrows * data.gap + 0.25
		local segments = 10
		local limbs = arcParts(table.create(segments + 1, Vector3.zero), 0.22, WIND, 0.2)
		local core = arcParts(table.create(segments + 1, Vector3.zero), 0.08, WIND_WHITE, 0)
		local strings = { bar(Vector3.zero, UP, 0.05, WIND_WHITE, 0.2), bar(Vector3.zero, UP, 0.05, WIND_WHITE, 0.2) }
		local soft = bowArc()
		local tips: { BasePart } = {}
		for i = 1, 4 do
			local long = i % 2 == 1
			local feather = U.newPart({
				Size = Vector3.new(0.05, if long then 0.34 else 0.28, if long then 1.15 else 0.8),
				Color = if long then WIND_WHITE else WIND,
				Transparency = if long then 0.2 else 0.3,
			})
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = feather
			table.insert(tips, feather)
		end
		local all = table.clone(limbs)
		table.move(core, 1, #core, #all + 1, all)
		table.move(strings, 1, 2, #all + 1, all)
		table.move(tips, 1, #tips, #all + 1, all)
		local bow: Bow = {
			stop = function() end,
			nocked = makeArrow(1),
			scale = 1,
			ends = os.clock() + length,
		}
		function bow.stop()
			bows[character] = nil
			fadeOut(all, 0.2)
			soft.fade(0.2)
			if bow.nocked then
				bow.nocked.destroy(0.15)
				bow.nocked = nil
			end
			if bow.glow then
				fadeOut({ bow.glow }, 0.1)
				bow.glow = nil
			end
			if bow.well then
				local well = bow.well
				bow.well = nil
				for _, child in well:GetChildren() do
					if child:IsA("ParticleEmitter") then
						child.Enabled = false
					end
				end
				task.delay(0.6, well.Destroy, well)
			end
		end
		bows[character] = bow
		every(length + 2, function(elapsed)
			local hand = handOf(character, "Left")
			local pull = handOf(character, "Right")
			if not live(character, token) or not hand or not pull or not root.Parent or os.clock() > bow.ends then
				return false
			end
			local forward = root.CFrame.LookVector
			local right = forward:Cross(UP).Unit
			local grow = math.min(elapsed / 0.2, 1)
			local charge = if bow.charging then math.min((os.clock() - bow.charging) / 0.6, 1) else 0
			local radius = (3.4 + 1.4 * charge) * grow + 0.1
			local center = hand + forward * (2.2 - radius)
			local points = arcPoints(center, forward, UP, radius, -1.1, 1.1, segments)
			poseArc(limbs, points)
			poseArc(core, points)
			soft.set(center, forward, UP, radius, -1.1, 1.1)
			for i, feather in tips do
				local top = i <= 2
				local long = i % 2 == 1
				local tip = if top then points[#points] else points[1]
				local before = if top then points[#points - 1] else points[2]
				local out = (tip - before).Unit
				local along = (out + forward * (if long then 0.35 else -0.2)).Unit
				local length = (if long then 1.15 else 0.8) * grow + 0.05
				feather.Size = Vector3.new(0.05, (if long then 0.34 else 0.28) * grow + 0.02, length)
				feather.CFrame = CFrame.fromMatrix(tip + along * (length / 2 - 0.1), right, (-along):Cross(right))
			end
			local nock = pull + right * 0.1
			strings[1].Size = Vector3.new(0.05, 0.05, (points[1] - nock).Magnitude)
			strings[1].CFrame = CFrame.lookAt(points[1]:Lerp(nock, 0.5), nock)
			strings[2].Size = Vector3.new(0.05, 0.05, (points[#points] - nock).Magnitude)
			strings[2].CFrame = CFrame.lookAt(points[#points]:Lerp(nock, 0.5), nock)
			if bow.nocked then
				local frame = CFrame.lookAt(nock, nock + forward) * CFrame.new(0, 0, -1.6 * bow.scale)
				bow.nocked.place(frame * CFrame.Angles(0, 0, charge * elapsed * 6))
				if bow.glow then
					local head = (frame * CFrame.new(0, 0, -2.3 * bow.scale)).Position
					bow.glow.Size = Vector3.one * (0.8 + 2.6 * charge) * (1 + 0.1 * math.sin(elapsed * 30))
					bow.glow.CFrame = CFrame.new(head)
					if bow.well then
						bow.well.CFrame = CFrame.new(head)
					end
					inflow(head, 5 + 2 * charge)
				end
			end
			return true
		end, function()
			if bows[character] == bow then
				bow.stop()
			end
		end)
	elseif data.phase == "Arrow" then
		local origin: Vector3 = data.origin
		local direction: Vector3 = data.direction
		local bow = bows[character]
		local nocked = if bow and not data.last then bow.nocked else nil
		if bow and nocked then
			bow.nocked = nil
			task.delay(0.06, function()
				if bows[character] == bow and not bow.nocked then
					bow.nocked = makeArrow(1)
				end
			end)
		elseif bow and bow.nocked then
			bow.nocked.destroy(0.05)
			bow.nocked = nil
		end
		flyingArrow(origin, direction, data.speed, data.range, if data.last then 1.4 else 1, nocked)
		U.impactSpikes(origin, WIND, if data.last then 10 else 6, if data.last then 6 else 3.5, 0.18, STAR_WHITE)
		gust(origin, if data.last then 4 else 2, direction)
		U.impactRing(origin, direction, WIND_WHITE, 0.4, if data.last then 4 else 2.4, 0.18)
		windRing(origin, direction, 0.4, if data.last then 5 else 3, 0.22)
		twinkle(origin, if data.last then 3 else 1.8, WIND, 0.16)
		if U.isLocal(character) then
			CameraShake.FovKick(if data.last then 5 else 2)
		end
	elseif data.phase == "Charge" then
		local bow = bows[character]
		if bow then
			if bow.nocked then
				bow.nocked.destroy(0.05)
			end
			bow.nocked = makeArrow(1.8)
			bow.scale = 1.8
			bow.charging = os.clock()
			bow.ends = os.clock() + data.max + 0.6
			bow.glow = U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = WIND, Transparency = 0.55 })
			local well = U.newPart({
				Size = Vector3.one * 7,
				Transparency = 1,
				CFrame = CFrame.new(handOf(character, "Right") or root.Position),
			})
			windEmitter(well, {
				Texture = SPARKLE,
				Color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
				LightEmission = 1,
				Transparency = NumberSequence.new({ key(0, 1), key(0.3, 0.2), key(1, 0.6) }),
				Size = NumberSequence.new({ key(0, 0.5), key(1, 0.1) }),
				Lifetime = NumberRange.new(0.35, 0.45),
				Speed = NumberRange.new(8, 10),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				Rate = 45,
			})
			windEmitter(well, {
				Size = NumberSequence.new({ key(0, 2.5), key(1, 0.5) }),
				Lifetime = NumberRange.new(0.35, 0.45),
				Speed = NumberRange.new(8, 10),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				Rate = 20,
			})
			bow.well = well
		end
		local pull = handOf(character, "Right")
		if pull then
			gust(pull, 3)
		end
		if U.isLocal(character) then
			CameraShake.Add(0.05)
		end
	elseif data.phase == "Great" then
		local origin: Vector3 = data.origin
		local direction: Vector3 = data.direction
		local bow = bows[character]
		local drawn = if bow then bow.nocked else nil
		if bow then
			bow.nocked = nil
			bow.stop()
		end
		flyingArrow(origin, direction, data.speed, data.range, 1.8, drawn)
		U.flash(origin, WIND_WHITE, 7, 0.18)
		U.impactSpikes(origin, WIND, 14, 11, 0.3, STAR_WHITE)
		Soft.helix(function()
			return origin, origin + direction * 40
		end, 1.6, 3, 0.22, 3, 0.5, 0.4, WIND)
		for i = 1, 7 do
			local at = origin + direction * (4 + i * 6)
			task.delay((4 + i * 6) / data.speed, function()
				local below = U.groundBelow(at, { character }, 6)
				if below then
					windPuff(below.Position + UP * 0.5, 2, UP)
					U.burst(below.Position, {
						texture = SMOKE,
						color = Color3.fromRGB(190, 198, 188),
						count = 3,
						size = 2.5,
						speed = NumberRange.new(6, 12),
						lifetime = NumberRange.new(0.4, 0.7),
						lightEmission = 0,
						transparency = 0.5,
						spread = 50,
						direction = UP,
						drag = 3,
					})
				end
			end)
		end
		twinkle(origin, 7, STAR, 0.3)
		gust(origin, 7, direction)
		U.shockwave(origin, WIND, 2, 12, 0.3)
		for i = 0, 3 do
			task.delay(i * 0.03, U.impactRing, origin + direction * i * 3, direction, WIND_WHITE, 1, 7 - i, 0.28)
		end
		for i = 0, 5 do
			task.delay(i * 0.035, function()
				local at = origin + direction * (4 + i * 6)
				windRing(at, direction, 1, 8 - i * 0.6, 0.35)
				lightRing(at, direction, 0.5, 6 - i * 0.5, 0.25, WIND_WHITE)
			end)
		end
		local a0, a1 = worldAnchor(origin, direction), worldAnchor(origin + direction * 40, direction)
		fadeBeams({
			softBeam(a0, a1, {
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 5,
				width1 = 1,
				transparency = NumberSequence.new({ key(0, 0.4), key(1, 1) }),
				texture = SMOKE,
				speed = 12,
				length = 10,
			}),
		}, 0.5, { a0, a1 })
		windPuff(origin, 4, -direction)
		U.light(origin, WIND, 6, 28, 0.35)
		if U.isLocal(character) then
			CameraShake.Add(0.2)
			CameraShake.FovKick(9)
		end
		task.delay(0.2, function()
			if PoseAnimator.Current(character) == ANIMS.Bow then
				PoseAnimator.FadeOut(character, 0.25)
			end
		end)
	elseif data.phase == "Cancel" then
		bump(character)
		local bow = bows[character]
		if bow then
			bow.stop()
		end
	end
end

local TWISTER_HEIGHT = 14
local TWISTER_RINGS = 8
local TWISTER_LIFE = 9
local DUST = Color3.fromRGB(176, 192, 178)

local function funnelRadius(f: number, wide: number): number
	return (1 + 5 * f ^ 1.4) * wide
end

local function twister(ground: Vector3): Twister
	local start = os.clock()
	local wide = 1
	local cycloneAt: number? = nil
	local done = false
	local rings = {}
	for i = 1, TWISTER_RINGS do
		local f = (i - 1) / (TWISTER_RINGS - 1)
		local bright = i % 2 == 0
		local ring = softRing(if bright
			then {
				color = ColorSequence.new(WIND_WHITE),
				width0 = 0.18,
				width1 = 0.18,
				transparency = NumberSequence.new(0.35),
			}
			else {
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 1 + f * 1.6,
				width1 = 1 + f * 1.6,
				transparency = NumberSequence.new(0.5),
				texture = SMOKE,
				speed = 4,
				length = 4,
			})
		table.insert(rings, { ring = ring, f = f, spin = (if bright then 5 else 3.4) + f * 2 })
	end
	local foot, top = worldAnchor(ground, UP), worldAnchor(ground + UP * TWISTER_HEIGHT, UP)
	local core = softBeam(foot, top, {
		color = ColorSequence.new(WIND_WHITE, WIND),
		width0 = 1.6,
		width1 = 5,
		transparency = NumberSequence.new({ key(0, 0.8), key(0.3, 0.62), key(1, 0.9) }),
		texture = SMOKE,
		speed = 14,
		length = 7,
	})
	local base = U.newPart({ Size = Vector3.new(4, 0.2, 4), Transparency = 1, CFrame = CFrame.new(ground) })
	local dust = windEmitter(base, {
		Color = ColorSequence.new(DUST),
		Size = NumberSequence.new({ key(0, 1.5), key(1, 4) }),
		Transparency = NumberSequence.new({ key(0, 1), key(0.2, 0.6), key(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = UP * 8,
		Rate = 40,
	})
	local glow = Instance.new("PointLight")
	glow.Color = WIND
	glow.Range = 16
	glow.Brightness = 1.6
	glow.Parent = base
	local rocks: { BasePart } = {}
	for _ = 1, 6 do
		table.insert(
			rocks,
			U.newPart({
				Size = Vector3.new(0.4, 0.3, 0.5) * (1 + math.random()),
				Color = Color3.fromRGB(92, 86, 78),
				Material = Enum.Material.Slate,
				Transparency = 0,
			})
		)
	end
	local feathers: { BasePart } = {}
	for _ = 1, 5 do
		table.insert(
			feathers,
			newWedge({
				Size = Vector3.new(0.05, 0.3, 1),
				Color = WIND_WHITE,
				Material = Enum.Material.ForceField,
				Transparency = 0.1,
			})
		)
	end
	local blades: { BasePart } = {}
	type Runner = { part: BasePart, trail: Trail, phase: number }
	local runners: { [number]: Runner } = {}
	local function sway(f: number, t: number): Vector3
		return Vector3.new(math.sin(t * 1.3 + f * 2.2), 0, math.cos(t * 1.1 + f * 2.2)) * 0.7 * f
	end

	local function clear(duration: number)
		done = true
		for _, entry in rings do
			entry.ring.fade(duration)
		end
		fadeBeams({ core }, duration, { foot, top })
		dust.Enabled = false
		glow.Enabled = false
		task.delay(1.2, base.Destroy, base)
		for _, runner in runners do
			Soft.endTrail(runner.trail)
			task.delay(0.5, runner.part.Destroy, runner.part)
		end
		table.clear(runners)
	end

	every(TWISTER_LIFE, function(elapsed)
		if done then
			return false
		end
		local rise = easeOut(elapsed / 0.35)
		if cycloneAt and elapsed >= cycloneAt then
			wide = math.min(wide + 0.04, 1.35)
		end
		local height = TWISTER_HEIGHT * rise
		for _, entry in rings do
			local f = entry.f
			local center = ground + UP * (height * f + 0.2) + sway(f, elapsed)
			entry.ring.set(
				CFrame.new(center) * CFrame.Angles(math.sin(elapsed * 2 + f * 4) * 0.08, elapsed * entry.spin, 0),
				funnelRadius(f, wide) * rise + 0.05
			)
		end
		Soft.aim(top, ground + UP * height + sway(1, elapsed), UP)
		for i = 1, 4 do
			local phase = (elapsed * 0.9 + (i - 1) / 4) % 1
			local angle = elapsed * 7 + i * math.pi / 2 + phase * math.pi * 4
			local r = funnelRadius(phase, wide) * 0.85
			local position = ground
				+ UP * (height * phase)
				+ sway(phase, elapsed)
				+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * r
			local runner = runners[i]
			if runner and phase < runner.phase then
				Soft.endTrail(runner.trail)
				task.delay(0.4, runner.part.Destroy, runner.part)
				runner = nil
				runners[i] = nil
			end
			if runner then
				runner.part.CFrame = CFrame.new(position)
				runner.phase = phase
			else
				local part = U.newPart({ Size = Vector3.one * 0.1, Transparency = 1, CFrame = CFrame.new(position) })
				runners[i] = {
					part = part,
					trail = Soft.trail(part, Vector3.new(0, 0.35, 0), Vector3.new(0, -0.35, 0), {
						color = ColorSequence.new(if i % 2 == 0 then WIND_WHITE else WIND, WIND),
						transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) }),
						width = NumberSequence.new({ key(0, 1), key(1, 0.2) }),
						lifetime = 0.3,
					}),
					phase = phase,
				}
			end
		end
		for i, rock in rocks do
			local angle = elapsed * (6 + i % 3) + i * 1.7
			local r = 2.2 + (i % 3) * 0.9
			rock.CFrame = CFrame.new(ground + UP * (0.8 + (i % 4) * 0.9 + math.sin(elapsed * 3 + i) * 0.4))
				* CFrame.new(math.cos(angle) * r, 0, math.sin(angle) * r)
				* CFrame.Angles(elapsed * 5 + i, elapsed * 3, 0)
		end
		for i, feather in feathers do
			local f = 0.25 + i * 0.13
			local angle = -elapsed * 5 + i * 1.3
			local r = funnelRadius(f, wide) * 0.9
			local at = ground + UP * (height * f) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * r
			feather.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(angle), 0.3, math.cos(angle)))
		end
		for i, blade in blades do
			local f = (i - 0.5) / #blades
			local angle = elapsed * 9 + i * (math.pi * 2 / #blades) * 3
			local r = funnelRadius(f, wide) * 0.75
			local at = ground + UP * (height * f * 0.92 + 0.6) + sway(f, elapsed)
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			blade.CFrame = CFrame.lookAt(at + out * r, at + out * r + out:Cross(UP)) * CFrame.Angles(0, 0, rad(70))
		end
		if math.random() < 0.35 then
			inflow(ground + UP * 0.5, 10 * wide, WIND_WHITE)
		end
		return true
	end, function()
		if not done then
			clear(0.4)
			fadeOut(rocks, 0.3)
			fadeOut(feathers, 0.3)
			fadeOut(blades, 0.3)
		end
	end)

	local twist = {}
	function twist.cyclone(delay: number)
		if cycloneAt then
			return
		end
		cycloneAt = os.clock() - start + delay
		task.delay(delay, function()
			if done then
				return
			end
			for _ = 1, 9 do
				local blade = U.newPart({
					Size = Vector3.new(0.12, 0.08, 2.6),
					Color = WIND_WHITE,
					Transparency = 0.05,
				})
				local sheen = Soft.glow(blade, WIND, 2.4, 0.55)
				sheen.Rate = 30
				table.insert(blades, blade)
			end
			core.Color = ColorSequence.new(STAR_WHITE, WIND)
			glow.Brightness = 3
			U.flash(ground + UP * 6, WIND_WHITE, 9, 0.2)
			windRing(ground + UP * 0.3, UP, 2, 16, 0.4)
			twinkle(ground + UP * 8, 6, WIND_WHITE, 0.35)
		end)
	end
	function twist.burst(cyclone: boolean)
		if done then
			return
		end
		local mid = ground + UP * 6
		local k = if cyclone then 1.4 else 1
		clear(0.3)
		for _, entry in rings do
			local f = entry.f
			local frame = CFrame.new(ground + UP * (TWISTER_HEIGHT * f + 0.2))
			local from = funnelRadius(f, wide)
			every(0.3, function(elapsed)
				entry.ring.set(frame, from + (from * 2.2 + 4) * easeOut(elapsed / 0.3))
				return true
			end)
		end
		for _, rock in rocks do
			local out = (rock.Position - ground) * Vector3.new(1, 0, 1)
			local away = if out.Magnitude > 1e-3 then out.Unit else U.randomUnit()
			U.tween(rock, 0.5, { CFrame = rock.CFrame + away * 14 * k + UP * 6 * k })
		end
		fadeOut(rocks, 0.55)
		for _, feather in feathers do
			U.tween(feather, 0.45, { CFrame = feather.CFrame + U.randomUnit() * 10 })
		end
		fadeOut(feathers, 0.45)
		for _, blade in blades do
			local out = (blade.Position - ground) * Vector3.new(1, 0, 1)
			local away = if out.Magnitude > 1e-3 then out.Unit else U.randomUnit()
			U.tween(blade, 0.3, { CFrame = blade.CFrame + away * 18 + UP * 4 })
		end
		fadeOut(blades, 0.35)
		gust(mid, 6 * k, UP)
		windRing(ground + UP * 0.3, UP, 2, 14 * k, 0.45)
		lightRing(ground + UP * 0.2, UP, 1, 11 * k, 0.35, WIND_WHITE)
		U.pillar(ground, WIND, 3 * k, 22 * k, 0.5, Enum.Material.ForceField, 0.35)
		U.dustWave(ground, 10 * k)
		featherBurst(mid, if cyclone then 14 else 8, 18)
		U.light(mid, WIND, 5 * k, 26 * k, 0.4)
		if cyclone then
			U.impactSpikes(mid, WIND, 14, 12, 0.32, STAR_WHITE)
			U.flash(mid, WIND_WHITE, 14, 0.25)
			starDust(mid, 24, 34)
			U.groundCracks(ground, 8, 7, WIND, 1.4)
		end
		if (workspace.CurrentCamera.CFrame.Position - ground).Magnitude < 45 then
			CameraShake.Add(if cyclone then 0.3 else 0.15)
		end
	end
	function twist.stop()
		if not done then
			clear(0.35)
			fadeOut(rocks, 0.3)
			fadeOut(feathers, 0.3)
			fadeOut(blades, 0.3)
		end
	end
	return twist
end

function handlers.TornadoFang(data, character, root)
	local phase = data.phase
	if phase == "Cast" then
		play(character, if data.airborne then ANIMS.TornadoAir else ANIMS.Tornado)
		local hand = handOf(character, "Right")
		if hand then
			for _ = 1, 5 do
				inflow(hand, 4)
			end
		end
		task.delay(0.28, function()
			local palm = handOf(character, "Right")
			if palm then
				gust(palm, 2.5, root.CFrame.LookVector)
				windPuff(palm, 1.6, root.CFrame.LookVector)
			end
		end)
	elseif phase == "Form" then
		local old = twisters[character]
		if old then
			old.stop()
		end
		local ground: Vector3 = data.ground
		twisters[character] = twister(ground)
		local hand = handOf(character, "Right") or root.Position
		local a0, a1 = worldAnchor(hand, ground - hand), worldAnchor(ground + UP * 2, ground - hand)
		fadeBeams({
			softBeam(a0, a1, {
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 1.2,
				width1 = 3.5,
				transparency = NumberSequence.new({ key(0, 0.5), key(1, 0.8) }),
				texture = SMOKE,
				speed = 12,
				length = 5,
			}),
		}, 0.35, { a0, a1 })
		windRing(ground + UP * 0.3, UP, 1, 9, 0.4)
		lightRing(ground + UP * 0.2, UP, 0.5, 6, 0.3, WIND_WHITE)
		U.dustWave(ground, 6)
		windPuff(ground + UP, 3, UP)
	elseif phase == "Burst" then
		local twist = twisters[character]
		twisters[character] = nil
		if twist then
			twist.burst(data.cyclone == true)
		end
	elseif phase == "Fizzle" or phase == "Cancel" then
		local twist = twisters[character]
		twisters[character] = nil
		if twist then
			twist.stop()
		end
		if phase == "Cancel" then
			local current = PoseAnimator.Current(character)
			if current == ANIMS.Tornado or current == ANIMS.TornadoAir then
				PoseAnimator.FadeOut(character, 0.15)
			end
		end
	end
end

return {
	makeArrow = makeArrow,
	flyingArrow = flyingArrow,
	bowArc = bowArc,
}
