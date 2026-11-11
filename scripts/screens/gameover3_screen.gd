extends "res://scripts/screens/cutscene_base.gd"
## GAME OVER (Chapter 3) - "THE LINE-UP" (docs/DESIGN3.md, "Endings"; SPOILERS). Replaces "Mochi's Last Soak" for Case 3:
## Snapjaw names the real culprit, who checks out; everyone else is punished on screen, in the brutal style of the
## Case 3 execution, and Mochi is last. Then GAME OVER with Retry Trial / Title.
##   0  WRONG: Snapjaw names the real culprit      3  the culprit walks out through a door of light
##   6  title card                                  9  the line-up: a prison height chart, a lamp and a spiked gate
##  12  the roll call: each name, a bell, the gate (hard white and red frames, blood up the wall), faster and faster
##  ~26 Mochi, alone at the end of the line       ~31 black, blood on the lens, GAME OVER
## Clock-driven on cutscene_base.gd. A click or key (after 0.5 s), or holding one, jumps to the menu. Emits
## finished({"action": "retry"|"title"}); under autotest it shows the menu and picks "title" after about 0.5 s.
## Debug: --wrong3-t=<seconds> (with --shot= for a timed screenshot). Chapter data: culprit and victim_name.
## Art: art/props/wv_*.svg (tools/gen_end3_art.py). Sound: execution_lineup, wv_*, sp_crush (tools/gen_end3_audio.py).

const Chapters := preload("res://scripts/data/chapters.gd")

const MUSIC_ID := "execution_lineup"
const SPACING := 270.0
const LINE_X0 := 400.0
const GUEST_SC := 0.5
const BUST_FOOT := 724.0
const GATE_SC := 0.9
const GATE_UP := 96.0          # world y of the spike tips, raised (they show just under the ceiling)
const GATE_DOWN := 742.0
const SHOT_LEAD := 0.45

const BLOOD := Color("7a0010")
const BLOOD_D := Color("3a0008")
const BLOOD_H := Color("b3001b")
const AQUA_TXT := Color(0.66, 0.95, 0.92)
const BONE_TXT := Color(0.86, 0.82, 0.72)

## Same worn tape as the execution: grey, except the blood.
const TAPE_SHADER := preload("res://scripts/screens/execution3_screen.gd").TAPE_SHADER
const LIT_SHADER := preload("res://scripts/screens/execution3_screen.gd").LIT_SHADER

# ------------------------------------------------------------------ state
var _guests: Array = []          # line-up order, Mochi last
var _culprit := ""
var _gate_y: Array = []
var _gone: Array = []            # per guest: punished yet?
var _expr: Array = []
var _lamp_on: Array = []
var _impact := 0
var _impact_i := -1
var _snap_on := 0.0
var _door := 0.0
var _walk := 0.0
var _lens_t0 := -1.0
var _menu_shown := false
var _shot_at := -1.0
var _caption := ""
var _caption_t0 := 0.0
var _caption_col := Color.WHITE
var _big := ""
var _big_t0 := 0.0
var _title_t0 := 1.0e9
var _hb_rate := 0.0
var _hb_next := 0.0
var _tremble := 0.0
var _mochi_close := false

var _cam_c := C
var _cam_z := 1.0
var _cam_from_c := C
var _cam_to_c := C
var _cam_from_z := 1.0
var _cam_to_z := 1.0
var _cam_t0 := 0.0
var _cam_t1 := 0.0

# ------------------------------------------------------------------ nodes
var _mono: SystemFont
var _intro: Node2D
var _snap: Sprite2D
var _exit: Node2D
var _cul: Sprite2D
var _line: Node2D
var _busts: Array = []
var _gates: Array = []
var _decals: Array = []
var _texts: CPainter
var _hud: CPainter
var _ui: Control
var _info: Label
var _hint_lbl: Label
var _btn_retry: Button
var _btn_title: Button
var _go: CPainter
var _go_t0 := -1.0
var _cpainters: Array = []
var _lens_drops: Array = []


# ================================================================== contract hooks
func _debug_start_time() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wrong3-t="):
			var t := clampf(float(a.get_slice("=", 1)), 0.0, _menu_at() + 2.0)
			if Game.shot_path != "":
				_shot_at = t
				return maxf(0.0, t - SHOT_LEAD)
			return t
	return 0.0


func _menu_at() -> float:
	return _mochi_t() + 5.6


## When Mochi's name is called: after everyone else's, the gaps shrinking as the line gets shorter.
func _roll_t(i: int) -> float:
	var t := 12.4
	for k in i:
		t += maxf(0.85, 2.5 - k * 0.24)
	return t


func _mochi_t() -> float:
	return _roll_t(_guests.size() - 1) + 1.2


