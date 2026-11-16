class_name Landmarks
extends RefCounted
## Handcrafted places: the starting neighbourhood's shops and the city's landmarks.
## Each builder returns a Node3D with merged meshes, collision and signage.

static func build(z: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "LM_" + str(z.id)
	var ctx := {"root": root, "vc": MB.new(), "fac": MB.new(), "gr": MB.new(), "con": MB.new(), "wat": MB.new(), "trees": [], "solids": []}
	if z.kind == "site":
		_site(ctx, z.id, City.sites[z.id])
	else:
		var r: Rect2 = z.rect
		match z.kind:
			"busstation": _busstation(ctx, r)
			"railstation": _railstation(ctx, r)
			"vidhana": _vidhana(ctx, r)
			"market": _market(ctx, r)
			"park": _park(ctx, r, false)
			"park2": _park(ctx, r, true)
			"lake": _lake(ctx, r)
			"temple": _temple(ctx, r)
			"airport": _airport(ctx, r)
	var m := ArrayMesh.new()
	ctx.vc.add_to(m, Mats.vcol())
	ctx.fac.add_to(m, Mats.facade())
	ctx.gr.add_to(m, Mats.grass())
	ctx.con.add_to(m, Mats.concrete())
	ctx.wat.add_to(m, Mats.water())
	if m.get_surface_count() > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		root.add_child(mi)
	_finish(ctx)
	return root

static func _finish(ctx: Dictionary) -> void:
	var root: Node3D = ctx.root
	var body := StaticBody3D.new()
	root.add_child(body)
	for s in ctx.solids:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = s[1]
		cs.shape = sh
		cs.position = s[0]
		if s.size() > 2:
			cs.rotation.y = s[2]
		body.add_child(cs)
	if ctx.trees.is_empty():
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.4
	trunk.height = 4.0
	trunk.radial_segments = 6
	trunk.rings = 1
	trunk.material = Mats.col(Color(0.33, 0.25, 0.18))
	var can := SphereMesh.new()
	can.radius = 3.4
	can.height = 4.6
	can.radial_segments = 8
	can.rings = 4
	can.material = Mats.col(Color(0.18, 0.36, 0.16), 1.0)
	var red := SphereMesh.new()
	red.radius = 3.0
	red.height = 3.6
	red.radial_segments = 8
	red.rings = 4
	red.material = Mats.col(Color(0.75, 0.25, 0.12), 1.0)   # gulmohar in bloom
	for pair in [[trunk, 0], [can, 1], [red, 2]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[0]
		var list: Array = []
		for i in ctx.trees.size():
			var t = ctx.trees[i]
			var s: float = t[1]
			if pair[1] == 0:
				list.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), t[0] + Vector3(0, 2.0 * s, 0)))
			elif (pair[1] == 1) == (i % 6 != 0):
				list.append(Transform3D(Basis(Vector3.UP, i * 1.7).scaled(Vector3(s, s * 0.9, s)), t[0] + Vector3(0, 5.4 * s, 0)))
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		root.add_child(mi)

static func label(ctx: Dictionary, text: String, pos: Vector3, yaw: float, size := 64, colour := Color(1, 0.9, 0.3), bg := Color(0.5, 0.05, 0.05)) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = size
	lb.pixel_size = 0.008
	lb.outline_size = 14
	lb.modulate = colour
	lb.outline_modulate = bg
	lb.position = pos
	lb.rotation.y = yaw
	lb.visibility_range_end = 90.0
	ctx.root.add_child(lb)

static func solid(ctx: Dictionary, centre: Vector3, size: Vector3, c: Color, yaw := 0.0) -> void:
	ctx.vc.box(centre, size, c, Rect2(0, 0, 1, 1), true, Basis(Vector3.UP, yaw))
	ctx.solids.append([centre, size, yaw])

static func v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)

