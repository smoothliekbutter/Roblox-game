-- Yuno's Half-Crown moves: Spirit Storm, Tempest Dive, Quartile Scutum and Nova Vortex.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DivePlan = require(ReplicatedStorage:WaitForChild("Shared").TempestDive)
local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local Cinematic = require(script.Parent.Parent.Parent.Cinematic)
local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local VFX = require(script.Parent.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Parent.Soft)
local Nova = require(script.Parent.Nova)

local U = VFX.Util
local rad = math.rad
local UP = Vector3.yAxis

-- The palette and the soft wind everything is drawn with (see Soft).
local WIND, WIND_DEEP, WIND_WHITE = Soft.WIND, Soft.WIND_DEEP, Soft.WIND_WHITE
local STAR, STAR_WHITE = Soft.STAR, Soft.STAR_WHITE
local SMOKE, SPARKLE = Soft.SMOKE, Soft.SPARKLE
local every, fadeOut, key = Soft.every, Soft.fadeOut, Soft.key
local bar, tube = Soft.bar, Soft.tube
local inflow, gust = Soft.inflow, Soft.gust
local makeStar = Soft.makeStar
local arcPoints, arcParts, poseArc = Soft.arcPoints, Soft.arcParts, Soft.poseArc
local worldAnchor, softBeam, fadeBeams, softRing = Soft.worldAnchor, Soft.softBeam, Soft.fadeBeams, Soft.softRing
local windRing, lightRing, windEmitter, windPuff = Soft.windRing, Soft.lightRing, Soft.windEmitter, Soft.windPuff
local twinkle, starDust, streaks = Soft.twinkle, Soft.starDust, Soft.streaks

local Fx = require(script.Parent.Fx)
local ANIMS, handlers, play, bump, live, involves = Fx.ANIMS, Fx.handlers, Fx.play, Fx.bump, Fx.live, Fx.involves
local handOf, easeInOut = Fx.handOf, Fx.easeInOut

local STORM_STRANDS = 3
local STORM_SEGMENTS = 18

