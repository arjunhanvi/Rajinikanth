class_name HUD
extends CanvasLayer
## In-game interface: touch controls, minimap, status, objectives, toasts,
## dialogue with choices, list menus, cinematic bars/fades, map and pause.

signal dlg_advance
signal chosen(i)
signal menu_picked(i)

var world
var pad: TouchPad
var mini: MapView
var modal := 0
var voice := 1.0               # pitch of the speech blip for whoever is talking
var cinematic := false
var _money: Label
var _clock: Label
var _area: Label
var _obj: Label
var _heat: Label
var _toasts: VBoxContainer
var _sub: Label
var _dlg: Control
var _dlg_name: Label
var _dlg_text: Label
var _dlg_hint: Label
var _choices: VBoxContainer
var _bars: Array = []
var _fade: ColorRect
var _grain: ColorRect
var _card: Control
var _typing := 0.0
var _acc := 0.0
var _map_panel: Control = null
var _full_map: MapView = null
var _phone: Control = null
var _pause: Control = null
var _menu: Control = null
var _area_name := ""

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	UI.full(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_grain = UI.grain(0.018 if Game.settings.grain else 0.0, 0.3)
	root.add_child(_grain)
	pad = TouchPad.new()
	root.add_child(pad)
	pad.pressed.connect(_on_pad)
	mini = MapView.new()
	mini.mini = true
	mini.ppm = 0.42
	mini.position = Vector2(16, 16)
	mini.size = Vector2(168, 168)
	root.add_child(mini)
	_area = UI.label("", 17, Color(1, 1, 1, 0.9))
	_area.position = Vector2(16, 190)
	_area.add_theme_color_override("font_outline_color", Color.BLACK)
	_area.add_theme_constant_override("outline_size", 5)
	root.add_child(_area)
	var tr := VBoxContainer.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr.offset_left = -330
	tr.offset_right = -84
	tr.offset_top = 14
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	_money = _out(UI.label("Rs 0", 28, UI.YELLOW, HORIZONTAL_ALIGNMENT_RIGHT))
	_clock = _out(UI.label("", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT))
	_heat = _out(UI.label("", 18, Color(1, 0.4, 0.3), HORIZONTAL_ALIGNMENT_RIGHT))
	tr.add_child(_money)
	tr.add_child(_clock)
	tr.add_child(_heat)
	_obj = _out(UI.label("", 21, Color(1, 0.95, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	_obj.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_obj.offset_left = -330
	_obj.offset_right = 330
	_obj.offset_top = 12
	_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_obj)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_left = -260
	_toasts.offset_right = 260
	_toasts.offset_top = 86
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)
	_sub = _out(UI.label("", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_sub.offset_left = -420
	_sub.offset_right = 420
	_sub.offset_top = -150
	_sub.offset_bottom = -90
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_sub)
	for i in 2:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
		b.custom_minimum_size.y = 0
		root.add_child(b)
		_bars.append(b)
	_build_dialogue(root)
	_card = Control.new()
	UI.full(_card)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_card)
	_fade = UI.rect(Color(0, 0, 0, 0))
	root.add_child(_fade)
	Game.toast.connect(toast)
	Game.changed.connect(refresh)
	Game.settings_changed.connect(func():
		_grain.material.set_shader_parameter("strength", 0.018 if Game.settings.grain else 0.0)
		pad.queue_redraw())
	refresh()

func _out(l: Label) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _build_dialogue(root: Control) -> void:
	_dlg = Control.new()
	UI.full(_dlg)
	_dlg.visible = false
	root.add_child(_dlg)
	var tap := Button.new()
	tap.flat = true
	tap.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UI.full(tap)
	tap.pressed.connect(_dlg_tap)
	_dlg.add_child(tap)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.03, 0.04, 0.9), 4, 0, Color.BLACK, 18))
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	p.offset_left = 150
	p.offset_right = -150
	p.offset_top = -178
	p.offset_bottom = -26
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(p)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb)
	_dlg_name = UI.label("", 22, UI.YELLOW)
	vb.add_child(_dlg_name)
	_dlg_text = UI.label("", 25, Color(0.96, 0.96, 0.93))
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_dlg_text)
	_dlg_hint = UI.label("tap to continue  >", 14, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
	vb.add_child(_dlg_hint)
	_choices = VBoxContainer.new()
	_choices.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_choices.offset_left = -560
	_choices.offset_right = -150
	_choices.offset_top = -210
	_choices.offset_bottom = 150
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.add_theme_constant_override("separation", 10)
	_dlg.add_child(_choices)

# ------------------------------------------------------------------ frame update
func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var pl: Player = world.player
	var en := modal == 0 and not cinematic
	if en != pad.enabled:
		pad.enabled = en
		pad.queue_redraw()
	if pad.enabled and not get_tree().paused:
		pl.input_move = pad.stick
		pl.input_sprint = pad.held("sprint")
		pl.input_throttle = (1.0 if pad.held("accel") else 0.0) - (1.0 if pad.held("brake") else 0.0)
		pl.input_steer = (1.0 if pad.held("right") else 0.0) - (1.0 if pad.held("left") else 0.0)
		if pl.in_vehicle() and int(Game.settings.steer) == 1:
			pl.input_steer = pad.stick.x
			pl.input_move = Vector2.ZERO
		pl.input_handbrake = pad.held("hbrake")
		pl.look_input(pad.take_look())
		for a in ["interact", "jump", "crouch", "punch", "phone", "map", "cam", "pause", "horn"]:
			if Input.is_action_just_pressed(a):
				_on_pad(a if a != "handbrake" else "hbrake")
	else:
		pl.input_move = Vector2.ZERO
		pl.input_sprint = false
		pl.input_throttle = 0.0
		pl.input_steer = 0.0
		pad.take_look()
	if _typing > 0.0 and _dlg.visible:
		_typing += delta * 60.0
		_dlg_text.visible_characters = int(_typing)
		if _dlg_text.visible_characters >= _dlg_text.text.length():
			_dlg_text.visible_characters = -1
			_typing = 0.0
	_acc += delta
	if _acc > 0.12:
		_acc = 0.0
		var p2 := Vector2(pl.global_position.x, pl.global_position.z)
		mini.centre = p2
		mini.player_pos = p2
		mini.player_yaw = pl.human.global_rotation.y if not pl.in_vehicle() else pl.vehicle.rotation.y
		var op = world.story.objective_pos()
		mini.objective = Vector2(op.x, op.z) if op != null else null
		var wp = Game.s.get("waypoint")
		mini.waypoint = Vector2(wp[0], wp[1]) if wp != null else null
		mini.visible = not cinematic and world.interior == ""
		mini.queue_redraw()
		_clock.text = "%s  -  %s" % [Game.clock_text(), Game.date_text()] if str(Game.s.mode) == "story" else "%s  -  Day %d" % [Game.clock_text(), int(Game.s.day)]
		var an: String = world.area_name()
		if an != _area_name:
			_area_name = an
			_area.text = an
		var ot: String = world.story.objective_text()
		var tgt = op
		if tgt == null and wp != null:
			tgt = Vector3(wp[0], 0, wp[1])
		if tgt != null and world.interior == "":
			var dm: float = pl.global_position.distance_to(tgt)
			ot += "   [%d m]" % int(dm)
		_obj.text = ot
		for c in [_money, _clock, _heat, _area, _obj, pad]:
			c.visible = not cinematic

func refresh() -> void:
	if Game.s.is_empty():
		return
	_money.text = "Rs %s" % _commas(int(Game.s.money))
	var h := int(ceil(float(Game.s.heat) / 20.0))
	_heat.text = "WANTED " + "*".repeat(h) if h > 0 else Game.rank().to_upper()
	_heat.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if h > 0 else Color(0.8, 0.8, 0.8))
	pad.queue_redraw()

