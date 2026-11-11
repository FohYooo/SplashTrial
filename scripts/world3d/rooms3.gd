extends RefCounted
## Chapter 3 (Warden's Rest, the island) 3D spaces for the walk-around version.
## Same conventions as rooms1.gd / rooms2.gd: one builder per space id, doors following the house plan, people at
## k.person(char, pos). Every place of Case 3 is listed in SPACES with its map pin and "opens_day" (Chapters.room_open).
## An id that investigation_data3.gd also lists as a room is that room (its entry wins); the rest are walkable spaces.
##
## Look of the house: a grand, earthquake-cracked Victorian mansion on a cliff, built for the Warden of the Gaol across
## the bay. Dark panelling, green and oxblood wallpaper, a marble chequer in the Grand Hall, gilt frames, brass
## chandeliers, sea light from tall sash windows; Snapjaw's cameras and crocodile crests everywhere.
##
## The state of a space follows the story day (Chapters.day_at of the current step, or k.get_meta("day"), or the debug
## argument --day3d=<n>): on Day 6 the Library door is broken in, its tall bookcase has come down across the desk,
## the Gallery clock lies stopped on the floor, and white plaster dust lies everywhere the 11:05 aftershock reached.
##
## The 7 AM photographs (tools/render_evidence3.gd) build the Library and the Gallery with extra metas: "photo_trail"
## (the dragged line in the dust before the crowd trampled it), "photo_pen" ("chewed" for the pen by the hatch before
## the swap), "photo_hatch" ("shut" before it), "gallery_clock" / "library_clock" (Vector2(hour, minute) of that room's
## mantel clock).
## Every examinable thing a later Case 3 package may want is already built as a k.hotspot anchor (see the "anchors"
## notes above each builder). An anchor only becomes examinable when investigation_data3.gd lists its id.
## Free Time: FREE_SPACES and the per-day guest spots in FREE_BY_DAY. In investigation mode guests without a named
## spot stand at the room's k.spots, in order.

const Style := preload("res://scripts/ui/style.gd")
const Kit := preload("res://scripts/world3d/kit.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Chapters := preload("res://scripts/data/chapters.gd")
const MouseGuard := preload("res://scripts/world3d/mouse_guard.gd")

## Every place of Case 3: name, where its pin goes on the mansion map (board coordinates, see investigation3d_screen.gd),
## the story day it opens and, for the passage, the investigation stage that opens it.
const SPACES := {
	# the island
	"shore": {"name": "Shore", "map_at": Vector2(150, 520), "opens_day": 1, "area": "island"},
	"wreck": {"name": "Mudlark Wreck", "map_at": Vector2(150, 420), "opens_day": 5, "area": "island"},
	"terrace": {"name": "Terrace", "map_at": Vector2(300, 520), "opens_day": 1, "area": "island"},
	"cliff_path": {"name": "Cliff Path", "map_at": Vector2(470, 560), "opens_day": 4, "area": "island"},
	"boathouse": {"name": "Boathouse", "map_at": Vector2(640, 560), "opens_day": 4, "area": "island"},
	"prison_yard": {"name": "Prison Yard", "map_at": Vector2(1010, 545), "opens_day": 4, "area": "prison"},
	"visiting_room": {"name": "Visiting Room", "map_at": Vector2(1010, 455), "opens_day": 4, "area": "prison"},
	# ground floor
	"grand_hall": {"name": "Grand Hall", "map_at": Vector2(470, 330), "opens_day": 1, "area": "ground"},
	"dining_room": {"name": "Dining Room", "map_at": Vector2(300, 285), "opens_day": 1, "area": "ground"},
	"kitchen": {"name": "Kitchen", "map_at": Vector2(300, 385), "opens_day": 1, "area": "ground"},
	"music_room": {"name": "Music Room", "map_at": Vector2(640, 285), "opens_day": 2, "area": "ground"},
	"marble_bath": {"name": "Marble Bath", "map_at": Vector2(640, 385), "opens_day": 3, "area": "ground"},
	"conservatory": {"name": "Conservatory", "map_at": Vector2(470, 455), "opens_day": 3, "area": "ground"},
	# below stairs
	"wine_cellar": {"name": "Wine Cellar", "map_at": Vector2(800, 400), "opens_day": 2, "area": "below"},
	"generator_room": {"name": "Generator Room", "map_at": Vector2(800, 470), "opens_day": 5, "area": "below"},
	# upper floor
	"library": {"name": "Library", "map_at": Vector2(300, 160), "opens_day": 2, "area": "upper"},
	"gallery": {"name": "Gallery", "map_at": Vector2(640, 160), "opens_day": 2, "area": "upper"},
	"bedroom_wing": {"name": "Bedroom Wing", "map_at": Vector2(470, 160), "opens_day": 1, "area": "upper"},
	"servants_passage": {"name": "Servants' Passage", "map_at": Vector2(330, 215), "opens_day": 6, "opens_stage": 3, "area": "upper"},
	"attic": {"name": "Attic", "map_at": Vector2(800, 160), "opens_day": 3, "area": "upper"},
	# the guests' bedrooms (one layout, each with its owner's things), named for island birds, not for anyone
	"bedroom_mochi": {"name": "Curlew Room", "map_at": Vector2(410, 112), "opens_day": 1, "area": "bedroom"},
	"bedroom_bramble": {"name": "Dunlin Room", "map_at": Vector2(430, 112), "opens_day": 1, "area": "bedroom"},
	"bedroom_bruno": {"name": "Gannet Room", "map_at": Vector2(450, 112), "opens_day": 1, "area": "bedroom"},
	"bedroom_duchess": {"name": "Heron Room", "map_at": Vector2(470, 112), "opens_day": 1, "area": "bedroom"},
	"bedroom_fennel": {"name": "Kittiwake Room", "map_at": Vector2(490, 112), "opens_day": 1, "area": "bedroom"},
	"bedroom_grub": {"name": "Lapwing Room", "map_at": Vector2(510, 112), "opens_day": 1, "area": "bedroom"},
	"bedroom_lulu": {"name": "Merlin Room", "map_at": Vector2(530, 112), "opens_day": 1, "area": "bedroom"},
	"bedroom_pepper": {"name": "Osprey Room", "map_at": Vector2(425, 208), "opens_day": 1, "area": "bedroom"},
	"bedroom_nibs": {"name": "Plover Room", "map_at": Vector2(450, 208), "opens_day": 1, "area": "bedroom"},
	"bedroom_reginald": {"name": "Shearwater Room", "map_at": Vector2(475, 208), "opens_day": 1, "area": "bedroom"},
	"bedroom_zuzu": {"name": "Tern Room", "map_at": Vector2(500, 208), "opens_day": 1, "area": "bedroom"},
}

## Free Time: where you can walk (each is shut until its own day), and where you start.
const FREE_SPACES := ["grand_hall", "dining_room", "kitchen", "terrace", "shore", "library", "gallery", "music_room",
	"conservatory", "marble_bath", "cliff_path"]
const FREE_START := "grand_hall"

## Bedrooms along the Bedroom Wing, in door order (north side first, west to east, then the south side).
const BEDROOMS := ["mochi", "bramble", "bruno", "duchess", "fennel", "grub", "lulu", "pepper", "nibs", "reginald", "zuzu"]

## Where each guest spends Free Time, from the day given until the next listed day: guest -> [space, named spot].
## Each builder names its own spots ("a", "b", ...).
const FREE_BY_DAY := {
	1: {"reginald": ["grand_hall", "a"], "zuzu": ["grand_hall", "b"], "duchess": ["dining_room", "a"], "grub": ["kitchen", "a"],
		"nibs": ["terrace", "a"], "lulu": ["terrace", "b"], "bruno": ["shore", "a"], "fennel": ["shore", "b"], "bramble": ["shore", "c"],
		"pepper": ["shore", "d"]},
	2: {"reginald": ["grand_hall", "a"], "duchess": ["dining_room", "a"], "grub": ["kitchen", "a"], "bramble": ["terrace", "c"],
		"fennel": ["terrace", "d"], "bruno": ["shore", "a"], "nibs": ["library", "a"], "zuzu": ["library", "b"], "pepper": ["gallery", "a"],
		"lulu": ["music_room", "a"]},
	3: {"reginald": ["terrace", "a"], "grub": ["kitchen", "a"], "bruno": ["shore", "a"], "nibs": ["library", "a"], "zuzu": ["library", "b"],
		"pepper": ["gallery", "a"], "lulu": ["music_room", "a"], "duchess": ["music_room", "b"], "bramble": ["conservatory", "a"],
		"fennel": ["conservatory", "b"]},
	4: {"reginald": ["terrace", "a"], "grub": ["kitchen", "a"], "bruno": ["cliff_path", "a"], "nibs": ["library", "a"], "zuzu": ["library", "b"],
		"pepper": ["gallery", "a"], "lulu": ["music_room", "a"], "duchess": ["music_room", "b"], "bramble": ["conservatory", "a"],
		"fennel": ["conservatory", "b"]},
}

const GILT := Color(0.78, 0.6, 0.26)
const SEA_LIGHT := Color(0.86, 0.92, 1.0)
const WARM := Color(1.0, 0.84, 0.6)
const LAMP := Color(1.0, 0.8, 0.55)


static func build(rid: String, k, names: Dictionary) -> void:
	k.names = names
	if rid.begins_with("bedroom_") and rid != "bedroom_wing":
		_bedroom(k, rid.substr(8))
		return
	match rid:
		"grand_hall":
			_grand_hall(k)
		"library":
			_library(k)
		"servants_passage":
			_passage(k)
		"bedroom_wing":
			_bedroom_wing(k)
		"gallery":
			_gallery(k)
		"attic":
			_attic(k)
		"dining_room":
			_dining(k)
		"kitchen":
			_kitchen(k)
		"wine_cellar":
			_cellar(k)
		"generator_room":
			_generator(k)
		"music_room":
			_music(k)
		"conservatory":
			_conservatory(k)
		"marble_bath":
			_marble_bath(k)
		"terrace":
			_terrace(k)
		"shore":
			_shore(k)
		"wreck":
			_wreck(k)
		"cliff_path":
			_cliff_path(k)
		"boathouse":
			_boathouse(k)
		"prison_yard":
			_prison_yard(k)
		"visiting_room":
			_visiting_room(k)
		_:
			k.environment("indoor")
			k.shell(8.0, 8.0, 3.4)


# =================================================================== shared helpers
static func _h(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)


## The story day this space is shown on (see the header).
static func _day(k) -> int:
	if k.has_meta("day"):
		return int(k.get_meta("day"))
	var a := MouseGuard.arg("day3d")
	if a != "":
		return int(a)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var game: Node = tree.root.get_node_or_null("Game")
		if game != null and game.get("main") != null:
			var d := Chapters.day_at(str(game.get("main").call("current_step")))
			if d > 0:
				return d
	return 6 if k.mode != "freetime" else maxi(Chapters.day_at("freetime"), 1)


## Day 6 (the body has been found): the aftershock has been through the house.
static func _after(k) -> bool:
	return _day(k) >= 6


## A pen lying on something (`pos` on the surface, `rot_y` its heading): black, with a silver clip. A chewed one has no
## clip and its end gnawed pale and splintered, the way all of Nibs's pens are (his case of old ones in the Plover Room).
static func _pen(k, parent: Node3D, pos: Vector3, rot_y: float, chewed: bool) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	parent.add_child(g)
	var r := 0.0085
	var body_m: Material = k.mat(Color(0.08, 0.08, 0.1), 0.25)
	k.cyl(r, r, 0.16, Vector3(0, r, 0), body_m, g, false, 8).rotation.x = PI / 2.0
	if not chewed:
		# a new one: black from end to end, a gold band and a gold clip
		var gold: Material = k.mat(Color(0.8, 0.62, 0.24), 0.3, 0.8)
		k.cyl(r + 0.0006, r + 0.0006, 0.008, Vector3(0, r, -0.02), gold, g, false, 8).rotation.x = PI / 2.0
		k.box(Vector3(0.0035, 0.004, 0.055), Vector3(0, 2.0 * r + 0.001, -0.05), gold, false, g)
	else:
		# gnawed: the end bitten pale and splintered, with tooth marks behind it
		var pale: Material = k.mat(Color(0.86, 0.74, 0.52), 0.95)
		k.sphere(0.012, Vector3(0, r, 0.082), pale, g, Vector3(1.05, 0.85, 2.2), 7)
		for i in 5:
			var a := float(i) * TAU / 5.0 + 0.4
			k.box(Vector3(0.0035, 0.0035, 0.022), Vector3(cos(a) * 0.01, r + sin(a) * 0.01, 0.1), pale, false, g, a)
		for i in 3:
			k.box(Vector3(0.019, 0.003, 0.0025), Vector3(0, 2.0 * r - 0.001, 0.058 + i * 0.007), k.mat(Color(0.55, 0.45, 0.3), 0.9), false, g)


## Stands this space's Free Time guests at the builder's named spots.
static func _guests(k, sid: String, at: Dictionary) -> void:
	if k.mode != "freetime":
		return
	var day := _day(k)
	var best := 0
	for d in FREE_BY_DAY.keys():
		if int(d) <= day and int(d) > best:
			best = int(d)
	if best == 0:
		best = 1
	var table: Dictionary = FREE_BY_DAY[best]
	for g in table.keys():
		var e: Array = table[g]
		if str(e[0]) == sid and at.has(str(e[1])):
			k.person(str(g), at[str(e[1])])


## Places guests without a named spot can stand during the investigation (used in order).
static func _spots(k, list: Array) -> void:
	if k.mode == "freetime":
		return
	for p in list:
		k.spots.append(p)


static func _wallpaper(k, base: Color, motif: Color, scale: float = 0.28) -> ShaderMaterial:
	return k.smat(Kit.SH_WALLPAPER, {"base": base, "motif": motif, "scale": scale})


static func _marble(k, a: Color = Color(0.9, 0.88, 0.84), c: Color = Color(0.14, 0.15, 0.17), tile: float = 0.8, checker: float = 1.0) -> ShaderMaterial:
	return k.smat(Kit.SH_MARBLE, {"col_a": a, "col_b": a.darkened(0.35), "col_c": c, "tile": tile, "checker": checker})


static func _parquet(k) -> ShaderMaterial:
	return k.wood_floor(Color(0.26, 0.14, 0.07), Color(0.46, 0.27, 0.13), 0.16)


static func _panel(k) -> ShaderMaterial:
	return k.wood_wall(Color(0.2, 0.11, 0.06), Color(0.34, 0.19, 0.1), 0.42)


static func _ceil(k) -> StandardMaterial3D:
	return k.mat(Color(0.86, 0.82, 0.74), 0.95)


## Shell options for a mansion room: papered or plain walls over dark panelling.
static func _manor(k, wall: Material, floor_m: Material = null, wain: Variant = "panel", wain_h: float = 1.05) -> Dictionary:
	var o := {"floor": floor_m if floor_m != null else _parquet(k), "wall": wall, "wain_h": wain_h, "trim": k.wood_dark, "ceiling": _ceil(k)}
	o["wain"] = _panel(k) if str(wain) == "panel" else wain
	return o


## A picture rail and a deep cornice round a rectangular room (x0..x1, z0..z1), on the walls' inner faces.
static func _mouldings(k, x0: float, z0: float, x1: float, z1: float, h: float, y: float = 0.0, rail_y: float = 2.7) -> void:
	var m: Material = k.mat(Color(0.82, 0.76, 0.62), 0.6)
	var w := x1 - x0
	var d := z1 - z0
	for e in [[Vector3((x0 + x1) / 2.0, 0, z0 + 0.015), Vector3(w, 0, 0.03)], [Vector3((x0 + x1) / 2.0, 0, z1 - 0.015), Vector3(w, 0, 0.03)],
			[Vector3(x0 + 0.015, 0, (z0 + z1) / 2.0), Vector3(0.03, 0, d - 0.06)], [Vector3(x1 - 0.015, 0, (z0 + z1) / 2.0), Vector3(0.03, 0, d - 0.06)]]:
		var c: Vector3 = e[0]
		var s: Vector3 = e[1]
		k.box(Vector3(maxf(s.x, 0.03), 0.04, maxf(s.z, 0.03)), Vector3(c.x, y + rail_y, c.z), m)
		k.box(Vector3(maxf(s.x, 0.03) * (1.0 if s.x > 0.05 else 1.0), 0.07, maxf(s.z, 0.03)) + Vector3(0.0 if s.x > 0.05 else 0.1, 0, 0.0 if s.z > 0.05 else 0.1),
			Vector3(c.x + (0.0 if s.x > 0.05 else (0.05 if c.x < (x0 + x1) / 2.0 else -0.05)), y + h - 0.16, c.z + (0.0 if s.z > 0.05 else (0.05 if c.z < (z0 + z1) / 2.0 else -0.05))), m)


## A crack running across a wall: `a` is where it starts on the wall surface, the wall faces `rot_y`, it runs `len`
## metres roughly along `dir` (in the wall plane: x along the wall, y up).
static func _crack(k, a: Vector3, rot_y: float, len: float, dir: Vector2, seed: int) -> void:
	var b := Basis(Vector3.UP, rot_y)
	var m: Material = k.mat(Color(0.12, 0.1, 0.09), 0.9)
	var p := Vector2.ZERO
	var n := maxi(3, int(len / 0.22))
	var d := dir.normalized()
	for i in n:
		var j := Vector2(-d.y, d.x) * (_h(seed * 13 + i) - 0.5) * 0.18
		var q := p + d * (len / n) + j
		k.beam(a + b * Vector3(p.x, p.y, 0.004), a + b * Vector3(q.x, q.y, 0.004), 0.0035 - 0.0015 * float(i) / n, m)
		if i % 3 == 1:
			var br := q + Vector2(d.y, -d.x).rotated(0.5) * 0.12
			k.beam(a + b * Vector3(q.x, q.y, 0.004), a + b * Vector3(br.x, br.y, 0.004), 0.003, m)
		p = q


## Lumps of fallen plaster on the floor round `c`.
static func _rubble(k, c: Vector3, n: int, r: float, seed: int, m: Material = null) -> void:
	var pm: Material = m if m != null else k.mat(Color(0.86, 0.83, 0.76), 0.95)
	for i in n:
		var a := _h(seed + i) * TAU
		var rr := r * sqrt(_h(seed * 3 + i))
		var s := 0.04 + 0.07 * _h(seed * 7 + i)
		k.box(Vector3(s * 1.4, s * 0.5, s), c + Vector3(cos(a) * rr, s * 0.25, sin(a) * rr), pm, false, null, a)


## A Snapjaw crest: a green crocodile head on a brass roundel, bolted to a wall (`pos` on the wall).
static func _crest(k, pos: Vector3, rot_y: float, s: float = 1.0) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	k.root.add_child(g)
	k.cyl(0.24 * s, 0.24 * s, 0.03, Vector3(0, 0, 0.015), k.brass, g, false, 24).rotation.x = PI / 2.0
	k.cyl(0.2 * s, 0.2 * s, 0.012, Vector3(0, 0, 0.036), k.mat(Color(0.18, 0.34, 0.2), 0.6), g, false, 24).rotation.x = PI / 2.0
	k.box(Vector3(0.22, 0.12, 0.03) * s, Vector3(0, -0.02 * s, 0.05), k.mat(Color(0.3, 0.56, 0.32), 0.6), false, g)
	for sd in [-1.0, 1.0]:
		k.sphere(0.03 * s, Vector3(sd * 0.07 * s, 0.07 * s, 0.05), k.mat(Color(0.95, 0.9, 0.6), 0.5), g, Vector3.ONE, 8)
	k.sphere(0.012 * s, Vector3(-0.07 * s, 0.07 * s, 0.075), k.glow(Color(1.0, 0.1, 0.08), 4.0), g, Vector3.ONE, 6)
	for i in 5:
		k.box(Vector3(0.02, 0.03, 0.02) * s, Vector3((-0.08 + i * 0.04) * s, -0.09 * s, 0.06), k.white, false, g)


## A rug with a fringe at both ends.
static func _rug(k, pos: Vector3, size: Vector2, col: Color, border: Color, rot_y: float = 0.0) -> void:
	k.rug(pos, size, col, border, rot_y)
	var b := Basis(Vector3.UP, rot_y)
	var fm: Material = k.mat(border.lightened(0.3), 0.95)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(size.x - 0.1, Kit.LAYER, 0.06), pos + b * Vector3(0, Kit.LAYER / 2.0, sd * (size.y / 2.0 + 0.03)), fm, false, null, rot_y)


## A small table with things on it (a vase of dried flowers and a candlestick): pos on the floor.
static func _console(k, pos: Vector3, rot_y: float, w: float = 1.1, vase: Color = Color(0.3, 0.42, 0.56)) -> Node3D:
	var g: Node3D = k.table(pos, Vector3(w, 0.82, 0.42), k.wood_mid, k.wood_dark, rot_y)
	k.cyl(0.07, 0.09, 0.26, Vector3(-w * 0.25, 0.95, 0), k.mat(vase, 0.3), g, false, 14)
	for i in 5:
		var a := i * 1.3
		k.beam(Vector3(-w * 0.25, 1.05, 0), Vector3(-w * 0.25 + cos(a) * 0.12, 1.38 + 0.06 * (i % 2), sin(a) * 0.08), 0.006, k.mat(Color(0.5, 0.42, 0.26), 0.9), g)
		k.sphere(0.03, Vector3(-w * 0.25 + cos(a) * 0.12, 1.39 + 0.06 * (i % 2), sin(a) * 0.08), k.mat(Color(0.72, 0.5, 0.36), 0.9), g, Vector3.ONE, 6)
	k.cyl(0.05, 0.07, 0.03, Vector3(w * 0.25, 0.835, 0), k.brass, g, false, 12)
	k.cyl(0.015, 0.02, 0.2, Vector3(w * 0.25, 0.95, 0), k.brass, g, false, 8)
	k.cyl(0.014, 0.014, 0.1, Vector3(w * 0.25, 1.1, 0), k.mat(Color(0.95, 0.92, 0.84), 0.6), g, false, 8)
	return g


## A guest's name card in a brass holder on the wall beside a bedroom door (`pos` on the wall).
static func _name_card(k, pos: Vector3, rot_y: float, who: String) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	k.root.add_child(g)
	k.box(Vector3(0.36, 0.14, 0.02), Vector3(0, 0, 0.01), k.brass, false, g)
	k.box(Vector3(0.32, 0.1, Kit.LAYER), Vector3(0, 0, 0.02 + Kit.LAYER / 2.0), k.paper, false, g)
	k.label(Cast.display_name(who), Vector3(0, 0, 0.026), 0.0, 26, Color(0.18, 0.1, 0.05), g, 0.0024, 0)


## A page torn out of the Ledger, tucked away by Snapjaw on Day 3 (shown from then on): anchor "ledger_page", one per
## space. wall=true: slipped behind a picture or between books, `pos` on that surface, `rot_y` the way it faces;
## wall=false: half under something on the floor.
static func _page(k, pos: Vector3, rot_y: float, wall: bool = true) -> void:
	if _day(k) < 3:
		return
	var off := Vector3(0, -0.06, 0.12) if wall else Vector3(0, 0.1, 0.05)
	var pg: Node3D = k.hotspot("ledger_page", pos, Vector3(0.34, 0.36, 0.26) if wall else Vector3(0.4, 0.3, 0.4), off, rot_y)
	var paper_m: Material = k.mat(Color(0.93, 0.89, 0.76), 0.95)
	var ink: Material = k.mat(Color(0.2, 0.18, 0.16), 0.9)
	var sheet := Node3D.new()
	if wall:
		sheet.position = Vector3(0, -0.07, 0.012)
		sheet.rotation.x = -PI / 2.0
	else:
		sheet.position = Vector3(0, 0.0, 0)
	pg.add_child(sheet)
	k.box(Vector3(0.2, 0.004, 0.26), Vector3(0, 0.002, 0), paper_m, false, sheet)
	var flap: MeshInstance3D = k.box(Vector3(0.2, 0.004, 0.1), Vector3(0, 0.026, 0.075), paper_m, false, sheet)
	flap.rotation.x = 0.45
	for i in 4:
		k.box(Vector3(0.14 - 0.03 * float(i % 2), Kit.LAYER, 0.008), Vector3(-0.01, 0.004 + Kit.LAYER / 2.0, -0.1 + i * 0.03), ink, false, sheet)


## Glimpse through an open (broken) doorway: a bit of the room beyond, self-lit.
static func _glimpse_room(k, pos: Vector3, rot_y: float, wall_m: Material, floor_m: Material, lamp: Color, energy: float = 0.5) -> void:
	k.passage_glimpse(pos + Basis(Vector3.UP, rot_y) * Vector3(0, 0, -0.21), rot_y, wall_m, floor_m, _ceil(k), lamp, 2.6, 2.4, 2.9, energy)


# =================================================================== Grand Hall
## Two storeys under one ceiling: an imperial staircase (one flight up to a half landing under the Warden's portrait,
## then two flights back) to a U-shaped upper gallery. Snapjaw's notice board by the front door.
## Anchors: desk, cabinet (the hall's porter's desk and curio cabinet), notice_board, warden_portrait,
## library_door (low on the hall side of the Library door), clock.
static func _grand_hall(k) -> void:
	var HW := 8.0
	var H := 9.4
	var Y2 := 4.6
	var YL := 2.3
	var after := _after(k)
	var ft: bool = k.mode == "freetime"
	k.bounds = Vector2(HW * 2.0, HW * 2.0)
	k.environment("indoor", Color(0.6, 0.56, 0.5), 0.46)
	var paper: Material = _wallpaper(k, Color(0.13, 0.26, 0.23), Color(0.27, 0.42, 0.33), 0.32)
	var o := _manor(k, paper, null, "panel", 1.25)
	var floor_m: Material = _marble(k, Color(0.88, 0.86, 0.8), Color(0.12, 0.13, 0.15), 0.9, 1.0)
	k.slab(-HW, -HW, HW, HW, 0.0, floor_m)
	k.slab(-HW, -HW, HW, HW, H + 0.12, _ceil(k), 0.12, false, "ceiling")
	# walls; the Library door upstairs on the west wall stands broken open on Day 6, so it needs a real hole
	var lib_z := 2.0
	k.wall_run(Vector2(-HW, -HW), Vector2(HW, -HW), 0.0, H, o)
	k.wall_run(Vector2(HW, -HW), Vector2(HW, HW), 0.0, H, o)
	k.wall_run(Vector2(HW, HW), Vector2(-HW, HW), 0.0, H, o)
	var gaps: Array = [[HW - lib_z - 0.5, HW - lib_z + 0.5, Y2, Y2 + 2.1]] if after else []
	k.wall_run(Vector2(-HW, HW), Vector2(-HW, -HW), 0.0, H, o, gaps)
	# coffered ceiling beams and a ceiling rose
	for i in 5:
		var z := -6.4 + i * 3.2
		k.box(Vector3(HW * 2.0, 0.26, 0.22), Vector3(0, H - 0.13, z), k.mat(Color(0.8, 0.74, 0.62), 0.8))
	for x in [-4.8, 0.0, 4.8]:
		k.box(Vector3(0.22, 0.26, HW * 2.0 - 0.02), Vector3(x, H - 0.13 - Kit.LAYER, 0), k.mat(Color(0.8, 0.74, 0.62), 0.8))
	# upper floor: west and east balconies, the south balcony, the half landing; their undersides are panelled
	var bal_m: Material = _parquet(k)
	k.slab(-HW, -0.6, -3.4, HW, Y2, bal_m, 0.3)
	k.slab(3.4, -0.6, HW, HW, Y2, bal_m, 0.3)
	k.slab(-3.4, 5.6, 3.4, HW, Y2, bal_m, 0.3)
	k.slab(-5.2, -HW, 5.2, -5.4, YL, bal_m, 0.3)
	var trim_m: Material = k.wood_dark
	# fascia boards along the balcony edges, just proud of the floor edge
	var ft_y := -0.18 - Kit.LAYER
	k.box(Vector3(0.08, 0.36, 6.2), Vector3(-3.4 + 0.04, Y2 + ft_y, 2.5), trim_m)
	k.box(Vector3(0.08, 0.36, 6.2), Vector3(3.4 - 0.04, Y2 + ft_y, 2.5), trim_m)
	k.box(Vector3(6.64, 0.36, 0.08), Vector3(0, Y2 + ft_y, 5.6 - 0.04 - Kit.LAYER), trim_m)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(1.76, 0.36, 0.08), Vector3(sd * 2.5, YL + ft_y, -5.4 + 0.04 + Kit.LAYER), trim_m)
	# the staircase: centre flight, two return flights
	var tread: Material = k.wood_floor(Color(0.3, 0.16, 0.08), Color(0.5, 0.3, 0.15), 0.2)
	k.stairs(Vector3(0, 0, -0.6), Vector3(0, YL, -5.4), 3.2, {"mat": tread, "rail": "none"})
	k.stairs(Vector3(-4.3, YL, -5.4), Vector3(-4.3, Y2, -0.6), 1.8, {"mat": tread, "rail": "none", "solid": false})
	k.stairs(Vector3(4.3, YL, -5.4), Vector3(4.3, Y2, -0.6), 1.8, {"mat": tread, "rail": "none", "solid": false})
	# a runner up the middle of the centre flight
	var run: MeshInstance3D = k.box(Vector3(1.6, 0.02, 5.4), Vector3(0, YL / 2.0 + 0.1, -3.0), k.mat(Color(0.45, 0.08, 0.1), 0.9))
	run.rotation.x = atan2(YL, 4.8)
	k.box(Vector3(1.6, 0.012, 1.2), Vector3(0, 0.006, 0.0), k.mat(Color(0.45, 0.08, 0.1), 0.9))
	# balustrades
	var bm: Material = k.wood_dark
	k.balustrade(Vector3(-1.62, 0, -0.6), Vector3(-1.62, YL, -5.4), 1.0, bm)
	k.balustrade(Vector3(1.62, 0, -0.6), Vector3(1.62, YL, -5.4), 1.0, bm)
	k.balustrade(Vector3(-3.42, YL, -5.4), Vector3(-3.42, Y2, -0.6), 1.0, bm)
	k.balustrade(Vector3(3.42, YL, -5.4), Vector3(3.42, Y2, -0.6), 1.0, bm)
	k.balustrade(Vector3(-5.18, YL, -HW + 0.05), Vector3(-5.18, YL, -5.4), 1.0, bm)
	k.balustrade(Vector3(5.18, YL, -HW + 0.05), Vector3(5.18, YL, -5.4), 1.0, bm)
	k.balustrade(Vector3(-5.18, YL, -5.4), Vector3(-5.18, Y2, -0.6), 1.0, bm)
	k.balustrade(Vector3(5.18, YL, -5.4), Vector3(5.18, Y2, -0.6), 1.0, bm)
	k.balustrade(Vector3(-3.4, YL, -5.42), Vector3(-1.62, YL, -5.42), 1.0, bm, 0.16, false)
	k.balustrade(Vector3(1.62, YL, -5.42), Vector3(3.4, YL, -5.42), 1.0, bm, 0.16, false)
	k.balustrade(Vector3(-3.42, Y2, -0.6), Vector3(-3.42, Y2, 5.62), 1.0, bm)
	k.balustrade(Vector3(3.42, Y2, -0.6), Vector3(3.42, Y2, 5.62), 1.0, bm)
	k.balustrade(Vector3(-3.42, Y2, 5.62), Vector3(3.42, Y2, 5.62), 1.0, bm, 0.16, false)
	k.balustrade(Vector3(-HW + 0.05, Y2, -0.58), Vector3(-5.18, Y2, -0.58), 1.0, bm, 0.16, false)
	k.balustrade(Vector3(5.18, Y2, -0.58), Vector3(HW - 0.05, Y2, -0.58), 1.0, bm, 0.16, false)
	# under the half landing: panelled fronts and sides, with a little cupboard door
	var under: Material = _panel(k)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(3.6, YL - 0.3, 0.12), Vector3(sd * 3.4, (YL - 0.3) / 2.0, -5.46), under, true)
		k.box(Vector3(0.12, YL - 0.3, 2.46), Vector3(sd * 5.14, (YL - 0.3) / 2.0, -6.77), under, true)
	k.box(Vector3(0.8, 1.6, 0.03), Vector3(2.5, 0.85, -5.385), k.wood_mid)
	k.sphere(0.03, Vector3(2.8, 0.9, -5.36), k.brass)
	k.note("Cupboard under the stairs", "Brooms, a broken umbrella and a very old smell. Nothing else.", Vector3(2.5, 0, -5.2), Vector3(0.9, 1.7, 0.4), Vector3(0, 0.85, 0))
	# the Warden's portrait over the half landing, lit by two sconces
	k.painting(Vector3(0, YL + 3.0, -HW), 0.0, Vector2(2.0, 2.6), "warden", 0)
	k.hotspot("warden_portrait", Vector3(0, YL + 1.7, -HW + 0.4), Vector3(2.4, 3.4, 0.8), Vector3(0, 1.7, 0))
	k.sconce(Vector3(-1.7, YL + 2.6, -HW), 0.0, LAMP, 0.9, 6.0)
	k.sconce(Vector3(1.7, YL + 2.6, -HW), 0.0, LAMP, 0.9, 6.0)
	_crest(k, Vector3(0, YL + 4.9, -HW), 0.0, 1.6)
	k.longcase_clock(Vector3(-4.6, YL, -HW), 0.0, 3.0, 10.0)
	k.hotspot("clock", Vector3(-4.6, YL, -HW + 0.2), Vector3(0.7, 2.4, 0.6))
	k.plant(Vector3(4.6, YL, -HW + 0.6), 1.1)
	# the chandelier hangs in the open middle of the hall
	k.chandelier(Vector3(0, 6.6, 2.3), H, WARM, 2.6, 16.0, true, 12, 1.5)
	# ---- ground floor, south: the front door (Snapjaw has locked it for good) and the notice board
	var fd := Node3D.new()
	fd.position = Vector3(0, 0, HW)
	fd.rotation.y = PI
	k.root.add_child(fd)
	k.box(Vector3(2.4, 3.1, 0.1), Vector3(0, 1.55, 0.05), k.wood_dark, false, fd)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.98, 2.8, 0.08), Vector3(sd * 0.5, 1.4, 0.13), k.mat(Color(0.3, 0.16, 0.08), 0.6), false, fd)
		for yy in [0.7, 1.9]:
			k.box(Vector3(0.66, 0.8, 0.02), Vector3(sd * 0.5, yy, 0.18), k.wood_dark, false, fd)
		k.sphere(0.05, Vector3(sd * 0.12, 1.3, 0.2), k.brass, fd)
	k.box(Vector3(2.0, 0.16, 0.16), Vector3(0, 1.3, 0.25), k.steel, false, fd)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.2, 0.3, 0.12), Vector3(sd * 0.9, 1.3, 0.25), k.steel, false, fd)
	k.box(Vector3(0.24, 0.3, 0.14), Vector3(0, 1.3, 0.38), k.mat(Color(0.18, 0.34, 0.2), 0.5), false, fd)
	k.box(Vector3(2.4, 0.5, 0.06), Vector3(0, 3.35, 0.05), k.wood_dark, false, fd)
	k.vista_window(Vector3(0, 3.35, HW - 0.082), PI, Vector2(2.0, 0.3), {"curtains": null, "sill": false, "prison_at": 9.0})
	k.note("Front door", "Bolted, barred and fitted with a crocodile padlock. The Warden doesn't want anyone leaving by the front.", Vector3(0, 0, HW - 0.3), Vector3(2.4, 2.8, 0.6), Vector3(0, 1.4, 0))
	var sheets := [[-0.75, 0.35, 0.5, 0.62, Color(0.95, 0.92, 0.84), 7], [-0.1, 0.38, 0.46, 0.56, Color(0.98, 0.95, 0.7), 6],
		[0.55, 0.32, 0.56, 0.66, Color(0.92, 0.94, 0.98), 8], [-0.7, -0.35, 0.44, 0.5, Color(0.98, 0.86, 0.82), 5],
		[0.0, -0.32, 0.4, 0.48, Color(0.95, 0.92, 0.84), 5], [0.62, -0.36, 0.42, 0.44, Color(0.85, 0.95, 0.85), 4]]
	k.notice_board(Vector3(4.2, 1.55, HW), PI, Vector2(2.1, 1.4), sheets, "NOTICES")
	k.hotspot("notice_board", Vector3(4.2, 0.7, HW - 0.25), Vector3(2.3, 1.7, 0.5), Vector3(0, 0.85, 0))
	_crest(k, Vector3(4.2, 2.75, HW), PI, 0.9)
	k.cctv(Vector3(-2.0, 3.6, HW), PI, -0.4)
	k.cctv(Vector3(HW, 3.6, -6.0), -PI / 2.0, 0.6)
	# ground floor seating, a hall table (the desk anchor) and a curio cabinet
	var velvet: Material = k.mat(Color(0.4, 0.08, 0.1), 0.85)
	k.sofa(Vector3(-6.9, 0, 0.2), PI / 2.0, velvet, 2.2)
	k.armchair(Vector3(-5.4, 0, -1.8), 0.4, velvet)
	k.table(Vector3(-5.7, 0, 0.2), Vector3(0.7, 0.45, 1.1), k.wood_mid, k.wood_dark)
	k.cyl(0.08, 0.06, 0.05, Vector3(-5.7, 0.48, 0.4), k.mat(Color(0.9, 0.88, 0.8), 0.3), null, false, 12)
	var desk: Node3D = k.hotspot("desk", Vector3(-6.8, 0, 6.2), Vector3(1.8, 1.2, 1.0), Vector3.ZERO, PI / 2.0)
	k.box(Vector3(1.6, 0.78, 0.7), Vector3(0, 0.39, 0), k.wood_mid, true, desk)
	k.box(Vector3(1.7, 0.05, 0.78), Vector3(0, 0.805, 0), k.wood_light, false, desk)
	k.box(Vector3(0.5, 0.03, 0.34), Vector3(-0.3, 0.845, 0.05), k.mat(Color(0.3, 0.1, 0.1), 0.8), false, desk)
	k.box(Vector3(0.46, 0.02, 0.3), Vector3(-0.3, 0.87, 0.05), k.paper, false, desk)
	k.cyl(0.06, 0.07, 0.03, Vector3(0.45, 0.845, 0.0), k.brass, desk, false, 12)
	k.sphere(0.05, Vector3(0.45, 0.88, 0.0), k.brass, desk, Vector3(1, 0.7, 1))
	k.cyl(0.03, 0.03, 0.12, Vector3(0.15, 0.89, -0.15), k.mat(Color(0.1, 0.1, 0.12), 0.3), desk, false, 10)
	var cab: Node3D = k.hotspot("cabinet", Vector3(HW - 0.35, 0, 6.2), Vector3(0.9, 2.1, 1.6), Vector3.ZERO, -PI / 2.0)
	k.box(Vector3(1.3, 1.9, 0.45), Vector3(0, 0.95, -0.1), k.wood_dark, true, cab)
	k.box(Vector3(1.16, 1.5, 0.02), Vector3(0, 1.1, 0.135), k.mat(Color(0.7, 0.82, 0.86), 0.05, 0.2), false, cab)
	for i in 3:
		k.box(Vector3(1.16, 0.02, 0.36), Vector3(0, 0.55 + i * 0.5, -0.1), k.wood_mid, false, cab)
	for i in 4:
		k.sphere(0.06, Vector3(-0.4 + i * 0.26, 1.13, -0.08), k.mat([Color(0.85, 0.75, 0.3), Color(0.7, 0.7, 0.75), Color(0.5, 0.2, 0.2), Color(0.2, 0.4, 0.5)][i], 0.3, 0.6), cab, Vector3.ONE, 10)
		k.box(Vector3(0.08, 0.18, 0.06), Vector3(-0.4 + i * 0.26, 0.65, -0.08), k.mat(Color(0.75, 0.7, 0.6), 0.6), false, cab)
	k.box(Vector3(0.5, 0.08, 0.2), Vector3(0, 1.62, -0.08), k.mat(Color(0.6, 0.5, 0.3), 0.4, 0.8), false, cab)
	# side tables and plants by the doors, portraits
	k.plant(Vector3(-HW + 0.6, 0, -5.9), 1.2)
	k.plant(Vector3(HW - 0.6, 0, -6.9), 1.2)
	k.plant(Vector3(-1.8, 0, HW - 0.6), 1.0)
	k.plant(Vector3(1.8, 0, HW - 0.6), 1.0)
	_console(k, Vector3(HW - 0.3, 0, 0.3), -PI / 2.0, 1.2)
	k.painting(Vector3(-HW, 2.4, -1.3), PI / 2.0, Vector2(0.9, 1.2), "portrait", 3)
	_page(k, Vector3(-HW, 1.8, -1.12), PI / 2.0)
	k.painting(Vector3(HW, 2.4, -1.3), -PI / 2.0, Vector2(0.9, 1.2), "portrait", 4)
	k.painting(Vector3(-HW, 2.4, 0.9 + 4.6), PI / 2.0, Vector2(1.1, 0.8), "sea", 1)
	k.painting(Vector3(HW, Y2 + 1.9, -0.2 + 0.0), -PI / 2.0, Vector2(1.2, 0.9), "still", 2)
	k.painting(Vector3(-HW, Y2 + 1.9, -0.2), PI / 2.0, Vector2(0.8, 1.1), "portrait", 7)
	_rug(k, Vector3(0, 0, 3.2), Vector2(5.0, 3.4), Color(0.36, 0.08, 0.1), GILT)
	# sconces by the doors downstairs and upstairs
	for sd in [-1.0, 1.0]:
		k.sconce(Vector3(sd * HW, 2.4, 1.4), -sd * PI / 2.0, LAMP, 0.75, 6.0)
		k.sconce(Vector3(sd * HW, 2.4, -5.6), -sd * PI / 2.0, LAMP, 0.7, 6.0)
		k.sconce(Vector3(sd * HW, Y2 + 2.3, 3.6), -sd * PI / 2.0, LAMP, 0.75, 6.0)
	k.sconce(Vector3(-2.6, Y2 + 2.3, HW), PI, LAMP, 0.7, 6.0)
	for x in [-5.6, 5.6]:
		k.vista_window(Vector3(x, Y2 + 1.7, HW - 0.002), PI, Vector2(1.3, 2.1), {"prison_at": 0.5 if x > 0.0 else 9.0, "light": 0.55})
	# earthquake damage: cracks up the walls, a slipped picture, a few lumps of plaster
	_crack(k, Vector3(-HW, 6.8, -3.0), PI / 2.0, 2.6, Vector2(0.5, -1.0), 3)
	_crack(k, Vector3(HW, 8.4, 4.0), -PI / 2.0, 3.2, Vector2(-0.3, -1.0), 7)
	_crack(k, Vector3(3.0, 8.9, -HW), 0.0, 1.8, Vector2(0.8, -0.6), 11)
	_rubble(k, Vector3(6.6, 0, 2.6), 6, 0.4, 5)
	# the Library door upstairs (west) with scratch marks low on its frame; the Gallery (east) and the Bedroom Wing (south)
	if after:
		k.door("library", "", Vector3(-HW, Y2, lib_z), PI / 2.0, {"broken": true, "h": 2.1})
		_glimpse_room(k, Vector3(-HW, Y2, lib_z), PI / 2.0, k.wood_wall(Color(0.2, 0.11, 0.06), Color(0.34, 0.19, 0.1), 0.42), _parquet(k), WARM, 0.45)
	else:
		k.door("library", "", Vector3(-HW, Y2, lib_z), PI / 2.0)
	var scr: Node3D = k.hotspot("library_door", Vector3(-HW, Y2, lib_z + 0.95), Vector3(0.5, 0.7, 0.3), Vector3(0, 0.35, 0.14), PI / 2.0)
	var scratch: Material = k.mat(Color(0.5, 0.38, 0.26), 0.9)
	for i in 5:
		var s: MeshInstance3D = k.box(Vector3(0.012, 0.16 + 0.04 * (i % 2), 0.006), Vector3(-0.12 + i * 0.05, 0.22 + 0.02 * (i % 3), 0.003), scratch, false, scr)
		s.rotation.z = 0.25
	k.door("gallery", "", Vector3(HW, Y2, lib_z), -PI / 2.0)
	k.door("bedroom_wing", "", Vector3(0, Y2, HW), PI)
	k.door("dining_room", "", Vector3(-HW, 0, 3.4), PI / 2.0, {"h": 2.4, "w": 1.2})
	k.door("kitchen", "", Vector3(-HW, 0, -4.0), PI / 2.0, {"mat": k.mat(Color(0.12, 0.3, 0.16), 0.9), "panels": false})
	k.door("music_room", "", Vector3(HW, 0, 3.4), -PI / 2.0, {"h": 2.4, "w": 1.2})
	k.door("marble_bath", "", Vector3(HW, 0, -4.0), -PI / 2.0)
	k.door("terrace", "", Vector3(-6.6, 0, -HW), 0.0, {"h": 2.4, "w": 1.2})
	k.vista_window(Vector3(-4.0, 1.9, -HW + 0.002), 0.0, Vector2(1.0, 2.0), {"prison_at": 0.2, "light": 0.5, "curtains": Color(0.4, 0.09, 0.1)})
	if after:
		for p in [Vector3(-2.0, 0, 3.0), Vector3(2.5, 0, -0.2), Vector3(-5.0, Y2, 3.0), Vector3(0, YL, -6.6)]:
			k.dust(p + Vector3(0, 0.016, 0), Vector2(3.0, 2.4), 0.5)
		_rubble(k, Vector3(-6.4, Y2, 1.0), 5, 0.35, 9)
	_spots(k, [Vector3(-2.4, 0, 3.0), Vector3(2.4, 0, 3.0), Vector3(-5.8, Y2, 3.6), Vector3(5.8, Y2, 3.6), Vector3(0, 0, 6.0)])
	_guests(k, "grand_hall", {"a": Vector3(-1.6, YL, -6.9), "b": Vector3(-5.9, Y2, 4.4)})
	k.spawn = Vector3(0, 0, 5.6)
	k.look = Vector3(0, 2.6, -6.0)
	if not ft:
		k.spawn = Vector3(0, 0, 5.6)


