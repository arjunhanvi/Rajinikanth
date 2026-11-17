class_name World
extends Node3D
## The gameplay scene: streams the city around the player, runs the clock and
## weather, routes interaction, and hosts crowd, traffic, story and HUD.

const HOUR_SECONDS := 120.0      # one game hour per two real minutes

var player: Player
var hud: HUD
var crowd: Crowd
var traffic: Traffic
var story: Story
var weather: Weather
var chunks := {}                 # Vector2i -> Chunk
var interior := ""               # id of the interior we are inside ("" = on the street)
var exterior_pos := Vector2.ZERO
var busy := false                # a scripted sequence owns the player
var _queue: Array = []
var _stream_t := 0.0
var _int_node: Node3D = null
var _int_t := 0.0
var _cur = null                  # current interaction target
var _beacon: MeshInstance3D
var _weather_t := 300.0
var _event_t := 40.0
var _power_t := 0.0
var _slow := false
var _autosave := 0.0
var chunk_bonus := 0              # a scene can widen the streamed radius (aerial shots)

func _ready() -> void:
	Game.world = self
	weather = Weather.new()
	add_child(weather)
	crowd = Crowd.new()
	crowd.world = self
	traffic = Traffic.new()
	traffic.world = self
	story = Story.new()
	story.world = self
	player = Player.new()
	add_child(player)
	var p: Array = Game.s.pos
	player.global_position = Vector3(p[0], 0, p[2])
	player.yaw = float(Game.s.rot)
	player.human.rotation.y = float(Game.s.rot)
	exterior_pos = Vector2(p[0], p[2])
	# build the surroundings before the first frame is shown
	_want_chunks(true)
	add_child(crowd)
	add_child(traffic)
	var cr := Critters.new()
	cr.world = self
	add_child(cr)
	hud = HUD.new()
	hud.world = self
	add_child(hud)
	add_child(story)
	_beacon = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 0.9
	cm.height = 40.0
	cm.radial_segments = 10
	cm.cap_top = false
	cm.cap_bottom = false
	_beacon.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1, 0.8, 0, 0.28)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon.material_override = bm
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beacon)
	get_viewport().scaling_3d_scale = Game.gfx("scale")
	if str(Game.s.interior) != "":
		enter_interior(str(Game.s.interior), false)
	weather.update(1.0, float(Game.s.time), Game.s.weather, player.global_position, [])
	story.begin()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	if Game.world == self:
		Game.world = null

func write_state() -> void:
	var p := player.global_position
	if interior != "":
		p = Vector3(exterior_pos.x, 0, exterior_pos.y)
	Game.s.pos = [p.x, 0.0, p.z]
	Game.s.rot = player.yaw
	Game.s.interior = interior
	traffic.write_state()

# ------------------------------------------------------------------ streaming
func _want_chunks(immediate := false) -> void:
	var centre := City.chunk_of(exterior_pos if interior != "" else Vector2(player.global_position.x, player.global_position.z))
	var r: int = int(Game.gfx("chunks")) + chunk_bonus
	var need := {}
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if dx * dx + dz * dz <= r * r + 1:
				need[centre + Vector2i(dx, dz)] = true
	for k in chunks.keys():
		var d: Vector2i = k - centre
		if absi(d.x) > r + 1 or absi(d.y) > r + 1:
			chunks[k].queue_free()
			chunks.erase(k)
	_queue.clear()
	for k in need:
		if not chunks.has(k):
			_queue.append(k)
	_queue.sort_custom(func(a, b): return (a - centre).length_squared() < (b - centre).length_squared())
	if immediate:
		while not _queue.is_empty():
			_build_next()

func _build_next() -> void:
	var k: Vector2i = _queue.pop_front()
	if chunks.has(k):
		return
	var ch := Chunk.new()
	add_child(ch)
	ch.build(k)
	chunks[k] = ch
	traffic.populate_chunk(ch)

func lamp_positions() -> Array:
	var out: Array = []
	var c := City.chunk_of(Vector2(player.global_position.x, player.global_position.z))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var ch = chunks.get(c + Vector2i(dx, dz))
			if ch != null:
				out.append_array(ch.lamps)
	return out

# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var real := delta / maxf(Engine.time_scale, 0.05)
	var vcam := get_viewport().get_camera_3d()
	var cpos: Vector3 = vcam.global_position if vcam != null else player.cam.global_position
	Human.cam_pos = cpos
	if not busy or story.clock_runs:
		Game.s.time = float(Game.s.time) + delta / HOUR_SECONDS
		if float(Game.s.time) >= 24.0:
			Game.s.time = float(Game.s.time) - 24.0
			_new_day()
	Game.s.playtime = float(Game.s.playtime) + real
	_stream_t -= delta
	if _stream_t <= 0.0:
		_stream_t = 0.3
		_want_chunks()
	if not _queue.is_empty():
		_build_next()
	weather.indoors = interior != ""
	weather.update(delta, float(Game.s.time), Game.s.weather, cpos, lamp_positions() if interior == "" else [])
	_ambience()
	Sfx.radio_set(radio_ok())
	_int_t -= delta
	if _int_t <= 0.0:
		_int_t = 0.12
		_scan_interact()
	if player.vehicle != null:
		crowd.vehicle_hits(player.vehicle)
	_update_beacon()
	_weather_t -= delta
	if _weather_t <= 0.0 and not busy:
		_weather_t = randf_range(200.0, 520.0)
		var r := randf()
		Game.s.weather = "clear" if r < 0.58 else ("cloudy" if r < 0.82 else "rain")
	if _power_t > 0.0:
		_power_t -= delta
		if _power_t <= 0.0:
			weather.power = true
			hud.toast("Current is back.")
	_event_t -= delta
	if _event_t <= 0.0 and not busy and interior == "":
		_event_t = randf_range(90.0, 200.0)
		_random_event()
	_autosave += real
	if _autosave > 90.0 and not busy and interior == "" and player.bus == null:
		_autosave = 0.0
		Game.save_game(false)
	if float(Game.s.hp) < 100.0 and not busy:
		Game.s.hp = minf(100.0, float(Game.s.hp) + delta * 1.5)

func _ambience() -> void:
	if not story.amb_override.is_empty():
		Sfx.ambience(story.amb_override)
		return
	var t := float(Game.s.time)
	var night := weather.is_night(t)
	var inside := interior != ""
	var dens := float(City.district(exterior_pos if inside else Vector2(player.global_position.x, player.global_position.z)).density)
	var k := 0.25 if inside else 1.0
	Sfx.ambience({"amb_city": (0.25 if night else 0.75) * dens * k, "amb_night": (0.6 if night else 0.0) * k, "amb_rain": weather.raining * (0.4 if inside else 0.9),
		"amb_crowd": (0.5 if (interior in ["bar", "godown"] or story.crowd_noise) else 0.0)})
const RADIO_VEHICLES := ["car", "hatch", "taxi", "jeep", "auto"]

## Music exists in exactly one place: the radio of a car or auto the player is driving.
func radio_ok() -> bool:
	return player != null and player.vehicle != null and player.vehicle.type in RADIO_VEHICLES

func _new_day() -> void:
	Game.s.day = int(Game.s.day) + 1
	story.new_day()

func area_name() -> String:
	if interior != "":
		return City.PLACES[interior].name
	return City.area_name(Vector2(player.global_position.x, player.global_position.z))

func _update_beacon() -> void:
	var op = story.objective_pos()
	var wp = Game.s.get("waypoint")
	var target = op
	if target == null and wp != null:
		target = Vector3(wp[0], 0, wp[1])
	_beacon.visible = target != null and interior == "" and player.global_position.distance_to(target) > 6.0
	if target != null:
		_beacon.global_position = target + Vector3(0, 20, 0)
	if wp != null and Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(wp[0], wp[1])) < 8.0:
		Game.s.waypoint = null
		hud.toast("Reached your marked spot.")
	# discovering places by walking past them
	for id in City.PLACES:
		if not Game.s.discovered.has(id) and City.PLACES[id].pos.distance_to(player.global_position) < 22.0 and interior == "":
			Game.discover(id)

