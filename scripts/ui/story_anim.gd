extends "res://scripts/screens/cutscene_base.gd"
## StoryAnim - plays one data-driven scene from scripts/data/anim_scenes.gd (the `@anim <id>` story command).
##
## A scene is a list of timed beats, [seconds, kind, {args}]; each kind is a `_b_<kind>` method below. Beats build a
## layered cut-out stage (far / back / mid / front / top, with a parallax camera), slanted cut-ins and tape effects.
## The player sits on top of the dialogue and frees itself when the scene ends, so a story script simply carries on.
## Hold Space / Enter / mouse to skip. About 0.3 s under autotest.
##
## Debug: --anim=<id> plays a scene through the real @anim command. With --anim-t=<seconds> it starts there, and with
## --shot=<png> as well it saves that exact frame and quits (shot-delay does not apply).

const AnimScenes := preload("res://scripts/data/anim_scenes.gd")

const EASES := {"linear": 0, "sine": 1, "out": 2, "in": 3, "expo": 4, "back": 5, "expo_in": 6}
## layer name, parallax, base scale (the far layer overscans so the camera can drift without showing edges)
const LAYERS := [["far", 0.35, 1.12], ["back", 0.7, 1.04], ["mid", 1.0, 1.0], ["front", 1.35, 1.0]]
const SHOT_LEAD := 0.45      # a timed screenshot runs this long in real time first, so flashes and speed lines exist
const WIPE_IN := 0.16
const WIPE_OUT := 0.3
const REVEAL := 0.24
const TEXT_CPS := 46.0
const BLIP_STEP := 0.08
const PORTRAIT_W := 480.0
const PORTRAIT_H := 600.0
const FACE := Vector2(240, 217)   # middle of a face in a portrait, in portrait pixels

var _scene: Dictionary = {}
var _format: Dictionary = {}
var _length := 1.0
var _prev_music := ""
var _shot_taken := false

# camera
var _cam_c := C
var _cam_z := 1.0
var _cam_roll := 0.0
var _punch_k := 0.0
var _punch_at := C
var _drift_k := 1.0
# stage washes, jaws, CRT
var _wash := Color(INK, 0.0)
var _jaw_k := 0.0
var _crt_k := 0.0

var _root2d: Node2D
var _layer_list: Array = []
var _layer_by: Dictionary = {}
var _top: Node2D
var _wash_all: ColorRect
var _jaw: CPainter
var _crt: CPainter

var _el: Dictionary = {}     # beat id -> {"node": Node, "out": Callable}
var _actors: Array = []
var _tickers: Array = []
var _spinners: Array = []
var _blinks: Array = []


func _load_scene() -> void:
	var id := str(_params.get("id", ""))
	_scene = AnimScenes.DATA.get(id, {})
	if _scene.is_empty():
		push_warning("StoryAnim: unknown scene '%s'" % id)
	_format = AnimScenes.FORMATS.get(str(_scene.get("format", "slam")), {})
	_length = float(_scene.get("length", 1.0))
	_end_at = _length
	_skip_after = float(_format.get("skip_after", 1.0))
	_prev_music = Audio.current_music()


func _option(key: String, fallback: Variant) -> Variant:
	return _scene.get(key, _format.get(key, fallback))


func _debug_start_time() -> float:
	if Game.debug_anim == "" or Game.debug_anim_t < 0.0:
		return 0.0
	return clampf(_shot_time() - (SHOT_LEAD if Game.shot_path != "" else 0.0), 0.0, _length - 0.1)


func _shot_time() -> float:
	return minf(Game.debug_anim_t, _length - 0.05)


func _process(delta: float) -> void:
	if Game.debug_anim_t >= 0.0 and Game.shot_path != "":
		if _shot_taken or (Game.main and Game.main.is_transitioning()):
			return
		if _t >= _shot_time():
			_shot_taken = true
			Game.main.save_shot()
			return
	super(delta)


# ================================================================== building
func _build_scene() -> void:
	_rng.seed = hash(str(_params.get("id", "")))
	_load_scene()
	_root2d = _node(_world)
	for d in LAYERS:
		var n := _node(_root2d)
		_layer_list.append([n, d[1], d[2], C])
		_layer_by[d[0]] = n
		if d[0] == "far":
			var wp := _painter(_root2d, _draw_wash)
			wp.name = "Wash"
	_painter(_world, func(ci: Node2D) -> void: _draw_parts(ci, "stage"))
	_wash_all = ColorRect.new()
	_wash_all.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash_all.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash_all.color = Color(INK, 0.0)
	_over.add_child(_wash_all)
	_top = _node(_shaker)
	_jaw = CPainter.new()
	_jaw.fn = _draw_jaw
	_jaw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_jaw)
	move_child(_jaw, _letterbox.get_index())
	_crt = CPainter.new()
	_crt.fn = _draw_crt
	_crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_crt)
	move_child(_crt, _final.get_index())
	_set_vhs(bool(_option("tape", false)))
	_fx_chroma = 1.3
	_fx_tracking = 0.1
	_fx_desat = 0.12
	_fx_vignette = 0.6
	_fx_grain = 0.06
	_lb = 0.0


## "top" is fixed to the screen above every cut-in; "over" is fixed to the screen too, above the cut-ins made so far
## and below the ones made after it.
func _layer(n: String) -> Node:
	match n:
		"top":
			return _top
		"over":
			return _over
	return _layer_by.get(n, _layer_by["mid"])


func _content(on: bool) -> void:
	for n in [_black, _shaker, _letterbox, _fxl, _jaw]:
		(n as CanvasItem).visible = on
	if not on:
		_set_vhs(false)
		_crt.visible = false


# ================================================================== the timeline
func _schedule() -> void:
	for b in _scene.get("beats", []):
		var kind := str(b[1])
		var args: Dictionary = b[2] if (b as Array).size() > 2 else {}
		_at(float(b[0]), _beat.bind(kind, args))
	_schedule_ends()


func _beat(kind: String, a: Dictionary) -> void:
	var fn := "_b_" + kind
	if has_method(fn):
		call(fn, a)
	else:
		push_warning("StoryAnim: unknown beat '%s'" % kind)


func _schedule_ends() -> void:
	var music := str(_option("music", ""))
	_at(0.0, func() -> void:
		if music != "":
			_music(music, 0.3)
		if bool(_option("letterbox", false)):
			_anim(self, "_lb", 0.0, 1.0, 0.5, 2))
	match str(_option("in", "wipe")):
		"wipe":
			_at(0.0, func() -> void:
				_content(false)
				_anim(self, "_wipe_cover", 0.0, 1.0, WIPE_IN, 3)
				_sfx("static", 1.2, -12.0))
			_at(WIPE_IN, func() -> void:
				_content(true)
				_set_vhs(bool(_option("tape", false)))
				_crt.visible = true
				_anim(self, "_wipe_cover", 1.0, 2.0, 0.34, 2))
		"tv":
			_at(0.0, func() -> void:
				_anim(self, "_crt_k", 1.0, 0.0, 0.32, 2)
				_anim(self, "_fx_static", 0.95, 0.04, 0.7, 2)
				_anim(self, "_fx_tear", 0.8, 0.05, 0.8, 2)
				_sfx("hx_static_burst", 1.2, -6.0))
	match str(_option("out", "wipe")):
		"wipe":
			_at(_length - WIPE_OUT, func() -> void:
				_anim(self, "_wipe_cover", 0.0, 1.0, WIPE_OUT, 3)
				_sfx("static", 1.1, -12.0))
		"tv":
			_at(_length - 0.55, func() -> void:
				_anim(self, "_fx_tear", _fx_tear, 0.9, 0.2, 3)
				_anim(self, "_fx_static", _fx_static, 0.4, 0.2, 3)
				_anim(self, "_crt_k", 0.0, 1.0, 0.45, 3, 0.1)
				_sfx("an_tvoff", 1.0, -3.0))
		"jaw":
			_at(_length - 0.3, func() -> void:
				_anim(self, "_jaw_k", 0.0, 1.0, 0.2, 6)
				_sfx("whoosh", 1.25, -6.0))
			_at(_length - 0.1, func() -> void:
				_kick(20.0)
				_sfx("hx_slam", 1.1, -2.0)
				_sfx("break", 0.7, -8.0))


