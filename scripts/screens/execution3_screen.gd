extends "res://scripts/screens/cutscene_base.gd"
## EXECUTION (Chapter 3) - "STOP PRESS" (docs/DESIGN3.md, "Endings"; SPOILERS). A 60 s cursed broadcast in the
## style of the other execution tapes, but from Case 3 on the death happens on screen: hard silhouette frames,
## impact cuts, violent sound and a lot of dark-red blood, and it ends on what was done, not on a joke.
##   0  PLEASE STAND BY, a press hammering under the static        4  title card
##  10  the endless newsroom of dummy reporters, flashbulbs        17  Pepper strapped to the bed of the press,
##      her camera taped to her paws; through her viewfinder, the plate        24  Snapjaw's red eye behind the glass
##  28  the plate comes down in strokes; the third is the kill     38  through her fallen camera
##  41  the press keeps running: page after page, her name, soaked red        51  the dummies turn to the camera
##  54  PRINTED AS RECEIVED, static, TRANSMISSION ENDED
## Clock-driven on cutscene_base.gd (no awaits). Hold Space / Enter / mouse for 1 s (after 3 s) to skip; about
## 0.3 s under autotest. Debug: --exec3-t=<seconds> starts there (with --shot= for a timed screenshot).
## Art: art/props/sp_*.svg (tools/gen_end3_art.py). Sound: execution_press, sp_* (tools/gen_end3_audio.py), hx_*.

const END_TIME := 60.0
const MUSIC_ID := "execution_press"
const KILL_T := 35.6

const BLOOD := Color("7a0010")
const BLOOD_D := Color("3a0008")
const BLOOD_H := Color("b3001b")
const BONE_TXT := Color(0.86, 0.82, 0.72)
const AQUA_TXT := Color(0.66, 0.95, 0.92)

# ---- press-set geometry (world px); the press art is tools/gen_end3_art.py's 900x800 frame
const PRESS_POS := Vector2(190, -60)       # top-left of sp_press in the close set
const BED_FOOT := 640.0                     # world y of the bed's foot (press y 700)
const PEP_SC := 0.8
const PEP_TOP := 192.0                      # world y of the top of her hat when unsquashed
const PLATE_UP := 110.0                     # the plate's crushing face, raised
const PLATE_S1 := 176.0
const PLATE_S2 := 238.0
const PLATE_W := 520.0
const PLATE_H := 900.0
# the same press, far away on the newsroom dais
const FAR_PRESS_SC := 0.2
const FAR_PRESS_POS := Vector2(550, 160)

## Worn videotape that keeps the blood red while everything else goes grey (as in execution2_screen.gd).
const TAPE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
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

## Portrait lighting: one soft light (in UV space) over a dark ambient, partly desaturated.
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

# ------------------------------------------------------------------ state (animated through _anim)
var _red_keep := 1.0
var _plate_y := PLATE_UP
var _lamp := 1.0
var _lamp_swing := 0.0
var _pep_shake := 0.0
var _eye_open := 0.0
var _eye_k := 1.0
var _lever := 0.0
var _pov_z := 1.0
var _pov_rush := 0.0
var _page_close := 0.0
var _impact := 0              # 0 off, 1 white field + black silhouettes, 2 red field, 3 black
var _jet := 0.0               # blood squirting from under the plate (decays)
var _pool := 0.0              # how far the pool has spread (0..1)
var _soak := 0.0
var _turned := false
var _hb_rate := 0.0
var _hb_next := 0.0

var _cam_c := C
var _cam_z := 1.0
var _cam_from_c := C
var _cam_to_c := C
var _cam_from_z := 1.0
var _cam_to_z := 1.0
var _cam_t0 := 0.0
var _cam_t1 := 0.0
var _sway := 1.5

var _cc_until := 0.0
var _title_exec_t0 := 1.0e9
var _title_name_t0 := 1.0e9
var _title_act_t0 := 1.0e9
var _printed_t0 := -1.0
var _trans_t0 := -1.0
var _kill_t0 := 1.0e9
var _pov_floor := false
var _stamp_blink := 0.0

# ------------------------------------------------------------------ nodes
var _tx := {}
var _mono: SystemFont
var _sets := {}
var _news: Node2D
var _news_bg: Sprite2D
var _press: Node2D
var _booth: Node2D
var _pov: Node2D
var _pages_set: Node2D
var _cam_set: Node2D
var _far_dummies: Array = []
var _fg_dummies: Array = []
var _pep: Sprite2D
var _pep_far: Sprite2D
var _plate: Sprite2D
var _plate_far: Sprite2D
var _snap_close: Sprite2D
var _snap_mat: ShaderMaterial
var _pep_mat: ShaderMaterial
var _pages: Array = []
var _page_spawn := 0.0
var _page_seq := 0
var _decals: Array = []
var _flashes: Array = []
var _standby: Control
var _sub_face: TextureRect
var _title: CPainter
var _endtext: CPainter
var _hud: CPainter
var _cc: Control
var _cc_label: Label
var _cc_box: ColorRect
var _cpainters: Array = []
var _vf: CPainter
var _drip_r := RandomNumberGenerator.new()


# ================================================================== contract hooks
func _debug_start_time() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--exec3-t="):
			var t := clampf(float(a.get_slice("=", 1)), 0.0, END_TIME - 0.5)
			if Game.shot_path != "":
				# a timed screenshot: run the last SHOT_LEAD seconds for real, so flashes and particles exist, then shoot
				_shot_at = t
				return maxf(0.0, t - SHOT_LEAD)
			return t
	return 0.0


## Timed screenshots (--exec3-t with --shot): the frame at exactly that time. Pass a long --shot-delay as a safety net.
const SHOT_LEAD := 0.45
var _shot_at := -1.0


func _check_shot() -> void:
	if _shot_at >= 0.0 and _t >= _shot_at and not _ff and Game.main and Game.main.has_method("save_shot"):
		_shot_at = -1.0
		Game.main.save_shot()


func _finish(skipped: bool) -> void:
	if _done:
		return
	if Audio.current_music() == MUSIC_ID:
		Audio.stop_music(0.3 if skipped else 0.5)
	super._finish(skipped)


# ================================================================== building
func _build_scene() -> void:
	_end_at = END_TIME
	_skip_after = 3.0
	_rng.seed = 3131
	_drip_r.seed = 77
	var sh := Shader.new()
	sh.code = TAPE_SHADER
	_vhs_mat.shader = sh
	_set_vhs(true)
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Courier New", "Menlo", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_mono.font_weight = 700
	for n in ["sp_standby", "sp_newsroom", "sp_newsroom_turned", "sp_dummy_back", "sp_dummy_front", "sp_press", "sp_press_front",
			"sp_plate", "sp_plate_under", "sp_straps", "sp_camera_taped", "sp_paper", "sp_booth", "lx_eye"]:
		_tx[n] = Assets.prop(n)
	for e in ["sad", "shock"]:
		_tx["pepper_" + e] = Assets.portrait("pepper", e)
	_tx["snapjaw_happy"] = Assets.portrait("snapjaw", "happy")
	_build_news()
	_build_press()
	_build_booth()
	_build_pov()
	_build_pages()
	_build_cam_insert()
	_build_overlays()
	_show_set("")


func _tex(n: String) -> Texture2D:
	return _tx.get(n, null)


func _root(name: String) -> Node2D:
	var n := Node2D.new()
	n.name = name
	_world.add_child(n)
	_sets[name] = n
	return n


func _sp(parent: Node, tex: Texture2D, pos: Vector2, sc: float = 1.0, centered: bool = true) -> Sprite2D:
	var s := _spr(parent, tex, pos, centered)
	s.scale = Vector2(sc, sc)
	return s


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


func _bg_fill(parent: Node2D, col: Color) -> void:
	var p := _painter(parent, func(ci: Node2D) -> void: ci.draw_rect(Rect2(-900, -900, 3080, 2520), col))
	parent.move_child(p, 0)


