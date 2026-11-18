class_name Vehicle
extends CharacterBody3D
## A period vehicle: procedurally modelled, arcade-driven by the player or moved
## on rails by Traffic. Model forward is -Z; India drives on the left.

const SPECS := {
	"car":     {"name": "Ambassador-style saloon", "l": 4.3, "w": 1.7, "h": 1.55, "max": 22.0, "acc": 5.0, "turn": 1.5, "eng": "eng_car", "horn": "horn_car", "price": 85000, "open": false},
	"hatch":   {"name": "800cc hatchback", "l": 3.3, "w": 1.5, "h": 1.42, "max": 21.0, "acc": 5.5, "turn": 1.8, "eng": "eng_car", "horn": "horn_car", "price": 60000, "open": false},
	"taxi":    {"name": "Taxi", "l": 4.3, "w": 1.7, "h": 1.55, "max": 21.0, "acc": 4.8, "turn": 1.5, "eng": "eng_car", "horn": "horn_car", "price": 70000, "open": false},
	"jeep":    {"name": "Police jeep", "l": 3.8, "w": 1.7, "h": 1.85, "max": 22.0, "acc": 5.5, "turn": 1.6, "eng": "eng_car", "horn": "horn_car", "price": 0, "open": false},
	"auto":    {"name": "Auto-rickshaw", "l": 2.7, "w": 1.35, "h": 1.75, "max": 13.0, "acc": 4.0, "turn": 2.3, "eng": "eng_auto", "horn": "horn_auto", "price": 28000, "open": true},
	"bike":    {"name": "100cc motorcycle", "l": 2.0, "w": 0.75, "h": 1.1, "max": 25.0, "acc": 7.5, "turn": 2.2, "eng": "eng_bike", "horn": "horn_auto", "price": 22000, "open": true},
	"scooter": {"name": "Geared scooter", "l": 1.8, "w": 0.7, "h": 1.1, "max": 17.0, "acc": 5.0, "turn": 2.3, "eng": "eng_bike", "horn": "horn_auto", "price": 9000, "open": true},
	"bus":     {"name": "City bus", "l": 10.4, "w": 2.5, "h": 3.05, "max": 15.0, "acc": 2.6, "turn": 0.85, "eng": "eng_bus", "horn": "horn_bus", "price": 0, "open": false},
	"pbus":    {"name": "Private bus", "l": 10.4, "w": 2.5, "h": 3.05, "max": 16.0, "acc": 2.8, "turn": 0.85, "eng": "eng_bus", "horn": "horn_bus", "price": 0, "open": false},
	"truck":   {"name": "Lorry", "l": 7.0, "w": 2.4, "h": 2.9, "max": 14.0, "acc": 2.4, "turn": 0.95, "eng": "eng_bus", "horn": "horn_bus", "price": 0, "open": false},
}
const PAINT := [Color(0.92, 0.92, 0.9), Color(0.85, 0.85, 0.8), Color(0.55, 0.1, 0.1), Color(0.1, 0.25, 0.45), Color(0.55, 0.58, 0.6), Color(0.2, 0.4, 0.3), Color(0.75, 0.7, 0.5), Color(0.1, 0.1, 0.12), Color(0.6, 0.35, 0.2)]

var type := "car"
var spec := {}
var paint := Color.WHITE
var v := 0.0               # signed forward speed, m/s
var steer := 0.0
var driver: Human = null   # visible rider (open vehicles)
var owned := false
var player_driven := false
var ai := {}               # Traffic's per-vehicle state
var uid := ""              # persistent id for owned vehicles
var _eng: AudioStreamPlayer = null
var _lean: Node3D
var _brake: MeshInstance3D
var _ind := {}              # -1 / 1 -> MeshInstance3D
var _ind_dir := 0
var _blink := 0.0
var _spot: SpotLight3D = null
var _prev_v := 0.0
# handling and suspension state (see Handling.gd)
var hvel := Vector3.ZERO      # horizontal velocity (the body can slide sideways)
var lat_acc := 0.0            # lateral acceleration, + when turning right
var reverse := false
var rev_hold := 0.0
var gear := 1
var shift_t := 0.0
var susp := Vector3.ZERO      # body height, pitch, roll
var susp_v := Vector3.ZERO
var _acc_f := 0.0
var wheel_pts: Array = []
var _prev_yaw := 0.0

