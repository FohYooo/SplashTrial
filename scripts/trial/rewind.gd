extends Control
## CASE REWIND - rebuild the crime as a comic strip. Each panel: a sepia mini-scene, a caption with a
## blank, and options to fill it (REWARD_REWIND_PANEL / PENALTY_REWIND, retry until right). Afterwards
## the finished strip slides by, then the finale line with the culprit's shocked portrait (REWARD_REWIND).
## data: title, panels [{caption with ___, options, answer, bg}], culprit, finale.
## A panel with "jam": true is the one that doesn't fit: whatever is picked (no cost), the reel stops there, with no replay
## and no finale, and the minigame ends with the flag rewind_jammed so the next segment takes over.
## Skill "artists_eye": one wrong option per panel is crossed out. Contract: docs/ARCHITECTURE.md section 5.
## Look: angular "sharp kit" (see the SHARP KIT section at the end of this file); slanted comic panels
## are masked with clip_children.

signal finished(result: Dictionary)
signal _clicked

const Style := preload("res://scripts/ui/style.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Cast := preload("res://scripts/data/cast.gd")

const W := 1280.0
const H := 720.0
const INK := Color("2a1a10")
const CREAM := Color("fff1cf")
const SEPIA := Color(0.86, 0.70, 0.52)
const PANEL_RECT := Rect2(140, 86, 1000, 352)
const CAPTION_RECT := Rect2(140, 456, 1000, 100)
const BLANK_BB := "[bgcolor=#2a1a10][color=#ffd166][b]  ? ? ?  [/b][/color][/bgcolor]"

var _data := {}
var _panels: Array = []
var _culprit := "wisp"
var _idx := 0
var _filled: Array[String] = []
var _done := false
var _busy := true
var _k := 1.0
var _auto_wrong := false
var _time := 0.0
var _wait_click := false
var _result := {}

var _stage: Control
var _fx: Control
var _overlay: Control
var _badge: Control
var _thumbs: Array[Panel] = []

var _page: Control              # current panel + caption + options
var _panel_node: Control
var _caption: RichTextLabel
var _opt_buttons: Array[Button] = []
var _crossed := {}              # option index -> true
var _rays: Control
var _ray_col := Color.WHITE
var _ray_center := Vector2(W - 270, 330)


# =================================================================== setup
func setup(data: Dictionary) -> void:
	_data = data
	_panels = data.get("panels", [])
	_culprit = str(data.get("culprit", "wisp"))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_k = 0.12 if Game.autotest and not Game.autotest_slow else 1.0
	_auto_wrong = Game.autotest and Game.debug_minigame != ""
	_kit_backdrop(0.56)
	_stage = _layer()
	_fx = _layer()
	_fx.draw.connect(_kit_draw)
	_overlay = _layer()
	_kit_top_layers()
	_badge = _kit_badge(str(_data.get("title", "CASE REWIND")))
	_build_thumbs()
	_run()


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _wait_click:
		_clicked.emit()
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if _done:
		return
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if _wait_click and k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z]:
		_clicked.emit()
		get_viewport().set_input_as_handled()
		return
	if _busy:
		return
	var i := -1
	if k.keycode >= KEY_1 and k.keycode <= KEY_9:
		i = k.keycode - KEY_1
	elif k.keycode >= KEY_KP_1 and k.keycode <= KEY_KP_9:
		i = k.keycode - KEY_KP_1
	if i >= 0 and i < _opt_buttons.size():
		get_viewport().set_input_as_handled()
		_choose(i)


## Waits for a click / key (or auto_after seconds; autotest skips almost at once).
func _await_click(auto_after: float = -1.0) -> void:
	if Game.autotest:
		await _sleep(1.2 if Game.autotest_slow else 0.1)
		return
	_wait_click = true
	if auto_after > 0.0:
		_auto_click(auto_after)
	await _clicked
	_wait_click = false


func _auto_click(t: float) -> void:
	await _sleep(t)
	if _wait_click:
		_clicked.emit()


# =================================================================== static UI
func _build_thumbs() -> void:
	var n := _panels.size()
	if n == 0:
		return
	var tw_ := clampf((330.0 - (n - 1) * 8.0) / n, 22.0, 50.0)
	var x := 1250.0 - (n * tw_ + (n - 1) * 8.0)
	for i in n:
		var t := Panel.new()
		t.position = Vector2(x + i * (tw_ + 8.0), 20)
		t.size = Vector2(tw_, 36)
		t.pivot_offset = t.size * 0.5
		t.clip_contents = true
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Style.label(str(i + 1), 16, Style.TEXT_DIM, true)
		l.name = "Num"
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.add_child(l)
		_stage.add_child(t)
		_thumbs.append(t)
	_refresh_thumbs()


