local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local Ascent = require(script.Parent.Ascent)
local Comet = require(script.Parent.Comet)
local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local Reactions = require(script.Parent.Parent.Parent.Reactions)
local Soft = require(script.Parent.Parent.Parent.Soft)
local VFX = require(script.Parent.Parent.Parent.VFX)

local U = VFX.Util

type Animation = PoseAnimator.Animation

local rad = math.rad

local Fx = require(script.Parent.Fx)
local BLACK, RED, DARK_RED, WHITE, HOT, WHITE_HOT = Fx.BLACK, Fx.RED, Fx.DARK_RED, Fx.WHITE, Fx.HOT, Fx.WHITE_HOT
local UP, ANIMS, handlers, play, bump, live = Fx.UP, Fx.ANIMS, Fx.handlers, Fx.play, Fx.bump, Fx.live
local involves, feetOf, getSword, bladeOf, bladePoint = Fx.involves, Fx.feetOf, Fx.getSword, Fx.bladeOf, Fx.bladePoint
local alongBlade, swordGlow, swordAura, heavyTrail = Fx.alongBlade, Fx.swordGlow, Fx.swordAura, Fx.heavyTrail
local edgeGlow, blackSmoke, redSparks, blackLightning = Fx.edgeGlow, Fx.blackSmoke, Fx.redSparks, Fx.blackLightning
local crackle, crescent, inflow, slashWave, slashMark = Fx.crackle, Fx.crescent, Fx.inflow, Fx.slashWave, Fx.slashMark
local markAngle, impactFrame, lingerSmoke, partEmitter = Fx.markAngle, Fx.impactFrame, Fx.lingerSmoke, Fx.partEmitter
local trailEmitter, glowBurst, bloomPulse = Fx.trailEmitter, Fx.glowBurst, Fx.bloomPulse
local Look = require(script.Parent.Look)
local grimoire, awakenedVisuals = Look.grimoire, Look.awakenedVisuals
local Moon = require(script.Parent.Moon)
local launchedFor = Moon.launchedFor

local hurricaneEmitters: { [Model]: { ParticleEmitter } } = setmetatable({}, { __mode = "k" }) :: any

