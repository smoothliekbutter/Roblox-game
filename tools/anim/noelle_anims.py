"""Noelle (Water Princess) animations: stance, locomotion, water lashes and spell casts.

Run `python3 tools/anim/noelle_anims.py` to check them (feet on the floor at
every keyframe and in between) and `python3 tools/anim/noelle_anims.py
src/client/Kits/Water/Animations.luau` to write the Luau data.

Same conventions as yuno_anims.py:
  R(x, y, z)       torso/head/leg rotation: torso -x leans forward, +y turns left
  L(pitch, yaw, roll)  arm/leg aim: pitch 90 = straight ahead, 180 = up;
                   +yaw swings it toward her left, +roll out to her right
"""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from design import *
from math import sin, cos, pi, radians

def R(x, y=0, z=0): return ('rot', x, y, z)
def L(p, y=0, r=0): return ('limb', p, y, r)
def _r(v): return round(v, 2)
TAU = 2 * pi

def pose(torso, head, rarm, larm, rleg=R(3, 0, 3), lleg=R(-5, -8, -3)):
    return {'Torso': torso, 'Head': head, 'RightArm': rarm, 'LeftArm': larm, 'RightLeg': rleg, 'LeftLeg': lleg}

# ---------------- Stance ----------------
# Proud and upright, chin up, the left hand on her hip, the right hand loose
# at her side, palm turned out; feet close, one a little ahead.
STANCE = pose(R(-2, 8), R(6, -6), L(10, 4, 12), L(-14, 0, -30))
IDLE = [
    (0.0, STANCE),
    (1.5, pose(R(-1, 9), R(8, -9), L(13, 4, 13), L(-12, 0, -31))),
    (3.0, STANCE),
]

# ---------------- Locomotion ----------------
# Built like Yuno's: smooth curves sampled densely, the cadence set by the
# swing so a foot passing under her doesn't slide, a runner's bob; a lighter,
# neater arm swing.
def stride(swing, reach):
    return round(TAU * 2 * cos(radians(reach)) * radians(swing), 2)

def cycle(fn, keys):
    return [(round(i / keys, 4), fn(i / keys)) for i in range(keys + 1)]

RUN_LEAN, RUN_SWING, RUN_REACH, RUN_LIFT = 12, 48, 6, 0.16
RUN_STRIDE = stride(RUN_SWING, RUN_REACH)

def run_lift(p):
    return RUN_LIFT * (1 - cos(2 * TAU * p - 0.35)) / 2

def run_pose(p, base=0.0):
    s, bob = sin(TAU * p), cos(2 * TAU * p - 0.35)
    twist, roll = -5 * s, 2.5 * cos(TAU * p)
    torso = R(_r(-RUN_LEAN - 1.5 * (1 - bob) / 2), _r(twist), _r(roll))
    return {
        'Torso': ('body', _r(base + run_lift(p)), *torso[1:]),
        'Head': R(_r(RUN_LEAN * 0.9 + bob), _r(-twist), _r(-roll)),
        'RightArm': L(_r(4 - 40 * s), _r(-6 * s), _r(10 + 3 * s * s)),
        'LeftArm': L(_r(4 + 40 * s), _r(-6 * s), _r(-10 - 3 * s * s)),
        'RightLeg': L(_r(RUN_REACH + RUN_SWING * s + RUN_LEAN), _r(-twist), _r(-0.6 * roll)),
        'LeftLeg': L(_r(RUN_REACH - RUN_SWING * s + RUN_LEAN), _r(-twist), _r(-0.6 * roll)),
    }

RUN_BASE = plant_pose(run_pose(0.35 / (2 * TAU)))['Torso'][1]
RUN = cycle(lambda p: run_pose(p, RUN_BASE), 16)

WALK_LEAN, WALK_SWING, WALK_REACH = 3, 26, 3
WALK_STRIDE = stride(WALK_SWING, WALK_REACH)

def walk_pose(p):
    s, c2 = sin(TAU * p), cos(2 * TAU * p)
    twist, roll = -4 * s, 2 * cos(TAU * p)
    return {
        'Torso': R(-WALK_LEAN, _r(twist), _r(roll)),
        'Head': R(_r(WALK_LEAN + 3 + 0.6 * c2), _r(-twist), _r(-roll)),
        'RightArm': L(_r(4 - 20 * s), _r(-4 * s), 8),
        'LeftArm': L(_r(4 + 20 * s), _r(-4 * s), -8),
        'RightLeg': L(_r(WALK_REACH + WALK_SWING * s + WALK_LEAN), _r(-twist), _r(-0.6 * roll)),
        'LeftLeg': L(_r(WALK_REACH - WALK_SWING * s + WALK_LEAN), _r(-twist), _r(-0.6 * roll)),
    }