## The newsroom: rows of dummy reporters facing away, toward the press on its dais at the far end.
func _build_news() -> void:
	_news = _root("news")
	_bg_fill(_news, Color("050606"))
	_news_bg = _sp(_news, _tex("sp_newsroom"), C)
	var far := _node(_news, FAR_PRESS_POS, FAR_PRESS_SC)
	_sp(far, _tex("sp_press"), Vector2.ZERO, 1.0, false)
	_pep_far = _sp(far, _tex("pepper_sad"), Vector2(450, 700), PEP_SC)
	_pep_far.offset = Vector2(0, -300)
	_pep_far.modulate = Color(0.75, 0.75, 0.75)
	_plate_far = _sp(far, _tex("sp_plate"), Vector2.ZERO, 1.0, false)
	_sp(far, _tex("sp_press_front"), Vector2.ZERO, 1.0, false)
	var glow := _sp(_news, _soft, Vector2(640, 250), 3.2)
	glow.material = _add_mat
	glow.modulate = Color(1.0, 0.85, 0.6, 0.35)
	# near rows, as sprites, so they can turn round (far rows are painted into the backdrop)
	var rows := [[0.42, 520.0, [210.0, 360.0, 920.0, 1070.0]], [0.62, 610.0, [120.0, 330.0, 950.0, 1160.0]], [0.95, 790.0, [140.0, 1140.0]]]
	for r in rows:
		var sc: float = r[0]
		var y: float = r[1]
		for x in r[2]:
			var d := _sp(_news, _tex("sp_dummy_back"), Vector2(float(x), y), sc)
			d.offset = Vector2(0, -170)
			d.modulate = Color(0.55, 0.55, 0.55) if sc < 0.9 else Color(0.32, 0.32, 0.32)
			_far_dummies.append(d)
	_painter(_news, _draw_flashes, true)


## The press, close: frame, the bed with Pepper strapped to it, the plate, the guide rails, the front row of dummies.
func _build_press() -> void:
	_press = _root("press")
	_bg_fill(_press, Color("060607"))
	var wall := _painter(_press, _draw_press_backdrop)
	wall.z_index = 0
	var lamp := _sp(_press, _soft, Vector2(640, 40), 7.0)
	lamp.material = _add_mat
	lamp.modulate = Color(1.0, 0.86, 0.62, 0.28)
	lamp.name = "lampglow"
	_sp(_press, _tex("sp_press"), PRESS_POS, 1.0, false)
	_pep = _sp(_press, _tex("pepper_sad"), Vector2(640, BED_FOOT), PEP_SC)
	_pep.offset = Vector2(0, -300)
	_pep_mat = _lit_mat(Vector2(0.5, -0.15), 1.25, Color(1.0, 0.93, 0.8), Color(0.05, 0.06, 0.07), 0.45, 1.5)
	_pep.material = _pep_mat
	var straps := _sp(_pep, _tex("sp_straps"), Vector2.ZERO)
	straps.offset = Vector2(0, -300)
	straps.modulate = Color(0.85, 0.85, 0.85)
	_painter(_press, _draw_plate_shadow)
	_plate = _sp(_press, _tex("sp_plate"), Vector2.ZERO, 1.0, false)
	_plate.modulate = Color(1.55, 1.55, 1.6)
	_painter(_press, _draw_plate_edge, true)
	_sp(_press, _tex("sp_press_front"), PRESS_POS, 1.0, false)
	_painter(_press, _draw_press_blood_over)
	for x in [250.0, 640.0, 1030.0]:
		var d := _sp(_press, _tex("sp_dummy_back"), Vector2(x, 1040), 1.5)
		d.offset = Vector2(0, -170)
		d.modulate = Color(0.2, 0.2, 0.2)
		_fg_dummies.append(d)
	_painter(_press, _draw_fg_blood)
	_painter(_press, _draw_flashes, true)
	_painter(_press, _draw_impact)


func _build_booth() -> void:
	_booth = _root("booth")
	_bg_fill(_booth, Color("030202"))
	var eg := _sp(_booth, _soft, Vector2(640, 300), 2.4)
	eg.material = _add_mat
	eg.name = "eyeglow"
	var eye := _sp(_booth, _tex("lx_eye"), Vector2(640, 300), 0.5)
	eye.name = "eye"
	_snap_close = _sp(_booth, _tex("snapjaw_happy"), Vector2(640, 470), 1.6)
	_snap_mat = _lit_mat(Vector2(0.5, 1.1), 1.7, Color(1.0, 0.12, 0.08), Color(0.04, 0.02, 0.03), 0.25, 2.2)
	_snap_close.material = _snap_mat
	_snap_close.visible = false
	_sp(_booth, _tex("sp_booth"), C)
	_painter(_booth, _draw_booth)


func _build_pov() -> void:
	_pov = _root("pov")
	_bg_fill(_pov, Color("020202"))
	_painter(_pov, _draw_pov)
	# her viewfinder stays square to the screen even when the camera lies tilted on the floor
	_vf = _cpainter(_over, _draw_vf)


func _build_pages() -> void:
	_pages_set = _root("pages")
	_bg_fill(_pages_set, Color("070605"))
	_painter(_pages_set, _draw_rollers)
	var cp := _painter(_pages_set, _draw_close_page)
	cp.z_index = 5


func _build_cam_insert() -> void:
	_cam_set = _root("cam")
	_bg_fill(_cam_set, Color("050505"))
	var cs := _sp(_cam_set, _tex("sp_camera_taped"), Vector2(640, 380), 1.9)
	cs.material = _lit_mat(Vector2(0.45, 0.05), 1.8, Color(1.0, 0.93, 0.82), Color(0.34, 0.33, 0.34), 0.3, 1.9)
	_painter(_cam_set, func(ci: Node2D) -> void:
		if fmod(_t, 0.9) < 0.5:
			ci.draw_circle(Vector2(640 + (372 - 260) * 1.9, 380 + (136 - 180) * 1.9), 22.0, Color(1.0, 0.1, 0.1, 0.55)), true)


func _build_overlays() -> void:
	_standby = _ctrl(_over)
	var card := TextureRect.new()
	card.texture = _tex("sp_standby")
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
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
	_sub_face = TextureRect.new()
	_sub_face.texture = _tex("sp_dummy_front")
	_sub_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sub_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sub_face.position = Vector2(390, 20)
	_sub_face.size = Vector2(500, 680)
	_sub_face.visible = false
	_sub_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_standby.add_child(_sub_face)
	_standby.visible = false
	_title = _cpainter(_over, _draw_title)
	_title.visible = false
	_endtext = _cpainter(_over, _draw_end)
	# the camcorder HUD and the captions sit above the tape, crisp
	_hud = _cpainter(self, _draw_hud)
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
	var at := _vhs.get_index() + 1
	move_child(_hud, at)
	move_child(_cc, at + 1)


func _show_set(which: String) -> void:
	for k in _sets:
		(_sets[k] as Node2D).visible = k == which
	if _hud:
		_hud.visible = which != ""


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


func _cam_push(c0: Vector2, z0: float, c1: Vector2, z1: float, dur: float) -> void:
	_cam_cut(c0, z0)
	_cam_to_c = c1
	_cam_to_z = z1
	_cam_t1 = _ev_time + dur


func _update_camera() -> void:
	var k := 1.0
	if _cam_t1 > _cam_t0:
		k = _ease(clampf((_t - _cam_t0) / (_cam_t1 - _cam_t0), 0.0, 1.0), 1)
	_cam_c = _cam_from_c.lerp(_cam_to_c, k)
	_cam_z = lerpf(_cam_from_z, _cam_to_z, k)
	var sway := Vector2(sin(_t * 0.83) + 0.5 * sin(_t * 1.91 + 1.0), sin(_t * 0.61 + 2.0) + 0.4 * sin(_t * 1.37)) * _sway
	var rot := (sin(_t * 0.53) * 0.6 + sin(_t * 1.21) * 0.4) * 0.0018 * _sway
	if _pov_floor:
		rot += -0.32
	for k2 in _sets:
		var n: Node2D = _sets[k2]
		if not n.visible:
			continue
		n.scale = Vector2(_cam_z, _cam_z)
		n.rotation = rot
		n.position = C - (_cam_c * _cam_z).rotated(rot) + sway


