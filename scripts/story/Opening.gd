class_name Opening
extends Node
## BIG BANG LORE - the opening sequence. Monday, 1 January 2007.
## M.S. Laliah Institute of Technology: a film unit, an empty reel, a superstar
## under an umbrella, a crowd, and two men who see each other.
##
## One director coroutine (run) walks the shot list in the order the brief fixes.
## Everything happens in the live streamed city, with the player's own Raja body:
## when the cinematic camera hands over, the player is already standing in the crowd.

signal beat(name: String)          # for automated capture: one per shot

const BOUNDS := Rect2(-27, 13, 54, 25)     # where the player may roam in the crowd (campus frame, x/z)

var world
var pl: Player
var hud: HUD
var root: Node3D                  # everything this scene adds to the world
var cam: Camera3D
var raja: Human
var cast := {}                    # id -> Human
var crowd: Array = []             # {h, home, side, mode, t, goal, act_t}
var movers := {}                  # Human -> {to: Vector3, spd: float, node: Node3D}
var vmovers := {}                 # Vehicle -> {pts: Array, i: int, spd: float}
var rng := RandomNumberGenerator.new()
var base_ts := 1.0
var phase := ""                   # shot name, for tests
var player_free := false
var _cam_fn := Callable()
var _cam_t := 0.0
var _shake := 0.0
var _sweat: MeshInstance3D = null
var _sweat_t := -1.0
var _skip := false
var _punch_hit := false
var _choice := -1
var _centre := Vector3.ZERO
var _dust: CPUParticles3D = null
var _siren: AudioStreamPlayer3D = null
var _beacon_m: MeshInstance3D = null
# ---- UI
var ui: CanvasLayer
var _sub: PanelContainer
var _sub_name: Label
var _sub_orig: Label
var _sub_eng: Label
var _sub_tw: Tween = null
var _black: ColorRect
var _flash: ColorRect
var _card: Control
var _split: Control = null
var _split_cams: Array = []
var _prompt: Button = null
var _choices: VBoxContainer = null
var _skip_btn: Button = null
var whistle_frame := -1
var rajini_front_frames := 0      # test hook: frames in which the camera saw his face from the front
var black_frame := -1

# ================================================================== helpers
static func L(x: float, y: float, z: float) -> Vector3:
	return Campus.world(Vector3(x, y, z))

static func yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)

func _node(h: Human) -> Node3D:
	return pl if h == raja else h

func pos_of(h: Human) -> Vector3:
	return _node(h).global_position

## Between the eyes, from the animated skeleton (so it follows a turned head, a stoop, a seat).
func head_of(h: Human) -> Vector3:
	if h.skel != null:
		var el := h.skel.find_bone("eye_l")
		var er := h.skel.find_bone("eye_r")
		if el >= 0 and er >= 0:
			var g := h.skel.global_transform
			var hp := (g * h.skel.get_bone_global_pose(el).origin + g * h.skel.get_bone_global_pose(er).origin) * 0.5
			# right after a body is placed its pose can still be stale for a frame or two;
			# trust it only if it is near where the head should be
			var est := pos_of(h) + Vector3(0, float(Human.manifest.get(h.model, {}).get("eye_y", 1.6)), 0)
			if h.state in ["idle", "talk"] and hp.distance_to(est) > 0.35:
				return est
			return hp
	return pos_of(h) + Vector3(0, float(Human.manifest.get(h.model, {}).get("eye_y", 1.6)), 0)

## Which way the face points (the head bone's -Z).
func face_dir(h: Human) -> Vector3:
	var f := -h.global_transform.basis.z
	f.y = 0.0
	return f.normalized()

func put(h: Human, p: Vector3, face_to = null) -> void:
	_node(h).global_position = p
	if face_to != null:
		h.rotation.y = yaw_to(p, face_to)
	movers.erase(h)
	h.speed = 0.0

func face(h: Human, p: Vector3) -> void:
	h.rotation.y = yaw_to(pos_of(h), p)

func go(h: Human, to: Vector3, spd := 1.45, turn := true) -> void:
	movers[h] = {"to": to, "spd": spd, "turn": turn}

func arrived(h: Human) -> bool:
	return not movers.has(h)

func _arrive(h: Human, timeout := 30.0) -> void:
	var t := 0.0
	while movers.has(h) and t < timeout and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
	if _skip and movers.has(h):
		put(h, movers[h].to)

func _w(t: float) -> void:
	if _skip:
		await get_tree().process_frame
		return
	await get_tree().create_timer(t, false, false, false).timeout

func _real(t: float) -> void:
	if _skip:
		await get_tree().process_frame
		return
	await get_tree().create_timer(t, false, false, true).timeout

func slow(scale: float) -> void:
	Engine.time_scale = scale * base_ts

func shot(name: String, fn: Callable) -> void:
	phase = name
	_cam_fn = fn
	_cam_t = 0.0
	_shake = 0.0
	_apply_cam(0.0)
	beat.emit(name)

func _apply_cam(dt: float) -> void:
	if _cam_fn.is_valid():
		_cam_fn.call(_cam_t, dt)

## Point the cinematic camera.
func aim(p: Vector3, look: Vector3, fov := 50.0) -> void:
	cam.fov = fov
	cam.global_position = p
	if not p.is_equal_approx(look):
		cam.look_at(look, Vector3.UP)

static func ease_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

static func cr(p: Array, t: float) -> Vector3:
	var n := p.size() - 1
	var f := clampf(t, 0.0, 1.0) * n
	var i := mini(int(f), n - 1)
	var u := f - i
	var p0: Vector3 = p[maxi(i - 1, 0)]
	var p1: Vector3 = p[i]
	var p2: Vector3 = p[i + 1]
	var p3: Vector3 = p[mini(i + 2, n)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)

# ================================================================== cast
func spawn(id: String, look: Dictionary, at: Vector3, face_to = null, lod := 2) -> Human:
	var h := Human.make(look, lod)
	root.add_child(h)
	h.global_position = at
	if face_to != null:
		h.rotation.y = yaw_to(at, face_to)
	if id != "":
		cast[id] = h
	return h

## Frames worn on the face, fitted to the eye bones (sunglasses, or clear spectacles).
func spectacles(h: Human, dark: bool) -> void:
	if h.skel == null:
		return
	var ib := h.skel.find_bone("head")
	var el := h.skel.find_bone("eye_l")
	var er := h.skel.find_bone("eye_r")
	if ib < 0 or el < 0 or er < 0:
		return
	var hp := h.skel.get_bone_global_rest(ib).origin
	var pl_ := h.skel.get_bone_global_rest(el).origin
	var pr_ := h.skel.get_bone_global_rest(er).origin
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	h.skel.add_child(att)
	var g := Node3D.new()
	att.add_child(g)
	var frame_m := Mats.col(Color(0.04, 0.04, 0.045), 0.3, 0.6)
	var lens_m := StandardMaterial3D.new()
	lens_m.albedo_color = Color(0.03, 0.035, 0.04, 0.92) if dark else Color(0.8, 0.85, 0.9, 0.18)
	lens_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lens_m.roughness = 0.05
	lens_m.metallic_specular = 1.0
	var zf := -0.028        # in front of the eyeballs (the model faces -Z)
	for e: Vector3 in [pl_, pr_]:
		var lens := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.038 if dark else 0.032, 0.004)
		lens.mesh = bm
		lens.material_override = lens_m
		lens.position = e - hp + Vector3(0, -0.003, zf)
		g.add_child(lens)
		var rim := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.054, 0.006 if not dark else 0.009, 0.006)
		rim.mesh = rb
		rim.material_override = frame_m
		rim.position = lens.position + Vector3(0, 0.019 if dark else 0.016, 0)
		g.add_child(rim)
		var arm := MeshInstance3D.new()
		var ab := BoxMesh.new()
		ab.size = Vector3(0.004, 0.005, 0.11)
		arm.mesh = ab
		arm.material_override = frame_m
		arm.position = e - hp + Vector3(signf(e.x - hp.x) * 0.034, 0.012, zf + 0.055)
		arm.rotation.y = signf(e.x - hp.x) * 0.12
		g.add_child(arm)
	var br := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(absf(pl_.x - pr_.x) - 0.045, 0.005, 0.005)
	br.mesh = bb
	br.material_override = frame_m
	br.position = (pl_ + pr_) * 0.5 - hp + Vector3(0, 0.01, zf)
	g.add_child(br)

## A bead of sweat at Lal's temple, to run down his face in the split screen.
func sweat(h: Human) -> void:
	var ib := h.skel.find_bone("head")
	var er := h.skel.find_bone("eye_r")
	var hp := h.skel.get_bone_global_rest(ib).origin
	var ep := h.skel.get_bone_global_rest(er).origin
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	h.skel.add_child(att)
	_sweat = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.0042
	sm.height = 0.011
	sm.radial_segments = 10
	sm.rings = 6
	_sweat.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.9, 0.95, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.0
	m.metallic_specular = 1.0
	m.rim_enabled = true
	m.rim = 1.0
	_sweat.material_override = m
	_sweat.set_meta("top", ep - hp + Vector3(signf(ep.x - hp.x) * 0.018, 0.055, -0.035))
	_sweat.set_meta("bottom", ep - hp + Vector3(signf(ep.x - hp.x) * 0.026, -0.06, -0.045))
	_sweat.position = _sweat.get_meta("top")
	_sweat.visible = false
	att.add_child(_sweat)

