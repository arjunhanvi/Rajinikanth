class_name MB
extends RefCounted
## Tiny mesh builder: accumulates quads/boxes into one surface.

var v := PackedVector3Array()
var n := PackedVector3Array()
var uv := PackedVector2Array()
var col := PackedColorArray()
var idx := PackedInt32Array()

func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, nrm: Vector3, uvr := Rect2(0, 0, 1, 1), c := Color.WHITE) -> void:
	# p0 bottom-left, p1 bottom-right, p2 top-right, p3 top-left (seen from the front)
	var b := v.size()
	v.append_array([p0, p1, p2, p3])
	n.append_array([nrm, nrm, nrm, nrm])
	uv.append_array([Vector2(uvr.position.x, uvr.end.y), uvr.end, Vector2(uvr.end.x, uvr.position.y), uvr.position])
	col.append_array([c, c, c, c])
	if (p2 - p0).cross(p1 - p0).dot(nrm) >= 0.0:
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	else:
		idx.append_array([b, b + 2, b + 1, b, b + 3, b + 2])

func wall(base_mid: Vector3, nrm: Vector3, w: float, h: float, uvr := Rect2(0, 0, 1, 1), c := Color.WHITE) -> void:
	var r := Vector3.UP.cross(nrm).normalized() * (w * 0.5)
	var up := Vector3(0, h, 0)
	quad(base_mid - r, base_mid + r, base_mid + r + up, base_mid - r + up, nrm, uvr, c)

func flat(centre: Vector3, sx: float, sz: float, uvr := Rect2(0, 0, 1, 1), c := Color.WHITE) -> void:
	var a := Vector3(sx * 0.5, 0, 0)
	var b := Vector3(0, 0, sz * 0.5)
	quad(centre - a + b, centre + a + b, centre + a - b, centre - a - b, Vector3.UP, uvr, c)

## Horizontal strip between two points with a given width (roads, footpaths).
func strip(a: Vector3, b: Vector3, w: float, vlen: float, c := Color.WHITE) -> void:
	var d := (b - a)
	var side := Vector3(d.z, 0, -d.x).normalized() * (w * 0.5)
	quad(a - side, a + side, b + side, b - side, Vector3.UP, Rect2(0, 0, 1, d.length() / vlen), c)

func box(centre: Vector3, size: Vector3, c := Color.WHITE, uvr := Rect2(0, 0, 1, 1), top := true, basis := Basis.IDENTITY) -> void:
	var hx := basis.x * size.x * 0.5
	var hz := basis.z * size.z * 0.5
	var bot := centre - Vector3(0, size.y * 0.5, 0)
	wall_dir(bot + hz, basis.z, hx, size.y, uvr, c)
	wall_dir(bot - hz, -basis.z, -hx, size.y, uvr, c)
	wall_dir(bot + hx, basis.x, -hz, size.y, uvr, c)
	wall_dir(bot - hx, -basis.x, hz, size.y, uvr, c)
	if top:
		var t := centre + Vector3(0, size.y * 0.5, 0)
		quad(t - hx + hz, t + hx + hz, t + hx - hz, t - hx - hz, Vector3.UP, uvr, c)

func wall_dir(base_mid: Vector3, nrm: Vector3, half_right: Vector3, h: float, uvr: Rect2, c: Color) -> void:
	var up := Vector3(0, h, 0)
	quad(base_mid - half_right, base_mid + half_right, base_mid + half_right + up, base_mid - half_right + up, nrm, uvr, c)

## Wheel-like cylinder whose axis is basis.x.
func wheel(centre: Vector3, radius: float, width: float, c: Color, basis := Basis.IDENTITY, segs := 10) -> void:
	var ax := basis.x * (width * 0.5)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var r0 := (basis.y * cos(a0) + basis.z * sin(a0)) * radius
		var r1 := (basis.y * cos(a1) + basis.z * sin(a1)) * radius
		quad(centre + r0 - ax, centre + r0 + ax, centre + r1 + ax, centre + r1 - ax, (r0 + r1).normalized(), Rect2(0, 0, 1, 1), c)
		for sd: float in [-1.0, 1.0]:
			var b := v.size()
			var nn := basis.x * sd
			v.append_array([centre + ax * sd, centre + r0 + ax * sd, centre + r1 + ax * sd])
			n.append_array([nn, nn, nn])
			uv.append_array([Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0)])
			var hub := c.lightened(0.25)
			col.append_array([hub, c, c])
			if (r1).cross(r0).dot(nn) >= 0.0:
				idx.append_array([b, b + 1, b + 2])
			else:
				idx.append_array([b, b + 2, b + 1])

func empty() -> bool:
	return v.is_empty()

func add_to(mesh: ArrayMesh, mat: Material) -> void:
	if v.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)

## UV rect of facade tile i in the 8 x 4 atlas.
static func atlas(i: int) -> Rect2:
	var pad := 0.003
	return Rect2((i % 8) / 8.0 + pad * 0.5, (i / 8) / 4.0 + pad, 1.0 / 8.0 - pad, 1.0 / 4.0 - pad * 2.0)
