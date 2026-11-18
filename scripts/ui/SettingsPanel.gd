class_name SettingsPanel
extends Control
## Settings overlay used by both the main menu and the pause menu.

func _ready() -> void:
	UI.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := UI.rect(Color(0, 0, 0, 0.85))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.07, 0.08), 8, 2, UI.YELLOW, 20))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -400
	p.offset_right = 400
	p.offset_top = -320
	p.offset_bottom = 320
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	vb.add_child(UI.label("SETTINGS", 30, UI.YELLOW))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var g := VBoxContainer.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("separation", 8)
	sc.add_child(g)
	_cycle(g, "Graphics", "gfx", ["Low", "Medium", "High"])
	_cycle(g, "Frame rate", "fps60", ["30 FPS", "60 FPS"], true)
	_cycle(g, "Film grain", "grain", ["Off", "On"], true)
	g.add_child(UI.label("CONTROLS", 20, UI.YELLOW))
	_slider(g, "Camera sensitivity (horizontal)", "sens", 0.3, 2.5)
	_slider(g, "Camera sensitivity (vertical)", "sens_y", 0.3, 2.5)
	_cycle(g, "Invert camera Y", "invert_y", ["Off", "On"], true)
	_slider(g, "Movement stick size", "stick_scale", 0.7, 1.5)
	_slider(g, "Button size", "btn_scale", 0.7, 1.4)
	_slider(g, "HUD opacity", "btn_alpha", 0.2, 1.0)
	_cycle(g, "Control layout", "lefty", ["Right-handed", "Left-handed"], true)
	_slider(g, "RUN LOCK hold time (s)", "runlock_hold", 0.4, 1.2)
	_cycle(g, "Vibration", "haptics", ["Off", "On"], true)
	_cycle(g, "Show touches (testing)", "touch_trace", ["Off", "On"], true)
	var rl := UI.button("Reset controls to default", 18, 400)
	rl.pressed.connect(func():
		for k in Game.CONTROL_DEFAULTS:
			Game.settings[k] = Game.CONTROL_DEFAULTS[k]
		Game.save_settings()
		var parent := get_parent()
		queue_free()
		if parent != null:
			parent.add_child(SettingsPanel.new()))
	g.add_child(rl)
	g.add_child(UI.label("GAME", 20, UI.YELLOW))
	_cycle(g, "Steering", "steer", ["Arrow buttons", "Joystick"])
	_slider(g, "Intro music volume", "music", 0.0, 1.0)
	_slider(g, "Vehicle radio volume", "radio", 0.0, 1.0)
	_cycle(g, "Vehicle radio", "radio_mute", ["On", "Muted"], true)
	_slider(g, "Sound volume", "sfx", 0.0, 1.0)
	_cycle(g, "Street subtitles", "subtitles", ["Off", "On"], true)
	g.add_child(UI.label("Graphics changes to draw distance apply when the city reloads.", 14, Color(0.6, 0.6, 0.6)))
	var done := UI.button("Done", 22)
	done.pressed.connect(func():
		Game.save_settings()
		queue_free())
	vb.add_child(done)

func _row(parent: Control, title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UI.label(title, 20)
	l.custom_minimum_size.x = 300
	h.add_child(l)
	parent.add_child(h)
	return h

func _cycle(parent: Control, title: String, key: String, names: Array, is_bool := false) -> void:
	var h := _row(parent, title)
	var b := UI.button("", 20, 300)
	var cur := func() -> int: return (1 if Game.settings[key] else 0) if is_bool else int(Game.settings[key])
	b.text = names[cur.call()]
	b.pressed.connect(func():
		var n: int = (cur.call() + 1) % names.size()
		Game.settings[key] = (n == 1) if is_bool else n
		b.text = names[n]
		Game.save_settings())
	h.add_child(b)

func _slider(parent: Control, title: String, key: String, lo: float, hi: float) -> void:
	var h := _row(parent, title)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(300, 44)
	s.value_changed.connect(func(v): Game.settings[key] = v)
	s.drag_ended.connect(func(_c): Game.save_settings())
	h.add_child(s)
