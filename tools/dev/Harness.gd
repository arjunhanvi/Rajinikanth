extends Node
## Automated play-test driver (dev only). Run: tools/playtest.sh <scenario>
var scenario := ""
var out := "/tmp/rk_shots/"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("_run")

func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + nm + ".png")
	print("[shot] ", nm)

func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func world():
	return Game.world

func tp(p: Vector3, yaw := 0.0) -> void:
	var w = world()
	w.player.global_position = p
	w.player.yaw = yaw
	w._want_chunks(true)
	await wait(0.3)

func _run() -> void:
	if not scenario.begins_with("ui"):
		await wait(1.0)
	if has_method("s_" + scenario):
		await call("s_" + scenario)
	else:
		print("unknown scenario ", scenario)
	print("[harness] done")
	get_tree().quit()

func s_boot() -> void:
	await wait(4.0)
	await shot("boot_start")
	var w = world()
	print("fps ", Engine.get_frames_per_second(), " npcs ", w.crowd.npcs.size(), " traffic ", w.traffic.moving.size(), " chunks ", w.chunks.size())

func s_tour() -> void:
	var w = world()
	await wait(2.5)
	await shot("t1_home_street")
	w.player.yaw = PI
	await wait(0.6)
	await shot("t2_home_front")
	Game.s.time = 8.0
	w.crowd.resync()
	await tp(Vector3(-25, 0, 100.0), 0.6)
	w.player.yaw = PI
	w.player.pitch = -0.1
	await wait(3.0)
	await shot("t3_tea_stall")
	Game.s.time = 6.3
	await tp(Vector3(52, 0, -6), 0.0)
	await wait(2.0)
	await shot("t4_bus_station")
	await tp(Vector3(60, 0, 2), -PI * 0.5)
	await wait(4.0)
	await shot("t5_kg_road_traffic")
	Game.s.time = 20.0
	await wait(2.0)
	await shot("t6_night")
	Game.s.time = 15.0
	Game.s.weather = "rain"
	w.weather.cloud = 1.0; w.weather.raining = 1.0; w.weather.wet = 1.0
	await wait(2.0)
	await shot("t7_rain")
	print("fps ", Engine.get_frames_per_second(), " npcs ", w.crowd.npcs.size(), " traffic ", w.traffic.moving.size())

func ok(cond: bool, what: String) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", what])

func s_ui() -> void:
	var intro = Game.boot.current
	for t in [[1.6, "u1a_hanvis_setting"], [3.4, "u1b_logo_mid"], [8.5, "u1c_logo_full"], [17.0, "u2a_star"], [24.2, "u2b_title_landing"], [31.0, "u2c_title_full"]]:
		while intro._t < t[0]:
			await get_tree().process_frame
		await shot(t[1])
	print("intro track available=", Sfx.intro_available(), " playing=", Sfx.intro_playing(), " length=", Sfx._intro.stream.get_length() if Sfx._intro.stream != null else -1.0)
	await wait(1.2)
	await shot("u3_menu")
	print("still playing in menu=", Sfx.intro_playing())
	Game.goto("creator", {"slot": 0, "mode": "free"})
	await wait(1.0)
	await shot("u4_creator")
	Game.start_new(Game.SLOTS - 1, "story", "Rajinikanth", Human.default_look())
	Game.goto("world")
	await wait(4.0)
	print("after entering world, intro playing=", Sfx.intro_playing())

func s_panels() -> void:
	var w = world()
	await wait(2.0)
	Game.s.phone = true
	Game.add_contact("immu")
	Game.add_message("'Oil' Kumar", "Kaveri Bar. After 8.")
	w.hud.open_phone()
	await wait(0.4)
	await shot("p1_phone")
	w.hud._phone.closed.emit()
	await wait(0.2)
	w.hud.open_map()
	await wait(0.4)
	await shot("p2_map_area")
	w.hud._full_map.zoom_to(0.1)
	w.hud._full_map.centre = Vector2(800, 0)
	await wait(1.2)
	await shot("p2_map_city")
	w.hud._full_map.centre = Vector2(-20, 60)
	w.hud._full_map.zoom_to(1.3)
	await wait(1.2)
	w.hud._full_map._tap(w.hud._full_map.w2s(Vector2(City.PLACES["police"].pos.x, City.PLACES["police"].pos.z)))
	w.hud._set_wp(Vector2(City.np("mgroad")))
	await wait(0.3)
	await shot("p2_map_street")
	w.hud.close_map()
	w.hud.say("Nanjappa", "Tea is two rupees. Advice is free. Guess which one people take.")
	await wait(0.6)
	await shot("p3_dialogue")
	w.hud.end_talk()
	w.hud.open_pause()
	await wait(0.3)
	await shot("p4_pause")
	w.hud.close_pause()
	var veh = Vehicle.create("car", 2)
	w.traffic.add_child(veh)
	veh.global_position = w.player.global_position + Vector3(3, 0, 0)
	w.player.enter_vehicle(veh)
	Input.action_press("mv_u")
	await wait(2.0)
	await shot("p5_driving")
	Input.action_release("mv_u")

func s_streets() -> void:
	var w = world()
	Game.s.time = 10.5
	w.crowd.resync()
	var views = [["majestic_lane", Vector3(30, 0, 150), 1.2], ["chickpet", Vector3(City.np("chickpet").x + 30, 0, City.np("chickpet").y + 50), -1.5], ["malleshwaram", Vector3(City.np("malleshwaram").x + 80, 0, City.np("malleshwaram").y + 100), 1.5],
		["mgroad", Vector3(City.np("mgroad").x - 40, 0, City.np("mgroad").y + 3), -1.57], ["jayanagar", Vector3(City.np("jayanagar").x + 20, 0, City.np("jayanagar").y + 150), -1.6], ["peenya", Vector3(City.np("peenya").x + 30, 0, City.np("peenya").y + 100), 1.5]]
	for v in views:
		await tp(v[1], v[2])
		w.player.pitch = -0.12
		await wait(3.0)
		await shot("st_" + v[0])
	print("fps ", Engine.get_frames_per_second(), " npcs ", w.crowd.npcs.size())

# ------------------------------------------------------------------ BIG BANG LORE: the opening, end to end
var _beats: Array = []
var _raja_fell := false
var _lal_seen_at_fall := true

