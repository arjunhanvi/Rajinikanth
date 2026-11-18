"""R1 pipeline checks on an exported character .glb (the file the game loads).
Usage: python3 tools/humans/verify_body.py <model.glb>"""
import json
import struct
import sys
import numpy as np
from collections import Counter

path = sys.argv[1]
d = open(path, 'rb').read()
l = struct.unpack('<I', d[12:16])[0]
j = json.loads(d[20:20 + l]); off = 20 + l + 8
acc, bv = j['accessors'], j['bufferViews']
CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}


def arr(ai):
    a = acc[ai]; v = bv[a['bufferView']]
    n = NC[a['type']]
    x = np.frombuffer(d, dtype=CT[a['componentType']], count=a['count'] * n, offset=off + v.get('byteOffset', 0) + a.get('byteOffset', 0))
    return x.reshape(-1, n) if n > 1 else x


parts = {}
for m in j['meshes']:
    if not m['name'].startswith('L0_skin'):
        continue
    p = m['primitives'][0]
    at = p['attributes']
    parts[m['name']] = dict(P=arr(at['POSITION']).astype(float), N=arr(at['NORMAL']).astype(float), UV=arr(at['TEXCOORD_0']).astype(float),
                            W=arr(at['WEIGHTS_0']).astype(float), T=arr(p['indices']).reshape(-1, 3).astype(int),
                            morphs=len(p.get('targets', [])), names=m.get('extras', {}).get('targetNames', []))
print('== ', path)
allP = []
for n, q in parts.items():
    P, T, UV, W = q['P'], q['T'], q['UV'], q['W']
    a = UV[T[:, 1]] - UV[T[:, 0]]; b = UV[T[:, 2]] - UV[T[:, 0]]
    uva = a[:, 0] * b[:, 1] - a[:, 1] * b[:, 0]
    ws = W.sum(1)
    print(f"{n:14s} verts {len(P):6d} tris {len(T):6d} | UV in [0,1]: {bool((UV >= -1e-4).all() and (UV <= 1 + 1e-4).all())}  degenerate-UV tris: {int((np.abs(uva) < 1e-10).sum())}"
          f"  UV-flipped tris: {int(min((uva > 0).sum(), (uva < 0).sum()))} | weight sums {ws.min():.3f}-{ws.max():.3f} NaN {bool(np.isnan(W).any())} | morphs {q['morphs']}")
    allP.append((n, P))
# connectivity: open-border vertices of each part and whether another part has a vertex at the same place
print('-- borders between parts')
keyed = {n: {tuple(x) for x in np.round(P, 5)} for n, P in allP}
for n, q in parts.items():
    ec = Counter()
    for t in q['T']:
        for a_, b_ in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            ka = tuple(np.round(q['P'][a_], 5)); kb = tuple(np.round(q['P'][b_], 5))
            ec[(min(ka, kb), max(ka, kb))] += 1
    bverts = {k for e, c in ec.items() if c == 1 for k in e}
    others = set().union(*[keyed[o] for o in keyed if o != n])
    shared = [k for k in bverts if k in others]
    # normal continuity at shared border vertices
    nmap = {}
    for o, qo in parts.items():
        for pp, nn in zip(np.round(qo['P'], 5), qo['N']):
            nmap.setdefault(tuple(pp), []).append(nn)
    dots = []
    for k in shared:
        ns = nmap[k]
        if len(ns) > 1:
            dots.append(min(float(np.dot(ns[0], x)) for x in ns[1:]))
    dots = np.array(dots) if dots else np.array([1.0])
    print(f"{n:14s} open-border verts {len(bverts):5d}, shared exactly with another part {len(shared):5d} "
          f"(others are the eye/mouth openings or the region's own edge); normal agreement at shared verts: min dot {dots.min():.4f}, below 0.999: {int((dots < 0.999).sum())}")
for lvl in (1, 2):
    tot = 0
    for m in j['meshes']:
        if m['name'].startswith('L%d_skin' % lvl):
            tot += acc[m['primitives'][0]['indices']]['count'] // 3
    print(f"L{lvl} skin triangles: {tot}")
