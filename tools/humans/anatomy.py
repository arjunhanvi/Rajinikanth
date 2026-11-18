"""R1 body reconstruction: selective Catmull-Clark subdivision of the body's quad topology, then
anatomical forms built into the new geometry from the skeleton's landmarks.

Units are generator space: decimetres, face toward +Z, the character's left on +X, Y up.
Amplitudes are kept to a naturally proportioned, lean-to-average man: structures are suggested by
smooth, falloff-shaped volumes and hollows (no noise, no bodybuilder definition).
"""
import numpy as np


# ------------------------------------------------------------------ subdivision
def _quads(p):
    """Rebuild the part's quads (in part vertex indices) from its fan-triangulated faces."""
    faces = {}
    for t, fid in zip(p.tris, p.tf):
        faces.setdefault(int(fid), []).append(t)
    out = []
    for fid, ts in faces.items():
        if len(ts) == 2:
            a, b, c = ts[0]
            d = [x for x in ts[1] if x not in (a, c)]
            out.append((fid, [a, b, c, d[0]] if d else [a, b, c]))
        else:
            for t in ts:
                out.append((fid, list(t)))
    return out


def subdivide(c, p, face_ok):
    """One Catmull-Clark level on the faces where face_ok(base_face_id) is true. Topology is welded by
    base vertex (so UV seams do not become creases); the region's border stays fixed (edge points at
    midpoints), so neighbouring meshes keep matching. UVs, colours, weights and morphs follow by
    linear stencils."""
    quads = _quads(p)
    sel = [(fid, q) for fid, q in quads if face_ok(fid) and len(q) == 4]
    keep = [(fid, q) for fid, q in quads if not (face_ok(fid) and len(q) == 4)]
    if not sel:
        return 0
    src = p.src
    P = p.P
    W = c.weights(p)
    # welded topology over the selected faces
    wpos = {}
    for fid, q in sel:
        for i in q:
            wpos[int(src[i])] = P[i]
    edges = {}
    vfaces = {}
    fpts = []
    for k, (fid, q) in enumerate(sel):
        fpts.append(np.mean([P[i] for i in q], axis=0))
        for j in range(4):
            a, b = int(src[q[j]]), int(src[q[(j + 1) % 4]])
            e = (min(a, b), max(a, b))
            edges.setdefault(e, []).append(k)
            vfaces.setdefault(a, []).append(k)
    fpts = np.array(fpts)
    boundary_v = set()
    for e, fl in edges.items():
        if len(fl) == 1:
            boundary_v.update(e)
    epos = {}
    for e, fl in edges.items():
        mid = (wpos[e[0]] + wpos[e[1]]) * 0.5
        epos[e] = mid if len(fl) == 1 else (wpos[e[0]] + wpos[e[1]] + fpts[fl[0]] + fpts[fl[1]]) * 0.25
    vneigh = {}
    for e in edges:
        vneigh.setdefault(e[0], set()).add(e[1])
        vneigh.setdefault(e[1], set()).add(e[0])
    vnew = {}
    for v, pos in wpos.items():
        if v in boundary_v:
            vnew[v] = pos
            continue
        fl = vfaces[v]
        n = len(fl)
        F = fpts[fl].mean(0)
        R = np.mean([(pos + wpos[u]) * 0.5 for u in vneigh[v]], axis=0)
        vnew[v] = (F + 2 * R + (n - 3) * pos) / n
    # new split vertices
    NP, NUV, NC, NW, NS = [], [], [], [], []
    morphs = {nm: [] for nm in p.morph}
    remap = {}

    def add(pos, uv, col, w, s, md):
        NP.append(pos); NUV.append(uv); NC.append(col); NW.append(w); NS.append(s)
        for nm in morphs:
            morphs[nm].append(md[nm])
        return len(NP) - 1

    def old(i):
        if i not in remap:
            pos = vnew.get(int(src[i]), P[i]) if any(int(src[i]) == x for x in (int(src[i]),)) else P[i]
            pos = vnew[int(src[i])] if int(src[i]) in vnew else P[i]
            remap[i] = add(pos, p.UV[i], p.C[i], W[i], src[i], {nm: d[i] for nm, d in p.morph.items()})
        return remap[i]
    ekey = {}

    def edge(i, j):
        a, b = int(src[i]), int(src[j])
        e = (min(a, b), max(a, b))
        k = (e, tuple(np.round(p.UV[i], 5)), tuple(np.round(p.UV[j], 5))) if a < b else (e, tuple(np.round(p.UV[j], 5)), tuple(np.round(p.UV[i], 5)))
        if k not in ekey:
            ekey[k] = add(epos[e], (p.UV[i] + p.UV[j]) * 0.5, (p.C[i] + p.C[j]) * 0.5, (W[i] + W[j]) * 0.5, src[i],
                          {nm: (d[i] + d[j]) * 0.5 for nm, d in p.morph.items()})
        return ekey[k]
    T = []
    for k, (fid, q) in enumerate(sel):
        fp = add(fpts[k], np.mean([p.UV[i] for i in q], 0), np.mean([p.C[i] for i in q], 0), np.mean([W[i] for i in q], 0), src[q[0]],
                 {nm: np.mean([d[i] for i in q], 0) for nm, d in p.morph.items()})
        o = [old(i) for i in q]
        e = [edge(q[j], q[(j + 1) % 4]) for j in range(4)]
        for j in range(4):
            # sub-quad: corner j, edge j, face point, edge j-1
            a, b_, cc, d = o[j], e[j], fp, e[j - 1]
            T.append([a, b_, cc]); T.append([a, cc, d])
    TF = [0] * len(T)
    for fid, q in keep:
        o = [old(i) for i in q]
        for kk in range(1, len(o) - 1):
            T.append([o[0], o[kk], o[kk + 1]]); TF.append(fid)
    p.P = np.array(NP); p.UV = np.array(NUV); p.C = np.array(NC); p.W = np.array(NW, np.float32); p.src = np.array(NS)
    p.tris = np.array(T); p.tf = np.array(TF)
    for nm in morphs:
        p.morph[nm] = np.array(morphs[nm])
    p.N = None
    return len(sel)


