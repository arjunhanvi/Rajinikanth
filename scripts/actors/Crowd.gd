class_name Crowd
extends Node3D
## Population manager. Named characters live on their schedules all the time
## (abstractly when far away, physically when near); ambient pedestrians,
## loiterers and police are streamed in around the player.

signal npc_down(npc)

var world
var npcs: Array = []          # active NPC nodes
var named := {}               # id -> {pos: Vector2, place, mode, path, pidx, node, pin}
var rng := RandomNumberGenerator.new()
var _acc := 0.0
var _chat_t := 3.0
var _cops_out := 0.0
var player_hp_cb: Callable

const BARKS := ["Howdu, howdu.", "Aiyo, what to do?", "Swalpa adjust maadi.", "Chennagide.", "Tomorrow, pakka.", "Rate is too much.", "Who told you?", "Haagalla, listen...", "Bus late again.", "One by-two.", "Solpa wait.", "Guru, is it true?", "Election time, no?", "He said, she said."]

func _ready() -> void:
	rng.randomize()
	for id in People.DB:
		var sl := People.slot(id, float(Game.s.time))
		var a := anchor_for(sl[0], sl[1], id)
		named[id] = {"pos": Vector2(a.pos.x, a.pos.z), "place": sl[0], "mode": sl[1], "path": PackedVector2Array(), "pidx": 0, "node": null, "pin": null, "anchor": a}

# ------------------------------------------------------------------ anchors
## Where somebody stands for (place, mode): {pos: Vector3, yaw: float, sit: bool}
func anchor_for(place: String, mode: String, salt: String) -> Dictionary:
	var h := absi(hash(salt + place))
	if City.sites.has(place):
		var s = City.sites[place]
		var f := Vector3(s.fwd.x, 0, s.fwd.y)
		var r := Vector3.UP.cross(f)
		var front := Vector3(s.front.x, 0, s.front.y)
		var yaw := atan2(-f.x, -f.z)
		if mode == "in":
			if s.type == "tea":
				return {"pos": front - f * 2.3, "yaw": yaw, "sit": false}
			return {"pos": front + f * 0.7 + r * (float(s.w) * 0.25), "yaw": yaw, "sit": false}
		if mode == "sit" and s.type == "tea":
			var sd := 1.0 if h % 2 == 0 else -1.0
			var along := -0.8 + 0.8 * float((h / 2) % 3)
			return {"pos": front + f * (1.0 + along) + r * sd * (float(s.w) * 0.5 + 0.2), "yaw": atan2(r.x * sd, r.z * sd), "sit": true}
		var ox := -3.0 + float(h % 7)
		var oz := 1.2 + float((h / 7) % 4) * 0.7
		return {"pos": front + f * oz + r * ox, "yaw": yaw + PI + (float(h % 5) - 2.0) * 0.3, "sit": false}
	var p: Vector3 = City.PLACES[place].pos if City.PLACES.has(place) else Vector3.ZERO
	return {"pos": p + Vector3(-4.0 + float(h % 9), 0, -3.0 + float((h / 9) % 7)), "yaw": float(h % 6), "sit": false}

# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	if world == null or world.player == null or get_tree().paused:
		return
	for n in npcs.duplicate():
		if is_instance_valid(n):
			n.tick(delta, self)
	_acc += delta
	if _acc >= 0.4:
		var dt := _acc
		_acc = 0.0
		_named_tick(dt)
		_ambient_tick()
		_police_tick(dt)
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(2.5, 6.0)
		_street_chatter()

func ppos() -> Vector2:
	var p: Vector3 = world.player.global_position if world.interior == "" else Vector3(world.exterior_pos.x, 0, world.exterior_pos.y)
	return Vector2(p.x, p.z)

