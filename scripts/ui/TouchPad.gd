class_name TouchPad
extends Control
## Multi-touch game controls.
## On foot: a floating movement stick (dead zone, response curve, jitter filtering, follow-the-thumb),
## push past 85% to run, and RUN LOCK: hold forward at full push for a moment and a lock chip
## appears above the stick; slide onto it or tap it and the character keeps running with the thumb
## lifted. Right side: camera drag (smoothed, with acceleration) and only the actions that apply now.
## Driving and bus modes keep their own layouts.

signal pressed(id)
signal run_lock_changed(on)

var mode := "foot"
var enabled := true
var stick := Vector2.ZERO        # filtered output: x right, y forward, length 0..1
var look_delta := Vector2.ZERO
var interact_text := ""
var _held := {}
var _touch := {}                 # touch index -> role ("stick", "look", "chip", or button id)
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _raw := Vector2.ZERO         # unfiltered stick (screen-relative, y up)

# ---- tuning (in fractions of the stick radius unless noted)
const DEAD := 0.12               # nothing happens inside this
const RUN_AT := 0.85             # beyond this the character runs
const LOCK_CONE := deg_to_rad(25.0)   # "forward" for RUN LOCK: within 25 degrees of straight up
const OFFER_KEEP := 2.0          # seconds the chip stays offered after the thumb leaves full forward
const CANCEL_BACK := 0.6         # pulling the stick back this far cancels the lock

# ---- RUN LOCK state
enum Lock { NONE, ARMING, OFFERED, LOCKED }
var lock_state := Lock.NONE
var _arm_t := 0.0                # how long full-forward has been held
var _offer_t := 0.0              # time left on the offer
var _chip_hover := false         # the stick thumb is over the chip
var _flash := 0.0                # feedback pulse when the lock engages or ends
var last_cancel := ""            # why the last lock ended (for tests and feedback)

# ---- camera drag smoothing
var _look_raw := Vector2.ZERO    # pixels this frame
var _look_vel := Vector2.ZERO    # filtered pixels per second
var _look_out := Vector2.ZERO

# ---- touch trace (test builds): recent touch points, drawn as fading dots
var trace: Array = []

# id: [anchor, x, y, radius, label, modes, icon]
const BTN := {
	"interact": ["br", -128, -300, 54, "", ["foot", "bus"], ""],
	"jump": ["br", -112, -118, 46, "Jump", ["foot"], "jump"],
	"crouch": ["br", -232, -96, 38, "Crouch", ["foot"], "crouch"],
	"punch": ["br", -228, -206, 34, "Hit", ["foot"], "hit"],
	"accel": ["br", -110, -120, 72, "GAS", ["drive"], ""],
	"brake": ["br", -275, -95, 56, "BRAKE", ["drive"], ""],
	"hbrake": ["br", -262, -228, 42, "H-BRK", ["drive"], ""],
	"horn": ["br", -80, -285, 44, "HORN", ["drive"], ""],
	"exit": ["br", -195, -355, 40, "EXIT", ["drive"], ""],
	"left": ["bl", 105, -115, 64, "<", ["drive"], ""],
	"right": ["bl", 262, -115, 64, ">", ["drive"], ""],
	"whistle": ["br", -110, -110, 60, "RIGHT!", ["bus"], ""],
	"bell": ["br", -255, -100, 46, "BELL", ["bus"], ""],
	"pause": ["tr", -44, 44, 26, "", ["foot", "drive", "bus", "ride"], "pause"],
	"radio": ["br", -330, -340, 38, "RADIO", ["drive"], ""],
	"phone": ["tr", -44, 190, 26, "", ["foot", "drive"], "phone"],
	"map": ["tr", -44, 252, 26, "", ["foot", "drive", "bus"], "map"],
	"cam": ["tr", -44, 314, 26, "", ["foot", "drive", "ride"], "cam"],
}

func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func held(id: String) -> bool:
	return _held.get(id, false)

func reset() -> void:
	_held.clear()
	_touch.clear()
	stick = Vector2.ZERO
	_raw = Vector2.ZERO
	if lock_state == Lock.LOCKED:
		cancel_run_lock("reset")
	lock_state = Lock.NONE
	queue_redraw()

