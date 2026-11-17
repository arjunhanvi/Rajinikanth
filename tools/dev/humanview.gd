extends Node3D
# Dev: renders a character through the real Human class.
# godot --path . res://tools/dev/humanview.tscn -- <model|look-json> [tag]
var cam: Camera3D
var h: Human
var tag := ""
func shot(n: String, pos: Vector3, look: Vector3, fov := 30.0, frames := 20) -> void:
	cam.fov = fov; cam.position = pos; cam.look_at(look); Human.cam_pos = pos
	for i in frames: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/hv_%s_%s.png" % [tag, n])
func _ready():
	var a = OS.get_cmdline_user_args()
	var nm: String = a[0] if a.size() > 0 else "raji"
	tag = a[1] if a.size() > 1 else nm
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.3, 0.31, 0.34)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.75, 0.76, 0.82); env.environment.ambient_light_energy = 0.5
	add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-32, 152, 0); sun.light_energy = 1.15; sun.shadow_enabled = true; sun.shadow_bias = 0.12; sun.shadow_normal_bias = 3.0; sun.directional_shadow_max_distance = 12.0; add_child(sun)
	var fill = DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-10, -140, 0); fill.light_energy = 0.3; add_child(fill)
	var fl = MeshInstance3D.new(); var pm = PlaneMesh.new(); pm.size = Vector2(12, 12); fl.mesh = pm; fl.material_override = Mats.col(Color(0.36, 0.36, 0.38)); add_child(fl)
	cam = Camera3D.new(); add_child(cam)
	var look: Dictionary
	if nm.begins_with("{"): look = JSON.parse_string(nm)
	elif nm in People.DB: look = People.look_of(nm)
	else:
		look = Human.default_look(); look["model"] = nm
	var legacy := a.has("legacy")
	var node: Node3D
	if legacy:
		look.erase("model")
		node = HumanLegacy.make(look, 2)
	else:
		h = Human.make(look, 2); node = h
	add_child(node)
	var ey := 1.62
	if not legacy and Human.manifest.has(h.model): ey = float(Human.manifest[h.model].eye_y)
	await shot("full", Vector3(0, 0.95, -4.3), Vector3(0, 0.9, 0), 30, 40)
	await shot("face", Vector3(0.1, ey + 0.02, -0.62), Vector3(0, ey - 0.02, 0), 30)
	await shot("face34", Vector3(-0.42, ey + 0.03, -0.5), Vector3(0, ey - 0.02, 0), 30)
	if legacy:
		get_tree().quit(); return
	await shot("back", Vector3(0.6, 1.3, 3.3), Vector3(0, 0.95, 0), 30)
	await shot("hand", Vector3(-0.62, 0.86, -0.5), Vector3(-0.27, 0.82, 0), 22)
	await shot("feet", Vector3(0.6, 0.25, -1.1), Vector3(0, 0.1, 0), 40)
	await shot("feet_far", Vector3(1.5, 0.6, -6.5), Vector3(0, 0.1, 0), 30)
	await shot("cloth", Vector3(0.25, 1.25, -0.95), Vector3(0, 1.2, 0), 34)
	for e in [["smile", "smile"], ["angry", "angry"], ["surprise", "surprise"], ["sad", "sad"]]:
		h.mood = e[1]
		await shot("expr_" + e[0], Vector3(0.05, ey + 0.01, -0.6), Vector3(0, ey - 0.02, 0), 30, 30)
	h.mood = ""; h.talk_t = 5.0; h.look_target = Vector3(-1.0, ey, -2.0)
	await shot("talk", Vector3(-0.3, ey + 0.02, -0.85), Vector3(0, ey - 0.08, 0), 34, 36)
	h.talk_t = 0.0; h.look_target = null
	h.speed = 1.4
	await shot("walk1", Vector3(-3.0, 1.0, -2.4), Vector3(0, 0.9, 0), 30, 22)
	await shot("walk2", Vector3(-3.0, 1.0, -2.4), Vector3(0, 0.9, 0), 30, 9)
	h.speed = 5.2
	await shot("run", Vector3(-3.0, 1.0, -2.4), Vector3(0, 0.9, 0), 30, 26)
	h.speed = 0.0; h.state = "sit"
	await shot("sit", Vector3(-2.6, 1.0, -2.2), Vector3(0, 0.7, 0), 30, 40)
	h.state = "idle"; h.rotation.y = 1.2; h.play_once("namaste", 3.0)
	await shot("turn_greet", Vector3(-1.2, 1.25, -2.6), Vector3(0, 1.0, 0), 30, 40)
	h.rotation.y = 0.0; h.play_once("salute", 3.0)
	await shot("salute", Vector3(0, 1.1, -3.3), Vector3(0, 1.0, 0), 30, 40)
	get_tree().quit()
