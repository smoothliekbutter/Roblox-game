--[[
	Moves
	Plays move animations + their VFX on characters.

	Your own swings play instantly when you click (predicted by Input), so
	they feel responsive at any ping. Everyone else's play when the server's
	"Swing" event arrives.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local M1Animations = require(script.Parent.M1Animations)
local PoseAnimator = require(script.Parent.PoseAnimator)
local VFX = require(script.Parent.VFX)

local localPlayer = Players.LocalPlayer

local TRAIL_TIME = 0.14

local Moves = {}

function Moves.PlayM1(character: Model, index: number, variant: string)
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

function Moves.Start()
	PoseAnimator.Start()

	Remotes.VFX.OnClientEvent:Connect(function(name, data)
		if name ~= "Swing" or type(data) ~= "table" then
			return
		end
		local character = data.character
		-- Our own swing already played the moment we clicked.
		if typeof(character) ~= "Instance" or character == localPlayer.Character then
			return
		end
		Moves.PlayM1(character :: Model, data.index or 1, data.variant or "Normal")
	end)
end

return Moves
