extends "res://scripts/trial/trial_common.gd"
## SPLASH DEBATE (trial data type "debate").
## Statements fly in one at a time from a vanishing point in the distance (small, faint, leaning), rush
## toward the camera to full size, drift, then rush past the camera or slash off sideways - looping.
## The speaker slashes in on the opposite side through a diagonal wipe with speed lines.
## {Weak spots} glow yuzu-orange; the player loads a Truth Drop (click / number keys / wheel) and clicks a
## weak spot to fire a water shot. Correct spot + drop -> freeze-frame, crack, SCREEN SHATTER, banner.
## Wrong -> glitch + coral flash + shake + mistake + the data's "wrong" line.
## Each full loop without success -> no penalty (only wrong shots cost convince); after the chapter's "hint_loops" the hint
## thought-bubble appears, or, with "hint_on_request", a button offers it for Game.HINT_COST. A Drop listed under the segment's
## "early" is right but too soon: no cost, and a bonus when it comes up for real. V opens the loaded Drop's pictures.
## Skills: scoop_sense (answer sparkles after the first loop), power_nap (durations x Game.timer_scale()).

const FLY_IN := 0.36
const FLY_OUT := 0.28
const VP_Y := 228.0          # vanishing point height (statements emerge from the far pool)

var _statements: Array = []
var _ans_stmt := 0
var _ans_weak := 0
var _ans_drop := ""
var _state := "intro"     # intro, play, firing, wrong, loopend, won
var _si := 0
var _st := 0.0
var _sdur := 3.2
var _durs: Array = []
var _loop_total := 1.0
var _loop := 0
var _hint_shown := false
var _scoop_popped := false
var _wrong_i := 0
var _fire_cd := 0.0
var _tick_i := -1
var _landed := false

var _view: StatementView
var _home := Vector2.ZERO
var _from := Vector2.ZERO
var _drift := Vector2.ZERO
var _exit_dir := Vector2.ZERO
var _exit_mode := 0
var _rot0 := 0.0
var _skew0 := 0.0
var _side := 0
var _portrait: CutPortrait
var _plate: Slant
var _glow: TextureRect
var _tag: Slant
var _speaker := ""

var _loop_label: Label
var _count_label: Label
var _bar: SegBar
var _hud_cache := ""
var _hint_btn: Button


func _ready() -> void:
	_build_common(Style.AQUA)
	_statements = data.get("statements", [])
	var ans: Dictionary = data.get("answer", {})
	_ans_stmt = int(ans.get("statement", 0))
	_ans_weak = int(ans.get("weak", 0))
	_ans_drop = str(ans.get("drop", ""))
	if _statements.is_empty():
		push_warning("debate: no statements in '%s'" % str(data.get("id", "")))
		_finish.call_deferred({})
		return
	_ans_stmt = clampi(_ans_stmt, 0, _statements.size() - 1)
	_loop_total = 0.0
	for i in _statements.size():
		var d := _stmt_duration(i)
		_durs.append(d)
		_loop_total += d
	_build_hud()
	_build_drop_panel(_ammo_list(data.get("drops", [])))
	_run.call_deferred()


func _stmt_duration(i: int) -> float:
	var s: Dictionary = _statements[i]
	var txt := str(s.get("text", ""))
	return clampf(2.5 + txt.length() * 0.011, 3.0, 3.8) * Game.timer_scale()


func _run() -> void:
	var title := str(data.get("title", "SPLASH DEBATE"))
	await _banner_sweep(title, "Load a Truth Drop and shoot the glowing lie!", Style.AQUA)
	if _gone():
		return
	_show_drop_panel()
	_aim_enabled = true
	_state = "play"
	_start_statement(0)
	if Game.autotest:
		_autoplay()


