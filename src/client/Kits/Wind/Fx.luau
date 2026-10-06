local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local VFX = require(script.Parent.Parent.Parent.VFX)
local Soft = require(script.Parent.Parent.Parent.Soft)

type Animation = PoseAnimator.Animation

local U = VFX.Util
local UP = Vector3.yAxis

local WIND_WHITE = Soft.WIND_WHITE
local newWedge = Soft.newWedge

local function build(raw: { [string]: any }): Animation
	local keyframes = {}
	for _, key in raw.keys do
		table.insert(keyframes, {
			time = key[1],
			pose = key[2],
			easing = if key[3] then (Enum.EasingStyle :: any)[key[3]] else nil,
			direction = if key[4] then (Enum.EasingDirection :: any)[key[4]] else nil,
		})
	end
	return {
		keyframes = keyframes,
		loop = raw.loop,
		fadeIn = raw.fadeIn,
		fadeOut = raw.fadeOut,
		delays = raw.delays,
	}
end

local ANIMS: { [string]: Animation } = {}
for name, raw in require(script.Parent.Animations) do
	ANIMS[name] = build(raw)
end

local function play(character: Model, animation: Animation, onEvent: ((string) -> ())?)
	PoseAnimator.Play(character, animation, onEvent)
end

local handlers: { [string]: (data: any, character: Model, root: BasePart) -> () } = {}

local function involves(data, character: Model): boolean
	return U.isLocal(character) or U.isLocal(data.target)
end

local castTokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local function bump(character: Model): number
	local token = (castTokens[character] or 0) + 1
	castTokens[character] = token
	return token
end
local function live(character: Model, token: number): boolean
	return castTokens[character] == token and character.Parent ~= nil
end

local function handOf(character: Model, side: string): Vector3?
	local arm = character:FindFirstChild(side .. " Arm")
	return if arm and arm:IsA("BasePart") then (arm.CFrame * CFrame.new(0, -1.15, 0)).Position else nil
end

local function easeOut(u: number): number
	return 1 - (1 - math.clamp(u, 0, 1)) ^ 3
end

local function easeInOut(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function featherBurst(position: Vector3, count: number, speed: number)
	for _ = 1, count do
		local feather = newWedge({
			Size = Vector3.new(0.05, 0.28, 0.9),
			Color = WIND_WHITE,
			Material = Enum.Material.ForceField,
			Transparency = 0.1,
			CFrame = CFrame.new(position) * U.randomAngles(),
		})
		local out = U.randomUnit() * speed * (0.5 + math.random() * 0.5)
		local life = 0.45 + math.random() * 0.3
		U.tween(feather, life, {
			CFrame = CFrame.new(position + out * life + UP * 1.5) * U.randomAngles(),
			Transparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(life + 0.05, feather.Destroy, feather)
	end
end

return {
	ANIMS = ANIMS,
	play = play,
	handlers = handlers,
	involves = involves,
	bump = bump,
	live = live,
	handOf = handOf,
	easeOut = easeOut,
	easeInOut = easeInOut,
	featherBurst = featherBurst,
}
