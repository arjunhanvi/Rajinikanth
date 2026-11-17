class_name Story
extends Node
## Chapter One: "Ticket". Mission state lives in Game.s (active, step, mvars,
## flags) so every beat survives save/load. Scenes are coroutines.

const ROUTE := ["majestic", "gandhinagar", "vidhana", "shivajinagar", "mgroad", "ulsoor"]
const DEPOT := Vector3(27.6, 0, -28.0)
const TITLES := {"c1": "Bail", "c2": "Back on the Route", "c3": "Eighteen Lakhs", "c4": "Wrong Number", "c5": "The Conductor's Bag", "end": "Chapter One complete"}

var world
var clock_runs := false
var crowd_noise := false
var bus: Vehicle = null
var pax: Array = []            # {h: Human, seat: int, dest: int, paid: bool, name: String, tag: String}
var stop_i := 0                # index into the current run's stop list
var run_stops: Array = []
var _run_night := false
var _incident_t := -1.0
var _cam_fn := Callable()
var _bag: MeshInstance3D = null
var _collected := 0
var _mistakes := 0
var _thief: NPC = null
var _thief_t := 0.0
var _rally_day := -1
var _check_done := false
var _ride := {}                # active pillion ride: {veh, pts, i, v, lines, ...}

var hud: HUD:
	get: return world.hud
var pl: Player:
	get: return world.player
var s: Dictionary:
	get: return Game.s

func _ready() -> void:
	world.traffic.bus_arrived.connect(_on_bus_arrived)
	world.crowd.npc_down.connect(_on_npc_down)

# ------------------------------------------------------------------ helpers
func say(who: String, text: String) -> void:
	var n: NPC = world.crowd.node_of(who) if world.crowd.named.has(who) else null
	if n != null:
		n.human.talk_t = 2.5
	if who == "raji":
		pl.human.talk_t = 2.0
	var nm: String = People.NAMES.get(who, who)
	if who == "raji":
		nm = str(s.name)
	if who == "phone" and Game.flag("oil_known"):
		nm = "'Oil' Kumar"
	hud.voice = float(People.DB[who].get("voice", 1.0)) if People.DB.has(who) else 1.0
	await hud.say(nm, text)
	hud.voice = 1.0

func choose(opts: Array) -> int:
	return await hud.choose(opts)

func _scene(on: bool, bars := false) -> void:
	world.busy = on
	pl.locked = on
	if bars or not on:
		if hud.cinematic != (on and bars):
			hud.letterbox(on and bars)
	if not on:
		hud.end_talk()

func set_step(m: String, st: int) -> void:
	s.active = m
	s.step = st
	Game.changed.emit()

func _complete(m: String, reward: int, rep: int, note: String) -> void:
	s.missions[m] = "done"
	Game.log_event("%s: %s" % [TITLES[m], note])
	hud.card("MISSION COMPLETE", TITLES[m])
	Sfx.play("boom", 0.5)
	if reward != 0:
		Game.add_money(reward, "")
	Game.add_rep(rep)
	Game.save_game(false)

func place(id: String) -> Vector3:
	return City.PLACES[id].pos

# ------------------------------------------------------------------ lifecycle
func begin() -> void:
	if s.mode != "story":
		s.active = "free"
		return
	if Game.flag("migrated") and not Game.flag("migrated_told"):
		Game.set_flag("migrated_told")
		hud.toast("Your save was carried over. The story has been retold from the beginning; money, clothes and vehicles are kept.")
	if str(s.active) == "" or (s.active == "c1" and int(s.step) == 0):
		set_step("c1", 0)
		_opening()
	elif s.active == "c2" and int(s.step) == 2:
		set_step("c2", 1)        # a save made mid-route resumes at the depot
	_apply_pins()

func _apply_pins() -> void:
	var a := str(s.active)
	var st := int(s.step)
	if (a == "c2" and st <= 1) or (a == "c3" and st <= 1):
		world.crowd.pin("uma", DEPOT, -PI * 0.5)
	else:
		world.crowd.unpin("uma")
	if a == "c1" and st == 2:
		_wait_outside_station()
	else:
		world.crowd.unpin("kamakshi")

func _opening() -> void:
	_scene(true, true)
	pl.cam_override = true
	pl.human.visible = false
	await hud.fade(1.0, 0.01)
	s.time = 16.2
	world.crowd.resync()
	# --- 1. the tea, in close-up ---
	var ts := TeaSet.new()
	world.add_child(ts)
	var o := Vector3(20000, 0, 21500)
	ts.global_position = o
	world.weather.indoors = true
	Sfx.ambience({"amb_city": 0.12})
	_cam_move(o + Vector3(1.1, 0.75, 1.5), o + Vector3(0.8, 0.62, 1.25), o + Vector3(0, 0.3, 0), o + Vector3(0, 0.3, 0), 6.0, 15.0)
	await hud.fade(0.0, 2.0)
	Sfx.play("pour", 0.7)
	ts.pour_water()
	await world.wait(3.4)
	_cam_move(o + Vector3(-0.9, 1.0, 0.95), o + Vector3(-0.75, 0.92, 0.8), o + Vector3(0, 0.36, 0), o + Vector3(0, 0.33, 0), 3.5, 12.0)
	ts.add_leaves()
	Sfx.play("hiss", 0.5)
	await world.wait(3.0)
	ts.boil()
	_cam_move(o + Vector3(0.2, 0.7, 1.4), o + Vector3(0.1, 0.8, 1.3), o + Vector3(0, 0.42, 0), o + Vector3(0, 0.55, 0), 4.0, 13.0)
	Sfx.play("boil", 0.6)
	await world.wait(2.2)
	Sfx.play("pour", 0.5, 1.3)
	ts.add_milk()
	await world.wait(2.8)
	ts.stir(true)
	_cam_move(o + Vector3(0.85, 0.95, 0.9), o + Vector3(0.7, 0.9, 1.0), o + Vector3(0, 0.34, 0), o + Vector3(0, 0.34, 0), 3.0, 11.0)
	Sfx.play("clink", 0.5)
	await world.wait(2.8)
	ts.stir(false)
	# the long pour between tumblers
	_cam_move(o + Vector3(2.1, 0.5, 1.6), o + Vector3(1.9, 0.62, 1.5), o + Vector3(0.75, 0.5, 0.1), o + Vector3(0.75, 0.56, 0.1), 4.2, 20.0)
	ts.metre_pour(true)
	Sfx.play("pour", 0.9, 0.9)
	await world.wait(2.1)
	Sfx.play("pour", 0.9, 1.1)
	await world.wait(2.1)
	ts.metre_pour(false)
	# the glass fills; it goes on the tray
	_cam_move(o + Vector3(-0.45, 0.2, 0.95), o + Vector3(-0.55, 0.16, 0.85), o + Vector3(-0.91, 0.06, 0.02), o + Vector3(-0.91, 0.06, 0.02), 3.6, 10.0)
	ts.fill_glass()
	Sfx.play("pour", 0.6, 1.5)
	await world.wait(2.6)
	Sfx.play("clink", 0.7)
	_cam_move(o + Vector3(-0.2, 0.4, 1.3), o + Vector3(-0.35, 0.5, 1.4), o + Vector3(-0.75, 0.06, 0.1), o + Vector3(-0.75, 0.1, 0.1), 2.6, 20.0)
	await world.wait(2.4)
	await hud.fade(1.0, 0.7)
	ts.queue_free()
	world.weather.indoors = false
	# --- 2. the tray goes down the street ---
	var door := place("police")
	pl.global_position = door + Vector3(0, 0, 3.0)
	world.exterior_pos = Vector2(door.x, door.z)
	world._want_chunks(true)
	var boy: NPC = world.crowd.spawn_actor(_raju_look(), {"name": "Raju", "job": "tea boy"}, door + Vector3(-16.0, 0, 1.6), "opening", -PI * 0.5)
	_give_tray(boy)
	boy.speed = 1.5
	boy.go(PackedVector2Array([Vector2(door.x - 1.0, door.z + 1.6), Vector2(door.x, door.z + 0.2)]), "idle")
	_cam_fn = func():
		if is_instance_valid(boy):
			var bp: Vector3 = boy.global_position
			pl.cam.fov = 34.0
			pl.cam.global_position = bp + Vector3(1.6, 1.05, 2.3)
			pl.cam.look_at(bp + Vector3(0.9, 1.12, 0), Vector3.UP)
	await hud.fade(0.0, 0.8)
	hud.subtitle("A tea stall outside Upparpet Police Station. Thirty-one glasses a day go in. Thirty-one come out empty.", 5.0)
	await world.wait(9.0)
	await hud.fade(1.0, 0.6)
	world.crowd.clear_actors("opening")
	# --- 3. inside the station ---
	world.enter_interior("police", false)
	var io: Vector3 = world._int_node.global_position
	pl.global_position = io + Vector3(3.0, 0, -2.5)
	pl.human.visible = true
	pl.human.rotation.y = PI
	pl.pose = "sit"
	pl.human.state = "sit"
	pl.human.mood = "tired"
	pl.human.emotion = -0.4
	pl.human.activity = ""
	var c1n: NPC = world.crowd.spawn_actor(Human.random_look(world.crowd.rng, 0, "police"), {"name": "Head Constable", "job": "police"}, io + Vector3(-3.3, 0, 0.8), "interior", PI * 0.5)
	c1n.sit = true
	c1n.human.state = "sit"
	c1n.base_act = "read"
	c1n.human.activity = "read"
	var wr: NPC = world.crowd.spawn_actor(Human.random_look(world.crowd.rng, 0, "police"), {"name": "Station writer", "job": "police"}, io + Vector3(-0.2, 0, 1.7), "interior", PI)
	wr.base_act = "work"
	wr.human.activity = "work"
	boy = world.crowd.spawn_actor(_raju_look(), {"name": "Raju", "job": "tea boy"}, io + Vector3(0.3, 0, 2.6), "interior", 0.0)
	_give_tray(boy)
	_cam_move(io + Vector3(1.6, 1.2, 2.9), io + Vector3(-0.2, 1.3, 2.4), io + Vector3(-1.2, 1.0, 0), io + Vector3(-2.2, 1.0, -0.6), 5.0, 40.0)
	await hud.fade(0.0, 0.7)
	boy.go(PackedVector2Array([Vector2(io.x - 2.4, io.z + 1.0)]), "idle")
	await world.wait(2.6)
	Sfx.play("clink", 0.5)
	c1n.human.activity = "tea"
	await hud.say("Head Constable", "Ey Raju. Sugar less means sugar less. This is payasa.")
	boy.go(PackedVector2Array([Vector2(io.x - 1.4, io.z - 0.6)]), "idle")
	_cam_move(io + Vector3(0.6, 1.5, 0.6), io + Vector3(0.0, 1.4, 0.2), io + Vector3(-1.5, 1.0, -2.0), io + Vector3(-1.5, 1.1, -2.2), 4.0, 36.0)
	await world.wait(2.0)
	Sfx.play("clink", 0.5)
	await say("lokesh", "(Takes a glass without looking up from his file.)")
	await hud.say("Station writer", "One is left over, saar.")
	await say("lokesh", "Lock-up. His wife has been sitting in the Sessions Court since morning. Let him at least be awake when she comes.")
	hud.end_talk()
	# --- 4. the last glass ---
	boy.go(PackedVector2Array([Vector2(io.x + 2.6, io.z - 0.9)]), "idle")
	_cam_fn = func():
		if is_instance_valid(boy):
			var bp2: Vector3 = boy.global_position
			pl.cam.fov = 30.0
			pl.cam.global_position = bp2 + Vector3(-1.5, 1.15, 1.3)
			pl.cam.look_at(bp2 + Vector3(0.35, 1.1, -0.3), Vector3.UP)
	await world.wait(4.2)
	boy.face(pl.global_position)
	boy.human.play_once("give", 1.6)
	_cam_move(io + Vector3(2.7, 1.25, 0.6), io + Vector3(2.9, 1.2, -0.2), io + Vector3(3.0, 1.15, -2.5), io + Vector3(3.0, 1.2, -2.5), 5.5, 20.0)
	Sfx.play("clink", 0.4)
	await world.wait(1.6)
	pl.human.activity = "tea"
	hud.card("RAJINIKANTH", "Conductor, Route 27E.  Under-trial, Crime No. 214/2002.", 4.5)
	await world.wait(5.0)
	await hud.say("Head Constable", "Nine days he is here and he still folds his blanket. Decent fellow.")
	await hud.say("Station writer", "Eve-teasing on a city bus. The girl's statement says 'a man in khaki pushed against me and laughed'. The whole 27E had one man in khaki.")
	await hud.say("Head Constable", "The complaint is true. Somebody did that to her. Whether the name on the F.I.R. is true is a different column.")
	await hud.say("Station writer", "Devaraj saar's nephew was on that bus.")
	await hud.say("Head Constable", "Drink your tea.")
	hud.end_talk()
	# --- 5. Kamakshi ---
	Sfx.play("door", 0.8)
	var kl := People.look_of("kamakshi")
	kl.top = 11
	var kam: NPC = world.crowd.spawn_actor(kl, {"name": "Kamakshi", "job": "advocate"}, io + Vector3(0, 0, 2.8), "interior", 0.0)
	kam.id = "kamakshi"
	kam.human.walk = People.DB["kamakshi"].walk
	kam.speed = 1.7
	kam.go(PackedVector2Array([Vector2(io.x - 1.3, io.z - 0.5)]), "idle")
	_cam_move(io + Vector3(-3.6, 1.5, -2.6), io + Vector3(-3.4, 1.5, -2.4), io + Vector3(-0.8, 1.3, 1.0), io + Vector3(-1.3, 1.4, -0.6), 3.4, 34.0)
	await world.wait(3.0)
	kam.face(io + Vector3(-1.5, 0, -2.5))
	kam.human.emotion = -0.3
	await hud.say("Kamakshi", "Sub-Inspector. Bail order, Fourth Additional Sessions Judge, Crime 214 of 2002. Served on this station at 3:40 this afternoon. It is now 4:15.")
	await say("lokesh", "Madam, the writer has to make the entry, the surety has to be verified, the Inspector has to sign. These things have a procedure. Come tomorrow morning.")
	await hud.say("Kamakshi", "The surety is Mr. K. Umashankar, B.C.T.S. driver, who is standing outside holding his salary certificate with both hands. The Inspector is ten feet behind you. The writer is that gentleman drinking tea.")
	await hud.say("Kamakshi", "I will wait. I have waited nine days. But every minute my client spends in that room after 3:40 is illegal detention, and I am keeping count for the High Court.")
	_cam_at(io + Vector3(-0.6, 1.45, -1.9), io + Vector3(-1.5, 1.2, -2.6), 30.0)
	await say("lokesh", "...'Client.' He's your husband, madam.")
	_cam_at(io + Vector3(-1.9, 1.5, -1.9), io + Vector3(-1.3, 1.5, -0.5), 28.0)
	await hud.say("Kamakshi", "In this building he is my client. At home he is my problem. Open the lock-up.")
	await say("shivaramu", "Lokesh. Open it. I have signed.")
	hud.end_talk()
	Sfx.play("shutter", 0.9, 0.7)
	await world.wait(1.2)
	kam.go(PackedVector2Array([Vector2(io.x + 2.8, io.z - 0.8)]), "idle")
	_cam_move(io + Vector3(3.9, 1.3, -3.0), io + Vector3(3.8, 1.4, -2.9), io + Vector3(3.0, 1.0, -2.3), io + Vector3(2.9, 1.3, -1.4), 3.6, 36.0)
	pl.human.activity = ""
	pl.pose = ""
	pl.human.state = "idle"
	pl.human.mood = ""
	pl.human.look_target = io + Vector3(2.8, 1.55, -0.8)
	await world.wait(3.0)
	kam.face(pl.global_position)
	kam.human.look_target = pl.global_position + Vector3(0, 1.6, 0)
	await hud.say("Kamakshi", "You've lost weight. Your moustache has not.")
	var c := await choose(["\"I didn't do it, Kamu.\"", "\"You shouldn't have had to come to a place like this.\"", "Say nothing. Look at the floor."])
	if c == 0:
		Game.set_flag("c1_said", "innocent")
		await hud.say("Kamakshi", "I know you didn't. If I thought you had, I would have argued for the prosecution. Wash your face.")
	elif c == 1:
		Game.set_flag("c1_said", "sorry")
		Game.add_rel("kamakshi", 4)
		await hud.say("Kamakshi", "I come to places like this every week, Rajini. I just don't usually know the accused's shirt size. Wash your face.")
	else:
		Game.set_flag("c1_said", "silent")
		await hud.say("Kamakshi", "Floor. Good. That's the face you make when the gas cylinder is over and you forgot to book. Get up.")
	await hud.say("Kamakshi", "Collect your things from the writer. I'll be outside with the scooter. Umashankar has been crying on it, so check the seat.")
	hud.end_talk()
	kam.go(PackedVector2Array([Vector2(io.x, io.z + 2.9)]), "gone")
	await hud.fade(1.0, 0.6)
	if is_instance_valid(boy):
		world.crowd.remove(boy)
	pl.global_position = io + Vector3(2.4, 0, -0.4)
	pl.human.look_target = null
	pl.human.emotion = 0.0
	pl.cam.fov = 62.0
	pl.cam_override = false
	_cam_fn = Callable()
	pl.yaw = 0.6
	s.time = 16.6
	set_step("c1", 1)
	_scene(false)
	await hud.fade(0.0, 0.8)
	hud.card("CHAPTER ONE", "T I C K E T")
	hud.toast("Left stick: walk.  Drag the right side: look.  Yellow button: talk, use, enter.")

