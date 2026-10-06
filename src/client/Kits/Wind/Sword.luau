local Soft = require(script.Parent.Parent.Parent.Soft)

local rad = math.rad
local key = Soft.key

local WIND, WIND_WHITE = Soft.WIND, Soft.WIND_WHITE
local STAR, STAR_WHITE = Soft.STAR, Soft.STAR_WHITE

local GRIP = Color3.fromRGB(22, 64, 48)
local GOLD = STAR
local GEM = WIND

local Sword = {}

local BASE, SWELL, TIP = 0.72, 4.6, 6.6
local BASE_WIDTH, WIDEST = 0.5, 0.86
local THICK = 0.12
local CORE = 3.5

export type Piece = {
	shape: "Box" | "Wedge" | "Ball" | "Feather",
	size: Vector3,
	color: Color3,
	transparency: number,
	offset: CFrame,
	material: Enum.Material?,
	core: boolean?,
}

local PIECES: { Piece } = {}
local function add(piece: Piece)
	table.insert(PIECES, piece)
end

add({
	shape = "Box",
	size = Vector3.new(0.2, 1.12, 0.2),
	color = GRIP,
	transparency = 0,
	offset = CFrame.new(0, -0.06, 0),
	material = Enum.Material.Fabric,
})
for _, y in { -0.36, -0.06, 0.24 } do
	add({
		shape = "Box",
		size = Vector3.new(0.235, 0.07, 0.235),
		color = GOLD,
		transparency = 0,
		offset = CFrame.new(0, y, 0),
	})
end
add({
	shape = "Box",
	size = Vector3.new(0.27, 0.08, 0.27),
	color = GOLD,
	transparency = 0,
	offset = CFrame.new(0, -0.62, 0),
})
add({ shape = "Ball", size = Vector3.one * 0.3, color = GOLD, transparency = 0, offset = CFrame.new(0, -0.8, 0) })
add({ shape = "Ball", size = Vector3.one * 0.16, color = GEM, transparency = 0, offset = CFrame.new(0, -0.95, 0) })

local GUARD = 0.56
add({
	shape = "Box",
	size = Vector3.new(0.3, 0.24, 0.46),
	color = GOLD,
	transparency = 0,
	offset = CFrame.new(0, GUARD, 0),
})
for _, x in { -0.12, 0.12 } do
	add({ shape = "Ball", size = Vector3.one * 0.2, color = GEM, transparency = 0, offset = CFrame.new(x, GUARD, 0) })
end
local GUARD_FEATHERS = {
	{ rise = 10, length = 0.95, width = 0.22 },
	{ rise = 34, length = 0.76, width = 0.19 },
	{ rise = 58, length = 0.54, width = 0.16 },
	{ rise = -28, length = 0.42, width = 0.14 },
}
for _, side in { -1, 1 } do
	for _, f in GUARD_FEATHERS do
		add({
			shape = "Feather",
			size = Vector3.new(0.07, f.length, f.width),
			color = GOLD,
			transparency = 0,
			offset = CFrame.new(0, GUARD, side * 0.2)
				* CFrame.Angles(rad(90 - f.rise) * side, 0, 0)
				* CFrame.new(0, f.length / 2, 0),
		})
	end
end

local DIAMOND = 0.95
add({
	shape = "Box",
	size = Vector3.new(0.17, 0.3, 0.3),
	color = GOLD,
	transparency = 0,
	offset = CFrame.new(0, DIAMOND, 0) * CFrame.Angles(rad(45), 0, 0),
})
for _, x in { -0.07, 0.07 } do
	add({ shape = "Ball", size = Vector3.one * 0.13, color = GEM, transparency = 0, offset = CFrame.new(x, DIAMOND, 0) })
end

