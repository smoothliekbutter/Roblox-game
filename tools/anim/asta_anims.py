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

# Run cycle (0.5s at speed 16; plays faster or slower with the actual
# speed): forward lean, long strides, left arm pumping against them, sword
# bobbing on the shoulder, hips and shoulders twisting with each step.
def run_key(torso, head, arm_pitch, larm, rleg, lleg):
    t = R(*torso)
    return {'Torso': t, 'Head': R(*head), 'RightArm': L(arm_pitch, 25, 10),
            'Sword': torso_dir(t, SHOULDER), 'LeftArm': larm, 'RightLeg': R(rleg), 'LeftLeg': R(lleg)}

RUN = [
    (0.000, run_key((-18, 8), (12, -8), 82, L(55, -14, -6), 50, -42)),
    (0.125, run_key((-20, 0), (14, 0), 88, L(8, -6, -8), 4, 4)),
    (0.250, run_key((-18, -8), (12, 8), 82, L(-45, 6, -10), -42, 50)),
    (0.375, run_key((-20, 0), (14, 0), 88, L(8, -6, -8), 4, 4)),
    (0.500, run_key((-18, 8), (12, -8), 82, L(55, -14, -6), 50, -42)),
]

# Walk cycle (0.9s at speed 8): used when he's slowed down (attacking,
# blocking, casting). Upright, shorter steps, same leg phase as the run so
# the two blend into each other.
WALK = [
    (0.000, run_key((-5, 4), (4, -4), 86, L(22, -8, -6), 24, -22)),
    (0.225, run_key((-4, 0), (3, 0), 87, L(4, -4, -8), 1, 1)),
    (0.450, run_key((-5, -4), (4, 4), 86, L(-16, 2, -10), -22, 24)),
    (0.675, run_key((-4, 0), (3, 0), 87, L(4, -4, -8), 1, 1)),
    (0.900, run_key((-5, 4), (4, -4), 86, L(22, -8, -6), 24, -22)),
]

# In the air (jumping or falling): knee up, free arm out for balance.
AIR = [
    (0.0, {'Torso': R(-6), 'Head': R(6), 'RightArm': REST_ARM, 'Sword': A(*SHOULDER),
           'LeftArm': L(35, 0, -40), 'RightLeg': R(30), 'LeftLeg': R(-12)}),
]

# ---------------- M1 swings ----------------
READY = IDLE[0][1]

LEGS = lambda y: {'RightLeg': R(0,y,0), 'LeftLeg': R(0,y,0)}  # additive counter-twist

def swing(windup, through, strike, settle, heavy=False):
    t = (0.12, 0.18, 0.24, 0.44) if heavy else (0.08, 0.12, 0.17, 0.32)
    # Start from the idle's upper body. Legs are left to the idle stance
    # (or layered on top of it), so the stance isn't applied twice.
    start = {k: v for k, v in READY.items() if k not in ('RightLeg', 'LeftLeg')}
    if 'RightLeg' in windup:
        start.update(LEGS(0))
    return [(0.0, start), (t[0], windup), (t[1], through), (t[2], strike), (t[3], settle)]

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

# Barrage: a rapid flurry, side to side with an overhead chop thrown in,
# finishing with a straight thrust that pushes them away.
B_RIGHT = {'Torso': R(-6, -25), 'Head': R(6, 18), 'RightArm': L(82, -70), 'Sword': A(0.85, 0.05, -0.5),
           'LeftArm': L(40, -25), 'RightLeg': R(0, 22), 'LeftLeg': R(0, 22)}
B_LEFT = {'Torso': R(-6, 25), 'Head': R(6, -18), 'RightArm': L(82, 70), 'Sword': A(-0.85, 0.05, -0.5),
          'LeftArm': L(35, -30), 'RightLeg': R(0, -22), 'LeftLeg': R(0, -22)}
B_UP = {'Torso': R(4, 0), 'Head': R(-4, 0), 'RightArm': L(150, 10), 'Sword': A(0, 0.85, -0.52),
        'LeftArm': L(45, -25), 'RightLeg': R(0, 0), 'LeftLeg': R(0, 0)}
B_DOWN = {'Torso': R(-14, 0), 'Head': R(10, 0), 'RightArm': L(55, 5), 'Sword': A(0, -0.3, -0.95),
          'LeftArm': L(40, -25), 'RightLeg': R(0, 0), 'LeftLeg': R(0, 0)}
