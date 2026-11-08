extends RefCounted
## Chapter 1 (Yuzu Springs resort) 3D rooms for the walk-around version, plus the Free Time courtyard hub.
## Each builder recreates its 2D background (art/bg/<id>.svg) as a walkable room, places one 3D object
## per hotspot id from investigation_data.gd (k.hotspot), the people's standing spots (k.person) and the
## exits (k.door, following the resort map links). See kit.gd for the coordinate conventions.

const Style := preload("res://scripts/ui/style.gd")
const Kit := preload("res://scripts/world3d/kit.gd")


static func build(rid: String, k, names: Dictionary) -> void:
	k.names = names
	match rid:
		"bath":
			_bath(k)
		"changing":
			_changing(k)
		"sauna":
			_sauna(k)
		"garden":
			_garden(k)
		"lounge":
			_lounge(k)
		"storage":
			_storage(k)
		"giftshop":
			_giftshop(k)
		"dining":
			_dining(k)
		"hub":
			_hub(k)
		_:
			k.environment("indoor")
			k.shell(8.0, 8.0, 3.2)


# =================================================================== shared bits
static func _h(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)


## Bamboo fence from a to b (a straight run), 1.9 m high, with posts and rails.
static func _fence(k, a: Vector3, b: Vector3, h: float = 1.9) -> void:
	var d := b - a
	var len := d.length()
	var mid := (a + b) * 0.5
	var rot := atan2(d.x, d.z) + PI / 2.0
	k.box(Vector3(len, h, 0.08), mid + Vector3(0, h / 2.0, 0), k.bamboo(), true, null, rot)
	var rail: Material = k.mat(Color(0.26, 0.17, 0.09), 0.8)
	for yy in [0.45, h - 0.3]:
		k.box(Vector3(len, 0.06, 0.06), mid + Vector3(0, yy, 0) + Vector3(sin(rot + PI / 2.0), 0, cos(rot + PI / 2.0)) * 0.06, rail, false, null, rot)
	var n := int(len / 2.0)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		k.cyl(0.06, 0.06, h + 0.15, p + Vector3(0, (h + 0.15) / 2.0, 0), rail)


## Floating yuzu fruit.
static func _yuzu(k, p: Vector3, parent: Node = null, r: float = 0.085) -> void:
	k.sphere(r, p, k.mat(Color(1.0, 0.78, 0.12), 0.35), parent, Vector3.ONE, 12)
	k.sphere(r * 0.25, p + Vector3(0, r * 0.95, 0), k.mat(Color(0.3, 0.5, 0.15), 0.6), parent, Vector3(1, 0.5, 1), 6)


## Capybara-shaped mannequin (cream form) with an optional dress.
static func _mannequin(k, parent: Node3D, dress: Color, sparkle: bool = false) -> void:
	var cream: Material = k.mat(Color(0.93, 0.88, 0.78), 0.6)
	k.cyl(0.26, 0.3, 0.05, Vector3(0, 0.025, 0), k.wood_dark, parent)
	k.cyl(0.025, 0.025, 0.85, Vector3(0, 0.45, 0), k.brass, parent)
	if dress.a > 0.0:
		k.cyl(0.18, 0.4, 0.75, Vector3(0, 0.95, 0), k.mat(dress, 0.8), parent, false, 20)
		k.sphere(0.25, Vector3(0, 1.38, 0), k.mat(dress, 0.8), parent, Vector3(1.05, 0.95, 0.8))
	else:
		k.sphere(0.25, Vector3(0, 1.2, 0), cream, parent, Vector3(1.15, 1.7, 0.85))
	k.cyl(0.07, 0.09, 0.14, Vector3(0, 1.6, 0), cream, parent)
	k.sphere(0.2, Vector3(0, 1.8, 0), cream, parent, Vector3(1.0, 0.9, 1.0))
	k.sphere(0.11, Vector3(0, 1.75, 0.15), cream, parent, Vector3(1.0, 0.8, 1.1))
	for sx in [-0.12, 0.12]:
		k.sphere(0.05, Vector3(sx, 1.97, -0.02), cream, parent)
	if sparkle:
		k.torus(0.1, 0.13, Vector3(0, 1.58, 0), k.mat(Color(0.78, 0.66, 0.95), 0.4), parent)
		for i in 7:
			var a := i * TAU / 7.0
			k.sphere(0.015, Vector3(cos(a) * 0.14, 1.6 + 0.04 * sin(a * 3.0), sin(a) * 0.14), k.glow(Color(0.85, 0.75, 1.0), 4.0), parent)


## Building facade (for outdoor scenes): wall slab with timber frame and a roof edge.
static func _facade(k, x0: float, x1: float, z: float, h: float, wall_m: Material, timber: bool) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	k.box(Vector3(w, h, 0.3), Vector3(cx, h / 2.0, z - 0.15), wall_m, true)
	if timber:
		var tm: Material = k.mat(Color(0.24, 0.14, 0.08), 0.8)
		var n := maxi(int(w / 1.5), 1)
		for i in n + 1:
			k.box(Vector3(0.14, h, 0.06), Vector3(x0 + w * float(i) / n, h / 2.0, z + 0.02), tm)
		for yy in [0.12, 1.0, h - 0.15]:
			k.box(Vector3(w, 0.14, 0.06), Vector3(cx, yy, z + 0.02), tm)
	var roof: Material = k.mat(Color(0.2, 0.21, 0.26), 0.7)
	var r: MeshInstance3D = k.box(Vector3(w + 0.6, 0.16, 1.6), Vector3(cx, h + 0.35, z + 0.35), roof)
	r.rotation.x = 0.35
	k.box(Vector3(w + 0.6, 0.12, 0.12), Vector3(cx, h + 0.1, z + 1.05), k.mat(Color(0.14, 0.14, 0.17), 0.7))


static func _ceiling_light(k, pos: Vector3, h: float, energy: float = 1.2, shadows: bool = true) -> void:
	k.hanging_lamp(pos, Color(1.0, 0.84, 0.62), energy, h, shadows)


