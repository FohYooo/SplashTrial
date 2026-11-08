extends Control
## EXECUTION "video" (Chapter 2) - THE ENDLESS LULLABY (docs/DESIGN2.md section 9, horror version).
## A ~59 s cursed-broadcast sequence with the same architecture as execution_screen.gd: one clock advanced
## in _process, timed events (see _schedule) start keyframes in a tiny built-in animator, and every other
## effect is a pure function of the "visual time" _vt (which can stutter / run choppy for frame-drop
## effects). No awaits and no Tween objects, so nothing can resume after the screen is freed.
## The fate happens off-screen: every impact is a cut to black + a thud; afterwards only red water, an
## empty cradle and a floating nightcap are shown.
## Hold Space / Enter / mouse for 1 s (after 3 s) to skip. Emits finished({}) exactly once.
## Debug: --exec-t=<seconds> starts the timeline at that time (for screenshots).

signal finished(result: Dictionary)

const Style := preload("res://scripts/ui/style.gd")
const Assets := preload("res://scripts/core/assets.gd")

const END_TIME := 58.8
const SKIP_AFTER := 3.0
const HOLD_TO_SKIP := 1.0
const AUTOTEST_END := 0.3
const MUSIC_ID := "execution_lullaby"

# ---- geometry shared with tools/gen_exec2_art.py (world px of the exterior shot)
const WHEEL_C := Vector2(812, 380)
const WHEEL_SC := 0.88
const WHEEL_N := 12
const PAD_R0 := 176.0                     # 200 * WHEEL_SC (inner end of a paddle board)
const PAD_R1 := 260.5                     # 296 * WHEEL_SC (outer tip)
const WATER_Y := 548.0
const PIVOT := Vector2(340, 66)           # the crane's pulley
const CHAIN_L := 300.0
const CR_EXT_SC := 0.24
const CR_SPR := Vector2(0, 370)           # cradle sprites (600x740) centre; the chain ring is the cradle origin
const TUMBLE_POS := Vector2(0, 352)
const TUMBLE_SC := 0.7
const MOB_HUB := Vector2(0, -70)          # mobile hub on the main chain, above the ring
const MOB_RX := 142.0
const MOB_RY := 22.0
const MOB_STR := 30.0
const MOB_SC := 0.62
const MOB_EYE := Vector2(17, 66)          # lx_mob_front's red eye, relative to its string point
const CL_PIVOT := Vector2(640, -730)      # close-up: pendulum pivot far above the frame
const CL_LEN := 880.0
const CL_SC := 0.92
const CL_SWING := 0.36                    # close-up swing angle = exterior swing angle * this
const LANTERN_EXT := Vector2(300, 98)
const LANTERN_CL := Vector2(392, 92)
const THUD_T := [36.0, 38.4, 40.8]

const BLOOD := Color("7a0010")
const BLOOD_D := Color("3a0008")
const BLOOD_H := Color("b3001b")
const BONE_TXT := Color(0.86, 0.82, 0.72)
const AQUA_TXT := Color(0.66, 0.95, 0.92)
const WATER_COL := Color(0.62, 0.76, 0.76)

const VHS_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float static_amt = 0.0;
uniform float tear = 0.0;
uniform float vroll = 0.0;
uniform float chroma = 2.0;
uniform float desat = 0.85;
uniform float grain = 0.07;
uniform float vignette = 1.0;
uniform float bright = 1.0;
uniform float tracking = 0.3;
uniform float red_keep = 1.0;

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
	float ratio = (c.r - max(c.g, c.b)) / (c.r + 0.06);
	float redness = smoothstep(0.42, 0.68, ratio) * red_keep;
	vec3 tone = vec3(l) * mix(vec3(0.62, 0.96, 1.0), vec3(1.04, 1.0, 0.86), smoothstep(0.05, 0.6, l));
	vec3 g = mix(c, tone, desat * (1.0 - redness));
	g = mix(g, vec3(c.r * 1.05, c.g * 0.4, c.b * 0.4), redness * 0.6);
	g = pow(max(g, vec3(0.0)), vec3(1.12)) * bright;
	g *= 1.0 - 0.07 * (0.5 + 0.5 * sin((suv.y + t * 0.11) * 6.2831));
	g *= 1.0 - 0.10 * (0.5 + 0.5 * sin(suv.y * 720.0 * 3.14159));
	float st = step(0.86, rnd(vec2(floor(uv.x * 160.0), line + fr))) * band;
	g = mix(g, vec3(0.8), st * 0.6);
	float n = rnd(floor(suv * vec2(640.0, 360.0)) + vec2(fract(t * 7.0) * 91.0, fract(t * 3.0) * 57.0));
	g += (n - 0.5) * grain;
	float n2 = rnd(floor(suv * vec2(320.0, 240.0)) + vec2(fr * 1.31, fr * 0.77));
	g = mix(g, vec3(n2 * 0.95), clamp(static_amt, 0.0, 1.0));
	float seam = 1.0 - smoothstep(0.0, 0.03, abs(suv.y - (1.0 - vroll)));
	g *= 1.0 - seam * step(0.002, vroll) * 0.9;
	vec2 d = suv - 0.5;
	float v = 1.0 - smoothstep(0.32, 0.95, length(d * vec2(1.0, 1.15)) * 1.25);
	g *= mix(1.0, v, vignette);
	COLOR = vec4(g, 1.0);
}
"""

## Portrait lighting: one soft point light (in UV space) over a dark ambient, partly desaturated.
const LIT_SHADER := """
shader_type canvas_item;
uniform vec2 light_uv = vec2(0.5, -0.1);
uniform float radius = 0.9;
uniform vec4 light_col : source_color = vec4(1.0, 1.0, 0.95, 1.0);
uniform vec4 ambient : source_color = vec4(0.04, 0.06, 0.07, 1.0);
uniform float desat = 0.3;
uniform float gain = 1.3;