# ================================================================== building
func _build_scene() -> void:
	_rng.seed = 3232
	_skip_after = 0.5
	var sh := Shader.new()
	sh.code = TAPE_SHADER
	_vhs_mat.shader = sh
	_vhs_mat.set_shader_parameter("red_keep", 1.0)
	_set_vhs(true)
	_put("_fx_desat", 0.85)
	_put("_fx_grain", 0.08)
	_put("_fx_tracking", 0.3)
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Courier New", "Menlo", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_mono.font_weight = 700
	_pick_guests()
	_end_at = _menu_at()
	_build_intro()
	_build_exit()
	_build_line()
	_texts = _cpainter(_over, _draw_texts)
	_hud = _cpainter(self, _draw_hud)
	move_child(_hud, _vhs.get_index() + 1)
	# GAME OVER sits above the tape, crisp, like the menu under it
	_go = _cpainter(self, _draw_gameover)
	move_child(_go, _hud.get_index() + 1)
	_build_menu()
	_show_set("")


func _pick_guests() -> void:
	_culprit = str(Chapters.get_value("culprit", ""))
	var alive := Cast.survivors()
	for id in Cast.ROSTER:
		if id != "mochi" and id != _culprit and alive.has(id):
			_guests.append(id)
	_guests.append("mochi")
	for i in _guests.size():
		_gate_y.append(GATE_UP)
		_gone.append(false)
		_expr.append("sad" if i % 3 == 0 else ("shock" if i % 3 == 1 else "normal"))
		_lamp_on.append(false)


func _lit_mat(light_uv: Vector2, radius: float, light_col: Color, ambient: Color, desat: float, gain: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = LIT_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("light_uv", light_uv)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("light_col", light_col)
	m.set_shader_parameter("ambient", ambient)
	m.set_shader_parameter("desat", desat)
	m.set_shader_parameter("gain", gain)
	return m


func _cpainter(parent: Node, fn: Callable) -> CPainter:
	var p := CPainter.new()
	p.fn = fn
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(p)
	_cpainters.append(p)
	return p


func _root(n: String) -> Node2D:
	var r := Node2D.new()
	r.name = n
	_world.add_child(r)
	return r


func _build_intro() -> void:
	_intro = _root("intro")
	_painter(_intro, func(ci: Node2D) -> void: ci.draw_rect(Rect2(-600, -600, 2480, 1920), Color("040202")))
	_snap = _spr(_intro, Assets.portrait("snapjaw", "happy"), Vector2(640, 500), true)
	_snap.scale = Vector2(1.35, 1.35)
	_snap.material = _lit_mat(Vector2(0.5, 1.1), 1.7, Color(1.0, 0.12, 0.08), Color(0.04, 0.02, 0.03), 0.25, 2.2)


## The culprit walks out through a door of light.
func _build_exit() -> void:
	_exit = _root("exit")
	_painter(_exit, _draw_door)
	_cul = _spr(_exit, Assets.portrait(_culprit, "normal") if _culprit != "" else null, Vector2(640, 760), true)
	_cul.offset = Vector2(0, -300)
	_cul.scale = Vector2(0.9, 0.9)
	_cul.material = _lit_mat(Vector2(0.5, 0.2), 1.5, Color(1.0, 0.95, 0.85), Color(0.05, 0.05, 0.06), 0.3, 1.4)


func _build_line() -> void:
	_line = _root("line")
	var wall := Assets.prop("wv_wall")
	var w := LINE_X0 * 2.0 + SPACING * (_guests.size() - 1)
	var tiles := int(ceil(w / 1280.0)) + 1
	_painter(_line, func(ci: Node2D) -> void: ci.draw_rect(Rect2(-1400, -600, w + 2800, 1920), Color("0b0d0c")))
	for k in tiles:
		var s := _spr(_line, wall, Vector2(k * 1280.0 - 200.0, 0))
		s.modulate = Color(0.85, 0.85, 0.85)
	_painter(_line, _draw_chart)
	_painter(_line, _draw_wall_blood)
	for i in _guests.size():
		var x := LINE_X0 + i * SPACING
		var b := _spr(_line, Assets.portrait(str(_guests[i]), str(_expr[i])), Vector2(x, BUST_FOOT), true)
		b.offset = Vector2(0, -300)
		b.scale = Vector2(GUEST_SC, GUEST_SC)
		b.material = _lit_mat(Vector2(0.5, -0.25), 1.15, Color(1.0, 0.95, 0.82), Color(0.05, 0.06, 0.07), 0.45, 1.5)
		_busts.append(b)
	_painter(_line, _draw_placards)
	for i in _guests.size():
		var g := _spr(_line, Assets.prop("wv_gate"), Vector2.ZERO)
		g.scale = Vector2(GATE_SC, GATE_SC)
		_gates.append(g)
	_painter(_line, _draw_gate_blood)
	_painter(_line, _draw_lamps, true)
	_painter(_line, _draw_parts_line)
	_painter(_line, _draw_impact)


func _build_menu() -> void:
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.visible = false
	add_child(_ui)
	move_child(_ui, _hud.get_index() + 1)
	var pct := roundi(Game.convince)
	_info = Style.title_label("Your Convince Meter was at %d%%" % pct, 32, Style.TEXT, Style.BG_DARK, 10)
	_ui.add_child(_info)
	_info.reset_size()
	_info.position = Vector2(640 - _info.size.x * 0.5, 330)
	var need := roundi(Game.convince_threshold()) if Game.has_method("convince_threshold") else 70
	_hint_lbl = Style.title_label("Convince at least %d%% and point out the real culprit." % need, 24, Style.GOLD, Style.BG_DARK, 8)
	_ui.add_child(_hint_lbl)
	_hint_lbl.reset_size()
	_hint_lbl.position = Vector2(640 - _hint_lbl.size.x * 0.5, 380)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 36)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.position = Vector2(640 - 300, 450)
	box.size = Vector2(600, 64)
	_ui.add_child(box)
	_btn_retry = _make_button(box, "Retry Trial", "retry")
	_btn_title = _make_button(box, "Title", "title")