func _refresh_thumbs() -> void:
	for i in _thumbs.size():
		var t := _thumbs[i]
		var st: StyleBoxFlat
		if i < _filled.size():
			st = _sb(Color(0.3, 0.2, 0.1, 1.0), Style.GOLD, 2, 6, 0.3, HARD_SHADOW, Vector2(4, 4))
		elif i == _idx:
			st = _sb(Color(0.16, 0.09, 0.30, 1.0), Style.YUZU, 3, 6, 0.3, Color(Style.AQUA, 0.9), Vector2(4, 4))
		else:
			st = _sb(Color(0.05, 0.03, 0.11, 0.95), Style.AQUA_DEEP, 2, 6, 0.3, HARD_SHADOW, Vector2(4, 4))
		t.add_theme_stylebox_override("panel", st)
		if i < _filled.size() and not t.has_node("Img"):
			var p: Dictionary = _panels[i]
			var img := TextureRect.new()
			img.name = "Img"
			img.texture = Assets.bg(str(p.get("bg", "trial")))
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			img.modulate = SEPIA
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.add_child(img)
			t.move_child(img, 0)
			var num: Label = t.get_node("Num")
			num.add_theme_color_override("font_color", Color.WHITE)
			num.add_theme_color_override("font_outline_color", INK)
			num.add_theme_constant_override("outline_size", 6)
			var fr := Panel.new()
			fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fr.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0), Style.GOLD, 2, 6, 0.0, Color(0, 0, 0, 0)))
			t.add_child(fr)


## Largest font size (max_s..min_s) whose wrapped text fits into box.
func _fit(font: Font, text: String, box: Vector2, max_s: int, min_s: int) -> int:
	var s := max_s
	while s > min_s:
		var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box.x - 6.0, s)
		if sz.y * 1.15 <= box.y:
			return s
		s -= 1
	return min_s


func _longest_option(p: Dictionary) -> String:
	var best := "? ? ?"
	for o in p.get("options", []):
		if str(o).length() > best.length():
			best = str(o)
	return best


# =================================================================== flow
func _run() -> void:
	await _sleep(0.3 * _k)
	while _idx < _panels.size():
		await _play_panel(_idx)
		if bool((_panels[_idx] as Dictionary).get("jam", false)):
			_result = {"flags": {"rewind_jammed": true}}
			_finish()
			return
		_idx += 1
		_refresh_thumbs()
	await _replay()
	await _finale()
	_finish()