# =================================================================== Yuzu Bath (outdoor, morning)
static func _bath(k) -> void:
	var W := 12.0
	var D := 11.0
	k.bounds = Vector2(W, D)
	k.environment("outdoor_morning", Color(0.78, 0.82, 0.86), 0.55)
	k.sun(Vector3(-36, -28, 0), Color(1.0, 0.95, 0.88), 1.1)
	k.box(Vector3(W, 0.2, D), Vector3(0, -0.1, 0), k.stone_floor(Color(0.47, 0.47, 0.47), Color(0.63, 0.62, 0.6), 0.8, 0.65), true)
	# bathhouse wall behind the player, with a deep eave
	k.box(Vector3(W, 3.4, 0.3), Vector3(0, 1.7, D / 2.0 + 0.15), k.wood_wall(Color(0.26, 0.15, 0.08), Color(0.4, 0.25, 0.13)), true)
	var eave: MeshInstance3D = k.box(Vector3(W + 0.6, 0.16, 1.6), Vector3(0, 3.35, D / 2.0 - 0.6), k.mat(Color(0.18, 0.18, 0.22), 0.7))
	eave.rotation.x = -0.25
	k.paper_lantern(Vector3(-3.6, 2.6, D / 2.0 - 0.9), Color(1.0, 0.36, 0.26), 0.9, true, false, 0.8)
	k.paper_lantern(Vector3(3.6, 2.6, D / 2.0 - 0.9), Color(1.0, 0.36, 0.26), 0.9, true, false, 0.8)
	# bamboo fence around the bath
	_fence(k, Vector3(-W / 2.0, 0, -D / 2.0), Vector3(W / 2.0, 0, -D / 2.0))
	_fence(k, Vector3(-W / 2.0, 0, -D / 2.0), Vector3(-W / 2.0, 0, D / 2.0))
	_fence(k, Vector3(W / 2.0, 0, -D / 2.0), Vector3(W / 2.0, 0, D / 2.0))
	# wooden sign on the fence
	k.box(Vector3(1.6, 0.5, 0.06), Vector3(-2.2, 1.55, -D / 2.0 + 0.1), k.wood_light)
	k.label("YUZU BATH", Vector3(-2.2, 1.55, -D / 2.0 + 0.14), 0.0, 44, Color(0.25, 0.13, 0.06), null, 0.0035, 0)
	# distant hills and a pine or two beyond the fence
	for i in 6:
		var hill: Material = k.mat(Color(0.35, 0.48, 0.42).lerp(Color(0.66, 0.74, 0.8), 0.25 + 0.15 * (i % 2)), 1.0)
		k.sphere(1.0, Vector3(-18 + i * 7.0, -1.5, -20 - (i % 2) * 5.0), hill, null, Vector3(8, 5 + (i % 3), 4), 16)
	for px in [-4.5, 4.8]:
		k.cyl(0.12, 0.16, 3.6, Vector3(px, 1.8, -D / 2.0 - 1.2), k.wood_dark)
		k.sphere(1.0, Vector3(px, 3.9, -D / 2.0 - 1.2), k.mat(Color(0.18, 0.34, 0.22), 0.9), null, Vector3(1.4, 1.0, 1.4), 12)
	# the pool: an oval of glowing water inside a ring of rocks
	var pc := Vector3(0, 0, -1.4)
	var rx := 3.4
	var rz := 2.3
	var bottom: MeshInstance3D = k.cyl(1.0, 1.0, 0.1, pc + Vector3(0, 0.05, 0), k.mat(Color(0.1, 0.3, 0.3), 0.6), null, false, 48)
	bottom.scale = Vector3(rx, 1, rz)
	var water: MeshInstance3D = k.cyl(1.0, 1.0, 0.3, pc + Vector3(0, 0.17, 0), k.water(Color(0.05, 0.4, 0.42), Color(0.45, 0.9, 0.82), 0.32), null, false, 48)
	water.scale = Vector3(rx, 1, rz)
	k.blocker(Vector3(rx * 1.75, 1.2, rz * 1.75), pc + Vector3(0, 0.6, 0))
	k.blocker(Vector3(rx * 1.3, 1.2, rz * 2.0), pc + Vector3(0, 0.6, 0))
	k.blocker(Vector3(rx * 2.0, 1.2, rz * 1.2), pc + Vector3(0, 0.6, 0))
	var rock_m: Material = k.mat(Color(0.4, 0.4, 0.4), 0.45)
	var foam_m: Material = k.mat(Color(0.66, 0.84, 0.95), 0.95)
	for i in 30:
		var a := i * TAU / 30.0
		if absf(wrapf(a - 2.3, -PI, PI)) < 0.32 or absf(wrapf(a - 0.85, -PI, PI)) < 0.18:
			continue   # those rocks are the cushion / headband hotspots
		var p: Vector3 = pc + Vector3(cos(a) * (rx + 0.1), 0.16, sin(a) * (rz + 0.1))
		var s := 0.8 + 0.45 * _h(i)
		k.rock(p, Vector3(0.95, 0.5, 0.75) * s, rock_m, -a, false)
		if i % 3 == 1:
			k.sphere(0.3, p + Vector3(0, 0.26 * s, 0), foam_m, null, Vector3(1.3, 0.35, 1.0) * s, 12).rotation.y = -a
	k.steam(pc + Vector3(0, 0.45, 0), Vector3(rx * 0.75, 0.05, rz * 0.75), 30, 1.3, 0.11, 0.35, 4.5)
	for i in 12:
		var a := i * 2.399 + 0.4
		var rr := 0.35 + 0.55 * _h(i + 40)
		var p: Vector3 = pc + Vector3(cos(a) * rx * rr, 0.33, sin(a) * rz * rr)
		if p.distance_to(Vector3(0.25, 0.33, -1.0)) < 1.0 or p.distance_to(Vector3(-1.7, 0.33, -2.75)) < 0.7:
			continue
		_yuzu(k, p)
	# hotspot: the body, floating face-down (cartoon, non-graphic: striped shirt + captain hat)
	var body: Node3D = k.hotspot("body", Vector3(0.25, 0.3, -1.0), Vector3(1.6, 0.6, 1.5), Vector3(0, 0.1, 0))
	var shirt: MeshInstance3D = k.sphere(0.5, Vector3(0, 0.02, 0), k.stripes(Color(0.95, 0.95, 0.93), Color(0.16, 0.3, 0.6), 9.0), body, Vector3(0.7, 1.15, 0.38))
	shirt.rotation = Vector3(PI / 2.0, 0.3, 0)
	k.sphere(0.21, Vector3(-0.17, 0.0, 0.58), k.mat(Color(0.52, 0.34, 0.2), 0.8), body, Vector3(1, 0.8, 1))
	for sx in [-0.26, 0.24]:
		k.sphere(0.09, Vector3(sx * 1.6, 0.0, 0.25), k.mat(Color(0.52, 0.34, 0.2), 0.8), body, Vector3(1.6, 0.5, 0.7))
	var hat := Node3D.new()
	hat.position = Vector3(0.75, 0.06, 0.55)
	hat.rotation = Vector3(0.25, 0.6, 0.15)
	body.add_child(hat)
	k.cyl(0.17, 0.15, 0.13, Vector3(0, 0.065, 0), k.white, hat)
	k.cyl(0.2, 0.2, 0.02, Vector3(0, 0.0, 0), k.white, hat)
	k.box(Vector3(0.22, 0.02, 0.12), Vector3(0, 0.01, 0.16), k.black, false, hat)
	k.sphere(0.03, Vector3(0, 0.08, 0.16), k.brass, hat)
	# hotspot: foam-cushioned rocks (front left of the pool)
	var cush: Node3D = k.hotspot("cushion", pc + Vector3(cos(2.3) * (rx + 0.15), 0, sin(2.3) * (rz + 0.15)), Vector3(1.9, 0.9, 1.2), Vector3.ZERO, -2.3 + PI / 2.0)
	for j in 3:
		var off := Vector3(-0.55 + j * 0.55, 0.18, 0.05 * j)
		k.rock(off, Vector3(0.75, 0.5, 0.65), rock_m, 0.3 * j, false).reparent(cush, false)
		k.sphere(0.32, off + Vector3(0, 0.27, 0), foam_m, cush, Vector3(1.15, 0.4, 0.95))
	# hotspot: the red headband on the front-right rock
	var hb: Node3D = k.hotspot("headband", pc + Vector3(cos(0.85) * (rx + 0.15), 0, sin(0.85) * (rz + 0.15)), Vector3(1.0, 0.9, 0.9))
	var hr: MeshInstance3D = k.rock(Vector3(0, 0.17, 0), Vector3(0.9, 0.5, 0.75), rock_m, 0.4, false)
	hr.reparent(hb, false)
	k.torus(0.1, 0.15, Vector3(0.05, 0.43, 0.05), k.mat(Color(0.86, 0.1, 0.1), 0.7), hb, Vector3(0.12, 0, 0.1))
	k.box(Vector3(0.2, 0.012, 0.05), Vector3(0.22, 0.42, 0.12), k.mat(Color(0.86, 0.1, 0.1), 0.7), false, hb, 0.5)
	# hotspot: floating yuzu (a little cluster at the back left)
	var yz: Node3D = k.hotspot("yuzu", Vector3(-1.7, 0.32, -2.75), Vector3(1.1, 0.5, 0.8))
	for j in 5:
		_yuzu(k, Vector3(cos(j * 1.3) * 0.25, 0.02, sin(j * 1.3) * 0.18), yz, 0.1)
	k.box(Vector3(0.14, 0.01, 0.06), Vector3(0.12, 0.03, 0.2), k.mat(Color(0.3, 0.55, 0.2), 0.6), false, yz, 0.6)
	# hotspot: stone lantern behind the pool (right)
	var ln: Node3D = k.hotspot("lantern", Vector3(3.6, 0, -4.4), Vector3(1.0, 2.0, 1.0))
	k.stone_lantern(Vector3.ZERO, 1.3, true, ln)
	k.cctv(Vector3(W / 2.0 - 0.2, 2.1, -D / 2.0 + 0.6), -PI / 2.0 - 0.6)
	k.person("marigold", Vector3(4.3, 0, -0.6))
	k.person("bruno", Vector3(-4.3, 0, -0.8))
	k.door("changing", "", Vector3(0, 0, D / 2.0), PI, {"mat": k.wood_light})
	k.spawn = Vector3(0, 0, 4.0)
	k.look = Vector3(0, 0.5, -2.0)


# =================================================================== Changing Room
static func _changing(k) -> void:
	var W := 9.0
	var D := 8.0
	var H := 3.2
	k.environment("indoor", Color(0.62, 0.55, 0.48), 0.32)
	k.shell(W, D, H, {
		"floor": k.wood_floor(Color(0.34, 0.2, 0.1), Color(0.56, 0.37, 0.2)),
		"wall": k.mat(Color(0.88, 0.82, 0.7), 0.95),
		"wain": k.wood_wall(Color(0.36, 0.22, 0.12), Color(0.5, 0.32, 0.17)), "wain_h": 0.9,
		"ceiling": k.mat(Color(0.5, 0.36, 0.22), 0.8), "beams": true})
	_ceiling_light(k, Vector3(0, 2.75, -0.8), H, 1.4, true)
	_ceiling_light(k, Vector3(0, 2.75, 2.3), H, 0.7, false)
	# lockers (back left)
	var lk: Node3D = k.hotspot("lockers", Vector3(-2.5, 0, -D / 2.0 + 0.32), Vector3(3.3, 2.3, 0.9))
	k.box(Vector3(3.0, 2.15, 0.55), Vector3(0, 1.075, -0.05), k.wood_dark, true, lk)
	var door_m: Material = k.mat(Color(0.62, 0.42, 0.24), 0.6)
	for c in 4:
		for r in 3:
			var x := -1.08 + c * 0.72
			var y := 0.42 + r * 0.6 + 0.29
			k.box(Vector3(0.66, 0.54, 0.04), Vector3(x, y, 0.24), door_m, false, lk)
			k.box(Vector3(0.5, 0.05, 0.02), Vector3(x, y + 0.14, 0.27), k.wood_dark, false, lk)
			k.box(Vector3(0.5, 0.05, 0.02), Vector3(x, y + 0.08, 0.27), k.wood_dark, false, lk)
			k.cyl(0.05, 0.05, 0.01, Vector3(x, y - 0.12, 0.265), k.brass, lk).rotation.x = PI / 2.0
			k.label(str(c + 1 + (2 - r) * 4), Vector3(x, y - 0.12, 0.275), 0.0, 32, Color(0.2, 0.1, 0.05), lk, 0.0025, 0)
			k.sphere(0.018, Vector3(x + 0.24, y, 0.27), k.brass, lk)
	k.box(Vector3(3.0, 0.4, 0.6), Vector3(0, 0.2, -0.05), k.wood_dark, false, lk)
	# coat hooks with towels (back centre)
	var hk: Node3D = k.hotspot("hooks", Vector3(0.7, 1.45, -D / 2.0 + 0.1), Vector3(2.0, 1.1, 0.5), Vector3(0, 0.25, 0.1))
	k.box(Vector3(1.9, 0.1, 0.05), Vector3(0, 0.55, 0.02), k.wood_dark, false, hk)
	var towels := [Color(0.95, 0.95, 0.95), Color(0.62, 0.8, 0.95), Color(0.98, 0.72, 0.78), Color(0.95, 0.95, 0.95), Color(0.98, 0.8, 0.62)]
	for i in 5:
		var x := -0.72 + i * 0.36
		k.cyl(0.012, 0.012, 0.12, Vector3(x, 0.5, 0.08), k.brass, hk).rotation.x = PI / 2.0
		k.box(Vector3(0.26, 0.5, 0.05), Vector3(x, 0.22, 0.12), k.mat(towels[i], 0.95), false, hk)
		if i == 3:
			k.box(Vector3(0.1, 0.07, 0.02), Vector3(x, 0.66, 0.05), k.mat(Color(0.85, 0.1, 0.1), 0.6), false, hk)
	# side door (back right), ajar, morning light outside
	var sd: Node3D = k.hotspot("side_door", Vector3(2.7, 0, -D / 2.0 + 0.04), Vector3(1.4, 2.3, 0.7))
	k.box(Vector3(1.2, 2.25, 0.06), Vector3(0, 1.125, 0.02), k.wood_dark, false, sd)
	k.quad(Vector2(0.98, 2.08), Vector3(0, 1.05, 0.06), k.glow(Color(0.82, 0.95, 0.75), 1.4), sd)
	var hinge := Node3D.new()
	hinge.position = Vector3(-0.49, 0, 0.08)
	hinge.rotation.y = -0.55
	sd.add_child(hinge)
	k.box(Vector3(0.96, 2.05, 0.05), Vector3(0.48, 1.03, 0), k.mat(Color(0.6, 0.4, 0.22), 0.6), false, hinge)
	k.sphere(0.03, Vector3(0.86, 1.0, 0.04), k.brass, hinge)
	k.omni(Vector3(2.7, 1.4, -D / 2.0 + 0.6), Color(0.85, 1.0, 0.82), 0.7, 4.0)
	# round mirror and a little shelf
	var mir: MeshInstance3D = k.cyl(0.36, 0.36, 0.03, Vector3(-0.0, 0.0, 0.0), k.mat(Color(0.8, 0.86, 0.9), 0.05, 1.0))
	mir.position = Vector3(3.95, 1.85, -D / 2.0 + 0.05)
	mir.rotation.x = PI / 2.0
	k.torus(0.35, 0.41, Vector3(3.95, 1.85, -D / 2.0 + 0.05), k.wood_dark, null, Vector3(PI / 2.0, 0, 0))
	k.box(Vector3(0.8, 0.04, 0.2), Vector3(3.95, 1.3, -D / 2.0 + 0.1), k.wood_light)
	for i in 3:
		k.cyl(0.035, 0.035, 0.14, Vector3(3.7 + i * 0.22, 1.39, -D / 2.0 + 0.1), k.mat([Color(0.4, 0.75, 0.9), Color(0.95, 0.75, 0.3), Color(0.9, 0.5, 0.6)][i], 0.3))
	# bucket stack (middle of the room)
	var bk: Node3D = k.hotspot("buckets", Vector3(0.2, 0, -1.3), Vector3(1.2, 1.0, 0.9))
	var rows := [[-0.36, 0.0, 0.36], [-0.18, 0.18], [0.0]]
	for r in rows.size():
		for x in rows[r]:
			var b: Node3D = k.bucket(Vector3(float(x), r * 0.27 + 0.26, 0), 1.0, bk)
			b.rotation.x = PI
	for x in [-0.18, 0.18]:
		var b2: Node3D = k.bucket(Vector3(x, 0.26, -0.32), 1.0, bk)
		b2.rotation.x = PI
	k.blocker(Vector3(0.9, 0.9, 0.7), Vector3(0.2, 0.45, -1.42))
	# bench along the east wall + baskets
	k.box(Vector3(0.5, 0.45, 2.4), Vector3(W / 2.0 - 0.35, 0.225, 1.4), k.wood_light, true)
	for i in 2:
		k.box(Vector3(0.36, 0.2, 0.3), Vector3(W / 2.0 - 0.35, 0.55, 0.8 + i * 1.1), k.mat(Color(0.7, 0.55, 0.32), 0.9))
	k.cctv(Vector3(-W / 2.0 + 0.15, 2.85, D / 2.0 - 0.5), PI / 2.0 + 0.7)
	k.person("reginald", Vector3(2.3, 0, -0.4))
	k.door("bath", "", Vector3(W / 2.0, 0, -1.6), -PI / 2.0, {"mat": k.wood_light})
	k.door("sauna", "", Vector3(-W / 2.0, 0, 1.3), PI / 2.0, {"porthole": true})
	k.door("garden", "", Vector3(-2.2, 0, D / 2.0), PI)
	k.spawn = Vector3(0, 0, 2.6)
	k.look = Vector3(0, 1.25, -4.0)