func _make_button(box: Control, text: String, act: String) -> Button:
	var b := Style.button(text, Vector2(270, 62), 28)
	b.add_theme_font_override("font", Style.display_font())
	b.pressed.connect(_on_button.bind(act))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(func() -> void: Audio.sfx("select", 1.0, -4.0))
	box.add_child(b)
	return b


func _show_set(which: String) -> void:
	_intro.visible = which == "intro"
	_exit.visible = which == "exit"
	_line.visible = which == "line"
	_hud.visible = which != "" and not _menu_shown


# ================================================================== camera
func _cam_cut(c: Vector2, z: float) -> void:
	_cam_from_c = c
	_cam_to_c = c
	_cam_from_z = z
	_cam_to_z = z
	_cam_t0 = _ev_time
	_cam_t1 = _ev_time


func _cam_move(c: Vector2, z: float, dur: float) -> void:
	_cam_from_c = _cam_c
	_cam_from_z = _cam_z
	_cam_to_c = c
	_cam_to_z = z
	_cam_t0 = _ev_time
	_cam_t1 = _ev_time + dur


func _update_camera() -> void:
	var k := 1.0
	if _cam_t1 > _cam_t0:
		k = _ease(clampf((_t - _cam_t0) / (_cam_t1 - _cam_t0), 0.0, 1.0), 1)
	_cam_c = _cam_from_c.lerp(_cam_to_c, k)
	_cam_z = lerpf(_cam_from_z, _cam_to_z, k)
	var sway := Vector2(sin(_t * 0.83) + 0.5 * sin(_t * 1.91 + 1.0), sin(_t * 0.61 + 2.0)) * 1.4
	for n in [_intro, _exit, _line]:
		var r: Node2D = n
		if r.visible:
			r.scale = Vector2(_cam_z, _cam_z)
			r.position = C - _cam_c * _cam_z + sway


func _gx(i: int) -> float:
	return LINE_X0 + i * SPACING


func _line_mid() -> Vector2:
	return Vector2((_gx(0) + _gx(_guests.size() - 1)) * 0.5, 400)


# ================================================================== the timeline
func _schedule() -> void:
	var name := Cast.full_name(_culprit).to_upper() if _culprit != "" else "SOMEBODY ELSE"
	# ---- 0  WRONG
	_at(0.0, _ev_intro)
	_at(0.25, func() -> void: _big_say("WRONG.", Color(0.75, 0.02, 0.06)))
	_at(1.2, func() -> void: _say("THE REAL CULPRIT WAS " + name + ".", Color(0.95, 0.95, 0.95)))
	_at(1.25, func() -> void: _sfx("lx_laugh", 0.95, -3.0))
	# ---- 3  the culprit checks out
	_at(3.0, _ev_exit)
	_at(3.4, func() -> void: _say("CONGRATULATIONS. YOU GET TO CHECK OUT.", AQUA_TXT))
	_at(4.6, func() -> void: _anim(self, "_walk", 0.0, 1.0, 1.0, 3))
	_at(5.4, func() -> void: _anim(self, "_door", 1.0, 0.0, 0.35, 3))
	_at(5.7, func() -> void:
		_sfx("hx_slam", 1.0, 0.0)
		_kick(10.0)
		_say("[ A DOOR CLOSES ]", Color(0.9, 0.9, 0.9)))
	# ---- 6  title
	_at(6.3, _ev_title)
	_at(8.6, func() -> void: _put("_title_t0", 1.0e9))
	# ---- 9  the line-up
	_at(8.8, _ev_line)
	for i in _guests.size():
		_at(9.4 + i * 0.16, _ev_lamp.bind(i))
	_at(11.2, func() -> void: _say("ROLL CALL.", Color(0.95, 0.95, 0.95)))
	for i in _guests.size() - 1:
		var t := _roll_t(i)
		var gap := maxf(0.85, 2.5 - i * 0.24)
		_at(t, _ev_call.bind(i))
		_at(t + gap * 0.62 - 0.34, func() -> void: _sfx("wv_gate", randf_range(0.95, 1.05), 0.0))
		_at(t + gap * 0.62 - 0.12, _ev_drop.bind(i))
		_at(t + gap * 0.62, _ev_impact.bind(i))
		_at(t + gap * 0.62 + 0.07, _ev_impact2.bind(i))
		_at(t + gap * 0.62 + 0.13, func() -> void: _impact = 0)
	# ---- Mochi, alone at the end of the line
	var m := _guests.size() - 1
	var mt := _mochi_t()
	_at(mt - 1.0, _ev_mochi)
	_at(mt + 0.4, func() -> void: _say("(I'm sorry. Everyone... I'm so sorry.)", AQUA_TXT))
	_at(mt + 2.2, _ev_call.bind(m))
	_at(mt + 2.6, func() -> void:
		_sfx("lx_chain", 0.8, 0.0)
		_anim(self, "_gate_lower", 0.0, 1.0, 1.4, 1))
	_at(mt + 4.05, func() -> void: _sfx("wv_gate", 0.9, 2.0))
	_at(mt + 4.27, _ev_drop.bind(m))
	_at(mt + 4.39, _ev_last)
	# ---- the menu
	_at(_menu_at(), func() -> void: _finish(false))


