class_name Shops
extends RefCounted
## The everyday economy: tea, tiffin, clothes, vehicles, cinema, property,
## buses and autos, the evening paper, sleeping and the wardrobe.

const FREE := {"top": [0, 1, 3, 4, 5, 7], "bottom": [0, 2, 3], "shoes": [0, 3, 4], "glasses": [0], "watch": [0, 3], "acc": [0, 3, 4]}
# [slot, index, price]
const TAILOR := [["top", 2, 180], ["top", 6, 650], ["bottom", 1, 350], ["shoes", 1, 400], ["shoes", 2, 220], ["glasses", 1, 90], ["glasses", 3, 90],
	["glasses", 2, 150], ["watch", 1, 300], ["watch", 2, 1800], ["acc", 1, 2500], ["acc", 2, 40]]
const SLOT_NAMES := {"top": Human.TOPS, "bottom": Human.BOTTOMS, "shoes": Human.SHOES, "glasses": Human.GLASSES, "watch": Human.WATCHES, "acc": Human.ACCS}
const COLOUR_NAMES := ["White", "Khaki", "Sky blue", "Navy", "Red", "Bottle green", "Mustard", "Violet", "Black", "Brown", "Rose", "Teal", "Grey", "Orange"]
const DEALER := [["scooter", 9000], ["bike", 22000], ["auto", 28000], ["hatch", 60000], ["car", 85000]]

static func eat(world, name: String, price: int, hp: float) -> bool:
	if not Game.can_pay(price):
		world.hud.toast("Not enough money.")
		return false
	Game.add_money(-price, name)
	Game.s.hp = minf(100.0, float(Game.s.hp) + hp)
	return true

## Generic conversations with shopkeepers. Returns true if it handled the talk.
static func talk(world, n: NPC) -> bool:
	var hud = world.hud
	var nm: String = n.display_name()
	match n.id:
		"nanjappa":
			await hud.say(nm, People.CHAT["nanjappa"][world.crowd.rng.randi() % 4])
			var c: int = await hud.menu("Nanjappa's Tea Stall", [{"text": "By-two coffee", "sub": "Rs 2"}, {"text": "Bun and butter", "sub": "Rs 3"},
				{"text": "Sanje Vaani (evening paper)", "sub": "Rs 2"}, {"text": "\"Any news, Nanjappa?\"", "sub": "free"}])
			if c == 0: eat(world, "coffee", 2, 10.0)
			elif c == 1: eat(world, "bun", 3, 18.0)
			elif c == 2 and eat(world, "newspaper", 2, 0.0): await newspaper(world)
			elif c == 3: await hud.say(nm, world.story.gossip())
			return true
		"bhatta":
			await hud.say(nm, People.CHAT["bhatta"][world.crowd.rng.randi() % 2])
			var c2: int = await hud.menu("Hotel Dwaraka Darshini", [{"text": "Idli-vada", "sub": "Rs 8"}, {"text": "Masala dosa", "sub": "Rs 12"}, {"text": "Curd rice", "sub": "Rs 7"}, {"text": "Coffee", "sub": "Rs 4"}])
			if c2 >= 0:
				eat(world, ["idli-vada", "masala dosa", "curd rice", "coffee"][c2], [8, 12, 7, 4][c2], [40.0, 60.0, 35.0, 12.0][c2])
			return true
		"balaji":
			await hud.say(nm, People.CHAT["balaji"][world.crowd.rng.randi() % 2])
			var items: Array = []
			for d in DEALER:
				items.append({"text": Vehicle.SPECS[d[0]].name, "sub": "Rs %d" % d[1], "disabled": not Game.can_pay(d[1])})
			var c3: int = await hud.menu("Sri Balaji Auto Consultants", items, "All vehicles single owner. Papers 'almost' clear.")
			if c3 >= 0:
				Game.add_money(-int(DEALER[c3][1]), Vehicle.SPECS[DEALER[c3][0]].name)
				var s = City.sites["dealer"]
				var pos := Vector3(s.front.x + 6.0, 0, s.front.y + s.fwd.y * 3.0)
				world.traffic.add_owned(DEALER[c3][0], world.crowd.rng.randi() % Vehicle.PAINT.size(), pos, PI * 0.5)
				Game.add_rep(2)
				Game.log_event("Bought a %s from Balaji." % Vehicle.SPECS[DEALER[c3][0]].name)
				await hud.say(nm, "Parked right outside. Any problem, you don't know me.")
			return true
		"rafiq":
			await hud.say(nm, People.CHAT["rafiq"][world.crowd.rng.randi() % 2])
			await tailor(world)
			return true
		"mani":
			await hud.say(nm, People.CHAT["mani"][world.crowd.rng.randi() % 2])
			await bar(world)
			return true
		"immu":
			await hud.say(nm, People.CHAT["immu"][world.crowd.rng.randi() % 3])
			await auto_travel(world, "Immu's auto")
			return true
	if n.id == "" and n.ident.get("job", "") == "flower seller":
		await hud.say(nm, People.BY_JOB["flower seller"])
		var c4: int = await hud.menu("Flowers", [{"text": "A mola of jasmine", "sub": "Rs 5"}])
		if c4 == 0 and eat(world, "jasmine", 5, 0.0):
			Game.set_flag("jasmine")
		return true
	return false