function handlers.BlackHurricane(data, character, root)
	local token = bump(character)
	local spinning = hurricaneEmitters[character]
	hurricaneEmitters[character] = nil
	if spinning and data.phase ~= "Finish" then
		for _, emitter in spinning do
			emitter.Enabled = false
		end
	end
	if data.phase == "Spin" then
		local duration = if type(data.duration) == "number" then data.duration else 0.9
		local air = data.airborne == true
		play(character, ANIMS.Hurricane)
		local emitters: { ParticleEmitter } = {}
		hurricaneEmitters[character] = emitters
		heavyTrail(character, duration + 0.1)
		U.spiral(root, BLACK, 4.6, 3, duration + 0.05, 5, 0.9, 0.15)
		U.spiral(root, RED, 3.8, 3, duration + 0.05, 3, 0.3, 0.15)
		emitters[1] = partEmitter(root, {
			Texture = U.textures.Smoke,
			Color = ColorSequence.new(BLACK),
			LightEmission = 0,
			Size = NumberSequence.new(1.6, 4),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.4, 0.7),
			Rate = 90,
			Speed = NumberRange.new(8, 16),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(25, 25),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-300, 300),
		}, duration)
		local blade = bladeOf(character)
		if blade then
			emitters[2] = partEmitter(blade, {
				Texture = U.textures.Spark,
				Color = ColorSequence.new(RED, DARK_RED),
				LightEmission = 1,
				Size = NumberSequence.new(0.35, 0),
				Lifetime = NumberRange.new(0.15, 0.35),
				Rate = 70,
				Speed = NumberRange.new(14, 28),
				SpreadAngle = Vector2.new(40, 40),
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				Squash = NumberSequence.new(1.4),
			}, duration)
		end
		crackle(root, duration, 0.05, 4.5)
		for i = 0, 3 do
			task.delay(0.1 + i * 0.2, function()
				if live(character, token) then
					crescent(character, {
						center = CFrame.new(0, 0.1, 0),
						radius = 5.4,
						from = 90,
						to = 450,
						tilt = 0,
						width = 1.5,
						sweep = 0.18,
						fade = 0.22,
					})
				end
			end)
		end
		if air then
			local dive = root.CFrame.LookVector * 40 - UP * 35
			U.speedLines(root, dive.Unit, duration)
			U.bodyTrail(character, BLACK, duration)
		end
		for i = 0, 8 do
			task.delay(i * 0.1, function()
				if not live(character, token) then
					return
				end
				local ground = U.groundBelow(root.Position, { character })
				if ground and root.Position.Y - ground.Position.Y < 4.5 then
					local feet = ground.Position
					U.groundCracks(feet, 3, 2.5, RED, 1)
					U.ringBurst(CFrame.new(feet + UP * 0.1), BLACK, 2, 7, 0.25, 0.25)
					U.debris(feet, 3, 26, 0.7)
					U.burst(feet, {
						texture = U.textures.Smoke,
						color = Color3.fromRGB(150, 140, 130),
						count = 3,
						size = 3,
						speed = NumberRange.new(8, 16),
						lifetime = NumberRange.new(0.4, 0.7),
						lightEmission = 0,
						transparency = 0.5,
						drag = 3,
						spread = 80,
					})
				else
					local below = root.Position - UP * 2.6
					U.ringBurst(CFrame.new(below), if i % 2 == 0 then BLACK else RED, 1.5, 6.5, 0.22, 0.2)
					blackSmoke(below, 3, 2.2, 8)
					redSparks(below, 4, 0.6, -UP)
				end
				if U.isLocal(character) then
					CameraShake.Add(0.05)
				end
			end)
		end
		if U.isLocal(character) then
			CameraShake.FovKick(8)
		end
	elseif data.phase == "Stop" then
		blackSmoke(root.Position, 8, 3, 8)
	elseif data.phase == "Finish" then
		local position = root.Position
		local ground = U.groundBelow(position, { character })
		local grounded = ground ~= nil and position.Y - ground.Position.Y < 4.5
		local feet = if ground and grounded then ground.Position else position - UP * 3
		crescent(character, {
			center = CFrame.new(0, 0.2, 0),
			radius = 7,
			from = 80,
			to = -150,
			tilt = -8,
			width = 2.4,
			sweep = 0.09,
			fade = 0.3,
		})
		U.flash(position, BLACK, 14, 0.3)
		U.flash(position, RED, 9, 0.22)
		U.shockwave(position, RED, 2, 20, 0.4)
		if grounded then
			U.shockwave(feet, BLACK, 3, 18, 0.45, Enum.Material.Glass, 0.4)
			U.ringBurst(CFrame.new(feet + UP * 0.2), BLACK, 1, 16, 0.4, 0.6)
			task.delay(0.04, U.ringBurst, CFrame.new(feet + UP * 0.3), RED, 1, 12, 0.35, 0.3)
			U.groundCracks(feet, 10, 8, RED, 2.5)
			U.debris(feet, 14, 45, 1.1)
		else
			U.impactRing(position - UP * 2, -UP, BLACK, 1.5, 16, 0.45)
			task.delay(0.04, U.impactRing, position - UP * 3, -UP, RED, 1, 11, 0.35)
			redSparks(position, 20, 1, -UP)
		end
		blackLightning(position, 10, 9, 0.3)
		blackSmoke(position, 20, 5, 26)
		redSparks(position + UP, 30, 1.2)
		U.light(position, RED, 12, 30, 0.45)
		if U.isLocal(character) then
			impactFrame(0.8)
			CameraShake.Add(0.4)
		end
	end
end

function handlers.BlackSlash(data, character, root)
	if data.phase == "Windup" then
		play(character, ANIMS.BlackSlash)
		swordGlow(character, RED, 0.3, 0.3)
		swordAura(character, 0.3, 40)
		task.delay(0.11, heavyTrail, character, 0.25)
		for i = 0, 5 do
			task.delay(i * 0.03, function()
				local blade = bladeOf(character)
				if blade then
					inflow(blade.Position, 5)
				end
			end)
		end
	elseif data.phase == "Projectile" then
		local origin: Vector3 = data.origin
		local direction: Vector3 = data.direction
		local grand = data.grand == true
		slashWave(data)
		U.flash(origin, BLACK, if grand then 16 else 8, 0.22)
		U.flash(origin, RED, if grand then 10 else 5, 0.15)
		U.impactRing(origin, direction, RED, 1, if grand then 12 else 7, 0.25)
		task.delay(0.04, U.impactRing, origin + direction * 2, direction, BLACK, 0.8, if grand then 10 else 6, 0.25)
		U.burst(origin, {
			color = RED,
			count = if grand then 28 else 14,
			size = 0.7,
			speed = NumberRange.new(35, 65),
			lifetime = NumberRange.new(0.15, 0.35),
			streaks = true,
			spread = 30,
			direction = direction,
		})
		blackLightning(origin, if grand then 8 else 4, if grand then 7 else 4)
		U.light(origin, RED, if grand then 12 else 7, if grand then 30 else 18, 0.35)
		if U.isLocal(character) then
			CameraShake.FovKick(if grand then 12 else 6)
			CameraShake.Add(if grand then 0.3 else 0.12)
		end
	end
end

