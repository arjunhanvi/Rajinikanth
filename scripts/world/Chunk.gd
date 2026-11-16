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
var _trees: Array = []      # [pos: Vector3, scale: float]
var _poles: Array = []      # Transform3D

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

	g_ground.flat(Vector3(mid.x, 0, mid.y), City.CHUNK, City.CHUNK, Rect2(0, 0, 12, 12))
	# --- side-street grid ---
	for i in 2:
		for j in 2:
			var gx := ox + i * City.GRID
			var gz := oz + j * City.GRID
			if City.district(Vector2(gx, gz + 25.0)).kind != "rural":
				g_street.strip(Vector3(gx, 0.04, gz), Vector3(gx, 0.04, gz + City.GRID), City.STREET_W, 8.0)
			if City.district(Vector2(gx + 25.0, gz)).kind != "rural":
				g_street.strip(Vector3(gx, 0.045, gz), Vector3(gx + City.GRID, 0.045, gz), City.STREET_W, 8.0)
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
			for t in rng.randi_range(1, 4):
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
				gap = rng.randf_range(0.5, 2.0)
			elif kind == "cant":
				gap = 3.0
			var lot := Rect2(x, front_z if row == 1 else front_z, w, depth)
			var cz := front_z - nz * depth * 0.5
			var rect := Rect2(x, cz - depth * 0.5, w, depth)
			var skip := rng.randf() > float(d.density) + 0.15
			if not skip:
				for sp in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y), rect.get_center()]:
					if City.on_arterial(sp, 3.6):
						skip = true
						break
			if not skip and City.rect_hits_zone(rect):
				skip = true
			if skip:
				if kind in ["res", "cant", "out"] and rng.randf() < 0.4:
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

