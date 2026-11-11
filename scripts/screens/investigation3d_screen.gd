extends "res://scripts/screens/investigation_screen.gd"
## INVESTIGATION - 3D walk-around version.
## Same rules as the 2D screen this extends: rooms, hotspots and people come from investigation_data*.gd,
## talking / examining plays the same story ids, sets the same "seen_<id>" flags, grants the same Truth
## Drops, and the investigation ends the same way (player-ended or on the last required Drop; then "investigation_complete").
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
var _links: Dictionary = {}     # hotspot id -> [room it leads to, that room's name] (k.link_door)
var _fallback_i := 0


## Stands in for the investigation data script: the real rooms plus the walkable connecting spaces, which have no
## hotspots or people. ROOM_ORDER keeps only the real rooms, so the 2D map and the autotest stay the same.
class WorldData extends RefCounted:
	var ROOMS: Dictionary = {}
	var ROOM_ORDER: Array = []
	var START_ROOM := ""
	var SLOT_X: Dictionary = {}
	var PERSON_SCALE := 0.62
	var STAGES: Array = []


func _make_world_data() -> void:
	# a place listed both as a room of the investigation and as a walkable space is that room
	var all_spaces: Dictionary = Chapters.rooms3d().get_script_constant_map()["SPACES"]
	_spaces = {}
	for id in all_spaces.keys():
		if not (Inv.ROOMS as Dictionary).has(id):
			_spaces[id] = all_spaces[id]
	var w := WorldData.new()
	w.ROOMS = (Inv.ROOMS as Dictionary).duplicate()
	for id in _spaces.keys():
		var sp: Dictionary = _spaces[id]
		w.ROOMS[id] = {"name": str(sp["name"]), "bg": "", "enter_script": "", "hotspots": [], "people": [],
			"opens_day": int(sp.get("opens_day", 1)), "opens_stage": int(sp.get("opens_stage", 0))}
	w.ROOM_ORDER = Inv.ROOM_ORDER
	w.START_ROOM = Inv.START_ROOM
	w.SLOT_X = Inv.SLOT_X
	w.PERSON_SCALE = Inv.PERSON_SCALE
	w.STAGES = (Inv as Script).get_script_constant_map().get("STAGES", [])
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
	_set_key_hints()
	for id in _spaces.keys():
		_cleared[id] = true
	var guard := MouseGuard.new()
	guard.want = _wants_mouse
	add_child(guard)


## The key strip at the bottom. T appears with the Finish button (see _can_end), never before.
func _set_key_hints() -> void:
	if _hud == null:
		return
	_hud.set_hints([["WASD", "Move"], ["Mouse", "Look"], ["E / Click", "Examine / Talk"], ["Shift", "Hurry"],
		["M", "Map"], ["N", "Notebook"]] + ([["T", "Finish"]] if _btn_end and _btn_end.visible else []) + [["Esc", "Pause"]])


func _on_finish_shown() -> void:
	_set_key_hints()


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
	_links.clear()
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
	Chapters.rooms3d().call("build", rid, k, names)
	# examinable things (one with "opens_stage" joins once that stage has played, see _open_new_hotspots)
	_fallback_i = 0
	for h in room.get("hotspots", []):
		if _hotspot_open(h):
			_add_hotspot(h)
	# people: at their named spot, else at the room's spare standing spots in order
	var spare: Array = (k.spots as Array).duplicate()
	for p in room.get("people", []):
		var pd: Dictionary = p
		var cid := str(pd.get("char", ""))
		var pos: Vector3 = _slot_pos(k, str(pd.get("slot", "left")))
		if k.people.has(cid):
			pos = k.people[cid]
		elif not spare.is_empty():
			pos = spare.pop_front()
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
			_links[str(d["link"])] = [str(to), str(names.get(to, to))]
			for ht in _targets:
				_link_target(ht)
			continue
		var t := {"kind": "door", "verb": "Go to" if _room_open(str(to)) else "Locked", "label": str(names.get(to, to)), "to": str(to), "script": "",
			"node": d["node"], "body": d["body"], "hinge": d.get("hinge"), "seen": false, "hidden": bool(d.get("hidden", false))}
		# a hidden door (a jib door in the panelling) gives nothing away until the place behind it opens
		if not t["hidden"] or _room_open(str(to)):
			(d["body"] as Node3D).set_meta("target", t)
		_doors.append(t)
	_refresh_status()
	for t in _targets:
		t["pop"] = 1.0
	_flickers = k.flickers.duplicate()
	_place_player()