WALK = cycle(walk_pose, 12)

# Jumping or falling: arms out and a little up, one foot drawn up, poised.
AIR = [(0.0, pose(R(-4), R(6), L(50, 0, 38), L(50, 0, -38), R(24, 0, 2), R(-8, 0, -2)))]

# ---------------- Hovering (Valkyrie Dress and Dragon Form) ----------------
# Held up on a stream of water (the client lifts her about 1.8 studs while
# she's awakened; these add the bob). The lance is held upright in her right
# hand, the left arm out for balance, legs together, toes down. Moving, she
# leans into the glide, legs trailing.
def hover(lift, lean, turn, rarm, larm, rleg, lleg, head):
    return {'Torso': ('body', lift, lean, turn, 0), 'Head': head, 'RightArm': rarm, 'LeftArm': larm,
            'RightLeg': rleg, 'LeftLeg': lleg}

HOVER_LOW = hover(0, 2, 8, L(-6, 0, 12), L(22, -6, -26), L(-4, 0, 3), L(-12, 0, -3), R(4, -6))
HOVER_HIGH = hover(0.3, 1, 10, L(-4, 0, 14), L(28, -6, -32), L(-6, 0, 4), L(-16, 0, -4), R(2, -8))
HOVER_IDLE = [(0.0, HOVER_LOW), (1.7, HOVER_HIGH), (3.4, HOVER_LOW)]
GLIDE_A = hover(-0.1, -22, 0, L(-14, 0, 14), L(-24, -6, -26), L(-20, 0, 2), L(-30, 0, -2), R(20))
GLIDE_B = hover(0.1, -24, 0, L(-18, 0, 16), L(-30, -6, -30), L(-26, 0, 2), L(-24, 0, -2), R(22))
HOVER_MOVE = [(0.0, GLIDE_A), (0.9, GLIDE_B), (1.8, GLIDE_A)]

# ---------------- M1: water lashes ----------------
# Each lash cracks a whip of water off her hand. Timed like Yuno's swipes:
# held in the wind-up while the clip fades in, then through, strike, settle;
# legs layered on whatever she's doing (a counter-twist as she turns).
def LEGS(y):
    return {'RightLeg': R(0, y, 0), 'LeftLeg': R(0, y, 0)}

def M1POSE(torso, head, rarm, larm, legs):
    return {'Torso': torso, 'Head': head, 'RightArm': rarm, 'LeftArm': larm, **legs}

SWING_TIMES = (0.1, 0.15, 0.21, 0.4)
HEAVY_SWING_TIMES = (0.14, 0.21, 0.28, 0.52)

def swing(windup, through, strike, settle, heavy=False):
    t = HEAVY_SWING_TIMES if heavy else SWING_TIMES
    return [(0.0, windup), (t[0], windup), (t[1], through), (t[2], strike), (t[3], settle)]

