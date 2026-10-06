local CameraShake = require(script.Parent.Parent.Parent.CameraShake)
local VFX = require(script.Parent.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Parent.Soft)

local U = VFX.Util
local rad = math.rad
local UP = Vector3.yAxis

local Fx = require(script.Parent.Fx)
local Base = require(script.Parent.Base)
local Serpent = require(script.Parent.Serpent)

local ANIMS, handlers, play, bump, live = Fx.ANIMS, Fx.handlers, Fx.play, Fx.bump, Fx.live
local easeOut, easeInOut = Fx.easeOut, Fx.easeInOut
local WATER, WATER_LIGHT, FOAM, SAINT = Fx.WATER, Fx.WATER_LIGHT, Fx.FOAM, Fx.SAINT
local ripple, shine, spray, mist, droplets, splash = Fx.ripple, Fx.shine, Fx.spray, Fx.mist, Fx.droplets, Fx.splash
local crown, puddle, geyser, whirl = Fx.crown, Fx.puddle, Fx.geyser, Fx.whirl
local every = Soft.every
local SMOKE, SPARKLE = Soft.SMOKE, Soft.SPARKLE
local near, crater = Base.near, Base.crater

local function ellipsoid(size: Vector3, color: Color3, material: Enum.Material, transparency: number): BasePart
	local part = U.newPart({ Size = Vector3.one, Color = color, Material = material, Transparency = transparency })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = part
	return part
end

type Spine = { place: (Vector3, Vector3, Vector3, number) -> (), fade: (number) -> () }

local function spine(count: number, thick: number): Spine
	type Link = { body: BasePart, skin: BasePart?, radius: number }
	local links: { Link } = {}
	for i = 1, count do
		local f = (i - 1) / math.max(count - 1, 1)
		local radius = thick * (1 - 0.6 * f)
		table.insert(links, {
			body = ellipsoid(Vector3.new(radius * 2, radius * 2, radius * 2.6), WATER, Enum.Material.Glass, 0.3),
			skin = if i % 2 == 1
				then ellipsoid(
					Vector3.new(radius * 2.15, radius * 2.15, radius * 2.8),
					WATER_LIGHT,
					Enum.Material.ForceField,
					0
				)
				else nil,
			radius = radius,
		})
	end
	local flukes = {
		ellipsoid(Vector3.new(0.2, thick * 2.4, thick * 2), FOAM, Enum.Material.ForceField, 0),
		ellipsoid(Vector3.new(0.2, thick * 2.4, thick * 2), FOAM, Enum.Material.ForceField, 0),
		ellipsoid(Vector3.new(0.16, thick * 2, thick * 1.7), WATER_LIGHT, Enum.Material.Glass, 0.3),
		ellipsoid(Vector3.new(0.16, thick * 2, thick * 1.7), WATER_LIGHT, Enum.Material.Glass, 0.3),
	}
	local crest: { BasePart } = {}
	for i = 1, count, 2 do
		local radius = links[i].radius
		table.insert(crest, ellipsoid(Vector3.new(0.12, radius * 1.6, radius * 1.8), FOAM, Enum.Material.ForceField, 0))
	end
	local light = Instance.new("PointLight")
	light.Color = WATER
	light.Range = 18
	light.Brightness = 2
	light.Parent = links[1].body
	local result = {}
	function result.place(a: Vector3, b: Vector3, c: Vector3, wiggle: number)
		local function at(u: number): Vector3
			return Soft.quadratic(a, b, c, u)
		end
		local now = os.clock()
		for i, link in links do
			local u = (i - 1) / (count - 1)
			local position = at(u)
			local ahead = at(math.min(u + 0.02, 1)) - at(math.max(u - 0.02, 0))
			local direction = if ahead.Magnitude > 1e-3 then ahead.Unit else UP
			local side = direction:Cross(UP)
			if side.Magnitude > 1e-3 then
				position += side.Unit * math.sin(now * 10 - i * 0.7) * wiggle * u
			end
			local frame = CFrame.lookAt(position, position + direction)
			link.body.CFrame = frame
			if link.skin then
				link.skin.CFrame = frame
			end
			local index = math.floor((i + 1) / 2)
			if i % 2 == 1 and crest[index] then
				crest[index].CFrame = frame * CFrame.new(0, link.radius * 0.9, 0) * CFrame.Angles(rad(-25), 0, 0)
			end
		end
		local tip = at(1)
		local before = at(0.96)
		local along = tip - before
		local frame = CFrame.lookAt(tip, tip + (if along.Magnitude > 1e-3 then along.Unit else UP))
		for i, fluke in flukes do
			local side = if i % 2 == 1 then 1 else -1
			fluke.CFrame = frame
				* CFrame.new(side * thick * 0.7, 0, -thick * 0.6)
				* CFrame.Angles(0, 0, rad(side * 70))
				* CFrame.Angles(rad(30), 0, 0)
		end
	end
	function result.fade(duration: number)
		light.Enabled = false
		local parts: { BasePart } = {}
		for _, link in links do
			table.insert(parts, link.body)
			if link.skin then
				table.insert(parts, link.skin)
			end
		end
		for _, part in flukes do
			table.insert(parts, part)
		end
		for _, part in crest do
			table.insert(parts, part)
		end
		Soft.fadeOut(parts, duration)
	end
	return result
