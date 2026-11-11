extends "res://scripts/screens/cutscene_base.gd"
## "RIGHT ON SCHEDULE" - the Chapter 3 earthquake, flood and tunnel cutscene, flow step `quake` (plan section 3.1).
## About 55 s in the lake drain's language: slanted cut-in panels with hard ink shadows, diagonal static wipes,
## speed lines, shake and hit-stops, big slanted title badges. The lake Snapjaw pulled the plug on comes back.
##   A  0.0  the tremor: static wipe in, the Mudlark's rail up close, a teacup rattling, fungus flickering, pebbles
##   B  5.4  Snapjaw cut-in "RIGHT ON SCHEDULE!", his pocket watch and the detonator; charges blink along the pillars
##   C 11.05 the quake: the cave shakes, stalactites fall, cracks race over the wall, "RUMBLE!!"; four reaction cut-ins
##   D 18.0  the wall gives way: the lake bursts back in, the ship lifts off the mud, three mooring ropes snap
##   E 27.6  the tunnel: point of view down a vast dark tunnel, four more cut-ins; side view, a low arch shears a stack
##   F 39.6  daylight: white-out, the ship shoots out of a sea cliff, a huge arc, "KER-SPLOOSH!!", then gulls and sky
##   G 47.8  the island: a slow pan over open sea to the prison and the house on the cliff, title badge
##   H 54.2  diagonal static wipe to the shore
## Built on cutscene_base.gd (clock, keyframes, hit-stop, hold-to-skip, particles). drain_screen.gd is not touched.
## Autotest: about 0.3 s. Debug: --quake-t=<seconds> starts there; with --shot=<png> as well it saves exactly that frame.
## Art: art/props/qk_*.svg (tools/gen_quake_art.py) plus the drain's cave and Mudlark (dr_*.svg, tools/gen_drain_art.py).
## SFX: audio/sfx/qk_*.wav (tools/gen_quake_audio.py). Every asset may be missing; the scene then draws without it.
## Reaction cut-ins use the existing portraits only; the hat, pots, rope and scribbles are separate overlays.

const END_TIME := 55.6
const SHOT_LEAD := 0.45
const WATER := [Color("3ee0d0"), Color("bff8ff"), Color("ffffff"), Color("6fd6ff")]
const SNAP_GREEN := Color("43a047")
const ROCK := Color("1a2236")

# ------------------------------------------------------------------ shared with tools/gen_quake_art.py
const CUP_AT := Vector2(772, 446)
const CUP_BASE := Vector2(75, 112)
const CHARGES := [Vector3(214, 386, 1.0), Vector3(606, 352, 0.62), Vector3(884, 334, 0.4), Vector3(1062, 324, 0.27)]
const WATCH_C := Vector2(180, 232)
const PLUNGER_ROD := Vector2(200, 470)
const DETONATOR_SLOT := Vector2(260, 96)
const STACK_ORIGIN := Vector2(412, 30)
const STACK_SIZE := Vector2(128, 220)
const BOW_VP := Vector2(640, 300)
const TUNNEL_MOUTH := Vector2(962, 356)
# ------------------------------------------------------------------ shared with tools/gen_drain_art.py (the Mudlark, dr_cave)
const SHIP_MID := Vector2(600, 520)
const WATERLINE := 690.0
const WHEEL_C := Vector2(1040, 630)
const STACK_X := [467.0, 546.0]
const SHIP_G_POS := Vector2(334.2, 84.0)
const SHIP_G_SCALE := 0.5206
const LANTERNS := [Vector2(100.3, 412.2), Vector2(176.9, 409.4), Vector2(253.5, 392.0), Vector2(330.1, 359.8),
	Vector2(406.7, 313.0), Vector2(584.2, 307.6), Vector2(616.5, 340.0), Vector2(648.8, 352.9), Vector2(691.7, 373.4),
	Vector2(745.1, 406.6), Vector2(798.5, 427.0), Vector2(851.9, 434.6), Vector2(905.3, 429.4), Vector2(190.0, 568.0),
	Vector2(280.0, 568.0), Vector2(370.0, 568.0), Vector2(460.0, 568.0), Vector2(550.0, 568.0), Vector2(640.0, 568.0),
	Vector2(730.0, 568.0), Vector2(820.0, 568.0)]
const LANTERN_COLS := [Color("ff5a3c"), Color("ff9a3c"), Color("ffd25a")]
const FUNGUS := [Vector3(60, 226, 1.1), Vector3(130, 318, 1.0), Vector3(46, 392, 0.9), Vector3(1215, 214, 1.1), Vector3(1160, 336, 1.0),
	Vector3(1240, 404, 0.9), Vector3(330, 96, 0.7), Vector3(610, 104, 0.8), Vector3(880, 92, 0.8), Vector3(470, 250, 0.5),
	Vector3(820, 236, 0.6), Vector3(560, 300, 0.6), Vector3(760, 300, 0.6), Vector3(1000, 294, 0.6)]

# ------------------------------------------------------------------ composition
const CAVE_BASE := 1.12                       # the cave shot's layers overscan so the camera can pan
const BURST_C := Vector2(1110, 210)          # the hole the lake comes back through (dr_cave px)
const TUNNEL_L := Vector2(150, 250)          # the tunnel that opens in the left wall (dr_cave px)
const FLOOD_TOP := 336.0                      # where the lake comes back up to (cave shot px)
const FLOAT_WL := 443.0                       # the Mudlark's waterline on the mud in the cave shot (screen px)
## Mooring ropes: [shore end (screen px of the cave shot), ship end (Mudlark canvas px)]
const ROPES := [[Vector2(330, 444), Vector2(70, 628)], [Vector2(560, 586), Vector2(430, 640)], [Vector2(1000, 566), Vector2(940, 640)]]
const SIDE_POS := Vector2(200, 150)
const SIDE_SCALE := 0.62
const SIDE_WL := 585.0
const ARCH_W := 300.0
const ARCH_LOW := 288.0
const ARC_P0 := Vector2(905, 372)
const ARC_P1 := Vector2(610, 40)
const SEA_F := 600.0                         # the near sea's surface in the daylight shot
const ARC_P2 := Vector2(360, SEA_F - 46.0)   # where she comes down (her waterline is 51 px under this point)
const SKY_SHIP_SCALE := 0.3
const ISLE_POS := Vector2(0, 12)
const ISLE_SCALE := 0.8
const SEA_G := 540.0                         # the island's waterline in the island shot
const ISLE_SHIP := Vector2(930, 612)
const DET_SC := 0.55
const SHORE_BGS := ["res://art/bg/manor_shore.svg", "res://art/bg/shore.svg"]

## [id, expression, line, box position, side, line above the box, extra overlay]
const REACTS := [
	["lulu", "shock", "LULU-LUUUUU!!", Vector2(40, 62), -1.0, false, "scream"],
	["grub", "shock", "Not my good pots!", Vector2(820, 90), 1.0, false, "pots"],
	["reginald", "angry", "I'm lashed to the rail! Steady!", Vector2(60, 410), -1.0, true, "rope"],
	["bruno", "angry", "Bruno has you! Both of you!", Vector2(800, 436), 1.0, true, "catch"],
	["pepper", "happy", "Front page! FRONT PAGE!", Vector2(40, 62), -1.0, false, "flash"],
	["duchess", "shock", "My HAT! Not the HAT!", Vector2(820, 90), 1.0, false, "hat"],
	["nibs", "shock", "Ninety knots. Hypothetically.", Vector2(60, 410), -1.0, true, "maths"],
	["zuzu", "normal", "cool. cool cool cool.", Vector2(800, 436), 1.0, true, "deadpan"],
]

## Cuts the forward smokestack's top off dr_ship once `cut` is 1 (same jagged line as gen_quake_art.cut_y).
const CUT_SHADER := """
shader_type canvas_item;
uniform float cut = 0.0;
varying vec2 vp;
void vertex() {
	vp = VERTEX;
}
float ycut(float x) {
	float u = x / 14.0;
	return 236.0 + 6.0 * (abs(fract(u) * 2.0 - 1.0) * 2.0 - 1.0);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (cut > 0.5) {
		float yc = ycut(vp.x);
		if (vp.x > 412.0 && vp.x < 521.5 && vp.y < yc) {
			c.a = 0.0;
		} else if (vp.x > 443.0 && vp.x < 491.0 && vp.y < yc + 3.5) {
			c.rgb = vec3(0.02, 0.016, 0.03);
		} else if (vp.x >= 521.5 && vp.x < 535.0 && vp.y > 168.0 && vp.y < 240.0) {
			if (vp.x < 524.0) {
				c.a = 0.0;
			} else if (vp.x < 526.5) {
				c.rgb = vec3(0.16, 0.1, 0.06);
			} else {
				c.rgb = vec3(0.07, 0.067, 0.094);
			}
		}
	}
	COLOR = c;
}
"""

## Point of view down the tunnel: a rock tube with ribs and glowing fungus, a rushing water floor, fog.
const TUNNEL_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 vp = vec2(840.0, 500.0);
uniform float travel = 0.0;
uniform float light = 0.0;
varying vec2 pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	pos = VERTEX;
}