var _gate_lower := 0.0:
	set(v):
		_gate_lower = v
		if _gate_y.size() > 0:
			_gate_y[_gate_y.size() - 1] = lerpf(GATE_UP, BUST_FOOT - 600.0 * GUEST_SC + 8.0, v)


# ------------------------------------------------------------------ events
func _say(text: String, col: Color) -> void:
	_caption = text
	_caption_t0 = _ev_time
	_caption_col = col
	_sfx("sp_type", 1.15, -10.0)


func _big_say(text: String, col: Color) -> void:
	_big = text
	_big_t0 = _ev_time
	_caption_col = col
	_sfx("wrong", 0.7, -2.0)
	_sfx("hx_sting", 1.0, 0.0)
	_kick(12.0)
	_glitch(0.25, 0.8)


func _ev_intro() -> void:
	_show_set("intro")
	_cam_cut(C, 1.0)
	_cam_move(Vector2(640, 380), 1.12, 3.0)
	_put("_fx_static", 1.0)
	_anim(self, "_fx_static", 1.0, 0.0, 0.35, 2)
	_sfx("hx_static_burst", 1.0, -2.0)
	_music(MUSIC_ID, 0.6)


func _ev_exit() -> void:
	_show_set("exit")
	_big = ""
	_cam_cut(Vector2(640, 380), 1.0)
	_cam_move(Vector2(640, 360), 1.08, 3.0)
	_put("_door", 1.0)
	_put("_walk", 0.0)
	_glitch(0.2, 0.5)
	_sfx("hx_static_burst", 1.3, -8.0)


func _ev_title() -> void:
	_show_set("")
	_caption = ""
	_title_t0 = _ev_time
	_sfx("hx_sting", 0.8, 0.0)
	_glitch(0.25, 0.6)


func _ev_line() -> void:
	_show_set("line")
	# the whole line in one wide shot, however long it is
	var span := _gx(_guests.size() - 1) - _gx(0) + 360.0
	var z := minf(0.6, 1280.0 / span)
	_cam_cut(_line_mid() + Vector2(0, 40), z * 0.94)
	_cam_move(_line_mid() + Vector2(0, 60), z, 2.2)


func _ev_lamp(i: int) -> void:
	_lamp_on[i] = true
	_sfx("hx_buzz", randf_range(0.9, 1.15), -12.0)


func _ev_call(i: int) -> void:
	var who := "MOCHI" if str(_guests[i]) == "mochi" else Cast.display_name(str(_guests[i])).to_upper()
	_say("No. %d  —  %s" % [i + 1, who], Color(0.95, 0.95, 0.95))
	_sfx("wv_bell", 1.0, -4.0)
	if i < _guests.size() - 1:
		_cam_move(Vector2(_gx(i) + 40.0, 400), 1.0 + 0.02 * i, 0.45)
		_expr[i] = "shock"
		(_busts[i] as Sprite2D).texture = Assets.portrait(str(_guests[i]), "shock")


func _ev_drop(i: int) -> void:
	_anim(self, "_drop_k", 0.0, 1.0, 0.12, 3)
	_drop_i = i
	_drop_from = float(_gate_y[i])


var _drop_k := 0.0
var _drop_i := -1
var _drop_from := GATE_UP


## The hard frames: white, the spikes at the head; then red, the gate all the way down and the spray.
func _ev_impact(i: int) -> void:
	_gate_y[i] = BUST_FOOT - 230.0
	_drop_i = -1
	_impact = 1
	_impact_i = i
	_hitstop(0.08)
	_kick(22.0)
	_sfx("sp_crush", randf_range(0.95, 1.1), -2.0)


func _ev_impact2(i: int) -> void:
	_gate_y[i] = GATE_DOWN
	_impact = 2
	_hitstop(0.05)
	_kick(16.0)
	_gone[i] = true
	(_busts[i] as Sprite2D).visible = false
	_spawn_blood(i)
	# the next in line sees it
	for k in [i + 1, i + 2]:
		if k < _guests.size():
			(_busts[k] as Sprite2D).texture = Assets.portrait(str(_guests[k]), "shock" if k == i + 1 else "sad")


