class_name Story
extends Node
## Chapter One: "Ticket". Mission state lives in Game.s (active, step, mvars,
## flags) so every beat survives save/load. Scenes are coroutines.

const ROUTE := ["majestic", "gandhinagar", "vidhana", "shivajinagar", "mgroad", "ulsoor"]
const DEPOT := Vector3(27.6, 0, -28.0)
const TITLES := {"m0": "Morning Shift", "m1": "Route 27E", "m2": "Eighteen Lakhs", "m3": "Wrong Number", "m4": "The Conductor's Bag", "end": "Chapter One complete"}

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
	await hud.say(nm, text)

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
	if str(s.active) == "":
		set_step("m0", 0)
		_opening()
	elif s.active == "m1":
		# a save made mid-route resumes at the depot
		set_step("m0", 1)
	_apply_pins()

func _apply_pins() -> void:
	if s.active == "m0" or (s.active == "m2" and int(s.step) <= 1) or s.active == "m1":
		world.crowd.pin("basanna", DEPOT, -PI * 0.5)
	else:
		world.crowd.unpin("basanna")
	if s.active == "m4" and int(s.step) == 0:
		pass

func _opening() -> void:
	_scene(true, true)
	await hud.fade(1.0, 0.01)
	hud.card("CHAPTER ONE", "T I C K E T")
	await world.wait(2.5)
	await hud.fade(0.0, 1.5)
	await say("", "Bangalore. July, 2002. The city has not yet decided what it wants to become.")
	await say("", "You are Rajinikanth. Conductor, Route 27E, Majestic to Ulsoor. Badge number 4471.")
	await say("", "Your father named you after a bus conductor who became a god. No pressure.")
	_scene(false)
	hud.toast("Left stick: walk.  Drag right side: look.  Yellow button: interact.")

func new_day() -> void:
	var j := clampf(float(s.politics.jpp) + randf_range(-3.0, 3.0) + (1.5 if Game.flag("helped_jpp") else 0.0) - (2.0 if Game.flag("tipped_press") else 0.0), 20.0, 80.0)
	s.politics.jpp = j
	s.politics.knv = 100.0 - j
	if int(s.day) % 7 == 0 and s.mode == "story":
		if Game.can_pay(300):
			Game.add_money(-300, "rent to Lakshmamma")
		else:
			Game.add_rel("lakshmamma", -8)
			Game.add_message("Lakshmamma", "RENT. I am not running a dharmashala. - L")
	if Game.flag("promise_meena") and not Game.flag("date_done") and int(s.day) > int(Game.flag("promise_day", 0)) + 2 and not Game.flag("meena_cold"):
		Game.set_flag("meena_cold")
		s.rel["meena"] = Game.rel("meena") - 12
		if s.phone:
			Game.add_message("S.T.D. booth", "Sunday came. Sunday went. Sangam Talkies is still standing, in case you forgot where it is. - M")

func on_wake() -> void:
	if s.active == "m2" and int(s.step) == 2:
		_complete("m2", 0, 2, "Slept on a decision. It did not improve.")
		set_step("m3", 0)
		_m3_call()
	elif s.active == "m3wait" and int(s.day) >= int(s.mvars.get("m4_day", 0)):
		set_step("m4", 0)
		Game.add_message("'Oil' Kumar", "Kaveri Bar. After 8. Bring the ticket bag. Empty.")

func on_player_down() -> void:
	if s.active == "m3" and int(s.step) == 3:
		_m3_finish(false)
	_end_run(false)

# ------------------------------------------------------------------ objectives
func objective_text() -> String:
	var st := int(s.step)
	match str(s.active):
		"free": return "Free roam  -  Bangalore, 2002"
		"m0":
			return "Have a coffee at Nanjappa's tea stall" if st == 0 else "Report to Basanna at Depot No. 2, Kempegowda Bus Station"
		"m1":
			if bus == null: return ""
			var nxt: String = City.nodes[run_stops[mini(stop_i + 1, run_stops.size() - 1)]].name
			var unpaid := 0
			for p in pax:
				if not p.paid: unpaid += 1
			if bus.ai.hold and _incident_t < 0.0:
				return "At %s. Issue tickets, then signal RIGHT!  (%d without ticket)" % [City.nodes[run_stops[stop_i]].name, unpaid]
			return "Next: %s  -  %d without ticket.  Fares: 1 stage Rs 2, 2 Rs 3, 3 Rs 4, more Rs 5" % [nxt, unpaid]
		"m2":
			if st <= 1: return "The bag: hand it in at Upparpet Police Station, or hide it in your room"
			return "Go home and sleep on it"
		"m3":
			if st == 1: return "Meena is waving from the S.T.D. booth. See what she wants"
			if st == 2: return "Go to Thimmaiah's flower godown at K.R. Market (bus stop, auto or on foot)"
			if st == 3: return "Anthony's boys! Take the scooter and lose them"
		"m3wait": return "Lie low. Work a shift with Basanna, see Meena, sleep"
		"m4":
			if st == 0: return "Meet 'Oil' Kumar inside Kaveri Bar after 8 PM"
			var left: Array = []
			for k in ["tailor", "cinema", "jpp"]:
				if not s.mvars.get("done_" + k, false): left.append(City.PLACES[k].name)
			return "Deliver the packets: " + ", ".join(PackedStringArray(left))
		"end": return "Chapter One complete  -  the city is yours to explore"
	return ""

