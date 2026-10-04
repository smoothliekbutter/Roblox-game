"""Asta's animation set as data. Verified with the FK model, then emitted as Luau.
Pose values are tuples so they can be both evaluated (Python) and printed (Luau):
  ('rot', x, y, z) | ('limb', pitch, yaw, roll) | ('aim', dx, dy, dz)  (blade direction in character space)
  ('body', dy, x, y, z)  the torso moved dy studs up/down (root space), then rotated
"""
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rig import *
import sys

GRIP_R = Rx(radians(215))
D0 = GRIP_R @ np.array([0,1,0])

def to_cf(v):
    kind = v[0]
    if kind == 'rot': return rot(*v[1:])
    if kind == 'limb': return limb(*v[1:])
    if kind == 'body': return T(0, v[1], 0) @ rot(*v[2:])
    raise ValueError(kind)

def aim_matrix(torso_cf, arm_cf, d):
    arm_rot = torso_cf[:3,:3] @ arm_cf[:3,:3]
    d = np.array(d, float); d /= np.linalg.norm(d)
    target = arm_rot.T @ d
    axis = np.cross(D0, target); s = np.linalg.norm(axis); c = np.clip(np.dot(D0, target), -1, 1)
    if s < 1e-6: return np.eye(4)
    axis /= s; ang = np.arccos(c)
    K = np.array([[0,-axis[2],axis[1]],[axis[2],0,-axis[0]],[-axis[1],axis[0],0]])
    R = np.eye(3) + np.sin(ang)*K + (1-np.cos(ang))*K@K
    return cf(R)

def pose_cfs(p):
    out = {k: to_cf(v) for k, v in p.items() if k != 'Sword'}
    if 'Sword' in p:
        out['Sword'] = aim_matrix(out.get('Torso', np.eye(4)), out.get('RightArm', np.eye(4)), p['Sword'][1:])
    return out

# ---- quaternion slerp to check in-between frames like CFrame:Lerp ----
def to_quat(R):
    t = np.trace(R)
    if t > 0:
        s = np.sqrt(t+1)*2; return np.array([0.25*s,(R[2,1]-R[1,2])/s,(R[0,2]-R[2,0])/s,(R[1,0]-R[0,1])/s])
    i = np.argmax([R[0,0],R[1,1],R[2,2]])
    if i == 0:
        s = np.sqrt(1+R[0,0]-R[1,1]-R[2,2])*2; return np.array([(R[2,1]-R[1,2])/s,0.25*s,(R[0,1]+R[1,0])/s,(R[0,2]+R[2,0])/s])
    if i == 1:
        s = np.sqrt(1+R[1,1]-R[0,0]-R[2,2])*2; return np.array([(R[0,2]-R[2,0])/s,(R[0,1]+R[1,0])/s,0.25*s,(R[1,2]+R[2,1])/s])
    s = np.sqrt(1+R[2,2]-R[0,0]-R[1,1])*2; return np.array([(R[1,0]-R[0,1])/s,(R[0,2]+R[2,0])/s,(R[1,2]+R[2,1])/s,0.25*s])
def from_quat(q):
    w,x,y,z = q/np.linalg.norm(q)
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def slerp(Ra, Rb, t):
    qa, qb = to_quat(Ra), to_quat(Rb)
    if np.dot(qa,qb) < 0: qb = -qb
    d = np.clip(np.dot(qa,qb), -1, 1)
    if d > 0.9995: q = qa + t*(qb-qa)
    else:
        th = np.arccos(d); q = (np.sin((1-t)*th)*qa + np.sin(t*th)*qb)/np.sin(th)
    return from_quat(q)
def lerp_pose(a, b, t):
    keys = set(a) | set(b); out = {}
    for k in keys:
        A = a.get(k, np.eye(4)); B = b.get(k, np.eye(4))
        out[k] = cf(slerp(A[:3,:3], B[:3,:3], t), A[:3,3]*(1-t) + B[:3,3]*t)
    return out

