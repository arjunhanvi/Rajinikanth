"""Builds every rigged human in the game from the CC0 MakeHuman base mesh.
Usage: python3 tools/humans/gen_humans.py <mpfb data dir> <makehuman core data dir> [name ...]
See docs/HUMANS.md for where the source data comes from."""
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import mh, build, gltf, tex

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'humans')
SOUTH = {'asian': 0.42, 'caucasian': 0.38, 'african': 0.2}
INDIAN = {'asian': 0.18, 'caucasian': 0.55, 'african': 0.27}
KHAKI = [0.5, 0.43, 0.26, 1]; WHITE = [0.93, 0.93, 0.9, 1]

def face(seed, n=9, amp=0.55):
    """an individual face: a seeded handful of feature targets"""
    pool = ['nose/nose-scale-horiz-incr', 'nose/nose-scale-horiz-decr', 'nose/nose-hump-incr', 'nose/nose-flaring-incr', 'nose/nose-scale-vert-incr', 'nose/nose-base-down', 'nose/nose-curve-convex',
            'chin/chin-prominent-incr', 'chin/chin-height-incr', 'chin/chin-height-decr', 'chin/chin-bones-incr', 'chin/chin-jaw-drop-incr', 'head/head-oval', 'head/head-rectangular', 'head/head-diamond',
            'head/head-fat-incr', 'head/head-invertedtriangular', 'cheek/l-cheek-bones-incr', 'cheek/r-cheek-bones-incr', 'cheek/l-cheek-volume-incr', 'cheek/r-cheek-volume-incr',
            'forehead/forehead-nubian-incr', 'forehead/forehead-scale-vert-incr', 'forehead/forehead-temple-decr', 'mouth/mouth-angles-up', 'mouth/mouth-cupidsbow-incr', 'mouth/mouth-lowerlip-ext-down',
            'eyes/l-eye-bag-incr', 'eyes/r-eye-bag-incr', 'ears/l-ear-scale-incr', 'ears/r-ear-scale-incr', 'asym/asym-cheek-1-l', 'asym/asym-brown-1-r', 'asym/asym-ear-1-l']
    r = np.random.default_rng(seed)
    return {pool[i]: float(r.uniform(0.2, 1.0) * amp) for i in r.choice(len(pool), n, replace=False)}

# morphs built from MakeHuman facial pose units. The first 13 keep the names the game already drives;
# the rest add left/right control, cheeks, lip shapes for speech and strain.
FACS = {
    "blink_l": {"LeftUpperLidClosed": 1.0, "LeftLowerLidUp": 0.15}, "blink_r": {"RightUpperLidClosed": 1.0, "RightLowerLidUp": 0.15},
    "brow_up": {"LeftOuterBrowUp": 0.9, "RightOuterBrowUp": 0.9, "LeftInnerBrowUp": 0.6, "RightInnerBrowUp": 0.6, "LeftUpperLidOpen": 0.25, "RightUpperLidOpen": 0.25},
    "brow_down": {"LeftBrowDown": 1.0, "RightBrowDown": 1.0, "NoseWrinkler": 0.25},
    "brow_sad": {"LeftInnerBrowUp": 1.0, "RightInnerBrowUp": 1.0},
    "smile": {"MouthLeftPullUp": 0.9, "MouthRightPullUp": 0.9, "LeftCheekUp": 0.6, "RightCheekUp": 0.6, "LeftLowerLidUp": 0.25, "RightLowerLidUp": 0.25, "NasolabialDeepener": 0.4},
    "frown": {"MouthLeftPullDown": 1.0, "MouthRightPullDown": 1.0, "MouthLeftPlatysma": 0.15, "MouthRightPlatysma": 0.15},
    "jaw_open": {"JawDrop": 1.0},
    "lips_part": {"lowerLipDown": 0.6, "UpperLipUp": 0.35},
    "pucker": {"LipsKiss": 1.0},
    "wide": {"MouthLeftPullSide": 1.0, "MouthRightPullSide": 1.0},
    "squint": {"LeftLowerLidUp": 1.0, "RightLowerLidUp": 1.0, "LeftCheekUp": 0.3, "RightCheekUp": 0.3},
    "sneer": {"NoseWrinkler": 1.0, "UpperLipUp": 0.5},
    # left/right and extra shapes
    "smile_l": {"MouthLeftPullUp": 1.0, "LeftCheekUp": 0.5}, "smile_r": {"MouthRightPullUp": 1.0, "RightCheekUp": 0.5},
    "brow_up_l": {"LeftOuterBrowUp": 1.0, "LeftInnerBrowUp": 0.5}, "brow_up_r": {"RightOuterBrowUp": 1.0, "RightInnerBrowUp": 0.5},
    "brow_down_l": {"LeftBrowDown": 1.0}, "brow_down_r": {"RightBrowDown": 1.0},
    "lids_wide": {"LeftUpperLidOpen": 1.0, "RightUpperLidOpen": 1.0},
    "lower_lip_up": {"lowerLipUp": 1.0}, "upper_lip_up": {"UpperLipUp": 1.0},
    "lip_corner_down_l": {"MouthLeftPullDown": 1.0}, "platysma": {"MouthLeftPlatysma": 1.0, "MouthRightPlatysma": 1.0},
    "jaw_stretch": {"JawDropStretched": 1.0}, "cheeks_puff": {"CheeksPump": 1.0}, "chin_raise": {"lowerLipUp": 0.6, "ChinForward": 0.3},
}

