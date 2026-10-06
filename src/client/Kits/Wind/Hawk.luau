local Soft = require(script.Parent.Parent.Parent.Soft)

local rad = math.rad
local key = Soft.key

local WIND, WIND_WHITE = Soft.WIND, Soft.WIND_WHITE
local STAR = Soft.STAR

local Hawk = {}

local ARM, HAND = 1.25, 1.45
local SHOULDER = Vector3.new(0.35, 0.12, -0.25)
local FLAP = 38
local FLICK = 30

export type Piece = {
	shape: "Feather" | "Box" | "Wedge",
	size: Vector3,
	color: Color3,
	transparency: number,
}

type Feather = { bone: number, at: number, angle: number, length: number, width: number, lift: number? }
local WING: { Feather } = {
	{ bone = 1, at = 0.12, angle = 2, length = 1.05, width = 0.56 },
	{ bone = 1, at = 0.4, angle = 6, length = 1.15, width = 0.56 },
	{ bone = 1, at = 0.68, angle = 10, length = 1.2, width = 0.56 },
	{ bone = 1, at = 0.95, angle = 15, length = 1.25, width = 0.54 },
	{ bone = 2, at = 0.12, angle = 22, length = 1.3, width = 0.5 },
	{ bone = 2, at = 0.36, angle = 34, length = 1.45, width = 0.48 },
	{ bone = 2, at = 0.6, angle = 47, length = 1.55, width = 0.44 },
	{ bone = 2, at = 0.82, angle = 60, length = 1.55, width = 0.4 },
	{ bone = 2, at = 1, angle = 74, length = 1.35, width = 0.34 },
	{ bone = 1, at = 0.3, angle = 8, length = 0.6, width = 0.5, lift = 0.05 },
	{ bone = 1, at = 0.75, angle = 12, length = 0.62, width = 0.5, lift = 0.05 },
	{ bone = 2, at = 0.25, angle = 30, length = 0.66, width = 0.45, lift = 0.05 },
	{ bone = 2, at = 0.65, angle = 50, length = 0.6, width = 0.4, lift = 0.05 },
}
local OUTERMOST = 9
local TAIL = { -28, -14, 0, 14, 28 }

local PIECES: { Piece } = {
	{ shape = "Feather", size = Vector3.new(0.85, 0.75, 2.3), color = WIND_WHITE, transparency = 0.12 },
	{ shape = "Feather", size = Vector3.new(1.7, 1.5, 3.4), color = WIND, transparency = 0.72 },
	{ shape = "Feather", size = Vector3.new(0.62, 0.6, 0.85), color = WIND_WHITE, transparency = 0.08 },
	{ shape = "Wedge", size = Vector3.new(0.14, 0.24, 0.42), color = STAR, transparency = 0 },
}
for _ in TAIL do
	table.insert(PIECES, { shape = "Feather", size = Vector3.new(0.42, 0.05, 1.45), color = WIND, transparency = 0.3 })
end
for _ = 1, 2 do
	table.insert(PIECES, { shape = "Box", size = Vector3.new(ARM, 0.12, 0.12), color = WIND_WHITE, transparency = 0.1 })
	table.insert(PIECES, { shape = "Box", size = Vector3.new(HAND, 0.1, 0.1), color = WIND_WHITE, transparency = 0.1 })
	for _, f in WING do
		table.insert(PIECES, {
			shape = "Feather",
			size = Vector3.new(f.width, 0.05, f.length),
			color = if f.lift
				then WIND:Lerp(WIND_WHITE, 0.45)
				elseif f.bone == 2 then WIND:Lerp(WIND_WHITE, 0.2)
				else WIND,
			transparency = if f.lift then 0.2 else 0.28,
		})
	end
end
local TIP = 4 + #TAIL + 2 + OUTERMOST

function Hawk.Pieces(): { Piece }
	return PIECES
end