func objective_pos():
	var st := int(s.step)
	match str(s.active):
		"m0": return place("tea") if st == 0 else DEPOT
		"m2": return place("home") if (st == 2 or pl.global_position.distance_to(place("home")) < pl.global_position.distance_to(place("police"))) else place("police")
		"m3":
			if st == 1: return place("std")
			if st == 2: return place("godown")
		"m4":
			if st == 0: return place("bar")
			for k in ["tailor", "cinema", "jpp"]:
				if not s.mvars.get("done_" + k, false): return place(k)
	return null

func hotspots() -> Array:
	var out: Array = []
	if bus != null and pl.bus == bus and _incident_t < 0.0:
		for i in pax.size():
			var p = pax[i]
			if not p.paid:
				out.append({"pos": bus.global_transform * _seat_pos(p.seat), "r": 1.25, "label": "TICKET", "key": "pax:%d" % i})
	if s.active == "m4" and int(s.step) == 1 and world.interior == "":
		for k in ["cinema", "jpp"]:
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
	match n.id:
		"nanjappa":
			if a == "m0" and st == 0:
				await _m0_tea()
				return true
		"basanna":
			if a == "m0" and st == 1:
				await _m0_depot()
				return true
			if a == "m2" and st <= 1:
				await say("basanna", "Money that size has an owner, and the owner has long arms. Police station or pooja room, decide before sunrise.")
				await say("basanna", "And Raji... whichever you choose, you never showed it to me.")
				return true
			if a in ["m3wait", "end", "free", "m4"] and bus == null:
				return await _shift_offer()
		"meena":
			return await _meena(a, st)
		"kitty":
			if await _kitty():
				return true
		"pinto":
			if Game.flag("kitty_debt") and not Game.flag("kitty_settled"):
				await _pinto()
				return true
		"lokesh":
			if a == "m2" and st <= 1:
				await _m2_police()
				return true
		"tiger", "oilkumar":
			if a == "m3" and st == 2 and world.interior == "godown":
				await _m3_godown()
				return true
			if a == "m4" and st == 0 and n.id == "oilkumar":
				await _m4_brief()
				return true
		"rafiq":
			if a == "m4" and st == 1 and not s.mvars.get("done_tailor", false):
				await say("rafiq", "For me? From the market side? ...Keep it on the cutting table. No, don't tell me what it is.")
				_m4_mark("tailor")
				return true
		"shalini":
			if await _shalini():
				return true
	if n.story_tag == "victim":
		await hud.say(n.display_name(), "My chain! Two sovereigns! He went that way!")
		return true
	return await Shops.talk(world, n)

func on_enter(id: String) -> void:
	if id == "home" and s.active == "m2" and int(s.step) <= 1:
		_m2_home()
	if id == "godown" and s.active == "m3" and int(s.step) == 2:
		hud.subtitle("The godown smells of jasmine and something older.", 3.0)

func on_leave(_id: String) -> void:
	pass

func on_interior(_id: String, _key: String) -> bool:
	return false

func interior_cast(id: String) -> Array:
	if id == "godown" and s.active == "m3":
		return ["tiger", "oilkumar"]
	if id == "police" and s.active == "m2":
		return ["lokesh"]
	if id == "bar" and s.active == "m4" and int(s.step) == 0 and (float(s.time) >= 20.0 or float(s.time) < 2.0):
		return ["oilkumar"]
	return []

func interior_absent(id: String) -> Array:
	if id == "home" and s.active in ["m0", "m1"]:
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
		"oilkumar":
			await say("oilkumar", "Don't call this number. This number calls you.")
		"meena":
			await say("meena", "S.T.D. booth... oh, it's you. Calling a phone booth from a mobile. Big man now." if Game.rel("meena") >= 0 else "S.T.D. booth. ...Wrong number.")
		"shalini":
			await say("shalini", "Sanje Vaani, crime desk. If this is about the bus story, I'm at the Upparpet station most afternoons.")
		_:
			await say("", "The number you are calling is not answering. Please try after some time.")
	_scene(false)