func _building(r: Rect2, nz: float, kind: String, corner: int, fac: MB, sg: MB, roof: MB, hoard: MB, shed: MB, pc: MB) -> void:
	var floors := 1
	var shop_p := 0.2
	match kind:
		"old": floors = rng.randi_range(2, 3); shop_p = 0.85
		"com": floors = rng.randi_range(2, 5) + (2 if rng.randf() < 0.12 else 0); shop_p = 0.9
		"gov": floors = rng.randi_range(2, 4); shop_p = 0.15
		"res": floors = rng.randi_range(1, 3); shop_p = 0.22
		"out": floors = rng.randi_range(1, 2); shop_p = 0.3
		"cant": floors = rng.randi_range(1, 2); shop_p = 0.0
	var tint: Color = WALLS[rng.randi() % WALLS.size()]
	if kind == "old":
		tint = tint.darkened(0.08)
	var setback := 0.0
	if kind == "cant":
		setback = 6.0
	elif kind == "res":
		setback = rng.randf_range(0.0, 2.5)
	var w := r.size.x
	var dp := r.size.y - setback
	var cx := r.position.x + w * 0.5
	var front_z := (r.position.y + setback) if nz < 0 else (r.end.y - setback)
	var back_z := front_z - nz * dp
	var h := floors * FLOOR_H
	var centre := Vector3(cx, h * 0.5, (front_z + back_z) * 0.5)
	_boxes.append([centre, Vector3(w, h, dp)])
	if kind == "ind":
		h = rng.randf_range(5.5, 8.0)
		centre.y = h * 0.5
		_boxes[-1] = [centre, Vector3(w, h, dp)]
		shed.box(centre, Vector3(w, h, dp), tint.lerp(Color(0.8, 0.82, 0.85), 0.6), Rect2(0, 0, w / 4.0, 1), false)
		# saw-tooth roof
		var hw := Vector3(w * 0.5, 0, 0)
		var top := Vector3(cx, h, centre.z)
		shed.quad(top - hw + Vector3(0, 0, dp * 0.5), top + hw + Vector3(0, 0, dp * 0.5), top + hw + Vector3(0, 1.6, 0), top - hw + Vector3(0, 1.6, 0), Vector3(0, 0.6, 0.4).normalized(), Rect2(0, 0, w / 4.0, 1), Color(0.6, 0.6, 0.62))
		shed.quad(top - hw - Vector3(0, 0, dp * 0.5), top + hw - Vector3(0, 0, dp * 0.5), top + hw + Vector3(0, 1.6, 0), top - hw + Vector3(0, 1.6, 0), Vector3(0, 0.6, -0.4).normalized(), Rect2(0, 0, w / 4.0, 1), Color(0.55, 0.55, 0.58))
		return
	var nrm := Vector3(0, 0, nz)
	var nb := maxi(1, int(round(w / 3.0)))
	var bw := w / nb
	var shop := rng.randf() < shop_p
	var win := rng.randi() % 4
	var door_bay := rng.randi() % nb
	for f in floors:
		for b in nb:
			var tile := win
			if f == 0:
				if shop:
					tile = 4 + rng.randi() % 4
					if nb >= 3 and b == door_bay:
						tile = 10
				else:
					tile = 10 if b == door_bay else (1 if kind != "gov" else 2)
			elif rng.randf() < 0.18:
				tile = [11, 12, 13, 14][rng.randi() % 4]
			# bays run left-to-right as seen from the front
			var bx := cx + (-w * 0.5 + bw * (b + 0.5)) * (1.0 if nz > 0 else -1.0)
			fac.wall(Vector3(bx, f * FLOOR_H, front_z), nrm, bw, FLOOR_H, MB.atlas(tile), tint)
	# back + sides
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
					var tile2 := win if (f > 0 and rng.randf() < 0.7) else (4 + rng.randi() % 4 if (f == 0 and shop and rng.randf() < 0.6) else 11)
					fac.wall(Vector3(sx, f * FLOOR_H, zc - dp * 0.5 + sbw * (b + 0.5)), sn, sbw, FLOOR_H, MB.atlas(tile2), tint)
		else:
			fac.wall(Vector3(sx, 0, zc), sn, dp, h, MB.atlas(11 if rng.randf() < 0.5 else 13), tint.darkened(0.06))
	# roof
	if kind == "cant" or (kind in ["res", "out"] and floors == 1 and rng.randf() < 0.45):
		var ridge := Vector3(cx, h + 1.5, centre.z)
		var tc := Color(0.62, 0.3, 0.2) if rng.randf() < 0.8 else Color(0.5, 0.5, 0.52)
		var ex := w * 0.5 + 0.4
		var ez := dp * 0.5 + 0.4
		pc.quad(Vector3(cx - ex, h, centre.z + ez), Vector3(cx + ex, h, centre.z + ez), ridge + Vector3(ex, 0, 0), ridge - Vector3(ex, 0, 0), Vector3(0, 0.7, 0.5).normalized(), Rect2(0, 0, 1, 1), tc)
		pc.quad(Vector3(cx - ex, h, centre.z - ez), Vector3(cx + ex, h, centre.z - ez), ridge + Vector3(ex, 0, 0), ridge - Vector3(ex, 0, 0), Vector3(0, 0.7, -0.5).normalized(), Rect2(0, 0, 1, 1), tc.darkened(0.1))
		if kind == "cant":   # compound wall + garden tree
			var wz := front_z + nz * (setback - 0.3)
			pc.box(Vector3(cx, 0.6, wz), Vector3(w - 3.0, 1.2, 0.25), Color(0.85, 0.83, 0.78))
			_trees.append([Vector3(cx + rng.randf_range(-w * 0.3, w * 0.3), 0, front_z + nz * setback * 0.5), rng.randf_range(1.0, 1.7)])
	else:
		roof.flat(Vector3(cx, h, centre.z), w, dp, Rect2(0, 0, w / 6.0, dp / 6.0), Color(0.62, 0.6, 0.58))
		roof.wall(Vector3(cx, h, front_z), nrm, w, 0.7, Rect2(0, 0, w / 4.0, 0.2), tint.darkened(0.05))   # parapet
		if rng.randf() < 0.6:   # the black rooftop water tank
			pc.box(Vector3(cx + rng.randf_range(-w * 0.25, w * 0.25), h + 0.9, centre.z - nz * dp * 0.2), Vector3(1.3, 1.4, 1.3), Color(0.08, 0.08, 0.09))
	# shop signboards
	if shop:
		var ns := maxi(1, int(w / 4.5))
		for i in ns:
			var sxp := cx + (-w * 0.5 + (i + 0.5) * w / ns)
			var si := rng.randi() % SIGN_COUNT
			var uvr := Rect2((si % 4) * 0.25, (si / 4) * 0.125, 0.25, 0.125)
			sg.wall(Vector3(sxp, 2.72, front_z + nz * 0.14), nrm, minf(3.4, w / ns - 0.3), 0.85, uvr)
	# rooftop hoarding
	if kind in ["com", "old", "gov"] and floors >= 3 and rng.randf() < 0.28 and w >= 8.0:
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
