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
	Axes: X = right, Y = up, Z = back. So for a limb hanging down,
	  +X rotation swings it forward, +Y turns it to the left,
	  +Z swings it out to the right. For the Torso, +X leans back.
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
	-- Joints whose pose is layered on top of the default walk/idle animation
	-- instead of replacing it (e.g. legs counter-twisting while still walking).
	additive: { [string]: boolean }?,
	events: { { time: number, name: string } }?,
}

local JOINTS = {
	Torso = "RootJoint",
	Head = "Neck",
	RightArm = "Right Shoulder",
	LeftArm = "Left Shoulder",
	RightLeg = "Right Hip",
	LeftLeg = "Left Hip",
}

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
}

type Idle = {
	pose: Pose,
	joints: { [string]: Motor6D },
}

local tracks: { [Model]: Track } = {}
-- Persistent stances (e.g. holding a sword up) that play whenever no
-- animation is using those joints, and that animations blend from/to.
local idles: { [Model]: Idle } = {}
-- What we wrote to each joint last frame. If the default Animator didn't
-- overwrite it, the joint has no base animation and its base is identity.
local lastWritten: { [Motor6D]: CFrame } = {}

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

-- The animation's pose for one joint at time t (identity if never posed).
local function sample(animation: Animation, poseName: string, t: number): CFrame
	local keyframes = animation.keyframes
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

local function posedJoints(animation: Animation): { [string]: boolean }
	local set = {}
	for _, keyframe in animation.keyframes do
		for poseName in keyframe.pose do
			set[poseName] = true
		end
	end
	return set
end

-- Parent-part-space pose -> the joint's own space.
local function toJointSpace(joint: Motor6D, pose: CFrame): CFrame
	local c0 = joint.C0.Rotation
	return c0:Inverse() * pose * c0
end

local function release(track: Track, character: Model)
	-- Hand the joints back; the default Animator overwrites them next frame
	-- if it's animating them. Joints with an idle stance stay put, the idle
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

local function step()
	local now = os.clock()

	for character, idle in idles do
		if not character.Parent then
			idles[character] = nil
			continue
		end
		if character:GetAttribute("Ragdolled") == true then
			continue
		end
		-- Joints get recreated if the body is rebuilt (e.g. avatar applied).
		for poseName, joint in idle.joints do
			if not joint.Parent then
				local fresh = findJoints(character)[poseName]
				if fresh then
					idle.joints[poseName] = fresh
				end
			end
		end
		local track = tracks[character]
		for poseName, joint in idle.joints do
			if joint.Parent and not (track and track.joints[poseName]) then
				local value = toJointSpace(joint, idle.pose[poseName])
				joint.Transform = value
				lastWritten[joint] = value
			end
		end
	end

	for character, track in tracks do
		local elapsed = if now < track.freezeUntil then track.frozenAt else now - track.start
		local animation = track.animation
		local fadeIn = animation.fadeIn or 0.04
		local fadeOut = animation.fadeOut or 0.15
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
		local idle = idles[character]
		for poseName, joint in track.joints do
			local base
			if idle and idle.joints[poseName] then
				base = toJointSpace(joint, idle.pose[poseName])
			else
				local current = joint.Transform
				base = if lastWritten[joint] == current then CFrame.identity else current
			end
			local local_ = toJointSpace(joint, sample(animation, poseName, elapsed))
			local target = if additive[poseName] then base * local_ else local_
			-- Fading in starts from wherever the joint really was (mid-swing
			-- from the previous track, for example), not from the base.
			local start = if fadingIn then track.from[poseName] or base else base
			local final = start:Lerp(target, weight)
			joint.Transform = final
			lastWritten[joint] = final
		end
	end
end

-- Plays `animation` on `character`, replacing whatever this module was playing on it.
function PoseAnimator.Play(character: Model, animation: Animation, onEvent: ((name: string) -> ())?)
	local posed = posedJoints(animation)
	local all = findJoints(character)
	local joints = {}
	local from = {}
	for poseName, joint in all do
		if posed[poseName] then
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

	local keyframes = animation.keyframes
	tracks[character] = {
		animation = animation,
		joints = joints,
		start = os.clock(),
		length = keyframes[#keyframes].time,
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

-- Sets (or clears, with nil) a persistent stance for some joints.
function PoseAnimator.SetIdle(character: Model, pose: Pose?)
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
	if not pose then
		return
	end
	local joints = {}
	for poseName, joint in findJoints(character) do
		if pose[poseName] then
			joints[poseName] = joint
		end
	end
	if next(joints) ~= nil then
		idles[character] = { pose = pose, joints = joints }
	end
end

function PoseAnimator.Start()
	-- PreSimulation runs after the default Animator has written its pose, so
	-- whatever we set here is what gets rendered.
	RunService.PreSimulation:Connect(step)
end

return PoseAnimator