# ------------------------------------------------------------------ M0: Morning Shift
func _m0_tea() -> void:
	await say("nanjappa", "Raji! First customer. Your face looks like last night's sambar. By-two?")
	var c := await choose(["\"Full cup. Here, two rupees.\"", "\"By-two. Put it on my account.\"", "\"No time, anna. Basanna will eat my head.\""])
	if c == 0:
		Shops.eat(world, "coffee", 2, 10.0)
		Game.add_rel("nanjappa", 3)
		await say("nanjappa", "Cash payment! Somebody call the newspaper.")
	elif c == 1:
		Game.remember("nanjappa", "tab")
		s.hp = minf(100.0, float(s.hp) + 6.0)
		await say("nanjappa", "Your account has more pages than the Ramayana. Drink.")
	else:
		await say("nanjappa", "Go, go. A bus waits for nobody. Except Basanna's bus, which waits for Basanna.")
	await say("nanjappa", "Listen. Two fellows were asking this morning which conductor does the last trip on 27E. Not police. Not passengers.")
	await say("raji", "Me. Why would anybody ask?")
	await say("nanjappa", "That's what I'm telling. Nobody asks about conductors.")
	Game.remember("nanjappa", "warned")
	Game.add_contact("immu")
	set_step("m0", 1)
	world.crowd.pin("basanna", DEPOT, -PI * 0.5)
	hud.toast("MAP button: the city map. Depot No. 2 is north, across K.G. Road.")

func _m0_depot() -> void:
	await say("basanna", "Six fifty-two. In my day a conductor came before the driver and polished the bell.")
	await say("raji", "In your day the bus had horses, Basanna.")
	await say("basanna", "Ha. Ticket roll? Whistle? Change? Good. Rules: you don't leave a stop until everybody has a ticket, and I don't move until you shout RIGHT.")
	await say("basanna", "Fares: one stage two rupees, two stages three, three stages four, anything more five. Don't embarrass me.")
	hud.end_talk()
	await _start_run(false)

# ------------------------------------------------------------------ M1: Route 27E (the conductor game)
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
	var drv := Human.make(People.look_of("basanna"))
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
	if s.active == "m0":
		set_step("m1", 0)
	world.crowd.unpin("basanna")
	var bn: NPC = world.crowd.node_of("basanna")
	if bn != null:
		world.crowd.remove(bn)
	world.crowd.named["basanna"].pin = {"pos": Vector3(0, 0, -5000), "yaw": 0.0, "sit": false, "mode": "pin"}   # he is driving
	world.crowd.named["basanna"].pos = Vector2(0, -5000)
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
	Sfx.music("music_city" if not night else "music_tension", 2.0)
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
		if _run_night and run_stops[stop_i] == "vidhana" and s.active == "m1":
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
	var was_m1: bool = s.active == "m1"
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
	world.crowd.unpin("basanna")
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
	if _incident_t > 0.0 and bus != null:
		_incident_t -= delta
		if _incident_t <= 0.0:
			_incident_t = 0.0
			_m1_incident()
	if s.active == "m3" and int(s.step) == 3 and not world.busy:
		var far: bool = pl.global_position.distance_to(place("godown")) > 170.0
		var alive := 0
		for n in world.crowd.actors("raid"):
			if n.mode == "hostile": alive += 1
		if far or alive == 0:
			_m3_finish(true)
	if s.active == "m4" and int(s.step) == 1 and not _check_done and not world.busy and world.interior == "":
		if pl.global_position.distance_to(place("jpp") + Vector3(0, 0, 0)) < 45.0 and not s.mvars.get("done_jpp", false):
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
	Sfx.music("music_tension", 0.5)
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
	Sfx.music("music_tension", 1.0)
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
	await hud.say("basanna", "RAJI! What was that? Thirty-one years! Thirty-one years nobody has jumped off my bus!")
	pl.cam_override = false
	_cam_fn = Callable()
	_scene(false)
	world.busy = true
	_incident_t = -1.0
	stop_i = run_stops.find("vidhana")
	bus.ai.hold = false
	hud.toast("The bag is at your feet. Majestic is two stops away.")

func _m1_after(wage: int) -> void:
	world.crowd.pin("basanna", DEPOT, -PI * 0.5)
	s.time = 22.4
	await hud.fade(0.0, 1.0)
	await say("basanna", "Depot. Engine off. Now tell me what is in that bag you think I didn't see.")
	var c := await choose(["\"I haven't opened it. I swear on Amma.\"", "\"Nothing. Lost property. I'll hand it in tomorrow.\""])
	if c == 0:
		Game.add_rel("basanna", 6)
		await say("basanna", "Then open it somewhere I am not. And Raji - whatever is inside, it already knows your badge number.")
	else:
		Game.add_rel("basanna", -4)
		Game.remember("basanna", "lied")
		await say("basanna", "Hm. Thirty-one years I have watched conductors lie about ticket money. You are worse at it than most.")
	var total := wage + maxi(0, 30 - _mistakes_carry * 6)
	Game.add_money(total, "day's wages")
	_complete("m1", 0, 3, "A man jumped off the last bus and left his bag behind.")
	set_step("m2", 0)
	_scene(false)
	await world.wait(1.0)
	_m2_open()