# ------------------------------------------------------------------ anatomy fields
def _seg(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1), t


def _g(d, r):
    return np.exp(-(d / r) ** 2)


def body_fields(c, P, N):
    """Displacement (dm, along the normal) for anatomical forms at positions P with normals N."""
    h = c.h
    D = np.zeros(len(P))
    fr = np.clip(N[:, 2] * 1.6, 0, 1)          # facing forward
    bk = np.clip(-N[:, 2] * 1.6, 0, 1)         # facing back
    up = np.clip(N[:, 1] * 1.6, 0, 1)
    dn = np.clip(-N[:, 1] * 1.6, 0, 1)
    for sx in (1.0, -1.0):
        side = (P[:, 0] * sx) > -0.02
        o = np.clip(sx * N[:, 0] * 1.6, 0, 1)   # facing outward on this side
        inn = np.clip(-sx * N[:, 0] * 1.6, 0, 1)
        S = 'l' if sx > 0 else 'r'
        sh = h['upperarm_' + S]; el = h['lowerarm_' + S]; wr = h['hand_' + S]
        cl = h['clavicle_' + S]; th = h['thigh_' + S]; kn = h['calf_' + S]; an = h['foot_' + S]; ba = h['ball_' + S]
        nk = h['neck_01']; sp3 = h['spine_03']; sp2 = h['spine_02']; sp1 = h['spine_01']; pel = h['pelvis']; hd = h['head']
        acro = sh + np.array([sx * 0.05, 0.14, 0.0])
        sc = np.array([sx * 0.12, cl[1] + 0.05, cl[2] + 0.42])        # sternoclavicular joint (front of the chest)
        # --- neck and shoulder girdle
        d, _ = _seg(P, sc, acro + np.array([0, 0.02, 0.18]))
        D += side * 0.024 * _g(d, 0.06) * np.clip(fr + up, 0, 1)                          # clavicle
        d2, _ = _seg(P, sc + np.array([0, -0.14, 0]), acro + np.array([0, -0.15, 0.14]))
        D -= side * 0.012 * _g(d2, 0.08) * fr                                              # hollow under the clavicle
        d3, _ = _seg(P, sc + np.array([sx * 0.08, 0.12, -0.12]), acro + np.array([-sx * 0.12, 0.08, -0.02]))
        D -= side * 0.016 * _g(d3, 0.07) * up                                              # hollow above the clavicle
        mast = hd + np.array([sx * 0.42, -0.42, -0.12])
        d4, _ = _seg(P, mast, sc + np.array([0, 0.06, -0.02]))
        D += side * 0.018 * _g(d4, 0.06) * np.clip(fr + o * 0.6, 0, 1) * (P[:, 1] < hd[1] - 0.25)   # sternocleidomastoid
        d5, _ = _seg(P, nk + np.array([sx * 0.18, 0.2, -0.2]), acro + np.array([0, 0.05, -0.08]))
        D += side * 0.02 * _g(d5, 0.14) * np.clip(up + bk * 0.6, 0, 1)                    # trapezius slope
        # --- chest
        pc = np.array([sx * 0.52, sp3[1] - 0.12, 0.0])
        rel = P - pc
        pm = _g(np.sqrt((rel[:, 0] / 0.62) ** 2 + (rel[:, 1] / 0.42) ** 2), 1.0) * fr
        edge_low = np.clip((P[:, 1] - (sp3[1] - 0.52)) / 0.06, 0, 1)                      # a defined lower edge
        D += side * 0.03 * pm * edge_low                                                   # pectoral mass
        dpg, _ = _seg(P, sc + np.array([sx * 0.5, -0.05, -0.1]), sh + np.array([-sx * 0.18, -0.3, 0.2]))
        D -= side * 0.012 * _g(dpg, 0.05) * fr                                             # deltopectoral groove
        # --- deltoid
        dc = sh + np.array([sx * 0.12, -0.18, 0.0])
        D += side * 0.028 * _g(np.linalg.norm(P - dc, axis=1), 0.32) * np.clip(o + up * 0.5, 0, 1)
        # --- back: scapulae and the spine
        md_top = np.array([sx * 0.33, sp3[1] + 0.25, -0.0]); md_bot = np.array([sx * 0.42, sp2[1] - 0.15, 0.0])
        dm_, _ = _seg(P * np.array([1, 1, 0]), md_top, md_bot)
        D += side * 0.014 * _g(dm_, 0.06) * bk                                             # medial border of the scapula
        dss, _ = _seg(P * np.array([1, 1, 0]), md_top, np.array([acro[0], acro[1] - 0.06, 0]))
        D += side * 0.013 * _g(dss, 0.06) * bk                                             # spine of the scapula
        D += side * 0.012 * _g(np.linalg.norm((P - np.array([sx * 0.45, sp2[1] - 0.2, 0])) * np.array([1, 1, 0]), axis=1), 0.12) * bk   # inferior angle
        er = np.clip((P[:, 1] - pel[1]) / 0.3, 0, 1) * np.clip((sp2[1] - P[:, 1]) / 0.3, 0, 1)
        D += side * 0.016 * _g(np.abs(P[:, 0]) - 0.24, 0.1) * bk * er                      # erector spinae (lower back)
        # --- pelvis, flank, gluteal
        asis = np.array([sx * 0.62, pel[1] + 0.22, 0.0])
        D += side * 0.012 * _g(np.linalg.norm((P - asis) * np.array([1, 1, 0.0]), axis=1), 0.1) * fr
        ing, _ = _seg(P * np.array([1, 1, 0]), asis * np.array([1, 1, 0]) + np.array([0, -0.06, 0]), np.array([sx * 0.12, pel[1] - 0.35, 0]))
        D -= side * 0.014 * _g(ing, 0.05) * fr                                             # inguinal groove
        D += side * 0.012 * _g(P[:, 1] - (pel[1] + 0.32), 0.12) * o * (np.abs(P[:, 2] - pel[2]) < 0.5)   # flank above the iliac crest
        gc = np.array([sx * 0.42, pel[1] - 0.3, 0.0])
        D += side * 0.022 * _g(np.linalg.norm((P - gc) * np.array([1, 1, 0]), axis=1), 0.42) * bk   # gluteal mass
        D -= side * 0.016 * _g(P[:, 1] - (th[1] - 0.62), 0.05) * bk * (np.abs(P[:, 0]) < 0.75)       # gluteal fold
        # --- upper arm, elbow, forearm, wrist (the rest pose has the arms out, palms down)
        dua, tua = _seg(P, sh, el)
        arm = (dua < 0.6) & side
        D += arm * 0.018 * _g(tua - 0.6, 0.22) * fr                                        # biceps
        D += arm * 0.016 * _g(tua - 0.45, 0.25) * bk                                       # triceps
        D += side * 0.022 * _g(np.linalg.norm(P - (el + np.array([0, 0, -0.06])), axis=1), 0.07) * bk     # olecranon
        D -= side * 0.012 * _g(np.linalg.norm(P - (el + np.array([0, 0, 0.06])), axis=1), 0.08) * fr      # inside of the elbow
        D += side * 0.010 * _g(np.linalg.norm(P - (el + np.array([0, -0.06, 0])), axis=1), 0.05)          # epicondyle
        dfa, tfa = _seg(P, el, wr)
        fa = (dfa < 0.5) & side
        D += fa * 0.018 * _g(tfa - 0.22, 0.22) * np.clip(up + fr * 0.5, 0, 1)             # brachioradialis and extensors
        D += fa * 0.012 * _g(tfa - 0.3, 0.25) * dn                                         # flexors
        D += side * 0.011 * _g(np.linalg.norm(P - (wr + np.array([-sx * 0.04, 0.05, -0.06])), axis=1), 0.04)   # head of the ulna
        # --- thigh, knee, calf, ankle
        dth, tth = _seg(P, th, kn)
        leg = (dth < 0.9) & side
        D += leg * 0.016 * _g(tth - 0.45, 0.3) * fr                                        # quadriceps
        D += leg * 0.014 * _g(tth - 0.45, 0.3) * bk                                        # hamstrings
        D -= leg * 0.010 * _g(tth - 0.6, 0.3) * o * (np.abs(N[:, 2]) < 0.6)                # iliotibial band groove
        vm = kn + np.array([-sx * 0.1, 0.22, 0.08])
        D += side * 0.026 * _g(np.linalg.norm(P - vm, axis=1), 0.12) * np.clip(fr + inn, 0, 1)            # vastus medialis
        pat = kn + np.array([0, 0.04, 0.12])
        D += side * 0.03 * _g(np.linalg.norm((P - pat) * np.array([1.0, 0.75, 1.0]), axis=1), 0.075) * fr  # patella
        for e in (-1.0, 1.0):
            D -= side * 0.016 * _g(np.linalg.norm(P - (kn + np.array([e * 0.07, -0.07, 0.1])), axis=1), 0.05) * fr   # hollows beside the patellar tendon
        D -= side * 0.016 * _g(np.linalg.norm(P - (kn + np.array([0, 0.02, -0.1])), axis=1), 0.09) * bk   # back of the knee
        D += side * 0.03 * _g(np.linalg.norm(P - (kn + np.array([-sx * 0.06, -0.3, -0.12])), axis=1), 0.16) * np.clip(bk + inn * 0.5, 0, 1)   # gastrocnemius, inner head (lower)
        D += side * 0.022 * _g(np.linalg.norm(P - (kn + np.array([sx * 0.07, -0.24, -0.12])), axis=1), 0.14) * np.clip(bk + o * 0.5, 0, 1)    # outer head (higher)
        dtb, ttb = _seg(P, kn + np.array([0, -0.1, 0.1]), an + np.array([0, 0.15, 0.08]))
        D += side * 0.006 * _g(dtb, 0.03) * fr                                             # shin (tibial crest)
        ach = an + np.array([0, 0.25, -0.1])
        D -= side * 0.012 * _g(np.linalg.norm((P - ach) * np.array([1.0, 0.5, 1.0]), axis=1), 0.08) * np.clip(o + inn, 0, 1) * (P[:, 2] < an[2])   # beside the Achilles tendon
        D += side * 0.026 * _g(np.linalg.norm(P - (an + np.array([-sx * 0.07, 0.02, 0.0])), axis=1), 0.045) * inn   # medial malleolus (higher)
        D += side * 0.024 * _g(np.linalg.norm(P - (an + np.array([sx * 0.07, -0.02, -0.01])), axis=1), 0.045) * o   # lateral malleolus (lower)
        arch = (an + ba) * 0.5 + np.array([-sx * 0.06, -0.04, 0])
        D -= side * 0.03 * _g(np.linalg.norm(P - arch, axis=1), 0.12) * dn                  # the arch
        # --- hand (palm down in the rest pose)
        th1 = h.get('thumb_01_' + S)
        if th1 is not None:
            mid1 = h['middle_01_' + S]; pk1 = h['pinky_01_' + S]; ix1 = h['index_01_' + S]
            thenar = (wr + th1) * 0.5 + np.array([0, -0.03, 0])
            D += side * 0.024 * _g(np.linalg.norm(P - thenar, axis=1), 0.09) * dn            # thenar mound
            hyp = (wr + pk1) * 0.5 + np.array([0, -0.03, 0])
            D += side * 0.016 * _g(np.linalg.norm(P - hyp, axis=1), 0.08) * dn               # hypothenar
            pal = (wr + mid1) * 0.5 + (mid1 - wr) * 0.15
            D -= side * 0.016 * _g(np.linalg.norm(P - pal, axis=1), 0.08) * dn               # hollow of the palm
            for k1 in (ix1, mid1, h['ring_01_' + S], pk1):
                D += side * 0.016 * _g(np.linalg.norm(P - (k1 + np.array([0, 0.03, 0])), axis=1), 0.04) * up   # knuckles
    # midline: suprasternal notch, sternum, linea alba, spine groove, Adam's apple
    nk = h['neck_01']; sp3 = h['spine_03']; sp2 = h['spine_02']; pel = h['pelvis']; hd = h['head']
    cl = h['clavicle_l']
    notch = np.array([0.0, cl[1] + 0.06, cl[2] + 0.38])
    D -= 0.026 * _g(np.linalg.norm(P - notch, axis=1), 0.07) * fr
    mid = _g(P[:, 0], 0.07)
    D -= 0.010 * mid * fr * (P[:, 1] < notch[1] - 0.1) * (P[:, 1] > sp2[1] - 0.25)        # sternal groove
    D -= 0.006 * mid * fr * (P[:, 1] < sp2[1] - 0.25) * (P[:, 1] > pel[1] + 0.05)         # linea alba (faint)
    D -= 0.022 * _g(P[:, 0], 0.09) * bk * (P[:, 1] > pel[1] - 0.1) * (P[:, 1] < nk[1] + 0.1)   # spinal groove
    adam = np.array([0.0, (nk[1] + hd[1]) * 0.5 - 0.05, nk[2] + 0.42])
    D += 0.018 * _g(np.linalg.norm((P - adam) * np.array([1.0, 0.6, 1.0]), axis=1), 0.05) * fr
    return D


