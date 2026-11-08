extends "res://scripts/screens/investigation_screen.gd"
## INVESTIGATION - 3D walk-around version.
## Same rules as the 2D screen this extends: rooms, hotspots and people come from investigation_data*.gd,
## talking / examining plays the same story ids, sets the same "seen_<id>" flags, grants the same Truth
## Drops, and the investigation ends when every required Truth Drop is found (then "investigation_complete").
## The map (M), notebook (N), banners, toasts and the autotest path are inherited unchanged.
##
## What changes: each room is a walkable 3D space (scripts/world3d/rooms1.gd / rooms2.gd). Hotspots are 3D
## objects, people are standees of their portraits, and exits are doors with a sign. Look at something
## (crosshair) and press E / Space / click. Unexamined things have a sparkle above them, examined ones a check.
##
## Debug (screenshots): --room3d=<room id> starts in that room with all intro snippets skipped;
## --cam=x,y,z,tx,ty,tz places the camera; --door3d=<room id> walks through that door on arrival.

const Kit := preload("res://scripts/world3d/kit.gd")
const Player3D := preload("res://scripts/world3d/player3d.gd")
const Hud3D := preload("res://scripts/world3d/hud3d.gd")
const MouseGuard := preload("res://scripts/world3d/mouse_guard.gd")
const Rooms1 := preload("res://scripts/world3d/rooms1.gd")
const Rooms2 := preload("res://scripts/world3d/rooms2.gd")
const LiftRide := preload("res://scripts/world3d/lift_ride.gd")

var _holder: Node3D
var _room3d: Node3D
var _player: CharacterBody3D
var _hud: Control
var _dim: ColorRect
var _kit: RefCounted
var _doors: Array = []
var _arrive_from := ""
var _rim: ShaderMaterial
var _talk_dim := false
var _t3 := 0.0
var _debug_room := ""
var _spaces: Dictionary = {}    # connecting spaces of this chapter (id -> {name, map_at})
var _flickers: Array = []


## Stands in for the investigation data script: the real rooms plus the walkable connecting spaces, which have no
## hotspots or people. ROOM_ORDER keeps only the real rooms, so the 2D map and the autotest stay the same.
class WorldData extends RefCounted:
	var ROOMS: Dictionary = {}
	var ROOM_ORDER: Array = []
	var START_ROOM := ""
	var SLOT_X: Dictionary = {}
	var PERSON_SCALE := 0.62


func _make_world_data() -> void:
	_spaces = Rooms2.SPACES if Chapters.current == 2 else Rooms1.SPACES
	var w := WorldData.new()
	w.ROOMS = (Inv.ROOMS as Dictionary).duplicate()
	for id in _spaces.keys():
		w.ROOMS[id] = {"name": str((_spaces[id] as Dictionary)["name"]), "bg": "", "enter_script": "", "hotspots": [], "people": []}
	w.ROOM_ORDER = Inv.ROOM_ORDER
	w.START_ROOM = Inv.START_ROOM
	w.SLOT_X = Inv.SLOT_X
	w.PERSON_SCALE = Inv.PERSON_SCALE
	Inv = w


func _ready() -> void:
	_make_world_data()
	_debug_room = MouseGuard.arg("room3d")
	if _debug_room != "":
		for rid in Inv.ROOMS.keys():
			var room: Dictionary = Inv.ROOMS[rid]
			Game.set_flag("seen_" + str(room.get("enter_script", "")), true)
	super()
	_fx.show_marks = false
	_hud.set_hints([["WASD", "Move"], ["Mouse", "Look"], ["E / Click", "Examine / Talk"], ["Shift", "Hurry"],
		["M", "Map"], ["N", "Notebook"], ["Esc", "Pause"]])
	for id in _spaces.keys():
		_cleared[id] = true
	var guard := MouseGuard.new()
	guard.want = _wants_mouse
	add_child(guard)


func _wants_mouse() -> bool:
	return _can_hover() and not Game.autotest and Game.shot_path == "" and is_visible_in_tree() \
		and get_window().has_focus()