func uses_stick() -> bool:
	return mode in ["foot", "bus"] or (mode == "drive" and int(Game.settings.steer) == 1)

func stick_held() -> bool:
	return _touch.values().has("stick")

## Running: a full push, or RUN LOCK.
func running() -> bool:
	return mode == "foot" and (lock_state == Lock.LOCKED or _raw.length() >= RUN_AT)

func run_locked() -> bool:
	return lock_state == Lock.LOCKED

func cancel_run_lock(reason: String) -> void:
	if lock_state != Lock.LOCKED and lock_state != Lock.OFFERED and lock_state != Lock.ARMING:
		return
	var was := lock_state == Lock.LOCKED
	lock_state = Lock.NONE
	_arm_t = 0.0
	_offer_t = 0.0
	if was:
		last_cancel = reason
		_flash = 1.0
		_buzz(25)
		run_lock_changed.emit(false)
	queue_redraw()

func _engage() -> void:
	lock_state = Lock.LOCKED
	last_cancel = ""
	_flash = 1.0
	_buzz(18)
	run_lock_changed.emit(true)
	queue_redraw()

func _buzz(ms: int) -> void:
	if bool(Game.settings.get("haptics", true)):
		Input.vibrate_handheld(ms)

# ------------------------------------------------------------------ geometry
func _visible_btn(id: String) -> bool:
	var b = BTN[id]
	if not mode in b[5]:
		return false
	if id == "interact" and interact_text == "":
		return false
	if id in ["left", "right"] and int(Game.settings.steer) == 1:
		return false
	if id == "radio" and (Game.world == null or not Game.world.radio_ok()):
		return false
	if id == "phone" and not Game.s.get("phone", false):
		return false
	return true

func btn_pos(id: String) -> Vector2:
	var b = BTN[id]
	var sc: float = float(Game.settings.btn_scale)
	var a: String = b[0]
	var off := Vector2(b[1], b[2]) * (sc if a != "tr" else 1.0)
	if Game.settings.lefty and a in ["br", "bl"]:
		a = "bl" if a == "br" else "br"
		off.x = -off.x
	var safe := _safe()
	match a:
		"br": return Vector2(size.x - safe.z, size.y - safe.w) + off
		"bl": return Vector2(safe.x + off.x, size.y - safe.w + off.y)
		"tr": return Vector2(size.x - safe.z + off.x, safe.y + off.y)
	return off

## Safe-area insets (left, top, right, bottom) in control pixels, for notches and rounded corners.
func _safe() -> Vector4:
	# only meaningful on a phone, where the window is the screen; on desktop the safe area describes the monitor
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var ws := DisplayServer.window_get_size()
	var sa := DisplayServer.get_display_safe_area()
	if ws.x <= 0 or sa.size.x <= 0 or sa.size.x > ws.x:
		return Vector4.ZERO
	var k := size.x / float(ws.x)
	var lim := size.x * 0.08
	return Vector4(clampf(sa.position.x * k, 0, lim), clampf(sa.position.y * k, 0, lim),
		clampf((ws.x - sa.end.x) * k, 0, lim), clampf((ws.y - sa.end.y) * k, 0, lim))

func btn_radius(id: String) -> float:
	return float(BTN[id][3]) * (float(Game.settings.btn_scale) if BTN[id][0] != "tr" else 1.0)

func stick_radius() -> float:
	return 88.0 * float(Game.settings.get("stick_scale", 1.0))

func _stick_home() -> Vector2:
	var safe := _safe()
	var x := 170.0 + safe.x if not Game.settings.lefty else size.x - 170.0 - safe.z
	return Vector2(x, size.y - 170.0 - safe.w)

func _stick_side(p: Vector2) -> bool:
	var left := p.x < size.x * 0.42
	return (left != bool(Game.settings.lefty)) and p.y > size.y * 0.35

func chip_pos() -> Vector2:
	var o := _stick_origin if stick_held() else _stick_home()
	return o + Vector2(0, -(stick_radius() + 58.0))

func chip_radius() -> float:
	return 34.0 * float(Game.settings.get("stick_scale", 1.0))