func _look(sex: int, job: String) -> Dictionary:
	var l := Human.random_look(rng, sex, job)
	l.acc = 0 if job != "student" else l.acc
	return l

func _build_cast() -> void:
	raja = pl.human
	cast["raja"] = raja
	raja.walk = [1.12, 0.7, 1.25, 0.04]           # long, quick stride; arms swing; leans into it
	var rc := L(16.0, 0, 57.0)
	# seated facing into the campus: from the crowd, the gate and the unit he is a back and a pair of shades
	var rajini := spawn("rajini", {"model": "rajini", "acc": 0, "top": 11}, rc + Campus.frame().basis * Vector3(0, 0, -0.08), L(16, 0, 80))
	rajini.state = "sit"
	rajini.seat_lift = 0.07
	spectacles(rajini, true)
	var sh := spawn("shankar", {"model": "shankar", "acc": 0, "top": 1}, L(-13.9, 0, 53.4), L(-12.2, 0, 53.9))
	spawn("kvanand", {"model": "kvanand", "acc": 0}, L(-12.2, 0, 53.9), L(-13.9, 0, 53.4))
	var ad := spawn("ad", {"model": "ad", "acc": 0, "pat": {"shirt_out": "check"}}, L(-7.2, 0, 45.0), L(-3, 0, 40))
	ad.walk = [1.05, 0.8, 1.1, 0.03]
	var crew_l := _look(0, "mechanic")
	crew_l.age = 0.3
	crew_l.top = 4
	crew_l.top_col = 8
	var crew := spawn("crew", crew_l, L(16.0, 0, -6.0), L(0, 0, -4), 1)
	crew.walk = [0.95, 1.1, 0.9, 0.06]
	var uma := spawn("uma", {"model": "umashankar", "acc": 0, "pat": {"shirt_out": "check"}}, L(-4.0, 0, 26.0), L(2, 0, 36))
	uma.walk = [0.9, 1.25, 0.8, -0.02]                # rolling, unhurried
	# Lal is not in the crowd: he arrives later, on his own (scene 6)
	var lal := spawn("lal", {"model": "lal", "acc": 0}, L(40.0, 0, -14.0), L(0, 0, -14))
	lal.walk = [0.92, 0.55, 0.6, -0.05]              # deliberate, chest out, arms quiet
	lal.visible = false
	sweat(lal)
	var fl := _look(0, "")
	fl.age = 0.26
	fl.top = 3
	var lf := spawn("lal_friend", fl, L(42.0, 0, -14.0), L(0, 0, -14), 1)
	lf.visible = false
	var f2 := _look(0, "")
	f2.age = 0.24
	f2.top = 4
	f2.top_col = 3
	spawn("raja_friend", f2, L(-1.5, 0, 33.5), L(2, 0, 38), 1)
	for i in 3:
		var sl := _look(0, "")
		sl.top = 4
		sl.top_col = 8
		sl.bottom = 0
		sl.bot_col = 8
		sl.build = 0.8
		sl.age = 0.35
		spawn("security%d" % i, sl, L(-6.0 + i * 6.0, 0, 40.2), L(-6.0 + i * 6.0, 0, 30), 1)
	# the crowd: fans pressed up to the rope, students, people off the road
	var n: int = [26, 40, 56][clampi(int(Game.settings.gfx), 0, 2)]
	for i in n:
		var sex := 1 if rng.randf() < 0.18 else 0
		var job: String = "student" if rng.randf() < 0.45 else ["", "office", "vendor", "mechanic", "shopper"][rng.randi() % 5]
		var lk := _look(sex, job)
		var row := float(i % 4)
		var x := rng.randf_range(-26.0, 26.0)
		if absf(x - 3.5) < 2.2 and row < 1.0:
			x += 5.0 * signf(x - 3.5 + 0.01)
		var home := L(x, 0, 37.2 - row * 1.25 - rng.randf_range(0.0, 1.6) - (5.0 if i > n * 0.8 else 0.0))
		var h := spawn("", lk, home, L(x * 0.4, 0, 60.0), 1)
		h.activity = ["cheer", "", "wave_star", "", "crossed", "cheer"][rng.randi() % 6]
		crowd.append({"h": h, "home": home, "side": -1 if x < 3.0 else 1, "mode": "watch", "t": rng.randf() * 3.0, "goal": home, "act_t": rng.randf_range(1.0, 5.0)})
	# medical students from the college next door, in their white coats, stethoscopes round their
	# necks: one knot at the rope near the star, one on the porch steps, two at the canteen
	var groups := [[L(19.0, 0, 35.2), 7], [L(1.0, 0, 85.0), 5], [L(60.0, 0, 15.0), 3]]
	for g in groups:
		var gc: Vector3 = g[0]
		for i in int(g[1]):
			var sex := 1 if rng.randf() < 0.45 else 0
			var lk2 := _look(sex, "student")
			lk2["labcoat"] = true
			lk2["steth"] = rng.randf() < 0.7
			lk2.acc = 0
			var ang := TAU * i / float(g[1]) + rng.randf_range(-0.3, 0.3)
			var p := gc + Campus.frame().basis * Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.7, 1.3)
			var h2 := spawn("", lk2, p, gc, 1)
			h2.activity = ["listen", "", "laugh", "crossed", "phone"][i % 5]
			crowd.append({"h": h2, "home": p, "side": 1, "mode": "med", "t": rng.randf() * 4.0, "goal": gc, "act_t": rng.randf_range(1.0, 4.0), "med": true})