# ================================================================== the timeline
func _schedule() -> void:
	# ---- 0.0  cold open
	_at(0.0, _ev_standby)
	_at(0.35, func() -> void: _anim(self, "_fx_static", 1.0, 0.45, 0.5, 2))
	for t in [0.5, 1.4, 2.3, 3.2]:
		_at(t, func() -> void: _sfx("sp_press", 0.62, -16.0))
	_at(2.95, _ev_subliminal)
	_at(3.06, func() -> void: _sub_face.visible = false)
	_at(3.45, _ev_standby_glitch)
	_at(3.9, _ev_black)
	# ---- 4.0  title
	_at(4.0, _ev_title)
	_at(4.2, _ev_title_exec)
	_at(5.7, _ev_title_name)
	_at(7.3, _ev_title_act)
	for i in 10:
		_at(7.3 + i * 0.13, func() -> void: _sfx("sp_press", 1.7 + randf() * 0.2, -14.0))
	_at(8.75, func() -> void: _sfx("sp_bell", 0.9, -6.0))
	_at(9.3, func() -> void: _anim(self, "_fx_tear", 0.05, 0.7, 0.6, 3))
	_at(9.9, _ev_title_out)
	# ---- 10.0 the newsroom
	_at(10.0, _ev_news)
	_at(10.7, func() -> void: _cc_show("[ TYPEWRITERS ]", 2.4))
	for t in [10.2, 11.8, 13.4, 15.0]:
		_at(t, func() -> void: _sfx("sp_type", randf_range(0.92, 1.05), -6.0))
	for t in [11.5, 12.6, 13.3, 14.4, 15.2, 15.7, 16.1]:
		_at(t, _ev_bulb.bind(1))
	_at(13.0, func() -> void: _cc_show("[ FLASHBULBS ]", 2.0))
	_at(16.6, func() -> void: _glitch(0.25, 0.6))
	# ---- 17.0 Pepper on the bed of the press
	_at(17.0, _ev_press_close)
	_at(18.6, func() -> void: _sfx("hx_whisper", 0.9, -8.0))
	_at(19.3, _ev_cam_insert)
	_at(20.6, _ev_press_back)
	_at(20.7, func() -> void: _sfx("sp_hiss", 0.8, -4.0))
	_at(22.2, _ev_pov.bind(1.0, 1.15))
	_at(23.6, _ev_black)
	# ---- 24.0 behind the glass
	_at(24.0, _ev_booth)
	_at(25.0, func() -> void: _anim(self, "_eye_k", 1.0, 0.05, 0.08, 0))
	_at(25.12, func() -> void: _anim(self, "_eye_k", 0.05, 1.0, 0.12, 0))
	_at(26.0, func() -> void:
		_sfx("lx_laugh", 0.9, -2.0)
		_glitch(0.3, 0.5))
	_at(27.0, _ev_snap_jump)
	_at(27.4, func() -> void: _snap_close.visible = false)
	_at(27.6, _ev_lever)
	# ---- 28.4 the strokes
	_at(28.4, _ev_press_wide)
	_at(28.6, func() -> void: _sfx("sp_hiss", 1.0, -2.0))
	_at(29.0, _ev_stroke.bind(PLATE_S1, 0))
	_at(30.2, _ev_face)
	_at(31.5, _ev_pov.bind(1.45, 1.6))
	_at(31.8, func() -> void: _sfx("sp_hiss", 1.1, 0.0))
	_at(32.2, _ev_stroke.bind(PLATE_S2, 1))
	_at(33.4, _ev_face)
	_at(34.6, _ev_pov_rush)
	_at(35.5, _ev_black)
	# the kill, in hard frames: halfway down (white), all the way down (red), the spray (white), black, then the sight
	_at(KILL_T, _ev_kill)
	_at(KILL_T + 0.06, _ev_kill_down)
	_at(KILL_T + 0.12, func() -> void: _impact = 1)
	_at(KILL_T + 0.18, func() -> void: _impact = 3)
	_at(KILL_T + 0.25, _ev_after_kill)
	for t in [KILL_T + 0.8, KILL_T + 1.5, KILL_T + 2.3]:
		_at(t, func() -> void: _put("_jet", 1.0))
	_at(36.6, func() -> void: _cc_show("[ SILENCE ]", 1.6))
	for t in [37.1, 37.8, 38.2]:
		_at(t, func() -> void: _sfx("lx_drip", randf_range(0.85, 1.1), -4.0))
	# ---- 38.6 through her fallen camera
	_at(38.6, _ev_pov_floor)
	for t in [39.3, 40.1, 40.6]:
		_at(t, func() -> void: _sfx("hx_drip", randf_range(0.9, 1.1), -6.0))
	# ---- 41.0 the press keeps running
	_at(41.0, _ev_pages)
	_at(41.5, func() -> void: _cc_show("[ THE PRESS KEEPS RUNNING ]", 2.6))
	var r := 41.0
	while r < 50.4:
		_at(r, func() -> void: _sfx("sp_run", 1.0, -3.0))
		r += 2.4
	_at(44.6, _ev_page_close)
	_at(46.2, _ev_page_close_out)
	# ---- 50.6 the dummies turn
	_at(50.6, _ev_news_end)
	_at(51.6, _ev_turn)
	_at(52.4, func() -> void: _sfx("hx_whisper", 0.8, -4.0))
	_at(54.0, _ev_smash)
	# ---- 54.3 PRINTED AS RECEIVED / TRANSMISSION ENDED
	_at(54.3, _ev_printed)
	_at(54.4, func() -> void: _sfx("sp_type", 0.85, -4.0))
	_at(56.0, func() -> void: _sfx("sp_press", 1.2, -6.0))
	_at(56.8, _ev_static_out)
	_at(57.6, _ev_trans_end)
	_at(59.4, func() -> void: _anim(self, "_fx_bright", 1.0, 0.0, 0.5, 0))


# ------------------------------------------------------------------ small helpers
func _cc_show(text: String, dur: float) -> void:
	_cc_label.text = text
	_cc_label.reset_size()
	var sz := _cc_label.size
	_cc_label.position = Vector2(640 - sz.x * 0.5, 612 - sz.y * 0.5)
	_cc_box.position = _cc_label.position - Vector2(14, 4)
	_cc_box.size = sz + Vector2(28, 8)
	_cc.visible = true
	_cc_until = _ev_time + dur


func _set_pep(expr: String) -> void:
	_pep.texture = _tex("pepper_" + expr)
	_pep_far.texture = _tex("pepper_" + expr)


func _heartbeat(rate: float) -> void:
	_hb_rate = rate
	_hb_next = _ev_time


# ------------------------------------------------------------------ events
func _ev_standby() -> void:
	_show_set("")
	_standby.visible = true
	_put("_fx_static", 1.0)
	_put("_fx_desat", 0.55)
	_put("_fx_tear", 0.18)
	_sfx("hx_standby", 1.0, 0.0)


func _ev_subliminal() -> void:
	_sub_face.visible = true
	_put("_fx_static", 0.6)
	_sfx("hx_static_burst", 0.7, -8.0)


func _ev_standby_glitch() -> void:
	_anim(self, "_fx_vroll", 0.45, 0.0, 0.4, 2)
	_anim(self, "_fx_static", 0.4, 1.0, 0.3, 3)
	_glitch(0.3, 0.8)
	_sfx("hx_static_burst", 1.0, 0.0)


func _ev_black() -> void:
	_show_set("")
	_standby.visible = false
	_title.visible = false
	_hud.visible = false
	_put("_fx_static", 0.0)
	_impact = 0


func _ev_title() -> void:
	_title.visible = true
	_put("_fx_static", 0.0)
	_put("_fx_desat", 0.25)
	_put("_fx_tear", 0.04)
	_put("_fx_chroma", 2.5)
	_music(MUSIC_ID, 0.4)


func _ev_title_exec() -> void:
	_title_exec_t0 = _ev_time
	_sfx("hx_sting", 1.0, 0.0)
	_glitch(0.25, 0.5)


func _ev_title_name() -> void:
	_title_name_t0 = _ev_time
	_sfx("sp_type", 1.1, -8.0)


func _ev_title_act() -> void:
	_title_act_t0 = _ev_time


func _ev_title_out() -> void:
	_title.visible = false
	_put("_fx_tear", 0.05)
	_sfx("hx_static_burst", 1.2, -6.0)
	_anim(self, "_fx_static", 0.8, 0.0, 0.2, 2)


func _ev_news() -> void:
	_show_set("news")
	_hud.visible = true
	_put("_fx_desat", 0.86)
	_put("_fx_tracking", 0.35)
	_put("_fx_chroma", 2.2)
	_cam_push(Vector2(640, 380), 1.0, Vector2(640, 330), 1.32, 6.8)
	_sway = 2.0


func _ev_bulb(count: int) -> void:
	var pool: Array = _far_dummies if _news.visible else _fg_dummies
	for i in count:
		if pool.is_empty():
			return
		var d: Sprite2D = pool[_rng.randi() % pool.size()]
		var p := d.position + Vector2(d.scale.x * 70.0 * (1.0 if _rng.randf() < 0.5 else -1.0), -d.scale.y * 230.0)
		_flashes.append({"p": p, "t0": _t, "r": 70.0 * d.scale.x + 40.0, "set": "news" if _news.visible else "press"})
	_sfx("sp_flash", randf_range(0.9, 1.15), -6.0)


func _ev_press_close() -> void:
	_show_set("press")
	_set_pep("sad")
	_put("_plate_y", PLATE_UP)
	_cam_push(Vector2(640, 360), 1.08, Vector2(640, 300), 1.42, 3.4)
	_sway = 1.4
	_anim(self, "_lamp_swing", 0.4, 0.0, 4.0, 2)
	_heartbeat(0.8)


func _ev_cam_insert() -> void:
	_show_set("cam")
	_cam_push(Vector2(640, 380), 1.0, Vector2(640, 390), 1.12, 1.3)
	_sfx("hx_heartbeat", 1.0, -2.0)


