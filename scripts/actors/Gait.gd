class_name Gait
extends RefCounted
## Procedural, ground-locked locomotion for a Human.
##
## Each foot is either PLANTED (locked to a point in the world: it cannot slide) or
## SWINGING (travelling an arc to a footfall predicted from the body's velocity, placed
## on the real walkable surface by a raycast, so kerbs, ramps and stairs just work).
## Analytic two-bone IK puts each leg on its foot with the knee over the toes. The pelvis
## carries the weight: it bobs, shifts over the stance foot, yaws with the stride and
## drops on the swing side; the spine and shoulders counter-rotate and the arms swing
## from the legs. Heel strike, foot-flat and toe-off come from where the foot is relative
## to the body. Standing still, the feet stay planted while the hips shift weight; when
## the body turns or drifts too far from the feet, the feet take real steps.

var h: Human
var sk: Skeleton3D
var bi := {}                   # bone -> index
var rest := {}                 # bone -> rest position (skeleton space)
var len1 := {}                 # side -> thigh length
var len2 := {}                 # side -> shin length
var feet := {}                 # side -> state Dictionary
var vel := Vector3.ZERO        # smoothed ground velocity (world)
var acc := Vector3.ZERO
var _prev_pos := Vector3.ZERO
var _prev_vel := Vector3.ZERO
var _have_prev := false
var _idle_t := 0.0
var _land_gap := 0.0
var _seed := 0.0
var pelvis_off := Vector3.ZERO  # current pelvis offset (skeleton space)
var _swing_side := ""          # which foot is in the air ("" = both planted)
var stance_width := 0.115
var run_mode := false
var _run_cycle := 0.0
# measurements for validation
var stats := {"slide_max": 0.0, "ground_err_max": 0.0, "samples": 0, "steps": 0, "reach_fail": 0}
var _meas := {}

const UP := Vector3.UP

