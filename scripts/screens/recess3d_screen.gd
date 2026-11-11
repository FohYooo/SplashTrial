extends "res://scripts/screens/freetime3d_screen.gd"
## THE RECESS (Case 3's trial, between its two halves): a short walk in the Grand Hall while Snapjaw prints the 7 AM roll
## in the cupboard under the stairs. Main plays it as the "recess" step when the trial script sets flag "trial_break"
## (see main.gd), then takes the trial up again at its after_recess checkpoint. params: {"script": id} is the --2d story
## and is not used here.
## Flow: "recess_intro" -> walk among the guests; each has a short "recess_<id>" talk, played over the room, as often as
## you like (flavour only: nothing in them is needed for the case) -> Snapjaw at his darkroom door plays
## "recess_darkroom", which hands over the prints and ends the recess -> finished({}). The hall's doors stay shut.
## It reuses the Free Time walk (freetime3d_screen.gd): the guests are "guest" targets, Snapjaw is one more, and
## Game.hangouts_done marks who you've talked to while it runs (put back as it was at the end).
## Autotest talks to two guests, then collects the prints.
## Debug: -- --chapter=3 --start=recess [--skip-intro] [--cam=x,y,z,tx,ty,tz] [--shot=<png>]

const SPACE := "grand_hall"
## Where everybody stands on the ground floor of the hall, in little clumps; Snapjaw at the cupboard under the stairs.
const SPOTS := {
	"zuzu": Vector3(-4.6, 0, 5.0),
	"reginald": Vector3(-5.3, 0, 1.8),
	"bruno": Vector3(-3.0, 0, -1.3),
	"grub": Vector3(-2.35, 0, -2.2),
	"lulu": Vector3(-0.3, 0, 0.9),
	"pepper": Vector3(1.9, 0, 2.1),
	"duchess": Vector3(3.0, 0, 4.7),
	"fennel": Vector3(4.6, 0, 1.4),
	"bramble": Vector3(5.6, 0, 4.4),
	"snapjaw": Vector3(3.0, 0, -2.9),
}
## Their faces while they wait (the full-body standees have normal, sad and angry).
const MOOD := {"lulu": "sad", "grub": "sad", "zuzu": "sad", "bramble": "sad", "duchess": "sad", "bruno": "sad",
	"reginald": "normal", "pepper": "normal", "fennel": "normal", "snapjaw": "normal"}
## Where the darkroom's red bulb hangs: over the little cupboard door under the stairs (rooms3.gd _grand_hall).
const DARKROOM := Vector3(2.5, 0, -5.38)
const AUTO_TALKS := ["zuzu", "grub"]

var _saved_done: Array[String] = []


func _free_start() -> String:
	return SPACE


## Only the hall: every door out of it is shut for the recess.
func _make_names() -> void:
	super._make_names()
	_free = [SPACE]


## Builds the hall in its Day 6 state with everybody standing about in it (the copy of freetime3d_screen's _enter_space,
## with the recess's own people and no loose pages).
func _enter_space(id: String) -> void:
	if not _has_guest("snapjaw"):
		_guests.append({"kind": "guest", "id": "snapjaw", "spark": 1.3})
	if _room3d:
		_holder.remove_child(_room3d)
		_room3d.queue_free()
	_room3d = Node3D.new()
	_holder.add_child(_room3d)
	var k := Kit.new(_room3d)
	k.mode = "freetime"
	k.set_meta("day", 6)
	Chapters.rooms3d().call("build", id, k, _names)
	_kit = k
	_space = id
	Game.log_place(str(_names.get(id, id)))
	var here: Array = Cast.survivors()
	for gid in SPOTS.keys():
		if gid == "snapjaw" or here.has(gid):
			k.person(str(gid), SPOTS[gid])
	_darkroom(k)
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
		var sd: Dictionary = k.standee(gid, str(MOOD.get(gid, "normal")), k.people[gid])
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
		if d.has("link") or bool(d.get("hidden", false)):
			continue
		var t := {"kind": "door", "to": str(to), "label": str(_names.get(to, to)), "hinge": d.get("hinge")}
		(d["body"] as Node3D).set_meta("target", t)
		_useable.append(t)
	for nt in k.notes:
		# the cupboard under the stairs is Snapjaw's darkroom today: he's standing in front of it
		if str(nt["label"]).begins_with("Cupboard"):
			continue
		var t := {"kind": "note", "label": str(nt["label"]), "text": str(nt["text"])}
		(nt["body"] as Node3D).set_meta("target", t)
		_useable.append(t)
	var cam := MouseGuard.cam_arg()
	if not cam.is_empty():
		_player.place(Vector3(cam[0].x, cam[0].y - 1.5, cam[0].z), cam[1])
	else:
		_player.place(k.spawn, k.look)


## A red safelight bulb over the cupboard door, glowing on the panelling.
func _darkroom(k: Kit) -> void:
	k.box(Vector3(0.05, 0.05, 0.12), DARKROOM + Vector3(0, 1.98, 0.06), k.mat(Color(0.12, 0.1, 0.08), 0.6, 0.4))
	k.sphere(0.06, DARKROOM + Vector3(0, 1.9, 0.14), k.glow(Color(1.0, 0.12, 0.08), 4.0))
	k.omni(DARKROOM + Vector3(0, 1.7, 0.6), Color(1.0, 0.18, 0.12), 1.8, 4.5)


func _has_guest(id: String) -> bool:
	for g in _guests:
		if str(g["id"]) == id:
			return true
	return false


