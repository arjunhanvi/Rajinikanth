class_name MainMenu
extends Control
## Title menu: continue, new story, free play, load, settings, about.

var _panel: Control = null

func _ready() -> void:
	UI.full(self)
	add_child(UI.rect(Color.BLACK))
	# the game's mark: the yellow star, and the title in the Portia manner
	var star := TextureRect.new()
	star.texture = load("res://assets/img/star.png")
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.position = Vector2(300, 46)
	star.size = Vector2(130, 130)
	star.pivot_offset = Vector2(65, 65)
	add_child(star)
	var tw := star.create_tween().set_loops()
	tw.tween_property(star, "scale", Vector2(1.04, 1.04), 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(star, "scale", Vector2(1.0, 1.0), 2.2).set_trans(Tween.TRANS_SINE)
	var t := UI.deco_title("BIG BANG LORE", 150, UI.YELLOW, 0.07, HORIZONTAL_ALIGNMENT_LEFT)
	t.position = Vector2(90, 180)
	t.size = Vector2(700, 170)
	add_child(t)
	var st := UI.label("A HANVI'S ORIGINAL PRODUCTION  -  BENGALURU, 1 JANUARY - 15 JUNE 2007", 18, UI.YELLOW)
	st.position = Vector2(90, 372)
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
	var items := [["Continue", func(): _load(latest), latest >= 0], ["New story", func(): _slots("story"), true], ["Free roam (Bengaluru, 2007)", func(): _slots("free"), true],
		["Load game", func(): _slots("load"), true], ["Settings", func(): add_child(SettingsPanel.new()), true], ["About", _about, true]]
	for it in items:
		var b := UI.button(it[0], 26)
		b.disabled = not it[2]
		b.pressed.connect(it[1])
		vb.add_child(b)
	var ver := UI.label("v%s  -  a work of fiction; real public figures appear only in a fictionalised context" % ProjectSettings.get_setting("application/config/version"), 14, Color(0.5, 0.5, 0.5))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 90
	ver.offset_top = -40
	add_child(ver)
	add_child(UI.grain(0.08, 0.4))
	# the Hanvi's Original intro music carries on under the menu, looping
	Sfx.theme_stop(0.5)
	Sfx.menu_music()
	if not Sfx.intro_available():
		var miss := UI.label("Intro music not found (assets/audio/user/intro_theme.ogg). Running silent.", 13, Color(0.8, 0.4, 0.3))
		miss.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		miss.offset_left = 90
		miss.offset_top = -62
		add_child(miss)

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
				elif mode == "story":
					# the protagonist is fixed: the story begins with Raja
					Game.start_new(i, "story", "Raja", Human.default_look())
					Game.goto("world")
				else:
					Sfx.intro_stop(1.0)
					Game.goto("creator", {"slot": i, "mode": mode}))
		vb.add_child(row)
	_close_row(vb)

func _about() -> void:
	var vb := _open("BIG BANG LORE")
	var l := UI.label("A Hanvi's Original production.\n\nBengaluru, 1 January to 15 June 2007. Two die-hard Rajinikanth fans, Raja and Lal and what they turn out to mean to each other. The opening sequence is playable; the story continues in later updates.\n\nThis is a work of fiction. Real public figures, institutions and places appear in a fictionalised, alternate-history context; none of their words or actions in this game are real records. The January 2007 shoot at M.S. Ramaiah Institute of Technology is invented for the game.\n\nBuilt with the open-source Godot Engine. Title lettering: Bangers (SIL Open Font License).\n\nMap data © OpenStreetMap contributors, available under the Open Database License (ODbL): openstreetmap.org/copyright. Elevation: SRTM (NASA, public domain). Shop and vehicle brands in the game are fictional.", 18, Color(0.9, 0.9, 0.88))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)
	_close_row(vb)
