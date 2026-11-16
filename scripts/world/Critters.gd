class_name Critters
extends Node3D
## Street animals: stray dogs that trot about, sniff and sleep; flocks of pigeons
## and crows that lift off when somebody walks into them.

var world
var dogs: Array = []       # {n: Node3D, legs: Array, tail, target: Vector3, t, mode}
var flocks: Array = []     # {n: Node3D, birds: Array, up: float}
var _acc := 0.0

func _process(delta: float) -> void:
	if world == null or world.player == null or world.interior != "" or get_tree().paused:
		return
	var pp: Vector3 = world.player.global_position
	_acc += delta
	if _acc > 1.5:
		_acc = 0.0
		_manage(pp)
	for d in dogs:
		_dog(d, delta, pp)
	for f in flocks:
		_flock(f, delta, pp)

func _manage(pp: Vector3) -> void:
	for d in dogs.duplicate():
		if d.n.global_position.distance_to(pp) > 90.0:
			d.n.queue_free()
			dogs.erase(d)
	for f in flocks.duplicate():
		if f.n.global_position.distance_to(pp) > 90.0:
			f.n.queue_free()
			flocks.erase(f)
	var dist := City.district(Vector2(pp.x, pp.z))
	if dist.kind == "rural":
		return
	if dogs.size() < 3:
		var p := _street_point(pp)
		if p != Vector3.INF:
			dogs.append(_make_dog(p))
	if flocks.size() < 2:
		var p2 := _street_point(pp)
		if p2 != Vector3.INF:
			flocks.append(_make_flock(p2, randf() < 0.5))

func _street_point(pp: Vector3) -> Vector3:
	var ang := randf() * TAU
	var p := pp + Vector3(cos(ang), 0, sin(ang)) * randf_range(28.0, 60.0)
	var g := roundf(p.z / City.GRID) * City.GRID
	p.z = g + randf_range(-2.5, 2.5)
	var p2 := Vector2(p.x, p.z)
	if City.district(p2).kind == "rural" or City.on_arterial(p2, 2.0) or City.in_zone(p2, 2.0) != null:
		return Vector3.INF
	return p

func _make_dog(p: Vector3) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	var c: Color = [Color(0.72, 0.6, 0.42), Color(0.3, 0.24, 0.2), Color(0.85, 0.82, 0.76), Color(0.5, 0.38, 0.26)][randi() % 4]
	var m := Mats.col(c, 0.9)
	_bx(n, Vector3(0, 0.42, 0), Vector3(0.22, 0.22, 0.6), m)
	_bx(n, Vector3(0, 0.56, -0.38), Vector3(0.17, 0.18, 0.24), m)
	_bx(n, Vector3(0, 0.52, -0.52), Vector3(0.09, 0.08, 0.12), Mats.col(c.darkened(0.3)))
	for sd: float in [-1.0, 1.0]:
		_bx(n, Vector3(sd * 0.07, 0.68, -0.32), Vector3(0.05, 0.09, 0.04), m)
	var legs: Array = []
	for lp in [Vector3(-0.08, 0.3, -0.22), Vector3(0.08, 0.3, -0.22), Vector3(-0.08, 0.3, 0.22), Vector3(0.08, 0.3, 0.22)]:
		var j := Node3D.new()
		j.position = lp
		n.add_child(j)
		_bx(j, Vector3(0, -0.15, 0), Vector3(0.06, 0.3, 0.06), m)
		legs.append(j)
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.5, 0.3)
	n.add_child(tail)
	_bx(tail, Vector3(0, 0.08, 0.08), Vector3(0.04, 0.2, 0.04), m).rotation.x = 0.7
	return {"n": n, "legs": legs, "tail": tail, "target": p, "t": randf_range(1.0, 5.0), "mode": "idle", "ph": 0.0}