function handlers.SpiritStorm(data, character, root)
	if data.phase == "Charge" then
		play(character, ANIMS.StormCharge)
		local token = bump(character)
		local orb = U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.2, Color = WIND_WHITE })
		local halo =
			U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, Color = WIND, Transparency = 0.5 })
		local shell = U.newPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			Color = WIND,
			Material = Enum.Material.ForceField,
		})
		local rings = {}
		for _ = 1, 3 do
			table.insert(
				rings,
				arcParts(arcPoints(Vector3.zero, Vector3.xAxis, UP, 1, 0, math.pi * 2, 10), 0.08, WIND_WHITE, 0.15)
			)
		end
		local light = Instance.new("PointLight")
		light.Color = WIND
		light.Range = 12
		light.Brightness = 1
		light.Parent = orb
		local glow = Soft.glow(orb, WIND, 6, 0.85)
		local whirl = softRing({
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 1,
			width1 = 1,
			transparency = NumberSequence.new(0.5),
			texture = SMOKE,
			speed = 4,
			length = 3,
		})
		local well = U.newPart({
			Size = Vector3.one * 10,
			Transparency = 1,
			CFrame = CFrame.new(handOf(character, "Right") or root.Position),
		})
		local drawn = {
			windEmitter(well, {
				Texture = SPARKLE,
				Color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
				LightEmission = 1,
				Transparency = NumberSequence.new({ key(0, 1), key(0.3, 0.2), key(1, 0.6) }),
				Size = NumberSequence.new({ key(0, 0.5), key(1, 0.1) }),
				Lifetime = NumberRange.new(0.4, 0.5),
				Speed = NumberRange.new(10, 12),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				Rate = 40,
			}),
			windEmitter(well, {
				Size = NumberSequence.new({ key(0, 3), key(1, 0.6) }),
				Lifetime = NumberRange.new(0.4, 0.5),
				Speed = NumberRange.new(10, 12),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				Rate = 18,
			}),
		}
		local floor = softRing({
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 1.4,
			width1 = 1.4,
			transparency = NumberSequence.new(0.55),
			texture = SMOKE,
			speed = 3,
			length = 4,
		})
		every(data.duration + 0.05, function(elapsed)
			local hand = handOf(character, "Right")
			if not live(character, token) or not hand then
				return false
			end
			local grow = math.min(elapsed / data.duration, 1)
			local center = hand + root.CFrame.LookVector * 0.7
			well.CFrame = CFrame.new(center)
			whirl.set(
				CFrame.lookAt(center, center + root.CFrame.LookVector) * CFrame.Angles(rad(90), elapsed * 9, 0),
				1.2 + 2 * grow
			)
			floor.set(CFrame.new(root.Position - UP * 2.9) * CFrame.Angles(0, elapsed * 3, 0), 7 - 5.5 * grow)
			orb.Size = Vector3.one * (0.3 + 1.1 * grow)
			halo.Size = Vector3.one * (0.8 + 2.4 * grow)
			shell.Size = Vector3.one * (1 + 3.2 * grow)
			orb.CFrame = CFrame.new(center)
			halo.CFrame = orb.CFrame
			shell.CFrame = orb.CFrame * CFrame.Angles(elapsed * 3, elapsed * 2, 0)
			for r, ring in rings do
				local tilt = CFrame.Angles(r * 1.1 + elapsed * (3 + r), elapsed * (4 - r), r * 0.7)
				poseArc(
					ring,
					arcPoints(center, tilt.RightVector, tilt.UpVector, 0.7 + 1.7 * grow + r * 0.25, 0, math.pi * 2, 10)
				)
			end
			inflow(center, 6)
			inflow(center, 4)
			light.Brightness = 1 + 5 * grow
			return true
		end, function()
			glow.Enabled = false
			for _, emitter in drawn do
				emitter.Enabled = false
			end
			task.delay(0.6, well.Destroy, well)
			whirl.fade(0.1)
			floor.fade(0.15)
			fadeOut({ orb, halo, shell }, 0.08)
			for _, ring in rings do
				fadeOut(ring, 0.08)
			end
		end)
		U.spiral(root, WIND, 2.2, 4, data.duration, 2, 0.08, 0.6)
		if U.isLocal(character) then
			CameraShake.Add(0.06)
		end
	elseif data.phase == "Fire" then
		play(character, ANIMS.StormFire)
		local token = bump(character)
		local origin: Vector3 = data.origin
		local direction: Vector3 = data.direction
		local length: number = data.length
		local finish = origin + direction * length
		local right = direction:Cross(UP)
		right = if right.Magnitude > 1e-3 then right.Unit else Vector3.xAxis
		local up = right:Cross(direction).Unit

		local core = tube(origin, finish, 1.2, WIND_WHITE, 0)
		local column = tube(origin, finish, 4.2, WIND, 0.5)
		local sheath = tube(origin, finish, 6.4, WIND, 0)
		sheath.Material = Enum.Material.ForceField
		local haze = tube(origin, finish, 9, WIND_DEEP, 0.9)
		local strands: { { BasePart } } = {}
		for k = 1, STORM_STRANDS do
			local strand = {}
			for _ = 1, STORM_SEGMENTS do
				table.insert(
					strand,
					bar(
						origin,
						origin + direction,
						if k == 1 then 0.3 else 0.22,
						if k == 1 then WIND_WHITE else WIND,
						0.1
					)
				)
			end
			table.insert(strands, strand)
		end
		-- Streaks racing down the beam.
		local muzzle = U.newPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.lookAt(origin, finish) })
		local racing = Instance.new("ParticleEmitter")
		racing.Texture = U.textures.Spark
		racing.Color = ColorSequence.new(WIND_WHITE, WIND)
		racing.LightEmission = 1
		racing.LightInfluence = 0
		racing.EmissionDirection = Enum.NormalId.Front
		racing.Orientation = Enum.ParticleOrientation.VelocityParallel
		racing.Speed = NumberRange.new(150, 210)
		racing.Lifetime = NumberRange.new(length / 210, length / 150)
		racing.SpreadAngle = Vector2.new(5, 5)
		racing.Size = NumberSequence.new(0.7, 0.1)
		racing.Transparency = NumberSequence.new(0.1, 1)
		racing.Rate = 140
		racing.Parent = muzzle
		local light = Instance.new("PointLight")
		light.Color = WIND
		light.Range = 28
		light.Brightness = 5
		light.Parent = core
		local from, to = worldAnchor(origin, direction), worldAnchor(finish, direction)
		local flow = {
			softBeam(from, to, {
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 9,
				width1 = 11,
				transparency = NumberSequence.new({ key(0, 0.75), key(0.1, 0.55), key(0.9, 0.6), key(1, 0.85) }),
				texture = SMOKE,
				speed = 30,
				length = 12,
			}),
			softBeam(from, to, {
				color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
				width0 = 2.4,
				width1 = 2.4,
				transparency = NumberSequence.new({ key(0, 0.6), key(0.1, 0.3), key(1, 0.45) }),
				texture = SPARKLE,
				wrap = true,
				length = 2.5,
				speed = 40,
			}),
			softBeam(from, to, {
				color = ColorSequence.new(WIND, WIND_DEEP),
				width0 = 16,
				width1 = 18,
				transparency = NumberSequence.new({ key(0, 0.95), key(0.15, 0.88), key(1, 0.9) }),
				texture = SMOKE,
				speed = 12,
				length = 20,
				emission = 0.6,
			}),
		}
		local stopHelix = Soft.helix(function()
			return origin, finish
		end, 3.4, 3, 0.3, 5, 0.9, data.duration)

		local nextRing, nextPulse, nextSplash = 0, 0, 0
		every(data.duration, function(elapsed)
			if not live(character, token) then
				return false
			end
			-- Three helices of wind, twisting round the beam and spinning.
			local spin = elapsed * 14
			for k, strand in strands do
				local phase = k * (math.pi * 2 / STORM_STRANDS) + spin
				local radius = 2.5 + 0.35 * math.sin(elapsed * 30 + k)
				local previous = origin
				for i, segment in strand do
					local s = i / #strand * length
					local angle = phase + s * 0.35
					local point = origin
						+ direction * s
						+ (right * math.cos(angle) + up * math.sin(angle)) * radius * math.min(s / 3, 1)
					segment.Size = Vector3.new(segment.Size.X, segment.Size.Y, (point - previous).Magnitude + 0.05)
					segment.CFrame = CFrame.lookAt(previous:Lerp(point, 0.5), point)
					previous = point
				end
			end
			local breathe = 1 + math.sin(elapsed * 40) * 0.07
			column.Size = Vector3.new(column.Size.X, 4.2 * breathe, 4.2 * breathe)
			core.Size =
				Vector3.new(core.Size.X, 1.2 + math.sin(elapsed * 55) * 0.18, 1.2 + math.sin(elapsed * 55) * 0.18)
			if elapsed >= nextRing then
				nextRing = elapsed + 0.035
				local at = origin + direction * (math.random() * length)
				if math.random() < 0.5 then
					U.impactRing(at, direction, WIND_WHITE, 2, 5.5, 0.2)
				else
					lightRing(at, direction, 2, 6, 0.2, WIND_WHITE)
				end
			end
			if elapsed >= nextPulse then
				nextPulse = elapsed + 0.1
				U.impactRing(origin, direction, WIND, 1.5, 7, 0.25)
				windRing(origin + direction * 2, direction, 1.5, 6, 0.25)
			end
			if elapsed >= nextSplash then
				-- Where it strikes, wind and glitter blast out of it.
				nextSplash = elapsed + 0.09
				windPuff(finish, 3, -direction)
				streaks(finish, 6, 50, -direction, 60)
			end
			return true
		end, function()
			-- The helices unwind outward and it all collapses.
			for _, strand in strands do
				for _, segment in strand do
					local out = segment.Position - (origin + direction * direction:Dot(segment.Position - origin))
					U.tween(segment, 0.3, {
						CFrame = segment.CFrame + (if out.Magnitude > 1e-3 then out.Unit * 2.5 else Vector3.zero),
						Transparency = 1,
					})
				end
				task.delay(0.32, function()
					for _, segment in strand do
						segment:Destroy()
					end
				end)
			end
			U.tween(core, 0.25, { Size = Vector3.new(core.Size.X, 0.05, 0.05) })
			fadeOut({ core, column, sheath, haze }, 0.3)
			for _, beam in flow do
				U.tween(beam, 0.3, { Width0 = 0.5, Width1 = 0.5 })
			end
			fadeBeams(flow, 0.32, { from, to })
			stopHelix()
			racing.Enabled = false
			task.delay(0.6, muzzle.Destroy, muzzle)
			gust(finish, 8, direction)
			U.shockwave(finish, WIND, 2, 14, 0.35)
			windRing(finish, direction, 2, 16, 0.4)
			lightRing(finish, direction, 1, 12, 0.3, WIND_WHITE)
		end)

		-- The ground it passes over is scarred.
		for along = 6, length, 6 do
			local ground = U.groundBelow(origin + direction * along, { character }, 7)
			if ground then
				task.delay(along / 300, function()
					U.groundCracks(ground.Position, 2, 4, WIND, 1.2)
					U.debris(ground.Position, 3, 25, 0.5)
				end)
			end
		end
		gust(origin, 6, direction)
		U.flash(origin, WIND_WHITE, 6, 0.2)
		twinkle(origin, 6, WIND, 0.25)
		U.impactRing(origin, direction, WIND_WHITE, 1, 9, 0.3)
		windRing(origin, direction, 1, 12, 0.35)
		U.light(origin, WIND, 6, 24, 0.7)
		if U.isLocal(character) then
			CameraShake.Add(0.25)
			CameraShake.FovKick(10)
		elseif (workspace.CurrentCamera.CFrame.Position - origin).Magnitude < 40 then
			CameraShake.Add(0.1)
		end
	elseif data.phase == "Cancel" then
		bump(character)
	end