# ------------------------------------------------------------------ M2: Eighteen Lakhs
func _m2_open() -> void:
	_scene(true, true)
	Sfx.music("music_tension", 1.0)
	await say("", "Behind the depot office, under the one tube-light that works, you open the zip.")
	await say("", "Bundles. Five-hundreds, bank-banded. You count the bands twice, then a third time because the number is stupid.")
	await say("raji", "Eighteen... lakhs.")
	await say("", "Your salary is three thousand four hundred a month. This is forty-four years of whistling.")
	await say("", "Under the money: a ledger, every page filled with film-song titles and numbers. And a mobile phone. It is switched on.")
	s.phone = true
	Game.add_contact("immu")
	Game.add_message("48 missed calls", "ANNA IS ASKING. PICK UP SUBBU. - K")
	Sfx.play("sms")
	hud.toast("You now carry a mobile phone (TEL button).")
	set_step("m2", 1)
	Game.discover("police")
	_scene(false)
	Sfx.music("", 2.0)

func _m2_police() -> void:
	await say("lokesh", "Conductor. At this hour. Somebody stole your whistle?")
	var c := await choose(["Put the bag on his desk. \"Found on my bus, saar. Lost property.\"", "\"Nothing, saar. Wrong building.\"  (leave)"])
	if c == 1:
		await say("lokesh", "Then don't waste government tube-light.")
		return
	await say("", "He unzips it. For four seconds S.I. Lokesh is the most honest-looking man in Bangalore.")
	await say("lokesh", "Hm. Very good. Very... civic. Name. Badge. Depot. Residence.")
	await say("lokesh", "This is 'evidence' now. I will personally keep it in safe custody. Receipt? Here.")
	await say("", "He writes \"1 bag recd.\" on the back of a cigarette packet and signs it with somebody else's name.")
	await say("lokesh", "For your honesty. Take. Five hundred. And conductor - you never came here.")
	Game.add_money(500, "'reward'")
	Game.set_flag("bag", "police")
	Game.add_faction("police", 8)
	Game.add_faction("soda", 10)
	Game.add_faction("tiger", -15)
	Game.log_event("Handed eighteen lakhs to S.I. Lokesh. Got a cigarette packet.")
	await say("", "As you leave he is already dialling. You catch one word through the door: \"Anthony.\"")
	set_step("m2", 2)

func _m2_home() -> void:
	_scene(true)
	await say("", "You push the bag under the cot, behind the trunk, and put Appa's old suitcase in front of it.")
	await say("kitty", "Anna? ...Why are you hiding a bag like a film villain?")
	var c := await choose(["\"Conductor's cash. Depot rule. Touch it and I break your hand.\"", "Show him. He's your brother.", "\"Go to sleep, Kitty.\""])
	Game.set_flag("bag", "home")
	if c == 1:
		Game.set_flag("kitty_knows")
		await say("kitty", "Anna. ANNA. That's... we can buy a colour TV. We can buy the SHOP that sells colour TVs.")
		var c2 := await choose(["\"It's not ours. Not one rupee.\"", "Peel off one bundle. \"Five thousand. For the TV. Then you forget this.\""])
		if c2 == 1:
			Game.set_flag("kitty_took")
			Game.add_rel("kitty", 10)
			await say("kitty", "Best brother in Karnataka. No - South India.")
		else:
			Game.add_rel("kitty", -3)
			await say("kitty", "Then why show me? That's cruelty, anna.")
	elif c == 0:
		await say("kitty", "Okay, okay! God. Become a conductor, become Hitler.")
	Game.log_event("Hid the bag under the cot.")
	set_step("m2", 2)
	_scene(false)
	hud.toast("Sleep (the cot) to end this long day.")

# ------------------------------------------------------------------ M3: Wrong Number
func _m3_call() -> void:
	_scene(true, true)
	Sfx.play("ring", 0.9)
	await world.wait(1.6)
	Sfx.play("ring", 0.9)
	await world.wait(1.4)
	await say("", "The dead man's phone is ringing. It is 6 AM. You answer because not answering feels worse.")
	await say("phone", "Subbu. Finally. Anna has not slept. I have not slept. Where is it?")
	await say("raji", "This is... not Subbu.")
	await say("phone", "...")
	await say("phone", "Conductor. Four-four-seven-one. Good, saves me petrol. Listen carefully, I say things once.")
	if Game.flag("bag") == "police":
		await say("phone", "We know you walked into Upparpet station with it. We know which pocket it went into after. Anna wants to hear this comedy from your own mouth.")
	else:
		await say("phone", "You have a bag that belongs to S.T. Thimmaiah. Bring it. All of it. Anna likes round numbers.")
	await say("phone", "Flower godown, K.R. Market, behind the main building. Before nine tonight. Come alone. Come by bus if you like, ha.")
	Game.add_contact("oilkumar")
	Game.discover("godown")
	set_step("m3", 1)
	_scene(false)