local function fissure(start: Vector3, direction: Vector3, length: number)
	local ground = U.groundBelow(start)
	if not ground then
		return
	end
	local floorY = ground.Position.Y
	local flat = Vector3.new(direction.X, 0, direction.Z).Unit
	local steps = math.floor(length / 3)
	local function floorAt(distance: number): Vector3?
		local p = Vector3.new(start.X, floorY, start.Z) + flat * distance
		local hit = U.groundBelow(p + UP * 3)
		if not hit or hit.Position.Y < floorY - 4.5 then
			return nil
		end
		return hit.Position + UP * 0.05
	end
	for i = 0, steps - 1 do
		task.delay(i * 0.025, function()
			local a, b = floorAt(i * 3), floorAt(i * 3 + 3)
			if not (a and b) then
				return
			end
			local look = CFrame.lookAt((a + b) / 2, b)
			local segment = (b - a).Magnitude + 0.2
			local width = 1.6 * (1 - i / steps) + 0.5
			local crack = U.newPart({
				Size = Vector3.new(width, 0.08, segment),
				CFrame = look,
				Color = Color3.fromRGB(12, 11, 11),
				Material = Enum.Material.SmoothPlastic,
			})
			local hot = U.newPart({
				Size = Vector3.new(width * 0.45, 0.1, segment),
				CFrame = look + Vector3.new(0, 0.01, 0),
				Color = RED,
			})
			U.tween(hot, 1.2, { Transparency = 1 })
			task.delay(2.4, function()
				U.tween(crack, 0.6, { Transparency = 1 })
			end)
			task.delay(3.1, function()
				crack:Destroy()
				hot:Destroy()
			end)
			if i % 2 == 0 then
				U.groundRocks(b, 4, 1.6 + width * 0.5, 1.2 + width * 0.6)
				U.lightning(a + UP * 0.3, b + UP * 0.3 + U.randomUnit() * 0.8, BLACK, RED, 0.16, 0.25)
			end
			if i % 3 == 0 then
				blackSmoke(b + UP * 0.5, 4, 2.5, 6)
			end
		end)
	end
end

local grandBlades: { [Model]: () -> () } = setmetatable({}, { __mode = "k" }) :: any

