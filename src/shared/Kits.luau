export type SkillInfo = {
	name: string,
	cooldown: number,
	type: string,
	airHold: boolean?,
}

export type SwordInfo = {
	name: string,
	skills: { SkillInfo },
}

export type KitInfo = {
	id: string,
	title: string,
	description: string,
	color: Color3,
	playable: boolean,
	m1: { [string]: any },
	skills: { SkillInfo },
	special: SkillInfo?,
	awakenedSkills: { SkillInfo }?,
	awakenedSpecial: SkillInfo?,
	swords: { [string]: SwordInfo }?,
	awakening: {
		name: string,
		duration: number,
		damageMultiplier: number,
		cooldownMultiplier: number,
		speedBonus: number,
	}?,
	airJumps: number?,
	ascension: {
		name: string,
		duration: number,
		charge: number,
		chargeByKit: boolean?,
		damageMultiplier: number,
		cooldownMultiplier: number,
		speedBonus: number,
		skills: { SkillInfo },
	}?,
}

local Kits = {}

Kits.Default = "AntiMagic"

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
			HitboxSize = Vector3.new(7, 6, 7),
			HitboxOffset = 3.75,
			Damage = 3,
			FinisherDamage = 4.5,
			WindUp = 0.11,
			FinisherWindUp = 0.18,
		},
		skills = {
			{ name = "Bull Thrust", cooldown = 10, type = "Melee", airHold = true },
			{ name = "Black Meteorite", cooldown = 13, type = "Melee", airHold = true },
			{ name = "Black Divider", cooldown = 11, type = "Melee", airHold = true },
			{ name = "Anti-Magic Deflect", cooldown = 14, type = "Counter", airHold = true },
		},
		special = { name = "Anti-Magic Leap", cooldown = 10, type = "Melee", airHold = true },
		awakenedSkills = {
			{ name = "Black Hurricane", cooldown = 9, type = "Melee", airHold = true },
			{ name = "Slayer Recall", cooldown = 12, type = "Bolt", airHold = true },
			{ name = "Grand Divider", cooldown = 13, type = "Explosion", airHold = true },
			{ name = "Black Moon", cooldown = 25, type = "Melee" },
		},
		awakenedSpecial = { name = "Swap Sword", cooldown = 0, type = "Melee" },
		swords = {
			Slayer = {
				name = "Demon-Slayer Sword",
				skills = {
					{ name = "Black Hurricane", cooldown = 9, type = "Melee", airHold = true },
					{ name = "Slayer Recall", cooldown = 12, type = "Bolt", airHold = true },
				},
			},
			Destroyer = {
				name = "Demon-Destroyer Sword",
				skills = {
					{ name = "Causality Break", cooldown = 15, type = "Zone", airHold = true },
					{ name = "Black Comet", cooldown = 14, type = "Melee", airHold = true },
				},
			},
			Slasher = {
				name = "Demon-Slasher Katana",
				skills = {
					{ name = "Black Ascent", cooldown = 12, type = "Melee", airHold = true },
					{ name = "Zetten", cooldown = 16, type = "Counter", airHold = true },
				},
			},
		},
		awakening = {
			name = "Black Form",
			duration = 55,
			damageMultiplier = 1.25,
			cooldownMultiplier = 0.8,
			speedBonus = 6,
		},
	} :: KitInfo,

	Wind = {
		id = "Wind",
		title = "Prince of Wind",
		description = "Wind magic blessed by the spirit Sylph, and star magic. Fights from range, with tornadoes and blades of wind.",
		color = Color3.fromRGB(90, 220, 150),
		playable = true,
		m1 = {
			HitboxOffset = 3.5,
		},
		airJumps = 1,
		skills = {
			{ name = "Wind Blades Shower", cooldown = 11, type = "Swarm", airHold = true },
			{ name = "Swift White Hawk", cooldown = 8, type = "Bolt", airHold = true },
			{ name = "Heavenly Wind Ark", cooldown = 12, type = "Zone", airHold = true },
			{ name = "Gale White Bow", cooldown = 15, type = "Bolt", airHold = true },
		},
		special = { name = "Tornado Fang", cooldown = 10, type = "Zone", airHold = true },
		awakenedSkills = {
			{ name = "Spirit Storm", cooldown = 12, type = "Bolt", airHold = true },
			{ name = "Tempest Dive", cooldown = 16, type = "Melee", airHold = true },
			{ name = "Quartile Scutum", cooldown = 16, type = "Counter" },
			{ name = "Nova Vortex", cooldown = 14, type = "Zone", airHold = true },
		},
		awakening = {
			name = "Half-Crown",
			duration = 45,
			damageMultiplier = 1.15,
			cooldownMultiplier = 0.85,
			speedBonus = 4,
		},
		ascension = {
			name = "Full-Crown",
			duration = 30,
			charge = 2,
			chargeByKit = true,
			damageMultiplier = 1.3,
			cooldownMultiplier = 0.75,
			speedBonus = 8,
			skills = {
				{ name = "Spirit of Boreas", cooldown = 12, type = "Melee", airHold = true },
				{ name = "Spirit of Zephyrus", cooldown = 13, type = "Melee", airHold = true },
				{ name = "Spirit of Euros", cooldown = 18, type = "Bolt", airHold = true },
				{ name = "Saint Spirit of Zephyr", cooldown = 30, type = "Melee" },
			},
		},
	} :: KitInfo,
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

function Kits.SkillsOf(character: Model): { SkillInfo }
	local kit = Kits.Of(character)
	if not kit then
		return {}
	end
	if character:GetAttribute("Awakened") == true and kit.ascension and character:GetAttribute("Ascended") == true then
		return kit.ascension.skills
	end
	if character:GetAttribute("Awakened") == true and kit.awakenedSkills then
		local sword = character:GetAttribute("Sword")
		local weapon = if kit.swords and type(sword) == "string" then kit.swords[sword] else nil
		if weapon then
			local merged = table.clone(kit.awakenedSkills)
			for slot, skill in weapon.skills do
				merged[slot] = skill
			end
			return merged
		end
		return kit.awakenedSkills
	end
	return kit.skills
end

function Kits.Of(character: Model): KitInfo?
	return Kits.Get(character:GetAttribute("Kit") :: string?)
end

return Kits
