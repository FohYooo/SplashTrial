extends RefCounted
## Chapter 2 (the Mudlark paddle-steamer) 3D rooms for the walk-around version, plus the Free Time deck hub.
## Same conventions as rooms1.gd: one 3D object per hotspot id from investigation_data2.gd, standing spots
## for the people, doors following the ship map. Ship look: warm wood, grimy teal wainscot, brass fittings,
## portholes glowing with the cave's aqua fungus light.

const Style := preload("res://scripts/ui/style.gd")
const Kit := preload("res://scripts/world3d/kit.gd")

## Walkable connecting spaces (not investigation rooms): name + where the "you are here" pin goes on the 2D map.
const SPACES := {
	"promenade": {"name": "Promenade Deck", "map_at": Vector2(560, 130)},
	"companionway": {"name": "Main Stairs", "map_at": Vector2(560, 345)},
	"back_stairs": {"name": "Back Stairs", "map_at": Vector2(715, 345)},
	"saloon": {"name": "Saloon", "map_at": Vector2(400, 345)},
	"mochi_cabin": {"name": "Mochi's Cabin", "map_at": Vector2(405, 150)},
}
## Free Time: where you can walk, and where you start.
const FREE_SPACES := ["promenade", "companionway", "saloon"]
const FREE_START := "promenade"

const TEAL := Color(0.1, 0.42, 0.42)
const TEAL_DARK := Color(0.06, 0.28, 0.29)
const CREAM := Color(0.9, 0.87, 0.78)
const TAN := Color(0.66, 0.48, 0.3)
const FUNGUS := Color(0.25, 0.95, 0.85)


static func build(rid: String, k, names: Dictionary) -> void:
	k.names = names
	match rid:
		"infirmary":
			_infirmary(k)
		"boiler":
			_boiler(k)
		"laundry":
			_laundry(k)
		"hall":
			_hall(k)
		"tumble_cabin":
			_tumble_cabin(k)
		"purser":
			_purser(k)
		"promenade":
			_promenade(k)
		"companionway":
			_companionway(k)
		"back_stairs":
			_back_stairs(k)
		"saloon":
			_saloon(k)
		"mochi_cabin":
			_mochi_cabin(k)
		_:
			k.environment("indoor")
			k.shell(8.0, 8.0, 3.0)


static func _h(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)


## A cluster of glowing cave mushrooms.
static func _fungus(k, p: Vector3, s: float, cap: Material, stem: Material) -> void:
	for i in 3:
		var o := p + Vector3(0.0, 0.0, (i - 1) * 0.7 * s) + Vector3(0, -0.3 * s * (i % 2), 0)
		k.cyl(0.07 * s, 0.1 * s, 0.6 * s, o + Vector3(0, 0.3 * s, 0), stem, null, false, 6)
		k.sphere(0.35 * s, o + Vector3(0, 0.62 * s, 0), cap, null, Vector3(1, 0.45, 1), 10)


## Ship cabin shell: wood floor, upper wall (cream paint or tan panelling), teal wainscot, brass trim,
## dark beamed ceiling with a pipe or two.
static func _ship_shell(k, w: float, d: float, h: float, upper: String = "tan") -> void:
	var wall_m: Material
	if upper == "cream":
		wall_m = k.mat(CREAM, 0.95)
	elif upper == "teal":
		wall_m = k.wood_wall(TEAL_DARK, TEAL, 0.3)
	else:
		wall_m = k.wood_wall(TAN.darkened(0.15), TAN, 0.26)
	k.shell(w, d, h, {
		"floor": k.wood_floor(Color(0.3, 0.17, 0.09), Color(0.5, 0.31, 0.16), 0.2),
		"wall": wall_m,
		"wain": k.wood_wall(TEAL_DARK, TEAL, 0.18) if upper != "teal" else k.wood_wall(TEAL_DARK.darkened(0.2), TEAL_DARK, 0.18),
		"wain_h": 1.05,
		"trim": k.brass,
		"ceiling": k.mat(Color(0.24, 0.15, 0.09), 0.85), "beams": true})
	k.cyl(0.06, 0.06, w, Vector3(0, h - 0.32, -d / 2.0 + 0.3), k.mat(Color(0.5, 0.42, 0.3), 0.4, 0.7)).rotation.z = PI / 2.0


## A porthole with a bit of cave glow spilling in.
static func _port(k, pos: Vector3, rot_y: float, r: float = 0.2, light: bool = true) -> void:
	k.porthole(pos, rot_y, r, FUNGUS, 1.5)
	if light:
		var b := Basis(Vector3.UP, rot_y)
		k.omni(pos + b * Vector3(0, -0.2, 0.6), FUNGUS, 0.35, 2.6)


# =================================================================== Infirmary (pale morning)
static func _infirmary(k) -> void:
	var W := 6.0
	var D := 8.0
	var H := 2.5
	k.environment("indoor", Color(0.7, 0.72, 0.72), 0.4)
	_ship_shell(k, W, D, H, "cream")
	k.hanging_lamp(Vector3(0, 2.15, -0.8), Color(1.0, 0.92, 0.8), 1.3, H, true)
	k.hanging_lamp(Vector3(0, 2.15, 2.4), Color(1.0, 0.92, 0.8), 0.7, H, false, 5.0)
	# the ship's hull slopes in along the west wall
	var hull: MeshInstance3D = k.box(Vector3(0.1, 1.4, D), Vector3(-W / 2.0 + 0.22, 0.62, 0), k.wood_wall(TEAL_DARK, TEAL, 0.18))
	hull.rotation.z = 0.3
	_port(k, Vector3(-W / 2.0, 1.75, -1.2), PI / 2.0)
	# medicine cabinet, eye chart and a green-cross sign on the back wall
	var cab := Vector3(0.1, 1.55, -D / 2.0 + 0.12)
	k.box(Vector3(1.0, 0.8, 0.22), cab, k.mat(Color(0.95, 0.95, 0.93), 0.5))
	k.box(Vector3(0.9, 0.7, 0.01), cab + Vector3(0, 0, 0.115), k.mat(Color(0.8, 0.92, 0.95), 0.05, 0.2))
	for i in 8:
		k.cyl(0.03, 0.03, 0.12, cab + Vector3(-0.35 + i * 0.1, 0.12 - 0.3 * (i % 2), 0.02), k.mat([Color(0.85, 0.3, 0.3), Color(0.3, 0.6, 0.85), Color(0.95, 0.8, 0.3), Color(0.4, 0.75, 0.45)][i % 4], 0.3))
	k.box(Vector3(0.3, 0.3, 0.02), Vector3(1.25, 1.95, -D / 2.0 + 0.02), k.white)
	k.box(Vector3(0.18, 0.06, 0.01), Vector3(1.25, 1.95, -D / 2.0 + 0.035), k.glow(Color(0.2, 0.8, 0.3), 0.8))
	k.box(Vector3(0.06, 0.18, 0.01), Vector3(1.25, 1.95, -D / 2.0 + 0.035), k.glow(Color(0.2, 0.8, 0.3), 0.8))
	k.box(Vector3(0.36, 0.5, 0.02), Vector3(2.2, 1.7, -D / 2.0 + 0.02), k.white)
	for i in 5:
		k.box(Vector3(0.24 - i * 0.04, 0.03, 0.01), Vector3(2.2, 1.86 - i * 0.07, -D / 2.0 + 0.035), k.black)
	# desk (back left)
	k.box(Vector3(1.4, 0.8, 0.6), Vector3(-1.9, 0.4, -D / 2.0 + 0.4), k.wood_mid, true)
	k.box(Vector3(1.5, 0.05, 0.66), Vector3(-1.9, 0.825, -D / 2.0 + 0.4), k.wood_light)
	for i in 2:
		k.box(Vector3(0.6, 0.25, 0.02), Vector3(-1.9 + (i - 0.5) * 0.66, 0.6, -D / 2.0 + 0.71), k.wood_light)
	# hotspot: rounds log (clipboard on the wall above the desk)
	var lg: Node3D = k.hotspot("log", Vector3(-1.9, 1.45, -D / 2.0 + 0.03), Vector3(0.6, 0.75, 0.35), Vector3(0, 0.05, 0.12))
	k.box(Vector3(0.32, 0.44, 0.02), Vector3(0, 0, 0.01), k.wood_light, false, lg)
	k.box(Vector3(0.28, 0.38, 0.01), Vector3(0, -0.02, 0.025), k.paper, false, lg)
	k.box(Vector3(0.12, 0.05, 0.03), Vector3(0, 0.2, 0.03), k.steel, false, lg)
	for i in 6:
		k.box(Vector3(0.2, 0.012, 0.005), Vector3(-0.02, 0.12 - i * 0.05, 0.032), k.mat(Color(0.3, 0.35, 0.5), 0.9), false, lg)
	# hotspot: cot (back right)
	var ct: Node3D = k.hotspot("cot", Vector3(1.4, 0, -D / 2.0 + 0.6), Vector3(2.3, 0.9, 1.1))
	var frame: Material = k.mat(Color(0.92, 0.92, 0.9), 0.35, 0.5)
	k.box(Vector3(2.0, 0.08, 0.85), Vector3(0, 0.45, 0), frame, true, ct)
	for sx in [-0.97, 0.97]:
		for sz in [-0.39, 0.39]:
			k.box(Vector3(0.05, 0.45, 0.05), Vector3(sx, 0.225, sz), frame, false, ct)
		k.box(Vector3(0.05, 0.8, 0.85), Vector3(sx, 0.55, 0), frame, false, ct)
	k.box(Vector3(1.9, 0.14, 0.8), Vector3(0, 0.56, 0), k.white, false, ct)
	k.box(Vector3(1.2, 0.05, 0.82), Vector3(0.3, 0.64, 0), k.mat(Color(0.7, 0.86, 0.9), 0.9), false, ct)
	k.sphere(0.2, Vector3(-0.72, 0.68, 0), k.white, ct, Vector3(1.0, 0.45, 1.5))
	# hotspot: kettle on a little burner (side table, left)
	var kt: Node3D = k.hotspot("kettle", Vector3(-2.2, 0, -1.6), Vector3(0.8, 1.2, 0.8))
	k.table(Vector3.ZERO, Vector3(0.55, 0.72, 0.55), k.wood_light, k.wood_dark, 0.0, kt)
	k.cyl(0.12, 0.13, 0.08, Vector3(0, 0.76, 0), k.mat(Color(0.2, 0.2, 0.22), 0.4, 0.7), kt)
	var soot: Material = k.mat(Color(0.16, 0.15, 0.15), 0.6, 0.5)
	k.sphere(0.15, Vector3(0, 0.92, 0), soot, kt, Vector3(1.0, 0.8, 1.0))
	var sp: MeshInstance3D = k.cyl(0.015, 0.03, 0.16, Vector3(0.15, 0.95, 0), soot, kt)
	sp.rotation.z = -0.9
	k.torus(0.07, 0.09, Vector3(0, 1.04, 0), soot, kt, Vector3(0, 0, PI / 2.0))
	k.steam(Vector3(-2.2, 1.1, -1.6), Vector3(0.05, 0.02, 0.05), 6, 0.35, 0.1, 0.3, 2.0)
	# hotspot: the door (east wall, swinging, no doorstop) + the dropped breakfast tray
	var dr: Node3D = k.hotspot("door", Vector3(W / 2.0 - 0.04, 0, -2.0), Vector3(1.3, 2.3, 0.8), Vector3.ZERO, -PI / 2.0)
	k.box(Vector3(1.15, 2.2, 0.06), Vector3(0, 1.1, 0.02), k.wood_dark, false, dr)
	k.quad(Vector2(0.95, 2.0), Vector3(0, 1.0, 0.04), k.mat(Color(0.08, 0.06, 0.05), 0.9), dr)
	var hinge := Node3D.new()
	hinge.position = Vector3(-0.48, 0, 0.06)
	hinge.rotation.y = -0.9
	dr.add_child(hinge)
	k.box(Vector3(0.95, 2.0, 0.05), Vector3(0.475, 1.0, 0), k.mat(Color(0.55, 0.35, 0.2), 0.6), false, hinge)
	k.sphere(0.03, Vector3(0.85, 1.0, 0.04), k.brass, hinge)
	k.box(Vector3(0.45, 0.02, 0.3), Vector3(0.3, 0.01, 0.6), k.mat(Color(0.75, 0.6, 0.4), 0.6), false, dr, 0.4)
	k.cyl(0.04, 0.03, 0.06, Vector3(0.0, 0.03, 0.85), k.white, dr).rotation.z = PI / 2.0
	k.cyl(0.09, 0.08, 0.012, Vector3(0.5, 0.01, 0.9), k.white, dr)
	# hotspot: the body (cartoon, non-graphic: face-down, light-blue scrubs, nurse cap fallen beside her)
	var bd: Node3D = k.hotspot("body", Vector3(0.1, 0, -0.9), Vector3(1.9, 0.6, 1.2))
	var scrubs: Material = k.mat(Color(0.62, 0.82, 0.92), 0.85)
	var fur: Material = k.mat(Color(0.56, 0.38, 0.22), 0.85)
	var torso: MeshInstance3D = k.sphere(0.5, Vector3(0, 0.17, 0), scrubs, bd, Vector3(0.62, 1.15, 0.32))
	torso.rotation = Vector3(PI / 2.0, PI / 2.0 - 0.2, 0)
	k.sphere(0.22, Vector3(-0.62, 0.18, 0.12), fur, bd, Vector3(1, 0.85, 1))
	for sz in [-0.3, 0.3]:
		k.sphere(0.09, Vector3(-0.25, 0.08, sz * 1.1), fur, bd, Vector3(0.7, 0.5, 1.6))
		k.sphere(0.1, Vector3(0.62, 0.09, sz * 0.6), scrubs, bd, Vector3(1.8, 0.7, 0.8))
	var cap := Node3D.new()
	cap.position = Vector3(-0.95, 0.03, 0.55)
	cap.rotation = Vector3(0.0, 0.7, 0.25)
	bd.add_child(cap)
	k.box(Vector3(0.24, 0.08, 0.14), Vector3(0, 0.04, 0), k.white, false, cap)
	k.box(Vector3(0.07, 0.025, 0.012), Vector3(0, 0.05, 0.075), k.mat(Color(0.2, 0.7, 0.3), 0.6), false, cap)
	k.box(Vector3(0.025, 0.07, 0.012), Vector3(0, 0.05, 0.075), k.mat(Color(0.2, 0.7, 0.3), 0.6), false, cap)
	k.cctv(Vector3(W / 2.0 - 0.15, 2.25, D / 2.0 - 0.4), -PI / 2.0 - 0.7)
	k.person("grub", Vector3(-1.9, 0, 0.3))
	k.person("nibs", Vector3(2.1, 0, 0.2))
	k.door("companionway", "Lower Passage", Vector3(0, 0, D / 2.0), PI, {"h": 1.9})
	k.spawn = Vector3(0, 0, 2.8)
	k.look = Vector3(0, 0.9, -3.0)


