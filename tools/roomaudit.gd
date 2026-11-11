extends SceneTree
## Room audit: holds every 3D space to the room standard (no rendering needed). Runs next to tools/walktest.gd.
##   Godot --headless --path . -s tools/walktest.gd       can you get everywhere?
##   Godot --headless --path . -s tools/roomaudit.gd      is it a proper room once you are there?
## Optional, after a "--": --room=<id> audits one space, --chapter=<n> one chapter.
## A chapter with story days is audited as the investigation sees it (its last day) and as Free Time sees each earlier day.
##
## SCALE      doors at least 1.0 x 2.1 m (0.8 m wide where the door gives a story reason), signs under the ceiling, ceilings
##            high enough, a 1.2 m wide route between the doors (0.8 m where the builder sets k.cramped to a story reason),
##            a clear 1.2 m in front of every door.
## FLOATING   every prop rests on or is fixed to something. A thing hanging from the ceiling shows its cord or rod.
## SHELL      no two visible flat faces share a plane, no prop pokes through a wall.
## TOUCH      solid-looking things within reach can be bumped into, nothing invisible stops you (rails are the exception),
##            people (and the spare standing spots in k.spots) stand clear of props and out of doorways.
## DETAIL     a minimum number of props for the size of the room.
## LIGHT      at most 16 lights and 2 with shadows per space, every door and hotspot lit well enough to see.
## Exit code 1 if anything fails. What it cannot judge (does this read as a real place?) still needs eyes and screenshots.

const Kit := preload("res://scripts/world3d/kit.gd")
const Player3D := preload("res://scripts/world3d/player3d.gd")
const Chapters := preload("res://scripts/data/chapters.gd")

## Chapters whose rooms are held to the standard, and the lowest ceiling allowed in each (the mansion gets high ones).
const AUDITED := {1: 2.5, 2: 2.5, 3: 3.2}

const DOOR_MIN := Vector2(Kit.DOOR_W, Kit.DOOR_H)
const DOOR_NARROW := 0.8            # a door narrow on purpose (Kit.leaf / door style "narrow" with a story reason)
const WALK_W := 1.2
const WALK_W_CRAMPED := 0.8
const DOOR_CLEAR := 1.2
const PERSON_CLEAR := 0.4
const MAX_LIGHTS := 16
const MAX_SHADOWS := 2
const MIN_LIGHT := 0.34             # calibrated against rooms judged too dark (or fine) in screenshots

const STEP := 0.25                  # walking grid, the same as the walk test
const CONTACT := 0.025              # touching, allowing for the gap between a box and a rounded neighbour
const COPLANAR := 0.0015
const PLAYER_R := 0.27
const PLAYER_H := 1.6
const THIN := 0.08                  # anything narrower than this is a cord, a sheet or a post top, not furniture

var holder: Node3D
var fails := 0
var totals := {}
var spaces := 0
var only_room := ""
var only_chapter := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			only_room = a.get_slice("=", 1)
		elif a.begins_with("--chapter="):
			only_chapter = a.get_slice("=", 1).to_int()
	holder = Node3D.new()
	root.add_child(holder)
	for ch in AUDITED.keys():
		if only_chapter == 0 or only_chapter == ch:
			await _chapter(ch)
	print("")
	if fails == 0:
		print("roomaudit: OK (%d spaces)" % spaces)
	else:
		print("roomaudit: %d violation(s) in %d spaces: %s" % [fails, spaces, totals])
	quit(1 if fails > 0 else 0)


func _chapter(ch: int) -> void:
	Chapters.current = ch
	var rooms: Script = Chapters.rooms3d()
	var inv: Script = load(str(Chapters.get_value("investigation")))
	var inv_rooms: Dictionary = inv.get_script_constant_map()["ROOMS"]
	var world: Dictionary = rooms.get_script_constant_map()
	var spaces: Dictionary = world["SPACES"]
	var ids: Array = inv_rooms.keys()
	for id in spaces.keys():
		if not ids.has(id):
			ids.append(id)
	var starts: Dictionary = Chapters.get_value("day_starts", {})
	if starts.is_empty():
		for id in ids:
			await _audit(ch, rooms, str(id), "investigate")
		for id in world["FREE_SPACES"]:
			await _audit(ch, rooms, str(id), "freetime")
		return
	var last: int = starts.values().max()
	for id in ids:
		await _audit(ch, rooms, str(id), "investigate", last)
	for id in world["FREE_SPACES"]:
		for d in range(1, last):
			if Chapters.room_open(inv_rooms.get(id, spaces.get(id, {})), d):
				await _audit(ch, rooms, str(id), "freetime", d)