# ---- planting the feet ----
FLOOR = -3.0
def plant_pose(pose):
    """Moves the torso up or down so the lowest sole rests on the floor. R6
    has no knees, so a lunge or a wide stance lifts the feet; dropping the
    body is what makes it look grounded."""
    sole = solve(pose_cfs(pose))['sole']
    dy = round(FLOOR - sole, 3)
    if abs(dy) < 0.01:
        return pose
    torso = pose.get('Torso', ('rot', 0, 0, 0))
    if torso[0] == 'body':
        dy = round(dy + torso[1], 3); angles = torso[2:]
    else:
        angles = torso[1:]
    angles = tuple(angles) + (0,) * (3 - len(angles))
    out = dict(pose); out['Torso'] = ('body', dy, *angles)
    return out

def plant(keys, until=None):
    """Plants every keyframe (or those at or before `until` seconds)."""
    return [(k[0], plant_pose(k[1]) if until is None or k[0] <= until else k[1], *k[2:]) for k in keys]

def sole_check(pose_m, label, problems, tolerance=0.05):
    """Keyframes are planted exactly; in-betweens may dip a little (the drop
    is interpolated in a straight line while the legs swing in arcs)."""
    r = solve(pose_m)
    if r['sole'] < FLOOR - tolerance: problems.append(f"{label}: foot in ground (y={r['sole']:.2f})")

# ---- collision checks ----
def inside_box(p, M, half):
    local = np.linalg.inv(M) @ np.array([*p,1])
    return all(abs(local[i]) < half[i] for i in range(3))

# The rig's blade is the Demon-Slayer Sword's (0.86 to 5.65 along the
# handle). Moves made for a shorter sword pass its `reach` (where its point
# is along the handle) so they're checked with the blade they really hold.
SLAYER_BASE, SLAYER_TIP = 0.86, 5.65

def check(pose_m, label, problems, floor=-2.85, reach=None):
    r = solve(pose_m)
    if reach is not None:
        r['tip'] = r['base'] + (r['tip'] - r['base']) * ((reach - SLAYER_BASE) / (SLAYER_TIP - SLAYER_BASE))
    torso = r['torso']; arm = r['arm']
    head = r['head']
    for t in np.linspace(0.15, 1, 18):          # skip the handle/guard area at the hand
        p = r['base'] + t*(r['tip'] - r['base'])
        if inside_box(p, torso, (1.0, 1.0, 0.5)): problems.append(f"{label}: blade in torso"); break
        if np.linalg.norm(p - head) < 0.75: problems.append(f"{label}: blade in head"); break
    for name in ('tip', 'base'):
        if r[name][1] < floor: problems.append(f"{label}: {name} in ground (y={r[name][1]:.2f})")
    return r

def verify(name, keys, floor=-2.85, hidden_until=-1.0, grounded=False, reach=None):
    """floor: lowest the blade may go (the ground is y=-3; lower it for moves
    that plant the blade on purpose). hidden_until: the sword is invisible
    before this time, so it isn't checked."""
    problems = []
    poses = [pose_cfs(k[1]) for k in keys]
    for i, (k, pm) in enumerate(zip(keys, poses)):
        if i + 1 < len(keys) and keys[i+1][0] <= hidden_until:
            continue
        check(pm, f"{name}@{k[0]:.2f}", problems, floor, reach)
        if grounded: sole_check(pm, f"{name}@{k[0]:.2f}", problems)
        if i + 1 < len(keys):
            for t in (0.25, 0.5, 0.75):
                check(lerp_pose(pm, poses[i+1], t), f"{name}@{k[0]:.2f}+{t}", problems, floor, reach)
                if grounded: sole_check(lerp_pose(pm, poses[i+1], t), f"{name}@{k[0]:.2f}+{t}", problems, 0.16)
    tips = [solve(pm)['tip'] for pm in poses]
    print(f"{name:12s} " + " ".join(fmt(t) for t in tips))
    for p in problems: print("   !!", p)
    return not problems
