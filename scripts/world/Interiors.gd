class_name Interiors
extends RefCounted
## Enterable rooms. Each is built on demand in its own pocket of space, with
## furniture, lighting, hotspots and the people who should be there right now.

const IDS := ["home", "bar", "police", "tailor", "godown"]
# id: [width, depth, height, wall colour, floor colour, light colour, light energy]
const ROOMS := {
	"home": [5.0, 4.6, 2.9, Color(0.55, 0.68, 0.62), Color(0.45, 0.2, 0.16), Color(1.0, 0.85, 0.6), 1.6],
	"bar": [10.0, 8.0, 3.1, Color(0.35, 0.16, 0.16), Color(0.2, 0.17, 0.15), Color(1.0, 0.45, 0.3), 1.3],
	"police": [9.0, 6.5, 3.3, Color(0.78, 0.76, 0.6), Color(0.5, 0.5, 0.48), Color(0.9, 0.95, 1.0), 1.7],
	"tailor": [6.5, 5.0, 3.0, Color(0.75, 0.82, 0.9), Color(0.6, 0.55, 0.5), Color(0.9, 0.95, 1.0), 1.9],
	"godown": [13.0, 10.0, 4.6, Color(0.5, 0.45, 0.36), Color(0.36, 0.33, 0.3), Color(1.0, 0.8, 0.5), 1.5],
}

static func has(id: String) -> bool:
	return IDS.has(id)

static func entry(id: String) -> Vector3:
	return Vector3(0, 0, float(ROOMS[id][1]) * 0.5 - 1.0)

static func hotspots(id: String) -> Array:
	var d: float = ROOMS[id][1]
	var out := [{"pos": Vector3(0, 0, d * 0.5 - 0.5), "label": "LEAVE", "key": "leave"}]
	match id:
		"home":
			out.append({"pos": Vector3(-1.4, 0, -1.2), "label": "SLEEP", "key": "sleep"})
			out.append({"pos": Vector3(1.7, 0, -1.6), "label": "CLOTHES", "key": "wardrobe"})
			out.append({"pos": Vector3(1.9, 0, 0.6), "label": "RADIO", "key": "radio"})
		"bar":
			out.append({"pos": Vector3(0, 0, -2.3), "label": "ORDER", "key": "bar"})
		"tailor":
			out.append({"pos": Vector3(0, 0, -0.9), "label": "BROWSE", "key": "tailor"})
		"godown":
			out.append({"pos": Vector3(5.6, 0, -4.2), "label": "BACK DOOR", "key": "backdoor"})
	return out