# =================================================================== Library
## A tall room lined with bookcases. Nibs's desk faces the tallest one, which is braced to the wall under the cornice.
## On the far (east) wall: a bookcase, the dumbwaiter hatch with a side table beside it, and a tapestry that hides a
## narrow servants' door. Day 6: the door broken in, the bookcase down across the desk, books over the far floor,
## white dust everywhere with a dragged line from the tapestry to the side table and back.
## Anchors: bookcase, wall_brace, desk, blotter, body (Day 6), side_table, hatch, floor_pen (Day 6), tapestry (link door to
## the passage), dust_trail (Day 6), door, typewriter, fireplace, books_floor (Day 6).
static func _library(k) -> void:
	var W := 10.0
	var D := 8.0
	var H := 4.6
	var after := _after(k)
	var day := _day(k)
	k.environment("indoor", Color(0.62, 0.55, 0.48), 0.46)
	var paper: Material = _wallpaper(k, Color(0.12, 0.2, 0.17), Color(0.22, 0.3, 0.24), 0.26)
	var o := _manor(k, paper, null, "panel", 1.05)
	var door_x := -3.0
	k.slab(-W / 2.0, -D / 2.0, W / 2.0, D / 2.0, 0.0, _parquet(k))
	k.slab(-W / 2.0, -D / 2.0, W / 2.0, D / 2.0, H + 0.12, _ceil(k), 0.12, false, "ceiling")
	k.bounds = Vector2(W, D)
	k.wall_run(Vector2(-W / 2.0, -D / 2.0), Vector2(W / 2.0, -D / 2.0), 0.0, H, o)
	k.wall_run(Vector2(W / 2.0, -D / 2.0), Vector2(W / 2.0, D / 2.0), 0.0, H, o)
	k.wall_run(Vector2(-W / 2.0, D / 2.0), Vector2(-W / 2.0, -D / 2.0), 0.0, H, o)
	var sgaps: Array = [[W / 2.0 - door_x - 0.5, W / 2.0 - door_x + 0.5, 0.0, 2.1]] if after else []
	k.wall_run(Vector2(W / 2.0, D / 2.0), Vector2(-W / 2.0, D / 2.0), 0.0, H, o, sgaps)
	_mouldings(k, -W / 2.0, -D / 2.0, W / 2.0, D / 2.0, H, 0.0, 3.62)
	# the deep cornice ledge along the north wall, above the bookcases (screws lie along its top on Day 6)
	k.box(Vector3(W - 0.02, 0.1, 0.22), Vector3(0, 3.66, -D / 2.0 + 0.11), k.wood_dark)
	k.box(Vector3(W - 0.02, 0.06, 0.16), Vector3(0, 3.58, -D / 2.0 + 0.08), k.wood_dark)
	# ---- north wall: two bookcases either side of the tall one
	var bc_h := 3.3
	k.bookcase(Vector3(-3.6, 0, -D / 2.0), 0.0, Vector3(1.7, bc_h, 0.42), 11)
	k.bookcase(Vector3(2.5, 0, -D / 2.0), 0.0, Vector3(1.7, bc_h, 0.42), 12)
	k.bookcase(Vector3(4.15, 0, -D / 2.0), 0.0, Vector3(1.3, bc_h, 0.42), 13)
	# the tall bookcase behind the desk, and its iron brace under the cornice
	var tall_x := -0.5
	var tall_w := 1.5
	var bc_d := 0.45
	var brace_m: Material = k.mat(Color(0.2, 0.2, 0.22), 0.5, 0.6)
	var bk: Node3D = k.hotspot("bookcase", Vector3(tall_x, 0, -D / 2.0 + 0.55), Vector3(tall_w + 0.4, 1.6, 0.9), Vector3(0, 0.8, 0))
	if not after:
		k.bookcase(Vector3(tall_x, 0, -D / 2.0), 0.0, Vector3(tall_w, bc_h, bc_d), 14)
		for sd in [-1.0, 1.0]:
			var bx: float = tall_x + sd * (tall_w / 2.0 + 0.05)
			k.box(Vector3(0.1, 0.06, 0.012), Vector3(bx, bc_h - 0.15, -D / 2.0 + 0.006), brace_m)
			k.box(Vector3(0.012, 0.06, 0.32), Vector3(tall_x + sd * (tall_w / 2.0 + 0.006), bc_h - 0.15, -D / 2.0 + 0.16), brace_m)
			k.cyl(0.012, 0.012, 0.01, Vector3(bx + sd * 0.02, bc_h - 0.15, -D / 2.0 + 0.014), k.steel, null, false, 8).rotation.x = PI / 2.0
	else:
		# walked a foot forward, then over: it lies across the desk at about 46 degrees
		var piv := Node3D.new()
		piv.position = Vector3(tall_x, 0, -D / 2.0 + bc_d + 0.3)
		piv.rotation.x = 0.8
		k.root.add_child(piv)
		k.bookcase(Vector3(0, 0, -bc_d), 0.0, Vector3(tall_w, bc_h, bc_d), 14, piv, null, 0.06, false)
		for sd in [-1.0, 1.0]:
			k.box(Vector3(0.012, 0.06, 0.32), Vector3(sd * (tall_w / 2.0 + 0.006), bc_h - 0.15, -bc_d + 0.16), brace_m, false, piv)
		k.blocker(Vector3(tall_w, 1.2, 1.6), Vector3(tall_x, 0.6, -D / 2.0 + 1.3))
		# scrape marks where the base walked forward
		for sd in [-0.65, 0.65]:
			k.box(Vector3(0.05, Kit.LAYER, 0.34), Vector3(tall_x + sd, Kit.LAYER / 2.0, -D / 2.0 + bc_d + 0.15), k.mat(Color(0.62, 0.46, 0.3), 0.9))
		# two clean screw holes in the wall where the brace's wall plates were
		for sd in [-1.0, 1.0]:
			var hx: float = tall_x + sd * (tall_w / 2.0 + 0.07)
			k.cyl(0.012, 0.012, 0.01, Vector3(hx, bc_h - 0.15, -D / 2.0 + 0.004), k.black, null, false, 8).rotation.x = PI / 2.0
			k.box(Vector3(0.1, 0.06, 0.004), Vector3(tall_x + sd * (tall_w / 2.0 + 0.05), bc_h - 0.15, -D / 2.0 + 0.002), k.mat(Color(0.7, 0.62, 0.5), 0.9))
		# books that slid off the shelves as it came down
		for i in 26:
			var p := Vector3(tall_x - 1.2 + 2.4 * _h(i + 40), 0, -D / 2.0 + 0.5 + 2.6 * _h(i + 70))
			if absf(p.x - tall_x) < 1.0 and p.z > -D / 2.0 + 1.2 and p.z < -D / 2.0 + 2.9:
				continue
			k.box(Vector3(0.16, 0.035, 0.22), p + Vector3(0, 0.018 + Kit.LAYER * (i % 3), 0), k.mat([Color(0.45, 0.1, 0.12), Color(0.14, 0.26, 0.4), Color(0.62, 0.5, 0.24), Color(0.18, 0.34, 0.24)][i % 4], 0.8), false, null, _h(i) * TAU)
	var wb: Node3D = k.hotspot("wall_brace", Vector3(tall_x + tall_w / 2.0 + 0.25, bc_h - 0.15, -D / 2.0), Vector3(0.6, 1.0, 0.4), Vector3(0, 0.15, 0.2))
	if wb and after:
		# up on the cornice ledge, out of sight from the floor: the brace's screws laid in a row, under the white dust
		for i in 6:
			var sc: MeshInstance3D = k.cyl(0.006, 0.006, 0.05, Vector3(-0.35 + i * 0.06, 3.71 - (bc_h - 0.15) + 0.006, 0.1), k.steel, wb, false, 6)
			sc.rotation.x = PI / 2.0
		k.dust(Vector3(-0.2, 3.71 - (bc_h - 0.15) + 0.014, 0.11), Vector2(0.5, 0.18), 0.6, wb)
	# ---- the desk, facing the tall bookcase, and its chair
	var desk_z := -D / 2.0 + bc_d + 1.15
	var dk: Node3D = k.hotspot("desk", Vector3(tall_x + 0.75, 0, desk_z), Vector3(0.8, 1.2, 1.1), Vector3(0, 0.6, 0))
	var desk_g := Node3D.new()
	desk_g.position = Vector3(tall_x, 0, desk_z)
	k.root.add_child(desk_g)
	k.box(Vector3(2.0, 0.05, 0.8), Vector3(0, 0.765, 0), k.mat(Color(0.3, 0.16, 0.08), 0.4), false, desk_g)
	k.box(Vector3(1.84, 0.012, 0.66), Vector3(0, 0.796, 0), k.mat(Color(0.18, 0.32, 0.22), 0.9), false, desk_g)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.5, 0.72, 0.72), Vector3(sd * 0.72, 0.36, 0), k.mat(Color(0.3, 0.16, 0.08), 0.4), false, desk_g)
		for i in 3:
			k.box(Vector3(0.42, 0.18, 0.02), Vector3(sd * 0.72, 0.15 + i * 0.22, 0.37), k.wood_dark, false, desk_g)
			k.sphere(0.018, Vector3(sd * 0.72, 0.15 + i * 0.22, 0.385), k.brass, desk_g, Vector3.ONE, 6)
	k.box(Vector3(0.9, 0.12, 0.02), Vector3(0, 0.66, -0.37), k.wood_dark, false, desk_g)
	k.blocker(Vector3(2.0, 0.8, 0.8), Vector3(tall_x, 0.4, desk_z))
	# on the desk: the blotter (west end), papers and an inkstand (east end), a lamp
	var bl: Node3D = k.hotspot("blotter", Vector3(tall_x - 0.7, 0.8, desk_z + 0.05), Vector3(0.6, 0.35, 0.55), Vector3(0, 0.12, 0))
	k.box(Vector3(0.5, 0.012, 0.36), Vector3(0, 0.006, 0), k.mat(Color(0.86, 0.86, 0.8), 0.95), false, bl)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.06, 0.02, 0.38), Vector3(sd * 0.25, 0.01, 0), k.mat(Color(0.3, 0.12, 0.1), 0.6), false, bl)
	for i in 5:
		k.box(Vector3(0.22 + 0.06 * (i % 2), Kit.LAYER, 0.008), Vector3(-0.04, 0.012 + Kit.LAYER, -0.12 + i * 0.06), k.mat(Color(0.25, 0.3, 0.5), 0.9), false, bl, 0.05)
	for i in 4:
		k.box(Vector3(0.21, 0.004 + 0.002 * i, 0.29), Vector3(0.0, 0.8 + 0.006 * i, 0.04 - 0.02 * i), k.paper, false, dk, 0.1 * (i - 1.5))
	k.box(Vector3(0.24, 0.04, 0.12), Vector3(0.0, 0.82, -0.25), k.brass, false, dk)
	for sd in [-0.06, 0.06]:
		k.cyl(0.025, 0.028, 0.05, Vector3(sd, 0.865, -0.25), k.mat(Color(0.08, 0.1, 0.2), 0.1), dk, false, 10)
	k.desk_lamp(Vector3(tall_x + 0.85, 0.79, desk_z - 0.22), PI, null, 0.7)
	var chair_z := desk_z + 0.85
	if not after:
		k.chair(Vector3(tall_x, 0, chair_z), PI, k.mat(Color(0.18, 0.3, 0.22), 0.85), k.wood_dark)
	else:
		# Nibs, slumped forward over the desk, one arm out under the fallen bookcase (cartoon, nothing graphic)
		k.chair(Vector3(tall_x - 0.05, 0, chair_z + 0.05), PI + 0.12, k.mat(Color(0.18, 0.3, 0.22), 0.85), k.wood_dark)
		var bd: Node3D = k.hotspot("body", Vector3(tall_x, 0, chair_z - 0.1), Vector3(0.9, 1.3, 1.0), Vector3(0, 0.65, 0.1))
		var coat: Material = k.mat(Color(0.92, 0.92, 0.9), 0.85)
		var fur: Material = k.mat(Color(0.55, 0.42, 0.3), 0.85)
		var cloth: Material = k.mat(Color(0.25, 0.25, 0.3), 0.8)
		# sitting, hips on the chair, legs under the desk
		k.box(Vector3(0.36, 0.16, 0.34), Vector3(0, 0.56, 0.1), cloth, false, bd)
		for sx in [-0.1, 0.1]:
			k.box(Vector3(0.13, 0.13, 0.38), Vector3(sx, 0.52, -0.2), cloth, false, bd)
			k.box(Vector3(0.12, 0.4, 0.12), Vector3(sx, 0.26, -0.36), cloth, false, bd)
			k.box(Vector3(0.12, 0.05, 0.2), Vector3(sx, 0.025, -0.4), k.mat(Color(0.2, 0.14, 0.1), 0.6), false, bd)
		# slumped forward from the waist, his head on the desk turned to the wall
		var tp := Node3D.new()
		tp.position = Vector3(0, 0.62, 0.12)
		tp.rotation.x = -1.0
		bd.add_child(tp)
		k.box(Vector3(0.44, 0.5, 0.26), Vector3(0, 0.25, 0), coat, false, tp)
		k.sphere(0.2, Vector3(0, 0.48, 0), coat, tp, Vector3(1.1, 0.5, 0.7), 12)
		k.box(Vector3(0.46, 0.3, 0.04), Vector3(0, 0.05, 0.13), coat, false, tp)
		k.sphere(0.17, Vector3(0.06, 0.93, -0.5), fur, bd, Vector3(1.0, 0.82, 1.25), 14)
		k.sphere(0.12, Vector3(0.06, 0.9, -0.7), k.mat(Color(0.6, 0.47, 0.34), 0.85), bd, Vector3(1.0, 0.75, 1.1), 12)
		for sz in [-0.42, -0.58]:
			k.sphere(0.045, Vector3(0.12, 1.06, sz), fur, bd, Vector3(1, 0.8, 1), 8)
		# one arm out across the desk under the fallen case, the other hanging; his spectacles knocked off on the blotter
		k.beam(Vector3(0.2, 0.9, -0.3), Vector3(0.36, 0.84, -0.95), 0.05, coat, bd)
		k.sphere(0.055, Vector3(0.37, 0.835, -1.0), fur, bd, Vector3(1.2, 0.6, 1.0), 8)
		k.beam(Vector3(-0.22, 0.88, -0.28), Vector3(-0.3, 0.46, -0.22), 0.05, coat, bd)
		k.sphere(0.05, Vector3(-0.31, 0.42, -0.22), fur, bd, Vector3(1.0, 1.0, 1.0), 8)
		for sx in [-0.035, 0.035]:
			k.torus(0.022, 0.03, Vector3(-0.52 + sx, 0.8, -0.72), k.brass, bd, Vector3.ZERO)
	# ---- far (east) wall: a bookcase, the dumbwaiter hatch, the side table, the tapestry
	k.bookcase(Vector3(W / 2.0, 0, -2.8), -PI / 2.0, Vector3(1.6, bc_h, 0.42), 15)
	var hatch_z := -1.05
	# set out from the wall by the depth of the wainscot, so the panelling never shows through the opening
	var hp := Vector3(W / 2.0 - 0.045, 0.85, hatch_z)
	var hg: Node3D = k.hotspot("hatch", Vector3(W / 2.0 - 0.02, 0.85, hatch_z), Vector3(0.5, 0.8, 0.9), Vector3(0.22, 0.4, 0), -PI / 2.0)
	var hb := Node3D.new()
	hb.position = hp
	hb.rotation.y = -PI / 2.0
	k.root.add_child(hb)
	# (the frame reaches back to the wall, 0.045 behind the hatch's own plane)
	k.box(Vector3(0.84, 0.1, 0.105), Vector3(0, -0.05, 0.0075), k.wood_dark, false, hb)
	k.box(Vector3(0.84, 0.1, 0.105), Vector3(0, 0.73, 0.0075), k.wood_dark, false, hb)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.1, 0.68, 0.105), Vector3(sd * 0.37, 0.34, 0.0075), k.wood_dark, false, hb)
	k.box(Vector3(0.66, 0.02, 0.16), Vector3(0, -0.0, 0.09), k.wood_mid, false, hb)
	var crack := 0.2 if after and str(k.get_meta("photo_hatch", "crack")) == "crack" else 0.0
	k.quad(Vector2(0.64, 0.66), Vector3(0, 0.34, 0.004), Kit.flat(Color(0.012, 0.01, 0.008)), hb)
	var shutter: MeshInstance3D = k.box(Vector3(0.62, 0.66 - crack, 0.025), Vector3(0, 0.34 + crack / 2.0, 0.035), k.mat(Color(0.36, 0.2, 0.1), 0.6), false, hb)
	shutter.name = "shutter"
	k.box(Vector3(0.14, 0.03, 0.03), Vector3(0, 0.05 + crack, 0.06), k.brass, false, hb)
	if after:
		# the car is up here: the edge of the tray and the belly of the white pot show under the shutter
		k.box(Vector3(0.5, 0.02, 0.006), Vector3(0, 0.03, 0.01), k.mat(Color(0.75, 0.72, 0.66), 0.3, 0.6), false, hb)
		k.sphere(0.075, Vector3(0.06, 0.11, 0.01), k.mat(Color(0.95, 0.93, 0.88), 0.3), hb, Vector3(1.0, 0.8, 0.07), 14)
	k.box(Vector3(0.2, 0.06, 0.075), Vector3(0.0, 0.86, -0.0075), k.brass, false, hb)
	k.label("SERVICE", Vector3(0.0, 0.86, 0.032), 0.0, 22, Color(0.2, 0.12, 0.04), hb, 0.0022, 0)
	if hg:
		pass
	# the side table by the hatch, with the box of new pens
	var st_z := 0.15
	var stg: Node3D = k.hotspot("side_table", Vector3(W / 2.0 - 0.42, 0, st_z), Vector3(0.7, 1.0, 0.7), Vector3(0, 0.5, 0))
	k.table(Vector3.ZERO, Vector3(0.52, 0.72, 0.52), k.wood_mid, k.wood_dark, 0.0, stg)
	var pens := 0 if day < 3 else (11 if after else 12)
	if pens > 0:
		# a flat box with twelve slots in cream felt; one slot stands empty once a pen has gone
		var pb := Node3D.new()
		pb.position = Vector3(0.06, 0.72, -0.1)
		pb.rotation.y = 0.2
		stg.add_child(pb)
		# twelve slots between raised cream ridges, each lined in red felt (like his case of old pens), so an empty one
		# shows a bare red stripe where every other slot shows a black pen with a gold band
		var pitch := 0.026
		var x0 := -pitch * 5.5
		k.box(Vector3(0.34, 0.026, 0.18), Vector3(0, 0.013, 0), k.mat(Color(0.12, 0.2, 0.35), 0.6), false, pb)
		var felt: Material = k.mat(Color(0.9, 0.86, 0.74), 0.95)
		var hole: Material = k.mat(Color(0.52, 0.1, 0.12), 0.95)
		k.box(Vector3(0.32, Kit.LAYER, 0.16), Vector3(0, 0.026 + Kit.LAYER / 2.0, 0), felt, false, pb)
		for i in 12:
			k.box(Vector3(0.016, 0.0012, 0.142), Vector3(x0 + i * pitch, 0.026 + Kit.LAYER + 0.0006, 0), hole, false, pb)
		for i in 13:
			k.box(Vector3(0.008, 0.009, 0.15), Vector3(x0 + (i - 0.5) * pitch, 0.026 + Kit.LAYER + 0.0045, 0), felt, false, pb)
		# new pens like the clean one by the hatch: black, a gold band and a gold clip. Once one has gone, its slot
		# (the eighth from the left) stands empty in the middle of the row, where it can't be taken for the border
		var pen_m: Material = k.mat(Color(0.08, 0.08, 0.1), 0.3)
		var gold: Material = k.mat(Color(0.8, 0.62, 0.24), 0.3, 0.8)
		var gone := 7 if pens < 12 else -1
		for i in 12:
			if i == gone:
				continue
			var px := x0 + i * pitch
			k.cyl(0.0065, 0.0065, 0.13, Vector3(px, 0.0375, 0), pen_m, pb, false, 8).rotation.x = PI / 2.0
			k.cyl(0.0071, 0.0071, 0.008, Vector3(px, 0.0375, -0.03), gold, pb, false, 8).rotation.x = PI / 2.0
			k.box(Vector3(0.003, 0.003, 0.045), Vector3(px, 0.0375 + 0.0072, -0.052), gold, false, pb)
	if after:
		var dm: MeshInstance3D = k.dust(Vector3(0, 0.72, 0), Vector2(0.5, 0.5), 0.7, stg)
		dm.name = "dust"
		k.torus(0.034, 0.042, Vector3(-0.1, 0.722, 0.08), k.mat(Color(0.36, 0.2, 0.1), 0.6), stg, Vector3.ZERO)
	# the tapestry: a hunting scene in faded wool on a pole, hiding the servants' door
	var tap_z := 2.2
	var tp: Node3D = k.hotspot("tapestry", Vector3(W / 2.0, 0, tap_z), Vector3(1.8, 2.9, 0.6), Vector3(0, 1.45, 0.25), -PI / 2.0)
	k.leaf(tp, 0.8, 2.1, "The servants' passage was built for one slim servant with a tray, not for wrestlers.")
	k.cyl(0.022, 0.022, 1.9, Vector3(0, 2.95, 0.1), k.brass, tp, false, 8).rotation.z = PI / 2.0
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.04, 0.06, 0.1), Vector3(sd * 0.85, 2.95, 0.05), k.brass, false, tp)
		k.sphere(0.035, Vector3(sd * 0.98, 2.95, 0.1), k.brass, tp, Vector3.ONE, 8)
	var wool := [Color(0.5, 0.32, 0.2), Color(0.32, 0.36, 0.24), Color(0.62, 0.5, 0.32), Color(0.4, 0.22, 0.18)]
	for i in 6:
		k.box(Vector3(0.28, 2.75, 0.02), Vector3(-0.7 + i * 0.28, 1.56, 0.1 + 0.012 * float(i % 2)), k.mat(wool[i % 4], 0.98), false, tp)
	k.box(Vector3(1.66, 0.12, 0.024), Vector3(0, 2.86, 0.124), k.mat(Color(0.3, 0.16, 0.1), 0.95), false, tp)
	k.box(Vector3(1.66, 0.12, 0.024), Vector3(0, 0.24, 0.124), k.mat(Color(0.3, 0.16, 0.1), 0.95), false, tp)
	for i in 4:
		k.sphere(0.1, Vector3(-0.5 + i * 0.33, 1.4 + 0.3 * sin(i * 1.7), 0.12), k.mat(Color(0.24, 0.36, 0.22), 0.95), tp, Vector3(1.4, 1.0, 0.12), 10)
	k.sphere(0.13, Vector3(0.2, 1.0, 0.125), k.mat(Color(0.7, 0.56, 0.36), 0.95), tp, Vector3(1.8, 0.8, 0.1), 10)
	k.link_door("tapestry", "servants_passage")
	if after:
		var dt: Node3D = k.hotspot("dust_trail", Vector3(W / 2.0 - 0.7, 0, (tap_z + st_z) / 2.0), Vector3(0.8, 0.3, 1.8), Vector3(0, 0.15, 0))
		var drag: Material = k.mat(Color(0.6, 0.47, 0.34), 0.95)
		# (drawn on top of the white dust patch below, which lies at y 0.016)
		var on_dust := 0.016 + Kit.LAYER * 2.0
		if bool(k.get_meta("photo_trail", false)):
			# the first minute after the door went in: a line dragged through the white dust from the tapestry to the side
			# table and back again, with a row of prints beside it
			for back in [0.0, 1.0]:
				for i in 9:
					var t := float(i) / 8.0
					var x: float = 0.07 * sin(t * 5.0 + back * 1.3) + (0.1 if back > 0.5 else -0.04)
					k.box(Vector3(0.06, Kit.LAYER, 0.26), Vector3(x, on_dust, -0.95 + t * 1.9), drag, false, dt, 0.1 * sin(t * 4.0 + back))
			for i in 6:
				k.box(Vector3(0.05, Kit.LAYER, 0.08), Vector3(0.24, on_dust, -0.8 + i * 0.32), drag, false, dt, 0.15)
		else:
			# trampled by everybody who came in after: scuffed paw prints every which way
			for i in 26:
				var fp := Vector3(-0.38 + 0.76 * _h(i + 140), on_dust, -1.0 + 2.0 * _h(i + 160))
				k.box(Vector3(0.07, Kit.LAYER, 0.1), fp, drag, false, dt, _h(i + 180) * TAU)
		var floor_p: Node3D = k.hotspot("floor_pen", Vector3(W / 2.0 - 0.32, 0, hatch_z + 0.3), Vector3(0.6, 0.4, 0.6), Vector3(0, 0.2, 0))
		_pen(k, floor_p, Vector3(0, 0.017, 0), 0.7, str(k.get_meta("photo_pen", "clean")) == "chewed")
		var bf: Node3D = k.hotspot("books_floor", Vector3(2.6, 0, -0.8), Vector3(2.0, 0.4, 2.0), Vector3(0, 0.2, 0))
		for i in 30:
			var p := Vector3(-0.9 + 1.8 * _h(i + 5), 0, -0.9 + 1.8 * _h(i + 9))
			k.box(Vector3(0.15, 0.035, 0.21), p + Vector3(0, 0.018 + Kit.LAYER * (i % 3), 0), k.mat([Color(0.45, 0.1, 0.12), Color(0.14, 0.26, 0.4), Color(0.62, 0.5, 0.24), Color(0.18, 0.34, 0.24), Color(0.36, 0.2, 0.38)][i % 5], 0.8), false, bf, _h(i + 3) * TAU)
		for i in 14:
			var p := Vector3(3.6 + 0.9 * _h(i + 50), 0, -2.0 + 3.2 * _h(i + 60))
			if absf(p.z - st_z) < 0.45 or absf(p.z - tap_z) < 1.2:
				continue
			k.box(Vector3(0.15, 0.035, 0.21), p + Vector3(0, 0.018 + Kit.LAYER * (i % 3), 0), k.mat([Color(0.45, 0.1, 0.12), Color(0.62, 0.5, 0.24), Color(0.18, 0.34, 0.24)][i % 3], 0.8), false, null, _h(i + 8) * TAU)
		for p in [Vector3(-2.5, 0.016, -1.0), Vector3(1.0, 0.016, 1.2), Vector3(-1.5, 0.016, 2.2), Vector3(3.8, 0.016, -2.0), Vector3(2.8, 0.016, 2.6)]:
			k.dust(p, Vector2(2.4, 2.0), 0.55)
		k.dust(Vector3(W / 2.0 - 0.7, 0.016, (tap_z + st_z) / 2.0 + 0.1), Vector2(0.9, 2.6), 0.55)
	# ---- west wall: the fireplace between two bookcases, a pair of armchairs
	var fp: Node3D = k.fireplace(Vector3(-W / 2.0, 0, -0.4), PI / 2.0, 1.8, false, k.mat(Color(0.3, 0.28, 0.26), 0.4))
	k.hotspot("fireplace", Vector3(-W / 2.0 + 0.2, 0, -0.4), Vector3(0.7, 1.4, 2.0), Vector3(0, 0.7, 0), PI / 2.0)
	if fp:
		pass
	# wound to the second like every clock in the house: the afternoon on Days 2 to 5, the morning after on Day 6
	# (a photograph sets the minute it was taken, "library_clock")
	var lc: Vector2 = k.get_meta("library_clock", Vector2(7.0, 31.0) if after else Vector2(3.0, 40.0))
	k.mantel_clock(Vector3(-W / 2.0 + 0.2, 1.21, -0.4), PI / 2.0, lc.x, lc.y)
	k.painting(Vector3(-W / 2.0, 2.3, -0.4), PI / 2.0, Vector2(1.1, 0.8), "sea", 4)
	k.bookcase(Vector3(-W / 2.0, 0, -2.7), PI / 2.0, Vector3(1.6, bc_h, 0.42), 16)
	_page(k, Vector3(-W / 2.0 + 0.42, 1.5, -3.05), PI / 2.0)
	k.bookcase(Vector3(-W / 2.0, 0, 1.7), PI / 2.0, Vector3(1.6, bc_h, 0.42), 17)
	var green: Material = k.mat(Color(0.16, 0.3, 0.2), 0.85)
	k.armchair(Vector3(-3.5, 0, 1.0), PI * 0.75, green)
	k.armchair(Vector3(-3.5, 0, -1.9), PI * 0.25, green)
	k.table(Vector3(-3.4, 0, -0.45), Vector3(0.5, 0.55, 0.5), k.wood_mid, k.wood_dark)
	# two books on it (nothing cup-shaped: the Day 6 Library has no cup anywhere, and players look for one)
	k.box(Vector3(0.22, 0.04, 0.16), Vector3(-3.42, 0.57, -0.42), k.mat(Color(0.5, 0.14, 0.12), 0.8), false, null, 0.3)
	k.box(Vector3(0.19, 0.035, 0.14), Vector3(-3.4, 0.6075, -0.44), k.mat(Color(0.16, 0.3, 0.22), 0.8), false, null, -0.2)
	# library ladder leaning on the west bookcase
	var lad := Node3D.new()
	lad.position = Vector3(-W / 2.0 + 0.95, 0, -2.2)
	lad.rotation = Vector3(0, PI / 2.0, 0)
	k.root.add_child(lad)
	var lp := Node3D.new()
	lp.rotation.x = -0.2
	lad.add_child(lp)
	for sd in [-0.22, 0.22]:
		k.box(Vector3(0.05, 3.0, 0.05), Vector3(sd, 1.5, 0), k.wood_light, false, lp)
	for i in 9:
		k.box(Vector3(0.44, 0.03, 0.05), Vector3(0, 0.3 + i * 0.32, 0), k.wood_light, false, lp)
	# ---- south wall: windows over the sea, a reading table with the Library's typewriter, a globe
	for x in [0.2, 3.0]:
		k.vista_window(Vector3(x, 2.0, D / 2.0 - 0.002), PI, Vector2(1.2, 2.0), {"prison_at": 0.35 if x > 1.0 else -0.3, "light": 0.6, "curtains": Color(0.2, 0.32, 0.24)})
	var rt: Node3D = k.hotspot("typewriter", Vector3(1.6, 0, 2.5), Vector3(1.0, 1.1, 0.8), Vector3(0, 0.55, 0))
	k.table(Vector3.ZERO, Vector3(1.6, 0.76, 0.8), k.wood_mid, k.wood_dark, 0.0, rt)
	k.typewriter(Vector3(-0.2, 0.76, 0.0), 0.0, Color(0.14, 0.16, 0.15), rt)
	k.box(Vector3(0.22, 0.02, 0.3), Vector3(0.45, 0.77, 0.05), k.paper, false, rt, 0.2)
	k.chair(Vector3(1.4, 0, 3.3), PI, k.mat(Color(0.18, 0.3, 0.22), 0.85), k.wood_dark)
	var globe := Vector3(4.3, 0, 3.3)
	for i in 3:
		var a := i * TAU / 3.0
		k.beam(globe + Vector3(0, 0.55, 0), globe + Vector3(cos(a) * 0.24, 0, sin(a) * 0.24), 0.018, k.wood_dark)
	k.cyl(0.24, 0.24, 0.03, globe + Vector3(0, 0.56, 0), k.wood_dark, null, false, 16)
	k.sphere(0.24, globe + Vector3(0, 0.84, 0), k.mat(Color(0.56, 0.66, 0.6), 0.5), null, Vector3.ONE, 18)
	k.torus(0.25, 0.27, globe + Vector3(0, 0.84, 0), k.brass, null, Vector3(0, 0, 0.4))
	k.blocker(Vector3(0.5, 1.1, 0.5), globe + Vector3(0, 0.55, 0))
	_rug(k, Vector3(-0.3, 0, 0.2), Vector2(4.2, 3.0), Color(0.4, 0.1, 0.1), GILT)
	k.chandelier(Vector3(-0.3, 3.3, 0.4), H, WARM, 1.9, 11.0, true, 8, 1.1)
	k.sconce(Vector3(-W / 2.0, 2.4, 3.1), PI / 2.0, LAMP, 0.6, 5.0)
	k.sconce(Vector3(W / 2.0, 2.4, -1.05 + 0.0), -PI / 2.0, LAMP, 0.7, 5.5)
	k.sconce(Vector3(-1.4, 2.4, D / 2.0), PI, LAMP, 0.6, 5.0)
	k.cctv(Vector3(W / 2.0, 3.5, D / 2.0 - 0.4), -PI / 2.0, 0.6)
	_crack(k, Vector3(1.6, 4.4, D / 2.0), PI, 1.6, Vector2(0.4, -1.0), 21)
	_crack(k, Vector3(-W / 2.0, 4.3, 0.6), PI / 2.0, 1.4, Vector2(-0.3, -1.0), 23)
	# the door: bolted from inside on its last night, broken in on Day 6
	var dstyle := {"h": 2.1}
	if after:
		dstyle = {"broken": true, "swing_in": true, "h": 2.1}
	k.door("grand_hall", "", Vector3(door_x, 0, D / 2.0), PI, dstyle)
	if after:
		# the barrel bolt on the room side of the leaf, near its latch edge: still shot, its keeper torn off the frame
		var leaf: Node3D = ((k.doors["grand_hall"] as Dictionary)["slab"] as Node3D).get_parent()
		var dw := Kit.DOOR_W
		k.box(Vector3(0.05, 0.07, 0.012), Vector3(dw - 0.2, 1.05, 0.006), k.brass, false, leaf)
		k.box(Vector3(0.13, 0.034, 0.03), Vector3(dw - 0.11, 1.05, 0.015), k.brass, false, leaf)
		k.cyl(0.011, 0.011, 0.11, Vector3(dw - 0.02, 1.05, 0.026), k.mat(Color(0.78, 0.64, 0.3), 0.3, 0.8), leaf, false, 8).rotation.z = PI / 2.0
		k.cyl(0.008, 0.008, 0.05, Vector3(dw - 0.09, 1.075, 0.03), k.brass, leaf, false, 6)
	# the barrel bolt's keeper on the frame (torn out and lying on the floor on Day 6)
	var dh: Node3D = k.hotspot("door", Vector3(door_x - 0.66, 0, D / 2.0), Vector3(0.36, 1.6, 0.4), Vector3(0, 1.1, 0.2), PI)
	if not after:
		k.box(Vector3(0.06, 0.12, 0.03), Vector3(0, 1.05, 0.015), k.brass, false, dh)
		k.box(Vector3(0.03, 0.06, 0.03), Vector3(0, 1.05, 0.045), k.brass, false, dh)
	else:
		k.box(Vector3(0.06, 0.12, 0.012), Vector3(0, 1.05, 0.006), k.mat(Color(0.62, 0.46, 0.3), 0.9), false, dh)
	if after:
		_glimpse_room(k, Vector3(door_x, 0, D / 2.0), PI, _wallpaper(k, Color(0.13, 0.26, 0.23), Color(0.27, 0.42, 0.33), 0.32), _parquet(k), WARM, 0.45)
	_spots(k, [Vector3(-1.8, 0, 1.6), Vector3(1.6, 0, 1.2), Vector3(-1.6, 0, 2.9), Vector3(3.0, 0, 1.4), Vector3(0.4, 0, 3.2)])
	if k.mode == "investigate" and after:
		# the morning after: Zuzu hasn't gone far from the desk, Pepper stands by the window
		k.person("zuzu", Vector3(0.95, 0, -1.2))
		k.person("pepper", Vector3(3.3, 0, 2.95))
	_guests(k, "library", {"a": Vector3(1.4, 0, -1.6), "b": Vector3(3.2, 0, 1.6)})
	k.spawn = Vector3(door_x, 0, D / 2.0 - 1.3)
	k.look = Vector3(0.5, 1.4, -D / 2.0)