func _meena(a: String, st: int) -> bool:
	if a == "m3" and st == 1:
		await say("meena", "Rajinikanth! Come here. Since six o'clock some man is calling my booth asking for 'the 27E conductor'. He doesn't say please.")
		await say("meena", "I told him this is a public call office, not your personal secretary. What have you done?")
		var c := await choose(["Tell her everything. The jump, the bag, the phone.", "\"Depot matter. Ticket shortage. Nothing.\"", "\"Maybe he's a fan.\""])
		if c == 0:
			Game.set_flag("meena_knows")
			Game.add_rel("meena", 10)
			await say("meena", "...You're serious. Eighteen lakhs, and you're standing here in rubber chappals.")
			await say("meena", "Listen to me. People who lose that money don't file complaints. Be careful. And - come back and tell me you're alive. Promise.")
		elif c == 1:
			Game.add_rel("meena", -3)
			Game.remember("meena", "lied")
			await say("meena", "Hm. You lie like you give change. Slowly and wrong.")
		else:
			Game.add_rel("meena", 3)
			await say("meena", "A fan! Of what, your whistle?  ...Don't smile, I'm angry.")
		await say("raji", "Sunday. Benki Basava at Sangam Talkies, evening show. Balcony. I'll come to the booth at five.")
		var c2 := await choose(["\"I promise.\"", "\"If I'm free.\""])
		if c2 == 0:
			Game.set_flag("promise_meena")
			Game.set_flag("promise_day", int(s.day))
			Game.add_rel("meena", 4)
			await say("meena", "Balcony. Not Gandhi class. And you're buying the interval samosa. Now go, customer is waiting.")
		else:
			await say("meena", "'If I'm free.' Minister of Transport, no? Go.")
		Game.add_contact("meena")
		set_step("m3", 2)
		return true
	if Game.flag("meena_cold") and not Game.flag("date_done"):
		await say("meena", "Local call one rupee. S.T.D. extra. Broken promises, free of charge, it seems.")
		if Game.flag("jasmine"):
			var c3 := await choose(["Hold out the jasmine. \"I got a bag, a phone and a death threat. I forgot Sunday. I'm sorry.\"", "\"I was busy.\""])
			if c3 == 0:
				Game.set_flag("meena_cold", false)
				Game.set_flag("jasmine", false)
				Game.set_flag("promise_day", int(s.day))
				Game.add_rel("meena", 14)
				await say("meena", "...These are yesterday's flowers. You got cheated. (She puts them in her plait anyway.) This evening. Five o'clock. Last chance.")
				return true
			await say("meena", "Then be busy. Next!")
			Game.add_rel("meena", -4)
		else:
			await say("", "(Words won't fix this. K.R. Market sells jasmine by the mola.)")
		return true
	if Game.flag("promise_meena") and not Game.flag("date_done") and not Game.flag("meena_cold") and float(s.time) >= 17.0 and float(s.time) < 20.5:
		await say("meena", "You came! One minute, I'll put the 'Closed' board. Appa thinks I'm at typing class.")
		var n: NPC = world.crowd.node_of("meena")
		if n != null:
			world.crowd.named["meena"].pin = {"pos": place("cinema"), "yaw": 0.0, "sit": false, "mode": "pin"}
			n.mode = "follow"
			n.no_despawn = true
		Game.set_flag("date_on")
		hud.toast("Walk Meena to Sangam Talkies on M.G. Road (or take a bus together).")
		Game.s.waypoint = [place("cinema").x, place("cinema").z]
		return true
	if Game.flag("date_on"):
		await say("meena", "Walk properly. People will think I'm being escorted by the Corporation.")
		return true
	return false

func on_cinema() -> bool:
	if not Game.flag("date_on"):
		return false
	_scene(true)
	if not Shops.eat(world, "two balcony tickets + samosa", 36, 10.0):
		await say("meena", "You brought me to the balcony queue without balcony money? Rajinikanth.")
		Game.add_rel("meena", -5)
		_scene(false)
		return true
	await hud.fade(1.0, 0.8)
	world.pass_time(3.0)
	Sfx.music("music_love", 1.0)
	await hud.fade(0.0, 0.8)
	await say("meena", "He jumped from a helicopter onto a moving train and his hair didn't move. I want that barber.")
	await say("meena", "Can I ask? In the film the hero never chooses. Things just happen and he hits them. What do YOU want, Raji?")
	var c := await choose(["\"A window seat. For once to sit, and watch somebody else collect the fares.\"", "\"Enough money that nobody can shout 'Ey conductor'.\"", "\"Right now? This. The samosa was optional.\""])
	if c == 0:
		Game.add_rel("meena", 10)
		await say("meena", "That's the saddest and nicest thing a man has said to me. Mostly saddest.")
	elif c == 1:
		Game.add_rel("meena", 2)
		Game.set_flag("meena_money")
		await say("meena", "Careful. In my booth I hear what men say after they get that. They still shout. Only the phone is costlier.")
	else:
		Game.add_rel("meena", 14)
		await say("meena", "...Filmy. Very filmy. (She does not move her hand away from yours.)")
	Game.set_flag("date_on", false)
	Game.set_flag("date_done")
	world.crowd.unpin("meena")
	var n: NPC = world.crowd.node_of("meena")
	if n != null:
		n.no_despawn = false
		n.mode = "idle"
	Game.log_event("Took Meena to the evening show at Sangam Talkies.")
	Sfx.music("", 3.0)
	_scene(false)
	return true

