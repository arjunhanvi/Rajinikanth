class_name TouchPad
extends Control
## Multi-touch game controls: floating left stick, right-side camera drag and
## round action buttons. Layout adapts to mode (foot / drive / bus) and settings.

signal pressed(id)

var mode := "foot"
var enabled := true
var stick := Vector2.ZERO
var look_delta := Vector2.ZERO
var interact_text := ""
var _held := {}
var _touch := {}          # touch index -> role ("stick", "look", or button id)
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO

# id: [anchor, x, y, radius, text, modes]
const BTN := {
	"interact": ["br", -150, -330, 56, "", ["foot", "bus"]],
	"sprint": ["br", -110, -110, 62, "RUN", ["foot"]],
	"jump": ["br", -265, -90, 48, "JUMP", ["foot"]],
	"crouch": ["br", -262, -212, 42, "DUCK", ["foot"]],
	"punch": ["br", -70, -245, 44, "HIT", ["foot"]],
	"accel": ["br", -110, -120, 72, "GAS", ["drive"]],
	"brake": ["br", -275, -95, 56, "BRAKE", ["drive"]],
	"hbrake": ["br", -262, -228, 42, "H-BRK", ["drive"]],
	"horn": ["br", -80, -285, 44, "HORN", ["drive"]],
	"exit": ["br", -195, -355, 40, "EXIT", ["drive"]],
	"left": ["bl", 105, -115, 64, "<", ["drive"]],
	"right": ["bl", 262, -115, 64, ">", ["drive"]],
	"whistle": ["br", -110, -110, 60, "RIGHT!", ["bus"]],
	"bell": ["br", -255, -100, 46, "BELL", ["bus"]],
	"pause": ["tr", -44, 44, 28, "II", ["foot", "drive", "bus", "ride"]],
	"radio": ["br", -330, -340, 38, "RADIO", ["drive"]],
	"phone": ["tr", -44, 190, 30, "TEL", ["foot", "drive"]],
	"map": ["tr", -44, 262, 30, "MAP", ["foot", "drive", "bus"]],
	"cam": ["tr", -44, 334, 30, "CAM", ["foot", "drive", "ride"]],
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
	queue_redraw()

func uses_stick() -> bool:
	return mode in ["foot", "bus"] or (mode == "drive" and int(Game.settings.steer) == 1)

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
	match a:
		"br": return size + off
		"bl": return Vector2(off.x, size.y + off.y)
		"tr": return Vector2(size.x + off.x, off.y)
	return off

func btn_radius(id: String) -> float:
	return float(BTN[id][3]) * (float(Game.settings.btn_scale) if BTN[id][0] != "tr" else 1.0)

func _stick_side(p: Vector2) -> bool:
	var left := p.x < size.x * 0.45
	return (left != bool(Game.settings.lefty)) and p.y > size.y * 0.3

func _input(ev: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			for id in BTN:
				if _visible_btn(id) and ev.position.distance_to(btn_pos(id)) <= btn_radius(id) * 1.15:
					_touch[ev.index] = id
					_held[id] = true
					pressed.emit(id)
					queue_redraw()
					return
			if uses_stick() and _stick_side(ev.position) and not _touch.values().has("stick"):
				_touch[ev.index] = "stick"
				_stick_origin = ev.position
				_stick_pos = ev.position
			else:
				_touch[ev.index] = "look"
		else:
			var role = _touch.get(ev.index, "")
			_touch.erase(ev.index)
			if role == "stick":
				stick = Vector2.ZERO
			elif role != "look" and role != "":
				_held[role] = false
		queue_redraw()
	elif ev is InputEventScreenDrag:
		var role = _touch.get(ev.index, "")
		if role == "stick":
			_stick_pos = ev.position
			var d: Vector2 = (ev.position - _stick_origin) / (90.0 * float(Game.settings.btn_scale))
			if d.length() > 1.0:
				d = d.normalized()
			stick = Vector2(d.x, -d.y)
			queue_redraw()
		elif role == "look":
			look_delta += ev.relative

func take_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d

func _draw() -> void:
	if not enabled:
		return
	var al: float = float(Game.settings.btn_alpha)
	var font := ThemeDB.fallback_font
	for id in BTN:
		if not _visible_btn(id):
			continue
		var p := btn_pos(id)
		var r := btn_radius(id)
		var on: bool = held(id)
		var base := Color(1.0, 0.8, 0.0, al) if (on or id == "interact") else Color(0.05, 0.05, 0.06, al * 0.6)
		draw_circle(p, r, base)
		draw_arc(p, r, 0, TAU, 40, Color(1, 1, 1, al * 0.8), 2.0, true)
		var txt: String = BTN[id][4] if id != "interact" else interact_text
		var fs := int(clampf(r * 0.42, 13, 26))
		if txt.length() > 6:
			fs = int(fs * 0.8)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, p + Vector2(-tw * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.05, 0.05, 1) if (on or id == "interact") else Color(1, 1, 1, al + 0.2))
	if uses_stick():
		var held_stick: bool = _touch.values().has("stick")
		var o := _stick_origin if held_stick else Vector2(150.0 if not Game.settings.lefty else size.x - 150.0, size.y - 150.0)
		var rr := 90.0 * float(Game.settings.btn_scale)
		draw_circle(o, rr, Color(0.05, 0.05, 0.06, al * 0.35))
		draw_arc(o, rr, 0, TAU, 48, Color(1, 1, 1, al * 0.6), 2.0, true)
		draw_circle(o + Vector2(stick.x, -stick.y) * rr, rr * 0.42, Color(1, 1, 1, al * 0.75))
