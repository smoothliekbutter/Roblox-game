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

# Conjunction: points where the star goes (0.12); arrives low and poised.
POINT = pose(R(-4, -10), R(6, 10), L(104, 14, 4), L(20, 0, -18), R(-10, 0, 6), R(12, 0, -6))
CONJUNCTION = [(0.0, STANCE), (0.12, POINT), (0.4, POINT)]
ARRIVE = pose(R(-16, 10), R(10, -8), L(30, 0, 40), L(30, 0, -40), R(-22, 0, 12), R(22, 0, -12))
WARP = [(0.0, ARRIVE), (0.35, STANCE)]

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

# Quartile Hasta: left hand conducting the stars overhead, right pointing
# the way (0.2 to 0.5); the beam goes and he rocks back.
HASTA_AIM = pose(R(-4, -12), R(6, 10), L(92, 10, 0), L(150, -10, -22), R(-16, 0, 8), R(16, 0, -8))
HASTA_KICK = pose(R(6, -8), R(10, 6), L(100, 8, 0), L(140, -10, -26), R(-18, 0, 8), R(18, 0, -8))
HASTA_STARS = [(0.0, STANCE), (0.2, HASTA_AIM), (1.0, HASTA_AIM)]  # held through a tapped barrage
# Held: leaning into the beam he keeps on them.
HASTA_PUSH = pose(R(-8, -12), R(8, 10), L(94, 8, 0), L(140, -10, -26), R(-20, 0, 8), R(20, 0, -8))
HASTA_BEAM = [(0.0, HASTA_AIM), (0.1, HASTA_PUSH), (2.0, HASTA_PUSH)]
# In the air: both hands down at the ground, calling the star-fire down on it.
HASTA_CALL = pose(R(-10), R(-14), L(40, 10, 20), L(40, -10, -20), R(14), R(-8))
HASTA_RAIN = [(0.0, AIR[0][1]), (0.15, HASTA_CALL), (1.2, HASTA_CALL)]
HASTA_FIRE = [(0.0, HASTA_AIM), (0.05, HASTA_KICK), (0.45, HASTA_KICK)]

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
BOREAS_CHOP = [(0.0, BOREAS_RAISE), (0.1, BOREAS_DOWN), (0.5, BOREAS_DOWN)]

# Spirit of Euros: the archer's stance again, drawn deeper and held longer;
# loosed, the drawing hand flies back.
EUROS_FULL = pose(R(-8, -74), R(4, 68), L(90, 44, -4), L(90, 72, 0), R(-20, 22, 8), R(20, 22, -6))
EUROS_RELEASE = pose(R(-4, -74), R(6, 68), L(84, 120, -6), L(92, 72, 0), R(-20, 22, 8), R(20, 22, -6))
EUROS_DRAW = [(0.0, STANCE), (0.25, BOW_AIM), (0.8, EUROS_FULL), (1.0, EUROS_FULL)]
EUROS_LOOSE = [(0.0, EUROS_FULL), (0.05, EUROS_RELEASE), (0.5, EUROS_RELEASE)]