func _guest(id: String) -> Dictionary:
	for g in _here:
		if str(g["id"]) == id:
			return g
	return {}


# =================================================================== flow
func _run() -> void:
	_saved_done = Game.hangouts_done.duplicate()
	Game.hangouts_done.clear()
	_header.modulate.a = 0.0
	Audio.play_music("tension")
	if Story.has("recess_intro") and MouseGuard.arg("skip-intro") == "" and not OS.get_cmdline_user_args().has("--skip-intro"):
		var running := _start_story("recess_intro")
		if running and _sp.is_running():
			await _sp.finished
		if not is_inside_tree():
			return
		await _fade_to(1.0, 0.25)
		_free_player()
		await _fade_to(0.0, 0.35)
	Audio.play_music("tension")
	var tw := create_tween()
	tw.tween_property(_header, "modulate:a", 1.0, _dur(0.35))
	_toast("Recess! Talk to anyone, or fetch the prints from Snapjaw.", Style.AQUA)
	_enable()


func _enable() -> void:
	_active = true
	_lock_ms = Time.get_ticks_msec() + 250
	if Game.autotest:
		_auto_pick()


## Autotest: a word with a couple of guests, then the prints.
func _auto_pick() -> void:
	await get_tree().create_timer(0.1, false).timeout
	if not _active or not is_inside_tree():
		return
	var want := "snapjaw"
	for id in AUTO_TALKS:
		if not Game.hangouts_done.has(str(id)) and not _guest(str(id)).is_empty():
			want = str(id)
			break
	var t := _guest(want)
	if t.is_empty():
		await _finish()
		return
	_pick(t)


## A guest: their talk, over the room, then back to walking. Snapjaw: the prints, and the recess is over.
func _pick(t: Dictionary) -> void:
	if not _active:
		return
	var id := str(t["id"])
	_active = false
	_set_focus({})
	Audio.sfx("confirm")
	if not Game.autotest and t.has("standee"):
		var holder: Node3D = (t["standee"] as Dictionary)["holder"]
		_player.turn_to(holder.global_position + Vector3(0, 1.25, 0), 0.3)
		_pop(holder)
	await _wait(0.3)
	if id == "snapjaw":
		await _talk("recess_darkroom")
		if is_inside_tree():
			await _finish()
		return
	await _talk("recess_" + id)
	if not is_inside_tree():
		return
	if not Game.hangouts_done.has(id):
		Game.hangouts_done.append(id)
	_set_done(t)
	_enable()


## Plays a short script over the room (portraits come and go by themselves, like the investigation's talks).
func _talk(id: String) -> void:
	_free_player()
	_header.visible = false
	_sp = ScriptPlayer.new()
	_sp.transparent = true
	_sp.auto_portrait = true
	add_child(_sp)
	move_child(_sp, _fade.get_index())
	_sp.play_text(Story.get_text(id) if Story.has(id) else "@end")
	if _sp.is_running():
		await _sp.finished
	if not is_inside_tree():
		return
	_free_player()
	_header.visible = true


func _finish() -> void:
	_active = false
	_set_focus({})
	Game.hangouts_done.clear()
	Game.hangouts_done.append_array(_saved_done)
	await _fade_to(1.0, 0.35)
	if is_inside_tree():
		finished.emit({})


func _go_door(_door: Dictionary) -> void:
	Audio.sfx("cancel")
	_toast("Not now. Snapjaw wants everybody in the Hall.", Style.TEXT_DIM)


func _ride(_lift: Dictionary) -> void:
	_go_door(_lift)


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
	var title := Style.title_label("RECESS", 48, Style.GOLD, Style.BG_DARK, 12)
	title.position = Vector2(34, 10)
	_header.add_child(title)
	var bar := ColorRect.new()
	bar.color = Style.DANGER
	bar.position = Vector2(38, 72)
	bar.size = Vector2(250, 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(bar)
	var sub := Style.label("Day 6  -  The Grand Hall. Snapjaw is printing the photos under the stairs.", 18, Style.TEXT, true)
	sub.position = Vector2(38, 80)
	sub.add_theme_color_override("font_outline_color", Style.BG_DARK)
	sub.add_theme_constant_override("outline_size", 6)
	_header.add_child(sub)
	_slots_label = Style.label("", 15, Style.TEXT_DIM)
	_slots_label.visible = false
	_header.add_child(_slots_label)


func _refresh_slots(_animated: bool) -> void:
	pass


func _show_info(id: String) -> void:
	var col := Cast.color(id)
	_info_name.text = Cast.full_name(id)
	var nl := Cast.full_name(id).length()
	_info_name.add_theme_font_size_override("font_size", 30 if nl <= 17 else (25 if nl <= 22 else 21))
	_info_name.add_theme_color_override("font_color", col.lightened(0.25))
	_info_talent.text = Cast.talent(id)
	if id == "snapjaw":
		_info_status.text = "[E] / Click  -  collect the prints"
		_info_status.add_theme_color_override("font_color", Style.YUZU)
		_info_tag.text = "THE DARKROOM"
		_info_skill.text = "Sixteen frames"
		_info_desc.text = "Taking the prints ends the recess, and the trial goes on."
	else:
		var talked := Game.hangouts_done.has(id)
		_info_status.text = "[E] / Click  -  " + ("talk again" if talked else "talk")
		_info_status.add_theme_color_override("font_color", Style.GOOD if talked else Style.AQUA)
		_info_tag.text = "RECESS"
		_info_skill.text = "A word or two"
		_info_desc.text = "Talking doesn't end the recess. Only the prints do."
	_panel.visible = true
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.12)
