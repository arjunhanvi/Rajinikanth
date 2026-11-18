"""BIG BANG LORE - Raja R1 master project setup (Blender 5.3).

Builds the production Blender project WITHOUT sculpting anything:
  * metric units, 1 unit = 1 m;
  * collections: 00_ORIGINAL_BASE (locked, disabled for edits), 10_WORKING, 20_CURRENT_RAJA (comparison),
    30_REFERENCE, 40_CAMERAS, 50_LIGHT_STUDIO, 51_LIGHT_RAKING;
  * the candidate male base mesh appended from the Human Base Meshes bundle (original kept untouched,
    a working copy made for sculpting with a Multiresolution modifier ready);
  * the current game Raja body (raja.glb, skin meshes only) imported for comparison, at matching scale;
  * the two reference photos as image empties;
  * front / back / left / right / both three-quarter cameras, studio and raking light rigs;
  * evidence renders (solid clay + wireframe overlay) of base mesh vs current Raja into 08_EVIDENCE;
  * topology statistics (vertices, faces, quads/tris/ngons, poles) into 00_PROJECT_CONTROL;
  * RAJA_R1_MASTER.blend plus a dated backup copy; the file is then reopened to verify it.

Run (Windows, from a command prompt):
  "C:\\Program Files\\Blender Foundation\\Blender 5.3\\blender.exe" --background --python raja_master_setup.py -- D:\\BIG_BANG_LORE_PRODUCTION
Optional second argument: path to the game's raja.glb (default: <root>\\01_REFERENCE\\raja.glb).
"""
import bpy
import bmesh
import datetime
import json
import os
import shutil
import sys
import glob
import zipfile

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = argv[0] if argv else os.getcwd()
RAJA_GLB = argv[1] if len(argv) > 1 else os.path.join(ROOT, "01_REFERENCE", "raja.glb")
D = {k: os.path.join(ROOT, k) for k in ["00_PROJECT_CONTROL", "01_REFERENCE", "02_BASE_MESHES", "03_BLENDER", "04_SCULPTS",
                                        "05_RETOPOLOGY", "06_TEXTURES", "07_EXPORTS", "08_EVIDENCE", "09_SCRIPTS"]}
for p in D.values():
    os.makedirs(p, exist_ok=True)
LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    print("[raja-setup]", s)
    LOG.append(s)


log("Blender", bpy.app.version_string, "| root", ROOT)

# ------------------------------------------------------------------ fresh scene, metric units
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.unit_settings.system = 'METRIC'
sc.unit_settings.scale_length = 1.0
sc.unit_settings.length_unit = 'METERS'


def coll(name, parent=None):
    c = bpy.data.collections.new(name)
    (parent or sc.collection).children.link(c)
    return c


C = {n: coll(n) for n in ["00_ORIGINAL_BASE", "10_WORKING", "20_CURRENT_RAJA", "30_REFERENCE", "40_CAMERAS", "50_LIGHT_STUDIO", "51_LIGHT_RAKING"]}

# ------------------------------------------------------------------ base mesh bundle
bundle_blends = glob.glob(os.path.join(D["02_BASE_MESHES"], "**", "*.blend"), recursive=True)
if not bundle_blends:
    zips = glob.glob(os.path.join(D["02_BASE_MESHES"], "human-base-meshes*.zip"))
    if zips:
        out = os.path.join(D["02_BASE_MESHES"], "extracted")
        if not os.path.isdir(out):
            log("extracting", zips[0], "-> 02_BASE_MESHES/extracted (the zip itself is left untouched)")
            with zipfile.ZipFile(zips[0]) as z:
                z.extractall(out)
        bundle_blends = glob.glob(os.path.join(out, "**", "*.blend"), recursive=True)
inventory = []
for bl in bundle_blends:
    with bpy.data.libraries.load(bl, link=False) as (src, _):
        for o in src.objects:
            inventory.append((bl, o))
log("bundle .blend files:", len(bundle_blends), "| objects found:", len(inventory))
with open(os.path.join(D["00_PROJECT_CONTROL"], "base_mesh_inventory.txt"), "w") as f:
    for bl, o in inventory:
        f.write(f"{os.path.relpath(bl, ROOT)} :: {o}\n")