func _update_scene(delta: float) -> void:
	var c := _cam_c
	var z := _cam_z
	if _punch_k > 0.0:
		c = c.lerp(_punch_at, _punch_k * 0.85)
		z *= 1.0 + 0.5 * _punch_k
	var drift := Vector2(sin(_t * 0.37) * 6.0, cos(_t * 0.29) * 4.0) * _drift_k
	_apply_cam(_root2d, _layer_list, c + drift, z, deg_to_rad(_cam_roll))
	var live: Array = []
	for ac in _actors:
		if not is_instance_valid(ac):
			continue
		live.append(ac)
		var a: Actor = ac
		if a.spr:
			a.spr.position.y = sin(_t * 1.9 + a.phase) * a.bob
		if a.rig:
			a.rig.position.x = randf_range(-1.0, 1.0) * a.jit
	_actors = live
	for tk in _tickers:
		if is_instance_valid(tk["label"]):
			var lbl: Label = tk["label"]
			lbl.position.x = W - fmod((_t - float(tk["t0"])) * float(tk["speed"]), float(tk["w"]) + W)
	for s in _spinners:
		if is_instance_valid(s):
			(s as Node2D).rotation += delta * 0.5
	for b in _blinks:
		if is_instance_valid(b):
			(b as CanvasItem).visible = fmod(_t, 1.0) < 0.62
	_jaw.queue_redraw()
	_crt.queue_redraw()


# ================================================================== finishing
func _finish(skipped: bool) -> void:
	if _done:
		return
	_done = true
	_set_audio_paused(false)
	if _music_id != "":
		Audio.play_music(_prev_music if _prev_music != "" else "stop", 0.6)
	if skipped:
		Audio.stop_all_sfx()
		Audio.sfx("static", 1.2, -10.0)
	_hint.visible = false
	if Game.autotest or DisplayServer.get_name() == "headless" or str(_option("out", "wipe")) == "cut":
		_content(false)
		finished.emit({})
		return
	if str(_option("out", "wipe")) == "jaw" and not skipped:
		_open_jaws()
	else:
		_reveal()


func _reveal() -> void:
	_content(false)
	_wipe_cover = 1.0
	Fx.set_wipe(_wipe, 1.0, 1.0)
	var tw := Fx.wipe_to(_wipe, 2.0, REVEAL)
	tw.finished.connect(func() -> void: finished.emit({}))


func _open_jaws() -> void:
	for n in [_black, _shaker, _letterbox, _fxl]:
		(n as CanvasItem).visible = false
	_set_vhs(false)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_jaw_k = v
		_jaw.queue_redraw(), 1.0, 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: finished.emit({}))


# ================================================================== argument helpers
func _ez(a: Dictionary, fallback: String = "sine") -> int:
	return int(EASES.get(str(a.get("ease", fallback)), 1))