def sculpt(c, parts, smooth_iters=1):
    """Apply the anatomical forms to the (subdivided) body parts, in one consistent field so the parts
    still meet."""
    # normals welded across all body parts by position, so a seam vertex moves the same way in both parts
    keys = []
    acc = {}
    Ns = []
    for p in parts:
        N = c.normals(p.P, p.tris)
        Ns.append(N)
        k = [tuple(x) for x in np.round(p.P, 4)]
        keys.append(k)
        for kk, n in zip(k, N):
            acc[kk] = acc.get(kk, 0) + n
    for p, k in zip(parts, keys):
        N = np.array([acc[kk] for kk in k])
        N /= np.linalg.norm(N, axis=1)[:, None] + 1e-9
        D = body_fields(c, p.P, N)
        # wrist flattening: the forearm becomes oval toward the wrist (back-to-palm thinner)
        for S, sx in (('l', 1.0), ('r', -1.0)):
            el = c.h['lowerarm_' + S]; wr = c.h['hand_' + S]
            d, t = _seg(p.P, el, wr)
            m = (d < 0.45) & ((p.P[:, 0] * sx) > 0)
            k = np.clip((t - 0.55) / 0.45, 0, 1) * m * (t < 0.999)
            axis_c = el + (wr - el) * t[:, None]
            p.P[:, 1] -= (p.P[:, 1] - axis_c[:, 1]) * 0.14 * k
        p.P = p.P + N * D[:, None]
        p.N = None
    return parts
