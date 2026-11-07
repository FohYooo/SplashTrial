extends Control
## VOTE TIME - the final vote.
##  1. Shows the player's convince vs the threshold (will the group follow Mochi?).
##  2. The player points out a capybara (Cast.survivors() minus mochi) and confirms.
##  3. The lights drop, spotlights sweep, a drumroll plays and a 3-reel vote machine spins through
##     portraits, slamming to a stop reel by reel on the MAJORITY:
##     convince >= threshold -> the group follows the player's pick; otherwise it votes `fallback`.
##  4. The majority's portrait zooms in with speed lines + a "MAJORITY: <name>" banner, then the tally
##     (bars per capybara). No verdict - the trial script announces it.
## Emits {"flags": {"vote_correct": majority == culprit, "voted": pick, "majority": majority}}.
## Look: angular "sharp kit" (see the SHARP KIT section at the end of this file).

signal finished(result: Dictionary)
signal _clicked

const Style := preload("res://scripts/ui/style.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Cast := preload("res://scripts/data/cast.gd")

const W := 1280.0
const H := 720.0
const INK := Color("2a1a10")
const CELL_H := 268.0
const REEL_W := 214.0
const CARD_BG := Color(0.10, 0.06, 0.22, 0.95)
const CARD_HOVER := Color(0.19, 0.12, 0.38, 0.98)

var _data := {}
var _culprit := "wisp"
var _fallback := "bruno"
var _threshold := 60.0
var _convinced := false
var _cands: Array[String] = []
var _pick := ""
var _majority := ""
var _tally := {}
var _done := false
var _busy := true
var _phase := ""
var _k := 1.0
var _time := 0.0
var _wait_click := false
var _hurry := false            # a click during the spin / reveal fast-forwards the rest of it
var _last_slot_ms := 0

var _stage: Control
var _fx: Control
var _overlay: Control
var _badge: Control
var _dark: ColorRect            # lights-down overlay (under the stage)
var _spot: Control              # sweeping spotlights (under the stage)
var _spot_mode := ""            # "", "sweep", "focus"
var _spot_target := Vector2(W * 0.5, 420)
var _spot_boost := 0.0
var _spot_drawn := false

var _grid: Control
var _cards := {}
var _confirm: Control
var _reels: Array = []        # [{win, cells:[Control x2], ms:[int x2], list, offset, state}]
var _bulbs: Control
var _machine: Control
var _lines: Control           # majority reveal speed lines
var _lines_center := Vector2(W * 0.5, H * 0.5)
var _cv_value := 0.0          # convince bar fill (0..100)
var _cv_bar: Control


# =================================================================== setup
func setup(data: Dictionary) -> void:
	_data = data
	_culprit = str(data.get("culprit", "wisp"))
	_fallback = str(data.get("fallback", "bruno"))
	_threshold = float(data.get("threshold", Game.CONVINCE_THRESHOLD))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_k = 0.12 if Game.autotest and not Game.autotest_slow else 1.0
	_convinced = Game.convince >= _threshold
	for id in Cast.survivors():
		if id != "mochi":
			_cands.append(str(id))
	if not _cands.has(_fallback):
		_fallback = _cands[0]
	_kit_backdrop(0.55)
	_dark = ColorRect.new()
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.color = NEAR_BLACK
	_dark.modulate.a = 0.0
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dark)
	_spot = _layer()
	_spot.draw.connect(_draw_spots)
	_stage = _layer()
	_fx = _layer()
	_fx.draw.connect(_kit_draw)
	_overlay = _layer()
	_kit_top_layers()
	_badge = _kit_badge("VOTE TIME")
	_run()


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _run() -> void:
	await _show_convince()
	_build_grid()
	# the rest continues from the confirm dialog (_cast_vote)


# =================================================================== input helpers
func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _wait_click:
			_clicked.emit()
			accept_event()
		elif _phase in ["spin", "spinning", "tally"]:
			_hurry = true
			accept_event()


## Presentation multiplier for the spin / reveal (shrinks once the player clicks to hurry).
func _hk() -> float:
	return _k * (0.3 if _hurry else 1.0)


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
	if _phase in ["spin", "spinning", "tally"] and k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z]:
		_hurry = true
		get_viewport().set_input_as_handled()
		return
	if _phase == "confirm":
		if k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			_cast_vote()
		elif k.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			get_viewport().set_input_as_handled()
			_close_confirm()
	elif _phase == "pick" and k.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or not is_ancestor_of(focus):
			(_cards[_cands[0]] as Control).grab_focus()
			get_viewport().set_input_as_handled()


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


# =================================================================== shared widgets
func _panel(r: Rect2, border: Color = Style.AQUA, bw: int = 3, cut: int = 22) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.pivot_offset = r.size * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.025, 0.12, 0.96), border, bw, cut, 0.0, HARD_SHADOW, Vector2(10, 10)))
	return p


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
	deco.name = "Deco"
	deco.size = box
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.set_meta("col", frame_col)
	deco.draw.connect(func() -> void:
		var c: Color = deco.get_meta("col", frame_col)
		deco.draw_colored_polygon(PackedVector2Array([Vector2(box.x * 0.55, 0), Vector2(box.x * 0.85, 0), Vector2(box.x * 0.35, box.y), Vector2(box.x * 0.05, box.y)]), Color(c, 0.20))
		deco.draw_colored_polygon(PackedVector2Array([Vector2(box.x * 0.92, 0), Vector2(box.x, 0), Vector2(box.x * 0.55, box.y), Vector2(box.x * 0.47, box.y)]), Color(c, 0.12)))
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
	fr.name = "Frame"
	fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.set_meta("col", frame_col)
	var fw := float(frame_w)
	fr.draw.connect(func() -> void:
		var c: Color = fr.get_meta("col", frame_col)
		var sz := fr.size
		var t := minf(sz.x, sz.y) * 0.16
		fr.draw_rect(Rect2(Vector2(fw * 0.5, fw * 0.5), sz - Vector2(fw, fw)), c, false, fw)
		fr.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(t, 0), Vector2(0, t)]), c)
		fr.draw_colored_polygon(PackedVector2Array([sz, Vector2(sz.x - t, sz.y), Vector2(sz.x, sz.y - t)]), c))
	holder.add_child(fr)
	return holder


func _set_face(holder: Control, id: String, expr: String) -> void:
	var tr: TextureRect = holder.get_node("Face")
	tr.texture = Assets.portrait(id, expr)


func _fit(font: Font, text: String, box: Vector2, max_s: int, min_s: int) -> int:
	var s := max_s
	while s > min_s:
		var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box.x - 4.0, s)
		if sz.y * 1.12 <= box.y:
			return s
		s -= 1
	return min_s


