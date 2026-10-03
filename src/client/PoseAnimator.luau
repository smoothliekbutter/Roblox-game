--[[
	PoseAnimator
	Keyframe animations defined in code, played by overriding Motor6D.Transform
	every frame. No uploaded animation assets needed, so they work in any place
	without animation permissions.

	Runs on every client for every character: the server tells clients
	"this character swung", each client animates it locally.

	Poses rotate a limb around its joint in the PARENT part's space:
	  Torso       RootJoint, relative to HumanoidRootPart
	  Head        Neck, relative to Torso
	  RightArm    Right Shoulder, relative to Torso
	  LeftArm     Left Shoulder
	  RightLeg    Right Hip
	  LeftLeg     Left Hip
	  Sword       SwordGrip (a weapon's wrist), relative to the right arm
	Axes: X = right, Y = up, Z = back. So for a limb hanging down,
	  +X rotation swings it forward, +Y turns it to the left,
	  +Z swings it out to the right. For the Torso, +X leans back.

	Two layers per character:
	  idle   a looping stance, one version for standing still and one for
	         moving, blended by how fast the character is going
	  track  one-shot animations (attacks, skills) that blend in from
	         wherever the body is and back out into the idle
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

export type Pose = { [string]: CFrame }

export type Keyframe = {
	time: number,
	pose: Pose,
	easing: Enum.EasingStyle?, -- easing INTO this keyframe (default Quad)
	direction: Enum.EasingDirection?, -- (default Out)
}

export type Animation = {
	keyframes: { Keyframe },
	fadeIn: number?,
	fadeOut: number?,
	loop: boolean?,
	-- Joints whose pose is layered on top of the layer below instead of
	-- replacing it (e.g. legs counter-twisting while still walking).
	additive: { [string]: boolean }?,
	-- Overlapping action: a joint with a delay follows the animation that
	-- many seconds late (negative leads), so the body leads and the arm and
	-- weapon drag behind like in hand-made animation.
	delays: { [string]: number }?,
	events: { { time: number, name: string } }?,
}

export type IdleSet = {
	stand: Animation?, -- played while standing still
	move: Animation?, -- played while moving (a walk/run cycle)
	air: Animation?, -- played while jumping or falling
	-- The speed the move cycle is animated for; it plays faster or slower
	-- with the character's actual speed so feet don't slide.
	moveSpeed: number?,
}

local JOINTS = {
	Torso = "RootJoint",
	Head = "Neck",
	RightArm = "Right Shoulder",
	LeftArm = "Left Shoulder",
	RightLeg = "Right Hip",
	LeftLeg = "Left Hip",
	Sword = "SwordGrip",
}

local STAND_SPEED = 1.5 -- studs/s; slower than this counts as standing still
local STANCE_BLEND = 8 -- how fast the idle switches between stand and move
local AIR_SPEED = 6 -- vertical studs/s; faster than this counts as airborne
local AIR_BLEND = 10

type Track = {
	animation: Animation,
	joints: { [string]: Motor6D },
	start: number,
	length: number,
	onEvent: ((name: string) -> ())?,
	firedEvents: { [number]: boolean },
	-- Where each joint actually was when this track started, so a new swing
	-- blends from the previous swing's pose instead of snapping to idle.
	from: { [string]: CFrame },
	-- Hit-stop: the animation holds still until this time.
	freezeUntil: number,
	frozenAt: number,
	-- Set when the track is told to stop early (FadeOut).
	fadeOutOverride: number?,
}

type Idle = {
	set: IdleSet,
	covered: { [string]: boolean },
	joints: { [string]: Motor6D },
	start: number,
	standWeight: number,
	airWeight: number,
	moveClock: number,
	nextJointScan: number,
}

local tracks: { [Model]: Track } = {}
local idles: { [Model]: Idle } = {}
-- What we wrote to each joint last frame. If the default Animator didn't
-- overwrite it, the joint has no base animation and its base is identity.
local lastWritten: { [Motor6D]: CFrame } = {}
local posedCache: { [Animation]: { [string]: boolean } } = setmetatable({}, { __mode = "k" }) :: any

local PoseAnimator = {}

local function findJoints(character: Model): { [string]: Motor6D }
	local found = {}
	for poseName, jointName in JOINTS do
		local joint = character:FindFirstChild(jointName, true)
		if joint and joint:IsA("Motor6D") then
			found[poseName] = joint
		end
	end
	return found
end

local function ease(alpha: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): number
	return TweenService:GetValue(alpha, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
end

-- Smooth 0..1 ramp (no sudden starts/stops) for fading tracks in and out.
local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function lengthOf(animation: Animation): number
	local keyframes = animation.keyframes
	return keyframes[#keyframes].time
end

local function posed(animation: Animation): { [string]: boolean }
	local cached = posedCache[animation]
	if cached then
		return cached
	end
	local set = {}
	for _, keyframe in animation.keyframes do
		for poseName in keyframe.pose do
			set[poseName] = true
		end
	end
	posedCache[animation] = set
	return set
end

-- The animation's pose for one joint at time t (identity if never posed).
-- Applies the joint's delay; looping animations wrap around.
local function sample(animation: Animation, poseName: string, t: number): CFrame
	local delays = animation.delays
	if delays and delays[poseName] then
		t -= delays[poseName]
	end
	local keyframes = animation.keyframes
	if animation.loop then
		local length = keyframes[#keyframes].time
		if length > 0 then
			t %= length
		end
	end

	local previous = keyframes[1]
	if t <= previous.time then
		return previous.pose[poseName] or CFrame.identity
	end
	for i = 2, #keyframes do
		local nextFrame = keyframes[i]
		if t <= nextFrame.time then
			local span = nextFrame.time - previous.time
			local alpha = if span > 0 then (t - previous.time) / span else 1
			local from = previous.pose[poseName] or CFrame.identity
			local to = nextFrame.pose[poseName] or CFrame.identity
			return from:Lerp(to, ease(alpha, nextFrame.easing, nextFrame.direction))
		end
		previous = nextFrame
	end
	return previous.pose[poseName] or CFrame.identity
end

-- Parent-part-space pose -> the joint's own space.
local function toJointSpace(joint: Motor6D, pose: CFrame): CFrame
	local c0 = joint.C0.Rotation
	return c0:Inverse() * pose * c0
end

-- What the default Animator (walk/idle) set this frame, or identity if
-- nothing but us animates this joint.
local function animatorBase(joint: Motor6D): CFrame
	local current = joint.Transform
	return if lastWritten[joint] == current then CFrame.identity else current
end

local function write(joint: Motor6D, value: CFrame)
	joint.Transform = value
	lastWritten[joint] = value
end

local function release(track: Track, character: Model)
	-- Hand the joints back; the default Animator overwrites them next frame
	-- if it's animating them. Joints the idle covers stay put, the idle
	-- takes over next frame.
	local idle = idles[character]
	for poseName, joint in track.joints do
		if idle and idle.joints[poseName] then
			continue
		end
		if lastWritten[joint] then
			lastWritten[joint] = nil
			if joint.Parent then
				joint.Transform = CFrame.identity
			end
		end
	end
end

-- One idle animation's value for a joint (joint space), or nil if it doesn't pose it.
local function layer(animation: Animation?, poseName: string, joint: Motor6D, time: number): CFrame?
	if animation and posed(animation)[poseName] then
		return toJointSpace(joint, sample(animation, poseName, time))
	end
	return nil
end

-- The idle layer's value for every joint it covers this frame (joint space).
local function idleValues(character: Model, idle: Idle, now: number, dt: number): { [string]: CFrame }
	-- Joints can show up late (a weapon replicating after the kit was set)
	-- or get recreated (avatar applied), so look for missing ones now and then.
	if now >= idle.nextJointScan then
		idle.nextJointScan = now + 0.25
		local fresh: { [string]: Motor6D }? = nil
		for poseName in idle.covered do
			local joint = idle.joints[poseName]
			if not joint or not joint.Parent then
				fresh = fresh or findJoints(character)
				idle.joints[poseName] = (fresh :: { [string]: Motor6D })[poseName]
			end
		end
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed, verticalSpeed = 0, 0
	if root then
		local velocity = root.AssemblyLinearVelocity
		speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		verticalSpeed = math.abs(velocity.Y)
	end
	local set = idle.set
	local standTarget = if speed < STAND_SPEED then 1 else 0
	idle.standWeight += (standTarget - idle.standWeight) * math.min(dt * STANCE_BLEND, 1)
	local airTarget = if set.air and verticalSpeed > AIR_SPEED then 1 else 0
	idle.airWeight += (airTarget - idle.airWeight) * math.min(dt * AIR_BLEND, 1)
	-- The run cycle keeps pace with the actual movement speed.
	idle.moveClock += dt * math.clamp(speed / (set.moveSpeed or 16), 0.5, 2)
	local standW, airW = smooth(idle.standWeight), smooth(idle.airWeight)

	local t = now - idle.start
	local values = {}
	for poseName, joint in idle.joints do
		if not joint.Parent then
			continue
		end
		local base = animatorBase(joint)
		-- Moving (or the default walk), blended toward standing, then air.
		local value = layer(set.move, poseName, joint, idle.moveClock) or base
		value = value:Lerp(layer(set.stand, poseName, joint, t) or base, standW)
		local air = layer(set.air, poseName, joint, t)
		if air and airW > 0 then
			value = value:Lerp(air, airW)
		end
		values[poseName] = value
	end
	return values
end

local function step(dt: number)
	local now = os.clock()

	local idleFrame: { [Model]: { [string]: CFrame } } = {}
	for character, idle in idles do
		if not character.Parent then
			idles[character] = nil
			continue
		end
		if character:GetAttribute("Ragdolled") == true then
			continue
		end
		local values = idleValues(character, idle, now, dt)
		idleFrame[character] = values
		local track = tracks[character]
		for poseName, value in values do
			if not (track and track.joints[poseName]) then
				write(idle.joints[poseName], value)
			end
		end
	end

	for character, track in tracks do
		local elapsed = if now < track.freezeUntil then track.frozenAt else now - track.start
		local animation = track.animation
		local fadeIn = animation.fadeIn or 0.04
		local fadeOut = track.fadeOutOverride or animation.fadeOut or 0.15
		local total = track.length + fadeOut

		local dead = not character.Parent or character:GetAttribute("Ragdolled") == true
		if dead or elapsed >= total then
			tracks[character] = nil
			release(track, character)
			continue
		end

		if animation.events and track.onEvent then
			for index, event in animation.events do
				if not track.firedEvents[index] and elapsed >= event.time then
					track.firedEvents[index] = true
					task.spawn(track.onEvent, event.name)
				end
			end
		end

		local fadingIn = elapsed < fadeIn
		local weight = 1
		if fadingIn then
			weight = smooth(elapsed / fadeIn)
		elseif elapsed > track.length then
			weight = 1 - smooth((elapsed - track.length) / fadeOut)
		end

		local additive = animation.additive or {}
		local idleValuesNow = idleFrame[character]
		local clampedTime = math.min(elapsed, track.length)
		for poseName, joint in track.joints do
			if not joint.Parent then
				continue
			end
			local base = (idleValuesNow and idleValuesNow[poseName]) or animatorBase(joint)
			local local_ = toJointSpace(joint, sample(animation, poseName, clampedTime))
			local target = if additive[poseName] then base * local_ else local_
			-- Fading in starts from wherever the joint really was (mid-swing
			-- from the previous track, for example), not from the base.
			local start = if fadingIn then track.from[poseName] or base else base
			write(joint, start:Lerp(target, weight))
		end
	end
end

-- Plays `animation` on `character`, replacing whatever this module was playing on it.
function PoseAnimator.Play(character: Model, animation: Animation, onEvent: ((name: string) -> ())?)
	local wanted = posed(animation)
	local joints = {}
	local from = {}
	for poseName, joint in findJoints(character) do
		if wanted[poseName] then
			joints[poseName] = joint
			from[poseName] = joint.Transform -- captured before the old track lets go
		end
	end

	local existing = tracks[character]
	if existing then
		tracks[character] = nil
		release(existing, character)
	end
	if next(joints) == nil then
		return -- not an R6 rig
	end

	tracks[character] = {
		animation = animation,
		joints = joints,
		start = os.clock(),
		length = lengthOf(animation),
		onEvent = onEvent,
		firedEvents = {},
		from = from,
		freezeUntil = 0,
		frozenAt = 0,
	}
end

function PoseAnimator.Stop(character: Model)
	local track = tracks[character]
	if track then
		tracks[character] = nil
		release(track, character)
	end
end

-- The animation currently playing on a character, if any.
function PoseAnimator.Current(character: Model): Animation?
	local track = tracks[character]
	return if track then track.animation else nil
end

-- Ends the current animation early, fading out from wherever it is now.
function PoseAnimator.FadeOut(character: Model, duration: number?)
	local track = tracks[character]
	if not track then
		return
	end
	local elapsed = os.clock() - track.start
	if elapsed < track.length then
		track.length = math.max(elapsed, 0)
	end
	track.fadeOutOverride = duration
end

-- Hit-stop: holds the character's current animation still for `duration`,
-- then lets it continue from the same point.
function PoseAnimator.Freeze(character: Model, duration: number)
	local track = tracks[character]
	if not track then
		return
	end
	local now = os.clock()
	if now < track.freezeUntil then
		return
	end
	track.frozenAt = now - track.start
	track.freezeUntil = now + duration
	track.start += duration
end

-- Sets (or clears, with nil) a character's idle layer.
function PoseAnimator.SetIdle(character: Model, set: IdleSet?)
	local old = idles[character]
	if old then
		idles[character] = nil
		for _, joint in old.joints do
			if lastWritten[joint] then
				lastWritten[joint] = nil
				joint.Transform = CFrame.identity
			end
		end
	end
	if not set then
		return
	end
	local covered: { [string]: boolean } = {}
	for _, animation in { set.stand, set.move, set.air } do
		for poseName in posed(animation :: Animation) do
			covered[poseName] = true
		end
	end
	local joints = {}
	for poseName, joint in findJoints(character) do
		if covered[poseName] then
			joints[poseName] = joint
		end
	end
	idles[character] = {
		set = set,
		covered = covered,
		joints = joints,
		start = os.clock(),
		standWeight = 1,
		airWeight = 0,
		moveClock = 0,
		nextJointScan = 0,
	}
end

function PoseAnimator.Start()
	-- PreSimulation runs after the default Animator has written its pose, so
	-- whatever we set here is what gets rendered.
	RunService.PreSimulation:Connect(step)
end

return PoseAnimator