# =================================================================== world
func _build_world() -> void:
	_holder = Node3D.new()
	add_child(_holder)
	_player = Player3D.new()
	_holder.add_child(_player)
	_world = _layer()
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.03, 0.02, 0.07, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_dim)
	_hud = Hud3D.new()
	_world.add_child(_hud)
	_rim = ShaderMaterial.new()
	_rim.shader = Kit.shader(Kit.SH_RIM)


func _build_room(rid: String) -> void:
	if _debug_room != "" and Inv.ROOMS.has(_debug_room):
		rid = _debug_room
		_debug_room = ""
	_room_id = rid
	var room: Dictionary = Inv.ROOMS[rid]
	_targets.clear()
	_doors.clear()
	_hover = {}
	_tag.visible = false
	if _room3d:
		_holder.remove_child(_room3d)
		_room3d.queue_free()
	_room3d = Node3D.new()
	_holder.add_child(_room3d)
	var k := Kit.new(_room3d)
	_kit = k
	var names := {}
	for r in Inv.ROOMS.keys():
		names[r] = str((Inv.ROOMS[r] as Dictionary).get("name", r))
	if Chapters.current == 2:
		Rooms2.build(rid, k, names)
	else:
		Rooms1.build(rid, k, names)
	# examinable things
	var fallback_i := 0
	for h in room.get("hotspots", []):
		var hd: Dictionary = h
		var id := str(hd.get("id", ""))
		var a: Dictionary = k.hot.get(id, {})
		if a.is_empty():
			push_warning("3D room %s has no object for hotspot %s" % [rid, id])
			a = _fallback_hotspot(k, id, fallback_i)
			fallback_i += 1
		var t := {
			"kind": "hotspot", "verb": "Examine", "label": str(hd.get("label", "???")), "id": id,
			"script": str(hd.get("script", "")), "rect": Rect2(), "node": a["node"], "body": a["body"],
			"top": a["top"], "seen": false, "pop": 1.0, "spark": randf_range(0.0, 6.0),
		}
		(a["body"] as Node3D).set_meta("target", t)
		t["marker"] = Hud3D.make_marker(_room3d, a["top"])
		_targets.append(t)
	# people
	for p in room.get("people", []):
		var pd: Dictionary = p
		var cid := str(pd.get("char", ""))
		var pos: Vector3 = k.people.get(cid, _slot_pos(k, str(pd.get("slot", "left"))))
		var sd: Dictionary = k.standee(cid, str(pd.get("expr", "normal")), pos)
		var t := {
			"kind": "person", "verb": "Talk", "label": Cast.display_name(cid), "char": cid,
			"script": str(pd.get("script", "")), "rect": Rect2(), "node": sd["holder"], "standee": sd,
			"body": sd["body"], "top": sd["top"], "seen": false, "pop": 1.0, "spark": randf_range(0.0, 6.0),
		}
		(sd["body"] as Node3D).set_meta("target", t)
		t["marker"] = Hud3D.make_marker(_room3d, sd["top"])
		_targets.append(t)
	# small things to look at, and lifts
	for nt in k.notes:
		var nd: Dictionary = nt
		var t := {"kind": "note", "verb": "Look at", "label": str(nd["label"]), "text": str(nd["text"]), "script": "",
			"node": nd["node"], "body": nd["body"], "seen": false}
		(nd["body"] as Node3D).set_meta("target", t)
		_doors.append(t)
	for lid in k.lifts.keys():
		var ld: Dictionary = k.lifts[lid]
		var t := {"kind": "lift", "verb": "Ride to", "label": str(ld["label"]), "lift_id": str(lid), "script": "",
			"node": ld["node"], "body": ld["body"], "seen": false}
		(ld["body"] as Node3D).set_meta("target", t)
		_doors.append(t)
	# exits (a "link" door is an examinable door that becomes an exit once examined)
	for to in k.doors.keys():
		var d: Dictionary = k.doors[to]
		if d.has("link"):
			for ht in _targets:
				if str(ht.get("id", "")) == str(d["link"]):
					ht["door_to"] = str(to)
					ht["door_label"] = str(names.get(to, to))
			continue
		var t := {"kind": "door", "verb": "Go to", "label": str(names.get(to, to)), "to": str(to), "script": "",
			"node": d["node"], "body": d["body"], "hinge": d.get("hinge"), "seen": false}
		(d["body"] as Node3D).set_meta("target", t)
		_doors.append(t)
	_refresh_status()
	for t in _targets:
		t["pop"] = 1.0
	_flickers = k.flickers.duplicate()
	_place_player()


