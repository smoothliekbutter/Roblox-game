-- Yuno's wings of wind: a three-bone bird wing that beats while he hovers and lies back into a glide as he moves.

local Soft = require(script.Parent.Parent.Parent.Soft)

local rad = math.rad
local key = Soft.key

local WIND, WIND_DEEP, WIND_WHITE = Soft.WIND, Soft.WIND_DEEP, Soft.WIND_WHITE
local STAR, STAR_WHITE = Soft.STAR, Soft.STAR_WHITE

local Wings = {}

-- How big the whole wing is, and its bones: the upper arm, the forearm and
-- the hand.
local SCALE = 0.92
local BONES = { 1.3 * SCALE, 1.8 * SCALE, 1.4 * SCALE }

local ROOT = Vector3.new(0.45, 0.55, 0.65)

export type Hold = {
	lift: number,
	elbow: number,
	wrist: number,
	sweep: number,
	twist: number,
	beat: number,
	rate: number,
}

Wings.Hover = { lift = 68, elbow = -20, wrist = -44, sweep = 24, twist = 8, beat = 1, rate = 0.4 } :: Hold
Wings.Glide = { lift = 22, elbow = -12, wrist = -30, sweep = 30, twist = 72, beat = 0.35, rate = 0.8 } :: Hold

function Wings.Blend(a: Hold, b: Hold, k: number): Hold
	return {
		lift = a.lift + (b.lift - a.lift) * k,
		elbow = a.elbow + (b.elbow - a.elbow) * k,
		wrist = a.wrist + (b.wrist - a.wrist) * k,
		sweep = a.sweep + (b.sweep - a.sweep) * k,
		twist = a.twist + (b.twist - a.twist) * k,
		beat = a.beat + (b.beat - a.beat) * k,
		rate = a.rate + (b.rate - a.rate) * k,
	}
end

type Feather = {
	bone: number,
	at: number,
	angle: number,
	length: number,
	width: number,
	layer: number,
	drop: number,
	color: Color3,
	transparency: number,
	quill: boolean,
	flex: number, -- how far it bends against the air as the wing beats
	trail: boolean, -- wind streams off its tip
}

local FEATHERS: { Feather } = {}
local function row(style: { [string]: any }, list: { { number } })
	for i, f in list do
		table.insert(FEATHERS, {
			bone = f[1],
			at = f[2],
			angle = f[3],
			length = f[4] * SCALE,
			width = f[5] * SCALE,
			-- (a hair apart, so neighbours never lie flat in each other)
			layer = style.layer + i * 0.006,
			drop = style.drop,
			color = style.color,
			transparency = style.transparency,
			quill = style.quill == true,
			flex = style.flex,
			trail = style.trail == true and i >= #list - 2,
		})
	end
end

