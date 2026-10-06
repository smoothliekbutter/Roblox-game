"""Yuno (Prince of Wind) animations: stance, locomotion and spell casts.

Run `python3 tools/anim/yuno_anims.py` to check them (feet on the floor at
every keyframe and in between) and `python3 tools/anim/yuno_anims.py
src/client/Kits/Wind/Animations.luau` to write the Luau data.

Same conventions as asta_anims.py (he just has no sword):
  R(x, y, z)       torso/head/leg rotation: torso -x leans forward, +y turns left
  L(pitch, yaw, roll)  arm/leg aim: pitch 90 = straight ahead, 180 = up;
                   +yaw swings it toward his left, +roll out to his right
"""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from design import *
from math import sin, cos, pi, radians

def R(x, y=0, z=0): return ('rot', x, y, z)
def L(p, y=0, r=0): return ('limb', p, y, r)
def _r(v): return round(v, 2)
TAU = 2 * pi

def pose(torso, head, rarm, larm, rleg=R(-4, 0, 6), lleg=R(6, 0, -7)):
    return {'Torso': torso, 'Head': head, 'RightArm': rarm, 'LeftArm': larm, 'RightLeg': rleg, 'LeftLeg': lleg}

# ---------------- Stance ----------------
# Calm and upright, turned a little, the left hand held loose in front of
# him where the wind gathers; slow breathing.
STANCE = pose(R(-3, 12), R(2, -10), L(12, 4, 10), L(30, -8, -16))
IDLE = [
    (0.0, STANCE),
    (1.4, pose(R(-1, 12), R(4, -14), L(15, 4, 11), L(34, -8, -18))),
    (2.8, STANCE),
]

# ---------------- Hovering (Half-Crown and Full-Crown) ----------------
# Carried on the wind (the client lifts everything he plays about 1.8 studs
# while he's awakened, PoseAnimator.SetLift; these only add the bob),
# rising and settling slowly, legs loose and trailing, arms drifting out
# from his sides in the updraft. Moving, he leans into it and glides: legs
# swept back, arms back like wings, chin up.
def hover(lift, lean, turn, rarm, larm, rleg, lleg, head):
    return {'Torso': ('body', lift, lean, turn, 0), 'Head': head, 'RightArm': rarm, 'LeftArm': larm,
            'RightLeg': rleg, 'LeftLeg': lleg}

HOVER_LOW = hover(0, 3, 12, L(16, 4, 24), L(24, -4, -28), L(10, 0, 4), L(-14, 0, -4), R(-5, -10))
HOVER_HIGH = hover(0.32, 1, 14, L(22, 4, 32), L(30, -4, -36), L(6, 0, 6), L(-18, 0, -6), R(-8, -12))
HOVER_IDLE = [(0.0, HOVER_LOW), (1.6, HOVER_HIGH), (3.2, HOVER_LOW)]
GLIDE_A = hover(-0.12, -24, 0, L(-28, 6, 24), L(-28, -6, -24), L(-22, 0, 3), L(-34, 0, -3), R(22))
GLIDE_B = hover(0.12, -26, 0, L(-34, 6, 30), L(-34, -6, -30), L(-30, 0, 3), L(-26, 0, -3), R(24))
HOVER_MOVE = [(0.0, GLIDE_A), (0.8, GLIDE_B), (1.6, GLIDE_A)]

# ---------------- Locomotion ----------------
# Built like Asta's (see asta_anims.py): smooth curves sampled densely, the
# cadence set by the swing so a foot passing under him doesn't slide, a
# runner's bob. No sword, so both arms swing against the legs.
def stride(swing, reach):
    return round(TAU * 2 * cos(radians(reach)) * radians(swing), 2)

def cycle(fn, keys):
    return [(round(i / keys, 4), fn(i / keys)) for i in range(keys + 1)]

RUN_LEAN, RUN_SWING, RUN_REACH, RUN_LIFT = 14, 50, 7, 0.18
RUN_STRIDE = stride(RUN_SWING, RUN_REACH)

def run_lift(p):
    return RUN_LIFT * (1 - cos(2 * TAU * p - 0.35)) / 2

def run_pose(p, base=0.0):
    s, bob = sin(TAU * p), cos(2 * TAU * p - 0.35)
    twist, roll = -6 * s, 3 * cos(TAU * p)
    torso = R(_r(-RUN_LEAN - 1.5 * (1 - bob) / 2), _r(twist), _r(roll))
    return {
        'Torso': ('body', _r(base + run_lift(p)), *torso[1:]),
        'Head': R(_r(RUN_LEAN * 0.85 + bob), _r(-twist), _r(-roll)),
        'RightArm': L(_r(6 - 46 * s), _r(-8 * s), _r(8 + 3 * s * s)),
        'LeftArm': L(_r(6 + 46 * s), _r(-8 * s), _r(-8 - 3 * s * s)),
        'RightLeg': L(_r(RUN_REACH + RUN_SWING * s + RUN_LEAN), _r(-twist), _r(-0.6 * roll)),
        'LeftLeg': L(_r(RUN_REACH - RUN_SWING * s + RUN_LEAN), _r(-twist), _r(-0.6 * roll)),
    }

RUN_BASE = plant_pose(run_pose(0.35 / (2 * TAU)))['Torso'][1]
RUN = cycle(lambda p: run_pose(p, RUN_BASE), 16)

WALK_LEAN, WALK_SWING, WALK_REACH = 4, 28, 3
WALK_STRIDE = stride(WALK_SWING, WALK_REACH)

