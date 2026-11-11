extends Control
## CutsceneBase - scaffolding for clock-driven cutscenes, for new scenes only (drain_screen.gd keeps its own copy).
##
## One timeline clock (_t) advanced in _process fires the events scheduled with _at(); they start keyframes in a
## tiny animator (_anim) and every other motion is computed per frame. No awaits, so nothing can resume after the
## screen is freed. Hit-stops freeze the clock itself. Autotest finishes after about 0.3 s. Hold Space / Enter / mouse
## for a second to skip. The pause menu (Esc) freezes clock, music and SFX.
##
## A scene overrides these:
##   _build_scene()         builds its world under _world and its cut-ins under _over
##   _schedule()            calls _at(time, callable) for every beat
##   _simulate(dt)          per-step simulation (also runs during the debug fast-forward)
##   _update_scene(delta)   per-frame visuals (camera, painters)
##   _debug_start_time()    seconds to fast-forward to, from a --xxx-t= flag (0 = from the start)
## Layers, bottom to top: _black, _shaker[_world, _over], _letterbox, _fxl, VHS (optional), _final, _wipe, _hint.
## Every asset may be missing; the scene then draws without it.

signal finished(result: Dictionary)

const Style := preload("res://scripts/ui/style.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Fx := preload("res://scripts/ui/fx.gd")
const TC := preload("res://scripts/trial/trial_common.gd")

const W := 1280.0
const H := 720.0
const C := Vector2(640, 360)
const INK := Color("07040f")
const PANEL_BG := Color(0.06, 0.035, 0.13, 0.95)
const HOLD_TO_SKIP := 1.0

## Hit-stop frame: the last frame turned into hard ink-and-paper negative.
const INVERT_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 ink = mix(vec3(0.02, 0.015, 0.05), vec3(0.9, 1.0, 0.98), step(0.22, l));
	COLOR = vec4(mix(vec3(1.0) - c, ink, 0.6), 1.0);
}
"""

## Worn videotape: tracking noise, colour bleed, grain, static, roll. Same look as the execution tapes.
const VHS_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float static_amt = 0.0;
uniform float tear = 0.0;
uniform float vroll = 0.0;
uniform float chroma = 2.0;
uniform float desat = 0.2;
uniform float grain = 0.07;
uniform float vignette = 0.7;
uniform float bright = 1.0;
uniform float tracking = 0.3;

float rnd(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 suv = SCREEN_UV;
	float t = TIME;
	float yy = fract(suv.y + vroll);
	float line = floor(yy * 240.0);
	float fr = floor(t * 30.0);
	float jit = (rnd(vec2(line, fr)) - 0.5) * tear * 0.06;
	jit += sin(yy * 9.0 + t * 23.0) * tear * 0.012;
	jit += sin(yy * 50.0 + t * 2.7) * 0.0006;
	float tb = smoothstep(0.90, 0.95, yy) * (1.0 - smoothstep(0.975, 1.0, yy));
	float roll = fract(t * 0.045);
	float rb = 1.0 - smoothstep(0.0, 0.03, abs(yy - roll));
	float band = clamp(tb + rb * 0.6, 0.0, 1.0) * tracking;
	jit += (rnd(vec2(line * 1.7, fr + 3.0)) - 0.5) * band * 0.03;
	vec2 uv = vec2(suv.x + jit, yy);
	float off = chroma * SCREEN_PIXEL_SIZE.x * (1.0 + tear * 4.0);
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(off, 0.0)).r * 0.6 + texture(screen_tex, uv + vec2(off * 2.0, 0.0)).r * 0.4;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(off, 0.0)).b * 0.6 + texture(screen_tex, uv - vec2(off * 2.0, 0.0)).b * 0.4;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c, vec3(l), desat);
	g = pow(max(g, vec3(0.0)), vec3(1.08)) * bright;
	g *= 1.0 - 0.07 * (0.5 + 0.5 * sin((suv.y + t * 0.11) * 6.2831));
	g *= 1.0 - 0.10 * (0.5 + 0.5 * sin(suv.y * 720.0 * 3.14159));
	float st = step(0.86, rnd(vec2(floor(uv.x * 160.0), line + fr))) * band;
	g = mix(g, vec3(0.8), st * 0.6);
	float n = rnd(floor(suv * vec2(640.0, 360.0)) + vec2(fract(t * 7.0) * 91.0, fract(t * 3.0) * 57.0));
	g += (n - 0.5) * grain;
	float n2 = rnd(floor(suv * vec2(320.0, 240.0)) + vec2(fr * 1.31, fr * 0.77));
	g = mix(g, vec3(n2 * 0.95), clamp(static_amt, 0.0, 1.0));
	vec2 d = suv - 0.5;
	float v = 1.0 - smoothstep(0.32, 0.95, length(d * vec2(1.0, 1.15)) * 1.25);
	g *= mix(1.0, v, vignette);
	COLOR = vec4(g, 1.0);
}
"""

