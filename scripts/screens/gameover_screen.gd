extends Control
## GAME OVER - "Mochi's Last Soak" (DESIGN section 9). A ~10 s comedic punishment: Mochi soaks in a
## bathtub on a giant stove, the thermometer climbs into the red, steam fills the screen and the
## rubber duck floats away. Then GAME OVER + Retry Trial / Title.
## Emits finished({"action": "retry"|"title"}). Autotest -> "title".
## Any click / key before the menu appears skips straight to it.

signal finished(result: Dictionary)

const Style := preload("res://scripts/ui/style.gd")
const Assets := preload("res://scripts/core/assets.gd")

const MENU_AT := 9.4
const TUB_POS := Vector2(640, 402)
const TUB_SCALE := 0.85
const WATER_Y := 314.0
const MOCHI_POS := Vector2(600, 446)
const DUCK_POS := Vector2(806, 310)
const THERMO_POS := Vector2(1100, 330)
const THERMO_SCALE := 0.9
const FLAME_XS := [430.0, 535.0, 640.0, 745.0, 850.0]
const FLAME_Y := 548.0

var _t := 0.0
var _events: Array = []
var _ev_i := 0
var _done := false
var _menu_shown := false
var _heat := 0.0
var _shake := 0.0
var _bubble_acc := 0.0
var _steam_acc := 0.0
var _sizzle_t := 0.0
var _parts: Array = []
var _steam: Array = []
var _mochi_expr := "happy"
var _glow_tex: Texture2D

var _world: Node2D
var _bg: Sprite2D
var _stove: Sprite2D
var _knob: Sprite2D
var _flames: Array[Sprite2D] = []
var _tub_back: Sprite2D
var _mochi: Sprite2D
var _tub_front: Sprite2D
var _lone_yuzu: Sprite2D
var _duck: Sprite2D
var _thermo: Sprite2D
var _column: ColorRect
var _temp_label: Label
var _snap: Sprite2D
var _fx_back: Node2D
var _fx_front: Node2D
var _steam_layer: Control
var _steam_cover: ColorRect
var _dim: ColorRect
var _bubble_snap: Panel
var _bubble_snap_label: Label
var _bubble_think: Panel
var _bubble_think_label: Label
var _card: Control
var _ui: Control
var _go_label: Label
var _info: Label
var _hint: Label
var _btn_box: HBoxContainer
var _btn_retry: Button
var _btn_title: Button
var _flash: ColorRect
var _duck_floating := false
var _tweens: Array[Tween] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Audio.play_music("gameover")
	_glow_tex = _radial_tex()
	_build()
	if Game.autotest:
		_events.clear()
		_show_menu(true)
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(_emit.bind("title"))
		return
	_schedule()


# ================================================================== building
func _radial_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.4, Color(1, 1, 1, 0.5))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _spr(parent: Node, tex: Texture2D, pos: Vector2, sc: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2(sc, sc)
	parent.add_child(s)
	return s


func _bubble(col: Color) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Style.box(Color(0.09, 0.06, 0.18, 0.94), 16, col, 3))
	p.modulate.a = 0.0
	add_child(p)
	return p