func new_day() -> void:
	var j := clampf(float(s.politics.jpp) + randf_range(-3.0, 3.0) + (1.5 if str(Game.flag("devaraj_answer")) == "accept" else 0.0) - (2.0 if Game.flag("tipped_press") else 0.0), 20.0, 80.0)
	s.politics.jpp = j
	s.politics.knv = 100.0 - j
	if int(s.day) % 7 == 0 and s.mode == "story":
		if Game.can_pay(300):
			Game.add_money(-300, "your half of the house rent")
		else:
			Game.add_rel("kamakshi", -3)
			Game.add_message("Kamakshi", "I have paid the full rent this month. This is not a complaint. It is a record.")

func on_wake() -> void:
	var a := str(s.active)
	if a == "c1" and int(s.step) == 4:
		_complete("c1", 0, 0, "Home. Hot water. A cot that was not cement.")
		set_step("c2", 0)
		world.crowd.pin("uma", DEPOT, -PI * 0.5)
		_scene(true)
		await say("kamakshi", "Six-thirty. Uniform is on the nail. The depot has reinstated you pending enquiry; if you sit at home, you will start believing them.")
		await say("kamakshi", "I leave for court at nine-thirty. If you want a lift to Majestic, ask before I've started the scooter, not after.")
		_scene(false)
	elif a == "c3" and int(s.step) == 2:
		_complete("c3", 0, 2, "Slept on a decision. It did not improve.")
		set_step("c4", 0)
		_m3_call()
	elif a == "c4wait" and int(s.day) >= int(s.mvars.get("m4_day", 0)):
		set_step("c5", 0)
		Game.add_message("'Oil' Kumar", "Kaveri Bar. After 8. Bring the ticket bag. Empty.")

func on_player_down() -> void:
	if s.active == "c4" and int(s.step) == 3:
		_m3_finish(false)
	_end_run(false)

# ------------------------------------------------------------------ objectives
func objective_text() -> String:
	var st := int(s.step)
	match str(s.active):
		"free": return "Free roam  -  Bangalore, 2002"
		"c1":
			if pl.ride != null: return ""
			if st == 1: return "Collect your things from the station writer and walk out"
			if st == 2: return "Kamakshi is waiting outside with the scooter"
			if st == 3: return "Go inside. You are home"
			if st == 4: return "Sleep"
			return ""
		"c2":
			if bus == null:
				return "Get to Depot No. 2, Kempegowda Bus Station (ask Kamakshi for a lift, or take a bus)" if st == 0 else "Report to Umashankar at Depot No. 2"
			var nxt: String = City.nodes[run_stops[mini(stop_i + 1, run_stops.size() - 1)]].name
			var unpaid := 0
			for p in pax:
				if not p.paid: unpaid += 1
			if bus.ai.hold and _incident_t < 0.0:
				return "At %s. Issue tickets, then signal RIGHT!  (%d without ticket)" % [City.nodes[run_stops[stop_i]].name, unpaid]
			return "Next: %s  -  %d without ticket.  Fares: 1 stage Rs 2, 2 Rs 3, 3 Rs 4, more Rs 5" % [nxt, unpaid]
		"c3":
			if st <= 1: return "The bag: Upparpet Police Station - or home, to Kamakshi"
			return "Go home and sleep on it"
		"c4":
			if st == 1: return "Find Umashankar (Nanjappa's stall at lunch, the depot otherwise)"
			if st == 2: return "Go to Thimmaiah's flower godown at K.R. Market before nine"
			if st == 3: return "Take the scooter and get out of the market"
		"c4wait": return "Lie low. Work a shift with Umashankar, go home, sleep"
		"c5":
			if st == 0: return "Meet 'Oil' Kumar inside Kaveri Bar after 8 PM"
			var left: Array = []
			for k in ["tailor", "cinema", "devaraj"]:
				if not s.mvars.get("done_" + k, false): left.append(City.PLACES[k].name)
			return "Deliver the packets: " + ", ".join(PackedStringArray(left))
		"end": return "Chapter One complete  -  the city is yours to explore"
	if bus != null:
		return "Morning trip: issue tickets, signal RIGHT!"
	return ""

func objective_pos():
	var st := int(s.step)
	match str(s.active):
		"c1":
			if st == 2 and world.interior == "": return place("police") + Vector3(1.3, 0, 2.6)
			if st >= 3: return place("home")
		"c2":
			if bus == null: return DEPOT
		"c3": return place("home") if (st == 2 or pl.global_position.distance_to(place("home")) < pl.global_position.distance_to(place("police"))) else place("police")
		"c4":
			if st == 1: return world.crowd.named_pos("uma")
			if st == 2: return place("godown")
		"c5":
			if st == 0: return place("bar")
			for k in ["tailor", "cinema", "devaraj"]:
				if not s.mvars.get("done_" + k, false): return place(k)
	return null

func hotspots() -> Array:
	var out: Array = []
	if bus != null and pl.bus == bus and _incident_t < 0.0:
		for i in pax.size():
			var p = pax[i]
			if not p.paid:
				out.append({"pos": bus.global_transform * _seat_pos(p.seat), "r": 1.25, "label": "TICKET", "key": "pax:%d" % i})
	if s.active == "c5" and int(s.step) == 1 and world.interior == "":
		for k in ["cinema", "devaraj"]:
			if not s.mvars.get("done_" + k, false):
				out.append({"pos": place(k), "r": 3.0, "label": "DELIVER", "key": "deliver:" + k})
	return out

func on_hotspot(key: String) -> void:
	if key.begins_with("pax:"):
		_ticket(int(key.substr(4)))
	elif key.begins_with("deliver:"):
		_m4_deliver(key.substr(8))

# ------------------------------------------------------------------ talking to people
func on_talk(n: NPC) -> bool:
	var a := str(s.active)
	var st := int(s.step)
	if a == "c1" and st == 1 and world.interior == "police":
		if await _c1_station_talk(n):
			return true
	match n.id:
		"uma":
			if await _uma(a, st):
				return true
		"kamakshi":
			return await _kamakshi(a, st, n)
		"pinto":
			if Game.flag("uma_loan") and not Game.flag("uma_settled"):
				await _pinto()
				return true
		"lokesh":
			if a == "c3" and st <= 1:
				await _m2_police()
				return true
		"tiger", "oilkumar":
			if a == "c4" and st == 2 and world.interior == "godown":
				await _m3_godown()
				return true
			if a == "c5" and st == 0 and n.id == "oilkumar":
				await _m4_brief()
				return true
		"rafiq":
			if a == "c5" and st == 1 and not s.mvars.get("done_tailor", false):
				await say("rafiq", "For me? From the market side? ...Keep it on the cutting table. No, don't tell me what it is.")
				_m4_mark("tailor")
				return true
		"shalini":
			if await _shalini():
				return true
		"meena":
			if a == "c4" and st == 2 and Game.flag("means_to_return") and not Game.flag("told_kamakshi_godown"):
				await say("meena", "You want the High Court advocates' room? One rupee. ...She's in court. I can leave word: 'Your husband has gone to K.R. Market flower godown, nine o'clock.' Shall I?")
				var c := await choose(["\"Leave word.\"", "\"No. Forget I asked.\""])
				if c == 0:
					Game.set_flag("told_kamakshi_godown")
					Game.add_rel("kamakshi", 6)
					await say("meena", "Done. She will not like the message. But she will like that there was one.")
				return true
	if n.story_tag == "victim":
		await hud.say(n.display_name(), "My chain! Two sovereigns! He went that way!")
		return true
	return await Shops.talk(world, n)

func on_enter(id: String) -> void:
	if id == "home" and s.active == "c1" and int(s.step) == 3:
		_c1_home()
	if id == "godown" and s.active == "c4" and int(s.step) == 2:
		hud.subtitle("The godown smells of jasmine and something older.", 3.0)

func on_leave(id: String) -> void:
	if id == "police" and s.active == "c1" and int(s.step) == 1:
		set_step("c1", 2)
		_wait_outside_station()
		s.time = 16.8

func on_interior(_id: String, _key: String) -> bool:
	return false

func interior_cast(id: String) -> Array:
	if id == "godown" and s.active == "c4":
		return ["tiger", "oilkumar"]
	if id == "police" and (s.active == "c3" or s.active == "c1"):
		return ["lokesh", "shivaramu"]
	if id == "bar" and s.active == "c5" and int(s.step) == 0 and (float(s.time) >= 20.0 or float(s.time) < 2.0):
		return ["oilkumar"]
	if id == "home" and (s.active == "c1" or (s.active == "c3" and int(s.step) <= 2)):
		return ["kamakshi"]
	return []

func interior_absent(id: String) -> Array:
	if id == "home" and s.active in ["c1", "c2"]:
		return []
	return []

