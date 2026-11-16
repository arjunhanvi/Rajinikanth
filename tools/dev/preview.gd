extends Node3D
# Dev tool: renders stills of generated chunks. godot --path . res://tools/dev/preview.tscn -- x z [radius]
func _ready():
	var a = OS.get_cmdline_user_args()
	var px = float(a[0]) if a.size() > 0 else 0.0
	var pz = float(a[1]) if a.size() > 1 else 60.0
	var rad = int(a[2]) if a.size() > 2 else 2
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.62, 0.7); env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 35, 0); sun.shadow_enabled = true; add_child(sun)
	var cc = City.chunk_of(Vector2(px, pz))
	var t0 = Time.get_ticks_msec()
	for dx in range(-rad, rad + 1):
		for dz in range(-rad, rad + 1):
			var ch = Chunk.new(); add_child(ch); ch.build(cc + Vector2i(dx, dz))
	print("built ", (rad * 2 + 1) * (rad * 2 + 1), " chunks in ", Time.get_ticks_msec() - t0, " ms")
	var cam = Camera3D.new(); add_child(cam); cam.far = 2000
	var shots = [[Vector3(px, 260, pz + 40), Vector3(px, 0, pz), "top"], [Vector3(px + 3, 1.7, pz + 2), Vector3(px + 60, 3, pz + 1), "street"], [Vector3(px - 30, 14, pz + 40), Vector3(px + 10, 2, pz - 20), "mid"]]
	for s in shots:
		cam.position = s[0]; cam.look_at(s[1])
		for i in 4: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/pv_%s.png" % s[2])
	get_tree().quit()
