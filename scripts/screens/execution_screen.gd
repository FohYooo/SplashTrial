extends Control
## EXECUTION "video" - THE FINAL VANISHING ACT (DESIGN section 8, horror version).
## A ~59 s found-footage / cursed-broadcast sequence. Everything is driven by one clock advanced in
## _process: timed events (see _schedule) start keyframed animations from a tiny built-in animator,
## and every other effect is a pure function of the "visual time" _vt (which can stutter / run choppy
## for frame-drop effects). No awaits and no Tween objects, so nothing can resume after the screen is
## freed. Hold Space / Enter / mouse for 1 s (after 3 s) to skip. Emits finished({}) exactly once.
## Debug: --exec-t=<seconds> starts the timeline at that time (for screenshots).

signal finished(result: Dictionary)

const Style := preload("res://scripts/ui/style.gd")
const Assets := preload("res://scripts/core/assets.gd")

const END_TIME := 58.8
const SKIP_AFTER := 3.0
const HOLD_TO_SKIP := 1.0

# Cabinet geometry - shared with tools/gen_exec_horror_art.py. Cabinet-local origin = bottom centre of
# the 320x620 frame (svg x - 160, svg y - 620).
const CAB_POS := Vector2(640, 574)
const CAB_SCALE := 0.7
const DOOR_PIVOT := Vector2(-120, -285)      # left edge, vertical middle of the 240x480 door opening
const BLADE_Y := [-340.0, -250.0, -160.0]
const VBLADE_X := 20.0
const BLADE_T := [35.0, 36.8, 38.6, 40.4]    # the four thuds
const WISP_IN_CAB := Vector2(0, -352)       # portrait centre inside the cabinet (eyes line up with the slot)
const WISP_CAB_SCALE := 0.48
const HAT_POS := Vector2(-42, -62)
const MONO_MQ := 3                           # index in _front_row of the mannequin that ends up with the monocle

const BLOOD := Color("7a0010")
const BLOOD_D := Color("3a0008")
const BLOOD_H := Color("b3001b")
const BONE_TXT := Color(0.86, 0.82, 0.72)
const AQUA_TXT := Color(0.66, 0.95, 0.92)

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
var _shake := 0.0
var _sway := 2.0

# lights
var _tent_level := 0.0
var _sag := 0.0
var _strobe_t0 := -100.0
var _spot_level := 0.0
var _swing_amp := 0.05
var _flash_a := 0.0
var _flash_col := Color(0.85, 1.0, 0.98)

# story state
var _clap_times: Array = []
var _wisp_shake := 0.0
var _wisp_dart := 0.0
var _eye_scale := 0.3
var _eye_open := 0.0
var _hat_rock_t0 := -100.0
var _glitter_on := false
var _glitter_rate := 0.0
var _glitter_acc := 0.0
var _heads := "away"      # away | side | front
var _door_sx := -0.3:     # cabinet door hinge (1 = shut, < 0 = swung open towards the camera)
	set(v):
		_door_sx = v
		if _door:
			_set_door(v)
var _cc_until := 0.0
var _title_exec_t0 := 1.0e9
var _title_name_t0 := 1.0e9
var _title_act_t0 := 1.0e9
var _show_t0 := -100.0
var _trans_t0 := -100.0
var _lens_t0 := -100.0
var _subliminal_until := -1.0
var _typed := 0
var _ff := false

# nodes
var _tx := {}
var _mono: SystemFont
var _glow_tex: Texture2D
var _shade_tex: Texture2D
var _add_mat: CanvasItemMaterial
var _world: Node2D
var _tent: Node2D
var _spot: Node2D
var _snap: Node2D
var _bulb_wire: Node2D
var _bulb_glow: Node2D
var _bulbs: Array = []
var _curtain_splat: Sprite2D
var _bleach: Array = []
var _front_row: Array = []
var _pool_node: Node2D
var _cab: Node2D
var _cab_inner: Node2D
var _cab_wisp: Sprite2D
var _cab_shade: Sprite2D
var _blades: Array = []
var _door: Node2D
var _door_spr: Sprite2D
var _door_deco: Node2D
var _door_splat: Sprite2D
var _cab_front: Sprite2D
var _cab_blood: Node2D
var _chains: Array = []
var _padlock: Sprite2D
var _hat: Sprite2D
var _hat_glow: Sprite2D
var _lamp: Node2D
var _lamp_cone: Sprite2D
var _lamp_glow: Sprite2D
var _floor_glow: Sprite2D
var _tent_fx: Node2D
var _tent_fx_add: Node2D
var _monocle: Sprite2D
var _monocle_glint: Sprite2D
var _spot_cone: Sprite2D
var _spot_wisp: Sprite2D
var _spot_mat: ShaderMaterial
var _spot_faces: Array = []
var _spot_fx: Node2D
var _snap_sil: Sprite2D
var _snap_eye: Sprite2D
var _snap_eye_glow: Sprite2D
var _snap_close: Sprite2D
var _snap_close_mat: ShaderMaterial
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

# particle pools: [pos, vel, life, max_life, size, col, kind]
var _glitter: Array = []
var _dust: Array = []
var _door_drips: Array = []
var _frame_drips: Array = []
var _lens_drops: Array = []
var _show_drips: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 1313
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Courier New", "Menlo", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_mono.font_weight = 700
	_glow_tex = _radial_tex()
	_shade_tex = _shade_gradient()
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_load_textures()
	_build()
	_make_blood()
	_schedule()
	if Game.autotest:
		# exercise the cold open, then end quickly
		_events = _events.filter(func(e: Array) -> bool: return float(e[0]) < 0.5)
		_end_at = 0.6
	var start := _debug_start_time()
	if start > 0.0:
		# fast-forward the timeline silently, in small steps, so keyframes resolve in order
		_ff = true
		while _t < start:
			_t = minf(start, _t + 1.0 / 30.0)
			_fire_events()
			_vt = _t
			_update_anims()
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
	for n in ["hx_tent", "hx_curtain", "hx_mq_front", "hx_mq_back", "hx_mq_side", "hx_mq_body", "hx_mq_hand",
			"hx_cab_back", "hx_cab_front", "hx_cab_door", "hx_cab_door_back", "hx_blade", "hx_chain", "hx_padlock",
			"hx_tophat", "hx_monocle", "hx_eye", "hx_snap_sil", "hx_standby", "hx_splatter", "hx_lamp", "hx_spotcone",
			"title_sparkle"]:
		_tx[n] = Assets.prop(n)
	_tx["mq_front_big"] = Assets.prop("hx_mq_front", 2.0)
	_tx["monocle_big"] = Assets.prop("hx_monocle", 2.0)
	for e in ["sad", "shock", "normal"]:
		_tx["wisp_" + e] = Assets.portrait("wisp", e)
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


func _shade_gradient() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 1))
	g.add_point(0.38, Color(0, 0, 0, 0))
	g.add_point(0.58, Color(0, 0, 0, 0.96))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 16
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


# ================================================================== building
func _build() -> void:
	_full_rect(self, Color.BLACK)
	_world = Node2D.new()
	add_child(_world)
	_build_tent()
	_build_spot()
	_build_snap()
	_show_set("none")

	_black = _full_rect(self, Color(0, 0, 0, 1))
	_black.visible = false
	_lens = _ctrl(self)
	_lens.draw.connect(_draw_lens)

	_standby = _ctrl(self)
	var card := TextureRect.new()
	card.texture = _tex("hx_standby")
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
	_sub_face.texture = _tex("mq_front_big")
	_sub_face.position = Vector2(640, 380)
	_sub_face.scale = Vector2(1.9, 1.9)
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


