--[[
	ShiftLock
	Our own shift lock (Roblox's built-in one is turned off in StarterPlayer):
	LeftShift or the top bar button toggles it. While on, the mouse is locked
	to the center, the camera sits over the right shoulder and the character
	always faces where the camera looks, so attacks go where you aim.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatState = require(ReplicatedStorage:WaitForChild("Shared").CombatState)

local SHOULDER_OFFSET = Vector3.new(1.75, 0.25, 0)
local LOCKED_CURSOR = "rbxasset://textures/MouseLockedCursor.png"

local localPlayer = Players.LocalPlayer

local ShiftLock = {}

local enabled = false
local suspended = false -- e.g. a menu is open and needs the mouse
local listeners: { (boolean) -> () } = {}

local function getHumanoid(): (Humanoid?, BasePart?)
	local character = localPlayer.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function apply()
	local active = enabled and not suspended
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.AutoRotate = not active
		humanoid.CameraOffset = if active then SHOULDER_OFFSET else Vector3.zero
	end
	UserInputService.MouseIcon = if active then LOCKED_CURSOR else ""
	if not active then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

function ShiftLock.IsEnabled(): boolean
	return enabled
end

function ShiftLock.Set(value: boolean)
	if enabled == value then
		return
	end
	enabled = value
	apply()
	for _, listener in listeners do
		task.spawn(listener, enabled)
	end
end

function ShiftLock.Toggle()
	ShiftLock.Set(not enabled)
end

-- Temporarily frees the mouse (menus) without turning shift lock off.
function ShiftLock.SetSuspended(value: boolean)
	suspended = value
	apply()
end

function ShiftLock.OnChanged(listener: (boolean) -> ())
	table.insert(listeners, listener)
end

function ShiftLock.Start()
	ContextActionService:BindAction("CloverShiftLock", function(_, state)
		if state == Enum.UserInputState.Begin then
			ShiftLock.Toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftShift)

	-- After the camera has updated: keep the mouse locked and turn the
	-- character to match the camera.
	RunService:BindToRenderStep("CloverShiftLock", Enum.RenderPriority.Camera.Value + 2, function()
		if not enabled or suspended then
			return
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

		local humanoid, root = getHumanoid()
		if not humanoid or not root or humanoid.Health <= 0 or humanoid.Sit then
			return
		end
		local character = localPlayer.Character :: Model
		if CombatState.IsRagdolled(character) then
			return
		end
		local look = workspace.CurrentCamera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 1e-3 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
		end
	end)

	localPlayer.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		apply()
	end)
end

return ShiftLock