func _play_panel(i: int) -> void:
	_busy = true
	var p: Dictionary = _panels[i]
	_crossed.clear()
	_opt_buttons.clear()
	_page = Control.new()
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_page)
	_panel_node = _comic_panel(p, i, PANEL_RECT, true)
	_page.add_child(_panel_node)
	_build_caption(p)
	_build_options(p)
	_refresh_thumbs()
	# SLAM: the panel drops in big and tilted, hits, shakes; caption and options snap in after
	var flip := i % 2 == 1
	_panel_node.pivot_offset = PANEL_RECT.size * 0.5
	_panel_node.scale = Vector2(1.32, 1.32)
	_panel_node.rotation = 0.09 if flip else -0.09
	_panel_node.modulate.a = 0.0
	var cap: Control = _page.get_node("Caption")
	cap.position.x = -W
	Audio.sfx("whoosh")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel_node, "scale", Vector2.ONE, 0.17 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel_node, "rotation", 0.0, 0.17 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel_node, "modulate:a", 1.0, 0.08 * _k)
	await tw.finished
	Audio.sfx("gavel", 0.75, -4.0)
	_kit_shake(12.0, 0.26)
	_kit_flash(CREAM, 0.35, 0.2)
	_kit_speedlines(PANEL_RECT.get_center(), Color(CREAM, 0.55), 0.35, 300.0, 36)
	for c in [PANEL_RECT.position + Vector2(0, PANEL_RECT.size.y), PANEL_RECT.end]:
		_kit_shards(c, CREAM, 6, 320.0)
	var tc := create_tween()
	tc.tween_property(cap, "position:x", CAPTION_RECT.position.x, 0.2 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_kit_hlines(Rect2(0, CAPTION_RECT.position.y, W, CAPTION_RECT.size.y), Color(CREAM, 0.45), 0.25, 10)
	for j in _opt_buttons.size():
		var b := _opt_buttons[j]
		var tw2 := create_tween()
		tw2.tween_property(b, "scale", Vector2.ONE, 0.18 * _k).set_delay((0.08 + j * 0.05) * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _sleep((0.28 + _opt_buttons.size() * 0.05) * _k)
	if Game.has_skill("artists_eye") and not bool(p.get("jam", false)):
		await _artists_eye(p)
	_busy = false
	if Game.autotest:
		_autoplay(p, i)
	# wait until solved
	while not (_filled.size() > i):
		await _sleep(0.05)
	await _sleep(1.0 * _k)
	if bool(p.get("jam", false)):
		return   # the jammed panel stays up until the minigame ends
	# panel flies into its thumbnail
	var t: Control = _thumbs[i] if i < _thumbs.size() else null
	var tw3 := create_tween().set_parallel(true)
	if t:
		var target := t.get_global_rect().get_center()
		var pc := PANEL_RECT.get_center()
		_page.pivot_offset = pc
		tw3.tween_property(_page, "position", target - pc, 0.28 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw3.tween_property(_page, "scale", Vector2.ONE * 0.05, 0.28 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw3.tween_property(_page, "rotation", -0.2, 0.28 * _k)
	tw3.tween_property(_page, "modulate:a", 0.0, 0.28 * _k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw3.finished
	_page.queue_free()
	_page = null
	_panel_node = null
	if t:
		t.scale = Vector2(1.6, 1.6)
		var tw4 := t.create_tween()
		tw4.tween_property(t, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_kit_burst(t.get_global_rect().get_center(), Style.GOLD, 8, 200.0)
		Audio.sfx("select", 1.3, -4.0)


## Slanted comic-panel outline (flip mirrors the slant so neighbouring panels zig-zag).
func _panel_quad(w: float, h: float, s: float, cut: float, flip: bool) -> PackedVector2Array:
	var q := _kit_quad(w, h, s, cut)
	if flip:
		var m := PackedVector2Array()
		for i in range(q.size() - 1, -1, -1):
			m.append(Vector2(w - q[i].x, q[i].y))
		return m
	return q


## A comic panel: slanted, chamfered frame (hard shadow + ink + cream border) masking a sepia
## background, the culprit's silhouette, a "?" and halftone dots; panel number plate on top.
func _comic_panel(p: Dictionary, i: int, r: Rect2, big: bool) -> Control:
	var root := Control.new()
	root.position = r.position
	root.size = r.size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flip := i % 2 == 1
	var sl := r.size.y * 0.09
	var cut := r.size.y * (0.10 if big else 0.12)
	var bw := 7.0 if big else 5.0
	var q := _panel_quad(r.size.x, r.size.y, sl, cut, flip)
	var back := Control.new()
	back.size = r.size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(func() -> void:
		var sh := PackedVector2Array()
		var ink := PackedVector2Array()
		var c := r.size * 0.5
		for v in q:
			sh.append(v + Vector2(12, 12) if big else v + Vector2(8, 8))
			ink.append(c + (v - c) * Vector2(1.0 + (bw * 2.0 + 6.0) / r.size.x, 1.0 + (bw * 2.0 + 6.0) / r.size.y))
		back.draw_colored_polygon(sh, Color(NEAR_BLACK, 0.92))
		back.draw_colored_polygon(ink, INK))
	root.add_child(back)
	var mask := Control.new()
	mask.size = r.size
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.draw.connect(func() -> void: mask.draw_colored_polygon(q, Color.WHITE))
	root.add_child(mask)
	var img := TextureRect.new()
	img.texture = Assets.bg(str(p.get("bg", "trial")))
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.size = r.size
	img.modulate = SEPIA
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(img)
	# mysterious culprit silhouette
	var shp := TextureRect.new()
	shp.texture = Assets.portrait(_culprit, "normal")
	shp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var s := (r.size.y * 1.05) / Assets.PORTRAIT_SIZE.y
	shp.size = Assets.PORTRAIT_SIZE * s
	var right := i % 2 == 0
	shp.position = Vector2(r.size.x - shp.size.x - r.size.x * 0.07 if right else r.size.x * 0.07, r.size.y * 0.1)
	shp.modulate = Color(0.07, 0.04, 0.13, 0.93)
	shp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(shp)
	var qm := Style.title_label("?", int(r.size.y * 0.24), Style.GOLD, INK, 10 if big else 6)
	qm.size = Vector2(r.size.y * 0.3, r.size.y * 0.3)
	qm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qm.position = shp.position + Vector2(shp.size.x * (0.72 if right else 0.0), r.size.y * 0.02)
	qm.rotation = 0.2 if right else -0.2
	mask.add_child(qm)
	# halftone dots, diagonal action slashes + vignette
	var tone := Control.new()
	tone.size = r.size
	tone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tone.draw.connect(_draw_halftone.bind(tone, 13.0 if big else 9.0, right))
	mask.add_child(tone)
	var frame := Control.new()
	frame.size = r.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		var o := q.duplicate()
		o.append(q[0])
		frame.draw_polyline(o, CREAM, bw, true))
	root.add_child(frame)
	# panel number: slanted yuzu plate
	var ns := 52.0 if big else 34.0
	var nb := Control.new()
	nb.size = Vector2(ns * 1.3, ns)
	nb.position = Vector2(-ns * 0.2, -ns * 0.3)
	nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nb.draw.connect(func() -> void:
		var pq := _kit_quad(ns * 1.3, ns, ns * 0.32, ns * 0.2)
		var sh := PackedVector2Array()
		for v in pq:
			sh.append(v + Vector2(4, 4))
		nb.draw_colored_polygon(sh, HARD_SHADOW)
		nb.draw_colored_polygon(pq, Style.YUZU)
		var o := pq.duplicate()
		o.append(pq[0])
		nb.draw_polyline(o, INK, 3.0, true))
	root.add_child(nb)
	var nl := Style.label(str(i + 1), int(ns * 0.56), INK, true)
	nl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nb.add_child(nl)
	return root


func _draw_halftone(c: Control, step: float, right: bool) -> void:
	var sz := c.size
	var y := step * 0.5
	var row := 0
	while y < sz.y:
		var x := step * 0.5 + (step * 0.5 if row % 2 == 1 else 0.0)
		var rr := step * (0.12 + 0.18 * (y / sz.y))
		while x < sz.x:
			c.draw_circle(Vector2(x, y), rr, Color(0.16, 0.08, 0.04, 0.18))
			x += step
		y += step * 0.87
		row += 1
	# diagonal action slashes on the side opposite the silhouette
	var bx := sz.x * (0.08 if right else 0.62)
	for k in 3:
		var x0 := bx + k * sz.x * 0.07
		c.draw_colored_polygon(PackedVector2Array([Vector2(x0 + sz.y * 0.35, 0), Vector2(x0 + sz.y * 0.35 + 14, 0), Vector2(x0 + 14, sz.y), Vector2(x0, sz.y)]), Color(1.0, 0.95, 0.85, 0.08))
	# vignette edges
	var e := 28.0
	var dark := Color(0.1, 0.05, 0.02, 0.45)
	var clear := Color(0.1, 0.05, 0.02, 0.0)
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, e), Vector2(0, e)]), PackedColorArray([dark, dark, clear, clear]))
	c.draw_polygon(PackedVector2Array([Vector2(0, sz.y - e), Vector2(sz.x, sz.y - e), Vector2(sz.x, sz.y), Vector2(0, sz.y)]), PackedColorArray([clear, clear, dark, dark]))


func _caption_bb(p: Dictionary, fill: String) -> String:
	var cap := str(p.get("caption", "___"))
	if not cap.contains("___"):
		cap += " ___"
	var blank := BLANK_BB
	if fill != "":
		blank = "[bgcolor=#ffb347][color=#2a1a10][b] %s [/b][/color][/bgcolor]" % fill
	return "[color=#2a1a10]" + cap.replace("___", "[/color]" + blank + "[color=#2a1a10]") + "[/color]"


func _build_caption(p: Dictionary) -> void:
	var box := Panel.new()
	box.position = CAPTION_RECT.position
	box.size = CAPTION_RECT.size
	box.pivot_offset = box.size * 0.5
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", _sb(CREAM, INK, 4, 16, 0.06, Color(NEAR_BLACK, 0.92), Vector2(8, 8)))
	box.name = "Caption"
	_page.add_child(box)
	_kit_stripes(box, Vector2(CAPTION_RECT.size.x - 70, 8), 4, Color(Style.YUZU, 0.85), Vector2(5, 14), 9.0)
	var plain := str(p.get("caption", "")).replace("___", "  " + _longest_option(p) + "  ")
	var tsz := Vector2(CAPTION_RECT.size.x - 52, CAPTION_RECT.size.y - 18)
	var fs := _fit(Style.body_font(), plain, tsz, 24, 14)
	_caption = RichTextLabel.new()
	_caption.bbcode_enabled = true
	_caption.scroll_active = false
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("normal_font_size", fs)
	_caption.add_theme_font_size_override("bold_font_size", fs)
	_caption.add_theme_font_override("bold_font", Style.display_font())
	_caption.fit_content = true
	_caption.position = Vector2(26, 9)
	_caption.size = Vector2(tsz.x, 0)
	_caption.text = _caption_bb(p, "")
	var cap_ref := _caption
	_caption.resized.connect(func() -> void: cap_ref.position.y = maxf(4.0, (CAPTION_RECT.size.y - cap_ref.size.y) * 0.5))
	box.add_child(_caption)


func _build_options(p: Dictionary) -> void:
	var opts: Array = p.get("options", [])
	var n := maxi(opts.size(), 1)
	var gap := 24.0
	var bw := (CAPTION_RECT.size.x - (n - 1) * gap) / n
	var bh := 74.0
	for j in opts.size():
		var b := _option_button(str(opts[j]), j + 1, Vector2(bw, bh))
		b.position = Vector2(CAPTION_RECT.position.x + j * (bw + gap), 580)
		b.scale = Vector2.ZERO
		b.pressed.connect(_choose.bind(j))
		b.mouse_entered.connect(_hover.bind(b, true))
		b.mouse_exited.connect(_hover.bind(b, false))
		_page.add_child(b)
		_opt_buttons.append(b)
	var hint := Style.label("Choose what fills the blank  -  click or press 1-%d" % opts.size(), 15, Style.TEXT_DIM)
	hint.position = Vector2(0, 670)
	hint.size = Vector2(W, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(hint)


func _btn_style(bg: Color, border: Color, bw: int, ml: int, shadow: Color = HARD_SHADOW) -> StyleBoxFlat:
	var st := _sb(bg, border, bw, 14, 0.2, shadow, Vector2(7, 7))
	st.content_margin_left = ml
	st.content_margin_right = 12
	return st


func _option_button(text: String, num: int, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.size = sz
	b.pivot_offset = sz * 0.5
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Style.display_font())
	b.add_theme_font_size_override("font_size", _fit(Style.display_font(), text, Vector2(sz.x - 96, sz.y - 8), 24, 14))
	b.add_theme_color_override("font_hover_color", Style.GOLD)
	b.add_theme_color_override("font_outline_color", NEAR_BLACK)
	b.add_theme_constant_override("outline_size", 5)
	var ml := 78
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.11, 0.06, 0.24, 0.96), Style.AQUA_DEEP, 3, ml))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.21, 0.12, 0.42, 0.98), Style.YUZU, 4, ml, Color(Style.AQUA, 0.9)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.10, 0.45, 0.50, 0.98), Style.GOLD, 4, ml))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(0.08, 0.06, 0.14, 0.85), Color(0.30, 0.28, 0.38), 2, ml))
	var bs := 44.0
	var badge := Control.new()
	badge.size = Vector2(bs * 1.25, bs)
	badge.position = Vector2(16, (sz.y - bs) * 0.5)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		var q := _kit_quad(bs * 1.25, bs, bs * 0.3, bs * 0.18)
		var sh := PackedVector2Array()
		for v in q:
			sh.append(v + Vector2(3, 3))
		badge.draw_colored_polygon(sh, HARD_SHADOW)
		badge.draw_colored_polygon(q, Style.YUZU)
		var o := q.duplicate()
		o.append(q[0])
		badge.draw_polyline(o, Color.WHITE, 2.0, true))
	b.add_child(badge)
	var nl := Style.label(str(num), 24, NEAR_BLACK, true)
	nl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(nl)
	return b


