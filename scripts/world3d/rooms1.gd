extends RefCounted
## Chapter 1 (Yuzu Springs resort) 3D rooms for the walk-around version, plus the Free Time courtyard hub.
## Each builder recreates its 2D background (art/bg/<id>.svg) as a walkable room, places one 3D object
## per hotspot id from investigation_data.gd (k.hotspot), the people's standing spots (k.person) and the
## exits (k.door, following the resort map links). See kit.gd for the coordinate conventions.

const Style := preload("res://scripts/ui/style.gd")
const Kit := preload("res://scripts/world3d/kit.gd")
const Cast := preload("res://scripts/data/cast.gd")

## Walkable connecting spaces (not investigation rooms): name + where the "you are here" pin goes on the 2D map.
const SPACES := {
	"lobby": {"name": "Grand Lobby", "map_at": Vector2(272, 345)},
	"arcade": {"name": "Shop Arcade", "map_at": Vector2(205, 345)},
	"courtyard": {"name": "Courtyard Garden", "map_at": Vector2(345, 440)},
	"walkway": {"name": "Bathhouse Walkway", "map_at": Vector2(625, 470)},
	"backstage": {"name": "Backstage Steps", "map_at": Vector2(420, 270)},
	"bath_passage": {"name": "Bath Passage", "map_at": Vector2(926, 270)},
	"mochi_room": {"name": "Mochi's Room", "map_at": Vector2(272, 250)},
}
## Free Time: where you can walk, and where you start.
const FREE_SPACES := ["courtyard", "lobby", "arcade"]
const FREE_START := "courtyard"


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
		"lobby":
			_lobby(k)
		"arcade":
			_arcade(k)
		"courtyard":
			_courtyard(k)
		"walkway":
			_walkway(k)
		"backstage":
			_backstage(k)
		"bath_passage":
			_bath_passage(k)
		"mochi_room":
			_mochi_room(k)
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
static func _facade(k, x0: float, x1: float, z: float, h: float, wall_m: Material, timber: bool, flip: bool = false) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var sg := -1.0 if flip else 1.0
	k.box(Vector3(w, h, 0.3), Vector3(cx, h / 2.0, z - 0.15 * sg), wall_m, true)
	if timber:
		var tm: Material = k.mat(Color(0.24, 0.14, 0.08), 0.8)
		var n := maxi(int(w / 1.5), 1)
		for i in n + 1:
			k.box(Vector3(0.14, h, 0.06), Vector3(x0 + w * float(i) / n, h / 2.0, z + 0.02 * sg), tm)
		for yy in [0.12, 1.0, h - 0.15]:
			k.box(Vector3(w, 0.14, 0.06), Vector3(cx, yy, z + 0.02 * sg), tm)
	var roof: Material = k.mat(Color(0.2, 0.21, 0.26), 0.7)
	var r: MeshInstance3D = k.box(Vector3(w + 0.6, 0.16, 1.6), Vector3(cx, h + 0.35, z + 0.35 * sg), roof)
	r.rotation.x = 0.35 * sg
	k.box(Vector3(w + 0.6, 0.12, 0.12), Vector3(cx, h + 0.1, z + 1.05 * sg), k.mat(Color(0.14, 0.14, 0.17), 0.7))


static func _ceiling_light(k, pos: Vector3, h: float, energy: float = 1.2, shadows: bool = true) -> void:
	k.hanging_lamp(pos, Color(1.0, 0.84, 0.62), energy, h, shadows)


# =================================================================== Yuzu Bath (outdoor, morning)
static func _bath(k) -> void:
	var W := 15.0
	var D := 13.0
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
	# raised entry terrace with stone steps down to the bath
	k.slab(-W / 2.0, 4.5, W / 2.0, D / 2.0, 0.54, k.wood_floor(Color(0.36, 0.22, 0.12), Color(0.56, 0.37, 0.2)), 0.54)
	k.stairs(Vector3(0, 0, 3.2), Vector3(0, 0.54, 4.5), 4.2, {"mat": k.stone, "rail": "none"})
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
	var pc := Vector3(1.4, 0, -1.8)
	var rx := 3.4
	var rz := 2.3
	var bottom: MeshInstance3D = k.cyl(1.0, 1.0, 0.1, pc + Vector3(0, 0.05, 0), k.mat(Color(0.1, 0.3, 0.3), 0.6), null, false, 48)
	bottom.scale = Vector3(rx, 1, rz)
	var water: MeshInstance3D = k.cyl(1.0, 1.0, 0.3, pc + Vector3(0, 0.17, 0), k.water(Color(0.05, 0.4, 0.42), Color(0.45, 0.9, 0.82), 0.32), null, false, 48)
	water.scale = Vector3(rx, 1, rz)
	# kept low so you can still aim over them at things floating in the water
	k.blocker(Vector3(rx * 1.75, 0.5, rz * 1.75), pc + Vector3(0, 0.25, 0))
	k.blocker(Vector3(rx * 1.3, 0.5, rz * 2.0), pc + Vector3(0, 0.25, 0))
	k.blocker(Vector3(rx * 2.0, 0.5, rz * 1.2), pc + Vector3(0, 0.25, 0))
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
		if p.distance_to(pc + Vector3(0.25, 0.33, 0.4)) < 1.0 or p.distance_to(pc + Vector3(-1.7, 0.33, -1.35)) < 0.7:
			continue
		_yuzu(k, p)
	# hotspot: the body, floating face-down (cartoon, non-graphic: striped shirt + captain hat)
	var body: Node3D = k.hotspot("body", pc + Vector3(0.25, 0.3, 0.4), Vector3(1.6, 0.6, 1.5), Vector3(0, 0.1, 0))
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
	var yz: Node3D = k.hotspot("yuzu", pc + Vector3(-1.7, 0.32, -1.35), Vector3(1.1, 0.5, 0.8))
	for j in 5:
		_yuzu(k, Vector3(cos(j * 1.3) * 0.25, 0.02, sin(j * 1.3) * 0.18), yz, 0.1)
	k.box(Vector3(0.14, 0.01, 0.06), Vector3(0.12, 0.03, 0.2), k.mat(Color(0.3, 0.55, 0.2), 0.6), false, yz, 0.6)
	# hotspot: stone lantern behind the pool (right)
	var ln: Node3D = k.hotspot("lantern", Vector3(5.6, 0, -5.4), Vector3(1.0, 2.0, 1.0))
	k.stone_lantern(Vector3.ZERO, 1.3, true, ln)
	k.cctv(Vector3(W / 2.0 - 0.2, 2.1, -D / 2.0 + 0.6), -PI / 2.0 - 0.6)
	k.person("marigold", Vector3(6.2, 0, -0.4))
	k.person("bruno", Vector3(-4.0, 0, -0.9))
	k.door("bath_passage", "", Vector3(0, 0.54, D / 2.0), PI, {"mat": k.wood_light})
	k.spawn = Vector3(0, 0.54, 5.2)
	k.look = Vector3(1.0, 0.5, -2.0)