def walk_pose(p):
    s, c2 = sin(TAU * p), cos(2 * TAU * p)
    twist, roll = -4 * s, 2 * cos(TAU * p)
    torso = R(-WALK_LEAN, _r(twist), _r(roll))
    return {
        'Torso': torso,
        'Head': R(_r(WALK_LEAN * 0.8 + 0.6 * c2), _r(-twist), _r(-roll)),
        'RightArm': L(_r(4 - 24 * s), _r(-5 * s), 7),
        'LeftArm': L(_r(4 + 24 * s), _r(-5 * s), -7),
        'RightLeg': L(_r(WALK_REACH + WALK_SWING * s + WALK_LEAN), _r(-twist), _r(-0.6 * roll)),
        'LeftLeg': L(_r(WALK_REACH - WALK_SWING * s + WALK_LEAN), _r(-twist), _r(-0.6 * roll)),
    }

WALK = cycle(walk_pose, 12)

# Jumping or falling: riding the wind, arms out, one knee up.
AIR = [(0.0, pose(R(-6), R(4), L(40, 0, 30), L(40, 0, -30), R(30), R(-12)))]

# ---------------- M1: wind swipes ----------------
# Each swipe throws a crescent of wind off the hand. Timed like Asta's swings
# (see asta_anims.py): held in the wind-up while the clip fades in, then
# through, strike, settle; legs layered on whatever he's doing (a counter-
# twist as he turns).
def LEGS(y):
    return {'RightLeg': R(0, y, 0), 'LeftLeg': R(0, y, 0)}

def M1POSE(torso, head, rarm, larm, legs):
    return {'Torso': torso, 'Head': head, 'RightArm': rarm, 'LeftArm': larm, **legs}

SWING_TIMES = (0.1, 0.15, 0.21, 0.4)
HEAVY_SWING_TIMES = (0.14, 0.21, 0.28, 0.52)

def swing(windup, through, strike, settle, heavy=False):
    t = HEAVY_SWING_TIMES if heavy else SWING_TIMES
    return [(0.0, windup), (t[0], windup), (t[1], through), (t[2], strike), (t[3], settle)]

# Right hand from his right across to his left at chest height.
SWIPE1 = swing(
    M1POSE(R(2, -38), R(0, 30), L(84, -95, 0), L(50, 20, -10), LEGS(38)),
    M1POSE(R(-4, -5), R(0, 4), L(88, -20, 0), L(40, 10, -14), LEGS(5)),
    M1POSE(R(-8, 36), R(0, -26), L(84, 70, 0), L(30, -20, -20), LEGS(-34)),
    M1POSE(R(-6, 26), R(0, -18), L(72, 55, 6), L(32, -18, -20), LEGS(-24)),
)
# The left hand back the other way.
SWIPE2 = swing(
    M1POSE(R(2, 34), R(0, -26), L(45, -20, 10), L(84, 95, 0), LEGS(-32)),
    M1POSE(R(-4, 2), R(0, -2), L(40, -10, 14), L(88, 20, 0), LEGS(-2)),
    M1POSE(R(-8, -36), R(0, 26), L(30, 20, 20), L(84, -70, 0), LEGS(34)),
    M1POSE(R(-6, -26), R(0, 18), L(32, 18, 20), L(72, -55, -6), LEGS(24)),
)
# Rising: the right hand from low on his left up past his right shoulder.
SWIPE3 = swing(
    M1POSE(R(-14, 24), R(10, -16), L(30, 40, -10), L(50, -10, -20), LEGS(-22)),
    M1POSE(R(-4, 4), R(2, -2), L(95, 10, 0), L(40, -10, -20), LEGS(-4)),
    M1POSE(R(8, -26), R(-10, 16), L(160, -30, 10), L(26, 10, -24), LEGS(24)),
    M1POSE(R(4, -18), R(-6, 12), L(140, -22, 10), L(30, 8, -22), LEGS(16)),
)
# Finisher: both palms driven out together, a gale off them.
GALE_PUSH = swing(
    M1POSE(R(6), R(-4), L(-10, 0, 14), L(-10, 0, -14), LEGS(0)),
    M1POSE(R(-6), R(2), L(70, 18, 6), L(70, -18, -6), LEGS(0)),
    M1POSE(R(-14), R(8), L(92, 10, 0), L(92, -10, 0), LEGS(0)),
    M1POSE(R(-10), R(6), L(84, 12, 4), L(84, -12, -4), LEGS(0)),
    heavy=True,
)
# Finisher (jump held): both hands swept up, an updraft under them.
GALE_RISE = swing(
    M1POSE(R(-18), R(10), L(10, 20, 10), L(10, -20, -10), LEGS(0)),
    M1POSE(R(-6), R(2), L(90, 10, 6), L(90, -10, -6), LEGS(0)),
    M1POSE(R(12), R(-16), L(170, 10, 10), L(170, -10, -10), LEGS(0)),
    M1POSE(R(8), R(-12), L(155, 10, 10), L(155, -10, -10), LEGS(0)),
    heavy=True,
)
# Finisher (in the air): both hands brought down like a hammer, a downdraft.
GALE_FALL = swing(
    {'Torso': R(16), 'Head': R(-10), 'RightArm': L(172, 8, 6), 'LeftArm': L(172, -8, -6)},
    {'Torso': R(0), 'Head': R(0), 'RightArm': L(110, 8, 0), 'LeftArm': L(110, -8, 0)},
    {'Torso': R(-34), 'Head': R(18), 'RightArm': L(36, 8, 0), 'LeftArm': L(36, -8, 0)},
    {'Torso': R(-28), 'Head': R(14), 'RightArm': L(44, 8, 0), 'LeftArm': L(44, -8, 0)},
    heavy=True,
)

# ---------------- Base: Prince of Wind ----------------
# Wind Blades Shower: right hand up to the sky as the blades form (0.2), then
# brought down and forward to send them (0.35).
SHOWER_RAISE = pose(R(4, 18), R(16, -12), L(172, -6, 8), L(40, -10, -30), R(-12, 0, 8), R(14, 0, -8))
SHOWER_SEND = pose(R(-10, -8), R(4, 6), L(112, 4, 6), L(30, -10, -26), R(-16, 0, 8), R(18, 0, -8))
# Held up a moment longer, reaching higher, as the blades gather (the wind-up).
SHOWER_GATHER = pose(R(6, 20), R(18, -14), L(178, -4, 10), L(44, -10, -32), R(-12, 0, 8), R(14, 0, -8))
SHOWER = [(0.0, STANCE), (0.2, SHOWER_RAISE), (0.5, SHOWER_GATHER), (0.6, SHOWER_SEND), (0.95, SHOWER_SEND)]

