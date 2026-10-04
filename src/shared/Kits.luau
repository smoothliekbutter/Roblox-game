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
	-- Has an air version that holds the player up: the client keeps them in
	-- the air from the moment of the press (see Input.holdInAir).
	airHold: boolean?,
}

-- One of a character's weapons (Asta's swords): its name and the moves 1
-- and 2 it gives him while awakened.
export type SwordInfo = {
	name: string,
	skills: { SkillInfo },
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
	-- The R special: one per character, kept through awakening.
	special: SkillInfo?,
	-- Awakening swaps the move set (like Vessel -> Sukuna, Hero Hunter -> Rampage).
	awakenedSkills: { SkillInfo }?,
	-- A different R while awakened (Asta: swap to another of his swords).
	awakenedSpecial: SkillInfo?,
	-- Weapons that change moves 1 and 2 while awakened, by the character's
	-- "Sword" attribute (see Kits.SkillsOf).
	swords: { [string]: SwordInfo }?,
	awakening: {
		name: string,
		duration: number,
		damageMultiplier: number,
		cooldownMultiplier: number,
		speedBonus: number,
	}?,
	-- Extra jumps in the air (Yuno rides the wind: one more).
	airJumps: number?,
	-- A second, stronger stage of the awakening (Yuno: Full-Crown): once
	-- `charge` is reached in the first stage, G can be pressed again. It
	-- charges with damage dealt, or, with `chargeByKit`, only when the kit
	-- says so (Yuno: each landed Tempest Dive is 1). Its own moves and stats,
	-- and the awakening's timer restarts at `duration`.
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
			{ name = "Bull Thrust", cooldown = 10, type = "Melee", airHold = true },
			{ name = "Black Meteorite", cooldown = 13, type = "Melee", airHold = true },
			{ name = "Black Divider", cooldown = 11, type = "Melee", airHold = true },
			{ name = "Anti-Magic Deflect", cooldown = 14, type = "Counter", airHold = true },
		},
		-- Leap off a blast of anti-magic; R again in the air to plunge.
		special = { name = "Anti-Magic Leap", cooldown = 10, type = "Melee", airHold = true },
		awakenedSkills = {
			{ name = "Black Hurricane", cooldown = 9, type = "Melee", airHold = true },
			{ name = "Black Slash", cooldown = 7, type = "Bolt", airHold = true },
			{ name = "Grand Divider", cooldown = 13, type = "Explosion", airHold = true },
			{ name = "Black Moon", cooldown = 25, type = "Melee" },
		},
		-- In Black Form R draws another of his swords from the grimoire, at
		-- random; moves 1 and 2 come from the sword in his hand.
		awakenedSpecial = { name = "Swap Sword", cooldown = 10, type = "Melee" },
		swords = {
			Slayer = {
				name = "Demon-Slayer Sword",
				skills = {
					{ name = "Black Hurricane", cooldown = 9, type = "Melee", airHold = true },
					{ name = "Slayer Recall", cooldown = 12, type = "Bolt", airHold = true },
				},
			},
			Dweller = {
				name = "Demon-Dweller Sword",
				skills = {
					{ name = "Black Slash", cooldown = 7, type = "Bolt", airHold = true },
					{ name = "Conquering Eon", cooldown = 15, type = "Counter", airHold = true },
				},
			},
			Destroyer = {
				name = "Demon-Destroyer Sword",
				skills = {
					{ name = "Causality Break", cooldown = 15, type = "Zone", airHold = true },
					{ name = "Severance", cooldown = 12, type = "Melee", airHold = true },
				},
			},
			Slasher = {
				name = "Demon-Slasher Katana",
				skills = {
					{ name = "Infinite Slash", cooldown = 13, type = "Melee", airHold = true },
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
		description = "Wind magic blessed by the spirit Sylph, and star magic. Fights from range and is never where you left him.",
		color = Color3.fromRGB(90, 220, 150),
		playable = true,
		m1 = {
			-- Wind-wrapped strikes reach a little further than bare fists.
			HitboxOffset = 3.5,
		},
		-- He rides the wind: one more jump in the air, for chasing air combos.
		airJumps = 1,
		-- Mid-range zoner (Asta's opposite): a rain of blades to pin people
		-- down, a homing hawk, a launcher, a six-arrow volley. Less damage
		-- per move than Asta's sword, but from where the sword can't reach.
		skills = {
			{ name = "Wind Blades Shower", cooldown = 11, type = "Swarm", airHold = true },
			{ name = "Swift White Hawk", cooldown = 8, type = "Bolt", airHold = true },
			{ name = "Heavenly Wind Ark", cooldown = 12, type = "Zone", airHold = true },
			{ name = "Gale White Bow", cooldown = 15, type = "Bolt", airHold = true },
		},
		-- Star magic: place a star, press R again to be there.
		special = { name = "Conjunction", cooldown = 10, type = "Melee" },
		-- Half-Crown Spirit of Zephyr (G): Sylph on his left side.
		awakenedSkills = {
			{ name = "Spirit Storm", cooldown = 12, type = "Bolt", airHold = true },
			{ name = "Tempest Dive", cooldown = 16, type = "Melee", airHold = true },
			{ name = "Quartile Scutum", cooldown = 16, type = "Counter" },
			{ name = "Quartile Hasta", cooldown = 14, type = "Bolt", airHold = true },
		},
		awakening = {
			name = "Half-Crown",
			duration = 45,
			damageMultiplier = 1.15,
			cooldownMultiplier = 0.85,
			speedBonus = 4,
		},
		-- Full-Crown Spirit of Zephyr: G again once Tempest Dive (Half-Crown
		-- 2) has landed twice. Stronger than Black Form, but only 30 seconds.
		ascension = {
			name = "Full-Crown",
			duration = 30,
			charge = 2,
			chargeByKit = true,
			damageMultiplier = 1.3,
			cooldownMultiplier = 0.75,
			speedBonus = 8,
			skills = {
				{ name = "Spirit of Notos", cooldown = 12, type = "Counter" },
				{ name = "Spirit of Zephyrus", cooldown = 13, type = "Bolt", airHold = true },
				{ name = "Spirit of Euros", cooldown = 18, type = "Bolt", airHold = true },
				{ name = "Neverland", cooldown = 30, type = "Melee" },
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

-- The move list a character has right now (awakened moves while awakened).
function Kits.SkillsOf(character: Model): { SkillInfo }
	local kit = Kits.Of(character)
	if not kit then
		return {}
	end
	if character:GetAttribute("Awakened") == true and kit.ascension and character:GetAttribute("Ascended") == true then
		return kit.ascension.skills
	end
	if character:GetAttribute("Awakened") == true and kit.awakenedSkills then
		-- Moves 1 and 2 come from the sword in his hand.
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

-- The kit a character is using (nil for kit-less NPCs like the dummies).
function Kits.Of(character: Model): KitInfo?
	return Kits.Get(character:GetAttribute("Kit") :: string?)
end

return Kits