func call_contact(id: String) -> void:
	_scene(true)
	Sfx.play("ring", 0.6)
	await world.wait(1.2)
	match id:
		"immu":
			await say("immu", "Raji! Where are you? Stay there, I'm coming. Meter down, friendship rate.")
			hud.end_talk()
			_scene(false)
			await Shops.auto_travel(world, "Immu's auto (called)")
			return
		"uma":
			await say("uma", ["Raji! I'm driving. I'm not supposed to pick up. I picked up. Tell fast.", "Girija says come for lunch Sunday. She says bring madam. She says don't bring anything. Bring something.", "I am fine. Why does everybody ask if I am fine. Did Girija tell you to call?"][int(s.day) % 3])
		"oilkumar":
			await say("oilkumar", "Don't call this number. This number calls you.")
		"shalini":
			await say("shalini", "Sanje Vaani, crime desk. If this is about Crime 214, I'm at the Upparpet station most afternoons.")
		_:
			await say("", "The number you are calling is not answering. Please try after some time.")
	_scene(false)

func _seat_pos(i: int) -> Vector3:
	var row := i / 2
	return Vector3(-0.82 if i % 2 == 0 else 0.82, 0.78, -3.3 + row * 0.95)

func _bus_interior(b: Vehicle) -> void:
	var mb := MB.new()
	var L: float = b.spec.l
	var W: float = b.spec.w
	var grey := Color(0.55, 0.57, 0.55)
	mb.flat(Vector3(0, 0.78, 0), W - 0.1, L - 0.2, Rect2(0, 0, 1, 1), Color(0.25, 0.25, 0.27))
	mb.quad(Vector3(-W / 2, 2.96, L / 2), Vector3(W / 2, 2.96, L / 2), Vector3(W / 2, 2.96, -L / 2), Vector3(-W / 2, 2.96, -L / 2), Vector3.DOWN, Rect2(0, 0, 1, 1), Color(0.85, 0.83, 0.75))
	for sd: float in [-1.0, 1.0]:
		mb.wall(Vector3(sd * (W / 2 - 0.04), 0.78, 0), Vector3(-sd, 0, 0), L - 0.2, 1.0, Rect2(0, 0, 1, 1), grey)
		mb.wall(Vector3(sd * (W / 2 - 0.04), 2.54, 0), Vector3(-sd, 0, 0), L - 0.2, 0.42, Rect2(0, 0, 1, 1), grey.lightened(0.2))
		mb.box(Vector3(sd * 0.36, 2.72, 0), Vector3(0.035, 0.035, L - 1.2), Color(0.75, 0.75, 0.78))     # grab rails
	mb.wall(Vector3(0, 0.78, L / 2 - 0.06), Vector3(0, 0, -1), W - 0.1, 2.2, Rect2(0, 0, 1, 1), grey)
	mb.wall(Vector3(0.5, 0.78, -L / 2 + 1.5), Vector3(0, 0, 1), W * 0.5, 1.1, Rect2(0, 0, 1, 1), grey.darkened(0.2))   # driver partition
	for i in 16:
		var sp := _seat_pos(i)
		mb.box(sp + Vector3(0, 0.42, 0.12), Vector3(0.78, 0.1, 0.5), Color(0.25, 0.4, 0.3))
		mb.box(sp + Vector3(0, 0.75, 0.4), Vector3(0.78, 0.6, 0.07), Color(0.22, 0.36, 0.27))
	var mesh := ArrayMesh.new()
	mb.add_to(mesh, Mats.vcol())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	b.add_child(mi)
	var lt := OmniLight3D.new()
	lt.position = Vector3(0, 2.6, 0)
	lt.light_color = Color(0.85, 0.95, 1.0)
	lt.light_energy = 0.9
	lt.omni_range = 6.5
	b.add_child(lt)
	var drv := Human.make(People.look_of("uma"))
	b.add_child(drv)
	drv.position = Vector3(0.55, 0.78, -L / 2 + 0.9)
	drv.state = "drive"
	var lb := Label3D.new()
	lb.text = "27E   MAJESTIC - ULSOOR"
	lb.font_size = 44
	lb.pixel_size = 0.004
	lb.modulate = Color(1, 0.9, 0.2)
	lb.position = Vector3(0, 2.82, -L / 2 - 0.06)
	lb.rotation.y = PI
	b.add_child(lb)

func _start_run(night: bool) -> void:
	_scene(true)
	await hud.fade(1.0, 0.7)
	_run_night = night
	run_stops = ROUTE.duplicate()
	if night:
		run_stops.reverse()
		s.time = 21.6
	stop_i = 0
	_collected = 0
	_mistakes = 0
	_incident_t = -1.0
	if s.active == "c2":
		set_step("c2", 2)
	world.crowd.unpin("uma")
	var bn: NPC = world.crowd.node_of("uma")
	if bn != null:
		world.crowd.remove(bn)
	world.crowd.named["uma"].pin = {"pos": Vector3(0, 0, -5000), "yaw": 0.0, "sit": false, "mode": "pin"}   # he is driving
	world.crowd.named["uma"].pos = Vector2(0, -5000)
	bus = world.traffic.spawn_route("bus", run_stops, 0)
	bus.ai.hold = true
	_bus_interior(bus)
	if night:
		# warp the world to the far terminus first
		var st: Vector2 = City.stops["ulsoor"].pos
		pl.global_position = Vector3(st.x, 0, st.y)
		world._want_chunks(true)
	pax.clear()
	_board(3 if night else 4)
	pl.board_bus(bus, Vector3(0, 0.78, -2.0))
	pl.yaw = bus.rotation.y + PI
	hud.set_mode("bus")
	clock_runs = true
	await hud.fade(0.0, 0.7)
	_scene(false)
	world.busy = true      # the route owns the player until it ends
	pl.locked = false
	hud.card("ROUTE 27E", "Last trip. 9:40 PM, Ulsoor." if night else "Majestic  -  Ulsoor")
	hud.toast("Walk the aisle. TICKET each passenger, then shout RIGHT! to move.")

func _board(n: int) -> void:
	var free: Array = []
	for i in 16:
		var used := false
		for p in pax:
			if p.seat == i: used = true
		if not used: free.append(i)
	free.shuffle()
	var rng: RandomNumberGenerator = world.crowd.rng
	for k in mini(n, free.size()):
		if stop_i >= run_stops.size() - 1:
			break
		var ident := People.random_identity(rng, "com")
		var h := Human.make(Human.random_look(rng, ident.sex))
		bus.add_child(h)
		h.position = _seat_pos(free[k])
		h.state = "sit"
		pax.append({"h": h, "seat": free[k], "dest": rng.randi_range(stop_i + 1, run_stops.size() - 1), "paid": false, "name": ident.name, "tag": ""})

func _on_bus_arrived(veh: Vehicle, node: String) -> void:
	if veh != bus:
		return
	stop_i = run_stops.find(node)
	bus.ai.hold = true
	Sfx.play("bell", 0.7)
	var escaped := 0
	for p in pax.duplicate():
		if p.dest <= stop_i and p.tag == "":
			if not p.paid:
				escaped += 1
			p.h.queue_free()
			pax.erase(p)
	if escaped > 0:
		_mistakes += escaped
		hud.toast("%d got down without a ticket. That comes out of your pay." % escaped)
	if stop_i >= run_stops.size() - 1:
		_end_run(true)
		return
	_board(world.crowd.rng.randi_range(2, 4) if not _run_night else world.crowd.rng.randi_range(0, 1))
	if _run_night and node == "shivajinagar":
		var h := Human.make({"sex": 0, "skin": 2, "face": 1, "hair": 3, "hair_col": 1, "beard": 1, "top": 1, "top_col": 0, "bottom": 0, "bot_col": 12, "glasses": 1, "build": 0.75, "acc": 0, "watch": 1, "shoes": 1})
		bus.add_child(h)
		h.position = _seat_pos(15)
		h.state = "sit"
		pax.append({"h": h, "seat": 15, "dest": 5, "paid": false, "name": "Nervous passenger", "tag": "subbu"})
		_make_bag(_seat_pos(15) + Vector3(-0.45, 0.2, 0.1))
		hud.subtitle("A man gets on at the back. Rexine bag held like a baby.", 3.5)

func _make_bag(local: Vector3) -> void:
	_bag = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.32, 0.26)
	bm.material = Mats.col(Color(0.28, 0.16, 0.1), 0.5)
	_bag.mesh = bm
	bus.add_child(_bag)
	_bag.position = local

func bus_signal(kind: String) -> void:
	if bus == null:
		return
	if kind == "bell":
		Sfx.play("bell", 0.9)
		return
	Sfx.play("whistle", 0.9)
	pl.human.play_once("whistle", 0.8)
	if bus.ai.hold and _incident_t < 0.0 and stop_i < run_stops.size() - 1:
		hud.subtitle("%s: RIGHT! RIGHT!" % str(s.name), 1.5)
		bus.ai.hold = false
		if _run_night and run_stops[stop_i] == "vidhana" and s.active == "c2":
			_incident_t = 7.0

func _ticket(i: int) -> void:
	if i >= pax.size():
		return
	var p = pax[i]
	var was_locked := pl.locked
	pl.locked = true
	pl.human.play_once("give", 0.6)
	var stages: int = p.dest - stop_i
	var dest_name: String = City.nodes[run_stops[p.dest]].name
	if p.tag == "subbu":
		await hud.say(p.name, "M-Majestic. One. Quickly.")
		await hud.say(p.name, "(He pushes a hundred-rupee note at you. His hand is wet.)  Keep it. Keep the change. Just... is this bus direct?")
		var c := await choose(["Count out ninety-five rupees change, properly.", "\"Keep the change\" - you heard the man.", "\"Saar, are you all right?\""])
		if c == 1:
			Game.set_flag("kept_change")
			Game.add_money(95, "'keep the change'")
		elif c == 2:
			await hud.say(p.name, "All right? Yes. Fine. Everybody is fine. Go, go, attend to others.")
		p.paid = true
		_collected += 5
		s.stats.tickets = int(s.stats.tickets) + 1
	else:
		await hud.say(p.name, "One %s." % dest_name)
		var c2 := await choose(["Rs 2", "Rs 3", "Rs 4", "Rs 5"])
		var right := clampi(stages, 1, 4) - 1
		var fare: int = [2, 3, 4, 5][c2]
		p.paid = true
		_collected += fare
		s.stats.tickets = int(s.stats.tickets) + 1
		Sfx.play("coin", 0.6)
		if c2 > right:
			_mistakes += 1
			await hud.say(p.name, ["Ey, it was cheaper yesterday! Daylight robbery in khaki.", "Rs %d? For this? I could have bought the bus." % fare][world.crowd.rng.randi() % 2])
		elif c2 < right:
			_mistakes += 1
			hud.toast("Undercharged. The shortage is yours.")
	hud.end_talk()
	pl.locked = was_locked

func _end_run(reached: bool) -> void:
	if bus == null:
		return
	var was_m1: bool = s.active == "c2"
	var night := _run_night
	clock_runs = false
	_cam_fn = Callable()
	if not reached:
		pl.leave_bus(pl.global_position)
		_clear_bus()
		world.busy = false
		hud.set_mode("foot")
		return
	_scene(true)
	await hud.fade(1.0, 0.8)
	var wage := maxi(20, 60 + int(_collected * 0.5) - _mistakes * 6)
	var term: String = run_stops[run_stops.size() - 1]
	var st: Vector2 = City.stops[term].pos
	pl.leave_bus(Vector3(st.x, 0, st.y) if not (was_m1 and night) else DEPOT + Vector3(2.5, 0, 1.0))
	_clear_bus()
	hud.set_mode("foot")
	world._want_chunks(true)
	if was_m1 and not night:
		# the day's other trips pass in a cut; the last trip is the one that matters
		await hud.fade(0.0, 0.5)
		hud.card("FOURTEEN HOURS LATER", "The last trip. Ulsoor, 9:40 PM.")
		await world.wait(2.6)
		_mistakes_carry = _mistakes
		_collect_carry = _collected
		await _start_run(true)
		return
	if was_m1:
		await _m1_after(wage)
		return
	Game.add_money(wage, "shift wages (collection Rs %d, %d mistakes)" % [_collected, _mistakes])
	world.crowd.unpin("uma")
	_scene(false)
	await hud.fade(0.0, 0.8)
	hud.toast("Shift over at %s." % City.nodes[term].name)
	Game.save_game(false)

var _mistakes_carry := 0
var _collect_carry := 0

func _clear_bus() -> void:
	for p in pax:
		if is_instance_valid(p.h):
			p.h.queue_free()
	pax.clear()
	if bus != null and is_instance_valid(bus):
		world.traffic.despawn(bus)
	bus = null
	_bag = null

func _process(delta: float) -> void:
	if _cam_fn.is_valid():
		_cam_fn.call()
	if not _ride.is_empty() and not get_tree().paused:
		_ride_tick(delta)
	if _incident_t > 0.0 and bus != null:
		_incident_t -= delta
		if _incident_t <= 0.0:
			_incident_t = 0.0
			_m1_incident()
	if s.active == "c4" and int(s.step) == 3 and not world.busy:
		var far: bool = pl.global_position.distance_to(place("godown")) > 170.0
		var alive := 0
		for n in world.crowd.actors("raid"):
			if n.mode == "hostile": alive += 1
		if far or alive == 0:
			_m3_finish(true)
	if s.active == "c5" and int(s.step) == 1 and not _check_done and not world.busy and world.interior == "":
		if pl.global_position.distance_to(place("devaraj")) < 45.0 and not s.mvars.get("done_devaraj", false):
			_check_done = true
			_m4_checkpoint()
	if _thief != null:
		_thief_t -= delta
		if not is_instance_valid(_thief) or _thief_t <= 0.0:
			_thief = null
			world.crowd.clear_actors("victim")
	_rally(delta)