func _on_chip(p: Vector2) -> bool:
	return lock_state in [Lock.OFFERED, Lock.LOCKED] and p.distance_to(chip_pos()) <= chip_radius() * 1.35

# ------------------------------------------------------------------ input
func _input(ev: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if ev is InputEventScreenTouch:
		if bool(Game.settings.get("touch_trace", false)):
			trace.append([ev.position, 1.0, ev.pressed])
		if ev.pressed:
			# the RUN LOCK chip takes a tap first (engage when offered, cancel when locked)
			if mode == "foot" and _on_chip(ev.position):
				_touch[ev.index] = "chip"
				if lock_state == Lock.OFFERED:
					_engage()
				else:
					cancel_run_lock("chip")
				return
			for id in BTN:
				if _visible_btn(id) and ev.position.distance_to(btn_pos(id)) <= btn_radius(id) * 1.15:
					_touch[ev.index] = id
					_held[id] = true
					pressed.emit(id)
					_buzz(8)
					queue_redraw()
					return
			if uses_stick() and _stick_side(ev.position) and not stick_held():
				_touch[ev.index] = "stick"
				_stick_origin = ev.position
				_stick_pos = ev.position
				_raw = Vector2.ZERO
			else:
				_touch[ev.index] = "look"
		else:
			var role = _touch.get(ev.index, "")
			_touch.erase(ev.index)
			if role == "stick":
				# released over the chip while it is offered: that engages the lock (the slide gesture)
				if mode == "foot" and lock_state == Lock.OFFERED and _chip_hover:
					_engage()
				_raw = Vector2.ZERO
				_chip_hover = false
			elif role not in ["look", "chip", ""]:
				_held[role] = false
		queue_redraw()
	elif ev is InputEventScreenDrag:
		if bool(Game.settings.get("touch_trace", false)):
			trace.append([ev.position, 1.0, true])
		var role = _touch.get(ev.index, "")
		if role == "stick":
			_stick_pos = ev.position
			_chip_hover = mode == "foot" and lock_state == Lock.OFFERED and ev.position.distance_to(chip_pos()) <= chip_radius() * 1.35
			var rr := stick_radius()
			var d: Vector2 = ev.position - _stick_origin
			if _chip_hover:
				pass            # sliding up onto the chip: keep running straight, do not drag the stick base
			elif d.length() > rr * 1.25:
				# the thumb drifted past the ring: the base follows it, so the stick never "slips" off
				_stick_origin = ev.position - d.normalized() * rr * 1.25
				d = ev.position - _stick_origin
			if not _chip_hover:
				var r := d / rr
				if r.length() > 1.0:
					r = r.normalized()
				_raw = Vector2(r.x, -r.y)
			queue_redraw()
		elif role == "look":
			_look_raw += ev.relative

## Camera drag for this frame, smoothed and with gentle acceleration for fast swipes.
func take_look() -> Vector2:
	var d := _look_out
	_look_out = Vector2.ZERO
	return d

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_update_look(delta)
	_update_stick(delta)
	_update_lock(delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
	for t in trace:
		t[1] -= delta * 0.8
	while trace.size() > 0 and float(trace[0][1]) <= 0.0:
		trace.pop_front()
	if lock_state != Lock.NONE or _flash > 0.0 or trace.size() > 0 or stick_held():
		queue_redraw()

func _update_look(delta: float) -> void:
	var v := _look_raw / delta
	_look_raw = Vector2.ZERO
	var dragging := _touch.values().has("look")
	if dragging:
		_look_vel = _look_vel.lerp(v, 1.0 - exp(-delta / 0.035))
	else:
		_look_vel = _look_vel.lerp(Vector2.ZERO, 1.0 - exp(-delta / 0.08))   # a short glide, then stop
	# acceleration: slow drags are precise, fast swipes turn further
	var spd := _look_vel.length()
	var gain := 1.0 + clampf((spd - 600.0) / 1800.0, 0.0, 1.0) * 0.6
	var sy: float = float(Game.settings.get("sens_y", 1.0))
	var out := _look_vel * delta * gain
	_look_out += Vector2(out.x, out.y * sy)

func _update_stick(delta: float) -> void:
	var r := _raw
	var m := r.length()
	var target := Vector2.ZERO
	if lock_state == Lock.LOCKED and mode == "foot":
		# locked: always running; the thumb (if down) steers, otherwise straight ahead of the camera
		target = r.normalized() if m > DEAD else Vector2(0, 1)
		if stick_held() and m > DEAD and r.y < -CANCEL_BACK:
			cancel_run_lock("pulled back")
			target = Vector2.ZERO
	elif m > DEAD:
		# response curve: fine control near the centre, full speed at the rim
		var k := clampf((m - DEAD) / (1.0 - DEAD), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65
		target = r / m * k
	# jitter filter: small direction wobble is smoothed slowly, real turns follow quickly
	var cur := stick
	if target.length() < 0.01 or cur.length() < 0.01:
		stick = cur.lerp(target, 1.0 - exp(-delta / 0.04))
	else:
		var ang := absf(cur.angle_to(target))
		var tau := 0.16 if ang < deg_to_rad(8.0) else 0.05
		var a := cur.angle() + clampf(wrapf(target.angle() - cur.angle(), -PI, PI), -PI, PI) * (1.0 - exp(-delta / tau))
		var l := lerpf(cur.length(), target.length(), 1.0 - exp(-delta / 0.05))
		stick = Vector2(cos(a), sin(a)) * l

func _update_lock(delta: float) -> void:
	if mode != "foot":
		if lock_state == Lock.LOCKED:
			cancel_run_lock("mode")
		lock_state = Lock.NONE
		return
	var hold: float = float(Game.settings.get("runlock_hold", 0.6))
	var fwd_full := stick_held() and _raw.length() >= RUN_AT and absf(Vector2(0, 1).angle_to(_raw)) <= LOCK_CONE
	match lock_state:
		Lock.NONE, Lock.ARMING:
			if fwd_full:
				lock_state = Lock.ARMING
				_arm_t += delta
				if _arm_t >= hold:
					lock_state = Lock.OFFERED
					_offer_t = OFFER_KEEP
					_buzz(10)
			else:
				lock_state = Lock.NONE
				_arm_t = 0.0
		Lock.OFFERED:
			if not (fwd_full or _chip_hover):
				_offer_t -= delta
				if _offer_t <= 0.0:
					lock_state = Lock.NONE
					_arm_t = 0.0
		Lock.LOCKED:
			pass

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if not enabled:
		return
	var al: float = float(Game.settings.btn_alpha)
	var font := ThemeDB.fallback_font
	for id in BTN:
		if not _visible_btn(id):
			continue
		_draw_btn(id, al, font)
	if uses_stick():
		_draw_stick(al, font)
	for t in trace:
		draw_circle(t[0], 10.0, Color(0.2, 1.0, 0.4, float(t[1]) * 0.7) if t[2] else Color(1, 0.3, 0.2, float(t[1])))

func _draw_btn(id: String, al: float, font: Font) -> void:
	var p := btn_pos(id)
	var r := btn_radius(id)
	var on: bool = held(id)
	var icon: String = BTN[id][6]
	if id == "interact":
		# the one primary, contextual action: amber, with its verb
		draw_circle(p, r, Color(1.0, 0.76, 0.1, minf(1.0, al + 0.15)))
		draw_arc(p, r, 0, TAU, 48, Color(1, 1, 1, 0.9), 2.5 if on else 1.5, true)
		var fs := 20 if interact_text.length() <= 7 else 16
		var tw := font.get_string_size(interact_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, p + Vector2(-tw * 0.5, fs * 0.35), interact_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.06, 0.02))
		return
	var fill := Color(1, 1, 1, al * 0.32) if on else Color(0.04, 0.04, 0.05, al * 0.42)
	draw_circle(p, r * (0.94 if on else 1.0), fill)
	draw_arc(p, r, 0, TAU, 40, Color(1, 1, 1, al * (0.95 if on else 0.55)), 1.6, true)
	var ic := Color(1, 1, 1, minf(1.0, al + 0.15))
	if icon != "":
		_icon(icon, p, r * 0.46, ic)
		var lbl: String = BTN[id][4]
		if lbl != "" and BTN[id][0] != "tr":
			var fs2 := 12
			var tw2 := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2).x
			draw_string(font, p + Vector2(-tw2 * 0.5, r + 15), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1, 1, 1, al * 0.8))
	else:
		var txt: String = BTN[id][4]
		var fs := int(clampf(r * 0.42, 13, 26))
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, p + Vector2(-tw * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ic)