func _v2(v: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


func _col(v: Variant, fallback: Color = Color.WHITE) -> Color:
	var s := str(v) if v != null else ""
	if s == "":
		return fallback
	if Cast.exists(s):
		return Cast.color(s)
	match s:
		"aqua":
			return Style.AQUA
		"gold":
			return Style.GOLD
		"yuzu":
			return Style.YUZU
		"danger":
			return Style.DANGER
		"violet":
			return Style.VIOLET
		"good":
			return Style.GOOD
		"ink":
			return INK
		"white":
			return Color.WHITE
	return Color(s) if Color.html_is_valid(s) else fallback


func _art(id: String) -> Texture2D:
	if FileAccess.file_exists("res://art/bg/%s.svg" % id):
		return Assets.bg(id)
	return Assets.prop(id)


func _reg(id: String, node: Node, out_fn: Callable = Callable()) -> void:
	_remove(id)
	_el[id] = {"node": node, "out": out_fn}


func _remove(id: String) -> void:
	if not _el.has(id):
		return
	var n: Variant = _el[id]["node"]
	_el.erase(id)
	if is_instance_valid(n):
		(n as Node).queue_free()


func _node_of(id: String) -> Node:
	var n: Variant = _el.get(id, {}).get("node", null)
	return n if is_instance_valid(n) else null


## Mouse-transparent absolute-position container.
func _box(parent: Node, pos: Vector2, sz: Vector2) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = pos
	c.size = sz
	c.pivot_offset = sz * 0.5
	parent.add_child(c)
	return c


## Crop of a portrait that fits a window of this aspect and stays on the face.
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


func _entry_offset(from: String, amount: float) -> Vector2:
	match from:
		"left":
			return Vector2(-amount, 0)
		"right":
			return Vector2(amount, 0)
		"top":
			return Vector2(0, -amount)
		"bottom":
			return Vector2(0, amount)
	return Vector2.ZERO


# ================================================================== beats: stage
func _b_bg(a: Dictionary) -> void:
	var layer := str(a.get("layer", "far"))
	var key := "_bg_" + layer
	var tex := _art(str(a["art"]))
	if tex == null:
		_remove(key)
		return
	var holder := _node(_layer(layer))
	(_layer(layer) as Node2D).move_child(holder, 0)
	var s := _spr(holder, tex)
	if a.has("tint"):
		s.modulate = _col(a["tint"])
	_reg(key, holder)


func _b_clear(a: Dictionary) -> void:
	for id in _el.keys():
		if not (str(id).begins_with("_bg_") and bool(a.get("keep_bg", false))):
			_remove(str(id))
	_tickers.clear()
	if a.has("wash"):
		_wash = Color(INK, float(a["wash"]))


func _b_actor(a: Dictionary) -> void:
	var id := str(a["id"])
	var is_char := a.has("char")
	var tex: Texture2D
	if is_char:
		tex = Assets.portrait(str(a["char"]), str(a.get("expr", "normal")))
	else:
		tex = _art(str(a["art"]))
	if tex == null:
		return
	var sc := float(a.get("s", 1.0))
	var target := Vector2(float(a.get("x", 640.0)), float(a.get("y", 760.0)))
	var from := _v2(a.get("from"), target)
	var ac := Actor.new()
	ac.position = from
	ac.scale = Vector2(sc, sc)
	ac.rotation = deg_to_rad(float(a.get("rot", 0.0)))
	ac.phase = _rng.randf() * TAU
	ac.bob = float(a.get("bob", 3.0 if is_char else 0.0))
	_layer(str(a.get("layer", "mid"))).add_child(ac)
	ac.rig = _node(ac)
	var off := Vector2(-tex.get_width() * 0.5, -tex.get_height())
	if str(a.get("anchor", "bottom")) == "center":
		off.y = -tex.get_height() * 0.5
	if bool(a.get("shadow", is_char)):
		ac.shade = _spr(ac.rig, tex, Vector2(12, 10) * 0.8)
		ac.shade.offset = off
		ac.shade.flip_h = bool(a.get("flip", false))
		ac.shade.material = Fx.silhouette_material(Color(INK, 0.85))
	ac.spr = _spr(ac.rig, tex)
	ac.spr.offset = off
	ac.spr.flip_h = bool(a.get("flip", false))
	if a.has("sil"):
		ac.spr.material = Fx.silhouette_material(_col(a["sil"], INK))
	if a.has("tint"):
		ac.spr.modulate = _col(a["tint"])
	if a.has("a"):
		ac.modulate.a = float(a["a"])
	_actors.append(ac)
	_reg(id, ac)
	if from != target:
		_anim(ac, "position", from, target, float(a.get("dur", 0.3)), _ez(a, "expo"))


## Additive soft light; moves like an actor.
func _b_glow(a: Dictionary) -> void:
	var id := str(a["id"])
	var at := _v2(a.get("at"), C)
	var r := float(a.get("r", 200.0))
	var ac := Actor.new()
	ac.position = at
	ac.scale = Vector2.ONE * (r / 64.0)
	ac.modulate = Color(_col(a.get("col"), Color.WHITE), float(a.get("a", 0.8)))
	_layer(str(a.get("layer", "mid"))).add_child(ac)
	ac.spr = _spr(ac, _soft, Vector2.ZERO, true)
	ac.spr.material = _add_mat
	_reg(id, ac)
	if a.has("from_a"):
		_anim(ac, "modulate:a", float(a["from_a"]), float(a.get("a", 0.8)), float(a.get("dur", 0.3)), 2)


func _b_move(a: Dictionary) -> void:
	var n := _node_of(str(a["id"]))
	if n == null:
		return
	var dur := float(a.get("dur", 0.3))
	var e := _ez(a, "expo")
	if a.has("to"):
		_anim(n, "position", n.get("position"), _v2(a["to"]), dur, e)
	if a.has("s"):
		_anim(n, "scale", n.get("scale"), Vector2.ONE * float(a["s"]), dur, e)
	if a.has("rot"):
		_anim(n, "rotation", n.get("rotation"), deg_to_rad(float(a["rot"])), dur, e)
	if a.has("a"):
		_anim(n, "modulate:a", (n as CanvasItem).modulate.a, float(a["a"]), dur, e)


func _b_expr(a: Dictionary) -> void:
	var ac := _node_of(str(a["id"])) as Actor
	if ac == null or ac.spr == null:
		return
	var tex := Assets.portrait(str(a["char"]), str(a["expr"]))
	ac.spr.texture = tex
	if ac.shade:
		ac.shade.texture = tex
	if a.get("hop", true):
		_b_hop({"id": a["id"], "h": 14.0})


func _b_hop(a: Dictionary) -> void:
	var ac := _node_of(str(a["id"])) as Actor
	if ac and ac.rig:
		_anim(ac.rig, "position:y", -float(a.get("h", 22.0)), 0.0, float(a.get("dur", 0.28)), 5)


func _b_shudder(a: Dictionary) -> void:
	var ac := _node_of(str(a["id"])) as Actor
	if ac:
		_anim(ac, "jit", float(a.get("amt", 9.0)), 0.0, float(a.get("dur", 0.5)), 2)


func _b_cam(a: Dictionary) -> void:
	var dur := float(a.get("dur", 0.0))
	var e := _ez(a)
	if a.has("at"):
		var c := _v2(a["at"], C)
		if dur <= 0.0:
			_put("_cam_c", c)
		else:
			_anim(self, "_cam_c", _cam_c, c, dur, e)
	if a.has("z"):
		if dur <= 0.0:
			_put("_cam_z", float(a["z"]))
		else:
			_anim(self, "_cam_z", _cam_z, float(a["z"]), dur, e)
	if a.has("roll"):
		if dur <= 0.0:
			_put("_cam_roll", float(a["roll"]))
		else:
			_anim(self, "_cam_roll", _cam_roll, float(a["roll"]), dur, e)
	if a.has("drift"):
		_drift_k = float(a["drift"])


func _b_punch(a: Dictionary) -> void:
	_punch_at = _v2(a.get("at"), C)
	_anim(self, "_punch_k", float(a.get("k", 1.0)), 0.0, float(a.get("dur", 0.45)), 2)


func _b_wash(a: Dictionary) -> void:
	var col := Color(_col(a.get("col"), INK), float(a.get("a", 0.6)))
	var dur := float(a.get("dur", 0.0))
	if bool(a.get("all", false)):
		_anim(_wash_all, "color", _wash_all.color, col, dur, 1)
	elif dur <= 0.0:
		_put("_wash", col)
	else:
		_anim(self, "_wash", _wash, col, dur, 1)


# ================================================================== beats: impact and effects
func _b_shake(a: Dictionary) -> void:
	_kick(float(a.get("s", 14.0)))


func _b_rumble(a: Dictionary) -> void:
	_anim(self, "_rumble", _rumble, float(a.get("s", 6.0)), float(a.get("dur", 0.4)), 1)


func _b_flash(a: Dictionary) -> void:
	_flash(_col(a.get("col")), float(a.get("a", 0.6)), float(a.get("dur", 0.3)))


func _b_glitch(a: Dictionary) -> void:
	_glitch(float(a.get("dur", 0.22)), float(a.get("amt", 1.0)))


func _b_speed(a: Dictionary) -> void:
	_speed(_v2(a.get("at"), C), float(a.get("dur", 0.45)), Color(_col(a.get("col")), float(a.get("a", 0.4))),
		int(a.get("n", 40)), float(a.get("inner", 240.0)))


func _b_blade(a: Dictionary) -> void:
	_blade(_v2(a.get("a"), Vector2(-40, 520)), _v2(a.get("b"), Vector2(W + 40, 200)), _col(a.get("col"), Style.GOLD), float(a.get("w", 12.0)))


func _b_hitstop(a: Dictionary) -> void:
	_hitstop(float(a.get("dur", 0.08)), float(a.get("invert", 0.0)))


func _b_splash(a: Dictionary) -> void:
	if _fx_ok():
		Fx.splash(_fxl, _v2(a.get("at"), C), _col(a.get("col"), Style.AQUA), int(a.get("n", 14)), float(a.get("r", 200.0)), float(a.get("dur", 0.7)))


func _b_shatter(a: Dictionary) -> void:
	if _fx_ok():
		Fx.shatter(_fxl, float(a.get("dur", 0.55)), _v2(a.get("at"), C))
		_sfx("break", 1.15, -8.0)


## One impact: shake, flash, speed lines and a sound, with an optional hit-stop.
func _b_hit(a: Dictionary) -> void:
	_kick(float(a.get("s", 14.0)))
	if float(a.get("flash", 0.4)) > 0.0:
		_flash(_col(a.get("col")), float(a.get("flash", 0.4)), float(a.get("flash_dur", 0.25)))
	if a.has("lines"):
		_speed(_v2(a["lines"], C), 0.42, Color(_col(a.get("line_col")), 0.42), 38, float(a.get("inner", 240.0)))
	if a.has("glitch"):
		_glitch(0.2, float(a["glitch"]))
	if a.has("sfx"):
		_sfx(str(a["sfx"]), float(a.get("p", 1.0)), float(a.get("v", 0.0)))
	if a.has("stop"):
		_hitstop(float(a["stop"]), float(a.get("invert", 0.0)))


func _b_burst(a: Dictionary) -> void:
	var kinds := {"drop": 0, "puff": 1, "chip": 3, "confetti": 4}
	var kind := int(kinds.get(str(a.get("kind", "chip")), 3))
	var at := _v2(a.get("at"), C)
	var cols: Array = a.get("cols", ["white"])
	var n := int(a.get("n", 18))
	var spd := float(a.get("spd", 420.0))
	var sz := float(a.get("size", 5.0))
	var g := float(a.get("g", 900.0))
	var life := float(a.get("life", 1.1))
	var spread := float(a.get("spread", TAU))
	var aim := deg_to_rad(float(a.get("aim", -90.0)))
	var grow := float(a.get("grow", 0.0))
	var w := float(a.get("w", 0.0))
	for i in n:
		var ang := aim + _rng.randf_range(-0.5, 0.5) * spread
		var v := Vector2(cos(ang), sin(ang)) * spd * _rng.randf_range(0.35, 1.0)
		var p := at + Vector2(_rng.randf_range(-0.5, 0.5) * w, 0)
		var c := _col(cols[_rng.randi() % cols.size()])
		if a.has("a"):
			c.a = float(a["a"])
		_emit("stage", p, v, life * _rng.randf_range(0.6, 1.0), sz * _rng.randf_range(0.6, 1.3), c, kind, g, float(a.get("drag", 0.8)), grow)


func _b_sfx(a: Dictionary) -> void:
	_sfx(str(a["id"]), float(a.get("p", 1.0)), float(a.get("v", 0.0)))


func _b_music(a: Dictionary) -> void:
	_music(str(a["id"]), float(a.get("fade", 0.6)))


func _b_wipe(a: Dictionary) -> void:
	var from := _wipe_cover if _wipe_cover < 2.0 else 0.0
	_anim(self, "_wipe_cover", from, float(a.get("to", 1.0)), float(a.get("dur", 0.3)), 1)
	if float(a.get("to", 1.0)) <= 1.0:
		_sfx("static", 1.1, -12.0)


func _b_jaw(a: Dictionary) -> void:
	_anim(self, "_jaw_k", _jaw_k, float(a.get("to", 1.0)), float(a.get("dur", 0.2)), _ez(a, "expo_in"))


func _b_crt(a: Dictionary) -> void:
	_anim(self, "_crt_k", _crt_k, float(a.get("to", 1.0)), float(a.get("dur", 0.4)), 3)


func _b_letterbox(a: Dictionary) -> void:
	_anim(self, "_lb", _lb, 1.0 if bool(a.get("on", true)) else 0.0, float(a.get("dur", 0.4)), 2)


func _b_vhs(a: Dictionary) -> void:
	var dur := float(a.get("dur", 0.3))
	for k in ["static", "tear", "chroma", "desat", "grain", "tracking", "vignette", "bright"]:
		if a.has(k):
			var prop: String = "_fx_" + str(k)
			_anim(self, prop, get(prop), float(a[k]), dur, 1)
	if a.has("on"):
		_set_vhs(bool(a["on"]))


## Fades or slides any element off and frees it.
func _b_out(a: Dictionary) -> void:
	var id := str(a["id"])
	var e: Dictionary = _el.get(id, {})
	if e.is_empty():
		return
	var fn: Callable = e["out"]
	if fn.is_valid():
		fn.call()
		_at_late(float(a.get("dur", 0.24)), _remove.bind(id))
		return
	var n: Node = _node_of(id)
	if n == null:
		return
	var dur := float(a.get("dur", 0.18))
	_anim(n, "modulate:a", (n as CanvasItem).modulate.a, 0.0, dur, 0)
	if a.has("to"):
		_anim(n, "position", n.get("position"), _v2(a["to"]), dur, _ez(a, "expo_in"))
	_at_late(dur + 0.02, _remove.bind(id))


# ================================================================== beats: cut-ins
## A slanted window with a guest's face in it. Optional: name tag, a line beside it, "!?" and a shutter ("slab").
func _b_panel(a: Dictionary) -> void:
	var id := str(a["id"])
	var who := str(a["char"])
	var r: Array = a["rect"]
	var pos := Vector2(float(r[0]), float(r[1]))
	var sz := Vector2(float(r[2]), float(r[3]))
	var skew := float(a.get("skew", 60.0))
	var col := _col(a.get("col", who), Style.AQUA)
	var from := str(a.get("from", "left"))
	var side := -1.0 if from == "right" else 1.0
	var root := _box(_over, pos, sz)
	var fr := _slant(sz, col.darkened(0.55), Color.WHITE, 5.0, skew, 0.0, 3, Color(INK, 0.95), Vector2(10, 10))
	fr.stripe_col = Color(col.lightened(0.3), 0.3)
	fr.refresh()
	root.add_child(fr)
	var st := TC.Streaks.new()
	st.position = Vector2(absf(skew) * 0.5, 12)
	st.size = Vector2(sz.x - absf(skew), sz.y - 24)
	st.col = Color(col.lightened(0.4), 0.28)
	st.dir = side
	st.n = 12
	root.add_child(st)
	var por := TC.CutPortrait.new()
	por.texture = Assets.portrait(who, str(a.get("expr", "shock")))
	por.size = sz
	por.uv_rect = _face_crop(sz, float(a.get("zoom", 1.0)))
	var inner: Array = Geometry2D.offset_polygon(Style.slant_poly(Rect2(Vector2.ZERO, sz), skew), -7.0, Geometry2D.JOIN_MITER)
	if inner.size() > 0:
		por.frame = inner[0]
	por.edge_col = Color(Style.GOLD, 0.95)
	por.wipe_dir = side
	por.wipe = 0.0
	root.add_child(por)
	var slab: Slab = null
	if bool(a.get("slab", false)):
		slab = Slab.new()
		slab.size = sz
		slab.texture = _art("an_shutter")
		slab.frame = por.frame
		root.add_child(slab)
	if a.get("tag", true):
		var tag := _name_tag(who, Cast.display_name(who), 22)
		tag.position = Vector2(8 if side > 0.0 else sz.x - tag.size.x - 30, sz.y - 22)
		root.add_child(tag)
	var line := str(a.get("line", ""))
	if line != "":
		var fs := _fit(line, 36, 20, sz.x)
		var lbl := _title_lbl(line, fs, Color.WHITE, INK, 9, Vector2(4, 5), Color(col.darkened(0.4), 1.0))
		lbl.position = Vector2(20.0, -44.0 if bool(a.get("line_above", false)) else sz.y + 18.0)
		lbl.rotation = deg_to_rad(-3.0)
		root.add_child(lbl)
		_anim(lbl, "modulate:a", 0.0, 1.0, 0.1, 0, 0.26)
		lbl.modulate.a = 0.0
	if a.get("bang", false):
		var bang := _title_lbl(str(a["bang"]), 64, Style.YUZU, INK, 14, Vector2(5, 6))
		bang.position = Vector2(sz.x - 90 if side > 0.0 else 12, 16)
		bang.pivot_offset = Vector2(30, 40)
		bang.rotation = deg_to_rad(12.0 * side)
		root.add_child(bang)
		_anim(bang, "scale", Vector2(2.4, 2.4), Vector2.ONE, 0.16, 5, 0.18)
		_anim(bang, "modulate:a", 0.0, 1.0, 0.05, 0, 0.18)
		bang.modulate.a = 0.0
	var off := _entry_offset(from, 900.0)
	_anim(root, "position", pos + off, pos, 0.2, 4)
	_anim(por, "wipe", 0.0, 1.0, 0.24, 4, 0.05)
	_sfx("whoosh", _rng.randf_range(1.05, 1.3), -6.0)
	var centre := pos + sz * 0.5
	_at_late(0.2, func() -> void:
		_kick(float(a.get("kick", 9.0)))
		_flash(Color.WHITE, 0.2, 0.16)
		_speed(centre, 0.35, Color(1, 1, 1, 0.3), 26, 140.0))
	var e := {"node": root, "slab": slab}
	_remove(id)
	_el[id] = e
	e["out"] = func() -> void:
		_anim(root, "position", root.position, pos + off, 0.2, 6)


func _b_slab(a: Dictionary) -> void:
	var slab: Slab = _el.get(str(a["id"]), {}).get("slab", null)
	if slab:
		_anim(slab, "drop", 0.0, 1.0, float(a.get("dur", 0.16)), 6)


## The big slanted shout: band, text slam, optional portrait window.
func _b_slam(a: Dictionary) -> void:
	var id := str(a["id"])
	var who := str(a.get("char", ""))
	var text := str(a["text"])
	var col := _col(a.get("col", who), Style.GOLD)
	var root := _ctrl(_over)
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var has_face := who != ""
	var foc := TC.Focus.new()
	foc.size = Vector2(W, H)
	foc.c = Vector2(820, 340) if has_face else C
	foc.col = Color(1, 1, 1, 0.28)
	foc.r_in = 330.0
	foc.k = 1.0
	root.add_child(foc)
	var grp := _ctrl(root)
	grp.pivot_offset = C
	grp.rotation = deg_to_rad(float(a.get("rot", -9.0)))
	var band := _ctrl(grp)
	var bs := _slant(Vector2(W + 700, 256), Color(0.04, 0.02, 0.09, 0.97), col, 5.0, 64.0, 0.0, 0, Color(col.darkened(0.25), 0.95), Vector2(0, 18))
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
	var small_txt := str(a.get("small", ""))
	var small: Label = null
	if small_txt != "":
		small = _title_lbl(small_txt, 40, Color.WHITE, INK, 10, Vector2(4, 5))
		small.position = Vector2(560 if has_face else 200, 262)
		band.add_child(small)
		_anim(small, "modulate:a", 0.0, 1.0, 0.1, 0, 0.02)
		small.modulate.a = 0.0
	var tx0 := 400.0 if has_face else 0.0
	var tw_max := 820.0 if has_face else 1100.0
	var fs := _fit(text, int(a.get("fs", 96)), 40, tw_max)
	var tl2 := _title_lbl(text, fs, col, col.darkened(0.35), 18, Vector2.ZERO, Color(0, 0, 0, 0))
	var tl := _title_lbl(text, fs, Style.GOLD, INK, 18, Vector2.ZERO, Color(0, 0, 0, 0))
	var box_w := 860.0 if has_face else W
	for l in [tl2, tl]:
		var lb: Label = l
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.size = Vector2(box_w, 130)
		lb.pivot_offset = Vector2(box_w * 0.5, 65)
		band.add_child(lb)
	tl.position = Vector2(tx0, 300)
	tl2.position = tl.position + Vector2(9, 9)
	var cut := _ctrl(root)
	var por: TC.CutPortrait = null
	if has_face:
		var win := Rect2(34, 104, 380, 440)
		var win_pts := Style.slant_poly(win, 74.0)
		var frame_poly: Array = Geometry2D.offset_polygon(win_pts, 8.0, Geometry2D.JOIN_MITER)
		var fr := Style.Shape.new()
		if frame_poly.size() > 0:
			fr.points = frame_poly[0]
		fr.fill = col
		fr.outline = INK
		fr.outline_w = 3.0
		fr.shadow = Color(INK, 0.95)
		fr.shadow_off = Vector2(12, 12)
		fr.size = Vector2(W, H)
		cut.add_child(fr)
		var wbg := Style.Shape.new()
		wbg.points = win_pts
		wbg.fill = col.darkened(0.55)
		wbg.size = Vector2(W, H)
		cut.add_child(wbg)
		var wst := TC.Streaks.new()
		wst.position = Vector2(70, 120)
		wst.size = Vector2(320, 400)
		wst.col = Color(col.lightened(0.4), 0.22)
		wst.n = 10
		cut.add_child(wst)
		por = TC.CutPortrait.new()
		por.texture = Assets.portrait(who, str(a.get("expr", "angry")))
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
		var tag_text := str(a.get("tag", Cast.full_name(who).to_upper()))
		var tag := _name_tag(who, tag_text, 24)
		tag.position = Vector2(60, 536)
		cut.add_child(tag)
	var yell := str(a.get("yell", ""))
	if yell != "":
		var y := _title_lbl(yell, 34, Style.DANGER, INK, 10, Vector2(4, 5))
		y.position = Vector2(860, 520)
		y.pivot_offset = y.get_minimum_size() * 0.5
		y.rotation = deg_to_rad(-8.0)
		root.add_child(y)
		y.modulate.a = 0.0
		_anim(y, "modulate:a", 0.0, 1.0, 0.05, 0, 0.9)
		_anim(y, "scale", Vector2(2.2, 2.2), Vector2.ONE, 0.2, 5, 0.9)
	_anim(dim, "modulate:a", 0.0, 1.0, 0.08, 0)
	_anim(band, "position:x", W * 1.3, 0.0, 0.13, 4)
	_anim(cut, "position:x", -560.0, 0.0, 0.2, 5, 0.03)
	cut.position.x = -560.0
	if por:
		_anim(por, "wipe", 0.0, 1.0, 0.24, 4, 0.06)
	for pair in [[tl, 0.08], [tl2, 0.11]]:
		var lb: Label = pair[0]
		_anim(lb, "scale", Vector2(2.7, 2.7), Vector2.ONE, 0.12, 4, pair[1])
		_anim(lb, "modulate:a", 0.0, 1.0, 0.04, 0, pair[1])
		lb.modulate.a = 0.0
	_sfx(str(a.get("sfx", "shout")), 0.9, 0.0)
	var impact := foc.c
	_at_late(0.2, func() -> void:
		_kick(16.0)
		_flash(Color.WHITE, 0.6, 0.3)
		_speed(impact, 0.45, Color(1, 1, 1, 0.45), 42, 280.0)
		_glitch(0.16, 0.9))
	_reg(id, root, func() -> void:
		_anim(band, "position:x", 0.0, -W * 1.4, 0.2, 6)
		_anim(cut, "position:x", 0.0, -700.0, 0.2, 6)
		_anim(dim, "modulate:a", 1.0, 0.0, 0.2, 0)
		_sfx("whoosh", 1.2, -6.0))


## Title band across the screen, with a coloured subtitle bar.
func _b_title(a: Dictionary) -> void:
	var id := str(a["id"])
	var text := str(a["text"])
	var sub := str(a.get("sub", ""))
	var col := _col(a.get("col"), Style.AQUA)
	var root := _ctrl(_over)
	var dimr := ColorRect.new()
	dimr.color = Color(INK, 0.5)
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dimr)
	var rig := _ctrl(root)
	rig.pivot_offset = C
	rig.rotation = deg_to_rad(float(a.get("rot", -7.0)))
	var bw := 1900.0
	var x0 := -310.0
	var sl_top := _slant(Vector2(bw, 10), Style.YUZU, Color(0, 0, 0, 0), 0.0, 6.0, 0.0, 0, Color(0, 0, 0, 0))
	sl_top.position = Vector2(x0, 196)
	rig.add_child(sl_top)
	var sl_bot := _slant(Vector2(bw, 10), col, Color(0, 0, 0, 0), 0.0, 6.0, 0.0, 0, Color(0, 0, 0, 0))
	sl_bot.position = Vector2(x0, 470)
	rig.add_child(sl_bot)
	var band_a := _slant(Vector2(bw, 168), Color(0.04, 0.02, 0.10, 0.97), col, 5.0, 46.0, 0.0, 0, Color(col.darkened(0.3), 0.85), Vector2(0, 12))
	band_a.position = Vector2(x0, 214)
	rig.add_child(band_a)
	var st := TC.Streaks.new()
	st.position = Vector2(0, 14)
	st.size = Vector2(bw, 140)
	st.col = Color(col, 0.16)
	st.n = 16
	band_a.add_child(st)
	var fs := _fit(text, int(a.get("fs", 100)), 44, 1060.0)
	var tl := _title_lbl(text, fs, Style.GOLD, Style.BG_DARK, 16, Vector2(8, 8), Color(col.darkened(0.25), 1.0))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.size = Vector2(W, 150)
	tl.position = Vector2(-x0, 8)
	tl.pivot_offset = tl.size * 0.5
	band_a.add_child(tl)
	var band_b := _slant(Vector2(bw, 64), col, Color.WHITE, 3.0, 24.0, 0.0, 0, Color(INK, 0.9), Vector2(0, 8))
	band_b.position = Vector2(x0, 396)
	rig.add_child(band_b)
	var st2 := TC.Streaks.new()
	st2.position = Vector2(0, 6)
	st2.size = Vector2(bw, 52)
	st2.col = Color(1, 1, 1, 0.22)
	st2.dir = -1.0
	st2.n = 10
	band_b.add_child(st2)
	if sub != "":
		var sl := Style.label(sub, 29, Style.BG_DARK, true)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sl.size = Vector2(W, 64)
		sl.position = Vector2(-x0, 0)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band_b.add_child(sl)
	_anim(dimr, "modulate:a", 0.0, 1.0, 0.15, 0)
	_anim(band_a, "position:x", x0 - bw, x0, 0.26, 4)
	_anim(band_b, "position:x", x0 + bw, x0, 0.26, 4, 0.05)
	_anim(sl_top, "position:x", x0 + bw, x0, 0.26, 4, 0.08)
	_anim(sl_bot, "position:x", x0 - bw, x0, 0.26, 4, 0.08)
	_anim(tl, "scale", Vector2(1.6, 1.6), Vector2.ONE, 0.3, 5, 0.12)
	_anim(tl, "modulate:a", 0.0, 1.0, 0.08, 0, 0.12)
	tl.modulate.a = 0.0
	band_b.position.x = x0 + bw
	sl_top.position.x = x0 + bw
	sl_bot.position.x = x0 - bw
	_sfx("whoosh", 1.0, 0.0)
	_at_late(0.22, func() -> void:
		_kick(9.0)
		_flash(Color.WHITE, 0.4, 0.3)
		_speed(C, 0.5, Color(1, 1, 1, 0.3), 40, 280.0)
		_blade(Vector2(-40, 404), Vector2(W + 40, 248), Color(Style.GOLD, 0.9), 10.0)
		_sfx(str(a.get("sfx", "gavel")), 0.8, -4.0))
	_reg(id, root, func() -> void:
		_anim(band_a, "position:x", x0, x0 + bw + 200.0, 0.2, 6)
		_anim(sl_top, "position:x", x0, x0 + bw + 200.0, 0.2, 6)
		_anim(band_b, "position:x", x0, x0 - bw - 200.0, 0.2, 6)
		_anim(sl_bot, "position:x", x0, x0 - bw - 200.0, 0.2, 6)
		_anim(dimr, "modulate:a", 1.0, 0.0, 0.2, 0)
		_sfx("whoosh", 1.25, -6.0))


