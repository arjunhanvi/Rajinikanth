"""Bakes skin, hair and fabric textures. Skin detail is computed in the body's UV
space from 3D position maps, so pores, creases, brows and stubble sit exactly
where the anatomy is; every albedo has a matching normal map for real relief."""
import numpy as np, os
from PIL import Image, ImageFilter

TONES = [(0.86, 0.66, 0.5), (0.78, 0.57, 0.41), (0.68, 0.47, 0.32), (0.56, 0.38, 0.25), (0.44, 0.29, 0.19), (0.33, 0.21, 0.14)]

def raster(c, R=1024):
    """position map of the body in UV space: (R,R,3) and coverage mask"""
    b = c.b; pos = np.zeros((R, R, 3), np.float32); hit = np.zeros((R, R), bool)
    body = c.tri_face[np.isin(c.tri_face, np.where(b.face_group == 'body')[0])]
    sel = np.isin(c.tri_face, np.where(b.face_group == 'body')[0])
    TV, TU = c.tris_all[sel], c.tri_uv[sel]
    uv = np.stack([b.vt[:, 0], 1 - b.vt[:, 1]], 1) * (R - 1)
    for tv, tu in zip(TV, TU):
        p = uv[tu]; q = c.v[tv]
        x0, y0 = np.floor(p.min(0)).astype(int); x1, y1 = np.ceil(p.max(0)).astype(int)
        if x1 - x0 > 300 or y1 - y0 > 300: continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-9: continue
        w0 = ((p[1, 1] - p[2, 1]) * (xs - p[2, 0]) + (p[2, 0] - p[1, 0]) * (ys - p[2, 1])) / d
        w1 = ((p[2, 1] - p[0, 1]) * (xs - p[2, 0]) + (p[0, 0] - p[2, 0]) * (ys - p[2, 1])) / d
        w2 = 1 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        yy, xx = ys[m], xs[m]
        ok = (yy >= 0) & (yy < R) & (xx >= 0) & (xx < R)
        yy, xx = yy[ok], xx[ok]
        pos[yy, xx] = (w0[m][ok, None] * q[0] + w1[m][ok, None] * q[1] + w2[m][ok, None] * q[2])
        hit[yy, xx] = True
    return pos, hit

def noise(R, scale, seed, octaves=3):
    rng = np.random.default_rng(seed); out = np.zeros((R, R)); amp = 1.0; tot = 0
    for o in range(octaves):
        n = max(2, int(R / (scale / (2 ** o))))
        g = rng.random((n, n))
        out += np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((R, R), Image.BICUBIC)) / 255.0 * amp
        tot += amp; amp *= 0.5
    return out / tot

def normal_from_height(h, strength):
    gx = np.roll(h, -1, 1) - np.roll(h, 1, 1); gy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    n = np.stack([-gx * strength, -gy * strength, np.ones_like(h)], 2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)