# ================================================================== setup / UI
func _setup() -> void:
	pl = world.player
	hud = world.hud
	rng.seed = 20070101
	if OS.get_cmdline_user_args().has("--fast"):
		base_ts = 4.0
	Engine.time_scale = base_ts
	root = Node3D.new()
	root.name = "OpeningSet"
	world.add_child(root)
	cam = Camera3D.new()
	cam.near = 0.02
	cam.far = 1600.0
	world.add_child(cam)
	cam.make_current()
	world.busy = true
	world.story.clock_runs = false
	world._weather_t = 99999.0
	Game.s.time = 10.4
	Game.s.weather = "clear"
	pl.puppet = true
	pl.locked = true
	pl.cam_override = true
	hud.letterbox(true)
	_build_ui()
	_build_cast()

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 40
	add_child(ui)
	_black = UI.rect(Color.BLACK)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_black)
	_flash = UI.rect(Color(1, 1, 1, 0))
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_flash)
	_sub = PanelContainer.new()
	_sub.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.0), 6, 0, Color(0, 0, 0, 0), 10))
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_sub.offset_left = -560
	_sub.offset_right = 560
	_sub.offset_top = -190
	_sub.offset_bottom = -96
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.modulate.a = 0.0
	ui.add_child(_sub)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_END
	vb.add_theme_constant_override("separation", 2)
	_sub.add_child(vb)
	_sub_name = UI.label("", 17, UI.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_sub_orig = UI.label("", 21, Color(0.85, 0.85, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	_sub_eng = UI.label("", 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	for l: Label in [_sub_name, _sub_orig, _sub_eng]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		vb.add_child(l)
	if bool(Game.settings.get("opening_seen", false)):
		_skip_btn = UI.button("Skip opening", 16)
		_skip_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_skip_btn.offset_left = -190
		_skip_btn.offset_top = 96
		_skip_btn.offset_right = -20
		_skip_btn.modulate.a = 0.6
		_skip_btn.pressed.connect(func():
			_skip = true
			_skip_btn.visible = false)
		ui.add_child(_skip_btn)

## A line of dialogue: who, what they said (as said), and what it means.
func line(h: Human, who: String, orig: String, eng: String, dur := 2.8) -> void:
	if h != null:
		h.talk_t = dur * 0.85
	_sub_name.text = who.to_upper()
	_sub_orig.text = orig
	_sub_orig.visible = orig != "" and orig != eng
	_sub_eng.text = eng
	if _sub_tw != null:
		_sub_tw.kill()
	_sub.modulate.a = 1.0 if Game.settings.subtitles or orig != "" else 0.0
	_sub_tw = _sub.create_tween()
	_sub_tw.tween_interval(dur)
	_sub_tw.tween_property(_sub, "modulate:a", 0.0, 0.3)
	Sfx.play("blip", 0.12, randf_range(0.9, 1.1))

func clear_line() -> void:
	if _sub_tw != null:
		_sub_tw.kill()
	_sub.modulate.a = 0.0

func fade_black(to: float, dur: float) -> void:
	var tw := _black.create_tween()
	tw.tween_property(_black, "color:a", to, dur)
	await tw.finished

func flash() -> void:
	_flash.color.a = 0.9
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.22)

func date_card() -> void:
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_card.offset_left = 70
	_card.offset_top = -250
	ui.add_child(_card)
	var a := UI.label("BENGALURU", 54, UI.YELLOW)
	a.add_theme_font_override("font", UI.title_font())
	a.add_theme_constant_override("outline_size", 6)
	a.add_theme_color_override("font_outline_color", Color.BLACK)
	_card.add_child(a)
	var b := UI.label("", 22, Color(0.95, 0.95, 0.92))
	b.position = Vector2(4, 70)
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_card.add_child(b)
	_card.modulate.a = 0.0
	var tw := _card.create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 1.2)
	var full := "MONDAY, 1 JANUARY 2007"
	for i in full.length() + 1:
		b.text = full.substr(0, i)
		if i < full.length() and full[i] != " ":
			Sfx.play("click", 0.08, 1.6)
		await _real(0.06)
	await _w(4.5)
	var tw2 := _card.create_tween()
	tw2.tween_property(_card, "modulate:a", 0.0, 1.0)

# ================================================================== frame
func _process(delta: float) -> void:
	if root == null:
		return
	_cam_t += delta
	# walking / running people
	for h: Human in movers.keys():
		if not is_instance_valid(h):
			movers.erase(h)
			continue
		var m: Dictionary = movers[h]
		var nd := _node(h)
		var to: Vector3 = m.to
		var d := Vector3(to.x - nd.global_position.x, 0, to.z - nd.global_position.z)
		var dist := d.length()
		var spd: float = m.spd
		if dist < maxf(0.06, spd * delta * 1.2):
			nd.global_position = Vector3(to.x, nd.global_position.y, to.z)
			h.speed = 0.0
			movers.erase(h)
			continue
		var dir := d / dist
		nd.global_position += dir * minf(spd * delta, dist)
		if bool(m.get("turn", true)):
			h.rotation.y = lerp_angle(h.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-10.0 * delta))
			h.speed = spd
	for v: Vehicle in vmovers.keys():
		if not is_instance_valid(v):
			vmovers.erase(v)
			continue
		var vm: Dictionary = vmovers[v]
		var pts: Array = vm.pts
		var i: int = vm.i
		if i >= pts.size():
			v.v = move_toward(v.v, 0.0, delta * 6.0)
			continue
		var tgt: Vector3 = pts[i]
		var dv := Vector3(tgt.x - v.global_position.x, 0, tgt.z - v.global_position.z)
		var dl := dv.length()
		var want: float = vm.spd if i < pts.size() - 1 else minf(float(vm.spd), dl * 1.2 + 0.4)
		v.v = move_toward(v.v, want, delta * 5.0)
		if dl < maxf(0.5, v.v * delta * 2.0):
			vm.i = i + 1
		else:
			var dn := dv / dl
			v.global_position += dn * v.v * delta
			v.rotation.y = lerp_angle(v.rotation.y, atan2(-dn.x, -dn.z), 1.0 - exp(-4.0 * delta))
	_crowd_tick(delta)
	_separate(delta)
	if _beacon_m != null:
		_beacon_m.visible = fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.3
	if _sweat != null and _sweat_t >= 0.0:
		_sweat_t += delta / maxf(Engine.time_scale, 0.05)
		var k := clampf(_sweat_t / 3.2, 0.0, 1.0)
		var top: Vector3 = _sweat.get_meta("top")
		var bot: Vector3 = _sweat.get_meta("bottom")
		_sweat.position = top.lerp(bot, k * k * (3.0 - 2.0 * k))
		_sweat.scale = Vector3(1, 1.0 + k * 0.6, 1)
	if player_free:
		_bound_player()
	_apply_cam(delta)
	_watch_rajini()
	if _shake > 0.0:
		var real := delta / maxf(Engine.time_scale, 0.05)
		var tt := Time.get_ticks_msec() / 1000.0
		cam.rotate_object_local(Vector3.RIGHT, sin(tt * 37.0) * _shake * 0.02)
		cam.rotate_object_local(Vector3.UP, sin(tt * 29.0 + 1.0) * _shake * 0.025)
		cam.global_position += Vector3(sin(tt * 23.0), sin(tt * 31.0), 0) * _shake * 0.02
		_shake = maxf(0.0, _shake - real * 0.0)

## People do not pass through each other: every standing body keeps a personal radius,
## and the one that is moving gives way. Pairs in deliberate contact (a push, a grip) use
## a smaller radius so hands can land.
func _separate(_delta: float) -> void:
	var bodies: Array = []
	for c in crowd:
		bodies.append(c.h)
	for id in ["raja", "uma", "raja_friend", "lal", "lal_friend", "ad", "crew", "security0", "security1", "security2", "cop0", "cop1", "cop2"]:
		if cast.has(id) and is_instance_valid(cast[id]) and (cast[id] as Human).visible:
			bodies.append(cast[id])
	var n := bodies.size()
	for i in n:
		var a: Human = bodies[i]
		if a.state in ["sit", "drive"] or a.get_parent() != root and a != raja:
			continue
		var pa := pos_of(a)
		for j in range(i + 1, n):
			var b: Human = bodies[j]
			if b.state in ["sit", "drive"] or b.get_parent() != root and b != raja:
				continue
			var pb := pos_of(b)
			var d := Vector2(pb.x - pa.x, pb.z - pa.z)
			var dist := d.length()
			var want := 0.34 if (a.activity in ["hold", "push"] or b.activity in ["hold", "push"] or a.state == "fall" or b.state == "fall") else 0.52
			if dist < want and dist > 0.001:
				var push := (want - dist) * 0.5
				var dn := d / dist
				var wa := 0.5 if a != raja else 0.0
				var wb := 0.5 if b != raja else 0.0
				if wa + wb == 0.0:
					continue
				var tot := wa + wb
				_node(a).global_position -= Vector3(dn.x, 0, dn.y) * push * 2.0 * wa / tot
				_node(b).global_position += Vector3(dn.x, 0, dn.y) * push * 2.0 * wb / tot
				pa = pos_of(a)

## The opening must never show Rajinikanth's face from the front. Every frame, check whether the
## active camera is in front of him, near enough to read a face, with his head in view.
func _watch_rajini() -> void:
	if not cast.has("rajini"):
		return
	var rj: Human = cast["rajini"]
	if not rj.visible:
		return
	var c := get_viewport().get_camera_3d()
	if c == null:
		return
	var hp := head_of(rj)
	var to_cam := c.global_position - hp
	var fwd := -rj.global_transform.basis.z
	to_cam.y = 0
	if to_cam.length() < 30.0 and to_cam.normalized().dot(fwd) > 0.25 and c.is_position_in_frustum(hp):
		rajini_front_frames += 1

func _bound_player() -> void:
	var lp: Vector3 = Campus.frame().affine_inverse() * pl.global_position
	var c := Vector3(clampf(lp.x, BOUNDS.position.x, BOUNDS.end.x), 0, clampf(lp.z, BOUNDS.position.y, BOUNDS.end.y))
	if not c.is_equal_approx(Vector3(lp.x, 0, lp.z)):
		pl.global_position = Campus.frame() * c
		if lp.z > BOUNDS.end.y + 0.05 and not _sub.modulate.a > 0.5:
			line(cast["security1"], "Security", "Ey! Line hinde nillu!", "Hey! Stay behind the line!", 2.0)

func _crowd_tick(delta: float) -> void:
	var rc: Vector3 = head_of(cast["rajini"]) if cast.has("rajini") else L(16, 1.5, 57)
	for c in crowd:
		var h: Human = c.h
		c.t = float(c.t) + delta
		match str(c.mode):
			"watch":
				h.look_target = rc
				c.act_t = float(c.act_t) - delta
				if float(c.act_t) <= 0.0:
					c.act_t = rng.randf_range(2.0, 6.0)
					h.activity = ["cheer", "", "wave_star", "cheer", "crossed", ""][rng.randi() % 6]
			"med":
				# a knot of friends: they talk among themselves, turn to watch the star, laugh
				c.act_t = float(c.act_t) - delta
				if float(c.act_t) <= 0.0:
					c.act_t = rng.randf_range(2.0, 5.0)
					var r := rng.randf()
					if r < 0.4:
						h.look_target = (c.goal as Vector3) + Vector3(0, 1.5, 0)
						h.talk_t = rng.randf_range(1.2, 2.6)
						h.activity = ""
					elif r < 0.75:
						h.look_target = rc
						h.activity = ["listen", "crossed", ""][rng.randi() % 3]
					else:
						h.activity = "laugh"
			"react":
				h.look_target = _centre + Vector3(0, 1.5, 0)
				h.mood = "surprise"
			"surge":
				h.activity = ""
				h.mood = "scream" if rng.randf() < 0.02 else h.mood
				if arrived(h):
					c.mode = "brawl"
					c.act_t = 0.0
			"brawl":
				h.look_target = _centre + Vector3(0, 1.5, 0)
				c.act_t = float(c.act_t) - delta
				if float(c.act_t) <= 0.0:
					c.act_t = rng.randf_range(0.8, 2.0)
					h.activity = ["hold", "argue", "hold", "shout", ""][rng.randi() % 5]
					h.mood = ["angry", "scream", "surprise", "angry"][rng.randi() % 4]
					if rng.randf() < 0.35:
						h.play_once("push", 0.5)
					if rng.randf() < 0.5:
						var off := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * 1.4
						go(h, pos_of(h) + off, 2.4)
			"part":
				h.look_target = _centre + Vector3(0, 1.5, 0)
				if arrived(h):
					h.activity = ["argue", "crossed", "listen", ""][rng.randi() % 4]
					h.mood = ""
					c.mode = "after"

# ================================================================== the sequence
func run() -> void:
	_setup()
	# --- a word before the picture ---
	Sfx.ambience({})
	world.story.amb_override = {"amb_city": 0.0}
	var disc := UI.label("This is a work of fiction.\nReal public figures appear in a fictionalised, alternate-history context.\nThe film shoot shown here is invented for this story.", 19, Color(0.75, 0.75, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	disc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	disc.offset_left = -520
	disc.offset_right = 520
	disc.offset_top = -50
	disc.offset_bottom = 50
	disc.modulate.a = 0.0
	ui.add_child(disc)
	var tw := disc.create_tween()
	tw.tween_property(disc, "modulate:a", 1.0, 0.8)
	# the aerial needs the city around the campus built before the first frame
	world.chunk_bonus = 3
	world._want_chunks(true)
	world.weather.haze = 0.0011
	world.weather.shadow_reach = 70.0
	await _real(4.0)
	var tw2 := disc.create_tween()
	tw2.tween_property(disc, "modulate:a", 0.0, 0.6)
	await _real(0.8)
	disc.queue_free()
	await _s1_aerial()
	await _s2_reel()
	await _s3_rajini()
	await _s4_crowd()
	await _s5_control()
	await _s6_entrance()
	await _s7_confrontation()
	await _s8_police()
	await _s9_separate()
	await _s10_questions()
	await _s11_title()

# ---------------------------------------------------------------- 1. Bengaluru, 1 January 2007
func _s1_aerial() -> void:
	world.story.amb_override = {"amb_city": 0.55}
	# an eagle's view straight down on the city, levelling out as it drops to the gate
	var path := [L(-150, 330, -300), L(-95, 200, -185), L(-34, 92, -76), L(-12, 32, -32), L(-4, 6.0, -15), L(2.5, 2.0, -7.5)]
	var looks := [L(-125, 0, -230), L(-55, 0, -95), L(0, 0, 18), L(0, 2, 22), L(0, 3, 9), L(2.0, 1.4, 1.0)]
	var dur := 17.0
	shot("aerial", func(t: float, _dt: float):
		var k := t / dur
		k = k * k * (3.0 - 2.0 * k) * 0.35 + k * 0.65
		aim(cr(path, k), cr(looks, k), lerpf(55.0, 46.0, k)))
	fade_black(0.0, 2.5)
	date_card()
	await _w(11.0)
	# the crew man comes along the footpath to the gate
	var crew: Human = cast["crew"]
	go(crew, L(1.6, 0, -2.8), 1.5)
	world.weather.haze = 0.0
	await _w(dur - 11.0)

# ---------------------------------------------------------------- 2. the empty reel
func _s2_reel() -> void:
	var crew: Human = cast["crew"]
	world.chunk_bonus = 0
	world.story.amb_override = {"amb_city": 0.4, "amb_crowd": 0.25}
	# one continuous move: the camera falls in behind him as he turns in at the gate
	var start_p := cam.global_position
	var start_l := L(2.0, 1.4, 1.0)
	await _arrive(crew, 6.0)
	go(crew, L(0.6, 0, 6.0), 1.5)
	shot("walk_in", func(t: float, _dt: float):
		var cp := pos_of(crew)
		var fwd := Campus.frame().basis * Vector3(0, 0, 1)
		var rt := Campus.frame().basis * Vector3(1, 0, 0)
		var want := cp - fwd * lerpf(2.4, 3.6, ease_io(t / 6.0)) + rt * 0.75 + Vector3(0, lerpf(1.7, 2.5, ease_io(t / 6.0)), 0)
		var look := cp + fwd * 6.0 + Vector3(0, lerpf(1.5, 1.2, ease_io(t / 6.0)), 0)
		var b := ease_io(t / 1.4)
		aim(start_p.lerp(want, b), start_l.lerp(look, b), 50.0))
	await _arrive(crew, 6.0)
	go(crew, L(-0.6, 0, 16.0), 1.55)
	await _w(3.2)
	# cut: he reaches the assistant director at the rope line
	var ad: Human = cast["ad"]
	put(crew, L(-10.4, 0, 48.0), L(-7.2, 1.4, 45.0))
	go(crew, L(-8.3, 0, 46.0), 1.4)
	ad.activity = "crossed"
	ad.look_target = head_of(crew)
	world.story.amb_override = {"amb_city": 0.25, "amb_crowd": 0.5}
	shot("reel_news", func(t: float, _dt: float):
		var mid := (pos_of(crew) + pos_of(ad)) * 0.5
		var side := Campus.frame().basis * Vector3(-0.55, 0, -1).normalized()
		aim(mid + side * 5.4 + Vector3(0, 1.6, 0) + Campus.frame().basis * Vector3(t * 0.04, 0, 0), mid + Vector3(0, 1.35, 0), 36.0))
	await _arrive(crew, 3.0)
	face(crew, pos_of(ad))
	face(ad, pos_of(crew))
	crew.look_target = head_of(ad)
	crew.mood = "nervous"
	line(crew, "Unit boy", "Sir... reel kaali aayiduchu. Innikki vera reel kidaiyaadhu. Naalaikki thaan varum.", "Sir... the reel's finished. There's no other reel today. It'll only come tomorrow.", 4.2)
	await _w(4.3)
	ad.activity = ""
	ad.mood = "frustrated"
	ad.play_once("facepalm", 1.6)
	line(ad, "Assistant director", "Enna?! ...Ippo vandhu solriya idha?", "What?! You come and tell me this now?", 2.6)
	await _w(2.4)
	# he goes to the director
	var sh: Human = cast["shankar"]
	var an: Human = cast["kvanand"]
	sh.talk_t = 9.0
	sh.look_target = head_of(an)
	an.look_target = head_of(sh)
	go(ad, L(-12.4, 0, 52.2), 1.6)
	ad.look_target = null
	shot("to_director", func(t: float, _dt: float):
		var p := L(-19.0, 1.62, 48.2) + Campus.frame().basis * Vector3(t * 0.12, 0, 0)
		var grp := (pos_of(sh) + pos_of(an)) * 0.5
		aim(p, grp.lerp(pos_of(ad), 0.25) + Vector3(0, 1.4, 0), 40.0))
	await _arrive(ad, 6.0)
	face(ad, pos_of(sh))
	ad.look_target = head_of(sh)
	an.talk_t = 0.0
	sh.talk_t = 0.0
	sh.look_target = head_of(ad)
	an.look_target = head_of(ad)
	line(ad, "Assistant director", "Sir... reel illa sir. Naalaikki thaan varumaam.", "Sir... there's no reel, sir. Apparently it'll only come tomorrow.", 3.4)
	await _w(3.4)
	shot("inform_sir", func(t: float, _dt: float):
		var hp := head_of(sh)
		var fw := (head_of(ad) - hp).normalized()
		aim(hp + fw * 1.25 + Vector3(0, 0.05, 0) + fw.cross(Vector3.UP) * 0.55 + Vector3(0, t * 0.01, 0), hp - Vector3(0, 0.08, 0), 30.0))
	sh.play_once("sigh", 2.2)
	Sfx.play("hiss", 0.05, 0.6)
	await _w(2.3)
	sh.look_target = head_of(cast["rajini"])
	await _w(0.35)
	sh.look_target = head_of(ad)
	sh.play_once("point_small", 1.2)
	line(sh, "Shankar", "", "Inform sir.", 2.0)
	await _w(1.9)

# ---------------------------------------------------------------- 3. Rajinikanth
func _s3_rajini() -> void:
	var ad: Human = cast["ad"]
	var rj: Human = cast["rajini"]
	var rpos := pos_of(rj)
	var B := Campus.frame().basis
	# the AD comes round to face him (in front of the chair); the camera never goes in front:
	# a wide from behind, then one move in to over his left shoulder
	put(ad, L(9.0, 0, 62.5), rpos)
	go(ad, rpos + B * Vector3(-1.6, 0, 1.6), 1.45)
	ad.look_target = null
	ad.mood = ""
	world.story.amb_override = {"amb_city": 0.2, "amb_crowd": 0.35}
	var c0 := L(25.0, 2.3, 43.0)
	var l0 := L(14.0, 1.2, 63.0)
	var ots := rpos + B * Vector3(0.16, 1.3, -1.05)          # just behind his left shoulder
	var ots_look := rpos + B * Vector3(-0.6, 1.22, 1.0)
	shot("rajini_approach", func(t: float, _dt: float):
		var k := ease_io(t / 6.5)
		var mid := rpos + B * Vector3(3.5, 2.2, -6.0)
		var p := c0.lerp(mid, k).lerp(mid.lerp(ots, k), k)
		aim(p, l0.lerp(ots_look, k), lerpf(40.0, 46.0, k)))
	await _arrive(ad, 7.0)
	go(ad, rpos + B * Vector3(-0.78, 0, 0.88), 1.1)
	await _arrive(ad, 5.0)
	face(ad, rpos)
	ad.activity = "bend"
	ad.look_target = head_of(rj) + Vector3(0, -0.45, 0)
	rj.look_target = head_of(ad) + Vector3(0, -0.4, 0)
	shot("rajini_ots", func(t: float, _dt: float):
		aim(ots + B * Vector3(-t * 0.015, -t * 0.006, 0), ots_look, 46.0))
	await _w(1.4)
	line(ad, "Assistant director", "", "Sir, pack up. We didn't get reel.", 2.8)
	await _w(3.0)
	rj.play_once("nod_slow", 1.5)
	await _w(1.0)
	rj.mood = "smile"
	rj.play_once("calm", 1.4)
	await _w(1.6)
	rj.mood = ""
	rj.look_target = null

# ---------------------------------------------------------------- 4. the crowd, and Raja goes down
func _s4_crowd() -> void:
	var ad: Human = cast["ad"]
	var B := Campus.frame().basis
	ad.activity = ""
	ad.look_target = null
	ad.mood = "angry"
	# Raja is pressed up against the rope, as close as anyone can get
	put(raja, L(3.2, 0, 37.9), L(16, 1.6, 57))
	raja.state = "idle"
	raja.activity = "cheer"
	raja.mood = "smile"
	go(ad, L(1.5, 0, 41.6), 1.7)
	world.story.amb_override = {"amb_city": 0.15, "amb_crowd": 0.9}
	shot("ad_away", func(t: float, _dt: float):
		var ap := pos_of(ad)
		var to_crowd := (L(1.5, 0, 38) - ap)
		to_crowd.y = 0
		var dirn := to_crowd.normalized() if to_crowd.length() > 0.3 else B * Vector3(0, 0, -1)
		aim(ap + dirn * 2.6 + dirn.cross(Vector3.UP) * 0.9 + Vector3(0, 1.6, 0), ap + Vector3(0, 1.45, 0) - dirn * 0.5, 44.0))
	await _w(1.6)
	ad.activity = "shout"
	line(ad, "Assistant director", "", "Push that guy back!", 1.8)
	for i in 3:
		var s: Human = cast["security%d" % i]
		s.activity = "hold"
	await _arrive(ad, 6.0)
	face(ad, L(1.5, 0, 30))
	line(ad, "Assistant director", "", "Ask these guys to stand behind the line!", 2.4)
	await _w(2.5)
	# Raja, in the press of bodies, straining to get closer
	shot("raja_crowd", func(t: float, _dt: float):
		var rp := head_of(raja)
		aim(L(1.0, 1.95, 41.4) + B * Vector3(t * 0.15, 0, 0), rp + Vector3(0, -0.15, 0), 34.0))
	line(raja, "Raja", "Thalaiva! Thalaiva!", "Thalaiva! Thalaiva!", 2.6)
	Sfx.play("whistle", 0.35)
	await _w(1.4)
	go(raja, L(3.25, 0, 38.15), 0.5)          # he leans into the rope
	# a crowd-control man steps up on the other side of the rope, square in front of him
	var s1: Human = cast["security1"]
	s1.activity = ""
	put(s1, L(3.25, 0, 38.75), pos_of(raja))
	await _w(0.8)
	# the shove: hands on his chest, and his feet go
	shot("shove", func(t: float, _dt: float):
		var mid := (pos_of(raja) + pos_of(s1)) * 0.5
		aim(mid + B * Vector3(-3.4, 1.45, -0.6), mid + Vector3(0, 1.1, 0), 40.0))
	line(s1, "Security", "Ey! Hindhe hogo!", "Hey! Get back!", 1.6)
	await _w(0.5)
	s1.play_once("push", 0.7)
	await _w(0.18)
	Sfx.play("punch", 0.3, 0.55)
	raja.activity = ""
	raja.mood = "surprise"
	raja.state = "fall"
	raja.fall_t = 0.0
	go(raja, L(3.3, 0, 36.6), 2.4, false)      # staggering back, still facing the man who pushed him
	# the people behind him get out of the way, and stare
	for c in crowd:
		var h: Human = c.h
		if pos_of(h).distance_to(pos_of(raja)) < 2.6:
			go(h, pos_of(h) + (pos_of(h) - pos_of(raja)).normalized() * 0.9, 2.2)
			h.look_target = pos_of(raja) + Vector3(0, 0.4, 0)
			h.mood = "surprise"
			h.activity = ""
	await _w(0.55)
	Sfx.play("punch", 0.35, 0.4)               # he lands
	shot("raja_falls", func(t: float, _dt: float):
		var rp := pos_of(raja)
		aim(rp + B * Vector3(-2.3, 0.65, -1.4) + B * Vector3(t * 0.06, 0, 0), rp + Vector3(0, 0.35, 0), 42.0))
	var med: Human = null
	for c in crowd:
		if c.get("med", false) and med == null and pos_of(c.h).distance_to(pos_of(raja)) < 20.0:
			med = c.h
	if med != null:
		med.look_target = pos_of(raja)
		line(med, "Medical student", "Ayyo, biddbitta paapa!", "Oh no, he fell, poor guy!", 2.0)
	await _w(1.4)
	# he gets back up, and dusts himself off
	shot("raja_rises", func(t: float, _dt: float):
		var rp := pos_of(raja)
		aim(rp + B * Vector3(-2.2, 1.35, -2.4) - B * Vector3(t * 0.08, 0, 0), rp + Vector3(0, lerpf(0.6, 1.1, ease_io(t / 2.0)), 0), lerpf(40.0, 36.0, ease_io(t / 4.0))))
	while raja.fall_t < 3.15 and not _skip:
		await get_tree().process_frame
	raja.state = "idle"
	raja.fall_t = -1.0
	raja.mood = "angry"
	raja.activity = "dust"
	for c in crowd:
		(c.h as Human).mood = ""
	await _w(2.6)
	raja.activity = ""
	s1.look_target = null

# ---------------------------------------------------------------- 5. the player takes control
func _s5_control() -> void:
	var uma: Human = cast["uma"]
	# the camera that was the film's becomes the player's: no cut, no load
	var from_t := cam.global_transform
	var from_fov := cam.fov
	var lp := Campus.frame().basis * Vector3(0, 0, 1)
	pl.yaw = atan2(-lp.x, -lp.z) + 0.35
	pl.pitch = -0.12
	pl.cam_override = false
	pl.puppet = false
	pl.locked = false
	hud.letterbox(false)
	shot("handoff", func(t: float, _dt: float):
		var k := ease_io(t / 1.6)
		var tr := from_t.interpolate_with(pl.cam.global_transform, k)
		cam.global_transform = tr
		cam.fov = lerpf(from_fov, pl.cam.fov, k))
	await _w(1.6)
	pl.cam.make_current()
	_cam_fn = Callable()
	phase = "play"
	player_free = true
	beat.emit("play")
	raja.activity = ""
	# Umashankar finds him
	go(uma, pos_of(raja) + (L(-1.4, 0, 0) - L(0, 0, 0)) + (L(0, 0, -0.6) - L(0, 0, 0)), 1.3)
	var t := 0.0
	while not arrived(uma) and t < 8.0:
		go(uma, pos_of(raja) + (pos_of(uma) - pos_of(raja)).normalized() * 1.1, 1.3)
		await get_tree().process_frame
		t += get_process_delta_time()
		if pos_of(uma).distance_to(pos_of(raja)) < 1.3:
			movers.erase(uma)
			uma.speed = 0.0
			break
	uma.look_target = head_of(raja)
	pl.talk_focus = uma
	uma.mood = "smile"
	# Umashankar: slow, amused, never in a hurry. Raja: quick, loud, all "maga" and "kano".
	line(uma, "Umashankar", "Enlaa bhakta... biddu eddu, devra darshana aaytaa?", "So, devotee... you fell and got up. Did you get your god's darshan?", 3.8)
	await _w(4.0)
	var c := await _choose([["Kannu tumba nodde kano. Saaku.", "I saw him till my eyes were full. That's enough."],
		["Hogo! Ninge en gottu Thalaivar bagge?", "Get lost! What do you know about Thalaivar?"]])
	if c == 0:
		line(raja, "Raja", "Kannu tumba nodde kano. Saaku.", "I saw him till my eyes were full. That's enough.", 2.8)
		await _w(2.9)
		uma.activity = "laugh"
		line(uma, "Umashankar", "Avru ninna nodidra? Cooling glass haakondu kootidaare.", "Did he see you? He's sitting there in cooling glasses.", 3.6)
		await _w(3.7)
		uma.activity = ""
		line(raja, "Raja", "Thalaivar ellarnu nodtaare, maga.", "Thalaivar sees everyone, maga.", 2.8)
	else:
		line(raja, "Raja", "Hogo! Ninge en gottu Thalaivar bagge?", "Get lost! What do you know about Thalaivar?", 2.8)
		await _w(2.9)
		line(uma, "Umashankar", "Ella gottu. Beligge aaru ganteinda illi nintidiya, adu gottu.", "I know enough. I know you've been standing here since six in the morning.", 3.8)
		await _w(3.9)
		uma.activity = "laugh"
		line(raja, "Raja", "Aaru alla. Aidu.", "Not six. Five.", 2.4)
	await _w(2.6)
	uma.activity = ""
	pl.talk_focus = null
	# a few moments that are simply his: the crowd, the star under the umbrella
	var t2 := 0.0
	var start := pl.global_position
	while t2 < 5.0 and pl.global_position.distance_to(start) < 5.0 and not _skip:
		await get_tree().process_frame
		t2 += get_process_delta_time()

func _choose(opts: Array) -> int:
	_choices = VBoxContainer.new()
	_choices.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_choices.offset_left = -560
	_choices.offset_right = -230
	_choices.offset_top = -120
	_choices.offset_bottom = 60
	_choices.add_theme_constant_override("separation", 10)
	ui.add_child(_choices)
	_choice = -1
	for i in opts.size():
		var b := UI.button("%s\n%s" % [opts[i][0], opts[i][1]], 17)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _choice = i)
		_choices.add_child(b)
	var t := 0.0
	while _choice < 0 and t < 12.0 and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.05)
		if Game.test_mode and t > 1.0:
			_choice = int(OS.get_cmdline_user_args().has("--choice2"))
	_choices.queue_free()
	_choices = null
	return maxi(_choice, 0)

# ---------------------------------------------------------------- 6. Lal's entrance
func _s6_entrance() -> void:
	var lal: Human = cast["lal"]
	player_free = false
	pl.locked = true
	pl.puppet = true
	pl.cam_override = true
	cam.global_transform = pl.cam.global_transform
	cam.fov = pl.cam.fov
	cam.make_current()
	hud.letterbox(true)
	raja.speed = 0.0
	raja.state = "idle"
	var rpos := pos_of(raja)
	var gate_side := L(3.5, 0, 1.5)             # he comes in through the open gateway, alone (clear of the security cabin)
	put(lal, gate_side, rpos)
	lal.visible = true
	# let his body settle at the gate for a few frames before the first close-up cuts in
	for _i in 4:
		await get_tree().process_frame
	lal.mood = "smirk"
	lal.look_target = null
	var stop := rpos + (gate_side - rpos).normalized() * 4.6
	go(lal, stop, 1.25)
	world.story.amb_override = {"amb_city": 0.05, "amb_crowd": 0.35}
	slow(0.42)
	Sfx.play("whoosh", 0.4, 0.5)
	# 1. the smile
	shot("lips", func(t: float, _dt: float):
		var hp := head_of(lal)
		var fw := face_dir(lal)
		var mouth := hp + Vector3(0, -0.085, 0) + fw * 0.06
		aim(mouth + fw * (0.42 - t * 0.04) + fw.cross(Vector3.UP) * 0.05 + Vector3(0, 0.01, 0), mouth, 24.0))
	await _w(1.1)
	# 2. his back
	shot("back", func(t: float, _dt: float):
		var p := pos_of(lal)
		var fw := -lal.global_transform.basis.z
		aim(p - fw * 1.9 + Vector3(0, 1.45, 0) + fw.cross(Vector3.UP) * 0.35, p + fw * 6.0 + Vector3(0, 1.2, 0), 46.0))
	await _w(1.1)
	# 3. the feet
	shot("feet", func(t: float, _dt: float):
		var p := pos_of(lal)
		var fw := -lal.global_transform.basis.z
		var rt := fw.cross(Vector3.UP)
		aim(p + fw * 1.25 + rt * 0.75 + Vector3(0, 0.22, 0), p + Vector3(0, 0.18, 0) + fw * 0.2, 42.0))
	Sfx.play("step", 0.5, 0.6)
	await _w(0.9)
	Sfx.play("step", 0.5, 0.6)
	await _w(0.5)
	# 4. the approach: Raja notices, and stops
	raja.activity = ""
	raja.look_target = head_of(lal)
	shot("approach", func(t: float, _dt: float):
		var rp := pos_of(raja)
		var to := (pos_of(lal) - rp).normalized()
		aim(rp - to * 1.6 + Vector3(0, 1.75, 0) - to.cross(Vector3.UP) * 0.55, pos_of(lal) + Vector3(0, 1.35, 0), 40.0))
	await _w(0.6)
	raja.rotation.y = yaw_to(rpos, pos_of(lal))
	raja.mood = "glare"
	await _arrive(lal, 4.0)
	face(lal, rpos)
	lal.look_target = head_of(raja)
	lal.mood = "glare"
	slow(1.0)
	await _w(0.5)
	# the split: equal halves, nobody above anybody
	world.story.amb_override = {"amb_city": 0.0, "amb_crowd": 0.12}
	_open_split()
	phase = "split"
	beat.emit("split")
	_sweat.visible = true
	_sweat_t = 0.0
	Sfx.play("heart", 0.7)
	await _w(1.6)
	Sfx.play("heart", 0.8)
	await _w(1.6)
	Sfx.play("heart", 0.9)
	await _w(1.2)
	_close_split()
	_sweat.visible = false

func _open_split() -> void:
	_split = Control.new()
	UI.full(_split)
	_split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_split)
	ui.move_child(_split, 1)
	var vs := get_viewport().get_visible_rect().size
	_split_cams.clear()
	for i in 2:
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.position = Vector2(0, i * vs.y * 0.5)
		svc.size = Vector2(vs.x, vs.y * 0.5)
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_split.add_child(svc)
		var sv := SubViewport.new()
		sv.size = Vector2i(int(vs.x), int(vs.y * 0.5))
		svc.add_child(sv)
		var c := Camera3D.new()
		c.near = 0.02
		c.fov = 15.0
		sv.add_child(c)
		_split_cams.append(c)
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.position = Vector2(0, vs.y * 0.5 - 3)
	bar.size = Vector2(vs.x, 6)
	_split.add_child(bar)
	var who := [raja, cast["lal"]]
	_cam_fn = func(t: float, _dt: float):
		for i in 2:
			var h: Human = who[i]
			var other: Human = who[1 - i]
			var hp := head_of(h)
			var to := (head_of(other) - hp)
			to.y = 0
			to = to.normalized()
			var c: Camera3D = _split_cams[i]
			# eye-line: each face seen from just off the other man's eye line, pushing in slowly
			var d := lerpf(1.25, 1.05, ease_io(t / 4.4))
			c.global_position = hp + to * d + to.cross(Vector3.UP) * (0.12 if i == 0 else -0.12) + Vector3(0, -0.01, 0)
			c.look_at(hp + Vector3(0, -0.015, 0), Vector3.UP)
		aim(head_of(raja) + Vector3(0, 0.3, 2), head_of(raja), 40.0)