# ------------------------------------------------------------------ M1: the incident (cinematic)
func _cam_bus(local: Vector3, look_local: Vector3) -> void:
	_cam_fn = func():
		if bus != null and is_instance_valid(bus):
			pl.cam.global_position = bus.global_transform * local
			pl.cam.look_at(bus.global_transform * look_local, Vector3.UP)

func _m1_incident() -> void:
	var subbu = null
	for p in pax:
		if p.tag == "subbu": subbu = p
	if subbu == null:
		_incident_t = -1.0
		return
	_scene(true, true)
	pl.cam_override = true
	# two men on a motorcycle draw level with the bus
	var bike := Vehicle.create("bike", 7, false)
	bus.add_child(bike)
	bike.position = Vector3(2.3, 0, 6.0)
	var g1 := Human.make(Human.random_look(world.crowd.rng, 0, "goon"))
	var g2 := Human.make(Human.random_look(world.crowd.rng, 0, "goon"))
	bike.add_child(g1)
	g1.position = bike.seat_pos()
	g1.state = "drive"
	bike.add_child(g2)
	g2.position = bike.seat_pos() + Vector3(0, 0.05, 0.55)
	g2.state = "sit"
	var tw := bike.create_tween()
	tw.tween_property(bike, "position:z", -1.0, 3.0)
	_cam_bus(Vector3(5.5, 2.2, -6.5), Vector3(0.5, 1.6, 1.0))
	Sfx.play("horn_auto", 0.8)
	await world.wait(1.6)
	await hud.say("Man on the motorcycle", "EY! DRIVER! Nillso! Stop the bus!")
	_cam_bus(Vector3(0.1, 2.3, 0.2), Vector3(0.6, 1.9, 4.3))
	subbu.h.state = "idle"
	subbu.h.position = Vector3(0.15, 0.78, 4.0)
	await hud.say(subbu.name, "Don't stop! Driver, for God's sake, DON'T STOP!")
	if _bag != null:
		_bag.position = _seat_pos(15) + Vector3(0, -0.3, 0.25)     # shoved under the seat
	await hud.say("", "He shoves the bag under the last seat, looks once at you - only at you - and runs for the rear door.")
	hud.end_talk()
	# SLOW MOTION: the leap
	var h: Human = subbu.h
	var start: Vector3 = bus.global_transform * Vector3(-1.3, 0.9, 3.4)
	var side: Vector3 = -bus.global_transform.basis.x
	bus.remove_child(h)
	world.add_child(h)
	h.global_position = start
	h.rotation.y = bus.rotation.y + PI * 0.5
	h.state = "air"
	pax.erase(subbu)
	_cam_bus(Vector3(-5.0, 1.4, 7.5), Vector3(-1.6, 1.6, 3.2))
	world.slowmo(0.22, true)
	Sfx.play("whoosh", 0.8, 0.6)
	var t := 0.0
	while t < 1.0:
		await get_tree().process_frame
		t += get_process_delta_time() * 1.15
		if not is_instance_valid(h):
			break
		h.global_position = start + side * (3.2 * t) + Vector3(0, 0.9 * sin(t * PI) - 0.9 * t, 0) - (-bus.global_transform.basis.z) * (2.5 * t)
	h.state = "ko"
	world.slowmo(1.0, false)
	Sfx.play("screech", 0.9)
	bus.ai.hold = true
	h.create_tween().tween_callback(h.queue_free).set_delay(6.0)
	# SLOW MOTION: the bag slides down the aisle to your feet
	await world.wait(0.5)
	world.slowmo(0.3, true)
	if _bag != null:
		_bag.position = Vector3(0, 0.95, 3.9)
		var bt := _bag.create_tween()
		bt.tween_property(_bag, "position:z", pl.bus_local.z + 0.45, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pl.human.rotation.y = bus.rotation.y + PI
	_cam_bus(Vector3(0.0, 1.2, pl.bus_local.z + 2.2), Vector3(0, 1.0, pl.bus_local.z + 0.3))
	await world.wait(1.4)
	_cam_bus(pl.bus_local + Vector3(0.25, 1.62, 1.25), pl.bus_local + Vector3(0, 1.6, 0))     # close-up
	await world.wait(1.6)
	world.slowmo(1.0, false)
	await hud.say("", "A rexine bag. Heavy. It has stopped exactly at your chappals, like a dog that has chosen its owner.")
	# the men board
	bike.queue_free()
	var a1 := Human.make(g1.look)
	var a2 := Human.make(g2.look)
	for pair in [[a1, Vector3(0.0, 0.78, pl.bus_local.z - 1.5)], [a2, Vector3(0.2, 0.78, pl.bus_local.z - 2.4)]]:
		bus.add_child(pair[0])
		pair[0].position = pair[1]
		pair[0].rotation.y = PI
	pl.human.rotation.y = bus.rotation.y
	_cam_bus(pl.bus_local + Vector3(0.9, 1.9, 1.6), pl.bus_local + Vector3(0, 1.5, -1.6))
	a1.talk_t = 3.0
	await hud.say("Man in the printed shirt", "Conductor. A fellow got on with a bag. Fat fellow, spectacles. Where?")
	var c := await choose(["\"Ticket, ticket! Where to, saar? Two rupees minimum.\"  (play the fool)", "Stand over the bag. Say nothing.", "\"Take it. Whatever it is, I don't want it.\""])
	if c == 0:
		Game.set_flag("m1_choice", "fool")
		await hud.say("Man in the printed shirt", "...Is he mad or is he brave?")
		await hud.say("The other one", "He's a conductor, guru. Same thing. Check the back.")
		await hud.say("", "They tear through the last three rows. The bag sits between your feet, wearing your shadow.")
		Game.add_rep(2)
	elif c == 1:
		Game.set_flag("m1_choice", "silent")
		a1.play_once("punch", 0.3)
		Sfx.play("punch", 0.9)
		pl.human.play_once("hit", 0.4)
		s.hp = maxf(20.0, float(s.hp) - 15.0)
		await hud.say("Man in the printed shirt", "Dumb, is it? This is for wasting my time. We know this bus. We know this route.")
		Game.add_rep(1)
	else:
		Game.set_flag("m1_choice", "gave")
		await hud.say("", "You hold out a bag. Your hands pick the wrong one: a passenger's tiffin carrier, three steel boxes, still warm.")
		await hud.say("Man in the printed shirt", "Good boy. See, Seena? Cooperation.")
		await hud.say("", "They will open it at the next signal. They will find curd rice. They will remember your face.")
		Game.add_faction("tiger", -10)
	await hud.say("The other one", "27E. Badge four-four-seven-one. We'll meet again, conductor.")
	a1.queue_free()
	a2.queue_free()
	Sfx.play("eng_bike", 0.7)
	await hud.say("uma", "RAJI! What was that? Eleven years! Eleven years nobody has jumped off my bus! Are you hurt? Say something!")
	pl.cam_override = false
	_cam_fn = Callable()
	_scene(false)
	world.busy = true
	_incident_t = -1.0
	stop_i = run_stops.find("vidhana")
	bus.ai.hold = false
	hud.toast("The bag is at your feet. Majestic is two stops away.")

func _m1_after(wage: int) -> void:
	world.crowd.pin("uma", DEPOT, -PI * 0.5)
	s.time = 22.4
	await hud.fade(0.0, 1.0)
	await say("uma", "Depot. Engine off. Now. What is in that bag you think I didn't see?")
	var c := await choose(["\"I haven't opened it. I swear on Amma.\"", "\"Nothing. Lost property. I'll hand it in tomorrow.\""])
	if c == 0:
		Game.add_rel("uma", 6)
		await say("uma", "Then open it where I can't see, so when they ask me I can cry honestly. Raji - you are on bail. You cannot even find a coin on the road now. You know that?")
	else:
		Game.add_rel("uma", -4)
		Game.remember("uma", "lied")
		await say("uma", "Eleven years. I know your lying face. It's the same as your acidity face. Fine. Don't tell me. But tell HER. Don't be clever with a lawyer.")
	var total := wage + maxi(0, 30 - _mistakes_carry * 6)
	Game.add_money(total, "day's wages")
	_complete("c2", 0, 3, "First day back. A man jumped off the last bus and left his bag behind.")
	set_step("c3", 0)
	_scene(false)
	await world.wait(1.0)
	_m2_open()

# ------------------------------------------------------------------ C3: Eighteen Lakhs
func _m2_open() -> void:
	_scene(true, true)
	await say("", "Behind the depot office, under the one tube-light that works, you open the zip.")
	await say("", "Bundles. Five-hundreds, bank-banded. You count the bands twice, then a third time because the number is stupid.")
	await say("raji", "Eighteen... lakhs.")
	await say("", "Your salary is three thousand four hundred a month. This is forty-four years of whistling. And you are a man on bail.")
	await say("", "Under the money: a ledger, every page filled with film-song titles and numbers. And a mobile phone. It is switched on.")
	s.phone = true
	Game.add_contact("immu")
	Game.add_contact("uma")
	Game.add_message("48 missed calls", "ANNA IS ASKING. PICK UP SUBBU. - K")
	Sfx.play("sms")
	hud.toast("You now carry a mobile phone (TEL button).")
	set_step("c3", 1)
	_scene(false)

func _m2_police() -> void:
	await say("lokesh", "The under-trial. Back so soon. Missed our tea?")
	var c := await choose(["Put the bag on his desk. \"Found on my bus, saar. Lost property.\"", "\"Nothing, saar. Wrong building.\"  (leave)"])
	if c == 1:
		await say("lokesh", "Then don't waste government tube-light.")
		return
	await say("", "He unzips it. For four seconds S.I. Lokesh is the most honest-looking man in Bangalore.")
	await say("lokesh", "A man on bail walks into my station at midnight carrying eighteen lakhs. Do you know how many sections that is? I can't even count, and I am good at counting.")
	await say("lokesh", "...But you came yourself. So. This is 'evidence'. I will personally keep it in safe custody. Receipt? Here.")
	await say("", "He writes \"1 bag recd.\" on the back of a cigarette packet and signs it with somebody else's name.")
	await say("lokesh", "For your honesty. Five hundred. And conductor - you never came here. Tell your wife also that you never came here.")
	Game.add_money(500, "'reward'")
	Game.set_flag("bag", "police")
	Game.add_faction("police", 8)
	Game.add_faction("devaraj", 10)
	Game.add_faction("tiger", -15)
	Game.add_rel("kamakshi", -6)
	Game.log_event("Handed eighteen lakhs to the same S.I. who locked you up. Got a cigarette packet.")
	await say("", "As you leave he is already dialling. You catch two words through the door: \"Devaraj saar.\"")
	set_step("c3", 2)

func _m2_home() -> void:
	_scene(true)
	await say("", "You try to get the bag under the cot quietly. In eleven years you have never done anything quietly in this house.")
	await say("kamakshi", "Rajini. What is that?")
	var c := await choose(["Tell her. The jump, the bag, the phone. Unzip it.", "\"Depot cash. Conductor's collection. Don't touch.\"", "\"Lost property. I'm handing it in tomorrow.\""])
	if c == 0:
		Game.set_flag("kamakshi_knows")
		await say("kamakshi", "(She looks at the money for a long time. Then at the ledger. Then at you.)")
		await say("kamakshi", "This is proceeds of crime or it is stolen property. Either way it is Section 411 with your name on it, and you are on bail for nine more weeks. If Lokesh finds this in my house, I cannot even stand for you. I'd be an accused.")
		var c2 := await choose(["\"Then you decide. You're the lawyer.\"", "\"Nobody knows. We keep it. One time in our life, Kamu.\"", "\"I'll take it back to whoever owns it.\""])
		if c2 == 0:
			Game.set_flag("bag", "court")
			Game.add_rel("kamakshi", 10)
			Game.add_faction("tiger", -20)
			await say("kamakshi", "Tomorrow, 10:30, I produce it before the Magistrate in a sealed cover with a memo: 'found property, finder's wife is an officer of the court'. It will be the most honest thing that money has ever experienced.")
			await say("kamakshi", "Whoever lost it will be very angry. But they will have to be angry in a courtroom, and that is my house.")
			Game.log_event("Kamakshi will deposit the bag with the Magistrate.")
		elif c2 == 1:
			Game.set_flag("bag", "home")
			Game.add_rel("kamakshi", -10)
			await say("kamakshi", "'One time in our life.' Every client I have ever defended has said that sentence to me. Every one. Put it under the cot. I did not see it. And Rajini - I am very, very tired of not seeing things for you.")
			Game.log_event("Hid the bag under the cot. Kamakshi did not see it. She said so twice.")
		else:
			Game.set_flag("bag", "home")
			Game.set_flag("means_to_return")
			Game.add_rel("kamakshi", 3)
			await say("kamakshi", "To people who chase buses on motorcycles. You. (She rubs her eyes.) Fine. One night it stays. If they call, you tell me before you go anywhere. Promise.")
			Game.log_event("Hid the bag for one night. Promised Kamakshi to tell her before going anywhere.")
	else:
		Game.set_flag("bag", "home")
		Game.remember("kamakshi", "lied_bag")
		Game.add_rel("kamakshi", -5)
		await say("kamakshi", "Hm. You're looking at the floor. (She goes back to her file.) I have a matter at eleven. We will discuss the floor tomorrow.")
		Game.log_event("Hid the bag under the cot and lied to a lawyer about it.")
	set_step("c3", 2)
	_scene(false)
	hud.toast("Sleep (the cot) to end this long day.")

# ------------------------------------------------------------------ C4: Wrong Number
func _m3_call() -> void:
	_scene(true, true)
	Sfx.play("ring", 0.9)
	await world.wait(1.6)
	Sfx.play("ring", 0.9)
	await world.wait(1.4)
	await say("", "The dead man's phone is ringing. It is 6 AM. Kamakshi's side of the cot is already empty; you can hear the pressure cooker.")
	await say("phone", "Subbu. Finally. Anna has not slept. I have not slept. Where is it?")
	await say("raji", "This is... not Subbu.")
	await say("phone", "...")
	await say("phone", "Conductor. Four-four-seven-one. The bail fellow. Good, saves me petrol. Listen carefully, I say things once.")
	if str(Game.flag("bag")) == "police":
		await say("phone", "We know you walked into Upparpet with it. We know whose pocket it went into, and whose pocket after that. Anna wants to hear this comedy from your own mouth.")
	elif str(Game.flag("bag")) == "court":
		await say("phone", "Your wife is carrying Anna's money to a Magistrate this morning in a sealed cover. A SEALED COVER. Anna laughed for one full minute. Then he stopped. Come and explain.")
	else:
		await say("phone", "You have a bag that belongs to S.T. Thimmaiah. Bring it. All of it. Anna likes round numbers.")
	await say("phone", "Flower godown, K.R. Market, behind the main building. Before nine tonight. Come alone. Come by bus if you like, ha.")
	Game.set_flag("oil_known")
	Game.add_contact("oilkumar")
	Game.discover("godown")
	set_step("c4", 1)
	_scene(false)
	hud.toast("Umashankar takes his tea at Nanjappa's around one, or find him at the depot.")

func on_cinema() -> bool:
	if not Game.flag("date_on"):
		return false
	_scene(true)
	if not Shops.eat(world, "two balcony tickets + samosa", 36, 10.0):
		await say("kamakshi", "You brought me to the balcony queue without balcony money. Rajinikanth. I will pay. You will hear about it till Ugadi.")
		Game.add_rel("kamakshi", -2)
	await hud.fade(1.0, 0.8)
	world.pass_time(3.0)
	await hud.fade(0.0, 0.8)
	await say("kamakshi", "He jumped from a helicopter onto a moving train and his hair didn't move. I want that barber.")
	await say("kamakshi", "Can I ask you something? In the film the hero is never afraid. You are afraid of everything - dogs, inspectors, my mother. And you still told that boy on the bus to behave. Why?")
	var c := await choose(["\"I was more afraid of what I'd be if I didn't.\"", "\"It came out before I could stop it.\"", "\"Because you'd have asked me why I didn't.\""])
	if c == 0:
		Game.add_rel("kamakshi", 10)
		await say("kamakshi", "...That's the best answer you have given me since 1991. Don't spoil it by talking more.")
	elif c == 1:
		Game.add_rel("kamakshi", 6)
		await say("kamakshi", "That's you exactly. A coward with a faulty brake. (She takes your arm.) I'd rather that than the other kind.")
	else:
		Game.add_rel("kamakshi", 12)
		await say("kamakshi", "So you are more afraid of me than of Devaraj. Good. Keep it that way and we may survive this.")
	Game.set_flag("date_on", false)
	Game.log_event("Took Kamakshi to the evening show at Sangam Talkies.")
	_scene(false)
	await ride_with(place("home") + Vector3(1.5, 0, 0.8), [["r", "You're smiling."], ["k", "I am concentrating on the road."], ["r", "You're smiling at the road."], ["k", "Sit quietly, Rajini."]])
	return true

func _m3_godown() -> void:
	_scene(true, true)
	var bag: String = str(Game.flag("bag"))
	await say("oilkumar", "Anna. The conductor. The bail one.")
	await say("tiger", "Sit. Kumar, coffee for him. In my godown even enemies get coffee first.")
	await say("tiger", "Subbu kept my accounts eleven years. Yesterday he ran with eighteen lakhs and died of fright in a pay-toilet near Shivajinagar. Heart. All that planning.")
	await say("tiger", "It was not my money, conductor. That is the joke. It was Devaraj's. His 'donation' to Channanna's election, sent through my flowers so that nobody's hands smell. Subbu was Devaraj's man in my shop. I found that out the same day you found the bag.")
	if bag == "police":
		await say("tiger", "And you carried it - on foot - to Lokesh. Who eats from Devaraj's plate. You returned Devaraj's money to Devaraj and he doesn't even have to say thank you. Nobody has done something so stupid and so clean in front of me in forty years.")
	elif bag == "court":
		await say("tiger", "And your wife has put it in front of a Magistrate. Do you know what that makes me? I cannot claim it. Devaraj cannot claim it. Channanna cannot even look at it. Eighteen lakhs that nobody in Bangalore is allowed to own. (He starts laughing again.) I want to meet this woman.")
		Game.add_faction("tiger", 12)
	else:
		await say("tiger", "And you kept it under a cot in Malleshwaram. No bank, no cousin, no running away to Bombay. And you brought it here in a ticket bag, on bail, with your knees shaking. I can see them from here.")
	await say("raji", "Saar. I am a conductor. I was in the lock-up nine days for something that boy Vicky did. I only want it to stop.")
	await say("tiger", "Vicky. So Devaraj has put his thumb on you also. (He looks at Kumar.) See how God arranges things.")
	await say("tiger", "A conductor's bag. Nobody checks it. Police salute it. It goes through every lane in this city by timetable. Carry small things for me. Envelopes. Five hundred a trip. And when the time comes, we will talk about Devaraj's nephew.")
	var c := await choose(["\"...Five hundred a trip?\"  (accept)", "\"I only issue tickets, saar. My wife will kill me before you can.\"  (refuse)"])
	if c == 0:
		Game.set_flag("works_for_tiger")
		Game.add_faction("tiger", 15)
		await say("tiger", "Good. Kumar will call. And conductor - you were never here. You only smell of flowers.")
	else:
		Game.add_faction("tiger", -5)
		await say("tiger", "Afraid of the wife. An honest answer. Go. But in this city a refusal is also a kind of debt.")
	hud.end_talk()
	# the raid: SLOW MOTION as the shutters come in
	Sfx.play("crash", 1.0)
	Sfx.play("shutter", 1.0)
	world.slowmo(0.25, true)
	_petals()
	pl.cam_override = true
	var origin: Vector3 = pl.global_position
	pl.cam.global_position = origin + Vector3(-2.5, 1.0, 2.5)
	pl.cam.look_at(origin + Vector3(1.5, 1.4, -2.0), Vector3.UP)
	await world.wait(2.2)
	pl.human.emotion = -1.0
	pl.cam.global_position = origin + Vector3(0.6, 1.6, -1.2)
	pl.cam.look_at(origin + Vector3(0, 1.55, 0), Vector3.UP)
	await world.wait(1.4)
	world.slowmo(1.0, false)
	await say("oilkumar", "DEVARAJ'S FINANCE BOYS! Anna, back room! Conductor - side door, my nephew's scooter is outside. RUN!")
	pl.cam_override = false
	pl.human.emotion = 0.0
	_scene(false)
	Game.add_faction("devaraj", -5)
	world.leave_interior()
	var gp := place("godown")
	var sc: Vehicle = world.traffic.add_owned("scooter", 2, gp + Vector3(3.5, 0, 0.5), 0.0)
	sc.rotation.y = PI * 0.5
	var n_bad := 2 if Game.flag("uma_came") else 3
	for i in n_bad:
		var n: NPC = world.crowd.spawn_actor(Human.random_look(world.crowd.rng, 0, "goon"), {"name": "Finance collector", "job": "goon"}, gp + Vector3(-9.0 - i * 2.0, 0, 3.0 + i * 1.5), "raid")
		n.mode = "hostile"
		n.hp = 36.0
	if Game.flag("uma_came"):
		world.crowd.pin("uma", gp + Vector3(-6.0, 0, 5.0), 0.0)
		var un: NPC = world.crowd.ensure("uma")
		if un != null:
			un.say_bubble("RAJI! GO! I'll sit on this one!", 4.0)
		hud.subtitle("Umashankar: RAJI! GO! I'll sit on this one!", 4.0)
	set_step("c4", 3)
	hud.toast("Fear is fuel. RIDE the scooter out of the market - or stand and fight (HIT).")

func _petals() -> void:
	var p := CPUParticles3D.new()
	p.amount = 160
	p.lifetime = 2.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(3, 0.5, 2)
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -4, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.65, 0.1)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.mesh = q
	world.add_child(p)
	p.global_position = pl.global_position + Vector3(0, 1.0, -2.5)
	p.emitting = true
	p.create_tween().tween_callback(p.queue_free).set_delay(6.0)

