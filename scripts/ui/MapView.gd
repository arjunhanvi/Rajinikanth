class_name MapView
extends Control
## The city map, drawn live from City data in world coordinates. Used small as
## the HUD minimap and full-screen as a period paper map: smooth zoom and pan,
## zoom-dependent detail, symbols, discovered / undiscovered places, routes.

signal place_tapped(id)
signal spot_tapped(p)

var mini := false
var centre := Vector2.ZERO          # world x/z at the middle of the control
var ppm := 0.5                      # pixels per world metre
var target_ppm := 0.5
var player_pos := Vector2.ZERO
var player_yaw := 0.0
var objective = null                # Vector2 or null
var waypoint = null                 # Vector2 or null
var route := PackedVector2Array()
var selected := ""
var _drag := {}
var _moved := 0.0
var _vel := Vector2.ZERO
var _zoom_at := Vector2.ZERO
var _rail: Array = []
var _stations: Array = []

const PAPER := Color(0.93, 0.89, 0.78)
const URBAN := Color(0.9, 0.8, 0.68)
const BLOCK := Color(0.86, 0.74, 0.62)
const WATERC := Color(0.6, 0.76, 0.86)
const GREEN := Color(0.7, 0.82, 0.6)
const INK := Color(0.2, 0.14, 0.1)
const SYM := {"home": ["H", Color(0.2, 0.55, 0.3)], "tea": ["T", Color(0.6, 0.35, 0.15)], "phone": ["#", Color(0.85, 0.6, 0.05)], "food": ["F", Color(0.85, 0.4, 0.1)], "bar": ["B", Color(0.55, 0.1, 0.4)],
	"car": ["A", Color(0.3, 0.3, 0.7)], "shirt": ["C", Color(0.2, 0.55, 0.75)], "police": ["P", Color(0.1, 0.2, 0.65)], "bus": ["B", Color(0.75, 0.15, 0.1)], "train": ["R", Color(0.15, 0.15, 0.15)],
	"landmark": ["*", Color(0.5, 0.36, 0.1)], "park": ["P", Color(0.15, 0.5, 0.2)], "market": ["M", Color(0.8, 0.3, 0.3)], "skull": ["!", Color(0.1, 0.1, 0.1)], "film": ["C", Color(0.7, 0.1, 0.1)],
	"flag": ["F", Color(0.9, 0.5, 0.1)], "news": ["N", Color(0.3, 0.3, 0.3)], "factory": ["I", Color(0.35, 0.35, 0.4)], "plane": ["A", Color(0.2, 0.4, 0.7)], "shop": ["S", Color(0.5, 0.5, 0.5)],
	"hospital": ["+", Color(0.8, 0.1, 0.1)], "school": ["E", Color(0.3, 0.3, 0.6)]}
const LEGEND := [["bus", "Bus station / stop"], ["train", "Railway station"], ["market", "Market"], ["food", "Eating house"], ["police", "Police"], ["film", "Cinema / theatre"], ["hospital", "Hospital"],
	["landmark", "Place of interest"], ["factory", "Industry"], ["school", "College"], ["home", "Residence"], ["skull", "Keep away"]]

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE if mini else Control.MOUSE_FILTER_STOP
	target_ppm = ppm
	for r in City.RAIL:
		var pts := PackedVector2Array()
		for q in r[1]:
			pts.append(City.to_world(q[0], q[1]))
		_rail.append(pts)
	for st in City.STATIONS:
		_stations.append([st[0], City.to_world(st[1], st[2])])

func w2s(p: Vector2) -> Vector2:
	return size * 0.5 + (p - centre) * ppm

func s2w(p: Vector2) -> Vector2:
	return centre + (p - size * 0.5) / ppm

