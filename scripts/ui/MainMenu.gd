class_name MainMenu
extends Control
## Title menu: continue, new story, free play, load, settings, about.

var _panel: Control = null

func _ready() -> void:
	UI.full(self)
	add_child(UI.rect(Color.BLACK))
	var star := TextureRect.new()
	star.texture = load("res://assets/img/star.png")
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.position = Vector2(90, 70)
	star.size = Vector2(150, 150)
	add_child(star)
	var t := UI.label("RAJINIKANTH", 76, Color.WHITE)
	t.position = Vector2(84, 220)
	add_child(t)
	var st := UI.label("A HANVI'S ORIGINAL PRODUCTION  -  BANGALORE, 2002", 18, UI.YELLOW)
	st.position = Vector2(90, 318)
	add_child(st)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	vb.offset_left = -470
	vb.offset_right = -90
	vb.offset_top = 90
	vb.offset_bottom = -60
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)
	var latest := -1
	var best := -1.0
	for i in Game.SLOTS:
		var info = Game.slot_info(i)
		if info != null and float(info.playtime) > best:
			best = float(info.playtime)
			latest = i
	var items := [["Continue", func(): _load(latest), latest >= 0], ["New story", func(): _slots("story"), true], ["Free play (your own character)", func(): _slots("free"), true],
		["Load game", func(): _slots("load"), true], ["Settings", func(): add_child(SettingsPanel.new()), true], ["About", _about, true]]
	for it in items:
		var b := UI.button(it[0], 26)
		b.disabled = not it[2]
		b.pressed.connect(it[1])
		vb.add_child(b)
	var ver := UI.label("v%s  -  all characters and events are fictional" % ProjectSettings.get_setting("application/config/version"), 14, Color(0.5, 0.5, 0.5))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 90
	ver.offset_top = -40
	add_child(ver)
	add_child(UI.grain(0.08, 0.4))
	Sfx.music("music_title", 1.0)

func _load(i: int) -> void:
	if Game.load_game(i):
		Game.goto("world")

func _open(title: String) -> VBoxContainer:
	if _panel != null:
		_panel.queue_free()
	_panel = UI.rect(Color(0, 0, 0, 0.88))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.07, 0.08), 8, 2, UI.YELLOW, 20))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -420
	p.offset_right = 420
	p.offset_top = -300
	p.offset_bottom = 300
	_panel.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	vb.add_child(UI.label(title, 30, UI.YELLOW))
	return vb

func _close_row(vb: VBoxContainer) -> void:
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp)
	var b := UI.button("Back", 22)
	b.pressed.connect(func():
		_panel.queue_free()
		_panel = null)
	vb.add_child(b)

func _slots(mode: String) -> void:
	var vb := _open("Choose a save slot" if mode != "load" else "Load game")
	vb.add_child(UI.label("Each slot is an independent player profile stored on this device.", 16, Color(0.7, 0.7, 0.7)))
	for i in Game.SLOTS:
		var info = Game.slot_info(i)
		var txt := "Slot %d  -  empty" % (i + 1)
		if info != null:
			txt = "Slot %d  -  %s  (%s)\n   Day %d, Rs %d, %s, %d min played" % [i + 1, info.name, "Story" if info.mode == "story" else "Free play", info.day, info.money, Story.TITLES.get(info.active, "exploring"), int(info.playtime / 60.0)]
		var row := HBoxContainer.new()
		var b := UI.button(txt, 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		if mode == "load":
			b.disabled = info == null
			b.pressed.connect(func(): _load(i))
			if info != null:
				var del := UI.button("Delete", 17)
				del.pressed.connect(func():
					if del.text == "Sure?":
						Game.delete_slot(i)
						_slots(mode)
					else:
						del.text = "Sure?")
				row.add_child(del)
		else:
			b.pressed.connect(func():
				if info != null and not b.text.begins_with("OVERWRITE"):
					b.text = "OVERWRITE slot %d? Tap again to confirm." % (i + 1)
				else:
					Game.goto("creator", {"slot": i, "mode": mode}))
		vb.add_child(row)
	_close_row(vb)

func _about() -> void:
	var vb := _open("RAJINIKANTH")
	var l := UI.label("A Hanvi's Original production.\n\nAn open-world crime drama about a Bangalore bus conductor, set in 2002. Chapter One, \"Ticket\", is playable; the city, its people and the story are still growing.\n\nEvery character, party, gang, film and business in this game is fictional. Real place names are used only as geography.\n\nBuilt with the open-source Godot Engine. All art, sound and music are original and generated for this game.", 19, Color(0.9, 0.9, 0.88))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)
	_close_row(vb)