func _close_split() -> void:
	if _split != null:
		_split.queue_free()
		_split = null
	_split_cams.clear()

# ---------------------------------------------------------------- 7. the confrontation
func _s7_confrontation() -> void:
	var lal: Human = cast["lal"]
	var rp := pos_of(raja)
	var mp := pos_of(lal)
	_centre = (rp + mp) * 0.5
	raja.mood = "scream"
	lal.mood = "scream"
	world.story.amb_override = {"amb_city": 0.0, "amb_crowd": 1.0}
	Sfx.play("whoosh", 0.6, 0.8)
	line(null, "", "", "", 0.1)
	clear_line()
	var to := (mp - rp).normalized()
	var side := to.cross(Vector3.UP)
	go(lal, _centre - to * 0.55, 4.8)
	shot("charge", func(t: float, _dt: float):
		aim(_centre + side * 6.2 + Vector3(0, 1.4, 0) - to * 0.4, _centre + Vector3(0, 1.1, 0), 46.0))
	# Raja runs, and leaves the ground
	var t := 0.0
	var start := rp
	var air_from := 0.0
	while t < 1.15:
		var dt := get_process_delta_time()
		t += dt
		var k := clampf(t / 1.15, 0.0, 1.0)
		var p := start.lerp(_centre - to * 0.55, k)
		var y := 0.0
		if k > 0.45:
			if air_from == 0.0:
				air_from = t
				raja.play_once("leap", 2.0)
			var u := (k - 0.45) / 0.55
			y = sin(u * PI) * 0.75
			raja.state = "air"
		raja.speed = 5.5 if k <= 0.45 else 0.0
		pl.global_position = Vector3(p.x, y, p.z)
		raja.rotation.y = atan2(-to.x, -to.z)
		if k > 0.75 and Engine.time_scale > 0.3 * base_ts:
			slow(0.22)
		await get_tree().process_frame
		if _skip:
			break
	# the punch is the player's to throw
	phase = "punch"
	beat.emit("punch")
	_punch_hit = false
	_show_prompt()
	var wt := 0.0
	while not _punch_hit and wt < 3.0 and not _skip:
		await get_tree().process_frame
		wt += get_process_delta_time() / maxf(Engine.time_scale, 0.05)
		if Input.is_action_just_pressed("punch") or (Game.test_mode and wt > 0.6):
			_punch_hit = true
	_hide_prompt()
	raja.play_once("punch", 0.45)
	slow(0.12)
	Sfx.play("punch", 1.0, 0.8)
	Sfx.play("boom", 0.5, 1.4)
	flash()
	_shake = 1.0
	lal.play_once("hit", 0.6)
	movers.erase(lal)
	go(lal, pos_of(lal) + to * 0.7, 3.0)
	shot("impact", func(t2: float, _dt: float):
		aim(_centre - side * 2.4 + Vector3(0, 1.3, 0) + to * 0.3, _centre + Vector3(0, 1.35, 0), 34.0))
	await _real(0.7)
	slow(1.0)
	_shake = 0.0
	pl.global_position.y = 0.0
	raja.state = "idle"
	# from high above the gate: two waves of people meeting
	_dust_at(_centre)
	# the star's people take him away from the trouble, out of sight
	cast["rajini"].visible = false
	for c in crowd:
		var h: Human = c.h
		if c.get("med", false) or pos_of(h).distance_to(_centre) > 32.0:
			c.mode = "react"         # the medical students and the far crowd stop and stare
			h.activity = ""
			continue
		var off := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(1.4, 6.5)
		c.mode = "surge"
		h.look_target = null
		go(h, _centre + off + side * float(c.side) * rng.randf_range(0.0, 2.0), rng.randf_range(3.6, 5.2))
	cast["lal_friend"].visible = true
	put(cast["lal_friend"], _centre + to * 9.0, _centre)
	for id in ["uma", "raja_friend"]:
		go(cast[id], _centre - to * 1.2 + side * rng.randf_range(-1, 1), 4.6)
	go(cast["lal_friend"], _centre + to * 1.4, 4.6)
	shot("high_angle", func(t2: float, _dt: float):
		aim(_centre + Campus.frame().basis * Vector3(-4.0, 33.0 - t2 * 0.6, -11.0), _centre + Campus.frame().basis * Vector3(0, 0, 6.0), 56.0))
	await _w(4.2)
	# ground level, in it
	raja.activity = "hold"
	lal.activity = "hold"
	cast["uma"].activity = "hold"
	cast["lal_friend"].activity = "hold"
	put(raja, _centre - to * 0.5, _centre)
	put(lal, _centre + to * 0.5, _centre)
	_shake = 0.45
	shot("chaos1", func(t2: float, _dt: float):
		aim(_centre + side * 2.6 - to * 1.2 + Vector3(0, 1.5, 0), _centre + Vector3(0, 1.3, 0), 40.0))
	await _w(2.4)
	var ad: Human = cast["ad"]
	put(ad, _centre + to * 4.5 + side * 3.5, _centre)
	ad.activity = "shout"
	ad.mood = "scream"
	line(ad, "Assistant director", "", "Stop it! Stop it! Somebody separate them!", 2.4)
	for id in ["shankar", "kvanand"]:
		var h2: Human = cast[id]
		h2.mood = "surprise"
		h2.look_target = _centre + Vector3(0, 1.4, 0)
	shot("chaos2", func(t2: float, _dt: float):
		var ap := pos_of(ad)
		aim(ap + (ap - _centre).normalized() * 2.4 + side * 0.8 + Vector3(0, 1.7, 0), ap.lerp(_centre, 0.5) + Vector3(0, 1.3, 0), 44.0))
	await _w(2.4)
	for c in crowd:
		if c.get("med", false):
			line(c.h, "Medical student", "Ayyo, hodedaadtidaare! Yaaradru police ge phone maadi!", "They're fighting! Someone call the police!", 2.2)
			break
	shot("chaos3", func(t2: float, _dt: float):
		aim(_centre - side * 3.4 + to * 1.0 + Vector3(0, 0.9, 0), _centre + Vector3(0, 1.4, 0), 50.0))
	await _w(1.2)

