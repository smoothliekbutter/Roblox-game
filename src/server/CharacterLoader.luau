local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local CharacterLoader = {}

local descriptions: { [Player]: HumanoidDescription } = {}

local function getDescription(player: Player): HumanoidDescription
	local cached = descriptions[player]
	if cached then
		return cached
	end
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
	end)
	if not ok or not description then
		description = Instance.new("HumanoidDescription")
	end
	descriptions[player] = description
	return description
end

local function spawnCharacter(player: Player)
	if not player.Parent then
		return
	end
	player:LoadCharacterAsync()

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end

	local ok, err = pcall(function()
		humanoid:ApplyDescriptionAsync(getDescription(player))
	end)
	if not ok then
		warn("[CharacterLoader] Couldn't apply avatar for", player.Name, err)
	end
	character:SetAttribute("AvatarLoaded", true)

	humanoid.Died:Connect(function()
		task.delay(Players.RespawnTime, function()
			if player.Parent and player.Character == character then
				spawnCharacter(player)
			end
		end)
	end)
end

function CharacterLoader.Start()
	Players.CharacterAutoLoads = false

	if not StarterPlayer:FindFirstChild("StarterCharacter") then
		local rig = Players:CreateHumanoidModelFromDescriptionAsync(
			Instance.new("HumanoidDescription"),
			Enum.HumanoidRigType.R6
		)
		rig.Name = "StarterCharacter"
		rig.Parent = StarterPlayer
	end

	Players.PlayerAdded:Connect(spawnCharacter)
	Players.PlayerRemoving:Connect(function(player)
		descriptions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(spawnCharacter, player)
	end
end

return CharacterLoader
