class_name Human
extends Node3D
## A procedurally built, procedurally animated person. Used for the player and
## every NPC. Appearance comes from a plain "look" dictionary (see default_look).

const SKIN := [Color(0.93, 0.76, 0.6), Color(0.85, 0.65, 0.48), Color(0.74, 0.54, 0.38), Color(0.62, 0.43, 0.29), Color(0.5, 0.34, 0.23), Color(0.38, 0.26, 0.18)]
const HAIR_COL := [Color(0.06, 0.05, 0.05), Color(0.14, 0.1, 0.08), Color(0.45, 0.45, 0.46), Color(0.8, 0.8, 0.8), Color(0.3, 0.15, 0.08)]
const CLOTH := [Color(0.95, 0.95, 0.93), Color(0.76, 0.66, 0.5), Color(0.55, 0.7, 0.85), Color(0.2, 0.3, 0.5), Color(0.75, 0.2, 0.2), Color(0.25, 0.45, 0.3),
	Color(0.9, 0.75, 0.25), Color(0.5, 0.3, 0.5), Color(0.15, 0.15, 0.17), Color(0.45, 0.32, 0.22), Color(0.9, 0.55, 0.6), Color(0.35, 0.6, 0.6), Color(0.6, 0.6, 0.62), Color(0.95, 0.5, 0.15)]
const TOPS := ["Formal shirt (half sleeve)", "Formal shirt (full sleeve)", "Printed shirt", "Checked shirt", "T-shirt", "Kurta", "Safari jacket", "Conductor khaki", "Blouse", "Kameez"]
const BOTTOMS := ["Trousers", "Jeans", "Lungi", "Panche", "Saree", "Salwar"]
const HAIRS := ["Short crop", "Side parting", "Thick wave", "Receding", "Step cut", "Curly", "Bald", "Long plait", "Bun"]
const BEARDS := ["Clean shave", "Thin moustache", "Thick moustache", "Handlebar", "Stubble", "Full beard", "French beard"]
const FACES := ["Lean", "Round", "Square", "Long", "Sharp", "Soft"]
const SHOES := ["Chappals", "Leather shoes", "Canvas shoes", "Barefoot", "Sandals"]
const GLASSES := ["None", "Square frames", "Aviator shades", "Round frames"]
const WATCHES := ["None", "Steel watch", "Gold watch", "Leather strap"]
const ACCS := ["None", "Gold chain", "Cap", "Shoulder towel", "Ticket bag", "Jasmine flowers"]

static var _meshes := {}

var look := {}
var state := "idle"        # idle, walk, sit, drive, talk, crouch, ko, air
var speed := 0.0           # horizontal speed, drives the walk cycle
var talk_t := 0.0
var _phase := 0.0
var _t := 0.0
var _shot := ""
var _shot_t := 0.0
var _j := {}               # joints
var _rot := {}             # current joint rotations (Vector3)
var body: Node3D
var hips: Node3D
var head: Node3D

static func default_look() -> Dictionary:
	return {"sex": 0, "skin": 2, "face": 0, "hair": 1, "hair_col": 0, "beard": 2, "height": 0.5, "build": 0.4,
		"top": 7, "top_col": 1, "bottom": 0, "bot_col": 1, "shoes": 0, "glasses": 0, "watch": 3, "acc": 4}

