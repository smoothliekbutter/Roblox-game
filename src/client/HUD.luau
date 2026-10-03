--[[
	HUD
	Top right (in the top bar): small health + Evasive bars.
	Bottom:    awakening bar over the move icons (skills 1-4, then the R
	           special) with cooldowns.
	Right:     combo counter.
	Top:       toast messages from the server.
	Built in code so it can be restyled without touching Studio.
]]

local GuiService = game:GetService("GuiService")
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
	Panel = Color3.fromRGB(0, 0, 0),
	Back = Color3.fromRGB(40, 40, 46),
	Health = Color3.fromRGB(90, 220, 110),
	HealthLow = Color3.fromRGB(230, 60, 60),
	Evasive = Color3.fromRGB(120, 235, 255),
	Awakening = Color3.fromRGB(220, 40, 50),
	Text = Color3.fromRGB(240, 240, 240),
	SubText = Color3.fromRGB(170, 170, 180),
	Locked = Color3.fromRGB(60, 60, 68),
}

local COMBO_TIMEOUT = 1.6
local SLOT_SIZE = 54
local SLOT_GAP = 6
local SPECIAL_GAP = 14 -- extra room before the R slot
local STATUS_WIDTH = 190

type Slot = {
	frame: Frame,
	stroke: UIStroke,
	name: TextLabel,
	overlay: Frame,
	timer: TextLabel,
}

local HUD = {}

local ui: {
	healthFill: Frame,
	healthText: TextLabel,
	evasiveFill: Frame,
	evasiveStroke: UIStroke,
	awakening: Frame,
	awakeningFill: Frame,
	awakeningStroke: UIStroke,
	awakeningLabel: TextLabel,
	skills: { Slot },
	special: Slot,
	comboLabel: TextLabel,
	comboScale: UIScale,
	toast: TextLabel,
} =
	{} :: any

local comboCount = 0
local lastComboHit = 0
local shownHealth = 1
local shownKit: string? = "?"
local shownAwakened = false
local toastToken = 0

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
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
	corner(back, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner(fill, UDim.new(1, 0))

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	gradient.Rotation = 90
	gradient.Parent = fill

	return back, fill
end

local function slot(parent: Instance, key: string, order: number): Slot
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	frame.BackgroundColor3 = COLORS.Panel
	frame.BackgroundTransparency = 0.35
	frame.LayoutOrder = order
	frame.ClipsDescendants = true
	frame.Parent = parent
	corner(frame, UDim.new(0, 7))

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Locked
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	label(frame, {
		Text = key,
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(5, 3),
		Size = UDim2.fromOffset(14, 12),
		ZIndex = 4,
	})

	local name = label(frame, {
		Text = "",
		TextWrapped = true,
		TextSize = 10,
		Position = UDim2.new(0, 3, 0, 14),
		Size = UDim2.new(1, -6, 1, -16),
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
		TextSize = 16,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		TextStrokeTransparency = 0.2,
	})

	return { frame = frame, stroke = stroke, name = name, overlay = overlay, timer = timer }
end

local function setSlotCooldown(s: Slot, remaining: number, length: number)
	s.overlay.Size = UDim2.fromScale(1, math.clamp(remaining / math.max(length, 0.01), 0, 1))
	s.timer.Text = if remaining > 0 then string.format(if remaining < 10 then "%.1f" else "%d", remaining) else ""
	s.name.TextTransparency = if remaining > 0 then 0.6 else 0
end

local function buildStatus(playerGui: Instance)
	-- Lives in the top right corner of the screen, at the same height as
	-- Roblox's top bar buttons.
	local gui = Instance.new("ScreenGui")
	gui.Name = "Status"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Parent = playerGui

	local area = Instance.new("Frame")
	area.BackgroundTransparency = 1
	area.Size = UDim2.fromScale(1, 1)
	area.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Bars"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.3
	panel.Parent = area
	corner(panel, UDim.new(0, 10))

	local healthBack
	healthBack, ui.healthFill = bar(panel, UDim2.new(0, 8, 0.5, -10), UDim2.new(1, -16, 0, 13), COLORS.Health)
	ui.healthText = label(healthBack, {
		TextSize = 10,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		TextStrokeTransparency = 0.4,
	})

	local evasiveBack
	evasiveBack, ui.evasiveFill = bar(panel, UDim2.new(0, 8, 0.5, 6), UDim2.new(1, -16, 0, 4), COLORS.Evasive)
	ui.evasiveStroke = Instance.new("UIStroke")
	ui.evasiveStroke.Color = COLORS.Evasive
	ui.evasiveStroke.Thickness = 1.5
	ui.evasiveStroke.Transparency = 1
	ui.evasiveStroke.Parent = evasiveBack

	-- Same vertical placement as the top bar buttons (see TopBar).
	local function align()
		local barHeight = GuiService.TopbarInset.Height
		if barHeight <= 0 then
			barHeight = 58
		end
		local height = math.clamp(barHeight - 14, 28, 44)
		panel.Size = UDim2.fromOffset(STATUS_WIDTH, height)
		panel.Position = UDim2.new(1, -16, 0, math.max(barHeight - height - 2, 0))
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(align)
	align()
end

local function buildMoves(gui: ScreenGui)
	-- Skills 1-4, a little gap, then the R special.
	local width = 5 * SLOT_SIZE + 4 * SLOT_GAP + SPECIAL_GAP

	local holder = Instance.new("Frame")
	holder.Name = "Moves"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -14)
	holder.Size = UDim2.fromOffset(width, SLOT_SIZE + 24)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	-- Awakening bar over the moves, with the key and the form's name.
	ui.awakening = Instance.new("Frame")
	ui.awakening.BackgroundTransparency = 1
	ui.awakening.Size = UDim2.new(1, 0, 0, 18)
	ui.awakening.Parent = holder

	ui.awakeningLabel = label(ui.awakening, {
		Text = "",
		TextSize = 10,
		TextColor3 = COLORS.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 10),
	})
	local awakeningBack
	awakeningBack, ui.awakeningFill =
		bar(ui.awakening, UDim2.fromOffset(0, 12), UDim2.new(1, 0, 0, 5), COLORS.Awakening)
	ui.awakeningStroke = Instance.new("UIStroke")
	ui.awakeningStroke.Color = COLORS.Awakening
	ui.awakeningStroke.Thickness = 1.5
	ui.awakeningStroke.Transparency = 1
	ui.awakeningStroke.Parent = awakeningBack

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.fromScale(0, 1)
	row.Size = UDim2.new(1, 0, 0, SLOT_SIZE)
	row.Parent = holder

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, SLOT_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	ui.skills = {}
	for i = 1, CombatState.SkillSlots do
		ui.skills[i] = slot(row, tostring(i), i)
	end
	local spacer = Instance.new("Frame")
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.fromOffset(SPECIAL_GAP - SLOT_GAP, SLOT_SIZE)
	spacer.LayoutOrder = CombatState.SkillSlots + 1
	spacer.Parent = row
	ui.special = slot(row, "R", CombatState.SkillSlots + 2)
