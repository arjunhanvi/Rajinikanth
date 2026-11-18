"""Bake MakeHuman's facial pose units into vertex offsets (morph targets).

MakeHuman ships a 163-bone rig with a full face (jaw, eyelids, lips, cheeks, brows, tongue), artist-made
skin weights, and 60 facial pose units (FACS-like: left/right brows, lids, cheeks, nasolabial fold,
every lip direction, jaw, tongue) as a BVH. Running a game on that rig costs too much on a phone, so the
face is posed offline here: each unit is skinned on the character's own sculpted mesh and stored as a
morph target. The runtime keeps its light 55-bone body skeleton.
"""
import json
import numpy as np


def _parse_bvh(path):
    joints = []          # [(name, parent_index, channels)]
    stack = []
    frames = []
    with open(path) as f:
        lines = [l.strip() for l in f]
    i = 0
    motion = False
    while i < len(lines):
        l = lines[i]
        if l.startswith('ROOT') or l.startswith('JOINT'):
            name = l.split()[1]
            parent = stack[-1] if stack else -1
            joints.append([name, parent, []])
            stack.append(len(joints) - 1)
        elif l.startswith('End Site'):
            stack.append(-2)
        elif l.startswith('CHANNELS'):
            joints[stack[-1]][2] = l.split()[2:]
        elif l == '}':
            stack.pop()
        elif l.startswith('MOTION'):
            motion = True
            i += 3
            continue
        elif motion and l:
            frames.append([float(x) for x in l.split()])
        i += 1
    return joints, np.array(frames)


def _rot(axis, deg):
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    if axis == 'X':
        return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if axis == 'Y':
        return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


# BVH (Z up, -Y forward) -> mesh space (Y up, +Z forward)
_M = np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]], float)


def bake(mh_data, v, units):
    """mh_data: makehuman/data dir; v: sculpted mesh vertices (all base-mesh vertices, generator space);
    units: list of pose-unit names. Returns {unit: (n, 3) offsets}."""
    skel = json.load(open(mh_data + '/rigs/default.mhskel'))
    wts = json.load(open(mh_data + '/rigs/default_weights.mhw'))['weights']
    names = json.load(open(mh_data + '/poseunits/face-poseunits.json'))['framemapping']
    joints, frames = _parse_bvh(mh_data + '/poseunits/face-poseunits.bvh')
    jpos = {k: v[np.array(idx)].mean(0) for k, idx in skel['joints'].items()}
    bones = skel['bones']
    # bone heads on this mesh
    head = {}
    for j in joints:
        nm = j[0]
        if nm in bones:
            head[nm] = jpos[bones[nm]['head']]
        elif nm == 'root':
            head[nm] = jpos.get(bones.get('root', {}).get('head', ''), v.mean(0)) if 'root' in bones else v.mean(0)
    # weights as dense per-bone vertex lists
    n = len(v)
    out = {}
    for u in units:
        fi = names.index(u)
        vals = frames[fi]
        G = {}
        H = {}
        col = 0
        for ji, (nm, parent, ch) in enumerate(joints):
            R = np.eye(3)
            for c in ch:
                val = vals[col]
                col += 1
                if c.endswith('rotation'):
                    R = R @ _rot(c[0], val)
            Rm = _M @ R @ _M.T                     # the same rotation, expressed in mesh axes
            if parent < 0:
                G[ji] = Rm
                H[ji] = head.get(nm, np.zeros(3))
            else:
                G[ji] = G[parent] @ Rm
                pn = joints[parent][0]
                hp = head.get(pn, np.zeros(3))
                hc = head.get(nm, hp)
                H[ji] = H[parent] + G[parent] @ (hc - hp)
        acc = np.zeros((n, 3))
        wsum = np.zeros(n)
        for ji, (nm, parent, ch) in enumerate(joints):
            if nm not in wts:
                continue
            arr = np.array(wts[nm])
            idx = arr[:, 0].astype(int)
            w = arr[:, 1]
            keep = idx < n
            idx, w = idx[keep], w[keep]
            h0 = head.get(nm, np.zeros(3))
            moved = (v[idx] - h0) @ G[ji].T + H[ji]
            np.add.at(acc, idx, moved * w[:, None])
            np.add.at(wsum, idx, w)
        d = np.zeros((n, 3))
        ok = wsum > 1e-6
        d[ok] = acc[ok] / wsum[ok, None] - v[ok]
        d[np.linalg.norm(d, axis=1) < 1e-5] = 0.0
        out[u] = d
    return out