func _b_badge(a: Dictionary) -> void:
	var id := str(a["id"])
	var at := _v2(a.get("at"), Vector2(40, 74))
	var col := _col(a.get("col"), Style.AQUA)
	var root := _ctrl(_over)
	_badge(root, str(a.get("tab", "")), col, str(a["title"]), str(a.get("sub", "")), at)
	_anim(root, "position:x", -620.0, 0.0, 0.26, 4)
	_sfx("whoosh", 1.0, -6.0)
	_reg(id, root, func() -> void: _anim(root, "position:x", 0.0, -660.0, 0.22, 6))


## A word or line that slams onto the screen. "plate": true puts a slanted plate behind it; "dur" removes it again.
func _b_pop(a: Dictionary) -> void:
	var id := str(a["id"])
	var text := str(a["text"])
	var at := _v2(a.get("at"), C)
	var col := _col(a.get("col"), Style.GOLD)
	var edge := _col(a.get("edge"), Color(col.darkened(0.45), 1.0))
	var fs := _fit(text, int(a.get("fs", 64)), 18, float(a.get("max_w", 1100.0)))
	var root := _node(_top if bool(a.get("top", false)) else _over, at)
	root.rotation = deg_to_rad(float(a.get("rot", -4.0)))
	var sz: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	if bool(a.get("plate", false)):
		var plate := _slant(sz + Vector2(70, 26), PANEL_BG, _col(a.get("plate_col"), col), 3.0, 16.0, 8.0, 3, Color(INK, 0.95), Vector2(7, 7))
		plate.position = -plate.size * 0.5
		root.add_child(plate)
	var lbl := _title_lbl(text, fs, col, INK, maxi(8, int(fs / 7.0)), Vector2(5, 6), edge)
	lbl.position = -Vector2(sz.x * 0.5, sz.y * 0.56)
	root.add_child(lbl)
	var inflate := float(a.get("inflate", 2.3))
	_anim(root, "scale", Vector2.ONE * inflate, Vector2.ONE, float(a.get("in", 0.17)), 5)
	_anim(root, "modulate:a", 0.0, 1.0, 0.05, 0)
	_reg(id, root)
	if a.has("dur"):
		_at_late(float(a["dur"]), func() -> void: _b_out({"id": id}))


