class_name Human
extends Node3D
## A person. A rigged, skinned anatomical model (built offline by tools/humans from
## the CC0 MakeHuman base mesh) dressed and coloured from a plain "look" dictionary,
## animated by driving its skeleton, with a morph-target face. Used for the player
## and every NPC. Three levels of detail swap by distance.

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
const DIR := "res://assets/humans/"
const HEROES := ["raja", "lal", "rajini", "shankar", "kvanand", "ad", "umashankar", "raji", "kamakshi", "uma", "devaraj"]
const SKIN_REF := Color(0.86, 0.66, 0.5)      # tone the crowd skin maps are baked at
## Milestone 2 quality prototype: these bodies get the skin shader, card hair with motion
## and (when enabled) the ground-locked gait.
const PROTO := ["raja"]

static var _scenes := {}
static var _mats := {}
static var manifest := {}
static var cam_pos := Vector3.ZERO

var look := {}
var state := "idle"        # idle, walk, sit, drive, pillion, talk, crouch, ko, air
var speed := 0.0           # horizontal speed, drives the walk cycle
var talk_t := 0.0
var activity := ""         # tea, eat, read, phone, work, fix, wait, carry, argue, laugh, listen, sweep, pour, tray, umbrella, load, play, pray
var look_target = null     # Vector3 the head and eyes turn toward
var stoop := 0.0
var emotion := 0.0         # -1 angry .. +1 pleased
var mood := ""             # surprise, nervous, angry, sad, tired, smile
var detail := 1            # 2 = hero tier
var walk: Array = [1.0, 1.0, 1.0, 0.0]   # personal gait: stride, sway, arm swing, lean
var model := ""
var body: Node3D           # the model root
var skel: Skeleton3D
var hips: Node3D           # kept for old call sites: a marker at hip height
var head: Node3D
var _phase := 0.0
var _t := 0.0
var _shot := ""
var _shot_t := 0.0
var _props := {}
var _skip := 0
var _seed := randf() * 10.0
var _skirt: MeshInstance3D = null
var _blink := 2.0
var _blink_t := 0.0
var _dart := Vector2.ZERO
var _last_yaw := 0.0
var _tilt := 0.0
var _rot := {}             # smoothed joint angles
var _bone := {}            # name -> index
var _neutral := {}         # bone -> Quaternion: world orientation with the arms hanging
var _curl := {}            # finger bone -> curl axis (neutral frame)
var _faces: Array = []     # MeshInstance3D with expression morphs
var _morph := {}           # name -> current value
var _pelvis_rest := Vector3.ZERO
var _fist := 0.0
var _hip_y := 0.9
var _scale := 1.0
var _foot_lock := {}
var fall_t := -1.0         # >= 0 while a fall-and-recover plays (state "fall")
var seat_lift := 0.0       # raise the body so the pelvis rests on a seat of a given height
var ground_follow := true  # stand on the real walkable surface (off when riding in a vehicle)
var _gy := 0.0             # how far the walkable surface is above our root
var _blob: MeshInstance3D = null
var gait: Gait = null      # ground-locked procedural locomotion (feet planted, IK legs)
var gait_measure := false
var _card_mats: Array = []     # per-person hair-card materials (each carries its own sway)
var _hs := Vector3.ZERO        # hair spring: lagging position of the hair mass
var _hsv := Vector3.ZERO
var _hs_init := false
var _gait_was := false

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

static func _manifest() -> Dictionary:
	if manifest.is_empty():
		var txt := FileAccess.get_file_as_string(DIR + "manifest.json")
		var d = JSON.parse_string(txt)
		if d is Dictionary:
			manifest = d
	return manifest

## Which body model a look uses: a named hero, or the crowd body nearest in sex, age and build.
static func model_for(l: Dictionary) -> String:
	var m := str(l.get("model", ""))
	if m != "" and _manifest().has(m):
		return m
	var age := float(l.get("age", 0.4))
	var build := float(l.get("build", 0.4)) + float(l.get("fat", 0.0)) * 0.3
	if int(l.get("sex", 0)) == 1:
		if age < 0.13: return "child_f"
		if age > 0.75: return "f_old"
		if build > 0.72: return "f_heavy"
		return "f_slim" if build < 0.42 else "f_avg"
	if age < 0.13: return "child_m"
	if age > 0.75: return "m_old"
	if build > 0.74: return "m_heavy"
	if age < 0.27: return "m_youth"
	if float(l.get("height", 0.5)) > 0.78: return "m_tall"
	return "m_lean" if build < 0.4 else "m_avg"

static func _tex(n: String) -> Texture2D:
	var p := DIR + "tex/" + n
	return load(p) if ResourceLoader.exists(p) else null

static func _mat(key: String, build: Callable) -> Material:
	if not _mats.has(key):
		_mats[key] = build.call()
	return _mats[key]

static func skin_mat(model_name: String, tone: Color) -> Material:
	return _mat("skin_%s_%s" % [model_name, tone.to_html()], func():
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex(model_name + "_skin.jpg")
		m.albedo_color = tone
		m.normal_enabled = true
		m.normal_texture = _tex(model_name + "_skin_n.jpg")
		m.normal_scale = 0.7
		m.roughness = 0.52
		m.metallic_specular = 0.42
		m.rim_enabled = true          # soft light wrapping at grazing angles, as skin does
		m.rim = 0.18
		m.rim_tint = 0.6
		return m)

static func cloth_mat(pattern: String, tint: Color, vcol := true, rough := 0.9) -> Material:
	return _mat("cloth_%s_%s_%s" % [pattern, tint.to_html(), vcol], func():
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex("cloth.png" if pattern == "plain" else "cloth_%s.png" % pattern)
		m.albedo_color = tint
		m.vertex_color_use_as_albedo = vcol
		m.normal_enabled = true
		m.normal_texture = _tex("cloth_n.png")
		m.normal_scale = 0.45
		m.uv1_scale = Vector3(1.3, 1.3, 1) if pattern == "plain" else Vector3(5, 5, 1)
		m.roughness = rough
		m.metallic_specular = 0.25
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)

static func hair_mat(c: Color, solid := false, cut := 0.5) -> Material:
	return _mat("hair_%s_%s_%s" % [c.to_html(), solid, cut], func():
		var m := StandardMaterial3D.new()
		m.albedo_color = c if not solid else c.darkened(0.2)
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.45
		m.metallic_specular = 0.6
		if true:
			m.albedo_texture = _tex("hair.png")
			m.vertex_color_use_as_albedo = true
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = cut
			m.normal_enabled = true
			m.normal_texture = _tex("hair_n.png")
			m.uv1_scale = Vector3(3.0, 0.5, 1)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)

static func plain_mat(key: String, c: Color, rough: float, metal := 0.0, vcol := true) -> Material:
	return _mat("pl_%s_%s" % [key, c.to_html()], func():
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.vertex_color_use_as_albedo = vcol
		m.roughness = rough
		m.metallic = metal
		if c.a < 0.99:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return m)