def pick_male(inv):
    """The realistic male full body: prefer names with 'realistic' + 'male' and 'body', avoid 'female'."""
    def score(name):
        n = name.lower()
        s = 0
        if "realistic" in n: s += 4
        if "male" in n and "female" not in n: s += 4
        if "body" in n or "full" in n: s += 2
        if any(k in n for k in ("head", "hand", "foot", "feet", "eye", "teeth")): s -= 3
        return s
    best = sorted(inv, key=lambda t: score(t[1]), reverse=True)
    return best[0] if best and score(best[0][1]) >= 6 else None


base = None
cand = pick_male(inventory)
if cand:
    bl, name = cand
    with bpy.data.libraries.load(bl, link=False) as (src, dst):
        dst.objects = [name]
    for o in dst.objects:
        if o is None:
            continue
        C["00_ORIGINAL_BASE"].objects.link(o)
        base = o
    log("base mesh candidate:", name, "from", os.path.relpath(bl, ROOT))
else:
    log("NO realistic male base mesh found - put human-base-meshes-bundle-v1.4.1.zip (or its extracted folder) in 02_BASE_MESHES and run again")

# ------------------------------------------------------------------ current game Raja (comparison)
raja = []
if os.path.isfile(RAJA_GLB):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=RAJA_GLB)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        if o.type == 'MESH' and o.name.startswith("L0_skin"):
            C["20_CURRENT_RAJA"].objects.link(o)
            raja.append(o)
        else:
            bpy.data.objects.remove(o, do_unlink=True)
    log("current Raja skin meshes imported:", [o.name for o in raja])
else:
    log("raja.glb not found at", RAJA_GLB, "- copy assets/humans/raja.glb from the game project into 01_REFERENCE")


def bbox(objs):
    import mathutils
    pts = [o.matrix_world @ mathutils.Vector(c) for o in objs for c in o.bound_box]
    lo = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


# working copy + side-by-side placement, both standing on the ground (z = 0)
work = None
if base:
    lo, hi = bbox([base])
    log("base mesh height (as authored): %.3f m" % (hi.z - lo.z))
    work = base.copy(); work.data = base.data.copy(); work.name = "RAJA_BODY_WORKING"
    C["10_WORKING"].objects.link(work)
    if not any(m.type == 'MULTIRES' for m in work.modifiers):
        work.modifiers.new("Multires", 'MULTIRES')
    work.location.x += 0.0
    base.hide_select = True                           # the original cannot be clicked or edited by accident
    base.hide_render = True
    base.hide_viewport = True
    C["00_ORIGINAL_BASE"].hide_select = True
if raja:
    lo, hi = bbox(raja)
    for o in raja:
        o.location.x += 0.9 - (lo.x + hi.x) * 0.5    # Raja to the right of the working mesh
        o.location.z -= lo.z
    log("current Raja height: %.3f m" % (hi.z - lo.z))

# ------------------------------------------------------------------ reference photos
for f in sorted(glob.glob(os.path.join(D["01_REFERENCE"], "raja_ref_*"))):
    if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
        img = bpy.data.images.load(f, check_existing=True)
        e = bpy.data.objects.new("REF_" + os.path.basename(f), None)
        e.empty_display_type = 'IMAGE'; e.data = img; e.empty_display_size = 0.5
        e.location = (-1.0, 0.6, 1.5); e.rotation_euler = (1.5708, 0, 0)
        C["30_REFERENCE"].objects.link(e)
        log("reference image:", os.path.basename(f))

# ------------------------------------------------------------------ cameras and lights
import math
targets = ([work] if work else []) + raja
if targets:
    lo, hi = bbox(targets)
    cx, cy, cz = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (hi.z - lo.z) * 0.5
else:
    cx, cy, cz = 0.0, 0.0, 0.9
cams = {"CAM_FRONT": (0, -1), "CAM_BACK": (0, 1), "CAM_LEFT": (1, 0), "CAM_RIGHT": (-1, 0), "CAM_34_L": (0.7, -0.7), "CAM_34_R": (-0.7, -0.7)}
for nm, (dx, dy) in cams.items():
    cd = bpy.data.cameras.new(nm); cd.type = 'ORTHO'; cd.ortho_scale = 2.4
    cam = bpy.data.objects.new(nm, cd)
    cam.location = (cx + dx * 6, cy + dy * 6, cz)
    cam.rotation_euler = (math.radians(90), 0, math.atan2(dx, -dy))
    C["40_CAMERAS"].objects.link(cam)