# A backhand: the right hand from across her body out to her right.
LASH1 = swing(
    M1POSE(R(0, 30), R(4, -22), L(64, 72, 0), L(30, -16, -24), LEGS(-26)),
    M1POSE(R(-4, 2), R(4, 0), L(92, 12, 0), L(28, -10, -26), LEGS(-2)),
    M1POSE(R(-6, -34), R(4, 26), L(100, -72, 4), L(30, 14, -28), LEGS(30)),
    M1POSE(R(-4, -26), R(4, 20), L(90, -60, 6), L(28, 12, -28), LEGS(22)),
)
# The left hand the other way.
LASH2 = swing(
    M1POSE(R(0, -30), R(4, 22), L(30, 16, 24), L(64, -72, 0), LEGS(26)),
    M1POSE(R(-4, -2), R(4, 0), L(28, 10, 26), L(92, -12, 0), LEGS(2)),
    M1POSE(R(-6, 34), R(4, -26), L(30, -14, 28), L(100, 72, -4), LEGS(-30)),
    M1POSE(R(-4, 26), R(4, -20), L(28, -12, 28), L(90, 60, -6), LEGS(-22)),
)
# Overhead: the right hand from high behind her down in front, a whip crack.
LASH3 = swing(
    M1POSE(R(8, 10), R(12, -8), L(172, 8, 14), L(40, -10, -30), LEGS(-8)),
    M1POSE(R(0, 4), R(6, -2), L(130, 4, 8), L(36, -8, -28), LEGS(-3)),
    M1POSE(R(-14, -4), R(-2, 4), L(64, 2, 4), L(26, -4, -30), LEGS(4)),
    M1POSE(R(-10, -2), R(0, 2), L(72, 2, 6), L(28, -4, -30), LEGS(2)),
)
# Finisher: a palm strike, body turned into it, a wave bursting off the palm.
TIDAL_PALM = swing(
    M1POSE(R(2, -30), R(4, 24), L(-24, 0, 20), L(70, -24, 0), LEGS(26)),
    M1POSE(R(-6, -6), R(4, 6), L(60, 4, 10), L(50, -10, -14), LEGS(6)),
    M1POSE(R(-14, 26), R(6, -20), L(92, 10, 0), L(-30, 0, -24), LEGS(-24)),
    M1POSE(R(-10, 20), R(6, -16), L(88, 10, 2), L(-24, 0, -24), LEGS(-18)),
    heavy=True,
)
# Finisher (jump held): low, then the right hand swept up as a geyser bursts.
GEYSER = swing(
    M1POSE(R(-20, 18), R(14, -12), L(-12, 18, 30), L(30, -10, -30), LEGS(-14)),
    M1POSE(R(-6, 6), R(6, -4), L(100, 6, 12), L(36, -8, -30), LEGS(-4)),
    M1POSE(R(10, -8), R(-10, 6), L(176, -8, 10), L(40, 0, -42), LEGS(8)),
    M1POSE(R(6, -6), R(-6, 4), L(160, -6, 10), L(38, 0, -40), LEGS(6)),
    heavy=True,
)
# Finisher (in the air): both hands from overhead brought down, a torrent.
TORRENT = swing(
    {'Torso': R(14), 'Head': R(-8), 'RightArm': L(170, 10, 10), 'LeftArm': L(170, -10, -10)},
    {'Torso': R(0), 'Head': R(0), 'RightArm': L(115, 10, 4), 'LeftArm': L(115, -10, -4)},
    {'Torso': R(-30), 'Head': R(16), 'RightArm': L(40, 12, 4), 'LeftArm': L(40, -12, -4)},
    {'Torso': R(-24), 'Head': R(12), 'RightArm': L(48, 12, 4), 'LeftArm': L(48, -12, -4)},
    heavy=True,
)

# ---------------- Base: Water Princess ----------------
# Sea Dragon's Waterball: both hands lifted as the water gathers into
# spheres (0.2), then thrown: right (0.32), left (0.5), and the big one with
# both hands from overhead (0.68).
BALL_GATHER = pose(R(4, 0), R(12, 0), L(132, 0, 38), L(132, 0, -38), R(-8, 0, 6), R(8, 0, -6))
BALL_THROW_R = pose(R(-8, 18), R(6, -14), L(96, 8, 0), L(120, 0, -40), R(-14, 0, 6), R(14, 0, -6))
BALL_THROW_L = pose(R(-8, -16), R(6, 12), L(64, 0, 20), L(96, -8, 0), R(-14, 0, 6), R(14, 0, -6))
BALL_LIFT = pose(R(6, 0), R(14, 0), L(164, 10, 10), L(164, -10, -10), R(-10, 0, 6), R(10, 0, -6))
BALL_THROW_BIG = pose(R(-14, 0), R(4, 0), L(96, 12, 0), L(96, -12, 0), R(-20, 0, 8), R(20, 0, -8))
WATERBALL = [(0.0, STANCE), (0.2, BALL_GATHER), (0.3, BALL_GATHER), (0.36, BALL_THROW_R), (0.46, BALL_THROW_R),
             (0.54, BALL_THROW_L), (0.62, BALL_LIFT), (0.7, BALL_THROW_BIG), (1.0, BALL_THROW_BIG)]
