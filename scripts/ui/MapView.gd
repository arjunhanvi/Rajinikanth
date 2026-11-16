class_name MapView
extends Control
## Draws Bangalore from City data. Used as the HUD minimap (mini = true) and as
## the full, pannable/zoomable paper city map.

signal place_tapped(id)

var mini := false
var centre := Vector2.ZERO          # world x/z at the middle of the control
var ppm := 0.5                      # pixels per metre
var player_pos := Vector2.ZERO
var player_yaw := 0.0
var objective = null                # Vector2 or null
var waypoint = null                 # Vector2 or null
var route := PackedVector2Array()
var selected := ""
var _drag := {}
var _moved := 0.0

const ICON_COL := {"home": Color(0.2, 0.6, 0.3), "tea": Color(0.6, 0.35, 0.15), "phone": Color(0.9, 0.7, 0.1), "food": Color(0.85, 0.4, 0.1), "bar": Color(0.6, 0.1, 0.4),
	"car": Color(0.3, 0.3, 0.7), "shirt": Color(0.2, 0.6, 0.8), "police": Color(0.1, 0.2, 0.7), "bus": Color(0.75, 0.15, 0.1), "train": Color(0.4, 0.3, 0.2), "landmark": Color(0.5, 0.4, 0.1),
	"park": Color(0.15, 0.5, 0.2), "market": Color(0.8, 0.3, 0.3), "skull": Color(0.1, 0.1, 0.1), "film": Color(0.7, 0.1, 0.1), "flag": Color(0.9, 0.5, 0.1), "news": Color(0.3, 0.3, 0.3),
	"factory": Color(0.35, 0.35, 0.4), "plane": Color(0.2, 0.4, 0.7), "shop": Color(0.5, 0.5, 0.5)}

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE if mini else Control.MOUSE_FILTER_STOP

func w2s(p: Vector2) -> Vector2:
	return size * 0.5 + (p - centre) * ppm

func s2w(p: Vector2) -> Vector2:
	return centre + (p - size * 0.5) / ppm

func _gui_input(ev: InputEvent) -> void:
	if mini:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_drag[ev.index] = ev.position
			_moved = 0.0
		else:
			_drag.erase(ev.index)
			if _moved < 12.0:
				_tap(ev.position)
	elif ev is InputEventScreenDrag:
		if _drag.size() >= 2 and _drag.has(ev.index):
			var other := Vector2.ZERO
			for k in _drag:
				if k != ev.index:
					other = _drag[k]
			var d0: float = _drag[ev.index].distance_to(other)
			var d1: float = ev.position.distance_to(other)
			if d0 > 10.0:
				zoom(d1 / d0)
		else:
			centre -= ev.relative / ppm
		_drag[ev.index] = ev.position
		_moved += ev.relative.length()
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1.15)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0 / 1.15)

func zoom(f: float) -> void:
	ppm = clampf(ppm * f, 0.06, 2.5)
	queue_redraw()