static func skin_shader_mat(model_name: String) -> Material:
	return _mat("skinsh_" + model_name, func():
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/skin.gdshader")
		m.set_shader_parameter("albedo_tex", _tex(model_name + "_skin.jpg"))
		m.set_shader_parameter("normal_tex", _tex(model_name + "_skin_n.jpg"))
		m.set_shader_parameter("pores_tex", _tex("skin_pores_n.png"))
		return m)

func _card_mat(fine: bool, facial := false) -> Material:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/hair_cards.gdshader")
	m.set_shader_parameter("strands", _tex("hair_card.png"))
	m.set_shader_parameter("cut", 0.58 if facial else (0.4 if fine else 0.33))
	if facial:
		m.set_shader_parameter("tint", Color(1.6, 1.45, 1.35))     # facial hair reads a touch browner than the head
	_card_mats.append(m)
	return m

static func eye_mat() -> Material:
	return _mat("eye", func():
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex("eye.png")
		m.roughness = 0.22                # wet, but not a mirror in daylight
		m.metallic_specular = 0.45
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.3
		return m)

# ------------------------------------------------------------------ building
func set_look(l: Dictionary) -> void:
	look = default_look()
	for k in l:
		look[k] = l[k]
	for ch in get_children():
		ch.queue_free()
	_props.clear()
	_faces.clear()
	_bone.clear()
	_neutral.clear()
	_curl.clear()
	_rot.clear()
	skel = null
	model = model_for(look)
	var path := DIR + model + ".glb"
	if not _scenes.has(model):
		_scenes[model] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _scenes[model]
	if ps == null:
		push_warning("Human model missing: " + path)
		return
	var info: Dictionary = _manifest().get(model, {})
	var hero: bool = info.get("hero", false)
	body = ps.instantiate()
	add_child(body)
	var sk := body.find_children("*", "Skeleton3D", true, false)
	skel = sk[0]
	var age := float(look.get("age", 0.4))
	stoop = clampf((age - 0.72) * 0.9, 0.0, 0.25)
	_scale = 1.0 if hero else lerpf(0.95, 1.05, float(look.height))
	body.scale = Vector3.ONE * _scale
	for i in skel.get_bone_count():
		_bone[skel.get_bone_name(i)] = i
	_pelvis_rest = skel.get_bone_rest(_bone["pelvis"]).origin
	_setup_neutral()
	_dress(info, hero)
	_make_props()
	hips = Node3D.new()
	hips.position.y = 0.9
	add_child(hips)
	head = BoneAttachment3D.new()
	head.bone_name = "head"
	skel.add_child(head)
	var sh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	sh.mesh = q
	sh.material_override = Mats.blob()
	sh.position.y = 0.03
	sh.visibility_range_end = 40.0
	_blob = sh
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sh)

func _gpos(b: String) -> Vector3:
	return skel.get_bone_global_rest(_bone[b]).origin

## Work out the "arms hanging" neutral orientation for the arm and hand bones, and
## the axis each finger curls about. The model is authored with its arms out.
func _setup_neutral() -> void:
	for s in ["l", "r"]:
		var sx := -1.0 if s == "l" else 1.0
		var up := _gpos("upperarm_" + s)
		var lo := _gpos("lowerarm_" + s)
		var hd := _gpos("hand_" + s)
		var mid := _gpos("middle_01_" + s)
		var down := Vector3(sx * 0.1, -1.0, 0.03).normalized()
		var q1 := Quaternion((lo - up).normalized(), down)
		var q2 := Quaternion(q1 * (hd - lo).normalized(), Vector3(sx * 0.05, -1.0, -0.14).normalized()) * q1
		var q3 := Quaternion(q2 * (mid - hd).normalized(), Vector3(sx * 0.02, -1.0, -0.1).normalized()) * q2
		# roll the hand so the palm faces the thigh
		var palm_n := (q3 * (_gpos("index_01_" + s) - hd)).cross(q3 * (_gpos("pinky_01_" + s) - hd)).normalized() * sx
		var hand_dir := (q3 * (mid - hd)).normalized()
		var want := Vector3(-sx, 0, 0)
		want = (want - hand_dir * want.dot(hand_dir)).normalized()
		var pn := (palm_n - hand_dir * palm_n.dot(hand_dir)).normalized()
		var roll := Quaternion(hand_dir, pn.signed_angle_to(want, hand_dir))
		q3 = roll * q3
		_neutral["upperarm_" + s] = q1
		_neutral["lowerarm_" + s] = q2
		_neutral["hand_" + s] = q3
		for f in ["thumb", "index", "middle", "ring", "pinky"]:
			for k in ["01", "02", "03"]:
				var bn := "%s_%s_%s" % [f, k, s]
				_neutral[bn] = q3
				var ch := "%s_%s_%s" % [f, "02" if k == "01" else "03", s]
				var d := (q3 * (_gpos(ch) - _gpos("%s_%s_%s" % [f, "01" if k != "03" else "02", s]))).normalized()
				_curl[bn] = d.cross(Vector3(-sx, 0, 0) if f != "thumb" else Vector3(0, 0, -1)).normalized()

func _show(part: String, mat: Material = null) -> void:
	for lvl in 3:
		var mi: MeshInstance3D = body.get_node_or_null("L%d_%s" % [lvl, part])
		if mi == null:
			mi = body.find_child("L%d_%s" % [lvl, part], true, false)
		if mi != null:
			mi.visible = true
			if mat != null:
				mi.material_override = mat

