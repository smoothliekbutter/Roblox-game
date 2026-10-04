import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from design import *

def R(x,y=0,z=0): return ('rot',x,y,z)
def L(p,y=0,r=0): return ('limb',p,y,r)
def A(x,y,z): return ('aim',x,y,z)

def torso_dir(torso_rot, d):
    """Express a torso-relative blade direction in character space (so the
    sword stays on the shoulder however the torso is turned)."""
    M = rot(*torso_rot[1:])[:3,:3]
    v = M @ np.array(d, float); v /= np.linalg.norm(v)
    return ('aim', *[round(float(c), 3) for c in v])

# Blade over the right shoulder (torso space), angled out and back so it
# stays clear of the face from any camera angle (1.35 studs from the head).
SHOULDER = (0.28, 0.39, 0.88)
REST_ARM = L(85, 25, 10)

# ---------------- Idle ----------------
def idle_key(torso, head, arm_pitch, larm, rleg, lleg):
    t = R(*torso)
    return {'Torso': t, 'Head': R(*head), 'RightArm': L(arm_pitch, 25, 10),
            'Sword': torso_dir(t, SHOULDER), 'LeftArm': larm, 'RightLeg': rleg, 'LeftLeg': lleg}

# Breathing in and out over 2.6s, with the head glancing around a little.
IDLE = [
    (0.0, idle_key((-6,-18), (5,16), 85, L(10,0,-14), R(-6,0,9), R(12,0,-10))),
    (1.3, idle_key((-2,-18), (2,22), 89, L(13,0,-16), R(-6,0,9), R(12,0,-10))),
    (2.6, idle_key((-6,-18), (5,16), 85, L(10,0,-14), R(-6,0,9), R(12,0,-10))),
]

# Run and walk cycles. The phase follows the distance travelled (RUN_STRIDE
# and WALK_STRIDE studs per loop, see Kit.Idle), so the feet stay planted at
# any speed. Leg angles are against the leaning torso: a leg's angle in the
# world is its own minus the lean, so the strides below swing evenly about
# straight down. The free arm swings against the legs and the shoulders turn
# with it; the head stays level and looking ahead. (Planting the feet drops
# the body when the legs are apart, which gives the bob.)
def run_key(torso, head, arm_pitch, larm, rleg, lleg):
    t = R(*torso)
    return {'Torso': t, 'Head': R(*head), 'RightArm': L(arm_pitch, 25, 10),
            'Sword': torso_dir(t, SHOULDER), 'LeftArm': larm, 'RightLeg': R(rleg), 'LeftLeg': R(lleg)}

# Sprint: leaning in hard, legs 46 degrees either side of straight down in
# the world (lean 22), the sword steady on the shoulder.
RUN_LEAN, RUN_SWING = 22, 46
RUN_STRIDE = round(2 * 2 * 2 * __import__('math').sin(__import__('math').radians(RUN_SWING)), 2)
RUN = [
    (0.0, run_key((-RUN_LEAN, -8), (16, 8), 84, L(58, -6, -8), RUN_SWING + RUN_LEAN, -RUN_SWING + RUN_LEAN)),
    (0.1, run_key((-RUN_LEAN - 2, 0), (18, 0), 88, L(8, -4, -10), RUN_LEAN - 2, RUN_LEAN + 8)),
    (0.2, run_key((-RUN_LEAN, 8), (16, -8), 84, L(-42, 4, -12), -RUN_SWING + RUN_LEAN, RUN_SWING + RUN_LEAN)),
    (0.3, run_key((-RUN_LEAN - 2, 0), (18, 0), 88, L(8, -4, -10), RUN_LEAN + 8, RUN_LEAN - 2)),
    (0.4, run_key((-RUN_LEAN, -8), (16, 8), 84, L(58, -6, -8), RUN_SWING + RUN_LEAN, -RUN_SWING + RUN_LEAN)),
]

# Walk (when slowed: attacking, blocking, casting): upright, shorter steps,
# same leg phase as the run so the two blend into each other.
WALK_LEAN, WALK_SWING = 6, 32
WALK_STRIDE = round(2 * 2 * 2 * __import__('math').sin(__import__('math').radians(WALK_SWING)), 2)
WALK = [
    (0.00, run_key((-WALK_LEAN, -4), (4, 4), 86, L(28, -6, -6), WALK_SWING + WALK_LEAN, -WALK_SWING + WALK_LEAN)),
    (0.15, run_key((-WALK_LEAN + 1, 0), (3, 0), 87, L(4, -4, -8), WALK_LEAN + 2, WALK_LEAN + 6)),
    (0.30, run_key((-WALK_LEAN, 4), (4, -4), 86, L(-20, 2, -10), -WALK_SWING + WALK_LEAN, WALK_SWING + WALK_LEAN)),
    (0.45, run_key((-WALK_LEAN + 1, 0), (3, 0), 87, L(4, -4, -8), WALK_LEAN + 6, WALK_LEAN + 2)),
    (0.60, run_key((-WALK_LEAN, -4), (4, 4), 86, L(28, -6, -6), WALK_SWING + WALK_LEAN, -WALK_SWING + WALK_LEAN)),
]

# In the air (jumping or falling): knee up, free arm out for balance.
AIR = [
    (0.0, {'Torso': R(-6), 'Head': R(6), 'RightArm': REST_ARM, 'Sword': A(*SHOULDER),
           'LeftArm': L(35, 0, -40), 'RightLeg': R(30), 'LeftLeg': R(-12)}),
]

# ---------------- M1 swings ----------------
READY = IDLE[0][1]

LEGS = lambda y: {'RightLeg': R(0,y,0), 'LeftLeg': R(0,y,0)}  # additive counter-twist

# (Wind-up, through, strike, settle.) Config.M1's swing timings match these.
SWING_TIMES = (0.1, 0.15, 0.21, 0.4)
HEAVY_SWING_TIMES = (0.14, 0.21, 0.28, 0.52)

def swing(windup, through, strike, settle, heavy=False):
    t = HEAVY_SWING_TIMES if heavy else SWING_TIMES
    # Held in the wind-up while the clip fades in (its fadeIn is t[0], see
    # emit.py): the body flows straight from wherever the last swing left
    # it into this wind-up, with no detour back through the idle pose, and
    # the swing then starts from rest. Legs are layered on the stance.
    return [(0.0, windup), (t[0], windup), (t[1], through), (t[2], strike), (t[3], settle)]

SLASH1 = swing(
    {'Torso': R(3,-42), 'Head': R(0,32), 'RightArm': L(80,-100), 'Sword': A(0.75,0.25,0.6), 'LeftArm': L(40,-25), **LEGS(40)},
    {'Torso': R(-4,-5), 'Head': R(0,4), 'RightArm': L(85,-20), 'Sword': A(0.35,0.05,-0.94), 'LeftArm': L(30,-25), **LEGS(5)},
    {'Torso': R(-8,38), 'Head': R(0,-28), 'RightArm': L(82,70), 'Sword': A(-0.9,-0.1,-0.35), 'LeftArm': L(20,-40), **LEGS(-36)},
    {'Torso': R(-6,28), 'Head': R(0,-20), 'RightArm': L(70,55), 'Sword': A(-0.75,-0.35,-0.5), 'LeftArm': L(25,-35), **LEGS(-26)},
)
SLASH2 = swing(
    {'Torso': R(3,35), 'Head': R(0,-28), 'RightArm': L(82,80), 'Sword': A(-0.8,0.2,0.5), 'LeftArm': L(35,-10), **LEGS(-34)},
    {'Torso': R(-4,0), 'Head': R(0,-2), 'RightArm': L(85,10), 'Sword': A(-0.3,0.05,-0.95), 'LeftArm': L(35,-25), **LEGS(0)},
    {'Torso': R(-8,-38), 'Head': R(0,28), 'RightArm': L(80,-85), 'Sword': A(0.95,-0.1,-0.25), 'LeftArm': L(40,-30), **LEGS(36)},
    {'Torso': R(-6,-26), 'Head': R(0,18), 'RightArm': L(72,-65), 'Sword': A(0.75,-0.35,-0.45), 'LeftArm': L(38,-28), **LEGS(24)},
)
SLASH3 = swing(
    {'Torso': R(-14,-25), 'Head': R(10,18), 'RightArm': L(25,-40), 'Sword': A(0.45,-0.35,-0.8), 'LeftArm': L(45,-20), **LEGS(22)},
    {'Torso': R(-3,0), 'Head': R(0,0), 'RightArm': L(85,-5), 'Sword': A(0.1,0.3,-0.95), 'LeftArm': L(35,-20), **LEGS(0)},
    {'Torso': R(10,28), 'Head': R(-10,-15), 'RightArm': L(150,30), 'Sword': A(-0.45,0.85,-0.25), 'LeftArm': L(20,-20), **LEGS(-26)},
    {'Torso': R(6,20), 'Head': R(-6,-10), 'RightArm': L(135,25), 'Sword': A(-0.35,0.8,0.45), 'LeftArm': L(25,-22), **LEGS(-18)},
)
CLEAVE = swing(
    {'Torso': R(4,-60), 'Head': R(0,40), 'RightArm': L(80,-120), 'Sword': A(0.45,0.2,0.85), 'LeftArm': L(65,-30), **LEGS(55)},
    {'Torso': R(-4,-10), 'Head': R(0,8), 'RightArm': L(85,-20), 'Sword': A(0.4,0.05,-0.9), 'LeftArm': L(45,-35), **LEGS(8)},
    {'Torso': R(-12,62), 'Head': R(0,-42), 'RightArm': L(80,95), 'Sword': A(-0.85,-0.05,0.5), 'LeftArm': L(15,-45), **LEGS(-58)},
    {'Torso': R(-10,50), 'Head': R(0,-34), 'RightArm': L(72,80), 'Sword': A(-0.7,-0.35,0.6), 'LeftArm': L(22,-40), **LEGS(-46)},
    heavy=True,
)
RISING = swing(
    {'Torso': R(-22,-15), 'Head': R(14,10), 'RightArm': L(15,-25), 'Sword': A(0.45,-0.3,-0.84), 'LeftArm': L(70,-25), 'RightLeg': R(-10,15), 'LeftLeg': R(15,15)},
    {'Torso': R(-8,0), 'Head': R(2,0), 'RightArm': L(80,0), 'Sword': A(0.05,0.45,-0.9), 'LeftArm': L(50,-25), 'RightLeg': R(-5,0), 'LeftLeg': R(5,0)},
    {'Torso': R(15,15), 'Head': R(-20,-10), 'RightArm': L(175,10), 'Sword': A(0.05,1,0.1), 'LeftArm': L(30,-20), 'RightLeg': R(0,-15), 'LeftLeg': R(0,-15)},
    {'Torso': R(10,10), 'Head': R(-14,-8), 'RightArm': L(160,10), 'Sword': A(0.05,0.8,0.6), 'LeftArm': L(32,-20), 'RightLeg': R(0,-10), 'LeftLeg': R(0,-10)},
    heavy=True,
)
CHOP = swing(
    {'Torso': R(20), 'Head': R(-12), 'RightArm': L(175,8), 'LeftArm': L(170,-8), 'Sword': A(0,0.55,0.83)},
    {'Torso': R(0), 'Head': R(0), 'RightArm': L(115,8), 'LeftArm': L(110,-8), 'Sword': A(0,0.75,-0.65)},
    {'Torso': R(-35), 'Head': R(18), 'RightArm': L(40,8), 'LeftArm': L(45,-8), 'Sword': A(0,-0.3,-0.95)},
    {'Torso': R(-28), 'Head': R(14), 'RightArm': L(48,8), 'LeftArm': L(52,-8), 'Sword': A(0,-0.36,-0.93)},
    heavy=True,
)

