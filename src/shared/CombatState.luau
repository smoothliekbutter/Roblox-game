--[[
	CombatState
	Combat state is stored as attributes on the character model. Attributes
	replicate, so the server writes them and clients read them to gate input
	and drive the HUD. Timestamps use server time so both sides agree.
]]

local CombatState = {}

local DEFAULTS = {
	StunUntil = 0,
	BusyUntil = 0, -- swinging: slowed, can't jump
	CastUntil = 0, -- using a skill: locked out of everything else
	IFrameUntil = 0,
	Blocking = false,
	BlockStart = 0,
	Ragdolled = false,
	Evasive = 0,
	Awakening = 0, -- meter, 0 to Config.Awakening.Max
	Awakened = false,
	Rooted = false, -- can't move (e.g. during a spawn entrance)
}

-- Skill slots 1-4. "CD<n>" is the server time the skill is ready again,
-- "CDLen<n>" how long that cooldown was (for drawing the HUD sweep).
CombatState.SkillSlots = 4
-- The R special uses the same attributes as slot 5. It isn't part of the
-- move set, so awakening doesn't reset it.
CombatState.SpecialSlot = 5

local function now(): number
	return workspace:GetServerTimeNow()
end
CombatState.Now = now

function CombatState.Setup(character: Model)
	for name, value in DEFAULTS do
		character:SetAttribute(name, value)
	end
	CombatState.ResetCooldowns(character)
	CombatState.ResetSpecial(character)
end

function CombatState.ResetCooldowns(character: Model)
	for slot = 1, CombatState.SkillSlots do
		character:SetAttribute("CD" .. slot, 0)
		character:SetAttribute("CDLen" .. slot, 1)
	end
end

function CombatState.ResetSpecial(character: Model)
	character:SetAttribute("CD" .. CombatState.SpecialSlot, 0)
	character:SetAttribute("CDLen" .. CombatState.SpecialSlot, 1)
end

function CombatState.IsAlive(character: Model?): boolean
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

function CombatState.IsStunned(character: Model): boolean
	return (tonumber(character:GetAttribute("StunUntil")) or 0) > now()
end

function CombatState.IsBusy(character: Model): boolean
	return (tonumber(character:GetAttribute("BusyUntil")) or 0) > now()
end

function CombatState.IsCasting(character: Model): boolean
	return (tonumber(character:GetAttribute("CastUntil")) or 0) > now()
end

function CombatState.IsAwakened(character: Model): boolean
	return character:GetAttribute("Awakened") == true
end

-- Seconds left on a skill's cooldown, and the cooldown's full length.
function CombatState.Cooldown(character: Model, slot: number): (number, number)
	local readyAt = tonumber(character:GetAttribute("CD" .. slot)) or 0
	local length = tonumber(character:GetAttribute("CDLen" .. slot)) or 1
	return math.max(readyAt - now(), 0), length
end

function CombatState.IsRagdolled(character: Model): boolean
	return character:GetAttribute("Ragdolled") == true
end

function CombatState.IsBlocking(character: Model): boolean
	return character:GetAttribute("Blocking") == true
end

function CombatState.HasIFrames(character: Model): boolean
	return (tonumber(character:GetAttribute("IFrameUntil")) or 0) > now()
end

-- Alive, not stunned and not ragdolled. Busy (mid-swing) and casting are
-- checked separately.
function CombatState.CanAct(character: Model): boolean
	return CombatState.IsAlive(character)
		and not CombatState.IsStunned(character)
		and not CombatState.IsRagdolled(character)
end

-- Setters below are only meaningful on the server.

function CombatState.Stun(character: Model, duration: number)
	local untilTime = math.max(tonumber(character:GetAttribute("StunUntil")) or 0, now() + duration)
	character:SetAttribute("StunUntil", untilTime)
end

function CombatState.ClearStun(character: Model)
	character:SetAttribute("StunUntil", 0)
end

function CombatState.SetCasting(character: Model, duration: number)
	character:SetAttribute("CastUntil", now() + duration)
end

function CombatState.ClearCasting(character: Model)
	character:SetAttribute("CastUntil", 0)
end

function CombatState.StartCooldown(character: Model, slot: number, duration: number)
	character:SetAttribute("CD" .. slot, now() + duration)
	character:SetAttribute("CDLen" .. slot, math.max(duration, 0.01))
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