func _btn_style(bg: Color, border: Color, bw: int, skew: float = 0.0, shadow: Color = HARD_SHADOW) -> StyleBoxFlat:
	return _sb(bg, border, bw, 14, skew, shadow, Vector2(7, 7))


func _big_button(text: String, sz: Vector2, primary: bool) -> Button:
	var b := Style.button(text, sz, 28)
	b.size = sz
	b.pivot_offset = sz * 0.5
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Style.display_font())
	if primary:
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, NEAR_BLACK)
		b.add_theme_stylebox_override("normal", _btn_style(Style.YUZU, Color.WHITE, 3, 0.3))
		b.add_theme_stylebox_override("hover", _btn_style(Style.GOLD, Color.WHITE, 4, 0.3, Color(Style.AQUA, 0.95)))
		b.add_theme_stylebox_override("pressed", _btn_style(Style.AQUA, Color.WHITE, 4, 0.3))
	else:
		b.add_theme_stylebox_override("normal", _btn_style(Color(0.13, 0.08, 0.27, 0.97), Style.AQUA_DEEP, 3, 0.3))
		b.add_theme_stylebox_override("hover", _btn_style(Color(0.21, 0.12, 0.42, 0.98), Style.AQUA, 3, 0.3, Color(Style.AQUA_DEEP, 0.95)))
		b.add_theme_stylebox_override("pressed", _btn_style(Color(0.10, 0.45, 0.50, 0.98), Style.GOLD, 3, 0.3))
	b.mouse_entered.connect(func() -> void:
		Audio.sfx("select", 1.2, -10.0)
		b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.06, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	return b


# =================================================================== 1. convince check
func _show_convince() -> void:
	_phase = "convince"
	var p := _panel(Rect2(200, 110, 880, 430), Style.GOLD, 4, 30)
	_stage.add_child(p)
	_kit_stripes(p, Vector2(30, 24), 5, Color(Style.YUZU, 0.7), Vector2(7, 30), 12.0)
	_kit_stripes(p, Vector2(770, 24), 5, Color(Style.AQUA, 0.5), Vector2(7, 30), 12.0)
	var title := Style.title_label("THE FINAL VOTE", 64, Style.GOLD, NEAR_BLACK, 14)
	title.position = Vector2(0, 18)
	title.size = Vector2(880, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(title)
	var sub := Style.label("Will the others follow your lead?", 22, Style.TEXT_DIM)
	sub.position = Vector2(0, 100)
	sub.size = Vector2(880, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(sub)
	var cap := Style.label("YOUR CONVINCE", 18, Style.AQUA, true)
	cap.position = Vector2(100, 160)
	p.add_child(cap)
	var pct := Style.title_label("0%", 54, Color.WHITE, NEAR_BLACK, 12)
	pct.position = Vector2(560, 136)
	pct.size = Vector2(220, 64)
	pct.pivot_offset = Vector2(110, 32)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(pct)
	var bar_w := 680.0
	_cv_value = 0.0
	_cv_bar = Control.new()
	_cv_bar.position = Vector2(100, 200)
	_cv_bar.size = Vector2(bar_w, 44)
	_cv_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cv_bar.draw.connect(_draw_cv_bar)
	p.add_child(_cv_bar)
	var tx := 100.0 + 22.0 + (bar_w - 44.0) * _threshold / 100.0
	var mark := Control.new()
	mark.position = Vector2(tx, 188)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func() -> void:
		mark.draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(16, 0), Vector2(-8, 68), Vector2(-16, 68)]), HARD_SHADOW)
		mark.draw_colored_polygon(PackedVector2Array([Vector2(4, -4), Vector2(12, -4), Vector2(-12, 64), Vector2(-20, 64)]), Style.GOLD))
	p.add_child(mark)
	var ml := Style.label("NEEDED: %d%%" % roundi(_threshold), 15, Style.GOLD, true)
	ml.position = Vector2(tx - 68, 258)
	ml.size = Vector2(120, 20)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(ml)
	var verdict := Style.title_label("", 30, Style.GOOD, NEAR_BLACK, 9)
	verdict.position = Vector2(30, 292)
	verdict.size = Vector2(820, 44)
	verdict.pivot_offset = Vector2(410, 22)
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict.modulate.a = 0.0
	p.add_child(verdict)
	var verdict2 := Style.label("", 20, Style.TEXT)
	verdict2.position = Vector2(30, 336)
	verdict2.size = Vector2(820, 28)
	verdict2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict2.modulate.a = 0.0
	p.add_child(verdict2)
	# slam in
	p.scale = Vector2(1.35, 1.35)
	p.rotation = -0.05
	p.modulate.a = 0.0
	_kit_wipe(Color(Style.GOLD, 0.2), 0.34, Style.AQUA)
	Audio.sfx("whoosh")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.16 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "rotation", 0.0, 0.16 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "modulate:a", 1.0, 0.08 * _k)
	await tw.finished
	Audio.sfx("gavel")
	_kit_shake(10.0, 0.25)
	_kit_flash(Style.GOLD.lerp(Color.WHITE, 0.6), 0.3, 0.2)
	_kit_shards(Vector2(200, 540), Style.GOLD, 8, 360.0)
	_kit_shards(Vector2(1080, 110), Style.AQUA, 8, 360.0)
	await _sleep(0.35 * _k)
	# fill the bar
	var target := Game.convince
	var dur := maxf(0.5, 1.4 * target / 100.0) * _k
	var twf := create_tween()
	twf.tween_method(_convince_fill.bind(pct), 0.0, target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await twf.finished
	pct.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(pct, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var shown := roundi(target)
	var bar_end := Vector2(200 + 100 + 22 + (bar_w - 44.0) * clampf(target / 100.0, 0.0, 1.0), 332)
	if _convinced:
		verdict.text = "Your Convince: %d%% — they'll follow your lead!" % shown
		verdict.add_theme_color_override("font_color", Style.GOOD)
		verdict2.text = "Whoever you point out, the group will vote with you."
		Audio.sfx("correct")
		_kit_flash(Style.GOOD, 0.3, 0.3)
		_kit_shards(bar_end, Style.AQUA, 14, 420.0)
		_kit_splash(bar_end, 12, 380.0)
	else:
		verdict.text = "Only %d%%... they don't trust you." % shown
		verdict.add_theme_color_override("font_color", Style.DANGER)
		verdict2.text = "Without at least %d%%, the group will vote with their gut..." % roundi(_threshold)
		Audio.sfx("heartbeat")
		_kit_glitch(0.25, 0.7)
		_kit_flash(Style.DANGER, 0.25, 0.35)
		_kit_jolt(p, 8.0)
	verdict.add_theme_font_size_override("font_size", _fit(Style.display_font(), verdict.text, Vector2(820, 44), 30, 18))
	verdict.scale = Vector2(1.5, 1.5)
	var tv := create_tween().set_parallel(true)
	tv.tween_property(verdict, "modulate:a", 1.0, 0.12 * _k)
	tv.tween_property(verdict, "scale", Vector2.ONE, 0.2 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tv.tween_property(verdict2, "modulate:a", 1.0, 0.25 * _k).set_delay(0.15 * _k)
	await _sleep(0.35 * _k)
	var btn := _big_button("CAST YOUR VOTE", Vector2(340, 64), true)
	btn.position = Vector2(270, 372)
	btn.scale = Vector2.ZERO
	p.add_child(btn)
	create_tween().tween_property(btn, "scale", Vector2.ONE, 0.2 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	btn.pressed.connect(func() -> void: _clicked.emit())
	_busy = false
	await _await_click()
	_busy = true
	Audio.sfx("confirm")
	var to := create_tween().set_parallel(true)
	to.tween_property(p, "position", p.position + Vector2(-120, -60), 0.2 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	to.tween_property(p, "modulate:a", 0.0, 0.2 * _k)
	await to.finished
	p.queue_free()
	_cv_bar = null


func _convince_fill(v: float, pct: Label) -> void:
	_cv_value = v
	if _cv_bar:
		_cv_bar.queue_redraw()
	var t := "%d%%" % roundi(v)
	if pct.text != t:
		pct.text = t
		_slot_tick()


## Slanted, segmented convince bar.
func _draw_cv_bar() -> void:
	var sz := _cv_bar.size
	var s := 22.0
	var q := _kit_quad(sz.x, sz.y, s, 0.0)
	var sh := PackedVector2Array()
	for v in q:
		sh.append(v + Vector2(6, 6))
	_cv_bar.draw_colored_polygon(sh, HARD_SHADOW)
	_cv_bar.draw_colored_polygon(q, Color(0.02, 0.01, 0.06, 1.0))
	var f := clampf(_cv_value / 100.0, 0.0, 1.0)
	var fw := (sz.x - s - 8.0) * f
	var col := Style.AQUA if _cv_value >= _threshold else Style.YUZU.lerp(Style.DANGER, clampf(1.0 - _cv_value / maxf(_threshold, 1.0), 0.0, 1.0))
	if fw > 1.0:
		_cv_bar.draw_colored_polygon(PackedVector2Array([Vector2(s + 4, 5), Vector2(s + 4 + fw, 5), Vector2(4 + fw, sz.y - 5), Vector2(4, sz.y - 5)]), col)
		_cv_bar.draw_colored_polygon(PackedVector2Array([Vector2(s + 4, 5), Vector2(s + 4 + fw, 5), Vector2(s + fw, 12), Vector2(s, 12)]), Color(1, 1, 1, 0.25))
	var x := 30.0
	while x < sz.x - s:
		_cv_bar.draw_line(Vector2(x + s, 3), Vector2(x, sz.y - 3), Color(0.02, 0.01, 0.06, 0.7), 3.0)
		x += 34.0
	var o := q.duplicate()
	o.append(q[0])
	_cv_bar.draw_polyline(o, Style.AQUA_DEEP, 3.0, true)


# =================================================================== 2. pick
func _build_grid() -> void:
	_phase = "pick"
	_grid = Control.new()
	_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_grid)
	# prompt
	var pp := _panel(Rect2(40, 84, 1200, 124), Style.AQUA, 3, 20)
	_grid.add_child(pp)
	_kit_stripes(pp, Vector2(1100, 94), 5, Color(Style.YUZU, 0.55), Vector2(6, 20), 12.0)
	var av := _head_box("snapjaw", "happy", Vector2(102, 102), Cast.color("snapjaw"))
	av.position = Vector2(12, 11)
	pp.add_child(av)
	var tag := _kit_tag(Cast.display_name("snapjaw"), Cast.color("snapjaw"), 22)
	tag.position = Vector2(136, 12)
	pp.add_child(tag)
	var q := Style.label("Snap-snap-snap! Voting time! Point out the capybara who checked Captain Coco out of this world!", 24, Style.TEXT)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.position = Vector2(136, 48)
	q.size = Vector2(1036, 66)
	q.add_theme_font_size_override("font_size", _fit(Style.body_font(), q.text, q.size, 24, 15))
	pp.add_child(q)
	# convince reminder chip (top right)
	var chip := Panel.new()
	chip.position = Vector2(934, 12)
	chip.size = Vector2(318, 56)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.025, 0.12, 0.95), Style.GOOD if _convinced else Style.DANGER, 3, 12, 0.36, HARD_SHADOW, Vector2(7, 6)))
	_grid.add_child(chip)
	var c1 := Style.label("CONVINCE %d%%" % roundi(Game.convince), 16, Style.GOOD if _convinced else Style.DANGER, true)
	c1.position = Vector2(0, 6)
	c1.size = Vector2(318, 22)
	c1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(c1)
	var c2 := Style.label("They'll follow your vote" if _convinced else "They'll vote with their gut", 15, Style.TEXT)
	c2.position = Vector2(0, 28)
	c2.size = Vector2(318, 22)
	c2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(c2)
	# cards
	var n := _cands.size()
	var top := n if n <= 7 else ceili(n / 2.0)
	var gap := 12.0
	var cw := minf(164.0, (1200.0 - (top - 1) * gap) / top)
	var ch := 234.0 if n > 7 else 300.0
	for i in n:
		var row := 0 if i < top else 1
		var idx := i if row == 0 else i - top
		var count := top if row == 0 else n - top
		var rw := count * cw + (count - 1) * gap
		var b := _char_card(_cands[i], Vector2(cw, ch))
		b.position = Vector2((W - rw) * 0.5 + idx * (cw + gap), 228.0 + row * (ch + gap))
		_grid.add_child(b)
		_cards[_cands[i]] = b
		var p := b.position
		b.position = p + Vector2(30, 46)
		b.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(b, "position", p, 0.24 * _k).set_delay(i * 0.022 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "modulate:a", 1.0, 0.14 * _k).set_delay(i * 0.022 * _k)
	var ppos := pp.position
	pp.position = ppos + Vector2(80, -40)
	pp.modulate.a = 0.0
	var tp := create_tween().set_parallel(true)
	tp.tween_property(pp, "position", ppos, 0.24 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tp.tween_property(pp, "modulate:a", 1.0, 0.16 * _k)
	Audio.sfx("whoosh")
	await _sleep((0.3 + n * 0.022) * _k)
	_busy = false
	if Game.autotest:
		await _sleep(0.9 if Game.autotest_slow else 0.3)
		_open_confirm(_culprit if _cands.has(_culprit) else _cands[0])


func _char_card(id: String, sz: Vector2) -> Button:
	var b := Button.new()
	b.size = sz
	b.pivot_offset = Vector2(sz.x * 0.5, sz.y)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _btn_style(CARD_BG, Style.AQUA_DEEP, 2))
	b.add_theme_stylebox_override("hover", _btn_style(CARD_HOVER, Style.YUZU, 4, 0.0, Color(Style.AQUA, 0.95)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.10, 0.40, 0.46, 0.98), Style.GOLD, 4))
	b.add_theme_stylebox_override("focus", _btn_style(Color(0, 0, 0, 0), Style.GOLD, 3, 0.0, Color(0, 0, 0, 0)))
	var col := Cast.color(id)
	var face := _head_box(id, "normal", Vector2(sz.x - 12, sz.y - 62), col, 2)
	face.name = "FaceBox"
	face.position = Vector2(6, 6)
	b.add_child(face)
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
	b.pressed.connect(_open_confirm.bind(id))
	b.mouse_entered.connect(_card_hover.bind(b, true))
	b.mouse_exited.connect(_card_hover.bind(b, false))
	b.focus_entered.connect(_card_hover.bind(b, true))
	b.focus_exited.connect(_card_hover.bind(b, false))
	return b


