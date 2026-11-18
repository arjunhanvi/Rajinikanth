extends Node3D
# Character evaluation scene: a fixed set of cameras and lighting presets, so every change to a
# character is judged from the same views under the same light.
#   godot --path . --resolution 1600x900 res://tools/dev/lookdev.tscn -- <model> <out_dir> [set]
# set: "all" (default), "anatomy", "face", "light"
# Tone mapping and exposure match the game (Weather.gd: filmic, exposure 0.95, white 6).

var cam: Camera3D
var h: Human
var out := "/tmp/lookdev"
var env: Environment
var lights: Array[Node] = []
var ey := 1.62

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var model: String = a[0] if a.size() > 0 else "raja"
	out = a[1] if a.size() > 1 else out
	var which: String = a[2] if a.size() > 2 else "all"
	DirAccess.make_dir_recursive_absolute(out)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	we.environment = env
	add_child(we)
	# a neutral mid-grey floor and a backdrop far behind (so silhouettes read)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.32, 0.33)
	fm.roughness = 0.9
	fl.material_override = fm
	add_child(fl)
	cam = Camera3D.new()
	add_child(cam)
	var look: Dictionary = People.look_of(model) if model in People.DB else Human.default_look()
	look["model"] = model
	h = Human.make(look, 2)
	add_child(h)
	h.ground_follow = false
	if Human.manifest.has(model):
		ey = float(Human.manifest[model].eye_y)
	# optional 4th argument: comma-separated parts to hide (for diagnosing a visual defect)
	if a.size() > 3:
		for part in String(a[3]).split(","):
			for mi in h.find_children("L*_" + part, "MeshInstance3D", true, false):
				mi.visible = false
	await _settle(30)
	if which in ["all", "anatomy"]:
		await _anatomy()
	if which in ["all", "face"]:
		await _face()
	if which in ["all", "light"]:
		await _lighting()
	get_tree().quit()

# ------------------------------------------------------------------ lighting presets
func _clear_lights() -> void:
	for l in lights:
		l.queue_free()
	lights.clear()

func _dir(rot: Vector3, c: Color, e: float, shadow := true) -> void:
	var d := DirectionalLight3D.new()
	d.rotation_degrees = rot
	d.light_color = c
	d.light_energy = e
	d.shadow_enabled = shadow
	d.shadow_bias = 0.04
	d.shadow_normal_bias = 1.4
	d.directional_shadow_max_distance = 10.0
	add_child(d)
	lights.append(d)

func _omni(p: Vector3, c: Color, e: float, rng := 6.0) -> void:
	var o := OmniLight3D.new()
	o.position = p
	o.light_color = c
	o.light_energy = e
	o.omni_range = rng
	o.shadow_enabled = true
	add_child(o)
	lights.append(o)

func _amb(c: Color, e: float) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = c.darkened(0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = c
	env.ambient_light_energy = e

## The character faces -Z; yaw 180 puts a light in front of him.
func preset(name: String) -> void:
	_clear_lights()
	match name:
		"studio":      # key 35° to his right and above, soft fill, a rim from behind
			_amb(Color(0.62, 0.63, 0.66), 0.35)
			_dir(Vector3(-32, 145, 0), Color(1, 0.98, 0.95), 1.15)
			_dir(Vector3(-10, -140, 0), Color(0.9, 0.93, 1.0), 0.32, false)
			_dir(Vector3(-25, 10, 0), Color(1, 1, 1), 0.45, false)
		"sun":         # Bengaluru morning sun, blue sky fill
			_amb(Color(0.55, 0.66, 0.85), 0.5)
			_dir(Vector3(-48, 160, 0), Color(1.0, 0.95, 0.86), 1.45)
		"shade":       # open shade: no direct sun, only the sky
			_amb(Color(0.62, 0.7, 0.85), 1.0)
			_dir(Vector3(-70, 180, 0), Color(0.75, 0.82, 0.95), 0.18, false)
		"overcast":    # grey sky, soft top light
			_amb(Color(0.72, 0.73, 0.76), 0.85)
			_dir(Vector3(-80, 170, 0), Color(0.9, 0.9, 0.92), 0.35)
		"indoor_warm": # a tungsten bulb above and in front
			_amb(Color(0.5, 0.4, 0.32), 0.18)
			_omni(Vector3(0.6, 2.3, -1.4), Color(1.0, 0.72, 0.45), 2.4)
		"indoor_cool": # a tube light
			_amb(Color(0.5, 0.55, 0.6), 0.25)
			_omni(Vector3(-0.4, 2.5, -1.2), Color(0.85, 0.93, 1.0), 2.2)
		"side":        # hard side light
			_amb(Color(0.5, 0.52, 0.56), 0.12)
			_dir(Vector3(-15, 90, 0), Color(1, 0.97, 0.92), 1.3)
		"back":        # light from behind, face in shadow
			_amb(Color(0.55, 0.58, 0.64), 0.3)
			_dir(Vector3(-25, 0, 0), Color(1, 0.96, 0.9), 1.5)
		"low":         # evening: a weak warm practical light, cool ambient
			_amb(Color(0.3, 0.36, 0.5), 0.15)
			_omni(Vector3(1.0, 1.8, -1.0), Color(1.0, 0.75, 0.5), 0.9)

# ------------------------------------------------------------------ shots
func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(n: String, pos: Vector3, at: Vector3, fov := 30.0, frames := 12) -> void:
	cam.fov = fov
	cam.position = pos
	cam.look_at(at)
	Human.cam_pos = pos
	await _settle(frames)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])