static func build(id: String, _world) -> Node3D:
	var R: Array = ROOMS[id]
	var w: float = R[0]
	var d: float = R[1]
	var h: float = R[2]
	var root := Node3D.new()
	var mb := MB.new()
	var wc: Color = R[3]
	# shell (faces point inward)
	mb.flat(Vector3(0, 0, 0), w, d, Rect2(0, 0, 1, 1), R[4])
	mb.quad(Vector3(-w / 2, h, d / 2), Vector3(w / 2, h, d / 2), Vector3(w / 2, h, -d / 2), Vector3(-w / 2, h, -d / 2), Vector3.DOWN, Rect2(0, 0, 1, 1), wc.lightened(0.3))
	mb.wall(Vector3(0, 0, -d / 2), Vector3(0, 0, 1), w, h, Rect2(0, 0, 1, 1), wc)
	mb.wall(Vector3(0, 0, d / 2), Vector3(0, 0, -1), w, h, Rect2(0, 0, 1, 1), wc.darkened(0.1))
	mb.wall(Vector3(-w / 2, 0, 0), Vector3(1, 0, 0), d, h, Rect2(0, 0, 1, 1), wc.darkened(0.05))
	mb.wall(Vector3(w / 2, 0, 0), Vector3(-1, 0, 0), d, h, Rect2(0, 0, 1, 1), wc.darkened(0.05))
	mb.wall(Vector3(0, 0, d / 2 - 0.02), Vector3(0, 0, -1), 1.1, 2.1, Rect2(0, 0, 1, 1), Color(0.3, 0.2, 0.14))   # door
	var solids: Array = []
	match id:
		"home":
			_box(mb, solids, Vector3(-1.5, 0.28, -1.75), Vector3(1.9, 0.12, 0.9), Color(0.35, 0.25, 0.18))   # cot
			mb.box(Vector3(-1.5, 0.38, -1.75), Vector3(1.8, 0.1, 0.8), Color(0.7, 0.7, 0.85))
			mb.box(Vector3(-2.25, 0.46, -1.75), Vector3(0.3, 0.1, 0.5), Color(0.9, 0.88, 0.8))
			_box(mb, solids, Vector3(1.8, 0.25, -1.9), Vector3(1.0, 0.5, 0.55), Color(0.3, 0.4, 0.5))        # steel trunk
			mb.box(Vector3(2.2, 0.45, 0.6), Vector3(0.35, 0.22, 0.2), Color(0.25, 0.2, 0.16))                # transistor radio
			_box(mb, solids, Vector3(2.2, 0.17, 0.6), Vector3(0.5, 0.34, 0.5), Color(0.5, 0.36, 0.25))
			mb.box(Vector3(-2.2, 0.12, 0.9), Vector3(0.45, 0.24, 0.45), Color(0.15, 0.3, 0.6))               # kerosene stove
			mb.box(Vector3(0.6, 0.02, 0.4), Vector3(1.8, 0.03, 0.75), Color(0.75, 0.6, 0.3))                 # Kitty's mat
			mb.wall(Vector3(0.9, 1.3, -d / 2 + 0.02), Vector3(0, 0, 1), 0.5, 0.75, Rect2(0, 0, 1, 1), Color(0.95, 0.93, 0.85))   # calendar
			mb.wall(Vector3(-0.6, 1.5, -d / 2 + 0.02), Vector3(0, 0, 1), 0.4, 0.5, Rect2(0, 0, 1, 1), Color(0.85, 0.7, 0.2))    # framed god photo
			_text(root, "JULY 2002\nSri Ganesha Stores", Vector3(0.9, 1.68, -d / 2 + 0.04), 0.0, 20, Color(0.6, 0.1, 0.1))
			for i in 4:   # clothes on a line
				mb.wall(Vector3(-w / 2 + 0.05, 1.3, -0.6 + i * 0.4), Vector3(1, 0, 0), 0.34, 0.6, Rect2(0, 0, 1, 1), [Color(0.76, 0.66, 0.5), Color(0.9, 0.9, 0.9), Color(0.3, 0.4, 0.6), Color(0.76, 0.66, 0.5)][i])
		"bar":
			_box(mb, solids, Vector3(0, 0.55, -3.0), Vector3(6.0, 1.1, 0.6), Color(0.3, 0.18, 0.1))
			for i in 9:
				mb.box(Vector3(-2.4 + i * 0.6, 1.9, -3.85), Vector3(0.14, 0.4, 0.14), [Color(0.5, 0.25, 0.1), Color(0.2, 0.4, 0.2), Color(0.8, 0.75, 0.6)][i % 3])
			mb.box(Vector3(0, 1.65, -3.85), Vector3(6.0, 0.06, 0.3), Color(0.25, 0.15, 0.1))
			for t in [Vector3(-3.2, 0, -0.5), Vector3(3.2, 0, -0.5), Vector3(-3.2, 0, 2.0), Vector3(3.2, 0, 2.0)]:
				_box(mb, solids, t + Vector3(0, 0.38, 0), Vector3(0.9, 0.76, 0.9), Color(0.35, 0.22, 0.14))
				mb.box(t + Vector3(0.15, 0.85, 0.1), Vector3(0.08, 0.2, 0.08), Color(0.45, 0.25, 0.1))
				for sd: float in [-1.0, 1.0]:
					mb.box(t + Vector3(sd * 0.85, 0.22, 0), Vector3(0.4, 0.44, 0.4), Color(0.5, 0.1, 0.1))
			_text(root, "NO CREDIT\nDON'T ASK", Vector3(0, 2.5, -d / 2 + 0.05), 0.0, 36, Color(1, 0.85, 0.3))
		"police":
			_box(mb, solids, Vector3(-1.5, 0.4, -1.6), Vector3(2.2, 0.8, 1.0), Color(0.4, 0.3, 0.22))   # S.I.'s desk
			for i in 4:
				mb.box(Vector3(-2.3 + i * 0.35, 0.86 + i * 0.03, -1.6), Vector3(0.3, 0.1 + i * 0.05, 0.4), Color(0.8, 0.7, 0.5))   # files
			mb.box(Vector3(-0.7, 0.9, -1.5), Vector3(0.25, 0.2, 0.25), Color(0.1, 0.1, 0.1))    # telephone
			_box(mb, solids, Vector3(2.6, 0.25, 1.6), Vector3(2.6, 0.08, 0.5), Color(0.45, 0.33, 0.22))   # the bench
			for i in 9:
				_box(mb, solids, Vector3(1.6 + i * 0.3, 1.5, -1.4), Vector3(0.05, 3.0, 0.05), Color(0.2, 0.2, 0.22))   # lock-up bars
			mb.wall(Vector3(-1.5, 1.6, -d / 2 + 0.02), Vector3(0, 0, 1), 1.6, 1.0, Rect2(0, 0, 1, 1), Color(0.3, 0.45, 0.3))
			_text(root, "CRIME CHART - UPPARPET P.S.\nChain snatching: 14   Solved: 2\nMissing cycles: 31", Vector3(-1.5, 2.1, -d / 2 + 0.04), 0.0, 20, Color.WHITE)
			_text(root, "LOCK-UP", Vector3(2.9, 2.9, -1.35), 0.0, 30, Color(1, 0.9, 0.3))
		"tailor":
			_box(mb, solids, Vector3(0, 0.5, -1.6), Vector3(4.0, 1.0, 0.6), Color(0.5, 0.36, 0.25))
			for i in 10:
				for j in 3:
					mb.box(Vector3(-2.2 + i * 0.5, 0.6 + j * 0.65, -2.35), Vector3(0.42, 0.22, 0.3), Human.CLOTH[(i * 3 + j) % Human.CLOTH.size()])
			_box(mb, solids, Vector3(2.5, 0.4, 0.8), Vector3(0.9, 0.8, 0.5), Color(0.2, 0.2, 0.2))   # sewing machine table
			mb.box(Vector3(2.5, 0.95, 0.8), Vector3(0.5, 0.3, 0.2), Color(0.08, 0.08, 0.08))
			_text(root, "DELIVERY IN 3 DAYS\n(GOD WILLING)", Vector3(0, 2.6, -d / 2 + 0.05), 0.0, 30, Color(0.1, 0.1, 0.5))
		"godown":
			var cols := [Color(1, 0.6, 0.1), Color(1, 0.9, 0.2), Color(0.9, 0.2, 0.3), Color(1, 1, 1), Color(0.95, 0.5, 0.7)]
			for i in 14:
				var p := Vector3(-5.6 + (i % 7) * 1.4, 0.35, -4.2 + (i / 7) * 1.5)
				_box(mb, solids, p, Vector3(1.0, 0.7, 1.0), Color(0.55, 0.45, 0.3))
				mb.box(p + Vector3(0, 0.45, 0), Vector3(0.85, 0.25, 0.85), cols[i % 5])
			for i in 6:
				_box(mb, solids, Vector3(-5.8, 0.4 + (i % 2) * 0.6, 0.5 + (i / 2) * 1.3), Vector3(1.1, 0.6, 0.8), Color(0.6, 0.55, 0.45))   # gunny sacks
			_box(mb, solids, Vector3(2.5, 0.3, -1.0), Vector3(2.0, 0.14, 1.0), Color(0.35, 0.25, 0.18))    # Thimmaiah's cot
			mb.box(Vector3(2.5, 0.4, -1.0), Vector3(1.9, 0.08, 0.9), Color(0.75, 0.2, 0.2))
			_box(mb, solids, Vector3(0.6, 0.45, -1.0), Vector3(0.7, 0.9, 0.5), Color(0.25, 0.25, 0.27))    # weighing scale
			mb.wall(Vector3(w / 2 - 0.02, 0, -4.2), Vector3(-1, 0, 0), 1.2, 2.1, Rect2(0, 0, 1, 1), Color(0.25, 0.3, 0.25))   # back door
	var mesh := ArrayMesh.new()
	mb.add_to(mesh, Mats.vcol())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	var body := StaticBody3D.new()
	root.add_child(body)
	for s in [[Vector3(0, h / 2, -d / 2 - 0.25), Vector3(w + 1, h, 0.5)], [Vector3(0, h / 2, d / 2 + 0.25), Vector3(w + 1, h, 0.5)],
			[Vector3(-w / 2 - 0.25, h / 2, 0), Vector3(0.5, h, d + 1)], [Vector3(w / 2 + 0.25, h / 2, 0), Vector3(0.5, h, d + 1)]] + solids:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = s[1]
		cs.shape = sh
		cs.position = s[0]
		body.add_child(cs)
	var lt := OmniLight3D.new()
	lt.position = Vector3(0, h - 0.5, 0)
	lt.light_color = R[5]
	lt.light_energy = R[6]
	lt.omni_range = maxf(w, d) * 1.3
	root.add_child(lt)
	return root