# =================================================================== Changing Room
static func _changing(k) -> void:
	var W := 12.0
	var D := 5.0
	var H := 3.0
	k.environment("indoor", Color(0.62, 0.55, 0.48), 0.32)
	k.shell(W, D, H, {
		"floor": k.wood_floor(Color(0.34, 0.2, 0.1), Color(0.56, 0.37, 0.2)),
		"wall": k.mat(Color(0.88, 0.82, 0.7), 0.95),
		"wain": k.wood_wall(Color(0.36, 0.22, 0.12), Color(0.5, 0.32, 0.17)), "wain_h": 0.9,
		"ceiling": k.mat(Color(0.5, 0.36, 0.22), 0.8), "beams": true})
	_ceiling_light(k, Vector3(-2.8, 2.55, 0.0), H, 1.3, true)
	_ceiling_light(k, Vector3(3.0, 2.55, 0.0), H, 0.9, false)
	# lockers (back left)
	var lk: Node3D = k.hotspot("lockers", Vector3(-3.6, 0, -D / 2.0 + 0.32), Vector3(3.3, 2.3, 0.9))
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
	var hk: Node3D = k.hotspot("hooks", Vector3(-0.6, 1.45, -D / 2.0 + 0.1), Vector3(2.0, 1.1, 0.5), Vector3(0, 0.25, 0.1))
	k.box(Vector3(1.9, 0.1, 0.05), Vector3(0, 0.55, 0.02), k.wood_dark, false, hk)
	var towels := [Color(0.95, 0.95, 0.95), Color(0.62, 0.8, 0.95), Color(0.98, 0.72, 0.78), Color(0.95, 0.95, 0.95), Color(0.98, 0.8, 0.62)]
	for i in 5:
		var x := -0.72 + i * 0.36
		k.cyl(0.012, 0.012, 0.12, Vector3(x, 0.5, 0.08), k.brass, hk).rotation.x = PI / 2.0
		k.box(Vector3(0.26, 0.5, 0.05), Vector3(x, 0.22, 0.12), k.mat(towels[i], 0.95), false, hk)
		if i == 3:
			k.box(Vector3(0.1, 0.07, 0.02), Vector3(x, 0.66, 0.05), k.mat(Color(0.85, 0.1, 0.1), 0.6), false, hk)
	# side door (back right), ajar, morning light outside
	var sd: Node3D = k.hotspot("side_door", Vector3(2.0, 0, -D / 2.0 + 0.04), Vector3(1.4, 2.3, 0.7))
	k.box(Vector3(1.2, 2.25, 0.06), Vector3(0, 1.125, 0.02), k.wood_dark, false, sd)
	k.quad(Vector2(0.98, 2.08), Vector3(0, 1.05, 0.06), k.glow(Color(0.82, 0.95, 0.75), 1.4), sd)
	var hinge := Node3D.new()
	hinge.position = Vector3(-0.49, 0, 0.08)
	hinge.rotation.y = -0.55
	sd.add_child(hinge)
	k.box(Vector3(0.96, 2.05, 0.05), Vector3(0.48, 1.03, 0), k.mat(Color(0.6, 0.4, 0.22), 0.6), false, hinge)
	k.sphere(0.03, Vector3(0.86, 1.0, 0.04), k.brass, hinge)
	k.omni(Vector3(2.0, 1.4, -D / 2.0 + 0.6), Color(0.85, 1.0, 0.82), 0.7, 4.0)
	# round mirror and a little shelf
	var mir: MeshInstance3D = k.cyl(0.36, 0.36, 0.03, Vector3(-0.0, 0.0, 0.0), k.mat(Color(0.8, 0.86, 0.9), 0.05, 1.0))
	mir.position = Vector3(3.95, 1.85, -D / 2.0 + 0.05)
	mir.rotation.x = PI / 2.0
	k.torus(0.35, 0.41, Vector3(3.95, 1.85, -D / 2.0 + 0.05), k.wood_dark, null, Vector3(PI / 2.0, 0, 0))
	k.box(Vector3(0.8, 0.04, 0.2), Vector3(3.95, 1.3, -D / 2.0 + 0.1), k.wood_light)
	for i in 3:
		k.cyl(0.035, 0.035, 0.14, Vector3(3.7 + i * 0.22, 1.39, -D / 2.0 + 0.1), k.mat([Color(0.4, 0.75, 0.9), Color(0.95, 0.75, 0.3), Color(0.9, 0.5, 0.6)][i], 0.3))
	# bucket stack (middle of the room)
	var bk: Node3D = k.hotspot("buckets", Vector3(0.1, 0, -0.5), Vector3(1.2, 1.0, 0.9))
	var rows := [[-0.36, 0.0, 0.36], [-0.18, 0.18], [0.0]]
	for r in rows.size():
		for x in rows[r]:
			var b: Node3D = k.bucket(Vector3(float(x), r * 0.27 + 0.26, 0), 1.0, bk)
			b.rotation.x = PI
	for x in [-0.18, 0.18]:
		var b2: Node3D = k.bucket(Vector3(x, 0.26, -0.32), 1.0, bk)
		b2.rotation.x = PI
	k.blocker(Vector3(0.9, 0.9, 0.7), Vector3(0.1, 0.45, -0.62))
	# bench along the east wall + baskets
	k.box(Vector3(3.0, 0.45, 0.5), Vector3(-2.6, 0.225, D / 2.0 - 0.35), k.wood_light, true)
	for i in 2:
		k.box(Vector3(0.36, 0.2, 0.3), Vector3(-3.4 + i * 1.5, 0.55, D / 2.0 - 0.35), k.mat(Color(0.7, 0.55, 0.32), 0.9))
	k.cctv(Vector3(-W / 2.0 + 0.15, 2.85, D / 2.0 - 0.5), PI / 2.0 + 0.7)
	k.person("reginald", Vector3(-2.4, 0, 1.0))
	k.door("walkway", "", Vector3(W / 2.0, 0, 0.3), -PI / 2.0, {"mat": k.wood_light})
	k.door("bath_passage", "", Vector3(-W / 2.0, 0, 0.3), PI / 2.0, {"porthole": true})
	k.link_door("side_door", "garden")
	k.spawn = Vector3(4.6, 0, 0.3)
	k.look = Vector3(-3.0, 1.25, -1.2)


# =================================================================== Sauna
static func _sauna(k) -> void:
	var W := 5.0
	var D := 4.5
	var H := 2.5
	k.environment("steam", Color(0.72, 0.5, 0.36), 0.32)
	var planks: Material = k.wood_wall(Color(0.5, 0.25, 0.1), Color(0.76, 0.44, 0.22), 0.14)
	k.shell(W, D, H, {"floor": k.wood_floor(Color(0.3, 0.15, 0.07), Color(0.46, 0.25, 0.12), 0.12),
		"wall": planks, "wain": null, "ceiling": planks, "trim": k.mat(Color(0.32, 0.16, 0.07), 0.8)})
	k.omni(Vector3(0.4, 2.15, 0.5), Color(1.0, 0.7, 0.45), 0.9, 6.0, true)
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
	var bn: Node3D = k.hotspot("benches", Vector3(-W / 2.0 + 0.85, 0, 0.1), Vector3(1.8, 1.25, 3.6))
	var bench_m: Material = k.wood_floor(Color(0.6, 0.34, 0.16), Color(0.82, 0.52, 0.28), 0.1)
	k.box(Vector3(0.6, 0.07, 3.4), Vector3(0.35, 0.45, 0), bench_m, false, bn)
	k.box(Vector3(0.6, 0.42, 3.4), Vector3(0.35, 0.21, 0), k.mat(Color(0.42, 0.22, 0.1), 0.8), false, bn)
	k.box(Vector3(0.65, 0.07, 3.4), Vector3(-0.3, 0.9, 0), bench_m, false, bn)
	k.box(Vector3(0.65, 0.87, 3.4), Vector3(-0.3, 0.43, 0), k.mat(Color(0.4, 0.2, 0.09), 0.8), false, bn)
	k.box(Vector3(0.5, 0.06, 0.32), Vector3(-0.3, 0.96, 1.1), k.white, false, bn)
	k.bucket(Vector3(0.35, 0.49, -1.0), 0.8, bn)
	k.blocker(Vector3(1.4, 1.0, 3.4), Vector3(-W / 2.0 + 0.75, 0.5, 0.1))
	# door panel (right of the stove)
	var pn: Node3D = k.hotspot("panel", Vector3(1.75, 1.35, -D / 2.0 + 0.05), Vector3(0.7, 0.8, 0.4), Vector3(0, 0, 0.12))
	k.box(Vector3(0.34, 0.48, 0.06), Vector3(0, 0, 0.03), k.mat(Color(0.75, 0.76, 0.74), 0.4, 0.3), false, pn)
	k.box(Vector3(0.26, 0.13, 0.01), Vector3(0, 0.1, 0.065), k.glow(Color(0.25, 0.9, 0.5), 1.6), false, pn)
	k.label("90°C", Vector3(0, 0.1, 0.075), 0.0, 32, Color(0.05, 0.2, 0.08), pn, 0.0022, 0)
	for i in 3:
		k.sphere(0.022, Vector3(-0.08 + i * 0.08, -0.1, 0.07), k.glow([Color(0.9, 0.2, 0.15), Color(0.95, 0.75, 0.2), Color(0.2, 0.8, 0.3)][i], 1.5), pn)
	k.box(Vector3(0.2, 0.06, 0.02), Vector3(0, -0.18, 0.065), k.black, false, pn)
	# hourglass + thermometer (back left), vent
	var hg := Vector3(-1.05, 1.55, -D / 2.0 + 0.12)
	k.box(Vector3(0.22, 0.03, 0.16), hg + Vector3(0, 0.22, 0), k.wood_dark)
	k.box(Vector3(0.22, 0.03, 0.16), hg + Vector3(0, -0.22, 0), k.wood_dark)
	var glass: Material = k.mat(Color(0.9, 0.95, 1.0, 1.0), 0.05)
	k.cyl(0.08, 0.015, 0.2, hg + Vector3(0, 0.1, 0), glass)
	k.cyl(0.015, 0.08, 0.2, hg + Vector3(0, -0.1, 0), glass)
	k.cyl(0.0, 0.06, 0.08, hg + Vector3(0, -0.16, 0), k.mat(Color(0.95, 0.8, 0.45), 0.9))
	k.box(Vector3(0.1, 0.5, 0.03), Vector3(-1.75, 1.55, -D / 2.0 + 0.04), k.white)
	k.box(Vector3(0.02, 0.32, 0.01), Vector3(-1.75, 1.52, -D / 2.0 + 0.06), k.mat(Color(0.85, 0.1, 0.1), 0.5))
	k.box(Vector3(0.4, 0.3, 0.04), Vector3(1.9, 2.15, -D / 2.0 + 0.03), k.mat(Color(0.25, 0.14, 0.07), 0.8))
	k.door("bath_passage", "", Vector3(W / 2.0, 0, 0.9), -PI / 2.0, {"porthole": true, "h": 1.9, "mat": k.mat(Color(0.6, 0.36, 0.18), 0.6)})
	k.person("zuzu", Vector3(-0.3, 0, 0.6))
	k.person("nibs", Vector3(1.5, 0, -0.9))
	k.spawn = Vector3(1.3, 0, 0.9)
	k.look = Vector3(-0.3, 1.1, -2.2)