func _bone(b: String) -> Vector3:
	return h.skel.global_transform * h.skel.get_bone_global_pose(h.skel.find_bone(b)).origin

func _anatomy() -> void:
	preset("studio")
	await shot("a01_full_front", Vector3(0, 0.95, -4.4), Vector3(0, 0.9, 0), 30, 30)
	await shot("a02_full_side", Vector3(4.4, 0.95, 0), Vector3(0, 0.9, 0), 30)
	await shot("a03_full_back", Vector3(0, 0.95, 4.4), Vector3(0, 0.9, 0), 30)
	await shot("a04_full_34", Vector3(-3.1, 1.0, -3.1), Vector3(0, 0.9, 0), 30)
	await shot("a05_torso_34", Vector3(-1.1, 1.35, -1.3), Vector3(0, 1.2, 0), 34)
	var hl := _bone("hand_l")
	await shot("a06_hand", hl + Vector3(-0.35, 0.05, -0.32), hl + Vector3(0, -0.06, 0), 26)
	await shot("a07_hand_back", hl + Vector3(-0.2, 0.08, 0.38), hl + Vector3(0, -0.06, 0), 26)
	await shot("a08_feet", Vector3(0.55, 0.28, -1.05), Vector3(0, 0.08, 0), 34)
	await shot("a09_feet_side", Vector3(1.1, 0.2, -0.1), Vector3(0, 0.08, 0), 30)
	await shot("a10_shirt", Vector3(0.2, 1.3, -1.0), Vector3(0, 1.2, 0), 34)

func _face() -> void:
	preset("studio")
	var f := Vector3(0, ey - 0.03, 0)
	await shot("f01_face_front", Vector3(0, ey, -0.62), f, 30, 20)
	await shot("f02_face_side", Vector3(0.62, ey, -0.05), f, 30)
	await shot("f03_face_34", Vector3(-0.44, ey + 0.02, -0.46), f, 30)
	await shot("f04_eyes", Vector3(0, ey + 0.01, -0.34), Vector3(0, ey, 0), 22)
	await shot("f05_mouth", Vector3(0, ey - 0.09, -0.32), Vector3(0, ey - 0.1, 0), 24)
	await shot("f06_hairline", Vector3(-0.3, ey + 0.16, -0.38), Vector3(0, ey + 0.07, 0), 28)
	await shot("f07_hair_top", Vector3(0.0, ey + 0.55, -0.35), Vector3(0, ey + 0.08, 0), 34)
	await shot("f08_brow_moustache", Vector3(-0.18, ey - 0.02, -0.36), Vector3(0, ey - 0.04, 0), 26)
	# expressions, front
	var k := 0
	for e in ["neutral", "happy", "irritated", "angry", "confused", "nervous", "tired", "surprised"]:
		h.mood = e
		await shot("e%d_%s" % [k, e], Vector3(0, ey, -0.62), f, 30, 34)
		await shot("e%d_%s_34" % [k, e], Vector3(-0.4, ey + 0.01, -0.48), f, 30, 4)
		k += 1
	h.mood = ""
	h.talk_t = 6.0
	for i in 4:
		await shot("t%d_talk" % i, Vector3(0, ey, -0.62), f, 30, 5 + i * 3)
	h.talk_t = 0.0
	await _settle(20)

func _lighting() -> void:
	var f := Vector3(0, ey - 0.03, 0)
	for p in ["studio", "sun", "shade", "overcast", "indoor_warm", "indoor_cool", "side", "back", "low"]:
		preset(p)
		await shot("l_" + p + "_face34", Vector3(-0.44, ey + 0.02, -0.46), f, 30, 14)
		await shot("l_" + p + "_body", Vector3(-1.6, 1.25, -2.4), Vector3(0, 1.05, 0), 30, 8)