B_PUSH = {'Torso': R(-16, 6), 'Head': R(12, -4), 'RightArm': L(85, 0), 'Sword': A(0, 0, -1),
          'LeftArm': L(-20, 0, -30), 'RightLeg': R(0, 0), 'LeftLeg': R(0, 0)}
BARRAGE_STEPS = [B_RIGHT, B_LEFT, B_RIGHT, B_UP, B_DOWN, B_LEFT, B_RIGHT, B_LEFT]
BARRAGE_STEP = 0.1
BARRAGE = [(0.0, PROPEL_POSE | {'RightLeg': R(0), 'LeftLeg': R(0)})]
for i, pose in enumerate(BARRAGE_STEPS):
    BARRAGE.append((round((i + 1) * BARRAGE_STEP, 3), pose))
BARRAGE_END = len(BARRAGE_STEPS) * BARRAGE_STEP
BARRAGE.append((round(BARRAGE_END + 0.12, 3), B_PUSH))
BARRAGE.append((round(BARRAGE_END + 0.32, 3), B_PUSH))

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
METEOR_LUNGE = [(0.0, UPPER), (0.07, M_LUNGE), (0.35, M_LUNGE)]
METEOR_RISE = [(0.0, M_HOLD), (0.2, M_RISE), (0.55, M_APEX)]
METEOR_SLAM = [(0.0, M_APEX), (0.12, M_SLAM), (0.6, M_SLAM)]
METEOR_IMPACT = [(0.0, M_SLAM), (0.25, M_RECOVER), (0.5, M_RECOVER)]

