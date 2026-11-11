extends "res://scripts/screens/cutscene_base.gd"
## Flow step `caiman_kill` (Chapter 3; docs/DESIGN3.md, "Endings"; SPOILERS). Between the two halves of the epilogue:
## the sick guest lunges at Snapjaw with a cleaver in front of everyone, Snapjaw catches the swing and his jaws close.
## Fast, loud, ugly; then everyone's faces, then silence. Until now "he bites" was a joke in the rules. Not any more.
##   0  the Grand Hall, Snapjaw still talking, the clock ticking      2.3  the face, the lunge, the cleaver
##   3.5 caught                                                       4.3  the jaws (hard white and red frames), twice more
##   5.3 the hall: the cleaver skidding, the blood across the marble  5.7  everyone, one after another, screaming
##   9.6 silence: nothing moves but the pool; a ringing, then nothing   ~23 black
## Clock-driven on cutscene_base.gd. Hold Space / Enter / mouse for 1 s (after 2 s) to skip; about 0.3 s under autotest.
## Debug: --kill-t=<seconds> (with --shot= for a timed screenshot).
## Art: art/bg/end3_hall, art/props/ck_*.svg (tools/gen_end3_art.py). Sound: ck_* (tools/gen_end3_audio.py).

const END_TIME := 23.6
const SILENCE_T := 9.6
const BITE_T := 4.3
const SHOT_LEAD := 0.45

const BLOOD := Color("7a0010")
const BLOOD_D := Color("3a0008")
const BLOOD_H := Color("b3001b")
const PORTRAIT_W := 480.0
const PORTRAIT_H := 600.0
const FACE := Vector2(240, 217)

const TAPE_SHADER := preload("res://scripts/screens/execution3_screen.gd").TAPE_SHADER
const LIT_SHADER := preload("res://scripts/screens/execution3_screen.gd").LIT_SHADER

const SNAP_POS := Vector2(800, 760)
const SNAP_SC := 0.74
const GRUB_POS := Vector2(380, 770)
const GRUB_SC := 0.6
const POOL_C := Vector2(560, 640)
## Everyone who is watching, in the order their faces cut in.
const WITNESSES := ["lulu", "bramble", "reginald", "duchess", "bruno", "zuzu", "fennel", "mochi"]

# ------------------------------------------------------------------ state
var _shot_at := -1.0
var _grub_sway := 1.0
var _lunge := 0.0
var _jaw := 0.0
var _thrash := 0.0
var _impact := 0
var _pool := 0.0
var _cleaver_t0 := 1.0e9
var _hall_dark := 0.0
var _grub_gone := false
var _tick_next := 0.4
var _ticking := true
var _red_keep := 1.0

var _cam_c := C
var _cam_z := 1.0
var _cam_from_c := C
var _cam_to_c := C
var _cam_from_z := 1.0
var _cam_to_z := 1.0
var _cam_t0 := 0.0
var _cam_t1 := 0.0

# ------------------------------------------------------------------ nodes
var _hall: Node2D
var _snap: Sprite2D
var _grub: Sprite2D
var _crowd: Array = []
var _catch: Node2D
var _bite: Node2D
var _jaw_top: Sprite2D
var _jaw_bot: Sprite2D
var _bite_grub: Sprite2D
var _snapface: Node2D
var _panels: Array = []
var _decals: Array = []


# ================================================================== contract hooks
func _debug_start_time() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kill-t="):
			var t := clampf(float(a.get_slice("=", 1)), 0.0, END_TIME - 0.5)
			if Game.shot_path != "":
				_shot_at = t
				return maxf(0.0, t - SHOT_LEAD)
			return t
	return 0.0


func _finish(skipped: bool) -> void:
	if _done:
		return
	Audio.stop_music(0.2)
	super._finish(skipped)


