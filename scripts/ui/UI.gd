class_name UI
extends RefCounted
## Shared look for menus: black, star-yellow, Hanvi navy.

const YELLOW := Color(1.0, 0.8, 0.0)
const NAVY := Color(0.096, 0.134, 0.264)
const INK := Color(0.06, 0.06, 0.07)
const PAPER := Color(0.93, 0.9, 0.82)

static func box(c: Color, radius := 8, border := 0, bc := Color.BLACK, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = bc
	s.set_content_margin_all(pad)
	return s

static var _comic: Font = null

## The BIG BANG LORE display face (Bangers, SIL Open Font License).
static func comic() -> Font:
	if _comic == null:
		_comic = load("res://assets/fonts/Bangers.ttf")
	return _comic

static func label(text: String, size := 22, c := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, size := 24, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	b.add_theme_color_override("font_hover_color", YELLOW)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))
	b.add_theme_stylebox_override("normal", box(Color(0.1, 0.1, 0.12, 0.92), 6, 2, Color(0.3, 0.3, 0.32), 12))
	b.add_theme_stylebox_override("hover", box(Color(0.16, 0.16, 0.18, 0.95), 6, 2, YELLOW, 12))
	b.add_theme_stylebox_override("pressed", box(YELLOW, 6, 2, YELLOW, 12))
	b.add_theme_stylebox_override("disabled", box(Color(0.08, 0.08, 0.09, 0.8), 6, 2, Color(0.2, 0.2, 0.2), 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(min_w, size * 2.1)
	b.pressed.connect(func(): Sfx.play("click", 0.6))
	return b

static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

static func rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(r)
	return r

## Film grain + vignette overlay (no screen read, so it is cheap on mobile).
static func grain(strength := 0.07, vignette := 0.35) -> ColorRect:
	var r := ColorRect.new()
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.07;
uniform float vignette = 0.35;
uniform float tint = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
	float n = h(floor(UV * vec2(640.0, 360.0)) + floor(TIME * 24.0) * 7.13) - 0.5;
	vec2 d = UV - 0.5;
	float v = smoothstep(0.35, 0.95, length(d) * 1.25) * vignette;
	vec3 c = mix(vec3(0.5 + n), vec3(0.0), clamp(v * 1.4, 0.0, 1.0));
	float a = abs(n) * strength * 2.0 + v;
	COLOR = vec4(mix(c, vec3(0.35, 0.22, 0.08), tint * 0.5), clamp(a + tint * 0.12, 0.0, 1.0));
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("vignette", vignette)
	r.material = m
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(r)
	return r
