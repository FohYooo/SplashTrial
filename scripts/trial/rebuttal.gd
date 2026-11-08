extends "res://scripts/trial/trial_common.gd"
## REBUTTAL SHOWDOWN (trial data type "rebuttal").
## Phase 1: the opponent fires each of data.lines - each line slashes in from his side with diagonal speed
##   lines; a timing ring shrinks onto the COUNTER target.
##   Space / click while the ring is inside the window -> COUNTER! (hit-stop, a blade slices the line in two;
##   REWARD_COUNTER, x2 with en_garde), too early / too late -> MISSED! (glitch, PENALTY_COUNTER); no press -> MISSED! with no penalty.
## Phase 2: data.final.text with its {weak spot}; load a Truth Drop from data.final.drops and shoot it.
##   Correct -> freeze, crack, screen shatter, banner (REWARD_REBUTTAL) and finished({});
##   wrong -> PENALTY_REBUTTAL, retry.
## Skills: sleight_of_paw (window 40% wider), en_garde (counter reward x2), power_nap (durations x timer_scale).

signal line_done

const MARK := Vector2(400, 530)    # center of the COUNTER target
const RT := 48.0                   # target ring radius
const R0 := 172.0                  # ring start radius
const T_RING0 := 0.3               # ring appears after the line lands
const WIN_T := 0.17                # half-width of the timing window (seconds, before skills)
const LINE_CENTER := Vector2(400, 250)
const FINAL_CENTER := Vector2(400, 300)
const LINE_SKEW := -0.06
const TAUNTS := ["That proves nothing at all!", "Wide of the mark! Try again!", "Is that the best you've got?"]

var _opp := "wisp"
var _lines: Array = []
var _final: Dictionary = {}
var _phase := 0           # 0 intro, 1 counters, 2 final, 3 done
var _state := ""          # phase 2: aim, firing, wrong, won
var _li := 0
var _lt := 0.0
var _lstate := ""         # incoming, resolved
var _T := 2.6
var _t_hit := 2.0
var _speed := 100.0
var _win_px := 17.0
var _auto_pressed := false
var _wrong_i := 0
var _fire_cd := 0.0
var _ft := 0.0

var _opp_por: CutPortrait
var _opp_home := Vector2.ZERO
var _ring: RingView
var _instr: Label
var _holder: Control
var _line_home := Vector2.ZERO
var _final_view: StatementView
var _final_home := Vector2.ZERO
var _pips: Array = []
var _pip_state: Array = []


func _ready() -> void:
	_build_common(Style.VIOLET)
	_backdrop.speed = 140.0
	_opp = str(data.get("opponent", "wisp"))
	_lines = data.get("lines", [])
	_final = data.get("final", {})
	var tpl := float(data.get("time_per_line", 2.6))
	_T = tpl * Game.timer_scale()
	_t_hit = _T * 0.8
	_speed = (R0 - RT) / maxf(_t_hit - T_RING0, 0.3)
	# window is fixed in pixels from the unscaled speed, so power_nap's slower ring = more time
	var base_speed := (R0 - RT) / maxf(tpl * 0.8 - T_RING0, 0.3)
	_win_px = WIN_T * base_speed * (1.4 if Game.has_skill("sleight_of_paw") else 1.0)
	_build_hud()
	_ring = RingView.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.c = MARK
	_ring.rt = RT
	_ring.r0 = R0
	_ring.win = _win_px
	_ring.font = Style.display_font()
	_stage.add_child(_ring)
	_instr = _hard_shadow(Style.title_label("Press SPACE or CLICK when the ring meets the circle!", 17, Style.TEXT, Style.BG_DARK, 5), Vector2(3, 3), INK)
	_instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instr.size = Vector2(700, 26)
	_instr.position = Vector2(MARK.x - 350.0, MARK.y + RT + 26.0)
	_instr.modulate.a = 0.0
	_instr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_instr)
	_run.call_deferred()