# Saint Spirit of Zephyr (all in the air but the landing). A cut: the sword
# cocked over his left shoulder, then swept through them two-handed.
SAINT_COCK = pose(R(-8, 40), R(6, -30), L(110, 50, 10), L(100, 70, -10), R(-24, 0, 10), R(20, 0, -10))
SAINT_SWEEP = pose(R(-14, -45), R(8, 35), L(80, -60, 10), L(70, -40, -10), R(-30, 0, 12), R(26, 0, -12))
SAINT_CUT = [(0.0, SAINT_COCK), (0.06, SAINT_SWEEP), (0.25, SAINT_SWEEP)]
# At his own star before the first cut: the sword drawn back, leaning in.
SAINT_READY = pose(R(-14, 42), R(10, -32), L(112, 52, 10), L(102, 72, -10), R(-34, 0, 10), R(24, 0, -10))
# And back the other way (every other cut).
SAINT_CUT_BACK = [(0.0, SAINT_SWEEP), (0.06, SAINT_COCK), (0.25, SAINT_COCK)]
# Flying up beside them on the wind: arms back, chin up, legs together.
SAINT_SOAR = pose(R(14), R(-22), L(-20, 0, 35), L(-20, 0, -35), R(12, 0, 4), R(18, 0, -4))
SAINT_ASCEND = [(0.0, STANCE), (0.15, SAINT_SOAR), (1.2, SAINT_SOAR)]
SAINT_POISE = [(0.0, SAINT_SOAR), (0.16, SAINT_READY), (0.6, SAINT_READY)]
# High above them, the blade raised in both hands, legs trailing.
SAINT_RAISE = pose(R(10), R(-18), L(172, 6, 0), L(172, -6, 0), R(-8, 0, 6), R(16, 0, -6))
SAINT_RISE = [(0.0, SAINT_SWEEP), (0.12, SAINT_RAISE), (0.75, SAINT_RAISE)]
# The strike: straight down, folding over it.
SAINT_DOWN = pose(R(-38), R(20), L(40, 6, 0), L(40, -6, 0), R(-40, 0, 8), R(10, 0, -8))
SAINT_STRIKE = [(0.0, SAINT_RAISE), (0.08, SAINT_DOWN), (0.2, SAINT_DOWN)]
# Landed low, his back to them, the sword out to the side.
SAINT_KNEEL = pose(R(-20, 15), R(12, -10), L(40, 10, 50), L(25, 0, -25), R(-50, 0, 10), R(40, 0, -10))
SAINT_STAND = pose(R(-6, 12), R(4, -12), L(20, 6, 30), L(18, 0, -18), R(-8, 0, 6), R(8, 0, -6))
SAINT_LAND = [(0.0, SAINT_DOWN), (0.12, SAINT_KNEEL), (0.6, SAINT_KNEEL), (1.0, SAINT_STAND)]

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
    'Shower': dict(keys=SHOWER, ease=[None, SINE_OUT, SINE_IO, QUART_OUT, SINE_IO], fadeOut=0.25, doc="Wind Blades Shower: hand to the sky, then down to send the blades."),
    'Hawk': dict(keys=HAWK, ease=snap(4), fadeOut=0.25, doc="Swift White Hawk: wound back, then the palm thrust out."),
    'Ark': dict(keys=ARK, ease=snap(4), fadeOut=0.3, doc="Heavenly Wind Ark: low and wide, then both arms sweep up."),
    'AirArk': dict(keys=AIR_ARK, ease=snap(4), fadeOut=0.3, doc="Heavenly Wind Ark in the air: both arms sweep down."),
    'Bow': dict(keys=BOW, ease=[None, SINE_OUT, SINE_IO, LINEAR], fadeOut=0.25, doc="Gale White Bow: archer's stance, held through the volley."),
    'Conjunction': dict(keys=CONJUNCTION, ease=snap(3), fadeOut=0.2, doc="Conjunction: points where the star goes."),
    'Warp': dict(keys=WARP, ease=[None, SINE_OUT], fadeIn=0.01, doc="Conjunction: arriving at the star, low and poised."),
    'StormCharge': dict(keys=STORM_CHARGE, ease=[None, SINE_OUT, LINEAR], fadeOut=0.05, doc="Spirit Storm: palm out, mana gathering."),
    'StormFire': dict(keys=STORM_FIRE, ease=[None, QUART_OUT, LINEAR], fadeIn=0.02, fadeOut=0.3, doc="Spirit Storm: leaning into the beam."),
    'Scutum': dict(keys=SCUTUM, ease=[None, SINE_OUT, LINEAR], fadeOut=0.2, doc="Quartile Scutum: hands out, holding the barrier."),
    'HastaStars': dict(keys=HASTA_STARS, ease=[None, SINE_OUT, LINEAR], fadeOut=0.05, doc="Quartile Hasta: conducting the four stars."),
    'HastaBeam': dict(keys=HASTA_BEAM, ease=[None, QUART_OUT, LINEAR], fadeIn=0.03, fadeOut=0.3, doc="Quartile Hasta held: leaning into the beam."),
    'HastaRain': dict(keys=HASTA_RAIN, ease=[None, SINE_OUT, LINEAR], fadeOut=0.25, doc="Quartile Hasta in the air: hands down, calling the star-fire down."),
    'HastaFire': dict(keys=HASTA_FIRE, ease=[None, QUART_OUT, SINE_OUT], fadeIn=0.02, fadeOut=0.3, doc="Quartile Hasta: the lance goes, he rocks back."),
    'Notos': dict(keys=NOTOS, ease=snap(4), fadeOut=0.3, doc="Spirit of Notos: arms crossed, then flung wide."),
    'ZephyrusLunge': dict(keys=ZEPHYRUS_LUNGE, ease=[None, QUART_OUT, LINEAR], fadeIn=0.03, fadeOut=0.2, doc="Spirit of Zephyrus: the lunge, sword low and forward."),
    'ZephyrusThrust': dict(keys=ZEPHYRUS_THRUST, ease=[None, QUART_OUT, LINEAR], fadeIn=0.02, fadeOut=0.25, doc="Spirit of Zephyrus: the thrust through them."),
    'BoreasForm': dict(keys=BOREAS_FORM, ease=[None, SINE_OUT, LINEAR], fadeOut=0.05, doc="Tempest Dive: both hands raised over them at the top."),
    'BoreasChop': dict(keys=BOREAS_CHOP, ease=[None, QUAD_IN, LINEAR], fadeIn=0.01, fadeOut=0.3, doc="Tempest Dive: driving them down into the ground."),
    'EurosDraw': dict(keys=EUROS_DRAW, ease=[None, SINE_OUT, SINE_IO, LINEAR], fadeOut=0.05, doc="Spirit of Euros: drawn deep and held."),
    'EurosLoose': dict(keys=EUROS_LOOSE, ease=[None, QUART_OUT, LINEAR], fadeIn=0.01, fadeOut=0.3, doc="Spirit of Euros: loosed, the drawing hand flies back."),
    'SaintCut': dict(keys=SAINT_CUT, ease=[None, QUART_OUT, LINEAR], fadeIn=0.03, fadeOut=0.1, doc="Saint Spirit of Zephyr: one two-handed cut through them (each star)."),
    'SaintCutBack': dict(keys=SAINT_CUT_BACK, ease=[None, QUART_OUT, LINEAR], fadeIn=0.03, fadeOut=0.1, doc="Saint Spirit of Zephyr: the backhand cut (every other star)."),
    'SaintAscend': dict(keys=SAINT_ASCEND, ease=[None, SINE_OUT, LINEAR], fadeIn=0.05, fadeOut=0.1, doc="Saint Spirit of Zephyr: flying up beside them on the wind."),
    'SaintPoise': dict(keys=SAINT_POISE, ease=[None, SINE_OUT, LINEAR], fadeIn=0.05, fadeOut=0.1, doc="Saint Spirit of Zephyr: at his star, the sword drawn back, leaning in to charge."),
    'SaintRise': dict(keys=SAINT_RISE, ease=[None, SINE_OUT, LINEAR], fadeIn=0.03, fadeOut=0.05, doc="Saint Spirit of Zephyr: the blade raised high above them."),
    'SaintStrike': dict(keys=SAINT_STRIKE, ease=[None, QUAD_IN, LINEAR], fadeIn=0.01, fadeOut=0.1, doc="Saint Spirit of Zephyr: the one strike, straight down."),
    'SaintLand': dict(keys=SAINT_LAND, ease=[None, QUART_OUT, LINEAR, SINE_IO], fadeIn=0.02, fadeOut=0.3, doc="Saint Spirit of Zephyr: landed low, his back to them, then up."),
    'TempestDrag': dict(keys=TEMPEST_DRAG, ease=[None, LINEAR], fadeIn=0.08, fadeOut=0.1, doc="Tempest Dive: flying straight up, dragging them by the collar."),
    'Entrance': dict(keys=ENTRANCE, ease=[None, SINE_IO, SINE_IO, QUART_OUT, LINEAR, SINE_IO], fadeOut=0.25, doc="Spawn entrance: his grimoire comes down to him, he reaches for it, the wind bursts out."),
    'Awaken': dict(keys=AWAKEN, ease=[None, SINE_OUT, BACK_OUT, LINEAR, SINE_IO], fadeOut=0.2, doc="Half-Crown: wind gathers, Sylph merges on the burst."),
    'Ascend': dict(keys=ASCEND, ease=[None, SINE_OUT, BACK_OUT, LINEAR, SINE_IO], fadeOut=0.2, doc="Full-Crown: the same, arms thrown to the sky."),
}