# In the air: knees up, thrown down at them.
BALL_GATHER_AIR = pose(R(0, 0), R(14, 0), L(132, 0, 38), L(132, 0, -38), R(30, 0, 4), R(-6, 0, -4))
BALL_THROW_R_AIR = pose(R(-20, 18), R(18, -14), L(64, 8, 0), L(120, 0, -40), R(26, 0, 4), R(-8, 0, -4))
BALL_THROW_L_AIR = pose(R(-20, -16), R(18, 12), L(50, 0, 20), L(64, -8, 0), R(26, 0, 4), R(-8, 0, -4))
BALL_LIFT_AIR = pose(R(2, 0), R(16, 0), L(164, 10, 10), L(164, -10, -10), R(30, 0, 4), R(-4, 0, -4))
BALL_THROW_BIG_AIR = pose(R(-28, 0), R(22, 0), L(60, 12, 0), L(60, -12, 0), R(20, 0, 4), R(-10, 0, -4))
WATERBALL_AIR = [(0.0, AIR[0][1]), (0.2, BALL_GATHER_AIR), (0.3, BALL_GATHER_AIR), (0.36, BALL_THROW_R_AIR),
                 (0.46, BALL_THROW_R_AIR), (0.54, BALL_THROW_L_AIR), (0.62, BALL_LIFT_AIR),
                 (0.7, BALL_THROW_BIG_AIR), (1.0, BALL_THROW_BIG_AIR)]

# Sea Dragon's Roar: the right hand raised to the sky as the dragon's head
# forms over her, arched back under its weight (0.3 to 0.55); then swept
# down at them as it leaves.
ROAR_SUMMON = pose(R(8, 12), R(18, -8), L(166, -4, 14), L(30, 0, -36), R(-12, 0, 6), R(12, 0, -6))
ROAR_HELD = pose(R(10, 14), R(20, -10), L(170, -4, 16), L(32, 0, -38), R(-12, 0, 6), R(12, 0, -6))
ROAR_SEND = pose(R(-12, -6), R(4, 4), L(100, -4, 4), L(20, 0, -32), R(-20, 0, 8), R(20, 0, -8))
ROAR = [(0.0, STANCE), (0.3, ROAR_SUMMON), (0.55, ROAR_HELD), (0.62, ROAR_SEND), (0.95, ROAR_SEND)]
ROAR_SUMMON_AIR = pose(R(4, 12), R(20, -8), L(166, -4, 14), L(30, 0, -36), R(30, 0, 4), R(-6, 0, -4))
ROAR_HELD_AIR = pose(R(6, 14), R(22, -10), L(170, -4, 16), L(32, 0, -38), R(30, 0, 4), R(-6, 0, -4))
ROAR_SEND_AIR = pose(R(-22, -6), R(16, 4), L(70, -4, 4), L(20, 0, -32), R(22, 0, 4), R(-10, 0, -4))
ROAR_AIR = [(0.0, AIR[0][1]), (0.3, ROAR_SUMMON_AIR), (0.55, ROAR_HELD_AIR), (0.62, ROAR_SEND_AIR),
            (0.95, ROAR_SEND_AIR)]

# Point-Blank Sea Dragon's Roar: the right palm drawn back to her hip, the
# left hand out in front (0.12 to 0.25); then the palm driven out at them,
# the left hand bracing the right arm, and the recoil rocks her back.
BLANK_DRAW = pose(R(0, -28), R(4, 22), L(-26, 0, 22), L(78, -12, 0), R(-18, 0, 6), R(16, 0, -6))
BLANK_FIRE = pose(R(-12, 18), R(8, -14), L(92, 8, 0), L(86, -40, 0), R(-24, 0, 8), R(22, 0, -8))
BLANK_RECOIL = pose(R(6, 14), R(2, -10), L(98, 8, 2), L(90, -38, 0), R(-24, 0, 8), R(22, 0, -8))
BLANK = [(0.0, STANCE), (0.12, BLANK_DRAW), (0.25, BLANK_DRAW), (0.3, BLANK_FIRE), (0.42, BLANK_RECOIL),
         (0.75, BLANK_RECOIL)]
BLANK_DRAW_AIR = pose(R(-4, -28), R(10, 22), L(-26, 0, 22), L(60, -12, 0), R(30, 0, 4), R(-6, 0, -4))
BLANK_FIRE_AIR = pose(R(-30, 18), R(24, -14), L(56, 8, 0), L(52, -40, 0), R(20, 0, 4), R(-12, 0, -4))
BLANK_RECOIL_AIR = pose(R(-10, 14), R(14, -10), L(64, 8, 2), L(58, -38, 0), R(26, 0, 4), R(-8, 0, -4))
BLANK_AIR = [(0.0, AIR[0][1]), (0.12, BLANK_DRAW_AIR), (0.25, BLANK_DRAW_AIR), (0.3, BLANK_FIRE_AIR),
             (0.42, BLANK_RECOIL_AIR), (0.75, BLANK_RECOIL_AIR)]