func _dress(info: Dictionary, hero: bool) -> void:
	var has_l0 := false
	for mi in body.find_children("L0_*", "MeshInstance3D", true, false):
		has_l0 = true
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		mi.visible = false
		# skinned + morphed meshes can carry bounds that do not follow the posed body;
		# a fixed person-sized box keeps culling and LOD distance honest from every angle
		mi.custom_aabb = AABB(Vector3(-0.9, -0.05, -0.9), Vector3(1.8, 2.15, 1.8))
		var nm := String(mi.name)
		var lvl := int(nm.substr(1, 1))
		# level of detail by distance: full model only for close-ups
		if lvl == 0:
			mi.visibility_range_end = 5.0
		elif lvl == 1:
			mi.visibility_range_begin = 5.0 if has_l0 else 0.0
			mi.visibility_range_end = 15.0
		else:
			mi.visibility_range_begin = 15.0
			mi.visibility_range_end = 115.0
		if lvl >= 1:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lvl == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh != null and mi.mesh.get_blend_shape_count() > 0 and lvl <= 1:
			_faces.append(mi)
	var tone: Color = SKIN[int(look.skin) % SKIN.size()]
	var skin: Material
	if hero and model in PROTO:
		skin = skin_shader_mat(model)
	elif hero:
		skin = skin_mat(model, Color.WHITE)
	else:
		skin = skin_mat(model, Color(tone.r / SKIN_REF.r, tone.g / SKIN_REF.g, tone.b / SKIN_REF.b).clamp())
	var hair_c: Color = HAIR_COL[int(look.hair_col) % HAIR_COL.size()]
	if float(look.get("age", 0.4)) > 0.72 and int(look.hair_col) == 0:
		hair_c = HAIR_COL[2]
	_show("skin_a", skin)
	_show("skin_feet", skin)
	# the body is one continuous surface: the skin under the clothes is always there, so a sleeve,
	# collar or hem that lifts in motion shows the body beneath, never a gap into nothing
	_show("skin_torso", skin)
	_show("skin_legs", skin)
	_show("eyes", eye_mat())
	_show("teeth", plain_mat("teeth", Color.WHITE, 0.3))
	_show("tongue", plain_mat("tongue", Color.WHITE, 0.4))
	_show("lashes", plain_mat("lash", Color(1, 1, 1, 0.5), 0.8))
	var top_i := int(look.top)
	var bot_i := int(look.bottom)
	var tc: Color = CLOTH[int(look.top_col) % CLOTH.size()]
	var bc: Color = CLOTH[int(look.bot_col) % CLOTH.size()]
	if hero:
		# heroes wear their own tailored outfit; colours are baked into the cloth
		var white := cloth_mat("plain", Color.WHITE)
		for part in info.get("parts", []):
			var p := String(part)
			if p.begins_with("skin") or p in ["eyes", "teeth", "tongue", "lashes"]:
				continue
			if p.ends_with("_cards") or p.ends_with("_cards1"):
				var facial := p.begins_with("brows") or p.begins_with("moustache") or p.begins_with("sideburn") or p.begins_with("beard")
				_show(p, _card_mat(not p.ends_with("_cards1"), facial))
			elif p.begins_with("hair_"):
				_show(p, hair_mat(Color.WHITE, p.ends_with("_cap")))
			elif p in ["moustache", "beard", "goatee"]:
				_show(p, hair_mat(Color.WHITE, false, 0.28))
			elif p == "glasses":
				pass      # the fitted frames are not good enough yet; left off rather than shown wrong
			elif p == "watch":
				_show(p, plain_mat("watch", Color.WHITE, 0.3, 0.7))
			elif p == "belt" or p.ends_with("_sole") or p.ends_with("_straps") or p == "shoes":
				_show(p, plain_mat("leather", Color.WHITE, 0.5))
			elif p == "coat":
				if top_i == 11:
					_show(p, white)
			elif p == "over":
				if top_i == 7:
					_show(p, white)
			else:
				var pats: Dictionary = look.get("pat", {})
				_show(p, cloth_mat(str(pats[p]), Color.WHITE) if pats.has(p) else white)
		if model == "kamakshi":
			_show("skin_torso", skin)
			_show("skin_legs", skin)
		return
	if bot_i == 1: bc = Color(0.2, 0.28, 0.45)
	if bot_i == 3: bc = Color(0.96, 0.95, 0.9)
	var pattern := "plain"
	if top_i == 2: pattern = "print"
	elif top_i == 3: pattern = "check"
	elif top_i == 1 and int(look.top_col) % 3 == 2: pattern = "stripe"
	if top_i == 11: tc = Color(0.07, 0.07, 0.08)
	var top_m := cloth_mat(pattern, tc)
	var skirted := bot_i in [2, 3, 4]
	var tucked := false
	match top_i:
		0, 7:
			_show("shirt", top_m); tucked = true
		1, 11:
			_show("shirt_full", top_m); tucked = true
		2, 3, 4, 6:
			_show("shirt_out", top_m)
		5:
			_show("kurta", top_m); _show("kurta_skirt", top_m)
		8:
			_show("blouse", top_m); _show("skin_torso", skin)
		9:
			_show("kameez", top_m); _show("kameez_skirt", top_m)
		10:
			_show("banian", top_m); _show("skin_torso", skin)
	match bot_i:
		0, 1, 5:
			_show("trousers", cloth_mat("plain", bc))
			if tucked:
				_show("belt", plain_mat("leather", Color.WHITE, 0.5))
		2:
			_show("lungi", cloth_mat("check", bc))
		3:
			_show("lungi", cloth_mat("plain", bc))
		4:
			_show("saree", cloth_mat("plain", bc)); _show("pallu", cloth_mat("plain", bc))
	if skirted:
		_show("skin_legs", skin)
	match int(look.shoes):
		0, 4:
			_show("chappal_sole", plain_mat("leather", Color.WHITE, 0.5)); _show("chappal_straps", plain_mat("leather", Color.WHITE, 0.5))
		1:
			_show("shoes", plain_mat("leather", Color.WHITE, 0.4))
		2:
			_show("shoes", plain_mat("canvas", Color(8, 8, 8), 0.8))
	var female: bool = int(look.sex) == 1
	var style := ""
	if female:
		style = "plait" if int(look.hair) == 7 else ("bun" if int(look.hair) == 8 else "long")
	else:
		style = ["short", "side", "bouffant", "balding", "side", "curly", "", "short", "short"][int(look.hair) % 9]
	if style != "":
		for suffix in ["", "_cap", "_tail", "_bun"]:
			_show("hair_" + style + suffix, hair_mat(hair_c if suffix != "_cap" else hair_c, suffix == "_cap"))
	var bd := int(look.beard)
	if not female:
		if bd in [1, 2, 3, 5, 6]:
			_show("moustache", hair_mat(hair_c, false, 0.28))
		if bd in [5, 6]:
			_show("beard", hair_mat(hair_c, false, 0.28))
	if bool(look.get("labcoat", false)):
		_show("labcoat", cloth_mat("plain", Color.WHITE))
	if int(look.glasses) > 0:
		_show("glasses", plain_mat("frame", Color.WHITE, 0.3, 0.4))
	if int(look.watch) > 0:
		_show("watch", plain_mat("watch%d" % int(look.watch), [Color.WHITE, Color(1, 1, 1), Color(1.3, 1.0, 0.3), Color(0.4, 0.26, 0.14)][int(look.watch)], 0.3, 0.7))
	# an individual face: blend the identity shapes by this person's own numbers
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(look.get("face", 0)) + str(look.skin) + str(look.get("age", 0)) + str(look.top_col) + str(look.height))
	for mi in _faces:
		for i in mi.mesh.get_blend_shape_count():
			var bn := String(mi.mesh.get_blend_shape_name(i))
			if bn.begins_with("id_"):
				mi.set_blend_shape_value(i, rng.randf_range(0.0, 0.95) if rng.randf() < 0.6 else 0.0)

func _attach(bone: String) -> BoneAttachment3D:
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	skel.add_child(a)
	return a

