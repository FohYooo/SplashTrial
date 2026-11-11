extends Control
## Credits: a scrolling roll over a starry, steamy night sky. Title, "All the hard work done by ...", the full cast
## (portrait + name + talent), a memorial card, "Thanks for playing!", "Made with Godot Engine" with
## the engine's MIT license and required third-party notices, and a final credits card that stops
## in the middle of the screen.
## Hold click / Space / Enter to speed up, Esc to skip. Emits finished({}) at the end.

signal finished(result: Dictionary)

const Style := preload("res://scripts/ui/style.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Chapters := preload("res://scripts/data/chapters.gd")

const SPEED := 82.0
const FAST := 6.0
const START_HOLD := 2.4
const END_HOLD := 5.0

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
var _scroll_t := 0.0
var _done := false
var _ending := false
var _end_t := 0.0
var _roll: Control
var _final_y := 0.0
var _final_center := 0.0
var _sky: Control
var _fx: Control
var _fade: ColorRect
var _hint: Label
var _glow_tex: Texture2D
var _spark_tex: Texture2D
var _stars: Array = []
var _steam: Array = []
var _sparks: Array = []
var _shooting: Array = []
var _shoot_timer := 3.0
var _bob_items: Array = []
var _logo_mat: ShaderMaterial
var _from_title := false


## The finished chapter's title (from the title screen: the game's first chapter title).
func _subtitle() -> String:
	return str(Chapters.data(1 if _from_title else -1)["title"])


## Per-chapter credits options (chapters.gd "credits_*" keys); from the title screen, the first chapter's.
func _opt(key: String, fallback: Variant) -> Variant:
	return Chapters.data(1 if _from_title else -1).get(key, fallback)


## A sombre chapter's credits: no fireworks, and the Gaol's cell lights across the water instead of the hot spring.
func _quiet() -> bool:
	return bool(_opt("credits_quiet", false))


func setup(params: Dictionary) -> void:
	# Opened from the title screen the player may not have played yet: leave out the memorial card.
	_from_title = bool(params.get("from_title", false))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Audio.play_music("sad" if _quiet() else "credits")
	_glow_tex = _radial_tex()
	_spark_tex = Assets.prop("title_sparkle")
	_build_sky()
	_roll = Control.new()
	_roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll.size = Vector2(1280, 10)
	add_child(_roll)
	_build_roll()
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_hint = Style.label("Hold click / Space to speed up  ·  Esc to skip", 16, Style.TEXT_DIM)
	_hint.add_theme_color_override("font_outline_color", Style.BG_DARK)
	_hint.add_theme_constant_override("outline_size", 5)
	add_child(_hint)
	_hint.reset_size()
	_hint.position = Vector2(1262 - _hint.size.x, 692)
	_hint.modulate.a = 0.0
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	for i in 150:
		_stars.append({"p": Vector2(randf_range(0, 1280), randf_range(0, 600)), "r": randf_range(0.7, 2.2), "ph": randf() * TAU, "sp": randf_range(0.8, 3.0), "d": randf_range(0.02, 0.08)})
	for i in 12:
		_steam.append(_new_steam(true))
	create_tween().tween_property(_hint, "modulate:a", 1.0, 0.8).set_delay(1.5)
	if Game.autotest:
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_callback(_finish)


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


func _build_sky() -> void:
	var g := Gradient.new()
	g.set_color(0, Color("05031a"))
	g.set_color(1, Color("0e4a5a"))
	g.add_point(0.6, Color("1d1042"))
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
	_sky = Control.new()
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.draw.connect(_draw_sky)
	add_child(_sky)


func _lab(text: String, size: int, col: Color, display: bool = true, osize: int = 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Style.display_font() if display else Style.body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Style.BG_DARK)
	l.add_theme_constant_override("outline_size", osize)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Adds a label to the roll centered on x (shrunk to max_w); returns its height.
func _add_center(l: Label, x: float, y: float, max_w: float = 1180.0) -> float:
	_roll.add_child(l)
	l.reset_size()
	var sz := l.size
	l.pivot_offset = Vector2(sz.x * 0.5, 0)
	l.position = Vector2(x - sz.x * 0.5, y)
	if sz.x > max_w:
		var k := max_w / sz.x
		l.scale = Vector2(k, k)
		return sz.y * k
	return sz.y


func _add_left(l: Label, x: float, y: float, max_w: float) -> float:
	_roll.add_child(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.reset_size()
	var sz := l.size
	l.position = Vector2(x, y)
	if sz.x > max_w:
		var k := max_w / sz.x
		l.scale = Vector2(k, k)
		return sz.y * k
	return sz.y


func _add_sprite(tex: Texture2D, pos: Vector2, sc: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2(sc, sc)
	_roll.add_child(s)
	return s


func _add_glow(pos: Vector2, r: Vector2, col: Color) -> void:
	var tr := TextureRect.new()
	tr.texture = _glow_tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = r * 2.0
	tr.position = pos - r
	tr.modulate = col
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll.add_child(tr)


## Colored frame the portrait bust stands in (its cut-off bottom edge sits on the frame's bottom).
func _add_card(r: Rect2, col: Color) -> void:
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := Style.box(Color(col.darkened(0.62), 0.9), 22, col, 4)
	card.add_theme_stylebox_override("panel", sb)
	card.position = r.position
	card.size = r.size
	_roll.add_child(card)


func _made_by_block(y: float) -> float:
	var y0 := y
	_add_glow(Vector2(640, y + 130), Vector2(600, 180), Color(0.6, 0.35, 0.9, 0.35))
	# [caption, name, name size]: the helper gets the smaller name, on purpose
	for row in [["All the hard work done by", "Foh, Noomie and Dani", 64], ["little bit of help from", "Claude", 40]]:
		y += _add_center(_lab(row[0], 32, Style.AQUA, true, 8), 640, y) + 2
		y += _add_center(_lab(row[1], row[2], Style.GOLD, true, 16 if row[2] >= 60 else 12), 640, y, 1160) + 26
	return y - y0


## Adds a word-wrapped paragraph of fixed width w, centered on x; returns its height.
func _add_wrapped(l: Label, x: float, y: float, w: float) -> float:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	_roll.add_child(l)
	l.size = Vector2(w, 0)
	var h := l.get_combined_minimum_size().y
	l.size = Vector2(w, h)
	l.position = Vector2(x - w * 0.5, y)
	return h


## Godot's MIT license text with each paragraph's hard line breaks joined, so it wraps to the column
## (the two copyright lines stay on their own lines).
func _reflowed_license() -> String:
	var out: Array = []
	for para in Engine.get_license_text().strip_edges().split("\n\n"):
		if para.begins_with("Copyright"):
			out.append(para)
		else:
			out.append(para.replace("\n", " "))
	return "\n\n".join(out)


## FreeType's required attribution, with its year read from the engine's own copyright data.
func _freetype_notice() -> String:
	var year := "2025"
	for c in Engine.get_copyright_info():
		if str(c.get("name", "")).contains("FreeType"):
			var rx := RegEx.create_from_string("\\d{4}")
			for part in c.get("parts", []):
				for cr in part.get("copyright", []):
					for m in rx.search_all(str(cr)):
						if m.get_string() > year:
							year = m.get_string()
	return "Portions of this software are copyright © %s The FreeType Project (www.freetype.org). All rights reserved." % year


## "Made with Godot Engine" + the engine license and the third-party notices it requires.
func _engine_block(y: float) -> float:
	var y0 := y
	_add_glow(Vector2(640, y + 90), Vector2(420, 140), Color(0.3, 0.55, 0.95, 0.3))
	y += _add_center(_lab("Made with", 30, Style.AQUA, true, 8), 640, y) + 2
	y += _add_center(_lab("Godot Engine", 60, Color.WHITE, true, 14), 640, y) + 2
	y += _add_center(_lab("godotengine.org  ·  MIT License", 22, Style.TEXT_DIM, false, 6), 640, y) + 30
	y += _add_wrapped(_lab(_reflowed_license(), 16, Style.TEXT, false, 4), 640, y, 900) + 26
	var notices := "\n".join([
		_freetype_notice(),
		"Mbed TLS is Copyright The Mbed TLS Contributors, licensed under the Apache License, Version 2.0.",
		"ENet is Copyright (c) 2002-2024 Lee Salzman, licensed under the MIT License.",
		"Full third-party notices: GODOT_COPYRIGHT.txt, included with the game.",
	])
	y += _add_wrapped(_lab(notices, 16, Style.TEXT_DIM, false, 4), 640, y, 900)
	return y - y0


func _build_roll() -> void:
	var y := 0.0
	# --- title block
	var drop := Assets.prop("title_drop")
	if drop:
		var d := _add_sprite(drop, Vector2(640, y + 70), 0.5)
		_bob_items.append(d)
		y += 150
	var title := _lab("SPLASH TRIAL", 104, Color.WHITE, true, 20)
	var asc := Style.display_font().get_ascent(104)
	_logo_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = LOGO_SHADER
	_logo_mat.shader = sh
	_logo_mat.set_shader_parameter("y0", asc - 104 * 0.74)
	_logo_mat.set_shader_parameter("y1", asc + 104 * 0.02)
	title.material = _logo_mat
	var rim := _lab("SPLASH TRIAL", 104, Style.AQUA_DEEP, true, 36)
	rim.add_theme_color_override("font_outline_color", Style.AQUA)
	_add_center(rim, 640, y)
	y += _add_center(title, 640, y)
	y += _add_center(_lab(_subtitle(), 38, Style.TEXT, true, 12), 640, y - 4) + 10
	var title_h := y
	# center the title block on screen at the start
	_roll.position.y = 360.0 - title_h * 0.5
	y += 240
	# --- made by
	y += _made_by_block(y)
	y += 260
	# --- cast
	y += _add_center(_lab("STARRING", 46, Style.AQUA, true, 12), 640, y) + 4
	y += _add_center(_lab(str(_opt("credits_cast", "the guests (and host) of Yuzu Springs Resort")), 24, Style.TEXT_DIM, false, 6), 640, y) + 46
	var ids: Array = []
	for id in Cast.ROSTER:
		ids.append(id)
	ids.append("snapjaw")
	var row_h := 214.0
	for i in ids.size():
		var id: String = ids[i]
		var col := i % 2
		var row := int(i / 2.0)
		var cx := 330.0 if col == 0 else 830.0
		var cy := y + row * row_h
		var ccol := Cast.color(id)
		_add_glow(Vector2(cx - 120, cy + 110), Vector2(120, 110), Color(ccol, 0.3))
		_add_card(Rect2(cx - 120 - 86, cy + 30, 172, 162), ccol)
		_add_sprite(Assets.portrait(id, "happy"), Vector2(cx - 120, cy + 96), 0.31)
		var nm := Cast.full_name(id)
		var ny := cy + 56
		var nh := _add_left(_lab(nm, 34, ccol.lightened(0.25), true, 10), cx - 22, ny, 300)
		var tal := Cast.talent(id)
		if id == "mochi":
			tal += "  (that's you!)"
		_add_left(_lab(tal, 23, Style.TEXT, false, 6), cx - 20, ny + nh + 2, 296)
	y += ceilf(ids.size() / 2.0) * row_h + 200
	# --- in memoriam (only after actually playing the case, and only if the case has a victim)
	if not _from_title and str(Chapters.get_value("victim", "")) != "":
		_add_glow(Vector2(640, y + 150), Vector2(260, 220), Color(1.0, 0.85, 0.5, 0.35))
		var halo := Line2D.new()
		var pts := PackedVector2Array()
		for k in 41:
			var a := TAU * k / 40.0
			pts.append(Vector2(640 + cos(a) * 92.0, y + 22 + sin(a) * 20.0))
		halo.points = pts
		halo.width = 7.0
		halo.default_color = Color(1.0, 0.86, 0.4, 0.9)
		_roll.add_child(halo)
		_add_card(Rect2(640 - 140, y + 92, 280, 236), Color(1.0, 0.86, 0.45))
		var victim: String = str(Chapters.get_value("victim", "coco"))
		_add_sprite(Assets.portrait(victim, "happy"), Vector2(640, y + 170), 0.52)
		y += 346
		y += _add_center(_lab("In loving memory of", 30, Style.TEXT_DIM, true, 8), 640, y) + 2
		y += _add_center(_lab(str(Chapters.get_value("victim_name", "")), 72, Cast.color(victim).lightened(0.3), true, 16), 640, y) + 2
		y += _add_center(_lab(str(Chapters.get_value("memorial_line", "")), 24, Style.TEXT, false, 6), 640, y)
		y += 300
	# anyone else this chapter lost who wasn't the culprit
	if not _from_title:
		for m in _opt("credits_mourned", []):
			var row: Array = m
			var mid := str(row[0])
			_add_glow(Vector2(640, y + 120), Vector2(220, 180), Color(0.8, 0.85, 1.0, 0.25))
			_add_card(Rect2(640 - 120, y + 30, 240, 200), Color(0.75, 0.8, 0.9))
			_add_sprite(Assets.portrait(mid, "happy"), Vector2(640, y + 98), 0.44)
			y += 250
			y += _add_center(_lab("and of", 26, Style.TEXT_DIM, true, 8), 640, y) + 2
			y += _add_center(_lab(str(row[1]), 56, Cast.color(mid).lightened(0.3), true, 14), 640, y) + 2
			y += _add_center(_lab(str(row[2]), 24, Style.TEXT, false, 6), 640, y)
			y += 280
	# --- thanks
	var yz := Assets.prop("title_yuzu")
	var th := _lab("Thanks for playing!", 78, Style.YUZU, true, 18)
	var thh := _add_center(th, 640, y)
	if yz:
		var half := th.size.x * th.scale.x * 0.5
		for side in [-1.0, 1.0]:
			var s := _add_sprite(yz, Vector2(640 + side * (half + 60), y + thh * 0.5), 0.6)
			s.set_meta("bob", 50 + int(side))
			_bob_items.append(s)
	y += thh + 300
	# --- engine + license notices
	y += _engine_block(y)
	y += 380
	# --- final card (stops in the middle of the screen)
	var fy := y
	var fh := _made_by_block(y)
	y += fh + 18
	y += _add_center(_lab("SPLASH TRIAL: " + _subtitle(), 28, Style.TEXT_DIM, true, 8), 640, y)
	_final_center = fy + (y - fy) * 0.5
	_final_y = 360.0 - _final_center
	_roll.size.y = y + 50


func _new_steam(initial: bool) -> Dictionary:
	var life := randf_range(6.0, 10.0)
	return {"x": randf_range(-60, 1340), "y": randf_range(690, 760), "t": randf() * life if initial else 0.0, "life": life,
		"r": randf_range(90, 160), "ph": randf() * TAU, "sp": randf_range(16, 30)}


# ------------------------------------------------------------------ flow
func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if Game.autotest:
		finished.emit({})
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	tw.tween_callback(func() -> void: finished.emit({}))


func _process(delta: float) -> void:
	_t += delta
	var fast := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE) \
		or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)
	var mult := FAST if fast else 1.0
	var dy := 0.0
	if not _done:
		if not _ending:
			if _t > START_HOLD:
				dy = SPEED * mult * delta
				_roll.position.y -= dy
				if _roll.position.y <= _final_y:
					_roll.position.y = _final_y
					_ending = true
					_celebrate()
		else:
			_end_t += delta * (2.5 if fast else 1.0)
			if fmod(_t, 0.35) < delta and not _quiet():
				var p := Vector2(randf_range(250, 1030), randf_range(230, 500))
				_burst(p, 8)
			if _end_t >= END_HOLD:
				_finish()
	# parallax: stars drift with the roll
	for s in _stars:
		var d: Dictionary = s
		var p: Vector2 = d["p"]
		p.y -= dy * float(d["d"])
		if p.y < -4.0:
			p.y += 610.0
			p.x = randf_range(0, 1280)
		d["p"] = p
	for i in _steam.size():
		var st: Dictionary = _steam[i]
		st["t"] = float(st["t"]) + delta * (1.0 + (mult - 1.0) * 0.3)
		if float(st["t"]) >= float(st["life"]):
			_steam[i] = _new_steam(false)
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = randf_range(3.5, 7.0)
		_shooting.append({"p": Vector2(randf_range(200, 1200), randf_range(40, 260)), "v": Vector2(-randf_range(500, 700), randf_range(160, 260)), "t": 0.0, "life": 0.9})
	var keep: Array = []
	for sh in _shooting:
		var d: Dictionary = sh
		d["t"] = float(d["t"]) + delta
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
		if float(d["t"]) < float(d["life"]):
			keep.append(d)
	_shooting = keep
	var keep2: Array = []
	for sp in _sparks:
		var d: Dictionary = sp
		d["t"] = float(d["t"]) + delta
		var v: Vector2 = d["v"]
		v *= maxf(0.0, 1.0 - 1.8 * delta)
		v.y += 60.0 * delta
		d["v"] = v
		d["p"] = (d["p"] as Vector2) + v * delta
		if float(d["t"]) < float(d["life"]):
			keep2.append(d)
	_sparks = keep2
	for it in _bob_items:
		var n := it as Sprite2D
		if n == null:
			continue
		var i := int(n.get_meta("bob", 0))
		n.offset = Vector2(0, sin(_t * 1.8 + i * 0.9) * 8.0 / maxf(n.scale.y, 0.1) * 0.5)
	_sky.queue_redraw()
	_fx.queue_redraw()


func _celebrate() -> void:
	if _quiet():
		_light_out_t = _t
		return
	Audio.sfx("chime")
	for i in 3:
		_burst(Vector2(randf_range(320, 960), randf_range(250, 470)), 24)


func _burst(p: Vector2, n: int) -> void:
	var cols := [Style.GOLD, Style.AQUA, Color(0.85, 0.75, 1.0), Color.WHITE]
	for i in n:
		_sparks.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(60, 260), "t": 0.0, "life": randf_range(0.7, 1.4),
			"r": randf_range(6, 13), "c": cols[i % cols.size()]})