local function growGrandBlade(character: Model, duration: number)
	local blade = bladeOf(character)
	if not blade then
		return
	end
	local core = U.newPart({ Size = Vector3.new(0.5, 0.1, 1.6), Color = BLACK, Material = Enum.Material.SmoothPlastic })
	local glow = U.newPart({ Size = Vector3.new(0.9, 0.1, 2.3), Color = RED, Transparency = 0.55 })
	local start = os.clock()
	local length = 0
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not blade.Parent then
			connection:Disconnect()
			core:Destroy()
			glow:Destroy()
			return
		end
		local t = os.clock() - start
		length = 10
			* TweenService:GetValue(math.clamp(t / duration, 0, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local wobble = 1 + 0.06 * math.sin(t * 40)
		local base = alongBlade(blade, 2.1) * CFrame.new(0, length / 2, 0)
		core.Size = Vector3.new(0.45 * wobble, length + 0.1, 1.5)
		core.CFrame = base
		glow.Size = Vector3.new(0.9 * wobble, length + 0.6, 2.4 * wobble)
		glow.CFrame = base
	end)
	local function dissolve()
		grandBlades[character] = nil
		connection:Disconnect()
		U.tween(core, 0.3, { Transparency = 1, Size = core.Size * Vector3.new(0.2, 1, 0.2) })
		U.tween(glow, 0.25, { Transparency = 1 })
		task.delay(0.35, function()
			core:Destroy()
			glow:Destroy()
		end)
	end
	grandBlades[character] = dissolve
	task.delay(duration + 1.5, function()
		if grandBlades[character] == dissolve then
			dissolve()
		end
	end)
end

function handlers.GrandDivider(data, character, root)
	local phase = data.phase
	local token = bump(character)
	local air = data.airborne == true
	if phase == "Charge" then
		play(character, if air then ANIMS.AirDividerCharge else ANIMS.GrandCharge)
		swordGlow(character, BLACK, 0.75, 0.25)
		swordAura(character, 0.75, 50)
		growGrandBlade(character, 0.6)
		if air then
			U.ringBurst(CFrame.new(root.Position), BLACK, 12, 2, 0.7, 0.35)
			task.delay(0.3, U.ringBurst, CFrame.new(root.Position), DARK_RED, 10, 1.5, 0.4, 0.2)
			U.ringBurst(CFrame.new(root.Position) * CFrame.Angles(rad(90), 0, 0), BLACK, 10, 2, 0.7, 0.3)
			blackSmoke(root.Position, 12, 3, 8)
		else
			local feet = feetOf(character, root)
			U.ringBurst(CFrame.new(feet + UP * 0.1), BLACK, 12, 2, 0.7, 0.35)
			task.delay(0.3, U.ringBurst, CFrame.new(feet + UP * 0.12), DARK_RED, 10, 1.5, 0.4, 0.2)
			task.delay(0.25, U.groundCracks, feet, 8, 6, RED, 2)
			blackSmoke(feet + UP * 0.3, 12, 3, 8)
		end
		local start = os.clock()
		task.spawn(function()
			while os.clock() - start < 0.7 and live(character, token) do
				local tip = bladePoint(character, 2.1)
				if tip then
					inflow(tip, 9)
					inflow(tip, 6)
					if math.random() < 0.5 then
						blackLightning(tip + UP * 3, 1, 4, 0.14)
					end
				end
				if U.isLocal(character) then
					CameraShake.Add(0.04)
				end
				task.wait(0.04)
			end
		end)
		for _, at in { 0.2, 0.45 } do
			task.delay(at, function()
				local tip = bladePoint(character, 2.1)
				if tip and live(character, token) then
					U.pillar(tip, BLACK, 1.2, 40, 0.5, Enum.Material.SmoothPlastic, 0.2)
					U.pillar(tip, RED, 0.6, 46, 0.4)
				end
			end)
		end
		if U.isLocal(character) then
			CameraShake.FovKick(-6)
		end
	elseif phase == "Cancel" then
		local dissolve = grandBlades[character]
		if dissolve then
			dissolve()
		end
		blackSmoke(root.Position + UP * 3, 8, 3, 6)
	elseif phase == "Release" then
		play(character, if air then ANIMS.AirDividerRelease else ANIMS.GrandRelease)
		heavyTrail(character, 0.35)
		crescent(character, {
			center = CFrame.new(0, 0.6, 0),
			radius = 10,
			from = 100,
			to = if air then -260 else -40,
			tilt = 90,
			width = 3.6,
			sweep = if air then 0.16 else 0.1,
			fade = 0.35,
		})
		task.delay(0.35, function()
			local dissolve = grandBlades[character]
			if dissolve then
				dissolve()
			end
		end)
		local look = root.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z).Unit
		local function groundStrike(strike: Vector3)
			U.flash(strike + UP, WHITE, 6, 0.08)
			U.flash(strike + UP, BLACK, 16, 0.35)
			U.flash(strike + UP, RED, 10, 0.25)
			U.shockwave(strike, BLACK, 4, 28, 0.5, Enum.Material.Glass, 0.35)
			U.shockwave(strike, RED, 3, 22, 0.45)
			U.ringBurst(CFrame.new(strike + UP * 0.2), BLACK, 1, 18, 0.45, 0.7)
			task.delay(0.05, U.ringBurst, CFrame.new(strike + UP * 0.3), RED, 1, 13, 0.4, 0.35)
			U.groundCracks(strike, 12, 10, RED, 3)
			U.groundRocks(strike, 14, 5, 2.6)
			U.debris(strike, 18, 50, 1.3)
			blackSmoke(strike + UP, 24, 6, 30)
			blackLightning(strike + UP, 10, 9, 0.3)
			U.light(strike + UP * 2, RED, 14, 40, 0.5)
			fissure(strike, forward, 42)
		end
		task.delay(0.08, function()
			if not character.Parent then
				return
			end
			if air then
				local burst = root.Position + forward * 4 - UP * 3
				U.flash(burst, WHITE, 5, 0.08)
				U.flash(burst, BLACK, 13, 0.3)
				U.flash(burst, RED, 8, 0.22)
				U.impactRing(burst, -UP, BLACK, 2, 18, 0.45)
				task.delay(0.04, U.impactRing, burst, -UP, RED, 1.5, 13, 0.4)
				blackLightning(burst, 8, 7, 0.28)
				redSparks(burst, 24, 1.1, -UP)
				U.light(burst, RED, 12, 30, 0.4)
				local ground = U.groundBelow(burst, { character }, 60)
				if ground then
					local drop = burst.Y - ground.Position.Y
					task.delay(math.clamp(drop / 150, 0, 0.35), function()
						groundStrike(ground.Position)
					end)
				end
			else
				groundStrike(feetOf(character, root) + forward * 4.5)
			end
			if U.isLocal(character) then
				impactFrame(1.2)
				U.screenFlash(RED, 0.35)
				CameraShake.FovKick(14)
				CameraShake.Add(0.5)
			end
		end)
	end
end

local SWORD_NAMES = {
	Slayer = "DEMON-SLAYER SWORD",
	Destroyer = "DEMON-DESTROYER SWORD",
	Slasher = "DEMON-SLASHER KATANA",
}

