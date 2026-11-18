class_name Handling
extends RefCounted
## Per-vehicle handling and suspension.
## The chassis stays kinematic (traffic and cinematics still place vehicles directly), but the player's
## vehicle is driven by a tyre-grip model: bicycle-model steering with speed-sensitive lock, lateral
## grip that lets the car slide when the handbrake locks the rear, an engine curve with gear changes,
## brakes, coasting drag and brake-into-reverse. Every vehicle gets raycast suspension per wheel: the
## body rides on the real road surface with springs and dampers (speed breakers, kerbs, dive, squat, roll).

# wb: wheelbase (m); steer: max road-wheel angle (rad) at rest; steer_hi: fraction of lock left at top speed
# rate/ret: steering speed toward the input / back to centre (input units per second)
# acc: peak acceleration (m/s^2); brake: braking (m/s^2); grip: lateral grip (m/s^2)
# gears; f, z: suspension natural frequency (Hz) and damping ratio; roll, pitch: body roll/pitch per m/s^2
# lean: two-wheeler (leans into turns instead of rolling out)
const P := {
	"car":     {"wb": 2.46, "steer": 0.42, "steer_hi": 0.32, "rate": 2.0, "ret": 2.8, "acc": 3.0, "brake": 7.0, "grip": 6.3, "gears": 4, "f": 1.25, "z": 0.32, "roll": 0.013, "pitch": 0.009, "lean": false, "mass": 1150},
	"taxi":    {"wb": 2.46, "steer": 0.42, "steer_hi": 0.32, "rate": 2.0, "ret": 2.8, "acc": 2.9, "brake": 7.0, "grip": 6.3, "gears": 4, "f": 1.25, "z": 0.32, "roll": 0.013, "pitch": 0.009, "lean": false, "mass": 1150},
	"hatch":   {"wb": 2.17, "steer": 0.46, "steer_hi": 0.3, "rate": 2.4, "ret": 3.2, "acc": 3.3, "brake": 7.5, "grip": 6.8, "gears": 4, "f": 1.6, "z": 0.38, "roll": 0.010, "pitch": 0.008, "lean": false, "mass": 650},
	"jeep":    {"wb": 2.40, "steer": 0.44, "steer_hi": 0.34, "rate": 2.0, "ret": 2.8, "acc": 2.9, "brake": 6.8, "grip": 6.0, "gears": 4, "f": 1.4, "z": 0.3, "roll": 0.016, "pitch": 0.010, "lean": false, "mass": 1500},
	"auto":    {"wb": 2.00, "steer": 0.60, "steer_hi": 0.45, "rate": 3.0, "ret": 3.6, "acc": 2.3, "brake": 5.5, "grip": 4.3, "gears": 4, "f": 2.0, "z": 0.28, "roll": 0.022, "pitch": 0.012, "lean": false, "mass": 350},
	"bike":    {"wb": 1.27, "steer": 0.52, "steer_hi": 0.22, "rate": 3.5, "ret": 4.2, "acc": 4.0, "brake": 7.0, "grip": 7.5, "gears": 4, "f": 1.8, "z": 0.45, "roll": 0.0, "pitch": 0.010, "lean": true, "mass": 110},
	"scooter": {"wb": 1.23, "steer": 0.55, "steer_hi": 0.25, "rate": 3.8, "ret": 4.4, "acc": 3.1, "brake": 6.0, "grip": 6.5, "gears": 4, "f": 2.0, "z": 0.4, "roll": 0.0, "pitch": 0.012, "lean": true, "mass": 105},
	"bus":     {"wb": 5.50, "steer": 0.50, "steer_hi": 0.45, "rate": 1.1, "ret": 1.6, "acc": 1.35, "brake": 4.8, "grip": 3.6, "gears": 5, "f": 1.0, "z": 0.28, "roll": 0.010, "pitch": 0.006, "lean": false, "mass": 11000},
	"pbus":    {"wb": 5.50, "steer": 0.50, "steer_hi": 0.45, "rate": 1.1, "ret": 1.6, "acc": 1.45, "brake": 4.8, "grip": 3.6, "gears": 5, "f": 1.0, "z": 0.28, "roll": 0.010, "pitch": 0.006, "lean": false, "mass": 10000},
	"truck":   {"wb": 4.20, "steer": 0.48, "steer_hi": 0.42, "rate": 1.2, "ret": 1.7, "acc": 1.2, "brake": 4.4, "grip": 3.3, "gears": 5, "f": 1.2, "z": 0.32, "roll": 0.009, "pitch": 0.006, "lean": false, "mass": 9000},
}

static func prof(type: String) -> Dictionary:
	return P.get(type, P["car"])