end

local TORNADO_BANDS = 12
local TORNADO_PANELS = 16
local TORNADO_SHADES = { WIND, Color3.fromRGB(150, 176, 160), Color3.fromRGB(96, 120, 106) }

type Tornado = { update: (t: number, visible: number) -> (), destroy: () -> () }

local function makeTornado(base: Vector3, height: number): Tornado
	local bands = {}
	local emitters = {}
	for k = 1, TORNADO_BANDS do
		local fraction = (k - 0.5) / TORNADO_BANDS
		local radius = 2.5 + 11 * fraction ^ 1.25
		local hub = U.newPart({
			Size = Vector3.one * 0.2,
			Transparency = 1,
			CFrame = CFrame.new(base + UP * (height * fraction)),
		})
		local panels = {}
		local width = 2 * math.pi * radius / TORNADO_PANELS * 1.3
		for j = 1, TORNADO_PANELS do
			local shade = (j + k) % 3 + 1
			local panel = Instance.new("Part")
			panel.Anchored = false
			panel.CanCollide = false
			panel.CanQuery = false
			panel.CanTouch = false
			panel.CastShadow = false
			panel.Massless = true
			panel.Material = if shade == 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			panel.Color = TORNADO_SHADES[shade]
			panel.Transparency = 1
			panel.Size = Vector3.new(width, height / TORNADO_BANDS + 0.8, 0.5)
			-- Leaning into the spin, like streaks of wind.
			panel.CFrame = hub.CFrame
				* CFrame.Angles(0, j / TORNADO_PANELS * math.pi * 2, 0)
				* CFrame.new(0, 0, -radius)
				* CFrame.Angles(0, 0, rad(18))
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hub
			weld.Part1 = panel
			weld.Parent = panel
			panel.Parent = U.folder
			table.insert(panels, { part = panel, solid = if shade == 1 then 0.35 else 0.18 })
			if k % 2 == 0 and j % 4 == 0 then
				local dust = Instance.new("ParticleEmitter")
				dust.Texture = U.textures.Smoke
				dust.Color = ColorSequence.new(Color3.fromRGB(170, 190, 175))
				dust.LightInfluence = 0.6
				dust.Size = NumberSequence.new(2.5, 4.5)
				dust.Transparency = NumberSequence.new(0.45, 1)
				dust.Lifetime = NumberRange.new(0.5, 0.8)
				dust.Rate = 0
				dust.Speed = NumberRange.new(0, 1)
				dust.Parent = panel
				table.insert(emitters, dust)
			end
		end
		table.insert(bands, { hub = hub, panels = panels, height = height * fraction, radius = radius, shown = -1 })
	end
	local debris = {}
	for _ = 1, 18 do
		table.insert(
			debris,
			U.newPart({
				Size = Vector3.new(0.4, 0.3, 0.5) * (1 + math.random() * 1.5),
				Color = Color3.fromRGB(92, 86, 78),
				Material = Enum.Material.Slate,
				Transparency = 1,
			})
		)
	end

	local tornado = {}
	function tornado.update(t: number, visible: number)
		for k, band in bands do
			band.hub.CFrame = CFrame.new(base + UP * band.height) * CFrame.Angles(0, t * (9 - k * 0.35) + k * 0.5, 0)
			local risen = math.clamp(visible * TORNADO_BANDS - (k - 1), 0, 1)
			local shown = math.floor(risen * 20 + 0.5) / 20
			if shown ~= band.shown then
				band.shown = shown
				for _, panel in band.panels do
					panel.part.Transparency = 1 - (1 - panel.solid) * shown
				end
			end
		end
		for _, dust in emitters do
			dust.Rate = if visible > 0.5 then 12 else 0
		end
		for i, chunk in debris do
			local fraction = (i - 0.5) / #debris
			local angle = t * (6 + i % 3) + i
			local radius = (2.5 + 11 * fraction ^ 1.25) * 0.75
			local position = base
				+ Vector3.new(
					math.cos(angle) * radius,
					height * 0.9 * fraction + math.sin(t * 2 + i) * 1.5,
					math.sin(angle) * radius
				)
			chunk.CFrame = CFrame.new(position) * CFrame.Angles(t * 5 + i, t * 3, 0)
			chunk.Transparency = if visible > fraction then 0 else 1
		end
	end
	function tornado.destroy()
		for _, band in bands do
			band.hub:Destroy()
			for _, panel in band.panels do
				panel.part:Destroy()
			end
		end
		for _, chunk in debris do
			chunk:Destroy()
		end
	end
	return tornado