func _card_hover(b: Button, on: bool) -> void:
	if _phase != "pick":
		return
	var cap: Control = b.get_node("Caption")
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "scale", Vector2.ONE * (1.07 if on else 1.0), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(cap, "modulate:a", 1.0 if on else 0.0, 0.1)
	if on:
		b.move_to_front()
		Audio.sfx("select", randf_range(1.1, 1.3), -12.0)


# =================================================================== 3. confirm
func _open_confirm(id: String) -> void:
	if _phase != "pick" or _busy or _done:
		return
	_phase = "confirm"
	_pick = id
	Audio.sfx("confirm")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(root)
	_confirm = root
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(NEAR_BLACK, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var col := Cast.color(id)
	var slash := Control.new()
	slash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.draw.connect(func() -> void:
		slash.draw_colored_polygon(PackedVector2Array([Vector2(505, 160), Vector2(745, 160), Vector2(620, 590), Vector2(380, 590)]), Color(col, 0.22))
		slash.draw_colored_polygon(PackedVector2Array([Vector2(761, 160), Vector2(777, 160), Vector2(652, 590), Vector2(636, 590)]), Color(Style.YUZU, 0.6)))
	root.add_child(slash)
	var p := _panel(Rect2(330, 170, 620, 380), Style.YUZU, 4, 26)
	root.add_child(p)
	_kit_stripes(p, Vector2(520, 18), 5, Color(Style.YUZU, 0.6), Vector2(6, 20), 12.0)
	var face := _head_box(id, "normal", Vector2(190, 220), col, 4)
	face.position = Vector2(30, 40)
	p.add_child(face)
	var l1 := Style.label("Vote for...", 22, Style.TEXT_DIM)
	l1.position = Vector2(244, 52)
	p.add_child(l1)
	var nm := Style.title_label(Cast.full_name(id), 40, Style.GOLD, NEAR_BLACK, 10)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.position = Vector2(244, 84)
	nm.size = Vector2(350, 110)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", _fit(Style.display_font(), Cast.full_name(id), Vector2(350, 110), 40, 22))
	p.add_child(nm)
	var tl := Style.label(Cast.talent(id), 20, col.lightened(0.25))
	tl.position = Vector2(244, 196)
	p.add_child(tl)
	var l2 := Style.label("as the culprit?", 22, Style.TEXT_DIM)
	l2.position = Vector2(244, 228)
	p.add_child(l2)
	var yes := _big_button("VOTE!", Vector2(250, 66), true)
	yes.position = Vector2(330, 290)
	yes.pressed.connect(_cast_vote)
	p.add_child(yes)
	var no := _big_button("Wait...", Vector2(220, 66), false)
	no.position = Vector2(70, 290)
	no.pressed.connect(_close_confirm)
	p.add_child(no)
	p.scale = Vector2(1.3, 1.3)
	p.modulate.a = 0.0
	root.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.1 * _k)
	tw.tween_property(p, "modulate:a", 1.0, 0.1 * _k)
	tw.tween_property(p, "scale", Vector2.ONE, 0.16 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: _kit_shake(6.0, 0.18))
	if Game.autotest:
		await _sleep(1.0 if Game.autotest_slow else 0.15)
		_cast_vote()


