extends Node
## Bangalore's geography: localities and arterial roads projected from real
## coordinates (compressed 1:4), plus handcrafted places. Everything else
## (side streets, buildings) is generated per streamed chunk from this data.

const LAT0 := 12.9767
const LON0 := 77.5713
const SX := 27000.0      # metres of world per degree of longitude (real 108 km / 4)
const SZ := 27750.0      # per degree of latitude
const CHUNK := 100.0
const GRID := 50.0       # side-street spacing
const STREET_W := 8.0

# id: [display name, lat, lon, kind, urban radius]
# kinds: old (dense pete), com, res, ind, cant (leafy bungalows), gov, out (village / outskirts)
const LOCALITIES := {
	"majestic": ["Majestic", 12.9767, 77.5713, "com", 420],
	"gandhinagar": ["Gandhinagar", 12.9770, 77.5790, "com", 300],
	"chickpet": ["Chickpet", 12.9698, 77.5772, "old", 300],
	"krmarket": ["K.R. Market", 12.9650, 77.5770, "old", 330],
	"corporation": ["Corporation Circle", 12.9665, 77.5870, "gov", 280],
	"vidhana": ["Vidhana Veedhi", 12.9797, 77.5907, "gov", 260],
	"kasturba": ["Kasturba Road", 12.9740, 77.5975, "cant", 220],
	"mgroad": ["M.G. Road", 12.9756, 77.6066, "com", 320],
	"brigade": ["Brigade Road", 12.9716, 77.6070, "com", 260],
	"richmond": ["Richmond Circle", 12.9660, 77.6010, "com", 260],
	"shivajinagar": ["Shivajinagar", 12.9857, 77.6057, "old", 340],
	"ulsoor": ["Ulsoor", 12.9817, 77.6286, "res", 330],
	"indiranagar": ["Indiranagar", 12.9784, 77.6408, "res", 380],
	"domlur": ["Domlur", 12.9610, 77.6387, "res", 300],
	"hal": ["H.A.L. Airport", 12.9585, 77.6650, "ind", 300],
	"marathahalli": ["Marathahalli", 12.9569, 77.7011, "out", 260],
	"whitefield": ["Whitefield", 12.9698, 77.7500, "out", 320],
	"krpuram": ["K.R. Puram", 13.0075, 77.6950, "out", 280],
	"frazer": ["Frazer Town", 12.9988, 77.6130, "cant", 320],
	"cantonment": ["Cantonment", 12.9936, 77.5980, "cant", 280],
	"rtnagar": ["R.T. Nagar", 13.0212, 77.5946, "res", 320],
	"hebbal": ["Hebbal", 13.0358, 77.5970, "out", 280],
	"yelahanka": ["Yelahanka", 13.1007, 77.5963, "out", 320],
	"sadashivanagar": ["Sadashivanagar", 13.0068, 77.5813, "cant", 300],
	"malleshwaram": ["Malleshwaram", 13.0031, 77.5643, "res", 400],
	"yeshwanthpur": ["Yeshwanthpur", 13.0280, 77.5400, "ind", 340],
	"peenya": ["Peenya", 13.0285, 77.5197, "ind", 380],
	"rajajinagar": ["Rajajinagar", 12.9910, 77.5550, "res", 380],
	"vijayanagar": ["Vijayanagar", 12.9719, 77.5350, "res", 360],
	"mysoreroad": ["Mysore Road", 12.9530, 77.5440, "ind", 300],
	"kengeri": ["Kengeri", 12.9140, 77.4870, "out", 280],
	"basavanagudi": ["Basavanagudi", 12.9422, 77.5738, "res", 360],
	"lalbagh": ["Lalbagh", 12.9507, 77.5848, "res", 240],
	"jayanagar": ["Jayanagar", 12.9308, 77.5838, "res", 400],
	"banashankari": ["Banashankari", 12.9255, 77.5468, "res", 360],
	"jpnagar": ["J.P. Nagar", 12.9063, 77.5857, "res", 340],
	"btm": ["B.T.M. Layout", 12.9166, 77.6101, "res", 300],
	"madiwala": ["Madiwala", 12.9226, 77.6174, "com", 280],
	"koramangala": ["Koramangala", 12.9352, 77.6245, "res", 380],
	"wilsongarden": ["Wilson Garden", 12.9484, 77.5970, "res", 280],
	"shanthinagar": ["Shanthinagar", 12.9569, 77.5998, "com", 260],
	"bommanahalli": ["Bommanahalli", 12.9010, 77.6230, "out", 260],
	"ecity": ["Electronic City", 12.8452, 77.6602, "ind", 320],
}
# [a, b, road name, width]
const ROADS := [
	["majestic", "gandhinagar", "K.G. Road", 12], ["gandhinagar", "corporation", "K.G. Road", 12], ["gandhinagar", "vidhana", "Seshadri Road", 12],
	["majestic", "chickpet", "B.V.K. Iyengar Road", 12], ["chickpet", "krmarket", "Avenue Road", 12], ["krmarket", "corporation", "S.J.P. Road", 12],
	["corporation", "vidhana", "Nrupathunga Road", 12], ["corporation", "kasturba", "Kasturba Road", 12], ["kasturba", "mgroad", "M.G. Road", 14],
	["vidhana", "shivajinagar", "Infantry Road", 12], ["mgroad", "shivajinagar", "Kamaraj Road", 12], ["mgroad", "brigade", "Brigade Road", 12],
	["brigade", "richmond", "Residency Road", 12], ["corporation", "richmond", "Mission Road", 12], ["mgroad", "ulsoor", "M.G. Road", 14],
	["ulsoor", "indiranagar", "Old Madras Road", 16], ["indiranagar", "krpuram", "Old Madras Road", 16], ["krpuram", "whitefield", "Whitefield Road", 14],
	["indiranagar", "domlur", "100 Feet Road", 14], ["domlur", "hal", "Airport Road", 16], ["hal", "marathahalli", "Airport Road", 16],
	["marathahalli", "whitefield", "Varthur Road", 12], ["marathahalli", "krpuram", "Outer Ring Road", 16], ["domlur", "koramangala", "Inner Ring Road", 14],
	["koramangala", "madiwala", "Sarjapur Road", 12], ["richmond", "shanthinagar", "Double Road", 12], ["shanthinagar", "wilsongarden", "Hosur Road", 14],
	["shanthinagar", "lalbagh", "K.H. Road", 12], ["wilsongarden", "koramangala", "Hosur Road", 16], ["wilsongarden", "madiwala", "Hosur Road", 16],
	["madiwala", "bommanahalli", "Hosur Road", 16], ["bommanahalli", "ecity", "Hosur Road", 16], ["madiwala", "btm", "Outer Ring Road", 16],
	["btm", "jpnagar", "Outer Ring Road", 16], ["jpnagar", "banashankari", "Outer Ring Road", 16], ["btm", "jayanagar", "Bannerghatta Road", 12],
	["jayanagar", "jpnagar", "Kanakapura Road", 12], ["lalbagh", "jayanagar", "R.V. Road", 12], ["lalbagh", "basavanagudi", "Bull Temple Road", 12],
	["basavanagudi", "banashankari", "K.R. Road", 12], ["krmarket", "basavanagudi", "K.R. Road", 12], ["corporation", "lalbagh", "J.C. Road", 12],
	["krmarket", "mysoreroad", "Mysore Road", 16], ["mysoreroad", "kengeri", "Mysore Road", 16], ["mysoreroad", "vijayanagar", "Chord Road", 14],
	["vijayanagar", "rajajinagar", "Chord Road", 14], ["rajajinagar", "yeshwanthpur", "Chord Road", 14], ["majestic", "rajajinagar", "Dr. Rajkumar Road", 12],
	["majestic", "vijayanagar", "Magadi Road", 12], ["majestic", "malleshwaram", "Sampige Road", 12], ["malleshwaram", "yeshwanthpur", "C.V. Raman Road", 12],
	["yeshwanthpur", "peenya", "Tumkur Road", 16], ["malleshwaram", "sadashivanagar", "Sankey Road", 12], ["sadashivanagar", "hebbal", "Bellary Road", 16],
	["hebbal", "yelahanka", "Bellary Road", 16], ["sadashivanagar", "cantonment", "Jayamahal Road", 12], ["vidhana", "sadashivanagar", "Palace Road", 12],
	["cantonment", "shivajinagar", "Queens Road", 12], ["cantonment", "frazer", "Millers Road", 12], ["frazer", "ulsoor", "Kensington Road", 12],
	["frazer", "rtnagar", "Nandidurga Road", 12], ["rtnagar", "hebbal", "Bellary Road", 14], ["hebbal", "krpuram", "Outer Ring Road", 16],
	["hebbal", "yeshwanthpur", "Outer Ring Road", 16], ["peenya", "vijayanagar", "Outer Ring Road", 16], ["banashankari", "mysoreroad", "Outer Ring Road", 16],
]