# =================================================================== Servants' passage
## Inside the walls between the Library and the Bedroom Wing: bare boards, a row of old service bells, one narrow door at
## each end. Sealed for years: a film of grey dust from the Day 2 aftershock, and on Day 6 white limewash over it with a
## single set of prints there and back, a dragged line beside them, and a feather caught on the Library door's bracket.
## Anchors: passage_door (the Library end), tracks, hem_line, feather (Day 6), bells.
static func _passage(k) -> void:
	var after := _after(k)
	var H := 3.3
	var WD := 0.92
	k.cramped = "A servants' passage inside the walls, built for one slim servant with a tray."
	k.environment("dim", Color(0.5, 0.48, 0.46), 0.42)
	var boards: Material = k.wood_wall(Color(0.22, 0.15, 0.1), Color(0.34, 0.24, 0.16), 0.14)
	var o := {"floor": k.wood_floor(Color(0.2, 0.14, 0.09), Color(0.32, 0.22, 0.14), 0.12), "wall": boards, "wain": null,
		"trim": k.mat(Color(0.14, 0.1, 0.07), 0.9), "ceiling": k.mat(Color(0.3, 0.26, 0.22), 0.95)}
	var hw := WD / 2.0
	var zt := -8.0
	var xe := 7.4
	k.plan([[-hw, zt, hw, 0.0], [hw, zt, xe, zt + WD]], 0.0, H, o)
	k.bounds = Vector2(xe + hw, -zt)
	var narrow := "The servants' passage was built for one slim servant with a tray, not for wrestlers."
	k.door("library", "", Vector3(0, 0, 0.0), PI, {"w": 0.8, "narrow": narrow, "sign": false, "mat": k.wood_mid})
	k.door("bedroom_wing", "", Vector3(xe, 0, zt + hw), -PI / 2.0, {"w": 0.8, "narrow": narrow, "sign": false, "mat": k.wood_mid})
	# ceiling joists, a pipe, old lamp brackets, bare bulbs
	var joist: Material = k.mat(Color(0.18, 0.13, 0.09), 0.9)
	for i in 8:
		k.box(Vector3(WD, 0.12, 0.08), Vector3(0, H - 0.06, -0.6 - i * 0.95), joist)
	for i in 7:
		k.box(Vector3(0.08, 0.12, WD), Vector3(hw + 0.5 + i * 1.0, H - 0.06, zt + hw), joist)
	k.beam(Vector3(hw - 0.06, 2.6, -0.2), Vector3(hw - 0.06, 2.6, zt + 0.06), 0.03, k.mat(Color(0.36, 0.3, 0.24), 0.5, 0.6))
	k.beam(Vector3(hw - 0.06, 2.6, zt + 0.06), Vector3(xe - 0.1, 2.6, zt + 0.06), 0.03, k.mat(Color(0.36, 0.3, 0.24), 0.5, 0.6))
	for p in [Vector3(0, 2.4, -2.0), Vector3(0, 2.4, -6.0), Vector3(3.2, 2.4, zt + hw), Vector3(6.4, 2.4, zt + hw)]:
		var pp: Vector3 = p
		k.flickers.append(k.bulb(pp, H, Color(1.0, 0.8, 0.52), 0.55, 4.0))
	# the row of service bells on their springs, labelled for rooms that no longer ring
	var bl: Node3D = k.hotspot("bells", Vector3(-hw, 2.0, -4.2), Vector3(0.3, 0.6, 1.6), Vector3(0.15, 0, 0), PI / 2.0)
	k.box(Vector3(1.5, 0.36, 0.03), Vector3(0, 0.0, 0.015), k.wood_dark, false, bl)
	for i in 6:
		var x := -0.6 + i * 0.24
		k.beam(Vector3(x, 0.1, 0.03), Vector3(x, -0.04, 0.09), 0.006, k.brass, bl)
		k.sphere(0.045, Vector3(x, -0.08, 0.1), k.brass, bl, Vector3(1, 0.8, 1), 10)
		k.box(Vector3(0.16, 0.05, 0.004), Vector3(x, 0.12, 0.032), k.paper, false, bl)
	# a forgotten tray and a broom, an old lamp on a bracket, a hook with a duster
	k.box(Vector3(0.4, 0.02, 0.28), Vector3(-0.2, 0.01, -7.4), k.mat(Color(0.6, 0.6, 0.62), 0.3, 0.7), false, null, 0.3)
	k.cyl(0.03, 0.03, 0.08, Vector3(-0.2, 0.06, -7.4), k.mat(Color(0.85, 0.85, 0.8), 0.4), null, false, 8)
	var brm := Node3D.new()
	brm.position = Vector3(hw - 0.08, 0, -2.9)
	brm.rotation.z = 0.1
	k.root.add_child(brm)
	k.cyl(0.015, 0.015, 1.3, Vector3(0, 0.75, 0), k.wood_light, brm, false, 6)
	k.box(Vector3(0.06, 0.16, 0.26), Vector3(0, 0.08, 0), k.mat(Color(0.62, 0.5, 0.3), 0.95), false, brm)
	var shelf: Node3D = k.wall_shelf(Vector3(-hw, 1.7, -6.6), PI / 2.0, 0.6, 0.18, k.wood_dark)
	for i in 3:
		k.cyl(0.035, 0.04, 0.12, Vector3(-0.18 + i * 0.18, 0.06, 0.09), k.mat([Color(0.3, 0.28, 0.26), Color(0.55, 0.45, 0.25), Color(0.3, 0.36, 0.3)][i], 0.6), shelf, false, 10)
	for p in [Vector3(2.0, 1.8, zt), Vector3(5.0, 1.8, zt)]:
		var pp: Vector3 = p
		k.box(Vector3(0.08, 0.08, 0.04), pp + Vector3(0, 0, 0.02), k.brass)
		k.beam(pp + Vector3(0, 0, 0.04), pp + Vector3(0, -0.1, 0.12), 0.008, k.brass)
	k.box(Vector3(0.22, 0.4, 0.03), Vector3(2.0, 1.55, zt + 0.15), k.mat(Color(0.82, 0.8, 0.74), 0.95), false, null, 0.05)
	# Day 2's grey dust lies everywhere in here; on Day 6 white limewash lies on top of it
	var grey: Material = k.mat(Color(0.5, 0.49, 0.47), 0.95)
	for i in 8:
		k.box(Vector3(WD - 0.06, Kit.LAYER, 0.95), Vector3(0, Kit.LAYER / 2.0, -0.55 - i * 0.95), grey)
	k.box(Vector3(xe - hw - 0.06, Kit.LAYER, WD - 0.06), Vector3((hw + xe) / 2.0, Kit.LAYER / 2.0, zt + hw), grey)
	var pd: Node3D = k.hotspot("passage_door", Vector3(0, 0, -0.25), Vector3(0.84, 1.2, 0.5), Vector3(0, 0.6, 0))
	if pd:
		pass
	if after:
		var lime: Material = k.mat(Color(0.95, 0.95, 0.92), 0.98)
		for i in 8:
			k.box(Vector3(WD - 0.1, Kit.LAYER, 0.93), Vector3(0, Kit.LAYER * 1.5, -0.55 - i * 0.95), lime)
		k.box(Vector3(xe - hw - 0.1, Kit.LAYER, WD - 0.1), Vector3((hw + xe) / 2.0, Kit.LAYER * 1.5, zt + hw), lime)
		for p in [Vector3(-hw, 2.2, -1.5), Vector3(hw, 2.6, -5.0), Vector3(3.5, 2.3, zt)]:
			var pp: Vector3 = p
			var rot := PI / 2.0 if pp.x < 0.0 else (-PI / 2.0 if absf(pp.z - zt) > 0.1 else 0.0)
			_crack(k, pp, rot, 1.0, Vector2(0.2, -1.0), int(pp.z * 7.0))
		# the prints: one set, there and back, grey showing through where each paw pressed the white down
		var tr: Node3D = k.hotspot("tracks", Vector3(0, 0, -3.6), Vector3(0.8, 0.3, 2.4), Vector3(0, 0.15, 0))
		if tr:
			pass
		var paw: Material = k.mat(Color(0.42, 0.41, 0.4), 0.95)
		for i in 9:
			var z := -0.6 - i * 0.8
			for lane in [-0.16, 0.16]:
				var off := 0.0 if lane < 0.0 else 0.4
				k.box(Vector3(0.09, Kit.LAYER, 0.13), Vector3(lane + 0.05 * float(i % 2), Kit.LAYER * 2.5, z - off), paw, false, null, 0.1 * lane)
		for i in 8:
			var x := hw + 0.4 + i * 0.85
			for lane in [-0.16, 0.16]:
				var off := 0.0 if lane < 0.0 else 0.4
				k.box(Vector3(0.13, Kit.LAYER, 0.09), Vector3(x + off, Kit.LAYER * 2.5, zt + hw + lane + 0.05 * float(i % 2)), paw, false, null, 0.1 * lane)
		var hm: Node3D = k.hotspot("hem_line", Vector3(-0.3, 0, -5.4), Vector3(0.5, 0.3, 1.8), Vector3(0, 0.15, 0))
		k.box(Vector3(0.04, Kit.LAYER, 3.2), Vector3(-0.32 + 0.3, Kit.LAYER * 2.5, 0.2), k.mat(Color(0.6, 0.58, 0.56), 0.95), false, hm, 0.02)
		# an old lamp bracket on the wall just inside the Library door, with a snapped feather caught on it
		var ft: Node3D = k.hotspot("feather", Vector3(-hw, 1.9, -0.9), Vector3(0.36, 0.44, 0.3), Vector3(0, 0, 0.14), PI / 2.0)
		k.box(Vector3(0.08, 0.12, 0.03), Vector3(0.0, 0.0, 0.015), k.brass, false, ft)
		k.beam(Vector3(0, 0, 0.03), Vector3(0, 0.08, 0.16), 0.008, k.brass, ft)
		var fe: MeshInstance3D = k.sphere(0.05, Vector3(0.02, -0.04, 0.13), k.mat(Color(0.62, 0.36, 0.7), 0.8), ft, Vector3(0.35, 2.0, 0.25), 8)
		fe.rotation.z = 0.5
	# nobody waits in here: anyone standing in a passage this narrow would block it
	k.spawn = Vector3(0, 0, -1.2)
	k.look = Vector3(0, 1.4, -6.0)


# =================================================================== Bedroom Wing
## A long upstairs corridor: seven doors on the north side, four on the south, a window or two, the Grand Hall at the west
## end and the attic stairs at the east. A jib door in the south panelling, flush and unmarked, opens into the servants'
## passage (it is only usable once the investigation gets there).
static func _bedroom_wing(k) -> void:
	var L := 14.0
	var hw := 1.3
	var H := 3.4
	var after := _after(k)
	k.environment("indoor", Color(0.6, 0.55, 0.5), 0.46)
	var paper: Material = _wallpaper(k, Color(0.36, 0.14, 0.15), Color(0.52, 0.3, 0.26), 0.26)
	var o := _manor(k, paper, null, "panel", 1.0)
	k.plan([[-L, -hw, L, hw]], 0.0, H, o)
	k.bounds = Vector2(L * 2.0, hw * 2.0)
	_mouldings(k, -L, -hw, L, hw, H)
	_rug(k, Vector3(0, 0, 0), Vector2(L * 2.0 - 1.6, 1.1), Color(0.3, 0.12, 0.14), GILT)
	k.door("grand_hall", "", Vector3(-L, 0, 0), PI / 2.0, {"h": 2.3, "w": 1.2})
	k.door("attic", "Attic Stairs", Vector3(L, 0, 0), -PI / 2.0, {"mat": k.wood_dark})
	var north := ["mochi", "bramble", "bruno", "duchess", "fennel", "grub", "lulu"]
	var south := ["pepper", "nibs", "reginald", "zuzu"]
	for i in north.size():
		var x := -11.0 + i * 3.6
		var who: String = north[i]
		k.door("bedroom_" + who, "", Vector3(x, 0, -hw), 0.0)
		_name_card(k, Vector3(x + 0.86, 1.5, -hw), 0.0, who)
	for i in south.size():
		var x := -9.2 + i * 3.6
		var who: String = south[i]
		k.door("bedroom_" + who, "", Vector3(x, 0, hw), PI)
		_name_card(k, Vector3(x - 0.86, 1.5, hw), PI, who)
	# the jib door into the passage, flush with the panelling between the windows and the attic end
	k.door("servants_passage", "Servants' Passage", Vector3(12.2, 0, hw), PI, {"hidden": true, "w": 0.8, "mat": paper, "frame": k.wood_dark,
		"narrow": "A jib door into the servants' passage, made to be missed."})
	for x in [5.2, 8.8]:
		k.vista_window(Vector3(x, 1.75, hw - 0.002), PI, Vector2(1.1, 1.8), {"prison_at": 0.4, "light": 0.5, "curtains": Color(0.5, 0.36, 0.2)})
	# between the doors: console tables, chairs, portraits and sconces
	for i in 6:
		var x := -9.2 + i * 3.6
		k.sconce(Vector3(x, 2.25, -hw), 0.0, LAMP, 0.55 if i % 2 == 0 else 0.0, 5.0)
		k.painting(Vector3(x, 2.15, -hw), 0.0, Vector2(0.5, 0.66), "portrait", 20 + i)
	for i in 4:
		var x := -11.0 + i * 3.6
		if x > 10.0:
			continue
		k.painting(Vector3(x, 2.1, hw), PI, Vector2(0.62, 0.46), "sea" if i % 2 == 0 else "still", 30 + i)
		if i == 2:
			_page(k, Vector3(x - 0.1, 1.87, hw), PI)
	_console(k, Vector3(-7.4, 0, hw - 0.24), PI, 1.0, Color(0.5, 0.3, 0.3))
	_console(k, Vector3(-0.2, 0, hw - 0.24), PI, 1.0)
	k.chair(Vector3(3.4, 0, hw - 0.35), PI, k.mat(Color(0.4, 0.1, 0.12), 0.85), k.wood_dark)
	k.plant(Vector3(11.9, 0, -hw + 0.45), 0.9)
	k.longcase_clock(Vector3(10.6 - 1.8, 0, -hw), 0.0, 3.0, 25.0)
	for x in [-10.0, -3.0, 4.0, 11.0]:
		k.chandelier(Vector3(x, 2.85, 0), H, WARM, 1.0, 6.5, x == -3.0, 5, 0.6)
	k.sconce(Vector3(10.6 + 1.8, 2.25, -hw), 0.0, LAMP, 0.55, 5.0)
	k.cctv(Vector3(-L, 2.85, -hw + 0.4), PI / 2.0, 0.5)
	_crack(k, Vector3(2.0, 3.3, hw), PI, 1.4, Vector2(0.3, -1.0), 41)
	if after:
		for x in [-9.0, -2.0, 5.0, 11.0]:
			k.dust(Vector3(x, 0.016, 0), Vector2(3.0, 1.6), 0.45)
	_spots(k, [Vector3(-12.2, 0, 0), Vector3(5.2, 0, 0.3), Vector3(8.8, 0, 0.3)])
	k.spawn = Vector3(-L + 1.2, 0, 0)
	k.look = Vector3(L, 1.4, 0)


# =================================================================== Bedrooms (one layout, each with its owner's things)
## The bed's head against the north wall, a wardrobe and washstand on the west wall, a window over the sea on the east wall
## with the writing desk below it. Anchors: bed, desk, wardrobe, window, keepsake (the owner's own thing).
static func _bedroom(k, who: String) -> void:
	var W := 6.0
	var D := 5.0
	var H := 3.5
	var after := _after(k)
	var palettes := {"mochi": [Color(0.24, 0.36, 0.42), Color(0.36, 0.5, 0.52), Color(0.3, 0.5, 0.7)],
		"bramble": [Color(0.26, 0.34, 0.2), Color(0.4, 0.5, 0.3), Color(0.5, 0.62, 0.3)],
		"bruno": [Color(0.36, 0.2, 0.16), Color(0.5, 0.32, 0.24), Color(0.62, 0.2, 0.18)],
		"duchess": [Color(0.34, 0.24, 0.4), Color(0.5, 0.38, 0.54), Color(0.62, 0.48, 0.7)],
		"fennel": [Color(0.42, 0.3, 0.2), Color(0.58, 0.44, 0.3), Color(0.78, 0.32, 0.3)],
		"grub": [Color(0.42, 0.28, 0.16), Color(0.58, 0.42, 0.24), Color(0.85, 0.5, 0.3)],
		"lulu": [Color(0.44, 0.24, 0.32), Color(0.6, 0.38, 0.46), Color(0.92, 0.56, 0.72)],
		"pepper": [Color(0.4, 0.32, 0.2), Color(0.56, 0.48, 0.32), Color(0.85, 0.66, 0.36)],
		"nibs": [Color(0.24, 0.28, 0.32), Color(0.38, 0.44, 0.48), Color(0.56, 0.62, 0.66)],
		"reginald": [Color(0.32, 0.26, 0.12), Color(0.48, 0.4, 0.2), Color(0.8, 0.66, 0.24)],
		"zuzu": [Color(0.16, 0.26, 0.32), Color(0.24, 0.4, 0.46), Color(0.2, 0.72, 0.8)]}
	var pal: Array = palettes.get(who, palettes["mochi"])
	k.environment("indoor", Color(0.62, 0.56, 0.5), 0.46)
	var o := _manor(k, _wallpaper(k, pal[0], pal[1], 0.24), null, "panel", 0.9)
	k.plan([[-W / 2.0, -D / 2.0, W / 2.0, D / 2.0]], 0.0, H, o)
	k.bounds = Vector2(W, D)
	_mouldings(k, -W / 2.0, -D / 2.0, W / 2.0, D / 2.0, H, 0.0, 2.6)
	var door_x := -1.8
	k.door("bedroom_wing", "Bedroom Wing", Vector3(door_x, 0, D / 2.0), PI)
	# the bed and its bedside table with a lamp
	var bg: Node3D = k.hotspot("bed", Vector3(0.6, 0, -D / 2.0), Vector3(1.7, 1.0, 2.3), Vector3(0, 0.5, 1.1))
	k.bed(Vector3.ZERO, 0.0, pal[2], 1.4, who in ["duchess", "reginald"], bg)
	var bt: Node3D = k.table(Vector3(1.75, 0, -D / 2.0 + 0.3), Vector3(0.44, 0.6, 0.4), k.wood_mid, k.wood_dark)
	k.desk_lamp(Vector3(0.0, 0.6, -0.04), PI, bt, 0.55)
	k.box(Vector3(0.14, 0.03, 0.2), Vector3(-0.1, 0.615, 0.08), k.mat(pal[2].darkened(0.3), 0.8), false, bt, 0.3)
	# the wardrobe and the washstand on the west wall
	var wd: Node3D = k.hotspot("wardrobe", Vector3(-W / 2.0, 0, -1.2), Vector3(0.8, 2.3, 1.3), Vector3(0, 1.15, 0.3), PI / 2.0)
	k.wardrobe(Vector3.ZERO, 0.0, 1.2, 2.2, k.wood_mid, wd)
	var ws := Vector3(-W / 2.0 + 0.3, 0, 0.6)
	k.table(ws, Vector3(0.5, 0.82, 0.8), k.mat(Color(0.86, 0.84, 0.8), 0.4), k.wood_dark, PI / 2.0)
	k.cyl(0.2, 0.12, 0.1, ws + Vector3(0, 0.87, 0), k.white, null, false, 16)
	k.cyl(0.07, 0.09, 0.26, ws + Vector3(0, 0.95, 0.25), k.white, null, false, 12)
	k.mirror(Vector3(-W / 2.0, 1.55, 0.6), PI / 2.0, Vector2(0.5, 0.7), false, k.wood_dark, Color(0.66, 0.66, 0.62), Color(0.42, 0.36, 0.3))
	k.box(Vector3(0.04, 0.03, 0.4), Vector3(-W / 2.0 + 0.04, 1.05, 0.6 + 0.0), k.brass)
	k.box(Vector3(0.03, 0.4, 0.3), Vector3(-W / 2.0 + 0.06, 0.82, 0.6), k.mat(Color(0.9, 0.9, 0.86), 0.95))
	# the window over the sea, and the writing desk under it
	var wn: Node3D = k.hotspot("window", Vector3(W / 2.0, 0.95, -0.5), Vector3(0.4, 1.9, 1.3), Vector3(0.15, 0.95, 0), -PI / 2.0)
	if wn:
		pass
	k.vista_window(Vector3(W / 2.0 - 0.002, 1.9, -0.5), -PI / 2.0, Vector2(1.1, 1.8), {"prison_at": 0.5 if who != "mochi" else 0.2, "light": 0.55, "curtains": pal[1].darkened(0.2)})
	var dk: Node3D = k.hotspot("desk", Vector3(W / 2.0 - 0.4, 0, 1.3), Vector3(0.9, 1.1, 1.3), Vector3(0, 0.55, 0), -PI / 2.0)
	k.table(Vector3.ZERO, Vector3(1.1, 0.76, 0.6), k.wood_mid, k.wood_dark, 0.0, dk)
	k.chair(Vector3(W / 2.0 - 1.05, 0, 1.3), -PI / 2.0, k.mat(pal[1], 0.85), k.wood_dark)
	k.box(Vector3(0.3, 0.012, 0.22), Vector3(-0.3, 0.766, 0.05), k.paper, false, dk, 0.1)
	k.cyl(0.025, 0.025, 0.08, Vector3(-0.42, 0.8, -0.18), k.mat(Color(0.1, 0.1, 0.2), 0.2), dk, false, 8)
	# a small fireplace (cold), a painting, the rug, the ceiling light
	k.fireplace(Vector3(-1.4, 0, -D / 2.0), 0.0, 1.2, false, k.mat(Color(0.82, 0.8, 0.76), 0.4))
	k.painting(Vector3(-1.4, 2.0, -D / 2.0), 0.0, Vector2(0.7, 0.52), "sea" if (who.length() % 2) == 0 else "still", who.length())
	_rug(k, Vector3(0.4, 0, 0.8), Vector2(2.6, 1.7), pal[2].darkened(0.4), GILT)
	k.hanging_lamp(Vector3(0.0, 2.75, 0.2), WARM, 1.0, H, true, 7.0)
	k.cctv(Vector3(W / 2.0, 2.9, D / 2.0 - 0.3), -PI / 2.0, 0.6)
	_crack(k, Vector3(2.0, H - 0.2, -D / 2.0), 0.0, 1.0, Vector2(0.4, -1.0), who.length() * 3)
	# the owner's own things
	var kp: Node3D = k.hotspot("keepsake", Vector3(W / 2.0 - 0.7, 0, 2.12), Vector3(0.9, 1.2, 0.6), Vector3(0, 0.5, 0))
	_keepsake(k, who, kp, dk, bg)
	# his case of old pens on the mantelpiece: every one of them chewed
	if who == "nibs":
		var pcs: Node3D = k.hotspot("pen_case", Vector3(-1.02, 1.21, -D / 2.0 + 0.2), Vector3(0.44, 0.3, 0.36), Vector3(0, 0.12, 0.04))
		var case_m: Material = k.mat(Color(0.36, 0.2, 0.1), 0.5)
		k.box(Vector3(0.32, 0.05, 0.16), Vector3(0, 0.025, 0), case_m, false, pcs)
		k.box(Vector3(0.3, 0.012, 0.14), Vector3(0, 0.051, 0), k.mat(Color(0.45, 0.1, 0.12), 0.9), false, pcs)
		var lid: MeshInstance3D = k.box(Vector3(0.32, 0.14, 0.012), Vector3(0, 0.12, -0.09), case_m, false, pcs)
		lid.rotation.x = -0.25
		for i in 7:
			var px := -0.12 + i * 0.04
			k.cyl(0.006, 0.006, 0.12, Vector3(px, 0.064, -0.01), k.mat(Color(0.12, 0.12, 0.14), 0.3), pcs, false, 6).rotation.x = PI / 2.0
			k.sphere(0.009, Vector3(px, 0.064, 0.055), k.mat(Color(0.74, 0.62, 0.45), 0.95), pcs, Vector3(1.0, 0.7, 1.4), 5)
	if after:
		k.dust(Vector3(0.4, 0.02, 0.0), Vector2(3.4, 2.6), 0.35)
	_spots(k, [Vector3(0.0, 0, 1.4), Vector3(1.5, 0, 0.4)])
	k.spawn = Vector3(door_x, 0, D / 2.0 - 1.2)
	k.look = Vector3(0.6, 1.0, -D / 2.0)


## What makes each bedroom its owner's: `kp` is a spot by the door (south-west corner), `dk` the desk group, `bg` the bed group.
static func _keepsake(k, who: String, kp: Node3D, dk: Node3D, bg: Node3D) -> void:
	match who:
		"mochi":
			k.sphere(0.08, Vector3(0.3, 0.83, -0.15), k.mat(Color(1.0, 0.85, 0.2), 0.4), dk, Vector3(1.2, 1.0, 1.0), 12)
			k.sphere(0.05, Vector3(0.33, 0.93, -0.15), k.mat(Color(1.0, 0.85, 0.2), 0.4), dk, Vector3.ONE, 10)
			k.folded_stack(Vector3(0.0, 0.0, 0.0), [Color(0.95, 0.92, 0.85), Color(0.5, 0.75, 0.85)], 3, Vector2(0.5, 0.36), 0.0, kp)
			k.cyl(0.09, 0.09, 0.2, Vector3(0.0, 0.26, 0.0), k.mat(Color(0.6, 0.85, 0.9), 0.2), kp, false, 12)
		"bramble":
			for i in 4:
				k.cyl(0.07, 0.05, 0.12, Vector3(-0.3 + i * 0.2, 0.06, 0.0), k.mat(Color(0.6, 0.3, 0.2), 0.8), kp, false, 10)
				k.sphere(0.08, Vector3(-0.3 + i * 0.2, 0.17, 0.0), k.mat(Color(0.3, 0.55, 0.25), 0.8), kp, Vector3(1, 0.8, 1), 8)
			k.cyl(0.08, 0.1, 0.2, Vector3(0.0, 0.1, 0.25), k.mat(Color(0.5, 0.6, 0.62), 0.3, 0.6), kp, false, 12)
			for i in 3:
				k.box(Vector3(0.08, 0.12, 0.005), Vector3(0.3 + i * 0.1, 0.83, 0.1), k.mat([Color(0.8, 0.5, 0.3), Color(0.9, 0.8, 0.3), Color(0.5, 0.3, 0.6)][i], 0.8), false, dk, 0.2 * i)
		"bruno":
			for sd in [-0.2, 0.2]:
				k.cyl(0.03, 0.03, 0.34, Vector3(sd, 0.08, 0.0), k.steel, kp, false, 8).rotation.z = PI / 2.0
				for e in [-0.13, 0.13]:
					k.cyl(0.08, 0.08, 0.05, Vector3(sd + e, 0.08, 0.0), k.mat(Color(0.12, 0.12, 0.13), 0.5), kp, false, 12).rotation.z = PI / 2.0
			k.cyl(0.12, 0.12, 0.6, Vector3(0.0, 0.12, 0.3), k.mat(Color(0.2, 0.4, 0.5), 0.8), kp, false, 14).rotation.z = PI / 2.0
			k.box(Vector3(0.3, 0.16, 0.2), Vector3(0.3, 0.84, -0.1), k.mat(Color(0.85, 0.85, 0.82), 0.5), false, dk)
			k.box(Vector3(0.06, 0.1, 0.005), Vector3(0.3, 0.86, 0.0), k.mat(Color(0.8, 0.1, 0.1), 0.5), false, dk)
		"duchess":
			for i in 3:
				k.cyl(0.2 - i * 0.03, 0.2 - i * 0.03, 0.18, Vector3(0.0, 0.09 + i * 0.18, 0.0), k.mat([Color(0.6, 0.3, 0.5), Color(0.9, 0.85, 0.75), Color(0.4, 0.3, 0.55)][i], 0.6), kp, false, 18)
			k.cyl(0.05, 0.07, 0.25, Vector3(0.3, 0.88, -0.12), k.mat(Color(0.8, 0.78, 0.74), 0.4), dk, false, 10)
			k.sphere(0.09, Vector3(0.3, 1.06, -0.12), k.mat(Color(0.8, 0.78, 0.74), 0.4), dk, Vector3.ONE, 10)
			k.cyl(0.16, 0.16, 0.03, Vector3(0.3, 1.13, -0.12), k.mat(Color(0.62, 0.36, 0.7), 0.6), dk, false, 16)
		"fennel":
			var ea := Node3D.new()
			ea.position = Vector3(0.0, 0, 0.0)
			ea.rotation.y = 0.5
			kp.add_child(ea)
			for sd in [-0.25, 0.25]:
				var leg: MeshInstance3D = k.box(Vector3(0.035, 1.5, 0.035), Vector3(sd, 0.75, 0.0), k.wood_light, false, ea)
				leg.rotation.x = -0.1
			k.box(Vector3(0.6, 0.45, 0.025), Vector3(0, 1.1, 0.08), k.white, false, ea)
			k.box(Vector3(0.52, 0.18, 0.005), Vector3(0, 1.0, 0.095), k.mat(Color(0.3, 0.5, 0.65), 0.9), false, ea)
			k.box(Vector3(0.52, 0.16, 0.005), Vector3(0, 1.18, 0.095), k.mat(Color(0.95, 0.75, 0.5), 0.9), false, ea)
			k.box(Vector3(0.5, 0.04, 0.06), Vector3(0, 0.86, 0.05), k.wood_light, false, ea)
			for i in 5:
				k.cyl(0.012, 0.012, 0.1, Vector3(0.2 + i * 0.03, 0.775, 0.1), k.mat([Color(0.9, 0.2, 0.2), Color(0.2, 0.4, 0.9), Color(0.95, 0.85, 0.2), Color(0.2, 0.7, 0.3), Color(0.95, 0.95, 0.95)][i], 0.6), dk, false, 6).rotation.z = PI / 2.0
		"grub":
			k.cyl(0.2, 0.18, 0.2, Vector3(0.0, 0.1, 0.0), k.mat(Color(0.12, 0.12, 0.12), 0.4, 0.5), kp, false, 16)
			k.torus(0.02, 0.04, Vector3(0.22, 0.17, 0.0), k.mat(Color(0.12, 0.12, 0.12), 0.4, 0.5), kp, Vector3(0, 0, PI / 2.0))
			for i in 3:
				k.box(Vector3(0.22, 0.05, 0.3), Vector3(0.3, 0.79 + i * 0.05, -0.1), k.mat([Color(0.8, 0.3, 0.2), Color(0.3, 0.5, 0.3), Color(0.9, 0.8, 0.5)][i], 0.8), false, dk, 0.1 * i)
		"lulu":
			k.cyl(0.015, 0.015, 1.6, Vector3(-0.35, 0.8, 0.0), k.steel, kp, false, 8)
			k.cyl(0.015, 0.015, 1.6, Vector3(0.35, 0.8, 0.0), k.steel, kp, false, 8)
			k.cyl(0.015, 0.015, 0.72, Vector3(0.0, 1.6, 0.0), k.steel, kp, false, 8).rotation.z = PI / 2.0
			for i in 3:
				k.box(Vector3(0.18, 0.9, 0.03), Vector3(-0.22 + i * 0.22, 1.12, 0.0), k.mat([Color(1.0, 0.5, 0.75), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.4)][i], 0.3, 0.4), false, kp)
			for sd in [-0.35, 0.35]:
				k.box(Vector3(0.3, 0.03, 0.3), Vector3(sd, 0.015, 0.0), k.steel, false, kp)
			k.cyl(0.03, 0.02, 0.18, Vector3(0.3, 0.81, -0.1), k.black, dk, false, 10).rotation.z = 1.35
		"pepper":
			k.typewriter(Vector3(0.12, 0.76, -0.06), -0.2, Color(0.5, 0.18, 0.12), dk)
			for i in 4:
				k.box(Vector3(0.36, 0.012, 0.5), Vector3(0.0, 0.006 + i * 0.013, 0.0), k.mat(Color(0.92, 0.9, 0.82), 0.95), false, kp, 0.1 * i)
			k.box(Vector3(0.3, 0.2, 0.16), Vector3(0.0, 0.16, 0.3), k.mat(Color(0.3, 0.2, 0.12), 0.7), false, kp)
		"nibs":
			for i in 3:
				k.cyl(0.03, 0.035, 0.12, Vector3(0.28 + i * 0.08, 0.82, -0.18), k.mat([Color(0.6, 0.85, 0.7), Color(0.85, 0.75, 0.5), Color(0.7, 0.7, 0.9)][i], 0.15), dk, false, 10)
			var pc: MeshInstance3D = k.box(Vector3(0.24, 0.05, 0.12), Vector3(0.36, 0.785, 0.12), k.mat(Color(0.3, 0.2, 0.1), 0.6), false, dk, 0.2)
			if pc:
				pass
			for i in 6:
				k.box(Vector3(0.2, 0.05 + 0.02 * float(i % 3), 0.3), Vector3(0.0, 0.03 + i * 0.07, 0.0), k.mat([Color(0.3, 0.32, 0.4), Color(0.5, 0.2, 0.2), Color(0.85, 0.82, 0.7)][i % 3], 0.8), false, kp, 0.05 * i)
		"reginald":
			k.box(Vector3(0.6, 0.06, 0.04), Vector3(0.0, 1.6, 0.36), k.wood_dark, false, kp)
			k.beam(Vector3(-0.3, 1.66, 0.33), Vector3(0.45, 1.66, 0.33), 0.006, k.steel, kp)
			k.sphere(0.04, Vector3(-0.32, 1.66, 0.33), k.brass, kp, Vector3(1, 1, 0.5), 8)
			k.cyl(0.04, 0.04, 0.03, Vector3(0.36, 0.78, -0.15), k.mat(Color(0.75, 0.6, 0.3), 0.3, 0.7), dk, false, 12)
			k.box(Vector3(0.14, 0.18, 0.02), Vector3(0.1, 0.85, -0.22), k.mat(Color(0.78, 0.6, 0.26), 0.35, 0.7), false, dk, 0.3)
			k.box(Vector3(0.1, 0.14, 0.004), Vector3(0.1, 0.85, -0.208), k.mat(Color(0.4, 0.36, 0.34), 0.8), false, dk, 0.3)
		"zuzu":
			k.box(Vector3(0.34, 0.02, 0.24), Vector3(0.1, 0.77, -0.05), k.mat(Color(0.2, 0.2, 0.22), 0.4, 0.4), false, dk)
			var scr: MeshInstance3D = k.box(Vector3(0.34, 0.22, 0.01), Vector3(0.1, 0.88, -0.17), k.glow(Color(0.2, 0.8, 0.85), 1.2), false, dk)
			scr.rotation.x = -0.2
			for i in 3:
				k.cyl(0.033, 0.033, 0.12, Vector3(-0.15 + i * 0.12, 0.06, 0.0), k.mat([Color(0.2, 0.7, 0.3), Color(0.9, 0.2, 0.5), Color(0.2, 0.5, 0.9)][i], 0.3, 0.5), kp, false, 10)
			k.beam(Vector3(0.27, 0.77, -0.1), Vector3(0.5, 0.0, -0.2), 0.006, k.black, dk)
	if bg:
		pass