## Spoken line along the bottom, typed on, with the speaker's name tag. Also goes into the Logbook transcript.
func _b_say(a: Dictionary) -> void:
	var who := str(a.get("who", "narr"))
	var text := str(a["text"])
	var typing := minf(text.length() / TEXT_CPS, 1.6)
	var dur := float(a.get("dur", maxf(1.7, text.length() / 15.0)))
	var col := _col(who if Cast.exists(who) else "", Style.VIOLET)
	var y := float(a.get("y", 566.0))
	_remove("_say")
	var root := _box(_over, Vector2(190, y), Vector2(900, 86))
	var bar := _slant(Vector2(900, 86), Color(0.05, 0.03, 0.12, 0.96), col, 3.0, 20.0, 12.0, 3, Color(INK, 0.95), Vector2(8, 8))
	bar.stripe_col = Color(col, 0.25)
	bar.refresh()
	root.add_child(bar)
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(44, 8)
	lbl.size = Vector2(800, 70)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 24 if text.length() < 84 else 21)
	lbl.add_theme_color_override("font_color", Style.TEXT)
	lbl.add_theme_color_override("font_outline_color", Style.INK)
	lbl.add_theme_constant_override("outline_size", 4)
	root.add_child(lbl)
	if Cast.exists(who):
		var tag := _name_tag(who, Cast.display_name(who), 20)
		tag.position = Vector2(26, -26)
		root.add_child(tag)
	elif who == "voice":
		var tag := _name_tag("", "???", 20)
		tag.position = Vector2(26, -26)
		root.add_child(tag)
	_anim(lbl, "visible_ratio", 0.0, 1.0, typing, 0)
	_anim(root, "position:x", 150.0, 190.0, 0.16, 4)
	_anim(root, "modulate:a", 0.0, 1.0, 0.08, 0)
	if not _ff:
		Game.log_say(who if Cast.exists(who) else "narr", text)
		var pitch := Cast.pitch(who) if Cast.exists(who) else 0.9
		var i := 0
		while i * BLIP_STEP < typing:
			_at_late(i * BLIP_STEP, func() -> void:
				if not _ff:
					Audio.blip(pitch))
			i += 1
	_reg("_say", root)
	var rid := root.get_instance_id()
	_at_late(dur, func() -> void:
		var cur := _node_of("_say")
		if cur and cur.get_instance_id() == rid:
			_b_out({"id": "_say", "dur": 0.12}))