func _build_tent() -> void:
	_tent = _node(_world)
	var back := _spr(_tent, _tex("hx_tent"), Vector2(640, 360))
	if back.texture == null:
		var fb := ColorRect.new()
		fb.color = Color("140c0c")
		fb.position = Vector2(-640, -360)
		fb.size = Vector2(1280, 720)
		fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(fb)
	# bulb garland (wire + glass, and an additive glow pass)
	_bulb_wire = _node(_tent)
	_bulb_wire.draw.connect(_draw_bulbs)
	_bulb_glow = _node(_tent)
	_bulb_glow.material = _add_mat
	_bulb_glow.draw.connect(_draw_bulb_glow)
	var spans := [[Vector2(-20, 108), Vector2(330, 150), 38.0], [Vector2(330, 150), Vector2(950, 150), 74.0], [Vector2(950, 150), Vector2(1300, 108), 38.0]]
	var idx := 0
	for sp in spans:
		var a: Vector2 = sp[0]
		var b: Vector2 = sp[1]
		var sag: float = sp[2]
		var n := int(a.distance_to(b) / 46.0)
		for i in range(1, n):
			var u := float(i) / n
			var p := a.lerp(b, u) + Vector2(0, sag * 4.0 * u * (1.0 - u))
			var red := idx % 7 == 3
			var dead := idx % 11 == 5
			_bulbs.append({"pos": p, "red": red, "dead": dead, "on": 10.0 + _rng.randf_range(0.0, 0.7), "ph": _rng.randf() * TAU, "die": -1.0})
			idx += 1
	for k in [9, 10]:
		if k < _bulbs.size():
			_bulbs[k]["die"] = 12.6
	var cur := _spr(_tent, _tex("hx_curtain"), Vector2(640, 318))
	cur.modulate = Color(0.9, 0.9, 0.9)
	_curtain_splat = _spr(_tent, _tex("hx_splatter"), Vector2(790, 246), 0.62)
	_curtain_splat.rotation = -0.35
	_curtain_splat.visible = false
	# bleachers: mannequins in profile, facing the ring
	var tiers := [[392.0, 330.0, 0.27], [454.0, 352.0, 0.31], [516.0, 372.0, 0.35]]
	var empty := [[1, 3], [2], [0, 4]]
	for side in [-1, 1]:
		for ti in tiers.size():
			var tr: Array = tiers[ti]
			var y_in: float = tr[0]
			var x_in: float = tr[1]
			var sc: float = tr[2]
			var xi := x_in if side < 0 else 1280.0 - x_in
			var x_out := -60.0 if side < 0 else 1340.0
			var count := 5
			for j in count:
				var gaps: Array = empty[(ti + (1 if side > 0 else 0)) % empty.size()]
				if j in gaps:
					continue
				var x := xi + (x_out - xi) * (0.1 + j * 0.19)
				var y := y_in - 30.0 * absf(xi - x) / absf(xi - x_out) + 4.0
				var neck := Vector2(x, y - 160.0 * sc)
				var m := _make_mq(_tent, neck, sc, "side", side > 0, true)
				m["node"].modulate = Color(0.5, 0.5, 0.5)
				_bleach.append(m)
	_pool_node = _node(_tent)
	_pool_node.draw.connect(_draw_pool)
	_floor_glow = _spr(_tent, _glow_tex, Vector2(640, 560))
	_floor_glow.material = _add_mat
	_floor_glow.scale = Vector2(6.0, 1.7)
	_floor_glow.modulate = Color(0.55, 0.62, 0.6, 0.7)
	_build_cabinet()
	# hanging lamp above the cabinet
	_lamp = _node(_tent, Vector2(640, -30))
	_lamp_cone = _spr(_lamp, _tex("hx_spotcone"), Vector2(0, 150))
	_lamp_cone.offset = Vector2(0, 360)
	_lamp_cone.scale = Vector2(0.8, 0.66)
	_lamp_cone.material = _add_mat
	_lamp_cone.modulate = Color(0.55, 0.66, 0.64, 0.42)
	var lamp_spr := _spr(_lamp, _tex("hx_lamp"), Vector2(0, 126), 0.7)
	lamp_spr.offset = Vector2(0, -20)
	_lamp_glow = _spr(_lamp, _glow_tex, Vector2(0, 150), 1.4)
	_lamp_glow.material = _add_mat
	_lamp_glow.modulate = Color(0.7, 0.85, 0.8, 0.8)
	_tent_fx_add = _node(_tent)
	_tent_fx_add.material = _add_mat
	_tent_fx_add.draw.connect(_draw_tent_fx.bind(true))
	_tent_fx = _node(_tent)
	_tent_fx.draw.connect(_draw_tent_fx.bind(false))
	# audience: front rows, seen from behind (silhouettes against the ring)
	var fr := [[Vector2(70, 672), 1.0], [Vector2(250, 668), 1.0], [Vector2(1075, 668), 1.0], [Vector2(838, 706), 0.85],
		[Vector2(1212, 674), 1.0], [Vector2(428, 708), 0.85]]
	for e in fr:
		var m := _make_mq(_tent, e[0], e[1], "back", false, false)
		m["node"].modulate = Color(0.3, 0.3, 0.3)
		_front_row.append(m)
	var mm: Dictionary = _front_row[MONO_MQ]
	var head: Sprite2D = mm["head"]
	_monocle = _spr(head, _tex("monocle_big"), Vector2(28, -8), 0.29)
	_monocle.offset = Vector2(20, 70)
	_monocle.visible = false
	_monocle_glint = _spr(head, _tex("title_sparkle"), Vector2(22, -6), 0.35)
	_monocle_glint.material = _add_mat
	_monocle_glint.visible = false


func _make_mq(parent: Node2D, neck: Vector2, sc: float, view: String, flip: bool, hands: bool) -> Dictionary:
	var n := _node(parent, neck)
	n.scale = Vector2(-sc if flip else sc, sc)
	var body := _spr(n, _tex("hx_mq_body"), Vector2(0, 77))
	if view == "side":
		body.scale.x = 0.62
	var hs: Array = []
	if hands:
		for i in 2:
			var h := _spr(n, _tex("hx_mq_hand"), Vector2(62.0 + i * 32.0, 52), 0.85)
			hs.append(h)
	var head := _spr(n, _tex("hx_mq_side" if view == "side" else "hx_mq_back"), Vector2(10 if view == "side" else 0, -84))
	return {"node": n, "head": head, "body": body, "hands": hs, "view": view, "base": neck, "sc": sc}