# ------------------------------------------------------------------ small sites
static func _site(ctx: Dictionary, id: String, s: Dictionary) -> void:
	var fwd: Vector2 = s.fwd
	var f3 := Vector3(fwd.x, 0, fwd.y)
	var right := Vector3.UP.cross(f3)
	var yaw := atan2(fwd.x, fwd.y)
	var basis := Basis(Vector3.UP, yaw)
	var c := v3(s.centre)
	var w: float = s.w
	var d: float = s.d
	var front := v3(s.front)
	var vc: MB = ctx.vc
	var fac: MB = ctx.fac
	var type: String = s.type
	var h := 3.2
	var tint := Color(0.9, 0.86, 0.72)
	var sign_col := Color(1, 0.9, 0.3)
	var sign_bg := Color(0.55, 0.05, 0.05)
	var text: String = str(s.name).to_upper()
	match type:
		"tea":
			# open-fronted stall: back wall, tin roof, counter, benches, kettle stove
			vc.box(c - f3 * (d * 0.5 - 0.15) + Vector3(0, 1.4, 0), Vector3(w, 2.8, 0.3), Color(0.55, 0.62, 0.7), Rect2(0, 0, 1, 1), true, basis)
			for sd: float in [-1.0, 1.0]:
				vc.box(c + right * sd * (w * 0.5 - 0.1) + Vector3(0, 1.4, 0), Vector3(0.2, 2.8, d), Color(0.5, 0.57, 0.66), Rect2(0, 0, 1, 1), true, basis)
			vc.box(c + f3 * 0.6 + Vector3(0, 2.9, 0), Vector3(w + 1.0, 0.12, d + 2.2), Color(0.42, 0.44, 0.47), Rect2(0, 0, 1, 1), true, basis)
			solid(ctx, front - f3 * 1.2 + Vector3(0, 0.5, 0), Vector3(w * 0.6, 1.0, 0.8), Color(0.45, 0.3, 0.2), yaw)
			vc.box(front - f3 * 1.2 + right * 1.2 + Vector3(0, 1.2, 0), Vector3(0.45, 0.4, 0.45), Color(0.75, 0.75, 0.78), Rect2(0, 0, 1, 1), true, basis)   # kettle
			vc.box(front - f3 * 1.2 - right * 1.0 + Vector3(0, 1.2, 0), Vector3(0.9, 0.35, 0.5), Color(0.85, 0.75, 0.5, 1), Rect2(0, 0, 1, 1), true, basis)   # bun tray
			for sd: float in [-1.0, 1.0]:
				vc.box(front + f3 * 1.0 + right * sd * (w * 0.5 + 0.2) + Vector3(0, 0.45, 0), Vector3(0.4, 0.08, 2.2), Color(0.4, 0.28, 0.18), Rect2(0, 0, 1, 1), true, basis)
			ctx.solids.append([c - f3 * (d * 0.5 - 0.15) + Vector3(0, 1.4, 0), Vector3(w, 2.8, 0.3), yaw])
			label(ctx, "NANJAPPA TEA STALL\nBY-TWO COFFEE  BUN  BEEDI", front + Vector3(0, 3.35, 0) + f3 * 1.6, yaw, 44)
			return
		"std":
			tint = Color(0.98, 0.88, 0.3)
			sign_col = Color(0.1, 0.1, 0.5)
			sign_bg = Color(1, 0.9, 0.2)
			text = "S.T.D  -  I.S.D  -  P.C.O\nLOCAL CALL Rs. 1"
		"home":
			h = 6.4
			tint = Color(0.78, 0.86, 0.8)
			text = "LAKSHMI VATARA\nROOMS FOR BACHELORS"
		"food":
			tint = Color(0.95, 0.95, 0.9)
			sign_bg = Color(0.1, 0.4, 0.15)
			text = "HOTEL DWARAKA DARSHINI\nIDLI VADA DOSA - STANDING ONLY"
		"bar":
			tint = Color(0.45, 0.2, 0.2)
			h = 3.6
			text = str(s.name).to_upper() + "\nA/C  -  FAMILY ROOM UPSTAIRS"
		"police":
			tint = Color(0.82, 0.25, 0.2)
			h = 4.0
			sign_col = Color.WHITE
			sign_bg = Color(0.1, 0.15, 0.5)
		"tailor":
			tint = Color(0.75, 0.82, 0.95)
			text = "NEW MODERN TAILORS\nSHIRTING - SUITING - READYMADES"
		"dealer":
			tint = Color(0.9, 0.9, 0.92)
			text = "SRI BALAJI AUTO CONSULTANTS\nBUYING & SELLING - FINANCE ARRANGED"
		"godown":
			tint = Color(0.6, 0.55, 0.45)
			h = 5.0
			text = "S.T. THIMMAIAH & SONS\nFLOWER MERCHANTS"
		"cinema":
			tint = Color(0.92, 0.8, 0.45)
			h = 11.0
			text = "SANGAM TALKIES"
		"parlour":
			tint = Color(0.3, 0.3, 0.42)
			text = "ANTHONY'S VIDEO PARLOUR\nNEW ENGLISH - HINDI - TAMIL"
		"office":
			h = 6.4
			tint = Color(0.9, 0.85, 0.7) if id != "knv" else Color(0.7, 0.85, 0.75)
		"factory":
			h = 7.0
			tint = Color(0.6, 0.62, 0.66)
		"house":
			tint = Color(0.95, 0.8, 0.82)
			text = ""
		"property":
			h = 6.4
			tint = Color(0.8, 0.9, 0.95)
			text = "FLAT FOR SALE\nCONTACT: OWNER"
	var body_c := c + Vector3(0, h * 0.5, 0)
	ctx.solids.append([body_c, Vector3(w, h, d), yaw])
	# front face from facade tiles, the rest plain
	var nb := maxi(1, int(round(w / 3.0)))
	var bw := w / nb
	var floors := maxi(1, int(round(h / 3.2)))
	var fh := h / floors
	for f in floors:
		for b in nb:
			var tile := 0
			if f == 0:
				tile = 10 if b == nb / 2 else (4 + (b % 4) if type in ["food", "tailor", "std", "dealer", "parlour"] else (2 if type in ["police", "office", "factory"] else 1))
				if type in ["godown", "cinema"] and b != nb / 2:
					tile = 9
			else:
				tile = [0, 3, 2, 1][(b + f) % 4] if type != "cinema" else 12
			fac.wall(front + right * (-w * 0.5 + bw * (b + 0.5)) + Vector3(0, f * fh, 0), f3, bw, fh, MB.atlas(tile), tint)
	fac.wall(front - f3 * d, -f3, w, h, MB.atlas(12), tint.darkened(0.1))
	fac.wall(c + right * w * 0.5, right, d, h, MB.atlas(11), tint.darkened(0.05))
	fac.wall(c - right * w * 0.5, -right, d, h, MB.atlas(13), tint.darkened(0.05))
	ctx.con.quad(c + Vector3(0, h, 0) - right * w * 0.5 + f3 * d * 0.5, c + Vector3(0, h, 0) + right * w * 0.5 + f3 * d * 0.5, c + Vector3(0, h, 0) + right * w * 0.5 - f3 * d * 0.5, c + Vector3(0, h, 0) - right * w * 0.5 - f3 * d * 0.5, Vector3.UP, Rect2(0, 0, 2, 2), Color(0.6, 0.58, 0.56))
	if text != "":
		vc.box(front + f3 * 0.12 + Vector3(0, minf(h - 0.6, 3.25), 0), Vector3(minf(w - 0.6, 9.0), 1.1, 0.1), sign_bg, Rect2(0, 0, 1, 1), true, basis)
		label(ctx, text, front + f3 * 0.2 + Vector3(0, minf(h - 0.6, 3.25), 0), yaw, 40 if text.length() > 30 else 56, sign_col, sign_bg.darkened(0.3))
	match type:
		"cinema":
			vc.box(front + f3 * 0.3 + Vector3(0, 7.5, 0), Vector3(12, 5, 0.2), Color(0.5, 0.05, 0.05), Rect2(0, 0, 1, 1), true, basis)
			label(ctx, "NOW SHOWING\nBENKI BASAVA\n4 SHOWS DAILY", front + f3 * 0.45 + Vector3(0, 7.5, 0), yaw, 90)
			vc.box(front + f3 * 2.0 + Vector3(0, 3.6, 0), Vector3(w, 0.25, 4.0), Color(0.8, 0.7, 0.4), Rect2(0, 0, 1, 1), true, basis)
		"police":
			vc.box(front + f3 * 1.5 + Vector3(0, 3.0, 0), Vector3(6, 0.2, 3.0), Color(0.8, 0.25, 0.2), Rect2(0, 0, 1, 1), true, basis)
			for sd: float in [-1.0, 1.0]:
				vc.box(front + f3 * 2.8 + right * sd * 2.8 + Vector3(0, 1.5, 0), Vector3(0.25, 3.0, 0.25), Color.WHITE, Rect2(0, 0, 1, 1), true, basis)
		"dealer":
			vc.box(front + f3 * 3.0 + Vector3(0, 3.4, 0), Vector3(w, 0.1, 6.0), Color(0.3, 0.45, 0.7), Rect2(0, 0, 1, 1), true, basis)
		"home":
			vc.box(front + f3 * 0.6 + Vector3(0, 3.2, 0), Vector3(w, 0.15, 1.2), Color(0.7, 0.7, 0.68), Rect2(0, 0, 1, 1), true, basis)   # corridor balcony
			vc.box(front + f3 * 1.15 + Vector3(0, 3.7, 0), Vector3(w, 0.9, 0.06), Color(0.3, 0.35, 0.3), Rect2(0, 0, 1, 1), true, basis)
		"godown":
			for i in 5:   # flower baskets by the door
				var cc: Color = [Color(1, 0.6, 0.1), Color(1, 0.9, 0.2), Color(0.9, 0.2, 0.3), Color(1, 1, 1)][i % 4]
				vc.box(front + f3 * 1.0 + right * (-4.0 + i * 2.0) + Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 0.9), cc, Rect2(0, 0, 1, 1), true, basis)
		"factory":
			solid(ctx, c - right * (w * 0.5 - 2.0) - f3 * (d * 0.5 - 2.0) + Vector3(0, 9.0, 0), Vector3(1.6, 18.0, 1.6), Color(0.5, 0.3, 0.25))   # chimney