func _build(rooms: Script, id: String, mode: String, day: int = 0) -> Kit:
	for c in holder.get_children():
		holder.remove_child(c)
		c.free()
	var r := Node3D.new()
	holder.add_child(r)
	var k := Kit.new(r)
	k.mode = mode
	if day > 0:
		k.set_meta("day", day)
	rooms.call("build", id, k, {})
	return k


## Everyone who stands in a space: the named people, then the spare spots (as "spot 1", "spot 2", ...).
func _standers(k: Kit) -> Dictionary:
	var out := {}
	for cid in k.people.keys():
		out[str(cid)] = k.people[cid]
	for i in k.spots.size():
		out["spot %d" % (i + 1)] = k.spots[i]
	return out


func _fail(kind: String, msg: String) -> void:
	fails += 1
	totals[kind] = int(totals.get(kind, 0)) + 1
	print("  FAIL %-10s %s" % [kind, msg])


func _fmt(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


# =================================================================== one space
func _audit(ch: int, rooms: Script, id: String, mode: String, day: int = 0) -> void:
	if only_room != "" and only_room != id:
		return
	spaces += 1
	var k := _build(rooms, id, mode, day)
	await physics_frame
	await physics_frame
	var before := fails
	print("== ch%d %s [%s%s]" % [ch, id, mode, " day %d" % day if day > 0 else ""])
	var meshes: Array = []
	_collect(holder, meshes)
	var space := holder.get_world_3d().direct_space_state
	var seeds := _seeds(k)
	var reach := _flood(space, seeds, PLAYER_R, STEP, true)
	var cells := _cells(reach)
	var props := 0
	for m in meshes:
		if (m as Dictionary)["arch"] == "":
			props += 1
	var area := reach.size() * STEP * STEP
	var min_props := _min_props(area)
	var counts := _lights()
	_check_scale(k, ch, space, meshes, seeds, reach)
	_check_floating(meshes)
	_check_faces(space, meshes, reach)
	_check_walls(meshes)
	_check_touch(k, space, meshes, cells)
	if props < min_props:
		_fail("detail", "only %d props in %.0f m2 of floor (want at least %d)" % [props, area, min_props])
	_check_light(k, space, counts)
	print("  %s  props %d/%d  lights %d/%d  shadows %d/%d  floor %.0f m2%s" % ["ok  " if fails == before else "FAIL", props, min_props,
		counts["lights"], MAX_LIGHTS, counts["shadows"], MAX_SHADOWS, area, "  cramped: " + k.cramped if k.cramped != "" else ""])


func _min_props(area: float) -> int:
	return mini(90 + roundi(area * 1.2), 200)


## {mi, box, arch ("floor"/"wall"/"ceiling"/""), door (part of a door or lift)}
func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
		var mi: MeshInstance3D = n
		var a: AABB = mi.global_transform * mi.get_aabb()
		var kind := str(mi.get_meta("arch", ""))
		if kind == "" and _big(a) and not (mi.mesh is QuadMesh):
			if not (mi.mesh is BoxMesh):
				kind = "terrain"
			elif a.size.y < 0.6:
				kind = "roof" if a.position.y > 2.0 else "floor"
			else:
				kind = "wall"
		out.append({"mi": mi, "box": a, "arch": kind, "door": _in_door(mi)})
	for c in n.get_children():
		_collect(c, out)


## Big terrain, boulders and hand-built walls that didn't go through the kit's shell.
func _big(a: AABB) -> bool:
	var big := 0
	for i in 3:
		if a.size[i] > 2.4:
			big += 1
	return big >= 2


func _in_door(n: Node) -> bool:
	var p: Node = n
	while p != null:
		if p.has_meta("door_part"):
			return true
		p = p.get_parent()
	return false


func _seeds(k: Kit) -> Array:
	var out: Array = []
	for to in k.doors.keys():
		var d: Dictionary = k.doors[to]
		if d["body"] != null:
			out.append(_front(d, 1.15))
	for lid in k.lifts.keys():
		var l: Dictionary = k.lifts[lid]
		out.append((l["pos"] as Vector3) + Basis(Vector3.UP, float(l["rot"])) * Vector3(0, 0, 1.15))
	out.append(k.spawn)
	return out


func _front(d: Dictionary, dist: float) -> Vector3:
	return (d["pos"] as Vector3) + Basis(Vector3.UP, float(d["rot"])) * Vector3(0, 0, dist)


func _ground(space: PhysicsDirectSpaceState3D, x: float, y: float, z: float) -> Variant:
	for off in [Vector2.ZERO, Vector2(0.07, 0), Vector2(-0.07, 0), Vector2(0, 0.07), Vector2(0, -0.07)]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x + off.x, y + 0.55, z + off.y), Vector3(x + off.x, y - 0.6, z + off.y), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit["normal"] as Vector3).y >= 0.7:
			return Vector3(x, (hit["position"] as Vector3).y, z)
	return null