static func random_look(rng: RandomNumberGenerator, sex := -1, job := "") -> Dictionary:
	var L := default_look()
	L.sex = sex if sex >= 0 else (1 if rng.randf() < 0.38 else 0)
	L.skin = rng.randi_range(0, 5)
	L.face = rng.randi_range(0, 5)
	L.height = rng.randf()
	L.build = rng.randf()
	L.hair_col = 0 if rng.randf() < 0.75 else rng.randi_range(1, 3)
	L.glasses = 0 if rng.randf() < 0.8 else [1, 3][rng.randi() % 2]
	L.watch = rng.randi_range(0, 3)
	L.top_col = rng.randi() % CLOTH.size()
	L.bot_col = [1, 3, 8, 9, 12][rng.randi() % 5]
	L.acc = 0
	if L.sex == 1:
		L.hair = 7 if rng.randf() < 0.6 else 8
		L.beard = 0
		if rng.randf() < 0.6:
			L.bottom = 4
			L.top = 8
			L.bot_col = rng.randi() % CLOTH.size()
		else:
			L.bottom = 5
			L.top = 9
		L.acc = 5 if rng.randf() < 0.3 else 0
		L.shoes = 4
	else:
		L.hair = [0, 1, 1, 2, 3, 4, 5, 6][rng.randi() % 8]
		L.beard = [0, 1, 2, 2, 2, 3, 4, 5, 6][rng.randi() % 9]
		L.top = [0, 0, 1, 2, 3, 3, 4, 5][rng.randi() % 8]
		L.bottom = [0, 0, 0, 1, 2, 3][rng.randi() % 6]
		if L.bottom == 3:
			L.bot_col = 0
		L.shoes = [0, 0, 1, 2, 4][rng.randi() % 5]
	match job:
		"police":
			L.top = 1; L.top_col = 1; L.bottom = 0; L.bot_col = 1; L.shoes = 1; L.acc = 2; L.beard = 2; L.sex = 0; L.hair = 0
		"conductor", "driver":
			L.top = 7; L.top_col = 1; L.bottom = 0; L.bot_col = 1
		"goon":
			L.top = 2; L.bottom = 2 if rng.randf() < 0.5 else 1; L.acc = 1; L.beard = [2, 3, 5][rng.randi() % 3]; L.sex = 0; L.build = rng.randf_range(0.6, 1.0)
		"neta":
			L.top = 5; L.top_col = 0; L.bottom = 3; L.bot_col = 0; L.acc = 3; L.sex = 0
	return L

static func make(l: Dictionary) -> Human:
	var h := Human.new()
	h.set_look(l)
	return h

static func _mesh(kind: String, a: float, b := 0.0, c := 0.0) -> Mesh:
	var key := "%s_%.2f_%.2f_%.2f" % [kind, a, b, c]
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match kind:
		"cap":
			var cm := CapsuleMesh.new()
			cm.radius = a
			cm.height = b + a * 2.0
			cm.radial_segments = 6
			cm.rings = 2
			m = cm
		"sph":
			var sm := SphereMesh.new()
			sm.radius = a
			sm.height = a * 2.0
			sm.radial_segments = 10
			sm.rings = 6
			m = sm
		"hemi":
			var hm := SphereMesh.new()
			hm.radius = a
			hm.height = a
			hm.is_hemisphere = true
			hm.radial_segments = 10
			hm.rings = 4
			m = hm
		"cone":
			var cy := CylinderMesh.new()
			cy.top_radius = a
			cy.bottom_radius = b
			cy.height = c
			cy.radial_segments = 8
			cy.rings = 1
			m = cy
		_:
			var bm := BoxMesh.new()
			bm.size = Vector3(a, b, c)
			m = bm
	_meshes[key] = m
	return m

func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, detail := false, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	if detail:
		mi.visibility_range_end = 16.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		mi.visibility_range_end = 110.0
	parent.add_child(mi)
	return mi

func _joint(parent: Node3D, nm: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)
	_j[nm] = n
	_rot[nm] = Vector3.ZERO
	return n