def P(gender, age, weight, muscle, height, extra=None, race=None):
    return {'gender': gender, 'age': age, 'weight': weight, 'muscle': muscle, 'height': height, 'race': race or SOUTH, 'extra': extra or {}}

HEROES = {
    # Rajinikanth: lean, swept-back thick hair, full moustache; khaki shirt worn open over a white shirt
    'raji': dict(p=P(1, 0.56, 0.42, 0.52, 0.53, {**face(11, 6, 0.4), 'mouth/mouth-angles-up': 0.5, 'cheek/l-cheek-bones-incr': 0.5, 'cheek/r-cheek-bones-incr': 0.5, 'chin/chin-prominent-incr': 0.3, 'nose/nose-scale-horiz-incr': 0.35}),
                 hair=[('bouffant', (0.035, 0.03, 0.03))], face_hair=[('moustache', 0.11)], tone=2, age_lines=0.35,
                 outfit='conductor'),
    'kamakshi': dict(p=P(0, 0.54, 0.4, 0.4, 0.5, {**face(23, 6, 0.4), 'cheek/l-cheek-bones-incr': 0.4, 'cheek/r-cheek-bones-incr': 0.4, 'chin/chin-height-decr': 0.2}),
                     hair=[('bun', (0.03, 0.025, 0.03))], face_hair=[], tone=1, age_lines=0.15, outfit='saree'),
    'uma': dict(p=P(1, 0.6, 1.0, 0.35, 0.42, {**face(37, 6, 0.4), 'stomach/stomach-pregnant-incr': 0.55, 'neck/neck-double-incr': 0.9, 'head/head-fat-incr': 0.9, 'cheek/l-cheek-volume-incr': 0.8, 'cheek/r-cheek-volume-incr': 0.8, 'head/head-round': 0.6}),
                hair=[('curly', (0.04, 0.035, 0.035))], face_hair=[('moustache', 0.12)], tone=3, age_lines=0.3, outfit='driver'),
    'devaraj': dict(p=P(1, 0.82, 0.68, 0.45, 0.52, {**face(51, 6, 0.4), 'head/head-rectangular': 0.6, 'chin/chin-bones-incr': 0.5, 'eyes/l-eye-bag-incr': 0.7, 'eyes/r-eye-bag-incr': 0.7, 'nose/nose-hump-incr': 0.4}),
                    hair=[('side', (0.5, 0.5, 0.52))], face_hair=[('moustache', 0.09)], tone=2, age_lines=0.85, outfit='safari'),
    # ---- BIG BANG LORE (2007) ----
    # Raja (visual reference: Shankar Nag): a long, lean oval face, high cheekbones, a strong straight nose,
    # intense deep-set eyes under heavy brows, a thick moustache, dense black hair swept to the side;
    # a khaki-beige half-sleeve shirt open at the collar, tucked into dark trousers
    'raja': dict(p=P(1, 0.46, 0.34, 0.58, 0.55, race=INDIAN, extra={'head/head-oval': 0.7, 'chin/chin-height-incr': 0.35, 'chin/chin-prominent-incr': 0.35,
                 'cheek/l-cheek-bones-incr': 0.65, 'cheek/r-cheek-bones-incr': 0.65, 'cheek/l-cheek-volume-decr': 0.45, 'cheek/r-cheek-volume-decr': 0.45,
                 'nose/nose-scale-vert-incr': 0.45, 'nose/nose-hump-incr': 0.25, 'nose/nose-scale-horiz-decr': 0.15,
                 'forehead/forehead-nubian-incr': 0.35, 'eyebrows/eyebrows-angle-down': 0.3, 'mouth/mouth-scale-horiz-decr': 0.1,
                 'expression/units/asian/mouth-compression': 0.3,          # the lips meet at rest (no gap showing the teeth)
                 # a real face is not symmetrical: small, deliberate left/right differences
                 'asym/asym-brown-1-l': 0.3, 'asym/asym-eye-2-r': 0.25, 'asym/asym-cheek-1-l': 0.2, 'asym/asym-nose-2-r': 0.25,
                 'asym/asym-mouth-1-l': 0.2, 'asym/asym-jaw-1-r': 0.2, 'asym/asym-ear-2-l': 0.3, 'asym/asym-temple-1-r': 0.2}),
                 hair=[('thick_side', (0.055, 0.045, 0.04))], face_hair=[('moustache', 0.13)], tone=4, age_lines=0.12, brow=0.9, cards=True,
                 outfit=dict(top=('shirt', 'half', True, [0.6, 0.5, 0.36, 1], 0.4, 5), bottom=[0.09, 0.09, 0.11, 1], feet='shoe', watch=(0.12, 0.1, 0.08), belt=True, tailored=True)),
    # Lal (visual reference: Ambareesh): big and broad, a round full face with a wide jaw and full cheeks,
    # a broad nose, a big crown of wavy hair, a thick moustache; a dark full-sleeve sweatshirt over jeans
    'lal': dict(p=P(1, 0.52, 0.74, 0.62, 0.55, race=INDIAN, extra={'head/head-round': 0.6, 'head/head-fat-incr': 0.55, 'chin/chin-width-incr': 0.45,
                'cheek/l-cheek-volume-incr': 0.7, 'cheek/r-cheek-volume-incr': 0.7, 'nose/nose-scale-horiz-incr': 0.55, 'nose/nose-flaring-incr': 0.35,
                'neck/neck-scale-horiz-incr': 0.5, 'neck/neck-double-incr': 0.2, 'mouth/mouth-scale-horiz-incr': 0.2, 'eyes/l-eye-height2-incr': 0.25, 'eyes/r-eye-height2-incr': 0.25}),
                hair=[('puff', (0.035, 0.03, 0.028))], face_hair=[('moustache', 0.12)], tone=2, age_lines=0.15, brow=0.75,
                outfit=dict(top=('sweat', 'full', False, [0.2, 0.2, 0.22, 1], 0.45, 0), bottom=[0.2, 0.25, 0.38, 1], feet='shoe', watch=(0.85, 0.68, 0.2), collar=False)),
    # the superstar on set, as in the Sivaji reference: bald, grey goatee and moustache, shades,
    # a black turtleneck, a long black coat, black trousers (only ever seen from behind)
    'rajini': dict(p=P(1, 0.66, 0.38, 0.5, 0.56, {**face(91, 6, 0.4), 'cheek/l-cheek-bones-incr': 0.5, 'cheek/r-cheek-bones-incr': 0.5}),
                   hair=[], face_hair=[('moustache', 0.08), ('goatee', 0.06)], hair_col=(0.3, 0.29, 0.28), tone=3, age_lines=0.5,
                   outfit=dict(top=('shirt_full', 'full', True, [0.05, 0.05, 0.06, 1], 0.15, 0), bottom=[0.05, 0.05, 0.06, 1], feet='shoe', watch=None, coat=[0.04, 0.04, 0.045, 1], collar=False, belt=True)),
    'shankar': dict(p=P(1, 0.66, 0.5, 0.42, 0.5, {**face(97, 6, 0.4), 'head/head-oval': 0.4}),
                    hair=[('side', (0.06, 0.055, 0.055))], face_hair=[], tone=2, age_lines=0.4,
                    outfit=dict(top=('shirt_full', 'full', True, [0.62, 0.72, 0.86, 1], 0.2, 6), bottom=[0.22, 0.22, 0.25, 1], feet='shoe', watch=(0.7, 0.7, 0.72))),
    'kvanand': dict(p=P(1, 0.64, 0.58, 0.45, 0.52, {**face(113, 6, 0.4)}),
                    hair=[('short', (0.2, 0.2, 0.2))], face_hair=[('moustache', 0.07), ('beard', 0.05)], tone=3, age_lines=0.45,
                    outfit=dict(top=('shirt_out', 'half', False, [0.28, 0.3, 0.33, 1], 0.3, 5), bottom=[0.2, 0.24, 0.36, 1], feet='shoe', watch=(0.1, 0.1, 0.1))),
    'ad': dict(p=P(1, 0.44, 0.42, 0.45, 0.52, {**face(127, 7, 0.45)}),
               hair=[('short', (0.03, 0.025, 0.025))], face_hair=[('moustache', 0.06)], tone=2, age_lines=0.1,
               outfit=dict(top=('shirt_out', 'half', False, [0.86, 0.78, 0.5, 1], 0.3, 6), bottom=[0.18, 0.24, 0.4, 1], feet='shoe', watch=(0.7, 0.7, 0.72))),
    'umashankar': dict(p=P(1, 0.46, 0.62, 0.4, 0.44, {**face(139, 7, 0.45), 'cheek/l-cheek-volume-incr': 0.5, 'cheek/r-cheek-volume-incr': 0.5, 'head/head-round': 0.4}),
                       hair=[('short', (0.03, 0.025, 0.025))], face_hair=[('moustache', 0.08)], tone=3, age_lines=0.1,
                       outfit=dict(top=('shirt_out', 'half', False, [0.2, 0.42, 0.3, 1], 0.4, 6), bottom=[0.4, 0.3, 0.22, 1], feet='chappal', watch=None)),
}
CROWD = {
    'm_lean': P(1, 0.5, 0.3, 0.45, 0.5, face(101)), 'm_avg': P(1, 0.55, 0.5, 0.5, 0.5, face(102)), 'm_heavy': P(1, 0.62, 0.9, 0.4, 0.45, {**face(103), 'stomach/stomach-pregnant-incr': 0.35}),
    'm_old': P(1, 0.95, 0.4, 0.3, 0.42, face(104)), 'm_tall': P(1, 0.45, 0.45, 0.65, 0.62, face(105)), 'm_youth': P(1, 0.38, 0.35, 0.4, 0.5, face(106)),
    'f_slim': P(0, 0.48, 0.35, 0.4, 0.5, face(201)), 'f_avg': P(0, 0.58, 0.55, 0.4, 0.45, face(202)), 'f_heavy': P(0, 0.65, 0.85, 0.35, 0.4, face(203)), 'f_old': P(0, 0.96, 0.45, 0.3, 0.38, face(204)),
    'child_m': P(1, 0.26, 0.4, 0.4, 0.5, face(301)), 'child_f': P(0, 0.26, 0.4, 0.4, 0.5, face(302)),
}