func _clear(space: PhysicsDirectSpaceState3D, p: Vector3, shape: CylinderShape3D) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.45 + shape.height / 2.0, 0))
	return space.intersect_shape(q, 1).is_empty()


func _clear_low(space: PhysicsDirectSpaceState3D, p: Vector3, shape: CylinderShape3D) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.2 + shape.height / 2.0, 0))
	return space.intersect_shape(q, 1).is_empty()


## Everywhere a cylinder of radius r can walk to from the seeds. It rides above the floor to get over stairs; with
## `ankles` a slimmer one below it also stops at low furniture, as the real player does.
func _flood(space: PhysicsDirectSpaceState3D, seeds: Array, r: float, step: float, ankles: bool = false) -> Array:
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = 1.1
	var low := CylinderShape3D.new()
	low.radius = 0.2
	low.height = 0.27
	var seen := {}
	var out: Array = []
	# cells are counted from the first seed, so points exactly half a step apart can't round to the same cell
	var o: Vector3 = seeds[0]
	for s in seeds:
		var g: Variant = _ground(space, (s as Vector3).x, (s as Vector3).y + 0.1, (s as Vector3).z)
		if g != null and not seen.has(_key(g, step, o)):
			seen[_key(g, step, o)] = true
			out.append(g)
	var i := 0
	while i < out.size() and out.size() < 60000:
		var p: Vector3 = out[i]
		i += 1
		for d in [Vector2(step, 0), Vector2(-step, 0), Vector2(0, step), Vector2(0, -step)]:
			var n: Variant = _ground(space, p.x + d.x, p.y, p.z + d.y)
			if n == null or absf((n as Vector3).y - p.y) > 0.22:
				continue
			var key := _key(n, step, o)
			if seen.has(key):
				continue
			seen[key] = true
			if _clear(space, n, shape) and (not ankles or _clear_low(space, n, low)):
				out.append(n)
	return out


func _key(p: Vector3, step: float, o: Vector3) -> Vector3i:
	return Vector3i(roundi((p.x - o.x) / step), roundi(p.y / 0.5), roundi((p.z - o.z) / step))


## Reached points sorted into grid columns, for quick "can anyone stand here" questions.
func _cells(reach: Array) -> Dictionary:
	var c := {}
	for r in reach:
		var key := Vector2i(roundi((r as Vector3).x / STEP), roundi((r as Vector3).z / STEP))
		if not c.has(key):
			c[key] = []
		(c[key] as Array).append(r)
	return c


func _near(reach: Array, p: Vector3, dist: float) -> bool:
	for r in reach:
		var v: Vector3 = r
		if absf(v.y - p.y) < 0.6 and Vector2(v.x - p.x, v.z - p.z).length() < dist:
			return true
	return false