var nodes := {}          # id -> {name, p: Vector2, kind, r}
var edges: Array = []    # {a, b, name, w, pa, pb, dir, len}
var adj := {}            # id -> [edge index]
var _cell_edges := {}    # Vector2i chunk -> [edge index]
var PLACES := {}         # id -> {name, pos: Vector3, icon, kind}
var zones: Array = []    # [{id, rect: Rect2, kind}] handcrafted areas that suppress generic buildings
var stops := {}          # locality id -> {pos: Vector2, dir: Vector2} bus stop on the first road out
var sites := {}          # small handcrafted buildings: id -> {front: Vector2, face, w, d, type, name}

func to_world(lat: float, lon: float) -> Vector2:
	return Vector2((lon - LON0) * SX, -(lat - LAT0) * SZ)

func _ready() -> void:
	for id in LOCALITIES:
		var L = LOCALITIES[id]
		var p := to_world(L[1], L[2])
		p = Vector2(roundf(p.x / GRID) * GRID, roundf(p.y / GRID) * GRID)   # junctions sit on side-street crossings
		nodes[id] = {"name": L[0], "p": p, "kind": L[3], "r": float(L[4])}
		adj[id] = []
	for R in ROADS:
		var pa: Vector2 = nodes[R[0]].p
		var pb: Vector2 = nodes[R[1]].p
		var e := {"a": R[0], "b": R[1], "name": R[2], "w": float(R[3]), "pa": pa, "pb": pb, "dir": (pb - pa).normalized(), "len": pa.distance_to(pb)}
		edges.append(e)
		var idx := edges.size() - 1
		adj[R[0]].append(idx)
		adj[R[1]].append(idx)
		var n := int(e.len / 25.0) + 1
		for i in n + 1:
			var q: Vector2 = pa.lerp(pb, float(i) / n)
			var c := chunk_of(q)
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var key := c + Vector2i(dx, dz)
					if not _cell_edges.has(key):
						_cell_edges[key] = []
					if not _cell_edges[key].has(idx):
						_cell_edges[key].append(idx)
	for id in nodes:
		var e0 = edges[adj[id][0]]
		var d0: Vector2 = e0.dir if e0.a == id else -e0.dir
		var left := Vector2(d0.y, -d0.x)
		stops[id] = {"pos": nodes[id].p + d0 * 34.0 + left * (float(e0.w) * 0.5 + 1.4), "dir": d0}
	_define_places()

func chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))

func edges_near(c: Vector2i) -> Array:
	return _cell_edges.get(c, [])

## Distance from p to the nearest arterial centreline: returns [dist, edge index, t along edge 0..1]
func nearest_road(p: Vector2) -> Array:
	var best := [1e9, -1, 0.0]
	for idx in edges_near(chunk_of(p)):
		var e = edges[idx]
		var t := clampf((p - e.pa).dot(e.dir) / e.len, 0.0, 1.0)
		var d: float = p.distance_to(e.pa.lerp(e.pb, t))
		if d < best[0]:
			best = [d, idx, t]
	return best

func on_arterial(p: Vector2, margin := 0.0) -> bool:
	var n := nearest_road(p)
	return n[1] >= 0 and n[0] < edges[n[1]].w * 0.5 + margin

func nearest_node(p: Vector2) -> String:
	var best := ""
	var bd := 1e12
	for id in nodes:
		var d: float = p.distance_squared_to(nodes[id].p)
		if d < bd:
			bd = d
			best = id
	return best

## What kind of neighbourhood is at p, and how built-up (0..1).
func district(p: Vector2) -> Dictionary:
	var best := ""
	var bs := 0.0
	for id in nodes:
		var n = nodes[id]
		var d: float = p.distance_to(n.p)
		var sc: float = 1.0 - d / (float(n.r) * 1.25)
		if sc > bs:
			bs = sc
			best = id
	if best != "":
		return {"id": best, "kind": nodes[best].kind, "density": clampf(bs * 2.2, 0.25, 1.0), "name": nodes[best].name}
	var nr := nearest_road(p)
	if nr[1] >= 0 and nr[0] < 75.0:
		return {"id": "", "kind": "out", "density": 0.45, "name": edges[nr[1]].name}
	return {"id": "", "kind": "rural", "density": 0.0, "name": "Outskirts"}

