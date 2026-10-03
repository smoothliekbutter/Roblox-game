"""Forward kinematics for a Roblox R6 rig + Asta's sword, mirroring
PoseAnimator: a pose P for a joint rotates the child around the joint in the
parent's space. World units are studs; the root (HRP) sits at the origin, so
the ground is at y = -3. Roblox axes: X right, Y up, -Z forward."""
import numpy as np
from math import radians, cos, sin

def Rx(a):
    c, s = cos(a), sin(a); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def Ry(a):
    c, s = cos(a), sin(a); return np.array([[c,0,s],[0,1,0],[-s,0,c]])
def Rz(a):
    c, s = cos(a), sin(a); return np.array([[c,-s,0],[s,c,0],[0,0,1]])

def cf(R=None, p=(0,0,0)):
    M = np.eye(4)
    if R is not None: M[:3,:3] = R
    M[:3,3] = p; return M
def T(x,y,z): return cf(None,(x,y,z))
def apply(M, v): return (M @ np.array([*v,1.0]))[:3]

# Pose helpers (same as the Luau ones)
def rot(x, y=0, z=0):  # CFrame.Angles = Rx*Ry*Rz
    return cf(Rx(radians(x)) @ Ry(radians(y)) @ Rz(radians(z)))
def limb(pitch, yaw=0, roll=0):
    return cf(Ry(radians(yaw)) @ Rz(radians(roll)) @ Rx(radians(pitch)))
def wrist(a, phi=0):
    """Blade at angle a (deg) forward of the arm's down direction, turned phi around the arm."""
    return cf(Ry(radians(phi)) @ Rx(radians(a - 35)))

GRIP = T(0,-1,0) @ cf(Rx(radians(215)))

def solve(pose):
    I = np.eye(4)
    torso = pose.get('Torso', I)                      # root space
    arm = torso @ T(1,0.5,0) @ pose.get('RightArm', I) @ T(0.5,-0.5,0)
    larm = torso @ T(-1,0.5,0) @ pose.get('LeftArm', I) @ T(-0.5,-0.5,0)
    head = torso @ T(0,1,0) @ pose.get('Head', I) @ T(0,0.5,0)
    rleg = torso @ T(1,-1,0) @ pose.get('RightLeg', I) @ T(-0.5,-1,0)
    lleg = torso @ T(-1,-1,0) @ pose.get('LeftLeg', I) @ T(0.5,-1,0)
    # Asta's sword: grip at the bottom of the arm; S rotates around the hand.
    sword = arm @ T(0,-1,0) @ pose.get('Sword', I) @ cf(Rx(radians(215)))
    hand = apply(arm, (0,-1,0))
    # Blade runs from just above the guard to the tip (see buildSword).
    base = apply(sword, (0,0.7,0))
    tip = apply(sword, (0,4.4,0))
    return dict(torso=torso, arm=arm, hand=hand, base=base, tip=tip,
                head=apply(head,(0,0,0)), lfoot=apply(lleg,(0,-1,0)), rfoot=apply(rleg,(0,-1,0)),
                lhand=apply(larm,(0,-1,0)))

def fmt(v): return "(%5.2f,%5.2f,%5.2f)" % tuple(v)

def report(name, pose):
    r = solve(pose)
    d = r['tip'] - r['base']; d /= np.linalg.norm(d)
    print(f"{name:18s} hand{fmt(r['hand'])} tip{fmt(r['tip'])} dir{fmt(d)} feet y {r['lfoot'][1]:.2f}/{r['rfoot'][1]:.2f}")
    return r

if __name__ == '__main__':
    # Sanity: neutral pose. Arm hangs: hand at (1.5,-1,0); feet at y=-3.
    report('neutral', {})
    # Current idle stance (limb(50,15)) with the default grip.
    report('old idle', {'RightArm': limb(50,15)})
