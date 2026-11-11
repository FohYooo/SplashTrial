extends SceneTree
## Walk test for the 3D spaces (no rendering needed):
##   Godot --headless --path . -s tools/walktest.gd
## For every space of every chapter it checks that
##  - every door has a matching door back, and leads to a space that exists,
##  - from the arrival spot of each door you can reach, on foot, every door, lift, hotspot, person and note,
##    close enough and with a clear line of sight to use it,
##  - every staircase really carries a walking player to the top,
##  - in a chapter with days, every room and space has a valid "opens_day", and on every day before the last each guest
##    stands in exactly one Free Time space that is open that day (spaces are walked as the investigation sees them on
##    the last day, and as Free Time sees them on each earlier day).
##  - the investigation's people have somewhere to stand: a named spot, or one of the room's spare k.spots.
## Exit code 1 if anything fails.

const Kit := preload("res://scripts/world3d/kit.gd")
const Player3D := preload("res://scripts/world3d/player3d.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Chapters := preload("res://scripts/data/chapters.gd")

const STEP := 0.25
const REACH := 3.0
var fails := 0
var holder: Node3D


func _init() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	fails += 1
	print("FAIL ", msg)


func _run() -> void:
	holder = Node3D.new()
	root.add_child(holder)
	for ch in range(1, Chapters.LAST + 1):
		await _chapter(ch)
	print("walktest: ", "OK" if fails == 0 else "%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


func _build(ch_rooms: Script, id: String, mode: String, day: int = 0) -> Kit:
	for c in holder.get_children():
		holder.remove_child(c)
		c.free()
	var r := Node3D.new()
	holder.add_child(r)
	var k := Kit.new(r)
	k.mode = mode
	if day > 0:
		k.set_meta("day", day)
	ch_rooms.call("build", id, k, {})
	return k


func _chapter(ch: int) -> void:
	Chapters.current = ch
	var rooms: Script = Chapters.rooms3d()
	var inv: Script = load(str(Chapters.get_value("investigation")))
	var inv_rooms: Dictionary = inv.get_script_constant_map()["ROOMS"]
	var spaces: Dictionary = rooms.get_script_constant_map()["SPACES"]
	var ids: Array = inv_rooms.keys()
	for id in spaces.keys():
		if not ids.has(id):
			ids.append(id)
	var day_starts: Dictionary = Chapters.get_value("day_starts", {})
	var last_day := 0
	if not day_starts.is_empty():
		last_day = day_starts.values().max()
		for id in ids:
			var opens := int((inv_rooms.get(id, spaces.get(id, {})) as Dictionary).get("opens_day", 0))
			if opens < 1 or opens > last_day:
				_fail("ch%d %s: opens_day %d is not a day of the story" % [ch, id, opens])
	var door_map := {}
	for id in ids:
		var k := _build(rooms, id, "investigate", last_day)
		door_map[id] = k.doors.keys()
	for id in ids:
		for to in door_map[id]:
			if not ids.has(to):
				_fail("ch%d %s: door to unknown space %s" % [ch, id, to])
			elif not (door_map[to] as Array).has(id):
				_fail("ch%d %s: door to %s has no door back" % [ch, id, to])
	for id in ids:
		await _check_space(rooms, ch, id, "investigate", inv_rooms.get(id, {}), last_day)
	var free: Array = rooms.get_script_constant_map()["FREE_SPACES"]
	var days: Array = [Chapters.day_at("freetime")] if last_day == 0 else range(1, last_day)
	for day in days:
		var placed := {}
		for id in free:
			if not Chapters.room_open(inv_rooms.get(id, spaces.get(id, {})), int(day)):
				continue
			await _check_space(rooms, ch, id, "freetime", {}, int(day) if last_day > 0 else 0)
			var k := _build(rooms, id, "freetime", int(day) if last_day > 0 else 0)
			for cid in k.people.keys():
				if placed.has(cid):
					_fail("ch%d day %d: %s stands in both %s and %s" % [ch, day, cid, placed[cid], id])
				placed[cid] = id
		for cid in Cast.roster_alive():
			if cid != "mochi" and not placed.has(cid):
				_fail("ch%d day %d: %s has no Free Time spot" % [ch, day, cid])
	print("ch%d: %d spaces checked" % [ch, ids.size()])


func _check_space(rooms: Script, ch: int, id: String, mode: String, data: Dictionary, day: int = 0) -> void:
	var k := _build(rooms, id, mode, day)
	var standees := {}
	for cid in k.people.keys():
		standees[cid] = k.standee(cid, "normal", k.people[cid])
	for i in k.spots.size():
		standees["spot %d" % (i + 1)] = k.standee("mochi", "normal", k.spots[i])
	await physics_frame
	await physics_frame
	var name := "ch%d %s (%s%s)" % [ch, id, mode, " day %d" % day if day > 0 else ""]
	for h in data.get("hotspots", []):
		if not k.hot.has(str(h["id"])):
			_fail("%s: no 3D object for hotspot %s" % [name, h["id"]])
	var spare := k.spots.size()
	for p in data.get("people", []):
		if not k.people.has(str(p["char"])):
			spare -= 1
			if spare < 0:
				_fail("%s: no standing spot for %s" % [name, p["char"]])
	var starts: Array = []
	for to in k.doors.keys():
		var d: Dictionary = k.doors[to]
		starts.append((d["pos"] as Vector3) + Basis(Vector3.UP, float(d["rot"])) * Vector3(0, 0, 1.15))
	starts.append(k.spawn)
	var space: PhysicsDirectSpaceState3D = holder.get_world_3d().direct_space_state
	var reach := _flood(space, starts[0])
	for s in starts:
		if not _near_reached(reach, s, 0.6):
			_fail("%s: arrival spot %s can't be walked to from %s" % [name, s, starts[0]])
	var check := func(lbl: String, body: Node3D, at: Vector3) -> void:
		if not _usable(space, reach, body, at):
			_fail("%s: can't reach or see %s" % [name, lbl])
	for hid in k.hot.keys():
		check.call("hotspot " + str(hid), k.hot[hid]["body"], _center(k.hot[hid]["body"]))
	for cid in standees.keys():
		check.call("person " + str(cid), standees[cid]["body"], _center(standees[cid]["body"]))
	for to in k.doors.keys():
		var d: Dictionary = k.doors[to]
		if d["body"] != null:
			check.call("door to " + str(to), d["body"], _center(d["body"]))
	for lid in k.lifts.keys():
		check.call("lift " + str(lid), k.lifts[lid]["body"], _center(k.lifts[lid]["body"]))
	for nt in k.notes:
		check.call("note " + str(nt["label"]), nt["body"], _center(nt["body"]))
	for st in k.stairs_list:
		await _walk_stairs(name, k, st)


func _center(body: Node3D) -> Vector3:
	var cs: CollisionShape3D = body.get_child(0)
	return cs.global_position


func _key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x / STEP), roundi(p.y / 0.5), roundi(p.z / STEP))