# ------------------------------------------------------------------ clock / animator
var _t := 0.0
var _ev_time := 0.0
var _events: Array = []
var _ev_i := 0
var _anims: Array = []
var _done := false
var _ff := false
var _end_at := 1.0
var _skip_after := 2.0
var _hold := 0.0
var _freeze_left := 0.0
var _invert_left := 0.0
var _params: Dictionary = {}
var _music_id := ""
var _rng := RandomNumberGenerator.new()

# screen state, animated through _anim(self, "...")
var _shake := 0.0
var _rumble := 0.0
var _lb := 0.0
var _wipe_cover := 0.0

var _fx_static := 0.0
var _fx_tear := 0.0
var _fx_chroma := 2.0
var _fx_desat := 0.2
var _fx_grain := 0.07
var _fx_tracking := 0.3
var _fx_vignette := 0.7
var _fx_bright := 1.0
var _fx_vroll := 0.0

var _parts: Dictionary = {}
var _soft: Texture2D
var _add_mat: CanvasItemMaterial
var _font: Font

# nodes
var _black: ColorRect
var _shaker: Control
var _world: Control
var _over: Control
var _fxl: Control
var _final: TextureRect
var _wipe: ColorRect
var _invert: ColorRect
var _invert_bb: BackBufferCopy
var _letterbox: CPainter
var _hint: Control
var _hint_fill: TC.Slant
var _vhs: ColorRect
var _vhs_mat: ShaderMaterial
var _vhs_bb: BackBufferCopy
var _painters: Array = []


# ================================================================== contract
func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = Style.display_font()
	_soft = _make_soft()
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_build_frame()
	_build_scene()
	_schedule()
	_sort_events()
	if Game.autotest:
		_events = _events.filter(func(e: Array) -> bool: return float(e[0]) < 0.3)
		_end_at = 0.3
	var start := _debug_start_time()
	if start > 0.0:
		_fast_forward(start)
	_update_visuals(0.0)
	set_process(true)


## Runs the timeline silently up to `start` (debug flags).
func _fast_forward(start: float) -> void:
	_ff = true
	while _t < start:
		_step(minf(1.0 / 30.0, start - _t))
	_ff = false
	if _music_id != "":
		Audio.play_music(_music_id, 0.2)


# ================================================================== for the scene to override
func _build_scene() -> void:
	pass


func _schedule() -> void:
	pass


func _simulate(_dt: float) -> void:
	pass


func _update_scene(_delta: float) -> void:
	pass


func _debug_start_time() -> float:
	return 0.0


# ================================================================== helpers
func _make_soft() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _ctrl(parent: Node) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _node(parent: Node, pos: Vector2 = Vector2.ZERO, sc: float = 1.0) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	n.scale = Vector2(sc, sc)
	parent.add_child(n)
	return n