# =================================================================== Boiler Room
static func _boiler(k) -> void:
	var W := 10.0
	var D := 10.0
	var H := 6.0
	k.environment("dim", Color(0.5, 0.4, 0.36), 0.32)
	var plates: Material = k.smat(Kit.SH_METAL, {"base": Color(0.24, 0.24, 0.26)})
	k.shell(W, D, H, {"floor": k.smat(Kit.SH_METAL, {"base": Color(0.3, 0.29, 0.3), "plate": Vector2(1.0, 1.0)}),
		"wall": plates, "wain": null, "trim": k.mat(Color(0.14, 0.14, 0.15), 0.5, 0.6),
		"ceiling": k.mat(Color(0.12, 0.12, 0.13), 0.7, 0.4)})
	var pipe_m: Material = k.mat(Color(0.38, 0.36, 0.34), 0.45, 0.7)
	for i in 3:
		k.cyl(0.08 - i * 0.015, 0.08 - i * 0.015, W, Vector3(0, 2.4 + i * 0.22, -D / 2.0 + 0.2 + i * 0.1), pipe_m).rotation.z = PI / 2.0
	for x in [-3.6, -0.4, 3.9]:
		k.cyl(0.07, 0.07, H, Vector3(x, H / 2.0, -D / 2.0 + 0.2), pipe_m)
	k.cyl(0.006, 0.006, 2.4, Vector3(-1.0, H - 1.2, 0.8), k.black)
	k.sphere(0.09, Vector3(-1.0, H - 2.45, 0.8), k.glow(Color(1.0, 0.85, 0.6), 4.0))
	k.omni(Vector3(-1.0, H - 2.65, 0.8), Color(1.0, 0.82, 0.6), 1.3, 10.0, true)
	# a metal stair along the south wall up to a catwalk along the west wall
	var grate: Material = k.mat(Color(0.2, 0.2, 0.22), 0.45, 0.7)
	k.stairs(Vector3(0.6, 0, 4.4), Vector3(-3.8, 2.9, 4.4), 1.1, {"mat": grate, "solid": false, "rail": "right", "rail_mat": k.steel})
	k.slab(-W / 2.0, -D / 2.0, -3.8, D / 2.0, 2.9, grate, 0.08)
	k.rail(Vector3(-3.8, 2.9, -D / 2.0), Vector3(-3.8, 2.9, 3.85), k.steel)
	k.omni(Vector3(-4.4, 4.4, -1.0), Color(1.0, 0.75, 0.5), 0.8, 7.0)
	k.note("Catwalk", "From up here the furnace looks like it's breathing. Let's not stay long.", Vector3(-4.4, 2.9, -2.0), Vector3(1.0, 1.2, 1.6), Vector3(0, 0.6, 0))
	# hotspot: furnace (back right)
	var fn: Node3D = k.hotspot("furnace", Vector3(1.6, 0, -D / 2.0 + 0.85), Vector3(2.4, 2.4, 1.6))
	var iron: Material = k.mat(Color(0.1, 0.1, 0.11), 0.5, 0.6)
	k.box(Vector3(2.0, 1.9, 1.3), Vector3(0, 0.95, 0), iron, true, fn)
	k.box(Vector3(2.1, 0.12, 1.4), Vector3(0, 1.95, 0), k.mat(Color(0.16, 0.16, 0.17), 0.5, 0.6), false, fn)
	k.cyl(0.25, 0.25, H, Vector3(0, 2.0 + H / 2.0 - 0.9, -0.2), iron, fn)
	k.box(Vector3(0.9, 0.7, 0.06), Vector3(0, 0.85, 0.66), k.mat(Color(0.2, 0.2, 0.22), 0.4, 0.7), false, fn)
	k.box(Vector3(0.7, 0.45, 0.02), Vector3(0, 0.82, 0.7), k.glow(Color(1.0, 0.42, 0.1), 5.0), false, fn)
	for i in 5:
		k.box(Vector3(0.025, 0.45, 0.02), Vector3(-0.28 + i * 0.14, 0.82, 0.72), iron, false, fn)
	k.cyl(0.18, 0.18, 0.03, Vector3(0, 1.55, 0.66), k.brass, fn).rotation.x = PI / 2.0
	k.cyl(0.12, 0.12, 0.032, Vector3(0, 1.55, 0.67), k.mat(Color(0.25, 0.5, 0.3), 0.5), fn).rotation.x = PI / 2.0
	var fire: OmniLight3D = k.omni(Vector3(1.6, 0.9, -D / 2.0 + 2.0), Color(1.0, 0.45, 0.15), 2.2, 6.5, true)
	k.flickers.append(fire)
	# hotspot: pressure gauges on the pipes (back left)
	var gg: Node3D = k.hotspot("gauges", Vector3(-1.8, 1.75, -D / 2.0 + 0.3), Vector3(1.3, 0.8, 0.6), Vector3(0, 0, 0.1))
	k.cyl(0.05, 0.05, 1.2, Vector3(0, -0.25, 0), pipe_m, gg).rotation.z = PI / 2.0
	for i in 2:
		var gx := -0.3 + i * 0.6
		var r := 0.17 - i * 0.04
		k.cyl(0.03, 0.03, 0.2, Vector3(gx, -0.12, 0), pipe_m, gg)
		var face: MeshInstance3D = k.cyl(r, r, 0.06, Vector3(gx, 0.08, 0.04), k.brass, gg)
		face.rotation.x = PI / 2.0
		var dial: MeshInstance3D = k.cyl(r * 0.85, r * 0.85, 0.01, Vector3(gx, 0.08, 0.075), k.mat(Color(0.95, 0.93, 0.86), 0.5), gg)
		dial.rotation.x = PI / 2.0
		var needle: MeshInstance3D = k.box(Vector3(0.012, r * 0.75, 0.005), Vector3(gx, 0.08, 0.085), k.mat(Color(0.85, 0.1, 0.1), 0.5), false, gg)
		needle.rotation.z = -0.9 + i * 1.6
		needle.position += Vector3(sin(0.9 - i * 1.6), cos(0.9 - i * 1.6), 0) * r * 0.3
	k.sphere(0.04, Vector3(0.6, -0.25, 0.05), k.glow(Color(1.0, 0.2, 0.15), 2.0), gg)
	# hotspot: coal pile (left of centre) with a shovel
	var cl: Node3D = k.hotspot("coal", Vector3(-1.5, 0, -2.6), Vector3(2.0, 1.1, 1.6))
	var coal: Material = k.mat(Color(0.13, 0.13, 0.15), 0.3, 0.25)
	k.sphere(0.8, Vector3(0, 0.0, 0), coal, cl, Vector3(1.2, 0.85, 0.9), 14)
	for i in 26:
		var a := i * 2.399
		var rr := 0.2 + 0.75 * _h(i)
		var p := Vector3(cos(a) * rr * 1.1, 0.0, sin(a) * rr * 0.8)
		p.y = 0.62 * (1.0 - clampf(rr / 0.95, 0.0, 1.0)) + 0.06
		k.sphere(0.07 + 0.05 * _h(i + 9), p, coal, cl, Vector3(1, 0.8, 1), 6)
	var shovel := Node3D.new()
	shovel.position = Vector3(0.9, 0, -0.2)
	shovel.rotation = Vector3(0, 0.3, -0.35)
	cl.add_child(shovel)
	k.cyl(0.02, 0.02, 1.2, Vector3(0, 0.75, 0), k.wood_light, shovel)
	k.box(Vector3(0.24, 0.3, 0.02), Vector3(0, 0.1, 0), k.steel, false, shovel)
	k.blocker(Vector3(1.8, 0.8, 1.3), Vector3(-1.5, 0.4, -2.6))
	# hotspot: huge boot prints in the coal dust (floor, front)
	var bp: Node3D = k.hotspot("prints", Vector3(0.6, 0, -0.6), Vector3(2.8, 0.3, 1.6), Vector3(0, 0.1, 0))
	var dust: Material = k.mat(Color(0.03, 0.03, 0.03), 0.95)
	var smear: StandardMaterial3D = k.tex_mat(Kit.puff_texture(), true, true)
	smear.albedo_color = Color(0.05, 0.05, 0.05, 0.55)
	k.decal_quad(Vector2(2.8, 1.4), Vector3(0, 0.006, 0), smear, bp)
	for i in 5:
		var side := 1.0 if i % 2 == 0 else -1.0
		var fp := Vector3(-1.1 + i * 0.55, 0.012, side * 0.18)
		var sole: MeshInstance3D = k.box(Vector3(0.38, 0.008, 0.17), fp, dust, false, bp, -0.1)
		sole.position.x += 0.0
		k.box(Vector3(0.12, 0.008, 0.15), fp + Vector3(-0.28, 0, 0), dust, false, bp, -0.1)
	k.cctv(Vector3(-W / 2.0 + 0.15, 2.8, D / 2.0 - 0.4), PI / 2.0 + 0.7)
	k.person("bruno", Vector3(-2.7, 0, 1.2))
	k.person("reginald", Vector3(3.0, 0, 1.3))
	k.door("companionway", "Lower Passage", Vector3(3.0, 0, D / 2.0), PI, {"mat": k.steel, "frame": k.mat(Color(0.18, 0.18, 0.2), 0.5, 0.6), "porthole": true})
	k.spawn = Vector3(3.0, 0, 3.8)
	k.look = Vector3(-1.0, 1.0, -4.5)


