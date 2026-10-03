import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
"""Emits src/client/Kits/AntiMagic/Animations.luau from asta_anims.py."""
from asta_anims import *

SINE_IO = ('Sine', 'InOut'); QUAD_IN = ('Quad', 'In'); QUART_OUT = ('Quart', 'Out')
SINE_OUT = ('Sine', 'Out'); LINEAR = ('Linear', 'Out'); QUAD_OUT = ('Quad', 'Out')

SWING_EASE = [None, SINE_IO, QUAD_IN, QUART_OUT, SINE_OUT]
OVERLAP = {'Head': -0.01, 'RightArm': 0.012, 'LeftArm': 0.02, 'Sword': 0.03}

SPEC = {
    'Idle': dict(keys=IDLE, ease=[None, SINE_IO, SINE_IO], loop=True,
                 delays={'Head': 0.12, 'RightArm': 0.08, 'Sword': 0.16, 'LeftArm': 0.2},
                 doc="Standing still: wide stance, sword resting on the right shoulder, slow breathing."),
    'Run': dict(keys=RUN, ease=[None, SINE_IO, SINE_IO, SINE_IO, SINE_IO], loop=True,
                delays={'Head': 0.04, 'Sword': 0.05, 'LeftArm': 0.02},
                doc="Moving: forward-leaning run, sword bobbing on the shoulder. Speeds up with movement speed."),
    'Walk': dict(keys=WALK, ease=[None, SINE_IO, SINE_IO, SINE_IO, SINE_IO], loop=True,
                 delays={'Head': 0.05, 'Sword': 0.07, 'LeftArm': 0.03},
                 doc="Moving slowly (attacking, blocking, casting): upright walk, same step timing as the run."),
    'Air': dict(keys=AIR, ease=[None], loop=True,
                doc="Jumping or falling: knee up, free arm out for balance."),
    'Slash1': dict(keys=SLASH1, ease=SWING_EASE, additive=['RightLeg','LeftLeg'], delays=OVERLAP, fadeOut=0.22,
                   doc="M1 1: right to left horizontal slash."),
    'Slash2': dict(keys=SLASH2, ease=SWING_EASE, additive=['RightLeg','LeftLeg'], delays=OVERLAP, fadeOut=0.22,
                   doc="M1 2: backhand, left to right."),
    'Slash3': dict(keys=SLASH3, ease=SWING_EASE, additive=['RightLeg','LeftLeg'], delays=OVERLAP, fadeOut=0.22,
                   doc="M1 3: rising diagonal."),
    'Cleave': dict(keys=CLEAVE, ease=SWING_EASE, additive=['RightLeg','LeftLeg'], delays=OVERLAP, fadeOut=0.28,
                   doc="Finisher: huge horizontal cleave that wraps around the body."),
    'Rising': dict(keys=RISING, ease=SWING_EASE, additive=['RightLeg','LeftLeg'], delays=OVERLAP, fadeOut=0.28,
                   doc="Finisher (jump held): rising vertical slash."),
    'Chop': dict(keys=CHOP, ease=SWING_EASE, delays=OVERLAP, fadeOut=0.28,
                 doc="Finisher (airborne): two-handed overhead chop."),
    'DashFront': dict(keys=DASH_FRONT, ease=[None, QUART_OUT, SINE_OUT], fadeIn=0.03, fadeOut=0.16,
                      delays={'Sword': 0.03}, doc="Front dash: leaning hard into it, sword trailing low behind."),
    'DashBack': dict(keys=DASH_BACK, ease=[None, QUART_OUT, SINE_OUT], fadeIn=0.03, fadeOut=0.16,
                     delays={'Sword': 0.03}, doc="Back dash: leaning back, sword held out in front."),
    'DashLeft': dict(keys=DASH_LEFT, ease=[None, QUART_OUT, SINE_OUT], fadeIn=0.03, fadeOut=0.16,
                     delays={'Sword': 0.03}, doc="Left dash: leaning left, sword trailing to the right."),
    'DashRight': dict(keys=DASH_RIGHT, ease=[None, QUART_OUT, SINE_OUT], fadeIn=0.03, fadeOut=0.16,
                      delays={'Sword': 0.03}, doc="Right dash: leaning right, sword trailing to the left."),
    'FlinchA': dict(keys=FLINCH_A, ease=[None, QUART_OUT, SINE_OUT], fadeIn=0.02, fadeOut=0.2,
                    additive=['RightLeg', 'LeftLeg'], delays={'Head': -0.01, 'Sword': 0.02},
                    doc="Hit from the front (alternates with FlinchB)."),
    'FlinchB': dict(keys=FLINCH_B, ease=[None, QUART_OUT, SINE_OUT], fadeIn=0.02, fadeOut=0.2,
                    additive=['RightLeg', 'LeftLeg'], delays={'Head': -0.01, 'Sword': 0.02},
                    doc="Hit from the front, other side."),
    'FlinchBack': dict(keys=FLINCH_BACK, ease=[None, QUART_OUT, SINE_OUT], fadeIn=0.02, fadeOut=0.2,
                       additive=['RightLeg', 'LeftLeg'], doc="Hit from behind: thrown forward."),
    'HitHeavy': dict(keys=HIT_HEAVY, ease=[None, QUART_OUT, SINE_IO], fadeIn=0.02, fadeOut=0.25,
                     additive=['RightLeg', 'LeftLeg'], doc="Big hit that doesn't knock down (e.g. launched by an uppercut)."),
    'Guard': dict(keys=GUARD, ease=[None, QUART_OUT, LINEAR], fadeIn=0.05, fadeOut=0.15,
                  doc="Blocking: sword across the chest. Held until the block ends."),
    'GuardHit': dict(keys=GUARD_HIT, ease=[None, QUART_OUT, SINE_OUT, LINEAR], fadeIn=0.02, fadeOut=0.15,
                     doc="A blocked hit pushes the guard back, then it holds again."),
    'Stagger': dict(keys=STAGGER, ease=[None, QUART_OUT, LINEAR, SINE_IO], fadeIn=0.02, fadeOut=0.25,
                    doc="Guard broken or parried: thrown off balance."),
    'Propel': dict(keys=PROPEL, ease=[None, QUART_OUT, SINE_OUT], fadeIn=0.03, fadeOut=0.1,
                   delays={'Sword': 0.02}, doc="Bull Thrust: propelling forward, sword thrust ahead."),
    'Barrage': dict(keys=BARRAGE, ease=[None] + [('Quad', 'InOut')] * len(BARRAGE_STEPS) + [QUART_OUT, LINEAR],
                    fadeIn=0.03, fadeOut=0.2, additive=['RightLeg', 'LeftLeg'], delays={'Sword': 0.015, 'Head': -0.01},
                    doc="Bull Thrust: rapid slash flurry ending in a pushing thrust."),
    'MeteorLunge': dict(keys=METEOR_LUNGE, ease=[None, QUART_OUT, SINE_OUT], fadeIn=0.03, fadeOut=0.1,
                        delays={'Sword': 0.03}, doc="Black Meteorite: lunging grab, free hand reaching out."),
    'MeteorRise': dict(keys=METEOR_RISE, ease=[None, QUAD_OUT, SINE_IO], fadeIn=0.05, fadeOut=0.1,
                       delays={'Sword': 0.04}, doc="Black Meteorite: rising with the victim, sword drawn back overhead."),
    'MeteorSlam': dict(keys=METEOR_SLAM, ease=[None, QUAD_IN, LINEAR], fadeIn=0.02, fadeOut=0.1,
                       doc="Black Meteorite: crashing down, sword driven into the ground."),
    'MeteorImpact': dict(keys=METEOR_IMPACT, ease=[None, SINE_OUT, LINEAR], fadeIn=0.02, fadeOut=0.3,
                         doc="Black Meteorite: rising out of the crater."),
    'DividerCharge': dict(keys=DIVIDER_CHARGE, ease=[None, SINE_IO, SINE_IO, SINE_IO, SINE_IO], fadeIn=0.05,
                          fadeOut=0.05, additive=['RightLeg', 'LeftLeg'], delays={'Sword': 0.02},
                          doc="Black Divider: coiled, sword drawn back low, trembling with anti-magic."),
    'DividerRelease': dict(keys=DIVIDER_RELEASE, ease=[None, QUAD_IN, QUART_OUT, SINE_OUT], fadeIn=0.01,
                           fadeOut=0.28, additive=['RightLeg', 'LeftLeg'], delays={'Sword': 0.02, 'Head': -0.01},
                           doc="Black Divider: the cleave, wrapping all the way around."),
    'DeflectStance': dict(keys=DEFLECT_STANCE, ease=[None, QUART_OUT, LINEAR], fadeIn=0.03, fadeOut=0.15,
                          doc="Anti-Magic Deflect: blade held upright in front, braced."),
    'DeflectCounter': dict(keys=DEFLECT_COUNTER, ease=[None, QUAD_OUT, QUART_OUT, LINEAR], fadeIn=0.01,
                           fadeOut=0.25, delays={'Sword': 0.015},
                           doc="Anti-Magic Deflect: the counter slash, down and across."),
    'DeflectReflect': dict(keys=DEFLECT_REFLECT, ease=[None, QUAD_OUT, QUART_OUT, LINEAR], fadeIn=0.01,
                           fadeOut=0.25, delays={'Sword': 0.015},
                           doc="Anti-Magic Deflect: swatting a projectile back."),
    'Awaken': dict(keys=AWAKEN, ease=[None, SINE_IO, SINE_IO, SINE_IO, SINE_IO, QUART_OUT, LINEAR, SINE_IO, LINEAR],
                   fadeIn=0.05, fadeOut=0.3, delays={'Head': 0.03, 'Sword': 0.04},
                   events=[(0.92, 'Burst'), (1.55, 'Stance')],
                   doc="Black Form: hunched over the planted sword, trembling, then a roar and the burst, ending in a stance."),
    'Leap': dict(keys=LEAP, ease=[None, QUAD_OUT, QUART_OUT, LINEAR], fadeIn=0.03, fadeOut=0.25,
                 delays={'Sword': 0.03}, doc="Anti-Magic Leap (R): coiled crouch, then launching, free arm reaching ahead."),
    'Plunge': dict(keys=PLUNGE, ease=[None, SINE_OUT, QUAD_IN, LINEAR], fadeIn=0.03, fadeOut=0.1,
                   delays={'Sword': 0.02}, doc="Meteor Plunge (R in the air): sword raised overhead, then diving behind it."),
    'PlungeImpact': dict(keys=PLUNGE_IMPACT, ease=[None, LINEAR, SINE_IO], fadeIn=0.03, fadeOut=0.3,
                         doc="Meteor Plunge: the sword stabbed into the ground."),
    'AirDividerCharge': dict(keys=AIR_DIVIDER_CHARGE, ease=[None, SINE_IO, SINE_IO, SINE_IO, SINE_IO], fadeIn=0.05,
                             fadeOut=0.05, delays={'Sword': 0.02},
                             doc="Air Black Divider: hanging in the air, sword cocked overhead."),
    'AirDividerRelease': dict(keys=AIR_DIVIDER_RELEASE, ease=[None, QUAD_IN, LINEAR, LINEAR, QUART_OUT, LINEAR],
                              fadeIn=0.01, fadeOut=0.3, delays={'Sword': 0.01},
                              doc="Air Black Divider: a front flip carrying the blade in a full circle, down onto them."),
    'Entrance': dict(keys=ENTRANCE,
                     ease=[None, LINEAR, SINE_IO, SINE_IO, QUART_OUT, LINEAR, LINEAR, LINEAR, LINEAR, LINEAR,
                           SINE_IO, QUAD_IN, SINE_OUT, SINE_IO],
                     delays={'Sword': 0.025, 'Head': -0.02},
                     events=[(0.30, 'Grimoire'), (1.0, 'Draw'), (1.70, 'Slam'), (2.25, 'Settle')],
                     fadeIn=0.08, fadeOut=0.25,
                     doc="Spawn entrance: crouched landing, grimoire appears, sword drawn from it, twirled overhead, slammed into the ground, rested on the shoulder."),
}