# Swift White Hawk: wound back (0.12), then the palm thrust out as the hawk leaves (0.22).
HAWK_WIND = pose(R(-4, 30), R(6, -26), L(30, -10, 30), L(60, -20, -10), R(-14, 0, 6), R(16, 0, -6))
HAWK_THROW = pose(R(-12, -20), R(10, 18), L(96, 10, 2), L(20, 0, -20), R(-22, 0, 6), R(22, 0, -6))
HAWK = [(0.0, STANCE), (0.12, HAWK_WIND), (0.22, HAWK_THROW), (0.5, HAWK_THROW)]

# Heavenly Wind Ark: low and wide (0.1), then both arms sweep up as the ark
# rises out of the ground (0.18). In the air the sweep goes down instead.
ARK_LOW = pose(R(-18), R(10), L(-12, 0, 24), L(-12, 0, -24), R(-26, 0, 10), R(26, 0, -10))
ARK_HIGH = pose(R(8), R(20), L(165, -8, 10), L(165, 8, -10), R(-10, 0, 6), R(12, 0, -6))
ARK = [(0.0, STANCE), (0.1, ARK_LOW), (0.18, ARK_HIGH), (0.5, ARK_HIGH)]
AIR_ARK_HIGH = pose(R(6), R(14), L(160, -6, 12), L(160, 6, -12), R(10), R(-8))
AIR_ARK_LOW = pose(R(-24), R(-6), L(15, 0, 16), L(15, 0, -16), R(30), R(-14))
AIR_ARK = [(0.0, AIR[0][1]), (0.1, AIR_ARK_HIGH), (0.18, AIR_ARK_LOW), (0.5, AIR_ARK_LOW)]

# Gale White Bow: turned side-on like an archer, the bow arm (left) out at
# them, the right drawing the string to his chin; held through the volley.
BOW_AIM = pose(R(-4, -68), R(4, 62), L(92, 70, 0), L(90, 64, 0), R(-16, 20, 8), R(16, 20, -6))
BOW_FULL = pose(R(-6, -72), R(4, 66), L(90, 50, -2), L(90, 70, 0), R(-18, 22, 8), R(18, 22, -6))
BOW = [(0.0, STANCE), (0.25, BOW_AIM), (0.5, BOW_FULL), (1.35, BOW_FULL)]

# Tornado (R): the right hand swung low across him (0.14), then swept up and
# out at where the tornado rises (0.3), the left hand circling back.
TORNADO_COIL = pose(R(-8, 28), R(4, -20), L(20, 50, -10), L(40, -10, -20), R(-10, 0, 6), R(12, 0, -6))
TORNADO_SEND = pose(R(2, -18), R(6, 12), L(120, -20, 20), L(30, 10, -30), R(-14, 0, 8), R(14, 0, -8))
TORNADO = [(0.0, STANCE), (0.14, TORNADO_COIL), (0.3, TORNADO_SEND), (0.6, TORNADO_SEND)]
TORNADO_COIL_AIR = pose(R(-8, 28), R(6, -20), L(20, 50, -10), L(40, -10, -20), R(36, 0, 8), R(12, 0, -6))
TORNADO_SEND_AIR = pose(R(-4, -18), R(10, 12), L(100, -20, 20), L(30, 10, -30), R(30, 0, 8), R(8, 0, -6))
TORNADO_AIR = [(0.0, AIR[0][1]), (0.14, TORNADO_COIL_AIR), (0.3, TORNADO_SEND_AIR), (0.6, TORNADO_SEND_AIR)]

# Points where a star goes (0.12): Saint Spirit of Zephyr's flick.
POINT = pose(R(-4, -10), R(6, 10), L(104, 14, 4), L(20, 0, -18), R(-10, 0, 6), R(12, 0, -6))
POINTING = [(0.0, STANCE), (0.12, POINT), (0.4, POINT)]

# ---------------- Half-Crown Spirit of Zephyr ----------------
# Spirit Storm: palm out, the left hand bracing the wrist, mana gathering
# (0.2 to 0.45); fired, he leans into the beam against the push.
STORM_GATHER = pose(R(-8, -12), R(4, 10), L(92, 10, 0), L(86, -30, 0), R(-20, 0, 8), R(20, 0, -8))
STORM_PUSH = pose(R(-14, -10), R(8, 8), L(96, 8, 0), L(90, -28, 0), R(-24, 0, 10), R(24, 0, -10))
STORM_CHARGE = [(0.0, STANCE), (0.2, STORM_GATHER), (0.45, STORM_GATHER)]
STORM_FIRE = [(0.0, STORM_GATHER), (0.06, STORM_PUSH), (0.7, STORM_PUSH)]

# Quartile Scutum: both hands up and out in front, holding the barrier.
SCUTUM_HOLD = pose(R(4), R(2), L(100, 22, 12), L(100, -22, -12), R(-16, 0, 8), R(16, 0, -8))
SCUTUM = [(0.0, STANCE), (0.15, SCUTUM_HOLD), (2.5, SCUTUM_HOLD)]

