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

export type Pose = { [string]: CFrame }

export type Keyframe = {
	time: number,
	pose: Pose,
	easing: Enum.EasingStyle?, -- easing INTO this keyframe
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
}

local tracks: { [Model]: Track } = {}
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

local function ease(alpha: number, style: Enum.EasingStyle?): number
	if style == Enum.EasingStyle.Linear then
		return alpha
	elseif style == Enum.EasingStyle.Back then
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * (alpha - 1) ^ 3 + c1 * (alpha - 1) ^ 2
	elseif style == Enum.EasingStyle.Sine then
		return math.sin(alpha * math.pi / 2)
	end
	return 1 - (1 - alpha) * (1 - alpha) -- Quad out
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
			return from:Lerp(to, ease(alpha, nextFrame.easing))
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

local function release(track: Track)
	-- Hand the joints back; the default Animator overwrites them next frame
	-- if it's animating them.
	for _, joint in track.joints do
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
	for character, track in tracks do
		local elapsed = now - track.start
		local animation = track.animation
		local fadeIn = animation.fadeIn or 0.04
		local fadeOut = animation.fadeOut or 0.15
		local total = track.length + fadeOut

		local dead = not character.Parent or character:GetAttribute("Ragdolled") == true
		if dead or elapsed >= total then
			tracks[character] = nil
			release(track)
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

		local weight = 1
		if elapsed < fadeIn then
			weight = elapsed / fadeIn
		elseif elapsed > track.length then
			weight = 1 - (elapsed - track.length) / fadeOut
		end

		local additive = animation.additive or {}
		for poseName, joint in track.joints do
			local current = joint.Transform
			local base = if lastWritten[joint] == current then CFrame.identity else current
			-- Convert from parent-part space into the joint's own space.
			local c0 = joint.C0.Rotation
			local local_ = c0:Inverse() * sample(animation, poseName, elapsed) * c0
			local target = if additive[poseName] then base * local_ else local_
			local final = base:Lerp(target, weight)
			joint.Transform = final
			lastWritten[joint] = final
		end
	end
end

-- Plays `animation` on `character`, replacing whatever this module was playing on it.
function PoseAnimator.Play(character: Model, animation: Animation, onEvent: ((name: string) -> ())?)
	local existing = tracks[character]
	if existing then
		tracks[character] = nil
		release(existing)
	end

	local posed = posedJoints(animation)
	local all = findJoints(character)
	local joints = {}
	for poseName, joint in all do
		if posed[poseName] then
			joints[poseName] = joint
		end
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
	}
end

function PoseAnimator.Stop(character: Model)
	local track = tracks[character]
	if track then
		tracks[character] = nil
		release(track)
	end
end

function PoseAnimator.Start()
	-- PreSimulation runs after the default Animator has written its pose, so
	-- whatever we set here is what gets rendered.
	RunService.PreSimulation:Connect(step)
end

return PoseAnimator