# =================================================================== scale
func _check_scale(k: Kit, ch: int, space: PhysicsDirectSpaceState3D, meshes: Array, seeds: Array, reach: Array) -> void:
	# a space can hold itself to a lower ceiling with a reason (the wreck of the Mudlark is still a ship: 2.5 m)
	var min_ceiling: float = minf(float(AUDITED[ch]), float(k.get_meta("ceiling_min", AUDITED[ch])))
	for to in k.doors.keys():
		var d: Dictionary = k.doors[to]
		var min_w: float = DOOR_MIN.x if str(d.get("narrow", "")) == "" else DOOR_NARROW
		if float(d.get("w", 0.0)) < min_w - 0.001 or float(d.get("h", 0.0)) < DOOR_MIN.y - 0.001:
			_fail("door", "door to %s is %.2f x %.2f m (at least %.1f x %.1f)" % [to, float(d.get("w", 0.0)), float(d.get("h", 0.0)), min_w, DOOR_MIN.y])
		if d["body"] == null:
			continue
		var top: Variant = _ceiling_at(meshes, d["pos"] as Vector3)
		if top != null and float(d.get("sign_top", 0.0)) > float(top) - 0.02:
			_fail("door", "sign over the door to %s reaches the ceiling (top %.2f, ceiling %.2f)" % [to, float(d.get("sign_top", 0.0)), float(top)])
	# ceiling height, from everywhere you can stand
	var low := INF
	var at := Vector3.ZERO
	for i in range(0, reach.size(), 3):
		var p: Vector3 = reach[i]
		var top: Variant = _ceiling_at(meshes, p + Vector3(0, 0.1, 0))
		if top != null and float(top) - p.y < low:
			low = float(top) - p.y
			at = p
	if low < min_ceiling - 0.005:
		_fail("ceiling", "%.2f m at %s (at least %.1f)" % [low, _fmt(at), min_ceiling])
	# a route wide enough between doors, lifts and stairs
	var want := WALK_W_CRAMPED if k.cramped != "" else WALK_W
	var wide := _flood(space, [seeds[0]], want / 2.0 - 0.02, 0.15)
	var targets: Array = seeds.duplicate()
	for st in k.stairs_list:
		targets.append(st["bottom"])
		targets.append(st["top"])
	for t in targets:
		if not _near(wide, t, 0.75):
			_fail("walkway", "no %.1f m wide route from %s to %s" % [want, _fmt(seeds[0]), _fmt(t)])
	for st in k.stairs_list:
		if float(st["width"]) < want - 0.001:
			_fail("walkway", "stairs at %s are %.2f m wide (at least %.1f)" % [_fmt(st["bottom"]), float(st["width"]), want])
	# nothing in the way of the doors
	for to in k.doors.keys():
		var d: Dictionary = k.doors[to]
		if d["body"] != null:
			_door_front(space, k, meshes, str(to), d)
	for lid in k.lifts.keys():
		var l: Dictionary = k.lifts[lid]
		_door_front(space, k, meshes, "lift " + str(lid), {"pos": l["pos"], "rot": l["rot"], "w": 1.2, "node": l["node"]})


func _ceiling_at(meshes: Array, p: Vector3) -> Variant:
	var best: Variant = null
	for m in meshes:
		if (m as Dictionary)["arch"] != "ceiling":
			continue
		var a: AABB = m["box"]
		if p.x >= a.position.x and p.x <= a.end.x and p.z >= a.position.z and p.z <= a.end.z and a.position.y > p.y + 0.5:
			if best == null or a.position.y < float(best):
				best = a.position.y
	return best


## The box a person walks through to use a door: as wide as the door, DOOR_CLEAR deep.
func _door_zone(d: Dictionary) -> Array:
	var pos: Vector3 = d["pos"]
	var b := Basis(Vector3.UP, float(d["rot"]))
	var w: float = maxf(float(d.get("w", 1.0)), 1.0)
	var c0 := pos + b * Vector3(0, 0, 0.25)
	var c1 := pos + b * Vector3(0, 0, DOOR_CLEAR)
	var side := b * Vector3(w / 2.0, 0, 0)
	var a := AABB(c0 + side, Vector3.ZERO).expand(c0 - side).expand(c1 + side).expand(c1 - side)
	a.position.y = pos.y + 0.15
	a.size.y = 1.75
	return [a, c0.lerp(c1, 0.5) + Vector3(0, 1.0, 0), b]


func _door_front(space: PhysicsDirectSpaceState3D, k: Kit, meshes: Array, label: String, d: Dictionary) -> void:
	var zone: Array = _door_zone(d)
	var a: AABB = zone[0]
	var hits := 0
	for m in meshes:
		if m["arch"] != "" or _is_under(m["mi"], d["node"]):
			continue
		var b: AABB = m["box"]
		if b.size.length() >= 0.25 and b.intersects(a):
			hits += 1
			if hits == 1:
				_fail("door", "%s: something in the way at %s, size %s" % [label, _fmt(b.get_center()), _fmt(b.size)])
	var q := PhysicsShapeQueryParameters3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(float(d.get("w", 1.0)), 1.75, DOOR_CLEAR - 0.25)
	q.shape = s
	q.collision_mask = 1
	q.transform = Transform3D(zone[2], zone[1])
	for h in space.intersect_shape(q, 8):
		if hits == 0 and not _is_under(h["collider"], d["node"]) and not (h["collider"] as Node).get_meta("rail", false):
			hits += 1
			_fail("door", "%s: collider in the way at %s" % [label, _fmt((h["collider"] as Node3D).global_position)])
	var st := _standers(k)
	for cid in st.keys():
		var p: Vector3 = st[cid]
		if a.grow(0.3).has_point(Vector3(p.x, a.get_center().y, p.z)) and absf(p.y - (d["pos"] as Vector3).y) < 1.0:
			_fail("person", "%s stands in the path of %s" % [cid, label])