func _ev_mochi() -> void:
	var m := _guests.size() - 1
	_mochi_close = true
	_cam_move(Vector2(_gx(m), 470), 1.75, 2.6)
	(_busts[m] as Sprite2D).texture = Assets.portrait("mochi", "sad")
	_hb_rate = 0.75
	_hb_next = _ev_time
	if not _ff:
		Audio.stop_music(1.5)
	_music_id = ""
	_anim(self, "_tremble", 0.0, 1.0, 3.0, 1)


func _ev_last() -> void:
	# no white frame for Mochi: straight to black on the impact, and blood on the lens
	var m := _guests.size() - 1
	_gate_y[m] = GATE_DOWN
	_drop_i = -1
	_gone[m] = true
	_hb_rate = 0.0
	_show_set("")
	_caption = ""
	_sfx("sp_crush", 0.85, 2.0)
	_kick(30.0)
	_lens_t0 = _ev_time
	_make_lens()


func _make_lens() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 9393
	_lens_drops.clear()
	for k in 9:
		var p := Vector2(r.randf_range(70.0, 1210.0), r.randf_range(30.0, 300.0))
		_lens_drops.append({"p": p, "r": r.randf_range(10.0, 26.0), "len": r.randf_range(90.0, 300.0), "tau": r.randf_range(0.9, 2.2),
			"d": r.randf_range(0.0, 0.35), "seed": r.randi()})


func _spawn_blood(i: int) -> void:
	var x := _gx(i)
	var r := RandomNumberGenerator.new()
	r.seed = 600 + i
	for k in 110:
		var p := Vector2(x + r.randf_range(-90, 90), r.randf_range(470, 690))
		var ang := deg_to_rad(r.randf_range(-170, -10))
		var v := Vector2(cos(ang), sin(ang)) * r.randf_range(300, 1300)
		_emit("line", p, v, r.randf_range(0.4, 1.0), r.randf_range(3.0, 9.0), BLOOD, 7, 1500.0, 0.4)
	for k in 26:
		var ang2 := deg_to_rad(r.randf_range(-175, -5))
		var d := pow(r.randf(), 1.4) * 330.0 + 30.0
		var dir := Vector2(cos(ang2), sin(ang2))
		_decals.append({"p": Vector2(x, 600) + dir * d, "dir": dir, "r": lerpf(15.0, 5.0, d / 360.0) * r.randf_range(0.7, 1.3), "seed": r.randi(),
			"t": _ev_time + d / 2000.0})
	_decals.append({"p": Vector2(x, 600), "dir": Vector2.ZERO, "r": 70.0, "seed": r.randi(), "t": _ev_time})


# ================================================================== simulation
func _simulate(dt: float) -> void:
	if _drop_i >= 0:
		_gate_y[_drop_i] = lerpf(_drop_from, GATE_DOWN, _drop_k)


# ================================================================== per-frame
func _update_scene(_delta: float) -> void:
	if _shot_at >= 0.0 and _t >= _shot_at and not _ff and Game.main and Game.main.has_method("save_shot"):
		_shot_at = -1.0
		Game.main.save_shot()
	_update_camera()
	if _hb_rate > 0.0 and _t >= _hb_next and not _ff:
		_hb_next = _t + _hb_rate
		_hb_rate = maxf(0.3, _hb_rate * 0.93)
		Audio.sfx("hx_heartbeat", 1.0 + (0.75 - _hb_rate) * 0.6, -1.0)
	if _exit.visible:
		_cul.position = Vector2(640 + _walk * 760.0, 760 + sin(_walk * 18.0) * 6.0 * _walk)
	for i in _guests.size():
		var g: Sprite2D = _gates[i]
		var gw := 300.0 * GATE_SC
		g.position = Vector2(_gx(i) - gw * 0.5, float(_gate_y[i]) - 700.0 * GATE_SC)
		var b: Sprite2D = _busts[i]
		if b.visible:
			var tr := _tremble * 3.0 if i == _guests.size() - 1 else 0.6
			b.position = Vector2(_gx(i) + randf_range(-tr, tr), BUST_FOOT)
	for p in _cpainters:
		if is_instance_valid(p) and (p as CanvasItem).is_visible_in_tree():
			(p as CanvasItem).queue_redraw()


# ================================================================== painters
func _draw_door(ci: Node2D) -> void:
	ci.draw_rect(Rect2(-600, -600, 2480, 1920), Color("050505"))
	# a tall door at the back, light pouring out of it while it's open
	var w := 260.0 * _door
	var rect := Rect2(640 + 380 - w * 0.5, 120, w, 600)
	ci.draw_rect(Rect2(640 + 380 - 150, 106, 300, 620), Color(0.12, 0.12, 0.12), false, 10.0)
	if _door > 0.01:
		ci.draw_rect(rect, Color(0.98, 0.97, 0.9))
		ci.draw_texture_rect(_soft, Rect2(rect.position - Vector2(300, 200), rect.size + Vector2(600, 400)), false, Color(1, 1, 0.95, 0.35 * _door))
		ci.draw_colored_polygon(PackedVector2Array([rect.position + Vector2(0, rect.size.y), rect.end, Vector2(1400, 900), Vector2(300, 900)]),
			Color(1, 1, 0.95, 0.14 * _door))


