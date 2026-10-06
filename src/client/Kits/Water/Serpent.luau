local VFX = require(script.Parent.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Parent.Soft)
local Fx = require(script.Parent.Fx)

local U = VFX.Util
local rad = math.rad

local WATER, WATER_DEEP, WATER_LIGHT, FOAM = Fx.WATER, Fx.WATER_DEEP, Fx.WATER_LIGHT, Fx.FOAM
local SMOKE = Soft.SMOKE
local key = Soft.key

export type Serpent = {
	head: BasePart,
	scale: number,
	place: (CFrame, number) -> (),
	fade: (number) -> (),
}

type Piece = { part: BasePart, offset: CFrame, base: number, jaw: boolean }
type Segment = { part: BasePart, fin: BasePart?, radius: number, base: number, shown: number }

local function ellipsoid(size: Vector3, color: Color3, material: Enum.Material, transparency: number): BasePart
	local part = U.newPart({ Size = Vector3.one, Color = color, Material = material, Transparency = 1 })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = part
	part:SetAttribute("Base", transparency)
	return part
end

local GLASS = Enum.Material.Glass
local SHIMMER = Enum.Material.ForceField
local NEON = Enum.Material.Neon

local Serpent = {}

function Serpent.new(scale: number, segments: number?): Serpent
	local s = scale
	local pieces: { Piece } = {}
	local function add(part: BasePart, offset: CFrame, jaw: boolean?)
		table.insert(
			pieces,
			{ part = part, offset = offset, base = (part:GetAttribute("Base") :: number?) or 0.05, jaw = jaw == true }
		)
		return part
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	local function toward(x: number, y: number, z: number, dx: number, dy: number, dz: number): CFrame
		local from = Vector3.new(x, y, z) * s
		return CFrame.lookAt(from, from + Vector3.new(dx, dy, dz))
	end

	local skull = add(ellipsoid(Vector3.new(3, 2.4, 3.8) * s, WATER, GLASS, 0.3), at(0, 0.2, 0.2))
	add(ellipsoid(Vector3.new(3.15, 2.55, 3.95) * s, WATER_LIGHT, SHIMMER, 0), at(0, 0.2, 0.2))
	add(ellipsoid(Vector3.new(2.2, 1.5, 3.6) * s, WATER, GLASS, 0.3), at(0, -0.15, -2.4))
	add(ellipsoid(Vector3.new(2.3, 1.6, 3.7) * s, WATER_LIGHT, SHIMMER, 0), at(0, -0.15, -2.4))
	add(ellipsoid(Vector3.new(1, 0.7, 2.6) * s, WATER_LIGHT, GLASS, 0.35), at(0, 0.45, -2.2))
	add(ellipsoid(Vector3.new(1.9, 0.75, 3.4) * s, WATER_DEEP, GLASS, 0.3), at(0, -1.05, -1.9), true)
	add(ellipsoid(Vector3.new(2, 0.85, 3.5) * s, WATER_LIGHT, SHIMMER, 0), at(0, -1.05, -1.9), true)
	for side = -1, 1, 2 do
		for i = 0, 4 do
			local z = -1.3 - i * 0.6
			add(
				U.newPart({ Size = Vector3.new(0.14, 0.4, 0.14) * s, Color = FOAM, Transparency = 1 }),
				at(side * (0.78 - i * 0.06), -0.98, z) * CFrame.Angles(0, rad(45), 0)
			)
			if i < 4 then
				add(
					U.newPart({ Size = Vector3.new(0.12, 0.32, 0.12) * s, Color = FOAM, Transparency = 1 }),
					at(side * (0.62 - i * 0.05), -0.72, z - 0.3) * CFrame.Angles(0, rad(45), 0),
					true
				)
			end
		end
		local eye = add(
			U.newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.42 * s, Color = FOAM, Transparency = 1 }),
			at(side * 1.05, 0.55, -1.3)
		)
		Soft.glow(eye, WATER_LIGHT, 1.8 * s, 0.55)
		add(
			ellipsoid(Vector3.new(0.5, 0.35, 1.5) * s, WATER_LIGHT, GLASS, 0.25),
			toward(side * 0.95, 0.95, -1.1, 0, -0.25, -1)
		)
		add(
			ellipsoid(Vector3.new(0.5, 0.5, 2.2) * s, FOAM, GLASS, 0.2),
			toward(side * 0.9, 1.3, 1, side * 0.3, 0.55, 1)
		)
		add(
			ellipsoid(Vector3.new(0.3, 0.3, 2) * s, WATER_LIGHT, NEON, 0.35),
			toward(side * 1.35, 2.05, 2.5, side * 0.25, 0.3, 1)
		)
		add(
			ellipsoid(Vector3.new(0.1, 1.6, 2.4) * s, FOAM, SHIMMER, 0),
			toward(side * 1.55, 0.3, 1, side * 0.55, 0.1, 1) * CFrame.Angles(0, 0, rad(side * 20))
		)
		add(
			ellipsoid(Vector3.new(0.1, 1.1, 1.8) * s, WATER_LIGHT, SHIMMER, 0),
			toward(side * 1.4, -0.4, 0.6, side * 0.6, -0.2, 1)
		)
	end
	for i = 0, 3 do
		add(
			ellipsoid(Vector3.new(0.12, 1.3 - i * 0.15, 1.5) * s, WATER_LIGHT, SHIMMER, 0),
			at(0, 1.35 - i * 0.12, -0.6 + i * 0.85) * CFrame.Angles(rad(-25), 0, 0)
		)
	end
	add(ellipsoid(Vector3.new(3.8, 3.2, 0.6) * s, WATER_LIGHT, SHIMMER, 0), at(0, 0.3, 2.1))

	local whiskers: { Trail } = {}
	for side = -1, 1, 2 do
		local trail =
			Soft.trail(skull, Vector3.new(side * 0.7, -0.3, -4.1) * s, Vector3.new(side * 0.95, -0.1, -3.9) * s, {
				color = ColorSequence.new(FOAM, WATER_LIGHT),
				transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) }),
				width = NumberSequence.new({ key(0, 1), key(1, 0.3) }),
				lifetime = 0.45,
			})
		table.insert(whiskers, trail)
	end
	local glowLight = Instance.new("PointLight")
	glowLight.Color = WATER
	glowLight.Range = 14 * s
	glowLight.Brightness = 2.5
	glowLight.Parent = skull

	local body: { Segment } = {}
	local count = segments or 9
	for i = 1, count do
		local f = (i - 1) / math.max(count - 1, 1)
		local radius = (1.25 - 0.8 * f) * s
		local part = ellipsoid(Vector3.new(radius * 1.7, radius * 1.7, radius * 2.4), WATER, GLASS, 0.35)
		local fin = if i % 2 == 1
			then ellipsoid(Vector3.new(0.1, radius * 1.4, radius * 1.8), WATER_LIGHT, SHIMMER, 0)
			else nil
		table.insert(body, { part = part, fin = fin, radius = radius, base = 0.35, shown = -1 })
	end
	local anchors: { Attachment } = {}
	for _ = 1, count + 1 do
		table.insert(anchors, Soft.worldAnchor(Vector3.zero))
	end
	local flows: { Beam } = {}
	for i = 1, count do
		local radius = body[i].radius
		table.insert(
			flows,
			Soft.softBeam(anchors[i], anchors[i + 1], {
				color = ColorSequence.new(FOAM, WATER),
				width0 = radius * 2.3,
				width1 = radius * 2,
				transparency = NumberSequence.new({ key(0, 0.55), key(1, 0.6) }),
				texture = SMOKE,
				speed = 5,
				length = radius * 3,
			})
		)
	end

	local path: { Vector3 } = {}
	local born = os.clock()
	local appeared = false
	local spacing = 1.7 * s
	local result = { head = skull, scale = s }

	local function pointAt(distance: number): (Vector3?, Vector3?)
		local walked = 0
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local step = (b - a).Magnitude
			if walked + step >= distance then
				local u = if step > 1e-4 then (distance - walked) / step else 0
				return a:Lerp(b, u), a - b
			end
			walked += step
		end
		return nil, nil
	end

	function result.place(frame: CFrame, open: number)
		local now = os.clock()
		local alpha = math.clamp((now - born) / 0.25, 0, 1)
		local jaw = frame * at(0, -0.8, -0.3) * CFrame.Angles(-open * rad(38), 0, 0) * at(0, 0.8, 0.3)
		for _, piece in pieces do
			piece.part.CFrame = (if piece.jaw then jaw else frame) * piece.offset
			if not appeared then
				piece.part.Transparency = 1 - (1 - piece.base) * alpha
			end
		end
		local back = (frame * at(0, 0.2, 2.2)).Position
		if #path == 0 or (path[1] - back).Magnitude > 0.2 then
			table.insert(path, 1, back)
			if #path > 80 then
				table.remove(path)
			end
		end
		Soft.aim(anchors[1], back, -frame.LookVector)
		local last = back
		for i, segment in body do
			local position, along = pointAt(i * spacing)
			local shown = if position then alpha else 0
			if position and along and along.Magnitude > 1e-3 then
				local sway = math.sin(now * 9 - i * 0.8) * 0.35 * s
				local side = along.Unit:Cross(Vector3.yAxis)
				if side.Magnitude > 1e-3 then
					position += side.Unit * sway
				end
				local cf = CFrame.lookAt(position, position + along)
				segment.part.CFrame = cf
				if segment.fin then
					segment.fin.CFrame = cf * CFrame.new(0, segment.radius * 0.8, 0) * CFrame.Angles(rad(-20), 0, 0)
				end
				last = position
			else
				segment.part.CFrame = CFrame.new(last)
				if segment.fin then
					segment.fin.CFrame = CFrame.new(last)
				end
			end
			if shown ~= segment.shown then
				segment.shown = shown
				segment.part.Transparency = 1 - (1 - segment.base) * shown
				if segment.fin then
					segment.fin.Transparency = 1 - shown
				end
				flows[i].Enabled = shown > 0
			end
			Soft.aim(anchors[i + 1], last, -frame.LookVector)
		end
		if alpha >= 1 then
			appeared = true
		end
	end

	function result.fade(duration: number)
		glowLight.Enabled = false
		for _, trail in whiskers do
			Soft.endTrail(trail)
		end
		local parts: { BasePart } = {}
		for _, piece in pieces do
			table.insert(parts, piece.part)
		end
		for _, segment in body do
			table.insert(parts, segment.part)
			if segment.fin then
				table.insert(parts, segment.fin)
			end
		end
		for _, part in parts do
			for _, child in part:GetChildren() do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
		end
		Soft.fadeOut(parts, duration)
		Soft.fadeBeams(flows, duration, anchors)
	end

	return result
end

return Serpent