# =================================================================== HUD
func _build_hud() -> void:
	var title := str(data.get("title", "SPLASH DEBATE"))
	var badge := _hud_badge(title, Style.AQUA, 30)
	badge.position = Vector2(16, 8)
	_hud.add_child(badge)
	_skill_tags(["scoop_sense", "power_nap"], Vector2(22, 60))
	var lp := _slant(Vector2(362, 62), PANEL_BG, Style.AQUA_DEEP, 3.0, 16.0, 10.0, 3, Color(INK, 0.92), Vector2(6, 6))
	lp.stripe_col = Color(Style.AQUA, 0.18)
	lp.refresh()
	lp.position = Vector2(898, 8)
	_hud.add_child(lp)
	_loop_label = _hard_shadow(Style.title_label("LOOP 1", 19, Style.AQUA, Style.BG_DARK, 5), Vector2(2, 3), INK)
	_loop_label.position = Vector2(26, 4)
	_loop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.add_child(_loop_label)
	_count_label = Style.label("STATEMENT 1 / %d" % _statements.size(), 14, Style.TEXT_DIM, true)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.size = Vector2(196, 20)
	_count_label.position = Vector2(112, 8)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.add_child(_count_label)
	_bar = SegBar.new()
	_bar.position = Vector2(22, 34)
	_bar.size = Vector2(310, 16)
	_bar.durs = _durs
	_bar.total = _loop_total
	lp.add_child(_bar)
	if bool(Chapters.get_value("hint_on_request", false)) and str(data.get("hint", "")) != "":
		_hint_btn = Style.button("Ask Mochi's hunch  (-%d%%)  [H]" % roundi(Game.HINT_COST), Vector2(290, 36), 14)
		_hint_btn.position = Vector2(960, 78)
		_hint_btn.size = Vector2(290, 36)
		_hint_btn.focus_mode = Control.FOCUS_NONE
		_hint_btn.pressed.connect(_ask_hint)
		_hud.add_child(_hint_btn)
		_ui_rects.append(Rect2(_hint_btn.position, _hint_btn.size))


func _update_hud() -> void:
	if _bar == null:
		return
	var el := 0.0
	for i in mini(_si, _durs.size()):
		el += float(_durs[i])
	el += minf(_st, _sdur)
	if _state == "intro" or _state == "loopend":
		el = 0.0
	var k := clampf(el / _loop_total, 0.0, 1.0)
	var col := Style.AQUA.lerp(Style.YUZU, clampf(k * 1.6 - 0.4, 0.0, 1.0)).lerp(Style.DANGER, clampf(k * 4.0 - 3.0, 0.0, 1.0))
	_bar.set_state(k, _si, _state != "loopend" and _state != "intro", col)
	var key := "%d/%d" % [_loop, _si]
	if key != _hud_cache:
		_hud_cache = key
		_loop_label.text = "LOOP %d" % (_loop + 1)
		_count_label.text = "STATEMENT %d / %d" % [_si + 1, _statements.size()]


# =================================================================== statements
func _start_statement(i: int) -> void:
	_si = i
	_st = 0.0
	_tick_i = -1
	_landed = false
	_sdur = float(_durs[i])
	var s: Dictionary = _statements[i]
	var text := str(s.get("text", ""))
	Game.log_say(str(s.get("speaker", "")), text, true)
	_side = i % 2
	_show_speaker(str(s.get("speaker", "")), str(s.get("expr", "normal")), _side)
	if _view and is_instance_valid(_view):
		_view.queue_free()
	_view = _new_statement()
	var fs := 42 if text.length() < 66 else 38
	_view.build(text, 720.0, fs, Style.display_font())
	_stage.add_child(_view)
	var cx := 832.0 if _side == 0 else 448.0
	_home = Vector2(cx, 330.0) - _view.size * 0.5
	var vp := Vector2(lerpf(640.0, cx, 0.3), VP_Y)
	_from = vp - _view.size * 0.5
	var lean := 1.0 if _side == 0 else -1.0
	_rot0 = deg_to_rad(randf_range(2.2, 4.0)) * (1.0 if randf() < 0.5 else -1.0)
	_skew0 = 0.34 * lean
	_drift = Vector2(-lean * randf_range(22.0, 40.0), randf_range(-12.0, 12.0))
	_exit_mode = 0 if randf() < 0.55 else 1
	var c := _home + _view.size * 0.5
	_exit_dir = (c - Vector2(W * 0.5, 300.0)).normalized()
	if _exit_dir == Vector2.ZERO:
		_exit_dir = Vector2(lean, 0.0)
	_view.ghost_off = (_from - _home).normalized() * 26.0
	_view.sparkle_weak = _ans_weak if (_scoop_on() and i == _ans_stmt) else -1
	_update_view()
	Audio.sfx("whoosh", randf_range(1.05, 1.3), -10.0)
	if _view.sparkle_weak >= 0 and not _scoop_popped:
		_scoop_popped = true
		_scoop_pop.call_deferred()