func _build_cabinet() -> void:
	_cab = _node(_tent, CAB_POS)
	_cab.scale = Vector2(CAB_SCALE, CAB_SCALE)
	var back := _spr(_cab, _tex("hx_cab_back"), Vector2(0, -310))
	back.modulate = Color(0.9, 0.9, 0.9)
	_cab_inner = _node(_cab)
	_cab_inner.draw.connect(_draw_cab_inner)
	_hat_glow = _spr(_cab, _glow_tex, Vector2(-30, -200))
	_hat_glow.scale = Vector2(2.6, 3.6)
	_hat_glow.material = _add_mat
	_hat_glow.modulate = Color(0.45, 0.55, 0.55, 0.55)
	_hat_glow.visible = false
	_hat = _spr(_cab, _tex("hx_tophat"), HAT_POS, 0.62)
	_hat.offset = Vector2(0, -98)
	_hat.modulate = Color(1.7, 1.7, 1.8)
	_hat.visible = false
	_cab_wisp = _spr(_cab, _tex("wisp_shock"), WISP_IN_CAB, WISP_CAB_SCALE)
	_cab_wisp.material = _lit_mat(Vector2(0.5, -0.1), 1.45, Color(0.95, 1.0, 0.96), Color(0.05, 0.06, 0.08), 0.35, 1.5)
	_cab_wisp.visible = false
	_cab_shade = _spr(_cab, _shade_tex, Vector2(0, -285))
	_cab_shade.scale = Vector2(240.0 / 16.0, 480.0 / 128.0)
	_cab_shade.visible = false
	for i in 4:
		var b := _spr(_cab, _tex("hx_blade"))
		var from_right := i == 1
		b.flip_h = from_right
		b.offset = Vector2(-224 if from_right else 224, 0)
		if i == 3:
			b.rotation = PI * 0.5
		b.visible = false
		_blades.append(b)
	_door = _node(_cab, DOOR_PIVOT)
	_door_spr = _spr(_door, _tex("hx_cab_door"))
	_door_spr.offset = Vector2(120, 0)
	_door_deco = _node(_door)
	_door_deco.draw.connect(_draw_door_blood)
	_door_splat = _spr(_door, _tex("hx_splatter"), Vector2(128, -40), 0.5)
	_door_splat.rotation = 0.45
	_door_splat.visible = false
	_cab_front = _spr(_cab, _tex("hx_cab_front"), Vector2(0, -310))
	_cab_blood = _node(_cab)
	_cab_blood.draw.connect(_draw_frame_blood)
	for s in [-1, 1]:
		var c := _spr(_cab, _tex("hx_chain"), Vector2(0, -290))
		c.scale = Vector2(0.71, 1.0)
		c.rotation = 0.714 * s
		c.visible = false
		_chains.append(c)
	_padlock = _spr(_cab, _tex("hx_padlock"), Vector2(0, -282), 0.75)
	_padlock.visible = false
	_set_door(-0.3)


func _build_spot() -> void:
	_spot = _node(_world)
	var fl := _spr(_spot, _glow_tex, Vector2(640, 700))
	fl.scale = Vector2(6.0, 1.6)
	fl.material = _add_mat
	fl.modulate = Color(0.5, 0.55, 0.55, 0.5)
	for p in [Vector2(150, 520), Vector2(1135, 470), Vector2(70, 250), Vector2(1220, 230)]:
		var f := _spr(_spot, _tex("hx_mq_front"), p, 0.8)
		f.modulate = Color(0.16, 0.17, 0.17)
		f.visible = false
		_spot_faces.append(f)
	_spot_wisp = _spr(_spot, _tex("wisp_sad"), Vector2(640, 470), 1.0)
	_spot_mat = _lit_mat(Vector2(0.5, -0.12), 1.5, Color(1.0, 0.98, 0.9), Color(0.03, 0.05, 0.06), 0.4, 1.5)
	_spot_wisp.material = _spot_mat
	_spot_cone = _spr(_spot, _tex("hx_spotcone"), Vector2(640, 360))
	_spot_cone.scale = Vector2(1.1, 1.0)
	_spot_cone.material = _add_mat
	_spot_cone.modulate = Color(0.75, 0.82, 0.8, 0.5)
	_spot_fx = _node(_spot)
	_spot_fx.material = _add_mat
	_spot_fx.draw.connect(_draw_dust)
	for i in 46:
		_dust.append([Vector2(_rng.randf_range(470, 810), _rng.randf_range(0, 720)), Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-8, 8)),
			_rng.randf_range(0.8, 2.4), _rng.randf() * TAU])


func _build_snap() -> void:
	_snap = _node(_world)
	_snap_sil = _spr(_snap, _tex("hx_snap_sil"), Vector2(640, 400))
	_snap_sil.visible = false
	_snap_eye_glow = _spr(_snap, _glow_tex, Vector2(900, 300), 1.0)
	_snap_eye_glow.material = _add_mat
	_snap_eye_glow.modulate = Color(1.0, 0.08, 0.05, 0.6)
	_snap_eye = _spr(_snap, _tex("hx_eye"), Vector2(900, 300), 0.3)
	_snap_close = _spr(_snap, _tex("snapjaw_happy"), Vector2(640, 452), 1.75)
	_snap_close_mat = _lit_mat(Vector2(0.5, 1.1), 1.7, Color(1.0, 0.12, 0.08), Color(0.04, 0.02, 0.03), 0.25, 2.2)
	_snap_close.material = _snap_close_mat
	_snap_close.visible = false


func _show_set(which: String) -> void:
	_tent.visible = which == "tent"
	_spot.visible = which == "spot"
	_snap.visible = which == "snap"


# ================================================================== blood data (deterministic)
func _make_blood() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7001
	# door-local: slit i is at y = BLADE_Y[i] - DOOR_PIVOT.y ; the door spans x 0..240, y -240..240
	for i in 3:
		var sy: float = BLADE_Y[i] - DOOR_PIVOT.y + 4.0
		for k in 4:
			var x := r.randf_range(14.0, 226.0)
			var room := 236.0 - sy
			_door_drips.append({"x": x, "y": sy, "len": room * r.randf_range(0.35, 0.95), "t0": float(BLADE_T[i]) + 0.25 + r.randf_range(0.0, 1.4),
				"tau": r.randf_range(1.1, 2.6), "w": r.randf_range(4.0, 7.0)})
	# frame-local: from the bottom seam of the door down over the plinth, and out of the post slits
	for k in 6:
		_frame_drips.append({"x": r.randf_range(-108.0, 108.0), "y": -46.0, "len": r.randf_range(30.0, 46.0), "t0": float(BLADE_T[1]) + r.randf_range(-0.6, 1.2),
			"tau": r.randf_range(0.6, 1.4), "w": r.randf_range(5.0, 8.0)})
	for i in 3:
		for s in [-1, 1]:
			var y: float = BLADE_Y[i] + 6.0
			_frame_drips.append({"x": 140.0 * s + r.randf_range(-8.0, 8.0), "y": y, "len": r.randf_range(40.0, 160.0), "t0": float(BLADE_T[i]) + 0.3 + r.randf_range(0.0, 1.0),
				"tau": r.randf_range(1.0, 2.0), "w": r.randf_range(4.0, 6.0)})
	# lens splash at the final thud (screen space)
	for k in 11:
		var p := Vector2(r.randf_range(90.0, 1190.0), r.randf_range(40.0, 470.0))
		_lens_drops.append({"p": p, "r": r.randf_range(10.0, 34.0), "len": r.randf_range(80.0, 330.0), "tau": r.randf_range(0.9, 2.2),
			"d": r.randf_range(0.0, 0.25), "sat": r.randi_range(2, 5), "seed": r.randi()})


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
	_cam_from_c = c0
	_cam_from_z = z0
	_cam_to_c = c1
	_cam_to_z = z1
	_cam_t1 = _ev_time + dur