function Hawk.Pose(frames: { CFrame }, frame: CFrame, phase: number, bank: number)
	local body = frame * CFrame.new(0, -0.1 * math.sin(phase), 0) * CFrame.Angles(0, 0, bank)
	frames[1] = body
	frames[2] = body
	frames[3] = body * CFrame.new(0, 0.18, -1.25) * CFrame.Angles(rad(-8), 0, 0)
	frames[4] = body * CFrame.new(0, 0.1, -1.72)
	local n = 4
	for _, spread in TAIL do
		n += 1
		frames[n] = body * CFrame.new(0, 0.05, 1.05) * CFrame.Angles(rad(6), rad(spread), 0) * CFrame.new(0, 0, 0.65)
	end
	local arm = FLAP * math.sin(phase)
	local hand = arm + FLICK * math.sin(phase - 0.7)
	for _, side in { 1, -1 } do
		local shoulder = body
			* CFrame.new(SHOULDER.X * side, SHOULDER.Y, SHOULDER.Z)
			* CFrame.Angles(0, rad(-8) * side, rad(arm) * side)
		local wrist = shoulder
			* CFrame.new(ARM * side, 0, 0)
			* CFrame.Angles(0, rad(-12) * side, rad(hand - arm) * side)
		n += 1
		frames[n] = shoulder * CFrame.new(ARM / 2 * side, 0, -0.05)
		n += 1
		frames[n] = wrist * CFrame.new(HAND / 2 * side, 0, -0.05)
		for _, f in WING do
			local bone, length = if f.bone == 1 then shoulder else wrist, if f.bone == 1 then ARM else HAND
			n += 1
			frames[n] = bone
				* CFrame.new(length * f.at * side, f.lift or 0, 0)
				* CFrame.Angles(0, rad(f.angle) * side, 0)
				* CFrame.new(0, 0, f.length / 2)
		end
	end
end

export type Hawk = {
	parts: { BasePart },
	frames: { CFrame },
	body: BasePart,
	trails: { Trail },
}

function Hawk.new(start: CFrame): Hawk
	local parts: { BasePart } = {}
	for _, piece in PIECES do
		local part: BasePart
		if piece.shape == "Wedge" then
			part = Soft.newWedge({ Size = piece.size, Color = piece.color, Transparency = piece.transparency })
		else
			part = Soft.U.newPart({ Size = piece.size, Color = piece.color, Transparency = piece.transparency })
			if piece.shape == "Feather" then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = part
			end
		end
		table.insert(parts, part)
	end
	local hawk = {
		parts = parts,
		frames = table.create(#parts, CFrame.identity),
		body = parts[1],
		trails = {},
	}
	Hawk.Place(hawk, start, 0, 0)
	table.insert(
		hawk.trails,
		Soft.trail(parts[1], Vector3.new(0, 1, 0.4), Vector3.new(0, -1, 0.4), {
			color = ColorSequence.new(WIND_WHITE, WIND),
			transparency = NumberSequence.new({ key(0, 0.35), key(1, 1) }),
			width = NumberSequence.new({ key(0, 1), key(1, 0.2) }),
			lifetime = 0.4,
			texture = Soft.SMOKE,
		})
	)
	for _, tip in { TIP, TIP + 2 + #WING } do
		local feather = parts[tip]
		local half = feather.Size.Z / 2
		table.insert(
			hawk.trails,
			Soft.trail(feather, Vector3.new(0, 0, half - 0.6), Vector3.new(0, 0, half), {
				color = ColorSequence.new(WIND_WHITE, WIND),
				transparency = NumberSequence.new({ key(0, 0.3), key(1, 1) }),
				lifetime = 0.22,
			})
		)
	end
	return hawk
end

function Hawk.Place(hawk: Hawk, frame: CFrame, phase: number, bank: number)
	Hawk.Pose(hawk.frames, frame, phase, bank)
	workspace:BulkMoveTo(hawk.parts, hawk.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

function Hawk.Release(hawk: Hawk, fade: number)
	for _, trail in hawk.trails do
		Soft.endTrail(trail)
	end
	for _, part in hawk.parts do
		Soft.linger(part, fade, 0.55)
	end
end

return Hawk