func _m3_godown() -> void:
	_scene(true, true)
	var police: bool = Game.flag("bag") == "police"
	await say("oilkumar", "Anna. The conductor.")
	await say("tiger", "Sit. Kumar, coffee for him. In my godown even enemies get coffee first.")
	await say("tiger", "Subbu kept my accounts eleven years. Yesterday he ran with my election money and died of fright in a public toilet near Shivajinagar. Heart. Imagine. All that planning.")
	if police:
		await say("tiger", "And you. You found eighteen lakhs and carried it - on foot - to Lokesh. Lokesh, who eats from Anthony's plate.")
		await say("tiger", "I should be angry. But in forty years nobody has done something so stupid and so clean in front of me. You actually believed in a police station.")
	else:
		await say("tiger", "And you kept it under a cot in a vatara. No bank, no cousin, no running away to Bombay. You brought it back in a ticket bag.")
		if Game.flag("kitty_took"):
			await say("oilkumar", "Five thousand short, anna.")
			var c0 := await choose(["\"My brother took it. For a TV. I'll pay it back from my salary.\"", "\"It was like that when I found it.\""])
			if c0 == 0:
				Game.add_faction("tiger", 8)
				await say("tiger", "From your salary! Kumar, write it down: one hundred forty-seven instalments. Ha! I like him.")
			else:
				Game.add_faction("tiger", -8)
				await say("tiger", "Subbu's bundles were always full. Don't lie to a flower merchant, boy. We count petals.")
	await say("tiger", "A conductor's bag. Nobody checks it. Police salute it. It goes through every lane in this city by timetable.")
	await say("tiger", "Carry small things for me. Envelopes. From here to there. Five hundred a trip." + (" And we will discuss how you return what Lokesh took." if police else ""))
	var c := await choose(["\"...Five hundred a trip?\"  (accept)", "\"I only issue tickets, saar.\"  (refuse)"])
	if c == 0:
		Game.set_flag("works_for_tiger")
		Game.add_faction("tiger", 15)
		await say("tiger", "Good. Kumar will call. And conductor - you were never here. You only smell of flowers.")
	else:
		Game.add_faction("tiger", -5)
		await say("tiger", "Honest. Twice in two days. It's a disease. Go. But in this city a refusal is also a kind of debt.")
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
	pl.cam.global_position = origin + Vector3(0.6, 1.6, -1.2)
	pl.cam.look_at(origin + Vector3(0, 1.55, 0), Vector3.UP)
	await world.wait(1.4)
	world.slowmo(1.0, false)
	Sfx.music("music_tension", 0.5)
	await say("oilkumar", "ANTHONY'S BOYS! Anna, back room! Conductor - side door, my nephew's scooter is outside. RUN!")
	pl.cam_override = false
	_scene(false)
	Game.add_faction("soda", -5)
	world.leave_interior()
	var gp := place("godown")
	var sc: Vehicle = world.traffic.add_owned("scooter", 2, gp + Vector3(3.5, 0, 0.5), 0.0)
	sc.rotation.y = PI * 0.5
	for i in 3:
		var n: NPC = world.crowd.spawn_actor(Human.random_look(world.crowd.rng, 0, "goon"), {"name": "Anthony's boy", "job": "goon"}, gp + Vector3(-9.0 - i * 2.0, 0, 3.0 + i * 1.5), "raid")
		n.mode = "hostile"
		n.hp = 36.0
	set_step("m3", 3)
	hud.toast("The scooter is yours. RIDE it out of the market - or stand and fight (HIT).")

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
	Sfx.music("", 3.0)
	if escaped:
		_complete("m3", 0, 5, "Walked out of Thimmaiah's godown alive, with his nephew's scooter.")
		Game.add_message("'Oil' Kumar", "Anna says keep the scooter. The nephew is in no condition to ride. Rest two days. Then we talk.")
	else:
		s.missions["m3"] = "done"
		Game.log_event("Wrong Number: woke up in a ward with marigold in your hair.")
	s.mvars["m4_day"] = int(s.day) + 1
	set_step("m3wait", 0)
	Game.save_game(false)

# ------------------------------------------------------------------ M4: The Conductor's Bag
func _m4_brief() -> void:
	await say("oilkumar", "Sit. Don't order, you're working.")
	await say("oilkumar", "Three packets. One for the tailor near your stall. One for the manager's cabin at Sangam Talkies. One for the J.P.P. office in Gandhinagar. Tonight.")
	if not Game.flag("works_for_tiger"):
		await say("oilkumar", "Yes, you refused. Anna heard. Anna has decided you didn't mean it.")
	await say("oilkumar", "Police ask, you are a conductor carrying a conductor's bag. That is the whole plan. It is a good plan because it is true.")
	s.mvars["done_tailor"] = false
	s.mvars["done_cinema"] = false
	s.mvars["done_jpp"] = false
	_check_done = false
	Game.discover("cinema")
	Game.discover("jpp")
	Game.discover("tailor")
	set_step("m4", 1)

