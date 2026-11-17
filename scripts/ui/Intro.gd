class_name Intro
extends Control
## The production identity, cut to the supplied soundtrack.
##   0.0  white.  HANVI'S sets letter by letter, ORIGINAL is drawn in beneath it.
##  10.0  the frame falls to black.
##  12.5  hand over to the BIG BANG LORE menu; the music carries on underneath.
## (The old star and RAJINIKANTH title card were retired with the old story;
##  the game's own title now lands at the end of the opening sequence.)

const T_BLACK := 10.0
const T_STAR := 12.5
const T_TITLE := 23.0
const T_END := 12.5

var _done := false
var _t := 0.0
var _logo: Control
var _glyphs: Array = []
var _orig_clip: Control
var _orig: TextureRect
var _orig_full := 0.0
var _black: ColorRect
var _star: TextureRect
var _glow: TextureRect
var _letters: Array = []
var _row: Control
var _pres: Label
var _tag: Label
var _rule: ColorRect
var _use_clock := false

func _ready() -> void:
	UI.full(self)
	add_child(UI.rect(Color(0.996, 0.996, 0.996)))
	_logo = Control.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	var sc := 0.62
	# --- HANVI'S: one node per glyph so the tracking can breathe ---
	var tex: Texture2D = load("res://assets/img/logo_hanvis.png")
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/img/logo_hanvis.json"))
	var segs: Array = meta.glyphs if meta is Dictionary else [[0, tex.get_width()]]
	var cx := float(tex.get_width()) * 0.5
	for g in segs:
		for shadow in [true, false]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(g[0] - 2, 0, g[1] - g[0] + 4, tex.get_height())
			var tr := TextureRect.new()
			tr.texture = at
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.size = at.region.size * sc
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.modulate = Color(0, 0, 0, 0) if shadow else Color(1, 1, 1, 0)
			_logo.add_child(tr)
			_glyphs.append({"n": tr, "x": (float(g[0]) - 2.0 - cx) * sc, "shadow": shadow, "i": _glyphs.size() / 2})
	# --- ORIGINAL: drawn in left to right, settling from a slight enlargement ---
	var otex: Texture2D = load("res://assets/img/logo_original.png")
	var osz := Vector2(otex.get_size()) * sc
	_orig_full = osz.x
	_orig_clip = Control.new()
	_orig_clip.clip_contents = true
	_orig_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orig_clip.size = Vector2(0, osz.y + 12)
	_orig_clip.position = Vector2(-osz.x * 0.5, 30 - osz.y * 0.5)
	_logo.add_child(_orig_clip)
	var osh := TextureRect.new()
	osh.texture = otex
	osh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	osh.size = osz
	osh.position = Vector2(0, 5)
	osh.modulate = Color(0, 0, 0, 0.10)
	_orig_clip.add_child(osh)
	_orig = TextureRect.new()
	_orig.texture = otex
	_orig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_orig.size = osz
	_orig_clip.add_child(_orig)
	# --- black, star, title ---
	_black = UI.rect(Color(0, 0, 0, 0))
	add_child(_black)
	_glow = TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.8, 0.1, 0.22))
	gr.set_color(1, Color(1.0, 0.8, 0.1, 0.0))
	gt.gradient = gr
	_glow.texture = gt
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.size = Vector2(620, 620)
	_glow.pivot_offset = Vector2(310, 310)
	_glow.modulate.a = 0.0
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)
	_star = TextureRect.new()
	_star.texture = load("res://assets/img/star.png")
	_star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_star.size = Vector2(210, 210)
	_star.pivot_offset = Vector2(105, 105)
	_star.modulate.a = 0.0
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_star)
	_star.visible = false
	_glow.visible = false
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	for ch in "":
		for shadow in [true, false]:
			var l := UI.label(ch, 86, Color(0.35, 0.28, 0.0) if shadow else Color(0.98, 0.97, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
			l.size = Vector2(80, 110)
			l.pivot_offset = Vector2(40, 60)
			l.modulate.a = 0.0
			_row.add_child(l)
			_letters.append({"n": l, "shadow": shadow, "i": _letters.size() / 2})
	_rule = ColorRect.new()
	_rule.color = UI.YELLOW
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rule)
	_pres = UI.label("H A N V I ' S   O R I G I N A L   P R E S E N T S", 16, Color(0.72, 0.72, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_pres.size = Vector2(800, 30)
	_pres.modulate.a = 0.0
	add_child(_pres)
	_tag = UI.label("ONE CITY.   COUNTLESS STORIES.   ONE MAN'S UNEXPECTED TRANSFORMATION.", 18, UI.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_tag.size = Vector2(1000, 30)
	_tag.modulate.a = 0.0
	add_child(_tag)
	add_child(UI.grain(0.05, 0.38))
	var skip := Button.new()
	skip.flat = true
	skip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UI.full(skip)
	skip.pressed.connect(func():
		if _t > 1.5: _finish())
	add_child(skip)
	Sfx.music("", 0.1)
	Sfx.intro_play()
	_use_clock = Sfx.intro_playing()

static func ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

static func ease_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _process(delta: float) -> void:
	# the picture follows the soundtrack's own clock, so the two can never drift
	var mt := Sfx.intro_time()
	if _use_clock and mt >= 0.0 and not Game.test_mode:
		_t = maxf(_t, mt)
	else:
		_t += delta * (4.0 if Game.test_mode else 1.0)
	var c := size * 0.5
	var t := _t
	# HANVI'S: wide tracking gathers to the reference spacing while each glyph settles upward
	_logo.position = c
	var track := lerpf(1.55, 1.0, ease_out((t - 0.6) / 5.5))
	var settle := lerpf(1.035, 1.0, ease_out((t - 0.6) / 8.5))
	_logo.scale = Vector2(settle, settle)
	for g in _glyphs:
		var a := ease_io((t - 0.8 - float(g.i) * 0.32) / 1.3)
		var n: TextureRect = g.n
		n.position = Vector2(g.x * track, -78.0 - n.size.y * 0.5 + (1.0 - ease_out((t - 0.8 - float(g.i) * 0.32) / 1.6)) * 9.0)
		if g.shadow:
			n.position += Vector2(0, 3.5)
			n.modulate = Color(0.05, 0.08, 0.2, a * 0.10)
		else:
			n.modulate.a = a
	_orig_clip.size.x = (_orig_full + 8.0) * ease_io((t - 3.4) / 3.6)
	_orig.modulate.a = ease_io((t - 3.4) / 1.2)
	_black.color.a = ease_io((t - T_BLACK) / 2.0)
	# the star: rises out of the dark, turns a few degrees into place, breathes once on the hit
	var sa := ease_io((t - T_STAR) / 5.0)
	var hit := exp(-maxf(t - T_TITLE, 0.0) * 1.6) if t >= T_TITLE else 0.0
	var ss := lerpf(0.62, 1.0, ease_out((t - T_STAR) / 9.0)) + hit * 0.07
	_star.position = c + Vector2(-105, -205)
	_star.modulate.a = sa
	_star.scale = Vector2(ss, ss)
	_star.rotation = lerpf(-0.32, 0.0, ease_out((t - T_STAR) / 8.0))
	_glow.position = c + Vector2(-310, -410)
	_glow.modulate.a = sa * 0.55 + hit * 0.8
	_glow.scale = Vector2.ONE * (0.9 + hit * 0.25 + sin(t * 0.8) * 0.02)
	_pres.position = c + Vector2(-400, -262)
	_pres.modulate.a = ease_io((t - T_STAR - 3.0) / 3.0) * 0.9
	# RAJINIKANTH: each letter arrives slightly large and soft, then seats itself
	var spread := lerpf(74.0, 82.0, ease_out((t - T_TITLE) / 9.0))
	for L in _letters:
		var lt := (t - T_TITLE - float(L.i) * 0.2) / 0.9
		var n2: Label = L.n
		var a2 := ease_io(lt)
		var s2 := lerpf(1.22, 1.0, ease_out(lt))
		n2.position = c + Vector2((float(L.i) - 5.0) * spread - 40.0, 44.0 + (1.0 - ease_out(lt)) * 10.0)
		n2.scale = Vector2(s2, s2)
		if L.shadow:
			n2.position += Vector2(2.5, 3.5)
			n2.modulate.a = a2 * 0.7
		else:
			n2.modulate.a = a2
	var rw := 520.0 * ease_io((t - T_TITLE - 2.6) / 2.2)
	_rule.size = Vector2(rw, 2)
	_rule.position = c + Vector2(-rw * 0.5, 160)
	_tag.position = c + Vector2(-500, 174)
	_tag.modulate.a = ease_io((t - T_TITLE - 3.6) / 2.4)
	if t >= T_END:
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	Game.settings.intro_seen = true
	Game.save_settings()
	Game.goto("menu")