func area_name(p: Vector2) -> String:
	for z in zones:
		if z.rect.has_point(p) and PLACES.has(z.id):
			return PLACES[z.id].name
	var nr := nearest_road(p)
	var d := district(p)
	if nr[1] >= 0 and nr[0] < 14.0:
		return "%s, %s" % [edges[nr[1]].name, d.name] if d.id != "" else str(edges[nr[1]].name)
	return d.name

func in_zone(p: Vector2, margin := 0.0):
	for z in zones:
		if z.rect.grow(margin).has_point(p):
			return z
	return null

func rect_hits_zone(r: Rect2) -> bool:
	for z in zones:
		if z.rect.intersects(r):
			return true
	return false

# ------------------------------------------------------------------ routing
## Shortest arterial route between two world points: list of Vector2 waypoints.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_node(from)
	var b := nearest_node(to)
	var ids := node_path(a, b)
	var out := PackedVector2Array([from])
	for id in ids:
		out.append(nodes[id].p)
	out.append(to)
	return out

func node_path(a: String, b: String) -> Array:
	var dist := {a: 0.0}
	var prev := {}
	var open := [a]
	var done := {}
	while not open.is_empty():
		var cur: String = open[0]
		for o in open:
			if dist[o] < dist[cur]:
				cur = o
		open.erase(cur)
		if cur == b:
			break
		done[cur] = true
		for idx in adj[cur]:
			var e = edges[idx]
			var other: String = e.b if e.a == cur else e.a
			if done.has(other):
				continue
			var nd: float = dist[cur] + e.len
			if not dist.has(other) or nd < dist[other]:
				dist[other] = nd
				prev[other] = cur
				if not open.has(other):
					open.append(other)
	var path := [b]
	var c := b
	while prev.has(c):
		c = prev[c]
		path.push_front(c)
	return path

func edge_between(a: String, b: String) -> int:
	for idx in adj[a]:
		var e = edges[idx]
		if (e.a == a and e.b == b) or (e.a == b and e.b == a):
			return idx
	return -1

## Walking route along the side-street grid (always on streets): Manhattan path.
func street_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := Vector2(from.x, roundf(from.y / GRID) * GRID)
	var b := Vector2(roundf(to.x / GRID) * GRID, a.y)
	var c := Vector2(b.x, roundf(to.y / GRID) * GRID)
	var d := Vector2(to.x, c.y)
	var side := 2.6
	return PackedVector2Array([a + Vector2(0, side), b + Vector2(side, side), c + Vector2(side, side), d + Vector2(0, side), to])

# ------------------------------------------------------------------ handcrafted places
func _site(id: String, nm: String, fx: float, fz: float, face: String, w: float, d: float, type: String, icon := "shop") -> void:
	var fwd := Vector2(0, -1) if face == "N" else Vector2(0, 1) if face == "S" else Vector2(1, 0) if face == "E" else Vector2(-1, 0)
	var front := Vector2(fx, fz)
	var centre := front - fwd * d * 0.5
	var size := Vector2(w, d) if face in ["N", "S"] else Vector2(d, w)
	sites[id] = {"name": nm, "front": front, "fwd": fwd, "centre": centre, "w": w, "d": d, "type": type}
	zones.append({"id": id, "rect": Rect2(centre - size * 0.5, size).grow(1.0), "kind": "site"})
	var door := front + fwd * 1.6
	PLACES[id] = {"name": nm, "pos": Vector3(door.x, 0, door.y), "icon": icon, "kind": type}

func _zone(id: String, nm: String, rect: Rect2, kind: String, icon := "landmark", entry := Vector2.INF) -> void:
	zones.append({"id": id, "rect": rect, "kind": kind})
	var e := entry if entry != Vector2.INF else rect.get_center()
	PLACES[id] = {"name": nm, "pos": Vector3(e.x, 0, e.y), "icon": icon, "kind": kind}

func np(id: String) -> Vector2:
	return nodes[id].p

