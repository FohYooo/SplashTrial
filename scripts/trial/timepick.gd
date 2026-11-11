extends "res://scripts/trial/trial_common.gd"
## TIME PICK (trial data type "time_pick"): set a moment, or a window, on a timeline of the evening.
## data: title, speaker, expr, prompt, wrong {speaker, expr, text},
##   from, to   the ends of the timeline ("7:00 PM", "12:30 AM")
##   step       minutes between positions (default 5)
##   answer     "8:05 PM" for one handle, or ["8:05 PM", "9:15 PM"] for a window
##   tolerance  minutes either side still accepted (default 0)
## Right: REWARD_TIME. Wrong: PENALTY_TIME and try again.
## Controls: drag a handle, Left/Right moves the active handle, Tab switches handle, Space/Enter confirms.

const Alibis := preload("res://scripts/data/alibis.gd")

const BAR := Rect2(120, 430, 1040, 14)

var _t0 := 0
var _t1 := 0
var _step := 5
var _tol := 0
var _answers: Array = []     # minutes, one or two
var _vals: Array = []        # the handles' positions, in minutes
var _active := 0
var _state := "intro"
var _drag := -1
var _readout: Label
var _line: TimeLine
var _ok: Button
var _wrong_i := 0


func _ready() -> void:
	_build_common(Style.AQUA)
	_step = maxi(1, int(data.get("step", 5)))
	_tol = int(data.get("tolerance", 0))
	_t0 = Alibis.minutes(str(data.get("from", "6:00 PM")))
	_t1 = Alibis.minutes(str(data.get("to", "12:00 AM")))
	var ans: Variant = data.get("answer", "")
	var list: Array = ans if typeof(ans) == TYPE_ARRAY else [ans]
	for a in list:
		_answers.append(Alibis.minutes(str(a)))
	_answers.sort()
	for i in _answers.size():
		_vals.append(_t0 + (_t1 - _t0) * (i + 1) / (_answers.size() + 1))
		_vals[i] = _snap(_vals[i])
	var badge := _hud_badge(str(data.get("title", "WHAT TIME?")), Style.AQUA, 30)
	badge.position = Vector2(16, 8)
	_hud.add_child(badge)
	_build_ui()
	_run.call_deferred()


func _run() -> void:
	await _banner_sweep(str(data.get("title", "WHAT TIME?")), "Set the time on the line, then confirm.", Style.AQUA)
	if _gone():
		return
	_state = "pick"
	if Game.autotest:
		_autoplay()


func _build_ui() -> void:
	var who := str(data.get("speaker", "mochi"))
	var p := _make_portrait(who, str(data.get("expr", "normal")), 0.56)
	p.position = Vector2(30, 92)
	_stage.add_child(p)
	var prompt := str(data.get("prompt", ""))
	var box := _slant(Vector2(900, 214), Color(0.06, 0.035, 0.14, 0.97), Cast.color(who), 3.0, 18.0, 14.0, 4, Color(INK, 0.95), Vector2(8, 8))
	box.position = Vector2(330, 112)
	_stage.add_child(box)
	var tag := _make_name_tag(who, 24)
	tag.position = Vector2(24, -18)
	box.add_child(tag)
	var l := Label.new()
	l.text = prompt
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(30, 34)
	l.size = Vector2(840, 168)
	l.add_theme_font_size_override("font_size", 25)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	_line = TimeLine.new()
	_line.host = self
	_line.position = Vector2.ZERO
	_line.size = Vector2(W, H)
	_stage.add_child(_line)
	_readout = Style.title_label("", 46, Style.GOLD, Style.BG_DARK, 10)
	_readout.size = Vector2(W, 64)
	_readout.position = Vector2(0, 500)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_readout)
	_ok = Style.button("That's when!  [Enter]", Vector2(320, 62), 24)
	_ok.position = Vector2((W - 320.0) * 0.5, 584)
	_ok.size = Vector2(320, 62)
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.pressed.connect(_confirm)
	_ui.add_child(_ok)
	var tip := Style.label("Drag the marker%s, or use Left / Right%s." % ["s" if _vals.size() > 1 else "", " and Tab" if _vals.size() > 1 else ""], 16, Style.TEXT_DIM)
	tip.size = Vector2(W, 24)
	tip.position = Vector2(0, 656)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(tip)
	_refresh()


# =================================================================== time helpers
func _snap(m: int) -> int:
	return clampi(_t0 + roundi(float(m - _t0) / _step) * _step, _t0, _t1)


static func clock(m: int) -> String:
	var total := posmod(m, 1440)
	var h := (total / 60) % 12
	var pm := total < 720
	return "%d:%02d %s" % [12 if h == 0 else h, total % 60, "PM" if pm else "AM"]


func _x(m: int) -> float:
	return BAR.position.x + BAR.size.x * float(m - _t0) / maxf(float(_t1 - _t0), 1.0)


func _m_at(x: float) -> int:
	return _snap(_t0 + roundi((x - BAR.position.x) / BAR.size.x * (_t1 - _t0)))


func _set_val(i: int, m: int) -> void:
	_vals[i] = _snap(m)
	if _vals.size() == 2:
		if i == 0:
			_vals[0] = mini(int(_vals[0]), int(_vals[1]))
		else:
			_vals[1] = maxi(int(_vals[1]), int(_vals[0]))
	_refresh()


func _refresh() -> void:
	if _vals.size() == 2:
		_readout.text = "%s  to  %s" % [clock(int(_vals[0])), clock(int(_vals[1]))]
	else:
		_readout.text = clock(int(_vals[0])) if not _vals.is_empty() else ""
	if _line:
		_line.queue_redraw()