func _build() -> void:
	var back := ColorRect.new()
	back.color = Style.BG_DARK
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_world = Node2D.new()
	add_child(_world)
	_bg = _spr(_world, Assets.prop("exec_soak_bg"), Vector2(640, 360))
	_stove = _spr(_world, Assets.prop("exec_soak_stove"), Vector2(640, 644))
	for x in FLAME_XS:
		var f := _spr(_world, Assets.prop("exec_soak_flame"), Vector2(float(x), FLAME_Y), 0.0)
		f.offset = Vector2(0, -78)
		_flames.append(f)
	_tub_back = _spr(_world, Assets.prop("exec_soak_tub_back"), TUB_POS + Vector2(0, (60.0 - 170.0) * TUB_SCALE), TUB_SCALE)
	_mochi = _spr(_world, Assets.portrait("mochi", "happy"), MOCHI_POS, 0.55)
	_mochi.offset = Vector2(0, -300)
	_fx_back = Node2D.new()
	_world.add_child(_fx_back)
	_fx_back.draw.connect(_draw_parts.bind(0, _fx_back))
	_tub_front = _spr(_world, Assets.prop("exec_soak_tub_front"), TUB_POS, TUB_SCALE)
	_lone_yuzu = _spr(_world, Assets.prop("title_yuzu"), Vector2(600, WATER_Y - 6), 0.5)
	_lone_yuzu.visible = false
	_fx_front = Node2D.new()
	_world.add_child(_fx_front)
	_fx_front.draw.connect(_draw_parts.bind(1, _fx_front))
	_thermo = _spr(_world, Assets.prop("exec_soak_thermo"), THERMO_POS, THERMO_SCALE)
	_column = ColorRect.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.color = Style.AQUA
	_thermo.add_child(_column)
	_update_thermo()
	_temp_label = Style.title_label("38°C", 34, Style.AQUA, Style.BG_DARK, 10)
	_world.add_child(_temp_label)
	_temp_label.reset_size()
	_temp_label.position = THERMO_POS + Vector2(-_temp_label.size.x * 0.5, -250)
	_snap = _spr(_world, Assets.portrait("snapjaw", "happy"), Vector2(-260, 760), 0.75)
	_snap.offset = Vector2(0, -300)
	_knob = _spr(_world, Assets.prop("exec_soak_knob"), Vector2(388, 640), 1.0)

	_steam_layer = Control.new()
	_steam_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_steam_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steam_layer.draw.connect(_draw_steam)
	add_child(_steam_layer)
	_steam_cover = ColorRect.new()
	_steam_cover.color = Color(0.94, 0.95, 1.0, 0.0)
	_steam_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_steam_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_steam_cover)
	_duck = _spr(self, Assets.prop("exec_soak_duck"), DUCK_POS, 0.6)

	_bubble_snap = _bubble(Color("43a047"))
	_bubble_snap_label = Style.label("", 24, Style.TEXT)
	_bubble_snap.add_child(_bubble_snap_label)
	_bubble_think = _bubble(Color("8fd4ff"))
	_bubble_think_label = Style.label("", 24, Color("a8dcff"))
	_bubble_think.add_child(_bubble_think_label)

	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.02, 0.09, 0.85)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_build_card()
	_build_ui()

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _build_card() -> void:
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = Vector2(0, 250)
	_card.size = Vector2(1280, 220)
	_card.pivot_offset = Vector2(640, 110)
	_card.modulate.a = 0.0
	add_child(_card)
	var strip := Panel.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", Style.box(Color(0.32, 0.06, 0.16, 0.95), 0, Style.GOLD, 4))
	strip.position = Vector2(-20, 30)
	strip.size = Vector2(1320, 160)
	_card.add_child(strip)
	var top := Style.title_label("PUNISHMENT TIME!", 30, Style.DANGER, Style.BG_DARK, 10)
	_card.add_child(top)
	top.reset_size()
	top.position = Vector2(640 - top.size.x * 0.5, 44)
	var big := Style.title_label("MOCHI'S LAST SOAK", 86, Style.GOLD, Style.BG_DARK, 18)
	_card.add_child(big)
	big.reset_size()
	big.position = Vector2(640 - big.size.x * 0.5, 82)


func _build_ui() -> void:
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.visible = false
	add_child(_ui)
	_go_label = Style.title_label("GAME OVER", 132, Style.DANGER, Style.BG_DARK, 24)
	_ui.add_child(_go_label)
	_go_label.reset_size()
	_go_label.position = Vector2(640 - _go_label.size.x * 0.5, 215 - _go_label.size.y * 0.5)
	_go_label.pivot_offset = _go_label.size * 0.5
	var pct := roundi(Game.convince)
	_info = Style.title_label("Your Convince Meter was at %d%%" % pct, 32, Style.TEXT, Style.BG_DARK, 10)
	_ui.add_child(_info)
	_info.reset_size()
	_info.position = Vector2(640 - _info.size.x * 0.5, 318)
	_hint = Style.title_label("Convince at least 60% and point out the real culprit.", 24, Style.GOLD, Style.BG_DARK, 8)
	_ui.add_child(_hint)
	_hint.reset_size()
	_hint.position = Vector2(640 - _hint.size.x * 0.5, 368)
	_btn_box = HBoxContainer.new()
	_btn_box.add_theme_constant_override("separation", 36)
	_btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_box.position = Vector2(640 - 300, 440)
	_btn_box.size = Vector2(600, 64)
	_ui.add_child(_btn_box)
	_btn_retry = _make_button("Retry Trial", "retry")
	_btn_title = _make_button("Title", "title")
	for e in [_info, _hint, _btn_box]:
		(e as CanvasItem).modulate.a = 0.0


