class_name Campus
extends RefCounted
## M.S. Ramaiah Institute of Technology, MSR Nagar, as BIG BANG LORE's opening
## location: compound wall and gate on the Outer Ring Road, a U of academic blocks
## around a quadrangle, and (on 1 January 2007, in this story) a film unit at work
## in the quad. Built in a local frame: origin at the gate, +X along the road
## (towards Hebbal), +Z into the campus.

static var _frame := Transform3D.IDENTITY
static var _have := false

## Local campus frame -> world. Derived from the real Outer Ring Road edge so the
## gate sits exactly on the road's southern kerb.
static func frame() -> Transform3D:
	if _have:
		return _frame
	var pick: Dictionary = {}
	for e in City.edges:
		if (e.a == "hebbal" and e.b == "yeshwanthpur") or (e.a == "yeshwanthpur" and e.b == "hebbal"):
			pick = e
	var g := Vector2(-175, -1478)
	var d := Vector2(1, 0)
	if not pick.is_empty():
		var pa: Vector2 = pick.pa
		var pb: Vector2 = pick.pb
		d = (pb - pa).normalized()
		if d.x < 0.0:
			d = -d
		var n := Vector2(-d.y, d.x)
		if n.y < 0.0:
			n = -n
		var t := (Vector2(-175, -1490) - pa).dot(pb - pa) / (pb - pa).length_squared()
		var on := pa.lerp(pb, t)
		g = on + n * (float(pick.w) * 0.5 + 4.0)
	var yaw := atan2(-d.y, d.x)            # local +X onto the road direction
	_frame = Transform3D(Basis(Vector3.UP, yaw), Vector3(g.x, 0, g.y))
	_have = true
	return _frame

static func world(local: Vector3) -> Vector3:
	return frame() * local

static func yaw_world(local_yaw: float) -> float:
	return frame().basis.get_euler().y + local_yaw