func _dust_at(p: Vector3) -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = 70
	_dust.lifetime = 3.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(4.5, 0.2, 4.5)
	_dust.direction = Vector3(0, 1, 0)
	_dust.spread = 70.0
	_dust.initial_velocity_min = 0.3
	_dust.initial_velocity_max = 1.1
	_dust.gravity = Vector3(0, -0.05, 0)
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.6
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.64, 0.52, 0.22)
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	m.albedo_texture = gt
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	_dust.mesh = q
	root.add_child(_dust)
	_dust.global_position = p + Vector3(0, 0.3, 0)

func _show_prompt() -> void:
	_prompt = Button.new()
	_prompt.text = "PUNCH"
	_prompt.add_theme_font_override("font", UI.title_font())
	_prompt.add_theme_font_size_override("font_size", 44)
	_prompt.add_theme_color_override("font_color", Color.BLACK)
	_prompt.add_theme_stylebox_override("normal", UI.box(UI.YELLOW, 90, 4, Color.BLACK, 10))
	_prompt.add_theme_stylebox_override("hover", UI.box(UI.YELLOW, 90, 4, Color.BLACK, 10))
	_prompt.add_theme_stylebox_override("pressed", UI.box(Color.WHITE, 90, 4, Color.BLACK, 10))
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_prompt.offset_left = -330
	_prompt.offset_top = -330
	_prompt.offset_right = -150
	_prompt.offset_bottom = -150
	_prompt.pivot_offset = Vector2(90, 90)
	_prompt.pressed.connect(func(): _punch_hit = true)
	ui.add_child(_prompt)
	var tw := _prompt.create_tween().set_loops()
	tw.tween_property(_prompt, "scale", Vector2(1.12, 1.12), 0.25)
	tw.tween_property(_prompt, "scale", Vector2(1.0, 1.0), 0.25)