# ------------------------------------------------------------------ landmarks
static func _slab(ctx: Dictionary, r: Rect2, mb_key: String, uvs := 10.0, c := Color.WHITE, y := 0.13) -> void:
	ctx[mb_key].flat(Vector3(r.get_center().x, y, r.get_center().y), r.size.x, r.size.y, Rect2(0, 0, r.size.x / uvs, r.size.y / uvs), c)

static func _scatter_trees(ctx: Dictionary, r: Rect2, n: int, seed_v: int, avoid: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in n:
		var p := Vector2(rng.randf_range(r.position.x + 3, r.end.x - 3), rng.randf_range(r.position.y + 3, r.end.y - 3))
		var ok := true
		for a in avoid:
			if a.has_point(p):
				ok = false
		if ok:
			ctx.trees.append([v3(p), rng.randf_range(0.9, 1.8)])

static func _busstation(ctx: Dictionary, r: Rect2) -> void:
	_slab(ctx, r, "con", 8.0, Color(0.78, 0.77, 0.75))
	var vc: MB = ctx.vc
	# four long platforms with tin shelters, running north-south
	for i in 4:
		var x := r.position.x + 20.0 + i * 16.0
		var zc := r.get_center().y - 6.0
		vc.box(Vector3(x, 0.28, zc), Vector3(4.0, 0.3, 52.0), Color(0.7, 0.69, 0.66))
		vc.box(Vector3(x, 3.4, zc), Vector3(5.2, 0.14, 52.0), Color(0.35, 0.42, 0.5))
		for k in 7:
			solid(ctx, Vector3(x, 1.8, zc - 24.0 + k * 8.0), Vector3(0.22, 3.2, 0.22), Color(0.85, 0.85, 0.8))
		for k in 4:
			vc.box(Vector3(x, 0.75, zc - 18.0 + k * 12.0), Vector3(0.5, 0.08, 3.0), Color(0.45, 0.33, 0.22))   # benches
		label(ctx, "PLATFORM %d" % (i + 1), Vector3(x, 3.9, zc + 26.2), 0.0, 48, Color.WHITE, Color(0.1, 0.2, 0.5))
	# depot / traffic controller's office by the south gate
	var oc := Vector3(r.position.x + 12.0, 1.7, r.end.y - 14.0)
	solid(ctx, oc, Vector3(8.0, 3.4, 6.0), Color(0.85, 0.8, 0.65))
	vc.box(oc + Vector3(4.05, 0.2, 0), Vector3(0.1, 1.4, 2.4), Color(0.2, 0.25, 0.3))
	label(ctx, "B.C.T.S. DEPOT No. 2\nTRAFFIC CONTROLLER", oc + Vector3(4.15, 1.9, 0), PI * 0.5, 40, Color(1, 1, 1), Color(0.5, 0.1, 0.1))
	# entrance arch on K.G. Road
	var gz := r.end.y - 1.0
	var gx := r.get_center().x
	for sd: float in [-1.0, 1.0]:
		solid(ctx, Vector3(gx + sd * 9.0, 3.0, gz), Vector3(1.2, 6.0, 1.2), Color(0.8, 0.3, 0.25))
	vc.box(Vector3(gx, 6.6, gz), Vector3(20.0, 1.6, 1.0), Color(0.8, 0.3, 0.25))
	label(ctx, "KEMPEGOWDA BUS STATION", Vector3(gx, 6.6, gz + 0.56), 0.0, 110, Color(1, 0.95, 0.6), Color(0.3, 0.05, 0.05))
	# low boundary wall (north + east), leaving gates open on the south and west
	solid(ctx, Vector3(r.get_center().x, 0.7, r.position.y + 0.3), Vector3(r.size.x, 1.4, 0.4), Color(0.75, 0.73, 0.7))
	solid(ctx, Vector3(r.end.x - 0.3, 0.7, r.get_center().y), Vector3(0.4, 1.4, r.size.y), Color(0.75, 0.73, 0.7))

static func _railstation(ctx: Dictionary, r: Rect2) -> void:
	_slab(ctx, r, "con", 8.0, Color(0.74, 0.73, 0.7))
	var c := r.get_center()
	var w := r.size.x - 16.0
	var body := Vector3(c.x, 4.5, c.y - 6.0)
	ctx.solids.append([body, Vector3(w, 9.0, 14.0)])
	var nb := int(w / 4.0)
	var tint := Color(0.93, 0.83, 0.55)
	for b in nb:
		for f in 2:
			ctx.fac.wall(Vector3(c.x - w * 0.5 + (b + 0.5) * w / nb, f * 4.5, c.y + 1.0), Vector3(0, 0, 1), w / nb, 4.5, MB.atlas(10 if (f == 0 and b % 3 == 1) else 2), tint)
	ctx.fac.wall(Vector3(c.x, 0, c.y - 13.0), Vector3(0, 0, -1), w, 9.0, MB.atlas(12), tint)
	ctx.fac.wall(Vector3(c.x - w * 0.5, 0, c.y - 6.0), Vector3(-1, 0, 0), 14.0, 9.0, MB.atlas(12), tint)
	ctx.fac.wall(Vector3(c.x + w * 0.5, 0, c.y - 6.0), Vector3(1, 0, 0), 14.0, 9.0, MB.atlas(12), tint)
	ctx.con.flat(Vector3(c.x, 9.0, c.y - 6.0), w, 14.0, Rect2(0, 0, 4, 2), Color(0.6, 0.35, 0.3))
	ctx.vc.box(Vector3(c.x, 11.0, c.y - 2.0), Vector3(8.0, 4.0, 6.0), Color(0.93, 0.83, 0.55))
	ctx.vc.box(Vector3(c.x, 4.2, c.y + 3.5), Vector3(w * 0.5, 0.25, 5.0), Color(0.6, 0.35, 0.3))   # porch
	for i in 6:
		solid(ctx, Vector3(c.x - w * 0.25 + i * w * 0.1, 2.1, c.y + 5.6), Vector3(0.5, 4.2, 0.5), Color(0.95, 0.93, 0.85))
	label(ctx, "BANGALORE CITY", Vector3(c.x, 11.2, c.y + 1.05), 0.0, 120, Color(0.1, 0.1, 0.1), Color(1, 0.85, 0.2))
	# rails behind
	for k in 3:
		for sd: float in [-0.75, 0.75]:
			ctx.vc.box(Vector3(c.x, 0.22, r.position.y + 2.0 + k * 3.0 + sd), Vector3(r.size.x, 0.14, 0.12), Color(0.35, 0.3, 0.28))

static func _vidhana(ctx: Dictionary, r: Rect2) -> void:
	_slab(ctx, r, "gr", 6.0)
	var c := r.get_center()
	var g := Color(0.78, 0.76, 0.72)   # dressed granite
	var w := r.size.x - 20.0
	var cz := c.y - 12.0
	solid(ctx, Vector3(c.x, 1.0, cz), Vector3(w + 6.0, 2.0, 34.0), g.darkened(0.08))
	solid(ctx, Vector3(c.x, 9.0, cz), Vector3(w, 14.0, 26.0), g)
	var nb := int(w / 3.0)
	for b in nb:
		for f in 4:
			ctx.fac.wall(Vector3(c.x - w * 0.5 + (b + 0.5) * w / nb, 2.0 + f * 3.5, cz + 13.05), Vector3(0, 0, 1), w / nb, 3.5, MB.atlas(2 if f < 3 else 12), g)
	# portico with twelve columns and the grand stairs
	for i in 12:
		ctx.vc.box(Vector3(c.x - 16.5 + i * 3.0, 8.0, cz + 17.0), Vector3(0.9, 12.0, 0.9), Color(0.86, 0.84, 0.8))
	ctx.vc.box(Vector3(c.x, 14.6, cz + 15.5), Vector3(38.0, 1.4, 5.0), g)
	for st in 6:
		ctx.vc.box(Vector3(c.x, 0.17 + st * 0.33, cz + 23.0 - st * 0.9), Vector3(36.0, 0.34, 1.0), Color(0.84, 0.82, 0.78))
	ctx.solids.append([Vector3(c.x, 1.0, cz + 20.5), Vector3(36.0, 2.0, 5.0)])
	# domes
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 2.0
	dome.radial_segments = 12
	dome.rings = 6
	dome.material = Mats.col(Color(0.8, 0.78, 0.74))
	for dd in [[0.0, 0.0, 9.0], [-w * 0.42, 0.0, 4.0], [w * 0.42, 0.0, 4.0], [-w * 0.2, -6.0, 3.0], [w * 0.2, -6.0, 3.0]]:
		var rad: float = dd[2]
		ctx.vc.box(Vector3(c.x + dd[0], 16.0 + rad * 0.3, cz + dd[1]), Vector3(rad * 1.7, rad * 0.9, rad * 1.7), g)
		var mi := MeshInstance3D.new()
		mi.mesh = dome
		mi.scale = Vector3(rad, rad * 0.95, rad)
		mi.position = Vector3(c.x + dd[0], 16.0 + rad * 0.75, cz + dd[1])
		ctx.root.add_child(mi)
	label(ctx, "GOVERNMENT'S WORK IS GOD'S WORK", Vector3(c.x, 14.6, cz + 18.05), 0.0, 96, Color(0.15, 0.12, 0.1), Color(0.8, 0.78, 0.72))
	_scatter_trees(ctx, r, 14, 77, [Rect2(c.x - w * 0.5 - 6, cz - 20, w + 12, 50)])

static func _market(ctx: Dictionary, r: Rect2) -> void:
	_slab(ctx, r, "con", 8.0, Color(0.7, 0.68, 0.64))
	var c := r.get_center()
	var w := r.size.x - 18.0
	var cz := c.y + 8.0
	var red := Color(0.72, 0.22, 0.18)
	solid(ctx, Vector3(c.x, 5.0, cz), Vector3(w, 10.0, 26.0), red)
	for i in 7:
		ctx.vc.box(Vector3(c.x - w * 0.5 + (i + 0.5) * w / 7.0, 3.0, cz - 13.1), Vector3(w / 7.0 - 2.0, 6.0, 0.2), Color(0.95, 0.93, 0.88))
		ctx.vc.box(Vector3(c.x - w * 0.5 + (i + 0.5) * w / 7.0, 2.4, cz - 13.2), Vector3(w / 7.0 - 3.4, 4.8, 0.22), Color(0.12, 0.1, 0.1))
	ctx.vc.box(Vector3(c.x, 11.5, cz - 10.0), Vector3(10.0, 3.0, 6.0), Color(0.95, 0.93, 0.88))
	label(ctx, "KRISHNARAJENDRA MARKET", Vector3(c.x, 8.6, cz - 13.3), PI, 100, Color.WHITE, red.darkened(0.4))
	# street stalls: flowers, vegetables, plantain leaves
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var cols := [Color(1, 0.6, 0.1), Color(1, 0.9, 0.2), Color(0.9, 0.2, 0.3), Color(0.3, 0.6, 0.2), Color(0.9, 0.3, 0.2), Color(0.95, 0.95, 0.9), Color(0.5, 0.2, 0.5)]
	for i in 16:
		var p := Vector3(r.position.x + 5.0 + (i % 8) * (r.size.x - 10.0) / 7.0, 0, r.position.y + 4.0 + (i / 8) * 7.0)
		solid(ctx, p + Vector3(0, 0.45, 0), Vector3(2.4, 0.6, 1.6), Color(0.45, 0.33, 0.22))
		for k in 3:
			ctx.vc.box(p + Vector3(-0.75 + k * 0.75, 0.95, 0), Vector3(0.65, 0.45, 1.2), cols[rng.randi() % cols.size()])
		ctx.vc.box(p + Vector3(0, 2.3, 0), Vector3(3.0, 0.06, 2.4), [Color(0.2, 0.4, 0.75), Color(0.85, 0.75, 0.2), Color(0.75, 0.25, 0.2)][i % 3])
		for sd: float in [-1.0, 1.0]:
			ctx.vc.box(p + Vector3(sd * 1.4, 1.15, 1.1), Vector3(0.06, 2.3, 0.06), Color(0.3, 0.25, 0.2))

static func _park(ctx: Dictionary, r: Rect2, lalbagh: bool) -> void:
	_slab(ctx, r, "gr", 6.0)
	var c := r.get_center()
	# walking paths
	ctx.con.flat(Vector3(c.x, 0.15, c.y), r.size.x - 6.0, 3.0, Rect2(0, 0, 20, 1), Color(0.75, 0.6, 0.45))
	ctx.con.flat(Vector3(c.x, 0.155, c.y), 3.0, r.size.y - 6.0, Rect2(0, 0, 1, 20), Color(0.75, 0.6, 0.45))
	var avoid := [Rect2(c.x - 2.5, r.position.y, 5, r.size.y), Rect2(r.position.x, c.y - 2.5, r.size.x, 5)]
	var vc: MB = ctx.vc
	for i in 6:
		vc.box(Vector3(c.x - 40.0 + i * 16.0, 0.5, c.y + 2.6), Vector3(1.8, 0.08, 0.5), Color(0.3, 0.45, 0.3))
		vc.box(Vector3(c.x - 40.0 + i * 16.0, 0.85, c.y + 2.85), Vector3(1.8, 0.5, 0.06), Color(0.3, 0.45, 0.3))
	if lalbagh:
		# the Glass House
		var gc := Vector3(c.x + 30.0, 0, c.y - 35.0)
		avoid.append(Rect2(gc.x - 22, gc.z - 14, 44, 28))
		var glass := Mats.col(Color(0.75, 0.9, 0.95, 0.45), 0.1)
		for part in [[Vector3(0, 4.0, 0), Vector3(36.0, 8.0, 14.0)], [Vector3(0, 5.5, 0), Vector3(14.0, 11.0, 24.0)]]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = part[1]
			bm.material = glass
			mi.mesh = bm
			mi.position = gc + part[0]
			ctx.root.add_child(mi)
			ctx.solids.append([gc + part[0], part[1]])
		for i in 13:
			vc.box(gc + Vector3(-18.0 + i * 3.0, 4.0, 7.05), Vector3(0.15, 8.0, 0.15), Color.WHITE)
			vc.box(gc + Vector3(-18.0 + i * 3.0, 4.0, -7.05), Vector3(0.15, 8.0, 0.15), Color.WHITE)
		label(ctx, "GLASS HOUSE - 1889", gc + Vector3(0, 11.6, 12.1), 0.0, 60, Color.WHITE, Color(0.1, 0.3, 0.1))
		# the rock and Kempegowda's watch tower
		var rc := Vector3(c.x - 40.0, 0, c.y + 40.0)
		avoid.append(Rect2(rc.x - 14, rc.z - 12, 28, 24))
		solid(ctx, rc + Vector3(0, 1.2, 0), Vector3(24.0, 2.4, 18.0), Color(0.5, 0.48, 0.46), 0.3)
		solid(ctx, rc + Vector3(1, 3.0, 0), Vector3(14.0, 1.6, 10.0), Color(0.46, 0.44, 0.42), -0.2)
		for k in 4:
			vc.box(rc + Vector3(1, 4.4 + k * 1.2, 0), Vector3(3.6 - k * 0.7, 1.2, 3.6 - k * 0.7), Color(0.9, 0.85, 0.7))
	else:
		# bandstand + the red public library
		var bc := Vector3(c.x - 30.0, 0, c.y - 28.0)
		avoid.append(Rect2(bc.x - 6, bc.z - 6, 12, 12))
		solid(ctx, bc + Vector3(0, 0.4, 0), Vector3(7.0, 0.8, 7.0), Color(0.85, 0.85, 0.82), PI * 0.25)
		for i in 8:
			var a := i * TAU / 8.0
			vc.box(bc + Vector3(cos(a) * 3.0, 2.3, sin(a) * 3.0), Vector3(0.18, 3.0, 0.18), Color.WHITE)
		vc.box(bc + Vector3(0, 3.95, 0), Vector3(7.6, 0.3, 7.6), Color(0.7, 0.25, 0.2), Rect2(0, 0, 1, 1), true, Basis(Vector3.UP, PI * 0.25))
		var lc := Vector3(c.x + 35.0, 0, c.y - 30.0)
		avoid.append(Rect2(lc.x - 20, lc.z - 10, 40, 22))
		solid(ctx, lc + Vector3(0, 4.0, 0), Vector3(34.0, 8.0, 12.0), Color(0.7, 0.16, 0.14))
		for i in 9:
			vc.box(lc + Vector3(-14.0 + i * 3.5, 3.6, 6.3), Vector3(0.7, 7.2, 0.7), Color(0.95, 0.93, 0.9))
		vc.box(lc + Vector3(0, 8.4, 0.8), Vector3(36.0, 0.8, 14.0), Color(0.95, 0.93, 0.9))
		label(ctx, "STATE CENTRAL LIBRARY", lc + Vector3(0, 8.5, 7.85), 0.0, 56, Color(0.5, 0.1, 0.1), Color.WHITE)
	_scatter_trees(ctx, r, 46 if lalbagh else 40, int(r.position.x), avoid)

static func _lake(ctx: Dictionary, r: Rect2) -> void:
	_slab(ctx, r, "gr", 6.0)
	var inner := r.grow(-9.0)
	_slab(ctx, inner, "wat", 14.0, Color.WHITE, 0.2)
	var c := inner.get_center()
	ctx.solids.append([Vector3(c.x, 0.5, c.y), Vector3(inner.size.x, 1.0, inner.size.y)])
	solid(ctx, Vector3(c.x + 12.0, 0.5, c.y - 10.0), Vector3(14.0, 1.0, 10.0), Color(0.3, 0.42, 0.25), 0.5)   # island
	ctx.trees.append([Vector3(c.x + 12.0, 0.8, c.y - 10.0), 1.3])
	ctx.vc.box(Vector3(inner.position.x + 6.0, 0.45, c.y + 20.0), Vector3(3.2, 0.5, 1.2), Color(0.85, 0.3, 0.2))   # pedal boat
	ctx.vc.box(Vector3(inner.position.x + 6.0, 1.3, c.y + 20.0), Vector3(2.2, 0.06, 1.3), Color(0.95, 0.9, 0.4))
	_scatter_trees(ctx, r, 22, 91, [inner.grow(2.0)])

static func _temple(ctx: Dictionary, r: Rect2) -> void:
	_slab(ctx, r, "con", 8.0, Color(0.8, 0.76, 0.7))
	var c := r.get_center()
	var cols := [Color(0.95, 0.9, 0.75), Color(0.75, 0.3, 0.25), Color(0.3, 0.5, 0.6), Color(0.9, 0.75, 0.3), Color(0.5, 0.7, 0.45)]
	# gopuram on the north gate
	var gp := Vector3(c.x, 0, r.position.y + 6.0)
	solid(ctx, gp + Vector3(-4.0, 3.0, 0), Vector3(4.0, 6.0, 5.0), cols[0])
	solid(ctx, gp + Vector3(4.0, 3.0, 0), Vector3(4.0, 6.0, 5.0), cols[0])
	for k in 6:
		ctx.vc.box(gp + Vector3(0, 6.8 + k * 1.7, 0), Vector3(12.0 - k * 1.6, 1.7, 5.0 - k * 0.5), cols[k % cols.size()])
	ctx.vc.box(gp + Vector3(0, 17.6, 0), Vector3(3.0, 1.2, 1.6), Color(0.9, 0.75, 0.2))
	# sanctum
	solid(ctx, Vector3(c.x, 2.5, c.y + 12.0), Vector3(16.0, 5.0, 14.0), Color(0.6, 0.58, 0.55))
	for k in 3:
		ctx.vc.box(Vector3(c.x, 5.8 + k * 1.5, c.y + 14.0), Vector3(6.0 - k * 1.6, 1.5, 6.0 - k * 1.6), cols[(k + 2) % cols.size()])
	solid(ctx, Vector3(c.x, 3.5, c.y - 6.0), Vector3(0.7, 7.0, 0.7), Color(0.35, 0.33, 0.3))   # lamp pillar
	# compound wall with red-white stripes
	for sd: float in [-1.0, 1.0]:
		solid(ctx, Vector3(c.x + sd * (r.size.x * 0.5 - 0.3), 1.0, c.y), Vector3(0.5, 2.0, r.size.y), Color(0.9, 0.88, 0.85))
		ctx.vc.box(Vector3(c.x + sd * (r.size.x * 0.5 - 0.3), 1.0, c.y), Vector3(0.56, 0.5, r.size.y), Color(0.7, 0.2, 0.15), Rect2(0, 0, 1, 1), false)
	solid(ctx, Vector3(c.x, 1.0, r.end.y - 0.3), Vector3(r.size.x, 2.0, 0.5), Color(0.9, 0.88, 0.85))
	ctx.trees.append([Vector3(c.x - 18.0, 0, c.y - 8.0), 1.9])   # the old peepal tree

static func _airport(ctx: Dictionary, r: Rect2) -> void:
	_slab(ctx, r, "gr", 6.0)
	var c := r.get_center()
	var rw := Rect2(r.position.x + 10.0, c.y + 14.0, r.size.x - 20.0, 26.0)
	_slab(ctx, rw, "con", 10.0, Color(0.36, 0.36, 0.38), 0.16)
	for i in int(rw.size.x / 16.0):
		ctx.vc.box(Vector3(rw.position.x + 8.0 + i * 16.0, 0.17, rw.get_center().y), Vector3(8.0, 0.02, 0.7), Color.WHITE)
	var tc := Vector3(r.position.x + 60.0, 0, r.position.y + 22.0)
	_slab(ctx, Rect2(r.position.x + 6.0, r.position.y + 4.0, 140.0, 46.0), "con", 8.0, Color(0.72, 0.72, 0.7), 0.15)
	solid(ctx, tc + Vector3(0, 4.0, -6.0), Vector3(60.0, 8.0, 14.0), Color(0.88, 0.88, 0.84))
	for i in 15:
		ctx.fac.wall(tc + Vector3(-28.0 + i * 4.0, 0, 1.05), Vector3(0, 0, 1), 4.0, 4.0, MB.atlas(2), Color(0.9, 0.9, 0.86))
	solid(ctx, tc + Vector3(38.0, 9.0, -6.0), Vector3(5.0, 18.0, 5.0), Color(0.85, 0.85, 0.82))
	ctx.vc.box(tc + Vector3(38.0, 19.2, -6.0), Vector3(8.0, 2.6, 8.0), Color(0.25, 0.35, 0.4))
	label(ctx, "BANGALORE AIRPORT", tc + Vector3(0, 9.0, 1.1), 0.0, 110, Color(0.1, 0.2, 0.5), Color.WHITE)
	# a parked turboprop
	var pc := Vector3(tc.x + 20.0, 0, tc.z + 26.0)
	solid(ctx, pc + Vector3(0, 2.6, 0), Vector3(22.0, 2.6, 2.6), Color(0.95, 0.95, 0.95))
	ctx.vc.box(pc + Vector3(1.0, 3.4, 0), Vector3(3.6, 0.3, 24.0), Color(0.9, 0.9, 0.92))
	ctx.vc.box(pc + Vector3(-10.0, 5.2, 0), Vector3(2.6, 3.4, 0.3), Color(0.85, 0.3, 0.1))
	ctx.vc.box(pc + Vector3(-10.0, 4.0, 0), Vector3(2.0, 0.2, 8.0), Color(0.9, 0.9, 0.92))
	ctx.vc.box(pc + Vector3(0, 2.75, 1.32), Vector3(20.0, 0.25, 0.02), Color(0.85, 0.3, 0.1))