# ------------------------------------------------------------------ build
static func build(_z: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "LM_msrit"
	root.transform = frame()
	var ctx := {"root": root, "vc": MB.new(), "fac": MB.new(), "gr": MB.new(), "con": MB.new(), "wat": MB.new(), "trees": [], "solids": []}
	_ground(ctx)
	_walls_and_gate(ctx)
	_blocks(ctx)
	_canteen_and_bikes(ctx)
	_film_unit(ctx)
	var m := ArrayMesh.new()
	ctx.vc.add_to(m, Mats.vcol())
	ctx.fac.add_to(m, Mats.facade())
	ctx.gr.add_to(m, Mats.grass())
	ctx.con.add_to(m, Mats.concrete())
	var mi := MeshInstance3D.new()
	mi.mesh = m
	root.add_child(mi)
	Landmarks._finish(ctx)
	Landmarks.sound(ctx, "amb_crowd", Vector3(0, 1.5, 28), 60.0, -10.0)
	return root

static func _ground(ctx: Dictionary) -> void:
	ctx.con.flat(Vector3(0, 0.11, 64), 156, 128, Rect2(0, 0, 18, 15), Color(0.82, 0.8, 0.76))
	# the drive, a shade darker, from the gate to the porch
	ctx.vc.box(Vector3(0, 0.125, 46), Vector3(9.0, 0.02, 92), Color(0.42, 0.41, 0.4))
	# lawns either side of the drive, edged with kerb stones
	for sx: float in [-1.0, 1.0]:
		ctx.gr.flat(Vector3(sx * 30.0, 0.14, 21), 40, 22, Rect2(0, 0, 6, 3))
		ctx.vc.box(Vector3(sx * 30.0, 0.16, 9.9), Vector3(40, 0.12, 0.25), Color(0.85, 0.85, 0.82))
		ctx.vc.box(Vector3(sx * 30.0, 0.16, 32.1), Vector3(40, 0.12, 0.25), Color(0.85, 0.85, 0.82))
	# the quad's paved centre where the unit has set up
	ctx.vc.box(Vector3(0, 0.13, 63), Vector3(92, 0.02, 46), Color(0.74, 0.7, 0.62))
	for i in 4:      # rain trees on the lawns, clear of the drive and the quad
		ctx.trees.append([Vector3(-36.0 - (i % 2) * 8.0, 0, 12.5 + i * 5.0), 1.1 + 0.15 * sin(i * 2.1)])
		ctx.trees.append([Vector3(36.0 + (i % 2) * 8.0, 0, 13.0 + i * 5.0), 1.1 + 0.15 * cos(i * 1.7)])
	for i in 5:      # and a row along each wing
		ctx.trees.append([Vector3(-44.0, 0, 46.0 + i * 9.0), 1.0])
		ctx.trees.append([Vector3(44.0, 0, 46.0 + i * 9.0), 1.0])
	for i in 6:
		ctx.trees.append([Vector3(-70 + i * 4.0, 0, 115.0 + (i % 2) * 5.0), 1.4])
		ctx.trees.append([Vector3(70 - i * 4.0, 0, 118.0 - (i % 2) * 4.0), 1.3])
	ctx.trees.append([Vector3(-12, 0, 4), 1.3])
	ctx.trees.append([Vector3(12, 0, 4.5), 1.2])

static func _walls_and_gate(ctx: Dictionary) -> void:
	var cream := Color(0.88, 0.82, 0.64)
	var brick := Color(0.6, 0.26, 0.18)
	for seg in [[-78.0, -7.0], [7.0, 78.0]]:
		var a: float = seg[0]
		var b: float = seg[1]
		Landmarks.solid(ctx, Vector3((a + b) * 0.5, 1.0, 0.0), Vector3(b - a, 2.0, 0.3), cream)
		ctx.vc.box(Vector3((a + b) * 0.5, 2.08, 0.0), Vector3(b - a, 0.16, 0.42), brick)
		var n := int((b - a) / 4.0)
		for k in n + 1:        # piers every four metres
			ctx.vc.box(Vector3(a + k * (b - a) / n, 1.1, 0.0), Vector3(0.5, 2.25, 0.5), cream.darkened(0.06))
	for sx: float in [-1.0, 1.0]:
		Landmarks.solid(ctx, Vector3(sx * 78.0, 1.0, 64.0), Vector3(0.3, 2.0, 128.0), cream)
	Landmarks.solid(ctx, Vector3(0, 1.0, 128.0), Vector3(156.0, 2.0, 0.3), cream)
	# the gate: two pillars and the name arch, the iron leaves swung open
	for sx: float in [-1.0, 1.0]:
		Landmarks.solid(ctx, Vector3(sx * 6.6, 3.2, 0.0), Vector3(1.4, 6.4, 1.4), cream)
		ctx.vc.box(Vector3(sx * 6.6, 6.5, 0.0), Vector3(1.7, 0.3, 1.7), brick)
		for k in 11:          # swung-open grille leaves: bars, not slabs
			ctx.vc.box(Vector3(sx * 5.0, 0.85, 0.3 + k * 0.28), Vector3(0.05, 1.7, 0.05), Color(0.16, 0.17, 0.2))
		for yy: float in [0.12, 1.65]:
			ctx.vc.box(Vector3(sx * 5.0, yy, 1.7), Vector3(0.06, 0.08, 2.9), Color(0.16, 0.17, 0.2))
	ctx.vc.box(Vector3(0, 7.3, 0.0), Vector3(15.0, 1.5, 0.9), brick)
	ctx.vc.box(Vector3(0, 8.15, 0.0), Vector3(15.6, 0.2, 1.1), cream)
	_sign(ctx, "M. S. RAMAIAH INSTITUTE OF TECHNOLOGY", Vector3(0, 7.45, -0.47), PI, 64, Color(1, 0.94, 0.75), Color(0.35, 0.08, 0.05))
	_sign(ctx, "MSR NAGAR, BANGALORE - 560 054", Vector3(0, 6.85, -0.47), PI, 30, Color(1, 1, 1), Color(0.35, 0.08, 0.05))
	_sign(ctx, "M. S. RAMAIAH INSTITUTE OF TECHNOLOGY", Vector3(0, 7.45, 0.47), 0.0, 64, Color(1, 0.94, 0.75), Color(0.35, 0.08, 0.05))
	# security cabin
	var cab := Vector3(10.5, 1.3, 3.0)
	Landmarks.solid(ctx, cab, Vector3(2.4, 2.6, 2.2), Color(0.9, 0.88, 0.8))
	ctx.vc.box(cab + Vector3(0, 1.4, 0), Vector3(2.9, 0.15, 2.7), brick)
	ctx.vc.box(cab + Vector3(-1.22, 0.3, 0), Vector3(0.04, 0.9, 1.4), Color(0.2, 0.26, 0.3))
	_sign(ctx, "SECURITY", cab + Vector3(-1.26, 1.05, 0), -PI * 0.5, 26, Color(1, 1, 1), Color(0.1, 0.2, 0.5))
	# the boom barrier, raised
	ctx.vc.box(Vector3(6.0, 0.6, 2.2), Vector3(0.3, 1.2, 0.3), Color(0.9, 0.85, 0.2))
	var boom := Basis(Vector3(0, 0, 1), 1.35)
	ctx.vc.box(Vector3(5.8, 3.5, 2.2), Vector3(5.6, 0.12, 0.12), Color(0.95, 0.2, 0.15), Rect2(0, 0, 1, 1), true, boom)

static func _sign(ctx: Dictionary, text: String, pos: Vector3, yaw: float, size: int, c: Color, bg: Color) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = size
	lb.pixel_size = 0.008
	lb.outline_size = 10
	lb.modulate = c
	lb.outline_modulate = bg
	lb.position = pos
	lb.rotation.y = yaw
	lb.double_sided = false
	lb.visibility_range_end = 160.0
	ctx.root.add_child(lb)

static func _facade(ctx: Dictionary, mid: Vector3, nrm: Vector3, w: float, floors: int, tint: Color, ground_tile: int) -> void:
	var bays := maxi(1, int(w / 4.0))
	var right := Vector3.UP.cross(nrm).normalized()
	for b in bays:
		for f in floors:
			var c := mid + right * (-w * 0.5 + (b + 0.5) * w / bays) + Vector3(0, f * 3.6, 0)
			var tile := ground_tile if f == 0 else (22 if (b + f) % 3 != 0 else 17)
			if f == 0 and b % 5 == 2:
				tile = 31
			ctx.fac.wall(c + nrm * 0.02, nrm, w / bays, 3.6, MB.atlas(tile), tint)

static func _block(ctx: Dictionary, centre: Vector3, size: Vector3, floors: int, front: Vector3, label_txt: String) -> void:
	var cream := Color(0.95, 0.9, 0.77)
	var brick := Color(0.62, 0.3, 0.22)
	var h := floors * 3.6
	ctx.solids.append([centre + Vector3(0, h * 0.5, 0), Vector3(size.x, h, size.z)])
	for nrm: Vector3 in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		var half := size * 0.5
		var w := size.x if absf(nrm.z) > 0.5 else size.z
		var mid := centre + Vector3(nrm.x * half.x, 0, nrm.z * half.z)
		_facade(ctx, mid, nrm, w, floors, cream if nrm == front else cream.darkened(0.04), 27 if nrm == front else 11)
	# floor bands in the institute's brick red, parapet, roof
	for f in range(1, floors + 1):
		ctx.vc.box(centre + Vector3(0, f * 3.6 - 0.1, 0), Vector3(size.x + 0.4, 0.28, size.z + 0.4), brick)
	ctx.vc.box(centre + Vector3(0, h + 0.5, 0), Vector3(size.x, 1.0, size.z), cream.darkened(0.1), Rect2(0, 0, 1, 1), false)
	ctx.con.flat(centre + Vector3(0, h + 0.05, 0), size.x - 0.2, size.z - 0.2, Rect2(0, 0, 4, 2), Color(0.55, 0.53, 0.5))
	# black water tanks on the roof
	for k in 2:
		ctx.vc.box(centre + Vector3((k - 0.5) * size.x * 0.5, h + 1.0, 0), Vector3(1.6, 1.8, 1.6), Color(0.08, 0.08, 0.09))
	if label_txt != "":
		var lp := centre + Vector3(front.x * (size.x * 0.5 + 0.08), h - 0.9, front.z * (size.z * 0.5 + 0.08))
		_sign(ctx, label_txt, lp, atan2(front.x, front.z), 44, Color(0.98, 0.95, 0.85), Color(0.45, 0.12, 0.08))

static func _blocks(ctx: Dictionary) -> void:
	# main block across the head of the quad
	_block(ctx, Vector3(0, 0, 104), Vector3(100, 0, 16), 4, Vector3(0, 0, -1), "")
	# the central tower and the porch
	_block(ctx, Vector3(0, 0, 103), Vector3(18, 0, 18), 5, Vector3(0, 0, -1), "M. S. RAMAIAH INSTITUTE OF TECHNOLOGY")
	ctx.vc.box(Vector3(0, 4.4, 91.5), Vector3(16, 0.4, 6), Color(0.9, 0.85, 0.72))
	for i in 6:
		Landmarks.solid(ctx, Vector3(-7.0 + i * 2.8, 2.2, 89.0), Vector3(0.55, 4.4, 0.55), Color(0.97, 0.95, 0.9))
	for st in 4:
		ctx.vc.box(Vector3(0, 0.2 + st * 0.15, 92.6 - st * 0.55), Vector3(14, 0.15, 0.6), Color(0.8, 0.78, 0.74))
	# the two wings, three floors each, facing into the quad
	_block(ctx, Vector3(-56, 0, 66), Vector3(16, 0, 52), 3, Vector3(1, 0, 0), "DEPARTMENT OF MECHANICAL ENGINEERING")
	_block(ctx, Vector3(56, 0, 66), Vector3(16, 0, 52), 3, Vector3(-1, 0, 0), "DEPARTMENT OF ELECTRONICS & COMMUNICATION")
	# a notice board by the porch
	ctx.vc.box(Vector3(-11, 1.3, 88.5), Vector3(2.6, 1.4, 0.12), Color(0.35, 0.22, 0.14))
	ctx.vc.box(Vector3(-11, 1.3, 88.43), Vector3(2.3, 1.15, 0.02), Color(0.86, 0.82, 0.7))
	_sign(ctx, "NOTICE BOARD\nVTU EXAMINATIONS - TIME TABLE", Vector3(-11, 1.75, 88.4), PI, 18, Color(0.1, 0.1, 0.1), Color(0.86, 0.82, 0.7))

static func _canteen_and_bikes(ctx: Dictionary) -> void:
	var c := Vector3(66, 0, 16)
	for k in 4:
		Landmarks.solid(ctx, c + Vector3(-6 + (k % 2) * 12, 1.4, -5 + (k / 2) * 10), Vector3(0.2, 2.8, 0.2), Color(0.5, 0.5, 0.52))
	ctx.vc.box(c + Vector3(0, 2.9, 0), Vector3(13.5, 0.1, 11.5), Color(0.55, 0.58, 0.6), Rect2(0, 0, 1, 1), true, Basis(Vector3(1, 0, 0), 0.06))
	for k in 3:
		ctx.vc.box(c + Vector3(-3 + k * 3, 0.75, 1), Vector3(1.0, 0.06, 2.2), Color(0.85, 0.85, 0.82))
	ctx.vc.box(c + Vector3(5, 0.5, -4), Vector3(3, 1.0, 1), Color(0.6, 0.6, 0.62))
	_sign(ctx, "CANTEEN", c + Vector3(-6.9, 2.4, 0), -PI * 0.5, 40, Color(1, 1, 0.9), Color(0.1, 0.35, 0.15))
	# students' two-wheelers parked in a row inside the west wall
	var rng := RandomNumberGenerator.new()
	rng.seed = 2007
	var cols := [Color(0.08, 0.08, 0.1), Color(0.55, 0.05, 0.05), Color(0.1, 0.12, 0.35), Color(0.6, 0.6, 0.62), Color(0.05, 0.25, 0.1)]
	for i in 26:
		var p := Vector3(-73.5, 0, 6.0 + i * 1.05)
		var col: Color = cols[rng.randi() % cols.size()]
		var bs := Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.12, 0.12))
		ctx.vc.box(p + Vector3(0, 0.62, 0), Vector3(0.28, 0.34, 1.3), col, Rect2(0, 0, 1, 1), true, bs)
		ctx.vc.box(p + Vector3(0, 0.84, 0), Vector3(0.26, 0.08, 0.7), Color(0.06, 0.06, 0.06), Rect2(0, 0, 1, 1), true, bs)
		for wz: float in [-0.62, 0.62]:
			ctx.vc.box(p + bs * Vector3(0, 0.3, wz), Vector3(0.08, 0.6, 0.6), Color(0.07, 0.07, 0.07), Rect2(0, 0, 1, 1), true, bs)
		ctx.vc.box(p + bs * Vector3(0, 1.0, -0.55), Vector3(0.7, 0.04, 0.04), Color(0.6, 0.6, 0.62), Rect2(0, 0, 1, 1), true, bs)