## Wheel contact points in the vehicle's local space (front is -Z), from its size.
static func wheels(type: String, L: float, W: float) -> Array:
	match type:
		"auto":
			return [Vector3(0, 0, -L * 0.42), Vector3(-W * 0.48, 0, L * 0.3), Vector3(W * 0.48, 0, L * 0.3)]
		"bike", "scooter":
			return [Vector3(0, 0, -L * 0.36), Vector3(0, 0, L * 0.36)]
		"bus", "pbus":
			return [Vector3(-W * 0.45, 0, -L * 0.3), Vector3(W * 0.45, 0, -L * 0.3), Vector3(-W * 0.45, 0, L * 0.27), Vector3(W * 0.45, 0, L * 0.27)]
		"truck":
			return [Vector3(-W * 0.46, 0, -L * 0.34), Vector3(W * 0.46, 0, -L * 0.34), Vector3(-W * 0.46, 0, L * 0.3), Vector3(W * 0.46, 0, L * 0.3)]
	return [Vector3(-W * 0.42, 0, -L * 0.31), Vector3(W * 0.42, 0, -L * 0.31), Vector3(-W * 0.42, 0, L * 0.31), Vector3(W * 0.42, 0, L * 0.31)]

## One physics step for a player-driven vehicle. throttle, brake: 0..1; steer_in: -1 (left) .. 1 (right).
static func drive(veh: Vehicle, delta: float, throttle: float, brake: float, steer_in: float, handbrake: bool) -> void:
	var p := prof(veh.type)
	var vmax: float = float(veh.spec.max)
	var f := -veh.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var r := Vector3(-f.z, 0, f.x)              # right
	var vel: Vector3 = veh.hvel
	var vlong := vel.dot(f)
	var vlat := vel.dot(r)
	# ---- gear selection: brake held at a standstill engages reverse; the accelerator returns to drive
	if absf(vlong) < 0.4:
		if brake > 0.5 and throttle < 0.1 and not veh.reverse:
			veh.rev_hold += delta
			if veh.rev_hold > 0.4:
				veh.reverse = true
		elif throttle > 0.1 and veh.reverse:
			veh.reverse = false
			veh.rev_hold = 0.0
	if brake < 0.1:
		veh.rev_hold = 0.0
	var drive_in := throttle
	var brake_in := brake
	if veh.reverse:
		# in reverse the brake pedal backs the vehicle up and the accelerator brakes
		drive_in = brake
		brake_in = throttle
	# ---- engine: torque falls away toward top speed, a short dip while the gearbox changes
	var top := vmax if not veh.reverse else vmax * 0.25
	var spd := absf(vlong)
	var g := clampi(int(spd / top * float(p.gears)) + 1, 1, int(p.gears))
	if g != veh.gear and not veh.reverse:
		veh.shift_t = 0.22
		veh.gear = g
	veh.shift_t = maxf(0.0, veh.shift_t - delta)
	var torque := 1.0 - pow(clampf(spd / top, 0.0, 1.0), 1.7)
	if veh.shift_t > 0.0:
		torque *= 0.35
	var dirn := -1.0 if veh.reverse else 1.0
	var a := float(p.acc) * drive_in * torque * dirn
	# brakes act against the motion; coasting: rolling resistance plus air drag
	var bk := float(p.brake) * brake_in
	if handbrake:
		bk = maxf(bk, float(p.brake) * (0.55 if not bool(p.lean) else 0.7))
	var coast := 0.25 + 0.0011 * vlong * vlong
	var dec := (bk + (coast if drive_in < 0.05 else 0.0)) * delta
	vlong += a * delta
	if absf(vlong) <= dec:
		vlong = 0.0
	else:
		vlong -= signf(vlong) * dec
	vlong = clampf(vlong, -vmax * 0.25, vmax)
	# ---- steering: the wheel turns at a human rate toward the input and returns when released
	var target := clampf(steer_in, -1.0, 1.0)
	var rate := float(p.rate) if absf(target) > absf(veh.steer) and signf(target) == signf(veh.steer if veh.steer != 0.0 else target) else float(p.ret)
	veh.steer = move_toward(veh.steer, target, rate * delta)
	var lock := float(p.steer) * lerpf(1.0, float(p.steer_hi), clampf(spd / vmax, 0.0, 1.0))
	var delta_w := veh.steer * lock
	# yaw rate from the steering geometry, limited by what the tyres can hold
	var yaw_rate := vlong * tan(delta_w) / float(p.wb)
	var grip := float(p.grip)
	var rear_free := handbrake and not bool(p.lean) and spd > 4.0
	if rear_free:
		yaw_rate *= 1.35                         # the rear steps out
		grip *= 0.45
	var lat_need := absf(vlong * yaw_rate)
	if lat_need > grip and not rear_free:
		yaw_rate *= grip / lat_need              # understeer: the front cannot turn any tighter
	veh.rotation.y -= yaw_rate * delta
	# lateral velocity: the tyres pull it back to zero as fast as grip allows (a slide when they cannot)
	var f2 := -veh.global_transform.basis.z
	f2.y = 0.0
	f2 = f2.normalized()
	var r2 := Vector3(-f2.z, 0, f2.x)
	vlat = move_toward(vlat, 0.0, grip * delta)
	veh.hvel = f2 * vlong + r2 * vlat
	veh.lat_acc = vlong * yaw_rate
	veh.v = vlong

