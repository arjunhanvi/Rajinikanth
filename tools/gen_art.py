"""Builds logo layers and app icons. Usage: python3 tools/gen_art.py <reference_logo.png>"""
import sys, numpy as np
from PIL import Image, ImageDraw
src = Image.open(sys.argv[1]).convert("RGB")
a = np.asarray(src).astype(np.float32) / 255.0
lum = a.mean(axis=2)
alpha = np.clip((1.0 - lum) / (1.0 - lum.min()) * 1.15, 0, 1)
ys, xs = np.where(alpha > 0.25)
navy = a[alpha > 0.9].mean(axis=0)
print("ink bbox", xs.min(), xs.max(), ys.min(), ys.max(), "navy", navy)
rgba = np.zeros(a.shape[:2] + (4,), np.uint8)
rgba[..., :3] = (navy * 255).astype(np.uint8); rgba[..., 3] = (alpha * 255).astype(np.uint8)
rows = np.where((alpha > 0.25).any(axis=1))[0]
gap = [(rows[i], rows[i + 1]) for i in range(len(rows) - 1) if rows[i + 1] - rows[i] > 8]
split = (gap[0][0] + gap[0][1]) // 2
def crop(y0, y1, name):
    sub = alpha[y0:y1]; yy, xx = np.where(sub > 0.25); p = 12
    box = (max(xx.min() - p, 0), y0 + max(yy.min() - p, 0), xx.max() + p, y0 + yy.max() + p)
    Image.fromarray(rgba).crop(box).save("assets/img/" + name); print(name, box)
crop(0, split, "logo_hanvis.png"); crop(split, alpha.shape[0], "logo_original.png")
def star(size, r, bg=(0, 0, 0, 255)):
    im = Image.new("RGBA", (size * 4, size * 4), bg); d = ImageDraw.Draw(im); c = size * 2; pts = []
    for i in range(10):
        ang = -np.pi / 2 + i * np.pi / 5; rr = r * 4 * (1.0 if i % 2 == 0 else 0.42)
        pts.append((c + rr * np.cos(ang), c + rr * np.sin(ang)))
    d.polygon(pts, fill=(255, 204, 0, 255)); return im.resize((size, size), Image.LANCZOS)
star(512, 170).save("assets/img/icon.png")
star(432, 105, (0, 0, 0, 0)).save("assets/img/icon_fg.png")
Image.new("RGBA", (432, 432), (0, 0, 0, 255)).save("assets/img/icon_bg.png")
star(512, 230, (0, 0, 0, 0)).save("assets/img/star.png")