# ---------------- Entrance ----------------
CROUCH = {'Torso': R(-28), 'Head': R(22), 'RightArm': L(-12,0,28), 'LeftArm': L(-12,0,-28),
          'RightLeg': R(-22,0,8), 'LeftLeg': R(34,0,-6), 'Sword': A(0,-1,0.2)}
RISE = {'Torso': R(-10,10), 'Head': R(-4,-28), 'RightArm': L(15,0,18), 'LeftArm': L(75,-40),
        'RightLeg': R(-10,0,8), 'LeftLeg': R(14,0,-8), 'Sword': A(0,-1,0.2)}
REACH = {'Torso': R(-8,32), 'Head': R(0,-20), 'RightArm': L(82,72), 'LeftArm': L(70,-45),
         'RightLeg': R(-8,-25,8), 'LeftLeg': R(12,-25,-8), 'Sword': A(-0.95,0,-0.3)}
DRAW = {'Torso': R(4,-20), 'Head': R(-8,15), 'RightArm': L(150,-55), 'LeftArm': L(25,0,-30),
        'RightLeg': R(-8,15,8), 'LeftLeg': R(12,15,-8), 'Sword': A(0.6,0.8,0)}
def twirl(d): return {'Torso': R(4,0), 'Head': R(-12,0), 'RightArm': L(172,0), 'LeftArm': L(25,0,-30),
                      'RightLeg': R(-6,0,8), 'LeftLeg': R(10,0,-8), 'Sword': A(*d)}
SLAM_UP = {'Torso': R(16), 'Head': R(-10), 'RightArm': L(175,6), 'LeftArm': L(168,-6),
           'RightLeg': R(-12,0,6), 'LeftLeg': R(18,0,-6), 'Sword': A(0,0.5,0.86)}
SLAM = {'Torso': R(-30,5), 'Head': R(12), 'RightArm': L(52,8), 'LeftArm': L(48,-8),
        'RightLeg': R(-25,0,8), 'LeftLeg': R(32,0,-6), 'Sword': A(0,-0.42,-0.91)}
PLANTED = {'Torso': R(-20,8), 'Head': R(-12,-5), 'RightArm': L(55,8), 'LeftArm': L(15,0,-20),
           'RightLeg': R(-18,0,8), 'LeftLeg': R(25,0,-6), 'Sword': A(0,-0.45,-0.89)}

ENTRANCE = [
    (0.00, CROUCH),
    (0.30, CROUCH),
    (0.62, RISE),
    (0.88, REACH),
    (1.05, DRAW),
    (1.13, twirl((0.95,0.2,-0.2))),
    (1.21, twirl((0.2,0.2,0.95))),
    (1.29, twirl((-0.95,0.2,0.2))),
    (1.37, twirl((-0.2,0.2,-0.95))),
    (1.45, twirl((0.95,0.2,-0.2))),
    (1.58, SLAM_UP),
    (1.70, SLAM),
    (2.05, PLANTED),
    (2.45, IDLE[0][1]),
]

# ---------------- Dashes (0.28s) ----------------
# Body leans into the dash; the sword trails behind the movement.
UPPER = {k: v for k, v in READY.items() if k not in ('RightLeg', 'LeftLeg')}

def dash(pose):
    return [(0.0, UPPER), (0.06, pose), (0.26, pose)]

DASH_FRONT = dash({'Torso': R(-28, 6), 'Head': R(20, -4), 'RightArm': L(-25, 0, 20), 'Sword': A(0.2, -0.2, 0.96),
                   'LeftArm': L(30, -20), 'RightLeg': R(-32), 'LeftLeg': R(36)})
DASH_BACK = dash({'Torso': R(14), 'Head': R(-6), 'RightArm': L(70, 25), 'Sword': A(0.15, 0.4, -0.9),
                  'LeftArm': L(-20, 0, -25), 'RightLeg': R(26), 'LeftLeg': R(-8)})
DASH_LEFT = dash({'Torso': R(-8, 15, 14), 'Head': R(4, -12), 'RightArm': L(35, -35, 20), 'Sword': A(0.9, -0.1, 0.42),
                  'LeftArm': L(10, 0, -60), 'RightLeg': R(0, 0, 24), 'LeftLeg': R(0, 0, -6)})
DASH_RIGHT = dash({'Torso': R(-8, -15, -14), 'Head': R(4, 12), 'RightArm': L(55, -45, 30), 'Sword': A(-0.85, -0.1, 0.52),
                   'LeftArm': L(15, 0, -35), 'RightLeg': R(0, 0, 6), 'LeftLeg': R(0, 0, -24)})

# ---------------- Getting hit ----------------
def shoulder(torso, jolt=(0, 0, 0)):
    d = np.array(SHOULDER) + np.array(jolt)
    return torso_dir(torso, tuple(d / np.linalg.norm(d)))

def flinch(torso, head, rarm, larm, jolt):
    t = R(*torso)
    return {'Torso': t, 'Head': R(*head), 'RightArm': rarm, 'Sword': shoulder(t, jolt), 'LeftArm': larm,
            'RightLeg': R(-6), 'LeftLeg': R(6)}

def recover(torso, head):
    t = R(*torso)
    return {'Torso': t, 'Head': R(*head), 'RightArm': L(84, 25, 10), 'Sword': shoulder(t), 'LeftArm': L(12, 0, -18),
            'RightLeg': R(-2), 'LeftLeg': R(2)}

FLINCH_A = [(0.0, UPPER | {'RightLeg': R(0), 'LeftLeg': R(0)}),
            (0.05, flinch((14, 14, 5), (-20, 18), L(70, 35, 25), L(20, 0, -40), (0.2, 0.05, 0))),
            (0.30, recover((5, 4), (-6, 6)))]
FLINCH_B = [(0.0, UPPER | {'RightLeg': R(0), 'LeftLeg': R(0)}),
            (0.05, flinch((14, -14, -5), (-20, -18), L(78, 15, 0), L(35, 0, -25), (-0.1, 0.1, 0))),
            (0.30, recover((5, -4), (-6, -6)))]
FLINCH_BACK = [(0.0, UPPER | {'RightLeg': R(0), 'LeftLeg': R(0)}),
               (0.05, flinch((-16, 0), (18, 0), L(95, 25, 10), L(-20, 0, -25), (0, -0.1, 0.1))),
               (0.30, recover((-5, 0), (6, 0)))]
HIT_HEAVY = [(0.0, UPPER | {'RightLeg': R(0), 'LeftLeg': R(0)}),
             (0.06, {'Torso': R(26), 'Head': R(-35), 'RightArm': L(110, 30, 30), 'Sword': A(0.3, 0.8, 0.5),
                     'LeftArm': L(60, 0, -50), 'RightLeg': R(20), 'LeftLeg': R(-12)}),
             (0.50, recover((8, 0), (-10, 0)))]

# Blocking: sword held across the chest, free hand bracing it.
GUARD_POSE = {'Torso': R(-6, 10), 'Head': R(8, -6), 'RightArm': L(80, 45), 'Sword': A(-0.9, 0.35, -0.25),
              'LeftArm': L(85, -25)}
