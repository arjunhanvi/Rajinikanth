class_name NPC
extends Node3D
## One simulated person in the streamed area: a named character following a
## schedule, an ambient pedestrian walking the street grid, a loiterer, a
## hostile thug or a constable. Behaviour is a small state machine.

var id := ""                 # named character id, "" for ambient
var ident := {}              # {name, job, sex, mood}
var human: Human
var mode := "idle"           # idle, walk, grid, flee, ko, hostile, cop, follow
var after := "idle"          # mode on arrival
var sit := false
var path := PackedVector2Array()
var pidx := 0
var speed := 1.35
var face_yaw := 0.0
var hp := 30.0
var timer := 0.0
var attack_cd := 0.0
var story_tag := ""          # story actors carry a tag so missions can find them
var no_despawn := false
var partner: NPC = null
var _bubble: Label3D = null
var _bubble_t := 0.0
# grid walker state
var axis := 0
var line := 0.0
var side := 1.0
var dirn := 1.0
var _wait := 0.0

func setup(look: Dictionary, identity: Dictionary, named_id := "") -> void:
	id = named_id
	ident = identity
	human = Human.make(look)
	add_child(human)
	speed = randf_range(1.15, 1.6)

func p2() -> Vector2:
	return Vector2(global_position.x, global_position.z)

func display_name() -> String:
	if id != "":
		return People.NAMES.get(id, id)
	return str(ident.get("name", "Stranger"))

func go(points: PackedVector2Array, then := "idle", run := false) -> void:
	path = points
	pidx = 0
	after = then
	mode = "walk"
	sit = false
	if run:
		speed = 4.4

func face(target: Vector3) -> void:
	var d := target - global_position
	if d.length() > 0.05:
		face_yaw = atan2(-d.x, -d.z)

func say_bubble(text: String, dur := 2.6) -> void:
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.font_size = 30
		_bubble.pixel_size = 0.0045
		_bubble.outline_size = 8
		_bubble.modulate = Color(1, 1, 0.85)
		_bubble.position.y = 2.05
		_bubble.no_depth_test = true
		_bubble.visibility_range_end = 14.0
		_bubble.width = 320
		_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_bubble)
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = dur
	human.talk_t = dur

func knock_out(dur := 14.0) -> void:
	mode = "ko"
	timer = dur
	human.state = "ko"
	human.speed = 0.0

func tick(delta: float, crowd) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0 and _bubble != null:
			_bubble.visible = false
	var pl: Player = crowd.world.player
	var ppos := pl.global_position
	var moving := 0.0
	match mode:
		"ko":
			timer -= delta
			if timer <= 0.0:
				human.state = "idle"
				if hp <= 0.0:
					hp = 12.0
				_flee_from(ppos)
		"walk":
			if pidx >= path.size():
				mode = after
				human.state = "sit" if sit else "idle"
				if after == "gone":
					crowd.remove(self)
					return
			else:
				moving = _step_to(path[pidx], delta, 0.35)
				if moving < 0.0:
					pidx += 1
					moving = speed
		"grid":
			moving = _grid(delta, crowd)
		"flee":
			timer -= delta
			moving = _step_dir(delta, 4.2)
			if timer <= 0.0:
				speed = randf_range(1.15, 1.6)
				_regrid()
		"follow":
			var d := global_position.distance_to(ppos)
			if d > 2.2:
				speed = 4.6 if d > 7.0 else 2.4
				moving = _step_to(Vector2(ppos.x, ppos.z), delta, 1.6)
			else:
				face(ppos)
		"hostile", "cop":
			var d2 := global_position.distance_to(ppos)
			attack_cd -= delta
			if pl.bus != null or crowd.world.interior != "":
				pass
			elif d2 > 1.15:
				speed = 4.7 if mode == "cop" else 4.3
				moving = _step_to(Vector2(ppos.x, ppos.z), delta, 1.0)
				moving = speed
			else:
				face(ppos)
				if mode == "cop":
					crowd.arrest(self)
				elif attack_cd <= 0.0:
					attack_cd = randf_range(0.9, 1.4)
					human.play_once("punch", 0.3)
					crowd.hit_player(7.0)
		_:
			if partner != null and is_instance_valid(partner):
				face(partner.global_position)
	human.speed = maxf(moving, 0.0)
	if mode != "ko":
		human.rotation.y = lerp_angle(human.rotation.y, face_yaw, 1.0 - exp(-9.0 * delta))