function handlers.SwordSwap(data, character, root)
	local kind = data.sword
	play(character, ANIMS.SwordSwap)
	local old = getSword(character)
	if old then
		for _, part in old:GetDescendants() do
			if part:IsA("BasePart") then
				U.tween(part, 0.2, { Transparency = 1 })
			end
		end
		local blade = bladeOf(character)
		if blade then
			blackSmoke(blade.Position, 12, 3, 8)
			redSparks(blade.Position, 10, 0.6)
			swordAura(character, 0.2, 40)
		end
	end
	local visual = awakenedVisuals[character]
	local book = visual and visual.book
	if not book then
		local beside = grimoire(character, root)
		beside.open(0.18)
		task.delay(0.65, beside.close)
		book = beside
	end

	local arrived = false
	local connection
	connection = character.ChildAdded:Connect(function(child)
		if child.Name ~= "KitWeapon" or arrived then
			return
		end
		arrived = true
		connection:Disconnect()
		task.defer(function()
			for _, part in child:GetDescendants() do
				if part:IsA("BasePart") then
					local shown = part.Transparency
					part.Transparency = 1
					U.tween(part, 0.15, { Transparency = shown })
				end
			end
			book.burst()
			local blade = bladeOf(character)
			if blade then
				glowBurst(blade.Position, 4, 0.3)
				edgeGlow(character, 0.45, 1)
				blackLightning(blade.Position, 4, 3, 0.2)
				blackSmoke(blade.Position, 8, 2.5, 8)
			end
			U.ringBurst(CFrame.new(root.Position - UP * 2.8), BLACK, 1, 9, 0.35, 0.3)
			U.popup(root.Position + UP * 4.5, SWORD_NAMES[kind] or "", RED, 1.6)
			if U.isLocal(character) then
				CameraShake.Add(0.15)
			end
		end)
	end)
	task.delay(1, function()
		if connection.Connected then
			connection:Disconnect()
		end
	end)
end

local function cutLine(from: Vector3, to: Vector3, width: number, hold: number)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local cframe = CFrame.lookAt(from:Lerp(to, 0.5), to)
	local glow = U.newPart({
		Size = Vector3.new(0.05, width * 2.6, length),
		CFrame = cframe,
		Color = RED,
		Transparency = 0.45,
	})
	local dark = U.newPart({
		Size = Vector3.new(0.08, width * 1.2, length),
		CFrame = cframe,
		Color = BLACK,
		Material = Enum.Material.SmoothPlastic,
	})
	local core = U.newPart({ Size = Vector3.new(0.12, width * 0.4, length), CFrame = cframe, Color = WHITE_HOT })
	task.delay(hold, function()
		U.tween(glow, 0.35, { Size = Vector3.new(0.05, width * 5, length), Transparency = 1 })
		U.tween(dark, 0.35, { Size = Vector3.new(0.08, width * 3, length), Transparency = 1 })
		U.tween(core, 0.2, { Size = Vector3.new(0.12, 0.01, length), Transparency = 1 })
	end)
	task.delay(hold + 0.4, function()
		glow:Destroy()
		dark:Destroy()
		core:Destroy()
	end)
end

local function hideSword(character: Model): () -> ()
	local sword = getSword(character)
	local shown: { [BasePart]: number } = {}
	if sword then
		for _, part in sword:GetDescendants() do
			if part:IsA("BasePart") then
				shown[part] = part.Transparency
				part.Transparency = 1
			end
		end
	end
	return function()
		for part, transparency in shown do
			part.Transparency = transparency
		end
	end
end

local function looseSword(character: Model): (Model?, BasePart?)
	local sword = getSword(character)
	if not sword or not sword:FindFirstChild("Handle") then
		return nil, nil
	end
	local copy = sword:Clone()
	for _, item in copy:GetDescendants() do
		if item:IsA("JointInstance") then
			local inside = item.Part0 ~= nil
				and item.Part0:IsDescendantOf(copy)
				and item.Part1 ~= nil
				and item.Part1:IsDescendantOf(copy)
			if not inside then
				item:Destroy()
			end
		elseif item:IsA("BasePart") then
			item.Anchored = item.Name == "Handle"
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
		elseif item:IsA("Trail") then
			item.Enabled = true
		end
	end
	copy.Parent = U.folder
	return copy, copy:FindFirstChild("Handle") :: BasePart?
end

type Recall = {
	copy: Model,
	handle: BasePart,
	restore: () -> (),
	origin: Vector3,
	target: Vector3,
	out: number,
	position: Vector3,
	phase: string,
	speed: number,
	born: number,
}
local recalls: { [Model]: Recall } = {}
local RECALL_MIDDLE = 2.6

local function endRecall(character: Model)
	local recall = recalls[character]
	if recall then
		recalls[character] = nil
		recall.copy:Destroy()
		recall.restore()
	end