# ================================================================== beats: broadcast
## Channel furniture: logo bug, blinking LIVE tag and a tape counter.
func _b_onair(a: Dictionary) -> void:
	var root := _ctrl(_over)
	var col := _col(a.get("col"), Style.DANGER)
	var title := str(a.get("title", ""))
	if title != "":
		var tw_ := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var plate := _slant(Vector2(tw_ + 74.0, 42), Color(0.05, 0.03, 0.12, 0.92), Style.GOLD, 2.0, 12.0, 6.0, 0, Color(INK, 0.9), Vector2(5, 5))
		plate.position = Vector2(64, 28)
		root.add_child(plate)
		var l := _title_lbl(title, 22, Style.GOLD, INK, 6, Vector2(2, 2))
		l.position = Vector2(40, 6)
		plate.add_child(l)
		var tex := _art("an_snn_logo")
		if tex:
			var ic := _node(root, Vector2(66, 48))
			ic.scale = Vector2.ONE * (72.0 / tex.get_width())
			_spr(ic, tex, Vector2.ZERO, true)
	var live := _slant(Vector2(120, 34), col, Color.WHITE, 2.0, 10.0, 0.0, 0, Color(INK, 0.9), Vector2(4, 4))
	live.position = Vector2(W - 170, 28)
	root.add_child(live)
	var ll := Style.label("LIVE", 20, Color.WHITE, true)
	ll.position = Vector2(44, 3)
	ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live.add_child(ll)
	var dot := _painter(live, func(ci: Node2D) -> void: ci.draw_circle(Vector2(26, 17), 8.0, Color.WHITE))
	_blinks.append(dot)
	var tape := _painter(root, _draw_tape_osd)
	tape.position = Vector2.ZERO
	_reg("_onair", root)


