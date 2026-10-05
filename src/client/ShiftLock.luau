-- Our own shift lock (LeftShift or the top bar button).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatState = require(ReplicatedStorage:WaitForChild("Shared").CombatState)

local SHOULDER_OFFSET = Vector3.new(1.75, 0.25, 0)
local DOT_SIZE = 6

local localPlayer = Players.LocalPlayer

local ShiftLock = {}

local enabled = false
local suspended = false -- e.g. a menu is open and needs the mouse
local listeners: { (boolean) -> () } = {}
local dot: Frame? = nil

-- Small aiming dot in the middle of the screen (replaces the mouse cursor).
local function buildDot()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShiftLockDot"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.4
	stroke.Thickness = 1
	stroke.Parent = frame

	dot = frame
end

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
	UserInputService.MouseIconEnabled = not active
	if dot then
		dot.Visible = active
	end
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
	buildDot()
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
		-- Ragdolled, a skill is steering the body (Bull Thrust), or a cutscene.
		if
			CombatState.IsRagdolled(character)
			or character:GetAttribute("Steering") == true
			or character:GetAttribute("Cinematic") == true
		then
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