func _hover(b: Button, on: bool) -> void:
	if b.disabled or _busy:
		return
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * (1.05 if on else 1.0), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if on:
		Audio.sfx("select", randf_range(1.1, 1.25), -12.0)


func _artists_eye(p: Dictionary) -> void:
	var ans := int(p.get("answer", 0))
	var wrong: Array[int] = []
	for j in _opt_buttons.size():
		if j != ans and not _crossed.has(j):
			wrong.append(j)
	if wrong.is_empty():
		return
	var j: int = wrong[randi() % wrong.size()]
	_crossed[j] = true
	var b := _opt_buttons[j]
	Audio.sfx("poof", 1.15, -4.0)
	var c := b.get_global_rect().get_center()
	_kit_burst(c, Style.VIOLET, 12, 240.0)
	_kit_shards(c, Style.VIOLET.lightened(0.3), 6, 280.0)
	_cross_out(b, Style.VIOLET.lightened(0.25))
	var tag := _kit_tag("ARTIST'S EYE", Style.VIOLET, 14)
	tag.position = b.get_global_rect().position + Vector2(b.size.x * 0.5 - 64, -22)
	_overlay.add_child(tag)
	var tw := create_tween()
	tw.tween_interval(1.4 * _k)
	tw.tween_property(tag, "modulate:a", 0.0, 0.3 * _k)
	tw.tween_callback(tag.queue_free)
	await _sleep(0.3 * _k)