# ---------------- Black Divider (charge, release) ----------------
LEGS_TWIST = lambda y: {'RightLeg': R(0, y), 'LeftLeg': R(0, y)}
def d_charge(twist, lean):
    return {'Torso': R(lean, twist), 'Head': R(0, -twist * 0.75), 'RightArm': L(-40, -35), 'Sword': A(0.55, -0.2, 0.8),
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
# Air Black Meteorite: swoops in hand-first, then hangs on to their throat
# with the legs dangling.
AM_LUNGE = M_LUNGE | {'Torso': R(-36, -8), 'Head': R(28, 6), 'RightLeg': R(-16), 'LeftLeg': R(-30)}
AS_CLAMP = SEIZE_CLAMP | {'RightLeg': R(-22), 'LeftLeg': R(8)}
AS_LIFT = SEIZE_LIFT | {'RightLeg': R(-10), 'LeftLeg': R(16)}
AIR_METEOR_LUNGE = [(0.0, UPPER), (0.07, AM_LUNGE), (0.35, AM_LUNGE)]
AIR_SEIZE = [(0.0, AM_LUNGE), (0.08, AS_CLAMP), (0.3, AS_LIFT), (0.45, AS_LIFT)]
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

# Perched in the sky in front of the moon: turned side-on, the sword held
# out low to his right, one knee up, glaring at them. Breathes while he waits.
def perch(lean, arm):
    return {'Torso': R(lean, -30), 'Head': R(-10, 24), 'RightArm': L(arm, 70), 'Sword': A(0.75, -0.55, 0.35),
            'LeftArm': L(22, 0, -28), 'RightLeg': R(-14), 'LeftLeg': R(44)}
# Then he levels the sword at them: a challenge across the sky.
def point(lean):
    return {'Torso': R(lean, 6), 'Head': R(-8, -4), 'RightArm': L(98, 8), 'Sword': A(0.05, 0.22, -0.97),
            'LeftArm': L(18, 0, -30), 'RightLeg': R(-14), 'LeftLeg': R(40)}
MOON_PERCH = [(0.0, LEAP_LAUNCH), (0.15, perch(-6, 50)), (0.5, perch(-8, 46)), (0.85, perch(-6, 50)),
              (1.2, perch(-8, 46)), (1.5, point(-4)), (1.95, point(-6)), (2.35, point(-4))]

# The flight: body flat out, sword cocked back, then the cut through them
# and the finish: past them, back turned, blade held out behind.
FLIGHT_COCK = {'Torso': R(-50, 35), 'Head': R(30, -30), 'RightArm': L(-20, 20, 40), 'Sword': A(0.6, -0.2, 0.77),
               'LeftArm': L(110, -10), 'RightLeg': R(-35), 'LeftLeg': R(-10)}
FLIGHT_CUT = {'Torso': R(-40, -10), 'Head': R(20, 8), 'RightArm': L(85, -5), 'Sword': A(0.1, -0.1, -0.99),
              'LeftArm': L(30, 0, -40), 'RightLeg': R(-30), 'LeftLeg': R(-5)}
FLIGHT_AFTER = {'Torso': R(-10, -50), 'Head': R(0, 34), 'RightArm': L(80, 100), 'Sword': A(-0.7, -0.5, 0.5),
                'LeftArm': L(20, 0, -35), 'RightLeg': R(-20), 'LeftLeg': R(25)}
MOON_FLIGHT = [(0.0, point(-4)), (0.06, FLIGHT_COCK), (0.14, FLIGHT_CUT), (0.22, FLIGHT_AFTER),
               (1.15, FLIGHT_AFTER)]

# Victim thrown into the sky: flailing, held long (the cutscene ends it).
def launched(flail):
    return {'Torso': R(20 + flail), 'Head': R(-30), 'RightArm': L(160 - flail * 3, 0, 30), 'Sword': A(0.3, 0.8, 0.5),
            'LeftArm': L(150 + flail * 3, 0, -35), 'RightLeg': R(30 - flail * 2), 'LeftLeg': R(-20 + flail * 2)}
LAUNCHED = [(0.0, launched(0))]
for i in range(1, 25):
    LAUNCHED.append((round(i * 0.25, 2), launched(6 if i % 2 else -6)))

# ---------------- Black Form moves ----------------
# Black Hurricane: four full spins with the blade held straight out, then a
# final outward cut. The whole body turns on the root in 90 degree steps.
def spin(step):
    t = R(-8, -90 * step)
    return {'Torso': t, 'Head': R(6), 'RightArm': L(88, -88), 'Sword': torso_dir(t, (0.98, -0.08, -0.18)),
            'LeftArm': L(75, 85), 'RightLeg': R(-18), 'LeftLeg': R(16)}
H_FINISH = {'Torso': R(-12, 40), 'Head': R(4, -30), 'RightArm': L(84, 95), 'Sword': A(-0.85, -0.1, 0.5),
            'LeftArm': L(25, -40), 'RightLeg': R(-26), 'LeftLeg': R(24)}
HURRICANE = [(0.0, UPPER), (0.1, spin(0))]
for i in range(1, 17):
    HURRICANE.append((round(0.1 + i * 0.05, 3), spin(i)))
HURRICANE += [(1.0, H_FINISH), (1.25, H_FINISH)]

# Black Slash: sword wound up high behind him, then a huge diagonal cut that
# throws the wave.
BS_COCK = {'Torso': R(6, -40), 'Head': R(0, 30), 'RightArm': L(150, -35), 'Sword': A(0.55, 0.65, 0.5),
           'LeftArm': L(55, -20), 'RightLeg': R(-10), 'LeftLeg': R(12)}
BS_STRIKE = {'Torso': R(-16, 42), 'Head': R(8, -30), 'RightArm': L(72, 62), 'Sword': A(-0.72, -0.4, -0.56),
             'LeftArm': L(20, -35), 'RightLeg': R(-30), 'LeftLeg': R(28)}
BS_SETTLE = {'Torso': R(-12, 36), 'Head': R(6, -26), 'RightArm': L(66, 56), 'Sword': A(-0.7, -0.45, -0.55),
             'LeftArm': L(24, -32), 'RightLeg': R(-24), 'LeftLeg': R(22)}
BLACK_SLASH = [(0.0, UPPER), (0.13, BS_COCK), (0.21, BS_STRIKE), (0.55, BS_SETTLE)]

# Grand Divider: the sword raised straight to the sky, shaking as anti-magic
# piles into it, then brought down in one crushing cleave.
def raise_sword(tremble):
    return {'Torso': R(12 + tremble), 'Head': R(-16), 'RightArm': L(176, 4), 'Sword': A(0.02, 1, 0.05),
            'LeftArm': L(150, -18), 'RightLeg': R(-14, 0, 8), 'LeftLeg': R(14, 0, -8)}
G_THROUGH = {'Torso': R(-6), 'Head': R(2), 'RightArm': L(115, 4), 'Sword': A(0, 0.35, -0.94),
             'LeftArm': L(100, -10), 'RightLeg': R(-20), 'LeftLeg': R(16)}
G_STRIKE = {'Torso': R(-36, 4), 'Head': R(18), 'RightArm': L(60, 6), 'Sword': A(0, -0.45, -0.89),
            'LeftArm': L(35, -8), 'RightLeg': R(-46), 'LeftLeg': R(38)}
GRAND_CHARGE = [(0.0, UPPER), (0.2, raise_sword(0)), (0.35, raise_sword(3)), (0.5, raise_sword(-1)),
                (0.7, raise_sword(3))]
GRAND_RELEASE = [(0.0, raise_sword(3)), (0.05, G_THROUGH), (0.1, G_STRIKE), (0.6, G_STRIKE)]

ALL = {'Idle': IDLE, 'Run': RUN, 'Walk': WALK, 'Air': AIR, 'Seize': SEIZE, 'Grabbed': GRABBED,
       'MoonThrow': MOON_THROW, 'MoonPerch': MOON_PERCH, 'MoonFlight': MOON_FLIGHT, 'Launched': LAUNCHED,
       'Hurricane': HURRICANE, 'BlackSlash': BLACK_SLASH, 'GrandCharge': GRAND_CHARGE, 'GrandRelease': GRAND_RELEASE,
       'Leap': LEAP, 'Plunge': PLUNGE, 'PlungeImpact': PLUNGE_IMPACT,
       'AirDividerCharge': AIR_DIVIDER_CHARGE, 'AirDividerRelease': AIR_DIVIDER_RELEASE, 'Propel': PROPEL, 'Barrage': BARRAGE,
       'AirPropel': AIR_PROPEL, 'AirMeteorLunge': AIR_METEOR_LUNGE, 'AirSeize': AIR_SEIZE,
       'AirDeflectStance': AIR_DEFLECT_STANCE,
       'MeteorLunge': METEOR_LUNGE, 'MeteorRise': METEOR_RISE, 'MeteorSlam': METEOR_SLAM, 'MeteorImpact': METEOR_IMPACT,
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
AIRBORNE = {'Air', 'Grabbed', 'Launched', 'MoonPerch', 'MoonFlight', 'Plunge', 'AirDividerCharge', 'AirDividerRelease', 'MeteorRise', 'MeteorSlam', 'Chop',
            'AirPropel', 'AirMeteorLunge', 'AirSeize', 'AirDeflectStance'}
PLANT_UNTIL = {'Leap': 0.1}
UNPLANTED = dict(ALL)
ALL = {name: keys if name in AIRBORNE else plant(keys, PLANT_UNTIL.get(name)) for name, keys in ALL.items()}

if __name__ == '__main__':
    # Intentional floor contact: the air chop's tip grazes the floor, the
    # entrance slam plants it. The entrance sword is hidden until the draw.
    rules = {'Chop': dict(floor=-3.1), 'Entrance': dict(floor=-3.5, hidden_until=0.88),
             # These plant the blade on purpose.
             'MeteorSlam': dict(floor=-3.6), 'MeteorImpact': dict(floor=-3.6), 'Awaken': dict(floor=-3.6),
             'PlungeImpact': dict(floor=-3.6),
             # Only ever played in the air.
             'GrandRelease': dict(floor=-3.6),  # the cleave bites into the ground
             'Plunge': dict(floor=-10), 'Grabbed': dict(floor=-10), 'Launched': dict(floor=-10),
             'MoonPerch': dict(floor=-10), 'MoonFlight': dict(floor=-10), 'AirDividerCharge': dict(floor=-10), 'AirDividerRelease': dict(floor=-10),
             'AirPropel': dict(floor=-10), 'AirMeteorLunge': dict(floor=-10), 'AirSeize': dict(floor=-10),
             'AirDeflectStance': dict(floor=-10)}
    ok = True
    for name, keys in ALL.items():
        grounded = name not in AIRBORNE and name not in PLANT_UNTIL
        ok &= verify(name, keys, grounded=grounded, **rules.get(name, {}))
    print("ALL CLEAN" if ok else "PROBLEMS FOUND")
