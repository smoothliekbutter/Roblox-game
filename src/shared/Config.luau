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

-- Play-testing helpers. Turn these off (or delete them) before release.
Config.PlayTest = {
	-- An "INFINITE AWAKENING" button in the top bar: the bar stays full, the
	-- form never runs out and the second stage (Yuno's Full-Crown) is
	-- always ready. Anyone can press it while this is on.
	InfiniteAwakening = true,
}

Config.Movement = {
	WalkSpeed = 16,
	JumpHeight = 4.5, -- studs (Roblox default is 7.2)
	-- The air jump some kits get (Yuno, Kits airJumps): a small hop, about
	-- 4 studs, to pair with air moves rather than replace the jump.
	AirJumpSpeed = 24,
	AirJumpTime = 0.1,
	AttackingSpeed = 10,
	BlockingSpeed = 7,
	StunnedSpeed = 3,
	CastingSpeed = 5,
}

Config.M1 = {
	ComboLength = 4,
	Damage = 3.5,
	FinisherDamage = 5,

	-- Swing timings match the swing animations (SWING_TIMES in tools/anim).
	SwingCooldown = 0.36, -- time between swings in a string
	ResetTime = 1.2, -- idle time before the combo counter resets
	EndLag = 1.1, -- lockout after the final hit
	Busy = 0.42, -- slowed and can't jump while swinging (> SwingCooldown, so a full string stays grounded)
	FinisherBusy = 0.52,
	WindUp = 0.1, -- delay between the swing starting and the hitbox
	FinisherWindUp = 0.17, -- the 4th hit winds up longer (matches its animation)
	InputTolerance = 0.1, -- accept swings this early to absorb network jitter

	HitStun = 0.66, -- longer than SwingCooldown + WindUp (plus slack for ping), so strings are true combos
	-- The 3rd hit sets up the finisher: long enough to jump and downslam
	-- (3 hits, jump, hit) on a real player, ping included.
	SetupStun = 1.0,
	DownslamJumpAfter = 0.12, -- free to jump this soon after the 3rd hit
	UppercutStun = 1.1,
	-- The uppercut is a launcher: short end lag and an early jump, so you
	-- can go up after them and carry on in the air.
	UppercutEndLag = 0.4,
	UppercutJumpAfter = 0.2,
	UppercutGravity = 1.6, -- the launched body falls this much harder: a snappy arc
	JuggleTime = 0.85, -- how long a launched body can still be hit in the air

	HitboxSize = Vector3.new(5.5, 6, 6),
	HitboxOffset = 3.25, -- studs in front of the root

	Push = 10, -- pushes the victim about as far as the swing steps you in, so the spacing holds
	PushTime = 0.18,
	LungeSpeed = 13, -- attacker steps forward a little on every swing (eased out)
	LungeTime = 0.16,
	AirFloat = 0.45, -- air hits hold both players up this long (bridges the gap to the next swing)

	KnockbackForce = 65,
	KnockbackLift = 18,
	UppercutForce = 85, -- a ragdoll launch: about 10 studs up on 1.6x gravity (up and down in half a second)
	UppercutRagdoll = 1.1,
	DownslamForce = 75,
}

Config.Block = {
	PerfectWindow = 0.2, -- block pressed this recently = perfect block
	PerfectCooldown = 10, -- after one, blocks are plain blocks this long ("PerfectCD")
	ParryStun = 1.25, -- attacker stun after being perfect blocked
	GuardBreakStun = 1.75,
	Cooldown = 0.4, -- after releasing block, stops perfect-block spam
	Pushback = 14,
	FacingDot = 0, -- > 0 means the attacker must be in front (180 degree cone)
}

Config.Dash = {
	Cooldown = 2, -- front and back dashes
	Duration = 0.28,
	-- Side dashes are a smaller hop (about 10 studs to the front dash's 19)
	-- on a cooldown of their own.
	SideCooldown = 1.5,
	SideDuration = 0.2,
	Tolerance = 0.2, -- server allows the client to be this early (latency)
	Speed = {
		Front = 85,
		Back = 70,
		Left = 60,
		Right = 60,
	},
}

-- Awakening: fills by dealing (and a bit by taking) damage. G when full.
-- About 90 damage dealt (or 200 taken) fills it: it should take a real fight.
Config.Awakening = {
	Max = 100,
	GainPerDamageDealt = 1.1,
	GainPerDamageTaken = 0.5,
}

-- Timed states moves can put on people (Yuno's great arrow): PowerUntil hits
-- harder, WeakUntil hits softer, SlowUntil moves slower.
Config.States = {
	PowerMultiplier = 1.15,
	WeakMultiplier = 0.75,
	SlowMultiplier = 0.6,
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
	-- How much of a launch's sideways speed a ragdoll carries (the height
	-- is kept exactly), so knockback reads as a throw, not a teleport.
	RagdollCarry = 0.7,
	-- Gentler pushes than this on a ragdoll hold it (air hits, hangs);
	-- faster ones throw it.
	RagdollHoldSpeed = 20,
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