func _ground(space: PhysicsDirectSpaceState3D, x: float, y: float, z: float) -> Variant:
	# a ray landing exactly on the seam between a ramp and a floor can report a side face: try a few nearby points
	for off in [Vector2.ZERO, Vector2(0.07, 0), Vector2(-0.07, 0), Vector2(0, 0.07), Vector2(0, -0.07)]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x + off.x, y + 0.55, z + off.y), Vector3(x + off.x, y - 0.6, z + off.y), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit["normal"] as Vector3).y >= 0.7:
			var p: Vector3 = hit["position"]
			return Vector3(x, p.y, z)
	return null


func _clear(space: PhysicsDirectSpaceState3D, p: Vector3, shape: CylinderShape3D) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.45 + shape.height / 2.0, 0))
	return space.intersect_shape(q, 1).is_empty()


## Everywhere a player-sized cylinder can walk to from `start`.
func _flood(space: PhysicsDirectSpaceState3D, start: Vector3) -> Array:
	var shape := CylinderShape3D.new()
	shape.radius = 0.27
	shape.height = 1.1
	var g: Variant = _ground(space, start.x, start.y + 0.1, start.z)
	if g == null:
		_fail("no floor under start %s" % [start])
		return []
	var seen := {}
	var out: Array = [g]
	seen[_key(g)] = true
	var i := 0
	while i < out.size() and out.size() < 60000:
		var p: Vector3 = out[i]
		i += 1
		for d in [Vector2(STEP, 0), Vector2(-STEP, 0), Vector2(0, STEP), Vector2(0, -STEP)]:
			var n: Variant = _ground(space, p.x + d.x, p.y, p.z + d.y)
			if n == null:
				continue
			var nv: Vector3 = n
			if absf(nv.y - p.y) > 0.22:
				continue
			var key := _key(nv)
			if seen.has(key):
				continue
			seen[key] = true
			if _clear(space, nv, shape):
				out.append(nv)
	return out


func _near_reached(reach: Array, p: Vector3, dist: float) -> bool:
	for r in reach:
		if (r as Vector3).distance_to(Vector3(p.x, (r as Vector3).y if absf(p.y - (r as Vector3).y) < 0.3 else p.y, p.z)) < dist:
			return true
	return false


func _usable(space: PhysicsDirectSpaceState3D, reach: Array, body: Node3D, at: Vector3) -> bool:
	for r in reach:
		var eye := (r as Vector3) + Vector3(0, Player3D.EYE, 0)
		if eye.distance_to(at) > REACH:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, at, 1 | 2)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] == body:
			return true
	return false


func _walk_stairs(name: String, k: Kit, st: Dictionary) -> void:
	var p := Player3D.new()
	holder.add_child(p)
	var bottom: Vector3 = st["bottom"]
	var top: Vector3 = st["top"]
	if bottom.y > top.y:
		var t := bottom
		bottom = top
		top = t
	var dir := Vector3(top.x - bottom.x, 0, top.z - bottom.z).normalized()
	p.place(bottom - dir * 0.3 + Vector3(0, 0.05, 0), top + dir * 3.0 + Vector3(0, 1.5, 0))
	p.enabled = true
	Input.action_press("move_forward")
	var limit := int((bottom.distance_to(top) + 2.0) / 2.6 * 120.0)
	for i in limit:
		await physics_frame
		if p.global_position.y >= top.y - 0.08:
			break
	Input.action_release("move_forward")
	if p.global_position.y < top.y - 0.12:
		_fail("%s: stairs %s -> %s stop at y=%.2f" % [name, bottom, top, p.global_position.y])
	holder.remove_child(p)
	p.free()