func _is_under(n: Node, top: Node) -> bool:
	var p := n
	while p != null:
		if p == top:
			return true
		p = p.get_parent()
	return false


# =================================================================== floating and hanging
func _check_floating(meshes: Array) -> void:
	var n := meshes.size()
	var parent: Array = []
	for i in n:
		parent.append(i)
	var find := func(x: int) -> int:
		var r := x
		while parent[r] != r:
			r = parent[r]
		parent[x] = r
		return r
	var touches := {}   # mesh index -> {floor, wall, ceiling, thin_ceiling}
	for i in n:
		if meshes[i]["arch"] != "":
			continue
		var bi: AABB = meshes[i]["box"]
		var grown := bi.grow(CONTACT)
		var t := {"floor": bi.position.y <= 0.04, "wall": false, "ceiling": false, "roof": false, "terrain": false, "thin": false}
		for j in n:
			if i == j or not grown.intersects(meshes[j]["box"]):
				continue
			var kind: String = meshes[j]["arch"]
			if kind == "":
				if j > i:
					var ra: int = find.call(i)
					var rb: int = find.call(j)
					if ra != rb:
						parent[ra] = rb
				continue
			t[kind] = true
			if kind == "ceiling" and _is_thin(bi):
				t["thin"] = true
		touches[i] = t
	var groups := {}
	for i in touches.keys():
		var r: int = find.call(i)
		if not groups.has(r):
			groups[r] = []
		(groups[r] as Array).append(i)
	for r in groups.keys():
		var g: Array = groups[r]
		var box: AABB = meshes[g[0]]["box"]
		var on_floor := false
		var on_wall := false
		var on_ceiling := false
		var thin := false
		for i in g:
			box = box.merge(meshes[i]["box"])
			var t: Dictionary = touches[i]
			on_floor = on_floor or t["floor"] or t["terrain"]
			on_wall = on_wall or t["wall"] or t["roof"]
			on_ceiling = on_ceiling or t["ceiling"]
			thin = thin or t["thin"]
		if box.size.length() < 0.05:
			continue
		if not on_floor and not on_wall and not on_ceiling:
			_fail("floating", "%d mesh(es) at %s, size %s, bottom y=%.2f" % [g.size(), _fmt(box.get_center()), _fmt(box.size), box.position.y])
		elif on_ceiling and not on_floor and not on_wall and not thin and box.size.y > 0.3:
			_fail("hanging", "hangs from the ceiling with no cord or rod: %s, size %s" % [_fmt(box.get_center()), _fmt(box.size)])


## A cord, chain or rod: narrow in two directions.
func _is_thin(a: AABB) -> bool:
	var narrow := 0
	for i in 3:
		if a.size[i] <= THIN:
			narrow += 1
	return narrow >= 2


# =================================================================== visible faces sharing a plane
func _check_faces(space: PhysicsDirectSpaceState3D, meshes: Array, reach: Array) -> void:
	var flat: Array = []
	for m in meshes:
		if _axis_aligned(m["mi"]):
			flat.append(m)
	var found := 0
	for i in flat.size():
		var a: AABB = flat[i]["box"]
		for j in range(i + 1, flat.size()):
			var b: AABB = flat[j]["box"]
			for ax in 3:
				var u := (ax + 1) % 3
				var v := (ax + 2) % 3
				var ou := minf(a.end[u], b.end[u]) - maxf(a.position[u], b.position[u])
				var ov := minf(a.end[v], b.end[v]) - maxf(a.position[v], b.position[v])
				if ou <= 0.04 or ov <= 0.04 or ou * ov <= 0.02:
					continue
				for side in [-1.0, 1.0]:
					var pa: float = a.position[ax] if side < 0.0 else a.end[ax]
					var pb: float = b.position[ax] if side < 0.0 else b.end[ax]
					if absf(pa - pb) > COPLANAR or _same_look(flat[i]["mi"], flat[j]["mi"]):
						continue
					if not _faces(flat[i]["mi"], ax, side) or not _faces(flat[j]["mi"], ax, side):
						continue
					var c := Vector3.ZERO
					c[ax] = pa + side * 0.008
					c[u] = (maxf(a.position[u], b.position[u]) + minf(a.end[u], b.end[u])) / 2.0
					c[v] = (maxf(a.position[v], b.position[v]) + minf(a.end[v], b.end[v])) / 2.0
					var normal := Vector3.ZERO
					normal[ax] = side
					if _covered(meshes, c, flat[i]["mi"], flat[j]["mi"]) or not _seen(space, reach, c, normal):
						continue
					found += 1
					if found <= 12:
						_fail("coplanar", "faces at %s share the %s plane, %.2f m2: %s and %s" % [_fmt(c), "xyz"[ax], ou * ov, _describe(flat[i]), _describe(flat[j])])
					else:
						_fail("coplanar", "(more)")