func _prop(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.visible = false
	mi.visibility_range_end = 30.0
	parent.add_child(mi)
	return mi

func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

func _cyl(r0: float, r1: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r1
	c.height = h
	c.radial_segments = 10
	return c

func _make_props() -> void:
	var hr := _attach("hand_r")
	var hl := _attach("hand_l")
	var sp := _attach("spine_02")
	var hdb := _attach("head")
	var steel := Mats.col(Color(0.72, 0.73, 0.76), 0.25, 0.85)
	_props["glass"] = _prop(hr, _cyl(0.022, 0.017, 0.06), Mats.col(Color(0.62, 0.42, 0.26, 0.9), 0.15), Vector3(0, -0.07, -0.04))
	_props["paper"] = _prop(hr, _box(0.3, 0.004, 0.22), Mats.col(Color(0.88, 0.86, 0.8)), Vector3(-0.1, -0.08, -0.08))
	_props["phone"] = _prop(hr, _box(0.035, 0.15, 0.04), Mats.col(Color(0.08, 0.08, 0.08)), Vector3(0, -0.08, -0.03))
	_props["tool"] = _prop(hr, _box(0.025, 0.22, 0.025), Mats.col(Color(0.55, 0.56, 0.6), 0.3, 0.7), Vector3(0, -0.12, -0.02))
	_props["tumbler"] = _prop(hl, _cyl(0.03, 0.026, 0.07), steel, Vector3(0, -0.07, -0.04))
	var um := _prop(hr, _cyl(0.0, 0.55, 0.22), Mats.col(Color(0.06, 0.06, 0.07)), Vector3(0, 0.75, -0.05))
	_prop(um, _box(0.012, 0.8, 0.012), Mats.col(Color(0.2, 0.2, 0.2)), Vector3(0, -0.45, 0)).visible = true
	_props["umbrella"] = um
	var tray := _prop(sp, _box(0.4, 0.012, 0.28), steel, Vector3(0, -0.02, -0.4))
	for gi in 4:
		_prop(tray, _cyl(0.03, 0.026, 0.085), Mats.col(Color(0.5, 0.3, 0.16, 0.92), 0.15), Vector3(-0.12 + (gi % 2) * 0.24, 0.05, -0.06 + (gi / 2) * 0.12)).visible = true
	_props["tray"] = tray
	_props["load"] = _prop(hdb, _box(0.42, 0.26, 0.34), Mats.col(Color(0.6, 0.5, 0.35)), Vector3(0, 0.36, 0))
	# things that are simply worn
	if bool(look.get("steth", false)):
		# a stethoscope round the neck: tubing over the shoulders, the chest piece hanging
		var nb := _attach("spine_03")
		var tube := Mats.col(Color(0.05, 0.05, 0.06), 0.4)
		for sd: float in [-1.0, 1.0]:
			var t1 := _prop(nb, _box(0.012, 0.24, 0.012), tube, Vector3(sd * 0.075, 0.1, -0.1), Vector3(0.25, 0, sd * 0.12))
			t1.visible = true
		_prop(nb, _box(0.17, 0.012, 0.012), tube, Vector3(0, 0.24, 0.02)).visible = true
		_prop(nb, _cyl(0.022, 0.022, 0.012), Mats.col(Color(0.75, 0.76, 0.78), 0.2, 0.9), Vector3(0.07, -0.04, -0.13), Vector3(PI * 0.5, 0, 0)).visible = true
	match int(look.acc):
		4:      # the conductor's leather cash bag, slung at the hip
			var bag := _prop(_attach("pelvis"), _box(0.15, 0.11, 0.045), Mats.col(Color(0.24, 0.14, 0.08), 0.55), Vector3(-0.165, -0.02, -0.07), Vector3(0, 0.75, 0))
			bag.visible = true
			_prop(bag, _box(0.155, 0.04, 0.05), Mats.col(Color(0.2, 0.12, 0.06), 0.5), Vector3(0, 0.04, 0.0)).visible = true
		6:
			_prop(_attach("spine_03"), _box(0.28, 0.34, 0.13), Mats.col(Color(0.15, 0.25, 0.45)), Vector3(0, -0.05, 0.17)).visible = true
		7:
			_prop(hl, _box(0.06, 0.26, 0.22), Mats.col(Color(0.8, 0.75, 0.5)), Vector3(0, -0.2, 0)).visible = true
		3:
			_prop(_attach("spine_03"), _box(0.1, 0.34, 0.24), Mats.cloth("check", Color(0.9, 0.3, 0.3)), Vector3(0.14, 0.02, 0)).visible = true
		5:
			_prop(hdb, _box(0.13, 0.03, 0.03), Mats.col(Color(0.98, 0.97, 0.9)), Vector3(0, 0.05, 0.1)).visible = true

# ------------------------------------------------------------------ animation
## Body language. A posture shapes the whole body, not just the face, and comes with its own
## small habits. Values are added to the animated pose.
var posture := ""          # confident, nervous, defensive, frustrated, curious, tired, relaxed
var _post_t := 0.0
var reach := {}            # side -> {target: Vector3 (world), w: float, want: float}
var reach_err := {}

## Additive pose for the current posture: {tor, hd, aL, aR, eL, eR, arms (bool: the posture owns the arms)}.
func _posture_pose(delta: float) -> Dictionary:
	_post_t += delta
	var t := _post_t
	var o := {"tor": Vector3.ZERO, "hd": Vector3.ZERO, "aL": Vector3.ZERO, "aR": Vector3.ZERO, "eL": 0.0, "eR": 0.0, "arms": false}
	match posture:
		"confident":       # chest up, chin up, shoulders back, arms loose and a little away from the body
			o.tor = Vector3(0.06, 0, 0); o.hd = Vector3(-0.07, 0, 0)
			o.aL = Vector3(-0.05, 0, -0.1); o.aR = Vector3(-0.05, 0, 0.1)
		"nervous":         # folded in, head down, hands working at each other, eyes and head never still
			o.tor = Vector3(-0.1, 0, 0); o.hd = Vector3(0.14, sin(t * 1.9) * 0.22 + sin(t * 4.3) * 0.05, 0)
			o.arms = true
			o.aL = Vector3(0.38 + sin(t * 5.0) * 0.04, 0, 0.26); o.aR = Vector3(0.38 + sin(t * 5.7 + 1.0) * 0.04, 0, -0.26)
			o.eL = 1.25 + sin(t * 6.0) * 0.08; o.eR = 1.3 + sin(t * 6.4) * 0.08
		"defensive":       # arms folded across the chest, weight back, chin tucked
			o.tor = Vector3(0.05, 0, 0); o.hd = Vector3(0.04, 0, 0)
			o.arms = true
			o.aL = Vector3(0.22, 0, 0.32); o.aR = Vector3(0.26, 0, -0.3); o.eL = 1.55; o.eR = 1.5
		"frustrated":      # hands on the hips, a slow shake of the head, a sigh every so often
			o.arms = true
			var sig := maxf(0.0, sin(t * 0.7)) ** 6
			o.tor = Vector3(-0.04 + sig * 0.08, 0, 0); o.hd = Vector3(0.05 + sig * 0.2, sin(t * 0.9) * 0.12, 0)
			o.aL = Vector3(-0.25, 0, -0.62); o.aR = Vector3(-0.25, 0, 0.62); o.eL = 1.7; o.eR = 1.7
		"curious":         # leaning in, head tilted, chin forward
			o.tor = Vector3(-0.09, 0, 0); o.hd = Vector3(-0.06, sin(t * 0.6) * 0.1, 0.16)
		"tired":           # slumped, head heavy, arms hanging dead
			o.tor = Vector3(-0.14, 0, 0); o.hd = Vector3(0.2, 0, sin(t * 0.3) * 0.05)
			o.aL = Vector3(0.0, 0, 0.05); o.aR = Vector3(0.0, 0, -0.05)
		"relaxed":         # weight on one hip, one hand resting on the belt, slow looks around
			o.hd = Vector3(0.0, sin(t * 0.35) * 0.3, 0.04)
			o.aR = Vector3(-0.1, 0, 0.1); o.eR = 0.6
	return o

## Reach with a hand: blend toward the target over ~0.4 s, hold, release by calling reach_release.
func reach_to(side: String, target: Vector3) -> void:
	var r: Dictionary = reach.get(side, {"w": 0.0})
	r["target"] = target
	r["want"] = 1.0
	reach[side] = r

func reach_release(side: String) -> void:
	if reach.has(side):
		reach[side]["want"] = 0.0

func _reach_ik(delta: float) -> void:
	if gait == null:
		return
	for side in reach.keys():
		var r: Dictionary = reach[side]
		r.w = move_toward(float(r.w), float(r.get("want", 0.0)), delta / 0.45)
		var ws := float(r.w) * float(r.w) * (3.0 - 2.0 * float(r.w))
		reach_err[side] = gait.solve_arm(side, r.target, ws)
		if float(r.w) <= 0.0 and float(r.get("want", 0.0)) <= 0.0:
			reach.erase(side)
	# seated: hands come to rest on the thighs, just behind the knee
	if gait.seating():
		var st: float = gait.seat_t
		var wr := clampf((st - 0.55) / 0.45, 0.0, 1.0)
		wr = wr * wr * (3.0 - 2.0 * wr)
		for side in ["l", "r"]:
			var busy: float = float(reach[side].w) if reach.has(side) else 0.0
			var w := wr * (1.0 - busy)
			if w <= 0.001 or (side == "r" and activity != ""):
				continue
			var th: Vector3 = skel.global_transform * skel.get_bone_global_pose(_bone["thigh_" + side]).origin
			var kn: Vector3 = skel.global_transform * skel.get_bone_global_pose(_bone["calf_" + side]).origin
			var out := global_transform.basis.x * (-1.0 if side == "l" else 1.0)
			# top of the thigh: the bone runs through its middle, the surface is ~7 cm above it
			gait.solve_arm(side, th.lerp(kn, 0.62) + Vector3(0, 0.075, 0) + out * 0.02, w)

## Sit on a seat surface (world point at the centre of the seat), facing yaw.
func sit_on(seat_pos: Vector3, yaw: float) -> void:
	if gait == null:
		enable_gait()
	rotation.y = yaw
	gait.sit_on(seat_pos, yaw)

func stand_up() -> void:
	if gait != null:
		gait.stand_up()

## Switch this person to the ground-locked gait (planted feet, IK legs, weight transfer).
func enable_gait() -> void:
	if skel != null and gait == null:
		gait = Gait.new(self)

func play_once(nm: String, dur := 0.45) -> void:
	_shot = nm
	_shot_t = dur

func _sm(nm: String, v: Vector3, k: float) -> Vector3:
	var cur: Vector3 = _rot.get(nm, Vector3.ZERO)
	cur = cur.lerp(v, k)
	_rot[nm] = cur
	return cur

func _pose(bone: String, parent_bone: String, a: Quaternion) -> void:
	# local pose = (parent neutral)^-1 * animation * (own neutral)
	var np: Quaternion = _neutral.get(parent_bone, Quaternion.IDENTITY)
	var nb: Quaternion = _neutral.get(bone, Quaternion.IDENTITY)
	skel.set_bone_pose_rotation(_bone[bone], np.inverse() * a * nb)

func _eul(v: Vector3) -> Quaternion:
	return Quaternion.from_euler(v)

func _process(delta: float) -> void:
	if skel == null:
		return
	var cd := global_position.distance_squared_to(cam_pos)
	if cd > 115.0 * 115.0:
		return
	if cd > 30.0 * 30.0:
		_skip += 1
		if _skip % 3 != 0:
			return
		delta *= 3.0
	var near := cd < 14.0 * 14.0
	_t += delta
	if ground_follow:
		var root_y := global_position.y
		var gh := Ground.height(global_position) - root_y
		if gait != null and _gait_was and gait.foot_ground_ok and not gait.seating():
			gh = gait.foot_ground_y - root_y      # the body is carried by the feet, not the ground under its middle
		_gy = lerpf(_gy, maxf(0.0, gh), 1.0 - exp(-14.0 * delta)) if absf(gh - _gy) < 0.35 else maxf(0.0, gh)
	else:
		_gy = 0.0
	if _blob != null:
		_blob.position.y = _gy + 0.012
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
	if gait != null and gait.seating():
		gait.seat_update(delta)          # may finish standing up and clear the seat
	var seated_gait := gait != null and gait.seating()
	var gait_on := gait != null and not seated_gait and ground_follow and state in ["idle", "talk"] and not (_shot_t > 0.0 and _shot == "leap") and absf(body.rotation.x) < 0.2
	if gait_on and not _gait_was:
		gait.reset()
	_gait_was = gait_on
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
		"fall":
			fall_t += delta
			var P := _fall_pose(fall_t)
			hip_y = P.hip; tor = P.tor; hd = P.hd
			aL = P.aL; aR = P.aR; eL = P.eL; eR = P.eR
			lL = P.lL; lR = P.lR; kL = P.kL; kR = P.kR
			k = 1.0 - exp(-16.0 * delta)
		"ko":
			body_rx = 1.45
			body_y = 0.16
			aL.z = -1.2; aR.z = 1.2; lL.x = 0.15; lR.x = -0.1
		"air":
			lL.x = 0.5; lR.x = -0.2; kL.x = -0.7; kR.x = -0.3; aL.z = -0.5; aR.z = 0.5
		_:
			if speed > 0.25 and not gait_on:
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
			"cheer":
				# "Thalaiva!": a fist pumped over the head, up on the toes, face lifted to the star
				var pump := sin(_t * 8.5 + _seed)
				aR = Vector3(2.75 + pump * 0.22, 0, 0.25); eR.x = 0.35 + maxf(0.0, -pump) * 0.4
				if sin(_t * 0.9 + _seed) > 0.2:
					aL = Vector3(2.3 + sin(_t * 6.0) * 0.2, 0, -0.45); eL.x = 0.5
				hd.x -= 0.18; tor.x += 0.06; hip_y += absf(pump) * 0.025
			"wave_star":
				aR.z = 2.5; eR.z = sin(_t * 9.0 + _seed) * 0.45; hd.x -= 0.12
			"dust":
				# brushing the dust off: shirt, then the seat of the trousers
				var dc := fmod(_t * 0.5 + _seed, 1.0)
				if dc < 0.55:
					aR.x = 0.55 + sin(_t * 9.0) * 0.22; eR.x = 1.55; aR.z = -0.15
					aL.x = 0.35 + sin(_t * 9.0 + 1.5) * 0.18; eL.x = 1.25; aL.z = 0.15
					tor.x -= 0.22; hd.x += 0.38
				else:
					aR = Vector3(-0.35 + sin(_t * 10.0) * 0.15, 0, 0.2); eR.x = 0.5
					aL = Vector3(-0.3 + sin(_t * 10.0 + 1.0) * 0.15, 0, -0.2); eL.x = 0.5
					tor.x -= 0.3; tor.y = 0.35; hd.x += 0.2; hd.y = 0.6
			"bend":
				# leaning down to speak to someone seated
				tor.x -= 0.62; hd.x -= 0.32; lL.x = 0.28; lR.x = 0.22; kL.x = -0.32; kR.x = -0.26; hip_y -= 0.05
				aL.x = 0.2; eL.x = 0.4; aR.x = 0.3; eR.x = 1.2
			"hold":
				# restraining somebody: both arms forward, weight back
				aL = Vector3(1.15 + sin(_t * 5.0 + _seed) * 0.12, 0, 0.12); aR = Vector3(1.2 + sin(_t * 4.3) * 0.12, 0, -0.12)
				eL.x = 0.55; eR.x = 0.5; tor.x -= 0.18; lL.x = 0.2; lR.x = -0.25; kL.x = -0.3
			"shout":
				# yelling an order across a crowd: one arm out, pointing, body behind it
				aR = Vector3(1.35, 0, 0.15); eR.x = 0.12 + sin(_t * 3.0) * 0.1; aL.x = 0.25; eL.x = 0.8
				tor.x -= 0.12; hd.x -= 0.08
			"crossed":
				aL.x = 0.2; eL.x = 1.5; aR.x = 0.2; eR.x = 1.5; aL.z = 0.3; aR.z = -0.3
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
			"salute":
				aR = Vector3(0.35, 0, 1.45); eR = Vector3(2.45, 0, 0); hd.x -= 0.05; tor.x -= 0.03
			"namaste":
				aL.x = 0.9; aR.x = 0.9; eL.x = 1.5; eR.x = 1.5; aL.z = 0.25; aR.z = -0.25; hd.x = -0.2
			"nod":
				hd.x += sin(_shot_t * 14.0) * 0.18
			"nod_slow":
				hd.x += maxf(0.0, sin(_shot_t * 4.2)) * 0.26
			"push":
				aL = Vector3(1.45, 0, 0.1); aR = Vector3(1.45, 0, -0.1); eL.x = 0.12; eR.x = 0.12; tor.x -= 0.25; lR.x = -0.4; kR.x = -0.2
			"facepalm":
				aR = Vector3(1.85, 0, 0.32); eR.x = 2.35; hd.x += 0.22; tor.x -= 0.05
			"point_small":
				aR = Vector3(0.42, 0, 0.32); eR.x = 0.55; hd.y += 0.35; hd.x += 0.05
			"sigh":
				var sg := sin(clampf(_shot_t / 2.2, 0.0, 1.0) * PI)
				tor.x += 0.1 * sg; hd.x += 0.28 * sg; aL.z -= 0.05 * sg; aR.z += 0.05 * sg
			"calm":
				aR = Vector3(0.55, 0, 0.12); eR.x = 1.15; hd.x += 0.08
			"shades":
				aR = Vector3(1.6, 0, 0.25); eR.x = 2.5; hd.x -= 0.04
			"leap":
				aR = Vector3(1.9, 0, 0.3); eR.x = 1.9; aL = Vector3(1.0, 0, -0.3); eL.x = 1.4
				lL.x = 1.1; kL.x = -1.5; lR.x = -0.35; kR.x = -0.6; tor.x -= 0.3; tor.y = 0.4
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
	if seated_gait:
		# sitting: the torso leans over the knees on the way down and up, settles back when seated
		var st := gait.seat_t
		tor.x -= sin(PI * st) * 0.5 - st * 0.04
		hd.x += sin(PI * st) * 0.25
		aL.x = 0.45; aR.x = 0.45; eL.x = 0.85; eR.x = 0.85
	var po := _posture_pose(delta)
	tor += po.tor; hd += po.hd
	var still := gait == null or gait.vel.length() < 0.25
	if po.arms and still and activity == "" and prop == "":
		aL = po.aL; aR = po.aR; eL.x = po.eL; eR.x = po.eR
	else:
		aL += po.aL; aR += po.aR; eL.x += po.eL; eR.x += po.eR
	if gait_on:
		var free: bool = prop == "" and activity in ["", "listen", "laugh"] and not (_shot_t > 0.0)
		var g := gait.plan(delta, free)
		tor += g.tor; hd += g.hd; hipr += g.hip
		if free and gait.vel.length() > 0.2:
			aL.x = g.armL; aR.x = g.armR
			eL.x = maxf(eL.x, g.elbow + maxf(0.0, -g.armL) * 0.2); eR.x = maxf(eR.x, g.elbow + maxf(0.0, -g.armR) * 0.2)
			aL.z = -0.09; aR.z = 0.09
	# ---- drive the skeleton
	var a_l := _sm("armL", aL, k); var a_r := _sm("armR", aR, k)
	var e_l := _sm("elbowL", eL, k); var e_r := _sm("elbowR", eR, k)
	var l_l := _sm("legL", lL, k); var l_r := _sm("legR", lR, k)
	var k_l := _sm("kneeL", kL, k); var k_r := _sm("kneeR", kR, k)
	var t_s := _sm("torso", tor, k); var h_s := _sm("head", hd, k * 0.6); var hp := _sm("hips", hipr, k)
	_hip_y = lerpf(_hip_y, hip_y, k)
	hips.position.y = _hip_y
	var drop := (_hip_y - 0.9) / 0.9
	if not gait_on and not seated_gait:
		skel.set_bone_pose_position(_bone["pelvis"], _pelvis_rest + Vector3(0, drop * _pelvis_rest.y, 0))
	_pose("pelvis", "", _eul(hp))
	var third := t_s / 3.0
	_pose("spine_01", "", _eul(third)); _pose("spine_02", "", _eul(third)); _pose("spine_03", "", _eul(third))
	_pose("neck_01", "", _eul(h_s * 0.4)); _pose("head", "", _eul(h_s * 0.6))
	# shoulders rise a little with the arm
	_pose("clavicle_l", "", _eul(Vector3(0, 0, clampf(-a_l.z * 0.18 - absf(a_l.x) * 0.05, -0.3, 0.3))))
	_pose("clavicle_r", "", _eul(Vector3(0, 0, clampf(-a_r.z * 0.18 + absf(a_r.x) * 0.05, -0.3, 0.3))))
	_pose("upperarm_l", "", _eul(a_l)); _pose("upperarm_r", "", _eul(a_r))
	_pose("lowerarm_l", "upperarm_l", _eul(e_l)); _pose("lowerarm_r", "upperarm_r", _eul(e_r))
	_pose("hand_l", "lowerarm_l", Quaternion.IDENTITY); _pose("hand_r", "lowerarm_r", Quaternion.IDENTITY)
	if not gait_on and not seated_gait:
		_pose("thigh_l", "", _eul(l_l)); _pose("thigh_r", "", _eul(l_r))
		_pose("calf_l", "", _eul(k_l)); _pose("calf_r", "", _eul(k_r))
	# feet stay level with the ground through the stride, rolling off the toe
	var planted := state in ["idle", "talk", "crouch"] or (state != "sit" and state != "drive" and state != "pillion" and state != "ko" and state != "air")
	if seated_gait:
		gait.apply_seat(delta)
	elif gait_on:
		gait.apply(delta)
		if gait_measure:
			gait.measure()
	elif planted:
		_pose("foot_l", "", _eul(Vector3(-(l_l.x + k_l.x) + maxf(0.0, -l_l.x) * 0.35 - hp.x, 0, -l_l.z)))
		_pose("foot_r", "", _eul(Vector3(-(l_r.x + k_r.x) + maxf(0.0, -l_r.x) * 0.35 - hp.x, 0, -l_r.z)))
	else:
		_pose("foot_l", "", _eul(Vector3(0.25, 0, 0))); _pose("foot_r", "", _eul(Vector3(0.25, 0, 0)))
	_reach_ik(delta)
	# hands: relaxed curl, a fist to hit, a grip when holding something
	var want_fist := 0.25
	if _shot_t > 0.0 and _shot in ["punch", "leap"]: want_fist = 1.0
	if activity in ["cheer", "shout"]: want_fist = 0.9 if activity == "cheer" else 0.4
	if activity in ["dust", "hold", "bend", "wave_star"] or (_shot_t > 0.0 and _shot in ["push", "facepalm", "calm", "point_small"]): want_fist = 0.1
	if prop != "" or activity in ["carry", "load", "tray", "sweep", "work", "fix", "pour", "phone", "umbrella"] or state == "drive": want_fist = 0.75
	if _shot_t > 0.0 and _shot in ["namaste", "wave", "salute"]: want_fist = 0.02
	if talk_t > 0.0: want_fist = 0.3 + 0.2 * sin(_t * 2.3 + _seed)
	_fist = lerpf(_fist, want_fist, k)
	if near or detail >= 2:
		for s in ["l", "r"]:
			for f in ["index", "middle", "ring", "pinky", "thumb"]:
				var amt := _fist * (1.25 if f != "thumb" else 0.5)
				for kk in ["01", "02", "03"]:
					var bn := "%s_%s_%s" % [f, kk, s]
					var par: String = "hand_" + s if kk == "01" else "%s_%s_%s" % [f, "01" if kk == "02" else "02", s]
					_pose(bn, par, Quaternion(_curl[bn], amt * (0.8 if kk == "01" else 1.0)))
	body.rotation.x = lerpf(body.rotation.x, body_rx, k * 0.6)
	if state == "sit":
		body_y += seat_lift
	body.position.y = lerpf(body.position.y - _gy, body_y, k) + _gy
	var yaw_now := global_rotation.y
	var dyaw := wrapf(yaw_now - _last_yaw, -PI, PI)
	var yr := dyaw / maxf(delta, 0.001) if absf(dyaw) < 0.6 else 0.0      # a snap (teleport) is not a turn to lean into
	_last_yaw = yaw_now
	_tilt = lerpf(_tilt, clampf(-yr * 0.03 * minf(speed, 5.0), -0.18, 0.18), 1.0 - exp(-6.0 * delta))
	body.rotation.z = _tilt
	for pk in _props:
		_props[pk].visible = pk == prop
	if near:
		_face(delta)
	if not _card_mats.is_empty() and cd < 25.0 * 25.0:
		_hair_motion(delta)

## A push that takes the feet away: staggering back, sitting down hard onto the hands,
## a beat on the ground, then onto one knee and up. Keyframes in seconds.
const FALL_KEYS := [
	[0.00, {"hip": 0.90, "tor": Vector3(0.0, 0, 0), "hd": Vector3(0, 0, 0), "aL": Vector3(0.2, 0, -0.1), "aR": Vector3(0.2, 0, 0.1), "eL": 0.3, "eR": 0.3, "lL": Vector3(0, 0, 0), "lR": Vector3(0, 0, 0), "kL": 0.0, "kR": 0.0}],
	[0.22, {"hip": 0.86, "tor": Vector3(0.38, 0, 0.05), "hd": Vector3(-0.25, 0, 0), "aL": Vector3(1.1, 0, -0.9), "aR": Vector3(0.9, 0, 1.0), "eL": 0.5, "eR": 0.6, "lL": Vector3(0.35, 0, 0), "lR": Vector3(-0.55, 0, 0), "kL": -0.3, "kR": -0.25}],
	[0.45, {"hip": 0.6, "tor": Vector3(0.55, 0, -0.05), "hd": Vector3(-0.3, 0, 0), "aL": Vector3(-0.5, 0, -0.5), "aR": Vector3(-0.6, 0, 0.5), "eL": 0.25, "eR": 0.2, "lL": Vector3(1.1, 0, -0.1), "lR": Vector3(0.7, 0, 0.1), "kL": -1.2, "kR": -1.3}],
	[0.62, {"hip": 0.24, "tor": Vector3(0.62, 0, 0), "hd": Vector3(-0.15, 0, 0), "aL": Vector3(-0.85, 0, -0.35), "aR": Vector3(-0.9, 0, 0.35), "eL": 0.15, "eR": 0.15, "lL": Vector3(1.85, 0, -0.18), "lR": Vector3(1.6, 0, 0.18), "kL": -1.75, "kR": -1.5}],
	[1.25, {"hip": 0.24, "tor": Vector3(0.48, 0, 0), "hd": Vector3(0.1, 0.25, 0), "aL": Vector3(-0.8, 0, -0.32), "aR": Vector3(-0.85, 0, 0.32), "eL": 0.2, "eR": 0.2, "lL": Vector3(1.8, 0, -0.18), "lR": Vector3(1.55, 0, 0.18), "kL": -1.8, "kR": -1.45}],
	[1.75, {"hip": 0.5, "tor": Vector3(-0.45, 0, 0), "hd": Vector3(0.2, 0, 0), "aL": Vector3(0.6, 0, -0.2), "aR": Vector3(0.75, 0, 0.15), "eL": 0.25, "eR": 0.2, "lL": Vector3(1.55, 0, -0.1), "lR": Vector3(0.05, 0, 0.1), "kL": -1.65, "kR": -1.75}],
	[2.3, {"hip": 0.7, "tor": Vector3(-0.5, 0, 0), "hd": Vector3(0.15, 0, 0), "aL": Vector3(0.35, 0, -0.1), "aR": Vector3(0.9, 0, 0.1), "eL": 0.3, "eR": 1.2, "lL": Vector3(1.2, 0, -0.05), "lR": Vector3(-0.1, 0, 0.05), "kL": -1.35, "kR": -1.2}],
	[2.9, {"hip": 0.88, "tor": Vector3(-0.12, 0, 0), "hd": Vector3(0.05, 0, 0), "aL": Vector3(0.15, 0, -0.1), "aR": Vector3(0.2, 0, 0.1), "eL": 0.4, "eR": 0.5, "lL": Vector3(0.15, 0, 0), "lR": Vector3(-0.05, 0, 0), "kL": -0.2, "kR": -0.15}],
	[3.2, {"hip": 0.9, "tor": Vector3(0.0, 0, 0), "hd": Vector3(0, 0, 0), "aL": Vector3(0.1, 0, -0.07), "aR": Vector3(0.1, 0, 0.07), "eL": 0.15, "eR": 0.15, "lL": Vector3(0, 0, 0), "lR": Vector3(0, 0, 0), "kL": 0.0, "kR": 0.0}],
]

static func _fall_pose(t: float) -> Dictionary:
	var keys: Array = FALL_KEYS
	var i := 0
	while i < keys.size() - 2 and t > float(keys[i + 1][0]):
		i += 1
	var a: Dictionary = keys[i][1]
	var b: Dictionary = keys[i + 1][1]
	var u := clampf((t - float(keys[i][0])) / (float(keys[i + 1][0]) - float(keys[i][0])), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var out := {}
	for kk in a:
		var va = a[kk]
		var vb = b[kk]
		if va is Vector3:
			out[kk] = (va as Vector3).lerp(vb, u)
		else:
			out[kk] = lerpf(float(va), float(vb), u)
	for kk in ["eL", "eR"]:
		out[kk] = Vector3(float(out[kk]), 0, 0)
	for kk in ["kL", "kR"]:
		out[kk] = Vector3(float(out[kk]), 0, 0)
	return out

## Hair motion: the hair's mass (a point a little above and behind the head centre) is
## carried on a damped spring. When the head moves, turns, starts or stops, the mass lags
## and overshoots a little; a light breeze moves it too. The lag, in the body's own space,
## drives the card shader's tip offset, so the roots never leave the scalp.
func _hair_motion(delta: float) -> void:
	if head == null:
		return
	var target := head.global_transform * Vector3(0, 0.1, 0.03)
	if not _hs_init:
		_hs = target
		_hsv = Vector3.ZERO
		_hs_init = true
	var dt := minf(delta, 0.05)
	var k := 70.0
	var c := 9.0
	_hsv += ((target - _hs) * k - _hsv * c) * dt
	_hs += _hsv * dt
	var lag := _hs - target
	if lag.length() > 0.06:
		lag = lag.normalized() * 0.06
		_hs = target + lag
	var wind := Vector3(sin(_t * 1.3 + _seed) * 0.004 + sin(_t * 3.1) * 0.0015, 0, cos(_t * 1.1 + _seed) * 0.003)
	var local := (skel.global_transform.basis.inverse() * (lag * 0.8 + wind))
	for m in _card_mats:
		(m as ShaderMaterial).set_shader_parameter("sway", local)

func _m(nm: String, target: float, k: float) -> void:
	var v: float = lerpf(float(_morph.get(nm, 0.0)), target, k)
	_morph[nm] = v

## The face: blinking at irregular intervals, gaze that leads the head, speech,
## and moods that ease in and out through the expression morphs.
func _face(delta: float) -> void:
	_blink -= delta
	var fast := 0.45 if mood == "nervous" else 1.0
	if _blink <= 0.0:
		_blink = randf_range(1.6, 5.5) * fast
		_blink_t = 0.17
		if randf() < 0.2:
			_blink = 0.32
		_dart = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * (1.0 if mood == "nervous" else 0.35)
	_blink_t = maxf(0.0, _blink_t - delta)
	var closed := sin(clampf(_blink_t / 0.17, 0.0, 1.0) * PI)
	var talking := talk_t > 0.0 or state == "talk" or activity in ["argue", "laugh", "phone"]
	var em := emotion
	var w := {"blink": closed, "jaw_open": 0.0, "lips_part": 0.0, "smile": 0.0, "frown": 0.0, "brow_up": 0.0, "brow_down": 0.0, "brow_sad": 0.0, "squint": 0.0, "pucker": 0.0, "wide": 0.0, "sneer": 0.0}
	if talking:
		var sy := absf(sin(_t * 9.5 + _seed)) * (0.45 + 0.55 * absf(sin(_t * 3.3 + _seed * 2.0)))
		w.jaw_open = sy * 0.5
		w.lips_part = 0.3 + sy * 0.3
		w.pucker = maxf(0.0, sin(_t * 4.1 + _seed)) * 0.35
		w.wide = maxf(0.0, sin(_t * 5.7)) * 0.25
		w.brow_up = maxf(0.0, sin(_t * 1.9 + _seed)) * 0.35
	match mood:
		"angry": em -= 0.9
		"sad":
			w.brow_sad = 0.9; w.frown = 0.6; w.blink = maxf(w.blink, 0.2)
		"smile": em += 0.9
		"surprise":
			w.brow_up = 1.0; w.jaw_open = maxf(w.jaw_open, 0.45); w.lips_part = 0.6
		"scream":
			em -= 1.0; w.jaw_open = 1.0; w.lips_part = 1.0; w.wide = 0.6; w.squint = 0.4
		"glare":
			em -= 0.85; w.squint = 0.55; w.lips_part = 0.05; w.blink = minf(w.blink, 0.15)
		"smirk":
			em += 0.45; w.sneer = 0.35; w.squint = 0.3
		"frustrated":
			em -= 0.6; w.brow_sad = 0.3; w.lips_part = 0.25
		"nervous":
			w.brow_sad = 0.6; w.lips_part = 0.2; w.wide = 0.3
		"tired":
			w.blink = maxf(w.blink, 0.5); w.frown = 0.3
	if activity == "argue": em -= 0.8
	if activity == "laugh":
		em += 1.0
		w.jaw_open = maxf(w.jaw_open, 0.4 + 0.2 * sin(_t * 12.0))
	if activity == "listen":
		w.brow_up = maxf(w.brow_up, maxf(0.0, sin(_t * 0.7 + _seed)) * 0.4)
		if em < -0.2: w.brow_sad = 0.4
	if em > 0.0:
		w.smile = clampf(em, 0.0, 1.0)
		w.squint = maxf(w.squint, em * 0.3)
	else:
		w.brow_down = clampf(-em, 0.0, 1.0)
		w.frown = clampf(-em * 0.6, 0.0, 1.0)
		w.sneer = maxf(w.sneer, clampf(-em - 0.6, 0.0, 0.5))
	var kf := 1.0 - exp(-9.0 * delta)
	for nm in w:
		if nm == "blink":
			_morph[nm] = w[nm]
		else:
			_m(nm, w[nm], kf)
	for mi in _faces:
		if not mi.is_visible_in_tree():
			continue
		var msh: Mesh = mi.mesh
		for i in msh.get_blend_shape_count():
			var bn := String(msh.get_blend_shape_name(i))
			if bn == "blink_l" or bn == "blink_r":
				mi.set_blend_shape_value(i, clampf(float(_morph["blink"]) + float(_morph.get("squint", 0.0)) * 0.3, 0.0, 1.0))
			elif _morph.has(bn):
				mi.set_blend_shape_value(i, float(_morph[bn]))
	# eyes
	var gx := _dart.x * 0.25
	var gy := _dart.y * 0.12
	if look_target != null:
		var to: Vector3 = (look_target as Vector3) - (global_position + Vector3(0, 1.55 * _scale, 0))
		var rel := wrapf(atan2(-to.x, -to.z) - global_rotation.y - float(_rot.get("head", Vector3.ZERO).y), -PI, PI)
		gx = clampf(rel, -0.55, 0.55)
		gy = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.3, 0.3)
	var eq := Quaternion.from_euler(Vector3(gy, gx, 0))
	skel.set_bone_pose_rotation(_bone["eye_l"], eq)
	skel.set_bone_pose_rotation(_bone["eye_r"], eq)