# =================================================================== Garden Path (outdoor, morning)
static func _garden(k) -> void:
	var W := 8.0
	var D := 22.0
	k.bounds = Vector2(W, D)
	k.environment("outdoor_morning", Color(0.8, 0.85, 0.8), 0.6)
	k.sun(Vector3(-48, 32, 0), Color(1.0, 0.96, 0.86), 1.2)
	k.box(Vector3(W + 24, 0.2, D + 24), Vector3(0, -0.1, 0), k.smat(Kit.SH_GRASS), true)
	# the lounge annex closes the south end, the bathhouse the north end
	_facade(k, -W / 2.0 - 2.0, W / 2.0 + 2.0, D / 2.0, 3.2, k.mat(Color(0.9, 0.87, 0.8), 0.95), true, true)
	_facade(k, -W / 2.0 - 2.0, W / 2.0 + 2.0, -D / 2.0, 3.2, k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.44, 0.28, 0.15)), false)
	k.shoji(Vector2(1.2, 0.9), Vector3(-2.6, 1.75, D / 2.0 - 0.02), PI, Color(0.95, 0.9, 0.82), 0.4, Vector2(3, 2), false)
	k.box(Vector3(1.1, 0.8, 0.05), Vector3(2.6, 1.8, -D / 2.0 + 0.03), k.glow(Color(0.85, 0.85, 0.75), 0.3))
	_fence(k, Vector3(-W / 2.0, 0, -D / 2.0), Vector3(-W / 2.0, 0, D / 2.0))
	_fence(k, Vector3(W / 2.0, 0, -D / 2.0), Vector3(W / 2.0, 0, D / 2.0))
	# beyond the fences: autumn trees and the sky
	for t in [[-7.0, -7.0], [7.5, -2.0], [-7.5, 3.5], [7.0, 7.5]]:
		k.cyl(0.14, 0.2, 2.8, Vector3(float(t[0]), 1.4, float(t[1])), k.wood_dark)
		for i in 5:
			k.sphere(0.95, Vector3(float(t[0]) + cos(i * 1.3) * 0.6, 3.2 + sin(i * 2.1) * 0.35, float(t[1]) + sin(i * 1.3) * 0.4), k.mat(Color(0.95, 0.52, 0.2).lerp(Color(0.85, 0.32, 0.15), _h(i)), 0.9), null, Vector3.ONE, 12)
	# hedges in clumps along the fences, so the path feels like it winds between them
	for i in 11:
		var z := -9.5 + i * 1.9
		var side := -1.0 if i % 2 == 0 else 1.0
		k.sphere(0.5, Vector3(side * (W / 2.0 - 0.55), 0.32, z), k.mat(Color(0.2, 0.42, 0.2), 0.9), null, Vector3(1.0, 0.8, 1.6), 12)
		k.blocker(Vector3(0.8, 0.7, 1.3), Vector3(side * (W / 2.0 - 0.55), 0.35, z))
	# hotspot: lounge back door (south end)
	var ld: Node3D = k.hotspot("lounge_door", Vector3(0, 0, D / 2.0 - 0.02), Vector3(1.3, 2.4, 0.6), Vector3.ZERO, PI)
	k.box(Vector3(1.15, 2.2, 0.06), Vector3(0, 1.1, 0.02), k.wood_dark, false, ld)
	k.box(Vector3(0.95, 2.05, 0.05), Vector3(0, 1.03, 0.06), k.mat(Color(0.52, 0.32, 0.18), 0.6), false, ld)
	k.box(Vector3(0.55, 0.45, 0.02), Vector3(0, 1.55, 0.09), k.glow(Color(0.9, 0.85, 0.7), 0.35), false, ld)
	k.sphere(0.035, Vector3(0.36, 1.0, 0.1), k.brass, ld)
	# hotspot: bathhouse side door (north end)
	var bd: Node3D = k.hotspot("bath_door", Vector3(0, 0, -D / 2.0 + 0.02), Vector3(1.3, 2.4, 0.6))
	k.box(Vector3(1.15, 2.2, 0.06), Vector3(0, 1.1, 0.02), k.mat(Color(0.16, 0.09, 0.05), 0.8), false, bd)
	k.box(Vector3(0.95, 2.05, 0.05), Vector3(0, 1.03, 0.06), k.mat(Color(0.42, 0.26, 0.14), 0.6), false, bd)
	k.box(Vector3(0.6, 0.4, 0.02), Vector3(0, 1.6, 0.09), k.mat(Color(0.92, 0.9, 0.84), 0.9), false, bd)
	for x in [-0.15, 0.0, 0.15]:
		k.box(Vector3(0.025, 0.4, 0.02), Vector3(x, 1.6, 0.1), k.wood_dark, false, bd)
	k.sphere(0.035, Vector3(-0.36, 1.0, 0.1), k.brass, bd)
	k.box(Vector3(0.7, 0.22, 0.03), Vector3(0, 2.38, 0.06), k.wood_light, false, bd)
	# hotspot: rose bush (halfway, on the bend)
	var rb: Node3D = k.hotspot("rosebush", Vector3(1.5, 0, -0.5), Vector3(1.6, 1.3, 1.4))
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
	k.blocker(Vector3(1.2, 1.2, 1.0), Vector3(1.5, 0.6, -0.5))
	# winding stepping stones from door to door; the stretch by the bush is the "path" hotspot
	var stone_m: Material = k.mat(Color(0.82, 0.82, 0.8), 0.85)
	var path: Node3D = k.hotspot("path", Vector3(-0.6, 0, 2.6), Vector3(2.8, 0.3, 3.6), Vector3(0, 0.1, 0))
	for i in 25:
		var z := 10.0 - i * 0.84
		var x := sin(z * 0.42) * 1.3 - 0.3
		var cz: float = z - 2.6
		var in_spot := absf(cz) < 1.8 and absf(x + 0.6) < 1.4
		var st: MeshInstance3D = k.cyl(0.34 + 0.06 * _h(i), 0.36 + 0.06 * _h(i), 0.06, Vector3(x + 0.6, 0.03, cz) if in_spot else Vector3(x, 0.03, z), stone_m, path if in_spot else null, false, 14)
		st.scale = Vector3(1.2, 1, 0.85)
	k.stone_lantern(Vector3(-2.6, 0, -5.6), 1.1, false)
	k.stone_lantern(Vector3(2.7, 0, 5.2), 1.1, false)
	k.cctv(Vector3(-W / 2.0 + 0.1, 2.3, 0.0), PI / 2.0 + 0.4)
	k.person("bramble", Vector3(-1.9, 0, 4.9))
	k.link_door("lounge_door", "lounge")
	k.link_door("bath_door", "changing")
	k.spawn = Vector3(0, 0, D / 2.0 - 1.3)
	k.look = Vector3(0, 1.1, -4.0)


# =================================================================== Lounge
static func _lounge(k) -> void:
	var W := 14.0
	var D := 12.0
	var H := 5.0
	k.environment("indoor", Color(0.55, 0.42, 0.55), 0.3)
	k.shell(W, D, H, {
		"floor": k.wood_floor(Color(0.2, 0.09, 0.07), Color(0.36, 0.17, 0.11)),
		"wall": k.mat(Color(0.34, 0.12, 0.25), 0.9),
		"wain": k.wood_wall(Color(0.2, 0.08, 0.07), Color(0.3, 0.13, 0.1)), "wain_h": 1.0,
		"trim": k.mat(Color(0.8, 0.6, 0.25), 0.35, 0.7),
		"ceiling": k.mat(Color(0.16, 0.07, 0.12), 0.9)})
	var gold: Material = k.mat(Color(0.9, 0.7, 0.3), 0.3, 0.85)
	var velvet: Material = k.mat(Color(0.62, 0.06, 0.1), 0.85)
	# raised back of the room: you come in high and walk down towards the stage
	k.slab(-W / 2.0, 2.8, W / 2.0, D / 2.0, 0.6, k.wood_floor(Color(0.2, 0.09, 0.07), Color(0.36, 0.17, 0.11)), 0.6)
	k.stairs(Vector3(0, 0, 1.6), Vector3(0, 0.6, 2.8), 4.0, {"mat": k.wood_dark, "rail": "none"})
	for sx in [-1.0, 1.0]:
		k.rail(Vector3(sx * 2.0, 0.6, 2.8), Vector3(sx * W / 2.0, 0.6, 2.8), gold)
		for i in 3:
			k.chair(Vector3(sx * (3.2 + i * 1.1), 0.6, 4.2), PI, velvet, gold)
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
	k.spot(Vector3(0, H - 0.1, -0.5), Vector3(0, 0.5, -D / 2.0 + 1.0), Color(1.0, 0.85, 0.65), 2.6, 9.0, 32.0, true)
	# hotspot: front-row seats
	var cg: Node3D = k.hotspot("chairs", Vector3(0, 0, -2.6), Vector3(3.0, 1.0, 0.9))
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
	k.cyl(0.9, 0.75, 0.1, Vector3(0, 3.7, -0.8), gold)
	for i in 12:
		var a := i * TAU / 12.0
		k.sphere(0.06, Vector3(cos(a) * 0.82, 3.83, -0.8 + sin(a) * 0.82), k.glow(Color(1.0, 0.85, 0.55), 4.0))
	k.cyl(0.01, 0.01, 1.3, Vector3(0, 4.35, -0.8), k.black)
	k.omni(Vector3(0, 3.45, -0.8), Color(1.0, 0.82, 0.6), 1.5, 11.0, true)
	k.wall_lamp(Vector3(-W / 2.0, 2.4, 0.5), PI / 2.0, Color(1.0, 0.8, 0.55), 0.6)
	k.wall_lamp(Vector3(W / 2.0, 2.4, 0.5), -PI / 2.0, Color(1.0, 0.8, 0.55), 0.6)
	k.wall_lamp(Vector3(-2.9, 2.0, -D / 2.0), 0.0, Color(1.0, 0.8, 0.55), 0.6)
	k.wall_lamp(Vector3(2.9, 2.0, -D / 2.0), 0.0, Color(1.0, 0.8, 0.55), 0.6)
	k.table(Vector3(W / 2.0 - 0.5, 0, 0.6), Vector3(0.6, 0.95, 1.4), k.wood_dark, k.wood_dark)
	for i in 3:
		k.cyl(0.04, 0.05, 0.28, Vector3(W / 2.0 - 0.5, 1.09, 0.2 + i * 0.3), k.mat([Color(0.2, 0.6, 0.4), Color(0.75, 0.35, 0.15), Color(0.7, 0.1, 0.2)][i], 0.15))
	k.cctv(Vector3(W / 2.0 - 0.15, 2.95, D / 2.0 - 0.5), -PI / 2.0 - 0.7)
	k.person("lulu", Vector3(-3.6, 0, -1.2))
	k.person("wisp", Vector3(3.6, 0, -1.4))
	k.door("courtyard", "", Vector3(0, 0.6, D / 2.0), PI)
	k.door("backstage", "", Vector3(-W / 2.0, 0, -3.4), PI / 2.0)
	k.link_door("back_door", "garden")
	k.spawn = Vector3(0, 0.6, 4.8)
	k.look = Vector3(0, 1.3, -5.5)