func _make_button(text: String, act: String) -> Button:
	var b := Style.button(text, Vector2(270, 62), 28)
	b.add_theme_font_override("font", Style.display_font())
	b.pressed.connect(_on_button.bind(act, b))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(_on_focus.bind(b))
	_btn_box.add_child(b)
	return b


# ================================================================== timeline
func _at(time: float, c: Callable) -> void:
	_events.append([time, c])


func _schedule() -> void:
	_at(0.0, _ev_start)
	_at(0.2, _ev_snap_in)
	_at(0.95, _ev_card)
	_at(2.35, _ev_card_out)
	_at(2.45, _ev_knob)
	_at(2.75, _ev_ignite)
	_at(4.1, _think.bind("Is it just me, or is it getting... warm?", 1.6))
	_at(5.5, func() -> void: Audio.sfx("heartbeat"))
	_at(5.9, _think.bind("HOT! HOT! HOT! HOT!", 1.3))
	_at(6.3, func() -> void: Audio.sfx("heartbeat", 1.15))
	_at(6.6, _ev_redline)
	_at(7.0, func() -> void: Audio.sfx("heartbeat", 1.3))
	_at(7.35, _ev_steam_cover)
	_at(7.9, _ev_duck_away)
	_at(8.7, _ev_aftermath)
	_at(9.15, _ev_steam_clear)
	_at(MENU_AT, _show_menu.bind(false))
	_events.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _ev_start() -> void:
	var tw := _tw()
	tw.tween_property(_dim, "color:a", 0.55, 0.5)