func s_opening() -> void:
	var w = world()
	ok(str(ProjectSettings.get_setting("application/config/name")) == "Big Bang Lore", "project identity is BIG BANG LORE")
	ok(w.crowd.named.is_empty(), "no RAJINIKANTH cast spawned")
	ok(Game.SAVE_DIR.ends_with("saves_bbl/"), "old saves are not read")
	var t := 0.0
	while w.story.opening == null and t < 10.0:
		await wait(0.1)
		t += 0.1
	var op = w.story.opening
	ok(op != null, "opening sequence started")
	if op == null:
		return
	op.beat.connect(func(b: String):
		_beats.append(b)
		if b == "raja_falls":
			_raja_fell = op.raja.state == "fall"
			_lal_seen_at_fall = op.cast["lal"].visible
		_beat_shot(b))
	ok(w.player.human.model == "raja", "player body is Raja")
	while op.raja == null:
		await wait(0.1)
	ok(op.cast["lal"].model == "lal" and op.cast["lal"].model != op.raja.model, "Lal has his own body, distinct from Raja's")
	ok(w.get_node_or_null("Chunk") != null or true, "")
	# play through; when control is handed over, walk about a bit like a player would
	t = 0.0
	var moved := false
	while op.phase != "done" and t < 600.0:
		await wait(0.25)
		t += 0.25
		if op.phase == "play" and not moved:
			moved = true
			var p0: Vector3 = w.player.global_position
			Input.action_press("mv_l")
			await wait(1.2)
			Input.action_release("mv_l")
			Input.action_press("mv_u")
			await wait(0.8)
			Input.action_release("mv_u")
			await shot("op_play_moved")
			ok(w.player.global_position.distance_to(p0) > 0.8, "player can walk in the crowd after the hand-over (moved %.1f m)" % w.player.global_position.distance_to(p0))
	var lm = null
	for c in w.chunks.values():
		var n = c.get_node_or_null("LM_msrit")
		if n != null:
			lm = n
	ok(lm != null, "MSRIT campus built in the streamed city")
	for b in ["aerial", "walk_in", "reel_news", "inform_sir", "rajini_ots", "ad_away", "raja_crowd", "shove", "raja_falls", "raja_rises", "play", "lips", "back", "feet", "approach", "split", "punch", "high_angle", "chaos1", "siren_heard", "jeep_in", "raja_looks_back", "lal_looks_back", "auto_inside", "lal_walk", "black", "whistle", "title", "done"]:
		ok(_beats.has(b), "shot reached: " + b)
	ok(Game.flag("opening_done"), "opening marked complete in the save")
	ok(_raja_fell, "Raja is the one who is pushed and falls (fall animation played on the player's body)")
	ok(not _lal_seen_at_fall, "Lal is not present at Raja's fall")
	ok(op.whistle_frame == op.black_frame and op.black_frame > 0, "whistle starts on the blackout frame (black %d, whistle %d)" % [op.black_frame, op.whistle_frame])
	ok(op.rajini_front_frames == 0, "Rajinikanth never seen from the front (%d frames)" % op.rajini_front_frames)
	var meds := 0
	for c in op.crowd:
		if c.get("med", false): meds += 1
	ok(meds >= 10, "medical students present (%d)" % meds)
	print("beats: ", _beats)

func _beat_shot(b: String) -> void:
	await wait(0.05)
	await shot("op_%02d_%s" % [_beats.size(), b])
	if b in ["aerial", "walk_in", "rajini_approach", "rajini_ots", "raja_crowd", "shove", "raja_falls", "raja_rises", "split", "high_angle", "chaos1", "title_start", "auto_inside"]:
		await wait(1.6)
		await shot("op_%02d_%s_b" % [_beats.size(), b])

func s_dbg() -> void:
	var w = world()
	while w.story.opening == null:
		await wait(0.1)
	var op = w.story.opening
	while op.phase != "lips":
		await wait(0.01)
	for k in 6:
		await shot("dbg_lips_%d" % k)
		await wait(0.12)

func s_title() -> void:
	var w = world()
	while w.story.opening == null:
		await wait(0.1)
	var op = w.story.opening
	op._skip = true
	while op.phase != "done":
		await wait(0.1)
	await wait(0.3)
	await shot("title_only")

func s_intro() -> void:
	for t in [[5.0, "intro_logo"], [10.0, "intro_star"], [12.0, "intro_title"], [4.0, "intro_title_full"], [6.5, "menu"]]:
		await wait(t[0])
		await shot(t[1])
	ok(Sfx._intro.playing and Sfx._menu_loop, "the Hanvi's Original intro music plays on under the main menu, set to loop")
	ok(not Sfx._theme.playing, "the whistle track is not playing on the menu")
	Sfx._intro.seek(Sfx._intro.stream.get_length() - 0.5)
	await wait(1.5)
	ok(Sfx._intro.playing and Sfx._intro.get_playback_position() < 2.0, "menu music starts again after it ends (loop)")

## Evidence stills: the scattered notes and the medical students, from close.
func s_props() -> void:
	var w = world()
	while w.story.opening == null:
		await wait(0.1)
	var op = w.story.opening
	while op.phase != "reel_news":
		await wait(0.1)
	op._cam_fn = Callable()
	op.slow(0.0001)
	var B: Basis = Campus.frame().basis
	op.aim(Opening.L(-6.0, 1.2, 56.5), Opening.L(-3.0, 0.0, 61.0), 45.0)
	await wait(0.6)
	await shot("ev_notes_set")
	op.aim(Opening.L(-17.0, 1.25, 54.6), Opening.L(-18.0, 0.78, 56.0), 40.0)
	await wait(0.6)
	await shot("ev_notes_bundles")
	op.aim(Opening.L(15.5, 1.6, 31.0), Opening.L(19.0, 1.3, 35.2), 50.0)
	await wait(0.6)
	await shot("ev_medical_students")
	op.aim(Opening.L(1.0, 1.7, 80.5), Opening.L(1.0, 1.3, 85.0), 50.0)
	await wait(0.6)
	await shot("ev_medical_students_porch")

# ------------------------------------------------------------------ Milestone 2: gait test
var _cam_t: Camera3D

func _tcam(pos: Vector3, look: Vector3, fov := 40.0) -> void:
	if _cam_t == null:
		_cam_t = Camera3D.new()
		world().add_child(_cam_t)
	_cam_t.make_current()
	_cam_t.fov = fov
	_cam_t.global_position = pos
	_cam_t.look_at(look, Vector3.UP)

func _raja_proto():
	while world() == null or world().player == null:
		await get_tree().process_frame
	var w = world()
	var pl = w.player
	pl.human.set_look({"model": "raja", "acc": 0, "top": 0})
	pl.human.enable_gait()
	pl.human.gait_measure = true
	return pl

var _driving := false

func _drive_to(target: Vector3, sprint := false, timeout := 20.0) -> void:
	_driving = true
	var pl = world().player
	if sprint: Input.action_press("sprint")
	var t := 0.0
	while t < timeout:
		var d: Vector3 = target - pl.global_position
		d.y = 0
		if d.length() < 0.35: break
		pl.yaw = atan2(-d.x, -d.z)
		Input.action_press("mv_u")
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("mv_u")
	Input.action_release("sprint")
	_driving = false

func s_gait() -> void:
	var w = world()
	var pl = await _raja_proto()
	await tp(Campus.world(Vector3(-25, 0, 50)), 0.0)
	pl.cam_override = true
	w.busy = true
	var start: Vector3 = pl.global_position
	var fwd := Campus.frame().basis * Vector3(0, 0, 1)
	var side := Campus.frame().basis * Vector3(1, 0, 0)
	await wait(1.0)
	# walk, filmed side-on at foot level
	var goal := start + fwd * 9.0
	_drive_to(goal)
	for i in 24:
		var p: Vector3 = pl.global_position
		_tcam(p + side * 2.6 + Vector3(0, 0.55, 0), p + Vector3(0, 0.45, 0), 42.0)
		await wait(0.12)
		await shot("g_walk_%02d" % i)
	while _driving: await get_tree().process_frame
	await wait(1.2)
	await shot("g_stop")
	print("walk: ", pl.human.gait.stats)
	pl.human.gait.stats = {"slide_max": 0.0, "ground_err_max": 0.0, "samples": 0, "steps": 0, "reach_fail": 0}
	# run
	_drive_to(pl.global_position + fwd * 14.0, true)
	for i in 16:
		var p: Vector3 = pl.global_position
		_tcam(p + side * 3.2 + Vector3(0, 0.7, 0), p + Vector3(0, 0.7, 0), 45.0)
		await wait(0.08)
		await shot("g_run_%02d" % i)
	while _driving: await get_tree().process_frame
	await wait(1.2)
	print("run: ", pl.human.gait.stats)
	# turn on the spot
	var y0: float = pl.human.rotation.y
	for i in 20:
		pl.human.rotation.y = y0 + PI * (i + 1) / 20.0
		var p: Vector3 = pl.global_position
		_tcam(p + Vector3(0, 1.6, 0) + side * 1.2 + fwd * 1.2, p + Vector3(0, 0.1, 0), 50.0)
		await wait(0.08)
		if i % 4 == 0: await shot("g_turn_%02d" % i)
	await wait(1.5)
	await shot("g_turn_end")
	print("turn: ", pl.human.gait.stats)