# Played in the air (not planted, feet not checked); the run sets its own height.
AIRBORNE = {'Air', 'AirArk', 'TempestDrag', 'HastaRain', 'HoverIdle', 'HoverMove', 'SaintCut', 'SaintCutBack', 'SaintAscend', 'SaintPoise', 'SaintRise', 'SaintStrike'}
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

def num(v):
    s = ("%.3f" % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s

def value(v):
    kind, *args = v
    while len(args) > (2 if kind == 'body' else 1) and args[-1] == 0:
        args = args[:-1]
    return f"{kind}({', '.join(num(a) for a in args)})"

ORDER = ['Torso', 'Head', 'RightArm', 'LeftArm', 'RightLeg', 'LeftLeg']

def emit(path):
    out = ['''--[[
	Prince of Wind (Yuno) animation data.

	GENERATED by tools/anim/yuno_anims.py (feet checked against an R6 model
	of the rig at every keyframe and in between). Edit the Python and re-run
	it instead of editing this file by hand.

	Each animation: keys = { {time, pose, easingStyle?, easingDirection?}, ... }
	  rot(x, y, z)          torso/head/leg rotation (degrees)
	  body(dy, x, y, z)     torso lowered/raised dy studs, then rotated
	  limb(pitch, yaw, roll) arm/leg aim (degrees)
]]

local rad = math.rad

local function rot(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

local function body(dy: number, x: number, y: number?, z: number?): CFrame
	return CFrame.new(0, dy, 0) * CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

local function limb(pitch: number, yaw: number?, roll: number?): CFrame
	return CFrame.Angles(0, rad(yaw or 0), 0) * CFrame.Angles(0, 0, rad(roll or 0)) * CFrame.Angles(rad(pitch), 0, 0)
end

local Animations = {}
''']
    for name, spec in SPEC.items():
        keys = ALL[name]
        out.append(f"-- {spec['doc']}")
        out.append(f"Animations.{name} = {{")
        if spec.get('loop'): out.append("\tloop = true,")
        if 'fadeIn' in spec: out.append(f"\tfadeIn = {num(spec['fadeIn'])},")
        if 'fadeOut' in spec: out.append(f"\tfadeOut = {num(spec['fadeOut'])},")
        if spec.get('delays'):
            out.append("\tdelays = { " + ", ".join(f"{k} = {num(v)}" for k, v in spec['delays'].items()) + " },")
        out.append("\tkeys = {")
        assert len(spec['ease']) == len(keys), name
        for (t, p), ease in zip(keys, spec['ease']):
            out.append("\t\t{")
            out.append(f"\t\t\t{num(t)},")
            out.append("\t\t\t{")
            for k in ORDER:
                if k in p:
                    out.append(f"\t\t\t\t{k} = {value(p[k])},")
            out.append("\t\t\t},")
            if ease:
                out.append(f'\t\t\t"{ease[0]}",')
                out.append(f'\t\t\t"{ease[1]}",')
            out.append("\t\t},")
        out.append("\t},")
        out.append("}\n")
    out.append("return Animations\n")
    open(path, 'w').write("\n".join(out))
    print("wrote", path)

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