func _draw_chart(ci: Node2D) -> void:
	# the height chart's numbers, every 120 px, repeated along the wall
	var w := LINE_X0 * 2.0 + SPACING * (_guests.size() - 1)
	var x := -60.0
	while x < w + 400.0:
		for k in 5:
			var y := 120.0 + k * 120.0
			ci.draw_string(_mono, Vector2(x, y - 8), str(9 - k * 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.8, 0.82, 0.78, 0.55))
		x += SPACING * 2.0


func _draw_placards(ci: Node2D) -> void:
	var tex := Assets.prop("wv_placard")
	for i in _guests.size():
		if bool(_gone[i]):
			continue
		var p := Vector2(_gx(i), BUST_FOOT - 48)
		var sz := Vector2(220, 110) * 0.62
		if tex:
			ci.draw_texture_rect(tex, Rect2(p - sz * 0.5, sz), false)
		var s := "No. %d" % (i + 1)
		var tw := _mono.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		ci.draw_string(_mono, p + Vector2(-tw * 0.5, 9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.92, 0.92, 0.88))


func _draw_lamps(ci: Node2D) -> void:
	var tex := Assets.prop("wv_lamp")
	for i in _guests.size():
		var x := _gx(i)
		var on := bool(_lamp_on[i]) and not (randf() < 0.02)
		if tex:
			ci.draw_texture_rect(tex, Rect2(Vector2(x - 42, 40), Vector2(84, 120)), false, Color(1, 1, 1) if on else Color(0.3, 0.3, 0.3))
		if on:
			ci.draw_texture_rect(_soft, Rect2(Vector2(x - 190, 60), Vector2(380, 640)), false, Color(1.0, 0.92, 0.75, 0.22))
			ci.draw_texture_rect(_soft, Rect2(Vector2(x - 40, 100), Vector2(80, 70)), false, Color(1.0, 0.95, 0.85, 0.6))


func _draw_wall_blood(ci: Node2D) -> void:
	for d in _decals:
		var dd: Dictionary = d
		if _t < float(dd["t"]):
			continue
		var dir: Vector2 = dd["dir"]
		if dir == Vector2.ZERO:
			_blot(ci, dd["p"], float(dd["r"]), int(dd["seed"]), 1.0)
			var r := RandomNumberGenerator.new()
			r.seed = int(dd["seed"])
			for k in 6:
				var ln := minf(1.0, (_t - float(dd["t"])) / 3.0) * r.randf_range(40, 140)
				_drip(ci, (dd["p"] as Vector2).x + r.randf_range(-60, 60), (dd["p"] as Vector2).y + r.randf_range(-20, 30), ln, r.randf_range(5, 10))
		else:
			_streak(ci, dd["p"], dir, float(dd["r"]), int(dd["seed"]))


func _draw_gate_blood(ci: Node2D) -> void:
	# what runs down the bars after
	for i in _guests.size():
		if not bool(_gone[i]) or float(_gate_y[i]) < GATE_DOWN - 1.0:
			continue
		var r := RandomNumberGenerator.new()
		r.seed = 700 + i
		var gx0 := _gx(i) - 300.0 * GATE_SC * 0.5
		for k in 5:
			var bx := gx0 + (30 + k * 60) * GATE_SC
			var y0 := r.randf_range(380, 520)
			_drip(ci, bx + r.randf_range(-4, 4), y0, r.randf_range(60, 200), r.randf_range(6, 10))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(_gx(i) - 140, 728), Vector2(_gx(i) + 140, 728), Vector2(_gx(i) + 180, 760), Vector2(_gx(i) - 180, 760)]), BLOOD_D)


func _draw_parts_line(ci: Node2D) -> void:
	for p in _parts.get("line", []):
		var d: Dictionary = p
		var pos: Vector2 = d["p"]
		var v: Vector2 = d["v"]
		var s: float = d["s"]
		var a := clampf(float(d["life"]) / maxf(float(d["max"]), 0.001) * 3.0, 0.0, 1.0)
		var tail := v * 0.025
		if tail.length() > s:
			ci.draw_line(pos - tail, pos, Color(BLOOD_D, a), s * 1.1)
		ci.draw_circle(pos, s, Color(BLOOD, a))


