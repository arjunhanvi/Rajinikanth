class_name Human
extends Node3D
## A procedurally built, procedurally animated person. Used for the player and
## every NPC. Appearance comes from a plain "look" dictionary (see default_look).

const SKIN := [Color(0.93, 0.76, 0.6), Color(0.85, 0.65, 0.48), Color(0.74, 0.54, 0.38), Color(0.62, 0.43, 0.29), Color(0.5, 0.34, 0.23), Color(0.38, 0.26, 0.18)]
const HAIR_COL := [Color(0.06, 0.05, 0.05), Color(0.14, 0.1, 0.08), Color(0.45, 0.45, 0.46), Color(0.8, 0.8, 0.8), Color(0.3, 0.15, 0.08)]
const CLOTH := [Color(0.95, 0.95, 0.93), Color(0.76, 0.66, 0.5), Color(0.55, 0.7, 0.85), Color(0.2, 0.3, 0.5), Color(0.75, 0.2, 0.2), Color(0.25, 0.45, 0.3),
	Color(0.9, 0.75, 0.25), Color(0.5, 0.3, 0.5), Color(0.15, 0.15, 0.17), Color(0.45, 0.32, 0.22), Color(0.9, 0.55, 0.6), Color(0.35, 0.6, 0.6), Color(0.6, 0.6, 0.62), Color(0.95, 0.5, 0.15)]
const TOPS := ["Formal shirt (half sleeve)", "Formal shirt (full sleeve)", "Printed shirt", "Checked shirt", "T-shirt", "Kurta", "Safari jacket", "Conductor khaki", "Blouse", "Kameez", "Banian", "Advocate's coat"]
const BOTTOMS := ["Trousers", "Jeans", "Lungi", "Panche", "Saree", "Salwar"]
const HAIRS := ["Short crop", "Side parting", "Thick wave", "Receding", "Step cut", "Curly", "Bald", "Long plait", "Bun"]
const BEARDS := ["Clean shave", "Thin moustache", "Thick moustache", "Handlebar", "Stubble", "Full beard", "French beard"]
const FACES := ["Lean", "Round", "Square", "Long", "Sharp", "Soft"]
const SHOES := ["Chappals", "Leather shoes", "Canvas shoes", "Barefoot", "Sandals"]
const GLASSES := ["None", "Square frames", "Aviator shades", "Round frames"]
const WATCHES := ["None", "Steel watch", "Gold watch", "Leather strap"]
const ACCS := ["None", "Gold chain", "Cap", "Shoulder towel", "Ticket bag", "Jasmine flowers", "Shoulder bag", "Cloth bag"]

static var _meshes := {}

var look := {}
var state := "idle"        # idle, walk, sit, drive, talk, crouch, ko, air
var speed := 0.0           # horizontal speed, drives the walk cycle
var talk_t := 0.0
var _phase := 0.0
var _t := 0.0
var _shot := ""
var _shot_t := 0.0
var activity := ""         # eat, tea, read, phone, work, wait, carry, argue, laugh, listen, sweep
var look_target = null     # Vector3 the head turns toward (conversation partner, passing bus...)
var stoop := 0.0
var emotion := 0.0         # -1 angry .. +1 pleased: moves the brows and mouth
var _props := {}
var _brows: Array = []
var _mouth: MeshInstance3D
var _skip := 0
var _seed := randf() * 10.0
static var cam_pos := Vector3.ZERO
var detail := 1            # 2 = hero (player, named cast), 1 = ordinary
var walk: Array = [1.0, 1.0, 1.0, 0.0]   # personal gait: stride, sway, arm swing, lean
var mood := ""             # surprise, nervous, angry, sad, tired, smile ("" = neutral)
var _lids: Array = []
var _pupils: Array = []
var _teeth: MeshInstance3D
var _skirt: MeshInstance3D
var _blink := 2.0
var _blink_t := 0.0
var _dart := Vector2.ZERO
var _last_yaw := 0.0
var _tilt := 0.0
var _j := {}               # joints
var _rot := {}             # current joint rotations (Vector3)
var body: Node3D
var hips: Node3D
var head: Node3D