func _describe(m: Dictionary) -> String:
	var a: AABB = m["box"]
	return "%s %s" % [(m["mi"] as MeshInstance3D).mesh.get_class().replace("Mesh", ""), _fmt(a.size)]


func _axis_aligned(mi: MeshInstance3D) -> bool:
	if not (mi.mesh is BoxMesh or mi.mesh is QuadMesh or mi.mesh is PlaneMesh):
		return false
	var b: Basis = mi.global_transform.basis.orthonormalized()
	for i in 3:
		var v: Vector3 = b[i].abs()
		if v[v.max_axis_index()] < 0.999:
			return false
	return true


## A quad only has one face; a box has all six.
func _faces(mi: MeshInstance3D, ax: int, side: float) -> bool:
	if mi.mesh is BoxMesh:
		return true
	var n: Vector3 = mi.global_transform.basis.z.normalized()
	return absf(n[ax]) > 0.9 and signf(n[ax]) == signf(side)


func _covered(meshes: Array, c: Vector3, a: MeshInstance3D, b: MeshInstance3D) -> bool:
	for m in meshes:
		if m["mi"] != a and m["mi"] != b and (m["box"] as AABB).has_point(c):
			if not ((m["mi"] as MeshInstance3D).mesh is QuadMesh):
				return true
	return false


func _seen(space: PhysicsDirectSpaceState3D, reach: Array, c: Vector3, n: Vector3) -> bool:
	var stride := maxi(1, reach.size() / 80)
	for i in range(0, reach.size(), stride):
		var eye: Vector3 = (reach[i] as Vector3) + Vector3(0, Player3D.EYE, 0)
		if (eye - c).dot(n) < 0.02:
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, c, 1)).is_empty():
			return true
	return false


## Two faces that look identical can't flicker against each other.
func _same_look(a: MeshInstance3D, b: MeshInstance3D) -> bool:
	var ma: Material = a.material_override
	var mb: Material = b.material_override
	if ma == mb:
		return true
	if ma is StandardMaterial3D and mb is StandardMaterial3D:
		var sa := ma as StandardMaterial3D
		var sb := mb as StandardMaterial3D
		return sa.albedo_texture == sb.albedo_texture and sa.albedo_color.is_equal_approx(sb.albedo_color) and sa.emission_enabled == sb.emission_enabled
	if ma is ShaderMaterial and mb is ShaderMaterial:
		var sa := ma as ShaderMaterial
		var sb := mb as ShaderMaterial
		if sa.shader != sb.shader:
			return false
		for u in sa.shader.get_shader_uniform_list():
			var pname := StringName(str((u as Dictionary)["name"]))
			if sa.get_shader_parameter(pname) != sb.get_shader_parameter(pname):
				return false
		return true
	return false


# =================================================================== props through walls
func _check_walls(meshes: Array) -> void:
	for m in meshes:
		if m["arch"] != "" or m["door"] or (m["box"] as AABB).size.length() < 0.3:
			continue
		var a: AABB = m["box"]
		for w in meshes:
			if w["arch"] != "wall":
				continue
			var wb: AABB = w["box"]
			var t := wb.get_shortest_axis_index()
			if wb.size[t] > 0.5 or wb.size.y < 1.5 or not a.intersects(wb):
				continue
			if a.position[t] < wb.position[t] - 0.02 and a.end[t] > wb.end[t] + 0.02:
				_fail("through", "prop at %s, size %s, goes through the wall at %s" % [_fmt(a.get_center()), _fmt(a.size), _fmt(wb.get_center())])