# ================================================================== the timeline
func _schedule() -> void:
	# ---- 0.0  cold open: PLEASE STAND BY
	_at(0.0, _ev_standby)
	_at(0.35, func() -> void: _anim(self, "_fx_static", 1.0, 0.42, 0.5, 2))
	for t in [0.7, 1.6, 2.5]:
		_at(t, func() -> void: _sfx("hx_heartbeat", 0.92, -2.0))
	_at(2.95, _ev_subliminal)
	_at(3.45, _ev_standby_glitch)
	_at(3.9, _ev_black_cut)
	# ---- 4.0  title card
	_at(4.0, _ev_title)
	_at(4.2, _ev_title_exec)
	_at(5.7, _ev_title_name)
	_at(7.3, _ev_title_act)
	_at(9.3, func() -> void: _anim(self, "_fx_tear", 0.05, 0.7, 0.6, 3))
	_at(9.9, _ev_title_out)
	# ---- 10.0 the rotting big top
	_at(10.0, _ev_tent_on)
	_at(12.6, _ev_bulb_die)
	_at(13.4, func() -> void: _stutter(4))
	_at(14.0, _ev_power_sag)
	_at(14.4, _ev_power_back)
	_at(15.55, _ev_flicker_fix)
	_at(16.7, func() -> void: _glitch(0.6))
	# ---- 17.0 Wisp alone in the spotlight
	_at(17.0, _ev_spot_on)
	var hb := 17.45
	while hb < 21.3:
		_at(hb, func() -> void: _sfx("hx_heartbeat", 1.05, -1.0))
		hb += 0.78
	_at(18.6, func() -> void: _sfx("hx_whisper", 1.0, 0.0))
	_at(19.7, _ev_spot_flicker)
	_at(19.84, _ev_spot_back)
	_at(20.8, func() -> void: _stutter(3))
	_at(21.5, _ev_spot_die)
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
	# ---- 30.8 the cabinet
	_at(30.8, _ev_cab_shot)
	_at(32.5, _ev_slam)
	_at(32.6, func() -> void: _black.visible = false)
	_at(32.9, _ev_chains)
	_at(33.6, func() -> void: _stutter(3))
	# ---- 35.0 the blades
	for i in 4:
		var b: float = BLADE_T[i]
		_at(b - 0.5, _ev_blade_in.bind(i))
		_at(b, _ev_blade_thud.bind(i))
	_at(BLADE_T[0] + 0.55, _ev_wide_applause)
	_at(BLADE_T[0] + 1.25, _ev_close_cab)
	_at(BLADE_T[1] + 0.55, _ev_wide_applause)
	_at(BLADE_T[1] + 1.25, _ev_close_cab)
	_at(BLADE_T[2] + 0.4, _ev_strobe)
	_at(BLADE_T[2] + 1.25, _ev_close_cab)
	_at(BLADE_T[3] + 0.15, _ev_silence)
	# ---- 42.6 the reveal
	_at(42.6, _ev_reveal_shot)
	_at(44.0, _ev_chains_drop)
	_at(44.8, _ev_door_open)
	_at(46.0, func() -> void: _cam_move(CAB_POS + Vector2(-26, -84), 2.35, 3.4))
	_at(46.2, func() -> void: _sfx("hx_musicbox", 1.0, 0.0))
	_at(47.7, func() -> void: _stutter(3))
	# ---- 49.4 they turn
	_at(49.4, _ev_turn_wide)
	_at(50.4, _ev_heads_side)
	_at(50.47, _ev_heads_front)
	_at(51.3, _ev_monocle_close)
	_at(52.7, _ev_smash)
	# ---- 53.2 THE SHOW MUST GO ON / TRANSMISSION ENDED
	_at(53.2, _ev_show_must)
	_at(55.5, _ev_static_out)
	_at(56.4, _ev_trans_end)
	_at(58.2, func() -> void: _anim(self, "_fx_bright", 1.0, 0.0, 0.5, 0))
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


func _set_door(sx: float) -> void:
	_door.scale.x = sx
	var open := sx < 0.0
	_door_spr.texture = _tex("hx_cab_door_back") if open else _tex("hx_cab_door")
	_door_deco.visible = not open
	_door_splat.visible = (not open) and _vt >= BLADE_T[2] + 0.38
	# an open door swings in front of the frame
	if sx < 0.06 and _door.get_index() < _cab_front.get_index():
		_cab.move_child(_door, _cab_front.get_index())
	elif sx >= 0.06 and _door.get_index() > _cab_front.get_index():
		_cab.move_child(_door, _cab_front.get_index())


func _clap_pulse(t: float) -> float:
	var p := 0.0
	for c in _clap_times:
		var d := (t - float(c)) / 0.05
		p = maxf(p, exp(-d * d))
	return p


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
		Audio.play_music("execution_horror", 0.4)


func _ev_title_exec() -> void:
	_title_exec_t0 = _ev_time
	_sfx("hx_sting", 1.0, 0.0)
	_glitch(0.5)


func _ev_title_name() -> void:
	_title_name_t0 = _ev_time


func _ev_title_act() -> void:
	_title_act_t0 = _ev_time
	_sfx("hx_whisper", 0.9, 0.0)


func _ev_title_out() -> void:
	_title.visible = false
	_put("_fx_tear", 0.05)
	_sfx("hx_static_burst", 1.2, -6.0)
	_g_static = 0.8


# ------------------------------------------------------------------ events: the big top
func _ev_tent_on() -> void:
	_black.visible = false
	_show_set("tent")
	_hud.visible = true
	_put("_fx_desat", 0.86)
	_put("_fx_tracking", 0.35)
	_put("_fx_chroma", 2.2)
	_put("_tent_level", 0.0)
	_anim(self, "_tent_level", 0.15, 0.82, 1.2, 2)
	_cam_push(Vector2(640, 372), 1.0, Vector2(640, 392), 1.16, 7.0)
	_sway = 2.5
	_sfx("hx_buzz", 1.0, 0.0)
	_sfx("hx_wind", 1.0, 0.0)
	_vroll_slip(0.2, 0.25)


func _ev_bulb_die() -> void:
	_sfx("pop", 0.55, -8.0)
	_sfx("hx_buzz", 1.3, -6.0)
	_glitch(0.2)


func _ev_power_sag() -> void:
	_anim(self, "_sag", 0.0, 0.78, 0.08, 0)
	_sfx("hx_buzz", 0.8, -2.0)
	_turn_one(31, true)


func _ev_power_back() -> void:
	_anim(self, "_sag", 0.78, 0.0, 0.15, 0)


func _ev_flicker_fix() -> void:
	_put("_sag", 0.9)
	_anim(self, "_sag", 0.9, 0.0, 0.12, 0)
	_turn_one(31, false)
	_sfx("hx_buzz", 1.1, -6.0)


func _turn_one(i: int, front: bool) -> void:
	if i >= _bleach.size():
		return
	var m: Dictionary = _bleach[i]
	var head: Sprite2D = m["head"]
	head.texture = _tex("hx_mq_front") if front else _tex("hx_mq_side")
	head.position = Vector2(0 if front else 10, -84)


# ------------------------------------------------------------------ events: Wisp in the spotlight
func _ev_spot_on() -> void:
	_show_set("spot")
	_spot_wisp.texture = _tex("wisp_sad")
	_spot_wisp.position = Vector2(640, 470)
	_spot_level = 1.0
	_cam_push(Vector2(640, 360), 1.0, Vector2(640, 300), 1.22, 4.6)
	_sway = 1.6
	_wisp_shake = 1.4
	_put("_fx_desat", 0.9)
	_sfx("hx_buzz", 0.7, -3.0)
	_glitch(0.4)


func _ev_spot_flicker() -> void:
	_spot_level = 0.0
	_sfx("hx_buzz", 0.9, -4.0)


func _ev_spot_back() -> void:
	_spot_level = 1.0
	_spot_wisp.texture = _tex("wisp_shock")
	_spot_wisp.position = Vector2(652, 476)
	_wisp_shake = 2.6
	for f in _spot_faces:
		(f as Sprite2D).visible = true
	_sfx("hx_heartbeat", 1.2, 0.0)
	_glitch(0.3)


func _ev_spot_die() -> void:
	_spot_level = 0.0
	_sfx("hx_thud", 1.6, -12.0)
	_sfx("hx_buzz", 0.6, -2.0)
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
	_sfx("hx_buzz", 1.4, -4.0)
	_g_static = 0.15


func _ev_snap_hide() -> void:
	_snap_sil.visible = false


func _ev_laugh() -> void:
	_sfx("hx_laugh", 1.0, 0.0)
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


