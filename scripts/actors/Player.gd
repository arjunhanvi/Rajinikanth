class_name Player
extends CharacterBody3D
## The player: third-person on foot, driving, or working the aisle of a bus.

const WALK := 1.4         # a natural, unhurried walking pace (m/s)
const RUN := 4.2        # a run, not a sprint (4.8 forced the legs into a crouch)
const CROUCH := 1.3

var human: Human
var cam: Camera3D
var yaw := 0.0
var pitch := -0.25
var cam_dist := 4.2
var first_person := false
var vehicle: Vehicle = null
var locked := false            # dialogue / cutscene
var crouching := false
var bus: Node3D = null         # conductor mode: we ride inside this bus
var bus_local := Vector3.ZERO
var talk_focus: Node3D = null   # whoever we are speaking with: the camera frames both
var cam_zoom := 1.0             # 0.6 close .. 1.6 wide
var pose := ""                  # cinematics can hold the body in a pose ("sit")
var ride: Vehicle = null        # riding pillion: somebody else is driving
var cam_override := false      # cinematics drive the camera
var puppet := false            # a cinematic moves the body itself (position, state, activity)
var _vy := 0.0
var _cam_ahead := Vector3.ZERO
var _hv := Vector3.ZERO        # horizontal velocity: it builds up and falls off, never jumps
var _step := 0.0
var _look_idle := 0.0
var _punch_cd := 0.0
var input_move := Vector2.ZERO  # from HUD stick (x right, y forward)
var input_sprint := false
var input_throttle := 0.0         # 0..1 accelerator
var input_brake := 0.0            # 0..1 brake (held at a standstill: reverse)
var input_steer := 0.0
var input_handbrake := false
var run_blocked := false        # running into something solid (the HUD ends RUN LOCK on it)
var _block_t := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	human = Human.make(_hero_look(Game.s.look), 2)
	add_child(human)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.12
	cam.far = 900.0
	cam.top_level = true
	add_child(cam)
	cam.current = true

## In the story the player is Rajinikanth himself and wears his body; free play uses the created character.
func _hero_look(l: Dictionary) -> Dictionary:
	var d := l.duplicate()
	if Game.s.get("mode", "story") == "story":
		d["model"] = "raja"
		d["acc"] = 0
		d["top"] = 2
		d["pat"] = {"shirt_out": "check"}
	return d

func set_look(l: Dictionary) -> void:
	human.set_look(_hero_look(l))

func look_input(d: Vector2) -> void:
	var sens: float = float(Game.settings.sens) * 0.005
	yaw -= d.x * sens
	pitch = clampf(pitch - d.y * sens * (-1.0 if Game.settings.invert_y else 1.0), -1.25, 0.6)
	_look_idle = 0.0

func mount_pillion(veh: Vehicle) -> void:
	ride = veh
	crouching = false
	collision_layer = 0
	collision_mask = 0
	human.get_parent().remove_child(human)
	veh._lean.add_child(human)
	human.position = veh.seat_pos() + Vector3(0, 0.03, 0.5)
	human.rotation = Vector3.ZERO
	human.state = "pillion"
	human.speed = 0.0
	yaw = veh.rotation.y + 0.35

func dismount() -> void:
	if ride == null:
		return
	var out := ride.exit_point()
	human.get_parent().remove_child(human)
	add_child(human)
	human.position = Vector3.ZERO
	human.rotation = Vector3(0, ride.rotation.y, 0)
	human.state = "idle"
	ride = null
	global_position = Vector3(out.x, 0, out.z)
	collision_layer = 4
	collision_mask = 1 | 2

func in_vehicle() -> bool:
	return vehicle != null

func _physics_process(delta: float) -> void:
	_punch_cd -= delta
	_look_idle += delta
	if puppet:
		return
	var mv := input_move
	var kb := Input.get_vector("mv_l", "mv_r", "mv_d", "mv_u")
	if kb.length() > 0.1:
		mv = kb
	if ride != null:
		global_position = ride.global_position
		if _look_idle > 2.5:
			yaw = lerp_angle(yaw, ride.rotation.y + 0.35, 1.0 - exp(-1.5 * delta))
			pitch = lerpf(pitch, -0.16, 1.0 - exp(-1.5 * delta))
	elif bus != null:
		_bus_move(delta, mv)
	elif vehicle != null:
		_drive(delta, mv)
	else:
		_walk(delta, mv)
	_camera(delta)