# Sea Dragon's Nest: both arms raised up and out, palms out, holding the dome.
NEST_HOLD = pose(R(4), R(10), L(148, 0, 48), L(148, 0, -48), R(-10, 0, 8), R(10, 0, -8))
NEST_BREATH = pose(R(5), R(12), L(152, 0, 52), L(152, 0, -52), R(-10, 0, 8), R(10, 0, -8))
NEST = [(0.0, STANCE), (0.2, NEST_HOLD), (1.35, NEST_BREATH), (2.5, NEST_HOLD)]

# Sea Dragon's Cradle: curled up inside the sphere, knees drawn up, arms
# folded across them, head bowed.
CRADLE_CURL = pose(R(-16), R(-12), L(64, 44, 0), L(64, -44, 0), R(64, 0, 4), R(56, 0, -4))
CRADLE = [(0.0, CRADLE_CURL), (0.8, CRADLE_CURL)]

# Entrance: arms folded and chin up, looking away (0.3 to 1.1) while the
# water rises round her; then a sweep of the arm (1.4) and she points at
# them, the other hand on her hip (1.75); and back to her stance.
ENTRANCE_FOLD = pose(R(-2, 6), R(10, 34), L(70, 52, 0), L(66, -52, 0))
ENTRANCE_SWEEP = pose(R(-4, -12), R(8, -8), L(100, -80, 12), L(-14, 0, -30))
ENTRANCE_POINT = pose(R(-4, -10), R(6, 4), L(96, 2, 0), L(-14, 0, -32), R(6, 0, 3), R(-6, -8, -3))
ENTRANCE = [(0.0, STANCE), (0.3, ENTRANCE_FOLD), (1.1, ENTRANCE_FOLD), (1.4, ENTRANCE_SWEEP), (1.75, ENTRANCE_POINT),
            (2.0, ENTRANCE_POINT), (2.2, STANCE)]

# ---------------- Transformations ----------------
# Valkyrie Dress: arms folded over her chest as the water wraps round her
# (0.3), flung out wide as the armor forms on the burst (0.8), then up into
# the hover.
GATHER = pose(R(-10), R(-14), L(70, 50, 0), L(66, -50, 0), R(-10, 0, 6), R(10, 0, -6))
BURST = pose(R(8), R(16), L(122, 0, 66), L(122, 0, -66), R(-14, 0, 8), R(14, 0, -8))
AWAKEN = [(0.0, STANCE), (0.3, GATHER), (0.8, BURST), (1.1, BURST), (1.5, HOVER_LOW)]
# Dragon Form: the same, arms thrown to the sky as the dragon forms.
ASCEND_BURST = pose(R(12), R(24), L(174, 0, 18), L(174, 0, -18), R(-16, 0, 8), R(16, 0, -8))
ASCEND = [(0.0, HOVER_LOW), (0.35, GATHER), (0.8, ASCEND_BURST), (1.15, ASCEND_BURST), (1.5, HOVER_LOW)]

# ---------------- Valkyrie Dress ----------------
# Valkyrie Lance: coiled, the lance drawn back at her hip, the left hand out
# at them (0.14); the charge, flat out behind the lance; the drill (three
# twists); the last thrust, all the way through.
LANCE_COIL = pose(R(-8, -26), R(6, 20), L(36, -10, 24), L(82, -20, 0), R(-20, 0, 6), R(16, 0, -6))
LANCE_CHARGE = pose(R(-30, 8), R(24, -6), L(88, 4, 0), L(-40, 0, -30), R(-34, 0, 4), R(-18, 0, -4))
LANCE_TWIST_A = pose(R(-24, 14), R(20, -10), L(90, 6, 0), L(-34, 0, -30), R(-30, 0, 4), R(-14, 0, -4))
LANCE_TWIST_B = pose(R(-26, 2), R(22, -2), L(86, 2, 0), L(-38, 0, -28), R(-30, 0, 4), R(-14, 0, -4))
LANCE_THRUST = pose(R(-36, 18), R(28, -12), L(94, 6, 0), L(-48, 0, -32), R(-40, 0, 4), R(-20, 0, -4))
LANCE_READY = [(0.0, HOVER_LOW), (0.14, LANCE_COIL), (0.2, LANCE_COIL)]
LANCE_RUSH = [(0.0, LANCE_COIL), (0.08, LANCE_CHARGE), (0.5, LANCE_CHARGE)]
LANCE_DRILL = [(0.0, LANCE_CHARGE), (0.05, LANCE_TWIST_A), (0.1, LANCE_TWIST_B), (0.15, LANCE_TWIST_A),
               (0.2, LANCE_TWIST_B), (0.25, LANCE_TWIST_A), (0.3, LANCE_TWIST_B)]