func _hide_prompt() -> void:
	if _prompt != null:
		_prompt.queue_free()
		_prompt = null

# ---------------------------------------------------------------- 8. the siren
func _s8_police() -> void:
	# the siren comes first, from somewhere down the road
	var jeep := Vehicle.create("jeep", 0)
	root.add_child(jeep)
	jeep.collision_layer = 0
	jeep.collision_mask = 0
	jeep.global_position = L(150.0, 0, -7.5)
	jeep.rotation.y = yaw_to(L(150, 0, -7.5), L(0, 0, -7.5))
	_siren = AudioStreamPlayer3D.new()
	_siren.stream = Sfx.stream("siren")
	_siren.bus = "Sfx"
	_siren.unit_size = 18.0
	_siren.max_distance = 400.0
	_siren.volume_db = 2.0
	jeep.add_child(_siren)
	_siren.position = Vector3(0, 1.9, 0)
	_siren.play()
	_beacon_m = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.14, 0.2)
	_beacon_m.mesh = bm
	_beacon_m.material_override = Mats.glow(Color(1.0, 0.1, 0.05), 4.0)
	jeep.add_child(_beacon_m)
	_beacon_m.position = Vector3(0, 1.95, 0.1)
	vmovers[jeep] = {"pts": [L(14.0, 0, -7.2), L(3.0, 0, -4.5), L(0.2, 0, 2.0), L(-1.0, 0, 14.0), L(-1.5, 0, 21.0)], "i": 0, "spd": 11.0}
	# heads turn
	for c in crowd:
		if rng.randf() < 0.5:
			(c.h as Human).look_target = L(0, 1.5, -10)
	shot("siren_heard", func(t: float, _dt: float):
		aim(_centre + Campus.frame().basis * Vector3(-3.0, 1.6, 4.0), _centre + Campus.frame().basis * Vector3(0, 1.4, -6.0), 46.0))
	_shake = 0.25
	await _w(2.6)
	_shake = 0.0
	shot("jeep_in", func(t: float, _dt: float):
		aim(L(-6.5, 1.6, 9.0), jeep.global_position + Vector3(0, 1.0, 0), 44.0))
	var t := 0.0
	while vmovers.has(jeep) and int(vmovers[jeep].i) < 5 and t < 14.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if _skip:
			break
	_siren.volume_db = -6.0
	# constables out; the two sides pulled apart
	var cops: Array = []
	for i in 3:
		var cl := Human.random_look(rng, 0, "police")
		var cp := jeep.global_position + jeep.global_transform.basis * Vector3(-1.3 if i != 1 else 1.3, 0, -0.5 + i * 0.7)
		var cop := spawn("cop%d" % i, cl, cp, _centre, 1)
		cops.append(cop)
		go(cop, _centre + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)), 3.2)
	for c in crowd:
		var h: Human = c.h
		c.mode = "part"
		h.activity = ""
		var away := (pos_of(h) - _centre)
		away.y = 0
		away = away.normalized() if away.length() > 0.2 else Vector3(1, 0, 0)
		go(h, _centre + away * rng.randf_range(6.0, 12.0), rng.randf_range(2.2, 3.2))
	shot("parting", func(t2: float, _dt: float):
		aim(_centre + Campus.frame().basis * Vector3(7.0, 3.2 + t2 * 0.2, -6.0), _centre + Vector3(0, 1.0, 0), 48.0))
	if _dust != null:
		_dust.emitting = false
	await _w(1.8)
	var to := (pos_of(cast["lal"]) - pos_of(raja)).normalized()
	for id in ["uma", "lal_friend"]:
		cast[id].activity = ""
	raja.activity = ""
	cast["lal"].activity = ""
	put(cops[0], pos_of(raja) - to * 0.7, pos_of(raja))
	put(cops[1], pos_of(cast["lal"]) + to * 0.7, pos_of(cast["lal"]))
	cops[0].activity = "hold"
	cops[1].activity = "hold"
	line(cops[0], "Constable", "Ey! Saaku! Hogi, ellaru hogi!", "Hey! Enough! Go, all of you, go!", 2.6)
	await _w(2.8)