func s_gaitdbg() -> void:
	var w = world()
	var pl = await _raja_proto()
	await tp(Campus.world(Vector3(-25, 0, 50)), 0.0)
	w.busy = true
	await wait(1.0)
	var g = pl.human.gait
	var fwd := Campus.frame().basis * Vector3(0, 0, 1)
	_drive_to(pl.global_position + fwd * 6.0)
	for i in 40:
		await get_tree().process_frame
		var p: Vector3 = pl.global_position
		print("%02d dt %.3f pos %s vel %.2f swing '%s' L %s t%.2f  R %s t%.2f  poff %s state %s gy %.3f" % [i, get_process_delta_time(), str(p), g.vel.length(), g._swing_side, str(g.feet.l.lock - p) if g.feet.l.planted else "air", g.feet.l.t, str(g.feet.r.lock - p) if g.feet.r.planted else "air", g.feet.r.t, str(g.pelvis_off), pl.human.state, pl.human._gy])

func s_armdbg() -> void:
	var w = world()
	var pl = await _raja_proto()
	await tp(Campus.world(Vector3(-25, 0, 50)), 0.0)
	w.busy = true
	await wait(1.0)
	var raja: Human = pl.human
	var fwd: Vector3 = -raja.global_transform.basis.z
	var right: Vector3 = raja.global_transform.basis.x
	var tg: Vector3 = raja.global_position + fwd * 0.42 + right * 0.22 + Vector3(0, 1.2, 0)
	raja.reach_to("r", tg)
	for i in 30:
		await get_tree().process_frame
		var sk := raja.skel
		var hp: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hand_r")).origin
		var ep: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("lowerarm_r")).origin
		var sp: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("upperarm_r")).origin
		var d: Dictionary = raja.gait.arm_dbg.get("r", {})
		if d.is_empty(): continue
		print("%02d w %.2f | S %s vs %s | E %s vs %s | W %s vs %s | hand-target %.3f scale %s" % [i, float(raja.reach.r.w), str(sp), str(d.S), str(ep), str(d.elbow), str(hp), str(d.wrist), hp.distance_to(tg), str(sk.global_transform.basis.get_scale())])

# ------------------------------------------------------------------ Milestone 2-A: the prototype course
var _stage: Node3D
var _cam_fn2 := Callable()
var _metrics := {}
var _rail_err_max := 0.0

func _L(x: float, y: float, z: float) -> Vector3:
	return Campus.world(Vector3(x, y, z))