static func default_look() -> Dictionary:
	return {"sex": 0, "skin": 2, "face": 0, "hair": 1, "hair_col": 0, "beard": 2, "height": 0.5, "build": 0.4,
		"top": 7, "top_col": 1, "bottom": 0, "bot_col": 1, "shoes": 0, "glasses": 0, "watch": 3, "acc": 4, "age": 0.3, "tilak": 0}

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
	L.age = clampf(rng.randfn(0.42, 0.2), 0.16, 1.0)
	if L.age > 0.72:
		L.hair_col = [2, 2, 3][rng.randi() % 3]
		if L.sex == 0 and rng.randf() < 0.5:
			L.hair = 3
	match job:
		"student":
			L.age = 0.05 if rng.randf() < 0.6 else 0.2
			L.top = 0; L.top_col = 0; L.beard = 0; L.acc = 6; L.glasses = 0; L.build = rng.randf_range(0.1, 0.4); L.hair_col = 0
			if L.sex == 1:
				L.top = 9; L.top_col = 2; L.bottom = 5; L.bot_col = 0; L.hair = 7
			else:
				L.bottom = 0; L.bot_col = [3, 9, 12][rng.randi() % 3]; L.hair = 0; L.shoes = 2
		"office":
			if L.sex == 0:
				L.top = [0, 1, 1][rng.randi() % 3]; L.top_col = [0, 2, 12, 0, 11][rng.randi() % 5]; L.bottom = 0; L.bot_col = [8, 3, 12, 9][rng.randi() % 4]; L.shoes = 1; L.acc = 0
		"vendor":
			if L.sex == 0:
				L.top = [10, 4, 3][rng.randi() % 3]; L.top_col = [0, 12, 1][rng.randi() % 3]; L.bottom = 2; L.bot_col = rng.randi() % CLOTH.size(); L.acc = 3; L.shoes = [0, 3][rng.randi() % 2]
			else:
				L.acc = 5; L.top = 8; L.bottom = 4
		"mechanic":
			L.sex = 0; L.top = 4; L.top_col = [3, 8, 12][rng.randi() % 3]; L.bottom = 0; L.bot_col = 8; L.shoes = 0; L.acc = 0; L.hair = [0, 1, 5][rng.randi() % 3]; L.age = rng.randf_range(0.18, 0.5); L.hair_col = 0
		"coolie":
			L.sex = 0; L.top = 0; L.top_col = 4; L.bottom = 2; L.bot_col = 9; L.acc = 3; L.shoes = 3; L.build = rng.randf_range(0.3, 0.7)
		"priest":
			L.sex = 0; L.top = 10; L.top_col = 0; L.bottom = 3; L.bot_col = 0; L.acc = 3; L.shoes = 3; L.hair = 6; L.beard = 0; L.tilak = 1
		"elder":
			L.age = rng.randf_range(0.8, 1.0); L.hair_col = 3
			if L.sex == 0:
				L.top = 5; L.top_col = 0; L.bottom = 3; L.bot_col = 0; L.hair = 3; L.glasses = 1
		"shopper":
			L.acc = 7 if L.sex == 1 or rng.randf() < 0.4 else L.acc
		"police":
			L.top = 1; L.top_col = 1; L.bottom = 0; L.bot_col = 1; L.shoes = 1; L.acc = 2; L.beard = 2; L.sex = 0; L.hair = 0
		"conductor", "driver":
			L.top = 7; L.top_col = 1; L.bottom = 0; L.bot_col = 1
		"goon":
			L.top = 2; L.bottom = 2 if rng.randf() < 0.5 else 1; L.acc = 1; L.beard = [2, 3, 5][rng.randi() % 3]; L.sex = 0; L.build = rng.randf_range(0.6, 1.0)
		"neta":
			L.top = 5; L.top_col = 0; L.bottom = 3; L.bot_col = 0; L.acc = 3; L.sex = 0
	return L