LANCE_FINISH = [(0.0, LANCE_TWIST_B), (0.07, LANCE_THRUST), (0.45, LANCE_THRUST)]

# Lance of the Sea Dragon: turned side-on, the lance raised back over her
# shoulder like a javelin, the left hand aimed at them (0.4); then hurled,
# her whole body turning through it.
HURL_DRAW = pose(R(8, -40), R(6, 34), L(158, -6, 26), L(88, 14, -8), R(-16, 0, 6), R(16, 0, -6))
HURL_THROW = pose(R(-16, 22), R(10, -16), L(92, 10, 0), L(-22, 0, -30), R(-24, 0, 8), R(22, 0, -8))
HURL = [(0.0, HOVER_LOW), (0.4, HURL_DRAW), (0.47, HURL_THROW), (0.8, HURL_THROW)]

# Mermaid Dive: arms together over her head, legs together (the tail), the
# client pitching her into the water; she bursts out with her arms flung
# wide and settles.
DIVE_STREAM = pose(R(0), R(4), L(176, 10, 0), L(176, -10, 0), R(0, 0, 2), R(0, 0, -2))
DIVE_ERUPT = pose(R(10), R(14), L(136, 0, 64), L(136, 0, -64), R(-4, 0, 2), R(-8, 0, -2))
MERMAID = [(0.0, HOVER_LOW), (0.12, DIVE_STREAM), (0.95, DIVE_STREAM), (1.1, DIVE_ERUPT), (1.5, DIVE_ERUPT)]

# ---------------- Dragon Form ----------------
# Sea Dragon God's Tail: arched back, both arms raised as the tail rises up
# behind her (0.35); then folded forward as it comes down over her.
TAIL_RAISE = pose(R(14, 8), R(16, -6), L(160, 0, 30), L(160, 0, -30), R(-12, 0, 6), R(12, 0, -6))
TAIL_SLAM = pose(R(-30, -4), R(20, 2), L(44, 6, 12), L(44, -6, -12), R(-26, 0, 8), R(24, 0, -8))
TAIL = [(0.0, HOVER_LOW), (0.3, TAIL_RAISE), (0.35, TAIL_RAISE), (0.43, TAIL_SLAM), (0.8, TAIL_SLAM)]

# Sea Dragon God's Vortex: arms out, spinning like a whirlpool (five turns),
# then flung up as it bursts.
VORTEX_OUT = lambda turn: pose(R(-4, turn), R(6), L(92, 0, 72), L(92, 0, -72), R(-4, 0, 4), R(-4, 0, -4))
VORTEX = [(0.0, HOVER_LOW)] + [(round(0.1 + i * 0.075, 3), VORTEX_OUT(i * 90)) for i in range(21)]
VORTEX_BURST = pose(R(10), R(16), L(170, 0, 30), L(170, 0, -30), R(-8, 0, 6), R(-12, 0, -6))
VORTEX_END = [(0.0, VORTEX_OUT(0)), (0.08, VORTEX_BURST), (0.5, VORTEX_BURST)]

SINE_IO = ('Sine', 'InOut'); QUAD_IN = ('Quad', 'In'); QUART_OUT = ('Quart', 'Out')
SINE_OUT = ('Sine', 'Out'); LINEAR = ('Linear', 'Out'); BACK_OUT = ('Back', 'Out')

def snap(n):
    """Wind-up then a snappy hit, then hold."""
    return [None, SINE_OUT, QUART_OUT] + [SINE_IO] * (n - 3)

SWING_EASE = [None, None, SINE_IO, QUAD_IN, QUART_OUT]
BALL_EASE = [None, SINE_OUT, LINEAR, QUART_OUT, LINEAR, QUART_OUT, SINE_OUT, QUART_OUT, SINE_IO]