static func create(t: String, colour_i := -1, with_rider := false) -> Vehicle:
	var veh := Vehicle.new()
	veh.type = t
	veh.spec = SPECS[t]
	var ci := colour_i if colour_i >= 0 else randi() % PAINT.size()
	veh.paint = PAINT[ci % PAINT.size()]
	veh._build(with_rider)
	return veh

func _build(with_rider: bool) -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	var L: float = spec.l
	var W: float = spec.w
	var H: float = spec.h
	wheel_pts = Handling.wheels(type, L, W)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(W, H, L)
	cs.shape = sh
	cs.position.y = H * 0.5 + 0.05
	add_child(cs)
	_lean = Node3D.new()
	add_child(_lean)
	var mb := MB.new()
	var gl := MB.new()     # glass
	var lt := MB.new()     # lights
	var tyre := Color(0.07, 0.07, 0.08)
	var glass := Color(0.1, 0.14, 0.17)
	var chrome := Color(0.7, 0.72, 0.75)
	var c := paint
	match type:
		"car", "taxi", "hatch", "jeep":
			var roof_c := c
			if type == "taxi":
				c = Color(0.1, 0.1, 0.11); roof_c = Color(0.95, 0.8, 0.1)
			if type == "jeep":
				c = Color(0.25, 0.3, 0.22); roof_c = Color(0.2, 0.22, 0.18)
			var wr := 0.3
			mb.box(Vector3(0, 0.62, 0), Vector3(W, 0.58, L), c)
			var cab_l := L * (0.5 if type != "hatch" else 0.62)
			var cab_z := L * (0.06 if type in ["car", "taxi"] else 0.16)
			if type == "jeep":
				cab_l = L * 0.62; cab_z = L * 0.17
			var ch := H - 0.93
			mb.box(Vector3(0, 0.91 + ch * 0.5, cab_z), Vector3(W * 0.9, ch, cab_l), roof_c)
			gl.box(Vector3(0, 0.93 + ch * 0.42, cab_z), Vector3(W * 0.92, ch * 0.62, cab_l * 0.86), glass, Rect2(0, 0, 1, 1), false)
			gl.box(Vector3(0, 0.93 + ch * 0.42, cab_z), Vector3(W * 0.8, ch * 0.62, cab_l * 1.01), glass, Rect2(0, 0, 1, 1), false)
			mb.box(Vector3(0, 0.38, -L * 0.5 - 0.04), Vector3(W * 1.02, 0.14, 0.12), chrome)
			mb.box(Vector3(0, 0.38, L * 0.5 + 0.04), Vector3(W * 1.02, 0.14, 0.12), chrome)
			mb.box(Vector3(0, 0.66, -L * 0.5 - 0.01), Vector3(W * 0.5, 0.22, 0.04), Color(0.15, 0.15, 0.16))   # grille
			mb.box(Vector3(0, 0.45, L * 0.5 + 0.11), Vector3(0.5, 0.13, 0.02), Color(0.95, 0.95, 0.9) if type != "taxi" else Color(0.95, 0.8, 0.1))   # number plate
			for sd: float in [-1.0, 1.0]:
				lt.box(Vector3(sd * W * 0.36, 0.7, -L * 0.5 - 0.02), Vector3(0.22, 0.2, 0.05), Color(1, 0.95, 0.75))
				mb.box(Vector3(sd * W * 0.38, 0.68, L * 0.5 + 0.02), Vector3(0.2, 0.16, 0.04), Color(0.8, 0.1, 0.08))
				for fz: float in [-1.0, 1.0]:
					mb.wheel(Vector3(sd * (W * 0.5 - 0.08), wr, fz * L * 0.31), wr, 0.2, tyre)
			if type == "jeep":
				lt.box(Vector3(0, H + 0.08, cab_z - 0.4), Vector3(0.2, 0.16, 0.2), Color(0.9, 0.1, 0.1))
		"auto":
			var yel := Color(0.95, 0.78, 0.1)
			var blk := Color(0.09, 0.09, 0.1)
			mb.box(Vector3(0, 0.55, 0.25), Vector3(W, 0.6, L * 0.72), blk)
			mb.box(Vector3(0, 0.5, -L * 0.36), Vector3(W * 0.55, 0.5, L * 0.3), blk)
			mb.box(Vector3(0, H - 0.06, 0.12), Vector3(W * 1.02, 0.1, L * 0.86), yel)
			mb.box(Vector3(0, 1.2, L * 0.48), Vector3(W, 1.0, 0.06), yel)
			gl.box(Vector3(0, 1.25, -L * 0.3), Vector3(W * 0.86, 0.75, 0.04), Color(0.3, 0.38, 0.42))
			for sd: float in [-1.0, 1.0]:
				mb.box(Vector3(sd * W * 0.46, 1.2, -L * 0.3), Vector3(0.05, 1.05, 0.05), blk)
				mb.box(Vector3(sd * W * 0.46, 1.2, 0.4), Vector3(0.05, 1.05, 0.05), blk)
				mb.wheel(Vector3(sd * (W * 0.5 - 0.02), 0.22, L * 0.3), 0.22, 0.14, tyre)
			mb.wheel(Vector3(0, 0.22, -L * 0.42), 0.22, 0.12, tyre)
			mb.box(Vector3(0, 0.75, 0.55), Vector3(W * 0.9, 0.12, 0.5), Color(0.5, 0.1, 0.1))   # passenger seat
			lt.box(Vector3(0, 0.85, -L * 0.5 - 0.02), Vector3(0.18, 0.18, 0.05), Color(1, 0.95, 0.75))
		"bike", "scooter":
			var wr2 := 0.3 if type == "bike" else 0.2
			mb.wheel(Vector3(0, wr2, -L * 0.36), wr2, 0.09, tyre)
			mb.wheel(Vector3(0, wr2, L * 0.36), wr2, 0.09, tyre)
			if type == "bike":
				mb.box(Vector3(0, 0.55, 0.0), Vector3(0.22, 0.3, 0.75), Color(0.2, 0.2, 0.22))     # engine
				mb.box(Vector3(0, 0.82, -0.18), Vector3(0.3, 0.2, 0.5), c)                          # tank
				mb.box(Vector3(0, 0.8, 0.38), Vector3(0.28, 0.1, 0.65), Color(0.1, 0.1, 0.1))       # seat
				mb.box(Vector3(0, 0.7, -0.62), Vector3(0.07, 0.75, 0.07), chrome, Rect2(0, 0, 1, 1), true, Basis(Vector3.RIGHT, 0.4))
			else:
				mb.box(Vector3(0, 0.45, 0.35), Vector3(0.42, 0.45, 0.85), c)                        # rear body
				mb.box(Vector3(0, 0.28, -0.1), Vector3(0.38, 0.06, 0.5), c)                         # floorboard
				mb.box(Vector3(0, 0.62, -0.5), Vector3(0.44, 0.75, 0.08), c)                        # front apron
				mb.box(Vector3(0, 0.73, 0.3), Vector3(0.34, 0.1, 0.7), Color(0.12, 0.1, 0.1))       # seat
				mb.wheel(Vector3(0, 0.62, L * 0.5 + 0.02), 0.2, 0.1, tyre, Basis(Vector3.UP, PI * 0.5))   # stepney
			mb.box(Vector3(0, 1.02, -0.52), Vector3(0.62, 0.05, 0.05), chrome)                    # handlebar
			lt.box(Vector3(0, 0.92, -0.62), Vector3(0.16, 0.16, 0.06), Color(1, 0.95, 0.75))
			mb.box(Vector3(0, 0.6, L * 0.5 - 0.04), Vector3(0.12, 0.08, 0.04), Color(0.8, 0.1, 0.08))
		"bus", "pbus":
			var lower := Color(0.72, 0.16, 0.13) if type == "bus" else c
			var upper := Color(0.93, 0.9, 0.8) if type == "bus" else c.lightened(0.5)
			mb.box(Vector3(0, 0.95, 0), Vector3(W, 1.1, L), lower)
			mb.box(Vector3(0, 2.25, 0), Vector3(W, 1.5, L), upper)
			mb.box(Vector3(0, 1.52, 0), Vector3(W * 1.01, 0.08, L * 1.0), Color(0.95, 0.8, 0.2))
			gl.box(Vector3(0, 2.15, 0.2), Vector3(W * 1.015, 0.75, L * 0.9), glass, Rect2(0, 0, 1, 1), false)
			gl.box(Vector3(0, 2.05, -L * 0.5 + 0.02), Vector3(W * 0.9, 1.0, 0.1), glass, Rect2(0, 0, 1, 1), false)
			for i in 9:
				mb.box(Vector3(0, 2.15, -L * 0.42 + i * L * 0.105), Vector3(W * 1.02, 0.78, 0.09), upper)   # window pillars
			for dz: float in [-L * 0.36, L * 0.33]:   # doorways on the left (kerb) side
				mb.box(Vector3(-W * 0.5 - 0.005, 1.35, dz), Vector3(0.03, 1.9, 0.95), Color(0.12, 0.1, 0.1))
			for sd: float in [-1.0, 1.0]:
				lt.box(Vector3(sd * W * 0.36, 0.85, -L * 0.5 - 0.02), Vector3(0.26, 0.2, 0.05), Color(1, 0.95, 0.75))
				mb.box(Vector3(sd * W * 0.4, 0.9, L * 0.5 + 0.02), Vector3(0.2, 0.3, 0.04), Color(0.8, 0.1, 0.08))
				for fz: float in [-0.3, 0.27]:
					mb.wheel(Vector3(sd * (W * 0.5 - 0.12), 0.48, fz * L), 0.48, 0.3, tyre)
			mb.box(Vector3(0, 0.5, -L * 0.5 - 0.05), Vector3(W, 0.2, 0.12), Color(0.2, 0.2, 0.2))
			mb.box(Vector3(0, 2.82, -L * 0.5 - 0.02), Vector3(1.5, 0.3, 0.04), Color(0.05, 0.05, 0.05))   # destination board
		"truck":
			var cab := Color(0.75, 0.38, 0.12)
			mb.box(Vector3(0, 0.75, 0.3), Vector3(W * 0.9, 0.3, L * 0.9), Color(0.15, 0.13, 0.12))   # chassis
			mb.box(Vector3(0, 1.75, -L * 0.36), Vector3(W, 1.9, L * 0.26), cab)
			gl.box(Vector3(0, 2.1, -L * 0.36), Vector3(W * 1.01, 0.7, L * 0.2), glass, Rect2(0, 0, 1, 1), false)
			gl.box(Vector3(0, 2.1, -L * 0.49), Vector3(W * 0.88, 0.7, 0.06), glass, Rect2(0, 0, 1, 1), false)
			mb.box(Vector3(0, 2.75, -L * 0.36), Vector3(W * 0.9, 0.25, L * 0.22), Color(0.2, 0.35, 0.6))   # painted crown board
			mb.box(Vector3(0, 1.75, L * 0.13), Vector3(W, 1.5, L * 0.7), Color(0.45, 0.3, 0.18))        # wooden bed
			mb.box(Vector3(0, 2.55, L * 0.13), Vector3(W * 0.96, 0.25, L * 0.68), Color(0.35, 0.45, 0.4))   # tarpaulin
			for sd: float in [-1.0, 1.0]:
				lt.box(Vector3(sd * W * 0.36, 1.05, -L * 0.5 - 0.0), Vector3(0.24, 0.2, 0.05), Color(1, 0.95, 0.75))
				mb.box(Vector3(sd * W * 0.4, 1.1, L * 0.5 - 0.1), Vector3(0.2, 0.2, 0.04), Color(0.8, 0.1, 0.08))
				for fz: float in [-0.34, 0.25, 0.37]:
					mb.wheel(Vector3(sd * (W * 0.5 - 0.1), 0.46, fz * L), 0.46, 0.28, tyre)
			var lb := Label3D.new()
			lb.text = "HORN OK PLEASE"
			lb.font_size = 40
			lb.pixel_size = 0.005
			lb.modulate = Color(1, 0.9, 0.2)
			lb.outline_modulate = Color(0.5, 0.1, 0.1)
			lb.position = Vector3(0, 1.75, L * 0.48 + 0.03)
			lb.visibility_range_end = 30.0
			_lean.add_child(lb)
	var mesh := ArrayMesh.new()
	mb.add_to(mesh, Mats.col(Color.WHITE, 0.45, 0.25) if false else _paint_mat())
	gl.add_to(mesh, _glass_mat())
	lt.add_to(mesh, _light_mat())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.visibility_range_end = 220.0
	_lean.add_child(mi)
	var blob := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(W * 1.7, L * 1.25)
	q.orientation = PlaneMesh.FACE_Y
	blob.mesh = q
	blob.material_override = Mats.blob()
	blob.position.y = 0.12
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)
	_signals(L, W)
	if with_rider and spec.open:
		set_rider(Human.make(Human.random_look(RandomNumberGenerator.new(), 0, "driver" if type == "auto" else "")))