GUARD_PUSHED = {'Torso': R(6, 14), 'Head': R(-6, -10), 'RightArm': L(68, 50), 'Sword': A(-0.85, 0.5, -0.15),
                'LeftArm': L(72, -20)}
GUARD = [(0.0, UPPER), (0.08, GUARD_POSE), (60.0, GUARD_POSE)]
GUARD_HIT = [(0.0, GUARD_POSE), (0.05, GUARD_PUSHED), (0.2, GUARD_POSE), (60.0, GUARD_POSE)]

# Guard broken / parried: thrown off balance, arms flung up.
STAGGER_POSE = {'Torso': R(20, -10), 'Head': R(-25, 8), 'RightArm': L(140, 20, 20), 'Sword': A(0.2, 0.9, 0.35),
                'LeftArm': L(120, -20, -30), 'RightLeg': R(16), 'LeftLeg': R(-14)}
STAGGER = [(0.0, UPPER | {'RightLeg': R(0), 'LeftLeg': R(0)}), (0.08, STAGGER_POSE), (1.0, STAGGER_POSE),
           (1.3, recover((4, 0), (-4, 0)))]

# ---------------- Bull Thrust ----------------
# Propel: low and long, sword thrust straight ahead, free arm back.
PROPEL_POSE = {'Torso': R(-30, 10), 'Head': R(22, -8), 'RightArm': L(60, 5), 'Sword': A(0, -0.05, -1),
               'LeftArm': L(-35, 0, -25), 'RightLeg': R(-52), 'LeftLeg': R(42)}
PROPEL = [(0.0, UPPER), (0.07, PROPEL_POSE), (0.62, PROPEL_POSE)]

# The combo once he's caught someone: five hits, each its own swing with a
# wind-up and a follow-through. A rising cut from low right to high left, a
# backhand across the waist, a full turn that brings the blade round through
# them, a two-handed overhead chop, then a beat coiled with the sword drawn
# back at his hip before the thrust that drives them away.
# The server lands each hit on its strike key: keep COMBO_STRIKES in step
# with COMBO in Server/Kits/AntiMagic.
COMBO_STRIKES = (0.14, 0.30, 0.54, 0.76, 1.10)
S1, S2, S3, S4, S5 = COMBO_STRIKES

# 1: the blade dropped low behind him on the right, then up through them.
B_RISE_WIND = {'Torso': R(-24, -40), 'Head': R(14, 32), 'RightArm': L(30, -62, 8), 'Sword': A(0.62, -0.28, 0.73),
               'LeftArm': L(70, -15), 'RightLeg': R(-46, 30), 'LeftLeg': R(38, 30)}
B_RISE = {'Torso': R(-8, 16), 'Head': R(6, -12), 'RightArm': L(105, 20), 'Sword': A(-0.42, 0.5, -0.76),
          'LeftArm': L(30, -25), 'RightLeg': R(-32, -14), 'LeftLeg': R(28, -14)}
B_RISE_FOLLOW = {'Torso': R(2, 30), 'Head': R(-2, -22), 'RightArm': L(148, 32), 'Sword': A(-0.55, 0.8, 0.1),
                 'LeftArm': L(25, -30), 'RightLeg': R(-28, -24), 'LeftLeg': R(26, -24)}
# 2: down to his left at the waist, then a backhand across to the right.
B_SWEEP_WIND = {'Torso': R(-8, 42), 'Head': R(2, -32), 'RightArm': L(84, 80), 'Sword': A(-0.85, 0.08, 0.52),
                'LeftArm': L(-15, 0, -35), 'RightLeg': R(-26, -38), 'LeftLeg': R(28, -38)}
B_SWEEP = {'Torso': R(-12, -14), 'Head': R(6, 10), 'RightArm': L(86, -36), 'Sword': A(0.5, -0.06, -0.86),
           'LeftArm': L(30, 0, -45), 'RightLeg': R(-28, 14), 'LeftLeg': R(28, 14)}
B_SWEEP_FOLLOW = {'Torso': R(-12, -62), 'Head': R(6, 45), 'RightArm': L(86, -88), 'Sword': A(0.95, -0.1, 0.25),
                  'LeftArm': L(40, 0, -40), 'RightLeg': R(-24, 50), 'LeftLeg': R(24, 50)}
# 3: the backhand carries on into a full turn to the right, blade held out,
# and comes round through them side-on. Keyed in steps under 180 degrees so
# it turns the long way round.
def b_spin(yaw):
    t = R(-12, yaw)
    return {'Torso': t, 'Head': R(6), 'RightArm': L(84, -92), 'Sword': torso_dir(t, (0.96, -0.14, -0.22)),
            'LeftArm': L(30, 0, -20), 'RightLeg': R(-14), 'LeftLeg': R(14)}
B_SPIN = {'Torso': R(-14, 90), 'Head': R(6, -60), 'RightArm': L(86, -108), 'Sword': A(0.4, -0.12, -0.91),
          'LeftArm': L(60, 0, -60), 'RightLeg': R(-26), 'LeftLeg': R(24)}
B_SPIN_FOLLOW = {'Torso': R(-12, 40), 'Head': R(6, -30), 'RightArm': L(84, -110), 'Sword': A(0.9, -0.15, -0.4),
                 'LeftArm': L(50, 0, -60), 'RightLeg': R(-26, -30), 'LeftLeg': R(24, -30)}
# 4: both hands up, the blade laid back over his head, then straight down
# through them and on toward the ground.
B_CHOP_WIND = {'Torso': R(16, 6), 'Head': R(-10, -4), 'RightArm': L(172, 10, 14), 'Sword': A(-0.05, 0.5, 0.86),
               'LeftArm': L(168, -10, -14), 'RightLeg': R(-14, -6), 'LeftLeg': R(18, -6)}
B_CHOP = {'Torso': R(-12, 8), 'Head': R(12, -6), 'RightArm': L(100, 30, 6), 'Sword': A(-0.12, -0.28, -0.95),
          'LeftArm': L(104, -16, -6), 'RightLeg': R(-30, -8), 'LeftLeg': R(28, -8)}
B_CHOP_FOLLOW = {'Torso': R(-28, 8), 'Head': R(16, -6), 'RightArm': L(56, 30, 6), 'Sword': A(-0.15, -0.25, -0.96),
                 'LeftArm': L(60, -16, -6), 'RightLeg': R(-36, -8), 'LeftLeg': R(32, -8)}
# 5: sword drawn back at the hip, point level, free hand sighting along it;
# he sinks into it for a beat, then everything goes behind the point.
B_COIL = {'Torso': R(-12, -20), 'Head': R(10, 16), 'RightArm': L(-15, -20), 'Sword': A(0.03, 0.06, -1),
          'LeftArm': L(88, 10), 'RightLeg': R(-34, 20), 'LeftLeg': R(32, 20)}
B_HOLD = {'Torso': R(-14, -22), 'Head': R(12, 18), 'RightArm': L(-20, -20), 'Sword': A(0.03, 0.06, -1),
          'LeftArm': L(90, 10), 'RightLeg': R(-36, 22), 'LeftLeg': R(34, 22)}
B_THRUST = {'Torso': R(-22, 16), 'Head': R(16, -12), 'RightArm': L(88, 6), 'Sword': A(-0.08, -0.03, -1),
            'LeftArm': L(-30, 0, -30), 'RightLeg': R(-52), 'LeftLeg': R(40)}
B_THRUST_FOLLOW = {'Torso': R(-24, 18), 'Head': R(18, -12), 'RightArm': L(86, 8), 'Sword': A(-0.08, -0.05, -1),
                   'LeftArm': L(-34, 0, -32), 'RightLeg': R(-54), 'LeftLeg': R(42)}
B_SETTLE = {'Torso': R(-14, 4), 'Head': R(10, -2), 'RightArm': L(68, 5), 'Sword': A(0.12, -0.32, -0.94),
            'LeftArm': L(15, 0, -25), 'RightLeg': R(-36), 'LeftLeg': R(30)}
BULL_COMBO = [(0.0, PROPEL_POSE),
              (S1 - 0.06, B_RISE_WIND), (S1, B_RISE), (S1 + 0.04, B_RISE_FOLLOW),
              (S2 - 0.06, B_SWEEP_WIND), (S2, B_SWEEP), (S2 + 0.05, B_SWEEP_FOLLOW),
              (S3 - 0.10, b_spin(-145)), (S3 - 0.05, b_spin(-220)), (S3, B_SPIN), (S3 + 0.06, B_SPIN_FOLLOW),
              (S4 - 0.07, B_CHOP_WIND), (S4, B_CHOP), (S4 + 0.06, B_CHOP_FOLLOW),
              (S5 - 0.18, B_COIL), (S5 - 0.06, B_HOLD), (S5, B_THRUST), (S5 + 0.09, B_THRUST_FOLLOW),
              (S5 + 0.38, B_SETTLE)]
# When each swing gets going (the client traces its crescent from here),
# the coil, and the thrust leaving the hip.
COMBO_EVENTS = [(S1 - 0.04, 'Rising'), (S2 - 0.04, 'Sweep'), (S3 - 0.14, 'Spin'), (S4 - 0.05, 'Chop'),
                (S5 - 0.16, 'Coil'), (S5 - 0.05, 'Thrust')]

# ---------------- Black Meteorite (grab, rise, slam) ----------------
M_LUNGE = {'Torso': R(-28, -8), 'Head': R(22, 6), 'RightArm': L(-15, -10, 30), 'Sword': A(0.3, 0.15, 0.94),
           'LeftArm': L(95, -8), 'RightLeg': R(-48), 'LeftLeg': R(40)}