static func _box(mb: MB, solids: Array, c: Vector3, size: Vector3, col: Color) -> void:
	mb.box(c, size, col)
	solids.append([c, size])

static func _text(root: Node3D, text: String, pos: Vector3, yaw: float, size: int, col: Color) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = size
	lb.pixel_size = 0.006
	lb.modulate = col
	lb.outline_size = 4
	lb.position = pos
	lb.rotation.y = yaw
	root.add_child(lb)

## Put the right people in the room for this hour (plus any the story demands).
static func populate(id: String, world, origin: Vector3) -> void:
	var spots := {
		"home": [Vector3(0.6, 0, 0.4), Vector3(-0.3, 0, -0.5)],
		"bar": [Vector3(0, 0, -3.7), Vector3(-3.2, 0, 0.35), Vector3(3.2, 0, 0.35), Vector3(-3.2, 0, 2.85), Vector3(3.2, 0, 2.85)],
		"police": [Vector3(-1.5, 0, -2.5), Vector3(-3.3, 0, 0.8), Vector3(2.6, 0, 2.2)],
		"tailor": [Vector3(0, 0, -2.0), Vector3(2.5, 0, 0.2)],
		"godown": [Vector3(2.5, 0, -0.3), Vector3(1.0, 0, 0.6), Vector3(-2.0, 0, 1.5), Vector3(-3.5, 0, 2.5)],
	}
	var t := float(Game.s.time)
	var here: Array = []
	for nid in People.DB:
		var sl := People.slot(nid, t)
		var present: bool = sl[0] == id and (sl[1] != "off" or id == "home")
		if id == "home" and nid != "kitty":
			present = false
		if world.story.interior_cast(id).has(nid):
			present = true
		if world.story.interior_absent(id).has(nid):
			present = false
		if present:
			here.append(nid)
	# the proprietor always takes the first spot
	var lead := {"bar": "mani", "police": "lokesh", "tailor": "rafiq", "godown": "tiger", "home": "kitty"}
	here.sort_custom(func(a, b): return a == lead[id] and b != lead[id])
	var list: Array = spots[id]
	for i in mini(here.size(), list.size()):
		var nid: String = here[i]
		var n: NPC = world.crowd.spawn_actor(People.look_of(nid), {"name": People.NAMES[nid], "job": People.DB[nid].job}, origin + list[i], "interior", PI if i == 0 else float(i) * 1.3)
		n.id = nid
		if (id == "bar" and i > 0) or (id == "godown" and nid == "tiger") or (id == "police" and i == 0):
			n.sit = true
			n.human.state = "sit"
	# anonymous regulars give the bar its evening crowd
	if id == "bar" and (t >= 18.0 or t < 1.0):
		for i in range(here.size(), list.size()):
			var ident := People.random_identity(world.crowd.rng, "com")
			ident.sex = 0
			var n2: NPC = world.crowd.spawn_actor(Human.random_look(world.crowd.rng, 0), ident, origin + list[i], "interior", float(i))
			n2.sit = true
			n2.human.state = "sit"
			n2.story_tag = "interior"