func _signals(L: float, W: float) -> void:
	var y := 0.68
	match type:
		"bus", "pbus": y = 1.25
		"truck": y = 1.15
		"bike", "scooter": y = 0.72
		"auto": y = 0.75
	var two := type in ["bike", "scooter"]
	var half := 0.0 if two else W * 0.38
	_brake = MeshInstance3D.new()
	var bb := MB.new()
	for sd: float in ([0.0] if two else [-1.0, 1.0]):
		bb.box(Vector3(sd * half, y, L * 0.5 + 0.03), Vector3(0.18, 0.12, 0.05), Color.WHITE)
	var bmsh := ArrayMesh.new()
	bb.add_to(bmsh, null)
	_brake.mesh = bmsh
	_brake.material_override = Mats.glow(Color(0.5, 0.03, 0.02), 0.3)
	_brake.visibility_range_end = 120.0
	_lean.add_child(_brake)
	for sd: float in [-1.0, 1.0]:
		var ib := MB.new()
		var ix := sd * (W * 0.5 - 0.06) if not two else sd * 0.2
		ib.box(Vector3(ix, y - 0.02, L * 0.5 + 0.02), Vector3(0.1, 0.1, 0.05), Color.WHITE)
		ib.box(Vector3(ix, y - 0.02, -L * 0.5 - 0.02), Vector3(0.1, 0.1, 0.05), Color.WHITE)
		var im := ArrayMesh.new()
		ib.add_to(im, null)
		var mi := MeshInstance3D.new()
		mi.mesh = im
		mi.material_override = Mats.glow(Color(1.0, 0.6, 0.05), 3.0)
		mi.visible = false
		mi.visibility_range_end = 90.0
		_lean.add_child(mi)
		_ind[int(sd)] = mi
	# headlight throw on the road (additive, lit only after dark)
	var hl := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(W * 2.6, 11.0)
	q.orientation = PlaneMesh.FACE_Y
	hl.mesh = q
	hl.material_override = Mats.head()
	hl.position = Vector3(0, 0.27, -L * 0.5 - 5.0)
	hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hl.visibility_range_end = 70.0
	add_child(hl)

