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
	await tp(Vector3(-25, 0, 100.5), 0.6)
	w.player.yaw = PI
	await wait(1.5)
	await shot("t3_tea_stall")
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

func npc(id: String):
	var w = world()
	for i in 40:
		var n = w.crowd.node_of(id)
		if n != null:
			return n
		await wait(0.25)
	return null

func _slow_shots() -> void:
	var w = world()
	var k := 0
	while k < 8 and is_instance_valid(w):
		if w._slow:
			await shot("slowmo_%d" % k)
			k += 1
		await wait(0.12)

func _do_run(tag: String) -> void:
	var w = world()
	var st = w.story
	var guard := 0
	while st.bus != null and guard < 400:
		guard += 1
		if st.bus.ai.hold and st._incident_t < 0.0 and not w.hud.cinematic:
			for i in range(st.pax.size() - 1, -1, -1):
				if i < st.pax.size() and not st.pax[i].paid:
					var stages: int = st.pax[i].dest - st.stop_i
					Game.set_meta("test_choices", [clampi(stages, 1, 4) - 1])
					await st._ticket(i)
			if st.stop_i == 1:
				await shot(tag + "_in_bus")
			st.bus_signal("whistle")
			Engine.time_scale = 6.0
		await wait(0.3)
		if w._slow or w.hud.cinematic:
			pass
		elif st.bus != null and not st.bus.ai.hold:
			Engine.time_scale = 6.0
	Engine.time_scale = 1.0