# ================================================================== building
func _build_scene() -> void:
	_end_at = END_TIME
	_skip_after = 2.0
	_rng.seed = 3333
	var sh := Shader.new()
	sh.code = TAPE_SHADER
	_vhs_mat.shader = sh
	_set_vhs(true)
	# not a broadcast: no tape damage, only the grade (grey, the blood kept red), grain and a vignette
	_put("_fx_tear", 0.0)
	_put("_fx_tracking", 0.0)
	_put("_fx_chroma", 1.2)
	_put("_fx_desat", 0.3)
	_put("_fx_grain", 0.05)
	_put("_fx_vignette", 0.85)
	_build_hall()
	_build_catch()
	_build_bite()
	_build_snapface()
	_show_set("hall")
	if not Game.autotest:
		Audio.stop_music(0.3)


func _lit(light_uv: Vector2, radius: float, light_col: Color, ambient: Color, desat: float, gain: float) -> ShaderMaterial:
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


func _root(n: String) -> Node2D:
	var r := Node2D.new()
	r.name = n
	_world.add_child(r)
	return r


func _build_hall() -> void:
	_hall = _root("hall")
	var bgs := _spr(_hall, Assets.bg("end3_hall"), Vector2.ZERO)
	bgs.modulate = Color(0.9, 0.9, 0.9)
	_painter(_hall, _draw_floor_blood)
	var cl := _spr(_hall, Assets.prop("ck_cleaver"), Vector2(-500, -500), true)
	cl.name = "cleaver"
	cl.scale = Vector2(0.5, 0.5)
	var tq := _spr(_hall, Assets.prop("ck_toque"), Vector2(-500, -500), true)
	tq.name = "toque"
	tq.scale = Vector2(0.5, 0.5)
	_snap = _spr(_hall, Assets.portrait("snapjaw", "happy"), SNAP_POS, true)
	_snap.offset = Vector2(0, -300)
	_snap.scale = Vector2(SNAP_SC, SNAP_SC)
	_snap.material = _lit(Vector2(0.4, -0.2), 1.3, Color(1.0, 0.86, 0.62), Color(0.08, 0.08, 0.1), 0.2, 1.4)
	_grub = _spr(_hall, Assets.portrait("grub", "angry"), GRUB_POS, true)
	_grub.offset = Vector2(0, -300)
	_grub.scale = Vector2(GRUB_SC, GRUB_SC)
	_grub.material = _lit(Vector2(0.6, -0.1), 1.2, Color(0.8, 0.9, 0.7), Color(0.06, 0.07, 0.06), 0.55, 1.25)
	var raised := _spr(_grub, Assets.prop("ck_cleaver"), Vector2(150, -430), true)
	raised.name = "raised"
	raised.rotation = -2.2
	raised.modulate = Color(0.75, 0.75, 0.75)
	_painter(_hall, _draw_parts_hall)
	# the others, watching from the edges of the frame, in shadow
	var spots := [[Vector2(-40, 1010), 1.0], [Vector2(1150, 1000), 0.95], [Vector2(1330, 960), 0.85]]
	var who := ["bruno", "lulu", "reginald"]
	for i in spots.size():
		var s := _spr(_hall, Assets.portrait(who[i], "shock"), spots[i][0], true)
		s.offset = Vector2(0, -300)
		s.scale = Vector2(float(spots[i][1]), float(spots[i][1]))
		s.modulate = Color(0.04, 0.04, 0.05)
		_crowd.append(s)
	_painter(_hall, _draw_impact_hall)


func _build_catch() -> void:
	_catch = _root("catch")
	_painter(_catch, func(ci: Node2D) -> void:
		ci.draw_rect(Rect2(-800, -800, 2880, 2320), Color("0c0204"))
		ci.draw_texture_rect(_soft, Rect2(Vector2(140, -140), Vector2(1000, 1000)), false, Color(0.7, 0.05, 0.05, 0.5)))
	var c := _spr(_catch, Assets.prop("ck_catch"), C + Vector2(0, 30), true)
	c.scale = Vector2(1.55, 1.55)
	c.material = _lit(Vector2(0.6, 0.2), 1.4, Color(1.0, 0.85, 0.7), Color(0.12, 0.1, 0.1), 0.2, 1.5)


