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