# Nova Vortex: his right hand up and open in front of him, the star forming
# over the palm, the left hand cupped under it, eyes on it; then the flick
# that sends it, the whole body turning into it, the free arm swung back.
NOVA_CRADLE = pose(R(-4, 20), R(14, -12), L(112, -14, 8), L(62, 34, -14), R(-14, 0, 8), R(14, 0, -8))
NOVA_SEND = pose(R(-12, -26), R(6, 20), L(94, 22, 0), L(26, 0, -34), R(-26, 0, 8), R(24, 0, -8))
NOVA_FORM = [(0.0, STANCE), (0.16, NOVA_CRADLE), (0.32, NOVA_CRADLE)]
NOVA_FLICK = [(0.0, NOVA_CRADLE), (0.07, NOVA_SEND), (0.5, NOVA_SEND)]
# In the air: the same, knees up, and the star flicked down at the ground.
NOVA_CRADLE_AIR = pose(R(-8, 20), R(18, -12), L(100, -14, 8), L(56, 34, -14), R(-40, 0, 10), R(-10, 0, -10))
NOVA_SEND_AIR = pose(R(-30, -22), R(22, 18), L(58, 18, 0), L(20, 0, -40), R(-30, 0, 10), R(-4, 0, -10))
NOVA_FORM_AIR = [(0.0, AIR[0][1]), (0.16, NOVA_CRADLE_AIR), (0.32, NOVA_CRADLE_AIR)]
NOVA_FLICK_AIR = [(0.0, NOVA_CRADLE_AIR), (0.07, NOVA_SEND_AIR), (0.5, NOVA_SEND_AIR)]

# ---------------- Full-Crown Spirit of Zephyr ----------------
# Spirit of Notos: arms crossed as the wind gathers, flung wide as it bursts.
NOTOS_GATHER = pose(R(-12), R(-6), L(82, -38, 0), L(82, 38, 0), R(-14, 0, 8), R(14, 0, -8))
NOTOS_BURST = pose(R(8), R(16), L(96, 0, 80), L(96, 0, -80), R(-20, 0, 10), R(20, 0, -10))
NOTOS = [(0.0, STANCE), (0.08, NOTOS_GATHER), (0.15, NOTOS_BURST), (0.45, NOTOS_BURST)]

# Raised overhead in both hands, then brought down (Tempest Dive: over the
# top of them, then driving them into the ground).
BOREAS_RAISE = pose(R(6, 6), R(12), L(168, 10, 0), L(168, -10, 0), R(-14, 0, 6), R(14, 0, -6))
BOREAS_DOWN = pose(R(-30, -4), R(14), L(44, 10, 0), L(44, -10, 0), R(-30, 0, 10), R(30, 0, -10))
BOREAS_FORM = [(0.0, STANCE), (0.12, BOREAS_RAISE), (0.42, BOREAS_RAISE)]

# Spirit of Zephyrus: a long lunge, sword arm low and forward (the blade
# runs out ahead along it), free arm thrown back; then the thrust, deeper.
LUNGE = pose(R(-28, 18), R(18, -14), L(20, 8, 0), L(-35, 0, -25), R(-55, 0, 8), R(45, 0, -8))
THRUST = pose(R(-36, 26), R(22, -18), L(26, 6, 0), L(-48, 0, -30), R(-62, 0, 8), R(52, 0, -8))
ZEPHYRUS_LUNGE = [(0.0, STANCE), (0.08, LUNGE), (0.6, LUNGE)]
ZEPHYRUS_THRUST = [(0.0, LUNGE), (0.06, THRUST), (0.45, THRUST)]
# The waltz (in the air, held up by the wind): after the cuts round them he
# draws back out in front of them, sword low at his hip, free hand aimed at
# them, knees up; then the thrust, flat out, the free arm flung back.
WALTZ_DRAW = pose(R(-6, -32), R(8, 26), L(-22, 0, 16), L(78, 22, 0), R(-46, 0, 10), R(-12, 0, -10))
WALTZ_SKEWER = pose(R(-34, 24), R(20, -16), L(24, 6, 0), L(-46, 0, -30), R(-30, 0, 10), R(26, 0, -10))
WALTZ_FOLLOW = pose(R(-30, 20), R(16, -14), L(30, 6, 0), L(-38, 0, -28), R(-26, 0, 10), R(22, 0, -10))
ZEPHYRUS_DRAW = [(0.0, WALTZ_DRAW), (0.3, WALTZ_DRAW)]  # (eased in from the last cut by its fadeIn)
ZEPHYRUS_SKEWER = [(0.0, WALTZ_DRAW), (0.07, WALTZ_SKEWER), (0.18, WALTZ_FOLLOW), (0.5, WALTZ_FOLLOW)]
BOREAS_CHOP = [(0.0, BOREAS_RAISE), (0.1, BOREAS_DOWN), (0.5, BOREAS_DOWN)]

# Spirit of Euros: the archer's stance again, drawn deeper and held longer;
# loosed, the drawing hand flies back.
EUROS_FULL = pose(R(-8, -74), R(4, 68), L(90, 44, -4), L(90, 72, 0), R(-20, 22, 8), R(20, 22, -6))
EUROS_RELEASE = pose(R(-4, -74), R(6, 68), L(84, 120, -6), L(92, 72, 0), R(-20, 22, 8), R(20, 22, -6))
EUROS_DRAW = [(0.0, STANCE), (0.25, BOW_AIM), (0.8, EUROS_FULL), (1.0, EUROS_FULL)]
EUROS_LOOSE = [(0.0, EUROS_FULL), (0.05, EUROS_RELEASE), (0.5, EUROS_RELEASE)]