# =================================================================== Storage Closet
static func _storage(k) -> void:
	var W := 7.0
	var D := 6.5
	var H := 2.6
	k.environment("dim", Color(0.42, 0.38, 0.52), 0.24)
	k.plan([[-3.5, -3.25, 1.0, 3.25], [1.0, -3.25, 3.5, 0.0]], 0.0, H, {
		"floor": k.wood_floor(Color(0.15, 0.12, 0.12), Color(0.27, 0.22, 0.2)),
		"wall": k.wood_wall(Color(0.17, 0.14, 0.2), Color(0.27, 0.23, 0.3), 0.22), "wain": null,
		"ceiling": k.mat(Color(0.1, 0.09, 0.12), 0.9), "trim": k.mat(Color(0.1, 0.08, 0.1), 0.9)})
	k.cyl(0.008, 0.008, 0.3, Vector3(-0.3, H - 0.15, -1.2), k.black)
	k.sphere(0.07, Vector3(-0.3, H - 0.35, -1.2), k.glow(Color(1.0, 0.88, 0.62), 5.0))
	k.omni(Vector3(-0.3, H - 0.55, -1.2), Color(1.0, 0.84, 0.6), 1.2, 6.5, true)
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
		k.cyl(0.012, 0.012, 1.9, Vector3(2.8 + i * 0.25, H - 0.95, -0.5), k.mat(Color(0.6, 0.5, 0.35), 0.9))
	k.sphere(0.16, Vector3(3.05, 0.8, -0.5), k.mat(Color(0.55, 0.45, 0.3), 0.95), null, Vector3(1, 1.3, 1))
	# a tall rack making a narrow aisle down the room
	k.box(Vector3(0.5, 2.2, 2.4), Vector3(0.7, 1.1, 2.0), k.wood_dark, true)
	for yy in [0.6, 1.25, 1.9]:
		for i in 3:
			k.box(Vector3(0.36, 0.34, 0.5), Vector3(0.42, yy, 1.2 + i * 0.8), k.mat(Color(0.72, 0.56, 0.36).lerp(Color(0.5, 0.2, 0.5), _h(i + int(yy * 3.0))), 0.9))
	k.cctv(Vector3(W / 2.0 - 0.15, 2.3, -D / 2.0 + 0.4), -PI / 4.0)
	k.person("tumble", Vector3(-1.9, 0, -0.5))
	k.door("backstage", "", Vector3(-1.2, 0, D / 2.0), PI, {"h": 2.0})
	k.spawn = Vector3(-1.2, 0, 2.0)
	k.look = Vector3(-0.4, 1.1, -3.0)


# =================================================================== Gift Shop
static func _giftshop(k) -> void:
	var W := 12.0
	var D := 6.0
	var H := 3.2
	k.environment("indoor", Color(0.66, 0.58, 0.5), 0.35)
	k.plan([[-6.0, -3.0, 6.0, 3.0], [-1.6, 3.0, 1.6, 6.0, 2.7]], 0.0, H, {
		"floor": k.wood_floor(Color(0.42, 0.26, 0.13), Color(0.66, 0.45, 0.25)),
		"wall": k.mat(Color(0.92, 0.85, 0.72), 0.95),
		"wain": k.wood_wall(Color(0.4, 0.25, 0.13), Color(0.55, 0.36, 0.2)), "wain_h": 0.95,
		"ceiling": k.mat(Color(0.75, 0.62, 0.46), 0.9)})
	_ceiling_light(k, Vector3(-3.0, 2.75, 0.0), H, 1.0, true)
	_ceiling_light(k, Vector3(3.0, 2.75, 0.0), H, 1.0, false)
	k.paper_lantern(Vector3(0, 2.2, 4.6), Color(1.0, 0.86, 0.64), 0.7, true, false, 0.8, 2.7)
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
	var pd: Node3D = k.hotspot("pedestal", Vector3(-0.4, 0, 0.2), Vector3(1.2, 1.4, 1.2))
	var marble: Material = k.mat(Color(0.95, 0.94, 0.92), 0.25)
	k.cyl(0.5, 0.52, 0.08, Vector3(0, 0.04, 0), marble, pd)
	k.cyl(0.4, 0.4, 0.8, Vector3(0, 0.48, 0), marble, pd, true)
	k.cyl(0.48, 0.48, 0.07, Vector3(0, 0.915, 0), marble, pd)
	var plate: MeshInstance3D = k.box(Vector3(0.32, 0.18, 0.02), Vector3(0, 0.55, 0.41), k.brass, false, pd)
	plate.rotation.x = -0.15
	k.box(Vector3(0.22, 0.02, 0.01), Vector3(0, 0.58, 0.425), k.black, false, pd)
	k.box(Vector3(0.16, 0.02, 0.01), Vector3(0, 0.53, 0.425), k.black, false, pd)
	k.spot(Vector3(-0.4, H - 0.1, 0.6), Vector3(-0.4, 0.9, 0.2), Color(1.0, 0.95, 0.85), 2.0, 5.0, 18.0, false)
	# counter with the price-tag gun (right)
	var counter := Vector3(4.2, 0, 0.2)
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
	# freestanding shelves make aisles on the left side of the shop
	for r in 2:
		var gz := -0.6 + r * 2.0
		k.box(Vector3(3.0, 1.3, 0.5), Vector3(-4.0, 0.65, gz), k.wood_mid, true)
		for i in 7:
			k.box(Vector3(0.28, 0.24, 0.42), Vector3(-5.2 + i * 0.4, 1.42, gz), k.mat(flag_cols[(i + r) % 5].lightened(0.15), 0.8))
	k.person("fennel", Vector3(-1.9, 0, 2.0))
	k.person("duchess", Vector3(4.7, 0, -0.75))
	k.door("arcade", "", Vector3(0, 0, 6.0), PI)
	k.spawn = Vector3(0, 0, 4.7)
	k.look = Vector3(0, 1.1, -3.0)


# =================================================================== Dining Hall
static func _dining(k) -> void:
	var W := 8.0
	var D := 16.0
	var H := 4.5
	k.environment("indoor", Color(0.65, 0.55, 0.45), 0.32)
	k.shell(W, D, H, {
		"floor": k.wood_floor(Color(0.3, 0.17, 0.09), Color(0.48, 0.3, 0.16)),
		"wall": k.mat(Color(0.88, 0.8, 0.66), 0.95),
		"wain": k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.42, 0.26, 0.14)), "wain_h": 0.9,
		"ceiling": k.mat(Color(0.4, 0.26, 0.14), 0.85), "beams": true})
	for x in [-1.15, 1.05]:
		k.box(Vector3(0.2, H, 0.12), Vector3(x, H / 2.0, -D / 2.0 + 0.06), k.wood_dark)
	k.shoji(Vector2(1.9, 1.6), Vector3(-2.7, 2.0, -D / 2.0 + 0.02), 0.0, Color(1.0, 0.9, 0.7), 1.3, Vector2(4, 3))
	k.shoji(Vector2(1.3, 1.6), Vector3(3.1, 2.0, -D / 2.0 + 0.02), 0.0, Color(1.0, 0.9, 0.7), 1.3, Vector2(3, 3))
	for z in [-5.0, -1.0, 3.0]:
		for sx in [-1.0, 1.0]:
			k.shoji(Vector2(2.2, 2.0), Vector3(sx * (W / 2.0 - 0.02), 2.3, z), -sx * PI / 2.0, Color(1.0, 0.9, 0.7), 1.1, Vector2(4, 4), z == -1.0)
	# columns down both sides make it feel like a long hall
	for z in [-6.5, -3.0, 0.5, 4.0]:
		for sx in [-1.0, 1.0]:
			k.box(Vector3(0.36, H, 0.36), Vector3(sx * 3.1, H / 2.0, z), k.wood_dark, true)
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
	var mb: Node3D = k.hotspot("menu", Vector3(1.75, 1.15, -D / 2.0 + 0.06), Vector3(0.95, 1.25, 0.4), Vector3(0, 0.55, 0.1))
	k.box(Vector3(0.78, 1.0, 0.05), Vector3(0, 0.55, 0.0), k.wood_dark, false, mb)
	var crop: MeshInstance3D = k.bg_crop("dining", Rect2(812, 152, 116, 140), Vector2(0.68, 0.88), Vector3(0, 0.55, 0.03), 0.0, mb)
	if crop == null:
		k.box(Vector3(0.68, 0.88, 0.01), Vector3(0, 0.55, 0.03), k.mat(Color(0.1, 0.14, 0.12), 0.9), false, mb)
	k.cyl(0.005, 0.005, 0.4, Vector3(0, 1.22, 0.0), k.black, mb)
	# hotspot: the long dinner table
	var tb: Node3D = k.hotspot("table", Vector3(0, 0, -3.2), Vector3(2.0, 1.15, 4.7))
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
	k.hanging_lamp(Vector3(0, 2.8, -4.4), Color(1.0, 0.84, 0.6), 1.3, H, true, 9.0)
	k.hanging_lamp(Vector3(0, 2.8, -2.0), Color(1.0, 0.84, 0.6), 1.0, H, false, 8.0)
	k.hanging_lamp(Vector3(0, 2.8, 3.2), Color(1.0, 0.84, 0.6), 1.1, H, false, 9.0)
	# a couple of small round tables at the far end
	for t in [Vector3(-1.6, 0, 3.4), Vector3(1.6, 0, 5.2)]:
		var tp: Vector3 = t
		k.cyl(0.55, 0.55, 0.05, tp + Vector3(0, 0.75, 0), k.white, null, false, 20)
		k.cyl(0.05, 0.08, 0.72, tp + Vector3(0, 0.36, 0), k.wood_dark)
		k.blocker(Vector3(0.9, 0.9, 0.9), tp + Vector3(0, 0.45, 0))
		for a in [0.5, 2.6, 4.7]:
			k.chair(tp + Vector3(cos(a) * 0.85, 0, sin(a) * 0.85), atan2(-cos(a), -sin(a)), k.mat(Color(0.5, 0.1, 0.12), 0.85), k.wood_dark)
	k.plant(Vector3(-W / 2.0 + 0.5, 0, D / 2.0 - 0.6))
	k.plant(Vector3(W / 2.0 - 0.5, 0, D / 2.0 - 0.6))
	k.cctv(Vector3(W / 2.0 - 0.15, 3.4, -D / 2.0 + 0.5), -PI / 2.0 + 0.6)
	k.person("grub", Vector3(-2.1, 0, -0.1))
	k.person("pepper", Vector3(2.2, 0, 0.1))
	k.door("arcade", "", Vector3(0, 0, D / 2.0), PI)
	k.spawn = Vector3(0, 0, D / 2.0 - 1.3)
	k.look = Vector3(0, 1.3, -6.0)


