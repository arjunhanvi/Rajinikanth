"""MakeHuman (CC0) base-mesh toolkit: load the mesh, apply morph targets, read the
game skeleton and skin weights. Data comes from the MPFB2 repository's
src/mpfb/data directory (see docs/HUMANS.md)."""
import json, gzip, os, numpy as np

SCALE = 0.1          # MakeHuman works in decimetres
class Base:
    def __init__(self, data):
        self.data = data
        V, VT, F, FT, G = [], [], [], [], []
        g = None
        for l in open(data + '/3dobjs/base.obj'):
            if l.startswith('v '): V.append([float(x) for x in l.split()[1:4]])
            elif l.startswith('vt '): VT.append([float(x) for x in l.split()[1:3]])
            elif l.startswith('g '): g = l.split()[1]
            elif l.startswith('f '):
                p = [x.split('/') for x in l.split()[1:]]
                F.append([int(x[0]) - 1 for x in p]); FT.append([int(x[1]) - 1 for x in p]); G.append(g)
        self.v0 = np.array(V); self.vt = np.array(VT)
        self.faces = F; self.face_uv = FT; self.face_group = np.array(G)
        self.groups = sorted(set(G))
        vg = json.load(open(data + '/mesh_metadata/basemesh_vertex_groups.json'))
        self.vgroups = {k: np.concatenate([np.arange(a, b + 1) for a, b in r]) for k, r in vg.items()}
        self.rig = json.load(open(data + '/rigs/standard/rig.game_engine.json'))
        w = json.load(open(data + '/rigs/standard/weights.game_engine.json'))['weights']
        self.bones = self._bone_order()
        bi = {b: i for i, b in enumerate(self.bones)}
        W = np.zeros((len(self.v0), len(self.bones)), np.float32)
        for b, lst in w.items():
            for vi, wt in lst: W[vi, bi[b]] += wt
        self.W = W
        self._tcache = {}

    def _bone_order(self):
        order, left = [], dict(self.rig)
        while left:
            for b in sorted(left):
                p = left[b]['parent']
                if not p or p in order:
                    order.append(b); del left[b]; break
        return order

    def target(self, rel):
        if rel not in self._tcache:
            p = self.data + '/targets/' + rel + '.target.gz'
            idx, d = [], []
            if os.path.exists(p):
                for l in gzip.open(p, 'rt'):
                    if l[:1] in '#\n' or not l.strip(): continue
                    a = l.split(); idx.append(int(a[0])); d.append([float(a[1]), float(a[2]), float(a[3])])
            else:
                print('  (missing target %s)' % rel)
            self._tcache[rel] = (np.array(idx, int), np.array(d).reshape(-1, 3))
        return self._tcache[rel]

    def apply(self, v, rel, w):
        if abs(w) < 1e-4: return
        idx, d = self.target(rel)
        if len(idx): v[idx] += d * w

    def joints(self, v):
        """bone -> head position, from the joint helper cubes of the morphed mesh"""
        def pos(spec):
            if spec['strategy'] == 'CUBE': return v[self.vgroups[spec['cube_name']]].mean(axis=0)
            if spec['strategy'] == 'MEAN': return v[spec['vertex_indices']].mean(axis=0)
            raise ValueError(spec['strategy'])
        return {b: pos(self.rig[b]['head']) for b in self.bones}, {b: pos(self.rig[b]['tail']) for b in self.bones}

AGES = [('baby', 0.0), ('child', 0.1875), ('young', 0.5), ('old', 1.0)]
def _lerp3(x):          # -> weights for (min, average, max) from x in 0..1
    return {'min': max(0.0, 1 - 2 * x), 'average': 1 - abs(2 * x - 1), 'max': max(0.0, 2 * x - 1)}

def sculpt(base, p):
    """p: gender 0..1 (1 male), age 0..1, weight 0..1, muscle 0..1, height 0..1,
    race {'asian','african','caucasian'} weights, extra {target: weight}"""
    v = base.v0.copy()
    g = {'female': 1 - p['gender'], 'male': p['gender']}
    a = {}
    for i in range(len(AGES) - 1):
        (n0, t0), (n1, t1) = AGES[i], AGES[i + 1]
        if t0 <= p['age'] <= t1:
            k = (p['age'] - t0) / (t1 - t0); a[n0] = 1 - k; a[n1] = k
    mu, we, he = _lerp3(p['muscle']), _lerp3(p['weight']), _lerp3(p['height'])
    rs = sum(p['race'].values())
    for race, rw in p['race'].items():
        for gn, gw in g.items():
            for an, aw in a.items():
                base.apply(v, 'macrodetails/%s-%s-%s' % (race, gn, an), rw / rs * gw * aw)
    for gn, gw in g.items():
        for an, aw in a.items():
            for mn, mw in mu.items():
                for wn, ww in we.items():
                    k = gw * aw * mw * ww
                    base.apply(v, 'macrodetails/universal-%s-%s-%smuscle-%sweight' % (gn, an, mn, wn), k)
                    for hn, hw in he.items():
                        if hn != 'average':
                            base.apply(v, 'macrodetails/height/%s-%s-%smuscle-%sweight-%sheight' % (gn, an, mn, wn, hn), k * hw)
    for t, w in p.get('extra', {}).items():
        base.apply(v, t, w)
    return v
