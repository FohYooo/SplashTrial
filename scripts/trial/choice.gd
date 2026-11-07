extends Control
## Pick-the-Answer minigames. One script, three flavours (branches on data.type):
##   "choice"    PICK THE ANSWER       big option buttons (click or keys 1-9)
##   "present"   PRESENT A TRUTH DROP  grid of owned clues (Game.clues) + detail pane + PRESENT!
##   "character" POINT OUT A CAPYBARA  grid of portraits (Cast.survivors() minus data.exclude)
## Contract: docs/ARCHITECTURE.md section 5. Wrong picks cost convince and get crossed out; the
## player retries until correct. Skill "hypothesis" crosses out one wrong option at the start.
## Look: angular "sharp kit" (see the SHARP KIT section at the end of this file).

signal finished(result: Dictionary)
signal _reaction_closed

const Style := preload("res://scripts/ui/style.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Clues := preload("res://scripts/data/clues.gd")

const W := 1280.0
const H := 720.0
const INK := Color("2a1a10")
const CARD_BG := Color(0.10, 0.06, 0.22, 0.95)
const CARD_HOVER := Color(0.19, 0.12, 0.38, 0.98)

var _data := {}
var _type := "choice"
var _speaker := "snapjaw"
var _answer := ""
var _done := false
var _busy := true
var _k := 1.0                 # presentation-time multiplier (tiny in autotest)
var _auto_wrong := false      # autotest in an isolated --minigame run: try one wrong answer first
var _time := 0.0

var _keys: Array[String] = []  # option keys in display order (choice: "0".."n", present: clue ids, character: char ids)
var _nodes := {}               # key -> Button
var _crossed := {}             # key -> "wrong" | "hyp"
var _sel := ""                 # present: currently selected clue
var _solved := false

var _stage: Control
var _fx: Control
var _overlay: Control

var _portrait: TextureRect     # choice: big speaker portrait
var _slash: Control            # choice: coloured slash behind the portrait
var _prompt_panel: Panel
var _badge: Control
var _hint: Label
var _detail: Panel             # present: detail pane
var _detail_icon_holder: Control
var _detail_name: Label
var _detail_desc: Label
var _present_btn: Button

var _reaction: Control = null
var _react_text: RichTextLabel
var _react_tw: Tween


# =================================================================== setup
func setup(data: Dictionary) -> void:
	_data = data
	_type = str(data.get("type", "choice"))
	if not _type in ["choice", "present", "character"]:
		_type = "choice"
	_speaker = str(data.get("speaker", "snapjaw"))
	_answer = str(data.get("answer", "0"))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_k = 0.12 if Game.autotest and not Game.autotest_slow else 1.0
	_auto_wrong = Game.autotest and Game.debug_minigame != ""
	if _data.is_empty():
		setup({"type": "choice", "prompt": "...", "options": ["OK"], "answer": 0})
	_kit_backdrop(0.5)
	_stage = _layer()
	_fx = _layer()
	_fx.draw.connect(_kit_draw)
	_overlay = _layer()
	_kit_top_layers()
	match _type:
		"present":
			_badge = _kit_badge("PRESENT A TRUTH DROP")
			_build_present()
			_build_hint("Select a Truth Drop, then PRESENT!")
		"character":
			_badge = _kit_badge("POINT OUT A CAPYBARA")
			_build_character()
			_build_hint("Click the capybara you suspect!")
		_:
			_badge = _kit_badge("PICK THE ANSWER")
			_build_choice()
			_build_hint("Click an answer or press 1-%d" % _keys.size())
	_intro()


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


# =================================================================== shared widgets
func _build_hint(text: String) -> void:
	var chip := Panel.new()
	chip.position = Vector2(918, 24)
	chip.size = Vector2(338, 32)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.03, 0.13, 0.85), Color(Style.AQUA, 0.55), 2, 8, 0.4, HARD_SHADOW, Vector2(4, 4)))
	_stage.add_child(chip)
	_hint = Style.label(text, _fit(Style.body_font(), text, Vector2(310, 24), 15, 11), Style.TEXT)
	_hint.position = Vector2(14, 4)
	_hint.size = Vector2(310, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.clip_text = true
	chip.add_child(_hint)


func _name_tag(id: String) -> PanelContainer:
	var col := Cast.color(id) if Cast.exists(id) else Style.YUZU
	return _kit_tag(Cast.display_name(id) if Cast.exists(id) else "???", col, 22)


## A clipped head-and-shoulders crop of a portrait in an angular frame (corner tabs instead of rounding).
func _head_box(id: String, expr: String, box: Vector2, frame_col: Color, frame_w: int = 3) -> Panel:
	var holder := Panel.new()
	holder.size = box
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgc := frame_col.darkened(0.66)
	bgc.a = 0.96
	holder.add_theme_stylebox_override("panel", _sb(bgc, Color(0, 0, 0, 0), 0, 0, 0.0, Color(0, 0, 0, 0)))
	var deco := Control.new()
	deco.size = box
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func() -> void:
		# diagonal light slash + stripes behind the face
		deco.draw_colored_polygon(PackedVector2Array([Vector2(box.x * 0.55, 0), Vector2(box.x * 0.85, 0), Vector2(box.x * 0.35, box.y), Vector2(box.x * 0.05, box.y)]), Color(frame_col, 0.20))
		deco.draw_colored_polygon(PackedVector2Array([Vector2(box.x * 0.92, 0), Vector2(box.x, 0), Vector2(box.x * 0.55, box.y), Vector2(box.x * 0.47, box.y)]), Color(frame_col, 0.12)))
	holder.add_child(deco)
	var tr := TextureRect.new()
	tr.name = "Face"
	tr.texture = Assets.portrait(id, expr)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	var s := box.x / 300.0
	tr.size = Assets.PORTRAIT_SIZE * s
	tr.position = Vector2((box.x - tr.size.x) * 0.5, -box.y * 0.02)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tr)
	var fr := Control.new()
	fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fw := float(frame_w)
	fr.draw.connect(func() -> void:
		var sz := fr.size
		var t := minf(sz.x, sz.y) * 0.16
		fr.draw_rect(Rect2(Vector2(fw * 0.5, fw * 0.5), sz - Vector2(fw, fw)), frame_col, false, fw)
		fr.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(t, 0), Vector2(0, t)]), frame_col)
		fr.draw_colored_polygon(PackedVector2Array([sz, Vector2(sz.x - t, sz.y), Vector2(sz.x, sz.y - t)]), frame_col))
	holder.add_child(fr)
	return holder


## Prompt panel: optional speaker avatar, name tag and the question text (auto-fitted).
func _build_prompt(r: Rect2, with_avatar: bool) -> void:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := Cast.color(_speaker) if Cast.exists(_speaker) else Style.AQUA
	p.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.025, 0.12, 0.95), Style.AQUA, 3, 20, 0.05, HARD_SHADOW, Vector2(9, 9)))
	_stage.add_child(p)
	_prompt_panel = p
	# accent: speaker-coloured top bar + yuzu stripes in the bottom-right corner
	var acc := Control.new()
	acc.size = r.size
	acc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	acc.draw.connect(func() -> void:
		acc.draw_colored_polygon(PackedVector2Array([Vector2(28, 3), Vector2(r.size.x * 0.42, 3), Vector2(r.size.x * 0.42 - 8, 9), Vector2(20, 9)]), Color(col, 0.9)))
	p.add_child(acc)
	_kit_stripes(p, Vector2(r.size.x - 96, r.size.y - 30), 5, Color(Style.YUZU, 0.55), Vector2(6, 20), 12.0)
	var tx := 26.0
	if with_avatar:
		var a := r.size.y - 22.0
		var av := _head_box(_speaker, "normal", Vector2(a, a), col)
		av.position = Vector2(12, 11)
		p.add_child(av)
		tx = a + 34.0
	var tag := _name_tag(_speaker)
	tag.position = Vector2(tx, 12)
	p.add_child(tag)
	var prompt := str(_data.get("prompt", ""))
	var box := Vector2(r.size.x - tx - 30.0, r.size.y - 58.0)
	var l := Style.label(prompt, _fit(Style.body_font(), prompt, box, 26, 16), Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(tx, 48)
	l.size = box
	p.add_child(l)


## Largest font size (max_s..min_s) whose wrapped text fits into box.
func _fit(font: Font, text: String, box: Vector2, max_s: int, min_s: int) -> int:
	var s := max_s
	while s > min_s:
		var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box.x - 4.0, s)
		if sz.y * 1.12 <= box.y:
			return s
		s -= 1
	return min_s


func _btn_style(bg: Color, border: Color, bw: int, skew: float = 0.1, margin_left: int = 14, shadow: Color = HARD_SHADOW) -> StyleBoxFlat:
	var st := _sb(bg, border, bw, 14, skew, shadow, Vector2(7, 7))
	st.content_margin_left = margin_left
	return st


func _style_card(b: Button, skew: float = 0.08) -> void:
	b.add_theme_stylebox_override("normal", _btn_style(CARD_BG, Style.AQUA_DEEP, 2, skew))
	b.add_theme_stylebox_override("hover", _btn_style(CARD_HOVER, Style.AQUA, 3, skew, 14, Color(Style.AQUA_DEEP, 0.95)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.10, 0.40, 0.46, 0.98), Style.GOLD, 4, skew))
	b.add_theme_stylebox_override("focus", _btn_style(Color(0, 0, 0, 0), Style.GOLD, 3, skew, 14, Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(0.08, 0.06, 0.13, 0.85), Color(0.28, 0.26, 0.36), 2, skew))