void fragment() {
	vec4 tx = texture(TEXTURE, UV);
	float l = dot(tx.rgb, vec3(0.299, 0.587, 0.114));
	vec3 base = mix(tx.rgb, vec3(l), desat);
	float d = length((UV - light_uv) * vec2(1.0, 1.25));
	float fall = 1.0 - smoothstep(0.0, radius, d);
	vec3 lit = base * (ambient.rgb + light_col.rgb * fall * gain);
	COLOR = vec4(lit, tx.a) * COLOR;
}
"""

# ------------------------------------------------------------------ clock / animator
var _t := 0.0             # real timeline time
var _vt := 0.0            # visual time (stutters / runs choppy)
var _vt_prev := 0.0
var _ev_time := 0.0       # scheduled time of the event currently firing
var _events: Array = []
var _ev_i := 0
var _anims: Array = []
var _done := false
var _hold := 0.0
var _choppy := 0.0
var _stutter_frames := 0
var _end_at := END_TIME
var _rng := RandomNumberGenerator.new()

# fx state (pushed to the VHS shader each frame; animated through the animator)
var _fx_static := 1.0
var _fx_tear := 0.05
var _fx_vroll := 0.0
var _fx_chroma := 2.0
var _fx_desat := 0.6
var _fx_grain := 0.07
var _fx_bright := 1.0
var _fx_tracking := 0.25
var _fx_vignette := 1.0
var _g_tear := 0.0
var _g_static := 0.0
var _hud_glitch := 0.0

# camera
var _cam_c := Vector2(640, 360)
var _cam_z := 1.0
var _cam_from_c := Vector2(640, 360)
var _cam_to_c := Vector2(640, 360)
var _cam_from_z := 1.0
var _cam_to_z := 1.0
var _cam_t0 := 0.0
var _cam_t1 := 0.0
var _cam_roll := 0.0
var _shake := 0.0
var _sway := 2.0

# lights / scene state
var _ext_level := 0.0
var _lamp_level := 0.0
var _lamp_sag := 0.0
var _flash_a := 0.0
var _flash_col := Color(0.85, 1.0, 0.98)
var _wheel_ang := 0.0
var _wheel_speed := 0.22
var _a_exit := 0.7
var _pad_prev: Array = []
var _stain_a := 0.0
var _red_k := 0.0
var _red_t0 := 1.0e9
var _peaks: Array = []
var _jolt := 0.0
var _tumble_shake := 0.0
var _tumble_expr := "sad"
var _cradle_empty := false
var _crack_a := 0.0
var _mob_ang := 0.0
var _mob_speed := 0.35
var _mob_front := false
var _key_ang := 0.0
var _key_speed := 0.0
var _gear_ang := 0.0
var _needle := 0.0
var _eye_scale := 0.3
var _eye_open := 0.0
var _cc_until := 0.0
var _title_exec_t0 := 1.0e9
var _title_name_t0 := 1.0e9
var _title_act_t0 := 1.0e9
var _sweet_t0 := -100.0
var _trans_t0 := -100.0
var _lens_t0 := -100.0
var _subliminal_until := -1.0
var _typed := 0
var _ff := false
var _cap_t0 := 1.0e9

# nodes
var _tx := {}
var _mono: SystemFont
var _glow_tex: Texture2D
var _add_mat: CanvasItemMaterial
var _world: Node2D
var _ext: Node2D
var _close: Node2D
var _snap: Node2D
var _keyset: Node2D
var _wheel: Sprite2D
var _wheel_stain: Sprite2D
var _deck_wire: Node2D
var _deck_glow: Node2D
var _lanterns: Array = []
var _streams: Node2D
var _water: Node2D
var _splash: Node2D
var _cap: Sprite2D
var _cap_water: Node2D
var _mist: Node2D
var _pend_ext: Node2D
var _pend_cl: Node2D
var _cr_ext := {}
var _cr_cl := {}
var _lamp_ext: Sprite2D
var _lamp_ext_glow: Sprite2D
var _lamp_cl: Sprite2D
var _lamp_cl_glow: Sprite2D
var _lamp_cl_wash: Sprite2D
var _cl_cave: Sprite2D
var _cl_wheel: Sprite2D
var _cl_fx: Node2D
var _snap_sil: Sprite2D
var _snap_eye: Sprite2D
var _snap_eye_glow: Sprite2D
var _snap_close: Sprite2D
var _snap_close_mat: ShaderMaterial
var _key: Sprite2D
var _gears: Array = []
var _dial: Node2D
var _lens: Control
var _black: ColorRect
var _standby: Control
var _title: Control
var _endtext: Control
var _flash: ColorRect
var _vhs: ColorRect
var _vhs_mat: ShaderMaterial
var _hud: Control
var _cc: Control
var _cc_label: Label
var _cc_box: ColorRect
var _hint: Control
var _hint_fill: ColorRect
var _sub_face: Sprite2D

# particles / deterministic decoration
var _drops: Array = []        # splash droplets: [pos, vel, life, max_life, size, red]
var _rings: Array = []        # ripple rings on the water: [pos, t0, size]
var _dust: Array = []
var _wdash: Array = []
var _wrefl: Array = []
var _fog: Array = []
var _lens_drops: Array = []
var _sweet_drips: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 2424
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Courier New", "Menlo", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_mono.font_weight = 700
	_glow_tex = _radial_tex()
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_a_exit = asin((WATER_Y - WHEEL_C.y) / PAD_R1)
	_load_textures()
	_build_swing()
	_build()
	_make_decor()
	_schedule()
	if Game.autotest:
		# exercise the cold open, then end quickly
		_events = _events.filter(func(e: Array) -> bool: return float(e[0]) < 0.25)
		_end_at = AUTOTEST_END
	var start := _debug_start_time()
	if start > 0.0:
		# fast-forward the timeline silently, in small steps, so keyframes resolve in order
		_ff = true
		while _t < start:
			var dt := minf(1.0 / 30.0, start - _t)
			_t += dt
			_fire_events()
			_vt = _t
			_update_anims()
			_advance_sim(dt)
		_vt_prev = _vt
		_ff = false
	_update_all(0.0)
	set_process(true)


func _debug_start_time() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--exec-t="):
			return clampf(float(a.get_slice("=", 1)), 0.0, END_TIME - 0.5)
	return 0.0


# ================================================================== assets / helpers
func _load_textures() -> void:
	for n in ["lx_cave", "lx_stern", "lx_stern_fg", "lx_wheel", "lx_wheel_stain", "lx_cradle_back", "lx_quilt", "lx_quilt_empty",
			"lx_cradle_front", "lx_cradle_crack", "lx_mob_front", "lx_mob_side", "lx_mob_back", "lx_lantern", "lx_eye",
			"lx_snap_sil", "lx_standby", "lx_key", "lx_gear", "lx_gearbox"]:
		_tx[n] = Assets.prop(n)
	_tx["wheel_big"] = Assets.prop("lx_wheel", 2.0)
	_tx["stain_big"] = Assets.prop("lx_wheel_stain", 2.0)
	_tx["cap_big"] = Assets.prop("lx_nightcap", 2.0)
	_tx["mob_big"] = Assets.prop("lx_mob_front", 3.0)
	for e in ["sad", "shock", "normal"]:
		_tx["tumble_" + e] = Assets.portrait("tumble", e)
	for e in ["happy", "angry"]:
		_tx["snapjaw_" + e] = Assets.portrait("snapjaw", e)


func _tex(n: String) -> Texture2D:
	return _tx.get(n, null)


func _radial_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 0.5))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _spr(parent: Node, tex: Texture2D, pos: Vector2 = Vector2.ZERO, sc: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2(sc, sc)
	parent.add_child(s)
	return s


func _node(parent: Node, pos: Vector2 = Vector2.ZERO) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _full_rect(parent: Node, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _ctrl(parent: Node) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


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


func _sfx(id: String, pitch: float = 1.0, vol: float = 0.0) -> void:
	# never play sounds while the debug start fast-forwards through the timeline
	if _ff or _t - _ev_time > 0.3:
		return
	Audio.sfx(id, pitch, vol)


func _bg_rect(parent: Node2D, col: Color) -> Node2D:
	var n := _node(parent)
	n.draw.connect(func() -> void: n.draw_rect(Rect2(-500, -500, 2280, 1720), col))
	return n


# ================================================================== building
func _build() -> void:
	_full_rect(self, Color.BLACK)
	_world = Node2D.new()
	add_child(_world)
	_build_ext()
	_build_close()
	_build_snap()
	_build_key()
	_show_set("none")

	_black = _full_rect(self, Color(0, 0, 0, 1))
	_black.visible = false
	_lens = _ctrl(self)
	_lens.draw.connect(_draw_lens)

	_standby = _ctrl(self)
	var card := TextureRect.new()
	card.texture = _tex("lx_standby")
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_standby.add_child(card)
	var box := ColorRect.new()
	box.color = Color(0, 0, 0, 0.92)
	box.position = Vector2(330, 560)
	box.size = Vector2(620, 92)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_standby.add_child(box)
	var sb := Label.new()
	sb.text = "PLEASE  STAND  BY"
	sb.add_theme_font_override("font", Style.display_font())
	sb.add_theme_font_size_override("font_size", 50)
	sb.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	sb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sb.position = box.position
	sb.size = box.size
	sb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_standby.add_child(sb)
	_sub_face = Sprite2D.new()
	_sub_face.texture = _tex("mob_big")
	_sub_face.position = Vector2(640, 330)
	_sub_face.scale = Vector2(1.25, 1.25)
	_sub_face.visible = false
	_standby.add_child(_sub_face)
	_standby.visible = false

	_title = _ctrl(self)
	_title.draw.connect(_draw_title)
	_title.visible = false
	_endtext = _ctrl(self)
	_endtext.draw.connect(_draw_end)
	_flash = _full_rect(self, Color(1, 1, 1, 0))

	_vhs = _full_rect(self, Color.WHITE)
	var sh := Shader.new()
	sh.code = VHS_SHADER
	_vhs_mat = ShaderMaterial.new()
	_vhs_mat.shader = sh
	_vhs.material = _vhs_mat

	_hud = _ctrl(self)
	_hud.draw.connect(_draw_hud)
	_hud.visible = false

	_cc = _ctrl(self)
	_cc_box = ColorRect.new()
	_cc_box.color = Color(0, 0, 0, 0.88)
	_cc_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cc.add_child(_cc_box)
	_cc_label = Label.new()
	_cc_label.add_theme_font_override("font", _mono)
	_cc_label.add_theme_font_size_override("font_size", 28)
	_cc_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_cc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cc.add_child(_cc_label)
	_cc.visible = false

	_hint = Control.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.position = Vector2(1000, 684)
	_hint.modulate.a = 0.0
	add_child(_hint)
	var hl := Label.new()
	hl.text = "Hold SPACE / click to skip"
	hl.add_theme_font_override("font", _mono)
	hl.add_theme_font_size_override("font_size", 15)
	hl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(hl)
	hl.reset_size()
	hl.position = Vector2(256 - hl.size.x, -6)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.15)
	track.position = Vector2(56, 16)
	track.size = Vector2(200, 4)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(track)
	_hint_fill = ColorRect.new()
	_hint_fill.color = Color(0.85, 0.85, 0.85)
	_hint_fill.position = track.position
	_hint_fill.size = Vector2(0, 4)
	_hint_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(_hint_fill)


func _build_ext() -> void:
	_ext = _node(_world)
	_bg_rect(_ext, Color("030606"))
	_spr(_ext, _tex("lx_cave"), Vector2(640, 360))
	_spr(_ext, _tex("lx_stern"), Vector2(640, 360))
	# paper lantern strings: upper deck + a diagonal string from the crane post down to the stern rail
	_deck_wire = _node(_ext)
	_deck_wire.draw.connect(_draw_lanterns)
	_deck_glow = _node(_ext)
	_deck_glow.material = _add_mat
	_deck_glow.draw.connect(_draw_lantern_glow)
	var spans := [[Vector2(-10, 140), Vector2(430, 150), 18.0], [Vector2(222, 30), Vector2(566, 288), 26.0]]
	var idx := 0
	for sp in spans:
		var a: Vector2 = sp[0]
		var b: Vector2 = sp[1]
		var sag: float = sp[2]
		var n := int(a.distance_to(b) / 36.0)
		for i in range(1, n):
			var u := float(i) / n
			var p := a.lerp(b, u) + Vector2(0, sag * 4.0 * u * (1.0 - u))
			_lanterns.append({"pos": p, "red": idx % 3 != 1, "dead": idx % 9 == 4, "on": 10.1 + _rng.randf_range(0.0, 0.6),
				"ph": _rng.randf() * TAU, "die": -1.0})
			idx += 1
	if _lanterns.size() > 6:
		_lanterns[6]["die"] = 12.4
	_wheel = _spr(_ext, _tex("wheel_big"), WHEEL_C, WHEEL_SC * 0.5)
	_wheel.modulate = Color(0.86, 0.86, 0.86)
	_wheel_stain = _spr(_wheel, _tex("stain_big"))
	_wheel_stain.modulate.a = 0.0
	_spr(_ext, _tex("lx_stern_fg"), Vector2(640, 360))
	_streams = _node(_ext)
	_streams.draw.connect(_draw_streams)
	_water = _node(_ext)
	_water.draw.connect(_draw_water)
	_cap = _spr(_ext, _tex("cap_big"), Vector2(528, 590), 0.26)
	_cap.modulate = Color(1.4, 1.4, 1.45)
	_cap.visible = false
	_cap_water = _node(_ext)
	_cap_water.draw.connect(_draw_cap_water)
	_splash = _node(_ext)
	_splash.draw.connect(_draw_splash)
	# the hanging cradle on the crane
	_pend_ext = _node(_ext, PIVOT)
	_pend_ext.draw.connect(_draw_chain.bind(_pend_ext, CHAIN_L, CR_EXT_SC))
	_cr_ext = _make_cradle(_pend_ext, CR_EXT_SC, false)
	(_cr_ext["node"] as Node2D).position = Vector2(0, CHAIN_L)
	_lamp_ext_glow = _spr(_ext, _glow_tex, LANTERN_EXT + Vector2(0, 6), 1.6)
	_lamp_ext_glow.material = _add_mat
	_lamp_ext_glow.modulate = Color(1.0, 0.85, 0.6, 0.55)
	var hook := _node(_ext)
	hook.draw.connect(func() -> void: hook.draw_line(Vector2(300, 47), LANTERN_EXT + Vector2(0, -22), Color(0.07, 0.07, 0.07), 2.0))
	_lamp_ext = _spr(_ext, _tex("lx_lantern"), LANTERN_EXT, 0.5)
	_mist = _node(_ext)
	_mist.draw.connect(_draw_mist)


func _build_close() -> void:
	_close = _node(_world)
	_bg_rect(_close, Color("020404"))
	_cl_cave = _spr(_close, _tex("lx_cave"), Vector2(640, 330), 1.35)
	_cl_cave.modulate = Color(0.42, 0.42, 0.42)
	_cl_wheel = _spr(_close, _tex("wheel_big"), Vector2(1260, 470), 0.9)
	_cl_wheel.modulate = Color(0.2, 0.2, 0.2)
	_lamp_cl_wash = _spr(_close, _glow_tex, Vector2(560, 380), 9.0)
	_lamp_cl_wash.material = _add_mat
	_lamp_cl_wash.modulate = Color(0.55, 0.45, 0.32, 0.22)
	_pend_cl = _node(_close, CL_PIVOT)
	_pend_cl.draw.connect(_draw_chain.bind(_pend_cl, CL_LEN, CL_SC))
	_cr_cl = _make_cradle(_pend_cl, CL_SC, true)
	(_cr_cl["node"] as Node2D).position = Vector2(0, CL_LEN)
	_lamp_cl_glow = _spr(_close, _glow_tex, LANTERN_CL + Vector2(0, 10), 3.0)
	_lamp_cl_glow.material = _add_mat
	_lamp_cl_glow.modulate = Color(1.0, 0.85, 0.6, 0.6)
	var hook := _node(_close)
	hook.draw.connect(func() -> void: hook.draw_line(Vector2(LANTERN_CL.x, -300), LANTERN_CL + Vector2(0, -50), Color(0.06, 0.06, 0.06), 4.0))
	_lamp_cl = _spr(_close, _tex("lx_lantern"), LANTERN_CL, 1.0)
	_cl_fx = _node(_close)
	_cl_fx.material = _add_mat
	_cl_fx.draw.connect(_draw_dust)


## A layered hanging cradle (back, Tumble, quilt, front, cracks) + the Snapjaw-head mobile.
func _make_cradle(parent: Node2D, sc: float, big: bool) -> Dictionary:
	var n := _node(parent)
	n.scale = Vector2(sc, sc)
	var d := {"node": n, "big": big}
	d["back"] = _spr(n, _tex("lx_cradle_back"), CR_SPR)
	var tu := _spr(n, _tex("tumble_sad"), TUMBLE_POS, TUMBLE_SC)
	if big:
		tu.material = _lit_mat(Vector2(0.22, 0.02), 1.3, Color(1.0, 0.93, 0.8), Color(0.05, 0.06, 0.07), 0.55, 1.55)
	else:
		tu.material = _lit_mat(Vector2(0.3, -0.1), 1.4, Color(1.0, 0.93, 0.8), Color(0.05, 0.06, 0.07), 0.55, 1.2)
	d["tumble"] = tu
	d["quilt"] = _spr(n, _tex("lx_quilt"), CR_SPR)
	var qe := _spr(n, _tex("lx_quilt_empty"), CR_SPR)
	qe.visible = false
	d["quilt_empty"] = qe
	d["front"] = _spr(n, _tex("lx_cradle_front"), CR_SPR)
	var cr := _spr(n, _tex("lx_cradle_crack"), CR_SPR)
	cr.modulate.a = 0.0
	d["crack"] = cr
	# the mobile: hub + arms + strings (drawn) and five tiny Snapjaw heads
	var mob := _node(n)
	var lines := _node(mob)
	var heads: Array = []
	var glows: Array = []
	for i in 5:
		var h := _spr(mob, _tex("lx_mob_side"), Vector2.ZERO, MOB_SC)
		h.offset = Vector2(0, 75)
		var g := _spr(h, _glow_tex, MOB_EYE, 0.32)
		g.material = _add_mat
		g.modulate = Color(1.0, 0.1, 0.06, 0.0)
		heads.append(h)
		glows.append(g)
	d["mob"] = mob
	d["mob_lines"] = lines
	d["heads"] = heads
	d["glows"] = glows
	lines.draw.connect(_draw_mobile.bind(d))
	return d


func _build_snap() -> void:
	_snap = _node(_world)
	_snap_sil = _spr(_snap, _tex("lx_snap_sil"), Vector2(640, 400))
	_snap_sil.visible = false
	_snap_eye_glow = _spr(_snap, _glow_tex, Vector2(900, 300), 1.0)
	_snap_eye_glow.material = _add_mat
	_snap_eye_glow.modulate = Color(1.0, 0.08, 0.05, 0.6)
	_snap_eye = _spr(_snap, _tex("lx_eye"), Vector2(900, 300), 0.3)
	_snap_close = _spr(_snap, _tex("snapjaw_happy"), Vector2(640, 452), 1.75)
	_snap_close_mat = _lit_mat(Vector2(0.5, 1.1), 1.7, Color(1.0, 0.12, 0.08), Color(0.04, 0.02, 0.03), 0.25, 2.2)
	_snap_close.material = _snap_close_mat
	_snap_close.visible = false


func _build_key() -> void:
	_keyset = _node(_world)
	_bg_rect(_keyset, Color("050606"))
	for g in [[Vector2(220, 300), 1.0], [Vector2(370, 470), 0.72], [Vector2(150, 520), 0.55]]:
		var s := _spr(_keyset, _tex("lx_gear"), g[0], g[1])
		s.modulate = Color(0.75, 0.75, 0.75)
		_gears.append(s)
	_spr(_keyset, _tex("lx_gearbox"), Vector2(640, 360))
	_dial = _node(_keyset)
	_dial.draw.connect(_draw_dial)
	_key = _spr(_keyset, _tex("lx_key"), Vector2(640, 360), 0.95)


func _show_set(which: String) -> void:
	_ext.visible = which == "ext"
	_close.visible = which == "close"
	_snap.visible = which == "snap"
	_keyset.visible = which == "key"


# ================================================================== deterministic decoration
func _make_decor() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 9090
	for k in 90:
		var y := WATER_Y + 6.0 + pow(r.randf(), 1.6) * 170.0
		_wdash.append([r.randf_range(-300.0, 1580.0), y, r.randf_range(14.0, 70.0) * (1.0 + (y - WATER_Y) / 120.0), r.randf() * TAU, r.randf_range(-4.0, 4.0)])
	# reflections under the lit windows, the deck lanterns and the crane lantern
	for x in [120.0, 360.0, 64.0, 300.0, 452.0, 196.0]:
		_wrefl.append(x)
	for k in 6:
		_fog.append([r.randf_range(-200.0, 1400.0), r.randf_range(500.0, 580.0), r.randf_range(6.0, 11.0), r.randf_range(6.0, 16.0) * (1 if k % 2 else -1)])
	for i in 40:
		_dust.append([Vector2(r.randf_range(240, 760), r.randf_range(0, 720)), Vector2(r.randf_range(-5, 5), r.randf_range(-7, 7)),
			r.randf_range(0.8, 2.2), r.randf() * TAU])
	# red water on the lens after the final thud (screen space)
	for k in 8:
		# keep the middle of the frame readable: drops land towards the edges
		var p := Vector2(r.randf_range(70.0, 1210.0), r.randf_range(30.0, 440.0))
		if absf(p.x - 640.0) < 260.0 and p.y > 120.0:
			p.x += 300.0 if p.x > 640.0 else -300.0
		_lens_drops.append({"p": p, "r": r.randf_range(8.0, 22.0), "len": r.randf_range(70.0, 260.0), "tau": r.randf_range(0.9, 2.2),
			"d": r.randf_range(0.0, 0.3), "sat": r.randi_range(2, 5), "seed": r.randi()})
	for i in WHEEL_N:
		_pad_prev.append(-1.0)


## Swing peaks of the cradle (exterior angle in degrees, + = towards the wheel). Gentle rocking, the
## wind-up frenzy (THUD_T are peaks into the wheel), then an empty, slowly settling swing.
func _build_swing() -> void:
	var t := 31.7
	var s := 1.0
	while t > 7.0:
		_peaks.push_front([t, 4.0 * s])
		t -= 1.25
		s = -s
	for p in [[32.5, -7.0], [33.3, 10.0], [34.05, -13.0], [34.75, 16.0], [35.4, -18.0], [THUD_T[0], 26.0],
			[36.6, -20.0], [37.2, 17.0], [37.8, -22.0], [THUD_T[1], 26.0], [39.0, -22.0], [39.6, 19.0], [40.2, -24.0], [THUD_T[2], 28.0]]:
		_peaks.append(p)
	var amp := 14.0
	t = 41.6
	s = -1.0
	var half := 0.85
	while t < 66.0:
		_peaks.append([t, amp * s])
		amp = maxf(1.6, amp * 0.8)
		half = minf(1.45, half * 1.12)
		t += half
		s = -s


func _swing(t: float) -> float:
	var n := _peaks.size()
	if n == 0:
		return 0.0
	if t <= float(_peaks[0][0]):
		return float(_peaks[0][1])
	if t >= float(_peaks[n - 1][0]):
		return float(_peaks[n - 1][1])
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if float(_peaks[mid][0]) <= t:
			lo = mid
		else:
			hi = mid
	var t0: float = _peaks[lo][0]
	var t1: float = _peaks[hi][0]
	var k := (t - t0) / maxf(0.001, t1 - t0)
	return lerpf(float(_peaks[lo][1]), float(_peaks[hi][1]), 0.5 - 0.5 * cos(PI * k))


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


## Schedules an extra event while the timeline is running (inserted in order).
func _at_late(time: float, c: Callable) -> void:
	var e := [time, _events.size() + 1000, c]
	var pos := _ev_i
	while pos < _events.size() and float(_events[pos][0]) <= time:
		pos += 1
	_events.insert(pos, e)


## Keyframe a property (a script var, or "node_prop:sub") from -> to over dur, starting now (event time).
func _anim(obj: Object, prop: String, from: Variant, to: Variant, dur: float, ease: int = 1, delay: float = 0.0) -> void:
	_kill(obj, prop)
	_anims.append([obj, prop, from, to, _ev_time + delay, dur, ease])
	if delay <= 0.0 and _vt >= _ev_time:
		_set_prop(obj, prop, from)


## Remove pending keyframes of a property (so a direct assignment sticks).
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


func _ease(k: float, e: int) -> float:
	match e:
		0:
			return k
		2:
			return 1.0 - pow(1.0 - k, 3.0)
		3:
			return k * k * k
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
		if _vt < t0:
			keep.append(a)
			continue
		var k := 1.0 if dur <= 0.0 else clampf((_vt - t0) / dur, 0.0, 1.0)
		_set_prop(obj, a[1], lerp(a[2], a[3], _ease(k, a[6])))
		if k < 1.0:
			keep.append(a)
	_anims = keep


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


func _cam_push(c0: Vector2, z0: float, c1: Vector2, z1: float, dur: float) -> void:
	_cam_cut(c0, z0)
	_cam_to_c = c1
	_cam_to_z = z1
	_cam_t1 = _ev_time + dur


# ================================================================== the timeline
func _schedule() -> void:
	# ---- 0.0  cold open: PLEASE STAND BY, somebody winding a music box behind the static
	_at(0.0, _ev_standby)
	_at(0.35, func() -> void: _anim(self, "_fx_static", 1.0, 0.42, 0.5, 2))
	_at(0.6, func() -> void: _sfx("lx_windup", 1.0, -2.0))
	_at(2.95, _ev_subliminal)
	_at(3.45, _ev_standby_glitch)
	_at(3.9, _ev_black_cut)
	# ---- 4.0  title card
	_at(4.0, _ev_title)
	_at(4.2, _ev_title_exec)
	_at(5.7, func() -> void: _title_name_t0 = _ev_time)
	_at(7.3, _ev_title_act)
	_at(9.3, func() -> void: _anim(self, "_fx_tear", 0.05, 0.7, 0.6, 3))
	_at(9.9, _ev_title_out)
	# ---- 10.0 the paddle wheel of the Mudlark, turning over black water
	_at(10.0, _ev_ext_on)
	_at(10.7, func() -> void: _cc_show("[ A LULLABY PLAYS ]", 2.4))
	_at(12.4, func() -> void: _sfx("lx_sputter", 1.0, -4.0))
	_at(13.3, func() -> void: _stutter(4))
	_at(13.7, func() -> void: _sfx("lx_wheel", 0.96, -3.0))
	_at(14.4, _ev_reveal_cradle)
	_at(16.7, func() -> void: _glitch(0.6))
	# ---- 17.0 Tumble in the cradle, wide awake
	_at(17.0, _ev_close_on)
	var hb := 17.45
	while hb < 21.4:
		_at(hb, func() -> void: _sfx("hx_heartbeat", 1.05, -1.0))
		hb += 0.78
	_at(18.6, func() -> void: _sfx("hx_whisper", 0.85, -3.0))
	_at(19.7, _ev_lamp_flicker)
	_at(19.84, _ev_lamp_back)
	_at(20.8, func() -> void: _stutter(3))
	_at(20.95, func() -> void: _cam_move(Vector2(640, 168), 1.75, 0.55))
	_at(21.7, _ev_lamp_die)
	# ---- 22.5 Snapjaw in the dark
	_at(22.5, _ev_eye_open)
	_at(23.5, _ev_eye_blink)
	_at(24.0, func() -> void: _choppy = 8.0)
	var steps := [24.1, 24.95, 25.8, 26.55]
	for i in steps.size():
		_at(steps[i], _ev_snap_step.bind(i))
	_at(25.3, _ev_snap_reveal)
	_at(25.42, _ev_snap_hide)
	_at(25.56, _ev_snap_reveal)
	_at(25.62, _ev_snap_hide)
	_at(26.9, _ev_laugh)
	_at(27.2, func() -> void: _choppy = 0.0)
	_at(27.2, func() -> void: _sfx("hx_swell", 1.0, 0.0))
	_at(29.2, _ev_jump1)
	_at(29.8, _ev_jump2)
	_at(30.15, _ev_black_cut)
	# ---- 30.8 the giant wind-up key
	_at(30.8, _ev_key_on)
	for i in 3:
		_at(30.95 + i * 0.42, _ev_crank.bind(i))
	_at(32.1, _ev_key_release)
	# ---- 32.6 rocking higher and higher towards the wheel
	_at(32.6, _ev_rock_ext)
	_at(34.3, _ev_rock_close)
	_at(35.3, _ev_rock_ext2)
	for i in 3:
		_at(float(THUD_T[i]) - 0.04, _ev_thud.bind(i))
	_at(THUD_T[0] + 0.5, _ev_after_close.bind(0))
	_at(37.7, _ev_rock_ext3)
	_at(THUD_T[1] + 0.5, _ev_after_close.bind(1))
	_at(40.1, _ev_rock_ext4)
	_at(THUD_T[2] + 0.12, _ev_silence)
	# ---- 41.6 red water, silence
	_at(41.6, _ev_red_wheel)
	for t in [42.3, 43.1, 43.6]:
		_at(t, func() -> void: _sfx("lx_drip", randf_range(0.85, 1.15), -2.0))
	_at(42.2, func() -> void: _cc_show("[ SILENCE ]", 1.5))
	_at(43.9, _ev_red_wide)
	_at(46.2, _ev_nightcap)
	_at(46.4, func() -> void: _sfx("lx_winddown", 1.0, 0.0))
	_at(46.7, func() -> void: _cc_show("[ MUSIC BOX WINDS DOWN ]", 2.4))
	_at(47.6, func() -> void: _stutter(3))
	# ---- 48.6 the empty cradle; the mobile turns
	_at(48.6, _ev_empty_close)
	_at(50.4, _ev_heads_turn)
	_at(51.2, _ev_head_close)
	_at(52.7, _ev_smash)
	# ---- 53.2 SWEET DREAMS / TRANSMISSION ENDED
	_at(53.2, _ev_sweet)
	_at(55.5, _ev_static_out)
	_at(56.4, _ev_trans_end)
	_at(58.2, func() -> void: _anim(self, "_fx_bright", 1.0, 0.0, 0.5, 0))
	# creaks + chain rattles on the swing peaks while the cradle is on screen
	for p in _peaks:
		var pt: float = p[0]
		var amp: float = absf(float(p[1]))
		if (pt > 14.0 and pt < 21.7) or (pt > 32.4 and pt < 40.9) or (pt > 43.8 and pt < 52.7):
			_at(pt - 0.12, _ev_creak.bind(amp))
	_events.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))


# ------------------------------------------------------------------ effects helpers
func _glitch(amount: float) -> void:
	_g_tear = maxf(_g_tear, amount)
	_hud_glitch = maxf(_hud_glitch, amount * 0.6)


func _stutter(frames: int) -> void:
	_stutter_frames = maxi(_stutter_frames, frames)
	_glitch(0.35)


func _vroll_slip(amount: float, dur: float) -> void:
	_anim(self, "_fx_vroll", amount, 0.0, dur, 2)


func _do_flash(a: float, dur: float, col: Color = Color(0.85, 1.0, 0.98)) -> void:
	_flash_col = col
	_anim(self, "_flash_a", a, 0.0, dur, 2)


func _cc_show(text: String, dur: float) -> void:
	_cc_label.text = text
	_cc_label.reset_size()
	var sz := _cc_label.size
	_cc_label.position = Vector2(640 - sz.x * 0.5, 612 - sz.y * 0.5)
	_cc_box.position = _cc_label.position - Vector2(14, 4)
	_cc_box.size = sz + Vector2(28, 8)
	_cc.visible = true
	_cc_until = _ev_time + dur


func _set_tumble(expr: String) -> void:
	_tumble_expr = expr
	for d in [_cr_ext, _cr_cl]:
		(d["tumble"] as Sprite2D).texture = _tex("tumble_" + expr)


func _set_empty(on: bool) -> void:
	_cradle_empty = on
	for d in [_cr_ext, _cr_cl]:
		(d["tumble"] as Sprite2D).visible = not on
		(d["quilt"] as Sprite2D).visible = not on
		(d["quilt_empty"] as Sprite2D).visible = on


func _ev_creak(amp: float) -> void:
	if not (_ext.visible or _close.visible) or _black.visible:
		return
	var k := clampf(amp / 26.0, 0.0, 1.0)
	_sfx("lx_creak", randf_range(0.9, 1.06) + k * 0.25, lerpf(-9.0, -1.0, k))
	if k > 0.45:
		_sfx("lx_chain", randf_range(0.9, 1.1), lerpf(-10.0, -3.0, k))


# ------------------------------------------------------------------ events: cold open + title
func _ev_standby() -> void:
	_show_set("none")
	_standby.visible = true
	_put("_fx_static", 1.0)
	_put("_fx_desat", 0.55)
	_put("_fx_tear", 0.18)
	_sfx("hx_standby", 1.0, 0.0)


func _ev_subliminal() -> void:
	_sub_face.visible = true
	_subliminal_until = _ev_time + 0.1
	_g_static = 0.5
	_sfx("hx_static_burst", 0.7, -8.0)


func _ev_standby_glitch() -> void:
	_vroll_slip(0.45, 0.4)
	_anim(self, "_fx_static", 0.4, 1.0, 0.3, 3)
	_glitch(0.8)
	_sfx("hx_static_burst", 1.0, 0.0)


func _ev_black_cut() -> void:
	_show_set("none")
	_standby.visible = false
	_title.visible = false
	_black.visible = true
	_put("_fx_static", 0.0)
	_g_static = 0.0
	_cc.visible = false


func _ev_title() -> void:
	_black.visible = true
	_title.visible = true
	_put("_fx_static", 0.0)
	_put("_fx_desat", 0.25)
	_put("_fx_tear", 0.04)
	_put("_fx_chroma", 2.5)
	if not _ff:
		Audio.play_music(MUSIC_ID, 0.4)


func _ev_title_exec() -> void:
	_title_exec_t0 = _ev_time
	_sfx("hx_sting", 1.0, 0.0)
	_glitch(0.5)


func _ev_title_act() -> void:
	_title_act_t0 = _ev_time
	_sfx("lx_creak", 0.7, -6.0)


func _ev_title_out() -> void:
	_title.visible = false
	_put("_fx_tear", 0.05)
	_sfx("hx_static_burst", 1.2, -6.0)
	_g_static = 0.8


# ------------------------------------------------------------------ events: the wheel at night
func _ev_ext_on() -> void:
	_black.visible = false
	_show_set("ext")
	_hud.visible = true
	_put("_fx_desat", 0.86)
	_put("_fx_tracking", 0.35)
	_put("_fx_chroma", 2.2)
	_put("_ext_level", 0.0)
	_anim(self, "_ext_level", 0.15, 0.86, 1.3, 2)
	_cam_push(Vector2(760, 392), 1.12, Vector2(800, 410), 1.24, 4.4)
	_sway = 2.4
	_wheel_speed = 0.22
	_sfx("lx_wheel", 1.0, 0.0)
	_sfx("lx_lapping", 1.0, 0.0)
	_sfx("hx_wind", 1.0, -4.0)
	_vroll_slip(0.2, 0.25)


func _ev_reveal_cradle() -> void:
	_cam_move(Vector2(392, 410), 1.55, 2.4)
	_sfx("lx_lapping", 0.92, -3.0)
	_anim(self, "_lamp_level", 0.1, 1.0, 0.9, 3)


# ------------------------------------------------------------------ events: Tumble in the cradle
func _ev_close_on() -> void:
	_show_set("close")
	_set_tumble("sad")
	_lamp_level = 1.0
	_cam_push(Vector2(640, 400), 1.0, Vector2(640, 386), 1.16, 3.8)
	_sway = 1.6
	_tumble_shake = 1.2
	_mob_speed = 0.35
	_put("_fx_desat", 0.9)
	_sfx("lx_sputter", 0.8, -6.0)
	_glitch(0.4)


func _ev_lamp_flicker() -> void:
	_lamp_level = 0.0
	_sfx("lx_sputter", 1.1, -3.0)


func _ev_lamp_back() -> void:
	_lamp_level = 1.0
	_set_tumble("shock")
	_tumble_shake = 2.6
	_sfx("hx_heartbeat", 1.2, 0.0)
	_glitch(0.3)


func _ev_lamp_die() -> void:
	_lamp_level = 0.0
	_sfx("lx_sputter", 0.7, 0.0)
	_show_set("none")
	_black.visible = true
	_hud_glitch = 0.4


# ------------------------------------------------------------------ events: Snapjaw
func _ev_eye_open() -> void:
	_black.visible = false
	_show_set("snap")
	_cam_cut(Vector2(640, 360), 1.0)
	_sway = 1.0
	_snap_close.visible = false
	_eye_scale = 0.3
	_snap_eye.position = Vector2(910, 300)
	_anim(self, "_eye_open", 0.0, 1.0, 0.5, 2)
	_put("_fx_desat", 0.75)
	_sfx("hx_servo", 0.9, 0.0)


func _ev_eye_blink() -> void:
	_anim(self, "_eye_open", 0.05, 1.0, 0.22, 2)
	_sfx("hx_servo", 1.3, -6.0)


func _ev_snap_step(i: int) -> void:
	var k := float(i + 1) / 4.0
	_eye_scale = lerpf(0.3, 1.05, k * k)
	_snap_eye.position = Vector2(910, 300).lerp(Vector2(700, 330), k)
	_shake = 4.0 + i * 3.0
	_sfx("hx_thud", 0.55, -9.0 + i * 1.5)


func _ev_snap_reveal() -> void:
	_snap_sil.visible = true
	_sfx("hx_buzz", 1.4, -6.0)
	_g_static = 0.15


func _ev_snap_hide() -> void:
	_snap_sil.visible = false


func _ev_laugh() -> void:
	_sfx("lx_laugh", 1.0, 0.0)
	_cc_show("[ LAUGHTER ]", 2.2)
	_glitch(0.5)


func _ev_jump1() -> void:
	_snap_eye.visible = false
	_snap_eye_glow.visible = false
	_snap_sil.visible = false
	_snap_close.visible = true
	_snap_close.texture = _tex("snapjaw_happy")
	_snap_close_mat.set_shader_parameter("light_uv", Vector2(0.5, 1.1))
	_snap_close_mat.set_shader_parameter("radius", 1.7)
	_snap_close.position = Vector2(640, 470)
	_snap_close.scale = Vector2(1.75, 1.75)
	_anim(_snap_close, "scale", Vector2(1.75, 1.75), Vector2(1.95, 1.95), 0.6, 0)
	_shake = 16.0
	_g_tear = 0.12
	_hud_glitch = 1.0
	_g_static = 0.12
	_do_flash(0.5, 0.25, Color(1.0, 0.2, 0.15))
	_sfx("hx_drone_hit", 1.0, 0.0)
	_sfx("hx_static_burst", 0.8, -4.0)


func _ev_jump2() -> void:
	_snap_close.texture = _tex("snapjaw_angry")
	_snap_close_mat.set_shader_parameter("light_uv", Vector2(0.58, 0.55))
	_snap_close_mat.set_shader_parameter("radius", 1.1)
	_snap_close.scale = Vector2(2.7, 2.7)
	_snap_close.position = Vector2(520, 690)
	_shake = 18.0
	_g_tear = 0.2
	_hud_glitch = 1.0
	_at_late(_ev_time + 0.22, func() -> void: _glitch(1.0))
	_sfx("hx_static_burst", 0.6, 0.0)


# ------------------------------------------------------------------ events: the wind-up key
func _ev_key_on() -> void:
	_black.visible = false
	_snap_eye.visible = true
	_snap_eye_glow.visible = true
	_show_set("key")
	_put("_fx_desat", 0.86)
	_cam_push(Vector2(640, 360), 1.12, Vector2(640, 356), 1.22, 1.4)
	_sway = 1.2
	_key_speed = 0.0
	_needle = 0.04
	_sfx("hx_servo", 0.6, -4.0)


func _ev_crank(i: int) -> void:
	_anim(self, "_key_ang", _key_ang, _key_ang + 1.2, 0.2, 2)
	_anim(self, "_needle", _needle, 0.1 + 0.12 * (i + 1), 0.25, 2)
	_shake = 5.0 + i * 2.0
	_sfx("lx_ratchet", 1.0 + i * 0.06, -1.0)
	_glitch(0.2)


func _ev_key_release() -> void:
	_anim(self, "_key_speed", 0.0, 16.0, 1.0, 3)
	_anim(self, "_needle", _needle, 1.0, 0.9, 2)
	_cam_move(Vector2(640, 360), 1.38, 0.5)
	_shake = 9.0
	_sfx("lx_chain", 0.8, 0.0)
	_sfx("hx_servo", 1.4, -2.0)
	_glitch(0.5)


# ------------------------------------------------------------------ events: the swings
func _ev_rock_ext() -> void:
	_show_set("ext")
	_put("_ext_level", 0.8)
	_lamp_level = 1.0
	_set_tumble("shock")
	_tumble_shake = 2.0
	_wheel_speed = 0.42
	_anim(self, "_mob_speed", 0.6, 3.0, 2.0, 1)
	_cam_push(Vector2(520, 380), 1.34, Vector2(548, 372), 1.4, 1.7)
	_sway = 2.2
	_glitch(0.3)
	_sfx("lx_wheel", 1.12, 0.0)


func _ev_rock_close() -> void:
	_show_set("close")
	_cam_push(Vector2(640, 392), 1.12, Vector2(640, 380), 1.2, 1.0)
	_tumble_shake = 2.8
	_sway = 2.6
	_glitch(0.3)


func _ev_rock_ext2() -> void:
	_show_set("ext")
	_cam_push(Vector2(500, 360), 1.42, Vector2(560, 350), 1.52, 0.7)
	_sway = 2.6
	_sfx("lx_wheel", 1.18, 0.0)


func _ev_thud(i: int) -> void:
	_black.visible = true
	_show_set("none")
	_sfx("lx_thud", 1.0 - i * 0.05, i * 1.2)
	_shake = 14.0 + i * 6.0
	_jolt = 1.0
	_glitch(0.45 + i * 0.2)
	_hud_glitch = 0.8
	_cc.visible = false
	if i == 2:
		_set_empty(true)
		_sfx("lx_splash", 1.0, 0.0)
		_do_flash(0.5, 0.3, Color(1.0, 0.22, 0.18))
		_red_k = 1.0
		_red_t0 = _ev_time
		_stain_a = 1.0
		_cap_t0 = _ev_time + 0.4
	else:
		_crack_a = 0.6 if i == 0 else 1.0
		_at_late(_ev_time + 0.2, func() -> void: _sfx("lx_creak", 1.5, -4.0))


func _ev_after_close(i: int) -> void:
	_black.visible = false
	_show_set("close")
	_set_tumble("shock")
	_tumble_shake = 3.4 + i
	_cam_push(Vector2(640, 380), 1.18, Vector2(640, 370), 1.25, 1.1)
	_cam_roll = 0.05 if i == 0 else -0.08
	_shake = 10.0
	_sway = 3.0
	if i == 1:
		_anim(self, "_mob_speed", 3.0, 7.5, 0.6, 2)
	_glitch(0.5)
	_sfx("lx_chain", 1.2, -2.0)


func _ev_rock_ext3() -> void:
	_black.visible = false
	_show_set("ext")
	_cam_roll = 0.0
	_cam_push(Vector2(520, 360), 1.46, Vector2(570, 350), 1.56, 0.7)
	_sfx("lx_wheel", 1.24, 0.0)
	_glitch(0.3)


func _ev_rock_ext4() -> void:
	_black.visible = false
	_show_set("ext")
	_cam_roll = 0.0
	_cam_push(Vector2(640, 374), 1.0, Vector2(630, 370), 1.06, 0.7)
	_choppy = 10.0
	_wheel_speed = 0.55
	_sfx("lx_wheel", 1.3, 0.0)
	_glitch(0.4)


func _ev_silence() -> void:
	Audio.stop_music(0.05)
	_choppy = 0.0
	_put("_fx_tear", 0.02)


# ------------------------------------------------------------------ events: afterwards
func _ev_red_wheel() -> void:
	_black.visible = false
	_show_set("ext")
	_lens_t0 = _ev_time
	_wheel_speed = 0.2
	_put("_ext_level", 0.7)
	_cam_push(Vector2(940, 470), 2.0, Vector2(920, 462), 2.12, 2.3)
	_sway = 1.2
	_hud_glitch = 0.8
	_sfx("lx_wheel", 0.82, -2.0)
	_sfx("lx_lapping", 0.9, 0.0)


func _ev_red_wide() -> void:
	_show_set("ext")
	_cam_push(Vector2(600, 392), 1.1, Vector2(580, 392), 1.16, 2.3)
	_sway = 1.0
	_glitch(0.25)
	_sfx("hx_wind", 0.85, -4.0)


func _ev_nightcap() -> void:
	_show_set("ext")
	var cp := _cap_pos(_ev_time)
	_cam_push(cp + Vector2(10, -10), 2.7, cp + Vector2(-12, -12), 2.85, 2.4)
	_sway = 0.8
	_glitch(0.2)


func _ev_empty_close() -> void:
	_show_set("close")
	_set_empty(true)
	_lamp_level = 0.75
	_tumble_shake = 0.0
	_mob_front = false
	_anim(self, "_mob_speed", 0.7, 0.0, 1.8, 1)
	_cam_push(Vector2(640, 430), 0.98, Vector2(640, 418), 1.04, 1.0)
	_at_late(_ev_time + 1.0, func() -> void: _cam_move(Vector2(640, 150), 1.62, 0.8))
	_cam_roll = 0.0
	_sway = 0.8
	_glitch(0.3)


func _ev_heads_turn() -> void:
	_mob_front = true
	_kill(self, "_mob_speed")
	_mob_speed = 0.0
	_shake = 3.0
	_sfx("lx_turn", 1.0, 0.0)
	_hud_glitch = 0.6


func _ev_head_close() -> void:
	# push in on the head that hangs nearest the camera
	var best := _front_head_pos(_cr_cl)
	_cam_push(best + Vector2(4, 30), 3.0, best + Vector2(4, 24), 3.5, 1.4)
	_sway = 0.6
	_sfx("hx_sting", 1.15, -1.0)
	_glitch(0.6)
	_hud_glitch = 1.0


func _ev_smash() -> void:
	_show_set("none")
	_black.visible = true
	_hud.visible = false
	_cc.visible = false
	_put("_fx_tear", 0.0)
	_sfx("lx_thud", 0.62, -4.0)


func _ev_sweet() -> void:
	_sweet_t0 = _ev_time
	_put("_fx_tear", 0.12)
	_put("_fx_desat", 0.2)
	_sfx("lx_laugh", 0.78, -6.0)
	_glitch(0.6)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	_sweet_drips.clear()
	for k in 22:
		_sweet_drips.append({"u": r.randf(), "len": r.randf_range(20.0, 150.0), "t0": r.randf_range(0.1, 1.3), "tau": r.randf_range(0.5, 1.4),
			"w": r.randf_range(3.0, 7.0)})


func _ev_static_out() -> void:
	_sweet_t0 = -100.0
	_put("_fx_static", 1.0)
	_sfx("hx_static_burst", 1.0, 0.0)
	_sfx("hx_standby", 1.0, -4.0)


func _ev_trans_end() -> void:
	_put("_fx_static", 0.0)
	_put("_fx_tear", 0.03)
	_trans_t0 = _ev_time
	_sfx("hx_end_tone", 1.0, 0.0)


# ================================================================== per-frame
func _process(delta: float) -> void:
	_t += delta
	_fire_events()
	if not _done:
		if _t >= _end_at:
			_finish(false)
		_update_skip(delta)
	_update_all(delta)


func _update_all(delta: float) -> void:
	if _stutter_frames > 0:
		_stutter_frames -= 1
	elif _choppy > 0.0:
		_vt = maxf(_vt, floorf(_t * _choppy) / _choppy)
	else:
		_vt = _t
	var vdt := maxf(0.0, _vt - _vt_prev)
	_vt_prev = _vt
	_update_anims()
	_advance_sim(vdt)
	_update_camera(delta)
	if _ext.visible:
		_update_ext(vdt)
	if _close.visible:
		_update_close(vdt)
	if _snap.visible:
		_update_snap()
	if _keyset.visible:
		_update_key()
	_update_overlays(delta)
	_update_fx(delta)


## Continuous state that must also advance while fast-forwarding (wheel, mobile, key, particles).
func _advance_sim(vdt: float) -> void:
	_wheel_ang = wrapf(_wheel_ang - _wheel_speed * vdt, 0.0, TAU)
	_mob_ang = wrapf(_mob_ang + _mob_speed * vdt, 0.0, TAU)
	_key_ang += _key_speed * vdt
	_gear_ang += (0.4 + _key_speed * 0.35) * vdt
	_jolt = move_toward(_jolt, 0.0, vdt * 1.6)
	_tumble_shake = move_toward(_tumble_shake, 1.0 if _tumble_shake > 1.0 else _tumble_shake, vdt * 0.3)


func _update_camera(delta: float) -> void:
	var k := 1.0
	if _cam_t1 > _cam_t0:
		k = _ease(clampf((_vt - _cam_t0) / (_cam_t1 - _cam_t0), 0.0, 1.0), 1)
	_cam_c = _cam_from_c.lerp(_cam_to_c, k)
	_cam_z = lerpf(_cam_from_z, _cam_to_z, k)
	var sway := Vector2(sin(_vt * 0.83) + 0.5 * sin(_vt * 1.91 + 1.0), sin(_vt * 0.61 + 2.0) + 0.4 * sin(_vt * 1.37)) * _sway
	var rot := (sin(_vt * 0.53) * 0.6 + sin(_vt * 1.21) * 0.4) * 0.0018 * _sway + _cam_roll
	var sh := Vector2.ZERO
	if _shake > 0.05:
		sh = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 10.0))
	_world.scale = Vector2(_cam_z, _cam_z)
	_world.rotation = rot
	_world.position = Vector2(640, 360) - (_cam_c * _cam_z).rotated(rot) + sway + sh


func _lamp_flick() -> float:
	var l := _lamp_level * (1.0 - _lamp_sag)
	if l <= 0.0:
		return 0.0
	var f := 0.86 + 0.08 * sin(_vt * 11.0) * sin(_vt * 3.7) + 0.06 * sin(_vt * 23.0 + 1.0)
	if randf() < 0.03:
		f *= randf_range(0.6, 0.85)
	return l * f


func _swing_rad(t: float) -> float:
	return deg_to_rad(_swing(t))


func _update_ext(vdt: float) -> void:
	var l := _ext_level
	if randf() < 0.02:
		l *= randf_range(0.75, 0.92)
	_ext.modulate = Color(l, l, l)
	_wheel.rotation = _wheel_ang
	_wheel_stain.modulate.a = _stain_a
	# the pendulum
	var th := _swing_rad(_vt)
	_pend_ext.rotation = -th
	var cr: Node2D = _cr_ext["node"]
	cr.rotation = (_swing_rad(_vt - 0.14) - th) * 0.35 + sin(_vt * 40.0) * 0.05 * _jolt
	var lamp := _lamp_flick()
	_lamp_ext_glow.modulate.a = 0.55 * lamp
	_lamp_ext.modulate = Color(0.45 + 0.55 * lamp, 0.45 + 0.55 * lamp, 0.45 + 0.55 * lamp)
	var cl := 0.1 + 0.82 * lamp
	cr.modulate = Color(cl, cl, cl)
	_update_cradle(_cr_ext)
	_pend_ext.queue_redraw()
	# the nightcap bobbing on the water
	if _vt >= _cap_t0:
		_cap.visible = true
		_cap.position = _cap_pos(_vt)
		_cap.rotation = 0.05 * sin(_vt * 0.9) - 0.06
	else:
		_cap.visible = false
	_update_paddles(vdt)
	_update_drops(vdt)
	_deck_wire.queue_redraw()
	_deck_glow.queue_redraw()
	_streams.queue_redraw()
	_water.queue_redraw()
	_cap_water.queue_redraw()
	_splash.queue_redraw()
	_mist.queue_redraw()


func _update_close(vdt: float) -> void:
	var th := _swing_rad(_vt) * CL_SWING
	_pend_cl.rotation = -th
	var cr: Node2D = _cr_cl["node"]
	cr.rotation = (_swing_rad(_vt - 0.14) * CL_SWING - th) * 0.5 + sin(_vt * 40.0) * 0.03 * _jolt
	# the paddle wheel looms in the dark behind, closer on every swing towards it
	var toward := clampf(_swing(_vt) / 26.0, -1.0, 1.0)
	var near := maxf(0.0, toward)
	_cl_wheel.position = Vector2(1300.0 - near * 330.0, 470.0 - near * 40.0) + Vector2(-toward * 40.0, 0)
	_cl_wheel.scale = Vector2.ONE * (0.9 + near * 0.35)
	_cl_wheel.rotation = _wheel_ang
	var wv := 0.14 + near * 0.22
	_cl_wheel.modulate = Color(wv, wv, wv)
	_cl_cave.position = Vector2(640.0 + toward * 50.0, 330.0)
	var lamp := _lamp_flick()
	_lamp_cl_glow.modulate.a = 0.6 * lamp
	_lamp_cl_wash.modulate.a = 0.22 * lamp
	_lamp_cl.modulate = Color(0.4 + 0.6 * lamp, 0.4 + 0.6 * lamp, 0.4 + 0.6 * lamp)
	var lv := 0.32 + 0.68 * lamp
	cr.modulate = Color(lv, lv, lv)
	var tu: Sprite2D = _cr_cl["tumble"]
	var m: ShaderMaterial = tu.material
	m.set_shader_parameter("gain", 0.25 + 1.3 * lamp)
	_update_cradle(_cr_cl)
	_pend_cl.queue_redraw()
	for d in _dust:
		var p: Vector2 = d[0]
		var v: Vector2 = d[1]
		p += (v + Vector2(sin(_vt * 0.7 + float(d[3])) * 5.0, 0)) * vdt
		if p.y < 0:
			p.y += 720
		elif p.y > 720:
			p.y -= 720
		d[0] = p
	_cl_fx.queue_redraw()


func _update_cradle(d: Dictionary) -> void:
	var tu: Sprite2D = d["tumble"]
	if tu.visible:
		var s := _tumble_shake
		tu.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * s / TUMBLE_SC
		tu.scale = Vector2(TUMBLE_SC, TUMBLE_SC * (1.0 + 0.008 * sin(_vt * 2.6)))
	(d["crack"] as Sprite2D).modulate.a = _crack_a
	_update_mobile(d)


func _update_mobile(d: Dictionary) -> void:
	var heads: Array = d["heads"]
	var glows: Array = d["glows"]
	var mob: Node2D = d["mob"]
	var order: Array = []
	var n := heads.size()
	for i in n:
		var a := _mob_ang + TAU * i / n
		var z := sin(a)
		var x := cos(a) * MOB_RX
		var hang := MOB_STR + float(i % 2) * 16.0
		var swing := sin(_vt * 1.7 + i * 1.3) * 3.0 * (0.4 + _mob_speed * 0.2)
		var h: Sprite2D = heads[i]
		h.position = MOB_HUB + Vector2(x + swing, z * MOB_RY + hang)
		var depth := 0.86 + 0.14 * z
		h.scale = Vector2(MOB_SC * depth, MOB_SC * depth)
		var v := lerpf(0.5, 1.0, (z + 1.0) * 0.5)
		h.modulate = Color(v, v, v)
		var g: Sprite2D = glows[i]
		if _mob_front:
			h.texture = _tex("lx_mob_front")
			h.flip_h = false
			h.rotation = 0.0
			g.modulate.a = 0.75 + 0.25 * sin(_vt * 5.0 + i)
		else:
			var face := cos(a)
			if face > 0.55:
				h.texture = _tex("lx_mob_front")
				h.flip_h = false
			elif face < -0.55:
				h.texture = _tex("lx_mob_back")
				h.flip_h = false
			else:
				h.texture = _tex("lx_mob_side")
				h.flip_h = -sin(a) < 0.0
			h.rotation = -_mob_speed * 0.05 * (1.0 if not h.flip_h else -1.0)
			g.modulate.a = 0.0
		order.append([z, h])
	order.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	for k in order.size():
		mob.move_child(order[k][1], k + 1)
	(d["mob_lines"] as Node2D).queue_redraw()


## World position of the centre of the mobile head hanging nearest the camera (close-up cradle).
func _front_head_pos(d: Dictionary) -> Vector2:
	_update_close(0.0)
	var heads: Array = d["heads"]
	var best: Sprite2D = heads[0]
	var bz := -2.0
	for i in heads.size():
		var z := sin(_mob_ang + TAU * i / heads.size())
		if z > bz:
			bz = z
			best = heads[i]
	# the sprite's origin is its string point; the texture centre sits 75 px below it
	return _world.to_local(best.to_global(Vector2(0, 75)))


func _red_r() -> float:
	return 50.0 + 400.0 * (1.0 - exp(-maxf(0.0, _vt - _red_t0) / 3.0))


func _cap_pos(t: float) -> Vector2:
	return Vector2(528.0 - maxf(0.0, t - _cap_t0) * 3.0, 588.0 + sin(t * 1.4) * 2.2)


func _update_paddles(vdt: float) -> void:
	if vdt <= 0.0:
		return
	var a_in := PI - _a_exit
	for k in WHEEL_N:
		var a := wrapf(_wheel_ang + TAU * k / WHEEL_N, 0.0, TAU)
		var prev: float = _pad_prev[k]
		_pad_prev[k] = a
		if prev < 0.0 or absf(prev - a) > 1.0:
			continue
		if prev > a_in and a <= a_in:
			_spawn_splash(WHEEL_C + Vector2(cos(a_in), sin(a_in)) * PAD_R1, 22, 1.0)
		elif prev > _a_exit and a <= _a_exit:
			_spawn_splash(WHEEL_C + Vector2(cos(_a_exit), sin(_a_exit)) * (PAD_R1 - 20.0), 8, -0.6)


func _spawn_splash(at: Vector2, count: int, dirx: float) -> void:
	var red := _red_k > 0.5
	for i in count:
		var p := at + Vector2(randf_range(-30, 26), randf_range(-4, 4))
		var v := Vector2(randf_range(-80, 80) + dirx * -40.0, randf_range(-260, -90) * (1.0 + _wheel_speed))
		_drops.append([p, v, 0.0, randf_range(0.5, 1.0), randf_range(2.0, 4.6), red and randf() < 0.85])
	_rings.append([Vector2(at.x, WATER_Y + 4.0), _vt, randf_range(26.0, 44.0)])


func _update_drops(vdt: float) -> void:
	var keep: Array = []
	for d in _drops:
		d[2] = float(d[2]) + vdt
		var v: Vector2 = d[1]
		v.y += 820.0 * vdt
		d[1] = v
		d[0] = (d[0] as Vector2) + v * vdt
		var p: Vector2 = d[0]
		if p.y > WATER_Y + 3.0 and v.y > 0.0:
			if randf() < 0.15:
				_rings.append([Vector2(p.x, WATER_Y + 3.0), _vt, randf_range(8.0, 16.0)])
			continue
		if float(d[2]) < float(d[3]) * 2.0:
			keep.append(d)
	_drops = keep
	var rk: Array = []
	for r in _rings:
		if _vt - float(r[1]) < 1.6:
			rk.append(r)
	_rings = rk
	# drips from the cave ceiling, now and then
	if randf() < vdt * 0.9:
		_rings.append([Vector2(randf_range(-100, 1380), WATER_Y + randf_range(8, 150)), _vt, randf_range(12.0, 30.0)])


func _update_snap() -> void:
	var s := _eye_scale
	_snap_eye.scale = Vector2(s, s * maxf(0.04, _eye_open))
	var pulse := 0.75 + 0.25 * sin(_vt * 2.1)
	_snap_eye_glow.position = _snap_eye.position
	_snap_eye_glow.scale = Vector2(3.2, 2.2) * s * (0.85 + 0.3 * pulse)
	_snap_eye_glow.modulate.a = 0.6 * _eye_open * pulse
	# the silhouette's eye socket (620, 330 in its 1000x1100 texture) sits on the eye
	var ss := s * 1.33
	_snap_sil.scale = Vector2(ss, ss)
	_snap_sil.position = _snap_eye.position - Vector2(120, -220) * ss
	_snap_sil.modulate = Color(1.6, 1.2, 1.2)
	if _snap_close.visible:
		_snap_close.offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))


func _update_key() -> void:
	_key.rotation = _key_ang
	_key.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * minf(4.0, _key_speed * 0.25)
	for i in _gears.size():
		var g: Sprite2D = _gears[i]
		g.rotation = _gear_ang * (1.0 if i % 2 == 0 else -1.35)
	_dial.queue_redraw()


func _update_overlays(delta: float) -> void:
	if _sub_face.visible and _t > _subliminal_until:
		_sub_face.visible = false
	if _cc.visible and _t > _cc_until:
		_cc.visible = false
	if _title.visible:
		_title.queue_redraw()
		var tn := _vt - _title_name_t0
		if tn >= 0.0:
			var cnt := mini(30, int(tn / 0.045) + 1)
			if cnt > _typed and cnt < 30:
				_typed = cnt
				if cnt % 2 == 0 and not _ff:
					Audio.sfx("tick", 1.5, -15.0)
	if _sweet_t0 > 0.0 or _trans_t0 > 0.0:
		_endtext.queue_redraw()
	if _lens_t0 > 0.0 and _vt - _lens_t0 < 2.9:
		_lens.queue_redraw()
	elif _lens_t0 > 0.0:
		_lens_t0 = -100.0
		_lens.queue_redraw()
	if _hud.visible:
		_hud.queue_redraw()
	_hud_glitch = move_toward(_hud_glitch, 0.0, delta * 1.5)
	_flash.color = Color(_flash_col.r, _flash_col.g, _flash_col.b, _flash_a)


func _update_fx(delta: float) -> void:
	_g_tear = move_toward(_g_tear, 0.0, delta * 2.2)
	_g_static = move_toward(_g_static, 0.0, delta * 3.0)
	if randf() < delta * 0.35:
		_g_tear = maxf(_g_tear, randf_range(0.1, 0.3))
	var tear := _fx_tear + _g_tear
	_vhs_mat.set_shader_parameter("static_amt", clampf(_fx_static + _g_static, 0.0, 1.0))
	_vhs_mat.set_shader_parameter("tear", tear)
	_vhs_mat.set_shader_parameter("vroll", _fx_vroll)
	_vhs_mat.set_shader_parameter("chroma", _fx_chroma + _g_tear * 4.0)
	_vhs_mat.set_shader_parameter("desat", _fx_desat)
	_vhs_mat.set_shader_parameter("grain", _fx_grain)
	_vhs_mat.set_shader_parameter("bright", _fx_bright)
	_vhs_mat.set_shader_parameter("tracking", _fx_tracking + _g_tear * 0.6)
	_vhs_mat.set_shader_parameter("vignette", _fx_vignette)


# ================================================================== drawing
func _ellipse(n: CanvasItem, c: Vector2, r: Vector2, col: Color, wob: float = 0.0, seg: int = 28) -> void:
	if r.x < 0.6 or r.y < 0.6:
		return
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		var w := 1.0 + wob * (sin(3.0 * a + 1.3) * 0.6 + sin(5.0 * a + 0.4) * 0.3 + sin(9.0 * a) * 0.2)
		pts.append(c + Vector2(cos(a) * r.x * w, sin(a) * r.y * w))
	n.draw_colored_polygon(pts, col)


func _ring(n: CanvasItem, c: Vector2, r: Vector2, col: Color, w: float, seg: int = 24) -> void:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	n.draw_polyline(pts, col, w)


## Procedural chain from the pivot (0, 0) down to the ring at (0, length), links scaled like the cradle.
func _draw_chain(n: Node2D, length: float, sc: float) -> void:
	var link := 24.0 * sc
	var w := 13.0 * sc
	var pitch := link * 0.78
	var k := int(length / pitch)
	var dark := Color(0.05, 0.05, 0.05)
	var iron := Color(0.16, 0.17, 0.18)
	var hi := Color(0.45, 0.48, 0.5)
	for i in k:
		var y := (i + 0.5) * pitch
		if y < -n.position.y - 60.0 and sc > 0.5:
			continue
		if i % 2 == 0:
			_ring(n, Vector2(0, y), Vector2(w * 0.5, link * 0.55), dark, maxf(1.0, w * 0.5 + 3.0 * sc), 14)
			_ring(n, Vector2(0, y), Vector2(w * 0.5, link * 0.55), iron, maxf(1.0, w * 0.5), 14)
			_ring(n, Vector2(-0.8 * sc, y - 0.8 * sc), Vector2(w * 0.42, link * 0.5), Color(hi, 0.7), maxf(0.6, 1.6 * sc), 12)
		else:
			n.draw_rect(Rect2(-w * 0.2 - 1.0 * sc, y - link * 0.55, w * 0.4 + 2.0 * sc, link * 1.1), dark)
			n.draw_rect(Rect2(-w * 0.2, y - link * 0.5, w * 0.4, link * 1.0), iron)
			n.draw_rect(Rect2(-w * 0.14, y - link * 0.45, maxf(0.6, 1.6 * sc), link * 0.9), Color(hi, 0.7))


func _draw_mobile(d: Dictionary) -> void:
	var n: Node2D = d["mob_lines"]
	var heads: Array = d["heads"]
	var cnt := heads.size()
	var wood := Color(0.24, 0.17, 0.11)
	var str_col := Color(0.78, 0.74, 0.66, 0.85)
	# arms from the hub, then strings down to every head
	for i in cnt:
		var a := _mob_ang + TAU * i / cnt
		var tip := MOB_HUB + Vector2(cos(a) * MOB_RX, sin(a) * MOB_RY)
		var h: Sprite2D = heads[i]
		n.draw_line(MOB_HUB, tip, Color(0.04, 0.03, 0.02), 8.0)
		n.draw_line(MOB_HUB, tip, wood, 5.0)
		n.draw_line(tip, h.position, str_col, 2.0)
		n.draw_circle(tip, 4.0, Color(0.5, 0.42, 0.24))
	# hub: a little crescent moon ornament on the chain
	n.draw_circle(MOB_HUB, 13.0, Color(0.05, 0.04, 0.03))
	n.draw_circle(MOB_HUB, 10.0, Color(0.7, 0.62, 0.38))
	n.draw_circle(MOB_HUB + Vector2(4, -3), 8.5, Color(0.12, 0.1, 0.08))


func _lantern_level(l: Dictionary) -> float:
	if l["dead"]:
		return 0.0
	if _vt < float(l["on"]):
		return 0.0
	var die: float = l["die"]
	if die > 0.0 and _vt > die:
		return 0.0 if _vt > die + 0.3 else randf() * 0.6
	var ph: float = l["ph"]
	var f := 0.8 + 0.12 * sin(_vt * 7.0 + ph) * sin(_vt * 2.3 + ph * 2.0) + 0.08 * sin(_vt * 17.0 + ph)
	if _vt - float(l["on"]) < 0.35:
		f *= 1.0 if randf() < 0.5 else 0.15
	if fmod(_vt * 0.29 + ph, 1.0) < 0.02:
		f *= 0.3
	return clampf(f, 0.0, 1.0)


func _draw_lanterns() -> void:
	var n := _deck_wire
	for sp in [[Vector2(-10, 140), Vector2(430, 150), 18.0], [Vector2(222, 30), Vector2(566, 288), 26.0]]:
		var a: Vector2 = sp[0]
		var b: Vector2 = sp[1]
		var sag: float = sp[2]
		var pts := PackedVector2Array()
		for i in 21:
			var u := i / 20.0
			pts.append(a.lerp(b, u) + Vector2(0, sag * 4.0 * u * (1.0 - u)))
		n.draw_polyline(pts, Color(0.05, 0.04, 0.03), 1.6)
	for l in _lanterns:
		var p: Vector2 = l["pos"]
		var br := _lantern_level(l)
		var base := Color(0.78, 0.08, 0.06) if l["red"] else Color(0.95, 0.86, 0.66)
		var c := Color(0.1, 0.08, 0.07).lerp(base, 0.25 + 0.75 * br)
		n.draw_line(p, p + Vector2(0, 5), Color(0.05, 0.04, 0.03), 1.0)
		_ellipse(n, p + Vector2(0, 13), Vector2(7, 9), c, 0.0, 16)
		n.draw_line(p + Vector2(-6, 9), p + Vector2(6, 9), Color(0, 0, 0, 0.35), 1.0)
		n.draw_line(p + Vector2(-6, 16), p + Vector2(6, 16), Color(0, 0, 0, 0.35), 1.0)
		n.draw_rect(Rect2(p + Vector2(-4, 3), Vector2(8, 3)), Color(0.06, 0.05, 0.04))
		n.draw_rect(Rect2(p + Vector2(-4, 21), Vector2(8, 2.5)), Color(0.06, 0.05, 0.04))


func _draw_lantern_glow() -> void:
	var n := _deck_glow
	for l in _lanterns:
		var br := _lantern_level(l)
		if br <= 0.02:
			continue
		var col := Color(0.85, 0.16, 0.08, 0.5 * br) if l["red"] else Color(0.8, 0.66, 0.42, 0.42 * br)
		var sz := 70.0
		var p: Vector2 = l["pos"]
		n.draw_texture_rect(_glow_tex, Rect2(p + Vector2(-sz * 0.5, 13.0 - sz * 0.5), Vector2(sz, sz)), false, col)


func _draw_streams() -> void:
	var n := _streams
	var red := _red_k > 0.5
	for k in WHEEL_N:
		var a := wrapf(_wheel_ang + TAU * k / WHEEL_N, 0.0, TAU)
		var since := -1.0
		if a < _a_exit:
			since = _a_exit - a
		elif a > 1.5 * PI:
			since = _a_exit + TAU - a
		if since < 0.0:
			continue
		var tt := since / maxf(0.05, _wheel_speed)
		var wet := exp(-tt / (1.6 if red else 1.1))
		if wet < 0.04:
			continue
		var dir := Vector2(cos(a), sin(a))
		for j in 3:
			var r := lerpf(PAD_R0 + 10.0, PAD_R1 - 6.0, (j + 0.5) / 3.0)
			var p := WHEEL_C + dir * r
			if p.y >= WATER_Y - 4.0:
				continue
			var ln := WATER_Y + 3.0 - p.y
			var wob := sin(_vt * 9.0 + k * 1.7 + j) * 1.5
			var col := Color(BLOOD, 0.85 * wet) if red else Color(WATER_COL, 0.28 * wet)
			var w := (2.2 + j * 0.9) * (0.5 + 0.5 * wet)
			n.draw_line(p, Vector2(p.x + wob, WATER_Y + 3.0), col, w)
			if red:
				n.draw_line(p + Vector2(-w * 0.25, 0), Vector2(p.x + wob - w * 0.25, WATER_Y), Color(BLOOD_H, 0.5 * wet), maxf(1.0, w * 0.3))
			for b in 3:
				var y := p.y + fmod(_vt * 360.0 + j * 53.0 + k * 31.0 + b * 71.0, ln)
				n.draw_circle(Vector2(p.x + wob * (y - p.y) / ln, y), w * 0.75, Color(BLOOD_D, 0.9 * wet) if red else Color(WATER_COL, 0.35 * wet))
		# drips hanging from the tip
		if red:
			var tip := WHEEL_C + dir * (PAD_R1 - 2.0)
			if tip.y < WATER_Y - 10.0:
				_drip(n, tip.x, tip.y, 8.0 + 16.0 * wet, 2.6, wet)


func _draw_water() -> void:
	var n := _water
	var y0 := WATER_Y
	n.draw_rect(Rect2(-400, y0, 2080, 600), Color(0.012, 0.024, 0.027, 0.9))
	n.draw_rect(Rect2(-400, y0 + 22, 2080, 600), Color(0.006, 0.012, 0.014, 0.6))
	# faint sheen of the cave glow just under the surface
	for k in 6:
		n.draw_rect(Rect2(-400, y0 + 1.0 + k * 4.0, 2080, 4.0), Color(0.3, 0.42, 0.42, 0.08 * (1.0 - k / 6.0)))
	# the red spreading from where the cradle went in
	if _red_k > 0.0:
		var rt := maxf(0.0, _vt - _red_t0)
		var rr := _red_r()
		var c := Vector2(630, y0 + 10.0)
		_ellipse(n, c, Vector2(rr, 9.0 + rr * 0.075), Color(BLOOD_D, 0.9 * _red_k), 0.22, 44)
		_ellipse(n, c + Vector2(-rr * 0.08, 1), Vector2(rr * 0.7, 6.0 + rr * 0.05), Color(BLOOD, 0.62 * _red_k), 0.2, 40)
		_ellipse(n, c + Vector2(rr * 0.25, 3), Vector2(rr * 0.18, 2.0 + rr * 0.012), Color(BLOOD_H, 0.45 * _red_k), 0.0, 20)
		for k in 5:
			var ry := y0 + 4.0 + k * 3.5
			var rw := rr * (0.9 - k * 0.15)
			n.draw_line(Vector2(c.x - rw + sin(_vt * 0.8 + k) * 8.0, ry), Vector2(c.x + rw * 0.7, ry), Color(BLOOD_H, 0.22 * _red_k), 1.2)
		# red under the wheel, carried round by the paddles
		_ellipse(n, Vector2(WHEEL_C.x + 30.0, y0 + 8.0), Vector2(200.0, 9.0), Color(BLOOD_D, 0.8 * _red_k), 0.25, 30)
	# surface line + ripple dashes
	var pts := PackedVector2Array()
	for i in 70:
		var x := -400.0 + i * 30.0
		pts.append(Vector2(x, y0 + sin(x * 0.03 + _vt * 1.4) * 1.2))
	n.draw_polyline(pts, Color(0.5, 0.62, 0.62, 0.35), 1.6)
	for d in _wdash:
		var y: float = d[1]
		var depth := clampf((y - y0) / 172.0, 0.0, 1.0)
		var x: float = fposmod(float(d[0]) + sin(_vt * 0.6 + float(d[3])) * 10.0 + _vt * float(d[4]) + 300.0, 1980.0) - 300.0
		var col := Color(0.55, 0.7, 0.7, 0.12 + 0.18 * (1.0 - depth))
		if _red_k > 0.0 and absf(x - 630.0) < _red_r() and depth < 0.3:
			col = Color(BLOOD_H, 0.45)
		n.draw_line(Vector2(x, y), Vector2(x + float(d[2]), y), col, 1.0 + depth * 1.6)
	# broken reflection of the turning wheel: paddles mirrored about the waterline
	for k in WHEEL_N:
		var a := _wheel_ang + TAU * k / WHEEL_N
		for j in 4:
			var r := lerpf(PAD_R0 - 60.0, PAD_R1, j / 3.0)
			var p := WHEEL_C + Vector2(cos(a), sin(a)) * r
			var my := 2.0 * y0 - p.y
			if my < y0 + 3.0 or my > y0 + 170.0:
				continue
			var depth2 := (my - y0) / 170.0
			var wl := (16.0 if j == 3 else 9.0) * (1.0 + depth2)
			var xo := sin(_vt * 2.4 + my * 0.15) * (3.0 + 6.0 * depth2)
			var rc := Color(BLOOD_H, 0.3 * (1.0 - depth2)) if _red_k > 0.5 else Color(0.66, 0.74, 0.74, 0.34 * (1.0 - depth2))
			n.draw_line(Vector2(p.x - wl + xo, my), Vector2(p.x + wl + xo, my), rc, 2.0)
	# reflections of the windows and lanterns: wobbly broken streaks
	for xr in _wrefl:
		var xf: float = xr
		for k in 11:
			var yk := y0 + 6.0 + k * 9.0
			var w := 8.0 + k * 1.8
			var xo := sin(_vt * 2.0 + k * 0.9 + xf) * 4.0
			n.draw_line(Vector2(xf - w * 0.5 + xo, yk), Vector2(xf + w * 0.5 + xo, yk), Color(0.95, 0.8, 0.55, 0.3 * (1.0 - k / 12.0)), 2.0)
	# churn where the paddles bite
	for side: float in [-1.0, 1.0]:
		var cx: float = WHEEL_C.x + side * cos(_a_exit) * PAD_R1
		for k in 7:
			var xx := cx + sin(_vt * 3.0 + k * 1.9) * 18.0 + (k - 3) * 9.0
			var col2 := Color(BLOOD, 0.7) if _red_k > 0.5 else Color(0.78, 0.86, 0.86, 0.34)
			var fw := 10.0 + (k % 2) * 7.0 + 4.0 * sin(_vt * 5.0 + k * 2.3)
			_ellipse(n, Vector2(xx, y0 + 2.0 + (k % 3) * 2.0), Vector2(fw, 2.6), col2, 0.0, 12)
	# ripple rings
	for r in _rings:
		var age := _vt - float(r[1])
		var p: Vector2 = r[0]
		var s: float = float(r[2]) * (0.3 + age)
		_ring(n, p, Vector2(s, s * 0.18), Color(0.6, 0.72, 0.72, 0.3 * (1.0 - age / 1.6)), 1.2, 20)


func _draw_cap_water() -> void:
	if not _cap.visible:
		return
	var n := _cap_water
	var p := _cap.position + Vector2(0, 10)
	_ellipse(n, p + Vector2(0, 4), Vector2(34, 6), Color(0.012, 0.024, 0.027, 0.92), 0.0, 20)
	_ellipse(n, p + Vector2(0, 6), Vector2(40, 7), Color(BLOOD_D, 0.75 * _red_k), 0.2, 20)
	_ring(n, p + Vector2(0, 1), Vector2(30 + sin(_vt * 1.4) * 2.0, 4.5), Color(0.6, 0.7, 0.7, 0.35), 1.2, 20)
	var age := fmod(_vt - _cap_t0, 2.2)
	_ring(n, p + Vector2(0, 2), Vector2(30 + age * 24.0, 5.0 + age * 3.0), Color(0.6, 0.7, 0.7, 0.3 * (1.0 - age / 2.2)), 1.0, 22)


func _draw_splash() -> void:
	var n := _splash
	for d in _drops:
		var p: Vector2 = d[0]
		var s: float = d[4]
		var red: bool = d[5]
		var col := Color(BLOOD, 0.9) if red else Color(0.82, 0.9, 0.9, 0.62)
		var v: Vector2 = d[1]
		n.draw_line(p, p - v * 0.012, col, s)
		n.draw_circle(p, s * 0.6, col)


func _draw_mist() -> void:
	var n := _mist
	for f in _fog:
		var x: float = fposmod(float(f[0]) + _vt * float(f[3]) + 400.0, 2080.0) - 400.0
		var y: float = f[1]
		var w: float = float(f[2]) * 128.0
		n.draw_texture_rect(_glow_tex, Rect2(x - w * 0.5, y - 60.0, w, 120.0), false, Color(0.6, 0.7, 0.7, 0.07))


func _draw_dust() -> void:
	var n := _cl_fx
	var lamp := _lamp_flick()
	if lamp <= 0.0:
		return
	for d in _dust:
		var p: Vector2 = d[0]
		var near := clampf(1.0 - p.distance_to(LANTERN_CL + Vector2(60, 160)) / 420.0, 0.0, 1.0)
		if near <= 0.0:
			continue
		n.draw_circle(p, float(d[2]), Color(0.85, 0.8, 0.65, 0.3 * near * lamp))


func _draw_dial() -> void:
	var n := _dial
	var c := Vector2(1060, 250)
	var tremble := 0.0
	if _needle > 0.95:
		tremble = sin(_vt * 47.0) * 0.04 + randf_range(-0.03, 0.03)
	var a := deg_to_rad(150.0 + clampf(_needle, 0.0, 1.0) * 238.0) + tremble
	var tip := c + Vector2(cos(a), sin(a)) * 92.0
	n.draw_line(c - Vector2(cos(a), sin(a)) * 18.0, tip, Color(0.05, 0.04, 0.03), 7.0)
	n.draw_line(c - Vector2(cos(a), sin(a)) * 16.0, tip, Color(0.62, 0.05, 0.06), 4.0)
	n.draw_circle(c, 12.0, Color(0.12, 0.12, 0.12))
	n.draw_circle(c, 6.0, Color(0.55, 0.5, 0.4))


func _drip(n: CanvasItem, x: float, y0: float, ln: float, w: float, a: float = 1.0) -> void:
	if ln < 0.5:
		return
	var c := Color(BLOOD, a)
	n.draw_circle(Vector2(x, y0), w * 0.8, Color(BLOOD_D, a))
	n.draw_rect(Rect2(x - w * 0.5, y0, w, ln), c)
	n.draw_circle(Vector2(x, y0 + ln), w * 0.72, c)
	n.draw_line(Vector2(x - w * 0.18, y0 + 1.0), Vector2(x - w * 0.18, y0 + ln * 0.92), Color(BLOOD_H, 0.7 * a), maxf(1.0, w * 0.22))
	n.draw_circle(Vector2(x - w * 0.22, y0 + ln - w * 0.15), maxf(0.8, w * 0.18), Color(1, 1, 1, 0.22 * a))


func _draw_lens() -> void:
	if _lens_t0 < 0.0:
		return
	var t := _vt - _lens_t0
	var fade := clampf((2.9 - t) / 0.9, 0.0, 1.0)
	var n := _lens
	for d in _lens_drops:
		var td: float = t - float(d["d"])
		if td < 0.0:
			continue
		var p: Vector2 = d["p"]
		var r: float = d["r"]
		var grow := clampf(td / 0.08, 0.0, 1.0)
		var a := 0.85 * fade
		_ellipse(n, p, Vector2(r, r * 0.92) * grow, Color(BLOOD_D, a), 0.18, 22)
		_ellipse(n, p + Vector2(-1, -1), Vector2(r * 0.82, r * 0.75) * grow, Color(BLOOD, a), 0.15, 22)
		var rr := RandomNumberGenerator.new()
		rr.seed = int(d["seed"])
		for k in int(d["sat"]):
			var off := Vector2(rr.randf_range(-2.2, 2.2), rr.randf_range(-2.0, 1.6)) * r
			n.draw_circle(p + off * grow, rr.randf_range(2.0, 6.0), Color(BLOOD, a))
		var ln: float = float(d["len"]) * (1.0 - exp(-td / float(d["tau"])))
		_drip(n, p.x + r * 0.15, p.y + r * 0.5, ln, r * 0.42, fade)
		n.draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.16, Color(1, 1, 1, 0.25 * fade))


## Draws a line of text whose letters rock like a cradle around a pivot above it.
func _rocking_text(n: CanvasItem, font: Font, txt: String, sz: int, base: Vector2, pivot: Vector2, ang: float, col: Color, ghost: float) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var x0 := base.x - w * 0.5
	n.draw_set_transform(pivot, ang, Vector2.ONE)
	for i in txt.length():
		var ch := txt[i]
		var x := x0 + font.get_string_size(txt.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var jy := sin(_vt * 2.2 + i * 0.55) * 2.0 + (randf_range(-3, 3) if randf() < 0.03 else 0.0)
		var p := Vector2(x, base.y + jy) - pivot
		n.draw_string(font, p + Vector2(-3, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.7, 0.0, 0.05, 0.4 * ghost))
		n.draw_string(font, p + Vector2(3, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.2, 0.85, 0.8, 0.22 * ghost))
		n.draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_title() -> void:
	var n := _title
	var df := Style.display_font()
	# EXECUTION: a failing red sign
	var te := _vt - _title_exec_t0
	if te >= 0.0:
		var flick := [1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1]
		var on := true
		if te < 0.65:
			on = flick[int(te / 0.05) % flick.size()] == 1
		elif randf() < 0.03:
			on = false
		if on:
			var txt := "EXECUTION"
			var sz := 150
			var w := df.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var pos := Vector2(640 - w * 0.5, 292)
			var j := Vector2(randf_range(-1.5, 1.5), randf_range(-1, 1)) * (1.0 + _g_tear * 6.0)
			n.draw_string_outline(df, pos + j, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 26, Color(0.4, 0.0, 0.03, 0.35))
			n.draw_string(df, pos + j + Vector2(5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.3, 0.9, 0.85, 0.18))
			n.draw_string(df, pos + j, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.68, 0.02, 0.07))
			n.draw_line(Vector2(640 - w * 0.5, 318), Vector2(640 + w * 0.5, 318), Color(0.5, 0.0, 0.04, 0.9), 3.0)
	# OLD MAN TUMBLE - ACE NAPPER, typed
	var tn := _vt - _title_name_t0
	if tn >= 0.0:
		var full := "OLD MAN TUMBLE  —  ACE NAPPER"
		var cnt := mini(full.length(), int(tn / 0.045) + 1)
		var shown := full.substr(0, cnt)
		var sz2 := 30
		var w2 := _mono.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, sz2).x
		var p2 := Vector2(640 - w2 * 0.5, 386)
		n.draw_string(_mono, p2 + Vector2(2, 0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, sz2, Color(0.8, 0.1, 0.1, 0.35))
		n.draw_string(_mono, p2, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, sz2, AQUA_TXT)
		if cnt < full.length() or fmod(_vt, 0.8) < 0.45:
			var cw := _mono.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, sz2).x
			n.draw_rect(Rect2(p2 + Vector2(cw + 4, -24), Vector2(14, 26)), AQUA_TXT)
	# THE ENDLESS LULLABY, rocking like a cradle
	var ta := _vt - _title_act_t0
	if ta >= 0.0:
		var a3 := clampf(ta / 0.9, 0.0, 1.0)
		var ang := sin(ta * 1.9) * 0.035 * minf(1.0, ta * 0.8 + 0.3)
		_rocking_text(n, df, "THE ENDLESS LULLABY", 62, Vector2(640, 488), Vector2(640, 120), ang, Color(BONE_TXT, a3), a3)


func _draw_end() -> void:
	var n := _endtext
	var df := Style.display_font()
	if _sweet_t0 > 0.0:
		var t := _vt - _sweet_t0
		var txt := "SWEET DREAMS"
		var sz := 104
		var w := df.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var x0 := 640 - w * 0.5
		var base_y := 392.0
		var a := clampf(t / 0.3, 0.0, 1.0)
		var ang := sin(t * 2.1) * 0.03
		var pivot := Vector2(640, -200)
		# the drips hang from the letters and rock with them
		n.draw_set_transform(pivot, ang, Vector2.ONE)
		for d in _sweet_drips:
			var td: float = t - float(d["t0"])
			if td <= 0.0:
				continue
			var ln: float = float(d["len"]) * (1.0 - exp(-td / float(d["tau"])))
			_drip(n, x0 + 10.0 + (w - 20.0) * float(d["u"]) - pivot.x, base_y - 8.0 - pivot.y, ln, d["w"], a)
		for i in txt.length():
			var ch := txt[i]
			var x := x0 + df.get_string_size(txt.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var j := Vector2(randf_range(-2, 2), randf_range(-2, 2))
			if randf() < 0.05:
				j.x += randf_range(-14, 14)
			var p := Vector2(x, base_y) + j - pivot
			n.draw_string(df, p + Vector2(5, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.2, 0.8, 0.75, 0.16 * a))
			n.draw_string_outline(df, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6, Color(BLOOD_D, a))
			n.draw_string(df, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(BLOOD_H, a))
			n.draw_string(df, p + Vector2(0, -3), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.85, 0.1, 0.16, 0.25 * a))
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# a small crescent moon over the words
		var mc := Vector2(640 + w * 0.5 + 26.0, base_y - 108.0)
		var ma := a * (0.7 + 0.3 * sin(t * 3.0))
		n.draw_circle(mc, 22.0, Color(BONE_TXT, ma))
		n.draw_circle(mc + Vector2(9, -6), 19.0, Color(0, 0, 0, 1))
	if _trans_t0 > 0.0:
		var t2 := _vt - _trans_t0
		var txt2 := "TRANSMISSION ENDED"
		var sz2 := 40
		var w2 := _mono.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, sz2).x
		var p2 := Vector2(640 - w2 * 0.5, 372)
		var a2 := clampf(t2 / 0.15, 0.0, 1.0)
		n.draw_string(_mono, p2, txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, sz2, Color(0.92, 0.92, 0.92, a2))
		if fmod(t2, 0.9) < 0.5:
			n.draw_rect(Rect2(p2 + Vector2(w2 + 8, -30), Vector2(20, 34)), Color(0.92, 0.92, 0.92, a2))


func _glitchify(s: String) -> String:
	if _hud_glitch < 0.05:
		return s
	var out := ""
	var pool := "#%&?!0123456789:/_"
	for i in s.length():
		if s[i] != " " and randf() < _hud_glitch * 0.5:
			out += pool[randi() % pool.length()]
		else:
			out += s[i]
	return out


func _draw_hud() -> void:
	var n := _hud
	var j := Vector2.ZERO
	if _hud_glitch > 0.05:
		j = Vector2(randf_range(-6, 6), randf_range(-2, 2)) * _hud_glitch
	var white := Color(0.93, 0.93, 0.93, 0.92)
	var shadow := Color(0, 0, 0, 0.7)
	var frames := int(_t * 30.0)
	var tc := "%02d:%02d:%02d:%02d" % [0, floori(frames / 1800.0), floori(frames / 30.0) % 60, frames % 30]
	# the camcorder clock is stuck at midnight
	var items := [["REC", Vector2(78, 70), 30], ["SP", Vector2(1168, 70), 30], [tc, Vector2(56, 672), 28],
		["NOV. 09 1987", Vector2(1000, 640), 26], ["AM 12:00", Vector2(1064, 606), 26]]
	for it in items:
		var s := _glitchify(str(it[0]))
		var p: Vector2 = it[1]
		var fs: int = it[2]
		n.draw_string(_mono, p + j + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, shadow)
		n.draw_string(_mono, p + j + Vector2(-1.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.2, 0.2, 0.25))
		n.draw_string(_mono, p + j, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white)
	if fmod(_t, 1.0) < 0.6:
		n.draw_circle(Vector2(58, 60) + j, 10, Color(0.85, 0.05, 0.08))
	var c := Color(0.9, 0.9, 0.9, 0.35)
	for corner in [[Vector2(30, 30), Vector2(1, 1)], [Vector2(1250, 30), Vector2(-1, 1)], [Vector2(30, 690), Vector2(1, -1)], [Vector2(1250, 690), Vector2(-1, -1)]]:
		var p0: Vector2 = corner[0]
		var dd: Vector2 = corner[1]
		n.draw_line(p0, p0 + Vector2(36 * dd.x, 0), c, 2.0)
		n.draw_line(p0, p0 + Vector2(0, 36 * dd.y), c, 2.0)


# ================================================================== skip / finish
func _update_skip(delta: float) -> void:
	if _t < SKIP_AFTER:
		return
	var held := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if held:
		_hold += delta
	else:
		_hold = maxf(0.0, _hold - delta * 2.0)
	var target := 1.0 if _hold > 0.0 else 0.55
	_hint.modulate.a = move_toward(_hint.modulate.a, target, delta * 2.0)
	_hint_fill.size.x = 200.0 * clampf(_hold / HOLD_TO_SKIP, 0.0, 1.0)
	if _hold >= HOLD_TO_SKIP:
		_finish(true)


func _finish(skipped: bool) -> void:
	if _done:
		return
	_done = true
	Audio.set_music_paused(false)
	if skipped:
		Audio.stop_all_sfx()
		Audio.sfx("hx_static_burst", 1.0, -4.0)
		_put("_fx_static", 1.0)
		Audio.stop_music(0.3)
	elif Audio.current_music() == MUSIC_ID:
		Audio.stop_music(0.5)
	_hint.modulate.a = 0.0
	_hint.visible = false
	print_verbose("[execution2] finished at t=%.2f skipped=%s" % [_t, skipped])
	finished.emit({})


## Keep the soundtrack in sync with the timeline when the pause menu freezes the tree.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			Audio.set_music_paused(true)
		NOTIFICATION_UNPAUSED, NOTIFICATION_EXIT_TREE:
			Audio.set_music_paused(false)
