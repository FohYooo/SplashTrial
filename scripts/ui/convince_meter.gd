extends Control
## Convince Meter HUD (top-center strip: x 400..880, y 10..74). The trial screen adds it to ScriptPlayer.hud.
## Listens to Game.convince_changed. Angular look: slanted ink frame, 20 slanted segments, a bold gold
## VOTE notch at Game.CONVINCE_THRESHOLD (pulses when crossed), pop-up +/- numbers, a white "gain ghost"
## while the bar fills, a coral damage trail + shake on losses.

const Style := preload("res://scripts/ui/style.gd")

const W := 480.0
const SEGS := 20
const SEG_GAP := 3.0
const BAR := Rect2(22, 28, 436, 21)      # segment area (local)
const FRAME := Rect2(0, 20, 480, 37)
const SLANT := 12.0
const BASE_POS := Vector2(400, 10)

var _value := 0.0
var _shown := 0.0
var _trail := 0.0          # lags behind losses (coral damage trail)
var _trail_hold := 0.0
var _pulse := 0.0          # threshold-crossing pulse 1 -> 0
var _pulse_col := Style.GOLD
var _hit := 0.0            # change flash 1 -> 0
var _hit_col := Color.WHITE
var _t := 0.0
var _dirty := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = BASE_POS
	size = Vector2(W, 64)
	_value = Game.convince
	_shown = _value
	_trail = _value
	Game.convince_changed.connect(_on_changed)


func _on_changed(v: float, delta: float) -> void:
	var old := _value
	_value = v
	var th := Game.CONVINCE_THRESHOLD
	var txt := ""
	var col := Style.GOOD
	if delta > 0.05:
		txt = "+%d%%" % roundi(delta)
		col = Style.AQUA if v >= th else Style.GOOD
		_hit_col = Color.WHITE
	elif delta < -0.05:
		txt = "%d%%" % roundi(delta)
		col = Style.DANGER
		_hit_col = Style.DANGER
		_trail = maxf(_trail, old)
		_trail_hold = 0.4
		_shake(7.0)
	else:
		txt = "NO PENALTY"
		col = Style.GOLD
		_hit_col = Style.GOLD
	_hit = 1.0
	if old < th and v >= th:
		_pulse = 1.0
		_pulse_col = Style.GOLD
		_pop_text("THEY'RE LISTENING!", Style.GOLD, _notch_x(), 15)
	elif old >= th and v < th:
		_pulse = 1.0
		_pulse_col = Style.DANGER
		_pop_text("LOSING THEM!", Style.DANGER, _notch_x(), 15)
	var fx := clampf(BAR.position.x + BAR.size.x * clampf(v / 100.0, 0.0, 1.0), 70.0, W - 120.0)
	_pop_text(txt, col, fx, 24)
	_dirty = true


func _notch_x() -> float:
	return BAR.position.x + BAR.size.x * Game.CONVINCE_THRESHOLD / 100.0


## Pop-up label: slams in (scale overshoot), rises a few px and fades. Stays inside the HUD strip.
func _pop_text(txt: String, col: Color, cx: float, fsize: int) -> void:
	var f := Style.title_label(txt, fsize, col, Style.INK, 8)
	var sz := Style.display_font().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	f.position = Vector2(cx - sz.x * 0.5, 18)
	f.size = sz + Vector2(4, 4)
	f.pivot_offset = f.size * 0.5
	f.scale = Vector2(1.8, 1.8)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var tw := f.create_tween().set_parallel(true)
	tw.tween_property(f, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "position:y", 4.0, 0.8).set_delay(0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, 0.35).set_delay(0.65)
	tw.chain().tween_callback(f.queue_free)


func _shake(strength: float) -> void:
	var tw := create_tween()
	for i in 6:
		var k := 1.0 - i / 6.0
		tw.tween_property(self, "position", BASE_POS + Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * strength * k, 0.035)
	tw.tween_property(self, "position", BASE_POS, 0.03)


func _process(delta: float) -> void:
	_t += delta
	var target := _value
	var prev_shown := _shown
	_shown = lerpf(_shown, target, 1.0 - exp(-delta * 8.0))
	if absf(_shown - target) < 0.05:
		_shown = target
	if _trail_hold > 0.0:
		_trail_hold -= delta
	elif _trail > _shown:
		_trail = maxf(_shown, _trail - delta * 40.0)
	else:
		_trail = _shown
	var animating := _pulse > 0.0 or _hit > 0.0 or prev_shown != _shown or _trail != _shown
	_pulse = maxf(0.0, _pulse - delta / 0.7)
	_hit = maxf(0.0, _hit - delta / 0.35)
	if animating or _dirty:
		_dirty = false
		queue_redraw()


func _seg_poly(i: int, frac: float) -> PackedVector2Array:
	var sw := (BAR.size.x - SEG_GAP * (SEGS - 1)) / SEGS
	var x := BAR.position.x + i * (sw + SEG_GAP)
	var w := sw * frac
	return Style.slant_poly(Rect2(x, BAR.position.y, w, BAR.size.y), minf(6.0, w * 0.5))