# =================================================================== Laundry
static func _laundry(k) -> void:
	var W := 4.5
	var D := 10.0
	var H := 2.6
	k.environment("indoor", Color(0.55, 0.65, 0.62), 0.38)
	_ship_shell(k, W, D, H, "teal")
	k.hanging_lamp(Vector3(-0.3, 2.25, -2.4), Color(1.0, 0.9, 0.72), 1.1, H, true)
	k.hanging_lamp(Vector3(-0.3, 2.25, 2.2), Color(1.0, 0.9, 0.72), 0.8, H, false, 5.0)
	_port(k, Vector3(-W / 2.0, 1.8, -1.6), PI / 2.0)
	# shelves with folded towels (back right)
	for i in 2:
		k.box(Vector3(1.2, 0.04, 0.3), Vector3(1.2, 1.75 + i * 0.35, -D / 2.0 + 0.16), k.wood_light)
		for j in 3:
			k.box(Vector3(0.28, 0.12, 0.24), Vector3(0.8 + j * 0.38, 1.83 + i * 0.35, -D / 2.0 + 0.16), k.mat([Color(0.95, 0.95, 0.95), Color(0.7, 0.85, 0.95), Color(0.95, 0.85, 0.7)][(i + j) % 3], 0.95))
	# hotspot: drying line with sheets (and a lilac shawl)
	var ln: Node3D = k.hotspot("line", Vector3(1.35, 1.4, -0.8), Vector3(4.6, 1.4, 0.6), Vector3(0, 0.25, 0), -PI / 2.0)
	k.cyl(0.006, 0.006, 4.4, Vector3(0, 0.75, 0), k.mat(Color(0.85, 0.82, 0.75), 0.9), ln).rotation.z = PI / 2.0
	for sx in [-2.25, 2.25]:
		k.box(Vector3(0.06, 0.06, 0.9), Vector3(sx, 0.75, -0.45), k.brass, false, ln)
	var cloth := [[-1.7, 0.75, Color(0.95, 0.95, 0.95)], [-1.0, 0.55, Color(0.62, 0.8, 0.95)], [-0.1, 0.8, Color(0.97, 0.97, 0.94)],
		[0.75, 0.7, Color(0.76, 0.62, 0.9)], [1.6, 0.85, Color(0.95, 0.93, 0.88)]]
	for c in cloth:
		var cw: float = c[1]
		var ch := 0.95 if cw > 0.7 else 0.7
		k.box(Vector3(cw, ch, 0.015), Vector3(float(c[0]), 0.75 - ch / 2.0, 0), k.mat(c[2], 0.95), false, ln)
		k.box(Vector3(0.03, 0.06, 0.03), Vector3(float(c[0]) - cw * 0.3, 0.75, 0), k.wood_light, false, ln)
		k.box(Vector3(0.03, 0.06, 0.03), Vector3(float(c[0]) + cw * 0.3, 0.75, 0), k.wood_light, false, ln)
	for i in 5:
		k.box(Vector3(0.06, 0.05, 0.016), Vector3(0.48 + i * 0.13, 0.2 + 0.05 * (i % 2), 0.005), k.mat(Color(0.88, 0.8, 0.98), 0.9), false, ln)
	# hotspot: boot rack (front left) with enormous boots
	var rk: Node3D = k.hotspot("rack", Vector3(-1.4, 0, 1.4), Vector3(1.5, 1.0, 0.8), Vector3.ZERO, PI / 2.0)
	for yy in [0.12, 0.5]:
		k.box(Vector3(1.3, 0.04, 0.45), Vector3(0, yy, 0), k.wood_light, false, rk)
	for sx in [-0.64, 0.64]:
		k.box(Vector3(0.04, 0.6, 0.45), Vector3(sx, 0.3, 0), k.wood_dark, false, rk)
	var boot: Material = k.mat(Color(0.36, 0.2, 0.1), 0.6)
	for sx in [-0.3, 0.25]:
		k.box(Vector3(0.24, 0.42, 0.3), Vector3(sx, 0.75, -0.05), boot, false, rk)
		k.sphere(0.15, Vector3(sx, 0.6, 0.12), boot, rk, Vector3(1.0, 0.6, 1.3))
		k.box(Vector3(0.26, 0.04, 0.46), Vector3(sx, 0.54, 0.03), k.mat(Color(0.15, 0.1, 0.06), 0.8), false, rk)
	for sx in [-0.4, -0.15, 0.2, 0.42]:
		k.box(Vector3(0.1, 0.08, 0.22), Vector3(sx, 0.18, 0), k.mat(Color(0.25, 0.3, 0.45).lerp(Color(0.6, 0.4, 0.3), _h(int(sx * 10.0) + 3)), 0.7), false, rk)
	k.blocker(Vector3(0.5, 1.0, 1.3), Vector3(-1.4, 0.5, 1.4))
	# hotspot: sewing basket (floor, right of centre)
	var bk: Node3D = k.hotspot("basket", Vector3(1.4, 0, 2.9), Vector3(0.8, 0.6, 0.7))
	k.cyl(0.26, 0.22, 0.22, Vector3(0, 0.11, 0), k.mat(Color(0.7, 0.52, 0.28), 0.95), bk, false, 16)
	k.torus(0.24, 0.29, Vector3(0, 0.22, 0), k.mat(Color(0.55, 0.38, 0.18), 0.9), bk)
	for i in 3:
		k.sphere(0.07, Vector3(-0.1 + i * 0.1, 0.25, 0.04 * i), k.mat([Color(0.9, 0.3, 0.35), Color(0.35, 0.6, 0.9), Color(0.95, 0.8, 0.3)][i], 0.9), bk)
	var sc: MeshInstance3D = k.box(Vector3(0.2, 0.01, 0.025), Vector3(0.12, 0.33, -0.05), k.steel, false, bk, 0.6)
	sc.rotation.z = 0.3
	# hotspot: wash tubs (right, steaming)
	var tb: Node3D = k.hotspot("tubs", Vector3(-0.8, 0, -D / 2.0 + 0.7), Vector3(1.6, 1.0, 1.0))
	for i in 2:
		var tx := -0.38 + i * 0.75
		k.cyl(0.33, 0.28, 0.55, Vector3(tx, 0.275, 0), k.wood_light, tb, true, 18)
		for yy in [0.1, 0.42]:
			k.cyl(0.33 - (0.42 - yy) * 0.1, 0.33 - (0.42 - yy) * 0.1, 0.03, Vector3(tx, yy, 0), k.steel, tb, false, 18)
		for j in 6:
			k.sphere(0.07 + 0.03 * _h(j + i * 6), Vector3(tx + cos(j * 1.1) * 0.16, 0.56, sin(j * 1.1) * 0.14), k.mat(Color(0.97, 0.98, 1.0), 0.6), tb, Vector3(1, 0.7, 1), 8)
	k.box(Vector3(0.35, 0.55, 0.04), Vector3(0.45, 0.6, -0.15), k.wood_light, false, tb, -0.3)
	k.steam(Vector3(-0.8, 0.7, -D / 2.0 + 0.7), Vector3(0.5, 0.05, 0.25), 10, 0.6, 0.12, 0.35, 3.0)
	k.cctv(Vector3(W / 2.0 - 0.15, 2.3, D / 2.0 - 0.4), -PI / 2.0 - 0.7)
	k.person("bramble", Vector3(-1.4, 0, -1.2))
	k.person("duchess", Vector3(0.1, 0, 0.9))
	k.door("companionway", "Lower Passage", Vector3(0, 0, D / 2.0), PI, {"h": 2.0})
	k.spawn = Vector3(0, 0, 3.8)
	k.look = Vector3(0, 1.1, -5.0)