func _init(human: Human) -> void:
	h = human
	sk = human.skel
	_seed = randf() * 10.0
	for b in ["Root", "pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r",
			"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "spine_03", "head", "middle_01_l", "middle_01_r", "index_01_l", "index_01_r", "pinky_01_l", "pinky_01_r"]:
		bi[b] = sk.find_bone(b)
		if bi[b] >= 0:
			rest[b] = sk.get_bone_global_rest(bi[b]).origin
	for s in ["l", "r"]:
		len1[s] = (rest["calf_" + s] - rest["thigh_" + s]).length()
		len2[s] = (rest["foot_" + s] - rest["calf_" + s]).length()
		feet[s] = {"planted": true, "lock": Vector3.ZERO, "yaw": 0.0, "t": 0.0, "dur": 0.4, "from": Vector3.ZERO,
			"to": Vector3.ZERO, "from_yaw": 0.0, "lift": 0.06, "land": 1.0, "pitch": 0.0}

# ------------------------------------------------------------------ helpers
func _xf() -> Transform3D:
	return sk.global_transform

func facing_yaw() -> float:
	return h.global_rotation.y

func _fwd() -> Vector3:
	var y := facing_yaw()
	return Vector3(-sin(y), 0, -cos(y))

func _right() -> Vector3:
	var y := facing_yaw()
	return Vector3(cos(y), 0, -sin(y))

func _side_sign(s: String) -> float:
	return -1.0 if s == "l" else 1.0

func _ground_at(p: Vector3) -> Dictionary:
	var r := Ground.hit(Vector3(p.x, h.global_position.y + h._gy + 0.6, p.z), 0.0, 1.6)
	if r.is_empty():
		return {"y": h.global_position.y + h._gy, "n": UP}
	return {"y": float(r.position.y), "n": r.normal}

## Where a foot would stand if the body stopped right now.
func _home(s: String, lead := 0.0) -> Vector3:
	var p := h.global_position + _right() * _side_sign(s) * stance_width * h.body.scale.x + vel * lead
	var g := _ground_at(p)
	return Vector3(p.x, g.y, p.z)

## Put both feet under the body (spawn, teleport, leaving a seat or a vehicle).
func reset() -> void:
	foot_ground_ok = false
	for s in feet:
		var f: Dictionary = feet[s]
		var p := _home(s)
		f.planted = true
		f.lock = p
		f.yaw = facing_yaw() + _side_sign(s) * -0.1
		f.pitch = 0.0
		f.land = 1.0
	_swing_side = ""
	_prev_pos = h.global_position
	_have_prev = true
	vel = Vector3.ZERO
	pelvis_off = Vector3.ZERO

func _start_swing(s: String, dur: float, lift: float) -> void:
	var f: Dictionary = feet[s]
	f.planted = false
	f.t = 0.0
	f.dur = dur
	f.from = f.lock
	f.from_yaw = f.yaw
	f.lift = lift
	f.to = _target(s, dur)
	_swing_side = s
	stats.steps = int(stats.steps) + 1

## The predicted footfall: where the body will be when this foot lands, plus half a
## stance ahead, at the side of the body, on the real ground.
func _target(s: String, remaining: float) -> Vector3:
	var spd := Vector2(vel.x, vel.z).length()
	# land under the body when running (short contact), further ahead when walking
	var stance_half := lerpf(0.21, 0.07, clampf((spd - 1.6) / 2.5, 0.0, 1.0))
	# where the body will be: current velocity plus what it is gaining (starting off, slowing down)
	var tt := remaining + stance_half
	var a := acc
	a.y = 0.0
	if a.length() > 6.0:
		a = a.normalized() * 6.0
	var travel := vel * tt + a * (0.5 * tt * tt)
	if travel.dot(vel) < 0.0 and spd < 0.5:
		travel = Vector3.ZERO                       # braking: don't reach backwards
	var p := h.global_position + _right() * _side_sign(s) * stance_width * h.body.scale.x + travel
	p = _on_one_tread(p)
	var g := _ground_at(p)
	return Vector3(p.x, g.y, p.z)

## Slide a footfall along the walking direction so the whole sole (heel to toe) lands on one level:
## no heel hanging off a stair edge, no toes over a kerb.
func _on_one_tread(p: Vector3) -> Vector3:
	var fd := Vector3(vel.x, 0, vel.z)
	fd = fd.normalized() if fd.length() > 0.2 else _fwd()
	var sc: float = h.body.scale.z
	var back := 0.07 * sc       # heel behind the ankle
	var front := 0.19 * sc      # toe ahead of the ankle
	var yh: float = float(_ground_at(p - fd * back).y)
	var yt: float = float(_ground_at(p + fd * front).y)
	if absf(yh - yt) < 0.02:
		return p
	# find the edge between heel and toe
	var lo := -back
	var hi := front
	for i in 7:
		var m := (lo + hi) * 0.5
		var ym: float = float(_ground_at(p + fd * m).y)
		if absf(ym - yh) < 0.01:
			lo = m
		else:
			hi = m
	var edge := (lo + hi) * 0.5
	# most of the foot on the far side: step fully past the edge; otherwise stay short of it
	if edge < (front - back) * 0.5:
		return p + fd * (edge + back + 0.03)
	return p - fd * (front - edge + 0.02)

# ------------------------------------------------------------------ per frame (before the upper body is posed)
## Updates foot planning and returns additions for the upper body: {tor, hd, armL, armR, elbow, hip}.
func plan(delta: float, upper_free: bool) -> Dictionary:
	var pos := h.global_position
	if not _have_prev:
		reset()
	var raw := (pos - _prev_pos) / maxf(delta, 0.0001)
	raw.y = 0.0
	if raw.length() > 12.0:          # teleported: the feet come with us
		reset()
		raw = Vector3.ZERO
	_prev_pos = pos
	var kv := 1.0 - exp(-9.0 * delta)
	vel = vel.lerp(raw, kv)
	acc = acc.lerp((vel - _prev_vel) / maxf(delta, 0.0001), 1.0 - exp(-6.0 * delta))
	_prev_vel = vel
	var spd := Vector2(vel.x, vel.z).length()
	var running := clampf((spd - 2.2) / 2.5, 0.0, 1.0)
	var step_dur := clampf(0.56 - 0.075 * spd, 0.26, 0.56)
	var lift := lerpf(0.055, 0.13, running)
	# --- advance the swinging foot
	for s in feet:
		var f: Dictionary = feet[s]
		if f.planted:
			f.land = minf(1.0, float(f.land) + delta / 0.12)
			continue
		if run_mode:
			continue
		f.t = float(f.t) + delta / float(f.dur)
		var t: float = clampf(f.t, 0.0, 1.0)
		if t < 0.8:                  # keep aiming at where the body is going
			var nt := _target(s, float(f.dur) * (1.0 - t))
			f.to = (f.to as Vector3).lerp(nt, 0.8)
		if t >= 1.0:
			f.planted = true
			f.lock = f.to
			f.yaw = facing_yaw() + _side_sign(s) * -0.1
			f.land = 0.0
			var other := "r" if s == "l" else "l"
			_swing_side = "" if feet[other].planted else other
			_land_gap = 0.0
	# --- running: a fixed rhythm; each foot is on the ground about a third of the cycle,
	# and between contacts the body is in the air
	if run_mode and spd < 1.8:
		run_mode = false
	elif not run_mode and spd > 2.1:
		run_mode = true
		_run_cycle = 0.5 if feet.l.planted else 0.0
	if run_mode:
		var T := clampf(0.74 - 0.035 * spd, 0.56, 0.68)
		var duty := 0.34
		_run_cycle += delta / T
		for s in feet:
			var f: Dictionary = feet[s]
			var ph := fposmod(_run_cycle + (0.0 if s == "l" else 0.5), 1.0)
			var side := _right() * _side_sign(s) * stance_width * 0.8 * h.body.scale.x
			if ph < duty:
				if not f.planted:
					var lp := pos + side + vel * (duty * T * 0.5 - ph * T)
					var g := _ground_at(lp)
					f.planted = true
					f.lock = Vector3(lp.x, g.y, lp.z)
					f.yaw = facing_yaw() + _side_sign(s) * -0.06
					f.land = 0.4
					stats.steps = int(stats.steps) + 1
			else:
				if f.planted:
					f.planted = false
					f.from = f.lock
					f.from_yaw = f.yaw
					f.lift = 0.17
				f.t = (ph - duty) / (1.0 - duty)
				f.dur = T * (1.0 - duty)
				var tp := pos + side + vel * ((1.0 - ph) * T + duty * T * 0.5)
				var g2 := _ground_at(tp)
				f.to = Vector3(tp.x, g2.y, tp.z)
		_swing_side = "" if (feet.l.planted and feet.r.planted) else ("l" if not feet.l.planted else "r")
	# --- decide the next step
	_land_gap += delta
	var moving := spd > 0.18
	if run_mode:
		pass
	elif moving:
		_idle_t = 0.0
		var double_support := lerpf(0.09, 0.0, running)
		var other_busy: bool = not (bool(feet.l.planted) and bool(feet.r.planted))
		# a planted foot left far behind (sudden start, a sharp turn) hurries the step in progress
		for s in feet:
			var fl: Dictionary = feet[s]
			if fl.planted and other_busy:
				var behind := -((fl.lock as Vector3) - pos).dot(vel.normalized())
				if behind > 0.42:
					var sw0: Dictionary = feet[_swing_side]
					sw0.dur = minf(float(sw0.dur), 0.28)
		var can: bool = (not other_busy and _land_gap >= double_support)
		if other_busy and running > 0.4 and (bool(feet.l.planted) or bool(feet.r.planted)):
			# a run has a flight phase: the stance foot pushes off before the swinging one lands
			var sw: Dictionary = feet[_swing_side]
			can = float(sw.t) > lerpf(0.82, 0.5, running)
		if can:
			# the foot furthest behind where it should be goes next
			var best := ""
			var best_lag := 0.03
			for s in feet:
				var f2: Dictionary = feet[s]
				if not f2.planted:
					continue
				var lag := (_target(s, step_dur) - (f2.lock as Vector3)).dot(vel.normalized())
				if lag > best_lag or -((f2.lock as Vector3) - pos).dot(vel.normalized()) > 0.42:
					best_lag = lag
					best = s
			if best != "":
				_start_swing(best, step_dur * lerpf(1.0, 0.85, running), lift)
	else:
		_idle_t += delta
		if _swing_side == "" and _idle_t > 0.12:
			# settle: a foot left behind, or a body turned away from its feet, takes a step
			var worst := ""
			var worst_e := 0.0
			for s in feet:
				var f3: Dictionary = feet[s]
				var e := Vector2((f3.lock as Vector3).x - _home(s).x, (f3.lock as Vector3).z - _home(s).z).length()
				var ye := absf(wrapf(float(f3.yaw) - (facing_yaw() + _side_sign(s) * -0.1), -PI, PI))
				var score := maxf(e / 0.16, ye / 0.5)
				if score > 1.0 and score > worst_e:
					worst_e = score
					worst = s
			if worst != "":
				_start_swing(worst, 0.4, 0.045)
	# --- what the upper body does with the legs
	var out := {"tor": Vector3.ZERO, "hd": Vector3.ZERO, "armL": 0.0, "armR": 0.0, "elbow": 0.0, "hip": Vector3.ZERO}
	var fwd := _fwd()
	var pl: Vector3 = feet.l.lock if feet.l.planted else _swing_pos("l")
	var pr: Vector3 = feet.r.lock if feet.r.planted else _swing_pos("r")
	var relL: float = (pl - pos).dot(fwd)
	var relR: float = (pr - pos).dot(fwd)
	var stride: float = relL - relR                        # >0: left foot ahead
	var amt := clampf(spd / 1.4, 0.0, 1.0)
	# pelvis yaws with the leading leg; shoulders counter-rotate; arms swing opposite their legs
	out.hip = Vector3(0, clampf(stride * 0.22, -0.16, 0.16), 0)
	out.tor = Vector3(-(0.03 * amt + 0.12 * running + clampf(fwd.dot(acc) * 0.025, -0.08, 0.1)), -clampf(stride * 0.32, -0.22, 0.22), 0)
	out.hd = Vector3(0.02 * running, clampf(stride * 0.12, -0.08, 0.08), 0)
	if upper_free:
		out.armL = clampf(-stride * lerpf(0.75, 1.15, running), -0.75, 0.9)
		out.armR = clampf(stride * lerpf(0.75, 1.15, running), -0.75, 0.9)
		out.elbow = lerpf(0.12, 1.25, running) * amt + 0.1
	return out

func _swing_pos(s: String) -> Vector3:
	var f: Dictionary = feet[s]
	var t: float = clampf(f.t, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	var p := (f.from as Vector3).lerp(f.to, e)
	var y0: float = (f.from as Vector3).y
	var y1: float = (f.to as Vector3).y
	# stepping up: get the foot up early (clear the riser); stepping down: stay up until over the tread
	var v := clampf((t - 0.05) / 0.5, 0.0, 1.0) if y1 > y0 else clampf((t - 0.45) / 0.5, 0.0, 1.0)
	v = v * v * (3.0 - 2.0 * v)
	p.y = lerpf(y0, y1, v) + float(f.lift) * sin(PI * t)
	return p

# ------------------------------------------------------------------ per frame (after the upper body): pelvis and legs
func apply(delta: float) -> void:
	var xf := _xf()
	var inv := xf.affine_inverse()
	var spd := Vector2(vel.x, vel.z).length()
	var running := clampf((spd - 2.2) / 2.5, 0.0, 1.0)
	var pos := h.global_position
	# per-foot targets in the world: ankle position and foot orientation
	var targets := {}
	for s in feet:
		var f: Dictionary = feet[s]
		var sole: Vector3
		var yaw: float
		var pitch := 0.0
		var n := UP
		if f.planted:
			sole = f.lock
			yaw = f.yaw
			var rel := (sole - pos).dot(_fwd())
			if spd > 0.25:
				pitch = clampf((-rel - 0.06) * 3.2, 0.0, 0.85)       # heel rises as the foot trails: toe-off
			pitch -= 0.22 * (1.0 - float(f.land))                    # heel strike, then the foot lays flat
			n = _ground_at(sole).n
		else:
			var t: float = clampf(f.t, 0.0, 1.0)
			sole = _swing_pos(s)
			yaw = lerp_angle(float(f.from_yaw), facing_yaw() + _side_sign(s) * -0.1, t * t * (3.0 - 2.0 * t))
			pitch = lerpf(0.55, -0.22, clampf(t * 1.4, 0.0, 1.0)) if spd > 0.25 else lerpf(0.15, 0.0, t)
		f.pitch = pitch
		targets[s] = {"sole": sole, "yaw": yaw, "pitch": pitch, "n": n}
	# the height the body is carried at: between the two footholds (a swinging foot counts where it will land)
	# only feet actually on the ground count (a swing target can be stale, e.g. in the run cycle),
	# blended with the ground under the body and kept close to it
	var g_mid: float = float(_ground_at(pos).y)
	var hy := []
	for s in feet:
		var f: Dictionary = feet[s]
		if f.planted:
			hy.append(float((f.lock as Vector3).y))
	var fy := g_mid
	if hy.size() == 2:
		fy = (float(hy[0]) + float(hy[1])) * 0.5
	elif hy.size() == 1:
		fy = (float(hy[0]) + g_mid) * 0.5
	foot_ground_y = clampf(fy, g_mid - 0.2, g_mid + 0.2)
	foot_ground_ok = true
	# --- pelvis: weight over the stance leg, bob, and low enough for both legs to reach
	var off := Vector3.ZERO
	var t_sw := 0.0
	var stance_sign := 0.0
	if _swing_side != "":
		t_sw = clampf(float(feet[_swing_side].t), 0.0, 1.0)
		stance_sign = -_side_sign(_swing_side)            # weight goes over the other foot
	if not bool(feet.l.planted) and not bool(feet.r.planted):
		off.y = 0.01                                     # flight: the body rides its momentum
	elif spd > 0.2:
		var bob := lerpf(0.022, 0.035, running)
		off.y = -lerpf(0.012, 0.045, running) + bob * (sin(PI * t_sw) - 0.5) * (1.0 if _swing_side != "" else -1.0)
		off.x = stance_sign * lerpf(0.022, 0.01, running)
	else:
		# standing: a slow shift of weight from foot to foot (quick and small when nervous, long and deep when relaxed)
		var fq: float = {"nervous": 0.7, "relaxed": 0.16, "tired": 0.18, "confident": 0.22}.get(h.posture, 0.27)
		var am: float = {"nervous": 0.012, "relaxed": 0.034, "tired": 0.03, "confident": 0.016}.get(h.posture, 0.022)
		var w := sin(h._t * float(fq) + _seed)
		off.x = w * float(am)
		off.y = -0.006 - absf(w) * 0.008
	# reach: a foot lower than the body (a step down, a trailing foot) pulls the hips down
	var prot := sk.get_bone_pose_rotation(bi["pelvis"])
	var need_total := 0.0
	for _pass in 2:
		var need := 0.0
		for s in feet:
			var p0: Vector3 = rest["pelvis"]
			var th: Vector3 = rest["thigh_" + s]
			var hip: Vector3 = p0 + off + prot * (th - p0)
			var a: Vector3 = _ankle_skel(s, targets[s], inv)
			var lmax: float = (float(len1[s]) + float(len2[s])) * 0.985
			var d: Vector3 = a - hip
			if d.length() > lmax:
				var horiz := Vector2(d.x, d.z).length()
				var vert_ok := sqrt(maxf(lmax * lmax - horiz * horiz, 0.0))
				need = minf(need, -(absf(d.y) - vert_ok))
		off.y += need
		need_total += need
	off.y = maxf(off.y, -0.16)          # a person bends the knees, they do not sink to the floor
	pelvis_off = pelvis_off.lerp(off, 1.0 - exp(-14.0 * delta))
	if need_total < -0.001:
		pelvis_off.y = minf(pelvis_off.y, off.y)   # a leg that cannot reach pulls the hips down now, not next frame
	sk.set_bone_pose_position(bi["pelvis"], rest["pelvis"] + pelvis_off)
	# --- legs
	for s in feet:
		_solve_leg(s, targets[s], inv, prot)

## Ankle position (skeleton space) for a foot target, rolling about the ball (toe-off)
## or the heel (heel strike).
func _ankle_skel(s: String, tg: Dictionary, inv: Transform3D) -> Vector3:
	var A: Vector3 = rest["foot_" + s]
	var Bl: Vector3 = rest["ball_" + s]
	var G := _foot_rot(tg, inv)
	var sole_s: Vector3 = inv * (tg.sole as Vector3)
	var pitch: float = tg.pitch
	var piv_rest := Vector3(A.x, 0, A.z)
	var piv := sole_s
	var fs := _yaw_dir_skel(float(tg.yaw), inv)
	# the pivot (ball or heel) lies on the ground plane, which on a ramp is not level with the ankle
	var n_s: Vector3 = (inv.basis * (tg.n as Vector3)).normalized()
	if pitch > 0.0:
		var lb := Vector2(Bl.x - A.x, Bl.z - A.z).length()
		piv_rest = Vector3(Bl.x, 0, Bl.z)
		piv = sole_s + fs * lb
	elif pitch < 0.0:
		piv_rest = Vector3(A.x, 0, A.z + 0.06)
		piv = sole_s - fs * 0.06
	if n_s.y > 0.5:
		var o := piv - sole_s
		piv.y += -(n_s.x * o.x + n_s.z * o.z) / n_s.y
	return piv + G * (A - piv_rest)

func _yaw_dir_skel(yaw: float, inv: Transform3D) -> Vector3:
	var wd := Vector3(-sin(yaw), 0, -cos(yaw))
	var d := (inv.basis * wd)
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3(0, 0, -1)

func _foot_rot(tg: Dictionary, inv: Transform3D) -> Quaternion:
	var fs := _yaw_dir_skel(float(tg.yaw), inv)
	var qy := Quaternion(Vector3(0, 0, -1), fs) if fs.dot(Vector3(0, 0, -1)) > -0.999 else Quaternion(UP, PI)
	var lat := fs.cross(UP).normalized()
	var qp := Quaternion(lat, -float(tg.pitch))
	var n_s: Vector3 = (inv.basis * (tg.n as Vector3)).normalized()
	var qn := Quaternion(UP, n_s) if n_s.dot(UP) < 0.9999 else Quaternion.IDENTITY
	return qn * qp * qy

static func _frame(axis: Vector3, hinge: Vector3) -> Basis:
	var y := axis.normalized()
	var x := (hinge - y * hinge.dot(y)).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)

func _solve_leg(s: String, tg: Dictionary, inv: Transform3D, prot: Quaternion) -> void:
	var H: Vector3 = rest["thigh_" + s]
	var K: Vector3 = rest["calf_" + s]
	var A: Vector3 = rest["foot_" + s]
	var P0: Vector3 = rest["pelvis"]
	var hip := P0 + pelvis_off + prot * (H - P0)
	var ankle := _ankle_skel(s, tg, inv)
	var l1: float = len1[s]
	var l2: float = len2[s]
	var d := ankle - hip
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.002)
	if d.length() > l1 + l2:
		stats.reach_fail = int(stats.reach_fail) + 1
	var dn := d.normalized()
	# the knee points over the toes, a little outward
	var fs := _yaw_dir_skel(float(tg.yaw), inv)
	var pole := (fs + Vector3(_side_sign(s) * 0.12, 0, 0)).normalized()
	var pp := (pole - dn * pole.dot(dn))
	if pp.length() < 0.001:
		pp = Vector3(0, 0, -1)
	pp = pp.normalized()
	var ca := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var a1 := acos(ca)
	var u := (dn * cos(a1) + pp * sin(a1)).normalized()          # thigh direction
	var knee := hip + u * l1
	var v := (hip + dn * dist - knee).normalized()                # shin direction
	var hinge_d := u.cross(pp)
	if hinge_d.length() < 0.001:
		hinge_d = Vector3(1, 0, 0)
	hinge_d = hinge_d.normalized()
	var r1 := (K - H).normalized()
	var r2 := (A - K).normalized()
	var rest_pole := Vector3(0, 0, -1)
	var B1 := _frame(u, hinge_d) * _frame(r1, r1.cross(rest_pole)).inverse()
	var B2 := _frame(v, hinge_d) * _frame(r2, r2.cross(rest_pole)).inverse()
	var g1 := B1.get_rotation_quaternion()
	var g2 := B2.get_rotation_quaternion()
	var g3 := _foot_rot(tg, inv)
	sk.set_bone_pose_rotation(bi["thigh_" + s], prot.inverse() * g1)
	sk.set_bone_pose_rotation(bi["calf_" + s], g1.inverse() * g2)
	sk.set_bone_pose_rotation(bi["foot_" + s], g2.inverse() * g3)
	# toes stay flat on the ground while the heel is up
	var pitch: float = tg.pitch
	if pitch > 0.0:
		var lat := fs.cross(UP).normalized()
		sk.set_bone_pose_rotation(bi["ball_" + s], Quaternion(g3.inverse() * lat, pitch))
	else:
		sk.set_bone_pose_rotation(bi["ball_" + s], Quaternion.IDENTITY)

