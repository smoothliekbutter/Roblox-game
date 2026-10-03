--[[
	Server entry point.
]]

local Players = game:GetService("Players")

local CharacterLoader = require(script.CharacterLoader)
local CombatService = require(script.CombatService)
local Dummies = require(script.Dummies)

CombatService.Start()

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(CombatService.Register)
	if player.Character then
		task.spawn(CombatService.Register, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- After combat hooks are in place, so the first spawn gets registered.
CharacterLoader.Start()

Dummies.Start()