# =================================================================== Sauna
static func _sauna(k) -> void:
	var W := 7.0
	var D := 6.5
	var H := 2.9
	k.environment("steam", Color(0.72, 0.5, 0.36), 0.32)
	var planks: Material = k.wood_wall(Color(0.5, 0.25, 0.1), Color(0.76, 0.44, 0.22), 0.14)
	k.shell(W, D, H, {"floor": k.wood_floor(Color(0.3, 0.15, 0.07), Color(0.46, 0.25, 0.12), 0.12),
		"wall": planks, "wain": null, "ceiling": planks, "trim": k.mat(Color(0.32, 0.16, 0.07), 0.8)})
	k.omni(Vector3(0, 2.5, 0.5), Color(1.0, 0.7, 0.45), 1.0, 7.0, true)
	# stove (back centre)
	var st: Node3D = k.hotspot("stove", Vector3(0, 0, -D / 2.0 + 0.62), Vector3(1.5, 1.6, 1.2))
	k.box(Vector3(1.0, 0.72, 0.75), Vector3(0, 0.36, 0), k.mat(Color(0.12, 0.12, 0.13), 0.5, 0.6), true, st)
	k.box(Vector3(0.42, 0.22, 0.02), Vector3(0, 0.3, 0.38), k.glow(Color(1.0, 0.45, 0.12), 3.5), false, st)
	var cage: Material = k.mat(Color(0.2, 0.2, 0.22), 0.4, 0.7)
	for i in 9:
		var x := -0.48 + i * 0.12
		k.box(Vector3(0.02, 0.5, 0.02), Vector3(x, 0.97, 0.37), cage, false, st)
		k.box(Vector3(0.02, 0.5, 0.02), Vector3(x, 0.97, -0.37), cage, false, st)
	for z in [-0.37, -0.12, 0.12, 0.37]:
		k.box(Vector3(0.02, 0.5, 0.02), Vector3(-0.49, 0.97, z), cage, false, st)
		k.box(Vector3(0.02, 0.5, 0.02), Vector3(0.49, 0.97, z), cage, false, st)
	k.box(Vector3(1.0, 0.03, 0.76), Vector3(0, 1.22, 0), cage, false, st)
	var rock_m: Material = k.mat(Color(0.36, 0.35, 0.36), 0.8)
	for i in 16:
		k.sphere(0.12, Vector3(-0.36 + (i % 4) * 0.24, 0.82 + (i / 4) * 0.06, -0.24 + ((i / 4) % 4) * 0.16), rock_m, st, Vector3(1.0, 0.75, 0.9), 8)
	k.omni(Vector3(0, 0.6, -D / 2.0 + 1.2), Color(1.0, 0.5, 0.2), 1.2, 4.0)
	k.steam(Vector3(0, 1.3, -D / 2.0 + 0.62), Vector3(0.35, 0.05, 0.25), 16, 0.9, 0.2, 0.5, 3.0)
	# benches: two tiers along the west wall
	var bn: Node3D = k.hotspot("benches", Vector3(-W / 2.0 + 0.85, 0, 0.3), Vector3(1.8, 1.25, 4.4))
	var bench_m: Material = k.wood_floor(Color(0.6, 0.34, 0.16), Color(0.82, 0.52, 0.28), 0.1)
	k.box(Vector3(0.6, 0.07, 4.0), Vector3(0.35, 0.45, 0), bench_m, false, bn)
	k.box(Vector3(0.6, 0.42, 4.0), Vector3(0.35, 0.21, 0), k.mat(Color(0.42, 0.22, 0.1), 0.8), false, bn)
	k.box(Vector3(0.65, 0.07, 4.0), Vector3(-0.3, 0.9, 0), bench_m, false, bn)
	k.box(Vector3(0.65, 0.87, 4.0), Vector3(-0.3, 0.43, 0), k.mat(Color(0.4, 0.2, 0.09), 0.8), false, bn)
	k.box(Vector3(0.5, 0.06, 0.32), Vector3(-0.3, 0.96, 1.1), k.white, false, bn)
	k.bucket(Vector3(0.35, 0.49, -1.2), 0.8, bn)
	k.blocker(Vector3(1.4, 1.0, 4.0), Vector3(-W / 2.0 + 0.75, 0.5, 0.3))
	# door panel (right of the stove)
	var pn: Node3D = k.hotspot("panel", Vector3(1.75, 1.35, -D / 2.0 + 0.05), Vector3(0.7, 0.8, 0.4), Vector3(0, 0, 0.12))
	k.box(Vector3(0.34, 0.48, 0.06), Vector3(0, 0, 0.03), k.mat(Color(0.75, 0.76, 0.74), 0.4, 0.3), false, pn)
	k.box(Vector3(0.26, 0.13, 0.01), Vector3(0, 0.1, 0.065), k.glow(Color(0.25, 0.9, 0.5), 1.6), false, pn)
	k.label("90°C", Vector3(0, 0.1, 0.075), 0.0, 32, Color(0.05, 0.2, 0.08), pn, 0.0022, 0)
	for i in 3:
		k.sphere(0.022, Vector3(-0.08 + i * 0.08, -0.1, 0.07), k.glow([Color(0.9, 0.2, 0.15), Color(0.95, 0.75, 0.2), Color(0.2, 0.8, 0.3)][i], 1.5), pn)
	k.box(Vector3(0.2, 0.06, 0.02), Vector3(0, -0.18, 0.065), k.black, false, pn)
	# hourglass + thermometer (back left), vent
	var hg := Vector3(-1.5, 1.5, -D / 2.0 + 0.12)
	k.box(Vector3(0.22, 0.03, 0.16), hg + Vector3(0, 0.22, 0), k.wood_dark)
	k.box(Vector3(0.22, 0.03, 0.16), hg + Vector3(0, -0.22, 0), k.wood_dark)
	var glass: Material = k.mat(Color(0.9, 0.95, 1.0, 1.0), 0.05)
	k.cyl(0.08, 0.015, 0.2, hg + Vector3(0, 0.1, 0), glass)
	k.cyl(0.015, 0.08, 0.2, hg + Vector3(0, -0.1, 0), glass)
	k.cyl(0.0, 0.06, 0.08, hg + Vector3(0, -0.16, 0), k.mat(Color(0.95, 0.8, 0.45), 0.9))
	k.box(Vector3(0.1, 0.5, 0.03), Vector3(-1.0, 1.55, -D / 2.0 + 0.04), k.white)
	k.box(Vector3(0.02, 0.32, 0.01), Vector3(-1.0, 1.52, -D / 2.0 + 0.06), k.mat(Color(0.85, 0.1, 0.1), 0.5))
	k.box(Vector3(0.4, 0.3, 0.04), Vector3(-2.6, 2.45, -D / 2.0 + 0.03), k.mat(Color(0.25, 0.14, 0.07), 0.8))
	k.door("changing", "", Vector3(W / 2.0, 0, -1.2), -PI / 2.0, {"porthole": true, "mat": k.mat(Color(0.6, 0.36, 0.18), 0.6)})
	k.person("zuzu", Vector3(-1.1, 0, -0.4))
	k.person("nibs", Vector3(1.9, 0, -0.3))
	k.spawn = Vector3(0.4, 0, 2.3)
	k.look = Vector3(0, 1.1, -3.2)