func set_look(l: Dictionary) -> void:
	look = default_look()
	for k in l:
		look[k] = l[k]
	for ch in get_children():
		ch.queue_free()
	_j.clear()
	_rot.clear()
	var female: bool = int(look.sex) == 1
	var hs := lerpf(0.93, 1.07, float(look.height)) * (0.94 if female else 1.0)
	var bd := lerpf(0.85, 1.3, float(look.build))
	var skin := Mats.col(SKIN[int(look.skin) % SKIN.size()], 0.7)
	var top_i := int(look.top)
	var tc: Color = CLOTH[int(look.top_col) % CLOTH.size()]
	var pattern := "plain"
	if top_i == 2: pattern = "print"
	elif top_i == 3: pattern = "check"
	elif top_i == 1 and int(look.top_col) % 3 == 2: pattern = "stripe"
	var top_mat: Material = Mats.cloth(pattern, tc) if pattern != "plain" else Mats.col(tc, 0.95)
	var bot_i := int(look.bottom)
	var bc: Color = CLOTH[int(look.bot_col) % CLOTH.size()]
	if bot_i == 1: bc = Color(0.2, 0.28, 0.45)
	if bot_i == 3: bc = Color(0.96, 0.95, 0.9)
	var bot_mat: Material = Mats.cloth("check", bc) if bot_i == 2 else Mats.col(bc, 0.95)
	var long_sleeve := top_i in [1, 5, 6, 9]
	var skirt := bot_i in [2, 3, 4]

	body = Node3D.new()
	body.name = "body"
	body.scale = Vector3(hs, hs, hs)
	add_child(body)
	hips = _joint(body, "hips", Vector3(0, 0.9, 0))
	var sw := 0.2 * bd * (0.88 if female else 1.0)      # half shoulder width
	var torso := _joint(hips, "torso", Vector3.ZERO)
	_part(torso, _mesh("box", 1, 1, 1), top_mat, Vector3(0, 0.3, 0), false, Vector3(sw * 2.0, 0.52, 0.19 * bd))
	_part(hips, _mesh("box", 1, 1, 1), bot_mat if not top_i in [5, 9] else top_mat, Vector3(0, -0.02, 0), false, Vector3(sw * 1.85, 0.2, 0.2 * bd))
	if look.build > 0.7 and not female:
		_part(torso, _mesh("sph", 0.5), top_mat, Vector3(0, 0.16, -0.07), false, Vector3(sw * 1.9, 0.3, 0.24 * bd))   # paunch
	if top_i in [5, 9]:   # kurta / kameez falls to the knee
		_part(hips, _mesh("box", 1, 1, 1), top_mat, Vector3(0, -0.25, 0), false, Vector3(sw * 1.9, 0.42, 0.2 * bd))
	if top_i == 6:
		_part(torso, _mesh("box", 1, 1, 1), Mats.col(tc.darkened(0.25)), Vector3(0, 0.36, -0.1), true, Vector3(sw * 1.2, 0.3, 0.02))
	if top_i in [0, 1, 2, 3, 6, 7]:   # collar + placket
		_part(torso, _mesh("box", 1, 1, 1), Mats.col(tc.darkened(0.12)), Vector3(0, 0.3, -0.097 * bd), true, Vector3(0.03, 0.5, 0.012))
	# head
	head = _joint(torso, "head", Vector3(0, 0.58, 0))
	_part(torso, _mesh("cone", 0.05, 0.06, 0.1), skin, Vector3(0, 0.58, 0))
	var face := int(look.face)
	var hsc: Vector3 = [Vector3(0.95, 1.05, 1.0), Vector3(1.1, 1.0, 1.05), Vector3(1.08, 1.02, 1.0), Vector3(0.94, 1.12, 1.0), Vector3(0.98, 1.06, 0.98), Vector3(1.03, 1.0, 1.02)][face % 6]
	_part(head, _mesh("sph", 0.115), skin, Vector3(0, 0.15, 0), false, hsc * Vector3(1, 1.18, 1.05))
	var dark := Mats.col(Color(0.05, 0.04, 0.04), 0.5)
	var eye_dx := 0.042 + 0.004 * (face % 3)
	for sd: float in [-1.0, 1.0]:
		_part(head, _mesh("sph", 0.012), dark, Vector3(sd * eye_dx, 0.17, -0.106), true)
		_part(head, _mesh("box", 0.04, 0.008 + 0.004 * (face % 2), 0.01), dark, Vector3(sd * eye_dx, 0.196, -0.108), true)
		_part(head, _mesh("sph", 0.022), skin, Vector3(sd * 0.118 * hsc.x, 0.15, 0.0), true)   # ears
	_part(head, _mesh("box", 0.024 + 0.006 * (face % 3), 0.045, 0.03), Mats.col(SKIN[int(look.skin) % SKIN.size()].darkened(0.08), 0.7), Vector3(0, 0.14, -0.12), true)
	_part(head, _mesh("box", 0.045, 0.008, 0.01), Mats.col(Color(0.35, 0.15, 0.13)), Vector3(0, 0.085, -0.108), true)
	_hair(skin)
	_beard()
	var gl := int(look.glasses)
	if gl > 0:
		var gm := Mats.col(Color(0.05, 0.05, 0.06, 0.85 if gl == 2 else 0.25), 0.2)
		for sd: float in [-1.0, 1.0]:
			_part(head, _mesh("box", 0.05, 0.036, 0.008), gm, Vector3(sd * eye_dx, 0.17, -0.122), true)
		_part(head, _mesh("box", 0.2, 0.008, 0.008), dark, Vector3(0, 0.182, -0.118), true)
	if female:
		_part(head, _mesh("sph", 0.007), Mats.col(Color(0.8, 0.1, 0.1)), Vector3(0, 0.205, -0.118), true)   # bindi
	# arms
	var ar := 0.042 * bd
	for sd: float in [-1.0, 1.0]:
		var side := "L" if sd < 0 else "R"
		var arm := _joint(torso, "arm" + side, Vector3(sd * (sw + ar * 0.6), 0.5, 0))
		_part(arm, _mesh("cap", snappedf(ar, 0.01), 0.24), top_mat, Vector3(0, -0.13, 0))
		var elbow := _joint(arm, "elbow" + side, Vector3(0, -0.27, 0))
		_part(elbow, _mesh("cap", snappedf(ar * 0.85, 0.01), 0.22), top_mat if long_sleeve else skin, Vector3(0, -0.12, 0))
		_part(elbow, _mesh("sph", 0.04), skin, Vector3(0, -0.27, 0), true)
		if sd < 0 and int(look.watch) > 0:
			var wc: Color = [Color.WHITE, Color(0.75, 0.76, 0.8), Color(0.9, 0.72, 0.2), Color(0.3, 0.18, 0.1)][int(look.watch)]
			_part(elbow, _mesh("cone", ar * 0.95, ar * 0.95, 0.025), Mats.col(wc, 0.3, 0.6), Vector3(0, -0.21, 0), true)
	# legs
	var lr := 0.062 * bd
	for sd: float in [-1.0, 1.0]:
		var side := "L" if sd < 0 else "R"
		var leg := _joint(hips, "leg" + side, Vector3(sd * 0.085 * bd, -0.05, 0))
		var knee := _joint(leg, "knee" + side, Vector3(0, -0.41, 0))
		var shoe_i := int(look.shoes)
		if not skirt:
			_part(leg, _mesh("cap", snappedf(lr, 0.01), 0.36), bot_mat, Vector3(0, -0.2, 0))
			_part(knee, _mesh("cap", snappedf(lr * 0.8, 0.01), 0.36), bot_mat, Vector3(0, -0.2, 0))
		else:
			_part(knee, _mesh("cap", snappedf(lr * 0.7, 0.01), 0.3), skin, Vector3(0, -0.22, 0))
		var sc: Color = [Color(0.25, 0.18, 0.12), Color(0.08, 0.07, 0.07), Color(0.9, 0.9, 0.88), SKIN[int(look.skin) % SKIN.size()], Color(0.4, 0.25, 0.15)][shoe_i % 5]
		_part(knee, _mesh("box", 0.085, 0.05 if shoe_i in [1, 2] else 0.03, 0.23), Mats.col(sc, 0.6), Vector3(0, -0.42, -0.05))
	if skirt:
		var hem := 0.62 if bot_i == 2 else 0.8
		_part(hips, _mesh("cone", sw * 0.95, sw * (1.15 if bot_i != 4 else 1.3), hem), bot_mat, Vector3(0, -hem * 0.5 + 0.05, 0), false, Vector3(1, 1, 0.72))
	if bot_i == 4:   # saree pallu over the left shoulder
		_part(torso, _mesh("box", 0.12, 0.6, 0.23 * bd), bot_mat, Vector3(-sw * 0.5, 0.32, 0), false).rotation.z = -0.35
	# accessories
	match int(look.acc):
		1:
			_part(torso, _mesh("box", 0.1, 0.012, 0.012), Mats.col(Color(0.95, 0.78, 0.2), 0.3, 0.8), Vector3(0, 0.47, -0.1 * bd), true)
		2:
			_part(head, _mesh("hemi", 0.125), Mats.col(Color(0.45, 0.4, 0.3)), Vector3(0, 0.2, 0), false, Vector3(1, 0.7, 1.05))
			_part(head, _mesh("box", 0.16, 0.012, 0.1), Mats.col(Color(0.1, 0.1, 0.1)), Vector3(0, 0.21, -0.14), true)
		3:
			_part(torso, _mesh("box", 0.1, 0.36, 0.215 * bd), Mats.cloth("check", Color(0.9, 0.3, 0.3)), Vector3(sw * 0.6, 0.38, 0), false)
		4:
			_part(torso, _mesh("box", 0.012, 0.5, 0.2 * bd + 0.01), Mats.col(Color(0.25, 0.15, 0.08)), Vector3(0.02, 0.3, 0), true).rotation.z = 0.55
			_part(hips, _mesh("box", 0.2, 0.16, 0.07), Mats.col(Color(0.3, 0.19, 0.1), 0.6), Vector3(-sw - 0.04, 0.02, -0.02))
		5:
			_part(head, _mesh("box", 0.14, 0.03, 0.03), Mats.col(Color(0.98, 0.97, 0.9)), Vector3(0, 0.16, 0.115), true)
	# blob shadow
	var sh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	sh.mesh = q
	sh.material_override = Mats.blob()
	sh.position.y = 0.03
	sh.visibility_range_end = 40.0
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sh)

