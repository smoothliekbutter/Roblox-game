local Config = {}

Config.Debug = {
	ShowHitboxes = false,
}

Config.PlayTest = {
	InfiniteAwakening = true,
}

Config.Movement = {
	WalkSpeed = 16,
	JumpHeight = 4.5,
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

	SwingCooldown = 0.36,
	ResetTime = 1.2,
	EndLag = 1.1,
	Busy = 0.42,
	FinisherBusy = 0.52,
	WindUp = 0.1,
	FinisherWindUp = 0.17,
	InputTolerance = 0.1,

	HitStun = 0.66,
	SetupStun = 1.0,
	DownslamJumpAfter = 0.12,
	UppercutStun = 1.1,
	UppercutEndLag = 0.4,
	UppercutJumpAfter = 0.2,
	UppercutGravity = 1.6,
	JuggleTime = 0.85,

	HitboxSize = Vector3.new(5.5, 6, 6),
	HitboxOffset = 3.25,

	Push = 10,
	PushTime = 0.18,
	LungeSpeed = 13,
	LungeTime = 0.16,
	AirFloat = 0.45,

	KnockbackForce = 65,
	KnockbackLift = 18,
	UppercutForce = 85,
	UppercutRagdoll = 1.1,
	DownslamForce = 75,
}

Config.Block = {
	PerfectWindow = 0.2,
	PerfectCooldown = 10,
	ParryStun = 1.25,
	GuardBreakStun = 1.75,
	Cooldown = 0.4,
	Pushback = 14,
	FacingDot = 0,
}

Config.Dash = {
	Cooldown = 2,
	Duration = 0.28,
	SideCooldown = 1.5,
	SideDuration = 0.2,
	Tolerance = 0.2,
	Speed = {
		Front = 85,
		Back = 70,
		Left = 60,
		Right = 60,
	},
}

Config.Awakening = {
	Max = 100,
	GainPerDamageDealt = 1.1,
	GainPerDamageTaken = 0.5,
}

Config.States = {
	PowerMultiplier = 1.15,
	WeakMultiplier = 0.75,
	SlowMultiplier = 0.6,
}

Config.KitSwitchCombatLock = 5

Config.Ragdoll = {
	Duration = 1.5,
}

Config.Physics = {
	HitStop = 0.06,
	TumbleSpin = 0.12,
	MaxTumble = 10,
	RagdollCarry = 0.7,
	RagdollHoldSpeed = 20,
	ImpactSpeed = 35,
}

Config.Evasive = {
	Max = 100,
	GainPerDamage = 5,
	RegenPerSecond = 1.5,
	IFrames = 0.6,
	Speed = 55,
}

return Config