func _hover_fx(b: Control, on: bool) -> void:
	if _crossed.has(_key_of(b)) or _solved or _done:
		return
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "scale", Vector2.ONE * (1.045 if on else 1.0), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if on:
		Audio.sfx("select", randf_range(1.1, 1.25), -12.0)


func _key_of(n: Control) -> String:
	for k in _nodes.keys():
		if _nodes[k] == n:
			return str(k)
	return ""


# =================================================================== CHOICE
func _build_choice() -> void:
	var opts: Array = _data.get("options", [])
	if opts.is_empty():
		opts = ["..."]
	_answer = str(clampi(int(_answer), 0, opts.size() - 1))
	var expr := str(_data.get("expr", "normal"))
	var col := Cast.color(_speaker) if Cast.exists(_speaker) else Style.VIOLET
	# slanted spotlight slash in the speaker's colour behind the portrait
	_slash = Control.new()
	_slash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slash.draw.connect(func() -> void:
		_slash.draw_colored_polygon(PackedVector2Array([Vector2(150, 150), Vector2(330, 150), Vector2(180, H), Vector2(-20, H)]), Color(col, 0.32))
		_slash.draw_colored_polygon(PackedVector2Array([Vector2(342, 150), Vector2(362, 150), Vector2(212, H), Vector2(192, H)]), Color(Style.AQUA, 0.55))
		_slash.draw_colored_polygon(PackedVector2Array([Vector2(372, 150), Vector2(380, 150), Vector2(230, H), Vector2(222, H)]), Color(Style.YUZU, 0.7)))
	_stage.add_child(_slash)
	_portrait = TextureRect.new()
	_portrait.texture = Assets.portrait(_speaker, expr)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size = Vector2(432, 540)
	_portrait.position = Vector2(-10, H - 540)
	_portrait.pivot_offset = Vector2(216, 540)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_portrait)
	_build_prompt(Rect2(404, 88, 846, 150), false)
	var n := opts.size()
	var bh := clampf(420.0 / n - 16.0, 52.0, 80.0)
	var gap := 16.0 if n <= 4 else 10.0
	var y0 := 264.0
	for i in n:
		var key := str(i)
		var b := _option_button(str(opts[i]), i + 1, Vector2(780, bh))
		b.position = Vector2(446 - i * 6.0, y0 + i * (bh + gap))
		b.pressed.connect(_pick.bind(key))
		b.mouse_entered.connect(_hover_fx.bind(b, true))
		b.mouse_exited.connect(_hover_fx.bind(b, false))
		b.focus_entered.connect(_hover_fx.bind(b, true))
		b.focus_exited.connect(_hover_fx.bind(b, false))
		_stage.add_child(b)
		_keys.append(key)
		_nodes[key] = b


func _option_button(text: String, num: int, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.size = sz
	b.custom_minimum_size = sz
	b.pivot_offset = sz * 0.5
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", Style.display_font())
	b.add_theme_font_size_override("font_size", _fit(Style.display_font(), text, Vector2(sz.x - 120, sz.y - 10), 30, 16))
	b.add_theme_color_override("font_hover_color", Style.GOLD)
	b.add_theme_color_override("font_focus_color", Style.GOLD)
	b.add_theme_color_override("font_outline_color", NEAR_BLACK)
	b.add_theme_constant_override("outline_size", 6)
	var ml := int(sz.y * 0.5 + 70)
	var sk := 0.22
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.11, 0.06, 0.24, 0.95), Style.AQUA_DEEP, 3, sk, ml))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.21, 0.12, 0.42, 0.98), Style.YUZU, 4, sk, ml, Color(Style.AQUA, 0.9)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.10, 0.45, 0.50, 0.98), Style.GOLD, 4, sk, ml))
	b.add_theme_stylebox_override("focus", _btn_style(Color(0, 0, 0, 0), Style.GOLD, 3, sk, ml, Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(0.08, 0.06, 0.14, 0.85), Color(0.30, 0.28, 0.38), 2, sk, ml))
	# slanted yuzu number plate
	var bs := minf(sz.y - 18.0, 54.0)
	var badge := Control.new()
	badge.name = "Badge"
	badge.size = Vector2(bs * 1.25, bs)
	badge.position = Vector2(16, (sz.y - bs) * 0.5)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		var q := _kit_quad(bs * 1.25, bs, bs * 0.3, bs * 0.18)
		var sh := PackedVector2Array()
		for p in q:
			sh.append(p + Vector2(4, 4))
		badge.draw_colored_polygon(sh, HARD_SHADOW)
		badge.draw_colored_polygon(q, Style.YUZU)
		var o := q.duplicate()
		o.append(q[0])
		badge.draw_polyline(o, Color.WHITE, 2.0, true))
	b.add_child(badge)
	var nl := Style.label(str(num), int(bs * 0.56), NEAR_BLACK, true)
	nl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(nl)
	return b


# =================================================================== PRESENT
func _build_present() -> void:
	_build_prompt(Rect2(40, 84, 1200, 124), true)
	var ids: Array[String] = []
	for c in Clues.ORDER:
		if Game.clues.has(c):
			ids.append(c)
	for c in Game.clues:
		if not ids.has(c):
			ids.append(c)
	if not ids.has(_answer):
		ids.append(_answer)   # never make the question unsolvable
	var cols := 5
	var rows := ceili(ids.size() / float(cols))
	var gap := 12.0
	var area := Rect2(44, 224, 660, 476)
	var cw := (area.size.x - (cols - 1) * gap) / cols
	var ch := minf(152.0, (area.size.y - (rows - 1) * gap) / maxf(rows, 1))
	for i in ids.size():
		var id: String = ids[i]
		var b := Button.new()
		b.size = Vector2(cw, ch)
		b.pivot_offset = b.size * 0.5
		b.position = area.position + Vector2((i % cols) * (cw + gap), (i / cols) * (ch + gap))
		b.focus_mode = Control.FOCUS_ALL
		_style_card(b)
		var ic := minf(cw - 30.0, ch - 58.0)
		var icon := _clue_icon(id, Vector2(ic, ic), 0.36)
		icon.position = Vector2((cw - ic) * 0.5, 8)
		b.add_child(icon)
		var nm := Style.label(Clues.clue_name(id), 14, Style.TEXT)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.max_lines_visible = 2
		nm.clip_text = true
		nm.position = Vector2(4, ic + 10)
		nm.size = Vector2(cw - 8, ch - ic - 14)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nm)
		b.pressed.connect(_select_clue.bind(id, true))
		b.focus_entered.connect(_select_clue.bind(id, false))
		b.mouse_entered.connect(_hover_fx.bind(b, true))
		b.mouse_exited.connect(_hover_fx.bind(b, false))
		b.gui_input.connect(_on_card_input.bind(id))
		_stage.add_child(b)
		_keys.append(id)
		_nodes[id] = b
	# detail pane
	_detail = Panel.new()
	_detail.position = Vector2(728, 224)
	_detail.size = Vector2(512, 476)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.025, 0.12, 0.95), Style.AQUA, 3, 22, 0.0, HARD_SHADOW, Vector2(9, 9)))
	_stage.add_child(_detail)
	var hdr := _kit_tag("TRUTH DROP", Style.AQUA, 15)
	hdr.position = Vector2(22, -14)
	_detail.add_child(hdr)
	_kit_stripes(_detail, Vector2(420, 14), 5, Color(Style.AQUA, 0.4), Vector2(5, 18), 10.0)
	# angular plate behind the icon
	var plate := Control.new()
	plate.position = Vector2(156, 26)
	plate.size = Vector2(200, 160)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.draw.connect(func() -> void:
		var q := _kit_quad(200, 160, 40, 22)
		plate.draw_colored_polygon(q, Color(Style.VIOLET, 0.16))
		var o := q.duplicate()
		o.append(q[0])
		plate.draw_polyline(o, Color(Style.AQUA, 0.35), 2.0, true))
	_detail.add_child(plate)
	_detail_icon_holder = Control.new()
	_detail_icon_holder.position = Vector2(181, 30)
	_detail_icon_holder.size = Vector2(150, 150)
	_detail_icon_holder.pivot_offset = Vector2(75, 75)
	_detail_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(_detail_icon_holder)
	_detail_name = Style.title_label("", 28, Style.GOLD, NEAR_BLACK, 8)
	_detail_name.position = Vector2(16, 186)
	_detail_name.size = Vector2(480, 40)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail.add_child(_detail_name)
	_detail_desc = Style.label("", 18, Style.TEXT)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.position = Vector2(24, 230)
	_detail_desc.size = Vector2(464, 156)
	_detail_desc.clip_text = true
	_detail.add_child(_detail_desc)
	_present_btn = Style.button("PRESENT!", Vector2(300, 62), 30)
	_present_btn.add_theme_font_override("font", Style.display_font())
	_present_btn.focus_mode = Control.FOCUS_NONE
	_present_btn.size = Vector2(300, 62)
	_present_btn.position = Vector2(106, 396)
	_present_btn.pivot_offset = Vector2(150, 31)
	_present_btn.add_theme_color_override("font_color", NEAR_BLACK)
	_present_btn.add_theme_color_override("font_hover_color", NEAR_BLACK)
	_present_btn.add_theme_color_override("font_pressed_color", NEAR_BLACK)
	_present_btn.add_theme_stylebox_override("normal", _btn_style(Style.YUZU, Color.WHITE, 3, 0.3, 14))
	_present_btn.add_theme_stylebox_override("hover", _btn_style(Style.GOLD, Color.WHITE, 4, 0.3, 14, Color(Style.AQUA, 0.95)))
	_present_btn.add_theme_stylebox_override("pressed", _btn_style(Style.AQUA, Color.WHITE, 4, 0.3, 14))
	_present_btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.30, 0.26, 0.36), Color(0.5, 0.5, 0.55), 2, 0.3, 14))
	_present_btn.pressed.connect(func() -> void: _pick(_sel))
	_present_btn.mouse_entered.connect(func() -> void:
		Audio.sfx("select", 1.3, -10.0)
		_present_btn.create_tween().tween_property(_present_btn, "scale", Vector2.ONE * 1.06, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT))
	_present_btn.mouse_exited.connect(func() -> void:
		_present_btn.create_tween().tween_property(_present_btn, "scale", Vector2.ONE, 0.1))
	_detail.add_child(_present_btn)
	_select_clue(ids[0], false)