void fragment() {
	vec2 d = pos - vp;
	float r = max(length(d), 1.0);
	float F = 520.0;
	float w = 0.4;
	vec3 col;
	float depth;
	if (d.y / r > w) {
		float zw = w * F / max(d.y, 0.001);
		depth = zw;
		float xw = d.x / F * zw;
		float zz = zw + travel;
		float n = vnoise(vec2(xw * 3.0, zz * 0.5));
		col = mix(vec3(0.02, 0.07, 0.1), vec3(0.05, 0.2, 0.24), step(0.55, n));
		float streak = step(0.84, vnoise(vec2(xw * 12.0, zz * 0.16)));
		col = mix(col, vec3(0.78, 1.0, 1.0), streak * 0.85);
		float refl = step(0.93, vnoise(vec2(xw * 6.0 + sin(zz * 0.7) * 0.3, zz * 0.9)));
		col += vec3(0.1, 0.6, 0.55) * refl;
	} else {
		float zw2 = F / r;
		depth = zw2;
		float a = atan(d.y, d.x);
		float zz = zw2 + travel;
		float n = vnoise(vec2(a * 5.0, zz * 0.9)) * 0.6 + vnoise(vec2(a * 17.0, zz * 2.7)) * 0.4;
		vec3 rock = mix(vec3(0.04, 0.05, 0.09), vec3(0.12, 0.15, 0.24), step(0.5, n));
		rock = mix(rock, rock * 0.55, step(0.78, vnoise(vec2(a * 9.0, zz * 0.35))));
		float rib = fract(zz * 0.25 + 0.05 * sin(a * 3.0));
		float ribm = smoothstep(0.0, 0.04, rib) * (1.0 - smoothstep(0.1, 0.17, rib));
		rock = mix(rock, vec3(0.24, 0.3, 0.42), ribm * 0.9);
		rock = mix(rock, vec3(0.01, 0.01, 0.02), step(0.17, rib) * (1.0 - smoothstep(0.17, 0.3, rib)) * 0.85);
		vec2 cell = vec2(floor(a * 7.0), floor(zz * 0.5));
		float h = hash(cell);
		float fy = fract(zz * 0.5);
		float fx = fract(a * 7.0);
		float spot = step(0.8, h) * (1.0 - smoothstep(0.07, 0.16, abs(fx - 0.5))) * smoothstep(0.0, 0.12, fy) * (1.0 - smoothstep(0.3, 0.75, fy));
		rock += vec3(0.25, 0.95, 0.85) * spot;
		col = rock;
	}
	float fog = exp(-depth * 0.085);
	col = col * fog + vec3(0.03, 0.12, 0.13) * (1.0 - fog) * 0.25;
	float lr = light * 1400.0;
	col = mix(col, vec3(1.0, 0.98, 0.9), (1.0 - smoothstep(lr * 0.2, lr, r)) * clamp(light * 1.5, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
"""

# ------------------------------------------------------------------ state
var _shot := ""
var _cam_c := C
var _cam_z := 1.0
var _cam_roll := 0.0
var _drift_k := 1.0
var _tx := {}
var _cut_mat: ShaderMaterial
var _shot_t := -1.0
var _shot_taken := false
var _cpainters: Array = []
var _emit_acc := 0.0
# A
var _cup_shake := 0.0
var _cup_slide := 0.0
var _flicker := 0.0
var _dim := 0.0
var _pebble_rate := 0.0
# B
var _minute := 57.0
var _push_k := 0.0
var _armed := [-100.0, -100.0, -100.0, -100.0]
# C / D
var _quake := 0.0
var _falls: Array = []
var _fall_acc := 0.0
var _cracks: Array = []
var _crack_t0: Array = []
var _branches: Array = []
var _jets_k := 0.0
var _burst_k := 0.0
var _flood_x := 1500.0
var _flood_y := 800.0
var _front_h := 0.0
var _ship_dx := 0.0
var _ship_dy := 0.0
var _ship_rock := 0.0
var _ship_tilt := 0.0
var _rope_snap := [-100.0, -100.0, -100.0]
var _tunnel_k := 0.0
var _boulders: Array = []
# E
var _travel := 0.0
var _tun_v := 0.0
var _scroll := 0.0
var _side_speed := 0.0
var _wheel_ang := 0.0
var _wheel_v := 0.0
var _arch_x := -900.0
var _piece_on := false
var _piece_p := Vector2.ZERO
var _piece_v := Vector2.ZERO
var _piece_r := 0.0
var _skr_k := 0.0
var _white := 0.0
var _glow_left := 0.0
# F / G
var _arc_k := 0.0
var _landed := false
var _splash_t := -100.0
var _jet_k := 0.0
var _bob := 0.0

# nodes
var _rail_root: Node2D
var _rail_layers: Array = []
var _cup: Sprite2D
var _pil_root: Node2D
var _pil_layers: Array = []
var _cave_root: Node2D
var _cave_layers: Array = []
var _cship: Dictionary = {}
var _tun_root: Node2D
var _tun_layers: Array = []
var _tun_mat: ShaderMaterial
var _bow: Node2D
var _side_root: Node2D
var _side_layers: Array = []
var _sship: Dictionary = {}
var _piece: Sprite2D
var _sky_root: Node2D
var _sky_layers: Array = []
var _fship: Dictionary = {}
var _fpivot: Node2D
var _isle_root: Node2D
var _isle_layers: Array = []
var _gship: Dictionary = {}
var _white_rect: ColorRect

# overlays
var _loc: Control
var _rattle_lbl: Label
var _sh: Dictionary = {}
var _ecu: Dictionary = {}
var _bangs: Dictionary = {}
var _reacts: Array = []
var _snap_lbls: Array = []
var _skr: Dictionary = {}
var _caption: Control
var _title: Dictionary = {}


# ================================================================== base overrides
func _debug_start_time() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quake-t="):
			var t := clampf(float(a.get_slice("=", 1)), 0.0, END_TIME - 0.1)
			if Game.shot_path != "":
				_shot_t = t
				return maxf(0.0, t - SHOT_LEAD)
			return t
	return 0.0


func _fast_forward(start: float) -> void:
	super(start)
	if _music_id == "":
		Audio.stop_music(0.2)


## A timed screenshot (--quake-t with --shot) holds the clock through the screen's fade-in, then saves that exact frame.
func _process(delta: float) -> void:
	if _shot_t >= 0.0 and not _done:
		if _shot_taken or (Game.main and Game.main.is_transitioning()):
			return
		if _t >= _shot_t:
			_shot_taken = true
			Game.main.save_shot()
			return
	super(delta)


# ================================================================== building
func _build_scene() -> void:
	_rng.seed = 5503
	_end_at = END_TIME
	_skip_after = 2.0
	for n in ["dr_cave", "dr_mud", "dr_dock", "dr_front", "dr_ship", "dr_ship_over", "dr_wheel", "qk_rail", "qk_cup", "qk_pillars",
			"qk_watch", "qk_detonator", "qk_plunger", "qk_stalactite", "qk_boulder", "qk_stack", "qk_bow", "qk_sky", "qk_cliff",
			"qk_island", "qk_hat", "qk_pots"]:
		_tx[n] = Assets.prop(n)
	var sh := Shader.new()
	sh.code = CUT_SHADER
	_cut_mat = ShaderMaterial.new()
	_cut_mat.shader = sh
	_build_rail()
	_build_pillars()
	_build_cave()
	_build_tunnel()
	_build_side()
	_build_sky()
	_build_isle()
	_build_loc()
	_build_shout()
	_build_ecu()
	for b in [["rumble", "RUMBLE!!", Style.DANGER], ["kakoom", "KRA-KOOM!!", Style.AQUA], ["sploosh", "KER-SPLOOSH!!", Style.AQUA]]:
		var bb: Array = b
		_bangs[str(bb[0])] = _build_bang(str(bb[1]), bb[2])
	_build_reacts()
	_build_snaps()
	_build_skr()
	_build_caption()
	_build_title()
	_white_rect = ColorRect.new()
	_white_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white_rect.color = Color(1, 1, 1, 0)
	add_child(_white_rect)
	move_child(_white_rect, _shaker.get_index() + 1)
	_wipe_cover = 1.0
	_show_shot("black")


func _tex(n: String) -> Texture2D:
	return _tx.get(n, null)


func _fill(parent: Node, col: Color, rect: Rect2 = Rect2(0, 0, W, H)) -> void:
	_painter(parent, func(ci: Node2D) -> void: ci.draw_rect(rect, col))


func _cpainter(parent: Control, fn: Callable, sz: Vector2 = Vector2(W, H)) -> CPainter:
	var p := CPainter.new()
	p.fn = fn
	p.size = sz
	parent.add_child(p)
	_cpainters.append(p)
	return p


## The Mudlark (dr_ship + wheel + wheel beam) under `parent`; its hull sprite carries the stack-cut shader.
func _make_ship(parent: Node, pos: Vector2, sc: float, lights: bool) -> Dictionary:
	var n := _node(parent, pos, sc)
	var s := _spr(n, _tex("dr_ship"))
	s.material = _cut_mat
	var w := _spr(n, _tex("dr_wheel"), WHEEL_C, true)
	_spr(n, _tex("dr_ship_over"))
	if lights:
		_painter(n, _draw_ship_lights, true)
		_painter(n, _draw_ship_lights_core)
	return {"node": n, "wheel": w}


# ------------------------------------------------------------------ A: the rail
func _build_rail() -> void:
	_rail_root = _node(_world)
	var l_far := _node(_rail_root)
	if _tex("dr_cave"):
		_spr(l_far, _tex("dr_cave"))
	else:
		_fill(l_far, Color("0c0a1c"))
	_painter(l_far, _draw_fungus, true)
	_painter(l_far, func(ci: Node2D) -> void: ci.draw_rect(Rect2(-100, -100, W + 200, H + 200), Color(INK, _dim)))
	var l_mid := _node(_rail_root)
	if _tex("dr_mud"):
		_spr(l_mid, _tex("dr_mud"))
	if _tex("dr_dock"):
		_spr(l_mid, _tex("dr_dock"))
	_painter(l_mid, func(ci: Node2D) -> void: _draw_parts(ci, "rail_far"))
	var l_rail := _node(_rail_root)
	if _tex("qk_rail"):
		_spr(l_rail, _tex("qk_rail"))
	_cup = _spr(l_rail, _tex("qk_cup"), CUP_AT)
	_cup.offset = -CUP_BASE
	_painter(l_rail, _draw_cup_fx)
	_painter(l_rail, func(ci: Node2D) -> void: _draw_parts(ci, "rail"))
	_rail_layers = [[l_far, 0.45, 1.16, C], [l_mid, 0.6, 1.16, C], [l_rail, 1.15, 1.0, C]]


# ------------------------------------------------------------------ B: the pillars
func _build_pillars() -> void:
	_pil_root = _node(_world)
	var l := _node(_pil_root)
	if _tex("qk_pillars"):
		_spr(l, _tex("qk_pillars"))
	else:
		_fill(l, Color("0b1424"))
	_painter(l, _draw_lamps, true)
	_painter(l, _draw_lamp_cores)
	_pil_layers = [[l, 1.0, 1.0, C]]


# ------------------------------------------------------------------ C/D: the cave
func _build_cave() -> void:
	_cave_root = _node(_world)
	var l_cave := _node(_cave_root)
	if _tex("dr_cave"):
		_spr(l_cave, _tex("dr_cave"))
	else:
		_fill(l_cave, Color("0c0a1c"))
	_painter(l_cave, _draw_fungus, true)
	_painter(l_cave, _draw_cracks)
	_painter(l_cave, _draw_cracks_glow, true)
	_painter(l_cave, _draw_burst)
	_painter(l_cave, _draw_tunnel_l)
	var l_mud := _node(_cave_root)
	if _tex("dr_mud"):
		_spr(l_mud, _tex("dr_mud"))
	else:
		_fill(l_mud, Color("2a1f1c"), Rect2(0, 330, W, H - 330))
	_painter(l_mud, _draw_stakes)
	_painter(l_mud, _draw_falls.bind(false))
	var l_ship := _node(_cave_root)
	_cship = _make_ship(l_ship, SHIP_G_POS, SHIP_G_SCALE, true)
	_painter(l_ship, _draw_flood)
	_painter(l_ship, _draw_ropes)
	_painter(l_ship, _draw_falls.bind(true))
	_painter(l_ship, _draw_boulders)
	_painter(l_ship, func(ci: Node2D) -> void: _draw_parts(ci, "cave"))
	var l_dock := _node(_cave_root)
	if _tex("dr_dock"):
		_spr(l_dock, _tex("dr_dock"))
	_painter(l_dock, _draw_flood_dock)
	var l_front := _node(_cave_root)
	if _tex("dr_front"):
		_spr(l_front, _tex("dr_front"))
	_painter(l_front, func(ci: Node2D) -> void: _draw_parts(ci, "front"))
	_cave_layers = [[l_cave, 0.6, CAVE_BASE, C], [l_mud, 0.6, CAVE_BASE, C], [l_ship, 0.6, CAVE_BASE, C], [l_dock, 1.0, CAVE_BASE, C],
		[l_front, 1.35, CAVE_BASE * 1.05, C]]
	# cracks: random walks over the back wall, the ceiling and the right wall (the last one is where it bursts)
	var starts := [[Vector2(300, 190), 0.25], [Vector2(640, 150), -0.15], [Vector2(880, 180), 0.6], [Vector2(1060, 96), 1.25],
		[Vector2(470, 110), 2.6], [Vector2(200, 120), 0.9]]
	for s in starts:
		var ss: Array = s
		var p: Vector2 = ss[0]
		var ang: float = ss[1]
		var pts := PackedVector2Array([p])
		for i in 20:
			ang += _rng.randf_range(-0.55, 0.55)
			p += Vector2.from_angle(ang) * _rng.randf_range(14.0, 26.0)
			pts.append(p)
		_cracks.append(pts)
		_crack_t0.append(-100.0)
		var br: Array = []
		for j in [5, 10, 15]:
			var q: Vector2 = pts[j]
			var ba := ang + (1.0 if j % 2 == 0 else -1.0) * _rng.randf_range(0.6, 1.1)
			var bp := PackedVector2Array([q])
			for m in 5:
				ba += _rng.randf_range(-0.5, 0.5)
				q += Vector2.from_angle(ba) * _rng.randf_range(10.0, 18.0)
				bp.append(q)
			br.append([j, bp])
		_branches.append(br)


# ------------------------------------------------------------------ E1: the tunnel, point of view
func _build_tunnel() -> void:
	_tun_root = _node(_world)
	var l := _node(_tun_root)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(-220, -220)
	rect.size = Vector2(W + 440, H + 440)
	var sh := Shader.new()
	sh.code = TUNNEL_SHADER
	_tun_mat = ShaderMaterial.new()
	_tun_mat.shader = sh
	_tun_mat.set_shader_parameter("vp", BOW_VP - rect.position)
	rect.material = _tun_mat
	l.add_child(rect)
	_painter(l, _draw_tunnel_streaks, true)
	_bow = _node(l, Vector2(640, 780))
	if _tex("qk_bow"):
		_spr(_bow, _tex("qk_bow"), Vector2(-640, -780))
	_bow.scale = Vector2(1.06, 1.06)
	_painter(l, func(ci: Node2D) -> void: _draw_parts(ci, "tun"))
	_tun_layers = [[l, 1.0, 1.0, C]]


# ------------------------------------------------------------------ E2: the tunnel, side view
func _build_side() -> void:
	_side_root = _node(_world)
	var l_bg := _node(_side_root)
	_painter(l_bg, _draw_side_bg)
	_painter(l_bg, _draw_side_glow, true)
	var l_ship := _node(_side_root)
	_sship = _make_ship(l_ship, SIDE_POS, SIDE_SCALE, true)
	_painter(l_ship, _draw_side_water)
	_piece = _spr(l_ship, _tex("qk_stack"), Vector2.ZERO, true)
	_piece.visible = false
	_painter(l_ship, func(ci: Node2D) -> void: _draw_parts(ci, "side"))
	_painter(l_ship, _draw_arch)
	_side_layers = [[l_bg, 1.0, 1.0, C], [l_ship, 1.0, 1.0, C]]


# ------------------------------------------------------------------ F: daylight
func _build_sky() -> void:
	_sky_root = _node(_world)
	var l_sky := _node(_sky_root)
	if _tex("qk_sky"):
		_spr(l_sky, _tex("qk_sky"))
	else:
		_fill(l_sky, Color("5e9be6"))
	_painter(l_sky, _draw_gulls.bind(0))
	var l_cliff := _node(_sky_root)
	_painter(l_cliff, func(ci: Node2D) -> void:
		ci.draw_rect(Rect2(1240, 10, 900, 900), Color("3a2f2a"))
		for k in 12:
			ci.draw_line(Vector2(1240, 70.0 + k * 46.0), Vector2(2100, 76.0 + k * 46.0), Color("2a221e"), 4.0)
		ci.draw_rect(Rect2(1272, -2, 900, 16), Color("4a9a42")))
	if _tex("qk_cliff"):
		_spr(l_cliff, _tex("qk_cliff"))
	_painter(l_cliff, _draw_jet)
	_painter(l_cliff, func(ci: Node2D) -> void: _draw_parts(ci, "jet"))
	var l_ship := _node(_sky_root)
	_fpivot = _node(l_ship, ARC_P0)
	_fship = _make_ship(_fpivot, -SHIP_MID * SKY_SHIP_SCALE, SKY_SHIP_SCALE, false)
	_painter(l_ship, _draw_sea_fg)
	_painter(l_ship, _draw_splash)
	_painter(l_ship, func(ci: Node2D) -> void: _draw_parts(ci, "sky"))
	_sky_layers = [[l_sky, 0.2, 1.12, C], [l_cliff, 0.85, 1.0, C], [l_ship, 1.0, 1.0, C]]


# ------------------------------------------------------------------ G: the island
func _build_isle() -> void:
	_isle_root = _node(_world)
	var l_sky := _node(_isle_root)
	if _tex("qk_sky"):
		_spr(l_sky, _tex("qk_sky"))
	else:
		_fill(l_sky, Color("5e9be6"))
	_painter(l_sky, _draw_gulls.bind(1))
	var l_isle := _node(_isle_root)
	var isl := _spr(l_isle, _tex("qk_island"), ISLE_POS)
	isl.scale = Vector2(ISLE_SCALE, ISLE_SCALE)
	var l_sea := _node(_isle_root)
	_painter(l_sea, _draw_isle_sea)
	var l_ship := _node(_isle_root)
	_gship = _make_ship(l_ship, ISLE_SHIP - SHIP_MID * 0.24, 0.24, false)
	_painter(l_ship, _draw_isle_ship_water)
	_isle_layers = [[l_sky, 0.03, 1.12, C], [l_isle, 0.5, 1.0, C], [l_sea, 1.0, 1.0, C], [l_ship, 0.0, 1.0, C]]


func _show_shot(s: String) -> void:
	_shot = s
	_rail_root.visible = s == "rail"
	_pil_root.visible = s == "pillars"
	_cave_root.visible = s == "cave"
	_tun_root.visible = s == "tunnel"
	_side_root.visible = s == "side"
	_sky_root.visible = s == "sky"
	_isle_root.visible = s == "isle"


# ------------------------------------------------------------------ overlays
func _build_loc() -> void:
	_loc = _ctrl(_over)
	_loc.visible = false
	_badge(_loc, "SUBLEVEL B3", Style.AQUA, "THE MUDLARK", "morning, by the clock", Vector2(34, 74))
	_rattle_lbl = _title_lbl("rattle rattle...", 26, Color(1, 1, 1, 0.95), INK, 8, Vector2(3, 4))
	_rattle_lbl.pivot_offset = _rattle_lbl.get_minimum_size() * 0.5
	_rattle_lbl.rotation = deg_to_rad(-8.0)
	_rattle_lbl.modulate.a = 0.0
	_over.add_child(_rattle_lbl)


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
	var small := _title_lbl("TICK-TOCK...", 40, Color.WHITE, INK, 10, Vector2(4, 5))
	small.position = Vector2(520, 262)
	band.add_child(small)
	var fs := _fit("RIGHT ON SCHEDULE!", 92, 40, 860.0)
	var tl2 := _title_lbl("RIGHT ON SCHEDULE!", fs, SNAP_GREEN, SNAP_GREEN.darkened(0.35), 18, Vector2.ZERO, Color(0, 0, 0, 0))
	var tl := _title_lbl("RIGHT ON SCHEDULE!", fs, Style.GOLD, INK, 18, Vector2.ZERO, Color(0, 0, 0, 0))
	for l in [tl2, tl]:
		var lb: Label = l
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.size = Vector2(900, 130)
		lb.pivot_offset = Vector2(450, 65)
		band.add_child(lb)
	tl.position = Vector2(370, 300)
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
	# his line, on a slanted plate under the band
	var line := _ctrl(root)
	line.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var txt := "I only BORROWED that lake, my darlings!"
	var lfs := _fit(txt, 32, 20, 620.0)
	var lw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var plate := _slant(Vector2(lw + 70.0, 62), Color(0.05, 0.03, 0.1, 0.96), Style.GOLD, 3.0, 18.0, 8.0, 0, Color(INK, 0.95), Vector2(7, 7))
	line.add_child(plate)
	var ll := _title_lbl(txt, lfs, Color.WHITE, INK, 8, Vector2(3, 4), Color(SNAP_GREEN.darkened(0.4), 1.0))
	ll.position = Vector2(34, (62.0 - ll.get_minimum_size().y) * 0.5)
	plate.add_child(ll)
	line.position = Vector2(560, 560)
	line.rotation = deg_to_rad(-4.0)
	line.modulate.a = 0.0
	_sh = {"root": root, "dim": dim, "band": band, "cut": cut, "tl": tl, "tl2": tl2, "small": small, "por": por, "line": line, "foc": foc}


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
	# panel 1: the pocket watch
	var p1 := _ctrl(root)
	p1.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p1.size = Vector2(820, 300)
	p1.position = Vector2(-40, 44)
	var f1 := _slant(Vector2(820, 300), SNAP_GREEN.darkened(0.6), Color.WHITE, 5.0, 110.0, 0.0, 4, Color(INK, 0.95), Vector2(12, 12))
	f1.stripe_col = Color(SNAP_GREEN.lightened(0.2), 0.3)
	f1.refresh()
	p1.add_child(f1)
	var clip1 := Control.new()
	clip1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip1.clip_contents = true
	clip1.position = Vector2(60, 6)
	clip1.size = Vector2(700, 288)
	p1.add_child(clip1)
	var w := TextureRect.new()
	w.texture = _tex("qk_watch")
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	w.stretch_mode = TextureRect.STRETCH_SCALE
	w.size = Vector2(360, 400) * 0.82
	w.position = Vector2(290, -70)
	w.rotation = deg_to_rad(-6.0)
	clip1.add_child(w)
	_cpainter(w, _draw_watch_hands, Vector2(360, 400) * 0.82)
	var tick := _title_lbl("tick... tick...", 30, Color(1, 1, 1, 0.92), INK, 8, Vector2(3, 4))
	tick.position = Vector2(70, 200)
	tick.modulate.a = 0.0
	p1.add_child(tick)
	# panel 2: the detonator and the claw on the plunger
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
	_cpainter(clip, _draw_ecu_bg, Vector2(880, 360))
	var plunger := TextureRect.new()
	plunger.texture = _tex("qk_plunger")
	plunger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plunger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plunger.stretch_mode = TextureRect.STRETCH_SCALE
	plunger.size = Vector2(400, 470) * DET_SC
	clip.add_child(plunger)
	var det := TextureRect.new()
	det.texture = _tex("qk_detonator")
	det.mouse_filter = Control.MOUSE_FILTER_IGNORE
	det.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	det.stretch_mode = TextureRect.STRETCH_SCALE
	det.size = Vector2(520, 360) * DET_SC
	det.position = Vector2(330, 150)
	clip.add_child(det)
	var f2 := _slant(Vector2(880, 360), Color(0, 0, 0, 0), Color.WHITE, 5.0, 110.0, 0.0, 0, Color(0, 0, 0, 0))
	p2.add_child(f2)
	var sliver := _slant(Vector2(1500, 12), Style.YUZU, Color(0, 0, 0, 0), 0.0, 8.0, 0.0, 0, Color(INK, 0.9), Vector2(0, 5))
	sliver.position = Vector2(-120, 318)
	sliver.pivot_offset = Vector2(750, 6)
	sliver.rotation = deg_to_rad(-1.5)
	root.add_child(sliver)
	var click := _title_lbl("CLICK.", 70, Style.DANGER, INK, 14, Vector2(6, 7))
	click.position = Vector2(110, 470)
	click.pivot_offset = click.get_minimum_size() * 0.5
	click.rotation = deg_to_rad(-10.0)
	click.modulate.a = 0.0
	root.add_child(click)
	_ecu = {"root": root, "p1": p1, "p2": p2, "watch": w, "tick": tick, "plunger": plunger, "det": det, "sliver": sliver, "click": click}


## A huge hit word on a slanted plate (the drain's GLUG!, in other words).
func _build_bang(text: String, accent: Color) -> Dictionary:
	var root := _ctrl(_over)
	root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.38)
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
	var plate := _slant(Vector2(900, 236), Color(0.05, 0.02, 0.12, 0.97), accent, 6.0, 70.0, 0.0, 5,
		Color(accent.darkened(0.5), 0.95), Vector2(14, 16))
	plate.stripe_col = Color(accent, 0.25)
	plate.refresh()
	plate.position = Vector2(190, 242)
	plate.pivot_offset = Vector2(450, 118)
	rig.add_child(plate)
	var sliver := _slant(Vector2(1180, 14), Style.YUZU, Color(0, 0, 0, 0), 0.0, 10.0, 0.0, 0, Color(INK, 0.9), Vector2(0, 6))
	sliver.position = Vector2(50, 492)
	sliver.pivot_offset = Vector2(590, 7)
	rig.add_child(sliver)
	var fs := _fit(text, 170, 70, 860.0)
	var echo := _title_lbl(text, fs, Color(accent, 0.5), Color(0, 0, 0, 0), 0, Vector2.ZERO, Color(0, 0, 0, 0))
	var tl := _title_lbl(text, fs, Style.GOLD, INK, 24, Vector2(10, 12), accent.darkened(0.4))
	for l in [echo, tl]:
		var lb: Label = l
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.size = Vector2(1000, 260)
		lb.position = Vector2(140, 226)
		lb.pivot_offset = lb.size * 0.5
		rig.add_child(lb)
	return {"root": root, "rig": rig, "plate": plate, "tl": tl, "echo": echo, "sliver": sliver, "foc": foc}


func _build_reacts() -> void:
	for d in REACTS:
		var id: String = d[0]
		var expr: String = d[1]
		var line: String = d[2]
		var pos: Vector2 = d[3]
		var side: float = d[4]
		var line_above: bool = d[5]
		var extra: String = d[6]
		var col := Cast.color(id)
		var root := _ctrl(_over)
		root.visible = false
		var box := _ctrl(root)
		box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var sz := Vector2(420, 200)
		box.size = sz
		box.position = pos
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
		por.texture = Assets.portrait(id, expr)
		por.size = sz
		var uv_y := 168.0 if extra == "hat" else 122.0
		por.uv_rect = Rect2(40.0 / 480.0, uv_y / 600.0, 400.0 / 480.0, 190.0 / 600.0)
		var off: Array = Geometry2D.offset_polygon(Style.slant_poly(Rect2(Vector2.ZERO, sz), skew), -7.0, Geometry2D.JOIN_MITER)
		if off.size() > 0:
			por.frame = off[0]
		por.edge_col = Color(Style.GOLD, 0.95)
		por.wipe_dir = -side
		por.wipe = 0.0
		box.add_child(por)
		var r := {"id": id, "root": root, "box": box, "por": por, "side": side, "x": pos.x, "extra": extra, "t0": -100.0}
		_build_react_extra(r, sz)
		var tag := _name_tag(id, Cast.display_name(id), 22)
		tag.position = Vector2(8 if side < 0.0 else sz.x - tag.size.x - 30, sz.y - 22)
		box.add_child(tag)
		var fs := _fit(line, 27, 18, 400.0)
		var lbl := _title_lbl(line, fs, Color.WHITE, INK, 9, Vector2(4, 5), Color(col.darkened(0.4), 1.0))
		var lw := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
		lbl.position = Vector2(sz.x - lw - 30.0 if side < 0.0 else 40.0, -44.0 if line_above else sz.y + 14.0)
		lbl.pivot_offset = lbl.get_minimum_size() * 0.5
		lbl.rotation = deg_to_rad(-4.0)
		lbl.modulate.a = 0.0
		box.add_child(lbl)
		var mark := "..." if extra == "deadpan" else "!?"
		var bang := _title_lbl(mark, 64, Style.YUZU if extra != "deadpan" else Style.TEXT_DIM, INK, 14, Vector2(5, 6))
		bang.position = Vector2(sz.x - 90 if side < 0.0 else 4, 20)
		bang.pivot_offset = bang.get_minimum_size() * 0.5
		bang.rotation = deg_to_rad(12.0 * side)
		bang.modulate.a = 0.0
		box.add_child(bang)
		r["lbl"] = lbl
		r["bang"] = bang
		r["ly"] = lbl.position.y
		_reacts.append(r)


## The little extras that tell each reaction's joke without touching a portrait.
func _build_react_extra(r: Dictionary, sz: Vector2) -> void:
	var box: Control = r["box"]
	var root: Control = r["root"]
	match str(r["extra"]):
		"pots":
			var t := TextureRect.new()
			t.texture = _tex("qk_pots")
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_SCALE
			t.size = Vector2(300, 170) * 0.82
			t.position = Vector2(-70, sz.y - 96)
			box.add_child(t)
			r["prop"] = t
		"rope":
			_cpainter(box, _draw_rope_lash, sz)
		"catch":
			var mini: Array = []
			for k in 2:
				var cid: String = ["bramble", "fennel"][k]
				var holder := _ctrl(box)
				holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
				var msz := Vector2(170, 112)
				holder.size = msz
				holder.position = Vector2(-196 if k == 0 else -120, -8 + k * 122)
				holder.pivot_offset = msz * 0.5
				holder.rotation = deg_to_rad(-14.0 if k == 0 else 12.0)
				var mc := Cast.color(cid)
				var mfr := _slant(msz, mc.darkened(0.55), Color.WHITE, 4.0, 30.0, 0.0, 0, Color(INK, 0.95), Vector2(7, 7))
				holder.add_child(mfr)
				var mp := TC.CutPortrait.new()
				mp.texture = Assets.portrait(cid, "shock")
				mp.size = msz
				mp.uv_rect = Rect2(60.0 / 480.0, 110.0 / 600.0, 360.0 / 480.0, 236.0 / 600.0)
				var moff: Array = Geometry2D.offset_polygon(Style.slant_poly(Rect2(Vector2.ZERO, msz), 30.0), -5.0, Geometry2D.JOIN_MITER)
				if moff.size() > 0:
					mp.frame = moff[0]
				holder.add_child(mp)
				var mt := _name_tag(cid, Cast.display_name(cid), 15)
				mt.position = Vector2(14, msz.y - 14)
				holder.add_child(mt)
				holder.modulate.a = 0.0
				mini.append(holder)
			r["mini"] = mini
		"flash":
			_cpainter(box, _draw_photo_flash.bind(r), sz)
			var ck := _title_lbl("CLICK!", 30, Color.WHITE, INK, 8, Vector2(3, 4))
			ck.position = Vector2(sz.x - 150, -30)
			ck.rotation = deg_to_rad(10.0)
			ck.modulate.a = 0.0
			box.add_child(ck)
			r["click"] = ck
		"hat":
			var hat := TextureRect.new()
			hat.texture = _tex("qk_hat")
			hat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hat.stretch_mode = TextureRect.STRETCH_SCALE
			hat.size = Vector2(220, 150) * 1.1
			hat.pivot_offset = hat.size * 0.5
			hat.position = Vector2(1000, 40)
			hat.visible = false
			root.add_child(hat)
			r["hat"] = hat
		"maths":
			_cpainter(box, _draw_maths.bind(r), sz)


func _build_snaps() -> void:
	for i in 3:
		var l := _title_lbl("SNAP!" if i < 2 else "SNAP!!", 54, Style.GOLD, INK, 12, Vector2(5, 6), SNAP_GREEN.darkened(0.3))
		l.pivot_offset = l.get_minimum_size() * 0.5
		l.modulate.a = 0.0
		_over.add_child(l)
		_snap_lbls.append(l)


## The close-up the shear cuts to: rock scraping across the top of the forward stack.
func _build_skr() -> void:
	var root := _ctrl(_over)
	root.visible = false
	var rig := _ctrl(root)
	rig.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rig.size = Vector2(760, 330)
	rig.position = Vector2(270, 170)
	rig.pivot_offset = Vector2(380, 165)
	rig.rotation = deg_to_rad(-6.0)
	var bgp := _slant(Vector2(760, 330), Color(0.03, 0.04, 0.08, 1.0), Color(0, 0, 0, 0), 0.0, 90.0, 0.0, 0, Color(INK, 0.95), Vector2(14, 14))
	rig.add_child(bgp)
	var clip := Control.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	clip.size = Vector2(760, 330)
	rig.add_child(clip)
	_cpainter(clip, _draw_skr, Vector2(760, 330))
	var frm := _slant(Vector2(760, 330), Color(0, 0, 0, 0), Color.WHITE, 6.0, 90.0, 0.0, 0, Color(0, 0, 0, 0))
	rig.add_child(frm)
	var lbl := _title_lbl("SKRAAANG!!", 88, Style.GOLD, INK, 18, Vector2(8, 9), Style.DANGER.darkened(0.3))
	lbl.position = Vector2(300, 470)
	lbl.pivot_offset = lbl.get_minimum_size() * 0.5
	lbl.rotation = deg_to_rad(-8.0)
	lbl.modulate.a = 0.0
	root.add_child(lbl)
	_skr = {"root": root, "rig": rig, "lbl": lbl}


func _build_caption() -> void:
	_caption = _ctrl(_over)
	_caption.modulate.a = 0.0
	var l := Label.new()
	l.text = "(...the sky. A real one.)"
	l.add_theme_font_override("font", Style.italic_font())
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color("c8fff6"))
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(W, 60)
	l.position = Vector2(0, 286)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(l)


func _build_title() -> void:
	var root := _ctrl(_over)
	root.visible = false
	var dimr := ColorRect.new()
	dimr.color = Color(INK, 0.4)
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
	var fs := _fit("WARDEN'S REST", 100, 44, 1060.0)
	var tl := _title_lbl("WARDEN'S REST", fs, Style.GOLD, Style.BG_DARK, 16, Vector2(8, 8), Color(accent.darkened(0.25), 1.0))
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
	var sl := Style.label("sea air, sea views, and a prison next door!", 29, Style.BG_DARK, true)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sl.size = Vector2(W, 64)
	sl.position = Vector2(-x0, 0)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_b.add_child(sl)
	var tag := _name_tag("snapjaw", "- WARDEN SNAPJAW", 18)
	tag.position = Vector2(-x0 + 840, 70)
	band_b.add_child(tag)
	_title = {"root": root, "dim": dimr, "rig": rig, "a": band_a, "b": band_b, "st": sl_top, "sb": sl_bot, "tl": tl, "x0": x0, "bw": bw}


# ================================================================== the timeline
func _schedule() -> void:
	# ---- A  the tremor
	_at(0.0, _ev_open)
	_at(0.12, func() -> void: _anim(self, "_wipe_cover", 1.0, 2.0, 0.6, 1))
	_at(0.7, _ev_loc_in)
	_at(1.3, _ev_rattle.bind(0.55, 0.8))
	_at(2.2, _ev_flicker)
	_at(2.8, _ev_pebbles)
	_at(3.45, _ev_loc_out)
	_at(3.6, _ev_rattle2)
	_at(4.5, _ev_cup_slide)
	_at(5.2, func() -> void:
		_glitch(0.2, 1.0)
		_sfx("whoosh", 0.9, -6.0))
	# ---- B  right on schedule
	_at(5.4, _ev_shout_in)
	_at(5.6, _ev_shout_hit)
	_at(6.45, _ev_shout_line)
	_at(7.9, _ev_shout_out)
	_at(7.9, _ev_ecu_in)
	for i in 3:
		_at(8.3 + i * 0.5, _ev_tick.bind(i))
	_at(9.75, _ev_push)
	_at(10.05, _ev_pillars_in)
	for i in 4:
		_at(10.15 + i * 0.19, _ev_arm.bind(3 - i))
	_at(10.95, _ev_boom)
	# ---- C  the quake
	_at(11.05, _ev_quake_in)
	_at(11.2, _ev_bang_in.bind("rumble"))
	_at(12.3, _ev_bang_out.bind("rumble"))
	_at(11.4, func() -> void: _crack_go([0, 5]))
	_at(12.6, func() -> void: _crack_go([1, 4]))
	_at(14.1, func() -> void: _crack_go([2]))
	for i in 4:
		_at(12.5 + i * 1.1, _ev_react.bind(i))
	_at(13.0, func() -> void: _sfx("qk_crash", 0.9, -4.0))
	_at(15.2, func() -> void: _sfx("qk_crack", 1.1, -4.0))
	_at(16.4, func() -> void: _sfx("qk_quake", 0.92, -3.0))
	_at(17.3, _ev_react_out.bind([0, 1, 2, 3]))
	_at(17.6, _ev_big_fall)
	# ---- D  the wall gives way
	_at(18.0, _ev_wall_strain)
	_at(19.3, _ev_burst)
	_at(20.45, _ev_flood)
	_at(20.6, _ev_bang_out.bind("kakoom"))
	_at(22.7, _ev_lift)
	for i in 3:
		_at(23.4 + i * 0.75, _ev_snap.bind(i))
	_at(25.6, _ev_tunnel_open)
	_at(26.5, _ev_surge)
	_at(27.25, func() -> void:
		_anim(self, "_wipe_cover", 0.0, 1.0, 0.35, 3)
		_sfx("static", 1.1, -10.0))
	# ---- E1  the tunnel
	_at(27.6, _ev_tunnel_in)
	for k in 9:
		_at(27.9 + k * 0.62, _ev_rib_pass.bind(k))
	for i in 4:
		_at(28.8 + i * 1.1, _ev_react.bind(4 + i))
	_at(33.0, _ev_react_out.bind([4, 5, 6, 7]))
	_at(33.35, func() -> void:
		_anim(self, "_wipe_cover", 0.0, 1.0, 0.3, 3)
		_sfx("static", 1.2, -10.0))
	# ---- E2  side on, the low arch
	_at(33.7, _ev_side_in)
	_at(35.0, _ev_arch_looms)
	_at(35.9, _ev_shear)
	_at(36.85, _ev_shear_out)
	_at(37.3, _ev_light_ahead)
	_at(38.6, _ev_whiteout)
	# ---- F  daylight
	_at(39.6, _ev_sky_in)
	_at(42.6, _ev_landing)
	_at(43.8, _ev_bang_out.bind("sploosh"))
	_at(44.4, _ev_quiet)
	_at(45.3, func() -> void: _anim(_caption, "modulate:a", 0.0, 1.0, 0.8, 1))
	_at(47.2, func() -> void: _anim(_caption, "modulate:a", 1.0, 0.0, 0.5, 1))
	# ---- G  the island
	_at(47.8, _ev_isle_in)
	_at(50.5, _ev_title_in)
	_at(50.72, _ev_title_hit)
	_at(52.7, _ev_title_out)
	_at(52.9, func() -> void:
		_anim(self, "_cam_z", 1.0, 1.07, 1.5, 1)
		_anim(self, "_cam_c", _cam_c, Vector2(560, 340), 1.5, 1))
	_at(53.9, func() -> void: _anim(self, "_lb", _lb, 0.0, 0.6, 1))
	# ---- H  out
	_at(54.3, func() -> void:
		_anim(self, "_wipe_cover", 0.0, 1.0, 0.35, 3)
		_sfx("static", 1.2, -12.0))
	_at(54.65, _ev_final)


func _music_stop(fade: float) -> void:
	_music_id = ""
	if not _ff:
		Audio.stop_music(fade)


# ------------------------------------------------------------------ A
func _ev_open() -> void:
	_show_shot("rail")
	_put("_wipe_cover", 1.0)
	_anim(self, "_lb", 0.0, 1.0, 0.6, 2)
	_put("_cam_roll", 0.0)
	_anim(self, "_cam_c", Vector2(600, 350), Vector2(690, 372), 5.4, 1)
	_anim(self, "_cam_z", 1.0, 1.1, 5.4, 1)
	_music("tension", 0.8)
	_sfx("dr_drip", 1.0, -6.0)


func _ev_loc_in() -> void:
	_loc.visible = true
	_anim(_loc, "position:x", -560.0, 0.0, 0.26, 4)
	_sfx("whoosh", 1.0, -6.0)


func _ev_loc_out() -> void:
	_anim(_loc, "position:x", 0.0, -600.0, 0.22, 6)


func _ev_rattle(amt: float, dur: float) -> void:
	_anim(self, "_cup_shake", amt, 0.0, dur, 0)
	_sfx("qk_rattle", 1.0, -2.0)
	_anim(_rattle_lbl, "modulate:a", 0.0, 1.0, 0.08, 0)
	_anim(_rattle_lbl, "scale", Vector2(1.8, 1.8), Vector2.ONE, 0.18, 5)
	_anim_then(_rattle_lbl, "modulate:a", 1.0, 0.0, 0.3, 0, 1.0)


func _ev_flicker() -> void:
	_anim(self, "_flicker", 1.0, 0.0, 3.0, 0)
	_anim(self, "_dim", 0.0, 0.32, 0.25, 2)
	_anim_then(self, "_dim", 0.32, 0.12, 1.6, 1, 0.5)
	_sfx("dr_lantern", 0.6, -10.0)


func _ev_pebbles() -> void:
	_anim(self, "_pebble_rate", 1.0, 0.25, 2.4, 1)
	_sfx("qk_pebbles", 1.0, -3.0)


func _ev_rattle2() -> void:
	_anim(self, "_cup_shake", 1.0, 0.35, 1.5, 0)
	_anim(self, "_rumble", 0.0, 2.4, 0.8, 1)
	_anim(self, "_pebble_rate", _pebble_rate, 1.4, 0.6, 1)
	_kick(4.0)
	_sfx("qk_tremor", 1.0, 0.0)
	_sfx("qk_rattle", 0.9, 0.0)
	var lt := _cup_screen() + Vector2(-70, -150)
	_rattle_lbl.text = "RATTLE RATTLE!"
	_rattle_lbl.position = lt
	_anim(_rattle_lbl, "modulate:a", 0.0, 1.0, 0.06, 0)
	_anim(_rattle_lbl, "scale", Vector2(2.2, 2.2), Vector2.ONE, 0.16, 5)
	_anim_then(_rattle_lbl, "modulate:a", 1.0, 0.0, 0.25, 0, 1.3)
	for i in 8:
		_emit("rail", CUP_AT + Vector2(_rng.randf_range(-20, 20), -74), Vector2(_rng.randf_range(-70, 70), _rng.randf_range(-200, -100)),
			_rng.randf_range(0.4, 0.7), _rng.randf_range(2.0, 3.2), Color("b8742a"), 9, 900.0, 0.2)


func _ev_cup_slide() -> void:
	_anim(self, "_cup_slide", 0.0, 64.0, 0.7, 2)
	_kick(3.0)
	_sfx("qk_rattle", 0.8, -2.0)


func _cup_screen() -> Vector2:
	var l: Node2D = _rail_layers[2][0]
	return l.get_global_transform() * (CUP_AT + Vector2(_cup_slide, 0)) - _shaker.position


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
	_put("_rumble", 0.0)
	_sfx("shout", 0.9, 0.0)
	_sfx("qk_watch", 1.0, -6.0)
	_music("snapjaw", 0.3)


func _ev_shout_hit() -> void:
	_kick(16.0)
	_flash(Color.WHITE, 0.6, 0.3)
	_speed(Vector2(820, 340), 0.45, Color(1, 1, 1, 0.45), 42, 280.0)
	_glitch(0.16, 0.9)


func _ev_shout_line() -> void:
	var l: Control = _sh["line"]
	_anim(l, "modulate:a", 0.0, 1.0, 0.08, 0)
	_anim(l, "position:x", 900.0, 560.0, 0.22, 4)
	_sfx("hx_laugh", 1.1, -8.0)


func _ev_shout_out() -> void:
	if _fx_ok() and not Fx.skip_heavy():
		Fx.shatter(_fxl, 0.55, Vector2(800, 350))
	_sfx("break", 1.15, -9.0)
	(_sh["root"] as Control).visible = false


func _ev_ecu_in() -> void:
	var root: Control = _ecu["root"]
	root.visible = true
	_show_shot("black")
	_anim(_ecu["p1"], "position:x", -1000.0, -40.0, 0.24, 4)
	_anim(_ecu["p2"], "position:x", W + 80.0, 440.0, 0.24, 4, 0.06)
	_anim(_ecu["sliver"], "scale:x", 0.0, 1.0, 0.2, 4, 0.1)
	_anim(self, "_lb", _lb, 0.0, 0.2, 2)
	_anim(_ecu["tick"], "modulate:a", 0.0, 1.0, 0.3, 0, 0.35)
	(_ecu["p2"] as Control).position.x = W + 80.0
	(_ecu["sliver"] as Control).scale.x = 0.0
	_put("_minute", 57.0)
	_put("_push_k", 0.0)
	_sfx("whoosh", 0.9, -4.0)


func _ev_tick(i: int) -> void:
	_anim(self, "_minute", 57.0 + i, 58.0 + i, 0.1, 5)
	_kick(2.0 + i * 1.5)
	if i == 2:
		_flash(Style.GOLD, 0.25, 0.25)
		_sfx("hx_sting", 1.4, -12.0)
		_anim(_ecu["tick"], "modulate:a", 1.0, 0.0, 0.25, 0, 0.2)


func _ev_push() -> void:
	_anim(self, "_push_k", 0.0, 1.0, 0.12, 6)
	var c: Label = _ecu["click"]
	_anim(c, "modulate:a", 0.0, 1.0, 0.04, 0)
	_anim(c, "scale", Vector2(2.4, 2.4), Vector2.ONE, 0.12, 4)
	_at_late(0.1, func() -> void:
		_kick(14.0)
		_flash(Color.WHITE, 0.4, 0.2)
		_speed(Vector2(900, 540), 0.4, Color(1, 1, 1, 0.45), 36, 160.0))
	_sfx("qk_click", 1.0, 0.0)


func _ev_pillars_in() -> void:
	(_ecu["root"] as Control).visible = false
	_show_shot("pillars")
	_put("_cam_roll", 0.03)
	_anim(self, "_cam_c", C, Vector2(380, 420), 0.95, 3)
	_anim(self, "_cam_z", 1.0, 1.4, 0.95, 3)
	_anim(self, "_lb", _lb, 1.0, 0.2, 2)
	_glitch(0.22, 1.0)
	_flash(Style.DANGER, 0.2, 0.2)


func _ev_arm(i: int) -> void:
	_armed[i] = _ev_time
	_sfx("qk_beep", 1.0 + (3 - i) * 0.1, -2.0)
	_kick(2.0 + (3 - i) * 1.5)


func _ev_boom() -> void:
	_flash(Color.WHITE, 1.0, 0.5)
	_hitstop(0.1)
	_kick(30.0)
	_glitch(0.3, 1.2)
	_sfx("boom", 0.7, 0.0)
	_sfx("hx_slam", 0.8, -4.0)


# ------------------------------------------------------------------ C
func _ev_quake_in() -> void:
	_show_shot("cave")
	_put("_cam_roll", 0.0)
	_put("_quake", 1.0)
	_anim(self, "_cam_c", Vector2(640, 380), Vector2(660, 362), 6.8, 1)
	_anim(self, "_cam_z", 1.1, 1.0, 6.8, 1)
	_anim(self, "_rumble", 9.0, 4.0, 2.2, 2)
	_kick(30.0)
	_music("trial_climax", 0.15)
	_sfx("qk_quake", 1.0, 0.0)
	_sfx("boom", 0.6, -2.0)
	for i in 50:
		_emit("cave", Vector2(_rng.randf_range(0, W), _rng.randf_range(40, 110)), Vector2(_rng.randf_range(-40, 40), _rng.randf_range(0, 120)),
			_rng.randf_range(0.8, 1.6), _rng.randf_range(2.0, 4.5), Color("3a3a4a"), 3, 900.0, 0.1)


func _ev_bang_in(id: String) -> void:
	var b: Dictionary = _bangs[id]
	var root: Control = b["root"]
	root.visible = true
	root.modulate.a = 1.0
	(b["rig"] as Control).position.x = 0.0
	_anim(b["plate"], "scale", Vector2(0.0, 1.0), Vector2.ONE, 0.13, 4)
	_anim(b["sliver"], "scale:x", 0.0, 1.0, 0.16, 4, 0.04)
	_anim(b["tl"], "scale", Vector2(2.6, 2.6), Vector2.ONE, 0.16, 5, 0.05)
	_anim(b["tl"], "modulate:a", 0.0, 1.0, 0.05, 0, 0.05)
	_anim(b["echo"], "scale", Vector2.ONE, Vector2(1.7, 1.7), 0.45, 4, 0.2)
	_anim(b["echo"], "modulate:a", 1.0, 0.0, 0.45, 0, 0.2)
	(b["tl"] as Label).modulate.a = 0.0
	(b["echo"] as Label).modulate.a = 0.0
	(b["sliver"] as Control).scale.x = 0.0
	_hitstop(0.22, 0.09)
	_kick(24.0)
	_flash(Color.WHITE, 0.7, 0.35)
	_speed(C, 0.55, Color(1, 1, 1, 0.5), 46, 300.0)
	_glitch(0.22, 1.1)


func _ev_bang_out(id: String) -> void:
	var b: Dictionary = _bangs[id]
	_anim(b["rig"], "position:x", 0.0, W * 1.2, 0.22, 6)
	_anim(b["root"], "modulate:a", 1.0, 0.0, 0.22, 0)
	_glitch(0.2, 0.8)
	_sfx("whoosh", 1.2, -6.0)


func _crack_go(ids: Array) -> void:
	for i in ids:
		_crack_t0[int(i)] = _ev_time
	_sfx("qk_crack", _rng.randf_range(0.9, 1.15), -3.0)


func _ev_react(i: int) -> void:
	var r: Dictionary = _reacts[i]
	var root: Control = r["root"]
	root.visible = true
	r["t0"] = _ev_time
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
	match str(r["extra"]):
		"catch":
			for k in 2:
				var h: Control = r["mini"][k]
				var hy := -8.0 + k * 122.0
				_anim(h, "modulate:a", 0.0, 1.0, 0.08, 0, 0.3 + k * 0.12)
				_anim(h, "position:y", hy - 260.0, hy, 0.3, 5, 0.3 + k * 0.12)
				_at_late(0.6 + k * 0.12, func() -> void:
					_kick(6.0)
					_sfx("hx_thud", 1.2, -10.0))
		"hat":
			var hat: TextureRect = r["hat"]
			hat.visible = true
			var start := Vector2(x + 150.0, 36.0)
			_anim(hat, "position", start, start + Vector2(-380, -190), 1.7, 2, 0.32)
			_anim(hat, "rotation", 0.0, -4.2, 1.7, 2, 0.32)
			hat.position = start
			hat.rotation = 0.0
			_at_late(0.32, func() -> void: _sfx("whoosh", 1.5, -6.0))
		"flash":
			for k in 3:
				_at_late(0.3 + k * 0.28, func() -> void: _sfx("qk_shutter", 1.0 + k * 0.05, -4.0))
			var ck: Label = r["click"]
			_anim(ck, "modulate:a", 0.0, 1.0, 0.05, 0, 0.3)
			_anim(ck, "scale", Vector2(1.8, 1.8), Vector2.ONE, 0.14, 5, 0.3)
		"scream":
			_sfx("gasp", 1.5, -4.0)
		"pots":
			_at_late(0.3, func() -> void: _sfx("dr_chain", 1.6, -12.0))
	_at_late(0.2, func() -> void:
		_kick(9.0)
		_flash(Color.WHITE, 0.25, 0.16)
		_speed(Vector2(x + 220.0, (r["box"] as Control).position.y + 110.0), 0.35, Color(1, 1, 1, 0.3), 26, 140.0))
	_sfx("whoosh", 1.1 + (i % 4) * 0.05, -5.0)
	if str(r["extra"]) != "deadpan":
		_sfx("gasp", 0.95 + (i % 4) * 0.08, -7.0)


func _ev_react_out(ids: Array) -> void:
	for i in ids:
		var r: Dictionary = _reacts[int(i)]
		var side: float = r["side"]
		var x: float = r["x"]
		_anim(r["box"], "position:x", x, x + side * 760.0, 0.2, 6)
	_blade(Vector2(-40, 560), Vector2(W + 40, 160))
	_glitch(0.22, 0.9)
	_sfx("whoosh", 1.3, -4.0)
	_at_late(0.25, func() -> void:
		for i in ids:
			((_reacts[int(i)] as Dictionary)["root"] as Control).visible = false)


func _ev_big_fall() -> void:
	_falls.append({"x": 900.0, "y": -80.0, "vy": 200.0, "rot": 0.1, "vr": 0.4, "s": 1.5, "floor": 640.0, "front": true, "done": false})
	_sfx("whoosh", 0.6, -3.0)


# ------------------------------------------------------------------ D
func _ev_wall_strain() -> void:
	_anim(self, "_cam_c", _cam_c, Vector2(760, 340), 1.3, 1)
	_anim(self, "_cam_z", _cam_z, 1.06, 1.3, 1)
	_crack_go([3])
	_anim(self, "_jets_k", 0.0, 1.0, 1.2, 3)
	_anim(self, "_quake", 1.0, 0.45, 1.2, 1)
	_sfx("dr_steam", 0.7, -2.0)


func _ev_burst() -> void:
	_put("_burst_k", 0.0)
	_anim(self, "_burst_k", 0.0, 1.0, 0.7, 4)
	_put("_jets_k", 0.0)
	_anim(self, "_rumble", 7.0, 3.0, 2.0, 2)
	_kick(34.0)
	_ev_bang_in("kakoom")
	_flash(Color("bff8ff"), 0.8, 0.4)
	_sfx("qk_burst", 1.0, 0.0)
	for i in 9:
		var a := _rng.randf_range(PI * 0.65, PI * 1.2)
		var sp := _rng.randf_range(420.0, 900.0)
		_boulders.append({"p": BURST_C + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-30, 30)), "v": Vector2(cos(a), sin(a)) * sp,
			"r": _rng.randf() * TAU, "vr": _rng.randf_range(-6, 6), "s": _rng.randf_range(0.35, 0.8)})
	for i in 90:
		var a2 := _rng.randf_range(PI * 0.55, PI * 1.25)
		var sp2 := _rng.randf_range(300.0, 1200.0)
		_emit("cave", BURST_C + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-40, 40)), Vector2(cos(a2), sin(a2)) * sp2,
			_rng.randf_range(0.5, 1.3), _rng.randf_range(4.0, 11.0), WATER[_rng.randi() % 4], 0, 900.0, 0.4)


func _ev_flood() -> void:
	_anim(self, "_flood_x", 1120.0, -300.0, 2.4, 1)
	_anim(self, "_front_h", 240.0, 60.0, 2.4, 1)
	_anim(self, "_flood_y", 660.0, 470.0, 2.0, 2)
	_anim_then(self, "_flood_y", 470.0, FLOOD_TOP, 2.4, 1, 2.0)
	_anim(self, "_cam_c", _cam_c, Vector2(650, 372), 2.2, 1)
	_anim(self, "_cam_z", _cam_z, 1.02, 2.2, 1)
	_sfx("qk_flood", 1.0, 0.0)


func _ev_lift() -> void:
	_kick(10.0)
	_sfx("dr_creak", 0.9, 0.0)
	_sfx("dr_horn", 0.85, -4.0)
	for i in 30:
		var x := SHIP_G_POS.x + _rng.randf_range(80.0, 520.0)
		_emit("cave", Vector2(x, 470.0), Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-260, -120)), _rng.randf_range(0.4, 0.8),
			_rng.randf_range(3.0, 7.0), Color("4a3626"), 3, 900.0, 0.3)


func _ev_snap(i: int) -> void:
	_rope_snap[i] = _ev_time
	_hitstop(0.12, 0.05 if i == 2 else 0.0)
	_kick(10.0 + i * 4.0)
	_flash(Color.WHITE, 0.3, 0.18)
	_sfx("qk_snap", 1.0 + i * 0.07, 0.0)
	var mid := _rope_mid_screen(i)
	var l: Label = _snap_lbls[i]
	l.position = mid - l.get_minimum_size() * 0.5 + Vector2(0, -80)
	var rots: Array = [-12.0, 8.0, -6.0]
	l.rotation = deg_to_rad(float(rots[i]))
	_anim(l, "modulate:a", 0.0, 1.0, 0.04, 0)
	_anim(l, "scale", Vector2(2.4, 2.4), Vector2.ONE, 0.14, 5)
	_anim_then(l, "modulate:a", 1.0, 0.0, 0.25, 0, 0.55)
	_speed(mid, 0.3, Color(1, 1, 1, 0.35), 24, 120.0)


func _ev_tunnel_open() -> void:
	_anim(self, "_tunnel_k", 0.0, 1.0, 0.9, 4)
	_anim(self, "_cam_c", _cam_c, Vector2(520, 350), 0.9, 1)
	_kick(18.0)
	_sfx("qk_crash", 0.75, 0.0)
	_sfx("qk_crack", 0.8, -2.0)
	for i in 40:
		_emit("cave", TUNNEL_L + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-80, 80)), Vector2(_rng.randf_range(-80, 200), _rng.randf_range(-200, 100)),
			_rng.randf_range(0.5, 1.2), _rng.randf_range(3.0, 7.0), Color("2a2a3a"), 3, 900.0, 0.2)


func _ev_surge() -> void:
	_anim(self, "_ship_dx", 0.0, -420.0, 0.9, 3)
	_anim(self, "_ship_tilt", 0.0, -0.08, 0.9, 3)
	_anim(self, "_cam_z", _cam_z, 1.45, 0.85, 3)
	_anim(self, "_cam_c", _cam_c, Vector2(330, 300), 0.85, 3)
	_speed(Vector2(260, 330), 0.7, Color(1, 1, 1, 0.45), 44, 200.0)
	_glitch(0.2, 0.8)
	_sfx("qk_whoosh", 0.7, 0.0)
	_sfx("dr_roar", 1.1, -2.0)


# ------------------------------------------------------------------ E
func _ev_tunnel_in() -> void:
	_show_shot("tunnel")
	_put("_cam_c", C)
	_put("_cam_z", 1.0)
	_anim(self, "_wipe_cover", 1.0, 2.0, 0.35, 2)
	_put("_tun_v", 15.0)
	_put("_rumble", 2.6)
	_put("_quake", 0.0)
	_anim(self, "_lb", _lb, 1.0, 0.3, 2)
	_sfx("qk_rush", 1.0, 0.0)
	_speed(BOW_VP, 0.6, Color(1, 1, 1, 0.4), 44, 160.0)


func _ev_rib_pass(k: int) -> void:
	_sfx("qk_whoosh", 0.9 + float(k % 3) * 0.12, -9.0)
	if k % 2 == 0:
		_speed(BOW_VP, 0.4, Color(0.6, 1, 0.95, 0.3), 36, 200.0)


func _ev_side_in() -> void:
	_show_shot("side")
	_put("_cam_c", C)
	_put("_cam_z", 1.0)
	_put("_cam_roll", 0.0)
	_anim(self, "_wipe_cover", 1.0, 2.0, 0.35, 2)
	_put("_side_speed", 1.0)
	_put("_rumble", 2.0)
	_anim(self, "_wheel_v", -6.0, -15.0, 1.2, 2)
	_sfx("qk_rush", 0.95, -2.0)
	_sfx("dr_creak", 1.2, -4.0)


func _ev_arch_looms() -> void:
	_anim(self, "_arch_x", -700.0, 110.0, 0.9, 1)
	_sfx("hx_sting", 0.9, -6.0)
	_sfx("dr_horn", 1.05, -6.0)


func _ev_shear() -> void:
	_cut_mat.set_shader_parameter("cut", 1.0)
	_anim(self, "_arch_x", 110.0, 1900.0, 0.95, 0)
	var root: Control = _skr["root"]
	root.visible = true
	_anim(_skr["rig"], "position:x", -900.0, 270.0, 0.16, 4)
	_anim(self, "_skr_k", 0.0, 1.0, 0.9, 0)
	var l: Label = _skr["lbl"]
	_anim(l, "modulate:a", 0.0, 1.0, 0.04, 0, 0.12)
	_anim(l, "scale", Vector2(2.6, 2.6), Vector2.ONE, 0.16, 5, 0.12)
	_hitstop(0.18, 0.08)
	_kick(26.0)
	_flash(Color("ffe9a0"), 0.6, 0.3)
	_sfx("qk_scrape", 1.0, 0.0)
	# the sheared top tumbles off behind the ship
	var sn: Node2D = _sship["node"]
	_piece_on = true
	_piece_p = sn.position + (STACK_ORIGIN + STACK_SIZE * 0.5) * SIDE_SCALE
	_piece_v = Vector2(900, -420)
	_piece_r = 0.0
	for i in 40:
		_emit("side", sn.position + Vector2(STACK_X[0], 236) * SIDE_SCALE, Vector2(_rng.randf_range(100, 900), _rng.randf_range(-500, 100)),
			_rng.randf_range(0.2, 0.6), _rng.randf_range(1.5, 3.5), Color("ffd27a"), 5, 600.0, 0.5)


func _ev_shear_out() -> void:
	_anim(_skr["rig"], "position:x", 270.0, W + 200.0, 0.2, 6)
	_anim(_skr["lbl"], "modulate:a", 1.0, 0.0, 0.2, 0)
	_glitch(0.18, 0.8)
	_sfx("whoosh", 1.2, -5.0)
	_at_late(0.22, func() -> void: (_skr["root"] as Control).visible = false)


func _ev_light_ahead() -> void:
	_anim(self, "_glow_left", 0.0, 1.0, 1.6, 3)
	_sfx("qk_rise", 1.0, -2.0)


func _ev_whiteout() -> void:
	_anim(self, "_white", 0.0, 1.0, 0.95, 3)
	_anim(self, "_rumble", _rumble, 0.0, 0.9, 1)


# ------------------------------------------------------------------ F
func _ev_sky_in() -> void:
	_show_shot("sky")
	_put("_white", 1.0)
	_anim(self, "_white", 1.0, 0.0, 0.8, 2)
	_music_stop(0.3)
	_put("_arc_k", 0.0)
	_anim(self, "_arc_k", 0.0, 1.0, 3.0, 0)
	_put("_jet_k", 1.0)
	_anim(self, "_jet_k", 1.0, 0.35, 6.0, 1)
	_put("_cam_roll", 0.0)
	_anim(self, "_cam_c", Vector2(840, 340), Vector2(560, 390), 3.0, 1)
	_anim(self, "_cam_z", 1.12, 1.04, 3.0, 1)
	_put("_rumble", 3.0)
	_anim(self, "_rumble", 3.0, 0.0, 1.5, 1)
	_put("_wheel_v", -9.0)
	_sfx("qk_burst", 1.25, -6.0)
	_sfx("qk_whoosh", 0.6, -2.0)


func _ev_landing() -> void:
	_landed = true
	_splash_t = _ev_time
	_ev_bang_in("sploosh")
	_hitstop(0.25, 0.1)
	_kick(32.0)
	_sfx("qk_splash", 1.0, 0.0)
	_anim(self, "_wheel_v", _wheel_v, -1.0, 2.0, 1)
	for i in 120:
		var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
		var sp := _rng.randf_range(250.0, 1100.0)
		_emit("sky", Vector2(ARC_P2.x + _rng.randf_range(-120, 120), SEA_F), Vector2(cos(a) * sp * 0.7, sin(a) * sp), _rng.randf_range(0.7, 1.8),
			_rng.randf_range(3.0, 9.0), WATER[_rng.randi() % 4], 0, 900.0, 0.2)


func _ev_quiet() -> void:
	_sfx("qk_waves", 1.0, -2.0)
	_sfx("qk_gulls", 1.0, 0.0)
	_anim(self, "_cam_c", _cam_c, Vector2(600, 250), 3.4, 1)
	_anim(self, "_cam_z", _cam_z, 1.0, 3.4, 1)


# ------------------------------------------------------------------ G
func _ev_isle_in() -> void:
	_show_shot("isle")
	_flash(Color.WHITE, 0.35, 0.4)
	_put("_cam_roll", 0.0)
	_put("_cam_z", 1.0)
	_anim(self, "_cam_c", Vector2(3160, 360), Vector2(560, 360), 2.6, 2)
	_sfx("qk_waves", 0.95, -5.0)
	_sfx("qk_gulls", 1.1, -4.0)


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
	_music("snapjaw", 0.6)


func _ev_title_hit() -> void:
	_kick(9.0)
	_flash(Color.WHITE, 0.4, 0.3)
	_speed(C, 0.5, Color(1, 1, 1, 0.3), 40, 280.0)
	_blade(Vector2(-40, 404), Vector2(W + 40, 248), Color(Style.GOLD, 0.9), 10.0)
	if _fx_ok():
		Fx.splash(_fxl, Vector2(140, 330), Style.AQUA, 14, 200.0, 0.7)
		Fx.splash(_fxl, Vector2(1140, 300), Style.AQUA, 14, 200.0, 0.7)
	_sfx("gavel", 0.8, -4.0)


func _ev_title_out() -> void:
	var x0: float = _title["x0"]
	var bw: float = _title["bw"]
	_anim(_title["a"], "position:x", x0, x0 + bw + 200.0, 0.2, 6)
	_anim(_title["st"], "position:x", x0, x0 + bw + 200.0, 0.2, 6)
	_anim(_title["b"], "position:x", x0, x0 - bw - 200.0, 0.2, 6)
	_anim(_title["sb"], "position:x", x0, x0 - bw - 200.0, 0.2, 6)
	_anim(_title["dim"], "modulate:a", 1.0, 0.0, 0.2, 0)
	_sfx("whoosh", 1.25, -6.0)


func _ev_final() -> void:
	var t: Texture2D = null
	for p in SHORE_BGS:
		t = Assets.svg(str(p))
		if t != null:
			break
	if t == null:
		t = Assets.prop("qk_shore")
	if t != null:
		_final.texture = t
		_final.visible = true
	_anim(self, "_wipe_cover", 1.0, 2.0, 0.5, 2)


# ================================================================== simulation
func _simulate(dt: float) -> void:
	_bob += dt
	_wheel_ang += _wheel_v * dt
	_travel += _tun_v * dt
	_scroll += _side_speed * dt
	match _shot:
		"rail":
			_emit_acc += dt
			while _emit_acc > 0.05:
				_emit_acc -= 0.05
				if _rng.randf() < _pebble_rate * 0.9:
					_emit("rail_far", Vector2(_rng.randf_range(80, 1200), _rng.randf_range(60, 110)), Vector2(_rng.randf_range(-10, 10), 40.0),
						_rng.randf_range(0.9, 1.6), _rng.randf_range(1.5, 3.0), Color("6a6478"), 3, 700.0, 0.0)
				if _rng.randf() < _pebble_rate * 0.35:
					_emit("rail", Vector2(_rng.randf_range(0, W), -20.0), Vector2(_rng.randf_range(-30, 30), 80.0),
						_rng.randf_range(0.8, 1.2), _rng.randf_range(3.0, 6.0), Color("4a4458"), 3, 1300.0, 0.0)
		"cave":
			_sim_cave(dt)
		"side":
			if _piece_on:
				_piece_v.y += 1500.0 * dt
				_piece_p += _piece_v * dt
				_piece_r += 7.0 * dt
				if _piece_p.y > SIDE_WL + 20.0:
					_piece_on = false
					for i in 24:
						_emit("side", Vector2(_piece_p.x, SIDE_WL), Vector2(_rng.randf_range(-200, 200), _rng.randf_range(-500, -150)),
							_rng.randf_range(0.4, 0.8), _rng.randf_range(3.0, 7.0), WATER[_rng.randi() % 4], 0, 1300.0, 0.2)
					if not _ff:
						Audio.sfx("splash", 0.8, -4.0)
			_emit_acc += dt
			while _emit_acc > 0.04:
				_emit_acc -= 0.04
				_emit_side_tick()
		"tunnel":
			_emit_acc += dt
			while _emit_acc > 0.05:
				_emit_acc -= 0.05
				var a := _rng.randf() * TAU
				_emit("tun", BOW_VP + Vector2.from_angle(a) * 40.0, Vector2.from_angle(a) * _rng.randf_range(500, 1100), 0.8,
					_rng.randf_range(1.5, 3.0), Color(0.7, 1.0, 1.0, 0.7), 0, 0.0, -1.2)
		"sky":
			_emit_acc += dt
			while _emit_acc > 0.05:
				_emit_acc -= 0.05
				if _jet_k > 0.1:
					var s := _rng.randf()
					_emit("jet", _jet_at(s) + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-20, 20)), Vector2(_rng.randf_range(-300, -80), _rng.randf_range(-160, 60)),
						_rng.randf_range(0.5, 1.0), _rng.randf_range(3.0, 7.0), WATER[_rng.randi() % 4], 0, 700.0, 0.3)
				if _arc_k > 0.0 and _arc_k < 1.0:
					_emit("sky", _fpivot.position + Vector2(_rng.randf_range(-80, 80), _rng.randf_range(10, 60)), Vector2(_rng.randf_range(-60, 60), _rng.randf_range(0, 120)),
						_rng.randf_range(0.5, 1.0), _rng.randf_range(2.0, 5.0), WATER[_rng.randi() % 4], 0, 900.0, 0.1)


func _sim_cave(dt: float) -> void:
	# falling stalactites while the quake is on
	if _quake > 0.05 and _burst_k <= 0.0:
		_fall_acc += dt * _quake * 3.2
		while _fall_acc > 1.0:
			_fall_acc -= 1.0
			var fy := _rng.randf_range(350.0, 700.0)
			_falls.append({"x": _rng.randf_range(60.0, 1220.0), "y": _rng.randf_range(50.0, 100.0), "vy": 0.0, "rot": _rng.randf_range(-0.2, 0.2),
				"vr": _rng.randf_range(-0.6, 0.6), "s": 0.35 + 0.55 * (fy - 330.0) / 390.0, "floor": fy, "front": false, "done": false})
	for f in _falls:
		var d: Dictionary = f
		if bool(d["done"]):
			continue
		var vy: float = float(d["vy"]) + 1500.0 * dt
		d["vy"] = vy
		d["y"] = float(d["y"]) + vy * dt
		d["rot"] = float(d["rot"]) + float(d["vr"]) * dt
		if float(d["y"]) >= float(d["floor"]):
			d["done"] = true
			var p := Vector2(float(d["x"]), float(d["floor"]))
			var space := "front" if bool(d["front"]) else "cave"
			var s: float = d["s"]
			for i in int(14 + 10 * s):
				var a := _rng.randf_range(-PI * 0.9, -PI * 0.1)
				var sp := _rng.randf_range(80.0, 380.0) * s
				_emit(space, p, Vector2(cos(a) * sp, sin(a) * sp), _rng.randf_range(0.4, 0.9), _rng.randf_range(2.0, 6.0) * s, Color("2c3448"), 3, 900.0, 0.2)
			for i in 4:
				_emit(space, p + Vector2(_rng.randf_range(-30, 30) * s, -10), Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-60, -20)),
					_rng.randf_range(1.2, 2.0), _rng.randf_range(30.0, 60.0) * s, Color(0.55, 0.5, 0.55, 0.35), 1, -10.0, 0.6, 40.0)
			if bool(d["front"]):
				_kick(22.0)
				if not _ff:
					Audio.sfx("qk_crash", 0.8, 0.0)
			elif s > 0.7 and _rng.randf() < 0.5 and not _ff:
				Audio.sfx("qk_crash", _rng.randf_range(0.9, 1.2), -8.0)
	if _falls.size() > 60:
		_falls = _falls.slice(_falls.size() - 60)
	# dust raining from the ceiling
	_emit_acc += dt
	while _emit_acc > 0.06:
		_emit_acc -= 0.06
		if _quake > 0.05:
			_emit("cave", Vector2(_rng.randf_range(0, W), _rng.randf_range(60, 100)), Vector2(_rng.randf_range(-20, 20), 30.0),
				_rng.randf_range(0.8, 1.4), _rng.randf_range(1.5, 3.0), Color("5a5868"), 3, 800.0, 0.0)
		if _burst_k > 0.0 and _flood_x < 1300.0:
			var x := _rng.randf_range(maxf(_flood_x, -100.0), 1280.0)
			_emit("cave", Vector2(x, _flood_y + _rng.randf_range(-4, 4)), Vector2(_rng.randf_range(-200, 40), _rng.randf_range(-200, -60)),
				_rng.randf_range(0.3, 0.7), _rng.randf_range(2.0, 5.0), WATER[_rng.randi() % 4], 0, 900.0, 0.3)
			_emit("cave", Vector2(_flood_x + _rng.randf_range(0, 60), _flood_y - _front_h * 0.8), Vector2(_rng.randf_range(-260, -60), _rng.randf_range(-240, -40)),
				_rng.randf_range(0.3, 0.8), _rng.randf_range(3.0, 8.0), WATER[_rng.randi() % 4], 0, 900.0, 0.2)
	# boulders thrown out of the wall
	for b in _boulders:
		var bd: Dictionary = b
		var v: Vector2 = bd["v"]
		v.y += 1300.0 * dt
		bd["v"] = v
		bd["p"] = (bd["p"] as Vector2) + v * dt
		bd["r"] = float(bd["r"]) + float(bd["vr"]) * dt
	# the ship floats once the water is under her
	var float_dy := minf(0.0, _flood_y - FLOAT_WL)
	_ship_dy = float_dy
	var afloat := clampf(-float_dy / 30.0, 0.0, 1.0)
	_ship_rock = sin(_t * 1.9) * 0.035 * afloat + sin(_t * 3.3) * 0.012 * afloat


func _emit_side_tick() -> void:
	var sn: Node2D = _sship["node"]
	# bow wave, wheel spray, wake
	var bow := sn.position + Vector2(40, WATERLINE) * SIDE_SCALE
	_emit("side", Vector2(bow.x, SIDE_WL), Vector2(_rng.randf_range(-120, 60), _rng.randf_range(-420, -160)), _rng.randf_range(0.4, 0.7),
		_rng.randf_range(3.0, 7.0), WATER[_rng.randi() % 4], 0, 1200.0, 0.2)
	var wc := sn.position + WHEEL_C * SIDE_SCALE
	var a := _rng.randf_range(-PI * 0.9, -PI * 0.1)
	_emit("side", wc + Vector2.from_angle(a) * 80.0, Vector2(_rng.randf_range(200, 700), _rng.randf_range(-500, -150)), _rng.randf_range(0.4, 0.8),
		_rng.randf_range(2.5, 5.0), WATER[_rng.randi() % 4], 0, 1200.0, 0.3)
	_emit("side", Vector2(wc.x + _rng.randf_range(60, 160), SIDE_WL), Vector2(_rng.randf_range(300, 800), _rng.randf_range(-120, -20)), _rng.randf_range(0.3, 0.6),
		_rng.randf_range(3.0, 6.0), Color(1, 1, 1, 0.8), 0, 600.0, 0.4)


# ================================================================== per frame
func _update_scene(delta: float) -> void:
	var drift := Vector2(sin(_t * 0.37) * 6.0, cos(_t * 0.29) * 4.0) * _drift_k
	var roll_shake := sin(_t * 21.0) * 0.004 * _rumble
	match _shot:
		"rail":
			_apply_cam(_rail_root, _rail_layers, _cam_c + drift * 0.5, _cam_z, _cam_roll + roll_shake * 0.5)
			var j := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 3.5 * _cup_shake
			_cup.position = CUP_AT + Vector2(_cup_slide, -_cup_slide * 0.029) + j
			_cup.rotation = randf_range(-0.06, 0.06) * _cup_shake
		"pillars":
			_apply_cam(_pil_root, _pil_layers, _cam_c, _cam_z, _cam_roll)
		"cave":
			_apply_cam(_cave_root, _cave_layers, _cam_c + drift * 0.4, _cam_z, _cam_roll + roll_shake)
			var sn: Node2D = _cship["node"]
			sn.position = SHIP_G_POS + Vector2(_ship_dx, _ship_dy)
			sn.rotation = _ship_rock + _ship_tilt
		"tunnel":
			_apply_cam(_tun_root, _tun_layers, C, 1.0, sin(_t * 0.9) * 0.05 + roll_shake)
			_tun_mat.set_shader_parameter("travel", _travel)
			_tun_mat.set_shader_parameter("light", 0.0)
			_bow.position = Vector2(640, 780) + Vector2(sin(_t * 1.3) * 6.0, sin(_t * 2.6) * 9.0)
			_bow.rotation = sin(_t * 1.7) * 0.025
		"side":
			_apply_cam(_side_root, _side_layers, C, 1.0, roll_shake * 0.5)
			var sn2: Node2D = _sship["node"]
			sn2.position = SIDE_POS + Vector2(sin(_t * 1.1) * 8.0, sin(_t * 2.4) * 7.0)
			sn2.rotation = sin(_t * 1.6) * 0.03
			(_sship["wheel"] as Sprite2D).rotation = _wheel_ang
			_piece.visible = _piece_on
			if _piece_on:
				_piece.position = _piece_p
				_piece.rotation = _piece_r
				_piece.scale = Vector2(SIDE_SCALE, SIDE_SCALE)
		"sky":
			_apply_cam(_sky_root, _sky_layers, _cam_c, _cam_z, _cam_roll)
			var k := clampf(_arc_k, 0.0, 1.0)
			var p := ARC_P0 * (1.0 - k) * (1.0 - k) + ARC_P1 * 2.0 * k * (1.0 - k) + ARC_P2 * k * k
			if _landed:
				p = ARC_P2 + Vector2(sin(_bob * 0.8) * 4.0, sin(_bob * 1.6) * 5.0)
				_fpivot.rotation = lerpf(_fpivot.rotation, 0.06 + sin(_bob * 1.2) * 0.03, minf(1.0, delta * 2.0))
			else:
				_fpivot.rotation = lerpf(-0.32, 0.5, k * k)
			_fpivot.position = p
			(_fship["wheel"] as Sprite2D).rotation = _wheel_ang
		"isle":
			_apply_cam(_isle_root, _isle_layers, _cam_c, _cam_z, 0.0)
			var gn: Node2D = _gship["node"]
			gn.position = ISLE_SHIP - SHIP_MID * 0.24 + Vector2(sin(_bob * 0.7) * 3.0, sin(_bob * 1.4) * 4.0)
			gn.rotation = 0.05 + sin(_bob * 1.1) * 0.025
	_white_rect.color = Color(1, 1, 1, clampf(_white, 0.0, 1.0))
	for p2 in _cpainters:
		if is_instance_valid(p2) and (p2 as CPainter).is_visible_in_tree():
			(p2 as CPainter).queue_redraw()
	if (_ecu["root"] as Control).visible:
		var pl: TextureRect = _ecu["plunger"]
		var slot := (_ecu["det"] as Control).position + DETONATOR_SLOT * DET_SC
		pl.position = slot - PLUNGER_ROD * DET_SC + Vector2(0, 36.0 + 100.0 * _push_k)
		(_ecu["p1"] as Control).position.y = 44.0 + sin(_t * 1.7) * 3.0
	for r in _reacts:
		var rd: Dictionary = r
		if not (rd["root"] as Control).visible:
			continue
		if str(rd["extra"]) == "scream":
			(rd["por"] as Control).position = Vector2(randf_range(-4, 4), randf_range(-3, 3))
		elif str(rd["extra"]) == "pots" and rd.has("prop"):
			(rd["prop"] as Control).position = Vector2(-50, 66) + Vector2(randf_range(-3, 3), randf_range(-2, 2))


# ================================================================== drawing: A / B
func _draw_fungus(ci: Node2D) -> void:
	for i in FUNGUS.size():
		var f: Vector3 = FUNGUS[i]
		var fl := 1.0
		if _flicker > 0.0:
			var on := sin(_t * (23.0 + i * 3.7) + i * 1.3) * sin(_t * (7.0 + i)) > -0.2
			fl = lerpf(1.0, 0.15 if not on else 1.25, _flicker)
		if _burst_k > 0.0 or _quake > 0.0:
			fl *= 0.75 + 0.35 * absf(sin(_t * (11.0 + i * 2.1)))
		var r := 60.0 * f.z
		ci.draw_texture_rect(_soft, Rect2(Vector2(f.x, f.y) - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.3, 1.0, 0.9, 0.22 * fl))


func _draw_cup_fx(ci: Node2D) -> void:
	# a curl of steam off the tea (it thins out as the cup starts to rattle)
	var top := _cup.position + Vector2(0, -78)
	var a := 0.32 * (1.0 - clampf(_cup_shake, 0.0, 1.0) * 0.7)
	for k in 3:
		var ph := fmod(_t * 0.5 + k / 3.0, 1.0)
		var p := top + Vector2(sin(_t * 1.3 + k * 2.0) * 10.0 + ph * 8.0, -ph * 90.0)
		var r := 12.0 + ph * 22.0
		ci.draw_texture_rect(_soft, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, a * (1.0 - ph)))


func _draw_lamps(ci: Node2D) -> void:
	for i in CHARGES.size():
		var c: Vector3 = CHARGES[i]
		var t0: float = _armed[i]
		if _t < t0:
			continue
		var age := _t - t0
		var rate := 3.0 + age * 10.0
		var on := 1.0 if sin(age * rate * TAU) > -0.3 else 0.35
		var p := Vector2(c.x, c.y)
		var r := 90.0 * c.z * (1.0 + 0.8 * maxf(0.0, 1.0 - age / 0.25))
		ci.draw_texture_rect(_soft, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.15, 0.1, 0.75 * on))
		if age < 0.4:
			var rr := 30.0 * c.z + age * 260.0 * c.z
			ci.draw_arc(p, rr, 0.0, TAU, 40, Color(1.0, 0.4, 0.3, 0.8 * (1.0 - age / 0.4)), 3.0)


func _draw_lamp_cores(ci: Node2D) -> void:
	for i in CHARGES.size():
		var c: Vector3 = CHARGES[i]
		if _t < float(_armed[i]):
			continue
		ci.draw_circle(Vector2(c.x, c.y), 10.0 * c.z, Color(1.0, 0.35, 0.3))
		ci.draw_circle(Vector2(c.x, c.y) - Vector2(3, 3) * c.z, 4.0 * c.z, Color(1.0, 0.9, 0.85))


func _draw_watch_hands(ci: Control) -> void:
	var sc := 0.82
	var c := WATCH_C * sc
	var am := (_minute / 60.0) * TAU - PI / 2.0
	var ah := ((11.0 + _minute / 60.0) / 12.0) * TAU - PI / 2.0
	ci.draw_line(c, c + Vector2.from_angle(ah) * 58.0 * sc, Color("2a1a10"), 12.0 * sc)
	ci.draw_line(c, c + Vector2.from_angle(ah) * 58.0 * sc, Color("6a4a2a"), 6.0 * sc)
	ci.draw_line(c, c + Vector2.from_angle(am) * 92.0 * sc, Color("2a1a10"), 9.0 * sc)
	ci.draw_line(c, c + Vector2.from_angle(am) * 92.0 * sc, Color("8a2a20"), 4.0 * sc)
	ci.draw_circle(c, 9.0 * sc, Color("2a1a10"))
	ci.draw_circle(c, 5.0 * sc, Color("e7b347"))


func _draw_ecu_bg(ci: Control) -> void:
	ci.draw_texture_rect(_soft, Rect2(200, -120, 640, 560), false, Color(0.6, 0.15, 0.12, 0.25))
	for k in 6:
		var x0 := 170.0 + k * 120.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 60, 0), Vector2(x0 + 100, 0), Vector2(x0 - 10, 360), Vector2(x0 - 50, 360)]),
			Color(1, 1, 1, 0.025))
	if _push_k > 0.5:
		for k in 16:
			var x := 150.0 + fmod(k * 97.0, 590.0)
			var y := fmod(k * 131.0 + _t * 2600.0, 520.0) - 120.0
			ci.draw_rect(Rect2(x, y, 3.0 + (k % 3) * 2.0, 90.0 + (k % 4) * 40.0), Color(1, 1, 1, 0.3))


# ================================================================== drawing: C / D
func _crack_parts(i: int) -> Array:
	## The visible pieces of crack i so far: the main line, then each branch once the main line has passed its root.
	var k := _crack_k(i)
	var out: Array = []
	if k <= 0.0:
		return out
	var pts: PackedVector2Array = _cracks[i]
	var n := int(ceil(k * (pts.size() - 1))) + 1
	out.append(pts.slice(0, n))
	for b in _branches[i]:
		var bb: Array = b
		var root: int = bb[0]
		var bp: PackedVector2Array = bb[1]
		var kb := clampf((k * (pts.size() - 1) - root) / 4.0, 0.0, 1.0)
		if kb > 0.0:
			out.append(bp.slice(0, int(ceil(kb * (bp.size() - 1))) + 1))
	return out


func _draw_cracks(ci: Node2D) -> void:
	for i in _cracks.size():
		var parts := _crack_parts(i)
		for j in parts.size():
			var sub: PackedVector2Array = parts[j]
			if sub.size() < 2:
				continue
			var w := 9.0 if j == 0 else 5.0
			ci.draw_polyline(sub, Color(0.0, 0.0, 0.01, 0.95), w)
			ci.draw_polyline(sub, Color(0.32, 0.4, 0.55, 0.6), 1.5)


func _draw_cracks_glow(ci: Node2D) -> void:
	for i in _cracks.size():
		var parts := _crack_parts(i)
		if parts.is_empty():
			continue
		var fresh := clampf(1.0 - (_t - float(_crack_t0[i]) - 0.9) / 1.2, 0.2, 1.0)
		for j in parts.size():
			var sub: PackedVector2Array = parts[j]
			if sub.size() >= 2:
				ci.draw_polyline(sub, Color(0.5, 1.0, 0.95, 0.55 * fresh), 2.5 if j == 0 else 1.5)
		var main: PackedVector2Array = parts[0]
		var tip: Vector2 = main[main.size() - 1]
		if _crack_k(i) < 1.0:
			ci.draw_texture_rect(_soft, Rect2(tip - Vector2(34, 34), Vector2(68, 68)), false, Color(0.8, 1.0, 1.0, 0.85))


func _crack_k(i: int) -> float:
	var t0: float = _crack_t0[i]
	if _t < t0:
		return 0.0
	return clampf((_t - t0) / 0.9, 0.0, 1.0)


func _gush_at(f: float, g: float) -> Vector2:
	return BURST_C + Vector2(-f * 300.0, f * f * 120.0 + f * 40.0) * g


func _draw_burst(ci: Node2D) -> void:
	# jets spurting through the right wall's crack before it goes
	if _jets_k > 0.0:
		var pts: PackedVector2Array = _cracks[3]
		for j in 5:
			var p: Vector2 = pts[4 + j * 3]
			var ln := 30.0 + 70.0 * _jets_k * (0.6 + 0.4 * sin(_t * 17.0 + j))
			var dir := Vector2(-1.0, 0.25 + j * 0.08).normalized()
			var tip := p + dir * ln + Vector2(0, ln * ln * 0.004)
			ci.draw_line(p, tip, Color(0.75, 1.0, 1.0, 0.9 * _jets_k), 3.0 + _jets_k * 3.0)
			ci.draw_circle(tip, 3.0 + _jets_k * 3.0, Color(1, 1, 1, 0.8 * _jets_k))
	if _burst_k <= 0.0:
		return
	# the hole: a ragged black mouth with a broken rim
	var hr := 30.0 + 120.0 * _burst_k
	var rim := PackedVector2Array()
	var hole := PackedVector2Array()
	for k in 18:
		var a := k * TAU / 18.0
		var jag := 0.8 + 0.3 * absf(fmod(sin(k * 12.9898) * 43758.5453, 1.0))
		var d := Vector2(cos(a), sin(a) * 1.15)
		rim.append(BURST_C + d * hr * jag * 1.18)
		hole.append(BURST_C + d * hr * jag)
	ci.draw_colored_polygon(rim, Color(0.13, 0.17, 0.26))
	ci.draw_colored_polygon(hole, Color(0.0, 0.01, 0.03))
	ci.draw_polyline(rim + PackedVector2Array([rim[0]]), Color(0.02, 0.02, 0.04), 4.0)
	# the lake pouring back in: a thick body of water curving down out of the hole, streaked with foam
	var g := clampf(_burst_k * 1.4, 0.0, 1.0)
	var steps := 16
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var cols := PackedColorArray()
	var colb := PackedColorArray()
	for k in steps + 1:
		var f := float(k) / steps
		var c := _gush_at(f, g)
		var wdt := hr * 1.6 * (1.0 + f * 0.8)
		var nrm := Vector2(-(0.15 + f * 0.6), -1.0).normalized()
		top.append(c + nrm * wdt * 0.5)
		bot.append(c - nrm * wdt * 0.5)
		cols.append(Color(0.55, 0.9, 0.95, 0.95))
		colb.append(Color(0.06, 0.32, 0.4, 0.97))
	var body := top.duplicate()
	var bcols := cols.duplicate()
	for k in range(steps, -1, -1):
		body.append(bot[k])
		bcols.append(colb[k])
	ci.draw_polygon(body, bcols)
	# foam streaks riding the flow
	for m in 22:
		var ph := fmod(_t * (1.6 + fmod(m * 0.37, 0.8)) + m * 0.13, 1.0)
		var lane := fmod(m * 0.618, 1.0) - 0.5
		var f0 := ph
		var f1 := minf(1.0, ph + 0.08)
		var c0 := _gush_at(f0, g)
		var c1 := _gush_at(f1, g)
		var wd := hr * 1.6 * (1.0 + f0 * 0.8)
		var nrm2 := Vector2(-(0.15 + f0 * 0.6), -1.0).normalized()
		var off := nrm2 * wd * lane * 0.8
		ci.draw_line(c0 + off, c1 + off, Color(0.9, 1.0, 1.0, 0.8 * (1.0 - absf(lane))), 3.0 + 3.0 * (1.0 - absf(lane)))
	ci.draw_polyline(top, Color(0.95, 1.0, 1.0, 0.95), 5.0)
	# where it lands: a churning heap of foam
	var land := _gush_at(1.0, g)
	for m in 7:
		var q := land + Vector2((m - 3) * 34.0, -8.0 - absf(sin(_t * 6.0 + m)) * 20.0)
		ci.draw_circle(q, 20.0 + 8.0 * sin(m * 2.1 + _t * 4.0), Color(0.92, 1.0, 1.0, 0.85 * g))


func _draw_tunnel_l(ci: Node2D) -> void:
	if _tunnel_k <= 0.0:
		return
	# the left wall gives way into a black tunnel mouth, an arch standing on the water
	var w := 40.0 + 140.0 * _tunnel_k
	var h := 60.0 + 230.0 * _tunnel_k
	var base_y := TUNNEL_L.y + 110.0
	var mouth := PackedVector2Array()
	var rim := PackedVector2Array()
	for k in 15:
		var a := PI + k * PI / 14.0
		var jag := 0.88 + 0.2 * absf(fmod(sin(k * 78.233) * 43758.5453, 1.0))
		var d := Vector2(cos(a) * w, sin(a) * h)
		mouth.append(Vector2(TUNNEL_L.x, base_y) + d * jag)
		rim.append(Vector2(TUNNEL_L.x, base_y) + d * jag * 1.16)
	rim.append(Vector2(TUNNEL_L.x + w * 1.2, base_y + 60))
	rim.append(Vector2(TUNNEL_L.x - w * 1.2, base_y + 60))
	mouth.append(Vector2(TUNNEL_L.x + w, base_y + 60))
	mouth.append(Vector2(TUNNEL_L.x - w, base_y + 60))
	ci.draw_colored_polygon(rim, Color(0.13, 0.17, 0.26))
	ci.draw_colored_polygon(mouth, Color(0.0, 0.0, 0.01))
	ci.draw_texture_rect(_soft, Rect2(Vector2(TUNNEL_L.x, base_y) - Vector2(w, h) * 0.6, Vector2(w, h) * 1.2), false, Color(0, 0, 0, 0.9))
	var arch := rim.slice(0, 15)
	ci.draw_polyline(arch, Color(0.02, 0.02, 0.04), 5.0)
	ci.draw_polyline(arch, Color(0.35, 0.95, 0.9, 0.45), 2.0)


func _draw_stakes(ci: Node2D) -> void:
	for i in [1, 2]:
		var p: Vector2 = ROPES[i][0]
		ci.draw_rect(Rect2(p.x - 7, p.y - 30, 14, 36), Color("2a1a10"))
		ci.draw_rect(Rect2(p.x - 5, p.y - 28, 10, 32), Color("6a4428"))
		ci.draw_rect(Rect2(p.x - 8, p.y - 32, 16, 6), Color("8a5a34"))


func _ship_point(local: Vector2) -> Vector2:
	var sn: Node2D = _cship["node"]
	return sn.transform * local


func _rope_mid_screen(i: int) -> Vector2:
	var l: Node2D = _cave_layers[2][0]
	var a: Vector2 = ROPES[i][0]
	var b := _ship_point(ROPES[i][1])
	return l.get_global_transform() * a.lerp(b, 0.5) - _shaker.position


func _draw_ropes(ci: Node2D) -> void:
	for i in ROPES.size():
		var a: Vector2 = ROPES[i][0]
		var b := _ship_point(ROPES[i][1])
		var t0: float = _rope_snap[i]
		if _t < t0 or t0 < -50.0:
			var taut := clampf(-_ship_dy / 40.0, 0.0, 1.0)
			var sag := lerpf(46.0, 2.0, taut)
			var pts := PackedVector2Array()
			for k in 13:
				var f := k / 12.0
				var jit := sin(_t * 60.0 + i) * 1.5 * taut
				pts.append(a.lerp(b, f) + Vector2(0, sag * 4.0 * f * (1.0 - f) + jit * sin(f * PI)))
			_draw_rope(ci, pts)
		else:
			# two loose ends whipping back and dropping
			var age := _t - t0
			var mid := a.lerp(b, 0.5)
			for e in 2:
				var anchor := a if e == 0 else b
				var away := (mid - anchor)
				var ln := away.length()
				var dir := away / maxf(ln, 1.0)
				var whip := sin(age * 18.0) * exp(-age * 3.0) * 0.9
				var fall := minf(1.0, age * 1.4)
				var pts2 := PackedVector2Array()
				for k in 9:
					var f2 := k / 8.0
					var p := anchor + dir.rotated(whip * f2 * (1.0 if e == 0 else -1.0)) * ln * f2 * (1.0 - 0.3 * fall)
					p.y += fall * 90.0 * f2 * f2
					pts2.append(p)
				_draw_rope(ci, pts2, clampf(1.0 - (age - 0.9) / 0.6, 0.0, 1.0))


func _draw_rope(ci: CanvasItem, pts: PackedVector2Array, a: float = 1.0) -> void:
	if a <= 0.0:
		return
	ci.draw_polyline(pts, Color("2a1a10", a), 6.0)
	ci.draw_polyline(pts, Color("c8a66a", a), 3.5)
	ci.draw_polyline(pts, Color("e8d09a", 0.7 * a), 1.2)


func _draw_falls(ci: Node2D, front: bool) -> void:
	var tex := _tex("qk_stalactite")
	for f in _falls:
		var d: Dictionary = f
		var fr: bool = bool(d["front"]) or float(d["floor"]) >= 470.0
		if fr != front or bool(d["done"]):
			continue
		var s: float = d["s"]
		var p := Vector2(float(d["x"]), float(d["y"]))
		ci.draw_set_transform(p, float(d["rot"]), Vector2(s, s))
		if tex:
			ci.draw_texture(tex, Vector2(-50, -300))
		else:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-30, -280), Vector2(30, -280), Vector2(0, 0)]), ROCK)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# a motion streak above it
		ci.draw_line(p + Vector2(0, -300 * s), p + Vector2(0, -300 * s - minf(float(d["vy"]) * 0.08, 140.0)), Color(1, 1, 1, 0.12), 20.0 * s)


func _draw_boulders(ci: Node2D) -> void:
	var tex := _tex("qk_boulder")
	for b in _boulders:
		var bd: Dictionary = b
		var p: Vector2 = bd["p"]
		if p.y > 900.0:
			continue
		var s: float = bd["s"]
		ci.draw_set_transform(p, float(bd["r"]), Vector2(s, s))
		if tex:
			ci.draw_texture(tex, Vector2(-70, -60))
		else:
			ci.draw_circle(Vector2.ZERO, 50.0, ROCK)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _water_poly(x0: float, x1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 44
	for k in steps + 1:
		var x := lerpf(x0, x1, float(k) / steps)
		var y := _flood_y + sin(x * 0.03 + _t * 4.0) * 3.0 + sin(x * 0.011 + _t * 2.2) * 5.0
		var d := x - _flood_x
		if d < 160.0:
			var fk := clampf(1.0 - d / 160.0, 0.0, 1.0)
			y -= _front_h * fk * fk * clampf(d / 26.0 + 1.0, 0.0, 1.0)
		pts.append(Vector2(x, y))
	return pts


func _draw_water(ci: Node2D, x0: float, x1: float) -> void:
	var top := _water_poly(x0, x1)
	var poly := top.duplicate()
	poly.append(Vector2(x1, 900))
	poly.append(Vector2(x0, 900))
	ci.draw_colored_polygon(poly, Color(0.018, 0.035, 0.06, 0.97))
	var band := PackedVector2Array()
	for p in top:
		band.append(p)
	for k in range(top.size() - 1, -1, -1):
		band.append(top[k] + Vector2(0, 30))
	ci.draw_colored_polygon(band, Color(0.05, 0.17, 0.22, 0.75))
	# the current, racing left toward wherever it's going
	for k in 26:
		var depth := fmod(k * 0.618, 1.0)
		var y := _flood_y + 20.0 + depth * 330.0
		var spd := 300.0 + 900.0 * (1.0 - depth) * (1.0 + _tunnel_k)
		var ln := 60.0 + 200.0 * (1.0 - depth)
		var xx := x1 - fmod(k * 211.0 + _t * spd, x1 - x0 + 300.0)
		if xx > x0 - ln:
			ci.draw_rect(Rect2(maxf(xx, x0), y, ln, 2.0 + 2.5 * (1.0 - depth)), Color(0.4, 0.85, 0.9, 0.2 * (1.0 - depth * 0.6)))
	ci.draw_polyline(top, Color(0.85, 1.0, 1.0, 0.9), 4.0)
	# foam patches drifting along
	for k in 12:
		var fx := x1 - fmod(k * 157.0 + _t * (180.0 + 140.0 * _tunnel_k), x1 - x0 + 200.0)
		if fx < x0:
			continue
		var fy := _flood_y + 6.0 + fmod(k * 37.0, 40.0)
		ci.draw_set_transform(Vector2(fx, fy), 0.0, Vector2(1.0, 0.25))
		ci.draw_circle(Vector2.ZERO, 18.0 + (k % 3) * 8.0, Color(0.85, 1.0, 1.0, 0.35))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_flood(ci: Node2D) -> void:
	if _burst_k <= 0.0 or _flood_x > 1290.0:
		return
	var x0 := maxf(_flood_x, -300.0)
	_draw_water(ci, x0, 1500.0)
	# the ship's lanterns, shimmering on the water once she is afloat
	if _flood_y < FLOAT_WL + 10.0:
		var sn: Node2D = _cship["node"]
		for i in range(0, LANTERNS.size(), 2):
			var lp: Vector2 = sn.transform * (LANTERNS[i] as Vector2)
			var col: Color = LANTERN_COLS[i % 3]
			for j in 6:
				var w := (14.0 - j * 1.6) * (0.5 + 0.5 * absf(sin(_t * 2.3 + j * 1.3 + i)))
				ci.draw_rect(Rect2(lp.x - w * 0.5 + sin(_t * 1.7 + j) * 3.0, _flood_y + 8.0 + j * 9.0, w, 3.0), Color(col.lightened(0.2), 0.5 - j * 0.07))
	# the wave front: a curling wall of water with a white crest
	if _front_h > 2.0 and _flood_x > -280.0:
		var fx := _flood_x
		var crest := PackedVector2Array()
		for k in 9:
			var f := k / 8.0
			crest.append(Vector2(fx + 6.0 + f * 110.0, _flood_y - _front_h * (1.0 - f * f) + sin(_t * 9.0 + k) * 4.0))
		var face := PackedVector2Array([Vector2(fx - 4.0, _flood_y + 20.0), Vector2(fx - 18.0, _flood_y - _front_h * 0.55), crest[0], crest[3],
			Vector2(crest[3].x, _flood_y + 20.0)])
		ci.draw_polygon(face, PackedColorArray([Color(0.04, 0.16, 0.2, 0.97), Color(0.2, 0.6, 0.66, 0.95), Color(0.75, 0.97, 1.0, 0.95),
			Color(0.45, 0.85, 0.9, 0.95), Color(0.03, 0.1, 0.14, 0.97)]))
		ci.draw_polyline(crest, Color(0.95, 1.0, 1.0, 0.95), 8.0)
		for k in 6:
			var q: Vector2 = crest[k]
			ci.draw_circle(q + Vector2(-8.0, -6.0), 9.0 + 5.0 * absf(sin(k * 1.7 + _t * 6.0)), Color(0.95, 1.0, 1.0, 0.9))


func _draw_flood_dock(ci: Node2D) -> void:
	if _burst_k <= 0.0 or _flood_x > 430.0:
		return
	_draw_water(ci, maxf(_flood_x, -300.0), 440.0)


func _draw_ship_lights(ci: Node2D) -> void:
	var fl_all := 1.0
	if _quake > 0.0 or _burst_k > 0.0:
		fl_all = 0.7 + 0.3 * absf(sin(_t * 13.0))
	for i in LANTERNS.size():
		var p: Vector2 = LANTERNS[i]
		var fl := (0.85 + 0.15 * sin(_t * 9.0 + i * 2.3) * sin(_t * 3.1 + i)) * fl_all
		var col: Color = LANTERN_COLS[i % 3]
		ci.draw_texture_rect(_soft, Rect2(p - Vector2(46, 46), Vector2(92, 92)), false, Color(col.lerp(Color(1, 0.85, 0.5), 0.4), 0.5 * fl))
	var wc := Color(1.0, 0.72, 0.35, 0.5 * fl_all)
	for k in 12:
		if k == 5 or k == 10:
			continue
		ci.draw_texture_rect(_soft, Rect2(180.0 + 62.0 * k - 20, 550, 74, 70), false, Color(wc, wc.a * 0.6))


func _draw_ship_lights_core(ci: Node2D) -> void:
	for i in LANTERNS.size():
		var p: Vector2 = LANTERNS[i]
		var col: Color = LANTERN_COLS[i % 3]
		ci.draw_set_transform(p, 0.0, Vector2(1.0, 1.33))
		ci.draw_circle(Vector2.ZERO, 8.0, col.lightened(0.25))
		ci.draw_circle(Vector2(-2, -2), 4.0, Color(1, 0.95, 0.75, 0.9))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var wc := Color(1.0, 0.78, 0.42, 0.75)
	for k in 12:
		if k == 5 or k == 10:
			continue
		var x := 180.0 + 62.0 * k
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x + 3, 606), Vector2(x + 3, 578), Vector2(x + 17, 563), Vector2(x + 31, 578), Vector2(x + 31, 606)]), wc)


# ================================================================== drawing: E
func _draw_tunnel_streaks(ci: Node2D) -> void:
	var n := 40
	for i in n:
		var a := (float(i) + fmod(float(i) * 0.618, 1.0)) * TAU / n
		var ph := fmod(_t * (0.9 + fmod(i * 0.37, 0.6)) + i * 0.13, 1.0)
		var r0 := 60.0 + pow(ph, 2.2) * 900.0
		var ln := 20.0 + pow(ph, 2.0) * 260.0
		var dir := Vector2.from_angle(a)
		var col := Color(0.3, 1.0, 0.9, 0.35 * ph) if i % 3 != 0 else Color(1, 1, 1, 0.22 * ph)
		ci.draw_line(BOW_VP + dir * r0, BOW_VP + dir * (r0 + ln), col, 1.5 + ph * 4.0)


func _draw_side_bg(ci: Node2D) -> void:
	ci.draw_rect(Rect2(-40, -40, W + 80, H + 80), Color("070a14"))
	ci.draw_texture_rect(_soft, Rect2(-200, 120, 1680, 480), false, Color(0.1, 0.3, 0.35, 0.25))
	# far wall strata drifting past
	for k in 9:
		var y := 90.0 + k * 52.0
		var off := fmod(_scroll * 260.0 + k * 97.0, 240.0)
		for j in 8:
			var x := -240.0 + j * 240.0 + off
			ci.draw_line(Vector2(x, y + sin(j + k) * 6.0), Vector2(x + 180.0, y + sin(j + k + 1.0) * 6.0), Color("152036"), 6.0)
	# far ribs
	for j in 7:
		var x2 := fmod(j * 260.0 + _scroll * 620.0, 1820.0) - 280.0
		var pts := PackedVector2Array([Vector2(x2, -20), Vector2(x2 + 110, -20), Vector2(x2 + 96, H + 20), Vector2(x2 + 12, H + 20)])
		ci.draw_colored_polygon(pts, Color("101a2c"))
		ci.draw_line(Vector2(x2 + 110, -20), Vector2(x2 + 96, H + 20), Color(0.3, 0.9, 0.85, 0.25), 3.0)
	# fungus streaks
	for k in 22:
		var y2 := 80.0 + fmod(k * 137.0, 470.0)
		var spd := 900.0 + fmod(k * 311.0, 700.0)
		var x3 := fmod(k * 211.0 + _scroll * spd, 1700.0) - 300.0
		ci.draw_line(Vector2(x3, y2), Vector2(x3 + 90.0 + (k % 4) * 30.0, y2), Color(0.35, 1.0, 0.9, 0.55), 2.0 + (k % 3))
	# the ceiling with its rock teeth
	ci.draw_rect(Rect2(-40, -40, W + 80, 100), Color("04060c"))
	for j in 16:
		var x4 := fmod(j * 97.0 + _scroll * 1000.0, 1560.0) - 140.0
		var h := 30.0 + fmod(j * 53.0, 70.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x4, 58), Vector2(x4 + 40, 58), Vector2(x4 + 18, 58 + h)]), Color("04060c"))


func _draw_side_glow(ci: Node2D) -> void:
	if _glow_left <= 0.0:
		return
	var r := 300.0 + 1300.0 * _glow_left
	ci.draw_texture_rect(_soft, Rect2(Vector2(-160, 330) - Vector2(r, r * 0.8), Vector2(r, r * 0.8) * 2.0), false, Color(1, 0.97, 0.88, 0.9 * _glow_left))


func _draw_side_water(ci: Node2D) -> void:
	var pts := PackedVector2Array()
	for k in 49:
		var x := -100.0 + k * 30.0
		pts.append(Vector2(x, SIDE_WL + sin(x * 0.04 - _t * 9.0) * 5.0 + sin(x * 0.013 - _t * 3.0) * 6.0))
	var poly := pts.duplicate()
	poly.append(Vector2(1400, 780))
	poly.append(Vector2(-100, 780))
	ci.draw_colored_polygon(poly, Color(0.02, 0.07, 0.1, 0.96))
	ci.draw_rect(Rect2(-100, SIDE_WL, 1500, 30), Color(0.06, 0.24, 0.3, 0.6))
	for k in 30:
		var depth := fmod(k * 0.618, 1.0)
		var y := SIDE_WL + 12.0 + depth * 130.0
		var spd := 900.0 + 1400.0 * (1.0 - depth)
		var ln := 80.0 + 220.0 * (1.0 - depth)
		var xx := fmod(k * 211.0 + _t * spd, 1700.0) - 300.0
		ci.draw_rect(Rect2(xx, y, ln, 2.0 + 3.0 * (1.0 - depth)), Color(0.6, 0.95, 1.0, 0.3 * (1.0 - depth * 0.5)))
	ci.draw_polyline(pts, Color(0.85, 1.0, 1.0, 0.9), 4.0)
	# the bow wave
	var sn: Node2D = _sship["node"]
	var bx := sn.position.x + 30.0 * SIDE_SCALE
	for k in 6:
		var q := Vector2(bx - k * 18.0, SIDE_WL - 10.0 - (6 - k) * 6.0 + sin(_t * 14.0 + k) * 4.0)
		ci.draw_circle(q, 10.0 + (6 - k) * 2.0, Color(0.92, 1.0, 1.0, 0.85))


func _draw_arch(ci: Node2D) -> void:
	if _arch_x < -860.0 or _arch_x > 1700.0:
		return
	var x := _arch_x
	var under := PackedVector2Array()
	for k in 11:
		var f := k / 10.0
		under.append(Vector2(x + ARCH_W * f, ARCH_LOW - 34.0 * pow(absf(f - 0.55) * 1.6, 2.0) + sin(k * 2.7) * 7.0))
	var poly := PackedVector2Array([Vector2(x - 60, -40)])
	poly.append_array(under)
	poly.append(Vector2(x + ARCH_W + 60, -40))
	ci.draw_colored_polygon(poly, Color("1a2438"))
	for k in 6:
		var y := 40.0 + k * 40.0
		ci.draw_line(Vector2(x - 40, y), Vector2(x + ARCH_W + 40, y + sin(k * 1.3) * 10.0), Color("0e1524"), 6.0)
	ci.draw_polyline(under, Color(0.02, 0.02, 0.04), 10.0)
	ci.draw_polyline(under, Color(0.45, 1.0, 0.92, 0.6), 3.0)
	for k in 6:
		var p: Vector2 = under[2 + k]
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -2), p + Vector2(11, -2), p + Vector2(2, 26 + k * 3)]), Color("1a2438"))
	_arch_fungus(ci, under)


func _arch_fungus(ci: Node2D, under: PackedVector2Array) -> void:
	for k in 4:
		var p: Vector2 = under[1 + k * 2] + Vector2(0, -26)
		ci.draw_texture_rect(_soft, Rect2(p - Vector2(22, 22), Vector2(44, 44)), false, Color(0.3, 1.0, 0.9, 0.5))
		ci.draw_circle(p, 4.0, Color(0.6, 1.0, 0.95))


func _draw_skr(ci: Control) -> void:
	ci.draw_rect(Rect2(0, 0, 760, 330), Color(0.03, 0.05, 0.09))
	for k in 12:
		var y := fmod(k * 53.0, 330.0)
		var x := fmod(k * 197.0 + _t * 2400.0, 1100.0) - 200.0
		ci.draw_line(Vector2(x, y), Vector2(x + 160, y), Color(0.35, 1.0, 0.9, 0.3), 3.0)
	var k := _skr_k
	# the stack, close up, its top shearing off and spinning away
	var tex := _tex("qk_stack")
	var sc := 1.6
	var base := Vector2(380, 360)
	ci.draw_rect(Rect2(base.x - 36, base.y - 230 * sc * 0.25, 72, 400), Color("16151e"))
	ci.draw_rect(Rect2(base.x - 36, base.y - 230 * sc * 0.25, 72, 400), Color("2a1a10"), false, 4.0)
	if tex:
		var off := Vector2(k * 520.0, -k * 260.0 + k * k * 380.0)
		ci.draw_set_transform(base + Vector2(0, -200) + off, k * 3.4, Vector2(sc, sc))
		ci.draw_texture(tex, -STACK_SIZE * 0.5 + Vector2(0, -10))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the rock scraping across
	var rx := lerpf(-500.0, 900.0, k)
	var rock := PackedVector2Array([Vector2(rx - 300, -20), Vector2(rx + 120, -20), Vector2(rx + 140, 120), Vector2(rx + 60, 150), Vector2(rx - 120, 135), Vector2(rx - 300, 150)])
	ci.draw_colored_polygon(rock, Color("0e1626"))
	ci.draw_polyline(PackedVector2Array([Vector2(rx - 300, 150), Vector2(rx - 120, 135), Vector2(rx + 60, 150), Vector2(rx + 140, 120)]), Color(0.35, 0.95, 0.9, 0.5), 4.0)
	# sparks
	for s in 26:
		var a := -0.4 + fmod(s * 0.37, 1.0) * 0.9
		var d := fmod(k * 3.0 + s * 0.11, 1.0) * 320.0
		var p := Vector2(380, 150) + Vector2.from_angle(a) * d
		ci.draw_line(p, p + Vector2.from_angle(a) * 22.0, Color(1.0, 0.85, 0.4, 1.0 - d / 320.0), 3.0)


# ================================================================== drawing: F / G
func _jet_at(s: float) -> Vector2:
	return TUNNEL_MOUTH + Vector2(-s * 560.0, s * s * 320.0 + s * 40.0)


func _draw_jet(ci: Node2D) -> void:
	if _jet_k <= 0.02:
		return
	var steps := 18
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var ct := PackedColorArray()
	var cb := PackedColorArray()
	for k in steps + 1:
		var s := -0.06 + 1.06 * float(k) / steps
		var c := _jet_at(s)
		var wdt := (96.0 + maxf(s, 0.0) * 90.0) * _jet_k
		var a := clampf((s + 0.06) / 0.12, 0.0, 1.0)
		top.append(c + Vector2(0, -wdt * 0.5))
		bot.append(c + Vector2(0, wdt * 0.5))
		ct.append(Color(0.75, 0.96, 1.0, 0.95 * a))
		cb.append(Color(0.2, 0.55, 0.68, 0.95 * a))
	var body := top.duplicate()
	var cols := ct.duplicate()
	for k in range(steps, -1, -1):
		body.append(bot[k])
		cols.append(cb[k])
	ci.draw_polygon(body, cols)
	for m in 18:
		var ph := fmod(_t * (1.4 + fmod(m * 0.31, 0.7)) + m * 0.17, 1.0)
		var lane := fmod(m * 0.618, 1.0) - 0.5
		var c0 := _jet_at(ph)
		var c1 := _jet_at(minf(1.0, ph + 0.06))
		var wd := (96.0 + ph * 90.0) * _jet_k
		ci.draw_line(c0 + Vector2(0, lane * wd * 0.8), c1 + Vector2(0, lane * wd * 0.8), Color(1, 1, 1, 0.75 * clampf(ph * 8.0, 0.0, 1.0)), 2.5 + 3.0 * (0.5 - absf(lane)))
	ci.draw_polyline(top.slice(2), Color(1, 1, 1, 0.9), 4.0)
	# where it hits the sea
	var land := _jet_at(1.0)
	for m in 6:
		ci.draw_circle(land + Vector2((m - 2.5) * 30.0, -10.0 - absf(sin(_t * 5.0 + m)) * 16.0), (16.0 + 6.0 * sin(m + _t * 3.0)) * _jet_k, Color(1, 1, 1, 0.85))


func _sea_band(ci: CanvasItem, x0: float, x1: float, y0: float, col: Color) -> void:
	## A near-sea band whose top fades into the far sea behind it, so there's no second horizon.
	var soft := 40.0
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y0 - soft), Vector2(x1, y0 - soft), Vector2(x1, y0), Vector2(x0, y0)]),
		PackedColorArray([Color(col, 0.0), Color(col, 0.0), col, col]))
	ci.draw_rect(Rect2(x0, y0, x1 - x0, 400), col)


func _draw_sea_fg(ci: Node2D) -> void:
	_sea_band(ci, -300.0, W + 300.0, SEA_F, Color(0.1, 0.4, 0.53, 0.97))
	for k in 34:
		var depth := fmod(k * 0.618, 1.0)
		var y := SEA_F + 6.0 + depth * 110.0
		var xx := fmod(k * 173.0 + _t * (20.0 + 30.0 * depth), 1700.0) - 300.0
		ci.draw_line(Vector2(xx, y), Vector2(xx + 40.0 + 80.0 * depth, y), Color(0.85, 1.0, 1.0, 0.4), 1.5 + 2.0 * depth)
	if _landed:
		var p := Vector2(_fpivot.position.x, SEA_F)
		ci.draw_line(p + Vector2(-190, 0), p + Vector2(190, 0), Color(0.9, 1.0, 1.0, 0.7), 3.0)


func _draw_splash(ci: Node2D) -> void:
	var age := _t - _splash_t
	if age < 0.0:
		return
	var p := Vector2(ARC_P2.x, SEA_F + 4.0)
	if age < 2.2:
		var up := minf(1.0, age / 0.25)
		var fall := clampf((age - 0.6) / 1.6, 0.0, 1.0)
		var a := 1.0 - fall
		var jets := [[-160.0, 0.55, -0.35, 70.0], [-90.0, 0.85, -0.15, 90.0], [-20.0, 1.0, 0.0, 110.0], [60.0, 0.9, 0.15, 90.0], [140.0, 0.6, 0.32, 70.0]]
		for j in jets:
			var jj: Array = j
			var x: float = jj[0]
			var h: float = 520.0 * float(jj[1]) * up * (1.0 - fall * fall)
			var lean: float = jj[2]
			var w: float = jj[3]
			var b0 := p + Vector2(x - w * 0.5, 4)
			var b1 := p + Vector2(x + w * 0.5, 4)
			var tip := p + Vector2(x + lean * h, -h)
			ci.draw_colored_polygon(PackedVector2Array([b0, tip, b1]), Color(0.6, 0.92, 0.96, 0.9 * a))
			ci.draw_colored_polygon(PackedVector2Array([b0.lerp(b1, 0.25), tip.lerp(p + Vector2(x, 0), 0.08), b0.lerp(b1, 0.7)]), Color(1, 1, 1, 0.92 * a))
	for k in 3:
		var rr := 50.0 + age * (110.0 + k * 60.0)
		var ra := clampf(1.0 - age / 2.2, 0.0, 1.0)
		if ra <= 0.0:
			continue
		ci.draw_set_transform(p, 0.0, Vector2(1.0, 0.2))
		ci.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 60, Color(0.9, 1.0, 1.0, 0.7 * ra), 8.0 - k * 2.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# foam ring around her once she's down
	var fa := clampf((age - 0.3) / 0.6, 0.0, 1.0)
	ci.draw_set_transform(p + Vector2(0, -2), 0.0, Vector2(1.0, 0.16))
	ci.draw_arc(Vector2.ZERO, 200.0, 0.0, TAU, 60, Color(1, 1, 1, 0.5 * fa), 10.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_gulls(ci: Node2D, which: int) -> void:
	var n := 5
	for i in n:
		var base := Vector2(180.0 + i * 230.0, 120.0 + fmod(i * 67.0, 140.0)) if which == 0 else Vector2(300.0 + i * 190.0, 90.0 + fmod(i * 53.0, 120.0))
		var p := base + Vector2(sin(_t * 0.3 + i) * 40.0 - _t * 6.0 * (1 + i % 2), sin(_t * 0.5 + i * 2.0) * 14.0)
		var flap := sin(_t * (5.0 + i) + i) * 0.5 + 0.5
		var s := 1.0 + (i % 3) * 0.3
		var wing := 14.0 * s
		var lift := (4.0 + flap * 7.0) * s
		ci.draw_polyline(PackedVector2Array([p + Vector2(-wing, -lift * 0.3), p + Vector2(-wing * 0.45, -lift), p, p + Vector2(wing * 0.45, -lift), p + Vector2(wing, -lift * 0.3)]),
			Color(0.15, 0.2, 0.3, 0.85), 2.5 * s)


func _draw_isle_sea(ci: Node2D) -> void:
	var cx := _cam_c.x
	var x0 := cx - 900.0
	var x1 := cx + 900.0
	_sea_band(ci, x0, x1, SEA_G, Color(0.1, 0.4, 0.53, 0.97))
	ci.draw_line(Vector2(x0, SEA_G + 2.0), Vector2(x1, SEA_G + 2.0), Color(0.85, 1.0, 1.0, 0.35), 2.0)
	for k in 60:
		var depth := fmod(k * 0.618, 1.0)
		var y := SEA_G + 8.0 + depth * 170.0
		var span := 1800.0
		var wx := floorf((x0 - k * 173.0) / span) * span + k * 173.0 + fmod(_t * (12.0 + 20.0 * depth), 200.0)
		for rep in 2:
			var xx := wx + rep * span
			if xx > x0 - 200.0 and xx < x1:
				ci.draw_line(Vector2(xx, y), Vector2(xx + 30.0 + 90.0 * depth, y), Color(0.85, 1.0, 1.0, 0.4), 1.5 + 2.5 * depth)


func _draw_isle_ship_water(ci: Node2D) -> void:
	# the water in front of her hull, soft at both ends
	var gn: Node2D = _gship["node"]
	var y := gn.position.y + WATERLINE * 0.24 + 2.0
	var col := Color(0.1, 0.4, 0.53, 0.97)
	var xa := ISLE_SHIP.x - 230.0
	var xb := ISLE_SHIP.x + 230.0
	var xs := [xa, xa + 60.0, xb - 60.0, xb]
	var al := [0.0, 1.0, 1.0, 0.0]
	for i in 3:
		var u0: float = xs[i]
		var u1: float = xs[i + 1]
		ci.draw_polygon(PackedVector2Array([Vector2(u0, y), Vector2(u1, y), Vector2(u1, y + 90), Vector2(u0, y + 90)]),
			PackedColorArray([Color(col, col.a * float(al[i])), Color(col, col.a * float(al[i + 1])), Color(col, col.a * float(al[i + 1])), Color(col, col.a * float(al[i]))]))
	ci.draw_line(Vector2(xa + 50, y), Vector2(xb - 50, y), Color(0.9, 1.0, 1.0, 0.6), 2.5)
	for k in 5:
		var xx := xa + 70.0 + fmod(k * 83.0 + _t * 20.0, 320.0)
		ci.draw_line(Vector2(xx, y + 12 + k * 12), Vector2(xx + 46, y + 12 + k * 12), Color(0.85, 1.0, 1.0, 0.4), 2.0)


# ================================================================== drawing: cut-in extras
func _draw_rope_lash(ci: Control) -> void:
	var pts := PackedVector2Array()
	for k in 21:
		var f := k / 20.0
		pts.append(Vector2(-20.0 + 470.0 * f, 168.0 - 14.0 * f + sin(f * 30.0) * 3.0))
	_draw_rope(ci, pts)
	var pts2 := PackedVector2Array()
	for k in 21:
		var f2 := k / 20.0
		pts2.append(Vector2(-20.0 + 470.0 * f2, 186.0 - 10.0 * f2 + sin(f2 * 30.0 + 1.0) * 3.0))
	_draw_rope(ci, pts2)
	# the knot
	ci.draw_circle(Vector2(300, 170), 14.0, Color("2a1a10"))
	ci.draw_circle(Vector2(300, 170), 11.0, Color("c8a66a"))
	ci.draw_line(Vector2(300, 176), Vector2(318, 214), Color("2a1a10"), 7.0)
	ci.draw_line(Vector2(300, 176), Vector2(318, 214), Color("c8a66a"), 4.0)


func _draw_photo_flash(ci: Control, r: Dictionary) -> void:
	var age := _t - float(r["t0"]) - 0.3
	if age < 0.0:
		return
	for k in 3:
		var a := age - k * 0.28
		if a < 0.0 or a > 0.25:
			continue
		var f := 1.0 - a / 0.25
		var p := Vector2(330 - k * 40, 60 + k * 20)
		ci.draw_texture_rect(_soft, Rect2(p - Vector2(160, 160) * f, Vector2(320, 320) * f), false, Color(1, 1, 1, 0.9 * f))
		var pts := PackedVector2Array()
		for q in 8:
			var rr := 70.0 * f * (1.0 if q % 2 == 0 else 0.2)
			pts.append(p + Vector2.from_angle(q * PI / 4.0) * rr)
		ci.draw_colored_polygon(pts, Color(1, 1, 1, f))


func _draw_maths(ci: Control, r: Dictionary) -> void:
	var age := _t - float(r["t0"]) - 0.25
	if age < 0.0:
		return
	var bits := [["v = d / t", Vector2(250, 20), -0.12], ["90 kn ?!", Vector2(300, 140), 0.08], ["F = m a", Vector2(40, 30), 0.1],
		["x + y = !!", Vector2(60, 140), -0.06], ["...oh dear", Vector2(200, 84), 0.04]]
	for i in bits.size():
		var b: Array = bits[i]
		var a := clampf((age - i * 0.14) / 0.12, 0.0, 1.0)
		if a <= 0.0:
			continue
		var p: Vector2 = b[1]
		ci.draw_set_transform(p, float(b[2]), Vector2.ONE)
		ci.draw_string(_font, Vector2(2, 2), str(b[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0, 0, 0, 0.6 * a))
		ci.draw_string(_font, Vector2.ZERO, str(b[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 1.0, 0.95, 0.92 * a))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