end

type Swing = {
	tail: Spine,
	token: number,
	started: number,
	slamAt: number?,
	origin: Vector3,
	forward: Vector3,
	length: number,
	ground: Vector3,
}
local swings: { [Model]: Swing } = setmetatable({}, { __mode = "k" }) :: any

local function slamImpact(ground: Vector3, origin: Vector3, forward: Vector3, length: number, character: Model)
	local flat = Vector3.new(forward.X, 0, forward.Z)
	local along = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local floor = Vector3.new(origin.X, ground.Y, origin.Z)
	local tip = floor + along * length
	splash(tip + UP, 9)
	crater(tip, 8)
	U.groundCracks(tip, 12, 12, WATER_LIGHT, 1.6)
	U.groove(floor + along * 2, tip, 2.6, WATER_LIGHT, 2, 140)
	for i = 1, 5 do
		local spot = floor + along * (length * i / 5)
		task.delay(i * 0.025, function()
			crown(spot, 2.2, 4 + i * 0.6, 0.6, 12)
			spray(spot, 10, 30, UP, 40)
		end)
	end
	droplets(tip + UP * 2, 24, 34, UP, 0.6)
	U.shockwave(tip, WATER_LIGHT, 3, 20, 0.45, Enum.Material.ForceField)
	ripple(tip + UP * 0.1, UP, 2, 22, 0.55, 2)
	shine(tip + UP * 0.1, UP, 1, 16, 0.4)
	mist(tip + UP * 2, 6, UP)
	puddle(tip, 8, 2.2)
	U.light(tip, WATER, 7, 36, 0.6)
	if U.isLocal(character) then
		CameraShake.Add(0.4)
		CameraShake.FovKick(10)
	elseif near(tip, 70) then
		CameraShake.Add(0.25)
	end
end

