--[[
	Remotes
	The server creates every RemoteEvent; clients wait for them.

	Action       client -> server   ("M1", {jump, airborne}) | ("Block", bool) | ("Dash", dir) | ("Evasive") | ("AirJump")
	                                | ("Skill", slot, {airborne}) | ("Special", {airborne}) | ("Awaken")
	                                | ("SelectKit", kitId)
	VFX          server -> clients  (effectName, data)
	CameraShake  server -> client   (intensity 0-1)
	Impulse      server -> client   (velocity, duration, {steer?}) applied to your own character
	Notify       server -> client   (text, color?) toast message
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "Action", "VFX", "CameraShake", "Impulse", "Notify" }

local Remotes: { [string]: RemoteEvent } = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		Remotes[name] = remote
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
end

return Remotes
