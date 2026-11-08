extends Control
## FREE TIME - 3D walk-around version.  params: {"slots": 3}.  Emits finished({}).
## Same flow and rules as freetime_screen.gd: "freetime_intro" -> spend the visits (3 slots) on the guests ->
## each visit plays "hangout_<id>" full screen (the script sets its own bg and grants the skill), appends to
## Game.hangouts_done and uses a slot -> "freetime_outro" -> finished({}).
## What changes: instead of a portrait chooser you walk around a 3D hub (chapter 1: the resort courtyard,
## chapter 2: the Mudlark's promenade deck; built in rooms1.gd / rooms2.gd "hub"), find a capybara,
## look at them and press E / click to hang out. Autotest picks the same guests as the 2D screen.
## Debug: --skip-intro skips "freetime_intro"; --cam=x,y,z,tx,ty,tz places the camera.

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
const Rooms1 := preload("res://scripts/world3d/rooms1.gd")
const Rooms2 := preload("res://scripts/world3d/rooms2.gd")

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
var _guests: Array = []     # target dicts: {id, standee, body, marker, top, spark}
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
	var k := Kit.new(_holder)
	if Chapters.current == 2:
		Rooms2.build("hub", k, {})
	else:
		Rooms1.build("hub", k, {})
	_player = Player3D.new()
	_holder.add_child(_player)
	var cam := MouseGuard.cam_arg()
	if cam.is_empty():
		_player.place(k.spawn, k.look)
	else:
		_player.place(Vector3(cam[0].x, 0.0, cam[0].z), cam[1])
	_build_guests(k)
	_hud = Hud3D.new()
	add_child(_hud)
	_hud.set_hints([["WASD", "Move"], ["Mouse", "Look"], ["E / Click", "Hang out"], ["Shift", "Hurry"], ["Esc", "Pause"]])
	_build_header()
	_build_panel()
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


func _build_guests(k) -> void:
	var ids: Array = []
	for id in Cast.roster_alive():
		if id != "mochi":
			ids.append(id)
	var free: Array = k.spots.duplicate()
	var i := 0
	for id in ids:
		var pos: Vector3
		if k.people.has(id):
			pos = k.people[id]
		elif not free.is_empty():
			pos = free.pop_front()
		else:
			pos = Vector3(-4.0 + (i % 6) * 1.6, 0, -2.0 + (i / 6) * 1.6)
		i += 1
		var sd: Dictionary = k.standee(id, "normal", pos)
		var t := {"id": id, "standee": sd, "body": sd["body"], "top": sd["top"], "spark": randf_range(0.0, 6.0)}
		(sd["body"] as Node3D).set_meta("target", t)
		t["marker"] = Hud3D.make_marker(_holder, sd["top"])
		_guests.append(t)
		if Game.hangouts_done.has(id):
			_set_done(t)


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
	_toast("Find someone to spend the afternoon with!", Style.AQUA)
	_enable()


func _enable() -> void:
	_active = true
	_lock_ms = Time.get_ticks_msec() + 250
	if Game.autotest:
		_auto_pick()


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
	var holder: Node3D = (t["standee"] as Dictionary)["holder"]
	if not Game.autotest:
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
	for g in _guests:
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
	if not _focus.is_empty():
		var om: ShaderMaterial = (_focus["standee"] as Dictionary)["mat"]
		om.set_shader_parameter("outline", 0.0)
		om.set_shader_parameter("brightness", 1.0)
	_focus = t
	_hud.set_focus(not t.is_empty())
	if t.is_empty():
		_panel.visible = false
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


func _set_done(t: Dictionary) -> void:
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
		_pick(_focus)


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
	var sub := Style.label("Day 1  -  Afternoon. Who will you spend time with?", 18, Style.TEXT, true)
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