# The grab: his free hand clamps on their throat, then he hoists them up.
SEIZE_CLAMP = {'Torso': R(-10, 12), 'Head': R(6, -8), 'RightArm': L(-20, -10, 30), 'Sword': A(0.3, 0.2, 0.93),
               'LeftArm': L(100, -8), 'RightLeg': R(-38), 'LeftLeg': R(32)}
SEIZE_LIFT = {'Torso': R(-4, 14), 'Head': R(-4, -10), 'RightArm': L(-15, -10, 32), 'Sword': A(0.3, 0.25, 0.92),
              'LeftArm': L(120, -8), 'RightLeg': R(-24), 'LeftLeg': R(24)}
SEIZE = [(0.0, M_LUNGE), (0.08, SEIZE_CLAMP), (0.3, SEIZE_LIFT), (0.45, SEIZE_LIFT)]
# Still holding them up in front through the rise.
M_HOLD = {'Torso': R(-12, 10), 'Head': R(8, -6), 'RightArm': L(-10, -10, 30), 'Sword': A(0.3, 0.2, 0.93),
          'LeftArm': L(122, -6), 'RightLeg': R(-10), 'LeftLeg': R(12)}
M_RISE = {'Torso': R(14, 5), 'Head': R(-12), 'RightArm': L(165, 15), 'Sword': A(0.15, 0.55, 0.82),
          'LeftArm': L(108, -5), 'RightLeg': R(-25), 'LeftLeg': R(35)}
M_APEX = {'Torso': R(24), 'Head': R(-18), 'RightArm': L(178, 10), 'Sword': A(0.1, 0.2, 0.97),
          'LeftArm': L(100, -5), 'RightLeg': R(-15), 'LeftLeg': R(30)}
M_SLAM = {'Torso': R(-38), 'Head': R(18), 'RightArm': L(40, 8), 'Sword': A(0, -0.32, -0.95),
          'LeftArm': L(50, -10), 'RightLeg': R(-28), 'LeftLeg': R(30)}
M_RECOVER = {'Torso': R(-20), 'Head': R(8), 'RightArm': L(55, 8), 'Sword': A(0, -0.4, -0.92),
             'LeftArm': L(25, 0, -25), 'RightLeg': R(-40), 'LeftLeg': R(34)}
# Black Moon's lunge grab.
METEOR_LUNGE = [(0.0, UPPER), (0.07, M_LUNGE), (0.35, M_LUNGE)]
# Black Meteorite's grab: no dash. He plants, the free hand draws back past
# his hip with the left shoulder turned away, then shoots out for their
# throat on a half-step. It stays open a moment, then (if nobody was there)
# he sags into the overreach, which is also where the Seize starts from.
# The server checks for someone to seize from the thrust key: keep REACH_AT
# in step with REACH_STARTUP in Server/Kits/AntiMagic.
REACH_AT = 0.16
R_COCK = {'Torso': R(-12, 24), 'Head': R(10, -20), 'RightArm': L(-12, -10, 28), 'Sword': A(0.3, 0.15, 0.94),
          'LeftArm': L(-20, 0, -30), 'RightLeg': R(-14, -22), 'LeftLeg': R(16, -22)}
R_THRUST = {'Torso': R(-20, -16), 'Head': R(12, 12), 'RightArm': L(-18, -10, 32), 'Sword': A(0.3, 0.15, 0.94),
            'LeftArm': L(116, -4), 'RightLeg': R(-44, 8), 'LeftLeg': R(36, 8)}
R_OPEN = {'Torso': R(-22, -14), 'Head': R(14, 10), 'RightArm': L(-16, -10, 30), 'Sword': A(0.3, 0.15, 0.94),
          'LeftArm': L(112, -6), 'RightLeg': R(-46, 6), 'LeftLeg': R(38, 6)}
METEOR_REACH = [(0.0, UPPER), (REACH_AT - 0.07, R_COCK), (REACH_AT, R_THRUST), (0.3, R_OPEN), (0.5, M_LUNGE),
                (0.75, M_LUNGE)]
METEOR_RISE = [(0.0, M_HOLD), (0.2, M_RISE), (0.55, M_APEX)]
# The vortex: whirling round with them held out at arm's length, leaning
# back against the pull, sword swept out wide in the other hand, legs
# kicking as he bobs; at the end the sword comes up overhead for the slam.
def m_spin(lean, kick, twist, lift):
    t = R(lean, twist)
    return {'Torso': t, 'Head': R(-6, -6 - twist * 0.5), 'RightArm': L(86 + lift, -84),
            'Sword': torso_dir(t, (0.97, -0.06 + lift * 0.02, 0.2)),
            'LeftArm': L(100 - lift * 0.3, -6), 'RightLeg': R(24 + kick), 'LeftLeg': R(-10 - kick)}
# The head-first dive (the body is turned upside down by the path, so this
# is the pose in his own frame): streamlined, legs together, holding them
# out in front by the throat, the sword trailing along his legs like a fin.
DRILL = {'Torso': R(0), 'Head': R(-12), 'RightArm': L(8, -10, 8), 'Sword': A(0.05, -1, 0.1),
         'LeftArm': L(95, -6), 'RightLeg': R(2), 'LeftLeg': R(-2)}
# Rolling back over after the impact: tucked up tight, then landing in a
# crouch with the blade down.
M_TUCK = {'Torso': R(22), 'Head': R(-10), 'RightArm': L(30, -25), 'Sword': A(0.45, -0.55, 0.7),
          'LeftArm': L(55, 10, -10), 'RightLeg': R(78), 'LeftLeg': R(66)}
METEOR_DRILL = [(0.0, M_APEX), (0.14, DRILL), (1.2, DRILL)]
METEOR_LAND = [(0.0, DRILL), (0.1, M_TUCK), (0.24, plant_pose(M_RECOVER)), (0.55, plant_pose(M_RECOVER))]
METEOR_SPIN = [(0.0, M_HOLD), (0.14, m_spin(12, 0, 6, 0)), (0.34, m_spin(18, 16, 18, 10)),
               (0.54, m_spin(12, -8, 4, -2)), (0.74, m_spin(18, 14, 16, 12)), (0.94, M_RISE), (1.2, M_APEX)]
METEOR_SLAM = [(0.0, M_APEX), (0.12, M_SLAM), (0.6, M_SLAM)]
METEOR_IMPACT = [(0.0, M_SLAM), (0.25, M_RECOVER), (0.5, M_RECOVER)]

# ---------------- Black Divider (charge, release) ----------------
LEGS_TWIST = lambda y: {'RightLeg': R(0, y), 'LeftLeg': R(0, y)}
def d_charge(twist, lean):
    return {'Torso': R(lean, twist), 'Head': R(0, -twist * 0.75), 'RightArm': L(-40, -35), 'Sword': A(0.55, -0.14, 0.8),
            'LeftArm': L(80, -30), **LEGS_TWIST(-twist * 0.95)}
D_THROUGH = {'Torso': R(-6, 5), 'Head': R(0, -4), 'RightArm': L(86, -10), 'Sword': A(0.3, 0, -0.95),
             'LeftArm': L(40, -35), **LEGS_TWIST(-5)}
D_STRIKE = {'Torso': R(-12, 60), 'Head': R(0, -45), 'RightArm': L(84, 95), 'Sword': A(-0.8, -0.05, 0.6),
            'LeftArm': L(15, -45), **LEGS_TWIST(-55)}
D_SETTLE = {'Torso': R(-10, 48), 'Head': R(0, -36), 'RightArm': L(75, 78), 'Sword': A(-0.7, -0.35, 0.6),
            'LeftArm': L(22, -40), **LEGS_TWIST(-44)}
DIVIDER_CHARGE = [(0.0, UPPER | LEGS_TWIST(0)), (0.15, d_charge(-50, 6)), (0.3, d_charge(-53, 8)),
                  (0.45, d_charge(-49, 5)), (0.62, d_charge(-54, 9))]
DIVIDER_RELEASE = [(0.0, d_charge(-54, 9)), (0.05, D_THROUGH), (0.11, D_STRIKE), (0.42, D_SETTLE)]

# ---------------- Anti-Magic Deflect ----------------
F_STANCE = {'Torso': R(-6, 12), 'Head': R(8, -8), 'RightArm': L(40, 40), 'Sword': A(-0.1, 0.97, -0.2),
            'LeftArm': L(70, -10), 'RightLeg': R(-10), 'LeftLeg': R(12)}
F_WIND = {'Torso': R(-4, 30), 'Head': R(4, -20), 'RightArm': L(150, 50), 'Sword': A(-0.5, 0.75, 0.4),
          'LeftArm': L(50, -10), 'RightLeg': R(-10), 'LeftLeg': R(12)}
F_COUNTER = {'Torso': R(-12, -45), 'Head': R(4, 35), 'RightArm': L(55, -95), 'Sword': A(0.85, -0.3, 0.4),
             'LeftArm': L(20, 0, -40), 'RightLeg': R(-14, 30), 'LeftLeg': R(16, 30)}
F_R_WIND = {'Torso': R(-6, 40), 'Head': R(4, -30), 'RightArm': L(84, 85), 'Sword': A(-0.9, 0.1, 0.35),
            'LeftArm': L(45, -20), 'RightLeg': R(-10, -30), 'LeftLeg': R(12, -30)}