# =================================================================== input
func _on_left_click(pos: Vector2) -> void:
	if _state != "pick":
		return
	if absf(pos.y - BAR.get_center().y) > 60.0:
		return
	var best := 0
	for i in _vals.size():
		if absf(pos.x - _x(int(_vals[i]))) < absf(pos.x - _x(int(_vals[best]))):
			best = i
	_drag = best
	_active = best
	_set_val(best, _m_at(pos.x))


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		_drag = -1
	var mm := e as InputEventMouseMotion
	if mm and _drag >= 0 and _state == "pick":
		_set_val(_drag, _m_at(mm.global_position.x))
	super(e)


func _on_action() -> void:
	_confirm()


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k and k.pressed and _state == "pick" and not _vals.is_empty():
		match k.keycode:
			KEY_LEFT, KEY_A:
				_set_val(_active, int(_vals[_active]) - _step)
				Audio.sfx("tick", 1.2, -10.0)
				get_viewport().set_input_as_handled()
				return
			KEY_RIGHT, KEY_D:
				_set_val(_active, int(_vals[_active]) + _step)
				Audio.sfx("tick", 1.2, -10.0)
				get_viewport().set_input_as_handled()
				return
			KEY_TAB:
				if not k.echo:
					_active = (_active + 1) % _vals.size()
					_refresh()
				get_viewport().set_input_as_handled()
				return
	super(e)


# =================================================================== answering
func _right_now() -> bool:
	for i in _vals.size():
		if absi(int(_vals[i]) - int(_answers[i])) > _tol:
			return false
	return true


func _confirm() -> void:
	if _state != "pick":
		return
	_state = "busy"
	_drag = -1
	Audio.sfx("confirm")
	await _wait(_fxd(0.18))
	if _gone():
		return
	if _right_now():
		Audio.sfx("break")
		Audio.sfx("correct")
		_flash(Color("bff8ff"), 0.4, 0.3)
		_shake(14.0, 0.35)
		Game.reward(Game.REWARD_TIME)
		_pop_text("THAT'S WHEN!", Vector2(W * 0.5, 470), 62, Style.GOLD, -4.0, 0.7)
		await _wait(_fxd(1.2))
		if not _gone():
			_finish({})
		return
	Audio.sfx("wrong")
	Audio.sfx("static", 1.0, -8.0)
	_glitch(_fxd(0.32), 1.0)
	_flash(Style.DANGER, 0.4, 0.34)
	_shake(14.0, 0.32)
	_pop_text("WRONG!", Vector2(W * 0.5, 470), 58, Style.DANGER, -5.0, 0.4)
	Game.mistake(Game.PENALTY_TIME)
	var wl: Variant = data.get("wrong", {})
	if typeof(wl) == TYPE_DICTIONARY and not (wl as Dictionary).is_empty():
		var d: Dictionary = wl
		await _say_box(str(d.get("speaker", data.get("speaker", "mochi"))), str(d.get("expr", "normal")), str(d.get("text", "")), Vector2(240, 548), 820.0, _fxd(3.0), _fxd(0.4))
	else:
		await _wait(_fxd(0.8))
	if not _gone():
		_state = "pick"


# =================================================================== autotest
func _autoplay() -> void:
	await _wait(0.1)
	if _gone():
		return
	if Game.debug_minigame != "":
		_set_val(0, int(_answers[0]) + _step * 2 + _tol)
		if _vals.size() == 2:
			_set_val(1, int(_answers[1]) + _step * 2 + _tol)
		_confirm()
		while not _gone() and _state == "busy":
			await _frame
		if _gone():
			return
		_active = 0
	for i in range(_vals.size() - 1, -1, -1):
		_vals[i] = int(_answers[i])
	_refresh()
	_confirm()


# =================================================================== the line
class TimeLine extends Control:
	var host: Variant

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var b: Rect2 = host.BAR
		Style.draw_shape(self, Style.slant_poly(b.grow(4.0), 8.0), Color(0.05, 0.03, 0.12, 0.98), Style.AQUA_DEEP, 2.0, Color(INK, 0.9), Vector2(5, 5))
		var font := Style.body_font()
		var m: int = host._t0
		while m <= host._t1:
			var x: float = host._x(m)
			var hour: bool = posmod(m, 60) == 0
			var tall := 16.0 if hour else 7.0
			draw_line(Vector2(x, b.position.y - tall), Vector2(x, b.position.y), Color(Style.AQUA, 0.8 if hour else 0.3), 2.0 if hour else 1.0)
			if hour:
				var txt: String = host.clock(m).replace(":00", "")
				draw_string(font, Vector2(x - 40.0, b.position.y - 22.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 15, Style.TEXT_DIM)
			m += 15 if host._step <= 15 else host._step
		var vals: Array = host._vals
		if vals.size() == 2:
			var x0: float = host._x(int(vals[0]))
			var x1: float = host._x(int(vals[1]))
			draw_rect(Rect2(x0, b.position.y, x1 - x0, b.size.y), Color(Style.YUZU, 0.7))
		for i in vals.size():
			var x: float = host._x(int(vals[i]))
			var c := Vector2(x, b.get_center().y)
			var on: bool = i == host._active
			var col: Color = Style.GOLD if on else Style.YUZU.darkened(0.2)
			var tri := PackedVector2Array([c + Vector2(0, 12), c + Vector2(-17, 46), c + Vector2(17, 46)])
			draw_colored_polygon(tri, col)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), INK, 3.0, true)
			draw_line(c + Vector2(0, -16), c + Vector2(0, 14), col, 4.0)
