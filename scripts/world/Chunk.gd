class_name Chunk
extends Node3D
## One 100 m tile of the city, generated deterministically from City data:
## ground, arterial roads, side-street grid, buildings, props and collision.

const FLOOR_H := 3.0
const WALLS := [Color(0.93, 0.9, 0.8), Color(0.95, 0.86, 0.6), Color(0.72, 0.82, 0.9), Color(0.93, 0.76, 0.74), Color(0.75, 0.88, 0.75),
	Color(0.9, 0.9, 0.9), Color(0.86, 0.78, 0.66), Color(0.98, 0.93, 0.7), Color(0.68, 0.76, 0.72), Color(0.88, 0.7, 0.55), Color(0.8, 0.8, 0.86)]
const SIGN_COUNT := 32

var c := Vector2i.ZERO
var lamps: Array = []       # Vector3 lamp-head positions (for the dynamic light pool)
var parking: Array = []     # {pos: Vector3, rot: float}
var rng := RandomNumberGenerator.new()
var _boxes: Array = []      # [centre: Vector3, size: Vector3] building collision
var _walk: Array = []       # [a: Vector3, b: Vector3, width, top] walkable strips (roads, footpaths)
var _walk_boxes: Array = [] # [centre, size] walkable plates
var _trees: Array = []      # [pos: Vector3, scale: float]
var _poles: Array = []      # Transform3D
var _epoles: Array = []     # electric poles (Vector3)
var _palms: Array = []      # coconut palms
var spots: Array = []       # activity anchors for the crowd: {pos, yaw, kind}
var g_pool: MB
var g_shop: MB
var g_puddle: MB
var g_tarp: MB
var _hoard: MB
var _tv = null

func build(chunk: Vector2i) -> void:
	c = chunk
	name = "Chunk_%d_%d" % [c.x, c.y]
	rng.seed = hash(c) * 7919 + 2002
	var ox := c.x * City.CHUNK
	var oz := c.y * City.CHUNK
	var mid := Vector2(ox + 50.0, oz + 50.0)
	var dist := City.district(mid)
	var g_ground := MB.new()
	var g_street := MB.new()
	var g_road := MB.new()
	var g_foot := MB.new()
	var b_fac := MB.new()
	var b_sign := MB.new()
	var b_roof := MB.new()
	var b_hoard := MB.new()
	var b_shed := MB.new()
	var p_col := MB.new()
	g_pool = MB.new()
	g_shop = MB.new()
	g_puddle = MB.new()
	g_tarp = MB.new()
	_hoard = b_hoard

	g_ground.flat(Vector3(mid.x, 0, mid.y), City.CHUNK, City.CHUNK, Rect2(0, 0, 12, 12))
	# --- side-street grid ---
	for i in 2:
		for j in 2:
			var gx := ox + i * City.GRID
			var gz := oz + j * City.GRID
			if City.district(Vector2(gx, gz + 25.0)).kind != "rural":
				g_street.strip(Vector3(gx, 0.04, gz), Vector3(gx, 0.04, gz + City.GRID), City.STREET_W, 8.0)
				_walk.append([Vector3(gx, 0, gz), Vector3(gx, 0, gz + City.GRID), City.STREET_W, 0.04])
				_dress_street(Vector2(gx, gz), Vector2(0, 1), g_foot, p_col)
			if City.district(Vector2(gx + 25.0, gz)).kind != "rural":
				g_street.strip(Vector3(gx, 0.045, gz), Vector3(gx + City.GRID, 0.045, gz), City.STREET_W, 8.0)
				_walk.append([Vector3(gx, 0, gz), Vector3(gx + City.GRID, 0, gz), City.STREET_W, 0.045])
				_dress_street(Vector2(gx, gz), Vector2(1, 0), g_foot, p_col)
			if City.district(Vector2(gx, gz)).kind != "rural":
				var lp := Vector3(gx + 4.4, 0, gz + 4.4)
				_poles.append(Transform3D(Basis.IDENTITY, lp))
				lamps.append(lp + Vector3(-0.9, 5.7, -0.9))
	# --- arterial roads ---
	for idx in City.edges_near(c):
		var e = City.edges[idx]
		var n := int(ceil(e.len / 25.0))
		var side := Vector3(e.dir.y, 0, -e.dir.x)
		for i in n:
			var a2: Vector2 = e.pa.lerp(e.pb, float(i) / n)
			var b2: Vector2 = e.pa.lerp(e.pb, float(i + 1) / n)
			if City.chunk_of((a2 + b2) * 0.5) != c:
				continue
			var a := Vector3(a2.x, 0.09, a2.y)
			var b := Vector3(b2.x, 0.09, b2.y)
			g_road.strip(a, b, e.w, 12.0)
			var off: Vector3 = side * (float(e.w) * 0.5 + 1.25)
			var up := Vector3(0, 0.1, 0)
			g_foot.strip(a + off + up, b + off + up, 2.5, 2.5)
			g_foot.strip(a - off + up, b - off + up, 2.5, 2.5)
			_walk.append([a, b, float(e.w), 0.09])
			_walk.append([a + off, b + off, 2.5, 0.19])
			_walk.append([a - off, b - off, 2.5, 0.19])
			if i % 2 == 0 and i > 0:
				var s := 1.0 if (i / 2) % 2 == 0 else -1.0
				var lp2: Vector3 = a + side * s * (float(e.w) * 0.5 + 0.6)
				lp2.y = 0
				_poles.append(Transform3D(Basis.IDENTITY, lp2))
				lamps.append(lp2 + Vector3(0, 5.7, 0) - side * s * 1.0)
	for id in City.nodes:
		var np2: Vector2 = City.nodes[id].p
		if City.chunk_of(np2) == c:
			g_street.flat(Vector3(np2.x, 0.1, np2.y), 22.0, 22.0, Rect2(0, 0, 3, 3))
			_walk_boxes.append([Vector3(np2.x, 0.05, np2.y), Vector3(22.0, 0.1, 22.0)])
		var st = City.stops[id]
		if City.chunk_of(st.pos) == c:
			_bus_stop(p_col, st, City.nodes[id].name)
	# --- buildings ---
	for i in 2:
		for j in 2:
			_block(ox + i * City.GRID + 4.0, oz + j * City.GRID + 4.0, b_fac, b_sign, b_roof, b_hoard, b_shed, p_col)

	var ground_mesh := ArrayMesh.new()
	g_ground.add_to(ground_mesh, Mats.grass() if dist.kind == "rural" else Mats.ground())
	g_street.add_to(ground_mesh, Mats.street())
	g_road.add_to(ground_mesh, Mats.road())
	g_foot.add_to(ground_mesh, Mats.footpath())
	_add_mesh(ground_mesh, false)
	var bm := ArrayMesh.new()
	b_fac.add_to(bm, Mats.facade())
	b_sign.add_to(bm, Mats.signs())
	b_roof.add_to(bm, Mats.concrete())
	b_hoard.add_to(bm, Mats.hoardings())
	b_shed.add_to(bm, Mats.shed())
	p_col.add_to(bm, Mats.vcol())
	if bm.get_surface_count() > 0:
		_add_mesh(bm, true)
	for lp3 in lamps:
		g_pool.flat(Vector3(lp3.x, 0.24, lp3.z), 11.0, 11.0)
	var pm := ArrayMesh.new()
	g_pool.add_to(pm, Mats.pool(false))
	g_shop.add_to(pm, Mats.pool(true))
	g_puddle.add_to(pm, Mats.puddle())
	g_tarp.add_to(pm, Mats.tarp())
	if _tv != null:
		var tvp := AudioStreamPlayer3D.new()
		tvp.stream = Sfx.stream("amb_tv")
		tvp.bus = "Amb"
		tvp.unit_size = 2.5
		tvp.max_distance = 13.0
		tvp.volume_db = -10.0
		tvp.autoplay = true
		tvp.position = _tv
		add_child(tvp)
	if pm.get_surface_count() > 0:
		_add_mesh(pm, false)
	_props()
	_collision()
	for z in City.zones:
		if City.chunk_of(z.rect.get_center()) == c:
			var lm := Landmarks.build(z)
			if lm != null:
				add_child(lm)