F_R_STRIKE = {'Torso': R(-14, -40), 'Head': R(6, 30), 'RightArm': L(84, -90), 'Sword': A(0.9, 0.05, -0.4),
              'LeftArm': L(20, 0, -45), 'RightLeg': R(-10, 30), 'LeftLeg': R(12, 30)}
DEFLECT_STANCE = [(0.0, UPPER), (0.08, F_STANCE), (0.82, F_STANCE)]
DEFLECT_COUNTER = [(0.0, F_STANCE), (0.06, F_WIND), (0.13, F_COUNTER), (0.42, F_COUNTER)]
DEFLECT_REFLECT = [(0.0, F_STANCE), (0.08, F_R_WIND), (0.15, F_R_STRIKE), (0.42, F_R_STRIKE)]

# ---------------- Awakening: Black Form ----------------
def a_gather(lean, twist):
    return {'Torso': R(lean, twist), 'Head': R(25, -twist), 'RightArm': L(40, 10), 'Sword': A(0, -0.42, -0.91),
            'LeftArm': L(60, -55), 'RightLeg': R(-32), 'LeftLeg': R(34)}
A_ROAR = {'Torso': R(22), 'Head': R(-30), 'RightArm': L(40, -10, 70), 'Sword': A(0.85, 0.45, 0.25),
          'LeftArm': L(40, 10, -75), 'RightLeg': R(-12, 0, 10), 'LeftLeg': R(14, 0, -10)}
A_STANCE = {'Torso': R(-12, -15), 'Head': R(8, 12), 'RightArm': L(70, 5), 'Sword': A(0.2, -0.3, -0.93),
            'LeftArm': L(20, 0, -25), 'RightLeg': R(-8, 0, 9), 'LeftLeg': R(12, 0, -10)}
AWAKEN = [(0.0, UPPER | {'RightLeg': R(0), 'LeftLeg': R(0)}), (0.25, a_gather(-32, 0)), (0.45, a_gather(-30, 3)),
          (0.65, a_gather(-34, -3)), (0.85, a_gather(-33, 0)), (0.95, A_ROAR), (1.4, A_ROAR), (1.7, A_STANCE),
          (2.0, A_STANCE)]

# ---------------- Grabbed (held up by the throat) ----------------
# Head thrown back, free hand clawing at the grip, legs kicking. Written out
# as one long clip (tracks don't loop); the grab fades it out on release.
def grabbed(kick, arch):
    return {'Torso': R(10 + arch), 'Head': R(-26 - arch), 'RightArm': L(22, 0, 16), 'Sword': A(0.25, -0.35, -0.9),
            'LeftArm': L(150 + arch * 2, 14, -6), 'RightLeg': R(14 * kick), 'LeftLeg': R(-12 * kick)}
GRABBED = [(0.0, grabbed(0, 0))]
for i in range(1, 15):
    GRABBED.append((round(i * 0.18, 2), grabbed(1 if i % 2 else -1, 3 if i % 2 else 0)))

# ---------------- Special (R): Anti-Magic Leap / Meteor Plunge ----------------
# Leap: a coiled crouch, then he launches, free arm reaching ahead, sword
# trailing behind him.
LEAP_CROUCH = {'Torso': R(-28, 6), 'Head': R(20, -4), 'RightArm': L(-25, 0, 22), 'Sword': A(0.3, -0.15, 0.94),
               'LeftArm': L(-20, 0, -25), 'RightLeg': R(42), 'LeftLeg': R(-30)}
LEAP_LAUNCH = {'Torso': R(-12, -4), 'Head': R(6), 'RightArm': L(-45, 0, 25), 'Sword': A(0.25, -0.3, 0.92),
               'LeftArm': L(150, -10), 'RightLeg': R(-40), 'LeftLeg': R(32)}
LEAP = [(0.0, UPPER), (0.08, LEAP_CROUCH), (0.2, LEAP_LAUNCH), (0.6, LEAP_LAUNCH)]

# Plunge: curls up in the air with the sword raised behind his head, then
# dives head-first behind it like a spear, and stabs it into the ground.
P_WIND = {'Torso': R(14), 'Head': R(-10), 'RightArm': L(172, 5), 'Sword': A(0.05, 0.35, 0.94),
          'LeftArm': L(60, -20, -25), 'RightLeg': R(45), 'LeftLeg': R(25)}
P_DIVE = {'Torso': R(-50), 'Head': R(30), 'RightArm': L(75, 4), 'Sword': A(0, -0.72, -0.69),
          'LeftArm': L(-30, 0, -30), 'RightLeg': R(-20), 'LeftLeg': R(-5)}
P_STAB = {'Torso': R(-30, 8), 'Head': R(20, -6), 'RightArm': L(55, 4), 'Sword': A(0, -0.5, -0.87),
          'LeftArm': L(15, 0, -40), 'RightLeg': R(44), 'LeftLeg': R(-38)}
P_SETTLE = {'Torso': R(-22, 8), 'Head': R(14, -6), 'RightArm': L(62, 4), 'Sword': A(0, -0.5, -0.87),
            'LeftArm': L(10, 0, -35), 'RightLeg': R(30), 'LeftLeg': R(-26)}
PLUNGE = [(0.0, UPPER | {'RightLeg': R(10), 'LeftLeg': R(-5)}), (0.12, P_WIND), (0.22, P_DIVE), (0.9, P_DIVE)]
# Starts from the stab: by the time it plays he has hit the ground.
PLUNGE_IMPACT = [(0.0, P_STAB), (0.1, P_STAB), (0.45, P_SETTLE)]

# ---------------- Air Black Divider ----------------
# Hangs in the air with the sword cocked overhead, then a front flip that
# carries the blade in a full circle and ends pointing down at the target.
def ad_charge(lean):
    return {'Torso': R(lean), 'Head': R(-6), 'RightArm': L(168, -15), 'Sword': A(0.15, -0.1, 0.98),
            'LeftArm': L(70, -30, -20), 'RightLeg': R(48), 'LeftLeg': R(24)}
def flip(pitch):
    t = R(pitch)
    return {'Torso': t, 'Head': R(12), 'RightArm': L(172, 0), 'Sword': torso_dir(t, (0, 0.95, -0.31)),
            'LeftArm': L(140, -10, -15), 'RightLeg': R(60), 'LeftLeg': R(50)}
AD_END = {'Torso': R(-30), 'Head': R(18), 'RightArm': L(62, 4), 'Sword': A(0, -0.6, -0.8),
          'LeftArm': L(20, 0, -35), 'RightLeg': R(22), 'LeftLeg': R(-12)}
AIR_DIVIDER_CHARGE = [(0.0, UPPER), (0.15, ad_charge(12)), (0.3, ad_charge(16)), (0.45, ad_charge(11)),
                      (0.62, ad_charge(17))]
AIR_DIVIDER_RELEASE = [(0.0, ad_charge(17)), (0.05, flip(-70)), (0.1, flip(-180)), (0.15, flip(-280)),
                       (0.2, AD_END), (0.45, AD_END)]

# ---------------- Air versions of the base moves ----------------
# Air Bull Thrust: a diving spear, pitched down along the dive with the
# blade out in front and the legs streaming behind.
AP_POSE = {'Torso': R(-48, 6), 'Head': R(34, -4), 'RightArm': L(70, 4), 'Sword': A(0, -0.5, -0.87),
           'LeftArm': L(-40, 0, -30), 'RightLeg': R(-14), 'LeftLeg': R(-30)}
AIR_PROPEL = [(0.0, UPPER), (0.07, AP_POSE), (0.62, AP_POSE)]
# Air lunge grab (Black Moon used in the air): swoops in hand-first. The air
# Seize then hangs on to their throat with the legs dangling.
AM_LUNGE = M_LUNGE | {'Torso': R(-36, -8), 'Head': R(28, 6), 'RightLeg': R(-16), 'LeftLeg': R(-30)}
AS_CLAMP = SEIZE_CLAMP | {'RightLeg': R(-22), 'LeftLeg': R(8)}
AS_LIFT = SEIZE_LIFT | {'RightLeg': R(-10), 'LeftLeg': R(16)}
AIR_METEOR_LUNGE = [(0.0, UPPER), (0.07, AM_LUNGE), (0.35, AM_LUNGE)]
AIR_SEIZE = [(0.0, AM_LUNGE), (0.08, AS_CLAMP), (0.3, AS_LIFT), (0.45, AS_LIFT)]
# The air reach: the same thrust while he hangs there, legs dangling,
# sagging into the swoop pose the air Seize starts from.
AR_COCK = R_COCK | {'RightLeg': R(16, -20), 'LeftLeg': R(-8, -20)}
AR_THRUST = R_THRUST | {'Torso': R(-22, -16), 'RightLeg': R(-14, 8), 'LeftLeg': R(12, 8)}
AR_OPEN = R_OPEN | {'Torso': R(-26, -14), 'RightLeg': R(-16, 6), 'LeftLeg': R(6, 6)}
AIR_METEOR_REACH = [(0.0, UPPER), (REACH_AT - 0.07, AR_COCK), (REACH_AT, AR_THRUST), (0.3, AR_OPEN),
                    (0.5, AM_LUNGE), (0.75, AM_LUNGE)]
# Air Deflect: the same guard, knees tucked up under him.
AF_STANCE = F_STANCE | {'RightLeg': R(42), 'LeftLeg': R(18)}
AIR_DEFLECT_STANCE = [(0.0, UPPER), (0.08, AF_STANCE), (0.82, AF_STANCE)]