end

local function build()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	buildStatus(playerGui)
	buildMoves(gui)

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
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(600, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
end

-- Kit-dependent labels (skill names, colors) only change on switch/awaken.
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

	for i, s in ui.skills do
		local skill = skills[i]
		s.name.Text = if skill then skill.name else ""
		s.stroke.Color = if skill and kit then kit.color else COLORS.Locked
		s.frame.BackgroundTransparency = if skill then 0.35 else 0.7
	end
	local special = kit and kit.special
	ui.special.name.Text = if special then special.name else ""
	ui.special.stroke.Color = if special and kit then kit.color else COLORS.Locked
	ui.special.frame.BackgroundTransparency = if special then 0.35 else 0.7
	local awakening = kit and kit.awakening
	ui.awakening.Visible = awakening ~= nil
	ui.awakeningLabel.Text = if awakening then "[G]  " .. string.upper(awakening.name) else ""
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
		ui.healthText.Text = tostring(math.ceil(humanoid.Health))

		local pulse = 0.3 + 0.4 * math.sin(os.clock() * 8)

		local evasive = math.clamp((tonumber(character:GetAttribute("Evasive")) or 0) / Config.Evasive.Max, 0, 1)
		ui.evasiveFill.Size = UDim2.fromScale(evasive, 1)
		ui.evasiveStroke.Transparency = if evasive >= 1 then pulse else 1

		local awakening = math.clamp((tonumber(character:GetAttribute("Awakening")) or 0) / Config.Awakening.Max, 0, 1)
		local awakened = CombatState.IsAwakened(character)
		ui.awakeningFill.Size = UDim2.fromScale(awakening, 1)
		ui.awakeningStroke.Transparency = if awakening >= 1 or awakened then pulse else 1
		ui.awakeningLabel.TextColor3 = if awakening >= 1 or awakened then COLORS.Awakening else COLORS.SubText

		for i, s in ui.skills do
			setSlotCooldown(s, CombatState.Cooldown(character, i))
		end
		setSlotCooldown(ui.special, CombatState.Cooldown(character, CombatState.SpecialSlot))
	end

	if comboCount > 0 and os.clock() - lastComboHit > COMBO_TIMEOUT then
		comboCount = 0
		TweenService:Create(ui.comboLabel, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
	end
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