# =================================================================== Free Time hub: resort courtyard (afternoon)
## The inner courtyard of Yuzu Springs in golden afternoon light: the main inn (steel-shuttered entrance) to the
## north, a veranda and a food stall to the east, the garden to the west, an outdoor yuzu bath in the middle.
## Every guest stands somewhere that suits them.
static func _courtyard(k) -> void:
	var W := 22.0
	var D := 20.0
	k.bounds = Vector2(W, D)
	var free_time: bool = k.mode == "freetime"
	if free_time:
		var env: Environment = k.environment("outdoor_dusk", Color(0.85, 0.7, 0.6), 0.55)
		env.tonemap_exposure = 1.0
		k.sun(Vector3(-24, -62, 0), Color(1.0, 0.8, 0.58), 1.35)
	else:
		k.environment("outdoor_morning", Color(0.8, 0.83, 0.82), 0.58)
		k.sun(Vector3(-44, 30, 0), Color(1.0, 0.95, 0.86), 1.15)
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
	k.stairs(Vector3(ex - 3.4, 0, 3.0), Vector3(ex - 2.2, 0.35, 3.0), 1.9, {"count": 2, "mat": k.wood_light, "rail": "none"})
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
	k.box(Vector3(2.6, 0.2, 0.3), Vector3(0, 2.75, D / 2.0 - 0.05), k.mat(Color(0.2, 0.21, 0.27), 0.7))
	for i in 7:
		var hill: Material = k.mat(Color(0.42, 0.36, 0.48).lerp(Color(0.85, 0.6, 0.55), 0.3 + 0.12 * (i % 3)), 1.0)
		k.sphere(1.0, Vector3(-30 + i * 10.0, -2.0, D / 2.0 + 22 + (i % 2) * 6.0), hill, null, Vector3(10, 6 + (i % 3) * 2.0, 5), 16)
	# ---- centre: koi pond with a stone bridge you can walk over
	var pc := Vector3(0, 0, -1.5)
	var rx := 3.6
	var rz := 2.6
	var bottom: MeshInstance3D = k.cyl(1.0, 1.0, 0.1, pc + Vector3(0, 0.05, 0), k.mat(Color(0.08, 0.16, 0.14), 0.6), null, false, 48)
	bottom.scale = Vector3(rx, 1, rz)
	var water: MeshInstance3D = k.cyl(1.0, 1.0, 0.3, pc + Vector3(0, 0.17, 0), k.water(Color(0.05, 0.2, 0.18), Color(0.2, 0.5, 0.42), 0.06), null, false, 48)
	water.scale = Vector3(rx, 1, rz)
	for sx in [-1.0, 1.0]:
		k.blocker(Vector3(rx - 0.9, 0.5, rz * 1.7), pc + Vector3(sx * (0.9 + (rx - 0.9) / 2.0), 0.25, 0))
	var rock_m: Material = k.mat(Color(0.48, 0.45, 0.42), 0.55)
	for i in 30:
		var a := i * TAU / 30.0
		if absf(cos(a)) * rx < 1.05:
			continue   # the bridge lands here
		var p: Vector3 = pc + Vector3(cos(a) * (rx + 0.1), 0.15, sin(a) * (rz + 0.1))
		k.rock(p, Vector3(0.95, 0.48, 0.75) * (0.8 + 0.45 * _h(i)), rock_m, -a, false)
	for i in 9:
		var a := i * 2.399 + 0.7
		var rr := 0.35 + 0.5 * _h(i + 21)
		var koi: Vector3 = pc + Vector3(cos(a) * rx * rr, 0.325, sin(a) * rz * rr)
		var fish: MeshInstance3D = k.sphere(0.13, koi, k.mat(Color(1.0, 0.45, 0.12) if i % 3 else Color(0.97, 0.95, 0.88), 0.5), null, Vector3(0.5, 0.3, 1.5), 8)
		fish.rotation.y = a * 2.0
	for i in 8:
		var a := i * 1.7 + 0.2
		var pad: MeshInstance3D = k.cyl(0.2 + 0.08 * _h(i), 0.2 + 0.08 * _h(i), 0.012, pc + Vector3(cos(a) * rx * 0.72, 0.335, sin(a) * rz * 0.72), k.mat(Color(0.25, 0.5, 0.25), 0.6), null, false, 12)
		pad.scale = Vector3(1, 1, 0.85)
	var bridge_m: Material = k.mat(Color(0.62, 0.6, 0.56), 0.9)
	k.stairs(pc + Vector3(0, 0, rz + 0.5), pc + Vector3(0, 0.66, 0), 1.7, {"count": 9, "mat": bridge_m, "rail_mat": k.wood_dark})
	k.stairs(pc + Vector3(0, 0, -rz - 0.5), pc + Vector3(0, 0.66, 0), 1.7, {"count": 9, "mat": bridge_m, "rail_mat": k.wood_dark})
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
	k.note("Koi pond", "The koi don't seem worried about anything. Must be nice.", pc + Vector3(2.6, 0, 2.6), Vector3(1.2, 0.8, 1.0), Vector3(0, 0.4, 0))
	k.door("lobby", "", Vector3(-6.0, 0, inn_z), 0.0)
	k.door("lounge", "", Vector3(ex, 0.35, 3.0), -PI / 2.0)
	k.door("walkway", "", Vector3(0, 0, D / 2.0), PI)
	if free_time:
		k.person("coco", Vector3(2.5, 0, 2.0))
		k.person("bruno", Vector3(-4.0, 0, 1.6))
		k.person("lulu", Vector3(5.6, 0.35, -6.6))
		k.person("grub", Vector3(8.0, 0, 7.2))
		k.person("bramble", Vector3(-8.4, 0, -4.2))
		k.person("fennel", Vector3(-8.0, 0, 3.6))
		k.person("nibs", Vector3(-3.9, 0, -4.4))
	k.spawn = Vector3(0, 0, 8.4)
	k.look = Vector3(0, 1.2, -4.0)


# =================================================================== shared props for the connecting spaces
static func _shutter(k, x: float, z: float, w: float, h: float) -> void:
	k.quad(Vector2(w, h), Vector3(x, h / 2.0, z + 0.08), k.stripes(Color(0.52, 0.54, 0.57), Color(0.33, 0.35, 0.38), 34.0))
	k.box(Vector3(w + 0.4, 0.4, 0.4), Vector3(x, h + 0.2, z + 0.2), k.steel)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.18, h, 0.22), Vector3(x + sx * (w / 2.0 + 0.1), h / 2.0, z + 0.12), k.steel)
	for i in int(w / 0.4):
		k.box(Vector3(0.4, 0.2, 0.06), Vector3(x - w / 2.0 + 0.2 + i * 0.4, 0.1, z + 0.12), k.mat(Color(0.95, 0.78, 0.1) if i % 2 == 0 else Color(0.08, 0.07, 0.06), 0.6))
	k.box(Vector3(1.1, 0.5, 0.04), Vector3(x + 1.0, 1.75, z + 0.13), k.mat(Color(0.95, 0.75, 0.1), 0.5))
	k.label("NO EXIT", Vector3(x + 1.0, 1.75, z + 0.16), 0.0, 56, Color(0.08, 0.06, 0.05), null, 0.004, 0)


static func _sofa(k, pos: Vector3, rot: float, m: Material) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot
	k.root.add_child(g)
	k.box(Vector3(2.2, 0.42, 0.85), Vector3(0, 0.21, 0), m, true, g)
	k.box(Vector3(2.2, 0.55, 0.2), Vector3(0, 0.68, -0.33), m, false, g)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.2, 0.3, 0.85), Vector3(sx * 1.0, 0.56, 0), m, false, g)


## A shut, name-plated guest door: just for looking at.
static func _guest_door(k, pos: Vector3, rot: float, who: String) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot
	k.root.add_child(g)
	k.box(Vector3(1.15, 2.2, 0.06), Vector3(0, 1.1, 0.02), k.wood_dark, false, g)
	k.box(Vector3(0.95, 2.05, 0.05), Vector3(0, 1.03, 0.06), k.mat(Color(0.5, 0.31, 0.17), 0.6), false, g)
	k.sphere(0.035, Vector3(0.36, 1.02, 0.1), k.brass, g)
	k.box(Vector3(0.56, 0.16, 0.02), Vector3(0, 1.62, 0.095), k.brass, false, g)
	k.label(Cast.display_name(who), Vector3(0, 1.62, 0.11), 0.0, 26, Color(0.16, 0.08, 0.03), g, 0.0026, 0)
	var n: Node3D = k.note(Cast.display_name(who) + "'s door", "Locked. Knocking would be rude, anyway.", pos, Vector3(1.2, 2.2, 0.5), Basis(Vector3.UP, rot) * Vector3(0, 1.1, 0.25))
	n.rotation.y = 0.0