func _scoop_pop() -> void:
	await _wait(0.45)
	if _gone() or _view == null or _view.sparkle_weak < 0:
		return
	var top: Vector2 = _view.full_xf() * Vector2(_view.size.x * 0.5, 4.0)
	_pop_text("SCOOP SENSE!", top + Vector2(0, -16), 26, Style.GOLD, -4.0, 0.8)
	Audio.sfx("correct", 1.3, -8.0)


func _scoop_on() -> bool:
	return Game.has_skill("scoop_sense") and _loop >= 1


func _show_speaker(id: String, expr: String, side: int) -> void:
	_speaker = id
	for n in [_portrait, _plate, _glow, _tag]:
		if is_instance_valid(n):
			var c: Control = n
			var away := -110.0 if c.position.x + c.size.x * 0.5 < W * 0.5 else 110.0
			var tw0 := create_tween()
			tw0.set_parallel(true)
			tw0.tween_property(c, "modulate:a", 0.0, 0.12)
			tw0.tween_property(c, "position:x", c.position.x + away, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw0.chain().tween_callback(c.queue_free)
	_portrait = null
	_plate = null
	_glow = null
	_tag = null
	if id == "" or id == "mochi":
		return
	var col := Cast.color(id)
	var p := _make_portrait(id, expr, 0.9)
	var px := -14.0 if side == 0 else W - p.size.x + 14.0
	var py := H - p.size.y + 8.0
	var dir := 1.0 if side == 0 else -1.0
	# soft color glow + tall slanted color plate behind the bust
	_glow = _make_glow(col, 620.0, 0.3)
	_glow.position = Vector2(px + p.size.x * 0.5 - 310.0, py + 200.0 - 310.0)
	_glow.modulate.a = 0.0
	_stage.add_child(_glow)
	var plate := _slant(Vector2(300, 470), Color(col.lerp(Style.VIOLET, 0.4).darkened(0.35), 0.78), Color(col.lerp(Style.AQUA, 0.2).lightened(0.3), 1.0), 5.0, 90.0 * dir, 0.0, 5,
		Color(INK, 0.8), Vector2(12 * dir, 12))
	plate.stripe_col = Color(col.lightened(0.5), 0.4)
	plate.inner = Color(1, 1, 1, 0.35)
	plate.stripe_left = side == 1
	plate.refresh()
	var plate_x := px + p.size.x * 0.5 - 150.0 + 26.0 * dir
	plate.position = Vector2(plate_x - 260.0 * dir, 262.0)
	plate.modulate.a = 0.0
	_stage.add_child(plate)
	_plate = plate
	_speed_lines(_stage, Rect2(Vector2(px - 40.0, 250.0), Vector2(p.size.x + 80.0, 400.0)), Color(col.lightened(0.45), 0.35), dir, 0.5, 14)
	p.position = Vector2(px - 50.0 * dir, py)
	p.wipe = 0.0
	p.wipe_dir = dir
	p.edge_col = Color(col.lightened(0.5), 0.95)
	_stage.add_child(p)
	_portrait = p
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(plate, "position:x", plate_x, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(plate, "modulate:a", 1.0, 0.08)
	tw.tween_property(p, "wipe", 1.0, 0.22).set_delay(0.03).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "position:x", px, 0.24).set_delay(0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_glow, "modulate:a", 1.0, 0.3)
	var tag := _make_name_tag(id, 26)
	_stage.add_child(tag)
	tag.position = Vector2(26.0 if side == 0 else W - 26.0 - tag.size.x, 540.0)
	tag.scale = Vector2(0.2, 1.0)
	tag.rotation = deg_to_rad(-5.0 if side == 0 else 5.0)
	tag.modulate.a = 0.0
	_tag = tag
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(tag, "scale", Vector2.ONE, 0.2).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(tag, "modulate:a", 1.0, 0.06).set_delay(0.1)
	if expr == "shock" or expr == "angry":
		# bound to the portrait: if it is replaced (and freed) first, the shake simply never runs
		var tw3 := p.create_tween()
		tw3.tween_interval(0.26)
		tw3.tween_callback(_shake_node.bind(p, 8.0))


func _clear_speaker() -> void:
	_show_speaker("", "", 0)


static func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


## Statement motion is a pure function of _st, so freezing time freezes it.
func _update_view() -> void:
	if _view == null or not is_instance_valid(_view):
		return
	var t := _st
	var a := clampf(t / FLY_IN, 0.0, 1.0)
	var e := 1.0 - pow(2.0, -10.0 * a)
	var eb := _ease_out_back(a)
	var p := clampf(t / _sdur, 0.0, 1.0)
	var out_k := clampf((t - (_sdur - FLY_OUT)) / FLY_OUT, 0.0, 1.0)
	var o2 := out_k * out_k
	var sc := lerpf(0.35, 1.0, eb) * (1.0 + 0.05 * p)
	var sx := sc * lerpf(0.84, 1.0, e)
	var pos := _from.lerp(_home, e) + _drift * p
	var rot := lerpf(_rot0 * 3.0, _rot0, e) - _rot0 * 0.5 * p
	var sk := _skew0 * (1.0 - e)
	var alpha := lerpf(0.15, 1.0, clampf(a * 1.7, 0.0, 1.0))
	if out_k > 0.0:
		if _exit_mode == 0:
			# rush past the camera: balloon outward and fade
			var grow := lerpf(1.0, 2.5, o2)
			sc *= grow
			sx *= grow
			pos += _exit_dir * 300.0 * o2
			alpha *= 1.0 - out_k
		else:
			# slash off sideways, leaning into the motion
			var away := 1.0 if _side == 0 else -1.0
			pos.x += away * 980.0 * o2
			sk -= 0.42 * away * out_k
			sx *= lerpf(1.0, 1.25, out_k)
			alpha *= 1.0 - o2
	_view.position = pos
	_view.scale = Vector2(sx, sc)
	_view.rotation = rot
	_view.skew_x = sk
	_view.modulate.a = alpha
	_view.ghost = (1.0 - e) if a < 1.0 else (out_k if _exit_mode == 1 else 0.0)


func _tick(delta: float) -> void:
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	if _view != null and is_instance_valid(_view):
		var spd := 0.0
		if _state == "play":
			spd = 1.0
		elif _state == "firing":
			spd = 0.1
		_st += delta * spd
		_update_view()
		if not _landed and _st >= FLY_IN * 0.75 and _state == "play":
			_landed = true
			var c := _to_fx(_view.full_xf() * (_view.size * 0.5))
			_fx.ring(c, 40.0, 460.0, 0.5, Color(Style.AQUA, 0.28), 4.0)
			_focus(_to_local(_view.full_xf() * (_view.size * 0.5)), 0.32, 1.6)
		_view.hot_weak = _view.weak_at(get_global_mouse_position()) if (_state == "play" and not Game.autotest) else -1
		if _view.sparkle_weak >= 0 and _view.hidden_weak < 0 and spd > 0.0 and randf() < delta * 16.0:
			var pts: Array = _view.weak_points(_view.sparkle_weak, 1)
			if not pts.is_empty():
				_fx.burst(_to_fx(pts[0]), 1, [Style.GOLD, Color.WHITE, Color("fff1c0")], 50.0, -60.0, 6.0, 1)
		if _state == "play" and _si == _statements.size() - 1 and _st > _sdur - 1.5:
			var k := int((_st - (_sdur - 1.5)) / 0.5)
			if k != _tick_i:
				_tick_i = k
				Audio.sfx("tick", 1.0 + 0.12 * k, -9.0)
		if _state == "play" and _st >= _sdur:
			if _si + 1 < _statements.size():
				_start_statement(_si + 1)
			else:
				_loop_end()
	_update_hud()


func _loop_end() -> void:
	_state = "loopend"
	_loop += 1
	_clear_speaker()
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	Audio.sfx("wrong", 0.8, -6.0)
	# letting the loop run out costs no convince (only wrong shots do)
	_shake(6.0, 0.25)
	await _toast("TIME'S UP!", "The debate loops around... listen closely for the lie!", Style.DANGER, _fxd(1.1))
	if _gone():
		return
	var after := int(Chapters.get_value("hint_loops", 2))
	if after > 0 and _loop >= after and not _hint_shown and _hint_btn == null:
		_show_hint()
	_state = "play"
	_start_statement(0)


func _ask_hint() -> void:
	if _hint_shown or _state != "play":
		return
	Game.set_convince(Game.convince - Game.HINT_COST)
	_hint_btn.disabled = true
	_ui_rects.clear()
	_show_hint()


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_H and _hint_btn != null:
		_ask_hint()
		get_viewport().set_input_as_handled()
		return
	super(e)


func _show_hint() -> void:
	_hint_shown = true
	var txt := str(data.get("hint", ""))
	if txt == "":
		return
	var w := 760.0
	var body := "(" + txt + ")"
	var th := _text_height(body, _italic, 19, w - 56.0)
	var hint_col := Color("9fd8ff")
	var box := _slant(Vector2(w, th + 46.0), Color(0.06, 0.10, 0.24, 0.96), hint_col, 3.0, 16.0, 12.0, 4, Color(INK, 0.9), Vector2(7, 7))
	box.stripe_col = Color(hint_col, 0.2)
	box.refresh()
	box.position = Vector2((W - w) * 0.5, 94.0)
	box.pivot_offset = Vector2(60.0, box.size.y)
	_hud.add_child(box)
	var head := _slant(Vector2(176, 24), Style.GOLD, Style.BG_DARK, 2.0, 8.0, 5.0, 0, Color(INK, 0.95), Vector2(4, 4))
	head.position = Vector2(22, -12)
	var hl := Style.label("MOCHI'S HUNCH", 14, Style.BG_DARK, true)
	hl.position = Vector2(14, 2)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hl)
	box.add_child(head)
	var l := Label.new()
	l.text = body
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _italic)
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color("cfe9ff"))
	l.position = Vector2(28, 20)
	l.size = Vector2(w - 56.0, th + 6.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	for dot in [[Vector2(46, 8), 18.0], [Vector2(30, 30), 11.0]]:
		var off: Vector2 = dot[0]
		var r: float = dot[1]
		var d := _slant(Vector2(r, r), Color(0.06, 0.10, 0.24, 0.96), hint_col, 2.0, r * 0.3, r * 0.25, 0, Color(INK, 0.9), Vector2(3, 3))
		d.position = Vector2(off.x, box.size.y + off.y)
		box.add_child(d)
	box.scale = Vector2(0.3, 0.3)
	box.modulate.a = 0.0
	Audio.sfx("pop")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(box, "scale", Vector2.ONE, _fxd(0.26)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, _fxd(0.16))


# =================================================================== shooting
func _aim_allowed() -> bool:
	return _state == "play" or _state == "firing"


func _is_hot(pos: Vector2) -> bool:
	return _state == "play" and _view != null and is_instance_valid(_view) and _view.weak_at(pos) >= 0


func _on_left_click(pos: Vector2) -> void:
	if _state != "play" or _panel_rect.has_point(pos):
		return
	_fire_at(pos)


func _on_action() -> void:
	if _state == "play" and not Game.autotest:
		var m := get_global_mouse_position()
		if not _panel_rect.has_point(m):
			_fire_at(m)


func _fire_at(pos: Vector2) -> void:
	if _fire_cd > 0.0 or _drop_ids.is_empty():
		return
	_fire_cd = 0.3
	var drop := _selected_drop()
	var w := -1
	if _view != null and is_instance_valid(_view):
		w = _view.weak_at(pos)
	Audio.sfx("shoot", randf_range(0.95, 1.08))
	var to := _to_fx(pos)
	if w >= 0:
		_state = "firing"
		_fx.shot(_muzzle(), to, 0.17, func() -> void: _resolve(w, drop, pos))
	else:
		_fx.shot(_muzzle(), to, 0.17, func() -> void: _plain_splash(pos))


func _plain_splash(gp: Vector2) -> void:
	if _gone():
		return
	var c := _to_fx(gp)
	_fx.burst(c, 12, WATER, 260.0, 900.0, 5.0, 0)
	_fx.ring(c, 6.0, 60.0, 0.35, Color(Style.AQUA, 0.8), 3.0)
	Audio.sfx("splash", 1.35, -10.0)


func _resolve(w: int, drop: String, gp: Vector2) -> void:
	if _gone():
		return
	if _si == _ans_stmt and w == _ans_weak and drop == _ans_drop:
		_win(w, gp)
	elif (data.get("early", {}) as Dictionary).has(drop):
		_state = "wrong"
		await _early_line(drop, Vector2(260, 420))
		if not _gone():
			_state = "play"
	else:
		_wrong_shot(gp)


func _on_crack() -> void:
	if _portrait != null and is_instance_valid(_portrait):
		_portrait.texture = Assets.portrait(_speaker, "shock")


func _win(w: int, gp: Vector2) -> void:
	_state = "won"
	_aim_enabled = false
	_fx.aim_on = false
	_tip.visible = false
	await _break_hit(_view, w, gp)
	if _gone():
		return
	Audio.sfx("break")
	_shake(18.0, 0.45)
	Game.reward(Game.REWARD_DEBATE)
	Game.pay_early(_ans_drop)
	if _portrait != null and is_instance_valid(_portrait):
		_shake_node(_portrait, 14.0)
	await _wait(_fxd(0.24))
	if _gone():
		return
	await _break_banner(BREAK_TEXT)
	if _gone():
		return
	await _wait(_fxd(0.15))
	_finish({})


func _wrong_shot(gp: Vector2) -> void:
	_state = "wrong"
	var c := _to_fx(gp)
	_fx.burst(c, 16, [Style.DANGER, Color(0.65, 0.62, 0.75), Color.WHITE], 320.0, 1000.0, 6.0, 0)
	_fx.ring(c, 6.0, 90.0, 0.4, Color(Style.DANGER, 0.9), 5.0)
	Audio.sfx("wrong")
	Audio.sfx("static", 1.0, -8.0)
	_glitch(_fxd(0.34), 1.0)
	_flash(Style.DANGER, 0.42, 0.38)
	_shake(14.0, 0.35)
	_pop_text("WRONG!", gp + Vector2(0, -56), 46, Style.DANGER, -6.0, 0.45)
	Game.mistake(Game.PENALTY_DEBATE)
	if _view != null and is_instance_valid(_view):
		_view.dim = 0.55
	var lines: Array = data.get("wrong", [])
	if lines.size() > 0:
		var l: Dictionary = lines[_wrong_i % lines.size()]
		_wrong_i += 1
		await _wait(_fxd(0.25))
		if _gone():
			return
		await _say_box(str(l.get("speaker", "")), str(l.get("expr", "normal")), str(l.get("text", "")),
			Vector2(260, 420), 760.0, _fxd(2.6), _fxd(0.45))
	else:
		await _wait(_fxd(0.9))
	if _gone():
		return
	if _view != null and is_instance_valid(_view):
		_view.dim = 0.0
	_state = "play"


# =================================================================== autotest
func _autoplay() -> void:
	await _wait(0.12)
	if _gone():
		return
	var good := _drop_ids.find(_ans_drop)
	if good < 0:
		push_warning("debate: answer drop '%s' is not loaded" % _ans_drop)
		_finish({})
		return
	if Game.debug_minigame != "" and _hint_btn != null:
		_ask_hint()
	if Game.debug_minigame != "":
		for i in _drop_ids.size():
			if not Clues.images(str(_drop_ids[i])).is_empty():
				_select_drop(i)
				_view_selected()   # the viewer's own autotest pages through it and closes
				await _wait(0.05)
				if _gone():
					return
				break
	if Game.debug_minigame != "" and _drop_ids.size() > 1:
		_auto_shot((good + 1) % _drop_ids.size())
		while not _gone() and _state != "play":
			await _frame
		await _wait(0.05)
		if _gone():
			return
	_auto_shot(good)


func _auto_shot(drop_i: int) -> void:
	_select_drop(drop_i)
	_start_statement(_ans_stmt)
	_st = minf(0.6, _sdur * 0.4)
	_update_view()
	var gp := _view.weak_center(_ans_weak)
	_fx.aim_on = true
	_fx.aim = _to_fx(gp)
	_fx.aim_hot = true
	_fire_cd = 0.0
	_fire_at(gp)


# =================================================================== loop timer bar
## Slanted segmented loop bar: one parallelogram segment per statement, the current one outlined in gold.
class SegBar extends Control:
	var durs: Array = []
	var total := 1.0
	var k := 0.0
	var cur := 0
	var active := true
	var col := Color("3ee0d0")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(nk: float, ncur: int, nactive: bool, ncol: Color) -> void:
		if is_equal_approx(nk, k) and ncur == cur and nactive == active and ncol.is_equal_approx(col):
			return
		k = nk
		cur = ncur
		active = nactive
		col = ncol
		queue_redraw()

	func _seg(u0: float, u1: float, sk: float, L: float, h: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(sk + u0 * L, 0), Vector2(sk + u1 * L, 0), Vector2(u1 * L, h), Vector2(u0 * L, h)])

	func _draw() -> void:
		var h := size.y
		var sk := 7.0
		var L := size.x - sk
		draw_set_transform(Vector2(3, 3))
		draw_colored_polygon(_seg(0.0, 1.0, sk, L, h), Color(0.027, 0.016, 0.06, 0.9))
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(_seg(0.0, 1.0, sk, L, h), Color(0.16, 0.11, 0.3))
		if k > 0.002:
			draw_colored_polygon(_seg(0.0, k, sk, L, h), col)
			draw_colored_polygon(_seg(maxf(k - 0.012, 0.0), k, sk, L, h * 0.999), Color(1, 1, 1, 0.8))
		var acc := 0.0
		var t := maxf(total, 0.001)
		for i in durs.size():
			var u0 := acc / t
			acc += float(durs[i])
			var u1 := acc / t
			if i > 0:
				draw_line(Vector2(sk + u0 * L, 0), Vector2(u0 * L, h), Color(0.07, 0.04, 0.14), 3.0)
			if active and i == cur:
				var q := _seg(u0, u1, sk, L, h)
				q.append(q[0])
				draw_polyline(q, Color("ffd166"), 2.5, true)