# Saint Spirit of Zephyr (all in the air but the landing). A cut: the sword
# cocked over his left shoulder, then swept through them two-handed; it
# carries on past the strike (the follow-through), then he rebounds half
# way back, coiling for the next cut, so the dance never stops dead.
SAINT_COCK = pose(R(-8, 40), R(6, -30), L(110, 50, 10), L(100, 70, -10), R(-24, 0, 10), R(20, 0, -10))
SAINT_SWEEP = pose(R(-14, -45), R(8, 35), L(80, -60, 10), L(70, -40, -10), R(-30, 0, 12), R(26, 0, -12))
SAINT_SWEEP_OVER = pose(R(-18, -60), R(10, 44), L(76, -82, 12), L(66, -62, -10), R(-40, 0, 14), R(34, 0, -12))
SAINT_SWEEP_BACK = pose(R(-12, -24), R(6, 18), L(92, -28, 10), L(84, -14, -10), R(-26, 0, 10), R(22, 0, -10))
SAINT_COCK_OVER = pose(R(-10, 54), R(8, -40), L(114, 70, 10), L(104, 86, -10), R(-34, 0, 10), R(28, 0, -10))
SAINT_COCK_BACK = pose(R(-8, 24), R(4, -18), L(104, 30, 10), L(94, 46, -10), R(-22, 0, 10), R(18, 0, -10))
SAINT_CUT = [(0.0, SAINT_COCK_BACK), (0.055, SAINT_SWEEP), (0.12, SAINT_SWEEP_OVER), (0.24, SAINT_SWEEP_BACK),
             (0.34, SAINT_SWEEP_BACK)]  # (held till the next cut takes over)
# At his own star before the first cut: the sword drawn back, leaning in,
# coiling tighter as the charge builds.
SAINT_READY = pose(R(-14, 42), R(10, -32), L(112, 52, 10), L(102, 72, -10), R(-34, 0, 10), R(24, 0, -10))
SAINT_COILED = pose(R(-20, 50), R(14, -38), L(116, 62, 12), L(106, 82, -10), R(-44, 0, 10), R(30, 0, -10))
# And back the other way (every other cut).
SAINT_CUT_BACK = [(0.0, SAINT_SWEEP_BACK), (0.055, SAINT_COCK), (0.12, SAINT_COCK_OVER), (0.24, SAINT_COCK_BACK),
                  (0.34, SAINT_COCK_BACK)]
# Flying up beside them on the wind: arms back, chin up, legs together,
# the updraft lifting his arms and legs a little and letting them settle.
SAINT_SOAR = pose(R(14), R(-22), L(-20, 0, 35), L(-20, 0, -35), R(12, 0, 4), R(18, 0, -4))
SAINT_SOAR_LIFT = pose(R(18), R(-28), L(-32, 0, 46), L(-30, 0, -44), R(16, 0, 6), R(24, 0, -6))
SAINT_ASCEND = [(0.0, STANCE), (0.15, SAINT_SOAR), (0.6, SAINT_SOAR_LIFT), (1.2, SAINT_SOAR)]
SAINT_POISE = [(0.0, SAINT_SOAR), (0.16, SAINT_READY), (0.42, SAINT_COILED), (0.6, SAINT_COILED)]
# High above them, the blade raised in both hands, legs trailing; he arches
# back under its weight as it grows.
SAINT_RAISE = pose(R(10), R(-18), L(172, 6, 0), L(172, -6, 0), R(-8, 0, 6), R(16, 0, -6))
SAINT_ARCH = pose(R(17), R(-26), L(178, 6, 0), L(178, -6, 0), R(-4, 0, 8), R(22, 0, -8))
SAINT_RISE = [(0.0, SAINT_SWEEP), (0.12, SAINT_RAISE), (0.42, SAINT_ARCH), (0.75, SAINT_RAISE)]
# The strike: straight down, folding over it, past it, and back.
SAINT_DOWN = pose(R(-38), R(20), L(40, 6, 0), L(40, -6, 0), R(-40, 0, 8), R(10, 0, -8))
SAINT_DOWN_DEEP = pose(R(-50), R(26), L(26, 6, 0), L(26, -6, 0), R(-52, 0, 8), R(16, 0, -8))
SAINT_STRIKE = [(0.0, SAINT_RAISE), (0.07, SAINT_DOWN), (0.13, SAINT_DOWN_DEEP), (0.3, SAINT_DOWN)]
# Landed low, his back to them, the sword out to the side; he flicks the
# wind off it and glances back over his shoulder at them, then rises.
SAINT_KNEEL = pose(R(-20, 15), R(12, -10), L(40, 10, 50), L(25, 0, -25), R(-50, 0, 10), R(40, 0, -10))
SAINT_FLICK = pose(R(-16, 22), R(6, 38), L(52, 12, 72), L(25, 0, -28), R(-50, 0, 10), R(40, 0, -10))
SAINT_STAND = pose(R(-6, 12), R(4, -12), L(20, 6, 30), L(18, 0, -18), R(-8, 0, 6), R(8, 0, -6))
SAINT_LAND = [(0.0, SAINT_DOWN), (0.12, SAINT_KNEEL), (0.42, SAINT_FLICK), (0.68, SAINT_FLICK), (1.0, SAINT_STAND)]

# Tempest Dive: flying straight up, the right hand down holding them by the
# collar (they're below him, a little ahead), the left reaching for the sky.
DRAG = pose(R(4), R(22), L(15, 0, 4), L(172, -6, -10), R(-4), R(6))
TEMPEST_DRAG = [(0.0, DRAG), (0.75, DRAG)]

# Entrance: watching his grimoire come down to him (0.5), reaching up for it
# (1.0), then flinging his arm up as the wind bursts out (1.2), and settling
# into his stance.
ENTRANCE_LOOK = pose(R(4, 10), R(18, -10), L(20, 4, 10), L(100, 26, -6))
ENTRANCE_REACH = pose(R(6, 16), R(14, -16), L(16, 4, 12), L(130, 30, -10))
ENTRANCE_BURST = pose(R(10, -6), R(20, 6), L(168, -6, 14), L(60, 0, -60), R(-16, 0, 8), R(16, 0, -8))
ENTRANCE = [(0.0, STANCE), (0.5, ENTRANCE_LOOK), (1.0, ENTRANCE_REACH), (1.2, ENTRANCE_BURST), (1.6, ENTRANCE_BURST), (2.2, STANCE)]