end

local function driveRecall(character: Model, recall: Recall)
	local spin = 0
	local lastBolt = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if recalls[character] ~= recall then
			connection:Disconnect()
			return
		end
		local now = os.clock()
		local age = now - recall.born
		if age > 4 or not character.Parent then
			connection:Disconnect()
			endRecall(character)
			return
		end
		spin += dt * (if recall.phase == "hang" then 20 else 32)
		local root = U.getRoot(character)
		if recall.phase == "out" then
			local a = math.clamp(age / recall.out, 0, 1)
			recall.position = recall.origin:Lerp(recall.target, 1 - (1 - a) ^ 2)
			if a >= 1 then
				recall.phase = "hang"
			end
		elseif recall.phase == "back" and root then
			local offset = root.Position - recall.position
			local step = recall.speed * dt
			if offset.Magnitude <= math.max(step, 2.5) then
				recall.position = root.Position
				recall.phase = "home"
			else
				recall.position += offset.Unit * step
			end
			if now - lastBolt > 0.05 then
				lastBolt = now
				local arm = character:FindFirstChild("Left Arm") :: BasePart?
				if arm then
					U.lightning((arm.CFrame * CFrame.new(0, -1, 0)).Position, recall.position, BLACK, RED, 0.1, 0.08)
				end
			end
		end
		local bob = if recall.phase == "hang" then UP * math.sin(age * 7) * 0.3 else Vector3.zero
		recall.handle.CFrame = CFrame.new(recall.position + bob)
			* CFrame.Angles(0, spin, 0)
			* CFrame.Angles(0, 0, math.pi / 2)
			* CFrame.new(0, -RECALL_MIDDLE, 0)
	end)
end

function handlers.SlayerRecall(data, character, root)
	local phase = data.phase
	if phase == "Wind" then
		play(character, ANIMS.RecallThrow)
		swordGlow(character, RED, 0.35, 0.3)
		swordAura(character, 0.3, 40)
		edgeGlow(character, 0.35, 0.8)
		for i = 0, 4 do
			task.delay(i * 0.05, function()
				local point = bladePoint(character, 1)
				if point then
					inflow(point, 5)
				end
			end)
		end
	elseif phase == "Throw" then
		endRecall(character)
		local copy, handle = looseSword(character)
		local restore = hideSword(character)
		if not copy or not handle then
			restore()
			return
		end
		local origin: Vector3 = data.origin
		local target: Vector3 = data.target
		local blade = copy:FindFirstChild("Blade", true)
		if blade and blade:IsA("BasePart") then
			local glow = Instance.new("PointLight")
			glow.Color = RED
			glow.Range = 14
			glow.Brightness = 3
			glow.Parent = blade
			partEmitter(blade, {
				Texture = U.textures.Smoke,
				Color = ColorSequence.new(BLACK),
				Size = NumberSequence.new(1.4, 0),
				Transparency = NumberSequence.new(0.35, 1),
				Lifetime = NumberRange.new(0.25, 0.4),
				Rate = 70,
				Speed = NumberRange.new(0, 1),
				LightEmission = 0,
			}, 4)
		end
		local recall: Recall = {
			copy = copy,
			handle = handle,
			restore = restore,
			origin = origin,
			target = target,
			out = data.out or 0.42,
			position = origin,
			phase = "out",
			speed = 95,
			born = os.clock(),
		}
		recalls[character] = recall
		driveRecall(character, recall)
		local direction = if (target - origin).Magnitude > 0.1 then (target - origin).Unit else root.CFrame.LookVector
		glowBurst(origin, 3, 0.25)
		U.impactRing(origin, direction, RED, 1, 7, 0.25)
		task.delay(0.04, U.impactRing, origin + direction * 2, direction, BLACK, 0.8, 6, 0.25)
		U.burst(origin, {
			color = RED,
			count = 14,
			size = 0.5,
			speed = NumberRange.new(30, 55),
			lifetime = NumberRange.new(0.15, 0.3),
			streaks = true,
			spread = 25,
			direction = direction,
		})
		if U.isLocal(character) then
			CameraShake.Add(0.12)
			CameraShake.FovKick(5)
		end
	elseif phase == "Return" then
		local recall = recalls[character]
		if recall then
			recall.phase = "back"
			recall.speed = data.speed or recall.speed
			glowBurst(recall.position, 3.5, 0.3)
			blackLightning(recall.position, 3, 3, 0.2)
		end
		play(character, ANIMS.RecallCall)
	elseif phase == "Catch" then
		endRecall(character)
		if data.instant then
			return
		end
		play(character, ANIMS.RecallCatch)
		local point = bladePoint(character, 0.5) or root.Position
		glowBurst(point, 3.5, 0.3)
		edgeGlow(character, 0.4, 1)
		redSparks(point, 12, 0.6)
		blackSmoke(point, 6, 2.5, 6)
		U.ringBurst(CFrame.new(root.Position), RED, 1, 6, 0.25, 0.2)
		if U.isLocal(character) then
			CameraShake.Add(0.12)
		end
	end
