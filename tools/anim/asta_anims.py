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

# Run cycle (0.6s at walk speed 16; plays faster when moving faster): forward
# lean, striding legs, left arm pumping against them, sword bobbing on the
# shoulder.
def run_key(torso, head, arm_pitch, larm, rleg, lleg):
    t = R(*torso)
    return {'Torso': t, 'Head': R(*head), 'RightArm': L(arm_pitch, 25, 10),
            'Sword': torso_dir(t, SHOULDER), 'LeftArm': larm, 'RightLeg': R(rleg), 'LeftLeg': R(lleg)}

RUN = [
    (0.00, run_key((-14, 6), (8,-6), 84, L(42,-12), 34, -30)),
    (0.15, run_key((-16, 0), (10,0), 88, L(5,-5), 2, 2)),
    (0.30, run_key((-14,-6), (8,6), 84, L(-38,4), -30, 34)),
    (0.45, run_key((-16, 0), (10,0), 88, L(5,-5), 2, 2)),
    (0.60, run_key((-14, 6), (8,-6), 84, L(42,-12), 34, -30)),
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

ALL = {'Idle': IDLE, 'Run': RUN, 'Air': AIR,
       'DashFront': DASH_FRONT, 'DashBack': DASH_BACK, 'DashLeft': DASH_LEFT, 'DashRight': DASH_RIGHT,
       'FlinchA': FLINCH_A, 'FlinchB': FLINCH_B, 'FlinchBack': FLINCH_BACK, 'HitHeavy': HIT_HEAVY,
       'Guard': GUARD, 'GuardHit': GUARD_HIT, 'Stagger': STAGGER, 'Slash1': SLASH1, 'Slash2': SLASH2, 'Slash3': SLASH3,
       'Cleave': CLEAVE, 'Rising': RISING, 'Chop': CHOP, 'Entrance': ENTRANCE}

if __name__ == '__main__':
    # Intentional floor contact: the air chop's tip grazes the floor, the
    # entrance slam plants it. The entrance sword is hidden until the draw.
    rules = {'Chop': dict(floor=-3.1), 'Entrance': dict(floor=-3.5, hidden_until=0.88)}
    ok = True
    for name, keys in ALL.items():
        ok &= verify(name, keys, **rules.get(name, {}))
    print("ALL CLEAN" if ok else "PROBLEMS FOUND")