func _m4_mark(k: String) -> void:
	s.mvars["done_" + k] = true
	Sfx.play("coin", 0.5)
	hud.toast("Packet delivered.")
	Game.changed.emit()
	if s.mvars.get("done_tailor", false) and s.mvars.get("done_cinema", false) and s.mvars.get("done_jpp", false):
		_complete("m4", 1500, 6, "Three envelopes, one evening. The ticket bag has a second career.")
		set_step("end", 0)
		hud.card("END OF CHAPTER ONE", "The city remembers you now.", 5.0)

func _m4_deliver(k: String) -> void:
	_scene(true)
	if k == "cinema":
		await say("", "The manager takes the packet without looking up from his collection register. \"Tell Thimmaiah the balcony is his on Friday.\"")
		_scene(false)
		_m4_mark(k)
		return
	await say("", "The J.P.P. office: lantern flags, a garlanded photo, eleven men doing nothing with great urgency.")
	await say("channanna", "From the market? Aha. The flower offering for our humble party work. Put, put.")
	await say("channanna", "You are the conductor! Thimmaiah told me. 'An honest fool,' he said. In politics we call that a rare asset.")
	await say("channanna", "This election is a small matter of some crores. Thimmaiah's flowers, Shetty's land, my speeches. Everybody eats, the ward gets a foundation stone.")
	var c := await choose(["\"I only delivered a packet, saar.\"", "\"And the people who lose the land?\"", "Say nothing. Remember everything."])
	if c == 0:
		Game.add_faction("jpp", 6)
		Game.set_flag("helped_jpp")
		await say("channanna", "Exactly the correct answer. You will go far. Or at least to the next stop.")
	elif c == 1:
		Game.add_faction("jpp", -6)
		Game.set_flag("asked_land")
		await say("channanna", "(The smile stays. The eyes leave.) They get... development. Kumar should teach you which questions are free.")
	else:
		Game.set_flag("heard_jpp")
		await say("channanna", "Quiet type. Good. Quiet types become either saints or witnesses. Be a saint.")
	Game.log_event("Heard the M.L.A. explain an election over coffee.")
	_scene(false)
	_m4_mark(k)

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
	await say("basanna", "Morning trip leaves in two minutes. Coming, or are you a big man now?")
	var c := await choose(["Work the morning trip (wages)", "Not today"])
	if c == 0:
		hud.end_talk()
		world.crowd.pin("basanna", DEPOT, -PI * 0.5)
		pl.global_position = DEPOT + Vector3(2.0, 0, 0.5)
		await _start_run(false)
	return true

func _kitty() -> bool:
	if Game.flag("kitty_debt") or int(s.day) < 3 or not s.missions.has("m2"):
		return false
	await say("kitty", "Anna. Don't shout. Promise first you won't shout.")
	await say("kitty", "I took three thousand from Pinto. Anthony's Pinto. For a 'cable TV business'. The business... didn't happen. The interest happened.")
	Game.set_flag("kitty_debt")
	var c := await choose(["Pay it. \"Three thousand. Last time, Kitty.\"" + ("" if Game.can_pay(3000) else "  (not enough money)"), "\"I'll talk to Pinto myself.\"", "\"You borrowed it. Work it off for them.\""])
	if c == 0 and Game.can_pay(3000):
		Game.add_money(-3000, "Kitty's loan")
		Game.set_flag("kitty_settled")
		Game.add_rel("kitty", 12)
		await say("kitty", "I'll return it. With interest. Okay, without interest. But I'll return it.")
	elif c == 2:
		Game.set_flag("kitty_settled")
		Game.set_flag("kitty_soda")
		Game.add_rel("kitty", -10)
		Game.add_faction("soda", 5)
		await say("kitty", "...Fine. Fine! Maybe Anthony treats his people better than my own brother.")
		Game.log_event("Kitty has started running errands for Anthony's people.")
	else:
		world.crowd.pin("pinto", place("bar") + Vector3(2.5, 0, 0.8), PI)
		Game.discover("bar")
		await say("kitty", "He stands outside Kaveri Bar most evenings. Anna - he keeps a cycle chain in his pocket.")
	return true