# ---------------- Transformations ----------------
# Wind gathers as he draws in (0.3), Sylph merges into him on the burst
# (0.8), then he settles into his stance.
GATHER = pose(R(-16), R(-20), L(70, -44, 0), L(70, 44, 0), R(-18, 0, 8), R(18, 0, -8))
BURST = pose(R(10), R(22), L(140, 0, 46), L(140, 0, -46), R(-20, 0, 10), R(20, 0, -10))
AWAKEN = [(0.0, STANCE), (0.3, GATHER), (0.8, BURST), (1.1, BURST), (1.5, STANCE)]
ASCEND_BURST = pose(R(12), R(28), L(176, 0, 18), L(176, 0, -18), R(-22, 0, 10), R(22, 0, -10))
ASCEND = [(0.0, STANCE), (0.35, GATHER), (0.8, ASCEND_BURST), (1.15, ASCEND_BURST), (1.5, STANCE)]

SINE_IO = ('Sine', 'InOut'); QUAD_IN = ('Quad', 'In'); QUART_OUT = ('Quart', 'Out')
SINE_OUT = ('Sine', 'Out'); LINEAR = ('Linear', 'Out'); BACK_OUT = ('Back', 'Out')

def snap(n):
    """Wind-up then a snappy hit, then hold."""
    return [None, SINE_OUT, QUART_OUT] + [SINE_IO] * (n - 3)

SWING_EASE = [None, None, SINE_IO, QUAD_IN, QUART_OUT]