# =================================================================== Cabin Corridor
static func _hall(k) -> void:
	var W := 18.0
	var D := 2.6
	var H := 3.0
	k.environment("indoor", Color(0.62, 0.52, 0.42), 0.32)
	_ship_shell(k, W, D, H, "tan")
	k.rug(Vector3(0, 0, 0.0), Vector2(W - 0.6, 1.3), Color(0.55, 0.1, 0.12), Color(0.8, 0.6, 0.25))
	for i in 15:
		var d: MeshInstance3D = k.box(Vector3(0.1, 0.004, 0.1), Vector3(-8.0 + i * 1.15, 0.02, 0.0), k.mat(Color(0.85, 0.65, 0.28), 0.6))
		d.rotation.y = PI / 4.0
	var ndoor := [["door1", -2.1, "1"], ["door2", 0.0, "2"], ["door3", 2.1, "3"]]
	for nd in ndoor:
		var dx: float = nd[1]
		var g: Node3D = k.hotspot(str(nd[0]), Vector3(dx, 0, -D / 2.0 + 0.04), Vector3(1.4, 2.5, 0.7))
		k.box(Vector3(1.2, 2.3, 0.07), Vector3(0, 1.15, 0.02), k.wood_dark, false, g)
		k.box(Vector3(1.0, 2.15, 0.05), Vector3(0, 1.075, 0.07), k.mat(Color(0.42, 0.24, 0.13), 0.6), false, g)
		for yy in [0.65, 1.55]:
			k.box(Vector3(0.75, 0.62, 0.02), Vector3(0, yy, 0.1), k.mat(Color(0.36, 0.2, 0.1), 0.6), false, g)
		if str(nd[2]) == "2":
			k.cyl(0.6, 0.6, 0.07, Vector3(0, 2.15, 0.02), k.wood_dark, g).rotation.x = PI / 2.0
		k.box(Vector3(0.84, 0.05, 0.03), Vector3(0, 0.08, 0.1), k.brass, false, g)
		k.cyl(0.11, 0.11, 0.02, Vector3(0, 1.98, 0.1), k.brass, g).rotation.x = PI / 2.0
		k.label(str(nd[2]), Vector3(0, 1.98, 0.115), 0.0, 48, Color(0.15, 0.08, 0.03), g, 0.003, 0)
		k.sphere(0.04, Vector3(0.38, 1.05, 0.12), k.brass, g)
		if str(nd[2]) == "3":
			var note: MeshInstance3D = k.box(Vector3(0.18, 0.22, 0.005), Vector3(0.2, 1.55, 0.115), k.paper, false, g)
			note.rotation.z = 0.12
			k.sphere(0.012, Vector3(0.2, 1.65, 0.12), k.mat(Color(0.85, 0.1, 0.1), 0.5), g)
	for x in [-7.5, -3.3, -1.05, 1.05, 3.3, 7.5]:
		k.wall_lamp(Vector3(x, 1.9, -D / 2.0), 0.0, Color(1.0, 0.8, 0.55), 0.55, 4.0)
	for x in [-5.5, 0.0, 5.5]:
		k.wall_lamp(Vector3(x, 1.9, D / 2.0), PI, Color(1.0, 0.8, 0.55), 0.4, 3.5)
	# hotspot: speaking tube (brass mouth high on the wall between doors 1 and 2)
	var st: Node3D = k.hotspot("tube", Vector3(-1.05, 2.45, -D / 2.0 + 0.04), Vector3(0.6, 0.6, 0.6), Vector3(0, 0, 0.18))
	k.cyl(0.035, 0.035, 0.6, Vector3(0, 0.3, 0.06), k.brass, st)
	var horn: MeshInstance3D = k.cyl(0.13, 0.04, 0.24, Vector3(0, 0.0, 0.18), k.brass, st)
	horn.rotation.x = PI / 2.0
	k.cyl(0.11, 0.11, 0.01, Vector3(0, 0.0, 0.3), k.mat(Color(0.08, 0.06, 0.04), 0.9), st).rotation.x = PI / 2.0
	k.torus(0.03, 0.05, Vector3(0, 0.0, 0.07), k.brass, st, Vector3(PI / 2.0, 0, 0))
	# noticeboard (left) and fire bucket (right)
	k.box(Vector3(1.0, 0.8, 0.05), Vector3(-4.2, 1.65, -D / 2.0 + 0.03), k.wood_dark)
	k.box(Vector3(0.9, 0.7, 0.02), Vector3(-4.2, 1.65, -D / 2.0 + 0.06), k.mat(Color(0.1, 0.25, 0.2), 0.9))
	for i in 6:
		k.box(Vector3(0.55 - (i % 3) * 0.12, 0.025, 0.005), Vector3(-4.25, 1.88 - i * 0.08, -D / 2.0 + 0.075), k.mat(Color(0.9, 0.9, 0.85), 0.9))
	k.bucket(Vector3(5.2, 1.25, -D / 2.0 + 0.2), 0.9, null, k.mat(Color(0.85, 0.12, 0.1), 0.5))
	k.box(Vector3(0.05, 0.25, 0.04), Vector3(5.2, 1.6, -D / 2.0 + 0.04), k.brass)
	k.cctv(Vector3(W / 2.0 - 0.15, 2.6, D / 2.0 - 0.4), -PI / 2.0 - 0.6)
	k.person("lulu", Vector3(-4.6, 0, -0.65))
	k.person("pepper", Vector3(4.2, 0, 0.6))
	k.door("purser", "", Vector3(-W / 2.0, 0, 0.0), PI / 2.0)
	k.door("companionway", "Main Stairs", Vector3(W / 2.0, 0, 0.0), -PI / 2.0)
	k.door("back_stairs", "", Vector3(6.6, 0, D / 2.0), PI)
	k.link_door("door1", "mochi_cabin")
	k.link_door("door2", "tumble_cabin")
	k.spawn = Vector3(7.7, 0, 0.0)
	k.look = Vector3(-9.0, 1.3, 0.0)


# =================================================================== Tumble's Cabin (morning)
static func _tumble_cabin(k) -> void:
	var W := 4.5
	var D := 4.0
	var H := 2.3
	k.environment("indoor", Color(0.66, 0.58, 0.48), 0.36)
	_ship_shell(k, W, D, H, "tan")
	k.hanging_lamp(Vector3(0.3, 2.0, 0.3), Color(1.0, 0.86, 0.66), 0.9, H, true, 5.0)
	# hotspot: bunk & rug
	var bn: Node3D = k.hotspot("bunk", Vector3(0, 0, -D / 2.0 + 0.6), Vector3(2.6, 1.1, 2.4), Vector3(0, 0.55, 0.5))
	k.box(Vector3(2.2, 0.5, 0.95), Vector3(0, 0.25, 0), k.wood_mid, true, bn)
	for sx in [-0.52, 0.52]:
		k.box(Vector3(0.9, 0.32, 0.02), Vector3(sx, 0.25, 0.48), k.wood_light, false, bn)
		k.sphere(0.025, Vector3(sx, 0.25, 0.5), k.brass, bn)
	for sx in [-1.1, 1.1]:
		k.box(Vector3(0.08, 0.85, 0.95), Vector3(sx, 0.43, 0), k.wood_dark, false, bn)
	k.box(Vector3(2.1, 0.15, 0.9), Vector3(0, 0.58, 0), k.white, false, bn)
	k.box(Vector3(1.5, 0.06, 0.92), Vector3(0.3, 0.68, 0), k.stripes(Color(0.75, 0.15, 0.15), Color(0.95, 0.88, 0.8), 14.0), false, bn)
	k.sphere(0.22, Vector3(-0.78, 0.72, 0), k.white, bn, Vector3(1.0, 0.4, 1.6))
	k.rug(Vector3(0, 0, 1.3), Vector2(1.7, 1.0), Color(0.18, 0.4, 0.6), Color(0.9, 0.85, 0.7))
	# hotspot: porthole above the bunk (cave glow)
	var ph: Node3D = k.hotspot("porthole", Vector3(0, 1.75, -D / 2.0 + 0.02), Vector3(0.8, 0.8, 0.4), Vector3(0, 0, 0.12))
	k.porthole(Vector3.ZERO, 0.0, 0.26, FUNGUS, 1.6).reparent(ph, false)
	k.spot(Vector3(0, 1.75, -D / 2.0 + 0.2), Vector3(0, 0.6, -D / 2.0 + 1.2), FUNGUS, 1.0, 3.5, 25.0, false)
	# hotspot: nightstand with a clean teacup
	var ns: Node3D = k.hotspot("nightstand", Vector3(1.65, 0, -D / 2.0 + 0.35), Vector3(0.8, 1.0, 0.7))
	k.box(Vector3(0.5, 0.6, 0.45), Vector3(0, 0.3, 0), k.wood_mid, true, ns)
	k.box(Vector3(0.42, 0.18, 0.02), Vector3(0, 0.42, 0.23), k.wood_light, false, ns)
	k.sphere(0.02, Vector3(0, 0.42, 0.25), k.brass, ns)
	k.cyl(0.08, 0.07, 0.01, Vector3(0, 0.605, 0), k.white, ns)
	k.cyl(0.045, 0.035, 0.07, Vector3(0, 0.645, 0), k.white, ns)
	k.torus(0.018, 0.026, Vector3(0.055, 0.65, 0), k.white, ns, Vector3(PI / 2.0, 0, 0))
	# hotspot: droopy nightcap on a hook (back wall, left)
	var nc: Node3D = k.hotspot("nightcap", Vector3(-1.7, 1.8, -D / 2.0 + 0.03), Vector3(0.6, 0.8, 0.45), Vector3(0, -0.1, 0.15))
	k.cyl(0.012, 0.012, 0.1, Vector3(0, 0.12, 0.05), k.brass, nc).rotation.x = PI / 2.0
	var blue: Material = k.mat(Color(0.2, 0.3, 0.7), 0.9)
	k.cyl(0.05, 0.15, 0.3, Vector3(0, 0.0, 0.1), blue, nc)
	var tip: MeshInstance3D = k.cyl(0.01, 0.05, 0.3, Vector3(0.1, -0.2, 0.1), blue, nc)
	tip.rotation.z = 2.4
	k.sphere(0.05, Vector3(0.22, -0.32, 0.1), k.white, nc)
	k.torus(0.14, 0.17, Vector3(0, -0.15, 0.1), k.white, nc)
	for i in 4:
		k.sphere(0.012, Vector3(-0.06 + i * 0.04, -0.02 + 0.06 * (i % 2), 0.16), k.glow(Color(1.0, 0.95, 0.5), 2.0), nc)
	k.sphere(0.3, Vector3(-W / 2.0 + 0.04, 1.5, -0.2), k.mat(Color(0.75, 0.8, 0.85), 0.05, 1.0), null, Vector3(0.05, 1.2, 0.8))
	k.person("tumble", Vector3(-1.4, 0, 0.9))
	k.door("hall", "Cabin Corridor", Vector3(W / 2.0, 0, 1.0), -PI / 2.0, {"h": 1.75})
	k.spawn = Vector3(1.0, 0, 1.0)
	k.look = Vector3(-0.3, 0.9, -2.0)