# =================================================================== what you can touch
func _check_touch(k: Kit, space: PhysicsDirectSpaceState3D, meshes: Array, cells: Dictionary) -> void:
	_walk_through(meshes, cells)
	_invisible(meshes)
	var st := _standers(k)
	for cid in st.keys():
		var p: Vector3 = st[cid]
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 0.5, 0), 1)
		if space.intersect_ray(q).is_empty():
			_fail("person", "%s has no floor under them at %s" % [cid, _fmt(p)])
		for m in meshes:
			if m["arch"] != "":
				continue
			var a: AABB = m["box"]
			if a.position.y > p.y + 1.6 or a.end.y < p.y + 0.25 or a.size.length() < 0.2:
				continue
			var dx: float = maxf(maxf(a.position.x - p.x, p.x - a.end.x), 0.0)
			var dz: float = maxf(maxf(a.position.z - p.z, p.z - a.end.z), 0.0)
			if Vector2(dx, dz).length() < PERSON_CLEAR:
				_fail("person", "%s at %s is within %.1f m of a prop at %s, size %s" % [cid, _fmt(p), PERSON_CLEAR, _fmt(a.get_center()), _fmt(a.size)])
				break


## Can the player stand inside something that looks solid?
func _walk_through(meshes: Array, cells: Dictionary) -> void:
	var flagged := {}
	for m in meshes:
		var mesh: Mesh = (m["mi"] as MeshInstance3D).mesh
		if m["arch"] != "" or mesh is QuadMesh or _flimsy(mesh):
			continue
		var a: AABB = m["box"]
		if minf(a.size.x, a.size.z) < THIN or a.size.length() < 0.25:
			continue
		var core := a
		if not (mesh is BoxMesh) or not _axis_aligned(m["mi"]):
			# the corners of a round thing's box are empty air
			core = a.grow(-0.3 * minf(a.size.x, a.size.z) / 2.0)
			core.position.y = a.position.y
			core.size.y = a.size.y
		var g := core.grow(0.12)
		var x0 := roundi(g.position.x / STEP)
		var x1 := roundi(g.end.x / STEP)
		var z0 := roundi(g.position.z / STEP)
		var z1 := roundi(g.end.z / STEP)
		var hit := false
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				for r in cells.get(Vector2i(x, z), []):
					var v: Vector3 = r
					# the flood already can't step onto anything low, so only count standing right inside it
					var tall := a.end.y > v.y + 0.55
					var inside: AABB = g if tall else core
					if v.x < inside.position.x or v.x > inside.end.x or v.z < inside.position.z or v.z > inside.end.z:
						continue
					if not _in_rotated(m["mi"], v, 0.12 if tall else 0.0):
						continue
					# a shallow shelf at head height isn't something you walk into
					if minf(a.size.x, a.size.z) < 0.25 and a.position.y > v.y + 0.7:
						continue
					if a.position.y < v.y + PLAYER_H and a.end.y > v.y + 0.3:
						hit = true
		if hit:
			var key := Vector3i(a.get_center() * 2.0)
			if not flagged.has(key):
				flagged[key] = true
				_fail("no-collide", "you can walk through the prop at %s, size %s" % [_fmt(a.get_center()), _fmt(a.size)])


## For a turned box, its bounding box isn't good enough: is the point over the box itself?
func _in_rotated(mi: MeshInstance3D, v: Vector3, margin: float) -> bool:
	if not (mi.mesh is BoxMesh) or _axis_aligned(mi):
		return true
	var size: Vector3 = (mi.mesh as BoxMesh).size
	var l: Vector3 = mi.global_transform.affine_inverse() * Vector3(v.x, mi.global_position.y, v.z)
	return absf(l.x) <= size.x / 2.0 + margin and absf(l.z) <= size.z / 2.0 + margin


## Sheets, leaves and cords: real props, but nobody expects to bump into them.
func _flimsy(mesh: Mesh) -> bool:
	if mesh is BoxMesh:
		var b: Vector3 = (mesh as BoxMesh).size
		return minf(b.x, minf(b.y, b.z)) < 0.03
	if mesh is CylinderMesh:
		return maxf((mesh as CylinderMesh).top_radius, (mesh as CylinderMesh).bottom_radius) < 0.04
	return false