func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _sbox(centre_local: Vector3, size: Vector3, c: Color, walk := false, tilt := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	_stage.add_child(mi)
	mi.global_transform = Transform3D(Campus.frame().basis * Basis(Vector3(1, 0, 0), tilt), _L(centre_local.x, centre_local.y, centre_local.z))
	if walk:
		var b := Ground.new_body()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		b.add_child(cs)
		_stage.add_child(b)
		b.global_transform = mi.global_transform
	return mi

func _build_course() -> Dictionary:
	_stage = Node3D.new()
	world().add_child(_stage)
	var g := 0.055                                   # the paving
	var conc := Color(0.6, 0.58, 0.54)
	# 1. a footpath block with a 16 cm kerb, crossed
	_sbox(Vector3(-25, g + 0.08, 51.25), Vector3(4.0, 0.16, 2.5), conc.darkened(0.05), true)
	_sbox(Vector3(-25, g + 0.08, 50.0), Vector3(4.0, 0.16, 0.12), Color(0.75, 0.74, 0.7))
	# 2. a ramp up to a platform, and four stairs down the far side
	var rise := 0.36
	var rl := 3.2
	var ang := atan2(rise, rl)
	_sbox(Vector3(-25, g + rise * 0.5 - 0.06, 56.0 + rl * 0.5), Vector3(2.0, 0.12, sqrt(rl * rl + rise * rise)), conc, true, -ang)
	_sbox(Vector3(-25, g + rise * 0.5, 60.1), Vector3(2.0, rise, 1.8), conc.darkened(0.08), true)
	for k in 4:
		var top := rise - (k + 1) * 0.09
		_sbox(Vector3(-25, g + top * 0.5, 61.15 + k * 0.3), Vector3(2.0, maxf(top, 0.01), 0.3), conc.lightened(0.03 * k), true)
	# 3. a chair (seat 0.45 m) and a table with a tea glass
	var seat := _L(-25.0, g + 0.45, 67.0)
	var seat_loc := Vector3(-25.0, 0, 67.0)
	_sbox(Vector3(-25.0, g + 0.43, 67.0), Vector3(0.44, 0.04, 0.42), Color(0.45, 0.3, 0.18))
	_sbox(Vector3(-25.0, g + 0.72, 67.2), Vector3(0.44, 0.55, 0.04), Color(0.45, 0.3, 0.18))
	for sx: float in [-0.19, 0.19]:
		for sz: float in [-0.18, 0.18]:
			_sbox(Vector3(-25.0 + sx, g + 0.21, 67.0 + sz), Vector3(0.035, 0.42, 0.035), Color(0.38, 0.25, 0.15))
	_sbox(Vector3(-24.45, g + 0.7, 66.85), Vector3(0.6, 0.04, 0.5), Color(0.5, 0.36, 0.22))
	for sx: float in [-0.26, 0.26]:
		for sz: float in [-0.21, 0.21]:
			_sbox(Vector3(-24.45 + sx, g + 0.34, 66.85 + sz), Vector3(0.035, 0.68, 0.035), Color(0.42, 0.3, 0.18))
	var glass := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.032
	cm.bottom_radius = 0.026
	cm.height = 0.09
	glass.mesh = cm
	var gm := _mat(Color(0.62, 0.42, 0.26, 0.9), 0.12)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override = gm
	_stage.add_child(glass)
	glass.global_position = _L(-24.5, g + 0.72 + 0.045, 66.72)
	# 4. a railing along the path
	for k in 5:
		_sbox(Vector3(-26.4, g + 0.5, 70.0 + k * 1.5), Vector3(0.05, 1.0, 0.05), Color(0.3, 0.32, 0.35))
	_sbox(Vector3(-26.4, g + 1.0, 73.0), Vector3(0.06, 0.06, 6.2), Color(0.35, 0.37, 0.4))
	# 5. somebody to push
	var other := Human.make({"model": "m_avg", "top": 4, "top_col": 8, "bottom": 0, "bot_col": 8, "acc": 0, "build": 0.6, "age": 0.35}, 1)
	_stage.add_child(other)
	other.global_position = _L(-25.0, 0, 80.0)
	other.rotation.y = Campus.yaw_world(0.0)      # faces back down the course (local -Z)
	other.enable_gait()
	return {"seat": seat, "seat_loc": seat_loc, "glass": glass, "other": other, "rail_x": -26.4, "g": g}

func _watch(fn: Callable) -> void:
	_cam_fn2 = fn

func _process(_d: float) -> void:
	if _cam_fn2.is_valid():
		_cam_fn2.call()

func _yaw_local(lx: float, lz: float) -> float:
	var d := Campus.frame().basis * Vector3(lx, 0, lz)
	return atan2(-d.x, -d.z)

func s_proto() -> void:
	var w = world()
	var pl = await _raja_proto()
	await tp(_L(-25, 0, 46.5), 0.0)
	w.busy = true
	pl.cam_override = true
	Game.s.time = 9.5
	var C := _build_course()
	var raja: Human = pl.human
	var B := Campus.frame().basis
	var side := B * Vector3(1, 0, 0)
	var fwd := B * Vector3(0, 0, 1)
	raja.rotation.y = _yaw_local(0, 1)
	await wait(1.5)
	var gs = raja.gait
	# --- A. idle: breathing, weight shifting, glances, blinking; then a run of postures
	_watch(func():
		var p: Vector3 = pl.global_position
		_tcam(p + fwd * 2.2 + side * 0.6 + Vector3(0, 1.45, 0), p + Vector3(0, 1.2, 0), 38.0))
	await wait(3.0)
	await shot("p01_idle")
	for pst in ["confident", "nervous", "defensive", "frustrated", "curious", "tired", "relaxed"]:
		raja.posture = pst
		await wait(1.6)
		await shot("p02_posture_" + pst)
	raja.posture = ""
	_watch(func():
		var hp: Vector3 = raja.head.global_position
		_tcam(hp + fwd * 0.75 + side * 0.25 + Vector3(0, 0.05, 0), hp + Vector3(0, 0.02, 0), 30.0))
	await wait(1.2)
	await shot("p03_face")
	raja.look_target = raja.head.global_position + side * 2.0 + fwd * 1.0
	await wait(0.9)
	await shot("p03_face_turn")
	raja.look_target = null
	gs.stats = {"slide_max": 0.0, "ground_err_max": 0.0, "samples": 0, "steps": 0, "reach_fail": 0}
	# --- B. walk: over the kerb, up the ramp, down the stairs (feet filmed side-on)
	_watch(func():
		var p: Vector3 = pl.global_position
		_tcam(p + side * 2.4 + Vector3(0, 0.75, 0) - fwd * 0.4, p + Vector3(0, 0.5, 0) + fwd * 0.3, 44.0))
	_drive_to(_L(-25, 0, 64.0))
	var k := 0
	while _driving:
		await wait(0.35)
		await shot("p04_walk_%02d" % k)
		k += 1
	_metrics["walk_kerb_ramp_stairs"] = gs.stats.duplicate()
	if gs.stats.has("worst"):
		_metrics["walk_worst_local"] = str(Campus.frame().affine_inverse() * (gs.stats.worst.pos as Vector3))
	# --- C. stop at the chair, turn round, sit down, reach the glass, drink, put it back, stand up
	_drive_to(_L(-25, 0, 66.55))
	while _driving: await get_tree().process_frame
	_watch(func():
		var p: Vector3 = pl.global_position
		_tcam(p + side * 2.3 - fwd * 1.1 + Vector3(0, 1.1, 0), p + Vector3(0, 0.75, 0), 42.0))
	var yaw_sit := _yaw_local(0, -1)
	var y0: float = raja.rotation.y
	for i in 24:
		raja.rotation.y = lerp_angle(y0, yaw_sit, (i + 1) / 24.0)
		await wait(0.05)
	await wait(0.8)
	await shot("p05_turned")
	raja.sit_on(C.seat, yaw_sit)
	await wait(0.6)
	await shot("p06_sitting_down")
	await wait(1.2)
	await shot("p07_seated")
	_metrics["seat_contact_err_m"] = gs.seat_error()
	var glass: MeshInstance3D = C.glass
	_watch(func():
		var p: Vector3 = pl.global_position
		_tcam(p + side * 1.4 - fwd * 0.4 + Vector3(0, 1.0, 0), glass.global_position.lerp(raja.head.global_position, 0.4), 40.0))
	# grip the side of the glass nearest the shoulder: palm centre one radius + palm thickness from its axis
	var gp: Vector3 = glass.global_position
	var shp: Vector3 = raja.skel.global_transform * raja.skel.get_bone_global_pose(raja.skel.find_bone("upperarm_r")).origin
	var tw := Vector3(shp.x - gp.x, 0, shp.z - gp.z).normalized()
	raja.reach_to("r", gp + tw * 0.05)
	await wait(0.7)
	await shot("p08_reach")
	var pr: Vector3 = raja.gait.palm("r")
	_metrics["glass_grip_palm_err_m"] = pr.distance_to(gp + tw * 0.05)
	_metrics["glass_palm_axis_gap_m"] = Vector2(pr.x - gp.x, pr.z - gp.z).length() - 0.032
	_metrics["glass_reach_short_m"] = raja.reach_err.get("r", -1.0)
	# grip: the glass now travels in the hand
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	raja.skel.add_child(att)
	await get_tree().process_frame       # let the attachment take up the hand's pose first
	await get_tree().process_frame
	var gx := glass.global_transform
	glass.reparent(att)
	glass.global_transform = gx
	raja.activity = "tea"
	raja.reach_release("r")
	await wait(1.6)
	await shot("p09_drink")
	raja.activity = ""
	var _table_spot: Vector3 = (C.glass as Node3D).global_position
	raja.reach_to("r", _L(-24.48, C.g + 0.72 + 0.045, 66.7))
	await wait(0.7)
	var gx2 := glass.global_transform
	glass.reparent(_stage)
	glass.global_transform = gx2
	glass.global_position = _L(-24.5, C.g + 0.72 + 0.045, 66.72)
	raja.reach_release("r")
	await wait(0.5)
	raja.stand_up()
	await wait(0.7)
	await shot("p10_standing_up")
	await wait(1.0)
	# --- D. along the railing, a hand on it
	raja.rotation.y = _yaw_local(0, 1)
	_watch(func():
		var p: Vector3 = pl.global_position
		var rp := _L(C.rail_x, C.g + 1.03, 0)
		var lp: Vector3 = Campus.frame().affine_inverse() * p
		var rt := _L(C.rail_x + 0.01, C.g + 1.03 + 0.04, lp.z + 0.12)
		raja.reach_to("r", rt)
		if raja.reach.has("r") and float(raja.reach.r.w) >= 0.999:
			_rail_err_max = maxf(_rail_err_max, raja.gait.palm("r").distance_to(rt))
			if false:
				var sh: Vector3 = raja.skel.global_transform * raja.skel.get_bone_global_pose(raja.skel.find_bone("upperarm_r")).origin
				print("[rail] err %.3f short %.3f shoulder_to_target %.3f palm %s target %s" % [raja.gait.palm("r").distance_to(rt), float(raja.reach_err.get("r", -1.0)), sh.distance_to(rt), str(Campus.frame().affine_inverse() * raja.gait.palm("r")), str(Campus.frame().affine_inverse() * rt)])
		_tcam(p - side * 1.9 + fwd * 1.6 + Vector3(0, 1.5, 0), p + Vector3(0, 0.95, 0), 44.0))
	_drive_to(_L(-25.95, 0, 70.2))
	while _driving: await get_tree().process_frame
	_drive_to(_L(-25.95, 0, 75.5))
	k = 0
	while _driving:
		await wait(0.45)
		if k < 6: await shot("p11_rail_%02d" % k)
		k += 1
	_watch(Callable())
	_metrics["palm_to_rail_target_m_max_while_walking"] = _rail_err_max
	raja.reach_release("r")
	# --- E. the push: both hands to his chest, he takes catch-steps back
	var other: Human = C.other
	_drive_to(_L(-25.0, 0, 79.4))
	while _driving: await get_tree().process_frame
	raja.rotation.y = _yaw_local(0, 1)
	# he steps up to arm's length (the other man takes the step)
	other.global_position = pl.global_position + fwd * 0.68
	await wait(0.8)
	var chest := func(dx: float) -> Vector3:
		var sp: Vector3 = other.skel.global_transform * other.skel.get_bone_global_pose(other.skel.find_bone("spine_03")).origin
		var to: Vector3 = (pl.global_position - other.global_position)
		to.y = 0
		to = to.normalized()
		return sp + to * 0.13 + to.cross(Vector3.UP) * dx - Vector3(0, 0.05, 0)
	var pushing := [true]
	_watch(func():
		if pushing[0]:
			raja.reach_to("l", chest.call(0.11))
			raja.reach_to("r", chest.call(-0.11))
		var mid: Vector3 = (pl.global_position + other.global_position) * 0.5
		_tcam(mid + side * 2.6 + Vector3(0, 1.3, 0), mid + Vector3(0, 1.05, 0), 42.0))
	await wait(0.55)
	await shot("p12_hands_on")
	_metrics["push_palms_to_chest_m"] = [raja.gait.palm("l").distance_to(chest.call(0.11)), raja.gait.palm("r").distance_to(chest.call(-0.11))]
	# shove: he goes back, his feet catching him; Raja follows through a step
	other.mood = "surprise"
	var t := 0.0
	var o0 := other.global_position
	var r0: Vector3 = pl.global_position
	while t < 0.9:
		var dt := get_process_delta_time()
		t += dt
		var e := 1.0 - pow(1.0 - minf(t / 0.9, 1.0), 2.5)
		other.global_position = o0 + fwd * 0.95 * e
		pl.global_position = r0 + fwd * 0.3 * minf(t / 0.5, 1.0)
		if t > 0.25:
			pushing[0] = false
			raja.reach_release("l"); raja.reach_release("r")
		await get_tree().process_frame
	await shot("p13_pushed")
	await wait(1.2)
	await shot("p14_recovered")
	other.mood = "angry"
	# --- F. run, and stop
	gs.stats = {"slide_max": 0.0, "ground_err_max": 0.0, "samples": 0, "steps": 0, "reach_fail": 0}
	raja.rotation.y = _yaw_local(-1, 0)
	_watch(func():
		var p: Vector3 = pl.global_position
		_tcam(p - side * 0.0 + fwd * 3.6 + Vector3(0, 1.0, 0), p + Vector3(0, 0.9, 0), 46.0))
	_drive_to(_L(-39.0, 0, 79.0), true)
	k = 0
	while _driving:
		await wait(0.3)
		if k < 8: await shot("p15_run_%02d" % k)
		k += 1
	await wait(1.4)
	await shot("p16_stopped")
	_metrics["run"] = gs.stats.duplicate()
	# --- G. turn round on the spot
	var yt: float = raja.rotation.y
	_watch(func():
		var p: Vector3 = pl.global_position
		_tcam(p + Vector3(0, 1.5, 0) + fwd * 2.6 + side * 2.0, p + Vector3(0, 0.85, 0), 46.0))
	for i in 30:
		raja.rotation.y = yt + PI * (i + 1) / 30.0
		await wait(0.05)
	await wait(1.4)
	await shot("p17_turned_round")
	print("[metrics] ", JSON.stringify(_metrics))

# ------------------------------------------------------------------ controls overhaul: injected-touch tests
func _tch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)