# =================================================================== Gallery
## A long gallery: portraits of past wardens and officers down the north wall, tall windows over the bay on the south,
## a fireplace with its mantel clock at the east end, and beside it a tall cupboard turned into a darkroom.
## Night 2's prank turns every portrait to the wall (Days 3 and 4), with an old house plan on the back of one.
## Snapjaw turns them back round on Night 4 (story_daily3.gd "day5"), so from Day 5 they face the room.
## Day 6: the mantel clock lies on the hearth, stopped at 11:05. From Day 4 the grate holds ash.
## Anchors: clock, grate, darkroom, portraits, window_seat, bust.
static func _gallery(k) -> void:
	var L := 9.0
	var hw := 3.0
	var H := 4.4
	var day := _day(k)
	var after := _after(k)
	k.environment("indoor", Color(0.64, 0.6, 0.56), 0.48)
	var paper: Material = _wallpaper(k, Color(0.36, 0.42, 0.46), Color(0.48, 0.54, 0.56), 0.3)
	var o := _manor(k, paper, null, "panel", 1.0)
	k.plan([[-L, -hw, L, hw]], 0.0, H, o)
	k.bounds = Vector2(L * 2.0, hw * 2.0)
	_mouldings(k, -L, -hw, L, hw, H, 0.0, 3.2)
	k.door("grand_hall", "", Vector3(-L, 0, 0), PI / 2.0, {"h": 2.3, "w": 1.2})
	# portraits along the north wall (turned to the wall on Days 3 and 4; the house plan is pinned to the back of the fourth)
	var turned := day == 3 or day == 4
	var pt: Node3D = k.hotspot("portraits", Vector3(-1.0, 1.0, -hw + 0.1), Vector3(2.0, 2.0, 0.5), Vector3(0, 1.0, 0.2))
	if pt:
		pass
	for i in 7:
		var x := -7.0 + i * 2.0
		var sz := Vector2(0.95, 1.3) if i % 2 == 0 else Vector2(0.8, 1.05)
		k.painting(Vector3(x, 2.3, -hw), 0.0, sz, "portrait", 50 + i, turned)
		if turned and i == 3:
			k.painting(Vector3(x, 2.3, -hw + 0.035), 0.0, Vector2(0.7, 0.52), "plan", 0)
		k.box(Vector3(0.4, 0.06, 0.02), Vector3(x, 2.3 - sz.y / 2.0 - 0.2, -hw + 0.01), k.brass)
		k.beam(Vector3(x, 3.2, -hw + 0.02), Vector3(x - 0.3, 2.3 + sz.y / 2.0 + 0.04, -hw + 0.02), 0.004, k.brass)
		k.beam(Vector3(x, 3.2, -hw + 0.02), Vector3(x + 0.3, 2.3 + sz.y / 2.0 + 0.04, -hw + 0.02), 0.004, k.brass)
	# the south windows, with window seats
	for i in 3:
		var x := -5.0 + i * 5.0
		k.vista_window(Vector3(x, 2.2, hw - 0.002), PI, Vector2(1.3, 2.2), {"prison_at": 0.1 + i * 0.25, "light": 0.55 if i != 1 else 0.0, "curtains": Color(0.24, 0.3, 0.4), "drop": -0.3})
		var seat: Node3D = k.hotspot("window_seat", Vector3(x, 0, hw - 0.3), Vector3(1.6, 0.8, 0.7), Vector3(0, 0.3, 0)) if i == 0 else Node3D.new()
		if i != 0:
			k.root.add_child(seat)
			seat.position = Vector3(x, 0, hw - 0.3)
		k.box(Vector3(1.5, 0.45, 0.55), Vector3(0, 0.225, 0), k.wood_dark, true, seat)
		k.box(Vector3(1.44, 0.1, 0.5), Vector3(0, 0.5, 0), k.mat(Color(0.3, 0.38, 0.5), 0.9), false, seat)
	# benches down the middle, busts on pedestals, palms
	var velvet: Material = k.mat(Color(0.26, 0.32, 0.44), 0.85)
	for x in [-4.0, 2.0]:
		k.box(Vector3(2.0, 0.42, 0.6), Vector3(x, 0.21, 0.2), velvet, true)
		for sx in [-0.9, 0.9]:
			k.box(Vector3(0.08, 0.1, 0.5), Vector3(x + sx, 0.47, 0.2), k.wood_dark)
	for x in [-1.0, 5.0]:
		var b: Node3D = k.hotspot("bust", Vector3(x, 0, 0.6), Vector3(0.6, 1.8, 0.6), Vector3(0, 0.9, 0)) if x > 0.0 else Node3D.new()
		if x < 0.0:
			k.root.add_child(b)
			b.position = Vector3(x, 0, 0.6)
		k.box(Vector3(0.4, 1.1, 0.4), Vector3(0, 0.55, 0), k.mat(Color(0.86, 0.84, 0.8), 0.4), true, b)
		k.box(Vector3(0.5, 0.06, 0.5), Vector3(0, 1.13, 0), k.mat(Color(0.86, 0.84, 0.8), 0.4), false, b)
		k.sphere(0.16, Vector3(0, 1.4, 0), k.mat(Color(0.8, 0.78, 0.74), 0.5), b, Vector3(1.1, 1.0, 1.0), 14)
		k.box(Vector3(0.32, 0.16, 0.2), Vector3(0, 1.22, 0), k.mat(Color(0.8, 0.78, 0.74), 0.5), false, b)
		for sd in [-0.1, 0.1]:
			k.sphere(0.04, Vector3(sd, 1.56, 0), k.mat(Color(0.8, 0.78, 0.74), 0.5), b, Vector3.ONE, 8)
	k.plant(Vector3(-L + 0.6, 0, -hw + 0.6), 1.1)
	k.plant(Vector3(-L + 0.6, 0, hw - 0.6), 1.1)
	# the east end: fireplace, mantel clock, the grate
	var fpx := L
	k.fireplace(Vector3(fpx, 0, 0.0), -PI / 2.0, 2.0, false, k.mat(Color(0.86, 0.84, 0.8), 0.35))
	k.painting(Vector3(fpx, 2.5, 0.0), -PI / 2.0, Vector2(1.6, 1.1), "sea", 9)
	var ck: Node3D = k.hotspot("clock", Vector3(fpx - 0.2, 1.0, 0.0), Vector3(0.6, 0.9, 1.0), Vector3(0, 0.3, 0), -PI / 2.0)
	if not after:
		var ct: Vector2 = k.get_meta("gallery_clock", Vector2(3.0, 12.0))
		k.mantel_clock(Vector3(fpx - 0.2, 1.21, 0.0), -PI / 2.0, ct.x, ct.y)
	else:
		var fallen: Node3D = k.mantel_clock(Vector3(fpx - 0.55, 0.04, 0.35), -PI / 2.0 + 0.4, 11.0, 5.0)
		fallen.rotation.z = 0.0
		k.box(Vector3(0.006, 0.12, 0.004), Vector3(fpx - 0.47, 0.34, 0.33), k.white, false, null, -PI / 2.0 + 0.4)
	if ck:
		pass
	var gr: Node3D = k.hotspot("grate", Vector3(fpx - 0.25, 0, -0.55), Vector3(0.5, 0.7, 0.9), Vector3(0, 0.35, 0.3), -PI / 2.0)
	if day >= 4:
		var ash: Material = k.mat(Color(0.22, 0.21, 0.2), 0.95)
		for i in 6:
			k.sphere(0.06, Vector3(fpx - 0.18, 0.15, -0.2 + i * 0.08), ash, null, Vector3(1.3, 0.35, 1.0), 8)
		k.box(Vector3(0.09, 0.004, 0.07), Vector3(fpx - 0.24, 0.17, 0.05), k.mat(Color(0.86, 0.82, 0.7), 0.95), false, null, 0.5)
	if gr:
		pass
	for sd in [-1.0, 1.0]:
		k.sconce(Vector3(fpx, 2.3, sd * 1.5), -PI / 2.0, LAMP, 0.6, 5.0)
	# the darkroom: a tall cupboard on the north wall by the fireplace, door ajar, a red safelight inside
	var dr: Node3D = k.hotspot("darkroom", Vector3(6.6, 0, -hw), Vector3(1.6, 2.4, 0.9), Vector3(0, 1.2, 0.35))
	k.box(Vector3(1.5, 2.5, 0.02), Vector3(0, 1.25, 0.01), k.mat(Color(0.05, 0.03, 0.03), 0.9), false, dr)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.08, 2.5, 0.62), Vector3(sd * 0.79, 1.25, 0.31), k.wood_dark, false, dr)
	k.box(Vector3(1.66, 0.1, 0.66), Vector3(0, 2.55, 0.33), k.wood_dark, false, dr)
	k.box(Vector3(1.5, 0.04, 0.58), Vector3(0, 0.9, 0.3), k.wood_mid, false, dr)
	for i in 3:
		k.box(Vector3(0.36, 0.05, 0.26), Vector3(-0.5 + i * 0.45, 0.945, 0.3), k.mat([Color(0.85, 0.85, 0.82), Color(0.6, 0.62, 0.6), Color(0.75, 0.55, 0.3)][i], 0.3), false, dr)
	k.beam(Vector3(-0.7, 2.0, 0.3), Vector3(0.7, 2.0, 0.3), 0.004, k.mat(Color(0.9, 0.9, 0.85), 0.9), dr)
	for i in 5:
		k.box(Vector3(0.14, 0.18, 0.003), Vector3(-0.56 + i * 0.28, 1.88, 0.3), k.mat(Color(0.86, 0.84, 0.8) if i % 2 == 0 else Color(0.3, 0.28, 0.27), 0.9), false, dr)
		k.box(Vector3(0.03, 0.04, 0.02), Vector3(-0.56 + i * 0.28, 1.98, 0.3), k.wood_light, false, dr)
	k.sphere(0.06, Vector3(0.0, 2.35, 0.1), k.glow(Color(0.9, 0.08, 0.05), 3.0), dr, Vector3.ONE, 10)
	k.omni(Vector3(6.6, 2.0, -hw + 0.6), Color(0.9, 0.18, 0.1), 0.35, 2.4)
	var leaf_pv := Node3D.new()
	leaf_pv.position = Vector3(0.75, 0, 0.62)
	leaf_pv.rotation.y = -1.1
	dr.add_child(leaf_pv)
	k.box(Vector3(0.74, 2.4, 0.04), Vector3(-0.37, 1.22, 0.0), k.wood_mid, false, leaf_pv)
	k.blocker(Vector3(1.66, 2.5, 0.66), Vector3(6.6, 1.25, -hw + 0.33))
	k.chandelier(Vector3(-4.0, 3.5, 0), H, WARM, 1.3, 9.0, true, 8, 0.9)
	k.chandelier(Vector3(3.0, 3.5, 0), H, WARM, 1.3, 9.0, false, 8, 0.9)
	k.cctv(Vector3(-L, 3.2, -hw + 0.4), PI / 2.0, 0.6)
	_crest(k, Vector3(-L, 3.0, 1.6), PI / 2.0, 0.8)
	_crack(k, Vector3(-2.5, H - 0.1, hw), PI, 1.8, Vector2(-0.3, -1.0), 61)
	if after:
		for x in [-6.0, -1.0, 4.0, 7.0]:
			k.dust(Vector3(x, 0.016, 0.0), Vector2(3.0, 4.0), 0.4)
	_spots(k, [Vector3(-6.0, 0, -1.4), Vector3(0.0, 0, -1.4), Vector3(4.0, 0, 1.6), Vector3(7.4, 0, 1.8)])
	_guests(k, "gallery", {"a": Vector3(5.6, 0, -0.9)})
	k.spawn = Vector3(-L + 1.3, 0, 0)
	k.look = Vector3(L, 1.4, 0)


# =================================================================== Attic
## Under the roof: a long gable with rafters, a round window at the far end, trunks and the prison's old record boxes
## along the low sides. Zuzu has set up a corner here, wired to a camera they have killed.
## Anchors: zuzu_desk, bait_tin, dead_camera, trunks, rocking_horse.
static func _attic(k) -> void:
	var L := 8.0
	var hw := 5.0
	var ridge := 5.6
	var eave := 1.6
	var after := _after(k)
	k.environment("dim", Color(0.56, 0.52, 0.48), 0.44)
	var floor_m: Material = k.wood_floor(Color(0.28, 0.2, 0.14), Color(0.42, 0.32, 0.22), 0.22)
	k.slab(-L, -hw, L, hw, 0.0, floor_m)
	k.bounds = Vector2(L * 2.0, hw * 2.0)
	var roof_m: Material = k.wood_wall(Color(0.24, 0.17, 0.12), Color(0.36, 0.26, 0.18), 0.3)
	var slope := atan2(ridge - eave, hw)
	var rl := sqrt(hw * hw + (ridge - eave) * (ridge - eave))
	for sd in [-1.0, 1.0]:
		var r: MeshInstance3D = Kit.arch(k.box(Vector3(L * 2.0, 0.12, rl + 0.1), Vector3(0, (ridge + eave) / 2.0 + 0.06, sd * hw / 2.0), roof_m), "roof")
		r.rotation.x = sd * slope
		Kit.arch(k.box(Vector3(L * 2.0, eave, 0.2), Vector3(0, eave / 2.0, sd * (hw + 0.1)), roof_m, true), "wall")
	# gable walls with their triangles above the eaves
	var gable: Material = k.mat(Color(0.5, 0.44, 0.38), 0.95)
	for sx in [-1.0, 1.0]:
		Kit.arch(k.box(Vector3(0.2, eave, hw * 2.0), Vector3(sx * (L + 0.1), eave / 2.0, 0), gable, true), "wall")
		for i in 8:
			var y0 := eave + i * (ridge - eave) / 8.0
			var half := hw * (1.0 - (float(i) + 0.5) / 8.0)
			Kit.arch(k.box(Vector3(0.2, (ridge - eave) / 8.0, half * 2.0), Vector3(sx * (L + 0.1), y0 + (ridge - eave) / 16.0, 0), gable, true), "wall")
	# rafters, the ridge beam, collar ties
	var timber: Material = k.mat(Color(0.3, 0.2, 0.13), 0.9)
	k.box(Vector3(L * 2.0, 0.2, 0.16), Vector3(0, ridge - 0.12, 0), timber)
	for i in 9:
		var x := -L + 1.0 + i * 1.75
		for sd in [-1.0, 1.0]:
			var rf: MeshInstance3D = Kit.arch(k.box(Vector3(0.1, 0.14, rl - 0.2), Vector3(x, (ridge + eave) / 2.0 - 0.1, sd * hw / 2.0), timber), "roof")
			rf.rotation.x = sd * slope
		if i % 2 == 0:
			k.box(Vector3(0.08, 0.12, 2.6), Vector3(x, 4.5, 0), timber)
	# low knee walls of junk keep you where the roof is high enough to stand
	var trunk_c := [Color(0.42, 0.26, 0.14), Color(0.3, 0.3, 0.34), Color(0.5, 0.32, 0.2), Color(0.28, 0.36, 0.3)]
	for sd in [-1.0, 1.0]:
		for i in 7:
			var x := -L + 1.2 + i * 2.2
			var sz := Vector3(1.0 + 0.3 * _h(i * 5 + int(sd)), 0.5 + 0.25 * _h(i * 3), 0.7)
			k.box(sz, Vector3(x, sz.y / 2.0, sd * 3.45), k.mat(trunk_c[(i + int(sd)) % 4], 0.7), true)
			k.box(Vector3(sz.x + 0.02, 0.05, sz.z + 0.02), Vector3(x, sz.y * 0.75, sd * 3.45), k.mat(Color(0.6, 0.5, 0.3), 0.4, 0.7))
			if i % 2 == 0:
				k.box(Vector3(0.6, 0.4, 0.5), Vector3(x + 0.1, sz.y + 0.2, sd * 3.5), k.mat(Color(0.62, 0.52, 0.36), 0.95))
		k.blocker(Vector3(L * 2.0, 1.4, 1.2), Vector3(0, 0.7, sd * 3.9))
	var tk: Node3D = k.hotspot("trunks", Vector3(-3.4, 0, -3.0), Vector3(1.4, 1.0, 0.6), Vector3(0, 0.5, 0))
	if tk:
		pass
	# the round window at the east gable, the stair door at the west
	var ow := Node3D.new()
	ow.position = Vector3(L - 0.002, 3.0, 0)
	ow.rotation.y = -PI / 2.0
	k.root.add_child(ow)
	k.torus(0.62, 0.72, Vector3(0, 0, 0.05), k.wood_dark, ow, Vector3(PI / 2.0, 0, 0))
	var oculus: MeshInstance3D = k.cyl(0.62, 0.62, 0.01, Vector3(0, 0, 0.012), k.smat(Kit.SH_VISTA, {"prison_at": 0.3}), ow, false, 32)
	oculus.rotation.x = PI / 2.0
	for a in [0.0, PI / 2.0]:
		var bar: MeshInstance3D = k.box(Vector3(1.24, 0.04, 0.04), Vector3(0, 0, 0.04), k.wood_dark, false, ow)
		bar.rotation.z = a
	k.omni(Vector3(L - 1.0, 3.0, 0), SEA_LIGHT, 0.7, 6.0)
	k.door("bedroom_wing", "Attic Stairs", Vector3(-L, 0, 0), PI / 2.0, {"mat": k.wood_dark})
	# Zuzu's corner: a board across two crates, a laptop, a tangle of cable up to a camera on the rafter
	var zd: Node3D = k.hotspot("zuzu_desk", Vector3(4.6, 0, -1.9), Vector3(1.6, 1.2, 0.9), Vector3(0, 0.6, 0))
	for sx in [-0.55, 0.55]:
		k.box(Vector3(0.4, 0.66, 0.5), Vector3(sx, 0.33, 0), k.mat(Color(0.55, 0.42, 0.26), 0.9), true, zd)
	k.box(Vector3(1.6, 0.04, 0.7), Vector3(0, 0.68, 0), k.wood_light, false, zd)
	k.blocker(Vector3(1.6, 0.7, 0.7), Vector3(4.6, 0.35, -1.9))
	k.box(Vector3(0.36, 0.02, 0.25), Vector3(-0.1, 0.71, 0.05), k.mat(Color(0.18, 0.18, 0.2), 0.4, 0.5), false, zd)
	var lap: MeshInstance3D = k.box(Vector3(0.36, 0.24, 0.012), Vector3(-0.1, 0.82, -0.08), k.glow(Color(0.15, 0.85, 0.75), 1.0), false, zd)
	lap.rotation.x = -0.25
	for i in 3:
		k.cyl(0.033, 0.033, 0.12, Vector3(0.4 + i * 0.09, 0.76, 0.1), k.mat([Color(0.2, 0.7, 0.3), Color(0.9, 0.2, 0.5), Color(0.2, 0.5, 0.9)][i], 0.3, 0.5), zd, false, 10)
	k.stool(Vector3(4.6, 0, -1.1), k.wood_mid, 0.5)
	k.desk_lamp(Vector3(5.2, 0.7, -2.0), PI, null, 0.6, Color(0.7, 0.95, 1.0))
	var cam_p := Vector3(5.2, 4.25, -2.0)
	var dc: Node3D = k.hotspot("dead_camera", cam_p + Vector3(0, -0.6, 0), Vector3(0.6, 0.7, 0.6), Vector3(0, 0.35, 0))
	if dc:
		pass
	k.box(Vector3(0.16, 0.14, 0.32), cam_p + Vector3(0, -0.12, 0), k.mat(Color(0.12, 0.13, 0.12), 0.4, 0.4))
	k.box(Vector3(0.2, 0.02, 0.36), cam_p + Vector3(0, -0.04, 0), k.mat(Color(0.2, 0.42, 0.22), 0.5))
	k.beam(cam_p + Vector3(0, -0.03, 0), cam_p + Vector3(0, 0.25, 0), 0.02, k.black)
	k.cyl(0.05, 0.05, 0.03, cam_p + Vector3(0, -0.12, 0.17), k.mat(Color(0.3, 0.32, 0.34), 0.6), null, false, 10).rotation.x = PI / 2.0
	k.beam(cam_p + Vector3(0.06, -0.15, -0.15), Vector3(4.9, 0.71, -2.1), 0.007, k.black)
	k.beam(cam_p + Vector3(0.06, -0.15, -0.15), cam_p + Vector3(0.2, -0.5, -0.1), 0.007, k.black)
	# the rat-bait tins on a shelf nailed to the rafter, and the rest of the attic's clutter
	var bt: Node3D = k.hotspot("bait_tin", Vector3(-1.2, 0, -2.6), Vector3(0.9, 1.3, 0.6), Vector3(0, 0.65, 0))
	k.box(Vector3(0.7, 0.9, 0.4), Vector3(0, 0.45, 0), k.mat(Color(0.4, 0.3, 0.2), 0.8), true, bt)
	for i in 2:
		k.cyl(0.08, 0.08, 0.1, Vector3(-0.15 + i * 0.3, 0.95, 0.0), k.mat(Color(0.82, 0.72, 0.2), 0.4, 0.6), bt, false, 14)
		k.cyl(0.075, 0.075, 0.05, Vector3(-0.15 + i * 0.3, 0.95, 0.0), k.mat(Color(0.2, 0.4, 0.2), 0.6), bt, false, 14)
	var rh: Node3D = k.hotspot("rocking_horse", Vector3(-5.2, 0, 2.2), Vector3(1.2, 1.2, 0.6), Vector3(0, 0.6, 0), 0.3)
	for sd in [-0.18, 0.18]:
		k.box(Vector3(1.3, 0.06, 0.04), Vector3(0, 0.03, sd), k.wood_dark, false, rh)
	k.box(Vector3(0.8, 0.3, 0.26), Vector3(0, 0.6, 0), k.mat(Color(0.9, 0.86, 0.78), 0.8), true, rh)
	k.box(Vector3(0.18, 0.4, 0.16), Vector3(0.42, 0.85, 0), k.mat(Color(0.9, 0.86, 0.78), 0.8), false, rh)
	k.box(Vector3(0.3, 0.14, 0.14), Vector3(0.55, 1.05, 0), k.mat(Color(0.9, 0.86, 0.78), 0.8), false, rh)
	for sd in [-0.3, 0.3]:
		for sz in [-0.18, 0.18]:
			k.box(Vector3(0.05, 0.42, 0.05), Vector3(sd, 0.27, sz), k.mat(Color(0.9, 0.86, 0.78), 0.8), false, rh)
	var form := Vector3(1.6, 0, 2.6)
	k.cyl(0.015, 0.015, 1.1, form + Vector3(0, 0.55, 0), k.wood_dark, null, false, 8)
	k.cyl(0.2, 0.22, 0.03, form + Vector3(0, 0.015, 0), k.wood_dark, null, false, 12)
	k.sphere(0.24, form + Vector3(0, 1.3, 0), k.mat(Color(0.82, 0.76, 0.66), 0.9), null, Vector3(1.0, 1.3, 0.7), 12)
	k.blocker(Vector3(0.5, 1.6, 0.4), form + Vector3(0, 0.8, 0))
	var cage := Vector3(-2.6, 0, 2.7)
	k.cyl(0.2, 0.22, 0.04, cage + Vector3(0, 0.02, 0), k.brass, null, false, 12)
	for i in 10:
		var a := i * TAU / 10.0
		k.beam(cage + Vector3(cos(a) * 0.2, 0.04, sin(a) * 0.2), cage + Vector3(cos(a) * 0.05, 0.6, sin(a) * 0.05), 0.004, k.brass)
	for x in [-5.5, -2.0, 1.5, 4.5]:
		k.flickers.append(k.bulb(Vector3(x, 3.7, 0), ridge - 0.22, Color(1.0, 0.82, 0.55), 1.0, 7.0, x == 1.5))
	# more of the house's forgotten things: stacked chairs, picture frames leaning, record boxes, rolled carpets
	var box_m: Material = k.mat(Color(0.6, 0.5, 0.34), 0.95)
	for i in 10:
		var x := -6.6 + i * 1.4
		var z := 2.75 if i % 2 == 0 else -2.75
		if absf(x - 4.6) < 1.2 and z < 0.0:
			continue
		for j in 2:
			k.box(Vector3(0.42, 0.3, 0.32), Vector3(x + 0.04 * j, 0.15 + j * 0.3, z), box_m, j == 0, null, 0.08 * j)
			k.box(Vector3(0.2, 0.08, Kit.LAYER), Vector3(x + 0.04 * j, 0.2 + j * 0.3, z + (0.162 if z < 0.0 else -0.162)), k.paper, false, null, 0.08 * j)
	for i in 4:
		var fr: MeshInstance3D = k.box(Vector3(0.7, 0.9, 0.05), Vector3(-6.8 + i * 0.12, 0.44, -2.6), k.mat(Color(0.7, 0.55, 0.25), 0.4, 0.6), false, null, PI / 2.0)
		fr.rotation.z = 0.12
	for i in 3:
		var ch := Vector3(-0.2 + i * 0.6, 0, 2.7)
		k.chair(ch, PI, k.mat(Color(0.4, 0.3, 0.3), 0.85), k.wood_dark)
	for i in 3:
		k.cyl(0.14, 0.14, 1.6, Vector3(6.6, 0.14 + i * 0.27, 2.6), k.mat([Color(0.5, 0.2, 0.2), Color(0.3, 0.3, 0.5), Color(0.5, 0.45, 0.3)][i], 0.95), null, false, 12).rotation.z = PI / 2.0
	k.blocker(Vector3(1.6, 0.82, 0.3), Vector3(6.6, 0.41, 2.6))
	if after:
		for x in [-5.0, 0.0, 4.0]:
			k.dust(Vector3(x, 0.016, 0), Vector2(3.4, 4.2), 0.4)
	_spots(k, [Vector3(-3.0, 0, 0.6), Vector3(2.0, 0, -0.8), Vector3(5.6, 0, 1.0)])
	k.spawn = Vector3(-L + 1.3, 0, 0)
	k.look = Vector3(L, 2.2, 0)


# =================================================================== Dining Room and the cloakroom outside it
## From the Grand Hall you come into the cloakroom, with a brass hook and a name card for every guest, then through an
## arch into the Dining Room: one long table, the tall clock on the north wall that every sketch of dinner shows, a
## sideboard, a fireplace at the far end, windows over the sea. A service door leads to the kitchen.
## Anchors: coat_hooks, watch_roster (from Day 2), dining_table, dining_clock, sideboard.
static func _dining(k) -> void:
	var day := _day(k)
	var after := _after(k)
	k.environment("indoor", Color(0.62, 0.55, 0.5), 0.46)
	var paper: Material = _wallpaper(k, Color(0.34, 0.08, 0.1), Color(0.5, 0.2, 0.18), 0.3)
	var o := _manor(k, paper, null, "panel", 1.1)
	var cx0 := -9.5
	k.plan([[cx0, -1.6, -5.0, 1.6, 3.4], [-5.0, -4.0, 7.0, 4.0, 4.2]], 0.0, 4.2, o)
	k.bounds = Vector2(16.5, 8.0)
	# narrow the join to an arch with pilasters
	for sd in [-1.0, 1.0]:
		Kit.arch(k.box(Vector3(0.3, 3.4, 0.5), Vector3(-5.0, 1.7, sd * 1.35), paper, true), "wall")
		k.box(Vector3(0.36, 3.4, 0.06), Vector3(-5.0, 1.7, sd * 1.07), k.wood_dark)
	k.box(Vector3(0.36, 0.3, 2.2), Vector3(-5.0, 3.25, 0), k.wood_dark)
	k.box(Vector3(0.3, 0.8, 2.08), Vector3(-5.0, 3.0, 0), paper)
	_mouldings(k, -5.0, -4.0, 7.0, 4.0, 4.2)
	k.door("grand_hall", "", Vector3(cx0, 0, 0), PI / 2.0, {"h": 2.3, "w": 1.2})
	# the coat hooks: six on the north wall, five on the south; name cards from Day 2, when the house rule starts
	var names_n := ["Mochi", "Bramble", "Bruno", "Duchess", "Fennel", "Grub"]
	var names_s := ["Lulu", "Nibs", "Pepper", "Reginald", "Zuzu"]
	var coat_cols := [Color(0.3, 0.4, 0.6), Color(0.3, 0.45, 0.26), Color(0.55, 0.15, 0.12), Color(0.5, 0.36, 0.6), Color(0.6, 0.36, 0.22),
		Color(0.85, 0.5, 0.3), Color(0.9, 0.55, 0.72), Color(0.45, 0.5, 0.55), Color(0.62, 0.45, 0.25), Color(0.7, 0.6, 0.25), Color(0.2, 0.55, 0.62)]
	var cn: Array = []
	var cs: Array = []
	for i in 6:
		cn.append(coat_cols[i] if day >= 2 and day <= 5 and i % 3 != 1 else null)
	for i in 5:
		cs.append(coat_cols[6 + i] if day >= 2 and day <= 5 and i % 2 == 0 else null)
	var hk: Node3D = k.hotspot("coat_hooks", Vector3(-7.3, 0.9, -1.6), Vector3(2.8, 1.6, 0.6), Vector3(0, 0.8, 0.3))
	if hk:
		pass
	k.coat_rail(Vector3(-7.25, 1.75, -1.6), 0.0, cn, names_n if day >= 2 else [], 0.42)
	k.coat_rail(Vector3(-7.25, 1.75, 1.6), PI, cs, names_s if day >= 2 else [], 0.5)
	k.box(Vector3(2.4, 0.3, 0.36), Vector3(-7.25, 0.15, -1.42), k.wood_dark, true)
	k.box(Vector3(2.4, 0.3, 0.36), Vector3(-7.25, 0.15, 1.42), k.wood_dark, true)
	for i in 4:
		k.sphere(0.07, Vector3(-8.1 + i * 0.5, 0.33, -1.42), k.mat(Color(0.2, 0.14, 0.1), 0.6), null, Vector3(1.6, 0.6, 0.9), 8)
	k.cyl(0.13, 0.11, 0.6, Vector3(-9.1, 0.3, -1.25), k.mat(Color(0.24, 0.3, 0.26), 0.5), null, true, 14)
	for i in 3:
		k.beam(Vector3(-9.1 + 0.03 * i, 0.3, -1.25), Vector3(-9.1 + 0.08 * (i - 1), 0.98, -1.25 + 0.04 * i), 0.012, k.mat([Color(0.2, 0.2, 0.25), Color(0.5, 0.1, 0.1), Color(0.1, 0.25, 0.4)][i], 0.6))
	if day >= 2:
		var wr: Node3D = k.hotspot("watch_roster", Vector3(-5.6, 1.4, -1.6), Vector3(0.5, 0.6, 0.4), Vector3(0, 0, 0.2))
		k.box(Vector3(0.3, 0.42, 0.02), Vector3(0, 0, 0.01), k.wood_light, false, wr)
		k.box(Vector3(0.26, 0.36, 0.006), Vector3(0, -0.02, 0.023), k.paper, false, wr)
		k.box(Vector3(0.1, 0.04, 0.02), Vector3(0, 0.19, 0.03), k.steel, false, wr)
		for i in 7:
			k.box(Vector3(0.2, 0.01, Kit.LAYER), Vector3(-0.01, 0.12 - i * 0.04, 0.0265 + Kit.LAYER), k.mat(Color(0.25, 0.25, 0.4), 0.9), false, wr)
		k.beam(Vector3(0.14, 0.16, 0.03), Vector3(0.14, -0.4, 0.04), 0.004, k.black, wr)
		k.cyl(0.006, 0.006, 0.12, Vector3(0.14, -0.44, 0.04), k.mat(Color(0.12, 0.12, 0.14), 0.3), wr, false, 6)
	k.hanging_lamp(Vector3(-7.25, 2.8, 0), WARM, 0.9, 3.4, false, 6.0)
	k.painting(Vector3(cx0, 2.3, -1.0), PI / 2.0, Vector2(0.5, 0.4), "still", 70)
	# the Dining Room: the long table and its chairs
	var tb: Node3D = k.hotspot("dining_table", Vector3(1.0, 0, 0), Vector3(1.0, 1.0, 1.0), Vector3(0, 0.5, 0))
	if tb:
		pass
	k.box(Vector3(7.6, 0.08, 1.4), Vector3(1.0, 0.76, 0), k.wood_dark, false)
	k.box(Vector3(7.7, 0.012, 1.0), Vector3(1.0, 0.806, 0), k.mat(Color(0.94, 0.92, 0.86), 0.9))
	for x in [-2.4, 1.0, 4.4]:
		k.box(Vector3(0.5, 0.72, 0.5), Vector3(x, 0.36, 0), k.wood_dark)
	k.blocker(Vector3(7.6, 0.8, 1.4), Vector3(1.0, 0.4, 0))
	for i in 5:
		var x := -1.6 + i * 1.3
		for sd in [-1.0, 1.0]:
			k.chair(Vector3(x, 0, sd * 1.05), 0.0 if sd > 0.0 else PI, k.mat(Color(0.4, 0.08, 0.1), 0.85), k.wood_dark)
			if day >= 2 and not after:
				k.cyl(0.13, 0.12, 0.012, Vector3(x, 0.818, sd * 0.38), k.white, null, false, 16)
				k.box(Vector3(0.02, 0.006, 0.18), Vector3(x + 0.2, 0.815, sd * 0.38), k.mat(Color(0.75, 0.75, 0.78), 0.2, 0.8))
	k.chair(Vector3(-3.0, 0, 0), PI / 2.0, k.mat(Color(0.4, 0.08, 0.1), 0.85), k.wood_dark)
	k.chair(Vector3(5.0, 0, 0), -PI / 2.0, k.mat(Color(0.4, 0.08, 0.1), 0.85), k.wood_dark)
	for x in [-1.0, 1.0, 3.0]:
		k.cyl(0.06, 0.08, 0.03, Vector3(x, 0.825, 0), k.brass, null, false, 12)
		k.cyl(0.015, 0.02, 0.3, Vector3(x, 0.99, 0), k.brass, null, false, 8)
		k.cyl(0.014, 0.014, 0.12, Vector3(x, 1.2, 0), k.mat(Color(0.95, 0.92, 0.84), 0.6), null, false, 8)
	k.cyl(0.24, 0.2, 0.1, Vector3(2.0, 0.86, 0), k.mat(Color(0.9, 0.88, 0.82), 0.3), null, false, 18)
	for i in 5:
		k.sphere(0.06, Vector3(1.92 + 0.05 * (i % 3), 0.93 + 0.02 * (i % 2), -0.06 + 0.05 * (i / 2)), k.mat([Color(0.8, 0.2, 0.15), Color(0.95, 0.7, 0.2), Color(0.5, 0.7, 0.2)][i % 3], 0.6), null, Vector3.ONE, 8)
	# the clock, the sideboard, the fireplace, the service door to the kitchen
	var dc: Node3D = k.hotspot("dining_clock", Vector3(1.0, 0, -4.0), Vector3(0.8, 2.4, 0.7), Vector3(0, 1.2, 0.3))
	if dc:
		pass
	k.longcase_clock(Vector3(1.0, 0, -4.0), 0.0, 3.0, 50.0)
	var sb: Node3D = k.hotspot("sideboard", Vector3(4.5, 0, -4.0), Vector3(2.2, 1.2, 0.8), Vector3(0, 0.6, 0.3))
	k.box(Vector3(2.0, 0.9, 0.55), Vector3(0, 0.45, 0.275), k.wood_mid, true, sb)
	k.box(Vector3(2.1, 0.05, 0.6), Vector3(0, 0.925, 0.3), k.wood_dark, false, sb)
	for i in 3:
		k.box(Vector3(0.6, 0.7, 0.02), Vector3(-0.66 + i * 0.66, 0.45, 0.56), k.wood_dark, false, sb)
		k.sphere(0.02, Vector3(-0.66 + i * 0.66 + 0.22, 0.6, 0.575), k.brass, sb, Vector3.ONE, 6)
	for i in 3:
		k.cyl(0.14, 0.14, 0.03, Vector3(-0.6 + i * 0.6, 0.965, 0.3), k.mat(Color(0.8, 0.8, 0.84), 0.2, 0.8), sb, false, 16)
	k.cyl(0.06, 0.08, 0.3, Vector3(0.8, 1.1, 0.3), k.mat(Color(0.3, 0.06, 0.1), 0.1), sb, false, 10)
	k.painting(Vector3(4.5, 2.4, -4.0), 0.0, Vector2(1.6, 1.1), "still", 71)
	_page(k, Vector3(4.92, 1.85, -4.0), 0.0)
	k.fireplace(Vector3(7.0, 0, 0), -PI / 2.0, 2.0, true, k.mat(Color(0.86, 0.84, 0.8), 0.35))
	k.painting(Vector3(7.0, 2.5, 0), -PI / 2.0, Vector2(1.0, 1.3), "portrait", 72)
	k.mantel_clock(Vector3(6.8, 1.21, -0.7), -PI / 2.0, 3.0, 50.0)
	k.door("kitchen", "", Vector3(-3.6, 0, -4.0), 0.0, {"mat": k.mat(Color(0.12, 0.3, 0.16), 0.9), "panels": false})
	for x in [-2.0, 4.0]:
		k.vista_window(Vector3(x, 2.1, 4.0 - 0.002), PI, Vector2(1.3, 2.2), {"prison_at": 0.2 if x > 0.0 else -0.4, "light": 0.5, "curtains": Color(0.42, 0.1, 0.12)})
	_rug(k, Vector3(1.0, 0, 0), Vector2(8.6, 3.2), Color(0.24, 0.12, 0.16), GILT)
	k.chandelier(Vector3(-0.8, 3.3, 0), 4.2, WARM, 1.5, 9.0, true, 8, 0.9)
	k.chandelier(Vector3(2.8, 3.3, 0), 4.2, WARM, 1.2, 9.0, false, 8, 0.9)
	k.sconce(Vector3(-5.0, 2.4, -3.2), 0.0, LAMP, 0.0, 4.0)
	k.sconce(Vector3(7.0, 2.4, 2.6), -PI / 2.0, LAMP, 0.6, 5.0)
	k.cctv(Vector3(-5.0, 3.6, 3.6), PI / 2.0, 0.4)
	_crest(k, Vector3(-5.0, 3.75, 0), PI / 2.0, 0.7)
	k.plant(Vector3(6.4, 0, 3.4), 1.0)
	_crack(k, Vector3(-4.6, 4.1, -4.0), 0.0, 1.6, Vector2(0.2, -1.0), 81)
	if after:
		for x in [-3.0, 2.0, 5.5]:
			k.dust(Vector3(x, 0.02, 2.2), Vector2(3.0, 2.6), 0.4)
		k.dust(Vector3(-7.2, 0.016, 0), Vector2(3.6, 2.6), 0.4)
	_spots(k, [Vector3(-2.2, 0, 2.6), Vector3(4.0, 0, 2.6), Vector3(-7.25, 0, 0.0), Vector3(1.0, 0, -2.6)])
	_guests(k, "dining_room", {"a": Vector3(-1.0, 0, 2.7)})
	k.spawn = Vector3(cx0 + 1.2, 0, 0)
	k.look = Vector3(4.0, 1.2, 0)