## Hard frames on each impact: white (then red) field, the guest and the gate in black.
func _draw_impact(ci: Node2D) -> void:
	if _impact <= 0 or _impact_i < 0:
		return
	ci.draw_rect(Rect2(-1400, -600, 6000, 1920), Color(0.95, 0.95, 0.92) if _impact == 1 else Color(0.55, 0.0, 0.03))
	var ink := Color(0, 0, 0, 1) if _impact == 1 else Color(0.08, 0.0, 0.0, 1)
	for i in [_impact_i - 1, _impact_i, _impact_i + 1]:
		if i < 0 or i >= _guests.size():
			continue
		var b: Sprite2D = _busts[i]
		var sz := Vector2(480, 600) * GUEST_SC
		if (i == _impact_i and _impact == 1) or (i != _impact_i and b.visible):
			var tex := Assets.portrait(str(_guests[i]), str(_expr[i]) if i != _impact_i else "shock")
			ci.draw_texture_rect(tex, Rect2(Vector2(_gx(i) - sz.x * 0.5, BUST_FOOT - sz.y), sz), false, ink)
		var g: Sprite2D = _gates[i]
		ci.draw_texture_rect(g.texture, Rect2(g.position, Vector2(300, 700) * GATE_SC), false, ink)
	if _impact == 2:
		for p in _parts.get("line", []):
			var pd: Dictionary = p
			ci.draw_circle(pd["p"], float(pd["s"]) * 1.3, Color(0, 0, 0))


func _blot(ci: CanvasItem, c: Vector2, rad: float, seed: int, a: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var pts := PackedVector2Array()
	for k in 14:
		var ang := TAU * k / 14.0
		var rr := rad * r.randf_range(0.7, 1.25)
		pts.append(c + Vector2(cos(ang) * rr, sin(ang) * rr * 0.85))
	ci.draw_colored_polygon(pts, Color(BLOOD_D, a))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.78 + Vector2(-rad * 0.05, -rad * 0.06))
	ci.draw_colored_polygon(inner, Color(BLOOD, a))
	ci.draw_circle(c + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.12, Color(BLOOD_H, 0.5 * a))