SPEC = {
    'Idle': dict(keys=IDLE, ease=[None, SINE_IO, SINE_IO], loop=True, delays={'Head': 0.12, 'RightArm': 0.1, 'LeftArm': 0.2},
                 doc="Standing: proud, chin up, the left hand on her hip."),
    'Run': dict(keys=RUN, ease=[None] + [LINEAR] * (len(RUN) - 1), loop=True, delays={'Head': 0.03, 'RightArm': 0.03, 'LeftArm': 0.03},
                doc="Moving: a light run. Plays with the distance travelled (RUN_STRIDE studs a loop)."),
    'Walk': dict(keys=WALK, ease=[None] + [LINEAR] * (len(WALK) - 1), loop=True, delays={'Head': 0.03, 'RightArm': 0.03, 'LeftArm': 0.03},
                 doc="Moving slowly (casting, blocking): an easy walk, same phase as the run."),
    'Air': dict(keys=AIR, ease=[None], loop=True, doc="Jumping or falling: arms out, one foot drawn up."),
    'HoverIdle': dict(keys=HOVER_IDLE, ease=[None, SINE_IO, SINE_IO], loop=True,
                      doc="Awakened: held up on a stream of water, the lance upright in her hand."),
    'HoverMove': dict(keys=HOVER_MOVE, ease=[None, SINE_IO, SINE_IO], loop=True,
                      doc="Awakened: gliding on the stream, leaning into it."),
    'Lash1': dict(keys=LASH1, ease=SWING_EASE, additive=['RightLeg', 'LeftLeg'], fadeIn=SWING_TIMES[0], fadeOut=0.22,
                  events=[(SWING_TIMES[1], 'Strike')], doc="M1 1: a backhand whip of water."),
    'Lash2': dict(keys=LASH2, ease=SWING_EASE, additive=['RightLeg', 'LeftLeg'], fadeIn=SWING_TIMES[0], fadeOut=0.22,
                  events=[(SWING_TIMES[1], 'Strike')], doc="M1 2: the left hand the other way."),
    'Lash3': dict(keys=LASH3, ease=SWING_EASE, additive=['RightLeg', 'LeftLeg'], fadeIn=SWING_TIMES[0], fadeOut=0.22,
                  events=[(SWING_TIMES[1], 'Strike')], doc="M1 3: overhead, a whip crack."),
    'TidalPalm': dict(keys=TIDAL_PALM, ease=SWING_EASE, additive=['RightLeg', 'LeftLeg'], fadeIn=HEAVY_SWING_TIMES[0], fadeOut=0.28,
                      events=[(HEAVY_SWING_TIMES[1], 'Strike')], doc="Finisher: a palm strike, a wave bursting off it."),
    'Geyser': dict(keys=GEYSER, ease=SWING_EASE, additive=['RightLeg', 'LeftLeg'], fadeIn=HEAVY_SWING_TIMES[0], fadeOut=0.28,
                   events=[(HEAVY_SWING_TIMES[1], 'Strike')], doc="Finisher (jump held): a geyser under them."),
    'Torrent': dict(keys=TORRENT, ease=SWING_EASE, fadeIn=HEAVY_SWING_TIMES[0], fadeOut=0.28,
                    events=[(HEAVY_SWING_TIMES[1], 'Strike')], doc="Finisher (in the air): a torrent brought down on them."),
    'Waterball': dict(keys=WATERBALL, ease=BALL_EASE, fadeOut=0.25, doc="Sea Dragon's Waterball: water gathered overhead, three spheres thrown."),
    'WaterballAir': dict(keys=WATERBALL_AIR, ease=BALL_EASE, fadeOut=0.25, doc="Sea Dragon's Waterball in the air: thrown down at them."),
    'Roar': dict(keys=ROAR, ease=[None, SINE_OUT, SINE_IO, QUART_OUT, SINE_IO], fadeOut=0.3, doc="Sea Dragon's Roar: the head forms over her raised hand, then she sends it."),
    'RoarAir': dict(keys=ROAR_AIR, ease=[None, SINE_OUT, SINE_IO, QUART_OUT, SINE_IO], fadeOut=0.3, doc="Sea Dragon's Roar in the air."),
    'Blank': dict(keys=BLANK, ease=[None, SINE_OUT, LINEAR, QUART_OUT, SINE_OUT, SINE_IO], fadeOut=0.3, doc="Point-Blank Sea Dragon's Roar: the palm drawn back, driven out, the recoil."),
    'BlankAir': dict(keys=BLANK_AIR, ease=[None, SINE_OUT, LINEAR, QUART_OUT, SINE_OUT, SINE_IO], fadeOut=0.3, doc="Point-Blank Sea Dragon's Roar in the air, at them below."),
    'Nest': dict(keys=NEST, ease=[None, SINE_OUT, SINE_IO, SINE_IO], fadeOut=0.25, doc="Sea Dragon's Nest: arms up and out, holding the dome."),
    'Cradle': dict(keys=CRADLE, ease=[None, LINEAR], fadeIn=0.08, fadeOut=0.2, doc="Sea Dragon's Cradle: curled up inside the sphere."),
    'Entrance': dict(keys=ENTRANCE, ease=[None, SINE_IO, LINEAR, SINE_OUT, QUART_OUT, LINEAR, SINE_IO], fadeOut=0.25,
                     doc="Spawn entrance: arms folded, looking away while the water rises, then she points at them."),
    'Awaken': dict(keys=AWAKEN, ease=[None, SINE_OUT, BACK_OUT, LINEAR, SINE_IO], fadeOut=0.2, doc="Valkyrie Dress: the water wraps her, the armor forms on the burst."),
    'Ascend': dict(keys=ASCEND, ease=[None, SINE_OUT, BACK_OUT, LINEAR, SINE_IO], fadeOut=0.2, doc="Dragon Form: the same, arms thrown to the sky."),
    'LanceReady': dict(keys=LANCE_READY, ease=[None, SINE_OUT, LINEAR], fadeOut=0.05, doc="Valkyrie Lance: coiled, lance at her hip."),
    'LanceRush': dict(keys=LANCE_RUSH, ease=[None, QUART_OUT, LINEAR], fadeIn=0.02, fadeOut=0.15, doc="Valkyrie Lance: the charge."),
    'LanceDrill': dict(keys=LANCE_DRILL, ease=[None] + [SINE_IO] * 6, fadeIn=0.02, fadeOut=0.05, doc="Valkyrie Lance: the drill, three twists."),
    'LanceFinish': dict(keys=LANCE_FINISH, ease=[None, QUART_OUT, LINEAR], fadeIn=0.02, fadeOut=0.3, doc="Valkyrie Lance: the last thrust."),
    'Hurl': dict(keys=HURL, ease=[None, SINE_OUT, QUART_OUT, SINE_IO], fadeOut=0.3, doc="Lance of the Sea Dragon: the javelin throw."),
    'Mermaid': dict(keys=MERMAID, ease=[None, SINE_OUT, LINEAR, QUART_OUT, SINE_IO], fadeIn=0.05, fadeOut=0.3, doc="Mermaid Dive: streamlined dive, bursting out of the geyser."),
    'Tail': dict(keys=TAIL, ease=[None, SINE_OUT, LINEAR, QUAD_IN, SINE_IO], fadeOut=0.3, doc="Sea Dragon God's Tail: arched back, then folded over as it slams."),
    'Vortex': dict(keys=VORTEX, ease=[None, SINE_OUT] + [LINEAR] * (len(VORTEX) - 2), fadeIn=0.05, fadeOut=0.05, doc="Sea Dragon God's Vortex: spinning like a whirlpool."),
    'VortexEnd': dict(keys=VORTEX_END, ease=[None, QUART_OUT, SINE_IO], fadeIn=0.02, fadeOut=0.3, doc="Sea Dragon God's Vortex: flung up as it bursts."),
}

