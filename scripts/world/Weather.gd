class_name Weather
extends Node3D
## Day/night cycle, weather, rain, street-lamp pool and facade lighting phases.

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var rain: CPUParticles3D
var wet := 0.0
var cloud := 0.0          # 0 clear .. 1 overcast
var raining := 0.0
var power := true
var indoors := false
var _phase := -1
var _lamps: Array = []
var _acc := 0.0
var _thunder := 8.0

# hour -> [sky top, horizon, sun colour, sun energy, ambient energy]
const KEYS := [
	[0.0, Color(0.01, 0.015, 0.05), Color(0.04, 0.05, 0.11), Color(0.45, 0.55, 0.9), 0.05, 0.31],
	[4.8, Color(0.02, 0.03, 0.09), Color(0.09, 0.09, 0.17), Color(0.45, 0.55, 0.9), 0.05, 0.31],
	[6.0, Color(0.3, 0.38, 0.58), Color(0.98, 0.66, 0.45), Color(1.0, 0.72, 0.5), 0.4, 0.4],     # dawn: pink sky, long shadows
	[7.5, Color(0.3, 0.5, 0.82), Color(0.86, 0.84, 0.8), Color(1.0, 0.92, 0.78), 0.8, 0.46],    # morning: soft, slightly misty
	[12.5, Color(0.22, 0.44, 0.84), Color(0.74, 0.8, 0.86), Color(1.0, 0.98, 0.93), 1.0, 0.5],  # noon: hard white light
	[16.0, Color(0.26, 0.45, 0.78), Color(0.88, 0.8, 0.66), Color(1.0, 0.88, 0.68), 0.9, 0.48],
	[17.8, Color(0.3, 0.32, 0.56), Color(1.0, 0.56, 0.24), Color(1.0, 0.6, 0.3), 0.6, 0.42],     # golden hour
	[18.7, Color(0.12, 0.1, 0.3), Color(0.62, 0.26, 0.24), Color(0.9, 0.45, 0.35), 0.16, 0.34],  # dusk: purple
	[19.6, Color(0.02, 0.03, 0.1), Color(0.12, 0.08, 0.14), Color(0.45, 0.55, 0.9), 0.05, 0.31],
	[24.0, Color(0.01, 0.015, 0.05), Color(0.04, 0.05, 0.11), Color(0.45, 0.55, 0.9), 0.05, 0.31],
]

func _ready() -> void:
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 8.0
	var sk := Sky_res()
	env.background_mode = Environment.BG_SKY
	env.sky = sk
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_density = 0.0015
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = Game.gfx("shadows")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = maxf(Game.gfx("shadow_dist"), 10.0)
	sun.shadow_bias = 0.06
	sun.shadow_blur = 1.6
	add_child(sun)
	rain = CPUParticles3D.new()
	rain.amount = Game.gfx("rain")
	rain.lifetime = 0.7
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(16, 0.5, 16)
	rain.direction = Vector3(0.1, -1, 0.05)
	rain.spread = 2.0
	rain.gravity = Vector3.ZERO
	rain.initial_velocity_min = 20.0
	rain.initial_velocity_max = 24.0
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.7)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.8, 0.85, 0.95, 0.35)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = rm
	rain.mesh = q
	rain.emitting = false
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)
	for i in int(Game.gfx("lamps")):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.4)
		l.omni_range = 16.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
		_lamps.append(l)

func Sky_res() -> Sky:
	var sk := Sky.new()
	sk.sky_material = sky_mat
	sk.radiance_size = Sky.RADIANCE_SIZE_64
	sk.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	return sk

func is_night(t: float) -> bool:
	return t >= 18.6 or t < 6.0

func update(delta: float, t: float, weather: String, cam_pos: Vector3, lamp_positions: Array) -> void:
	var tc := 1.0 if weather != "clear" else 0.0
	var tr := 1.0 if weather == "rain" else 0.0
	cloud = move_toward(cloud, tc, delta * 0.08)
	raining = move_toward(raining, tr, delta * 0.1)
	wet = move_toward(wet, tr, delta * (0.06 if tr > wet else 0.015))
	rain.emitting = raining > 0.3 and not indoors
	rain.global_position = cam_pos + Vector3(0, 9, 0)
	if raining > 0.5:
		_thunder -= delta
		if _thunder <= 0.0:
			_thunder = randf_range(14.0, 40.0)
			Sfx.play("thunder", 0.7)
	_acc += delta
	if _acc < 0.2:
		return
	_acc = 0.0
	var a = KEYS[0]
	var b = KEYS[1]
	for i in KEYS.size() - 1:
		if t >= KEYS[i][0] and t <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var f := clampf((t - a[0]) / maxf(b[0] - a[0], 0.001), 0.0, 1.0)
	var top: Color = a[1].lerp(b[1], f)
	var hor: Color = a[2].lerp(b[2], f)
	var sc: Color = a[3].lerp(b[3], f)
	var se: float = lerpf(a[4], b[4], f)
	var ae: float = lerpf(a[5], b[5], f)
	var grey := Color(0.42, 0.44, 0.47) * clampf(se + 0.25, 0.1, 1.0)
	top = top.lerp(grey, cloud * 0.85)
	hor = hor.lerp(grey.lightened(0.15), cloud * 0.85)
	se *= lerpf(1.0, 0.45, cloud)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = hor.darkened(0.5)
	var day_f := clampf((t - 6.0) / 12.5, 0.0, 1.0)
	var night := is_night(t)
	if night:
		sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0)   # moonlight
	else:
		sun.rotation = Vector3(-maxf(sin(day_f * PI), 0.12) * 1.15, deg_to_rad(110.0 - day_f * 220.0), 0)
	sun.light_color = sc
	sun.light_energy = 0.0 if indoors else se
	sun.shadow_enabled = Game.gfx("shadows") and not night and cloud < 0.6
	env.ambient_light_color = top.lerp(hor, 0.6).lerp(Color.WHITE, 0.35) if not indoors else Color(1.0, 0.92, 0.8)
	env.ambient_light_energy = ae if not indoors else 0.75
	env.fog_light_color = hor
	var mist := clampf(1.0 - absf(t - 6.6) / 1.6, 0.0, 1.0) * 0.004 + clampf(1.0 - absf(t - 13.0) / 3.0, 0.0, 1.0) * 0.0008
	env.fog_density = lerpf(0.0011 + mist, 0.009, maxf(raining, cloud * 0.3))
	Mats.set_wetness(wet)
	var ph := 0
	if t >= 21.5 or t < 6.0:
		ph = 2
	elif t >= 18.2:
		ph = 1
	if ph != _phase or true:   # cheap; also re-applies after a power cut
		_phase = ph
		Mats.set_facade_phase(ph, power)
	# street-lamp light pool: attach real lights to the nearest lamp heads
	var lit := ph > 0 and power and not indoors
	if lit and not lamp_positions.is_empty():
		lamp_positions.sort_custom(func(p, q2): return p.distance_squared_to(cam_pos) < q2.distance_squared_to(cam_pos))
	for i in _lamps.size():
		var l: OmniLight3D = _lamps[i]
		if lit and i < lamp_positions.size():
			l.global_position = lamp_positions[i] + Vector3(0, -0.4, 0)
			l.light_energy = 2.2
		else:
			l.light_energy = 0.0