func _cross_out(b: Button, col: Color) -> void:
	b.disabled = true
	b.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	b.scale = Vector2.ONE
	var cross := Control.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.set_meta("t", 0.0)
	cross.draw.connect(_draw_cross.bind(cross, col))
	b.add_child(cross)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_set_cross_t.bind(cross), 0.0, 1.0, 0.18 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "modulate", Color(0.62, 0.58, 0.68, 0.8), 0.25 * _k)


func _set_cross_t(v: float, cross: Control) -> void:
	cross.set_meta("t", v)
	cross.queue_redraw()


func _draw_cross(cross: Control, col: Color) -> void:
	var t: float = cross.get_meta("t", 1.0)
	var sz := cross.size
	var a := Vector2(70, sz.y * 0.72)
	var bpt := Vector2(sz.x - 20, sz.y * 0.28)
	var e := a.lerp(bpt, t)
	var nrm := (bpt - a).normalized().orthogonal() * 4.0
	cross.draw_colored_polygon(PackedVector2Array([a + nrm + Vector2(4, 4), e + nrm + Vector2(4, 4), e - nrm + Vector2(4, 4), a - nrm + Vector2(4, 4)]), HARD_SHADOW)
	cross.draw_colored_polygon(PackedVector2Array([a + nrm, e + nrm * 0.4, e - nrm * 0.4, a - nrm]), col)


