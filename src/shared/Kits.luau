--[[
	Kits
	The character roster. Everything both sides need to know about a
	character lives here: name, colors, M1 tuning, skills (name, cooldown,
	attack type) and awakening. The server logic for each kit is in
	ServerScriptService.Server.Kits, the animations and VFX in
	StarterPlayerScripts.Client.Kits.

	Attack types decide which counters work against what:
	  Melee | Bolt | Explosion | Swarm | Zone
]]

export type SkillInfo = {
	name: string,
	cooldown: number,
	type: string,
}

export type KitInfo = {
	id: string,
	title: string, -- shown in the character picker
	description: string,
	color: Color3,
	playable: boolean,
	-- Overrides for Config.M1 (hitbox, damage, ...). Missing keys use Config.M1.
	m1: { [string]: any },
	skills: { SkillInfo },
	-- Awakening swaps the move set (like Vessel -> Sukuna, Hero Hunter -> Rampage).
	awakenedSkills: { SkillInfo }?,
	awakening: {
		name: string,
		duration: number,
		damageMultiplier: number,
		cooldownMultiplier: number,
		speedBonus: number,
	}?,
}

local Kits = {}

Kits.Default = "AntiMagic"

-- Picker order.
Kits.Order = { "AntiMagic", "Wind", "Water", "Dark", "Flame", "Lightning" }

local function comingSoon(id: string, title: string, description: string, color: Color3): KitInfo
	return {
		id = id,
		title = title,
		description = description,
		color = color,
		playable = false,
		m1 = {},
		skills = {},
	}
end

Kits.List = {
	AntiMagic = {
		id = "AntiMagic",
		title = "Anti-Magic Knight",
		description = "No magic at all. A demon-slaying greatsword that cuts through every spell.",
		color = Color3.fromRGB(205, 35, 45),
		playable = true,
		m1 = {
			-- The greatsword reaches further than fists.
			HitboxSize = Vector3.new(7, 6, 7),
			HitboxOffset = 3.75,
			Damage = 4,
			FinisherDamage = 6,
			-- Hits land as the blade sweeps through the middle of the swing.
			WindUp = 0.11,
			FinisherWindUp = 0.18,
		},
		-- Close-range rushdown, built like Vessel (JJS) / Hero Hunter (TSB):
		-- rush combo, grab, timing-crit heavy, counter.
		skills = {
			{ name = "Bull Thrust", cooldown = 8, type = "Melee" },
			{ name = "Black Meteorite", cooldown = 12, type = "Melee" },
			{ name = "Black Divider", cooldown = 10, type = "Melee" },
			{ name = "Anti-Magic Deflect", cooldown = 15, type = "Counter" },
		},
		awakenedSkills = {
			{ name = "Black Hurricane", cooldown = 9, type = "Melee" },
			{ name = "Black Slash", cooldown = 7, type = "Bolt" },
			{ name = "Grand Divider", cooldown = 12, type = "Explosion" },
			{ name = "Demon-Destroyer", cooldown = 25, type = "Melee" },
		},
		awakening = {
			name = "Black Form",
			duration = 40,
			damageMultiplier = 1.25,
			cooldownMultiplier = 0.85,
			speedBonus = 6,
		},
	} :: KitInfo,

	Wind = comingSoon("Wind", "Wind Prodigy", "Spirit-blessed wind magic.", Color3.fromRGB(90, 220, 150)),
	Water = comingSoon("Water", "Water Princess", "Royal water magic.", Color3.fromRGB(80, 160, 255)),
	Dark = comingSoon("Dark", "Dark Captain", "Dark magic that slices space.", Color3.fromRGB(120, 70, 190)),
	Flame = comingSoon("Flame", "Flame Lioness", "Overwhelming flame magic.", Color3.fromRGB(255, 120, 40)),
	Lightning = comingSoon("Lightning", "Battle Maniac", "Lightning-fast magic.", Color3.fromRGB(255, 225, 70)),
} :: { [string]: KitInfo }

function Kits.Get(id: string?): KitInfo?
	if id == nil then
		return nil
	end
	return Kits.List[id]
end

-- The move list a character has right now (awakened moves while awakened).
function Kits.SkillsOf(character: Model): { SkillInfo }
	local kit = Kits.Of(character)
	if not kit then
		return {}
	end
	if character:GetAttribute("Awakened") == true and kit.awakenedSkills then
		return kit.awakenedSkills
	end
	return kit.skills
end

-- The kit a character is using (nil for kit-less NPCs like the dummies).
function Kits.Of(character: Model): KitInfo?
	return Kits.Get(character:GetAttribute("Kit") :: string?)
end

return Kits