func _drg(i: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	e.relative = rel
	Input.parse_input_event(e)

## Slide a touch from a to b over t seconds (several drag events per frame step).
func _slide(i: int, a: Vector2, b: Vector2, t: float) -> void:
	var n := maxi(2, int(t * 30.0))
	var prev := a
	for k in n:
		var p := a.lerp(b, float(k + 1) / n)
		_drg(i, p, p - prev)
		prev = p
		await get_tree().process_frame

func _hold(t: float) -> void:
	var e := 0.0
	while e < t:
		await get_tree().process_frame
		e += get_process_delta_time()

## Face the player down the longest clear line (so a run test does not start against a wall).
func _face_open(pl) -> void:
	var space: PhysicsDirectSpaceState3D = pl.get_world_3d().direct_space_state
	var best := 0.0
	var best_yaw := 0.0
	for k in 24:
		var a := TAU * k / 24.0
		var d := Vector3(-sin(a), 0, -cos(a))
		var from: Vector3 = pl.global_position + Vector3(0, 1.0, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 40.0, 1 | 2)
		var hit := space.intersect_ray(q)
		var dist := 40.0 if hit.is_empty() else from.distance_to(hit.position)
		if dist > best:
			best = dist
			best_yaw = a
	pl.yaw = best_yaw
	pl.human.rotation.y = best_yaw
	await _hold(0.3)

func s_controls() -> void:
	var w = world()
	await wait(2.0)
	var pad: TouchPad = w.hud.pad
	var pl = w.player
	Game.settings.touch_trace = true
	var R := pad.stick_radius()
	var o := Vector2(pad.size.x * 0.16, pad.size.y * 0.72)
	await shot("c01_hud_idle")
	# 1. half push: walking, not running
	_tch(0, o, true)
	await _slide(0, o, o + Vector2(0, -R * 0.5), 0.2)
	await _hold(1.2)
	ok(not pad.running() and pl._hv.length() > 0.4 and pl._hv.length() < Player.WALK + 0.05, "half push walks (speed %.2f)" % pl._hv.length())
	await shot("c02_walk")
	# 2. full push: running; a short flick never offers the lock
	await _slide(0, o + Vector2(0, -R * 0.5), o + Vector2(0, -R * 1.0), 0.1)
	await _hold(0.3)
	ok(pad.running(), "full push runs")
	ok(pad.lock_state != TouchPad.Lock.OFFERED and pad.lock_state != TouchPad.Lock.LOCKED, "0.3 s at full push does not offer RUN LOCK")
	await _slide(0, o + Vector2(0, -R), o, 0.05)
	_tch(0, o, false)
	var offered_by_flicks := false
	for k in 8:
		_tch(0, o, true)
		await _slide(0, o, o + Vector2(0, -R), 0.08)
		await _hold(0.25)
		offered_by_flicks = offered_by_flicks or pad.lock_state in [TouchPad.Lock.OFFERED, TouchPad.Lock.LOCKED]
		_tch(0, o + Vector2(0, -R), false)
		await _hold(0.15)
	ok(not offered_by_flicks, "8 quick upward flicks never offer RUN LOCK")
	await _hold(0.8)
	# 3. hold full forward: the chip appears; a sideways full push does not count
	await _face_open(pl)
	_tch(0, o, true)
	await _slide(0, o, o + Vector2(R, 0), 0.1)
	await _hold(1.0)
	ok(pad.lock_state == TouchPad.Lock.NONE, "full push sideways does not offer RUN LOCK")
	await _slide(0, o + Vector2(R, 0), o + Vector2(0, -R), 0.1)
	await _hold(0.35)
	await shot("c03_lock_arming")
	await _hold(0.45)
	ok(pad.lock_state == TouchPad.Lock.OFFERED, "holding forward 0.8 s offers RUN LOCK")
	await shot("c04_lock_offered")
	# 4. slide onto the chip and let go: locked, and he keeps running with the thumb lifted
	await _slide(0, o + Vector2(0, -R), pad.chip_pos(), 0.2)
	ok(pad._chip_hover, "thumb over the chip")
	_tch(0, pad.chip_pos(), false)
	await _hold(0.1)
	ok(pad.run_locked(), "slide-and-release on the chip engages RUN LOCK")
	await _hold(1.5)
	ok(pl._hv.length() > Player.RUN * 0.85, "keeps running with no thumb on the stick (speed %.2f)" % pl._hv.length())
	await shot("c05_lock_active")
	# 5. steer while locked
	var y0: float = pl.human.rotation.y
	_tch(0, o, true)
	await _slide(0, o, o + Vector2(R * 0.9, -R * 0.3), 0.15)
	await _hold(1.0)
	ok(pad.run_locked() and absf(wrapf(pl.human.rotation.y - y0, -PI, PI)) > 0.6, "steering right keeps the lock and turns him (%.2f rad)" % wrapf(pl.human.rotation.y - y0, -PI, PI))
	await shot("c06_lock_steer")
	# 6. pull back: cancelled
	await _slide(0, o + Vector2(R * 0.9, -R * 0.3), o + Vector2(0, R * 0.9), 0.15)
	await _hold(0.2)
	ok(not pad.run_locked() and pad.last_cancel == "pulled back", "pulling the stick back cancels (%s)" % pad.last_cancel)
	_tch(0, o + Vector2(0, R * 0.9), false)
	await _hold(1.2)
	await shot("c07_cancelled_stopped")
	ok(pl._hv.length() < 0.3, "after cancelling and letting go he stops (speed %.2f)" % pl._hv.length())
	await _face_open(pl)
	# 7. engage by tapping the chip (after letting go, within 2 s), cancel by tapping it again
	_tch(0, o, true)
	await _slide(0, o, o + Vector2(0, -R), 0.1)
	await _hold(0.8)
	_tch(0, o + Vector2(0, -R), false)
	await _hold(0.5)
	ok(pad.lock_state == TouchPad.Lock.OFFERED, "chip stays offered briefly after letting go")
	_tch(1, pad.chip_pos(), true)
	_tch(1, pad.chip_pos(), false)
	await _hold(0.3)
	ok(pad.run_locked(), "tapping the offered chip engages RUN LOCK")
	_tch(1, pad.chip_pos(), true)
	_tch(1, pad.chip_pos(), false)
	await _hold(0.2)
	ok(not pad.run_locked() and pad.last_cancel == "chip", "tapping the chip again cancels (%s)" % pad.last_cancel)
	await _hold(1.0)
	# 8. context: dialogue/cutscene lock ends it
	await _face_open(pl)
	_tch(0, o, true)
	await _slide(0, o, o + Vector2(0, -R), 0.1)
	await _hold(0.8)
	await _slide(0, o + Vector2(0, -R), pad.chip_pos(), 0.2)
	_tch(0, pad.chip_pos(), false)
	await _hold(0.3)
	pl.locked = true
	await _hold(0.2)
	ok(not pad.run_locked() and pad.last_cancel == "context", "a dialogue lock ends RUN LOCK (%s)" % pad.last_cancel)
	pl.locked = false
	await _hold(1.0)
	# 9. a wall: running into it ends the lock
	var fwd := Vector3(-sin(pl.yaw), 0, -cos(pl.yaw))
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(8, 3, 0.4)
	cs.shape = bx
	wall.add_child(cs)
	var wm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bx.size
	wm.mesh = bm
	wall.add_child(wm)
	w.add_child(wall)
	wall.global_position = pl.global_position + fwd * 4.0 + Vector3(0, 1.5, 0)
	wall.look_at(pl.global_position + Vector3(0, 1.5, 0), Vector3.UP)
	_tch(0, o, true)
	await _slide(0, o, o + Vector2(0, -R), 0.1)
	await _hold(0.8)
	await _slide(0, o + Vector2(0, -R), pad.chip_pos(), 0.2)
	_tch(0, pad.chip_pos(), false)
	await _hold(2.5)
	ok(not pad.run_locked() and pad.last_cancel == "blocked", "running into a wall ends RUN LOCK (%s)" % pad.last_cancel)
	await shot("c08_wall_stop")
	wall.queue_free()
	# 10. camera drag: smooth and proportional
	var yaw0: float = pl.yaw
	var c := Vector2(pad.size.x * 0.7, pad.size.y * 0.45)
	_tch(2, c, true)
	await _slide(2, c, c + Vector2(240, 0), 0.4)
	_tch(2, c + Vector2(240, 0), false)
	await _hold(0.4)
	var dy: float = wrapf(pl.yaw - yaw0, -PI, PI)
	ok(absf(dy) > 0.4 and absf(dy) < 2.5, "a 240 px camera drag turns the camera %.2f rad" % dy)
	print("[controls] done")

# ------------------------------------------------------------------ driving overhaul: handling tests per vehicle class
func _road_start() -> Dictionary:
	var best := {}
	var bl := 0.0
	for e in City.edges:
		if float(e.len) > bl and float(e.w) >= 14.0:
			bl = float(e.len)
			best = e
	var d: Vector2 = best.dir
	var p: Vector2 = (best.pa as Vector2) + d * 60.0
	return {"pos": Vector3(p.x, 0, p.y), "dir": Vector3(d.x, 0, d.y), "yaw": atan2(-d.x, -d.y), "name": best.name}

func _speed_bump(at: Vector3, dir: Vector3, width: float) -> Node3D:
	var b := Ground.new_body()
	var yaw := atan2(-dir.x, -dir.z)
	Ground.box_shape(b, Vector3.ZERO, Vector3(width, 0.16, 0.55), 0.0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.16, 0.55)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.75, 0.2)
	mi.material_override = m
	b.add_child(mi)
	world().add_child(b)
	b.global_position = at + Vector3(0, 0.09, 0)
	b.rotation.y = yaw
	return b

