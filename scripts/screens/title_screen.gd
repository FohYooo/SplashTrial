extends Control
## Title screen: purple-to-teal sky + key art (slow parallax), steam wisps, rising bubbles,
## the SPLASH TRIAL logo drawn in code, capybaras peeking from the bottom edge, and the menu.
## Emits finished({"action": "new"|"continue"|"case<N>"|"credits"|"quit"}).
## Autotest -> "new", or "case<N>" with --pick-case=<N>.

signal finished(result: Dictionary)

const Style := preload("res://scripts/ui/style.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Chapters := preload("res://scripts/data/chapters.gd")

const LOGO_SIZE := 118
const LOGO_Y := 148.0
const PEEK_SLOTS := [
	{"x": 96.0, "k": 0.5, "rot": 0.13, "vis": 205.0},
	{"x": 300.0, "k": 0.36, "rot": -0.07, "vis": 132.0},
	{"x": 980.0, "k": 0.36, "rot": 0.07, "vis": 132.0},
	{"x": 1184.0, "k": 0.5, "rot": -0.13, "vis": 205.0},
]
const PEEK_START := ["mochi", "lulu", "bruno", "coco"]
const MOODS := {"new": "happy", "continue": "happy", "cases": "shock", "case1": "happy", "case2": "shock", "back": "normal", "credits": "normal", "quit": "sad"}
const MENU_W := 330.0
const CASE_MENU_W := 540.0

## Fill shader for the logo letters: white fill pixels get a yuzu-gold gradient with a gloss band,
## the dark outline is left alone.
const LOGO_SHADER := """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(1.0, 0.96, 0.66, 1.0);
uniform vec4 mid_col : source_color = vec4(1.0, 0.80, 0.30, 1.0);
uniform vec4 bot_col : source_color = vec4(1.0, 0.50, 0.12, 1.0);
uniform float y0 = 0.0;
uniform float y1 = 100.0;
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec4 c = COLOR;
	if (c.r + c.g + c.b > 2.6) {
		float t = clamp((lp.y - y0) / (y1 - y0), 0.0, 1.0);
		vec3 g = t < 0.5 ? mix(top_col.rgb, mid_col.rgb, t * 2.0) : mix(mid_col.rgb, bot_col.rgb, (t - 0.5) * 2.0);
		g += vec3(0.22) * (1.0 - smoothstep(0.0, 0.05, abs(t - 0.34)));
		c.rgb = g;
	}
	COLOR = c;
}
"""

var _t := 0.0
var _chosen := false
var _intro_done := false
var _par := Vector2.ZERO
var _bg: TextureRect
var _steam_layer: Control
var _logo: Control
var _letters: Array[Control] = []
var _drop: Sprite2D
var _wave: Sprite2D
var _subtitle: Label
var _sub_yuzus: Array[Sprite2D] = []
var _menu: VBoxContainer
var _in_cases := false
var _case_note: Label
var _buttons: Array[Button] = []
var _actions: Array[String] = []
var _ind_l: Sprite2D
var _ind_r: Sprite2D
var _ind_target := Vector2.ZERO
var _ind_w := 0.0
var _peek: Array[Sprite2D] = []
var _peek_ids: Array[String] = []
var _peek_busy: Array[bool] = []
var _peek_timer := 3.0
var _mood := "happy"
var _front: Control
var _glow_tex: Texture2D
var _spark_tex: Texture2D
var _yuzu_tex: Texture2D
var _steam: Array = []
var _bubbles: Array = []
var _drops: Array = []
var _twinkles: Array = []
var _intro_tweens: Array[Tween] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Audio.play_music("title")
	_glow_tex = _radial_tex()
	_spark_tex = Assets.prop("title_sparkle")
	_yuzu_tex = Assets.prop("title_yuzu")
	_build_background()
	_build_peekers()
	_build_logo()
	_build_menu()
	_front = Control.new()
	_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	add_child(_front)
	var ver := Style.label("v1.0", 17, Style.TEXT_DIM)
	ver.add_theme_color_override("font_outline_color", Style.BG_DARK)
	ver.add_theme_constant_override("outline_size", 6)
	add_child(ver)
	ver.reset_size()
	ver.position = Vector2(1268 - ver.size.x, 8)
	var by := Style.label("All the hard work done by Foh, Noomie and Dani  ·  little bit of help from Claude", 15, Style.TEXT_DIM)
	by.add_theme_color_override("font_outline_color", Style.BG_DARK)
	by.add_theme_constant_override("outline_size", 5)
	add_child(by)
	by.reset_size()
	by.position = Vector2(640 - by.size.x * 0.5, 694)
	for i in 14:
		_steam.append(_new_steam(true))
	for i in 18:
		_bubbles.append(_new_bubble(true))
	for i in 14:
		_twinkles.append({"p": Vector2(randf_range(320, 1240), randf_range(20, 330)), "ph": randf() * TAU, "sp": randf_range(1.5, 3.2), "r": randf_range(7, 14)})
	_intro()
	if Game.autotest:
		finished.emit.call_deferred({"action": "case%d" % Game.debug_case if Game.debug_case > 0 else "new"})
		_chosen = true
	elif Game.debug_case_menu:
		_skip_intro()
		_open_cases()


# ------------------------------------------------------------------ building
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


func _build_background() -> void:
	var g := Gradient.new()
	g.set_color(0, Color("1e0a3c"))
	g.set_color(1, Color("0c6c72"))
	g.add_point(0.55, Color("3b1d6e"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var grad := TextureRect.new()
	grad.texture = gt
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)
	if FileAccess.file_exists("res://art/bg/title.svg"):
		_bg = TextureRect.new()
		_bg.texture = Assets.bg("title")
		_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg.stretch_mode = TextureRect.STRETCH_SCALE
		_bg.size = Vector2(1280, 720) * 1.06
		_bg.position = -(_bg.size - Vector2(1280, 720)) * 0.5
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
	# soft darkening at the top so the logo pops
	var vg := Gradient.new()
	vg.set_color(0, Color(0.05, 0.02, 0.12, 0.55))
	vg.set_color(1, Color(0.05, 0.02, 0.12, 0.0))
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill_from = Vector2(0, 0)
	vt.fill_to = Vector2(0, 1)
	vt.width = 8
	vt.height = 64
	var top := TextureRect.new()
	top.texture = vt
	top.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.stretch_mode = TextureRect.STRETCH_SCALE
	top.size = Vector2(1280, 330)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_steam_layer = Control.new()
	_steam_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_steam_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steam_layer.draw.connect(_draw_steam)
	add_child(_steam_layer)


func _build_peekers() -> void:
	for i in PEEK_SLOTS.size():
		var slot: Dictionary = PEEK_SLOTS[i]
		var id: String = PEEK_START[i]
		var s := Sprite2D.new()
		s.texture = Assets.portrait(id, "happy")
		s.offset = Vector2(0, -300)
		var k: float = slot["k"]
		s.scale = Vector2(k, k)
		s.rotation = float(slot["rot"])
		s.position = Vector2(float(slot["x"]), _peek_y(i, true))
		add_child(s)
		_peek.append(s)
		_peek_ids.append(id)
		_peek_busy.append(false)


func _peek_y(i: int, hidden: bool) -> float:
	var slot: Dictionary = PEEK_SLOTS[i]
	var k: float = slot["k"]
	if hidden:
		return 720.0 + 600.0 * k + 30.0
	return 720.0 + 600.0 * k - float(slot["vis"])


func _letter_label(ch: String, col: Color, outline: Color, osize: int) -> Label:
	var l := Label.new()
	l.text = ch
	l.add_theme_font_override("font", Style.display_font())
	l.add_theme_font_size_override("font_size", LOGO_SIZE)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", osize)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_logo() -> void:
	_logo = Control.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.size = Vector2(1280, 330)
	add_child(_logo)
	var font := Style.display_font()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = LOGO_SHADER
	mat.shader = sh
	var asc := font.get_ascent(LOGO_SIZE)
	mat.set_shader_parameter("y0", asc - LOGO_SIZE * 0.74)
	mat.set_shader_parameter("y1", asc + LOGO_SIZE * 0.02)
	var words := ["SPLASH", "TRIAL"]
	var drop_w := 128.0
	var spacing := 1.0
	var total := drop_w
	for w in words:
		for ch in w:
			total += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, LOGO_SIZE).x + spacing
	var x := 640.0 - total * 0.5
	# splash wave under the letters
	var wtex := Assets.prop("title_wave")
	if wtex:
		_wave = Sprite2D.new()
		_wave.texture = wtex
		_wave.position = Vector2(640, LOGO_Y + 66)
		_wave.scale = Vector2(total / 900.0 * 1.02, 0.62)
		_wave.modulate.a = 0.0
		_logo.add_child(_wave)
	var idx := 0
	for wi in words.size():
		var word: String = words[wi]
		for ch in word:
			var adv := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, LOGO_SIZE).x
			var holder := Control.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.position = Vector2(x + adv * 0.5, LOGO_Y)
			holder.set_meta("i", idx)
			holder.set_meta("home", holder.position)
			_logo.add_child(holder)
			var shadow := _letter_label(ch, Color(0.06, 0.02, 0.14, 0.6), Color(0.06, 0.02, 0.14, 0.6), 34)
			var rim := _letter_label(ch, Style.AQUA_DEEP, Style.AQUA, 34)
			var fill := _letter_label(ch, Color.WHITE, Style.BG_DARK, 14)
			fill.material = mat
			for l in [shadow, rim, fill]:
				var lab: Label = l
				holder.add_child(lab)
				lab.reset_size()
				lab.position = -lab.size * 0.5
			shadow.position += Vector2(6, 10)
			holder.modulate.a = 0.0
			_letters.append(holder)
			x += adv + spacing
			idx += 1
		if wi == 0:
			var dtex := Assets.prop("title_drop")
			if dtex:
				_drop = Sprite2D.new()
				_drop.texture = dtex
				_drop.position = Vector2(x + drop_w * 0.5, LOGO_Y - 4)
				_drop.scale = Vector2(0.55, 0.55)
				_drop.set_meta("home", _drop.position)
				_drop.modulate.a = 0.0
				_logo.add_child(_drop)
			x += drop_w
	_subtitle = Style.title_label("Murder at Yuzu Springs", 38, Style.TEXT, Style.BG_DARK, 12)
	_logo.add_child(_subtitle)
	_subtitle.reset_size()
	_subtitle.position = Vector2(640 - _subtitle.size.x * 0.5, LOGO_Y + 86)
	_subtitle.pivot_offset = _subtitle.size * 0.5
	_subtitle.modulate.a = 0.0
	# 3D walk-around version badge (a child of the subtitle, so it shares its fade-in)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bst := Style.box(Color(0.05, 0.03, 0.11, 0.9), 12, Style.AQUA, 2)
	bst.content_margin_left = 16
	bst.content_margin_right = 16
	bst.content_margin_top = 1
	bst.content_margin_bottom = 1
	badge.add_theme_stylebox_override("panel", bst)
	badge.add_child(Style.title_label("3D WALK-AROUND EDITION", 19, Style.AQUA, Style.BG_DARK, 6))
	_subtitle.add_child(badge)
	var bsz := badge.get_combined_minimum_size()
	badge.size = bsz
	badge.position = Vector2((_subtitle.size.x - bsz.x) * 0.5, _subtitle.size.y + 2)
	if _yuzu_tex:
		for side in [-1.0, 1.0]:
			var y := Sprite2D.new()
			y.texture = _yuzu_tex
			y.scale = Vector2(0.36, 0.36)
			y.position = Vector2(640 + side * (_subtitle.size.x * 0.5 + 34), LOGO_Y + 86 + _subtitle.size.y * 0.5)
			y.set_meta("home", y.position)
			y.modulate.a = 0.0
			_logo.add_child(y)
			_sub_yuzus.append(y)


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.position = Vector2(640.0 - MENU_W * 0.5, 362)
	add_child(_menu)
	_case_note = Style.label("Case 2 opens with the ending of Case 1.", 19, Style.TEXT_DIM)
	_case_note.add_theme_color_override("font_outline_color", Style.BG_DARK)
	_case_note.add_theme_constant_override("outline_size", 6)
	_case_note.visible = false
	add_child(_case_note)
	_case_note.reset_size()
	_case_note.position = Vector2(640.0 - _case_note.size.x * 0.5, 574)
	_fill_menu(_main_items(), MENU_W, true)
	_ind_l = Sprite2D.new()
	_ind_r = Sprite2D.new()
	for s in [_ind_l, _ind_r]:
		var sp: Sprite2D = s
		sp.texture = _yuzu_tex
		sp.scale = Vector2(0.3, 0.3)
		sp.modulate.a = 0.0
		add_child(sp)