func _on_card_input(e: InputEvent, id: String) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
		_select_clue(id, false)
		_pick(id)
		accept_event()


func _select_clue(id: String, sound: bool) -> void:
	if _type != "present" or _done:
		return
	if id == _sel:
		return
	_sel = id
	if sound:
		Audio.sfx("select", 1.0, -6.0)
	for k in _nodes.keys():
		var b: Button = _nodes[k]
		if k == id:
			b.add_theme_stylebox_override("normal", _btn_style(Color(0.24, 0.13, 0.36, 0.98), Style.YUZU, 4, 0.08, 14, Color(Style.AQUA, 0.95)))
			b.add_theme_stylebox_override("hover", _btn_style(Color(0.28, 0.16, 0.44, 0.98), Style.YUZU, 4, 0.08, 14, Color(Style.AQUA, 0.95)))
		else:
			b.add_theme_stylebox_override("normal", _btn_style(CARD_BG, Style.AQUA_DEEP, 2, 0.08))
			b.add_theme_stylebox_override("hover", _btn_style(CARD_HOVER, Style.AQUA, 3, 0.08, 14, Color(Style.AQUA_DEEP, 0.95)))
	for c in _detail_icon_holder.get_children():
		c.queue_free()
	var icon := _clue_icon(id, Vector2(150, 150), 0.5)
	_detail_icon_holder.add_child(icon)
	var nm := Clues.clue_name(id)
	_detail_name.text = nm
	_detail_name.add_theme_font_size_override("font_size", _fit(Style.display_font(), nm, Vector2(480, 40), 28, 18))
	var d := Clues.desc(id)
	_detail_desc.text = d
	_detail_desc.add_theme_font_size_override("font_size", _fit(Style.body_font(), d, _detail_desc.size, 19, 12))
	var crossed := _crossed.has(id)
	_present_btn.disabled = crossed
	_detail.modulate = Color(0.75, 0.72, 0.8) if crossed else Color.WHITE
	_detail_icon_holder.scale = Vector2(0.7, 0.7)
	_detail_icon_holder.rotation = -0.12
	var tw := _detail_icon_holder.create_tween().set_parallel(true)
	tw.tween_property(_detail_icon_holder, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_detail_icon_holder, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Clue icon texture, or a styled "water drop" text card if the art is missing.
func _clue_icon(id: String, sz: Vector2, text_scale: float) -> Control:
	var tex := Assets.clue_icon(id)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = sz
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var c := Control.new()
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var initials := ""
	for word in Clues.clue_name(id).replace("'s", "").split(" ", false):
		if initials.length() < 2 and word.length() > 0 and word[0] != "(":
			initials += word[0].to_upper()
	var hue := float(absi(hash(id)) % 1000) / 1000.0
	var col := Color.from_hsv(0.45 + hue * 0.35, 0.55, 0.95)
	c.draw.connect(_draw_drop.bind(c, col, initials, text_scale))
	return c


func _draw_drop(c: Control, col: Color, initials: String, text_scale: float) -> void:
	var sz := c.size
	var cx := sz.x * 0.5
	var r := sz.x * 0.34
	var cy := sz.y * 0.6
	var pts := PackedVector2Array()
	pts.append(Vector2(cx, cy - r * 1.75))
	for i in 25:
		var a := deg_to_rad(-35.0 + i * (250.0 / 24.0))
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(4, 5))
	c.draw_colored_polygon(shadow, HARD_SHADOW)
	c.draw_colored_polygon(pts, col.darkened(0.15))
	c.draw_circle(Vector2(cx - r * 0.1, cy + r * 0.05), r * 0.82, col)
	c.draw_circle(Vector2(cx - r * 0.42, cy - r * 0.35), r * 0.16, Color(1, 1, 1, 0.75))
	pts.append(pts[0])
	c.draw_polyline(pts, INK, 3.0, true)
	var fs := int(sz.x * text_scale)
	var f := Style.display_font()
	var base := Vector2(0, cy + fs * 0.36)
	c.draw_string_outline(f, base, initials, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, 6, INK)
	c.draw_string(f, base, initials, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, Color.WHITE)


# =================================================================== CHARACTER
func _build_character() -> void:
	_build_prompt(Rect2(40, 84, 1200, 124), true)
	var ex: Array = _data.get("exclude", [])
	var ids: Array[String] = []
	for id in Cast.survivors():
		if not ex.has(id):
			ids.append(str(id))
	if not ids.has(_answer):
		ids.append(_answer)
	var n := ids.size()
	var top := n if n <= 7 else ceili(n / 2.0)
	var gap := 12.0
	var cw := minf(164.0, (1200.0 - (top - 1) * gap) / top)
	var ch := 234.0 if n > 7 else 300.0
	var y0 := 228.0
	for i in n:
		var row := 0 if i < top else 1
		var idx := i if row == 0 else i - top
		var count := top if row == 0 else n - top
		var rw := count * cw + (count - 1) * gap
		var x := (W - rw) * 0.5 + idx * (cw + gap)
		var b := _char_card(ids[i], Vector2(cw, ch))
		b.position = Vector2(x, y0 + row * (ch + gap))
		_stage.add_child(b)
		_keys.append(ids[i])
		_nodes[ids[i]] = b


func _char_card(id: String, sz: Vector2) -> Button:
	var b := Button.new()
	b.size = sz
	b.pivot_offset = Vector2(sz.x * 0.5, sz.y)
	b.focus_mode = Control.FOCUS_ALL
	_style_card(b, 0.0)
	var col := Cast.color(id)
	var face := _head_box(id, "normal", Vector2(sz.x - 12, sz.y - 62), col, 2)
	face.name = "FaceBox"
	face.position = Vector2(6, 6)
	b.add_child(face)
	# slanted name plate
	var plate := Panel.new()
	plate.position = Vector2(8, sz.y - 52)
	plate.size = Vector2(sz.x - 16, 46)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _sb(col.darkened(0.15), Color(1, 1, 1, 0.85), 2, 10, 0.18, Color(0, 0, 0, 0)))
	b.add_child(plate)
	var dark := col.get_luminance() > 0.45
	var nm := Style.label(Cast.display_name(id), 20, NEAR_BLACK if dark else Color.WHITE, true)
	nm.position = Vector2(0, 2)
	nm.size = Vector2(sz.x - 16, 26)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", _fit(Style.display_font(), Cast.display_name(id), Vector2(sz.x - 24, 28), 20, 13))
	plate.add_child(nm)
	var tal := Style.label(Cast.talent(id).replace("Ace ", ""), 12, Color(NEAR_BLACK if dark else Color.WHITE, 0.8))
	tal.position = Vector2(0, 26)
	tal.size = Vector2(sz.x - 16, 16)
	tal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tal.clip_text = true
	plate.add_child(tal)
	# hover caption (full name) shown over the portrait
	var cap := Label.new()
	cap.name = "Caption"
	cap.text = Cast.full_name(id)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	cap.add_theme_font_override("font", Style.display_font())
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", Style.GOLD)
	cap.add_theme_color_override("font_outline_color", NEAR_BLACK)
	cap.add_theme_constant_override("outline_size", 6)
	cap.position = Vector2(8, 8)
	cap.size = Vector2(sz.x - 16, sz.y - 66)
	cap.modulate.a = 0.0
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cap)
	b.pressed.connect(_pick.bind(id))
	b.mouse_entered.connect(_char_hover.bind(b, true))
	b.mouse_exited.connect(_char_hover.bind(b, false))
	b.focus_entered.connect(_char_hover.bind(b, true))
	b.focus_exited.connect(_char_hover.bind(b, false))
	return b


func _char_hover(b: Button, on: bool) -> void:
	if _crossed.has(_key_of(b)) or _done or _solved:
		return
	var cap: Control = b.get_node("Caption")
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "scale", Vector2.ONE * (1.07 if on else 1.0), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(cap, "modulate:a", 1.0 if on else 0.0, 0.1)
	if on:
		b.move_to_front()
		Audio.sfx("select", randf_range(1.1, 1.3), -12.0)


