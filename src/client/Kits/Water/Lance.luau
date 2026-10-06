local VFX = require(script.Parent.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Parent.Soft)
local Fx = require(script.Parent.Fx)

local U = VFX.Util
local rad = math.rad

local WATER, WATER_LIGHT, FOAM, SILVER = Fx.WATER, Fx.WATER_LIGHT, Fx.FOAM, Fx.SILVER
local GLASS = Enum.Material.Glass
local SHIMMER = Enum.Material.ForceField
local NEON = Enum.Material.Neon

export type Lance = {
	parts: { BasePart },
	bases: { [BasePart]: number },
	place: (CFrame, number) -> (),
	show: (number) -> (),
	fade: (number) -> (),
	tip: (CFrame) -> Vector3,
	length: number,
	blade: BasePart,
}

type Piece = { part: BasePart, offset: CFrame, spins: boolean }

local Lance = {}

local function ellipsoid(size: Vector3, color: Color3, material: Enum.Material): BasePart
	local part = U.newPart({ Size = Vector3.one, Color = color, Material = material, Transparency = 1 })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = part
	return part
end

local ALONG = CFrame.Angles(0, rad(90), 0)

function Lance.new(dragon: boolean): Lance
	local length = if dragon then 7.2 else 6
	local butt, base = length * 0.3, -length * 0.45
	local bladeLength = length * (if dragon then 0.3 else 0.25)
	local pieces: { Piece } = {}
	local bases: { [BasePart]: number } = {}
	local function add(part: BasePart, offset: CFrame, transparency: number, spins: boolean?): BasePart
		table.insert(pieces, { part = part, offset = offset, spins = spins == true })
		bases[part] = transparency
		return part
	end
	local shaftLength = butt - base
	local middle = (butt + base) / 2
	add(
		U.newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(shaftLength, 0.36, 0.36),
			Color = WATER_LIGHT,
			Material = GLASS,
		}),
		CFrame.new(0, 0, middle) * ALONG,
		0.2
	)
	add(
		U.newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(shaftLength, 0.14, 0.14),
			Color = FOAM,
			Material = NEON,
		}),
		CFrame.new(0, 0, middle) * ALONG,
		0.3
	)
	for i = 0, 11 do
		local z = butt - 0.3 - i * (shaftLength - 0.6) / 11
		local angle = i * 1.05
		add(
			U.newPart({ Size = Vector3.new(0.13, 0.13, 0.62), Color = WATER, Material = SHIMMER }),
			CFrame.new(0, 0, z) * CFrame.Angles(0, 0, angle) * CFrame.new(0.27, 0, 0) * CFrame.Angles(rad(30), 0, 0),
			0,
			true
		)
	end
	add(ellipsoid(Vector3.new(0.5, 0.5, 0.5), SILVER, GLASS), CFrame.new(0, 0, butt), 0.1)
	add(
		U.newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 1.05, 1.05),
			Color = SILVER,
			Material = GLASS,
		}),
		CFrame.new(0, 0, base) * ALONG,
		0.15
	)
	add(
		U.newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.08, 1.15, 1.15),
			Color = FOAM,
			Material = NEON,
		}),
		CFrame.new(0, 0, base - 0.08) * ALONG,
		0.25
	)
	local wing = if dragon then 1.5 else 1.1
	for side = -1, 1, 2 do
		add(
			ellipsoid(Vector3.new(0.12, wing * 0.55, wing), FOAM, SHIMMER),
			CFrame.new(side * 0.5, 0, base + 0.25) * CFrame.Angles(0, 0, rad(side * 90)) * CFrame.Angles(rad(-25), 0, 0),
			0
		)
		add(
			ellipsoid(Vector3.new(0.1, wing * 0.4, wing * 0.8), WATER_LIGHT, GLASS),
			CFrame.new(side * 0.45, 0, base + 0.3) * CFrame.Angles(0, 0, rad(side * 90)) * CFrame.Angles(rad(-35), 0, 0),
			0.3
		)
	end
	local bladeWidth = if dragon then 1.1 else 0.85
	local blade = add(
		ellipsoid(Vector3.new(bladeWidth, 0.22, bladeLength * 2), WATER_LIGHT, GLASS),
		CFrame.new(0, 0, base - bladeLength),
		0.15
	)
	add(
		ellipsoid(Vector3.new(bladeWidth * 1.08, 0.1, bladeLength * 2.04), FOAM, NEON),
		CFrame.new(0, 0, base - bladeLength),
		0.45
	)
	add(
		ellipsoid(Vector3.new(bladeWidth * 1.25, 0.3, bladeLength * 2.1), WATER, SHIMMER),
		CFrame.new(0, 0, base - bladeLength),
		0
	)
	add(
		U.newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 0.09, 0.09), Color = FOAM, Material = NEON }),
		CFrame.new(0, 0, base - bladeLength * 2 - 0.2) * ALONG,
		0.1
	)
	if dragon then
		for side = -1, 1, 2 do
			add(
				ellipsoid(Vector3.new(0.3, 0.3, 1.6), FOAM, GLASS),
				CFrame.lookAt(Vector3.new(side * 0.35, 0.3, base + 0.1), Vector3.new(side * 0.9, 0.9, base + 1.4)),
				0.15
			)
			add(
				ellipsoid(Vector3.new(0.08, 0.5, 1.4), WATER_LIGHT, SHIMMER),
				CFrame.new(side * bladeWidth * 0.5, 0, base - bladeLength * 0.9) * CFrame.Angles(0, 0, rad(side * 90)),
				0
			)
		end
		add(ellipsoid(Vector3.new(0.5, 0.5, 0.7), FOAM, NEON), CFrame.new(0, 0.32, base + 0.05), 0.2)
	end
	local glow = Soft.glow(blade, WATER_LIGHT, if dragon then 3.6 else 2.6, 0.75)
	local light = Instance.new("PointLight")
	light.Color = WATER
	light.Range = if dragon then 10 else 7
	light.Brightness = 1.5
	light.Parent = blade

	local parts: { BasePart } = {}
	for _, piece in pieces do
		table.insert(parts, piece.part)
	end
	local result = { parts = parts, bases = bases, length = length, blade = blade }
	function result.place(frame: CFrame, spin: number)
		local spun = frame * CFrame.Angles(0, 0, spin)
		for _, piece in pieces do
			piece.part.CFrame = (if piece.spins then spun else frame) * piece.offset
		end
	end
	function result.show(alpha: number)
		for part, transparency in bases do
			part.Transparency = 1 - (1 - transparency) * alpha
		end
		glow.Enabled = alpha > 0.5
		light.Enabled = alpha > 0.5
	end
	function result.tip(frame: CFrame): Vector3
		return (frame * CFrame.new(0, 0, base - bladeLength * 2 - 0.5)).Position
	end
	function result.fade(duration: number)
		glow.Enabled = false
		light.Enabled = false
		Soft.fadeOut(parts, duration)
	end
	return result
end

return Lance