# =================================================================== Garden Path (outdoor, morning)
static func _garden(k) -> void:
	var W := 12.0
	var D := 11.0
	k.bounds = Vector2(W, D)
	k.environment("outdoor_morning", Color(0.8, 0.85, 0.8), 0.6)
	k.sun(Vector3(-48, 32, 0), Color(1.0, 0.96, 0.86), 1.2)
	k.box(Vector3(W + 6, 0.2, D + 6), Vector3(0, -0.1, -1.5), k.smat(Kit.SH_GRASS), true)
	# two buildings: the lounge annex (white plaster + timber) and the bathhouse (dark wood)
	_facade(k, -W / 2.0 - 1.0, -0.7, -4.6, 3.2, k.mat(Color(0.9, 0.87, 0.8), 0.95), true)
	_facade(k, 0.7, W / 2.0 + 1.0, -4.6, 3.2, k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.44, 0.28, 0.15)), false)
	k.shoji(Vector2(1.3, 0.9), Vector3(-4.6, 1.75, -4.58), 0.0, Color(0.95, 0.9, 0.82), 0.4, Vector2(3, 2), false)
	k.box(Vector3(1.2, 0.8, 0.05), Vector3(4.4, 1.8, -4.57), k.glow(Color(0.85, 0.85, 0.75), 0.3))
	for x in [3.85, 4.4, 4.95]:
		k.box(Vector3(0.04, 0.8, 0.03), Vector3(x, 1.8, -4.53), k.wood_dark)
	# beyond: fence, an autumn tree and the sky
	_fence(k, Vector3(-0.7, 0, -6.0), Vector3(0.7, 0, -6.0), 1.6)
	k.cyl(0.14, 0.2, 2.6, Vector3(0.4, 1.3, -7.6), k.wood_dark)
	for i in 5:
		k.sphere(0.9, Vector3(0.4 + cos(i * 1.3) * 0.6, 3.0 + sin(i * 2.1) * 0.35, -7.6 + sin(i * 1.3) * 0.4), k.mat(Color(0.95, 0.52, 0.2).lerp(Color(0.85, 0.32, 0.15), _h(i)), 0.9), null, Vector3.ONE, 12)
	# hedges along the facades
	for x in [-5.4, -4.1, 4.1, 5.4, -1.4, 1.4]:
		k.sphere(0.45, Vector3(x, 0.3, -4.1), k.mat(Color(0.2, 0.42, 0.2), 0.9), null, Vector3(1.4, 0.8, 0.9), 12)
	# hotspot: lounge back door (left building)
	var ld: Node3D = k.hotspot("lounge_door", Vector3(-2.6, 0, -4.58), Vector3(1.3, 2.4, 0.6))
	k.box(Vector3(1.15, 2.2, 0.06), Vector3(0, 1.1, 0.02), k.wood_dark, false, ld)
	k.box(Vector3(0.95, 2.05, 0.05), Vector3(0, 1.03, 0.06), k.mat(Color(0.52, 0.32, 0.18), 0.6), false, ld)
	k.box(Vector3(0.55, 0.45, 0.02), Vector3(0, 1.55, 0.09), k.glow(Color(0.9, 0.85, 0.7), 0.35), false, ld)
	k.sphere(0.035, Vector3(0.36, 1.0, 0.1), k.brass, ld)
	# hotspot: bathhouse side door (right building)
	var bd: Node3D = k.hotspot("bath_door", Vector3(2.6, 0, -4.58), Vector3(1.3, 2.4, 0.6))
	k.box(Vector3(1.15, 2.2, 0.06), Vector3(0, 1.1, 0.02), k.mat(Color(0.16, 0.09, 0.05), 0.8), false, bd)
	k.box(Vector3(0.95, 2.05, 0.05), Vector3(0, 1.03, 0.06), k.mat(Color(0.42, 0.26, 0.14), 0.6), false, bd)
	k.box(Vector3(0.6, 0.4, 0.02), Vector3(0, 1.6, 0.09), k.mat(Color(0.92, 0.9, 0.84), 0.9), false, bd)
	for x in [-0.15, 0.0, 0.15]:
		k.box(Vector3(0.025, 0.4, 0.02), Vector3(x, 1.6, 0.1), k.wood_dark, false, bd)
	k.sphere(0.035, Vector3(-0.36, 1.0, 0.1), k.brass, bd)
	k.box(Vector3(0.7, 0.22, 0.03), Vector3(0, 2.38, 0.06), k.wood_light, false, bd)
	# hotspot: rose bush (centre)
	var rb: Node3D = k.hotspot("rosebush", Vector3(0, 0, -2.0), Vector3(1.6, 1.3, 1.4))
	var leaf: Material = k.mat(Color(0.18, 0.42, 0.16), 0.85)
	var rose: Material = k.mat(Color(0.86, 0.1, 0.14), 0.6)
	for i in 7:
		var a := i * TAU / 7.0
		k.sphere(0.36, Vector3(cos(a) * 0.38, 0.42 + 0.12 * _h(i), sin(a) * 0.3), leaf, rb, Vector3(1, 0.85, 1), 12)
	k.sphere(0.42, Vector3(0, 0.7, 0), leaf, rb, Vector3.ONE, 12)
	for i in 18:
		var a := i * 2.399
		var r := 0.25 + 0.4 * _h(i + 7)
		k.sphere(0.07, Vector3(cos(a) * r, 0.5 + 0.55 * _h(i + 3), sin(a) * r * 0.8 + 0.12), rose, rb, Vector3.ONE, 8)
	k.blocker(Vector3(1.2, 1.2, 1.0), Vector3(0, 0.6, -2.0))
	# stepping-stone path; the front part is the "path" hotspot
	var stone_m: Material = k.mat(Color(0.82, 0.82, 0.8), 0.85)
	var path: Node3D = k.hotspot("path", Vector3(0, 0, 1.2), Vector3(2.4, 0.3, 4.0), Vector3(0, 0.1, 0))
	var front := [Vector3(-0.2, 0, 1.6), Vector3(0.35, 0, 0.95), Vector3(-0.15, 0, 0.3), Vector3(0.3, 0, -0.35), Vector3(-0.3, 0, -0.95), Vector3(0.1, 0, 2.3)]
	for i in front.size():
		var s: MeshInstance3D = k.cyl(0.34 + 0.06 * _h(i), 0.36 + 0.06 * _h(i), 0.06, (front[i] as Vector3) + Vector3(0, 0.03, 0), stone_m, path, false, 14)
		s.scale = Vector3(1.2, 1, 0.85)
	var back := [Vector3(-0.9, 0, -2.6), Vector3(-1.7, 0, -3.3), Vector3(-2.5, 0, -3.9), Vector3(0.9, 0, -2.6), Vector3(1.7, 0, -3.3), Vector3(2.5, 0, -3.9)]
	for i in back.size():
		var s2: MeshInstance3D = k.cyl(0.3, 0.32, 0.06, (back[i] as Vector3) + Vector3(0, 0.03, 0), stone_m, null, false, 14)
		s2.scale = Vector3(1.2, 1, 0.85)
	k.stone_lantern(Vector3(-4.6, 0, -2.3), 1.1, false)
	k.stone_lantern(Vector3(4.6, 0, -2.3), 1.1, false)
	# boundaries: fences with gates (exits) on the sides, fence behind the player
	_fence(k, Vector3(-W / 2.0, 0, -4.6), Vector3(-W / 2.0, 0, D / 2.0))
	_fence(k, Vector3(W / 2.0, 0, -4.6), Vector3(W / 2.0, 0, D / 2.0))
	_fence(k, Vector3(-W / 2.0, 0, D / 2.0), Vector3(W / 2.0, 0, D / 2.0))
	k.door("lounge", "", Vector3(-W / 2.0 + 0.06, 0, 0.6), PI / 2.0)
	k.door("changing", "", Vector3(W / 2.0 - 0.06, 0, 0.6), -PI / 2.0)
	k.cctv(Vector3(-0.75, 2.9, -4.4), 0.4)
	k.person("bramble", Vector3(-3.0, 0, 0.4))
	k.spawn = Vector3(0, 0, 4.0)
	k.look = Vector3(0, 1.1, -4.0)


# =================================================================== Lounge
static func _lounge(k) -> void:
	var W := 10.0
	var D := 9.0
	var H := 3.4
	k.environment("indoor", Color(0.55, 0.42, 0.55), 0.3)
	k.shell(W, D, H, {
		"floor": k.wood_floor(Color(0.2, 0.09, 0.07), Color(0.36, 0.17, 0.11)),
		"wall": k.mat(Color(0.34, 0.12, 0.25), 0.9),
		"wain": k.wood_wall(Color(0.2, 0.08, 0.07), Color(0.3, 0.13, 0.1)), "wain_h": 1.0,
		"trim": k.mat(Color(0.8, 0.6, 0.25), 0.35, 0.7),
		"ceiling": k.mat(Color(0.16, 0.07, 0.12), 0.9)})
	var gold: Material = k.mat(Color(0.9, 0.7, 0.3), 0.3, 0.85)
	var velvet: Material = k.mat(Color(0.62, 0.06, 0.1), 0.85)
	# hotspot: stage & curtain
	var sg: Node3D = k.hotspot("stage", Vector3(0, 0, -D / 2.0 + 1.05), Vector3(5.0, 3.1, 2.0))
	k.box(Vector3(4.6, 0.5, 1.9), Vector3(0, 0.25, 0), k.wood_floor(Color(0.3, 0.16, 0.08), Color(0.45, 0.26, 0.13)), true, sg)
	k.box(Vector3(4.66, 0.08, 0.06), Vector3(0, 0.48, 0.96), gold, false, sg)
	for i in 8:
		k.sphere(0.035, Vector3(-2.0 + i * 0.57, 0.53, 0.88), k.glow(Color(1.0, 0.85, 0.5), 4.0), sg)
	for sx in [-2.45, 2.45]:
		k.box(Vector3(0.35, 3.0, 0.3), Vector3(sx, 1.5, -0.8), k.mat(Color(0.42, 0.06, 0.1), 0.8), false, sg)
		k.box(Vector3(0.08, 3.0, 0.32), Vector3(sx + (0.15 if sx < 0 else -0.15), 1.5, -0.8), gold, false, sg)
	k.box(Vector3(5.25, 0.5, 0.32), Vector3(0, 2.95, -0.8), k.mat(Color(0.42, 0.06, 0.1), 0.8), false, sg)
	k.box(Vector3(5.25, 0.06, 0.34), Vector3(0, 2.72, -0.8), gold, false, sg)
	k.box(Vector3(4.6, 2.4, 0.05), Vector3(0, 1.7, -0.95), k.mat(Color(0.06, 0.03, 0.06), 0.9), false, sg)
	for i in 11:
		k.cyl(0.12, 0.12, 2.25, Vector3(-2.15 + i * 0.205, 1.62, -0.72 + 0.04 * (i % 2)), velvet, sg, false, 10)
	for i in 4:
		k.cyl(0.13, 0.11, 2.25, Vector3(1.75 + i * 0.16, 1.62, -0.7 + 0.05 * (i % 2)), velvet, sg, false, 10)
	k.torus(0.18, 0.22, Vector3(2.0, 1.4, -0.6), gold, sg, Vector3(PI / 2.0, 0, 0))
	k.spot(Vector3(0, H - 0.1, 0.2), Vector3(0, 0.5, -D / 2.0 + 1.0), Color(1.0, 0.85, 0.65), 2.0, 7.0, 32.0, true)
	# hotspot: front-row seats
	var cg: Node3D = k.hotspot("chairs", Vector3(0, 0, -1.4), Vector3(3.0, 1.0, 0.9))
	for i in 4:
		k.chair(Vector3(-1.05 + i * 0.7, 0, 0), PI, velvet, gold, cg)
	for i in 6:
		k.sphere(0.012, Vector3(-0.35 + 0.08 * cos(i * 2.0), 0.52, 0.06 * sin(i * 2.4)), k.glow(Color(1.0, 0.75, 0.95), 5.0), cg)
	# hotspot: back door (right of the stage) with an exit sign
	var bd: Node3D = k.hotspot("back_door", Vector3(3.7, 0, -D / 2.0 + 0.05), Vector3(1.3, 2.6, 0.6))
	k.box(Vector3(1.15, 2.25, 0.06), Vector3(0, 1.125, 0.02), k.wood_dark, false, bd)
	k.box(Vector3(0.95, 2.1, 0.05), Vector3(0, 1.05, 0.06), k.mat(Color(0.4, 0.22, 0.14), 0.6), false, bd)
	for yy in [0.6, 1.5]:
		k.box(Vector3(0.7, 0.6, 0.02), Vector3(0, yy, 0.09), k.mat(Color(0.32, 0.17, 0.1), 0.6), false, bd)
	k.sphere(0.04, Vector3(0.35, 1.05, 0.11), k.brass, bd)
	k.box(Vector3(0.5, 0.2, 0.05), Vector3(0, 2.45, 0.05), k.glow(Color(0.2, 0.95, 0.45), 2.0), false, bd)
	k.label("EXIT", Vector3(0, 2.45, 0.085), 0.0, 36, Color(0.02, 0.2, 0.06), bd, 0.0028, 0)
	# poster (left of the stage), chandelier, sconces, a little bar table
	k.box(Vector3(1.0, 1.35, 0.05), Vector3(-3.7, 1.75, -D / 2.0 + 0.03), gold)
	k.box(Vector3(0.88, 1.22, 0.02), Vector3(-3.7, 1.75, -D / 2.0 + 0.06), k.mat(Color(0.12, 0.06, 0.22), 0.8))
	k.sphere(0.2, Vector3(-3.7, 1.55, -D / 2.0 + 0.08), k.mat(Color(0.02, 0.02, 0.04), 0.9), null, Vector3(1.2, 0.9, 0.1))
	k.cyl(0.1, 0.14, 0.24, Vector3(-3.7, 1.86, -D / 2.0 + 0.08), k.mat(Color(0.02, 0.02, 0.04), 0.9))
	for i in 9:
		k.sphere(0.018, Vector3(-4.05 + 0.08 * i, 2.2 + 0.08 * sin(i * 1.7), -D / 2.0 + 0.08), k.glow(Color(1.0, 0.9, 0.5), 3.0))
	k.cyl(0.6, 0.5, 0.08, Vector3(0, 2.75, -1.0), gold)
	for i in 8:
		var a := i * TAU / 8.0
		k.sphere(0.05, Vector3(cos(a) * 0.55, 2.86, -1.0 + sin(a) * 0.55), k.glow(Color(1.0, 0.85, 0.55), 4.0))
	k.cyl(0.008, 0.008, 0.6, Vector3(0, 3.1, -1.0), k.black)
	k.omni(Vector3(0, 2.6, -1.0), Color(1.0, 0.82, 0.6), 1.1, 7.0, true)
	k.wall_lamp(Vector3(-2.9, 2.0, -D / 2.0), 0.0, Color(1.0, 0.8, 0.55), 0.6)
	k.wall_lamp(Vector3(2.9, 2.0, -D / 2.0), 0.0, Color(1.0, 0.8, 0.55), 0.6)
	k.table(Vector3(W / 2.0 - 0.5, 0, 1.6), Vector3(0.6, 0.95, 1.4), k.wood_dark, k.wood_dark)
	for i in 3:
		k.cyl(0.04, 0.05, 0.28, Vector3(W / 2.0 - 0.5, 1.09, 1.2 + i * 0.3), k.mat([Color(0.2, 0.6, 0.4), Color(0.75, 0.35, 0.15), Color(0.7, 0.1, 0.2)][i], 0.15))
	k.cctv(Vector3(W / 2.0 - 0.15, 2.95, D / 2.0 - 0.5), -PI / 2.0 - 0.7)
	k.person("lulu", Vector3(-2.7, 0, -0.4))
	k.person("wisp", Vector3(2.7, 0, -0.5))
	k.door("garden", "", Vector3(W / 2.0, 0, -2.4), -PI / 2.0)
	k.door("storage", "", Vector3(-W / 2.0, 0, -2.4), PI / 2.0)
	k.door("dining", "", Vector3(-2.4, 0, D / 2.0), PI)
	k.door("giftshop", "", Vector3(2.4, 0, D / 2.0), PI)
	k.spawn = Vector3(0, 0, 3.0)
	k.look = Vector3(0, 1.3, -4.5)