# ------------------------------------------------------------------ drawing
func _draw_sky() -> void:
	for s in _stars:
		var d: Dictionary = s
		var tw := 0.55 + 0.45 * sin(_t * float(d["sp"]) + float(d["ph"]))
		_sky.draw_circle(d["p"], float(d["r"]) * (0.7 + 0.3 * tw), Color(1, 0.97, 1, 0.35 + 0.6 * tw))
	for sh in _shooting:
		var d: Dictionary = sh
		var f := float(d["t"]) / float(d["life"])
		var p: Vector2 = d["p"]
		var v: Vector2 = d["v"]
		var a := sin(f * PI)
		_sky.draw_line(p, p - v.normalized() * 120.0, Color(1, 1, 1, 0.0), 2.0, true)
		_sky.draw_line(p, p - v.normalized() * 90.0 * a, Color(0.9, 0.85, 1.0, 0.8 * a), 2.5, true)
		_sky.draw_circle(p, 2.5, Color(1, 1, 1, a))
	if _quiet():
		_draw_gaol()
		return
	# hot-spring glow + rocks at the bottom
	_sky.draw_texture_rect(_glow_tex, Rect2(Vector2(140, 560), Vector2(1000, 320)), false, Color(0.25, 0.9, 0.85, 0.35))
	for st in _steam:
		var d: Dictionary = st
		var f := float(d["t"]) / float(d["life"])
		var a := sin(f * PI) * 0.12
		var r := float(d["r"]) * (1.0 + f * 1.2)
		var pos := Vector2(float(d["x"]) + sin(_t * 0.35 + float(d["ph"])) * 60.0 * f, float(d["y"]) - float(d["sp"]) * float(d["t"]))
		_sky.draw_texture_rect(_glow_tex, Rect2(pos - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, Color(0.95, 0.97, 1.0, a))
	var rocks := PackedVector2Array([Vector2(0, 720), Vector2(0, 668), Vector2(90, 650), Vector2(190, 676), Vector2(300, 660),
		Vector2(420, 690), Vector2(560, 682), Vector2(700, 694), Vector2(840, 678), Vector2(980, 664), Vector2(1090, 680),
		Vector2(1190, 652), Vector2(1280, 664), Vector2(1280, 720)])
	_sky.draw_colored_polygon(rocks, Color("0b0618"))


## The sea and the Gaol along the bottom: rows of small cell lights. When the roll stops, one of them goes out.
var _light_out_t := -1.0


func _draw_gaol() -> void:
	_sky.draw_rect(Rect2(0, 640, 1280, 80), Color("050a12"))
	_sky.draw_colored_polygon(PackedVector2Array([Vector2(300, 642), Vector2(380, 616), Vector2(520, 604), Vector2(760, 600), Vector2(900, 612),
		Vector2(980, 642)]), Color("03060a"))
	_sky.draw_rect(Rect2(450, 560, 380, 50), Color("04070c"))
	_sky.draw_rect(Rect2(420, 580, 50, 30), Color("04070c"))
	var r := RandomNumberGenerator.new()
	r.seed = 2626
	var idx := 0
	for row in 3:
		for col in 18:
			var lit := r.randf() < 0.8
			if not lit:
				continue
			idx += 1
			if idx == 23 and _light_out_t >= 0.0 and _t - _light_out_t > 1.6:
				continue
			var p := Vector2(464 + col * 20.0, 568 + row * 13.0)
			_sky.draw_texture_rect(_glow_tex, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false, Color(1.0, 0.85, 0.5, 0.5))
			_sky.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 7)), Color(1.0, 0.86, 0.52))
	for k in 10:
		var x := 460.0 + k * 36.0
		_sky.draw_line(Vector2(x, 652 + (k % 3) * 9), Vector2(x + 14, 652 + (k % 3) * 9), Color(1.0, 0.85, 0.5, 0.18), 2.0)


func _draw_fx() -> void:
	for sp in _sparks:
		var d: Dictionary = sp
		var f := float(d["t"]) / float(d["life"])
		var r := float(d["r"]) * (1.0 - f * 0.6)
		var col: Color = d["c"]
		var p: Vector2 = d["p"]
		if _spark_tex:
			_fx.draw_texture_rect(_spark_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col, 1.0 - f))
		else:
			_fx.draw_circle(p, r * 0.4, Color(col, 1.0 - f))