## Suspension: springs and dampers on body height, pitch and roll, driven by the ground under each
## wheel and by the vehicle's own acceleration. Updates veh._lean (the visual body).
static func suspend(veh: Vehicle, delta: float, full: bool) -> void:
	if delta <= 0.0:
		return
	var p := prof(veh.type)
	var xf: Transform3D = veh.global_transform
	var ws: Array = veh.wheel_pts
	var hs := []
	var base_y: float = xf.origin.y
	if full:
		for w in ws:
			var wp: Vector3 = xf * (w as Vector3)
			hs.append(Ground.height(wp, 1.2) - base_y)
	else:
		var gc := Ground.height(xf.origin, 1.2) - base_y
		for w in ws:
			hs.append(gc)
	# road-shape targets
	var front := 0.0
	var rear := 0.0
	var left := 0.0
	var right := 0.0
	var nf := 0
	var nr := 0
	var nl := 0
	var nrt := 0
	var mean := 0.0
	for i in ws.size():
		var w: Vector3 = ws[i]
		var hh: float = hs[i]
		mean += hh
		if w.z < 0.0:
			front += hh; nf += 1
		else:
			rear += hh; nr += 1
		if w.x < -0.05:
			left += hh; nl += 1
		elif w.x > 0.05:
			right += hh; nrt += 1
	mean /= maxf(1.0, float(ws.size()))
	var wb: float = absf((ws[0] as Vector3).z - (ws[ws.size() - 1] as Vector3).z)
	var t_pitch := 0.0
	if nf > 0 and nr > 0 and wb > 0.1:
		t_pitch = atan2(front / nf - rear / nr, wb)          # nose up when the front is higher
	var t_roll := 0.0
	var track := 1.0
	if nl > 0 and nrt > 0:
		var xmin := 0.0
		var xmax := 0.0
		for w in ws:
			xmin = minf(xmin, (w as Vector3).x)
			xmax = maxf(xmax, (w as Vector3).x)
		track = xmax - xmin
		t_roll = atan2(right / nrt - left / nl, maxf(track, 0.3))
	# dynamic: dive under braking / squat on throttle; roll away from the turn (or lean into it)
	var acc_long: float = (veh.v - veh._prev_v) / delta
	veh._prev_v = veh.v
	veh._acc_f = lerpf(veh._acc_f, acc_long, 1.0 - exp(-8.0 * delta))
	t_pitch += clampf(veh._acc_f * float(p.pitch), -0.07, 0.07)
	if bool(p.lean):
		t_roll = clampf(-atan2(veh.lat_acc, 9.81), -0.65, 0.65)     # leans into the turn (right turn: right side down)
	else:
		t_roll += clampf(veh.lat_acc * float(p.roll), -0.09, 0.09)  # rolls out of the turn (right turn: right side up)
	# springs (critically under-damped, per the profile)
	var wn: float = TAU * float(p.f)
	var k := wn * wn
	var c := 2.0 * float(p.z) * wn
	var st: Vector3 = veh.susp          # x: height, y: pitch, z: roll
	var sv: Vector3 = veh.susp_v
	var tgt := Vector3(mean, t_pitch, t_roll)
	if bool(p.lean):
		# a two-wheeler's lean is steered, not sprung
		st.z = lerpf(st.z, t_roll, 1.0 - exp(-6.0 * delta))
		sv.z = 0.0
		tgt.z = st.z
	var n := 2
	var dt := delta / n
	for i in n:
		var acc := (tgt - st) * k - sv * c
		if bool(p.lean):
			acc.z = 0.0
		sv += acc * dt
		st += sv * dt
	# hard contact: the tyres are part of the body, so no wheel may end up below the ground under it.
	# Tilt toward the road shape first, then lift the body by whatever is still missing.
	if full and not bool(p.lean):
		for _it in 2:
			var worst := 0.0
			var worst_i := -1
			for i in ws.size():
				var w: Vector3 = ws[i]
				var at := st.x - w.z * st.y + w.x * st.z      # wheel contact height with this pitch/roll
				var short: float = float(hs[i]) - 0.025 - at  # 2.5 cm of tyre squash allowed
				if short > worst:
					worst = short
					worst_i = i
			if worst_i < 0:
				break
			var wi: Vector3 = ws[worst_i]
			if absf(wi.z) > 0.2:
				var dp := clampf(worst * 0.5 / -wi.z, -0.08, 0.08)   # half by pitching toward that wheel
				st.y += dp
				sv.y = maxf(sv.y, 0.0) if dp > 0.0 else minf(sv.y, 0.0)
				worst *= 0.5
			st.x += worst
			sv.x = maxf(sv.x, 0.0)
	elif bool(p.lean):
		for i in ws.size():
			var w2: Vector3 = ws[i]
			var at2 := st.x - w2.z * st.y
			var short2: float = float(hs[i]) - 0.025 - at2
			if short2 > 0.0:
				st.x += short2
				sv.x = maxf(sv.x, 0.0)
	st.x = clampf(st.x, mean - 0.06, mean + 0.25)
	veh.susp = st
	veh.susp_v = sv
	veh._lean.position.y = st.x
	veh._lean.rotation.x = st.y
	veh._lean.rotation.z = st.z