# ---------------------------------------------------------------- 9. two separate journeys
func _s9_separate() -> void:
	var lal: Human = cast["lal"]
	var uma: Human = cast["uma"]
	var f2: Human = cast["raja_friend"]
	var rf: Human = cast["lal_friend"]
	var cop0: Human = cast["cop0"]
	var cop1: Human = cast["cop1"]
	cop0.activity = ""
	cop1.activity = ""
	raja.mood = "angry"
	lal.mood = "angry"
	# the auto waiting on the kerb, facing west (Bangalore drives on the left)
	var auto := Vehicle.create("auto", -1, true)
	root.add_child(auto)
	auto.collision_layer = 0
	auto.collision_mask = 0
	auto.global_position = L(5.5, 0, -6.6)
	auto.rotation.y = yaw_to(L(5.5, 0, -6.6), L(-50, 0, -6.6))
	cast["auto"] = auto
	# Raja is walked out of the gate; Lal is taken further in
	put(raja, L(1.4, 0, 4.6), L(2, 0, -5))
	put(cop0, L(1.0, 0, 5.5), L(2, 0, -5))
	put(uma, L(0.0, 0, 6.3), L(2, 0, -5))
	put(f2, L(2.4, 0, 6.1), L(2, 0, -5))
	go(raja, L(3.4, 0, -4.6), 1.5)
	go(cop0, L(2.4, 0, -2.5), 1.5)
	go(uma, L(4.6, 0, -4.4), 1.5)
	go(f2, L(6.4, 0, -4.8), 1.5)
	world.story.amb_override = {"amb_city": 0.6, "amb_crowd": 0.3}
	_siren.stop()
	shot("out_gate", func(t: float, _dt: float):
		aim(L(-3.6, 1.65, -5.2) + Campus.frame().basis * Vector3(t * 0.12, 0, 0), pos_of(raja) + Vector3(0, 1.35, 0), 40.0))
	await _w(4.5)
	# Lal, led deeper into the campus
	put(lal, L(3.0, 0, 54.0), L(1, 0, 86))
	put(rf, L(4.1, 0, 53.6), L(1, 0, 86))
	put(cop1, L(1.9, 0, 54.4), L(1, 0, 86))
	go(lal, L(1.2, 0, 76.0), 1.35)
	go(rf, L(2.4, 0, 76.0), 1.35)
	go(cop1, L(0.0, 0, 74.0), 1.35)
	shot("in_campus", func(t: float, _dt: float):
		var rp := pos_of(lal)
		aim(rp + Campus.frame().basis * Vector3(-3.2, 0, 4.6) + Vector3(0, 1.6, 0), rp + Vector3(0, 1.3, 0), 40.0))
	await _w(3.5)
	# Raja looks back
	await _arrive(raja, 4.0)
	_seat(auto, raja, Vector3(0.36, 0.24, 0.5))
	_seat(auto, f2, Vector3(-0.36, 0.24, 0.5))
	_seat(auto, uma, Vector3(0.38, 0.24, -0.48))
	raja.look_target = L(2.0, 1.6, 30.0)
	shot("raja_looks_back", func(t: float, _dt: float):
		var hp := raja.global_position + Vector3(0, 1.22, 0)      # seated in the auto
		var lk := (L(2.0, 1.6, 30.0) - hp)
		lk.y = 0
		lk = lk.normalized()
		aim(hp + lk * 1.35 + lk.cross(Vector3.UP) * 0.35 + Vector3(0, 0.06, 0) - lk * t * 0.04, hp + Vector3(0, -0.04, 0), 30.0))
	await _w(3.0)
	# Lal looks back: he stops, and half turns
	movers.erase(lal)
	lal.speed = 0.0
	lal.rotation.y = lerp_angle(lal.rotation.y, yaw_to(pos_of(lal), L(1.0, 0, -6.0)), 0.62)
	movers.erase(rf)
	rf.speed = 0.0
	rf.look_target = head_of(lal)
	lal.look_target = L(1.0, 1.6, -6.0)
	shot("lal_looks_back", func(t: float, _dt: float):
		var hp := head_of(lal)
		var lk := (L(1.0, 1.6, -6.0) - hp).normalized()
		aim(hp + lk * 1.6 - lk.cross(Vector3.UP) * 0.5 + Vector3(0, 0.04, 0), hp - Vector3(0, 0.12, 0), 34.0))
	await _w(3.0)