# =================================================================== Storage Closet
static func _storage(k) -> void:
	var W := 7.0
	var D := 6.5
	var H := 3.0
	k.environment("dim", Color(0.42, 0.38, 0.52), 0.24)
	k.shell(W, D, H, {
		"floor": k.wood_floor(Color(0.15, 0.12, 0.12), Color(0.27, 0.22, 0.2)),
		"wall": k.wood_wall(Color(0.17, 0.14, 0.2), Color(0.27, 0.23, 0.3), 0.22), "wain": null,
		"ceiling": k.mat(Color(0.1, 0.09, 0.12), 0.9), "trim": k.mat(Color(0.1, 0.08, 0.1), 0.9)})
	k.cyl(0.008, 0.008, 0.5, Vector3(-0.3, H - 0.25, -1.2), k.black)
	k.sphere(0.07, Vector3(-0.3, H - 0.55, -1.2), k.glow(Color(1.0, 0.88, 0.62), 5.0))
	k.omni(Vector3(-0.3, H - 0.75, -1.2), Color(1.0, 0.84, 0.6), 1.2, 6.5, true)
	k.spot(Vector3(-0.3, H - 0.1, -0.9), Vector3(-0.3, 0, -1.6), Color(1.0, 0.92, 0.75), 2.4, 5.0, 24.0, true)
	# hotspot: mannequin (centre, in the light)
	var mq: Node3D = k.hotspot("mannequin", Vector3(-0.3, 0, -1.6), Vector3(0.9, 2.1, 0.9))
	_mannequin(k, mq, Color(0, 0, 0, 0), true)
	k.blocker(Vector3(0.6, 1.8, 0.6), Vector3(-0.3, 0.9, -1.6))
	# hotspot: magic trunk (right)
	var tk: Node3D = k.hotspot("trunk", Vector3(1.9, 0, -1.9), Vector3(1.4, 1.3, 1.0), Vector3.ZERO, -0.3)
	var purple: Material = k.mat(Color(0.32, 0.12, 0.5), 0.5)
	var gold: Material = k.mat(Color(0.95, 0.75, 0.3), 0.3, 0.85)
	k.box(Vector3(1.1, 0.8, 0.7), Vector3(0, 0.4, 0), purple, true, tk)
	k.box(Vector3(1.14, 0.16, 0.74), Vector3(0, 0.88, 0), k.mat(Color(0.25, 0.08, 0.4), 0.5), false, tk)
	for sx in [-0.55, 0.55]:
		for sz in [-0.35, 0.35]:
			k.sphere(0.05, Vector3(sx, 0.95, sz), gold, tk)
			k.sphere(0.05, Vector3(sx, 0.04, sz), gold, tk)
	for i in 5:
		var star: MeshInstance3D = k.box(Vector3(0.09, 0.09, 0.01), Vector3(-0.4 + i * 0.2, 0.3 + 0.25 * (i % 2), 0.36), gold, false, tk)
		star.rotation.z = PI / 4.0
	k.box(Vector3(0.14, 0.16, 0.04), Vector3(0, 0.75, 0.37), gold, false, tk)
	# hotspot: prop boxes on a shelf (back left)
	var bx: Node3D = k.hotspot("boxes", Vector3(-2.3, 0, -D / 2.0 + 0.45), Vector3(1.4, 2.2, 0.9))
	for sx in [-0.62, 0.62]:
		k.box(Vector3(0.05, 2.0, 0.6), Vector3(sx, 1.0, 0), k.wood_dark, false, bx)
	for yy in [0.5, 1.2, 1.9]:
		k.box(Vector3(1.3, 0.04, 0.6), Vector3(0, yy, 0), k.wood_mid, false, bx)
	var card: Material = k.mat(Color(0.72, 0.56, 0.36), 0.95)
	k.box(Vector3(0.7, 0.42, 0.45), Vector3(-0.2, 0.73, 0), card, false, bx)
	k.box(Vector3(0.45, 0.3, 0.4), Vector3(0.35, 0.67, 0), card, false, bx)
	k.box(Vector3(0.9, 0.38, 0.48), Vector3(0.05, 1.41, 0), k.mat(Color(0.82, 0.68, 0.5), 0.95), false, bx)
	k.box(Vector3(0.5, 0.25, 0.4), Vector3(-0.2, 2.04, 0), card, false, bx)
	for p in [Vector3(-0.2, 0.75, 0.23), Vector3(0.05, 1.42, 0.25), Vector3(-0.2, 2.05, 0.21)]:
		k.box(Vector3(0.22, 0.1, 0.01), p, k.paper, false, bx)
	k.blocker(Vector3(1.3, 2.0, 0.6), Vector3(-2.3, 1.0, -D / 2.0 + 0.45))
	# costume rack (west wall), ropes and a sandbag (right)
	var rack := Vector3(-W / 2.0 + 0.5, 0, 0.9)
	k.box(Vector3(0.04, 1.8, 0.04), rack + Vector3(0, 0.9, -0.8), k.steel)
	k.box(Vector3(0.04, 1.8, 0.04), rack + Vector3(0, 0.9, 0.8), k.steel)
	k.box(Vector3(0.03, 0.03, 1.65), rack + Vector3(0, 1.78, 0), k.steel)
	var cols := [Color(0.25, 0.2, 0.55), Color(0.5, 0.1, 0.2), Color(0.15, 0.4, 0.35), Color(0.55, 0.12, 0.45), Color(0.2, 0.25, 0.5)]
	for i in 5:
		k.box(Vector3(0.36, 1.0, 0.07), rack + Vector3(0, 1.22, -0.6 + i * 0.3), k.mat(cols[i], 0.9), false, null, PI / 2.0)
	k.blocker(Vector3(0.6, 1.8, 1.8), rack + Vector3(0, 0.9, 0))
	for i in 2:
		k.cyl(0.012, 0.012, 2.2, Vector3(2.9 + i * 0.25, H - 1.1, 0.4), k.mat(Color(0.6, 0.5, 0.35), 0.9))
	k.sphere(0.16, Vector3(3.15, 0.85, 0.4), k.mat(Color(0.55, 0.45, 0.3), 0.95), null, Vector3(1, 1.3, 1))
	k.cctv(Vector3(W / 2.0 - 0.15, 2.6, -D / 2.0 + 0.4), -PI / 4.0)
	k.person("tumble", Vector3(-1.7, 0, -0.4))
	k.door("lounge", "", Vector3(1.6, 0, D / 2.0), PI)
	k.spawn = Vector3(0.4, 0, 2.2)
	k.look = Vector3(0, 1.1, -3.0)