## Is there anything to see where a collider stops you? Rails are the one exception.
func _invisible(meshes: Array) -> void:
	var stack: Array = [holder]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is StaticBody3D) or not ((n as StaticBody3D).collision_layer & 1) or n.get_meta("rail", false):
			continue
		for c in n.get_children():
			if not (c is CollisionShape3D) or not ((c as CollisionShape3D).shape is BoxShape3D):
				continue
			var cs: CollisionShape3D = c
			var size: Vector3 = (cs.shape as BoxShape3D).size
			if size.y < 0.3:
				continue
			var a: AABB = cs.global_transform * AABB(-size / 2.0, size)
			var near: Array = []
			for m in meshes:
				# a floor counts only if this collider is that floor, not if the collider merely stands on it
				var over_floor: bool = m["arch"] == "floor" and (m["box"] as AABB).end.y <= a.position.y + 0.06
				if not over_floor and a.grow(0.06).intersects(m["box"]):
					near.append((m["box"] as AABB).grow(0.06))
			var nx := clampi(int(a.size.x / 0.1), 1, 12)
			var nz := clampi(int(a.size.z / 0.1), 1, 12)
			var covered := 0
			for ix in nx:
				for iz in nz:
					var x := a.position.x + a.size.x * (ix + 0.5) / nx
					var z := a.position.z + a.size.z * (iz + 0.5) / nz
					for b in near:
						var bb: AABB = b
						if x >= bb.position.x and x <= bb.end.x and z >= bb.position.z and z <= bb.end.z:
							covered += 1
							break
			if covered * 4 < nx * nz:
				_fail("invisible", "collider at %s, size %s, with nothing to see (%d/%d columns)" % [_fmt(a.get_center()), _fmt(a.size), covered, nx * nz])


# =================================================================== light
func _lights() -> Dictionary:
	var lights: Array = []
	var ambient := 0.0
	var stack: Array = [holder]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Light3D:
			lights.append(n)
		elif n is WorldEnvironment:
			var env: Environment = (n as WorldEnvironment).environment
			ambient = env.ambient_light_energy * env.ambient_light_color.get_luminance()
	var shadows := 0
	for l in lights:
		if (l as Light3D).shadow_enabled:
			shadows += 1
	return {"lights": lights.size(), "shadows": shadows, "list": lights, "ambient": ambient}


func _check_light(k: Kit, space: PhysicsDirectSpaceState3D, counts: Dictionary) -> void:
	if int(counts["lights"]) > MAX_LIGHTS:
		_fail("lights", "%d lights (at most %d)" % [counts["lights"], MAX_LIGHTS])
	if int(counts["shadows"]) > MAX_SHADOWS:
		_fail("lights", "%d lights with shadows (at most %d)" % [counts["shadows"], MAX_SHADOWS])
	for to in k.doors.keys():
		var d: Dictionary = k.doors[to]
		if d["body"] != null:
			_check_lit(space, counts, "door to " + str(to), (d["pos"] as Vector3) + Basis(Vector3.UP, float(d["rot"])) * Vector3(0, 1.2, 0.3))
	for hid in k.hot.keys():
		var b: StaticBody3D = k.hot[hid]["body"]
		_check_lit(space, counts, "hotspot " + str(hid), (b.get_child(0) as Node3D).global_position)


func _check_lit(space: PhysicsDirectSpaceState3D, counts: Dictionary, label: String, p: Vector3) -> void:
	var e := _light_at(space, counts, p)
	if e < MIN_LIGHT:
		_fail("dark", "%s at %s: light %.2f (want %.2f)" % [label, _fmt(p), e, MIN_LIGHT])


## A rough estimate of how much light lands on a point, using Godot's own falloff.
func _light_at(space: PhysicsDirectSpaceState3D, counts: Dictionary, p: Vector3) -> float:
	var e: float = counts["ambient"]
	for li in counts["list"]:
		var l: Light3D = li
		if l is DirectionalLight3D:
			e += l.light_energy * 0.7
			continue
		var d := l.global_position.distance_to(p)
		var rng: float = (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
		var att: float = (l as OmniLight3D).omni_attenuation if l is OmniLight3D else (l as SpotLight3D).spot_attenuation
		if d >= rng:
			continue
		if l is SpotLight3D:
			var to_p := (p - l.global_position).normalized()
			if (-l.global_transform.basis.z).dot(to_p) < cos(deg_to_rad((l as SpotLight3D).spot_angle)):
				continue
		if l.shadow_enabled:
			# stop short of the point, which is often inside the very thing being lit
			var q := PhysicsRayQueryParameters3D.create(l.global_position, p.move_toward(l.global_position, 0.7), 1)
			if not space.intersect_ray(q).is_empty():
				continue
		var nd := d / rng
		nd *= nd
		nd *= nd
		nd = maxf(1.0 - nd, 0.0)
		nd *= nd
		e += l.light_energy * nd * pow(maxf(d, 0.4), -att)
	return e