# ---------------- Black Moon (Black Form 4): the cutscene ----------------
# Throw: dips with them, then heaves them straight up into the sky.
THROW_DIP = {'Torso': R(-16, 10), 'Head': R(10, -6), 'RightArm': L(-20, -10, 30), 'Sword': A(0.3, 0.2, 0.93),
             'LeftArm': L(85, -6), 'RightLeg': R(-42), 'LeftLeg': R(36)}
THROW_HEAVE = {'Torso': R(14, -4), 'Head': R(-28), 'RightArm': L(-10, -10, 30), 'Sword': A(0.3, 0.3, 0.9),
               'LeftArm': L(178, -4), 'RightLeg': R(-22), 'LeftLeg': R(20)}
THROW_WATCH = {'Torso': R(10, -4), 'Head': R(-34), 'RightArm': L(-8, -10, 30), 'Sword': A(0.3, 0.3, 0.9),
               'LeftArm': L(160, -4), 'RightLeg': R(-20), 'LeftLeg': R(18)}
THROW_FOLLOW = {'Torso': R(12, -6), 'Head': R(-40), 'RightArm': L(-6, -10, 30), 'Sword': A(0.3, 0.3, 0.9),
                'LeftArm': L(150, -4), 'RightLeg': R(-20), 'LeftLeg': R(18)}
MOON_THROW = [(0.0, SEIZE_LIFT), (0.09, THROW_DIP), (0.18, THROW_HEAVE), (0.6, THROW_WATCH), (1.0, THROW_FOLLOW)]

# Perched in the sky in front of the moon: turned side-on, the sword hanging
# low out at his right side, one knee up, glaring at them. Breathes while he
# waits.
def perch(lean, arm):
    return {'Torso': R(lean, -30), 'Head': R(-10, 24), 'RightArm': L(arm, -5, 26), 'Sword': A(0.62, -0.75, 0.1),
            'LeftArm': L(22, 0, -28), 'RightLeg': R(-14), 'LeftLeg': R(44)}
# Then he levels the sword at them: a challenge across the sky.
def point(lean):
    return {'Torso': R(lean, 6), 'Head': R(-8, -4), 'RightArm': L(98, 8), 'Sword': A(0.05, 0.22, -0.97),
            'LeftArm': L(18, 0, -30), 'RightLeg': R(-14), 'LeftLeg': R(40)}
MOON_PERCH = [(0.0, LEAP_LAUNCH), (0.15, perch(-6, 38)), (0.5, perch(-8, 34)), (0.85, perch(-6, 38)),
              (1.2, perch(-8, 34)), (1.5, point(-4)), (1.95, point(-6)), (2.35, point(-4))]

# The flight: flat out, the sword drawn across to his left, then one
# backhand cut through them that carries on round to his right. He stops
# past them with his back to them: sword arm out at his side, the blade
# flicked down and back, glancing back over his shoulder at them. A beat
# after the cut lands he swings the sword up and back onto his shoulder.
# Timed against Shared/BlackMoon: the clip starts at Times.Fly, he passes
# through them at Times.Cut (0.15s in), and the client holds the clip still
# for 0.1s right there, so the cut lands (Times.Land) 1.05s into it. Keep
# MOON_CUT_AT and MOON_LANDS in step with those times.
MOON_CUT_AT = 0.14
MOON_LANDS = 1.05
FLIGHT_COCK = {'Torso': R(-46, 32), 'Head': R(28, -26), 'RightArm': L(80, 80), 'Sword': A(-0.72, 0.12, 0.68),
               'LeftArm': L(-25, 0, -35), 'RightLeg': R(-35), 'LeftLeg': R(-10)}
FLIGHT_CUT = {'Torso': R(-36, -8), 'Head': R(18, 6), 'RightArm': L(88, -18), 'Sword': A(0.32, -0.08, -0.94),
              'LeftArm': L(-20, 0, -40), 'RightLeg': R(-30), 'LeftLeg': R(-6)}
FLIGHT_FOLLOW = {'Torso': R(-20, -28), 'Head': R(8, 16), 'RightArm': L(86, -76), 'Sword': A(0.95, -0.22, 0.2),
                 'LeftArm': L(0, 0, -35), 'RightLeg': R(-26), 'LeftLeg': R(8)}
# The finish (zanshin): upright, turned a little to his right, the arm level
# out at his side and the blade angled down and back, clear of his legs and
# under the wing. `settle` lets it sink a touch while he holds it.
def zanshin(settle):
    return {'Torso': R(-6 + settle, -14, 4), 'Head': R(-8, -55 - settle), 'RightArm': L(80 - settle, -62),
            'Sword': A(0.38, -0.78, 0.5), 'LeftArm': L(14, 8, -20), 'RightLeg': R(-22, 0, 4), 'LeftLeg': R(12, 0, -4)}
# Raising the blade up his right side on the way back to the shoulder.
FLIGHT_LIFT = {'Torso': R(-2, -10), 'Head': R(-4, -20), 'RightArm': L(150, -45), 'Sword': A(0.4, 0.88, 0.25),
               'LeftArm': L(20, 0, -30), 'RightLeg': R(10), 'LeftLeg': R(-4)}
MOON_FLIGHT = [(0.0, point(-4)), (MOON_CUT_AT - 0.08, FLIGHT_COCK), (MOON_CUT_AT, FLIGHT_CUT),
               (MOON_CUT_AT + 0.06, FLIGHT_FOLLOW), (MOON_CUT_AT + 0.16, zanshin(0)),
               (MOON_LANDS + 0.3, zanshin(3)), (MOON_LANDS + 0.45, FLIGHT_LIFT), (MOON_LANDS + 0.67, AIR[0][1])]

# Victim thrown into the sky: flailing, held long (the cutscene ends it).
def launched(flail):
    return {'Torso': R(20 + flail), 'Head': R(-30), 'RightArm': L(160 - flail * 3, 0, 30), 'Sword': A(0.3, 0.8, 0.5),
            'LeftArm': L(150 + flail * 3, 0, -35), 'RightLeg': R(30 - flail * 2), 'LeftLeg': R(-20 + flail * 2)}
LAUNCHED = [(0.0, launched(0))]
for i in range(1, 25):
    LAUNCHED.append((round(i * 0.25, 2), launched(6 if i % 2 else -6)))

# ---------------- Black Form moves ----------------
# Black Hurricane: he coils up the other way first, then four full spins
# with the blade held straight out (the whole body turning on the root in
# 90 degree steps; the hits and crescents are timed to these), stepping
# round as he goes and leaning in and out with the speed, then a final
# outward cut that overshoots and settles.
H_COIL = {'Torso': R(-16, 38), 'Head': R(8, -26), 'RightArm': L(70, 70), 'Sword': A(-0.75, -0.2, 0.62),
          'LeftArm': L(40, -30), 'RightLeg': R(-26, 0, 6), 'LeftLeg': R(24, 0, -6)}
def spin(step):
    lean = -8 - 5 * (step % 2)          # dipping into each half turn
    t = R(lean, -90 * step)
    stride = 7 if step % 2 == 0 else -7  # feet stepping round
    return {'Torso': t, 'Head': R(6 + 2 * (step % 2)), 'RightArm': L(88 - 3 * (step % 2), -88),
            'Sword': torso_dir(t, (0.98, -0.08, -0.18)),
            'LeftArm': L(75 + 4 * (step % 2), 85), 'RightLeg': R(-18 + stride), 'LeftLeg': R(16 + stride)}
H_FINISH = {'Torso': R(-12, 40), 'Head': R(4, -30), 'RightArm': L(84, 95), 'Sword': A(-0.85, -0.1, 0.5),
            'LeftArm': L(25, -40), 'RightLeg': R(-26), 'LeftLeg': R(24)}
H_FOLLOW = {'Torso': R(-16, 52), 'Head': R(6, -36), 'RightArm': L(80, 108), 'Sword': A(-0.8, -0.3, 0.52),
            'LeftArm': L(18, -44), 'RightLeg': R(-30, 6), 'LeftLeg': R(26, 6)}
H_SETTLE = {'Torso': R(-10, 34), 'Head': R(4, -24), 'RightArm': L(78, 84), 'Sword': A(-0.8, -0.32, 0.5),
            'LeftArm': L(26, -36), 'RightLeg': R(-24), 'LeftLeg': R(22)}
HURRICANE = [(0.0, UPPER), (0.06, H_COIL), (0.1, spin(0))]
for i in range(1, 17):
    HURRICANE.append((round(0.1 + i * 0.05, 3), spin(i)))
HURRICANE += [(1.0, H_FINISH), (1.08, H_FOLLOW), (1.25, H_SETTLE)]

# Black Slash: a dip and a twist to gather himself, the sword wound up high
# behind him, then a huge diagonal cut (it throws the wave at 0.21) that
# carries on past the strike before he settles.
BS_GATHER = {'Torso': R(-8, -18), 'Head': R(4, 14), 'RightArm': L(110, -30), 'Sword': A(0.55, 0.35, 0.76),
             'LeftArm': L(45, -20), 'RightLeg': R(-14), 'LeftLeg': R(14)}
BS_COCK = {'Torso': R(6, -40), 'Head': R(0, 30), 'RightArm': L(150, -35), 'Sword': A(0.55, 0.65, 0.5),
           'LeftArm': L(55, -20), 'RightLeg': R(-10), 'LeftLeg': R(12)}