func _named_tick(dt: float) -> void:
	var t := float(Game.s.time)
	var pp := ppos()
	for id in named:
		var rec = named[id]
		var want: Array = People.slot(id, t)
		var a: Dictionary
		if rec.pin != null:
			want = ["_pin", rec.pin.mode]
			a = rec.pin
		else:
			a = anchor_for(want[0], want[1], id)
		if want[0] != rec.place or want[1] != rec.mode:
			rec.place = want[0]
			rec.mode = want[1]
			rec.anchor = a
			rec.path = City.street_path(rec.pos, Vector2(a.pos.x, a.pos.z))
			rec.pidx = 0
			var plen := 0.0
			var prev: Vector2 = rec.pos
			for q in rec.path:
				plen += prev.distance_to(q)
				prev = q
			rec.plen = plen
			if rec.node != null and is_instance_valid(rec.node):
				rec.node.sit = false
				rec.node.human.state = "idle"
				rec.node.go(rec.path, "arrived")
		var node: NPC = rec.node if (rec.node != null and is_instance_valid(rec.node)) else null
		if node != null:
			rec.pos = node.p2()
			if node.mode == "arrived":
				rec.path = PackedVector2Array()
				_settle(node, rec)
			if rec.pos.distance_to(pp) > 115.0 and not node.no_despawn:
				remove(node)
				rec.node = null
		else:
			# abstract simulation: keep walking the route even when nobody is watching
			if rec.pidx < rec.path.size():
				# off-screen commutes are compressed so a cross-town trip takes ~20 game minutes
				var step: float = maxf(1.4, float(rec.get("plen", 0.0)) / 40.0) * dt
				while step > 0.0 and rec.pidx < rec.path.size():
					var to: Vector2 = rec.path[rec.pidx]
					var d: float = rec.pos.distance_to(to)
					if d <= step:
						rec.pos = to
						rec.pidx += 1
						step -= d
					else:
						rec.pos = rec.pos.move_toward(to, step)
						step = 0.0
			var travelling: bool = rec.pidx < rec.path.size()
			if (rec.mode != "off" or travelling) and rec.pos.distance_to(pp) < 85.0 and world.interior == "":
				_spawn_named(id, rec, travelling)

func _spawn_named(id: String, rec: Dictionary, travelling: bool) -> void:
	var n := NPC.new()
	n.setup(People.look_of(id), {"name": People.NAMES[id], "job": People.DB[id].job}, id)
	add_child(n)
	n.global_position = Vector3(rec.pos.x, 0, rec.pos.y)
	npcs.append(n)
	rec.node = n
	if travelling:
		var rest := PackedVector2Array()
		for i in range(rec.pidx, rec.path.size()):
			rest.append(rec.path[i])
		n.go(rest, "arrived")
	else:
		_settle(n, rec)

func _settle(n: NPC, rec: Dictionary) -> void:
	if rec.mode == "off":
		remove(n)
		rec.node = null
		return
	var a: Dictionary = rec.anchor
	n.global_position = a.pos
	n.face_yaw = a.yaw
	n.human.rotation.y = a.yaw
	n.sit = a.get("sit", false)
	n.human.state = "sit" if n.sit else "idle"
	n.mode = "idle"

## After a time jump (sleeping, travelling) put everyone where their schedule says.
func resync() -> void:
	var t := float(Game.s.time)
	for id in named:
		var rec = named[id]
		if rec.pin != null:
			continue
		var want: Array = People.slot(id, t)
		var a := anchor_for(want[0], want[1], id)
		rec.place = want[0]
		rec.mode = want[1]
		rec.anchor = a
		rec.pos = Vector2(a.pos.x, a.pos.z)
		rec.path = PackedVector2Array()
		rec.pidx = 0
		if rec.node != null and is_instance_valid(rec.node):
			_settle(rec.node, rec)

## Story control: hold a named character at an exact spot (overrides the schedule).
func pin(id: String, pos: Vector3, yaw := 0.0, sit := false) -> void:
	var rec = named[id]
	rec.pin = {"pos": pos, "yaw": yaw, "sit": sit, "mode": "pin"}
	rec.place = "_pin"
	rec.mode = "pin"
	rec.anchor = rec.pin
	rec.pos = Vector2(pos.x, pos.z)
	rec.path = PackedVector2Array()
	if rec.node != null and is_instance_valid(rec.node):
		_settle(rec.node, rec)

func unpin(id: String) -> void:
	named[id].pin = null