-- Tertials: off the upper arm by the elbow, hanging down toward his back.
row({ layer = 0, drop = 0.1, color = WIND:Lerp(WIND_DEEP, 0.25), transparency = 0.56, quill = true, flex = 0.6 }, {
	{ 1, 0.48, -75, 1.4, 0.48 },
	{ 1, 0.7, -72, 1.62, 0.5 },
	{ 1, 0.92, -68, 1.8, 0.52 },
})
-- Secondaries: along the forearm, the trailing edge.
row({ layer = 0.03, drop = 0.1, color = WIND, transparency = 0.56, quill = true, flex = 0.8 }, {
	{ 2, 0.06, -46, 1.95, 0.54 },
	{ 2, 0.21, -42, 2.02, 0.54 },
	{ 2, 0.36, -38, 2.07, 0.54 },
	{ 2, 0.51, -34, 2.1, 0.54 },
	{ 2, 0.66, -30, 2.12, 0.54 },
	{ 2, 0.81, -26, 2.14, 0.54 },
	{ 2, 0.95, -22, 2.16, 0.54 },
})
row({
	layer = 0.07,
	drop = 0.08,
	color = WIND:Lerp(WIND_WHITE, 0.15),
	transparency = 0.54,
	quill = true,
	flex = 1,
	trail = true,
}, {
	{ 3, 0, 26, 2.3, 0.54 },
	{ 3, 0.14, 34, 2.48, 0.53 },
	{ 3, 0.28, 42, 2.64, 0.52 },
	{ 3, 0.42, 50, 2.8, 0.5 },
	{ 3, 0.56, 58, 2.92, 0.48 },
	{ 3, 0.7, 67, 3, 0.46 },
	{ 3, 0.82, 76, 2.94, 0.43 },
	{ 3, 0.92, 86, 2.75, 0.4 },
	{ 3, 1, 96, 2.4, 0.36 },
})
-- Greater coverts: over the roots of the secondaries and the inner primaries.
row({ layer = 0.16, drop = 0.04, color = WIND:Lerp(WIND_WHITE, 0.25), transparency = 0.54, flex = 0.4 }, {
	{ 2, 0.08, -42, 1.05, 0.48 },
	{ 2, 0.3, -36, 1.1, 0.48 },
	{ 2, 0.52, -30, 1.12, 0.48 },
	{ 2, 0.74, -24, 1.14, 0.48 },
	{ 2, 0.95, -18, 1.16, 0.48 },
	{ 3, 0.08, 32, 1.22, 0.46 },
	{ 3, 0.3, 44, 1.26, 0.44 },
	{ 3, 0.52, 56, 1.24, 0.42 },
	{ 3, 0.74, 68, 1.16, 0.4 },
})
-- Median coverts: a shorter row over those.
row({ layer = 0.24, drop = 0, color = WIND:Lerp(WIND_WHITE, 0.35), transparency = 0.52, flex = 0.2 }, {
	{ 1, 0.55, -62, 0.7, 0.38 },
	{ 1, 0.95, -48, 0.72, 0.4 },
	{ 2, 0.25, -34, 0.72, 0.4 },
	{ 2, 0.55, -26, 0.72, 0.4 },
	{ 2, 0.85, -18, 0.72, 0.4 },
	{ 3, 0.2, 30, 0.72, 0.38 },
	{ 3, 0.5, 46, 0.7, 0.36 },
	{ 3, 0.8, 62, 0.62, 0.32 },
})
-- Lesser coverts: small and close-set along the leading edge.
row({ layer = 0.32, drop = -0.06, color = WIND:Lerp(WIND_WHITE, 0.5), transparency = 0.48, flex = 0 }, {
	{ 1, 0.2, -70, 0.46, 0.3 },
	{ 1, 0.55, -58, 0.46, 0.3 },
	{ 1, 0.9, -46, 0.46, 0.3 },
	{ 2, 0.15, -30, 0.46, 0.3 },
	{ 2, 0.45, -20, 0.46, 0.3 },
	{ 2, 0.75, -10, 0.46, 0.3 },
	{ 3, 0.1, 20, 0.44, 0.28 },
	{ 3, 0.45, 40, 0.4, 0.26 },
	{ 3, 0.8, 60, 0.36, 0.24 },
})
row({ layer = 0.12, drop = 0, color = WIND:Lerp(WIND_WHITE, 0.2), transparency = 0.56, flex = 0.3 }, {
	{ 4, 0, -14, 1.2, 0.44 },
	{ 4, 0.16, -6, 1.05, 0.42 },
})

export type Piece = {
	shape: "Feather" | "Box" | "Ball",
	size: Vector3,
	color: Color3,
	transparency: number,
}

local PIECES: { Piece } = {}
for _, f in FEATHERS do
	table.insert(PIECES, {
		shape = "Feather",
		size = Vector3.new(f.width, f.length, 0.05),
		color = f.color,
		transparency = f.transparency,
	})
	if f.quill then
		table.insert(PIECES, {
			shape = "Box",
			size = Vector3.new(0.05, f.length * 0.86, 0.08),
			color = WIND_WHITE,
			transparency = 0.3,
		})
	end
end
local BONE_WIDTH = { 0.2, 0.16, 0.12 }
for i, length in BONES do
	table.insert(PIECES, {
		shape = "Box",
		size = Vector3.new(length + BONE_WIDTH[i] * 0.5, BONE_WIDTH[i], BONE_WIDTH[i]),
		color = WIND_WHITE,
		transparency = 0.18,
	})