# =================================================================== HUD + opponent
func _build_hud() -> void:
	var badge := _hud_badge("REBUTTAL SHOWDOWN", Style.VIOLET, 30)
	badge.position = Vector2(16, 8)
	_hud.add_child(badge)
	var py := badge.position.y + badge.size.y + 10.0
	var cl := _hard_shadow(Style.title_label("COUNTERS", 12, Style.TEXT_DIM, Style.BG_DARK, 3), Vector2(2, 2), INK)
	cl.position = Vector2(22, py + 1)
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(cl)
	for i in _lines.size():
		var pip := _slant(Vector2(20, 18), Color(0.16, 0.11, 0.3), Style.TEXT_DIM, 2.0, 7.0, 4.0, 0, Color(INK, 0.95), Vector2(3, 3))
		pip.position = Vector2(100 + i * 26, py)
		pip.pivot_offset = pip.size * 0.5
		_hud.add_child(pip)
		_pips.append(pip)
		_pip_state.append(0)
	_refresh_pips()
	_skill_tags(["sleight_of_paw", "en_garde", "power_nap"], Vector2(22, py + 26))
	var col := Cast.color(_opp)
	var vs := _slant(Vector2(362, 60), PANEL_BG, col, 3.0, 16.0, 10.0, 3, Color(INK, 0.92), Vector2(6, 6))
	vs.stripe_col = Color(col, 0.3)
	vs.refresh()
	vs.position = Vector2(898, 8)
	_hud.add_child(vs)
	var vl := _hard_shadow(Style.title_label("VS", 34, Style.GOLD, Style.BG_DARK, 8), Vector2(3, 4), Color(col.darkened(0.4), 1.0))
	vl.position = Vector2(22, 6)
	vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vs.add_child(vl)
	var nm := _hard_shadow(Style.title_label(Cast.full_name(_opp).to_upper(), 20, col.lightened(0.25), Style.BG_DARK, 6), Vector2(2, 3), INK)
	nm.position = Vector2(88, 4)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vs.add_child(nm)
	var tl := Style.label(Cast.talent(_opp), 15, Style.TEXT_DIM, true)
	tl.position = Vector2(90, 31)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vs.add_child(tl)


func _refresh_pips() -> void:
	for i in _pips.size():
		var p: Slant = _pips[i]
		var s: int = _pip_state[i]
		var bgc := Color(0.16, 0.11, 0.3)
		var bc := Style.TEXT_DIM
		if s > 0:
			bgc = Style.GOLD
			bc = Color.WHITE
		elif s < 0:
			bgc = Style.DANGER
			bc = Color(1, 0.8, 0.8)
		elif i == _li and _phase == 1:
			bc = Style.AQUA
		p.fill = bgc
		p.border = bc
		p.refresh()