func _spr(parent: Node, tex: Texture2D, pos: Vector2 = Vector2.ZERO, centered: bool = false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = centered
	s.position = pos
	parent.add_child(s)
	return s


func _painter(parent: Node, fn: Callable, additive: bool = false) -> Painter:
	var p := Painter.new()
	p.fn = fn
	if additive:
		p.material = _add_mat
	parent.add_child(p)
	_painters.append(p)
	return p


func _slant(sz: Vector2, fill: Color, border: Color, bw: float = 3.0, skew: float = 16.0, cut: float = 0.0,
		stripes: int = 0, shadow: Color = Color(INK, 0.92), shadow_off: Vector2 = Vector2(7, 7)) -> TC.Slant:
	var s := TC.Slant.new()
	s.fill = fill
	s.border = border
	s.border_w = bw
	s.skew_px = skew
	s.cut = cut
	s.stripes = stripes
	s.stripe_col = Color(border, 0.22)
	s.shadow = shadow
	s.shadow_off = shadow_off
	s.size = sz
	s.refresh()
	return s


func _title_lbl(text: String, fs: int, col: Color, outline: Color = INK, osz: int = 12,
		shadow_off: Vector2 = Vector2(6, 7), shadow_col: Color = INK) -> Label:
	var l := Style.title_label(text, fs, col, outline, osz)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shadow_col.a > 0.0:
		l.add_theme_color_override("font_shadow_color", shadow_col)
		l.add_theme_constant_override("shadow_offset_x", int(shadow_off.x))
		l.add_theme_constant_override("shadow_offset_y", int(shadow_off.y))
		l.add_theme_constant_override("shadow_outline_size", maxi(1, osz))
	return l


func _fit(text: String, fs: int, min_fs: int, max_w: float) -> int:
	while fs > min_fs and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 2
	return fs


func _sfx(id: String, pitch: float = 1.0, vol: float = 0.0) -> void:
	# never during the debug fast-forward, nor late (an event that fired long after its time)
	if _ff or _t - _ev_time > 0.3:
		return
	Audio.sfx(id, pitch, vol)


func _music(id: String, fade: float = 1.0) -> void:
	_music_id = id
	if not _ff:
		Audio.play_music(id, fade)


func _fx_ok() -> bool:
	return not _ff and not _done


func _flash(col: Color, alpha: float, dur: float) -> void:
	if _fx_ok():
		Fx.flash(_fxl, col, dur, alpha)


func _glitch(dur: float, amt: float = 1.0) -> void:
	if _fx_ok():
		Fx.glitch(_fxl, dur, amt)


func _speed(center: Vector2, dur: float = 0.45, col: Color = Color(1, 1, 1, 0.4), count: int = 40, inner: float = 240.0) -> void:
	if _fx_ok():
		Fx.speed_lines(_fxl, center, dur, col, count, inner)


## Tapered slash of light across the screen.
func _blade(a: Vector2, b: Vector2, col: Color = Color(Style.GOLD, 0.9), thick: float = 12.0) -> void:
	if not _fx_ok():
		return
	var bl := TC.Blade.new()
	bl.a = a
	bl.b = b
	bl.col = col
	bl.thick = thick
	bl.size = Vector2(W, H)
	_fxl.add_child(bl)
	var tw := bl.create_tween()
	tw.tween_property(bl, "k", 1.0, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(bl, "fade", 0.0, 0.28)
	tw.tween_callback(bl.queue_free)


func _kick(s: float) -> void:
	_shake = maxf(_shake, s)


## Hit-stop: the whole timeline freezes for `dur` real seconds (flashes still fade).
func _hitstop(dur: float, invert: float = 0.0) -> void:
	if _ff:
		return
	_freeze_left = dur
	_shaker.process_mode = Node.PROCESS_MODE_DISABLED
	if invert > 0.0 and DisplayServer.get_name() != "headless":
		_invert_left = invert
		_invert.visible = true
		_invert_bb.visible = true


# ================================================================== frame
func _build_frame() -> void:
	_black = ColorRect.new()
	_black.color = INK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_shaker = _ctrl(self)
	_world = _ctrl(_shaker)
	_over = _ctrl(_shaker)
	_letterbox = CPainter.new()
	_letterbox.fn = _draw_letterbox
	_letterbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_letterbox)
	_fxl = _ctrl(self)
	_invert_bb = BackBufferCopy.new()
	_invert_bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_invert_bb.visible = false
	add_child(_invert_bb)
	_invert = ColorRect.new()
	_invert.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_invert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = INVERT_SHADER
	var im := ShaderMaterial.new()
	im.shader = sh
	_invert.material = im
	_invert.visible = false
	add_child(_invert)
	_vhs_bb = BackBufferCopy.new()
	_vhs_bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_vhs_bb.visible = false
	add_child(_vhs_bb)
	_vhs = ColorRect.new()
	_vhs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vhs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := Shader.new()
	vs.code = VHS_SHADER
	_vhs_mat = ShaderMaterial.new()
	_vhs_mat.shader = vs
	_vhs.material = _vhs_mat
	_vhs.visible = false
	add_child(_vhs)
	_final = TextureRect.new()
	_final.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_final.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_final.stretch_mode = TextureRect.STRETCH_SCALE
	_final.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final.visible = false
	add_child(_final)
	_wipe = Fx.wipe_overlay(self)
	_build_hint()


## Turns the worn-tape look on or off. The tape sits above everything but the wipe and the skip hint.
func _set_vhs(on: bool) -> void:
	var enable := on and DisplayServer.get_name() != "headless"
	_vhs.visible = enable
	_vhs_bb.visible = enable


func _build_hint() -> void:
	_hint = Control.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.position = Vector2(1006, 672)
	_hint.size = Vector2(250, 30)
	_hint.modulate.a = 0.0
	add_child(_hint)
	var plate := _slant(Vector2(250, 30), Color(0.04, 0.025, 0.09, 0.9), Style.AQUA_DEEP, 2.0, 12.0, 0.0, 0, Color(INK, 0.9), Vector2(4, 4))
	_hint.add_child(plate)
	_hint_fill = _slant(Vector2(0, 30), Color(Style.AQUA, 0.35), Color(0, 0, 0, 0), 0.0, 12.0, 0.0, 0, Color(0, 0, 0, 0))
	_hint.add_child(_hint_fill)
	var l := Style.label("HOLD  SPACE  TO SKIP", 14, Style.TEXT, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(250, 30)
	_hint.add_child(l)


## Slanted HUD badge: a small colored tab on top of a striped plate with a gold title (+ optional subline).
func _badge(root: Control, tab: String, col: Color, title: String, sub: String, pos: Vector2) -> void:
	var fs := _fit(title, 34, 20, 380.0)
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var plate_h := 58.0 if sub == "" else 82.0
	var plate := _slant(Vector2(tw + 92.0, plate_h), PANEL_BG, col, 3.0, 18.0, 10.0, 3, Color(INK, 0.95), Vector2(7, 7))
	plate.stripe_col = Color(col, 0.3)
	plate.refresh()
	plate.position = pos + Vector2(0, 22)
	root.add_child(plate)
	var tl := _title_lbl(title, fs, Style.GOLD, Style.BG_DARK, 8, Vector2(3, 4), Color(col.darkened(0.45), 1.0))
	tl.position = Vector2(24, 7)
	plate.add_child(tl)
	if sub != "":
		var sl := Style.label(sub, 17, Style.TEXT_DIM, true)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sl.position = Vector2(30, 50)
		plate.add_child(sl)
	var ttw := _font.get_string_size(tab, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var tg := _slant(Vector2(ttw + 34.0, 26), col, Color(0, 0, 0, 0), 0.0, 10.0, 0.0, 0, Color(INK, 0.9), Vector2(4, 4))
	tg.position = pos + Vector2(14, 0)
	root.add_child(tg)
	var tl2 := Style.label(tab, 15, Style.BG_DARK, true)
	tl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl2.position = Vector2(17, 2)
	tg.add_child(tl2)


func _name_tag(id: String, text: String, fs: int) -> TC.Slant:
	var col := Cast.color(id) if Cast.exists(id) else Style.AQUA
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tag := _slant(Vector2(tw + 44.0, fs + 14.0), col, Color.WHITE, 3.0, 12.0, 8.0, 0, Color(INK, 0.95), Vector2(6, 6))
	var l := Style.title_label(text, fs, Color.WHITE, INK, 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(22, 4)
	tag.add_child(l)
	return tag


# ================================================================== scheduling / animator
func _at(time: float, c: Callable) -> void:
	_events.append([time, _events.size(), c])


func _sort_events() -> void:
	_events.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))


## Schedules an extra event relative to now (used inside events).
func _at_late(dt: float, c: Callable) -> void:
	var t := _ev_time + dt
	var idx := _ev_i
	while idx < _events.size() and float(_events[idx][0]) <= t:
		idx += 1
	_events.insert(idx, [t, 9000 + idx, c])


func _fire_events() -> void:
	while _ev_i < _events.size() and float(_events[_ev_i][0]) <= _t:
		_ev_time = float(_events[_ev_i][0])
		var c: Callable = _events[_ev_i][2]
		_ev_i += 1
		if not _done:
			c.call()


## Keyframe a property (a script var, or "node_prop:sub") from -> to over dur, starting at the event time.
func _anim(obj: Object, prop: String, from: Variant, to: Variant, dur: float, ease: int = 1, delay: float = 0.0) -> void:
	_kill(obj, prop)
	_anims.append([obj, prop, from, to, _ev_time + delay, dur, ease])
	if delay <= 0.0:
		_set_prop(obj, prop, from)


## A follow-up keyframe of the same property (does not cancel the running one).
func _anim_then(obj: Object, prop: String, from: Variant, to: Variant, dur: float, ease: int, delay: float) -> void:
	_anims.append([obj, prop, from, to, _ev_time + delay, dur, ease])


func _kill(obj: Object, prop: String) -> void:
	var keep: Array = []
	for a in _anims:
		if not (a[0] == obj and a[1] == prop):
			keep.append(a)
	_anims = keep


func _put(prop: String, v: Variant) -> void:
	_kill(self, prop)
	set(prop, v)


func _set_prop(obj: Object, prop: String, v: Variant) -> void:
	if prop.contains(":"):
		obj.set_indexed(NodePath(prop), v)
	else:
		obj.set(prop, v)


## 0 linear, 1 sine in-out, 2 cubic out, 3 cubic in, 4 expo out, 5 back out, 6 expo in
func _ease(k: float, e: int) -> float:
	match e:
		0:
			return k
		2:
			return 1.0 - pow(1.0 - k, 3.0)
		3:
			return k * k * k
		4:
			return 1.0 if k >= 1.0 else 1.0 - pow(2.0, -10.0 * k)
		5:
			var c1 := 1.9
			return 1.0 + (c1 + 1.0) * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)
		6:
			return 0.0 if k <= 0.0 else pow(2.0, 10.0 * k - 10.0)
		_:
			return 0.5 - 0.5 * cos(PI * k)


func _update_anims() -> void:
	var keep: Array = []
	for a in _anims:
		if not is_instance_valid(a[0]):
			continue   # its node was freed (a scene removed it); checked before any typed use of a[0]
		var obj: Object = a[0]
		var t0: float = a[4]
		var dur: float = a[5]
		if _t < t0:
			keep.append(a)
			continue
		var k := 1.0 if dur <= 0.0 else clampf((_t - t0) / dur, 0.0, 1.0)
		_set_prop(obj, a[1], lerp(a[2], a[3], _ease(k, a[6])))
		if k < 1.0:
			keep.append(a)
	_anims = keep


# ================================================================== particles
func _emit(space: String, p: Vector2, v: Vector2, life: float, s: float, c: Color, k: int, g: float = 0.0,
		drag: float = 0.0, grow: float = 0.0) -> void:
	if not _parts.has(space):
		_parts[space] = []
	var arr: Array = _parts[space]
	if arr.size() > 700:
		return
	arr.append({"p": p, "v": v, "life": life, "max": life, "s": s, "c": c, "k": k, "g": g, "drag": drag, "grow": grow,
		"r": _rng.randf() * TAU})


func _sim_parts(dt: float) -> void:
	for key in _parts:
		var arr: Array = _parts[key]
		var i := arr.size() - 1
		while i >= 0:
			var p: Dictionary = arr[i]
			var life: float = float(p["life"]) - dt
			if life <= 0.0:
				arr.remove_at(i)
			else:
				p["life"] = life
				var v: Vector2 = p["v"]
				v.y += float(p["g"]) * dt
				v *= 1.0 - minf(1.0, float(p["drag"]) * dt)
				p["v"] = v
				p["p"] = (p["p"] as Vector2) + v * dt
				p["s"] = float(p["s"]) + float(p["grow"]) * dt
				p["r"] = float(p["r"]) + dt * 7.0
			i -= 1


## Kinds: 0 droplet, 1 soft puff, 3 debris chip, 4 paper confetti, anything else a fading dot.
func _draw_parts(ci: CanvasItem, space: String) -> void:
	var arr: Array = _parts.get(space, [])
	for p in arr:
		var d: Dictionary = p
		var pos: Vector2 = d["p"]
		var col: Color = d["c"]
		var lk := float(d["life"]) / maxf(float(d["max"]), 0.001)
		var s: float = d["s"]
		match int(d["k"]):
			0:
				var a := col.a * clampf(lk * 2.0, 0.0, 1.0)
				var v: Vector2 = d["v"]
				if v.length() > 40.0:
					var dn := v.normalized()
					var pn := Vector2(-dn.y, dn.x) * s * 0.92
					ci.draw_colored_polygon(PackedVector2Array([pos + pn, pos - dn * s * (2.0 + minf(v.length() / 300.0, 2.0)), pos - pn]), Color(col, a))
				ci.draw_circle(pos, s, Color(col, a))
				ci.draw_circle(pos + Vector2(-s * 0.3, -s * 0.35), s * 0.32, Color(1, 1, 1, a * 0.8))
			1:
				var fade := minf(1.0, (1.0 - lk) * 6.0) * lk
				ci.draw_texture_rect(_soft, Rect2(pos - Vector2(s, s * 0.8), Vector2(s * 2.0, s * 1.6)), false, Color(col, col.a * fade))
			3:
				var a2 := clampf(lk * 3.0, 0.0, 1.0)
				ci.draw_circle(pos, s, Color(col, a2))
				ci.draw_circle(pos + Vector2(-s * 0.3, -s * 0.3), s * 0.3, Color(0.8, 0.7, 0.6, 0.5 * a2))
			4:
				var a3 := clampf(lk * 3.0, 0.0, 1.0)
				var ang: float = d["r"]
				var flip := absf(cos(ang * 0.8)) * 0.8 + 0.2
				var ax := Vector2(cos(ang), sin(ang)) * s
				var ay := Vector2(-sin(ang), cos(ang)) * s * 0.6 * flip
				ci.draw_colored_polygon(PackedVector2Array([pos - ax - ay, pos + ax - ay, pos + ax + ay, pos - ax + ay]), Color(col, a3))
			_:
				ci.draw_circle(pos, s, Color(col, col.a * lk))


# ================================================================== frame loop
func _process(delta: float) -> void:
	if _done:
		return
	if _freeze_left > 0.0:
		_freeze_left -= delta
		if _invert_left > 0.0:
			_invert_left -= delta
			if _invert_left <= 0.0:
				_invert.visible = false
				_invert_bb.visible = false
		if _freeze_left <= 0.0:
			_freeze_left = 0.0
			_invert.visible = false
			_invert_bb.visible = false
			_shaker.process_mode = Node.PROCESS_MODE_INHERIT
		_update_skip(delta)
		return
	_step(delta)
	if not _done:
		if _t >= _end_at:
			_finish(false)
		_update_skip(delta)
	if not _done:
		_update_visuals(delta)


## One timeline step: clock, events, keyframes and the simulations (also used by the debug fast-forward).
func _step(dt: float) -> void:
	_t += dt
	_fire_events()
	_update_anims()
	_sim_parts(dt)
	_simulate(dt)


func _update_visuals(delta: float) -> void:
	var sh := Vector2.ZERO
	var rum := _rumble
	if _shake > 0.05 or rum > 0.05:
		sh = Vector2(randf_range(-1, 1), randf_range(-0.6, 0.6)) * _shake + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * rum
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 9.0))
	_shaker.position = sh
	_update_scene(delta)
	var live: Array = []
	for p in _painters:
		if not is_instance_valid(p):
			continue   # freed with the element it drew
		live.append(p)
		var pn: Painter = p
		if pn.is_visible_in_tree():
			pn.queue_redraw()
	_painters = live
	_letterbox.queue_redraw()
	if _vhs.visible:
		_vhs_mat.set_shader_parameter("static_amt", clampf(_fx_static, 0.0, 1.0))
		_vhs_mat.set_shader_parameter("tear", _fx_tear)
		_vhs_mat.set_shader_parameter("vroll", _fx_vroll)
		_vhs_mat.set_shader_parameter("chroma", _fx_chroma)
		_vhs_mat.set_shader_parameter("desat", _fx_desat)
		_vhs_mat.set_shader_parameter("grain", _fx_grain)
		_vhs_mat.set_shader_parameter("tracking", _fx_tracking)
		_vhs_mat.set_shader_parameter("vignette", _fx_vignette)
		_vhs_mat.set_shader_parameter("bright", _fx_bright)
	var strength := clampf(1.0 - absf(_wipe_cover - 1.0), 0.0, 1.0) * 0.9 + 0.1
	Fx.set_wipe(_wipe, _wipe_cover, strength)