end
table.insert(PIECES, { shape = "Ball", size = Vector3.one * 0.26, color = WIND_WHITE, transparency = 0.15 })
table.insert(PIECES, { shape = "Ball", size = Vector3.one * 0.22, color = WIND_WHITE, transparency = 0.1 })
table.insert(PIECES, { shape = "Ball", size = Vector3.one * 0.36, color = WIND, transparency = 0.35 })

function Wings.Pieces(): { Piece }
	return PIECES
end

type Offsets = { root: CFrame, bones: { CFrame }, middles: { CFrame }, feathers: { CFrame } }
local OFFSETS: { [number]: Offsets } = {}
for _, side in { -1, 1 } do
	local offsets: Offsets = {
		root = CFrame.new(ROOT.X * side, ROOT.Y, ROOT.Z),
		bones = {},
		middles = {},
		feathers = {},
	}
	for i, length in BONES do
		offsets.bones[i] = CFrame.new(length * side, 0, 0)
		offsets.middles[i] = CFrame.new(length / 2 * side, 0, 0.12)
	end
	for i, f in FEATHERS do
		local along = if f.bone == 4 then f.at else BONES[f.bone] * f.at
		offsets.feathers[i] = CFrame.new(along * side, -f.drop, f.layer)
	end
	OFFSETS[side] = offsets
end
local HANGS: { CFrame } = {}
local QUILLS: { CFrame } = {}
for i, f in FEATHERS do
	HANGS[i] = CFrame.new(0, -f.length / 2, 0)
	QUILLS[i] = CFrame.new(0, -f.length * 0.47, 0.01)
end
local JOINT = CFrame.new(0, 0, 0.12)
local SHOULDER_GLOW = CFrame.new(0, 0, 0.05)

function Wings.Bones(torso: CFrame, side: number, hold: Hold, phase: number): (CFrame, CFrame, CFrame)
	local offsets = OFFSETS[side]
	local beat = hold.beat
	-- Down and forward, then up and back: the stroke rolling out along it.
	local lift = hold.lift + 10 * beat * math.sin(phase)
	local sweep = hold.sweep + 12 * beat * math.sin(phase - 0.5)
	local elbow = hold.elbow + 7 * beat * math.sin(phase - 0.9)
	local wrist = hold.wrist + 11 * beat * math.sin(phase - 1.6)
	local shoulder = torso
		* offsets.root
		* CFrame.Angles(0, rad(-sweep) * side, rad(lift) * side)
		* CFrame.Angles(rad(-hold.twist), 0, 0)
	local elbowFrame = shoulder * offsets.bones[1] * CFrame.Angles(0, 0, rad(elbow) * side)
	-- (the hand angled back a little, so the tip trails)
	local wristFrame = elbowFrame * offsets.bones[2] * CFrame.Angles(0, rad(-10) * side, rad(wrist) * side)
	return shoulder, elbowFrame, wristFrame
end

function Wings.Pose(
	frames: { CFrame },
	torso: CFrame,
	side: number,
	hold: Hold,
	phase: number,
	flutter: number,
	t: number
)
	local offsets = OFFSETS[side]
	local shoulder, elbow, wrist = Wings.Bones(torso, side, hold, phase)
	local bones = { shoulder, elbow, wrist, torso * offsets.root }
	local bend = 10 * hold.beat * math.cos(phase - 0.9) - flutter * 4
	local n = 0
	for i, f in FEATHERS do
		local ripple = 2.5 * math.sin(t * 2.3 - i * 0.55) + flutter * 2 * math.sin(t * 15 - i * 1.3)
		local joint = bones[f.bone]
			* offsets.feathers[i]
			* CFrame.Angles(rad(bend * f.flex), 0, rad(f.angle + ripple * f.flex) * side)
		n += 1
		frames[n] = joint * HANGS[i]
		if f.quill then
			n += 1
			frames[n] = joint * QUILLS[i]
		end
	end
	for i = 1, 3 do
		n += 1
		frames[n] = bones[i] * offsets.middles[i]
	end
	n += 1
	frames[n] = elbow * JOINT
	n += 1
	frames[n] = wrist * JOINT
	n += 1
	frames[n] = shoulder * SHOULDER_GLOW