func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func set_mode(m: String) -> void:
	pad.mode = m
	pad.reset()

func set_interact(t: String) -> void:
	if pad.interact_text != t:
		pad.interact_text = t
		pad.queue_redraw()

func _on_pad(id: String) -> void:
	if world == null or modal > 0 or cinematic:
		return
	var pl: Player = world.player
	match id:
		"interact": world.interact()
		"jump": pl.jump()
		"crouch": pl.toggle_crouch()
		"punch": pl.punch()
		"exit": world.exit_vehicle()
		"horn": world.player_horn()
		"cam":
			# cycle: normal -> close -> wide -> first person
			if pl.first_person:
				pl.first_person = false
				pl.cam_zoom = 1.0
			elif pl.cam_zoom == 1.0:
				pl.cam_zoom = 0.62
			elif pl.cam_zoom < 1.0:
				pl.cam_zoom = 1.6
			else:
				pl.first_person = true
		"phone":
			if Game.s.phone:
				open_phone()
		"map": open_map()
		"pause": open_pause()
		"radio": Sfx.radio_next()
		"whistle": world.story.bus_signal("whistle")
		"bell": world.story.bus_signal("bell")

# ------------------------------------------------------------------ toasts / subtitles
func toast(text: String) -> void:
	var l := _out(UI.label(text, 20, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER))
	_toasts.add_child(l)
	if _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