# =================================================================== Purser's Office
static func _purser(k) -> void:
	var W := 7.0
	var D := 5.0
	var H := 2.7
	var UP := 0.18
	k.environment("indoor", Color(0.64, 0.55, 0.45), 0.34)
	_ship_shell(k, W, D, H, "tan")
	k.hanging_lamp(Vector3(0, 2.3, -1.2), Color(1.0, 0.86, 0.64), 1.2, H, true)
	k.hanging_lamp(Vector3(0.6, 2.3, 1.6), Color(1.0, 0.86, 0.64), 0.6, H, false, 4.5)
	# the office floor is one step up, behind a service counter with a gap on the right
	k.slab(-W / 2.0, -D / 2.0, W / 2.0, 0.2, UP, k.wood_floor(Color(0.34, 0.2, 0.1), Color(0.54, 0.34, 0.18), 0.2), 0.18)
	k.box(Vector3(5.0, 0.95, 0.55), Vector3(-1.0, 0.475, 0.5), k.wood_mid, true)
	k.box(Vector3(5.1, 0.05, 0.7), Vector3(-1.0, 0.975, 0.5), k.wood_light)
	k.sphere(0.06, Vector3(0.6, 1.03, 0.45), k.brass, null, Vector3(1, 0.7, 1))
	k.note("Service bell", "Ding. Nobody comes.", Vector3(0.6, 1.0, 0.45), Vector3(0.5, 0.4, 0.5), Vector3(0, 0.1, 0))
	k.stairs(Vector3(2.5, 0, 1.0), Vector3(2.5, UP, 0.2), 2.0, {"count": 2, "mat": k.wood_light, "rail": "none"})
	_port(k, Vector3(-W / 2.0, 1.8, 0.4), PI / 2.0)
	# desk with the dictaphone (hotspot)
	var desk := Vector3(0.3, UP, -D / 2.0 + 0.9)
	k.box(Vector3(1.5, 0.82, 0.75), desk + Vector3(0, 0.41, 0), k.wood_mid, true)
	k.box(Vector3(1.6, 0.05, 0.82), desk + Vector3(0, 0.845, 0), k.wood_light)
	for i in 3:
		k.box(Vector3(0.4, 0.2, 0.02), desk + Vector3(0.45, 0.2 + i * 0.22, 0.38), k.wood_light)
		k.sphere(0.02, desk + Vector3(0.45, 0.2 + i * 0.22, 0.4), k.brass)
	var dc: Node3D = k.hotspot("dictaphone", desk + Vector3(-0.2, 0.87, 0.0), Vector3(0.8, 0.7, 0.7), Vector3(0, 0.3, 0))
	k.box(Vector3(0.36, 0.14, 0.26), Vector3(0, 0.1, 0), k.mat(Color(0.35, 0.18, 0.08), 0.5), false, dc)
	for sx in [-0.15, 0.15]:
		for sz in [-0.1, 0.1]:
			k.sphere(0.025, Vector3(sx, 0.02, sz), k.brass, dc)
	var cylm: MeshInstance3D = k.cyl(0.05, 0.05, 0.22, Vector3(0, 0.22, 0), k.mat(Color(0.25, 0.2, 0.15), 0.5), dc)
	cylm.rotation.z = PI / 2.0
	k.cyl(0.015, 0.015, 0.25, Vector3(0.08, 0.32, -0.05), k.brass, dc).rotation.z = -0.5
	var horn: MeshInstance3D = k.cyl(0.18, 0.025, 0.36, Vector3(0.2, 0.46, 0.05), k.brass, dc)
	horn.rotation = Vector3(0.3, 0, -1.0)
	k.box(Vector3(0.3, 0.02, 0.2), Vector3(-0.45, 0.01, 0.05), k.paper, false, dc, 0.2)
	# hotspot: cylinder rack (back wall, left) - one slot empty
	var rk: Node3D = k.hotspot("rack", Vector3(-2.2, 1.55, -D / 2.0 + 0.1), Vector3(1.1, 1.2, 0.45), Vector3(0, 0, 0.12))
	k.box(Vector3(0.85, 1.05, 0.2), Vector3(0, 0, 0), k.wood_dark, false, rk)
	k.box(Vector3(0.6, 0.12, 0.02), Vector3(0, 0.6, 0.06), k.mat(Color(0.9, 0.75, 0.3), 0.4, 0.6), false, rk)
	var wax: Material = k.mat(Color(0.32, 0.22, 0.12), 0.4)
	for r in 4:
		for c in 4:
			var cp := Vector3(-0.3 + c * 0.2, 0.35 - r * 0.24, 0.1)
			k.cyl(0.07, 0.07, 0.02, cp + Vector3(0, -0.11, 0), k.wood_mid, rk)
			if r == 1 and c == 2:
				continue
			k.cyl(0.055, 0.055, 0.18, cp, wax, rk)
			k.cyl(0.058, 0.058, 0.03, cp + Vector3(0, 0.09, 0), k.brass, rk)
	# cubby shelves with papers, a clock and a picture
	k.box(Vector3(0.9, 0.7, 0.25), Vector3(0.5, 2.0, -D / 2.0 + 0.13), k.wood_dark)
	for r in 2:
		for c in 3:
			k.box(Vector3(0.24, 0.05, 0.02), Vector3(0.22 + c * 0.28, 1.85 + r * 0.32, -D / 2.0 + 0.27), k.paper)
	k.cyl(0.18, 0.18, 0.05, Vector3(2.0, 2.05, -D / 2.0 + 0.04), k.brass).rotation.x = PI / 2.0
	k.cyl(0.15, 0.15, 0.01, Vector3(2.0, 2.05, -D / 2.0 + 0.07), k.white).rotation.x = PI / 2.0
	k.box(Vector3(0.01, 0.11, 0.005), Vector3(2.0, 2.09, -D / 2.0 + 0.08), k.black)
	k.box(Vector3(0.08, 0.01, 0.005), Vector3(2.03, 2.05, -D / 2.0 + 0.08), k.black)
	k.box(Vector3(0.5, 0.65, 0.04), Vector3(-W / 2.0 + 0.03, 1.8, -1.9), k.wood_light, false, null, PI / 2.0)
	# hotspot: safe (right)
	var sf: Node3D = k.hotspot("safe", Vector3(2.3, UP, -D / 2.0 + 0.6), Vector3(1.0, 1.3, 0.9))
	k.box(Vector3(0.75, 0.95, 0.65), Vector3(0, 0.475, 0), k.mat(Color(0.12, 0.13, 0.16), 0.35, 0.7), true, sf)
	k.box(Vector3(0.6, 0.8, 0.02), Vector3(0, 0.5, 0.33), k.mat(Color(0.16, 0.17, 0.2), 0.35, 0.7), false, sf)
	k.cyl(0.1, 0.1, 0.04, Vector3(-0.08, 0.6, 0.35), k.brass, sf).rotation.x = PI / 2.0
	k.box(Vector3(0.04, 0.2, 0.04), Vector3(0.18, 0.5, 0.36), k.brass, false, sf)
	# hotspot: red armchair (front left) with a blanket
	var ac: Node3D = k.hotspot("armchair", Vector3(-2.3, UP, -1.2), Vector3(1.1, 1.2, 1.1), Vector3.ZERO, 0.5)
	var leather: Material = k.mat(Color(0.6, 0.1, 0.1), 0.55)
	k.box(Vector3(0.8, 0.42, 0.75), Vector3(0, 0.21, 0), leather, true, ac)
	k.box(Vector3(0.66, 0.12, 0.6), Vector3(0, 0.48, 0.04), k.mat(Color(0.66, 0.13, 0.12), 0.6), false, ac)
	k.box(Vector3(0.8, 0.75, 0.18), Vector3(0, 0.75, -0.3), leather, false, ac)
	for sx in [-0.42, 0.42]:
		k.box(Vector3(0.16, 0.3, 0.72), Vector3(sx, 0.55, 0.0), leather, false, ac)
	k.box(Vector3(0.36, 0.5, 0.03), Vector3(0.32, 0.6, 0.3), k.mat(Color(0.95, 0.8, 0.35), 0.95), false, ac, 0.2)
	k.cctv(Vector3(W / 2.0 - 0.15, 2.55, D / 2.0 - 0.4), -PI / 2.0 - 0.7)
	k.person("zuzu", Vector3(-2.3, 0, 1.6))
	k.person("fennel", Vector3(-0.5, 0, 1.7))
	k.door("hall", "Cabin Corridor", Vector3(W / 2.0, 0, 1.6), -PI / 2.0, {"h": 2.0})
	k.spawn = Vector3(2.4, 0, 1.7)
	k.look = Vector3(-1.0, 1.1, -2.4)