func _on_npc_down(n: NPC) -> void:
	if n.story_tag == "raid":
		Game.add_rep(2)
		Game.add_faction("soda", -4)
	if n == _thief:
		_thief = null
		Game.add_rep(3)
		Game.add_money(50, "a grateful stranger")
		Game.set_flag("caught_thief")
		Game.log_event("Stopped a chain-snatcher. The victim blessed three generations.")
		hud.subtitle("Bystander: The conductor got him! Hodi maga!", 3.0)

func _m3_finish(escaped: bool) -> void:
	world.crowd.clear_actors("raid")
	world.crowd.unpin("uma")
	if escaped:
		_complete("c4", 0, 5, "Walked out of Thimmaiah's godown alive. Your hands shook for an hour.")
		Game.add_message("'Oil' Kumar", "Anna says keep the scooter. The nephew is in no condition to ride. Rest two days. Then we talk.")
		if Game.flag("uma_came"):
			Game.add_message("Umashankar", "i am ok. one tooth is loose but it was a bad tooth. dont tell girija. dont tell madam. - uma")
			Game.add_rel("uma", 6)
	else:
		s.missions["c4"] = "done"
		Game.log_event("Wrong Number: woke up in a ward with marigold in your hair.")
	if Game.flag("means_to_return") and not Game.flag("told_kamakshi_godown"):
		Game.add_rel("kamakshi", -8)
		Game.add_message("Kamakshi", "You promised to tell me before you went anywhere. I heard it from Meenakshi at the booth. We will talk when you are home. Eat first.")
	s.mvars["m4_day"] = int(s.day) + 1
	set_step("c4wait", 0)
	Game.save_game(false)

# ------------------------------------------------------------------ C5: The Conductor's Bag
func _m4_brief() -> void:
	await say("oilkumar", "Sit. Don't order, you're working.")
	await say("oilkumar", "Three packets. One for the tailor near Nanjappa's. One for the manager's cabin at Sangam Talkies. One for the office of Sri Devaraj Enterprises. Tonight.")
	await say("raji", "Devaraj. You want me - me - to walk into Devaraj's office.")
	await say("oilkumar", "Anna is returning something of his. With a message. You are the message. A man he put in the lock-up, walking in free with a ticket bag. Anna enjoys that kind of thing.")
	if not Game.flag("works_for_tiger"):
		await say("oilkumar", "Yes, you refused. Anna heard. Anna has decided you didn't mean it.")
	s.mvars["done_tailor"] = false
	s.mvars["done_cinema"] = false
	s.mvars["done_devaraj"] = false
	_check_done = false
	Game.discover("cinema")
	Game.discover("devaraj")
	Game.discover("tailor")
	set_step("c5", 1)

func _m4_mark(k: String) -> void:
	s.mvars["done_" + k] = true
	Sfx.play("coin", 0.5)
	hud.toast("Packet delivered.")
	Game.changed.emit()
	if s.mvars.get("done_tailor", false) and s.mvars.get("done_cinema", false) and s.mvars.get("done_devaraj", false):
		_complete("c5", 1500, 6, "Three envelopes, one evening, and tea with the man who jailed you.")
		set_step("end", 0)
		hud.card("END OF CHAPTER ONE", "The city remembers you now.", 5.0)