static func bar(world) -> void:
	var c: int = await world.hud.menu("Kaveri Bar & Restaurant", [{"text": "Old Cask rum, small", "sub": "Rs 25"}, {"text": "Egg bhurji", "sub": "Rs 15"}, {"text": "Listen to the next table", "sub": "free, if you are careful"}])
	if c == 0: eat(world, "rum", 25, 8.0)
	elif c == 1: eat(world, "egg bhurji", 15, 30.0)
	elif c == 2: await world.hud.say("", world.story.gossip(true))

static func interior(world, id: String, key: String) -> void:
	match key:
		"sleep": await sleep(world)
		"wardrobe": await wardrobe(world)
		"radio":
			await world.hud.say("Akashvani Bangalore", world.story.radio())
			world.hud.end_talk()
		"bar": await bar(world)
		"tailor": await tailor(world)
		"backdoor": world.hud.toast("Bolted from the other side.")

static func sleep(world) -> void:
	world.busy = true
	await world.hud.fade(1.0, 0.8)
	var t := float(Game.s.time)
	var hrs := (30.0 - t) if t > 6.0 else (6.0 - t)
	if t >= 6.0 and t < 19.0:
		hrs = 2.0     # an afternoon nap
	world.pass_time(hrs)
	Game.s.hp = 100.0
	Game.s.heat = 0.0
	world.busy = false
	Game.save_game(false)
	await world.hud.fade(0.0, 0.8)
	world.hud.toast("Day %d, %s. Game saved." % [int(Game.s.day), Game.clock_text()])
	world.story.on_wake()

static func owns(slot: String, i: int) -> bool:
	return FREE[slot].has(i) or Game.s.wardrobe.has("%s:%d" % [slot, i])

static func wardrobe(world) -> void:
	var look: Dictionary = Game.s.look
	while true:
		var items: Array = []
		for slot in ["top", "bottom", "shoes", "glasses", "watch", "acc"]:
			items.append({"text": "%s: %s" % [slot.capitalize(), SLOT_NAMES[slot][int(look[slot])]], "sub": "tap to change"})
		items.append({"text": "Shirt colour: %s" % COLOUR_NAMES[int(look.top_col) % 14], "sub": "tap to change"})
		items.append({"text": "Lower colour: %s" % COLOUR_NAMES[int(look.bot_col) % 14], "sub": "tap to change"})
		var c: int = await world.hud.menu("Steel Trunk - Your Clothes", items, "Everything you own is in here. Buy more at New Modern Tailors.")
		if c < 0:
			break
		if c < 6:
			var slot: String = ["top", "bottom", "shoes", "glasses", "watch", "acc"][c]
			var n: int = SLOT_NAMES[slot].size()
			var i := int(look[slot])
			for k in n:
				i = (i + 1) % n
				if owns(slot, i) and not (slot == "top" and i >= 8) and not (slot == "bottom" and i >= 4) and not (slot == "acc" and i == 5):
					break
			look[slot] = i
		elif c == 6:
			look.top_col = (int(look.top_col) + 1) % 14
		else:
			look.bot_col = (int(look.bot_col) + 1) % 14
		world.player.set_look(look)
	Game.s.look = look

static func tailor(world) -> void:
	while true:
		var items: Array = []
		for t in TAILOR:
			var have: bool = Game.s.wardrobe.has("%s:%d" % [t[0], t[1]])
			items.append({"text": SLOT_NAMES[t[0]][t[1]], "sub": "owned" if have else "Rs %d" % t[2], "disabled": have or not Game.can_pay(t[2])})
		var c: int = await world.hud.menu("New Modern Tailors", items, "Bought items go to the steel trunk in your room.")
		if c < 0:
			break
		var it = TAILOR[c]
		Game.add_money(-int(it[2]), SLOT_NAMES[it[0]][it[1]])
		Game.s.wardrobe.append("%s:%d" % [it[0], it[1]])
		Game.s.look[it[0]] = it[1]
		world.player.set_look(Game.s.look)
		Game.add_rep(1)