func subtitle(text: String, dur := 3.0) -> void:
	if not Game.settings.subtitles:
		return
	_sub.text = text
	_sub.modulate.a = 1.0
	var tw := _sub.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(_sub, "modulate:a", 0.0, 0.5)

# ------------------------------------------------------------------ dialogue
func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func say(who: String, text: String) -> void:
	_dlg.visible = true
	_choices.visible = false
	modal_set("dlg", true)
	_dlg_name.text = who.to_upper()
	_dlg_text.text = text
	_dlg_text.visible_characters = 0
	_dlg_hint.visible = true
	_typing = 1.0
	Sfx.play("blip", 0.25, voice * randf_range(0.95, 1.05))
	if Game.test_mode:
		await _wait(0.02)
	else:
		await dlg_advance

func _dlg_tap() -> void:
	if _choices.visible:
		return
	if _typing > 0.0:
		_typing = 0.0
		_dlg_text.visible_characters = -1
	else:
		dlg_advance.emit()

func choose(options: Array) -> int:
	_dlg.visible = true
	modal_set("dlg", true)
	_dlg_hint.visible = false
	for c in _choices.get_children():
		c.queue_free()
	_choices.visible = true
	for i in options.size():
		var b := UI.button(str(options[i]), 21)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func(): chosen.emit(i))
		_choices.add_child(b)
	var r := 0
	if Game.test_mode:
		await _wait(0.02)
		var q: Array = Game.get_meta("test_choices", [])
		r = int(q.pop_front()) if not q.is_empty() else 0
		r = clampi(r, 0, options.size() - 1)
	else:
		r = await chosen
	_choices.visible = false
	return r

func end_talk() -> void:
	_dlg.visible = false
	modal_set("dlg", false)

var _modal_set := {}
func modal_set(key: String, on: bool) -> void:
	if on:
		_modal_set[key] = true
	else:
		_modal_set.erase(key)
	modal = _modal_set.size()
	if modal > 0:
		pad.reset()

# ------------------------------------------------------------------ list menu (shops, fast travel, wardrobe)
## items: [{text, sub (optional), disabled (optional)}]  -> index or -1
func menu(title: String, items: Array, foot := "") -> int:
	if _menu != null:
		_menu.queue_free()
	modal_set("menu", true)
	_menu = UI.rect(Color(0, 0, 0, 0.55))
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.07, 0.08, 0.97), 8, 2, UI.YELLOW, 18))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -330
	p.offset_right = 330
	p.offset_top = -300
	p.offset_bottom = 300
	_menu.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	vb.add_child(UI.label(title, 28, UI.YELLOW))
	if foot != "":
		var fl := UI.label(foot, 17, Color(0.8, 0.8, 0.8))
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(fl)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	for i in items.size():
		var it = items[i]
		var txt: String = it.text
		if it.has("sub"):
			txt += "\n   " + str(it.sub)
		var b := UI.button(txt, 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = it.get("disabled", false)
		b.pressed.connect(func(): menu_picked.emit(i))
		list.add_child(b)
	var close := UI.button("Close", 20)
	close.pressed.connect(func(): menu_picked.emit(-1))
	vb.add_child(close)
	var r := -1
	if Game.test_mode:
		await _wait(0.02)
		var q: Array = Game.get_meta("test_choices", [])
		r = int(q.pop_front()) if not q.is_empty() else -1
	else:
		r = await menu_picked
	if _menu != null:
		_menu.queue_free()
		_menu = null
	modal_set("menu", false)
	return r

# ------------------------------------------------------------------ cinematics
func letterbox(on: bool) -> void:
	cinematic = on
	if on:
		pad.reset()
	for b in _bars:
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "custom_minimum_size:y", 84.0 if on else 0.0, 0.5 * Engine.time_scale)
		if b == _bars[1]:
			tw.parallel().tween_property(b, "offset_top", -84.0 if on else 0.0, 0.5 * Engine.time_scale)

func fade(to_alpha: float, dur := 0.6) -> void:
	if Game.test_mode:
		_fade.color.a = to_alpha
		return
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", to_alpha, dur * Engine.time_scale)
	await tw.finished