## Simple line icons (no text clutter on the buttons).
func _icon(kind: String, p: Vector2, s: float, c: Color) -> void:
	var w := maxf(2.0, s * 0.16)
	match kind:
		"jump":
			draw_polyline(PackedVector2Array([p + Vector2(-s * 0.7, s * 0.25), p + Vector2(0, -s * 0.45), p + Vector2(s * 0.7, s * 0.25)]), c, w, true)
			draw_line(p + Vector2(-s * 0.6, s * 0.75), p + Vector2(s * 0.6, s * 0.75), c, w, true)
		"crouch":
			draw_polyline(PackedVector2Array([p + Vector2(-s * 0.7, -s * 0.45), p + Vector2(0, s * 0.25), p + Vector2(s * 0.7, -s * 0.45)]), c, w, true)
			draw_line(p + Vector2(-s * 0.6, s * 0.75), p + Vector2(s * 0.6, s * 0.75), c, w, true)
		"hit":
			for k in 6:
				var a := TAU * k / 6.0
				draw_line(p + Vector2(cos(a), sin(a)) * s * 0.3, p + Vector2(cos(a), sin(a)) * s * 0.85, c, w, true)
		"pause":
			draw_line(p + Vector2(-s * 0.3, -s * 0.55), p + Vector2(-s * 0.3, s * 0.55), c, w * 1.3, true)
			draw_line(p + Vector2(s * 0.3, -s * 0.55), p + Vector2(s * 0.3, s * 0.55), c, w * 1.3, true)
		"phone":
			draw_rect(Rect2(p - Vector2(s * 0.42, s * 0.75), Vector2(s * 0.84, s * 1.5)), c, false, w)
			draw_line(p + Vector2(-s * 0.15, s * 0.5), p + Vector2(s * 0.15, s * 0.5), c, w, true)
		"map":
			var pts := PackedVector2Array([p + Vector2(-s * 0.8, -s * 0.55), p + Vector2(-s * 0.27, -s * 0.75), p + Vector2(s * 0.27, -s * 0.55), p + Vector2(s * 0.8, -s * 0.75),
				p + Vector2(s * 0.8, s * 0.55), p + Vector2(s * 0.27, s * 0.75), p + Vector2(-s * 0.27, s * 0.55), p + Vector2(-s * 0.8, s * 0.75), p + Vector2(-s * 0.8, -s * 0.55)])
			draw_polyline(pts, c, w * 0.8, true)
			draw_line(p + Vector2(-s * 0.27, -s * 0.75), p + Vector2(-s * 0.27, s * 0.55), c, w * 0.6, true)
			draw_line(p + Vector2(s * 0.27, -s * 0.55), p + Vector2(s * 0.27, s * 0.75), c, w * 0.6, true)
		"cam":
			draw_rect(Rect2(p - Vector2(s * 0.8, s * 0.45), Vector2(s * 1.6, s * 1.05)), c, false, w)
			draw_arc(p + Vector2(0, s * 0.08), s * 0.32, 0, TAU, 20, c, w, true)
		"run":
			# a small running figure: head, body, legs, arms
			draw_circle(p + Vector2(s * 0.25, -s * 0.7), s * 0.18, c)
			draw_line(p + Vector2(s * 0.15, -s * 0.45), p + Vector2(-s * 0.1, s * 0.15), c, w, true)
			draw_polyline(PackedVector2Array([p + Vector2(-s * 0.1, s * 0.15), p + Vector2(-s * 0.5, s * 0.45), p + Vector2(-s * 0.6, s * 0.8)]), c, w, true)
			draw_polyline(PackedVector2Array([p + Vector2(-s * 0.1, s * 0.15), p + Vector2(s * 0.3, s * 0.4), p + Vector2(s * 0.55, s * 0.8)]), c, w, true)
			draw_polyline(PackedVector2Array([p + Vector2(-s * 0.55, -s * 0.2), p + Vector2(-s * 0.05, -s * 0.3), p + Vector2(s * 0.5, -s * 0.05)]), c, w, true)
		"lock":
			draw_rect(Rect2(p + Vector2(-s * 0.45, -s * 0.05), Vector2(s * 0.9, s * 0.7)), c, true)
			draw_arc(p + Vector2(0, -s * 0.05), s * 0.3, PI, TAU, 14, c, w, true)
		"x":
			draw_line(p + Vector2(-s * 0.4, -s * 0.4), p + Vector2(s * 0.4, s * 0.4), c, w, true)
			draw_line(p + Vector2(-s * 0.4, s * 0.4), p + Vector2(s * 0.4, -s * 0.4), c, w, true)

