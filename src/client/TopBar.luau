local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Kits = require(Shared.Kits)
local Remotes = require(Shared.Remotes)

local ShiftLock = require(script.Parent.ShiftLock)

local localPlayer = Players.LocalPlayer

local COLORS = {
	Pill = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(14, 14, 18),
	Card = Color3.fromRGB(28, 28, 34),
	Text = Color3.fromRGB(240, 240, 240),
	SubText = Color3.fromRGB(165, 165, 175),
	On = Color3.fromRGB(90, 200, 255),
}

local TopBar = {}

local panel: Frame
local cards: { [string]: { stroke: UIStroke, badge: TextLabel } } = {}
local open = false

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function pillButton(parent: Instance, text: string, order: number): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.AutomaticSize = Enum.AutomaticSize.X
	button.Size = UDim2.fromOffset(0, 44)
	button.BackgroundColor3 = COLORS.Pill
	button.BackgroundTransparency = 0.3
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = COLORS.Text
	button.Text = text
	button.LayoutOrder = order
	button.Parent = parent
	corner(button, UDim.new(1, 0))

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = button
	return button
end

local function selectedKit(): string
	local character = localPlayer.Character
	local id = (character and character:GetAttribute("Kit")) or localPlayer:GetAttribute("Kit")
	return if type(id) == "string" then id else Kits.Default
end

local function refreshCards()
	local current = selectedKit()
	for id, card in cards do
		local kit = Kits.List[id]
		local isCurrent = id == current
		card.stroke.Color = if isCurrent then kit.color else Color3.fromRGB(50, 50, 58)
		card.stroke.Thickness = if isCurrent then 3 else 1
		card.badge.Text = if not kit.playable then "COMING SOON" elseif isCurrent then "SELECTED" else ""
	end
end

local function setOpen(value: boolean)
	open = value
	ShiftLock.SetSuspended(open)
	if open then
		refreshCards()
		panel.Visible = true
		panel.Position = UDim2.fromOffset(16, -10)
		TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(16, 8) })
			:Play()
	else
		panel.Visible = false
	end
end

local function buildCard(parent: Instance, kit: Kits.KitInfo, order: number)
	local card = Instance.new("TextButton")
	card.Name = kit.id
	card.AutoButtonColor = kit.playable
	card.Text = ""
	card.BackgroundColor3 = COLORS.Card
	card.LayoutOrder = order
	card.Parent = parent
	corner(card, UDim.new(0, 8))

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, 0, 0, 6)
	strip.BackgroundColor3 = kit.color
	strip.BackgroundTransparency = if kit.playable then 0 else 0.6
	strip.BorderSizePixel = 0
	strip.Parent = card
	corner(strip, UDim.new(0, 3))

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 14)
	title.Size = UDim2.new(1, -20, 0, 20)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = if kit.playable then COLORS.Text else COLORS.SubText
	title.Text = string.upper(kit.title)
	title.Parent = card

	local description = Instance.new("TextLabel")
	description.BackgroundTransparency = 1
	description.Position = UDim2.fromOffset(10, 36)
	description.Size = UDim2.new(1, -20, 0, 44)
	description.Font = Enum.Font.Gotham
	description.TextSize = 12
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.TextColor3 = COLORS.SubText
	description.Text = kit.description
	description.Parent = card

	local badge = Instance.new("TextLabel")
	badge.BackgroundTransparency = 1
	badge.AnchorPoint = Vector2.new(0, 1)
	badge.Position = UDim2.new(0, 10, 1, -8)
	badge.Size = UDim2.new(1, -20, 0, 14)
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 11
	badge.TextXAlignment = Enum.TextXAlignment.Left
	badge.TextColor3 = kit.color
	badge.Parent = card

	cards[kit.id] = { stroke = stroke, badge = badge }

	card.Activated:Connect(function()
		if not kit.playable then
			return
		end
		Remotes.Action:FireServer("SelectKit", kit.id)
		setOpen(false)
	end)
end

local function buildPanel(gui: ScreenGui)
	panel = Instance.new("Frame")
	panel.Name = "CharacterPicker"
	panel.Size = UDim2.fromOffset(3 * 170 + 2 * 10 + 28, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	corner(panel, UDim.new(0, 12))

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.Parent = panel

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Size = UDim2.new(1, 0, 0, 24)
	heading.Font = Enum.Font.GothamBlack
	heading.TextSize = 18
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = COLORS.Text
	heading.Text = "CHOOSE YOUR GRIMOIRE"
	heading.Parent = panel

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 34)
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = panel

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(170, 112)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for order, id in Kits.Order do
		local kit = Kits.List[id]
		if kit then
			buildCard(grid, kit, order)
		end
	end
end

function TopBar.Start()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local bar = Instance.new("ScreenGui")
	bar.Name = "TopBar"
	bar.ResetOnSpawn = false
	bar.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	bar.DisplayOrder = 10
	bar.Parent = playerGui

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local charactersButton = pillButton(row, "CHARACTERS", 1)
	local shiftLockButton = pillButton(row, "SHIFT LOCK: OFF", 2)
	local infiniteButton = if Config.PlayTest.InfiniteAwakening
		then pillButton(row, "INFINITE AWAKENING: OFF", 3)
		else nil

	local rowPadding = Instance.new("UIPadding")
	rowPadding.PaddingLeft = UDim.new(0, 10)
	rowPadding.Parent = row
	local function align()
		local barHeight = row.AbsoluteSize.Y
		local buttonHeight = math.clamp(barHeight - 14, 28, 44)
		rowPadding.PaddingTop = UDim.new(0, math.max(barHeight - buttonHeight - 2, 0))
		charactersButton.Size = UDim2.fromOffset(0, buttonHeight)
		shiftLockButton.Size = UDim2.fromOffset(0, buttonHeight)
		if infiniteButton then
			infiniteButton.Size = UDim2.fromOffset(0, buttonHeight)
		end
	end
	row:GetPropertyChangedSignal("AbsoluteSize"):Connect(align)
	align()

	local menus = Instance.new("ScreenGui")
	menus.Name = "Menus"
	menus.ResetOnSpawn = false
	menus.DisplayOrder = 10
	menus.Parent = playerGui
	buildPanel(menus)

	charactersButton.Activated:Connect(function()
		setOpen(not open)
	end)

	shiftLockButton.Activated:Connect(ShiftLock.Toggle)

	if infiniteButton then
		local function show()
			local on = localPlayer:GetAttribute("InfiniteAwakening") == true
			infiniteButton.Text = if on then "INFINITE AWAKENING: ON" else "INFINITE AWAKENING: OFF"
			infiniteButton.TextColor3 = if on then COLORS.On else COLORS.Text
		end
		infiniteButton.Activated:Connect(function()
			Remotes.Action:FireServer("InfiniteAwakening", localPlayer:GetAttribute("InfiniteAwakening") ~= true)
		end)
		localPlayer:GetAttributeChangedSignal("InfiniteAwakening"):Connect(show)
		show()
	end
	ShiftLock.OnChanged(function(on)
		shiftLockButton.Text = if on then "SHIFT LOCK: ON" else "SHIFT LOCK: OFF"
		shiftLockButton.TextColor3 = if on then COLORS.On else COLORS.Text
	end)

	local function watch(character: Model)
		character:GetAttributeChangedSignal("Kit"):Connect(refreshCards)
		refreshCards()
	end
	localPlayer.CharacterAdded:Connect(watch)
	if localPlayer.Character then
		watch(localPlayer.Character)
	end
end

return TopBar