func _close_confirm() -> void:
	if _phase != "confirm" or _confirm == null:
		return
	Audio.sfx("cancel")
	var root := _confirm
	_confirm = null
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.12 * _k)
	tw.tween_callback(root.queue_free)
	_phase = "pick"


func _cast_vote() -> void:
	if _phase != "confirm":
		return
	_phase = "spin"
	_busy = true
	Audio.sfx("gavel")
	_kit_flash(Style.GOLD, 0.4, 0.3)
	_kit_shake(10.0, 0.25)
	_compute_tally()
	var root := _confirm
	_confirm = null
	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 0.0, 0.18 * _k)
	tw.tween_property(_grid, "modulate:a", 0.0, 0.25 * _k)
	# lights down
	tw.tween_property(_dark, "modulate:a", 0.72, 0.35 * _k)
	await tw.finished
	root.queue_free()
	_grid.queue_free()
	await _spin()
	await _show_majority()
	_finish()


# =================================================================== tally rules
func _compute_tally() -> void:
	var voters := Cast.survivors().size()       # everyone alive votes, Mochi included
	_majority = _pick if _convinced else _fallback
	_tally.clear()
	var others: Array[String] = []
	for id in ["lulu", "reginald", "duchess", "pepper", "zuzu", "grub"]:
		if _cands.has(id) and id != _pick and id != _fallback:
			others.append(id)
	for id in _cands:
		if not others.has(id) and id != _pick and id != _fallback:
			others.append(id)
	if _convinced:
		# the whole group follows Mochi; the accused doesn't vote for themself
		var dissent := _fallback if _pick != _fallback else (_culprit if _culprit != _pick else others[0])
		_tally[_pick] = voters - 1
		_tally[dissent] = 1
	elif _pick == _fallback:
		_tally[_fallback] = voters - 2
		_tally[others[0]] = 1
		_tally[others[1]] = 1
	else:
		var mine := 3
		var stray := 2
		_tally[_fallback] = voters - mine - stray
		_tally[_pick] = mine
		for i in stray:
			_tally[others[i]] = 1