func _add_mesh(m: ArrayMesh, shadows: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _block(x0: float, z0: float, fac: MB, sg: MB, roof: MB, hoard: MB, shed: MB, pc: MB) -> void:
	var size := City.GRID - 8.0
	var d := City.district(Vector2(x0 + size * 0.5, z0 + size * 0.5))
	if d.kind == "rural":
		if rng.randf() < 0.5:
			for t in rng.randi_range(1, 4) if not City.rect_hits_zone(Rect2(x0, z0, size, size)) else 0:
				_trees.append([Vector3(x0 + rng.randf() * size, 0, z0 + rng.randf() * size), rng.randf_range(0.8, 1.5)])
		return
	var kind: String = d.kind
	var depth := size * 0.5 - 1.0
	for row in 2:
		var nz := -1.0 if row == 0 else 1.0
		var front_z := z0 if row == 0 else z0 + size
		var x := x0
		while x < x0 + size - 5.0:
			var w := _lot_width(kind)
			if x + w > x0 + size - 4.0:
				w = x0 + size - x
			var gap := 0.0
			if kind in ["res", "out"]:
				gap = rng.randf_range(0.8, 2.5)
			elif kind == "cant":
				gap = 3.0
			elif kind in ["com", "gov"] and rng.randf() < 0.3:
				gap = rng.randf_range(0.6, 1.5)
			var lot := Rect2(x, front_z if row == 1 else front_z, w, depth)
			var cz := front_z - nz * depth * 0.5
			var rect := Rect2(x, cz - depth * 0.5, w, depth)
			var skip := rng.randf() > float(d.density) + 0.15
			if not skip:
				for sp in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y), rect.get_center()]:
					if City.on_arterial(sp, 3.6):
						skip = true
						break
			var zoned := City.rect_hits_zone(rect)
			if not skip and zoned:
				skip = true
			if skip:
				if not zoned and kind in ["res", "cant", "out"] and rng.randf() < 0.4:
					_trees.append([Vector3(x + w * 0.5, 0, cz), rng.randf_range(0.9, 1.6)])
			else:
				var corner := -1 if x == x0 else (1 if x + w >= x0 + size - 0.1 else 0)
				_building(Rect2(x, cz - depth * 0.5, w - gap, depth), nz, kind, corner, fac, sg, roof, hoard, shed, pc)
			x += w
	# parked vehicles along the block's north street
	if rng.randf() < (0.6 if kind in ["com", "old"] else 0.3):
		parking.append({"pos": Vector3(x0 + rng.randf_range(6, size - 6), 0, z0 - 1.5), "rot": PI * 0.5 * (1 if rng.randf() < 0.5 else -1)})

func _lot_width(kind: String) -> float:
	match kind:
		"old": return rng.randf_range(5.0, 8.5)
		"com": return rng.randf_range(8.0, 15.0)
		"gov": return rng.randf_range(14.0, 22.0)
		"ind": return rng.randf_range(18.0, 34.0)
		"cant": return rng.randf_range(14.0, 20.0)
		"out": return rng.randf_range(6.0, 11.0)
	return rng.randf_range(8.0, 13.0)