func _ev_press_back() -> void:
	_show_set("press")
	_set_pep("shock")
	_cam_push(Vector2(640, 330), 1.5, Vector2(640, 310), 1.62, 1.6)
	_put("_pep_shake", 1.0)
	_heartbeat(0.6)


func _ev_pov(z0: float, z1: float) -> void:
	_show_set("pov")
	_pov_floor = false
	_cam_cut(C, 1.0)
	_anim(self, "_pov_z", z0, z1, 1.3, 1)
	_sway = 3.0
	_sfx("hx_heartbeat", 1.15, 0.0)


func _ev_booth() -> void:
	_show_set("booth")
	_heartbeat(0.0)
	_cam_push(Vector2(640, 330), 1.0, Vector2(640, 310), 1.12, 3.0)
	_anim(self, "_eye_open", 0.0, 1.0, 0.9, 2)
	_sfx("hx_sting", 0.6, -6.0)
	_sway = 1.0


func _ev_snap_jump() -> void:
	_snap_close.visible = true
	_anim(_snap_close, "scale", Vector2(1.9, 1.9), Vector2(1.6, 1.6), 0.25, 2)
	_glitch(0.4, 1.0)
	_kick(18.0)
	_sfx("hx_static_burst", 0.8, 0.0)
	_sfx("hx_sting", 1.2, 0.0)


func _ev_lever() -> void:
	_anim(self, "_lever", 0.0, 1.0, 0.35, 5)
	_at_late(0.3, func() -> void:
		_sfx("sp_press", 1.4, -2.0)
		_kick(10.0))
	_cc_show("[ THE PRESS STARTS ]", 1.4)


func _ev_press_wide() -> void:
	_show_set("press")
	_set_pep("shock")
	_put("_plate_y", PLATE_UP)
	_cam_push(Vector2(640, 380), 1.0, Vector2(640, 370), 1.05, 4.0)
	_sway = 1.8
	_heartbeat(0.42)


func _ev_stroke(to: float, i: int) -> void:
	_show_set("press")
	_cam_cut(Vector2(640, 340), 1.0)
	_anim(self, "_plate_y", _plate_y, to, 0.16, 3)
	_sfx("sp_press", 0.9 + i * 0.1, 0.0)
	_at_late(0.16, func() -> void:
		_kick(14.0 + i * 6.0)
		_flash(Color.WHITE, 0.55, 0.14)
		_put("_pep_shake", 1.6)
		_ev_bulb(3))
	if i == 1:
		_at_late(0.17, func() -> void: _impact = 1)
		_at_late(0.23, func() -> void: _impact = 2)
		_at_late(0.29, func() -> void: _impact = 0)


func _ev_face() -> void:
	_show_set("press")
	_set_pep("shock")
	_cam_push(Vector2(640, 330), 1.7, Vector2(640, 320), 1.95, 1.2)
	_put("_pep_shake", 2.0)
	_sfx("hx_heartbeat", 1.3, 0.0)


func _ev_pov_rush() -> void:
	_ev_pov(1.6, 1.9)
	_anim(self, "_pov_rush", 0.0, 1.0, 0.85, 6)
	_stamp_blink = 1.0


func _ev_kill() -> void:
	_kill_t0 = _ev_time
	_show_set("press")
	_cam_cut(Vector2(640, 380), 1.0)
	_sway = 0.0
	_heartbeat(0.0)
	_put("_plate_y", lerpf(PLATE_S2, BED_FOOT, 0.58))
	_music_id = ""
	if not _ff:
		Audio.stop_music(0.05)
	_sfx("sp_crush", 1.0, 2.0)
	_impact = 1
	_hitstop(0.12)
	_kick(34.0)


func _ev_kill_down() -> void:
	_put("_plate_y", BED_FOOT)
	_sfx("hx_splatter", 0.9, 0.0)
	_impact = 2
	_hitstop(0.08)
	_kick(30.0)
	_spawn_kill_blood()


func _ev_after_kill() -> void:
	_impact = 0
	_put("_fx_desat", 0.9)
	_put("_jet", 1.0)
	_anim(self, "_pool", 0.0, 1.0, 6.0, 2)
	_anim(self, "_soak", 0.0, 1.0, 2.5, 2)
	_cam_push(Vector2(640, 420), 1.02, Vector2(640, 470), 1.18, 3.0)
	_sway = 0.8
	_ev_bulb(4)


func _ev_pov_floor() -> void:
	_show_set("pov")
	_pov_floor = true
	_cam_push(Vector2(640, 380), 1.05, Vector2(640, 360), 1.12, 2.4)
	_sway = 0.5


func _ev_pages() -> void:
	_pov_floor = false
	_show_set("pages")
	_cam_push(Vector2(640, 360), 1.0, Vector2(640, 380), 1.08, 9.5)
	_sway = 1.4
	_put("_page_spawn", 0.0)


func _ev_page_close() -> void:
	_anim(self, "_page_close", 0.0, 1.0, 0.25, 4)
	_sfx("sp_paper", 0.8, 0.0)
	_kick(6.0)


func _ev_page_close_out() -> void:
	_anim(self, "_page_close", 1.0, 0.0, 0.3, 6)
	_sfx("sp_paper", 1.1, -4.0)


func _ev_news_end() -> void:
	_show_set("news")
	_turned = false
	_set_turned(false)
	_cam_push(Vector2(640, 380), 1.18, Vector2(640, 360), 1.26, 1.0)
	_sway = 1.0


func _ev_turn() -> void:
	_set_turned(true)
	_flash(Color.WHITE, 0.9, 0.3)
	for i in 4:
		_at_late(i * 0.05, func() -> void: _sfx("sp_flash", randf_range(0.8, 1.2), -2.0))
	_ev_bulb(8)
	_glitch(0.3, 0.7)
	_cam_push(Vector2(640, 380), 1.26, Vector2(640, 400), 1.5, 2.4)


func _set_turned(on: bool) -> void:
	_turned = on
	_news_bg.texture = _tex("sp_newsroom_turned" if on else "sp_newsroom")
	for d in _far_dummies:
		var s: Sprite2D = d
		s.texture = _tex("sp_dummy_front" if on else "sp_dummy_back")
		var lit := 0.95 if on else 0.55
		s.modulate = Color(lit, lit, lit) if s.scale.x < 0.9 else Color(lit * 0.6, lit * 0.6, lit * 0.6)


func _ev_smash() -> void:
	_show_set("")
	_hud.visible = false
	_cc.visible = false
	_sfx("hx_static_burst", 1.0, 0.0)
	_glitch(0.2, 1.0)


func _ev_printed() -> void:
	_printed_t0 = _ev_time
	_put("_fx_desat", 0.2)


func _ev_static_out() -> void:
	_anim(self, "_fx_static", 0.0, 1.0, 0.4, 3)
	_sfx("hx_static_burst", 1.2, -4.0)
	_at_late(0.75, func() -> void:
		_printed_t0 = -1.0
		_put("_fx_static", 0.0))


func _ev_trans_end() -> void:
	_put("_fx_static", 0.0)
	_put("_fx_tear", 0.03)
	_trans_t0 = _ev_time
	_sfx("hx_end_tone", 1.0, 0.0)


# ================================================================== blood
## The kill: a burst out from under the plate, sideways and up over the front row, and the stains it leaves.
func _spawn_kill_blood() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in 220:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector2(640 + side * r.randf_range(150, 262), BED_FOOT - r.randf_range(0, 30))
		var v := Vector2(side * r.randf_range(300, 1500), r.randf_range(-950, 150))
		_emit("press", p, v, r.randf_range(0.5, 1.4), r.randf_range(3.0, 11.0), BLOOD, 7, 1400.0, 0.4)
	for i in 70:
		var p2 := Vector2(640 + r.randf_range(-250, 250), BED_FOOT - 4)
		_emit("press", p2, Vector2(r.randf_range(-500, 500), r.randf_range(-1300, -500)), r.randf_range(0.7, 1.3), r.randf_range(4.0, 9.0), BLOOD, 7, 1500.0, 0.3)
	# stains: thrown out sideways and up from under the plate's two bottom corners, thick near them and thinning out;
	# a few heavy splashes on the plate's face just above its edge; the front row of dummies takes the rest
	_decals.clear()
	for i in 90:
		var side := -1.0 if i % 2 == 0 else 1.0
		var src := Vector2(640 + side * 262.0, BED_FOOT - 8.0)
		var ang := deg_to_rad(r.randf_range(-170.0, -98.0)) if side < 0.0 else deg_to_rad(r.randf_range(-82.0, -10.0))
		var dir := Vector2(cos(ang), sin(ang))
		var d := pow(r.randf(), 1.6) * 640.0 + 30.0
		_decals.append({"p": src + dir * d, "dir": dir, "r": lerpf(16.0, 5.0, d / 670.0) * r.randf_range(0.7, 1.3), "t": KILL_T + 0.06 + d / 2200.0,
			"seed": r.randi(), "sy": 1.0})
	for i in 14:
		var pos := Vector2(640 + r.randf_range(-240, 240), BED_FOOT - r.randf_range(14, 120))
		_decals.append({"p": pos, "r": r.randf_range(14, 38), "t": KILL_T + 0.06, "seed": r.randi(), "sy": r.randf_range(0.5, 0.9)})
	for i in 36:
		var fd: Sprite2D = _fg_dummies[i % _fg_dummies.size()]
		var pos2 := fd.position + Vector2(r.randf_range(-130, 130), r.randf_range(-400, -60))
		var dir2 := (pos2 - Vector2(640, BED_FOOT)).normalized()
		_decals.append({"p": pos2, "r": r.randf_range(8, 30), "t": KILL_T + 0.3 + r.randf() * 0.25, "seed": r.randi(), "sy": r.randf_range(0.7, 1.0),
			"fg": true, "dir": dir2 if i % 3 != 0 else Vector2.ZERO})