func _main_items() -> Array:
	var items := [["New Game", "new"]]
	if Game.has_save():
		items.append(["Continue", "continue"])
	items.append(["Choose Case", "cases"])
	items.append(["Credits", "credits"])
	items.append(["Quit", "quit"])
	return items


func _case_items() -> Array:
	var items := []
	for ch in range(1, Chapters.LAST + 1):
		var d := Chapters.data(ch)
		items.append(["%s: %s" % [d["case"], d["title"]], "case%d" % ch])
	items.append(["Back", "back"])
	return items


## Replaces the menu's buttons. `hidden` leaves them invisible for the title intro to fade in.
func _fill_menu(items: Array, width: float, hidden: bool) -> void:
	for old in _buttons:
		_menu.remove_child(old)
		old.queue_free()
	_buttons.clear()
	_actions.clear()
	var tight := items.size() > 4
	_menu.add_theme_constant_override("separation", 10 if tight else 14)
	_menu.position.x = 640.0 - width * 0.5
	_menu.size = Vector2(width, 10)
	for it in items:
		var b := Style.button(str(it[0]), Vector2(width, 50 if tight else 56), 26 if tight else 27)
		b.add_theme_font_override("font", Style.display_font())
		b.add_theme_stylebox_override("normal", Style.box(Color(0.10, 0.06, 0.22, 0.82), 14, Style.AQUA_DEEP, 3))
		b.add_theme_stylebox_override("hover", Style.box(Color(0.20, 0.12, 0.40, 0.92), 14, Style.GOLD, 3))
		b.add_theme_stylebox_override("focus", Style.box(Color(0.20, 0.12, 0.40, 0.92), 14, Style.GOLD, 3))
		b.add_theme_stylebox_override("pressed", Style.box(Color(0.10, 0.45, 0.50, 0.98), 14, Style.YUZU, 3))
		var act: String = it[1]
		b.pressed.connect(_choose.bind(act, b))
		b.mouse_entered.connect(_on_hover.bind(b))
		b.focus_entered.connect(_on_focus.bind(b, act))
		if hidden:
			b.modulate.a = 0.0
		_menu.add_child(b)
		_buttons.append(b)
		_actions.append(act)