func s_story() -> void:
	var w = world()
	var st = w.story
	await wait(1.5)
	ok(Game.s.active == "m0" and int(Game.s.step) == 0, "story starts at m0/0")
	await tp(Vector3(-25, 0, 100.5))
	var n = await npc("nanjappa")
	ok(n != null, "Nanjappa is at his stall in the morning")
	Game.set_meta("test_choices", [0])
	await w.crowd.talk(n)
	ok(int(Game.s.step) == 1, "m0 advances after tea (money now %d)" % int(Game.s.money))
	await tp(Story.DEPOT + Vector3(2, 0, 0.5))
	n = await npc("basanna")
	ok(n != null, "Basanna waits at the depot")
	await shot("s1_depot")
	_slow_shots()
	await w.crowd.talk(n)
	ok(st.bus != null and w.player.bus == st.bus, "conductor run started, player aboard")
	await wait(0.5)
	await _do_run("s2_day")
	await wait(4.0)
	Game.set_meta("test_choices", [])
	await _do_run("s3_night")
	await wait(2.0)
	ok(Game.s.missions.has("m1"), "m1 complete")
	ok(Game.s.active == "m2" and int(Game.s.step) == 1 and Game.s.phone, "m2 step 1, phone acquired (active=%s step=%d)" % [Game.s.active, int(Game.s.step)])
	await shot("s4_after_m1")
	Game.set_meta("test_choices", [1, 1])
	w.enter_interior("home")
	await wait(1.5)
	await shot("s5_home_interior")
	ok(int(Game.s.step) == 2 and Game.flag("bag") == "home", "bag hidden at home")
	await Shops.sleep(w)
	await wait(1.5)
	ok(Game.s.active == "m3" and int(Game.s.step) == 1, "m3 call happened on waking (active=%s step=%d day=%d)" % [Game.s.active, int(Game.s.step), int(Game.s.day)])
	w.leave_interior()
	Game.s.time = 9.5
	w.crowd.resync()
	await tp(Vector3(-25, 0, 98.0))
	n = await npc("meena")
	ok(n != null, "Meena is at the booth at 9:30")
	Game.set_meta("test_choices", [0, 0])
	await w.crowd.talk(n)
	ok(int(Game.s.step) == 2 and Game.flag("promise_meena"), "m3 step 2, promise made")
	await tp(City.PLACES["godown"].pos)
	await shot("s6_godown_outside")
	w.enter_interior("godown")
	await wait(1.0)
	await shot("s7_godown_inside")
	var tiger = null
	for a in w.crowd.actors("interior"):
		if a.id == "tiger": tiger = a
	ok(tiger != null, "Thimmaiah is in his godown")
	Game.set_meta("test_choices", [0, 0])
	await w.crowd.talk(tiger)
	await wait(1.0)
	ok(int(Game.s.step) == 3 and w.interior == "", "raid: thrown out of the godown, m3 step 3")
	ok(w.crowd.actors("raid").size() == 3 and w.traffic.owned.size() == 1, "3 hostiles and the scooter exist")
	await shot("s8_raid")
	w.player.enter_vehicle(w.traffic.owned[0])
	Input.action_press("mv_u")
	await wait(1.5)
	await shot("s9_scooter")
	ok(absf(w.traffic.owned[0].v) > 2.0, "scooter accelerates (v=%.1f)" % w.traffic.owned[0].v)
	Input.action_release("mv_u")
	w.traffic.owned[0].global_position = City.PLACES["godown"].pos + Vector3(0, 0, 220)
	await wait(2.0)
	ok(Game.s.missions.has("m3") and Game.s.active == "m3wait", "m3 complete after escaping")
	w.player.exit_vehicle()
	ok(Game.save_game(false), "save written")
	var money := int(Game.s.money)
	var snap := JSON.stringify(Game.s.flags)
	Game.s = {}
	ok(Game.load_game(Game.SLOTS - 1) and int(Game.s.money) == money and JSON.stringify(Game.s.flags) == snap and Game.s.vehicles.size() == 1, "load restores money, flags and vehicle")
	print("final: money=%d rep=%d rel=%s faction=%s" % [int(Game.s.money), int(Game.s.rep), Game.s.rel, Game.s.faction])

	# --- M4 ---
	w = world()
	Game.s.day = int(Game.s.day) + 1
	w.story.on_wake()
	ok(Game.s.active == "m4", "m4 offered the next day")
	Game.s.time = 20.5
	w.crowd.resync()
	w.enter_interior("bar")
	await wait(1.0)
	await shot("s10_bar")
	var oil = null
	for a in w.crowd.actors("interior"):
		if a.id == "oilkumar": oil = a
	ok(oil != null, "Oil Kumar is in the bar after 8")
	if oil != null:
		await w.crowd.talk(oil)
	ok(int(Game.s.step) == 1, "m4 briefed")
	w.leave_interior()
	w.story._check_done = true
	w.story._m4_mark("tailor")
	Game.set_meta("test_choices", [2])
	await w.story._m4_deliver("cinema")
	await w.story._m4_deliver("jpp")
	ok(Game.s.active == "end" and Game.s.missions.has("m4"), "chapter one ends (money=%d)" % int(Game.s.money))

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

func s_people() -> void:
	var w = world()
	Game.s.time = 10.0
	await tp(Vector3(-60, 0, 150), 0.0)
	w.player.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cats = ["office", "vendor", "student", "", "shopper", "mechanic", "elder", "police", "coolie", "priest"]
	var acts = ["read", "work", "laugh", "tea", "listen", "fix", "wait", "", "", "pray"]
	for i in cats.size():
		var ident = People.random_identity(rng, "com")
		if i in [3, 4]: ident.sex = 1
		var n = w.crowd._make(ident, Vector3(-66 + i * 1.3, 0, 146.0), cats[i])
		n.story_tag = "demo"; n.no_despawn = true
		n.face_yaw = PI; n.human.rotation.y = PI
		n.base_act = acts[i]; n.human.activity = acts[i]
	w.player.cam_override = true
	w.player.cam.global_position = Vector3(-60.2, 1.5, 151.5)
	w.player.cam.look_at(Vector3(-60.2, 1.0, 146), Vector3.UP)
	await wait(2.5)
	await shot("pe_lineup")
	w.player.cam.global_position = Vector3(-63.4, 1.55, 147.6)
	w.player.cam.look_at(Vector3(-63.4, 1.5, 146), Vector3.UP)
	await wait(1.0)
	await shot("pe_close")