## A thrown drop: a round head where it landed, a tail pointing back the way it came, a few satellites beyond.
func _streak(ci: CanvasItem, c: Vector2, dir: Vector2, rad: float, seed: int, a: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var n := Vector2(-dir.y, dir.x)
	var ln := rad * r.randf_range(3.0, 7.5)
	ci.draw_colored_polygon(PackedVector2Array([c + n * rad * 0.95, c - dir * ln, c - n * rad * 0.95]), Color(BLOOD, a))
	ci.draw_circle(c, rad, Color(BLOOD_D, a))
	ci.draw_circle(c - dir * rad * 0.15, rad * 0.8, Color(BLOOD, a))
	for k in 3:
		ci.draw_circle(c + dir * rad * r.randf_range(1.6, 3.6) + n * rad * r.randf_range(-1.2, 1.2), rad * r.randf_range(0.12, 0.3), Color(BLOOD, a))


func _decal(ci: CanvasItem, dd: Dictionary, a: float = 1.0) -> void:
	var dir: Vector2 = dd.get("dir", Vector2.ZERO)
	if dir != Vector2.ZERO:
		_streak(ci, dd["p"], dir, float(dd["r"]), int(dd["seed"]), a)
	else:
		_blot(ci, dd["p"], float(dd["r"]), int(dd["seed"]), float(dd["sy"]), a)


## The plate's shadow falling across whatever is under it.
func _draw_plate_shadow(ci: Node2D) -> void:
	var y := _plate_y
	var x0 := 640.0 - PLATE_W * 0.5
	var x1 := 640.0 + PLATE_W * 0.5
	var dark := Color(0, 0, 0, 0.7)
	var clear := Color(0, 0, 0, 0.0)
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y + 150), Vector2(x0, y + 150)]),
		PackedColorArray([dark, dark, clear, clear]))


## A hard glint along the plate's crushing edge, so it reads against the dark press.
func _draw_plate_edge(ci: Node2D) -> void:
	if not _press.visible:
		return
	var y := _plate_y
	ci.draw_line(Vector2(640 - PLATE_W * 0.5 + 6, y - 32), Vector2(640 + PLATE_W * 0.5 - 6, y - 32), Color(0.5, 0.55, 0.6, 0.55), 3.0)
	ci.draw_line(Vector2(640 - PLATE_W * 0.5 + 10, y - 2), Vector2(640 + PLATE_W * 0.5 - 10, y - 2), Color(0.55, 0.6, 0.65, 0.5), 2.0)
	ci.draw_texture_rect(_soft, Rect2(Vector2(640 - 300, y - 300), Vector2(600, 240)), false, Color(1.0, 0.86, 0.62, 0.12 * _lamp))


func _blot(ci: CanvasItem, c: Vector2, rad: float, seed: int, sy: float, a: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var pts := PackedVector2Array()
	for k in 14:
		var ang := TAU * k / 14.0
		var rr := rad * r.randf_range(0.7, 1.25)
		pts.append(c + Vector2(cos(ang) * rr, sin(ang) * rr * sy))
	ci.draw_colored_polygon(pts, Color(BLOOD_D, a))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.78 + Vector2(-rad * 0.05, -rad * 0.06))
	ci.draw_colored_polygon(inner, Color(BLOOD, a))
	for k in 5:
		var ang2 := r.randf() * TAU
		var d := rad * r.randf_range(1.2, 2.1)
		ci.draw_circle(c + Vector2(cos(ang2) * d, sin(ang2) * d * sy), rad * r.randf_range(0.08, 0.2), Color(BLOOD, a))
	ci.draw_circle(c + Vector2(-rad * 0.3, -rad * 0.3 * sy), rad * 0.12, Color(BLOOD_H, 0.5 * a))


func _drip(ci: CanvasItem, x: float, y0: float, ln: float, w: float, a: float = 1.0) -> void:
	if ln < 0.5:
		return
	ci.draw_circle(Vector2(x, y0), w * 0.8, Color(BLOOD_D, a))
	ci.draw_rect(Rect2(x - w * 0.5, y0, w, ln), Color(BLOOD, a))
	ci.draw_circle(Vector2(x, y0 + ln), w * 0.72, Color(BLOOD, a))
	ci.draw_line(Vector2(x - w * 0.18, y0 + 1.0), Vector2(x - w * 0.18, y0 + ln * 0.92), Color(BLOOD_H, 0.6 * a), maxf(1.0, w * 0.22))


func _draw_blood_parts(ci: CanvasItem, space: String) -> void:
	for p in _parts.get(space, []):
		var d: Dictionary = p
		var pos: Vector2 = d["p"]
		var v: Vector2 = d["v"]
		var s: float = d["s"]
		var lk := float(d["life"]) / maxf(float(d["max"]), 0.001)
		var a := clampf(lk * 3.0, 0.0, 1.0)
		var tail := v * 0.025
		if tail.length() > s:
			ci.draw_line(pos - tail, pos, Color(BLOOD_D, a), s * 1.1)
		ci.draw_circle(pos, s, Color(BLOOD, a))


# ================================================================== simulation (also runs while fast-forwarding)
func _simulate(dt: float) -> void:
	_jet = maxf(0.0, _jet - dt * 1.6)
	_pep_shake = move_toward(_pep_shake, 0.35 if _t > 20.6 and _t < KILL_T else 0.0, dt * 1.2)
	if _jet > 0.05 and _t > KILL_T:
		for i in int(18.0 * _jet * dt * 60.0 / 4.0) + 1:
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			var p := Vector2(640 + side * _rng.randf_range(200, 258), BED_FOOT - _rng.randf_range(0, 12))
			_emit("press", p, Vector2(side * _rng.randf_range(200, 700) * _jet, _rng.randf_range(-700, -200) * _jet), 0.8, _rng.randf_range(2.5, 6.0), BLOOD, 7, 1400.0, 0.3)
	# the pages
	if _pages_set and _t > 41.0 and _t < 50.6:
		_page_spawn -= dt
		if _page_spawn <= 0.0:
			_page_spawn = 0.32
			_spawn_page()
	for pg in _pages:
		var d: Dictionary = pg
		var v: Vector2 = d["v"]
		v.y += 520.0 * dt
		v.x *= 1.0 - minf(1.0, 0.9 * dt)
		v.y = minf(v.y, 340.0)
		d["v"] = v
		d["p"] = (d["p"] as Vector2) + v * dt + Vector2(sin(_t * 2.0 + float(d["ph"])) * 50.0 * dt, 0)
		d["rot"] = float(d["rot"]) + float(d["spin"]) * dt
		d["age"] = float(d["age"]) + dt
	var keep: Array = []
	for pg in _pages:
		var d: Dictionary = pg
		if (d["p"] as Vector2).y < 1300.0:
			keep.append(d)
		else:
			(d["node"] as Node2D).queue_free()
	_pages = keep
	# flashbulbs fade
	var fk: Array = []
	for fl in _flashes:
		if _t - float((fl as Dictionary)["t0"]) < 0.5:
			fk.append(fl)
	_flashes = fk