# =================================================================== Grand Lobby + upstairs balcony + Guest Wing (one continuous space)
## Two storeys tall. A wide staircase and a lift go up to a balcony and on into the guest wing hallway.
static func _lobby(k) -> void:
	var HW := 9.0
	var zn := -7.0
	var zs := 8.5
	var H := 7.2
	var Y2 := 3.6
	k.bounds = Vector2(HW * 2.0, zs - zn)
	k.environment("indoor", Color(0.62, 0.52, 0.44), 0.36)
	var o := {"wall": k.mat(Color(0.86, 0.79, 0.65), 0.95), "wain": k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.44, 0.27, 0.14)),
		"wain_h": 1.1, "trim": k.wood_dark}
	k.slab(-HW, zn, HW, zs, 0.0, k.wood_floor(Color(0.3, 0.17, 0.09), Color(0.5, 0.31, 0.16)))
	k.slab(-HW, zn, HW, zs, H + 0.12, k.mat(Color(0.3, 0.2, 0.12), 0.85), 0.12, false)
	for z in [-5.0, -1.0, 3.0, 7.0]:
		k.box(Vector3(HW * 2.0, 0.3, 0.3), Vector3(0, H - 0.15, z), k.wood_dark)
	k.wall_run(Vector2(-HW, zn), Vector2(HW, zn), 0.0, H, o)
	k.wall_run(Vector2(HW, zn), Vector2(HW, zs), 0.0, H, o)
	k.wall_run(Vector2(-HW, zs), Vector2(-HW, zn), 0.0, H, o)
	# south wall (t = metres from x = +HW): hallway opening upstairs, lift shaft on both floors
	k.wall_run(Vector2(HW, zs), Vector2(-HW, zs), 0.0, H, o, [
		[HW - 1.6, HW + 1.6, Y2, Y2 + 2.5], [HW - 6.0, HW - 4.0, 0.0, 2.5], [HW - 6.0, HW - 4.0, Y2, Y2 + 2.5]])
	k.box(Vector3(3.0, 0.012, 8.0), Vector3(0, 0.006, -3.2), k.mat(Color(0.75, 0.55, 0.2), 0.4, 0.5))
	k.box(Vector3(2.7, 0.018, 7.9), Vector3(0, 0.009, -3.25), k.mat(Color(0.42, 0.035, 0.045), 0.9))
	# north wall: steel shutter, shoji, key cubbies behind the front desk
	_shutter(k, 0.0, zn, 4.4, 2.75)
	k.shoji(Vector2(3.6, 2.2), Vector3(-5.8, 2.1, zn + 0.02), 0.0, Color(1.0, 0.88, 0.66), 1.4, Vector2(6, 4))
	k.box(Vector3(3.4, 0.7, 0.08), Vector3(0, 3.7, zn + 0.05), k.wood_dark)
	k.label("YUZU SPRINGS", Vector3(0, 3.7, zn + 0.1), 0.0, 84, Color(0.98, 0.82, 0.48), null, 0.005, 6)
	k.box(Vector3(2.8, 1.5, 0.2), Vector3(5.8, 2.0, zn + 0.1), k.wood_dark)
	for r in 3:
		for c in 6:
			k.box(Vector3(0.38, 0.38, 0.02), Vector3(4.75 + c * 0.42, 1.55 + r * 0.45, zn + 0.21), k.mat(Color(0.07, 0.04, 0.02), 0.9))
			if (r * 7 + c * 3) % 4 != 0:
				k.box(Vector3(0.05, 0.1, 0.02), Vector3(4.75 + c * 0.42, 1.5 + r * 0.45, zn + 0.23), k.brass)
	k.box(Vector3(3.6, 0.95, 0.7), Vector3(5.8, 0.475, zn + 1.7), k.wood_mid, true)
	k.box(Vector3(3.8, 0.05, 0.85), Vector3(5.8, 0.975, zn + 1.7), k.wood_light)
	k.cyl(0.08, 0.08, 0.025, Vector3(4.6, 1.01, zn + 1.7), k.brass)
	k.sphere(0.06, Vector3(4.6, 1.04, zn + 1.7), k.brass, null, Vector3(1, 0.7, 1))
	k.note("Guest ledger", "Fifteen names, all checked in on the same day. The check-out column is empty.", Vector3(6.2, 0.98, zn + 1.7), Vector3(0.8, 0.5, 0.7), Vector3(0, 0.15, 0))
	k.box(Vector3(0.5, 0.03, 0.36), Vector3(6.2, 1.01, zn + 1.7), k.paper)
	k.cctv(Vector3(-2.7, 3.2, zn + 0.1), 0.3)
	k.cctv(Vector3(2.7, 3.2, zn + 0.1), -0.3)
	# seating on the west side, plants, big lanterns in the open middle
	var couch: Material = k.mat(Color(0.46, 0.15, 0.11), 0.85)
	_sofa(k, Vector3(-7.9, 0, 2.2), PI / 2.0, couch)
	k.table(Vector3(-6.2, 0, 2.2), Vector3(0.7, 0.42, 1.3), k.wood_light, k.wood_dark)
	k.plant(Vector3(-2.9, 0, zn + 0.7))
	k.plant(Vector3(2.9, 0, zn + 0.7))
	k.plant(Vector3(-2.3, 0, 0.5))
	k.plant(Vector3(2.3, 0, 0.5))
	k.paper_lantern(Vector3(0, 5.2, -2.0), Color(1.0, 0.86, 0.64), 2.4, true, true, 1.6, H)
	k.paper_lantern(Vector3(-4.6, 4.8, 1.8), Color(1.0, 0.45, 0.32), 1.4, true, false, 1.0, H)
	k.paper_lantern(Vector3(4.6, 4.8, 1.8), Color(1.0, 0.86, 0.64), 1.4, true, false, 1.0, H)
	k.omni(Vector3(0, 2.8, 7.2), Color(1.0, 0.84, 0.62), 0.9, 8.0)
	# staircase, balcony arms and rails
	k.stairs(Vector3(0, 0, 0.8), Vector3(0, Y2, 5.8), 3.4, {"mat": k.wood_light, "rail_mat": k.wood_dark})
	var bal: Material = k.wood_floor(Color(0.32, 0.18, 0.1), Color(0.52, 0.33, 0.18))
	k.slab(-HW, 5.8, HW, zs, Y2, bal)
	k.slab(-HW, zn, -7.3, 5.8, Y2, bal)
	k.slab(7.3, zn, HW, 5.8, Y2, bal)
	var rw: Material = k.wood_dark
	k.rail(Vector3(-7.3, Y2, 5.8), Vector3(-1.7, Y2, 5.8), rw)
	k.rail(Vector3(1.7, Y2, 5.8), Vector3(7.3, Y2, 5.8), rw)
	k.rail(Vector3(-7.3, Y2, zn), Vector3(-7.3, Y2, 5.8), rw)
	k.rail(Vector3(7.3, Y2, zn), Vector3(7.3, Y2, 5.8), rw)
	k.note("View over the lobby", "Fancy from up here. You can almost forget about the shutter.", Vector3(-4.0, Y2, 6.0), Vector3(1.6, 1.3, 0.5), Vector3(0, 0.65, 0))
	# under the balcony: a vending machine and a bench
	k.box(Vector3(1.0, 1.9, 0.7), Vector3(-5.0, 0.95, zs - 0.45), k.mat(Color(0.75, 0.15, 0.15), 0.4), true)
	k.box(Vector3(0.75, 1.1, 0.02), Vector3(-5.0, 1.25, zs - 0.8 - 0.02), k.glow(Color(1.0, 0.86, 0.5), 1.1))
	k.note("Vending machine", "Yuzu soda, yuzu tea, yuzu water. And something labelled just 'YUZU'.", Vector3(-5.0, 0, zs - 0.85), Vector3(1.2, 2.0, 0.5), Vector3(0, 1.0, 0))
	k.box(Vector3(1.8, 0.45, 0.5), Vector3(-2.4, 0.225, zs - 0.4), k.wood_light, true)
	# the lift
	var lift_style := {"sign": "1F", "wall": k.wood_mid}
	k.lift("lobby_1f", Vector3(5, 0, zs), PI, "lobby_2f", "", "2F  Guest Wing", lift_style)
	k.lift("lobby_2f", Vector3(5, Y2, zs), PI, "lobby_1f", "", "1F  Grand Lobby", {"sign": "2F", "wall": k.wood_mid})
	# ---- Guest Wing hallway (upstairs, runs south from the balcony)
	var hy := Y2
	var hz1 := zs + 16.0
	var wing := {"floor": k.wood_floor(Color(0.28, 0.16, 0.09), Color(0.44, 0.27, 0.14), 0.18),
		"wall": k.mat(Color(0.84, 0.76, 0.62), 0.95), "wain": k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.42, 0.26, 0.14)), "wain_h": 0.95,
		"trim": k.wood_dark, "ceiling": k.mat(Color(0.32, 0.21, 0.12), 0.85), "open": ["n"]}
	k.plan([[-1.6, zs, 1.6, hz1]], hy, 2.9, wing)
	k.rug(Vector3(0, hy, (zs + hz1) / 2.0), Vector2(1.5, 15.4), Color(0.45, 0.1, 0.12), Color(0.8, 0.6, 0.25))
	k.shoji(Vector2(2.2, 1.5), Vector3(0, hy + 1.6, hz1 - 0.02), PI, Color(1.0, 0.9, 0.72), 1.5, Vector2(5, 3))
	var who := ["bramble", "bruno", "coco", "duchess", "fennel", "grub", "lulu", "marigold", "tumble", "pepper", "nibs", "reginald", "wisp", "zuzu"]
	k.door("mochi_room", "", Vector3(1.6, hy, zs + 1.4), -PI / 2.0)
	var idx := 0
	for i in 8:
		var z := zs + 1.4 + i * 1.95
		if i > 0:
			_guest_door(k, Vector3(1.6, hy, z), -PI / 2.0, who[idx])
			idx += 1
		if i < 7:
			_guest_door(k, Vector3(-1.6, hy, z), PI / 2.0, who[idx])
			idx += 1
		if i % 2 == 0:
			k.paper_lantern(Vector3(0, hy + 2.45, z + 1.0), Color(1.0, 0.86, 0.64), 0.6, true, false, 0.9, hy + 2.9)
	k.cctv(Vector3(-1.5, hy + 2.5, hz1 - 0.3), PI / 2.0 + 0.9)
	k.door("arcade", "", Vector3(HW, 0, -2.0), -PI / 2.0)
	k.door("courtyard", "", Vector3(-HW, 0, -2.0), PI / 2.0)
	if k.mode == "freetime":
		k.person("reginald", Vector3(-3.4, 0, -2.6))
		k.person("tumble", Vector3(-7.0, 0, 3.8))
		k.person("pepper", Vector3(2.6, 0, -3.9))
		k.person("zuzu", Vector3(0.9, hy, zs + 6.2))
		k.person("marigold", Vector3(-0.9, hy, zs + 11.0))
	k.spawn = Vector3(0, 0, -2.0)
	k.look = Vector3(0, 2.2, 6.0)