# =================================================================== intro / skills
func _intro() -> void:
	_busy = true
	Audio.sfx("whoosh")
	_kit_wipe(Color(Style.AQUA, 0.22), 0.34)
	if _portrait:
		var px := _portrait.position.x
		_portrait.position.x = px - 300.0
		_portrait.modulate.a = 0.0
		_tw_to(_portrait, "position:x", px, 0.3, 0.04)
		_tw_to(_portrait, "modulate:a", 1.0, 0.16, 0.04)
		_slash.modulate.a = 0.0
		_slash.position = Vector2(-120, 60)
		_tw_to(_slash, "position", Vector2.ZERO, 0.26)
		_tw_to(_slash, "modulate:a", 1.0, 0.18)
		var breathe := _portrait.create_tween().set_loops()
		breathe.tween_property(_portrait, "scale", Vector2(1.0, 1.012), 1.6).set_trans(Tween.TRANS_SINE)
		breathe.tween_property(_portrait, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	if _prompt_panel:
		var pp := _prompt_panel.position
		_prompt_panel.position = pp + Vector2(70, -50)
		_prompt_panel.modulate.a = 0.0
		_tw_to(_prompt_panel, "position", pp, 0.26, 0.06)
		_tw_to(_prompt_panel, "modulate:a", 1.0, 0.16, 0.06)
	if _detail:
		var dp := _detail.position
		_detail.position = dp + Vector2(150, 40)
		_detail.modulate.a = 0.0
		_tw_to(_detail, "position", dp, 0.28, 0.1)
		_tw_to(_detail, "modulate:a", 1.0, 0.2, 0.1)
	for i in _keys.size():
		var n: Control = _nodes[_keys[i]]
		n.modulate.a = 0.0
		var delay := 0.1 + i * (0.05 if _type == "choice" else 0.022)
		var p := n.position
		n.position = p + (Vector2(220, -36) if _type == "choice" else Vector2(26, 44))
		_tw_to(n, "position", p, 0.26, delay)
		_tw_to(n, "modulate:a", 1.0, 0.14, delay)
	await _sleep((0.42 + _keys.size() * (0.05 if _type == "choice" else 0.022)) * _k)
	if Game.has_skill("hypothesis"):
		await _apply_hypothesis()
	_busy = false
	if Game.autotest:
		_autoplay()


func _tw_to(n: Object, prop: String, val: Variant, dur: float, delay: float = 0.0) -> void:
	var tw := create_tween()
	tw.tween_property(n, prop, val, dur * _k).set_delay(delay * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _apply_hypothesis() -> void:
	var wrong: Array[String] = []
	for k in _keys:
		if k != _answer and not _crossed.has(k):
			wrong.append(k)
	if wrong.is_empty():
		return
	var k: String = wrong[randi() % wrong.size()]
	_crossed[k] = "hyp"
	var n: Control = _nodes[k]
	Audio.sfx("poof", 1.1, -4.0)
	var c := n.get_global_rect().get_center()
	_kit_burst(c, Style.VIOLET, 14, 240.0)
	_kit_shards(c, Style.VIOLET.lightened(0.3), 8, 300.0)
	_cross_out(n, Style.VIOLET.lightened(0.2))
	var tag := _kit_tag("HYPOTHESIS: RULED OUT", Style.VIOLET, 14)
	_overlay.add_child(tag)
	if _type == "choice":
		tag.position = n.get_global_rect().position + Vector2(n.size.x - 250, n.size.y * 0.5 - 13)
	else:
		tag.position = n.get_global_rect().position + Vector2(n.size.x * 0.5 - 100, -12)
	tag.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(tag, "modulate:a", 1.0, 0.15 * _k)
	tw.tween_interval(1.6 * _k)
	tw.tween_property(tag, "modulate:a", 0.0, 0.3 * _k)
	tw.tween_callback(tag.queue_free)
	if _type == "present" and _sel == k:
		var sel := _sel
		_sel = ""
		_select_clue(sel, false)
	await _sleep(0.35 * _k)


## Marks a node as ruled out: dim, disable and slash it (a diagonal strike / X).
func _cross_out(n: Control, col: Color) -> void:
	var b := n as Button
	if b:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	n.scale = Vector2.ONE
	var cross := Control.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.set_meta("t", 0.0)
	cross.draw.connect(_draw_cross.bind(cross, col, _type == "choice"))
	n.add_child(cross)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_set_cross_t.bind(cross), 0.0, 1.0, 0.18 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate", Color(0.62, 0.58, 0.68, 0.8), 0.25 * _k)


func _set_cross_t(v: float, cross: Control) -> void:
	cross.set_meta("t", v)
	cross.queue_redraw()


func _draw_cross(cross: Control, col: Color, line_mode: bool) -> void:
	var t: float = cross.get_meta("t", 1.0)
	var sz := cross.size
	if line_mode:
		# one hard slash across the option text
		var a := Vector2(sz.y * 0.5 + 60, sz.y * 0.70)
		var bpt := Vector2(sz.x - 30, sz.y * 0.30)
		var e := a.lerp(bpt, t)
		var nrm := (bpt - a).normalized().orthogonal() * 4.0
		cross.draw_colored_polygon(PackedVector2Array([a + nrm + Vector2(4, 4), e + nrm + Vector2(4, 4), e - nrm + Vector2(4, 4), a - nrm + Vector2(4, 4)]), HARD_SHADOW)
		cross.draw_colored_polygon(PackedVector2Array([a + nrm, e + nrm * 0.4, e - nrm * 0.4, a - nrm]), col)
		return
	var m := minf(sz.x, sz.y) * 0.18
	var p1 := Vector2(m, m)
	var p2 := Vector2(sz.x - m, sz.y - m - 40)
	var p3 := Vector2(sz.x - m, m)
	var p4 := Vector2(m, sz.y - m - 40)
	var t1 := clampf(t * 2.0, 0.0, 1.0)
	var t2 := clampf(t * 2.0 - 1.0, 0.0, 1.0)
	cross.draw_line(p1 + Vector2(4, 4), p1.lerp(p2, t1) + Vector2(4, 4), HARD_SHADOW, 12.0)
	cross.draw_line(p1, p1.lerp(p2, t1), col, 9.0)
	if t2 > 0.0:
		cross.draw_line(p3 + Vector2(4, 4), p3.lerp(p4, t2) + Vector2(4, 4), HARD_SHADOW, 12.0)
		cross.draw_line(p3, p3.lerp(p4, t2), col, 9.0)


# =================================================================== picking
func _pick(key: String) -> void:
	if _busy or _done or key == "" or _reaction != null:
		return
	if _crossed.has(key) or not _nodes.has(key):
		return
	_busy = true
	var n: Control = _nodes[key]
	Audio.sfx("confirm")
	if _type == "present":
		await _present_fly(key)
	else:
		var tw := n.create_tween()
		tw.tween_property(n, "scale", Vector2.ONE * 0.93, 0.05 * _k)
		tw.tween_property(n, "scale", Vector2.ONE * 1.08, 0.12 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await _sleep(0.2 * _k)
	if key == _answer:
		_correct(key)
	else:
		_wrong(key)


var _fly_card: Control = null


## Present: the chosen Truth Drop flies to the centre of the screen.
func _present_fly(id: String) -> void:
	var src: Control = _nodes[id]
	var card := Panel.new()
	card.size = Vector2(300, 330)
	card.pivot_offset = card.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.04, 0.20, 0.98), Style.YUZU, 5, 26, 0.0, Color(Style.AQUA, 0.95), Vector2(10, 10)))
	_kit_stripes(card, Vector2(18, 18), 4, Color(Style.YUZU, 0.6), Vector2(6, 22), 11.0)
	var icon := _clue_icon(id, Vector2(210, 210), 0.5)
	icon.position = Vector2(45, 22)
	card.add_child(icon)
	var nm := Style.title_label(Clues.clue_name(id), 26, Style.GOLD, NEAR_BLACK, 8)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", _fit(Style.display_font(), Clues.clue_name(id), Vector2(276, 80), 26, 16))
	nm.position = Vector2(12, 236)
	nm.size = Vector2(276, 84)
	card.add_child(nm)
	_overlay.add_child(card)
	_fly_card = card
	var from := src.get_global_rect().get_center()
	var to := Vector2(W * 0.5, H * 0.52)
	card.position = from - card.size * 0.5
	card.scale = Vector2(0.35, 0.35)
	card.rotation = -0.35
	Audio.sfx("shoot")
	_kit_speedlines(to, Color(Style.AQUA, 0.55), 0.4, 220.0, 36)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "position", to - card.size * 0.5, 0.24 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.26 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "rotation", -0.04, 0.26 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	_kit_ring(to, Style.AQUA, 260.0, 0.4)
	_kit_splash(to + Vector2(0, 120), 10, 320.0)
	await _sleep(0.26 * _k)