# ------------------------------------------------------------------ street dressing
## Kerbs, drains, electric poles with wires and the small things that make a
## street: carts, kiosks, dustbins, a resting cow.
func _dress_street(o: Vector2, d: Vector2, foot: MB, pc: MB) -> void:
	var mid := o + d * 25.0
	if City.in_zone(mid) != null and City.in_zone(mid).kind != "site":
		return
	for k in 6:
		if City.on_arterial(o + d * (k * 10.0), 4.5):
			return
	var dist := City.district(mid)
	var kind: String = dist.kind
	var side := Vector2(d.y, -d.x)
	var a := Vector3(o.x, 0, o.y)
	var dv := Vector3(d.x, 0, d.y)
	var sv := Vector3(side.x, 0, side.y)
	var basis := Basis(Vector3.UP, atan2(d.x, d.y))
	if kind in ["com", "gov", "res", "cant", "old"]:
		for s: float in [-1.0, 1.0]:
			var e0 := a + dv * 4.2 + sv * s * 3.45 + Vector3(0, 0.13, 0)
			foot.strip(e0, e0 + dv * 41.6, 1.1, 2.2)
			_walk.append([Vector3(e0.x, 0, e0.z), Vector3(e0.x, 0, e0.z) + dv * 41.6, 1.1, 0.13])
			pc.box(a + dv * 25.0 + sv * s * 2.82 + Vector3(0, 0.07, 0), Vector3(0.14, 0.14, 41.6), Color(0.3, 0.3, 0.3) if s > 0 else Color(0.62, 0.6, 0.56), Rect2(0, 0, 1, 1), true, basis)
	# open drain with cover slabs on one side
	var ds := 1.0 if rng.randf() < 0.5 else -1.0
	pc.box(a + dv * 25.0 + sv * ds * 3.95 + Vector3(0, 0.05, 0), Vector3(0.28, 0.02, 40.0), Color(0.08, 0.09, 0.08), Rect2(0, 0, 1, 1), true, basis)
	for i in 5:
		if rng.randf() < 0.7:
			pc.box(a + dv * (8.0 + i * 8.0) + sv * ds * 3.95 + Vector3(0, 0.08, 0), Vector3(0.5, 0.06, 2.2), Color(0.55, 0.54, 0.5), Rect2(0, 0, 1, 1), true, basis)
	# the road itself: patched tar, potholes, a manhole, rain puddles, litter in the gutter, weeds
	for i in rng.randi_range(2, 5):
		var rp := a + dv * rng.randf_range(4.0, 46.0) + sv * rng.randf_range(-2.2, 2.2) + Vector3(0, 0.056, 0)
		var r2 := rng.randf()
		if r2 < 0.45:
			pc.flat(rp, rng.randf_range(1.0, 3.2), rng.randf_range(1.0, 2.6), Rect2(0, 0, 1, 1), Color(0.14, 0.14, 0.15))        # fresh tar patch
		elif r2 < 0.7:
			pc.flat(rp, rng.randf_range(0.6, 1.3), rng.randf_range(0.5, 1.0), Rect2(0, 0, 1, 1), Color(0.3, 0.26, 0.22))         # pothole, down to the mud
			g_puddle.flat(rp + Vector3(0, 0.004, 0), 0.9, 0.7)
		elif r2 < 0.82:
			pc.flat(rp, 0.85, 0.85, Rect2(0, 0, 1, 1), Color(0.2, 0.2, 0.21))                                                  # manhole cover
			pc.flat(rp + Vector3(0, 0.003, 0), 0.6, 0.6, Rect2(0, 0, 1, 1), Color(0.28, 0.27, 0.26))
		else:
			pc.flat(rp, rng.randf_range(1.5, 4.0), 0.12, Rect2(0, 0, 1, 1), Color(0.5, 0.5, 0.48))                              # ghost of an old road marking
	for i in rng.randi_range(1, 3):
		g_puddle.flat(a + dv * rng.randf_range(5.0, 45.0) + sv * (2.5 * (1.0 if rng.randf() < 0.5 else -1.0)) + Vector3(0, 0.06, 0), rng.randf_range(1.0, 2.6), rng.randf_range(0.7, 1.5))
	for i in rng.randi_range(3, 8):
		var ls := 1.0 if rng.randf() < 0.5 else -1.0
		var lp4 := a + dv * rng.randf_range(4.0, 46.0) + sv * ls * rng.randf_range(2.5, 3.9)
		if rng.randf() < 0.55:
			pc.flat(lp4 + Vector3(0, 0.15, 0), rng.randf_range(0.15, 0.4), rng.randf_range(0.12, 0.3), Rect2(0, 0, 1, 1), [Color(0.88, 0.86, 0.8), Color(0.7, 0.6, 0.45), Color(0.8, 0.3, 0.25), Color(0.9, 0.85, 0.4)][rng.randi() % 4])   # paper, cardboard, wrappers
		else:
			pc.box(lp4 + Vector3(0, 0.2, 0), Vector3(0.25, rng.randf_range(0.15, 0.4), 0.25), Color(0.25, 0.42, 0.2))            # weeds through the slabs
	# electric poles along the other side, wires strung between them
	var ps := -ds
	var prev := Vector3.INF
	for i in 3:
		var pp := a + dv * (6.0 + i * 19.0) + sv * ps * 3.75
		_epoles.append(pp)
		pc.box(pp + Vector3(0, 6.6, 0), Vector3(1.5, 0.08, 0.08), Color(0.3, 0.26, 0.22), Rect2(0, 0, 1, 1), true, Basis(Vector3.UP, atan2(side.x, side.y)))
		if i == 1 and rng.randf() < 0.35:
			pc.box(pp + Vector3(0, 5.2, 0), Vector3(0.7, 0.9, 0.6), Color(0.35, 0.38, 0.4))     # transformer
		if prev != Vector3.INF:
			for w: float in [-0.6, 0.6]:
				_wire(pc, prev + sv * w + Vector3(0, 6.62, 0), pp + sv * w + Vector3(0, 6.62, 0))
		prev = pp
	# house connections sag across the street
	if kind in ["res", "old", "com"] and rng.randf() < 0.8:
		var p0: Vector3 = _epoles[-2] + Vector3(0, 6.3, 0)
		_wire(pc, p0, p0 - sv * ps * 8.5 + Vector3(0, -2.3, 0) + dv * rng.randf_range(-4, 4))
	# street life
	var n_items := 0
	if kind in ["com", "old"]: n_items = rng.randi_range(2, 4)
	elif kind in ["res", "gov", "out"]: n_items = rng.randi_range(1, 2)
	elif kind == "cant": n_items = rng.randi_range(0, 1)
	for i in n_items:
		var s2 := 1.0 if rng.randf() < 0.5 else -1.0
		var t := rng.randf_range(8.0, 42.0)
		var p := a + dv * t + sv * s2 * 2.35
		if City.on_arterial(Vector2(p.x, p.z), 4.0) or City.in_zone(Vector2(p.x, p.z), 3.0) != null:
			continue
		var face := atan2(-side.x * s2, -side.y * s2)      # facing the middle of the street
		var r := rng.randf()
		if r < 0.34:
			_cart(pc, p, basis, rng.randi() % 4)
			spots.append({"pos": p - sv * s2 * -0.95, "yaw": face, "kind": "vendor"})
			spots.append({"pos": p - sv * s2 * 1.2 + dv * 0.3, "yaw": face + PI, "kind": "customer"})
		elif r < 0.5 and kind != "cant":
			var kp := a + dv * t + sv * s2 * 3.3
			pc.box(kp + Vector3(0, 1.05, 0), Vector3(1.5, 2.1, 1.7), [Color(0.2, 0.4, 0.65), Color(0.6, 0.2, 0.2), Color(0.25, 0.5, 0.3)][rng.randi() % 3], Rect2(0, 0, 1, 1), true, basis)
			pc.box(kp + Vector3(0, 2.2, 0) - sv * s2 * 0.5, Vector3(1.7, 0.08, 2.6), Color(0.4, 0.42, 0.45), Rect2(0, 0, 1, 1), true, basis)
			pc.box(kp - sv * s2 * 0.78 + Vector3(0, 1.0, 0), Vector3(0.06, 0.5, 1.3), Color(0.9, 0.85, 0.3), Rect2(0, 0, 1, 1), true, basis)
			for k in 6:
				pc.box(kp - sv * s2 * 0.8 + dv * (-0.55 + k * 0.22) + Vector3(0, 1.75, 0), Vector3(0.05, 0.3, 0.12), [Color(0.9, 0.2, 0.2), Color(0.95, 0.8, 0.2), Color(0.2, 0.6, 0.3)][k % 3], Rect2(0, 0, 1, 1), true, basis)
			_boxes.append([kp + Vector3(0, 1.05, 0), Vector3(1.5, 2.1, 1.7) if d.x == 0.0 else Vector3(1.7, 2.1, 1.5)])
			spots.append({"pos": kp - sv * s2 * 1.5, "yaw": face + PI, "kind": "customer"})
		elif r < 0.66:
			pc.box(p + sv * s2 * 0.7 + Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.6), Color(0.2, 0.42, 0.25))            # dustbin
			pc.box(p + sv * s2 * 0.7 + dv * 0.6 + Vector3(0, 0.12, 0), Vector3(0.9, 0.24, 0.7), Color(0.4, 0.36, 0.3))  # spill-over
		elif r < 0.76 and kind in ["old", "res", "out"]:
			var cb := Basis(Vector3.UP, rng.randf() * TAU)                                                             # a cow at rest
			var cc := Color(0.9, 0.88, 0.82) if rng.randf() < 0.6 else Color(0.45, 0.3, 0.2)
			pc.box(p + Vector3(0, 0.42, 0), Vector3(0.7, 0.6, 1.7), cc, Rect2(0, 0, 1, 1), true, cb)
			pc.box(p + cb * Vector3(0, 0.75, -1.05), Vector3(0.34, 0.4, 0.55), cc, Rect2(0, 0, 1, 1), true, cb)
			pc.box(p + cb * Vector3(0, 0.98, -0.95), Vector3(0.5, 0.06, 0.06), Color(0.2, 0.18, 0.15), Rect2(0, 0, 1, 1), true, cb)
		elif r < 0.86:
			spots.append({"pos": p + sv * s2 * 0.9, "yaw": face, "kind": "idle"})
			pc.box(p + sv * s2 * 1.3 + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 1.6), Color(0.6, 0.58, 0.54), Rect2(0, 0, 1, 1), true, basis)   # stone bench (katte)
		elif r < 0.91 and kind in ["com", "gov", "old"]:
			var np3 := p + sv * s2 * 1.1                                                                           # newspaper stand
			pc.box(np3 + Vector3(0, 0.5, 0), Vector3(0.3, 1.0, 1.2), Color(0.4, 0.3, 0.2), Rect2(0, 0, 1, 1), true, basis)
			for k in 4:
				pc.box(np3 - sv * s2 * 0.18 + dv * (-0.42 + k * 0.28) + Vector3(0, 0.75, 0), Vector3(0.04, 0.34, 0.24), [Color(0.9, 0.88, 0.8), Color(0.85, 0.3, 0.25), Color(0.9, 0.88, 0.8), Color(0.25, 0.4, 0.7)][k], Rect2(0, 0, 1, 1), true, basis)
			spots.append({"pos": np3 - sv * s2 * 0.9, "yaw": face + PI, "kind": "paper"})
		elif r < 0.96:
			var pb := p + sv * s2 * 1.15                                                                           # coin telephone on a stand
			pc.box(pb + Vector3(0, 0.6, 0), Vector3(0.1, 1.2, 0.1), Color(0.3, 0.3, 0.32))
			pc.box(pb + Vector3(0, 1.3, 0), Vector3(0.34, 0.42, 0.28), Color(0.9, 0.75, 0.1))
			pc.box(pb + Vector3(0, 1.62, 0), Vector3(0.5, 0.06, 0.4), Color(0.2, 0.3, 0.6))
			spots.append({"pos": pb - sv * s2 * 0.6, "yaw": face + PI, "kind": "phone"})
		else:
			pc.box(p + sv * s2 * 1.0 + Vector3(0, 0.6, 0), Vector3(0.34, 1.2, 0.34), Color(0.75, 0.1, 0.1))            # post box
			pc.box(p + sv * s2 * 1.0 + Vector3(0, 1.25, 0), Vector3(0.4, 0.12, 0.4), Color(0.1, 0.1, 0.1))