def dress(c, outfit, female, hero):
    """every garment this body can wear; the game shows the ones the look asks for"""
    if hero and isinstance(outfit, dict):
        name, sl, tucked, col, loose, btn = outfit['top']
        tail = bool(outfit.get('tailored', False))
        s = c.top(name, sl, tucked=tucked, loose=loose, colour=col, collar=outfit.get('collar', True), tailored=tail)
        if tail:
            c.hem_bands(s)
            c.collar_band(s, col)
        if btn: c.details(s, btn, True, colour=(0.85, 0.85, 0.82))
        if outfit.get('coat'):
            c.top('coat', 'full', tucked=False, open_front=True, offset=0.26, loose=0.6, hem=c.h['calf_l'][1] + 0.6, colour=outfit['coat'])
        c.trousers(loose=0.25, colour=outfit['bottom']); c.footwear(outfit['feet'])
        if outfit.get('watch'): c.watch(outfit['watch'])
    elif hero and outfit == 'conductor':
        s = c.top('shirt', 'half', tucked=True, colour=WHITE); c.details(s, 5, False)
        o = c.top('over', 'half', tucked=False, open_front=True, offset=0.2, loose=0.5, colour=KHAKI); c.details(o, 0, True, colour=KHAKI[:3])
        c.trousers(colour=KHAKI); c.footwear('sandal'); c.watch((0.1, 0.1, 0.1))
    elif hero and outfit == 'driver':
        s = c.top('shirt', 'half', tucked=False, loose=0.35, colour=KHAKI); c.details(s, 6, True)
        c.trousers(loose=0.5, colour=KHAKI); c.footwear('chappal'); c.watch((0.3, 0.2, 0.1))
    elif hero and outfit == 'safari':
        s = c.top('shirt', 'half', tucked=False, loose=0.25, colour=[0.9, 0.89, 0.84, 1]); c.details(s, 5, True)
        c.trousers(loose=0.3, colour=[0.9, 0.89, 0.84, 1]); c.footwear('shoe'); c.watch((0.85, 0.68, 0.2)); c.glasses()
    elif hero and outfit == 'saree':
        c.top('blouse', 'cap', tucked=True, hem=c.h['spine_02'][1] + 0.15, collar=False, offset=0.07, colour=WHITE)
        c.skirt('saree', pleat=0.09, amp=0.07, colour=[0.12, 0.16, 0.36, 1], border=[0.72, 0.56, 0.16, 1])
        c.drape('pallu', [0.12, 0.16, 0.36, 1])
        o = c.top('coat', 'full', tucked=False, open_front=True, offset=0.24, loose=0.4, colour=[0.05, 0.05, 0.06, 1])
        c.footwear('sandal'); c.watch((0.75, 0.76, 0.8))
    else:
        s = c.top('shirt', 'half', tucked=True); c.details(s, 5, True)
        s2 = c.top('shirt_out', 'half', tucked=False, loose=0.3); c.details(s2, 5, True)
        c.top('shirt_full', 'full', tucked=True)
        c.top('banian', 'none', tucked=False, collar=False, offset=0.06)
        c.trousers(); c.footwear('chappal'); c.footwear('shoe'); c.watch((0.7, 0.7, 0.72))
        c.skirt('lungi', amp=0.06, folds=10)
        # the white coat medical students wear, open over their clothes
        c.top('labcoat', 'full', tucked=False, open_front=True, offset=0.24, loose=0.55, hem=c.h['thigh_l'][1] - 1.6, colour=[0.95, 0.95, 0.93, 1])
        if female:
            c.top('blouse', 'cap', tucked=True, hem=c.h['spine_02'][1] + 0.15, collar=False, offset=0.07)
            c.skirt('saree', pleat=0.09, amp=0.07); c.drape('pallu', [1, 1, 1, 1])
            c.top('kameez', 'half', tucked=False, loose=0.3, collar=False); c.skirt('kameez_skirt', hem_y=c.h['calf_l'][1] - 0.2, amp=0.05, folds=9, top_y=c.h['thigh_l'][1] + 0.4)
        else:
            c.top('kurta', 'full', tucked=False, loose=0.4, collar=False); c.skirt('kurta_skirt', hem_y=c.h['calf_l'][1] + 0.9, amp=0.04, folds=8, top_y=c.h['thigh_l'][1] + 0.3)