# ------------------------------------------------------------------ the film unit
## Named spots the opening sequence uses (local frame).
const SPOT := {
	"rajini_chair": Vector3(16.0, 0, 57.0),
	"monitor": Vector3(-13.0, 0, 52.0),
	"camera": Vector3(-6.0, 0, 61.0),
	"rope_z": 38.5,
	"crowd": Vector3(4.0, 0, 30.0),
	"porch": Vector3(0, 0, 87.0),
	"gate": Vector3(0, 0, -1.0),
}

static func _film_unit(ctx: Dictionary) -> void:
	var vc: MB = ctx.vc
	var dark := Color(0.08, 0.08, 0.09)
	var steel := Color(0.62, 0.63, 0.66)
	# rope line holding the crowd back
	var rz: float = SPOT.rope_z
	for i in 21:
		var x := -30.0 + i * 3.0
		vc.box(Vector3(x, 0.5, rz), Vector3(0.08, 1.0, 0.08), steel)
		vc.box(Vector3(x, 0.05, rz), Vector3(0.4, 0.1, 0.4), dark)
	vc.box(Vector3(0, 0.92, rz), Vector3(60, 0.04, 0.04), Color(0.85, 0.15, 0.1))
	vc.box(Vector3(0, 0.62, rz), Vector3(60, 0.03, 0.03), Color(0.9, 0.85, 0.2))
	# the superstar's chair under a big unit umbrella, a small table beside it
	var rc: Vector3 = SPOT.rajini_chair
	# he sits facing into the campus (+Z), his back to the gate and the crowd
	_chair(ctx, rc, PI, Color(0.12, 0.12, 0.13))
	vc.box(rc + Vector3(0.85, 0.55, 0.1), Vector3(0.5, 0.04, 0.5), Color(0.4, 0.28, 0.18))
	vc.box(rc + Vector3(0.85, 0.27, 0.1), Vector3(0.06, 0.55, 0.06), Color(0.3, 0.2, 0.12))
	vc.box(rc + Vector3(0.8, 0.68, 0.05), Vector3(0.09, 0.22, 0.09), steel)
	vc.box(rc + Vector3(0.95, 0.61, 0.2), Vector3(0.07, 0.09, 0.07), steel)
	var um := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.85
	cone.height = 0.55
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_bottom = false
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.92, 0.9, 0.86)
	cm.roughness = 0.9
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material = cm
	um.mesh = cone
	um.position = rc + Vector3(0.05, 2.55, 0.35)
	um.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ctx.root.add_child(um)
	vc.box(rc + Vector3(0.55, 1.3, 0.3), Vector3(0.05, 2.6, 0.05), steel)
	vc.box(rc + Vector3(0.55, 0.05, 0.3), Vector3(0.6, 0.1, 0.6), dark)
	# video assist: a monitor on a trolley, two director's chairs
	var mo: Vector3 = SPOT.monitor
	vc.box(mo + Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 0.6), steel.darkened(0.3))
	vc.box(mo + Vector3(0, 1.12, 0), Vector3(0.5, 0.42, 0.45), dark)
	vc.box(mo + Vector3(0, 1.12, -0.23), Vector3(0.4, 0.3, 0.02), Color(0.25, 0.35, 0.45))
	vc.box(mo + Vector3(0, 1.45, 0.05), Vector3(0.7, 0.03, 0.7), dark)      # hood
	_chair(ctx, mo + Vector3(-1.4, 0, 0.6), PI, Color(0.12, 0.12, 0.13))
	_chair(ctx, mo + Vector3(1.4, 0, 0.6), PI, Color(0.12, 0.12, 0.13))
	_sign(ctx, "DIRECTOR", mo + Vector3(-1.4, 0.82, 0.37), PI, 14, Color(1, 1, 1), dark)
	# camera on a dolly track, and a jib arm
	var ca: Vector3 = SPOT.camera
	for sd: float in [-0.32, 0.32]:
		vc.box(ca + Vector3(0, 0.07, sd), Vector3(9.0, 0.06, 0.05), steel)
	for k in 10:
		vc.box(ca + Vector3(-4.4 + k, 0.03, 0), Vector3(0.1, 0.05, 0.9), Color(0.35, 0.25, 0.15))
	vc.box(ca + Vector3(1.0, 0.35, 0), Vector3(1.0, 0.45, 0.8), dark)
	vc.box(ca + Vector3(1.0, 0.95, 0), Vector3(0.12, 0.8, 0.12), steel)
	vc.box(ca + Vector3(1.0, 1.45, 0), Vector3(0.55, 0.32, 0.26), dark)              # camera body
	vc.box(ca + Vector3(1.0, 1.47, -0.22), Vector3(0.1, 0.1, 0.22), Color(0.04, 0.04, 0.04))
	vc.box(ca + Vector3(0.62, 1.47, 0), Vector3(0.22, 0.26, 0.3), Color(0.05, 0.05, 0.05))  # matte box
	vc.box(ca + Vector3(1.25, 1.66, 0.08), Vector3(0.3, 0.12, 0.1), dark)               # magazine
	var jb := ca + Vector3(-12.0, 0, 8.0)
	vc.box(jb + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2), Color(0.2, 0.2, 0.22))
	var arm := Basis(Vector3(0, 0, 1), 0.42)
	vc.box(jb + Vector3(2.2, 2.2, 0), Vector3(6.0, 0.18, 0.18), steel, Rect2(0, 0, 1, 1), true, arm)
	vc.box(jb + Vector3(4.9, 3.4, 0), Vector3(0.4, 0.3, 0.3), dark)
	vc.box(jb + Vector3(-0.8, 1.4, 0), Vector3(0.6, 0.6, 0.6), Color(0.3, 0.3, 0.32))   # counterweights
	# reflectors and a big lamp, black flags, cables
	for k in 2:
		var rp := Vector3(-24.0 + k * 3.0, 0, 62.0 - k)
		vc.box(rp + Vector3(0, 0.75, 0), Vector3(0.05, 1.5, 0.05), steel)
		vc.box(rp + Vector3(0, 1.7, 0), Vector3(1.2, 1.2, 0.03), Color(0.85, 0.86, 0.9), Rect2(0, 0, 1, 1), true, Basis(Vector3.UP, 0.5 - k).rotated(Vector3(1, 0, 0), 0.0))
	var lamp := Vector3(-1.0, 0, 70.0)
	vc.box(lamp + Vector3(0, 1.3, 0), Vector3(0.07, 2.6, 0.07), steel)
	vc.box(lamp + Vector3(0, 2.75, 0), Vector3(0.6, 0.5, 0.7), dark)
	vc.box(lamp + Vector3(0, 2.75, -0.36), Vector3(0.5, 0.42, 0.02), Color(0.95, 0.92, 0.8))
	for k in 3:
		vc.box(lamp + Vector3(-0.4 + k * 0.4, 0.04, 0.8), Vector3(0.6, 0.03, 0.03), dark, Rect2(0, 0, 1, 1), true, Basis(Vector3.UP, k))
	vc.box(Vector3(10.0, 0.04, 74.0), Vector3(22.0, 0.03, 0.04), dark, Rect2(0, 0, 1, 1), true, Basis(Vector3.UP, 0.2))
	# the generator van and flight cases by the main block
	var gv := Vector3(30.0, 0, 82.0)
	Landmarks.solid(ctx, gv + Vector3(0, 1.4, 0), Vector3(2.3, 2.6, 6.0), Color(0.86, 0.86, 0.82))
	vc.box(gv + Vector3(0, 1.0, -3.6), Vector3(2.2, 2.0, 1.4), Color(0.86, 0.86, 0.82))
	vc.box(gv + Vector3(0, 1.4, -4.32), Vector3(1.9, 0.7, 0.02), Color(0.2, 0.25, 0.3))
	for wz: float in [-3.2, 1.8]:
		for sx: float in [-1.0, 1.0]:
			vc.box(gv + Vector3(sx * 1.05, 0.42, wz), Vector3(0.3, 0.84, 0.84), dark)
	_sign(ctx, "UNIT GENERATOR  -  125 KVA", gv + Vector3(-1.17, 1.9, 0.5), -PI * 0.5, 30, Color(0.1, 0.1, 0.1), Color(0.86, 0.86, 0.82))
	for k in 6:
		vc.box(Vector3(22.0 + (k % 3) * 1.0, 0.35 + (k / 3) * 0.6, 78.0), Vector3(0.9, 0.55, 0.6), Color(0.15, 0.15, 0.16))
	for k in 4:
		vc.box(Vector3(-20.0 + k * 0.45, 0.25, 48.0), Vector3(0.35, 0.5, 0.35), Color(0.3, 0.55, 0.85, 1.0))   # water cans
	# a table with the clapboard and the reel cans
	var tb := Vector3(-18.0, 0, 56.0)
	vc.box(tb + Vector3(0, 0.75, 0), Vector3(1.6, 0.05, 0.8), Color(0.45, 0.32, 0.2))
	for sx: float in [-0.7, 0.7]:
		vc.box(tb + Vector3(sx, 0.37, 0), Vector3(0.05, 0.74, 0.7), Color(0.3, 0.2, 0.12))
	vc.box(tb + Vector3(-0.3, 0.8, 0), Vector3(0.32, 0.03, 0.26), Color(0.06, 0.06, 0.06))
	vc.box(tb + Vector3(0.35, 0.8, 0.05), Vector3(0.36, 0.06, 0.36), Color(0.5, 0.5, 0.52))
	vc.box(tb + Vector3(0.35, 0.86, 0.05), Vector3(0.36, 0.06, 0.36), Color(0.5, 0.5, 0.52))
	_notes(ctx, tb)