func _place_player() -> void:
	var k = _kit
	var cam := MouseGuard.cam_arg()
	if not cam.is_empty():
		_player.place(Vector3(cam[0].x, cam[0].y - 1.5, cam[0].z), cam[1])
	elif _arrive_from != "" and k.doors.has(_arrive_from):
		var d: Dictionary = k.doors[_arrive_from]
		var b := Basis(Vector3.UP, float(d["rot"]))
		var p: Vector3 = (d["pos"] as Vector3) + b * Vector3(0, 0, 1.15)
		_player.place(p, p + b * Vector3(0, 0, 3.0) + Vector3(0, 1.3, 0))
	else:
		_player.place(k.spawn, k.look)
	_arrive_from = ""


func _slot_pos(k: RefCounted, slot: String) -> Vector3:
	var b: Vector2 = k.bounds
	return Vector3((-0.3 if slot == "left" else 0.3) * b.x, 0.0, 0.05 * b.y)


## Plain pedestal for a hotspot a room builder forgot (never soft-lock on missing 3D art).
func _fallback_hotspot(k: RefCounted, id: String, i: int) -> Dictionary:
	var b: Vector2 = k.bounds
	var g: Node3D = k.hotspot(id, Vector3(-b.x * 0.3 + i * 1.2, 0, -b.y * 0.3), Vector3(0.7, 1.2, 0.7))
	k.box(Vector3(0.5, 0.9, 0.5), Vector3(0, 0.45, 0), k.wood_dark, true, g)
	k.sphere(0.15, Vector3(0, 1.05, 0), k.glow(Style.AQUA, 2.0), g)
	return k.hot[id]


# =================================================================== per-frame: walking, focus, markers
func _process(delta: float) -> void:
	super(delta)
	_t3 += delta
	var walk := _can_hover() and not get_tree().paused
	_player.enabled = walk
	if walk:
		var t: Dictionary = {}
		var b: Node3D = _player.focus_body()
		if b != null:
			t = b.get_meta("target")
		if not is_same(t, _hover):
			_set_hover(t)
	elif not _hover.is_empty():
		_set_hover({})
	for l in _flickers:
		var ol: OmniLight3D = l
		if is_instance_valid(ol):
			ol.light_energy = 2.0 + 0.35 * sin(_t3 * 13.0) + 0.25 * sin(_t3 * 7.3 + 1.0)
	for t in _targets:
		_update_marker(t, delta)
		if str(t["kind"]) == "person":
			var sd: Dictionary = t["standee"]
			var mi: MeshInstance3D = sd["mesh"]
			if is_instance_valid(mi):
				var br := 1.0 + 0.012 * sin(_t3 * 2.1 + float(t["spark"]))
				mi.scale = Vector3(1.0, br, 1.0)


func _update_marker(t: Dictionary, delta: float) -> void:
	var m: Sprite3D = t.get("marker")
	if m == null or not is_instance_valid(m):
		return
	var seen := bool(t["seen"])
	m.visible = not _talk_dim and not is_same(t, _hover)
	var tex := Hud3D.check_tex() if seen else Hud3D.star_tex()
	if m.texture != tex:
		m.texture = tex
	var ph := float(t["spark"])
	var top: Vector3 = t["top"]
	m.position = top + Vector3(0, sin(_t3 * 2.0 + ph) * 0.04, 0)
	t["pop"] = minf(float(t["pop"]) + delta * 3.0, 1.0)
	var pop := 1.0 + 0.7 * sin(PI * float(t["pop"])) if float(t["pop"]) < 1.0 else 1.0
	if seen:
		m.modulate.a = 0.92
		m.pixel_size = 0.0003 * pop
	else:
		var tw := 0.5 + 0.5 * sin(_t3 * 2.6 + ph)
		m.modulate.a = 0.45 + 0.55 * tw
		m.pixel_size = (0.00034 + 0.0001 * tw) * pop