func _draw_tape_osd(ci: Node2D) -> void:
	var s := int(_t + 2531.0)
	var tc := "SP  %d:%02d:%02d" % [int(s / 3600.0), int(s / 60.0) % 60, s % 60]
	var pos := Vector2(W - 210, 92)
	ci.draw_string_outline(_font, pos, tc, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, INK)
	ci.draw_string(_font, pos, tc, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.85))


## News-style crawl along the bottom. Driven by the clock, so it lands right in a timed screenshot.
func _b_ticker(a: Dictionary) -> void:
	_remove("_ticker")
	var text := str(a["text"])
	var col := _col(a.get("col"), Style.YUZU)
	var y := float(a.get("y", H - 58.0))
	var root := _box(_over, Vector2(-20, y), Vector2(W + 40, 44))
	var bar := _slant(Vector2(W + 40, 44), col, Color.WHITE, 3.0, 0.0, 0.0, 0, Color(INK, 0.9), Vector2(0, -6))
	root.add_child(bar)
	var clip := _box(root, Vector2(150, 2), Vector2(W - 110, 40))
	clip.clip_contents = true
	var fs := 26
	var lbl := _title_lbl(text, fs, INK, Color(1, 1, 1, 0.0), 0, Vector2.ZERO, Color(0, 0, 0, 0))
	lbl.position = Vector2(W, 3)
	clip.add_child(lbl)
	var tab := _slant(Vector2(150, 44), INK, Color.WHITE, 2.0, 12.0, 0.0, 0, Color(0, 0, 0, 0))
	root.add_child(tab)
	var tl := Style.label(str(a.get("tag", "BUY NOW")), 22, Style.GOLD, true)
	tl.position = Vector2(24, 7)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(tl)
	_anim(root, "position:y", H + 20.0, y, 0.3, 4)
	var tw_ := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_tickers.append({"label": lbl, "t0": _ev_time, "speed": float(a.get("speed", 210.0)), "w": tw_})
	_reg("_ticker", root)


