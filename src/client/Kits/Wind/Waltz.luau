--[[
	Prince of Wind (Yuno): Spirit of Zephyrus (Full-Crown 2), the waltz of
	the west wind, drawn. The paths are Shared/Zephyrus (the server holds
	them both on them); this draws it, about 1.3 seconds from the catch:

	  the catch  his lunge runs into them: a ring of wind bursts off them
	             and the wind lifts them off their feet.
	  the waltz  he whirls round them twice at a blur, a ring of his ghosts
	             left behind him all the way round, wind spiralling up round
	             them; every half turn a cut, his long sword of wind through
	             them, each cut left hanging in the air round them.
	  the spear  he swings out in front of them, draws back (the wind pours
	             into his sword), and runs them through: the sword shoots out
	             into a spear of wind thirty studs long, spiralling, rings of
	             wind racing down it; every hanging cut bursts at once and
	             they're blown away trailing wind.

	Everything is see-through wind and light. The camera (for the two of
	them) circles the other way round them, low, so the waltz sweeps past
	it, and comes round behind him for the spear. No shake: eased zooms.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WaltzPlan = require(ReplicatedStorage:WaitForChild("Shared").Zephyrus)
local Cinematic = require(script.Parent.Parent.Parent.Cinematic)
local PoseAnimator = require(script.Parent.Parent.Parent.PoseAnimator)
local Reactions = require(script.Parent.Parent.Parent.Reactions)
local Soft = require(script.Parent.Parent.Parent.Soft)

local U = Soft.U
local rad = math.rad
local UP = Vector3.yAxis
local key = Soft.key

local WIND, WIND_WHITE = Soft.WIND, Soft.WIND_WHITE
local STAR, STAR_WHITE = Soft.STAR, Soft.STAR_WHITE
local SMOKE = Soft.SMOKE

type Animation = PoseAnimator.Animation
type Sword = { hold: (number) -> (), point: () -> Vector3 }

-- What the kit lends this module.
export type Context = {
	anims: { [string]: Animation },
	play: (Model, Animation) -> (),
	sword: (Model) -> Sword?, -- his long sword of wind, out since the lunge
}

local Waltz = {}

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- Draws it (t = 0 now). Returns stop(), which cuts it short.
function Waltz.Play(ctx: Context, data, character: Model, root: BasePart): (() -> ())?
	if typeof(data.attacker) ~= "Vector3" or typeof(data.victim) ~= "Vector3" then
		return nil
	end
	local times = WaltzPlan.Times
	local plan = WaltzPlan.Plan(data.attacker, data.victim)
	local victim: Model? = if typeof(data.target) == "Instance" and data.target:IsA("Model") then data.target else nil
	local victimRoot = U.getRoot(victim)
	local mine = U.isLocal(character) or U.isLocal(victim)
	local started = os.clock()
	local finished = false
	local through = -plan.out -- the way the spear goes

	local function at(time: number, fn: () -> ())
		task.delay(math.max(time - (os.clock() - started), 0), function()
			if not finished and character.Parent then
				fn()
			end
		end)
	end
	local function them(t: number): Vector3
		return WaltzPlan.Victim(plan, math.min(t, times.Thrust)).Position
	end

	-- Both of them on the paths.
	local bind = "CloverZephyrWaltz" .. tostring(started)
	local stop: () -> ()
	function stop()
		if finished then
			return
		end
		finished = true
		pcall(function()
			RunService:UnbindFromRenderStep(bind)
		end)
	end
	RunService:BindToRenderStep(bind, Enum.RenderPriority.Camera.Value + 3, function()
		local t = os.clock() - started
		if t > times.Length then
			stop()
			return
		end
		if root.Parent then
			root.CFrame = WaltzPlan.Attacker(plan, t)
		end
		if victimRoot and victimRoot.Parent and t <= times.Thrust then
			victimRoot.CFrame = WaltzPlan.Victim(plan, t)
		end
	end)
	task.delay(times.Length + 0.5, stop)
	local sword = ctx.sword(character)
	if sword then
		sword.hold(times.Length + 0.2)
	end

	-- The catch: a ring of wind off them, and the wind lifts them.
	local center = plan.center
	Soft.windRing(center, plan.out, 1, 8, 0.3)
	Soft.lightRing(center, plan.out, 0.5, 6, 0.25, WIND_WHITE)
	Soft.twinkle(center, 5, WIND, 0.25)
	Soft.windPuff(center, 3, through)
	U.flash(center, WIND_WHITE, 3, 0.1)
	if victim then
		U.highlight(victim, WIND_WHITE, 0.1, 0.6)
		-- Swept off their feet: flailing in the wind.
		local flail = Reactions.Launched
		if flail then
			PoseAnimator.Play(victim, flail)
		end
	end

	-- The wind round them while he whirls: two rings of wind turning with
	-- him, ribbons spiralling up round them, a ring of light under them.
	local rings = {
		Soft.softRing({
			color = ColorSequence.new(WIND_WHITE, WIND),
			width0 = 1.6,
			width1 = 1.6,
			transparency = NumberSequence.new(0.55),
			texture = SMOKE,
			speed = 6,
			length = 5,
		}),
		Soft.softRing({
			color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
			width0 = 0.3,
			width1 = 0.3,
			transparency = NumberSequence.new(0.45),
		}),
	}
	local stopHelix = Soft.helix(function()
		local foot = them(os.clock() - started) - UP * 3
		return foot, foot + UP * 8
	end, 3.6, 3, 0.5, 1.5, 0.9, times.Out + 0.15, WIND)
	Soft.every(times.Out + 0.15, function(elapsed)
		local spin = WaltzPlan.Attacker(plan, math.min(elapsed, times.Out))
		local heart = them(elapsed)
		local grow = smooth(elapsed / 0.15)
		local turn = math.atan2(spin.Position.Z - heart.Z, spin.Position.X - heart.X)
		rings[1].set(CFrame.new(heart) * CFrame.Angles(0, -turn, 0), WaltzPlan.Radius * grow + 0.05)
		rings[2].set(CFrame.new(heart - UP * 2.4) * CFrame.Angles(0, turn, 0), (WaltzPlan.Radius + 0.8) * grow + 0.05)
		return true
	end, function()
		for _, ring in rings do
			ring.fade(0.25)
		end
		stopHelix()
	end)

	-- Whirling round them: his ghosts left behind him all the way round, and
	-- the wind he trails painting the circle.
	local torso = character:FindFirstChild("Torso") :: BasePart?
	if torso then
		local wake = Soft.trail(torso, Vector3.new(0, 1.4, 0), Vector3.new(0, -1.4, 0), {
			color = ColorSequence.new(WIND_WHITE, WIND),
			transparency = NumberSequence.new({ key(0, 0.4), key(1, 1) }),
			width = NumberSequence.new({ key(0, 1), key(1, 0.2) }),
			lifetime = 0.45,
			texture = SMOKE,
		})
		task.delay(times.Out + 0.05, Soft.endTrail, wake)
	end
	for i = 0, 17 do
		at(0.06 + i * 0.045, function()
			U.afterimage(character, WIND, 0.4)
		end)
	end

	-- Each cut: his sword through them, the cut left hanging round them.
	local slashes: { Soft.Slash } = {}
	for i, when in times.Cuts do
		at(when - 0.05, function()
			ctx.play(character, if i % 2 == 1 then ctx.anims.SaintCut else ctx.anims.SaintCutBack)
		end)
		at(when, function()
			local heart = them(when)
			local him = WaltzPlan.Attacker(plan, when)
			local across = UP:Cross((heart - him.Position).Unit)
			across = if across.Magnitude > 1e-3 then across.Unit else plan.side
			local tilt = UP * (if i % 2 == 1 then 1.4 else -1.4)
			local slash = Soft.windSlash(
				heart + across * 4 + tilt,
				heart - across * 4 - tilt,
				(heart - him.Position).Unit * 1.2 + UP * 0.3,
				0.8
			)
			table.insert(slashes, slash)
			Soft.twinkle(heart, 3, WIND, 0.18)
			Soft.lightRing(heart, across, 0.4, 4.5, 0.2, WIND_WHITE)
			Soft.windPuff(heart, 2, across)
			U.burst(heart, {
				color = WIND_WHITE,
				count = 8,
				size = 0.4,
				speed = NumberRange.new(24, 50),
				lifetime = NumberRange.new(0.1, 0.25),
				streaks = true,
				spread = 40,
				direction = across,
			})
			if victim then
				U.highlight(victim, WIND_WHITE, 0.08, 0.6)
			end
		end)
	end

	-- Out in front of them, drawn back: the wind pours into his sword.
	at(times.Out - 0.06, function()
		ctx.play(character, ctx.anims.ZephyrusDraw)
		for i = 0, 6 do
			task.delay(i * 0.015, function()
				local current = ctx.sword(character)
				if current then
					Soft.inflow(current.point(), 4, WIND_WHITE)
				end
			end)
		end
		Soft.twinkle(root.Position, 4, STAR, 0.2)
	end)
	at(times.Thrust - 0.07, function()
		ctx.play(character, ctx.anims.ZephyrusSkewer)
	end)

	-- The spear: his sword shoots out through them and blows them away.
	at(times.Thrust, function()
		local hand = WaltzPlan.Attacker(plan, times.Thrust).Position + UP * 0.3
		local heart = them(times.Thrust)
		local tip = heart + through * 26
		local a, b = Soft.worldAnchor(hand, through), Soft.worldAnchor(hand, through)
		local spear = {
			Soft.softBeam(a, b, {
				color = ColorSequence.new(STAR_WHITE, WIND_WHITE),
				width0 = 1.1,
				width1 = 0.15,
				transparency = NumberSequence.new({ key(0, 0.1), key(1, 0.6) }),
			}),
			Soft.softBeam(a, b, {
				color = ColorSequence.new(WIND_WHITE, WIND),
				width0 = 5,
				width1 = 1.4,
				transparency = NumberSequence.new({ key(0, 0.55), key(1, 0.92) }),
				texture = SMOKE,
				speed = 14,
				length = 10,
			}),
		}
		table.insert(spear, Soft.starStream(a, b, 0.7, 16))
		-- It shoots out, then fades.
		Soft.every(0.07, function(elapsed)
			Soft.aim(b, hand:Lerp(tip, smooth(elapsed / 0.07)), through)
			return true
		end, function()
			Soft.aim(b, tip, through)
			task.delay(0.12, Soft.fadeBeams, spear, 0.32, { a, b })
		end)
		local stopSpiral = Soft.helix(function()
			return hand, tip
		end, 1.4, 4, 0.3, 3, 0.5, 0.4, WIND_WHITE)
		task.delay(0.4, stopSpiral)
		-- Rings of wind racing down it.
		for i = 1, 6 do
			task.delay(i * 0.025, function()
				local ring = hand + through * (2 + i * 4)
				Soft.windRing(ring, through, 0.6, 3 + i * 0.8, 0.3)
				Soft.lightRing(ring, through, 0.5, 2.5 + i * 0.7, 0.25, WIND_WHITE)
			end)
		end
		-- Where it goes through them: the air bursts, every cut bursts.
		U.flash(heart, STAR_WHITE, 5, 0.12)
		Soft.twinkle(heart, 9, STAR, 0.3)
		Soft.windRing(heart, through, 1, 12, 0.35)
		U.shockwave(heart, WIND, 1, 14, 0.3)
		Soft.windPuff(heart + through * 2, 4, through)
		Soft.streaks(heart + through, 18, 95, through, 25)
		for i, slash in slashes do
			task.delay(0.02 * i, function()
				slash.flare()
				slash.fade(0.22)
				Soft.twinkle(slash.apex, 3, WIND, 0.2)
			end)
		end
		if victimRoot and victimRoot.Parent then
			local comet = Soft.trail(victimRoot, Vector3.new(0, 1.2, 0), Vector3.new(0, -1.2, 0), {
				color = ColorSequence.new(WIND_WHITE, WIND),
				transparency = NumberSequence.new({ key(0, 0.35), key(1, 1) }),
				width = NumberSequence.new({ key(0, 1), key(1, 0.2) }),
				lifetime = 0.35,
				texture = SMOKE,
			})
			task.delay(0.7, Soft.endTrail, comet)
		end
		if mine then
			Soft.focusLines(0.3)
		end
	end)

	if mine then
		local release = Waltz.Camera(plan)
		local stopDrawing = stop
		stop = function()
			stopDrawing()
			release()
		end
	end
	return stop
end

--[[
	The camera: low, a little way out, going round them the other way to
	him (so the waltz sweeps past it, fast), then round behind his shoulder
	for the spear, watching them blown away. Each cut and the spear is an
	eased zoom in and out; nothing shakes.
]]
function Waltz.Camera(plan: WaltzPlan.Plan): () -> ()
	local times = WaltzPlan.Times
	local function them(t: number): Vector3
		return WaltzPlan.Victim(plan, math.min(t, times.Thrust)).Position
	end
	local function blow(t: number, at: number, amount: number): number
		if t < at then
			return 0
		end
		local u = (t - at) / 0.07
		return amount * u * math.exp(1 - u)
	end
	return Cinematic.Camera(function(elapsed)
		local t = math.min(elapsed, times.Length)
		-- From beside his shoulder, round the other way to him...
		local counter = rad(-40) - rad(40) * smooth(t / times.Out)
		-- ...then on round behind him for the spear.
		local behind = smooth((t - (times.Out - 0.35)) / 0.45)
		local angle = counter + (rad(18) - counter) * behind
		local radial = plan.out * math.cos(angle) + plan.side * math.sin(angle)
		local heart = them(t)
		local eye = heart + radial * (11 + 3 * behind) + UP * (0.6 + 1.6 * behind)
		local follow = smooth((t - times.Thrust) / 0.25)
		local focus = heart:Lerp(heart - plan.out * 8, follow) + UP * 0.4
		local fov = 72 - 4 * behind
		for _, cut in times.Cuts do
			fov -= blow(t, cut, 3)
		end
		fov -= blow(t, times.Thrust, 9)
		return CFrame.lookAt(eye, focus) * CFrame.Angles(0, 0, rad(3 - 5 * behind)), fov
	end, times.Length + 0.05)
end

return Waltz
