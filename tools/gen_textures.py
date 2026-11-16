"""Generates every world texture (facade atlases, shop signs, hoardings, ground).
All original, period-styled (Bangalore, c. 2002). python3 tools/gen_textures.py"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
rng = np.random.default_rng(1999)
OUT = "assets/img/"
FB = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
FX = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
FI = "/usr/share/fonts/opentype/inter/Inter-BoldItalic.otf"
def font(p, s): return ImageFont.truetype(p, s)
def grain(img, amt=10, blur=0):
    a = np.asarray(img).astype(np.int16); n = rng.normal(0, amt, a.shape[:2])
    if blur: n = np.asarray(Image.fromarray((n + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))).astype(np.int16) - 128; n = n * 3
    a[..., :3] += n[..., None].astype(np.int16); return Image.fromarray(a.clip(0, 255).astype(np.uint8), img.mode)
def fit(d, text, box, path, fill, maxs=200, stroke=0, sfill=None):
    x0, y0, x1, y1 = box; s = maxs
    while s > 6:
        f = font(path, s); bb = d.textbbox((0, 0), text, font=f, stroke_width=stroke)
        if bb[2] - bb[0] <= x1 - x0 and bb[3] - bb[1] <= y1 - y0: break
        s -= 2
    d.text(((x0 + x1) / 2, (y0 + y1) / 2), text, font=f, fill=fill, anchor="mm", stroke_width=stroke, stroke_fill=sfill)

# ---------------------------------------------------------------- facade atlas
T = 256
WALL = (232, 230, 224)
def wall_tile(stain=True):
    im = Image.new("RGB", (T, T), WALL); d = ImageDraw.Draw(im)
    if stain:
        for _ in range(5):
            x = int(rng.integers(0, T)); w = int(rng.integers(3, 14)); h = int(rng.integers(40, 200)); c = int(rng.integers(190, 215))
            d.rectangle([x, 0, x + w, h], fill=(c, c, c - 4))
        im = im.filter(ImageFilter.GaussianBlur(5))
        d = ImageDraw.Draw(im)
    d.rectangle([0, T - 10, T, T], fill=(205, 203, 198)); d.line([0, 4, T, 4], fill=(214, 212, 206), width=3)
    return im
def win_shutter(lit):
    im = wall_tile(); d = ImageDraw.Draw(im); x0, y0, x1, y1 = 70, 62, 186, 196
    d.rectangle([x0 - 8, y0 - 8, x1 + 8, y1 + 8], fill=(150, 146, 138)); glass = (255, 214, 120) if lit else (38, 46, 52)
    d.rectangle([x0, y0, x1, y1], fill=glass)
    for x in (x0, 128 + 3):  # wooden shutters half open
        d.rectangle([x, y0, x + 26, y1], fill=(86, 106, 92)); [d.line([x + 2, y, x + 24, y], fill=(64, 82, 70), width=2) for y in range(y0 + 6, y1, 9)]
    d.rectangle([127, y0, 130, y1], fill=(120, 116, 108)); [d.line([x, y0, x, y1], fill=(60, 60, 60), width=1) for x in range(x0 + 30, x1, 9)]
    d.rectangle([x0 - 14, y1 + 8, x1 + 14, y1 + 16], fill=(170, 166, 158)); return im
def win_grill(lit):
    im = wall_tile(); d = ImageDraw.Draw(im); x0, y0, x1, y1 = 58, 76, 198, 192
    d.rectangle([x0 - 20, y0 - 30, x1 + 20, y0 - 16], fill=(176, 172, 164)); d.rectangle([x0 - 20, y0 - 16, x1 + 20, y0 - 8], fill=(120, 118, 112))
    d.rectangle([x0 - 6, y0 - 6, x1 + 6, y1 + 6], fill=(112, 84, 62)); d.rectangle([x0, y0, x1, y1], fill=(250, 220, 140) if lit else (44, 56, 66))
    if lit: d.rectangle([x0, y0, x1, y0 + 50], fill=(190, 120, 90))  # curtain
    for x in range(x0, x1 + 1, 14): d.line([x, y0, x, y1], fill=(30, 30, 30), width=2)
    for y in range(y0, y1 + 1, 29): d.line([x0, y, x1, y], fill=(30, 30, 30), width=2)
    return im
def win_office(lit):
    im = wall_tile(False); d = ImageDraw.Draw(im); d.rectangle([0, 70, T, 190], fill=(96, 100, 104))
    for i in range(3):
        x = 10 + i * 82; d.rectangle([x, 78, x + 72, 182], fill=(235, 240, 220) if (lit and i != 1) else (52, 74, 88))
        if lit and i != 1: d.rectangle([x, 78, x + 72, 96], fill=(250, 250, 240))
    d.rectangle([150, 200, 236, 240], fill=(190, 188, 180)); [d.line([154, y, 232, y], fill=(120, 120, 116), width=2) for y in range(206, 238, 6)]  # AC box
    return im
def win_balcony(lit):
    im = wall_tile(); d = ImageDraw.Draw(im); d.rectangle([86, 50, 170, 214], fill=(104, 78, 58)); d.rectangle([94, 58, 162, 214], fill=(240, 200, 120) if lit else (56, 44, 36))
    d.rectangle([20, 206, 236, 222], fill=(160, 158, 150)); d.rectangle([20, 130, 236, 138], fill=(60, 60, 64))
    for x in range(24, 236, 14): d.line([x, 138, x, 206], fill=(60, 60, 64), width=3)
    for _ in range(3):  # clothes on the line
        x = int(rng.integers(30, 190)); c = tuple(int(v) for v in rng.integers(90, 230, 3)); d.rectangle([x, 138, x + 26, 138 + int(rng.integers(30, 56))], fill=c)
    return im
def shop_open(k):
    im = wall_tile(False); d = ImageDraw.Draw(im); d.rectangle([10, 14, 246, 256], fill=(34, 30, 28))
    d.rectangle([10, 14, 246, 44], fill=(150, 152, 156)); [d.line([10, y, 246, y], fill=(110, 112, 116), width=2) for y in range(18, 44, 6)]  # rolled shutter
    cols = [[(200, 60, 50), (240, 200, 60), (60, 120, 190)], [(230, 230, 220), (180, 140, 90), (90, 150, 90)], [(220, 120, 160), (250, 220, 120), (120, 200, 210)], [(150, 90, 60), (210, 190, 150), (200, 70, 60)]][k]
    d.rectangle([10, 44, 246, 60], fill=(255, 236, 180))  # tubelight glow
    for sh in range(3):
        y = 70 + sh * 44; d.rectangle([24, y + 34, 232, y + 38], fill=(120, 96, 70))
        x = 26
        while x < 224:
            w = int(rng.integers(8, 22)); h = int(rng.integers(14, 34)); d.rectangle([x, y + 34 - h, x + w, y + 34], fill=cols[int(rng.integers(0, 3))]); x += w + 3
    d.rectangle([24, 200, 232, 256], fill=(128, 98, 70)); d.rectangle([24, 200, 232, 208], fill=(170, 136, 100))  # counter
    for i in range(4): d.ellipse([40 + i * 48, 180, 66 + i * 48, 204], fill=(190, 200, 205), outline=(120, 120, 120))  # glass jars
    return im
def shop_shut(k):
    im = wall_tile(False); d = ImageDraw.Draw(im); base = [(142, 146, 150), (70, 110, 150)][k]; d.rectangle([10, 14, 246, 256], fill=base)
    for y in range(18, 256, 8): d.line([10, y, 246, y], fill=tuple(int(c * 0.72) for c in base), width=2)
    d.rectangle([110, 232, 146, 246], fill=(60, 60, 60))
    if k == 0: fit(d, "TO-LET", (60, 100, 196, 150), FB, (200, 40, 40))
    return im
def door_tile():
    im = wall_tile(); d = ImageDraw.Draw(im); d.rectangle([76, 40, 180, 244], fill=(84, 60, 44)); d.rectangle([84, 48, 172, 244], fill=(112, 80, 56))
    d.rectangle([92, 58, 164, 130], outline=(84, 60, 44), width=4); d.rectangle([92, 144, 164, 232], outline=(84, 60, 44), width=4); d.ellipse([154, 136, 164, 146], fill=(210, 180, 80))
    d.rectangle([60, 244, 196, 256], fill=(150, 146, 140))
    for i in range(7): d.ellipse([84 + i * 13, 28, 94 + i * 13, 40], fill=(60, 140, 60))  # mango-leaf thorana
    return im
def pipe_tile():
    im = wall_tile(); d = ImageDraw.Draw(im); d.rectangle([180, 0, 192, 256], fill=(150, 112, 88)); d.rectangle([176, 120, 196, 130], fill=(120, 88, 70)); return im
def vent_tile():
    im = wall_tile(); d = ImageDraw.Draw(im); d.rectangle([92, 90, 164, 150], fill=(70, 70, 70))
    for y in range(96, 150, 9): d.line([92, y, 164, y], fill=(170, 168, 160), width=3)
    return im
def brick_tile():
    im = Image.new("RGB", (T, T), (176, 170, 164)); d = ImageDraw.Draw(im)
    for r in range(16):
        for c in range(-1, 6):
            x = c * 52 + (26 if r % 2 else 0); v = int(rng.integers(-14, 14)); d.rectangle([x + 2, r * 16 + 2, x + 50, r * 16 + 14], fill=(214 + v, 206 + v, 198 + v))
    return im
def shed_tile():
    im = Image.new("RGB", (T, T), (206, 208, 210)); d = ImageDraw.Draw(im)
    for x in range(0, T, 16): d.rectangle([x, 0, x + 7, T], fill=(184, 186, 190))
    d.rectangle([0, 0, T, 30], fill=(160, 150, 140)); return im
def atlas(night, emit=False):
    A = Image.new("RGB", (T * 4, T * 4)); lit = night
    tiles = [win_shutter(lit), win_grill(False), win_office(lit and True), win_balcony(lit),
             *([shop_shut(i % 2) for i in range(4)] if night == 2 else [shop_open(i) for i in range(4)]),
             shop_shut(0), shop_shut(1), door_tile(), wall_tile(), wall_tile(False), pipe_tile(), vent_tile(), brick_tile()]
    for i, tl in enumerate(tiles): A.paste(grain(tl, 5), ((i % 4) * T, (i // 4) * T))
    return A
def emit_from(day_seeded, shops_open):
    a = np.asarray(day_seeded).astype(np.int16); r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (r > 225) & (g > 185) & (b < 200) & (r - b > 50)  # warm lit glass / tubelights
    e = np.zeros_like(a); e[m] = a[m]
    if not shops_open: e[T:T * 2] = 0
    else:
        rowa = a[T:T * 2].copy(); dark = rowa.sum(axis=2) < 110; rowa[dark] = 0; e[T:T * 2] = (rowa * 0.55).astype(np.int16)
    return Image.fromarray(e.clip(0, 255).astype(np.uint8))

# ---------------------------------------------------------------- signs
SIGNS = ["SRI GANESHA STORES", "UDUPI SRI KRISHNA BHAVAN", "S.T.D  I.S.D  P.C.O", "XEROX & LAMINATION", "IYENGAR BAKERY", "KAVERI WINES", "JANATHA MEDICALS", "NEW MODERN TAILORS",
         "HERO CYCLE MART", "LAKSHMI PROVISION STORE", "PADMA JEWELLERS", "MYSORE SAREE CENTRE", "RAJ VIDEO LIBRARY", "NETZONE CYBER CAFE", "A-1 HAIR DRESSERS", "SRI RAMA FLOUR MILL",
         "BYTWO COFFEE & TEA", "MILITARY HOTEL", "SLV DARSHINI", "FANCY & BANGLE STORE", "POWER ELECTRICALS", "VANI TYPING INSTITUTE", "SAPNA LENDING LIBRARY", "BRAHMINS CONDIMENTS",
         "PAN BEEDA COOL DRINKS", "BATA-STYLE FOOTWEAR", "CITY OPTICALS", "ROOPA PHOTO STUDIO", "VIJAYA TUTORIALS", "KAMADHENU TRAVELS", "SRI BALAJI FINANCE & CHITS", "DR. RAO'S CLINIC"]
SIGN_STYLES = [((190, 30, 30), (255, 230, 60)), ((250, 220, 40), (170, 20, 20)), ((20, 60, 140), (255, 255, 255)), ((245, 245, 235), (20, 30, 120)),
               ((20, 110, 60), (255, 240, 120)), ((30, 30, 30), (250, 210, 50)), ((240, 120, 20), (255, 255, 255)), ((250, 250, 250), (200, 30, 30))]
def signs():
    W, H = 512, 128; A = Image.new("RGB", (W * 4, H * 8))
    for i, s in enumerate(SIGNS):
        bg, fg = SIGN_STYLES[(i * 3 + i // 8) % 8]; im = Image.new("RGB", (W, H), bg); d = ImageDraw.Draw(im)
        d.rectangle([4, 4, W - 5, H - 5], outline=fg, width=4); fit(d, s, (26, 20, W - 26, 86), FB, fg, 70)
        sub = ["Bangalore - 560 053", "Prop: K. Shivanna", "Estd. 1974", "All Types Available", "Phone: 287 4411", "Wholesale & Retail", "Quality First", "Since 1961"][i % 8]
        fit(d, sub, (120, 88, W - 120, 116), FI, fg, 22); A.paste(grain(im, 6), ((i % 4) * W, (i // 4) * H))
    A.save(OUT + "signs.png")

# ---------------------------------------------------------------- hoardings
def hoardings():
    W, H = 512, 256; A = Image.new("RGB", (W * 2, H * 4))
    def base(c1, c2):
        im = Image.new("RGB", (W, H), c1); d = ImageDraw.Draw(im)
        for y in range(H): d.line([0, y, W, y], fill=tuple(int(c1[k] + (c2[k] - c1[k]) * y / H) for k in range(3)))
        return im, d
    def sil(d, x, y, s, col):  # anonymous painted figure
        d.ellipse([x - s * 0.5, y - s * 1.6, x + s * 0.5, y - s * 0.5], fill=col); d.polygon([(x - s * 1.2, y + s * 1.5), (x - s * 0.8, y - s * 0.3), (x + s * 0.8, y - s * 0.3), (x + s * 1.2, y + s * 1.5)], fill=col)
    items = []
    im, d = base((250, 200, 40), (240, 120, 20)); sil(d, 110, 150, 60, (60, 30, 20)); fit(d, "VOTE FOR CHANNANNA", (200, 30, 500, 100), FB, (120, 10, 10)); fit(d, "JANATA PRAGATHI PAKSHA", (200, 105, 500, 150), FX, (30, 30, 30)); fit(d, "Symbol: LANTERN  -  Majestic Constituency", (200, 170, 500, 210), FI, (80, 20, 20)); items.append(im)
    im, d = base((20, 110, 80), (10, 60, 60)); sil(d, 400, 150, 60, (235, 225, 200)); fit(d, "VASANTHA KUMARI", (16, 30, 320, 100), FB, (255, 255, 255)); fit(d, "KARNATAKA NAVA NIRMANA VEDIKE", (16, 105, 320, 150), FX, (250, 220, 80)); fit(d, "Symbol: PLOUGH  -  Clean Hands, Clean City", (16, 170, 320, 210), FI, (230, 240, 230)); items.append(im)
    im, d = base((120, 10, 10), (20, 0, 0)); sil(d, 256, 140, 70, (0, 0, 0)); fit(d, "BENKI BASAVA", (20, 150, 492, 236), FB, (255, 210, 40), 200, 4, (90, 0, 0)); fit(d, "100th DAY  -  SANGAM TALKIES", (20, 10, 492, 46), FX, (255, 255, 255)); items.append(im)
    im, d = base((250, 170, 190), (140, 60, 120)); sil(d, 150, 140, 50, (90, 20, 60)); sil(d, 350, 140, 50, (90, 20, 60)); fit(d, "MALLIGE MANASU", (20, 160, 492, 236), FI, (255, 255, 255), 200, 3, (120, 20, 80)); fit(d, "A Musical Love Story  -  Now Showing", (20, 10, 492, 46), FX, (90, 20, 60)); items.append(im)
    im, d = base((90, 50, 20), (40, 20, 5)); d.ellipse([40, 70, 180, 210], fill=(230, 220, 200)); d.ellipse([70, 100, 150, 180], fill=(70, 35, 10)); fit(d, "KAVERI FILTER COFFEE", (200, 50, 496, 130), FB, (250, 220, 150)); fit(d, "The Aroma of Old Bangalore", (200, 140, 496, 190), FI, (255, 255, 255)); items.append(im)
    im, d = base((250, 250, 250), (200, 220, 250)); d.rounded_rectangle([40, 80, 190, 180], 16, fill=(240, 200, 40), outline=(200, 30, 30), width=6); fit(d, "555", (50, 90, 180, 170), FB, (200, 30, 30)); fit(d, "SURYA 555 BAR SOAP", (210, 50, 496, 120), FB, (20, 60, 150)); fit(d, "Whiter than White!", (210, 130, 496, 190), FI, (200, 30, 30)); items.append(im)
    im, d = base((120, 124, 130), (70, 74, 80)); fit(d, "GAJA SHAKTI CEMENT", (20, 40, 492, 130), FB, (250, 220, 40)); fit(d, "Strength of an Elephant in Every Bag", (20, 150, 492, 200), FI, (255, 255, 255)); items.append(im)
    im, d = base((10, 20, 70), (0, 0, 20)); sil(d, 256, 150, 64, (220, 180, 40)); fit(d, "DON DHARMA", (20, 150, 492, 240), FB, (255, 255, 255), 200, 4, (180, 20, 20)); fit(d, "Housefull  -  3rd Week", (20, 10, 492, 46), FX, (250, 220, 40)); items.append(im)
    for i, im in enumerate(items): A.paste(grain(im, 8), ((i % 2) * W, (i // 2) * H))
    A.save(OUT + "hoardings.png")

# ---------------------------------------------------------------- grounds
def noise_tex(name, base, amt, size=256, blur=0, extra=None):
    im = grain(Image.new("RGB", (size, size), base), amt, blur)
    if blur: im = grain(im, amt * 0.6)
    if extra: extra(ImageDraw.Draw(im), size)
    im.save(OUT + name)
def road_lines(d, s):
    for y in range(0, s, 128): d.rectangle([s // 2 - 3, y, s // 2 + 2, y + 70], fill=(215, 215, 205))
    d.rectangle([6, 0, 9, s], fill=(190, 180, 120)); d.rectangle([s - 10, 0, s - 7, s], fill=(190, 180, 120))
def pavers(d, s):
    for i in range(0, s, 32): d.line([i, 0, i, s], fill=(120, 116, 110), width=2); d.line([0, i, s, i], fill=(120, 116, 110), width=2)
def patch(d, s):
    for _ in range(7):
        x, y = (int(v) for v in rng.integers(0, s, 2)); w, h = (int(v) for v in rng.integers(14, 50, 2)); c = int(rng.integers(52, 84)); d.ellipse([x, y, x + w, y + h], fill=(c, c, c))
def body_tex():
    for nm, pat in [("cloth_plain", 0), ("cloth_check", 1), ("cloth_print", 2), ("cloth_stripe", 3)]:
        im = Image.new("RGB", (64, 64), (235, 235, 235)); d = ImageDraw.Draw(im)
        if pat == 1:
            for i in range(0, 64, 16): d.rectangle([i, 0, i + 5, 64], fill=(170, 170, 170)); d.rectangle([0, i, 64, i + 5], fill=(170, 170, 170))
        if pat == 2:
            for _ in range(22): x, y = (int(v) for v in rng.integers(0, 60, 2)); d.ellipse([x, y, x + 7, y + 7], fill=(150, 150, 150))
        if pat == 3:
            for i in range(0, 64, 8): d.rectangle([i, 0, i + 2, 64], fill=(165, 165, 165))
        im.save(OUT + nm + ".png")

if __name__ == "__main__":
    st = rng.bit_generator.state
    day = atlas(0); day.save(OUT + "atlas_day.png")
    rng.bit_generator.state = st; lit = atlas(1); lit.save(OUT + "atlas_eve.png"); emit_from(lit, True).save(OUT + "atlas_eve_emit.png")
    rng.bit_generator.state = st; late = atlas(2); late.save(OUT + "atlas_night.png"); emit_from(late, False).save(OUT + "atlas_night_emit.png")
    shed_tile().save(OUT + "shed.png")
    signs(); hoardings(); body_tex()
    noise_tex("road.png", (66, 66, 68), 7, 256, 0, road_lines); noise_tex("street.png", (78, 76, 74), 9, 256, 0, patch)
    noise_tex("footpath.png", (150, 146, 138), 7, 256, 0, pavers); noise_tex("ground.png", (140, 124, 100), 8, 256, 6)
    noise_tex("grass.png", (74, 108, 58), 10, 256, 5); noise_tex("concrete.png", (156, 154, 150), 6, 256, 8); noise_tex("water.png", (40, 70, 78), 5, 128, 6)
    print("textures ok")
