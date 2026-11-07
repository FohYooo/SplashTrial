extends Control
## SPLASH TRIAL courtroom stage: a pseudo-3D rotating camera around the Trial Pool.
##
##   const TrialStage := preload("res://scripts/ui/trial_stage.gd")
##   var stage := TrialStage.new()
##   add_child(stage)                 # BEHIND the ScriptPlayer
##   stage.bind(player)               # player.stage_mode = true; listens to the stage hooks
##
## The chamber is a tiny ray-cast room drawn by ONE canvas shader (wooden deck, glowing pool with
## caustics, cylindrical wall panorama art/props/stage_pano.svg, dark ceiling with lamps). On top of
## it, camera-facing billboards are projected with the same camera: 15 podiums on a ring (Cast.ORDER,
## mochi = 0, every 24 deg) with their capybaras, Coco's memorial frame, Warden Snapjaw's throne
## island, and steam puffs. A "shot" is a set of camera parameters; the camera eases between shots
## (swing around the ring, then dolly in) and adds idle drift, punch-ins and shakes.

const Assets := preload("res://scripts/core/assets.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Style := preload("res://scripts/ui/style.gd")

const CENTER := Vector2(640, 360)
const STEP := TAU / 15.0
const RING_R := 1450.0
const POOL_R := 1000.0
const WALL_R := 2750.0
const WALL_H := WALL_R * TAU * 420.0 / 3000.0   # keeps the panorama strip's aspect
const THRONE_POS := Vector3(0, 0, -560)
const ISLAND_R := 300.0
const NEAR := 60.0

# billboard geometry (world units; svg px == world units unless scaled)
const POD_W := 330.0
const POD_H := 240.0
const CHAR_SCALE := 0.9
const CUT_PX := 470.0                       # portrait rows drawn above the podium lip
const CHAR_CUT := 190.0                     # world y of that cut (hidden behind the lip at 204)
const CHAR_TOP := CHAR_CUT + CUT_PX * CHAR_SCALE
const THR_SCALE := 1.2
const THR_W := 720.0 * THR_SCALE
const THR_H := 960.0 * THR_SCALE
const SNAP_SCALE := 0.85
const SNAP_TOP := (960.0 - 230.0) * THR_SCALE   # Snapjaw portrait top on the throne (world y)
const SNAP_CUT_PX := 600.0

const U_THRONE := 15
const N_STEAM := 9
const N_UNITS := 16 + N_STEAM
const N_STREAKS := 22

# camera parameters
const P_ANG := 0     # azimuth of the camera around the ring centre
const P_DIST := 1    # horizontal distance of the camera from the centre
const P_H := 2       # camera height
const P_LR := 3      # look-at point: radius along the camera azimuth
const P_LY := 4      # look-at point: height
const P_SIDE := 5    # camera lateral offset (tangent)
const P_TSIDE := 6   # look-at lateral offset
const P_F := 7       # focal length (px)
const P_ROLL := 8    # dutch angle (rad)
const P_LIGHT := 9   # global light level
const P_N := 10

enum { MODE_WIDE, MODE_MEDIUM, MODE_CLOSE, MODE_OTS, MODE_THRONE, MODE_ORBIT }
enum { EASE_SMOOTH, EASE_SWING, EASE_SNAP }

const ENV_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D pano : source_color, repeat_enable, filter_linear_mipmap;
uniform vec2 rect_origin = vec2(0.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 screen_center = vec2(640.0, 360.0);
uniform vec3 cam_pos = vec3(0.0, 1200.0, 2400.0);
uniform vec3 cam_right = vec3(1.0, 0.0, 0.0);
uniform vec3 cam_up = vec3(0.0, 1.0, 0.0);
uniform vec3 cam_fwd = vec3(0.0, 0.0, -1.0);
uniform float focal = 1000.0;
uniform float pool_r = 840.0;
uniform float ring_r = 1200.0;
uniform float wall_r = 2300.0;
uniform float wall_h = 2023.0;
uniform vec3 island = vec3(0.0, -440.0, 250.0);
uniform vec4 spot = vec4(0.0, 1200.0, 360.0, 0.0);
uniform vec3 spot_color = vec3(1.0, 0.92, 0.78);
uniform float light = 1.0;
uniform float time_s = 0.0;
uniform vec4 ripple = vec4(0.0, 0.0, -100.0, 0.0);

float caustic(vec2 p, float t) {
	float v = sin(p.x + sin(p.y * 1.3 + t)) + sin(p.y * 1.1 + sin(p.x * 0.9 - t * 1.3));
	v += 0.6 * sin((p.x + p.y) * 0.7 + t * 0.6);
	return pow(clamp(1.0 - abs(v) * 0.4, 0.0, 1.0), 6.0);
}

void fragment() {
	vec2 sp = rect_origin + UV * rect_size - screen_center;
	vec3 dir = normalize(cam_right * sp.x - cam_up * sp.y + cam_fwd * focal);
	vec3 o = cam_pos;
	// far side of the wall cylinder (the near wall is cut away, dollhouse style)
	float a = dir.x * dir.x + dir.z * dir.z;
	float b = 2.0 * (o.x * dir.x + o.z * dir.z);
	float c = o.x * o.x + o.z * o.z - wall_r * wall_r;
	float disc = b * b - 4.0 * a * c;
	float tw = 1e9;
	if (disc > 0.0 && a > 1e-6) {
		tw = (-b + sqrt(disc)) / (2.0 * a);
		if (tw < 0.0) tw = 1e9;
	}
	float tf = dir.y < -1e-5 ? -o.y / dir.y : 1e9;
	vec3 col = vec3(0.0);
	if (tf < tw) {
		vec2 q = (o + dir * tf).xz;
		float r = length(q);
		if (r < pool_r) {
			float e = r / pool_r;
			col = mix(vec3(0.10, 0.62, 0.62), vec3(0.015, 0.11, 0.16), smoothstep(0.05, 1.0, e));
			float fade = clamp(1.0 - length(fwidth(q)) * 0.035, 0.0, 1.0);
			float cs = caustic(q * 0.011, time_s * 0.8) * 0.6 + caustic(q * 0.019 + 3.0, time_s * 1.25) * 0.4;
			col += vec3(0.45, 1.0, 0.92) * cs * (0.22 + 0.45 * (1.0 - e)) * fade;
			// expanding splash rings (speaker reactions, the Warden's entrance)
			float age = time_s - ripple.z;
			float rd = length(q - ripple.xy);
			float rw = exp(-pow((rd - age * 950.0) / 55.0, 2.0)) + 0.6 * exp(-pow((rd - age * 600.0) / 40.0, 2.0));
			col += vec3(0.65, 1.0, 0.95) * rw * ripple.w * exp(-age * 1.4) * 0.55;
			// ring of light around the rim, under the water
			col += vec3(0.25, 0.9, 0.85) * smoothstep(0.80, 1.0, e) * 0.28;
			// rock island shadow + foam ring
			float di = length(q - island.xy);
			col = mix(col, vec3(0.01, 0.04, 0.06), smoothstep(island.z * 1.4, island.z * 0.95, di));
			float foam = smoothstep(island.z * 1.55, island.z * 1.3, di) * smoothstep(island.z * 1.0, island.z * 1.3, di);
			col += vec3(0.6, 1.0, 0.95) * foam * 0.3 * (0.6 + 0.4 * sin(atan(q.x - island.x, q.y - island.y) * 9.0 + time_s * 1.5));
		} else if (r < wall_r) {
			float ang = atan(q.x, q.y);
			float pa = ang * 72.0 / TAU;
			float rr = (r - pool_r) / 170.0;
			float fw = fwidth(pa) + fwidth(rr);
			float detail = 1.0 - smoothstep(0.25, 0.7, fw);
			float fp = fract(pa);
			float seam = smoothstep(0.0, 0.07, fp) * smoothstep(1.0, 0.93, fp);
			float ring = smoothstep(0.0, 0.05, fract(rr));
			vec3 wood = vec3(0.19, 0.11, 0.07) * (0.9 + 0.1 * sin(pa * 2.1 + floor(rr) * 3.7));
			wood *= mix(1.0, mix(0.5, 1.0, seam) * mix(0.62, 1.0, ring), detail);
			col = wood;
			// light spilling from the pool + a dark outer ring
			col += vec3(0.03, 0.2, 0.21) * exp(-(r - pool_r) / 380.0);
			col *= 1.0 - 0.55 * smoothstep(ring_r + 150.0, wall_r, r);
			// gold rim + bright inner lip
			col = mix(col, vec3(0.62, 0.43, 0.15), smoothstep(pool_r + 46.0, pool_r + 38.0, r));
			col += vec3(1.0, 0.82, 0.42) * smoothstep(pool_r + 12.0, pool_r + 2.0, r) * 0.5;
			// lamps set in the deck around the pool
			float la = (fract(ang * 30.0 / TAU) - 0.5) * TAU / 30.0 * r;
			float ld = length(vec2(la, r - (pool_r + 84.0)));
			col += vec3(1.0, 0.86, 0.55) * (smoothstep(30.0, 4.0, ld) * 0.8 + smoothstep(90.0, 10.0, ld) * 0.12);
			// aqua neon line along the wall foot
			col += vec3(0.2, 0.9, 0.85) * smoothstep(wall_r - 60.0, wall_r - 4.0, r) * 0.35;
		} else {
			col = vec3(0.01, 0.006, 0.02);
		}
		float ds = length(q - spot.xy);
		col += spot_color * spot.w * (smoothstep(spot.z, spot.z * 0.5, ds) * 0.32 + smoothstep(spot.z * 1.8, spot.z, ds) * 0.06);
		col *= exp(-tf * 0.00011);
	} else if (tw < 1e8) {
		vec3 h = o + dir * tw;
		if (h.y < wall_h) {
			vec2 uv = vec2(-atan(h.x, h.z) / TAU, 1.0 - h.y / wall_h);
			vec2 dx = dFdx(uv);
			vec2 dy = dFdy(uv);
			if (abs(dx.x) > 0.5) dx.x = 0.0;
			if (abs(dy.x) > 0.5) dy.x = 0.0;
			col = textureGrad(pano, uv, dx, dy).rgb;
			// faint caustic shimmer reflected from the pool on the lower wall
			float cw = caustic(vec2(uv.x * 260.0, h.y * 0.012), time_s * 0.7);
			col += vec3(0.25, 0.85, 0.8) * cw * 0.12 * smoothstep(0.35, 1.0, uv.y);
			col *= exp(-tw * 0.00008);
		} else {
			// ceiling: dark dome with ribs, a lamp above every podium and a cold oculus
			float ch = wall_h + 520.0;
			float tc = dir.y > 1e-4 ? (ch - o.y) / dir.y : 1e9;
			vec2 qc = (o + dir * min(tc, 1e5)).xz;
			float rc = length(qc);
			float ang = atan(qc.x, qc.y);
			col = vec3(0.016, 0.01, 0.035) + vec3(0.04, 0.02, 0.08) * smoothstep(wall_r, 0.0, rc);
			float rib = abs(fract(ang * 24.0 / TAU) - 0.5);
			col += vec3(0.05, 0.035, 0.1) * smoothstep(0.03, 0.0, rib) * smoothstep(wall_r, wall_r * 0.3, rc);
			col += vec3(0.25, 0.9, 0.95) * (smoothstep(420.0, 0.0, rc) * 0.22 + smoothstep(140.0, 100.0, rc) * 0.25);
			float la = (fract(ang * 15.0 / TAU) - 0.5) * TAU / 15.0 * rc;
			float ld = length(vec2(la, rc - ring_r));
			col += vec3(1.0, 0.95, 0.8) * (smoothstep(40.0, 8.0, ld) * 0.9 + smoothstep(140.0, 20.0, ld) * 0.12);
			col *= exp(-tc * 0.00005);
		}
	}
	COLOR = vec4(col * light, 1.0);
}
"""

const SIL_SHADER := """
shader_type canvas_item;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	COLOR = vec4(tint.rgb, tint.a * texture(TEXTURE, UV).a);
}
"""

const VIG_SHADER := """
shader_type canvas_item;
uniform float strength = 0.8;
uniform vec4 tint : source_color = vec4(0.03, 0.0, 0.07, 1.0);
uniform vec2 focus = vec2(0.5, 0.42);
void fragment() {
	vec2 d = (UV - focus) * vec2(1.15, 1.0);
	float v = smoothstep(0.28, 0.9, length(d));
	float bars = smoothstep(0.06, 0.0, UV.y) * 0.5;
	COLOR = vec4(tint.rgb, clamp(v * strength + bars, 0.0, 0.96));
}
"""

var _player: Control = null
var _game: Node = null

# nodes
var _root: Node2D
var _world: Node2D
var _env: ColorRect
var _env_mat: ShaderMaterial
var _beams: Node2D
var _rim: Node2D
var _actors: Node2D
var _fx: Node2D
var _bg_overlay: ColorRect
var _bg_tex: TextureRect
var _vig: ColorRect
var _vig_mat: ShaderMaterial
var _flash: ColorRect

# textures
var _pod_tex: Texture2D
var _thr_back: Texture2D
var _thr_front: Texture2D
var _memorial_tex: Texture2D
var _mochi_back: Texture2D
var _steam_tex: Texture2D
var _por := {}            # char id -> current portrait texture
var _expr := {}           # char id -> current expression

# camera
var _from := PackedFloat32Array()
var _to := PackedFloat32Array()
var _cur := PackedFloat32Array()
var _tt := 1.0
var _dur := 0.0
var _ease := EASE_SMOOTH
var _bump := 0.0
var _mode := MODE_WIDE
var _who := ""
var _focus := -1          # unit index in the spotlight (-1 none)
var _orbit_w := 0.0
var _orbit_off := 0.0
var _hold := 0.0
var _reframe := 0
var _cam_pos := Vector3.ZERO
var _cam_fwd := Vector3.FORWARD
var _cam_right := Vector3.RIGHT
var _cam_up := Vector3.UP
var _focal := 1000.0
var _ang_prev := 0.0
var _ang_vel := 0.0
var _time := 0.0

# fx state
var _punch := 0.0
var _shake := 0.0
var _pop := 0.0
var _bounce := 0.0
var _rim_flash := 0.0
var _rim_col := Color(1, 1, 1)
var _rim_a := 0.0
var _flash_a := 0.0
var _pending_fx := ""
var _others_dim := 0.85
var _ots_k := 0.0
var _spot_xz := Vector2.ZERO
var _spot_i := 0.0
var _spot_col := Color(1.0, 0.92, 0.78)
var _light_mul := 1.0
var _slash := 0.0         # 1 -> 0: diagonal light slash behind a speaker who just took the floor
var _slash_col := Color(0.24, 0.88, 0.82)

# billboards
var _u_pos := PackedVector3Array()
var _u_scr := PackedVector3Array()
var _order := PackedInt32Array()
var _steam_age := PackedFloat32Array()
var _steam_life := PackedFloat32Array()
var _steam_size := PackedFloat32Array()
var _streak := PackedVector3Array()   # x phase, y, length
var _plate := PackedVector2Array([Vector2(98, 70), Vector2(256, 70), Vector2(236, 126), Vector2(78, 126)])
var _plate_glint := PackedVector2Array([Vector2(190, 70), Vector2(214, 70), Vector2(196, 126), Vector2(172, 126)])
var _beam_pts := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _beam_cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.seed = 7
	_load_art()
	_build()
	_init_units()
	_cur.resize(P_N)
	_from.resize(P_N)
	_to.resize(P_N)
	# establishing shot: start high and far, settle into the wide shot
	var start := _shot_wide(0.0)
	start[P_DIST] += 900.0
	start[P_H] += 700.0
	start[P_ANG] = -0.5
	start[P_LIGHT] = 0.2
	_cur = start
	_go(_shot_wide(0.0), 2.6, EASE_SMOOTH)
	_mode = MODE_WIDE


## Connect to a ScriptPlayer (sets it to stage mode).
func bind(player: Control) -> void:
	_player = player
	player.set("stage_mode", true)
	if player.has_signal("line_started"):
		player.connect("line_started", _on_line)
	if player.has_signal("minigame_started"):
		player.connect("minigame_started", _on_minigame_started)
	if player.has_signal("minigame_finished"):
		player.connect("minigame_finished", _on_minigame_finished)
	if player.has_signal("bg_requested"):
		player.connect("bg_requested", set_bg)


# =================================================================== setup
func _load_art() -> void:
	_pod_tex = Assets.prop("stage_podium", 1.5)
	_thr_back = Assets.prop("stage_throne_back", 1.25)
	_thr_front = Assets.prop("stage_throne_front", 1.25)
	_memorial_tex = Assets.prop("stage_memorial", 1.5)
	_mochi_back = Assets.prop("stage_mochi_back")
	_steam_tex = Assets.prop("stage_steam")
	for id in Cast.ORDER:
		_expr[id] = "normal"
		if id != "coco":
			_por[id] = Assets.portrait(id, "normal")
	_expr["coco"] = "happy"
	_por["coco"] = Assets.portrait("coco", "happy")
	_expr["snapjaw"] = "happy"
	_por["snapjaw"] = Assets.portrait("snapjaw", "happy")


func _build() -> void:
	var black := ColorRect.new()
	black.color = Color("07040f")
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_root = Node2D.new()
	_root.position = CENTER
	add_child(_root)
	_world = Node2D.new()
	_world.position = -CENTER
	_root.add_child(_world)
	# environment (one full-screen ray-cast shader, oversized for roll + shake)
	_env = ColorRect.new()
	_env.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_env.position = Vector2(-90, -90)
	_env.size = Vector2(1460, 900)
	_env_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ENV_SHADER
	_env_mat.shader = sh
	var pano := Assets.prop("stage_pano")
	if pano != null:
		_env_mat.set_shader_parameter("pano", pano)
	_env_mat.set_shader_parameter("rect_origin", _env.position)
	_env_mat.set_shader_parameter("rect_size", _env.size)
	_env_mat.set_shader_parameter("screen_center", CENTER)
	_env_mat.set_shader_parameter("pool_r", POOL_R)
	_env_mat.set_shader_parameter("ring_r", RING_R)
	_env_mat.set_shader_parameter("wall_r", WALL_R)
	_env_mat.set_shader_parameter("wall_h", WALL_H)
	_env_mat.set_shader_parameter("island", Vector3(THRONE_POS.x, THRONE_POS.z, ISLAND_R))
	_env.material = _env_mat
	_world.add_child(_env)
	# light beams (additive, behind the figures)
	_beams = Node2D.new()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beams.material = add_mat
	_beams.draw.connect(_draw_beams)
	_world.add_child(_beams)
	# speaker silhouette (hard offset shadow + rim light)
	_rim = Node2D.new()
	var sil := ShaderMaterial.new()
	var sh2 := Shader.new()
	sh2.code = SIL_SHADER
	sil.shader = sh2
	_rim.material = sil
	_rim.draw.connect(_draw_rim)
	_world.add_child(_rim)
	# billboards
	_actors = Node2D.new()
	_actors.draw.connect(_draw_actors)
	_world.add_child(_actors)
	# speed streaks etc. (additive, on top)
	_fx = Node2D.new()
	_fx.material = add_mat
	_fx.draw.connect(_draw_fx)
	_world.add_child(_fx)
	# a non-trial background requested by the script (rare) covers the chamber
	_bg_overlay = ColorRect.new()
	_bg_overlay.color = Color.BLACK
	_bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_overlay.visible = false
	add_child(_bg_overlay)
	_bg_tex = TextureRect.new()
	_bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_overlay.add_child(_bg_tex)
	# vignette + colour flash (screen space)
	_vig = ColorRect.new()
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig_mat = ShaderMaterial.new()
	var sh3 := Shader.new()
	sh3.code = VIG_SHADER
	_vig_mat.shader = sh3
	_vig.material = _vig_mat
	add_child(_vig)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add2 := CanvasItemMaterial.new()
	add2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = add2
	_flash.color = Color(0, 0, 0, 0)
	add_child(_flash)


func _init_units() -> void:
	_u_pos.resize(N_UNITS)
	_u_scr.resize(N_UNITS)
	_order.resize(N_UNITS)
	for i in 15:
		var a := i * STEP
		_u_pos[i] = Vector3(sin(a) * RING_R, 0.0, cos(a) * RING_R)
	_u_pos[U_THRONE] = THRONE_POS
	_steam_age.resize(N_STEAM)
	_steam_life.resize(N_STEAM)
	_steam_size.resize(N_STEAM)
	for k in N_STEAM:
		_respawn_steam(k)
		_steam_age[k] = _rng.randf() * _steam_life[k]
	for k in N_UNITS:
		_order[k] = k
	_streak.resize(N_STREAKS)
	for k in N_STREAKS:
		_streak[k] = Vector3(_rng.randf() * 1600.0, _rng.randf_range(-60.0, 780.0), _rng.randf_range(90.0, 320.0))


func _respawn_steam(k: int) -> void:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * POOL_R * 0.85
	_u_pos[16 + k] = Vector3(sin(a) * r, _rng.randf_range(0.0, 60.0), cos(a) * r)
	_steam_life[k] = _rng.randf_range(6.0, 10.0)
	_steam_size[k] = _rng.randf_range(420.0, 720.0)
	_steam_age[k] = 0.0


# =================================================================== shots
func _mk(ang: float, dist: float, h: float, lr: float, ly: float, side: float, tside: float, f: float, roll: float, light: float) -> PackedFloat32Array:
	return PackedFloat32Array([ang, dist, h, lr, ly, side, tside, f, roll, light])


func _pod_ang(i: int) -> float:
	return i * STEP


func _shot_close(i: int) -> PackedFloat32Array:
	var side := 70.0 if i % 2 == 0 else -70.0
	var roll := deg_to_rad(0.8) * (1.0 if i % 2 == 0 else -1.0)
	return _mk(_pod_ang(i), RING_R + 1270.0, 400.0, RING_R - 220.0, 380.0, side, 0.0, 1400.0, roll, 1.0)


func _shot_medium(ang: float) -> PackedFloat32Array:
	return _mk(ang, RING_R + 1250.0, 900.0, -300.0, 200.0, 0.0, 0.0, 950.0, 0.0, 0.9)


func _shot_wide(ang: float) -> PackedFloat32Array:
	return _mk(ang, RING_R + 1400.0, 1250.0, -80.0, 20.0, 0.0, 0.0, 780.0, 0.0, 0.95)


func _shot_ots() -> PackedFloat32Array:
	return _mk(0.0, RING_R + 900.0, 470.0, -300.0, 330.0, 520.0, 140.0, 1000.0, deg_to_rad(-1.2), 0.95)


func _shot_throne() -> PackedFloat32Array:
	return _mk(0.0, 380.0, 120.0, THRONE_POS.z, 520.0, 0.0, 0.0, 900.0, deg_to_rad(-3.5), 0.95)


func _shot_orbit(ang: float) -> PackedFloat32Array:
	return _mk(ang, RING_R + 1300.0, 1050.0, -200.0, 120.0, 0.0, 0.0, 850.0, 0.0, 0.62)


func _fast() -> bool:
	# looked up dynamically so the stage also runs outside the game (preview harnesses)
	if _game == null:
		_game = get_node_or_null("/root/Game")
	return _game != null and bool(_game.call("is_fast_forward"))


## Start easing the camera towards a shot.
func _go(target: PackedFloat32Array, dur: float, ease_kind: int, bump: float = 0.0) -> void:
	if _orbit_off != 0.0:
		_cur[P_ANG] += _orbit_off
		_orbit_off = 0.0
	# fold the hold creep into the focal length so a new move starts without a jump
	_cur[P_F] *= _creep()
	_from = _cur.duplicate()
	_to = target
	_to[P_ANG] = _from[P_ANG] + wrapf(_to[P_ANG] - _from[P_ANG], -PI, PI)
	_tt = 0.0
	_dur = 0.04 if _fast() else dur
	_ease = ease_kind
	_bump = 0.0 if _fast() else bump
	_hold = 0.0


## Slow push-in while a shot is held.
func _creep() -> float:
	return 1.0 + minf(_hold, 8.0) * 0.004


static func _in_out(k: float) -> float:
	return 4.0 * k * k * k if k < 0.5 else 1.0 - pow(-2.0 * k + 2.0, 3.0) * 0.5


static func _expo_out(k: float) -> float:
	return 1.0 if k >= 1.0 else 1.0 - pow(2.0, -10.0 * k)


func _ease_val(j: int, k: float) -> float:
	match _ease:
		EASE_SWING:
			if j == P_ANG or j == P_SIDE or j == P_TSIDE or j == P_ROLL:
				return _in_out(clampf(k / 0.72, 0.0, 1.0))
			if j == P_LIGHT:
				return k
			return _expo_out(clampf((k - 0.38) / 0.62, 0.0, 1.0))
		EASE_SNAP:
			return _expo_out(k)
	return _in_out(k)


# =================================================================== hooks
func _on_line(who: String, expr: String) -> void:
	var prev := _who
	_who = who
	if Cast.exists(who):
		var old: String = str(_expr.get(who, "normal"))
		var changed := old != expr and expr != ""
		if changed:
			_expr[who] = expr
			_por[who] = Assets.portrait(who, expr)
		var same := prev == who
		if who == "snapjaw":
			_focus = U_THRONE
			if same and _mode == MODE_THRONE:
				_reframe_hold()
			else:
				_mode = MODE_THRONE
				_go(_shot_throne(), 0.62, EASE_SWING, 380.0)
				_pending_fx = "snapjaw"
		elif who == "mochi":
			_focus = 0
			if not (same and _mode == MODE_OTS):
				_mode = MODE_OTS
				_go(_shot_ots(), 0.6, EASE_SWING, 300.0)
		else:
			var i := Cast.ORDER.find(who)
			if i < 0:
				_mode = MODE_MEDIUM
				_go(_shot_medium(_cur[P_ANG]), 0.6, EASE_SMOOTH)
				return
			_focus = i
			if same and _mode == MODE_CLOSE:
				_reframe_hold()
			else:
				_mode = MODE_CLOSE
				var delta := absf(wrapf(_pod_ang(i) - (_cur[P_ANG] + _orbit_off), -PI, PI))
				_go(_shot_close(i), clampf(0.45 + delta * 0.12, 0.45, 0.7), EASE_SWING, 260.0 + delta * 160.0)
		if changed or not same:
			if same:
				_react(expr)
			else:
				_pending_fx = "snapjaw" if who == "snapjaw" else expr
	elif who == "all":
		_mode = MODE_WIDE
		_focus = -1
		var w := _shot_wide(_cur[P_ANG] + _orbit_off + 0.45)
		w[P_F] = 700.0
		_go(w, 0.5, EASE_SNAP)
		_kick_shake(9.0)
	else:
		if _mode == MODE_WIDE or _mode == MODE_MEDIUM:
			return
		_focus = -1
		var ang: float = _cur[P_ANG] + _orbit_off
		if _mode == MODE_THRONE or _mode == MODE_OTS:
			ang = 0.0
		if who == "think":
			_mode = MODE_MEDIUM
			_go(_shot_medium(ang), 0.85, EASE_SMOOTH)
		else:
			_mode = MODE_WIDE
			_go(_shot_wide(ang), 0.9, EASE_SMOOTH)


func _reframe_hold() -> void:
	_reframe += 1
	var t := _to.duplicate()
	var sgn := 1.0 if _reframe % 2 == 0 else -1.0
	t[P_SIDE] += 36.0 * sgn
	t[P_F] *= 1.0 + 0.035 * sgn
	t[P_H] += 10.0 * sgn
	_go(t, 0.35, EASE_SNAP)


func _on_minigame_started(_data_id: String, _type: String) -> void:
	_mode = MODE_ORBIT
	_focus = -1
	_who = ""
	_go(_shot_orbit(_cur[P_ANG] + _orbit_off), 1.1, EASE_SMOOTH)


func _on_minigame_finished(_data_id: String) -> void:
	_mode = MODE_MEDIUM
	_go(_shot_medium(_cur[P_ANG] + _orbit_off), 0.7, EASE_SMOOTH)


## "trial" shows the chamber; any other id covers it with that background ("none" = black).
func set_bg(bg_id: String) -> void:
	if bg_id == "trial" or bg_id == "":
		_bg_overlay.visible = false
		return
	_bg_tex.texture = null if bg_id == "none" else Assets.bg(bg_id)
	_bg_overlay.visible = true


func _react(expr: String) -> void:
	_pop = 1.0
	if (_mode == MODE_CLOSE or _mode == MODE_THRONE) and not _fast():
		_slash = 1.0
		_slash_col = Style.DANGER if expr == "angry" or expr == "snapjaw" else (Style.GOLD if expr == "happy" else Style.AQUA)
	match expr:
		"shock":
			_splash_at(_focus)
			_punch = 1.0
			_kick_shake(13.0)
			_rim_flash = 1.0
			_rim_col = Color(1, 1, 1)
		"angry":
			_rim_flash = 1.0
			_rim_col = Style.DANGER
			_kick_shake(6.0)
			_flash_a = maxf(_flash_a, 0.16)
			_flash.color = Style.DANGER
		"happy":
			_bounce = 1.0
		"snapjaw":
			_splash_at(U_THRONE)
			_flash_a = 0.42
			_flash.color = Color(1.0, 0.18, 0.2)
			_kick_shake(10.0)
			_punch = 0.6
			_rim_flash = 1.0
			_rim_col = Style.DANGER


## A ripple ring in the pool, starting at the island or at the pool edge in front of a podium.
func _splash_at(unit: int) -> void:
	if unit < 0 or unit >= 16:
		return
	var p := _u_pos[unit]
	var xz := Vector2(p.x, p.z)
	if unit < 15:
		xz *= POOL_R * 0.92 / RING_R
	_env_mat.set_shader_parameter("ripple", Vector4(xz.x, xz.y, _time, 1.0))


func _kick_shake(s: float) -> void:
	if _fast():
		return
	_shake = maxf(_shake, s)


# =================================================================== per frame
func _process(delta: float) -> void:
	_time += delta
	# camera parameter easing
	if _tt < _dur:
		_tt += delta
		var k := clampf(_tt / _dur, 0.0, 1.0)
		for j in P_N:
			_cur[j] = lerpf(_from[j], _to[j], _ease_val(j, k))
		if _bump != 0.0:
			var b := sin(PI * clampf(k / 0.8, 0.0, 1.0))
			_cur[P_DIST] += _bump * b
			_cur[P_H] += _bump * 0.3 * b
		if k >= 1.0 and _pending_fx != "":
			_react(_pending_fx)
			_pending_fx = ""
	elif _pending_fx != "":
		_react(_pending_fx)
		_pending_fx = ""
	_hold += delta
	# minigame orbit
	var ow := 0.16 if _mode == MODE_ORBIT else 0.0
	_orbit_w = move_toward(_orbit_w, ow, delta * 0.2)
	_orbit_off += _orbit_w * delta
	# decays
	_punch = move_toward(_punch, 0.0, delta * 4.5)
	_pop = move_toward(_pop, 0.0, delta * 5.5)
	_bounce = move_toward(_bounce, 0.0, delta * 3.2)
	_rim_flash = move_toward(_rim_flash, 0.0, delta * 2.6)
	_slash = move_toward(_slash, 0.0, delta * 2.4)
	_flash_a = move_toward(_flash_a, 0.0, delta * 1.1)
	_shake = move_toward(_shake, 0.0, delta * 38.0)
	var rim_target := 1.0 if (_mode == MODE_CLOSE or _mode == MODE_THRONE) and _tt >= _dur * 0.7 else 0.0
	_rim_a = move_toward(_rim_a, rim_target, delta * 3.0)
	var dim_target := 0.85
	match _mode:
		MODE_CLOSE, MODE_THRONE:
			dim_target = 0.4
		MODE_OTS:
			dim_target = 0.8
		MODE_ORBIT:
			dim_target = 0.72
	_others_dim = move_toward(_others_dim, dim_target, delta * 1.5)
	# whenever the camera stands behind Mochi's podium, Mochi (the player) is seen from behind
	var behind := absf(wrapf(_cur[P_ANG] + _orbit_off, -PI, PI)) < deg_to_rad(18.0) and _mode != MODE_THRONE
	_ots_k = move_toward(_ots_k, 1.0 if _mode == MODE_OTS or behind else 0.0, delta * (8.0 if _fast() else 3.5))
	# a sad speaker takes the light down a notch
	var sad := _mode == MODE_CLOSE and str(_expr.get(_who, "")) == "sad"
	_light_mul = move_toward(_light_mul, 0.84 if sad else 1.0, delta * 0.6)
	_update_camera()
	_update_spot(delta)
	_update_steam(delta)
	_project_units()
	# shake: own kicks + follow the ScriptPlayer's @shake (it moves itself)
	var sh := Vector2.ZERO
	if _shake > 0.0:
		sh = Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake) * 0.6)
	if _player != null:
		sh += _player.position
	_root.position = CENTER + sh
	_root.rotation = _cur[P_ROLL] + sin(_time * 0.31) * 0.002
	# shader + overlay uniforms
	_env_mat.set_shader_parameter("cam_pos", _cam_pos)
	_env_mat.set_shader_parameter("cam_right", _cam_right)
	_env_mat.set_shader_parameter("cam_up", _cam_up)
	_env_mat.set_shader_parameter("cam_fwd", _cam_fwd)
	_env_mat.set_shader_parameter("focal", _focal)
	_env_mat.set_shader_parameter("light", _cur[P_LIGHT] * _light_mul)
	_env_mat.set_shader_parameter("time_s", _time)
	_env_mat.set_shader_parameter("spot", Vector4(_spot_xz.x, _spot_xz.y, 380.0, _spot_i))
	_env_mat.set_shader_parameter("spot_color", Vector3(_spot_col.r, _spot_col.g, _spot_col.b))
	var vs := 0.78 if _mode == MODE_ORBIT else (0.62 if _mode == MODE_CLOSE or _mode == MODE_THRONE else 0.7)
	_vig_mat.set_shader_parameter("strength", vs)
	_flash.modulate.a = _flash_a
	_beams.queue_redraw()
	_rim.queue_redraw()
	_actors.queue_redraw()
	_fx.queue_redraw()


func _update_camera() -> void:
	var ang: float = _cur[P_ANG] + _orbit_off + sin(_time * 0.23) * 0.006
	var dir := Vector3(sin(ang), 0.0, cos(ang))
	var tng := Vector3(cos(ang), 0.0, -sin(ang))
	var breathe := sin(_time * 0.7) * 7.0
	_cam_pos = dir * _cur[P_DIST] + tng * _cur[P_SIDE] + Vector3(0.0, _cur[P_H] + breathe, 0.0)
	var target := dir * _cur[P_LR] + tng * _cur[P_TSIDE] + Vector3(0.0, _cur[P_LY] + breathe * 0.6, 0.0)
	_cam_fwd = (target - _cam_pos).normalized()
	_cam_right = _cam_fwd.cross(Vector3.UP).normalized()
	_cam_up = _cam_right.cross(_cam_fwd)
	# slow push-in while holding a shot + punch-ins
	var punch := 1.0 + 0.12 * _punch * _punch
	_focal = _cur[P_F] * _creep() * punch
	var v := (ang - _ang_prev) / maxf(get_process_delta_time(), 0.001)
	_ang_vel = lerpf(_ang_vel, v, 0.35)
	_ang_prev = ang


func _update_spot(delta: float) -> void:
	var want_i := 0.0
	var want := _spot_xz
	if _focus >= 0 and _mode != MODE_ORBIT:
		var p := _u_pos[_focus]
		want = Vector2(p.x, p.z)
		want_i = 1.0
		_spot_col = Color(1.0, 0.5, 0.45) if _focus == U_THRONE else Color(1.0, 0.92, 0.78)
	_spot_xz = _spot_xz.lerp(want, clampf(delta * 9.0, 0.0, 1.0))
	_spot_i = move_toward(_spot_i, want_i, delta * 2.5)


func _update_steam(delta: float) -> void:
	for k in N_STEAM:
		_steam_age[k] += delta
		if _steam_age[k] >= _steam_life[k]:
			_respawn_steam(k)
		var p := _u_pos[16 + k]
		p.y += delta * 34.0
		p.x += delta * 9.0
		_u_pos[16 + k] = p


func _proj(w: Vector3) -> Vector3:
	var v := w - _cam_pos
	var z := v.dot(_cam_fwd)
	if z < NEAR:
		return Vector3(0.0, 0.0, -1.0)
	var k := _focal / z
	return Vector3(CENTER.x + v.dot(_cam_right) * k, CENTER.y - v.dot(_cam_up) * k, z)


func _project_units() -> void:
	for k in N_UNITS:
		_u_scr[k] = _proj(_u_pos[k])
	# insertion sort, far -> near (no allocations)
	for a in range(1, N_UNITS):
		var idx := _order[a]
		var z := _u_scr[idx].z
		var b := a - 1
		while b >= 0 and _u_scr[_order[b]].z < z:
			_order[b + 1] = _order[b]
			b -= 1
		_order[b + 1] = idx


## Billboard modulate: distance fog, focus dimming, and a fade for things the camera flies past.
func _light_of(unit: int, z: float) -> Color:
	var fog := clampf(1.35 - z / 5200.0, 0.3, 1.0)
	var v := fog * _cur[P_LIGHT] * _light_mul
	var near := clampf((z - 220.0) / 380.0, 0.0, 1.0)
	if unit == _focus:
		return Color(v * 1.04, v * 1.0, v * 0.94, near)
	v *= _others_dim
	return Color(v * 0.92, v * 0.94, v * 1.06, near)


# =================================================================== drawing
func _draw_actors() -> void:
	var ci := _actors
	for n in N_UNITS:
		var u := _order[n]
		var s := _u_scr[u]
		if s.z <= 0.0:
			continue
		if u < 15:
			_draw_podium(ci, u, s)
		elif u == U_THRONE:
			_draw_throne(ci, s)
		else:
			_draw_steam(ci, u - 16, s)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _figure_rect(u: int, s: Vector3, top_y: float, cut_y: float, w: float) -> Rect2:
	var pos := _u_pos[u]
	var t := _proj(pos + Vector3(0.0, top_y, 0.0))
	var c := _proj(pos + Vector3(0.0, cut_y, 0.0))
	var sc := _focal / maxf((t.z + c.z) * 0.5, NEAR) if t.z > 0.0 and c.z > 0.0 else _focal / s.z
	var r := Rect2(s.x - w * 0.5 * sc, t.y, w * sc, c.y - t.y)
	if u == _focus:
		var grow := 1.0 + 0.05 * _pop * _pop
		var lift := -16.0 * sc * sin(_bounce * PI) + sin(_time * 2.1) * 1.5 * sc
		var breathe := 1.0 + sin(_time * 2.1) * 0.004
		var bottom := r.position.y + r.size.y
		var cx := r.position.x + r.size.x * 0.5
		r.size *= Vector2(grow, grow * breathe)
		r.position = Vector2(cx - r.size.x * 0.5, bottom - r.size.y + lift)
	return r


func _draw_podium(ci: Node2D, i: int, s: Vector3) -> void:
	var sc := _focal / s.z
	if s.x + 300.0 * sc < -80.0 or s.x - 300.0 * sc > 1360.0 or s.y - 700.0 * sc > 900.0:
		return
	var id: String = Cast.ORDER[i]
	var lit := _light_of(i, s.z)
	if lit.a <= 0.01:
		return
	var pos := _u_pos[i]
	# contact shadow
	ci.draw_set_transform(Vector2(s.x, s.y), 0.0, Vector2(POD_W * 0.62 * sc, POD_W * 0.11 * sc))
	ci.draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, 0.5 * lit.a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if id == "coco":
		_draw_memorial(ci, s, lit)
	else:
		var front_a := 1.0
		if id == "mochi":
			front_a = 1.0 - _ots_k
		if front_a > 0.01:
			var tex: Texture2D = _por.get(id)
			if tex != null:
				var r := _figure_rect(i, s, CHAR_TOP, CHAR_CUT, 480.0 * CHAR_SCALE)
				ci.draw_texture_rect_region(tex, r, Rect2(0, 0, 480, CUT_PX), Color(lit, front_a * lit.a))
	# podium front
	var top := _proj(pos + Vector3(0.0, POD_H, 0.0))
	var psc := _focal / ((top.z + s.z) * 0.5) if top.z > 0.0 else sc
	var pr := Rect2(s.x - POD_W * 0.5 * psc, top.y, POD_W * psc, s.y - top.y)
	if _pod_tex != null:
		var plit := lit
		if id == "mochi" and _ots_k > 0.0:
			plit = lit.darkened(0.55 * _ots_k)
		ci.draw_texture_rect(_pod_tex, pr, false, plit)
		# cast-colour nameplate
		ci.draw_set_transform(pr.position, 0.0, Vector2(psc, pr.size.y / POD_H))
		var pc := Cast.color(id) * plit
		pc.a = plit.a
		ci.draw_colored_polygon(_plate, pc)
		ci.draw_colored_polygon(_plate_glint, Color(1, 1, 1, 0.22 * plit.v * plit.a))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# Mochi seen from behind (over-the-shoulder shots)
	if id == "mochi" and _ots_k > 0.01 and _mochi_back != null:
		var r2 := _figure_rect(i, s, CHAR_TOP, CHAR_TOP - 680.0 * CHAR_SCALE, 480.0 * CHAR_SCALE)
		ci.draw_texture_rect(_mochi_back, r2, false, Color(lit.r * 0.8, lit.g * 0.72, lit.b * 0.8, _ots_k * lit.a))


func _draw_memorial(ci: Node2D, s: Vector3, lit: Color) -> void:
	# Coco's podium: a framed portrait on a little easel with a dark ribbon
	var pos := _u_pos[1]
	var sc := _focal / s.z
	var fs := 0.8
	var base_y := 206.0
	var top := _proj(pos + Vector3(0.0, base_y + 250.0 * fs, 0.0))
	var bot := _proj(pos + Vector3(0.0, base_y, 0.0))
	var fr := Rect2(s.x - 100.0 * fs * sc, top.y, 200.0 * fs * sc, bot.y - top.y)
	var ky := fr.size.y / 250.0
	var kx := fr.size.x / 200.0
	var win := Rect2(fr.position + Vector2(24.0 * kx, 24.0 * ky), Vector2(152.0 * kx, 172.0 * ky))
	ci.draw_rect(win, Color(0.12, 0.2, 0.26) * lit)
	var tex: Texture2D = _por.get("coco")
	if tex != null:
		ci.draw_texture_rect_region(tex, win, Rect2(50, 10, 380, 430), Color(lit.r * 0.78, lit.g * 0.82, lit.b * 0.92, lit.a))
	if _memorial_tex != null:
		ci.draw_texture_rect(_memorial_tex, fr, false, lit)


func _draw_throne(ci: Node2D, s: Vector3) -> void:
	var sc := _focal / s.z
	if s.x + 500.0 * sc < -80.0 or s.x - 500.0 * sc > 1360.0:
		return
	var lit := _light_of(U_THRONE, s.z)
	if lit.a <= 0.01:
		return
	var top := _proj(THRONE_POS + Vector3(0.0, THR_H, 0.0))
	var tsc := _focal / ((top.z + s.z) * 0.5) if top.z > 0.0 else sc
	var r := Rect2(s.x - THR_W * 0.5 * tsc, top.y, THR_W * tsc, s.y - top.y)
	if _thr_back != null:
		ci.draw_texture_rect(_thr_back, r, false, lit)
	var tex: Texture2D = _por.get("snapjaw")
	if tex != null:
		var fr := _figure_rect(U_THRONE, s, SNAP_TOP, SNAP_TOP - SNAP_CUT_PX * SNAP_SCALE, 480.0 * SNAP_SCALE)
		ci.draw_texture_rect_region(tex, fr, Rect2(0, 0, 480, SNAP_CUT_PX), lit)
	if _thr_front != null:
		ci.draw_texture_rect(_thr_front, r, false, lit)


func _draw_steam(ci: Node2D, k: int, s: Vector3) -> void:
	if _steam_tex == null:
		return
	var sc := _focal / s.z
	var sz := _steam_size[k] * sc
	if sz < 8.0 or s.x + sz < -50.0 or s.x - sz > 1330.0:
		return
	var life := _steam_age[k] / _steam_life[k]
	var a := sin(life * PI) * 0.27 * clampf((s.z - 300.0) / 900.0, 0.0, 1.0)
	var col := Color(0.75, 0.95, 0.95, a * _cur[P_LIGHT])
	ci.draw_texture_rect(_steam_tex, Rect2(s.x - sz * 0.5, s.y - sz * 0.75, sz, sz * 0.75), false, col)


func _draw_rim() -> void:
	if _focus < 0 or _rim_a + _rim_flash <= 0.01:
		return
	var s := _u_scr[_focus]
	if s.z <= 0.0:
		return
	var tex: Texture2D
	var r: Rect2
	var src: Rect2
	if _focus == U_THRONE:
		tex = _por.get("snapjaw")
		r = _figure_rect(U_THRONE, s, SNAP_TOP, SNAP_TOP - SNAP_CUT_PX * SNAP_SCALE, 480.0 * SNAP_SCALE)
		src = Rect2(0, 0, 480, SNAP_CUT_PX)
	elif _focus == 0:
		return
	else:
		tex = _por.get(Cast.ORDER[_focus])
		r = _figure_rect(_focus, s, CHAR_TOP, CHAR_CUT, 480.0 * CHAR_SCALE)
		src = Rect2(0, 0, 480, CUT_PX)
	if tex == null:
		return
	var a := clampf(_rim_a, 0.0, 1.0)
	var k := r.size.x / 432.0
	# hard offset shadow (near-black) + coloured rim light offset the other way
	_rim.draw_texture_rect_region(tex, Rect2(r.position + Vector2(16, 10) * k, r.size), src, Color(0.02, 0.01, 0.05, 0.75 * a))
	var rc := Style.AQUA.lerp(_rim_col, _rim_flash)
	var off := Vector2(-7, -5) * k * (1.0 + _rim_flash * 0.8)
	_rim.draw_texture_rect_region(tex, Rect2(r.position + off, r.size), src, Color(rc, maxf(0.7 * a, _rim_flash)))


func _draw_beams() -> void:
	var ci := _beams
	# slow ambient beams sweeping over the pool from the ceiling
	for k in 3:
		var ph := _time * 0.11 + k * TAU / 3.0
		var src := Vector3(sin(k * 2.1) * 900.0, WALL_H + 400.0, cos(k * 2.1) * 900.0)
		var dst := Vector3(sin(ph) * POOL_R * 0.6, 0.0, cos(ph) * POOL_R * 0.6 - 150.0)
		var col := Color(0.25, 0.9, 0.85) if k != 1 else Color(0.6, 0.42, 0.85)
		_beam(ci, src, dst, 50.0, 300.0, Color(col, 0.035 * _cur[P_LIGHT]), Color(col, 0.05 * _cur[P_LIGHT]))
	# angular light slash sweeping behind a speaker who just took the floor
	if _slash > 0.0:
		var k := 1.0 - _slash
		var x := lerpf(-560.0, 1450.0, 1.0 - pow(1.0 - k, 3.0))
		var a := minf(_slash * 1.6, 1.0)
		_beam_pts[0] = Vector2(x + 260.0, -100.0)
		_beam_pts[1] = Vector2(x + 450.0, -100.0)
		_beam_pts[2] = Vector2(x + 70.0, 820.0)
		_beam_pts[3] = Vector2(x - 120.0, 820.0)
		for j in 4:
			_beam_cols[j] = Color(_slash_col, a * (0.5 if j < 2 else 0.22))
		ci.draw_polygon(_beam_pts, _beam_cols)
		ci.draw_line(Vector2(x + 500.0, -100.0), Vector2(x + 120.0, 820.0), Color(Style.GOLD, a * 0.85), 9.0)
		ci.draw_line(Vector2(x + 540.0, -100.0), Vector2(x + 160.0, 820.0), Color(_slash_col, a * 0.5), 3.0)
	# the speaker's spotlight
	if _spot_i > 0.01:
		var p := Vector3(_spot_xz.x, 0.0, _spot_xz.y)
		var c := _spot_col
		_beam(ci, p + Vector3(0.0, 2600.0, 0.0), p, 70.0, 420.0, Color(c, 0.05 * _spot_i), Color(c, 0.16 * _spot_i))
		_beam(ci, p + Vector3(0.0, 2600.0, 0.0), p, 26.0, 210.0, Color(c, 0.03 * _spot_i), Color(c, 0.1 * _spot_i))


func _beam(ci: Node2D, src: Vector3, dst: Vector3, w_top: float, w_bot: float, c_top: Color, c_bot: Color) -> void:
	var b := _proj(dst)
	if b.z <= 0.0:
		return
	var t := _proj(src)
	if t.z <= 0.0:
		# source behind the camera: aim straight up from the target
		t = Vector3(b.x, -400.0, b.z)
	var st := _focal / t.z
	var sb := _focal / b.z
	_beam_pts[0] = Vector2(t.x - w_top * st, t.y)
	_beam_pts[1] = Vector2(t.x + w_top * st, t.y)
	_beam_pts[2] = Vector2(b.x + w_bot * sb, b.y)
	_beam_pts[3] = Vector2(b.x - w_bot * sb, b.y)
	_beam_cols[0] = c_top
	_beam_cols[1] = c_top
	_beam_cols[2] = c_bot
	_beam_cols[3] = c_bot
	ci.draw_polygon(_beam_pts, _beam_cols)


func _draw_fx() -> void:
	# speed streaks while the camera swings around the ring
	var spd := absf(_ang_vel)
	var a := clampf((spd - 0.9) / 2.5, 0.0, 1.0)
	if a <= 0.0:
		return
	var dirx := -signf(_ang_vel)
	for k in N_STREAKS:
		var st := _streak[k]
		var x := fposmod(st.x + dirx * _time * 2600.0 * (0.7 + 0.3 * float(k % 3)), 1700.0) - 210.0
		var col := Color(0.55, 1.0, 0.95, 0.22 * a) if k % 4 != 0 else Color(1.0, 0.82, 0.45, 0.2 * a)
		_fx.draw_line(Vector2(x, st.y), Vector2(x + st.z * dirx, st.y), col, 2.0 + float(k % 3))