# =================================================================== Free Time hub: the promenade deck in the cave
## The Mudlark's promenade deck: cabin wall with warm windows on one side, a railing with lifebuoys on the
## other, paper lanterns strung overhead, twin smokestacks, the little onsen barrel tub, the red paddle wheel
## at the stern - and beyond the rail, the dark underground lake and cave walls dotted with glowing fungus.
static func _promenade(k) -> void:
	var W := 8.0
	var L := 28.0
	k.bounds = Vector2(W, L)
	k.environment("cave", Color(0.3, 0.55, 0.6), 0.45)
	var deck_m: Material = k.wood_floor(Color(0.34, 0.2, 0.1), Color(0.55, 0.36, 0.2), 0.2)
	k.box(Vector3(W, 0.3, L), Vector3(0, -0.15, 0), deck_m, true)
	k.box(Vector3(W + 0.4, 1.4, L + 0.4), Vector3(0, -0.95, 0), k.mat(Color(0.86, 0.86, 0.82), 0.7))
	k.box(Vector3(W + 0.42, 0.16, L + 0.42), Vector3(0, -0.36, 0), k.mat(TEAL, 0.6))
	# ---- west: the cabin superstructure (teal below, cream above), windows, doors, lamps
	var wx := -W / 2.0
	k.box(Vector3(0.3, 3.1, L), Vector3(wx - 0.15, 1.55, 0), k.mat(CREAM, 0.9), true)
	k.box(Vector3(0.05, 1.05, L), Vector3(wx + 0.02, 0.525, 0), k.wood_wall(TEAL_DARK, TEAL, 0.18))
	k.box(Vector3(0.07, 0.07, L), Vector3(wx + 0.04, 1.07, 0), k.brass)
	for i in 6:
		var z := -11.0 + i * 4.4
		if i % 3 != 1:
			k.shoji(Vector2(1.4, 0.9), Vector3(wx + 0.03, 1.8, z), PI / 2.0, Color(1.0, 0.82, 0.55), 1.4, Vector2(3, 2), false)
			k.box(Vector3(0.08, 0.06, 1.5), Vector3(wx + 0.05, 1.33, z), k.brass)
		k.wall_lamp(Vector3(wx, 2.2, z + 2.2), PI / 2.0, Color(1.0, 0.8, 0.55), 0.7, 5.0)
	# canopy over the west half, posts, upper-deck rail
	k.box(Vector3(4.6, 0.14, L), Vector3(wx + 2.2, 3.15, 0), k.mat(Color(0.86, 0.84, 0.78), 0.8))
	k.box(Vector3(0.12, 0.3, L), Vector3(0.5, 3.0, 0), k.mat(TEAL, 0.6))
	for i in 7:
		k.cyl(0.07, 0.07, 3.0, Vector3(0.5, 1.5, -12.0 + i * 3.4), k.mat(Color(0.9, 0.9, 0.86), 0.6))
	for i in 15:
		k.cyl(0.025, 0.025, 0.7, Vector3(0.45, 3.55, -13.0 + i * 1.85), k.white)
	k.box(Vector3(0.06, 0.06, L), Vector3(0.45, 3.9, 0), k.white)
	# twin smokestacks rising through the canopy
	for z in [-5.0, -0.5]:
		k.cyl(0.6, 0.65, 9.0, Vector3(-1.6, 7.6, z), k.mat(Color(0.08, 0.08, 0.09), 0.5, 0.4))
		k.cyl(0.66, 0.66, 0.5, Vector3(-1.6, 11.6, z), k.mat(Color(0.75, 0.12, 0.12), 0.6))
		k.cyl(0.72, 0.62, 0.3, Vector3(-1.6, 12.2, z), k.mat(Color(0.08, 0.08, 0.09), 0.5, 0.4))
		k.steam(Vector3(-1.6, 12.6, z), Vector3(0.3, 0.1, 0.3), 14, 1.6, 0.14, 0.9, 5.0)
	# ---- east: railing with lifebuoys
	var ex := W / 2.0
	for i in 29:
		k.cyl(0.03, 0.03, 1.0, Vector3(ex - 0.1, 0.5, -14.0 + i * 1.0), k.white)
	k.box(Vector3(0.12, 0.08, L), Vector3(ex - 0.1, 1.02, 0), k.mat(TEAL, 0.6))
	k.box(Vector3(0.05, 0.05, L), Vector3(ex - 0.1, 0.55, 0), k.white)
	k.blocker(Vector3(0.3, 1.6, L), Vector3(ex - 0.1, 0.8, 0))
	for z in [-9.0, -1.0, 7.0]:
		k.torus(0.2, 0.32, Vector3(ex - 0.05, 0.62, z), k.stripes(Color(0.95, 0.95, 0.95), Color(0.85, 0.15, 0.12), 4.0), null, Vector3(0, 0, PI / 2.0))
	# bow (north) and stern (south) rails, a Snapjaw banner at the bow, the paddle wheel at the stern
	for zz in [-L / 2.0, L / 2.0]:
		for i in 9:
			k.cyl(0.03, 0.03, 1.0, Vector3(-W / 2.0 + 0.5 + i * 0.9, 0.5, zz), k.white)
		k.box(Vector3(W, 0.08, 0.12), Vector3(0, 1.02, zz), k.mat(TEAL, 0.6))
		k.blocker(Vector3(W, 1.6, 0.3), Vector3(0, 0.8, zz))
	k.cyl(0.05, 0.05, 4.0, Vector3(2.8, 2.0, -L / 2.0 + 0.3), k.brass)
	k.box(Vector3(1.0, 1.5, 0.03), Vector3(2.8, 3.1, -L / 2.0 + 0.3), k.mat(Color(0.5, 0.08, 0.16), 0.8))
	k.cyl(0.32, 0.32, 0.02, Vector3(2.8, 3.2, -L / 2.0 + 0.32), k.mat(Color(0.25, 0.55, 0.3), 0.6)).rotation.x = PI / 2.0
	var wheel := Node3D.new()
	wheel.position = Vector3(0, 1.2, L / 2.0 + 2.2)
	k.root.add_child(wheel)
	var red: Material = k.mat(Color(0.75, 0.12, 0.1), 0.6)
	k.torus(3.0, 3.25, Vector3.ZERO, red, wheel, Vector3(0, 0, PI / 2.0))
	k.torus(1.2, 1.4, Vector3.ZERO, red, wheel, Vector3(0, 0, PI / 2.0))
	for i in 12:
		var a := i * TAU / 12.0
		var spoke: MeshInstance3D = k.box(Vector3(0.6, 0.1, 6.2), Vector3.ZERO, red, false, wheel)
		spoke.rotation.x = a
	# ---- deck life: onsen barrel tub, deck chairs, planters, grill, anchor, gauge panel, first-aid box
	var tub := Vector3(2.2, 0, -8.6)
	k.cyl(0.85, 0.8, 0.8, tub + Vector3(0, 0.4, 0), k.wood_light, null, true, 24)
	for yy in [0.15, 0.65]:
		k.cyl(0.87, 0.87, 0.05, tub + Vector3(0, yy, 0), k.steel, null, false, 24)
	k.cyl(0.78, 0.78, 0.02, tub + Vector3(0, 0.75, 0), k.water(Color(0.05, 0.4, 0.42), Color(0.45, 0.9, 0.82), 0.4), null, false, 24)
	k.steam(tub + Vector3(0, 0.85, 0), Vector3(0.5, 0.05, 0.5), 14, 0.9, 0.14, 0.35, 3.5)
	k.bucket(tub + Vector3(-1.1, 0, 0.6), 1.0)
	var chair_m: Material = k.stripes(Color(0.95, 0.92, 0.85), Color(0.15, 0.5, 0.5), 8.0)
	for c in [Vector3(2.6, 0, -3.6), Vector3(2.6, 0, 6.2)]:
		var cp: Vector3 = c
		var seat: MeshInstance3D = k.box(Vector3(0.6, 0.06, 1.4), cp + Vector3(0, 0.35, 0), chair_m)
		seat.rotation.x = 0.0
		var back: MeshInstance3D = k.box(Vector3(0.6, 0.8, 0.06), cp + Vector3(0, 0.65, -0.75), chair_m)
		back.rotation.x = -0.5
		for sz in [-0.6, 0.6]:
			k.box(Vector3(0.62, 0.32, 0.04), cp + Vector3(0, 0.16, sz), k.wood_dark)
		k.blocker(Vector3(0.6, 0.8, 1.4), cp + Vector3(0, 0.4, 0))
	for i in 3:
		var pp := Vector3(-3.4, 0, -6.8 + i * 0.9)
		k.box(Vector3(0.6, 0.4, 0.7), pp + Vector3(0, 0.2, 0), k.wood_mid, true)
		for j in 4:
			k.sphere(0.13, pp + Vector3(-0.15 + (j % 2) * 0.3, 0.5, -0.15 + (j / 2) * 0.3), k.mat(Color(0.25, 0.55, 0.22).lerp(Color(0.4, 0.65, 0.3), _h(i * 4 + j)), 0.8), null, Vector3.ONE, 8)
	var grill := Vector3(-3.2, 0, 7.4)
	k.box(Vector3(0.6, 0.85, 1.2), grill + Vector3(0, 0.425, 0), k.mat(Color(0.15, 0.15, 0.16), 0.5, 0.6), true)
	k.box(Vector3(0.5, 0.02, 1.0), grill + Vector3(0, 0.86, 0), k.glow(Color(1.0, 0.4, 0.12), 2.0))
	for i in 3:
		k.sphere(0.07, grill + Vector3(0, 0.92, -0.3 + i * 0.3), k.mat(Color(0.75, 0.4, 0.2), 0.6), null, Vector3(1.4, 0.6, 1))
	k.steam(grill + Vector3(0, 1.0, 0), Vector3(0.15, 0.02, 0.4), 8, 0.45, 0.14, 0.4, 2.0)
	k.omni(grill + Vector3(0.4, 1.1, 0), Color(1.0, 0.5, 0.2), 0.8, 3.0)
	var anchor := Vector3(3.3, 0, 10.6)
	k.cyl(0.05, 0.05, 1.1, anchor + Vector3(0, 0.6, 0), k.steel)
	k.torus(0.07, 0.11, anchor + Vector3(0, 1.2, 0), k.steel, null, Vector3(PI / 2.0, 0, 0))
	k.torus(0.4, 0.46, anchor + Vector3(0, 0.45, 0), k.steel, null, Vector3(PI / 2.0, 0, 0))
	k.box(Vector3(0.9, 0.06, 0.06), anchor + Vector3(0, 1.0, 0), k.steel)
	k.box(Vector3(0.36, 0.5, 0.1), Vector3(wx + 0.06, 1.5, -2.7), k.brass, false, null, PI / 2.0)
	for i in 2:
		k.cyl(0.08, 0.08, 0.03, Vector3(wx + 0.12, 1.6 - i * 0.2, -2.7), k.white).rotation.z = PI / 2.0
	k.box(Vector3(0.12, 0.4, 0.5), Vector3(wx + 0.08, 1.5, 1.4), k.white)
	k.box(Vector3(0.02, 0.08, 0.28), Vector3(wx + 0.15, 1.5, 1.4), k.mat(Color(0.2, 0.7, 0.3), 0.6))
	k.box(Vector3(0.02, 0.24, 0.08), Vector3(wx + 0.15, 1.5, 1.4), k.mat(Color(0.2, 0.7, 0.3), 0.6))
	var easel := Node3D.new()
	easel.position = Vector3(3.0, 0, 3.0)
	easel.rotation.y = -PI / 2.0 - 0.3
	k.root.add_child(easel)
	for sx in [-0.3, 0.3]:
		var leg: MeshInstance3D = k.box(Vector3(0.04, 1.7, 0.04), Vector3(sx, 0.85, 0.0), k.wood_light, false, easel)
		leg.rotation.x = -0.12
	k.box(Vector3(0.8, 0.6, 0.03), Vector3(0, 1.25, 0.1), k.white, false, easel)
	k.box(Vector3(0.7, 0.5, 0.01), Vector3(0, 1.25, 0.12), k.mat(Color(0.05, 0.25, 0.3), 0.9), false, easel)
	for i in 5:
		k.sphere(0.03, Vector3(-0.25 + i * 0.12, 1.15 + 0.1 * sin(i * 2.0), 0.13), k.glow(FUNGUS, 2.0), easel, Vector3(1, 1, 0.3))
	k.cctv(Vector3(wx + 0.1, 2.7, 9.8), PI / 2.0 + 0.5)
	k.cctv(Vector3(0.55, 2.75, -9.0), PI / 2.0 + 2.4)
	# strings of paper lanterns between the canopy and the rail
	var lcols := [Color(1.0, 0.4, 0.3), Color(1.0, 0.85, 0.5), Color(1.0, 0.95, 0.85), Color(1.0, 0.6, 0.3)]
	for i in 4:
		var z := -11.0 + i * 7.0
		k.lantern_string(Vector3(0.5, 2.95, z), Vector3(ex - 0.1, 2.4, z + 2.5), 5, lcols, 0.35, 2)
	k.lantern_string(Vector3(-3.5, 3.0, -13.0), Vector3(-3.5, 3.0, 13.0), 16, lcols, 0.25, 3)
	# ---- the cave beyond: dark lake, rock walls and ceiling, glowing fungus, stalactites
	k.box(Vector3(160, 0.1, 160), Vector3(0, -2.2, 0), k.water(Color(0.01, 0.05, 0.07), Color(0.05, 0.25, 0.28), 0.25))
	var rock_m: Material = k.rock_mat(Color(0.08, 0.11, 0.13), Color(0.2, 0.24, 0.26))
	var glow_m: Material = k.glow(FUNGUS, 3.5)
	var glow2: Material = k.glow(Color(0.5, 1.0, 0.75), 3.0)
	var stem: Material = k.mat(Color(0.7, 0.9, 0.85), 0.6)
	for i in 14:
		var a := -1.2 + i * 0.2
		var p := Vector3(cos(a) * 30.0 + 6.0, 3.0 + 6.0 * _h(i), sin(a) * 30.0)
		k.sphere(1.0, p, rock_m, null, Vector3(10, 14 + 6 * _h(i + 3), 9), 14)
		for j in 6:
			var q := p + Vector3(-8.0 - 1.5 * _h(i * 7 + j), -7.0 + 9.0 * _h(i * 3 + j), -6.0 + 12.0 * _h(i * 5 + j * 2))
			_fungus(k, q, 0.5 + 0.6 * _h(i + j * 11), glow_m if j % 3 else glow2, stem)
	for i in 10:
		var p := Vector3(-28.0 + 2.0 * _h(i), 2.0 + 8.0 * _h(i + 5), -40.0 + i * 9.0)
		k.sphere(1.0, p, rock_m, null, Vector3(12, 16, 10), 14)
		for j in 4:
			_fungus(k, p + Vector3(10.5, -6.0 + 8.0 * _h(i * 2 + j), -5.0 + 10.0 * _h(i * 4 + j)), 0.6 + 0.5 * _h(i + j * 7), glow_m, stem)
	for p in [Vector3(22, 3, -10), Vector3(22, 3, 6), Vector3(-18, 3, -6), Vector3(-18, 3, 10)]:
		k.omni(p, FUNGUS, 2.2, 18.0)
	k.box(Vector3(160, 2.0, 160), Vector3(0, 24.0, 0), rock_m)
	for i in 60:
		var p := Vector3(-40.0 + 80.0 * _h(i * 3 + 1), 23.0, -40.0 + 80.0 * _h(i * 7 + 2))
		if absf(p.x) < 6.0 and absf(p.z) < 16.0:
			continue
		var len := 2.0 + 5.0 * _h(i + 9)
		k.cyl(0.6 + 0.6 * _h(i), 0.02, len, p - Vector3(0, len / 2.0, 0), rock_m, null, false, 7)
		if i % 2 == 0:
			k.sphere(0.18, p - Vector3(0, len * 0.6, 0), glow_m, null, Vector3.ONE, 6)
	k.omni(Vector3(16, 4, 0), FUNGUS, 1.4, 30.0)
	k.omni(Vector3(-14, 4, -10), FUNGUS, 1.0, 25.0)
	k.door("companionway", "Main Stairs", Vector3(wx + 0.05, 0, -6.6), PI / 2.0)
	k.door("saloon", "", Vector3(wx + 0.05, 0, 6.6), PI / 2.0)
	k.lift("deck_lift", Vector3(-2.7, 0, 11.6), 0.0, "lower_lift", "companionway", "Lower Passage", _cargo_style(k, "DECK"))
	k.note("The rail", "The water down there is black as ink. Better not lean out too far.", Vector3(3.4, 0, -11.0), Vector3(0.6, 1.3, 1.6), Vector3(0, 0.8, 0))
	if k.mode == "freetime":
		k.person("lulu", Vector3(0.0, 0, -11.8))
		k.person("reginald", Vector3(0.2, 0, 4.2))
		k.person("bramble", Vector3(-2.5, 0, -5.9))
		k.person("pepper", Vector3(3.0, 0, -0.6))
		k.person("duchess", Vector3(1.9, 0, -3.4))
		k.person("tumble", Vector3(1.9, 0, 6.8))
	k.spawn = Vector3(0.0, 0, 12.6)
	k.look = Vector3(0, 1.3, 0.0)