# ------------------------------------------------------------------ events: the cabinet
func _ev_cab_shot() -> void:
	_black.visible = false
	_snap_eye.visible = true
	_snap_eye_glow.visible = true
	_show_set("tent")
	_put("_fx_desat", 0.86)
	_put("_tent_level", 0.72)
	_cam_push(Vector2(640, 352), 1.42, Vector2(640, 340), 1.55, 1.7)
	_sway = 1.5
	_cab_wisp.visible = true
	_cab_wisp.texture = _tex("wisp_shock")
	_cab_shade.visible = true
	_hat.visible = false
	_wisp_shake = 1.8
	_set_door(-0.3)
	_sfx("hx_wind", 0.9, -4.0)


func _ev_slam() -> void:
	_anim(self, "_door_sx", -0.3, 1.0, 0.12, 3)
	_sfx("hx_slam", 1.0, 0.0)
	_shake = 12.0
	_swing_amp += 0.06
	_glitch(0.5)
	_black.visible = true


func _ev_chains() -> void:
	for i in 2:
		var c: Sprite2D = _chains[i]
		c.visible = true
		var s := -1.0 if i == 0 else 1.0
		_anim(c, "position", Vector2(-320.0 * s, -360), Vector2(0, -290), 0.32, 2)
	_padlock.visible = true
	_anim(_padlock, "position", Vector2(0, -360), Vector2(0, -282), 0.25, 2, 0.25)
	_padlock.position = Vector2(0, -360)
	_sfx("hx_chain", 1.0, 0.0)
	_shake = 3.0
	_wisp_dart = 1.0


# ------------------------------------------------------------------ events: the blades
func _blade_pose(i: int, k: float) -> Vector2:
	# k = 0 outside (start), 1 fully inserted
	match i:
		0, 2:
			return Vector2(lerpf(-900.0, -172.0, k), BLADE_Y[i])
		1:
			return Vector2(lerpf(900.0, 172.0, k), BLADE_Y[i])
		_:
			return Vector2(VBLADE_X, lerpf(-1450.0, -760.0, k))


func _ev_blade_in(i: int) -> void:
	var b: Sprite2D = _blades[i]
	b.visible = true
	_anim(b, "position", _blade_pose(i, 0.0), _blade_pose(i, 1.0), 0.5, 3)
	b.position = _blade_pose(i, 0.0)
	_sfx("hx_blade", 1.0 - i * 0.05, 0.0)


func _ev_blade_thud(i: int) -> void:
	var b: Sprite2D = _blades[i]
	b.position = _blade_pose(i, 1.0)
	_sfx("hx_thud", 1.0 - i * 0.04, 0.0 + i * 0.5)
	_shake = 14.0 + i * 4.0
	_swing_amp += 0.05
	_wisp_dart = 0.0
	_do_flash(0.35, 0.12)
	_glitch(0.45 + i * 0.15)
	if i == 0:
		_cab_wisp.texture = _tex("wisp_sad")
	elif i == 1:
		_cab_wisp.visible = false
	if i == 3:
		_cc.visible = false
		_lens_t0 = _ev_time
		_sfx("hx_splatter", 0.85, 0.0)
		_do_flash(0.6, 0.25, Color(1.0, 0.25, 0.2))
		_shake = 30.0
		return
	if i == 1:
		_sfx("hx_splatter", 1.0, -6.0)
	# hold the impact frame for a moment, then cut to black
	_at_late(_ev_time + 0.07, func() -> void: _black.visible = true)
	_hud_glitch = 0.5
	_applause_after(i)


func _applause_after(i: int) -> void:
	# claps start 0.25 s into the black
	var at := float(BLADE_T[i]) + 0.25
	_clap_times.append(at + 0.01)
	_clap_times.append(at + 0.45)
	_clap_times.append(at + 0.89)
	_clap_times.append(at + 1.33)
	_cc_until = 0.0
	_at_late(at, func() -> void:
		_sfx("hx_applause_stiff", 1.0, 0.0)
		_cc_show("[ APPLAUSE ]", 1.7))


## Schedules an extra event while the timeline is running (inserted in order).
func _at_late(time: float, c: Callable) -> void:
	var e := [time, _events.size() + 1000, c]
	var pos := _ev_i
	while pos < _events.size() and float(_events[pos][0]) <= time:
		pos += 1
	_events.insert(pos, e)


func _ev_wide_applause() -> void:
	_black.visible = false
	_show_set("tent")
	_cam_push(Vector2(640, 380), 1.0, Vector2(640, 384), 1.04, 0.8)
	_sway = 2.0
	_glitch(0.25)


func _ev_close_cab() -> void:
	_black.visible = false
	_show_set("tent")
	_strobe_t0 = -100.0
	_put("_tent_level", 0.72)
	_cam_push(Vector2(640, 345), 1.45, Vector2(640, 340), 1.5, 0.9)
	_glitch(0.2)
	if _vt > BLADE_T[0] + 1.0:
		_sfx("hx_drip", 1.0, -2.0)


func _ev_strobe() -> void:
	_black.visible = false
	_show_set("tent")
	_cam_cut(Vector2(640, 360), 1.22)
	_strobe_t0 = _ev_time
	_curtain_splat.visible = true
	_door_splat.visible = true
	_sfx("hx_thunder", 1.0, 0.0)


func _ev_silence() -> void:
	_show_set("none")
	_black.visible = true
	_strobe_t0 = -100.0
	Audio.stop_music(0.06)
	_cc.visible = false
	_hud_glitch = 0.8
	_put("_fx_tear", 0.02)


# ------------------------------------------------------------------ events: the reveal
func _ev_reveal_shot() -> void:
	_show_set("tent")
	_black.visible = true
	_anim(_black, "modulate:a", 1.0, 0.0, 1.3, 1)
	_put("_tent_level", 0.62)
	_cam_push(Vector2(640, 360), 1.34, Vector2(640, 368), 1.42, 2.2)
	_sway = 1.2
	_wisp_shake = 0.0
	_cab_wisp.visible = false
	_cab_shade.visible = false
	_hat.visible = true
	_hat_glow.visible = true
	_hat_rock_t0 = 45.4
	for b in _blades:
		(b as Sprite2D).visible = true
	for i in 4:
		(_blades[i] as Sprite2D).position = _blade_pose(i, 1.0)
	_sfx("hx_wind", 0.8, -2.0)


func _ev_chains_drop() -> void:
	_black.visible = false
	_kill(_black, "modulate:a")
	_black.modulate.a = 1.0
	for i in 2:
		var c: Sprite2D = _chains[i]
		_anim(c, "position", Vector2(0, -290), Vector2(-40.0 + i * 80.0, 60), 0.45, 3)
		_anim(c, "modulate:a", 1.0, 0.0, 0.5, 3)
	_anim(_padlock, "position", Vector2(0, -282), Vector2(10, 40), 0.42, 3)
	_anim(_padlock, "modulate:a", 1.0, 0.0, 0.5, 3)
	_sfx("hx_chain", 0.7, 0.0)


func _ev_door_open() -> void:
	_anim(self, "_door_sx", 1.0, -0.34, 2.3, 1)
	_sfx("hx_creak", 1.0, 0.0)
	_glitter_on = true
	_glitter_rate = 70.0


func _ev_turn_wide() -> void:
	_show_set("tent")
	_cam_cut(Vector2(640, 380), 1.0)
	_sway = 0.8
	_glitter_rate = 40.0
	_glitch(0.3)


func _ev_heads_side() -> void:
	_heads = "side"
	for m in _front_row:
		var h: Sprite2D = m["head"]
		h.texture = _tex("hx_mq_side")
		h.position = Vector2(10, -84)
	for m in _bleach:
		var h: Sprite2D = m["head"]
		h.texture = _tex("hx_mq_front")
		h.position = Vector2(0, -84)
	_sfx("hx_turn", 1.0, 0.0)