func _build_bite() -> void:
	_bite = _root("bite")
	_painter(_bite, func(ci: Node2D) -> void:
		ci.draw_rect(Rect2(-800, -800, 2880, 2320), Color("070102"))
		ci.draw_texture_rect(_soft, Rect2(Vector2(140, 0), Vector2(1000, 720)), false, Color(0.5, 0.02, 0.04, 0.6)))
	_bite_grub = _spr(_bite, Assets.portrait("grub", "shock"), Vector2(640, 760), true)
	_bite_grub.offset = Vector2(0, -300)
	_bite_grub.scale = Vector2(0.95, 0.95)
	_bite_grub.material = _lit(Vector2(0.5, 0.5), 1.2, Color(1.0, 0.4, 0.35), Color(0.05, 0.02, 0.02), 0.4, 1.4)
	_jaw_top = _spr(_bite, Assets.prop("ck_jaw_top"), Vector2(640, -300), true)
	_jaw_bot = _spr(_bite, Assets.prop("ck_jaw_bot"), Vector2(640, 1000), true)
	_painter(_bite, _draw_parts_bite)
	_painter(_bite, _draw_impact_bite)


func _build_snapface() -> void:
	_snapface = _root("snapface")
	_painter(_snapface, func(ci: Node2D) -> void: ci.draw_rect(Rect2(-800, -800, 2880, 2320), Color("030101")))
	var s := _spr(_snapface, Assets.portrait("snapjaw", "angry"), Vector2(640, 520), true)
	s.scale = Vector2(1.7, 1.7)
	s.material = _lit(Vector2(0.5, 1.1), 1.7, Color(1.0, 0.12, 0.08), Color(0.04, 0.02, 0.03), 0.25, 2.2)


func _show_set(which: String) -> void:
	for n in [_hall, _catch, _bite, _snapface]:
		var r: Node2D = n
		r.visible = r.name == which


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


func _update_camera() -> void:
	var k := 1.0
	if _cam_t1 > _cam_t0:
		k = _ease(clampf((_t - _cam_t0) / (_cam_t1 - _cam_t0), 0.0, 1.0), 1)
	_cam_c = _cam_from_c.lerp(_cam_to_c, k)
	_cam_z = lerpf(_cam_from_z, _cam_to_z, k)
	var r: Node2D = _hall
	r.scale = Vector2(_cam_z, _cam_z)
	r.position = C - _cam_c * _cam_z


# ================================================================== the timeline
func _schedule() -> void:
	_at(0.0, func() -> void:
		_cam_cut(Vector2(620, 380), 1.0)
		_cam_move(Vector2(600, 400), 1.08, 2.4)
		_anim(self, "_lb", 0.0, 1.0, 0.6, 2))
	_at(1.5, func() -> void: _sfx("hx_heartbeat", 0.9, -4.0))
	_at(2.0, func() -> void: _sfx("hx_heartbeat", 1.0, -2.0))
	# ---- the face, the lunge
	_at(2.3, _ev_face)
	_at(3.05, _ev_lunge)
	_at(3.5, _ev_catch)
	_at(3.92, _ev_snapface)
	# ---- the jaws
	_at(BITE_T - 0.12, _ev_bite_set)
	_at(BITE_T, _ev_bite)
	_at(BITE_T + 0.06, func() -> void:
		_put("_jaw", 1.0)
		_impact = 2)
	_at(BITE_T + 0.12, func() -> void: _impact = 1)
	_at(BITE_T + 0.17, func() -> void: _impact = 0)
	_at(BITE_T + 0.35, _ev_thrash.bind(1.0))
	_at(BITE_T + 0.7, _ev_thrash.bind(-1.0))
	# ---- the hall, after
	_at(5.3, _ev_after)
	_at(5.35, func() -> void: _sfx("ck_clatter", 1.0, 0.0))
	_at(5.6, func() -> void: _sfx("ck_scream", 1.0, 0.0))
	for i in WITNESSES.size():
		_at(5.7 + i * 0.46, _ev_witness.bind(i))
	_at(7.4, func() -> void: _sfx("ck_scream", 0.86, -3.0))
	_at(8.6, func() -> void: _sfx("gasp", 0.8, -6.0))
	# ---- silence
	_at(SILENCE_T, _ev_silence)
	_at(SILENCE_T + 0.4, func() -> void: _sfx("ck_ring", 1.0, -6.0))
	_at(21.6, func() -> void: _anim(self, "_fx_bright", 1.0, 0.0, 1.6, 1))