func _define_places() -> void:
	# --- the starting neighbourhood (Majestic / Cottonpet lanes) ---
	_site("home", "Raji's Room (Lakshmi Vatara)", 25, 104.5, "N", 16, 11, "home", "home")
	_site("tea", "Nanjappa's Tea Stall", -25, 104.5, "N", 8, 5, "tea", "tea")
	_site("std", "Meena's S.T.D. Booth", -25, 95.5, "S", 7, 6, "std", "phone")
	_site("darshini", "Hotel Dwaraka Darshini", 25, 95.5, "S", 14, 9, "food", "food")
	_site("bar", "Kaveri Bar & Restaurant", -75, 104.5, "N", 12, 10, "bar", "bar")
	_site("dealer", "Sri Balaji Auto Consultants", -75, 95.5, "S", 18, 12, "dealer", "car")
	_site("tailor", "New Modern Tailors", -125, 95.5, "S", 10, 8, "tailor", "shirt")
	_site("police", "Upparpet Police Station", 125, -15, "S", 18, 12, "police", "police")
	_zone("majestic", "Kempegowda Bus Station", Rect2(10, -98, 86, 84), "busstation", "bus", Vector2(40, -20))
	_zone("railway", "Bangalore City Railway Station", Rect2(-196, -46, 92, 40), "railstation", "train", Vector2(-150, -2))
	# --- the wider city ---
	var v := np("vidhana")
	_zone("vidhana", "Vidhana Soudha", Rect2(v.x - 120, v.y - 115, 110, 80), "vidhana", "landmark", Vector2(v.x - 65, v.y - 30))
	var k := np("kasturba")
	_zone("cubbon", "Cubbon Park", Rect2(k.x - 150, k.y - 135, 135, 110), "park", "park", Vector2(k.x - 80, k.y - 20))
	var m := np("krmarket")
	_zone("market", "K.R. Market", Rect2(m.x + 14, m.y + 14, 72, 60), "market", "market", Vector2(m.x + 40, m.y + 10))
	_site("godown", "Thimmaiah Flower Godown", m.x - 75, m.y + 54.5, "N", 20, 14, "godown", "skull")
	var g := np("mgroad")
	_site("cinema", "Sangam Talkies", g.x - 75, g.y - 15.5, "S", 26, 20, "cinema", "film")
	_site("pub", "The Bison Pub", g.x + 75, g.y + 45.5, "S", 12, 9, "bar", "bar")
	var sh := np("shivajinagar")
	_site("parlour", "Anthony's Video Parlour", sh.x + 75, sh.y + 54.5, "N", 14, 10, "parlour", "skull")
	_site("jpp", "J.P.P. Party Office", np("gandhinagar").x + 25, np("gandhinagar").y + 54.5, "N", 14, 10, "office", "flag")
	_site("knv", "K.N.V. Party Office", np("malleshwaram").x + 75, np("malleshwaram").y + 45.5, "S", 14, 10, "office", "flag")
	_site("paper", "Sanje Vaani Press", np("corporation").x - 75, np("corporation").y - 54.5, "S", 14, 10, "office", "news")
	_site("shetty", "Shetty Steel & Castings", np("peenya").x + 75, np("peenya").y + 54.5, "N", 30, 20, "factory", "factory")
	_site("meena_home", "Meena's House", np("malleshwaram").x - 75, np("malleshwaram").y + 104.5, "N", 10, 9, "house", "home")
	_site("flat", "Flat for Sale (Jayanagar 4th Block)", np("jayanagar").x + 75, np("jayanagar").y + 54.5, "N", 14, 12, "property", "home")
	var u := np("ulsoor")
	_zone("ulsoor", "Ulsoor Lake", Rect2(u.x - 130, u.y - 150, 110, 120), "lake", "park", Vector2(u.x - 60, u.y - 25))
	var l := np("lalbagh")
	_zone("lalbagh", "Lalbagh Botanical Garden", Rect2(l.x + 20, l.y + 20, 150, 150), "park2", "park", Vector2(l.x + 30, l.y + 30))
	var b := np("basavanagudi")
	_zone("temple", "Dodda Gudi Temple", Rect2(b.x - 90, b.y + 14, 60, 60), "temple", "landmark", Vector2(b.x - 60, b.y + 10))
	var h := np("hal")
	_zone("airport", "H.A.L. Airport", Rect2(h.x + 20, h.y + 20, 260, 120), "airport", "plane", Vector2(h.x + 30, h.y + 30))