# ------------------------------------------------------------------ arms: reaching for things
## Two-bone IK for an arm: the palm goes to `target` (world), the elbow hangs down, out and back.
## `w` blends from the animated pose (0) to the reach (1). Returns how far the palm ends up from the target.
var arm_dbg := {}
var foot_ground_y := 0.0
var foot_ground_ok := false

## Rest-space offset from the wrist to the centre of the palm (between the knuckles and the wrist).
func _palm_rest(s: String) -> Vector3:
	var Wr: Vector3 = rest["hand_" + s]
	var k: Vector3 = (rest["middle_01_" + s] * 2.0 + rest["index_01_" + s] + rest["pinky_01_" + s]) / 4.0
	return (k - Wr) * 0.6

## World position of the centre of the palm, from the posed skeleton.
func palm(s: String) -> Vector3:
	var gp := sk.get_bone_global_pose(bi["hand_" + s])
	return _xf() * (gp.origin + gp.basis * _palm_rest(s))

## Two-bone arm IK that lands the centre of the palm on the target (the wrist is kept straight
## while reaching). Returns how far the palm is short of the target (0 when it is reached).
func solve_arm(s: String, target: Vector3, w: float) -> float:
	if w <= 0.001:
		return 0.0
	var xf := _xf()
	var inv := xf.affine_inverse()
	var ui: int = bi["upperarm_" + s]
	var li: int = bi["lowerarm_" + s]
	var hi: int = bi["hand_" + s]
	var ci: int = bi["clavicle_" + s]
	var S := sk.get_bone_global_pose(ui).origin
	var Sr: Vector3 = rest["upperarm_" + s]
	var Er: Vector3 = rest["lowerarm_" + s]
	var Wr: Vector3 = rest["hand_" + s]
	var pr := _palm_rest(s)
	var la := (Er - Sr).length()
	var lb := (Wr - Er).length()
	var T: Vector3 = inv * target
	var r1 := (Er - Sr).normalized()
	var r2 := (Wr - Er).normalized()
	var rest_pole := Vector3(0, 0, 1)
	var sg := _side_sign(s)
	var pole := Vector3(sg * 0.55, -1.0, 0.45).normalized()
	var wrist := T - (T - S).normalized() * pr.length()
	var g1 := Quaternion.IDENTITY
	var g2 := Quaternion.IDENTITY
	var elbow := S
	var reach_w := S
	for it in 2:
		var d := wrist - S
		var dist := clampf(d.length(), absf(la - lb) + 0.02, la + lb - 0.003)
		var dn := d.normalized()
		var pp := pole - dn * pole.dot(dn)
		if pp.length() < 0.001:
			pp = Vector3(0, -1, 0)
		pp = pp.normalized()
		var a1 := acos(clampf((la * la + dist * dist - lb * lb) / (2.0 * la * dist), -1.0, 1.0))
		var u := (dn * cos(a1) + pp * sin(a1)).normalized()
		elbow = S + u * la
		reach_w = S + dn * dist
		var v := (reach_w - elbow).normalized()
		var hinge := u.cross(pp)
		if hinge.length() < 0.001:
			hinge = Vector3(0, 0, 1)
		g1 = (_frame(u, hinge) * _frame(r1, r1.cross(rest_pole)).inverse()).get_rotation_quaternion()
		g2 = (_frame(v, hinge) * _frame(r2, r2.cross(rest_pole)).inverse()).get_rotation_quaternion()
		# where the palm ends up with a straight wrist; move the wrist target by the miss
		var palm_at := reach_w + g2 * pr
		wrist += T - palm_at
	var pc := sk.get_bone_global_pose(ci).basis.get_rotation_quaternion()
	var lu := pc.inverse() * g1
	var ll := g1.inverse() * g2
	sk.set_bone_pose_rotation(ui, sk.get_bone_pose_rotation(ui).slerp(lu, w))
	sk.set_bone_pose_rotation(li, sk.get_bone_pose_rotation(li).slerp(ll, w))
	sk.set_bone_pose_rotation(hi, sk.get_bone_pose_rotation(hi).slerp(Quaternion.IDENTITY, w))
	var palm_end := reach_w + g2 * pr
	arm_dbg[s] = {"S": xf * S, "elbow": xf * elbow, "wrist": xf * reach_w, "palm": xf * palm_end}
	return (xf * palm_end).distance_to(target)