# ------------------------------------------------------------------ interaction
func _scan_interact() -> void:
	_cur = null
	if busy or hud.modal > 0 or hud.cinematic:
		hud.set_interact("")
		return
	var pp := player.global_position
	var best := 1e9
	for h in story.hotspots():
		var d: float = pp.distance_to(h.pos)
		if d < float(h.get("r", 2.4)) and d < best:
			best = d
			_cur = {"kind": "story", "label": h.label, "key": h.key}
	if _cur == null and player.bus == null and player.vehicle == null:
		var n := crowd.nearest_talkable(pp, 2.3)
		if n != null:
			_cur = {"kind": "npc", "label": "TALK", "npc": n}
		if interior != "":
			for h in Interiors.hotspots(interior):
				var d2: float = pp.distance_to(_int_node.global_position + h.pos)
				if d2 < 1.7 and (_cur == null or d2 < 1.2):
					_cur = {"kind": "int", "label": h.label, "key": h.key}
		else:
			if _cur == null:
				for veh in traffic.all_enterable():
					if is_instance_valid(veh) and veh.global_position.distance_to(pp) < float(veh.spec.l) * 0.5 + 1.4:
						_cur = {"kind": "veh", "label": "RIDE" if veh.spec.open else "DRIVE", "veh": veh}
						break
			if _cur == null:
				for id in City.PLACES:
					var pl = City.PLACES[id]
					if pl.pos.distance_to(pp) < 2.6:
						var lab := _place_label(id, pl.kind)
						if lab != "":
							_cur = {"kind": "place", "label": lab, "id": id}
				for id in City.stops:
					var sp: Vector2 = City.stops[id].pos
					if sp.distance_to(Vector2(pp.x, pp.z)) < 3.5:
						_cur = {"kind": "stop", "label": "BUS", "id": id}
	hud.set_interact(_cur.label if _cur != null else "")

func _place_label(id: String, kind: String) -> String:
	if Interiors.has(id):
		return "ENTER"
	match kind:
		"cinema": return "FILM"
		"property": return "VIEW"
		"market": return "SHOP"
	return ""

func interact() -> void:
	if _cur == null or busy:
		return
	var c = _cur
	match c.kind:
		"story": story.on_hotspot(c.key)
		"npc":
			if is_instance_valid(c.npc):
				crowd.talk(c.npc)
		"int": _interior_action(c.key)
		"veh": _take_vehicle(c.veh)
		"place":
			if Interiors.has(c.id):
				enter_interior(c.id)
			else:
				Shops.place(self, c.id)
		"stop": Shops.bus_travel(self, c.id)

func _take_vehicle(veh: Vehicle) -> void:
	if not is_instance_valid(veh):
		return
	if not veh.owned and not veh.ai.is_empty():
		# borrowing somebody's parked vehicle: fine if nobody is watching
		traffic.keep(veh)
		var seen := false
		for n in crowd.npcs:
			if is_instance_valid(n) and n.global_position.distance_to(veh.global_position) < 14.0 and n.mode != "ko":
				seen = true
		if seen:
			Game.add_heat(14.0)
			crowd.alarm(veh.global_position, 10.0)
			hud.subtitle("Bystander: Ey! That's not your vehicle! Kalla! Kalla!", 3.0)
	player.enter_vehicle(veh)

func exit_vehicle() -> void:
	if player.vehicle != null and absf(player.vehicle.v) < 4.0:
		player.exit_vehicle()

func player_horn() -> void:
	if player.vehicle != null:
		Sfx.play(player.vehicle.spec.horn, 0.9)
		crowd.alarm(player.vehicle.global_position - player.vehicle.global_transform.basis.z * 6.0, 5.0)

func on_crash(_veh: Vehicle, speed: float) -> void:
	if speed > 9.0:
		Game.add_heat(6.0)
		Game.s.hp = float(Game.s.hp) - speed * 0.8
		Game.changed.emit()
		crowd.alarm(player.global_position, 20.0)
		if float(Game.s.hp) <= 0.0:
			player_down()

# ------------------------------------------------------------------ interiors
func enter_interior(id: String, announce := true) -> void:
	if interior == "":
		exterior_pos = Vector2(player.global_position.x, player.global_position.z)
	if _int_node != null:
		_int_node.queue_free()
	interior = id
	_int_node = Interiors.build(id, self)
	add_child(_int_node)
	var slot_i: int = Interiors.IDS.find(id)
	_int_node.global_position = Vector3(20000.0 + slot_i * 200.0, 0, 20000.0)
	player.global_position = _int_node.global_position + Interiors.entry(id)
	player.yaw = 0.0
	player.human.rotation.y = 0.0
	player.cam.global_position = player.global_position + Vector3(0, 2, 3)
	Interiors.populate(id, self, _int_node.global_position)
	if announce:
		Sfx.play("door")
		Game.discover(id)
	story.on_enter(id)

