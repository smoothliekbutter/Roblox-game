--[[
	Client entry point.
]]

local StarterGui = game:GetService("StarterGui")

local CameraShake = require(script.CameraShake)
local HUD = require(script.HUD)
local Input = require(script.Input)
local Moves = require(script.Moves)
local VFX = require(script.VFX)

-- Our HUD replaces the default health bar.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

CameraShake.Start()
VFX.Start()
Moves.Start()
HUD.Start()
Input.Start()