# =================================================================== Kitchen and pantry
## A big working kitchen: the range under its hood, a scrubbed table, a dresser of plates, copper pans on a rack, a sink
## under the window. Through a door gap, the pantry: newspaper-lined shelves, the dumbwaiter hatch with its bell and the
## bell's paper tape, and below the hatch sill the bottom of the shaft.
## Anchors: stove, soup_pot, kitchen_table, dresser, knife_block, sink, pantry_shelf, hatch, hatch_rope, bell_tape, shaft_bottom.
static func _kitchen(k) -> void:
	var after := _after(k)
	k.environment("indoor", Color(0.64, 0.6, 0.54), 0.5)
	var tile: Material = k.stone_floor(Color(0.5, 0.42, 0.36), Color(0.64, 0.56, 0.48), 0.5)
	var wall: Material = k.mat(Color(0.86, 0.84, 0.76), 0.92)
	var o := {"floor": tile, "wall": wall, "wain": k.mat(Color(0.3, 0.5, 0.48), 0.5), "wain_h": 1.2, "trim": k.mat(Color(0.24, 0.36, 0.34), 0.6),
		"ceiling": _ceil(k)}
	# the pantry is its own little room through a doorway in a 20 cm partition
	k.plan([[-5.0, -3.6, 5.0, 3.6], [5.0, -2.1, 5.2, -0.9], [5.2, -3.4, 8.4, -0.6]], 0.0, 3.6, o)
	k.bounds = Vector2(13.4, 7.2)
	Kit.arch(k.box(Vector3(0.2, 1.3, 1.2), Vector3(5.1, 2.95, -1.5), wall), "wall")
	k.portal(Vector3(5.1, 0, -1.5), PI / 2.0, 1.2, 2.3, 0.34, k.wood_dark)
	k.door("grand_hall", "", Vector3(-3.4, 0, 3.6), PI, {"mat": k.mat(Color(0.12, 0.3, 0.16), 0.9), "panels": false})
	k.door("dining_room", "", Vector3(-5.0, 0, -1.6), PI / 2.0, {"mat": k.mat(Color(0.12, 0.3, 0.16), 0.9), "panels": false})
	k.door("wine_cellar", "Cellar Stairs", Vector3(2.4, 0, 3.6), PI, {"mat": k.wood_dark})
	# the range under its hood, the soup pot
	var st: Node3D = k.hotspot("stove", Vector3(-1.0, 0, -3.6), Vector3(2.2, 0.86, 1.0), Vector3(0, 0.43, 0.45))
	var iron: Material = k.mat(Color(0.12, 0.12, 0.13), 0.5, 0.5)
	k.box(Vector3(2.0, 0.9, 0.75), Vector3(0, 0.45, 0.375), iron, true, st)
	k.box(Vector3(2.06, 0.05, 0.8), Vector3(0, 0.925, 0.4), k.mat(Color(0.2, 0.2, 0.22), 0.4, 0.7), false, st)
	for i in 3:
		k.box(Vector3(0.5, 0.4, 0.02), Vector3(-0.66 + i * 0.66, 0.42, 0.76), k.mat(Color(0.2, 0.2, 0.22), 0.4, 0.6), false, st)
		k.box(Vector3(0.16, 0.03, 0.03), Vector3(-0.66 + i * 0.66, 0.6, 0.78), k.brass, false, st)
	k.box(Vector3(0.3, 0.08, 0.02), Vector3(-0.66, 0.3, 0.775), k.glow(Color(1.0, 0.42, 0.1), 2.0), false, st)
	k.box(Vector3(2.2, 0.6, 0.9), Vector3(0, 2.6, 0.45), k.mat(Color(0.5, 0.36, 0.24), 0.4, 0.7), false, st)
	k.box(Vector3(0.6, 0.7, 0.5), Vector3(0, 3.25, 0.25), k.mat(Color(0.5, 0.36, 0.24), 0.4, 0.7), false, st)
	k.box(Vector3(2.4, 0.05, 0.1), Vector3(0, 2.3, 0.92), k.brass, false, st)
	var sp: Node3D = k.hotspot("soup_pot", Vector3(-0.5, 0.95, -3.2), Vector3(0.6, 0.6, 0.6), Vector3(0, 0.25, 0))
	k.cyl(0.24, 0.22, 0.34, Vector3(0, 0.17, 0), k.mat(Color(0.6, 0.62, 0.64), 0.3, 0.7), sp, false, 18)
	k.cyl(0.22, 0.22, 0.01, Vector3(0, 0.32, 0), k.mat(Color(0.75, 0.55, 0.25), 0.5), sp, false, 18)
	k.beam(Vector3(0.1, 0.33, 0), Vector3(0.35, 0.75, 0.1), 0.012, k.wood_light, sp)
	k.steam(Vector3(-0.5, 1.35, -3.2), Vector3(0.12, 0.02, 0.12), 8, 0.4, 0.12, 0.3, 2.0)
	k.cyl(0.18, 0.16, 0.18, Vector3(-1.5, 1.04, -3.25), k.mat(Color(0.65, 0.35, 0.15), 0.3, 0.8), null, false, 16)
	# the long scrubbed table
	var kt: Node3D = k.hotspot("kitchen_table", Vector3(-0.6, 0, 0.4), Vector3(1.2, 1.1, 1.2), Vector3(0, 0.55, 0))
	if kt:
		pass
	k.table(Vector3(-0.6, 0, 0.4), Vector3(3.4, 0.86, 1.1), k.mat(Color(0.82, 0.72, 0.56), 0.9), k.wood_mid)
	k.box(Vector3(0.5, 0.04, 0.34), Vector3(-1.6, 0.88, 0.5), k.wood_light, false, null, 0.1)
	for i in 5:
		k.sphere(0.06, Vector3(-1.75 + i * 0.07, 0.95, 0.5), k.mat([Color(0.9, 0.5, 0.15), Color(0.85, 0.2, 0.15), Color(0.3, 0.6, 0.2)][i % 3], 0.6), null, Vector3(1.0, 0.8, 1.0), 8)
	for i in 3:
		k.cyl(0.11, 0.09, 0.08, Vector3(0.2 + i * 0.3, 0.9, 0.2), k.mat(Color(0.92, 0.9, 0.85), 0.3), null, false, 14)
	k.cyl(0.18, 0.14, 0.12, Vector3(0.4, 0.92, 0.7), k.mat(Color(0.6, 0.4, 0.25), 0.7), null, false, 14)
	var kb: Node3D = k.hotspot("knife_block", Vector3(0.75, 0.86, 0.75), Vector3(0.4, 0.5, 0.4), Vector3(0, 0.2, 0))
	k.box(Vector3(0.16, 0.2, 0.12), Vector3(0, 0.1, 0), k.wood_dark, false, kb, 0.2)
	for i in 4:
		k.box(Vector3(0.025, 0.12, 0.005), Vector3(-0.05 + i * 0.033, 0.24, 0.0), k.mat(Color(0.2, 0.18, 0.16), 0.6), false, kb, 0.2)
	k.box(Vector3(0.24, 0.006, 0.12), Vector3(-0.12, 0.003, 0.18), k.mat(Color(0.75, 0.76, 0.8), 0.2, 0.9), false, kb, 0.5)
	for x in [-1.8, 0.6]:
		k.stool(Vector3(x, 0, 1.4), k.wood_mid, 0.6, 0.18)
	# the dresser on the west wall, plates on its rails
	var dr: Node3D = k.hotspot("dresser", Vector3(-5.0, 0, 1.4), Vector3(0.7, 2.2, 1.8), Vector3(0, 1.1, 0.3), PI / 2.0)
	k.box(Vector3(1.8, 0.9, 0.5), Vector3(0, 0.45, 0.25), k.mat(Color(0.32, 0.46, 0.44), 0.6), true, dr)
	k.box(Vector3(1.86, 0.05, 0.54), Vector3(0, 0.925, 0.27), k.wood_light, false, dr)
	k.box(Vector3(1.8, 1.2, 0.04), Vector3(0, 1.55, 0.065), k.mat(Color(0.32, 0.46, 0.44), 0.6), false, dr)
	for r in 2:
		k.box(Vector3(1.7, 0.03, 0.22), Vector3(0, 1.3 + r * 0.45, 0.13), k.wood_light, false, dr)
		for i in 6:
			var pl: MeshInstance3D = k.cyl(0.12, 0.12, 0.015, Vector3(-0.7 + i * 0.28, 1.43 + r * 0.45, 0.08), k.mat([Color(0.92, 0.92, 0.95), Color(0.3, 0.45, 0.7)][i % 2], 0.3), dr, false, 18)
			pl.rotation.x = PI / 2.0 - 0.25
	# the sink under the window, the copper pans on their rack
	var sk: Node3D = k.hotspot("sink", Vector3(2.6, 0, -3.6), Vector3(1.5, 1.2, 0.9), Vector3(0, 0.6, 0.4))
	k.box(Vector3(1.4, 0.85, 0.65), Vector3(0, 0.425, 0.325), k.mat(Color(0.86, 0.86, 0.84), 0.3), true, sk)
	k.box(Vector3(1.1, 0.06, 0.5), Vector3(0, 0.83, 0.33), k.mat(Color(0.5, 0.52, 0.55), 0.2, 0.6), false, sk)
	k.beam(Vector3(0, 0.88, 0.05), Vector3(0, 1.15, 0.2), 0.02, k.brass, sk)
	k.vista_window(Vector3(2.6, 2.0, -3.6 + 0.002), 0.0, Vector2(1.1, 1.3), {"prison_at": 9.0, "light": 0.5, "curtains": null})
	var rack_y := 2.8
	k.beam(Vector3(-1.4, rack_y, 1.6), Vector3(0.6, rack_y, 1.6), 0.025, k.steel)
	for x in [-1.4, 0.6]:
		k.beam(Vector3(x, rack_y, 1.6), Vector3(x, 3.6, 1.6), 0.008, k.steel)
	for i in 5:
		var px := -1.2 + i * 0.42
		k.beam(Vector3(px, rack_y, 1.6), Vector3(px, rack_y - 0.25, 1.6), 0.006, k.steel)
		k.cyl(0.13 + 0.03 * (i % 2), 0.11 + 0.03 * (i % 2), 0.1, Vector3(px, rack_y - 0.29, 1.6), k.mat(Color(0.78, 0.45, 0.25), 0.3, 0.8), null, false, 16)
	# the pantry
	var ps: Node3D = k.hotspot("pantry_shelf", Vector3(8.4, 0, -2.0), Vector3(0.6, 2.0, 1.6), Vector3(-0.2, 1.0, 0), -PI / 2.0)
	if ps:
		pass
	for r in 4:
		var sh: Node3D = k.wall_shelf(Vector3(8.4, 0.6 + r * 0.45, -2.1), -PI / 2.0, 2.4, 0.36, k.wood_light)
		k.box(Vector3(2.3, Kit.LAYER, 0.34), Vector3(0, Kit.LAYER / 2.0 + 0.0, 0.18), k.mat(Color(0.9, 0.88, 0.8), 0.95), false, sh)
		# old newspaper lining the shelf, folded down over its front edge: columns of print, a headline
		k.box(Vector3(2.3, 0.08, Kit.LAYER), Vector3(0, -0.04 + Kit.LAYER, 0.36 + Kit.LAYER), k.mat(Color(0.88, 0.86, 0.78), 0.95), false, sh)
		var print_m: Material = k.mat(Color(0.32, 0.3, 0.28), 0.95)
		for c in 9:
			var cx := -1.0 + c * 0.25
			if c % 3 == r % 3:
				k.box(Vector3(0.2, 0.018, Kit.LAYER), Vector3(cx, -0.018, 0.36 + Kit.LAYER * 2.5), print_m, false, sh)
			else:
				for ln in 3:
					k.box(Vector3(0.2, 0.006, Kit.LAYER), Vector3(cx, -0.012 - ln * 0.018, 0.36 + Kit.LAYER * 2.5), print_m, false, sh)
		for i in 7:
			var jar_c: Color = [Color(0.85, 0.5, 0.2), Color(0.6, 0.15, 0.2), Color(0.9, 0.85, 0.5), Color(0.4, 0.6, 0.3), Color(0.75, 0.72, 0.68)][(i + r) % 5]
			if (i + r) % 3 == 0:
				k.cyl(0.07, 0.07, 0.2, Vector3(-1.0 + i * 0.32, 0.1 + Kit.LAYER, 0.18), k.mat(Color(0.7, 0.7, 0.72), 0.3, 0.6), sh, false, 12)
			else:
				k.cyl(0.06, 0.07, 0.18, Vector3(-1.0 + i * 0.32, 0.09 + Kit.LAYER, 0.18), k.mat(jar_c, 0.2), sh, false, 12)
	for i in 3:
		k.box(Vector3(0.36, 0.5, 0.28), Vector3(6.0 + i * 0.4, 0.25, -0.85), k.mat(Color(0.75, 0.66, 0.46), 0.95), true)
	k.cyl(0.18, 0.18, 0.5, Vector3(5.6, 0.25, -3.05), k.wood_light, null, true, 14)
	# the dumbwaiter hatch in the pantry's north wall: the shaft runs up to the Library; below the sill, its muddy bottom
	var hx := 6.8
	var hz := -3.4
	# (the hatch is its frame and sign; the rope and the shaft bottom inside the opening are their own anchors)
	var hg: Node3D = k.hotspot("hatch", Vector3(hx, 0, hz), Vector3(0.94, 0.36, 0.3), Vector3(0, 1.73, 0.15))
	k.box(Vector3(0.84, 0.1, 0.08), Vector3(0, 0.82, 0.04), k.wood_dark, false, hg)
	k.box(Vector3(0.84, 0.1, 0.08), Vector3(0, 1.6, 0.04), k.wood_dark, false, hg)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.1, 0.68, 0.08), Vector3(sd * 0.37, 1.21, 0.04), k.wood_dark, false, hg)
	k.box(Vector3(0.66, 0.02, 0.2), Vector3(0, 0.88, 0.1), k.wood_mid, false, hg)
	# the shaft behind the wall: a dark well, two ropes, the muck at the bottom
	var shaft := Node3D.new()
	shaft.position = Vector3(hx, 0, hz)
	k.root.add_child(shaft)
	k.quad(Vector2(0.64, 0.68), Vector3(0, 1.22, Kit.LAYER), k.mat(Color(0.03, 0.025, 0.02), 1.0), shaft)
	var rope: Material = k.mat(Color(0.7, 0.6, 0.42), 0.95)
	var hr: Node3D = k.hotspot("hatch_rope", Vector3(hx + 0.22, 0.9, hz), Vector3(0.24, 0.6, 0.3), Vector3(0, 0.3, 0.16))
	k.cyl(0.012, 0.012, 0.66, Vector3(0, 0.3, 0.02), rope, hr, false, 6)
	k.cyl(0.012, 0.012, 0.66, Vector3(-0.08, 0.3, 0.02), rope, hr, false, 6)
	if after:
		for i in 5:
			k.sphere(0.005, Vector3(-0.005 + 0.003 * i, 0.12 + i * 0.07, 0.034), k.glow(Color(1.0, 0.5, 0.75), 1.5), hr, Vector3.ONE, 4)
	var sb: Node3D = k.hotspot("shaft_bottom", Vector3(hx - 0.15, 0.88, hz + 0.02), Vector3(0.4, 0.3, 0.3), Vector3(0, 0.12, 0.14))
	k.box(Vector3(0.36, 0.012, 0.012), Vector3(0, 0.03, 0.005), k.mat(Color(0.22, 0.18, 0.12), 0.95), false, sb)
	if after:
		# old muck at the bottom of the shaft, and on top of it, not sunk in yet, a chewed pen
		k.box(Vector3(0.3, 0.02, 0.1), Vector3(0.02, 0.046, -0.04), k.mat(Color(0.14, 0.11, 0.08), 0.9), false, sb)
		_pen(k, sb, Vector3(0.03, 0.062, -0.03), 0.4, true)
	var bell: Node3D = k.hotspot("bell_tape", Vector3(hx - 0.75, 1.3, hz), Vector3(0.36, 0.6, 0.4), Vector3(0, 0, 0.18))
	k.box(Vector3(0.22, 0.3, 0.03), Vector3(0, 0.0, 0.015), k.wood_dark, false, bell)
	k.sphere(0.06, Vector3(0, 0.18, 0.08), k.brass, bell, Vector3(1, 0.8, 1), 10)
	k.beam(Vector3(0, 0.12, 0.03), Vector3(0, 0.15, 0.08), 0.008, k.brass, bell)
	k.box(Vector3(0.14, 0.1, 0.08), Vector3(0, -0.06, 0.07), k.mat(Color(0.5, 0.38, 0.2), 0.4, 0.7), false, bell)
	k.box(Vector3(0.04, 0.24, 0.004), Vector3(0, -0.22, 0.11), k.paper, false, bell)
	for i in 3:
		k.box(Vector3(0.012, 0.012, Kit.LAYER), Vector3(0, -0.14 - i * 0.06, 0.114), k.black, false, bell)
	k.box(Vector3(0.3, 0.1, 0.02), Vector3(hx, 1.78, hz + 0.01), k.brass)
	k.label("LIBRARY", Vector3(hx, 1.78, hz + 0.025), 0.0, 24, Color(0.2, 0.12, 0.04), null, 0.0022, 0)
	# lights: a big hanging lamp over the table, one in the pantry, the range's glow
	k.hanging_lamp(Vector3(-0.6, 2.6, 0.4), WARM, 1.6, 3.6, true, 9.0)
	k.hanging_lamp(Vector3(6.6, 2.7, -2.1), WARM, 0.9, 3.6, false, 5.0)
	k.omni(Vector3(-1.0, 0.8, -2.4), Color(1.0, 0.5, 0.2), 0.6, 3.0)
	k.wall_lamp(Vector3(-5.0, 2.3, -0.2), PI / 2.0, LAMP, 0.55, 5.0)
	k.wall_lamp(Vector3(0.0, 2.3, 3.6), PI, LAMP, 0.55, 5.0)
	k.cctv(Vector3(5.0, 3.0, 3.2), -PI / 2.0, 0.6)
	k.picture(Vector3(-3.4, 2.2, -3.6), 0.0, Vector2(0.5, 0.7), Color(0.95, 0.92, 0.84), k.wood_dark, "MENU", 6)
	_page(k, Vector3(-3.3, 1.86, -3.6), 0.0)
	k.wall_clock(Vector3(1.0, 2.6, -3.6), 0.0, 0.2)
	_rubble(k, Vector3(3.6, 0, 1.2), 5, 0.3, 91)
	if after:
		for x in [-2.5, 1.5]:
			k.dust(Vector3(x, 0.01, 1.8), Vector2(3.0, 2.4), 0.35)
	_spots(k, [Vector3(-2.6, 0, -1.4), Vector3(1.8, 0, -1.2), Vector3(3.6, 0, -0.2), Vector3(6.4, 0, -1.8)])
	_guests(k, "kitchen", {"a": Vector3(-2.4, 0, -1.6)})
	k.spawn = Vector3(-3.4, 0, 2.4)
	k.look = Vector3(0.0, 1.2, -3.6)


# =================================================================== Wine Cellar
## Down a long flight from the kitchen into a brick barrel vault: wine racks on both sides, barrels on cradles, a tasting
## table, the rat-bait tins on a shelf, bats asleep under the vault, a lone stool in the dark, and at the far end the door
## to the Generator Room. Anchors: bait_tin, wine_racks, barrels, cellar_stool, bats.
static func _cellar(k) -> void:
	var after := _after(k)
	var top := 2.6
	k.environment("dim", Color(0.52, 0.46, 0.42), 0.46)
	var brick: Material = k.brick(Color(0.42, 0.2, 0.14), Color(0.56, 0.3, 0.2), Color(0.5, 0.46, 0.4))
	var flags: Material = k.stone_floor(Color(0.34, 0.32, 0.3), Color(0.46, 0.44, 0.4), 0.7)
	var o := {"floor": flags, "wall": brick, "wain": null, "trim": k.mat(Color(0.25, 0.14, 0.1), 0.9), "ceiling": k.mat(Color(0.32, 0.18, 0.13), 0.95)}
	k.plan([[-4.5, -7.0, 4.5, 2.0, 3.6], [-1.1, 2.0, 1.1, 9.4, 6.2]], 0.0, 3.6, o)
	k.bounds = Vector2(9.0, 16.4)
	k.slab(-1.1, 8.2, 1.1, 9.4, top, flags)
	k.stairs(Vector3(0, 0, 3.0), Vector3(0, top, 8.2), 2.0, {"mat": k.stone_floor(Color(0.38, 0.36, 0.34), Color(0.5, 0.48, 0.44), 0.4), "rail": "none"})
	k.wall_rail(Vector3(1.04, top + 0.95, 8.2), Vector3(1.04, 0.95, 3.0), Vector3(0.06, 0, 0), k.steel)
	k.door("kitchen", "Kitchen", Vector3(0, top, 9.4), PI, {"mat": k.wood_dark})
	k.door("generator_room", "", Vector3(0, 0, -7.0), 0.0, {"mat": k.steel, "frame": k.mat(Color(0.2, 0.2, 0.22), 0.5, 0.6)})
	# the barrel vault: brick ribs springing from the side walls
	var rib: Material = k.mat(Color(0.46, 0.26, 0.18), 0.9)
	for i in 5:
		var z := -6.0 + i * 1.9
		for j in 8:
			var a0 := PI * float(j) / 8.0
			var a1 := PI * float(j + 1) / 8.0
			var p0 := Vector3(-cos(a0) * 4.35, 2.4 + sin(a0) * 1.1, z)
			var p1 := Vector3(-cos(a1) * 4.35, 2.4 + sin(a1) * 1.1, z)
			var seg: MeshInstance3D = k.box(Vector3(p0.distance_to(p1) + 0.04, 0.18, 0.3), (p0 + p1) / 2.0, rib)
			seg.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x)
		k.box(Vector3(0.3, 2.4, 0.3), Vector3(-4.35, 1.2, z), rib)
		k.box(Vector3(0.3, 2.4, 0.3), Vector3(4.35, 1.2, z), rib)
	# wine racks along both long walls
	var wr: Node3D = k.hotspot("wine_racks", Vector3(-4.5, 0, -1.0), Vector3(0.8, 2.0, 1.8), Vector3(0.4, 1.0, 0), PI / 2.0)
	if wr:
		pass
	var xf: Array = []
	for sd in [-1.0, 1.0]:
		for seg in 2:
			var zc := -4.2 + seg * 4.6
			var rk := Vector3(sd * 4.05, 0, zc)
			k.box(Vector3(0.6, 2.1, 0.06), rk + Vector3(0, 1.05, -1.2), k.wood_dark)
			k.box(Vector3(0.6, 2.1, 0.06), rk + Vector3(0, 1.05, 1.2), k.wood_dark)
			for r in 7:
				k.box(Vector3(0.58, 0.03, 2.34), rk + Vector3(0, 0.15 + r * 0.28, 0), k.wood_mid)
				for c in 10:
					if (r * 7 + c * 3 + seg) % 5 == 0:
						continue
					xf.append(Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0).scaled(Vector3(1, 1, 1)), rk + Vector3(0, 0.22 + r * 0.28, -1.05 + c * 0.233)))
			k.blocker(Vector3(0.6, 2.1, 2.4), rk + Vector3(0, 1.05, 0))
	var bot := CylinderMesh.new()
	bot.top_radius = 0.035
	bot.bottom_radius = 0.035
	bot.height = 0.5
	bot.radial_segments = 8
	k.scatter(bot, k.mat(Color(0.12, 0.2, 0.12), 0.2), xf)
	# barrels on cradles at the far end
	var bb: Node3D = k.hotspot("barrels", Vector3(-2.6, 0, -5.9), Vector3(1.6, 1.4, 1.2), Vector3(0, 0.7, 0))
	for i in 2:
		var bp := Vector3(-0.45 + i * 0.95, 0.62, 0)
		k.box(Vector3(0.9, 0.2, 0.2), bp + Vector3(0, -0.52, -0.3), k.wood_dark, false, bb)
		k.box(Vector3(0.9, 0.2, 0.2), bp + Vector3(0, -0.52, 0.3), k.wood_dark, false, bb)
		var br: MeshInstance3D = k.cyl(0.42, 0.42, 0.95, bp, k.mat(Color(0.48, 0.3, 0.16), 0.8), bb, false, 18)
		br.rotation.x = PI / 2.0
		for zz in [-0.32, 0.32]:
			var hoop: MeshInstance3D = k.cyl(0.435, 0.435, 0.05, bp + Vector3(0, 0, zz), k.steel, bb, false, 18)
			hoop.rotation.x = PI / 2.0
	k.blocker(Vector3(2.0, 1.1, 1.0), Vector3(-2.6, 0.55, -5.9))
	# a tasting table and the stool where someone sat in the dark
	k.table(Vector3(1.6, 0, -2.4), Vector3(1.2, 0.8, 0.7), k.wood_mid, k.wood_dark)
	for i in 3:
		k.bottle(Vector3(1.3 + i * 0.25, 0.8, -2.4), [Color(0.3, 0.06, 0.1), Color(0.12, 0.2, 0.12), Color(0.5, 0.42, 0.2)][i], 0.3)
	k.cyl(0.04, 0.03, 0.1, Vector3(2.0, 0.85, -2.2), k.mat(Color(0.8, 0.85, 0.9), 0.1), null, false, 10)
	var cs: Node3D = k.hotspot("cellar_stool", Vector3(2.6, 0, -4.8), Vector3(0.6, 0.8, 0.6), Vector3(0, 0.4, 0))
	k.stool(Vector3.ZERO, k.wood_mid, 0.48, 0.17, cs)
	k.cyl(0.08, 0.06, 0.16, Vector3(0.35, 0.08, 0.2), k.mat(Color(0.75, 0.6, 0.25), 0.4, 0.6), cs, false, 10)
	# the rat-bait tins on a shelf by the stairs: three tins with cartoon labels
	var bt: Node3D = k.hotspot("bait_tin", Vector3(-1.1, 1.3, 2.6), Vector3(0.5, 0.6, 1.0), Vector3(0.22, 0.15, 0), PI / 2.0)
	var shelf: Node3D = k.wall_shelf(Vector3(-1.1, 1.3, 2.6), PI / 2.0, 0.9, 0.24, k.wood_dark)
	if bt:
		pass
	for i in 3:
		k.cyl(0.075, 0.075, 0.1, Vector3(-0.28 + i * 0.28, 0.05, 0.12), k.mat(Color(0.82, 0.72, 0.2), 0.4, 0.6), shelf, false, 14)
		k.cyl(0.07, 0.07, 0.05, Vector3(-0.28 + i * 0.28, 0.07, 0.12), k.mat(Color(0.2, 0.42, 0.22), 0.6), shelf, false, 14)
		k.sphere(0.02, Vector3(-0.28 + i * 0.28, 0.12, 0.12), k.mat(Color(0.85, 0.15, 0.12), 0.6), shelf, Vector3.ONE, 6)
	# bats asleep under the vault (fewer after the first day)
	var bats := 9 if _day(k) <= 1 else 5
	for i in bats:
		var a := PI * (0.3 + 0.4 * _h(i + 3))
		var z := -5.0 + 7.0 * _h(i + 11)
		k.bat(Vector3(-cos(a) * 3.0, 3.6, z), 1.2, _h(i) * TAU)
	var bh: Node3D = k.hotspot("bats", Vector3(0.0, 3.0, -1.5), Vector3(3.0, 0.8, 3.0), Vector3(0, 0, 0))
	if bh:
		pass
	k.flickers.append(k.bulb(Vector3(0, 3.0, -1.0), 3.6, Color(1.0, 0.8, 0.5), 1.3, 8.5, true))
	k.wall_lamp(Vector3(0.0, 2.2, -7.0), 0.0, LAMP, 0.6, 6.0)
	k.bulb(Vector3(0, 3.0, -5.0), 3.6, Color(1.0, 0.8, 0.5), 0.8, 6.0)
	k.bulb(Vector3(0, 4.8, 5.5), 6.2, Color(1.0, 0.8, 0.5), 0.9, 6.0)
	k.wall_lamp(Vector3(1.1, top + 2.1, 8.6), -PI / 2.0, LAMP, 0.6, 4.5)
	k.cctv(Vector3(4.5, 2.2, 1.6), -PI / 2.0, 0.5)
	if after:
		k.dust(Vector3(0, 0.01, -2.0), Vector2(4.0, 6.0), 0.3)
	_spots(k, [Vector3(0.8, 0, 0.4), Vector3(-1.4, 0, -3.4)])
	k.spawn = Vector3(0, top, 8.6)
	k.look = Vector3(0, 0.8, -4.0)


# =================================================================== Generator Room
## Off the far end of the cellar: whitewashed brick, the diesel generator on its plinth, fuel drums, a switchboard of
## knife switches and the logbook on a little desk under a clock. Anchors: generator, generator_log, fuse_board, fuel_drums.
static func _generator(k) -> void:
	var after := _after(k)
	k.environment("indoor", Color(0.6, 0.6, 0.58), 0.48)
	var wall: Material = k.brick(Color(0.8, 0.79, 0.74), Color(0.88, 0.87, 0.82), Color(0.66, 0.64, 0.6))
	var o := {"floor": k.stone_floor(Color(0.4, 0.4, 0.4), Color(0.5, 0.5, 0.48), 1.2), "wall": wall, "wain": k.mat(Color(0.3, 0.32, 0.3), 0.7),
		"wain_h": 0.8, "trim": k.mat(Color(0.2, 0.2, 0.2), 0.7), "ceiling": k.mat(Color(0.5, 0.5, 0.48), 0.95)}
	k.plan([[-4.5, -3.5, 4.5, 3.5]], 0.0, 3.4, o)
	k.bounds = Vector2(9.0, 7.0)
	k.door("wine_cellar", "", Vector3(-2.6, 0, 3.5), PI, {"mat": k.steel, "frame": k.mat(Color(0.2, 0.2, 0.22), 0.5, 0.6)})
	var gn: Node3D = k.hotspot("generator", Vector3(0.6, 0, -1.6), Vector3(3.2, 1.8, 1.6), Vector3(0, 0.9, 0))
	var green: Material = k.mat(Color(0.22, 0.36, 0.26), 0.5, 0.4)
	k.box(Vector3(3.2, 0.25, 1.4), Vector3(0, 0.125, 0), k.mat(Color(0.45, 0.45, 0.44), 0.9), true, gn)
	k.box(Vector3(1.8, 1.1, 1.0), Vector3(-0.5, 0.8, 0), green, true, gn)
	var drum: MeshInstance3D = k.cyl(0.5, 0.5, 1.0, Vector3(0.9, 0.85, 0), green, gn, false, 20)
	drum.rotation.z = PI / 2.0
	k.blocker(Vector3(1.0, 1.0, 1.0), Vector3(1.5, 0.85, -1.6))
	for i in 6:
		k.box(Vector3(0.04, 0.8, 1.02), Vector3(-1.25 + i * 0.15, 0.8, 0), k.mat(Color(0.16, 0.26, 0.2), 0.5, 0.4), false, gn)
	k.cyl(0.08, 0.08, 1.9, Vector3(-0.9, 2.3, -0.3), k.steel, gn, false, 12)
	k.cyl(0.08, 0.08, 1.2, Vector3(-0.9, 3.2, -0.9), k.steel, gn, false, 12).rotation.x = PI / 2.0
	for i in 3:
		var g: MeshInstance3D = k.cyl(0.07, 0.07, 0.03, Vector3(-0.2 + i * 0.25, 1.15, 0.51), k.mat(Color(0.92, 0.9, 0.84), 0.5), gn, false, 14)
		g.rotation.x = PI / 2.0
	k.sphere(0.03, Vector3(0.6, 1.25, 0.5), k.glow(Color(0.3, 1.0, 0.4), 2.5), gn, Vector3.ONE, 8)
	var fb: Node3D = k.hotspot("fuse_board", Vector3(4.5, 1.6, 0.4), Vector3(0.4, 1.2, 1.6), Vector3(0.18, 0, 0), -PI / 2.0)
	k.box(Vector3(1.4, 1.1, 0.06), Vector3(0, 0, 0.03), k.mat(Color(0.18, 0.18, 0.2), 0.6), false, fb)
	for r in 2:
		for c in 4:
			var sw := Vector3(-0.48 + c * 0.32, 0.25 - r * 0.5, 0.07)
			k.box(Vector3(0.18, 0.06, 0.03), sw, k.mat(Color(0.88, 0.86, 0.8), 0.5), false, fb)
			var arm: MeshInstance3D = k.box(Vector3(0.03, 0.22, 0.03), sw + Vector3(0, 0.1, 0.03), k.brass, false, fb)
			arm.rotation.x = 0.5 if (r + c) % 3 else -0.4
	k.label("MAINS", Vector3(0, 0.48, 0.065), 0.0, 26, Color(0.95, 0.85, 0.4), fb, 0.0024, 4)
	var gl: Node3D = k.hotspot("generator_log", Vector3(3.2, 0, 2.6), Vector3(1.2, 1.2, 0.8), Vector3(0, 0.6, 0))
	k.table(Vector3.ZERO, Vector3(1.0, 0.76, 0.6), k.wood_mid, k.wood_dark, 0.0, gl)
	k.box(Vector3(0.34, 0.04, 0.26), Vector3(-0.1, 0.78, 0.0), k.mat(Color(0.2, 0.26, 0.4), 0.8), false, gl, 0.15)
	k.box(Vector3(0.3, 0.006, 0.22), Vector3(-0.1, 0.803, 0.0), k.paper, false, gl, 0.15)
	k.cyl(0.006, 0.006, 0.14, Vector3(0.2, 0.77, 0.05), k.mat(Color(0.1, 0.1, 0.12), 0.3), gl, false, 6).rotation.z = PI / 2.0
	k.chair(Vector3(3.2, 0, 1.9), PI, k.mat(Color(0.3, 0.3, 0.32), 0.7), k.steel)
	k.wall_clock(Vector3(3.2, 2.1, 3.5), PI, 0.18)
	var fd: Node3D = k.hotspot("fuel_drums", Vector3(-3.4, 0, -2.4), Vector3(1.4, 1.1, 1.4), Vector3(0, 0.55, 0))
	for i in 3:
		var dp := Vector3(-0.35 + (i % 2) * 0.7, 0.45, -0.3 + (i / 2) * 0.65)
		k.cyl(0.29, 0.29, 0.9, dp, k.mat([Color(0.62, 0.14, 0.1), Color(0.2, 0.3, 0.45), Color(0.62, 0.14, 0.1)][i], 0.5, 0.4), fd, true, 18)
		k.torus(0.27, 0.3, dp + Vector3(0, 0.25, 0), k.steel, fd)
	k.box(Vector3(0.2, 0.3, 0.14), Vector3(-2.2, 0.15, -3.1), k.mat(Color(0.62, 0.14, 0.1), 0.5), true)
	var tools: Node3D = k.wall_shelf(Vector3(-4.5, 1.5, 1.0), PI / 2.0, 1.6, 0.26, k.wood_dark)
	for i in 5:
		k.box(Vector3(0.18, 0.12 + 0.05 * (i % 3), 0.18), Vector3(-0.6 + i * 0.3, 0.07 + 0.025 * (i % 3), 0.12), k.mat([Color(0.6, 0.15, 0.1), Color(0.3, 0.3, 0.32), Color(0.75, 0.6, 0.2)][i % 3], 0.6, 0.3), false, tools)
	k.picture(Vector3(-4.5, 2.3, -1.0), PI / 2.0, Vector2(0.6, 0.4), Color(0.95, 0.8, 0.15), k.black, "DANGER", 0, Color(0.1, 0.08, 0.05))
	k.cyl(0.05, 0.05, 8.6, Vector3(0, 3.1, 3.3), k.steel, null, false, 10).rotation.z = PI / 2.0
	for x in [-3.0, 0.0, 3.0]:
		k.box(Vector3(0.06, 0.24, 0.08), Vector3(x, 3.28, 3.34), k.steel)
	# a workbench with spare parts, cable along the walls, sandbags, a ladder
	k.table(Vector3(0.6, 0, 2.95), Vector3(1.8, 0.86, 0.6), k.wood_mid, k.wood_dark)
	for i in 6:
		k.box(Vector3(0.12 + 0.06 * (i % 2), 0.08, 0.12), Vector3(-0.1 + i * 0.28, 0.9, 2.9 + 0.08 * (i % 2)), k.mat([Color(0.5, 0.5, 0.52), Color(0.6, 0.4, 0.2), Color(0.3, 0.3, 0.32)][i % 3], 0.5, 0.5))
	k.cyl(0.1, 0.1, 0.06, Vector3(1.2, 0.9, 2.95), k.mat(Color(0.2, 0.2, 0.2), 0.6), null, false, 14)
	for i in 4:
		k.box(Vector3(0.5, 0.18, 0.3), Vector3(-4.0, 0.09 + i * 0.18, -0.4 + 0.04 * (i % 2)), k.mat(Color(0.62, 0.55, 0.4), 0.95), i == 0, null, 0.05 * (i % 2))
	k.blocker(Vector3(0.5, 0.72, 0.3), Vector3(-4.0, 0.36, -0.4))
	for i in 2:
		k.beam(Vector3(-4.45, 0.05 + i * 0.0, 1.9 + i * 0.4), Vector3(-4.45, 2.3, 1.75 + i * 0.4), 0.025, k.wood_light)
	for i in 6:
		k.box(Vector3(0.42, 0.03, 0.05), Vector3(-4.45, 0.35 + i * 0.35, 2.0 - 0.02 * i), k.wood_light, false, null, PI / 2.0)
	k.beam(Vector3(4.47, 0.3, -3.4), Vector3(4.47, 0.3, 3.4), 0.02, k.black)
	k.beam(Vector3(-4.47, 2.8, -3.4), Vector3(-4.47, 2.8, 3.4), 0.02, k.black)
	for i in 4:
		k.box(Vector3(0.18, 0.24, 0.06), Vector3(-4.47, 1.2, -3.0 + i * 0.6), k.mat(Color(0.3, 0.3, 0.32), 0.5, 0.5), false, null, PI / 2.0)
	k.bulb(Vector3(-1.5, 2.6, 0.8), 3.4, Color(1.0, 0.92, 0.8), 1.3, 8.0, true)
	k.bulb(Vector3(2.5, 2.6, 0.8), 3.4, Color(1.0, 0.92, 0.8), 1.0, 7.0)
	k.cctv(Vector3(-4.5, 2.7, 3.0), PI / 2.0, 0.6)
	if after:
		k.dust(Vector3(0, 0.01, 1.2), Vector2(5.0, 3.0), 0.3)
	_spots(k, [Vector3(-1.0, 0, 1.4), Vector3(2.0, 0, 0.8)])
	k.spawn = Vector3(-2.6, 0, 2.3)
	k.look = Vector3(0.6, 1.0, -2.0)