func _wire(pc: MB, p0: Vector3, p1: Vector3) -> void:
	var mid := (p0 + p1) * 0.5 - Vector3(0, 0.3 + p0.distance_to(p1) * 0.012, 0)
	for seg in [[p0, mid], [mid, p1]]:
		var v: Vector3 = seg[1] - seg[0]
		var z := v.normalized()
		var x := Vector3.UP.cross(z).normalized()
		pc.box((seg[0] + seg[1]) * 0.5, Vector3(0.025, 0.025, v.length()), Color(0.05, 0.05, 0.05), Rect2(0, 0, 1, 1), true, Basis(x, z.cross(x), z))

func _cart(pc: MB, p: Vector3, basis: Basis, kind: int) -> void:
	pc.box(p + Vector3(0, 0.82, 0), Vector3(1.0, 0.12, 1.7), Color(0.45, 0.32, 0.2), Rect2(0, 0, 1, 1), true, basis)
	for s: float in [-1.0, 1.0]:
		pc.wheel(p + basis * Vector3(s * 0.55, 0.4, 0.3), 0.4, 0.05, Color(0.15, 0.13, 0.12), basis, 8)
	pc.box(p + basis * Vector3(0, 0.4, -0.75), Vector3(0.06, 0.8, 0.06), Color(0.3, 0.22, 0.15))
	var cols: Array = [[Color(0.95, 0.8, 0.2), Color(0.9, 0.5, 0.1)], [Color(0.3, 0.6, 0.2), Color(0.8, 0.2, 0.15)], [Color(0.95, 0.9, 0.8), Color(0.7, 0.5, 0.3)], [Color(0.9, 0.3, 0.5), Color(1.0, 0.6, 0.1)]][kind]
	for i in 6:
		pc.box(p + basis * Vector3(-0.28 + (i % 2) * 0.56, 0.98, -0.55 + (i / 2) * 0.55), Vector3(0.46, 0.22, 0.46), cols[i % 2], Rect2(0, 0, 1, 1), true, basis)
	if kind != 2:
		pc.box(p + Vector3(0, 2.15, 0), Vector3(1.5, 0.05, 2.0), [Color(0.2, 0.4, 0.7), Color(0.75, 0.2, 0.2), Color(0.9, 0.8, 0.3), Color(0.25, 0.5, 0.3)][kind], Rect2(0, 0, 1, 1), true, basis)
		for s: float in [-1.0, 1.0]:
			pc.box(p + basis * Vector3(s * 0.48, 1.5, 0.8), Vector3(0.04, 1.3, 0.04), Color(0.3, 0.22, 0.15))
	g_tarp.box(p + Vector3(0, 1.08, 0), Vector3(1.15, 0.34, 1.85), Color.WHITE, Rect2(0, 0, 1, 1), true, basis)
	_boxes.append([p + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2)])

# ------------------------------------------------------------------ buildings
func _archetype(kind: String, w: float) -> String:
	var r := rng.randf()
	match kind:
		"old": return "pete" if r < 0.55 else ("shoprow" if r < 0.9 else "godown")
		"com":
			if w >= 11.0 and r < 0.3: return "complex"
			if r < 0.5: return "shoprow"
			if r < 0.68: return "office"
			if r < 0.8: return "hotel"
			return "lodge"
		"gov": return "govt" if r < 0.55 else ("office" if r < 0.8 else "school")
		"res":
			if w >= 11.0 and r < 0.22: return "apartment"
			if r < 0.7: return "house"
			if r < 0.8: return "school" if w >= 11.0 else "house"
			return "cornershop"
		"ind": return "shed" if r < 0.5 else ("workshop" if r < 0.8 else "godown")
		"cant": return "bungalow"
		"out": return "hut" if r < 0.5 else ("workshop" if r < 0.65 else "cornershop")
	return "house"

