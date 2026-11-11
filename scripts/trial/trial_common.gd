extends Control
## Shared base for the trial-a minigames: Splash Debate (debate.gd) and Rebuttal Showdown (rebuttal.gd).
## Both do `extends "res://scripts/trial/trial_common.gd"` and implement the virtual hooks
## _tick(delta), _on_left_click(pos), _on_action(), _is_hot(pos) (+ optional _on_crack()).
##
## Layers (bottom -> top): backdrop (semi-transparent night + vignette + parallax particles + focus lines),
##   shaker [stage, hud, ui, top, fx], glitch (screen-texture shader, only visible while glitching), flash.
##   _stage : portraits, statement text, timing ring        (zoom-punch target)
##   _hud   : badges, loop timer, hint bubble
##   _ui    : Truth Drop ammo tray + tooltip
##   _top   : banners, speech boxes, pop texts, screen shatter
##   _fx    : particles, water-shot projectiles, crosshair
## Visual language: slanted/chamfered panels (Slant) with hard offset shadows and diagonal stripes,
## snappy expo/back motion, speed lines, freeze-frames, glitch on mistakes, screen shatter on breaks.
## Waits are driven by this node's own _process (pause-safe, and they simply stop if the node is freed).

signal finished(result: Dictionary)
signal _frame