func set_brake(on: bool) -> void:
	if _brake != null:
		_brake.material_override = Mats.glow(Color(1.0, 0.08, 0.05), 3.5) if on else Mats.glow(Color(0.5, 0.03, 0.02), 0.3)

## -1 left, 1 right, 0 off
func set_indicator(dir: int) -> void:
	_ind_dir = dir
	if dir == 0:
		for k in _ind:
			_ind[k].visible = false

func _process(delta: float) -> void:
	if _ind_dir != 0:
		_blink += delta
		var on := fmod(_blink, 0.7) < 0.38
		# model +X is the right-hand side
		_ind[_ind_dir].visible = on
		_ind[-_ind_dir].visible = false
	# the body rides on its springs over the real road: per-wheel ground contact near the camera,
	# one sample under the middle further away
	if not player_driven and delta > 0.0:
		# traffic and cinematics move us directly: read the turn back from the heading change
		var yr := -wrapf(rotation.y - _prev_yaw, -PI, PI) / delta
		lat_acc = lerpf(lat_acc, v * yr, 1.0 - exp(-6.0 * delta))
	_prev_yaw = rotation.y
	var near := global_position.distance_squared_to(Human.cam_pos) < 45.0 * 45.0
	Handling.suspend(self, delta, near)

static func _paint_mat() -> StandardMaterial3D:
	var m := Mats._std("vpaint", "", 0.35, false, true)
	m.metallic = 0.25
	return m