# =================================================================== Shop Arcade (L-shaped indoor street)
static func _arcade(k) -> void:
	k.environment("indoor", Color(0.62, 0.54, 0.46), 0.36)
	var H := 2.9
	k.plan([[-1.5, -12.0, 1.5, 2.0], [1.5, -12.0, 13.0, -9.0]], 0.0, H, {
		"floor": k.stone_floor(Color(0.5, 0.42, 0.34), Color(0.64, 0.55, 0.44), 0.6),
		"wall": k.mat(Color(0.92, 0.86, 0.72), 0.95), "wain": k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.44, 0.27, 0.14)), "wain_h": 0.85,
		"trim": k.wood_dark, "ceiling": k.mat(Color(0.5, 0.35, 0.2), 0.85)})
	for i in 5:
		k.paper_lantern(Vector3(0, 2.25, 0.5 - i * 2.9), Color(1.0, 0.8, 0.55) if i % 2 == 0 else Color(1.0, 0.45, 0.32), 0.75, true, false, 1.0, H)
	for i in 4:
		k.paper_lantern(Vector3(3.5 + i * 2.8, 2.25, -10.5), Color(1.0, 0.45, 0.32) if i % 2 == 0 else Color(1.0, 0.8, 0.55), 0.75, true, false, 1.0, H)
	# gift-shop window on the west wall
	var wz := -6.0
	k.box(Vector3(0.1, 1.4, 3.0), Vector3(-1.45, 1.35, wz + 3.0), k.wood_dark)
	k.box(Vector3(0.04, 1.2, 2.8), Vector3(-1.38, 1.35, wz + 3.0), k.glow(Color(1.0, 0.92, 0.75), 0.9))
	for i in 5:
		var pp := Vector3(-1.33, 0.95, wz + 2.0 + i * 0.5)
		k.sphere(0.13, pp, k.mat(Color(0.6, 0.4, 0.24), 0.95), null, Vector3(0.9, 0.85, 1.1), 10)
		k.sphere(0.1, pp + Vector3(0, 0.15, 0), k.mat(Color(0.6, 0.4, 0.24), 0.95), null, Vector3.ONE, 10)
	k.note("Shop window", "Rows of plush capybaras, all smiling. It's a bit much.", Vector3(-1.2, 0, wz + 3.0), Vector3(0.6, 1.6, 2.6), Vector3(0, 1.2, 0))
	# posters, a bench, curtains at the corner
	k.box(Vector3(0.05, 1.0, 0.75), Vector3(1.47, 1.65, -3.0), k.mat(Color(0.1, 0.35, 0.34), 0.8))
	k.label("RELAX!", Vector3(1.43, 1.85, -3.0), -PI / 2.0, 36, Style.GOLD, null, 0.0032, 6)
	k.label("or else", Vector3(1.43, 1.5, -3.0), -PI / 2.0, 22, Style.TEXT, null, 0.0032, 4)
	k.note("Poster", "Relax! Or else. Very welcoming, Warden.", Vector3(1.2, 0, -3.0), Vector3(0.5, 1.2, 1.0), Vector3(0, 1.65, 0))
	k.box(Vector3(0.5, 0.45, 1.6), Vector3(1.15, 0.225, -6.6), k.wood_light, true)
	for i in 4:
		k.box(Vector3(0.6, 0.85, 0.02), Vector3(-1.05 + i * 0.7, 2.45, -8.9), k.mat(Color(0.2, 0.25, 0.5) if i % 2 == 0 else Color(0.7, 0.15, 0.15), 0.9))
	k.plant(Vector3(12.2, 0, -11.3), 0.9)
	k.plant(Vector3(-0.9, 0, -11.3), 0.9)
	k.cctv(Vector3(12.8, 2.5, -9.2), -PI + 0.4)
	k.door("lobby", "", Vector3(0, 0, 2.0), PI)
	k.door("giftshop", "", Vector3(-1.5, 0, -6.6), PI / 2.0)
	k.door("dining", "", Vector3(13.0, 0, -10.5), -PI / 2.0)
	if k.mode == "freetime":
		k.person("duchess", Vector3(-0.8, 0, -2.8))
		k.person("wisp", Vector3(9.0, 0, -11.0))
	k.spawn = Vector3(0, 0, 0.8)
	k.look = Vector3(0, 1.3, -10.0)


# =================================================================== Bathhouse Walkway (roofed, open-sided, in the morning air)
static func _walkway(k) -> void:
	k.environment("outdoor_morning", Color(0.8, 0.84, 0.82), 0.58)
	k.sun(Vector3(-42, 40, 0), Color(1.0, 0.95, 0.86), 1.05)
	k.bounds = Vector2(16, 16)
	k.box(Vector3(60, 0.2, 60), Vector3(5, -0.12, -7), k.smat(Kit.SH_GRASS), true)
	var deck: Material = k.wood_floor(Color(0.4, 0.25, 0.13), Color(0.6, 0.4, 0.22), 0.16)
	k.slab(-1.4, -14.0, 1.4, 0.0, 0.02, deck, 0.1, false)
	k.slab(1.4, -14.0, 12.0, -11.2, 0.02, deck, 0.1, false)
	# a little humped bridge over a stream, halfway along
	k.box(Vector3(30, 0.02, 1.3), Vector3(0, 0.02, -6.2), k.water(Color(0.06, 0.25, 0.28), Color(0.3, 0.65, 0.6), 0.08))
	k.stairs(Vector3(0, 0.02, -4.4), Vector3(0, 0.5, -6.2), 2.6, {"count": 6, "mat": k.wood_light, "rail": "none"})
	k.stairs(Vector3(0, 0.02, -8.0), Vector3(0, 0.5, -6.2), 2.6, {"count": 6, "mat": k.wood_light, "rail": "none"})
	# roof on posts
	var post: Material = k.wood_dark
	var roof_m: Material = k.mat(Color(0.2, 0.21, 0.26), 0.7)
	k.slab(-1.8, -14.4, 1.8, 0.2, 3.1, roof_m, 0.14, false)
	k.slab(1.8, -14.4, 12.2, -10.8, 3.1, roof_m, 0.14, false)
	for i in 6:
		for sx in [-1.35, 1.35]:
			k.cyl(0.07, 0.07, 3.0, Vector3(sx, 1.5, -0.3 - i * 2.7), post)
	for i in 4:
		for z in [-13.95, -11.25]:
			k.cyl(0.07, 0.07, 3.0, Vector3(3.6 + i * 2.7, 1.5, z), post)
	# rails keep you on the walkway
	var r: Material = k.wood_dark
	k.rail(Vector3(-1.38, 0.02, 0.0), Vector3(-1.38, 0.02, -4.4), r, 0.9)
	k.rail(Vector3(1.38, 0.02, 0.0), Vector3(1.38, 0.02, -4.4), r, 0.9)
	k.rail(Vector3(-1.38, 0.02, -4.4), Vector3(-1.38, 0.5, -6.2), r, 0.9)
	k.rail(Vector3(1.38, 0.02, -4.4), Vector3(1.38, 0.5, -6.2), r, 0.9)
	k.rail(Vector3(-1.38, 0.5, -6.2), Vector3(-1.38, 0.02, -8.0), r, 0.9)
	k.rail(Vector3(1.38, 0.5, -6.2), Vector3(1.38, 0.02, -8.0), r, 0.9)
	k.rail(Vector3(-1.38, 0.02, -8.0), Vector3(-1.38, 0.02, -14.0), r, 0.9)
	k.rail(Vector3(1.38, 0.02, -8.0), Vector3(1.38, 0.02, -11.2), r, 0.9)
	k.rail(Vector3(-1.38, 0.02, -14.0), Vector3(12.0, 0.02, -14.0), r, 0.9)
	k.rail(Vector3(1.38, 0.02, -11.2), Vector3(12.0, 0.02, -11.2), r, 0.9)
	for i in 5:
		k.paper_lantern(Vector3(0, 2.5, -1.2 - i * 3.0), Color(1.0, 0.86, 0.64), 0.65, i % 2 == 0, false, 0.7, 3.04)
	for i in 3:
		k.paper_lantern(Vector3(3.8 + i * 3.0, 2.5, -12.6), Color(1.0, 0.86, 0.64), 0.65, i % 2 == 0, false, 0.7, 3.04)
	# bamboo groves, stone lanterns and gravel beyond the rails
	var stem: Material = k.mat(Color(0.5, 0.62, 0.3), 0.5)
	var leaf: Material = k.mat(Color(0.3, 0.52, 0.24), 0.8)
	for i in 34:
		var a := i * 2.399
		var ox := -7.0 + 22.0 * _h(i + 5)
		var oz := -18.0 + 18.0 * _h(i + 13)
		if ox > -2.4 and ox < 2.4 and oz > -15.0:
			continue
		if ox > 0.0 and ox < 13.0 and oz > -15.0 and oz < -10.2:
			continue
		k.cyl(0.05, 0.06, 4.2, Vector3(ox, 2.1, oz), stem, null, false, 7)
		k.sphere(0.6, Vector3(ox + cos(a) * 0.15, 4.0, oz + sin(a) * 0.15), leaf, null, Vector3(1.0, 0.7, 1.0), 8)
	k.stone_lantern(Vector3(3.0, 0, -6.0), 1.1, false)
	k.stone_lantern(Vector3(-3.2, 0, -10.0), 1.1, false)
	k.note("Bamboo", "Somewhere behind all this bamboo there must be a wall. There's always a wall.", Vector3(1.0, 0, -9.6), Vector3(0.6, 1.3, 1.4), Vector3(0.3, 0.8, 0))
	# the two end walls carry the doors
	k.box(Vector3(3.4, 3.1, 0.3), Vector3(0, 1.55, 0.15), k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.44, 0.28, 0.15)), true)
	k.box(Vector3(0.3, 3.1, 3.4), Vector3(12.15, 1.55, -12.6), k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.44, 0.28, 0.15)), true)
	k.door("courtyard", "", Vector3(0, 0, 0.0), PI)
	k.door("changing", "", Vector3(12.0, 0, -12.6), -PI / 2.0, {"mat": k.wood_light})
	k.spawn = Vector3(0, 0, -1.2)
	k.look = Vector3(0, 1.3, -10.0)