const Style := preload("res://scripts/ui/style.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Clues := preload("res://scripts/data/clues.gd")
const Skills := preload("res://scripts/data/skills.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Chapters := preload("res://scripts/data/chapters.gd")
const EvidenceViewer := preload("res://scripts/ui/evidence_viewer.gd")

const W := 1280.0
const H := 720.0
const PANEL_Y := 598.0
const CHIP_H := 76.0
const WATER := [Color("3ee0d0"), Color("bff8ff"), Color("ffffff"), Color("6fd6ff")]
const BREAK_TEXT := "THAT DOESN'T FLOAT!"
const NIGHT := Color("120a24")
const INK := Color("07040f")          # near-black for hard drop shadows
const PANEL_BG := Color(0.06, 0.035, 0.13, 0.95)

const GLITCH_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float amount = 0.0;
uniform float seed = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.31, 0.43, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 30.0) + seed;
	float band = floor(uv.y * 22.0);
	float r = hash(vec2(band, t));
	float blk = step(1.0 - amount * 0.45, r);
	uv.x += (hash(vec2(band, t + 3.7)) - 0.5) * 0.10 * amount * blk;
	float row = floor(uv.y * 260.0);
	uv.x += (hash(vec2(row, t)) - 0.5) * 0.005 * amount;
	float split = 0.010 * amount + 0.012 * amount * blk;
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(split, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(split, 0.0)).b;
	float n = hash(floor(uv * vec2(320.0, 180.0)) + t);
	c = mix(c, vec3(n), 0.10 * amount);
	c *= 1.0 - 0.16 * amount * step(0.5, fract(uv.y * 180.0));
	c = mix(c, c * 0.5 + tint.rgb * 0.5, 0.45 * amount * blk);
	COLOR = vec4(c, 1.0);
}
"""

var _glitch_shader: Shader = null
var _soft_tex: Texture2D = null

var data: Dictionary = {}

var _backdrop: Backdrop
var _shaker: Control
var _stage: Control
var _hud: Control
var _ui: Control
var _top: Control
var _fx: Fx
var _glitch_rect: ColorRect
var _glitch_mat: ShaderMaterial
var _flash_rect: ColorRect
var _flash_tw: Tween

var _clock := 0.0
var _done := false
var _click_flag := false
var _aim_enabled := false
var _cursor_hidden := false
var _shake_amt := 0.0
var _shake_t := 0.0
var _shake_dur := 0.3
var _freeze_t := 0.0
var _glitch_t := 0.0
var _glitch_dur := 0.3
var _glitch_amt := 1.0
var _cam := Vector2.ZERO

# Truth Drop ammo tray
var _drop_ids: Array = []
var _chips: Array = []
var _sel := 0
var _hover := -1
var _panel: Control
var _panel_rect := Rect2()
var _panel_shown := false
var _tip: Slant
var _tip_title: Label
var _tip_label: Label
var _italic: SystemFont
var _ui_rects: Array = []      # other clickable areas the crosshair should give way to


func setup(d: Dictionary) -> void:
	data = d


# =================================================================== virtual hooks
func _tick(_delta: float) -> void:
	pass


func _on_left_click(_pos: Vector2) -> void:
	pass


func _on_action() -> void:
	pass


func _is_hot(_pos: Vector2) -> bool:
	return false


## Whether the crosshair may show right now (subclasses gate it by their state).
func _aim_allowed() -> bool:
	return true


## Called by _break_hit when the weak spot cracks (swap faces to "shock" here).
func _on_crack() -> void:
	pass


# =================================================================== construction
func _build_common(tint: Color) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = Backdrop.new()
	_backdrop.tint = tint
	_backdrop.soft = _soft()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_shaker = _full(self)
	_stage = _full(_shaker)
	_hud = _full(_shaker)
	_ui = _full(_shaker)
	_top = _full(_shaker)
	_fx = Fx.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.aim_font = Style.body_font()
	_shaker.add_child(_fx)
	if _glitch_shader == null:
		_glitch_shader = Shader.new()
		_glitch_shader.code = GLITCH_CODE
	_glitch_mat = ShaderMaterial.new()
	_glitch_mat.shader = _glitch_shader
	_glitch_rect = ColorRect.new()
	_glitch_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_rect.material = _glitch_mat
	_glitch_rect.visible = false
	add_child(_glitch_rect)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color.WHITE
	_flash_rect.modulate.a = 0.0
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)
	_italic = SystemFont.new()
	_italic.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Verdana", "Arial", "Noto Sans"])
	_italic.font_italic = true
	_italic.font_weight = 600
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, _fxd(0.25))


func _full(parent: Control) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _new_statement() -> StatementView:
	return StatementView.new()


## Angular panel factory (see class Slant).
func _slant(sz: Vector2, fill: Color, border: Color, bw: float = 3.0, skew: float = 16.0, cut: float = 12.0,
		stripes: int = 0, shadow: Color = Color(INK, 0.92), shadow_off: Vector2 = Vector2(7, 7)) -> Slant:
	var s := Slant.new()
	s.fill = fill
	s.border = border
	s.border_w = bw
	s.skew_px = skew
	s.cut = cut
	s.stripes = stripes
	s.stripe_col = Color(border, 0.16)
	s.shadow = shadow
	s.shadow_off = shadow_off
	s.size = sz
	s.refresh()
	return s


## Gives a Label a chunky hard offset drop shadow (same thickness as its outline).
func _hard_shadow(l: Label, off: Vector2 = Vector2(5, 6), col: Color = INK) -> Label:
	l.add_theme_color_override("font_shadow_color", col)
	l.add_theme_constant_override("shadow_offset_x", int(off.x))
	l.add_theme_constant_override("shadow_offset_y", int(off.y))
	l.add_theme_constant_override("shadow_outline_size", maxi(1, l.get_theme_constant("outline_size")))
	return l


func _soft() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		_soft_tex = gt
	return _soft_tex


# =================================================================== loop / timing
func _process(delta: float) -> void:
	_clock += delta
	if _freeze_t > 0.0:
		_freeze_t -= delta
		if _freeze_t <= 0.0:
			_set_frozen(false)
		else:
			_frame.emit()
			return
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - delta, 0.0)
		var k := _shake_t / maxf(_shake_dur, 0.001)
		_shaker.position = Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * _shake_amt * k
		if _shake_t <= 0.0:
			_shaker.position = Vector2.ZERO
	if _glitch_t > 0.0:
		_glitch_t = maxf(_glitch_t - delta, 0.0)
		var gk := _glitch_t / maxf(_glitch_dur, 0.001)
		_glitch_mat.set_shader_parameter("amount", _glitch_amt * gk * randf_range(0.55, 1.0))
		if _glitch_t <= 0.0:
			_glitch_rect.visible = false
	_update_aim()
	_update_parallax(delta)
	_tick(delta)
	_frame.emit()


## True once the minigame finished or left the tree (stop any running sequence).
func _gone() -> bool:
	return _done or not is_inside_tree()


## Effect duration: real in play, tiny under --autotest.
func _fxd(t: float) -> float:
	return t * 0.08 if Game.autotest else t


## Pause-safe wait (seconds of this node's process time).
func _wait(t: float) -> void:
	var end := _clock + t
	while _clock < end and not _gone():
		await _frame


## Waits for a click / Space (after min_t) or until max_t passes.
func _wait_click(min_t: float, max_t: float) -> void:
	var start := _clock
	_click_flag = false
	while not _gone():
		await _frame
		var el := _clock - start
		if el >= max_t:
			break
		if el >= min_t and _click_flag:
			break
	_click_flag = false


func _finish(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	_aim_enabled = false
	_fx.aim_on = false
	_set_cursor_hidden(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, _fxd(0.3))
	await tw.finished
	finished.emit(result)


# =================================================================== input
func _gui_input(e: InputEvent) -> void:
	if _done:
		return
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var gp: Vector2 = get_global_transform() * mb.position
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			_click_flag = true
			_on_left_click(gp)
			accept_event()
		MOUSE_BUTTON_RIGHT:
			if _panel_shown:
				_cycle_drop(1)
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			if _panel_shown:
				_cycle_drop(-1)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			if _panel_shown:
				_cycle_drop(1)
			accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var code := int(k.keycode)
	var num := -1
	if code >= KEY_1 and code <= KEY_9:
		num = code - KEY_1
	elif code >= KEY_KP_1 and code <= KEY_KP_9:
		num = code - KEY_KP_1
	if num >= 0:
		if _panel_shown and num < _drop_ids.size():
			_select_drop(num)
			get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_V:
			if _panel_shown:
				_view_selected()
				get_viewport().set_input_as_handled()
		KEY_Q, KEY_LEFT:
			if _panel_shown:
				_cycle_drop(-1)
				get_viewport().set_input_as_handled()
		KEY_E, KEY_RIGHT, KEY_TAB:
			if _panel_shown:
				_cycle_drop(1)
				get_viewport().set_input_as_handled()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z:
			_click_flag = true
			_on_action()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_set_cursor_hidden(false)


func _set_cursor_hidden(on: bool) -> void:
	if on == _cursor_hidden:
		return
	_cursor_hidden = on
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if on else Input.MOUSE_MODE_VISIBLE


func _update_aim() -> void:
	if _fx == null:
		return
	if Game.autotest:
		_set_cursor_hidden(false)
		return
	var m := get_global_mouse_position()
	var over_ui := _panel_shown and _panel_rect.has_point(m)
	for r in _ui_rects:
		over_ui = over_ui or (r as Rect2).has_point(m)
	var on := _aim_enabled and _aim_allowed() and not over_ui and Rect2(0, 0, W, H).has_point(m)
	_fx.aim_on = on
	_fx.aim = _to_fx(m)
	_fx.aim_hot = on and _is_hot(m)
	_set_cursor_hidden(on)


## Backdrop particles drift against the mouse a little (depth parallax).
func _update_parallax(delta: float) -> void:
	var target := Vector2(sin(_clock * 0.35) * 18.0, cos(_clock * 0.27) * 10.0)
	if not Game.autotest:
		var m := get_global_mouse_position()
		if Rect2(0, 0, W, H).has_point(m):
			target = (Vector2(W * 0.5, H * 0.5) - m) * 0.045
	_cam = _cam.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	_backdrop.cam = _cam


func _to_fx(gp: Vector2) -> Vector2:
	return _fx.get_global_transform().affine_inverse() * gp


# =================================================================== screen feedback
func _flash(col: Color, alpha: float = 0.7, dur: float = 0.35) -> void:
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	_flash_rect.color = col
	_flash_rect.modulate.a = alpha
	_flash_tw = create_tween()
	_flash_tw.tween_property(_flash_rect, "modulate:a", 0.0, _fxd(dur)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _shake(strength: float = 12.0, dur: float = 0.3) -> void:
	if _shake_t <= 0.0 or strength > _shake_amt:
		_shake_amt = strength
	_shake_t = dur
	_shake_dur = dur


## RGB-split / block-offset / scanline glitch over everything drawn below it.
func _glitch(dur: float = 0.3, amt: float = 1.0, tint: Color = Style.DANGER) -> void:
	if dur <= 0.0:
		return
	_glitch_t = dur
	_glitch_dur = dur
	_glitch_amt = amt
	_glitch_mat.set_shader_parameter("seed", randf() * 100.0)
	_glitch_mat.set_shader_parameter("tint", tint)
	_glitch_mat.set_shader_parameter("amount", amt)
	_glitch_rect.visible = true


## Freeze-frame: stage/fx/backdrop stop moving for t seconds (waits keep running).
func _freeze(t: float) -> void:
	if t <= 0.0:
		return
	_freeze_t = t
	_set_frozen(true)


func _set_frozen(on: bool) -> void:
	var pm := Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	_shaker.process_mode = pm
	_backdrop.process_mode = pm
	if not on:
		_freeze_t = 0.0


## Quick zoom punch of the stage around a point.
func _punch(at: Vector2, amt: float = 0.06, dur: float = 0.4) -> void:
	_stage.pivot_offset = at
	_stage.scale = Vector2.ONE * (1.0 + amt)
	var tw := create_tween()
	tw.tween_property(_stage, "scale", Vector2.ONE, _fxd(dur)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _shake_node(n: Control, amt: float = 10.0) -> void:
	if n == null or not is_instance_valid(n):
		return
	var base := n.position
	var tw := n.create_tween()
	for i in 5:
		tw.tween_property(n, "position", base + Vector2(randf_range(-amt, amt), randf_range(-amt, amt) * 0.4), 0.03)
	tw.tween_property(n, "position", base, 0.04)


## Diagonal speed lines burst (manga focus lines) toward a point.
func _focus(c: Vector2, k: float = 1.0, decay: float = 2.4) -> void:
	_backdrop.focus.c = c
	_backdrop.focus.k = maxf(_backdrop.focus.k, k)
	_backdrop.focus.decay = decay


## Burst a statement's weak spot into droplets and yuzu shards, then hide it.
func _shatter(view: StatementView, wk: int) -> void:
	if view == null or not is_instance_valid(view):
		return
	var pts: Array = view.weak_points(wk, 44)
	for gp in pts:
		_fx.burst(_to_fx(gp), 1, WATER, 560.0, 1100.0, 7.0, 0)
	for k in mini(18, pts.size()):
		_fx.burst(_to_fx(pts[k]), 1, [Style.YUZU, Style.GOLD, Color("fff1c0")], 640.0, 1300.0, 10.0, 2)
	var c := _to_fx(view.weak_center(wk))
	_fx.ring(c, 10.0, 190.0, 0.55, Color(1, 1, 1, 0.9), 7.0)
	_fx.ring(c, 10.0, 120.0, 0.4, Color(Style.YUZU, 0.9), 5.0)
	view.hidden_weak = wk


## The big break moment: splash -> 0.15 s freeze-frame -> the weak phrase cracks -> the whole screen is
## captured and SHATTERS into flying glass shards over an aqua/yuzu flash. Returns once the shards fly.
func _break_hit(view: StatementView, wk: int, gp: Vector2) -> void:
	var c := _to_fx(gp)
	_fx.burst(c, 26, [Color.WHITE, Style.AQUA, Color("bff8ff")], 520.0, 900.0, 7.0, 0)
	_fx.ring(c, 8.0, 130.0, 0.4, Color.WHITE, 7.0)
	_flash(Color.WHITE, 0.5, 0.14)
	Audio.sfx("splash")
	_shake_t = 0.0
	_shaker.position = Vector2.ZERO
	await _frame
	if _gone():
		return
	_freeze(_fxd(0.15))
	await _wait(_fxd(0.15))
	if _gone():
		return
	_set_frozen(false)
	var valid := view != null and is_instance_valid(view)
	if valid:
		view.crack(wk)
		var tw := create_tween()
		tw.tween_property(view, "crack_k", 1.0, _fxd(0.12)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_on_crack()
	Audio.sfx("break", 1.45, -7.0)
	await _wait(_fxd(0.16))
	if _gone():
		return
	_shaker.position = Vector2.ZERO
	await _frame
	if _gone():
		return
	_screen_shatter(gp)
	if valid and is_instance_valid(view):
		_shatter(view, wk)
		view.visible = false
	_hide_drop_panel(true)
	_flash(Color("bff8ff"), 0.42, 0.3)
	_focus(_to_local(gp), 1.0, 1.4)


func _to_local(gp: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * gp


## Captures the last rendered frame and replaces it with flying glass shards (no-op without a renderer).
func _screen_shatter(gp: Vector2) -> void:
	var tex: Texture2D = null
	var img_size := Vector2.ZERO
	if DisplayServer.get_name() != "headless":
		var vt := get_viewport().get_texture()
		if vt != null:
			var img := vt.get_image()
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
				img_size = Vector2(img.get_size())
	var sh := Shatter.new()
	sh.size = Vector2(W, H)
	_top.add_child(sh)
	var to_px := get_viewport().get_final_transform() * sh.get_global_transform_with_canvas()
	sh.build(tex, sh.get_global_transform().affine_inverse() * gp, to_px, img_size, _fxd(0.85))


# =================================================================== text widgets
func _make_name_tag(id: String, font_size: int = 26) -> Slant:
	var col := Cast.color(id)
	var font := Style.display_font()
	var tw := font.get_string_size(Cast.display_name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var tag := _slant(Vector2(tw + 44.0, font_size + 14.0), col, Color.WHITE, 3.0, 12.0, 8.0, 0, Color(INK, 0.95), Vector2(6, 6))
	var l := Label.new()
	l.text = Cast.display_name(id)
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Style.BG_DARK if col.get_luminance() > 0.45 else Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = tag.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(l)
	tag.pivot_offset = tag.size * 0.5
	return tag


func _make_portrait(id: String, expr: String, sc: float) -> CutPortrait:
	var r := CutPortrait.new()
	r.texture = Assets.portrait(id, expr)
	r.size = Assets.PORTRAIT_SIZE * sc
	r.pivot_offset = Vector2(r.size.x * 0.5, r.size.y)
	return r


## Soft radial glow in a character's color (drawn behind portraits).
func _make_glow(col: Color, sz: float, alpha: float = 0.5) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _soft()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = Vector2(sz, sz)
	r.self_modulate = Color(col, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Horizontal speed lines that rush across `rect` and fade out after `life` seconds.
func _speed_lines(parent: Control, rect: Rect2, col: Color, dir: float = 1.0, life: float = 0.45, n: int = 12) -> Streaks:
	var s := Streaks.new()
	s.position = rect.position
	s.size = rect.size
	s.col = col
	s.dir = dir
	s.n = n
	parent.add_child(s)
	if life > 0.0:
		var tw := s.create_tween()
		tw.tween_property(s, "modulate:a", 0.0, _fxd(life)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(s.queue_free)
	return s


## A tapered blade streak that slices along a->b and fades.
func _blade(parent: Control, a: Vector2, b: Vector2, col: Color, thick: float = 14.0, dur: float = 0.1) -> void:
	var bl := Blade.new()
	bl.a = a
	bl.b = b
	bl.col = col
	bl.thick = thick
	bl.size = Vector2(W, H)
	parent.add_child(bl)
	var tw := bl.create_tween()
	tw.tween_property(bl, "k", 1.0, _fxd(dur)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(bl, "fade", 0.0, _fxd(0.28)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(bl.queue_free)


func _text_height(text: String, font: Font, fsize: int, width: float) -> float:
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, fsize).y


## Title plate for the HUD corner (slanted, striped, hard shadow). Keeps clear of the meter strip (x < 384).
func _hud_badge(title: String, accent: Color, fs: int = 30) -> Slant:
	var font := Style.display_font()
	while fs > 16 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 300.0:
		fs -= 2
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var plate := _slant(Vector2(tw + 64.0, fs + 16.0), PANEL_BG, accent, 3.0, 14.0, 9.0, 3, Color(INK, 0.95), Vector2(6, 6))
	plate.stripe_col = Color(accent, 0.3)
	plate.refresh()
	var l := _hard_shadow(Style.title_label(title, fs, Style.GOLD, Style.BG_DARK, 8), Vector2(3, 4), Color(accent.darkened(0.45), 1.0))
	l.position = Vector2(18, 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(l)
	return plate


## Small skill badges (only the skills the player owns).
func _skill_tags(ids: Array, pos: Vector2) -> void:
	var x := pos.x
	var y := pos.y
	var font := Style.display_font()
	for sid in ids:
		if not Game.has_skill(sid):
			continue
		var txt := Skills.skill_name(sid).to_upper()
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tag := _slant(Vector2(tw + 22.0, 19.0), Color(0.06, 0.24, 0.28, 0.95), Style.AQUA, 1.5, 6.0, 4.0, 0, Color(INK, 0.9), Vector2(3, 3))
		var l := Style.label(txt, 12, Style.AQUA, true)
		l.position = Vector2(11, 1)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(l)
		_hud.add_child(tag)
		if x + tag.size.x > 384.0 and x > pos.x:
			x = pos.x
			y += 23.0
		tag.position = Vector2(x, y)
		x += tag.size.x + 6.0


## Big outlined label that slams in, holds, then floats away.
func _pop_text(text: String, gp: Vector2, fsize: int, col: Color, rot_deg: float = -6.0, hold: float = 0.55) -> void:
	var l := Style.title_label(text, fsize, col, Style.BG_DARK, maxi(8, int(fsize / 5.0)))
	_hard_shadow(l, Vector2(maxi(4, int(fsize / 11.0)), maxi(5, int(fsize / 9.0))), INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(l)
	l.size = l.get_minimum_size()
	l.position = gp - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.rotation = deg_to_rad(rot_deg)
	l.scale = Vector2(2.2, 2.2)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, _fxd(0.16)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, _fxd(0.06))
	tw.chain().tween_interval(_fxd(hold))
	tw.chain().tween_property(l, "position:y", l.position.y - 46.0, _fxd(0.3)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "modulate:a", 0.0, _fxd(0.3))
	tw.chain().tween_callback(l.queue_free)


# =================================================================== banners
## Diagonal split-screen title: a dark band slashes in from the left with the title, an accent band from
## the right with the subtitle; speed lines rush through both. Holds (click skips), then they slash apart.
func _banner_sweep(title: String, sub: String, accent: Color) -> void:
	var root := _full(_top)
	var dimr := ColorRect.new()
	dimr.color = Color(INK, 0.5)
	dimr.size = Vector2(W, H)
	dimr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dimr.modulate.a = 0.0
	root.add_child(dimr)
	var rig := Control.new()
	rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rig.size = Vector2(W, H)
	rig.pivot_offset = Vector2(W * 0.5, H * 0.5)
	rig.rotation = deg_to_rad(-7.0)
	root.add_child(rig)
	var bw := 1900.0
	var x0 := -310.0
	# thin accent slivers above/below (split-screen edges)
	var sl_top := _slant(Vector2(bw, 10), Style.YUZU, Color(0, 0, 0, 0), 0.0, 6.0, 0.0, 0, Color(0, 0, 0, 0))
	sl_top.position = Vector2(x0 + bw, 196)
	rig.add_child(sl_top)
	var sl_bot := _slant(Vector2(bw, 10), accent, Color(0, 0, 0, 0), 0.0, 6.0, 0.0, 0, Color(0, 0, 0, 0))
	sl_bot.position = Vector2(x0 - bw, 470)
	rig.add_child(sl_bot)
	# band A: dark, title
	var band_a := _slant(Vector2(bw, 168), Color(0.04, 0.02, 0.10, 0.97), accent, 5.0, 46.0, 0.0, 0, Color(accent.darkened(0.3), 0.85), Vector2(0, 12))
	band_a.position = Vector2(x0 - bw, 214)
	rig.add_child(band_a)
	_speed_lines(band_a, Rect2(Vector2(0, 14), Vector2(bw, 140)), Color(accent, 0.16), 1.0, 0.0, 16)
	var font := Style.display_font()
	var fs := 88
	while fs > 44 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 1060.0:
		fs -= 4
	var tl := _hard_shadow(Style.title_label(title, fs, Style.GOLD, Style.BG_DARK, 16), Vector2(8, 8), Color(accent.darkened(0.25), 1.0))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.size = Vector2(W, 150)
	tl.position = Vector2(-x0, 8)
	tl.pivot_offset = tl.size * 0.5
	tl.scale = Vector2(1.6, 1.6)
	tl.modulate.a = 0.0
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_a.add_child(tl)
	# band B: solid accent, subtitle in dark ink
	var band_b := _slant(Vector2(bw, 64), accent, Color.WHITE, 3.0, 24.0, 0.0, 0, Color(INK, 0.9), Vector2(0, 8))
	band_b.position = Vector2(x0 + bw, 396)
	rig.add_child(band_b)
	_speed_lines(band_b, Rect2(Vector2(0, 6), Vector2(bw, 52)), Color(1, 1, 1, 0.22), -1.0, 0.0, 10)
	if sub != "":
		var fs2 := 27
		while fs2 > 16 and font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x > 1100.0:
			fs2 -= 1
		var sl := Style.label(sub, fs2, Style.BG_DARK, true)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sl.size = Vector2(W, 64)
		sl.position = Vector2(-x0, 0)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band_b.add_child(sl)
	Audio.sfx("whoosh")
	var d_in := _fxd(0.26)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dimr, "modulate:a", 1.0, _fxd(0.15))
	tw.tween_property(band_a, "position:x", x0, d_in).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(band_b, "position:x", x0, d_in).set_delay(_fxd(0.05)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(sl_top, "position:x", x0, d_in).set_delay(_fxd(0.08)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(sl_bot, "position:x", x0, d_in).set_delay(_fxd(0.08)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl, "scale", Vector2.ONE, _fxd(0.3)).set_delay(_fxd(0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl, "modulate:a", 1.0, _fxd(0.08)).set_delay(_fxd(0.12))
	await _wait(_fxd(0.2))
	if _gone():
		return
	_shake(7.0, 0.22)
	_focus(Vector2(W * 0.5, H * 0.5), 0.9, 1.6)
	_blade(root, Vector2(-40, 404), Vector2(W + 40, 248), Color(Style.GOLD, 0.9), 10.0, 0.12)
	_fx.burst(Vector2(140, 330), 14, WATER, 420.0, 700.0, 6.0, 0)
	_fx.burst(Vector2(1140, 300), 14, WATER, 420.0, 700.0, 6.0, 0)
	await _wait_click(_fxd(0.6), _fxd(1.5))
	if _gone():
		return
	Audio.sfx("whoosh", 1.25, -6.0)
	var d_out := _fxd(0.2)
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(band_a, "position:x", x0 + bw + 200.0, d_out).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw2.tween_property(sl_top, "position:x", x0 + bw + 200.0, d_out).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw2.tween_property(band_b, "position:x", x0 - bw - 200.0, d_out).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw2.tween_property(sl_bot, "position:x", x0 - bw - 200.0, d_out).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw2.tween_property(dimr, "modulate:a", 0.0, d_out)
	await tw2.finished
	root.queue_free()


## Compact slanted band for "TIME'S UP!"-style messages (red ones glitch in).
func _toast(title: String, sub: String, col: Color, hold: float = 1.0) -> void:
	var root := _full(_top)
	var rig := Control.new()
	rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rig.size = Vector2(W, H)
	rig.pivot_offset = Vector2(W * 0.5, H * 0.5)
	rig.rotation = deg_to_rad(-4.0)
	root.add_child(rig)
	var bw := 1700.0
	var x0 := -210.0
	var band := _slant(Vector2(bw, 140), Color(0.05, 0.03, 0.11, 0.96), col, 5.0, 34.0, 0.0, 0, Color(col.darkened(0.35), 0.9), Vector2(0, 10))
	band.position = Vector2(x0 + bw, 290)
	rig.add_child(band)
	_speed_lines(band, Rect2(Vector2(0, 10), Vector2(bw, 120)), Color(col, 0.14), -1.0, 0.0, 12)
	for i in 4:
		var st := _slant(Vector2(16, 140), Color(col, 0.75), Color(0, 0, 0, 0), 0.0, 40.0, 0.0, 0, Color(0, 0, 0, 0))
		st.position = Vector2(-x0 + 90.0 + i * 26.0, 0)
		band.add_child(st)
		var st2 := _slant(Vector2(16, 140), Color(col, 0.75), Color(0, 0, 0, 0), 0.0, 40.0, 0.0, 0, Color(0, 0, 0, 0))
		st2.position = Vector2(-x0 + W - 180.0 + i * 26.0, 0)
		band.add_child(st2)
	var tl := _hard_shadow(Style.title_label(title, 56, col, Style.BG_DARK, 12), Vector2(6, 6), INK)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.size = Vector2(W, 72)
	tl.position = Vector2(-x0, 8)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(tl)
	if sub != "":
		var sl := _hard_shadow(Style.title_label(sub, 22, Style.TEXT, Style.BG_DARK, 5), Vector2(3, 3), INK)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.size = Vector2(W, 34)
		sl.position = Vector2(-x0, 88)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(sl)
	Audio.sfx("whoosh", 1.2, -6.0)
	var tw := create_tween()
	tw.tween_property(band, "position:x", x0, _fxd(0.2)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if col == Style.DANGER:
		_glitch(_fxd(0.28), 0.8)
	await _wait(_fxd(0.2))
	if _gone():
		return
	_shake(5.0, 0.18)
	await _wait(hold)
	if _gone():
		return
	var tw2 := create_tween()
	tw2.tween_property(band, "position:x", x0 - bw - 100.0, _fxd(0.18)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw2.finished
	root.queue_free()


## The big "THAT DOESN'T FLOAT!" break cut-in: a slanted band slams across with speed lines while
## Mochi slashes in through a skewed window. Click skips the hold.
func _break_banner(text: String = BREAK_TEXT, shouter: String = "mochi") -> void:
	var root := _full(_top)
	var dimr := ColorRect.new()
	dimr.color = Color(INK, 0.42)
	dimr.size = Vector2(W, H)
	dimr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dimr)
	var foc := Focus.new()
	foc.size = Vector2(W, H)
	foc.c = Vector2(800, 350)
	foc.col = Color(1, 1, 1, 0.3)
	foc.r_in = 360.0
	foc.k = 1.0
	root.add_child(foc)
	var rig := Control.new()
	rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rig.size = Vector2(W, H)
	rig.pivot_offset = Vector2(W * 0.5, H * 0.5)
	rig.rotation = deg_to_rad(-8.0)
	root.add_child(rig)
	var bw := 2100.0
	var band := _slant(Vector2(bw, 214), Color(0.05, 0.02, 0.11, 0.97), Style.GOLD, 6.0, 40.0, 0.0, 0, Color(Style.AQUA, 0.95), Vector2(12, 14))
	band.position = Vector2(-410, 250)
	band.pivot_offset = Vector2(bw * 0.5, 107)
	band.scale = Vector2(0.0, 1.0)
	rig.add_child(band)
	_speed_lines(band, Rect2(Vector2(0, 14), Vector2(bw, 186)), Color(Style.AQUA, 0.15), 1.0, 0.0, 18)
	for i in 6:
		var st := _slant(Vector2(18, 214), Color(Style.YUZU, 0.85), Color(0, 0, 0, 0), 0.0, 60.0, 0.0, 0, Color(0, 0, 0, 0))
		st.position = Vector2(410.0 + W - 120.0 + i * 30.0, 0)
		band.add_child(st)
	var sliver := _slant(Vector2(bw, 12), Style.YUZU, Color(0, 0, 0, 0), 0.0, 10.0, 0.0, 0, Color(0, 0, 0, 0))
	sliver.position = Vector2(-410, 482)
	sliver.scale = Vector2(0.0, 1.0)
	rig.add_child(sliver)
	# Mochi window: skewed frame, portrait slash-wiped in, speed lines behind
	var mc := Cast.color(shouter)
	var win := _slant(Vector2(360, 430), Color(mc.darkened(0.45), 0.97), Color.WHITE, 5.0, 70.0, 0.0, 4, Color(INK, 0.95), Vector2(10, 10))
	win.stripe_col = Color(mc.lightened(0.2), 0.35)
	win.refresh()
	win.position = Vector2(-460, 150)
	root.add_child(win)
	_speed_lines(win, Rect2(Vector2(20, 20), Vector2(320, 390)), Color(mc.lightened(0.4), 0.3), 1.0, 0.0, 10)
	var por := CutPortrait.new()
	por.texture = Assets.portrait(shouter, "angry")
	por.size = Vector2(392, 490)
	por.position = Vector2(-16, -46)
	por.frame = PackedVector2Array([Vector2(16 + 74, 52), Vector2(16 + 356, 52), Vector2(16 + 286, 474), Vector2(16 + 4, 474)])
	por.wipe = 0.0
	por.edge_col = Color(Style.GOLD, 0.9)
	win.add_child(por)
	var font := Style.display_font()
	var fs := 88
	while fs > 40 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 860.0:
		fs -= 4
	var echo := Style.title_label(text, fs, Color(Style.AQUA, 0.45), Color(0, 0, 0, 0), 0)
	var tl := _hard_shadow(Style.title_label(text, fs, Style.GOLD, INK, 20), Vector2(8, 9), Color(Style.AQUA_DEEP, 1.0))
	for l in [echo, tl]:
		var lb: Label = l
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.size = Vector2(900, 150)
		lb.position = Vector2(370, 284)
		lb.pivot_offset = lb.size * 0.5
		lb.rotation = deg_to_rad(-8.0)
		lb.scale = Vector2(2.4, 2.4)
		lb.modulate.a = 0.0
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(lb)
	Audio.sfx("shout")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(band, "scale:x", 1.0, _fxd(0.13)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(sliver, "scale:x", 1.0, _fxd(0.16)).set_delay(_fxd(0.04)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(win, "position:x", 22.0, _fxd(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(por, "wipe", 1.0, _fxd(0.24)).set_delay(_fxd(0.06)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl, "scale", Vector2.ONE, _fxd(0.18)).set_delay(_fxd(0.07)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl, "modulate:a", 1.0, _fxd(0.06)).set_delay(_fxd(0.07))
	await _wait(_fxd(0.24))
	if _gone():
		return
	_shake(18.0, 0.4)
	_flash(Color.WHITE, 0.5, 0.28)
	_focus(Vector2(800, 350), 1.0, 1.2)
	for k in 7:
		var bx := 420.0 + k * 125.0
		_fx.burst(Vector2(bx, 370.0 - (bx - 640.0) * 0.14 + randf_range(-60, 60)), 9, WATER, 560.0, 1000.0, 7.0, 0)
	echo.scale = Vector2.ONE
	echo.modulate.a = 1.0
	var tw3 := create_tween()
	tw3.set_parallel(true)
	tw3.tween_property(echo, "scale", Vector2(1.6, 1.6), _fxd(0.35)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw3.tween_property(echo, "modulate:a", 0.0, _fxd(0.35))
	tw3.tween_property(foc, "k", 0.35, _fxd(0.6))
	await _wait_click(_fxd(0.45), _fxd(1.2))
	if _gone():
		return
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(root, "modulate:a", 0.0, _fxd(0.22))
	tw2.tween_property(rig, "position:x", 260.0, _fxd(0.22)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw2.tween_property(win, "position:x", -420.0, _fxd(0.22)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw2.finished
	root.queue_free()


## Speech box with the speaker's face, name and line. Click/Space closes after min_t; auto-closes at max_t.
func _say_box(speaker: String, expr: String, text: String, pos: Vector2, w: float, max_t: float, min_t: float = 0.35) -> void:
	Game.log_say(speaker, text)
	var col := Cast.color(speaker)
	var fsz := 21
	var text_w := w - 170.0
	var th := _text_height(text, Style.body_font(), fsz, text_w)
	var hgt := maxf(132.0, th + 60.0)
	var box := _slant(Vector2(w, hgt), Color(0.06, 0.035, 0.14, 0.97), col, 3.0, 18.0, 14.0, 4, Color(INK, 0.95), Vector2(8, 8))
	box.stripe_col = Color(col, 0.22)
	box.refresh()
	box.position = pos
	box.pivot_offset = box.size * 0.5
	var fr := _slant(Vector2(118, 112), col.darkened(0.55), col, 3.0, 16.0, 8.0, 0, Color(INK, 0.9), Vector2(4, 4))
	fr.position = Vector2(18, 10)
	box.add_child(fr)
	var face := CutPortrait.new()
	face.texture = Assets.portrait(speaker, expr)
	face.size = Vector2(118, 112)
	face.uv_rect = Rect2(0.2, 0.03, 0.6, 0.45)
	face.frame = PackedVector2Array([Vector2(19, 3), Vector2(114, 3), Vector2(99, 109), Vector2(4, 109)])
	fr.add_child(face)
	var tag := _make_name_tag(speaker, 20)
	tag.position = Vector2(150, -18)
	box.add_child(tag)
	var tx := Label.new()
	tx.text = text
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.position = Vector2(156, 30)
	tx.size = Vector2(text_w, th + 10.0)
	tx.add_theme_font_size_override("font_size", fsz)
	tx.add_theme_color_override("font_color", Style.TEXT)
	tx.visible_ratio = 0.0
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tx)
	var arrow := Style.label("▼", 18, Style.YUZU)
	arrow.position = Vector2(w - 62, hgt - 30)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(arrow)
	_top.add_child(box)
	var home := pos
	box.position = home + Vector2(-90, 0)
	box.scale = Vector2(1.0, 0.2)
	box.modulate.a = 0.0
	Audio.sfx("select", 0.9, -6.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(box, "position", home, _fxd(0.16)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "scale", Vector2.ONE, _fxd(0.18)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, _fxd(0.08))
	tw.tween_property(tx, "visible_ratio", 1.0, _fxd(clampf(text.length() / 70.0, 0.25, 1.1)))
	await _wait_click(min_t, max_t)
	if _gone():
		return
	tx.visible_ratio = 1.0
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(box, "modulate:a", 0.0, _fxd(0.14))
	tw2.tween_property(box, "position:x", home.x + 80.0, _fxd(0.14)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw2.finished
	box.queue_free()


# =================================================================== Truth Drop ammo tray
## The Truth Drops a debate loads: those of its own the player holds (a Drop they never found isn't in the tray, and
## one another guest handed over in the trial is, since it's in the notebook by then), topped up to the chapter's
## "ammo_min" from the notebook. The extras go in at positions fixed by the segment's id, so retries look the same and
## the answer's place gives nothing away.
func _ammo_list(ids: Array) -> Array:
	var out := _held(ids)
	var want := mini(int(Chapters.get_value("ammo_min", 0)), 6)
	if out.size() >= want:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(data.get("id", "")))
	var pool: Array = []
	for c in Game.clues:
		if not out.has(c):
			pool.append(c)
	while out.size() < want and not pool.is_empty():
		var c: Variant = pool.pop_at(rng.randi() % pool.size())
		out.insert(rng.randi() % (out.size() + 1), c)
	return out


## The Truth Drops of a list that are in the notebook, in the list's order.
func _held(ids: Array) -> Array:
	var out: Array = []
	for c in ids:
		if Game.has_clue(str(c)) and not out.has(c):
			out.append(c)
	return out


## Up to six Truth Drops fit in a row; keys 1-9 pick them (see _unhandled_input).
func _build_drop_panel(ids: Array) -> void:
	_drop_ids = ids.duplicate()
	_chips.clear()
	var n := _drop_ids.size()
	var chip_w := 236.0 if n <= 3 else (222.0 if n <= 5 else 190.0)
	var gap := 14.0 if n <= 5 else 10.0
	var icon := 62.0 if n <= 5 else 46.0
	var pw := n * chip_w + (n - 1) * gap + 36.0
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.size = Vector2(pw, 120)
	_panel.position = Vector2((W - pw) * 0.5, H + 40)
	_ui.add_child(_panel)
	var bg := _slant(Vector2(pw, 98), Color(0.04, 0.025, 0.10, 0.94), Style.AQUA_DEEP, 3.0, 26.0, 16.0, 0, Color(INK, 0.92), Vector2(8, 8))
	bg.position = Vector2(0, 24)
	_panel.add_child(bg)
	var tab := _slant(Vector2(186, 30), Style.AQUA, Color.WHITE, 2.0, 10.0, 6.0, 3, Color(INK, 0.95), Vector2(5, 5))
	tab.stripe_col = Color(1, 1, 1, 0.45)
	tab.refresh()
	tab.position = Vector2(22, -10)
	var tl := Style.label("TRUTH DROPS", 17, Style.BG_DARK, true)
	tl.position = Vector2(16, 3)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(tl)
	_panel.add_child(tab)
	var keys := _hard_shadow(Style.title_label("[1-%d] / wheel: switch drop      click: FIRE!" % n, 14, Style.TEXT_DIM, Style.BG_DARK, 4), Vector2(2, 2), INK)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys.size = Vector2(420, 20)
	keys.position = Vector2(pw - 448, -6)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(keys)
	for i in n:
		var id := str(_drop_ids[i])
		var chip := Panel.new()
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.size = Vector2(chip_w, CHIP_H)
		chip.position = Vector2(18 + i * (chip_w + gap), 34)
		chip.pivot_offset = chip.size * 0.5
		chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_panel.add_child(chip)
		var cbg := _slant(Vector2(chip_w, CHIP_H), Color.BLACK, Color.BLACK, 2.0, 14.0, 10.0, 0)
		chip.add_child(cbg)
		chip.set_meta("bg", cbg)
		var ibg := _slant(Vector2(icon, 60), Color(0.14, 0.24, 0.36, 1.0), Style.AQUA_DEEP, 2.0, 8.0, 6.0, 0, Color(INK, 0.8), Vector2(3, 3))
		ibg.position = Vector2(14, 8)
		chip.add_child(ibg)
		var tex := Assets.clue_icon(id)
		if tex:
			var ir := TextureRect.new()
			ir.texture = tex
			ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ir.position = Vector2(3, 2 + (56.0 - minf(icon - 6.0, 56.0)) * 0.5)
			ir.size = Vector2.ONE * minf(icon - 6.0, 56.0)
			ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ibg.add_child(ir)
		else:
			var hue := float(absi(hash(id)) % 1000) / 1000.0
			ibg.fill = Color.from_hsv(hue, 0.45, 0.8)
			ibg.border = Color.WHITE
			ibg.refresh()
			var ini := Style.label(_initials(Clues.clue_name(id)), 22, Style.BG_DARK, true)
			ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ini.size = Vector2(icon, 60)
			ini.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ibg.add_child(ini)
		var nm := Label.new()
		nm.text = Clues.clue_name(id)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.max_lines_visible = 2 if n <= 5 else 3
		nm.position = Vector2(icon + 22.0, 4)
		nm.size = Vector2(chip_w - icon - 38.0, CHIP_H - 8)
		nm.add_theme_font_size_override("font_size", 17 if n <= 5 else 14)
		nm.add_theme_color_override("font_color", Style.TEXT)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(nm)
		var kb := _slant(Vector2(28, 26), Style.GOLD, Style.BG_DARK, 2.0, 6.0, 5.0, 0, Color(INK, 0.95), Vector2(3, 3))
		kb.position = Vector2(-4, -10)
		var kl := Style.label(str(i + 1), 15, Style.BG_DARK, true)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		kl.size = Vector2(28, 26)
		kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kb.add_child(kl)
		chip.add_child(kb)
		var loaded := _slant(Vector2(72, 18), Style.YUZU, Style.BG_DARK, 2.0, 6.0, 4.0, 0, Color(INK, 0.95), Vector2(3, 3))
		var ll := Style.label("LOADED", 11, Style.BG_DARK, true)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ll.size = Vector2(72, 18)
		ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		loaded.add_child(ll)
		loaded.position = Vector2(chip_w - 96, CHIP_H - 9)
		loaded.visible = false
		chip.add_child(loaded)
		chip.set_meta("loaded", loaded)
		chip.gui_input.connect(func(ev: InputEvent) -> void: _on_chip_input(i, ev))
		chip.mouse_entered.connect(func() -> void: _hover_drop(i))
		chip.mouse_exited.connect(func() -> void: _hover_drop(-1))
		_chips.append(chip)
	_tip = _slant(Vector2(470, 80), Color(0.06, 0.035, 0.15, 0.97), Style.YUZU, 3.0, 14.0, 10.0, 3, Color(INK, 0.92), Vector2(7, 7))
	_tip.stripe_col = Color(Style.YUZU, 0.25)
	_tip.visible = false
	_ui.add_child(_tip)
	_tip_title = Style.label("", 18, Style.GOLD, true)
	_tip_title.position = Vector2(22, 8)
	_tip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_title)
	_tip_label = Label.new()
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.position = Vector2(22, 36)
	_tip_label.add_theme_font_size_override("font_size", 16)
	_tip_label.add_theme_color_override("font_color", Style.TEXT)
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_label)
	_select_drop(0, false)


func _style_chip(k: int) -> void:
	var c: Panel = _chips[k]
	var bg: Slant = c.get_meta("bg")
	if k == _sel:
		bg.fill = Color(0.25, 0.14, 0.34, 0.99)
		bg.border = Style.YUZU
		bg.border_w = 4.0
		bg.shadow = Color(Style.AQUA, 0.9)
		bg.shadow_off = Vector2(7, 7)
		bg.stripes = 3
		bg.stripe_col = Color(Style.YUZU, 0.28)
	elif k == _hover:
		bg.fill = Color(0.15, 0.10, 0.30, 0.98)
		bg.border = Style.AQUA
		bg.border_w = 3.0
		bg.shadow = Color(INK, 0.92)
		bg.shadow_off = Vector2(6, 6)
		bg.stripes = 0
	else:
		bg.fill = Color(0.10, 0.065, 0.21, 0.97)
		bg.border = Style.AQUA_DEEP
		bg.border_w = 2.0
		bg.shadow = Color(INK, 0.92)
		bg.shadow_off = Vector2(6, 6)
		bg.stripes = 0
	bg.refresh()


func _initials(s: String) -> String:
	var out := ""
	for wd in s.replace("'s", "").split(" ", false):
		if out.length() < 2 and wd.length() > 0 and wd[0] != "(":
			out += wd[0].to_upper()
	return out


func _show_drop_panel() -> void:
	if _panel == null:
		return
	_panel_shown = true
	var target := Vector2((W - _panel.size.x) * 0.5, PANEL_Y)
	_panel_rect = Rect2(target - Vector2(10, 20), _panel.size + Vector2(20, 20))
	_panel.position = Vector2(target.x - 160.0, H + 40.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "position:y", target.y, _fxd(0.26)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "position:x", target.x, _fxd(0.22)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _hide_drop_panel(instant: bool = false) -> void:
	if _panel == null:
		return
	_panel_shown = false
	_tip.visible = false
	if instant:
		_panel.position.y = H + 40.0
		return
	var tw := create_tween()
	tw.tween_property(_panel, "position:y", H + 40.0, _fxd(0.22)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


func _on_chip_input(i: int, ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_select_drop(i)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_drop(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_RIGHT:
			_cycle_drop(1)
		_chips[i].accept_event()


func _selected_drop() -> String:
	if _drop_ids.is_empty():
		return ""
	return str(_drop_ids[_sel])


func _cycle_drop(d: int) -> void:
	if _drop_ids.is_empty():
		return
	_select_drop(posmod(_sel + d, _drop_ids.size()))


func _select_drop(i: int, snd: bool = true) -> void:
	if _drop_ids.is_empty():
		return
	i = clampi(i, 0, _drop_ids.size() - 1)
	if snd:
		Audio.sfx("select", 1.0 + 0.08 * i)
	_sel = i
	for k in _chips.size():
		var c: Panel = _chips[k]
		var on := k == _sel
		_style_chip(k)
		var ld: Control = c.get_meta("loaded")
		ld.visible = on
		var tw := create_tween()
		tw.tween_property(c, "position:y", 34.0 - (12.0 if on else 0.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if snd and _chips.size() > _sel:
		var sc: Panel = _chips[_sel]
		sc.scale = Vector2(1.1, 1.1)
		sc.rotation = deg_to_rad(-2.5)
		var tw2 := create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(sc, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(sc, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var r := sc.get_global_rect()
		_fx.burst(_to_fx(Vector2(r.get_center().x, r.position.y)), 6, WATER, 220.0, 600.0, 4.0, 0)
	_fx.aim_text = Clues.clue_name(_selected_drop())


func _hover_drop(i: int) -> void:
	_hover = i
	for k in _chips.size():
		if k != _sel:
			_style_chip(k)
	if i < 0 or i >= _drop_ids.size():
		_tip.visible = false
		return
	Audio.sfx("select", 1.4, -14.0)
	var id := str(_drop_ids[i])
	var tw_w := 480.0
	_tip_title.text = Clues.clue_name(id)
	_tip_label.text = Clues.desc(id)
	var th := _text_height(_tip_label.text, Style.body_font(), 16, tw_w - 44.0)
	_tip_label.size = Vector2(tw_w - 44.0, th + 6.0)
	_tip.size = Vector2(tw_w, th + 50.0)
	_tip.refresh()
	var chip: Panel = _chips[i]
	var cx := chip.get_global_rect().get_center().x
	_tip.position = Vector2(clampf(cx - tw_w * 0.5, 12.0, W - tw_w - 20.0), PANEL_Y - _tip.size.y - 8.0)
	_tip.visible = true


## Opens the pictures of the loaded Truth Drop, if it has any. The segment waits while they're open.
func _view_selected() -> void:
	var id := _selected_drop()
	if Clues.images(id).is_empty():
		return
	_set_cursor_hidden(false)
	var v: Control = EvidenceViewer.new()
	v.setup({"clue": id})
	add_child(v)


## A Truth Drop that's right but too soon: costs nothing and earns a small bonus later. True if `id` is one here.
func _early_line(id: String, at: Vector2) -> bool:
	var early: Dictionary = data.get("early", {})
	if not early.has(id):
		return false
	Game.note_early(id)
	var line: Variant = early[id]
	var d: Dictionary = line if typeof(line) == TYPE_DICTIONARY else {"speaker": "mochi", "expr": "normal", "text": str(line)}
	Audio.sfx("select", 0.9)
	await _say_box(str(d.get("speaker", "mochi")), str(d.get("expr", "normal")), str(d.get("text", "")), at, 760.0, _fxd(3.4), _fxd(0.4))
	return true


## Projectile origin (top of the selected chip) in fx coordinates.
func _muzzle() -> Vector2:
	if _chips.is_empty():
		return _to_fx(Vector2(W * 0.5, H + 10.0))
	var c: Panel = _chips[_sel]
	var r := c.get_global_rect()
	return _to_fx(Vector2(r.get_center().x, r.position.y + 4.0))


# =================================================================== inner classes
## Angular panel: parallelogram (skew_px = how far the top edge leans right of the bottom edge) with
## chamfered corners (cut: top-left & bottom-right, cut2: the other two), a hard offset drop shadow,
## a thick outline, an optional inner hairline and optional diagonal stripes at the right end.
class Slant extends Control:
	var fill := Color(0.06, 0.035, 0.13, 0.95)
	var border := Color("3ee0d0")
	var border_w := 3.0
	var shadow := Color(0.027, 0.016, 0.06, 0.92)
	var shadow_off := Vector2(7, 7)
	var skew_px := 16.0
	var cut := 12.0
	var cut2 := 0.0
	var stripes := 0
	var stripe_col := Color(1, 1, 1, 0.1)
	var stripe_left := false
	var inner := Color(0, 0, 0, 0)
	var _poly := PackedVector2Array()
	var _outline := PackedVector2Array()
	var _inner_line := PackedVector2Array()
	var _stripe_polys: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			refresh()

	func refresh() -> void:
		_rebuild()
		queue_redraw()

	func _rebuild() -> void:
		_poly = PackedVector2Array()
		_outline = PackedVector2Array()
		_inner_line = PackedVector2Array()
		_stripe_polys.clear()
		var w := size.x
		var h := size.y
		if w < 3.0 or h < 3.0:
			return
		var s := clampf(skew_px, -w * 0.45, w * 0.45)
		var a := maxf(s, 0.0)
		var b := maxf(-s, 0.0)
		var c: Array = [Vector2(a, 0), Vector2(w - b, 0), Vector2(w - a, h), Vector2(b, h)]
		var cuts: Array = [cut, cut2, cut, cut2]
		for i in 4:
			var v: Vector2 = c[i]
			var cc: float = minf(float(cuts[i]), h * 0.45)
			if cc <= 0.5:
				_poly.append(v)
				continue
			var pv: Vector2 = c[(i + 3) % 4]
			var nv: Vector2 = c[(i + 1) % 4]
			_poly.append(v + (pv - v).normalized() * cc)
			_poly.append(v + (nv - v).normalized() * cc)
		_outline = _poly.duplicate()
		_outline.append(_poly[0])
		if inner.a > 0.0:
			var off := Geometry2D.offset_polygon(_poly, -(border_w + 4.0))
			if off.size() > 0:
				_inner_line = off[0]
				if _inner_line.size() > 0:
					_inner_line.append(_inner_line[0])
		if stripes > 0:
			var sw := clampf(h * 0.16, 6.0, 12.0)
			var gap := sw * 0.9
			var lean := h * 0.6
			for k in stripes:
				var x0 := (w - 18.0 - sw - k * (sw + gap)) if not stripe_left else (18.0 + k * (sw + gap))
				var band := PackedVector2Array([Vector2(x0 + lean * 0.5, -2), Vector2(x0 + lean * 0.5 + sw, -2),
					Vector2(x0 - lean * 0.5 + sw, h + 2), Vector2(x0 - lean * 0.5, h + 2)])
				for piece in Geometry2D.intersect_polygons(band, _poly):
					_stripe_polys.append(piece)

	func _draw() -> void:
		if _poly.size() < 3:
			return
		if shadow.a > 0.0:
			draw_set_transform(shadow_off)
			draw_colored_polygon(_poly, shadow)
			draw_set_transform(Vector2.ZERO)
		if fill.a > 0.0:
			draw_colored_polygon(_poly, fill)
		for sp in _stripe_polys:
			var pp: PackedVector2Array = sp
			if pp.size() >= 3:
				draw_colored_polygon(pp, stripe_col)
		if _inner_line.size() > 2:
			draw_polyline(_inner_line, inner, 1.5, true)
		if border_w > 0.0 and border.a > 0.0:
			draw_polyline(_outline, border, border_w, true)


## A portrait drawn as a textured polygon: optional clip `frame` polygon (e.g. a skewed window), a
## `uv_rect` crop of the texture, and a diagonal slash `wipe` reveal (0..1) with a bright leading edge.
class CutPortrait extends Control:
	var texture: Texture2D:
		set(v):
			texture = v
			queue_redraw()
	var wipe := 1.0:
		set(v):
			wipe = v
			queue_redraw()
	var wipe_dir := 1.0
	var slant := 0.45
	var edge_col := Color(1, 1, 1, 0.0)
	var frame := PackedVector2Array()
	var uv_rect := Rect2(0, 0, 1, 1)
	var _cols := PackedColorArray([Color.WHITE])

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if texture == null or size.x < 2.0 or size.y < 2.0 or wipe <= 0.0:
			return
		var pts := frame
		if pts.size() < 3:
			pts = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		var ea := Vector2.ZERO
		var eb := Vector2.ZERO
		if wipe < 1.0:
			var sl := size.y * slant
			var hp: PackedVector2Array
			if wipe_dir >= 0.0:
				var e := lerpf(-sl * 0.5, size.x + sl * 0.5, wipe)
				ea = Vector2(e + sl * 0.5, -4.0)
				eb = Vector2(e - sl * 0.5, size.y + 4.0)
				hp = PackedVector2Array([Vector2(-4000, -4), ea, eb, Vector2(-4000, size.y + 4.0)])
			else:
				var e2 := lerpf(size.x + sl * 0.5, -sl * 0.5, wipe)
				ea = Vector2(e2 - sl * 0.5, -4.0)
				eb = Vector2(e2 + sl * 0.5, size.y + 4.0)
				hp = PackedVector2Array([ea, Vector2(size.x + 4000, -4), Vector2(size.x + 4000, size.y + 4.0), eb])
			var parts := Geometry2D.intersect_polygons(pts, hp)
			if parts.is_empty():
				return
			pts = parts[0]
		if pts.size() < 3:
			return
		var uvs := PackedVector2Array()
		uvs.resize(pts.size())
		for i in pts.size():
			uvs[i] = uv_rect.position + pts[i] / size * uv_rect.size
		draw_polygon(pts, _cols, uvs, texture)
		if wipe < 1.0 and edge_col.a > 0.0:
			var segs: Array = [PackedVector2Array([ea, eb])]
			if frame.size() >= 3:
				segs = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([ea, eb]), frame)
			for sg in segs:
				var seg: PackedVector2Array = sg
				if seg.size() >= 2:
					draw_line(seg[0], seg[seg.size() - 1], edge_col, 12.0)
					draw_line(seg[0], seg[seg.size() - 1], Color(1, 1, 1, edge_col.a), 4.0)


## Horizontal speed lines rushing through a rect.
class Streaks extends Control:
	var col := Color(1, 1, 1, 0.15)
	var spd := 2200.0
	var dir := 1.0
	var n := 12
	var _d: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		for i in n:
			_d.append(Vector4(randf() * size.x, randf() * maxf(size.y - 6.0, 1.0), randf_range(90.0, 420.0), randf_range(2.0, 7.0)))

	func _process(delta: float) -> void:
		var span := size.x + 500.0
		for i in _d.size():
			var v: Vector4 = _d[i]
			v.x += dir * spd * delta * (0.55 + 0.45 * float(i % 3) / 2.0)
			if dir > 0.0 and v.x > size.x:
				v.x -= span
			elif dir < 0.0 and v.x + v.z < 0.0:
				v.x += span
			_d[i] = v
		queue_redraw()

	func _draw() -> void:
		for v in _d:
			var q: Vector4 = v
			var x0 := maxf(q.x, 0.0)
			var x1 := minf(q.x + q.z, size.x)
			if x1 > x0:
				draw_rect(Rect2(x0, q.y, x1 - x0, q.w), col)


## Manga focus lines: thin wedges from beyond the screen edge toward a center point.
class Focus extends Control:
	var c := Vector2(640, 360)
	var k := 0.0:
		set(v):
			k = v
			queue_redraw()
	var col := Color(1, 1, 1, 0.5)
	var r_in := 300.0
	var decay := 0.0
	var n := 44
	var _ang := PackedFloat32Array()
	var _len := PackedFloat32Array()
	var _wid := PackedFloat32Array()
	var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var _t := 0.0
	var _next := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ang.resize(n)
		_len.resize(n)
		_wid.resize(n)
		_reroll()

	func _reroll() -> void:
		for i in n:
			_ang[i] = (float(i) + randf()) * TAU / float(n)
			_len[i] = randf_range(0.0, 190.0)
			_wid[i] = randf_range(0.004, 0.02)

	func _process(delta: float) -> void:
		if k <= 0.0:
			return
		_t += delta
		if decay > 0.0:
			k = maxf(k - decay * delta, 0.0)
		if _t >= _next:
			_next = _t + 0.05
			_reroll()
		queue_redraw()

	func _draw() -> void:
		if k <= 0.01:
			return
		var far := 1600.0
		var cc := Color(col, col.a * minf(k, 1.0))
		for i in n:
			var a := _ang[i]
			var w := _wid[i]
			_tri[0] = c + Vector2.from_angle(a) * (r_in + _len[i])
			_tri[1] = c + Vector2.from_angle(a - w) * far
			_tri[2] = c + Vector2.from_angle(a + w) * far
			draw_colored_polygon(_tri, cc)


## Tapered slicing streak a -> b (k = drawn length 0..1, fade = thickness/alpha 1..0).
class Blade extends Control:
	var a := Vector2.ZERO
	var b := Vector2(100, 0)
	var col := Color("ffd166")
	var thick := 14.0
	var k := 0.0:
		set(v):
			k = v
			queue_redraw()
	var fade := 1.0:
		set(v):
			fade = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if k <= 0.0 or fade <= 0.0:
			return
		var e := a.lerp(b, k)
		var d := e - a
		if d.length() < 2.0:
			return
		var nn := Vector2(-d.y, d.x).normalized()
		var th := thick * fade
		var m := a.lerp(e, 0.72)
		draw_colored_polygon(PackedVector2Array([a, m + nn * th, e, m - nn * th]), Color(col, col.a * fade))
		draw_colored_polygon(PackedVector2Array([a.lerp(e, 0.15), m + nn * th * 0.32, e, m - nn * th * 0.32]), Color(1, 1, 1, fade))


## Screen shatter: the captured frame split into triangular glass shards (Polygon2D + UV) that burst
## outward from the impact point, spinning and fading, over a bright aqua/yuzu flash with focus lines.
class Shatter extends Control:
	var center := Vector2(640, 360)
	var dur := 0.85
	var t := 0.0
	var shards: Array = []
	var _foc: Focus

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func build(tex: Texture2D, c: Vector2, to_px: Transform2D, img_size: Vector2, d: float) -> void:
		center = c
		dur = maxf(d, 0.05)
		_foc = Focus.new()
		_foc.size = size
		_foc.c = c
		_foc.col = Color(1.0, 0.82, 0.4, 0.55)
		_foc.r_in = 120.0
		_foc.k = 1.0
		add_child(_foc)
		if tex == null or img_size.x < 2.0:
			return
		var screen := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		var n := 8
		var a0 := randf() * TAU
		var radii: Array = [randf_range(70.0, 105.0), randf_range(230.0, 300.0), 1800.0]
		var ring_pts: Array = []
		for j in radii.size():
			var row: Array = []
			for i in n:
				var ang := a0 + (float(i) + randf_range(-0.28, 0.28)) * TAU / float(n)
				var rr: float = float(radii[j]) * (randf_range(0.82, 1.18) if j < 2 else 1.0)
				row.append(c + Vector2.from_angle(ang) * rr)
			ring_pts.append(row)
		var tris: Array = []
		var r0: Array = ring_pts[0]
		for i in n:
			tris.append(PackedVector2Array([c, r0[i], r0[(i + 1) % n]]))
		for j in 2:
			var ra: Array = ring_pts[j]
			var rb: Array = ring_pts[j + 1]
			for i in n:
				var i2 := (i + 1) % n
				if (i + j) % 2 == 0:
					tris.append(PackedVector2Array([ra[i], rb[i], rb[i2]]))
					tris.append(PackedVector2Array([ra[i], rb[i2], ra[i2]]))
				else:
					tris.append(PackedVector2Array([ra[i], rb[i], ra[i2]]))
					tris.append(PackedVector2Array([rb[i], rb[i2], ra[i2]]))
		for tri in tris:
			for piece in Geometry2D.intersect_polygons(tri, screen):
				var poly: PackedVector2Array = piece
				if poly.size() < 3:
					continue
				_add_shard(poly, tex, to_px)

	func _add_shard(poly: PackedVector2Array, tex: Texture2D, to_px: Transform2D) -> void:
		var cen := Vector2.ZERO
		for p in poly:
			cen += p
		cen /= float(poly.size())
		var local := PackedVector2Array()
		var uv := PackedVector2Array()
		for p in poly:
			local.append(p - cen)
			uv.append(to_px * p)
		var pg := Polygon2D.new()
		pg.texture = tex
		pg.polygon = local
		pg.uv = uv
		pg.position = cen
		add_child(pg)
		var edge := Line2D.new()
		var ep := local.duplicate()
		ep.append(local[0])
		edge.points = ep
		edge.width = 2.5
		edge.default_color = Color(0.9, 1.0, 1.0, 0.75)
		edge.joint_mode = Line2D.LINE_JOINT_SHARP
		pg.add_child(edge)
		var dv := cen - center
		var dist := dv.length()
		var dir := dv / dist if dist > 1.0 else Vector2.from_angle(randf() * TAU)
		var spd := lerpf(1100.0, 420.0, clampf(dist / 900.0, 0.0, 1.0)) * randf_range(0.8, 1.2)
		var v := dir * spd + Vector2(0, -randf_range(60.0, 220.0))
		shards.append({"n": pg, "v": v, "w": randf_range(-7.0, 7.0) * (1.3 - clampf(dist / 1100.0, 0.0, 1.0)),
			"s": randf_range(0.15, 0.7), "delay": clampf(dist / 2600.0, 0.0, 0.12)})

	func _process(delta: float) -> void:
		t += delta
		var k := clampf(t / dur, 0.0, 1.0)
		for sh in shards:
			var d: Dictionary = sh
			var pg: Polygon2D = d["n"]
			var lt := t - float(d["delay"])
			if lt <= 0.0:
				continue
			var v: Vector2 = d["v"]
			v.y += 1500.0 * delta
			v *= 1.0 - 0.8 * delta
			d["v"] = v
			pg.position += v * delta
			pg.rotation += float(d["w"]) * delta
			pg.scale = Vector2.ONE * (1.0 + float(d["s"]) * lt)
			pg.modulate.a = 1.0 - smoothstep(0.35, 1.0, k)
		if _foc != null:
			_foc.k = 1.0 - k
		queue_redraw()
		if k >= 1.0:
			queue_free()

	func _draw() -> void:
		var k := clampf(t / dur, 0.0, 1.0)
		var a := 1.0 - smoothstep(0.15, 0.75, k)
		if a <= 0.0:
			return
		var c1 := Color("bff8ff").lerp(Color("3ee0d0"), smoothstep(0.0, 0.3, k))
		draw_rect(Rect2(Vector2.ZERO, size), Color(c1, 0.92 * a))
		var r := lerpf(40.0, 900.0, 1.0 - pow(1.0 - k, 3.0))
		draw_arc(center, r, 0.0, TAU, 64, Color(1.0, 0.70, 0.28, 0.9 * a), 26.0 * (1.0 - k) + 2.0, true)
		draw_arc(center, r * 0.62, 0.0, TAU, 64, Color(1, 1, 1, 0.8 * a), 10.0 * (1.0 - k) + 2.0, true)


## Semi-transparent night overlay (the live courtroom shows through) with a vignette, slow diagonal
## water streaks, steam, three depth layers of parallax bubbles and a focus-lines layer for emphasis.
class Backdrop extends Control:
	var tint := Color("3ee0d0")
	var dim := 0.5
	var speed := 70.0
	var t := 0.0
	var cam := Vector2.ZERO
	var focus: Focus
	var soft: Texture2D
	var parts: Array = []      # Vector4(x, y, radius, depth)
	var steam: Array = []      # Vector4(x, y, size, phase)
	var _vig: GradientTexture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		for i in 40:
			var depth := 0.35 if i < 20 else (0.75 if i < 34 else 1.35)
			var r := randf_range(2.0, 4.0) if depth < 0.5 else (randf_range(4.0, 8.0) if depth < 1.0 else randf_range(12.0, 20.0))
			parts.append(Vector4(randf() * 1400.0 - 60.0, randf() * 820.0, r, depth))
		for i in 6:
			steam.append(Vector4(randf() * 1280.0, 520.0 + randf() * 260.0, randf_range(260.0, 420.0), randf() * TAU))
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(0.027, 0.016, 0.06, 0.0), Color(0.027, 0.016, 0.06, 0.08), Color(0.027, 0.016, 0.06, 0.82)])
		_vig = GradientTexture2D.new()
		_vig.gradient = g
		_vig.fill = GradientTexture2D.FILL_RADIAL
		_vig.fill_from = Vector2(0.5, 0.5)
		_vig.fill_to = Vector2(1.08, 0.5)
		_vig.width = 128
		_vig.height = 128
		focus = Focus.new()
		focus.size = Vector2(1280, 720)
		focus.col = Color(1, 1, 1, 0.42)
		add_child(focus)

	func _process(delta: float) -> void:
		t += delta
		var w := maxf(size.x, 1280.0)
		var h := maxf(size.y, 720.0)
		for i in parts.size():
			var b: Vector4 = parts[i]
			b.y -= delta * (10.0 + 30.0 * b.w)
			b.x += sin(t * 1.1 + float(i)) * delta * 7.0 * b.w
			if b.y < -40.0:
				b = Vector4(randf() * (w + 120.0) - 60.0, h + 40.0, b.z, b.w)
			parts[i] = b
		for i in steam.size():
			var s: Vector4 = steam[i]
			s.y -= delta * 14.0
			s.x += sin(t * 0.4 + s.w) * delta * 10.0
			if s.y < 260.0:
				s = Vector4(randf() * w, h + 200.0, randf_range(260.0, 420.0), randf() * TAU)
			steam[i] = s
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.04, 0.14, dim))
		for s in steam:
			var q: Vector4 = s
			var fade := clampf((q.y - 260.0) / 260.0, 0.0, 1.0)
			var p := Vector2(q.x, q.y) + cam * 0.2
			if soft != null:
				draw_texture_rect(soft, Rect2(p - Vector2(q.z, q.z * 0.6), Vector2(q.z * 2.0, q.z * 1.2)), false, Color(0.75, 0.95, 1.0, 0.07 * fade))
		for i in 14:
			var x := fmod(i * 137.0 + t * speed * (0.7 + 0.1 * float(i % 4)), w + 700.0) - 250.0 + cam.x * 0.5
			var lw := 10.0 + float(i % 4) * 12.0
			draw_line(Vector2(x, -10), Vector2(x - 460.0, h + 10.0), Color(tint, 0.03 + 0.012 * float(i % 3)), lw)
		for b in parts:
			var q2: Vector4 = b
			var p2 := Vector2(q2.x, q2.y) + cam * q2.w
			var r := q2.z
			if q2.w < 0.5:
				draw_circle(p2, r, Color(tint, 0.22))
			elif q2.w < 1.0:
				draw_arc(p2, r, 0.0, TAU, 14, Color(tint, 0.34), 1.5, true)
				draw_circle(p2 + Vector2(-r * 0.35, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.32))
			else:
				draw_arc(p2, r, 0.0, TAU, 24, Color(tint, 0.14), 3.0, true)
				draw_circle(p2 + Vector2(-r * 0.35, -r * 0.35), r * 0.2, Color(1, 1, 1, 0.16))
		draw_texture_rect(_vig, Rect2(Vector2(-w * 0.06, -h * 0.06), size * 1.12), false)


## Particles, water-shot projectiles, expanding rings and the crosshair.
class Fx extends Control:
	var parts: Array = []
	var shots: Array = []
	var rings: Array = []
	var aim := Vector2(-100, -100)
	var aim_on := false
	var aim_hot := false
	var aim_text := ""
	var aim_font: Font
	var t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## kind 0 = water droplet, 1 = sparkle star, 2 = shard
	func burst(pos: Vector2, n: int, cols: Array, spd: float = 420.0, grav: float = 900.0, sz: float = 6.0, kind: int = 0) -> void:
		for i in n:
			var a := randf() * TAU
			var v := Vector2(cos(a), sin(a)) * spd * randf_range(0.3, 1.0)
			v.y -= spd * 0.25
			var life := randf_range(0.45, 0.95)
			parts.append({"p": pos, "v": v, "life": life, "max": life, "s": sz * randf_range(0.6, 1.4),
				"c": cols[randi() % cols.size()], "k": kind, "r": randf() * TAU, "w": randf_range(-9.0, 9.0), "g": grav})

	func shot(from: Vector2, to: Vector2, dur: float, cb: Callable) -> void:
		shots.append({"a": from, "b": to, "t": 0.0, "d": maxf(dur, 0.01), "cb": cb})
		burst(from, 7, [Color("3ee0d0"), Color.WHITE], 180.0, 400.0, 4.0, 0)

	func ring(pos: Vector2, r0: float, r1: float, dur: float, col: Color, w: float = 4.0) -> void:
		rings.append({"p": pos, "r0": r0, "r1": r1, "t": 0.0, "d": maxf(dur, 0.01), "c": col, "w": w})

	func _shot_pos(sh: Dictionary, k: float) -> Vector2:
		var a: Vector2 = sh["a"]
		var b: Vector2 = sh["b"]
		return a.lerp(b, k) + Vector2(0, -sin(k * PI) * 0.12 * a.distance_to(b))

	func _process(delta: float) -> void:
		t += delta
		var i := parts.size() - 1
		while i >= 0:
			var p: Dictionary = parts[i]
			var life: float = p["life"] - delta
			if life <= 0.0:
				parts.remove_at(i)
			else:
				p["life"] = life
				var v: Vector2 = p["v"]
				v.y += float(p["g"]) * delta
				v *= 1.0 - delta * 1.4
				p["v"] = v
				p["p"] = (p["p"] as Vector2) + v * delta
				p["r"] = float(p["r"]) + float(p["w"]) * delta
			i -= 1
		i = rings.size() - 1
		while i >= 0:
			var rg: Dictionary = rings[i]
			rg["t"] = float(rg["t"]) + delta
			if float(rg["t"]) >= float(rg["d"]):
				rings.remove_at(i)
			i -= 1
		i = shots.size() - 1
		while i >= 0:
			var sh: Dictionary = shots[i]
			sh["t"] = float(sh["t"]) + delta
			var k := clampf(float(sh["t"]) / float(sh["d"]), 0.0, 1.0)
			if randf() < 0.7:
				burst(_shot_pos(sh, k), 1, [Color("bff8ff"), Color("3ee0d0")], 40.0, 300.0, 3.5, 0)
			if k >= 1.0:
				shots.remove_at(i)
				var cb: Callable = sh["cb"]
				if cb.is_valid():
					cb.call()
			i -= 1
		queue_redraw()

	func _draw() -> void:
		for rg in rings:
			var k: float = float(rg["t"]) / float(rg["d"])
			var e := 1.0 - pow(1.0 - k, 3.0)
			var col: Color = rg["c"]
			draw_arc(rg["p"], lerpf(rg["r0"], rg["r1"], e), 0.0, TAU, 56, Color(col, col.a * (1.0 - k)), maxf(float(rg["w"]) * (1.0 - k), 1.0), true)
		for p in parts:
			var lk: float = float(p["life"]) / float(p["max"])
			var col: Color = p["c"]
			col.a *= clampf(lk * 1.8, 0.0, 1.0)
			var s: float = float(p["s"]) * (0.45 + 0.55 * lk)
			var pos: Vector2 = p["p"]
			match int(p["k"]):
				0:
					var v: Vector2 = p["v"]
					if v.length() > 30.0:
						draw_line(pos, pos - v.normalized() * s * 2.4, col, s * 1.1, true)
					draw_circle(pos, s, col)
					draw_circle(pos + Vector2(-s * 0.3, -s * 0.35), s * 0.32, Color(1, 1, 1, col.a * 0.8))
				1:
					var pts := PackedVector2Array()
					var rot: float = p["r"]
					for q in 8:
						var rr := s * (1.6 if q % 2 == 0 else 0.45)
						pts.append(pos + Vector2(cos(rot + q * PI / 4.0), sin(rot + q * PI / 4.0)) * rr)
					draw_colored_polygon(pts, col)
				_:
					var rot2: float = p["r"]
					var ax := Vector2(cos(rot2), sin(rot2)) * s * 1.3
					var ay := Vector2(-sin(rot2), cos(rot2)) * s * 0.55
					draw_colored_polygon(PackedVector2Array([pos - ax - ay, pos + ax - ay * 0.4, pos + ax + ay, pos - ax * 0.6 + ay]), col)
		for sh in shots:
			var k := clampf(float(sh["t"]) / float(sh["d"]), 0.0, 1.0)
			var pos := _shot_pos(sh, k)
			var prev := _shot_pos(sh, maxf(k - 0.06, 0.0))
			for j in 7:
				var kk := k - j * 0.045
				if kk < 0.0:
					break
				draw_circle(_shot_pos(sh, kk), 9.0 - j * 1.1, Color(0.24, 0.88, 0.82, 0.55 - j * 0.07))
			var dir := (pos - prev).normalized() if pos.distance_to(prev) > 0.5 else Vector2.UP
			var perp := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([pos + perp * 11.0, pos - dir * 34.0, pos - perp * 11.0]), Color(0.24, 0.88, 0.82, 0.95))
			draw_circle(pos, 12.0, Color("bff8ff"))
			draw_circle(pos, 12.0, Color("1a8f9e"), false, 2.0, true)
			draw_circle(pos + Vector2(-4, -4), 4.0, Color.WHITE)
		if aim_on:
			var col := Color("ffb347") if aim_hot else Color("3ee0d0")
			var rr := 22.0 + (sin(t * 12.0) * 2.5 if aim_hot else 0.0)
			var rot := t * (3.2 if aim_hot else 1.4)
			for q in 4:
				var a0 := rot + q * PI * 0.5 + 0.3
				draw_arc(aim, rr, a0, a0 + PI * 0.5 - 0.6, 10, Color(0, 0, 0, 0.55), 7.0, true)
				draw_arc(aim, rr, a0, a0 + PI * 0.5 - 0.6, 10, col, 3.5, true)
			for q in 4:
				var d := Vector2.RIGHT.rotated(q * PI * 0.5)
				draw_line(aim + d * (rr + 5.0), aim + d * (rr + 15.0), Color(0, 0, 0, 0.55), 6.0)
				draw_line(aim + d * (rr + 5.0), aim + d * (rr + 15.0), col, 3.0)
			draw_circle(aim, 4.0, Color(0, 0, 0, 0.6))
			draw_circle(aim, 2.6, col)
			if aim_text != "" and aim_font:
				var fs := 14
				var sw := aim_font.get_string_size(aim_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var o := aim + Vector2(-sw * 0.5 - 10.0, rr + 20.0)
				var tag := PackedVector2Array([o + Vector2(6, 0), o + Vector2(sw + 20.0, 0), o + Vector2(sw + 14.0, 22), o + Vector2(0, 22)])
				draw_set_transform(Vector2(3, 3))
				draw_colored_polygon(tag, Color(0.027, 0.016, 0.06, 0.85))
				draw_set_transform(Vector2.ZERO)
				draw_colored_polygon(tag, Color(0.05, 0.03, 0.12, 0.92))
				tag.append(tag[0])
				draw_polyline(tag, col, 1.5, true)
				draw_string(aim_font, o + Vector2(10, 16), aim_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## A statement drawn as separate word segments, so every {weak spot} has known rects.
## build(text, max_width, font_size, font) lays it out; weak_at(global_pos) hit-tests (rotation/scale/skew aware).
## skew_x leans the whole statement (perspective feel); crack(wk) + crack_k (0..1) draws a glass crack over a weak spot.
class StatementView extends Control:
	var font: Font
	var fsize := 40
	var toks: Array = []
	var weak_rects := {}
	var line_h := 50.0
	var base_off := 30.0
	var hidden_weak := -1
	var hot_weak := -1
	var sparkle_weak := -1
	var show_weak := true
	var dim := 0.0
	var t := 0.0
	var text_col := Color("f4f1ff")
	var weak_col := Color("ffb347")
	var outline_col := Color("120a24")
	var outline_px := 12
	var shadow_col := Color(0.027, 0.016, 0.06, 0.95)
	var shadow_off := Vector2(5, 6)
	var skew_x := 0.0
	var ghost := 0.0
	var ghost_off := Vector2(20, 8)
	var crack_weak := -1
	var crack_k := 0.0:
		set(v):
			crack_k = v
			queue_redraw()
	var _cracks: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func weak_count() -> int:
		return weak_rects.size()

	## Local skew about the pivot (applied when drawing and when hit-testing).
	func _xf() -> Transform2D:
		if is_zero_approx(skew_x):
			return Transform2D.IDENTITY
		var m := Transform2D(0.0, Vector2.ONE, skew_x, Vector2.ZERO)
		m.origin = pivot_offset - m.basis_xform(pivot_offset)
		return m

	func full_xf() -> Transform2D:
		return get_global_transform() * _xf()

	func build(text: String, max_w: float, size_px: int, f: Font) -> void:
		font = f
		fsize = size_px
		toks.clear()
		weak_rects.clear()
		var space_w := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var fh := font.get_height(fsize)
		line_h = fh * 1.14
		base_off = (line_h - fh) * 0.5 + font.get_ascent(fsize)
		# 1) tokens: runs of non-space characters sharing one weak index
		var raw: Array = []
		var cur := ""
		var cur_weak := -1
		var cur_sp := false
		var pending_sp := false
		var weak_idx := -1
		var in_weak := false
		for i in text.length():
			var ch := text[i]
			if ch == "{" or ch == "}" or ch == " ":
				if cur != "":
					raw.append({"t": cur, "weak": cur_weak, "sp": cur_sp})
					cur = ""
				if ch == "{":
					in_weak = true
					weak_idx += 1
				elif ch == "}":
					in_weak = false
				else:
					pending_sp = true
				continue
			if cur == "":
				cur_sp = pending_sp
				pending_sp = false
				cur_weak = weak_idx if in_weak else -1
			cur += ch
		if cur != "":
			raw.append({"t": cur, "weak": cur_weak, "sp": cur_sp})
		for tk in raw:
			tk["w"] = font.get_string_size(str(tk["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		# 2) word wrap (glued tokens like "{9:56}!" never split)
		var lines: Array = []
		var line: Array = []
		var x := 0.0
		var i2 := 0
		while i2 < raw.size():
			var grp: Array = [raw[i2]]
			var j := i2 + 1
			while j < raw.size() and not bool(raw[j]["sp"]):
				grp.append(raw[j])
				j += 1
			var gw := 0.0
			for g in grp:
				gw += float(g["w"])
			var gap := space_w if not line.is_empty() else 0.0
			if not line.is_empty() and x + gap + gw > max_w:
				lines.append({"toks": line, "w": x})
				line = []
				x = 0.0
				gap = 0.0
			x += gap
			for g in grp:
				g["x"] = x
				line.append(g)
				x += float(g["w"])
			i2 = j
		if not line.is_empty():
			lines.append({"toks": line, "w": x})
		var maxw := 0.0
		for ln in lines:
			maxw = maxf(maxw, float(ln["w"]))
		var pad := 18.0
		for li in lines.size():
			var ln: Dictionary = lines[li]
			var off := (maxw - float(ln["w"])) * 0.5 + pad
			for g in ln["toks"]:
				g["x"] = float(g["x"]) + off
				g["y"] = pad + li * line_h
				toks.append(g)
		size = Vector2(maxw + pad * 2.0, lines.size() * line_h + pad * 2.0)
		pivot_offset = size * 0.5
		# 3) weak-spot rects (one per line a weak spot spans)
		var cw := -1
		var cr := Rect2()
		for g in toks:
			var wk: int = g["weak"]
			var r := Rect2(float(g["x"]), float(g["y"]), float(g["w"]), line_h)
			if wk >= 0 and wk == cw and is_equal_approx(r.position.y, cr.position.y):
				cr = cr.merge(r)
			else:
				if cw >= 0:
					_add_rect(cw, cr)
				cw = wk
				cr = r
		if cw >= 0:
			_add_rect(cw, cr)

	func _add_rect(wk: int, r: Rect2) -> void:
		if not weak_rects.has(wk):
			weak_rects[wk] = []
		weak_rects[wk].append(r)

	func weak_at(gp: Vector2) -> int:
		if not show_weak or modulate.a < 0.45 or not is_visible_in_tree():
			return -1
		var lp: Vector2 = full_xf().affine_inverse() * gp
		for wk in weak_rects.keys():
			if wk == hidden_weak:
				continue
			for r in weak_rects[wk]:
				var rr: Rect2 = r
				if rr.grow(12.0).has_point(lp):
					return int(wk)
		return -1

	func weak_center(wk: int) -> Vector2:
		var arr: Array = weak_rects.get(wk, [])
		if arr.is_empty():
			return full_xf() * (size * 0.5)
		var best: Rect2 = arr[0]
		for a in arr:
			var ra: Rect2 = a
			if ra.size.x > best.size.x:
				best = ra
		return full_xf() * best.get_center()

	func weak_points(wk: int, n: int) -> Array:
		var out: Array = []
		var arr: Array = weak_rects.get(wk, [])
		if arr.is_empty():
			return out
		var xf := full_xf()
		for k in n:
			var r: Rect2 = arr[k % arr.size()]
			out.append(xf * Vector2(r.position.x + randf() * r.size.x, r.position.y + randf_range(0.2, 0.8) * r.size.y))
		return out

	## Prepare jagged crack lines radiating over weak spot wk (animate crack_k 0 -> 1).
	func crack(wk: int) -> void:
		crack_weak = wk
		_cracks.clear()
		var arr: Array = weak_rects.get(wk, [])
		for r in arr:
			var rr: Rect2 = r
			var c := rr.get_center() + Vector2(randf_range(-rr.size.x * 0.15, rr.size.x * 0.15), randf_range(-4.0, 4.0))
			var nrays := 5 + int(rr.size.x / 80.0)
			for i in nrays:
				var dv := Vector2.from_angle((float(i) + randf_range(-0.3, 0.3)) * TAU / float(nrays))
				var reach := (absf(dv.x) * rr.size.x * 0.5 + absf(dv.y) * rr.size.y * 0.5) * randf_range(0.7, 1.12)
				var pl := PackedVector2Array([c])
				for s in range(1, 5):
					var p := c + dv * reach * float(s) / 4.0 + Vector2(-dv.y, dv.x) * randf_range(-6.0, 6.0) * float(s)
					pl.append(p)
				_cracks.append(pl)
		crack_k = 0.0

	static func _quad(r: Rect2, sk: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(r.position.x + sk, r.position.y), Vector2(r.end.x + sk, r.position.y),
			Vector2(r.end.x - sk, r.end.y), Vector2(r.position.x - sk, r.end.y), Vector2(r.position.x + sk, r.position.y)])

	func _draw() -> void:
		if font == null:
			return
		draw_set_transform_matrix(_xf())
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		if show_weak:
			for wk in weak_rects.keys():
				if wk == hidden_weak:
					continue
				var hot: bool = wk == hot_weak
				var sp: bool = wk == sparkle_weak
				for r in weak_rects[wk]:
					var rr: Rect2 = r
					var g := rr.grow_individual(12, -2, 12, -2)
					var q := _quad(g, 8.0)
					var qf := q.slice(0, 4)
					if sp:
						var qg := _quad(g.grow(5.0 + 5.0 * pulse), 9.0)
						draw_colored_polygon(qg.slice(0, 4), Color(1.0, 0.88, 0.45, 0.25 + 0.3 * pulse))
					elif hot:
						var qh := _quad(g.grow(6.0), 9.0)
						draw_colored_polygon(qh.slice(0, 4), Color(1.0, 0.82, 0.4, 0.35))
					draw_set_transform_matrix(_xf() * Transform2D(0.0, Vector2(5, 5)))
					draw_colored_polygon(qf, Color(0.027, 0.016, 0.06, 0.55))
					draw_set_transform_matrix(_xf())
					draw_colored_polygon(qf, Color(1.0, 0.70, 0.28, (0.34 if hot else 0.14) + 0.08 * pulse))
					var bc := Color(1.0, 0.96, 0.78, 1.0) if hot else Color(1.0, 0.70, 0.28, 0.55 + 0.4 * pulse)
					draw_polyline(q, bc, 3.0 if (hot or sp) else 2.0, true)
				for r in weak_rects[wk]:
					var rr2: Rect2 = r
					var pts := PackedVector2Array()
					var y0 := rr2.position.y + rr2.size.y - 7.0
					var n := int(rr2.size.x / 6.0) + 1
					for k in n + 1:
						var xx := rr2.position.x + rr2.size.x * float(k) / float(n)
						pts.append(Vector2(xx, y0 + sin(xx * 0.22 + t * 9.0) * 2.4))
					draw_polyline(pts, Color(1.0, 0.85, 0.45, 0.95), 2.5, true)
		if ghost > 0.02:
			for gk in [2.0, 1.0]:
				var gc := Color(text_col, 0.13 * ghost * (1.5 - gk * 0.5))
				var go: Vector2 = ghost_off * float(gk) * ghost
				for g in toks:
					var wk0: int = g["weak"]
					if wk0 >= 0 and wk0 == hidden_weak:
						continue
					draw_string(font, Vector2(float(g["x"]), float(g["y"]) + base_off) + go, str(g["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, gc)
		for g in toks:
			var wk: int = g["weak"]
			if wk >= 0 and wk == hidden_weak:
				continue
			var p := Vector2(float(g["x"]), float(g["y"]) + base_off)
			if wk >= 0 and wk == crack_weak and crack_k < 1.0:
				p += Vector2(randf_range(-2.0, 2.0), randf_range(-1.5, 1.5)) * (1.0 - crack_k)
			draw_string_outline(font, p + shadow_off, str(g["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, outline_px, shadow_col)
		for g in toks:
			var wk: int = g["weak"]
			if wk >= 0 and wk == hidden_weak:
				continue
			var col := text_col
			if wk >= 0 and show_weak:
				col = weak_col.lerp(Color(1.0, 0.97, 0.85), 0.22 * pulse + (0.5 if wk == hot_weak else 0.0))
				if wk == crack_weak:
					col = col.lerp(Color.WHITE, 0.6)
			if dim > 0.0:
				col = col.lerp(Color(0.45, 0.42, 0.55), dim)
			var p := Vector2(float(g["x"]), float(g["y"]) + base_off)
			draw_string_outline(font, p, str(g["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, outline_px, outline_col)
			draw_string(font, p, str(g["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		if crack_weak >= 0 and crack_k > 0.0:
			for pl in _cracks:
				var pp: PackedVector2Array = pl
				var segs := pp.size() - 1
				var reach := crack_k * float(segs)
				for s in segs:
					if float(s) >= reach:
						break
					var a := pp[s]
					var b := pp[s + 1]
					if float(s) + 1.0 > reach:
						b = a.lerp(b, reach - float(s))
					draw_line(a, b, Color(0.027, 0.016, 0.06, 0.9), 6.0)
					draw_line(a, b, Color(0.9, 1.0, 1.0, 1.0), 2.5)
		draw_set_transform_matrix(Transform2D.IDENTITY)
