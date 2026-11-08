extends Control
## "PULL THE PLUG" - the Chapter 2 lake-drain cutscene (docs/DESIGN2.md section 8), flow step `drain`.
## ~41 s in the trial's movement + effect language: slanted cut-in panels with hard ink shadows, diagonal
## static wipes, radial speed lines, shake + hit-stop, punchy zooms and slanted title badges.
##   A  0.0  the Lower Lake: static wipe in, black still lake, lantern reflections, slow push-in
##   B  4.75 Snapjaw shout cut-in "Time to PULL THE PLUG!" (exits through a screen shatter)
##   C  7.75 split-panel extreme close-up: his eye + his claw on the plug chain; YANK -> hit-stop, "GLUG!"
##   D 12.15 top view: the plug bursts out, the whirlpool spins up and drains; survivors' shock cut-ins
##   E 22.8  low angle at the waterline: the Mudlark rises out of the water (stacks, steam, horn, wheel, mud)
##   F 30.5  title badge "THE MUDLARK" / "your new home, sweet home!"
##   G 34.2  wide shot of the ship on the mud flats, lanterns flicker on one by one
##   end 40.2 diagonal static wipe to bg `ship_dock` (falls back to the last frame), finished({})
## Clock-driven like execution_screen.gd: one timeline clock (_t) advanced in _process fires the events
## scheduled in _schedule(); they start keyframes in a tiny animator and every other motion is computed per
## frame. No awaits, so nothing can resume after the screen is freed. Hit-stops freeze the clock itself.
## Hold Space / Enter / mouse for 1 s (after 2 s) to skip. The pause menu (Esc) freezes clock, music and SFX.
## Autotest: finishes after ~0.3 s. Debug: --drain-t=<seconds> starts the timeline at that time.
## Art: art/props/dr_*.svg (tools/gen_drain_art.py), SFX: audio/sfx/dr_*.wav (tools/gen_drain_audio.py).
## Every asset may be missing - the scene then draws without it.

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
const END_TIME := 41.3
const SKIP_AFTER := 2.0
const HOLD_TO_SKIP := 1.0
const WATER := [Color("3ee0d0"), Color("bff8ff"), Color("ffffff"), Color("6fd6ff")]
const SNAP_GREEN := Color("43a047")

# ------------------------------------------------------------------ shared with tools/gen_drain_art.py (svg px)
# dr_ship / dr_ship_over canvas is 1200x770 (the drawing sits SHIP_DY = 110 px lower than its inner coords)
const KEEL := 750.0
const DECK_MAIN := 630.0
const DECK_PROM := 540.0
const DECK_TEX := 450.0
const STACK_X := [467.0, 546.0]
const STACK_TOP := 44.0
const WHISTLE := Vector2(506, 132)
const WHEEL_C := Vector2(1040, 630)
const PLAQUE_BOW := Rect2(130, 646, 210, 32)
const PLAQUE_ARCH := Rect2(985, 478, 110, 24)
const PULLEY := Vector2(690, 100)          # dr_pulley's chain exit (sprite origin = PULLEY - (70, 100))
const SHORE_Y := 330.0
const HOLE := Vector2(690, 612)
const CHAIN_WATER := Vector2(690, 560)     # where the hanging plug chain enters the full lake (A)
# dr_dock: the jetty (same footprint as art/bg/ship_dock.svg); its lake-side face (0,520)-(412,490) down to (412,556)/(0,640)
const DOCK_FACE := [Vector2(0, 520), Vector2(412, 490), Vector2(412, 556), Vector2(0, 640)]
const PLUG_RING := Vector2(120, 22)
const GRIP_TOP := Vector2(260, 26)
const LANTERNS := [Vector2(100.3, 412.2), Vector2(176.9, 409.4), Vector2(253.5, 392.0), Vector2(330.1, 359.8),
	Vector2(406.7, 313.0), Vector2(584.2, 307.6), Vector2(616.5, 340.0), Vector2(648.8, 352.9), Vector2(691.7, 373.4),
	Vector2(745.1, 406.6), Vector2(798.5, 427.0), Vector2(851.9, 434.6), Vector2(905.3, 429.4), Vector2(190.0, 568.0),
	Vector2(280.0, 568.0), Vector2(370.0, 568.0), Vector2(460.0, 568.0), Vector2(550.0, 568.0), Vector2(640.0, 568.0),
	Vector2(730.0, 568.0), Vector2(820.0, 568.0)]
const LANTERN_COLS := [Color("ff5a3c"), Color("ff9a3c"), Color("ffd25a")]
# festoon posts of the back wall in dr_cave (the lanterns between them are reflected in the lake)
const FESTOON := [Vector2(232, 232), Vector2(470, 252), Vector2(700, 244), Vector2(935, 250), Vector2(1100, 232)]
const FUNGUS_SHORE := [Vector2(130, 318), Vector2(560, 300), Vector2(760, 300), Vector2(1000, 294), Vector2(1160, 336)]

# ------------------------------------------------------------------ composition
# G ends exactly on art/bg/ship_dock.svg: bow tip (355,393), hull base y 474, stern x 835, stacks x 577/618
const SHIP_G_POS := Vector2(334.2, 84.0)
const SHIP_G_SCALE := 0.5206
const PLUG_G_POS := Vector2(500, 606)      # the yanked plug lying on the mud in G (ship_dock: ~(500,614))
const CHAIN_G_END := Vector2(410, 546)     # ...its chain trailing to the jetty
const POOL_C := Vector2(640, 400)          # plug hole in the top view (D)
const POOL_TILT := 0.42
const RISE_SHIP := Vector2(8, -5)          # ship origin in the low-angle shot (E), plus _ship_yoff
const RISE_BASE := 0.95
const CASCADES := [
	# [x, y_top, y_bottom, width]  (ship svg px) - water pouring off the decks as they surface
	[300.0, 461.0, 540.0, 12.0], [640.0, 461.0, 540.0, 14.0], [790.0, 461.0, 540.0, 11.0], [640.0, 376.0, 450.0, 9.0],
	[112.0, 553.0, 630.0, 16.0], [262.0, 553.0, 630.0, 13.0], [424.0, 553.0, 630.0, 15.0], [606.0, 553.0, 630.0, 12.0],
	[764.0, 553.0, 630.0, 16.0], [892.0, 553.0, 630.0, 12.0],
	[92.0, 637.0, 810.0, 18.0], [244.0, 637.0, 810.0, 14.0], [404.0, 637.0, 810.0, 17.0], [566.0, 637.0, 810.0, 13.0],
	[722.0, 637.0, 810.0, 18.0], [884.0, 637.0, 810.0, 15.0],
]

const WHIRL_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 center = vec2(900.0, 640.0);
uniform float tilt = 0.42;
uniform float level = 1400.0;
uniform float hole = 46.0;
uniform float spin = 0.0;
uniform float swirl = 0.0;
uniform float time = 0.0;
varying vec2 vpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vpos = VERTEX;
}