func node_of(id: String) -> NPC:
	var rec = named.get(id)
	if rec != null and rec.node != null and is_instance_valid(rec.node):
		return rec.node
	return null

func named_pos(id: String) -> Vector3:
	var rec = named[id]
	return Vector3(rec.pos.x, 0, rec.pos.y)

func ensure(id: String) -> NPC:
	var n := node_of(id)
	if n == null:
		_spawn_named(id, named[id], false)
		n = node_of(id)
	return n

## Story extras (passengers, thugs): not part of the ambient pool.
func spawn_actor(look: Dictionary, ident: Dictionary, pos: Vector3, tag: String, yaw := 0.0) -> NPC:
	var n := NPC.new()
	n.setup(look, ident)
	n.story_tag = tag
	n.no_despawn = true
	add_child(n)
	n.global_position = pos
	n.face_yaw = yaw
	n.human.rotation.y = yaw
	npcs.append(n)
	return n

func actors(tag: String) -> Array:
	var out: Array = []
	for n in npcs:
		if is_instance_valid(n) and n.story_tag == tag:
			out.append(n)
	return out

func clear_actors(tag: String) -> void:
	for n in actors(tag):
		remove(n)

func remove(n: NPC) -> void:
	npcs.erase(n)
	if n.id != "" and named.has(n.id) and named[n.id].node == n:
		named[n.id].node = null
	n.queue_free()

# ------------------------------------------------------------------ ambient life
func time_factor() -> float:
	var t := float(Game.s.time)
	var f := 0.8
	if t < 5.0: f = 0.12
	elif t < 7.0: f = 0.5
	elif t < 10.0: f = 1.0
	elif t < 16.0: f = 0.8
	elif t < 20.0: f = 1.0
	elif t < 22.0: f = 0.6
	else: f = 0.25
	if Game.s.weather == "rain":
		f *= 0.5
	return f

func _ambient_tick() -> void:
	var pp := ppos()
	var count := 0
	for n in npcs.duplicate():
		if not is_instance_valid(n):
			npcs.erase(n)
			continue
		if n.id == "" and n.story_tag == "":
			if n.p2().distance_to(pp) > 100.0:
				remove(n)
			else:
				count += 1
	if world.interior != "" or world.player.bus != null and false:
		return
	var d := City.district(pp)
	var want := int(float(Game.gfx("npcs")) * time_factor() * clampf(float(d.density) + 0.2, 0.0, 1.0))
	var tries := 0
	while count < want and tries < 3:
		tries += 1
		if _spawn_ambient(pp, d.kind):
			count += 1

func _spawn_ambient(pp: Vector2, kind: String) -> bool:
	var stander := rng.randf() < 0.3
	var ax := rng.randi() % 2
	var cell := Vector2(roundf(pp.x / City.GRID), roundf(pp.y / City.GRID))
	var ln := ((cell.y if ax == 0 else cell.x) + float(rng.randi_range(-1, 1))) * City.GRID
	var base := pp.x if ax == 0 else pp.y
	var along := base + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(38.0, 80.0)
	var sd := 1.0 if rng.randf() < 0.5 else -1.0
	var pos := Vector2(along, ln + sd * 3.0) if ax == 0 else Vector2(ln + sd * 3.0, along)
	if City.district(pos).kind == "rural" or City.on_arterial(pos, 1.0):
		return false
	var z = City.in_zone(pos)
	if z != null and z.kind in ["lake", "airport", "railstation", "vidhana", "temple", "site"]:
		return false
	var ident := People.random_identity(rng, kind)
	var n := NPC.new()
	n.setup(Human.random_look(rng, ident.sex), ident)
	add_child(n)
	n.global_position = Vector3(pos.x, 0, pos.y)
	npcs.append(n)
	if stander:
		# linger at a shop front; sometimes with company
		var away := Vector2(0, sd) if ax == 0 else Vector2(sd, 0)
		n.global_position += Vector3(away.x, 0, away.y) * 0.7
		n.face_yaw = atan2(away.x, away.y) + PI if rng.randf() < 0.5 else atan2(-away.x, -away.y) + PI
		n.human.rotation.y = n.face_yaw
		n.mode = "idle"
		if rng.randf() < 0.5:
			var id2 := People.random_identity(rng, kind)
			var m := NPC.new()
			m.setup(Human.random_look(rng, id2.sex), id2)
			add_child(m)
			var fw := Vector2(1, 0) if ax == 0 else Vector2(0, 1)
			m.global_position = n.global_position + Vector3(fw.x, 0, fw.y) * 1.1
			npcs.append(m)
			m.partner = n
			n.partner = m
			m.mode = "idle"
	else:
		n.start_grid(ax, ln, sd, 1.0 if along < base else -1.0)
	return true