func _correct(key: String) -> void:
	_busy = true
	_solved = true
	var n: Control = _nodes[key]
	var center := n.get_global_rect().get_center()
	if _fly_card:
		center = _fly_card.get_global_rect().get_center()
	Audio.sfx("correct")
	Audio.sfx("break", 1.1, -6.0)
	_kit_impact(center, Style.GOLD)
	Game.reward(Game.REWARD_CHOICE)
	# highlight the right answer, fade the rest
	for k in _keys:
		var other: Control = _nodes[k]
		if k != key:
			var tw0 := create_tween()
			tw0.tween_property(other, "modulate:a", 0.22, 0.2 * _k)
	var b := n as Button
	if b:
		var ml := int(b.size.y * 0.5 + 70) if _type == "choice" else 14
		var sk := 0.22 if _type == "choice" else (0.08 if _type == "present" else 0.0)
		b.add_theme_stylebox_override("normal", _btn_style(Color(0.40, 0.25, 0.05, 0.98), Style.GOLD, 5, sk, ml, Color(Style.AQUA, 0.95)))
		b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))
		b.add_theme_stylebox_override("focus", b.get_theme_stylebox("normal"))
		b.add_theme_color_override("font_color", Color.WHITE)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector2.ONE * 1.14, 0.08 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", Vector2.ONE * 1.05, 0.18 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _type == "character" and n.has_node("FaceBox/Face"):
		var face: TextureRect = n.get_node("FaceBox/Face")
		face.texture = Assets.portrait(key, "shock")
		_kit_jolt(n, 8.0)
	if _portrait:
		_portrait.texture = Assets.portrait(_speaker, "happy")
	var sy := 470.0
	if _type != "choice":
		sy = 612.0 if center.y < 430.0 else 300.0
	await _sleep(0.07 * _k)   # a beat of freeze on the impact before the stamp slams
	_kit_stamp("CORRECT!", Style.GOLD, Vector2(W * 0.5 + 20, sy), 116 if _type == "choice" else 100)
	await _sleep(1.4 * _k)
	_finish()


func _wrong(key: String) -> void:
	_busy = true
	var n: Control = _nodes[key]
	var c := n.get_global_rect().get_center()
	Audio.sfx("wrong")
	Audio.sfx("static", 1.0, -8.0)
	_kit_error(c)
	Game.mistake(Game.PENALTY_CHOICE)
	_crossed[key] = "wrong"
	if _fly_card:
		var card := _fly_card
		_fly_card = null
		card.modulate = Color(1.0, 0.5, 0.55)
		_kit_jolt(card, 14.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "position:y", card.position.y + 280.0, 0.36 * _k).set_delay(0.18 * _k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(card, "rotation", 0.6, 0.36 * _k).set_delay(0.18 * _k)
		tw.tween_property(card, "modulate:a", 0.0, 0.3 * _k).set_delay(0.26 * _k)
		tw.chain().tween_callback(card.queue_free)
	_cross_out(n, Style.DANGER)
	if _type == "present" and _sel == key:
		var sel := _sel
		_sel = ""
		_select_clue(sel, false)
	var mp := Vector2(clampf(c.x, 300.0, W - 300.0), clampf(c.y, 140.0, H - 80.0))
	_kit_stamp("WRONG!", Style.DANGER, mp, 64, 0.32, 4.0)
	await _sleep(0.55 * _k)
	var line: Dictionary = {}
	var wl: Variant = _data.get("wrong", null)
	if typeof(wl) == TYPE_DICTIONARY:
		line = wl
	elif typeof(wl) == TYPE_ARRAY and (wl as Array).size() > 0 and typeof(wl[0]) == TYPE_DICTIONARY:
		line = wl[0]
	if line.is_empty():
		line = {"speaker": _speaker, "expr": "sad", "text": "Hmm... that doesn't seem right. Think it over again."}
	await _show_reaction(line)
	_busy = false


func _finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25 * _k)
	await tw.finished
	finished.emit({})


# =================================================================== wrong-answer reaction line
func _show_reaction(line: Dictionary) -> void:
	var who := str(line.get("speaker", _speaker))
	var expr := str(line.get("expr", "normal"))
	var text := str(line.get("text", "..."))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(root)
	_reaction = root
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(NEAR_BLACK, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var col := Cast.color(who) if Cast.exists(who) else Style.AQUA
	var slash := Control.new()
	slash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.draw.connect(func() -> void:
		slash.draw_colored_polygon(PackedVector2Array([Vector2(W - 300, 120), Vector2(W - 120, 120), Vector2(W - 330, H), Vector2(W - 510, H)]), Color(col, 0.30))
		slash.draw_colored_polygon(PackedVector2Array([Vector2(W - 104, 120), Vector2(W - 88, 120), Vector2(W - 298, H), Vector2(W - 314, H)]), Color(Style.DANGER, 0.6)))
	root.add_child(slash)
	var por := TextureRect.new()
	por.texture = Assets.portrait(who, expr)
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	por.size = Vector2(456, 570)
	por.position = Vector2(W + 20, H - 570)
	por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(por)
	var box := Panel.new()
	box.position = Vector2(40, 540)
	box.size = Vector2(840, 160)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.025, 0.12, 0.97), col, 3, 20, 0.05, HARD_SHADOW, Vector2(9, 9)))
	root.add_child(box)
	_kit_stripes(box, Vector2(740, 12), 5, Color(col, 0.5), Vector2(5, 16), 10.0)
	var tag := _name_tag(who)
	tag.position = Vector2(64, 520)
	root.add_child(tag)
	_react_text = RichTextLabel.new()
	_react_text.bbcode_enabled = true
	_react_text.scroll_active = false
	_react_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_react_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_react_text.position = Vector2(28, 32)
	_react_text.size = Vector2(784, 104)
	var fs := _fit(Style.body_font(), text, _react_text.size, 25, 15)
	_react_text.add_theme_font_size_override("normal_font_size", fs)
	_react_text.add_theme_font_size_override("bold_font_size", fs)
	_react_text.text = Style.markup(text)
	_react_text.visible_ratio = 0.0
	box.add_child(_react_text)
	var more := Style.label("click to continue  ▼", 14, Style.YUZU)
	more.position = Vector2(620, 134)
	more.size = Vector2(196, 20)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(more)
	root.gui_input.connect(_on_reaction_input)
	root.modulate.a = 0.0
	box.position.x -= 60.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.12 * _k)
	tw.tween_property(box, "position:x", 40.0, 0.22 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(por, "position:x", W - 456 - 10, 0.24 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if expr == "shock" or expr == "angry":
		tw.chain().tween_callback(_kit_jolt.bind(por, 10.0))
	var pitch := Cast.pitch(who)
	var chars := text.length()
	_react_tw = create_tween()
	_react_tw.tween_method(_react_type.bind(pitch, chars), 0.0, 1.0, maxf(0.3, chars / (46.0 * maxf(Game.text_speed, 0.1))) * _k)
	if Game.autotest:
		_auto_close_reaction()
	await _reaction_closed
	_reaction = null
	var tw2 := create_tween()
	tw2.tween_property(root, "modulate:a", 0.0, 0.15 * _k)
	tw2.tween_callback(root.queue_free)
	await tw2.finished


func _react_type(v: float, pitch: float, chars: int) -> void:
	if _react_text == null or not is_instance_valid(_react_text):
		return
	if int(v * chars) != int(_react_text.visible_ratio * chars) and not Game.autotest:
		Audio.blip(pitch)
	_react_text.visible_ratio = v


func _auto_close_reaction() -> void:
	await _sleep(1.6 if Game.autotest_slow else 0.15)
	_reaction_click()
	await _sleep(0.05)
	_reaction_click()


func _on_reaction_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_reaction_click()
		accept_event()


func _reaction_click() -> void:
	if _reaction == null:
		return
	if _react_text and _react_text.visible_ratio < 1.0:
		if _react_tw:
			_react_tw.kill()
		_react_text.visible_ratio = 1.0
		return
	_reaction_closed.emit()


# =================================================================== input
func _input(e: InputEvent) -> void:
	# Present: Enter/Space presents the selected Truth Drop (before a focused card can eat it).
	if _type != "present" or _done or _busy or _reaction != null:
		return
	var k := e as InputEventKey
	if k and k.pressed and not k.echo and k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		_pick(_sel)


func _unhandled_input(e: InputEvent) -> void:
	if _done:
		return
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if _reaction != null:
		if k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z]:
			_reaction_click()
			get_viewport().set_input_as_handled()
		return
	if _busy:
		return
	if _type == "choice":
		var idx := -1
		if k.keycode >= KEY_1 and k.keycode <= KEY_9:
			idx = k.keycode - KEY_1
		elif k.keycode >= KEY_KP_1 and k.keycode <= KEY_KP_9:
			idx = k.keycode - KEY_KP_1
		if idx >= 0 and idx < _keys.size():
			get_viewport().set_input_as_handled()
			_pick(_keys[idx])
			return
	if k.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or not is_ancestor_of(focus):
			var start := _sel if _type == "present" and _sel != "" else ""
			for key in _keys:
				if not _crossed.has(key) and (start == "" or key == start):
					(_nodes[key] as Control).grab_focus()
					break
			get_viewport().set_input_as_handled()


# =================================================================== autotest
func _autoplay() -> void:
	await _sleep(0.9 if Game.autotest_slow else 0.3)
	if _auto_wrong:
		for key in _keys:
			if key != _answer and not _crossed.has(key):
				if _type == "present":
					_select_clue(key, false)
				_pick(key)
				break
		await _sleep(0.1)
		while _busy and not _done:
			await _sleep(0.05)
	if _done:
		return
	if _type == "present":
		_select_clue(_answer, true)
		await _sleep(0.6 if Game.autotest_slow else 0.1)
	_pick(_answer)


# =================================================================== frame
func _sleep(t: float) -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(t, 0.001))
	await tw.finished