func _hair(skin: Material) -> void:
	var hm := Mats.col(HAIR_COL[int(look.hair_col) % HAIR_COL.size()], 0.8)
	var st := int(look.hair)
	if st == 6:
		return
	var cap := _mesh("hemi", 0.123)
	match st:
		0:
			_part(head, cap, hm, Vector3(0, 0.165, 0.008), false, Vector3(1.0, 1.05, 1.08)).rotation.x = 0.25
		1:
			_part(head, cap, hm, Vector3(0, 0.165, 0.006), false, Vector3(1.03, 1.2, 1.1)).rotation.x = 0.2
			_part(head, _mesh("box", 0.15, 0.035, 0.06), hm, Vector3(0.03, 0.262, -0.075), true).rotation.z = -0.25
		2:
			_part(head, cap, hm, Vector3(0, 0.17, 0.01), false, Vector3(1.1, 1.45, 1.16)).rotation.x = 0.15
			_part(head, _mesh("box", 0.2, 0.12, 0.06), hm, Vector3(0, 0.13, 0.105), true)
		3:
			_part(head, _mesh("box", 0.235, 0.09, 0.1), hm, Vector3(0, 0.15, 0.07), false)
		4:
			_part(head, cap, hm, Vector3(0, 0.165, 0.008), false, Vector3(1.06, 1.25, 1.12)).rotation.x = 0.2
			_part(head, _mesh("box", 0.22, 0.2, 0.06), hm, Vector3(0, 0.08, 0.105), false)
		5:
			_part(head, _mesh("sph", 0.14), hm, Vector3(0, 0.2, 0.02), false, Vector3(1.05, 0.95, 1.05))
		7:
			_part(head, cap, hm, Vector3(0, 0.165, 0.008), false, Vector3(1.04, 1.15, 1.1)).rotation.x = 0.3
			_part(head, _mesh("box", 0.055, 0.55, 0.05), hm, Vector3(0, -0.15, 0.12), false)
		8:
			_part(head, cap, hm, Vector3(0, 0.165, 0.008), false, Vector3(1.04, 1.15, 1.1)).rotation.x = 0.3
			_part(head, _mesh("sph", 0.06), hm, Vector3(0, 0.13, 0.13), false)