func _draw() -> void:
	var th := Game.CONVINCE_THRESHOLD
	var ok := _shown >= th
	var font := Style.display_font()
	# frame: hard shadow, outline, ink fill (+ pulse ring)
	var frame := Style.slant_poly(FRAME, SLANT)
	var edge := Style.AQUA if ok else Style.AQUA_DEEP
	if _pulse > 0.0:
		var ring: Array = Geometry2D.offset_polygon(frame, 3.0 + (1.0 - _pulse) * 12.0, Geometry2D.JOIN_MITER)
		if ring.size() > 0:
			draw_colored_polygon(ring[0], Color(_pulse_col, 0.45 * _pulse))
		edge = edge.lerp(_pulse_col, _pulse)
	Style.draw_shape(self, frame, Color(Style.INK, 0.93), edge, 2.0, Color(Style.INK, 0.85), Vector2(5, 5))
	if _hit > 0.0:
		var inner: Array = Geometry2D.offset_polygon(frame, -2.0, Geometry2D.JOIN_MITER)
		if inner.size() > 0:
			draw_colored_polygon(inner[0], Color(_hit_col, 0.22 * _hit))
	# segments
	var low := Style.YUZU.lerp(Style.DANGER, clampf(1.0 - _shown / th, 0.0, 1.0))
	var main_col := Style.AQUA if ok else low
	var ghost_top := maxf(_trail, _value)
	var losing := _trail > _value + 0.1
	var ghost_col := Color(Style.DANGER.lightened(0.2), 0.9) if losing else Color(1, 1, 1, 0.55)
	for i in SEGS:
		var lo := i * 100.0 / SEGS
		var span := 100.0 / SEGS
		var empty := Color(0.13, 0.09, 0.25, 1.0) if lo < th else Color(0.22, 0.18, 0.12, 1.0)
		draw_colored_polygon(_seg_poly(i, 1.0), empty)
		var g := clampf((ghost_top - lo) / span, 0.0, 1.0)
		if g > 0.02:
			draw_colored_polygon(_seg_poly(i, g), ghost_col)
		var m := clampf((_shown - lo) / span, 0.0, 1.0)
		if m > 0.02:
			draw_colored_polygon(_seg_poly(i, m), main_col)
			# top sheen
			var sw := (BAR.size.x - SEG_GAP * (SEGS - 1)) / SEGS
			var x := BAR.position.x + i * (sw + SEG_GAP)
			draw_line(Vector2(x + 6, BAR.position.y + 3), Vector2(x + 6 + (sw - 6) * m, BAR.position.y + 3), Color(1, 1, 1, 0.35), 2.0)
	# vote notch (bold gold bar + arrowheads)
	var nx := _notch_x()
	var gold := Style.GOLD.lerp(Color.WHITE, 0.6 * _pulse)
	var bar_pts := PackedVector2Array([Vector2(nx - 2, 17), Vector2(nx + 7, 17), Vector2(nx + 2, 60), Vector2(nx - 7, 60)])
	Style.draw_shape(self, bar_pts, gold, Style.INK, 1.5, Color(Style.INK, 0.8), Vector2(3, 0))
	var top_tri := PackedVector2Array([Vector2(nx - 9, 9), Vector2(nx + 11, 9), Vector2(nx + 1, 21)])
	var bot_tri := PackedVector2Array([Vector2(nx - 11, 64), Vector2(nx + 9, 64), Vector2(nx - 1, 53)])
	Style.draw_shape(self, top_tri, gold, Style.INK, 2.0, Color(0, 0, 0, 0), Vector2.ZERO)
	Style.draw_shape(self, bot_tri, gold, Style.INK, 2.0, Color(0, 0, 0, 0), Vector2.ZERO)
	draw_string_outline(font, Vector2(nx + 14, 13), "VOTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Style.INK)
	draw_string(font, Vector2(nx + 14, 13), "VOTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gold)
	# title tab
	var tab := Style.slant_poly(Rect2(10, 0, 128, 23), 9.0)
	Style.draw_shape(self, tab, Style.AQUA, Style.INK, 2.0, Color(Style.INK, 0.85), Vector2(4, 4))
	draw_string(font, Vector2(26, 17), "CONVINCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Style.INK)
	# percentage tab
	var pr := Rect2(W - 112, -1, 98, 26)
	Style.draw_shape(self, Style.slant_poly(pr, 9.0), Color(Style.INK, 0.95), main_col, 2.0, Color(Style.INK, 0.8), Vector2(4, 4))
	var pct := "%d%%" % roundi(_shown)
	draw_string_outline(font, Vector2(pr.position.x, 20), pct, HORIZONTAL_ALIGNMENT_RIGHT, pr.size.x - 16, 21, 5, Style.INK)
	draw_string(font, Vector2(pr.position.x, 20), pct, HORIZONTAL_ALIGNMENT_RIGHT, pr.size.x - 16, 21, Color.WHITE if not ok else Style.GOLD)