func card(title: String, sub := "", dur := 3.2) -> void:
	for c in _card.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.offset_left = -500
	vb.offset_right = 500
	vb.offset_top = -70
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(vb)
	var t := _out(UI.label(title, 54, UI.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
	var s := _out(UI.label(sub, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(t)
	vb.add_child(s)
	_card.modulate.a = 0.0
	var tw := _card.create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.5)
	tw.tween_interval(dur if not Game.test_mode else 0.05)
	tw.tween_property(_card, "modulate:a", 0.0, 0.7)

func slow_fx(on: bool) -> void:
	_grain.material.set_shader_parameter("vignette", 0.75 if on else 0.3)
	_grain.material.set_shader_parameter("tint", 1.0 if on else 0.0)

# ------------------------------------------------------------------ map screen
func open_map() -> void:
	if _map_panel != null:
		return
	modal_set("map", true)
	_map_panel = UI.rect(Color(0.08, 0.06, 0.04, 0.98))
	_map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_map_panel)
	_full_map = MapView.new()
	_full_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full_map.offset_left = 14
	_full_map.offset_top = 52
	_full_map.offset_right = -262
	_full_map.offset_bottom = -14
	var pl: Player = world.player
	var p2: Vector2 = Vector2(pl.global_position.x, pl.global_position.z) if world.interior == "" else world.exterior_pos
	_full_map.centre = p2
	_full_map.player_pos = p2
	_full_map.player_yaw = pl.human.global_rotation.y if not pl.in_vehicle() else pl.vehicle.rotation.y
	_full_map.ppm = 0.55
	var op = world.story.objective_pos()
	_full_map.objective = Vector2(op.x, op.z) if op != null else null
	var wp = Game.s.get("waypoint")
	if wp != null:
		_full_map.waypoint = Vector2(wp[0], wp[1])
		_full_map.route = City.route(p2, _full_map.waypoint)
	_map_panel.add_child(_full_map)
	var title := UI.label("BANGALORE  -  CITY GUIDE MAP  -  2002", 22, UI.PAPER)
	title.position = Vector2(18, 12)
	_map_panel.add_child(title)
	var note := UI.label("Main roads, railways, tanks and landmarks from survey positions; side streets schematic.", 12, Color(0.7, 0.66, 0.58))
	note.position = Vector2(470, 20)
	_map_panel.add_child(note)
	var side := VBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -252
	side.offset_right = -12
	side.offset_top = 12
	side.offset_bottom = -12
	side.add_theme_constant_override("separation", 6)
	_map_panel.add_child(side)
	var info := UI.label("", 15, Color(0.92, 0.9, 0.84))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.y = 96
	side.add_child(info)
	var dest := UI.button("Set as destination", 18)
	dest.disabled = true
	side.add_child(dest)
	var clr := UI.button("Clear destination", 18)
	side.add_child(clr)
	var zr := HBoxContainer.new()
	zr.add_theme_constant_override("separation", 6)
	side.add_child(zr)
	for z in [["  +  ", func(): _full_map.zoom(1.6)], ["  -  ", func(): _full_map.zoom(1.0 / 1.6)]]:
		var zb := UI.button(z[0], 22)
		zb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zb.pressed.connect(z[1])
		zr.add_child(zb)
	var vr := HBoxContainer.new()
	vr.add_theme_constant_override("separation", 6)
	side.add_child(vr)
	for v in [["City", 0.1], ["Area", 0.3], ["Street", 1.0]]:
		var vb2 := UI.button(v[0], 16)
		vb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb2.pressed.connect(func(): _full_map.zoom_to(v[1]))
		vr.add_child(vb2)
	var ce := UI.button("Where am I?", 18)
	ce.pressed.connect(func():
		_full_map.centre = _full_map.player_pos
		_full_map.queue_redraw())
	side.add_child(ce)
	# legend
	var lg := Control.new()
	lg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lg.draw.connect(func():
		var f := ThemeDB.fallback_font
		for i in MapView.LEGEND.size():
			var row: Array = MapView.LEGEND[i]
			var y := 10.0 + i * 16.0
			var sy: Array = MapView.SYM[row[0]]
			lg.draw_rect(Rect2(4, y - 8, 15, 15), sy[1])
			lg.draw_string(f, Vector2(7, y + 4), sy[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
			lg.draw_string(f, Vector2(26, y + 4), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.82, 0.74))
		var y2 := 10.0 + MapView.LEGEND.size() * 16.0
		lg.draw_circle(Vector2(11, y2), 7, Color(0.75, 0.72, 0.65))
		lg.draw_string(f, Vector2(8, y2 + 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.3, 0.3))
		lg.draw_string(f, Vector2(26, y2 + 4), "Not yet visited", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.82, 0.74))
		lg.draw_dashed_line(Vector2(2, y2 + 16), Vector2(20, y2 + 16), Color(0.9, 0.2, 0.15), 2.0, 5.0)
		lg.draw_string(f, Vector2(26, y2 + 20), "Bus route 27E", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.82, 0.74))
		lg.draw_line(Vector2(2, y2 + 32), Vector2(20, y2 + 32), Color(0.2, 0.45, 0.95), 4.0)
		lg.draw_string(f, Vector2(26, y2 + 36), "Your route", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.82, 0.74)))
	side.add_child(lg)
	var cl := UI.button("Close map", 20)
	cl.pressed.connect(close_map)
	side.add_child(cl)
	var state := {"pick": Vector2.INF}
	var describe := func(p: Vector2, name: String, kind: String):
		var d := p.distance_to(_full_map.player_pos)
		info.text = "%s\n%s\n%s  -  about %s away" % [name, kind, City.area_name(p), ("%d m" % int(d * 4.0)) if d * 4.0 < 1000.0 else ("%.1f km" % (d * 4.0 / 1000.0))]
		state.pick = p
		dest.disabled = false
	if wp != null:
		describe.call(_full_map.waypoint, "Current destination", "Marked on your map")
	else:
		info.text = "Drag to move the map. Pinch, scroll or use + / - to zoom.\nTap a symbol or any street to see what is there."
	_full_map.place_tapped.connect(func(id):
		var plc = City.PLACES[id]
		if Game.s.discovered.has(id):
			describe.call(Vector2(plc.pos.x, plc.pos.z), plc.name, str(plc.kind).capitalize())
		else:
			describe.call(Vector2(plc.pos.x, plc.pos.z), "Unvisited place", "You have not been here yet"))
	_full_map.spot_tapped.connect(func(p):
		describe.call(p, "Marked spot", "Street location"))
	dest.pressed.connect(func():
		if state.pick != Vector2.INF:
			_set_wp(state.pick)
			var total := 0.0
			for i in _full_map.route.size() - 1:
				total += _full_map.route[i].distance_to(_full_map.route[i + 1])
			info.text += "\nRoute by main roads: %.1f km" % (total * 4.0 / 1000.0))
	clr.pressed.connect(func():
		Game.s.waypoint = null
		_full_map.waypoint = null
		_full_map.route = PackedVector2Array()
		_full_map.queue_redraw())