## One examinable thing: the room builder's anchor of that id (a fallback pedestal if the builder forgot it).
func _add_hotspot(h: Dictionary) -> void:
	var k = _kit
	var id := str(h.get("id", ""))
	var a: Dictionary = k.hot.get(id, {})
	if a.is_empty():
		push_warning("3D room %s has no object for hotspot %s" % [_room_id, id])
		a = _fallback_hotspot(k, id, _fallback_i)
		_fallback_i += 1
	var t := {
		"kind": "hotspot", "verb": "Examine", "label": str(h.get("label", "???")), "id": id,
		"script": str(h.get("script", "")), "rect": Rect2(), "node": a["node"], "body": a["body"],
		"top": a["top"], "seen": false, "pop": 1.0, "spark": randf_range(0.0, 6.0),
	}
	(a["body"] as Node3D).set_meta("target", t)
	t["marker"] = Hud3D.make_marker(_room3d, a["top"])
	_link_target(t)
	_targets.append(t)


## An examinable door that leads somewhere once it has been examined (see k.link_door).
func _link_target(t: Dictionary) -> void:
	var l: Array = _links.get(str(t.get("id", "")), [])
	if l.size() == 2:
		t["door_to"] = str(l[0])
		t["door_label"] = str(l[1])


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
		_btn_end.modulate = bcol
	else:
		_dim_tw = create_tween().set_parallel(true)
		_dim_tw.tween_property(_dim, "color:a", a, _dur(0.22))
		_dim_tw.tween_property(_btn_nb, "modulate", bcol, _dur(0.22))
		_dim_tw.tween_property(_btn_map, "modulate", bcol, _dur(0.22))
		_dim_tw.tween_property(_btn_end, "modulate", bcol, _dur(0.22))


# =================================================================== actions
## Only once the place behind it has opened: until then it's just a thing to look at, and its tag names nothing.
func _acts_as_door(t: Dictionary) -> bool:
	return t.has("door_to") and bool(t.get("seen", false)) and not Game.autotest and _room_open(str(t["door_to"]))


func _activate(t: Dictionary) -> void:
	if _done:
		return
	var use := str(t.get("kind", ""))
	if use == "note":
		await _read_note(t)
		return
	if use == "lift":
		# a lift is held to the same opening days and stages as a door
		var lift_to := str((_kit.lifts[str(t["lift_id"])] as Dictionary)["to_space"])
		if lift_to != "" and lift_to != _room_id and not _room_open(lift_to):
			Audio.sfx("cancel")
			_toast(_locked_text(lift_to), Style.TEXT_DIM)
			return
		await _ride(t)
		return
	if use == "door" or _acts_as_door(t):
		var dest := str(t["door_to"]) if t.has("door_to") else str(t["to"])
		if not _room_open(dest):
			Audio.sfx("cancel")
			_toast(_locked_text(dest), Style.TEXT_DIM)
			return
		_busy = true
		_set_hover({})
		_arrive_from = _room_id
		Audio.sfx("confirm")
		await _swing(t)
		await _travel(str(t["door_to"]) if t.has("door_to") else str(t["to"]))
		return
	_log_examined(t)
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