end

-- The parts

export type Maker = (props: { [string]: any }, base: number, wedge: boolean?) -> BasePart

export type Wing = {
	parts: { BasePart },
	frames: { CFrame },
	trails: { Trail },
	emitters: { ParticleEmitter },
	beams: { Beam },
	side: number,
}

function Wings.new(make: Maker, side: number): Wing
	local parts: { BasePart } = {}
	for _, piece in PIECES do
		local part = make({
			Shape = if piece.shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Block,
			Size = piece.size,
			Color = piece.color,
		}, piece.transparency)
		if piece.shape == "Feather" then
			-- (a flat ellipsoid: the feather's outline, round-tipped)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		table.insert(parts, part)
	end
	local frames = table.create(#parts, CFrame.identity)

	local trails: { Trail } = {}
	local emitters: { ParticleEmitter } = {}
	local n = 0
	for _, f in FEATHERS do
		n += 1
		local vane = parts[n]
		if f.trail then
			local tip = -f.length / 2
			table.insert(
				trails,
				Soft.trail(vane, Vector3.new(0, tip + 0.55, 0), Vector3.new(0, tip + 0.05, 0), {
					color = ColorSequence.new(WIND_WHITE, WIND),
					transparency = NumberSequence.new({ key(0, 0.5), key(1, 1) }),
					width = NumberSequence.new({ key(0, 1), key(1, 0.15) }),
					lifetime = 0.35,
					off = true,
				})
			)
			local wisp = Soft.windEmitter(vane, {
				Color = ColorSequence.new(WIND_WHITE, WIND),
				LightEmission = 1,
				Size = NumberSequence.new({ key(0, 0.35), key(1, 0) }),
				Transparency = NumberSequence.new({ key(0, 1), key(0.2, 0.55), key(1, 1) }),
				Lifetime = NumberRange.new(0.3, 0.55),
				Speed = NumberRange.new(0.4, 1),
				Rate = 6,
			})
			table.insert(emitters, wisp)
		end
		if f.quill then
			n += 1
		end
	end
	local hand = parts[n + 3]
	table.insert(
		emitters,
		Soft.windEmitter(hand, {
			Texture = Soft.SPARKLE,
			Color = ColorSequence.new(STAR_WHITE, STAR),
			LightEmission = 1,
			Size = NumberSequence.new({ key(0, 0.22), key(1, 0) }),
			Transparency = NumberSequence.new({ key(0, 0.2), key(1, 1) }),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(0.3, 1),
			Acceleration = Vector3.new(0, -1.5, 0),
			Shape = Enum.ParticleEmitterShape.Box,
			Rate = 5,
		})
	)

	-- Wind flowing out along the leading edge, bone by bone.
	local beams: { Beam } = {}
	for i = 1, 3 do
		local bone = parts[n + i]
		local half = bone.Size.X / 2
		local from = Instance.new("Attachment")
		from.Position = Vector3.new(-half * side, 0, 0)
		from.Parent = bone
		local to = Instance.new("Attachment")
		to.Position = Vector3.new(half * side, 0, 0)
		to.Parent = bone
		table.insert(
			beams,
			Soft.softBeam(from, to, {
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 0.7 - i * 0.12,
				width1 = 0.6 - i * 0.12,
				transparency = NumberSequence.new({ key(0, 0.8), key(0.5, 0.66), key(1, 0.8) }),
				texture = Soft.SMOKE,
				speed = 1.6,
				length = 1.5,
			}, bone)
		)
	end

	return { parts = parts, frames = frames, trails = trails, emitters = emitters, beams = beams, side = side }
end

-- Poses a wing (see Pose) and moves its parts there.
function Wings.Place(wing: Wing, torso: CFrame, hold: Hold, phase: number, flutter: number, t: number)
	Wings.Pose(wing.frames, torso, wing.side, hold, phase, flutter, t)
	workspace:BulkMoveTo(wing.parts, wing.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

return Wings