func _building(r: Rect2, nz: float, kind: String, corner: int, fac: MB, sg: MB, roof: MB, hoard: MB, shed: MB, pc: MB) -> void:
	var w := r.size.x
	var arch := _archetype(kind, w)
	var tint: Color = WALLS[rng.randi() % WALLS.size()]
	var floors := 1
	var setback := 0.0
	var g_tile := 1          # ground-floor bay tile
	var u_tiles: Array = [0] # upper-floor bay tiles
	var shop := false
	var balcony := 0.0       # probability of a projecting balcony per upper bay
	var chajja := false
	var sloped := false
	var colonnade := false
	var awning := false
	var compound := false
	var stair := false
	match arch:
		"pete":
			floors = rng.randi_range(2, 3); g_tile = 27; u_tiles = [0, 0, 3]; tint = tint.darkened(0.1); balcony = 0.25; sloped = rng.randf() < 0.35; shop = rng.randf() < 0.5
		"shoprow":
			floors = rng.randi_range(1, 3); shop = true; u_tiles = [0, 1, 24, 11]; awning = true; chajja = true; tint = tint.darkened(0.05)
		"complex":
			floors = rng.randi_range(3, 5); shop = true; u_tiles = [29, 2] if rng.randf() < 0.5 else [2, 2, 17]; colonnade = true; stair = true
			tint = [Color(0.9, 0.82, 0.78), Color(0.82, 0.86, 0.9), Color(0.92, 0.9, 0.8)][rng.randi() % 3]
		"office":
			floors = rng.randi_range(3, 6); g_tile = 2; u_tiles = [17] if rng.randf() < 0.5 else [2]; tint = Color(0.85, 0.87, 0.88).lerp(tint, 0.3); stair = true
		"hotel":
			floors = rng.randi_range(1, 3); shop = true; g_tile = 21; u_tiles = [1, 28]; awning = true; chajja = true
		"lodge":
			floors = rng.randi_range(3, 4); shop = true; u_tiles = [3]; balcony = 0.9; stair = true; tint = [Color(0.95, 0.85, 0.6), Color(0.75, 0.88, 0.8), Color(0.93, 0.76, 0.74)][rng.randi() % 3]
		"govt":
			floors = rng.randi_range(2, 3); g_tile = 16; u_tiles = [16]; tint = Color(0.93, 0.83, 0.55); setback = 3.0; compound = true
		"school":
			floors = 2; g_tile = 22; u_tiles = [22]; tint = Color(0.95, 0.93, 0.85); setback = 5.0; compound = true
		"apartment":
			floors = rng.randi_range(4, 5); g_tile = 28; u_tiles = [28, 3]; balcony = 0.55; stair = true; setback = 2.0; compound = true
		"house":
			floors = rng.randi_range(1, 2); g_tile = 1; u_tiles = [1, 0, 3]; setback = rng.randf_range(2.5, 4.5); compound = true; chajja = true
			sloped = floors == 1 and rng.randf() < 0.35; stair = not sloped and rng.randf() < 0.6; balcony = 0.3
		"cornershop":
			floors = rng.randi_range(1, 2); shop = true; g_tile = 30; u_tiles = [1, 24]; awning = true
		"hut":
			floors = 1; g_tile = 1; u_tiles = [1]; sloped = true; tint = tint.darkened(0.12); setback = rng.randf_range(0.0, 2.0)
		"bungalow":
			floors = rng.randi_range(1, 2); g_tile = 27; u_tiles = [0]; setback = 6.0; compound = true; sloped = true
		"workshop":
			floors = 1; shop = true; g_tile = 20; u_tiles = [15]; tint = Color(0.72, 0.72, 0.7)
		"godown":
			floors = 2; g_tile = 31; u_tiles = [18 if rng.randf() < 0.6 else 15]; tint = Color(0.86, 0.8, 0.74)
	var dp := r.size.y - setback
	var cx := r.position.x + w * 0.5
	var front_z := (r.position.y + setback) if nz < 0 else (r.end.y - setback)
	var back_z := front_z - nz * dp
	var h := floors * FLOOR_H
	var centre := Vector3(cx, h * 0.5, (front_z + back_z) * 0.5)
	_boxes.append([centre, Vector3(w, h, dp)])
	var nrm := Vector3(0, 0, nz)
	if arch == "shed":
		h = rng.randf_range(5.5, 8.0)
		centre.y = h * 0.5
		_boxes[-1] = [centre, Vector3(w, h, dp)]
		shed.box(centre, Vector3(w, h, dp), tint.lerp(Color(0.8, 0.82, 0.85), 0.6), Rect2(0, 0, w / 4.0, 1), false)
		var hw := Vector3(w * 0.5, 0, 0)
		var top := Vector3(cx, h, centre.z)
		shed.quad(top - hw + Vector3(0, 0, dp * 0.5), top + hw + Vector3(0, 0, dp * 0.5), top + hw + Vector3(0, 1.6, 0), top - hw + Vector3(0, 1.6, 0), Vector3(0, 0.6, 0.4).normalized(), Rect2(0, 0, w / 4.0, 1), Color(0.6, 0.6, 0.62))
		shed.quad(top - hw - Vector3(0, 0, dp * 0.5), top + hw - Vector3(0, 0, dp * 0.5), top + hw + Vector3(0, 1.6, 0), top - hw + Vector3(0, 1.6, 0), Vector3(0, 0.6, -0.4).normalized(), Rect2(0, 0, w / 4.0, 1), Color(0.55, 0.55, 0.58))
		fac.wall(Vector3(cx, 0, front_z + nz * 0.03), nrm, 4.0, 4.0, MB.atlas(31), Color(0.8, 0.8, 0.8))
		return
	var nb := maxi(1, int(round(w / 3.0)))
	var bw := w / nb
	var door_bay := rng.randi() % nb
	var trim := tint.darkened(0.25) if rng.randf() < 0.5 else Color(0.92, 0.9, 0.86)
	var gz := front_z - nz * (1.7 if colonnade else 0.0)      # recessed ground floor behind a colonnade
	for f in floors:
		for b in nb:
			var tile: int = u_tiles[rng.randi() % u_tiles.size()]
			var fz := front_z
			if f == 0:
				fz = gz
				tile = g_tile
				if shop and not arch in ["hotel", "workshop", "cornershop"]:
					tile = 4 + rng.randi() % 4
				if arch == "pete" and shop and b != door_bay:
					tile = 4 + rng.randi() % 4
				if b == door_bay and (not shop or nb >= 3) and not arch in ["govt", "school", "workshop", "godown"]:
					tile = 10
				if arch in ["godown"] and b != door_bay:
					tile = 15 if u_tiles[0] == 15 else 18
			elif arch in ["shoprow", "cornershop", "pete"] and rng.randf() < 0.14:
				tile = [11, 12, 13, 14, 25][rng.randi() % 5]
			var bx := cx + (-w * 0.5 + bw * (b + 0.5)) * (1.0 if nz > 0 else -1.0)
			fac.wall(Vector3(bx, f * FLOOR_H, fz), nrm, bw, FLOOR_H, MB.atlas(tile), tint)
			if f > 0 and rng.randf() < balcony:
				pc.box(Vector3(bx, f * FLOOR_H + 0.05, front_z + nz * 0.55), Vector3(bw - 0.3, 0.1, 1.1), trim)
				pc.box(Vector3(bx, f * FLOOR_H + 0.55, front_z + nz * 1.08), Vector3(bw - 0.3, 0.9, 0.05), trim.darkened(0.3) if rng.randf() < 0.5 else Color(0.2, 0.22, 0.2))
				if rng.randf() < 0.4:
					pc.box(Vector3(bx + rng.randf_range(-0.5, 0.5), f * FLOOR_H + 0.75, front_z + nz * 1.12), Vector3(0.7, 0.6, 0.03), Human.CLOTH[rng.randi() % Human.CLOTH.size()])
		if chajja and (f > 0 or not shop):
			pc.box(Vector3(cx, f * FLOOR_H + 2.5, front_z + nz * 0.28), Vector3(w - 0.2, 0.07, 0.56), trim)
		if f > 0 and arch in ["complex", "office", "lodge", "apartment", "govt"]:
			pc.box(Vector3(cx, f * FLOOR_H, front_z + nz * 0.08), Vector3(w, 0.22, 0.16), trim)      # floor band
	if colonnade:
		for b in nb + 1:
			pc.box(Vector3(cx - w * 0.5 + b * bw, 1.5, front_z - nz * 0.22), Vector3(0.42, 3.0, 0.42), trim)
		roof.flat(Vector3(cx, 0.16, front_z - nz * 0.85), w, 1.7, Rect2(0, 0, w / 3.0, 0.6), Color(0.72, 0.7, 0.66))
	if arch in ["complex", "office"]:
		for b in nb + 1:
			pc.box(Vector3(cx - w * 0.5 + b * bw, h * 0.5 + 1.5, front_z + nz * 0.1), Vector3(0.3, h - 3.0, 0.2), trim)   # pilasters
	# back and sides
	fac.wall(Vector3(cx, 0, back_z), -nrm, w, h, MB.atlas(12), tint.darkened(0.12))
	for s: float in [-1.0, 1.0]:
		var sx := cx + s * w * 0.5
		var sn := Vector3(s, 0, 0)
		var zc := (front_z + back_z) * 0.5
		if (corner == -1 and s < 0) or (corner == 1 and s > 0):
			var sb := maxi(1, int(round(dp / 3.0)))
			var sbw := dp / sb
			for f in floors:
				for b in sb:
					var t2: int = u_tiles[rng.randi() % u_tiles.size()] if (f > 0 and rng.randf() < 0.7) else ((4 + rng.randi() % 4) if (f == 0 and shop and rng.randf() < 0.5) else [11, 24, 25, 12][rng.randi() % 4])
					fac.wall(Vector3(sx, f * FLOOR_H, zc - dp * 0.5 + sbw * (b + 0.5)), sn, sbw, FLOOR_H, MB.atlas(t2), tint)
		else:
			fac.wall(Vector3(sx, 0, zc), sn, dp, h, MB.atlas([11, 13, 24][rng.randi() % 3]), tint.darkened(0.06))
			if rng.randf() < 0.3:          # bill-stickers have been here: film and election posters, some half torn
				for k in rng.randi_range(1, 3):
					var pi2 := rng.randi() % 8
					var torn := 0.5 if rng.randf() < 0.3 else 1.0
					hoard.wall(Vector3(sx + s * 0.03, 0.9 + (k % 2) * 0.75, zc - dp * 0.25 + k * 1.5), sn, 1.4 * torn, 0.7, Rect2((pi2 % 2) * 0.5, (pi2 / 2) * 0.25, 0.5 * torn, 0.25))
	# roof
	if sloped:
		var ridge := Vector3(cx, h + 1.5, centre.z)
		var tc := Color(0.62, 0.3, 0.2) if rng.randf() < 0.8 else Color(0.5, 0.5, 0.52)
		var ex := w * 0.5 + 0.4
		var ez := dp * 0.5 + 0.5
		pc.quad(Vector3(cx - ex, h, centre.z + ez), Vector3(cx + ex, h, centre.z + ez), ridge + Vector3(ex, 0, 0), ridge - Vector3(ex, 0, 0), Vector3(0, 0.7, 0.5).normalized(), Rect2(0, 0, 1, 1), tc)
		pc.quad(Vector3(cx - ex, h, centre.z - ez), Vector3(cx + ex, h, centre.z - ez), ridge + Vector3(ex, 0, 0), ridge - Vector3(ex, 0, 0), Vector3(0, 0.7, -0.5).normalized(), Rect2(0, 0, 1, 1), tc.darkened(0.1))
		for s: float in [-1.0, 1.0]:
			pc.quad(Vector3(cx + s * w * 0.5, h, centre.z - dp * 0.5), Vector3(cx + s * w * 0.5, h, centre.z + dp * 0.5), ridge + Vector3(s * w * 0.5, 0, 0), ridge + Vector3(s * w * 0.5, 0, 0), Vector3(s, 0, 0), Rect2(0, 0, 1, 1), tint.darkened(0.05))
	else:
		roof.flat(Vector3(cx, h, centre.z), w, dp, Rect2(0, 0, w / 6.0, dp / 6.0), Color(0.62, 0.6, 0.58))
		var pcol := tint.darkened(0.05)
		roof.wall(Vector3(cx, h, front_z), nrm, w, 0.8, Rect2(0, 0, w / 4.0, 0.2), pcol)
		roof.wall(Vector3(cx, h, front_z - nz * 0.15), -nrm, w, 0.8, Rect2(0, 0, w / 4.0, 0.2), pcol.darkened(0.15))
		if arch == "pete" or arch == "govt":      # shaped parapet with a centre pediment
			pc.box(Vector3(cx, h + 1.15, front_z - nz * 0.08), Vector3(minf(w * 0.5, 3.0), 0.7, 0.16), pcol)
		if stair:
			var tx := cx + (w * 0.5 - 1.5) * (1.0 if rng.randf() < 0.5 else -1.0)
			roof.box(Vector3(tx, h + 1.3, back_z + nz * 1.6), Vector3(2.6, 2.6, 3.0), tint.darkened(0.08), Rect2(0, 0, 0.6, 0.6))
		if rng.randf() < 0.65:
			var tk := Vector3(cx + rng.randf_range(-w * 0.25, w * 0.25), h, centre.z - nz * dp * 0.2)
			if rng.randf() < 0.5:
				for k in 4:
					pc.box(tk + Vector3((k % 2) * 1.0 - 0.5, 0.7, (k / 2) * 1.0 - 0.5), Vector3(0.12, 1.4, 0.12), Color(0.6, 0.6, 0.6))
				pc.box(tk + Vector3(0, 2.0, 0), Vector3(1.3, 1.2, 1.3), Color(0.08, 0.08, 0.09))
			else:
				pc.box(tk + Vector3(0, 0.75, 0), Vector3(1.6, 1.5, 1.6), Color(0.7, 0.68, 0.64))
		if rng.randf() < 0.45:                    # TV aerial
			var ap := Vector3(cx + rng.randf_range(-w * 0.3, w * 0.3), h, centre.z + nz * dp * 0.15)
			pc.box(ap + Vector3(0, 1.6, 0), Vector3(0.04, 3.2, 0.04), Color(0.6, 0.6, 0.62))
			for k in 4:
				pc.box(ap + Vector3(0, 2.4 + k * 0.22, 0), Vector3(1.1 - k * 0.18, 0.025, 0.025), Color(0.7, 0.7, 0.72))
		if arch in ["house", "apartment", "lodge"] and rng.randf() < 0.5:      # washing on the terrace
			var cl := Vector3(cx, h + 1.5, centre.z)
			pc.box(cl, Vector3(w * 0.6, 0.02, 0.02), Color(0.9, 0.9, 0.9))
			for k in rng.randi_range(2, 5):
				pc.box(cl + Vector3(-w * 0.25 + k * 0.9, -0.4, 0), Vector3(0.6, 0.8, 0.02), Human.CLOTH[rng.randi() % Human.CLOTH.size()])
	# shop fronts: signboards, awnings, light on the pavement, a spot to stand
	if shop:
		var ns := maxi(1, int(w / 4.5))
		for i in ns:
			var sxp := cx + (-w * 0.5 + (i + 0.5) * w / ns)
			var si := rng.randi() % SIGN_COUNT
			var uvr := Rect2((si % 4) * 0.25, (si / 4) * 0.125, 0.25, 0.125)
			var sw := minf(3.4, w / ns - 0.3)
			sg.wall(Vector3(sxp, 2.75 if not colonnade else 3.05, front_z + nz * (0.14 if not colonnade else 0.26)), nrm, sw, 0.85, uvr)
			if awning and rng.randf() < 0.75:
				var ac: Color = [Color(0.2, 0.4, 0.7), Color(0.7, 0.2, 0.18), Color(0.85, 0.75, 0.3), Color(0.2, 0.5, 0.3), Color(0.5, 0.5, 0.52)][rng.randi() % 5]
				var x0 := sxp - sw * 0.5
				var x1 := sxp + sw * 0.5
				pc.quad(Vector3(x0, 2.1, front_z + nz * 1.5), Vector3(x1, 2.1, front_z + nz * 1.5), Vector3(x1, 2.7, front_z + nz * 0.05), Vector3(x0, 2.7, front_z + nz * 0.05), Vector3(0, 0.9, nz * 0.4).normalized(), Rect2(0, 0, 1, 1), ac)
				pc.quad(Vector3(x0, 2.1, front_z + nz * 1.5), Vector3(x1, 2.1, front_z + nz * 1.5), Vector3(x1, 2.7, front_z + nz * 0.05), Vector3(x0, 2.7, front_z + nz * 0.05), Vector3(0, -0.9, -nz * 0.4).normalized(), Rect2(0, 0, 1, 1), ac.darkened(0.35))
			if rng.randf() < 0.3:                 # goods spilling onto the pavement
				for k in 3:
					pc.box(Vector3(sxp - 0.8 + k * 0.8, 0.3, front_z + nz * 0.5), Vector3(0.6, 0.6, 0.6), [Color(0.6, 0.45, 0.3), Color(0.3, 0.45, 0.6), Color(0.75, 0.7, 0.3)][k])
		g_shop.flat(Vector3(cx, 0.22, front_z + nz * 2.6), w + 2.0, 6.5)
		spots.append({"pos": Vector3(cx + rng.randf_range(-w * 0.3, w * 0.3), 0, front_z + nz * 1.0), "yaw": atan2(0.0, nz), "kind": "garage" if arch == "workshop" else ("eat" if arch == "hotel" else "shop")})
		if arch == "workshop":                    # a scooter up on its stand, tyres, an oil patch
			pc.flat(Vector3(cx, 0.06, front_z + nz * 1.6), 3.0, 2.2, Rect2(0, 0, 1, 1), Color(0.1, 0.09, 0.09))
			for k in 3:
				pc.wheel(Vector3(cx + w * 0.3, 0.14 + k * 0.2, front_z + nz * 0.8), 0.32, 0.18, Color(0.07, 0.07, 0.08), Basis(Vector3.FORWARD, PI * 0.5), 8)
		if arch == "hotel":
			for k in 2:
				pc.box(Vector3(cx - 1.2 + k * 2.4, 0.5, front_z + nz * 1.3), Vector3(0.6, 1.0, 0.6), Color(0.5, 0.5, 0.53))     # standing tables
	# compound, gate, porch, garden
	if compound and setback >= 2.0:
		var wz := front_z + nz * (setback - 0.25)
		var gate_x := cx + (rng.randf_range(-0.25, 0.25) * w)
		var wc := tint.lerp(Color(0.85, 0.83, 0.78), 0.6)
		var lw := (gate_x - 1.4) - (cx - w * 0.5)
		var rw := (cx + w * 0.5) - (gate_x + 1.4)
		if lw > 0.3:
			pc.box(Vector3(cx - w * 0.5 + lw * 0.5, 0.75, wz), Vector3(lw, 1.5, 0.22), wc)
		if rw > 0.3:
			pc.box(Vector3(cx + w * 0.5 - rw * 0.5, 0.75, wz), Vector3(rw, 1.5, 0.22), wc)
		fac.wall(Vector3(gate_x, 0, wz + nz * 0.02), nrm, 2.8, 2.0, MB.atlas(26), wc)
		fac.wall(Vector3(gate_x, 0, wz - nz * 0.02), -nrm, 2.8, 2.0, MB.atlas(26), wc)
		_boxes.append([Vector3(cx, 0.75, wz), Vector3(w, 1.5, 0.3)])
		if arch in ["house", "bungalow"]:
			var bxd := cx + (-w * 0.5 + bw * (door_bay + 0.5)) * (1.0 if nz > 0 else -1.0)
			pc.box(Vector3(bxd, 2.75, front_z + nz * 1.0), Vector3(bw + 0.6, 0.12, 2.0), trim)                 # porch slab
			for s: float in [-1.0, 1.0]:
				pc.box(Vector3(bxd + s * (bw * 0.5 + 0.1), 1.35, front_z + nz * 1.85), Vector3(0.2, 2.7, 0.2), trim)
			pc.box(Vector3(bxd, 0.12, front_z + nz * 0.5), Vector3(bw, 0.24, 1.0), Color(0.6, 0.2, 0.16))        # red-oxide step
			pc.box(Vector3(gate_x + 2.2, 0.45, front_z + nz * (setback * 0.5)), Vector3(0.45, 0.9, 0.45), Color(0.8, 0.5, 0.35))   # tulasi katte
			pc.box(Vector3(gate_x + 2.2, 1.1, front_z + nz * (setback * 0.5)), Vector3(0.35, 0.5, 0.35), Color(0.2, 0.45, 0.2))
			pc.flat(Vector3(gate_x, 0.07, wz + nz * 0.9), 1.1, 1.1, Rect2(0, 0, 1, 1), Color(0.95, 0.95, 0.92))              # rangoli at the gate
			pc.flat(Vector3(gate_x, 0.075, wz + nz * 0.9), 0.5, 0.5, Rect2(0, 0, 1, 1), Color(0.85, 0.2, 0.2))
			for k in rng.randi_range(1, 3):                                                                              # chappals left at the step
				pc.box(Vector3(bxd - 0.3 + k * 0.22, 0.27, front_z + nz * 1.05), Vector3(0.09, 0.03, 0.24), [Color(0.2, 0.3, 0.6), Color(0.3, 0.2, 0.15), Color(0.7, 0.2, 0.3)][k % 3])
			var wealth := rng.randf()
			if wealth < 0.5:
				pc.box(Vector3(bxd + bw * 0.5 + 0.5, 0.2, front_z + nz * 0.6), Vector3(0.34, 0.4, 0.34), Color(0.15, 0.35, 0.7))      # water bucket
				pc.box(Vector3(bxd + bw * 0.5 + 0.95, 0.15, front_z + nz * 0.6), Vector3(0.28, 0.3, 0.28), Color(0.7, 0.2, 0.2))
			else:
				for k in 3:
					pc.box(Vector3(cx - w * 0.4 + k * 0.5, 0.18, front_z + nz * 0.5), Vector3(0.3, 0.36, 0.3), Color(0.7, 0.4, 0.28))   # flower pots
					pc.box(Vector3(cx - w * 0.4 + k * 0.5, 0.5, front_z + nz * 0.5), Vector3(0.34, 0.34, 0.34), [Color(0.2, 0.45, 0.2), Color(0.8, 0.3, 0.4), Color(0.25, 0.5, 0.25)][k])
				pc.box(Vector3(cx + w * 0.3, 0.42, front_z + nz * 1.3), Vector3(0.5, 0.05, 0.5), Color(0.75, 0.15, 0.12))            # plastic chair
				pc.box(Vector3(cx + w * 0.3, 0.7, front_z + nz * 1.05), Vector3(0.5, 0.55, 0.05), Color(0.75, 0.15, 0.12))
			if rng.randf() < 0.4:                                                                                        # the old bicycle against the wall
				var by := Vector3(cx - w * 0.3, 0, wz - nz * 0.4)
				for sd3: float in [-0.5, 0.5]:
					pc.wheel(by + Vector3(sd3, 0.33, 0), 0.33, 0.03, Color(0.1, 0.1, 0.1), Basis(Vector3.UP, PI * 0.5), 8)
				pc.box(by + Vector3(0, 0.55, 0), Vector3(1.0, 0.04, 0.04), Color(0.2, 0.3, 0.25))
				pc.box(by + Vector3(-0.2, 0.75, 0), Vector3(0.04, 0.4, 0.04), Color(0.2, 0.3, 0.25))
			pc.box(Vector3(gate_x + 1.55, 1.3, wz + nz * 0.13), Vector3(0.32, 0.16, 0.02), Color(0.12, 0.12, 0.14))            # nameplate
			spots.append({"pos": Vector3(gate_x - 0.6, 0, wz + nz * 1.2), "yaw": atan2(0.0, nz), "kind": "sweep"})
			if rng.randf() < 0.5:
				spots.append({"pos": Vector3(gate_x + 3.0, 0, wz + nz * 2.2), "yaw": rng.randf() * TAU, "kind": "play"})
				spots.append({"pos": Vector3(gate_x + 4.2, 0, wz + nz * 2.6), "yaw": rng.randf() * TAU, "kind": "play"})
			if _tv == null and rng.randf() < 0.35:
				_tv = Vector3(cx, 1.5, front_z - nz * 1.0)
			if rng.randf() < 0.5:
				_palms.append([Vector3(cx + w * 0.38, 0, front_z + nz * setback * 0.5), rng.randf_range(0.9, 1.3)])
			elif rng.randf() < 0.6:
				_trees.append([Vector3(cx - w * 0.36, 0, front_z + nz * setback * 0.5), rng.randf_range(0.8, 1.2)])
		if arch == "school":
			pc.box(Vector3(cx - w * 0.3, 3.5, front_z + nz * 2.5), Vector3(0.08, 7.0, 0.08), Color(0.8, 0.8, 0.8))       # flagpole
			pc.box(Vector3(cx, 2.9, front_z + nz * 0.9), Vector3(w, 0.12, 1.8), trim)                                   # corridor roof
			for b in nb + 1:
				pc.box(Vector3(cx - w * 0.5 + b * bw, 1.4, front_z + nz * 1.7), Vector3(0.22, 2.8, 0.22), trim)
			spots.append({"pos": Vector3(gate_x, 0, wz + nz * 1.5), "yaw": atan2(0.0, -nz), "kind": "school"})
	# rooftop hoarding
	if arch in ["complex", "lodge", "shoprow", "office"] and floors >= 3 and rng.randf() < 0.35 and w >= 8.0:
		var hi := rng.randi() % 8
		var huv := Rect2((hi % 2) * 0.5, (hi / 2) * 0.25, 0.5, 0.25)
		hoard.wall(Vector3(cx, h + 1.4, front_z - nz * 0.5), nrm, 7.0, 3.5, huv)
		pc.box(Vector3(cx - 2.5, h + 0.7, front_z - nz * 0.7), Vector3(0.15, 1.4, 0.15), Color(0.2, 0.2, 0.2))
		pc.box(Vector3(cx + 2.5, h + 0.7, front_z - nz * 0.7), Vector3(0.15, 1.4, 0.15), Color(0.2, 0.2, 0.2))
		pc.wall(Vector3(cx, h + 1.4, front_z - nz * 0.52), -nrm, 7.0, 3.5, Rect2(0, 0, 1, 1), Color(0.3, 0.28, 0.26))

