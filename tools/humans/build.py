"""Turns a sculpted MakeHuman mesh into game-ready parts: skin regions, eyes, teeth,
clothing and hair fitted from the helper surfaces, facial-hair shells, footwear,
expression morphs and reduced levels of detail."""
import numpy as np, math
from scipy.spatial import cKDTree
import fast_simplification

EXPRESSIONS = {
    "blink_l": {"eye-left-closure": 1.0}, "blink_r": {"eye-right-closure": 1.0},
    "brow_up": {"eyebrows-left-up": 1, "eyebrows-right-up": 1, "eyebrows-left-extern-up": .5, "eyebrows-right-extern-up": .5, "eye-left-opened-up": .5, "eye-right-opened-up": .5},
    "brow_down": {"eyebrows-left-down": 1, "eyebrows-right-down": 1, "nose-compression": .4},
    "brow_sad": {"eyebrows-left-inner-up": 1, "eyebrows-right-inner-up": 1},
    "smile": {"mouth-corner-puller": 1.0, "mouth-elevation": .35, "eye-left-slit": .25, "eye-right-slit": .25},
    "frown": {"mouth-depression": 1.0, "mouth-compression": .3},
    "jaw_open": {"mouth-open": 1.0}, "lips_part": {"mouth-parling": 1.0},
    "pucker": {"mouth-pursing": .8, "mouth-protusion": .5}, "wide": {"mouth-retraction": 1.0},
    "squint": {"eye-left-slit": 1, "eye-right-slit": 1}, "sneer": {"nose-left-elevation": 1, "nose-right-elevation": 1, "mouth-upward-retraction": .5},
}
IDENTITY = {      # runtime-blendable face variation for the crowd
    "id_nose_wide": {"nose/nose-scale-horiz-incr": 1.0, "nose/nose-flaring-incr": .6}, "id_nose_long": {"nose/nose-scale-vert-incr": .8, "nose/nose-hump-incr": .7},
    "id_jaw_wide": {"head/head-square": 1.0, "chin/chin-width-incr": .7}, "id_face_long": {"head/head-oval": .9, "chin/chin-height-incr": .8},
    "id_cheeks": {"cheek/l-cheek-volume-incr": 1, "cheek/r-cheek-volume-incr": 1, "head/head-fat-incr": .6}, "id_gaunt": {"cheek/l-cheek-volume-decr": 1, "cheek/r-cheek-volume-decr": 1, "cheek/l-cheek-bones-incr": .8, "cheek/r-cheek-bones-incr": .8},
    "id_brow": {"forehead/forehead-nubian-incr": .8, "forehead/forehead-scale-vert-decr": .6}, "id_lips": {"mouth/mouth-scale-vert-incr": .9, "mouth/mouth-scale-horiz-incr": .5},
}

class Part:
    def __init__(self, name, P, UV, src, tris, C=None, W=None):
        self.name = name; self.P = P; self.UV = UV; self.src = src; self.tris = tris
        self.C = C if C is not None else np.ones((len(P), 4))
        self.W = W            # explicit weights (n, nb) or None -> taken from src
        self.morph = {}       # name -> (n,3)