# ------------------------------------------------------------------ events
func _ev_face() -> void:
	_ticking = false
	_panel("grub", "angry", Rect2(70, 120, 560, 330), "left", Color(0.62, 0.78, 0.52), "!!")
	_sfx("shout", 0.7, -4.0)
	_grub_sway = 2.5


func _ev_lunge() -> void:
	_clear_panels()
	_grub.texture = Assets.portrait("grub", "angry")
	_grub.modulate = Color(0.04, 0.04, 0.04)
	(_grub.get_node("raised") as Sprite2D).modulate = Color(0.04, 0.04, 0.04)
	_anim(self, "_lunge", 0.0, 1.0, 0.42, 3)
	_cam_move(Vector2(640, 420), 1.22, 0.4)
	_speed(C, 0.4, Color(1, 1, 1, 0.45), 44, 200.0)
	_sfx("ck_swing", 1.0, 0.0)
	_sfx("whoosh", 0.8, -4.0)


func _ev_catch() -> void:
	_show_set("catch")
	_hitstop(0.14, 0.12)
	_kick(22.0)
	_flash(Color.WHITE, 0.6, 0.12)
	_sfx("ck_catch", 1.0, 0.0)


func _ev_snapface() -> void:
	_show_set("snapface")
	_kick(12.0)
	_glitch(0.15, 0.5)
	_sfx("hx_sting", 1.1, -2.0)


func _ev_bite_set() -> void:
	_show_set("bite")
	_put("_jaw", 0.0)
	_anim(self, "_jaw", 0.0, 1.0, 0.12, 6)


func _ev_bite() -> void:
	_put("_jaw", 0.84)
	_impact = 1
	_hitstop(0.1)
	_kick(36.0)
	_sfx("ck_bite", 1.0, 2.0)
	_sfx("hx_splatter", 0.8, 0.0)
	_spawn_bite_blood(1.0)
	_put("_fx_desat", 0.85)


func _ev_thrash(side: float) -> void:
	_anim(self, "_thrash", side, 0.0, 0.32, 2)
	_kick(24.0)
	_sfx("ck_bite", 0.82, -5.0)
	_spawn_bite_blood(0.6)


func _ev_after() -> void:
	_show_set("hall")
	_grub_gone = true
	_grub.visible = false
	_snap.texture = Assets.portrait("snapjaw", "angry")
	_cam_cut(Vector2(620, 440), 1.12)
	_cam_move(Vector2(600, 450), 1.18, 4.0)
	_cleaver_t0 = _ev_time
	_anim(self, "_pool", 0.15, 0.55, 4.0, 2)
	_spawn_floor_blood()
	_put("_fx_desat", 0.88)
	for c in _crowd:
		(c as Sprite2D).modulate = Color(0.07, 0.07, 0.08)


func _ev_witness(i: int) -> void:
	var who: String = WITNESSES[i]
	var col := 3
	var w := 380.0
	var h := 250.0
	var row := floori(i / float(col))
	var x := 40.0 + (i % col) * 410.0 + (20.0 if row % 2 == 1 else 0.0)
	var y := 70.0 + row * 200.0
	_panel(who, "shock", Rect2(x, y, w, h), "left" if i % 2 == 0 else "right", Cast.color(who), "")
	_kick(7.0)


func _ev_silence() -> void:
	_clear_panels()
	_show_set("hall")
	_grub.visible = false
	if not _ff:
		Audio.stop_all_sfx()
		Audio.stop_music(0.0)
	_cam_cut(Vector2(590, 470), 1.16)
	_cam_move(Vector2(570, 540), 1.5, 12.0)
	_put("_fx_desat", 0.95)
	_anim(self, "_pool", _pool, 1.0, 11.0, 2)
	_anim(self, "_hall_dark", 0.0, 0.55, 3.0, 1)
	_snap.modulate = Color(0.08, 0.08, 0.09)
	_put("_lb", 1.0)


