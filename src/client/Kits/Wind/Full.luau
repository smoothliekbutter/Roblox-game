local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local VFX = require(script.Parent.Parent.Parent.VFX)
local Saint = require(script.Parent.Saint)
local Soft = require(script.Parent.Parent.Parent.Soft)
local Waltz = require(script.Parent.Waltz)

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
local worldAnchor, softBeam, fadeBeams = Soft.worldAnchor, Soft.softBeam, Soft.fadeBeams
local windRing, lightRing, windEmitter, windPuff = Soft.windRing, Soft.lightRing, Soft.windEmitter, Soft.windPuff
local windSlash, twinkle, starDust = Soft.windSlash, Soft.twinkle, Soft.starDust

local Fx = require(script.Parent.Fx)
local ANIMS, handlers, play, bump, live, handOf = Fx.ANIMS, Fx.handlers, Fx.play, Fx.bump, Fx.live, Fx.handOf
local Base = require(script.Parent.Base)
local makeArrow, flyingArrow, bowArc = Base.makeArrow, Base.flyingArrow, Base.bowArc
local Look = require(script.Parent.Look)
local looks, hideSword = Look.looks, Look.hideSword

local EUROS_SCALE = 3.6
function handlers.SpiritOfEuros(data, character, root)
	if data.phase == "Draw" then
		play(character, ANIMS.EurosDraw)
		local token = bump(character)
		hideSword(character, data.duration + 0.4)
		local segments = 12
		local limbs = arcParts(table.create(segments + 1, Vector3.zero), 0.24, WIND, 0.15)
		local arrow = makeArrow(EUROS_SCALE)
		local charge = U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = WIND, Transparency = 0.6 })
		local all = table.clone(limbs)
		table.insert(all, charge)
		local soft = bowArc()
		local well = U.newPart({
			Size = Vector3.one * 12,
			Transparency = 1,
			CFrame = CFrame.new(handOf(character, "Left") or root.Position),
		})
		local drawn = {
			windEmitter(well, {
				Texture = SPARKLE,
				Color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
				LightEmission = 1,
				Transparency = NumberSequence.new({ key(0, 1), key(0.3, 0.15), key(1, 0.6) }),
				Size = NumberSequence.new({ key(0, 0.7), key(1, 0.1) }),
				Lifetime = NumberRange.new(0.45, 0.55),
				Speed = NumberRange.new(11, 13),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				Rate = 55,
			}),
			windEmitter(well, {
				Size = NumberSequence.new({ key(0, 4), key(1, 1) }),
				Lifetime = NumberRange.new(0.45, 0.55),
				Speed = NumberRange.new(11, 13),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				Rate = 24,
			}),
		}
		local tail, head = root.Position, root.Position
		local stopHelix = Soft.helix(function()
			return tail, head
		end, 2.6, 3, 0.4, 2.5, 0.8, data.duration + 0.05)
		every(data.duration + 0.05, function(elapsed)
			local hand = handOf(character, "Left")
			local pull = handOf(character, "Right")
			if not live(character, token) or not hand or not pull then
				return false
			end
			local forward = root.CFrame.LookVector
			local center = hand - forward * 1.3
			local points = arcPoints(center, forward, UP, 3.6, -1.2, 1.2, segments)
			points[1] += forward * 0.7
			points[#points] += forward * 0.7
			poseArc(limbs, points)
			soft.set(center, forward, UP, 3.6, -1.2, 1.2)
			local tip = hand + forward * 1.6
			local frame = CFrame.lookAt(pull, tip) * CFrame.new(0, 0, -1.7 * EUROS_SCALE)
			arrow.place(frame * CFrame.Angles(0, 0, elapsed * 2))
			local point = (frame * CFrame.new(0, 0, -2.1 * EUROS_SCALE)).Position
			charge.Size = Vector3.one * (1 + 5 * math.min(elapsed / data.duration, 1))
			charge.CFrame = CFrame.new(point)
			well.CFrame = CFrame.new(point)
			tail, head = (frame * CFrame.new(0, 0, 1.6 * EUROS_SCALE)).Position, point
			inflow(point, 7)
			return true
		end, function()
			arrow.destroy(0.1)
			soft.fade(0.12)
			stopHelix()
			for _, emitter in drawn do
				emitter.Enabled = false
			end
			task.delay(0.6, well.Destroy, well)
			fadeOut(all, 0.1)
		end)
		windRing(root.Position - UP * 2.8, UP, 6, 1.5, data.duration)
	elseif data.phase == "Loose" then
		play(character, ANIMS.EurosLoose)
		bump(character)
		local origin: Vector3 = data.origin
		local direction: Vector3 = data.direction
		local finish = origin + direction * data.length
		flyingArrow(origin, direction, data.length / 0.08, data.length, EUROS_SCALE)
		local line = bar(origin, finish, 0.6, WIND_WHITE, 0)
		local glow = bar(origin, finish, 3.5, WIND, 0.55)
		U.tween(line, 0.45, { Size = Vector3.new(0.04, 0.04, line.Size.Z) })
		fadeOut({ line, glow }, 0.45)
		local a0, a1 = worldAnchor(origin, direction), worldAnchor(finish, direction)
		local wake = {
			Soft.starStream(a0, a1, 1.6, 40),
			softBeam(a0, a1, {
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 9,
				width1 = 5,
				transparency = NumberSequence.new({ key(0, 0.55), key(1, 0.8) }),
				texture = SMOKE,
				speed = 30,
				length = 16,
			}),
		}
		for _, beam in wake do
			U.tween(beam, 0.5, { Width0 = beam.Width0 * 0.1, Width1 = beam.Width1 * 0.1 })
		end
		fadeBeams(wake, 0.5, { a0, a1 })
		for i = 0, 8 do
			task.delay(i * 0.02, U.impactRing, origin:Lerp(finish, i / 8), direction, WIND_WHITE, 1.5, 6, 0.3)
			task.delay(i * 0.02 + 0.01, lightRing, origin:Lerp(finish, (i + 0.5) / 8), direction, 1, 7, 0.3, WIND_WHITE)
		end
		windRing(origin, direction, 1, 12, 0.35)
		twinkle(origin, 6, WIND, 0.25)
		twinkle(finish, 10, STAR, 0.3)
		U.flash(finish, WIND_WHITE, 8, 0.2)
		gust(finish, 6, direction)
		windPuff(finish, 5, direction)
		U.light(origin, WIND, 5, 24, 0.3)
		if U.isLocal(character) then
			CameraShake.Add(0.2)
			CameraShake.FovKick(12)
		end
	elseif data.phase == "Cancel" then
		bump(character)
	end
end

local saintContext: Saint.Context = {
	anims = ANIMS,
	play = play,
	blade = function(character: Model): BasePart?
		local look = looks[character]
		return look and look.blade
	end,
	hideSword = hideSword,
}

function handlers.SaintSpiritOfZephyr(data, character, root)
	Saint.Handle(data, character, root, saintContext)
end

local AXE_HAFT = 7
local AXE_EDGE = Vector3.new(0, AXE_HAFT - 2.4, -4)
local AXE_RAISED = -18
local AXE_DOWN = 122
local AXE_BITE = 1
local AXE_SWING = 0.1

type Axe = {
	chop: (duration: number, floorY: number?, bite: (Vector3, boolean) -> ()) -> (),
	stop: () -> (),
}
local axes: { [Model]: Axe } = {}

local function edgeDrop(angle: number): number
	local a = rad(angle)
	return -(AXE_EDGE.Y * math.cos(a) + AXE_EDGE.Z * math.sin(a))
end

local function biteAngle(drop: number): number
	local lo, hi = 20, AXE_DOWN
	if edgeDrop(hi) <= drop then
		return hi
	end
	for _ = 1, 24 do
		local mid = (lo + hi) / 2
		if edgeDrop(mid) < drop then
			lo = mid
		else
			hi = mid
		end
	end
	return (lo + hi) / 2
end

local function windAxe(character: Model, root: BasePart): Axe
	local hub = U.newPart({ Size = Vector3.one * 0.2, Transparency = 1 })
	local function at(position: Vector3, axis: Vector3): Attachment
		local x = axis.Unit
		local y = if math.abs(x.Y) > 0.98 then Vector3.zAxis else UP
		local z = x:Cross(y).Unit
		local attachment = Instance.new("Attachment")
		attachment.CFrame = CFrame.fromMatrix(position, x, z:Cross(x).Unit)
		attachment.Parent = hub
		return attachment
	end
	local h = AXE_HAFT
	local butt = at(Vector3.new(0, -1.5, 0), UP)
	local crown = at(Vector3.new(0, h, 0), UP)
	local headTop = at(Vector3.new(0, h - 0.4, 0), Vector3.new(0, -2, -8))
	local edge = at(Vector3.new(0, h - 2.4, -4), Vector3.new(0, -1, 0))
	local headLow = at(Vector3.new(0, h - 4.4, 0), Vector3.new(0, -2, 8))
	local curve = 1.9
	local white = ColorSequence.new(STAR_WHITE, WIND_WHITE)
	local green = ColorSequence.new(WIND_WHITE, WIND)
	local beams = {
		softBeam(
			butt,
			crown,
			{ color = white, width0 = 0.3, width1 = 0.3, transparency = NumberSequence.new(0.15) },
			hub
		),
		softBeam(butt, crown, {
			color = green,
			width0 = 1.3,
			width1 = 1.3,
			transparency = NumberSequence.new(0.65),
			texture = SMOKE,
			speed = 2,
			length = 4,
		}, hub),
		softBeam(headTop, edge, {
			color = white,
			width0 = 0.2,
			width1 = 0.7,
			transparency = NumberSequence.new({ key(0, 0.4), key(1, 0.05) }),
			curve0 = curve,
			curve1 = curve,
		}, hub),
		softBeam(edge, headLow, {
			color = white,
			width0 = 0.7,
			width1 = 0.2,
			transparency = NumberSequence.new({ key(0, 0.05), key(1, 0.4) }),
			curve0 = curve,
			curve1 = curve,
		}, hub),
		softBeam(headTop, edge, {
			color = green,
			width0 = 1.2,
			width1 = 3.2,
			transparency = NumberSequence.new({ key(0, 0.7), key(1, 0.45) }),
			curve0 = curve,
			curve1 = curve,
			texture = SMOKE,
			speed = 2,
			length = 3,
		}, hub),
		softBeam(edge, headLow, {
			color = green,
			width0 = 3.2,
			width1 = 1.2,
			transparency = NumberSequence.new({ key(0, 0.45), key(1, 0.7) }),
			curve0 = curve,
			curve1 = curve,
			texture = SMOKE,
			speed = 2,
			length = 3,
		}, hub),
	}
	local upper = newWedge({
		Size = Vector3.new(0.1, 2, 4),
		Color = WIND_WHITE,
		Material = Enum.Material.ForceField,
		Transparency = 0.25,
	})
	local lower = newWedge({
		Size = Vector3.new(0.1, 2, 4),
		Color = WIND_WHITE,
		Material = Enum.Material.ForceField,
		Transparency = 0.25,
	})
	local pour = windEmitter(upper, {
		Size = NumberSequence.new({ key(0, 1), key(1, 3) }),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(2, 6),
		Drag = 3,
		Rate = 30,
		Enabled = false,
	})
	for _, pair in { { headTop, edge }, { edge, headLow } } do
		table.insert(
			beams,
			softBeam(pair[1], pair[2], {
				color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
				width0 = 0.7,
				width1 = 0.7,
				transparency = NumberSequence.new({ key(0, 0.6), key(0.5, 0.25), key(1, 0.6) }),
				curve0 = curve,
				curve1 = curve,
				texture = SPARKLE,
				wrap = true,
				length = 1,
				speed = 3,
			}, hub)
		)
	end
	local glow = Soft.glow(upper, WIND, 6, 0.88)
	local sheet = Soft.trail(hub, Vector3.new(0, h - 0.6, 0), Vector3.new(0, h - 2.4, -4.2), {
		color = ColorSequence.new(WIND_WHITE, WIND),
		transparency = NumberSequence.new({ key(0, 0.25), key(1, 1) }),
		lifetime = 0.28,
		faceCamera = false,
		off = true,
	})
	local light = Instance.new("PointLight")
	light.Color = WIND
	light.Range = 22
	light.Brightness = 3
	light.Parent = hub
	local chopStart: number? = nil
	local chopTime = AXE_SWING
	local floor: number? = nil
	local onBite: ((Vector3, boolean) -> ())? = nil
	local planted: CFrame? = nil
	local bitAt = 0
	local alive = true
	every(4, function(elapsed)
		if not alive or not root.Parent then
			return false
		end
		if planted then
			local since = os.clock() - bitAt
			local shudder = math.sin(since * 70) * math.exp(-since * 16) * rad(3)
			hub.CFrame = planted * CFrame.new(AXE_EDGE) * CFrame.Angles(shudder, 0, 0) * CFrame.new(-AXE_EDGE)
		else
			local right, left = handOf(character, "Right"), handOf(character, "Left")
			local hands = if right and left then right:Lerp(left, 0.5) else root.Position + UP * 3
			local forward = root.CFrame.LookVector
			local side = root.CFrame.RightVector
			local swing = if chopStart then math.min((os.clock() - chopStart) / chopTime, 1) else 0
			local target = if floor then biteAngle(hands.Y - floor + AXE_BITE) else AXE_DOWN
			local angle = rad(AXE_RAISED + (target - AXE_RAISED) * swing * swing)
			hub.CFrame = CFrame.fromMatrix(hands, side, UP * math.cos(angle) + forward * math.sin(angle))
			local bite = onBite
			if swing >= 1 and bite then
				onBite = nil
				local buried = floor ~= nil and target < AXE_DOWN
				if buried then
					planted = hub.CFrame
					bitAt = os.clock()
				end
				bite(hub.CFrame * AXE_EDGE, buried)
			end
		end
		Soft.beginTrail(sheet)
		pour.Enabled = true
		local grow = math.min(elapsed / 0.2, 1)
		upper.CFrame = hub.CFrame * CFrame.new(0, h - 1.4, -2)
		lower.CFrame = hub.CFrame * CFrame.new(0, h - 3.4, -2) * CFrame.Angles(0, 0, math.pi)
		upper.Size = Vector3.new(0.1, 2 * grow, 4 * grow)
		lower.Size = Vector3.new(0.1, 2 * grow, 4 * grow)
		return true
	end)
	local axe = {}
	function axe.chop(duration: number, floorY: number?, bite: (Vector3, boolean) -> ())
		chopStart = os.clock()
		chopTime = duration
		floor = floorY
		onBite = bite
	end
	function axe.stop()
		if not alive then
			return
		end
		alive = false
		pour.Enabled = false
		glow.Enabled = false
		light.Enabled = false
		Soft.endTrail(sheet)
		windPuff((hub.CFrame * CFrame.new(0, h - 2.4, -2)).Position, 3)
		for i = 1, 3 do
			windPuff((hub.CFrame * CFrame.new(0, h * i / 4, 0)).Position, 1.4)
		end
		twinkle((hub.CFrame * CFrame.new(0, h - 2.4, -3)).Position, 3, WIND, 0.2)
		fadeOut({ upper, lower }, 0.25)
		fadeBeams(beams, 0.25)
		task.delay(0.6, hub.Destroy, hub)
	end
	return axe
end

local function axeBite(at: Vector3, forward: Vector3)
	U.flash(at + UP * 0.6, STAR_WHITE, 7, 0.14)
	U.flash(at + UP * 0.6, WIND, 12, 0.3)
	U.impactSpikes(at + UP * 1.4, WIND, 12, 10, 0.3, STAR_WHITE)
	twinkle(at + UP * 1.2, 8, WIND, 0.3)
	lightRing(at + UP * 0.2, UP, 0.5, 13, 0.35, WIND_WHITE)
	windRing(at + UP * 0.3, UP, 1, 15, 0.45)
	task.delay(0.06, windRing, at + UP * 0.5, UP, 1, 9, 0.35)
	U.shockwave(at, WIND, 2, 20, 0.45)
	U.groove(at - forward * 1.6, at + forward * 2.2, 1.1, WIND_WHITE, 2.4)
	U.groundRocks(at, 7, 1.4, 1.3)
	U.debris(at, 14, 46, 0.8)
	U.groundCracks(at, 8, 7, WIND, 1.6)
	U.dustWave(at, 12)
	gust(at + UP, 7, UP)
	windPuff(at + UP * 0.5, 3.5, UP)
	starDust(at + UP, 14, 26, UP)
	U.light(at + UP * 2, WIND, 7, 36, 0.5)
	if (workspace.CurrentCamera.CFrame.Position - at).Magnitude < 50 then
		CameraShake.Add(0.3)
	end
end

local function cleaveDown(from: Vector3, to: Vector3, side: Vector3)
	local travel = to - from
	if travel.Magnitude < 1 then
		return
	end
	local along = travel.Unit
	local cut = windSlash(from - side * 3.2, from + side * 3.2, along * 2.4, 1.1, 0.04)
	cut.move(travel, 0.1)
	task.delay(0.1, cut.fade, 0.25)
	local a0, a1 = worldAnchor(from, along), worldAnchor(to, along)
	fadeBeams({
		softBeam(a0, a1, {
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 3,
			width1 = 6,
			transparency = NumberSequence.new({ key(0, 0.5), key(1, 0.8) }),
			texture = SMOKE,
			speed = 8,
			length = 6,
		}),
	}, 0.35, { a0, a1 })
end

local function groundSplit(first: Vector3, last: Vector3, side: Vector3)
	local span = (last - first).Magnitude
	if span < 2 then
		return
	end
	local steps = math.max(math.floor(span / 3), 1)
	local pace = 0.018
	U.groove(first, last, 0.8, WIND_WHITE, 2.4, span / (steps * pace))
	for i = 0, steps do
		local point = first:Lerp(last, i / steps)
		task.delay(i * pace, function()
			windPuff(point + UP * 0.6, 2.4, UP)
			if i % 2 == 0 then
				U.groundRocks(point, 3, 2.2, 0.9)
				local blade =
					windSlash(point - side * 1.8 + UP * 0.2, point + side * 1.8 + UP * 0.2, UP * 2.8, 0.55, 0.04)
				blade.move(UP * 4.5, 0.35)
				task.delay(0.1, blade.fade, 0.3)
			end
			if i % 3 == 0 then
				U.groundCracks(point, 3, 3.5, WIND, 1.2)
			end
			if i % 4 == 2 then
				U.debris(point, 4, 30, 0.6)
			end
		end)
	end
	local a, b = worldAnchor(first + UP * 0.2, last - first), worldAnchor(last + UP * 0.2, last - first)
	local seam = {
		softBeam(a, b, {
			color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
			width0 = 0.9,
			width1 = 0.3,
			transparency = NumberSequence.new({ key(0, 0.1), key(1, 0.5) }),
		}),
		softBeam(a, b, {
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 6,
			width1 = 3,
			transparency = NumberSequence.new({ key(0, 0.5), key(1, 0.8) }),
			texture = SMOKE,
			speed = 6,
			length = 10,
		}),
	}
	task.delay(0.3, fadeBeams, seam, 0.5, { a, b })
	U.burst(first:Lerp(last, 0.5) + UP, {
		texture = SMOKE,
		color = Color3.fromRGB(190, 198, 188),
		count = 16,
		size = 4,
		speed = NumberRange.new(10, 26),
		lifetime = NumberRange.new(0.5, 0.9),
		lightEmission = 0,
		transparency = 0.5,
		spread = 70,
		direction = UP,
		drag = 3,
	})
end

function handlers.SpiritOfBoreas(data, character, root)
	local phase = data.phase
	if phase == "Raise" then
		play(character, ANIMS.BoreasForm)
		local old = axes[character]
		if old then
			old.stop()
		end
		hideSword(character, data.duration + 0.6)
		local axe = windAxe(character, root)
		axes[character] = axe
		task.delay(data.duration + 0.8, function()
			if axes[character] == axe then
				axes[character] = nil
				axe.stop()
			end
		end)
		windPuff(root.Position + UP * 4, 3)
		windRing(root.Position + UP * 7, UP, 1, 9, 0.4)
		twinkle(root.Position + UP * 8, 4, WIND, 0.25)
		for _ = 1, 8 do
			inflow(root.Position + UP * 6, 8, WIND_WHITE)
		end
	elseif phase == "Chop" then
		play(character, ANIMS.BoreasChop)
		local origin: Vector3 = data.origin
		local direction: Vector3 = data.direction
		local length: number = data.length
		local air = data.airborne == true
		local forward = Vector3.new(direction.X, 0, direction.Z)
		forward = if forward.Magnitude > 1e-3 then forward.Unit else root.CFrame.LookVector
		local side = forward:Cross(UP).Unit
		local function floorAt(point: Vector3): Vector3
			local hit = U.groundBelow(point, { character }, 30)
			return if hit then hit.Position else point - UP * 3
		end
		local last = if air then floorAt(origin + direction * length) else floorAt(origin + forward * length)
		local ahead = if air then nil else U.groundBelow(root.Position + forward * 5, { character }, 12)
		local struck = false
		local function strike(edge: Vector3, buried: boolean)
			if struck then
				return
			end
			struck = true
			if buried then
				local bite = floorAt(edge + UP * (AXE_BITE + 1))
				axeBite(bite, forward)
				groundSplit(bite, last, side)
				return
			end
			local bite = if air then last else floorAt(origin + forward * 5)
			cleaveDown(edge, bite, side)
			task.delay(0.08, function()
				axeBite(bite, forward)
				if not air then
					groundSplit(bite, last, side)
				end
			end)
		end
		local axe = axes[character]
		if axe then
			axe.chop(AXE_SWING, if ahead then ahead.Position.Y else nil, strike)
			task.delay(AXE_SWING + 0.4, function()
				if axes[character] == axe then
					axes[character] = nil
					axe.stop()
				end
			end)
		else
			task.delay(AXE_SWING, strike, floorAt(origin + forward * 5) - UP * AXE_BITE, false)
		end
		if U.isLocal(character) then
			CameraShake.FovKick(8)
		end
	elseif phase == "Cancel" then
		local axe = axes[character]
		if axe then
			axes[character] = nil
			axe.stop()
		end
	end
end

type LongSword = { stop: () -> (), hold: (number) -> (), point: () -> Vector3 }
local longSwords: { [Model]: LongSword } = {}

local function longSword(character: Model, duration: number): LongSword
	local hub = U.newPart({ Size = Vector3.one * 0.2, Transparency = 1 })
	local hilt = Instance.new("Attachment")
	hilt.Parent = hub
	local point = Instance.new("Attachment")
	point.Position = Vector3.new(0, 0, -9)
	point.Parent = hub
	local beams = {
		softBeam(hilt, point, {
			color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
			width0 = 0.45,
			width1 = 0.1,
			transparency = NumberSequence.new({ key(0, 0.1), key(1, 0.45) }),
		}, hub),
		softBeam(hilt, point, {
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 2.2,
			width1 = 0.6,
			transparency = NumberSequence.new({ key(0, 0.55), key(1, 0.85) }),
			texture = SMOKE,
			speed = 4,
			length = 6,
		}, hub),
	}
	table.insert(beams, Soft.starStream(hilt, point, 0.5, 10, hub))
	local shine = windEmitter(point, {
		Color = ColorSequence.new(WIND_WHITE),
		LightEmission = 1,
		Transparency = NumberSequence.new({ key(0, 1), key(0.25, 0.75), key(1, 1) }),
		Size = NumberSequence.new(2.4),
		Lifetime = NumberRange.new(0.18, 0.24),
		Speed = NumberRange.new(0),
		LockedToPart = true,
		Rate = 20,
	})
	local streak0 = Instance.new("Attachment")
	streak0.Position = Vector3.new(0, 0.5, -8.5)
	streak0.Parent = hub
	local streak1 = Instance.new("Attachment")
	streak1.Position = Vector3.new(0, -0.5, -8.5)
	streak1.Parent = hub
	local trail = Instance.new("Trail")
	trail.Attachment0 = streak0
	trail.Attachment1 = streak1
	trail.Color = ColorSequence.new(WIND_WHITE, WIND)
	trail.Transparency = NumberSequence.new({ key(0, 0.35), key(1, 1) })
	trail.WidthScale = NumberSequence.new({ key(0, 1), key(1, 0.2) })
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Parent = hub
	local sweep = Instance.new("Trail")
	sweep.Attachment0 = hilt
	sweep.Attachment1 = point
	sweep.Color = ColorSequence.new(WIND_WHITE, WIND)
	sweep.Transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) })
	sweep.Lifetime = 0.18
	sweep.LightEmission = 1
	sweep.LightInfluence = 0
	sweep.Parent = hub
	local alive = true
	local untilTime = os.clock() + duration
	every(math.huge, function()
		local arm = character:FindFirstChild("Right Arm") :: BasePart?
		if not alive or not arm or os.clock() > untilTime then
			return false
		end
		local grip = arm.CFrame * CFrame.new(0, -1.1, 0) * CFrame.Angles(rad(-90), 0, 0)
		hub.CFrame = CFrame.lookAt(grip.Position, grip.Position + grip.UpVector)
		return true
	end, function()
		if alive then
			alive = false
			trail.Enabled = false
			shine.Enabled = false
			fadeBeams(beams, 0.2, { hub })
		end
	end)
	local sword = {}
	function sword.stop()
		if alive then
			alive = false
			trail.Enabled = false
			sweep.Enabled = false
			shine.Enabled = false
			fadeBeams(beams, 0.2, { hub })
		end
	end
	function sword.hold(seconds: number)
		untilTime = math.max(untilTime, os.clock() + seconds)
	end
	function sword.point(): Vector3
		return point.WorldPosition
	end
	return sword
