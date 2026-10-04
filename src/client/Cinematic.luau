--[[
	Cinematic
	Tools for cutscenes (e.g. Asta's Black Moon):
	  Cinematic.Camera(shot, length)  a scripted camera for the people in the
	      cutscene: letterbox bars slide in, the HUD hides, shift lock lets
	      go, and shot(t) places the camera every frame. Returns finish().
	  Cinematic.Night(fadeIn)  night falls: the sky turns to midnight, the
	      light goes cold and dim. Returns lift(fadeOut). Nested nights are
	      counted, so overlapping cutscenes don't fight over the lighting.
	Both always put everything back, even if the cutscene is cut short.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local BASE_FOV = 70 -- same as CameraShake
local BAR_HEIGHT = 0.11 -- letterbox bars, fraction of the screen each

local Cinematic = {}

local function tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goals
	)
	t:Play()
	return t
end

---------------------------------------------------------------------------
-- Camera
---------------------------------------------------------------------------

function Cinematic.Camera(shot: (number) -> (CFrame?, number?), length: number): () -> ()
	local camera = workspace.CurrentCamera
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local character = localPlayer.Character

	-- Everything else on screen goes away.
	local hidden: { ScreenGui } = {}
	if playerGui then
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "Cinematic" then
				gui.Enabled = false
				table.insert(hidden, gui)
			end
		end
	end

	local bars = Instance.new("ScreenGui")
	bars.Name = "Cinematic"
	bars.IgnoreGuiInset = true
	bars.DisplayOrder = 50
	bars.ResetOnSpawn = false
	bars.Parent = playerGui
	local function bar(edge: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0, edge)
		frame.Position = UDim2.fromScale(0, edge)
		frame.Size = UDim2.fromScale(1, 0)
		frame.Parent = bars
		tween(frame, 0.35, { Size = UDim2.fromScale(1, BAR_HEIGHT) })
		return frame
	end
	local top, bottom = bar(0), bar(1)

	if character then
		character:SetAttribute("Cinematic", true)
	end
	camera.CameraType = Enum.CameraType.Scriptable

	local start = os.clock()
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep("CloverCinematic")
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = BASE_FOV
		if character then
			character:SetAttribute("Cinematic", nil)
		end
		tween(top, 0.3, { Size = UDim2.fromScale(1, 0) })
		tween(bottom, 0.3, { Size = UDim2.fromScale(1, 0) })
		task.delay(0.32, function()
			bars:Destroy()
			for _, gui in hidden do
				if gui.Parent then
					gui.Enabled = true
				end
			end
		end)
	end

	-- At camera priority, so CameraShake (just after) still shakes it.
	RunService:BindToRenderStep("CloverCinematic", Enum.RenderPriority.Camera.Value, function()
		local t = os.clock() - start
		if t > length then
			finish()
			return
		end
		local ok, cframe, fov = pcall(shot, t)
		if not ok then
			finish()
			return
		end
		if cframe then
			camera.CFrame = cframe
		end
		if fov then
			camera.FieldOfView = fov
		end
	end)
	task.delay(length + 1, finish) -- whatever happens, give the camera back
	return finish
end

---------------------------------------------------------------------------
-- Night
---------------------------------------------------------------------------

local nights = 0
-- The daylight to go back to. Kept until the fade back has finished, so a
-- night that starts mid-fade doesn't take the half-dark sky for daylight.
local saved: { [string]: any }? = nil
local grade: ColorCorrectionEffect? = nil
local generation = 0 -- bumped whenever a night starts or lifts

-- Moonlit rather than pitch black: dark sky, but you can still read the fight.
local NIGHT_LIGHTING = {
	ClockTime = 23.8,
	Brightness = 2,
	Ambient = Color3.fromRGB(72, 72, 98),
	OutdoorAmbient = Color3.fromRGB(106, 110, 148),
	ExposureCompensation = 0.3,
}

function Cinematic.Night(fadeIn: number): (fadeOut: number?) -> ()
	nights += 1
	if nights == 1 then
		generation += 1
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if not saved then
			local before: { [string]: any } = {
				ClockTime = Lighting.ClockTime,
				Brightness = Lighting.Brightness,
				Ambient = Lighting.Ambient,
				OutdoorAmbient = Lighting.OutdoorAmbient,
				ExposureCompensation = Lighting.ExposureCompensation,
			}
			if atmosphere then
				before.atmosphere = { Density = atmosphere.Density, Haze = atmosphere.Haze, Color = atmosphere.Color }
			end
			saved = before
		end
		if atmosphere then
			-- A clear night: the moon shouldn't fade into the haze.
			tween(atmosphere, fadeIn, { Density = 0.06, Haze = 0, Color = Color3.fromRGB(82, 90, 132) })
		end
		tween(Lighting, fadeIn, NIGHT_LIGHTING, Enum.EasingStyle.Sine)
		-- Still fading out from the last night? Bring the same grade back.
		local effect = if grade and grade.Parent then grade else Instance.new("ColorCorrectionEffect")
		effect.Name = "CinematicNight"
		effect.Parent = Lighting
		tween(effect, fadeIn, {
			Saturation = -0.2,
			Contrast = 0.1,
			Brightness = 0.07,
			TintColor = Color3.fromRGB(224, 230, 255),
		}, Enum.EasingStyle.Sine)
		grade = effect
	end

	local lifted = false
	return function(fadeOut: number?)
		if lifted then
			return
		end
		lifted = true
		nights -= 1
		if nights > 0 or not saved then
			return
		end
		local duration = fadeOut or 1
		local before = saved
		generation += 1
		local lifting = generation
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere and before.atmosphere then
			tween(atmosphere, duration, before.atmosphere)
		end
		local restore = table.clone(before)
		restore.atmosphere = nil
		tween(Lighting, duration, restore, Enum.EasingStyle.Sine)
		local effect = grade
		if effect then
			tween(effect, duration, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
		end
		task.delay(duration + 0.05, function()
			if generation ~= lifting then
				return -- another night fell before this one finished lifting
			end
			saved = nil
			if effect then
				effect:Destroy()
			end
			if grade == effect then
				grade = nil
			end
		end)
	end
end

return Cinematic