# ================================================================== panels (the reaction cut-ins)
func _face_crop(sz: Vector2, zoom: float = 1.0) -> Rect2:
	var aspect := sz.x / maxf(sz.y, 1.0)
	var cw: float
	var ch: float
	if aspect >= 400.0 / 486.0:
		cw = 410.0 / zoom
		ch = cw / aspect
	else:
		ch = 500.0 / zoom
		cw = ch * aspect
	var x := clampf(FACE.x - cw * 0.5, 0.0, PORTRAIT_W - cw)
	var y := clampf(FACE.y - ch * 0.48, 0.0, PORTRAIT_H - ch)
	return Rect2(x / PORTRAIT_W, y / PORTRAIT_H, cw / PORTRAIT_W, ch / PORTRAIT_H)


func _panel(who: String, expr: String, r: Rect2, from: String, tint: Color, bang: String) -> void:
	var skew := 48.0
	var side := -1.0 if from == "right" else 1.0
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = r.position
	root.size = r.size
	_over.add_child(root)
	var col := Cast.color(who) if Cast.exists(who) else Style.AQUA
	var fr := _slant(r.size, col.darkened(0.6), Color.WHITE, 5.0, skew, 0.0, 3, Color(INK, 0.95), Vector2(10, 10))
	fr.stripe_col = Color(col.lightened(0.3), 0.3)
	fr.refresh()
	root.add_child(fr)
	var st := TC.Streaks.new()
	st.position = Vector2(skew * 0.5, 12)
	st.size = Vector2(r.size.x - skew, r.size.y - 24)
	st.col = Color(col.lightened(0.4), 0.26)
	st.dir = side
	st.n = 12
	root.add_child(st)
	var por := TC.CutPortrait.new()
	por.texture = Assets.portrait(who, expr)
	por.size = r.size
	por.uv_rect = _face_crop(r.size, 1.05)
	var inner: Array = Geometry2D.offset_polygon(Style.slant_poly(Rect2(Vector2.ZERO, r.size), skew), -7.0, Geometry2D.JOIN_MITER)
	if inner.size() > 0:
		por.frame = inner[0]
	por.edge_col = Color(1, 1, 1, 0.9)
	por.wipe_dir = side
	por.wipe = 0.0
	por.modulate = tint if tint != col else Color(0.92, 0.92, 0.92)
	root.add_child(por)
	# a few drops of red across the panel's glass
	var specks := _painter_c(root, func(ci: Control) -> void:
		var rr := RandomNumberGenerator.new()
		rr.seed = hash(who)
		for k in 7:
			var p := Vector2(rr.randf_range(30, r.size.x - 30), rr.randf_range(16, r.size.y - 16))
			ci.draw_circle(p, rr.randf_range(3, 10), Color(BLOOD, 0.9))
			ci.draw_line(p, p + Vector2(rr.randf_range(-30, 30), rr.randf_range(-24, 24)), Color(BLOOD, 0.85), rr.randf_range(2, 5)))
	specks.visible = _grub_gone
	if bang != "":
		var b := _title_lbl(bang, 72, Style.YUZU, INK, 14, Vector2(5, 6))
		b.position = Vector2(r.size.x - 110 if side > 0.0 else 16, 10)
		b.rotation = deg_to_rad(12.0 * side)
		root.add_child(b)
	var off := Vector2(-1100 * side, 0)
	_anim(root, "position", r.position + off, r.position, 0.18, 4)
	_anim(por, "wipe", 0.0, 1.0, 0.22, 4, 0.04)
	_sfx("whoosh", _rng.randf_range(1.05, 1.3), -8.0)
	_at_late(0.18, func() -> void:
		_flash(Color.WHITE, 0.16, 0.12)
		_speed(r.position + r.size * 0.5, 0.3, Color(1, 1, 1, 0.3), 24, 120.0))
	_panels.append(root)