# =================================================================== answering
func _choose(j: int) -> void:
	if _busy or _done or _page == null or _crossed.has(j) or j >= _opt_buttons.size():
		return
	var p: Dictionary = _panels[_idx]
	var ans := int(p.get("answer", 0))
	var b := _opt_buttons[j]
	_busy = true
	Audio.sfx("confirm")
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * 0.93, 0.05 * _k)
	tw.tween_property(b, "scale", Vector2.ONE * 1.06, 0.1 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _sleep(0.16 * _k)
	if bool(p.get("jam", false)):
		_jam(p)
	elif j == ans:
		_correct(p, j)
	else:
		_wrong(j)


func _correct(p: Dictionary, j: int) -> void:
	var opts: Array = p.get("options", [])
	var fill := str(opts[j]) if j < opts.size() else "?"
	_caption.text = _caption_bb(p, fill)
	Audio.sfx("correct")
	Game.reward(Game.REWARD_REWIND_PANEL)
	var b := _opt_buttons[j]
	var c := b.get_global_rect().get_center()
	_kit_flash(Color(1.0, 0.96, 0.8), 0.55, 0.28)
	_kit_shards(c, Style.GOLD, 14, 480.0)
	_kit_ring(c, Style.GOLD, 180.0, 0.35)
	_kit_shake(7.0, 0.2)
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.42, 0.26, 0.05, 0.98), Style.GOLD, 5, 78, Color(Style.AQUA, 0.95)))
	b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))
	b.add_theme_color_override("font_color", Color.WHITE)
	for k in _opt_buttons.size():
		if k != j:
			var o := _opt_buttons[k]
			var tw0 := create_tween()
			tw0.tween_property(o, "modulate:a", 0.28, 0.2 * _k)
	var cap: Control = _page.get_node("Caption")
	var tw := cap.create_tween()
	tw.tween_property(cap, "scale", Vector2.ONE * 1.05, 0.08 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(cap, "scale", Vector2.ONE, 0.14 * _k)
	await _sleep(0.16 * _k)
	_rubber_stamp("TRUTH!", PANEL_RECT.position + Vector2(PANEL_RECT.size.x - 170, 86))
	_filled.append(fill)


func _wrong(j: int) -> void:
	Audio.sfx("wrong")
	Audio.sfx("static", 1.0, -8.0)
	Game.mistake(Game.PENALTY_REWIND)
	var b := _opt_buttons[j]
	_kit_error(b.get_global_rect().get_center())
	_kit_jolt(_page, 14.0)
	_crossed[j] = true
	_cross_out(b, Style.DANGER)
	_kit_stamp("THAT'S NOT HOW IT HAPPENED!", Style.DANGER, PANEL_RECT.get_center() + Vector2(0, -20), 42, 0.5, -4.0)
	await _sleep(0.55 * _k)
	_busy = false


## None of the options fits. Nothing is charged: every option strikes out, the panel shudders and the reel stops.
func _jam(p: Dictionary) -> void:
	Audio.sfx("wrong", 0.8)
	Audio.sfx("static", 1.0, -6.0)
	_kit_glitch(0.45, 1.0)
	_kit_jolt(_page, 18.0)
	_kit_shake(16.0, 0.4)
	for b in _opt_buttons:
		_cross_out(b, Style.DANGER)
		await _sleep(0.09 * _k)
	_kit_stamp(str(p.get("jam_text", "IT DOESN'T FIT!")), Style.DANGER, PANEL_RECT.get_center() + Vector2(0, -20), 64, 0.8, -4.0)
	await _sleep(0.7 * _k)
	_filled.append("?")


## An angular stamp slammed onto the comic panel.
func _rubber_stamp(text: String, center: Vector2) -> void:
	var holder := Control.new()
	holder.size = Vector2(270, 100)
	holder.position = center - holder.size * 0.5
	holder.pivot_offset = holder.size * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.draw.connect(func() -> void:
		var q := _kit_quad(270, 100, 30, 18)
		var sh := PackedVector2Array()
		for v in q:
			sh.append(v + Vector2(6, 6))
		holder.draw_colored_polygon(sh, Color(NEAR_BLACK, 0.85))
		holder.draw_colored_polygon(q, Color(INK, 0.92))
		var o := q.duplicate()
		o.append(q[0])
		holder.draw_polyline(o, Style.YUZU, 6.0, true))
	var l := Style.title_label(text, 54, Style.YUZU, INK, 8)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(l)
	_page.add_child(holder)
	holder.rotation = deg_to_rad(-12)
	holder.scale = Vector2(2.8, 2.8)
	holder.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(holder, "scale", Vector2.ONE, 0.13 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(holder, "modulate:a", 1.0, 0.07 * _k)
	tw.chain().tween_callback(func() -> void:
		Audio.sfx("gavel")
		_kit_shake(9.0, 0.22)
		_kit_jolt(_panel_node, 6.0)
		_kit_shards(center, Style.YUZU, 12, 460.0)
		_kit_speedlines(center, Color(Style.YUZU, 0.45), 0.3, 140.0, 28))


# =================================================================== replay + finale
func _replay() -> void:
	_busy = true
	var title := _kit_stamp("THE TRUTH, FROM THE TOP...", Style.GOLD, Vector2(W * 0.5, 126), 40, -1.0, -2.0)
	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(strip)
	var pw := 420.0
	var ph := 236.0
	var gap := 40.0
	var total := _panels.size() * (pw + gap) - gap
	# film strip behind the panels
	var film := Control.new()
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film.position = Vector2(-W - 200.0, 168)
	film.size = Vector2(total + W * 2.0 + 400.0, 430)
	film.draw.connect(_draw_film.bind(film))
	film.modulate.a = 0.0
	strip.add_child(film)
	create_tween().tween_property(film, "modulate:a", 1.0, 0.25 * _k)
	for i in _panels.size():
		var p: Dictionary = _panels[i]
		var cell := Control.new()
		cell.position = Vector2(i * (pw + gap), 196 + (12.0 if i % 2 == 1 else 0.0))
		cell.size = Vector2(pw, ph + 120)
		cell.pivot_offset = cell.size * 0.5
		cell.rotation = deg_to_rad(-1.5 if i % 2 == 0 else 1.5)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(_comic_panel(p, i, Rect2(0, 0, pw, ph), false))
		var box := Panel.new()
		box.position = Vector2(0, ph + 18)
		box.size = Vector2(pw, 104)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel", _sb(CREAM, INK, 3, 12, 0.05, Color(NEAR_BLACK, 0.9), Vector2(6, 6)))
		cell.add_child(box)
		var fill: String = _filled[i] if i < _filled.size() else "?"
		var plain := str(p.get("caption", "")).replace("___", " " + fill + " ")
		var tsz := Vector2(pw - 28, 92)
		var fs := _fit(Style.body_font(), plain, tsz, 17, 11)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.scroll_active = false
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.add_theme_font_size_override("normal_font_size", fs)
		rt.add_theme_font_size_override("bold_font_size", fs)
		rt.add_theme_font_override("bold_font", Style.display_font())
		rt.position = Vector2(14, 6)
		rt.size = tsz
		rt.text = _caption_bb(p, fill)
		box.add_child(rt)
		strip.add_child(cell)
	strip.position.x = W * 0.42
	strip.modulate.a = 0.0
	create_tween().tween_property(strip, "modulate:a", 1.0, 0.2 * _k)
	Audio.sfx("whoosh")
	var dur := maxf(4.0, _panels.size() * 1.2) * _k
	_kit_hlines(Rect2(0, 168, W, 430), Color(1.0, 0.95, 0.85, 0.3), dur, 22)
	var tw := create_tween()
	tw.tween_property(strip, "position:x", -(total - W) - 60.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_skip_on_click(tw)
	await tw.finished
	_wait_click = false
	await _sleep(0.25 * _k)
	# SHATTER into the finale: capture this frame, then swap the strip for the finale underneath
	Audio.sfx("break")
	_kit_shatter(Vector2(W * 0.5, H * 0.5), 8, 5, 0.5)
	strip.queue_free()
	title.queue_free()


func _draw_film(c: Control) -> void:
	var sz := c.size
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.01, 0.05, 0.9))
	c.draw_rect(Rect2(0, 0, sz.x, 4), Color(Style.YUZU, 0.7))
	c.draw_rect(Rect2(0, sz.y - 4, sz.x, 4), Color(Style.AQUA, 0.6))
	var x := 10.0
	while x < sz.x:
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 5, 10), Vector2(x + 25, 10), Vector2(x + 20, 23), Vector2(x, 23)]), Color(0.85, 0.8, 0.7, 0.55))
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 5, sz.y - 23), Vector2(x + 25, sz.y - 23), Vector2(x + 20, sz.y - 10), Vector2(x, sz.y - 10)]), Color(0.85, 0.8, 0.7, 0.55))
		x += 36.0