# ------------------------------------------------------------------ sitting
var seat := {}                 # {pos: seat surface centre (world), yaw, feet: {l, r}}
var seat_t := 0.0              # 0 standing .. 1 seated
var seat_dir := 0              # +1 sitting down, -1 standing up

func sit_on(seat_pos: Vector3, yaw: float) -> void:
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	seat = {"pos": seat_pos, "yaw": yaw, "feet": {}}
	for s in ["l", "r"]:
		var p := seat_pos + fwd * 0.42 + right * _side_sign(s) * 0.15
		var g := _ground_at(p)
		seat.feet[s] = Vector3(p.x, g.y, p.z)
	seat_dir = 1

func stand_up() -> void:
	seat_dir = -1

## Pelvis position (world) for the sit transition: over the feet, leaning, then down and back onto the seat.
func _seat_pelvis(stand_pelvis: Vector3) -> Vector3:
	var sp: Vector3 = seat.pos
	var fwd := Vector3(-sin(float(seat.yaw)), 0, -cos(float(seat.yaw)))
	var seated := sp + Vector3(0, 0.1 * h.body.scale.y, 0) + fwd * 0.04
	var t := seat_t
	var k := t * t * (3.0 - 2.0 * t)
	var p := stand_pelvis.lerp(seated, k)
	p += fwd * sin(PI * t) * 0.14                    # the hips go forward over the feet on the way down/up
	return p