def num(v):
    s = ("%.3f" % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s

def value(v):
    kind, *args = v
    while kind in ('rot', 'limb') and len(args) > 1 and args[-1] == 0:
        args = args[:-1]
    return f"{kind}({', '.join(num(a) for a in args)})"

ORDER = ['Torso', 'Head', 'RightArm', 'Sword', 'LeftArm', 'RightLeg', 'LeftLeg']

def emit_pose(pose, indent):
    lines = [indent + "{"]
    for k in ORDER:
        if k in pose:
            lines.append(f"{indent}\t{k} = {value(pose[k])},")
    lines.append(indent + "}")
    return "\n".join(lines)

out = ['''--[[
	Anti-Magic Knight animation data.

	GENERATED by tools/anim/emit.py from tools/anim/asta_anims.py. Every
	keyframe and the in-betweens are checked against an R6 model of the rig
	(blade clear of the body, tip above the floor), so edit the Python and
	re-run it instead of editing this file by hand.

	Each animation: keys = { {time, pose, easingStyle?, easingDirection?}, ... }
	  rot(x, y, z)          torso/head/leg rotation (degrees)
	  limb(pitch, yaw, roll) arm/leg aim (degrees)
	  aim(x, y, z)          which way the blade points, in character space
	                        (X right, Y up, -Z forward); the wrist is solved
	                        from it when the clip is built
]]

local rad = math.rad

local function rot(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end

local function limb(pitch: number, yaw: number?, roll: number?): CFrame
	return CFrame.Angles(0, rad(yaw or 0), 0) * CFrame.Angles(0, 0, rad(roll or 0)) * CFrame.Angles(rad(pitch), 0, 0)
end

local function aim(x: number, y: number, z: number): { aim: Vector3 }
	return { aim = Vector3.new(x, y, z) }
end

local Animations = {}
''']

for name, spec in SPEC.items():
    out.append(f"-- {spec['doc']}")
    out.append(f"Animations.{name} = {{")
    if spec.get('loop'): out.append("\tloop = true,")
    if 'fadeIn' in spec: out.append(f"\tfadeIn = {num(spec['fadeIn'])},")
    if 'fadeOut' in spec: out.append(f"\tfadeOut = {num(spec['fadeOut'])},")
    if spec.get('additive'):
        out.append("\tadditive = { " + ", ".join(f"{k} = true" for k in spec['additive']) + " },")
    if spec.get('delays'):
        out.append("\tdelays = { " + ", ".join(f"{k} = {num(v)}" for k, v in spec['delays'].items()) + " },")
    if spec.get('events'):
        out.append("\tevents = {")
        for t, e in spec['events']:
            out.append(f'\t\t{{ time = {num(t)}, name = "{e}" }},')
        out.append("\t},")
    out.append("\tkeys = {")
    for (t, pose), ease in zip(spec['keys'], spec['ease']):
        out.append("\t\t{")
        out.append(f"\t\t\t{num(t)},")
        out.append(emit_pose(pose, "\t\t\t") + ",")
        if ease:
            out.append(f'\t\t\t"{ease[0]}",')
            out.append(f'\t\t\t"{ease[1]}",')
        out.append("\t\t},")
    out.append("\t},")
    out.append("}\n")

out.append("return Animations\n")
import sys
open(sys.argv[1], 'w').write("\n".join(out))
print("wrote", sys.argv[1])