static func _cargo_style(k, label_text: String) -> Dictionary:
	return {"sign": label_text, "wall": k.mat(Color(0.28, 0.3, 0.33), 0.45, 0.7), "floor_m": k.mat(Color(0.2, 0.2, 0.22), 0.5, 0.7),
		"door_m": k.mat(Color(0.5, 0.42, 0.25), 0.4, 0.7)}


# =================================================================== Main Stairs + Lower Passage (one continuous space)
## Three levels of stairs in an open well (lower deck, cabin deck, promenade), and at the bottom a long, low passage
## leading to the Laundry, Infirmary, Boiler Room, the Back Stairs and the cargo lift.
static func _companionway(k) -> void:
	k.environment("indoor", Color(0.56, 0.56, 0.5), 0.34)
	var Y1 := 3.0
	var Y2 := 6.0
	var H := 8.8
	k.bounds = Vector2(7.0, 9.0)
	var floor_m: Material = k.wood_floor(Color(0.3, 0.17, 0.09), Color(0.5, 0.31, 0.16), 0.2)
	var o := {"wall": k.wood_wall(TAN.darkened(0.15), TAN, 0.26), "wain": k.wood_wall(TEAL_DARK, TEAL, 0.18), "wain_h": 1.05, "trim": k.brass}
	k.slab(-3.5, -4.5, 3.5, 4.5, 0.0, floor_m)
	k.slab(-3.5, -4.5, 3.5, 4.5, H + 0.12, k.mat(Color(0.24, 0.15, 0.09), 0.85), 0.12, false)
	k.wall_run(Vector2(-3.5, -4.5), Vector2(3.5, -4.5), 0.0, H, o)
	k.wall_run(Vector2(3.5, -4.5), Vector2(3.5, 4.5), 0.0, H, o, [[6.8, 9.0, 0.0, 2.5]])
	k.wall_run(Vector2(3.5, 4.5), Vector2(-3.5, 4.5), 0.0, H, o)
	k.wall_run(Vector2(-3.5, 4.5), Vector2(-3.5, -4.5), 0.0, H, o)
	# landings
	k.slab(-3.5, -4.5, 3.5, -2.2, Y1, floor_m)
	k.slab(-3.5, 2.2, 3.5, 4.5, Y2, floor_m)
	var tread: Material = k.wood_floor(Color(0.34, 0.2, 0.1), Color(0.54, 0.34, 0.18), 0.2)
	k.stairs(Vector3(-2.5, 0, 2.2), Vector3(-2.5, Y1, -2.2), 2.0, {"mat": tread, "solid": false, "rail": "left"})
	k.stairs(Vector3(2.5, Y1, -2.2), Vector3(2.5, Y2, 2.2), 2.0, {"mat": tread, "solid": false, "rail": "left"})
	k.rail(Vector3(-1.5, Y1, -2.2), Vector3(1.5, Y1, -2.2))
	k.rail(Vector3(-3.5, Y2, 2.2), Vector3(1.5, Y2, 2.2))
	# lamps and deck signs on each level
	for y in [0.0, Y1, Y2]:
		var yy: float = y
		k.wall_lamp(Vector3(-3.5, yy + 2.0, 0.0), PI / 2.0, Color(1.0, 0.8, 0.55), 0.75, 7.0)
		k.wall_lamp(Vector3(3.5, yy + 2.0, -0.5), -PI / 2.0, Color(1.0, 0.8, 0.55), 0.75, 7.0)
	_port(k, Vector3(-3.5, 2.0, 2.0), PI / 2.0)
	_port(k, Vector3(3.5, Y2 + 1.6, 3.6), -PI / 2.0)
	_port(k, Vector3(-3.5, Y1 + 1.6, -3.6), PI / 2.0)
	k.label("LOWER DECK", Vector3(0, 2.1, 4.48), PI, 52, Style.GOLD, null, 0.0045, 8)
	k.label("CABIN DECK", Vector3(0, Y1 + 2.45, -4.48), 0.0, 52, Style.GOLD, null, 0.0045, 8)
	k.label("PROMENADE", Vector3(-1.0, Y2 + 2.1, 4.48), PI, 52, Style.GOLD, null, 0.0045, 8)
	k.door("hall", "Cabin Corridor", Vector3(-1.5, Y1, -4.5), 0.0)
	k.door("saloon", "", Vector3(1.5, Y1, -4.5), 0.0)
	k.door("promenade", "", Vector3(-0.6, Y2, 4.5), PI)
	k.cctv(Vector3(-3.4, Y1 + 2.6, -4.3), 0.7)
	# ---- Lower Passage: low, pipes overhead, puddles on the floor, with a bay for the cargo lift
	var pass_o := {"floor": k.stone_floor(Color(0.22, 0.22, 0.23), Color(0.32, 0.31, 0.3), 0.8, 0.7),
		"wall": k.smat(Kit.SH_METAL, {"base": Color(0.27, 0.3, 0.3)}), "wain": k.wood_wall(TEAL_DARK.darkened(0.2), TEAL_DARK, 0.18), "wain_h": 0.9,
		"trim": k.mat(Color(0.2, 0.22, 0.22), 0.5, 0.6), "ceiling": k.mat(Color(0.14, 0.14, 0.15), 0.7, 0.3), "open": ["w"]}
	k.plan([[3.5, 2.3, 21.0, 4.5], [15.0, 0.0, 17.4, 2.3, 3.1]], 0.0, 2.5, pass_o)
	var pipe_m: Material = k.mat(Color(0.42, 0.36, 0.28), 0.4, 0.7)
	k.beam(Vector3(3.5, 2.28, 2.55), Vector3(21.0, 2.28, 2.55), 0.07, pipe_m)
	k.beam(Vector3(3.5, 2.28, 4.25), Vector3(21.0, 2.28, 4.25), 0.045, pipe_m)
	k.beam(Vector3(3.5, 2.1, 4.38), Vector3(21.0, 2.1, 4.38), 0.03, k.brass)
	for i in 6:
		var x := 5.0 + i * 3.1
		k.sphere(0.06, Vector3(x, 2.25, 3.4), k.glow(Color(1.0, 0.82, 0.55), 4.0))
		var l: OmniLight3D = k.omni(Vector3(x, 2.1, 3.4), Color(1.0, 0.8, 0.55), 0.8, 5.0, i == 2)
		if i % 2 == 1:
			k.flickers.append(l)
	var puddle: Material = k.mat(Color(0.06, 0.09, 0.1), 0.05, 0.3)
	for pd in [Vector3(7.0, 0.006, 3.9), Vector3(11.0, 0.006, 2.9), Vector3(18.0, 0.006, 3.7)]:
		var pm: MeshInstance3D = k.cyl(0.55, 0.55, 0.01, pd, puddle, null, false, 14)
		pm.scale = Vector3(1.4, 1, 0.8)
	k.torus(0.1, 0.14, Vector3(13.6, 1.3, 2.34), k.mat(Color(0.75, 0.15, 0.12), 0.5), null, Vector3(PI / 2.0, 0, 0))
	k.note("Valve", "Something's gurgling in these pipes. Hopefully just water.", Vector3(13.6, 0, 2.6), Vector3(0.7, 0.8, 0.5), Vector3(0, 1.3, 0))
	k.lift("lower_lift", Vector3(16.2, 0, 2.3), 0.0, "deck_lift", "promenade", "Promenade Deck", _cargo_style(k, "LOWER"))
	k.door("laundry", "", Vector3(8.0, 0, 2.3), 0.0, {"h": 1.9})
	k.door("infirmary", "", Vector3(12.0, 0, 4.5), PI, {"h": 1.9})
	k.door("boiler", "", Vector3(21.0, 0, 3.4), -PI / 2.0, {"h": 1.9, "mat": k.steel, "frame": k.mat(Color(0.18, 0.18, 0.2), 0.5, 0.6)})
	k.door("back_stairs", "", Vector3(5.6, 0, 4.5), PI, {"h": 1.9})
	k.cctv(Vector3(20.8, 2.2, 2.45), -PI / 2.0 - 0.5)
	if k.mode == "freetime":
		k.person("bruno", Vector3(18.9, 0, 3.8))
		k.person("marigold", Vector3(10.3, 0, 3.9))
	k.spawn = Vector3(0, 0, 3.3)
	k.look = Vector3(14.0, 1.2, 3.4)


