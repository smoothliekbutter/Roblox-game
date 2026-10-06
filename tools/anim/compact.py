"""Writes animation data as compact Luau: one line of text per keyframe.

A line is "time[ ease]|joint|joint|..." with the joints in JOINTS order,
each one a kind letter (r rot, b body, l limb, a aim) and its numbers
("" when the keyframe leaves it out). `ease` is a style letter and a
direction letter (see STYLES / DIRECTIONS). clip() in the Luau reads it
back into the same tables as before: { time, pose, style?, direction? }.
"""

STYLES = {'Linear': 'L', 'Sine': 'S', 'Quad': 'Q', 'Quart': 'T', 'Back': 'B', 'Cubic': 'C'}
DIRECTIONS = {'In': 'i', 'Out': 'o', 'InOut': 'x'}
KINDS = {'rot': 'r', 'body': 'b', 'limb': 'l', 'aim': 'a'}


def num(v):
    s = ("%.3f" % v).rstrip('0').rstrip('.')
    if s in ('-0', ''):
        return '0'
    if s.startswith('0.'):
        return s[1:]
    if s.startswith('-0.'):
        return '-' + s[2:]
    return s


def field(v):
    kind, *args = v
    keep = 3 if kind == 'aim' else 2 if kind == 'body' else 1
    while len(args) > keep and args[-1] == 0:
        args = args[:-1]
    return KINDS[kind] + ' '.join(num(a) for a in args)


def header(joints):
    order = ', '.join(f'"{j}"' for j in joints)
    return f'''local rad = math.rad
local function rot(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end
local function body(dy: number, x: number, y: number?, z: number?): CFrame
	return CFrame.new(0, dy, 0) * CFrame.Angles(rad(x), rad(y or 0), rad(z or 0))
end
local function limb(pitch: number, yaw: number?, roll: number?): CFrame
	return CFrame.Angles(0, rad(yaw or 0), 0) * CFrame.Angles(0, 0, rad(roll or 0)) * CFrame.Angles(rad(pitch), 0, 0)
end
local function aim(x: number, y: number, z: number): {{ aim: Vector3 }}
	return {{ aim = Vector3.new(x, y, z) }}
end
local KINDS: {{ [string]: (...number) -> any }} = {{ r = rot, b = body, l = limb, a = aim }}
local STYLES = {{ L = "Linear", S = "Sine", Q = "Quad", T = "Quart", B = "Back", C = "Cubic" }}
local DIRECTIONS = {{ i = "In", o = "Out", x = "InOut" }}
local JOINTS = {{ {order} }}

local function clip(meta: {{ [string]: any }}, data: string): {{ [string]: any }}
	local keys = {{}}
	for line in data:gmatch("[^\\n]+") do
		local fields = line:split("|")
		local head = fields[1]:split(" ")
		local pose = {{}}
		for i, joint in JOINTS do
			local value = fields[i + 1]
			if value and value ~= "" then
				local args = {{}}
				for n in value:sub(2):gmatch("%S+") do
					table.insert(args, tonumber(n) :: number)
				end
				pose[joint] = KINDS[value:sub(1, 1)](table.unpack(args))
			end
		end
		local ease = head[2]
		table.insert(keys, {{
			tonumber(head[1]),
			pose,
			ease and STYLES[ease:sub(1, 1)],
			ease and DIRECTIONS[ease:sub(2, 2)],
		}})
	end
	meta.keys = keys
	return meta
end

local Animations = {{}}
'''


def meta(spec):
    parts = []
    if spec.get('loop'):
        parts.append('loop = true')
    if 'fadeIn' in spec:
        parts.append(f"fadeIn = {num(spec['fadeIn'])}")
    if 'fadeOut' in spec:
        parts.append(f"fadeOut = {num(spec['fadeOut'])}")
    if spec.get('additive'):
        parts.append('additive = { ' + ', '.join(f'{k} = true' for k in spec['additive']) + ' }')
    if spec.get('delays'):
        parts.append('delays = { ' + ', '.join(f'{k} = {num(v)}' for k, v in spec['delays'].items()) + ' }')
    if spec.get('events'):
        parts.append('events = { ' + ', '.join(f'{{ time = {num(t)}, name = "{e}" }}' for t, e in spec['events']) + ' }')
    return '{ ' + ', '.join(parts) + ' }' if parts else '{}'


def clip(name, spec, keys, joints):
    assert len(spec['ease']) == len(keys), name
    lines = []
    for (t, pose), ease in zip(keys, spec['ease']):
        line = num(t)
        if ease:
            line += ' ' + STYLES[ease[0]] + DIRECTIONS[ease[1]]
        cells = [field(pose[j]) if j in pose else '' for j in joints]
        while cells and cells[-1] == '':
            cells.pop()
        lines.append('|'.join([line] + cells))
    return f'Animations.{name} = clip({meta(spec)}, [[\n' + '\n'.join(lines) + '\n]])\n'


def write(path, joints, items):
    """items: (name, spec, keys) in order."""
    out = [header(joints)]
    for name, spec, keys in items:
        out.append(clip(name, spec, keys, joints))
    out.append('return Animations\n')
    open(path, 'w').write('\n'.join(out))
    print('wrote', path)