# Life for the spell casts (as in yuno_anims.py): past each pose a little,
# eased back onto it, and through a long hold a slow breath.
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

def lively(spec, k=0.14):
    keys, ease = list(spec['keys']), list(spec['ease'])
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
        added.append((t + min(0.07, room * 0.3), over, SINE_OUT))
        added.append((t + min(0.2, room * 0.7), pose_, SINE_IO))
    if held and room >= 0.6:
        mid = t + 0.2 + (room - 0.2) / 2
        added.append((mid, _breath(pose_, 1), SINE_IO))
    if not added:
        return
    tail = keys[i + 1:]
    tail_ease = ease[i + 1:]
    keys = keys[:i + 1] + [(a[0], a[1]) for a in added] + tail
    ease = ease[:i + 1] + [a[2] for a in added] + [SINE_IO if held else e for e in tail_ease]
    spec['keys'], spec['ease'] = keys, ease

for _name in ('Waterball', 'WaterballAir', 'Roar', 'RoarAir', 'Blank', 'BlankAir', 'LanceFinish', 'Hurl', 'Tail', 'VortexEnd'):
    lively(SPEC[_name])

# Played in the air (not planted, feet not checked); the run sets its own height.
AIRBORNE = {'Air', 'WaterballAir', 'RoarAir', 'BlankAir', 'Torrent', 'Cradle', 'HoverIdle', 'HoverMove', 'LanceRush',
            'LanceDrill', 'LanceFinish', 'Mermaid', 'Vortex', 'VortexEnd', 'Tail', 'Hurl', 'LanceReady', 'Ascend'}
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