static func place(world, id: String) -> void:
	var hud = world.hud
	match id:
		"cinema":
			if await world.story.on_cinema():
				return
			var c: int = await hud.menu("Sangam Talkies", [{"text": "Benki Basava - Gandhi class", "sub": "Rs 8"}, {"text": "Benki Basava - Balcony", "sub": "Rs 15"}], "Four shows daily. Three hours you will never get back.")
			if c >= 0 and eat(world, "cinema ticket", 8 if c == 0 else 15, 5.0):
				await world.travel(City.PLACES["cinema"].pos, 3.0)
				hud.subtitle("The hero walked away from an explosion. The interval samosa was better.", 4.0)
		"flat":
			if Game.s.props.has("Jayanagar flat"):
				hud.toast("Your flat. The neighbours still think you are a bank officer.")
				return
			var c2: int = await hud.menu("Flat for Sale - Jayanagar 4th Block", [{"text": "Buy the flat", "sub": "Rs 2,50,000", "disabled": not Game.can_pay(250000)}], "Two bedrooms, Cauvery water (sometimes), respectable neighbours.")
			if c2 == 0:
				Game.add_money(-250000, "Jayanagar flat")
				Game.s.props.append("Jayanagar flat")
				Game.add_rep(15)
				Game.log_event("Bought a flat in Jayanagar. Amma would not believe it.")
		"market":
			var c3: int = await hud.menu("K.R. Market", [{"text": "A mola of jasmine", "sub": "Rs 5"}, {"text": "Bananas, half dozen", "sub": "Rs 6"}])
			if c3 == 0 and eat(world, "jasmine", 5, 0.0):
				Game.set_flag("jasmine")
			elif c3 == 1:
				eat(world, "bananas", 6, 25.0)

static func bus_travel(world, stop_id: String) -> void:
	var here: Vector2 = City.stops[stop_id].pos
	var ids: Array = City.nodes.keys()
	ids.erase(stop_id)
	ids.sort_custom(func(a, b): return City.stops[a].pos.distance_to(here) < City.stops[b].pos.distance_to(here))
	var items: Array = []
	for id in ids:
		var d: float = City.stops[id].pos.distance_to(here)
		items.append({"text": City.nodes[id].name, "sub": "Rs %d  -  about %d min" % [_bus_fare(d), int(d / 12.0) + 10]})
	var c: int = await world.hud.menu("Bus Stop - %s" % City.nodes[stop_id].name, items, "B.C.T.S. city buses. Exact change, please.")
	if c < 0:
		return
	var dest: String = ids[c]
	var dist: float = City.stops[dest].pos.distance_to(here)
	if not eat(world, "bus ticket", _bus_fare(dist), 0.0):
		return
	var sp: Vector2 = City.stops[dest].pos
	var dd: Vector2 = City.stops[dest].dir
	var left := Vector2(dd.y, -dd.x)
	Sfx.play("bell")
	await world.travel(Vector3(sp.x + left.x * 1.5, 0, sp.y + left.y * 1.5), (dist / 12.0 + 10.0) / 60.0)
	Game.discover(dest)
	world.hud.subtitle("Conductor: %s! %s! Get down, get down!" % [City.nodes[dest].name, City.nodes[dest].name], 3.0)

static func _bus_fare(d: float) -> int:
	return clampi(2 + int(d / 350.0), 2, 9)

static func auto_travel(world, title: String) -> void:
	var here: Vector3 = world.player.global_position
	var ids: Array = []
	for id in Game.s.discovered:
		if City.PLACES.has(id) and City.PLACES[id].pos.distance_to(here) > 40.0:
			ids.append(id)
	ids.sort_custom(func(a, b): return City.PLACES[a].pos.distance_to(here) < City.PLACES[b].pos.distance_to(here))
	var items: Array = []
	for id in ids:
		var d: float = City.PLACES[id].pos.distance_to(here)
		var fare := 8 + int(d / 45.0)
		items.append({"text": City.PLACES[id].name, "sub": "Rs %d on the meter" % fare, "disabled": not Game.can_pay(fare)})
	var c: int = await world.hud.menu(title, items, "\"Where to, saar? One-and-a-half after ten.\"")
	if c < 0:
		return
	var dist: float = City.PLACES[ids[c]].pos.distance_to(here)
	Game.add_money(-(8 + int(dist / 45.0)), "auto fare")
	Sfx.play("horn_auto")
	await world.travel(City.PLACES[ids[c]].pos, dist / 6000.0 + 0.08)

static func newspaper(world) -> void:
	var hud = world.hud
	var s: Dictionary = Game.s
	var lead := "J.P.P." if float(s.politics.jpp) >= float(s.politics.knv) else "K.N.V."
	var lines: Array = ["SANJE VAANI  -  Day %d  -  Price Rs 2" % int(s.day),
		"ELECTION: %s ahead in Majestic, says our survey (J.P.P. %d%%, K.N.V. %d%%). Both parties call the survey 'paid'." % [lead, int(s.politics.jpp), int(s.politics.knv)]]
	lines.append_array(world.story.headlines())
	lines.append(["WEATHER: Pleasant. As always. That is the one thing they cannot take away.", "CIVIC: Corporation promises pothole-free roads 'by Dasara'. Year not specified.",
		"CINEMA: 'Benki Basava' enters 15th week. Fans pour milk on cut-out, traffic stopped for an hour."][int(s.day) % 3])
	for l in lines:
		await hud.say("Sanje Vaani", l)
	hud.end_talk()