def make(base, core, name, spec, hero):
    p = spec['p'] if hero else spec
    v = mh.sculpt(base, p)
    c = build.Char(base, v)
    female = p['gender'] < 0.5
    c.body(hero)
    c.eyes(core, True)
    dress(c, spec.get('outfit') if hero else None, female, hero)
    if hero:
        fh_col = spec.get('hair_col') or (spec['hair'][0][1] if spec['hair'] else (0.05, 0.04, 0.04))
        if spec.get('cards'):
            # card hair: a scalp tint under ~1600 strand cards up close, fewer and wider cards at middle
            # distance, the old shell only far away; card eyebrows, moustache and sideburns
            for st, col in spec['hair']:
                c.hair('hair_' + st, st, 1, col, cap_only=True)
                c.hair_cards('hair_' + st + '_cards', st, col, 3000, levels=(0,), seed=7, card_w=0.11, segs=6)
                c.hair_cards('hair_' + st + '_cards1', st, col, 600, levels=(1,), seed=9, card_w=0.26)
                far = c.hair('hair_' + st + '_far', st, 3, col)
                far.levels = {2}
                for fp in c.parts:          # its scalp cap is for the distant level only (it has a hard edge)
                    if fp.name == 'hair_' + st + '_far_cap':
                        fp.levels = {2}
            # groomed fibres (about 1 mm wide, 1-3 strands each) for the brows, moustache, sideburns and a
            # soft hairline; the earlier 3.5 mm hard-cut cards broke up into specks, these are alpha-blended
            c.fibers('brows_fib', 'brows', fh_col, 1300, seed=21)
            c.fibers('hairline_fib', 'hairline', fh_col, 2200, seed=22)
            c.fibers('sideburns_fib', 'sideburns', fh_col, 500, seed=23)
            c.fibers('lashes_fib', 'lashes', (0.02, 0.016, 0.014), 360, seed=25)
            for reg, ln in spec['face_hair']:
                if reg == 'moustache':
                    c.fibers('moustache_fib', 'moustache', fh_col, 2600, seed=24)
                else:
                    c.face_hair(reg, reg, ln, 6, fh_col)
            c.eye_extras()
            c.mouth_occlusion()
        else:
            for st, col in spec['hair']: c.hair('hair_' + st, st, 12, col)
            for reg, ln in spec['face_hair']: c.face_hair(reg, reg, ln, 6, fh_col)
    else:
        styles = ['bun', 'plait', 'long'] if female else ['short', 'side', 'curly', 'balding', 'bouffant']
        for st in styles: c.hair('hair_' + st, st, 7)
        if not female:
            c.face_hair('moustache', 'moustache', 0.09, 4); c.face_hair('beard', 'beard', 0.1, 4)
            c.glasses()
    if spec.get('cards'):
        # the quality prototype: expressions from MakeHuman's facial pose units, skinned through its full
        # face rig on this character's own mesh (left/right brows, lids, cheeks, nasolabial, lips, jaw)
        import faceunits
        units = sorted({u for comp in FACS.values() for u in comp})
        c.add_pose_morphs(FACS, faceunits.bake(core, v, units))
    else:
        c.add_morphs(build.EXPRESSIONS)
    if not hero:
        c.add_morphs(build.IDENTITY, prefix_dir='', only=['skin_a'])
    g = gltf.Glb()
    lods = [(0, 1.0), (1, 0.3), (2, 0.07)] if hero else [(1, 0.24), (2, 0.06)]
    stats = c.export(g, lods)
    g.save(os.path.join(OUT, name + '.glb'))
    if hero:
        proto = bool(spec.get('cards'))      # the quality prototype gets a finer, 2048 skin
        tex.skin(c, os.path.join(OUT, 'tex'), name, spec['tone'], spec['age_lines'], female, stubble=0.0 if female else (0.3 if proto else 0.5), seed=hash(name) % 1000, grey=0.8 if name in ('devaraj', 'rajini') else 0.0, R=2048 if proto else 1024, hero=proto, moustache=0.55 if (proto and any(r == 'moustache' for r, _ in spec['face_hair'])) else 0.0, brow_k=0.4 if proto else 0.92)
    if not hero:
        tex.skin(c, os.path.join(OUT, 'tex'), name, 0, float(np.clip((p['age'] - 0.45) * 1.6, 0.05, 0.9)), female, stubble=0.0 if (female or p['age'] < 0.3) else 0.35, seed=hash(name) % 1000, R=512)
    lm = c.landmarks()
    hg = (c.heads['head'][1] - c.ground) * 0.1
    info = {'tris': stats, 'height': float((v[base.vgroups['body'], 1].max() - c.ground) * 0.1), 'female': bool(female), 'hero': hero,
            'parts': sorted(set(q.name for q in c.parts)), 'eye_y': float((c.heads['eye_l'][1] - c.ground) * 0.1),
            'arm_dir': [float(x) for x in (c.t['upperarm_l'] - c.h['upperarm_l'])], 'tone': spec.get('tone', 2) if hero else -1}
    print(name, info['tris'], 'height %.2f' % info['height'], 'size %.1f MB' % (os.path.getsize(os.path.join(OUT, name + '.glb')) / 1e6))
    return c, info

if __name__ == '__main__':
    base = mh.Base(sys.argv[1]); core = sys.argv[2]
    only = sys.argv[3:]
    os.makedirs(OUT, exist_ok=True)
    mpath = os.path.join(OUT, 'manifest.json')
    man = json.load(open(mpath)) if os.path.exists(mpath) else {}
    tex.shared(os.path.join(OUT, 'tex'))
    tex.hair_cards(os.path.join(OUT, 'tex'))
    tex.pores(os.path.join(OUT, 'tex'))
    tex.hair_fiber(os.path.join(OUT, 'tex'))
    import shutil
    tex.eye(os.path.join(core, 'eyes/materials/brown_eye.png'), os.path.join(OUT, 'tex', 'eye.png'))
    for name, spec in HEROES.items():
        if only and name not in only: continue
        c, man[name] = make(base, core, name, spec, True)
    for name, spec in CROWD.items():
        if only and name not in only: continue
        c, man[name] = make(base, core, name, spec, False)
    json.dump(man, open(mpath, 'w'), indent=1)
