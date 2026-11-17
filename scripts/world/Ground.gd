class_name Ground
extends RefCounted
## The walkable surface. Roads, footpaths, kerbs, junction plates, campus paving and
## steps carry thin collision on their own layer; anything standing or stepping asks
## here for the real height (and slope) under a point, instead of assuming y = 0.

const LAYER := 16                 # physics layer 5: walkable surfaces only (not walls, not seats)
static var space: PhysicsDirectSpaceState3D = null

static func hit(p: Vector3, up := 1.2, down := 2.0) -> Dictionary:
	if space == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + up, p.z), Vector3(p.x, p.y - down, p.z), LAYER)
	q.collide_with_areas = false
	return space.intersect_ray(q)

## Surface height under (x, z), searching from a little above `p.y`.
static func height(p: Vector3, up := 1.2) -> float:
	var r := hit(p, up)
	return float(r.position.y) if not r.is_empty() else 0.0

static func normal(p: Vector3) -> Vector3:
	var r := hit(p)
	return r.normal if not r.is_empty() else Vector3.UP

## Thin slab of walkable collision: a strip from a to b (on the ground plane), width w, top at `top`.
static func strip_shape(body: StaticBody3D, a: Vector3, b: Vector3, w: float, top: float) -> void:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var ln := d.length()
	if ln < 0.01:
		return
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, maxf(top, 0.02), ln)
	cs.shape = sh
	cs.position = Vector3((a.x + b.x) * 0.5, maxf(top, 0.02) * 0.5 + minf(top, 0.0), (a.z + b.z) * 0.5)
	cs.rotation.y = atan2(d.x, d.z)
	body.add_child(cs)

static func box_shape(body: StaticBody3D, centre: Vector3, size: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = centre
	cs.rotation.y = yaw
	body.add_child(cs)

static func new_body() -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = LAYER
	b.collision_mask = 0
	return b