end

local function playTempestDive(data, character: Model, root: BasePart)
	local target: Model? = data.target
	local targetRoot = target and U.getRoot(target)
	local plan = DivePlan.Plan(data.origin, data.start, data.floorY)
	PoseAnimator.SettleLift(character, DivePlan.Times.Length)
	local times = DivePlan.Times
	local started = os.clock()
	local mine = involves(data, character)
	local floorY = plan.floorY
	local base = Vector3.new(plan.start.X, floorY, plan.start.Z)

	play(character, ANIMS.TempestDrag)
	U.bodyTrail(character, WIND, times.Lift)
	if target then
		U.bodyTrail(target, WIND_WHITE, times.Lift)
	end
	gust(plan.start, 6, UP)
	U.ringBurst(CFrame.new(base + UP * 0.2), WIND, 1, 9, 0.4, 0.3)
	windRing(base + UP * 0.3, UP, 1, 12, 0.45)
	windPuff(base + UP, 4, UP)
	-- Up on a whirl of wind: ribbons of wind round the two of them and a
	-- soft wake of wind behind.
	Soft.helix(function()
		local at = root.Position
		return at - UP * 6, at + UP * 3
	end, 3, 3, 0.35, 2.5, 0.8, times.Lift)
	local wakes: { Trail } = {}
	local torso = character:FindFirstChild("Torso") :: BasePart?
	if torso then
		table.insert(
			wakes,
			Soft.trail(torso, Vector3.new(1.6, 0, 0), Vector3.new(-1.6, 0, 0), {
				color = ColorSequence.new(WIND_WHITE, WIND),
				transparency = NumberSequence.new({ key(0, 0.45), key(1, 1) }),
				width = NumberSequence.new({ key(0, 1), key(1, 0.3) }),
				lifetime = 0.45,
				texture = SMOKE,
			})
		)
	end
	task.delay(times.Length, function()
		for _, wake in wakes do
			Soft.endTrail(wake)
		end
	end)

	local tornado = makeTornado(base, DivePlan.Height + 4)
	local formFrom = times.Flip - 0.25 -- it rises out of the ground as he turns them over
	local standUntil = times.Land + 0.6
	local finishAt = standUntil + 0.4
	local bind = "CloverTempestDive" .. tostring(started)
	local function finish()
		pcall(function()
			RunService:UnbindFromRenderStep(bind)
		end)
	end
	local flipped, dove, risen = false, false, false
	RunService:BindToRenderStep(bind, Enum.RenderPriority.Camera.Value + 3, function()
		local t = os.clock() - started
		if t > finishAt then
			finish()
			return
		end
		if t <= times.Length and root.Parent then
			root.CFrame = DivePlan.Attacker(plan, t)
		end
		if targetRoot and targetRoot.Parent and t <= times.Land then
			targetRoot.CFrame = DivePlan.Victim(plan, t)
		end
		if not flipped and t >= times.Lift then
			flipped = true
			play(character, ANIMS.BoreasForm)
			local top = plan.start + UP * DivePlan.Height
			U.flash(top, WIND_WHITE, 6, 0.2)
			U.ringBurst(CFrame.new(top), WIND, 1, 8, 0.35, 0.2)
			windRing(top, UP, 1, 12, 0.4)
			lightRing(top, UP, 0.5, 9, 0.3, WIND_WHITE)
			windPuff(top, 3)
			if mine then
				CameraShake.Add(0.1)
			end
		end
		if not risen and t >= formFrom then
			risen = true
			U.ringBurst(CFrame.new(base + UP * 0.2), WIND_WHITE, 2, 16, 0.4, 0.5)
			U.debris(base, 14, 40, 0.8)
			windRing(base + UP * 0.4, UP, 3, 20, 0.5)
			local height = DivePlan.Height + 4
			local stand = finishAt - formFrom
			local foot, head = worldAnchor(base, UP), worldAnchor(base + UP * height, UP)
			local eye = {
				softBeam(foot, head, {
					color = ColorSequence.new(WIND_WHITE, WIND),
					width0 = 6,
					width1 = 20,
					transparency = NumberSequence.new({ key(0, 0.85), key(0.15, 0.6), key(0.9, 0.7), key(1, 1) }),
					texture = SMOKE,
					speed = 10,
					length = 14,
				}),
				softBeam(foot, head, {
					color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
					width0 = 1.5,
					width1 = 3,
					transparency = NumberSequence.new({ key(0, 0.7), key(0.2, 0.45), key(1, 0.9) }),
					texture = SPARKLE,
					wrap = true,
					length = 3,
					speed = 18,
				}),
			}
			task.delay(stand - 0.4, fadeBeams, eye, 0.4, { foot, head })
			Soft.helix(function()
				return base, base + UP * height
			end, 9, 4, 0.6, 2, 1.4, stand)
			if mine or (workspace.CurrentCamera.CFrame.Position - base).Magnitude < 70 then
				CameraShake.Add(0.2)
			end
		end
		if not dove and t >= times.Flip then
			dove = true
			play(character, ANIMS.BoreasChop)
			if mine then
				CameraShake.FovKick(10)
				U.speedLines(root, -UP, times.Land - times.Flip, WIND_WHITE)
			end
		end
		if t >= formFrom then
			local rising = math.clamp((t - formFrom) / 0.3, 0, 1)
			local going = math.clamp((t - standUntil) / 0.4, 0, 1)
			tornado.update(t, rising * (1 - going))
		end
	end)
	task.delay(finishAt + 0.1, function()
		finish()
		tornado.destroy()
	end)

	if mine then
		Cinematic.Camera(function(t)
			local focus = DivePlan.Victim(plan, math.min(t, times.Land)).Position
			local right = plan.forward:Cross(UP)
			if t < times.Flip - 0.05 then
				-- From the side, rising a little with them on the way up.
				local lift = -2 + 5 * easeInOut(t / times.Lift)
				local offset = right * 18 - plan.forward * 6 + UP * lift
				return CFrame.lookAt(focus + offset, focus), 72
			end
			-- Inside the tornado on the way down, then easing up and out of it
			-- as it stands over the crater.
			local after = easeInOut((t - times.Land) / 0.6)
			local eye = focus + UP * (9 + 7 * after) + right * (1.5 + 4 * after) - plan.forward * (0.5 + 3 * after)
			return CFrame.lookAt(eye, focus), 88 - 12 * after
		end, times.Length + 0.2)
	end