func _m4_deliver(k: String) -> void:
	_scene(true)
	if k == "cinema":
		await say("", "The manager takes the packet without looking up from his collection register. \"Tell Thimmaiah the balcony is his on Friday.\"")
		_scene(false)
		_m4_mark(k)
		return
	world.crowd.pin("devaraj", place("devaraj") + Vector3(0.6, 0, -0.4), 0.0)
	world.crowd.ensure("devaraj")
	await say("", "Sri Devaraj Enterprises. A Ganesha with a red bulb. Calendars from four banks. A clerk who does not ask your name because he already knows it.")
	await say("devaraj", "Rajinikanth. Come, come. Sit. No - sit. In this office only people who owe me stand, and you don't owe me anything. Yet. Coffee?")
	await say("devaraj", "So Thimmaiah sends my own property back through my own... what shall we call you? Guest? You stayed nine days at Upparpet on my recommendation. Guest.")
	await say("raji", "(Your mouth is completely dry. You hear yourself speak anyway.)  That girl. Shwetha. Somebody did that to her. You know who.")
	await say("devaraj", "(Mildly.)  My sister's son is a fool, and I have paid for his foolishness since he was nine. I will deal with him in the family. The girl will be looked after - a seat in a good college, far from here. I am not a monster. I am a man who tidies.")
	await say("devaraj", "Now. Your wife. A brilliant woman. She has stopped forty acres of my land with one sheet of paper. I can fight that for six years, or I can ask her husband to be reasonable.")
	await say("devaraj", "The complaint against you is 'corrected' - mistaken identity, it happens. Your friend the fat driver took fifteen thousand from my finance for your surety; I tear the note. And you carry for me, not for a flower-seller. All I need is for Madam to withdraw from Peenya.")
	var c := await choose(["\"I'll have to ask my wife.\"", "\"Tear Uma's note. Correct the case. I'll talk to her.\"  (accept)", "\"No. And leave that girl's statement alone - she said what happened to her.\"  (refuse)"])
	if c == 0:
		Game.set_flag("devaraj_answer", "ask")
		Game.add_rep(1)
		await say("devaraj", "(He laughs, genuinely.)  'I'll have to ask my wife.' In thirty years of business nobody has given me a more honest answer in this room. Go. Ask. I am patient with honest men; they're so few.")
	elif c == 1:
		Game.set_flag("devaraj_answer", "accept")
		Game.add_faction("devaraj", 20)
		Game.add_faction("tiger", -10)
		Game.set_flag("uma_note_torn")
		await say("devaraj", "Sensible. Pinto will tear the note tonight. And Rajinikanth - when you 'talk to her', remember which of you was in the lock-up. It focuses the mind.")
		await say("", "(Walking out, you realise you have just promised a High Court lawyer's signature. Your stomach understands before you do.)")
	else:
		Game.set_flag("devaraj_answer", "refuse")
		Game.add_faction("devaraj", -20)
		Game.add_rep(4)
		pl.human.emotion = -0.6
		await say("", "(It is out of your mouth before your knees can vote. The faulty brake again.)")
		await say("devaraj", "(The smile stays. The eyes leave.)  Courage. On bail. In my office. I thought you were the frightened one in that marriage. ...Finish your coffee. It may be some time before anyone offers you another.")
		pl.human.emotion = 0.0
	Game.log_event("Met Devaraj. He offered to tidy everything.")
	world.crowd.unpin("devaraj")
	_scene(false)
	_m4_mark("devaraj")

# ------------------------------------------------------------------ Umashankar
func _m4_checkpoint() -> void:
	_scene(true)
	var cop: NPC = world.crowd.spawn_actor(Human.random_look(world.crowd.rng, 0, "police"), {"name": "Constable", "job": "police constable"}, pl.global_position + Vector3(1.6, 0, -1.2), "naka")
	cop.face(pl.global_position)
	Sfx.play("whistle", 0.6)
	await hud.say("Constable", "Ey. Stop. Night checking. What's in the bag?")
	var uniform: bool = int(s.look.top) == 7
	var c := await choose(["\"Ticket bag, saar. 27E. Last trip cash.\"" + ("" if uniform else "  (you are not in uniform)"), "Fold two hundred rupees into your palm. \"Tea expenses, saar.\"", "Run."])
	if c == 0 and uniform:
		await hud.say("Constable", "Conductor. Okay, okay, go. Tell your driver to stop honking near the station.")
		Game.add_rep(1)
	elif c == 0:
		await hud.say("Constable", "Conductor without khaki? Open it. ...What are these envelopes? Station-ge baa.")
		Game.add_heat(45.0)
	elif c == 1:
		if Game.can_pay(200):
			Game.add_money(-200, "tea expenses")
			Game.add_faction("police", 2)
			await hud.say("Constable", "Dangerous area, be careful. Good night.")
		else:
			await hud.say("Constable", "Empty hand you're showing me? Open the bag.")
			Game.add_heat(45.0)
	else:
		Game.add_heat(40.0)
	cop.no_despawn = false
	cop.story_tag = ""
	_scene(false)

# ------------------------------------------------------------------ side stories
func _shift_offer() -> bool:
	var t := float(s.time)
	if t < 5.5 or t > 13.0:
		return false
	await say("uma", "Morning trip leaves in two minutes. Coming? Or have you become a big man who only carries envelopes?")
	var c := await choose(["Work the morning trip (wages)", "Not today"])
	if c == 0:
		hud.end_talk()
		world.crowd.pin("uma", DEPOT, -PI * 0.5)
		pl.global_position = DEPOT + Vector3(2.0, 0, 0.5)
		await _start_run(false)
	return true

func _pinto() -> void:
	await say("pinto", "The ticket man. Your friend owes Sri Devaraj Finance fifteen thousand. Eighteen, with this month.")
	var c := await choose(["Pay eighteen thousand." + ("" if Game.can_pay(18000) else "  (not enough money)"), "\"He has a daughter in school. Close the account or I close it.\"  (fight)", "Walk away."])
	if c == 0 and Game.can_pay(18000):
		Game.add_money(-18000, "Umashankar's loan, with interest")
		Game.set_flag("uma_settled")
		Game.add_rel("uma", 12)
		world.crowd.unpin("pinto")
		await say("pinto", "Pleasure. Tell him our door is always open.")
	elif c == 1:
		hud.end_talk()
		pl.human.emotion = -0.9
		var n: NPC = world.crowd.node_of("pinto")
		if n != null:
			n.id = ""
			n.story_tag = "pinto_fight"
			n.mode = "hostile"
			n.hp = 48.0
			n.no_despawn = true
			world.crowd.named["pinto"].node = null
			var cb := func(d: NPC):
				if d.story_tag == "pinto_fight":
					Game.set_flag("uma_settled")
					Game.add_rep(5)
					Game.add_faction("devaraj", -12)
					Game.add_rel("uma", 10)
					world.crowd.unpin("pinto")
					pl.human.emotion = 0.0
					Game.log_event("Settled Umashankar's loan with Pinto. Without money. On bail.")
					hud.subtitle("Pinto: ...Account closed. For now. Devaraj saar will hear.", 3.0)
			world.crowd.npc_down.connect(cb, CONNECT_ONE_SHOT)

func _shalini() -> bool:
	if not s.missions.has("c1") or Game.flag("shalini_met"):
		if str(Game.flag("devaraj_answer")) != "false" and not Game.flag("tipped_press"):
			await say("shalini", "You have the face of a man holding a headline. Off the record. What did Devaraj say to you in that office?")
			var c := await choose(["Tell her: the land, the 'corrected' complaint, the election money through the flower market.", "\"Nothing. I issue tickets.\""])
			if c == 0:
				Game.set_flag("tipped_press")
				Game.add_rel("shalini", 12)
				Game.add_faction("devaraj", -12)
				Game.add_faction("knv", 8)
				await say("shalini", "...I can't print it without paper. But now I know where to dig. Rajinikanth - they will ask who talked. Have an answer ready. And tell Kamakshi I said she chose well. Mostly.")
			else:
				await say("shalini", "That's the second-best lie I've heard today. The best was from the Commissioner.")
			return true
		return false
	Game.set_flag("shalini_met")
	await say("shalini", "Shalini Rao, Sanje Vaani. You're the conductor in Crime 214. I'm not here to ask if you did it. I'm asking who showed the complainant your photograph before she'd described anyone.")
	var c2 := await choose(["\"Ask the station. I only know I didn't do it.\"", "\"No comments.\"", "\"Write about the girl. She's the one it happened to.\""])
	if c2 == 0:
		Game.add_rel("shalini", 4)
		await say("shalini", "I did ask. The station writer went to wash his hands for forty minutes.")
	elif c2 == 1:
		await say("shalini", "'No comments.' Your wife trained you. Here's my number.")
	else:
		Game.add_rel("shalini", 8)
		await say("shalini", "(She stops writing.)  ...I am. That's the story. You're a paragraph in it. I'm glad you know that.")
	Game.add_contact("shalini")
	return true

func street_event() -> void:
	if _thief != null or world.interior != "" or pl.bus != null or pl.vehicle != null:
		return
	var d := City.district(Vector2(pl.global_position.x, pl.global_position.z))
	if d.kind == "rural":
		return
	var rng: RandomNumberGenerator = world.crowd.rng
	var fwd := Vector3(-sin(pl.yaw), 0, -cos(pl.yaw))
	var vp := pl.global_position + fwd * 9.0
	var vic: NPC = world.crowd.spawn_actor(Human.random_look(rng, 1), People.random_identity(rng, d.kind), vp, "victim")
	vic.ident.name = "Woman"
	vic.no_despawn = false
	_thief = world.crowd.spawn_actor(Human.random_look(rng, 0, "goon"), {"name": "Chain-snatcher", "job": "thief"}, vp + fwd * 1.5, "thief")
	_thief.mode = "hostile"
	_thief.hp = 10.0
	_thief.mode = "flee"
	_thief.timer = 25.0
	_thief.face_yaw = pl.yaw + PI + rng.randf_range(-0.4, 0.4)   # runs straight past you
	_thief_t = 25.0
	Sfx.play("whoosh", 0.6)
	hud.subtitle("Woman: KALLA! KALLA! My chain! Somebody catch him!", 3.5)
	hud.toast("A chain-snatcher is running past you. HIT to stop him.")
	# make him punchable as a hostile while fleeing
	_thief.set_meta("thief", true)

func _rally(_delta: float) -> void:
	var t := float(s.time)
	var on: bool = t >= 17.0 and t < 19.0 and world.interior == ""
	crowd_noise = false
	if not on:
		if _rally_day == int(s.day) and t >= 19.0:
			world.crowd.clear_actors("rally")
			_rally_day = -int(s.day)
		return
	var cp: Vector3 = world.crowd.named_pos("channanna")
	if pl.global_position.distance_to(cp) > 70.0:
		return
	crowd_noise = true
	if _rally_day != int(s.day):
		_rally_day = int(s.day)
		var rng: RandomNumberGenerator = world.crowd.rng
		for i in 9:
			var n: NPC = world.crowd.spawn_actor(Human.random_look(rng), People.random_identity(rng, "com"), cp + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(2.5, 8)), "rally")
			n.face(cp)
			n.no_despawn = false
		hud.toast("J.P.P. street-corner meeting. The lantern promises light.")
	if randf() < 0.01:
		var ch: NPC = world.crowd.node_of("channanna")
		if ch != null:
			ch.say_bubble(["A light in every house!", "Roads! Water! Dignity!", "They have the plough, we have the people!", "Who built this bus stand? WE did!"][randi() % 4], 3.5)
		for n in world.crowd.actors("rally"):
			if randf() < 0.3:
				n.say_bubble(["Channanna-ge jai!", "Jai! Jai!", "When is the biryani?"][randi() % 3], 2.0)
				n.human.play_once("wave", 0.8)

func gossip(bar := false) -> String:
	var a := str(s.active)
	if bar:
		if a in ["c4", "c4wait", "c5", "end"]:
			return "\"...Devaraj and Thimmaiah were partners in everything except trust. Somebody's eighteen lakhs went walking, and now the flower market smells of kerosene.\""
		return "\"...Devaraj is buying everything behind Peenya. Farmers sign in the morning, the registrar signs at night. Some lady lawyer has got a stay. Brave. Or doesn't know the area.\""
	if a in ["c1", "c2"]: return "You're back! I told everybody: that boy? Never. He says 'sorry' to my bench when he bumps it. ...Some people still talk. Let them. Tea?"
	if a == "c3": return "You look like you saw a ghost and the ghost gave you homework. Go home, Raji. Tell your wife. She's the brains."
	if a in ["c4", "c4wait"]: return "Subbu the cashier - found in the pay-and-use toilet near Shivajinagar stand. Heart. The attendant is angry; he died owing one rupee."
	if a == "c5" or a == "end": return "People are saying your name near the market. Quietly. In my experience that is never good. Umashankar is worried. When that man stops eating, I worry."
	return "Election time. Every tea I sell comes with a free manifesto."

func radio() -> String:
	var lead := "Janata Pragathi Paksha" if float(s.politics.jpp) >= float(s.politics.knv) else "Karnataka Nava Nirmana Vedike"
	return ["This is Akashvani Bangalore. The time is %s. Light rain is expected, or not." % Game.clock_text(),
		"...and in Majestic constituency observers say the %s holds a narrow lead. Now, a film song from 'Mallige Manasu'." % lead,
		"Load-shedding in the following areas from six to eight: Chickpet, Cottonpet, Majestic, and wherever you are listening from."][int(s.day + s.time) % 3]