func _process(delta: float) -> void:
	if mini:
		return
	var changed := false
	if absf(target_ppm - ppm) > 0.0005:
		# zoom about the point under the finger so the map does not swim
		var before := s2w(_zoom_at)
		ppm = lerpf(ppm, target_ppm, 1.0 - exp(-10.0 * delta))
		centre += before - s2w(_zoom_at)
		changed = true
	if _drag.is_empty() and _vel.length() > 4.0:
		centre -= _vel * delta / ppm
		_vel *= exp(-4.0 * delta)
		changed = true
	if changed:
		centre = centre.clamp(Vector2(-3600, -3900), Vector2(5300, 4000))
		queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if mini:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_drag[ev.index] = ev.position
			_moved = 0.0
			_vel = Vector2.ZERO
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
				zoom(d1 / d0, (ev.position + other) * 0.5, true)
		else:
			centre -= ev.relative / ppm
			_vel = ev.velocity
		_drag[ev.index] = ev.position
		_moved += ev.relative.length()
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1.25, ev.position)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0 / 1.25, ev.position)

func zoom(f: float, at := Vector2.INF, instant := false) -> void:
	_zoom_at = at if at != Vector2.INF else size * 0.5
	target_ppm = clampf(target_ppm * f, 0.07, 3.0)
	if instant:
		var before := s2w(_zoom_at)
		ppm = target_ppm
		centre += before - s2w(_zoom_at)
	queue_redraw()

func zoom_to(v: float) -> void:
	_zoom_at = size * 0.5
	target_ppm = v

func _tap(p: Vector2) -> void:
	var best := ""
	var bd := 28.0
	for id in City.PLACES:
		var pl = City.PLACES[id]
		var d := w2s(Vector2(pl.pos.x, pl.pos.z)).distance_to(p)
		if d < bd and (Game.s.discovered.has(id) or ppm > 0.3):
			bd = d
			best = id
	selected = best
	if best == "":
		spot_tapped.emit(s2w(p))
	else:
		place_tapped.emit(best)
	queue_redraw()