function handlers.SeaDragonGodsTail(data, character, root)
	local phase = data.phase
	if phase == "Raise" then
		play(character, ANIMS.Tail)
		local token = bump(character)
		local delay: number = data.delay or 0.35
		local tail = spine(14, 1.3)
		local state: Swing = {
			tail = tail,
			token = token,
			started = os.clock(),
			slamAt = nil,
			origin = root.Position,
			forward = root.CFrame.LookVector,
			length = 15,
			ground = root.Position - UP * 3,
		}
		swings[character] = state
		every(delay + 1.2, function()
			if not live(character, token) or swings[character] ~= state then
				return false
			end
			local t = os.clock() - state.started
			if state.slamAt and t - state.slamAt > 0.6 then
				return false
			end
			local forward = if state.slamAt then state.forward else root.CFrame.LookVector
			local flat = Vector3.new(forward.X, 0, forward.Z)
			forward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
			local base = (if state.slamAt then state.origin else root.Position) - forward * 0.9 - UP * 0.6
			local grow = easeOut(t / delay)
			local behind = base - forward * 4 + UP * 6 * grow
			local above = base - forward * (2 + 2 * grow) + UP * (2 + 11 * grow)
			if state.slamAt then
				local s = math.clamp((t - state.slamAt) / 0.12, 0, 1)
				local down = s * s
				local floor = Vector3.new(state.origin.X, state.ground.Y, state.origin.Z)
				local strike = floor + forward * state.length + UP * 0.8
				local mid = base + forward * state.length * 0.35 + UP * 9
				tail.place(base, behind:Lerp(mid, easeInOut(s)), above:Lerp(strike, down), 0.4 * (1 - s))
			else
				tail.place(base, behind, above, 0.9)
			end
			return true
		end, function()
			if swings[character] == state then
				swings[character] = nil
			end
			tail.fade(0.3)
		end)
		spray(root.Position - root.CFrame.LookVector * 2, 18, 30, UP, 40)
		whirl(root.Position - UP * 2.8 - root.CFrame.LookVector * 2, UP, 5, delay + 0.2, 7)
		crown(root.Position - UP * 2.85 - root.CFrame.LookVector * 1.5, 2, 5, 0.6, 14)
	elseif phase == "Slam" then
		local state = swings[character]
		local origin: Vector3 = data.origin
		local forward: Vector3 = data.direction
		local length: number = data.length or 15
		local ground: Vector3 = data.ground or origin - UP * 3
		if state then
			state.slamAt = os.clock() - state.started
			state.origin = origin
			state.forward = forward
			state.length = length
			state.ground = ground
		end
		task.delay(0.12, slamImpact, ground, origin, forward, length, character)
	elseif phase == "Cancel" then
		bump(character)
		local state = swings[character]
		swings[character] = nil
		if state then
			state.tail.fade(0.2)
		end
	end
end

type Spin = { done: boolean, serpent: Serpent.Serpent, rings: { Soft.Ring } }
local spins: { [Model]: Spin } = setmetatable({}, { __mode = "k" }) :: any