# =================================================================== Back Stairs (one narrow flight)
static func _back_stairs(k) -> void:
	k.environment("dim", Color(0.45, 0.42, 0.42), 0.26)
	k.bounds = Vector2(1.5, 7.6)
	var wall_m: Material = k.wood_wall(TAN.darkened(0.55), TAN.darkened(0.35), 0.2)
	var o := {"floor": k.wood_floor(Color(0.22, 0.13, 0.08), Color(0.36, 0.22, 0.12), 0.16), "wall": wall_m, "wain": null,
		"trim": k.mat(Color(0.14, 0.1, 0.07), 0.8), "ceiling": k.mat(Color(0.14, 0.1, 0.08), 0.9)}
	var low_o := o.duplicate()
	low_o["open"] = ["n"]
	k.plan([[-0.75, 0.0, 0.75, 1.8]], 0.0, 5.45, low_o)
	var top_o := o.duplicate()
	top_o["open"] = ["s"]
	k.plan([[-0.75, -6.2, 0.75, -4.4]], 3.0, 2.45, top_o)
	var side := {"wall": wall_m, "wain": null, "trim": o["trim"]}
	k.wall_run(Vector2(0.75, -4.4), Vector2(0.75, 0.0), 0.0, 5.45, side)
	k.wall_run(Vector2(-0.75, 0.0), Vector2(-0.75, -4.4), 0.0, 5.45, side)
	k.slab(-0.75, -4.4, 0.75, 0.0, 5.57, o["ceiling"], 0.12, false)
	k.stairs(Vector3(0, 0, 0.0), Vector3(0, 3.0, -4.4), 1.5, {"mat": k.wood_mid, "rail": "none"})
	k.beam(Vector3(0.68, 1.0, -0.1), Vector3(0.68, 4.0, -4.3), 0.025, k.brass)
	for p in [Vector3(0, 2.6, 1.0), Vector3(0, 3.8, -2.2), Vector3(0, 5.2, -5.4)]:
		var pp: Vector3 = p
		k.sphere(0.05, pp, k.glow(Color(1.0, 0.82, 0.55), 4.0))
		k.flickers.append(k.omni(pp + Vector3(0, -0.1, 0), Color(1.0, 0.82, 0.55), 0.7, 4.5))
	k.note("Worn steps", "The steps sag in the middle. Generations of tired paws, probably.", Vector3(0, 1.4, -2.0), Vector3(1.0, 0.6, 1.0), Vector3(0, 0.4, 0))
	k.door("companionway", "Lower Passage", Vector3(0, 0, 1.8), PI, {"h": 2.0})
	k.door("hall", "Cabin Corridor", Vector3(0, 3.0, -6.2), 0.0, {"h": 2.0})
	k.spawn = Vector3(0, 0, 0.8)
	k.look = Vector3(0, 2.5, -5.0)


# =================================================================== Saloon (long dining room you can walk through)
static func _saloon(k) -> void:
	var W := 6.0
	var D := 13.0
	var H := 3.1
	k.environment("indoor", Color(0.62, 0.52, 0.42), 0.36)
	_ship_shell(k, W, D, H, "tan")
	k.rug(Vector3(0, 0, 0), Vector2(2.6, D - 1.0), Color(0.55, 0.1, 0.12), Color(0.8, 0.6, 0.25))
	k.box(Vector3(1.3, 0.74, 5.2), Vector3(0, 0.37, -0.8), k.wood_dark, true)
	k.box(Vector3(1.42, 0.03, 5.3), Vector3(0, 0.76, -0.8), k.white)
	for i in 7:
		var z := -3.1 + i * 0.77
		for sx in [-1.0, 1.0]:
			k.chair(Vector3(sx * 0.98, 0, z), sx * -PI / 2.0, k.mat(Color(0.5, 0.1, 0.12), 0.85), k.wood_dark)
			k.cyl(0.1, 0.09, 0.012, Vector3(sx * 0.42, 0.785, z), k.white)
	for i in 3:
		k.cyl(0.04, 0.09, 0.3, Vector3(0, 0.92, -2.8 + i * 2.0), k.brass)
		k.sphere(0.05, Vector3(0, 1.12, -2.8 + i * 2.0), k.glow(Color(1.0, 0.82, 0.55), 3.5))
	for z in [-4.2, -0.6, 3.2]:
		k.hanging_lamp(Vector3(0, 2.6, z), Color(1.0, 0.84, 0.6), 0.9, H, z == -0.6, 6.0)
		for sx in [-1.0, 1.0]:
			_port(k, Vector3(sx * W / 2.0, 1.8, z), -sx * PI / 2.0, 0.2, false)
	# piano and chess table at the far end
	var piano := Vector3(2.0, 0, 5.2)
	k.box(Vector3(1.4, 1.2, 0.55), piano + Vector3(0, 0.6, 0.3), k.mat(Color(0.12, 0.07, 0.05), 0.3), true)
	k.box(Vector3(1.3, 0.06, 0.28), piano + Vector3(0, 0.8, -0.1), k.white)
	k.note("Piano", "One key is stuck. It's the sad one.", piano, Vector3(1.5, 1.4, 1.0), Vector3(0, 0.7, 0.0))
	k.table(Vector3(-2.0, 0, 5.2), Vector3(0.8, 0.72, 0.8), k.wood_light, k.wood_dark)
	k.box(Vector3(0.6, 0.02, 0.6), Vector3(-2.0, 0.73, 5.2), k.mat(Color(0.25, 0.2, 0.15), 0.5))
	for i in 8:
		k.cyl(0.018, 0.024, 0.08, Vector3(-2.24 + (i % 4) * 0.16, 0.78, 5.0 + (i / 4) * 0.4), k.white if i < 4 else k.black)
	k.cctv(Vector3(W / 2.0 - 0.15, 2.7, -D / 2.0 + 0.5), -PI / 2.0 + 0.6)
	k.door("promenade", "", Vector3(0, 0, -D / 2.0), 0.0)
	k.door("companionway", "Main Stairs", Vector3(0, 0, D / 2.0), PI)
	if k.mode == "freetime":
		k.person("nibs", Vector3(-2.3, 0, 3.8))
		k.person("grub", Vector3(-2.2, 0, -2.6))
		k.person("fennel", Vector3(2.2, 0, 1.8))
		k.person("zuzu", Vector3(2.3, 0, -3.5))
	k.spawn = Vector3(0, 0, D / 2.0 - 1.2)
	k.look = Vector3(0, 1.2, -6.0)


# =================================================================== Mochi's Cabin
static func _mochi_cabin(k) -> void:
	var W := 3.8
	var D := 3.6
	var H := 2.3
	k.environment("indoor", Color(0.6, 0.55, 0.48), 0.34)
	_ship_shell(k, W, D, H, "tan")
	k.hanging_lamp(Vector3(0.5, 2.0, 0.2), Color(1.0, 0.86, 0.66), 0.8, H, true, 5.0)
	k.box(Vector3(2.0, 0.5, 0.9), Vector3(-0.8, 0.25, -D / 2.0 + 0.55), k.wood_mid, true)
	k.box(Vector3(1.9, 0.14, 0.86), Vector3(-0.8, 0.57, -D / 2.0 + 0.55), k.white)
	k.box(Vector3(1.3, 0.05, 0.88), Vector3(-0.5, 0.66, -D / 2.0 + 0.55), k.mat(Color(0.2, 0.3, 0.6), 0.9))
	k.sphere(0.2, Vector3(-1.5, 0.7, -D / 2.0 + 0.55), k.white, null, Vector3(1.0, 0.4, 1.5))
	k.porthole(Vector3(-0.8, 1.6, -D / 2.0 + 0.02), 0.0, 0.2, FUNGUS, 1.5)
	k.note("Your bunk", "Thin walls. You can hear everything on this boat.", Vector3(-0.8, 0, -D / 2.0 + 0.55), Vector3(2.0, 0.9, 1.0), Vector3(0, 0.45, 0))
	k.door("hall", "Cabin Corridor", Vector3(W / 2.0, 0, 0.7), -PI / 2.0, {"h": 1.75})
	k.spawn = Vector3(0.6, 0, 0.8)
	k.look = Vector3(-0.8, 0.9, -1.8)