func _tap(p: Vector2) -> void:
	var best := ""
	var bd := 26.0
	for id in City.PLACES:
		if not Game.s.discovered.has(id):
			continue
		var pl = City.PLACES[id]
		var d := w2s(Vector2(pl.pos.x, pl.pos.z)).distance_to(p)
		if d < bd:
			bd = d
			best = id
	selected = best
	if best == "":
		waypoint = s2w(p)
	place_tapped.emit(best)
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var paper := Color(0.86, 0.82, 0.7) if not mini else Color(0.13, 0.14, 0.13, 0.85)
	draw_rect(Rect2(Vector2.ZERO, size), paper)
	var view := Rect2(s2w(Vector2.ZERO), size / ppm)
	# zones (parks, lakes, stations)
	for z in City.zones:
		if z.kind == "site" or not view.intersects(z.rect):
			continue
		var c := Color(0.55, 0.72, 0.45)
		if z.kind == "lake": c = Color(0.45, 0.65, 0.8)
		elif not z.kind in ["park", "park2"]: c = Color(0.72, 0.62, 0.5)
		if mini: c = c.darkened(0.45)
		draw_rect(Rect2(w2s(z.rect.position), z.rect.size * ppm), c)
	# side streets (only when zoomed in enough to matter)
	if ppm > 0.28:
		var sc := Color(1, 1, 1, 0.55) if not mini else Color(0.4, 0.42, 0.4, 0.8)
		var x0 := floorf(view.position.x / City.GRID) * City.GRID
		var x := x0
		while x < view.end.x:
			draw_line(w2s(Vector2(x, view.position.y)), w2s(Vector2(x, view.end.y)), sc, maxf(1.0, City.STREET_W * ppm * 0.6))
			x += City.GRID
		var z2 := floorf(view.position.y / City.GRID) * City.GRID
		while z2 < view.end.y:
			draw_line(w2s(Vector2(view.position.x, z2)), w2s(Vector2(view.end.x, z2)), sc, maxf(1.0, City.STREET_W * ppm * 0.6))
			z2 += City.GRID
	# arterial roads
	for e in City.edges:
		var a := w2s(e.pa)
		var b := w2s(e.pb)
		if not Rect2(Vector2.ZERO, size).grow(40).intersects(Rect2(a, Vector2.ZERO).expand(b)):
			continue
		var wd := maxf(2.0 if e.w < 15 else 3.0, float(e.w) * ppm)
		draw_line(a, b, Color(0.3, 0.25, 0.2) if not mini else Color(0.05, 0.05, 0.05), wd + 2.0)
		draw_line(a, b, Color(0.98, 0.9, 0.55) if e.w >= 15 else Color(1, 1, 1) if not mini else Color(0.62, 0.62, 0.58), wd)
		if not mini and ppm > 0.22 and e.len * ppm > 150.0:
			var midp := (a + b) * 0.5
			var ang := (b - a).angle()
			if absf(ang) > PI * 0.5:
				ang += PI
			draw_set_transform(midp, ang, Vector2.ONE)
			draw_string(font, Vector2(-60, -wd * 0.5 - 3), e.name, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(0.25, 0.2, 0.15))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if route.size() > 1:
		for i in route.size() - 1:
			draw_line(w2s(route[i]), w2s(route[i + 1]), Color(0.1, 0.4, 0.9, 0.8), 4.0)
	# locality names
	if not mini:
		for id in City.nodes:
			var n = City.nodes[id]
			var p := w2s(n.p)
			if Rect2(Vector2.ZERO, size).has_point(p):
				draw_circle(p, 3.0, Color(0.3, 0.2, 0.15))
				draw_string(font, p + Vector2(6, -6), str(n.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13 if ppm < 0.2 else 15, Color(0.2, 0.12, 0.1))
	# places
	for id in City.PLACES:
		if not Game.s.discovered.has(id):
			continue
		var pl = City.PLACES[id]
		var pp := w2s(Vector2(pl.pos.x, pl.pos.z))
		if not Rect2(Vector2.ZERO, size).has_point(pp):
			continue
		var col: Color = ICON_COL.get(pl.icon, Color(0.5, 0.5, 0.5))
		var r := 5.0 if mini else 8.0
		draw_circle(pp, r + 1.5, Color.WHITE)
		draw_circle(pp, r, col)
		if id == selected:
			draw_arc(pp, r + 6.0, 0, TAU, 24, Color(0.9, 0.1, 0.1), 2.5)
		if not mini and (ppm > 0.5 or id == selected):
			draw_string(font, pp + Vector2(11, 4), pl.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.1, 0.1))
	for mk in [[waypoint, Color(0.1, 0.4, 0.9)], [objective, Color(1.0, 0.8, 0.0)]]:
		if mk[0] != null:
			var mp := w2s(mk[0])
			if mini:   # clamp to the rim so the player always sees the direction
				var d := mp - size * 0.5
				var lim := size.x * 0.5 - 8.0
				if d.length() > lim:
					mp = size * 0.5 + d.normalized() * lim
			draw_circle(mp, 9.0 if not mini else 7.0, Color.BLACK)
			draw_circle(mp, 7.0 if not mini else 5.0, mk[1])
	# player arrow
	var c2 := w2s(player_pos)
	var fwd := Vector2(-sin(player_yaw), -cos(player_yaw))
	var rt := Vector2(-fwd.y, fwd.x)
	var s := 9.0 if mini else 12.0
	draw_colored_polygon(PackedVector2Array([c2 + fwd * s * 1.3, c2 - fwd * s * 0.8 + rt * s * 0.8, c2 - fwd * s * 0.3, c2 - fwd * s * 0.8 - rt * s * 0.8]), Color(0.9, 0.15, 0.1))
	if mini:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.8, 0.0, 0.9), false, 2.0)
		draw_string(font, Vector2(size.x * 0.5 - 4, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