func leave_interior() -> void:
	if interior == "":
		return
	crowd.clear_actors("interior")
	var id := interior
	interior = ""
	if _int_node != null:
		_int_node.queue_free()
		_int_node = null
	var p: Vector3 = City.PLACES[id].pos
	player.global_position = p
	player.cam.global_position = p + Vector3(0, 3, 4)
	Sfx.play("door")
	story.on_leave(id)

func _interior_action(key: String) -> void:
	match key:
		"leave": leave_interior()
		_:
			if not await story.on_interior(interior, key):
				Shops.interior(self, interior, key)

# ------------------------------------------------------------------ consequences
func player_down() -> void:
	if busy:
		return
	busy = true
	player.locked = true
	player.human.state = "ko"
	if player.vehicle != null:
		player.exit_vehicle()
	await hud.fade(1.0, 1.2)
	var bill := mini(int(Game.s.money), 150)
	Game.s.hp = 60.0
	Game.s.heat = 0.0
	for n in crowd.npcs.duplicate():
		if is_instance_valid(n) and n.mode in ["hostile", "cop"]:
			crowd.remove(n)
	story.on_player_down()
	_warp(City.PLACES["home"].pos, 3.0)
	Game.add_money(-bill, "Victoria Hospital, out-patient")
	player.human.state = "idle"
	player.locked = false
	busy = false
	await hud.fade(0.0, 1.0)
	hud.subtitle("You wake up outside the vatara with a bandage and a bill.", 4.0)

func arrested() -> void:
	busy = true
	player.locked = true
	if player.vehicle != null:
		player.exit_vehicle()
	await hud.say("Constable", "Station-ge baa. Come quietly.")
	hud.end_talk()
	await hud.fade(1.0, 0.8)
	var fine := mini(int(Game.s.money), 50 + int(float(Game.s.heat)) * 4)
	Game.s.heat = 0.0
	for n in crowd.npcs.duplicate():
		if is_instance_valid(n) and n.mode == "cop":
			crowd.remove(n)
	_warp(City.PLACES["police"].pos, 2.0)
	Game.add_money(-fine, "'fine' (no receipt)")
	Game.add_faction("police", -3)
	Game.log_event("Spent two hours on a bench at Upparpet station.")
	player.locked = false
	busy = false
	await hud.fade(0.0, 0.8)

func _warp(p: Vector3, hours: float) -> void:
	if interior != "":
		crowd.clear_actors("interior")
		interior = ""
		if _int_node != null:
			_int_node.queue_free()
			_int_node = null
	player.global_position = Vector3(p.x, 0, p.z)
	exterior_pos = Vector2(p.x, p.z)
	pass_time(hours)
	_want_chunks(true)

func pass_time(hours: float) -> void:
	Game.s.time = float(Game.s.time) + hours
	while float(Game.s.time) >= 24.0:
		Game.s.time = float(Game.s.time) - 24.0
		_new_day()
	crowd.resync()

## Fade out, move the player across town, let time pass, fade in.
func travel(p: Vector3, hours: float) -> void:
	busy = true
	player.locked = true
	await hud.fade(1.0, 0.6)
	if player.vehicle != null:
		player.exit_vehicle()
	_warp(p, hours)
	player.locked = false
	busy = false
	await hud.fade(0.0, 0.6)

# ------------------------------------------------------------------ cinematic slow motion
func slowmo(scale: float, on: bool) -> void:
	_slow = on
	Engine.time_scale = scale if on else 1.0
	Sfx.duck = 0.25 if on else 1.0
	var i := AudioServer.get_bus_index("Sfx")
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(Game.settings.sfx) * (0.35 if on else 1.0), 0.001)))
	hud.slow_fx(on)
	if on:
		Sfx.play("heart", 1.0)

func wait(t: float) -> void:
	await get_tree().create_timer(t if not Game.test_mode else minf(t, float(Game.get_meta("cine_wait", 0.03))), true, false, true).timeout

# ------------------------------------------------------------------ living-city events
func _random_event() -> void:
	var t := float(Game.s.time)
	var r := randf()
	if r < 0.3 and weather.is_night(t) and weather.power:
		weather.power = false
		_power_t = randf_range(25.0, 60.0)
		Sfx.play("shutter", 0.5, 0.6)
		hud.toast("Power cut. \"Current hoytu!\"")
		hud.subtitle("Somewhere a generator coughs awake.", 3.0)
	elif r < 0.7:
		story.street_event()