def sun(name, rot, energy, col_):
    ld = bpy.data.lights.new(name, 'SUN'); ld.energy = energy; ld.angle = math.radians(3)
    lo_ = bpy.data.objects.new(name, ld); lo_.rotation_euler = [math.radians(a) for a in rot]
    col_.objects.link(lo_)


sun("STUDIO_KEY", (50, 0, 35), 3.0, C["50_LIGHT_STUDIO"])
sun("STUDIO_FILL", (65, 0, -130), 1.0, C["50_LIGHT_STUDIO"])
sun("STUDIO_RIM", (40, 0, 170), 1.5, C["50_LIGHT_STUDIO"])
sun("RAKING_KEY", (62, 0, 55), 3.5, C["51_LIGHT_RAKING"])
sun("RAKING_FILL", (80, 0, -120), 0.4, C["51_LIGHT_RAKING"])
w = bpy.data.worlds.new("NEUTRAL"); sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.18, 0.18, 0.19, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.6

# ------------------------------------------------------------------ topology statistics
stats = {}


def topo(o):
    bm = bmesh.new()
    dg = bpy.context.evaluated_depsgraph_get()
    bm.from_mesh(o.data)
    q = sum(1 for f in bm.faces if len(f.verts) == 4)
    t = sum(1 for f in bm.faces if len(f.verts) == 3)
    n = sum(1 for f in bm.faces if len(f.verts) > 4)
    poles = sum(1 for v in bm.verts if len(v.link_edges) not in (4,) and not v.is_boundary)
    nm = sum(1 for e in bm.edges if not e.is_manifold)
    r = {"verts": len(bm.verts), "faces": len(bm.faces), "quads": q, "tris": t, "ngons": n, "poles(non-4 valence)": poles,
         "non_manifold_edges": nm, "uv_layers": len(o.data.uv_layers), "modifiers": [m.type for m in o.modifiers]}
    bm.free()
    return r


if base:
    stats["base_" + base.name] = topo(base)
for o in raja:
    stats["raja_" + o.name] = topo(o)
with open(os.path.join(D["00_PROJECT_CONTROL"], "topology_stats.json"), "w") as f:
    json.dump(stats, f, indent=1)
log("topology stats written:", list(stats))

# ------------------------------------------------------------------ evidence renders (workbench clay + wireframe)
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'SINGLE'
sc.display.shading.single_color = (0.62, 0.6, 0.58)
sc.render.resolution_x = 1000; sc.render.resolution_y = 1200
sc.render.film_transparent = False
if work:
    work.hide_render = False
for wire in (False, True):
    sc.display.shading.show_object_outline = False
    for o in ([work] if work else []) + raja:
        o.show_wire = wire
    sc.render.use_freestyle = False
    for nm in cams:
        sc.camera = bpy.data.objects[nm]
        sc.render.filepath = os.path.join(D["08_EVIDENCE"], f"R1A_{nm}{'_wire' if wire else ''}.png")
        bpy.ops.render.render(write_still=True)
log("evidence renders written to 08_EVIDENCE")

# ------------------------------------------------------------------ save, back up, reopen
master = os.path.join(D["03_BLENDER"], "RAJA_R1_MASTER.blend")
if os.path.exists(master):
    log("RAJA_R1_MASTER.blend already exists - saving this run as RAJA_R1_MASTER_new.blend instead (nothing overwritten)")
    master = os.path.join(D["03_BLENDER"], "RAJA_R1_MASTER_new.blend")
bpy.ops.wm.save_as_mainfile(filepath=master)
stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
os.makedirs(os.path.join(D["03_BLENDER"], "backup"), exist_ok=True)
shutil.copy2(master, os.path.join(D["03_BLENDER"], "backup", f"RAJA_R1_MASTER_{stamp}.blend"))
bpy.ops.wm.open_mainfile(filepath=master)
ok = all(n in bpy.data.collections for n in C)
log("reopened", os.path.basename(master), "| collections intact:", ok, "| objects:", len(bpy.data.objects))
with open(os.path.join(D["00_PROJECT_CONTROL"], "setup_log.txt"), "w") as f:
    f.write("\n".join(LOG))