# =================================================================== 4. vote machine
func _spin() -> void:
	_machine = Control.new()
	_machine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_machine)
	var body := Panel.new()
	body.position = Vector2(220, 128)
	body.size = Vector2(840, 470)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", _sb(Color(0.15, 0.07, 0.30, 0.98), Style.GOLD, 6, 44, 0.0, Color(Style.AQUA_DEEP, 0.95), Vector2(14, 14)))
	_machine.add_child(body)
	_kit_stripes(body, Vector2(34, 400), 6, Color(Style.YUZU, 0.5), Vector2(8, 40), 14.0)
	_kit_stripes(body, Vector2(700, 400), 6, Color(Style.AQUA, 0.4), Vector2(8, 40), 14.0)
	var inner := Panel.new()
	inner.position = Vector2(44, 54)
	inner.size = Vector2(752, 320)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", _sb(Color(0.04, 0.02, 0.09, 1.0), Style.AQUA, 3, 26, 0.0, Color(0, 0, 0, 0)))
	body.add_child(inner)
	_bulbs = Control.new()
	_bulbs.position = body.position
	_bulbs.size = body.size
	_bulbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulbs.draw.connect(_draw_bulbs)
	_machine.add_child(_bulbs)
	# marquee sign
	var sign := Panel.new()
	sign.position = Vector2(430, 92)
	sign.size = Vector2(420, 66)
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_theme_stylebox_override("panel", _sb(Style.VIOLET.darkened(0.35), Style.GOLD, 5, 16, 0.32, HARD_SHADOW, Vector2(8, 8)))
	_machine.add_child(sign)
	var st := Style.title_label("SPLASH VOTE", 40, Style.GOLD, INK, 10)
	st.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sign.add_child(st)
	# reels (chamfered windows masked with clip_children)
	var gap := 30.0
	var x0 := 640.0 - (REEL_W * 3.0 + gap * 2.0) * 0.5
	_reels.clear()
	for r in 3:
		var win := Panel.new()
		win.position = Vector2(x0 + r * (REEL_W + gap), 196)
		win.size = Vector2(REEL_W, CELL_H)
		win.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		win.mouse_filter = Control.MOUSE_FILTER_IGNORE
		win.add_theme_stylebox_override("panel", _sb(Color(0.95, 0.92, 0.85, 1.0), Color(0, 0, 0, 0), 0, 18, 0.0, Color(0, 0, 0, 0)))
		_machine.add_child(win)
		var list: Array[String] = []
		for id in _cands:
			list.append(id)
		list.shuffle()
		var cells: Array = []
		for c in 2:
			var cell := _reel_cell(list[0])
			win.add_child(cell)
			cells.append(cell)
		var shade := Control.new()
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.draw.connect(_draw_reel_shade.bind(shade))
		win.add_child(shade)
		var frame := Panel.new()
		frame.name = "Frame"
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0), Style.AQUA_DEEP, 6, 18, 0.0, Color(0, 0, 0, 0)))
		win.add_child(frame)
		_reels.append({"win": win, "cells": cells, "ms": [-99999, -99999], "list": list,
			"offset": randf() * list.size(), "speed": 11.0 + r * 1.5, "state": "spin", "frame": frame})
	# payline arrows
	for side in [-1, 1]:
		var arrow := Control.new()
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.position = Vector2(640.0 + side * (REEL_W * 1.5 + gap + 26.0), 196 + CELL_H * 0.5)
		arrow.draw.connect(_draw_arrow.bind(arrow, side))
		_machine.add_child(arrow)
	var status_chip := Panel.new()
	status_chip.position = Vector2(400, 516)
	status_chip.size = Vector2(480, 50)
	status_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_chip.add_theme_stylebox_override("panel", _sb(Color(0.04, 0.02, 0.09, 0.95), Style.AQUA, 3, 12, 0.36, HARD_SHADOW, Vector2(6, 6)))
	_machine.add_child(status_chip)
	var status := Style.title_label("THE GROUP IS VOTING...", 26, Color.WHITE, INK, 8)
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_chip.add_child(status)
	var blink := status.create_tween().set_loops()
	blink.tween_property(status, "modulate:a", 0.35, 0.3)
	blink.tween_property(status, "modulate:a", 1.0, 0.3)
	# lever
	var lever := Control.new()
	lever.position = Vector2(1100, 380)
	lever.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lever.draw.connect(_draw_lever.bind(lever))
	_machine.add_child(lever)
	for rr in _reels:
		_update_reel(rr)
	# entrance: drops in from above and slams down under the spotlights
	_machine.position.y = -720.0
	_spot_mode = "sweep"
	_spot_target = Vector2(640, 380)
	Audio.sfx("whoosh")
	var tw := create_tween()
	tw.tween_property(_machine, "position:y", 0.0, 0.3 * _hk()).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw.finished
	Audio.sfx("gavel", 0.8)
	_kit_shake(14.0, 0.3)
	_kit_shards(Vector2(220, 598), Style.GOLD, 8, 380.0)
	_kit_shards(Vector2(1060, 598), Style.GOLD, 8, 380.0)
	# pull the lever
	lever.rotation = 0.0
	var tl := create_tween()
	tl.tween_property(lever, "rotation", 0.9, 0.16 * _hk()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tl.tween_property(lever, "rotation", 0.0, 0.35 * _hk()).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await _sleep(0.16 * _hk())
	Audio.sfx("drumroll")
	Audio.sfx("confirm")
	_phase = "spinning"
	await _sleep(1.0 * _hk())
	for r in 3:
		if r == 2:
			# suspense before the last reel: spotlights lock on, heartbeat
			Audio.sfx("heartbeat")
			_spot_mode = "focus"
			_spot_target = (_reels[2]["win"] as Control).get_global_rect().get_center()
			await _sleep(0.35 * _hk())
		await _stop_reel(_reels[r], r)
		await _sleep((0.32 if r < 2 else 0.12) * _hk())
	blink.kill()
	status.modulate.a = 1.0
	status.text = "THE GROUP HAS DECIDED!"
	status.add_theme_color_override("font_color", Style.GOLD)
	await _sleep(0.6 * _hk())
	_spot_mode = ""
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(_machine, "position:y", -760.0, 0.26 * _hk()).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw2.finished
	_machine.queue_free()
	_machine = null
	_bulbs = null
	_reels.clear()


func _reel_cell(id: String) -> Control:
	var cell := Control.new()
	cell.size = Vector2(REEL_W, CELL_H)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := _head_box(id, "normal", Vector2(REEL_W - 20, CELL_H - 62), Cast.color(id), 3)
	face.name = "FaceBox"
	face.position = Vector2(10, 10)
	cell.add_child(face)
	var plate := Panel.new()
	plate.name = "Plate"
	plate.position = Vector2(14, CELL_H - 48)
	plate.size = Vector2(REEL_W - 28, 38)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(plate)
	var nm := Style.label("", 22, Color.WHITE, true)
	nm.name = "Name"
	nm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(nm)
	_set_cell(cell, id)
	return cell


func _set_cell(cell: Control, id: String) -> void:
	var col := Cast.color(id)
	var face: Control = cell.get_node("FaceBox")
	_set_face(face, id, "normal")
	var bgc := col.darkened(0.66)
	bgc.a = 0.96
	face.add_theme_stylebox_override("panel", _sb(bgc, Color(0, 0, 0, 0), 0, 0, 0.0, Color(0, 0, 0, 0)))
	for nn in ["Frame", "Deco"]:
		var c: Control = face.get_node(nn)
		c.set_meta("col", col)
		c.queue_redraw()
	var plate: Panel = cell.get_node("Plate")
	plate.add_theme_stylebox_override("panel", _sb(col.darkened(0.15), INK, 2, 10, 0.25, Color(0, 0, 0, 0)))
	var nm: Label = cell.get_node("Plate/Name")
	nm.text = Cast.display_name(id)
	nm.add_theme_color_override("font_color", NEAR_BLACK if col.get_luminance() > 0.45 else Color.WHITE)


func _update_reel(rr: Dictionary) -> void:
	var list: Array = rr["list"]
	var n := list.size()
	var off: float = rr["offset"]
	var base := floori(off)
	var cells: Array = rr["cells"]
	var ms: Array = rr["ms"]
	for k in 2:
		var m := base + k
		var cell: Control = cells[k]
		if ms[k] != m:
			ms[k] = m
			_set_cell(cell, str(list[posmod(m, n)]))
		cell.position.y = (off - m) * CELL_H


func _stop_reel(rr: Dictionary, r: int) -> void:
	var list: Array = rr["list"]
	var n := list.size()
	var want := list.find(_majority)
	if want < 0:
		want = 0
	var last := r == 2
	# keep spinning until the majority is 3-4 cells away, then ease into it (the last reel crawls in)
	var guard := 0.0
	while true:
		var off: float = rr["offset"]
		var m := ceili(off + 2.6)
		while posmod(m, n) != want:
			m += 1
		if m - off <= 3.9 or guard > 2.5:
			rr["state"] = "stopping"
			var tw := create_tween()
			var d1 := (1.35 if last else 0.75) * maxf(_hk(), 0.3)
			tw.tween_method(_set_offset.bind(rr), off, float(m) + 0.1, d1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tw.tween_method(_set_offset.bind(rr), float(m) + 0.1, float(m), 0.08 * maxf(_hk(), 0.3)).set_trans(Tween.TRANS_SINE)
			await tw.finished
			break
		await _sleep(0.016)
		guard += 0.016
	rr["state"] = "stopped"
	# SLAM
	var frame: Panel = rr["frame"]
	frame.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0), Style.GOLD, 8, 18, 0.0, Color(0, 0, 0, 0)))
	var win: Control = rr["win"]
	win.pivot_offset = win.size * 0.5
	win.scale = Vector2(1.16, 1.16)
	win.create_tween().tween_property(win, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var c := win.get_global_rect().get_center()
	Audio.sfx("gavel", 1.2 - r * 0.15, -2.0 + r * 2.0)
	Audio.sfx("confirm", 0.9 + r * 0.15)
	_kit_shake(8.0 + r * 5.0, 0.24 + r * 0.06)
	_kit_flash(Color.WHITE if last else Style.GOLD.lerp(Color.WHITE, 0.6), 0.55 if last else 0.25, 0.22)
	_kit_shards(c, Style.GOLD, 10 + r * 6, 420.0 + r * 120.0)
	_kit_ring(c, Style.GOLD, 160.0 + r * 60.0, 0.35)
	if last:
		_kit_speedlines(c, Color(1.0, 0.95, 0.8, 0.6), 0.45, 170.0)
		_spot_boost = 1.0


func _set_offset(v: float, rr: Dictionary) -> void:
	var before := floori(float(rr["offset"]))
	rr["offset"] = v
	if floori(v) != before:
		_slot_tick()
	_update_reel(rr)


func _slot_tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_slot_ms < 45:
		return
	_last_slot_ms = now
	Audio.sfx("slot", randf_range(0.95, 1.08), -4.0)


func _draw_reel_shade(c: Control) -> void:
	var sz := c.size
	var dark := Color(0.05, 0.02, 0.1, 0.6)
	var clear := Color(0.05, 0.02, 0.1, 0.0)
	var e := sz.y * 0.13
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, e), Vector2(0, e)]), PackedColorArray([dark, dark, clear, clear]))
	c.draw_polygon(PackedVector2Array([Vector2(0, sz.y - e), Vector2(sz.x, sz.y - e), Vector2(sz.x, sz.y), Vector2(0, sz.y)]), PackedColorArray([clear, clear, dark, dark]))
	c.draw_colored_polygon(PackedVector2Array([Vector2(sz.x * 0.6, 0), Vector2(sz.x * 0.75, 0), Vector2(sz.x * 0.35, sz.y), Vector2(sz.x * 0.2, sz.y)]), Color(1, 1, 1, 0.07))


