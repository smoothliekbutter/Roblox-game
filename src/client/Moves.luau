--[[
	Moves
	Plays move animations + their VFX on characters, routed to each
	character's kit (Client/Kits/<KitId>). Characters without a kit (the
	dummies) use the default fist M1s.

	Your own M1s play instantly when you click (predicted by Input), so they
	feel responsive at any ping. Everyone else's play when the server's
	"Swing" event arrives. Skills are driven by the server's "Skill" events.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Kits = require(ReplicatedStorage:WaitForChild("Shared").Kits)

local M1Animations = require(script.Parent.M1Animations)
local PoseAnimator = require(script.Parent.PoseAnimator)
local VFX = require(script.Parent.VFX)

local localPlayer = Players.LocalPlayer

local TRAIL_TIME = 0.14

local clientKits: { [string]: any } = {}
for _, module in script.Parent:WaitForChild("Kits"):GetChildren() do
	if module:IsA("ModuleScript") then
		clientKits[module.Name] = require(module) :: any
	end
end

local Moves = {}

local function kitOf(character: Model): any
	local id = character:GetAttribute("Kit")
	return if type(id) == "string" then clientKits[id] else nil
end

-- Default M1s: punches and a kick.
local function playFistM1(character: Model, index: number, variant: string)
	local name = M1Animations.NameFor(index, variant)
	local animation = M1Animations.Clips[name]
	if not animation then
		return
	end
	local heavy = variant ~= "Normal"
	local strikers = M1Animations.Strikers[name] or {}

	PoseAnimator.Play(character, animation, function(event)
		if event == "Strike" then
			for _, limbName in strikers do
				VFX.LimbTrail(character, limbName, if heavy then TRAIL_TIME * 1.5 else TRAIL_TIME)
			end
			VFX.AirPop(character, heavy)
		end
	end)
end

function Moves.PlayM1(character: Model, index: number, variant: string)
	local kit = kitOf(character)
	if kit and kit.PlayM1 then
		kit.PlayM1(character, index, variant)
	else
		playFistM1(character, index, variant)
	end
end

-- Black Form style looks follow the "Awakened" attribute on every player.
local function watchCharacter(character: Model)
	local function update()
		local kit = kitOf(character)
		if kit and kit.SetAwakened then
			kit.SetAwakened(character, character:GetAttribute("Awakened") == true)
		end
	end
	character:GetAttributeChangedSignal("Awakened"):Connect(update)
	update()
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

function Moves.Start()
	PoseAnimator.Start()

	Remotes.VFX.OnClientEvent:Connect(function(name, data)
		if type(data) ~= "table" then
			return
		end
		local character = data.character
		if typeof(character) ~= "Instance" or not character:IsA("Model") then
			return
		end

		if name == "Swing" then
			-- Our own swing already played the moment we clicked.
			if character ~= localPlayer.Character then
				Moves.PlayM1(character, data.index or 1, data.variant or "Normal")
			end
		elseif name == "Skill" then
			local kit = if type(data.kit) == "string" then clientKits[data.kit] else nil
			if kit and kit.OnSkill then
				kit.OnSkill(data)
			end
		end
	end)

	-- Character switch: a flash in the new character's color.
	VFX.Register("KitSwitch", function(data)
		local character = data.character
		local kit = Kits.Get(data.kit)
		local root = VFX.Util.getRoot(character)
		if not root or not kit then
			return
		end
		VFX.Util.afterimage(character, kit.color, 0.5)
		VFX.Util.flash(root.Position, kit.color, 8, 0.3)
		VFX.Util.ringBurst(CFrame.new(root.Position - Vector3.new(0, 2.8, 0)), kit.color, 1, 8, 0.35, 0.25)
	end)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return Moves