static func _glass_mat() -> StandardMaterial3D:
	var m := Mats._std("vglass", "", 0.08, false, true)
	m.metallic = 0.6
	return m

static func _light_mat() -> StandardMaterial3D:
	var m := Mats._std("vlight", "", 0.3, false, true)
	m.emission_enabled = true
	m.emission = Color(1, 0.9, 0.7)
	m.emission_energy_multiplier = 0.6
	return m

func seat_pos() -> Vector3:
	match type:
		"auto": return Vector3(0, 0.28, -0.55)
		"bike": return Vector3(0, 0.36, 0.25)
		"scooter": return Vector3(0, 0.28, 0.2)
	return Vector3(-spec.w * 0.22, 0.2, -0.2)

func set_rider(h: Human) -> void:
	if driver != null and is_instance_valid(driver) and driver != h:
		driver.queue_free()
	driver = h
	if h == null:
		return
	if h.get_parent() != null:
		h.get_parent().remove_child(h)
	_lean.add_child(h)
	h.position = seat_pos()
	h.rotation = Vector3.ZERO
	h.state = "drive"
	h.speed = 0.0
	h.ground_follow = false
	h.visible = spec.open

func clear_rider() -> void:
	driver = null

func exit_point() -> Vector3:
	# step out on the kerb (left) side
	return global_position + global_transform.basis.x * -(float(spec.w) * 0.5 + 0.8)