# =================================================================== Backstage Steps (narrow, dim, going down)
static func _backstage(k) -> void:
	k.environment("dim", Color(0.45, 0.4, 0.5), 0.26)
	k.bounds = Vector2(1.8, 8.6)
	var wall_m: Material = k.wood_wall(Color(0.2, 0.15, 0.2), Color(0.3, 0.24, 0.3), 0.2)
	var o := {"floor": k.wood_floor(Color(0.2, 0.14, 0.12), Color(0.32, 0.24, 0.2), 0.14), "wall": wall_m, "wain": null,
		"trim": k.mat(Color(0.1, 0.08, 0.1), 0.9), "ceiling": k.mat(Color(0.1, 0.09, 0.12), 0.9)}
	var low := -1.44
	var up_o := o.duplicate()
	up_o["open"] = ["n"]
	k.plan([[-0.9, 0.0, 0.9, 3.0]], 0.0, 2.5, up_o)
	var low_o := o.duplicate()
	low_o["open"] = ["s"]
	k.plan([[-0.9, -5.6, 0.9, -3.2]], low, 3.94, low_o)
	var side := {"wall": wall_m, "wain": null, "trim": o["trim"]}
	k.wall_run(Vector2(0.9, -3.2), Vector2(0.9, 0.0), low, 3.94, side)
	k.wall_run(Vector2(-0.9, 0.0), Vector2(-0.9, -3.2), low, 3.94, side)
	k.slab(-0.9, -3.2, 0.9, 0.0, 2.62, o["ceiling"], 0.12, false)
	k.stairs(Vector3(0, low, -3.2), Vector3(0, 0, 0), 1.8, {"mat": k.wood_mid, "rail": "none"})
	for p in [Vector3(0, 2.1, 1.6), Vector3(0, 2.0, -1.6), Vector3(0, 0.9, -4.6)]:
		var pp: Vector3 = p
		k.sphere(0.05, pp, k.glow(Color(1.0, 0.86, 0.58), 4.0))
		var l: OmniLight3D = k.omni(pp + Vector3(0, -0.1, 0), Color(1.0, 0.84, 0.58), 0.7, 4.5)
		k.flickers.append(l)
	k.beam(Vector3(0.75, 1.1, 2.9), Vector3(0.75, 1.1, 0.1), 0.012, k.mat(Color(0.65, 0.55, 0.38), 0.9))
	k.beam(Vector3(0.78, -0.3, -0.3), Vector3(0.78, -1.3, -3.1), 0.012, k.mat(Color(0.65, 0.55, 0.38), 0.9))
	k.sphere(0.2, Vector3(-0.6, 0.2, 2.5), k.mat(Color(0.55, 0.45, 0.3), 0.95), null, Vector3(1, 0.9, 1))
	k.box(Vector3(0.04, 0.8, 0.55), Vector3(-0.87, 1.5, 1.4), k.mat(Color(0.3, 0.1, 0.4), 0.8))
	k.note("Old show poster", "Faded names of acts that never got to play here.", Vector3(-0.55, 0, 1.4), Vector3(0.4, 1.0, 0.8), Vector3(0, 1.5, 0))
	k.box(Vector3(0.5, 0.5, 0.5), Vector3(0.55, low + 0.25, -5.1), k.mat(Color(0.5, 0.36, 0.2), 0.9))
	k.door("lounge", "", Vector3(0, 0, 3.0), PI, {"h": 2.0})
	k.door("storage", "", Vector3(0, low, -5.6), 0.0, {"h": 2.0})
	k.spawn = Vector3(0, 0, 1.8)
	k.look = Vector3(0, -0.5, -5.0)


# =================================================================== Bath Passage (T-shaped, tiled, steamy)
static func _bath_passage(k) -> void:
	k.environment("steam", Color(0.68, 0.66, 0.62), 0.42)
	var tile: Material = k.stone_floor(Color(0.72, 0.78, 0.78), Color(0.84, 0.88, 0.86), 0.32, 0.6)
	k.plan([[-1.1, 0.0, 1.1, 4.0], [-5.5, -2.4, 5.5, 0.0]], 0.0, 2.5, {
		"floor": k.stone_floor(Color(0.4, 0.46, 0.46), Color(0.55, 0.6, 0.58), 0.4, 0.8),
		"wall": tile, "wain": k.mat(Color(0.2, 0.5, 0.52), 0.4), "wain_h": 0.8, "trim": k.mat(Color(0.14, 0.32, 0.34), 0.5),
		"ceiling": k.mat(Color(0.62, 0.6, 0.55), 0.9)})
	k.omni(Vector3(0, 2.15, 1.8), Color(1.0, 0.9, 0.75), 0.9, 6.0, true)
	k.omni(Vector3(-3.6, 2.15, -1.2), Color(1.0, 0.86, 0.68), 0.7, 5.0)
	k.omni(Vector3(3.6, 2.15, -1.2), Color(1.0, 0.86, 0.68), 0.7, 5.0)
	k.steam(Vector3(0, 0.5, -1.2), Vector3(4.2, 0.1, 0.8), 18, 1.4, 0.07, 0.25, 5.0)
	for i in 5:
		k.box(Vector3(0.9, 0.04, 2.0), Vector3(-4.4 + i * 2.2, 0.03, -1.2), k.wood_light, false, null, PI / 2.0)
	for i in 5:
		k.box(Vector3(0.28, 0.75, 0.03), Vector3(-1.5 + i * 0.7, 1.45, -2.36), k.mat([Color(0.96, 0.96, 0.95), Color(0.62, 0.8, 0.95), Color(0.98, 0.72, 0.78)][i % 3], 0.95))
	k.box(Vector3(3.8, 0.04, 0.05), Vector3(0, 1.85, -2.34), k.wood_dark)
	k.note("Towels", "All folded the same way. Someone here really cares about towels.", Vector3(0, 0, -2.1), Vector3(3.6, 1.0, 0.5), Vector3(0, 1.45, 0))
	k.box(Vector3(1.8, 0.03, 0.9), Vector3(0, 2.42, 1.0), k.mat(Color(0.2, 0.3, 0.55), 0.9))
	for i in 3:
		k.box(Vector3(0.58, 0.8, 0.01), Vector3(-0.62 + i * 0.62, 2.0, 0.1), k.mat(Color(0.2, 0.3, 0.55), 0.9))
	k.cctv(Vector3(5.4, 2.1, -2.2), -PI / 2.0 - 0.7)
	k.door("changing", "", Vector3(0, 0, 4.0), PI, {"h": 1.9, "mat": k.wood_light})
	k.door("sauna", "", Vector3(-5.5, 0, -1.2), PI / 2.0, {"h": 1.9, "porthole": true})
	k.door("bath", "", Vector3(5.5, 0, -1.2), -PI / 2.0, {"h": 1.9})
	k.spawn = Vector3(0, 0, 2.8)
	k.look = Vector3(0, 1.3, -2.0)


# =================================================================== Mochi's Room (upstairs)
static func _mochi_room(k) -> void:
	k.environment("indoor", Color(0.6, 0.54, 0.46), 0.34)
	k.plan([[-2.6, -2.2, 2.6, 2.2]], 0.0, 2.6, {
		"floor": k.stone_floor(Color(0.62, 0.62, 0.38), Color(0.72, 0.72, 0.46), 0.9),
		"wall": k.mat(Color(0.86, 0.8, 0.66), 0.95), "wain": k.wood_wall(Color(0.3, 0.18, 0.1), Color(0.44, 0.27, 0.14)), "wain_h": 0.5,
		"trim": k.wood_dark, "ceiling": k.mat(Color(0.42, 0.28, 0.16), 0.85)})
	k.shoji(Vector2(2.0, 1.4), Vector3(0, 1.45, -2.18), 0.0, Color(1.0, 0.9, 0.72), 1.3, Vector2(4, 3))
	k.box(Vector3(1.2, 0.14, 2.1), Vector3(-1.7, 0.07, 0.0), k.white, true)
	k.box(Vector3(1.22, 0.1, 1.3), Vector3(-1.7, 0.17, 0.35), k.mat(Color(0.2, 0.3, 0.6), 0.9))
	k.sphere(0.24, Vector3(-1.7, 0.2, -0.75), k.white, null, Vector3(1.4, 0.45, 0.9))
	k.table(Vector3(1.3, 0, -0.5), Vector3(1.1, 0.32, 0.7), k.wood_light, k.wood_dark)
	k.cyl(0.05, 0.04, 0.08, Vector3(1.15, 0.36, -0.5), k.mat(Color(0.9, 0.88, 0.8), 0.3))
	k.paper_lantern(Vector3(1.9, 0.5, 1.5), Color(1.0, 0.86, 0.64), 0.7, true, true, 1.0)
	k.note("Your futon", "Home, sort of. Nobody sleeps well in a place with a Warden.", Vector3(-1.7, 0, 0.0), Vector3(1.3, 0.5, 2.1), Vector3(0, 0.25, 0))
	k.door("lobby", "Guest Wing", Vector3(0.6, 0, 2.2), PI)
	k.spawn = Vector3(0.6, 0, 1.0)
	k.look = Vector3(0, 1.1, -2.0)