func _ev_heads_front() -> void:
	_heads = "front"
	for m in _front_row:
		var h: Sprite2D = m["head"]
		h.texture = _tex("hx_mq_front")
		h.position = Vector2(0, -84)
		(m["node"] as Node2D).modulate = Color(0.46, 0.46, 0.46)
	var mm: Dictionary = _front_row[MONO_MQ]
	(mm["head"] as Sprite2D).texture = _tex("mq_front_big")
	(mm["head"] as Sprite2D).scale = Vector2(0.5, 0.5)
	_monocle.scale = Vector2(0.58, 0.58)
	_monocle.position = Vector2(56, -16)
	_monocle_glint.position = Vector2(42, -30)
	_monocle.visible = true
	_monocle_glint.visible = true
	_shake = 3.0


func _ev_monocle_close() -> void:
	var mm: Dictionary = _front_row[MONO_MQ]
	var n: Node2D = mm["node"]
	var head_c := n.position + Vector2(0, -84.0 * float(mm["sc"]))
	_cam_push(head_c + Vector2(8, 4), 2.8, head_c + Vector2(12, -4), 3.3, 1.4)
	n.modulate = Color(0.72, 0.72, 0.72)
	_sway = 0.7
	_sfx("hx_sting", 1.12, -1.0)
	_glitch(0.6)
	_hud_glitch = 1.0


func _ev_smash() -> void:
	_show_set("none")
	_black.visible = true
	_hud.visible = false
	_glitter_on = false
	_cc.visible = false
	_put("_fx_tear", 0.0)
	_sfx("hx_slam", 0.6, -2.0)


func _ev_show_must() -> void:
	_show_t0 = _ev_time
	_put("_fx_tear", 0.12)
	_put("_fx_desat", 0.2)
	_sfx("hx_laugh", 0.8, -5.0)
	_glitch(0.6)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	_show_drips.clear()
	for k in 24:
		_show_drips.append({"u": r.randf(), "len": r.randf_range(20.0, 150.0), "t0": r.randf_range(0.05, 1.2), "tau": r.randf_range(0.5, 1.4),
			"w": r.randf_range(3.0, 7.0)})


func _ev_static_out() -> void:
	_show_t0 = -100.0
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
	_update_camera(delta)
	if _tent.visible:
		_update_tent(vdt)
	if _spot.visible:
		_update_spot(vdt)
	if _snap.visible:
		_update_snap()
	_update_overlays(delta)
	_update_fx(delta)


func _update_camera(delta: float) -> void:
	var k := 1.0
	if _cam_t1 > _cam_t0:
		k = _ease(clampf((_vt - _cam_t0) / (_cam_t1 - _cam_t0), 0.0, 1.0), 1)
	_cam_c = _cam_from_c.lerp(_cam_to_c, k)
	_cam_z = lerpf(_cam_from_z, _cam_to_z, k)
	var sway := Vector2(sin(_vt * 0.83) + 0.5 * sin(_vt * 1.91 + 1.0), sin(_vt * 0.61 + 2.0) + 0.4 * sin(_vt * 1.37)) * _sway
	var rot := (sin(_vt * 0.53) * 0.6 + sin(_vt * 1.21) * 0.4) * 0.0018 * _sway
	var sh := Vector2.ZERO
	if _shake > 0.05:
		sh = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 10.0))
	_world.scale = Vector2(_cam_z, _cam_z)
	_world.rotation = rot
	_world.position = Vector2(640, 360) - (_cam_c * _cam_z).rotated(rot) + sway + sh


func _update_tent(vdt: float) -> void:
	# light level: base * power sag * random flicker, or the lightning strobe
	var l := _tent_level * (1.0 - _sag)
	if randf() < 0.025:
		l *= randf_range(0.65, 0.9)
	var st := _vt - _strobe_t0
	if st >= 0.0 and st < 0.85:
		var on := (st < 0.06) or (st > 0.13 and st < 0.18) or (st > 0.36 and st < 0.45) or (st > 0.62 and st < 0.66)
		l = 2.0 if on else 0.1
		_flash_a = 0.22 if on else 0.0
	_tent.modulate = Color(l, l, l)
	# lamp swing (amplitude grows with every impact and slowly settles)
	_swing_amp = lerpf(_swing_amp, 0.05, minf(1.0, vdt * 0.25))
	var ang := sin(_vt * 1.35) * _swing_amp
	_lamp.rotation = ang
	_floor_glow.position = Vector2(640 + sin(ang) * 520.0, 566)
	_lamp_glow.modulate.a = 0.75 + 0.25 * sin(_vt * 31.0) * sin(_vt * 7.0)
	# door + blood + bulbs + particles
	_bulb_wire.queue_redraw()
	_bulb_glow.queue_redraw()
	_pool_node.queue_redraw()
	_door_deco.queue_redraw()
	_cab_blood.queue_redraw()
	_cab_inner.queue_redraw()
	if _cab_wisp.visible:
		var dart := 0.0
		if _wisp_dart > 0.0:
			dart = [0.0, -7.0, 6.0, -3.0, 8.0][int(_vt / 0.45) % 5]
		_cab_wisp.offset = Vector2(dart / WISP_CAB_SCALE + randf_range(-1.0, 1.0) * _wisp_shake, randf_range(-1.0, 1.0) * _wisp_shake)
	if _hat.visible:
		var ht := _vt - _hat_rock_t0
		_hat.rotation = 0.0 if ht < 0.0 else sin(ht * 5.2) * 0.2 * exp(-ht * 0.75)
	# audience: unison claps (bodies jerk, profile hands meet)
	var p := _clap_pulse(_vt)
	for m in _bleach:
		var n: Node2D = m["node"]
		var hs: Array = m["hands"]
		if hs.size() == 2:
			(hs[1] as Sprite2D).position.x = 94.0 - 26.0 * p
			(hs[0] as Sprite2D).position.x = 60.0 + 4.0 * p
		n.position = (m["base"] as Vector2) + Vector2(0, -3.0 * p)
	for m in _front_row:
		var n2: Node2D = m["node"]
		n2.position = (m["base"] as Vector2) + Vector2(0, -6.0 * p)
		(m["head"] as Sprite2D).rotation = 0.03 * p
	if _monocle_glint.visible:
		var gp := 0.5 + 0.5 * sin(_vt * 3.1)
		_monocle_glint.modulate = Color(1, 0.95, 0.8, 0.35 + 0.65 * gp * gp)
		_monocle_glint.rotation = _vt * 0.8
	_update_glitter(vdt)
	_tent_fx.queue_redraw()
	_tent_fx_add.queue_redraw()


func _update_glitter(vdt: float) -> void:
	if _glitter_on:
		_glitter_acc += vdt * _glitter_rate
		while _glitter_acc >= 1.0:
			_glitter_acc -= 1.0
			var inside := randf() < 0.45
			var pos := CAB_POS + Vector2(randf_range(-80, 80), -400) * CAB_SCALE if inside else Vector2(randf_range(-100, 1380), randf_range(-60, 0))
			var red := randf() < 0.35
			var col := Color(0.62, 0.02, 0.06) if red else Color(0.78, 0.72, 1.0)
			if not red and randf() < 0.4:
				col = Color(0.85, 0.85, 0.9)
			_glitter.append([pos, Vector2(randf_range(-6, 6), randf_range(22, 48)), 0.0, randf_range(6.0, 10.0), randf_range(1.4, 3.4), col, randf() * TAU])
	var keep: Array = []
	for g in _glitter:
		g[2] = float(g[2]) + vdt
		var v: Vector2 = g[1]
		var ph: float = g[6]
		g[0] = (g[0] as Vector2) + Vector2(v.x + sin(_vt * 1.3 + ph) * 14.0, v.y) * vdt
		if float(g[2]) < float(g[3]) and (g[0] as Vector2).y < 760.0:
			keep.append(g)
	_glitter = keep


