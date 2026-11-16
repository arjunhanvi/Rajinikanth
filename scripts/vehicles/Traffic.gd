class_name Traffic
extends Node3D
## Period traffic on the arterial network: left-hand driving, car-following,
## junction slowing, buses that halt at stops, braking for people, plus parked
## and player-owned vehicles.

signal bus_arrived(veh, node_id)

var world
var moving: Array = []        # AI vehicles on the road network
var owned: Array = []         # player's vehicles (persist)
var taken: Array = []         # borrowed parked vehicles kept alive
var rng := RandomNumberGenerator.new()
var _acc := 0.0

const MIX := [["auto", 24], ["bike", 18], ["scooter", 16], ["car", 14], ["hatch", 9], ["taxi", 4], ["bus", 8], ["pbus", 2], ["truck", 6]]
const PARKED := ["scooter", "scooter", "bike", "bike", "car", "hatch", "auto"]

func _ready() -> void:
	rng.randomize()
	for v in Game.s.vehicles:
		var veh := Vehicle.create(v.type, int(v.col))
		veh.owned = true
		veh.uid = v.uid
		add_child(veh)
		veh.global_position = Vector3(v.pos[0], 0, v.pos[1])
		veh.rotation.y = float(v.rot)
		owned.append(veh)

func add_owned(type: String, col: int, pos: Vector3, rot: float) -> Vehicle:
	var veh := Vehicle.create(type, col)
	veh.owned = true
	veh.uid = "v%d" % (Time.get_ticks_usec() % 1000000)
	add_child(veh)
	veh.global_position = pos
	veh.rotation.y = rot
	owned.append(veh)
	Game.s.vehicles.append({"type": type, "col": col, "uid": veh.uid, "pos": [pos.x, pos.z], "rot": rot})
	return veh

func write_state() -> void:
	for veh in owned:
		for v in Game.s.vehicles:
			if v.uid == veh.uid:
				v.pos = [veh.global_position.x, veh.global_position.z]
				v.rot = veh.rotation.y

func populate_chunk(ch: Chunk) -> void:
	for sp in ch.parking:
		if City.in_zone(Vector2(sp.pos.x, sp.pos.z), 2.0) != null:
			continue
		var veh := Vehicle.create(PARKED[ch.rng.randi() % PARKED.size()], ch.rng.randi() % Vehicle.PAINT.size())
		ch.add_child(veh)
		veh.position = sp.pos
		veh.rotation.y = sp.rot
		veh.ai = {"parked": true}

func keep(veh: Vehicle) -> void:
	# a parked vehicle the player has taken must outlive its chunk
	if veh.get_parent() is Chunk:
		var xf := veh.global_transform
		veh.get_parent().remove_child(veh)
		add_child(veh)
		veh.global_transform = xf
		veh.ai = {}
		taken.append(veh)

func all_enterable() -> Array:
	var out: Array = []
	out.append_array(owned)
	out.append_array(taken)
	for ch in world.chunks.values():
		for c in ch.get_children():
			if c is Vehicle:
				out.append(c)
	return out

func time_factor() -> float:
	var t := float(Game.s.time)
	if t < 5.0 or t >= 23.0: return 0.2
	if t < 7.5: return 0.6
	if t < 10.5: return 1.0
	if t < 16.5: return 0.75
	if t < 20.5: return 1.0
	return 0.5

# ------------------------------------------------------------------ rails
func rail_point(ai: Dictionary) -> Vector2:
	var e = City.edges[ai.edge]
	var start: Vector2 = e.pa if ai.dir > 0 else e.pb
	var d: Vector2 = e.dir * float(ai.dir)
	var left := Vector2(d.y, -d.x)
	return start + d * float(ai.s) + left * (float(e.w) * 0.25)

func end_node(ai: Dictionary) -> String:
	var e = City.edges[ai.edge]
	return e.b if ai.dir > 0 else e.a