## Put a test vehicle back at the start of the test road, stopped, pointing along it.
func _place(veh, rs: Dictionary) -> void:
	veh.global_position = rs.pos
	veh.rotation.y = rs.yaw
	veh.hvel = Vector3.ZERO
	veh.v = 0.0
	veh.steer = 0.0
	veh.reverse = false
	world().player.global_position = rs.pos
	await _hold(0.4)

func s_driving() -> void:
	var w = world()
	await wait(2.0)
	var pl = w.player
	var pad: TouchPad = w.hud.pad
	var rs := _road_start()
	print("[drive] test road: ", rs.name)
	var results := {}
	var types := ["car", "hatch", "auto", "bike", "scooter", "bus", "truck"]
	for ti in types.size():
		var t: String = types[ti]
		if pl.vehicle != null:
			pl.exit_vehicle()
			await _hold(0.3)
		for old in veh_cleanup:
			if is_instance_valid(old):
				old.queue_free()
		veh_cleanup.clear()
		var start: Vector3 = rs.pos + rs.dir * (ti * 0.0)
		await tp(start + Vector3(0, 0, 0), rs.yaw)
		var veh := Vehicle.create(t, 2)
		w.add_child(veh)
		veh.global_position = start
		veh.rotation.y = rs.yaw
		await _hold(0.2)
		pl.enter_vehicle(veh)
		await _hold(0.5)
		var r := {}
		# 1. full throttle from rest (the car is driven through real touches on the pedal)
		if t == "car":
			var g := pad.gas_rect()
			_tch(5, Vector2(g.get_center().x, g.position.y + 12), true)
		else:
			pad.throttle_value = 1.0
		var tt := 0.0
		var t40 := -1.0
		while tt < 8.0:
			await get_tree().process_frame
			tt += get_process_delta_time()
			if t40 < 0.0 and veh.v >= 40.0 / 3.6:
				t40 = tt
			if tt > 1.2 and tt < 1.25 and t in ["car", "bike", "bus"]:
				await shot("d_%s_accel" % t)
		r.t_0_40kmh = t40
		r.speed_8s_kmh = veh.v * 3.6
		ok(veh.v > 0.5, "%s: accelerates (%.0f km/h after 8 s, 0-40 in %.1f s)" % [t, veh.v * 3.6, t40])
		await _place(veh, rs)
		pad.throttle_value = 1.0
		while veh.v < 26.0 / 3.6:
			await get_tree().process_frame
		# 2. ease to 25 km/h, then full right lock: measure the turning circle at that speed
		if t == "car":
			_tch(5, pad.gas_rect().get_center(), false)
		pad.throttle_value = 0.0
		pad.brake_value = 0.6
		while veh.v > 25.0 / 3.6:
			await get_tree().process_frame
		pad.brake_value = 0.0
		var hold_v := 25.0 / 3.6
		var sr := pad.steer_rect()
		var sx0 := sr.get_center().x
		if t == "car":
			_tch(6, Vector2(sx0, sr.get_center().y), true)
			await _slide(6, Vector2(sx0, sr.get_center().y), Vector2(sx0 + sr.size.x * 0.4, sr.get_center().y), 0.2)
		else:
			pad._steer_raw = 1.0
		var y0: float = veh.rotation.y
		tt = 0.0
		var yaw_acc := 0.0
		var prev: float = veh.rotation.y
		var vs := 0.0
		while tt < 2.5:
			pad.throttle_value = clampf((hold_v - veh.v) * 0.8, 0.0, 1.0)
			await get_tree().process_frame
			var dt := get_process_delta_time()
			tt += dt
			if tt > 1.0:
				yaw_acc += absf(wrapf(veh.rotation.y - prev, -PI, PI))
				vs += absf(veh.v) * dt
			prev = veh.rotation.y
			if tt > 1.4 and tt < 1.45 and t in ["car", "bike", "auto", "bus"]:
				await shot("d_%s_turn" % t)
		var radius := vs / maxf(yaw_acc, 0.001)
		r.turn_radius_m_at_25kmh = radius
		r.body_roll_deg = rad_to_deg(veh.susp.z)
		ok(radius > 1.5 and radius < 40.0, "%s: turning radius at 25 km/h %.1f m, body %s %.1f deg" % [t, radius, "lean" if t in ["bike", "scooter"] else "roll", rad_to_deg(veh.susp.z)])
		if t == "car":
			_tch(6, Vector2(sx0 + sr.size.x * 0.4, sr.get_center().y), false)
		pad._steer_raw = 0.0
		pad.throttle_value = 0.0
		await _hold(1.0)
		await _place(veh, rs)
		# 3. straighten, get to 40 km/h (or top), full brake: stopping distance
		pad.throttle_value = 1.0
		tt = 0.0
		var vt: float = minf(40.0 / 3.6, float(veh.spec.max) * 0.9)
		while veh.v < vt and tt < 10.0:
			await get_tree().process_frame
			tt += get_process_delta_time()
		pad.throttle_value = 0.0
		var b0: Vector3 = veh.global_position
		var v0: float = veh.v
		if t == "car":
			var br := pad.brake_rect()
			_tch(7, Vector2(br.get_center().x, br.position.y + 10), true)
		else:
			pad.brake_value = 1.0
		while veh.v > 0.05:
			await get_tree().process_frame
		var sd: float = Vector2(veh.global_position.x - b0.x, veh.global_position.z - b0.z).length()
		r.brake_from_kmh = v0 * 3.6
		r.stopping_distance_m = sd
		ok(sd > 1.0 and sd < 40.0, "%s: stops from %.0f km/h in %.1f m" % [t, v0 * 3.6, sd])
		# 4. keep holding the brake at a standstill: reverse engages and backs the vehicle up
		await _hold(1.6)
		r.reverse_engaged = veh.reverse
		r.reverse_speed_kmh = veh.v * 3.6
		ok(veh.reverse and veh.v < -0.3, "%s: holding brake at rest engages reverse (%.1f km/h)" % [t, veh.v * 3.6])
		if t == "car":
			await shot("d_car_reverse")
			_tch(7, pad.brake_rect().get_center(), false)
		pad.brake_value = 0.0
		pad.throttle_value = 0.6
		await _hold(1.0)
		ok(not veh.reverse, "%s: the accelerator returns to drive" % t)
		pad.throttle_value = 0.0
		# 5. speed breaker at about 15 km/h: the body must rise over it and settle (wheels never sink)
		await _place(veh, rs)
		var fwd := -veh.global_transform.basis.z
		var bump := _speed_bump(veh.global_position + fwd * 14.0, fwd, 10.0)
		await _hold(0.2)
		var base_h: float = veh.susp.x
		var maxh := -1.0
		tt = 0.0
		while tt < 5.0:
			pad.throttle_value = clampf((15.0 / 3.6 - veh.v) * 0.8, 0.0, 1.0)
			await get_tree().process_frame
			tt += get_process_delta_time()
			maxh = maxf(maxh, veh.susp.x - base_h)
			if t == "car" and absf(veh.susp.x - base_h) > 0.06 and not results.has("shot_bump"):
				results["shot_bump"] = true
				await shot("d_car_speedbreaker")
		r.bump_rise_m = maxh
		ok(maxh > 0.03 and maxh < 0.3, "%s: rides up over a 16 cm speed breaker (body +%.2f m) and settles" % [t, maxh])
		bump.queue_free()
		pad.throttle_value = 0.0
		pad.brake_value = 1.0
		await _hold(1.0)
		pad.brake_value = 0.0
		results[t] = r
		veh_cleanup.append(veh)
	print("[drive] results ", JSON.stringify(results))
	if pl.vehicle != null:
		pl.exit_vehicle()