func _update_spot(vdt: float) -> void:
	var l := _spot_level
	if l > 0.0 and randf() < 0.04:
		l *= randf_range(0.55, 0.85)
	_spot_cone.modulate.a = 0.5 * l
	_spot_mat.set_shader_parameter("gain", 1.5 * l)
	var breathe := 1.0 + 0.006 * sin(_vt * 2.3)
	_spot_wisp.scale = Vector2(1.0, breathe)
	_spot_wisp.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _wisp_shake
	for d in _dust:
		var p: Vector2 = d[0]
		var v: Vector2 = d[1]
		p += (v + Vector2(sin(_vt * 0.7 + float(d[3])) * 5.0, 0)) * vdt
		if p.y < 0:
			p.y += 720
		elif p.y > 720:
			p.y -= 720
		d[0] = p
	_spot_fx.queue_redraw()


func _update_snap() -> void:
	var s := _eye_scale
	_snap_eye.scale = Vector2(s, s * maxf(0.04, _eye_open))
	var pulse := 0.75 + 0.25 * sin(_vt * 2.1)
	_snap_eye_glow.position = _snap_eye.position
	_snap_eye_glow.scale = Vector2(3.2, 2.2) * s * (0.85 + 0.3 * pulse)
	_snap_eye_glow.modulate.a = 0.6 * _eye_open * pulse
	# the silhouette's eye socket (620, 330 in its 1000x800 texture) sits on the eye
	var ss := s * 1.33
	_snap_sil.scale = Vector2(ss, ss)
	_snap_sil.position = _snap_eye.position - Vector2(120, -70) * ss
	_snap_sil.modulate = Color(1.6, 1.2, 1.2)
	if _snap_close.visible:
		_snap_close.offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))


func _update_overlays(delta: float) -> void:
	if _sub_face.visible and _t > _subliminal_until:
		_sub_face.visible = false
	if _cc.visible and _t > _cc_until:
		_cc.visible = false
	if _title.visible:
		_title.queue_redraw()
		var tn := _vt - _title_name_t0
		if tn >= 0.0:
			var cnt := mini(31, int(tn / 0.045) + 1)
			if cnt > _typed and cnt < 31:
				_typed = cnt
				if cnt % 2 == 0:
					Audio.sfx("tick", 1.5, -15.0)
	if _show_t0 > 0.0 or _trans_t0 > 0.0:
		_endtext.queue_redraw()
	if _lens_t0 > 0.0 and _vt - _lens_t0 < 2.6:
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
func _draw_bulbs() -> void:
	var n := _bulb_wire
	var prev := Vector2(-20, 108)
	var pts := PackedVector2Array([prev])
	for b in _bulbs:
		pts.append(b["pos"])
	pts.append(Vector2(1300, 108))
	n.draw_polyline(pts, Color(0.06, 0.05, 0.04), 2.0)
	for i in _bulbs.size():
		var b: Dictionary = _bulbs[i]
		var br := _bulb_level(b)
		var base := Color(1.0, 0.18, 0.12) if b["red"] else Color(1.0, 0.92, 0.7)
		var c := Color(0.12, 0.1, 0.08).lerp(base, br)
		n.draw_circle(b["pos"] + Vector2(0, 6), 5.0, c)
		n.draw_rect(Rect2(b["pos"] + Vector2(-2.5, -1), Vector2(5, 4)), Color(0.08, 0.07, 0.06))


func _bulb_level(b: Dictionary) -> float:
	if b["dead"]:
		return 0.0
	if _vt < float(b["on"]):
		return 0.0
	var die: float = b["die"]
	if die > 0.0 and _vt > die:
		return 0.0 if _vt > die + 0.25 else randf()
	var ph: float = b["ph"]
	var f := 0.82 + 0.18 * sin(_vt * 13.0 + ph) * sin(_vt * 3.1 + ph * 2.0)
	if _vt - float(b["on"]) < 0.4:
		f *= 1.0 if randf() < 0.5 else 0.1
	if fmod(_vt * 0.37 + ph, 1.0) < 0.025:
		f *= 0.15
	return clampf(f, 0.0, 1.0)


func _draw_bulb_glow() -> void:
	var n := _bulb_glow
	for b in _bulbs:
		var br := _bulb_level(b)
		if br <= 0.02:
			continue
		var col := Color(0.9, 0.12, 0.08, 0.6 * br) if b["red"] else Color(0.75, 0.68, 0.5, 0.42 * br)
		var sz := 74.0
		n.draw_texture_rect(_glow_tex, Rect2(b["pos"] + Vector2(-sz * 0.5, 6.0 - sz * 0.5), Vector2(sz, sz)), false, col)


func _drip(n: CanvasItem, x: float, y0: float, ln: float, w: float, a: float = 1.0) -> void:
	if ln < 0.5:
		return
	var c := Color(BLOOD, a)
	n.draw_circle(Vector2(x, y0), w * 0.8, Color(BLOOD_D, a))
	n.draw_rect(Rect2(x - w * 0.5, y0, w, ln), c)
	n.draw_circle(Vector2(x, y0 + ln), w * 0.72, c)
	n.draw_line(Vector2(x - w * 0.18, y0 + 1.0), Vector2(x - w * 0.18, y0 + ln * 0.92), Color(BLOOD_H, 0.7 * a), maxf(1.0, w * 0.22))
	n.draw_circle(Vector2(x - w * 0.22, y0 + ln - w * 0.15), maxf(0.8, w * 0.18), Color(1, 1, 1, 0.22 * a))


func _drip_len(d: Dictionary, t: float) -> float:
	var t0: float = d["t0"]
	if t < t0:
		return 0.0
	return float(d["len"]) * (1.0 - exp(-(t - t0) / float(d["tau"])))


func _draw_door_blood() -> void:
	var n := _door_deco
	for i in 3:
		var bt: float = BLADE_T[i]
		var k := clampf((_vt - bt - 0.2) / 1.5, 0.0, 1.0)
		if k <= 0.0:
			continue
		var sy: float = BLADE_Y[i] - DOOR_PIVOT.y + 3.0
		n.draw_rect(Rect2(0, sy - 2.0, 240, 3.0 + 3.0 * k), Color(BLOOD_D, 0.9 * k))
		n.draw_rect(Rect2(0, sy + 1.0, 240, 1.5 * k), Color(BLOOD, 0.9 * k))
	# bottom gap + hinge gap seep after the second blade
	var k2 := clampf((_vt - BLADE_T[1] - 0.3) / 3.0, 0.0, 1.0)
	if k2 > 0.0:
		n.draw_rect(Rect2(0, 236.0 - 4.0 * k2, 240, 4.0 * k2 + 4.0), Color(BLOOD_D, k2))
		n.draw_rect(Rect2(236.0 - 3.0 * k2, -240, 3.0 * k2 + 4.0, 480), Color(BLOOD_D, 0.8 * k2))
	for d in _door_drips:
		_drip(n, d["x"], d["y"], _drip_len(d, _vt), d["w"])


func _draw_frame_blood() -> void:
	var n := _cab_blood
	for d in _frame_drips:
		_drip(n, d["x"], d["y"], _drip_len(d, _vt), d["w"])


func _draw_cab_inner() -> void:
	# a small dark pool on the cabinet floor under the hat (visible once the door opens)
	if _vt < BLADE_T[3]:
		return
	var n := _cab_inner
	var k := clampf((_vt - BLADE_T[3]) / 3.0, 0.0, 1.0)
	_ellipse(n, Vector2(-30, -56), Vector2(90, 13) * (0.6 + 0.4 * k), BLOOD_D)
	_ellipse(n, Vector2(-36, -57), Vector2(74, 9) * (0.6 + 0.4 * k), BLOOD)
	_ellipse(n, Vector2(-70, -59), Vector2(20, 3), Color(BLOOD_H, 0.8))