# =================================================================== Music Room
## A pale, gilded room: the grand piano, a harp, music stands and a row of little gilt chairs, a gramophone, and the
## corner where a costume is being fitted: a dress form stuck with pins, a sewing table with its tickets, a long mirror.
## Anchors: piano, dress_form, fitting_table, music_box, gramophone, harp.
static func _music(k) -> void:
	var after := _after(k)
	k.environment("indoor", Color(0.66, 0.6, 0.56), 0.5)
	var paper: Material = _wallpaper(k, Color(0.82, 0.76, 0.62), Color(0.88, 0.8, 0.58), 0.34)
	var o := _manor(k, paper, null, k.mat(Color(0.86, 0.82, 0.72), 0.6), 1.0)
	k.plan([[-5.0, -4.0, 5.0, 4.0]], 0.0, 4.2, o)
	k.bounds = Vector2(10.0, 8.0)
	_mouldings(k, -5.0, -4.0, 5.0, 4.0, 4.2)
	k.door("grand_hall", "", Vector3(-5.0, 0, 2.2), PI / 2.0, {"h": 2.4, "w": 1.2})
	var pn: Node3D = k.hotspot("piano", Vector3(-1.5, 0, -1.4), Vector3(1.8, 1.4, 2.2), Vector3(0, 0.7, 0), 0.4)
	k.grand_piano(Vector3.ZERO, 0.0, pn)
	var hp: Node3D = k.hotspot("harp", Vector3(1.2, 0, -3.2), Vector3(0.8, 1.9, 0.8), Vector3(0, 0.95, 0))
	# a pedal harp: the base, the straight pillar at the front, the soundbox slanting up from the back, the curved neck
	var gilt_m: Material = k.mat(Color(0.78, 0.6, 0.26), 0.35, 0.7)
	k.box(Vector3(0.34, 0.12, 0.28), Vector3(0.1, 0.06, 0), gilt_m, false, hp)
	k.beam(Vector3(0.16, 0.12, 0), Vector3(0.16, 1.66, 0), 0.035, gilt_m, hp)
	k.sphere(0.05, Vector3(0.16, 1.72, 0), gilt_m, hp, Vector3.ONE, 10)
	k.beam(Vector3(0.08, 0.14, 0), Vector3(-0.3, 1.45, 0), 0.06, k.mat(Color(0.6, 0.42, 0.2), 0.5), hp)
	var neck := [Vector3(0.16, 1.72, 0), Vector3(0.04, 1.66, 0), Vector3(-0.1, 1.64, 0), Vector3(-0.22, 1.57, 0), Vector3(-0.3, 1.47, 0)]
	for i in neck.size() - 1:
		k.beam(neck[i], neck[i + 1], 0.03, gilt_m, hp)
	# strings, straight up from the soundbox to the neck
	for i in 8:
		var x := -0.24 + 0.04 * i
		var y_bottom := 0.2 + (0.08 - x) / 0.38 * 1.25
		var y_top := 1.7 - (0.16 - x) * 0.42
		k.beam(Vector3(x, y_bottom, 0), Vector3(x, y_top, 0), 0.003, k.mat(Color(0.95, 0.9, 0.8), 0.4), hp)
	k.blocker(Vector3(0.5, 1.8, 0.4), Vector3(1.2, 0.9, -3.2))
	for i in 3:
		var ms := Vector3(-0.4 + i * 0.9, 0, 0.6)
		k.cyl(0.012, 0.012, 1.1, ms + Vector3(0, 0.55, 0), k.steel, null, false, 6)
		for j in 3:
			var a := j * TAU / 3.0
			k.beam(ms + Vector3(0, 0.25, 0), ms + Vector3(cos(a) * 0.2, 0, sin(a) * 0.2), 0.008, k.steel)
		var rest: MeshInstance3D = k.box(Vector3(0.44, 0.3, 0.012), ms + Vector3(0, 1.2, 0), k.steel)
		rest.rotation.x = -0.3
		k.box(Vector3(0.36, 0.24, 0.004), ms + Vector3(0, 1.21, 0.012), k.paper).rotation.x = -0.3
	for i in 5:
		k.chair(Vector3(-2.4 + i * 0.75, 0, 2.6), PI, k.mat(Color(0.85, 0.7, 0.4), 0.6), k.mat(Color(0.78, 0.6, 0.26), 0.35, 0.7))
	var gp: Node3D = k.hotspot("gramophone", Vector3(4.6, 0, -2.6), Vector3(0.8, 1.6, 0.8), Vector3(0, 0.8, 0), -PI / 2.0)
	k.box(Vector3(0.5, 0.8, 0.5), Vector3(0, 0.4, 0), k.wood_mid, true, gp)
	k.box(Vector3(0.44, 0.14, 0.44), Vector3(0, 0.87, 0), k.wood_dark, false, gp)
	k.cyl(0.18, 0.18, 0.01, Vector3(0, 0.95, 0), k.black, gp, false, 20)
	var horn: MeshInstance3D = k.cyl(0.3, 0.03, 0.55, Vector3(0.0, 1.2, -0.12), k.brass, gp, false, 20)
	horn.rotation.x = -0.8
	# the fitting corner: dress form, sewing table with the tickets, a long mirror
	var df: Node3D = k.hotspot("dress_form", Vector3(3.2, 0, 2.6), Vector3(0.8, 1.9, 0.8), Vector3(0, 0.95, 0))
	# a dressmaker's form on its tripod stand, a plum gown half pinned on it
	k.cyl(0.02, 0.02, 0.9, Vector3(0, 0.45, 0), k.wood_dark, df, false, 8)
	for i in 3:
		var a := i * TAU / 3.0
		k.beam(Vector3(0, 0.2, 0), Vector3(cos(a) * 0.26, 0.01, sin(a) * 0.26), 0.012, k.wood_dark, df)
	k.sphere(0.2, Vector3(0, 1.32, 0), k.mat(Color(0.88, 0.82, 0.7), 0.85), df, Vector3(1.05, 1.35, 0.72), 16)
	k.cyl(0.035, 0.05, 0.12, Vector3(0, 1.64, 0), k.mat(Color(0.88, 0.82, 0.7), 0.85), df, false, 10)
	k.sphere(0.04, Vector3(0, 1.72, 0), k.wood_dark, df, Vector3.ONE, 8)
	var gown: Material = k.mat(Color(0.42, 0.18, 0.46), 0.7)
	k.cyl(0.19, 0.4, 0.78, Vector3(0, 0.76, 0), gown, df, false, 18)
	k.sphere(0.2, Vector3(0, 1.22, 0.02), gown, df, Vector3(1.08, 0.9, 0.78), 14)
	k.box(Vector3(0.05, 0.5, 0.02), Vector3(0.0, 1.0, 0.21), k.mat(Color(0.95, 0.8, 0.4), 0.4, 0.5), false, df)
	for i in 8:
		var a := i * 0.8
		k.sphere(0.012, Vector3(cos(a) * 0.23, 1.1 + 0.06 * (i % 3), sin(a) * 0.17), k.mat(Color(0.9, 0.9, 0.95), 0.2, 0.8), df, Vector3.ONE, 4)
	k.blocker(Vector3(0.6, 1.7, 0.6), Vector3(3.2, 0.85, 2.6))
	var ft: Node3D = k.hotspot("fitting_table", Vector3(4.4, 0, 1.3), Vector3(0.9, 1.1, 1.2), Vector3(0, 0.55, 0), -PI / 2.0)
	k.table(Vector3.ZERO, Vector3(1.0, 0.74, 0.6), k.wood_light, k.wood_dark, 0.0, ft)
	k.box(Vector3(0.3, 0.12, 0.2), Vector3(-0.25, 0.8, 0), k.mat(Color(0.6, 0.35, 0.45), 0.8), false, ft)
	for i in 3:
		k.box(Vector3(0.12, 0.008, 0.07), Vector3(0.1 + i * 0.1, 0.744, 0.1 - i * 0.05), k.mat(Color(0.95, 0.92, 0.84), 0.9), false, ft, 0.2 * i)
	k.cyl(0.04, 0.04, 0.05, Vector3(0.3, 0.765, -0.15), k.mat(Color(0.85, 0.2, 0.3), 0.6), ft, false, 10)
	k.mirror(Vector3(5.0, 1.4, 2.8), -PI / 2.0, Vector2(0.8, 2.0), false, k.mat(Color(0.78, 0.6, 0.26), 0.35, 0.7), Color(0.85, 0.82, 0.72), Color(0.6, 0.52, 0.42))
	var mb: Node3D = k.hotspot("music_box", Vector3(-4.6, 0, -1.6), Vector3(0.7, 1.2, 0.9), Vector3(0, 0.6, 0), PI / 2.0)
	k.table(Vector3.ZERO, Vector3(0.7, 0.8, 0.45), k.wood_mid, k.wood_dark, 0.0, mb)
	k.box(Vector3(0.24, 0.12, 0.16), Vector3(0, 0.86, 0), k.mat(Color(0.4, 0.16, 0.12), 0.3), false, mb)
	var lid: MeshInstance3D = k.box(Vector3(0.24, 0.02, 0.16), Vector3(0, 0.98, -0.07), k.mat(Color(0.4, 0.16, 0.12), 0.3), false, mb)
	lid.rotation.x = -1.0
	k.sphere(0.03, Vector3(0, 0.95, 0.02), k.mat(Color(0.95, 0.85, 0.6), 0.3, 0.6), mb, Vector3(1, 1.6, 1), 8)
	for x in [-2.0, 1.6]:
		k.vista_window(Vector3(x, 2.2, -4.0 + 0.002), 0.0, Vector2(1.3, 2.2), {"prison_at": 9.0, "light": 0.5, "curtains": Color(0.62, 0.48, 0.2)})
	k.painting(Vector3(-5.0, 2.4, -1.4), PI / 2.0, Vector2(1.2, 0.9), "sea", 81)
	k.painting(Vector3(0.0, 2.4, 4.0), PI, Vector2(1.4, 1.0), "still", 82)
	_page(k, Vector3(0.3, 1.9, 4.0), PI)
	_rug(k, Vector3(-0.8, 0, -0.6), Vector2(5.0, 3.6), Color(0.32, 0.36, 0.5), GILT)
	k.chandelier(Vector3(0, 3.4, 0), 4.2, WARM, 1.6, 10.0, true, 10, 1.0)
	k.sconce(Vector3(-5.0, 2.4, 0.6), PI / 2.0, LAMP, 0.6, 5.0)
	k.sconce(Vector3(5.0, 2.4, -0.4), -PI / 2.0, LAMP, 0.6, 5.0)
	k.cctv(Vector3(5.0, 3.6, -3.6), -PI / 2.0, 0.5)
	k.plant(Vector3(-4.4, 0, 3.4), 1.0)
	_crack(k, Vector3(3.0, 4.0, -4.0), 0.0, 1.2, Vector2(-0.3, -1.0), 101)
	if after:
		k.dust(Vector3(0, 0.02, 0.6), Vector2(6.0, 4.0), 0.35)
	_spots(k, [Vector3(-2.6, 0, 1.2), Vector3(1.6, 0, 1.6), Vector3(0.6, 0, -1.4)])
	_guests(k, "music_room", {"a": Vector3(2.4, 0, 1.6), "b": Vector3(3.6, 0, -0.4)})
	k.spawn = Vector3(-3.8, 0, 2.2)
	k.look = Vector3(1.0, 1.2, -2.0)


# =================================================================== Conservatory
## A glasshouse off the terrace: iron glazing bars over a low brick wall, the sky and the sea through the glass, palms and
## ferns, benches of seedlings, a potting bench with its tins and tools, a little fountain, an easel in the light.
## Anchors: bait_tin, potting_bench, easel, fountain, palms.
static func _conservatory(k) -> void:
	var after := _after(k)
	var W := 10.0
	var D := 8.0
	var H := 4.6
	k.environment("indoor", Color(0.72, 0.76, 0.72), 0.62)
	k.sun(Vector3(-50, 30, 0), Color(1.0, 0.96, 0.88), 0.8, true)
	var tiles: Material = k.stone_floor(Color(0.56, 0.3, 0.22), Color(0.66, 0.4, 0.3), 0.4)
	k.slab(-W / 2.0, -D / 2.0, W / 2.0, D / 2.0, 0.0, tiles)
	k.bounds = Vector2(W, D)
	var brick: Material = k.brick()
	var iron: Material = k.mat(Color(0.18, 0.24, 0.22), 0.5, 0.5)
	var glass: ShaderMaterial = k.smat(Kit.SH_VISTA, {"prison_at": 0.6, "land_from": -0.4, "land_to": 1.4})
	# low brick walls, glass above them, iron bars; the glass roof in two slopes
	var sides := [[Vector3(0, 0, -D / 2.0), 0.0, W], [Vector3(0, 0, D / 2.0), PI, W], [Vector3(-W / 2.0, 0, 0), PI / 2.0, D], [Vector3(W / 2.0, 0, 0), -PI / 2.0, D]]
	for sd in sides:
		var c: Vector3 = sd[0]
		var r: float = sd[1]
		var ln: float = sd[2]
		var b := Basis(Vector3.UP, r)
		Kit.arch(k.box(Vector3(ln, 0.7, 0.3), c + b * Vector3(0, 0.35, -0.15), brick, true, null, r), "wall")
		k.box(Vector3(ln, 0.06, 0.34), c + b * Vector3(0, 0.73, -0.13), k.mat(Color(0.82, 0.8, 0.74), 0.6), false, null, r)
		k.quad(Vector2(ln, H - 0.76), c + b * Vector3(0, 0.76 + (H - 0.76) / 2.0, -0.05), glass, null, r)
		k.blocker(Vector3(ln, H, 0.2), c + b * Vector3(0, H / 2.0, -0.12))
		var n := int(ln / 1.0)
		for i in n + 1:
			var x := -ln / 2.0 + i * ln / n
			k.box(Vector3(0.05, H - 0.76, 0.06), c + b * Vector3(x, 0.76 + (H - 0.76) / 2.0, -0.02), iron, false, null, r)
		k.box(Vector3(ln, 0.06, 0.08), c + b * Vector3(0, 2.4, -0.02), iron, false, null, r)
		k.box(Vector3(ln, 0.08, 0.1), c + b * Vector3(0, H - 0.04, -0.02), iron, false, null, r)
	var rise := 1.2
	var rl := sqrt((D / 2.0) * (D / 2.0) + rise * rise)
	var slope := atan2(rise, D / 2.0)
	for sd in [-1.0, 1.0]:
		var rf: MeshInstance3D = Kit.arch(k.quad(Vector2(W, rl), Vector3(0, H + rise / 2.0, sd * D / 4.0), glass), "roof")
		rf.rotation_order = EULER_ORDER_YXZ
		rf.rotation = Vector3(-PI / 2.0 + sd * slope, 0.0 if sd < 0.0 else PI, 0)
		for i in 11:
			var bar: MeshInstance3D = k.box(Vector3(0.05, 0.06, rl), Vector3(-W / 2.0 + i * W / 10.0, H + rise / 2.0 - 0.04, sd * D / 4.0), iron)
			bar.rotation.x = sd * slope
	k.box(Vector3(W, 0.12, 0.12), Vector3(0, H + rise - 0.06, 0), iron)
	k.door("terrace", "", Vector3(0, 0, D / 2.0), PI, {"mat": iron, "frame": iron, "panels": false, "porthole": true})
	# palms in big pots, ferns on stands
	for p in [Vector3(-4.2, 0, -3.2), Vector3(4.2, 0, -3.2), Vector3(-4.2, 0, 3.0)]:
		var pp: Vector3 = p
		k.plant(pp, 1.6)
	var pm: Node3D = k.hotspot("palms", Vector3(4.2, 0, -3.2), Vector3(1.0, 1.6, 1.0), Vector3(0, 0.8, 0))
	if pm:
		pass
	# benches of seedlings down the middle
	for x in [-2.2, 1.6]:
		k.table(Vector3(x, 0, -0.6), Vector3(2.2, 0.8, 0.9), k.wood_light, k.wood_dark)
		for i in 8:
			var sp := Vector3(x - 0.9 + (i % 4) * 0.6, 0.8, -0.85 + (i / 4) * 0.5)
			k.cyl(0.08, 0.06, 0.12, sp + Vector3(0, 0.06, 0), k.mat(Color(0.6, 0.32, 0.2), 0.8), null, false, 10)
			k.sphere(0.1, sp + Vector3(0, 0.18, 0), k.mat(Color(0.3, 0.55, 0.25).lerp(Color(0.5, 0.65, 0.3), _h(i)), 0.8), null, Vector3(1, 0.8, 1), 8)
	# the potting bench with its tins and tools, against the west wall
	var pb: Node3D = k.hotspot("potting_bench", Vector3(-W / 2.0 + 0.45, 0, 0.8), Vector3(0.9, 1.2, 1.8), Vector3(0, 0.6, 0), PI / 2.0)
	k.table(Vector3.ZERO, Vector3(1.8, 0.86, 0.7), k.wood_light, k.wood_dark, 0.0, pb)
	for i in 3:
		k.box(Vector3(0.3, 0.06, 0.3), Vector3(-0.6 + i * 0.4, 0.89, -0.05), k.mat(Color(0.3, 0.22, 0.16), 0.95), false, pb)
	k.beam(Vector3(0.5, 0.88, 0.1), Vector3(0.8, 0.88, 0.0), 0.012, k.wood_light, pb)
	k.box(Vector3(0.1, 0.02, 0.06), Vector3(0.84, 0.885, 0.0), k.steel, false, pb)
	var bt: Node3D = k.hotspot("bait_tin", Vector3(-W / 2.0 + 0.45, 0.86, 1.6), Vector3(0.5, 0.5, 0.5), Vector3(0, 0.2, 0))
	k.cyl(0.075, 0.075, 0.1, Vector3(0, 0.05, 0), k.mat(Color(0.82, 0.72, 0.2), 0.4, 0.6), bt, false, 14)
	k.cyl(0.07, 0.07, 0.05, Vector3(0, 0.07, 0), k.mat(Color(0.2, 0.42, 0.22), 0.6), bt, false, 14)
	k.sphere(0.02, Vector3(0, 0.12, 0), k.mat(Color(0.85, 0.15, 0.12), 0.6), bt, Vector3.ONE, 6)
	for i in 2:
		k.cyl(0.12, 0.14, 0.3, Vector3(-W / 2.0 + 0.4, 0.15, -1.2 + i * 0.35), k.mat(Color(0.4, 0.5, 0.45), 0.4, 0.6), null, true, 12)
	k.box(Vector3(0.5, 0.6, 0.35), Vector3(-W / 2.0 + 0.4, 0.3, 2.4), k.mat(Color(0.6, 0.5, 0.35), 0.95), true)
	# the easel in the light by the east wall
	var es: Node3D = k.hotspot("easel", Vector3(W / 2.0 - 1.2, 0, 1.6), Vector3(0.9, 1.8, 0.9), Vector3(0, 0.9, 0), -0.6)
	for sd in [-0.28, 0.28]:
		var leg: MeshInstance3D = k.box(Vector3(0.035, 1.6, 0.035), Vector3(sd, 0.8, 0.0), k.wood_light, false, es)
		leg.rotation.x = -0.1
	k.box(Vector3(0.7, 0.5, 0.025), Vector3(0, 1.15, 0.09), k.white, false, es)
	k.box(Vector3(0.62, 0.2, 0.005), Vector3(0, 1.05, 0.105), k.mat(Color(0.35, 0.55, 0.3), 0.9), false, es)
	k.box(Vector3(0.62, 0.18, 0.005), Vector3(0, 1.25, 0.105), k.mat(Color(0.55, 0.75, 0.9), 0.9), false, es)
	k.box(Vector3(0.6, 0.04, 0.06), Vector3(0, 0.88, 0.07), k.wood_light, false, es)
	k.blocker(Vector3(0.7, 1.6, 0.5), Vector3(W / 2.0 - 1.2, 0.8, 1.6))
	k.stool(Vector3(W / 2.0 - 1.7, 0, 2.4), k.wood_light, 0.5)
	# the little fountain
	var fn: Node3D = k.hotspot("fountain", Vector3(1.6, 0, 2.4), Vector3(1.4, 0.9, 1.4), Vector3(0, 0.45, 0))
	k.cyl(0.6, 0.65, 0.4, Vector3(0, 0.2, 0), k.mat(Color(0.75, 0.73, 0.7), 0.6), fn, true, 24)
	k.cyl(0.55, 0.55, 0.02, Vector3(0, 0.38, 0), k.water(Color(0.1, 0.3, 0.32), Color(0.4, 0.7, 0.65), 0.1), fn, false, 24)
	k.cyl(0.06, 0.08, 0.5, Vector3(0, 0.6, 0), k.mat(Color(0.75, 0.73, 0.7), 0.6), fn, false, 12)
	k.sphere(0.12, Vector3(0, 0.9, 0), k.mat(Color(0.75, 0.73, 0.7), 0.6), fn, Vector3(1, 0.6, 1), 12)
	k.steam(Vector3(1.6, 0.95, 2.4), Vector3(0.05, 0.02, 0.05), 6, 0.2, 0.25, 0.4, 1.0)
	k.box(Vector3(1.8, 0.45, 0.5), Vector3(-1.6, 0.225, 2.6), k.wood_light, true)
	k.hanging_lamp(Vector3(0, 3.6, -0.6), WARM, 0.8, H, false, 8.0)
	k.omni(Vector3(-2.6, 2.4, 1.6), Color(0.95, 1.0, 0.95), 0.6, 7.0)
	k.cctv_pole(Vector3(-3.0, 0, 3.4), 2.6, 0.0, 0.5)
	if after:
		k.dust(Vector3(0, 0.02, 1.0), Vector2(5.0, 3.0), 0.25)
	_spots(k, [Vector3(-0.3, 0, 1.4), Vector3(3.2, 0, -0.4), Vector3(-2.6, 0, -2.6)])
	_guests(k, "conservatory", {"a": Vector3(-3.2, 0, 1.6), "b": Vector3(2.6, 0, 1.4)})
	k.spawn = Vector3(0, 0, D / 2.0 - 1.2)
	k.look = Vector3(0, 1.4, -D / 2.0)


# =================================================================== Marble Bath
## The Warden's bath house inside the house: marble floor and walls, a raised pool with steam coming off it, columns, a
## bronze crocodile spouting hot water at the head of the pool, benches and towels, high windows.
## Anchors: pool, statue, towels, bench.
static func _marble_bath(k) -> void:
	var after := _after(k)
	k.environment("steam", Color(0.68, 0.66, 0.64), 0.55)
	var floor_m: Material = _marble(k, Color(0.9, 0.88, 0.84), Color(0.3, 0.42, 0.42), 0.9, 1.0)
	var wall_m: Material = _marble(k, Color(0.86, 0.84, 0.8), Color(0.5, 0.5, 0.5), 1.4, 0.0)
	var o := {"floor": floor_m, "wall": wall_m, "wain": _marble(k, Color(0.3, 0.42, 0.42), Color(0.2, 0.3, 0.3), 1.0, 0.0), "wain_h": 0.9,
		"trim": k.mat(Color(0.78, 0.6, 0.26), 0.35, 0.7), "ceiling": k.mat(Color(0.8, 0.78, 0.74), 0.9)}
	k.plan([[-6.0, -4.5, 6.0, 4.5]], 0.0, 5.0, o)
	k.bounds = Vector2(12.0, 9.0)
	k.door("grand_hall", "", Vector3(-6.0, 0, 2.6), PI / 2.0)
	# the raised pool (its rim stays below the waist so you can see past it)
	var pl: Node3D = k.hotspot("pool", Vector3(1.0, 0, 0.0), Vector3(5.6, 0.6, 3.6), Vector3(0, 0.3, 0))
	var rim: Material = _marble(k, Color(0.95, 0.94, 0.9), Color(0.6, 0.6, 0.6), 1.2, 0.0)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(5.6, 0.45, 0.3), Vector3(0, 0.225, sd * 1.65), rim, true, pl)
		k.box(Vector3(0.3, 0.45, 3.0), Vector3(sd * 2.65, 0.225, 0), rim, true, pl)
	k.box(Vector3(5.0, 0.3, 3.0), Vector3(0, 0.15, 0), k.mat(Color(0.2, 0.42, 0.44), 0.4), false, pl)
	k.box(Vector3(5.0, 0.02, 3.0), Vector3(0, 0.38, 0), k.water(Color(0.08, 0.36, 0.4), Color(0.4, 0.82, 0.78), 0.3), false, pl)
	k.blocker(Vector3(5.0, 0.45, 3.0), Vector3(1.0, 0.225, 0.0))
	k.steam(Vector3(1.0, 0.6, 0), Vector3(2.2, 0.05, 1.3), 22, 1.2, 0.14, 0.35, 4.0)
	# the bronze crocodile at the head of the pool
	var stt: Node3D = k.hotspot("statue", Vector3(4.6, 0, 0), Vector3(1.0, 2.2, 1.2), Vector3(0, 1.1, 0))
	var bronze: Material = k.mat(Color(0.5, 0.36, 0.2), 0.35, 0.75)
	k.box(Vector3(0.8, 0.9, 0.8), Vector3(0, 0.45, 0), rim, true, stt)
	# reared up on its tail on the plinth, leaning out over the pool, jaws wide
	var body: MeshInstance3D = k.cyl(0.13, 0.22, 0.95, Vector3(0.06, 1.34, 0), bronze, stt, false, 14)
	body.rotation.z = 0.28
	for i in 4:
		var rg: MeshInstance3D = k.torus(0.15 + 0.02 * (3 - i) - 0.03, 0.17 + 0.02 * (3 - i) - 0.02, Vector3(0.08 - 0.06 * i, 1.0 + 0.2 * i, 0), bronze, stt, Vector3(0, 0, 0.28))
		rg.scale = Vector3(1.0, 0.4, 1.0)
	for sd in [-1.0, 1.0]:
		k.beam(Vector3(-0.02, 1.45, sd * 0.13), Vector3(-0.2, 1.05, sd * 0.2), 0.035, bronze, stt)
		k.beam(Vector3(0.12, 1.0, sd * 0.15), Vector3(0.1, 0.92, sd * 0.28), 0.04, bronze, stt)
	var tail: Array = [Vector3(0.24, 0.94, 0.0), Vector3(0.28, 0.94, 0.22), Vector3(0.1, 0.94, 0.32), Vector3(-0.12, 0.94, 0.26), Vector3(-0.24, 0.94, 0.1)]
	for i in tail.size() - 1:
		k.beam(tail[i], tail[i + 1], 0.07 - 0.012 * i, bronze, stt)
	var head := Node3D.new()
	head.position = Vector3(-0.16, 1.84, 0)
	head.rotation.z = -0.3
	stt.add_child(head)
	k.box(Vector3(0.3, 0.18, 0.26), Vector3(0, 0, 0), bronze, false, head)
	var upper: MeshInstance3D = k.box(Vector3(0.5, 0.08, 0.2), Vector3(-0.36, 0.06, 0), bronze, false, head)
	upper.rotation.z = -0.28
	var lower: MeshInstance3D = k.box(Vector3(0.46, 0.06, 0.18), Vector3(-0.33, -0.1, 0), bronze, false, head)
	lower.rotation.z = 0.16
	for i in 6:
		var tx := -0.16 - 0.06 * i
		k.box(Vector3(0.02, 0.04, 0.02), Vector3(tx, 0.02 + 0.016 * i, 0.08), k.white, false, head)
		k.box(Vector3(0.02, 0.04, 0.02), Vector3(tx, 0.02 + 0.016 * i, -0.08), k.white, false, head)
		k.box(Vector3(0.02, 0.035, 0.02), Vector3(tx + 0.02, -0.06 - 0.01 * i, 0.07), k.white, false, head)
	for sd in [-0.09, 0.09]:
		k.sphere(0.045, Vector3(0.04, 0.11, sd), k.mat(Color(0.95, 0.85, 0.4), 0.3, 0.6), head, Vector3.ONE, 8)
	# the hot water arcing out of its mouth into the pool
	var water_m: StandardMaterial3D = k.mat(Color(0.75, 0.93, 1.0, 0.55), 0.05)
	water_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_m.emission_enabled = true
	water_m.emission = Color(0.3, 0.45, 0.5)
	var arc: Array = [Vector3(4.02, 1.98, 0), Vector3(3.78, 2.06, 0), Vector3(3.56, 1.92, 0), Vector3(3.38, 1.5, 0), Vector3(3.26, 0.9, 0), Vector3(3.2, 0.42, 0)]
	for i in arc.size() - 1:
		k.beam(arc[i], arc[i + 1], 0.03, water_m)
	# columns, benches, towels
	for p in [Vector3(-2.6, 0, -3.4), Vector3(4.6, 0, -3.4), Vector3(-2.6, 0, 3.4), Vector3(4.6, 0, 3.4)]:
		var pp: Vector3 = p
		k.cyl(0.26, 0.28, 5.0, pp + Vector3(0, 2.5, 0), rim, null, true, 18)
		k.box(Vector3(0.7, 0.2, 0.7), pp + Vector3(0, 0.1, 0), rim)
		k.box(Vector3(0.7, 0.2, 0.7), pp + Vector3(0, 4.9, 0), rim)
	var bn: Node3D = k.hotspot("bench", Vector3(-4.0, 0, -3.8), Vector3(2.2, 0.9, 0.8), Vector3(0, 0.45, 0))
	k.box(Vector3(2.0, 0.08, 0.5), Vector3(0, 0.45, 0), k.wood_light, true, bn)
	for sx in [-0.85, 0.85]:
		k.box(Vector3(0.1, 0.41, 0.45), Vector3(sx, 0.205, 0), rim, false, bn)
	k.folded_stack(Vector3(-4.6, 0.49, -3.8), [Color(0.95, 0.95, 0.95), Color(0.7, 0.85, 0.95)], 3, Vector2(0.4, 0.3))
	var tw: Node3D = k.hotspot("towels", Vector3(-6.0, 0, -1.0), Vector3(0.5, 1.8, 1.4), Vector3(0.2, 0.9, 0), PI / 2.0)
	k.box(Vector3(1.2, 0.04, 0.04), Vector3(0, 1.5, 0.1), k.brass, false, tw)
	k.box(Vector3(1.2, 0.04, 0.04), Vector3(0, 1.0, 0.1), k.brass, false, tw)
	for sd in [-0.6, 0.6]:
		k.box(Vector3(0.04, 0.6, 0.12), Vector3(sd, 1.25, 0.06), k.brass, false, tw)
	for i in 3:
		k.box(Vector3(0.34, 0.8, 0.03), Vector3(-0.4 + i * 0.4, 1.1, 0.12), k.mat([Color(0.95, 0.95, 0.95), Color(0.7, 0.85, 0.95), Color(0.95, 0.85, 0.6)][i], 0.95), false, tw)
	k.sphere(0.07, Vector3(-1.2, 0.46, -1.4), k.mat(Color(1.0, 0.85, 0.2), 0.4), null, Vector3(1.2, 1.0, 1.0), 12)
	k.sphere(0.045, Vector3(-1.16, 0.55, -1.4), k.mat(Color(1.0, 0.85, 0.2), 0.4), null, Vector3.ONE, 10)
	for x in [-1.0, 3.0]:
		k.vista_window(Vector3(x, 3.2, -4.5 + 0.002), 0.0, Vector2(1.2, 1.4), {"prison_at": 0.4, "light": 0.6, "curtains": null})
	k.hanging_lamp(Vector3(1.0, 3.6, 0), WARM, 1.6, 5.0, true, 10.0)
	k.wall_lamp(Vector3(-6.0, 2.4, 0.6), PI / 2.0, LAMP, 0.6, 5.0)
	k.wall_lamp(Vector3(6.0, 2.4, 2.0), -PI / 2.0, LAMP, 0.6, 5.0)
	_crest(k, Vector3(6.0, 3.4, 0), -PI / 2.0, 1.0)
	k.cctv(Vector3(-6.0, 3.6, -4.0), PI / 2.0, 0.6)
	k.plant(Vector3(-5.4, 0, 3.9), 1.0)
	k.plant(Vector3(5.4, 0, -3.9), 1.0)
	var shelf: Node3D = k.wall_shelf(Vector3(1.0, 1.3, 4.5), PI, 2.0, 0.22, k.mat(Color(0.95, 0.94, 0.9), 0.3))
	for i in 7:
		k.bottle(Vector3(-0.8 + i * 0.26, 0.0, 0.1), [Color(0.6, 0.85, 0.9), Color(0.95, 0.75, 0.5), Color(0.8, 0.6, 0.9)][i % 3], 0.2 + 0.04 * (i % 2), shelf)
	for i in 12:
		k.box(Vector3(0.9, 0.12, Kit.LAYER), Vector3(-5.5 + i * 1.0, 2.2, -4.5 + Kit.LAYER / 2.0), k.mat([Color(0.2, 0.5, 0.52), Color(0.85, 0.7, 0.3)][i % 2], 0.3))
	_crack(k, Vector3(-3.0, 4.8, 4.5), PI, 1.8, Vector2(0.3, -1.0), 111)
	if after:
		k.dust(Vector3(-3.6, 0.01, 1.0), Vector2(3.0, 4.0), 0.3)
	_spots(k, [Vector3(-3.8, 0, 0.6), Vector3(1.0, 0, 2.6), Vector3(1.0, 0, -2.6)])
	k.spawn = Vector3(-4.8, 0, 2.6)
	k.look = Vector3(4.0, 1.2, 0)


# =================================================================== outdoors: shared pieces
## Sky and sun for the outdoor spaces: Free Time is the afternoon, the investigation the next morning.
static func _outdoor(k) -> void:
	var env: Environment
	if k.mode == "freetime":
		env = k.environment("outdoor_dusk", Color(0.86, 0.74, 0.66), 0.6)
		env.tonemap_exposure = 0.95
		k.sun(Vector3(-28, -40, 0), Color(1.0, 0.82, 0.62), 1.25)
	else:
		env = k.environment("outdoor_morning", Color(0.74, 0.8, 0.86), 0.55)
		env.tonemap_exposure = 0.88
		k.sun(Vector3(-40, 40, 0), Color(1.0, 0.95, 0.86), 1.1)
		var sm := env.sky.sky_material as ProceduralSkyMaterial
		if sm:
			sm.sky_top_color = Color(0.2, 0.4, 0.74)
			sm.sky_horizon_color = Color(0.62, 0.74, 0.86)
	# below the horizon the sky is open sea, the colour the bay fades to in the haze
	var sky_m := env.sky.sky_material as ProceduralSkyMaterial
	if sky_m:
		sky_m.ground_horizon_color = env.fog_light_color.lerp(Color(0.3, 0.52, 0.62), 0.55)
		sky_m.ground_bottom_color = Color(0.06, 0.22, 0.3)
		sky_m.ground_curve = 0.06
	# sea air, not soup: the far headland and the Gaol must stay in view, and the sky stays blue
	env.fog_density = 0.0014
	env.fog_sky_affect = 0.2
	# from a clifftop the bay runs out to the horizon: let the camera see that far (it is 120 m indoors)
	var rt: Node3D = k.root
	if rt.is_inside_tree():
		var cam: Camera3D = rt.get_viewport().get_camera_3d()
		if cam != null:
			cam.far = 1600.0


## The sea: a huge water plane at height y.
static func _sea(k, y: float, size: float = 3200.0) -> void:
	Kit.arch(k.box(Vector3(size, 0.1, size), Vector3(0, y - 0.05, 0), k.water(Color(0.05, 0.22, 0.32), Color(0.24, 0.5, 0.58), 0.12)), "floor")