func _bus_stop(pc: MB, st: Dictionary, nm: String) -> void:
	var d: Vector2 = st.dir
	var basis := Basis(Vector3.UP, atan2(d.x, d.y))
	var p := Vector3(st.pos.x, 0, st.pos.y)
	for s: float in [-1.0, 1.0]:
		pc.box(p + basis * Vector3(0.5, 1.3, s * 2.2), Vector3(0.1, 2.6, 0.1), Color(0.25, 0.3, 0.5))
	pc.box(p + basis * Vector3(0.1, 2.65, 0), Vector3(1.8, 0.1, 5.0), Color(0.75, 0.2, 0.15), Rect2(0, 0, 1, 1), true, basis)
	pc.box(p + basis * Vector3(0.45, 0.45, 0), Vector3(0.4, 0.08, 3.6), Color(0.45, 0.33, 0.22), Rect2(0, 0, 1, 1), true, basis)
	for k in 4:
		spots.append({"pos": p + basis * Vector3(-0.6 - (k % 2) * 0.7, 0, -1.6 + k * 1.0), "yaw": atan2(d.x, d.y) + PI * 0.5 + PI, "kind": "wait"})
	var lb := Label3D.new()
	lb.text = "BUS STOP\n" + nm.to_upper()
	lb.font_size = 56
	lb.pixel_size = 0.006
	lb.modulate = Color(1, 0.95, 0.5)
	lb.outline_modulate = Color(0.1, 0.1, 0.3)
	lb.position = p + basis * Vector3(0.1, 3.1, 0)
	lb.rotation.y = atan2(d.x, d.y) - PI * 0.5
	lb.visibility_range_end = 70.0
	lb.double_sided = true
	add_child(lb)