SPEC = {
    'Idle': dict(keys=IDLE, ease=[None, SINE_IO, SINE_IO], loop=True, delays={'Head': 0.12, 'RightArm': 0.1, 'LeftArm': 0.2},
                 doc="Standing: calm, turned a little, the left hand loose in front where the wind gathers."),
    'Run': dict(keys=RUN, ease=[None] + [LINEAR] * (len(RUN) - 1), loop=True, delays={'Head': 0.03, 'RightArm': 0.03, 'LeftArm': 0.03},
                doc="Moving: a light sprint, both arms swinging. Plays with the distance travelled (RUN_STRIDE studs a loop)."),
    'Walk': dict(keys=WALK, ease=[None] + [LINEAR] * (len(WALK) - 1), loop=True, delays={'Head': 0.03, 'RightArm': 0.03, 'LeftArm': 0.03},
                 doc="Moving slowly (casting, blocking): an easy walk, same phase as the run."),
    'Air': dict(keys=AIR, ease=[None], loop=True, doc="Jumping or falling: arms out on the wind, one knee up."),
    'HoverIdle': dict(keys=HOVER_IDLE, ease=[None, SINE_IO, SINE_IO], loop=True,
                      doc="Awakened: hovering on the wind, rising and settling slowly."),
    'HoverMove': dict(keys=HOVER_MOVE, ease=[None, SINE_IO, SINE_IO], loop=True,
                      doc="Awakened: gliding on the wind, leaning into it, legs swept back."),
    'Swipe1': dict(keys=SWIPE1, ease=SWING_EASE, additive=['RightLeg', 'LeftLeg'], fadeIn=SWING_TIMES[0], fadeOut=0.22,
                   events=[(SWING_TIMES[1], 'Strike')], doc="M1 1: the right hand swept across, a crescent of wind off it."),
    'Swipe2': dict(keys=SWIPE2, ease=SWING_EASE, additive=['RightLeg', 'LeftLeg'], fadeIn=SWING_TIMES[0], fadeOut=0.22,
                   events=[(SWING_TIMES[1], 'Strike')], doc="M1 2: the left hand back the other way."),
    'Swipe3': dict(keys=SWIPE3, ease=SWING_EASE, additive=['RightLeg', 'LeftLeg'], fadeIn=SWING_TIMES[0], fadeOut=0.22,
                   events=[(SWING_TIMES[1], 'Strike')], doc="M1 3: a rising swipe."),
    'GalePush': dict(keys=GALE_PUSH, ease=SWING_EASE, additive=['RightLeg', 'LeftLeg'], fadeIn=HEAVY_SWING_TIMES[0], fadeOut=0.28,
                     events=[(HEAVY_SWING_TIMES[1], 'Strike')], doc="Finisher: both palms driven out in a gale."),
    'GaleRise': dict(keys=GALE_RISE, ease=SWING_EASE, additive=['RightLeg', 'LeftLeg'], fadeIn=HEAVY_SWING_TIMES[0], fadeOut=0.28,
                     events=[(HEAVY_SWING_TIMES[1], 'Strike')], doc="Finisher (jump held): an updraft."),
    'GaleFall': dict(keys=GALE_FALL, ease=SWING_EASE, fadeIn=HEAVY_SWING_TIMES[0], fadeOut=0.28,
                     events=[(HEAVY_SWING_TIMES[1], 'Strike')], doc="Finisher (in the air): a downdraft, hands brought down like a hammer."),
    'Tornado': dict(keys=TORNADO, ease=[None, SINE_OUT, QUART_OUT, LINEAR], fadeOut=0.25, doc="Tornado: hand swung low across him, then swept up at it."),
    'TornadoAir': dict(keys=TORNADO_AIR, ease=[None, SINE_OUT, QUART_OUT, LINEAR], fadeOut=0.25, doc="Tornado in the air: the same, knees up."),
    'Shower': dict(keys=SHOWER, ease=[None, SINE_OUT, SINE_IO, QUART_OUT, SINE_IO], fadeOut=0.25, doc="Wind Blades Shower: hand to the sky, then down to send the blades."),
    'Hawk': dict(keys=HAWK, ease=snap(4), fadeOut=0.25, doc="Swift White Hawk: wound back, then the palm thrust out."),
    'Ark': dict(keys=ARK, ease=snap(4), fadeOut=0.3, doc="Heavenly Wind Ark: low and wide, then both arms sweep up."),
    'AirArk': dict(keys=AIR_ARK, ease=snap(4), fadeOut=0.3, doc="Heavenly Wind Ark in the air: both arms sweep down."),
    'Bow': dict(keys=BOW, ease=[None, SINE_OUT, SINE_IO, LINEAR], fadeOut=0.25, doc="Gale White Bow: archer's stance, held through the volley."),
    'Point': dict(keys=POINTING, ease=snap(3), fadeOut=0.2, doc="Points where a star goes (Saint Spirit of Zephyr's flick)."),
    'StormCharge': dict(keys=STORM_CHARGE, ease=[None, SINE_OUT, LINEAR], fadeOut=0.05, doc="Spirit Storm: palm out, mana gathering."),
    'StormFire': dict(keys=STORM_FIRE, ease=[None, QUART_OUT, LINEAR], fadeIn=0.02, fadeOut=0.3, doc="Spirit Storm: leaning into the beam."),
    'Scutum': dict(keys=SCUTUM, ease=[None, SINE_OUT, LINEAR], fadeOut=0.2, doc="Quartile Scutum: hands out, holding the barrier."),
    'NovaForm': dict(keys=NOVA_FORM, ease=[None, SINE_OUT, LINEAR], fadeIn=0.04, fadeOut=0.1, doc="Nova Vortex: the star forming over his open hand."),
    'NovaFlick': dict(keys=NOVA_FLICK, ease=[None, QUART_OUT, LINEAR], fadeIn=0.02, fadeOut=0.3, doc="Nova Vortex: the star flicked out, his body turning into it."),
    'NovaFormAir': dict(keys=NOVA_FORM_AIR, ease=[None, SINE_OUT, LINEAR], fadeIn=0.04, fadeOut=0.1, doc="Nova Vortex in the air: the star forming over his open hand, knees up."),
    'NovaFlickAir': dict(keys=NOVA_FLICK_AIR, ease=[None, QUART_OUT, LINEAR], fadeIn=0.02, fadeOut=0.3, doc="Nova Vortex in the air: the star flicked down at the ground."),
    'Notos': dict(keys=NOTOS, ease=snap(4), fadeOut=0.3, doc="Spirit of Notos: arms crossed, then flung wide."),
    'ZephyrusLunge': dict(keys=ZEPHYRUS_LUNGE, ease=[None, QUART_OUT, LINEAR], fadeIn=0.03, fadeOut=0.2, doc="Spirit of Zephyrus: the lunge, sword low and forward."),
    'ZephyrusThrust': dict(keys=ZEPHYRUS_THRUST, ease=[None, QUART_OUT, LINEAR], fadeIn=0.02, fadeOut=0.25, doc="Spirit of Zephyrus: the thrust through them."),
    'ZephyrusDraw': dict(keys=ZEPHYRUS_DRAW, ease=[None, LINEAR], fadeIn=0.1, fadeOut=0.1, doc="Spirit of Zephyrus: after the waltz, drawn back in front of them, sword low at the hip."),
    'ZephyrusSkewer': dict(keys=ZEPHYRUS_SKEWER, ease=[None, QUART_OUT, SINE_OUT, LINEAR], fadeIn=0.02, fadeOut=0.25, doc="Spirit of Zephyrus: the thrust in the air that runs them through."),
    'BoreasForm': dict(keys=BOREAS_FORM, ease=[None, SINE_OUT, LINEAR], fadeOut=0.05, doc="Tempest Dive: both hands raised over them at the top."),
    'BoreasChop': dict(keys=BOREAS_CHOP, ease=[None, QUAD_IN, LINEAR], fadeIn=0.01, fadeOut=0.3, doc="Tempest Dive: driving them down into the ground."),
    'EurosDraw': dict(keys=EUROS_DRAW, ease=[None, SINE_OUT, SINE_IO, LINEAR], fadeOut=0.05, doc="Spirit of Euros: drawn deep and held."),
    'EurosLoose': dict(keys=EUROS_LOOSE, ease=[None, QUART_OUT, LINEAR], fadeIn=0.01, fadeOut=0.3, doc="Spirit of Euros: loosed, the drawing hand flies back."),
    'SaintCut': dict(keys=SAINT_CUT, ease=[None, QUART_OUT, SINE_OUT, SINE_IO, LINEAR], fadeIn=0.03, fadeOut=0.1, doc="Saint Spirit of Zephyr: one two-handed cut through them (each star), carried past and rebounding."),
    'SaintCutBack': dict(keys=SAINT_CUT_BACK, ease=[None, QUART_OUT, SINE_OUT, SINE_IO, LINEAR], fadeIn=0.03, fadeOut=0.1, doc="Saint Spirit of Zephyr: the backhand cut (every other star), carried past and rebounding."),
    'SaintAscend': dict(keys=SAINT_ASCEND, ease=[None, SINE_OUT, SINE_IO, SINE_IO], fadeIn=0.05, fadeOut=0.1, doc="Saint Spirit of Zephyr: flying up beside them on the wind."),
    'SaintPoise': dict(keys=SAINT_POISE, ease=[None, SINE_OUT, SINE_IO, LINEAR], fadeIn=0.05, fadeOut=0.1, doc="Saint Spirit of Zephyr: at his star, the sword drawn back, leaning in to charge."),
    'SaintRise': dict(keys=SAINT_RISE, ease=[None, SINE_OUT, SINE_IO, SINE_IO], fadeIn=0.03, fadeOut=0.05, doc="Saint Spirit of Zephyr: the blade raised high above them."),
    'SaintStrike': dict(keys=SAINT_STRIKE, ease=[None, QUAD_IN, SINE_OUT, SINE_IO], fadeIn=0.01, fadeOut=0.1, doc="Saint Spirit of Zephyr: the one strike, straight down."),
    'SaintLand': dict(keys=SAINT_LAND, ease=[None, QUART_OUT, SINE_IO, LINEAR, SINE_IO], fadeIn=0.02, fadeOut=0.3, doc="Saint Spirit of Zephyr: landed low, his back to them, then up."),
    'TempestDrag': dict(keys=TEMPEST_DRAG, ease=[None, LINEAR], fadeIn=0.08, fadeOut=0.1, doc="Tempest Dive: flying straight up, dragging them by the collar."),
    'Entrance': dict(keys=ENTRANCE, ease=[None, SINE_IO, SINE_IO, QUART_OUT, LINEAR, SINE_IO], fadeOut=0.25, doc="Spawn entrance: his grimoire comes down to him, he reaches for it, the wind bursts out."),
    'Awaken': dict(keys=AWAKEN, ease=[None, SINE_OUT, BACK_OUT, LINEAR, SINE_IO], fadeOut=0.2, doc="Half-Crown: wind gathers, Sylph merges on the burst."),
    'Ascend': dict(keys=ASCEND, ease=[None, SINE_OUT, BACK_OUT, LINEAR, SINE_IO], fadeOut=0.2, doc="Full-Crown: the same, arms thrown to the sky."),
}

