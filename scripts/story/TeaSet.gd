class_name TeaSet
extends Node3D
## The macro set for the opening: a kerosene stove, a blackened vessel, a pair of
## steel tumblers, tea glasses on a dented tray. Liquids and steam are simple
## animated meshes and particles, staged for tight close-ups.

var water: MeshInstance3D       # liquid surface in the vessel
var stream: MeshInstance3D      # whatever is being poured right now
var steam: CPUParticles3D
var leaves: CPUParticles3D
var ladle: Node3D
var tumbler_a: Node3D
var tumbler_b: Node3D
var arc: MeshInstance3D         # the long "metre tea" pour
var glass_fill: MeshInstance3D
var tray: Node3D
var flame: MeshInstance3D
var _liq: StandardMaterial3D
var _t := 0.0

func _ready() -> void:
	var steel := Mats.col(Color(0.72, 0.73, 0.76), 0.25, 0.85)
	var soot := Mats.col(Color(0.09, 0.08, 0.08), 0.8, 0.2)
	_liq = StandardMaterial3D.new()
	_liq.albedo_color = Color(0.55, 0.62, 0.66, 0.9)
	_liq.roughness = 0.08
	_liq.metallic_specular = 0.9
	_liq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# counter, soot-stained wall, the stove
	_box(Vector3(0, -0.05, 0), Vector3(2.4, 0.1, 1.2), Color(0.32, 0.22, 0.15))
	_box(Vector3(0, 0.6, -0.62), Vector3(2.4, 1.4, 0.05), Color(0.36, 0.4, 0.44))
	_box(Vector3(-0.2, 0.9, -0.59), Vector3(0.5, 0.36, 0.01), Color(0.1, 0.12, 0.1))       # slate price board
	var lb := Label3D.new()
	lb.text = "TEA  2/-\nCOFFEE  3/-\nBUN  3/-"
	lb.font_size = 22
	lb.pixel_size = 0.0022
	lb.position = Vector3(-0.2, 0.9, -0.58)
	lb.modulate = Color(0.95, 0.95, 0.9)
	add_child(lb)
	_cyl(Vector3(0, 0.07, 0), 0.13, 0.14, steel).scale = Vector3(1, 1, 1)
	_cyl(Vector3(0, 0.02, 0), 0.16, 0.04, Mats.col(Color(0.15, 0.3, 0.55), 0.5))
	flame = _cyl(Vector3(0, 0.16, 0), 0.085, 0.03, Mats.glow(Color(0.25, 0.45, 1.0), 2.5))
	# the vessel: hollow, blackened outside, liquid inside
	var ves := CylinderMesh.new()
	ves.top_radius = 0.15
	ves.bottom_radius = 0.13
	ves.height = 0.2
	ves.cap_top = false
	ves.radial_segments = 20
	var vm := MeshInstance3D.new()
	vm.mesh = ves
	var vmat: StandardMaterial3D = soot.duplicate()
	vmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	vm.material_override = vmat
	vm.position = Vector3(0, 0.28, 0)
	add_child(vm)
	_box(Vector3(0.2, 0.36, 0), Vector3(0.14, 0.015, 0.03), Color(0.1, 0.1, 0.1))            # handle
	water = _cyl(Vector3(0, 0.2, 0), 0.138, 0.01, _liq)
	stream = _cyl(Vector3(0, 0.6, 0), 0.012, 0.5, _liq)
	stream.visible = false
	steam = CPUParticles3D.new()
	steam.amount = 26
	steam.lifetime = 2.2
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.07
	steam.direction = Vector3(0.1, 1, 0)
	steam.spread = 12.0
	steam.gravity = Vector3(0.02, 0.05, 0)
	steam.initial_velocity_min = 0.1
	steam.initial_velocity_max = 0.2
	steam.scale_amount_min = 0.6
	steam.scale_amount_max = 1.6
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = Mats.pool(false).albedo_texture
	sm.albedo_color = Color(1, 1, 1, 0.1)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = sm
	steam.mesh = q
	steam.position = Vector3(0, 0.36, 0)
	steam.emitting = false
	add_child(steam)
	leaves = CPUParticles3D.new()
	leaves.amount = 60
	leaves.lifetime = 0.7
	leaves.one_shot = true
	leaves.explosiveness = 0.3
	leaves.direction = Vector3(0, -1, 0)
	leaves.spread = 14.0
	leaves.initial_velocity_min = 0.4
	leaves.initial_velocity_max = 0.7
	leaves.gravity = Vector3(0, -2.5, 0)
	var lq := QuadMesh.new()
	lq.size = Vector2(0.009, 0.009)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.12, 0.07, 0.04)
	lm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	lq.material = lm
	leaves.mesh = lq
	leaves.position = Vector3(0.02, 0.62, 0)
	leaves.emitting = false
	add_child(leaves)
	ladle = Node3D.new()
	ladle.position = Vector3(0, 0.3, 0)
	add_child(ladle)
	var lh := _box(Vector3(0.07, 0.16, 0), Vector3(0.012, 0.4, 0.012), Color(0.7, 0.72, 0.75))
	remove_child(lh)
	ladle.add_child(lh)
	lh.rotation.z = -0.3
	ladle.visible = false
	# the two pouring tumblers and the long arc between them
	tumbler_a = _tumbler(Vector3(0.75, 0.75, 0.1), steel)
	tumbler_b = _tumbler(Vector3(0.75, 0.16, 0.1), steel)
	arc = _cyl(Vector3(0.75, 0.46, 0.1), 0.011, 0.5, _liq)
	arc.visible = false
	# the row of glasses on the tray
	tray = Node3D.new()
	tray.position = Vector3(-0.75, 0.01, 0.1)
	add_child(tray)
	var tb := _box(Vector3.ZERO, Vector3(0.5, 0.012, 0.34), Color(0.6, 0.61, 0.64))
	remove_child(tb)
	tray.add_child(tb)
	tb.material_override = steel
	var gmat := Mats.col(Color(0.85, 0.92, 0.95, 0.22), 0.05, 0.1)
	for i in 6:
		var gp := Vector3(-0.16 + (i % 3) * 0.16, 0.055, -0.08 + (i / 3) * 0.16)
		var g := _cyl(gp, 0.033, 0.09, gmat)
		remove_child(g)
		tray.add_child(g)
		var f := _cyl(gp - Vector3(0, 0.006, 0), 0.029, 0.07, Mats.col(Color(0.5, 0.3, 0.16), 0.2))
		remove_child(f)
		tray.add_child(f)
		if i == 0:
			glass_fill = f
			f.scale.y = 0.02
			f.position.y = gp.y - 0.04
	# biscuit jar, sugar tin, hanging packets: the clutter of a working stall
	_cyl(Vector3(-0.35, 0.11, -0.4), 0.07, 0.2, Mats.col(Color(0.85, 0.9, 0.92, 0.3), 0.05))
	_cyl(Vector3(-0.35, 0.07, -0.4), 0.062, 0.12, Mats.col(Color(0.78, 0.6, 0.35)))
	_cyl(Vector3(-0.35, 0.22, -0.4), 0.072, 0.02, Mats.col(Color(0.75, 0.1, 0.1)))
	_cyl(Vector3(0.38, 0.08, -0.42), 0.06, 0.15, Mats.col(Color(0.2, 0.4, 0.7), 0.4, 0.5))
	_cyl(Vector3(0.55, 0.12, -0.38), 0.09, 0.24, steel)                                      # milk can
	for i in 7:
		_box(Vector3(0.5 + i * 0.09, 1.02 - (i % 2) * 0.03, -0.56), Vector3(0.07, 0.11, 0.01), [Color(0.85, 0.15, 0.15), Color(0.95, 0.8, 0.15), Color(0.15, 0.5, 0.25)][i % 3])
	var lt := OmniLight3D.new()
	lt.position = Vector3(-0.6, 0.9, 0.9)
	lt.light_color = Color(1.0, 0.8, 0.55)
	lt.light_energy = 0.9
	lt.omni_range = 4.0
	add_child(lt)