end

local waltzContext: Waltz.Context = {
	anims = ANIMS,
	play = play,
	sword = function(character: Model): LongSword?
		return longSwords[character]
	end,
}
local waltzStops: { [Model]: () -> () } = setmetatable({}, { __mode = "k" }) :: any

function handlers.SpiritOfZephyrus(data, character, root)
	local phase = data.phase
	if phase == "Lunge" then
		play(character, ANIMS.ZephyrusLunge)
		local old = longSwords[character]
		if old then
			old.stop()
		end
		longSwords[character] = longSword(character, data.duration + 0.4)
		local direction: Vector3 = data.direction
		windPuff(root.Position - UP * 2.4, 3, -direction)
		windRing(root.Position, direction, 1, 6, 0.3)
		lightRing(root.Position, direction, 0.5, 5, 0.25, WIND_WHITE)
		U.bodyTrail(character, WIND, data.duration + 0.1)
		local torso = character:FindFirstChild("Torso") :: BasePart?
		if torso then
			local wake = Soft.trail(torso, Vector3.new(0, 1.6, 0), Vector3.new(0, -1.6, 0), {
				color = ColorSequence.new(WIND_WHITE, WIND),
				transparency = NumberSequence.new({ key(0, 0.45), key(1, 1) }),
				width = NumberSequence.new({ key(0, 1), key(1, 0.3) }),
				lifetime = 0.4,
				texture = SMOKE,
			})
			task.delay(data.duration + 0.1, Soft.endTrail, wake)
		end
		for i = 0, 3 do
			task.delay(i * 0.07, U.afterimage, character, WIND, 0.35)
		end
		if U.isLocal(character) then
			U.speedLines(root, direction, data.duration, WIND_WHITE)
			CameraShake.FovKick(8)
		end
	elseif phase == "Waltz" then
		local stop = Waltz.Play(waltzContext, data, character, root)
		if stop then
			waltzStops[character] = stop
		end
	elseif phase == "Abort" then
		local stop = waltzStops[character]
		waltzStops[character] = nil
		if stop then
			stop()
		end
		local sword = longSwords[character]
		if sword then
			longSwords[character] = nil
			sword.stop()
		end
	elseif phase == "Whiff" then
		windPuff(root.Position + root.CFrame.LookVector * 3, 2)
		local sword = longSwords[character]
		if sword then
			longSwords[character] = nil
			sword.stop()
		end
	end
end

return {}