func spawn_on(type: String, edge: int, dir: int, s: float, col := -1) -> Vehicle:
	var veh := Vehicle.create(type, col, true)
	veh.ai = {"edge": edge, "dir": dir, "s": s, "speed": 0.0, "cruise": minf(float(veh.spec.max) * rng.randf_range(0.5, 0.68), 11.5), "stop_t": 0.0, "hold": false, "honk": 0.0, "route": [], "ri": 0}
	add_child(veh)
	var p := rail_point(veh.ai)
	veh.global_position = Vector3(p.x, 0, p.y)
	var e = City.edges[edge]
	var d: Vector2 = e.dir * float(dir)
	veh.rotation.y = atan2(-d.x, -d.y)
	moving.append(veh)
	return veh

## A vehicle that follows a fixed list of junctions (the story bus).
func spawn_route(type: String, nodes: Array, col := -1) -> Vehicle:
	var idx := City.edge_between(nodes[0], nodes[1])
	var e = City.edges[idx]
	var veh := spawn_on(type, idx, 1 if e.a == nodes[0] else -1, 30.0, col)
	veh.ai.route = nodes
	veh.ai.ri = 1
	veh.ai.cruise = 9.0
	return veh

func despawn(veh: Vehicle) -> void:
	moving.erase(veh)
	veh.queue_free()

func busy_near(pos: Vector3, r: float) -> bool:
	for veh in moving:
		if is_instance_valid(veh) and float(veh.ai.speed) > 1.0 and veh.global_position.distance_to(pos) < r:
			return true
	return false

func _process(delta: float) -> void:
	if world == null or world.player == null or get_tree().paused:
		return
	var pl: Player = world.player
	var ppos := pl.global_position
	for veh in moving.duplicate():
		if is_instance_valid(veh):
			_drive_ai(veh, delta, pl, ppos)
	_acc += delta
	if _acc > 0.5:
		_acc = 0.0
		_manage(ppos)

func _drive_ai(veh: Vehicle, delta: float, pl: Player, ppos: Vector3) -> void:
	var ai: Dictionary = veh.ai
	var e = City.edges[ai.edge]
	var target: float = ai.cruise
	var is_bus := veh.type in ["bus", "pbus"]
	var remaining: float = e.len - float(ai.s)
	if remaining < 26.0:
		target = minf(target, 5.5)
	# car following on the same edge
	for o in moving:
		if o == veh or not is_instance_valid(o) or o.ai.edge != ai.edge or o.ai.dir != ai.dir:
			continue
		var gap: float = float(o.ai.s) - float(ai.s)
		if gap > 0.0:
			gap -= (float(o.spec.l) + float(veh.spec.l)) * 0.5
			if gap < 4.0:
				target = 0.0
			elif gap < 13.0:
				target = minf(target, float(o.ai.speed) * 0.9)
	# brake for the player and for people on the road
	var fwd := -veh.global_transform.basis.z
	var to_p := ppos - veh.global_position
	var ahead := to_p.dot(fwd)
	var look := 6.0 + float(ai.speed) * 1.3 + float(veh.spec.l) * 0.5
	var lat := absf(to_p.dot(veh.global_transform.basis.x))
	var blocked := ahead > 0.0 and ahead < look and lat < float(veh.spec.w) * 0.5 + (1.4 if pl.vehicle != null else 0.7) and pl.bus == null and pl.vehicle != veh
	if not blocked and float(ai.speed) > 0.5 and world.crowd.ped_ahead(veh.global_position + fwd * float(veh.spec.l) * 0.5, fwd, 5.0 + float(ai.speed)):
		blocked = true
	if blocked:
		target = 0.0
		ai.honk = float(ai.honk) - delta
		if ai.honk <= 0.0:
			ai.honk = rng.randf_range(1.5, 4.0)
			veh.honk()
	# scheduled halts
	if ai.hold:
		target = 0.0
	if float(ai.stop_t) > 0.0:
		ai.stop_t = float(ai.stop_t) - delta
		target = 0.0
	var sp: float = ai.speed
	sp = move_toward(sp, target, (float(veh.spec.acc) if target > sp else 9.0) * delta)
	ai.speed = sp
	var prev_s: float = ai.s
	ai.s = prev_s + sp * delta
	if is_bus and ai.route.is_empty():
		var start_node: String = e.a if ai.dir > 0 else e.b
		if City.adj[start_node][0] == ai.edge and prev_s < 34.0 and float(ai.s) >= 34.0:
			ai.stop_t = rng.randf_range(4.0, 8.0)
	if float(ai.s) >= e.len - 9.0:
		_next_edge(veh)
	var rp := rail_point(ai)
	var cur := Vector2(veh.global_position.x, veh.global_position.z)
	var np := cur.move_toward(rp, maxf(sp, 2.0) * delta * 1.25)
	var mv := np - cur
	veh.global_position = Vector3(np.x, 0, np.y)
	if mv.length() > 0.003:
		veh.rotation.y = lerp_angle(veh.rotation.y, atan2(-mv.x, -mv.y), 1.0 - exp(-5.0 * delta))
	veh.v = sp