func seat_update(delta: float) -> void:
	if seat_dir != 0:
		seat_t = clampf(seat_t + seat_dir * delta / 1.35, 0.0, 1.0)
		if seat_t <= 0.0 and seat_dir < 0:
			seat_dir = 0
			seat = {}
			reset()
		elif seat_t >= 1.0 and seat_dir > 0:
			seat_dir = 0

func seating() -> bool:
	return not seat.is_empty()

## Pelvis and legs while sitting or getting up: the feet stay planted in front of the seat.
func apply_seat(_delta: float) -> void:
	var xf := _xf()
	var inv := xf.affine_inverse()
	var stand: Vector3 = xf * (rest["pelvis"] as Vector3)
	var pw := _seat_pelvis(stand)
	var off: Vector3 = inv * pw - (rest["pelvis"] as Vector3)
	pelvis_off = off
	sk.set_bone_pose_position(bi["pelvis"], rest["pelvis"] + off)
	var prot := sk.get_bone_pose_rotation(bi["pelvis"])
	for s in ["l", "r"]:
		var tg := {"sole": seat.feet[s], "yaw": float(seat.yaw) + _side_sign(s) * -0.12, "pitch": 0.0, "n": UP}
		feet[s].lock = seat.feet[s]
		feet[s].planted = true
		_solve_leg(s, tg, inv, prot)