func _draw_arrow(c: Control, side: int) -> void:
	var s := float(side)
	var pts := PackedVector2Array([Vector2(-s * 20, -22), Vector2(s * 16, 0), Vector2(-s * 20, 22), Vector2(-s * 10, 0)])
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(4, 4))
	c.draw_colored_polygon(sh, HARD_SHADOW)
	c.draw_colored_polygon(pts, Style.GOLD)
	pts.append(pts[0])
	c.draw_polyline(pts, INK, 3.0, true)


func _draw_lever(c: Control) -> void:
	c.draw_colored_polygon(PackedVector2Array([Vector2(-10, -6), Vector2(30, -6), Vector2(26, 64), Vector2(-14, 64)]), Color(0.35, 0.2, 0.55))
	c.draw_polyline(PackedVector2Array([Vector2(-10, -6), Vector2(30, -6), Vector2(26, 64), Vector2(-14, 64), Vector2(-10, -6)]), Style.GOLD, 3.0, true)
	c.draw_line(Vector2(0, 0), Vector2(0, -150), Color(0.75, 0.75, 0.82), 12.0, true)
	c.draw_line(Vector2(-3, 0), Vector2(-3, -150), Color(1, 1, 1, 0.5), 3.0, true)
	var knob := PackedVector2Array()
	for i in 6:
		knob.append(Vector2(0, -160) + Vector2.from_angle(i * TAU / 6.0 + 0.5) * 26.0)
	c.draw_colored_polygon(knob, Style.DANGER)
	c.draw_circle(Vector2(-8, -168), 7.0, Color(1, 1, 1, 0.6))
	knob.append(knob[0])
	c.draw_polyline(knob, INK, 3.0, true)