## Layers are [node, parallax, base scale, anchor]; the root sits at the screen centre.
func _apply_cam(root: Node2D, layers: Array, c: Vector2, z: float, roll: float) -> void:
	root.position = C
	root.rotation = roll
	for L in layers:
		var n: Node2D = L[0]
		var par: float = L[1]
		var base: float = L[2]
		var anchor: Vector2 = L[3]
		var s := base * (1.0 + (z - 1.0) * par)
		n.scale = Vector2(s, s)
		n.position = -s * anchor - (c - C) * par * z


func _draw_letterbox(ci: Control) -> void:
	if _lb <= 0.01:
		return
	var tb := 44.0 * _lb
	var bb := 44.0 * _lb
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, tb - 12.0 * _lb), Vector2(0, tb)]), INK)
	ci.draw_line(Vector2(0, tb + 5.0), Vector2(W, tb - 12.0 * _lb + 5.0), Color(Style.AQUA, 0.7 * _lb), 2.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, H - bb + 12.0 * _lb), Vector2(W, H - bb), Vector2(W, H), Vector2(0, H)]), INK)
	ci.draw_line(Vector2(0, H - bb + 12.0 * _lb - 5.0), Vector2(W, H - bb - 5.0), Color(Style.YUZU, 0.75 * _lb), 2.0)