end

function handlers.TempestDive(data, character, root)
	local phase = data.phase
	if phase == "Reach" then
		play(character, ANIMS.Hawk)
		local hand = handOf(character, "Right")
		if hand then
			gust(hand, 3, root.CFrame.LookVector)
		end
	elseif phase == "Whiff" then
		gust(root.Position + root.CFrame.LookVector * 4, 2)
	elseif phase == "Begin" then
		playTempestDive(data, character, root)
	elseif phase == "Impact" then
		local position: Vector3 = data.position
		U.shockwave(position, WIND, 3, 26, 0.45, Enum.Material.ForceField)
		U.shockwave(position, WIND_WHITE, 2, 12, 0.25)
		U.ringBurst(CFrame.new(position + UP * 0.2), WIND_WHITE, 2, 16, 0.4, 0.45)
		U.ringBurst(CFrame.new(position + UP * 0.3), WIND, 1, 11, 0.5, 0.25)
		U.groundCracks(position, 12, 11, WIND, 1.6)
		U.groundRocks(position, 12, 7, 1.8)
		U.debris(position, 18, 45, 1)
		U.pillar(position, WIND, 3, 22, 0.45, Enum.Material.ForceField, 0.25)
		gust(position + UP, 9, UP)
		windRing(position + UP * 0.3, UP, 2, 26, 0.5)
		windRing(position + UP * 0.5, UP, 1, 16, 0.4, WIND_WHITE)
		lightRing(position + UP * 0.2, UP, 1, 20, 0.4, WIND_WHITE)
		windPuff(position + UP, 6, UP)
		streaks(position + UP, 24, 90, UP, 50)
		U.light(position, WIND, 6, 40, 0.6)
		local near = (workspace.CurrentCamera.CFrame.Position - position).Magnitude < 60
		if near then
			U.colorGrade({ Brightness = 0.2, Contrast = 0.5, Saturation = -0.6 }, 0, 0.06, 0.25)
			CameraShake.Add(0.45)
		end
	end