# Life for the spell casts: past each pose a little (the follow-through),
# eased back onto it, and through a long hold a slow breath, so nothing
# arrives dead and nothing stands frozen. Overshoot is a fraction of the
# move into the pose, carried on the same way.
def _beyond(a, b, k):
    out = {}
    for joint, value in b.items():
        prev = a.get(joint, value)
        if prev[0] != value[0] or len(prev) != len(value):
            out[joint] = value
            continue
        out[joint] = (value[0],) + tuple(_r(v + (v - p) * k) for p, v in zip(prev[1:], value[1:]))
    return out

def _breath(pose_, k):
    out = dict(pose_)
    for joint, (dx, dp) in {'Torso': (2, 0), 'Head': (-2, 0), 'RightArm': (0, 3), 'LeftArm': (0, 3)}.items():
        value = out.get(joint)
        if value and value[0] == 'rot':
            out[joint] = ('rot', _r(value[1] + dx * k), value[2], value[3])
        elif value and value[0] == 'limb':
            out[joint] = ('limb', _r(value[1] + dp * k), value[2], value[3])
    return out

SINE_IO_ = ('Sine', 'InOut'); SINE_OUT_ = ('Sine', 'Out')
def lively(spec, k=0.14):
    keys, ease = list(spec['keys']), list(spec['ease'])
    # The pose it settles in: the last one before the final hold.
    last = len(keys) - 1
    held = last > 0 and keys[last][1] == keys[last - 1][1]
    i = last - 1 if held else last
    if i < 1:
        return
    t, pose_ = keys[i][0], keys[i][1]
    end = keys[last][0]
    room = end - t
    over = _beyond(keys[i - 1][1], pose_, k)
    added = []
    if room >= 0.12:
        added.append((t + min(0.07, room * 0.3), over, SINE_OUT_))
        added.append((t + min(0.2, room * 0.7), pose_, SINE_IO_))
    if held and room >= 0.6:
        mid = t + 0.2 + (room - 0.2) / 2
        added.append((mid, _breath(pose_, 1), SINE_IO_))
    if not added:
        return
    tail = keys[i + 1:]
    tail_ease = ease[i + 1:]
    keys = keys[:i + 1] + [(a[0], a[1]) for a in added] + tail
    ease = ease[:i + 1] + [a[2] for a in added] + [SINE_IO_ if held else e for e in tail_ease]
    spec['keys'], spec['ease'] = keys, ease

for _name in ('Shower', 'Hawk', 'Ark', 'AirArk', 'Bow', 'Point', 'StormCharge', 'StormFire', 'Scutum',
              'NovaForm', 'NovaFlick', 'NovaFormAir', 'NovaFlickAir', 'Notos', 'ZephyrusLunge', 'ZephyrusThrust',
              'BoreasForm', 'BoreasChop', 'EurosDraw', 'EurosLoose', 'TempestDrag'):
    lively(SPEC[_name])

# Played in the air (not planted, feet not checked); the run sets its own height.
AIRBORNE = {'Air', 'AirArk', 'GaleFall', 'TornadoAir', 'TempestDrag', 'NovaFormAir', 'NovaFlickAir', 'HoverIdle', 'HoverMove', 'SaintCut', 'SaintCutBack', 'SaintAscend', 'SaintPoise', 'SaintRise', 'SaintStrike', 'ZephyrusDraw', 'ZephyrusSkewer'}
OWN_HEIGHT = {'Run'}
ALL = {name: spec['keys'] if name in AIRBORNE or name in OWN_HEIGHT else plant(spec['keys']) for name, spec in SPEC.items()}

def verify(name, keys):
    problems = []
    poses = [pose_cfs(k[1]) for k in keys]
    for i, (k, pm) in enumerate(zip(keys, poses)):
        sole_check(pm, f"{name}@{k[0]:.2f}", problems)
        if i + 1 < len(keys):
            for t in (0.25, 0.5, 0.75):
                sole_check(lerp_pose(pm, poses[i + 1], t), f"{name}@{k[0]:.2f}+{t}", problems, 0.16)
    for p in problems:
        print("   !!", name, p)
    return not problems

def emit(path):
    from compact import write
    write(path, ['Torso', 'Head', 'RightArm', 'LeftArm', 'RightLeg', 'LeftLeg'],
          [(name, spec, ALL[name]) for name, spec in SPEC.items()])

if __name__ == '__main__':
    if len(sys.argv) > 1:
        emit(sys.argv[1])
    else:
        print("RUN_STRIDE", RUN_STRIDE, "WALK_STRIDE", WALK_STRIDE)
        ok = True
        for name, keys in ALL.items():
            if name not in AIRBORNE:
                ok &= verify(name, keys)
        print("ALL CLEAN" if ok else "PROBLEMS FOUND")