BS_THROUGH = {'Torso': R(-6, 4), 'Head': R(2, -4), 'RightArm': L(120, 10), 'Sword': A(-0.1, 0.55, -0.83),
              'LeftArm': L(40, -25), 'RightLeg': R(-20), 'LeftLeg': R(20)}
BS_STRIKE = {'Torso': R(-16, 42), 'Head': R(8, -30), 'RightArm': L(72, 62), 'Sword': A(-0.72, -0.4, -0.56),
             'LeftArm': L(20, -35), 'RightLeg': R(-30), 'LeftLeg': R(28)}
BS_FOLLOW = {'Torso': R(-20, 50), 'Head': R(10, -34), 'RightArm': L(64, 74), 'Sword': A(-0.8, -0.36, -0.48),
             'LeftArm': L(16, -38), 'RightLeg': R(-32), 'LeftLeg': R(30)}
BS_SETTLE = {'Torso': R(-12, 36), 'Head': R(6, -26), 'RightArm': L(66, 56), 'Sword': A(-0.72, -0.38, -0.58),
             'LeftArm': L(24, -32), 'RightLeg': R(-24), 'LeftLeg': R(22)}
BLACK_SLASH = [(0.0, UPPER), (0.06, BS_GATHER), (0.13, BS_COCK), (0.17, BS_THROUGH), (0.21, BS_STRIKE),
               (0.3, BS_FOLLOW), (0.55, BS_SETTLE)]

# Grand Divider: the sword raised straight to the sky, braced wide and
# shaking as anti-magic piles into it; then he arches back to his full
# height and brings it down in one crushing cleave (it bites the ground at
# 0.1) that bounces him a touch off the impact before it settles.
def raise_sword(tremble):
    return {'Torso': R(12 + tremble), 'Head': R(-16), 'RightArm': L(176, 4), 'Sword': A(0.02, 1, 0.05),
            'LeftArm': L(150, -18), 'RightLeg': R(-14, 0, 8), 'LeftLeg': R(14, 0, -8)}
G_LIFT = {'Torso': R(4, -8), 'Head': R(-6, 6), 'RightArm': L(130, -10), 'Sword': A(0.2, 0.75, 0.62),
          'LeftArm': L(110, -20), 'RightLeg': R(-12, 0, 6), 'LeftLeg': R(12, 0, -6)}
G_ARCH = {'Torso': R(20), 'Head': R(-22), 'RightArm': L(178, 2), 'Sword': A(0, 0.92, 0.4),
          'LeftArm': L(160, -14), 'RightLeg': R(-16, 0, 8), 'LeftLeg': R(16, 0, -8)}
G_THROUGH = {'Torso': R(-6), 'Head': R(2), 'RightArm': L(115, 4), 'Sword': A(0, 0.35, -0.94),
             'LeftArm': L(100, -10), 'RightLeg': R(-20), 'LeftLeg': R(16)}
G_STRIKE = {'Torso': R(-36, 4), 'Head': R(18), 'RightArm': L(60, 6), 'Sword': A(0, -0.45, -0.89),
            'LeftArm': L(35, -8), 'RightLeg': R(-46), 'LeftLeg': R(38)}
G_RECOIL = {'Torso': R(-30, 4), 'Head': R(14), 'RightArm': L(64, 6), 'Sword': A(0, -0.42, -0.9),
            'LeftArm': L(40, -8), 'RightLeg': R(-42), 'LeftLeg': R(36)}
GRAND_CHARGE = [(0.0, UPPER), (0.1, G_LIFT), (0.2, raise_sword(0)), (0.35, raise_sword(3)), (0.5, raise_sword(-1)),
                (0.7, raise_sword(3))]
GRAND_RELEASE = [(0.0, raise_sword(3)), (0.03, G_ARCH), (0.065, G_THROUGH), (0.1, G_STRIKE), (0.2, G_RECOIL),
                 (0.6, G_STRIKE)]

# ---------------- Sword swap (R in Black Form) ----------------
# He holds the old sword up as it dissolves, pulls the new one out of the
# air low across his body (it's in his hand at 0.22, when the server swaps
# the model), flicks it out to his side, then settles into his stance.
SW_OFFER = {'Torso': R(4, 12), 'Head': R(-6, -8), 'RightArm': L(125, -12), 'Sword': A(0.08, 0.95, -0.3),
            'LeftArm': L(60, 35, -10), 'RightLeg': R(-12), 'LeftLeg': R(12)}
SW_DRAW = {'Torso': R(-10, 34), 'Head': R(6, -24), 'RightArm': L(60, 74), 'Sword': A(-0.72, -0.25, -0.65),
           'LeftArm': L(30, -30), 'RightLeg': R(-18), 'LeftLeg': R(16)}
SW_FLICK = {'Torso': R(-8, -26), 'Head': R(4, 20), 'RightArm': L(84, -70), 'Sword': A(0.86, -0.25, -0.44),
            'LeftArm': L(35, -20), 'RightLeg': R(-16), 'LeftLeg': R(14)}
SWORD_SWAP = [(0.0, UPPER), (0.1, SW_OFFER), (0.22, SW_OFFER), (0.3, SW_DRAW), (0.4, SW_FLICK), (0.6, UPPER)]

# ---------------- Sword moves (Black Form moves 1 and 2, by sword) ----------------
# Reaches (where each sword's point sits along the handle) for the checker.
DWELLER_REACH, DESTROYER_REACH, SLASHER_REACH = 3.9, 4.0, 3.35

# Demon-Slayer: Slayer Recall. Wound back over his shoulder, he hurls the
# sword (it leaves his hand at 0.3), calls it back with his palm out, and
# catches it swinging it up onto his shoulder.
RT_WIND = {'Torso': R(8, -30), 'Head': R(-4, 22), 'RightArm': L(165, -25), 'Sword': A(0.3, 0.3, 0.9),
           'LeftArm': L(70, -10), 'RightLeg': R(-16), 'LeftLeg': R(16)}
RT_THROW = {'Torso': R(-18, 30), 'Head': R(10, -20), 'RightArm': L(100, 20), 'Sword': A(-0.2, 0.1, -0.97),
            'LeftArm': L(-20, 0, -30), 'RightLeg': R(-34), 'LeftLeg': R(30)}
RT_FOLLOW = {'Torso': R(-14, 24), 'Head': R(8, -16), 'RightArm': L(85, 10), 'Sword': A(-0.1, -0.1, -0.99),
             'LeftArm': L(-10, 0, -30), 'RightLeg': R(-30), 'LeftLeg': R(26)}
RC_CALL = {'Torso': R(-6, 10), 'Head': R(4, -6), 'RightArm': L(95, 0), 'Sword': A(0, 0.1, -0.99),
           'LeftArm': L(30, -20), 'RightLeg': R(-14), 'LeftLeg': R(14)}
RC_CATCH = {'Torso': R(-10, -14), 'Head': R(6, 10), 'RightArm': L(120, -20), 'Sword': A(0.4, 0.75, 0.52),
            'LeftArm': L(40, -20), 'RightLeg': R(-18), 'LeftLeg': R(16)}
RECALL_THROW = [(0.0, UPPER), (0.15, RT_WIND), (0.3, RT_THROW), (0.6, RT_FOLLOW)]
RECALL_CALL = [(0.0, RT_FOLLOW), (0.15, RC_CALL), (2.0, RC_CALL)]
RECALL_CATCH = [(0.0, RC_CALL), (0.08, RC_CATCH), (0.35, UPPER)]

# Demon-Destroyer: Causality Break. Both hands lift the sword point-down,
# then drive it into the ground in front of him (0.42); he yanks it out.
CP_LIFT = {'Torso': R(10), 'Head': R(-8), 'RightArm': L(120, 0), 'Sword': A(0, -0.55, -0.83),
           'LeftArm': L(118, -6), 'RightLeg': R(-12), 'LeftLeg': R(12)}
CP_STAB = {'Torso': R(-22), 'Head': R(14), 'RightArm': L(78, 0), 'Sword': A(0, -0.82, -0.57),
           'LeftArm': L(76, -6), 'RightLeg': R(-34), 'LeftLeg': R(28)}
CP_YANK = {'Torso': R(4, -10), 'Head': R(-4, 8), 'RightArm': L(130, -15), 'Sword': A(0.2, 0.9, -0.3),
           'LeftArm': L(40, -20), 'RightLeg': R(-14), 'LeftLeg': R(14)}
CAUSALITY_PLANT = [(0.0, UPPER), (0.2, CP_LIFT), (0.42, CP_STAB), (0.8, CP_STAB)]
CAUSALITY_PULL = [(0.0, CP_STAB), (0.12, CP_YANK), (0.4, UPPER)]

# Demon-Destroyer: Severance. A low crouch with the blade drawn back, one
# draw-cut as he dashes through them (0.2), and he stops past them with his
# back turned, the blade held out low; the cut lands a beat later.
SV_CROUCH = {'Torso': R(-26, -30), 'Head': R(16, 22), 'RightArm': L(-30, -15, 20), 'Sword': A(0.32, 0.12, 0.94),
             'LeftArm': L(70, 10), 'RightLeg': R(-40), 'LeftLeg': R(36)}
SV_CUT = {'Torso': R(-30, 40), 'Head': R(18, -30), 'RightArm': L(84, 80), 'Sword': A(-0.86, -0.04, -0.5),
          'LeftArm': L(-20, 0, -35), 'RightLeg': R(-46), 'LeftLeg': R(40)}
SV_AFTER = {'Torso': R(-12, 60), 'Head': R(6, -40), 'RightArm': L(70, 100), 'Sword': A(-0.8, -0.45, 0.4),
            'LeftArm': L(15, -40), 'RightLeg': R(-24), 'LeftLeg': R(22)}