def skin(c, out, name, tone, age=0.3, female=False, brow=(0.04, 0.03, 0.03), stubble=0.0, seed=1, R=1024, grey=0.0):
    b = c.b; lm = c.landmarks(); pos, hit = raster(c, R)
    X, Y, Z = pos[..., 0], pos[..., 1], pos[..., 2]
    def mask(n): return np.asarray(Image.open(b.data + '/textures/mpfb_%s.jpg' % n).convert('L').resize((R, R), Image.BILINEAR)) / 255.0
    lips, nails, lids, ears = mask('lips'), mask('fingernails'), mask('eyelids'), mask('ears')
    face = mask('face')
    base = np.array(TONES[tone])
    rng = np.random.default_rng(seed)
    mott = noise(R, 90, seed, 3) - 0.5; fine = noise(R, 6, seed + 1, 2) - 0.5
    col = np.ones((R, R, 3)) * base
    col *= (1 + mott[..., None] * 0.16 + fine[..., None] * 0.05)
    ey, ez = lm['eye_l'][1], lm['eye_l'][2]; exl = abs(lm['eye_l'][0])
    headm = (Y > lm['chin'] - 0.6) & hit
    # blood near the surface: cheeks, nose, ears, knuckles
    cheek = np.exp(-(((np.abs(X) - exl * 1.25) / 0.45) ** 2 + ((Y - (ey - 0.62)) / 0.4) ** 2)) * headm
    nose = np.exp(-((X / 0.25) ** 2 + ((Y - lm['nose_tip'][1]) / 0.3) ** 2)) * headm * (Z > lm['nose_tip'][2] - 0.5)
    red = np.clip(cheek * 0.5 + nose * 0.45 + ears * 0.5, 0, 1)
    col[..., 0] *= 1 + red * 0.1; col[..., 1] *= 1 - red * 0.07; col[..., 2] *= 1 - red * 0.06
    # darker, thinner skin around the eyes; lighter palms and soles
    orbit = np.exp(-(((np.abs(X) - exl) / 0.34) ** 2 + ((Y - ey) / 0.24) ** 2)) * headm
    col *= (1 - orbit[..., None] * (0.16 + age * 0.12))
    col *= (1 - lids[..., None] * 0.1)
    low = hit & (Y < c.ground + 0.25)
    col[low] = col[low] * 0.5 + np.array(TONES[max(0, tone - 2)]) * 0.5
    # lips, nails
    lipc = base * np.array([0.86, 0.66, 0.64]) + np.array([0.04, 0.0, 0.0]) + (0.06 if female else 0.0) * np.array([1, 0, 0.2])
    col = col * (1 - lips[..., None] * 0.85) + lipc * lips[..., None] * 0.85
    nailc = base * 0.6 + np.array([0.36, 0.3, 0.28])
    col = col * (1 - nails[..., None] * 0.8) + nailc * nails[..., None] * 0.8
    # eyebrows: an arch of strands over each eye
    strands = np.asarray(Image.fromarray((rng.random((R, R // 6)) * 255).astype(np.uint8)).resize((R, R), Image.BILINEAR)) / 255.0
    dx = (np.abs(X) - exl) / 0.4
    arch = ey + 0.2 + 0.05 * (1 - dx ** 2) + np.clip(dx, 0, 1) * -0.06
    browm = np.clip(1 - np.abs(Y - arch) / ((0.032 if female else 0.05) * (1.2 - 0.6 * np.clip(dx, 0, 1))), 0, 1) * (dx > -0.52) * (dx < 0.85) * headm * (Z > ez - 0.3)
    browm = np.clip(browm * (0.75 + strands * 0.7), 0, 1) ** 0.8
    bc = np.array(brow) * (1 - grey) + np.array([0.6, 0.6, 0.6]) * grey
    col = col * (1 - browm[..., None] * 0.92) + bc * browm[..., None] * 0.92
    # stubble: the shadow of a beard on the jaw and upper lip
    if stubble > 0:
        dots = (noise(R, 2.5, seed + 5, 1) > 0.55).astype(float)
        area = headm * (Y < lm['lip_top'] + 0.22) * (Y > lm['chin'] - 0.25) * (Z > lm['mouth_z'] - 1.3) * (1 - lips)
        area = np.asarray(Image.fromarray((np.clip(area, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(R / 200))) / 255.0
        col *= (1 - area[..., None] * stubble * (0.16 + 0.1 * dots[..., None]))
    # moles and blemishes
    for _ in range(int(14 + age * 30)):
        y, x = rng.integers(0, R, 2)
        if hit[y, x]:
            r = rng.integers(1, 3); col[max(0, y - r):y + r + 1, max(0, x - r):x + r + 1] *= rng.uniform(0.55, 0.85)
    # ---- relief: pores everywhere, creases where a face folds, knuckles
    pore = noise(R, 1.3, seed + 9, 1)
    cell = noise(R, 2.6, seed + 10, 2)
    height = pore * 0.22 + cell * 0.12
    fore = headm * (Y > ey + 0.45) * (Y < ey + 1.25) * (np.abs(X) < 0.85) * (Z > ez - 0.5)
    height -= fore * (0.5 + 0.5 * np.sin(Y * 46 + 1.5 * np.sin(X * 5))) ** 6 * age * 0.9
    crow = np.exp(-(((np.abs(X) - exl - 0.38) / 0.2) ** 2 + ((Y - ey) / 0.2) ** 2)) * headm
    height -= crow * (0.5 + 0.5 * np.sin((Y - ey) * 60 + np.abs(X) * 30)) ** 4 * age * 0.9
    naso = np.exp(-(((np.abs(X) - (lm['mouth_w'] * 1.15 + (Y - lm['lip_top']) * -0.35)) / 0.06) ** 2)) * headm * (Y < lm['nose_base'] + 0.1) * (Y > lm['lip_bot'] - 0.2) * (Z > lm['mouth_z'] - 0.7)
    height -= naso * (0.3 + age) * 0.5
    col *= (1 - (naso * (0.1 + age * 0.2) + fore * 0 )[..., None])
    height -= orbit * (0.5 + 0.5 * np.sin((Y - ey) * 40)) ** 3 * age * 0.8
    height += lips * (0.5 + 0.5 * np.sin(X * 55)) * 0.25
    height += browm * strands * 0.6
    # fill outside the islands so mipmaps do not bleed dark
    img = np.clip(col, 0, 1)
    fill = ~hit
    img[fill] = base * 0.9
    os.makedirs(out, exist_ok=True)
    Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.5)).save(os.path.join(out, name + '_skin.jpg'), quality=92)
    Image.fromarray(normal_from_height(np.asarray(Image.fromarray((height * 60 + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))) / 255.0, 3.2)).save(os.path.join(out, name + '_skin_n.jpg'), quality=93)

def eye(src, dst):
    im = np.asarray(Image.open(src).convert('RGBA')).astype(float) / 255
    rgb = im[..., :3]; sat = rgb.max(2) - rgb.min(2)
    iris = np.clip((sat - 0.12) / 0.25, 0, 1)[..., None]
    dark = rgb * np.array([0.2, 0.14, 0.1])            # deep brown
    im[..., :3] = rgb * (1 - iris) + dark * iris
    Image.fromarray((im * 255).astype(np.uint8), 'RGBA').save(dst)

def shared(out):
    os.makedirs(out, exist_ok=True)
    R = 512; rng = np.random.default_rng(5)
    # hair: long streaks with gaps, alpha carries the strand density
    st = np.asarray(Image.fromarray((rng.random((8, R)) * 255).astype(np.uint8)).resize((R, R), Image.BICUBIC)) / 255.0
    st2 = np.asarray(Image.fromarray((rng.random((3, R // 3)) * 255).astype(np.uint8)).resize((R, R), Image.BICUBIC)) / 255.0
    a = np.clip(0.5 + st * 0.75 + st2 * 0.1, 0, 1)
    lum = 0.55 + st * 0.6
    Image.fromarray(np.dstack([(np.clip(lum, 0, 1) * 255).astype(np.uint8)] * 3 + [(a * 255).astype(np.uint8)]), 'RGBA').save(os.path.join(out, 'hair.png'))
    Image.fromarray(normal_from_height(st, 6.0)).save(os.path.join(out, 'hair_n.png'))
    # fabric: a woven surface with soft creases, tileable
    y, x = np.mgrid[0:R, 0:R]
    weave = 0.5 + 0.25 * np.sin(x * 2 * np.pi / 4) * np.sin(y * 2 * np.pi / 4) + 0.2 * (rng.random((R, R)) - 0.5)
    crease = np.zeros((R, R))
    for k in range(9):
        ang = rng.uniform(-0.5, 0.5); ph = rng.uniform(0, 6.28); f = rng.integers(1, 4)
        crease += np.sin((y * np.cos(ang) + x * np.sin(ang)) * 2 * np.pi * f / R + ph + 1.5 * np.sin(x * 2 * np.pi / R * rng.integers(1, 3))) / f
    hgt = weave * 0.12 + crease * 0.1
    Image.fromarray(normal_from_height(hgt, 5.0)).save(os.path.join(out, 'cloth_n.png'))
    lum = 0.9 + (weave - 0.5) * 0.14 + crease * 0.012
    Image.fromarray((np.clip(np.dstack([lum] * 3), 0, 1) * 255).astype(np.uint8)).save(os.path.join(out, 'cloth.png'))
    for nm, fn in [('check', lambda: 0.92 - 0.2 * ((x // 20) % 2) - 0.2 * ((y // 20) % 2)), ('stripe', lambda: 0.95 - 0.28 * ((x // 9) % 3 == 0)), ('print', lambda: 0.95 - 0.35 * ((np.sin(x * 0.2) * np.sin(y * 0.2)) > 0.55))]:
        l2 = fn() + (weave - 0.5) * 0.1
        Image.fromarray((np.clip(np.dstack([l2] * 3), 0, 1) * 255).astype(np.uint8)).save(os.path.join(out, 'cloth_%s.png' % nm))