func _pinto() -> void:
	await say("pinto", "The ticket man. Your brother owes my boss three thousand. Four, with this week.")
	var c := await choose(["Pay four thousand." + ("" if Game.can_pay(4000) else "  (not enough money)"), "\"He's a boy. Close the account or I close it.\"  (fight)", "Walk away."])
	if c == 0 and Game.can_pay(4000):
		Game.add_money(-4000, "Kitty's loan, with interest")
		Game.set_flag("kitty_settled")
		Game.add_rel("kitty", 8)
		world.crowd.unpin("pinto")
		await say("pinto", "Pleasure. Tell him our door is always open.")
	elif c == 1:
		hud.end_talk()
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
					Game.set_flag("kitty_settled")
					Game.add_rep(5)
					Game.add_faction("soda", -12)
					Game.add_rel("kitty", 10)
					world.crowd.unpin("pinto")
					Game.log_event("Settled Kitty's loan with Pinto. Without money.")
					hud.subtitle("Pinto: ...Account closed. For now.", 3.0)
			world.crowd.npc_down.connect(cb, CONNECT_ONE_SHOT)

func _shalini() -> bool:
	if not s.missions.has("m1") or Game.flag("shalini_met"):
		if Game.flag("heard_jpp") or Game.flag("asked_land"):
			if not Game.flag("tipped_press"):
				await say("shalini", "You have the face of a man holding a headline. Off the record. What did you hear in Gandhinagar?")
				var c := await choose(["Tell her about Thimmaiah's flowers, Shetty's land and the M.L.A.", "\"Nothing. I issue tickets.\""])
				if c == 0:
					Game.set_flag("tipped_press")
					Game.add_rel("shalini", 12)
					Game.add_faction("jpp", -10)
					Game.add_faction("knv", 8)
					await say("shalini", "...I can't print it without paper. But now I know where to dig. Rajinikanth - they will ask who talked. Have an answer ready.")
				else:
					await say("shalini", "That's the second-best lie I've heard today. The best was from the Commissioner.")
				return true
		return false
	Game.set_flag("shalini_met")
	await say("shalini", "Shalini Rao, Sanje Vaani. You're the conductor from the 27E. A man jumped off your bus and was found dead in a toilet. I have four questions.")
	var c2 := await choose(["\"He paid with a hundred and told me to keep the change. That's all I know.\"", "\"No comments.\"", "\"Who told you which bus?\""])
	if c2 == 0:
		Game.add_rel("shalini", 6)
		await say("shalini", "A cashier who tips ninety-five rupees. Thank you. That's the first true sentence in this whole story.")
	elif c2 == 1:
		await say("shalini", "'No comments.' You've been watching the news. Here's my number. People like you always call eventually.")
	else:
		Game.add_rel("shalini", 3)
		await say("shalini", "Good instinct. The station writer, for fifty rupees. Which means others bought it too.")
	Game.add_contact("shalini")
	return true

# ------------------------------------------------------------------ the living city
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
		if a in ["m3", "m3wait", "m4"]:
			return "\"...Anthony has bought the Upparpet station, I'm telling you. Thimmaiah's cash went in and never came out. There will be flowers on somebody's photo before Deepavali.\""
		return "\"...Shetty is buying everything behind Peenya. Farmers sign in the morning, the registrar signs at night. Channanna's blessings, obviously.\""
	if a == "m0": return "They're saying Thimmaiah's cashier has been drinking alone. A cashier who drinks alone is counting something that isn't his."
	if a == "m2": return "You look like you saw a ghost and the ghost gave you homework. Go home, Raji."
	if a in ["m3", "m3wait"]: return "Subbu the cashier - found in the pay-and-use toilet near Shivajinagar stand. Heart. The attendant is angry; he died owing one rupee."
	if a == "m4" or a == "end": return "People are saying your name near the market. Quietly. I don't know if that is good. In my experience it is never good."
	return "Election time. Every tea I sell comes with a free manifesto."

func radio() -> String:
	var lead := "Janata Pragathi Paksha" if float(s.politics.jpp) >= float(s.politics.knv) else "Karnataka Nava Nirmana Vedike"
	return ["This is Akashvani Bangalore. The time is %s. Light rain is expected, or not." % Game.clock_text(),
		"...and in Majestic constituency observers say the %s holds a narrow lead. Now, a film song from 'Mallige Manasu'." % lead,
		"Load-shedding in the following areas from six to eight: Chickpet, Cottonpet, Majestic, and wherever you are listening from."][int(s.day + s.time) % 3]

func headlines() -> Array:
	var out: Array = []
	if s.missions.has("m1"):
		out.append("CRIME: Flower-market cashier found dead in public convenience. Police say 'natural'. Colleagues say he left with 'a heavy bag'.")
	if s.missions.has("m3"):
		out.append("GANG CLASH at K.R. Market godown: flowers worth Rs 40,000 destroyed, three injured. Upparpet police 'investigating'.")
	if Game.flag("tipped_press"):
		out.append("EXCLUSIVE by Shalini Rao: Who is buying Peenya? Land records, a steel baron and a sitting M.L.A.")
	if Game.flag("caught_thief"):
		out.append("CITY: Chain-snatcher caught by off-duty B.C.T.S. conductor. \"I only wanted his ticket,\" he reportedly said.")
	if out.is_empty():
		out.append("CRIME: Quiet night in the city, say police. Readers are advised to remain suspicious.")
	return out