func _props() -> void:
	if not _poles.is_empty():
		var pole := CylinderMesh.new()
		pole.top_radius = 0.07
		pole.bottom_radius = 0.11
		pole.height = 6.0
		pole.radial_segments = 6
		pole.rings = 1
		pole.material = Mats.col(Color(0.55, 0.56, 0.55))
		var xf: Array = []
		for t in _poles:
			xf.append(t.translated(Vector3(0, 3.0, 0)))
		_mm(pole, xf)
		var head := BoxMesh.new()
		head.size = Vector3(0.9, 0.14, 0.3)
		head.material = Mats.lamp()
		var hx: Array = []
		for lp in lamps:
			hx.append(Transform3D(Basis.IDENTITY, lp + Vector3(0, 0.2, 0)))
		_mm(head, hx)
	if not _epoles.is_empty():
		var ep := CylinderMesh.new()
		ep.top_radius = 0.09
		ep.bottom_radius = 0.13
		ep.height = 7.0
		ep.radial_segments = 5
		ep.rings = 1
		ep.material = Mats.col(Color(0.5, 0.49, 0.46))
		var ex: Array = []
		for q in _epoles:
			ex.append(Transform3D(Basis.IDENTITY, q + Vector3(0, 3.5, 0)))
		_mm(ep, ex)
	if not _palms.is_empty():
		var pt := CylinderMesh.new()
		pt.top_radius = 0.11
		pt.bottom_radius = 0.2
		pt.height = 8.0
		pt.radial_segments = 5
		pt.rings = 1
		pt.material = Mats.col(Color(0.42, 0.36, 0.28))
		var fr := SphereMesh.new()
		fr.radius = 2.4
		fr.height = 1.3
		fr.radial_segments = 7
		fr.rings = 2
		fr.material = Mats.col(Color(0.16, 0.34, 0.14), 1.0)
		var px: Array = []
		var fx: Array = []
		for q in _palms:
			var sc: float = q[1]
			px.append(Transform3D(Basis(Vector3.RIGHT, 0.06).scaled(Vector3(1, sc, 1)), q[0] + Vector3(0, 4.0 * sc, 0)))
			fx.append(Transform3D(Basis.IDENTITY, q[0] + Vector3(0, 8.0 * sc, 0.3)))
		_mm(pt, px)
		_mm(fr, fx)
	if not _trees.is_empty():
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.22
		trunk.bottom_radius = 0.34
		trunk.height = 4.0
		trunk.radial_segments = 6
		trunk.rings = 1
		trunk.material = Mats.col(Color(0.33, 0.25, 0.18))
		var can := SphereMesh.new()
		can.radius = 3.2
		can.height = 4.2
		can.radial_segments = 8
		can.rings = 4
		can.material = Mats.col(Color(0.2, 0.38, 0.18), 1.0)
		var tx: Array = []
		var cxf: Array = []
		for t in _trees:
			var s: float = t[1]
			tx.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), t[0] + Vector3(0, 2.0 * s, 0)))
			cxf.append(Transform3D(Basis(Vector3.UP, s * 9.0).scaled(Vector3(s, s * 0.9, s)), t[0] + Vector3(0, 5.2 * s, 0)))
		_mm(trunk, tx)
		_mm(can, cxf)

func _mm(mesh: Mesh, xforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _collision() -> void:
	if not _walk.is_empty() or not _walk_boxes.is_empty():
		var wb := Ground.new_body()
		add_child(wb)
		for w in _walk:
			Ground.strip_shape(wb, w[0], w[1], w[2], w[3])
		for bx in _walk_boxes:
			Ground.box_shape(wb, bx[0], bx[1])
	if _boxes.is_empty() and _trees.is_empty():
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	for b in _boxes:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = b[1]
		cs.shape = sh
		cs.position = b[0]
		body.add_child(cs)
	for t in _trees:
		var cs2 := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.35
		cy.height = 4.0
		cs2.shape = cy
		cs2.position = t[0] + Vector3(0, 2, 0)
		body.add_child(cs2)