end

local function destroyerFlare(character: Model, duration: number)
	local sword = getSword(character)
	if not sword then
		return
	end
	for _, part in sword:GetDescendants() do
		if part:IsA("BasePart") and (part.Name == "GuardPlate" or part.Name:sub(1, 6) == "Clover") then
			local color = part.Color
			U.tween(part, 0.1, { Color = WHITE_HOT })
			task.delay(duration, function()
				if part.Parent then
					U.tween(part, 0.3, { Color = color })
				end
			end)
		end
	end
end

function handlers.CausalityBreak(data, character, root)
	local phase = data.phase
	if phase == "Plant" then
		bump(character)
		play(character, ANIMS.CausalityPlant)
		edgeGlow(character, 0.5, 0.8)
		swordAura(character, 0.45, 40)
		destroyerFlare(character, 0.7)
		task.delay(0.25, heavyTrail, character, 0.2)
	elseif phase == "Break" then
		local tip = bladePoint(character, 2.1) or root.Position + root.CFrame.LookVector * 3
		local ground = U.groundBelow(tip + UP * 1.5, { character }, 6)
		local point = if ground then ground.Position else tip
		glowBurst(point, 5, 0.35)
		bloomPulse(point, 0.7, 0.5)
		U.groundCracks(point, 9, 9, RED, 1.6)
		U.groundRocks(point, 8, 5, 1.2)
		U.debris(point, 10, 30, 0.8)
		U.pillar(point, RED, 1.2, 16, 0.35)
		U.ringBurst(CFrame.new(point + UP * 0.3), WHITE, 2, 18, 0.4, 0.25)
		task.delay(0.05, U.ringBurst, CFrame.new(point + UP * 0.3), RED, 2, 18, 0.5, 0.45)
		task.delay(0.1, U.ringBurst, CFrame.new(point + UP * 0.3), BLACK, 2, 16, 0.55, 0.6)
		Soft.lightRing(point + UP * 0.4, UP, 1, 20, 0.45, RED)
		task.delay(0.06, Soft.lightRing, point + UP * 0.6, UP, 1, 14, 0.4, RED)
		blackLightning(point, 6, 5)
		for i, target in data.targets do
			local targetRoot = U.getRoot(target)
			if targetRoot then
				task.delay(0.03 * i, function()
					if not targetRoot.Parent then
						return
					end
					local feet = targetRoot.Position - UP * 2.8
					U.lightning(point, feet, BLACK, RED, 0.25, 0.25, true)
					U.lightning(point + UP * 0.2, feet + UP * 0.2, RED, HOT, 0.08, 0.2)
					U.ringBurst(CFrame.new(feet + UP * 0.2), WHITE, 4, 0.5, 0.3, 0.12)
					U.shards(targetRoot.Position, WHITE, 8)
					U.shards(targetRoot.Position, RED, 6)
					glowBurst(targetRoot.Position, 3, 0.25)
					U.highlight(target, WHITE, 0.25, 0.5)
					U.popup(targetRoot.Position + UP * 3.5, "BROKEN", WHITE, 1)
				end)
			end
		end
		if U.isLocal(character) or #data.targets > 0 and involves({ target = data.targets[1] }, character) then
			CameraShake.Add(0.3)
			CameraShake.FovKick(8)
			impactFrame(0.5)
		end
	elseif phase == "Pull" then
		play(character, ANIMS.CausalityPull)
		heavyTrail(character, 0.25)
		local tip = bladePoint(character, 2.1)
		if tip then
			blackSmoke(tip, 8, 3, 6)
			redSparks(tip, 10, 0.6, UP)
		end
	elseif phase == "Cancel" then
		bump(character)
	end
end

local cometContext: Comet.Context = {
	anims = ANIMS,
	play = play,
	held = function(victim: Model): Animation?
		return if victim:GetAttribute("Kit") == "AntiMagic" then ANIMS.Grabbed else Reactions.Grabbed
	end,
	wings = function(character: Model): Comet.Wings?
		return awakenedVisuals[character]
	end,
	blackSmoke = blackSmoke,
	redSparks = redSparks,
	blackLightning = blackLightning,
	glowBurst = glowBurst,
	bloomPulse = bloomPulse,
	heavyTrail = heavyTrail,
	edgeGlow = edgeGlow,
	swordAura = swordAura,
	trailEmitter = trailEmitter,
	impactFrame = impactFrame,
	lingerSmoke = lingerSmoke,
}
local cometStops: { [Model]: () -> () } = setmetatable({}, { __mode = "k" }) :: any