var veh_cleanup: Array = []

# ------------------------------------------------------------------ R1: movement test reel (fixed cameras, measured per segment)
var _cap: Label
var _r1 := {}

func _caption(t: String) -> void:
	if _cap == null:
		var cl := CanvasLayer.new()
		cl.layer = 100
		add_child(cl)
		_cap = Label.new()
		_cap.position = Vector2(30, 24)
		_cap.add_theme_font_size_override("font_size", 30)
		_cap.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		_cap.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_cap.add_theme_constant_override("outline_size", 6)
		cl.add_child(_cap)
	_cap.text = t
	print("[r1] segment: ", t, " at frame ", Engine.get_process_frames())

func _seg_begin(gs) -> void:
	gs.stats = {"slide_max": 0.0, "ground_err_max": 0.0, "samples": 0, "steps": 0, "reach_fail": 0, "pelvis_min": 0.0}
	gs.falls.clear()

func _seg_end(name: String, gs) -> void:
	var st: Dictionary = gs.stats.duplicate()
	st.erase("worst")
	var lens := []
	var widths := []
	var F: Array = gs.falls
	for i in range(1, F.size()):
		var a: Dictionary = F[i - 1]
		var b: Dictionary = F[i]
		if a.s == b.s:
			continue
		var d: Vector3 = (b.p as Vector3) - (a.p as Vector3)
		d.y = 0
		var mv: Vector3 = (b.body as Vector3) - (a.body as Vector3)
		mv.y = 0
		if mv.length() < 0.05:
			continue
		var fwd := mv.normalized()
		lens.append(absf(d.dot(fwd)))
		widths.append(absf(d.dot(Vector3(-fwd.z, 0, fwd.x))))
	var avg := func(arr: Array) -> float:
		var t := 0.0
		for x in arr: t += float(x)
		return t / maxf(1.0, float(arr.size()))
	st.step_len_avg = avg.call(lens)
	st.step_len_max = lens.max() if lens.size() > 0 else 0.0
	st.step_width_avg = avg.call(widths)
	st.steps_measured = lens.size()
	st.deep_pelvis_frac = float(st.get("deep", 0)) / maxf(1.0, float(st.get("frames", 1)))
	_r1[name] = st
	print("[r1] ", name, " ", JSON.stringify(st))

func _walk_seg(name: String, gs, to: Vector3, cam: Vector3, run := false) -> void:
	_caption(name)
	var pl = world().player
	_watch(func(): _tcam(cam, pl.global_position + Vector3(0, 0.95, 0), 38.0))
	_seg_begin(gs)
	_drive_to(to, run)
	while _driving: await get_tree().process_frame
	await wait(1.2)
	_seg_end(name, gs)