func _draw_stick(al: float, font: Font) -> void:
	var o := _stick_origin if stick_held() else _stick_home()
	var rr := stick_radius()
	var is_run := running()
	var locked := lock_state == Lock.LOCKED
	var ring := Color(1, 0.76, 0.1, minf(1.0, al + 0.2)) if locked else (Color(1, 1, 1, al * 0.95) if is_run else Color(1, 1, 1, al * 0.5))
	draw_circle(o, rr, Color(0.04, 0.04, 0.05, al * 0.32))
	draw_arc(o, rr, 0, TAU, 56, ring, 3.0 if (is_run or locked) else 1.6, true)
	# run threshold marker: a faint inner ring at 85%
	draw_arc(o, rr * RUN_AT, 0, TAU, 56, Color(1, 1, 1, al * 0.18), 1.0, true)
	var knob := o + Vector2(_raw.x, -_raw.y) * rr if stick_held() else o
	if locked and not stick_held():
		knob = o + Vector2(0, -rr * 0.55)
	draw_circle(knob, rr * 0.4, Color(1, 1, 1, al * 0.8) if not locked else Color(1, 0.8, 0.25, 0.9))
	if is_run or locked:
		_icon("run", knob, rr * 0.22, Color(0.1, 0.1, 0.1, 0.85))
	# RUN LOCK chip above the stick (never under the thumb)
	if lock_state == Lock.ARMING:
		var hold: float = float(Game.settings.get("runlock_hold", 0.6))
		var f := clampf(_arm_t / hold, 0.0, 1.0)
		var cp := chip_pos()
		draw_arc(cp, chip_radius(), -PI * 0.5, -PI * 0.5 + TAU * f, 40, Color(1, 0.8, 0.25, 0.9 * f), 4.0, true)
	elif lock_state in [Lock.OFFERED, Lock.LOCKED]:
		var cp := chip_pos()
		var cr := chip_radius() * (1.12 if _chip_hover else 1.0)
		if lock_state == Lock.OFFERED:
			var fade := clampf(_offer_t / OFFER_KEEP, 0.3, 1.0) if not (stick_held() and _raw.length() >= RUN_AT) else 1.0
			draw_circle(cp, cr, Color(0.06, 0.05, 0.02, 0.75 * fade))
			draw_arc(cp, cr, 0, TAU, 44, Color(1, 0.8, 0.25, fade), 3.0, true)
			_icon("lock", cp + Vector2(0, -2), cr * 0.42, Color(1, 0.8, 0.25, fade))
			_label(font, "RUN LOCK", cp + Vector2(0, -cr - 10), 13, Color(1, 0.85, 0.4, fade))
		else:
			draw_circle(cp, cr, Color(1, 0.74, 0.12, 0.95))
			_icon("lock", cp + Vector2(-cr * 0.18, -2), cr * 0.36, Color(0.1, 0.07, 0.02))
			_icon("x", cp + Vector2(cr * 0.42, -cr * 0.42), cr * 0.28, Color(0.1, 0.07, 0.02))
			_label(font, "RUN LOCK ON", cp + Vector2(0, -cr - 10), 13, Color(1, 0.85, 0.4))
	if _flash > 0.0:
		draw_arc(chip_pos(), chip_radius() * (1.0 + (1.0 - _flash) * 0.9), 0, TAU, 44, Color(1, 0.85, 0.4, _flash), 3.0, true)

func _label(font: Font, t: String, p: Vector2, fs: int, c: Color) -> void:
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, p + Vector2(-tw * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