func _ellipse(n: CanvasItem, c: Vector2, r: Vector2, col: Color, wob: float = 0.0, seg: int = 28) -> void:
	if r.x < 0.6 or r.y < 0.6:
		return
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		var w := 1.0 + wob * (sin(3.0 * a + 1.3) * 0.6 + sin(5.0 * a + 0.4) * 0.3 + sin(9.0 * a) * 0.2)
		pts.append(c + Vector2(cos(a) * r.x * w, sin(a) * r.y * w))
	n.draw_colored_polygon(pts, col)


func _pool_r() -> float:
	var t := _vt - (BLADE_T[0] + 0.3)
	if t <= 0.0:
		return 0.0
	return 330.0 * (1.0 - exp(-t / 5.0)) + t * 2.0


func _draw_pool() -> void:
	var r := _pool_r()
	if r < 2.0:
		return
	var n := _pool_node
	var c := CAB_POS + Vector2(0, 2.0 + r * 0.1)
	_ellipse(n, c, Vector2(r, r * 0.27), BLOOD_D, 0.16, 40)
	_ellipse(n, c + Vector2(-r * 0.02, -r * 0.01), Vector2(r * 0.88, r * 0.23), BLOOD, 0.14, 40)
	_ellipse(n, c + Vector2(-r * 0.28, r * 0.06), Vector2(r * 0.26, r * 0.035), Color(BLOOD_H, 0.75), 0.0, 20)
	_ellipse(n, c + Vector2(-r * 0.32, r * 0.06), Vector2(r * 0.07, r * 0.01), Color(1, 1, 1, 0.18), 0.0, 12)


func _draw_tent_fx(additive: bool) -> void:
	var n := _tent_fx_add if additive else _tent_fx
	for g in _glitter:
		var col: Color = g[5]
		var is_red := col.r > col.b * 2.0
		if is_red == additive:
			continue
		var tw := 0.55 + 0.45 * sin(_vt * 9.0 + float(g[6]) * 3.0)
		var life: float = g[2]
		var fade := clampf(life / 0.4, 0.0, 1.0) * clampf((float(g[3]) - life) / 1.5, 0.0, 1.0)
		var s: float = float(g[4]) * (0.6 + 0.4 * tw)
		var p: Vector2 = g[0]
		var c2 := Color(col.r, col.g, col.b, fade * (0.9 if is_red else tw))
		n.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.6), p + Vector2(s * 0.6, 0), p + Vector2(0, s * 1.6), p + Vector2(-s * 0.6, 0)]), c2)


func _draw_dust() -> void:
	var n := _spot_fx
	if _spot_level <= 0.0:
		return
	for d in _dust:
		var p: Vector2 = d[0]
		var cone_w := 30.0 + p.y * 0.33
		var inside := clampf(1.0 - absf(p.x - 640.0) / cone_w, 0.0, 1.0)
		if inside <= 0.0:
			continue
		n.draw_circle(p, float(d[2]), Color(0.8, 0.85, 0.8, 0.35 * inside))


func _draw_lens() -> void:
	if _lens_t0 < 0.0:
		return
	var t := _vt - _lens_t0
	var fade := clampf((2.6 - t) / 0.8, 0.0, 1.0)
	var n := _lens
	for d in _lens_drops:
		var td: float = t - float(d["d"])
		if td < 0.0:
			continue
		var p: Vector2 = d["p"]
		var r: float = d["r"]
		var grow := clampf(td / 0.08, 0.0, 1.0)
		var a := 0.9 * fade
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
	# WISP VANDERLOO - ACE MAGICIAN, typed
	var tn := _vt - _title_name_t0
	if tn >= 0.0:
		var full := "WISP VANDERLOO  —  ACE MAGICIAN"
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
	# THE FINAL VANISHING ACT, letters wavering
	var ta := _vt - _title_act_t0
	if ta >= 0.0:
		var txt3 := "THE FINAL VANISHING ACT"
		var sz3 := 62
		var a3 := clampf(ta / 0.9, 0.0, 1.0)
		var w3 := df.get_string_size(txt3, HORIZONTAL_ALIGNMENT_LEFT, -1, sz3).x
		var x0 := 640 - w3 * 0.5
		for i in txt3.length():
			var ch := txt3[i]
			var x := x0 + df.get_string_size(txt3.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, sz3).x
			var jy := sin(_vt * 3.0 + i * 0.7) * 2.0 + (randf_range(-3, 3) if randf() < 0.04 else 0.0)
			var p3 := Vector2(x, 488 + jy)
			n.draw_string(df, p3 + Vector2(-3, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz3, Color(0.7, 0.0, 0.05, 0.4 * a3))
			n.draw_string(df, p3 + Vector2(3, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz3, Color(0.2, 0.85, 0.8, 0.22 * a3))
			n.draw_string(df, p3, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz3, Color(BONE_TXT, a3))


func _draw_end() -> void:
	var n := _endtext
	var df := Style.display_font()
	if _show_t0 > 0.0:
		var t := _vt - _show_t0
		var txt := "THE SHOW MUST GO ON"
		var sz := 96
		var w := df.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var x0 := 640 - w * 0.5
		var base_y := 380.0
		var a := clampf(t / 0.25, 0.0, 1.0)
		# drips first (they hang from the letters)
		for d in _show_drips:
			var td: float = t - float(d["t0"])
			if td <= 0.0:
				continue
			var ln: float = float(d["len"]) * (1.0 - exp(-td / float(d["tau"])))
			_drip(n, x0 + 8.0 + (w - 16.0) * float(d["u"]), base_y - 6.0, ln, d["w"], a)
		for i in txt.length():
			var ch := txt[i]
			var x := x0 + df.get_string_size(txt.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var j := Vector2(randf_range(-2, 2), randf_range(-2, 2))
			if randf() < 0.05:
				j.x += randf_range(-14, 14)
			var p := Vector2(x, base_y) + j
			n.draw_string(df, p + Vector2(5, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.2, 0.8, 0.75, 0.16 * a))
			n.draw_string_outline(df, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6, Color(BLOOD_D, a))
			n.draw_string(df, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(BLOOD_H, a))
			n.draw_string(df, p + Vector2(0, -3), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.85, 0.1, 0.16, 0.25 * a))
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
	var tc := "%02d:%02d:%02d:%02d" % [3, floori(frames / 1800.0) + 13, floori(frames / 30.0) % 60, frames % 30]
	var items := [["REC", Vector2(78, 70), 30], ["SP", Vector2(1168, 70), 30], [tc, Vector2(56, 672), 28],
		["NOV. 07 1987", Vector2(1000, 640), 26], ["AM 03:13", Vector2(1064, 606), 26]]
	for it in items:
		var s := _glitchify(str(it[0]))
		var p: Vector2 = it[1]
		var fs: int = it[2]
		n.draw_string(_mono, p + j + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, shadow)
		n.draw_string(_mono, p + j + Vector2(-1.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.2, 0.2, 0.25))
		n.draw_string(_mono, p + j, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white)
	if fmod(_t, 1.0) < 0.6:
		n.draw_circle(Vector2(58, 60) + j, 10, Color(0.85, 0.05, 0.08))
	# corner brackets of the camcorder viewfinder
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
	elif Audio.current_music() == "execution_horror":
		Audio.stop_music(0.5)
	_hint.modulate.a = 0.0
	_hint.visible = false
	print_verbose("[execution] finished at t=%.2f skipped=%s" % [_t, skipped])
	finished.emit({})


## Keep the soundtrack in sync with the timeline when the pause menu freezes the tree.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			Audio.set_music_paused(true)
		NOTIFICATION_UNPAUSED, NOTIFICATION_EXIT_TREE:
			Audio.set_music_paused(false)