# ================================================================== skip / finish
func _update_skip(delta: float) -> void:
	if _done:
		return
	if _t < _skip_after:
		_hint.modulate.a = 0.0
		return
	var held := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if held:
		_hold += delta
	else:
		_hold = maxf(0.0, _hold - delta * 2.0)
	var target := 1.0 if _hold > 0.0 else 0.55
	_hint.modulate.a = move_toward(_hint.modulate.a, target, delta * 2.0)
	var k := clampf(_hold / HOLD_TO_SKIP, 0.0, 1.0)
	_hint_fill.size = Vector2(250.0 * k, 30)
	_hint_fill.visible = k > 0.02
	if _hold >= HOLD_TO_SKIP:
		_finish(true)


func _finish(skipped: bool) -> void:
	if _done:
		return
	_done = true
	_set_audio_paused(false)
	if skipped:
		Audio.stop_all_sfx()
		Audio.sfx("static", 1.2, -10.0)
	_hint.visible = false
	finished.emit({})


## Pause menu: freeze the music and the long SFX in place too (the Audio autoload always processes).
func _set_audio_paused(on: bool) -> void:
	Audio.set_music_paused(on)
	var pool: Variant = Audio.get("_sfx_pool")
	if pool is Array:
		for p in pool:
			if p is AudioStreamPlayer:
				(p as AudioStreamPlayer).stream_paused = on


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			_set_audio_paused(true)
		NOTIFICATION_UNPAUSED, NOTIFICATION_EXIT_TREE:
			_set_audio_paused(false)


# ================================================================== painter nodes
class Painter extends Node2D:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


class CPainter extends Control:
	var fn: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)