# =================================================================== focus / highlight / prompt
func _set_hover(t: Dictionary, quiet: bool = false) -> void:
	if is_same(_hover, t):
		return
	if not _hover.is_empty():
		_highlight(_hover, false)
	_hover = t
	if t.is_empty():
		_tag.visible = false
		_hud.set_focus(false)
		return
	_highlight(t, true)
	_hud.set_focus(true)
	if not quiet:
		Audio.sfx("select", 1.0 + randf_range(-0.05, 0.05), -6.0)
	_show_tag(t)


func _hover_under_mouse() -> void:
	pass   # focus follows the crosshair (see _process)


func _highlight(t: Dictionary, on: bool) -> void:
	if str(t.get("kind", "")) in ["note", "lift"]:
		return
	if str(t.get("kind", "")) == "person":
		var sd: Dictionary = t["standee"]
		var m: ShaderMaterial = sd["mat"]
		m.set_shader_parameter("outline", 1.0 if on else 0.0)
		m.set_shader_parameter("brightness", 1.1 if on else 1.0)
		return
	var n: Node3D = t.get("node")
	if n and is_instance_valid(n):
		_set_overlay(n, _rim if on else null)


func _set_overlay(n: Node, m: Material) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_overlay = m
		_set_overlay(c, m)


func _show_tag(t: Dictionary) -> void:
	var kind := str(t["kind"])
	_tag_verb.text = str(t["verb"]) + ":"
	_tag_name.text = str(t["label"])
	if _acts_as_door(t):
		kind = "door"
		_tag_verb.text = "Go to:"
		_tag_name.text = str(t["door_label"])
	_tag_check.visible = bool(t["seen"]) and kind in ["hotspot", "person"]
	var st: StyleBoxFlat = _tag.get_theme_stylebox("panel")
	st.border_color = Style.GOOD if _tag_check.visible else (Style.YUZU if kind in ["door", "lift"] else Style.AQUA)
	_tag.reset_size()
	var sz := _tag.get_combined_minimum_size()
	_tag.size = sz
	_tag.position = Vector2((W - sz.x) * 0.5, H * 0.5 + 38.0)
	_tag.pivot_offset = Vector2(sz.x * 0.5, 0.0)
	_tag.visible = true
	_tag.scale = Vector2.ONE * 0.85
	_tag.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_tag, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_tag, "modulate:a", 1.0, 0.1)


func _set_dialogue_mode(on: bool, instant: bool = false) -> void:
	_fx.show_marks = false
	_talk_dim = on
	if on:
		_tag.visible = false
	if _hud:
		_hud.set_hidden(on)
	var a := 0.42 if on else 0.0
	var bcol := Color(1, 1, 1, 0.45) if on else Color.WHITE
	if _dim_tw:
		_dim_tw.kill()
		_dim_tw = null
	if instant:
		_dim.color.a = a
		_btn_nb.modulate = bcol
		_btn_map.modulate = bcol
	else:
		_dim_tw = create_tween().set_parallel(true)
		_dim_tw.tween_property(_dim, "color:a", a, _dur(0.22))
		_dim_tw.tween_property(_btn_nb, "modulate", bcol, _dur(0.22))
		_dim_tw.tween_property(_btn_map, "modulate", bcol, _dur(0.22))


# =================================================================== actions
func _acts_as_door(t: Dictionary) -> bool:
	return t.has("door_to") and bool(t.get("seen", false)) and not Game.autotest