## Diamond marquee lights chasing around the machine.
func _draw_bulbs() -> void:
	var sz := _bulbs.size
	var pts: Array[Vector2] = []
	var step := 42.0
	var x := 54.0
	while x <= sz.x - 54.0:
		pts.append(Vector2(x, 22))
		pts.append(Vector2(x, sz.y - 22))
		x += step
	var y := 70.0
	while y <= sz.y - 70.0:
		pts.append(Vector2(22, y))
		pts.append(Vector2(sz.x - 22, y))
		y += step
	var spinning := _phase == "spinning" or _phase == "spin"
	for i in pts.size():
		var on := (int(_time * (12.0 if spinning else 3.0)) + i) % 2 == 0
		var col := Style.GOLD if on else Color(0.45, 0.30, 0.2)
		var p := pts[i]
		if on:
			_bulbs.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12), p + Vector2(12, 0), p + Vector2(0, 12), p + Vector2(-12, 0)]), Color(Style.GOLD, 0.22))
		_bulbs.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]), col)
		_bulbs.draw_colored_polygon(PackedVector2Array([p + Vector2(-1, -5), p + Vector2(1, -3), p + Vector2(-1, -1), p + Vector2(-3, -3)]), Color(1, 1, 1, 0.7 if on else 0.2))


## Spotlight cones from the ceiling: sweeping during the spin, locked on the target for suspense.
func _draw_spots() -> void:
	if _spot_mode == "" and _spot_boost <= 0.0:
		return
	var srcs := [Vector2(170, -40), Vector2(W - 170, -40)]
	for i in 2:
		var src: Vector2 = srcs[i]
		var tgt := _spot_target
		if _spot_mode == "sweep":
			tgt += Vector2(sin(_time * 1.7 + i * 2.1) * 330.0, cos(_time * 1.3 + i) * 50.0)
		var dir := (tgt - src).normalized()
		var side := Vector2(-dir.y, dir.x)
		var far := src + dir * 980.0
		var a := (0.16 if _spot_mode != "" else 0.0) + 0.22 * _spot_boost
		var top := Color(1.0, 0.95, 0.80, a)
		var bot := Color(1.0, 0.95, 0.80, 0.0)
		_spot.draw_polygon(PackedVector2Array([src - side * 16.0, src + side * 16.0, far + side * 210.0, far - side * 210.0]),
			PackedColorArray([top, top, bot, bot]))
		# pool of light on the target
		var pool := PackedVector2Array()
		for k in 16:
			pool.append(tgt + Vector2(cos(k * TAU / 16.0) * 170.0, sin(k * TAU / 16.0) * 40.0) + Vector2(0, 150))
		_spot.draw_colored_polygon(pool, Color(1.0, 0.95, 0.8, a * 0.35))


# =================================================================== 5. majority reveal + tally
func _show_majority() -> void:
	_phase = "tally"
	var col := Cast.color(_majority)
	_lines_center = Vector2(930, 330)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(root)
	_lines = Control.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.set_meta("col", col)
	_lines.draw.connect(_draw_reveal_lines)
	_lines.modulate.a = 0.0
	root.add_child(_lines)
	var por := TextureRect.new()
	por.texture = Assets.portrait(_majority, "shock")
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	por.size = Assets.PORTRAIT_SIZE
	por.pivot_offset = Vector2(por.size.x * 0.5, por.size.y * 0.42)
	var final_pos := Vector2(_lines_center.x - por.size.x * 0.5, H - por.size.y + 30)
	por.position = Vector2(W * 0.5 - por.size.x * 0.5, H * 0.5 - por.size.y * 0.42)
	por.scale = Vector2(0.12, 0.12)
	por.modulate.a = 0.0
	por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(por)
	# ZOOM: the majority's portrait rushes at the camera, lands with a hit
	_spot_target = _lines_center
	_spot_mode = "focus"
	_spot_boost = 1.0
	Audio.sfx("whoosh")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(por, "scale", Vector2(1.18, 1.18), 0.26 * _hk()).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(por, "position", final_pos, 0.26 * _hk()).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(por, "modulate:a", 1.0, 0.1 * _hk())
	tw.tween_property(_lines, "modulate:a", 1.0, 0.2 * _hk())
	await tw.finished
	Audio.sfx("shout", 1.0, -3.0)
	Audio.sfx("gavel")
	_kit_flash(Color.WHITE, 0.85, 0.3)
	_kit_shake(18.0, 0.35)
	_kit_shards(_lines_center, col.lightened(0.3), 22, 640.0)
	_kit_ring(_lines_center, Style.GOLD, 380.0, 0.45)
	var settle := create_tween()
	settle.tween_property(por, "scale", Vector2.ONE, 0.22 * _hk()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _sleep(0.12 * _hk())
	_kit_stamp("MAJORITY: " + Cast.display_name(_majority).to_upper(), Style.GOLD, Vector2(W * 0.5 + 40, 618), 72)
	await _sleep(0.5 * _hk())
	await _show_tally(root)
	await _sleep(0.4 * _hk())
	var more := Style.label("click to continue  ▼", 16, Style.YUZU)
	more.position = Vector2(W - 260, H - 30)
	more.size = Vector2(230, 22)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_overlay.add_child(more)
	await _await_click()


func _draw_reveal_lines() -> void:
	var c := _lines_center
	var col: Color = _lines.get_meta("col", Style.GOLD)
	var n := 14
	for i in n:
		var a0 := _time * 0.2 + i * TAU / n
		var a1 := a0 + TAU / n * 0.42
		_lines.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * 1600.0, c + Vector2.from_angle(a1) * 1600.0]),
			Color(col if i % 2 == 0 else Style.GOLD, 0.13 if i % 2 == 0 else 0.06))
	var frame := int(_time * 24.0)
	for i in 44:
		var h := _kit_hash(i * 13 + frame * 7)
		var h2 := _kit_hash(i * 31 + frame * 11)
		var a := (i + h * 0.8) * TAU / 44.0
		var r0 := 250.0 + h2 * 170.0
		var wd := 0.004 + 0.01 * h
		_lines.draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * r0, c + Vector2.from_angle(a - wd) * 1700.0,
			c + Vector2.from_angle(a + wd) * 1700.0]), Color(1.0, 0.97, 0.9, 0.10 + 0.24 * h2))


