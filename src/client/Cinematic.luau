--[[
	Cinematic
	Tools for cutscenes (e.g. Asta's Black Moon):
	  Cinematic.Camera(shot, length)  a scripted camera for the people in the
	      cutscene: letterbox bars slide in, the HUD hides, shift lock lets
	      go, and shot(t) places the camera every frame. Returns finish().
	  Cinematic.Night(fadeIn)  night falls: the sky turns to midnight, the
	      light goes cold and dim. Returns lift(fadeOut).
	  Cinematic.Dawn(fadeIn)  the Golden Dawn: the sun low and gold, the light
	      warm. Returns lift(fadeOut). Settings nest (the latest one's light
	      wins), so overlapping cutscenes don't fight over the lighting.
	All of them always put everything back, even if the cutscene is cut short.
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
-- Settings: the sky and the light change for a cutscene (Night, Dawn)
---------------------------------------------------------------------------

local depth = 0 -- settings in force (they nest: the latest one's light wins)
-- The daylight to go back to. Kept until the fade back has finished, so a
-- setting that starts mid-fade doesn't take the half-changed sky for daylight.
local saved: { [string]: any }? = nil
local grade: ColorCorrectionEffect? = nil
local generation = 0 -- bumped whenever a setting starts or lifts

type Preset = {
	lighting: { [string]: any },
	atmosphere: { [string]: any },
	grade: { [string]: any },
}

-- Moonlit rather than pitch black: dark sky, but you can still read the fight.
local NIGHT: Preset = {
	lighting = {
		ClockTime = 23.8,
		Brightness = 2,
		Ambient = Color3.fromRGB(72, 72, 98),
		OutdoorAmbient = Color3.fromRGB(106, 110, 148),
		ExposureCompensation = 0.3,
	},
	-- A clear night: the moon shouldn't fade into the haze.
	atmosphere = { Density = 0.06, Haze = 0, Color = Color3.fromRGB(82, 90, 132) },
	grade = { Saturation = -0.2, Contrast = 0.1, Brightness = 0.07, TintColor = Color3.fromRGB(224, 230, 255) },
}

-- The Golden Dawn: the sun low on the horizon, the sky gold over green, the
-- light warm and bright (never dark), the haze glowing.
local DAWN: Preset = {
	lighting = {
		ClockTime = 6.6,
		Brightness = 3.6,
		Ambient = Color3.fromRGB(104, 112, 98),
		OutdoorAmbient = Color3.fromRGB(160, 168, 146),
		ExposureCompensation = 0.4,
	},
	atmosphere = {
		Density = 0.3,
		Haze = 2,
		Color = Color3.fromRGB(255, 212, 150),
		Decay = Color3.fromRGB(96, 168, 140),
		Glare = 0.7,
	},
	grade = { Saturation = 0.16, Contrast = 0.08, Brightness = 0.05, TintColor = Color3.fromRGB(255, 247, 228) },
}

local ATMOSPHERE_KEYS = { "Density", "Haze", "Color", "Decay", "Glare" }

local function setting(preset: Preset, fadeIn: number): (fadeOut: number?) -> ()
	depth += 1
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
			local air = {}
			for _, name in ATMOSPHERE_KEYS do
				air[name] = (atmosphere :: any)[name]
			end
			before.atmosphere = air
		end
		saved = before
	end
	if atmosphere then
		tween(atmosphere, fadeIn, preset.atmosphere)
	end
	tween(Lighting, fadeIn, preset.lighting, Enum.EasingStyle.Sine)
	-- Still fading back from the last one? Bring the same grade back.
	local effect = if grade and grade.Parent then grade else Instance.new("ColorCorrectionEffect")
	effect.Name = "CinematicSetting"
	effect.Parent = Lighting
	tween(effect, fadeIn, preset.grade, Enum.EasingStyle.Sine)
	grade = effect

	local lifted = false
	return function(fadeOut: number?)
		if lifted then
			return
		end
		lifted = true
		depth -= 1
		if depth > 0 or not saved then
			return
		end
		local duration = fadeOut or 1
		local before = saved
		generation += 1
		local lifting = generation
		local air = Lighting:FindFirstChildOfClass("Atmosphere")
		if air and before.atmosphere then
			tween(air, duration, before.atmosphere)
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
				return -- another setting started before this one finished lifting
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

-- Night falls: the sky turns to midnight, the light goes cold and dim.
-- Returns lift(fadeOut).
function Cinematic.Night(fadeIn: number): (fadeOut: number?) -> ()
	return setting(NIGHT, fadeIn)
end

-- The Golden Dawn (Yuno): the sun comes up gold on the horizon, the light
-- turns warm and green-gold. Returns lift(fadeOut).
function Cinematic.Dawn(fadeIn: number): (fadeOut: number?) -> ()
	return setting(DAWN, fadeIn)
end

-- Where the sun is in the Dawn (a unit vector toward it), for dressing the
-- sky round it.
function Cinematic.DawnSun(): Vector3
	local before = Lighting.ClockTime
	Lighting.ClockTime = DAWN.lighting.ClockTime
	local direction = Lighting:GetSunDirection()
	Lighting.ClockTime = before
	return direction
end

return Cinematic