## Why a place is shut: one whose day hasn't come yet, or one the investigation hasn't got to (which never promises days).
func _locked_text(rid: String) -> String:
	var entry: Dictionary = Inv.ROOMS.get(rid, {})
	if not Chapters.room_open(entry, Chapters.day_at(Game.main.current_step())):
		return "It's locked. Maybe in a day or two."
	return "It's locked. No getting in there for now."


## A stage can open a door: refresh the prompts of the doors in the room you're standing in.
func _on_stage_played() -> void:
	for t in _doors:
		if str(t.get("kind", "")) == "door":
			t["verb"] = "Go to" if _room_open(str(t["to"])) else "Locked"
			if bool(t.get("hidden", false)) and _room_open(str(t["to"])) and is_instance_valid(t["body"]):
				(t["body"] as Node3D).set_meta("target", t)


## Swings a door open before stepping through it (examinable doors that act as exits have no hinge).
func _swing(t: Dictionary) -> void:
	var hinge: Variant = t.get("hinge")
	if hinge == null or not is_instance_valid(hinge):
		return
	var tw := create_tween()
	tw.tween_property(hinge, "rotation:y", -1.45, _dur(0.22)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _read_note(t: Dictionary) -> void:
	_log_examined(t)
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
			# a locked door or lift must leave you where you are
			if kind in ["door", "lift"] and want != str(rid) and not _room_open(want):
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
	if rid != _room_id and not Game.autotest and enter != "" and not _seen(enter) and _room_open(rid):
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
## Case 3 draws the island and the house floor by floor, with every open place on it (see _case3_map).
func _build_map() -> Control:
	var root: Control = super()
	if Chapters.current == 3:
		_case3_map(root.get_meta("board"))
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


const MAP3_SCALE := 0.6


## Case 3: rooms keep their cards (smaller, at their place on the plan); walkable spaces get a plain plaque; nothing
## that hasn't opened yet is drawn at all, so the map never shows a place before the story does.
func _case3_map(board: Control) -> void:
	var all: Dictionary = Chapters.rooms3d().get_script_constant_map()["SPACES"]
	var decor := Map3Decor.new()
	decor.size = board.size
	for id in all.keys():
		var e: Dictionary = all[id]
		if not _room_open(str(id)):
			continue
		decor.places[id] = {"at": e["map_at"], "name": str(e["name"]), "area": str(e.get("area", "")),
			"card": (Inv.ROOM_ORDER as Array).has(id), "here": str(id) == _room_id}
	var at := 0
	for c in board.get_children():
		if "plain" in c:
			at = c.get_index() + 1
	board.add_child(decor)
	board.move_child(decor, at)
	for c in board.get_children():
		if not ("rid" in c and "thumb" in c):
			continue
		var rid := str(c.get("rid"))
		var card: Control = c
		if not _room_open(rid):
			card.visible = false
			continue
		if all.has(rid):
			card.position = ((all[rid] as Dictionary)["map_at"] as Vector2) - CARD_SIZE * 0.5
		card.scale = Vector2.ONE * MAP3_SCALE


## The island and Warden's Rest drawn under the map cards: sea, the island, the house in its floors, the Gaol across
## the bay, and a plaque for every open place that isn't a room card. Bedrooms are small doors along their wing.
class Map3Decor extends Control:
	var places := {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _region(r: Rect2, fill: Color, border: Color, label: String, top: bool = false) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = border
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var f := Style.display_font()
		var p := Vector2(r.position.x + 12, r.position.y + 20 if top else r.end.y - 10)
		draw_string_outline(f, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 6, Style.BG_DARK)
		draw_string(f, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(border, 1.0))

	func _draw() -> void:
		var f := Style.display_font()
		var ink := Color(0.06, 0.04, 0.1)
		# the sea, the island and, across the bay, the Gaol's headland joined by the causeway
		draw_rect(Rect2(14, 92, size.x - 28, size.y - 106), Color(0.1, 0.22, 0.32, 0.55))
		for i in 9:
			var y := 120.0 + i * 55.0
			draw_dashed_line(Vector2(900, y), Vector2(size.x - 30, y + 8.0), Color(0.5, 0.75, 0.85, 0.18), 2.0, 14.0)
		var land := PackedVector2Array([Vector2(40, 330), Vector2(70, 250), Vector2(190, 98), Vector2(900, 98), Vector2(905, 300),
			Vector2(880, 520), Vector2(760, 600), Vector2(330, 606), Vector2(210, 590), Vector2(60, 560), Vector2(30, 450)])
		draw_colored_polygon(land, Color(0.26, 0.34, 0.26, 0.85))
		var edge := land.duplicate()
		edge.append(land[0])
		draw_polyline(edge, Color(0.62, 0.72, 0.5, 0.7), 3.0, true)
		var gaol := PackedVector2Array([Vector2(930, 410), Vector2(1000, 380), Vector2(1100, 400), Vector2(1115, 520), Vector2(1080, 600),
			Vector2(950, 600), Vector2(925, 520)])
		draw_colored_polygon(gaol, Color(0.3, 0.3, 0.32, 0.9))
		var g_edge := gaol.duplicate()
		g_edge.append(gaol[0])
		draw_polyline(g_edge, Color(0.7, 0.7, 0.74, 0.7), 3.0, true)
		draw_line(Vector2(760, 585), Vector2(935, 560), ink, 12.0, true)
		draw_line(Vector2(760, 585), Vector2(935, 560), Color(0.6, 0.58, 0.52), 7.0, true)
		draw_string_outline(f, Vector2(940, 425), "THE GAOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Style.BG_DARK)
		draw_string(f, Vector2(940, 425), "THE GAOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.82, 0.82, 0.86))
		# the house, floor by floor
		_region(Rect2(215, 96, 525, 145), Color(0.42, 0.3, 0.62, 0.32), Color(Style.VIOLET, 0.7), "UPPER FLOOR", true)
		_region(Rect2(745, 96, 125, 145), Color(0.36, 0.3, 0.4, 0.32), Color(0.75, 0.7, 0.82, 0.7), "ROOF", true)
		_region(Rect2(215, 248, 525, 245), Color(0.55, 0.36, 0.22, 0.3), Color(Style.YUZU, 0.6), "GROUND FLOOR")
		_region(Rect2(745, 248, 125, 245), Color(0.2, 0.2, 0.26, 0.42), Color(0.6, 0.62, 0.7, 0.7), "BELOW", true)
		draw_string_outline(f, Vector2(44, 600), "THE ISLAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Style.BG_DARK)
		draw_string(f, Vector2(44, 600), "THE ISLAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.75, 0.86, 0.62))
		# bedrooms: a little door each along the wing; the rest of the open places get a plaque unless they're a room card
		for id in places.keys():
			var p: Dictionary = places[id]
			var c: Vector2 = p["at"]
			if str(p["area"]) == "bedroom":
				var r := Rect2(c - Vector2(8, 9), Vector2(16, 18))
				draw_rect(r.grow(2.0), ink)
				draw_rect(r, Style.GOLD if bool(p["here"]) else Color(0.62, 0.44, 0.28))
				draw_circle(c + Vector2(4, 1), 1.6, ink)
				continue
			if bool(p["card"]):
				continue
			var name_s := str(p["name"]).to_upper()
			var fs := 13 if name_s.length() <= 14 else 11
			var w := f.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pw := maxf(104.0, w + 16.0)
			var tr := Rect2(c - Vector2(pw * 0.5, 20), Vector2(pw, 40))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.1, 0.07, 0.2, 0.92) if not bool(p["here"]) else Color(0.32, 0.24, 0.08, 0.95)
			sb.border_color = Style.GOLD if bool(p["here"]) else Color(Style.AQUA, 0.7)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(9)
			sb.anti_aliasing = true
			draw_style_box(sb, tr)
			draw_string(f, Vector2(c.x - w * 0.5, c.y + fs * 0.36), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.TEXT)


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