# =================================================================== Gift Shop
static func _giftshop(k) -> void:
	var W := 10.0
	var D := 8.0
	var H := 3.2
	k.environment("indoor", Color(0.66, 0.58, 0.5), 0.35)
	k.shell(W, D, H, {
		"floor": k.wood_floor(Color(0.42, 0.26, 0.13), Color(0.66, 0.45, 0.25)),
		"wall": k.mat(Color(0.92, 0.85, 0.72), 0.95),
		"wain": k.wood_wall(Color(0.4, 0.25, 0.13), Color(0.55, 0.36, 0.2)), "wain_h": 0.95,
		"ceiling": k.mat(Color(0.75, 0.62, 0.46), 0.9)})
	_ceiling_light(k, Vector3(-1.8, 2.75, -0.8), H, 1.0, true)
	_ceiling_light(k, Vector3(1.8, 2.75, -0.8), H, 1.0, false)
	# bunting along the back wall
	var flag_cols := [Color(0.95, 0.35, 0.35), Color(1.0, 0.8, 0.25), Color(0.35, 0.8, 0.75), Color(0.6, 0.45, 0.85), Color(0.45, 0.75, 0.35)]
	for i in 22:
		var f: MeshInstance3D = k.prism(Vector3(0.28, 0.32, 0.01), Vector3(-W / 2.0 + 0.3 + i * 0.44, 2.82 - 0.06 * sin(i * 0.72), -D / 2.0 + 0.06), k.mat(flag_cols[i % 5], 0.9))
		f.rotation.z = PI
	# hotspot: shelves of plushies (back centre)
	var sh: Node3D = k.hotspot("shelves", Vector3(0, 0, -D / 2.0 + 0.3), Vector3(3.8, 2.5, 0.8))
	k.box(Vector3(3.5, 0.95, 0.5), Vector3(0, 0.475, 0), k.wood_mid, true, sh)
	k.box(Vector3(3.5, 1.3, 0.06), Vector3(0, 1.6, -0.2), k.wood_dark, false, sh)
	for yy in [1.0, 1.45, 1.9, 2.25]:
		k.box(Vector3(3.5, 0.04, 0.36), Vector3(0, yy, -0.04), k.wood_light, false, sh)
	var plush: Material = k.mat(Color(0.6, 0.4, 0.24), 0.95)
	for row in 2:
		for i in 8:
			var p := Vector3(-1.5 + i * 0.43, 1.12 + row * 0.45, 0.0)
			k.sphere(0.12, p, plush, sh, Vector3(1.1, 0.85, 0.9), 10)
			k.sphere(0.09, p + Vector3(0, 0.14, 0.03), plush, sh, Vector3(1.1, 0.95, 1.0), 10)
			k.sphere(0.04, p + Vector3(0, 0.12, 0.11), k.mat(Color(0.4, 0.25, 0.15), 0.9), sh, Vector3(1.3, 0.8, 1.0), 6)
			if (i + row) % 3 == 0:
				k.sphere(0.035, p + Vector3(0.06, 0.25, 0.02), k.mat(flag_cols[(i + row) % 5], 0.7), sh, Vector3.ONE, 6)
	for i in 10:
		k.box(Vector3(0.2, 0.22, 0.2), Vector3(-1.5 + i * 0.33, 2.02, -0.02), k.mat(flag_cols[i % 5].lightened(0.2), 0.8), false, sh)
	# mannequins in dresses (back left) and jackets (back right) - decoration
	for j in 2:
		var mp := Node3D.new()
		mp.position = Vector3(-3.9 + j * 1.05, 0.3, -D / 2.0 + 0.7)
		k.root.add_child(mp)
		k.cyl(0.42, 0.45, 0.3, Vector3(0, -0.15, 0), k.white, mp)
		_mannequin(k, mp, [Color(0.68, 0.55, 0.88), Color(0.3, 0.75, 0.75)][j])
	k.blocker(Vector3(2.2, 2.0, 1.0), Vector3(-3.4, 1.0, -D / 2.0 + 0.7))
	var jackets := [Color(0.2, 0.25, 0.55), Color(0.78, 0.15, 0.15), Color(0.12, 0.45, 0.45)]
	for j in 3:
		var jp := Vector3(2.8 + j * 0.62, 1.7, -D / 2.0 + 0.12)
		k.box(Vector3(0.5, 0.75, 0.08), jp, k.mat(jackets[j], 0.85))
		k.box(Vector3(0.12, 0.6, 0.07), jp + Vector3(-0.3, -0.02, 0), k.mat(jackets[j].darkened(0.1), 0.85))
		k.box(Vector3(0.12, 0.6, 0.07), jp + Vector3(0.3, -0.02, 0), k.mat(jackets[j].darkened(0.1), 0.85))
		k.box(Vector3(0.1, 0.3, 0.02), jp + Vector3(0, 0.2, 0.05), k.white)
		k.cyl(0.015, 0.015, 0.1, jp + Vector3(0, 0.45, 0), k.brass)
	# hotspot: the empty pedestal (centre)
	var pd: Node3D = k.hotspot("pedestal", Vector3(-0.4, 0, -0.8), Vector3(1.2, 1.4, 1.2))
	var marble: Material = k.mat(Color(0.95, 0.94, 0.92), 0.25)
	k.cyl(0.5, 0.52, 0.08, Vector3(0, 0.04, 0), marble, pd)
	k.cyl(0.4, 0.4, 0.8, Vector3(0, 0.48, 0), marble, pd, true)
	k.cyl(0.48, 0.48, 0.07, Vector3(0, 0.915, 0), marble, pd)
	var plate: MeshInstance3D = k.box(Vector3(0.32, 0.18, 0.02), Vector3(0, 0.55, 0.41), k.brass, false, pd)
	plate.rotation.x = -0.15
	k.box(Vector3(0.22, 0.02, 0.01), Vector3(0, 0.58, 0.425), k.black, false, pd)
	k.box(Vector3(0.16, 0.02, 0.01), Vector3(0, 0.53, 0.425), k.black, false, pd)
	k.spot(Vector3(-0.4, H - 0.1, -0.4), Vector3(-0.4, 0.9, -0.8), Color(1.0, 0.95, 0.85), 2.0, 5.0, 18.0, false)
	# counter with the price-tag gun (right)
	var counter := Vector3(2.4, 0, -0.9)
	k.box(Vector3(1.7, 0.92, 0.7), counter + Vector3(0, 0.46, 0), k.wood_mid, true)
	k.box(Vector3(1.8, 0.05, 0.78), counter + Vector3(0, 0.945, 0), k.wood_light)
	k.box(Vector3(0.36, 0.28, 0.3), counter + Vector3(-0.55, 1.11, 0), k.mat(Color(0.2, 0.2, 0.22), 0.4, 0.4))
	k.box(Vector3(0.3, 0.08, 0.02), counter + Vector3(-0.55, 1.2, 0.16), k.glow(Color(0.4, 1.0, 0.6), 1.0))
	var pg: Node3D = k.hotspot("price_gun", counter + Vector3(0.3, 0.97, 0.05), Vector3(0.75, 0.45, 0.6), Vector3(0, 0.15, 0))
	var orange: Material = k.mat(Color(1.0, 0.55, 0.12), 0.5)
	k.box(Vector3(0.24, 0.1, 0.09), Vector3(0, 0.06, 0), orange, false, pg, 0.4)
	var handle: MeshInstance3D = k.box(Vector3(0.07, 0.18, 0.08), Vector3(0.05, 0.04, 0.06), k.mat(Color(0.2, 0.2, 0.22), 0.6), false, pg, 0.4)
	handle.rotation.x = PI / 2.4
	k.cyl(0.05, 0.05, 0.08, Vector3(-0.06, 0.08, -0.05), k.white, pg).rotation.x = PI / 2.0
	for i in 4:
		k.box(Vector3(0.05, 0.004, 0.03), Vector3(-0.2 + i * 0.09, 0.005, 0.15 + 0.02 * (i % 2)), k.white, false, pg, i * 0.5)
	k.cctv(Vector3(-W / 2.0 + 0.15, 2.85, D / 2.0 - 0.5), PI / 2.0 + 0.7)
	k.person("fennel", Vector3(-2.4, 0, 0.0))
	k.person("duchess", Vector3(3.0, 0.12, -1.65))
	k.door("lounge", "", Vector3(-2.6, 0, D / 2.0), PI)
	k.door("dining", "", Vector3(2.6, 0, D / 2.0), PI)
	k.spawn = Vector3(0, 0, 3.0)
	k.look = Vector3(0, 1.1, -4.0)


