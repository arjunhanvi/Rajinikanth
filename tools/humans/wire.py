"""Wireframe-on-shaded renders of a character's exported skin meshes (the exact .glb the game loads),
for topology inspection. Usage: python3 tools/humans/wire.py <model.glb> <out_prefix>"""
import json
import struct
import sys
import numpy as np
from PIL import Image, ImageDraw


def load(path, prefix='L0_skin'):
    d = open(path, 'rb').read()
    l = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20 + l])
    off = 20 + l + 8
    acc, bv = j['accessors'], j['bufferViews']

    def arr(ai, dt, n):
        a = acc[ai]; v = bv[a['bufferView']]
        o = off + v.get('byteOffset', 0) + a.get('byteOffset', 0)
        return np.frombuffer(d, dtype=dt, count=a['count'] * n, offset=o).reshape(-1, n) if n > 1 else np.frombuffer(d, dtype=dt, count=a['count'], offset=o)
    Ps, Ts = [], []
    base = 0
    for m in j['meshes']:
        if not m['name'].startswith(prefix):
            continue
        p = m['primitives'][0]
        P = arr(p['attributes']['POSITION'], np.float32, 3)
        ia = acc[p['indices']]
        dt = {5123: np.uint16, 5125: np.uint32}[ia['componentType']]
        T = arr(p['indices'], dt, 1).reshape(-1, 3).astype(np.int64)
        Ps.append(P); Ts.append(T + base); base += len(P)
    return np.vstack(Ps), np.vstack(Ts)


def render(P, T, view, out, centre=None, half=1.0, size=1100):
    # view: (right, up, toward-camera) unit vectors
    r, u, f = [np.array(x, float) for x in view]
    c = centre if centre is not None else (P.min(0) + P.max(0)) * 0.5
    X = (P - c) @ r; Y = (P - c) @ u; Z = (P - c) @ f
    s = size / (2 * half)
    sx = size / 2 + X * s; sy = size / 2 - Y * s
    a, b, cc = T[:, 0], T[:, 1], T[:, 2]
    n = np.cross(P[b] - P[a], P[cc] - P[a])
    n /= np.linalg.norm(n, axis=1)[:, None] + 1e-12
    facing = n @ f > 0
    vis = facing & (np.maximum.reduce([np.abs(X[a]), np.abs(X[b]), np.abs(X[cc])]) < half * 1.05) & (np.maximum.reduce([np.abs(Y[a]), np.abs(Y[b]), np.abs(Y[cc])]) < half * 1.05)
    idx = np.where(vis)[0]
    depth = (Z[a] + Z[b] + Z[cc])[idx]
    idx = idx[np.argsort(depth)]
    light = np.array([0.4, 0.6, 0.7]); light /= np.linalg.norm(light)
    img = Image.new('RGB', (size, size), (38, 40, 44))
    dr = ImageDraw.Draw(img)
    for t in idx:
        L = 0.35 + 0.65 * max(0.0, float(n[t] @ (light[0] * r + light[1] * u + light[2] * f)))
        g = int(150 * L + 40)
        pts = [(sx[i], sy[i]) for i in T[t]]
        dr.polygon(pts, fill=(g, g, int(g * 0.97)), outline=(18, 60, 90))
    img.save(out)


if __name__ == '__main__':
    P, T = load(sys.argv[1])
    pre = sys.argv[2]
    top = P[:, 1].max()
    body_c = np.array([0, P[:, 1].min() + (top - P[:, 1].min()) * 0.5, 0])
    F = ((1, 0, 0), (0, 1, 0), (0, 0, -1))      # Godot: the model faces -Z, so the camera looks from -Z
    B = ((-1, 0, 0), (0, 1, 0), (0, 0, 1))
    Sd = ((0, 0, -1), (0, 1, 0), (-1, 0, 0))
    render(P, T, F, pre + '_front.png', body_c, 1.0)
    render(P, T, B, pre + '_back.png', body_c, 1.0)
    render(P, T, Sd, pre + '_side.png', body_c, 1.0)
    # close-ups: shoulder/chest, elbow, knee, hand (left side of the character is -X in Godot)
    render(P, T, F, pre + '_chest.png', np.array([0, 1.35, 0]), 0.3)
    render(P, T, B, pre + '_upperback.png', np.array([0, 1.3, 0]), 0.3)
    render(P, T, Sd, pre + '_knee.png', np.array([-0.1, 0.5, 0]), 0.22)
    render(P, T, F, pre + '_knee_front.png', np.array([-0.1, 0.5, 0]), 0.22)