func _streak(ci: CanvasItem, c: Vector2, dir: Vector2, rad: float, seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var n := Vector2(-dir.y, dir.x)
	var ln := rad * r.randf_range(3.0, 7.5)
	ci.draw_colored_polygon(PackedVector2Array([c + n * rad * 0.95, c - dir * ln, c - n * rad * 0.95]), BLOOD)
	ci.draw_circle(c, rad, BLOOD_D)
	ci.draw_circle(c - dir * rad * 0.15, rad * 0.8, BLOOD)
	for k in 3:
		ci.draw_circle(c + dir * rad * r.randf_range(1.6, 3.6) + n * rad * r.randf_range(-1.2, 1.2), rad * r.randf_range(0.12, 0.3), BLOOD)


func _drip(ci: CanvasItem, x: float, y0: float, ln: float, w: float, a: float = 1.0) -> void:
	if ln < 0.5:
		return
	ci.draw_circle(Vector2(x, y0), w * 0.8, Color(BLOOD_D, a))
	ci.draw_rect(Rect2(x - w * 0.5, y0, w, ln), Color(BLOOD, a))
	ci.draw_circle(Vector2(x, y0 + ln), w * 0.72, Color(BLOOD, a))
	ci.draw_line(Vector2(x - w * 0.18, y0 + 1.0), Vector2(x - w * 0.18, y0 + ln * 0.92), Color(BLOOD_H, 0.6 * a), maxf(1.0, w * 0.22))


# ------------------------------------------------------------------ screen-space: words, lens, GAME OVER
func _draw_texts(ci: Control) -> void:
	var df := Style.display_font()
	if _big != "":
		var t := _t - _big_t0
		var sz := 150
		var w := df.get_string_size(_big, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var j := Vector2(randf_range(-2, 2), randf_range(-2, 2))
		var a := clampf(t / 0.08, 0.0, 1.0)
		ci.draw_string_outline(df, Vector2(640 - w * 0.5, 230) + j, _big, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 18, Color(0, 0, 0, 0.8 * a))
		ci.draw_string(df, Vector2(640 - w * 0.5, 230) + j, _big, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.75, 0.02, 0.06, a))
	if _title_t0 < 1.0e8:
		var tt := _t - _title_t0
		var flick: Array = [1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1]
		var on: bool = tt > 0.65 or int(flick[int(tt / 0.05) % 13]) == 1
		if on:
			var txt := "PUNISHMENT"
			var w1 := df.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 132).x
			ci.draw_string(df, Vector2(640 - w1 * 0.5 + 5, 300), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 132, Color(0.3, 0.9, 0.85, 0.16))
			ci.draw_string(df, Vector2(640 - w1 * 0.5, 300), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 132, Color(0.68, 0.02, 0.07))
		if tt > 0.5:
			var full := "EVERYONE ELSE"
			var cnt := mini(full.length(), int((tt - 0.5) / 0.05) + 1)
			var w2 := _mono.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			ci.draw_string(_mono, Vector2(640 - w2 * 0.5, 372), full.substr(0, cnt), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, AQUA_TXT)
		if tt > 1.3:
			var a3 := clampf((tt - 1.3) / 0.5, 0.0, 1.0)
			var w3 := df.get_string_size("THE LINE-UP", HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
			ci.draw_string(df, Vector2(640 - w3 * 0.5, 470), "THE LINE-UP", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(BONE_TXT, a3))
	if _caption != "" and _t - _caption_t0 < 3.2:
		var t2 := _t - _caption_t0
		var cnt2 := mini(_caption.length(), int(t2 / 0.04) + 1)
		var shown := _caption.substr(0, cnt2)
		var fs := 30
		var wf := _mono.get_string_size(_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(640 - wf * 0.5, 614)
		ci.draw_rect(Rect2(p + Vector2(-16, -32), Vector2(wf + 32, 44)), Color(0, 0, 0, 0.85))
		ci.draw_string(_mono, p, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _caption_col)
	if _lens_t0 >= 0.0:
		_draw_lens(ci)


func _draw_lens(ci: Control) -> void:
	var t := _t - _lens_t0
	for d in _lens_drops:
		var dd: Dictionary = d
		var td: float = t - float(dd["d"])
		if td < 0.0:
			continue
		var p: Vector2 = dd["p"]
		var r: float = dd["r"]
		var grow := clampf(td / 0.08, 0.0, 1.0)
		_blot(ci, p, r * grow, int(dd["seed"]), 0.92)
		var ln: float = float(dd["len"]) * (1.0 - exp(-td / float(dd["tau"])))
		_drip(ci, p.x + r * 0.15, p.y + r * 0.5, ln, r * 0.42, 0.92)


func _draw_gameover(ci: Control) -> void:
	if _go_t0 < 0.0:
		return
	var df := Style.display_font()
	var t := _t - _go_t0 if not _done else 9.0
	var txt := "GAME OVER"
	var sz := 132
	var w := df.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var p := Vector2(640 - w * 0.5, 262)
	ci.draw_string_outline(df, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 10, Color(BLOOD_D, 1.0))
	ci.draw_string(df, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, BLOOD_H)
	var r := RandomNumberGenerator.new()
	r.seed = 4040
	for i in 10:
		var x := p.x + 30.0 + r.randf() * (w - 60.0)
		_drip(ci, x, p.y - 8.0, minf(1.0, t / 1.5) * r.randf_range(14, 60), r.randf_range(4, 8))


func _draw_hud(ci: Control) -> void:
	var white := Color(0.93, 0.93, 0.93, 0.92)
	var frames := int(_t * 30.0)
	var tc := "%02d:%02d:%02d:%02d" % [0, floori(frames / 1800.0), floori(frames / 30.0) % 60, frames % 30]
	for it in [["REC", Vector2(78, 70), 30], ["SP", Vector2(1168, 70), 30], [tc, Vector2(56, 672), 28]]:
		var s := str(it[0])
		var pos: Vector2 = it[1]
		var fs: int = it[2]
		ci.draw_string(_mono, pos + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
		ci.draw_string(_mono, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white)
	if fmod(_t, 1.0) < 0.6:
		ci.draw_circle(Vector2(58, 60), 10, Color(0.85, 0.05, 0.08))


# ================================================================== the menu
func _finish(skipped: bool) -> void:
	if _menu_shown:
		return
	_menu_shown = true
	_done = true
	if skipped:
		Audio.stop_all_sfx()
	_hint.visible = false
	_hb_rate = 0.0
	# the end state behind the menu: every gate down, the wall red, the line empty
	_show_set("line")
	_hud.visible = false
	_caption = ""
	_big = ""
	_title_t0 = 1.0e9
	_lens_t0 = -1.0
	_impact = 0
	_mochi_close = false
	for i in _guests.size():
		if not bool(_gone[i]):
			_ev_time = _t
			_spawn_blood(i)
		_gone[i] = true
		_gate_y[i] = GATE_DOWN
		(_busts[i] as Sprite2D).visible = false
	_parts.clear()
	for d in _decals:
		(d as Dictionary)["t"] = -100.0
	var span := _gx(_guests.size() - 1) - _gx(0) + 360.0
	_cam_cut(_line_mid() + Vector2(0, 60), minf(0.6, 1280.0 / span))
	_cam_t0 = _t
	_cam_t1 = _t
	_put("_fx_bright", 0.42)
	_put("_fx_static", 0.0)
	_go_t0 = _t
	if Audio.current_music() != MUSIC_ID:
		Audio.play_music(MUSIC_ID, 1.5)
	_update_visuals(0.0)
	for p in _cpainters:
		if is_instance_valid(p):
			(p as CanvasItem).queue_redraw()
	_ui.visible = true
	if Game.autotest:
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(_send.bind("title"))
		return
	if not skipped:
		Audio.sfx("sp_press", 0.8, -4.0)
	_btn_retry.grab_focus()


func _on_button(act: String) -> void:
	Audio.sfx("confirm")
	_send(act)


var _emitted := false


func _send(act: String) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit({"action": act})


func _gui_input(e: InputEvent) -> void:
	if not _menu_shown and _t > 0.5 and e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		_finish(true)
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if _menu_shown or _t < 0.5:
		return
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_finish(true)
		get_viewport().set_input_as_handled()
