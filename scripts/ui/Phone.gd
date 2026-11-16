class_name Phone
extends Control
## The in-game mobile: a 2002 candy-bar handset with a green monochrome LCD.
## Contacts, messages, call log, missions, profile/wallet, map and save.

signal closed

var hud
var _list: VBoxContainer
var _title: Label
var _stack: Array = ["home"]
const LCD := Color(0.62, 0.74, 0.5)
const LCD_INK := Color(0.1, 0.16, 0.1)

func _ready() -> void:
	UI.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := UI.rect(Color(0, 0, 0, 0.6))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", UI.box(Color(0.13, 0.17, 0.3), 46, 4, Color(0.05, 0.07, 0.14), 26))
	body.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	body.offset_left = -215
	body.offset_right = 215
	body.offset_top = -345
	body.offset_bottom = 345
	add_child(body)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	body.add_child(vb)
	vb.add_child(UI.label("SPARK", 18, Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER))
	var lcd := PanelContainer.new()
	lcd.add_theme_stylebox_override("panel", UI.box(LCD, 6, 4, Color(0.04, 0.05, 0.08), 12))
	lcd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(lcd)
	var lv := VBoxContainer.new()
	lcd.add_child(lv)
	var top := HBoxContainer.new()
	lv.add_child(top)
	_title = UI.label("", 20, LCD_INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	top.add_child(UI.label("|||  " + Game.clock_text(), 15, LCD_INK))
	var sep := ColorRect.new()
	sep.color = LCD_INK
	sep.custom_minimum_size.y = 2
	lv.add_child(sep)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	sc.add_child(_list)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 14)
	vb.add_child(keys)
	var back := UI.button("Back", 20)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_back)
	keys.add_child(back)
	var close := UI.button("Put away", 20)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func(): closed.emit())
	keys.add_child(close)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	for k in ["1", "2 abc", "3 def", "4 ghi", "5 jkl", "6 mno", "7 pqrs", "8 tuv", "9 wxyz", "*", "0", "#"]:
		var kl := UI.label(k, 14, Color(0.75, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
		kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kp := PanelContainer.new()
		kp.add_theme_stylebox_override("panel", UI.box(Color(0.2, 0.25, 0.4), 10, 0, Color.BLACK, 3))
		kp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kp.add_child(kl)
		grid.add_child(kp)
	_show()

func _row(text: String, cb = null) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", LCD_INK)
	b.add_theme_color_override("font_hover_color", LCD_INK)
	b.add_theme_color_override("font_pressed_color", LCD)
	b.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0), 2, 0, Color.BLACK, 6))
	b.add_theme_stylebox_override("hover", UI.box(Color(0, 0, 0, 0.1), 2, 0, Color.BLACK, 6))
	b.add_theme_stylebox_override("pressed", UI.box(LCD_INK, 2, 0, Color.BLACK, 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if cb != null:
		b.pressed.connect(func():
			Sfx.play("click", 0.5, 1.6)
			cb.call())
	else:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(b)

func _go(screen) -> void:
	_stack.append(screen)
	_show()

func _back() -> void:
	if _stack.size() > 1:
		_stack.pop_back()
		_show()
	else:
		closed.emit()

func _show() -> void:
	for c in _list.get_children():
		c.queue_free()
	var scr = _stack[-1]
	var s: Dictionary = Game.s
	if scr is Dictionary:      # a single message
		_title.text = str(scr.from)
		scr.read = true
		_row("Day %d\n\n%s" % [int(scr.d), scr.text])
		return
	match scr:
		"home":
			_title.text = "Menu"
			var unread := 0
			for m in s.messages:
				if not m.read:
					unread += 1
			_row("1  Messages" + (" (%d new)" % unread if unread > 0 else ""), func(): _go("messages"))
			_row("2  Contacts", func(): _go("contacts"))
			_row("3  Call register", func(): _go("calls"))
			_row("4  Missions", func(): _go("missions"))
			_row("5  Profile & wallet", func(): _go("profile"))
			_row("6  People", func(): _go("people"))
			_row("7  City map", func():
				closed.emit()
				hud.open_map())
			_row("8  Save game", func():
				Game.save_game()
				closed.emit())
		"messages":
			_title.text = "Inbox"
			if s.messages.is_empty():
				_row("(no messages)")
			for m in s.messages:
				var prev: String = str(m.text).substr(0, 46)
				_row("%s%s: %s..." % ["* " if not m.read else "", m.from, prev], func(): _go(m))
		"contacts":
			_title.text = "Contacts"
			if s.contacts.is_empty():
				_row("(phone book empty)")
			for id in s.contacts:
				var nm: String = People.NAMES.get(id, id)
				_row("%s\n   %s" % [nm, People.role(id)], func():
					s.calls.push_front({"who": nm, "d": int(s.day), "t": Game.clock_text()})
					if s.calls.size() > 20:
						s.calls.resize(20)
					closed.emit()
					hud.world.story.call_contact(id))
		"calls":
			_title.text = "Call register"
			if s.calls.is_empty():
				_row("(no calls)")
			for c in s.calls:
				_row("%s\n   Day %d, %s" % [c.who, int(c.d), c.t])
		"missions":
			_title.text = "Missions"
			_row("NOW: " + hud.world.story.objective_text())
			_row("--- Diary ---")
			for e in s.log:
				_row("Day %d: %s" % [int(e.d), e.t])
		"profile":
			_title.text = str(s.name)
			_row("Standing: %s (%d)" % [Game.rank(), int(s.rep)])
			_row("Cash: Rs %d" % int(s.money))
			_row("Day %d  -  %s" % [int(s.day), Game.clock_text()])
			_row("Tickets issued: %d" % int(s.stats.tickets))
			_row("Distance: %.1f km" % float(s.stats.km))
			_row("Vehicles: %s" % (", ".join(PackedStringArray(s.vehicles.map(func(v): return Vehicle.SPECS[v.type].name))) if not s.vehicles.is_empty() else "none"))
			_row("Property: %s" % (", ".join(PackedStringArray(s.props)) if not s.props.is_empty() else "rented room"))
			_row("--- The city ---")
			for f in [["tiger", "Thimmaiah's market gang"], ["soda", "Anthony's Cantonment company"], ["police", "Police"], ["jpp", "J.P.P."], ["knv", "K.N.V."]]:
				_row("%s: %s" % [f[1], _standing(int(s.faction.get(f[0], 0)))])
			_row("Election mood: JPP %d%% / KNV %d%%" % [int(s.politics.jpp), int(s.politics.knv)])
		"people":
			_title.text = "People"
			if s.rel.is_empty():
				_row("(you keep to yourself)")
			for id in s.rel:
				_row("%s: %s" % [People.NAMES.get(id, id), _bond(int(s.rel[id]))])

func _standing(v: int) -> String:
	if v <= -40: return "wants you gone"
	if v < -10: return "hostile"
	if v < 10: return "indifferent"
	if v < 40: return "useful to them"
	return "one of theirs"

func _bond(v: int) -> String:
	if v <= -30: return "bitter"
	if v < -5: return "cold"
	if v < 10: return "acquaintance"
	if v < 30: return "friendly"
	if v < 60: return "close"
	return "devoted"
