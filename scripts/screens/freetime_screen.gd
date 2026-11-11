extends Control
## FREE TIME - Day 1 afternoon.  params: {"slots": 3}.  Emits finished({}).
##
## Flow: story "freetime_intro" (full ScriptPlayer) -> chooser with the 14 other capybaras as
## round portrait medallions -> each pick plays "hangout_<id>" in a full ScriptPlayer (the script
## sets its own bg), appends to Game.hangouts_done and uses one slot -> when the slots run out,
## "freetime_outro" (if it exists) -> finished({}).
## Mouse first; arrow keys + Enter/Space also work in the chooser.

signal finished(result: Dictionary)

const ScriptPlayer := preload("res://scripts/core/script_player.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Style := preload("res://scripts/ui/style.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Chapters := preload("res://scripts/data/chapters.gd")
const Skills := preload("res://scripts/data/skills.gd")
const Story := preload("res://scripts/data/story.gd")

const W := 1280.0
const H := 720.0
const MED_R := 58.0
const COLS := 7
var _cols := COLS
const COL_STEP := 160.0
const ROW_Y := [238.0, 420.0]
const ROW_X0 := [120.0, 200.0]
## Face crop inside the 480x600 portrait (circle center + radius, portrait space).
const FACE_CENTER := Vector2(240, 205)
const FACE_R := 178.0
const INK := Color("2a1a10")
## Autotest picks these first (useful trial skills), then whoever is left.
const AUTO_PICKS := ["coco", "pepper", "nibs"]

const GRAY_SHADER := """shader_type canvas_item;
uniform float gray = 1.0;
uniform float dim = 0.7;
varying vec4 vcol;
void vertex() {
	vcol = COLOR;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * vcol;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(l), gray) * dim, c.a);
}
"""

var _slots := 3
var _slots_left := 0
var _sp: Control = null
var _backdrop: Control
var _chooser: Control
var _header: Control
var _fade: ColorRect
var _fx: Control
var _medals: Array = []
var _yuzus: Array = []
var _hover: Control = null
var _kb_index := -1
var _active := false
var _gray_mat: ShaderMaterial

var _info_panel: Panel
var _info_default: Control
var _info_char: Control
var _info_name: Label
var _info_talent: Label
var _info_status: Label
var _info_skill: Label
var _info_desc: Label
var _info_tag: Label
var _slots_label: Label


func setup(params: Dictionary) -> void:
	_slots = maxi(int(params.get("slots", 3)), 0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = GRAY_SHADER
	_gray_mat = ShaderMaterial.new()
	_gray_mat.shader = sh
	_build_backdrop()
	_build_chooser()
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.02, 0.01, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 10
	add_child(_fade)
	Audio.play_music("daily")
	_run.call_deferred()


# =================================================================== flow
func _run() -> void:
	_chooser.visible = false
	_backdrop.visible = false
	if Story.has("freetime_intro"):
		var running := _start_story("freetime_intro")
		if running and _sp.is_running():
			await _sp.finished
		if not is_inside_tree():
			return
	_slots_left = mini(_slots, _available_count())
	if _slots_left <= 0:
		await _finish()
		return
	await _reveal_chooser()
	_enable_chooser()


func _available_count() -> int:
	var n := 0
	for m in _medals:
		if not m.done:
			n += 1
	return n


func _reveal_chooser() -> void:
	_backdrop.visible = true
	_chooser.visible = true
	_refresh_slots(false)
	for m in _medals:
		m.scale = Vector2.ZERO
		m.set_selected(false)
	_header.modulate.a = 0.0
	_header.position.x = -60.0
	_info_panel.modulate.a = 0.0
	if _sp:
		var tw0 := create_tween()
		tw0.tween_property(_sp, "modulate:a", 0.0, _dur(0.35))
		await tw0.finished
		_free_player()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_header, "modulate:a", 1.0, _dur(0.3))
	tw.tween_property(_header, "position:x", 0.0, _dur(0.35)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_info_panel, "modulate:a", 1.0, _dur(0.3)).set_delay(_dur(0.2))
	Audio.sfx("whoosh", 1.0, -6.0)
	for i in _medals.size():
		var m: Control = _medals[i]
		tw.tween_property(m, "scale", Vector2.ONE, _dur(0.32)).set_delay(_dur(0.05 + i * 0.035)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i % 2 == 0:
			tw.tween_callback(Audio.sfx.bind("pop", 0.9 + i * 0.04, -14.0)).set_delay(_dur(0.05 + i * 0.035))
	await tw.finished


func _enable_chooser() -> void:
	_active = true
	_show_info(_hover.char_id if _hover else "")
	_hover_under_mouse()
	if Game.autotest:
		_auto_pick()


func _auto_pick() -> void:
	await get_tree().create_timer(0.15, false).timeout
	if not _active or not is_inside_tree():
		return
	var target: Control = null
	for id in Chapters.get_value("auto_picks", AUTO_PICKS):
		for m in _medals:
			if m.char_id == id and not m.done:
				target = m
				break
		if target:
			break
	if target == null:
		for m in _medals:
			if not m.done:
				target = m
				break
	if target:
		_pick(target)


func _pick(m: Control) -> void:
	if not _active:
		return
	if m.done:
		Audio.sfx("cancel")
		_wiggle(m)
		return
	if _slots_left <= 0:
		return
	_active = false
	var id: String = m.char_id
	Audio.sfx("confirm")
	_select(m)
	_burst(m.home, Cast.color(id), 22)
	_burst(m.home, Style.GOLD, 10)
	await m.pulse(_dur(0.12)).finished
	await _fade_to(1.0, 0.3)
	_chooser.visible = false
	_backdrop.visible = false
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
	_backdrop.visible = true
	_chooser.visible = true
	_select(null)
	await _fade_to(0.0, 0.3)
	await _wait(0.15)
	await _consume_slot(m)
	if _slots_left <= 0 or _available_count() == 0:
		_show_info("")
		await _wait(0.7)
		await _finish()
	else:
		_enable_chooser()


func _consume_slot(m: Control) -> void:
	# the next full yuzu pops, the medallion greys out and gets its check badge
	var idx := _slots_left
	if idx >= 0 and idx < _yuzus.size():
		var y: Control = _yuzus[idx]
		var tw := create_tween()
		tw.tween_property(y, "scale", Vector2.ONE * 1.45, _dur(0.12)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			y.spent = true
			y.queue_redraw()
			Audio.sfx("pop", 1.1, -4.0)
			_burst(y.position + y.size * 0.5, Color("ffc23a"), 14))
		tw.tween_property(y, "scale", Vector2.ONE * 0.6, 0.01)
		tw.tween_property(y, "scale", Vector2.ONE, _dur(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
	_refresh_slots(true)
	m.set_done(_gray_mat, true)
	Audio.sfx("correct", 1.0, -6.0)
	await _wait(0.35)


func _finish() -> void:
	_active = false
	_select(null)
	if Story.has("freetime_outro"):
		await _fade_to(1.0, 0.35)
		_chooser.visible = false
		_backdrop.visible = false
		var running := _start_story("freetime_outro")
		await _fade_to(0.0, 0.3)
		if running and _sp and _sp.is_running():
			await _sp.finished
		if not is_inside_tree():
			return
	finished.emit({})


# =================================================================== story playback
## Starts a story script in a fresh full-screen ScriptPlayer. Returns true if it is still running.
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


## The first "@bg <id>" of a script, so the player can show it instantly (no crossfade from empty).
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


# =================================================================== building
func _build_backdrop() -> void:
	_backdrop = Control.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = Assets.bg("lobby")
	bg.modulate = Color(0.34, 0.31, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(bg)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.28, 0.62, 1.0])
	grad.colors = PackedColorArray([Color(0.04, 0.02, 0.1, 0.82), Color(0.06, 0.03, 0.14, 0.25),
		Color(0.06, 0.03, 0.14, 0.3), Color(0.03, 0.02, 0.08, 0.9)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.texture = gt
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(shade)
	_backdrop.add_child(Bubbles.new())


func _build_chooser() -> void:
	_chooser = Control.new()
	_chooser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chooser.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chooser)
	# header
	_header = Control.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.size = Vector2(W, 150)
	_chooser.add_child(_header)
	var title := Style.title_label("FREE TIME", 60, Style.GOLD, Style.BG_DARK, 14)
	title.position = Vector2(54, 18)
	_header.add_child(title)
	var bar := ColorRect.new()
	bar.color = Style.AQUA
	bar.position = Vector2(60, 98)
	bar.size = Vector2(318, 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(bar)
	var sub := Style.label("Day %d  -  Afternoon. Who will you spend time with?" % maxi(Chapters.day_at(Game.main.current_step()), 1), 20, Style.TEXT, true)
	sub.position = Vector2(60, 110)
	sub.add_theme_color_override("font_outline_color", Style.BG_DARK)
	sub.add_theme_constant_override("outline_size", 6)
	_header.add_child(sub)
	# slot indicator (top right)
	var sl := Style.title_label("VISITS LEFT", 18, Style.AQUA, Style.BG_DARK, 6)
	sl.position = Vector2(1000, 26)
	sl.size = Vector2(220, 24)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_child(sl)
	var n := clampi(_slots, 0, 6)
	var step := 62.0
	var x0 := 1110.0 - (n - 1) * step * 0.5
	for i in n:
		var y := YuzuIcon.new()
		y.position = Vector2(x0 + i * step - 26.0, 52)
		y.phase = i * 1.3
		_header.add_child(y)
		_yuzus.append(y)
	_slots_label = Style.label("", 15, Style.TEXT_DIM)
	_slots_label.position = Vector2(1000, 108)
	_slots_label.size = Vector2(220, 20)
	_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_child(_slots_label)
	# medallions
	var ids: Array = []
	for id in Cast.roster_alive():
		if id != "mochi":
			ids.append(id)
	# two even rows (14 guests = 7 + 7, 12 = 6 + 6, 10 = 5 + 5), nudged right to stay centred
	_cols = mini(COLS, ceili(ids.size() / 2.0))
	var x_off := (COLS - _cols) * COL_STEP * 0.5
	for i in ids.size():
		var row := i / _cols
		var col := i % _cols
		var m := Medallion.new()
		m.char_id = ids[i]
		m.tex = Assets.portrait(ids[i], "normal")
		m.home = Vector2(float(ROW_X0[mini(row, 1)]) + x_off + col * COL_STEP, float(ROW_Y[mini(row, 1)]) + maxi(row - 1, 0) * 182.0)
		m.hovered.connect(_on_hover)
		m.unhovered.connect(_on_unhover)
		m.picked.connect(_pick)
		_chooser.add_child(m)
		_medals.append(m)
		if Game.hangouts_done.has(ids[i]):
			m.set_done(_gray_mat, false)
	_build_info_panel()


func _build_info_panel() -> void:
	_info_panel = Panel.new()
	_info_panel.position = Vector2(150, 556)
	_info_panel.size = Vector2(980, 144)
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := Style.box(Color(0.07, 0.04, 0.15, 0.94), 18, Style.AQUA, 3)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 12
	_info_panel.add_theme_stylebox_override("panel", st)
	_chooser.add_child(_info_panel)
	# default text
	_info_default = Control.new()
	_info_default.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_default.size = _info_panel.size
	_info_panel.add_child(_info_default)
	var d1 := Style.title_label("Who will you spend the afternoon with?", 28, Style.GOLD, Style.BG_DARK, 8)
	d1.position = Vector2(0, 30)
	d1.size = Vector2(980, 40)
	d1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_default.add_child(d1)
	var d2 := Style.label("Each visit uses one slot of free time - and every friend can teach you a skill for what lies ahead.", 18, Style.TEXT_DIM)
	d2.position = Vector2(0, 82)
	d2.size = Vector2(980, 26)
	d2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_default.add_child(d2)
	# character details
	_info_char = Control.new()
	_info_char.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_char.size = _info_panel.size
	_info_char.visible = false
	_info_panel.add_child(_info_char)
	_info_name = Style.title_label("", 32, Color.WHITE, Style.BG_DARK, 8)
	_info_name.position = Vector2(30, 14)
	_info_name.size = Vector2(420, 44)
	_info_name.clip_text = true
	_info_char.add_child(_info_name)
	_info_talent = Style.label("", 20, Style.TEXT_DIM, true)
	_info_talent.position = Vector2(32, 60)
	_info_char.add_child(_info_talent)
	_info_status = Style.label("", 17, Style.AQUA)
	_info_status.position = Vector2(32, 100)
	_info_char.add_child(_info_status)
	var div := ColorRect.new()
	div.color = Color(Style.AQUA_DEEP, 0.8)
	div.position = Vector2(462, 18)
	div.size = Vector2(3, 108)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_char.add_child(div)
	_info_tag = Style.title_label("WILL TEACH YOU", 15, Style.AQUA, Style.BG_DARK, 5)
	_info_tag.position = Vector2(488, 14)
	_info_char.add_child(_info_tag)
	_info_skill = Style.title_label("", 27, Style.GOLD, Style.BG_DARK, 8)
	_info_skill.position = Vector2(488, 34)
	_info_char.add_child(_info_skill)
	_info_desc = Label.new()
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.position = Vector2(490, 76)
	_info_desc.size = Vector2(466, 60)
	_info_desc.add_theme_font_size_override("font_size", 18)
	_info_desc.add_theme_color_override("font_color", Style.TEXT)
	_info_char.add_child(_info_desc)


func _refresh_slots(animated: bool) -> void:
	for i in _yuzus.size():
		var y: Control = _yuzus[i]
		var sp: bool = i >= _slots_left
		if y.spent != sp:
			y.spent = sp
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


# =================================================================== hover / info
func _on_hover(m: Control) -> void:
	if not _active:
		return
	if _hover != m:
		Audio.sfx("select", 1.0 + randf_range(-0.04, 0.04), -4.0)
	_select(m)


func _on_unhover(m: Control) -> void:
	if _hover == m:
		m.set_selected(false)
		_hover = null
		_kb_index = -1


func _select(m: Control) -> void:
	if _hover == m:
		return
	if _hover:
		_hover.set_selected(false)
	_hover = m
	_kb_index = _medals.find(m) if m else -1
	if m:
		m.set_selected(true)
		_show_info(m.char_id)


func _show_info(id: String) -> void:
	if id == "":
		_info_default.visible = true
		_info_char.visible = false
		return
	_info_default.visible = false
	_info_char.visible = true
	var col := Cast.color(id)
	_info_name.text = Cast.full_name(id)
	var nl := Cast.full_name(id).length()
	_info_name.add_theme_font_size_override("font_size", 32 if nl <= 17 else (27 if nl <= 22 else 23))
	_info_name.add_theme_color_override("font_color", col.lightened(0.25))
	_info_talent.text = Cast.talent(id)
	var sid: String = Skills.BY_CHAR.get(id, "")
	_info_skill.text = Skills.skill_name(sid) if sid != "" else "?"
	_info_desc.text = Skills.desc(sid) if sid != "" else ""
	var done := Game.hangouts_done.has(id)
	if done:
		_info_status.text = "You already spent time together today."
		_info_status.add_theme_color_override("font_color", Style.GOOD)
		_info_tag.text = "TAUGHT YOU"
	elif sid != "" and Game.has_skill(sid):
		_info_status.text = "Click to spend time together."
		_info_status.add_theme_color_override("font_color", Style.AQUA)
		_info_tag.text = "SKILL (ALREADY KNOWN)"
	else:
		_info_status.text = "Click to spend time together." if _slots_left > 0 else ""
		_info_status.add_theme_color_override("font_color", Style.AQUA)
		_info_tag.text = "WILL TEACH YOU"
	_info_char.modulate.a = 0.4
	var tw := create_tween()
	tw.tween_property(_info_char, "modulate:a", 1.0, 0.12)


func _hover_under_mouse() -> void:
	var mp := get_global_mouse_position()
	for m in _medals:
		var lp: Vector2 = m.get_global_transform().affine_inverse() * mp
		if m._has_point(lp):
			_select(m)
			return


func _wiggle(m: Control) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(m, "rotation", deg_to_rad(7.0 if i % 2 == 0 else -7.0), 0.05)
	tw.tween_property(m, "rotation", 0.0, 0.05)


func _unhandled_input(e: InputEvent) -> void:
	if not _active or not is_visible_in_tree():
		return
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return
	var idx := _kb_index
	var n := _medals.size()
	match k.keycode:
		KEY_LEFT, KEY_A:
			idx = (idx - 1 + n) % n if idx >= 0 else 0
		KEY_RIGHT, KEY_D:
			idx = (idx + 1) % n if idx >= 0 else 0
		KEY_UP, KEY_W:
			idx = idx - _cols if idx >= _cols else (idx if idx >= 0 else 0)
		KEY_DOWN, KEY_S:
			idx = mini(idx + _cols, n - 1) if idx >= 0 else 0
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z:
			if k.echo:
				return
			if _kb_index >= 0:
				get_viewport().set_input_as_handled()
				_pick(_medals[_kb_index])
			return
		_:
			return
	get_viewport().set_input_as_handled()
	if idx != _kb_index and idx >= 0 and idx < n:
		Audio.sfx("select", 1.0, -4.0)
		_select(_medals[idx])


# =================================================================== helpers
func _dur(sec: float) -> float:
	return 0.01 if Game.autotest else sec


func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, _dur(dur))
	await tw.finished


func _wait(sec: float) -> void:
	await get_tree().create_timer(_dur(sec), false).timeout


func _burst(at: Vector2, col: Color, count: int) -> void:
	if Game.autotest:
		return
	var b := Burst.new()
	b.origin = at
	b.color = col
	b.count = count
	_fx.add_child(b)


# =================================================================== inner classes
## A round portrait medallion: face crop drawn as a textured circle polygon (circular mask),
## colored backdrop + ring, gold glow when selected, grey + check badge once visited.
class Medallion extends Control:
	signal hovered(m: Control)
	signal unhovered(m: Control)
	signal picked(m: Control)

	var char_id := ""
	var home := Vector2.ZERO
	var tex: Texture2D = null
	var done := false
	var selected := false
	var glow := 0.0
	var t := 0.0
	var phase := 0.0
	var badge: Control = null
	var name_label: Label
	var talent_label: Label
	var _poly := PackedVector2Array()
	var _uvs := PackedVector2Array()
	var _scale_tw: Tween

	func _init() -> void:
		size = Vector2(MED_R * 2.0, MED_R * 2.0)
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var c := size * 0.5
		var r := MED_R - 3.0
		for i in 72:
			var a := TAU * float(i) / 72.0
			var d := Vector2(cos(a), sin(a))
			_poly.append(c + d * r)
			_uvs.append((FACE_CENTER + d * FACE_R) / Assets.PORTRAIT_SIZE)
		badge = CheckBadge.new()
		badge.radius = 16.0
		badge.position = c + Vector2(MED_R * 0.7, -MED_R * 0.7) - Vector2(16, 16)
		badge.visible = false
		add_child(badge)

	func _ready() -> void:
		position = home - pivot_offset
		phase = randf() * TAU
		var c := size * 0.5
		name_label = Style.title_label(Cast.display_name(char_id), 20, Color.WHITE, Style.BG_DARK, 6)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(c.x - 80.0, size.y + 6.0)
		name_label.size = Vector2(160, 26)
		add_child(name_label)
		talent_label = Style.label(Cast.talent(char_id), 14, Style.TEXT_DIM)
		talent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		talent_label.position = Vector2(c.x - 82.0, size.y + 32.0)
		talent_label.size = Vector2(164, 20)
		talent_label.add_theme_color_override("font_outline_color", Style.BG_DARK)
		talent_label.add_theme_constant_override("outline_size", 4)
		add_child(talent_label)
		move_child(badge, -1)
		if done:
			name_label.modulate = Color(0.7, 0.7, 0.75)
			talent_label.modulate = Color(0.7, 0.7, 0.75)
		mouse_entered.connect(func() -> void: hovered.emit(self))
		mouse_exited.connect(func() -> void: unhovered.emit(self))

	func _has_point(p: Vector2) -> bool:
		return p.distance_to(size * 0.5) <= MED_R + 3.0

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			picked.emit(self)

	func set_selected(on: bool) -> void:
		if selected == on:
			return
		selected = on
		z_index = 2 if on else 0
		if _scale_tw:
			_scale_tw.kill()
		_scale_tw = create_tween()
		_scale_tw.tween_property(self, "scale", Vector2.ONE * (1.16 if on else 1.0), 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if name_label:
			name_label.add_theme_color_override("font_color", Style.GOLD if on else Color.WHITE)

	## Click feedback: a quick swell, ending at the selected size.
	func pulse(step: float) -> Tween:
		if _scale_tw:
			_scale_tw.kill()
		_scale_tw = create_tween()
		_scale_tw.tween_property(self, "scale", Vector2.ONE * 1.32, step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_scale_tw.tween_property(self, "scale", Vector2.ONE * 1.16, step)
		return _scale_tw

	func set_done(mat: ShaderMaterial, animated: bool) -> void:
		done = true
		material = mat
		badge.visible = true
		if name_label:
			name_label.modulate = Color(0.7, 0.7, 0.75)
			talent_label.modulate = Color(0.7, 0.7, 0.75)
		if animated:
			badge.scale = Vector2.ZERO
			var tw := create_tween()
			tw.tween_property(badge, "scale", Vector2.ONE * 1.3, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(badge, "scale", Vector2.ONE, 0.12)

	func _process(delta: float) -> void:
		t += delta
		glow = move_toward(glow, 1.0 if selected else 0.0, delta * 6.0)
		position.y = home.y - pivot_offset.y + sin(t * 1.7 + phase) * (1.2 if done else 3.0)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Cast.color(char_id)
		if glow > 0.01:
			for i in 5:
				draw_circle(c, MED_R + 17.0 - i * 3.2, Color(Style.GOLD, 0.07 * glow))
		draw_circle(c + Vector2(0, 7), MED_R + 2.0, Color(0, 0, 0, 0.35))
		draw_circle(c, MED_R + 2.0, INK)
		draw_circle(c, MED_R - 2.0, col.darkened(0.5))
		draw_circle(c + Vector2(0, -MED_R * 0.22), MED_R * 0.74, Color(col.lightened(0.15), 0.45))
		if tex:
			draw_colored_polygon(_poly, Color.WHITE, _uvs, tex)
		var ring := col.lerp(Style.GOLD, glow)
		draw_arc(c, MED_R - 2.5, 0.0, TAU, 72, ring, 5.0 + glow * 1.5, true)
		draw_arc(c, MED_R + 1.0, 0.0, TAU, 72, INK, 2.5, true)
		draw_arc(c, MED_R - 10.0, deg_to_rad(198), deg_to_rad(248), 14, Color(1, 1, 1, 0.3 + 0.2 * glow), 3.0, true)


## Small green check badge.
class CheckBadge extends Control:
	var radius := 14.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(radius * 2.0, radius * 2.0)
		pivot_offset = size * 0.5

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c + Vector2(0, 2), radius + 1.0, Color(0, 0, 0, 0.35))
		draw_circle(c, radius + 1.5, INK)
		draw_circle(c, radius - 1.0, Style.GOOD)
		draw_circle(c + Vector2(-radius * 0.25, -radius * 0.3), radius * 0.35, Color(1, 1, 1, 0.25))
		var pts := PackedVector2Array([c + Vector2(-radius * 0.45, 0.0), c + Vector2(-radius * 0.1, radius * 0.38),
			c + Vector2(radius * 0.5, -radius * 0.36)])
		draw_polyline(pts, Color.WHITE, maxf(2.5, radius * 0.24), true)


## A yuzu fruit drawn with shapes (full = visit available, spent = faded outline).
class YuzuIcon extends Control:
	var spent := false
	var phase := 0.0
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(52, 52)
		pivot_offset = size * 0.5

	func _process(delta: float) -> void:
		t += delta
		rotation = 0.0 if spent else sin(t * 2.2 + phase) * 0.08
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, 4)
		var r := 18.0
		if spent:
			draw_circle(c, r, Color(0.2, 0.16, 0.32, 0.6))
			draw_arc(c, r, 0.0, TAU, 40, Color(Style.TEXT_DIM, 0.5), 2.5, true)
			draw_line(c + Vector2(0, -r), c + Vector2(1, -r - 5), Color(Style.TEXT_DIM, 0.5), 2.5, true)
			return
		draw_circle(c + Vector2(0, 4), r + 2.0, Color(0, 0, 0, 0.3))
		draw_circle(c, r + 2.5, INK)
		draw_circle(c, r, Color("f6a623"))
		draw_circle(c + Vector2(-3, -3), r * 0.78, Color("ffc23a"))
		draw_circle(c + Vector2(-7, -7), r * 0.26, Color(1, 1, 0.9, 0.85))
		for p in [Vector2(5, 3), Vector2(-2, 8), Vector2(9, -4), Vector2(2, -9)]:
			draw_circle(c + p, 1.1, Color(0.85, 0.5, 0.05, 0.6))
		var leaf := PackedVector2Array([c + Vector2(1, -r + 1), c + Vector2(9, -r - 9), c + Vector2(19, -r - 7),
			c + Vector2(12, -r + 1)])
		draw_colored_polygon(leaf, Color("6cc04a"))
		var outline := leaf.duplicate()
		outline.append(leaf[0])
		draw_polyline(outline, INK, 2.0, true)
		draw_line(c + Vector2(3, -r - 3), c + Vector2(14, -r - 5), Color("4e9a32"), 1.5, true)
		draw_line(c + Vector2(0, -r + 2), c + Vector2(-1, -r - 5), INK, 3.0, true)


## Gentle rising bubbles for the background.
class Bubbles extends Control:
	var items: Array = []
	var t := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 30:
			items.append(_bubble(true))

	func _bubble(anywhere: bool) -> Dictionary:
		var r := randf_range(4.0, 24.0)
		var y := randf_range(0.0, H + 40.0) if anywhere else H + r + randf_range(0.0, 120.0)
		return {"x": randf_range(0.0, W), "y": y, "r": r, "sp": randf_range(16.0, 42.0) * (1.25 - r / 40.0),
			"ph": randf() * TAU, "amp": randf_range(6.0, 22.0), "a": randf_range(0.14, 0.34)}

	func _process(delta: float) -> void:
		t += delta
		for i in items.size():
			var b: Dictionary = items[i]
			b["y"] = float(b["y"]) - float(b["sp"]) * delta
			if float(b["y"]) < -float(b["r"]) - 10.0:
				items[i] = _bubble(false)
		queue_redraw()

	func _draw() -> void:
		for b in items:
			var r: float = b["r"]
			var a: float = b["a"]
			var p := Vector2(float(b["x"]) + sin(t * 0.8 + float(b["ph"])) * float(b["amp"]), float(b["y"]))
			draw_circle(p, r, Color(Style.AQUA, a * 0.22))
			draw_arc(p, r, 0.0, TAU, 28, Color(Style.AQUA, a), 1.6, true)
			draw_circle(p + Vector2(-r * 0.35, -r * 0.35), maxf(r * 0.2, 1.2), Color(1, 1, 1, minf(a * 1.4, 1.0)))


## Short particle burst (juice), frees itself.
class Burst extends Control:
	var origin := Vector2.ZERO
	var color := Color.WHITE
	var count := 16
	var life := 0.65
	var age := 0.0
	var parts: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for i in count:
			var a := randf() * TAU
			var sp := randf_range(140.0, 380.0)
			parts.append({"p": origin, "v": Vector2(cos(a), sin(a)) * sp + Vector2(0, -90), "r": randf_range(3.0, 7.0)})

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		for p in parts:
			var v: Vector2 = p["v"]
			v.y += 520.0 * delta
			v *= 1.0 - 1.8 * delta
			p["v"] = v
			p["p"] = (p["p"] as Vector2) + v * delta
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 - age / life
		for p in parts:
			draw_circle(p["p"], float(p["r"]) * (0.4 + 0.6 * k), Color(color, k))