end

local barriers: { [Model]: { ripple: (Vector3?) -> (), drop: () -> () } } = {}

function handlers.QuartileScutum(data, character, root)
	if data.phase == "Raise" then
		play(character, ANIMS.Scutum)
		local corners = {
			Vector3.new(-3.6, -2.6, -3.2),
			Vector3.new(3.6, -2.6, -3.2),
			Vector3.new(3.6, 3.2, -3.2),
			Vector3.new(-3.6, 3.2, -3.2),
		}
		local cornerStars = {}
		for _ = 1, 4 do
			table.insert(cornerStars, makeStar(1.4))
		end
		local edges = {}
		for _ = 1, 4 do
			table.insert(edges, bar(Vector3.zero, UP, 0.18, STAR_WHITE, 0.05))
		end
		local pane = U.newPart({
			Size = Vector3.new(7.2, 5.8, 0.1),
			Color = STAR,
			Transparency = 0.82,
			Material = Enum.Material.ForceField,
		})
		-- Streams of starlight running round its edges, glitter drifting off
		-- the pane.
		local anchors: { Attachment } = {}
		for _ = 1, 4 do
			table.insert(anchors, worldAnchor(root.Position))
		end
		local streams: { Beam } = {}
		for i = 1, 4 do
			table.insert(streams, Soft.starStream(anchors[i], anchors[i % 4 + 1], 0.6, 3))
		end
		pane.CFrame = root.CFrame * CFrame.new(0, 0.3, -3.2)
		local shimmer = windEmitter(pane, {
			Texture = SPARKLE,
			Color = ColorSequence.new(STAR_WHITE, STAR),
			LightEmission = 1,
			Transparency = NumberSequence.new({ key(0, 1), key(0.3, 0.4), key(1, 1) }),
			Size = NumberSequence.new({ key(0, 0.3), key(0.5, 0.45), key(1, 0) }),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
			Shape = Enum.ParticleEmitterShape.Box,
			Rate = 22,
		})
		local done = false
		local function drop()
			done = true
			barriers[character] = nil
			for _, star in cornerStars do
				star.fade(0.25)
			end
			for _, anchor in anchors do
				starDust(anchor.WorldPosition, 5, 12)
			end
			shimmer.Enabled = false
			fadeBeams(streams, 0.25, anchors)
			fadeOut(edges, 0.25)
			fadeOut({ pane }, 0.25)
		end
		barriers[character] = {
			ripple = function(from: Vector3?)
				U.impactRing(pane.Position, pane.CFrame.LookVector, STAR_WHITE, 0.5, 4, 0.3)
				lightRing(pane.Position, pane.CFrame.LookVector, 0.3, 4.5, 0.3)
				twinkle(pane.Position, 4, STAR, 0.2)
				U.flash(pane.Position, STAR, 5, 0.15)
				if from then
					U.burst(pane.Position, {
						color = STAR,
						count = 10,
						size = 0.3,
						speed = NumberRange.new(10, 25),
						lifetime = NumberRange.new(0.15, 0.3),
						streaks = true,
						spread = 50,
						direction = (from - pane.Position).Unit,
					})
				end
			end,
			drop = drop,
		}
		for i, corner in corners do
			task.delay((i - 1) * 0.03, function()
				if root.Parent then
					twinkle(root.CFrame:PointToWorldSpace(corner), 3, STAR, 0.22)
				end
			end)
		end
		windPuff(root.CFrame:PointToWorldSpace(Vector3.new(0, 0.3, -3.2)), 2.5, root.CFrame.LookVector)
		every(data.duration + 0.5, function(elapsed)
			if done or not root.Parent then
				return false
			end
			local frame = root.CFrame
			local world = {}
			for i, corner in corners do
				world[i] = frame:PointToWorldSpace(corner)
				cornerStars[i].place(world[i], elapsed * 2 + i)
				anchors[i].CFrame = CFrame.new(world[i])
			end
			for i, edge in edges do
				local a, b = world[i], world[i % 4 + 1]
				local grow = math.min(elapsed / 0.15, 1)
				local tip = a:Lerp(b, grow)
				edge.Size = Vector3.new(0.18, 0.18, (tip - a).Magnitude + 0.05)
				edge.CFrame = CFrame.lookAt(a:Lerp(tip, 0.5), tip)
			end
			pane.CFrame = frame * CFrame.new(0, 0.3, -3.2)
			return true
		end, function()
			if not done then
				drop()
			end
		end)
	elseif data.phase == "Block" then
		local barrier = barriers[character]
		if barrier then
			barrier.ripple(data.from)
		end
	elseif data.phase == "Drop" then
		local barrier = barriers[character]
		if barrier then
			barrier.drop()
		end
	elseif data.phase == "Reflect" then
		-- What it stopped goes back, twice as hard.
		local origin: Vector3 = data.origin
		local barrier = barriers[character]
		if barrier then
			barrier.ripple(nil)
		end
		U.flash(origin, STAR_WHITE, 6, 0.2)
		if data.direction then
			-- A bolt of starlight back at whoever cast it.
			local direction: Vector3 = data.direction
			local star = makeStar(2.2)
			local position = origin
			local travelled = 0
			every(data.range / data.speed + 0.1, function(elapsed, dt)
				local step = data.speed * dt
				position += direction * step
				travelled += step
				star.place(position, elapsed * 12)
				local streak = bar(position, position - direction * 3.5, 0.35, STAR, 0.25)
				U.tween(streak, 0.2, { Transparency = 1, Size = Vector3.new(0.05, 0.05, 3.5) })
				task.delay(0.21, streak.Destroy, streak)
				return travelled < data.range
			end, function()
				star.fade(0.15)
				U.burst(position, {
					color = STAR,
					count = 12,
					size = 0.4,
					speed = NumberRange.new(14, 30),
					lifetime = NumberRange.new(0.15, 0.3),
					spread = 180,
				})
			end)
		else
			-- Straight back into them.
			local target: Vector3 = data.target
			local ray = bar(origin, target, 0.4, STAR_WHITE, 0)
			local glow = bar(origin, target, 1.4, STAR, 0.5)
			fadeOut({ ray, glow }, 0.2)
			U.shockwave(target, STAR, 1, 8, 0.25)
			U.burst(target, {
				color = STAR,
				count = 16,
				size = 0.45,
				speed = NumberRange.new(18, 36),
				lifetime = NumberRange.new(0.15, 0.3),
				streaks = true,
				spread = 180,
			})
		end
		if involves(data, character) then
			CameraShake.Add(0.15)
		end
	end
end

-- Nova Vortex (Half-Crown 4): drawn by the Nova module.
local novaContext: Nova.Context = { anims = ANIMS, play = play }

function handlers.NovaVortex(data, character, root)
	Nova.Handle(novaContext, data, character, root)
end

return {}