void fragment() {
	vec2 d = vpos - center;
	d.y /= tilt;
	float r = length(d);
	float a = atan(d.y, d.x);
	vec3 col;
	if (r > level) {
		float n = vnoise(d * 0.012) * 0.6 + vnoise(d * 0.05) * 0.4;
		vec3 mud = mix(vec3(0.12, 0.085, 0.075), vec3(0.22, 0.155, 0.12), step(0.52, n));
		float rings = sin(r * 0.08 + n * 3.0);
		mud = mix(mud, mud * 0.62, step(0.86, rings) * 0.7);
		float pud = step(0.76, vnoise(d * 0.007 + 3.0));
		mud = mix(mud, vec3(0.05, 0.16, 0.2) + vec3(0.1, 0.3, 0.3) * step(0.9, vnoise(d * 0.05 + 9.0)), pud);
		float wet = 1.0 - smoothstep(level, level + 160.0, r);
		mud = mix(mud, vec3(0.14, 0.27, 0.3), wet * 0.5 * step(0.45, vnoise(d * 0.03 + 7.0)));
		col = mud;
		col = mix(col, vec3(0.82, 0.98, 1.0), (1.0 - smoothstep(0.0, 9.0, r - level)) * 0.85);
	} else {
		float k = clamp((r - hole) / max(level - hole, 1.0), 0.0, 1.0);
		float w = spin * (0.3 + 2.4 * pow(1.0 - k, 2.0));
		float tw = swirl * 7.5;
		float lr = log(max(r, 1.0));
		float s = sin(a * 5.0 + lr * tw - w + vnoise(d * 0.008) * 1.6);
		float s2 = sin(a * 9.0 + lr * tw * 1.25 - w * 1.35 + 1.7 + vnoise(d * 0.02) * 1.2);
		vec3 deep = vec3(0.012, 0.03, 0.065);
		vec3 mid = vec3(0.03, 0.115, 0.16);
		vec3 hi = vec3(0.1, 0.42, 0.46);
		col = mix(deep, mid, step(0.3, s) * (0.35 + 0.65 * swirl));
		col = mix(col, hi, step(0.8, s) * swirl);
		float foam = step(0.92, s2) * swirl * smoothstep(0.04, 0.35, k);
		col = mix(col, vec3(0.78, 0.98, 1.0), foam * 0.9);
		float fun = 1.0 - smoothstep(0.0, 0.32, k);
		col = mix(col, vec3(0.0, 0.0, 0.02), fun * swirl * 0.8);
		float lip = 1.0 - smoothstep(0.0, 0.035, abs(k - 0.1));
		col = mix(col, vec3(0.55, 0.98, 0.94), lip * swirl * 0.65);
		float sh = smoothstep(0.955, 1.0, k);
		col = mix(col, vec3(0.86, 1.0, 1.0), sh * (0.35 + 0.45 * step(0.5, vnoise(vec2(a * 24.0, time * 3.0)))));
		float still = 1.0 - swirl;
		float refl = step(0.985, sin(d.y * 0.05 + sin(d.x * 0.01 + time * 0.8) * 2.5)) * 0.2 * still;
		col += vec3(0.15, 0.55, 0.55) * refl * (1.0 - fun);
	}
	if (r < hole) {
		col = vec3(0.0, 0.0, 0.012) + vec3(0.06, 0.24, 0.24) * step(0.88, sin(a * 3.0 - spin * 3.5)) * swirl;
	}
	COLOR = vec4(col, 1.0);
}
"""

## Mud/wet wash on the ship sprites: strongest at the waterline (sprite-local y), fading upward.
const MUD_SHADER := """
shader_type canvas_item;
uniform float wl = 5000.0;
uniform float band = 190.0;
uniform vec4 mud : source_color = vec4(0.24, 0.17, 0.12, 1.0);
uniform float amount = 0.85;
uniform float wet = 1.0;
varying float vy;
void vertex() {
	vy = VERTEX.y;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float k = clamp(1.0 - (wl - vy) / band, 0.0, 1.0);
	k = k * k * amount;
	vec3 m = mix(c.rgb * 0.5, mud.rgb, 0.6);
	c.rgb = mix(c.rgb, m, k);
	c.rgb += vec3(0.2, 0.42, 0.46) * wet * k * step(0.9, fract(UV.x * 41.0 + vy * 0.013)) * 0.45;
	COLOR = c;
}
"""

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

# ------------------------------------------------------------------ clock / animator
var _t := 0.0
var _ev_time := 0.0
var _events: Array = []
var _ev_i := 0
var _anims: Array = []
var _done := false
var _ff := false
var _end_at := END_TIME
var _hold := 0.0
var _freeze_left := 0.0
var _invert_left := 0.0
var _params: Dictionary = {}
var _music_id := ""
var _rng := RandomNumberGenerator.new()

# camera (applied to the active shot)
var _shot := "black"
var _cam_c := C
var _cam_z := 1.0
var _cam_roll := 0.0
var _punch_k := 0.0
var _punch_at := C
var _shake := 0.0
var _rumble := 0.0

# cave shots (A, G)
var _lake := 1.0
var _drained := false
var _lit_n := 0
var _lit_t: Array = []
var _windows := 0.0
var _bubbles_t := -100.0
var _drift_k := 1.0
# pool shot (D)
var _pool_level := 1500.0
var _pool_swirl := 0.0
var _pool_spin := 0.0
var _pool_spin_v := 0.0
var _plug_k := -1.0            # -1: plug sits in the hole; 0..1 flying out; 2: gone
var _plug_t0 := -100.0
var _focus_k := 0.0
var _debris: Array = []
var _foam: Array = []
# rise shot (E)
var _wl := 120.0
var _ship_yoff := 160.0
var _wheel_v := 0.0
var _wheel_ang := 0.0
var _casc_t: Array = []
var _steam_rate := 0.0
var _jet_until := -1.0
var _emit_acc := 0.0
# overlays
var _wipe_cover := 1.0
var _lb := 0.0
var _glint := 0.0
var _ecu_pull := 0.0
var _ecu_lines := 0.0

# particles per coordinate space: Array of Dictionary
var _parts := {"cave": [], "pool": [], "rise": [], "ship": []}

# textures
var _tx := {}
var _soft: Texture2D
var _add_mat: CanvasItemMaterial
var _font: Font

# nodes
var _shaker: Control
var _world: Control
var _over: Control
var _fxl: Control
var _black: ColorRect
var _final: TextureRect
var _wipe: ColorRect
var _invert: ColorRect
var _invert_bb: BackBufferCopy
var _letterbox: CPainter
var _hint: Control
var _hint_fill: TC.Slant
var _painters: Array = []

var _cave_root: Node2D
var _cave_layers: Array = []
var _g_ship: Node2D
var _g_wheel: Sprite2D
var _g_plug: Sprite2D
var _pulley: Sprite2D
var _front: Node2D
var _cave_lake: Painter
var _dock_water: Painter

var _pool_root: Node2D
var _pool_rect: ColorRect
var _pool_mat: ShaderMaterial
var _pool_plug: Sprite2D

var _rise_root: Node2D
var _rise_layers: Array = []
var _r_ship: Node2D
var _r_ship_spr: Sprite2D
var _r_wheel: Sprite2D
var _r_over: Sprite2D
var _r_mud_mats: Array = []

var _g_mud_mats: Array = []

# overlay roots / parts
var _loc: Control
var _area: Control
var _sh: Dictionary = {}
var _ecu: Dictionary = {}
var _glug: Dictionary = {}
var _reacts: Array = []
var _title: Dictionary = {}


# ================================================================== contract
func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 2611
	_font = Style.display_font()
	_soft = _make_soft()
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for n in ["dr_cave", "dr_mud", "dr_dock", "dr_front", "dr_ship", "dr_ship_over", "dr_wheel", "dr_plug", "dr_grip", "dr_pulley"]:
		_tx[n] = Assets.prop(n)
	_build()
	_schedule()
	if Game.autotest:
		_events = _events.filter(func(e: Array) -> bool: return float(e[0]) < 0.3)
		_end_at = 0.3
	var start := _debug_start_time()
	if start > 0.0:
		_ff = true
		while _t < start:
			_step(minf(1.0 / 30.0, start - _t))
		_ff = false
		if _music_id != "":
			Audio.play_music(_music_id, 0.2)
	_update_visuals(0.0)
	set_process(true)


func _debug_start_time() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--drain-t="):
			return clampf(float(a.get_slice("=", 1)), 0.0, END_TIME - 0.6)
	return 0.0


# ================================================================== helpers
func _tex(n: String) -> Texture2D:
	return _tx.get(n, null)


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


# ================================================================== building
func _build() -> void:
	_black = ColorRect.new()
	_black.color = INK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_shaker = _ctrl(self)
	_world = _ctrl(_shaker)
	_build_cave()
	_build_pool()
	_build_rise()
	_over = _ctrl(_shaker)
	_build_loc()
	_build_shout()
	_build_ecu()
	_build_glug()
	_build_reacts()
	_build_title()
	_build_area()
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
	_final = TextureRect.new()
	_final.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_final.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_final.stretch_mode = TextureRect.STRETCH_SCALE
	_final.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final.visible = false
	add_child(_final)
	_wipe = Fx.wipe_overlay(self)
	Fx.set_wipe(_wipe, 1.0, 1.0)
	_build_hint()
	_show_shot("black")


# ------------------------------------------------------------------ A / G: the cavern
func _build_cave() -> void:
	_cave_root = _node(_world)
	var l_cave := _node(_cave_root)
	if _tex("dr_cave"):
		_spr(l_cave, _tex("dr_cave"))
	else:
		_painter(l_cave, func(ci: Node2D) -> void: ci.draw_rect(Rect2(0, 0, W, H), Color("0c0a1c")))
	_painter(l_cave, _draw_cave_glow, true)
	_pulley = _spr(l_cave, _tex("dr_pulley"), PULLEY - Vector2(70, 100))
	var l_mud := _node(_cave_root)
	if _tex("dr_mud"):
		_spr(l_mud, _tex("dr_mud"))
	else:
		_painter(l_mud, func(ci: Node2D) -> void: ci.draw_rect(Rect2(0, SHORE_Y, W, H - SHORE_Y), Color("2a1f1c")))
	var l_ship := _node(_cave_root)
	_g_ship = _node(l_ship, SHIP_G_POS, SHIP_G_SCALE)
	var ss := _spr(_g_ship, _tex("dr_ship"))
	_g_wheel = _spr(_g_ship, _tex("dr_wheel"), WHEEL_C, true)
	var so := _spr(_g_ship, _tex("dr_ship_over"))
	for s in [ss, so]:
		var m := _mud_mat(KEEL + 10.0, 170.0, 0.75)
		(s as Sprite2D).material = m
		_g_mud_mats.append(m)
	_g_wheel.modulate = Color(0.8, 0.72, 0.66)
	_painter(_g_ship, _draw_ship_text)
	_painter(_g_ship, _draw_ship_lights, true)
	_painter(_g_ship, _draw_ship_lights_core)
	_painter(_g_ship, func(ci: Node2D) -> void: _draw_parts(ci, "ship"))
	_cave_lake = _painter(l_ship, _draw_lake)
	_painter(l_ship, _draw_chain_cave)
	_g_plug = _spr(l_ship, _tex("dr_plug"), PLUG_G_POS, false)
	_g_plug.offset = Vector2(-120, -130)
	_g_plug.scale = Vector2(0.5, 0.36)
	_g_plug.rotation = 0.12
	var l_steam := _node(_cave_root)
	_painter(l_steam, func(ci: Node2D) -> void: _draw_parts(ci, "cave"))
	var l_dock := _node(_cave_root)
	if _tex("dr_dock"):
		_spr(l_dock, _tex("dr_dock"))
	_dock_water = _painter(l_dock, _draw_dock_water)
	_painter(l_dock, _draw_gangway)
	var l_front := _node(_cave_root)
	_front = l_front
	if _tex("dr_front"):
		_spr(l_front, _tex("dr_front"))
	# [node, parallax, base scale, anchor] - base 1.0 so G ends exactly in screen space (= ship_dock)
	_cave_layers = [[l_cave, 0.6, 1.0, C], [l_mud, 0.6, 1.0, C], [l_ship, 0.6, 1.0, C], [l_steam, 0.6, 1.0, C],
		[l_dock, 1.0, 1.0, C], [l_front, 1.35, 1.06, C]]


func _mud_mat(wl: float, band: float, amount: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = MUD_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("wl", wl)
	m.set_shader_parameter("band", band)
	m.set_shader_parameter("amount", amount)
	return m


# ------------------------------------------------------------------ D: the whirlpool (top view)
func _build_pool() -> void:
	_pool_root = _node(_world)
	var l := _node(_pool_root)
	_pool_rect = ColorRect.new()
	_pool_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pool_rect.position = Vector2(-460, -480)
	_pool_rect.size = Vector2(W + 920, H + 960)
	var sh := Shader.new()
	sh.code = WHIRL_SHADER
	_pool_mat = ShaderMaterial.new()
	_pool_mat.shader = sh
	_pool_mat.set_shader_parameter("center", POOL_C - _pool_rect.position)
	_pool_mat.set_shader_parameter("tilt", POOL_TILT)
	_pool_rect.material = _pool_mat
	l.add_child(_pool_rect)
	_painter(l, _draw_pool_debris)
	_painter(l, _draw_pool_column)
	_pool_plug = _spr(l, _tex("dr_plug"), POOL_C, false)
	_pool_plug.offset = Vector2(-120, -130)
	_painter(l, _draw_pool_chain)
	_painter(l, func(ci: Node2D) -> void: _draw_parts(ci, "pool"))
	_painter(l, _draw_pool_focus)
	# debris: yuzu, rubber ducks, a bucket, swirling in
	for i in 16:
		var kind := 0 if i < 10 else (1 if i < 14 else 2)
		_debris.append({"r": _rng.randf_range(260.0, 980.0), "a": _rng.randf() * TAU, "k": kind, "s": _rng.randf_range(0.8, 1.25),
			"spin": _rng.randf_range(-3.0, 3.0), "rot": _rng.randf() * TAU, "gone": false})
	for i in 70:
		_foam.append(Vector3(_rng.randf_range(120.0, 1100.0), _rng.randf() * TAU, _rng.randf_range(0.6, 1.4)))


# ------------------------------------------------------------------ E: the ship rises (low angle)
func _build_rise() -> void:
	_rise_root = _node(_world)
	var l_bg := _node(_rise_root)
	if _tex("dr_cave"):
		_spr(l_bg, _tex("dr_cave"))
	_painter(l_bg, _draw_rise_sky_glow, true)
	var l_ship := _node(_rise_root)
	_r_ship = _node(l_ship, RISE_SHIP)
	_r_ship_spr = _spr(_r_ship, _tex("dr_ship"))
	_r_wheel = _spr(_r_ship, _tex("dr_wheel"), WHEEL_C, true)
	_r_over = _spr(_r_ship, _tex("dr_ship_over"))
	for s in [_r_ship_spr, _r_over]:
		var m := _mud_mat(-100.0, 210.0, 0.95)
		(s as Sprite2D).material = m
		_r_mud_mats.append(m)
	_painter(_r_ship, _draw_ship_text)
	_painter(_r_ship, _draw_cascades)
	_painter(_r_ship, func(ci: Node2D) -> void: _draw_parts(ci, "ship"))
	var l_water := _node(_rise_root)
	_painter(l_water, _draw_rise_water)
	_painter(l_water, func(ci: Node2D) -> void: _draw_parts(ci, "rise"))
	_rise_layers = [[l_bg, 0.25, 1.8, Vector2(640, 240)], [l_ship, 1.0, RISE_BASE, C], [l_water, 1.0, RISE_BASE, C]]
	_casc_t.resize(CASCADES.size())
	_casc_t.fill(-100.0)


func _show_shot(s: String) -> void:
	_shot = s
	_cave_root.visible = s == "cave"
	_pool_root.visible = s == "pool"
	_rise_root.visible = s == "rise"
	_g_ship.visible = _drained
	_g_plug.visible = _drained
	_pulley.visible = not _drained
	_front.visible = not _drained
	_cave_lake.visible = not _drained
	_dock_water.visible = not _drained


# ------------------------------------------------------------------ overlays
func _build_loc() -> void:
	_loc = _ctrl(_over)
	_loc.visible = false
	_badge(_loc, "SUBLEVEL B3", Style.AQUA, "THE LOWER LAKE", "", Vector2(34, 74))


func _build_area() -> void:
	_area = _ctrl(_over)
	_area.visible = false
	_badge(_area, "NEW AREA", Style.YUZU, "THE MUDLARK", "Lower Lake Dock", Vector2(34, 74))


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


func _build_shout() -> void:
	var root := _ctrl(_over)
	root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var foc := TC.Focus.new()
	foc.size = Vector2(W, H)
	foc.c = Vector2(820, 340)
	foc.col = Color(1, 1, 1, 0.28)
	foc.r_in = 330.0
	foc.k = 1.0
	root.add_child(foc)
	var grp := _ctrl(root)
	grp.pivot_offset = C
	grp.rotation = deg_to_rad(-9.0)
	var band := _ctrl(grp)
	var bs := _slant(Vector2(W + 700, 256), Color(0.04, 0.02, 0.09, 0.97), SNAP_GREEN, 5.0, 64.0, 0.0, 0,
		Color(SNAP_GREEN.darkened(0.25), 0.95), Vector2(0, 18))
	bs.position = Vector2(-350, 232)
	band.add_child(bs)
	var st := TC.Streaks.new()
	st.position = Vector2(-250, 252)
	st.size = Vector2(W + 500, 216)
	st.col = Color(1, 1, 1, 0.09)
	st.spd = 3200.0
	st.dir = -1.0
	st.n = 18
	band.add_child(st)
	for i in 4:
		var sp := _slant(Vector2(16, 196), Color(Style.GOLD, 0.8), Color(0, 0, 0, 0), 0.0, 50.0, 0.0, 0, Color(0, 0, 0, 0))
		sp.position = Vector2(W - 150 + i * 30, 262)
		band.add_child(sp)
	var small := _title_lbl("TIME TO...", 40, Color.WHITE, INK, 10, Vector2(4, 5))
	small.position = Vector2(560, 262)
	band.add_child(small)
	var fs := _fit("PULL THE PLUG!", 96, 40, 820.0)
	var tl2 := _title_lbl("PULL THE PLUG!", fs, SNAP_GREEN, SNAP_GREEN.darkened(0.35), 18, Vector2.ZERO, Color(0, 0, 0, 0))
	var tl := _title_lbl("PULL THE PLUG!", fs, Style.GOLD, INK, 18, Vector2.ZERO, Color(0, 0, 0, 0))
	for l in [tl2, tl]:
		var lb: Label = l
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.size = Vector2(860, 130)
		lb.pivot_offset = Vector2(430, 65)
		band.add_child(lb)
	tl.position = Vector2(400, 300)
	tl2.position = tl.position + Vector2(9, 9)
	# portrait window
	var cut := _ctrl(root)
	var win := Rect2(34, 104, 380, 440)
	var win_pts := Style.slant_poly(win, 74.0)
	var frame_poly: Array = Geometry2D.offset_polygon(win_pts, 8.0, Geometry2D.JOIN_MITER)
	var fr := Style.Shape.new()
	if frame_poly.size() > 0:
		fr.points = frame_poly[0]
	fr.fill = SNAP_GREEN
	fr.outline = INK
	fr.outline_w = 3.0
	fr.shadow = Color(INK, 0.95)
	fr.shadow_off = Vector2(12, 12)
	fr.size = Vector2(W, H)
	cut.add_child(fr)
	var wbg := Style.Shape.new()
	wbg.points = win_pts
	wbg.fill = SNAP_GREEN.darkened(0.55)
	wbg.size = Vector2(W, H)
	cut.add_child(wbg)
	var wst := TC.Streaks.new()
	wst.position = Vector2(70, 120)
	wst.size = Vector2(320, 400)
	wst.col = Color(SNAP_GREEN.lightened(0.4), 0.22)
	wst.n = 10
	cut.add_child(wst)
	var por := TC.CutPortrait.new()
	por.texture = Assets.portrait("snapjaw", "happy")
	por.position = win.position
	por.size = win.size
	por.uv_rect = Rect2(30.0 / 480.0, 28.0 / 600.0, 420.0 / 480.0, 486.0 / 600.0)
	var lp := PackedVector2Array()
	for p in win_pts:
		lp.append(p - win.position)
	por.frame = lp
	por.edge_col = Color(Style.GOLD, 0.9)
	por.wipe = 0.0
	cut.add_child(por)
	var tag := _name_tag("snapjaw", "WARDEN SNAPJAW", 24)
	tag.position = Vector2(60, 536)
	cut.add_child(tag)
	var snap := _title_lbl("Snap-snap-snap!", 34, Style.DANGER, INK, 10, Vector2(4, 5))
	snap.position = Vector2(860, 520)
	snap.pivot_offset = snap.get_minimum_size() * 0.5
	snap.rotation = deg_to_rad(-8.0)
	snap.modulate.a = 0.0
	root.add_child(snap)
	_sh = {"root": root, "dim": dim, "band": band, "cut": cut, "tl": tl, "tl2": tl2, "small": small, "por": por,
		"snap": snap, "foc": foc}


func _name_tag(id: String, text: String, fs: int) -> TC.Slant:
	var col := Cast.color(id) if Cast.exists(id) else Style.AQUA
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tag := _slant(Vector2(tw + 44.0, fs + 14.0), col, Color.WHITE, 3.0, 12.0, 8.0, 0, Color(INK, 0.95), Vector2(6, 6))
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Style.BG_DARK if col.get_luminance() > 0.45 else Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = tag.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(l)
	tag.pivot_offset = tag.size * 0.5
	return tag


func _build_ecu() -> void:
	var root := _ctrl(_over)
	root.visible = false
	var bg := CPainter.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.fn = func(ci: Control) -> void:
		ci.draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.05, 0.05))
		ci.draw_texture_rect(_soft, Rect2(-200, -300, 1680, 1320), false, Color(0.15, 0.4, 0.2, 0.35))
	root.add_child(bg)
	var foc := TC.Focus.new()
	foc.size = Vector2(W, H)
	foc.c = Vector2(640, 380)
	foc.col = Color(1, 1, 1, 0.16)
	foc.r_in = 220.0
	foc.k = 1.0
	root.add_child(foc)
	# panel 1: the eye (extreme close-up of the portrait)
	var p1 := _ctrl(root)
	p1.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p1.size = Vector2(900, 300)
	p1.position = Vector2(-40, 44)
	var f1 := _slant(Vector2(900, 300), SNAP_GREEN.darkened(0.6), Color.WHITE, 5.0, 110.0, 0.0, 4, Color(INK, 0.95), Vector2(12, 12))
	f1.stripe_col = Color(SNAP_GREEN.lightened(0.2), 0.3)
	f1.refresh()
	p1.add_child(f1)
	var eye := TC.CutPortrait.new()
	eye.texture = Assets.portrait("snapjaw", "happy")
	eye.size = Vector2(900, 300)
	eye.uv_rect = Rect2(30.0 / 480.0, 58.0 / 600.0, 420.0 / 480.0, 140.0 / 600.0)
	var e_off: Array = Geometry2D.offset_polygon(Style.slant_poly(Rect2(0, 0, 900, 300), 110.0), -7.0, Geometry2D.JOIN_MITER)
	if e_off.size() > 0:
		eye.frame = e_off[0]
	eye.edge_col = Color(Style.GOLD, 0.9)
	p1.add_child(eye)
	var gl := CPainter.new()
	gl.size = Vector2(900, 300)
	gl.fn = _draw_eye_glint
	gl.material = _add_mat
	p1.add_child(gl)
	# panel 2: the claw on the plug chain handle (rect-clipped; slanted border drawn on top)
	var p2 := _ctrl(root)
	p2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p2.size = Vector2(880, 360)
	p2.position = Vector2(440, 338)
	var f2s := _slant(Vector2(880, 360), Color(0.05, 0.03, 0.1, 1.0), Color(0, 0, 0, 0), 0.0, 110.0, 0.0, 0, Color(INK, 0.95), Vector2(12, 12))
	p2.add_child(f2s)
	var clip := Control.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	clip.size = Vector2(880, 360)
	p2.add_child(clip)
	var inner := CPainter.new()
	inner.size = Vector2(880, 360)
	inner.fn = _draw_ecu_chain
	clip.add_child(inner)
	var grip := TextureRect.new()
	grip.texture = _tex("dr_grip")
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grip.stretch_mode = TextureRect.STRETCH_SCALE
	grip.size = Vector2(520, 440) * 0.75
	grip.position = Vector2(300, 60)
	clip.add_child(grip)
	var f2 := _slant(Vector2(880, 360), Color(0, 0, 0, 0), Color.WHITE, 5.0, 110.0, 0.0, 0, Color(0, 0, 0, 0))
	p2.add_child(f2)
	var sliver := _slant(Vector2(1500, 12), Style.YUZU, Color(0, 0, 0, 0), 0.0, 8.0, 0.0, 0, Color(INK, 0.9), Vector2(0, 5))
	sliver.position = Vector2(-120, 318)
	sliver.pivot_offset = Vector2(750, 6)
	sliver.rotation = deg_to_rad(-1.5)
	root.add_child(sliver)
	var whisper := _title_lbl("...snap.", 30, Color(1, 1, 1, 0.9), INK, 8, Vector2(3, 4))
	whisper.position = Vector2(120, 392)
	whisper.modulate.a = 0.0
	root.add_child(whisper)
	var yank := _title_lbl("YANK!!", 64, Style.DANGER, INK, 14, Vector2(6, 7))
	yank.position = Vector2(90, 500)
	yank.pivot_offset = yank.get_minimum_size() * 0.5
	yank.rotation = deg_to_rad(-10.0)
	yank.modulate.a = 0.0
	root.add_child(yank)
	_ecu = {"root": root, "p1": p1, "p2": p2, "eye": eye, "grip": grip, "inner": inner, "sliver": sliver, "foc": foc,
		"whisper": whisper, "yank": yank, "gl": gl, "pull": 0.0, "lines": 0.0, "jit": 0.0}


func _build_glug() -> void:
	var root := _ctrl(_over)
	root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var foc := TC.Focus.new()
	foc.size = Vector2(W, H)
	foc.c = C
	foc.col = Color(1, 1, 1, 0.4)
	foc.r_in = 260.0
	foc.k = 1.0
	root.add_child(foc)
	var rig := _ctrl(root)
	rig.pivot_offset = C
	rig.rotation = deg_to_rad(-10.0)
	var plate := _slant(Vector2(760, 236), Color(0.05, 0.02, 0.12, 0.97), Style.AQUA, 6.0, 70.0, 0.0, 5,
		Color(Style.AQUA_DEEP, 0.95), Vector2(14, 16))
	plate.stripe_col = Color(Style.AQUA, 0.25)
	plate.refresh()
	plate.position = Vector2(260, 242)
	plate.pivot_offset = Vector2(380, 118)
	rig.add_child(plate)
	var sliver := _slant(Vector2(1100, 14), Style.YUZU, Color(0, 0, 0, 0), 0.0, 10.0, 0.0, 0, Color(INK, 0.9), Vector2(0, 6))
	sliver.position = Vector2(90, 492)
	sliver.pivot_offset = Vector2(550, 7)
	rig.add_child(sliver)
	var echo := _title_lbl("GLUG!", 190, Color(Style.AQUA, 0.5), Color(0, 0, 0, 0), 0, Vector2.ZERO, Color(0, 0, 0, 0))
	var tl := _title_lbl("GLUG!", 190, Style.GOLD, INK, 24, Vector2(10, 12), Style.AQUA_DEEP)
	for l in [echo, tl]:
		var lb: Label = l
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.size = Vector2(900, 260)
		lb.position = Vector2(190, 226)
		lb.pivot_offset = lb.size * 0.5
		rig.add_child(lb)
	_glug = {"root": root, "rig": rig, "plate": plate, "tl": tl, "echo": echo, "sliver": sliver, "foc": foc}


func _build_reacts() -> void:
	var defs := [
		["lulu", "Lulu-lu?! The LAKE!", Vector2(40, 62), -1.0, false],
		["bruno", "Bruno does not like this!", Vector2(820, 90), 1.0, false],
		["pepper", "Scoop of the CENTURY!", Vector2(60, 410), -1.0, true],
		["reginald", "I say! Stand back, all!", Vector2(800, 436), 1.0, true],
	]
	for d in defs:
		var id: String = d[0]
		var line: String = d[1]
		var pos: Vector2 = d[2]
		var side: float = d[3]
		var line_above: bool = d[4]
		var col := Cast.color(id)
		var root := _ctrl(_over)
		root.visible = false
		var box := _ctrl(root)
		box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		box.size = Vector2(420, 200)
		box.position = pos
		var sz := Vector2(420, 200)
		var skew := 60.0
		var fr := _slant(sz, col.darkened(0.55), Color.WHITE, 5.0, skew, 0.0, 3, Color(INK, 0.95), Vector2(10, 10))
		fr.stripe_col = Color(col.lightened(0.3), 0.3)
		fr.refresh()
		box.add_child(fr)
		var st := TC.Streaks.new()
		st.position = Vector2(skew * 0.5, 12)
		st.size = Vector2(sz.x - skew, sz.y - 24)
		st.col = Color(col.lightened(0.4), 0.28)
		st.dir = -side
		st.n = 12
		box.add_child(st)
		var por := TC.CutPortrait.new()
		por.texture = Assets.portrait(id, "shock")
		por.size = sz
		por.uv_rect = Rect2(40.0 / 480.0, 122.0 / 600.0, 400.0 / 480.0, 190.0 / 600.0)
		var off: Array = Geometry2D.offset_polygon(Style.slant_poly(Rect2(Vector2.ZERO, sz), skew), -7.0, Geometry2D.JOIN_MITER)
		if off.size() > 0:
			por.frame = off[0]
		por.edge_col = Color(Style.GOLD, 0.95)
		por.wipe_dir = -side
		por.wipe = 0.0
		box.add_child(por)
		var tag := _name_tag(id, Cast.display_name(id), 22)
		tag.position = Vector2(8 if side < 0.0 else sz.x - tag.size.x - 30, sz.y - 22)
		box.add_child(tag)
		var fs := _fit(line, 27, 18, 400.0)
		var lbl := _title_lbl(line, fs, Color.WHITE, INK, 9, Vector2(4, 5), Color(col.darkened(0.4), 1.0))
		var lw := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
		# the line sits on the side opposite the name tag (above the bottom panels, below the top ones)
		lbl.position = Vector2(sz.x - lw - 30.0 if side < 0.0 else 40.0, -44.0 if line_above else sz.y + 14.0)
		lbl.pivot_offset = lbl.get_minimum_size() * 0.5
		lbl.rotation = deg_to_rad(-4.0)
		lbl.modulate.a = 0.0
		box.add_child(lbl)
		var bang := _title_lbl("!?", 64, Style.YUZU, INK, 14, Vector2(5, 6))
		bang.position = Vector2(sz.x - 70 if side < 0.0 else 4, 20)
		bang.pivot_offset = bang.get_minimum_size() * 0.5
		bang.rotation = deg_to_rad(12.0 * side)
		bang.modulate.a = 0.0
		box.add_child(bang)
		_reacts.append({"id": id, "root": root, "box": box, "por": por, "lbl": lbl, "bang": bang, "side": side, "x": pos.x,
			"ly": lbl.position.y})


func _build_title() -> void:
	var root := _ctrl(_over)
	root.visible = false
	var dimr := ColorRect.new()
	dimr.color = Color(INK, 0.5)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dimr)
	var rig := _ctrl(root)
	rig.pivot_offset = C
	rig.rotation = deg_to_rad(-7.0)
	var accent := Style.AQUA
	var bw := 1900.0
	var x0 := -310.0
	var sl_top := _slant(Vector2(bw, 10), Style.YUZU, Color(0, 0, 0, 0), 0.0, 6.0, 0.0, 0, Color(0, 0, 0, 0))
	sl_top.position = Vector2(x0, 196)
	rig.add_child(sl_top)
	var sl_bot := _slant(Vector2(bw, 10), accent, Color(0, 0, 0, 0), 0.0, 6.0, 0.0, 0, Color(0, 0, 0, 0))
	sl_bot.position = Vector2(x0, 470)
	rig.add_child(sl_bot)
	var band_a := _slant(Vector2(bw, 168), Color(0.04, 0.02, 0.10, 0.97), accent, 5.0, 46.0, 0.0, 0, Color(accent.darkened(0.3), 0.85), Vector2(0, 12))
	band_a.position = Vector2(x0, 214)
	rig.add_child(band_a)
	var st := TC.Streaks.new()
	st.position = Vector2(0, 14)
	st.size = Vector2(bw, 140)
	st.col = Color(accent, 0.16)
	st.n = 16
	band_a.add_child(st)
	var fs := _fit("THE MUDLARK", 100, 44, 1060.0)
	var tl := _title_lbl("THE MUDLARK", fs, Style.GOLD, Style.BG_DARK, 16, Vector2(8, 8), Color(accent.darkened(0.25), 1.0))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.size = Vector2(W, 150)
	tl.position = Vector2(-x0, 8)
	tl.pivot_offset = tl.size * 0.5
	band_a.add_child(tl)
	var band_b := _slant(Vector2(bw, 64), accent, Color.WHITE, 3.0, 24.0, 0.0, 0, Color(INK, 0.9), Vector2(0, 8))
	band_b.position = Vector2(x0, 396)
	rig.add_child(band_b)
	var st2 := TC.Streaks.new()
	st2.position = Vector2(0, 6)
	st2.size = Vector2(bw, 52)
	st2.col = Color(1, 1, 1, 0.22)
	st2.dir = -1.0
	st2.n = 10
	band_b.add_child(st2)
	var sl := Style.label("your new home, sweet home!", 29, Style.BG_DARK, true)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sl.size = Vector2(W, 64)
	sl.position = Vector2(-x0, 0)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_b.add_child(sl)
	# Snapjaw's little sign-off tag on the subtitle band
	var tag := _name_tag("snapjaw", "- WARDEN SNAPJAW", 18)
	tag.position = Vector2(-x0 + 820, 70)
	band_b.add_child(tag)
	_title = {"root": root, "dim": dimr, "rig": rig, "a": band_a, "b": band_b, "st": sl_top, "sb": sl_bot, "tl": tl, "x0": x0, "bw": bw}


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


# ================================================================== scheduling / animator
func _at(time: float, c: Callable) -> void:
	_events.append([time, _events.size(), c])


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
		var obj: Object = a[0]
		if not is_instance_valid(obj):
			continue
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


# ================================================================== the timeline
func _schedule() -> void:
	# ---- A  the Lower Lake
	_at(0.0, _ev_open)
	_at(0.12, func() -> void: _anim(self, "_wipe_cover", 1.0, 2.0, 0.6, 1))
	_at(0.75, _ev_loc_in)
	_at(1.3, func() -> void: _sfx("dr_drip", 1.0, -2.0))
	_at(2.5, func() -> void: _sfx("dr_drip", 0.8, -4.0))
	_at(3.15, _ev_bubbles)
	_at(4.0, _ev_loc_out)
	# ---- B  Snapjaw
	_at(4.75, _ev_shout_in)
	_at(4.95, _ev_shout_hit)
	_at(5.9, _ev_shout_snap)
	_at(7.75, _ev_shout_out)
	# ---- C  extreme close-up: the chain
	_at(7.75, _ev_ecu_in)
	_at(8.7, _ev_ecu_creak)
	_at(9.45, _ev_ecu_eye)
	_at(10.15, _ev_ecu_yank)
	_at(10.3, _ev_glug)
	_at(11.85, _ev_glug_out)
	# ---- D  the whirlpool
	_at(12.15, _ev_pool_in)
	_at(12.4, _ev_plug_burst)
	_at(12.95, _ev_swirl)
	_at(14.2, _ev_react.bind(0))
	_at(15.4, _ev_react.bind(1))
	_at(16.6, _ev_react.bind(2))
	_at(17.8, _ev_react.bind(3))
	_at(15.0, func() -> void: _sfx("dr_roar", 1.0, -1.0))
	_at(19.6, _ev_react_out)
	_at(19.95, _ev_pool_push)
	_at(21.0, func() -> void: _sfx("dr_whirl", 0.85, 0.0))
	_at(22.45, func() -> void:
		_anim(self, "_wipe_cover", 0.0, 1.0, 0.35, 3)
		_sfx("static", 1.1, -10.0))
	# ---- E  the Mudlark rises
	_at(22.8, _ev_rise_in)
	_at(23.4, _ev_stacks_break)
	_at(24.3, _ev_stack_steam)
	_at(25.25, _ev_horn)
	_at(26.2, func() -> void: _sfx("dr_roar", 0.9, -4.0))
	_at(27.55, _ev_wheel_punch)
	_at(29.95, _ev_settle)
	# ---- F  title
	_at(30.5, _ev_title_in)
	_at(30.72, _ev_title_hit)
	_at(33.9, _ev_title_out)
	# ---- G  the new home
	_at(34.2, _ev_wide_in)
	_at(35.3, _ev_area_in)
	for i in LANTERNS.size():
		_at(35.0 + 0.155 * i, _ev_lantern.bind(i))
	_at(38.4, func() -> void:
		_anim(self, "_windows", 0.0, 1.0, 0.5, 2)
		_sfx("dr_lantern", 0.7, -4.0))
	_at(39.4, _ev_area_out)
	_at(39.5, func() -> void: _anim(self, "_lb", _lb, 0.0, 0.6, 1))
	_at(40.2, func() -> void:
		_anim(self, "_wipe_cover", 0.0, 1.0, 0.35, 3)
		_sfx("static", 1.2, -12.0))
	_at(40.55, _ev_final)
	_events.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))


# ------------------------------------------------------------------ A
func _ev_open() -> void:
	_drained = false
	_show_shot("cave")
	_put("_wipe_cover", 1.0)
	_anim(self, "_lb", 0.0, 1.0, 0.6, 2)
	_put("_cam_roll", 0.0)
	_anim(self, "_cam_c", C, Vector2(590, 388), 4.75, 1)
	_anim(self, "_cam_z", 1.0, 1.13, 4.75, 1)
	_music("tension", 0.8)


func _ev_loc_in() -> void:
	_loc.visible = true
	_anim(_loc, "position:x", -560.0, 0.0, 0.26, 4)
	_sfx("whoosh", 1.0, -6.0)


func _ev_loc_out() -> void:
	_anim(_loc, "position:x", 0.0, -600.0, 0.22, 6)


func _ev_bubbles() -> void:
	_bubbles_t = _ev_time
	_sfx("pop", 0.55, -6.0)
	_at_late(0.35, func() -> void: _sfx("pop", 0.45, -4.0))


## Schedules an extra event relative to now (used inside events).
func _at_late(dt: float, c: Callable) -> void:
	var t := _ev_time + dt
	var idx := _ev_i
	while idx < _events.size() and float(_events[idx][0]) <= t:
		idx += 1
	_events.insert(idx, [t, 9000 + idx, c])


# ------------------------------------------------------------------ B
func _ev_shout_in() -> void:
	var root: Control = _sh["root"]
	root.visible = true
	_anim(_sh["dim"], "modulate:a", 0.0, 1.0, 0.08, 0)
	_anim(_sh["band"], "position:x", W * 1.3, 0.0, 0.13, 4)
	_anim(_sh["cut"], "position:x", -560.0, 0.0, 0.2, 5, 0.03)
	_anim(_sh["por"], "wipe", 0.0, 1.0, 0.24, 4, 0.06)
	_anim(_sh["tl"], "scale", Vector2(2.7, 2.7), Vector2.ONE, 0.12, 4, 0.08)
	_anim(_sh["tl"], "modulate:a", 0.0, 1.0, 0.04, 0, 0.08)
	_anim(_sh["tl2"], "scale", Vector2(2.7, 2.7), Vector2.ONE, 0.12, 4, 0.11)
	_anim(_sh["tl2"], "modulate:a", 0.0, 1.0, 0.04, 0, 0.11)
	_anim(_sh["small"], "modulate:a", 0.0, 1.0, 0.1, 0, 0.02)
	(_sh["tl"] as Label).modulate.a = 0.0
	(_sh["tl2"] as Label).modulate.a = 0.0
	(_sh["por"] as TC.CutPortrait).wipe = 0.0
	(_sh["cut"] as Control).position.x = -560.0
	(_sh["small"] as Label).modulate.a = 0.0
	_sfx("shout", 0.9, 0.0)
	_music("snapjaw", 0.3)


func _ev_shout_hit() -> void:
	_kick(16.0)
	_flash(Color.WHITE, 0.6, 0.3)
	_speed(Vector2(820, 340), 0.45, Color(1, 1, 1, 0.45), 42, 280.0)
	_glitch(0.16, 0.9)
	_sfx("dr_chain", 1.2, -10.0)


func _ev_shout_snap() -> void:
	var s: Label = _sh["snap"]
	_anim(s, "modulate:a", 0.0, 1.0, 0.06, 0)
	_anim(s, "scale", Vector2(2.2, 2.2), Vector2.ONE, 0.16, 5)
	_anim(s, "position:y", 520.0, 500.0, 1.4, 2)
	_sfx("pop", 1.4, -6.0)


func _ev_shout_out() -> void:
	if _fx_ok() and not Fx.skip_heavy():
		Fx.shatter(_fxl, 0.55, Vector2(800, 350))
	_sfx("break", 1.15, -9.0)
	(_sh["root"] as Control).visible = false


# ------------------------------------------------------------------ C
func _ev_ecu_in() -> void:
	_show_shot("black")
	var root: Control = _ecu["root"]
	root.visible = true
	_anim(_ecu["p1"], "position:x", -1040.0, -40.0, 0.24, 4)
	_anim(_ecu["p2"], "position:x", W + 80.0, 440.0, 0.24, 4, 0.06)
	_anim(_ecu["sliver"], "scale:x", 0.0, 1.0, 0.2, 4, 0.1)
	_anim(self, "_lb", _lb, 0.0, 0.2, 2)
	(_ecu["p2"] as Control).position.x = W + 80.0
	(_ecu["sliver"] as Control).scale.x = 0.0
	_sfx("whoosh", 0.9, -4.0)
	_sfx("dr_chain", 0.8, -6.0)


func _ev_ecu_creak() -> void:
	_ecu["jit"] = 1.0
	_sfx("dr_creak", 0.8, -2.0)
	_sfx("dr_chain", 0.7, -8.0)
	var w: Label = _ecu["whisper"]
	_anim(w, "modulate:a", 0.0, 1.0, 0.2, 0)
	_anim(w, "position:x", 80.0, 110.0, 1.4, 2)


func _ev_ecu_eye() -> void:
	(_ecu["eye"] as TC.CutPortrait).texture = Assets.portrait("snapjaw", "angry")
	_anim(self, "_glint", 0.0, 1.0, 0.12, 4)
	_anim_then(self, "_glint", 1.0, 0.0, 0.5, 1, 0.12)
	_flash(Style.DANGER, 0.25, 0.25)
	_kick(5.0)
	_sfx("hx_sting", 1.3, -10.0)
	_anim(_ecu["whisper"], "position:x", 110.0, 140.0, 0.6, 2)
	_anim(_ecu["whisper"], "modulate:a", 1.0, 0.0, 0.2, 0, 0.4)


func _ev_ecu_yank() -> void:
	_ecu["jit"] = 0.0
	_anim(self, "_ecu_pull", 0.0, 1.0, 0.13, 6)
	_anim(self, "_ecu_lines", 0.0, 1.0, 0.08, 0)
	var y: Label = _ecu["yank"]
	_anim(y, "modulate:a", 0.0, 1.0, 0.04, 0)
	_anim(y, "scale", Vector2(2.4, 2.4), Vector2.ONE, 0.1, 4)
	_sfx("dr_yank", 1.0, 0.0)
	_kick(10.0)


func _ev_glug() -> void:
	var root: Control = _glug["root"]
	root.visible = true
	_anim(_glug["plate"], "scale", Vector2(0.0, 1.0), Vector2.ONE, 0.13, 4)
	_anim(_glug["sliver"], "scale:x", 0.0, 1.0, 0.16, 4, 0.04)
	_anim(_glug["tl"], "scale", Vector2(2.6, 2.6), Vector2.ONE, 0.16, 5, 0.05)
	_anim(_glug["tl"], "modulate:a", 0.0, 1.0, 0.05, 0, 0.05)
	_anim(_glug["echo"], "scale", Vector2.ONE, Vector2(1.7, 1.7), 0.45, 4, 0.2)
	_anim(_glug["echo"], "modulate:a", 1.0, 0.0, 0.45, 0, 0.2)
	(_glug["tl"] as Label).modulate.a = 0.0
	(_glug["echo"] as Label).modulate.a = 0.0
	(_glug["sliver"] as Control).scale.x = 0.0
	_hitstop(0.2, 0.09)
	_kick(24.0)
	_flash(Color.WHITE, 0.75, 0.35)
	_speed(C, 0.55, Color(1, 1, 1, 0.5), 46, 300.0)
	_glitch(0.22, 1.1)
	if _fx_ok():
		for k in 6:
			var p := Vector2(160 + k * 192, 360 - (k * 192 - 480) * 0.18 + _rng.randf_range(-70, 70))
			Fx.splash(_fxl, p, Style.AQUA, 12, 170.0, 0.6)
	_sfx("dr_glug", 1.0, 2.0)
	_sfx("boom", 0.8, -6.0)
	_music("trial_climax", 0.15)


func _ev_glug_out() -> void:
	_anim(_glug["rig"], "position:x", 0.0, W * 1.2, 0.22, 6)
	_anim(_glug["root"], "modulate:a", 1.0, 0.0, 0.22, 0)
	_anim(_ecu["p1"], "position:x", -40.0, -1100.0, 0.2, 6)
	_anim(_ecu["p2"], "position:x", 440.0, W + 120.0, 0.2, 6)
	_anim(_ecu["root"], "modulate:a", 1.0, 0.0, 0.25, 0, 0.05)
	_glitch(0.3, 1.0)
	_sfx("whoosh", 1.2, -4.0)


# ------------------------------------------------------------------ D
func _ev_pool_in() -> void:
	(_ecu["root"] as Control).visible = false
	(_glug["root"] as Control).visible = false
	_show_shot("pool")
	_put("_cam_c", POOL_C + Vector2(0, -40))
	_put("_cam_z", 1.3)
	_put("_cam_roll", 0.06)
	_anim(self, "_cam_c", POOL_C + Vector2(0, -40), POOL_C + Vector2(0, -10), 0.6, 2)
	_anim(self, "_lb", _lb, 1.0, 0.3, 2)
	_glitch(0.25, 1.0)
	_flash(Style.AQUA, 0.3, 0.3)


func _ev_plug_burst() -> void:
	_plug_k = 0.0
	_plug_t0 = _ev_time
	_anim(self, "_plug_k", 0.0, 1.0, 0.7, 2)
	_kick(18.0)
	_flash(Color("bff8ff"), 0.55, 0.3)
	_speed(POOL_C + Vector2(0, -60), 0.45, Color(1, 1, 1, 0.45), 40, 200.0)
	if _fx_ok():
		Fx.ripple(_fxl, _screen_of_pool(POOL_C), Color("bff8ff"), 380.0, 0.8, 3)
	for i in 70:
		var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
		var sp := _rng.randf_range(300.0, 1100.0)
		_emit("pool", POOL_C + Vector2(_rng.randf_range(-40, 40), -10), Vector2(cos(a) * sp * 0.6, sin(a) * sp),
			_rng.randf_range(0.6, 1.2), _rng.randf_range(4.0, 10.0), WATER[_rng.randi() % 4], 0, 1300.0, 0.6)
	_sfx("dr_burst", 1.0, 0.0)
	_sfx("dr_glug", 0.7, -6.0)


func _ev_swirl() -> void:
	_anim(self, "_pool_swirl", 0.0, 1.0, 2.6, 1)
	_anim(self, "_pool_spin_v", 0.0, 3.4, 5.0, 1)
	_anim(self, "_pool_level", 1500.0, 560.0, 9.8, 1)
	_anim(self, "_cam_z", 1.3, 1.0, 6.5, 1)
	_anim(self, "_cam_roll", 0.06, 0.32, 9.8, 1)
	_anim(self, "_rumble", 0.0, 3.5, 2.0, 1)
	_sfx("dr_rumble", 1.0, 0.0)
	_sfx("dr_whirl", 1.0, 0.0)
	_at_late(5.2, func() -> void: _sfx("dr_rumble", 0.9, -2.0))


func _ev_react(i: int) -> void:
	var r: Dictionary = _reacts[i]
	var root: Control = r["root"]
	root.visible = true
	var side: float = r["side"]
	var x: float = r["x"]
	_anim(r["box"], "position:x", x + side * 700.0, x, 0.2, 4)
	_anim(r["por"], "wipe", 0.0, 1.0, 0.24, 4, 0.05)
	_anim(r["bang"], "modulate:a", 0.0, 1.0, 0.05, 0, 0.18)
	_anim(r["bang"], "scale", Vector2(2.4, 2.4), Vector2.ONE, 0.16, 5, 0.18)
	_anim(r["lbl"], "modulate:a", 0.0, 1.0, 0.1, 0, 0.26)
	var ly: float = r["ly"]
	_anim(r["lbl"], "position:y", ly + 16.0, ly, 0.25, 4, 0.26)
	(r["por"] as TC.CutPortrait).wipe = 0.0
	(r["bang"] as Label).modulate.a = 0.0
	(r["lbl"] as Label).modulate.a = 0.0
	_at_late(0.2, func() -> void:
		_kick(9.0)
		_flash(Color.WHITE, 0.25, 0.16)
		_speed(Vector2(x + 220.0, (r["box"] as Control).position.y + 110.0), 0.35, Color(1, 1, 1, 0.3), 26, 140.0))
	_sfx("whoosh", 1.1 + i * 0.05, -5.0)
	_sfx("gasp", 0.95 + i * 0.08, -6.0)


func _ev_react_out() -> void:
	for r in _reacts:
		var side: float = r["side"]
		var x: float = r["x"]
		_anim(r["box"], "position:x", x, x + side * 760.0, 0.2, 6)
	if _fx_ok():
		var bl := TC.Blade.new()
		bl.a = Vector2(-40, 560)
		bl.b = Vector2(W + 40, 160)
		bl.col = Color(Style.GOLD, 0.9)
		bl.thick = 12.0
		bl.size = Vector2(W, H)
		_fxl.add_child(bl)
		var tw := bl.create_tween()
		tw.tween_property(bl, "k", 1.0, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(bl, "fade", 0.0, 0.28)
		tw.tween_callback(bl.queue_free)
	_glitch(0.22, 0.9)
	_sfx("whoosh", 1.3, -4.0)


func _ev_pool_push() -> void:
	_anim(self, "_cam_z", _cam_z, 1.55, 2.6, 3)
	_anim(self, "_cam_c", _cam_c, POOL_C, 2.0, 1)
	_anim(self, "_cam_roll", _cam_roll, 0.9, 2.8, 3)
	_anim(self, "_focus_k", 0.0, 1.0, 1.6, 1)
	_anim(self, "_rumble", _rumble, 6.0, 2.4, 3)


# ------------------------------------------------------------------ E
func _ev_rise_in() -> void:
	_show_shot("rise")
	_put("_rumble", 2.5)
	_put("_focus_k", 0.0)
	_anim(self, "_wipe_cover", 1.0, 2.0, 0.4, 2)
	_put("_cam_roll", -0.06)
	_anim(self, "_cam_roll", -0.06, -0.03, 7.0, 1)
	_anim(self, "_cam_c", Vector2(640, 250), Vector2(640, 380), 7.0, 1)
	_anim(self, "_cam_z", 1.18, 1.0, 7.0, 1)
	_anim(self, "_wl", 110.0, 300.0, 1.4, 0)
	_anim(self, "_ship_yoff", 170.0, 0.0, 7.2, 2)
	_at_late(1.4, func() -> void: _anim(self, "_wl", 300.0, 640.0, 4.0, 1))
	_at_late(5.4, func() -> void: _anim(self, "_wl", 640.0, 830.0, 2.2, 1))
	_anim(self, "_rumble", 2.5, 1.0, 6.0, 1)
	_sfx("dr_rumble", 1.1, -3.0)


func _ev_stacks_break() -> void:
	_kick(9.0)
	for sx in STACK_X:
		var x: float = sx
		var p := _r_ship.position + Vector2(x, 60.0)
		for i in 26:
			var a := _rng.randf_range(-PI * 0.9, -PI * 0.1)
			var sp := _rng.randf_range(200.0, 650.0)
			_emit("rise", Vector2(p.x + _rng.randf_range(-30, 30), _wl), Vector2(cos(a) * sp * 0.5, sin(a) * sp),
				_rng.randf_range(0.5, 1.0), _rng.randf_range(3.0, 8.0), WATER[_rng.randi() % 4], 0, 1200.0, 0.5)
	_sfx("dr_burst", 1.25, -5.0)
	_sfx("splash", 0.8, -2.0)


func _ev_stack_steam() -> void:
	_put("_steam_rate", 1.0)
	for sx in STACK_X:
		var x: float = sx
		for i in 18:
			_emit("rise", _r_ship.position + Vector2(x + _rng.randf_range(-14, 14), 70.0), Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-260, -120)),
				_rng.randf_range(1.4, 2.4), _rng.randf_range(30.0, 60.0), Color(1, 1, 1, 0.5), 1, -30.0, 0.8, 70.0)
	_kick(5.0)
	_sfx("dr_steam", 1.0, 0.0)


func _ev_horn() -> void:
	_jet_until = _ev_time + 1.8
	_kick(7.0)
	_anim(self, "_rumble", _rumble, 3.0, 0.2, 2)
	_at_late(0.4, func() -> void: _anim(self, "_rumble", _rumble, 1.0, 1.4, 1))
	_sfx("dr_horn", 1.0, 0.0)
	_flash(Color(1, 0.95, 0.8), 0.18, 0.4)


func _ev_wheel_punch() -> void:
	_punch_at = _r_ship.position + WHEEL_C
	_anim(self, "_punch_k", 0.0, 1.0, 0.16, 4)
	_anim_then(self, "_punch_k", 1.0, 0.0, 0.55, 1, 1.05)
	_anim(self, "_wheel_v", 0.0, 1.5, 1.2, 1)
	_at_late(0.05, func() -> void:
		_speed(Vector2(760, 400), 0.5, Color(1, 1, 1, 0.42), 40, 200.0)
		_flash(Color.WHITE, 0.3, 0.2)
		_kick(10.0))
	_glitch(0.12, 0.7)
	_sfx("whoosh", 0.8, -3.0)
	_sfx("dr_creak", 1.0, 0.0)


func _ev_settle() -> void:
	_kick(14.0)
	_anim(self, "_wheel_v", _wheel_v, 0.5, 1.5, 1)
	_anim(self, "_rumble", _rumble, 0.25, 0.8, 2)
	for i in 40:
		var x := _rng.randf_range(80.0, 1200.0)
		var a := _rng.randf_range(-PI * 0.85, -PI * 0.15)
		var sp := _rng.randf_range(150.0, 420.0)
		_emit("rise", Vector2(x, 740.0), Vector2(cos(a) * sp * 0.5, sin(a) * sp), _rng.randf_range(0.5, 0.9),
			_rng.randf_range(4.0, 9.0), Color("4a3626"), 3, 1100.0, 0.4)
	_sfx("dr_thud", 1.0, 0.0)


# ------------------------------------------------------------------ F
func _ev_title_in() -> void:
	var root: Control = _title["root"]
	root.visible = true
	var x0: float = _title["x0"]
	var bw: float = _title["bw"]
	_anim(_title["dim"], "modulate:a", 0.0, 1.0, 0.15, 0)
	_anim(_title["a"], "position:x", x0 - bw, x0, 0.26, 4)
	_anim(_title["b"], "position:x", x0 + bw, x0, 0.26, 4, 0.05)
	_anim(_title["st"], "position:x", x0 + bw, x0, 0.26, 4, 0.08)
	_anim(_title["sb"], "position:x", x0 - bw, x0, 0.26, 4, 0.08)
	_anim(_title["tl"], "scale", Vector2(1.6, 1.6), Vector2.ONE, 0.3, 5, 0.12)
	_anim(_title["tl"], "modulate:a", 0.0, 1.0, 0.08, 0, 0.12)
	(_title["tl"] as Label).modulate.a = 0.0
	(_title["b"] as Control).position.x = x0 + bw
	(_title["st"] as Control).position.x = x0 + bw
	(_title["sb"] as Control).position.x = x0 - bw
	_sfx("whoosh", 1.0, 0.0)


func _ev_title_hit() -> void:
	_kick(9.0)
	_flash(Color.WHITE, 0.4, 0.3)
	_speed(C, 0.5, Color(1, 1, 1, 0.3), 40, 280.0)
	if _fx_ok():
		var bl := TC.Blade.new()
		bl.a = Vector2(-40, 404)
		bl.b = Vector2(W + 40, 248)
		bl.col = Color(Style.GOLD, 0.9)
		bl.thick = 10.0
		bl.size = Vector2(W, H)
		_fxl.add_child(bl)
		var tw := bl.create_tween()
		tw.tween_property(bl, "k", 1.0, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(bl, "fade", 0.0, 0.28)
		tw.tween_callback(bl.queue_free)
		Fx.splash(_fxl, Vector2(140, 330), Style.AQUA, 14, 200.0, 0.7)
		Fx.splash(_fxl, Vector2(1140, 300), Style.AQUA, 14, 200.0, 0.7)
	_sfx("gavel", 0.8, -4.0)
	_sfx("dr_steam", 1.3, -8.0)


func _ev_title_out() -> void:
	var x0: float = _title["x0"]
	var bw: float = _title["bw"]
	_anim(_title["a"], "position:x", x0, x0 + bw + 200.0, 0.2, 6)
	_anim(_title["st"], "position:x", x0, x0 + bw + 200.0, 0.2, 6)
	_anim(_title["b"], "position:x", x0, x0 - bw - 200.0, 0.2, 6)
	_anim(_title["sb"], "position:x", x0, x0 - bw - 200.0, 0.2, 6)
	_anim(_title["dim"], "modulate:a", 1.0, 0.0, 0.2, 0)
	_sfx("whoosh", 1.25, -6.0)


# ------------------------------------------------------------------ G
func _ev_wide_in() -> void:
	(_title["root"] as Control).visible = false
	_drained = true
	_show_shot("cave")
	_put("_cam_roll", 0.0)
	_put("_rumble", 0.0)
	_anim(self, "_cam_c", Vector2(640, 380), C, 5.8, 1)
	_anim(self, "_cam_z", 1.12, 1.0, 5.8, 1)
	_anim(self, "_drift_k", 1.0, 0.0, 5.0, 1)
	_glitch(0.28, 1.0)
	_flash(Style.AQUA, 0.25, 0.3)
	_sfx("dr_steam", 0.8, -8.0)
	_music("snapjaw", 1.5)


func _ev_area_in() -> void:
	_area.visible = true
	_anim(_area, "position:x", -560.0, 0.0, 0.26, 4)
	_sfx("whoosh", 1.0, -6.0)
	_sfx("clue", 1.0, -8.0)


func _ev_area_out() -> void:
	_anim(_area, "position:x", 0.0, -600.0, 0.22, 6)


func _ev_lantern(i: int) -> void:
	_lit_n = maxi(_lit_n, i + 1)
	while _lit_t.size() < _lit_n:
		_lit_t.append(_ev_time)
	_sfx("dr_lantern", 0.9 + i * 0.035, -5.0)


func _ev_final() -> void:
	var t: Texture2D = Assets.svg("res://art/bg/ship_dock.svg")
	if t != null:
		_final.texture = t
		_final.visible = true
	_anim(self, "_wipe_cover", 1.0, 2.0, 0.5, 2)


# ================================================================== per frame
func _process(delta: float) -> void:
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
	_update_visuals(delta)


## One timeline step: clock, events, keyframes and the simulations (also used by the debug fast-forward).
func _step(dt: float) -> void:
	_t += dt
	_fire_events()
	_update_anims()
	_simulate(dt)


func _simulate(dt: float) -> void:
	# pool spin + debris
	_pool_spin += _pool_spin_v * dt
	if _shot == "pool" or _ff:
		for d in _debris:
			var dd: Dictionary = d
			if bool(dd["gone"]):
				continue
			var r: float = dd["r"]
			var inward := 26.0 + 90.0 * _pool_swirl * clampf(900.0 / maxf(r, 60.0), 0.6, 4.0)
			r -= inward * dt * _pool_swirl
			r = minf(r, _pool_level - 30.0)
			var w := _pool_spin_v * (0.35 + 2.4 * pow(1.0 - clampf((r - 46.0) / maxf(_pool_level - 46.0, 1.0), 0.0, 1.0), 2.0))
			dd["a"] = float(dd["a"]) + w * dt
			dd["rot"] = float(dd["rot"]) + float(dd["spin"]) * dt * (0.3 + _pool_swirl)
			dd["r"] = r
			if r < 58.0:
				dd["gone"] = true
		for i in _foam.size():
			var f: Vector3 = _foam[i]
			var k := clampf((f.x - 46.0) / maxf(_pool_level - 46.0, 1.0), 0.0, 1.0)
			f.y += _pool_spin_v * (0.3 + 2.4 * pow(1.0 - k, 2.0)) * dt
			f.x -= (30.0 + 160.0 * (1.0 - k)) * dt * _pool_swirl
			if f.x < 60.0 or f.x > _pool_level:
				f.x = _rng.randf_range(maxf(_pool_level * 0.55, 120.0), maxf(_pool_level - 10.0, 130.0))
			_foam[i] = f
	# wheel + cascades + steam (rise shot)
	_wheel_ang += _wheel_v * dt
	if _shot == "rise":
		var wl_local := _wl - (RISE_SHIP.y + _ship_yoff)
		for i in CASCADES.size():
			var cs: Array = CASCADES[i]
			var ytop: float = cs[1]
			if float(_casc_t[i]) < -50.0 and wl_local > ytop + 8.0:
				_casc_t[i] = _t
		_emit_acc += dt
		while _emit_acc > 0.05:
			_emit_acc -= 0.05
			_emit_rise_tick()
	elif _shot == "cave" and _drained:
		_emit_acc += dt
		while _emit_acc > 0.1:
			_emit_acc -= 0.1
			_emit_cave_tick()
	_sim_parts(dt)


func _emit_rise_tick() -> void:
	var sp := _r_ship.position
	if _steam_rate > 0.0:
		for sx in STACK_X:
			var x: float = sx
			if _rng.randf() < 0.55 * _steam_rate:
				_emit("rise", sp + Vector2(x + _rng.randf_range(-10, 10), 72.0), Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-150, -90)),
					_rng.randf_range(1.6, 2.6), _rng.randf_range(20.0, 34.0), Color(1, 1, 1, 0.32), 1, -20.0, 0.6, 50.0)
	if _t < _jet_until:
		for k in 3:
			_emit("rise", sp + WHISTLE + Vector2(0, -4), Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-520, -380)),
				_rng.randf_range(0.6, 1.0), _rng.randf_range(10.0, 18.0), Color(1, 1, 1, 0.6), 1, 0.0, 1.4, 90.0)
	# cascade splashes where the water lands
	var wl_local := _wl - (RISE_SHIP.y + _ship_yoff)
	for i in CASCADES.size():
		var t0: float = _casc_t[i]
		if t0 < -50.0:
			continue
		var age := _t - t0
		if age > 3.0 or _rng.randf() > 0.6:
			continue
		var cs: Array = CASCADES[i]
		var x: float = cs[0]
		var yb: float = minf(float(cs[2]), wl_local)
		_emit("ship", Vector2(x + _rng.randf_range(-8, 8), yb - 2.0), Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-200, -60)),
			_rng.randf_range(0.3, 0.6), _rng.randf_range(2.0, 4.5), WATER[_rng.randi() % 4], 0, 900.0, 0.3)
	# mud drips after the cascades
	if _rng.randf() < 0.5:
		var x2 := _rng.randf_range(60.0, 940.0)
		var ys := [DECK_MAIN + 8.0, DECK_PROM + 14.0, DECK_TEX + 12.0]
		var y2: float = ys[_rng.randi() % 3]
		if y2 < wl_local - 30.0:
			_emit("ship", Vector2(x2, y2), Vector2(0, 20), 1.0, _rng.randf_range(2.0, 3.6), Color("4a3626"), 3, 700.0, 0.0)
	# wheel spray
	if _wheel_v > 0.3 and wl_local > WHEEL_C.y + 60.0:
		var a := _wheel_ang + _rng.randf() * TAU
		var p := WHEEL_C + Vector2(cos(a), sin(a)) * 122.0
		if p.y < WHEEL_C.y:
			_emit("ship", p, Vector2(-sin(a), cos(a)) * 260.0 * _wheel_v + Vector2(0, -60), _rng.randf_range(0.4, 0.8),
				_rng.randf_range(2.0, 4.0), WATER[_rng.randi() % 4], 0, 900.0, 0.2)


func _emit_cave_tick() -> void:
	# steam off the warm mud + the hole, smoke from the stacks, drips from the hanging plug
	var spots := [HOLE + Vector2(0, -8), HOLE + Vector2(-60, -4), Vector2(860, 520), Vector2(1080, 560), Vector2(560, 668), Vector2(1180, 630), Vector2(760, 486)]
	var p: Vector2 = spots[_rng.randi() % spots.size()]
	_emit("cave", p + Vector2(_rng.randf_range(-40, 40), 0), Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-40, -24)),
		_rng.randf_range(2.5, 4.0), _rng.randf_range(30.0, 60.0), Color(0.85, 0.95, 1.0, 0.14), 1, -4.0, 0.2, 26.0)
	if _rng.randf() < 0.6:
		for sx in STACK_X:
			var x: float = sx
			_emit("cave", SHIP_G_POS + Vector2(x, 74.0) * SHIP_G_SCALE, Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-50, -30)),
				_rng.randf_range(2.0, 3.0), _rng.randf_range(10.0, 16.0), Color(0.9, 0.9, 0.95, 0.22), 1, -4.0, 0.3, 22.0)
	if _rng.randf() < 0.4:
		var xs := _rng.randf_range(60.0, 940.0)
		_emit("ship", Vector2(xs, DECK_MAIN + 8.0), Vector2(0, 20), 0.8, 2.6, Color("4a3626"), 3, 600.0, 0.0)


func _emit(space: String, p: Vector2, v: Vector2, life: float, s: float, c: Color, k: int, g: float = 0.0,
		drag: float = 0.0, grow: float = 0.0) -> void:
	var arr: Array = _parts[space]
	if arr.size() > 700:
		return
	arr.append({"p": p, "v": v, "life": life, "max": life, "s": s, "c": c, "k": k, "g": g, "drag": drag, "grow": grow})


func _sim_parts(dt: float) -> void:
	for key in _parts:
		var arr: Array = _parts[key]
		var i := arr.size() - 1
		while i >= 0:
			var p: Dictionary = arr[i]
			var life: float = float(p["life"]) - dt
			if life <= 0.0 or (key == "rise" and int(p["k"]) == 0 and (p["v"] as Vector2).y > 0.0 and (p["p"] as Vector2).y > _wl + 6.0):
				arr.remove_at(i)
			else:
				p["life"] = life
				var v: Vector2 = p["v"]
				v.y += float(p["g"]) * dt
				v *= 1.0 - minf(1.0, float(p["drag"]) * dt)
				p["v"] = v
				p["p"] = (p["p"] as Vector2) + v * dt
				p["s"] = float(p["s"]) + float(p["grow"]) * dt
			i -= 1


# ------------------------------------------------------------------ visuals
func _update_visuals(delta: float) -> void:
	# shake (shared by world + overlays)
	var sh := Vector2.ZERO
	var rum := _rumble
	if _shake > 0.05 or rum > 0.05:
		sh = Vector2(randf_range(-1, 1), randf_range(-0.6, 0.6)) * _shake + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * rum
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 9.0))
	_shaker.position = sh
	# camera
	var c := _cam_c
	var z := _cam_z
	if _punch_k > 0.0:
		c = c.lerp(_punch_at, _punch_k * 0.85)
		z *= 1.0 + 0.5 * _punch_k
	var drift := Vector2(sin(_t * 0.37) * 6.0, cos(_t * 0.29) * 4.0) * _drift_k
	match _shot:
		"cave":
			_apply_cam(_cave_root, _cave_layers, c + drift * 0.6, z, _cam_roll)
			_update_cave()
		"pool":
			_apply_cam(_pool_root, [[_pool_root.get_child(0), 1.0, 1.0, C]], c, z, _cam_roll)
			_update_pool()
		"rise":
			_apply_cam(_rise_root, _rise_layers, c + drift, z, _cam_roll)
			_update_rise()
	# ecu panel motion
	if (_ecu["root"] as Control).visible:
		var grip: TextureRect = _ecu["grip"]
		var jit: float = _ecu["jit"]
		var j := Vector2(randf_range(-2, 2), randf_range(-1, 1)) * 3.0 * jit
		grip.position = Vector2(300, 60 + 330.0 * _ecu_pull) + j
		(_ecu["inner"] as Control).queue_redraw()
		(_ecu["gl"] as Control).queue_redraw()
		(_ecu["p1"] as Control).position.y = 44.0 + sin(_t * 1.7) * 3.0
	for p in _painters:
		var pn: Painter = p
		if pn.is_visible_in_tree():
			pn.queue_redraw()
	_letterbox.queue_redraw()
	var strength := clampf(1.0 - absf(_wipe_cover - 1.0), 0.0, 1.0) * 0.9 + 0.1
	Fx.set_wipe(_wipe, _wipe_cover, strength)


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


func _update_cave() -> void:
	_g_wheel.rotation = 0.0


func _update_pool() -> void:
	_pool_mat.set_shader_parameter("level", _pool_level)
	_pool_mat.set_shader_parameter("swirl", _pool_swirl)
	_pool_mat.set_shader_parameter("spin", _pool_spin)
	_pool_mat.set_shader_parameter("time", _t)
	if _plug_k < 0.0:
		_pool_plug.visible = true
		_pool_plug.position = POOL_C + Vector2(0, 6)
		_pool_plug.scale = Vector2(0.5, 0.5 * 0.8)
		_pool_plug.modulate = Color(0.25, 0.42, 0.5, 0.55)
		_pool_plug.rotation = 0.0
	elif _plug_k < 1.0:
		_pool_plug.visible = true
		var k := _plug_k
		_pool_plug.position = POOL_C + Vector2(sin(k * 5.0) * 20.0, -k * 640.0)
		var s := 0.5 + k * 1.3
		_pool_plug.scale = Vector2(s, s)
		_pool_plug.rotation = sin(k * 9.0) * 0.22
		_pool_plug.modulate = Color(0.6, 0.7, 0.75).lerp(Color.WHITE, minf(1.0, k * 4.0))
	else:
		_pool_plug.visible = false


func _update_rise() -> void:
	_r_ship.position = RISE_SHIP + Vector2(0, _ship_yoff)
	var wl_local := _wl - _r_ship.position.y
	for m in _r_mud_mats:
		(m as ShaderMaterial).set_shader_parameter("wl", wl_local)
	_r_wheel.rotation = _wheel_ang
	var wk := clampf((wl_local - (WHEEL_C.y + 124.0)) / 260.0, 0.0, 1.0)
	_r_wheel.modulate = Color(0.5, 0.42, 0.36).lerp(Color(0.92, 0.86, 0.8), wk)


func _screen_of_pool(p: Vector2) -> Vector2:
	var s := _cam_z
	return C + (p - _cam_c).rotated(_cam_roll) * s



# ================================================================== drawing
func _draw_chain(ci: CanvasItem, a: Vector2, b: Vector2, r: float, col: Color = Color("b9b4a8")) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 1.0:
		return
	var dir := d / ln
	var step := r * 2.5
	ci.draw_line(a, b, Color("3a3630"), r * 0.4)
	var n := int(ln / step) + 1
	for i in n:
		var p := a + dir * (i * step)
		ci.draw_circle(p + Vector2(r * 0.15, r * 0.2), r, Color(0, 0, 0, 0.35))
		ci.draw_circle(p, r, Color("2a1a10"))
		ci.draw_circle(p, r * 0.82, col.darkened(0.25))
		ci.draw_circle(p - Vector2(r * 0.15, r * 0.15), r * 0.6, col)
		ci.draw_circle(p - Vector2(r * 0.35, r * 0.38), r * 0.24, Color(1, 1, 1, 0.85))


func _draw_chain_cave(ci: Node2D) -> void:
	if _drained:
		# the yanked plug lies on the mud, its chain trailing to the jetty (as in ship_dock)
		var ring := _g_plug.position + Vector2(0, -108).rotated(_g_plug.rotation) * _g_plug.scale.y
		var a := ring
		var n := 7
		for i in n:
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var p0 := a.lerp(CHAIN_G_END, t0) + Vector2(0, 14.0 * sin(PI * t0))
			var p1 := a.lerp(CHAIN_G_END, t1) + Vector2(0, 14.0 * sin(PI * t1))
			_draw_chain(ci, p0, p1, 5.0)
	else:
		var sway := sin(_t * 0.9) * 2.0
		_draw_chain(ci, PULLEY, Vector2(CHAIN_WATER.x + sway, CHAIN_WATER.y), 5.0)


func _draw_cave_glow(ci: Node2D) -> void:
	# soft lake bloom under the far lanterns (additive)
	var a := 0.16 + 0.03 * sin(_t * 2.1)
	ci.draw_texture_rect(_soft, Rect2(150, 200, 1000, 170), false, Color(1.0, 0.6, 0.3, a * 0.5))
	ci.draw_texture_rect(_soft, Rect2(300, 230, 700, 130), false, Color(0.25, 0.9, 0.85, a * 0.45))


func _festoon_lanterns() -> Array:
	var out: Array = []
	for i in FESTOON.size() - 1:
		var a: Vector2 = FESTOON[i]
		var b: Vector2 = FESTOON[i + 1]
		for j in 4:
			var t := (j + 0.5) / 4.0
			out.append(Vector2(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t) + 26.0 * 4.0 * t * (1.0 - t) + 9.0))
	return out


func _draw_lake(ci: Node2D) -> void:
	var top := SHORE_Y - 2.0
	var pts := PackedVector2Array()
	for k in 34:
		var x := -40.0 + k * 41.0
		pts.append(Vector2(x, top + sin(x * 0.02 + _t * 0.6) * 1.5))
	pts.append(Vector2(1360, 760))
	pts.append(Vector2(-40, 760))
	ci.draw_colored_polygon(pts, Color(0.018, 0.03, 0.055))
	# depth bands (cel)
	ci.draw_rect(Rect2(-40, top, 1400, 26), Color(0.05, 0.14, 0.18, 0.55))
	ci.draw_rect(Rect2(-40, top + 26, 1400, 50), Color(0.035, 0.09, 0.12, 0.45))
	# long slow sheen lines
	for k in 9:
		var y := top + 18.0 + pow(k / 8.0, 1.5) * 260.0
		var x0 := fmod(k * 197.0 + _t * (8.0 + k * 3.0), 1500.0) - 200.0
		ci.draw_rect(Rect2(x0, y, 180.0 + k * 40.0, 1.5 + k * 0.35), Color(0.3, 0.75, 0.8, 0.12))
	# reflections of the festoon lanterns (warm) and the shore fungus (aqua)
	var lan := _festoon_lanterns()
	for i in lan.size():
		var p: Vector2 = lan[i]
		_reflect(ci, p.x, top, Color(1.0, 0.62, 0.3), 9, 10.0 + (i % 3) * 3.0, float(i))
	for i in FUNGUS_SHORE.size():
		var f: Vector2 = FUNGUS_SHORE[i]
		_reflect(ci, f.x, top, Color(0.35, 1.0, 0.92), 12, 18.0, float(i) * 1.7 + 4.0)
	# ripples around the chain
	var cp := CHAIN_WATER
	for k in 3:
		var ph := fmod(_t * 0.35 + k / 3.0, 1.0)
		var rr := 14.0 + ph * 120.0
		ci.draw_set_transform(cp, 0.0, Vector2(1.0, 0.22))
		ci.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(0.6, 0.95, 1.0, 0.4 * (1.0 - ph)), 3.0 * (1.0 - ph) + 1.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# bubbles breaking the surface (foreshadowing)
	var bt := _t - _bubbles_t
	if bt >= 0.0 and bt < 1.8:
		for k in 7:
			var lt := bt - k * 0.17
			if lt < 0.0 or lt > 0.7:
				continue
			var q := cp + Vector2((k - 3) * 26.0 + sin(k * 3.1) * 10.0, -6.0 + cos(k * 1.7) * 8.0)
			var r2 := 6.0 + lt * 40.0
			ci.draw_set_transform(q, 0.0, Vector2(1.0, 0.35))
			ci.draw_arc(Vector2.ZERO, r2, 0.0, TAU, 24, Color(0.75, 1.0, 1.0, 0.6 * (1.0 - lt / 0.7)), 2.5)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if lt < 0.12:
				ci.draw_circle(q + Vector2(0, -4), 7.0 * (1.0 - lt / 0.12) + 2.0, Color(0.6, 0.95, 1.0, 0.7))
	# mist
	for k in 6:
		var mx := fmod(k * 260.0 + _t * (10.0 + k * 2.0), 1700.0) - 300.0
		var my := top + 10.0 + k * 34.0
		ci.draw_texture_rect(_soft, Rect2(mx, my - 40.0, 520.0, 90.0), false, Color(0.7, 0.9, 1.0, 0.05))


func _reflect(ci: CanvasItem, x: float, top: float, col: Color, n: int, w0: float, seed: float) -> void:
	# a shimmering column of stacked horizontal strokes under a light, plus a soft bloom on the water
	ci.draw_texture_rect(_soft, Rect2(x - w0 * 1.6, top - 6.0, w0 * 3.2, 70.0 + n * 6.0), false, Color(col, 0.12))
	var y := top + 3.0
	for j in n * 2:
		var f := float(j) / (n * 2)
		var h := 2.0 + f * 3.0
		var w := (w0 * (1.0 - f * 0.35)) * (0.45 + 0.55 * absf(sin(_t * 2.1 + j * 1.3 + seed)))
		var ox := sin(_t * 1.6 + j * 0.7 + seed) * (1.5 + j * 0.6)
		ci.draw_rect(Rect2(x + ox - w * 0.5, y, w, h), Color(col.lightened(0.2), 0.7 * (1.0 - f)))
		y += h + 2.0 + f * 5.0


func _draw_dock_water(ci: Node2D) -> void:
	# the full lake hides the lower part of the jetty's lake-side face
	var a: Vector2 = DOCK_FACE[0]
	var b: Vector2 = DOCK_FACE[1]
	var lap := sin(_t * 1.7) * 2.0
	var wa := a + Vector2(0, 24 + lap)
	var wb := b + Vector2(0, 24 + lap)
	ci.draw_colored_polygon(PackedVector2Array([wa, wb, Vector2(b.x + 2, 760), Vector2(a.x - 2, 760)]), Color(0.018, 0.03, 0.055))
	ci.draw_line(wa, wb, Color(0.7, 0.95, 1.0, 0.45), 2.0)
	ci.draw_line(wa + Vector2(0, 5), wb + Vector2(0, 5), Color(0.2, 0.5, 0.55, 0.4), 2.0)


## G: the gangway from the jetty up to the Mudlark's bow (as in ship_dock).
func _draw_gangway(ci: Node2D) -> void:
	if not _drained:
		return
	var b0 := Vector2(270, 466)
	var b1 := Vector2(314, 474)
	var t0 := Vector2(390, 404)
	var t1 := Vector2(410, 410)
	ci.draw_colored_polygon(PackedVector2Array([b0 + Vector2(4, 6), b1 + Vector2(4, 6), t1 + Vector2(4, 6), t0 + Vector2(4, 6)]), Color(0, 0, 0, 0.4))
	ci.draw_colored_polygon(PackedVector2Array([b0, b1, t1, t0]), Color("2a1a10"))
	ci.draw_colored_polygon(PackedVector2Array([b0 + Vector2(2, 1), b1 + Vector2(-2, -1), t1 + Vector2(-1, 0), t0 + Vector2(1, 1)]), Color("8a5a34"))
	for k in 9:
		var f := (k + 0.5) / 9.0
		ci.draw_line(b0.lerp(t0, f), b1.lerp(t1, f), Color("4a2c16"), 1.5)
	for side in [[b0, t0, -10.0], [b1, t1, -12.0]]:
		var p0: Vector2 = side[0]
		var p1: Vector2 = side[1]
		var hgt: float = side[2]
		ci.draw_line(p0, p0 + Vector2(0, hgt * 2.2), Color("2a1a10"), 3.0)
		ci.draw_line(p1, p1 + Vector2(0, hgt * 1.6), Color("2a1a10"), 3.0)
		ci.draw_line(p0 + Vector2(0, hgt * 2.2), p1 + Vector2(0, hgt * 1.6), Color("c8b48a"), 1.6)


func _draw_ship_text(ci: Node2D) -> void:
	# the name on the bow plaque + the wheel-guard arch plaque (brass letters)
	var vis := 1.0
	if ci.get_parent() == _r_ship:
		var wl_local := _wl - _r_ship.position.y
		vis = clampf((wl_local - (PLAQUE_BOW.end.y + 6.0)) / 60.0, 0.0, 1.0)
	if vis <= 0.0:
		return
	for r in [PLAQUE_BOW, PLAQUE_ARCH]:
		var rect: Rect2 = r
		var fs := int(rect.size.y * 0.72)
		var txt := "MUDLARK"
		var sw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(rect.position.x + (rect.size.x - sw) * 0.5, rect.position.y + rect.size.y * 0.5 + fs * 0.36)
		ci.draw_string(_font, p + Vector2(1.5, 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * vis))
		ci.draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffd98a", vis))


func _draw_ship_lights(ci: Node2D) -> void:
	# additive glows: lanterns + windows (wide shot only)
	for i in mini(_lit_n, LANTERNS.size()):
		var p: Vector2 = LANTERNS[i]
		var age := _t - float(_lit_t[i]) if i < _lit_t.size() else 10.0
		var pop := 1.0 + 1.6 * maxf(0.0, 1.0 - age / 0.35)
		var fl := 0.85 + 0.15 * sin(_t * 9.0 + i * 2.3) * sin(_t * 3.1 + i)
		var col: Color = LANTERN_COLS[i % 3]
		var r := 46.0 * pop
		ci.draw_texture_rect(_soft, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col.lerp(Color(1, 0.85, 0.5), 0.4), 0.5 * fl))
	if _windows > 0.0:
		var wc := Color(1.0, 0.72, 0.35, 0.55 * _windows)
		for k in 12:
			if k == 5 or k == 10:
				continue
			var x := 180.0 + 62.0 * k
			ci.draw_texture_rect(_soft, Rect2(x - 20, 550, 74, 70), false, Color(wc, wc.a * 0.6))
		for k in 11:
			if k == 6:
				continue
			var x2 := 312.0 + 46.0 * k
			ci.draw_texture_rect(_soft, Rect2(x2 - 14, 466, 54, 50), false, Color(wc, wc.a * 0.5))
		ci.draw_texture_rect(_soft, Rect2(590, 360, 150, 90), false, Color(wc, wc.a * 0.6))


func _draw_ship_lights_core(ci: Node2D) -> void:
	for i in mini(_lit_n, LANTERNS.size()):
		var p: Vector2 = LANTERNS[i]
		var col: Color = LANTERN_COLS[i % 3]
		var fl := 0.88 + 0.12 * sin(_t * 9.0 + i * 2.3)
		ci.draw_set_transform(p, 0.0, Vector2(1.0, 1.33))
		ci.draw_circle(Vector2.ZERO, 8.0, Color(col.lightened(0.25), fl))
		ci.draw_circle(Vector2(-2, -2), 4.0, Color(1, 0.95, 0.75, 0.9 * fl))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _windows > 0.0:
		var wc := Color(1.0, 0.78, 0.42, 0.75 * _windows)
		for k in 12:
			if k == 5 or k == 10:
				continue
			var x := 180.0 + 62.0 * k
			var pts := PackedVector2Array([Vector2(x + 3, 606), Vector2(x + 3, 578), Vector2(x + 17, 563), Vector2(x + 31, 578), Vector2(x + 31, 606)])
			ci.draw_colored_polygon(pts, wc)
		for k in 11:
			if k == 6:
				continue
			ci.draw_rect(Rect2(312.0 + 46.0 * k + 3, 481, 20, 20), wc)
		for k in 3:
			ci.draw_rect(Rect2(613 + k * 38, 389, 26, 32), Color(wc, wc.a * 0.8))


func _draw_parts(ci: CanvasItem, space: String) -> void:
	var arr: Array = _parts[space]
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
			_:
				ci.draw_circle(pos, s, Color(col, col.a * lk))


# ------------------------------------------------------------------ pool painters
func _pool_xy(r: float, a: float) -> Vector2:
	return POOL_C + Vector2(cos(a), sin(a) * POOL_TILT) * r


func _draw_pool_debris(ci: Node2D) -> void:
	# foam flecks riding the current
	if _pool_swirl > 0.05:
		for f in _foam:
			var q: Vector3 = f
			if q.x > _pool_level:
				continue
			var p0 := _pool_xy(q.x, q.y)
			var p1 := _pool_xy(q.x, q.y - 0.06 * q.z)
			var p2 := _pool_xy(q.x, q.y - 0.12 * q.z)
			ci.draw_polyline(PackedVector2Array([p0, p1, p2]), Color(0.85, 1.0, 1.0, 0.55 * _pool_swirl), 2.0 + q.z)
	for d in _debris:
		var dd: Dictionary = d
		if bool(dd["gone"]):
			continue
		var r: float = dd["r"]
		var p := _pool_xy(r, float(dd["a"]))
		var sink := clampf((r - 58.0) / 160.0, 0.0, 1.0)
		var s: float = float(dd["s"]) * (0.45 + 0.55 * sink) * (0.8 + 0.2 * (p.y - POOL_C.y + 300.0) / 600.0)
		var rot: float = dd["rot"]
		var dark := Color(0.55 + 0.45 * sink, 0.55 + 0.45 * sink, 0.6 + 0.4 * sink)
		ci.draw_set_transform(p, rot, Vector2(s, s))
		match int(dd["k"]):
			0:
				ci.draw_circle(Vector2(1, 2), 10.0, Color(0, 0, 0, 0.3))
				ci.draw_circle(Vector2.ZERO, 10.0, Color("2a1a10"))
				ci.draw_circle(Vector2.ZERO, 8.5, Color("ffb627") * dark)
				ci.draw_circle(Vector2(-3, -3), 3.0, Color(1, 1, 0.8, 0.8))
				ci.draw_circle(Vector2(0, -9), 2.5, Color("4f8f3e") * dark)
			1:
				var sc := s * 1.3
				ci.draw_set_transform(p, sin(rot) * 0.35, Vector2(sc * 1.5, sc))
				ci.draw_circle(Vector2(0, 3), 13.0, Color(0, 0, 0, 0.25))
				ci.draw_circle(Vector2.ZERO, 12.0, Color("2a1a10"))
				ci.draw_circle(Vector2.ZERO, 10.0, Color("ffd84a") * dark)
				ci.draw_circle(Vector2(-3, -4), 4.0, Color(1, 1, 0.85, 0.6))
				ci.draw_set_transform(p, sin(rot) * 0.35, Vector2(sc, sc))
				ci.draw_circle(Vector2(10, -13), 8.5, Color("2a1a10"))
				ci.draw_circle(Vector2(10, -13), 7.0, Color("ffe066") * dark)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(16, -14), Vector2(24, -12), Vector2(16, -9)]), Color("f08a2a"))
				ci.draw_circle(Vector2(12, -15), 1.6, Color("2a1a10"))
			_:
				ci.draw_rect(Rect2(-14, -10, 28, 20), Color("2a1a10"))
				ci.draw_rect(Rect2(-12, -8, 24, 16), Color("8a5a34") * dark)
				ci.draw_line(Vector2(-6, -8), Vector2(-6, 8), Color("c0c4cc") * dark, 2.0)
				ci.draw_line(Vector2(6, -8), Vector2(6, 8), Color("c0c4cc") * dark, 2.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pool_chain(ci: Node2D) -> void:
	if _plug_k >= 1.0:
		return
	var top := Vector2(POOL_C.x, -900)
	var ring := _pool_plug.position + Vector2(0, -130 + 22) * _pool_plug.scale.y
	if _plug_k < 0.0:
		ring = POOL_C + Vector2(0, -36)
	_draw_chain(ci, top, ring, 7.0 + maxf(_plug_k, 0.0) * 6.0)


func _draw_pool_column(ci: Node2D) -> void:
	var bt := _t - _plug_t0
	if bt < 0.0 or bt > 1.3:
		return
	var up := minf(1.0, bt / 0.2)
	var fall := clampf((bt - 0.32) / 0.9, 0.0, 1.0)
	var a := 1.0 - fall
	var base := POOL_C
	# a cluster of tapered jets (cel white with an aqua rim) + a crown of spikes around the base
	var jets := [[-58.0, 0.62, -0.22, 34.0], [-26.0, 0.9, -0.08, 46.0], [6.0, 1.0, 0.03, 52.0], [36.0, 0.78, 0.14, 40.0], [62.0, 0.5, 0.28, 28.0]]
	for j in jets:
		var jj: Array = j
		var x: float = jj[0]
		var h: float = 560.0 * float(jj[1]) * up * (1.0 - fall * fall)
		var lean: float = jj[2]
		var w: float = jj[3]
		var b0 := base + Vector2(x - w * 0.5, 4)
		var b1 := base + Vector2(x + w * 0.5, 4)
		var tip := base + Vector2(x + lean * h, -h)
		ci.draw_colored_polygon(PackedVector2Array([b0, tip, b1]), Color(0.45, 0.88, 0.92, 0.85 * a))
		ci.draw_colored_polygon(PackedVector2Array([b0.lerp(b1, 0.25), tip.lerp(base + Vector2(x, 0), 0.08), b0.lerp(b1, 0.7)]), Color(1, 1, 1, 0.9 * a))
	for k in 12:
		var ang := PI + k * PI / 11.0
		var d := Vector2(cos(ang), sin(ang) * 0.55)
		var r0 := 60.0 + 30.0 * up
		var sp := 50.0 + 40.0 * float(k % 3)
		var p0 := base + Vector2(d.x * r0, d.y * r0 * POOL_TILT * 2.0)
		var p1 := p0 + Vector2(d.x * sp, -sp * 1.3) * up * (1.0 - fall)
		var n := Vector2(-d.y, d.x).normalized() * 7.0
		ci.draw_colored_polygon(PackedVector2Array([p0 - n, p1, p0 + n]), Color(0.9, 1.0, 1.0, 0.8 * a))
	for k in 3:
		var rr := 40.0 + bt * (260.0 + k * 140.0)
		ci.draw_set_transform(base, 0.0, Vector2(1.0, POOL_TILT))
		ci.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 56, Color(0.8, 1.0, 1.0, 0.7 * (1.0 - bt / 1.3)), 6.0 - k)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pool_focus(ci: Node2D) -> void:
	# manga focus lines converging on the funnel (pool-local, so they rotate with the camera)
	if _focus_k <= 0.01:
		return
	var n := 40
	for i in n:
		var a := (float(i) + fmod(_t * 37.0 * float(i % 7), 1.0)) * TAU / n + _t * 0.5
		var w := 0.006 + 0.012 * fmod(float(i) * 0.37, 1.0)
		var r0 := 140.0 + fmod(float(i) * 53.0 + _t * 900.0, 160.0)
		var tri := PackedVector2Array([POOL_C + Vector2.from_angle(a) * r0, POOL_C + Vector2.from_angle(a - w) * 1400.0,
			POOL_C + Vector2.from_angle(a + w) * 1400.0])
		ci.draw_colored_polygon(tri, Color(1, 1, 1, 0.3 * _focus_k))


# ------------------------------------------------------------------ rise painters
func _draw_rise_sky_glow(ci: Node2D) -> void:
	ci.draw_texture_rect(_soft, Rect2(140, 260, 1000, 260), false, Color(0.2, 0.8, 0.8, 0.12))


func _draw_cascades(ci: Node2D) -> void:
	var wl_local := _wl - _r_ship.position.y
	for i in CASCADES.size():
		var t0: float = _casc_t[i]
		if t0 < -50.0:
			continue
		var age := _t - t0
		if age > 3.2:
			continue
		var cs: Array = CASCADES[i]
		var x: float = cs[0]
		var yt: float = cs[1]
		var yb: float = minf(float(cs[2]), wl_local)
		if yb <= yt:
			continue
		var inten := clampf(1.0 - age / 3.2, 0.0, 1.0)
		var w: float = float(cs[3]) * (0.4 + 0.6 * inten)
		var a := 0.75 * inten
		var pts := PackedVector2Array([Vector2(x - w * 0.5, yt), Vector2(x + w * 0.5, yt), Vector2(x + w * 0.7, yb), Vector2(x - w * 0.7, yb)])
		ci.draw_colored_polygon(pts, Color(0.55, 0.9, 0.95, a * 0.55))
		ci.draw_line(Vector2(x - w * 0.2, yt), Vector2(x - w * 0.3, yb), Color(1, 1, 1, a * 0.7), maxf(1.5, w * 0.18))
		var len := yb - yt
		for k in 3:
			var ph := fmod(_t * 2.2 + k / 3.0 + i * 0.13, 1.0)
			var y := yt + ph * len
			ci.draw_line(Vector2(x + w * 0.1, y), Vector2(x + w * 0.1, minf(y + 14.0, yb)), Color(1, 1, 1, a), maxf(1.5, w * 0.25))
		ci.draw_set_transform(Vector2(x, yb), 0.0, Vector2(1.0, 0.35))
		ci.draw_circle(Vector2.ZERO, w * 1.1, Color(1, 1, 1, a * 0.6))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rise_water(ci: Node2D) -> void:
	var wl := _wl
	if wl > 900.0:
		return
	var x0 := -260.0
	var x1 := W + 260.0
	var pts := PackedVector2Array()
	var steps := 48
	for k in steps + 1:
		var x := lerpf(x0, x1, float(k) / steps)
		pts.append(Vector2(x, wl + sin(x * 0.045 + _t * 5.0) * 3.0 + sin(x * 0.013 - _t * 2.0) * 4.0))
	var poly := pts.duplicate()
	poly.append(Vector2(x1, 1000))
	poly.append(Vector2(x0, 1000))
	ci.draw_colored_polygon(poly, Color(0.02, 0.05, 0.08))
	ci.draw_rect(Rect2(x0, wl, x1 - x0, 34), Color(0.06, 0.22, 0.27, 0.65))
	ci.draw_rect(Rect2(x0, wl + 34, x1 - x0, 40), Color(0.04, 0.12, 0.16, 0.5))
	# current streaks racing toward the plug hole (left)
	for k in 26:
		var depth := fmod(k * 0.618, 1.0)
		var y := wl + 14.0 + depth * 340.0
		var spd := 500.0 + 900.0 * (1.0 - depth)
		var ln := 80.0 + 220.0 * (1.0 - depth)
		var xx := x1 - fmod(k * 211.0 + _t * spd, x1 - x0 + ln)
		ci.draw_rect(Rect2(xx, y, ln, 2.0 + 2.5 * (1.0 - depth)), Color(0.4, 0.85, 0.9, 0.22 * (1.0 - depth * 0.6)))
	# foam lip
	ci.draw_polyline(pts, Color(0.85, 1.0, 1.0, 0.85), 4.0)
	for k in steps:
		if (k * 7 + int(_t * 12.0)) % 5 == 0:
			var p: Vector2 = pts[k]
			ci.draw_circle(p + Vector2(0, 2), 5.0, Color(1, 1, 1, 0.7))
	# ripples where the ship breaks the surface
	var sp := _r_ship.position
	var wl_local := wl - sp.y
	if wl_local > STACK_TOP + 10.0:
		for sx in STACK_X:
			var x: float = sx
			for k in 2:
				var ph := fmod(_t * 1.2 + k * 0.5 + x * 0.01, 1.0)
				ci.draw_set_transform(Vector2(sp.x + x, wl + 2.0), 0.0, Vector2(1.0, 0.22))
				ci.draw_arc(Vector2.ZERO, 30.0 + ph * 90.0, 0.0, TAU, 32, Color(0.8, 1.0, 1.0, 0.5 * (1.0 - ph)), 3.0)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ overlay painters
func _draw_eye_glint(ci: Control) -> void:
	if _glint <= 0.01:
		return
	var p := Vector2(612, 128)
	var r := 70.0 * _glint
	ci.draw_texture_rect(_soft, Rect2(p - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(1, 0.2, 0.2, 0.8 * _glint))
	var pts := PackedVector2Array()
	for q in 8:
		var rr := r * (1.0 if q % 2 == 0 else 0.18)
		pts.append(p + Vector2.from_angle(q * PI / 4.0 + 0.2) * rr)
	ci.draw_colored_polygon(pts, Color(1, 0.9, 0.9, _glint))


func _draw_ecu_chain(ci: Control) -> void:
	var pull := _ecu_pull
	var jit: float = _ecu["jit"]
	# backdrop inside the panel: dim green bloom + diagonal slashes
	ci.draw_texture_rect(_soft, Rect2(200, -120, 640, 560), false, Color(0.25, 0.7, 0.35, 0.22))
	for k in 6:
		var x0 := 170.0 + k * 120.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 60, 0), Vector2(x0 + 100, 0), Vector2(x0 - 10, 360), Vector2(x0 - 50, 360)]),
			Color(1, 1, 1, 0.025))
	var gx := 300.0 + GRIP_TOP.x * 0.75 + randf_range(-1.5, 1.5) * jit
	var gy := 60.0 + GRIP_TOP.y * 0.75 + 330.0 * pull
	_draw_chain(ci, Vector2(gx, -40), Vector2(gx, gy), 13.0)
	# vertical speed lines when it is yanked
	if _ecu_lines > 0.0:
		for k in 16:
			var x := 150.0 + fmod(k * 97.0, 590.0)
			var y := fmod(k * 131.0 + _t * 2600.0, 520.0) - 120.0
			ci.draw_rect(Rect2(x, y, 3.0 + (k % 3) * 2.0, 90.0 + (k % 4) * 40.0), Color(1, 1, 1, 0.35 * _ecu_lines))


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
	if _t < SKIP_AFTER:
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
	print_verbose("[drain] finished at t=%.2f skipped=%s" % [_t, skipped])
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