func _activate(t: Dictionary) -> void:
	if _done:
		return
	var use := str(t.get("kind", ""))
	if use == "note":
		await _read_note(t)
		return
	if use == "lift":
		await _ride(t)
		return
	if use == "door" or _acts_as_door(t):
		_busy = true
		_set_hover({})
		_arrive_from = _room_id
		Audio.sfx("confirm")
		await _swing(t)
		await _travel(str(t["door_to"]) if t.has("door_to") else str(t["to"]))
		return
	_busy = true
	_set_hover({})
	Audio.sfx("confirm")
	_fx.ripple(Vector2(W * 0.5, H * 0.5))
	_pop(t)
	if str(t["kind"]) == "person" and not Game.autotest:
		var n: Node3D = t["node"]
		_player.turn_to(n.global_position + Vector3(0, 1.25, 0), 0.25)
	await _wait(0.16)
	if _done or not is_inside_tree():
		return
	# like the 2D screen: the person's standee fades while their big portrait does the talking
	var sm: ShaderMaterial = null
	if str(t["kind"]) == "person":
		sm = (t["standee"] as Dictionary)["mat"]
		create_tween().tween_method(func(v: float) -> void: sm.set_shader_parameter("alpha", v), 1.0, 0.0, _dur(0.2))
	if await _snippet(str(t["script"]), null):
		return
	if sm:
		create_tween().tween_method(func(v: float) -> void: sm.set_shader_parameter("alpha", v), 0.0, 1.0, _dur(0.25))
	_unlock()