local reach = SWELL - BASE
local flare = (WIDEST - BASE_WIDTH) / 2
local middle = (BASE + SWELL) / 2
add({
	shape = "Box",
	size = Vector3.new(THICK, reach, BASE_WIDTH),
	color = WIND,
	transparency = 0.3,
	offset = CFrame.new(0, middle, 0),
})
local flareAt = BASE_WIDTH / 2 + flare / 2
add({
	shape = "Wedge",
	size = Vector3.new(THICK, reach, flare),
	color = WIND,
	transparency = 0.3,
	offset = CFrame.new(0, middle, flareAt) * CFrame.Angles(math.pi, 0, 0),
})
add({
	shape = "Wedge",
	size = Vector3.new(THICK, reach, flare),
	color = WIND,
	transparency = 0.3,
	offset = CFrame.new(0, middle, -flareAt) * CFrame.Angles(0, 0, math.pi),
})
local point = TIP - SWELL
add({
	shape = "Wedge",
	size = Vector3.new(THICK, point, WIDEST / 2),
	color = WIND,
	transparency = 0.3,
	offset = CFrame.new(0, (SWELL + TIP) / 2, WIDEST / 4) * CFrame.Angles(0, math.pi, 0),
})
add({
	shape = "Wedge",
	size = Vector3.new(THICK, point, WIDEST / 2),
	color = WIND,
	transparency = 0.3,
	offset = CFrame.new(0, (SWELL + TIP) / 2, -WIDEST / 4),
})
add({
	shape = "Box",
	size = Vector3.new(THICK + 0.015, reach - 0.3, 0.28),
	color = WIND_WHITE,
	transparency = 0.55,
	offset = CFrame.new(0, middle + 0.15, 0),
})
add({
	shape = "Box",
	size = Vector3.new(0.15, 5.3, 0.09),
	color = WIND_WHITE,
	transparency = 0,
	offset = CFrame.new(0, CORE, 0),
	core = true,
})
local function edge(fromY: number, fromZ: number, toY: number, toZ: number)
	local dy, dz = toY - fromY, toZ - fromZ
	add({
		shape = "Box",
		size = Vector3.new(THICK + 0.02, math.sqrt(dy * dy + dz * dz) + 0.03, 0.05),
		color = WIND_WHITE,
		transparency = 0.1,
		offset = CFrame.new(0, (fromY + toY) / 2, (fromZ + toZ) / 2) * CFrame.Angles(math.atan2(dz, dy), 0, 0),
	})
end
for _, side in { -1, 1 } do
	edge(BASE, side * BASE_WIDTH / 2, SWELL, side * WIDEST / 2)
	edge(SWELL, side * WIDEST / 2, TIP, 0)
end
add({
	shape = "Feather",
	size = Vector3.new(0.42, TIP - BASE + 0.6, WIDEST + 0.45),
	color = WIND,
	transparency = 0,
	offset = CFrame.new(0, (BASE + TIP) / 2 + 0.1, 0),
	material = Enum.Material.ForceField,
})

function Sword.Pieces(): { Piece }
	return PIECES
end

export type Maker = (props: { [string]: any }, base: number, wedge: boolean?) -> BasePart

export type Sword = {
	parts: { BasePart },
	frames: { CFrame },
	blade: BasePart,
	beams: { Beam },
	emitters: { ParticleEmitter },
}

function Sword.new(make: Maker): Sword
	local parts: { BasePart } = {}
	local blade: BasePart? = nil
	for _, piece in PIECES do
		local props: { [string]: any } = {
			Size = piece.size,
			Color = piece.color,
		}
		if piece.shape == "Ball" then
			props.Shape = Enum.PartType.Ball
		end
		if piece.material then
			props.Material = piece.material
		end
		local part = make(props, piece.transparency, piece.shape == "Wedge")
		if piece.shape == "Feather" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		if piece.core then
			blade = part
		end
		table.insert(parts, part)
	end
	assert(blade, "the sword has no fuller")

	local low = Instance.new("Attachment")
	low.Position = Vector3.new(0, -2.6, 0)
	low.Parent = blade
	local high = Instance.new("Attachment")
	high.Position = Vector3.new(0, 2.8, 0)
	high.Parent = blade
	local beams = {
		Soft.softBeam(low, high, {
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 1.5,
			width1 = 0.7,
			transparency = NumberSequence.new({ key(0, 0.86), key(0.3, 0.64), key(1, 0.82) }),
			texture = Soft.SMOKE,
			speed = 2.5,
			length = 3,
		}, blade),
		Soft.softBeam(low, high, {
			color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
			width0 = 0.5,
			width1 = 0.28,
			transparency = NumberSequence.new({ key(0, 0.75), key(0.5, 0.45), key(1, 0.7) }),
			texture = Soft.SPARKLE,
			wrap = true,
			length = 0.8,
			speed = 1.5,
		}, blade),
	}
	for _, beam in beams do
		beam.Enabled = false
	end
	local point = Instance.new("Attachment")
	point.Position = Vector3.new(0, TIP - CORE - 0.15, 0)
	point.Parent = blade
	local glint = Soft.windEmitter(point, {
		Texture = Soft.SPARKLE,
		Color = ColorSequence.new(STAR_WHITE),
		LightEmission = 1,
		Size = NumberSequence.new({ key(0, 0), key(0.3, 0.9), key(1, 0) }),
		Transparency = NumberSequence.new({ key(0, 0.1), key(1, 0.6) }),
		Lifetime = NumberRange.new(0.25, 0.35),
		Speed = NumberRange.new(0),
		RotSpeed = NumberRange.new(-90, 90),
		LockedToPart = true,
		Rate = 1.5,
	})

	return {
		parts = parts,
		frames = table.create(#parts, CFrame.identity),
		blade = blade,
		beams = beams,
		emitters = { glint },
	}
end

function Sword.Place(sword: Sword, grip: CFrame)
	for i, piece in PIECES do
		sword.frames[i] = grip * piece.offset
	end
	workspace:BulkMoveTo(sword.parts, sword.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

return Sword