## Sit someone in a vehicle (local seat position).
func _seat(veh: Vehicle, h: Human, local: Vector3) -> void:
	movers.erase(h)
	var holder := Node3D.new()
	veh._lean.add_child(holder)
	holder.position = local
	if h == raja:
		pl.puppet = true
		raja.reparent(holder, false)
	else:
		h.reparent(holder, false)
	h.position = Vector3.ZERO
	h.rotation = Vector3(0, PI if local.z > 0.0 else -PI * 0.5, 0) if h != cast.get("uma") else Vector3(0, -PI * 0.35, 0)
	if local.z > 0.0:
		h.rotation.y = 0.0
	h.state = "sit"
	h.speed = 0.0
	h.activity = ""

# ---------------------------------------------------------------- 10. the two questions
func _s10_questions() -> void:
	var auto: Vehicle = cast["auto"]
	var f2: Human = cast["raja_friend"]
	var lal: Human = cast["lal"]
	var rf: Human = cast["lal_friend"]
	raja.look_target = null
	vmovers[auto] = {"pts": [L(-160.0, 0, -6.6), L(-400.0, 0, -6.6)], "i": 0, "spd": 8.5}
	auto.v = 4.0
	world.story.amb_override = {"amb_city": 0.75}
	var eng := Sfx.make_loop("eng_auto", auto)
	eng.volume_db = -6.0
	eng.play()
	shot("auto_inside", func(t: float, _dt: float):
		var b := auto.global_transform
		aim(b * Vector3(1.05, 1.42, -0.3), head_of(raja) + Vector3(0, -0.12, 0), 50.0))
	await _w(1.6)
	f2.look_target = head_of(raja)
	line(f2, "Friend", "Yaaru adhu?", "Who was that?", 2.2)
	await _w(2.2)
	raja.mood = "glare"
	line(raja, "Raja", "Aa sule maga...", "That son of a...", 2.6)
	await _w(2.7)
	# Lal, walking, with the same question waiting for him
	eng.stop()
	world.story.amb_override = {"amb_city": 0.2}
	put(lal, L(-2.0, 0, 84.0), L(-30, 0, 86))
	put(rf, L(-1.4, 0, 84.9), L(-30, 0, 86))
	go(lal, L(-20.0, 0, 86.5), 1.25)
	go(rf, L(-19.5, 0, 87.4), 1.25)
	lal.look_target = null
	rf.look_target = head_of(lal)
	shot("lal_walk", func(t: float, _dt: float):
		var rp := pos_of(lal)
		var fw := -lal.global_transform.basis.z
		aim(rp + fw * 2.5 + fw.cross(Vector3.UP) * -0.4 + Vector3(0, 1.62, 0), rp.lerp(pos_of(rf), 0.4) + Vector3(0, 1.45, 0), 38.0))
	await _w(1.2)
	line(rf, "Lal's friend", "Yaaru avnu?", "Who is he?", 2.0)
	await _w(2.0)
	lal.mood = "glare"
	lal.look_target = null
	line(lal, "Lal", "Avn hesru...", "His name...", 3.0)
	await _w(1.05)
	# cut to black: picture and sound together
	clear_line()
	_black.color.a = 1.0
	black_frame = Engine.get_process_frames()
	_cam_fn = Callable()
	phase = "black"
	beat.emit("black")
	# on the same frame as the black: every other sound stops, and the theme comes in at its whistle
	world.story.amb_override = {"amb_city": 0.0}
	if _siren != null:
		_siren.stop()
	for p in root.find_children("*", "AudioStreamPlayer3D", true, false):
		(p as AudioStreamPlayer3D).stop()
	Sfx.cut_all()
	Sfx.theme_at(Sfx.WHISTLE_T)
	whistle_frame = Engine.get_process_frames()
	beat.emit("whistle")
	await _real(1.2)

# ---------------------------------------------------------------- 11. title
func _s11_title() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	var bg := UI.rect(Color.BLACK)
	layer.add_child(bg)
	var vs := get_viewport().get_visible_rect().size
	var fsize := int(clampf(vs.y * 0.34, 150.0, 330.0))
	var sh := ShaderMaterial.new()
	sh.shader = _title_shader()
	sh.set_shader_parameter("progress", 0.0)
	var title := UI.deco_title("BIG BANG LORE", fsize, UI.YELLOW, 0.06)
	title.size = vs
	title.position = Vector2(0, -vs.y * 0.04)
	layer.add_child(title)
	for l in title.get_children():
		(l as Label).material = sh
	phase = "title"
	beat.emit("title_start")
	# not slid in from anywhere: the letters gather out of the black itself, light first catching
	# the faces, then the depth behind them
	var t := 0.0
	var dur := 5.0
	var mid_sent := false
	while t < dur + 0.2:
		var dt := get_process_delta_time() / maxf(Engine.time_scale, 0.05)
		t += dt if not _skip else dur
		sh.set_shader_parameter("progress", clampf(t / dur, 0.0, 1.0))
		if t >= dur * 0.5 and not mid_sent:
			mid_sent = true
			beat.emit("title_mid")
		await get_tree().process_frame
	beat.emit("title")
	await _real(3.0)
	_finish(layer)

func _title_shader() -> Shader:
	var s := Shader.new()
	s.code = """shader_type canvas_item;
uniform float progress = 0.0;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec4 c = COLOR;
	// grain of the black: each fleck of the letter surfaces at its own moment
	float n = vnoise(FRAGCOORD.xy / 3.0) * 0.55 + vnoise(FRAGCOORD.xy / 40.0) * 0.45;
	float a = smoothstep(n * 0.7, n * 0.7 + 0.3, progress * 1.25);
	// and the colour comes up from black as it settles
	float lum = smoothstep(0.1, 1.0, progress);
	COLOR = vec4(c.rgb * mix(0.04, 1.0, lum), c.a * a);
}
"""
	return s

func _finish(layer: CanvasLayer) -> void:
	world.story.opening_finished()
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = -210
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 10)
	box.modulate.a = 0.0
	layer.add_child(box)
	var note := UI.label("The story continues in the next update.", 18, Color(0.7, 0.7, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(note)
	var again := UI.button("Watch the opening again", 20)
	var walk := UI.button("Walk Bengaluru as Raja", 20)
	var menu := UI.button("Main menu", 20)
	for b in [again, walk, menu]:
		box.add_child(b)
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 1.2)
	phase = "done"
	beat.emit("done")
	again.pressed.connect(func():
		Game.s.active = ""
		Game.save_game(false)
		Game.goto("world"))
	menu.pressed.connect(func(): Game.goto("menu"))
	walk.pressed.connect(func():
		layer.queue_free()
		_release())

## Hand the world back: Raja on the road outside the gate, free to walk.
func _release() -> void:
	Engine.time_scale = 1.0
	if raja.get_parent() != pl:
		raja.reparent(pl, false)
		raja.position = Vector3.ZERO
		raja.rotation = Vector3.ZERO
	raja.state = "idle"
	raja.mood = ""
	pl.global_position = L(2.0, 0, -3.0)
	pl.puppet = false
	pl.locked = false
	pl.cam_override = false
	pl.cam.make_current()
	hud.letterbox(false)
	world.busy = false
	world.story.amb_override = {}
	world.weather.shadow_reach = 0.0
	world.story.clock_runs = true
	_black.color.a = 0.0
	Sfx.theme_stop(3.0)
	root.queue_free()
	root = null
	cam.queue_free()
	queue_free()