func _spawn_page() -> void:
	_page_seq += 1
	var r := RandomNumberGenerator.new()
	r.seed = 500 + _page_seq
	var n := _node(_pages_set, Vector2.ZERO, 1.0)
	var sp := _sp(n, _tex("sp_paper"), Vector2.ZERO)
	sp.modulate = Color(0.95, 0.93, 0.88)
	var info := {"node": n, "seq": _page_seq, "p": Vector2(640 + r.randf_range(-60, 60), 250), "v": Vector2(r.randf_range(-520, 520), r.randf_range(-160, 40)),
		"rot": r.randf_range(-0.3, 0.3), "spin": r.randf_range(-2.4, 2.4), "ph": r.randf() * TAU, "age": 0.0, "sc": r.randf_range(0.55, 0.95),
		"seed": r.randi()}
	_painter(n, _draw_page.bind(info))
	_pages.append(info)
	if not _ff and _page_seq % 3 == 0:
		Audio.sfx("sp_paper", r.randf_range(0.9, 1.2), -12.0)


# ================================================================== per-frame visuals
func _update_scene(delta: float) -> void:
	_check_shot()
	_update_camera()
	_red_keep = 1.0
	_vhs_mat.set_shader_parameter("red_keep", _red_keep)
	if _cc.visible and _t > _cc_until:
		_cc.visible = false
	# heartbeat
	if _hb_rate > 0.0 and _t >= _hb_next and not _ff:
		_hb_next = _t + _hb_rate
		Audio.sfx("hx_heartbeat", 1.0 + (0.8 - _hb_rate) * 0.5, -3.0)
	# the plate and Pepper under it
	if _press.visible or _news.visible:
		var sq := clampf((BED_FOOT - _plate_y) / (BED_FOOT - PEP_TOP), 0.0, 1.0)
		var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _pep_shake * 2.0
		_pep.position = Vector2(640, BED_FOOT) + sh
		_pep.scale = Vector2(PEP_SC * (1.0 + (1.0 - sq) * 0.12), PEP_SC * sq)
		_pep.visible = sq > 0.015
		_plate.position = Vector2(640 - PLATE_W * 0.5, _plate_y - PLATE_H)
		_pep_far.scale = _pep.scale
		_pep_far.visible = _pep.visible
		_plate_far.position = Vector2(450 - PLATE_W * 0.5, (_plate_y - PRESS_POS.y) - PLATE_H)
		var lg := _press.get_node_or_null("lampglow") as Sprite2D
		if lg:
			lg.position = Vector2(640 + sin(_t * 1.6) * 60.0 * _lamp_swing, 40)
			lg.modulate.a = 0.28 * (0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 3.1))
		_pep_mat.set_shader_parameter("light_uv", Vector2(0.5 + sin(_t * 1.6) * 0.18 * _lamp_swing, -0.15))
	if _booth.visible:
		var eg := _booth.get_node("eyeglow") as Sprite2D
		var eye := _booth.get_node("eye") as Sprite2D
		eye.scale = Vector2(0.5, 0.5 * _eye_k) * (0.4 + 0.6 * _eye_open)
		eye.modulate.a = _eye_open
		eg.modulate = Color(1.0, 0.08, 0.05, 0.6 * _eye_open * (0.85 + 0.15 * sin(_t * 9.0)))
	for pg in _pages:
		var d: Dictionary = pg
		var n: Node2D = d["node"]
		n.position = d["p"]
		n.rotation = d["rot"]
		var sc: float = d["sc"]
		n.scale = Vector2(sc * cos(float(d["age"]) * 3.0 + float(d["ph"])), sc)
	for p in _cpainters:
		if is_instance_valid(p) and (p as CanvasItem).is_visible_in_tree():
			(p as CanvasItem).queue_redraw()


# ================================================================== painters
func _draw_press_backdrop(ci: Node2D) -> void:
	# the far newsroom behind the press, in shadow
	ci.draw_rect(Rect2(-600, -500, 2480, 1300), Color("0a0b0b"))
	for k in 14:
		var x := -200.0 + k * 130.0
		ci.draw_rect(Rect2(x, 120, 54, 520), Color(0.08, 0.09, 0.09))
	ci.draw_rect(Rect2(-600, 640, 2480, 600), Color("120e0b"))
	ci.draw_line(Vector2(-600, 640), Vector2(1880, 640), Color(0.02, 0.02, 0.02), 6.0)


func _draw_press_blood_under(ci: Node2D) -> void:
	# nothing shows on the bed behind her until the plate is down, and then the plate covers it
	pass


func _draw_press_blood_over(ci: Node2D) -> void:
	if _t < KILL_T:
		return
	var k := clampf((_t - KILL_T) / 0.4, 0.0, 1.0)
	# squeezed out from under the plate's face, both sides
	for side: float in [-1.0, 1.0]:
		var x0 := 640.0 + side * 262.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, BED_FOOT - 40), Vector2(x0 + side * 70.0 * k, BED_FOOT - 18), Vector2(x0 + side * 90.0 * k, BED_FOOT + 6),
			Vector2(x0 - side * 30.0, BED_FOOT + 6)]), BLOOD)
	# what was thrown over the plate's face, the columns and the wall behind
	for d in _decals:
		var dd: Dictionary = d
		if not dd.has("fg") and _t >= float(dd["t"]):
			_decal(ci, dd)
	# the pool on the press base and the floor, and drips down the front of the base
	if _pool > 0.0:
		var pr := 120.0 + 520.0 * _pool
		var pts := PackedVector2Array()
		var r := RandomNumberGenerator.new()
		r.seed = 4242
		for i in 22:
			var a := PI + PI * i / 21.0
			var rr := pr * r.randf_range(0.82, 1.1)
			pts.append(Vector2(640 + cos(a) * rr, BED_FOOT + 10 - sin(a) * rr * 0.08))
		pts.append(Vector2(640 + pr, BED_FOOT + 60.0 * _pool))
		pts.append(Vector2(640 - pr, BED_FOOT + 60.0 * _pool))
		ci.draw_colored_polygon(pts, Color(BLOOD_D, 0.95))
		for i in 12:
			var x := 640.0 + (i - 5.5) * 64.0 + r.randf_range(-20, 20)
			if absf(x - 640.0) > pr:
				continue
			var ln: float = r.randf_range(60, 180) * minf(1.0, _pool * 1.6)
			_drip(ci, x, BED_FOOT + 50.0, ln, r.randf_range(5, 11))
	# the paper in the tray, soaking through
	if _soak > 0.0:
		var r2 := RandomNumberGenerator.new()
		r2.seed = 11
		for i in 7:
			var c := Vector2(640 + (i - 3) * 62.0 + r2.randf_range(-14, 14), BED_FOOT + 2)
			_blot(ci, c, (10.0 + r2.randf() * 18.0) * _soak, r2.randi(), 0.35, 0.9)
	_draw_blood_parts(ci, "press")


func _draw_fg_blood(ci: Node2D) -> void:
	if _t < KILL_T:
		return
	for d in _decals:
		var dd: Dictionary = d
		if dd.has("fg") and _t >= float(dd["t"]):
			_decal(ci, dd)
			var r := RandomNumberGenerator.new()
			r.seed = int(dd["seed"])
			var ln := minf(1.0, (_t - float(dd["t"])) / 2.5) * r.randf_range(30, 130)
			_drip(ci, (dd["p"] as Vector2).x, (dd["p"] as Vector2).y, ln, float(dd["r"]) * 0.3)


func _draw_flashes(ci: Node2D) -> void:
	var setname := "news" if ci.get_parent() == _news else "press"
	for fl in _flashes:
		var d: Dictionary = fl
		if str(d["set"]) != setname:
			continue
		var k := (_t - float(d["t0"])) / 0.5
		var a := (1.0 - k) * (1.0 - k)
		var r: float = float(d["r"]) * (1.0 + k * 1.5)
		ci.draw_texture_rect(_soft, Rect2(d["p"] - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, a))
		ci.draw_circle(d["p"], r * 0.12 * (1.0 - k), Color(1, 1, 1, a))