## A stone gateway (two posts and a lintel) around a door in the open: `pos` and `rot_y` as for the door.
static func _gateway(k, pos: Vector3, rot_y: float, m: Material = null) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	k.root.add_child(g)
	var sm: Material = m if m != null else k.mat(Color(0.62, 0.6, 0.56), 0.9)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.5, 2.8, 0.5), Vector3(sd * 0.86, 1.4, -0.2), sm, true, g)
		k.box(Vector3(0.6, 0.12, 0.6), Vector3(sd * 0.86, 2.86, -0.2), sm, false, g)
		k.sphere(0.16, Vector3(sd * 0.86, 3.04, -0.2), sm, g, Vector3.ONE, 10)
	k.box(Vector3(2.22, 0.3, 0.5), Vector3(0, 2.6, -0.2), sm, false, g)
	k.box(Vector3(1.22, 0.24, 0.3), Vector3(0, 2.33, -0.1), sm, false, g)


## A low stone parapet from a to b (points on the ground) with a coping; stops you like a rail.
static func _parapet(k, a: Vector3, b: Vector3, h: float = 0.9, m: Material = null) -> void:
	var sm: Material = m if m != null else k.mat(Color(0.64, 0.62, 0.58), 0.9)
	var d := b - a
	var rot := atan2(d.x, d.z)
	var mid := (a + b) / 2.0
	var ln := Vector2(d.x, d.z).length()
	k.box(Vector3(0.4, h, ln), mid + Vector3(0, h / 2.0, 0), sm, false, null, rot)
	k.box(Vector3(0.5, 0.08, ln + 0.1), mid + Vector3(0, h + 0.04, 0), k.mat(Color(0.74, 0.72, 0.68), 0.85), false, null, rot)
	k._oriented_blocker(a, b, 0.4, h + 1.2)


## A gull standing on whatever is at `pos`.
static func _gull(k, pos: Vector3, rot_y: float) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	k.root.add_child(g)
	var wh: Material = k.mat(Color(0.95, 0.95, 0.93), 0.8)
	k.sphere(0.1, Vector3(0, 0.16, 0), wh, g, Vector3(1.0, 0.8, 1.6), 10)
	k.sphere(0.06, Vector3(0, 0.27, 0.12), wh, g, Vector3.ONE, 8)
	k.box(Vector3(0.09, 0.03, 0.22), Vector3(0, 0.2, -0.04), k.mat(Color(0.5, 0.52, 0.56), 0.8), false, g)
	k.box(Vector3(0.02, 0.02, 0.07), Vector3(0, 0.26, 0.2), k.mat(Color(0.95, 0.75, 0.2), 0.6), false, g)
	for sd in [-0.03, 0.03]:
		k.box(Vector3(0.012, 0.09, 0.012), Vector3(sd, 0.045, 0), k.mat(Color(0.95, 0.65, 0.4), 0.6), false, g)


# =================================================================== Terrace
## A long flagged terrace on the clifftop, roofed on columns (it counts as indoors at night). The house wall behind with
## the Grand Hall's French windows; a balustrade over the drop to the sea, the bay and, across it, the Gaol on its
## headland. The telescope stands at the rail, aimed at the cell windows. A gate to the sea steps, the glasshouse at the
## west end, the gate to the cliff path at the east end. Anchors: telescope, terrace_mud, tea_table, deckchairs.
static func _terrace(k) -> void:
	var L := 10.0
	var hd := 4.0
	var H := 3.8
	_outdoor(k)
	k.bounds = Vector2(L * 2.0, hd * 2.0)
	var flags: Material = k.stone_floor(Color(0.58, 0.56, 0.52), Color(0.7, 0.68, 0.62), 0.8)
	k.slab(-L, -hd, L, hd, 0.0, flags, 0.4)
	Kit.arch(k.box(Vector3(L * 2.0, 60.0, 8.0), Vector3(0, -30.4, 0.0), k.rock_mat(Color(0.32, 0.32, 0.3), Color(0.46, 0.45, 0.42))), "wall")
	_sea(k, -42.0)
	# the house wall behind, with windows into the dim house
	var house: Material = k.mat(Color(0.78, 0.72, 0.62), 0.95)
	Kit.arch(k.box(Vector3(L * 2.0 + 4.0, 9.0, 0.5), Vector3(0, 4.5, -hd - 0.25), house, true), "wall")
	k.box(Vector3(L * 2.0, 1.0, 0.04), Vector3(0, 0.5, -hd + 0.02), k.mat(Color(0.4, 0.38, 0.36), 0.9))
	for x in [-7.0, -3.5, 3.5, 7.0]:
		k.box(Vector3(1.3, 2.3, 0.04), Vector3(x, 1.95, -hd + 0.02), k.glow(Color(0.42, 0.32, 0.22), 0.5))
		for yy in [1.95]:
			k.box(Vector3(0.05, 2.3, 0.06), Vector3(x, yy, -hd + 0.04), k.white)
			k.box(Vector3(1.3, 0.05, 0.06), Vector3(x, yy, -hd + 0.04), k.white)
		k.box(Vector3(1.5, 0.12, 0.08), Vector3(x, 3.15, -hd + 0.04), k.white)
		k.box(Vector3(1.5, 0.08, 0.2), Vector3(x, 0.79, -hd + 0.1), k.white)
	k.door("grand_hall", "Grand Hall", Vector3(0, 0, -hd), 0.0, {"h": 2.4, "w": 1.2, "mat": k.mat(Color(0.9, 0.88, 0.82), 0.6), "porthole": true})
	# the roof on its columns
	Kit.arch(k.box(Vector3(L * 2.0 + 0.6, 0.2, hd * 2.0 + 0.6), Vector3(0, H + 0.1, 0.0), k.mat(Color(0.86, 0.84, 0.8), 0.9)), "ceiling")
	k.box(Vector3(L * 2.0 + 0.7, 0.26, 0.12), Vector3(0, H + 0.06, hd + 0.3), k.white)
	for i in 6:
		var x := -L + 0.4 + i * (L * 2.0 - 0.8) / 5.0
		k.cyl(0.16, 0.18, H, Vector3(x, H / 2.0, hd - 0.4), k.white, null, true, 16)
		k.box(Vector3(0.44, 0.14, 0.44), Vector3(x, 0.07, hd - 0.4), k.white)
		k.box(Vector3(0.44, 0.14, 0.44), Vector3(x, H - 0.07, hd - 0.4), k.white)
		k.box(Vector3(0.14, 0.18, hd * 2.0), Vector3(x, H - 0.09, 0.0), k.mat(Color(0.8, 0.78, 0.74), 0.9))
	# the balustrade over the drop, with a gap and a gate for the sea steps
	var gate_x := -7.7
	var bal: Material = k.mat(Color(0.82, 0.8, 0.74), 0.85)
	k.balustrade(Vector3(-L, 0, hd - 0.05), Vector3(gate_x - 0.75, 0, hd - 0.05), 1.0, bal, 0.22)
	k.balustrade(Vector3(gate_x + 0.75, 0, hd - 0.05), Vector3(L, 0, hd - 0.05), 1.0, bal, 0.22)
	k.door("shore", "Sea Steps", Vector3(gate_x, 0, hd), PI, {"mat": k.mat(Color(0.16, 0.18, 0.18), 0.5, 0.6), "panels": false, "frame": k.mat(Color(0.62, 0.6, 0.56), 0.9)})
	_gateway(k, Vector3(gate_x, 0, hd), PI)
	# the conservatory at the west end, the cliff path gate at the east end
	k.door("conservatory", "", Vector3(-L, 0, 0.0), PI / 2.0, {"mat": k.mat(Color(0.18, 0.24, 0.22), 0.5, 0.5), "panels": false, "porthole": true})
	var glass: ShaderMaterial = k.smat(Kit.SH_VISTA, {"prison_at": 9.0})
	Kit.arch(k.box(Vector3(0.3, 0.7, hd * 2.0), Vector3(-L - 0.15, 0.35, 0), k.brick(), true), "wall")
	for sd in [-1.0, 1.0]:
		k.quad(Vector2(hd - 0.8, H - 0.7), Vector3(-L - 0.05, 0.7 + (H - 0.7) / 2.0, sd * (hd / 2.0 + 0.4)), glass, null, PI / 2.0)
		k.box(Vector3(0.06, H - 0.7, 0.06), Vector3(-L - 0.02, 0.7 + (H - 0.7) / 2.0, sd * (hd - 0.1)), k.mat(Color(0.18, 0.24, 0.22), 0.5, 0.5))
	k.blocker(Vector3(0.3, H, hd * 2.0), Vector3(-L - 0.15, H / 2.0, 0))
	k.door("cliff_path", "Cliff Path", Vector3(L, 0, 0.0), -PI / 2.0, {"mat": k.mat(Color(0.16, 0.18, 0.18), 0.5, 0.6), "panels": false})
	_gateway(k, Vector3(L, 0, 0.0), -PI / 2.0)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.4, 1.0, hd - 1.2), Vector3(L + 0.2, 0.5, sd * (hd / 2.0 + 0.6)), k.mat(Color(0.64, 0.62, 0.58), 0.9), true)
	# the telescope at the rail, aimed down the bay at the Gaol
	var ts: Node3D = k.hotspot("telescope", Vector3(4.0, 0, hd - 1.0), Vector3(0.9, 1.6, 0.9), Vector3(0, 0.8, 0))
	if ts:
		pass
	k.telescope(Vector3(4.0, 0, hd - 1.0), PI * 0.82, 0.08)
	# a tea table, deckchairs, pots, hanging lanterns
	var tt: Node3D = k.hotspot("tea_table", Vector3(-2.4, 0, 0.6), Vector3(1.0, 1.0, 1.0), Vector3(0, 0.5, 0))
	k.table(Vector3.ZERO, Vector3(0.8, 0.72, 0.8), k.white, k.mat(Color(0.2, 0.22, 0.2), 0.5, 0.5), 0.0, tt)
	k.cyl(0.08, 0.1, 0.16, Vector3(0.1, 0.8, 0.0), k.mat(Color(0.92, 0.9, 0.86), 0.3), tt, false, 14)
	for i in 2:
		k.cyl(0.045, 0.04, 0.06, Vector3(-0.2, 0.75, -0.2 + i * 0.4), k.mat(Color(0.92, 0.9, 0.86), 0.3), tt, false, 10)
	for i in 3:
		k.chair(Vector3(-2.4 + cos(i * 2.1) * 0.8, 0, 0.6 + sin(i * 2.1) * 0.8), PI / 2.0 - i * 2.1, k.mat(Color(0.86, 0.84, 0.8), 0.6), k.mat(Color(0.2, 0.22, 0.2), 0.5, 0.5))
	var dc: Node3D = k.hotspot("deckchairs", Vector3(-6.6, 0, 1.0), Vector3(2.0, 1.0, 1.4), Vector3(0, 0.5, 0))
	if dc:
		pass
	var stripe: ShaderMaterial = k.stripes(Color(0.95, 0.92, 0.85), Color(0.2, 0.4, 0.55), 8.0)
	for cx in [-7.4, -5.8]:
		var cp := Vector3(cx, 0, 1.0)
		k.box(Vector3(0.6, 0.06, 1.3), cp + Vector3(0, 0.35, 0), stripe)
		var bk: MeshInstance3D = k.box(Vector3(0.6, 0.8, 0.06), cp + Vector3(0, 0.66, -0.7), stripe)
		bk.rotation.x = -0.5
		for sz in [-0.6, 0.6]:
			k.box(Vector3(0.62, 0.32, 0.04), cp + Vector3(0, 0.16, sz), k.wood_dark)
		k.blocker(Vector3(0.6, 0.8, 1.4), cp + Vector3(0, 0.4, 0))
	for x in [-9.2, 9.2]:
		k.plant(Vector3(x, 0, -hd + 0.6), 1.2)
	for x in [-1.0, 7.2]:
		k.cyl(0.32, 0.26, 0.5, Vector3(x, 0.25, hd - 1.2), k.mat(Color(0.7, 0.4, 0.28), 0.8), null, true, 14)
		for j in 6:
			k.sphere(0.16, Vector3(x + cos(j * 1.1) * 0.18, 0.62 + 0.06 * (j % 2), hd - 1.2 + sin(j * 1.1) * 0.18), k.mat(Color(0.75, 0.25, 0.35).lerp(Color(0.95, 0.75, 0.3), _h(j)), 0.8), null, Vector3.ONE, 8)
	# a folded page slipped half under the west planter
	_page(k, Vector3(-0.62, 0, hd - 1.12), 1.2, false)
	for x in [-5.0, 0.0, 5.0]:
		k.hanging_lamp(Vector3(x, H - 0.75, 0.6), Color(1.0, 0.86, 0.64), 0.5, H, false, 5.0)
	# mud on the flags near the east gate (someone came in from the cliff path)
	var md: Node3D = k.hotspot("terrace_mud", Vector3(8.4, 0, 0.6), Vector3(1.2, 0.3, 1.0), Vector3(0, 0.15, 0))
	for i in 4:
		k.box(Vector3(0.12, Kit.LAYER, 0.16), Vector3(-0.4 + i * 0.28, Kit.LAYER, 0.1 * float(i % 2)), k.mat(Color(0.3, 0.22, 0.14), 0.95), false, md, 0.2)
	# the view: the far headland with the Gaol, rocks below, a lighthouse on a point
	k.far_prison(Vector3(210, -40, 150), 1.0, -0.6, false)
	for i in 6:
		k.rock(Vector3(-40.0 + i * 18.0, -40.0, 40.0 + 20.0 * _h(i)), Vector3(14, 10 + 6 * _h(i + 2), 10), k.rock_mat(Color(0.3, 0.3, 0.3), Color(0.44, 0.43, 0.4)), _h(i) * 3.0, false)
	k.cyl(1.0, 1.4, 12.0, Vector3(-120, -34, 140), k.white, null, false, 12)
	k.cyl(1.2, 1.2, 2.0, Vector3(-120, -27, 140), k.mat(Color(0.75, 0.15, 0.12), 0.6), null, false, 12)
	k.cctv(Vector3(L - 0.4, H - 0.3, -hd), 0.0, -0.6)
	k.omni(Vector3(0, 2.6, -2.0), Color(1.0, 0.9, 0.78), 0.6, 9.0)
	k.wall_lamp(Vector3(-L + 0.3, 2.4, -hd), 0.0, LAMP, 0.6, 5.0)
	k.wall_lamp(Vector3(L - 1.2, 2.4, -hd), 0.0, LAMP, 0.6, 5.0)
	if _after(k):
		k.dust(Vector3(0, 0.01, -2.6), Vector2(10.0, 2.0), 0.25)
	_spots(k, [Vector3(1.6, 0, 1.4), Vector3(-4.0, 0, -1.8), Vector3(6.2, 0, -1.6)])
	_guests(k, "terrace", {"a": Vector3(5.0, 0, 2.0), "b": Vector3(2.4, 0, 2.0), "c": Vector3(-4.6, 0, 2.2), "d": Vector3(-0.8, 0, -1.6)})
	k.spawn = Vector3(0, 0, -hd + 1.3)
	k.look = Vector3(2.0, 1.2, hd + 4.0)


# =================================================================== Shore
## The beach under the cliff, where the flood dropped the Mudlark: the paddle-steamer lies on the sand, listing, one
## smokestack sheared off, the wheel smashed; a gangplank up to a hole in her side. Salvage is strewn about; gulls on the
## rocks; the sea steps climb the cliff to the terrace gate. Across the bay, the Gaol.
## Anchors: wreck_hull, ship_bell, tide_pool, salvage_crates.
static func _shore(k) -> void:
	_outdoor(k)
	var W := 22.0
	k.bounds = Vector2(W * 2.0, 30.0)
	var sand: Material = k.smat(Kit.SH_GRASS, {"g1": Color(0.78, 0.7, 0.54), "g2": Color(0.88, 0.8, 0.64)})
	Kit.arch(k.box(Vector3(W * 2.0 + 20.0, 0.4, 36.0), Vector3(0, -0.2, -2.0), sand, true), "floor")
	_sea(k, -0.12)
	# the cliff behind, the house on top of it
	var cliff: ShaderMaterial = k.rock_mat(Color(0.3, 0.29, 0.27), Color(0.46, 0.44, 0.4))
	for i in 9:
		var x := -W - 4.0 + i * 6.4
		k.rock(Vector3(x, 7.0, -18.0 - 2.0 * _h(i)), Vector3(9.0, 20.0 + 6.0 * _h(i + 4), 8.0), cliff, _h(i) * 2.0, false)
	k.blocker(Vector3(W * 2.0 + 20.0, 6.0, 2.0), Vector3(0, 3.0, -16.25))
	var house: Material = k.mat(Color(0.72, 0.66, 0.58), 0.95)
	k.box(Vector3(36.0, 14.0, 12.0), Vector3(-4.0, 30.0, -30.0), house)
	k.prism(Vector3(37.0, 6.0, 13.0), Vector3(-4.0, 40.0, -30.0), k.mat(Color(0.3, 0.3, 0.36), 0.8))
	for i in 8:
		k.box(Vector3(1.4, 2.4, 0.2), Vector3(-18.0 + i * 4.0, 31.0, -23.95), k.mat(Color(0.18, 0.2, 0.26), 0.5))
	k.cyl(2.0, 2.2, 8.0, Vector3(12.0, 38.0, -30.0), house, null, false, 14)
	# the sea steps: a flight cut in the cliff up to the terrace gate
	var steps_m: Material = k.stone_floor(Color(0.52, 0.5, 0.46), Color(0.64, 0.62, 0.58), 0.6)
	k.slab(-10.4, -15.0, -7.6, -11.6, 2.6, steps_m, 2.6)
	k.stairs(Vector3(-9.0, 0, -6.6), Vector3(-9.0, 2.6, -11.6), 2.2, {"mat": steps_m, "rail_mat": k.mat(Color(0.3, 0.3, 0.32), 0.5, 0.5)})
	k.door("terrace", "Sea Steps", Vector3(-9.0, 2.6, -15.0), 0.0, {"mat": k.mat(Color(0.16, 0.18, 0.18), 0.5, 0.6), "panels": false, "frame": k.mat(Color(0.62, 0.6, 0.56), 0.9)})
	_gateway(k, Vector3(-9.0, 2.6, -15.0), 0.0)
	k.rail(Vector3(-10.35, 2.6, -11.6), Vector3(-10.35, 2.6, -14.8), k.mat(Color(0.3, 0.3, 0.32), 0.5, 0.5))
	k.rail(Vector3(-7.65, 2.6, -11.6), Vector3(-7.65, 2.6, -14.8), k.mat(Color(0.3, 0.3, 0.32), 0.5, 0.5))
	k.wall_lamp(Vector3(-10.35, 4.4, -15.0), 0.0, LAMP, 0.7, 6.0)
	# the Mudlark, beached and listing
	var hull_w: Material = k.mat(Color(0.86, 0.84, 0.78), 0.8)
	var teal: Material = k.mat(Color(0.12, 0.42, 0.42), 0.7)
	var ship := Node3D.new()
	ship.position = Vector3(10.0, 0, -3.0)
	ship.rotation = Vector3(0.0, 0.25, -0.16)
	k.root.add_child(ship)
	Kit.arch(k.box(Vector3(7.0, 4.0, 26.0), Vector3(0, 1.6, 0), hull_w, false, ship), "wall")
	k.box(Vector3(7.08, 0.8, 26.04), Vector3(0, 0.0, 0), teal, false, ship)
	k.box(Vector3(7.1, 0.16, 26.1), Vector3(0, 3.62, 0), k.mat(Color(0.75, 0.15, 0.12), 0.6), false, ship)
	k.box(Vector3(5.0, 3.0, 16.0), Vector3(0, 5.2, 0), k.mat(Color(0.9, 0.88, 0.8), 0.8), false, ship)
	k.box(Vector3(5.4, 0.2, 16.4), Vector3(0, 6.8, 0), k.mat(Color(0.86, 0.84, 0.78), 0.8), false, ship)
	for i in 6:
		k.box(Vector3(0.05, 0.9, 1.3), Vector3(-2.52, 5.2, -6.0 + i * 2.4), k.mat(Color(0.2, 0.24, 0.28), 0.4), false, ship)
	k.cyl(0.65, 0.7, 6.0, Vector3(0, 9.8, -3.0), k.mat(Color(0.08, 0.08, 0.09), 0.5, 0.4), ship, false, 16)
	k.cyl(0.7, 0.7, 0.5, Vector3(0, 12.2, -3.0), k.mat(Color(0.75, 0.12, 0.12), 0.6), ship, false, 16)
	k.cyl(0.65, 0.7, 1.4, Vector3(0, 7.5, 1.6), k.mat(Color(0.08, 0.08, 0.09), 0.5, 0.4), ship, false, 16)
	for i in 3:
		var porth: MeshInstance3D = k.cyl(0.22, 0.22, 0.04, Vector3(-3.52, 2.0, -8.0 + i * 3.0), k.mat(Color(0.2, 0.3, 0.32), 0.2, 0.5), ship, false, 16)
		porth.rotation.z = PI / 2.0
		k.torus(0.22, 0.28, Vector3(-3.53, 2.0, -8.0 + i * 3.0), k.brass, ship, Vector3(0, 0, PI / 2.0))
	var wheel := Node3D.new()
	wheel.position = Vector3(0, 2.0, 14.0)
	wheel.rotation.x = 0.4
	ship.add_child(wheel)
	k.torus(2.6, 2.8, Vector3.ZERO, k.mat(Color(0.75, 0.12, 0.1), 0.6), wheel, Vector3(0, 0, PI / 2.0))
	for i in 7:
		var sp: MeshInstance3D = k.box(Vector3(0.4, 0.1, 5.4 - 1.2 * float(i % 3)), Vector3.ZERO, k.mat(Color(0.75, 0.12, 0.1), 0.6), false, wheel)
		sp.rotation.x = i * TAU / 7.0
	k.blocker(Vector3(7.0, 4.0, 26.0), Vector3(0, 1.6, 0), ship)
	k.blocker(Vector3(1.2, 5.6, 6.0), Vector3(0, 2.0, 14.0), ship)
	var wh: Node3D = k.hotspot("wreck_hull", Vector3(5.6, 0, 3.4), Vector3(1.2, 2.0, 2.0), Vector3(0, 1.0, 0))
	if wh:
		pass
	# the sheared smokestack lying on the sand
	var stack: MeshInstance3D = k.cyl(0.65, 0.7, 5.0, Vector3(1.0, 0.68, 9.0), k.mat(Color(0.08, 0.08, 0.09), 0.5, 0.4), null, false, 16)
	stack.rotation = Vector3(0, 0.4, PI / 2.0)
	k.blocker(Vector3(4.6, 1.3, 1.3), Vector3(1.0, 0.65, 9.0))
	# the gangplank up to the breach in her side, and the breach
	var bx := 5.2
	var bz := -1.6
	k.slab(bx - 0.9, bz - 1.0, bx + 0.6, bz + 1.0, 1.2, k.wood_floor(Color(0.34, 0.22, 0.12), Color(0.5, 0.34, 0.18), 0.2), 0.2)
	k.stairs(Vector3(bx - 4.0, 0, bz), Vector3(bx - 0.9, 1.2, bz), 1.4, {"mat": k.wood_floor(Color(0.34, 0.22, 0.12), Color(0.5, 0.34, 0.18), 0.2), "rail": "none", "count": 7})
	k.rail(Vector3(bx - 0.9, 1.2, bz - 1.0), Vector3(bx + 0.6, 1.2, bz - 1.0), k.wood_dark)
	k.rail(Vector3(bx - 0.9, 1.2, bz + 1.0), Vector3(bx + 0.6, 1.2, bz + 1.0), k.wood_dark)
	k.door("wreck", "Mudlark Wreck", Vector3(bx + 0.6, 1.2, bz), -PI / 2.0, {"mat": k.mat(Color(0.12, 0.3, 0.3), 0.7), "frame": k.mat(Color(0.6, 0.45, 0.3), 0.8)})
	# the salvage crew's timber boarding frame, from the platform to the breach in her hull (the hull leans away above)
	var frame_m: Material = k.wood_wall(Color(0.3, 0.2, 0.12), Color(0.42, 0.3, 0.18), 0.22)
	k.box(Vector3(1.0, 2.9, 2.2), Vector3(bx + 1.12, 2.65, bz), frame_m, true)
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.12, 2.9, 0.12), Vector3(bx + 0.56, 2.65, bz + sd * 1.04), k.wood_dark)
	k.box(Vector3(0.14, 0.14, 2.3), Vector3(bx + 0.56, 4.04, bz), k.wood_dark)
	# salvage strewn about: crates, a barrel, a lifebuoy, a deckchair, coils of rope, the ship's bell
	var sc: Node3D = k.hotspot("salvage_crates", Vector3(-1.6, 0, 2.6), Vector3(2.2, 1.2, 1.6), Vector3(0, 0.6, 0))
	k.crate(Vector3(-0.5, 0, 0), Vector3(0.8, 0.6, 0.7), 0.2, null, true, sc)
	k.crate(Vector3(0.5, 0, 0.2), Vector3(0.7, 0.5, 0.6), -0.3, null, true, sc)
	k.crate(Vector3(-0.3, 0.6, 0.0), Vector3(0.5, 0.4, 0.5), 0.5, null, false, sc)
	k.rope_coil(Vector3(0.6, 0.5, 0.2), 1.0, null, sc)
	var bell: Node3D = k.hotspot("ship_bell", Vector3(2.6, 0, 6.4), Vector3(0.8, 1.0, 0.8), Vector3(0, 0.5, 0))
	k.box(Vector3(0.7, 0.08, 0.2), Vector3(0, 0.04, 0), k.wood_dark, false, bell)
	var bl: MeshInstance3D = k.cyl(0.14, 0.24, 0.36, Vector3(0, 0.22, 0), k.brass, bell, false, 18)
	bl.rotation.z = 1.2
	k.blocker(Vector3(0.7, 0.5, 0.5), Vector3(0, 0.25, 0), bell)
	k.cyl(0.36, 0.36, 0.7, Vector3(-4.0, 0.35, 5.0), k.mat(Color(0.5, 0.32, 0.18), 0.8), null, true, 16)
	k.torus(0.2, 0.32, Vector3(-2.6, 0.06, 6.6), k.stripes(Color(0.95, 0.95, 0.95), Color(0.85, 0.15, 0.12), 4.0), null, Vector3(0, 0, 0.0))
	var dch: MeshInstance3D = k.box(Vector3(0.6, 0.06, 1.3), Vector3(0.2, 0.12, 4.6), k.stripes(Color(0.95, 0.92, 0.85), Color(0.15, 0.5, 0.5), 8.0), false, null, 0.6)
	dch.rotation.z = 0.3
	k.blocker(Vector3(1.2, 0.4, 1.4), Vector3(0.2, 0.2, 4.6))
	for i in 9:
		var pl: MeshInstance3D = k.box(Vector3(0.2, 0.05, 1.6 + 1.2 * _h(i)), Vector3(-6.0 + 2.2 * _h(i + 3) * 4.0, 0.025, 3.0 + 6.0 * _h(i + 7)), k.mat(Color(0.5, 0.36, 0.2).lerp(Color(0.66, 0.56, 0.4), _h(i)), 0.9), false, null, _h(i + 1) * PI)
		pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# rocks, tide pools, seaweed, gulls
	var rk: ShaderMaterial = k.rock_mat(Color(0.32, 0.31, 0.3), Color(0.5, 0.48, 0.44))
	var tops: Array = []
	for p in [Vector3(-16.0, 0.4, 2.0), Vector3(-17.0, 0.6, -6.0), Vector3(-12.0, 0.3, 8.0), Vector3(17.0, 0.5, 9.0), Vector3(-6.0, 0.35, -9.5)]:
		var pp: Vector3 = p
		var f := 0.8 + 0.6 * _h(int(pp.x))
		k.rock(pp, Vector3(2.4, 1.4, 2.0) * f, rk, _h(int(pp.z)) * 3.0, true)
		tops.append(pp + Vector3(0, 0.7 * f - 0.04, 0))
	var tp: Node3D = k.hotspot("tide_pool", Vector3(-11.0, 0, 3.0), Vector3(2.0, 0.4, 1.6), Vector3(0, 0.2, 0))
	k.puddle(Vector3(-11.0, 0, 3.0), Vector2(2.2, 1.5), 0.3)
	for i in 5:
		k.sphere(0.1, Vector3(-11.6 + i * 0.3, 0.04, 2.6 + 0.2 * float(i % 2)), k.mat(Color(0.85, 0.4, 0.3), 0.6), tp, Vector3(1.0, 0.4, 1.0), 8)
	for i in 14:
		k.box(Vector3(0.5, 0.02, 0.12), Vector3(-14.0 + 28.0 * _h(i + 30), 0.01, 10.0 + 2.0 * _h(i + 40)), k.mat(Color(0.2, 0.32, 0.16), 0.9), false, null, _h(i) * PI)
	_gull(k, tops[0], 0.4)
	_gull(k, tops[2], 2.0)
	_gull(k, Vector3(-4.0, 0.68, 5.0), 1.0)
	# Snapjaw has roped off the water
	for sd in [0]:
		k.rail(Vector3(-W, 0, 12.0), Vector3(W, 0, 12.0), k.mat(Color(0.66, 0.54, 0.36), 0.9), 0.9)
	k.picture(Vector3(-3.0, 1.1, 12.0), PI, Vector2(0.7, 0.4), Color(0.95, 0.8, 0.15), k.black, "NO\nSWIMMING", 0, Color(0.1, 0.08, 0.05))
	k.rail(Vector3(-W, 0, 12.0), Vector3(-W, 0, -14.0), k.mat(Color(0.66, 0.54, 0.36), 0.9), 0.9)
	k.rail(Vector3(W, 0, 12.0), Vector3(W, 0, -14.0), k.mat(Color(0.66, 0.54, 0.36), 0.9), 0.9)
	k.cctv_pole(Vector3(-6.0, 0, 9.0), 3.2, PI, 0.4)
	k.far_prison(Vector3(180, -2, 120), 0.9, -0.5, false)
	k.omni(Vector3(4.0, 2.0, 1.0), Color(1.0, 0.92, 0.8), 0.5, 10.0)
	_spots(k, [Vector3(-4.0, 0, 0.0), Vector3(0.0, 0, -6.0), Vector3(-8.0, 0, 5.0)])
	_guests(k, "shore", {"a": Vector3(2.6, 0, 0.6), "b": Vector3(-14.4, 0, 0.6), "c": Vector3(-9.6, 0, 3.6), "d": Vector3(-1.4, 0, 5.4)})
	k.spawn = Vector3(-9.0, 0, -5.4)
	k.look = Vector3(8.0, 2.0, 2.0)


# =================================================================== Mudlark Wreck (the infirmary)
## Inside the beached Mudlark: the infirmary from the voyage, knocked sideways. The cot overturned, the cabinet hanging
## open, sand drifted in through the breach, a porthole of daylight, and Marigold's tall steel locker with her name on it.
## Anchors: locker, manual_shelf, medicine_cabinet, cot, porthole.
static func _wreck(k) -> void:
	var W := 6.0
	var D := 8.0
	var H := 2.8
	k.set_meta("ceiling_min", 2.5)
	k.environment("indoor", Color(0.66, 0.68, 0.66), 0.5)
	var cream: Material = k.mat(Color(0.88, 0.85, 0.76), 0.95)
	var teal_w: ShaderMaterial = k.wood_wall(Color(0.06, 0.28, 0.29), Color(0.1, 0.42, 0.42), 0.18)
	var o := {"floor": k.wood_floor(Color(0.3, 0.17, 0.09), Color(0.5, 0.31, 0.16), 0.2), "wall": cream, "wain": teal_w, "wain_h": 1.05,
		"trim": k.brass, "ceiling": k.mat(Color(0.24, 0.15, 0.09), 0.85)}
	k.plan([[-W / 2.0, -D / 2.0, W / 2.0, D / 2.0]], 0.0, H, o)
	k.bounds = Vector2(W, D)
	for z in [-3.0, -1.0, 1.0, 3.0]:
		k.box(Vector3(W, 0.16, 0.16), Vector3(0, H - 0.08, z), k.wood_dark)
	k.door("shore", "Shore", Vector3(0, 0, D / 2.0), PI, {"mat": k.mat(Color(0.12, 0.3, 0.3), 0.7)})
	# sand drifted in and a puddle of seawater
	var sand: Material = k.mat(Color(0.82, 0.74, 0.58), 0.95)
	for i in 5:
		k.sphere(0.6, Vector3(-1.6 + i * 0.8, 0.0, D / 2.0 - 0.6 - 0.2 * float(i % 2)), sand, null, Vector3(1.2, 0.18, 0.8), 10)
	k.puddle(Vector3(1.4, 0, 0.8), Vector2(1.6, 1.0), 0.4)
	k.puddle(Vector3(-1.2, 0, -1.4), Vector2(1.0, 0.7), 1.2)
	# the porthole of daylight, cracked
	var ph: Node3D = k.hotspot("porthole", Vector3(-W / 2.0, 1.75, -1.2), Vector3(0.3, 0.6, 0.6), Vector3(0.15, 0, 0), PI / 2.0)
	if ph:
		pass
	k.porthole(Vector3(-W / 2.0, 1.75, -1.2), PI / 2.0, 0.22, Color(0.75, 0.85, 0.95), 2.0)
	k.omni(Vector3(-W / 2.0 + 0.8, 1.6, -1.2), SEA_LIGHT, 0.8, 5.0)
	k.beam(Vector3(-W / 2.0 + 0.08, 1.9, -1.32), Vector3(-W / 2.0 + 0.08, 1.62, -1.06), 0.004, k.white)
	# the medicine cabinet, hanging open, bottles on the floor
	var mc: Node3D = k.hotspot("medicine_cabinet", Vector3(0.1, 1.55, -D / 2.0), Vector3(1.2, 0.9, 0.5), Vector3(0, 0, 0.2))
	k.box(Vector3(1.0, 0.8, 0.22), Vector3(0, 0, 0.11), k.mat(Color(0.95, 0.95, 0.93), 0.5), false, mc)
	var cdoor: MeshInstance3D = k.box(Vector3(0.48, 0.74, 0.02), Vector3(0.6, -0.04, 0.4), k.mat(Color(0.8, 0.92, 0.95), 0.05, 0.2), false, mc, 1.2)
	if cdoor:
		pass
	for i in 4:
		k.cyl(0.03, 0.03, 0.12, Vector3(-0.35 + i * 0.12, 0.1, 0.1), k.mat([Color(0.85, 0.3, 0.3), Color(0.3, 0.6, 0.85), Color(0.95, 0.8, 0.3)][i % 3], 0.3), mc, false, 8)
	for i in 5:
		var bt: MeshInstance3D = k.cyl(0.03, 0.03, 0.12, Vector3(-0.4 + i * 0.22, 0.03, -D / 2.0 + 0.6 + 0.2 * float(i % 2)), k.mat([Color(0.85, 0.3, 0.3), Color(0.3, 0.6, 0.85), Color(0.95, 0.8, 0.3)][i % 3], 0.3), null, false, 8)
		bt.rotation.z = PI / 2.0
		bt.rotation.y = _h(i) * 3.0
	# the overturned cot
	var ct: Node3D = k.hotspot("cot", Vector3(1.6, 0, -2.2), Vector3(2.3, 1.0, 1.3), Vector3(0, 0.5, 0), 0.3)
	var frame: Material = k.mat(Color(0.92, 0.92, 0.9), 0.35, 0.5)
	var tilt := Node3D.new()
	tilt.rotation.x = PI / 2.0
	tilt.position = Vector3(0, 0.43, 0)
	ct.add_child(tilt)
	k.box(Vector3(2.0, 0.08, 0.85), Vector3(0, 0.0, 0.0), frame, false, tilt)
	for sx in [-0.97, 0.97]:
		for sz in [-0.39, 0.39]:
			k.box(Vector3(0.05, 0.45, 0.05), Vector3(sx, 0.26, sz), frame, false, tilt)
	k.box(Vector3(1.9, 0.14, 0.8), Vector3(0.1, 0.07, 0.3), k.white, false, ct, 0.1)
	k.blocker(Vector3(2.1, 0.9, 0.6), Vector3(0, 0.45, 0), ct)
	# Marigold's locker, tall and steel, her name on a card
	var lk: Node3D = k.hotspot("locker", Vector3(W / 2.0, 0, 0.6), Vector3(0.8, 2.0, 0.8), Vector3(0.25, 1.0, 0), -PI / 2.0)
	k.box(Vector3(0.6, 1.9, 0.5), Vector3(0, 0.95, 0.25), k.mat(Color(0.4, 0.5, 0.52), 0.4, 0.6), true, lk)
	for i in 4:
		k.box(Vector3(0.36, 0.02, 0.01), Vector3(0, 1.55 + i * 0.05, 0.505), k.mat(Color(0.2, 0.25, 0.26), 0.5), false, lk)
	k.box(Vector3(0.22, 0.08, 0.006), Vector3(0, 1.3, 0.505), k.paper, false, lk)
	k.label("M. FERN", Vector3(0, 1.3, 0.51), 0.0, 22, Color(0.2, 0.12, 0.06), lk, 0.0022, 0)
	k.box(Vector3(0.04, 0.12, 0.03), Vector3(0.22, 1.0, 0.515), k.steel, false, lk)
	# the shelf of old manuals and the rounds log over the desk
	var ms: Node3D = k.hotspot("manual_shelf", Vector3(-1.6, 1.6, -D / 2.0), Vector3(1.4, 0.8, 0.5), Vector3(0, 0, 0.2))
	var shelf: Node3D = k.wall_shelf(Vector3(-1.6, 1.5, -D / 2.0), 0.0, 1.2, 0.22, k.wood_light)
	for i in 8:
		var bk: MeshInstance3D = k.box(Vector3(0.06, 0.24, 0.17), Vector3(-0.5 + i * 0.07, 0.12, 0.1), k.mat([Color(0.5, 0.12, 0.16), Color(0.16, 0.3, 0.42), Color(0.3, 0.4, 0.3), Color(0.6, 0.5, 0.3)][i % 4], 0.8), false, shelf)
		if i > 5:
			bk.rotation.z = 0.35
	if ms:
		pass
	k.box(Vector3(1.4, 0.8, 0.6), Vector3(-1.6, 0.4, -D / 2.0 + 0.3), k.wood_mid, true)
	k.box(Vector3(1.5, 0.05, 0.66), Vector3(-1.6, 0.825, -D / 2.0 + 0.33), k.wood_light)
	k.box(Vector3(0.3, 0.02, 0.4), Vector3(-1.7, 0.86, -D / 2.0 + 0.36), k.paper, false, null, 0.3)
	k.stool(Vector3(-1.6, 0, -D / 2.0 + 1.2), k.mat(Color(0.2, 0.42, 0.44), 0.6))
	# the hull leans in along the west wall
	var hull: MeshInstance3D = k.box(Vector3(0.1, 1.4, D - 0.2), Vector3(-W / 2.0 + 0.22, 0.62, 0), teal_w)
	hull.rotation.z = 0.3
	k.picture(Vector3(W / 2.0, 1.75, 2.6), -PI / 2.0, Vector2(0.6, 0.8), Color(0.92, 0.9, 0.84), k.brass, "WASH!", 6)
	k.wall_clock(Vector3(-0.9, 2.15, D / 2.0), PI)
	k.hanging_lamp(Vector3(0, 2.4, -0.6), Color(1.0, 0.92, 0.8), 0.9, H, true, 6.0)
	k.omni(Vector3(0, 1.4, D / 2.0 - 0.8), Color(1.0, 0.95, 0.85), 0.7, 5.0)
	# the voyage's last mess: a chair on its back, papers, a lifejacket, a coil of rope, a crab that has moved in
	var chr: Node3D = k.chair(Vector3(-1.6, 0.25, 1.2), 0.4, k.mat(Color(0.2, 0.42, 0.44), 0.6), k.wood_dark)
	chr.rotation.x = -PI / 2.0
	for i in 8:
		k.box(Vector3(0.21, 0.004, 0.29), Vector3(-0.6 + 1.6 * _h(i + 3), 0.004 + Kit.LAYER * (i % 3), -0.8 + 2.4 * _h(i + 9)), k.paper, false, null, _h(i) * TAU)
	var lj: Node3D = Node3D.new()
	lj.position = Vector3(2.1, 0, 2.4)
	lj.rotation.y = 0.7
	k.root.add_child(lj)
	k.box(Vector3(0.5, 0.08, 0.6), Vector3(0, 0.04, 0), k.mat(Color(0.95, 0.5, 0.12), 0.7), false, lj)
	for i in 3:
		k.box(Vector3(0.52, 0.02, 0.04), Vector3(0, 0.085, -0.2 + i * 0.2), k.mat(Color(0.85, 0.85, 0.85), 0.6), false, lj)
	k.rope_coil(Vector3(-2.2, 0, 2.8), 0.9)
	var crab := Vector3(0.6, 0, 2.6)
	k.sphere(0.07, crab + Vector3(0, 0.05, 0), k.mat(Color(0.8, 0.3, 0.18), 0.6), null, Vector3(1.4, 0.6, 1.0), 10)
	for sd in [-1.0, 1.0]:
		k.sphere(0.03, crab + Vector3(sd * 0.1, 0.05, 0.07), k.mat(Color(0.8, 0.3, 0.18), 0.6), null, Vector3.ONE, 6)
		for j in 3:
			k.beam(crab + Vector3(sd * 0.06, 0.05, -0.03 + j * 0.03), crab + Vector3(sd * 0.14, 0.0, -0.06 + j * 0.04), 0.006, k.mat(Color(0.8, 0.3, 0.18), 0.6))
	for i in 6:
		k.box(Vector3(0.05, 0.004, 0.04), Vector3(-0.5 + 0.2 * i, 0.002, -D / 2.0 + 0.9 + 0.1 * float(i % 2)), k.mat(Color(0.8, 0.92, 0.95), 0.05, 0.3), false, null, i * 0.8)
	_spots(k, [Vector3(-0.4, 0, 1.6), Vector3(0.6, 0, -0.6)])
	k.spawn = Vector3(0, 0, D / 2.0 - 1.2)
	k.look = Vector3(0, 1.0, -D / 2.0)