static func make(l: Dictionary, lod := 1) -> Human:
	var h := Human.new()
	h.detail = lod
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
	_props.clear()
	_lids.clear()
	_pupils.clear()
	var arng := RandomNumberGenerator.new()
	arng.seed = hash(str(look))          # every face is slightly lopsided in its own way
	var asym := Vector3(arng.randf_range(-1, 1), arng.randf_range(-1, 1), arng.randf_range(-1, 1))
	var female: bool = int(look.sex) == 1
	var age := float(look.get("age", 0.4))
	var hs := lerpf(0.93, 1.07, float(look.height)) * (0.94 if female else 1.0)
	if age < 0.12:
		hs *= 0.8          # school-age
	var bd := lerpf(0.85, 1.3, float(look.build))
	stoop = clampf((age - 0.72) * 0.9, 0.0, 0.25)
	var skin_c: Color = SKIN[int(look.skin) % SKIN.size()]
	var skin: Material = Mats.skin(skin_c)
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
	if top_i == 11:
		tc = Color(0.07, 0.07, 0.08)
		top_mat = Mats.cloth("plain", tc)
	elif pattern == "plain":
		top_mat = Mats.cloth("plain", tc)
	var long_sleeve := top_i in [1, 5, 6, 9, 11]
	var sleeveless := top_i == 10
	var skirt := bot_i in [2, 3, 4]
	var tucked := top_i in [0, 1, 7] and not skirt
	var dark := Mats.col(Color(0.05, 0.04, 0.04), 0.5)

	body = Node3D.new()
	body.name = "body"
	body.scale = Vector3(hs, hs, hs)
	add_child(body)
	hips = _joint(body, "hips", Vector3(0, 0.9, 0))
	var sw := 0.19 * bd * (0.86 if female else 1.0)      # half shoulder width
	var wst := sw * (0.78 if not female else 0.72) * lerpf(1.0, 1.25, clampf(float(look.build) - 0.5, 0.0, 0.5) * 2.0)
	var torso := _joint(hips, "torso", Vector3.ZERO)
	var flat := Vector3(1, 1, 0.56 * lerpf(0.95, 1.2, float(look.build)))
	# chest tapers to the waist; shoulders are rounded off; hips flare slightly
	_part(torso, _mesh("cone", snappedf(sw * 1.02, 0.01), snappedf(wst, 0.01), 0.4), top_mat, Vector3(0, 0.34, 0), false, flat)
	_part(torso, _mesh("sph", snappedf(sw * 1.02, 0.01)), top_mat, Vector3(0, 0.54, 0), false, Vector3(1, 0.22, flat.z))
	_part(torso, _mesh("cone", snappedf(wst, 0.01), snappedf(wst * 1.06, 0.01), 0.16), top_mat if not tucked else bot_mat, Vector3(0, 0.07, 0), false, flat)
	_part(hips, _mesh("cone", snappedf(wst * 1.06, 0.01), snappedf(wst * (1.12 if not female else 1.25), 0.01), 0.2), bot_mat if not top_i in [5, 9] else top_mat, Vector3(0, -0.04, 0), false, flat)
	if tucked:
		_part(torso, _mesh("cone", snappedf(wst * 1.03, 0.01), snappedf(wst * 1.03, 0.01), 0.035), Mats.col(Color(0.12, 0.08, 0.05), 0.5), Vector3(0, 0.145, 0), true, flat)   # belt
	elif top_i in [2, 3, 4]:
		_part(hips, _mesh("cone", snappedf(wst * 1.08, 0.01), snappedf(wst * 1.14, 0.01), 0.12), top_mat, Vector3(0, 0.02, 0), false, flat)                                  # shirt worn out
	var fat := float(look.get("fat", 0.0))
	if (look.build > 0.68 or fat > 0.0) and not female:
		_part(torso, _mesh("sph", 0.5), top_mat, Vector3(0, 0.2 - fat * 0.02, -0.05 - fat * 0.05), false, Vector3(wst * (2.0 + fat * 0.5), 0.3 + fat * 0.1, 0.27 * bd + fat * 0.14))   # paunch
	if top_i == 11:
		_part(torso, _mesh("box", 0.05, 0.11, 0.01), Mats.col(Color(0.96, 0.96, 0.94)), Vector3(0, 0.52, -0.105), false)   # advocate's bands
	if detail >= 2 and top_i in [0, 1, 2, 3, 7]:
		for bi in 4:
			_part(torso, _mesh("sph", 0.006), Mats.col(Color(0.9, 0.9, 0.85)), Vector3(0, 0.5 - bi * 0.085, -0.113 * flat.z / 0.56), true)   # buttons
	if female:
		_part(torso, _mesh("sph", 0.5), top_mat, Vector3(0, 0.42, -0.045), false, Vector3(sw * 1.7, 0.16, 0.2))
	if top_i in [5, 9]:   # kurta / kameez falls to the knee
		_part(hips, _mesh("cone", snappedf(wst * 1.13, 0.01), snappedf(wst * 1.3, 0.01), 0.42), top_mat, Vector3(0, -0.3, 0), false, flat)
	if top_i in [0, 1, 2, 3, 6, 7]:   # collar, placket, pocket
		for sd: float in [-1.0, 1.0]:
			_part(torso, _mesh("box", 0.07, 0.022, 0.05), top_mat, Vector3(sd * 0.045, 0.565, -0.07), true).rotation = Vector3(0.3, sd * 0.5, sd * 0.35)
		_part(torso, _mesh("box", 0.028, 0.4, 0.008), Mats.col(tc.darkened(0.1)), Vector3(0, 0.35, -0.108 * flat.z / 0.56), true)
		_part(torso, _mesh("box", 0.07, 0.07, 0.008), Mats.col(tc.darkened(0.08)), Vector3(-sw * 0.5, 0.42, -0.1 * flat.z / 0.56), true)
	if top_i == 6:
		for sd: float in [-1.0, 1.0]:
			_part(torso, _mesh("box", 0.08, 0.06, 0.01), Mats.col(tc.darkened(0.2)), Vector3(sd * sw * 0.5, 0.26, -0.1), true)
	# head
	head = _joint(torso, "head", Vector3(0, 0.6, 0))
	_part(torso, _mesh("cone", 0.046, 0.055, 0.1), skin, Vector3(0, 0.6, 0.005))
	var face := int(look.face)
	var hsc: Vector3 = [Vector3(0.95, 1.05, 1.0), Vector3(1.1, 1.0, 1.05), Vector3(1.08, 1.02, 1.0), Vector3(0.94, 1.12, 1.0), Vector3(0.98, 1.06, 0.98), Vector3(1.03, 1.0, 1.02)][face % 6]
	if age < 0.12:
		hsc *= 1.08
	_part(head, _mesh("sph", 0.112), skin, Vector3(0, 0.16, 0.006), false, hsc * Vector3(1, 1.12, 1.08))                       # cranium
	var jaw_w: float = [0.78, 0.98, 1.0, 0.8, 0.74, 0.9][face % 6] + fat * 0.22
	if fat > 0.5:
		_part(head, _mesh("sph", 0.07), skin, Vector3(0, 0.06, -0.035), true, Vector3(1.25, 0.6, 1.0))    # double chin
	_part(head, _mesh("sph", 0.09), skin, Vector3(0, 0.095, -0.022), false, Vector3(jaw_w * hsc.x, 0.95, 1.0))                  # jaw and chin
	var eye_dx := 0.04 + 0.003 * (face % 3)
	var white := Mats.col(Color(0.93, 0.92, 0.88), 0.4)
	for sd: float in [-1.0, 1.0]:
		_part(head, _mesh("sph", 0.017), white, Vector3(sd * eye_dx, 0.172, -0.098), true, Vector3(1.25, 0.7, 0.6))
		var eye_y := 0.172 + (asym.x * 0.003 if sd > 0 else 0.0)
		_part(head, _mesh("sph", 0.0105), Mats.col(Color(0.22, 0.12, 0.06), 0.3), Vector3(sd * eye_dx, eye_y, -0.1045), true, Vector3(1, 1, 0.5))   # iris
		var pup := _part(head, _mesh("sph", 0.0062), dark, Vector3(sd * eye_dx, eye_y, -0.108), true, Vector3(1, 1, 0.5))
		pup.set_meta("home", pup.position)
		_pupils.append(pup)
		_part(pup, _mesh("sph", 0.002), Mats.glow(Color(1, 1, 1), 1.0), Vector3(0.003, 0.003, -0.004), true)             # catch-light
		var lid := _part(head, _mesh("sph", 0.0185), skin, Vector3(sd * eye_dx, eye_y + 0.011, -0.097), true, Vector3(1.3, 0.1, 0.75))
		lid.set_meta("y", lid.position.y)
		_lids.append(lid)
		if detail >= 2:
			_part(head, _mesh("box", 0.036, 0.003, 0.006), dark, Vector3(sd * eye_dx, eye_y + 0.0115, -0.112), true)       # lash line
		var brow := _part(head, _mesh("box", 0.042, 0.007 + 0.004 * (face % 2), 0.012), dark, Vector3(sd * eye_dx, 0.196, -0.107), true)
		brow.rotation.z = -sd * 0.12
		_brows.append(brow)
		_part(head, _mesh("sph", 0.024), skin, Vector3(sd * 0.112 * hsc.x, 0.155, 0.008), true, Vector3(0.45, 1.0, 0.8))         # ears
	var nose := _part(head, _mesh("cone", 0.004, 0.017 + 0.003 * (face % 3), 0.05), Mats.col(skin_c.darkened(0.06), 0.62), Vector3(0, 0.148, -0.117), true)
	nose.rotation.x = -0.35
	nose.position.x = asym.y * 0.003
	_mouth = _part(head, _mesh("box", 0.042, 0.009, 0.01), Mats.col(skin_c.darkened(0.35).lerp(Color(0.5, 0.15, 0.15), 0.4)), Vector3(asym.z * 0.003, 0.098, -0.103), true)
	_mouth.rotation.z = asym.z * 0.06
	_teeth = _part(head, _mesh("box", 0.03, 0.007, 0.006), Mats.col(Color(0.93, 0.91, 0.84), 0.4), Vector3(asym.z * 0.003, 0.1, -0.1), true)
	_teeth.visible = false
	if float(look.get("age", 0.4)) > 0.6:      # lines of a lived-in face
		for sd: float in [-1.0, 1.0]:
			_part(head, _mesh("box", 0.003, 0.035, 0.004), Mats.col(skin_c.darkened(0.22)), Vector3(sd * 0.034, 0.115, -0.103), true).rotation.z = sd * 0.35
		_part(head, _mesh("box", 0.07, 0.003, 0.004), Mats.col(skin_c.darkened(0.18)), Vector3(0, 0.222, -0.1), true)
	_brows = _brows.slice(_brows.size() - 2)
	_hair(skin)
	_beard()
	var gl := int(look.glasses)
	if gl > 0:
		var gm := Mats.col(Color(0.05, 0.05, 0.06, 0.85 if gl == 2 else 0.22), 0.2)
		for sd: float in [-1.0, 1.0]:
			_part(head, _mesh("box", 0.05, 0.036, 0.008), gm, Vector3(sd * eye_dx, 0.172, -0.118), true)
			_part(head, _mesh("box", 0.006, 0.006, 0.11), dark, Vector3(sd * 0.105, 0.176, -0.06), true)
		_part(head, _mesh("box", 0.2, 0.007, 0.007), dark, Vector3(0, 0.186, -0.116), true)
	if female:
		_part(head, _mesh("sph", 0.007), Mats.col(Color(0.8, 0.1, 0.1)), Vector3(0, 0.207, -0.112), true)   # bindi
	if int(look.get("tilak", 0)) == 1:
		_part(head, _mesh("box", 0.05, 0.012, 0.004), Mats.col(Color(0.92, 0.9, 0.85)), Vector3(0, 0.215, -0.108), true)       # vibhuti
	# arms
	var ar := 0.04 * bd
	for sd: float in [-1.0, 1.0]:
		var side := "L" if sd < 0 else "R"
		var arm := _joint(torso, "arm" + side, Vector3(sd * (sw + ar * 0.45), 0.51, 0))
		_part(arm, _mesh("sph", snappedf(ar * 1.25, 0.01)), top_mat if not sleeveless else skin, Vector3(0, -0.01, 0))           # shoulder
		_part(arm, _mesh("cap", snappedf(ar, 0.01), 0.24), skin if not long_sleeve else top_mat, Vector3(0, -0.13, 0))
		if not long_sleeve and not sleeveless:
			_part(arm, _mesh("cone", snappedf(ar * 1.2, 0.01), snappedf(ar * 1.35, 0.01), 0.15), top_mat, Vector3(0, -0.085, 0)) # half sleeve
		var elbow := _joint(arm, "elbow" + side, Vector3(0, -0.27, 0))
		_part(elbow, _mesh("cap", snappedf(ar * 0.82, 0.01), 0.21), top_mat if long_sleeve else skin, Vector3(0, -0.115, 0))
		_part(elbow, _mesh("sph", 0.036), skin, Vector3(0, -0.265, -0.005), true, Vector3(0.6, 1.25, 1.0))                     # hand
		_part(elbow, _mesh("box", 0.014, 0.04, 0.022), skin, Vector3(-sd * 0.022, -0.25, -0.028), true)                        # thumb
		if detail >= 2:
			for fi in 4:
				_part(elbow, _mesh("box", 0.011, 0.05, 0.012), skin, Vector3(0.0, -0.315, -0.022 + fi * 0.0135), true)             # fingers
			_part(elbow, _mesh("box", 0.03, 0.006, 0.056), Mats.col(skin_c.darkened(0.12)), Vector3(0.001, -0.288, -0.002), true)  # knuckles
		_j["hand" + side] = elbow
		if sd < 0 and int(look.watch) > 0:
			var wc: Color = [Color.WHITE, Color(0.75, 0.76, 0.8), Color(0.9, 0.72, 0.2), Color(0.3, 0.18, 0.1)][int(look.watch)]
			_part(elbow, _mesh("cone", ar * 0.92, ar * 0.92, 0.025), Mats.col(wc, 0.3, 0.6), Vector3(0, -0.2, 0), true)
		if female and sd > 0:
			_part(elbow, _mesh("cone", ar * 0.9, ar * 0.9, 0.03), Mats.col([Color(0.8, 0.1, 0.15), Color(0.9, 0.72, 0.2), Color(0.1, 0.5, 0.3)][int(look.skin) % 3], 0.3, 0.4), Vector3(0, -0.19, 0), true)   # bangles
	# legs
	var lr := 0.06 * bd
	for sd: float in [-1.0, 1.0]:
		var side := "L" if sd < 0 else "R"
		var leg := _joint(hips, "leg" + side, Vector3(sd * 0.08 * bd, -0.06, 0))
		var knee := _joint(leg, "knee" + side, Vector3(0, -0.41, 0))
		var shoe_i := int(look.shoes)
		if not skirt:
			_part(leg, _mesh("cone", snappedf(lr * 1.08, 0.01), snappedf(lr * 0.86, 0.01), 0.44), bot_mat, Vector3(0, -0.2, 0))
			_part(knee, _mesh("cone", snappedf(lr * 0.86, 0.01), snappedf(lr * 0.72, 0.01), 0.42), bot_mat, Vector3(0, -0.2, 0))
		else:
			_part(knee, _mesh("cap", snappedf(lr * 0.62, 0.01), 0.3), skin, Vector3(0, -0.22, 0))
		var sc: Color = [Color(0.25, 0.18, 0.12), Color(0.08, 0.07, 0.07), Color(0.9, 0.9, 0.88), skin_c, Color(0.4, 0.25, 0.15)][shoe_i % 5]
		if shoe_i in [1, 2]:
			_part(knee, _mesh("sph", 0.05), Mats.col(sc, 0.5), Vector3(0, -0.425, -0.055), false, Vector3(0.9, 0.72, 2.3))
		else:
			_part(knee, _mesh("sph", 0.045), skin, Vector3(0, -0.435, -0.05), false, Vector3(0.9, 0.5, 2.2))                    # foot
			if shoe_i != 3:
				_part(knee, _mesh("box", 0.09, 0.016, 0.22), Mats.col(sc, 0.7), Vector3(0, -0.455, -0.05))                     # sole
				_part(knee, _mesh("box", 0.085, 0.012, 0.025), Mats.col(sc.darkened(0.2), 0.7), Vector3(0, -0.425, -0.085), true)
	if skirt:
		var hem := 0.62 if bot_i == 2 else 0.8
		_skirt = _part(hips, _mesh("cone", snappedf(wst * 1.1, 0.01), snappedf(sw * (1.2 if bot_i != 4 else 1.35), 0.01), hem), bot_mat, Vector3(0, -hem * 0.5 + 0.05, 0), false, Vector3(1, 1, 0.74))
		if bot_i == 4:
			_part(hips, _mesh("cone", snappedf(sw * 1.37, 0.01), snappedf(sw * 1.37, 0.01), 0.05), Mats.col(bc.darkened(0.3).lerp(Color(0.9, 0.75, 0.2), 0.5)), Vector3(0, -hem + 0.08, 0), false, Vector3(1, 1, 0.74))   # zari border
	if bot_i == 4:   # saree pallu over the left shoulder
		_part(torso, _mesh("box", 0.09, 0.56, 0.215 * bd), bot_mat, Vector3(-sw * 0.3, 0.34, 0), false).rotation.z = -0.5
		_part(torso, _mesh("box", 0.11, 0.42, 0.02), bot_mat, Vector3(-sw * 0.7, 0.3, 0.115), false)
	if top_i == 9:   # dupatta
		_part(torso, _mesh("box", sw * 1.7, 0.05, 0.03), Mats.col(bc.lightened(0.2)), Vector3(0, 0.5, -0.1), false)
		for sd: float in [-1.0, 1.0]:
			_part(torso, _mesh("box", 0.07, 0.5, 0.02), Mats.col(bc.lightened(0.2)), Vector3(sd * sw * 0.8, 0.3, 0.1), false)
	# accessories
	match int(look.acc):
		1:
			_part(torso, _mesh("box", 0.1, 0.012, 0.012), Mats.col(Color(0.95, 0.78, 0.2), 0.3, 0.8), Vector3(0, 0.5, -0.1 * bd), true)
		2:
			_part(head, _mesh("hemi", 0.122), Mats.col(Color(0.45, 0.4, 0.3)), Vector3(0, 0.205, 0.004), false, Vector3(1, 0.7, 1.08))
			_part(head, _mesh("box", 0.15, 0.012, 0.09), Mats.col(Color(0.1, 0.1, 0.1)), Vector3(0, 0.215, -0.14), true)
		3:
			_part(torso, _mesh("box", 0.1, 0.36, 0.2 * bd), Mats.cloth("check", Color(0.9, 0.3, 0.3)), Vector3(sw * 0.6, 0.4, 0), false)
		4:
			_part(torso, _mesh("box", 0.012, 0.52, 0.2 * bd + 0.01), Mats.col(Color(0.25, 0.15, 0.08)), Vector3(0.02, 0.32, 0), true).rotation.z = 0.55
			_part(hips, _mesh("box", 0.2, 0.16, 0.07), Mats.col(Color(0.3, 0.19, 0.1), 0.6), Vector3(-sw - 0.03, 0.02, -0.02))
		5:
			_part(head, _mesh("box", 0.14, 0.03, 0.03), Mats.col(Color(0.98, 0.97, 0.9)), Vector3(0, 0.16, 0.118), true)
		6:   # school / college bag
			_part(torso, _mesh("box", 0.26, 0.32, 0.12), Mats.col(Color(0.15, 0.25, 0.45)), Vector3(0, 0.35, 0.16), false)
		7:   # cloth shopping bag (butti)
			_part(_j["handL"], _mesh("box", 0.06, 0.26, 0.22), Mats.col(Color(0.8, 0.75, 0.5)), Vector3(0, -0.42, 0), false)
	# hand-held props, shown by activity
	_props["glass"] = _part(_j["handR"], _mesh("cone", 0.022, 0.017, 0.06), Mats.col(Color(0.75, 0.6, 0.4, 0.8), 0.2), Vector3(0, -0.28, -0.05), true)
	_props["paper"] = _part(_j["handR"], _mesh("box", 0.3, 0.004, 0.22), Mats.col(Color(0.88, 0.86, 0.8)), Vector3(-0.1, -0.3, -0.06), true)
	_props["phone"] = _part(_j["handR"], _mesh("box", 0.035, 0.16, 0.04), Mats.col(Color(0.08, 0.08, 0.08)), Vector3(0, -0.3, -0.03), true)
	_props["tool"] = _part(_j["handR"], _mesh("box", 0.025, 0.22, 0.025), Mats.col(Color(0.55, 0.56, 0.6), 0.3, 0.7), Vector3(0, -0.36, -0.02), true)
	var tray := _part(torso, _mesh("box", 0.4, 0.012, 0.28), Mats.col(Color(0.65, 0.66, 0.7), 0.3, 0.8), Vector3(0, 0.24, -0.36), false)
	for gi in 4:
		_part(tray, _mesh("cone", 0.03, 0.026, 0.085), Mats.col(Color(0.62, 0.4, 0.22, 0.9), 0.15), Vector3(-0.12 + (gi % 2) * 0.24, 0.05, -0.06 + (gi / 2) * 0.12), true)
	_props["tray"] = tray
	_props["tumbler"] = _part(_j["handL"], _mesh("cone", 0.03, 0.026, 0.07), Mats.col(Color(0.72, 0.73, 0.76), 0.25, 0.85), Vector3(0, -0.29, -0.05), true)
	_props["umbrella"] = _part(_j["handR"], _mesh("cone", 0.0, 0.55, 0.22), Mats.col(Color(0.06, 0.06, 0.07)), Vector3(0, -0.2, -0.75), false)
	_props["umbrella"].rotation.x = -PI * 0.5
	_part(_props["umbrella"], _mesh("box", 0.012, 0.75, 0.012), Mats.col(Color(0.2, 0.2, 0.2)), Vector3(0, -0.4, 0), false)
	_props["load"] = _part(head, _mesh("box", 0.42, 0.26, 0.34), Mats.col(Color(0.6, 0.5, 0.35)), Vector3(0, 0.41, 0), false)
	for k in _props:
		_props[k].visible = false
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
	# animation level of detail: far people update less often, very far not at all
	var cd := global_position.distance_squared_to(cam_pos)
	if cd > 110.0 * 110.0:
		return
	if cd > 38.0 * 38.0:
		_skip += 1
		if _skip % 3 != 0:
			return
		delta *= 3.0
	var near := cd < 18.0 * 18.0
	_t += delta
	var k := 1.0 - exp(-12.0 * delta)
	var hip_y := 0.9
	var body_rx := 0.0
	var body_y := 0.0
	var aL := Vector3.ZERO; var aR := Vector3.ZERO; var eL := Vector3.ZERO; var eR := Vector3.ZERO
	var lL := Vector3.ZERO; var lR := Vector3.ZERO; var kL := Vector3.ZERO; var kR := Vector3.ZERO
	var tor := Vector3(-stoop, 0, 0); var hd := Vector3(stoop * 0.6, 0, 0)
	var hipr := Vector3.ZERO
	var breath := sin(_t * 1.6 + _seed) * 0.012
	var prop := ""
	var st_k: float = walk[0]
	var sw_k: float = walk[1]
	var ar_k: float = walk[2]
	tor.x -= float(walk[3])
	match state:
		"pillion":
			hip_y = 0.52
			lL.x = 1.3; lR.x = 1.3; kL.x = -1.35; kR.x = -1.35; lL.z = -0.22; lR.z = 0.22
			tor.x = 0.2 + sin(_t * 0.7) * 0.02          # leaning back, at ease
			aL.x = 0.25; aR.x = 0.25; eL.x = 0.75; eR.x = 0.75; aL.z = -0.12; aR.z = 0.12
			hd.y = sin(_t * 0.33 + _seed) * 0.8          # watching the city go by
			hd.x = -0.12
		"sit", "drive":
			hip_y = 0.52
			lL.x = 1.45; lR.x = 1.45; kL.x = -1.5; kR.x = -1.5
			if state == "drive":
				aL.x = 1.05; aR.x = 1.05; eL.x = 0.35; eR.x = 0.35
				aL.z = 0.1; aR.z = -0.1
			else:
				aL.x = 0.35; aR.x = 0.35; eL.x = 0.9; eR.x = 0.9
				hd.y = sin(_t * 0.4 + _seed) * 0.25
				lL.z = -0.08; lR.z = 0.08
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
				# cadence follows ground speed so the feet do not skate
				_phase += delta * speed * lerpf(4.9, 2.6, run) * (1.0 + stoop) / st_k
				var amp := lerpf(0.42, 0.95, run) * (1.0 - stoop * 1.2) * st_k
				var sp := sin(_phase)
				var cp := cos(_phase)
				lL.x = sp * amp; lR.x = -sp * amp
				kL.x = -maxf(0.0, sin(_phase - 1.3)) * lerpf(0.85, 1.7, run) - 0.06
				kR.x = -maxf(0.0, sin(_phase - 1.3 + PI)) * lerpf(0.85, 1.7, run) - 0.06
				aL.x = -sp * amp * 0.7 * ar_k; aR.x = sp * amp * 0.7 * ar_k
				aL.z = -0.07; aR.z = 0.07
				eL.x = lerpf(0.18, 1.3, run) + maxf(0.0, -sp) * 0.25; eR.x = lerpf(0.18, 1.3, run) + maxf(0.0, sp) * 0.25
				tor.x -= lerpf(0.03, 0.22, run)
				tor.y = sp * 0.09
				tor.z = cp * 0.02
				hipr.y = -sp * 0.1
				hipr.z = cp * 0.035 * sw_k
				tor.z = -cp * 0.025 * sw_k
				if _skirt != null:
					_skirt.rotation.x = sp * 0.07
					_skirt.scale.x = 1.0 + absf(cp) * 0.05
				hd.y = -sp * 0.05
				hip_y += absf(cp) * lerpf(0.022, 0.05, run) - 0.022
				if activity == "carry":
					aR.x = 0.25; eR.x = 0.3; aR.z = 0.1
				elif activity == "tray":
					aL = Vector3(0.75, 0, 0.1); aR = Vector3(0.75, 0, -0.1); eL.x = 1.2; eR.x = 1.2; prop = "tray"; tor.y *= 0.2
				elif activity == "umbrella":
					aR.x = 0.5; eR.x = 2.0; prop = "umbrella"
				elif activity == "load":
					aL = Vector3(2.7, 0, 0.5); aR = Vector3(2.7, 0, -0.5); eL.x = 0.5; eR.x = 0.5; prop = "load"; tor.y *= 0.3
			else:
				# standing: weight on one leg, slow sway, the occasional glance
				var sway := sin(_t * 0.35 + _seed)
				hipr.z = sway * 0.04
				tor.z = -sway * 0.03
				lL.z = -0.03; lR.z = 0.03
				aL.z = -0.07; aR.z = 0.07; eL.x = 0.14; eR.x = 0.14
				tor.x += breath
				hd.y = sin(_t * 0.5 + _seed * 3.0) * 0.14 + (0.35 * sin(_t * 0.13 + _seed) if sin(_t * 0.21 + _seed) > 0.7 else 0.0)
	if state in ["idle", "sit", "talk"] and speed < 0.25:
		match activity:
			"tea", "eat":
				var c := fmod(_t * 0.35 + _seed, 1.0)
				var up := smoothstep(0.0, 0.15, c) * (1.0 - smoothstep(0.35, 0.5, c))
				aR.x = lerpf(0.5, 1.15, up); eR.x = lerpf(1.1, 2.2, up); aR.z = 0.1
				hd.x += up * 0.12
				if activity == "eat":
					aL.x = 0.55; eL.x = 1.35
				prop = "glass" if activity == "tea" else ""
			"tray":
				aL = Vector3(0.75, 0, 0.1); aR = Vector3(0.75, 0, -0.1); eL.x = 1.2; eR.x = 1.2; prop = "tray"
			"umbrella":
				aR.x = 0.5; eR.x = 2.0; prop = "umbrella"
			"pour":
				# the long pour: one hand high, one low, then a wipe of the counter
				var pc := fmod(_t * 0.22 + _seed, 1.0)
				if pc < 0.55:
					var lift := sin(pc / 0.55 * PI)
					aR.x = 1.0 + lift * 1.3; eR.x = 0.9 - lift * 0.5; aR.z = 0.2
					aL.x = 0.7 - lift * 0.3; eL.x = 1.0; hd.x += 0.25
					prop = "tumbler"
				else:
					aR.x = 0.8 + sin(_t * 3.0) * 0.2; eR.x = 1.1; aL.x = 0.6; eL.x = 1.2; hd.x += 0.2
			"play":
				aL.z = -0.9 + sin(_t * 6.0) * 0.4; aR.z = 0.9 - sin(_t * 6.0) * 0.4; hip_y += absf(sin(_t * 7.0)) * 0.08
			"read":
				aR.x = 0.75; eR.x = 1.4; aL.x = 0.75; eL.x = 1.4; aL.z = 0.2; aR.z = -0.1; hd.x += 0.3; hd.y = sin(_t * 0.3) * 0.08
				prop = "paper"
			"phone":
				aR.x = 0.9; eR.x = 2.35; aR.z = 0.25; hd.z = -0.12; hd.y = 0.1
				aL.x = sin(_t * 1.3) * 0.12 + 0.2; eL.x = 0.8 + sin(_t * 2.1 + _seed) * 0.3
				prop = "phone"
			"work":
				aR.x = 0.8 + sin(_t * 3.0 + _seed) * 0.18; eR.x = 1.2 + sin(_t * 4.1) * 0.25
				aL.x = 0.75 + sin(_t * 2.3 + 1.0) * 0.15; eL.x = 1.25 + cos(_t * 3.3) * 0.2
				hd.x += 0.22; tor.x -= 0.08
			"fix":
				hip_y = 0.6; lL.x = 1.2; lR.x = 0.65; kL.x = -1.95; kR.x = -1.7; tor.x -= 0.3
				aR.x = 1.0 + sin(_t * 5.0) * 0.12; eR.x = 0.6 + sin(_t * 5.0) * 0.2; aL.x = 0.9; eL.x = 0.8; hd.x += 0.2
				prop = "tool"
			"wait":
				var look_w := sin(_t * 0.18 + _seed)
				hd.y = 0.6 * clampf(look_w * 3.0, -1.0, 1.0) if absf(look_w) > 0.55 else hd.y
				if fmod(_t * 0.08 + _seed, 1.0) < 0.12:
					aL.x = 0.7; eL.x = 1.6; hd.x += 0.3     # checks the watch
				else:
					aL.x = 0.2; eL.x = 1.5; aR.x = 0.2; eR.x = 1.5; aL.z = 0.3; aR.z = -0.3      # arms folded
			"argue":
				var ch := sin(_t * 6.0 + _seed)
				aR.x = 0.9 + ch * 0.3; eR.x = 0.9 - ch * 0.4; aR.z = 0.2
				aL.x = 0.4 + sin(_t * 4.3) * 0.2; eL.x = 1.0; tor.x -= 0.08; hd.x += sin(_t * 5.0) * 0.07
			"laugh":
				var sh := sin(_t * 14.0) * 0.03
				tor.x += 0.1 + sh; hd.x -= 0.2 - sh * 2.0; aR.x = 0.3; eR.x = 1.3; hip_y += sh * 0.3
			"listen":
				hd.x += sin(_t * 2.2 + _seed) * 0.07 + 0.04; aL.x = 0.15; eL.x = 1.45; aL.z = 0.25; aR.x = 0.1; eR.x = 0.4
			"sweep":
				aR.x = 0.6 + sin(_t * 2.6) * 0.3; eR.x = 0.5; aL.x = 0.8 + sin(_t * 2.6) * 0.3; eL.x = 0.7; tor.x -= 0.3; tor.y = sin(_t * 2.6) * 0.2; hd.x += 0.2
			"pray":
				aL.x = 0.9; aR.x = 0.9; eL.x = 1.5; eR.x = 1.5; aL.z = 0.25; aR.z = -0.25; hd.x += 0.25
	if state == "talk" or talk_t > 0.0:
		talk_t = maxf(0.0, talk_t - delta)
		var g := sin(_t * 1.1 + _seed)
		aR.x = 0.55 + sin(_t * 4.0) * 0.18; eR.x = 1.25 + sin(_t * 5.3) * 0.25; aR.z = 0.15
		if g > 0.3:
			aL.x = 0.4 + sin(_t * 3.4) * 0.15; eL.x = 1.1 + sin(_t * 4.7) * 0.2      # both hands when warming to the subject
		hd.x += sin(_t * 3.1) * 0.06
		hd.z = sin(_t * 1.7) * 0.05
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
			"nod":
				hd.x += sin(_shot_t * 14.0) * 0.18
			"shake":
				hd.y += sin(_shot_t * 14.0) * 0.3
	# the head turns to whoever has our attention (clamped so nobody is an owl)
	if look_target != null and state != "ko":
		var to: Vector3 = (look_target as Vector3) - (global_position + Vector3(0, 1.55, 0))
		var want := atan2(-to.x, -to.z) - global_rotation.y
		want = wrapf(want, -PI, PI)
		if absf(want) < 1.9:
			hd.y = clampf(want, -1.1, 1.1) * 0.85
			tor.y += clampf(want, -1.1, 1.1) * 0.15
			hd.x += clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.4, 0.4)
	_tg("armL", aL, k); _tg("armR", aR, k); _tg("elbowL", eL, k); _tg("elbowR", eR, k)
	_tg("legL", lL, k); _tg("legR", lR, k); _tg("kneeL", kL, k); _tg("kneeR", kR, k)
	_tg("torso", tor, k); _tg("head", hd, k * 0.6); _tg("hips", hipr, k)
	hips.position.y = lerpf(hips.position.y, hip_y, k)
	body.rotation.x = lerpf(body.rotation.x, body_rx, k * 0.6)
	body.position.y = lerpf(body.position.y, body_y, k)
	# lean into turns: the body carries momentum
	var yaw_now := global_rotation.y
	var yr := wrapf(yaw_now - _last_yaw, -PI, PI) / maxf(delta, 0.001)
	_last_yaw = yaw_now
	_tilt = lerpf(_tilt, clampf(-yr * 0.03 * minf(speed, 5.0), -0.18, 0.18), 1.0 - exp(-6.0 * delta))
	body.rotation.z = _tilt
	if near:
		_face(delta)
		for pk in _props:
			_props[pk].visible = pk == prop