## Hard impact frames: a white or red field with every solid thing on it in black.
func _draw_impact(ci: Node2D) -> void:
	if _impact <= 0:
		return
	var field := Color(0.95, 0.95, 0.92) if _impact == 1 else (Color(0.55, 0.0, 0.03) if _impact == 2 else Color(0, 0, 0))
	ci.draw_rect(Rect2(-900, -900, 3080, 2520), field)
	if _impact == 3:
		return
	var ink := Color(0, 0, 0, 1) if _impact == 1 else Color(0.06, 0.0, 0.0, 1)
	# the bed's outline and the guide rails, thin, so the frame still reads as the press
	ci.draw_rect(Rect2(PRESS_POS + Vector2(230, 200), Vector2(440, 500)), Color(ink, 0.5), false, 8.0)
	ci.draw_rect(Rect2(PRESS_POS + Vector2(196, 150), Vector2(30, 560)), ink)
	ci.draw_rect(Rect2(PRESS_POS + Vector2(674, 150), Vector2(30, 560)), ink)
	ci.draw_rect(Rect2(PRESS_POS + Vector2(30, 700), Vector2(840, 100)), ink)
	if _pep.visible:
		var sz := Vector2(480, 600) * _pep.scale
		ci.draw_texture_rect(_pep.texture, Rect2(_pep.position + Vector2(-sz.x * 0.5, -sz.y), sz), false, ink)
	ci.draw_texture_rect(_tex("sp_plate"), Rect2(_plate.position, Vector2(PLATE_W, PLATE_H)), false, ink)
	for d in _fg_dummies:
		var s: Sprite2D = d
		var dsz := Vector2(220, 340) * s.scale
		ci.draw_texture_rect(s.texture, Rect2(s.position + Vector2(-dsz.x * 0.5, -dsz.y), dsz), false, ink)
	if _t >= KILL_T:
		# the spray, frozen, in the field's opposite colour
		for p in _parts.get("press", []):
			var pd: Dictionary = p
			ci.draw_circle(pd["p"], float(pd["s"]) * 1.3, Color(0.5, 0.0, 0.02) if _impact == 1 else Color(0.0, 0.0, 0.0))


func _draw_booth(ci: Node2D) -> void:
	# the ON AIR box lit red, the lever being pulled
	var on := fmod(_t, 0.8) < 0.55
	ci.draw_rect(Rect2(569, 22, 142, 38), Color(0.85, 0.05, 0.06) if on else Color(0.25, 0.0, 0.02))
	ci.draw_string(_mono, Vector2(588, 52), "ON AIR", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.9, 0.85) if on else Color(0.4, 0.2, 0.2))
	var base := Vector2(640, 626)
	var ang := lerpf(-0.9, 0.9, _lever)
	var tip := base + Vector2(sin(ang), -cos(ang)) * 150.0
	ci.draw_line(base, tip, Color(0.12, 0.13, 0.14), 16.0)
	ci.draw_line(base, tip, Color(0.4, 0.43, 0.45), 4.0)
	ci.draw_circle(tip, 22.0, Color(0.5, 0.02, 0.04))
	ci.draw_circle(tip + Vector2(-6, -6), 6.0, Color(1, 0.6, 0.6, 0.5))


## Through her viewfinder: the plate's face from below, the type reading her name backwards, the date stamp.
## After the kill (_pov_floor): the camera on the floor, tilted, the lens cracked and red.
func _draw_pov(ci: Node2D) -> void:
	if _pov_floor:
		_draw_pov_floor(ci)
		return
	var z := _pov_z * (1.0 + _pov_rush * 2.6)
	var tex := _tex("sp_plate_under")
	if tex:
		var sz := Vector2(1280, 720) * z
		ci.draw_texture_rect(tex, Rect2(C - sz * 0.5 + Vector2(0, -30) * z, sz), false, Color(0.7, 0.7, 0.7))
	# the type: her own name, mirrored, row on row
	var df := Style.display_font()
	var fs := int(46 * z)
	var rows := ["PEPPER  QUILL", "ACE  JOURNALIST", "PEPPER  QUILL", "STOP  PRESS", "PEPPER  QUILL"]
	for i in rows.size():
		var y := 360.0 + (i - 2) * 66.0 * z
		var txt: String = rows[i]
		var w := df.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_set_transform(Vector2(640, y), 0.0, Vector2(-1, 1))
		ci.draw_string(df, Vector2(-w * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.62, 0.66, 0.68, 0.9))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_vf(ci: Control) -> void:
	if _pov.visible:
		if _pov_floor:
			# the lens itself: a red smear across one side, and cracks from where it hit the floor
			_blot(ci, Vector2(1040, 150), 150.0, 31, 0.75, 0.88)
			_blot(ci, Vector2(1160, 330), 70.0, 32, 0.9, 0.85)
			for i in 5:
				_drip(ci, 960.0 + i * 46.0, 190.0, 80.0 + i * 30.0, 9.0, 0.85)
		_draw_viewfinder(ci, _pov_floor)


func _draw_viewfinder(ci: CanvasItem, cracked: bool) -> void:
	var w := Color(0.95, 0.95, 0.9, 0.85)
	for corner in [[Vector2(150, 110), Vector2(1, 1)], [Vector2(1130, 110), Vector2(-1, 1)], [Vector2(150, 610), Vector2(1, -1)], [Vector2(1130, 610), Vector2(-1, -1)]]:
		var p0: Vector2 = corner[0]
		var dd: Vector2 = corner[1]
		ci.draw_line(p0, p0 + Vector2(60 * dd.x, 0), w, 3.0)
		ci.draw_line(p0, p0 + Vector2(0, 60 * dd.y), w, 3.0)
	ci.draw_arc(C, 70.0, 0.0, TAU, 48, Color(w, 0.5), 2.0)
	ci.draw_line(C - Vector2(14, 0), C + Vector2(14, 0), w, 2.0)
	ci.draw_line(C - Vector2(0, 14), C + Vector2(0, 14), w, 2.0)
	# the lit date-back in the corner: it still keeps time
	var on := not (_stamp_blink > 0.0 and fmod(_t, 0.3) < 0.12)
	if on:
		var stamp := "11 05"
		var o := Color(1.0, 0.55, 0.12)
		ci.draw_string(_mono, Vector2(182, 590), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(o, 0.35))
		ci.draw_string(_mono, Vector2(180, 588), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, o)
	if cracked:
		var r := RandomNumberGenerator.new()
		r.seed = 808
		var hub := Vector2(400, 250)
		for k in 14:
			var a := TAU * k / 14.0 + r.randf_range(-0.2, 0.2)
			var p := hub
			for s in 3:
				var q := p + Vector2(cos(a), sin(a)) * r.randf_range(26, 80)
				ci.draw_line(p, q, Color(0.92, 0.96, 1.0, 0.6), 2.0)
				p = q
				a += r.randf_range(-0.4, 0.4)
		for ring in [22.0, 54.0]:
			ci.draw_arc(hub, ring, 0.0, TAU, 24, Color(0.92, 0.96, 1.0, 0.4), 1.5)


func _draw_pov_floor(ci: Node2D) -> void:
	var tex := _tex("sp_press")
	if tex:
		ci.draw_texture_rect(tex, Rect2(Vector2(100, -560), Vector2(900, 800) * 1.2), false, Color(0.5, 0.5, 0.5))
	ci.draw_rect(Rect2(-600, 400, 2600, 900), Color("140f0c"))
	for k in 9:
		ci.draw_line(Vector2(-600, 410 + k * k * 9.0), Vector2(2000, 410 + k * k * 9.0), Color(0.03, 0.02, 0.02), 2.0)
	var k2 := clampf((_t - 38.6) / 2.4, 0.0, 1.0)
	var r := RandomNumberGenerator.new()
	r.seed = 5150
	# drips running down the base, the pool spreading off it and toward the lens
	for i in 10:
		var x := 180.0 + i * 82.0 + r.randf_range(-20, 20)
		_drip(ci, x, 300.0 + r.randf_range(-30, 20), r.randf_range(60, 120) * minf(1.0, 0.4 + k2), r.randf_range(6, 12))
	var pts := PackedVector2Array()
	for i in 20:
		var a := PI * i / 19.0
		var rr := (250.0 + 520.0 * k2) * r.randf_range(0.86, 1.12)
		pts.append(Vector2(600 - cos(a) * rr * 1.5, 404 + sin(a) * rr * 0.55))
	ci.draw_colored_polygon(pts, Color(BLOOD_D, 0.97))
	ci.draw_line(Vector2(600 - 500, 404), Vector2(600 + 500, 404), Color(BLOOD, 0.9), 6.0)


func _draw_rollers(ci: Node2D) -> void:
	# three huge rollers turning across the top, ink-dark, streaked red
	for i in 3:
		var y := 60.0 + i * 70.0
		ci.draw_rect(Rect2(-200, y - 30, 1680, 60), Color(0.12, 0.12, 0.13))
		var ph := fmod(_t * (220.0 + i * 40.0), 60.0)
		for k in 30:
			var x := -200.0 + k * 60.0 + ph
			ci.draw_line(Vector2(x, y - 28), Vector2(x - 20, y + 28), Color(0.05, 0.05, 0.05), 6.0)
		ci.draw_line(Vector2(-200, y - 22), Vector2(1480, y - 22), Color(0.4, 0.42, 0.44, 0.5), 3.0)
		if _t > 43.0:
			ci.draw_rect(Rect2(380 + i * 40, y - 30, 160 + i * 30, 60), Color(BLOOD, 0.75))
	ci.draw_rect(Rect2(-200, 260, 1680, 20), Color(0.03, 0.03, 0.03))