## The price star: the old price gets struck out, the new one slams in.
func _b_price(a: Dictionary) -> void:
	var id := str(a["id"])
	var at := _v2(a.get("at"), Vector2(900, 330))
	var col := _col(a.get("col"), Style.DANGER)
	var r := float(a.get("r", 214.0))
	var root := _node(_over, at)
	var star := _node(root)
	_spinners.append(star)
	var spikes := PackedVector2Array()
	for i in 32:
		var rr := r if i % 2 == 0 else r * 0.78
		var ang := TAU * i / 32.0
		spikes.append(Vector2(cos(ang), sin(ang)) * rr)
	var painter := _painter(star, func(ci: Node2D) -> void:
		var sh := PackedVector2Array()
		for p in spikes:
			sh.append(p + Vector2(12, 14).rotated(-star.rotation))
		ci.draw_colored_polygon(sh, Color(INK, 0.92))
		ci.draw_colored_polygon(spikes, col)
		var edge := spikes.duplicate()
		edge.append(spikes[0])
		ci.draw_polyline(edge, Color.WHITE, 4.0, true)
		ci.draw_circle(Vector2.ZERO, r * 0.62, Color(col.lightened(0.15), 1.0)))
	painter.position = Vector2.ZERO
	var was_txt := str(a.get("was", ""))
	var was_fs := _fit(was_txt, 30, 14, r * 1.3)
	var was := _title_lbl(was_txt, was_fs, Color.WHITE, INK, 6, Vector2(2, 3))
	var was_sz: Vector2 = _font.get_string_size(was_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, was_fs)
	var was_y := -r * 0.42
	was.position = Vector2(-was_sz.x * 0.5, was_y)
	root.add_child(was)
	for tag in [["WAS", was_y - 30.0, Color.WHITE], ["NOW ONLY", -r * 0.08, Style.GOLD]]:
		var tl := _title_lbl(str(tag[0]), 22, tag[2], INK, 6, Vector2(2, 3))
		var tsz: Vector2 = _font.get_string_size(str(tag[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		tl.position = Vector2(-tsz.x * 0.5, float(tag[1]))
		root.add_child(tl)
	var strike := TC.Blade.new()
	strike.a = Vector2(-was_sz.x * 0.6, was_y + was_sz.y * 0.8)
	strike.b = Vector2(was_sz.x * 0.6, was_y + was_sz.y * 0.1)
	strike.col = Color(Style.GOLD, 1.0)
	strike.thick = 9.0
	strike.fade = 1.0
	strike.size = Vector2(W, H)
	root.add_child(strike)
	var now_txt := str(a.get("now", ""))
	var now_fs := _fit(now_txt, 76, 24, r * 1.6)
	var now := _title_lbl(now_txt, now_fs, Style.GOLD, INK, 12, Vector2(5, 6))
	var now_sz: Vector2 = _font.get_string_size(now_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, now_fs)
	var now_h := _node(root, Vector2(0, r * 0.3))
	now.position = -Vector2(now_sz.x * 0.5, now_sz.y * 0.56)
	now_h.add_child(now)
	now_h.modulate.a = 0.0
	_anim(root, "scale", Vector2.ONE * 2.6, Vector2.ONE, 0.2, 5)
	_anim(root, "modulate:a", 0.0, 1.0, 0.05, 0)
	var strike_at := float(a.get("strike", 0.75))
	var strike_id := strike.get_instance_id()
	var now_id := now_h.get_instance_id()
	_at_late(strike_at, func() -> void:
		var sk := instance_from_id(strike_id)
		if sk == null:
			return
		_anim(sk, "k", 0.0, 1.0, 0.1, 4)
		_sfx("shoot", 1.3, -6.0))
	_at_late(strike_at + 0.3, func() -> void:
		var nh := instance_from_id(now_id)
		if nh == null:
			return
		_anim(nh, "modulate:a", 0.0, 1.0, 0.05, 0)
		_anim(nh, "scale", Vector2.ONE * 2.6, Vector2.ONE, 0.18, 5)
		_kick(14.0)
		_flash(Style.GOLD, 0.4, 0.25)
		_speed(at, 0.45, Color(1, 1, 1, 0.42), 36, r * 0.9)
		_sfx(str(a.get("sfx", "an_kaching")), 1.0, -2.0))
	_reg(id, root)


# ================================================================== painters
func _draw_wash(ci: Node2D) -> void:
	if _wash.a > 0.003:
		ci.draw_rect(Rect2(-1600, -1200, 3200, 2400), _wash)


## Rows of teeth that bite shut across the screen. Green scales on the left, chrome on the right, like the Warden.
func _draw_jaw(ci: Control) -> void:
	if _jaw_k <= 0.001:
		return
	var open := (1.0 - _jaw_k) * 430.0
	var tooth := 80.0
	if _jaw_k > 0.95:
		ci.draw_rect(Rect2(0, 330, W, 60), INK)
	for sgn in [-1.0, 1.0]:
		var edge: float = 360.0 + sgn * open + sgn * 18.0
		var far: float = edge + sgn * 460.0
		var x_mid := 640.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(0, edge), Vector2(x_mid, edge), Vector2(x_mid, far), Vector2(0, far)]), Color("2f5e37"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x_mid, edge), Vector2(W, edge), Vector2(W, far), Vector2(x_mid, far)]), Color("9aa6b4"))
		# scales on the green half, rivets and a seam on the chrome half
		for row in 6:
			var yy: float = edge + sgn * (60.0 + row * 54.0)
			for col in 9:
				var sx := 36.0 + col * 70.0 + (35.0 if row % 2 else 0.0)
				ci.draw_arc(Vector2(sx, yy), 26.0, PI * 0.1, PI * 0.9, 10, Color("4f8f52"), 5.0)
			ci.draw_line(Vector2(x_mid + 10, yy), Vector2(W, yy), Color("7d8a99"), 3.0)
			for col in 8:
				ci.draw_circle(Vector2(x_mid + 40.0 + col * 80.0, yy - sgn * 22.0), 5.0, Color("c3ccd6"))
		ci.draw_line(Vector2(x_mid, edge), Vector2(x_mid, far), INK, 5.0)
		ci.draw_rect(Rect2(Vector2(0, minf(edge, edge + sgn * 34.0)), Vector2(W, 34.0)), Color("7c1c2c"))
		ci.draw_line(Vector2(0, edge + sgn * 34.0), Vector2(W, edge + sgn * 34.0), INK, 6.0)
		var x0: float = -tooth if sgn < 0.0 else -tooth * 0.5
		var n := int(W / tooth) + 3
		for i in n:
			var x: float = x0 + i * tooth
			var a := Vector2(x, edge)
			var b := Vector2(x + tooth, edge)
			var tip := Vector2(x + tooth * 0.5, edge - sgn * 62.0)
			ci.draw_colored_polygon(PackedVector2Array([a + Vector2(5, sgn * 4), b + Vector2(5, sgn * 4), tip + Vector2(5, sgn * 4)]), Color(INK, 0.9))
			ci.draw_colored_polygon(PackedVector2Array([a, b, tip]), Color("fff4d6"))
			ci.draw_polyline(PackedVector2Array([a, tip, b]), INK, 3.0, true)


## An old television switching off: the picture squeezes to a line, then to a dot.
func _draw_crt(ci: Control) -> void:
	if _crt_k <= 0.001:
		return
	var k := _crt_k
	var band := H * (1.0 - clampf(k / 0.7, 0.0, 1.0)) + 3.0
	var y0 := (H - band) * 0.5
	ci.draw_rect(Rect2(0, 0, W, y0), Color.BLACK)
	ci.draw_rect(Rect2(0, y0 + band, W, H - y0 - band), Color.BLACK)
	if k >= 0.7:
		var w := W * (1.0 - (k - 0.7) / 0.3)
		ci.draw_rect(Rect2(0, y0 - 2.0, W, band + 4.0), Color.BLACK)
		ci.draw_rect(Rect2((W - w) * 0.5, y0, w, band), Color.WHITE)
	else:
		ci.draw_rect(Rect2(0, y0 - 2.0, W, 2.0), Color(1, 1, 1, 0.8))
		ci.draw_rect(Rect2(0, y0 + band, W, 2.0), Color(1, 1, 1, 0.8))


# ================================================================== small nodes
## A cut-out on the stage. rig carries the hop and the shudder, spr the idle bob.
class Actor extends Node2D:
	var rig: Node2D
	var spr: Sprite2D
	var shade: Sprite2D
	var jit := 0.0
	var bob := 0.0
	var phase := 0.0


## A steel shutter dropping inside a slanted window.
class Slab extends Control:
	const ART_SCALE := 0.74
	var texture: Texture2D
	var frame := PackedVector2Array()
	var drop := 0.0:
		set(v):
			drop = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if drop <= 0.0 or frame.size() < 3:
			return
		var edge := size.y * drop
		var clip := PackedVector2Array([Vector2(-60, -60), Vector2(size.x + 60, -60), Vector2(size.x + 60, edge), Vector2(-60, edge)])
		var art := Vector2(1280, 720) * ART_SCALE
		for piece in Geometry2D.intersect_polygons(frame, clip):
			var pts: PackedVector2Array = piece
			if pts.size() < 3:
				continue
			if texture == null:
				draw_colored_polygon(pts, Color("6b7788"))
				continue
			var uvs := PackedVector2Array()
			for p in pts:
				uvs.append(Vector2((p.x + (art.x - size.x) * 0.5) / art.x, 1.0 - (edge - p.y) / art.y))
			draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, texture)
		var seg: Array = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(-60, edge), Vector2(size.x + 60, edge)]), frame)
		for s in seg:
			var line: PackedVector2Array = s
			if line.size() >= 2:
				draw_line(line[0], line[line.size() - 1], Color("1e1e22"), 5.0)