func _skip_on_click(tw: Tween) -> void:
	if Game.autotest:
		return
	_wait_click = true
	await _clicked
	if tw.is_valid() and tw.is_running():
		tw.custom_step(999.0)


func _finale() -> void:
	var col := Cast.color(_culprit) if Cast.exists(_culprit) else Style.VIOLET
	_ray_col = col
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(root)
	var dark := ColorRect.new()
	dark.color = Color(NEAR_BLACK, 0.5)
	dark.position = Vector2(-40, -40)
	dark.size = Vector2(W + 80, H + 80)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dark)
	_rays = Control.new()
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	root.add_child(_rays)
	var por := TextureRect.new()
	por.texture = Assets.portrait(_culprit, "shock")
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	por.size = Assets.PORTRAIT_SIZE * 1.08
	por.pivot_offset = Vector2(por.size.x * 0.5, por.size.y * 0.6)
	por.position = Vector2(W - por.size.x + 10, H - por.size.y + 20)
	por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(por)
	var name_tag := _kit_tag(Cast.display_name("mochi"), Cast.color("mochi"), 24)
	name_tag.position = Vector2(64, 462)
	var box := Panel.new()
	box.position = Vector2(40, 482)
	box.size = Vector2(760, 210)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.025, 0.12, 0.97), Style.YUZU, 4, 22, 0.05, HARD_SHADOW, Vector2(10, 10)))
	root.add_child(box)
	root.add_child(name_tag)
	_kit_stripes(box, Vector2(640, 14), 6, Color(Style.YUZU, 0.55), Vector2(5, 18), 11.0)
	var text := str(_data.get("finale", "...and the culprit is YOU!"))
	var fs := _fit(Style.body_font(), text, Vector2(712, 160), 30, 16)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_size_override("normal_font_size", fs)
	rt.add_theme_font_size_override("bold_font_size", fs)
	rt.add_theme_font_override("bold_font", Style.display_font())
	rt.position = Vector2(26, 30)
	rt.size = Vector2(708, 166)
	var bb := Style.markup(text)
	var full := Cast.full_name(_culprit)
	if bb.contains(full):
		bb = bb.replace(full, "[color=#ffb347][b]%s[/b][/color]" % full)
	bb = bb.replace("YOU", "[color=#ff4f6d][b]YOU[/b][/color]")
	rt.text = bb
	rt.visible_ratio = 0.0
	box.add_child(rt)
	# reveal: portrait slams in with speed lines
	por.position.x = W + 40.0
	por.scale = Vector2(1.5, 1.5)
	box.position.x = -820.0
	name_tag.position.x = -820.0
	Audio.sfx("whoosh")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(por, "position:x", W - por.size.x + 10, 0.2 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(por, "scale", Vector2.ONE, 0.32 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "position:x", 40.0, 0.22 * _k).set_delay(0.12 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(name_tag, "position:x", 64.0, 0.22 * _k).set_delay(0.16 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		Audio.sfx("shout", 1.0, -4.0)
		_kit_flash(Color.WHITE, 0.8, 0.3)
		_kit_shake(18.0, 0.35)
		_kit_shards(_ray_center, col.lightened(0.3), 24, 640.0)
		_kit_ring(_ray_center, Style.GOLD, 360.0, 0.5))
	await _sleep(0.4 * _k)
	var chars := text.length()
	var twt := create_tween()
	twt.tween_method(_type_step.bind(rt, chars), 0.0, 1.0, maxf(0.4, chars / (46.0 * maxf(Game.text_speed, 0.1))) * _k)
	_skip_typing(twt, rt)
	await twt.finished
	_wait_click = false
	Game.reward(Game.REWARD_REWIND)
	Audio.sfx("gavel")
	_kit_stamp("CASE CLOSED!", Style.GOLD, Vector2(W * 0.5 - 120, 250), 100)
	await _sleep(0.6 * _k)
	var more := Style.label("click to continue  ▼", 16, Style.YUZU)
	more.position = Vector2(540, 180)
	more.size = Vector2(196, 22)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(more)
	await _await_click()


func _type_step(v: float, rt: RichTextLabel, chars: int) -> void:
	if int(v * chars) != int(rt.visible_ratio * chars) and not Game.autotest:
		Audio.blip(Cast.pitch("mochi"))
	rt.visible_ratio = v


func _skip_typing(tw: Tween, rt: RichTextLabel) -> void:
	if Game.autotest:
		return
	_wait_click = true
	await _clicked
	if tw.is_valid() and tw.is_running():
		tw.custom_step(999.0)
	rt.visible_ratio = 1.0


## Finale backdrop: rotating angular wedges + flickering speed lines converging on the culprit.
func _draw_rays() -> void:
	var c := _ray_center
	var n := 16
	for i in n:
		var a0 := _time * 0.22 + i * TAU / n
		var a1 := a0 + TAU / n * 0.42
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a0) * 1500.0, c + Vector2.from_angle(a1) * 1500.0])
		_rays.draw_colored_polygon(pts, Color(_ray_col if i % 2 == 0 else Style.YUZU, 0.11 if i % 2 == 0 else 0.05))
	var frame := int(_time * 24.0)
	for i in 40:
		var h := _kit_hash(i * 13 + frame * 7)
		var h2 := _kit_hash(i * 31 + frame * 11)
		var a := (i + h * 0.8) * TAU / 40.0
		var r0 := 230.0 + h2 * 160.0
		var wd := 0.004 + 0.01 * h
		_rays.draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * r0, c + Vector2.from_angle(a - wd) * 1600.0,
			c + Vector2.from_angle(a + wd) * 1600.0]), Color(1.0, 0.97, 0.9, 0.10 + 0.22 * h2))


func _finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25 * _k)
	await tw.finished
	finished.emit(_result)


# =================================================================== autotest
func _autoplay(p: Dictionary, i: int) -> void:
	await _sleep(0.9 if Game.autotest_slow else 0.3)
	var ans := int(p.get("answer", 0))
	if bool(p.get("jam", false)):
		_choose(0)
		return
	if _auto_wrong and i == 0:
		for j in _opt_buttons.size():
			if j != ans and not _crossed.has(j):
				_choose(j)
				break
		await _sleep(0.15)
		while _busy and not _done:
			await _sleep(0.05)
		if Game.autotest_slow:
			await _sleep(0.6)
	_choose(ans)


# =================================================================== frame
func _process(delta: float) -> void:
	_time += delta
	_kit_tick(delta)
	if _rays:
		_rays.queue_redraw()


func _sleep(t: float) -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(t, 0.001))
	await tw.finished

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