func headlines() -> Array:
	var out: Array = []
	if s.missions.has("c1"):
		out.append("COURTS: Bail for B.C.T.S. conductor in bus harassment case. Complainant's counsel: \"Find the right man; she deserves that much.\"")
	if s.missions.has("c2"):
		out.append("CRIME: Flower-market cashier found dead in public convenience. Police say 'natural'. Colleagues say he left with 'a heavy bag'.")
	if str(Game.flag("bag")) == "court":
		out.append("COURTS: Rs 18 lakh 'found on a bus' deposited before Magistrate in sealed cover. No claimant has come forward. Nobody is surprised.")
	if s.missions.has("c4"):
		out.append("GANG CLASH at K.R. Market godown: flowers worth Rs 40,000 destroyed, three injured. Upparpet police 'investigating'.")
	if Game.flag("tipped_press"):
		out.append("EXCLUSIVE by Shalini Rao: Who is buying Peenya? Land records, a finance company and a sitting M.L.A.")
	if Game.flag("caught_thief"):
		out.append("CITY: Chain-snatcher caught by off-duty B.C.T.S. conductor. \"I only wanted his ticket,\" he reportedly said.")
	if out.is_empty():
		out.append("CRIME: Quiet night in the city, say police. Readers are advised to remain suspicious.")
	return out

func family_scooter() -> Vehicle:
	for v in world.traffic.owned:
		if v.uid == "family":
			return v
	var hp := place("home")
	var sc: Vehicle = world.traffic.add_owned("scooter", 3, hp + Vector3(2.6, 0, 0.6), PI * 0.5)
	sc.uid = "family"
	s.vehicles[s.vehicles.size() - 1].uid = "family"
	return sc

# ------------------------------------------------------------------ the opening: tea
func _cam_at(p: Vector3, look: Vector3, fov := 62.0) -> void:
	_cam_fn = Callable()
	pl.cam.fov = fov
	pl.cam.global_position = p
	pl.cam.look_at(look, Vector3.UP)

func _cam_move(a: Vector3, b: Vector3, look_a: Vector3, look_b: Vector3, dur: float, fov := 62.0) -> void:
	pl.cam.fov = fov
	var st := {"t": 0.0}
	var d := maxf(dur if not Game.test_mode else 0.05, 0.01)
	_cam_fn = func():
		var tt: float = minf(1.0, float(st.t) + get_process_delta_time() / maxf(Engine.time_scale, 0.05) / d)
		st.t = tt
		var k: float = tt * tt * (3.0 - 2.0 * tt)
		pl.cam.global_position = a.lerp(b, k)
		pl.cam.look_at(look_a.lerp(look_b, k), Vector3.UP)

func _raju_look() -> Dictionary:
	return {"sex": 0, "skin": 3, "face": 5, "hair": 0, "beard": 0, "height": 0.2, "build": 0.1, "top": 4, "top_col": 13, "bottom": 0, "bot_col": 9, "shoes": 3, "age": 0.14, "acc": 0, "watch": 0}

func _give_tray(n: NPC) -> void:
	n.human.activity = "tray"
	n.base_act = "tray"

func _wait_outside_station() -> void:
	var door := place("police")
	var sc := family_scooter()
	if sc != pl.vehicle:
		sc.global_position = door + Vector3(2.4, 0, 2.2)
		sc.rotation.y = PI * 0.5
	world.crowd.pin("kamakshi", door + Vector3(1.3, 0, 2.6), PI)
	world.crowd.pin("uma", door + Vector3(-1.6, 0, 2.8), PI)

# ------------------------------------------------------------------ riding pillion behind Kamakshi
func ride_with(dest: Vector3, lines: Array, then := Callable()) -> void:
	_scene(true)
	if world.interior != "":
		world.leave_interior()
	if pl.vehicle != null:
		pl.exit_vehicle()
	var sc := family_scooter()
	var kn: NPC = world.crowd.node_of("kamakshi")
	var kp: Vector3 = kn.global_position if kn != null else pl.global_position + Vector3(1.5, 0, 0)
	sc.global_position = kp + Vector3(0.9, 0, 0.2)
	if kn != null:
		kn.human.play_once("give", 0.8)
	Sfx.play("eng_bike", 0.5, 0.8)
	await say("kamakshi", ["Stand is off. Get on. Don't lean on me like I am a sofa.", "Sit. Feet up. If you say 'left, left' in my ear I will stop the vehicle.", "Get on, conductor. No ticket required."][int(s.day) % 3])
	hud.end_talk()
	if kn != null:
		world.crowd.remove(kn)
	world.crowd.named["kamakshi"].pin = {"pos": dest, "yaw": 0.0, "sit": false, "mode": "pin"}
	world.crowd.named["kamakshi"].pos = Vector2(dest.x, dest.z)
	var kh := Human.make(People.look_of("kamakshi"))
	sc.set_rider(kh)
	kh.visible = true
	pl.mount_pillion(sc)
	hud.set_mode("ride")
	_scene(false)
	world.busy = true
	var from := Vector2(sc.global_position.x, sc.global_position.z)
	var pts := City.route(from, Vector2(dest.x, dest.z))
	_ride = {"veh": sc, "pts": pts, "i": 1, "v": 0.0, "lines": lines, "li": 0, "lt": 3.0, "kh": kh, "dest": dest, "then": then}

func _ride_tick(delta: float) -> void:
	var sc: Vehicle = _ride.veh
	var pts: PackedVector2Array = _ride.pts
	var i: int = _ride.i
	var cur := Vector2(sc.global_position.x, sc.global_position.z)
	if i >= pts.size():
		_ride_end()
		return
	# keep to the left of the line between waypoints
	var seg: Vector2 = (pts[i] - pts[i - 1]).normalized()
	var tgt: Vector2 = pts[i] + Vector2(seg.y, -seg.x) * (2.6 if i < pts.size() - 1 else 0.0)
	var dist := cur.distance_to(tgt)
	var want := 8.5 if dist > 14.0 else 4.0
	if i == pts.size() - 1 and dist < 12.0:
		want = 2.0
	if Game.test_mode:
		want = 80.0
	var v: float = move_toward(float(_ride.v), want, (3.0 if want > float(_ride.v) else 6.0) * delta)
	_ride.v = v
	if dist < maxf(2.5, v * delta * 1.5):
		_ride.i = i + 1
	var mv := (tgt - cur).normalized() * v * delta
	sc.global_position += Vector3(mv.x, 0, mv.y)
	var before := sc.rotation.y
	sc.rotation.y = lerp_angle(sc.rotation.y, atan2(-mv.x, -mv.y), 1.0 - exp(-3.5 * delta))
	sc.v = v
	sc.steer = clampf(-wrapf(sc.rotation.y - before, -PI, PI) / maxf(delta, 0.001), -1.0, 1.0)
	sc._lean.rotation.z = lerpf(sc._lean.rotation.z, -sc.steer * 0.25, delta * 5.0)
	# the conversation carries on over the engine
	_ride.lt = float(_ride.lt) - delta
	if float(_ride.lt) <= 0.0 and int(_ride.li) < _ride.lines.size():
		var ln: Array = _ride.lines[_ride.li]
		_ride.li = int(_ride.li) + 1
		_ride.lt = 3.2 + float(str(ln[1]).length()) * 0.055
		var nm: String = "Kamakshi" if ln[0] == "k" else str(s.name)
		hud.subtitle("%s: %s" % [nm, ln[1]], float(_ride.lt) - 0.4)
		if ln[0] == "k":
			_ride.kh.talk_t = 2.5
			_ride.kh.look_target = sc.global_position + sc.global_transform.basis.z * 2.0 + Vector3(0.8, 1.4, 0)
		else:
			pl.human.talk_t = 2.5
			_ride.kh.look_target = null

func _ride_end() -> void:
	var r: Dictionary = _ride
	_ride = {}
	var sc: Vehicle = r.veh
	sc.v = 0.0
	pl.dismount()
	sc.set_rider(null)
	if is_instance_valid(r.kh):
		r.kh.queue_free()
	Sfx.play("door", 0.4, 1.5)
	var dest: Vector3 = r.dest
	world.crowd.pin("kamakshi", sc.global_position + Vector3(0.9, 0, 0.9), 0.0)
	world.crowd.ensure("kamakshi")
	hud.set_mode("foot")
	world.busy = false
	Game.s.waypoint = null
	if r.then.is_valid():
		r.then.call()

# ------------------------------------------------------------------ C1: Bail
func _c1_station_talk(n: NPC) -> bool:
	if n.ident.get("name", "") == "Station writer":
		if Game.flag("belongings"):
			await hud.say("Station writer", "Sign there also. And there. Welcome back to society.")
			return true
		await hud.say("Station writer", "Prisoner's property register. One whistle. One ticket bag, empty. One steel watch, not working. Cash, rupees one hundred and forty.")
		await hud.say("Station writer", "It was one hundred and sixty when you came. Twenty is 'storage'. Sign here.")
		var c := await choose(["Sign.", "\"It was one-sixty. Write one-sixty.\""])
		if c == 1:
			await hud.say("Station writer", "...Fine. One-sixty. Your wife has made everybody in this station very careful.")
			Game.add_money(20, "returned")
			Game.set_flag("stood_up_writer")
		Game.set_flag("belongings")
		Sfx.play("coin", 0.5)
		return true
	if n.ident.get("name", "") == "Head Constable":
		await hud.say("Head Constable", "Go home. Eat hot food. And conductor - next time something happens on your bus, look the other way faster, or not at all. The middle is what gets people locked up.")
		return true
	if n.id == "lokesh":
		await say("lokesh", "Bail is not acquittal. I have ninety days to file the charge sheet, and a very good memory for faces that walk out of here smiling.")
		var c2 := await choose(["\"I am not smiling, saar.\"", "\"Who told you to put my name?\"", "Walk past him."])
		if c2 == 0:
			await say("lokesh", "Keep it like that.")
		elif c2 == 1:
			Game.set_flag("asked_lokesh")
			Game.add_rep(1)
			await say("lokesh", "(A small pause; he caps his pen.)  The complainant told me. That is what the paper says. Paper is all there is. Out.")
		return true
	if n.id == "shivaramu":
		await say("shivaramu", "Your wife filed a stay against the Peenya land acquisition last month. For some farmers and that lady corporator. You knew?")
		await say("raji", "She files many things, saar.")
		await say("shivaramu", "Three weeks later her husband is in my lock-up. I am not saying anything. I am only reading two dates aloud. Go home safely.")
		Game.set_flag("shivaramu_hint")
		return true
	return false

func _c1_outside() -> void:
	var un: NPC = world.crowd.node_of("uma")
	if un != null:
		un.face(pl.global_position)
		un.human.emotion = 0.8
	await say("uma", "RAJI! Aiyo, Raji! Look at him. LOOK at him. They've made him half. Madam, they've returned only half, give a complaint!")
	await say("raji", "Uma. People are looking.")
	await say("uma", "Let them look! Nine days I drove 27E with that substitute fellow. He rings the bell like he's apologising. Passengers were asking, 'Where is our conductor?' I said, 'Official duty.' I said it very proudly.")
	await say("kamakshi", "Umashankar stood surety. He signed for ten thousand rupees he does not have, with his salary certificate and his whole chest.")
	var c := await choose(["\"You shouldn't have signed, Uma. You have Putti's fees.\"", "\"...Thank you.\"  (it comes out angry)", "\"Who asked you to cry on my scooter?\""])
	if c == 0:
		Game.add_rel("uma", 4)
		await say("uma", "Shouldn't have! Listen to him. Who signed for my Tumkur site loan? Who lied to Girija about my sugar report? Don't do accounts with me, Raji. We are not that type.")
	elif c == 1:
		Game.add_rel("uma", 6)
		await say("uma", "See, madam, he's angry. That means he is all right. If he was polite I would be worried.")
	else:
		Game.add_rel("uma", 5)
		await say("uma", "It is an emotional vehicle. I am an emotional man. The seat will dry.")
	await say("uma", "I have the evening trip. Tomorrow you come to the depot. The manager will make a face. Let him make. I have already told him what I think of his face.")
	await say("kamakshi", "Tomorrow. Tonight he eats and sleeps. Rajini, come.")
	world.crowd.unpin("uma")
	Game.add_contact("uma")
	hud.end_talk()
	pl.locked = false
	await ride_with(place("home") + Vector3(1.5, 0, 0.8), [
		["k", "Don't lean. ...Fine. Lean. You've been sitting on a cement floor for nine days."],
		["r", "The city looks the same."],
		["k", "It is the same. You were in a police station, not in the Army."],
		["r", "At the depot they'll all know. At Nanjappa's. In the vatara. 'Eve-teasing.' They'll say it behind me."],
		["k", "Some will. And a girl got on a bus that day and somebody put his hands on her and laughed. That is also true, and it was not you. Both things have to be carried, Rajini. Hers first."],
		["r", "I told him to stop. That boy with the dark glasses. I said, 'Ey, behave.' He looked at my badge number. Just looked."],
		["k", "Vicky. Devaraj's sister's son. I know. The girl - Shwetha - was shown one photograph at the station. Yours. In uniform. From your depot file."],
		["r", "Why me?"],
		["k", "Because I filed a stay on forty acres in Peenya, and a man who cannot frighten a lawyer looks around for what the lawyer loves."],
		["r", "...You're saying this is because of you."],
		["k", "I am saying it is because of Devaraj. Learn the difference tonight, please. It will save us one fight."],
		["r", "Kamu. Malleshwaram is straight. Why did you take a left?"],
		["k", "Because you smell like Upparpet lock-up and I am stopping for Mysore Sandal soap. Sit quietly."],
	], func():
		set_step("c1", 3)
		hud.toast("Home. 8th Cross, Malleshwaram. Go in."))
	set_step("c1", 2)