class Char:
    def __init__(self, base, v, lod0=True):
        self.b = base; self.v = v; self.parts = []; self.lod0 = lod0
        b = base
        self.tris_all = []; self.tri_uv = []; self.tri_face = []
        for fi, (f, ft) in enumerate(zip(b.faces, b.face_uv)):
            for k in range(1, len(f) - 1):
                self.tris_all.append([f[0], f[k], f[k + 1]]); self.tri_uv.append([ft[0], ft[k], ft[k + 1]]); self.tri_face.append(fi)
        self.tris_all = np.array(self.tris_all); self.tri_uv = np.array(self.tri_uv); self.tri_face = np.array(self.tri_face)
        self.VN = self.normals(v, self.tris_all)
        self.h, self.t = b.joints(v)
        self.ground = v[b.vgroups['joint-ground']].mean(0)[1]
        dom = b.W.argmax(1)
        # dominant bone per face (by summed vertex weights)
        fb = []
        for f in b.faces:
            fb.append(b.bones[int(b.W[f].sum(0).argmax())])
        self.face_bone = np.array(fb)
        self.face_c = np.array([v[f].mean(0) for f in b.faces])
        self.names = list(b.bones) + ['eye_l', 'eye_r']
        self.parents = {n: (b.rig[n]['parent'] or None) for n in b.bones}
        self.parents['eye_l'] = 'head'; self.parents['eye_r'] = 'head'
        self.heads = dict(self.h)
        self.heads['eye_l'] = v[b.vgroups['joint-l-eye']].mean(0); self.heads['eye_r'] = v[b.vgroups['joint-r-eye']].mean(0)

    @staticmethod
    def normals(P, tris):
        n = np.zeros_like(P)
        fn = np.cross(P[tris[:, 1]] - P[tris[:, 0]], P[tris[:, 2]] - P[tris[:, 0]])
        for k in range(3): np.add.at(n, tris[:, k], fn)
        l = np.linalg.norm(n, axis=1); l[l == 0] = 1
        return n / l[:, None]

    # ------------------------------------------------------------ selecting
    def faces(self, group, bones=None, pred=None):
        m = self.b.face_group == group
        if bones is not None:
            m &= np.isin(self.face_bone, [x for x in self.b.bones if any(x == q or x.startswith(q) for q in bones)])
        if pred is not None:
            m &= pred(self.face_c)
        return np.where(m)[0]

    def part(self, name, fidx, offset=None, shift=None, uv='mesh', colour=None):
        """build a part from base faces; offset: per-base-vertex array (dm along normal)"""
        sel = np.isin(self.tri_face, fidx)
        tv, tu = self.tris_all[sel], self.tri_uv[sel]
        key = tv.astype(np.int64) * 100000 + tu
        uniq, inv = np.unique(key.reshape(-1), return_inverse=True)
        src = (uniq // 100000).astype(int); uvi = (uniq % 100000).astype(int)
        P = self.v[src].copy()
        if offset is not None:
            o = offset[src] if isinstance(offset, np.ndarray) else np.full(len(src), float(offset))
            P += self.VN[src] * o[:, None]
        if shift is not None: P += shift[src]
        if uv == 'mesh':
            UV = np.stack([self.b.vt[uvi, 0], 1 - self.b.vt[uvi, 1]], 1)
        else:
            UV = self.cyl_uv(P)
        p = Part(name, P, UV, src, inv.reshape(-1, 3))
        if colour is not None: p.C[:] = colour
        self.parts.append(p); return p

    def cyl_uv(self, P):
        ang = np.arctan2(P[:, 0], P[:, 2])
        return np.stack([ang / (2 * np.pi) * 6.0, -P[:, 1] * 0.45], 1)

    def weights(self, p):
        return p.W if p.W is not None else self.b.W[p.src]

    # ------------------------------------------------------------ body
    def body(self, hero):
        A = ['head', 'neck', 'upperarm', 'lowerarm', 'hand', 'thumb', 'index', 'middle', 'ring', 'pinky']
        knee = self.h['calf_l'][1]; ankle = self.h['foot_l'][1]; mid = (knee + ankle) * 0.5
        self.part('skin_a', self.faces('body', A))
        self.part('skin_torso', self.faces('body', ['spine', 'clavicle']))
        legs = self.faces('body', ['pelvis', 'thigh']); calf = self.faces('body', ['calf'])
        up = calf[self.face_c[calf][:, 1] > mid]
        self.part('skin_legs', np.concatenate([legs, up]))
        self.part('skin_feet', np.concatenate([calf[self.face_c[calf][:, 1] <= mid], self.faces('body', ['foot', 'ball'])]))
        self.part('teeth', np.concatenate([self.faces('helper-upper-teeth'), self.faces('helper-lower-teeth')]), colour=[0.93, 0.9, 0.82, 1])
        self.part('tongue', self.faces('helper-tongue'), colour=[0.75, 0.38, 0.4, 1])
        lash = np.concatenate([self.faces(g) for g in ['helper-l-eyelashes-1', 'helper-l-eyelashes-2', 'helper-r-eyelashes-1', 'helper-r-eyelashes-2']])
        self.part('lashes', lash, colour=[0.03, 0.02, 0.02, 1])
        self.expr_parts = ['skin_a', 'teeth', 'tongue', 'lashes']

    def add_pose_morphs(self, table, unit_d, thresh=0.004):
        """Morphs from baked facial pose units (see faceunits.py). table: name -> {unit: weight}.
        A part keeps a morph only if it actually moves (saves memory on a phone)."""
        for nm, comp in table.items():
            d = np.zeros_like(self.v)
            for u, w in comp.items():
                d += unit_d[u] * w
            for p in self.parts:
                if (p.name in self.expr_parts or getattr(p, 'morph_follow', False)) and p.src is not None:
                    dp = d[p.src]
                    if np.abs(dp).max() > thresh:
                        p.morph[nm] = dp

    def add_morphs(self, table, prefix_dir=None, only=None):
        for nm, comp in table.items():
            d = np.zeros_like(self.v)
            for t, w in comp.items():
                idx, dd = self.b.target(('expression/units/asian/' + t) if prefix_dir is None else t)
                if len(idx): d[idx] += dd * w
            for p in self.parts:
                if (p.name in (only or self.expr_parts) or getattr(p, 'morph_follow', False)) and p.src is not None:
                    p.morph[nm] = d[p.src]

    def eyes(self, mh_core, high):
        base = mh_core + '/eyes/' + ('high-poly/high-poly' if high else 'low-poly/low-poly')
        sc = {}; rows = []; inv = False
        for l in open(base + '.mhclo'):
            a = l.split()
            if not a or a[0].startswith('#'): continue
            if a[0] in ('x_scale', 'y_scale', 'z_scale'): sc[a[0][0]] = (int(a[1]), int(a[2]), float(a[3]))
            elif a[0] == 'verts': inv = True
            elif inv and len(a) == 9: rows.append([float(x) for x in a])
            elif inv and len(a) < 9: inv = False
        rows = np.array(rows); v = self.v
        s = np.array([abs(v[sc[k][0]] - v[sc[k][1]])[i] / sc[k][2] for i, k in enumerate('xyz')])
        i3 = rows[:, :3].astype(int)
        P = (v[i3] * rows[:, 3:6, None]).sum(1) + rows[:, 6:9] * s
        VT = []; F = []; FT = []
        for l in open(base + '.obj'):
            if l.startswith('vt '): VT.append([float(x) for x in l.split()[1:3]])
            elif l.startswith('f '):
                q = [x.split('/') for x in l.split()[1:]]
                for k in range(1, len(q) - 1):
                    F.append([int(q[0][0]) - 1, int(q[k][0]) - 1, int(q[k + 1][0]) - 1]); FT.append([int(q[0][1]) - 1, int(q[k][1]) - 1, int(q[k + 1][1]) - 1])
        F = np.array(F); FT = np.array(FT); VT = np.array(VT)
        key = F.astype(np.int64) * 100000 + FT
        uniq, invi = np.unique(key.reshape(-1), return_inverse=True)
        src = (uniq // 100000).astype(int); uvi = (uniq % 100000).astype(int)
        PP = P[src]; nb = len(self.names)
        W = np.zeros((len(PP), nb), np.float32)
        W[PP[:, 0] > 0, self.names.index('eye_l')] = 1; W[PP[:, 0] <= 0, self.names.index('eye_r')] = 1
        p = Part('eyes', PP, np.stack([VT[uvi, 0], 1 - VT[uvi, 1]], 1), None, invi.reshape(-1, 3), W=W)
        self.parts.append(p)

    def eye_extras(self):
        """Cornea shells (glossy, they follow the eye) and eye-occlusion shells (fixed to the head:
        the lids and corners shade the eyeball wherever it looks)."""
        eyes = [p for p in self.parts if p.name == 'eyes'][0]
        P = eyes.P; T = eyes.tris; nb = len(self.names)
        for side in ('l', 'r'):
            m = (P[:, 0] > 0) if side == 'l' else (P[:, 0] <= 0)
            idx = np.where(m)[0]
            lo = P[idx].min(0); hi = P[idx].max(0)
            c = (lo + hi) * 0.5; r = float((hi - lo)[0]) * 0.5
            rel = (P - c) / r
            # cornea: the front cap, slightly proud of the eyeball
            front = m & (rel[:, 2] > 0.72)
            tri = T[front[T].all(1)]
            print('  cornea', side, 'tris', len(tri))
            if len(tri):
                used = np.unique(tri); remap = -np.ones(len(P), int); remap[used] = np.arange(len(used))
                Pc = c + (P[used] - c) * 1.012
                W = np.zeros((len(Pc), nb), np.float32); W[:, self.names.index('eye_' + side)] = 1
                pc = Part('cornea_' + side, Pc, np.zeros((len(Pc), 2)), None, remap[tri], C=np.tile([1, 1, 1, 1.0], (len(Pc), 1)), W=W)
                pc.keep = True; pc.levels = {0, 1}
                self.parts.append(pc)
            # occlusion: the front hemisphere, a little larger, dark under the upper lid and in the corners
            fh = m & (rel[:, 2] > 0.3)
            tri2 = T[fh[T].all(1)]
            used2 = np.unique(tri2); remap2 = -np.ones(len(P), int); remap2[used2] = np.arange(len(used2))
            Po = c + (P[used2] - c) * 1.006
            ro = rel[used2]
            dark = np.clip((ro[:, 1] - 0.05) / 0.6, 0, 1) * 0.8 + np.clip((np.abs(ro[:, 0]) - 0.5) / 0.4, 0, 1) * 0.45 + np.clip((-ro[:, 1] - 0.45) / 0.4, 0, 1) * 0.25
            Wo = np.zeros((len(Po), nb), np.float32); Wo[:, self.names.index('head')] = 1
            Co = np.zeros((len(Po), 4)); Co[:, 3] = np.clip(dark, 0, 0.85)
            po = Part('eyeocc_' + side, Po, np.zeros((len(Po), 2)), None, remap2[tri2], C=Co, W=Wo)
            po.keep = True; po.levels = {0, 1}
            self.parts.append(po)

    def mouth_occlusion(self):
        """Teeth set slightly back and darkening toward the inside of the mouth, so a closed or
        barely parted mouth never shows a bright line of teeth."""
        for p in self.parts:
            if p.name == 'teeth':
                z = p.P[:, 2]
                p.P = p.P - np.array([0, 0, 0.022])
                k = np.clip((z - z.min()) / max(1e-6, z.max() - z.min()), 0, 1)
                C = np.array(p.C, float)
                C[:, :3] = C[:, :3] * (0.22 + 0.42 * k ** 2)[:, None]
                p.C = C

    # ------------------------------------------------------------ clothing
    def _fold(self, amp, fy=7.0):
        v = self.v
        return amp * np.sin(v[:, 1] * fy + 3.0 * np.sin(v[:, 0] * 2.3) + v[:, 2] * 2.0)

    def top(self, name, sleeves='half', tucked=True, open_front=False, offset=0.11, hem=None, collar=True, loose=0.0, colour=None, tailored=False):
        h = self.h; fc = self.face_c
        waist = h['spine_01'][1]; pel = h['pelvis'][1]; crotch = h['thigh_l'][1] - 0.9
        if hem is None: hem = (waist - 0.35) if tucked else (crotch + 0.55)
        neck_top = h['neck_01'][1] + (0.38 if collar else 0.0)
        elbow = h['lowerarm_l']; sh = h['upperarm_l']
        bones = ['spine', 'clavicle', 'pelvis', 'neck']
        if sleeves in ('half', 'full', 'cap'): bones.append('upperarm')
        if sleeves == 'full': bones.append('lowerarm')
        f = self.faces('helper-tights', bones)
        c = fc[f]; bn = self.face_bone[f]
        keep = (c[:, 1] > hem) & (c[:, 1] < neck_top)
        if sleeves == 'half':      # end the sleeve above the elbow
            d = np.linalg.norm(c - np.where(c[:, :1] > 0, 1, -1) * np.array([[elbow[0], 0, 0]]) - np.array([[0, elbow[1], elbow[2]]]), axis=1)
            keep &= ~(np.char.startswith(bn, 'upperarm') & (d < 0.75))
        if sleeves == 'cap':
            d = np.linalg.norm(c - np.where(c[:, :1] > 0, 1, -1) * np.array([[sh[0], 0, 0]]) - np.array([[0, sh[1], sh[2]]]), axis=1)
            keep &= ~(np.char.startswith(bn, 'upperarm') & (d > 1.15))
        if sleeves == 'full':
            wr = h['hand_l']
            d = np.linalg.norm(c - np.where(c[:, :1] > 0, 1, -1) * np.array([[wr[0], 0, 0]]) - np.array([[0, wr[1], wr[2]]]), axis=1)
            keep &= ~(np.char.startswith(bn, 'lowerarm') & (d < 0.28))
        if open_front:             # worn unbuttoned: a gap that widens toward the hem
            gap = 0.52
            fv = np.array([np.abs(self.v[self.b.faces[i]][:, 0]).min() for i in f])
            keep &= ~((c[:, 2] > 0.2) & (fv < gap))
        elif collar:               # open collar notch
            keep &= ~((c[:, 2] > 0.3) & (np.abs(c[:, 0]) < 0.22) & (c[:, 1] > h['neck_01'][1] - 0.35))
        f = f[keep]
        v = self.v
        shift = np.zeros_like(v)
        if open_front:           # pull the two front edges into clean vertical lines
            edge = (v[:, 2] > 0.2) & (np.abs(v[:, 0]) < 0.52 + 0.45) & (np.abs(v[:, 0]) >= 0.52)
            shift[edge, 0] = np.sign(v[edge, 0]) * (0.56 + (np.abs(v[edge, 0]) - 0.52) * 0.55) - v[edge, 0]
        off = np.full(len(v), offset) + self._fold(0.012 + loose * 0.02)
        below = np.clip((waist + 0.3 - v[:, 1]) / 1.5, 0, 1)
        off += below * (0.12 + loose * 0.25) * (0.0 if tucked else 1.0)        # hangs away from the body below the waist
        off += np.clip((v[:, 1] - h['neck_01'][1] + 0.1) / 0.4, 0, 1) * 0.06     # collar stands off the neck
        arm = np.abs(v[:, 0]) > sh[0] * 1.02
        off[arm] += 0.05 + loose * 0.08
        if tailored:
            # real folds, where a worn shirt makes them: blousing over the belt (vertical folds that
            # die out upward), drag folds fanning from the armpits across chest and back, and a few
            # slack ripples on the sleeve
            ang = np.arctan2(v[:, 0], v[:, 2])
            band = np.clip(1 - (v[:, 1] - (hem + 0.05)) / 0.7, 0, 1) * (v[:, 1] > hem)
            off += band * (0.05 + 0.03 * np.sin(ang * 13.0 + 0.7) + 0.018 * np.sin(ang * 29.0 + 2.1))
            for sx in (1.0, -1.0):
                ap = np.array([sx * sh[0] * 0.92, sh[1] - 0.35, sh[2]])
                d = np.linalg.norm(v - ap, axis=1)
                torso = np.abs(v[:, 0]) < sh[0] * 0.95
                off += torso * np.exp(-d / 0.9) * (0.018 * np.sin(d * 19.0) + 0.012)
            sleeve = arm & (v[:, 1] < sh[1] + 0.2)
            off[sleeve] += 0.02 * np.sin((sh[1] - v[sleeve, 1]) * 16.0 + v[sleeve, 2] * 9.0) * 0.6
        p = self.part(name, f, offset=off, shift=shift, uv='cyl', colour=colour)
        if not collar:
            self._clean_neckline(p, h)
        self._hems(p, 0.72)
        return p

    def hem_bands(self, p, depth=0.035):
        """Fabric thickness at the open edges: every boundary edge gets a narrow turned-in band, so a
        sleeve or hem shows a folded edge instead of a paper-thin cut."""
        from collections import Counter
        ec = Counter()
        for t in p.tris:
            for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
                ec[(min(a, b), max(a, b))] += 1
        edges = [e for e, n in ec.items() if n == 1]
        if not edges: return
        N = self.normals(p.P, p.tris)
        P = list(p.P); UV = list(p.UV); C = list(p.C); S = list(p.src); T = list(p.tris)
        new = {}
        def inner(i):
            if i not in new:
                new[i] = len(P)
                P.append(p.P[i] - N[i] * depth); UV.append(p.UV[i]); C.append(p.C[i] * np.array([0.82, 0.82, 0.82, 1])); S.append(p.src[i])
            return new[i]
        for a, b in edges:
            ia, ib = inner(a), inner(b)
            T.append([a, ib, b]); T.append([a, ia, ib])
        p.P = np.array(P); p.UV = np.array(UV); p.C = np.array(C); p.src = np.array(S); p.tris = np.array(T)

    def collar_band(self, p, colour, height=0.32, spread=0.16):
        """A shirt collar: a band standing round the neck that turns down into two points at the front."""
        h = self.h; v = self.v
        ny = h['neck_01'][1] - 0.05
        nv = self.b.vgroups['body']
        bi = self.b.bones.index('neck_01') if 'neck_01' in self.b.bones else self.b.bones.index('neck')
        ring = np.array([i for i in nv if abs(v[i, 1] - ny) < 0.08 and self.b.W[i, bi] > 0.3])
        if len(ring) < 8: return None
        cen = v[ring].mean(0)
        angs = np.linspace(-np.pi * 0.92, np.pi * 0.92, 40)      # leaves the throat open at the front
        rr = np.max(np.linalg.norm((v[ring] - cen)[:, [0, 2]], axis=1)) + 0.07
        Ps = []; UVs = []
        for k, a in enumerate(angs):
            dx, dz = -np.sin(a), -np.cos(a)                        # a = 0 at the back of the neck; the opening (a = +-pi) at the front
            front = np.clip((abs(a) - np.pi * 0.62) / (np.pi * 0.3), 0, 1)   # 0 at the back, 1 at the collar points
            base = cen + np.array([dx * rr, 0.0, dz * rr])
            top = base + np.array([dx * 0.05, height * (1 - 0.35 * front), dz * 0.05])
            fold = top + np.array([dx * (spread + 0.12 * front), -height * (0.75 + 0.9 * front), dz * (spread + 0.12 * front)])
            Ps += [base, top, fold]; UVs += [[k / 39, 0], [k / 39, 0.5], [k / 39, 1]]
        T = []
        for k in range(len(angs) - 1):
            for r in range(2):
                a0 = k * 3 + r; b0 = (k + 1) * 3 + r
                T.append([a0, b0, a0 + 1]); T.append([a0 + 1, b0, b0 + 1])
        P = np.array(Ps)
        W = np.zeros((len(P), len(self.names)), np.float32)
        W[:, self.names.index('neck_01')] = 0.6; W[:, self.names.index('spine_03')] = 0.4
        cp = Part('collar', P, np.array(UVs), None, np.array(T), C=np.tile(list(colour[:3]) + [1], (len(P), 1)), W=W)
        cp.keep = True
        self.parts.append(cp)
        return cp

    def _clean_neckline(self, p, h):
        """a collarless neck opening cut from faces has a saw-tooth edge; pull the open edge
        round the neck onto one smooth ring so it reads as a sewn neckband"""
        e = {}
        for t in p.tris:
            for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
                k = (min(a, b), max(a, b)); e[k] = e.get(k, 0) + 1
        bnd = set()
        for (a, b), n in e.items():
            if n == 1: bnd.add(a); bnd.add(b)
        nk = h['neck_01']
        ids = [i for i in bnd if p.P[i, 1] > nk[1] - 0.9 and np.hypot(p.P[i, 0] - nk[0], p.P[i, 2] - nk[2]) < 1.1]
        if not ids: return
        ids = np.array(ids)
        ang = np.arctan2(p.P[ids, 0] - nk[0], p.P[ids, 2] - nk[2])
        # a ring that dips a little at the front, as a crew neck does
        y = np.median(p.P[ids, 1]) - 0.12 * np.clip(np.cos(ang), 0, 1)
        p.P[ids, 1] = y

    def _hems(self, p, k=0.75):
        """darken the open edges: a stitched hem / cuff line"""
        e = {}
        for t in p.tris:
            for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
                key = (min(p.src[a], p.src[b]), max(p.src[a], p.src[b])) if p.src is not None else (min(a, b), max(a, b))
                e[key] = e.get(key, 0) + 1
        bsrc = set()
        for (a, b), n in e.items():
            if n == 1: bsrc.add(a); bsrc.add(b)
        m = np.isin(p.src, list(bsrc)) if p.src is not None else np.zeros(len(p.P), bool)
        p.C[m, :3] *= k

    def details(self, shirt, buttons=5, pocket=True, colour=(0.9, 0.9, 0.86)):
        """buttons down the placket and a chest pocket, as real geometry on the garment"""
        P = shirt.P; front = (np.abs(P[:, 0]) < 0.12) & (P[:, 2] > 0)
        if front.sum() < 3: return
        ys = np.linspace(P[front, 1].min() + 0.25, P[front, 1].max() - 0.35, buttons)
        Wg = self.weights(shirt); newP, newT, newW, newC = [], [], [], []
        n0 = 0
        def blob(c, r, col, wrow, squash=0.25):
            nonlocal n0
            ring = [c + np.array([math.cos(a) * r, math.sin(a) * r, 0]) for a in np.linspace(0, 2 * np.pi, 7)[:-1]]
            pts = [c + np.array([0, 0, r * squash])] + ring
            newP.extend(pts); newW.extend([wrow] * 7); newC.extend([list(col) + [1]] * 7)
            for i in range(6): newT.append([n0, n0 + 1 + i, n0 + 1 + (i + 1) % 6])
            n0 += 7
        for y in ys:
            cand = np.where(front)[0]; i = cand[np.argmin(np.abs(P[cand, 1] - y))]
            blob(np.array([0.0, y, P[i, 2] + 0.035]), 0.055, colour, Wg[i])
        if pocket:
            ch = self.h['spine_03'][1] + 0.55
            reg = np.where((P[:, 0] > 0.45) & (P[:, 0] < 1.25) & (P[:, 1] > ch - 0.95) & (P[:, 1] < ch) & (P[:, 2] > 0.3))[0]
            if len(reg) > 3:
                tm = np.isin(shirt.tris, reg).all(1); tt = shirt.tris[tm]
                used = np.unique(tt); remap = {u: n0 + k for k, u in enumerate(used)}
                Nn = self.normals(P, shirt.tris)
                newP.extend(P[used] + Nn[used] * 0.03); newW.extend(Wg[used]); newC.extend((shirt.C[used] * [0.86, 0.86, 0.86, 1]).tolist())
                newT.extend([[remap[a] for a in t] for t in tt]); n0 += len(used)
        base = len(shirt.P)
        shirt.W = np.vstack([Wg, np.array(newW)]); shirt.P = np.vstack([P, np.array(newP)])
        shirt.UV = np.vstack([shirt.UV, self.cyl_uv(np.array(newP))]); shirt.C = np.vstack([shirt.C, np.array(newC)])
        shirt.tris = np.vstack([shirt.tris, np.array(newT) + base]); shirt.src = None

    def trousers(self, name='trousers', loose=0.0, colour=None):
        h = self.h; v = self.v
        f = self.faces('helper-tights', ['pelvis', 'thigh', 'calf'])
        f = f[(self.face_c[f][:, 1] > h['foot_l'][1] + 0.25) & (self.face_c[f][:, 1] < h['spine_01'][1] - 0.1)]
        off = np.full(len(v), 0.09) + self._fold(0.012, 9.0)
        shift = np.zeros_like(v)
        for s in ('l', 'r'):       # straight leg: do not follow the calf in to the ankle
            k0, a0 = h['calf_' + s], h['foot_' + s]
            m = (np.sign(v[:, 0]) == np.sign(k0[0])) & (v[:, 1] < k0[1] + 0.6)
            t = np.clip((k0[1] + 0.6 - v[m, 1]) / (k0[1] - a0[1] + 0.6), 0, 1)
            axis = k0[None, :] + (a0 - k0)[None, :] * np.clip((k0[1] - v[m, 1]) / (k0[1] - a0[1]), 0, 1)[:, None]
            rad = v[m] - axis; rad[:, 1] = 0
            r = np.linalg.norm(rad, axis=1); r[r == 0] = 1
            want = 0.62 + loose * 0.35
            push = np.clip(want - r, 0, None) * t
            shift[m] += rad / r[:, None] * push[:, None]
        off += loose * 0.12
        p = self.part(name, f, offset=off, shift=shift, uv='cyl', colour=colour)
        self._hems(p)
        # belt
        w = h['spine_01'][1] - 0.32
        bf = self.faces('helper-tights', ['pelvis', 'spine_01'], lambda c: (c[:, 1] > w - 0.22) & (c[:, 1] < w + 0.18))
        self.part('belt', bf, offset=np.full(len(v), 0.135), uv='cyl', colour=[0.16, 0.1, 0.06, 1])
        return p

    def skirt(self, name, hem_y=None, flare=0.08, folds=14, amp=0.11, pleat=0.0, top_y=None, colour=None, border=None, sub=True):
        h = self.h; v = self.v
        idx = self.b.vgroups['helper-skirt']
        y0 = v[idx, 1].max(); y1 = v[idx, 1].min()
        if hem_y is None: hem_y = y1
        f = self.faces('helper-skirt')
        shift = np.zeros_like(v)
        t = np.clip((y0 - v[idx, 1]) / (y0 - y1), 0, 1)
        newy = y0 - t * (y0 - hem_y)
        ang = np.arctan2(v[idx, 0], v[idx, 2])
        rad = v[idx].copy(); rad[:, 1] = 0
        r = np.linalg.norm(rad, axis=1); r[r == 0] = 1; rd = rad / r[:, None]
        wave = np.sin(ang * folds + 1.3 * np.sin(ang * 3)) * amp * t
        if pleat > 0:              # the saree's front pleats: a fan of deep folds at the centre front
            wave += np.exp(-(ang / 0.45) ** 2) * np.sin(ang * 34) * pleat * (0.3 + t)
        shift[idx] = rd * (wave + flare * t + 0.05)[:, None]
        shift[idx, 1] += newy - v[idx, 1]
        if top_y is not None: f = f[self.face_c[f][:, 1] < top_y]
        p = self.part(name, f, shift=shift, uv='cyl', colour=colour)
        if sub: self.subdivide(p)
        if border is not None:
            m = p.P[:, 1] < hem_y + 0.55
            p.C[m] = border
        return p

    def subdivide(self, p):
        W = self.weights(p); P, UV, C = p.P, p.UV, p.C
        cache = {}; nP = list(P); nUV = list(UV); nC = list(C); nW = list(W); T = []
        def mid(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                cache[k] = len(nP); nP.append((P[a] + P[b]) / 2); nUV.append((UV[a] + UV[b]) / 2); nC.append((C[a] + C[b]) / 2); nW.append((W[a] + W[b]) / 2)
            return cache[k]
        for a, b, c in p.tris:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            T += [[a, ab, ca], [ab, b, bc], [ca, bc, c], [ab, bc, ca]]
        p.P = np.array(nP); p.UV = np.array(nUV); p.C = np.array(nC); p.W = np.array(nW, np.float32); p.tris = np.array(T); p.src = None

    def drape(self, name, colour, a=(1.6, 13.8), b=(-1.7, 9.6), width=0.75, offset=0.2, tail=True):
        """a band of cloth across the torso from one shoulder to the opposite hip (saree pallu, dupatta)"""
        v = self.v; h = self.h
        sh = h['upperarm_l']; hip = h['thigh_r']
        A = np.array([sh[0] * 0.75, sh[1] + 0.35]); B = np.array([hip[0] * 1.3, h['spine_01'][1] - 0.2])
        d = (B - A) / np.linalg.norm(B - A)
        def pred(c):
            rel = c[:, :2] - A
            along = rel @ d; perp = np.abs(rel[:, 0] * d[1] - rel[:, 1] * d[0])
            return (perp < width + 0.45) & (along > -0.9) & (along < np.linalg.norm(B - A) + 0.6)
        f = self.faces('helper-tights', ['spine', 'clavicle', 'pelvis', 'neck'], pred)
        off = np.full(len(v), offset) + self._fold(0.03, 11.0)
        p = self.part(name, f, offset=off, uv='cyl', colour=colour)
        # refine the mesh, then trim to the band so its edges run clean and diagonal
        self.subdivide(p); self.subdivide(p)
        cen = p.P[p.tris].mean(1); rel = cen[:, :2] - A
        al = rel @ d; pe = np.abs(rel[:, 0] * d[1] - rel[:, 1] * d[0])
        p.tris = p.tris[(pe < width) & (al > -0.6) & (al < np.linalg.norm(B - A) + 0.3)]
        if tail:                    # the loose end falling down the back from the shoulder
            Wg = self.weights(p); back = np.where((p.P[:, 2] < -0.3) & (p.P[:, 1] > sh[1] - 0.2))[0]
            if len(back) >= 2:
                i0 = back[np.argmin(p.P[back, 0])]; i1 = back[np.argmax(p.P[back, 0])]
                n = 7; rows = []
                for k in range(n + 1):
                    t = k / n
                    for i in (i0, i1):
                        q = p.P[i].copy(); q[1] -= t * 4.2; q[2] -= 0.12 + 0.25 * math.sin(t * 3.1); q[0] += (0.1 if i == i1 else -0.1) * t
                        rows.append(q)
                base = len(p.P); rows = np.array(rows)
                Wt = np.zeros((len(rows), Wg.shape[1]), np.float32); Wt[:, self.b.bones.index('spine_03')] = 0.6; Wt[:, self.b.bones.index('spine_02')] = 0.4
                T = []
                for k in range(n):
                    a0 = base + k * 2
                    T += [[a0, a0 + 1, a0 + 3], [a0, a0 + 3, a0 + 2], [a0, a0 + 3, a0 + 1], [a0, a0 + 2, a0 + 3]]
                p.W = np.vstack([Wg, Wt]); p.P = np.vstack([p.P, rows]); p.UV = np.vstack([p.UV, self.cyl_uv(rows)])
                p.C = np.vstack([p.C, np.tile(colour, (len(rows), 1))]); p.tris = np.vstack([p.tris, np.array(T)]); p.src = None
        return p

    # ------------------------------------------------------------ hair
    def hair(self, name, style, shells=6, colour=(0.05, 0.04, 0.04), cap_only=False):
        v = self.v; h = self.h; b = self.b
        idx = b.vgroups['helper-hair']
        head = h['head']; top = v[idx, 1].max()
        rel = v - head
        up = np.clip(rel[:, 1] / (top - head[1]), -3, 1)          # 0 at skull base .. 1 at crown
        front = rel[:, 2] / 1.0; side = np.abs(rel[:, 0])
        L = np.zeros(len(v)); shift = np.zeros_like(v)
        nape = head[1] - 0.25
        def pred_short(c): return c[:, 1] > nape
        pred = pred_short
        if style == 'short':
            L[:] = 0.1 + 0.08 * np.clip(up, 0, 1)
        elif style == 'side':
            L[:] = 0.12 + 0.22 * np.clip(up, 0, 1) ** 2
            shift[:, 0] = -0.1 * np.clip(up, 0, 1)
        elif style == 'bouffant':          # thick, swept up and back from the forehead, full over the ears
            cu = np.clip(up, 0, 1)
            L[:] = 0.2 + 0.34 * cu ** 1.5 + 0.2 * np.clip(front, 0, 1) * cu
            shift[:, 2] = -0.22 * cu * np.clip(front + 0.4, 0, 1)
            shift[:, 1] = 0.14 * cu * np.clip(front, 0, 1)
            shift[:, 0] = -0.14 * cu
            nape = head[1] - 0.75
        elif style == 'curly':
            L[:] = 0.26 + 0.1 * np.sin(v[:, 0] * 23) * np.sin(v[:, 1] * 19 + v[:, 2] * 17)
        elif style == 'thick_side':      # Raja: dense, long on top, swept to one side and back, full over the ears, longer at the nape
            cu = np.clip(up, 0, 1)
            L[:] = 0.13 + 0.17 * cu ** 1.2 + 0.07 * np.clip(front, 0, 1) * cu + 0.025 * np.sin(v[:, 0] * 9 + v[:, 2] * 7)
            shift[:, 0] = -0.1 * cu * np.clip(front + 0.6, 0, 1.2)
            shift[:, 2] = -0.07 * cu
            shift[:, 1] = 0.03 * cu * np.clip(front, 0, 1)
            nape = head[1] - 0.85
        elif style == 'puff':            # Lal: a big rounded crown of wavy hair, full at the sides, sideburns
            cu = np.clip(up, 0, 1)
            L[:] = 0.17 + 0.26 * cu ** 1.1 + 0.04 * np.sin(v[:, 0] * 17) * np.sin(v[:, 2] * 15 + v[:, 1] * 9)
            shift[:, 1] = 0.08 * cu
            shift[:, 2] = 0.02 * cu * np.clip(front, 0, 1) - 0.05 * cu * np.clip(-front, 0, 1)
            nape = head[1] - 0.7
        elif style == 'balding':
            L[:] = 0.1
            pred = lambda c: (c[:, 1] > nape) & ~((c[:, 1] - head[1] > (top - head[1]) * 0.62) & (c[:, 2] - head[2] > -0.75))
        elif style == 'bun':
            L[:] = 0.16 + 0.12 * np.clip(up, 0, 1)
            shift[:, 2] = -0.08 * np.clip(up, 0, 1)
        elif style in ('plait', 'long'):
            L[:] = 0.16 + 0.1 * np.clip(up, 0, 1)
            low = v[:, 1] < nape
            if style == 'plait':
                shift[low, 0] = -v[low, 0] * 0.72
                shift[low, 2] = -0.1
            pred = lambda c: c[:, 1] > head[1] - 4.2
        # the scalp: head skin above a hairline that runs from the forehead, over the ears, down to the nape
        ey = self.heads['eye_l'][1]; ez = self.heads['eye_l'][2]
        hv = v[self.b.vgroups['body']]; hm = self.b.W[self.b.vgroups['body'], self.b.bones.index('head')] > 0.5
        zb = hv[hm][:, 2].min()
        recede = 0.0 if style != 'balding' else 0.55
        def scalp(c):
            t = np.clip((ez - 0.25 - c[:, 2]) / (ez - 0.25 - zb), 0, 1)
            line = ey + 0.66 + recede - 2.05 * t ** 1.35
            return (c[:, 1] > line) & ~((np.abs(c[:, 0]) > 0.62) & (c[:, 1] < ey + 0.25) & (t < 0.55))
        f = self.faces('body', ['head', 'neck'], scalp)
        tv = np.clip((ez - 0.25 - v[:, 2]) / (ez - 0.25 - zb), 0, 1)
        edge_a = np.clip((v[:, 1] - (ey + 0.66 + recede - 2.05 * tv ** 1.35)) / 0.3, 0.0, 1.0)
        if style == 'balding':
            f = np.array([i for i in f if not (self.face_c[i][1] > ey + 1.0 and self.face_c[i][2] > head[2] - 0.9)], int)
        extra = None
        if style in ('plait', 'long'):
            extra = self.faces('helper-hair', None, lambda c: (c[:, 2] < head[2] - 0.55) & (c[:, 1] < head[1] + 0.2) & (c[:, 1] > head[1] - (4.2 if style == 'plait' else 2.6)))
        parts = []
        cap = self.part(name + '_cap', f, offset=L * 0.25 + 0.02, shift=shift * 0.3, uv='cyl', colour=list(np.array(colour) * 0.6) + [1])
        if cap_only:
            cap.C[:, 3] = np.clip(edge_a[cap.src] * 1.4, 0, 1) ** 1.6   # card hair: 0 at the hairline, an alpha-blended density ramp
        else:
            cap.C[:, 3] = 0.45 + 0.55 * edge_a[cap.src]
        parts.append(cap)
        if cap_only:
            return cap
        if extra is not None and len(extra):
            self.part(name + '_tail', extra, offset=np.full(len(v), 0.04), shift=shift, uv='cyl', colour=list(colour) + [1])
        sh = self.part(name, f, offset=L * 0.4, shift=shift, uv='cyl', colour=list(colour) + [1])
        sh.C[:, 3] = 0.5 + 0.5 * edge_a[sh.src]
        P0, UV0, C0, T0 = sh.P.copy(), sh.UV.copy(), sh.C.copy(), sh.tris.copy()
        N0 = self.normals(P0, T0); Ls = L[sh.src]
        Pl, UVl, Cl, Tl, Sl = [P0], [UV0], [C0], [T0], [sh.src]
        for k in range(1, shells):
            t = k / (shells - 1) if shells > 1 else 1
            Pk = P0 + N0 * (Ls * 0.6 * t)[:, None]
            Ck = C0.copy(); Ck[:, 3] = C0[:, 3] * (1.0 - 0.2 * t)
            Tl.append(T0 + len(P0) * k); Pl.append(Pk); UVl.append(UV0); Cl.append(Ck); Sl.append(sh.src)
        sh.P = np.vstack(Pl); sh.UV = np.vstack(UVl); sh.C = np.vstack(Cl); sh.tris = np.vstack(Tl); sh.src = np.concatenate(Sl)
        if style == 'bun':
            c = head + np.array([0, 0.55, -1.2]); r = 0.5
            pts = []; T = []
            for i in range(7):
                for j in range(10):
                    th = math.pi * i / 6; ph = 2 * math.pi * j / 10
                    pts.append(c + r * np.array([math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph) * 0.8]))
            for i in range(6):
                for j in range(10):
                    a = i * 10 + j; b2 = i * 10 + (j + 1) % 10; T += [[a, b2, a + 10], [b2, b2 + 10, a + 10]]
            pts = np.array(pts); W = np.zeros((len(pts), len(self.names)), np.float32); W[:, self.names.index('head')] = 1
            bp = Part(name + '_bun', pts, self.cyl_uv(pts) * 3, None, np.array(T), W=W); bp.C[:] = list(colour) + [1]
            self.parts.append(bp); parts.append(bp)
        return sh

    # ------------------------------------------------------------ hair cards
    def _scalp_faces(self, recede=0.0):
        v = self.v; h = self.h; b = self.b
        ey = self.heads['eye_l'][1]; ez = self.heads['eye_l'][2]
        hv = v[b.vgroups['body']]; hm = b.W[b.vgroups['body'], b.bones.index('head')] > 0.5
        zb = hv[hm][:, 2].min()
        def scalp(c):
            t = np.clip((ez - 0.25 - c[:, 2]) / (ez - 0.25 - zb), 0, 1)
            line = ey + 0.66 + recede - 2.05 * t ** 1.35
            return (c[:, 1] > line) & ~((np.abs(c[:, 0]) > 0.62) & (c[:, 1] < ey + 0.25) & (t < 0.55))
        return self.faces('body', ['head', 'neck'], scalp)

    def _sample_surface(self, fidx, n, rng):
        sel = np.isin(self.tri_face, fidx)
        T = self.tris_all[sel]; v = self.v
        a, b2, c = v[T[:, 0]], v[T[:, 1]], v[T[:, 2]]
        area = np.linalg.norm(np.cross(b2 - a, c - a), axis=1) * 0.5
        pick = rng.choice(len(T), n, p=area / area.sum())
        r1 = np.sqrt(rng.random(n)); r2 = rng.random(n)
        w0 = 1 - r1; w1 = r1 * (1 - r2); w2 = r1 * r2
        P = a[pick] * w0[:, None] + b2[pick] * w1[:, None] + c[pick] * w2[:, None]
        N = self.VN[T[pick, 0]] * w0[:, None] + self.VN[T[pick, 1]] * w1[:, None] + self.VN[T[pick, 2]] * w2[:, None]
        N /= np.linalg.norm(N, axis=1)[:, None]
        return P, N

    def hair_cards(self, name, style, colour, n_cards, levels=(0,), seed=7, card_w=0.16, segs=5):
        """Hair as cards: strips grown from roots on the scalp along the style's flow, held at the
        style's height above the skull, each a clump of strands from the card atlas. Vertex alpha
        carries the sway weight (0 at the root, 1 at the tip) for the hair-motion shader."""
        rng = np.random.default_rng(seed)
        v = self.v; head = self.h['head']
        f = self._scalp_faces()
        roots, rn = self._sample_surface(f, n_cards * 2, rng)
        # density thins toward the hairline (no hard staircase edge): keep a root with a probability
        # that rises from 0 at the hairline to 1 about 2.5 cm inside it
        hv = v[self.b.vgroups['body']]; hm = self.b.W[self.b.vgroups['body'], self.b.bones.index('head')] > 0.5
        zb0 = hv[hm][:, 2].min(); ey0 = self.heads['eye_l'][1]; ez0 = self.heads['eye_l'][2]
        tt = np.clip((ez0 - 0.25 - roots[:, 2]) / (ez0 - 0.25 - zb0), 0, 1)
        e = roots[:, 1] - (ey0 + 0.66 - 2.05 * tt ** 1.35)
        pk = np.clip(e / 0.18, 0, 1) ** 1.3
        keep = rng.random(len(roots)) < pk
        roots = roots[keep][:n_cards]; rn = rn[keep][:n_cards]
        edge_e = np.clip(e[keep][:n_cards] / 0.4, 0.3, 1.0)
        n_cards = len(roots)
        sp, sn = self._sample_surface(f, 6000, np.random.default_rng(seed + 1))
        tree = cKDTree(sp)
        top = sp[:, 1].max()
        ey = self.heads['eye_l'][1]; ez = self.heads['eye_l'][2]
        def flow_at(q, nrm):
            rel = q - head
            up = np.clip((q[1] - head[1]) / (top - head[1]), -1.5, 1.0)
            back = np.array([0.0, 0.0, -1.0]); down = np.array([0.0, -1.0, 0.0])
            if style == 'thick_side':
                part_x = 0.42                                   # parting on his left (generator +x)
                away = np.array([-1.0 if rel[0] < part_x else 1.0, 0.0, 0.0])
                d = (away * 0.9 + back * 0.75) * np.clip(up + 0.2, 0, 1) + (down * 0.8 + back * 0.45) * np.clip(0.6 - up, 0, 1)
                if rel[2] > 0.5 and up > 0.3:                   # the front swept back and up off the forehead
                    d = d + back * 0.9 + np.array([0, 0.25, 0])
            elif style == 'puff':
                d = (back * 0.8 + np.array([np.sign(rel[0]) * 0.25, 0.2, 0])) * np.clip(up + 0.3, 0, 1) + down * np.clip(0.5 - up, 0, 1)
            elif style == 'side':
                away = np.array([-1.0 if rel[0] < 0.35 else 1.0, 0, 0])
                d = (away * 0.8 + back * 0.6) * np.clip(up + 0.2, 0, 1) + (down + back * 0.3) * np.clip(0.6 - up, 0, 1)
            else:
                d = back * np.clip(up + 0.4, 0, 1) + down * np.clip(0.6 - up, 0, 1)
            d = d - nrm * d.dot(nrm)
            l = np.linalg.norm(d)
            return d / l if l > 1e-6 else np.cross(nrm, np.array([1.0, 0, 0]))
        def profile(q):
            """card length and height above the skull at a root"""
            up = np.clip((q[1] - head[1]) / (top - head[1]), -1.5, 1.0)
            frontness = np.clip((q[2] - head[2]) / 0.9, 0, 1)
            if style == 'thick_side':
                L = 0.34 + 0.34 * np.clip(up, 0, 1) + 0.12 * frontness * np.clip(up, 0, 1)
                Hh = 0.07 + 0.22 * np.clip(up, 0, 1) ** 1.2 + 0.08 * frontness
            elif style == 'puff':
                L = 0.32 + 0.3 * np.clip(up, 0, 1)
                Hh = 0.12 + 0.34 * np.clip(up + 0.2, 0, 1)
            elif style == 'side':
                L = 0.22 + 0.22 * np.clip(up, 0, 1); Hh = 0.05 + 0.12 * np.clip(up, 0, 1)
            else:
                L = 0.16 + 0.12 * np.clip(up, 0, 1); Hh = 0.04 + 0.08 * np.clip(up, 0, 1)
            return L, Hh
        Ps = []; Ns = []; UVs = []; Cs = []; Ts = []
        col = np.array(colour[:3])
        hl = ey + 0.66
        for i in range(n_cards):
            q = roots[i].copy(); nrm = rn[i]
            L, Hh = profile(q)
            edge = np.clip((q[1] - hl + 2.05 * 0) / 0.35, 0.25, 1.0) if q[2] > head[2] + 0.4 else 1.0
            edge = min(edge, edge_e[i])
            L *= rng.uniform(0.8, 1.15) * (0.6 + 0.4 * edge); Hh *= (0.5 + 0.5 * edge)
            w = card_w * rng.uniform(0.75, 1.25) * (0.55 + 0.45 * edge)
            twist = rng.uniform(-0.7, 0.7)
            seg = L / segs
            pts = [q + nrm * 0.01]; nrms = [nrm]
            d = flow_at(q, nrm)
            for k in range(1, segs + 1):
                s01 = k / segs
                nq = pts[-1] + d * seg
                _, j = tree.query(nq)
                c0 = sp[j]; n0 = sn[j]
                hgt = Hh * (1 - np.exp(-s01 * 3.0))
                nq = nq - n0 * np.dot(nq - c0, n0) + n0 * (hgt + 0.012)
                pts.append(nq); nrms.append(n0)
                d = flow_at(nq, n0)
            base = len(Ps)
            u0 = rng.integers(0, 4) * 0.25
            tint = rng.uniform(0.85, 1.12)
            for k, (pt, n0) in enumerate(zip(pts, nrms)):
                if k < len(pts) - 1: dk = pts[k + 1] - pt
                else: dk = pt - pts[k - 1]
                dk = dk / (np.linalg.norm(dk) + 1e-9)
                side = np.cross(dk, n0); side /= (np.linalg.norm(side) + 1e-9)
                # twist the card about its own axis a little for volume
                side = side * np.cos(twist) + n0 * np.sin(twist) * 0.6
                side /= (np.linalg.norm(side) + 1e-9)
                taper = 1.0 - 0.75 * (k / segs) ** 1.4
                for e in (-0.5, 0.5):
                    Ps.append(pt + side * w * e * taper)
                    Ns.append(n0)
                    UVs.append([u0 + (e + 0.5) * 0.25, k / segs])
                    root_dark = 0.72 + 0.28 * (k / segs)
                    Cs.append(list(np.clip(col * root_dark * tint, 0, 1)) + [(k / segs) ** 1.3])
            for k in range(segs):
                a0 = base + k * 2
                Ts.append([a0, a0 + 2, a0 + 1]); Ts.append([a0 + 1, a0 + 2, a0 + 3])
        P = np.array(Ps); T = np.array(Ts)
        W = np.zeros((len(P), len(self.names)), np.float32); W[:, self.names.index('head')] = 1
        p = Part(name, P, np.array(UVs), None, T, C=np.array(Cs), W=W)
        p.N = np.array(Ns); p.keep = True; p.levels = set(levels)
        self.parts.append(p)
        return p

    def face_cards(self, name, region, colour, n, length, seed=3, levels=(0, 1)):
        """Short cards for eyebrows, moustache, sideburns, beard: roots on the face skin,
        lying along the growth direction."""
        rng = np.random.default_rng(seed)
        lm = self.landmarks(); el = self.heads['eye_l']; er = self.heads['eye_r']
        def pred(c):
            x = np.abs(c[:, 0]); y = c[:, 1]; z = c[:, 2]
            if region == 'brows':
                ex = abs(el[0]); eyy = el[1]
                return (x > ex - 0.22) & (x < ex + 0.3) & (y > eyy + 0.13) & (y < eyy + 0.3) & (z > el[2] - 0.05)
            if region == 'moustache':
                return (x < lm['mouth_w'] * 1.15) & (y > lm['lip_top'] - 0.0) & (y < lm['nose_base'] + 0.0) & (z > lm['mouth_z'] - 0.35)
            if region == 'sideburns':
                return (x > abs(el[0]) + 0.45) & (y > el[1] - 0.5) & (y < el[1] + 0.3) & (z < el[2] - 0.7) & (z > el[2] - 1.1)
            return np.zeros(len(c), bool)
        f = self.faces('body', ['head'], pred)
        if len(f) == 0: return None
        roots, rn = self._sample_surface(f, n, rng)
        Ps = []; Ns = []; UVs = []; Cs = []; Ts = []
        col = np.array(colour[:3])
        for i in range(n):
            q = roots[i]; nrm = rn[i]
            sx = 1.0 if q[0] > 0 else -1.0
            if region == 'brows':
                d = np.array([sx * 1.0, 0.25, 0.0])
            elif region == 'moustache':
                d = np.array([sx * 0.55, -1.0, 0.15])
            else:
                d = np.array([0.0, -1.0, 0.1])
            d = d - nrm * d.dot(nrm); d /= np.linalg.norm(d) + 1e-9
            L = length * rng.uniform(0.7, 1.2)
            w = (0.035 if region == 'brows' else 0.05) * rng.uniform(0.8, 1.2)
            lift = 0.012 if region == 'moustache' else 0.004
            pts = [q + nrm * 0.003, q + d * L * 0.5 + nrm * (lift + 0.004), q + d * L + nrm * lift]
            base = len(Ps); u0 = rng.integers(0, 4) * 0.25
            side = np.cross(d, nrm); side /= np.linalg.norm(side) + 1e-9
            for k, pt in enumerate(pts):
                tp = 1.0 - 0.5 * k / 2
                for e in (-0.5, 0.5):
                    Ps.append(pt + side * w * e * tp); Ns.append(nrm); UVs.append([u0 + (e + 0.5) * 0.25, k / 2]); Cs.append(list(col * rng.uniform(0.85, 1.1)) + [0.0])
            for k in range(2):
                a0 = base + k * 2
                Ts.append([a0, a0 + 2, a0 + 1]); Ts.append([a0 + 1, a0 + 2, a0 + 3])
        P = np.array(Ps)
        W = np.zeros((len(P), len(self.names)), np.float32); W[:, self.names.index('head')] = 1
        p = Part(name, P, np.array(UVs), None, np.array(Ts), C=np.array(Cs), W=W)
        p.N = np.array(Ns); p.keep = True; p.levels = set(levels); p.morph_follow = True
        # follow the face's expressions: each card vertex borrows the morph offsets of the nearest skin vertex
        body_idx = self.b.vgroups['body']
        _, nn = cKDTree(self.v[body_idx]).query(P)
        p.src = np.asarray(body_idx)[nn]
        self.parts.append(p)
        return p

    def fibers(self, name, region, colour, n, seed=11, levels=(0,)):
        """Groomed hair fibres for eyebrows, moustache, sideburns and the scalp hairline.
        Each fibre is a thin curved strip (about 1 mm wide) carrying one to three strands from the
        fibre atlas, rooted on the skin by a density map (so edges thin out naturally), grown along
        the region's groom direction and lying close to the skin. Fibres borrow the morph offsets of
        the nearest skin vertex, so they move with every expression."""
        rng = np.random.default_rng(seed)
        lm = self.landmarks(); el = self.heads['eye_l']; head = self.h['head']
        ex = abs(el[0]); ey = el[1]; ez = el[2]
        v = self.v; b = self.b
        hv = v[b.vgroups['body']]; hm = b.W[b.vgroups['body'], b.bones.index('head')] > 0.5
        zb = hv[hm][:, 2].min()
        def hairline_y(c):
            t = np.clip((ez - 0.25 - c[:, 2]) / (ez - 0.25 - zb), 0, 1)
            return ey + 0.66 - 2.05 * t ** 1.35
        def arch(x):
            dx = (np.abs(x) - ex) / 0.4
            return dx, ey + 0.2 + 0.05 * (1 - dx ** 2) + np.clip(dx, 0, 1) * -0.06
        def density(c):
            x = np.abs(c[:, 0]); y = c[:, 1]; z = c[:, 2]
            if region == 'brows':
                dx, ay = arch(c[:, 0])
                hw = 0.055 * (1.25 - 0.65 * np.clip(dx, 0, 1))          # full at the head of the brow, thin tail
                d = np.clip(1 - np.abs(y - ay) / hw, 0, 1) ** 0.7
                d *= np.clip((dx + 0.55) / 0.12, 0, 1) * np.clip((0.88 - dx) / 0.25, 0, 1) * (z > ez - 0.3)
                return d
            if region == 'moustache':
                mw = lm['mouth_w'] * 1.22
                sub = lm['nose_tip'][1] - 0.065                  # the base of the nose (subnasale)
                top = sub - 0.01 - x * 0.12
                bot = lm['lip_top'] - 0.005
                d = np.clip((top - y) / 0.05, 0, 1) * np.clip((y - bot) / 0.03 + 0.4, 0, 1)
                d *= np.clip((mw - x) / 0.12, 0, 1) * (z > lm['mouth_z'] - 0.42)
                d *= 1.0 - 0.35 * np.exp(-(x / 0.05) ** 2)               # the philtrum is a little thinner
                return d
            if region == 'sideburns':
                hl = hairline_y(c)
                band = (x > ex + 0.5) & (z < ez - 0.55) & (z > ez - 1.15)
                return band * np.clip((hl + 0.02 - y) / 0.08, 0, 1) * np.clip((y - (ey - 0.42)) / 0.25, 0, 1)
            if region == 'hairline':
                e = y - hairline_y(c)
                return np.clip(1 - np.abs(e - 0.06) / 0.12, 0, 1) * (y > ey + 0.1)
            return np.zeros(len(c))
        if region == 'lashes':
            # roots along the lid margin: the eyelash helper strips' edge nearest each eyeball
            f = np.concatenate([self.faces(g) for g in ['helper-l-eyelashes-1', 'helper-l-eyelashes-2', 'helper-r-eyelashes-1', 'helper-r-eyelashes-2']])
            cand, cn = self._sample_surface(f, n * 3, rng)
            ec = np.where(cand[:, 0:1] > 0, self.heads['eye_l'], self.heads['eye_r'])
            dist = np.linalg.norm(cand - ec, axis=1)
            near = dist < np.percentile(dist, 45)
            roots = cand[near][:n]; rn = cn[near][:n]
            eyc = ec[near][:n]
        else:
            f = self.faces('body', ['head'], lambda c: density(c) > 0.02)
            print('  fibers', region, 'faces', len(f))
            if len(f) == 0: return None
            cand, cn = self._sample_surface(f, n * 4, rng)
            keep = rng.random(len(cand)) < density(cand)
            roots = cand[keep][:n]; rn = cn[keep][:n]
        Ps = []; Ns = []; UVs = []; Cs = []; Ts = []
        col = np.array(colour[:3])
        for i in range(len(roots)):
            q = roots[i]; nrm = rn[i]
            sx = 1.0 if q[0] > 0 else -1.0
            if region == 'brows':
                dx = (abs(q[0]) - ex) / 0.4
                th = np.radians(np.interp(dx, [-0.55, -0.25, 0.3, 0.9], [72, 35, 8, -18]) + rng.normal(0, 7))
                d = np.array([sx * np.cos(th), np.sin(th), 0.0])
                L = rng.uniform(0.06, 0.1); w = rng.uniform(0.009, 0.013); lift = (0.002, 0.004, 0.003)
            elif region == 'moustache':
                fx = abs(q[0]) / (lm['mouth_w'] * 1.2)
                th = np.radians(np.interp(fx, [0, 0.4, 1.0], [-90, -72, -55]) + rng.normal(0, 6))
                d = np.array([sx * np.cos(th), np.sin(th), 0.18])
                L = rng.uniform(0.09, 0.15); w = rng.uniform(0.01, 0.014); lift = (0.003, 0.014, 0.008)
            elif region == 'lashes':
                out = q - eyc[i]; out /= np.linalg.norm(out) + 1e-9
                upper = q[1] > eyc[i][1]
                d = out + np.array([0.0, 0.55 if upper else -0.25, 0.45])
                nrm = out
                L = rng.uniform(0.06, 0.09) if upper else rng.uniform(0.025, 0.04)
                w = rng.uniform(0.006, 0.008); lift = (0.0, 0.006 if upper else 0.002, 0.016 if upper else 0.004)
            elif region == 'sideburns':
                d = np.array([0.0, -1.0, 0.12]) + rng.normal(0, 0.12, 3)
                L = rng.uniform(0.05, 0.09); w = rng.uniform(0.01, 0.014); lift = (0.003, 0.006, 0.004)
            else:   # hairline: swept back and up at the front, down and back at the temples and nape
                rel = q - head
                if rel[2] > 0.35:
                    d = np.array([-0.25 * sx, 0.35, -1.0])
                elif rel[1] > 0.2:
                    d = np.array([0.0, -0.4, -1.0])
                else:
                    d = np.array([0.0, -1.0, -0.35])
                d = d + rng.normal(0, 0.12, 3)
                # long and lifted: swept back up into the hair mass, not a short stubbly band
                L = rng.uniform(0.14, 0.26); w = rng.uniform(0.009, 0.012); lift = (0.003, 0.02, 0.045)
            d = d - nrm * d.dot(nrm); d /= np.linalg.norm(d) + 1e-9
            side = np.cross(d, nrm); side /= np.linalg.norm(side) + 1e-9
            curl = rng.normal(0, 0.15)
            pts = [q + nrm * lift[0], q + (d + side * curl * 0.5) * L * 0.5 + nrm * lift[1], q + (d + side * curl) * L + nrm * lift[2]]
            base = len(Ps)
            u0 = rng.integers(0, 8) * 0.125
            tint = rng.uniform(0.75, 1.2)
            for k, pt in enumerate(pts):
                tp = 1.0 - 0.6 * k / 2
                for e in (-0.5, 0.5):
                    Ps.append(pt + side * w * e * tp); Ns.append(nrm)
                    UVs.append([u0 + (e + 0.5) * 0.125, k / 2])
                    Cs.append(list(np.clip(col * tint, 0, 1)) + [k / 2])
            for k in range(2):
                a0 = base + k * 2
                Ts.append([a0, a0 + 2, a0 + 1]); Ts.append([a0 + 1, a0 + 2, a0 + 3])
        P = np.array(Ps)
        W = np.zeros((len(P), len(self.names)), np.float32); W[:, self.names.index('head')] = 1
        p = Part(name, P, np.array(UVs), None, np.array(Ts), C=np.array(Cs), W=W)
        p.N = np.array(Ns); p.keep = True; p.levels = set(levels); p.morph_follow = True
        body_idx = self.b.vgroups['body']
        _, nn = cKDTree(self.v[body_idx]).query(P)
        p.src = np.asarray(body_idx)[nn]
        self.parts.append(p)
        return p

    def face_hair(self, name, region, length, shells=3, colour=(0.05, 0.04, 0.04)):
        """shells grown from the face skin itself: moustache / beard"""
        v = self.v; h = self.h
        lm = self.landmarks()
        def pred(c):
            x = np.abs(c[:, 0]); y = c[:, 1]; z = c[:, 2]
            if region == 'moustache':
                return (x < lm['mouth_w'] * 1.12) & (y > lm['lip_top'] - 0.01) & (y < lm['nose_base'] + 0.02) & (z > lm['mouth_z'] - 0.35)
            if region == 'goatee':
                return (y < lm['lip_bot'] + 0.02) & (y > lm['chin'] - 0.22) & (x < lm['mouth_w'] * 1.15) & (z > lm['mouth_z'] - 0.9)
            if region == 'beard':
                jaw = (y < lm['lip_bot'] + 0.02) & (y > lm['chin'] - 0.25) & (z > lm['mouth_z'] - 1.25) & (x < lm['mouth_w'] * 2.3)
                side = (y < lm['lip_top'] + 0.2) & (y > lm['chin'] - 0.1) & (x > lm['mouth_w'] * 1.2) & (x < lm['mouth_w'] * 2.4) & (z > lm['mouth_z'] - 1.3) & (z < lm['mouth_z'] - 0.25)
                return jaw | side
            return np.zeros(len(c), bool)
        f = self.faces('body', ['head'], pred)
        lips = lm['lip_verts']
        f = np.array([i for i in f if not np.isin(self.b.faces[i], lips).all()], int)
        if len(f) == 0: return None
        p = self.part(name, f, offset=np.full(len(v), length * 0.3), uv='cyl', colour=list(colour) + [1])
        P0, UV0, C0, T0, S0 = p.P.copy(), p.UV.copy(), p.C.copy(), p.tris.copy(), p.src.copy()
        N0 = self.normals(P0, T0); Pl, UVl, Cl, Tl, Sl = [P0], [UV0 * 4], [C0], [T0], [S0]
        for k in range(1, shells):
            t = k / (shells - 1)
            Ck = C0.copy(); Ck[:, 3] = 1.0 - 0.18 * t
            Pk = P0 + N0 * (length * 0.7 * t) + np.array([0, -length * 0.5 * t, 0])
            Pl.append(Pk); UVl.append(UV0 * 4); Cl.append(Ck); Tl.append(T0 + len(P0) * k); Sl.append(S0)
        p.P = np.vstack(Pl); p.UV = np.vstack(UVl); p.C = np.vstack(Cl); p.tris = np.vstack(Tl); p.src = np.concatenate(Sl)
        p.morph_follow = True
        return p

    def landmarks(self):
        if hasattr(self, '_lm'): return self._lm
        v = self.v; b = self.b
        from PIL import Image
        mask = np.asarray(Image.open(b.data + '/textures/mpfb_lips.jpg').convert('L').resize((512, 512)))
        acc = np.zeros(len(v)); cnt = np.zeros(len(v))
        for f, ft, g in zip(b.faces, b.face_uv, b.face_group):
            if g != 'body': continue
            for vi, ti in zip(f, ft):
                u, w = b.vt[ti]; acc[vi] += mask[min(511, int((1 - w) * 512)), min(511, int(u * 512))]; cnt[vi] += 1
        lip = np.where((cnt > 0) & (acc / np.maximum(cnt, 1) > 110))[0]
        head = np.where(b.W[:, b.bones.index('head')] > 0.5)[0]; head = head[head < 13380]
        mid = head[np.abs(v[head, 0]) < 0.08]
        nose = mid[np.argmax(v[mid, 2])]
        L = v[lip]
        self._lm = {'lip_verts': lip, 'mouth_w': np.abs(L[:, 0]).max(), 'lip_top': L[:, 1].max(), 'lip_bot': L[:, 1].min(), 'mouth_z': L[:, 2].max(),
                    'nose_tip': v[nose], 'nose_base': v[nose][1] - 0.2, 'chin': v[mid][v[mid, 2] > v[nose][2] - 1.4][:, 1].min(),
                    'eye_l': self.heads['eye_l'], 'eye_r': self.heads['eye_r']}
        return self._lm

    # ------------------------------------------------------------ extras
    def footwear(self, kind):
        v = self.v; h = self.h; g = self.ground
        f = self.faces('body', ['foot', 'ball'])
        fn = np.array([self.VN[self.b.faces[i]].mean(0) for i in f]); c = self.face_c[f]
        ball_z = h['ball_l'][2]; ankle = h['foot_l']
        if kind == 'shoe':
            # the whole foot, heel to toe, up to just over the ankle bone: a closed shoe that
            # stands a little off the skin everywhere (more at the toe box), so nothing pokes through
            sel = f[c[:, 1] < ankle[1] + 0.12]
            off = np.full(len(v), 0.1)
            toe = v[:, 2] > ball_z - 0.1
            off[toe] += np.clip((v[toe, 2] - ball_z + 0.1) * 0.12, 0, 0.08)
            sh = np.zeros_like(v); sh[:, 1] = np.where(v[:, 1] < g + 0.08, -0.04, 0.0)
            self.part('shoes', sel, offset=off, shift=sh, uv='cyl', colour=[0.07, 0.06, 0.06, 1]); return
        sole = f[fn[:, 1] < -0.45]
        sh = np.zeros_like(v); sh[:, 1] = -(v[:, 1] - g) * 0.9 - 0.02
        self.part(kind + '_sole', sole, offset=np.full(len(v), 0.06), shift=sh * 0 + np.array([0, -0.1, 0]), uv='cyl', colour=[0.2, 0.13, 0.08, 1] if kind == 'sandal' else [0.12, 0.1, 0.1, 1])
        topf = fn[:, 1] > -0.1
        if kind == 'sandal':
            band = topf & (((c[:, 2] > ball_z - 0.45) & (c[:, 2] < ball_z + 0.25)) | ((c[:, 2] > ankle[2] + 0.35) & (c[:, 2] < ankle[2] + 0.85)) | ((c[:, 2] < ankle[2] - 0.35) & (c[:, 1] < ankle[1] - 0.05)))
            self.part('sandal_straps', f[band], offset=np.full(len(v), 0.055), uv='cyl', colour=[0.55, 0.26, 0.1, 1])
        else:
            band = topf & (c[:, 2] > ball_z - 0.5) & (c[:, 2] < ball_z + 0.1)
            self.part('chappal_straps', f[band], offset=np.full(len(v), 0.05), uv='cyl', colour=[0.1, 0.12, 0.3, 1])

    def watch(self, colour):
        wr = self.h['hand_l']
        f = self.faces('helper-tights', ['lowerarm_l', 'hand_l'], lambda c: (np.linalg.norm(c - wr, axis=1) < 0.42) & (c[:, 0] > 0))
        if len(f): self.part('watch', f, offset=np.full(len(self.v), 0.07), uv='cyl', colour=list(colour) + [1])

    def glasses(self):
        el, er = self.heads['eye_l'], self.heads['eye_r']; z = max(el[2], er[2]) + 0.52
        pts = []; T = []; r = 0.3
        def ring(c):
            n0 = len(pts)
            for i in range(12):
                a = 2 * math.pi * i / 12
                for rr in (r, r - 0.035):
                    pts.append([c[0] + math.cos(a) * rr * 1.15, c[1] + math.sin(a) * rr * 0.85, z])
            for i in range(12):
                a = n0 + i * 2; b = n0 + ((i + 1) % 12) * 2
                T.extend([[a, b, a + 1], [b, b + 1, a + 1], [a, a + 1, b], [b, a + 1, b + 1]])
        ring(el); ring(er)
        n0 = len(pts)
        for sx in (1, -1):
            x = (el[0] + 0.36) * sx
            q = [[x, el[1] + 0.02, z], [x, el[1] - 0.02, z], [x * 1.02, el[1] - 0.02, z - 1.0], [x * 1.02, el[1] + 0.02, z - 1.0]]
            k = len(pts); pts.extend(q); T.extend([[k, k + 1, k + 2], [k, k + 2, k + 3], [k, k + 2, k + 1], [k, k + 3, k + 2]])
        k = len(pts); pts.extend([[-0.1, el[1] + 0.05, z], [0.1, el[1] + 0.05, z], [0.1, el[1] + 0.01, z], [-0.1, el[1] + 0.01, z]]); T.extend([[k, k + 1, k + 2], [k, k + 2, k + 3], [k, k + 2, k + 1], [k, k + 3, k + 2]])
        pts = np.array(pts, float); W = np.zeros((len(pts), len(self.names)), np.float32); W[:, self.names.index('head')] = 1
        p = Part('glasses', pts, np.zeros((len(pts), 2)), None, np.array(T), W=W); p.C[:] = [0.05, 0.05, 0.06, 1]
        self.parts.append(p)

    # ------------------------------------------------------------ output
    def finalize(self, p):
        """-> export-space arrays for a part"""
        nb = len(self.names)
        W = self.weights(p)
        if W.shape[1] < nb: W = np.hstack([W, np.zeros((len(W), nb - W.shape[1]), np.float32)])
        top = np.argsort(-W, axis=1)[:, :4]
        w4 = np.take_along_axis(W, top, 1); s = w4.sum(1, keepdims=True); s[s == 0] = 1; w4 = w4 / s
        return top, w4

    def xform(self, P):
        Q = P.copy(); Q[:, 1] -= self.ground; Q *= 0.1; Q[:, 0] *= -1; Q[:, 2] *= -1; return Q

    def dxform(self, D):
        Q = D * 0.1; Q[:, 0] *= -1; Q[:, 2] *= -1; return Q

    def export(self, glb, lods):
        """lods: list of (level, keep_ratio). Level 0 is undecimated."""
        heads = {n: self.xform(self.heads[n][None, :])[0] for n in self.names}
        glb.add_skeleton(self.names, self.parents, heads)
        stats = {}
        for level, ratio in lods:
            total = 0
            for p in self.parts:
                if getattr(p, 'levels', None) is not None and level not in p.levels:
                    continue
                P, T, UV, C = p.P, p.tris, p.UV, p.C
                J, W4 = self.finalize(p)
                morphs = [(n, d) for n, d in p.morph.items()]
                r = ratio
                if p.name in ('eyes', 'glasses', 'teeth', 'tongue', 'lashes') and level < 2: r = 1.0
                if level >= 2 and p.name in ('teeth', 'tongue', 'lashes', 'glasses', 'watch', 'belt'): continue
                if getattr(p, 'keep', False): r = 1.0
                if r < 0.999 and len(T) > 40:
                    pts, tris = fast_simplification.simplify(P.astype(np.float32), T.astype(np.int32), target_reduction=1 - r, agg=5)
                    if len(tris) < 4: continue
                    _, nn = cKDTree(P).query(pts)
                    P2, T2 = pts.astype(float), tris
                    UV, C, J, W4 = UV[nn], C[nn], J[nn], W4[nn]
                    morphs = [(n, d[nn]) for n, d in morphs] if level <= 1 else []
                    P, T = P2, T2
                N = p.N if getattr(p, 'N', None) is not None and len(p.N) == len(P) else self.normals(P, T)
                N2 = N.copy(); N2[:, 0] *= -1; N2[:, 2] *= -1
                glb.add_mesh('L%d_%s' % (level, p.name), self.xform(P), N2, UV, J, W4, T, C, [(n, self.dxform(d)) for n, d in morphs])
                total += len(T)
            stats[level] = total
        return stats
