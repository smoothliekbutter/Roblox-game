--[[
	HUD
	Health bar, Evasive bar, dash cooldown and combo counter. Built in code
	so it can be restyled later without touching Studio.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local localPlayer = Players.LocalPlayer

local COLORS = {
	Back = Color3.fromRGB(18, 18, 24),
	Health = Color3.fromRGB(90, 220, 110),
	HealthLow = Color3.fromRGB(230, 60, 60),
	Evasive = Color3.fromRGB(120, 235, 255),
	Text = Color3.fromRGB(240, 240, 240),
}

local COMBO_TIMEOUT = 1.6

local HUD = {}

local healthFill: Frame
local healthText: TextLabel
local evasiveFill: Frame
local evasiveStroke: UIStroke
local dashOverlay: Frame
local comboLabel: TextLabel
local comboScale: UIScale

local dashReadyAt = 0
local dashDuration = 1
local comboCount = 0
local lastComboHit = 0
local shownHealth = 1

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function bar(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Name = name
	back.Position = position
	back.Size = size
	back.BackgroundColor3 = COLORS.Back
	back.BackgroundTransparency = 0.15
	back.BorderSizePixel = 0
	back.Parent = parent
	corner(back, 6)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner(fill, 6)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	gradient.Rotation = 90
	gradient.Parent = fill

	return back, fill
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.Name = "Bars"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -24)
	holder.Size = UDim2.fromOffset(380, 44)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local healthBack
	healthBack, healthFill = bar(holder, "Health", UDim2.fromOffset(52, 0), UDim2.new(1, -52, 0, 24), COLORS.Health)

	healthText = Instance.new("TextLabel")
	healthText.BackgroundTransparency = 1
	healthText.Size = UDim2.fromScale(1, 1)
	healthText.Font = Enum.Font.GothamBold
	healthText.TextSize = 14
	healthText.TextColor3 = COLORS.Text
	healthText.TextStrokeTransparency = 0.5
	healthText.ZIndex = 2
	healthText.Parent = healthBack

	local evasiveBack
	evasiveBack, evasiveFill =
		bar(holder, "Evasive", UDim2.fromOffset(52, 30), UDim2.new(1, -52, 0, 10), COLORS.Evasive)
	evasiveStroke = Instance.new("UIStroke")
	evasiveStroke.Color = COLORS.Evasive
	evasiveStroke.Thickness = 2
	evasiveStroke.Transparency = 1
	evasiveStroke.Parent = evasiveBack

	-- Dash icon: dark overlay shrinks as the cooldown finishes.
	local dash = Instance.new("Frame")
	dash.Name = "Dash"
	dash.Size = UDim2.fromOffset(44, 44)
	dash.BackgroundColor3 = COLORS.Back
	dash.BackgroundTransparency = 0.15
	dash.BorderSizePixel = 0
	dash.ClipsDescendants = true
	dash.Parent = holder
	corner(dash, 8)

	local dashLabel = Instance.new("TextLabel")
	dashLabel.BackgroundTransparency = 1
	dashLabel.Size = UDim2.fromScale(1, 1)
	dashLabel.Font = Enum.Font.GothamBlack
	dashLabel.Text = "Q"
	dashLabel.TextSize = 20
	dashLabel.TextColor3 = COLORS.Text
	dashLabel.ZIndex = 3
	dashLabel.Parent = dash

	dashOverlay = Instance.new("Frame")
	dashOverlay.AnchorPoint = Vector2.new(0, 1)
	dashOverlay.Position = UDim2.fromScale(0, 1)
	dashOverlay.Size = UDim2.fromScale(1, 0)
	dashOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	dashOverlay.BackgroundTransparency = 0.35
	dashOverlay.BorderSizePixel = 0
	dashOverlay.ZIndex = 2
	dashOverlay.Parent = dash

	comboLabel = Instance.new("TextLabel")
	comboLabel.Name = "Combo"
	comboLabel.AnchorPoint = Vector2.new(1, 0.5)
	comboLabel.Position = UDim2.new(1, -40, 0.45, 0)
	comboLabel.Size = UDim2.fromOffset(260, 70)
	comboLabel.BackgroundTransparency = 1
	comboLabel.Font = Enum.Font.GothamBlack
	comboLabel.TextScaled = true
	comboLabel.TextXAlignment = Enum.TextXAlignment.Right
	comboLabel.TextColor3 = Color3.new(1, 1, 1)
	comboLabel.TextStrokeTransparency = 0
	comboLabel.TextTransparency = 1
	comboLabel.TextStrokeTransparency = 1
	comboLabel.Rotation = -6
	comboLabel.Parent = gui

	comboScale = Instance.new("UIScale")
	comboScale.Parent = comboLabel
end

local function onHit(data)
	if type(data) ~= "table" or data.attacker == nil or data.attacker ~= localPlayer.Character then
		return
	end
	local t = os.clock()
	comboCount = if t - lastComboHit < COMBO_TIMEOUT then comboCount + 1 else 1
	lastComboHit = t

	comboLabel.Text = comboCount .. " HIT" .. (if comboCount == 1 then "" else "S")
	comboLabel.TextTransparency = 0
	comboLabel.TextStrokeTransparency = 0
	comboScale.Scale = 1.5
	TweenService:Create(comboScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function update(dt: number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		shownHealth += (ratio - shownHealth) * math.min(dt * 12, 1)
		healthFill.Size = UDim2.fromScale(shownHealth, 1)
		healthFill.BackgroundColor3 = COLORS.HealthLow:Lerp(COLORS.Health, ratio)
		healthText.Text = string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)

		local evasive = (character :: Model):GetAttribute("Evasive") or 0
		local evasiveRatio = math.clamp(evasive / Config.Evasive.Max, 0, 1)
		evasiveFill.Size = UDim2.fromScale(evasiveRatio, 1)
		-- Pulse the outline when Evasive is ready.
		evasiveStroke.Transparency = if evasiveRatio >= 1 then 0.3 + 0.4 * math.sin(os.clock() * 8) else 1
	end

	local remaining = math.max(dashReadyAt - os.clock(), 0)
	dashOverlay.Size = UDim2.fromScale(1, remaining / dashDuration)

	if comboCount > 0 and os.clock() - lastComboHit > COMBO_TIMEOUT then
		comboCount = 0
		TweenService:Create(comboLabel, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
end

function HUD.SetDashCooldown(duration: number)
	dashDuration = duration
	dashReadyAt = os.clock() + duration
end

function HUD.Start()
	build()
	Remotes.VFX.OnClientEvent:Connect(function(name, data)
		if name == "Hit" or name == "HeavyHit" then
			onHit(data)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return HUD