func _step_to(t: Vector2, delta: float, arrive: float) -> float:
	var d := t - p2()
	var dist := d.length()
	if dist < arrive:
		return -1.0
	d /= dist
	global_position += Vector3(d.x, 0, d.y) * speed * delta
	face_yaw = atan2(-d.x, -d.y)
	return speed

func _step_dir(delta: float, spd: float) -> float:
	var f := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	global_position += f * spd * delta
	return spd

func _flee_from(p: Vector3) -> void:
	mode = "flee"
	timer = randf_range(5.0, 8.0)
	var d := global_position - p
	face_yaw = atan2(-d.x, -d.z) + randf_range(-0.5, 0.5)

func alarm(p: Vector3) -> void:
	if mode in ["grid", "idle", "walk"] and id == "" and story_tag == "":
		_flee_from(p)
		partner = null
		human.state = "idle"

# ------------------------------------------------------------------ street-grid walking
func start_grid(ax: int, ln: float, sd: float, dr: float) -> void:
	mode = "grid"
	axis = ax
	line = ln
	side = sd
	dirn = dr

func _regrid() -> void:
	# rejoin the nearest street after fleeing
	var p := p2()
	var gx := roundf(p.x / City.GRID) * City.GRID
	var gz := roundf(p.y / City.GRID) * City.GRID
	if absf(p.x - gx) < absf(p.y - gz):
		start_grid(1, gx, 1.0 if p.x > gx else -1.0, 1.0 if randf() < 0.5 else -1.0)
	else:
		start_grid(0, gz, 1.0 if p.y > gz else -1.0, 1.0 if randf() < 0.5 else -1.0)

func _grid(delta: float, crowd) -> float:
	if _wait > 0.0:
		_wait -= delta
		return 0.0
	var p := p2()
	var along := p.x if axis == 0 else p.y
	var nxt := along + dirn * speed * delta
	var off := line + side * 3.0
	var fwd2 := Vector2(dirn, 0) if axis == 0 else Vector2(0, dirn)
	# wait for a gap before stepping onto an arterial road
	var ahead := p + fwd2 * 2.5
	if City.on_arterial(ahead, 0.5) and not City.on_arterial(p, 0.5):
		if crowd.world.traffic.busy_near(Vector3(ahead.x, 0, ahead.y) + Vector3(fwd2.x, 0, fwd2.y) * 5.0, 14.0):
			_wait = 0.6
			face_yaw = atan2(-fwd2.x, -fwd2.y)
			return 0.0
	if floorf(along / City.GRID) != floorf(nxt / City.GRID):
		# reached a crossing: carry on, turn, or turn back at the edge of town
		var cross := roundf(nxt / City.GRID) * City.GRID
		var here := Vector2(cross, line) if axis == 0 else Vector2(line, cross)
		var beyond := here + fwd2 * City.GRID
		var z = City.in_zone(beyond)
		var blocked: bool = City.district(beyond).kind == "rural" or (z != null and z.kind in ["lake", "airport", "railstation", "vidhana", "temple"])
		var r := randf()
		if blocked or r < 0.34:
			var new_axis := 1 - axis
			var nd := 1.0 if randf() < 0.5 else -1.0
			var probe := here + (Vector2(nd, 0) if new_axis == 0 else Vector2(0, nd)) * City.GRID
			if City.district(probe).kind == "rural":
				nd = -nd
			var old_off := off
			axis = new_axis
			line = cross
			side = 1.0 if old_off > (here.y if new_axis == 0 else here.x) else -1.0
			dirn = nd
			# keep a consistent pavement side relative to the new street
			side = 1.0 if randf() < 0.5 else -1.0
			return speed
	var target := Vector2(nxt, off) if axis == 0 else Vector2(off, nxt)
	var np := p.lerp(target, 1.0) if absf((p.y if axis == 0 else p.x) - off) < 0.15 else Vector2(
		nxt if axis == 0 else move_toward(p.x, off, speed * delta),
		move_toward(p.y, off, speed * delta) if axis == 0 else nxt)
	global_position = Vector3(np.x, 0, np.y)
	var mv := np - p
	if mv.length() > 0.0005:
		face_yaw = atan2(-mv.x, -mv.y)
	return speed