func _next_edge(veh: Vehicle) -> void:
	var ai: Dictionary = veh.ai
	var node := end_node(ai)
	var nxt := -1
	if not ai.route.is_empty():
		var ri: int = ai.ri
		if ai.route[ri] == node:
			bus_arrived.emit(veh, node)
			ri += 1
			ai.ri = ri
		if ri >= ai.route.size():
			ai.hold = true
			ai.s = City.edges[ai.edge].len - 9.0
			return
		nxt = City.edge_between(node, ai.route[ri])
	else:
		var opts: Array = []
		for idx in City.adj[node]:
			if idx != ai.edge:
				opts.append(idx)
		nxt = opts[rng.randi() % opts.size()] if not opts.is_empty() else ai.edge
	var e = City.edges[nxt]
	ai.edge = nxt
	ai.dir = 1 if e.a == node else -1
	ai.s = 9.0

func _manage(ppos: Vector3) -> void:
	var pp: Vector2 = Vector2(ppos.x, ppos.z) if world.interior == "" else world.exterior_pos
	var count := 0
	for veh in moving.duplicate():
		if not is_instance_valid(veh):
			moving.erase(veh)
			continue
		if veh.ai.route.is_empty():
			if Vector2(veh.global_position.x, veh.global_position.z).distance_to(pp) > 270.0:
				despawn(veh)
			else:
				count += 1
	for veh in taken.duplicate():
		if not is_instance_valid(veh):
			taken.erase(veh)
		elif veh != world.player.vehicle and veh.global_position.distance_to(ppos) > 300.0:
			taken.erase(veh)
			veh.queue_free()
	var want := int(float(Game.gfx("traffic")) * time_factor())
	var near: Array = City.edges_near(City.chunk_of(pp)).duplicate()
	for off in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		for idx in City.edges_near(City.chunk_of(pp) + off):
			if not near.has(idx):
				near.append(idx)
	if near.is_empty():
		return
	var tries := 0
	while count < want and tries < 4:
		tries += 1
		var idx: int = near[rng.randi() % near.size()]
		var e = City.edges[idx]
		var dir := 1 if rng.randf() < 0.5 else -1
		var s := rng.randf_range(12.0, maxf(13.0, e.len - 12.0))
		var probe := {"edge": idx, "dir": dir, "s": s}
		var p := rail_point(probe)
		var d := p.distance_to(pp)
		if d < 75.0 or d > 230.0:
			continue
		var clear := true
		for o in moving:
			if is_instance_valid(o) and Vector2(o.global_position.x, o.global_position.z).distance_to(p) < 16.0:
				clear = false
				break
		if not clear:
			continue
		spawn_on(_pick_type(), idx, dir, s)
		count += 1

func _pick_type() -> String:
	var total := 0
	for m in MIX:
		total += int(m[1])
	var r := rng.randi() % total
	for m in MIX:
		r -= int(m[1])
		if r < 0:
			return m[0]
	return "car"
