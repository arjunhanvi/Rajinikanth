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

func _poll(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await wait(0.2)
		t += 0.2
	return false

func _actor(nm: String):
	for a in world().crowd.npcs:
		if is_instance_valid(a) and (a.id == nm or a.ident.get("name", "") == nm):
			return a
	return null

func _op_shots() -> void:
	var k := 0
	while k < 44 and Game.s.active == "c1" and int(Game.s.step) == 0:
		await shot("op_%02d" % k)
		k += 1
		await wait(0.55)

func s_story() -> void:
	var w = world()
	var st = w.story
	Game.set_meta("cine_wait", 0.7)
	_op_shots()
	ok(await _poll(func(): return int(Game.s.step) == 1, 150.0), "opening tea sequence runs through to bail (step=%d)" % int(Game.s.step))
	Game.set_meta("cine_wait", 0.03)
	ok(w.interior == "police" and not w.player.locked and not w.busy, "first playable moment is inside the police station")
	ok(not Sfx._music_a.playing and not Sfx._music_b.playing and not Sfx._radio.playing, "no music is playing on foot")
	await wait(1.0)
	await shot("s1_station_playable")
	var wr = _actor("Station writer")
	ok(wr != null and _actor("lokesh") != null, "officers are in the station to talk to")
	Game.set_meta("test_choices", [1])
	await w.crowd.talk(wr)
	ok(Game.flag("belongings"), "belongings returned by the writer")
	w.leave_interior()
	await wait(1.0)
	ok(int(Game.s.step) == 2, "walking out advances to 'Kamakshi is waiting'")
	var k = await npc("kamakshi")
	ok(k != null and await npc("uma") != null, "Kamakshi and Umashankar wait outside")
	await shot("s2_outside_station")
	Game.set_meta("test_choices", [1])
	w.crowd.talk(k)
	await _poll(func(): return w.player.ride != null, 20.0)
	ok(w.player.ride != null and w.player.human.state == "pillion", "riding pillion behind Kamakshi")
	Game.test_mode = false
	await wait(4.0)
	await shot("s3_scooter_ride")
	Game.test_mode = true
	ok(await _poll(func(): return int(Game.s.step) == 3, 60.0), "ride ends at home in Malleshwaram")
	ok(w.player.global_position.distance_to(City.PLACES["home"].pos) < 25.0, "arrived near the house (%.0f m)" % w.player.global_position.distance_to(City.PLACES["home"].pos))
	await shot("s4_home_outside")
	Game.set_meta("test_choices", [0])
	w.enter_interior("home")
	ok(await _poll(func(): return int(Game.s.step) == 4, 20.0), "home scene with Kamakshi")
	await shot("s5_home_interior")
	await Shops.sleep(w)
	ok(await _poll(func(): return Game.s.active == "c2" and not w.busy, 20.0), "c1 complete, c2 begins next morning")
	k = _actor("kamakshi")
	ok(k != null, "Kamakshi is at home in the morning")
	Game.set_meta("test_choices", [1])
	await w.crowd.talk(k)
	ok(await _poll(func(): return w.player.ride == null and w.player.global_position.distance_to(Story.DEPOT) < 60.0, 60.0), "Kamakshi drops you near the depot")
	await tp(Story.DEPOT + Vector3(2, 0, 0.5))
	var u = await npc("uma")
	ok(u != null, "Umashankar waits at the depot")
	await shot("s6_uma_depot")
	_slow_shots()
	Game.set_meta("test_choices", [2])
	await w.crowd.talk(u)
	ok(st.bus != null and w.player.bus == st.bus, "conductor run started")
	await wait(0.5)
	await _do_run("s7_day")
	await wait(4.0)
	Game.set_meta("test_choices", [])
	await _do_run("s8_night")
	await wait(2.0)
	ok(Game.s.missions.has("c2") and Game.s.active == "c3" and int(Game.s.step) == 1 and Game.s.phone, "c2 complete; bag opened, phone acquired (active=%s step=%d)" % [Game.s.active, int(Game.s.step)])
	w.enter_interior("home")
	await wait(1.0)
	k = _actor("kamakshi")
	Game.set_meta("test_choices", [0, 0])
	await w.crowd.talk(k)
	ok(int(Game.s.step) == 2 and str(Game.flag("bag")) == "court", "Kamakshi takes the bag to the Magistrate")
	await Shops.sleep(w)
	ok(await _poll(func(): return Game.s.active == "c4" and int(Game.s.step) == 1 and not w.busy, 20.0), "c4 phone call on waking")
	w.leave_interior()
	Game.s.time = 9.0
	w.crowd.resync()
	await tp(w.crowd.named_pos("uma") + Vector3(1.5, 0, 1.5))
	u = await npc("uma")
	Game.set_meta("test_choices", [0, 1])
	await w.crowd.talk(u)
	ok(int(Game.s.step) == 2 and Game.flag("uma_came"), "Umashankar insists on coming")
	await tp(City.PLACES["godown"].pos)
	w.enter_interior("godown")
	await wait(1.0)
	Game.set_meta("test_choices", [1])
	await w.crowd.talk(_actor("tiger"))
	await wait(1.0)
	ok(int(Game.s.step) == 3 and w.interior == "" and w.crowd.actors("raid").size() == 2, "raid: out of the godown, Umashankar holds one back")
	await shot("s9_raid")
	var sc = w.traffic.owned[w.traffic.owned.size() - 1]
	w.player.enter_vehicle(sc)
	ok(not w.radio_ok(), "a scooter has no radio")
	sc.global_position = City.PLACES["godown"].pos + Vector3(0, 0, 220)
	await wait(2.0)
	ok(Game.s.missions.has("c4") and Game.s.active == "c4wait", "c4 complete after escaping")
	w.player.exit_vehicle()
	var car = Vehicle.create("car", 2)
	w.traffic.add_child(car)
	car.global_position = w.player.global_position + Vector3(3, 0, 0)
	w.player.enter_vehicle(car)
	await wait(0.5)
	ok(w.radio_ok() and Sfx._radio_on and not Sfx._radio.playing, "radio switches on in a car; silent because no tracks are installed (%d found)" % Sfx.radio_tracks.size())
	w.player.exit_vehicle()
	await wait(0.3)
	ok(not Sfx._radio_on, "radio off on leaving the car")
	Game.s.day = int(Game.s.day) + 1
	st.on_wake()
	ok(Game.s.active == "c5", "c5 offered the next day")
	Game.s.time = 20.5
	w.crowd.resync()
	w.enter_interior("bar")
	await wait(1.0)
	await w.crowd.talk(_actor("oilkumar"))
	ok(int(Game.s.step) == 1, "c5 briefed")
	w.leave_interior()
	st._check_done = true
	st._m4_mark("tailor")
	await st._m4_deliver("cinema")
	await tp(City.PLACES["devaraj"].pos + Vector3(0, 0, -3))
	Game.set_meta("test_choices", [2])
	await st._m4_deliver("devaraj")
	await shot("s10_devaraj")
	ok(Game.s.active == "end" and str(Game.flag("devaraj_answer")) == "refuse", "chapter ends after meeting Devaraj (money=%d)" % int(Game.s.money))
	ok(Game.save_game(false), "save written")
	var money := int(Game.s.money)
	var snap := JSON.stringify(Game.s.flags)
	Game.s = {}
	ok(Game.load_game(Game.SLOTS - 1) and int(Game.s.money) == money and JSON.stringify(Game.s.flags) == snap, "load restores money and flags")
	# an old v1 save must still load
	var old := {"v": 1, "mode": "story", "name": "Rajinikanth", "look": Human.default_look(), "money": 4321, "rep": 12, "day": 9, "active": "m3", "step": 2,
		"flags": {"bag": "home"}, "vehicles": [{"type": "scooter", "col": 2, "uid": "v77", "pos": [10, 10], "rot": 0}], "wardrobe": ["top:6"], "props": [], "playtime": 999.0, "stats": {"tickets": 40, "km": 3.2, "talks": 9}, "rel": {"meena": 20}}
	var f := FileAccess.open(Game.slot_path(0), FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	ok(Game.load_game(0) and int(Game.s.money) == 4321 and Game.s.active == "" and Game.s.vehicles.size() == 1 and Game.s.wardrobe.has("top:6") and Game.flag("migrated") and int(Game.s.v) == 2, "v1 save migrates: money, vehicle and clothes kept, story restarts")
	Game.delete_slot(0)
	print("final: rel=%s faction=%s" % [Game.s.rel, Game.s.faction])

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

func s_humans() -> void:
	var w = world()
	Game.s.time = 10.0
	w.crowd.resync()
	await tp(Vector3(-60, 0, 150), 0.0)
	w.player.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cats = ["office", "vendor", "student", "", "shopper", "mechanic", "elder", "police", "coolie", "priest"]
	var acts = ["read", "work", "laugh", "tea", "listen", "", "wait", "", "", "pray"]
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
	await wait(3.0)
	await shot("hu_lineup")
	w.player.cam.fov = 40
	w.player.cam.global_position = Vector3(-63.4, 1.5, 148.2)
	w.player.cam.look_at(Vector3(-63.4, 1.35, 146), Vector3.UP)
	await wait(1.5)
	await shot("hu_close")
	w.player.cam.fov = 62
	w.player.cam_override = false
	w.player.visible = true
	w.crowd.clear_actors("demo")
	# a normal street: count what is on screen and how long a frame takes
	Game.s.time = 9.0
	await tp(Vector3(30, 0, 150), 1.2)
	await wait(6.0)
	await shot("hu_street")
	var t0 := Time.get_ticks_usec()
	var f0 := Engine.get_frames_drawn()
	await wait(5.0)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(Engine.get_frames_drawn() - f0)
	var tris := 0
	var skinned := 0
	for n in w.crowd.npcs:
		if is_instance_valid(n):
			skinned += 1
	print("[perf] software renderer: %.1f ms/frame, people on scene %d, draw calls %d, primitives %d" % [ms, skinned, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	print("[perf] texture memory %.0f MB, static memory %.0f MB" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0, OS.get_static_memory_usage() / 1048576.0])