## The money-rain shot: ₹1,000 notes (Mahatma Gandhi series, as in circulation in 2007) and
## US $100 notes (1996 series) lie where they came down around the camera and the set,
## thinning out towards the edges; a few have blown towards the rope. Two banded bundles
## sit on the props table, ready for the next take. Textures are stylised props, not facsimiles.
static func _notes(ctx: Dictionary, table: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000
	for kind in [["inr", "res://assets/img/note_inr1000.png", Vector2(0.177, 0.073), 70], ["usd", "res://assets/img/note_usd100.png", Vector2(0.156, 0.066), 50]]:
		var q := QuadMesh.new()
		q.size = kind[2]
		q.orientation = PlaneMesh.FACE_Y
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(kind[1])
		m.roughness = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material = m
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = q
		var n: int = kind[3]
		mm.instance_count = n + 12
		for i in n:
			# most land in the set's centre, where the take was shot; a tail drifts towards the crowd
			var p: Vector3
			var r := rng.randf()
			if r < 0.7:
				p = Vector3(rng.randfn(-3.0, 4.0), 0.0, rng.randfn(61.0, 3.2))
			elif r < 0.9:
				p = Vector3(rng.randfn(4.0, 6.0), 0.0, rng.randfn(52.0, 4.0))
			else:
				p = Vector3(rng.randf_range(-20.0, 24.0), 0.0, rng.randf_range(39.5, 45.0))
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.12, 0.12)) * Basis(Vector3(0, 0, 1), rng.randf_range(-0.1, 0.1))
			mm.set_instance_transform(i, Transform3D(b, p + Vector3(0, 0.135 + rng.randf() * 0.01, 0)))
		for i in 12:     # a bundle on the table: notes stacked, slightly fanned
			var b2 := Basis(Vector3.UP, 0.1 + rng.randf_range(-0.04, 0.04))
			var off := Vector3(-0.55 if kind[0] == "inr" else -0.05, 0.785 + i * 0.002, 0.18)
			mm.set_instance_transform(n + i, Transform3D(b2, table + off))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 60.0
		ctx.root.add_child(mi)
	for k in 2:   # paper bands round the bundles
		ctx.vc.box(table + Vector3(-0.55 if k == 0 else -0.05, 0.8, 0.18), Vector3(0.03, 0.03, 0.08), Color(0.9, 0.88, 0.8))

static func _chair(ctx: Dictionary, p: Vector3, yaw: float, canvas: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	var wood := Color(0.42, 0.3, 0.18)
	for sx: float in [-0.24, 0.24]:
		for sz: float in [-0.2, 0.2]:
			ctx.vc.box(p + b * Vector3(sx, 0.3, sz), Vector3(0.04, 0.6, 0.04), wood, Rect2(0, 0, 1, 1), true, b)
		ctx.vc.box(p + b * Vector3(sx, 0.85, 0.2), Vector3(0.04, 0.55, 0.04), wood, Rect2(0, 0, 1, 1), true, b)
		ctx.vc.box(p + b * Vector3(sx, 0.68, 0.0), Vector3(0.05, 0.04, 0.46), wood, Rect2(0, 0, 1, 1), true, b)
	ctx.vc.box(p + b * Vector3(0, 0.6, 0), Vector3(0.48, 0.03, 0.4), canvas, Rect2(0, 0, 1, 1), true, b)
	ctx.vc.box(p + b * Vector3(0, 0.95, 0.21), Vector3(0.48, 0.24, 0.02), canvas, Rect2(0, 0, 1, 1), true, b)