# ------------------------------------------------------------------ player driving
## Compatibility: one signed pedal (+ accelerate, - brake/reverse), as the keyboard and old callers use.
func drive(delta: float, throttle: float, steer_in: float, handbrake: bool) -> void:
	drive2(delta, maxf(throttle, 0.0), maxf(-throttle, 0.0), steer_in, handbrake)

## Analogue driving: throttle and brake 0..1, steer -1..1 (see Handling.gd).
func drive2(delta: float, throttle: float, brake: float, steer_in: float, handbrake: bool) -> void:
	if hvel == Vector3.ZERO and absf(v) > 0.01:
		hvel = -global_transform.basis.z * v       # taking over a moving vehicle
	Handling.drive(self, delta, throttle, brake, steer_in, handbrake)
	velocity = hvel
	var before := global_position
	move_and_slide()
	global_position.y = 0.0
	var moved := global_position.distance_to(before) / maxf(delta, 0.001)
	if get_slide_collision_count() > 0 and moved < hvel.length() * 0.6:
		if absf(v) > 6.0:
			Sfx.play("crash", clampf(absf(v) / 15.0, 0.3, 1.0))
			if Game.world != null:
				Game.world.on_crash(self, absf(v))
		v *= 0.35
		hvel = velocity * 0.5
	_engine_sound(true)
	set_brake((brake > 0.05 and not reverse) or (throttle > 0.05 and reverse) or handbrake)
	if _spot == null:
		_spot = SpotLight3D.new()
		_spot.position = Vector3(0, 0.9, -float(spec.l) * 0.5)
		_spot.spot_range = 26.0
		_spot.spot_angle = 34.0
		_spot.light_energy = 2.5
		_spot.light_color = Color(1.0, 0.93, 0.75)
		add_child(_spot)
	_spot.visible = Mats.night_on

func _engine_sound(on: bool) -> void:
	if on and _eng == null:
		_eng = AudioStreamPlayer.new()
		_eng.stream = Sfx.stream(spec.eng)
		_eng.bus = "Sfx"
		_eng.volume_db = -9.0
		add_child(_eng)
		_eng.play()
	if _eng != null:
		if not on:
			_eng.queue_free()
			_eng = null
		else:
			_eng.pitch_scale = 0.7 + absf(v) / float(spec.max) * 1.1

func stop_engine() -> void:
	_engine_sound(false)
	v = 0.0
	set_brake(false)
	if _spot != null:
		_spot.visible = false

func honk() -> void:
	var d := 0.0
	if Game.world != null and Game.world.player != null:
		d = global_position.distance_to(Game.world.player.global_position)
	if d < 70.0:
		Sfx.play(spec.horn, clampf(1.0 - d / 70.0, 0.05, 1.0), randf_range(0.95, 1.05))
