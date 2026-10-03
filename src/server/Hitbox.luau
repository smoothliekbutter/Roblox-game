--[[
	Hitbox
	Spatial queries that return the characters (anything with a Humanoid)
	inside a region. Each character is returned at most once.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CombatState = require(Shared.CombatState)

local Hitbox = {}

local function characterFromPart(part: BasePart): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function visualize(cframe: CFrame, size: Vector3)
	local box = Instance.new("Part")
	box.Name = "HitboxDebug"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Material = Enum.Material.ForceField
	box.Color = Color3.fromRGB(255, 40, 40)
	box.CFrame = cframe
	box.Size = size
	box.Parent = workspace
	Debris:AddItem(box, 0.25)
end

function Hitbox.Box(attacker: Model, cframe: CFrame, size: Vector3): { Model }
	if Config.Debug.ShowHitboxes then
		visualize(cframe, size)
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker }

	local found: { Model } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(cframe, size, params) do
		local character = characterFromPart(part)
		if character and not seen[character] and CombatState.IsAlive(character) then
			seen[character] = true
			table.insert(found, character)
		end
	end
	return found
end

function Hitbox.Sphere(attacker: Model, position: Vector3, radius: number): { Model }
	if Config.Debug.ShowHitboxes then
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Material = Enum.Material.ForceField
		ball.Color = Color3.fromRGB(255, 40, 40)
		ball.Size = Vector3.one * radius * 2
		ball.Position = position
		ball.Parent = workspace
		Debris:AddItem(ball, 0.25)
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker }

	local found: { Model } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInRadius(position, radius, params) do
		local character = characterFromPart(part)
		if character and not seen[character] and CombatState.IsAlive(character) then
			seen[character] = true
			table.insert(found, character)
		end
	end
	return found
end

return Hitbox