# =================================================================== Dining Hall
static func _dining(k) -> void:
	var W := 11.0
	var D := 9.0
	var H := 3.3
	k.environment("indoor", Color(0.65, 0.55, 0.45), 0.32)
	k.shell(W, D, H, {
		"floor": k.wood_floor(Color(0.3, 0.17, 0.09), Color(0.48, 0.3, 0.16)),
		"wall": k.mat(Color(0.88, 0.8, 0.66), 0.95),
		"wain": k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.42, 0.26, 0.14)), "wain_h": 0.9,
		"ceiling": k.mat(Color(0.4, 0.26, 0.14), 0.85), "beams": true})
	for x in [-5.0, -1.4, 1.4, 5.0]:
		k.box(Vector3(0.2, H, 0.12), Vector3(x, H / 2.0, -D / 2.0 + 0.06), k.wood_dark)
	k.shoji(Vector2(2.4, 1.5), Vector3(-3.2, 1.85, -D / 2.0 + 0.02), 0.0, Color(1.0, 0.9, 0.7), 1.3, Vector2(5, 3))
	k.shoji(Vector2(1.8, 1.5), Vector3(3.6, 1.85, -D / 2.0 + 0.02), 0.0, Color(1.0, 0.9, 0.7), 1.3, Vector2(4, 3))
	# hotspot: kitchen door (double door with round windows)
	var kd: Node3D = k.hotspot("kitchen_door", Vector3(0, 0, -D / 2.0 + 0.05), Vector3(1.9, 2.6, 0.6))
	k.box(Vector3(1.75, 2.35, 0.06), Vector3(0, 1.175, 0.02), k.wood_dark, false, kd)
	for sx in [-0.38, 0.38]:
		k.box(Vector3(0.72, 2.18, 0.05), Vector3(sx, 1.09, 0.07), k.mat(Color(0.48, 0.28, 0.15), 0.6), false, kd)
		k.torus(0.13, 0.17, Vector3(sx, 1.55, 0.11), k.brass, kd, Vector3(PI / 2.0, 0, 0))
		k.cyl(0.13, 0.13, 0.01, Vector3(sx, 1.55, 0.1), k.glow(Color(1.0, 0.85, 0.6), 0.9), kd).rotation.x = PI / 2.0
		k.box(Vector3(0.04, 0.3, 0.03), Vector3(sx * 0.15, 1.05, 0.11), k.brass, false, kd)
	k.box(Vector3(1.75, 0.18, 0.05), Vector3(0, 2.25, 0.08), k.mat(Color(0.15, 0.45, 0.45), 0.6), false, kd)
	# hotspot: menu board (the chalk menu as drawn in the 2D art)
	var mb: Node3D = k.hotspot("menu", Vector3(1.95, 1.15, -D / 2.0 + 0.06), Vector3(0.95, 1.25, 0.4), Vector3(0, 0.55, 0.1))
	k.box(Vector3(0.78, 1.0, 0.05), Vector3(0, 0.55, 0.0), k.wood_dark, false, mb)
	var crop: MeshInstance3D = k.bg_crop("dining", Rect2(812, 152, 116, 140), Vector2(0.68, 0.88), Vector3(0, 0.55, 0.03), 0.0, mb)
	if crop == null:
		k.box(Vector3(0.68, 0.88, 0.01), Vector3(0, 0.55, 0.03), k.mat(Color(0.1, 0.14, 0.12), 0.9), false, mb)
	k.cyl(0.005, 0.005, 0.4, Vector3(0, 1.22, 0.0), k.black, mb)
	# hotspot: the long dinner table
	var tb: Node3D = k.hotspot("table", Vector3(0, 0, -0.4), Vector3(2.0, 1.15, 4.7))
	k.box(Vector3(1.3, 0.74, 4.2), Vector3(0, 0.37, 0), k.wood_dark, true, tb)
	k.box(Vector3(1.44, 0.04, 4.34), Vector3(0, 0.77, 0), k.white, false, tb)
	k.box(Vector3(1.46, 0.24, 4.36), Vector3(0, 0.66, 0), k.mat(Color(0.92, 0.92, 0.88), 0.9), false, tb)
	var china: Material = k.mat(Color(0.96, 0.96, 0.95), 0.25)
	for side in [-1.0, 1.0]:
		for i in 5:
			var z := -1.6 + i * 0.8
			k.cyl(0.12, 0.1, 0.015, Vector3(side * 0.42, 0.8, z), china, tb)
			k.cyl(0.035, 0.03, 0.07, Vector3(side * 0.56, 0.83, z + 0.2), k.mat(Color(0.3, 0.5, 0.45), 0.3), tb)
			k.box(Vector3(0.012, 0.01, 0.22), Vector3(side * 0.6, 0.8, z - 0.05), k.wood_dark, false, tb)
			k.box(Vector3(0.012, 0.01, 0.22), Vector3(side * 0.62, 0.8, z - 0.05), k.wood_dark, false, tb)
	k.cyl(0.3, 0.26, 0.03, Vector3(0, 0.8, -0.4), china, tb)
	k.sphere(0.2, Vector3(0, 0.84, -0.4), k.mat(Color(1.0, 0.78, 0.3), 0.6), tb, Vector3(1.2, 0.45, 0.9))
	k.sphere(0.04, Vector3(0.06, 0.92, -0.42), k.mat(Color(0.3, 0.6, 0.2), 0.7), tb)
	k.sphere(0.11, Vector3(0, 0.88, 0.5), k.mat(Color(0.15, 0.4, 0.3), 0.3), tb, Vector3(1.1, 0.9, 1.1))
	var spout: MeshInstance3D = k.cyl(0.015, 0.025, 0.14, Vector3(0.12, 0.9, 0.5), k.mat(Color(0.15, 0.4, 0.3), 0.3), tb)
	spout.rotation.z = -0.8
	for side in [-1.0, 1.0]:
		for i in 5:
			k.chair(Vector3(side * 0.98, 0, -2.0 + 1.6 * 0.0 + i * 0.8 + 0.4), side * -PI / 2.0, k.mat(Color(0.5, 0.1, 0.12), 0.85), k.wood_dark, tb)
	k.hanging_lamp(Vector3(0, 2.55, -1.5), Color(1.0, 0.84, 0.6), 1.2, H, true)
	k.hanging_lamp(Vector3(0, 2.55, 0.8), Color(1.0, 0.84, 0.6), 1.0, H, false)
	k.plant(Vector3(-W / 2.0 + 0.5, 0, D / 2.0 - 0.6))
	k.plant(Vector3(W / 2.0 - 0.5, 0, D / 2.0 - 0.6))
	k.cctv(Vector3(W / 2.0 - 0.15, 2.95, -D / 2.0 + 0.5), -PI / 2.0 + 0.6)
	k.person("grub", Vector3(-2.6, 0, 0.0))
	k.person("pepper", Vector3(2.6, 0, -0.2))
	k.door("lounge", "", Vector3(-W / 2.0, 0, -1.2), PI / 2.0)
	k.door("giftshop", "", Vector3(W / 2.0, 0, -1.2), -PI / 2.0)
	k.spawn = Vector3(0, 0, 3.3)
	k.look = Vector3(0, 1.1, -4.5)