func _walk(delta: float, mv: Vector2) -> void:
	if locked:
		mv = Vector2.ZERO
	var sprint := (input_sprint or Input.is_action_pressed("sprint")) and not crouching
	var spd := CROUCH if crouching else (RUN if sprint else WALK)
	var dir := Vector3.ZERO
	if mv.length() > 0.08:
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		dir = (fwd * mv.y + right * mv.x)
		var mag := minf(dir.length(), 1.0)
		dir = dir.normalized()
		spd *= mag if not sprint else 1.0
		# the body turns at a human rate (faster when slow, wider arcs when running)
		var turn_rate := lerpf(9.0, 4.5, clampf(_hv.length() / RUN, 0.0, 1.0))
		human.rotation.y = lerp_angle(human.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-turn_rate * delta))
	else:
		spd = 0.0
	var on_floor := global_position.y <= 0.001
	if on_floor:
		_vy = 0.0
		global_position.y = 0.0
	else:
		_vy -= 22.0 * delta
	# acceleration into a walk or run, quicker deceleration to a stop (momentum, not a switch)
	var want := dir * spd
	var rate := (3.2 if want.length() > _hv.length() else 5.5) * (1.6 if sprint else 1.0)
	_hv = _hv.move_toward(want, rate * delta)
	velocity = _hv + Vector3(0, _vy, 0)
	var before := global_position
	move_and_slide()
	if global_position.y < 0.0:
		global_position.y = 0.0
	var hs := Vector2(velocity.x, velocity.z).length()
	# blocked: we want to run but hardly move, for a moment
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, 0.0001)
	var trying := Vector2(_hv.x, _hv.z).length()      # the speed we are actually trying to move at (not the target)
	if trying > 2.0 and moved < trying * 0.3:
		_block_t += delta
	else:
		_block_t = 0.0
	run_blocked = _block_t > 0.3
	human.speed = hs
	human.state = "air" if not on_floor else ("crouch" if crouching else "idle")
	if pose != "":
		human.state = pose
		human.speed = 0.0
	if hs > 0.5 and on_floor:
		_step -= delta * hs
		if _step <= 0.0:
			_step = 1.9
			Sfx.play("step", 0.25, randf_range(0.85, 1.15))
		Game.s.stats.km = float(Game.s.stats.km) + hs * delta / 1000.0

func jump() -> void:
	if vehicle == null and bus == null and not locked and global_position.y <= 0.001:
		_vy = 6.4
		global_position.y = 0.01
		crouching = false

func toggle_crouch() -> void:
	if vehicle == null and bus == null:
		crouching = not crouching

func punch() -> void:
	if vehicle != null or bus != null or locked or _punch_cd > 0.0:
		return
	_punch_cd = 0.55
	human.play_once("punch", 0.3)
	Sfx.play("whoosh", 0.3, 1.8)
	if Game.world != null:
		var fwd := -human.global_transform.basis.z
		Game.world.crowd.player_punch(global_position + fwd * 0.9, fwd)

# ------------------------------------------------------------------ vehicles
func enter_vehicle(veh: Vehicle) -> void:
	vehicle = veh
	veh.player_driven = true
	crouching = false
	collision_layer = 0
	collision_mask = 0
	veh.set_rider(human)
	human.visible = veh.spec.open
	Sfx.play("door")
	yaw = veh.rotation.y
	if Game.world != null:
		Game.world.hud.set_mode("drive")

func exit_vehicle() -> void:
	if vehicle == null:
		return
	var veh := vehicle
	var out := veh.exit_point()
	veh.clear_rider()
	human.get_parent().remove_child(human)
	add_child(human)
	human.position = Vector3.ZERO
	human.rotation = Vector3(0, veh.rotation.y, 0)
	human.state = "idle"
	human.visible = true
	veh.player_driven = false
	veh.hvel = Vector3.ZERO
	veh.reverse = false
	veh.stop_engine()
	vehicle = null
	global_position = Vector3(out.x, 0, out.z)
	collision_layer = 4
	collision_mask = 1 | 2
	Sfx.play("door")
	if Game.world != null:
		Game.world.hud.set_mode("foot")

func _drive(delta: float, mv: Vector2) -> void:
	var th := input_throttle
	var br := input_brake
	var st := input_steer
	# keyboard / joystick fallback: forward is the accelerator, back is the brake
	if absf(mv.y) > 0.1 and th < 0.05 and br < 0.05:
		th = maxf(mv.y, 0.0)
		br = maxf(-mv.y, 0.0)
	if absf(mv.x) > 0.1 and absf(st) < 0.05:
		st = mv.x
	if locked:
		th = 0.0
		br = 0.0
		st = 0.0
	vehicle.drive2(delta, th, br, st, input_handbrake or Input.is_action_pressed("handbrake") or locked)
	global_position = vehicle.global_position
	Game.s.stats.km = float(Game.s.stats.km) + absf(vehicle.v) * delta / 1000.0
	if _look_idle > 1.2 and absf(vehicle.v) > 1.0:
		yaw = lerp_angle(yaw, vehicle.rotation.y, 1.0 - exp(-2.5 * delta))
		pitch = lerpf(pitch, -0.22, 1.0 - exp(-2.0 * delta))

# ------------------------------------------------------------------ conductor mode
func board_bus(b: Node3D, local: Vector3) -> void:
	bus = b
	bus_local = local
	collision_layer = 0
	collision_mask = 0
	human.state = "idle"

func leave_bus(to: Vector3) -> void:
	bus = null
	collision_layer = 4
	collision_mask = 1 | 2
	global_position = to

