class_name Mats
extends RefCounted
## Shared material cache. Everything in the world draws with a handful of materials.

const IMG := "res://assets/img/"
static var _m := {}
static var _tex := {}
static var night_on := false

static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(IMG + n + ".png")
	return _tex[n]

static func _std(key: String, t: String, rough := 0.95, repeat := true, vcol := false) -> StandardMaterial3D:
	if _m.has(key):
		return _m[key]
	var m := StandardMaterial3D.new()
	if t != "":
		m.albedo_texture = tex(t)
	m.roughness = rough
	m.metallic_specular = 0.2
	m.texture_repeat = repeat
	m.vertex_color_use_as_albedo = vcol
	_m[key] = m
	return m

static func facade() -> StandardMaterial3D:
	if _m.has("facade"):
		return _m["facade"]
	var m := _std("facade", "atlas_day", 0.95, false, true)
	m.emission_enabled = true
	m.emission_texture = tex("atlas_eve_emit")
	m.emission = Color.WHITE
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_energy_multiplier = 0.0
	return m

## phase: 0 day, 1 evening (windows lit, shops open), 2 late night (shops shuttered); power=false during a power cut
static func set_facade_phase(phase: int, power := true) -> void:
	night_on = phase > 0
	head().albedo_color = Color(0.42, 0.4, 0.32) if phase > 0 else Color(0, 0, 0)
	var m := facade()
	m.albedo_texture = tex(["atlas_day", "atlas_eve", "atlas_night"][phase])
	m.emission_texture = tex("atlas_night_emit" if phase == 2 else "atlas_eve_emit")
	m.emission_energy_multiplier = 0.0 if (phase == 0 or not power) else 1.6
	lamp().emission_energy_multiplier = 0.0 if (phase == 0 or not power) else 3.0
	signs().emission_energy_multiplier = 0.35 if (phase == 1 and power) else 0.0
	pool(false).albedo_color = Color(0.75, 0.5, 0.2) if (phase > 0 and power) else Color(0, 0, 0)
	pool(true).albedo_color = Color(0.4, 0.36, 0.26) if (phase == 1 and power) else Color(0, 0, 0)
	Vehicle._light_mat().emission_energy_multiplier = 3.0 if phase > 0 else 0.5

static func signs() -> StandardMaterial3D:
	if _m.has("signs"):
		return _m["signs"]
	var m := _std("signs", "signs", 0.8, false)
	m.emission_enabled = true
	m.emission_texture = tex("signs")
	m.emission = Color.WHITE
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_energy_multiplier = 0.0
	return m

static func hoardings() -> StandardMaterial3D:
	return _std("hoardings", "hoardings", 0.8, false)

static func road() -> StandardMaterial3D: return _std("road", "road", 0.9)
static func street() -> StandardMaterial3D: return _std("street", "street", 0.95)
static func footpath() -> StandardMaterial3D: return _std("footpath", "footpath", 0.95)
static func ground() -> StandardMaterial3D: return _std("ground", "ground", 1.0)
static func grass() -> StandardMaterial3D: return _std("grass", "grass", 1.0)
static func concrete() -> StandardMaterial3D: return _std("concrete", "concrete", 0.9, true, true)
static func shed() -> StandardMaterial3D: return _std("shed", "shed", 0.7, true, true)

static func puddle() -> StandardMaterial3D:
	if _m.has("puddle"):
		return _m["puddle"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.22, 0.25, 0.0)
	m.roughness = 0.03
	m.metallic_specular = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m["puddle"] = m
	return m

## Blue plastic sheets that vendors pull over their goods when it rains.
static func tarp() -> StandardMaterial3D:
	if _m.has("tarp"):
		return _m["tarp"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.3, 0.7, 0.0)
	m.roughness = 0.35
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m["tarp"] = m
	return m

static func set_rain(r: float) -> void:
	tarp().albedo_color.a = clampf(r * 2.0, 0.0, 1.0)

static func set_wetness(w: float) -> void:
	puddle().albedo_color.a = clampf(w * 1.2, 0.0, 0.8)
	for k in ["road", "street", "footpath"]:
		var m: StandardMaterial3D = _m.get(k)
		if m != null:
			m.roughness = lerpf(0.92, 0.18, w)
			m.metallic_specular = lerpf(0.2, 0.9, w)
			m.albedo_color = Color.WHITE.lerp(Color(0.55, 0.57, 0.62), w)

static func water() -> StandardMaterial3D:
	var m := _std("water", "water", 0.08)
	m.metallic_specular = 0.9
	return m

static func vcol() -> StandardMaterial3D:
	# untextured, vertex-coloured (props, landmark details)
	return _std("vcol", "", 0.85, false, true)

static func col(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var key := "c%s_%.2f_%.2f" % [c.to_html(), rough, metal]
	if _m.has(key):
		return _m[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m[key] = m
	return m

static func skin(c: Color) -> StandardMaterial3D:
	var key := "skin_" + c.to_html()
	if _m.has(key):
		return _m[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = tex("skin")
	m.uv1_scale = Vector3(2, 2, 1)
	m.roughness = 0.6
	m.metallic_specular = 0.35
	_m[key] = m
	return m

static func cloth(pattern: String, c: Color) -> StandardMaterial3D:
	var key := "cl_%s_%s" % [pattern, c.to_html()]
	if _m.has(key):
		return _m[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = tex("cloth_" + pattern)
	m.uv1_scale = Vector3(3, 3, 1)
	m.roughness = 0.95
	_m[key] = m
	return m

## Additive pools of light on the ground: sodium-orange under lamps, tube-light
## white in front of open shops. Driven by set_facade_phase.
static func pool(shop: bool) -> StandardMaterial3D:
	var key := "pool_shop" if shop else "pool_lamp"
	if _m.has(key):
		return _m[key]
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(0, 0, 0, 1))
	g.gradient = gr
	g.width = 64
	g.height = 64
	var m := StandardMaterial3D.new()
	m.albedo_texture = g
	m.albedo_color = Color(0, 0, 0)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	_m[key] = m
	return m

static func head() -> StandardMaterial3D:
	if _m.has("pool_head"):
		return _m["pool_head"]
	var m: StandardMaterial3D = pool(false).duplicate()
	m.albedo_color = Color(0, 0, 0)
	_m["pool_head"] = m
	return m

static func lamp() -> StandardMaterial3D:
	if _m.has("lamp"):
		return _m["lamp"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.88, 0.8)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.72, 0.35)   # sodium vapour
	m.emission_energy_multiplier = 0.0
	_m["lamp"] = m
	return m

static func glow(c: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "g" + c.to_html() + str(energy)
	if _m.has(key):
		return _m[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_m[key] = m
	return m

static func blob() -> StandardMaterial3D:
	if _m.has("blob"):
		return _m["blob"]
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0.5))
	gr.set_color(1, Color(0, 0, 0, 0))
	g.gradient = gr
	g.width = 64
	g.height = 64
	var m := StandardMaterial3D.new()
	m.albedo_texture = g
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m["blob"] = m
	return m