func _process(delta: float) -> void:
	_time += delta
	_kit_tick(delta)

# =================================================================== SHARP KIT
# Shared visual kit (identical copy in choice.gd, bubbles.gd, rewind.gd and vote.gd so every file
# stays self-contained): angular styleboxes, night backdrop + vignette, slanted title badge, glitch
# shader, flash, screen shake, particles (shards, water drops, stars, rings), speed lines, diagonal
# wipes, the slam stamp and a screen shatter. The host script provides _k, _stage, _fx and _overlay,
# connects _fx.draw to _kit_draw and calls _kit_tick(delta) from _process.

const NIGHT := Color("120a24")
const NEAR_BLACK := Color("07040f")
const HARD_SHADOW := Color(0.027, 0.016, 0.059, 0.92)
const GLITCH_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform float seed = 0.0;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(seed * 24.0);
	float band = floor(uv.y * 22.0 + rnd(vec2(t, 3.0)) * 5.0);
	float r = rnd(vec2(band, t));
	float shift = r > 0.7 ? (rnd(vec2(t, band)) - 0.5) * 0.09 * amount : 0.0;
	shift += (rnd(vec2(floor(uv.y * 150.0), t)) - 0.5) * 0.007 * amount;
	uv.x += shift;
	float sp = 0.009 * amount;
	vec3 col = vec3(texture(screen_tex, uv + vec2(sp, 0.0)).r, texture(screen_tex, uv).g, texture(screen_tex, uv - vec2(sp, 0.0)).b);
	col *= 1.0 - 0.24 * amount * step(0.5, fract(FRAGCOORD.y * 0.5));
	col = mix(col, vec3(rnd(uv * 517.0 + t)), 0.09 * amount);
	col = mix(col, vec3(1.0, 0.31, 0.43), 0.24 * amount * step(0.86, r));
	COLOR = vec4(col, 1.0);
}
"""

static var _kit_shader: Shader = null
static var _kit_vig: GradientTexture2D = null

var _kit_parts: Array = []
var _kit_lines: Array = []
var _kit_time := 0.0
var _kit_glitch_rect: ColorRect = null
var _kit_flash_rect: ColorRect = null
var _kit_flash_tw: Tween = null
var _kit_glitch_left := 0.0
var _kit_glitch_len := 0.3
var _kit_glitch_peak := 0.0
var _kit_shake_left := 0.0
var _kit_shake_len := 0.3
var _kit_shake_amt := 0.0


## Angular stylebox: chamfered top-left / bottom-right corners, optional skew, hard offset shadow.
func _sb(bg: Color, border: Color, bw: int = 3, cut: int = 14, skew: float = 0.0,
		shadow: Color = HARD_SHADOW, shadow_off: Vector2 = Vector2(7, 7)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.corner_detail = 1
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_radius_top_right = 0
	s.corner_radius_bottom_left = 0
	s.skew = Vector2(skew, 0.0)
	if shadow.a > 0.0:
		s.shadow_color = shadow
		s.shadow_size = 1
		s.shadow_offset = shadow_off
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.anti_aliasing = true
	return s


## Parallelogram (top edge shifted right by s) with chamfered top-left / bottom-right corners.
func _kit_quad(w: float, h: float, s: float, cut: float) -> PackedVector2Array:
	var a := Vector2(s, 0)
	var b := Vector2(w, 0)
	var c := Vector2(w - s, h)
	var d := Vector2(0, h)
	if cut <= 0.0:
		return PackedVector2Array([a, b, c, d])
	return PackedVector2Array([a + (b - a).normalized() * cut, b, c + (b - c).normalized() * cut,
		c + (d - c).normalized() * cut, d, a + (d - a).normalized() * cut])


## Semi-transparent night backdrop (lets the courtroom behind show through) + vignette + slashes.
func _kit_backdrop(alpha: float, accent: Color = Style.AQUA) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_kit_draw_backdrop.bind(c, alpha, accent))
	add_child(c)
	if _kit_vig == null:
		var g := Gradient.new()
		g.set_color(0, Color(NEAR_BLACK, 0.0))
		g.set_color(1, Color(NEAR_BLACK, 0.88))
		g.add_point(0.5, Color(NEAR_BLACK, 0.08))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.02, 1.02)
		gt.width = 256
		gt.height = 144
		_kit_vig = gt
	var vg := TextureRect.new()
	vg.texture = _kit_vig
	vg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(vg)
	return c


func _kit_draw_backdrop(c: Control, alpha: float, accent: Color) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(NIGHT, alpha))
	# two big diagonal slash bands
	c.draw_colored_polygon(PackedVector2Array([Vector2(-60, H), Vector2(380, 90), Vector2(470, 90), Vector2(30, H)]), Color(Style.VIOLET, 0.07))
	c.draw_colored_polygon(PackedVector2Array([Vector2(W - 330, H), Vector2(W + 40, 250), Vector2(W + 40, 300), Vector2(W - 280, H)]), Color(accent, 0.05))
	# stripe accents in the bottom corners
	for i in 7:
		var x := 18.0 + i * 20.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 44, H - 66), Vector2(x + 54, H - 66), Vector2(x + 10, H), Vector2(x, H)]), Color(accent, 0.13))
	for i in 7:
		var x := W - 170.0 + i * 20.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 44, H - 66), Vector2(x + 54, H - 66), Vector2(x + 10, H), Vector2(x, H)]), Color(Style.YUZU, 0.10))
	# hairline frame
	c.draw_line(Vector2(0, H - 3), Vector2(W, H - 3), Color(accent, 0.25), 2.0)


## Glitch overlay + flash, added last so they sit above everything the minigame draws.
func _kit_top_layers() -> void:
	if _kit_shader == null:
		_kit_shader = Shader.new()
		_kit_shader.code = GLITCH_CODE
	_kit_glitch_rect = ColorRect.new()
	_kit_glitch_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_kit_glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _kit_shader
	_kit_glitch_rect.material = m
	_kit_glitch_rect.visible = false
	add_child(_kit_glitch_rect)
	_kit_flash_rect = ColorRect.new()
	_kit_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_kit_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kit_flash_rect.color = Color.WHITE
	_kit_flash_rect.modulate.a = 0.0
	add_child(_kit_flash_rect)


func _kit_flash(col: Color, alpha: float = 0.6, dur: float = 0.35) -> void:
	if _kit_flash_rect == null:
		return
	if _kit_flash_tw and _kit_flash_tw.is_valid():
		_kit_flash_tw.kill()
	_kit_flash_rect.color = col
	_kit_flash_rect.modulate.a = alpha
	_kit_flash_tw = create_tween()
	_kit_flash_tw.tween_property(_kit_flash_rect, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _kit_glitch(dur: float = 0.3, amt: float = 1.0) -> void:
	if _kit_glitch_rect == null or Game.autotest and not Game.autotest_slow:
		return
	_kit_glitch_peak = maxf(_kit_glitch_peak if _kit_glitch_left > 0.0 else 0.0, amt)
	_kit_glitch_len = maxf(dur, 0.05)
	_kit_glitch_left = _kit_glitch_len
	_kit_glitch_rect.visible = true


func _kit_shake(s: float = 12.0, dur: float = 0.3) -> void:
	_kit_shake_amt = maxf(_kit_shake_amt if _kit_shake_left > 0.0 else 0.0, s)
	_kit_shake_len = maxf(dur, 0.05)
	_kit_shake_left = _kit_shake_len


## Quick tween shake of a single node (restores its position).
func _kit_jolt(n: Control, s: float = 10.0) -> void:
	if n == null or not is_instance_valid(n) or n.has_meta("jolt"):
		return
	var base := n.position
	n.set_meta("jolt", true)
	var tw := n.create_tween()
	for i in 6:
		tw.tween_property(n, "position", base + Vector2(randf_range(-s, s), randf_range(-s, s) * 0.5), 0.03)
	tw.tween_property(n, "position", base, 0.04)
	tw.tween_callback(n.remove_meta.bind("jolt"))


## Slanted title badge (top-left, stays left of the Convince Meter strip) with a diagonal wipe in.
func _kit_badge(title: String, sub: String = "SPLASH TRIAL") -> Control:
	var root := Control.new()
	root.position = Vector2(26, 12)
	root.size = Vector2(336, 56)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(root)
	var p := Panel.new()
	p.size = root.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _sb(Color(0.15, 0.06, 0.30, 0.98), Style.GOLD, 3, 12, 0.36, Color(Style.AQUA_DEEP, 0.95), Vector2(7, 6)))
	root.add_child(p)
	var accent := Control.new()
	accent.size = root.size
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.draw.connect(func() -> void:
		for i in 3:
			var x := 16.0 + i * 11.0
			accent.draw_colored_polygon(PackedVector2Array([Vector2(x + 14, 9), Vector2(x + 20, 9), Vector2(x + 6, 47), Vector2(x, 47)]), Color(Style.YUZU, 0.95 - i * 0.25))
		accent.draw_rect(Rect2(66, 21, 214, 2), Color(Style.AQUA, 0.35)))
	root.add_child(accent)
	var sl := Style.label(sub, 11, Style.AQUA, true)
	sl.position = Vector2(60, 4)
	sl.size = Vector2(260, 16)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sl)
	var fs := 27
	while fs > 16 and Style.display_font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 262.0:
		fs -= 1
	var t := Style.title_label(title, fs, Style.GOLD, NEAR_BLACK, 7)
	t.position = Vector2(58, 17)
	t.size = Vector2(268, 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(t)
	root.position = Vector2(-420, -40)
	var tw := create_tween()
	tw.tween_property(root, "position", Vector2(26, 12), 0.28 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return root


## Diagonal stripe accent (n slanted bars) added to parent.
func _kit_stripes(parent: Control, pos: Vector2, n: int, col: Color, bar: Vector2 = Vector2(7, 30), gap: float = 11.0) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = Vector2(n * gap + bar.x + bar.y * 0.45, bar.y)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		for i in n:
			var x := i * gap
			var s := bar.y * 0.45
			c.draw_colored_polygon(PackedVector2Array([Vector2(x + s, 0), Vector2(x + s + bar.x, 0), Vector2(x + bar.x, bar.y), Vector2(x, bar.y)]), col))
	parent.add_child(c)
	return c


## Slanted name tag in the character's colour.
func _kit_tag(text: String, col: Color, font_size: int = 22) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := _sb(col, Color.WHITE, 2, 8, 0.32, HARD_SHADOW, Vector2(4, 4))
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	tag.add_theme_stylebox_override("panel", st)
	tag.add_child(Style.label(text, font_size, NEAR_BLACK if col.get_luminance() > 0.45 else Color.WHITE, true))
	return tag


# ------------------------------------------------------------------ particles & lines
func _kit_add(kind: String, p: Vector2, v: Vector2, life: float, col: Color, size: float, g: float = 260.0, drag: float = 2.2) -> void:
	_kit_parts.append({"k": kind, "p": p, "v": v, "t": 0.0, "max": life, "c": col, "s": size,
		"r": randf() * TAU, "w": randf_range(-10.0, 10.0), "g": g, "d": drag})


func _kit_burst(pos: Vector2, col: Color, n: int = 18, spd: float = 360.0, star: bool = true) -> void:
	for i in n:
		var a := randf() * TAU
		_kit_add("star" if star else "dot", pos, Vector2.from_angle(a) * spd * randf_range(0.35, 1.0),
			randf_range(0.4, 0.8), col, randf_range(5.0, 12.0))


## Angular glassy shards flying out of an impact point.
func _kit_shards(pos: Vector2, col: Color, n: int = 16, spd: float = 560.0) -> void:
	for i in n:
		var a := randf() * TAU
		var c := col if i % 3 != 0 else (Color.WHITE if i % 2 == 0 else Style.AQUA)
		_kit_add("shard", pos + Vector2.from_angle(a) * randf_range(0.0, 18.0), Vector2.from_angle(a) * spd * randf_range(0.4, 1.0),
			randf_range(0.45, 0.8), c, randf_range(9.0, 22.0), 520.0, 2.6)


## Water droplets (teardrops stretched along their velocity) - hot-spring splash.
func _kit_splash(pos: Vector2, n: int = 14, spd: float = 380.0, col: Color = Color(0.78, 1.0, 1.0, 0.95)) -> void:
	for i in n:
		var a := -PI * 0.5 + randf_range(-1.35, 1.35)
		_kit_add("drop", pos, Vector2.from_angle(a) * spd * randf_range(0.45, 1.0), randf_range(0.45, 0.75), col, randf_range(5.0, 10.0), 900.0, 1.2)


func _kit_ring(pos: Vector2, col: Color, radius: float, dur: float = 0.45) -> void:
	_kit_add("ring", pos, Vector2.ZERO, dur, col, radius, 0.0, 0.0)


## Radial speed lines converging on center.
func _kit_speedlines(center: Vector2, col: Color, dur: float = 0.5, inner: float = 170.0, n: int = 44) -> void:
	_kit_lines.append({"m": "radial", "c": center, "col": col, "t": 0.0, "max": dur, "r0": inner, "n": n, "seed": randi() % 997})


## Horizontal speed streaks inside rect (for fast slides / scrolling strips).
func _kit_hlines(rect: Rect2, col: Color, dur: float = 0.5, n: int = 18) -> void:
	_kit_lines.append({"m": "horiz", "c": rect.position, "sz": rect.size, "col": col, "t": 0.0, "max": dur, "n": n, "seed": randi() % 997})


## A slanted colour band sweeping diagonally across the screen (entrances / transitions).
func _kit_wipe(col: Color, dur: float = 0.32, col2: Color = Style.YUZU) -> void:
	_kit_lines.append({"m": "wipe", "col": col, "col2": col2, "t": 0.0, "max": maxf(dur * _k, 0.05), "seed": 0})


## Impact combo for big CORRECT moments: white flash, ring, shards, splash, speed lines, shake.
func _kit_impact(pos: Vector2, col: Color = Style.GOLD) -> void:
	_kit_flash(Color(1.0, 0.97, 0.85), 0.85, 0.32)
	_kit_ring(pos, col, 320.0, 0.45)
	_kit_ring(pos, Style.AQUA, 200.0, 0.35)
	_kit_shards(pos, col, 22, 640.0)
	_kit_splash(pos, 16, 460.0)
	_kit_speedlines(pos, Color(1.0, 0.96, 0.85, 0.75), 0.55, 190.0)
	_kit_shake(13.0, 0.32)


## Error combo for WRONG answers: glitch jitter + coral flash + shake + coral shards.
func _kit_error(pos: Vector2) -> void:
	_kit_glitch(0.32, 1.0)
	_kit_flash(Style.DANGER, 0.42, 0.4)
	_kit_shake(15.0, 0.3)
	_kit_shards(pos, Style.DANGER, 10, 380.0)


func _kit_hash(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + 4.1414) * 43758.5453, 1.0)


func _kit_tick(delta: float) -> void:
	_kit_time += delta
	if _kit_shake_left > 0.0:
		_kit_shake_left -= delta
		var f := clampf(_kit_shake_left / _kit_shake_len, 0.0, 1.0)
		var a := _kit_shake_amt * f * f
		_stage.position = Vector2(randf_range(-a, a), randf_range(-a, a) * 0.6)
		if _kit_shake_left <= 0.0:
			_stage.position = Vector2.ZERO
			_kit_shake_amt = 0.0
	if _kit_glitch_left > 0.0 and _kit_glitch_rect:
		_kit_glitch_left -= delta
		var gm := _kit_glitch_rect.material as ShaderMaterial
		gm.set_shader_parameter("amount", _kit_glitch_peak * clampf(_kit_glitch_left / _kit_glitch_len, 0.0, 1.0) * randf_range(0.5, 1.0))
		gm.set_shader_parameter("seed", _kit_time)
		if _kit_glitch_left <= 0.0:
			_kit_glitch_rect.visible = false
			_kit_glitch_peak = 0.0
	var busy := not _kit_parts.is_empty() or not _kit_lines.is_empty()
	var n := _kit_parts.size()
	var i := 0
	while i < n:
		var p: Dictionary = _kit_parts[i]
		var t: float = float(p["t"]) + delta
		if t >= float(p["max"]):
			_kit_parts[i] = _kit_parts[n - 1]
			n -= 1
			continue
		p["t"] = t
		var v: Vector2 = p["v"]
		p["p"] = (p["p"] as Vector2) + v * delta
		p["v"] = v * maxf(0.0, 1.0 - float(p["d"]) * delta) + Vector2(0, float(p["g"]) * delta)
		p["r"] = float(p["r"]) + float(p["w"]) * delta
		i += 1
	_kit_parts.resize(n)
	n = _kit_lines.size()
	i = 0
	while i < n:
		var l: Dictionary = _kit_lines[i]
		l["t"] = float(l["t"]) + delta
		if float(l["t"]) >= float(l["max"]):
			_kit_lines[i] = _kit_lines[n - 1]
			n -= 1
			continue
		i += 1
	_kit_lines.resize(n)
	if busy:
		_fx.queue_redraw()


func _kit_draw() -> void:
	for l in _kit_lines:
		_kit_draw_line_fx(l)
	for p in _kit_parts:
		var t: float = float(p["t"]) / float(p["max"])
		var c: Color = p["c"]
		var pos: Vector2 = p["p"]
		var s: float = p["s"]
		var rot: float = p["r"]
		match str(p["k"]):
			"ring":
				c.a *= 1.0 - t
				var e := 1.0 - (1.0 - t) * (1.0 - t)
				_fx.draw_arc(pos, s * (0.2 + 0.8 * e), 0.0, TAU, 48, c, 12.0 * (1.0 - t) + 2.0, true)
			"shard":
				c.a *= 1.0 - t * t
				var k := s * (1.0 - t * 0.4)
				_fx.draw_colored_polygon(PackedVector2Array([pos + Vector2.from_angle(rot) * k,
					pos + Vector2.from_angle(rot + 2.25) * k * 0.45, pos + Vector2.from_angle(rot + 3.8) * k * 0.75]), c)
			"drop":
				c.a *= 1.0 - t
				var v: Vector2 = p["v"]
				var dir := v.normalized() if v.length_squared() > 1.0 else Vector2.DOWN
				var r := s * 0.5 * (1.0 - t * 0.4)
				var tail := clampf(v.length() * 0.035, r * 1.5, r * 5.0)
				var side := Vector2(-dir.y, dir.x) * r
				_fx.draw_colored_polygon(PackedVector2Array([pos - dir * tail, pos + side, pos - side]), c)
				_fx.draw_circle(pos, r, c)
			"star":
				c.a *= 1.0 - t * t
				var pts := PackedVector2Array()
				for j in 8:
					pts.append(pos + Vector2.from_angle(rot + j * TAU / 8.0) * s * (1.0 - t * 0.5) * (1.0 if j % 2 == 0 else 0.38))
				_fx.draw_colored_polygon(pts, c)
			_:
				c.a *= 1.0 - t
				_fx.draw_circle(pos, s * 0.6 * (1.0 - t * 0.5), c)


func _kit_draw_line_fx(l: Dictionary) -> void:
	var t: float = float(l["t"]) / float(l["max"])
	var col: Color = l["col"]
	var sd: int = l["seed"]
	var frame := int(_kit_time * 30.0)
	match str(l["m"]):
		"radial":
			var c: Vector2 = l["c"]
			var n: int = l["n"]
			var r0: float = l["r0"]
			for i in n:
				var h := _kit_hash(sd + i * 13 + frame * 7)
				var h2 := _kit_hash(sd * 3 + i * 31 + frame * 11)
				var a := (i + h * 0.8) * TAU / n
				var rr := r0 * (0.75 + h2 * 0.7) * (1.0 + t * 0.25)
				var wd := 0.005 + 0.012 * h
				var cc := col
				cc.a *= (1.0 - t) * (0.45 + 0.55 * h2)
				_fx.draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * rr,
					c + Vector2.from_angle(a - wd) * 1600.0, c + Vector2.from_angle(a + wd) * 1600.0]), cc)
		"horiz":
			var o: Vector2 = l["c"]
			var sz: Vector2 = l["sz"]
			var n2: int = l["n"]
			for i in n2:
				var h := _kit_hash(sd + i * 17 + frame * 5)
				var h2 := _kit_hash(sd + i * 29 + frame * 3)
				var y := o.y + _kit_hash(sd + i * 7) * sz.y
				var ln := 80.0 + h * 320.0
				var x := o.x + h2 * (sz.x + ln) - ln
				var cc := col
				cc.a *= (1.0 - t) * (0.35 + 0.65 * h)
				_fx.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + ln, y - 1.5 - h * 2.0), Vector2(x + ln, y + 1.5 + h * 2.0)]), cc)
		"wipe":
			var e := 1.0 - pow(1.0 - t, 3.0)
			var bw := 520.0
			var x0 := -bw - 420.0 + e * (W + bw * 2.0 + 840.0)
			var col2: Color = l["col2"]
			col.a *= 1.0 - t * 0.6
			col2.a *= 1.0 - t * 0.6
			_fx.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 420, 0), Vector2(x0 + 420 + bw, 0), Vector2(x0 + bw, H), Vector2(x0, H)]), col)
			_fx.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 420 - 46, 0), Vector2(x0 + 420 - 20, 0), Vector2(x0 - 20, H), Vector2(x0 - 46, H)]), col2)


# ------------------------------------------------------------------ slam stamp
## A slanted, chamfered banner that slams down (scale-in), freezes a beat, then shakes + bursts.
func _kit_stamp(text: String, col: Color, pos: Vector2, size: int = 110, hold: float = -1.0, rot_deg: float = -5.0) -> Control:
	pos = Vector2(clampf(pos.x, 220.0, W - 220.0), clampf(pos.y, 80.0 + size * 0.7, H - size * 0.7))
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = pos
	holder.rotation = deg_to_rad(rot_deg)
	_overlay.add_child(holder)
	var font := Style.display_font()
	var fs := size
	var tw_ := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw_ > 980.0 and fs > 28:
		fs -= 3
		tw_ = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bh := fs * 1.32
	var bw := tw_ + bh * 0.9 + 90.0
	# thin full-width slash lines behind the band
	var lines := Control.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.draw.connect(func() -> void:
		lines.draw_rect(Rect2(-900, -bh * 0.5 - 14, 1800, 4), Color(col, 0.85))
		lines.draw_rect(Rect2(-900, bh * 0.5 + 10, 1800, 4), Color(Style.AQUA, 0.7)))
	holder.add_child(lines)
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = Vector2(-bw * 0.5, -bh * 0.5)
	band.size = Vector2(bw, bh)
	band.draw.connect(_kit_draw_band.bind(band, col))
	holder.add_child(band)
	var l := Style.title_label(text, fs, col, NEAR_BLACK, maxi(8, int(fs / 6.0)))
	l.size = Vector2(bw, bh)
	l.position = Vector2(-bw * 0.5, -bh * 0.5 - fs * 0.02)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	holder.scale = Vector2(2.7, 2.7)
	holder.modulate.a = 0.0
	lines.scale = Vector2(0.0, 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(holder, "scale", Vector2.ONE, 0.13 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(holder, "modulate:a", 1.0, 0.07 * _k)
	var punch := clampf(size / 110.0, 0.3, 1.2)
	tw.chain().tween_callback(func() -> void:
		_kit_shake(11.0 * punch, 0.28)
		_kit_shards(pos, col, int(14 * punch), 620.0 * punch)
		_kit_flash(col.lerp(Color.WHITE, 0.6), 0.3 * punch, 0.18))
	tw.tween_property(lines, "scale:x", 1.0, 0.18 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "scale", Vector2(1.05, 1.05), 0.05 * _k).set_delay(0.06 * _k)
	tw.chain().tween_property(holder, "scale", Vector2.ONE, 0.12 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.chain().tween_interval(hold * _k)
		tw.chain().tween_property(holder, "modulate:a", 0.0, 0.2 * _k)
		tw.chain().tween_callback(holder.queue_free)
	return holder


func _kit_draw_band(c: Control, col: Color) -> void:
	var w := c.size.x
	var h := c.size.y
	var pts := _kit_quad(w, h, h * 0.42, h * 0.26)
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(10, 9))
	c.draw_colored_polygon(sh, Color(NEAR_BLACK, 0.92))
	c.draw_colored_polygon(pts, Color(0.10, 0.04, 0.20, 0.97))
	for i in 3:
		var x := h * 0.42 + 12.0 + i * 14.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 10, 6), Vector2(x + 17, 6), Vector2(x + 7 - h * 0.3, h - 6), Vector2(x - h * 0.3, h - 6)]), Color(col, 0.5 - i * 0.13))
	var o := pts.duplicate()
	o.append(pts[0])
	c.draw_polyline(o, col, 5.0, true)


# ------------------------------------------------------------------ screen shatter
## Captures the screen and blows it apart into textured shards (skipped headless / in fast autotest).
## Call it, then swap what is behind before the shards clear.
func _kit_shatter(center: Vector2, cols: int = 7, rows: int = 4, dur: float = 0.6) -> void:
	if DisplayServer.get_name() == "headless" or (Game.autotest and not Game.autotest_slow):
		return
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	var tex := ImageTexture.create_from_image(img)
	var uvk := Vector2(img.get_width() / W, img.get_height() / H)
	var grid: Array[Vector2] = []
	for y in rows + 1:
		for x in cols + 1:
			var p := Vector2(x * W / cols, y * H / rows)
			if x > 0 and x < cols:
				p.x += randf_range(-0.32, 0.32) * W / cols
			if y > 0 and y < rows:
				p.y += randf_range(-0.32, 0.32) * H / rows
			grid.append(p)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(holder)
	for y in rows:
		for x in cols:
			var a := grid[y * (cols + 1) + x]
			var b := grid[y * (cols + 1) + x + 1]
			var c := grid[(y + 1) * (cols + 1) + x + 1]
			var d := grid[(y + 1) * (cols + 1) + x]
			var tris: Array = [[a, b, c], [a, c, d]] if (x + y) % 2 == 0 else [[a, b, d], [b, c, d]]
			for tri in tris:
				var cen: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
				var poly := Polygon2D.new()
				poly.texture = tex
				poly.position = cen
				poly.polygon = PackedVector2Array([tri[0] - cen, tri[1] - cen, tri[2] - cen])
				poly.uv = PackedVector2Array([tri[0] * uvk, tri[1] * uvk, tri[2] * uvk])
				holder.add_child(poly)
				var dir := (cen - center).normalized()
				var dist := randf_range(180.0, 520.0)
				var st := create_tween().set_parallel(true)
				st.tween_property(poly, "position", cen + dir * dist + Vector2(0, randf_range(160.0, 420.0)), dur).set_delay(randf_range(0.0, 0.08)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				st.tween_property(poly, "rotation", randf_range(-2.4, 2.4), dur)
				st.tween_property(poly, "scale", Vector2.ONE * randf_range(0.5, 0.85), dur)
				st.tween_property(poly, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
	var ht := create_tween()
	ht.tween_interval(dur + 0.15)
	ht.tween_callback(holder.queue_free)