func _box(p: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = Mats.col(c)
	m.position = p
	add_child(m)
	return m

func _cyl(p: Vector3, r: float, h: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 0.92
	c.height = h
	c.radial_segments = 18
	m.mesh = c
	m.material_override = mat
	m.position = p
	add_child(m)
	return m

func _tumbler(p: Vector3, mat: Material) -> Node3D:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var c := _cyl(Vector3.ZERO, 0.045, 0.1, mat)
	remove_child(c)
	n.add_child(c)
	return n

func _process(delta: float) -> void:
	_t += delta
	flame.scale = Vector3(1.0 + sin(_t * 23.0) * 0.06, 1.0 + sin(_t * 31.0) * 0.3, 1.0 + cos(_t * 19.0) * 0.06)
	if ladle.visible:
		ladle.rotation.y += delta * 4.0
		water.position.y += sin(_t * 9.0) * 0.0002
	if arc.visible:
		arc.scale.x = 1.0 + sin(_t * 40.0) * 0.15

# ---- beats, called in order by the opening ----
func pour_water() -> void:
	stream.visible = true
	_liq.albedo_color = Color(0.6, 0.68, 0.72, 0.85)
	var tw := create_tween()
	tw.tween_property(water, "position:y", 0.3, 3.0)
	tw.tween_callback(func(): stream.visible = false)

func add_leaves() -> void:
	leaves.emitting = true
	create_tween().tween_property(_liq, "albedo_color", Color(0.3, 0.14, 0.06, 0.96), 2.5)

func boil() -> void:
	steam.emitting = true

func add_milk() -> void:
	stream.visible = true
	stream.material_override = Mats.col(Color(0.96, 0.95, 0.9), 0.3)
	var tw := create_tween()
	tw.tween_property(_liq, "albedo_color", Color(0.66, 0.44, 0.26, 1.0), 2.6)
	tw.parallel().tween_property(water, "position:y", 0.345, 2.6)
	tw.tween_callback(func(): stream.visible = false)

func stir(on: bool) -> void:
	ladle.visible = on

func metre_pour(on: bool) -> void:
	arc.visible = on
	arc.material_override = Mats.col(Color(0.66, 0.44, 0.26), 0.15)
	if on:
		var tw := create_tween().set_loops(3)
		tw.tween_property(tumbler_a, "position:y", 0.95, 0.7).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(arc, "scale:y", 1.5, 0.7)
		tw.parallel().tween_property(arc, "position:y", 0.56, 0.7)
		tw.tween_property(tumbler_a, "position:y", 0.5, 0.7).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(arc, "scale:y", 0.6, 0.7)
		tw.parallel().tween_property(arc, "position:y", 0.34, 0.7)
	tumbler_a.rotation.z = 1.9 if on else 0.0

func fill_glass() -> void:
	var tw := create_tween()
	tw.tween_property(glass_fill, "scale:y", 1.0, 2.2)
	tw.parallel().tween_property(glass_fill, "position:y", 0.049, 2.2)