# =================================================================== Cliff Path
## A path along the clifftop between the terrace and the causeway to the Gaol: grass and gorse inland, a low stone wall on
## the edge, wind-bent trees, a bench with a view, a signpost, steps down to the boathouse.
## Anchors: crate, bench, signpost.
static func _cliff_path(k) -> void:
	_outdoor(k)
	var L := 18.0
	k.bounds = Vector2(L * 2.0, 10.0)
	var grass: ShaderMaterial = k.smat(Kit.SH_GRASS, {"g1": Color(0.34, 0.46, 0.2), "g2": Color(0.5, 0.58, 0.28)})
	Kit.arch(k.box(Vector3(L * 2.0 + 10.0, 0.6, 14.0), Vector3(0, -0.3, -3.0), grass, true), "floor")
	k.box(Vector3(L * 2.0, Kit.LAYER, 2.4), Vector3(0, Kit.LAYER / 2.0, 0.6), k.stone_floor(Color(0.6, 0.54, 0.44), Color(0.7, 0.64, 0.52), 0.9))
	Kit.arch(k.box(Vector3(L * 2.0 + 10.0, 50.0, 6.0), Vector3(0, -25.6, 6.0), k.rock_mat(Color(0.32, 0.32, 0.3), Color(0.46, 0.45, 0.42))), "wall")
	_sea(k, -38.0)
	# the low wall along the edge, gorse and a fence on the inland side
	_parapet(k, Vector3(-L, 0, 3.2), Vector3(-1.4, 0, 3.2), 0.8)
	_parapet(k, Vector3(1.4, 0, 3.2), Vector3(L, 0, 3.2), 0.8)
	for i in 12:
		var x := -L + 1.5 + i * 3.0
		k.sphere(0.6, Vector3(x + _h(i) * 1.2, 0.3, -2.6 - _h(i + 5)), k.mat(Color(0.3, 0.42, 0.18), 0.9), null, Vector3(1.4, 0.9, 1.0), 10)
		k.blocker(Vector3(1.5, 1.0, 1.1), Vector3(x + _h(i) * 1.2, 0.5, -2.6 - _h(i + 5)))
		for j in 3:
			k.sphere(0.06, Vector3(x + _h(i) * 1.2 + 0.3 * (j - 1), 0.62, -2.4 - _h(i + 5)), k.mat(Color(0.98, 0.82, 0.2), 0.7), null, Vector3.ONE, 6)
	k.rail(Vector3(-L, 0, -3.4), Vector3(L, 0, -3.4), k.wood_dark, 0.9)
	# wind-bent trees
	for x in [-11.0, 4.0, 12.0]:
		var tr := Node3D.new()
		tr.position = Vector3(x, 0, -2.0)
		tr.rotation.z = 0.25
		k.root.add_child(tr)
		k.cyl(0.14, 0.22, 3.2, Vector3(0, 1.6, 0), k.mat(Color(0.32, 0.24, 0.16), 0.9), tr, false, 10)
		for j in 4:
			k.sphere(0.9, Vector3(-0.5 - 0.4 * j, 3.2 + 0.2 * (j % 2), 0.3 * (j % 2)), k.mat(Color(0.26, 0.4, 0.2), 0.9), tr, Vector3(1.3, 0.7, 1.0), 10)
		k.blocker(Vector3(1.2, 2.2, 0.5), Vector3(x - 0.3, 1.1, -2.0))
	# the bench with a view
	var bn: Node3D = k.hotspot("bench", Vector3(-5.0, 0, 2.4), Vector3(2.0, 1.0, 0.8), Vector3(0, 0.5, 0))
	k.box(Vector3(1.8, 0.08, 0.5), Vector3(0, 0.45, 0), k.wood_light, true, bn)
	k.box(Vector3(1.8, 0.4, 0.06), Vector3(0, 0.69, 0.25), k.wood_light, false, bn)
	for sx in [-0.8, 0.8]:
		k.box(Vector3(0.08, 0.45, 0.5), Vector3(sx, 0.225, 0), k.mat(Color(0.2, 0.22, 0.2), 0.5, 0.5), false, bn)
	k.box(Vector3(0.5, 0.06, 0.12), Vector3(0, 0.8, 0.29), k.brass, false, bn)
	# Bruno's crate, left by the path
	var cr: Node3D = k.hotspot("crate", Vector3(8.0, 0, -1.6), Vector3(1.2, 1.0, 1.0), Vector3(0, 0.5, 0))
	k.crate(Vector3.ZERO, Vector3(0.9, 0.7, 0.7), 0.3, null, true, cr)
	k.rope_coil(Vector3(0.0, 0.7, 0.0), 0.8, null, cr)
	var sg: Node3D = k.hotspot("signpost", Vector3(-1.4, 0, -1.4), Vector3(0.8, 2.2, 0.8), Vector3(0, 1.1, 0))
	k.cyl(0.06, 0.07, 2.2, Vector3(0, 1.1, 0), k.wood_dark, sg, true, 8)
	for i in 3:
		var arm: MeshInstance3D = k.box(Vector3(0.9, 0.2, 0.04), Vector3(0.3 * (1 if i % 2 == 0 else -1), 1.9 - i * 0.3, 0), k.wood_light, false, sg, 0.3 * (i - 1))
		if arm:
			pass
	k.blocker(Vector3(1.0, 1.0, 0.5), Vector3(-1.4, 1.6, -1.4))
	k.door("terrace", "Terrace", Vector3(-L, 0, 0.6), PI / 2.0, {"mat": k.mat(Color(0.16, 0.18, 0.18), 0.5, 0.6), "panels": false})
	_gateway(k, Vector3(-L, 0, 0.6), PI / 2.0)
	k.door("prison_yard", "Causeway Gate", Vector3(L, 0, 0.6), -PI / 2.0, {"mat": k.mat(Color(0.16, 0.18, 0.18), 0.5, 0.6), "panels": false})
	_gateway(k, Vector3(L, 0, 0.6), -PI / 2.0, k.mat(Color(0.42, 0.42, 0.45), 0.9))
	k.door("boathouse", "Boathouse Steps", Vector3(0, 0, 3.2), PI, {"mat": k.wood_dark, "panels": false})
	_gateway(k, Vector3(0, 0, 3.2), PI)
	# low walls close the ends of the path either side of the gates
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.5, 1.2, 2.9), Vector3(sd * (L + 0.1), 0.6, -1.95), k.mat(Color(0.64, 0.62, 0.58), 0.9), true)
		k.box(Vector3(0.5, 1.2, 1.5), Vector3(sd * (L + 0.1), 0.6, 2.5), k.mat(Color(0.64, 0.62, 0.58), 0.9), true)
	k.far_prison(Vector3(200, -38, 60), 1.0, -0.9, false)
	k.cctv_pole(Vector3(10.0, 0, -2.8), 3.0, 0.0, 0.5)
	k.omni(Vector3(0, 2.0, 0.0), Color(1.0, 0.95, 0.85), 0.4, 10.0)
	_spots(k, [Vector3(-8.0, 0, 0.4), Vector3(5.0, 0, 0.4), Vector3(13.0, 0, 1.0)])
	_guests(k, "cliff_path", {"a": Vector3(9.4, 0, -0.4)})
	k.spawn = Vector3(-L + 1.3, 0, 0.6)
	k.look = Vector3(0, 1.2, 0.6)


# =================================================================== Boathouse
## A timber boathouse in a cove under the cliff: a slip of sea water down the middle with rowing boats chained in it (every
## one stove in), walkways round it, the big sea doors chained shut with a crocodile padlock, oars and nets on the walls.
## Anchors: boats, workbench, boat_doors, nets.
static func _boathouse(k) -> void:
	k.environment("indoor", Color(0.6, 0.62, 0.62), 0.52)
	var W := 5.5
	var D := 7.0
	var H := 4.2
	k.bounds = Vector2(W * 2.0, D * 2.0)
	var boards: ShaderMaterial = k.wood_floor(Color(0.3, 0.22, 0.14), Color(0.46, 0.34, 0.22), 0.2)
	var walls: ShaderMaterial = k.wood_wall(Color(0.28, 0.2, 0.13), Color(0.42, 0.3, 0.2), 0.24)
	k.slab(-W, -D, -2.0, D, 0.0, boards)
	k.slab(2.0, -D, W, D, 0.0, boards)
	k.slab(-2.0, 4.6, 2.0, D, 0.0, boards)
	Kit.arch(k.box(Vector3(4.0, 0.1, 11.6), Vector3(0, -0.85, -1.2), k.water(Color(0.04, 0.2, 0.26), Color(0.2, 0.46, 0.5), 0.12)), "floor")
	# a timber curb and mooring posts round the slip keep you out of the water
	for sd in [-1.0, 1.0]:
		k.box(Vector3(0.16, 0.18, 11.6), Vector3(sd * 1.92, 0.09, -1.2), k.wood_dark)
		k._oriented_blocker(Vector3(sd * 1.95, 0, -D), Vector3(sd * 1.95, 0, 4.6), 0.12, 1.0)
		for i in 4:
			k.cyl(0.1, 0.12, 0.9, Vector3(sd * 1.92, 0.45, -5.6 + i * 3.0), k.wood_dark, null, true, 10)
	k.box(Vector3(4.0, 0.18, 0.16), Vector3(0, 0.09, 4.52), k.wood_dark)
	k._oriented_blocker(Vector3(-2.0, 0, 4.55), Vector3(2.0, 0, 4.55), 0.12, 1.0)
	var o := {"wall": walls, "wain": null, "trim": k.wood_dark}
	k.wall_run(Vector2(-W, D), Vector2(-W, -D), 0.0, H, o)
	k.wall_run(Vector2(W, -D), Vector2(W, D), 0.0, H, o)
	k.wall_run(Vector2(W, D), Vector2(-W, D), 0.0, H, o)
	k.wall_run(Vector2(-W, -D), Vector2(W, -D), 0.0, H, o, [[W - 2.0, W + 2.0, -1.0, 3.4]])
	# the pitched roof and its trusses
	var rise := 2.0
	var rl := sqrt(W * W + rise * rise)
	var slope := atan2(rise, W)
	for sd in [-1.0, 1.0]:
		var rf: MeshInstance3D = Kit.arch(k.box(Vector3(0.12, rl + 0.2, D * 2.0 + 0.4), Vector3(sd * W / 2.0, H + rise / 2.0, 0), walls), "roof")
		rf.rotation.z = sd * (PI / 2.0 - slope)
	for i in 5:
		var z := -D + 1.4 + i * 2.8
		k.box(Vector3(W * 2.0, 0.16, 0.14), Vector3(0, H - 0.08, z), k.wood_dark)
		k.box(Vector3(0.14, rise, 0.14), Vector3(0, H + rise / 2.0, z), k.wood_dark)
	# the sea doors, chained, with the light of the cove through the gaps
	var bd: Node3D = k.hotspot("boat_doors", Vector3(0, 0.0, -D), Vector3(4.0, 3.0, 0.6), Vector3(0, 1.8, 0.3))
	for sd in [-1.0, 1.0]:
		k.box(Vector3(1.96, 3.4, 0.08), Vector3(sd * 1.0, 1.4, 0.06), walls, false, bd)
		for i in 3:
			k.box(Vector3(1.9, 0.1, 0.04), Vector3(sd * 1.0, 0.4 + i * 1.2, 0.12), k.wood_dark, false, bd)
	for i in 6:
		k.torus(0.04, 0.06, Vector3(-0.25 + i * 0.1, 1.6, 0.16), k.steel, bd, Vector3(0, 0, PI / 2.0 * float(i % 2)))
	k.box(Vector3(0.18, 0.22, 0.08), Vector3(0.0, 1.45, 0.2), k.mat(Color(0.2, 0.42, 0.22), 0.5), false, bd)
	k.box(Vector3(4.0, 0.04, 0.02), Vector3(0, 3.12, -D + 0.02), k.glow(Color(0.8, 0.9, 1.0), 1.2))
	# the boats in the slip, stove in and chained to the rings
	var bt: Node3D = k.hotspot("boats", Vector3(0, 0, -1.0), Vector3(3.0, 1.0, 3.6), Vector3(0, 0.55, 0))
	for i in 2:
		var bp := Vector3(-0.9 + i * 1.8, -0.55, -2.4 + i * 2.6)
		var hull: MeshInstance3D = k.sphere(1.0, bp, k.mat([Color(0.62, 0.22, 0.16), Color(0.24, 0.4, 0.5)][i], 0.7), bt, Vector3(0.6, 0.35, 1.7), 16)
		if hull:
			pass
		k.box(Vector3(1.1, 0.05, 0.22), bp + Vector3(0, 0.3, 0.2), k.wood_light, false, bt)
		k.box(Vector3(0.3, 0.04, 0.34), bp + Vector3(0.2, 0.32, 0.9), k.black, false, bt, 0.4)
		k.beam(bp + Vector3(0, 0.3, -1.5), Vector3(-2.0 if i == 0 else 2.0, 0.05, bp.z - 1.4), 0.02, k.steel)
	# walkway clutter: oars on the wall, nets, a workbench, lanterns
	for i in 4:
		var oar: MeshInstance3D = k.box(Vector3(0.05, 2.6, 0.05), Vector3(-W + 0.03, 1.32, -4.0 + i * 0.4), k.wood_light, false, null, 0.0)
		oar.rotation.x = 0.12
		k.box(Vector3(0.04, 0.5, 0.16), Vector3(-W + 0.03, 0.25, -4.0 + i * 0.4 + 0.12), k.wood_light)
	var nt: Node3D = k.hotspot("nets", Vector3(W, 1.6, -3.0), Vector3(0.4, 1.4, 2.2), Vector3(-0.15, 0, 0), -PI / 2.0)
	for i in 6:
		k.box(Vector3(1.8, 0.03, 0.02), Vector3(0, 0.6 - i * 0.22, 0.03), k.mat(Color(0.6, 0.55, 0.4), 0.95), false, nt)
		k.box(Vector3(0.02, 1.3, 0.02), Vector3(-0.85 + i * 0.34, 0.0, 0.035), k.mat(Color(0.6, 0.55, 0.4), 0.95), false, nt)
	for i in 3:
		k.sphere(0.1, Vector3(-0.6 + i * 0.6, -0.5, 0.08), k.mat(Color(0.9, 0.5, 0.2), 0.6), nt, Vector3.ONE, 10)
	var wb: Node3D = k.hotspot("workbench", Vector3(3.8, 0, 3.0), Vector3(1.6, 1.1, 0.9), Vector3(0, 0.55, 0))
	k.table(Vector3.ZERO, Vector3(1.5, 0.86, 0.7), k.wood_light, k.wood_dark, 0.0, wb)
	k.box(Vector3(0.4, 0.06, 0.12), Vector3(-0.3, 0.89, 0.0), k.steel, false, wb, 0.3)
	k.cyl(0.08, 0.08, 0.14, Vector3(0.4, 0.93, 0.1), k.mat(Color(0.55, 0.2, 0.12), 0.5), wb, false, 12)
	k.rope_coil(Vector3(-4.0, 0, 5.6), 1.2)
	k.rope_coil(Vector3(4.4, 0, -5.8), 1.0)
	# lobster pots, buoys, a tarp over something, life rings, a paddle rack, a barrel
	for i in 3:
		var lp := Vector3(-4.4, 0, -1.0 + i * 0.75)
		k.cyl(0.3, 0.3, 0.42, lp + Vector3(0, 0.21, 0), k.mat(Color(0.5, 0.4, 0.28), 0.95), null, true, 12)
		for j in 4:
			k.torus(0.28, 0.31, lp + Vector3(0, 0.06 + j * 0.11, 0), k.mat(Color(0.38, 0.3, 0.2), 0.9))
	for i in 5:
		k.sphere(0.13, Vector3(W - 0.13, 2.2 - 0.06 * float(i % 2), -1.0 + i * 0.32), k.mat([Color(0.9, 0.3, 0.2), Color(0.95, 0.85, 0.3), Color(0.95, 0.95, 0.95)][i % 3], 0.5), null, Vector3.ONE, 10)
	# a ladder down into the slip, a tool rack, lanterns hung on nails, a paddle rack
	for sd in [-0.2, 0.2]:
		k.box(Vector3(0.05, 1.4, 0.05), Vector3(1.95 + sd * 0.0, 0.0, 2.6 + sd), k.wood_light)
	for i in 4:
		k.box(Vector3(0.05, 0.03, 0.4), Vector3(1.95, -0.5 + i * 0.3, 2.6), k.wood_light)
	var tr: Node3D = k.wall_shelf(Vector3(W, 1.8, 3.0), -PI / 2.0, 1.4, 0.2, k.wood_dark)
	for i in 5:
		k.box(Vector3(0.06, 0.3 + 0.1 * float(i % 2), 0.04), Vector3(-0.5 + i * 0.25, 0.15 + 0.05 * float(i % 2), 0.1), k.mat([Color(0.6, 0.62, 0.64), Color(0.5, 0.35, 0.2)][i % 2], 0.5, 0.4), false, tr)
	for z in [-3.0, 4.6]:
		k.box(Vector3(0.04, 0.04, 0.12), Vector3(-W + 0.02, 2.3, z), k.steel)
		k.cyl(0.08, 0.08, 0.2, Vector3(-W + 0.1, 2.14, z), k.mat(Color(0.2, 0.22, 0.2), 0.5, 0.5), null, false, 10)
	for i in 4:
		k.box(Vector3(0.04, 1.6, 0.14), Vector3(-W + 0.02, 0.8, 4.0 + i * 0.22), k.wood_light)
	k.box(Vector3(1.2, 0.7, 0.9), Vector3(3.6, 0.35, -5.4), k.mat(Color(0.3, 0.36, 0.26), 0.95), true)
	k.box(Vector3(1.3, 0.04, 1.0), Vector3(3.6, 0.72, -5.4), k.mat(Color(0.34, 0.4, 0.3), 0.95))
	for z in [-2.0, 1.0]:
		k.torus(0.18, 0.28, Vector3(-W + 0.06, 1.9, z), k.stripes(Color(0.95, 0.95, 0.95), Color(0.85, 0.15, 0.12), 4.0), null, Vector3(0, 0, PI / 2.0))
		k.box(Vector3(0.04, 0.06, 0.06), Vector3(-W + 0.02, 2.14, z), k.steel)
	k.cyl(0.3, 0.3, 0.8, Vector3(4.6, 0.4, 5.8), k.mat(Color(0.45, 0.3, 0.18), 0.8), null, true, 14)
	k.cyl(0.31, 0.31, 0.05, Vector3(4.6, 0.65, 5.8), k.steel, null, false, 14)
	k.cyl(0.31, 0.31, 0.05, Vector3(4.6, 0.15, 5.8), k.steel, null, false, 14)
	for p in [Vector3(-3.6, 0, 6.2), Vector3(-3.0, 0, 6.3)]:
		var pp: Vector3 = p
		k.crate(pp, Vector3(0.6, 0.5, 0.5), _h(int(pp.x * 10.0)), null, true)
	for p in [Vector3(-W, 2.6, 2.0), Vector3(W, 2.6, 4.0)]:
		var pp: Vector3 = p
		k.wall_lamp(pp, PI / 2.0 if pp.x < 0.0 else -PI / 2.0, LAMP, 0.8, 7.0)
	k.hanging_lamp(Vector3(0, 3.2, 1.0), WARM, 1.4, H, true, 10.0)
	k.omni(Vector3(0, 1.0, -D + 1.0), SEA_LIGHT, 0.6, 6.0)
	k.door("cliff_path", "Cliff Path", Vector3(0, 0, D), PI, {"mat": k.wood_dark})
	k.cctv(Vector3(W, 3.0, D - 0.6), -PI / 2.0, 0.6)
	_spots(k, [Vector3(-3.5, 0, 0.0), Vector3(3.5, 0, -1.0)])
	k.spawn = Vector3(0, 0, D - 1.2)
	k.look = Vector3(0, 1.2, -D)


# =================================================================== Prison Yard
## The Gaol's yard: grey walls with wire on top, the cell block's rows of barred windows, a watchtower with its searchlight,
## the gatehouse office with a typewriter on its desk behind the window, and the door to the Visiting Room.
## Anchors: cell_windows, gate, office_window, watchtower.
static func _prison_yard(k) -> void:
	_outdoor(k)
	var W := 13.0
	var D := 10.0
	var WH := 8.0
	k.bounds = Vector2(W * 2.0, D * 2.0)
	k.slab(-W, -D, W, D, 0.0, k.stone_floor(Color(0.44, 0.44, 0.44), Color(0.54, 0.54, 0.52), 1.2), 0.4)
	var grey: Material = k.brick(Color(0.46, 0.46, 0.48), Color(0.58, 0.58, 0.58), Color(0.36, 0.36, 0.38), Vector2(0.62, 0.3))
	var o := {"wall": grey, "wain": k.mat(Color(0.34, 0.34, 0.36), 0.9), "wain_h": 1.2, "trim": k.mat(Color(0.3, 0.3, 0.32), 0.9)}
	k.wall_run(Vector2(-W, -D), Vector2(W, -D), 0.0, WH + 4.0, o)
	k.wall_run(Vector2(W, -D), Vector2(W, D), 0.0, WH, o)
	k.wall_run(Vector2(W, D), Vector2(-W, D), 0.0, WH, o)
	k.wall_run(Vector2(-W, D), Vector2(-W, -D), 0.0, WH, o)
	for e in [[Vector3(0, WH, D), W * 2.0, 0.0], [Vector3(W, WH, 0), D * 2.0, PI / 2.0], [Vector3(-W, WH, 0), D * 2.0, PI / 2.0]]:
		var c: Vector3 = e[0]
		var ln: float = e[1]
		var r: float = e[2]
		var n := int(ln / 2.0)
		for i in n + 1:
			var t := -ln / 2.0 + i * ln / n
			var p := c + Basis(Vector3.UP, r) * Vector3(t, 0, 0)
			k.box(Vector3(0.06, 0.9, 0.06), p + Vector3(0, 0.45, 0), k.steel)
		for j in 3:
			k.beam(c + Basis(Vector3.UP, r) * Vector3(-ln / 2.0, 0.3 + j * 0.3, 0), c + Basis(Vector3.UP, r) * Vector3(ln / 2.0, 0.3 + j * 0.3, 0), 0.008, k.steel)
	# the cell block facade on the north wall: rows of barred windows, a few lit
	var cw: Node3D = k.hotspot("cell_windows", Vector3(-4.0, 1.4, -D), Vector3(4.0, 1.6, 0.6), Vector3(0, 0, 0.3))
	if cw:
		pass
	for r in 3:
		for c in 10:
			var x := -11.0 + c * 2.4
			var y := 3.0 + r * 3.0
			if absf(x - 5.8) < 1.3 and r == 0:
				continue
			k.box(Vector3(0.8, 1.0, 0.04), Vector3(x, y, -D + 0.02), k.mat(Color(0.12, 0.12, 0.14), 0.6) if (r * 3 + c) % 4 else k.glow(Color(1.0, 0.8, 0.45), 0.9))
			for b in 4:
				k.box(Vector3(0.04, 1.0, 0.06), Vector3(x - 0.3 + b * 0.2, y, -D + 0.05), k.steel)
	# the Visiting Room door in the block, the gate back to the causeway
	k.door("visiting_room", "Visiting Room", Vector3(5.8, 0, -D), 0.0, {"mat": k.steel, "frame": k.mat(Color(0.3, 0.3, 0.32), 0.6, 0.4), "porthole": true})
	k.door("cliff_path", "Causeway Gate", Vector3(0, 0, D), PI, {"mat": k.mat(Color(0.2, 0.2, 0.22), 0.5, 0.6), "panels": false, "w": 1.6, "h": 2.6})
	k.box(Vector3(3.0, 1.0, 0.6), Vector3(0, 3.4, D - 0.3), grey)
	_crest(k, Vector3(0, 3.4, D - 0.6), PI, 1.2)
	# the watchtower in the north-east corner, with its searchlight
	var wt: Node3D = k.hotspot("watchtower", Vector3(W - 1.4, 0, -D + 1.4), Vector3(2.2, 3.0, 2.2), Vector3(0, 1.5, 0))
	for sx in [-0.9, 0.9]:
		for sz in [-0.9, 0.9]:
			k.box(Vector3(0.2, 8.0, 0.2), Vector3(sx, 4.0, sz), k.mat(Color(0.3, 0.3, 0.32), 0.7), true, wt)
	k.box(Vector3(2.4, 2.2, 2.4), Vector3(0, 9.1, 0), grey, false, wt)
	k.box(Vector3(2.8, 0.2, 2.8), Vector3(0, 10.3, 0), k.mat(Color(0.25, 0.25, 0.28), 0.7), false, wt)
	k.cyl(0.4, 0.5, 0.6, Vector3(-0.6, 10.7, 0.6), k.steel, wt, false, 14)
	k.cyl(0.36, 0.36, 0.02, Vector3(-0.6, 10.7, 0.92), k.glow(Color(1.0, 0.98, 0.9), 3.0), wt, false, 14).rotation.x = PI / 2.0
	for i in 6:
		k.box(Vector3(0.06, 6.0, 0.06), Vector3(0.9, 3.0, -0.9 + i * 0.36), k.steel, false, wt)
	# the gatehouse office: a little brick hut by the gate, a typewriter on the desk behind its window
	var ow: Node3D = k.hotspot("office_window", Vector3(-9.0, 0, 7.0), Vector3(1.6, 2.2, 0.8), Vector3(0, 1.4, -1.6))
	var hut := Vector3(-9.0, 0, 8.4)
	k.box(Vector3(4.0, 3.2, 3.0), hut + Vector3(0, 1.6, 0), k.brick(), true)
	k.box(Vector3(4.4, 0.2, 3.4), hut + Vector3(0, 3.3, 0), k.mat(Color(0.25, 0.25, 0.28), 0.7))
	k.box(Vector3(1.4, 0.9, 0.04), hut + Vector3(0, 1.6, -1.52), k.mat(Color(0.25, 0.3, 0.32), 0.1, 0.3))
	k.box(Vector3(1.5, 1.0, 0.03), hut + Vector3(0, 1.6, -1.515), k.wood_dark)
	k.box(Vector3(1.6, 0.06, 0.24), hut + Vector3(0, 1.1, -1.6), grey)
	k.typewriter(hut + Vector3(0, 1.13, -1.62), PI, Color(0.2, 0.22, 0.2))
	k.box(Vector3(0.3, 0.02, 0.2), hut + Vector3(0.5, 1.14, -1.62), k.paper, false, null, 0.2)
	if ow:
		pass
	k.picture(hut + Vector3(1.4, 2.4, -1.5), PI, Vector2(0.6, 0.3), Color(0.95, 0.92, 0.84), k.black, "OFFICE", 0)
	# yard furniture: a bench, the exercise ring painted on the ground, a drinking fountain, a Snapjaw banner
	k.box(Vector3(2.4, 0.08, 0.5), Vector3(-8.0, 0.45, -D + 1.4), k.wood_light, true)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.08, 0.45, 0.45), Vector3(-8.0 + sx, 0.225, -D + 1.4), k.steel)
	for i in 24:
		var a := i * TAU / 24.0
		k.box(Vector3(0.5, Kit.LAYER, 0.12), Vector3(cos(a) * 5.0, Kit.LAYER / 2.0, sin(a) * 4.0 + 1.0), k.mat(Color(0.9, 0.85, 0.3), 0.8), false, null, -a + PI / 2.0)
	var fnt := Vector3(8.0, 0, 6.0)
	k.cyl(0.25, 0.3, 0.9, fnt + Vector3(0, 0.45, 0), grey, null, true, 14)
	k.cyl(0.3, 0.3, 0.06, fnt + Vector3(0, 0.93, 0), k.steel, null, false, 14)
	k.beam(fnt + Vector3(0, 0.96, 0), fnt + Vector3(0.1, 1.08, 0), 0.015, k.steel)
	k.box(Vector3(0.05, 3.0, 2.0), Vector3(W - 0.03, 5.0, 2.0), k.mat(Color(0.5, 0.08, 0.16), 0.8))
	_crest(k, Vector3(W - 0.06, 5.4, 2.0), -PI / 2.0, 1.0)
	k.cctv(Vector3(-W, 4.0, -D + 0.4), PI / 2.0, 0.6)
	k.cctv(Vector3(W, 4.0, D - 0.4), -PI / 2.0, 0.6)
	k.wall_lamp(Vector3(5.8 + 1.0, 2.6, -D), 0.0, LAMP, 0.7, 6.0)
	k.wall_lamp(Vector3(1.4, 2.6, D), PI, LAMP, 0.7, 6.0)
	_spots(k, [Vector3(-3.0, 0, 3.0), Vector3(3.0, 0, -3.0), Vector3(-6.0, 0, -4.0)])
	k.spawn = Vector3(0, 0, D - 1.3)
	k.look = Vector3(0, 3.0, -D)


# =================================================================== Visiting Room
## A long room cut in half by thick glass: on this side eleven booths with stools and telephones on hooks, on the far side
## the prisoners' chairs under a barred light. A guard's desk, a clock, and the sign about the thirty seconds.
## Anchors: booths, phone, guard_desk, glass.
static func _visiting_room(k) -> void:
	var L := 9.0
	k.environment("indoor", Color(0.6, 0.62, 0.62), 0.5)
	var o := {"floor": k.stone_floor(Color(0.42, 0.44, 0.44), Color(0.52, 0.54, 0.54), 0.6), "wall": k.mat(Color(0.7, 0.74, 0.72), 0.9),
		"wain": k.mat(Color(0.32, 0.42, 0.4), 0.7), "wain_h": 1.2, "trim": k.mat(Color(0.3, 0.32, 0.32), 0.7), "ceiling": k.mat(Color(0.78, 0.8, 0.78), 0.95)}
	k.plan([[-L, -4.6, L, 3.2]], 0.0, 3.4, o)
	k.bounds = Vector2(L * 2.0, 7.8)
	k.door("prison_yard", "Prison Yard", Vector3(-6.0, 0, 3.2), PI, {"mat": k.steel, "frame": k.mat(Color(0.3, 0.3, 0.32), 0.6, 0.4), "porthole": true})
	# the counter and the glass, the booths and their stools
	k.box(Vector3(L * 2.0, 0.9, 0.5), Vector3(0, 0.45, -0.25), k.mat(Color(0.5, 0.54, 0.54), 0.6), true)
	k.box(Vector3(L * 2.0, 0.05, 0.6), Vector3(0, 0.925, -0.25), k.mat(Color(0.3, 0.34, 0.34), 0.5))
	var gl: Node3D = k.hotspot("glass", Vector3(4.0, 0.95, -0.55), Vector3(1.4, 1.6, 0.3), Vector3(0, 0.8, 0))
	if gl:
		pass
	var glass_m: StandardMaterial3D = k.mat(Color(0.72, 0.86, 0.9, 0.22), 0.05, 0.1)
	glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	k.box(Vector3(L * 2.0, 2.36, 0.04), Vector3(0, 0.95 + 1.18, -0.55), glass_m)
	k.blocker(Vector3(L * 2.0, 3.4, 0.3), Vector3(0, 1.7, -0.6))
	var bh: Node3D = k.hotspot("booths", Vector3(-2.4, 0, 0.4), Vector3(1.4, 1.2, 0.8), Vector3(0, 0.6, 0))
	if bh:
		pass
	for i in 12:
		var x := -L + 0.75 + i * 1.5
		k.box(Vector3(0.06, 1.6, 0.72), Vector3(x - 0.75, 0.95 + 0.8, -0.17), k.mat(Color(0.3, 0.34, 0.34), 0.5))
		if i == 11:
			continue
		k.stool(Vector3(x, 0, 0.55), k.mat(Color(0.5, 0.15, 0.12), 0.6), 0.5)
		k.box(Vector3(0.08, 0.2, 0.06), Vector3(x + 0.4, 1.3, -0.5), k.black)
		k.beam(Vector3(x + 0.4, 1.2, -0.44), Vector3(x + 0.3, 0.98, -0.3), 0.006, k.black)
	var ph: Node3D = k.hotspot("phone", Vector3(2.0 + 0.4 + 1.5 * 0.0, 1.3, -0.4), Vector3(0.3, 0.4, 0.3), Vector3(0, 0, 0))
	if ph:
		pass
	# the far side: chairs, a barred light, a barred door
	for i in 11:
		var x := -L + 0.75 + i * 1.5
		k.chair(Vector3(x, 0, -1.4), 0.0, k.mat(Color(0.4, 0.42, 0.42), 0.7), k.steel)
	k.box(Vector3(1.2, 2.2, 0.06), Vector3(0, 1.1, -4.57), k.steel)
	for i in 5:
		k.box(Vector3(0.04, 2.2, 0.08), Vector3(-0.5 + i * 0.25, 1.1, -4.5), k.mat(Color(0.2, 0.2, 0.22), 0.5, 0.6))
	k.omni(Vector3(0, 2.6, -2.6), Color(0.85, 0.9, 1.0), 0.8, 7.0)
	# this side: the guard's desk, the clock, the sign
	var gd: Node3D = k.hotspot("guard_desk", Vector3(6.6, 0, 2.2), Vector3(1.6, 1.2, 1.0), Vector3(0, 0.6, 0))
	k.box(Vector3(1.4, 0.8, 0.7), Vector3(0, 0.4, 0), k.mat(Color(0.42, 0.46, 0.46), 0.6), true, gd)
	k.box(Vector3(1.5, 0.05, 0.76), Vector3(0, 0.825, 0), k.wood_mid, false, gd)
	k.box(Vector3(0.36, 0.02, 0.26), Vector3(-0.3, 0.86, 0.0), k.mat(Color(0.3, 0.22, 0.16), 0.8), false, gd)
	k.cyl(0.05, 0.05, 0.04, Vector3(0.4, 0.87, 0.1), k.brass, gd, false, 12)
	k.chair(Vector3(6.6, 0, 2.85), PI, k.mat(Color(0.4, 0.42, 0.42), 0.7), k.steel)
	k.wall_clock(Vector3(0.0, 2.7, 3.2), PI, 0.24)
	k.picture(Vector3(-2.8, 2.5, 3.2), PI, Vector2(1.2, 0.5), Color(0.95, 0.92, 0.84), k.black, "30 SECONDS.\nNO TOUCHING.", 0, Color(0.6, 0.08, 0.06))
	k.picture(Vector3(L, 1.9, 1.4), -PI / 2.0, Vector2(0.5, 0.7), Color(0.95, 0.92, 0.84), k.black, "RULES", 6)
	for x in [-6.0, 0.0, 6.0]:
		k.hanging_lamp(Vector3(x, 2.8, 1.4), Color(0.95, 0.98, 1.0), 1.0, 3.4, x == 0.0, 7.0)
	k.cctv(Vector3(L, 2.9, 2.8), -PI / 2.0, 0.6)
	k.cctv(Vector3(-L, 2.9, 2.8), PI / 2.0, -0.6)
	_spots(k, [Vector3(-2.0, 0, 2.0), Vector3(2.4, 0, 2.0)])
	k.spawn = Vector3(-6.0, 0, 2.0)
	k.look = Vector3(2.0, 1.4, -0.6)