func _painter_c(parent: Control, fn: Callable) -> CPainter:
	var p := CPainter.new()
	p.fn = fn
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(p)
	return p


func _clear_panels() -> void:
	for p in _panels:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_panels.clear()


# ================================================================== blood
func _spawn_bite_blood(k: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 100 + int(k * 10.0) + int(_t * 10.0)
	for i in int(160 * k):
		var ang := r.randf() * TAU
		var v := Vector2(cos(ang) * r.randf_range(300, 1500), sin(ang) * r.randf_range(200, 900) - 200.0)
		_emit("bite", Vector2(640 + r.randf_range(-260, 260), 380 + r.randf_range(-30, 30)), v, r.randf_range(0.4, 1.1), r.randf_range(4.0, 14.0), BLOOD, 7, 1600.0, 0.3)


func _spawn_floor_blood() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 55
	_decals.clear()
	for i in 70:
		var ang := deg_to_rad(r.randf_range(-200, 20))
		var dir := Vector2(cos(ang), sin(ang) * 0.42).normalized()
		var d := pow(r.randf(), 1.5) * 520.0 + 40.0
		_decals.append({"p": POOL_C + dir * d, "dir": dir, "r": lerpf(13.0, 4.0, d / 560.0) * r.randf_range(0.7, 1.3), "seed": r.randi()})
	for i in 60:
		var ang2 := r.randf() * TAU
		_emit("hall", POOL_C + Vector2(r.randf_range(-60, 60), -r.randf_range(80, 220)),
			Vector2(cos(ang2) * r.randf_range(200, 700), -r.randf_range(100, 600)), r.randf_range(0.4, 0.9), r.randf_range(3.0, 8.0), BLOOD, 7, 1500.0, 0.2)


func _draw_floor_blood(ci: Node2D) -> void:
	if _decals.is_empty():
		return
	# the pool spreading over the marble, flattened by the perspective
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var rad := 80.0 + 300.0 * _pool
	var pts := PackedVector2Array()
	for i in 26:
		var a := TAU * i / 26.0
		var rr := rad * r.randf_range(0.8, 1.18)
		pts.append(POOL_C + Vector2(cos(a) * rr, sin(a) * rr * 0.3))
	ci.draw_colored_polygon(pts, BLOOD_D)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(POOL_C + (p - POOL_C) * 0.86 + Vector2(-6, -3))
	ci.draw_colored_polygon(inner, BLOOD)
	ci.draw_line(POOL_C + Vector2(-rad * 0.5, -rad * 0.12), POOL_C + Vector2(-rad * 0.1, -rad * 0.16), Color(BLOOD_H, 0.5), 3.0)
	for d in _decals:
		var dd: Dictionary = d
		var c: Vector2 = dd["p"]
		var dir: Vector2 = dd["dir"]
		var radd: float = dd["r"]
		var n := Vector2(-dir.y, dir.x)
		var ln := radd * 5.0
		ci.draw_colored_polygon(PackedVector2Array([c + n * radd, c - dir * ln, c - n * radd]), BLOOD)
		ci.draw_circle(c, radd, BLOOD_D)
		ci.draw_circle(c - dir * radd * 0.15, radd * 0.8, BLOOD)
	# the cleaver skidding across the marble and spinning to a stop; the hat rolling away
	var cl := _hall.get_node("cleaver") as Sprite2D
	var tq := _hall.get_node("toque") as Sprite2D
	var t := _t - _cleaver_t0
	if t >= 0.0:
		var k := 1.0 - exp(-t / 0.45)
		cl.position = POOL_C + Vector2(40, 10) + Vector2(260, 46) * k
		cl.rotation = 9.0 * k + 0.3
		tq.position = POOL_C + Vector2(-60, -40) + Vector2(-210, -36) * (1.0 - exp(-t / 0.7))
		tq.rotation = 2.4 * (1.0 - exp(-t / 0.7)) + 0.3
	else:
		cl.position = Vector2(-500, -500)
		tq.position = Vector2(-500, -500)


func _draw_blood_parts(ci: CanvasItem, space: String) -> void:
	for p in _parts.get(space, []):
		var d: Dictionary = p
		var pos: Vector2 = d["p"]
		var v: Vector2 = d["v"]
		var s: float = d["s"]
		var a := clampf(float(d["life"]) / maxf(float(d["max"]), 0.001) * 3.0, 0.0, 1.0)
		var tail := v * 0.025
		if tail.length() > s:
			ci.draw_line(pos - tail, pos, Color(BLOOD_D, a), s * 1.1)
		ci.draw_circle(pos, s, Color(BLOOD, a))


func _draw_parts_hall(ci: Node2D) -> void:
	_draw_blood_parts(ci, "hall")
	if _hall_dark > 0.0:
		ci.draw_rect(Rect2(-800, -800, 2880, 2320), Color(0, 0, 0, _hall_dark * 0.6))


func _draw_parts_bite(ci: Node2D) -> void:
	_draw_blood_parts(ci, "bite")


func _draw_impact_hall(ci: Node2D) -> void:
	pass


## Hard frames as the jaws close: white with the jaws and him in black, then red, then white with the spray.
func _draw_impact_bite(ci: Node2D) -> void:
	if _impact <= 0:
		return
	ci.draw_rect(Rect2(-800, -800, 2880, 2320), Color(0.95, 0.95, 0.92) if _impact == 1 else Color(0.55, 0.0, 0.03))
	for s in [_bite_grub, _jaw_top, _jaw_bot]:
		var sp: Sprite2D = s
		if not sp.visible or sp.texture == null:
			continue
		# on white, the jaws in dark red and him in black, so the two shapes read apart; on red, all of it black
		var ink := Color(0.06, 0.0, 0.0, 1)
		if _impact == 1:
			ink = Color(0, 0, 0, 1) if sp == _bite_grub else Color(0.42, 0.0, 0.03, 1)
		var sz := sp.texture.get_size() * sp.scale
		var off := sp.offset * sp.scale
		ci.draw_texture_rect(sp.texture, Rect2(sp.position + off - sz * 0.5, sz), false, ink)
	for p in _parts.get("bite", []):
		var pd: Dictionary = p
		ci.draw_circle(pd["p"], float(pd["s"]) * 1.2, Color(0.5, 0.0, 0.02) if _impact == 1 else Color(0, 0, 0))


# ================================================================== per-frame
func _simulate(dt: float) -> void:
	pass


func _update_scene(_delta: float) -> void:
	if _shot_at >= 0.0 and _t >= _shot_at and not _ff and Game.main and Game.main.has_method("save_shot"):
		_shot_at = -1.0
		Game.main.save_shot()
	_update_camera()
	_vhs_mat.set_shader_parameter("red_keep", _red_keep)
	# the hall clock, until the lunge
	if _ticking and _t >= _tick_next and not _ff:
		_tick_next = _t + 1.0
		Audio.sfx("tick", 0.55, -14.0)
	if not _grub_gone:
		var sway := sin(_t * 1.7) * 6.0 * _grub_sway
		var k := _lunge
		_grub.position = GRUB_POS.lerp(Vector2(640, 790), k) + Vector2(sway, absf(sin(_t * 3.4)) * 3.0)
		_grub.rotation = sin(_t * 1.7) * 0.03 * _grub_sway + k * 0.12
		var sc := lerpf(GRUB_SC, 0.95, k)
		_grub.scale = Vector2(sc, sc)
		var raised := _grub.get_node("raised") as Sprite2D
		raised.rotation = lerpf(-2.2, -0.6, k)
	if _bite.visible:
		var close := _jaw
		var shake := _thrash * 70.0
		_jaw_top.position = Vector2(640 + shake, lerpf(-330.0, 120.0, close))
		_jaw_bot.position = Vector2(640 - shake * 0.6, lerpf(1060.0, 560.0, close))
		_bite_grub.visible = _jaw < 0.98 or _impact == 1
		_bite_grub.position = Vector2(640 + shake * 0.4, 760)