func _beard() -> void:
	var b := int(look.beard)
	if b == 0:
		return
	var hm := Mats.col(HAIR_COL[int(look.hair_col) % HAIR_COL.size()].lerp(Color(0.1, 0.08, 0.08), 0.5), 0.9)
	if b in [1, 2, 3, 5, 6]:
		var th := 0.012 if b == 1 else 0.024
		_part(head, _mesh("box", 0.07 if b != 3 else 0.11, th, 0.016), hm, Vector3(0, 0.107, -0.112), true)
	if b == 3:
		for sd: float in [-1.0, 1.0]:
			_part(head, _mesh("box", 0.014, 0.04, 0.014), hm, Vector3(sd * 0.055, 0.092, -0.108), true)
	if b == 4:
		_part(head, _mesh("sph", 0.1), Mats.col(Color(0.1, 0.08, 0.08, 0.35)), Vector3(0, 0.09, -0.02), true, Vector3(1.08, 0.8, 1.12))
	if b == 5:
		_part(head, _mesh("sph", 0.1), hm, Vector3(0, 0.075, -0.02), false, Vector3(1.1, 0.85, 1.14))
	if b == 6:
		_part(head, _mesh("box", 0.06, 0.05, 0.03), hm, Vector3(0, 0.055, -0.1), true)

# ------------------------------------------------------------------ animation
func play_once(nm: String, dur := 0.45) -> void:
	_shot = nm
	_shot_t = dur

func _tg(nm: String, v: Vector3, k: float) -> void:
	var cur: Vector3 = _rot[nm]
	cur = cur.lerp(v, k)
	_rot[nm] = cur
	_j[nm].rotation = cur