## One page held right up to the lens: her name, soaked through.
func _draw_close_page(ci: Node2D) -> void:
	if _page_close > 0.01:
		var pc := _page_close
		var size := Vector2(300, 400) * lerpf(0.6, 2.05, pc)
		var center := C + Vector2(0, lerpf(240.0, 30.0, pc))
		var fake := {"seq": 5, "seed": 707, "age": 3.0, "close": true}
		ci.draw_set_transform(center, lerpf(0.4, -0.04, pc), size / Vector2(300, 400))
		ci.draw_texture_rect(_tex("sp_paper"), Rect2(Vector2(-150, -200), Vector2(300, 400)), false, Color(0.95, 0.93, 0.88))
		_page_words(ci, fake)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_page(ci: Node2D, info: Dictionary) -> void:
	_page_words(ci, info)


## The masthead and the headline (her name), and the red soaking through. Page-local, centred, 300x400.
func _page_words(ci: CanvasItem, info: Dictionary) -> void:
	var df := Style.display_font()
	ci.draw_string(df, Vector2(-136, -158), "THE DAILY PUDDLE", HORIZONTAL_ALIGNMENT_CENTER, 272, 24, Color(0.92, 0.9, 0.85))
	var heads := ["PEPPER QUILL", "PEPPER QUILL", "STOP PRESS", "PEPPER QUILL", "FINAL EDITION"]
	var h: String = heads[int(info["seq"]) % heads.size()]
	ci.draw_string(df, Vector2(-140, -78), h, HORIZONTAL_ALIGNMENT_CENTER, 280, _fit(h, 40, 18, 268.0), Color(0.08, 0.07, 0.06))
	ci.draw_string(_mono, Vector2(-138, -56), "ACE JOURNALIST", HORIZONTAL_ALIGNMENT_CENTER, 276, 14, Color(0.15, 0.14, 0.12))
	var r := RandomNumberGenerator.new()
	r.seed = int(info["seed"])
	var soak := clampf(float(info["age"]) / 0.8, 0.0, 1.0)
	var n := 3 + r.randi() % 4
	for i in n:
		var c := Vector2(r.randf_range(-120, 120), r.randf_range(-150, 170))
		_blot(ci, c, r.randf_range(22, 70) * (0.4 + 0.6 * soak), r.randi(), r.randf_range(0.7, 1.1), 0.82)
	if bool(info.get("close", false)):
		for i in 4:
			_drip(ci, r.randf_range(-130, 130), r.randf_range(-100, 120), r.randf_range(40, 120), r.randf_range(5, 9), 0.9)


# ------------------------------------------------------------------ screen-space overlays
func _draw_title(ci: Control) -> void:
	var df := Style.display_font()
	var te := _t - _title_exec_t0
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
			var pos := Vector2(640 - w * 0.5, 262)
			var j := Vector2(randf_range(-1.5, 1.5), randf_range(-1, 1))
			ci.draw_string_outline(df, pos + j, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 26, Color(0.4, 0.0, 0.03, 0.35))
			ci.draw_string(df, pos + j + Vector2(5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.3, 0.9, 0.85, 0.18))
			ci.draw_string(df, pos + j, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.68, 0.02, 0.07))
			ci.draw_line(Vector2(640 - w * 0.5, 288), Vector2(640 + w * 0.5, 288), Color(0.5, 0.0, 0.04, 0.9), 3.0)
	var tn := _t - _title_name_t0
	if tn >= 0.0:
		var full := "PEPPER QUILL  —  ACE JOURNALIST"
		var cnt := mini(full.length(), int(tn / 0.045) + 1)
		var shown := full.substr(0, cnt)
		var w2 := _mono.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var p2 := Vector2(640 - w2 * 0.5, 356)
		ci.draw_string(_mono, p2 + Vector2(2, 0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.8, 0.1, 0.1, 0.35))
		ci.draw_string(_mono, p2, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, AQUA_TXT)
		if cnt < full.length() or fmod(_t, 0.8) < 0.45:
			var cw := _mono.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			ci.draw_rect(Rect2(p2 + Vector2(cw + 4, -24), Vector2(14, 26)), AQUA_TXT)
	# STOP PRESS: each letter struck in like a slug of type, the red ink a little off register
	var ta := _t - _title_act_t0
	if ta >= 0.0:
		var txt3 := "STOP PRESS"
		var sz3 := 92
		var w3 := df.get_string_size(txt3, HORIZONTAL_ALIGNMENT_LEFT, -1, sz3).x
		var x0 := 640 - w3 * 0.5
		var r := RandomNumberGenerator.new()
		r.seed = 66
		for i in txt3.length():
			var lt := ta - i * 0.13
			var jy := r.randf_range(-6, 6)
			var rot := r.randf_range(-0.05, 0.05)
			if lt < 0.0:
				continue
			var k := clampf(lt / 0.08, 0.0, 1.0)
			var x := x0 + df.get_string_size(txt3.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, sz3).x
			var sc := lerpf(1.8, 1.0, k)
			ci.draw_set_transform(Vector2(x, 470 + jy), rot, Vector2(sc, sc))
			ci.draw_string(df, Vector2(4, 3), txt3[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz3, Color(0.65, 0.0, 0.05, 0.75 * k))
			ci.draw_string(df, Vector2.ZERO, txt3[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz3, Color(BONE_TXT, k))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_end(ci: Control) -> void:
	var df := Style.display_font()
	if _printed_t0 > 0.0:
		var t := _t - _printed_t0
		var full := "PRINTED AS RECEIVED"
		var cnt := mini(full.length(), int(t / 0.075) + 1)
		var shown := full.substr(0, cnt)
		var sz := 74
		var w := df.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var p := Vector2(640 - w * 0.5, 392)
		var j := Vector2(randf_range(-1.2, 1.2), randf_range(-1, 1))
		ci.draw_string(df, p + j + Vector2(4, 0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.2, 0.8, 0.75, 0.14))
		ci.draw_string_outline(df, p + j, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6, Color(BLOOD_D, 1.0))
		ci.draw_string(df, p + j, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, BLOOD_H)
		if cnt >= full.length():
			var dt := t - full.length() * 0.075
			var r := RandomNumberGenerator.new()
			r.seed = 19
			for i in 9:
				var x := p.x + 20.0 + r.randf() * (w - 40.0)
				_drip(ci, x, p.y - 6.0, minf(1.0, dt / 1.2) * r.randf_range(20, 110), r.randf_range(4, 8))
	if _trans_t0 > 0.0:
		var t2 := _t - _trans_t0
		var txt2 := "TRANSMISSION ENDED"
		var w2 := _mono.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		var p2 := Vector2(640 - w2 * 0.5, 372)
		var a2 := clampf(t2 / 0.15, 0.0, 1.0)
		ci.draw_string(_mono, p2, txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.92, 0.92, 0.92, a2))
		if fmod(t2, 0.9) < 0.5:
			ci.draw_rect(Rect2(p2 + Vector2(w2 + 8, -30), Vector2(20, 34)), Color(0.92, 0.92, 0.92, a2))


func _draw_hud(ci: Control) -> void:
	var white := Color(0.93, 0.93, 0.93, 0.92)
	var shadow := Color(0, 0, 0, 0.7)
	var frames := int(_t * 30.0)
	var tc := "%02d:%02d:%02d:%02d" % [0, floori(frames / 1800.0), floori(frames / 30.0) % 60, frames % 30]
	# the camcorder's clock is stuck
	var items := [["REC", Vector2(78, 70), 30], ["SP", Vector2(1168, 70), 30], [tc, Vector2(56, 672), 28],
		["NOV. 10 1987", Vector2(1000, 640), 26], ["PM 11:05", Vector2(1064, 606), 26]]
	for it in items:
		var s := str(it[0])
		var p: Vector2 = it[1]
		var fs: int = it[2]
		ci.draw_string(_mono, p + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, shadow)
		ci.draw_string(_mono, p + Vector2(-1.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.2, 0.2, 0.25))
		ci.draw_string(_mono, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, white)
	if fmod(_t, 1.0) < 0.6:
		ci.draw_circle(Vector2(58, 60), 10, Color(0.85, 0.05, 0.08))
	var c := Color(0.9, 0.9, 0.9, 0.35)
	for corner in [[Vector2(30, 30), Vector2(1, 1)], [Vector2(1250, 30), Vector2(-1, 1)], [Vector2(30, 690), Vector2(1, -1)], [Vector2(1250, 690), Vector2(-1, -1)]]:
		var p0: Vector2 = corner[0]
		var dd: Vector2 = corner[1]
		ci.draw_line(p0, p0 + Vector2(36 * dd.x, 0), c, 2.0)
		ci.draw_line(p0, p0 + Vector2(0, 36 * dd.y), c, 2.0)