func _ev_snap_in() -> void:
	Audio.sfx("wrong")
	var tw := _tw()
	tw.tween_property(_snap, "position:x", 190.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_say("WRONG! The real culprit\nwas Wisp! Snap-snap-snap!", 2.0)


func _ev_card() -> void:
	Audio.sfx("boom")
	Audio.sfx("gavel")
	_shake = 10.0
	_card.scale = Vector2(1.6, 1.6)
	var tw := _tw().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _ev_card_out() -> void:
	var tw := _tw().set_parallel(true)
	tw.tween_property(_card, "position:y", -260.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_dim, "color:a", 0.0, 0.4)
	Audio.sfx("whoosh")


func _ev_knob() -> void:
	_say("Enjoy your bath, Mochi!\nLet me warm it up for you~", 2.4)
	var tw := _tw()
	tw.tween_property(_knob, "rotation", 2.4, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.sfx("tick", 0.9)
	var tw2 := _tw()
	tw2.tween_interval(0.15)
	tw2.tween_callback(func() -> void: Audio.sfx("tick", 1.1))


func _ev_ignite() -> void:
	Audio.sfx("boom", 0.6, -4.0)
	Audio.sfx("sizzle")
	_shake = 6.0
	for i in _flames.size():
		var f := _flames[i]
		var tw := _tw()
		tw.tween_interval(i * 0.05)
		tw.tween_property(f, "scale", Vector2(0.55, 0.55), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw2 := _tw()
	tw2.tween_property(self, "_heat", 1.0, 4.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _ev_redline() -> void:
	Audio.sfx("wrong", 1.3, -4.0)
	_flash_color(Color(1, 0.2, 0.25), 0.35)


func _ev_steam_cover() -> void:
	Audio.sfx("sizzle", 0.8)
	Audio.sfx("whoosh", 0.6)
	var tw := _tw()
	tw.tween_property(_steam_cover, "color:a", 0.94, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _ev_duck_away() -> void:
	Audio.sfx("pop", 1.7)
	_duck_floating = true
	var tw := _tw().set_parallel(true)
	tw.tween_property(_duck, "position", Vector2(1190, -90), 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_duck, "scale", Vector2(0.3, 0.3), 2.6)
	tw.tween_property(_duck, "rotation", 1.2, 2.6)


func _ev_aftermath() -> void:
	# hidden behind the steam: Mochi is gone, only the yuzu is left bobbing.
	_mochi.visible = false
	_lone_yuzu.visible = true
	_heat = 0.0
	for f in _flames:
		(f as Sprite2D).scale = Vector2.ZERO
	_knob.rotation = 0.0
	_snap.texture = Assets.portrait("snapjaw", "happy")
	_update_thermo()


func _ev_steam_clear() -> void:
	var tw := _tw().set_parallel(true)
	tw.tween_property(_steam_cover, "color:a", 0.22, 1.0)
	tw.tween_property(_dim, "color:a", 0.6, 0.8)


func _show_menu(instant: bool) -> void:
	if _menu_shown:
		return
	_menu_shown = true
	_ui.visible = true
	if instant:
		for e in [_info, _hint, _btn_box]:
			(e as CanvasItem).modulate.a = 1.0
		_btn_retry.grab_focus()
		return
	Audio.sfx("boom")
	Audio.sfx("gavel", 0.8)
	_shake = 14.0
	_go_label.scale = Vector2(2.4, 2.4)
	_go_label.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_go_label, "modulate:a", 1.0, 0.1)
	tw.tween_property(_go_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_info, "modulate:a", 1.0, 0.35).set_delay(0.55)
	tw.tween_property(_hint, "modulate:a", 1.0, 0.35).set_delay(0.75)
	_btn_box.position.y = 480
	tw.tween_property(_btn_box, "modulate:a", 1.0, 0.3).set_delay(0.95)
	tw.tween_property(_btn_box, "position:y", 440.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.95)
	tw.chain().tween_callback(_btn_retry.grab_focus)


func _tw() -> Tween:
	var tw := create_tween()
	_tweens.append(tw)
	return tw


## Jump straight to the menu (any input during the animation).
func _skip() -> void:
	for tw in _tweens:
		if tw and tw.is_valid():
			tw.kill()
	_tweens.clear()
	_events.clear()
	_ev_i = 0
	_mochi.visible = false
	_lone_yuzu.visible = true
	_heat = 0.0
	for f in _flames:
		(f as Sprite2D).scale = Vector2.ZERO
	_card.modulate.a = 0.0
	_bubble_snap.modulate.a = 0.0
	_bubble_think.modulate.a = 0.0
	_snap.position.x = 190.0
	_duck.visible = false
	_steam.clear()
	_parts.clear()
	_knob.rotation = 0.0
	_card.visible = false
	_flash.color.a = 0.0
	_steam_cover.color.a = 0.22
	_dim.color.a = 0.6
	_update_thermo()
	_show_menu(false)


func _on_focus(b: Button) -> void:
	Audio.sfx("select", 1.0, -4.0)
	for o in [_btn_retry, _btn_title]:
		var ob: Button = o
		ob.pivot_offset = ob.size * 0.5
		var tw := ob.create_tween()
		tw.tween_property(ob, "scale", Vector2(1.07, 1.07) if ob == b else Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_button(act: String, b: Button) -> void:
	if _done:
		return
	Audio.sfx("confirm")
	b.pivot_offset = b.size * 0.5
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2(1.16, 1.16), 0.07)
	tw.tween_property(b, "scale", Vector2.ONE, 0.18)
	tw.tween_callback(_emit.bind(act))
	_done = true


func _emit(act: String) -> void:
	finished.emit({"action": act})


func _unhandled_input(e: InputEvent) -> void:
	if _menu_shown or _done:
		return
	if _t < 0.4:
		return
	var pressed := false
	if e is InputEventMouseButton and e.pressed:
		pressed = true
	elif e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		pressed = true
	if pressed:
		_skip()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ helpers
func _say(text: String, dur: float) -> void:
	_bubble_snap_label.text = text
	_bubble_snap_label.reset_size()
	_bubble_snap_label.position = Vector2(16, 8)
	_bubble_snap.size = _bubble_snap_label.size + Vector2(32, 16)
	_bubble_snap.position = Vector2(28, 196)
	_pop_bubble(_bubble_snap, dur)


func _think(text: String, dur: float) -> void:
	_bubble_think_label.text = "(" + text + ")"
	_bubble_think_label.reset_size()
	_bubble_think_label.position = Vector2(16, 8)
	_bubble_think.size = _bubble_think_label.size + Vector2(32, 16)
	_bubble_think.position = Vector2(clampf(640 - _bubble_think.size.x * 0.5, 20, 1260 - _bubble_think.size.x), 98)
	_pop_bubble(_bubble_think, dur)


func _pop_bubble(p: Panel, dur: float) -> void:
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(0.6, 0.6)
	p.modulate.a = 0.0
	var tw := _tw()
	tw.tween_property(p, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(p, "modulate:a", 0.0, 0.2)
	Audio.sfx("blip", 1.0, -4.0)


func _flash_color(c: Color, dur: float) -> void:
	_flash.color = Color(c, 0.45)
	_tw().tween_property(_flash, "color:a", 0.0, dur)


func _update_thermo() -> void:
	# tube interior in thermometer texture coordinates (130x470, centered on the sprite)
	var bottom := 400.0
	var top_y := 40.0
	var f := 0.24 + 0.76 * _heat
	var y := lerpf(bottom, top_y, f)
	_column.position = Vector2(53.0 - 65.0, y - 235.0)
	_column.size = Vector2(24, bottom - y)
	var cool := Style.AQUA
	var warm := Style.YUZU
	var hot := Style.DANGER
	_column.color = cool.lerp(warm, clampf(_heat * 2.0, 0.0, 1.0)) if _heat < 0.5 else warm.lerp(hot, clampf((_heat - 0.5) * 2.0, 0.0, 1.0))
	if _temp_label:
		_temp_label.text = "%d°C" % roundi(lerpf(38.0, 104.0, _heat))
		_temp_label.add_theme_color_override("font_color", _column.color)


func _part(layer: int, pos: Vector2, vel: Vector2, life: float, r: float, col: Color, kind: int, grav: float = 0.0) -> void:
	if _parts.size() > 600:
		return
	_parts.append({"l": layer, "p": pos, "v": vel, "t": 0.0, "life": life, "r": r, "c": col, "k": kind, "g": grav})


# ================================================================== per-frame
func _process(delta: float) -> void:
	_t += delta
	while _ev_i < _events.size() and float(_events[_ev_i][0]) <= _t:
		var c: Callable = _events[_ev_i][1]
		_ev_i += 1
		c.call()
	_update_heat(delta)
	_update_parts(delta)
	if _shake > 0.05:
		_world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 8.0))
	else:
		_world.position = Vector2.ZERO
	if _lone_yuzu.visible:
		_lone_yuzu.position = Vector2(600 + sin(_t * 1.3) * 18.0, WATER_Y - 6 + sin(_t * 2.6) * 4.0)
		_lone_yuzu.rotation = sin(_t * 1.7) * 0.3
	if not _duck_floating and _duck.visible:
		_duck.position = DUCK_POS + Vector2(sin(_t * 1.5) * 10.0, sin(_t * 3.1) * 3.0 - _heat * absf(sin(_t * 17.0)) * 8.0)
		_duck.rotation = sin(_t * 2.2) * (0.12 + _heat * 0.3)
	_steam_layer.queue_redraw()


func _update_heat(delta: float) -> void:
	var h := _heat
	if _mochi.visible:
		var want := "happy"
		if h > 0.72:
			want = "sad"
		elif h > 0.42:
			want = "shock"
		elif h > 0.16:
			want = "normal"
		if want != _mochi_expr:
			_mochi_expr = want
			_mochi.texture = Assets.portrait("mochi", want)
			var tw := create_tween()
			tw.tween_property(_mochi, "scale", Vector2(0.6, 0.5), 0.06)
			tw.tween_property(_mochi, "scale", Vector2(0.55, 0.55), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if want == "shock":
				_snap.texture = Assets.portrait("snapjaw", "happy")
		var tremble := h * h * 6.0
		_mochi.offset = Vector2(randf_range(-tremble, tremble), -300.0 + sin(_t * 2.0) * 3.0)
		_mochi.modulate = Color(1.0, 1.0 - 0.28 * h, 1.0 - 0.32 * h)
	for i in _flames.size():
		var f := _flames[i]
		if f.scale.x > 0.01 and h > 0.0:
			var base := 0.55 + 0.5 * h
			var fl := sin(_t * 17.0 + i * 1.9) * 0.06 + sin(_t * 29.0 + i) * 0.04
			f.scale = Vector2(base * (1.0 - fl), base * (1.0 + fl * 1.6))
	if h > 0.0:
		_update_thermo()
		_shake = maxf(_shake, h * h * 3.5)
		# boiling bubbles on the water surface
		_bubble_acc += (2.0 + h * 46.0) * delta
		while _bubble_acc >= 1.0:
			_bubble_acc -= 1.0
			var x := randf_range(430, 850)
			_part(1, Vector2(x, WATER_Y + randf_range(-14, 18)), Vector2(0, -6), randf_range(0.25, 0.5), randf_range(4, 10) * (0.6 + h), Color(0.92, 1.0, 1.0, 0.9), 1)
		_steam_acc += (1.0 + h * 9.0) * delta
		while _steam_acc >= 1.0:
			_steam_acc -= 1.0
			_steam.append({"p": Vector2(randf_range(420, 860), WATER_Y), "v": Vector2(randf_range(-30, 30), randf_range(-90, -50)), "t": 0.0,
				"life": randf_range(2.0, 3.4), "r": randf_range(50, 90)})
		_sizzle_t -= delta
		if _sizzle_t <= 0.0:
			_sizzle_t = 1.25 - h * 0.6
			Audio.sfx("sizzle", randf_range(0.9, 1.1), -6.0 + h * 4.0)
		if h > 0.75 and randf() < 0.3:
			_part(1, Vector2(randf_range(520, 690), randf_range(170, 260)), Vector2(randf_range(-60, 60), randf_range(-80, -20)), 0.6, randf_range(4, 7), Color(0.6, 0.85, 1.0, 0.9), 0, 300.0)
	# thermometer glow when in the red
	if h > 0.78:
		_thermo.modulate = Color(1, 1, 1).lerp(Color(1.4, 0.7, 0.7), 0.5 + 0.5 * sin(_t * 14.0))
	else:
		_thermo.modulate = Color.WHITE


func _update_parts(delta: float) -> void:
	var keep: Array = []
	for p in _parts:
		var d: Dictionary = p
		d["t"] = float(d["t"]) + delta
		if float(d["t"]) >= float(d["life"]):
			continue
		var v: Vector2 = d["v"]
		v.y += float(d["g"]) * delta
		d["v"] = v
		d["p"] = (d["p"] as Vector2) + v * delta
		keep.append(d)
	_parts = keep
	var keep2: Array = []
	for s in _steam:
		var d: Dictionary = s
		d["t"] = float(d["t"]) + delta
		if float(d["t"]) >= float(d["life"]):
			continue
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
		keep2.append(d)
	_steam = keep2
	_fx_back.queue_redraw()
	_fx_front.queue_redraw()


func _draw_parts(layer: int, node: Node2D) -> void:
	for p in _parts:
		var d: Dictionary = p
		if int(d["l"]) != layer:
			continue
		var f := float(d["t"]) / float(d["life"])
		var col: Color = d["c"]
		var pos: Vector2 = d["p"]
		var r := float(d["r"])
		if int(d["k"]) == 1:
			node.draw_arc(pos, r * (0.6 + f * 0.6), PI, TAU, 12, Color(col, col.a * (1.0 - f)), 2.5, true)
			node.draw_circle(pos + Vector2(-r * 0.3, -r * 0.4), r * 0.18, Color(1, 1, 1, 0.8 * (1.0 - f)))
		else:
			node.draw_circle(pos, r * (1.0 - f * 0.4), Color(col, col.a * (1.0 - f)))


func _draw_steam() -> void:
	for s in _steam:
		var d: Dictionary = s
		var f := float(d["t"]) / float(d["life"])
		var a := sin(f * PI) * 0.22
		var r := float(d["r"]) * (1.0 + f * 2.2)
		var pos: Vector2 = d["p"]
		pos += _world.position
		_steam_layer.draw_texture_rect(_glow_tex, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, a))