func _process(delta: float) -> void:
	if body == null or _j.is_empty():
		return
	_t += delta
	var k := 1.0 - exp(-12.0 * delta)
	var hip_y := 0.9
	var body_rx := 0.0
	var body_y := 0.0
	var aL := Vector3.ZERO; var aR := Vector3.ZERO; var eL := Vector3.ZERO; var eR := Vector3.ZERO
	var lL := Vector3.ZERO; var lR := Vector3.ZERO; var kL := Vector3.ZERO; var kR := Vector3.ZERO
	var tor := Vector3.ZERO; var hd := Vector3.ZERO
	var breath := sin(_t * 1.6) * 0.012
	match state:
		"sit", "drive":
			hip_y = 0.52
			lL.x = 1.45; lR.x = 1.45; kL.x = -1.5; kR.x = -1.5
			if state == "drive":
				aL.x = 1.05; aR.x = 1.05; eL.x = 0.35; eR.x = 0.35
			else:
				aL.x = 0.35; aR.x = 0.35; eL.x = 0.9; eR.x = 0.9
				hd.y = sin(_t * 0.4 + position.x) * 0.25
		"crouch":
			hip_y = 0.58
			lL.x = 1.15; lR.x = 0.6; kL.x = -1.9; kR.x = -1.7
			tor.x = -0.35
			if speed > 0.3:
				_phase += delta * 7.0
				lL.x += sin(_phase) * 0.35; lR.x -= sin(_phase) * 0.35
		"ko":
			body_rx = 1.45
			body_y = 0.16
			aL.z = -1.2; aR.z = 1.2; lL.x = 0.15; lR.x = -0.1
		"air":
			lL.x = 0.5; lR.x = -0.2; kL.x = -0.7; kR.x = -0.3; aL.z = -0.5; aR.z = 0.5
		_:
			if speed > 0.25:
				var run := clampf((speed - 2.2) / 3.0, 0.0, 1.0)
				_phase += delta * (5.2 + speed * 1.55)
				var amp := lerpf(0.5, 0.95, run)
				var sp := sin(_phase)
				lL.x = sp * amp; lR.x = -sp * amp
				kL.x = -maxf(0.0, sin(_phase - 1.3)) * lerpf(0.9, 1.7, run) - 0.05
				kR.x = -maxf(0.0, sin(_phase - 1.3 + PI)) * lerpf(0.9, 1.7, run) - 0.05
				aL.x = -sp * amp * 0.8; aR.x = sp * amp * 0.8
				eL.x = lerpf(0.25, 1.3, run); eR.x = eL.x
				tor.x = -lerpf(0.03, 0.22, run)
				tor.y = sp * 0.08
				hip_y += absf(cos(_phase)) * lerpf(0.02, 0.05, run) - 0.02
			else:
				aL.z = -0.06; aR.z = 0.06; eL.x = 0.12; eR.x = 0.12
				tor.x = breath
				hd.y = sin(_t * 0.5 + position.z) * 0.12
	if state == "talk" or talk_t > 0.0:
		talk_t = maxf(0.0, talk_t - delta)
		aR.x = 0.55 + sin(_t * 4.0) * 0.18; eR.x = 1.25 + sin(_t * 5.3) * 0.25; aR.z = 0.15
		hd.x = sin(_t * 3.1) * 0.06
	if _shot_t > 0.0:
		_shot_t -= delta
		k = 1.0 - exp(-26.0 * delta)
		match _shot:
			"punch":
				aR.x = 1.5; eR.x = 0.15; tor.y = 0.45; aL.x = 0.6; eL.x = 1.6
			"hit":
				tor.x = 0.35; hd.x = 0.3
			"wave":
				aR.z = 2.6; eR.z = sin(_t * 12.0) * 0.5
			"give":
				aR.x = 1.2; eR.x = 0.4
			"whistle":
				aR.x = 1.3; eR.x = 2.1
			"namaste":
				aL.x = 0.9; aR.x = 0.9; eL.x = 1.5; eR.x = 1.5; aL.z = 0.25; aR.z = -0.25; hd.x = -0.2
	_tg("armL", aL, k); _tg("armR", aR, k); _tg("elbowL", eL, k); _tg("elbowR", eR, k)
	_tg("legL", lL, k); _tg("legR", lR, k); _tg("kneeL", kL, k); _tg("kneeR", kR, k)
	_tg("torso", tor, k); _tg("head", hd, k)
	hips.position.y = lerpf(hips.position.y, hip_y, k)
	body.rotation.x = lerpf(body.rotation.x, body_rx, k * 0.6)
	body.position.y = lerpf(body.position.y, body_y, k)