func _bx(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.visibility_range_end = 70.0
	parent.add_child(mi)
	return mi

func _dog(d: Dictionary, delta: float, pp: Vector3) -> void:
	var n: Node3D = d.n
	d.t = float(d.t) - delta
	var sp := 0.0
	if d.mode == "trot":
		var to: Vector3 = d.target - n.global_position
		if to.length() < 0.5 or float(d.t) <= 0.0:
			d.mode = "idle" if randf() < 0.7 else "sleep"
			d.t = randf_range(3.0, 10.0)
		else:
			sp = 1.8
			var dir := to.normalized()
			n.global_position += dir * sp * delta
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-dir.x, -dir.z), delta * 5.0)
	elif float(d.t) <= 0.0:
		d.mode = "trot"
		d.t = 8.0
		var g := roundf(n.global_position.z / City.GRID) * City.GRID
		d.target = Vector3(n.global_position.x + randf_range(-18, 18), 0, g + randf_range(-3, 3))
		if randf() < 0.25 and n.global_position.distance_to(pp) < 25.0:
			Sfx.play("bark", clampf(1.0 - n.global_position.distance_to(pp) / 25.0, 0.1, 0.6), randf_range(0.9, 1.15))
	# a car coming: get out of the road
	if world.traffic.busy_near(n.global_position, 7.0) and d.mode != "trot":
		d.mode = "trot"
		d.t = 3.0
		d.target = n.global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
	d.ph = float(d.ph) + delta * sp * 6.0
	var lie: bool = d.mode == "sleep"
	n.position.y = lerpf(n.position.y, -0.24 if lie else 0.0, delta * 4.0)
	for i in 4:
		var j: Node3D = d.legs[i]
		j.rotation.x = (sin(float(d.ph) + (PI if i in [1, 2] else 0.0)) * 0.6 if sp > 0.0 else (1.4 if lie else 0.0))
	d.tail.rotation.z = sin(Time.get_ticks_msec() * 0.012) * (0.5 if d.mode == "idle" else 0.15)

func _make_flock(p: Vector3, crows: bool) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	var m := Mats.col(Color(0.06, 0.06, 0.07) if crows else Color(0.5, 0.52, 0.58), 0.8)
	var birds: Array = []
	for i in randi_range(4, 9):
		var b := Node3D.new()
		b.position = Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		b.rotation.y = randf() * TAU
		n.add_child(b)
		_bx(b, Vector3(0, 0.09, 0), Vector3(0.09, 0.09, 0.2), m)
		_bx(b, Vector3(0, 0.16, -0.1), Vector3(0.06, 0.07, 0.07), m)
		var wl := _bx(b, Vector3(-0.1, 0.12, 0), Vector3(0.18, 0.015, 0.12), m)
		var wr := _bx(b, Vector3(0.1, 0.12, 0), Vector3(0.18, 0.015, 0.12), m)
		birds.append({"b": b, "wl": wl, "wr": wr, "home": b.position, "ph": randf() * 6.0})
	return {"n": n, "birds": birds, "up": 0.0, "crows": crows, "peck": 0.0}

func _flock(f: Dictionary, delta: float, pp: Vector3) -> void:
	var n: Node3D = f.n
	var near: bool = n.global_position.distance_to(pp) < 4.5 or world.traffic.busy_near(n.global_position, 6.0)
	if near and float(f.up) <= 0.0:
		f.up = 7.0
		Sfx.play("caw" if f.crows else "whoosh", 0.35, 1.3)
	f.up = maxf(0.0, float(f.up) - delta)
	var t := Time.get_ticks_msec() * 0.001
	for bd in f.birds:
		var b: Node3D = bd.b
		var flying: bool = float(f.up) > 0.0
		var k := sin(clampf(float(f.up) / 7.0, 0.0, 1.0) * PI)
		var home: Vector3 = bd.home
		var orbit := Vector3(cos(t * 1.3 + float(bd.ph)) * 4.0, 5.0 + sin(t + float(bd.ph)), sin(t * 1.3 + float(bd.ph)) * 4.0)
		b.position = b.position.lerp(home + orbit * k, delta * 3.0) if flying else b.position.lerp(home, delta * 2.0)
		var flap := sin(t * 22.0 + float(bd.ph)) * 0.9 if flying else 0.0
		bd.wl.rotation.z = flap
		bd.wr.rotation.z = -flap
		if not flying:
			b.rotation.x = maxf(0.0, sin(t * 3.0 + float(bd.ph) * 2.0)) * 0.5      # pecking
