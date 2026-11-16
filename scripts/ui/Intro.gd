class_name Intro
extends Control
## The production identity: HANVI'S ORIGINAL on white, then the yellow star on
## black and the RAJINIKANTH title, cut to the original title theme.

var _done := false
var _t := 0.0
var _letters: Array = []

func _ready() -> void:
	UI.full(self)
	var white := UI.rect(Color(0.996, 0.996, 0.996))
	add_child(white)
	var hv := _wipe("logo_hanvis", Vector2(0, -78), 0.62)
	var og := _wipe("logo_original", Vector2(0, 30), 0.62)
	var black := UI.rect(Color(0, 0, 0, 0))
	add_child(black)
	var star := TextureRect.new()
	star.texture = load("res://assets/img/star.png")
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	star.offset_left = -110
	star.offset_right = 110
	star.offset_top = -200
	star.offset_bottom = 20
	star.pivot_offset = Vector2(110, 110)
	star.modulate.a = 0.0
	star.scale = Vector2(0.55, 0.55)
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(star)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.offset_left = -520
	row.offset_right = 520
	row.offset_top = 40
	row.offset_bottom = 150
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for ch in "RAJINIKANTH":
		var l := UI.label(ch, 84, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		l.modulate.a = 0.0
		row.add_child(l)
		_letters.append(l)
	var pres := UI.label("H A N V I ' S   O R I G I N A L   P R E S E N T S", 17, Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	pres.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pres.offset_left = -400
	pres.offset_right = 400
	pres.offset_top = -262
	pres.modulate.a = 0.0
	add_child(pres)
	var tag := UI.label("ONE CITY.  COUNTLESS STORIES.  ONE MAN'S UNEXPECTED TRANSFORMATION.", 19, UI.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tag.offset_left = -500
	tag.offset_right = 500
	tag.offset_top = 170
	tag.modulate.a = 0.0
	add_child(tag)
	var grain := UI.grain(0.1, 0.45)
	add_child(grain)
	var skip := Button.new()
	skip.flat = true
	skip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UI.full(skip)
	skip.pressed.connect(func():
		if _t > 1.0: _finish())
	add_child(skip)
	Sfx.music("music_title", 0.1)
	var k := 0.25 if Game.test_mode else 1.0
	var tw := create_tween()
	tw.tween_interval(1.0 * k)
	tw.tween_property(hv, "size:x", hv.get_meta("full"), 2.6 * k).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(og, "size:x", og.get_meta("full"), 3.4 * k).set_delay(1.4 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.2 * k)
	tw.tween_property(black, "color:a", 1.0, 2.0 * k)
	tw.tween_callback(func(): Sfx.play("whoosh", 0.35, 0.5))
	tw.tween_property(star, "modulate:a", 1.0, 3.6 * k).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(star, "scale", Vector2.ONE, 4.3 * k).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pres, "modulate:a", 1.0, 2.5 * k).set_delay(1.5 * k)
	for i in _letters.size():
		tw.tween_callback(func(): Sfx.play("click", 0.25, 0.55))
		tw.tween_property(_letters[i], "modulate:a", 1.0, 0.28 * k)
	tw.tween_property(row, "theme_override_constants/separation", 34, 4.0 * k).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(tag, "modulate:a", 1.0, 2.0 * k).set_delay(1.0 * k)
	tw.tween_interval(3.0 * k)
	tw.tween_callback(_finish)

func _wipe(tex_name: String, off: Vector2, scale_f: float) -> Control:
	var tex: Texture2D = load("res://assets/img/%s.png" % tex_name)
	var sz := Vector2(tex.get_size()) * scale_f
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	clip.position = Vector2(640, 360) + off - sz * 0.5
	clip.size = Vector2(0, sz.y)
	clip.set_meta("full", sz.x)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.size = sz
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(tr)
	add_child(clip)
	_place.append([clip, off, sz])
	return clip

var _place: Array = []

func _process(delta: float) -> void:
	_t += delta
	# keep the logo centred on any aspect ratio
	for p in _place:
		p[0].position = size * 0.5 + p[1] - p[2] * 0.5

func _finish() -> void:
	if _done:
		return
	_done = true
	Game.settings.intro_seen = true
	Game.save_settings()
	Game.goto("menu")
