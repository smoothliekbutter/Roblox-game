--[[
	Config
	Every tunable combat number lives here so balancing never means digging
	through logic. Times are in seconds, speeds in studs/second.
]]

local Config = {}

Config.Debug = {
	-- Draws a red box wherever a hitbox is checked (server-side, visible to everyone).
	ShowHitboxes = false,
}

Config.Movement = {
	WalkSpeed = 16,
	JumpHeight = 4.5, -- studs (Roblox default is 7.2)
	AttackingSpeed = 10,
	BlockingSpeed = 7,
	StunnedSpeed = 3,
	CastingSpeed = 5,
}

Config.M1 = {
	ComboLength = 4,
	Damage = 3.5,
	FinisherDamage = 5,

	SwingCooldown = 0.3, -- time between swings in a string
	ResetTime = 1.1, -- idle time before the combo counter resets
	EndLag = 1.1, -- lockout after the final hit
	Busy = 0.35, -- slowed and can't jump while swinging (> SwingCooldown, so a full string stays grounded)
	FinisherBusy = 0.45,
	WindUp = 0.08, -- delay between the swing starting and the hitbox
	FinisherWindUp = 0.15, -- the 4th hit winds up longer (matches its animation)
	InputTolerance = 0.06, -- accept swings this early to absorb network jitter

	HitStun = 0.6, -- longer than SwingCooldown + WindUp, so strings are true combos
	UppercutStun = 1.1,

	HitboxSize = Vector3.new(5.5, 6, 6),
	HitboxOffset = 3.25, -- studs in front of the root

	Push = 6, -- small push on normal hits keeps the victim in range
	LungeSpeed = 13, -- attacker steps forward a little on every swing (eased out)
	LungeTime = 0.16,
	AirFloat = 0.35, -- air hits hold both players up this long

	KnockbackForce = 65,
	KnockbackLift = 18,
	UppercutForce = 60, -- a ragdoll launch: about 8 studs up, in reach of a jump
	UppercutRagdoll = 1.2,
	DownslamForce = 75,
}

Config.Block = {
	PerfectWindow = 0.2, -- block pressed this recently = perfect block
	ParryStun = 1.25, -- attacker stun after being perfect blocked
	GuardBreakStun = 1.75,
	Cooldown = 0.4, -- after releasing block, stops perfect-block spam
	Pushback = 14,
	FacingDot = 0, -- > 0 means the attacker must be in front (180 degree cone)
}

Config.Dash = {
	Cooldown = 2,
	Duration = 0.28,
	Tolerance = 0.2, -- server allows the client to be this early (latency)
	Speed = {
		Front = 85,
		Back = 70,
		Left = 70,
		Right = 70,
	},
}

-- Awakening: fills by dealing (and a bit by taking) damage. G when full.
-- About 90 damage dealt (or 200 taken) fills it: it should take a real fight.
Config.Awakening = {
	Max = 100,
	GainPerDamageDealt = 1.1,
	GainPerDamageTaken = 0.5,
}

-- Switching characters is blocked this long after dealing or taking damage.
Config.KitSwitchCombatLock = 5

Config.Ragdoll = {
	Duration = 1.5,
}

Config.Physics = {
	-- Heavy hits freeze the victim for a split second before launching
	-- them, which sells the impact.
	HitStop = 0.06,
	-- Launched ragdolls tumble: spin (rad/s) per stud/s of launch speed.
	TumbleSpin = 0.12,
	MaxTumble = 10,
	-- A ragdoll moving at least this fast that suddenly stops (floor, wall)
	-- kicks up a body impact effect.
	ImpactSpeed = 35,
}

-- Evasive: fills as you take damage. When full, Q while stunned or
-- ragdolled breaks you out of the combo.
Config.Evasive = {
	Max = 100,
	GainPerDamage = 5,
	RegenPerSecond = 1.5,
	IFrames = 0.6,
	Speed = 55,
}

return Config