func s_r1() -> void:
	var w = world()
	var pl = await _raja_proto()
	var raja: Human = pl.human
	var gs = raja.gait
	var C := _build_course()
	w.busy = true
	Game.s.time = 9.5
	var F := Campus.frame()
	var fwd: Vector3 = F.basis * Vector3(0, 0, 1)
	var side: Vector3 = F.basis * Vector3(1, 0, 0)
	# open paving beside the course for straight-line tests
	await tp(_L(-19, 0, 44), _yaw_local(0, 1))
	await wait(1.5)
	_caption("1. standing idle")
	_watch(func(): _tcam(_L(-19, 1.35, 47.2), pl.global_position + Vector3(0, 1.1, 0), 34.0))
	_seg_begin(gs)
	await wait(4.0)
	_seg_end("idle", gs)
	await _walk_seg("2. walking towards the camera", gs, _L(-19, 0, 52), _L(-19, 1.3, 55.5))
	await _walk_seg("3. walking away", gs, _L(-19, 0, 44.5), _L(-19, 1.3, 55.5))
	await _walk_seg("4. side-view walking", gs, _L(-19, 0, 53), _L(-14.5, 1.0, 48.5))
	# turning while walking: a curve through four waypoints
	_caption("5. turning while walking")
	_watch(func(): _tcam(_L(-12.5, 3.2, 49), pl.global_position + Vector3(0, 0.9, 0), 42.0))
	_seg_begin(gs)
	for wp in [_L(-17, 0, 55), _L(-14, 0, 55.5), _L(-12, 0, 53), _L(-13, 0, 50)]:
		_drive_to(wp)
		while _driving: await get_tree().process_frame
	await wait(1.0)
	_seg_end("turning_walk", gs)
	# start and stop
	_caption("6. starting and stopping")
	_watch(func(): _tcam(_L(-9.5, 1.0, 47), pl.global_position + Vector3(0, 0.9, 0), 36.0))
	_seg_begin(gs)
	for wp in [_L(-13, 0, 47.5), _L(-13, 0, 45)]:
		_drive_to(wp)
		while _driving: await get_tree().process_frame
		await wait(1.6)
	_seg_end("start_stop", gs)
	# running
	await tp(_L(-19, 0, 40), _yaw_local(0, 1))
	await wait(1.0)
	await _walk_seg("7. running towards the camera", gs, _L(-19, 0, 53), _L(-19, 1.2, 58), true)
	await tp(_L(-12, 0, 40), _yaw_local(0, 1))
	await wait(1.0)
	await _walk_seg("8. side-view running (accelerate, run, decelerate)", gs, _L(-12, 0, 58), _L(-5.5, 1.0, 49), true)
	# kerb and stairs (the course)
	await tp(_L(-25, 0, 47.5), _yaw_local(0, 1))
	await wait(1.0)
	await _walk_seg("9. stepping onto and off a kerb", gs, _L(-25, 0, 54.5), _L(-22.2, 0.6, 51.2))
	await _walk_seg("10. ramp up, stairs down", gs, _L(-25, 0, 63.6), _L(-22.0, 0.9, 60.5))
	await _walk_seg("11. stairs up, ramp down", gs, _L(-25, 0, 54.5), _L(-22.0, 0.9, 60.5))
	# sit, stand, reach, drink
	await tp(_L(-25, 0, 65.4), _yaw_local(0, 1))
	await wait(0.8)
	_caption("12. sitting down")
	_watch(func(): _tcam(_L(-22.9, 1.2, 66.0), pl.global_position + Vector3(0, 0.8, 0), 40.0))
	_seg_begin(gs)
	_drive_to(_L(-25, 0, 66.55))
	while _driving: await get_tree().process_frame
	var yaw_sit := _yaw_local(0, -1)
	var y0: float = raja.rotation.y
	for i in 20:
		raja.rotation.y = lerp_angle(y0, yaw_sit, (i + 1) / 20.0)
		await wait(0.05)
	raja.sit_on(C.seat, yaw_sit)
	await wait(2.2)
	_caption("13. reaching for the glass, drinking")
	var glass: MeshInstance3D = C.glass
	var gp: Vector3 = glass.global_position
	var shp: Vector3 = raja.skel.global_transform * raja.skel.get_bone_global_pose(raja.skel.find_bone("upperarm_r")).origin
	var tw := Vector3(shp.x - gp.x, 0, shp.z - gp.z).normalized()
	raja.reach_to("r", gp + tw * 0.05, "cylinder")
	await wait(0.9)
	_r1["glass_palm_err_m"] = raja.gait.palm("r").distance_to(gp + tw * 0.05)
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	raja.skel.add_child(att)
	await get_tree().process_frame
	await get_tree().process_frame
	var gx := glass.global_transform
	glass.reparent(att)
	glass.global_transform = gx
	raja.activity = "tea"
	raja.held_grip["r"] = "cylinder"
	raja.reach_release("r")
	await wait(2.0)
	raja.activity = ""
	raja.held_grip.erase("r")
	raja.reach_to("r", gp)
	await wait(0.8)
	var gx2 := glass.global_transform
	glass.reparent(_stage)
	glass.global_transform = gx2
	glass.global_position = gp
	raja.reach_release("r")
	await wait(0.6)
	_caption("14. standing up")
	raja.stand_up()
	await wait(2.2)
	_seg_end("sit_reach_stand", gs)
	# railing
	raja.rotation.y = _yaw_local(0, 1)
	_caption("15. walking with a hand on the railing")
	_drive_to(_L(-25.95, 0, 70.2))
	while _driving: await get_tree().process_frame
	_seg_begin(gs)
	var rail_err := [0.0]
	_watch(func():
		var p: Vector3 = pl.global_position
		var lp: Vector3 = Campus.frame().affine_inverse() * p
		var rt := _L(C.rail_x + 0.01, C.g + 1.03 + 0.04, lp.z + 0.12)
		raja.reach_to("r", rt, "flat")
		if raja.reach.has("r") and float(raja.reach.r.w) >= 0.999:
			rail_err[0] = maxf(rail_err[0], raja.gait.palm("r").distance_to(rt))
		_tcam(p - side * 1.9 + fwd * 1.6 + Vector3(0, 1.5, 0), p + Vector3(0, 0.95, 0), 44.0))
	_drive_to(_L(-25.95, 0, 75.5))
	while _driving: await get_tree().process_frame
	_watch(Callable())
	raja.reach_release("r")
	_r1["rail_palm_err_max_m"] = rail_err[0]
	await wait(0.8)
	_seg_end("railing_walk", gs)
	# push
	_caption("16. pushing another person")
	var other: Human = C.other
	_drive_to(_L(-25.0, 0, 79.4))
	while _driving: await get_tree().process_frame
	raja.rotation.y = _yaw_local(0, 1)
	other.global_position = pl.global_position + fwd * 0.68
	await wait(0.8)
	var pushing := [true]
	var chest := func(dx: float) -> Vector3:
		var sp: Vector3 = other.skel.global_transform * other.skel.get_bone_global_pose(other.skel.find_bone("spine_03")).origin
		var to: Vector3 = (pl.global_position - other.global_position)
		to.y = 0
		to = to.normalized()
		return sp + to * 0.13 + to.cross(Vector3.UP) * dx - Vector3(0, 0.05, 0)
	_watch(func():
		if pushing[0]:
			raja.reach_to("l", chest.call(0.11), "flat")
			raja.reach_to("r", chest.call(-0.11), "flat")
		var mid: Vector3 = (pl.global_position + other.global_position) * 0.5
		_tcam(mid + side * 2.6 + Vector3(0, 1.3, 0), mid + Vector3(0, 1.05, 0), 42.0))
	await wait(0.6)
	_r1["push_palm_err_m"] = [raja.gait.palm("l").distance_to(chest.call(0.11)), raja.gait.palm("r").distance_to(chest.call(-0.11))]
	var t := 0.0
	var o0 := other.global_position
	while t < 0.9:
		t += get_process_delta_time()
		other.global_position = o0 + fwd * 0.95 * (1.0 - pow(1.0 - minf(t / 0.9, 1.0), 2.5))
		if t > 0.25:
			pushing[0] = false
			raja.reach_release("l"); raja.reach_release("r")
		await get_tree().process_frame
	await wait(1.5)
	_watch(Callable())
	_caption("")
	print("[r1] results ", JSON.stringify(_r1))
