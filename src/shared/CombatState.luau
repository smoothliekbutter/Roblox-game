--[[
	CombatState
	Combat state is stored as attributes on the character model. Attributes
	replicate, so the server writes them and clients read them to gate input
	and drive the HUD. Timestamps use server time so both sides agree.
]]

local CombatState = {}

local DEFAULTS = {
	StunUntil = 0,
	BusyUntil = 0,
	IFrameUntil = 0,
	Blocking = false,
	BlockStart = 0,
	Ragdolled = false,
	Evasive = 0,
}

local function now(): number
	return workspace:GetServerTimeNow()
end
CombatState.Now = now

function CombatState.Setup(character: Model)
	for name, value in DEFAULTS do
		character:SetAttribute(name, value)
	end
end

function CombatState.IsAlive(character: Model?): boolean
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

function CombatState.IsStunned(character: Model): boolean
	return (character:GetAttribute("StunUntil") or 0) > now()
end

function CombatState.IsBusy(character: Model): boolean
	return (character:GetAttribute("BusyUntil") or 0) > now()
end

function CombatState.IsRagdolled(character: Model): boolean
	return character:GetAttribute("Ragdolled") == true
end

function CombatState.IsBlocking(character: Model): boolean
	return character:GetAttribute("Blocking") == true
end

function CombatState.HasIFrames(character: Model): boolean
	return (character:GetAttribute("IFrameUntil") or 0) > now()
end

-- Alive, not stunned and not ragdolled. Busy (mid-swing) is checked separately.
function CombatState.CanAct(character: Model): boolean
	return CombatState.IsAlive(character)
		and not CombatState.IsStunned(character)
		and not CombatState.IsRagdolled(character)
end

-- Setters below are only meaningful on the server.

function CombatState.Stun(character: Model, duration: number)
	local untilTime = math.max(character:GetAttribute("StunUntil") or 0, now() + duration)
	character:SetAttribute("StunUntil", untilTime)
end

function CombatState.ClearStun(character: Model)
	character:SetAttribute("StunUntil", 0)
end

function CombatState.SetBusy(character: Model, duration: number)
	character:SetAttribute("BusyUntil", now() + duration)
end

function CombatState.GiveIFrames(character: Model, duration: number)
	character:SetAttribute("IFrameUntil", now() + duration)
end

function CombatState.SetBlocking(character: Model, blocking: boolean)
	character:SetAttribute("Blocking", blocking)
	if blocking then
		character:SetAttribute("BlockStart", now())
	end
end

return CombatState