## Eyes, lids, brows and mouth: blinking at irregular intervals, gaze, and mood.
func _face(delta: float) -> void:
	_blink -= delta
	var fast := 0.45 if mood == "nervous" else 1.0
	if _blink <= 0.0:
		_blink = randf_range(1.6, 5.5) * fast
		_blink_t = 0.16
		if randf() < 0.2:
			_blink = 0.3            # a double blink now and then
		_dart = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * (1.0 if mood == "nervous" else 0.35)
	_blink_t = maxf(0.0, _blink_t - delta)
	var closed := sin(clampf(_blink_t / 0.16, 0.0, 1.0) * PI)
	var droop := 0.55 if mood == "tired" else (0.25 if mood == "sad" else (-0.3 if mood == "surprise" else 0.0))
	var lid_k := clampf(maxf(closed, droop), 0.0, 1.0)
	for lid in _lids:
		lid.scale.y = 0.1 + lid_k * 0.75
		lid.position.y = float(lid.get_meta("y")) - lid_k * 0.009
	# the eyes move before the head does
	var gx := _dart.x * 0.004
	var gy := _dart.y * 0.002
	if look_target != null:
		var to: Vector3 = (look_target as Vector3) - (global_position + Vector3(0, 1.55, 0))
		var rel := wrapf(atan2(-to.x, -to.z) - global_rotation.y - _rot["head"].y, -PI, PI)
		gx = clampf(-rel, -1.0, 1.0) * 0.006
	for pup in _pupils:
		var hp: Vector3 = pup.get_meta("home")
		pup.position = hp + Vector3(gx, gy, 0)
	var talking := talk_t > 0.0 or state == "talk" or activity in ["argue", "laugh", "phone"]
	var open := absf(sin(_t * 11.0 + _seed)) * (0.5 + 0.5 * absf(sin(_t * 3.7))) if talking else 0.0
	var em := emotion
	match mood:
		"angry": em -= 0.9
		"sad": em -= 0.4
		"smile": em += 0.8
		"surprise": open = maxf(open, 0.8)
		"nervous": em -= 0.2
	if activity == "argue": em -= 0.8
	if activity == "laugh":
		em += 0.7
		open = maxf(open, 0.6)
	if _mouth != null:
		_mouth.scale = Vector3(1.0 + clampf(em, -0.3, 1.0) * 0.3 - (0.3 if mood == "surprise" else 0.0), 1.0 + open * 2.4, 1.0)
		_mouth.position.y = 0.098 + maxf(em, 0.0) * 0.004 - open * 0.004
		_teeth.visible = open > 0.35 or em > 0.6
		_teeth.position.y = 0.101 - open * 0.002
	for bi in _brows.size():
		var sd2 := -1.0 if bi == 0 else 1.0
		var raise := 0.008 if mood == "surprise" else (0.004 if (talking and sin(_t * 2.3 + _seed) > 0.6) else 0.0)
		_brows[bi].rotation.z = -sd2 * 0.12 + sd2 * clampf(-em, -1.0, 1.0) * 0.32 + (sd2 * -0.25 if mood == "sad" else 0.0)
		_brows[bi].position.y = 0.196 + clampf(em, -1.0, 1.0) * 0.003 + raise
