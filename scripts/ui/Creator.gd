class_name Creator
extends Control
## Character creation with a live, rotatable 3D preview.

var args := {}
var look := {}
var _human: Human
var _pivot: Node3D
var _name: LineEdit
var _rows := {}

const OPTS := [
	["sex", "Body", ["Man", "Woman"]], ["face", "Face", Human.FACES], ["skin", "Skin tone", ["Fair", "Wheatish", "Medium", "Brown", "Dark brown", "Deep"]],
	["hair", "Hairstyle", Human.HAIRS], ["hair_col", "Hair colour", ["Black", "Dark brown", "Grey", "White", "Henna"]], ["beard", "Facial hair", Human.BEARDS],
	["top", "Top", Human.TOPS], ["top_col", "Top colour", Shops.COLOUR_NAMES], ["bottom", "Lower", Human.BOTTOMS], ["bot_col", "Lower colour", Shops.COLOUR_NAMES],
	["shoes", "Footwear", Human.SHOES], ["glasses", "Glasses", Human.GLASSES], ["watch", "Watch", Human.WATCHES], ["acc", "Accessory", Human.ACCS],
]

func _ready() -> void:
	UI.full(self)
	add_child(UI.rect(Color(0.04, 0.04, 0.05)))
	look = Human.default_look()
	var story: bool = args.get("mode", "story") == "story"
	# --- 3D preview ---
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	svc.offset_right = 520
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = false
	svc.add_child(sv)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.09, 0.09, 0.11)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.6
	sv.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 150, 0)
	sun.light_energy = 1.2
	sv.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, -3.3)
	cam.rotation_degrees = Vector3(-3, 180, 0)
	cam.fov = 40
	sv.add_child(cam)
	_pivot = Node3D.new()
	sv.add_child(_pivot)
	var floor_m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 1.0
	cyl.height = 0.08
	cyl.material = Mats.col(Color(0.16, 0.16, 0.18))
	floor_m.mesh = cyl
	floor_m.position.y = -0.04
	sv.add_child(floor_m)
	_human = Human.make(look)
	_pivot.add_child(_human)
	var drag := Control.new()
	drag.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	drag.offset_right = 520
	drag.gui_input.connect(func(ev):
		if ev is InputEventScreenDrag or (ev is InputEventMouseMotion and ev.button_mask != 0):
			_pivot.rotation.y += ev.relative.x * 0.012)
	add_child(drag)
	var hint := UI.label("drag to turn", 14, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(200, 12)
	add_child(hint)
	# --- options ---
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 540
	vb.offset_right = -30
	vb.offset_top = 20
	vb.offset_bottom = -20
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	vb.add_child(UI.label("WHO ARE YOU?" if not story else "RAJINIKANTH, BADGE 4471", 30, UI.YELLOW))
	var nr := HBoxContainer.new()
	nr.add_child(UI.label("Name  ", 20))
	_name = LineEdit.new()
	_name.text = "Rajinikanth" if story else "Shivu"
	_name.editable = not story
	_name.max_length = 18
	_name.custom_minimum_size = Vector2(300, 44)
	_name.add_theme_font_size_override("font_size", 20)
	nr.add_child(_name)
	if story:
		nr.add_child(UI.label("   (the story is his; the face is yours to choose)", 14, Color(0.6, 0.6, 0.6)))
	vb.add_child(nr)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	sc.add_child(list)
	for o in OPTS:
		if o[0] == "sex" and story:
			continue
		var h := HBoxContainer.new()
		var l := UI.label(o[1], 19)
		l.custom_minimum_size.x = 150
		h.add_child(l)
		var prev := UI.button("<", 20, 56)
		var val := UI.label("", 19, UI.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
		val.custom_minimum_size.x = 290
		var nxt := UI.button(">", 20, 56)
		prev.pressed.connect(_step.bind(o[0], -1))
		nxt.pressed.connect(_step.bind(o[0], 1))
		h.add_child(prev)
		h.add_child(val)
		h.add_child(nxt)
		list.add_child(h)
		_rows[o[0]] = val
	for sl in [["height", "Height"], ["build", "Build"]]:
		var h2 := HBoxContainer.new()
		var l2 := UI.label(sl[1], 19)
		l2.custom_minimum_size.x = 150
		h2.add_child(l2)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(look[sl[0]])
		s.custom_minimum_size = Vector2(402, 40)
		s.value_changed.connect(func(v):
			look[sl[0]] = v
			_human.set_look(look))
		h2.add_child(s)
		list.add_child(h2)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	vb.add_child(bottom)
	var back := UI.button("Back", 22, 150)
	back.pressed.connect(func(): Game.goto("menu"))
	bottom.add_child(back)
	var rnd := UI.button("Surprise me", 22, 200)
	rnd.pressed.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		look = Human.random_look(rng, 0 if story else -1)
		_refresh())
	bottom.add_child(rnd)
	var go := UI.button("Begin", 24, 240)
	go.pressed.connect(_begin)
	bottom.add_child(go)
	_refresh()

func _valid(key: String, i: int) -> bool:
	var female: bool = int(look.sex) == 1
	match key:
		"top": return (i >= 8) == female or i in [4, 5]
		"bottom": return (i >= 4) == female or (i == 1)
		"hair": return (i >= 7) == female
		"beard": return not female or i == 0
		"acc": return (i != 5 or female) and (i != 4 or not female)
	return true

func _step(key: String, d: int) -> void:
	var n := 0
	for o in OPTS:
		if o[0] == key:
			n = o[2].size()
	var i := int(look[key])
	for k in n:
		i = posmod(i + d, n)
		if _valid(key, i):
			break
	look[key] = i
	if key == "sex":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var keep_skin = look.skin
		look = Human.random_look(rng, i)
		look.skin = keep_skin
	_refresh()

func _refresh() -> void:
	for o in OPTS:
		if _rows.has(o[0]):
			_rows[o[0]].text = str(o[2][int(look[o[0]]) % o[2].size()])
	_human.set_look(look)

func _begin() -> void:
	var nm := _name.text.strip_edges()
	if nm == "":
		nm = "Rajinikanth"
	Game.start_new(int(args.get("slot", 0)), str(args.get("mode", "story")), nm, look)
	for slot in ["top", "bottom", "shoes", "glasses", "watch", "acc"]:
		Game.s.wardrobe.append("%s:%d" % [slot, int(look[slot])])
	Game.save_game(false)
	Game.goto("world")