function handlers.BlackComet(data, character, root)
	local phase = data.phase
	if phase == "Drag" then
		local stop = Comet.Play(cometContext, data, character, root)
		if stop then
			cometStops[character] = stop
		end
	elseif phase == "Abort" then
		local stop = cometStops[character]
		cometStops[character] = nil
		if stop then
			stop()
		end
	else
		handlers.BlackMeteorite(data, character, root)
	end
end

local ascentContext: Ascent.Context = {
	anims = ANIMS,
	play = play,
	launched = launchedFor,
	wings = function(character: Model): Comet.Wings?
		return awakenedVisuals[character]
	end,
	crescent = crescent,
	cutLine = cutLine,
	blackSmoke = blackSmoke,
	redSparks = redSparks,
	blackLightning = blackLightning,
	glowBurst = glowBurst,
	bloomPulse = bloomPulse,
	heavyTrail = heavyTrail,
	edgeGlow = edgeGlow,
	swordAura = swordAura,
	trailEmitter = trailEmitter,
	impactFrame = impactFrame,
	lingerSmoke = lingerSmoke,
}

function handlers.BlackAscent(data, character, root)
	local phase = data.phase
	if phase == "Cut" then
		play(character, ANIMS.Rising)
		heavyTrail(character, 0.25)
		edgeGlow(character, 0.3, 0.8)
		crescent(character, {
			center = CFrame.new(0, 0.4, 0),
			radius = 5.5,
			from = -60,
			to = 110,
			tilt = 90,
			width = 1.6,
			sweep = 0.1,
			fade = 0.3,
			glow = 0.6,
		})
	elseif phase == "Whiff" then
		blackSmoke(bladePoint(character, 2) or root.Position, 4, 1.5, 3)
	elseif phase == "Launch" then
		Ascent.Play(ascentContext, data, character, root)
	end
end

function handlers.Zetten(data, character, root)
	local phase = data.phase
	if phase == "Stance" then
		local token = bump(character)
		local duration = data.duration or 1
		play(character, ANIMS.ZettenStance)
		edgeGlow(character, duration, 0.4)
		task.spawn(function()
			local start = os.clock()
			while live(character, token) and os.clock() - start < duration do
				U.ringBurst(CFrame.new(feetOf(character, root) + UP * 0.2), WHITE, 2, 20, 0.6, 0.06)
				task.wait(0.33)
			end
		end)
		if U.isLocal(character) then
			U.colorGrade({ Saturation = -0.35 }, 0.15, duration, 0.3)
		end
	elseif phase == "Strike" then
		bump(character)
		play(character, ANIMS.ZettenCut)
		local from: Vector3 = data.from
		local to: Vector3 = data.to
		local direction = if (to - from).Magnitude > 0.1 then (to - from).Unit else root.CFrame.LookVector
		cutLine(from + UP * 0.5, to + UP * 0.5, 0.35, 0.25)
		glowBurst(from, 2, 0.2)
		crescent(character, {
			center = CFrame.new(0, 0.4, 0),
			radius = 5,
			from = -110,
			to = 70,
			tilt = 55,
			width = 1.4,
			sweep = 0.07,
			fade = 0.3,
			glow = 0.9,
		})
		local targetRoot = U.getRoot(data.target)
		if targetRoot then
			glowBurst(targetRoot.Position, 4, 0.3)
			slashMark(targetRoot.Position, markAngle(targetRoot.Position, (direction + UP * 0.8).Unit), 7, 0.4)
			U.burst(targetRoot.Position, {
				color = RED,
				count = 20,
				size = 0.6,
				speed = NumberRange.new(30, 65),
				lifetime = NumberRange.new(0.15, 0.35),
				streaks = true,
				spread = 40,
				direction = direction,
			})
			blackLightning(targetRoot.Position, 5, 4)
			Soft.lightRing(targetRoot.Position, direction, 0.5, 9, 0.3, RED)
		end
		bloomPulse(to, 0.6, 0.4)
		if involves(data, character) then
			CameraShake.Add(0.28)
			CameraShake.FovKick(10)
			impactFrame(0.8)
		end
	elseif phase == "Cut" then
		bump(character)
		play(character, ANIMS.ZettenCut)
		heavyTrail(character, 0.2)
		crescent(character, {
			center = CFrame.new(0, 0.4, 0),
			radius = 5,
			from = -110,
			to = 70,
			tilt = 55,
			width = 1.2,
			sweep = 0.08,
			fade = 0.3,
			glow = 0.6,
		})
		if U.isLocal(character) then
			CameraShake.Add(0.1)
		end
	elseif phase == "Cancel" then
		bump(character)
	end
end

return {}