func _show_tally(root: Control) -> void:
	var ids: Array = _tally.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return int(_tally[a]) > int(_tally[b]))
	var total := 0
	for id in ids:
		total += int(_tally[id])
	var row_h := 62.0
	var ph := 110.0 + ids.size() * row_h + 30.0
	var pr := Rect2(40, 92, 660, ph)
	var p := _panel(pr, Style.AQUA, 4, 26)
	root.add_child(p)
	_kit_stripes(p, Vector2(560, 20), 5, Color(Style.AQUA, 0.45), Vector2(6, 22), 12.0)
	var title := Style.title_label("THE VOTES ARE IN!", 40, Style.GOLD, NEAR_BLACK, 10)
	title.position = Vector2(0, 16)
	title.size = Vector2(pr.size.x, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(title)
	var tl := Style.label("%d votes cast" % total, 17, Style.TEXT_DIM)
	tl.position = Vector2(0, 70)
	tl.size = Vector2(pr.size.x, 24)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(tl)
	p.position.x = -720.0
	Audio.sfx("whoosh")
	var tw := create_tween()
	tw.tween_property(p, "position:x", pr.position.x, 0.24 * _hk()).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_kit_hlines(Rect2(0, pr.position.y, W * 0.6, ph), Color(Style.AQUA, 0.45), 0.3, 12)
	await _sleep(0.3 * _hk())
	var max_c := 1
	for id in ids:
		max_c = maxi(max_c, int(_tally[id]))
	var bar_x := 250.0
	var bar_max := 300.0
	for i in ids.size():
		var id: String = ids[i]
		var cnt := int(_tally[id])
		var col := Cast.color(id)
		var y := 104.0 + i * row_h
		var face := _head_box(id, "normal", Vector2(52, 52), col, 2)
		face.position = Vector2(28, y)
		p.add_child(face)
		var nm := Style.label(Cast.display_name(id), 24, Color.WHITE, true)
		nm.position = Vector2(94, y + 10)
		nm.size = Vector2(150, 32)
		nm.add_theme_font_size_override("font_size", _fit(Style.display_font(), Cast.display_name(id), Vector2(150, 32), 24, 14))
		p.add_child(nm)
		var bar := Control.new()
		bar.position = Vector2(bar_x, y + 10)
		bar.size = Vector2(bar_max + 30, 34)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_meta("f", 0.0)
		bar.draw.connect(_draw_tally_bar.bind(bar, col, bar_max))
		p.add_child(bar)
		var cl := Style.title_label("0", 30, Style.GOLD if id == _majority else Color.WHITE, NEAR_BLACK, 8)
		cl.position = Vector2(bar_x + bar_max + 40, y + 4)
		cl.size = Vector2(70, 44)
		cl.pivot_offset = Vector2(20, 22)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(cl)
		face.modulate.a = 0.0
		nm.modulate.a = 0.0
		var tr := create_tween().set_parallel(true)
		tr.tween_property(face, "modulate:a", 1.0, 0.12 * _hk())
		tr.tween_property(nm, "modulate:a", 1.0, 0.12 * _hk())
		var dur := (0.22 + 0.03 * cnt) * _hk()
		tr.tween_method(_set_bar.bind(bar), 0.0, maxf(0.03, cnt / float(max_c)), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tr.tween_method(_count_up.bind(cl), 0.0, float(cnt), dur)
		await tr.finished
		cl.scale = Vector2(1.5, 1.5)
		cl.create_tween().tween_property(cl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		Audio.sfx("tick", 1.0 + i * 0.1)
		if id == _majority:
			_kit_shake(5.0, 0.15)
			_kit_shards(p.position + bar.position + Vector2(bar_max * cnt / float(max_c), 17), Style.GOLD, 8, 300.0)
		await _sleep(0.08 * _hk())


func _set_bar(v: float, bar: Control) -> void:
	bar.set_meta("f", v)
	bar.queue_redraw()


func _draw_tally_bar(bar: Control, col: Color, bar_max: float) -> void:
	var h := bar.size.y
	var s := 14.0
	var q := PackedVector2Array([Vector2(s, 0), Vector2(bar_max + s, 0), Vector2(bar_max, h), Vector2(0, h)])
	bar.draw_colored_polygon(q, Color(0.02, 0.01, 0.06, 1.0))
	var f: float = bar.get_meta("f", 0.0)
	var fw := bar_max * f
	if fw > 1.0:
		var sh := PackedVector2Array([Vector2(s + 5, 5), Vector2(s + fw + 5, 5), Vector2(fw + 5, h + 5), Vector2(5, h + 5)])
		bar.draw_colored_polygon(sh, HARD_SHADOW)
		bar.draw_colored_polygon(PackedVector2Array([Vector2(s, 0), Vector2(s + fw, 0), Vector2(fw, h), Vector2(0, h)]), col)
		bar.draw_colored_polygon(PackedVector2Array([Vector2(s, 0), Vector2(s + fw, 0), Vector2(s + fw - 3, 7), Vector2(s - 3, 7)]), Color(1, 1, 1, 0.3))
	q.append(q[0])
	bar.draw_polyline(q, Style.AQUA_DEEP, 2.0, true)


func _count_up(v: float, l: Label) -> void:
	var t := str(roundi(v))
	if l.text != t:
		l.text = t
		_slot_tick()


func _finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25 * _k)
	await tw.finished
	finished.emit({"flags": {"vote_correct": _majority == _culprit, "voted": _pick, "majority": _majority}})


# =================================================================== frame
func _process(delta: float) -> void:
	_time += delta
	_kit_tick(delta)
	for rr in _reels:
		if rr["state"] == "spin" and _phase == "spinning":
			var before := floori(float(rr["offset"]))
			rr["offset"] = float(rr["offset"]) + float(rr["speed"]) * delta
			if floori(float(rr["offset"])) != before:
				_slot_tick()
			_update_reel(rr)
	if _bulbs and is_instance_valid(_bulbs):
		_bulbs.queue_redraw()
	if _lines and is_instance_valid(_lines):
		_lines.queue_redraw()
	if _spot_boost > 0.0:
		_spot_boost = maxf(0.0, _spot_boost - delta * 1.6)
	var spot_on := _spot_mode != "" or _spot_boost > 0.0
	if spot_on or _spot_drawn:
		_spot.queue_redraw()
	_spot_drawn = spot_on


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