func _c1_home() -> void:
	_scene(true)
	await world.wait(0.6)
	await say("kamakshi", "Hot water is on the stove. Rice is on. Rasam is from yesterday but you are in no position to appeal.")
	await say("", "The house is exactly as you left it. Her files on the cot. Your uniform, ironed, on the nail. Somebody has been ironing a uniform nobody was wearing.")
	await say("raji", "The depot will hold an enquiry.")
	await say("kamakshi", "The depot will hold an enquiry, the police will take ninety days, and Shwetha will be made to repeat her statement four more times to men who yawn. I can fight all three. I need one thing from you.")
	var c := await choose(["\"Tell me.\"", "\"I'll go to Devaraj. I'll fold my hands. It will stop.\"", "\"I want to find that Vicky and break his glasses.\""])
	if c == 0:
		Game.add_rel("kamakshi", 5)
		await say("kamakshi", "Do nothing. Go to work, issue tickets, come home. Be the most boring man in Bangalore for ninety days. Can you?")
	elif c == 1:
		Game.set_flag("c1_plan", "beg")
		Game.add_rel("kamakshi", -4)
		await say("kamakshi", "If you fold your hands to that man, he owns both of us and forty farmers besides. I did not sit nine days in Sessions Court to marry a doormat. No.")
	else:
		Game.set_flag("c1_plan", "fight")
		await say("kamakshi", "You? You apologise to autos when they hit you. (Almost a smile.) Hold that feeling. Don't use it. Go to work, issue tickets, come home. Ninety days.")
	await say("raji", "And if he does something else?")
	await say("kamakshi", "Then he does it to an Advocate of the High Court and her very boring husband. Eat. Then sleep. I have a matter at eleven.")
	Game.log_event("Bail. Nine days in Upparpet lock-up for something another man did.")
	set_step("c1", 4)
	_scene(false)
	hud.toast("Sleep (the cot) to end the day.")

func _kamakshi(a: String, st: int, n: NPC) -> bool:
	if a == "c1" and st == 2:
		await _c1_outside()
		return true
	if a == "c1" and st == 4:
		await say("kamakshi", "Still standing? Sleep. The cot will not file a complaint.")
		return true
	if a == "c3" and st <= 1 and world.interior == "home":
		await _m2_home()
		return true
	if Game.flag("date_on"):
		await say("kamakshi", "Walk properly. People will think I am being escorted by the Corporation.")
		return true
	var opts: Array = ["Just talk."]
	var keys: Array = ["talk"]
	if a == "c2" and st == 0:
		opts.append("\"Drop me at the depot? Majestic.\"")
		keys.append("depot")
	else:
		opts.append("\"Take me somewhere on the scooter.\"")
		keys.append("ride")
	var hr := float(s.time)
	if hr >= 17.0 and hr < 20.5 and not Game.flag("film_day_%d" % int(s.day)):
		opts.append("\"Evening show at Sangam Talkies? Balcony.\"")
		keys.append("film")
	await say("kamakshi", People.CHAT["kamakshi"][world.crowd.rng.randi() % 4])
	var c := await choose(opts)
	match str(keys[c]):
		"depot":
			hud.end_talk()
			pl.locked = false
			await ride_with(DEPOT + Vector3(6.0, 0, 18.0), [
				["k", "Head up when you walk in. Not too up. You're a conductor, not a returning king."],
				["r", "What do I say if they ask?"],
				["k", "'The matter is sub judice.' Nobody knows what it means. They stop asking."],
				["r", "Sub... judi..."],
				["k", "Just say 'case is in court'. And Rajini - don't fight anybody for my sake today. I have a full board."],
				["r", "I never fight."],
				["k", "I know. That's what worries me. One day it will all come out at once, at the wrong person."],
			], func(): hud.toast("Depot No. 2 is through the arch. Umashankar is waiting."))
		"ride":
			hud.end_talk()
			pl.locked = false
			var ids: Array = []
			for id in s.discovered:
				if City.PLACES.has(id) and City.PLACES[id].pos.distance_to(pl.global_position) > 60.0:
					ids.append(id)
			var items: Array = []
			for id in ids:
				items.append({"text": City.PLACES[id].name})
			var pick: int = await hud.menu("\"Where?\"", items, "Kamakshi drives. You sit behind and look at Bangalore.")
			if pick >= 0:
				await ride_with(City.PLACES[ids[pick]].pos + Vector3(1.2, 0, 1.0), _ride_chatter())
		"film":
			Game.set_flag("film_day_%d" % int(s.day))
			Game.set_flag("date_on")
			hud.end_talk()
			pl.locked = false
			await ride_with(place("cinema") + Vector3(1.5, 0, 1.5), [["k", "Balcony. And you are buying the samosa. I got you bail; samosa is the least."], ["r", "Benki Basava again?"], ["k", "I like it when he jumps on the train. Nobody in my court ever jumps on anything."]],
				func(): hud.toast("Sangam Talkies. Buy the tickets (FILM)."))
		_:
			await say("kamakshi", _kamakshi_line())
			if not Game.recalls("kamakshi", "chat_day%d" % int(s.day)):
				Game.remember("kamakshi", "chat_day%d" % int(s.day))
				s.rel["kamakshi"] = clampi(Game.rel("kamakshi") + 1, -100, 100)
	return true

func _kamakshi_line() -> String:
	if Game.flag("works_for_tiger"):
		return "You came home at one o'clock smelling of jasmine and lies. I cross-examine for a living, Rajini. Don't make me do it at breakfast."
	if str(Game.flag("bag")) == "court":
		return "The Magistrate asked me where an advocate's husband found eighteen lakhs. I said, 'On a bus, Your Honour.' He wrote it down. It looked ridiculous even in his handwriting."
	if s.missions.has("c2"):
		return "A man jumps off your bus and leaves a bag. Out of four hundred conductors in this city. I am starting to think God has your badge number too."
	return "Ninety days. Count them on the calendar if it helps. I am."

func _ride_chatter() -> Array:
	var sets: Array = [
		[["k", "Hold the bag, not my shoulder. I am changing gear."], ["r", "That building wasn't there last year."], ["k", "That building wasn't there last month. Somebody's nephew got a licence."], ["r", "Left here is shorter."], ["k", "Who is driving?"], ["r", "...You."], ["k", "Thank you."]],
		[["r", "Uma says we should buy a car. Second-hand Fiat."], ["k", "Umashankar should first buy a belt that closes."], ["r", "He's sensitive about that."], ["k", "He told me himself. He is proud of it. He calls it his 'prosperity'."]],
		[["k", "Your mother called. She asked if you are eating. I said yes. She asked if I am cooking. I said the matter is sub judice."], ["r", "You said that to Amma?"], ["k", "She laughed. Your mother and I understand each other. It's you neither of us understands."]],
	]
	return sets[int(s.day + int(s.time)) % sets.size()]

# ------------------------------------------------------------------ C2: Back on the Route
func _c2_depot() -> void:
	await say("uma", "Seven-oh-two! In my day a conductor came before the driver and polished the bell. ...It is still my day. Come here.")
	await say("", "He hugs you in front of the whole depot. It is like being hugged by a warm almirah.")
	await say("uma", "Listen. Three things. One: the manager has reinstated you 'pending enquiry'. Pending is a beautiful word, it means nobody has to decide. Two: don't go near the canteen, they are all experts on your case.")
	await say("raji", "And three?")
	await say("uma", "Three: I ate your share of Girija's chitranna because I thought you weren't coming. I'm not sorry. It was very good.")
	var c := await choose(["\"If any passenger says anything today-\"", "\"Uma. The surety. Ten thousand. Where did you show that from?\"", "\"Start the bus.\""])
	if c == 0:
		await say("uma", "-then he will discover that a city bus has very sudden brakes. Leave passengers to me. You do tickets.")
	elif c == 1:
		Game.set_flag("asked_surety")
		await say("uma", "(He becomes very interested in the steering wheel.)  Arrangements. A man has arrangements. Ticket roll? Whistle? Change? Good.")
	await say("uma", "Fares: one stage two rupees, two stages three, three stages four, anything more five. You don't leave a stop till everybody has a ticket, and I don't move till you shout RIGHT.")
	hud.end_talk()
	await _start_run(false)

func _c4_uma() -> void:
	await say("uma", "You have the face. The acidity-lying face. Sit. Tell.")
	var c := await choose(["Tell him everything. The bag, the phone, the godown at nine.", "\"Nothing. Stomach.\""])
	if c == 1:
		Game.add_rel("uma", -5)
		await say("uma", "Stomach. Okay. I am only the man who signed your surety, why would you tell me anything. Go. Do your stomach.")
		set_step("c4", 2)
		return
	Game.set_flag("uma_knows")
	Game.add_rel("uma", 8)
	await say("uma", "Thimmaiah. THE Thimmaiah. Flower Thimmaiah. Raji, that man once had a fellow garlanded and buried the same afternoon.")
	await say("uma", "Right. I'm coming.")
	var c2 := await choose(["\"You have Girija and Putti. You're not coming.\"", "\"...Bring the auto. Immu's. Wait outside.\"", "\"If Kamakshi asks, you don't know where I am.\""])
	if c2 == 0:
		Game.set_flag("uma_stayed")
		await say("uma", "Don't put my daughter's name in front of me like a speed-breaker. ...Fine. But nine-thirty. If you have not called by nine-thirty I am coming with the bus. The whole bus.")
	elif c2 == 1:
		Game.set_flag("uma_came")
		Game.add_rel("uma", 4)
		await say("uma", "Now you're talking like a conductor. I'll be at the market gate with the engine on. I'll keep eating something, so I look natural.")
	else:
		Game.set_flag("uma_stayed")
		Game.set_flag("hid_from_kamakshi")
		await say("uma", "You want me to lie to a High Court lawyer. Me. I can't even lie to the weighing machine. Go. I didn't hear anything.")
	if Game.flag("means_to_return") and not Game.flag("hid_from_kamakshi"):
		await say("", "(You promised Kamakshi you would tell her before going anywhere. The S.T.D. booth and your phone both work.)")
	set_step("c4", 2)

func _uma(a: String, st: int) -> bool:
	if a == "c2" and st <= 1:
		await _c2_depot()
		return true
	if a == "c3" and st <= 1:
		await say("uma", "Money that size has an owner, and the owner has long arms. Police station, or your wife. If you ask me - your wife. Police already had you once.")
		await say("uma", "And Raji... whichever you choose, you never showed it to me. I have a weak heart for secrets. I tell Girija everything by Thursday.")
		return true
	if a == "c4" and st == 1:
		await _c4_uma()
		return true
	if Game.flag("uma_loan") and not Game.flag("uma_settled"):
		await say("uma", "Don't look at me with the loan face. I will manage. I have managed bigger things. I managed you for eleven years.")
		return true
	if a in ["c4wait", "c5", "end"] and not Game.flag("uma_loan") and int(s.day) >= 3:
		await _uma_loan()
		return true
	if a in ["c4wait", "end", "free", "c5"] and bus == null:
		return await _shift_offer()
	return false

func _uma_loan() -> void:
	Game.set_flag("uma_loan")
	await say("uma", "Raji. Don't shout. First promise you won't shout.")
	await say("uma", "The surety. And Putti's term fees came the same week. I took fifteen thousand from Sri Devaraj Finance. Pinto wrote 'three percent'. I thought per year. It is per week.")
	await say("raji", "DEVARAJ Finance. Uma. For MY bail. From the man who-")
	await say("uma", "I didn't know then! Nobody told me which villain it was! I only knew you were on a cement floor and I am too fat to break a lock-up!")
	if Game.flag("uma_note_torn"):
		await say("", "(Devaraj said the note would be torn. You realise what that tearing has cost, and say nothing.)")
		Game.set_flag("uma_settled")
		return
	var c := await choose(["Pay it off: Rs 15,000." + ("" if Game.can_pay(15000) else "  (not enough money)"), "\"I'll talk to Pinto myself.\"", "\"We tell Kamakshi. Three percent a week is not even legal.\""])
	if c == 0 and Game.can_pay(15000):
		Game.add_money(-15000, "Umashankar's loan")
		Game.set_flag("uma_settled")
		Game.add_rel("uma", 15)
		await say("uma", "(He cannot speak. He holds your shoulder and looks at the bus instead.)  ...I'll return it. Don't say no. I'll return it.")
	elif c == 2:
		Game.set_flag("uma_settled")
		Game.set_flag("loan_notice")
		Game.add_rel("uma", 8)
		Game.add_rel("kamakshi", 6)
		Game.add_faction("devaraj", -8)
		await say("uma", "Madam will look at me over her spectacles. I would rather face Pinto. ...Fine. Fine! But you do the talking.")
		Game.add_message("Kamakshi", "Notice under the Karnataka Money Lenders Act sent to Sri Devaraj Finance by registered post, acknowledgement due. Tell Umashankar to stop bringing me bananas.")
		Game.log_event("Kamakshi sent Devaraj Finance a legal notice over Umashankar's loan.")
	else:
		world.crowd.pin("pinto", place("bar") + Vector3(2.5, 0, 0.8), PI)
		Game.discover("bar")
		await say("uma", "He stands outside Kaveri Bar most evenings. Raji - he keeps a cycle chain in his pocket. And you are on bail. Don't be brave. You are not good at it.")