func _bus_move(delta: float, mv: Vector2) -> void:
	# walk the aisle: local z in [-4.2, 4.2] (front is -z), tiny sideways freedom
	if locked:
		mv = Vector2.ZERO
	var rel := yaw - bus.rotation.y
	var f := mv.y * cos(rel) - mv.x * sin(rel)    # forward along the bus
	var sdw := mv.x * cos(rel) + mv.y * sin(rel)
	bus_local.z = clampf(bus_local.z - f * 2.0 * delta, -4.2, 4.2)
	bus_local.x = clampf(bus_local.x + sdw * 1.2 * delta, -0.28, 0.28)
	global_position = bus.global_transform * bus_local
	human.speed = Vector2(f, sdw).length() * 2.0
	if mv.length() > 0.1:
		human.rotation.y = lerp_angle(human.rotation.y, bus.rotation.y + (0.0 if f >= 0.0 else PI), 1.0 - exp(-10.0 * delta))

# ------------------------------------------------------------------ camera
func _camera(delta: float) -> void:
	if cam_override:
		return
	var target := global_position + Vector3(0, 1.55 if not crouching else 1.1, 0)
	var dist := cam_dist * cam_zoom
	if talk_focus != null and is_instance_valid(talk_focus) and vehicle == null and bus == null:
		# conversation framing: over the shoulder, both faces in shot
		var mid := (global_position + talk_focus.global_position) * 0.5 + Vector3(0, 1.5, 0)
		var to := talk_focus.global_position - global_position
		var want_yaw := atan2(-to.x, -to.z) + 0.6
		yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-3.0 * delta))
		pitch = lerpf(pitch, -0.12, 1.0 - exp(-3.0 * delta))
		target = target.lerp(mid, 0.6)
		dist = 2.6
	if ride != null:
		dist = 4.4 * cam_zoom
		target = ride.global_position + Vector3(0, 1.45, 0)
	if vehicle != null:
		# chase camera per vehicle class: further back and wider as speed builds, looking ahead into the turn
		var two := vehicle.type in ["bike", "scooter"]
		var vmax: float = float(vehicle.spec.max)
		var sp := clampf(absf(vehicle.v) / vmax, 0.0, 1.0)
		dist = ((3.2 if two else 5.5 + float(vehicle.spec.l) * 0.75) * (1.0 + 0.22 * sp)) * cam_zoom
		var fwdv := -vehicle.global_transform.basis.z
		var rgt := vehicle.global_transform.basis.x
		var ahead := fwdv * clampf(absf(vehicle.v) * 0.18, 0.0, 3.5) * signf(vehicle.v) + rgt * vehicle.steer * clampf(absf(vehicle.v) * 0.12, 0.0, 1.6)
		_cam_ahead = _cam_ahead.lerp(ahead, 1.0 - exp(-3.0 * delta))
		target = vehicle.global_position + Vector3(0, (float(vehicle.spec.h) * 0.75 + 0.5) if not two else 1.25, 0) + _cam_ahead + Vector3(0, vehicle.susp.x, 0)
		cam.fov = lerpf(cam.fov, 62.0 + 9.0 * sp, 1.0 - exp(-2.0 * delta))
	else:
		_cam_ahead = Vector3.ZERO
		cam.fov = lerpf(cam.fov, 62.0, 1.0 - exp(-3.0 * delta))
	if bus != null:
		dist = 1.7
		target = global_position + Vector3(0, 1.6, 0)
	var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var back := rot * Vector3(0, 0, 1)
	if first_person and bus == null:
		human.visible = false if vehicle == null else human.visible
		var eye := global_position + Vector3(0, 1.62, 0) if vehicle == null else vehicle.global_position + vehicle.global_transform.basis * (vehicle.seat_pos() + Vector3(0, 1.15, -0.25))
		cam.global_position = eye
		cam.global_transform.basis = rot
		return
	if vehicle == null and not cam_override:
		human.visible = true
	var want := target + back * dist
	if bus == null:
		# a sphere, not a ray, so the camera does not clip walls at the edge of the view
		var space := get_world_3d().direct_space_state
		var sq := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.22
		sq.shape = sph
		sq.transform = Transform3D(Basis(), target)
		sq.motion = want - target
		sq.collision_mask = 1
		var frac := space.cast_motion(sq)
		if frac.size() > 0 and frac[0] < 1.0:
			want = target + (want - target) * frac[0]
	if bus != null:
		# keep the camera inside the bus shell
		var inv := bus.global_transform.affine_inverse()
		var lp := inv * want
		lp = Vector3(clampf(lp.x, -0.95, 0.95), clampf(lp.y, 1.6, 2.75), clampf(lp.z, -4.6, 4.8))
		want = bus.global_transform * lp
		cam.global_position = want
		cam.look_at(target, Vector3.UP)
		return
	if want.y < 0.25:
		want.y = 0.25
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-18.0 * delta)) if cam.global_position.distance_to(want) < 12.0 else want
	cam.look_at(target, Vector3.UP)
