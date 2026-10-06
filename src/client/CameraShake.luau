local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local MAX_ANGLE = 4
local DECAY = 1.8
local FREQUENCY = 25
local BASE_FOV = 70

local CameraShake = {}

local trauma = 0
local seed = math.random() * 1000

function CameraShake.Add(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1)
end

function CameraShake.FovKick(amount: number)
	local camera = workspace.CurrentCamera
	camera.FieldOfView = BASE_FOV + amount
	TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = BASE_FOV,
	}):Play()
end

function CameraShake.Start()
	Remotes.CameraShake.OnClientEvent:Connect(function(intensity)
		if type(intensity) == "number" then
			CameraShake.Add(intensity)
		end
	end)

	RunService:BindToRenderStep("CloverCameraShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if trauma <= 0 then
			return
		end
		trauma = math.max(0, trauma - dt * DECAY)
		local amount = trauma * trauma * MAX_ANGLE
		local t = os.clock() * FREQUENCY
		local camera = workspace.CurrentCamera
		camera.CFrame = camera.CFrame
			* CFrame.Angles(
				math.rad(math.noise(seed, t) * amount),
				math.rad(math.noise(seed + 10, t) * amount),
				math.rad(math.noise(seed + 20, t) * amount * 0.5)
			)
	end)
end

return CameraShake