func _street_chatter() -> void:
	var pp: Vector3 = world.player.global_position
	var cands: Array = []
	for n in npcs:
		if is_instance_valid(n) and n.mode == "idle" and n.global_position.distance_to(pp) < 14.0:
			if n.partner != null or n.sit or n.id != "":
				cands.append(n)
	if cands.is_empty():
		return
	var pick: NPC = cands[rng.randi() % cands.size()]
	var line: String = BARKS[rng.randi() % BARKS.size()]
	pick.say_bubble(line)
	if world.hud != null and pick.global_position.distance_to(pp) < 6.0:
		world.hud.subtitle("%s: %s" % [pick.display_name(), line], 2.4)

# ------------------------------------------------------------------ interaction
func nearest_talkable(pos: Vector3, r: float) -> NPC:
	var best: NPC = null
	var bd := r
	for n in npcs:
		if not is_instance_valid(n) or n.mode in ["ko", "flee", "hostile", "cop"]:
			continue
		var d: float = n.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = n
	return best

func talk(n: NPC) -> void:
	var pl: Player = world.player
	pl.locked = true
	n.face(pl.global_position)
	pl.human.rotation.y = atan2(-(n.global_position.x - pl.global_position.x), -(n.global_position.z - pl.global_position.z))
	var was := n.mode
	if n.mode in ["grid", "walk"]:
		n.mode = "idle" if was == "grid" else "paused"
	n.human.speed = 0.0
	Game.s.stats.talks = int(Game.s.stats.talks) + 1
	var handled: bool = await world.story.on_talk(n)
	if not handled:
		if n.id != "":
			await _named_chat(n)
		else:
			n.human.talk_t = 2.0
			await world.hud.say("%s  (%s)" % [n.display_name(), n.ident.job], People.ambient_line(n.ident, rng))
	world.hud.end_talk()
	pl.locked = false
	if is_instance_valid(n):
		if was == "grid" and n.mode == "idle":
			n.mode = "grid"
		elif n.mode == "paused":
			n.mode = "walk"

func _named_chat(n: NPC) -> void:
	var id := n.id
	var nm: String = People.NAMES[id]
	var hud = world.hud
	n.human.talk_t = 3.0
	if not Game.recalls(id, "met"):
		Game.remember(id, "met")
		await hud.say(nm, People.CHAT[id][0])
		await hud.say("", "%s - %s" % [nm, People.role(id)])
		return
	if Game.recalls(id, "hit"):
		await hud.say(nm, "After what you did? Keep walking.")
		return
	var lines: Array = People.CHAT[id]
	var key := "chat_day%d" % int(Game.s.day)
	await hud.say(nm, lines[rng.randi() % lines.size()])
	if not Game.recalls(id, key) and id in ["nanjappa", "meena", "basanna", "kitty", "immu", "shalini"]:
		Game.remember(id, key)
		Game.s.rel[id] = clampi(Game.rel(id) + 1, -100, 100)

func alarm(pos: Vector3, radius: float) -> void:
	for n in npcs:
		if is_instance_valid(n) and n.global_position.distance_to(pos) < radius:
			n.alarm(pos)