func _sym(p: Vector2, icon: String, r: float, known := true) -> void:
	var sy: Array = SYM.get(icon, SYM["shop"])
	var font := ThemeDB.fallback_font
	if not known:
		draw_circle(p, r, Color(0.75, 0.72, 0.65))
		draw_arc(p, r, 0, TAU, 20, Color(0.45, 0.42, 0.38), 1.5, true)
		draw_string(font, p + Vector2(-r * 0.32, r * 0.42), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.3), Color(0.4, 0.37, 0.33))
		return
	draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), Color(0.98, 0.96, 0.9))
	draw_rect(Rect2(p - Vector2(r, r) + Vector2(1.5, 1.5), Vector2(r, r) * 2.0 - Vector2(3, 3)), sy[1])
	var fs := int(r * 1.35)
	var tw := font.get_string_size(sy[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, p + Vector2(-tw * 0.5, fs * 0.36), sy[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _label(p: Vector2, text: String, fs: int, col: Color, centred := false) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var o := p - Vector2(w * 0.5, 0) if centred else p
	draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(PAPER, 0.85) if not mini else Color(0, 0, 0, 0.7))
	draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var scr := Rect2(Vector2.ZERO, size)
	draw_rect(scr, PAPER if not mini else Color(0.13, 0.14, 0.13, 0.88))
	var view := Rect2(s2w(Vector2.ZERO), size / ppm)
	var street_level := ppm > 0.26
	# --- built-up area: washes at city level, individual blocks at street level ---
	if not mini:
		if not street_level:
			for id in City.nodes:
				var n = City.nodes[id]
				if view.grow(500).has_point(n.p):
					draw_circle(w2s(n.p), float(n.r) * 1.2 * ppm, URBAN)
		else:
			var bx := floorf(view.position.x / City.GRID) * City.GRID
			while bx < view.end.x:
				var bz := floorf(view.position.y / City.GRID) * City.GRID
				while bz < view.end.y:
					var mid := Vector2(bx + 25.0, bz + 25.0)
					if City.district(mid).kind != "rural" and City.in_zone(mid) == null:
						draw_rect(Rect2(w2s(Vector2(bx + 4.5, bz + 4.5)), Vector2(41.0, 41.0) * ppm), BLOCK)
					bz += City.GRID
				bx += City.GRID
	# --- greens, tanks, handcrafted zones ---
	for g in City.GREENS:
		var gp := City.to_world(g[1], g[2])
		if view.grow(300).has_point(gp):
			draw_circle(w2s(gp), float(g[3]) * ppm, GREEN if not mini else GREEN.darkened(0.55))
			if not mini and ppm > 0.14:
				_label(w2s(gp), g[0], 11, Color(0.2, 0.4, 0.2), true)
	for wt in City.WATER:
		var wp := City.to_world(wt[1], wt[2])
		if view.grow(400).has_point(wp):
			draw_circle(w2s(wp), float(wt[3]) * ppm, WATERC if not mini else WATERC.darkened(0.5))
			if not mini:
				draw_arc(w2s(wp), float(wt[3]) * ppm, 0, TAU, 32, Color(0.3, 0.45, 0.6), 1.2, true)
				if ppm > 0.14:
					_label(w2s(wp), wt[0], 11, Color(0.15, 0.3, 0.5), true)
	for z in City.zones:
		if z.kind == "site" or not view.intersects(z.rect):
			continue
		var c := Color(0.8, 0.72, 0.6)
		if z.kind == "lake": c = WATERC
		elif z.kind in ["park", "park2"]: c = GREEN
		if mini: c = c.darkened(0.5)
		draw_rect(Rect2(w2s(z.rect.position), z.rect.size * ppm), c)
		if not mini:
			draw_rect(Rect2(w2s(z.rect.position), z.rect.size * ppm), Color(INK, 0.35), false, 1.0)
	# --- numbered side streets ---
	if ppm > 0.2:
		var sc := Color(1, 1, 1, 0.95) if not mini else Color(0.4, 0.42, 0.4, 0.8)
		var lw := maxf(1.0, City.STREET_W * ppm * 0.7)
		var x := floorf(view.position.x / City.GRID) * City.GRID
		while x < view.end.x:
			draw_line(w2s(Vector2(x, view.position.y)), w2s(Vector2(x, view.end.y)), sc, lw)
			x += City.GRID
		var z2 := floorf(view.position.y / City.GRID) * City.GRID
		while z2 < view.end.y:
			draw_line(w2s(Vector2(view.position.x, z2)), w2s(Vector2(view.end.x, z2)), sc, lw)
			z2 += City.GRID
		if not mini and ppm > 0.75:
			var cc := view.get_center()
			z2 = floorf(view.position.y / City.GRID) * City.GRID
			while z2 < view.end.y:
				var nm := City.grid_street_name(0, z2, Vector2(cc.x, z2))
				if nm != "" and City.district(Vector2(cc.x, z2)).kind != "rural":
					draw_string(font, w2s(Vector2(cc.x - 60.0, z2)) + Vector2(0, 4), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.33, 0.28))
				z2 += City.GRID
			x = floorf(view.position.x / City.GRID) * City.GRID
			while x < view.end.x:
				var nm2 := City.grid_street_name(1, x, Vector2(x, cc.y))
				if nm2 != "" and City.district(Vector2(x, cc.y)).kind != "rural":
					draw_set_transform(w2s(Vector2(x, cc.y + 40.0)) + Vector2(4, 0), -PI * 0.5, Vector2.ONE)
					draw_string(font, Vector2.ZERO, nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.33, 0.28))
					draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				x += City.GRID
	# --- railways: black and white ladder ---
	for pts in _rail:
		for i in pts.size() - 1:
			var a := w2s(pts[i])
			var b := w2s(pts[i + 1])
			if not scr.grow(60).intersects(Rect2(a, Vector2.ZERO).expand(b)):
				continue
			draw_line(a, b, Color(0.1, 0.1, 0.1) if not mini else Color(0.3, 0.3, 0.3), 3.5 if not mini else 2.0)
			if not mini:
				draw_dashed_line(a, b, Color(0.95, 0.95, 0.9), 1.6, 7.0)
	# --- arterial roads, casing then fill ---
	for pass_i in 2:
		for e in City.edges:
			var a2 := w2s(e.pa)
			var b2 := w2s(e.pb)
			if not scr.grow(40).intersects(Rect2(a2, Vector2.ZERO).expand(b2)):
				continue
			var wd := maxf(2.5 if e.w < 15 else 3.8, float(e.w) * ppm)
			if pass_i == 0:
				draw_line(a2, b2, Color(0.42, 0.3, 0.2) if not mini else Color(0.05, 0.05, 0.05), wd + 2.2)
			else:
				draw_line(a2, b2, (Color(0.99, 0.86, 0.45) if e.w >= 15 else Color(1, 0.99, 0.95)) if not mini else Color(0.62, 0.62, 0.58), wd)
	if not mini:
		# the conductor's own route
		for br in City.BUS_ROUTES:
			for i in br[1].size() - 1:
				draw_dashed_line(w2s(City.np(br[1][i])), w2s(City.np(br[1][i + 1])), Color(0.8, 0.12, 0.1, 0.8), 2.0, 9.0)
		if ppm > 0.16:
			for e in City.edges:
				var a3 := w2s(e.pa)
				var b3 := w2s(e.pb)
				var seg: float = e.len * ppm
				if seg < 110.0 or not scr.grow(40).intersects(Rect2(a3, Vector2.ZERO).expand(b3)):
					continue
				var ang := (b3 - a3).angle()
				if absf(ang) > PI * 0.5:
					ang += PI
				var reps := 1 + int(seg / 520.0)
				for k in reps:
					var mp := a3.lerp(b3, (float(k) + 0.5) / reps)
					draw_set_transform(mp, ang, Vector2.ONE)
					var tw := font.get_string_size(e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
					draw_string_outline(font, Vector2(-tw * 0.5, 4), e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(1, 0.98, 0.9, 0.9))
					draw_string(font, Vector2(-tw * 0.5, 4), e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.2, 0.12))
					draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# --- the navigation route ---
	if route.size() > 1:
		for i in route.size() - 1:
			draw_line(w2s(route[i]), w2s(route[i + 1]), Color(0.1, 0.35, 0.85, 0.85), 5.0 if not mini else 3.0)
	# --- stations, bus stops, sights ---
	if not mini:
		for st in _stations:
			var sp: Vector2 = w2s(st[1])
			if scr.has_point(sp):
				_sym(sp, "train", 7.0)
				if ppm > 0.12:
					_label(sp + Vector2(10, 4), st[0] + " Stn.", 11, INK)
		if ppm > 0.22:
			for id in City.stops:
				var bp := w2s(City.stops[id].pos)
				if scr.has_point(bp):
					_sym(bp, "bus", 5.5)
		if ppm > 0.13:
			for sg in City.SIGHTS:
				var gp2 := w2s(City.to_world(sg[1], sg[2]))
				if scr.has_point(gp2):
					_sym(gp2, sg[3], 6.0)
					if ppm > 0.2:
						_label(gp2 + Vector2(9, 4), sg[0], 11, INK)
		# locality names: spaced capitals, larger when zoomed out
		var placed: Array = []
		for id in City.nodes:
			var n2 = City.nodes[id]
			var p := w2s(n2.p)
			var crowded := false
			for q in placed:
				if absf(q.x - p.x) < 96.0 and absf(q.y - p.y) < 15.0:
					crowded = true
			if scr.has_point(p) and not crowded:
				placed.append(p)
				var nm3: String = str(n2.name).to_upper()
				if ppm < 0.3:
					nm3 = " ".join(nm3.split(""))
				_label(p + Vector2(0, -10), nm3, 12 if ppm < 0.14 else 14, Color(0.35, 0.12, 0.1), true)
	# --- game places ---
	for id in City.PLACES:
		var pl = City.PLACES[id]
		var pp := w2s(Vector2(pl.pos.x, pl.pos.z))
		if not scr.has_point(pp):
			continue
		var known: bool = Game.s.discovered.has(id)
		if not known and (mini or ppm < 0.3):
			continue
		if mini:
			draw_circle(pp, 5.0, Color.WHITE)
			draw_circle(pp, 3.8, SYM.get(pl.icon, SYM["shop"])[1])
			continue
		_sym(pp, pl.icon, 9.0, known)
		if id == selected:
			draw_arc(pp, 16.0, 0, TAU, 24, Color(0.85, 0.1, 0.1), 2.5, true)
		if known and (ppm > 0.45 or id == selected):
			_label(pp + Vector2(13, 4), pl.name, 12, INK)
	for mk in [[waypoint, Color(0.1, 0.4, 0.9)], [objective, Color(1.0, 0.8, 0.0)]]:
		if mk[0] != null:
			var mp2 := w2s(mk[0])
			if mini:
				var d := mp2 - size * 0.5
				var lim := size.x * 0.5 - 8.0
				if d.length() > lim:
					mp2 = size * 0.5 + d.normalized() * lim
				draw_circle(mp2, 7.0, Color.BLACK)
				draw_circle(mp2, 5.0, mk[1])
			else:
				draw_colored_polygon(PackedVector2Array([mp2, mp2 + Vector2(-9, -22), mp2 + Vector2(9, -22)]), Color.BLACK)
				draw_circle(mp2 + Vector2(0, -22), 10.0, Color.BLACK)
				draw_circle(mp2 + Vector2(0, -22), 7.5, mk[1])
	# --- you are here ---
	var c2 := w2s(player_pos)
	var fwd := Vector2(-sin(player_yaw), -cos(player_yaw))
	var rt := Vector2(-fwd.y, fwd.x)
	var s := 9.0 if mini else 13.0
	if not mini:
		draw_circle(c2, s * 1.6, Color(0.9, 0.15, 0.1, 0.18))
	draw_colored_polygon(PackedVector2Array([c2 + fwd * s * 1.4, c2 - fwd * s * 0.8 + rt * s * 0.85, c2 - fwd * s * 0.3, c2 - fwd * s * 0.8 - rt * s * 0.85]), Color(0.85, 0.12, 0.08))
	if mini:
		draw_rect(scr, Color(1.0, 0.8, 0.0, 0.9), false, 2.0)
		draw_string(font, Vector2(size.x * 0.5 - 4, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
		return
	# --- paper furniture: neat line, folds, scale bar, north point ---
	for i in range(1, 4):
		draw_line(Vector2(size.x * i / 4.0, 0), Vector2(size.x * i / 4.0, size.y), Color(0.5, 0.4, 0.3, 0.09), 2.0)
	draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Color(0.5, 0.4, 0.3, 0.09), 2.0)
	draw_rect(scr.grow(-4), INK, false, 2.0)
	draw_rect(scr.grow(-9), INK, false, 0.8)
	var km := 1000.0 / 4.0                 # 1 real km is 250 world metres (the city is drawn at 1:4)
	var bar := km * ppm
	var unit := "1 km"
	if bar > 260.0:
		bar *= 0.25
		unit = "250 m"
	elif bar < 50.0:
		bar *= 5.0
		unit = "5 km"
	var bo := Vector2(26, size.y - 30)
	draw_rect(Rect2(bo - Vector2(8, 22), Vector2(bar + 70, 38)), Color(PAPER, 0.9))
	draw_rect(Rect2(bo, Vector2(bar * 0.5, 6)), INK)
	draw_rect(Rect2(bo, Vector2(bar, 6)), INK, false, 1.2)
	draw_string(font, bo + Vector2(0, -5), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	draw_string(font, bo + Vector2(bar - 8, -5), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	var no := Vector2(size.x - 44, 52)
	draw_circle(no, 24.0, Color(PAPER, 0.9))
	draw_arc(no, 24.0, 0, TAU, 32, INK, 1.2, true)
	draw_colored_polygon(PackedVector2Array([no + Vector2(0, -20), no + Vector2(6, 4), no + Vector2(-6, 4)]), INK)
	draw_colored_polygon(PackedVector2Array([no + Vector2(0, 20), no + Vector2(6, 4), no + Vector2(-6, 4)]), Color(0.7, 0.66, 0.58))
	draw_string(font, no + Vector2(-5, -26), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