## How far the body is from sitting on the seat surface (for validation): pelvis contact error.
func seat_error() -> float:
	if seat.is_empty():
		return 0.0
	var xf := _xf()
	var p := xf * sk.get_bone_global_pose(bi["pelvis"]).origin
	return absf((p.y - 0.1 * h.body.scale.y) - float((seat.pos as Vector3).y))

# ------------------------------------------------------------------ validation
## Measure where the feet really are (from the posed skeleton) against where they should be.
func measure() -> void:
	var xf := _xf()
	for s in feet:
		var f: Dictionary = feet[s]
		if not f.planted or float(f.land) < 1.0:
			continue
		# the point the foot is standing on: the heel/sole when flat, the ball when the heel is up
		var bone: String = ("ball_" + s) if float(f.pitch) > 0.02 else ("foot_" + s)
		var a: Vector3 = xf * sk.get_bone_global_pose(bi[bone]).origin
		var key: String = str(f.lock) + bone
		var rec: Array = _meas.get(s, ["", Vector3.ZERO])
		if rec[0] != key:
			rec = [key, a]
			_meas[s] = rec
		var a0: Vector3 = rec[1]
		var drift := Vector2(a.x - a0.x, a.z - a0.z).length()
		stats.slide_max = maxf(float(stats.slide_max), drift)
		# sole contact, checked under the heel and under the ball: the lower of the two must touch
		# (float), and neither may be below the surface (sink)
		var gaps := []
		for bn: String in ["foot_" + s, "ball_" + s]:
			var q: Vector3 = xf * sk.get_bone_global_pose(bi[bn]).origin
			var sole_y: float = q.y - float(rest[bn].y) * h.body.scale.y
			if bn.begins_with("foot"):
				q += (xf.basis * sk.get_bone_global_pose(bi[bn]).basis * Vector3(0, 0, 0.05)) # heel is behind the ankle
			gaps.append(sole_y - float(_ground_at(q).y))
		var flo: float = maxf(0.0, minf(float(gaps[0]), float(gaps[1])))
		var sink: float = maxf(0.0, -minf(float(gaps[0]), float(gaps[1])))
		var err := maxf(flo, sink)
		if err > float(stats.ground_err_max):
			stats.worst = {"pos": a, "side": s, "gaps": gaps, "lock_y": (f.lock as Vector3).y, "pitch": f.pitch, "land": f.land, "bone": bone}
		stats.ground_err_max = maxf(float(stats.ground_err_max), err)
		stats.samples = int(stats.samples) + 1