func player_punch(pos: Vector3, _dir: Vector3) -> void:
	for n in npcs.duplicate():
		if not is_instance_valid(n) or n.mode == "ko":
			continue
		if n.global_position.distance_to(pos) < 1.15:
			Sfx.play("punch", 0.8, randf_range(0.9, 1.1))
			n.human.play_once("hit", 0.3)
			if n.mode in ["hostile"]:
				n.hp -= 12.0
				if n.hp <= 0.0:
					n.knock_out(60.0)
					npc_down.emit(n)
			elif n.mode == "cop":
				n.hp -= 12.0
				Game.add_heat(15.0)
				if n.hp <= 0.0:
					n.knock_out(30.0)
			elif n.id != "":
				Game.remember(n.id, "hit")
				Game.s.rel[n.id] = clampi(Game.rel(n.id) - 15, -100, 100)
				n.say_bubble("Ey! Have you gone mad?")
				Game.add_heat(4.0)
			elif n.story_tag == "thief":
				n.knock_out(30.0)
				n.no_despawn = false
				npc_down.emit(n)
			elif n.story_tag != "":
				n.say_bubble("Ey!")
			else:
				n.knock_out(12.0)
				Game.add_heat(12.0)
				Game.add_rep(1 if int(Game.s.rep) >= 30 else -1)
				alarm(pos, 16.0)
			return

func hit_player(dmg: float) -> void:
	Sfx.play("punch", 0.9, 0.8)
	world.player.human.play_once("hit", 0.3)
	Game.s.hp = float(Game.s.hp) - dmg
	Game.changed.emit()
	if float(Game.s.hp) <= 0.0:
		world.player_down()

func vehicle_hits(veh: Vehicle) -> void:
	if absf(veh.v) < 3.0:
		return
	var fwd := -veh.global_transform.basis.z * signf(veh.v)
	var front := veh.global_position + fwd * (float(veh.spec.l) * 0.5)
	for n in npcs.duplicate():
		if is_instance_valid(n) and n.mode != "ko" and n.global_position.distance_to(front) < float(veh.spec.w) * 0.5 + 0.5:
			n.knock_out(20.0)
			Sfx.play("punch", 1.0, 0.7)
			Game.add_heat(25.0)
			alarm(front, 22.0)
			veh.v *= 0.6

## Is somebody on foot in the way? (traffic uses this to brake for pedestrians)
func ped_ahead(pos: Vector3, fwd: Vector3, dist: float) -> bool:
	for n in npcs:
		if not is_instance_valid(n):
			continue
		var d: Vector3 = n.global_position - pos
		var f := d.dot(fwd)
		if f > 0.5 and f < dist and absf(d.dot(Vector3(fwd.z, 0, -fwd.x))) < 1.5:
			return true
	return false

# ------------------------------------------------------------------ police
func _police_tick(dt: float) -> void:
	var heat := float(Game.s.heat)
	var cops: Array = []
	for n in npcs:
		if is_instance_valid(n) and n.mode == "cop":
			cops.append(n)
	if heat >= 20.0 and world.interior == "" and world.player.bus == null:
		var want := 1 + int(heat / 40.0)
		if cops.size() < want:
			var pp: Vector3 = world.player.global_position
			var ang := rng.randf() * TAU
			var pos: Vector3 = pp + Vector3(cos(ang), 0, sin(ang)) * 45.0
			var cop := spawn_actor(Human.random_look(rng, 0, "police"), {"name": "Constable", "job": "police constable"}, pos, "")
			cop.no_despawn = false
			cop.mode = "cop"
			cop.hp = 40.0
			Sfx.play("whistle", 0.5)
			world.hud.subtitle("Constable: Ey! Nillo! Stop there!", 2.5)
		_cops_out = 0.0
	var near := false
	for n in cops:
		if n.global_position.distance_to(world.player.global_position) < 55.0:
			near = true
	if heat > 0.0 and not near:
		Game.s.heat = maxf(0.0, heat - dt * 2.2)
		if int(heat) != int(Game.s.heat):
			Game.changed.emit()
	if float(Game.s.heat) < 5.0:
		for n in cops:
			n.mode = "flee"
			n.timer = 1.0
			n.no_despawn = false
			n.story_tag = ""

func arrest(_cop: NPC) -> void:
	if world.busy:
		return
	world.arrested()
