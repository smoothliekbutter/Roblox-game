--[[
	HUD
	Top right: character name, health, Evasive and Awakening bars.
	Bottom:    move bar (Q dash, skills 1-4, G awakening) with cooldowns.
	Right:     combo counter.
	Top:       toast messages from the server.
	Built in code so it can be restyled without touching Studio.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatState = require(Shared.CombatState)
local Config = require(Shared.Config)
local Kits = require(Shared.Kits)
local Remotes = require(Shared.Remotes)

local localPlayer = Players.LocalPlayer

local COLORS = {
	Panel = Color3.fromRGB(14, 14, 18),
	Back = Color3.fromRGB(28, 28, 34),
	Health = Color3.fromRGB(90, 220, 110),
	HealthLow = Color3.fromRGB(230, 60, 60),
	Evasive = Color3.fromRGB(120, 235, 255),
	Awakening = Color3.fromRGB(220, 40, 50),
	Text = Color3.fromRGB(240, 240, 240),
	SubText = Color3.fromRGB(170, 170, 180),
	Locked = Color3.fromRGB(60, 60, 68),
}

local COMBO_TIMEOUT = 1.6
local SLOT_SIZE = 74

type Slot = {
	frame: Frame,
	stroke: UIStroke,
	name: TextLabel,
	overlay: Frame,
	timer: TextLabel,
}

local HUD = {}

local ui: {
	kitTitle: TextLabel,
	kitStrip: Frame,
	healthFill: Frame,
	healthText: TextLabel,
	evasiveFill: Frame,
	evasiveStroke: UIStroke,
	awakeningFill: Frame,
	awakeningStroke: UIStroke,
	awakeningLabel: TextLabel,
	dash: Slot,
	skills: { Slot },
	awaken: Slot,
	comboLabel: TextLabel,
	comboScale: UIScale,
	toast: TextLabel,
} =
	{} :: any

local dashReadyAt = 0
local dashDuration = 1
local comboCount = 0
local lastComboHit = 0
local shownHealth = 1
local shownKit: string? = "?"
local shownAwakened = false
local toastToken = 0

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = COLORS.Text
	l.TextStrokeTransparency = 0.6
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function bar(parent: Instance, position: UDim2, size: UDim2, color: Color3): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Position = position
	back.Size = size
	back.BackgroundColor3 = COLORS.Back
	back.BorderSizePixel = 0
	back.Parent = parent
	corner(back, 4)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner(fill, 4)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(165, 165, 165))
	gradient.Rotation = 90
	gradient.Parent = fill

	return back, fill
end

local function slot(parent: Instance, key: string, order: number): Slot
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	frame.BackgroundColor3 = COLORS.Panel
	frame.BackgroundTransparency = 0.2
	frame.LayoutOrder = order
	frame.ClipsDescendants = true
	frame.Parent = parent
	corner(frame, 8)

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Locked
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	label(frame, {
		Text = key,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(7, 4),
		Size = UDim2.fromOffset(20, 16),
		ZIndex = 4,
	})

	local name = label(frame, {
		Text = "",
		TextWrapped = true,
		TextSize = 12,
		Position = UDim2.new(0, 4, 0, 20),
		Size = UDim2.new(1, -8, 1, -24),
		ZIndex = 4,
	})

	-- Dark curtain that shrinks as the cooldown finishes.
	local overlay = Instance.new("Frame")
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 2
	overlay.Parent = frame

	local timer = label(frame, {
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		TextStrokeTransparency = 0.2,
	})

	return { frame = frame, stroke = stroke, name = name, overlay = overlay, timer = timer }
end

local function setSlotCooldown(s: Slot, remaining: number, length: number)
	s.overlay.Size = UDim2.fromScale(1, math.clamp(remaining / math.max(length, 0.01), 0, 1))
	s.timer.Text = if remaining > 0 then string.format(if remaining < 10 then "%.1f" else "%d", remaining) else ""
	s.name.TextTransparency = if remaining > 0 then 0.5 else 0
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	-- Top right status panel.
	local status = Instance.new("Frame")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(1, 0)
	status.Position = UDim2.new(1, -16, 0, 12)
	status.Size = UDim2.fromOffset(320, 92)
	status.BackgroundColor3 = COLORS.Panel
	status.BackgroundTransparency = 0.25
	status.Parent = gui
	corner(status, 10)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 8)
	padding.Parent = status

	ui.kitStrip = Instance.new("Frame")
	ui.kitStrip.Size = UDim2.fromOffset(4, 16)
	ui.kitStrip.Position = UDim2.fromOffset(0, 1)
	ui.kitStrip.BorderSizePixel = 0
	ui.kitStrip.Parent = status
	corner(ui.kitStrip, 2)

	ui.kitTitle = label(status, {
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -10, 0, 18),
	})

	local healthBack
	healthBack, ui.healthFill = bar(status, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 22), COLORS.Health)
	ui.healthText = label(healthBack, {
		TextSize = 14,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	})

	local evasiveBack
	evasiveBack, ui.evasiveFill = bar(status, UDim2.fromOffset(0, 52), UDim2.new(0.5, -3, 0, 8), COLORS.Evasive)
	ui.evasiveStroke = Instance.new("UIStroke")
	ui.evasiveStroke.Color = COLORS.Evasive
	ui.evasiveStroke.Thickness = 2
	ui.evasiveStroke.Transparency = 1
	ui.evasiveStroke.Parent = evasiveBack
	label(status, {
		Text = "EVASIVE",
		TextSize = 10,
		TextColor3 = COLORS.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(0.5, 0, 0, 14),
	})

	local awakeningBack
	awakeningBack, ui.awakeningFill = bar(status, UDim2.new(0.5, 3, 0, 52), UDim2.new(0.5, -3, 0, 8), COLORS.Awakening)
	ui.awakeningStroke = Instance.new("UIStroke")
	ui.awakeningStroke.Color = COLORS.Awakening
	ui.awakeningStroke.Thickness = 2
	ui.awakeningStroke.Transparency = 1
	ui.awakeningStroke.Parent = awakeningBack
	ui.awakeningLabel = label(status, {
		Text = "AWAKENING",
		TextSize = 10,
		TextColor3 = COLORS.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.5, 3, 0, 62),
		Size = UDim2.new(0.5, -3, 0, 14),
	})

	-- Bottom move bar.
	local hotbar = Instance.new("Frame")
	hotbar.Name = "Moves"
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Position = UDim2.new(0.5, 0, 1, -18)
	hotbar.Size = UDim2.fromOffset(6 * SLOT_SIZE + 5 * 8 + 16, SLOT_SIZE)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = hotbar

	ui.dash = slot(hotbar, "Q", 0)
	ui.dash.name.Text = "Dash"
	ui.dash.stroke.Color = Color3.fromRGB(200, 200, 210)

	ui.skills = {}
	for i = 1, CombatState.SkillSlots do
		ui.skills[i] = slot(hotbar, tostring(i), i + 1)
	end
	ui.awaken = slot(hotbar, "G", 10)

	-- Little gap between dash and the skills.
	local spacer = Instance.new("Frame")
	spacer.Size = UDim2.fromOffset(8, 1)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder = 1
	spacer.Parent = hotbar

	ui.comboLabel = label(gui, {
		Name = "Combo",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.45, 0),
		Size = UDim2.fromOffset(260, 70),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Rotation = -6,
	})
	ui.comboScale = Instance.new("UIScale")
	ui.comboScale.Parent = ui.comboLabel

	ui.toast = label(gui, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(600, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
end

-- Kit-dependent labels (title, colors, skill names) only change on switch.
local function refreshKit(character: Model?)
	local kitId = if character then character:GetAttribute("Kit") :: string? else nil
	local awakened = character ~= nil and CombatState.IsAwakened(character)
	if kitId == shownKit and awakened == shownAwakened then
		return
	end
	shownKit = kitId
	shownAwakened = awakened
	local kit = Kits.Get(kitId)
	local skills = if character then Kits.SkillsOf(character) else {}

	ui.kitTitle.Text = if kit then string.upper(kit.title) else ""
	ui.kitStrip.BackgroundColor3 = if kit then kit.color else COLORS.Locked
	ui.kitStrip.Visible = kit ~= nil

	for i, s in ui.skills do
		local skill = skills[i]
		s.name.Text = if skill then skill.name else ""
		s.stroke.Color = if skill and kit then kit.color else COLORS.Locked
		s.frame.BackgroundTransparency = if skill then 0.2 else 0.6
	end
	local awakening = kit and kit.awakening
	ui.awaken.name.Text = if awakening then awakening.name else ""
	ui.awaken.stroke.Color = if awakening then COLORS.Awakening else COLORS.Locked
	ui.awakeningLabel.Text = if awakening then string.upper(awakening.name) else "AWAKENING"
end

local function onHitConfirm(data)
	if type(data) ~= "table" or not data.hitConfirm or data.attacker ~= localPlayer.Character then
		return
	end
	local t = os.clock()
	comboCount = if t - lastComboHit < COMBO_TIMEOUT then comboCount + 1 else 1
	lastComboHit = t

	ui.comboLabel.Text = comboCount .. " HIT" .. (if comboCount == 1 then "" else "S")
	ui.comboLabel.TextTransparency = 0
	ui.comboLabel.TextStrokeTransparency = 0
	ui.comboScale.Scale = 1.5
	TweenService:Create(ui.comboScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function update(dt: number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	refreshKit(character)

	if character and humanoid then
		local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		shownHealth += (ratio - shownHealth) * math.min(dt * 12, 1)
		ui.healthFill.Size = UDim2.fromScale(shownHealth, 1)
		ui.healthFill.BackgroundColor3 = COLORS.HealthLow:Lerp(COLORS.Health, ratio)
		ui.healthText.Text = string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)

		local pulse = 0.3 + 0.4 * math.sin(os.clock() * 8)

		local evasive = math.clamp((tonumber(character:GetAttribute("Evasive")) or 0) / Config.Evasive.Max, 0, 1)
		ui.evasiveFill.Size = UDim2.fromScale(evasive, 1)
		ui.evasiveStroke.Transparency = if evasive >= 1 then pulse else 1

		local awakening = math.clamp((tonumber(character:GetAttribute("Awakening")) or 0) / Config.Awakening.Max, 0, 1)
		local awakened = CombatState.IsAwakened(character)
		local kit = Kits.Of(character)
		local canAwaken = kit ~= nil and kit.awakening ~= nil
		ui.awakeningFill.Size = UDim2.fromScale(awakening, 1)
		ui.awakeningStroke.Transparency = if (awakening >= 1 and canAwaken) or awakened then pulse else 1

		for i, s in ui.skills do
			setSlotCooldown(s, CombatState.Cooldown(character, i))
		end

		-- G slot: dim until the meter is full, glowing while awakened.
		ui.awaken.overlay.Size = UDim2.fromScale(1, if canAwaken then 1 - awakening else 1)
		ui.awaken.timer.Text = ""
		ui.awaken.stroke.Transparency = if canAwaken and (awakening >= 1 or awakened) then pulse else 0
	end

	setSlotCooldown(ui.dash, math.max(dashReadyAt - os.clock(), 0), dashDuration)

	if comboCount > 0 and os.clock() - lastComboHit > COMBO_TIMEOUT then
		comboCount = 0
		TweenService:Create(ui.comboLabel, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
	end
end

function HUD.SetDashCooldown(duration: number)
	dashDuration = duration
	dashReadyAt = os.clock() + duration
end

-- Short message at the top of the screen.
function HUD.Toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	ui.toast.Text = text
	ui.toast.TextColor3 = color or COLORS.Text
	ui.toast.TextTransparency = 0
	ui.toast.TextStrokeTransparency = 0.3
	task.delay(2.2, function()
		if toastToken == token then
			TweenService:Create(ui.toast, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
		end
	end)
end

function HUD.Start()
	build()
	Remotes.VFX.OnClientEvent:Connect(function(_, data)
		onHitConfirm(data)
	end)
	Remotes.Notify.OnClientEvent:Connect(function(text, color)
		if type(text) == "string" then
			HUD.Toast(text, if typeof(color) == "Color3" then color else nil)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return HUD