func _show_opponent() -> void:
	var col := Cast.color(_opp)
	var glow := _make_glow(col, 760.0, 0.32)
	_opp_por = _make_portrait(_opp, "normal", 1.1)
	_opp_home = Vector2(W - _opp_por.size.x + 12.0, H - _opp_por.size.y + 6.0)
	glow.position = Vector2(_opp_home.x + _opp_por.size.x * 0.5 - 380.0, _opp_home.y + 250.0 - 380.0)
	glow.modulate.a = 0.0
	_stage.add_child(glow)
	_stage.move_child(glow, 0)
	var plate := _slant(Vector2(380, 560), Color(col.lerp(Style.VIOLET, 0.4).darkened(0.35), 0.78), Color(col.lerp(Style.AQUA, 0.2).lightened(0.3), 1.0), 5.0, -110.0, 0.0, 6,
		Color(INK, 0.8), Vector2(-12, 12))
	plate.stripe_col = Color(col.lightened(0.5), 0.4)
	plate.inner = Color(1, 1, 1, 0.35)
	plate.stripe_left = true
	plate.refresh()
	var plate_x := _opp_home.x + _opp_por.size.x * 0.5 - 190.0 - 20.0
	plate.position = Vector2(plate_x + 420.0, 190.0)
	_stage.add_child(plate)
	_stage.move_child(plate, 1)
	_speed_lines(_stage, Rect2(Vector2(_opp_home.x - 60.0, 150.0), Vector2(_opp_por.size.x + 80.0, 520.0)), Color(col.lightened(0.45), 0.35), -1.0, 0.6, 16)
	_opp_por.position = _opp_home + Vector2(120, 0)
	_opp_por.wipe = 0.0
	_opp_por.wipe_dir = -1.0
	_opp_por.edge_col = Color(col.lightened(0.5), 0.95)
	_stage.add_child(_opp_por)
	Audio.sfx("whoosh", 0.8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(plate, "position:x", plate_x, _fxd(0.18)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_opp_por, "wipe", 1.0, _fxd(0.26)).set_delay(_fxd(0.04)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_opp_por, "position", _opp_home, _fxd(0.3)).set_delay(_fxd(0.04)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(glow, "modulate:a", 1.0, _fxd(0.5))
	_focus(Vector2(_opp_home.x + 260.0, 360.0), 0.7, 1.8)


func _opp_expr(e: String) -> void:
	if _opp_por != null and is_instance_valid(_opp_por):
		_opp_por.texture = Assets.portrait(_opp, e)


func _opp_lunge() -> void:
	if _opp_por == null:
		return
	var tw := create_tween()
	tw.tween_property(_opp_por, "position", _opp_home + Vector2(-40, 6), _fxd(0.08)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_opp_por, "position", _opp_home, _fxd(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _opp_recoil(amt: float = 40.0) -> void:
	if _opp_por == null:
		return
	_opp_por.modulate = Color(1.6, 1.6, 1.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_opp_por, "position", _opp_home + Vector2(amt, -4), _fxd(0.08))
	tw.tween_property(_opp_por, "modulate", Color.WHITE, _fxd(0.3))
	tw.chain().tween_property(_opp_por, "position", _opp_home, _fxd(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# =================================================================== flow
func _run() -> void:
	await _banner_sweep("REBUTTAL SHOWDOWN", "%s won't go down without a fight!" % Cast.display_name(_opp), Style.VIOLET)
	if _gone():
		return
	_show_opponent()
	await _wait(_fxd(0.35))
	if _gone():
		return
	_opp_expr("happy")
	var intro := str(data.get("intro", ""))
	if intro != "":
		await _say_box(_opp, "happy", intro, Vector2(40, 392), 700.0, _fxd(4.5), _fxd(0.5))
		if _gone():
			return
	_phase = 1
	var tw := create_tween()
	tw.tween_property(_instr, "modulate:a", 1.0, _fxd(0.3))
	for i in _lines.size():
		_begin_line(i)
		await line_done
		if _gone():
			return
	_phase = 2
	_ring.alpha = 0.0
	_ring.active = false
	var tw2 := create_tween()
	tw2.tween_property(_instr, "modulate:a", 0.0, _fxd(0.2))
	if _holder != null and is_instance_valid(_holder):
		_holder.queue_free()
	_opp_expr("angry")
	await _toast("FINAL STRIKE!", "Load the right Truth Drop and shoot the weak spot!", Style.GOLD, _fxd(1.1))
	if _gone():
		return
	_start_final()


# =================================================================== phase 1: counters
func _ring_radius(t: float) -> float:
	if t < T_RING0:
		return R0
	return RT + (R0 - RT) * (1.0 - (t - T_RING0) / maxf(_t_hit - T_RING0, 0.01))


func _begin_line(i: int) -> void:
	_li = i
	_lt = 0.0
	_lstate = "incoming"
	_auto_pressed = false
	_refresh_pips()
	if _holder != null and is_instance_valid(_holder):
		_holder.queue_free()
	_holder = _make_line(str(_lines[i]))
	_stage.add_child(_holder)
	_line_home = LINE_CENTER - _holder.size * 0.5
	_holder.position = _line_home + Vector2(520, -60)
	_holder.pivot_offset = _holder.size * 0.5
	_holder.scale = Vector2(1.6, 1.6)
	_holder.modulate.a = 0.0
	_set_line_skew(-0.55)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_holder, "position", _line_home, _fxd(0.2)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_holder, "scale", Vector2.ONE, _fxd(0.24)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_holder, "modulate:a", 1.0, _fxd(0.08))
	tw.tween_method(_set_line_skew, -0.55, LINE_SKEW, _fxd(0.26)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var col := Cast.color(_opp)
	_slash_in(LINE_CENTER, col)
	_opp_expr("angry" if i % 2 == 0 else "happy")
	_opp_lunge()
	Audio.sfx("whoosh", 1.15)
	_ring.alpha = 0.0
	_ring.active = false
	_ring.inside = false
	_ring.r = R0
	_ring.result = 0


## Diagonal speed lines that streak in from the opponent's side as a line lands.
func _slash_in(center: Vector2, col: Color) -> void:
	var offs := [[-70.0, 7.0, Color(col.lightened(0.3), 0.95)], [6.0, 4.0, Color(1, 1, 1, 0.9)], [74.0, 8.0, Color(col, 0.9)], [118.0, 3.0, Color(Style.GOLD, 0.8)]]
	for o in offs:
		var oy: float = o[0]
		var a := Vector2(W + 80.0, center.y + oy - 70.0)
		var b := Vector2(-80.0, center.y + oy + 60.0)
		_blade(_top, a, b, o[2], float(o[1]), 0.12)
	_speed_lines(_stage, Rect2(Vector2(0, center.y - 110.0), Vector2(W, 220.0)), Color(col.lightened(0.4), 0.22), -1.0, 0.4, 12)
	_focus(center, 0.4, 2.2)


func _set_line_skew(v: float) -> void:
	if _holder == null or not is_instance_valid(_holder):
		return
	for key in ["v1", "v2"]:
		if _holder.has_meta(key):
			var sv: StatementView = _holder.get_meta(key)
			if is_instance_valid(sv):
				sv.skew_x = v


## A line of big text split into two clipped halves (so a COUNTER can slice it apart).
func _make_line(text: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := 44 if text.length() < 48 else 40
	var v1 := _new_statement()
	v1.build(text, 660.0, fs, Style.display_font())
	v1.outline_col = Color("1e0b33")
	var sz := v1.size
	holder.size = sz
	var m := 90.0
	var half := sz.y * 0.5
	var top := Control.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.clip_contents = true
	top.position = Vector2(-m, -m)
	top.size = Vector2(sz.x + 2.0 * m, half + m)
	v1.position = Vector2(m, m)
	top.add_child(v1)
	holder.add_child(top)
	var bot := Control.new()
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot.clip_contents = true
	bot.position = Vector2(-m, half)
	bot.size = Vector2(sz.x + 2.0 * m, half + m)
	var v2 := _new_statement()
	v2.build(text, 660.0, fs, Style.display_font())
	v2.outline_col = v1.outline_col
	v2.position = Vector2(m, -half)
	bot.add_child(v2)
	holder.add_child(bot)
	var rot := deg_to_rad(-3.0)
	v1.rotation = rot
	v2.rotation = rot
	holder.set_meta("top", top)
	holder.set_meta("bot", bot)
	holder.set_meta("v1", v1)
	holder.set_meta("v2", v2)
	return holder


func _tick(delta: float) -> void:
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	if _phase == 1 and _lstate == "incoming":
		_lt += delta * (6.0 if Game.autotest else 1.0)
		var r := _ring_radius(_lt)
		_ring.r = r
		_ring.alpha = clampf((_lt - 0.12) / 0.2, 0.0, 1.0)
		_ring.active = _lt >= T_RING0 * 0.5
		var was_inside := _ring.inside
		_ring.inside = absf(r - RT) <= _win_px
		if _ring.inside and not was_inside and not Game.autotest:
			Audio.sfx("tick", 1.5, -6.0)
		if _holder != null and is_instance_valid(_holder):
			var k := clampf(_lt / _t_hit, 0.0, 1.2)
			if _lt > 0.25:
				_holder.scale = Vector2.ONE * (1.0 + 0.07 * k)
				_holder.position = _line_home + Vector2(-14.0, 10.0) * k
		if Game.autotest and not _auto_pressed:
			if Game.debug_minigame != "" and _li == 0:
				if _lt > T_RING0 + 0.1:
					_auto_pressed = true
					_press()
			elif absf(r - RT) <= _win_px:
				_auto_pressed = true
				_press()
		if _lstate == "incoming" and r < RT - _win_px:
			_counter_miss(false, true)
	elif _phase == 2 and _final_view != null and is_instance_valid(_final_view):
		if _state != "won":
			_ft += delta
		var e := clampf(_ft / 0.35, 0.0, 1.0)
		var eb := 1.0 + 2.70158 * pow(e - 1.0, 3.0) + 1.70158 * pow(e - 1.0, 2.0)
		_final_view.scale = Vector2.ONE * lerpf(2.1, 1.0, eb)
		_final_view.rotation = lerpf(-0.16, -0.045, eb) + sin(_ft * 1.3) * 0.018
		_final_view.skew_x = lerpf(-0.5, -0.05, eb) + sin(_ft * 0.8) * 0.02
		_final_view.position = _final_home + Vector2(160, -40) * (1.0 - eb) + Vector2(sin(_ft * 0.9) * 8.0, sin(_ft * 1.7) * 6.0)
		_final_view.modulate.a = clampf(_ft / 0.15, 0.0, 1.0)
		_final_view.ghost = 1.0 - e
		_final_view.hot_weak = _final_view.weak_at(get_global_mouse_position()) if (_state == "aim" and not Game.autotest) else -1


func _on_left_click(pos: Vector2) -> void:
	if _phase == 1:
		_press()
	elif _phase == 2 and _state == "aim" and not _panel_rect.has_point(pos):
		_fire_at(pos)


func _on_action() -> void:
	if _phase == 1:
		_press()
	elif _phase == 2 and _state == "aim" and not Game.autotest:
		var m := get_global_mouse_position()
		if not _panel_rect.has_point(m):
			_fire_at(m)


func _press() -> void:
	if _phase != 1 or _lstate != "incoming" or _lt < 0.15:
		return
	var r := _ring_radius(_lt)
	if absf(r - RT) <= _win_px:
		_counter_hit()
	else:
		_counter_miss(r > RT)


func _counter_hit() -> void:
	_lstate = "resolved"
	_pip_state[_li] = 1
	_refresh_pips()
	var amt := Game.REWARD_COUNTER * (2.0 if Game.has_skill("en_garde") else 1.0)
	Game.reward(amt)
	_ring.result = 1
	_ring.r = RT
	Audio.sfx("break")
	_flash(Color.WHITE, 0.35, 0.12)
	# hit-stop: a tiny freeze-frame right on the counter
	_freeze(_fxd(0.07))
	await _wait(_fxd(0.07))
	if _gone():
		return
	Audio.sfx("shout", 1.15, -4.0)
	var m := _to_fx(MARK)
	_fx.ring(m, RT, RT + 150.0, 0.45, Style.GOLD, 7.0)
	_fx.ring(m, RT, RT + 90.0, 0.3, Color.WHITE, 4.0)
	_fx.burst(m, 20, [Style.GOLD, Color.WHITE, Style.AQUA], 440.0, 500.0, 6.0, 1)
	_cut_line()
	_pop_text("COUNTER!", LINE_CENTER + Vector2(0, 8), 72, Style.GOLD, -8.0, 0.45)
	_flash(Color.WHITE, 0.45, 0.25)
	_shake(10.0, 0.25)
	_opp_expr("shock")
	_opp_recoil()
	_pulse_pip(_li)
	await _wait(_fxd(0.9))
	if _gone():
		return
	line_done.emit()


func _counter_miss(early: bool, no_press: bool = false) -> void:
	_lstate = "resolved"
	_pip_state[_li] = -1
	_refresh_pips()
	if not no_press:   # a mistimed press costs convince; not pressing at all does not
		Game.mistake(Game.PENALTY_COUNTER)
	Audio.sfx("wrong")
	Audio.sfx("static", 1.0, -8.0)
	_ring.result = -1
	_glitch(_fxd(0.3), 0.9)
	_flash(Style.DANGER, 0.42, 0.35)
	_shake(15.0, 0.35)
	_pop_text("MISSED!", LINE_CENTER + Vector2(0, -4), 64, Style.DANGER, 6.0, 0.4)
	_pop_text("TOO EARLY!" if early else "TOO LATE!", MARK + Vector2(0, -RT - 34.0), 26, Color(1, 0.75, 0.78), 0.0, 0.5)
	if _holder != null and is_instance_valid(_holder):
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_holder, "scale", Vector2(1.9, 1.9), _fxd(0.3)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_property(_holder, "modulate:a", 0.0, _fxd(0.3))
	_opp_expr("happy")
	_opp_lunge()
	_pulse_pip(_li)
	await _wait(_fxd(0.9))
	if _gone():
		return
	line_done.emit()


func _pulse_pip(i: int) -> void:
	if i < 0 or i >= _pips.size():
		return
	var p: Slant = _pips[i]
	p.scale = Vector2(1.9, 1.9)
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, _fxd(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## COUNTER: a blade slices the line along its baseline and the two halves fly apart.
func _cut_line() -> void:
	if _holder == null or not is_instance_valid(_holder):
		return
	var top: Control = _holder.get_meta("top")
	var bot: Control = _holder.get_meta("bot")
	var r := _holder.get_global_rect()
	var c := r.get_center()
	var half_len := r.size.x * 0.5 + 220.0
	var dy := tan(deg_to_rad(-3.0)) * half_len
	var a := _to_local(c - Vector2(half_len, dy))
	var b := _to_local(c + Vector2(half_len, dy))
	_blade(_top, a, b, Color(Style.GOLD, 0.95), 20.0, 0.09)
	_blade(_top, a + Vector2(0, -16), b + Vector2(0, -16), Color(Style.AQUA, 0.7), 6.0, 0.11)
	for k in 16:
		var gp := c + Vector2(randf_range(-_holder.size.x * 0.5, _holder.size.x * 0.5), randf_range(-6, 6))
		_fx.burst(_to_fx(gp), 1, [Style.GOLD, Color.WHITE, Style.YUZU], 420.0, 900.0, 8.0, 2)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(top, "position", top.position + Vector2(-70, -46), _fxd(0.45)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(bot, "position", bot.position + Vector2(70, 46), _fxd(0.45)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(top, "rotation", -0.06, _fxd(0.45)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(bot, "rotation", 0.05, _fxd(0.45)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(top, "modulate:a", 0.0, _fxd(0.4)).set_delay(_fxd(0.15))
	tw.tween_property(bot, "modulate:a", 0.0, _fxd(0.4)).set_delay(_fxd(0.15))


# =================================================================== phase 2: final statement
func _start_final() -> void:
	_phase = 2
	_state = "aim"
	_ft = 0.0
	_opp_expr("angry")
	var text := str(_final.get("text", ""))
	_final_view = _new_statement()
	_final_view.build(text, 660.0, 50 if text.length() < 50 else 44, Style.display_font())
	_final_view.outline_col = Color("1e0b33")
	_final_view.ghost_off = Vector2(30, -8)
	_stage.add_child(_final_view)
	_final_home = FINAL_CENTER - _final_view.size * 0.5
	_final_view.modulate.a = 0.0
	_final_view.position = _final_home
	Audio.sfx("whoosh", 0.9)
	_opp_lunge()
	_slash_in(FINAL_CENTER, Cast.color(_opp))
	_shake(6.0, 0.2)
	if _final_view.weak_count() == 0:
		push_warning("rebuttal: final text has no {weak spot}")
	_build_drop_panel(_final.get("drops", []))
	_show_drop_panel()
	_aim_enabled = true
	if Game.autotest:
		_auto_final()


func _aim_allowed() -> bool:
	return _phase == 2 and (_state == "aim" or _state == "firing")


func _is_hot(pos: Vector2) -> bool:
	return _phase == 2 and _state == "aim" and _final_view != null and is_instance_valid(_final_view) and _final_view.weak_at(pos) >= 0


func _fire_at(pos: Vector2) -> void:
	if _fire_cd > 0.0 or _drop_ids.is_empty():
		return
	_fire_cd = 0.3
	var drop := _selected_drop()
	var w := -1
	if _final_view != null and is_instance_valid(_final_view):
		w = _final_view.weak_at(pos)
	Audio.sfx("shoot", randf_range(0.95, 1.08))
	var to := _to_fx(pos)
	if w >= 0:
		_state = "firing"
		_fx.shot(_muzzle(), to, 0.17, func() -> void: _resolve(drop, pos))
	else:
		_fx.shot(_muzzle(), to, 0.17, func() -> void: _plain_splash(pos))


func _plain_splash(gp: Vector2) -> void:
	if _gone():
		return
	var c := _to_fx(gp)
	_fx.burst(c, 12, WATER, 260.0, 900.0, 5.0, 0)
	_fx.ring(c, 6.0, 60.0, 0.35, Color(Style.AQUA, 0.8), 3.0)
	Audio.sfx("splash", 1.35, -10.0)


func _resolve(drop: String, gp: Vector2) -> void:
	if _gone():
		return
	if drop == str(_final.get("answer", "")):
		_final_win(gp)
	else:
		_final_wrong(gp)


func _on_crack() -> void:
	_opp_expr("shock")


func _final_win(gp: Vector2) -> void:
	_state = "won"
	_phase = 3
	_aim_enabled = false
	_fx.aim_on = false
	_tip.visible = false
	await _break_hit(_final_view, 0, gp)
	if _gone():
		return
	Audio.sfx("break")
	_shake(20.0, 0.45)
	Game.reward(Game.REWARD_REBUTTAL)
	_opp_recoil(70.0)
	await _wait(_fxd(0.24))
	if _gone():
		return
	await _break_banner(BREAK_TEXT)
	if _gone():
		return
	await _wait(_fxd(0.15))
	_finish({})


func _final_wrong(gp: Vector2) -> void:
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
	Game.mistake(Game.PENALTY_REBUTTAL)
	_opp_expr("happy")
	_opp_lunge()
	if _final_view != null and is_instance_valid(_final_view):
		_final_view.dim = 0.5
	var spk := _opp
	var expr := "happy"
	var line := str(TAUNTS[_wrong_i % TAUNTS.size()])
	var wl: Variant = data.get("wrong", null)
	if typeof(wl) == TYPE_ARRAY and (wl as Array).size() > 0:
		var arr: Array = wl
		var d: Dictionary = arr[_wrong_i % arr.size()]
		spk = str(d.get("speaker", _opp))
		expr = str(d.get("expr", "happy"))
		line = str(d.get("text", line))
	elif typeof(wl) == TYPE_DICTIONARY:
		var d2: Dictionary = wl
		spk = str(d2.get("speaker", _opp))
		expr = str(d2.get("expr", "happy"))
		line = str(d2.get("text", line))
	_wrong_i += 1
	await _wait(_fxd(0.25))
	if _gone():
		return
	await _say_box(spk, expr, line, Vector2(40, 430), 700.0, _fxd(2.4), _fxd(0.45))
	if _gone():
		return
	if _final_view != null and is_instance_valid(_final_view):
		_final_view.dim = 0.0
	_opp_expr("angry")
	_state = "aim"


# =================================================================== autotest
func _auto_final() -> void:
	await _wait(0.12)
	if _gone():
		return
	var good := _drop_ids.find(str(_final.get("answer", "")))
	if good < 0 or _final_view.weak_count() == 0:
		push_warning("rebuttal: final answer cannot be hit")
		_finish({})
		return
	_ft = 1.0
	_tick(0.0)
	if Game.debug_minigame != "" and _drop_ids.size() > 1:
		_auto_shot((good + 1) % _drop_ids.size())
		while not _gone() and _state != "aim":
			await _frame
		await _wait(0.05)
		if _gone():
			return
	_auto_shot(good)


func _auto_shot(drop_i: int) -> void:
	_select_drop(drop_i)
	var gp := _final_view.weak_center(0)
	_fx.aim_on = true
	_fx.aim = _to_fx(gp)
	_fx.aim_hot = true
	_fire_cd = 0.0
	_fire_at(gp)


# =================================================================== timing ring
## The COUNTER target: a hard-shadowed disc with four inward chevrons; the approach ring closes in on it.
class RingView extends Control:
	var c := Vector2.ZERO
	var r := 172.0
	var rt := 48.0
	var r0 := 172.0
	var win := 17.0
	var active := false
	var inside := false
	var alpha := 0.0
	var result := 0
	var t := 0.0
	var font: Font

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var a := alpha
		if a <= 0.01:
			return
		var pulse := 0.5 + 0.5 * sin(t * 8.0)
		draw_arc(c, r0, 0.0, TAU, 80, Color(1, 1, 1, 0.08 * a), 2.0, true)
		draw_arc(c, rt, 0.0, TAU, 80, Color(0.24, 0.88, 0.82, (0.22 + (0.18 if inside else 0.0)) * a), win * 2.0, true)
		var tc := Color(1.0, 0.82, 0.4)
		if result > 0:
			tc = Color.WHITE
		elif result < 0:
			tc = Color(1.0, 0.31, 0.43)
		var br := rt - 10.0
		if inside and result == 0:
			br += 3.0 * pulse
		draw_circle(c + Vector2(5, 6), br + 2.0, Color(0.027, 0.016, 0.06, 0.85 * a))
		draw_arc(c, rt, 0.0, TAU, 80, Color(tc, (0.7 + 0.3 * pulse) * a), 4.0, true)
		draw_circle(c, br, Color(0.10, 0.05, 0.20, 0.94 * a))
		draw_arc(c, br, 0.0, TAU, 48, Color(0.61, 0.42, 0.84, a), 2.0, true)
		# inward chevrons on the diagonals (angular accent)
		var spin := t * 0.6
		for q in 4:
			var ang := spin + PI * 0.25 + q * PI * 0.5
			var d := Vector2.from_angle(ang)
			var nn := Vector2(-d.y, d.x)
			var tip := c + d * (rt + 8.0)
			var base := c + d * (rt + 24.0)
			var chev := PackedVector2Array([tip, base + nn * 10.0, base + d * 4.0, base - nn * 10.0])
			draw_colored_polygon(chev, Color(tc, 0.9 * a))
		if font:
			var label := "NOW!" if (inside and result == 0) else "COUNTER"
			var fs := 22 if label == "NOW!" else 13
			var sw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var lc := Color(1.0, 0.82, 0.4, a) if label == "NOW!" else Color(0.96, 0.95, 1.0, a)
			var p := c + Vector2(-sw * 0.5, fs * 0.36)
			draw_string_outline(font, p + Vector2(2, 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.027, 0.016, 0.06, a))
			draw_string_outline(font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.07, 0.04, 0.14, a))
			draw_string(font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)
		if active and result == 0:
			var col := Color(1.0, 0.82, 0.4) if inside else Color(1, 1, 1)
			draw_arc(c, r, 0.0, TAU, 80, Color(col, 0.3 * a), 16.0, true)
			draw_arc(c, r, 0.0, TAU, 80, Color(col, a), 5.0, true)
			for q in 8:
				var ang2 := t * 2.0 + q * PI / 4.0
				var d2 := Vector2(cos(ang2), sin(ang2))
				draw_line(c + d2 * (r + 6.0), c + d2 * (r + 16.0), Color(col, 0.8 * a), 3.0)