function handlers.SeaDragonGodsVortex(data, character, root)
	local phase = data.phase
	if phase == "Spin" then
		play(character, ANIMS.Vortex)
		local duration: number = data.duration or 1.6
		local radius: number = data.radius or 9
		local serpent = Serpent.new(0.9, 10)
		local rings: { Soft.Ring } = {}
		for i = 1, 4 do
			table.insert(
				rings,
				Soft.softRing({
					color = ColorSequence.new(FOAM, if i % 2 == 0 then WATER else WATER_LIGHT),
					width0 = 1.6 - i * 0.2,
					width1 = 1.6 - i * 0.2,
					transparency = NumberSequence.new(0.35 + i * 0.05),
					texture = SMOKE,
					speed = 8,
					length = 4,
				})
			)
		end
		local state: Spin = { done = false, serpent = serpent, rings = rings }
		spins[character] = state
		local feet = root.Position - UP * 2.85
		whirl(feet + UP * 0.1, UP, radius, duration + 0.1, 8)
		whirl(feet + UP * 0.15, UP, radius * 0.6, duration + 0.1, -11)
		puddle(feet, radius * 0.9, duration + 0.4)
		every(duration + 0.1, function(elapsed)
			if state.done or spins[character] ~= state then
				return false
			end
			local center = root.Position
			local grow = easeOut(elapsed / 0.2)
			for i, ring in rings do
				local h = -2.4 + i * 1.2
				local r = (2.4 + i * 0.9) * grow + 0.05
				ring.set(
					CFrame.new(center + UP * h)
						* CFrame.Angles(0, elapsed * (10 + i * 2), 0)
						* CFrame.Angles(rad(math.sin(elapsed * 6 + i) * 8), 0, 0),
					r
				)
			end
			local angle = elapsed * 7
			local orbit = radius * 0.7
			local position = center
				+ Vector3.new(math.cos(angle) * orbit, math.sin(elapsed * 5) * 1.2 + 0.5, math.sin(angle) * orbit)
			local tangent = Vector3.new(-math.sin(angle), 0.05, math.cos(angle))
			serpent.place(CFrame.lookAt(position, position + tangent), 0.6)
			if math.random() < 0.7 then
				local out = Vector3.new(math.cos(angle * 1.7), 0, math.sin(angle * 1.7))
				spray(center + out * 2, 4, 30, out:Cross(UP) + out * 0.3, 25)
			end
			return true
		end, function()
			if spins[character] == state then
				spins[character] = nil
			end
			state.done = true
			serpent.fade(0.2)
			for _, ring in rings do
				ring.fade(0.2)
			end
		end)
		mist(root.Position, 4)
		U.light(root.Position, WATER, 4, 26, duration)
	elseif phase == "Deflect" then
		local from: Vector3? = data.from
		local toward = if from then from - root.Position else root.CFrame.LookVector
		local flat = Vector3.new(toward.X, 0, toward.Z)
		local normal = if flat.Magnitude > 1e-3 then flat.Unit else root.CFrame.LookVector
		local spot = root.Position + normal * 4
		splash(spot, 4, normal)
		shine(spot, normal, 0.5, 5, 0.25)
		U.flash(spot, FOAM, 4, 0.12)
		if U.isLocal(character) then
			CameraShake.Add(0.1)
		end
	elseif phase == "Burst" or phase == "Fizzle" then
		local state = spins[character]
		spins[character] = nil
		if state and not state.done then
			state.done = true
			state.serpent.fade(0.15)
			for _, ring in state.rings do
				ring.fade(0.15)
			end
		end
		if phase == "Burst" then
			play(character, ANIMS.VortexEnd)
			local position: Vector3 = data.position or root.Position
			local base = position - UP * 2.85
			splash(position, 9)
			geyser(base, 20, 2.6, 0.9)
			crown(base, 7, 6, 0.8, 22)
			droplets(position + UP * 2, 26, 34, UP, 0.55)
			U.shockwave(position, WATER_LIGHT, 3, 22, 0.45, Enum.Material.ForceField)
			ripple(base + UP * 0.1, UP, 2, 22, 0.55, 2)
			shine(base + UP * 0.1, UP, 1, 18, 0.4)
			U.light(position, WATER, 6, 32, 0.5)
			if U.isLocal(character) then
				CameraShake.Add(0.35)
				CameraShake.FovKick(10)
			elseif near(position, 60) then
				CameraShake.Add(0.2)
			end
		end
	end
end

function handlers.Purify(data)
	local victim: Model? = data.victim
	local victimRoot = U.getRoot(victim)
	if not victim or not victimRoot then
		return
	end
	local position = victimRoot.Position
	U.highlight(victim, SAINT, 0.35, 0.55)
	Soft.twinkle(position + UP, 5, SAINT, 0.3)
	U.burst(position, {
		color = SAINT,
		count = 18,
		size = 0.5,
		speed = NumberRange.new(6, 16),
		lifetime = NumberRange.new(0.4, 0.8),
		acceleration = Vector3.new(0, 18, 0),
		drag = 3,
		spread = 180,
	})
	U.burst(position, {
		texture = SPARKLE,
		color = FOAM,
		count = 10,
		size = 0.8,
		speed = NumberRange.new(4, 10),
		lifetime = NumberRange.new(0.5, 0.9),
		acceleration = Vector3.new(0, 10, 0),
		spread = 180,
	})
	shine(position, UP, 0.5, 4, 0.35, SAINT)
	U.popup(position + UP * 3, "PURIFIED", SAINT, 0.9)
end

return {}