# =================================================================== Free Time hub: resort courtyard (afternoon)
## The inner courtyard of Yuzu Springs in golden afternoon light: the main inn (steel-shuttered entrance) to the
## north, a veranda and a food stall to the east, the garden to the west, an outdoor yuzu bath in the middle.
## Every guest stands somewhere that suits them.
static func _hub(k) -> void:
	var W := 22.0
	var D := 20.0
	k.bounds = Vector2(W, D)
	var env: Environment = k.environment("outdoor_dusk", Color(0.85, 0.7, 0.6), 0.55)
	env.tonemap_exposure = 1.0
	k.sun(Vector3(-24, -62, 0), Color(1.0, 0.8, 0.58), 1.35)
	k.box(Vector3(W + 20, 0.2, D + 20), Vector3(0, -0.12, 0), k.smat(Kit.SH_GRASS, {"g1": Color(0.3, 0.45, 0.16), "g2": Color(0.5, 0.6, 0.24)}), true)
	k.box(Vector3(14.0, 0.04, 13.0), Vector3(0, 0.0, -1.5), k.stone_floor(Color(0.55, 0.5, 0.44), Color(0.7, 0.64, 0.56), 0.9), false)
	# ---- north: the main inn with the steel-shuttered entrance
	var inn_z := -D / 2.0
	k.box(Vector3(W, 6.4, 0.4), Vector3(0, 3.2, inn_z - 0.2), k.mat(Color(0.9, 0.84, 0.72), 0.95), true)
	var timber: Material = k.mat(Color(0.24, 0.14, 0.08), 0.8)
	for i in 12:
		k.box(Vector3(0.2, 6.4, 0.1), Vector3(-W / 2.0 + i * 2.0, 3.2, inn_z + 0.05), timber)
	for yy in [0.15, 3.1, 6.3]:
		k.box(Vector3(W, 0.22, 0.12), Vector3(0, yy, inn_z + 0.06), timber)
	for x in [-8.0, -4.0, 4.0, 8.0]:
		k.shoji(Vector2(2.2, 1.4), Vector3(x, 1.75, inn_z + 0.03), 0.0, Color(1.0, 0.86, 0.6), 1.5, Vector2(5, 3), false)
	for x in [-9.0, -5.0, -1.0, 1.0, 5.0, 9.0]:
		k.shoji(Vector2(1.6, 1.3), Vector3(x, 4.6, inn_z + 0.03), 0.0, Color(1.0, 0.86, 0.6), 1.2, Vector2(4, 3), false)
	var roof: MeshInstance3D = k.box(Vector3(W + 1.0, 0.25, 2.6), Vector3(0, 6.8, inn_z + 0.8), k.mat(Color(0.2, 0.21, 0.27), 0.7))
	roof.rotation.x = 0.35
	var eave: MeshInstance3D = k.box(Vector3(W + 1.0, 0.18, 1.8), Vector3(0, 3.35, inn_z + 0.8), k.mat(Color(0.22, 0.22, 0.28), 0.7))
	eave.rotation.x = 0.3
	# steel shutter over the entrance (sinister touch) + hazard stripes + sign
	k.quad(Vector2(3.6, 2.7), Vector3(0, 1.35, inn_z + 0.08), k.stripes(Color(0.52, 0.54, 0.57), Color(0.33, 0.35, 0.38), 34.0))
	k.box(Vector3(4.0, 0.4, 0.4), Vector3(0, 2.9, inn_z + 0.2), k.steel)
	for sx in [-1.9, 1.9]:
		k.box(Vector3(0.18, 2.7, 0.22), Vector3(sx, 1.35, inn_z + 0.12), k.steel)
	for i in 9:
		k.box(Vector3(0.4, 0.2, 0.06), Vector3(-1.6 + i * 0.4, 0.1, inn_z + 0.12), k.mat(Color(0.95, 0.78, 0.1) if i % 2 == 0 else Color(0.08, 0.07, 0.06), 0.6))
	k.box(Vector3(1.1, 0.5, 0.04), Vector3(1.0, 1.75, inn_z + 0.13), k.mat(Color(0.95, 0.75, 0.1), 0.5))
	k.label("NO EXIT", Vector3(1.0, 1.75, inn_z + 0.16), 0.0, 56, Color(0.08, 0.06, 0.05), null, 0.004, 0)
	k.box(Vector3(3.2, 0.7, 0.08), Vector3(0, 3.75, inn_z + 0.12), k.wood_dark)
	k.label("YUZU SPRINGS", Vector3(0, 3.75, inn_z + 0.18), 0.0, 80, Color(0.98, 0.82, 0.48), null, 0.005, 6)
	for x in [-2.6, 2.6]:
		k.paper_lantern(Vector3(x, 2.7, inn_z + 0.9), Color(1.0, 0.4, 0.28), 1.0, true, false, 1.0)
	k.cctv(Vector3(-2.3, 3.2, inn_z + 0.15), 0.3)
	k.cctv(Vector3(2.3, 3.2, inn_z + 0.15), -0.3)
	# ---- east: veranda (engawa) along a lower wing, food stall, little stage
	var ex := W / 2.0
	k.box(Vector3(0.4, 3.6, D), Vector3(ex + 0.2, 1.8, 0), k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.45, 0.28, 0.15)), true)
	for z in [-6.0, -2.0, 2.0]:
		k.shoji(Vector2(1.8, 2.0), Vector3(ex - 0.02, 1.4, z), -PI / 2.0, Color(1.0, 0.86, 0.62), 1.3, Vector2(3, 4), false)
	k.box(Vector3(2.2, 0.35, D - 2.0), Vector3(ex - 1.1, 0.175, -1.0), k.wood_floor(Color(0.4, 0.24, 0.12), Color(0.58, 0.38, 0.2), 0.18), true)
	var v_roof: MeshInstance3D = k.box(Vector3(3.2, 0.18, D), Vector3(ex - 1.3, 3.5, 0), k.mat(Color(0.22, 0.22, 0.28), 0.7))
	v_roof.rotation.z = -0.25
	for z in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		k.cyl(0.09, 0.09, 3.2, Vector3(ex - 2.3, 1.6, z), k.wood_dark)
	k.box(Vector3(0.5, 0.42, 2.2), Vector3(ex - 0.6, 0.56, 1.0), k.wood_light)
	k.box(Vector3(0.5, 0.42, 2.2), Vector3(ex - 0.6, 0.56, -5.2), k.wood_light)
	k.box(Vector3(0.36, 0.3, 0.5), Vector3(ex - 0.5, 0.5, -3.2), k.white)
	k.box(Vector3(0.28, 0.08, 0.02), Vector3(ex - 0.5, 0.55, -2.94), k.mat(Color(0.2, 0.7, 0.3), 0.6))
	k.box(Vector3(0.08, 0.24, 0.02), Vector3(ex - 0.5, 0.55, -2.94), k.mat(Color(0.2, 0.7, 0.3), 0.6))
	# food stall (yatai)
	var st := Vector3(8.0, 0, 6.0)
	k.box(Vector3(2.4, 1.0, 1.0), st + Vector3(0, 0.5, 0), k.wood_mid, true)
	k.box(Vector3(2.6, 0.06, 1.2), st + Vector3(0, 1.03, 0), k.wood_light)
	for sx in [-1.15, 1.15]:
		k.cyl(0.05, 0.05, 2.3, st + Vector3(sx, 1.15, -0.4), k.wood_dark)
	k.box(Vector3(2.8, 0.1, 1.6), st + Vector3(0, 2.35, 0), k.mat(Color(0.75, 0.15, 0.12), 0.8))
	for i in 5:
		k.box(Vector3(0.5, 0.5, 0.02), st + Vector3(-1.0 + i * 0.5, 2.05, 0.8), k.mat(Color(0.95, 0.92, 0.85) if i % 2 == 0 else Color(0.2, 0.25, 0.5), 0.9))
	k.paper_lantern(st + Vector3(-1.2, 1.95, 0.85), Color(1.0, 0.4, 0.28), 0.7, true, false, 0.8)
	k.paper_lantern(st + Vector3(1.2, 1.95, 0.85), Color(1.0, 0.4, 0.28), 0.7, false)
	for i in 4:
		k.cyl(0.12, 0.1, 0.06, st + Vector3(-0.8 + i * 0.5, 1.09, 0.2), k.mat(Color(0.95, 0.94, 0.9), 0.3))
		k.sphere(0.07, st + Vector3(-0.8 + i * 0.5, 1.13, 0.2), k.mat(Color(0.95, 0.7, 0.3), 0.6), null, Vector3(1, 0.6, 1))
	k.steam(st + Vector3(0.6, 1.2, 0.1), Vector3(0.2, 0.02, 0.1), 8, 0.4, 0.12, 0.3, 2.0)
	# little wooden stage with a mic stand
	var sg := Vector3(5.6, 0, -6.4)
	k.box(Vector3(3.0, 0.35, 2.2), sg + Vector3(0, 0.175, 0), k.wood_floor(Color(0.4, 0.22, 0.1), Color(0.58, 0.36, 0.18)), true)
	k.box(Vector3(3.04, 0.06, 0.06), sg + Vector3(0, 0.36, 1.1), k.mat(Color(0.9, 0.7, 0.3), 0.3, 0.8))
	k.cyl(0.015, 0.015, 1.3, sg + Vector3(0.6, 1.0, 0.4), k.steel)
	k.sphere(0.05, sg + Vector3(0.6, 1.68, 0.4), k.black)
	k.lantern_string(sg + Vector3(-1.5, 2.6, -1.0), sg + Vector3(1.5, 2.6, -1.0), 5, [Color(1.0, 0.5, 0.75), Color(1.0, 0.85, 0.5), Color(0.6, 0.85, 1.0)], 0.3, 2)
	for sx in [-1.5, 1.5]:
		k.cyl(0.05, 0.05, 2.6, sg + Vector3(sx, 1.3, -1.0), k.wood_dark)
	# ---- west: garden (rose bushes, lanterns, easel)
	var wx := -W / 2.0
	_fence(k, Vector3(wx, 0, -D / 2.0), Vector3(wx, 0, D / 2.0), 2.2)
	var leaf: Material = k.mat(Color(0.18, 0.42, 0.16), 0.85)
	var rose: Material = k.mat(Color(0.86, 0.1, 0.14), 0.6)
	for b in 3:
		var bc := Vector3(-9.6, 0, -6.0 + b * 1.6)
		for i in 4:
			k.sphere(0.4, bc + Vector3(cos(i * 1.6) * 0.3, 0.45, sin(i * 1.6) * 0.3), leaf, null, Vector3.ONE, 10)
		for i in 9:
			k.sphere(0.065, bc + Vector3(cos(i * 2.4) * 0.45, 0.4 + 0.45 * _h(i + b * 9), sin(i * 2.4) * 0.45), rose, null, Vector3.ONE, 8)
		k.blocker(Vector3(1.0, 1.0, 1.0), bc + Vector3(0, 0.5, 0))
	k.stone_lantern(Vector3(-9.8, 0, -1.5), 1.2, true)
	k.stone_lantern(Vector3(-9.8, 0, 6.0), 1.2, true)
	var easel := Node3D.new()
	easel.position = Vector3(-8.9, 0, 3.0)
	easel.rotation.y = PI / 2.0 + 0.4
	k.root.add_child(easel)
	for sx in [-0.3, 0.3]:
		var leg: MeshInstance3D = k.box(Vector3(0.04, 1.7, 0.04), Vector3(sx, 0.85, 0.0), k.wood_light, false, easel)
		leg.rotation.x = -0.12
	k.box(Vector3(0.8, 0.6, 0.03), Vector3(0, 1.25, 0.1), k.white, false, easel)
	k.box(Vector3(0.7, 0.24, 0.01), Vector3(0, 1.18, 0.12), k.mat(Color(0.45, 0.62, 0.85), 0.9), false, easel)
	k.box(Vector3(0.7, 0.16, 0.01), Vector3(0, 1.38, 0.12), k.mat(Color(1.0, 0.7, 0.4), 0.9), false, easel)
	k.sphere(0.06, Vector3(0.15, 1.42, 0.13), k.mat(Color(1.0, 0.9, 0.5), 0.9), easel, Vector3(1, 1, 0.2))
	# ---- south: fence with a locked gate, mountains and the setting sun beyond
	_fence(k, Vector3(-W / 2.0, 0, D / 2.0), Vector3(W / 2.0, 0, D / 2.0), 2.2)
	k.box(Vector3(2.4, 2.6, 0.2), Vector3(0, 1.3, D / 2.0 - 0.05), k.wood_dark)
	k.box(Vector3(0.12, 0.6, 0.12), Vector3(0, 1.2, D / 2.0 - 0.2), k.steel)
	k.box(Vector3(2.6, 0.2, 0.3), Vector3(0, 2.7, D / 2.0 - 0.05), k.mat(Color(0.2, 0.21, 0.27), 0.7))
	for i in 7:
		var hill: Material = k.mat(Color(0.42, 0.36, 0.48).lerp(Color(0.85, 0.6, 0.55), 0.3 + 0.12 * (i % 3)), 1.0)
		k.sphere(1.0, Vector3(-30 + i * 10.0, -2.0, D / 2.0 + 22 + (i % 2) * 6.0), hill, null, Vector3(10, 6 + (i % 3) * 2.0, 5), 16)
	# ---- centre: the outdoor yuzu bath
	var pc := Vector3(0, 0, -1.5)
	var rx := 3.6
	var rz := 2.6
	var bottom: MeshInstance3D = k.cyl(1.0, 1.0, 0.1, pc + Vector3(0, 0.05, 0), k.mat(Color(0.1, 0.3, 0.3), 0.6), null, false, 48)
	bottom.scale = Vector3(rx, 1, rz)
	var water: MeshInstance3D = k.cyl(1.0, 1.0, 0.3, pc + Vector3(0, 0.17, 0), k.water(Color(0.06, 0.4, 0.42), Color(0.5, 0.9, 0.8), 0.28), null, false, 48)
	water.scale = Vector3(rx, 1, rz)
	k.blocker(Vector3(rx * 1.75, 1.2, rz * 1.75), pc + Vector3(0, 0.6, 0))
	k.blocker(Vector3(rx * 1.3, 1.2, rz * 2.0), pc + Vector3(0, 0.6, 0))
	k.blocker(Vector3(rx * 2.0, 1.2, rz * 1.2), pc + Vector3(0, 0.6, 0))
	var rock_m: Material = k.mat(Color(0.48, 0.45, 0.42), 0.55)
	for i in 30:
		var a := i * TAU / 30.0
		var p: Vector3 = pc + Vector3(cos(a) * (rx + 0.1), 0.15, sin(a) * (rz + 0.1))
		k.rock(p, Vector3(0.95, 0.48, 0.75) * (0.8 + 0.45 * _h(i)), rock_m, -a, false)
	for i in 14:
		var a := i * 2.399 + 0.4
		var rr := 0.3 + 0.6 * _h(i + 40)
		_yuzu(k, pc + Vector3(cos(a) * rx * rr, 0.33, sin(a) * rz * rr))
	k.steam(pc + Vector3(0, 0.45, 0), Vector3(rx * 0.75, 0.05, rz * 0.75), 26, 1.4, 0.1, 0.35, 4.5)
	k.stone_lantern(pc + Vector3(-rx - 0.9, 0, -rz + 0.2), 1.3, true)
	k.rock(Vector3(-5.2, 0.45, 0.4), Vector3(1.4, 1.0, 1.1), rock_m, 0.4, true)
	# a Snapjaw camera pole
	k.cyl(0.07, 0.09, 3.2, Vector3(4.2, 1.6, -2.4), k.steel)
	k.cctv(Vector3(4.2, 3.0, -2.25), 0.6)
	# benches
	for b in [[Vector3(-6.4, 0, 7.2), 0.0], [Vector3(3.6, 0, 6.8), 0.3]]:
		var bp: Vector3 = b[0]
		k.box(Vector3(1.8, 0.08, 0.5), bp + Vector3(0, 0.45, 0), k.wood_light, true, null, float(b[1]))
		for sx in [-0.75, 0.75]:
			k.box(Vector3(0.08, 0.45, 0.45), bp + Vector3(cos(float(b[1])) * sx, 0.22, -sin(float(b[1])) * sx), k.wood_dark, false, null, float(b[1]))
	k.box(Vector3(0.9, 0.12, 0.35), Vector3(-6.4, 0.55, 7.2), k.mat(Color(0.3, 0.4, 0.75), 0.9))
	# strings of lanterns across the courtyard
	var lcols := [Color(1.0, 0.45, 0.3), Color(1.0, 0.85, 0.55), Color(1.0, 0.6, 0.35)]
	k.lantern_string(Vector3(-W / 2.0 + 0.5, 3.6, -6.0), Vector3(W / 2.0 - 2.4, 3.4, -4.0), 12, lcols, 0.9, 3)
	k.lantern_string(Vector3(-W / 2.0 + 0.5, 3.6, 3.0), Vector3(W / 2.0 - 2.4, 3.4, 4.0), 12, lcols, 0.9, 3)
	# guests (each somewhere that suits them)
	k.person("coco", Vector3(1.2, 0, 2.3))
	k.person("bruno", Vector3(-4.0, 0, 1.6))
	k.person("lulu", Vector3(5.6, 0.35, -6.6))
	k.person("pepper", Vector3(2.8, 0, -8.4))
	k.person("duchess", Vector3(8.3, 0.35, 1.0))
	k.person("grub", Vector3(8.0, 0, 7.2))
	k.person("bramble", Vector3(-8.4, 0, -4.2))
	k.person("fennel", Vector3(-8.0, 0, 3.6))
	k.person("nibs", Vector3(-3.9, 0, -4.4))
	k.person("zuzu", Vector3(4.9, 0, -1.6))
	k.person("reginald", Vector3(4.6, 0, 3.4))
	k.person("tumble", Vector3(-6.4, 0, 6.4))
	k.person("marigold", Vector3(8.4, 0.35, -3.2))
	k.person("wisp", Vector3(-7.6, 0, -8.6))
	k.spots = [Vector3(-2.0, 0, 5.0), Vector3(2.0, 0, 5.0), Vector3(-6.0, 0, -2.0), Vector3(6.0, 0, 1.0)]
	k.spawn = Vector3(0, 0, 8.4)
	k.look = Vector3(0, 1.2, -4.0)