SV_DRAW = {'Torso': R(-28, 0), 'Head': R(16, 0), 'RightArm': L(80, -60), 'Sword': A(0.9, 0.02, -0.42),
           'LeftArm': L(20, 0, -30), 'RightLeg': R(-44), 'LeftLeg': R(38)}
SEVERANCE = [(0.0, UPPER), (0.12, SV_CROUCH), (0.16, SV_DRAW), (0.2, SV_CUT), (0.32, SV_AFTER), (0.8, SV_AFTER)]

# Demon-Slasher Katana: Infinite Slash. Yami's two-handed overhead raise,
# trembling as the cut builds, then one straight chop (it opens at 0.05).
IS_RAISE = {'Torso': R(10, -10), 'Head': R(-10, 8), 'RightArm': L(170, -6), 'Sword': A(0.1, 0.6, 0.8),
            'LeftArm': L(165, 8), 'RightLeg': R(-16, 0, 6), 'LeftLeg': R(18, 0, -6)}
IS_TREMBLE = IS_RAISE | {'Torso': R(12, -10), 'Head': R(-12, 8)}
IS_CUT = {'Torso': R(-30), 'Head': R(16), 'RightArm': L(75, 2), 'Sword': A(0, -0.35, -0.94),
          'LeftArm': L(72, -2), 'RightLeg': R(-42), 'LeftLeg': R(36)}
INFINITE_RAISE = [(0.0, UPPER), (0.25, IS_RAISE), (0.4, IS_TREMBLE), (0.55, IS_RAISE)]
INFINITE_CUT = [(0.0, IS_RAISE), (0.05, IS_CUT), (0.45, IS_CUT)]

# Demon-Slasher Katana: Zetten. Crouched in an iai stance, the katana low
# at his hip, head bowed and still; then one rising diagonal cut.
Z_STANCE = {'Torso': R(-20, -35), 'Head': R(22, 25), 'RightArm': L(30, -20, 15), 'Sword': A(0.36, -0.05, 0.93),
            'LeftArm': L(50, 30, -10), 'RightLeg': R(-34, 10), 'LeftLeg': R(30, 10)}
Z_CUT = {'Torso': R(-16, 40), 'Head': R(10, -28), 'RightArm': L(130, 70), 'Sword': A(-0.6, 0.65, -0.45),
         'LeftArm': L(-10, 0, -35), 'RightLeg': R(-36), 'LeftLeg': R(32)}
Z_AFTER = {'Torso': R(-10, 34), 'Head': R(6, -24), 'RightArm': L(115, 60), 'Sword': A(-0.55, 0.6, -0.58),
           'LeftArm': L(0, 0, -30), 'RightLeg': R(-26), 'LeftLeg': R(24)}
ZETTEN_STANCE = [(0.0, UPPER), (0.12, Z_STANCE), (1.4, Z_STANCE)]
ZETTEN_CUT = [(0.0, Z_STANCE), (0.05, Z_CUT), (0.35, Z_AFTER), (0.6, Z_AFTER)]

ALL = {'Idle': IDLE, 'Run': RUN, 'Walk': WALK, 'Air': AIR, 'Seize': SEIZE, 'Grabbed': GRABBED,
       'MoonThrow': MOON_THROW, 'MoonPerch': MOON_PERCH, 'MoonFlight': MOON_FLIGHT, 'Launched': LAUNCHED,
       'Hurricane': HURRICANE, 'BlackSlash': BLACK_SLASH, 'GrandCharge': GRAND_CHARGE, 'GrandRelease': GRAND_RELEASE,
       'Leap': LEAP, 'Plunge': PLUNGE, 'PlungeImpact': PLUNGE_IMPACT,
       'AirDividerCharge': AIR_DIVIDER_CHARGE, 'AirDividerRelease': AIR_DIVIDER_RELEASE, 'Propel': PROPEL, 'BullCombo': BULL_COMBO,
       'AirPropel': AIR_PROPEL, 'AirMeteorLunge': AIR_METEOR_LUNGE, 'AirMeteorReach': AIR_METEOR_REACH,
       'AirSeize': AIR_SEIZE,
       'AirDeflectStance': AIR_DEFLECT_STANCE,
       'MeteorLunge': METEOR_LUNGE, 'MeteorReach': METEOR_REACH, 'MeteorRise': METEOR_RISE, 'MeteorSpin': METEOR_SPIN, 'SwordSwap': SWORD_SWAP,
       'RecallThrow': RECALL_THROW, 'RecallCall': RECALL_CALL, 'RecallCatch': RECALL_CATCH,
       'CausalityPlant': CAUSALITY_PLANT, 'CausalityPull': CAUSALITY_PULL, 'Severance': SEVERANCE,
       'InfiniteRaise': INFINITE_RAISE, 'InfiniteCut': INFINITE_CUT, 'ZettenStance': ZETTEN_STANCE,
       'ZettenCut': ZETTEN_CUT, 'MeteorDrill': METEOR_DRILL, 'MeteorLand': METEOR_LAND, 'MeteorSlam': METEOR_SLAM, 'MeteorImpact': METEOR_IMPACT,
       'DividerCharge': DIVIDER_CHARGE, 'DividerRelease': DIVIDER_RELEASE,
       'DeflectStance': DEFLECT_STANCE, 'DeflectCounter': DEFLECT_COUNTER, 'DeflectReflect': DEFLECT_REFLECT,
       'Awaken': AWAKEN,
       'DashFront': DASH_FRONT, 'DashBack': DASH_BACK, 'DashLeft': DASH_LEFT, 'DashRight': DASH_RIGHT,
       'FlinchA': FLINCH_A, 'FlinchB': FLINCH_B, 'FlinchBack': FLINCH_BACK, 'HitHeavy': HIT_HEAVY,
       'Guard': GUARD, 'GuardHit': GUARD_HIT, 'Stagger': STAGGER, 'Slash1': SLASH1, 'Slash2': SLASH2, 'Slash3': SLASH3,
       'Cleave': CLEAVE, 'Rising': RISING, 'Chop': CHOP, 'Entrance': ENTRANCE}

# Grounded animations get their feet planted (the body drops into lunges and
# wide stances). These are played in the air instead, or leave the ground
# (planted only up to the time given).
AIRBORNE = {'Air', 'Grabbed', 'Launched', 'MoonPerch', 'MoonFlight', 'Plunge', 'AirDividerCharge', 'AirDividerRelease', 'MeteorRise', 'MeteorSpin', 'MeteorDrill', 'MeteorLand', 'MeteorSlam', 'Chop',
            'AirPropel', 'AirMeteorLunge', 'AirMeteorReach', 'AirSeize', 'AirDeflectStance'}
PLANT_UNTIL = {'Leap': 0.1}
UNPLANTED = dict(ALL)
ALL = {name: keys if name in AIRBORNE else plant(keys, PLANT_UNTIL.get(name)) for name, keys in ALL.items()}

if __name__ == '__main__':
    # Intentional floor contact: the air chop's tip grazes the floor, the
    # entrance slam plants it. The entrance sword is hidden until the draw.
    # (The Demon-Slayer Sword is long: where the blade is driven into the
    # ground on purpose, it may go in about a stud.)
    rules = {'Chop': dict(floor=-3.1), 'Entrance': dict(floor=-3.9, hidden_until=0.88),
             # These plant the blade on purpose.
             'MeteorSlam': dict(floor=-4.0), 'MeteorImpact': dict(floor=-4.0), 'Awaken': dict(floor=-4.0),
             'PlungeImpact': dict(floor=-4.0),
             # Only ever played in the air.
             'GrandRelease': dict(floor=-4.0),  # the cleave bites into the ground
             'Plunge': dict(floor=-10), 'Grabbed': dict(floor=-10), 'Launched': dict(floor=-10),
             'MoonPerch': dict(floor=-10), 'MoonFlight': dict(floor=-10), 'AirDividerCharge': dict(floor=-10), 'AirDividerRelease': dict(floor=-10), 'MeteorSpin': dict(floor=-10), 'MeteorDrill': dict(floor=-10),
             # Starts upside down (the path turns him; the checker can't see
             # that), so the trailing sword reads as pointing at the floor.
             # The landing crouch's tip ends at about -3.
             'MeteorLand': dict(floor=-10),
             'AirPropel': dict(floor=-10), 'AirMeteorLunge': dict(floor=-10), 'AirMeteorReach': dict(floor=-10),
             'AirSeize': dict(floor=-10),
             'AirDeflectStance': dict(floor=-10),
             # The other swords are shorter than the Demon-Slayer.
             'CausalityPlant': dict(floor=-4.0, reach=DESTROYER_REACH),  # driven into the ground
             'CausalityPull': dict(floor=-4.0, reach=DESTROYER_REACH),
             'Severance': dict(reach=DESTROYER_REACH),
             'InfiniteRaise': dict(reach=SLASHER_REACH), 'InfiniteCut': dict(reach=SLASHER_REACH),
             'ZettenStance': dict(reach=SLASHER_REACH), 'ZettenCut': dict(reach=SLASHER_REACH)}
    ok = True
    for name, keys in ALL.items():
        grounded = name not in AIRBORNE and name not in PLANT_UNTIL
        ok &= verify(name, keys, grounded=grounded, **rules.get(name, {}))
    print("ALL CLEAN" if ok else "PROBLEMS FOUND")