func _set_wp(p: Vector2) -> void:
	Game.s.waypoint = [p.x, p.y]
	_full_map.waypoint = p
	_full_map.route = City.route(_full_map.player_pos, p)
	_full_map.queue_redraw()
	Sfx.play("blip", 0.5)

func close_map() -> void:
	if _map_panel != null:
		_map_panel.queue_free()
		_map_panel = null
		_full_map = null
	modal_set("map", false)

# ------------------------------------------------------------------ phone / pause
func open_phone() -> void:
	if _phone != null:
		return
	modal_set("phone", true)
	_phone = Phone.new()
	_phone.hud = self
	add_child(_phone)
	_phone.closed.connect(func():
		_phone.queue_free()
		_phone = null
		modal_set("phone", false))

func open_pause() -> void:
	if _pause != null:
		return
	modal_set("pause", true)
	get_tree().paused = true
	_pause = UI.rect(Color(0, 0, 0, 0.7))
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.offset_left = -200
	vb.offset_right = 200
	vb.offset_top = -240
	vb.add_theme_constant_override("separation", 12)
	_pause.add_child(vb)
	vb.add_child(UI.label("PAUSED", 44, UI.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(UI.label("%s  -  %s  -  Day %d" % [Game.s.name, Game.rank(), int(Game.s.day)], 18, Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	var items := [["Resume", close_pause], ["Save game", func(): Game.save_game()], ["Settings", _pause_settings],
		["Quit to main menu", func():
			Game.save_game(false)
			close_pause()
			Game.goto("menu")]]
	for it in items:
		var b := UI.button(it[0], 24, 400)
		b.pressed.connect(it[1])
		vb.add_child(b)

func _pause_settings() -> void:
	var sp := SettingsPanel.new()
	_pause.add_child(sp)

func close_pause() -> void:
	get_tree().paused = false
	if _pause != null:
		_pause.queue_free()
		_pause = null
	modal_set("pause", false)