func _open_cases() -> void:
	_in_cases = true
	_fill_menu(_case_items(), CASE_MENU_W, false)
	_case_note.visible = true
	_focus_action.call_deferred("case1")


func _close_cases() -> void:
	_in_cases = false
	_fill_menu(_main_items(), MENU_W, false)
	_case_note.visible = false
	_focus_action.call_deferred("cases")


## Deferred so the menu has laid out its new buttons before the indicator reads their position.
func _focus_action(act: String) -> void:
	_buttons[maxi(_actions.find(act), 0)].grab_focus()


func _intro() -> void:
	Audio.sfx("whoosh", 0.8, -6.0)
	for i in _letters.size():
		var h: Control = _letters[i]
		var home: Vector2 = h.get_meta("home")
		h.position = home + Vector2(0, -260)
		h.rotation = randf_range(-0.5, 0.5)
		var tw := _itw().set_parallel(true)
		var d := 0.08 + i * 0.05
		tw.tween_property(h, "modulate:a", 1.0, 0.15).set_delay(d)
		tw.tween_property(h, "position", home, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(d)
		tw.tween_property(h, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)
	if _drop:
		var home: Vector2 = _drop.get_meta("home")
		_drop.position = home + Vector2(0, -420)
		_drop.scale = Vector2(0.4, 0.75)
		var tw := _itw()
		tw.tween_interval(0.42)
		tw.tween_property(_drop, "modulate:a", 1.0, 0.05)
		tw.parallel().tween_property(_drop, "position", home, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_drop_landed)
		tw.tween_property(_drop, "scale", Vector2(0.72, 0.42), 0.07)
		tw.tween_property(_drop, "scale", Vector2(0.55, 0.55), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _wave:
		var tw2 := _itw()
		tw2.tween_interval(0.7)
		tw2.tween_property(_wave, "modulate:a", 1.0, 0.4)
	var tw3 := _itw().set_parallel(true)
	_subtitle.scale = Vector2(0.7, 0.7)
	tw3.tween_property(_subtitle, "modulate:a", 1.0, 0.3).set_delay(0.85)
	tw3.tween_property(_subtitle, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.85)
	for y in _sub_yuzus:
		tw3.tween_property(y, "modulate:a", 1.0, 0.3).set_delay(0.95)
	for i in _buttons.size():
		var b: Button = _buttons[i]
		tw3.tween_property(b, "modulate:a", 1.0, 0.25).set_delay(1.0 + i * 0.08)
	tw3.chain().tween_callback(_intro_finished)
	for i in _peek.size():
		var tw4 := _itw()
		tw4.tween_interval(0.9 + i * 0.12)
		tw4.tween_property(_peek[i], "position:y", _peek_y(i, false), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _itw() -> Tween:
	var tw := create_tween()
	_intro_tweens.append(tw)
	return tw


func _drop_landed() -> void:
	Audio.sfx("splash", 1.0, -3.0)
	var c := _drop.position + _logo.position + Vector2(0, 40)
	for i in 30:
		var a := randf_range(PI * 1.05, PI * 1.95)
		_drops.append({"p": c, "v": Vector2.from_angle(a) * randf_range(180, 460), "r": randf_range(3, 8), "t": 0.0, "life": randf_range(0.6, 1.0), "k": 0})


func _intro_finished() -> void:
	if _intro_done:
		return
	_intro_done = true
	if not _buttons.is_empty() and not _chosen:
		_buttons[0].grab_focus()


# ------------------------------------------------------------------ menu
func _on_hover(b: Button) -> void:
	if not _chosen and b.has_focus() == false:
		b.grab_focus()


func _on_focus(b: Button, act: String) -> void:
	if _intro_done:
		Audio.sfx("select", 1.0, -4.0)
	for other in _buttons:
		var ob: Button = other
		ob.pivot_offset = ob.size * 0.5
		var tw := ob.create_tween()
		tw.tween_property(ob, "scale", Vector2(1.07, 1.07) if ob == b else Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ind_target = b.global_position - global_position + b.size * 0.5
	_ind_w = b.size.x * 0.5 + 34.0
	if _ind_l.modulate.a < 0.1:
		_ind_l.position = _ind_target - Vector2(_ind_w, 0)
		_ind_r.position = _ind_target + Vector2(_ind_w, 0)
	_ind_l.modulate.a = 1.0
	_ind_r.modulate.a = 1.0
	var mood: String = MOODS.get(act, "happy")
	if mood != _mood:
		_mood = mood
		for i in _peek.size():
			_peek[i].texture = Assets.portrait(_peek_ids[i], _mood)
			var s := _peek[i]
			var tw2 := s.create_tween()
			tw2.tween_property(s, "position:y", _peek_y(i, false) + 14.0, 0.07)
			tw2.tween_property(s, "position:y", _peek_y(i, false), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _choose(act: String, b: Button) -> void:
	if _chosen:
		return
	if act == "cases" or act == "back":
		Audio.sfx("confirm")
		# Deferred: this runs inside the pressed button's own signal, and that button gets replaced.
		(_open_cases if act == "cases" else _close_cases).call_deferred()
		return
	_chosen = true
	Audio.sfx("confirm")
	if act == "new" or act.begins_with("case"):
		Audio.sfx("splash", 1.1, -4.0)
	var c := b.global_position - global_position + b.size * 0.5
	for i in 26:
		var a := randf() * TAU
		_drops.append({"p": c + Vector2(cos(a) * b.size.x * 0.4, sin(a) * 20.0), "v": Vector2.from_angle(a) * randf_range(120, 360), "r": randf_range(3, 7), "t": 0.0, "life": randf_range(0.5, 0.9), "k": 0})
	b.pivot_offset = b.size * 0.5
	var tw := create_tween()
	tw.tween_property(b, "scale", Vector2(1.18, 1.18), 0.08)
	tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_emit.bind(act))
	for i in _peek.size():
		var s := _peek[i]
		var tw2 := s.create_tween()
		tw2.tween_property(s, "position:y", _peek_y(i, false) - 30.0, 0.12)
		tw2.tween_property(s, "position:y", _peek_y(i, false), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _emit(act: String) -> void:
	finished.emit({"action": act})


func _unhandled_input(e: InputEvent) -> void:
	if _chosen:
		return
	# Any key/click during the intro snaps straight to the menu.
	if not _intro_done and (e is InputEventKey or e is InputEventMouseButton) and e.is_pressed():
		_skip_intro()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		if k.keycode == KEY_ESCAPE and _in_cases:
			Audio.sfx("confirm")
			_close_cases()
			get_viewport().set_input_as_handled()
		elif k.keycode in [KEY_UP, KEY_DOWN, KEY_W, KEY_S] and not _any_focus():
			_buttons[0].grab_focus()
			get_viewport().set_input_as_handled()


func _any_focus() -> bool:
	for b in _buttons:
		if (b as Button).has_focus():
			return true
	return false


func _skip_intro() -> void:
	for tw in _intro_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_intro_tweens.clear()
	for h in _letters:
		var c: Control = h
		c.position = c.get_meta("home")
		c.rotation = 0.0
		c.modulate.a = 1.0
	if _drop:
		_drop.position = _drop.get_meta("home")
		_drop.scale = Vector2(0.55, 0.55)
		_drop.modulate.a = 1.0
	if _wave:
		_wave.modulate.a = 1.0
	_subtitle.modulate.a = 1.0
	_subtitle.scale = Vector2.ONE
	for y in _sub_yuzus:
		(y as Sprite2D).modulate.a = 1.0
	for b in _buttons:
		(b as Button).modulate.a = 1.0
	for i in _peek.size():
		_peek[i].position.y = _peek_y(i, false)
	_intro_finished()


# ------------------------------------------------------------------ per-frame
func _process(delta: float) -> void:
	_t += delta
	# parallax from the mouse (smoothed) + slow drift
	var target := Vector2.ZERO
	var vr := get_viewport_rect()
	var m := get_local_mouse_position()
	if vr.has_point(m):
		target = (m - Vector2(640, 360)) / Vector2(640, 360)
		target = target.clamp(Vector2(-1, -1), Vector2(1, 1))
	_par = _par.lerp(target, minf(1.0, delta * 2.0))
	var drift := Vector2(sin(_t * 0.11) * 10.0, sin(_t * 0.07) * 5.0)
	if _bg:
		_bg.position = -(_bg.size - Vector2(1280, 720)) * 0.5 - _par * 14.0 + drift
	_steam_layer.position = -_par * 22.0 + drift * 1.4
	_logo.position = _par * 6.0
	for i in _peek.size():
		var s := _peek[i]
		var slot: Dictionary = PEEK_SLOTS[i]
		s.offset = Vector2(-_par.x * 18.0, -300.0 + sin(_t * 1.6 + i * 1.3) * 7.0)
		s.rotation = float(slot["rot"]) + sin(_t * 0.9 + i) * 0.03
	# logo bobbing like it floats on water
	if _intro_done:
		for h in _letters:
			var c: Control = h
			var i := int(c.get_meta("i"))
			var home: Vector2 = c.get_meta("home")
			c.position = home + Vector2(0, sin(_t * 2.2 - i * 0.55) * 5.0)
			c.rotation = sin(_t * 1.7 - i * 0.7) * 0.035
		if _drop:
			var dh: Vector2 = _drop.get_meta("home")
			_drop.position = dh + Vector2(0, sin(_t * 2.0) * 7.0)
			_drop.rotation = sin(_t * 1.3) * 0.08
		for y in _sub_yuzus:
			var ys: Sprite2D = y
			var yh: Vector2 = ys.get_meta("home")
			ys.position = yh + Vector2(0, sin(_t * 2.4 + yh.x) * 4.0)
			ys.rotation = sin(_t * 1.5 + yh.x) * 0.25
		if _wave:
			_wave.position.y = LOGO_Y + 66.0 + sin(_t * 1.8) * 3.0
	# menu indicator
	if _ind_l.modulate.a > 0.0:
		var bob := sin(_t * 5.0) * 5.0
		_ind_l.position = _ind_l.position.lerp(_ind_target - Vector2(_ind_w + bob, 0), minf(1.0, delta * 14.0))
		_ind_r.position = _ind_r.position.lerp(_ind_target + Vector2(_ind_w + bob, 0), minf(1.0, delta * 14.0))
		_ind_l.rotation = sin(_t * 3.0) * 0.3
		_ind_r.rotation = -sin(_t * 3.0) * 0.3
	# peek swaps
	if _intro_done and not _chosen:
		_peek_timer -= delta
		if _peek_timer <= 0.0:
			_peek_timer = randf_range(2.6, 4.6)
			_peek_swap(randi() % _peek.size())
	_update_fx(delta)


func _peek_swap(i: int) -> void:
	if _peek_busy[i]:
		return
	_peek_busy[i] = true
	var pool: Array[String] = []
	for id in Cast.ORDER:
		var cid: String = id
		if not _peek_ids.has(cid):
			pool.append(cid)
	var new_id: String = pool[randi() % pool.size()] if not pool.is_empty() else _peek_ids[i]
	var s := _peek[i]
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", _peek_y(i, true), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_peek_set.bind(i, new_id))
	tw.tween_interval(0.35)
	tw.tween_property(s, "position:y", _peek_y(i, false), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _peek_busy[i] = false)


func _peek_set(i: int, id: String) -> void:
	_peek_ids[i] = id
	_peek[i].texture = Assets.portrait(id, _mood)


func _new_steam(initial: bool) -> Dictionary:
	var life := randf_range(6.0, 10.0)
	return {"x": randf_range(-80, 1360), "y": randf_range(440, 560), "t": randf() * life if initial else 0.0, "life": life,
		"r": randf_range(90, 150), "ph": randf() * TAU, "sp": randf_range(18, 36)}


func _new_bubble(initial: bool) -> Dictionary:
	return {"p": Vector2(randf_range(30, 1250), randf_range(460, 740) if initial else randf_range(725, 760)),
		"v": randf_range(26, 64), "r": randf_range(3, 8.5), "ph": randf() * TAU, "pop": randf_range(450, 640)}


func _update_fx(delta: float) -> void:
	for i in _steam.size():
		var s: Dictionary = _steam[i]
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) >= float(s["life"]):
			_steam[i] = _new_steam(false)
	for i in _bubbles.size():
		var b: Dictionary = _bubbles[i]
		var p: Vector2 = b["p"]
		p.y -= float(b["v"]) * delta
		p.x += sin(_t * 3.0 + float(b["ph"])) * 12.0 * delta
		b["p"] = p
		if p.y < float(b["pop"]):
			_drops.append({"p": p, "v": Vector2.ZERO, "r": float(b["r"]), "t": 0.0, "life": 0.35, "k": 1})
			_bubbles[i] = _new_bubble(false)
	var keep: Array = []
	for d in _drops:
		var dd: Dictionary = d
		dd["t"] = float(dd["t"]) + delta
		if float(dd["t"]) >= float(dd["life"]):
			continue
		if int(dd["k"]) == 0:
			var v: Vector2 = dd["v"]
			v.y += 900.0 * delta
			dd["v"] = v
			dd["p"] = (dd["p"] as Vector2) + v * delta
		keep.append(dd)
	_drops = keep
	_steam_layer.queue_redraw()
	_front.queue_redraw()


func _draw_steam() -> void:
	for s in _steam:
		var d: Dictionary = s
		var f := float(d["t"]) / float(d["life"])
		var a := sin(f * PI) * 0.13
		var r := float(d["r"]) * (1.0 + f * 1.3)
		var pos := Vector2(float(d["x"]) + sin(_t * 0.4 + float(d["ph"])) * 50.0 * f, float(d["y"]) - float(d["sp"]) * float(d["t"]))
		_steam_layer.draw_texture_rect(_glow_tex, Rect2(pos - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, Color(0.95, 0.97, 1.0, a))
	for b in _bubbles:
		var bd: Dictionary = b
		var p: Vector2 = bd["p"]
		var r := float(bd["r"])
		_steam_layer.draw_arc(p, r, 0.0, TAU, 16, Color(0.85, 1.0, 0.98, 0.55), 1.6, true)
		_steam_layer.draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.75))
	if _spark_tex:
		for tw in _twinkles:
			var td: Dictionary = tw
			var k := maxf(0.0, sin(_t * float(td["sp"]) + float(td["ph"])))
			var r := float(td["r"]) * k
			if r > 0.5:
				var p: Vector2 = td["p"]
				_steam_layer.draw_texture_rect(_spark_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, 0.8 * k))


func _draw_front() -> void:
	for d in _drops:
		var dd: Dictionary = d
		var f := float(dd["t"]) / float(dd["life"])
		var p: Vector2 = dd["p"]
		var r := float(dd["r"])
		if int(dd["k"]) == 0:
			_front.draw_circle(p, r * (1.0 - f * 0.5), Color(0.75, 1.0, 0.97, 1.0 - f))
		else:
			_front.draw_arc(p, r + f * 10.0, 0.0, TAU, 16, Color(0.9, 1.0, 1.0, 0.7 * (1.0 - f)), 1.5, true)