## Swings a door open before stepping through it (examinable doors that act as exits have no hinge).
func _swing(t: Dictionary) -> void:
	var hinge: Variant = t.get("hinge")
	if hinge == null or not is_instance_valid(hinge):
		return
	var tw := create_tween()
	tw.tween_property(hinge, "rotation:y", -1.45, _dur(0.22)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _read_note(t: Dictionary) -> void:
	_busy = true
	_set_hover({})
	Audio.sfx("select")
	_set_dialogue_mode(true)
	_sp.play_text("think: %s\n@end" % str(t["text"]))
	if _sp.is_running():
		await _sp.finished
	if not is_inside_tree():
		return
	_set_dialogue_mode(false)
	_unlock()


## Rides the lift: doors shut, hum, the world swaps behind the doors, doors open on the other floor.
func _ride(t: Dictionary) -> void:
	_busy = true
	_set_hover({})
	Audio.sfx("confirm")
	var from: Dictionary = _kit.lifts[str(t["lift_id"])]
	await LiftRide.move_doors(self, from, false)
	await LiftRide.rumble(self, _player.cam, from)
	if not is_inside_tree():
		return
	var offset: Vector3 = Basis(Vector3.UP, float(from["rot"])).inverse() * (_player.global_position - (from["pos"] as Vector3))
	var from_rot := float(from["rot"])
	var to_space := str(from["to_space"])
	var changed := to_space != "" and to_space != _room_id
	if changed:
		_build_room(to_space)
	var dest: Dictionary = _kit.lifts[str(from["to"])]
	LiftRide.set_doors(dest, false)
	_player.global_position = (dest["pos"] as Vector3) + Basis(Vector3.UP, float(dest["rot"])) * offset
	_player.rotation.y += float(dest["rot"]) - from_rot
	_player.velocity = Vector3.ZERO
	(dest["inside"] as Label3D).text = str(dest["floor"])
	await get_tree().process_frame
	await LiftRide.move_doors(self, dest, true)
	if not is_inside_tree():
		return
	if not changed:
		LiftRide.set_doors(from, true)
	if changed:
		_show_banner()
	if await _enter_script():
		return
	_unlock()


## Little squash-and-stretch on the thing you just used.
func _pop(t: Dictionary) -> void:
	var n: Node3D = t.get("node")
	if n == null or not is_instance_valid(n):
		return
	var s0 := n.scale
	var tw := create_tween()
	tw.tween_property(n, "scale", s0 * Vector3(1.06, 0.94, 1.06), 0.07)
	tw.tween_property(n, "scale", s0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Debug (--door3d=<room id>): walks through that door once the room is ready (tests door travel + arrival spot).
func _unlock() -> void:
	super()
	if OS.get_cmdline_user_args().has("--map3d") and not has_meta("map_tested"):
		set_meta("map_tested", true)
		_open_map()
	var d := MouseGuard.arg("door3d")
	if d != "" and not has_meta("door_tested"):
		for t in _doors:
			if str(t.get("to", "")) == d:
				set_meta("door_tested", true)
				_activate.call_deferred(t)


## The map only takes you to rooms you've already found on foot.
## Debug (--autotest --tour3d): really uses every door, lift and note of every space first, then the normal autotest.
func _autotest() -> void:
	if OS.get_cmdline_user_args().has("--tour3d"):
		await _tour()
	await super()


func _tour() -> void:
	var used := 0
	var bad := 0
	for rid in Inv.ROOMS.keys():
		await _travel(str(rid))
		var count := _doors.size()
		for i in count:
			var t: Dictionary = _doors[i]
			var kind := str(t["kind"])
			var want := str(t.get("to", ""))
			if kind == "lift":
				var lift_to := str((_kit.lifts[str(t["lift_id"])] as Dictionary)["to_space"])
				want = lift_to if lift_to != "" else str(rid)
			elif kind == "note":
				want = str(rid)
			await _activate(t)
			await get_tree().process_frame
			used += 1
			if _room_id != want or _player.global_position.y < -8.0:
				bad += 1
				print("[tour] FAIL %s %s: ended in %s, wanted %s" % [rid, kind, _room_id, want])
			if _busy:
				bad += 1
				print("[tour] FAIL %s %s: still locked afterwards" % [rid, kind])
			await _travel(str(rid))
	print("[tour] investigation: used %d doors/lifts/notes, %d failures" % [used, bad])


func _on_map_pick(rid: String) -> void:
	var enter := str((Inv.ROOMS.get(rid, {}) as Dictionary).get("enter_script", ""))
	if rid != _room_id and not Game.autotest and enter != "" and not _seen(enter):
		Audio.sfx("cancel")
		_close_map()
		_toast("Find your way there on foot first!", Style.YUZU)
		return
	_arrive_from = ""
	super(rid)


func _refresh_status() -> void:
	super()
	if _spaces.has(_room_id):
		_room_prog.text = "Exploring"
		_room_prog.add_theme_color_override("font_color", Style.TEXT_DIM)


## Adds a "you are here" pin when you're in a connecting space (rooms already highlight their own card).
func _build_map() -> Control:
	var root: Control = super()
	var sp: Dictionary = _spaces.get(_room_id, {})
	if sp.is_empty():
		return root
	var board: Control = root.get_meta("board")
	var pin := MapPin.new()
	pin.at = sp["map_at"]
	pin.title = str(sp["name"])
	pin.size = board.size
	board.add_child(pin)
	return root


class MapPin extends Control:
	var at := Vector2.ZERO
	var title := ""
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var r := 11.0 + sin(t * 5.0) * 2.0
		draw_circle(at, r + 7.0, Color(Style.GOLD, 0.25))
		draw_circle(at, r + 2.0, Style.INK)
		draw_circle(at, r, Style.GOLD)
		var f := Style.display_font()
		var label_text := "YOU ARE HERE: " + title.to_upper()
		var w := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var p := at + Vector2(-w * 0.5, -24.0)
		p.x = clampf(p.x, 8.0, size.x - w - 8.0)
		draw_string_outline(f, p, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 6, Style.BG_DARK)
		draw_string(f, p, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Style.GOLD)


func _play(id: String) -> void:
	# screenshot runs (--room3d) skip the opening snippet so the room is visible right away
	if id == "investigation_start" and MouseGuard.arg("room3d") != "":
		return
	await super(id)


func _unhandled_input(e: InputEvent) -> void:
	if MouseGuard.is_interact(e):
		if _can_hover() and Time.get_ticks_msec() >= _lock_ms and not _hover.is_empty():
			get_viewport().set_input_as_handled()
			_activate(_hover)
			return
	super(e)
