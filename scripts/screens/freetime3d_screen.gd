extends Control
## FREE TIME - 3D walk-around version.  params: {"slots": 3}.  Emits finished({}).
## Same flow and rules as freetime_screen.gd: "freetime_intro" -> spend the visits (3 slots) on the guests ->
## each visit plays "hangout_<id>" full screen (the script sets its own bg and grants the skill), appends to
## Game.hangouts_done and uses a slot -> "freetime_outro" -> finished({}).
## What changes: instead of a portrait chooser you walk around in 3D (chapter 1: courtyard, lobby + guest wing,
## shop arcade; chapter 2: promenade deck, main stairs + lower passage, saloon; rooms1.gd / rooms2.gd FREE_SPACES),
## find a capybara, look at them and press E / click to hang out. Autotest picks the same guests as the 2D screen.
## Debug: --skip-intro skips "freetime_intro"; --space3d=<id> starts in that space; --cam=x,y,z,tx,ty,tz places the camera.
## Case 3: from Day 3 a space's "ledger_page" anchor is a loose page to read (story id page_<space>, if it exists).

signal finished(result: Dictionary)

const ScriptPlayer := preload("res://scripts/core/script_player.gd")
const Style := preload("res://scripts/ui/style.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Chapters := preload("res://scripts/data/chapters.gd")
const Skills := preload("res://scripts/data/skills.gd")
const Story := preload("res://scripts/data/story.gd")
const FT := preload("res://scripts/screens/freetime_screen.gd")
const Kit := preload("res://scripts/world3d/kit.gd")
const Player3D := preload("res://scripts/world3d/player3d.gd")
const Hud3D := preload("res://scripts/world3d/hud3d.gd")
const MouseGuard := preload("res://scripts/world3d/mouse_guard.gd")
const LiftRide := preload("res://scripts/world3d/lift_ride.gd")

const W := 1280.0
const H := 720.0
const AUTO_PICKS := ["coco", "pepper", "nibs"]

var _slots := 3
var _slots_left := 0
var _sp: Control = null
var _holder: Node3D
var _player: Player3D
var _hud: Hud3D
var _fade: ColorRect
var _header: Control
var _yuzus: Array = []
var _slots_label: Label
var _panel: Panel
var _info_name: Label
var _info_talent: Label
var _info_status: Label
var _info_tag: Label
var _info_skill: Label
var _info_desc: Label
var _toast_layer: Control
var _guests: Array = []     # target dicts: {kind, id, spark} + {standee, body, marker, top} while their space is built
var _here: Array = []       # guests standing in the current space
var _useable: Array = []    # doors, lifts and notes in the current space
var _room3d: Node3D
var _kit: Kit
var _space := ""
var _free: Array = []       # spaces you may walk through during Free Time
var _names := {}
var _arrive_from := ""
var _touring := false
var _toured := false
var _tag: PanelContainer
var _tag_label: Label
var _focus: Dictionary = {}
var _active := false
var _lock_ms := 0
var _t := 0.0


func setup(params: Dictionary) -> void:
	_slots = maxi(int(params.get("slots", 3)), 0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder = Node3D.new()
	add_child(_holder)
	_player = Player3D.new()
	_holder.add_child(_player)
	_make_names()
	for id in Cast.roster_alive():
		if id != "mochi":
			_guests.append({"kind": "guest", "id": id, "spark": randf_range(0.0, 6.0)})
	_hud = Hud3D.new()
	add_child(_hud)
	_hud.set_hints([["WASD", "Move"], ["Mouse", "Look"], ["E / Click", "Use"], ["Shift", "Hurry"], ["Esc", "Pause"]])
	_build_header()
	_build_panel()
	_build_tag()
	var start := MouseGuard.arg("space3d")
	_enter_space(start if start != "" else _free_start())
	_toast_layer = Control.new()
	_toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_layer)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.02, 0.01, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 10
	add_child(_fade)
	var guard := MouseGuard.new()
	guard.want = _wants_mouse
	add_child(guard)
	Audio.play_music("daily")
	_run.call_deferred()


func _wants_mouse() -> bool:
	return _active and _sp == null and not Game.autotest and Game.shot_path == "" and is_visible_in_tree() \
		and get_window().has_focus()


func _free_start() -> String:
	return str(Chapters.rooms3d().get_script_constant_map()["FREE_START"])


func _make_names() -> void:
	var world: Dictionary = Chapters.rooms3d().get_script_constant_map()
	var entries: Dictionary = (world["SPACES"] as Dictionary).duplicate()
	var path := str(Chapters.get_value("investigation", ""))
	if path != "" and ResourceLoader.exists(path):
		var script: Script = load(path)
		entries.merge(script.get_script_constant_map().get("ROOMS", {}), true)
	for id in entries.keys():
		_names[id] = str((entries[id] as Dictionary).get("name", id))
	# a space whose day hasn't come stays shut, like any other door outside Free Time's reach
	var day := Chapters.day_at(Game.main.current_step())
	_free = []
	for id in world["FREE_SPACES"]:
		if Chapters.room_open(entries.get(id, {}), day):
			_free.append(id)


## Builds one walkable space with the guests who are there, and puts the player at the door they came through.
func _enter_space(id: String) -> void:
	if _room3d:
		_holder.remove_child(_room3d)
		_room3d.queue_free()
	_room3d = Node3D.new()
	_holder.add_child(_room3d)
	var k := Kit.new(_room3d)
	k.mode = "freetime"
	Chapters.rooms3d().call("build", id, k, _names)
	_kit = k
	_space = id
	Game.log_place(str(_names.get(id, id)))
	_focus = {}
	_tag.visible = false
	_panel.visible = false
	_here.clear()
	_useable.clear()
	for g in _guests:
		for key in ["standee", "body", "marker", "top"]:
			g.erase(key)
		var gid := str(g["id"])
		if not k.people.has(gid):
			continue
		var sd: Dictionary = k.standee(gid, "normal", k.people[gid])
		g["standee"] = sd
		g["body"] = sd["body"]
		g["top"] = sd["top"]
		g["marker"] = Hud3D.make_marker(_room3d, sd["top"])
		(sd["body"] as Node3D).set_meta("target", g)
		_here.append(g)
		if Game.hangouts_done.has(gid):
			_set_done(g)
	for to in k.doors.keys():
		var d: Dictionary = k.doors[to]
		# examinable doors, and hidden (jib) doors to places Free Time doesn't go, aren't doors here
		if d.has("link") or (bool(d.get("hidden", false)) and not _free.has(str(to))):
			continue
		var t := {"kind": "door", "to": str(to), "label": str(_names.get(to, to)), "hinge": d.get("hinge")}
		(d["body"] as Node3D).set_meta("target", t)
		_useable.append(t)
	for lid in k.lifts.keys():
		var ld: Dictionary = k.lifts[lid]
		var t := {"kind": "lift", "lift_id": str(lid), "label": str(ld["label"])}
		(ld["body"] as Node3D).set_meta("target", t)
		_useable.append(t)
	for nt in k.notes:
		var t := {"kind": "note", "label": str(nt["label"]), "text": str(nt["text"])}
		(nt["body"] as Node3D).set_meta("target", t)
		_useable.append(t)
	# Case 3 from Day 3: a loose Ledger page tucked away in this space can be read (story id page_<space>)
	if k.hot.has("ledger_page") and Story.has("page_" + id):
		var hp: Dictionary = k.hot["ledger_page"]
		var t := {"kind": "page", "label": "Loose page", "script": "page_" + id}
		(hp["body"] as Node3D).set_meta("target", t)
		_useable.append(t)
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


# =================================================================== flow
func _run() -> void:
	_header.modulate.a = 0.0
	if Story.has("freetime_intro") and MouseGuard.arg("skip-intro") == "" and not OS.get_cmdline_user_args().has("--skip-intro"):
		var running := _start_story("freetime_intro")
		if running and _sp.is_running():
			await _sp.finished
		if not is_inside_tree():
			return
		await _fade_to(1.0, 0.25)
		_free_player()
		await _fade_to(0.0, 0.35)
	_slots_left = mini(_slots, _available_count())
	_refresh_slots(false)
	if _slots_left <= 0:
		await _finish()
		return
	var tw := create_tween()
	tw.tween_property(_header, "modulate:a", 1.0, _dur(0.35))
	_toast("Everyone's scattered around. Go and find someone!", Style.AQUA)
	_enable()


func _enable() -> void:
	_active = true
	_lock_ms = Time.get_ticks_msec() + 250
	if _touring:
		return
	if Game.autotest:
		if OS.get_cmdline_user_args().has("--tour3d") and not _toured:
			_toured = true
			await _tour()
		_auto_pick()


## Debug (--autotest --tour3d): really uses every door, lift and note of every Free Time space first.
func _tour() -> void:
	_touring = true
	var used := 0
	var bad := 0
	for id in _free:
		_enter_space(str(id))
		var count := _useable.size()
		for i in count:
			var t: Dictionary = _useable[i]
			var kind := str(t["kind"])
			var want := str(id)
			if kind == "door" and _free.has(str(t["to"])):
				want = str(t["to"])
			elif kind == "lift":
				var lift_to := str((_kit.lifts[str(t["lift_id"])] as Dictionary)["to_space"])
				want = lift_to if lift_to != "" and _free.has(lift_to) else str(id)
			await _use(t)
			await get_tree().process_frame
			used += 1
			if _space != want:
				bad += 1
				print("[tour] FAIL %s %s: ended in %s, wanted %s" % [id, kind, _space, want])
			_enter_space(str(id))
	print("[tour] free time: used %d doors/lifts/notes, %d failures" % [used, bad])
	_touring = false
	_active = true
	_enter_space(_free_start())


func _available_count() -> int:
	var n := 0
	for t in _guests:
		if not Game.hangouts_done.has(str(t["id"])):
			n += 1
	return n


func _auto_pick() -> void:
	await get_tree().create_timer(0.1, false).timeout
	if not _active or not is_inside_tree():
		return
	var target: Dictionary = {}
	for id in Chapters.get_value("auto_picks", AUTO_PICKS):
		for t in _guests:
			if str(t["id"]) == str(id) and not Game.hangouts_done.has(str(id)):
				target = t
				break
		if not target.is_empty():
			break
	if target.is_empty():
		for t in _guests:
			if not Game.hangouts_done.has(str(t["id"])):
				target = t
				break
	if not target.is_empty():
		_pick(target)


func _pick(t: Dictionary) -> void:
	if not _active:
		return
	var id := str(t["id"])
	if Game.hangouts_done.has(id):
		Audio.sfx("cancel")
		_toast("You already spent time with %s today." % Cast.display_name(id), Style.TEXT_DIM)
		return
	if _slots_left <= 0:
		return
	_active = false
	_set_focus({})
	Audio.sfx("confirm")
	if not Game.autotest and t.has("standee"):
		var holder: Node3D = (t["standee"] as Dictionary)["holder"]
		_player.turn_to(holder.global_position + Vector3(0, 1.25, 0), 0.3)
		_pop(holder)
	await _wait(0.35)
	await _fade_to(1.0, 0.3)
	_header.visible = false
	_hud.visible = false
	var running := _start_story("hangout_" + id)
	await _fade_to(0.0, 0.3)
	if running and _sp and _sp.is_running():
		await _sp.finished
	if not is_inside_tree():
		return
	if not Game.hangouts_done.has(id):
		Game.hangouts_done.append(id)
	_slots_left -= 1
	await _fade_to(1.0, 0.3)
	_free_player()
	Audio.play_music("daily")
	_header.visible = true
	_hud.visible = true
	_set_done(t)
	await _fade_to(0.0, 0.3)
	await _wait(0.15)
	await _consume_slot()
	if _slots_left <= 0 or _available_count() == 0:
		_toast("The afternoon is over.", Style.GOLD)
		await _wait(1.2)
		await _finish()
	else:
		_enable()


func _consume_slot() -> void:
	var idx := _slots_left
	if idx >= 0 and idx < _yuzus.size():
		var y: Control = _yuzus[idx]
		var tw := create_tween()
		tw.tween_property(y, "scale", Vector2.ONE * 1.45, _dur(0.12)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			y.spent = true
			y.queue_redraw()
			Audio.sfx("pop", 1.1, -4.0))
		tw.tween_property(y, "scale", Vector2.ONE * 0.6, 0.01)
		tw.tween_property(y, "scale", Vector2.ONE, _dur(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
	_refresh_slots(true)
	Audio.sfx("correct", 1.0, -6.0)
	await _wait(0.3)


func _finish() -> void:
	_active = false
	_set_focus({})
	if Story.has("freetime_outro"):
		await _fade_to(1.0, 0.35)
		_header.visible = false
		_hud.visible = false
		var running := _start_story("freetime_outro")
		await _fade_to(0.0, 0.3)
		if running and _sp and _sp.is_running():
			await _sp.finished
		if not is_inside_tree():
			return
	finished.emit({})


# =================================================================== story playback (same as the 2D screen)
func _start_story(id: String) -> bool:
	_free_player()
	_sp = ScriptPlayer.new()
	add_child(_sp)
	move_child(_sp, _fade.get_index())
	var txt := Story.get_text(id)
	var first_bg := _first_bg(txt)
	if first_bg != "" and first_bg != "none":
		_sp.set_background(first_bg, true)
	_sp.play_text(txt)
	return _sp.is_running()


func _free_player() -> void:
	if _sp:
		_sp.queue_free()
		_sp = null


func _first_bg(txt: String) -> String:
	for line in txt.split("\n"):
		var l := line.strip_edges()
		# a script that branches before its first @bg (Case 3's hangouts pick theirs by day) sets its own, from black
		if l.begins_with("@if ") or l.begins_with("@ifnot ") or l.begins_with("@jump "):
			return ""
		if l.begins_with("@bg "):
			var parts := l.substr(4).strip_edges().split(" ", false)
			return parts[0] if parts.size() > 0 else ""
		if l != "" and not l.begins_with("@") and not l.begins_with("#"):
			return ""
	return ""


# =================================================================== per frame
func _process(delta: float) -> void:
	_t += delta
	var walk := _active and _sp == null and not get_tree().paused
	_player.enabled = walk
	if walk:
		var t: Dictionary = {}
		var b: Node3D = _player.focus_body()
		if b != null:
			t = b.get_meta("target")
		if not is_same(t, _focus):
			_set_focus(t)
	elif not _focus.is_empty():
		_set_focus({})
	for g in _here:
		var m: Sprite3D = g["marker"]
		var done := Game.hangouts_done.has(str(g["id"]))
		m.visible = walk and not is_same(g, _focus)
		var tex := Hud3D.check_tex() if done else Hud3D.star_tex()
		if m.texture != tex:
			m.texture = tex
		var ph := float(g["spark"])
		m.position = (g["top"] as Vector3) + Vector3(0, sin(_t * 2.0 + ph) * 0.04, 0)
		if done:
			m.modulate.a = 0.9
			m.pixel_size = 0.0003
		else:
			var tw := 0.5 + 0.5 * sin(_t * 2.6 + ph)
			m.modulate.a = 0.5 + 0.5 * tw
			m.pixel_size = 0.00036 + 0.0001 * tw
		var sd: Dictionary = g["standee"]
		var mi: MeshInstance3D = sd["mesh"]
		mi.scale = Vector3(1.0, 1.0 + 0.012 * sin(_t * 2.1 + ph), 1.0)


func _set_focus(t: Dictionary) -> void:
	if is_same(t, _focus):
		return
	if str(_focus.get("kind", "")) == "guest" and _focus.has("standee"):
		var om: ShaderMaterial = (_focus["standee"] as Dictionary)["mat"]
		om.set_shader_parameter("outline", 0.0)
		om.set_shader_parameter("brightness", 1.0)
	_focus = t
	_hud.set_focus(not t.is_empty())
	_tag.visible = false
	_panel.visible = false
	if t.is_empty():
		return
	if str(t["kind"]) != "guest":
		_show_tag(t)
		Audio.sfx("select", 1.0 + randf_range(-0.05, 0.05), -6.0)
		return
	var m: ShaderMaterial = (t["standee"] as Dictionary)["mat"]
	m.set_shader_parameter("outline", 1.0)
	m.set_shader_parameter("brightness", 1.1)
	Audio.sfx("select", 1.0 + randf_range(-0.05, 0.05), -6.0)
	_show_info(str(t["id"]))


func _show_info(id: String) -> void:
	var col := Cast.color(id)
	_info_name.text = Cast.full_name(id)
	var nl := Cast.full_name(id).length()
	_info_name.add_theme_font_size_override("font_size", 30 if nl <= 17 else (25 if nl <= 22 else 21))
	_info_name.add_theme_color_override("font_color", col.lightened(0.25))
	_info_talent.text = Cast.talent(id)
	var sid: String = Skills.BY_CHAR.get(id, "")
	_info_skill.text = Skills.skill_name(sid) if sid != "" else "?"
	_info_desc.text = Skills.desc(sid) if sid != "" else ""
	if Game.hangouts_done.has(id):
		_info_status.text = "You already spent time together today."
		_info_status.add_theme_color_override("font_color", Style.GOOD)
		_info_tag.text = "TAUGHT YOU"
	else:
		_info_status.text = "[E] / Click  -  spend time together"
		_info_status.add_theme_color_override("font_color", Style.AQUA)
		_info_tag.text = "SKILL (ALREADY KNOWN)" if sid != "" and Game.has_skill(sid) else "WILL TEACH YOU"
	_panel.visible = true
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.12)


func _show_tag(t: Dictionary) -> void:
	var kind := str(t["kind"])
	var txt := "Look at:  " + str(t["label"])
	var col := Style.AQUA
	if kind == "door":
		txt = ("Go to:  " if _free.has(str(t["to"])) else "Closed for now:  ") + str(t["label"])
		col = Style.YUZU if _free.has(str(t["to"])) else Style.TEXT_DIM
	elif kind == "lift":
		txt = "Ride to:  " + str(t["label"])
		col = Style.YUZU
	_tag_label.text = txt
	var st: StyleBoxFlat = _tag.get_theme_stylebox("panel")
	st.border_color = col
	_tag.reset_size()
	var sz := _tag.get_combined_minimum_size()
	_tag.size = sz
	_tag.position = Vector2((W - sz.x) * 0.5, H * 0.5 + 38.0)
	_tag.visible = true


func _build_tag() -> void:
	_tag = PanelContainer.new()
	var st := Style.box(Color(0.06, 0.035, 0.13, 0.95), 10, Style.AQUA, 2)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	_tag.add_theme_stylebox_override("panel", st)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.visible = false
	_tag_label = Style.label("", 20, Style.TEXT)
	_tag.add_child(_tag_label)
	add_child(_tag)


## Doors, lifts and small things to look at.
func _use(t: Dictionary) -> void:
	match str(t["kind"]):
		"door":
			await _go_door(t)
		"lift":
			await _ride(t)
		"note":
			await _read_note(t)
		"page":
			await _read_page(t)


func _go_door(t: Dictionary) -> void:
	var to := str(t["to"])
	if not _free.has(to):
		Audio.sfx("cancel")
		_toast("Not now. It's Free Time: go and find someone!", Style.TEXT_DIM)
		return
	_active = false
	_set_focus({})
	Audio.sfx("confirm")
	var hinge: Variant = t.get("hinge")
	if hinge != null and is_instance_valid(hinge):
		var tw := create_tween()
		tw.tween_property(hinge, "rotation:y", -1.45, _dur(0.22)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tw.finished
	Audio.sfx("door")
	await _fade_to(1.0, 0.2)
	_arrive_from = _space
	_enter_space(to)
	await _fade_to(0.0, 0.25)
	_toast(str(_names.get(to, to)), Style.GOLD)
	_enable()


func _ride(t: Dictionary) -> void:
	var lift_to := str((_kit.lifts[str(t["lift_id"])] as Dictionary)["to_space"])
	if lift_to != "" and lift_to != _space and not _free.has(lift_to):
		Audio.sfx("cancel")
		_toast("Not now. It's Free Time: go and find someone!", Style.TEXT_DIM)
		return
	_active = false
	_set_focus({})
	Audio.sfx("confirm")
	var from: Dictionary = _kit.lifts[str(t["lift_id"])]
	await LiftRide.move_doors(self, from, false)
	await LiftRide.rumble(self, _player.cam, from)
	if not is_inside_tree():
		return
	var from_rot := float(from["rot"])
	var offset: Vector3 = Basis(Vector3.UP, from_rot).inverse() * (_player.global_position - (from["pos"] as Vector3))
	var to_space := str(from["to_space"])
	var changed := to_space != "" and to_space != _space
	if changed:
		_enter_space(to_space)
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
		(from["inside"] as Label3D).text = str(from["floor"])
	_enable()


func _read_note(t: Dictionary) -> void:
	Game.log_thing(str(t["label"]))
	_active = false
	_set_focus({})
	Audio.sfx("select")
	_free_player()
	_sp = ScriptPlayer.new()
	_sp.transparent = true
	_sp.auto_portrait = true
	add_child(_sp)
	move_child(_sp, _fade.get_index())
	_sp.play_text("think: %s\n@end" % str(t["text"]))
	if _sp.is_running():
		await _sp.finished
	if not is_inside_tree():
		return
	_free_player()
	_enable()


## A loose page: its story script plays over the room (it sets its own flag and Logbook entry), then back to walking.
func _read_page(t: Dictionary) -> void:
	Game.log_thing(str(t["label"]))
	_active = false
	_set_focus({})
	Audio.sfx("select")
	_free_player()
	_sp = ScriptPlayer.new()
	_sp.transparent = true
	_sp.auto_portrait = true
	add_child(_sp)
	move_child(_sp, _fade.get_index())
	_sp.play_text(Story.get_text(str(t["script"])))
	if _sp.is_running():
		await _sp.finished
	if not is_inside_tree():
		return
	_free_player()
	_enable()


func _set_done(t: Dictionary) -> void:
	if not t.has("standee"):
		return
	var m: ShaderMaterial = (t["standee"] as Dictionary)["mat"]
	m.set_shader_parameter("gray", 0.55)


func _pop(n: Node3D) -> void:
	var s0 := n.scale
	var tw := create_tween()
	tw.tween_property(n, "scale", s0 * Vector3(1.06, 0.94, 1.06), 0.07)
	tw.tween_property(n, "scale", s0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(e: InputEvent) -> void:
	if MouseGuard.is_interact(e) and _active and _sp == null and not _focus.is_empty() and Time.get_ticks_msec() >= _lock_ms:
		get_viewport().set_input_as_handled()
		if str(_focus["kind"]) == "guest":
			_pick(_focus)
		else:
			_use(_focus)


# =================================================================== HUD
func _build_header() -> void:
	_header = Control.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.size = Vector2(W, 150)
	add_child(_header)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.03, 0.02, 0.08, 0.7), Color(0.03, 0.02, 0.08, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var sh := TextureRect.new()
	sh.texture = gt
	sh.size = Vector2(W, 130)
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(sh)
	var title := Style.title_label("FREE TIME", 48, Style.GOLD, Style.BG_DARK, 12)
	title.position = Vector2(34, 10)
	_header.add_child(title)
	var bar := ColorRect.new()
	bar.color = Style.AQUA
	bar.position = Vector2(38, 72)
	bar.size = Vector2(250, 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(bar)
	var sub := Style.label("Day %d  -  Afternoon. Who will you spend time with?" % maxi(Chapters.day_at(Game.main.current_step()), 1), 18, Style.TEXT, true)
	sub.position = Vector2(38, 80)
	sub.add_theme_color_override("font_outline_color", Style.BG_DARK)
	sub.add_theme_constant_override("outline_size", 6)
	_header.add_child(sub)
	var sl := Style.title_label("VISITS LEFT", 17, Style.AQUA, Style.BG_DARK, 6)
	sl.position = Vector2(1000, 12)
	sl.size = Vector2(240, 24)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_child(sl)
	var n := clampi(_slots, 0, 6)
	var step := 60.0
	var x0 := 1120.0 - (n - 1) * step * 0.5
	for i in n:
		var y: Control = FT.YuzuIcon.new()
		y.position = Vector2(x0 + i * step - 26.0, 36)
		y.phase = i * 1.3
		_header.add_child(y)
		_yuzus.append(y)
	_slots_label = Style.label("", 15, Style.TEXT_DIM)
	_slots_label.position = Vector2(1000, 92)
	_slots_label.size = Vector2(240, 20)
	_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slots_label.add_theme_color_override("font_outline_color", Style.BG_DARK)
	_slots_label.add_theme_constant_override("outline_size", 5)
	_header.add_child(_slots_label)


func _refresh_slots(animated: bool) -> void:
	for i in _yuzus.size():
		var y: Control = _yuzus[i]
		var spent: bool = i >= _slots_left
		if y.spent != spent:
			y.spent = spent
			y.queue_redraw()
	if _slots_left <= 0:
		_slots_label.text = "The afternoon is over"
	elif _slots_left == 1:
		_slots_label.text = "Last visit of the day!"
	else:
		_slots_label.text = "%d visits left today" % _slots_left
	if animated:
		_slots_label.pivot_offset = _slots_label.size * 0.5
		_slots_label.scale = Vector2.ONE * 1.2
		var tw := create_tween()
		tw.tween_property(_slots_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_panel() -> void:
	_panel = Panel.new()
	_panel.position = Vector2(170, 536)
	_panel.size = Vector2(940, 132)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var st := Style.box(Color(0.07, 0.04, 0.15, 0.92), 18, Style.AQUA, 3)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", st)
	add_child(_panel)
	_info_name = Style.title_label("", 30, Color.WHITE, Style.BG_DARK, 8)
	_info_name.position = Vector2(26, 10)
	_info_name.size = Vector2(410, 42)
	_info_name.clip_text = true
	_panel.add_child(_info_name)
	_info_talent = Style.label("", 19, Style.TEXT_DIM, true)
	_info_talent.position = Vector2(28, 54)
	_panel.add_child(_info_talent)
	_info_status = Style.label("", 17, Style.AQUA)
	_info_status.position = Vector2(28, 92)
	_panel.add_child(_info_status)
	var div := ColorRect.new()
	div.color = Color(Style.AQUA_DEEP, 0.8)
	div.position = Vector2(446, 16)
	div.size = Vector2(3, 100)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(div)
	_info_tag = Style.title_label("WILL TEACH YOU", 15, Style.AQUA, Style.BG_DARK, 5)
	_info_tag.position = Vector2(470, 12)
	_panel.add_child(_info_tag)
	_info_skill = Style.title_label("", 25, Style.GOLD, Style.BG_DARK, 8)
	_info_skill.position = Vector2(470, 32)
	_panel.add_child(_info_skill)
	_info_desc = Label.new()
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.position = Vector2(472, 70)
	_info_desc.size = Vector2(450, 56)
	_info_desc.add_theme_font_size_override("font_size", 17)
	_info_desc.add_theme_color_override("font_color", Style.TEXT)
	_panel.add_child(_info_desc)


func _toast(text: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := Style.box(Color(0.05, 0.03, 0.11, 0.92), 22, col, 3)
	st.content_margin_left = 22
	st.content_margin_right = 22
	p.add_theme_stylebox_override("panel", st)
	var l := Style.title_label(text, 20, col, Style.BG_DARK, 5)
	p.add_child(l)
	_toast_layer.add_child(p)
	var sz := p.get_combined_minimum_size()
	p.size = sz
	p.position = Vector2((W - sz.x) * 0.5, 130)
	p.pivot_offset = sz * 0.5
	p.scale = Vector2.ONE * 0.6
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, _dur(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "modulate:a", 1.0, _dur(0.15))
	tw.tween_interval(_dur(2.2))
	tw.tween_property(p, "modulate:a", 0.0, _dur(0.4))
	tw.tween_callback(p.queue_free)


# =================================================================== helpers
func _dur(sec: float) -> float:
	return 0.01 if Game.autotest else sec


func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, _dur(dur))
	await tw.finished


func _wait(sec: float) -> void:
	await get_tree().create_timer(_dur(sec), false).timeout
