extends Control
## BUBBLE LETTERS - letter bubbles rise through a steamy pool; pop them in order to spell the answer.
## data: prompt, answer (word), decoys (extra letters), time (seconds x Game.timer_scale()).
## Wrong letter -> PENALTY_BUBBLES. Time out -> PENALTY_TIMEOUT and progress resets. Solved -> REWARD_BUBBLES.
## Skill "autocomplete": the next correct letter's bubble shimmers. Contract: docs/ARCHITECTURE.md section 5.
## Look: angular "sharp kit" (see the SHARP KIT section at the end of this file).

signal finished(result: Dictionary)

const Style := preload("res://scripts/ui/style.gd")

const W := 1280.0
const H := 720.0
const INK := Color("2a1a10")
const POOL := Rect2(0, 270, 1280, 450)
const MARGIN := 70.0          # bubbles wrap this far outside the pool rect

var _data := {}
var _word := "GARDEN"
var _need: Array[String] = []      # required letters, in order (spaces skipped)
var _progress := 0
var _bubbles: Array = []
var _time_total := 60.0
var _time_left := 60.0
var _running := false
var _done := false
var _gen := 0
var _k := 1.0
var _auto_wrong := false
var _time := 0.0
var _last_tick := -1
var _hover := -1
var _shimmer := -1

var _stage: Control
var _pool: Control
var _steam_layer: Control
var _fx: Control
var _overlay: Control
var _steam: Array = []

var _slots: Array[Panel] = []
var _slot_labels: Array[Label] = []
var _slot_row: Control
var _timer_panel: Panel
var _timer_bar: Control
var _timer_f := 1.0
var _timer_col := Style.AQUA
var _timer_label: Label
var _prompt_panel: Panel
var _badge: Control


# =================================================================== setup
func setup(data: Dictionary) -> void:
	_data = data
	_word = str(data.get("answer", "GARDEN")).to_upper().strip_edges()
	if _word == "":
		_word = "?"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_k = 0.12 if Game.autotest and not Game.autotest_slow else 1.0
	_auto_wrong = Game.autotest and Game.debug_minigame != ""
	if _data.is_empty():
		setup({"answer": "GARDEN", "decoys": "SPTOHLKW", "time": 60.0, "prompt": "___"})
	for i in _word.length():
		if _word[i] != " ":
			_need.append(_word[i])
	_time_total = maxf(5.0, float(_data.get("time", 60.0))) * Game.timer_scale()
	_time_left = _time_total
	_kit_backdrop(0.46)
	_pool = Control.new()
	_pool.position = POOL.position
	_pool.size = POOL.size
	_pool.clip_contents = true
	_pool.mouse_filter = Control.MOUSE_FILTER_STOP
	_pool.draw.connect(_draw_pool)
	_pool.gui_input.connect(_on_pool_input)
	add_child(_pool)
	_steam_layer = _layer()
	_steam_layer.draw.connect(_draw_steam)
	_stage = _layer()
	_fx = _layer()
	_fx.draw.connect(_kit_draw)
	_overlay = _layer()
	_kit_top_layers()
	_badge = _kit_badge("BUBBLE LETTERS")
	_build_timer()
	_build_prompt()
	_build_slots()
	_spawn_bubbles()
	for i in 14:
		_steam.append(_new_puff(true))
	_intro()


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


# =================================================================== UI
func _build_timer() -> void:
	_timer_panel = Panel.new()
	_timer_panel.position = Vector2(934, 12)
	_timer_panel.size = Vector2(318, 56)
	_timer_panel.pivot_offset = _timer_panel.size * 0.5
	_timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_panel.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.025, 0.12, 0.95), Style.AQUA, 3, 12, 0.36, HARD_SHADOW, Vector2(7, 6)))
	_stage.add_child(_timer_panel)
	var tl := Style.label("TIME", 13, Style.AQUA, true)
	tl.position = Vector2(26, 5)
	_timer_panel.add_child(tl)
	_timer_bar = Control.new()
	_timer_bar.position = Vector2(18, 26)
	_timer_bar.size = Vector2(196, 18)
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bar.draw.connect(_draw_timer_bar)
	_timer_panel.add_child(_timer_bar)
	_timer_label = Style.title_label("60", 34, Color.WHITE, NEAR_BLACK, 8)
	_timer_label.position = Vector2(218, 4)
	_timer_label.size = Vector2(90, 48)
	_timer_label.pivot_offset = Vector2(45, 24)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_panel.add_child(_timer_label)
	_update_timer()


## Slanted segmented time bar.
func _draw_timer_bar() -> void:
	var sz := _timer_bar.size
	var s := sz.y * 0.5
	_timer_bar.draw_colored_polygon(_kit_quad(sz.x, sz.y, s, 0.0), Color(0.02, 0.01, 0.06, 1.0))
	var fw := maxf(0.0, (sz.x - s - 4.0) * _timer_f)
	if fw > 1.0:
		_timer_bar.draw_colored_polygon(PackedVector2Array([Vector2(s + 2, 3), Vector2(s + 2 + fw, 3), Vector2(2 + fw, sz.y - 3), Vector2(2, sz.y - 3)]), _timer_col)
	# segment ticks
	var x := 18.0
	while x < sz.x - s:
		_timer_bar.draw_line(Vector2(x + s, 2), Vector2(x, sz.y - 2), Color(0.02, 0.01, 0.06, 0.8), 2.0)
		x += 18.0
	var o := _kit_quad(sz.x, sz.y, s, 0.0)
	o.append(o[0])
	_timer_bar.draw_polyline(o, Style.AQUA_DEEP, 2.0, true)


func _build_prompt() -> void:
	var p := Panel.new()
	p.position = Vector2(40, 84)
	p.size = Vector2(1200, 98)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.025, 0.12, 0.95), Style.AQUA, 3, 20, 0.05, HARD_SHADOW, Vector2(9, 9)))
	_stage.add_child(p)
	_prompt_panel = p
	_kit_stripes(p, Vector2(1100, 70), 5, Color(Style.YUZU, 0.5), Vector2(5, 18), 11.0)
	# slanted "?" plate
	var q := Control.new()
	q.position = Vector2(16, 14)
	q.size = Vector2(80, 70)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.draw.connect(func() -> void:
		var pts := _kit_quad(80, 70, 18, 12)
		var sh := PackedVector2Array()
		for v in pts:
			sh.append(v + Vector2(5, 5))
		q.draw_colored_polygon(sh, HARD_SHADOW)
		q.draw_colored_polygon(pts, Style.YUZU)
		var o := pts.duplicate()
		o.append(pts[0])
		q.draw_polyline(o, Color.WHITE, 3.0, true))
	p.add_child(q)
	var ql := Style.title_label("?", 46, Color.WHITE, INK, 8)
	ql.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ql.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.add_child(ql)
	var prompt := str(_data.get("prompt", ""))
	var plain := prompt.replace("___", "______")
	var box := Vector2(1060, 78)
	var fs := _fit(Style.body_font(), plain, box, 26, 15)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_size_override("normal_font_size", fs)
	rt.add_theme_font_size_override("bold_font_size", fs)
	rt.fit_content = true
	rt.position = Vector2(112, 10)
	rt.size = Vector2(box.x, 0)
	rt.text = Style.markup(prompt).replace("___", "[color=#ffb347][b]______[/b][/color]")
	p.add_child(rt)
	# vertically centre once the text has been laid out
	rt.resized.connect(func() -> void: rt.position.y = maxf(6.0, (p.size.y - rt.size.y) * 0.5))


func _build_slots() -> void:
	_slot_row = Control.new()
	_slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_slot_row)
	var n := _word.length()
	var sw := clampf(840.0 / n - 10.0, 40.0, 64.0)
	var sh := 70.0
	var gap := 12.0
	var total := 0.0
	for i in n:
		total += (sw * 0.45 if _word[i] == " " else sw) + (gap if i < n - 1 else 0.0)
	var x := (W - total) * 0.5
	for i in n:
		if _word[i] == " ":
			x += sw * 0.45 + gap
			continue
		var s := Panel.new()
		s.position = Vector2(x, 192)
		s.size = Vector2(sw, sh)
		s.pivot_offset = s.size * 0.5
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(s)
		var l := Style.title_label("", int(sw * 0.72), Style.GOLD, INK, 10)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		s.add_child(l)
		_slots.append(s)
		_slot_labels.append(l)
		x += sw + gap
	_refresh_slots()


func _slot_style(bg: Color, border: Color, bw: int, shadow: Color = HARD_SHADOW) -> StyleBoxFlat:
	return _sb(bg, border, bw, 10, 0.14, shadow, Vector2(6, 6))


func _refresh_slots() -> void:
	for i in _slots.size():
		var st: StyleBoxFlat
		if i < _progress:
			st = _slot_style(Color(0.32, 0.18, 0.04, 0.97), Style.GOLD, 3)
		elif i == _progress and not _done:
			st = _slot_style(Color(0.12, 0.07, 0.26, 0.97), Style.YUZU, 4, Color(Style.AQUA, 0.9))
		else:
			st = _slot_style(Color(0.05, 0.03, 0.12, 0.95), Style.AQUA_DEEP, 3)
		_slots[i].add_theme_stylebox_override("panel", st)


func _update_timer() -> void:
	var f := clampf(_time_left / _time_total, 0.0, 1.0)
	var secs := ceili(maxf(_time_left, 0.0))
	_timer_label.text = str(secs)
	var col := Style.AQUA
	if _time_left <= 10.0:
		col = Style.DANGER
	elif f < 0.5:
		col = Style.YUZU
	if absf(f - _timer_f) > 0.002 or col != _timer_col:
		_timer_f = f
		_timer_col = col
		_timer_bar.queue_redraw()
	_timer_label.add_theme_color_override("font_color", Color.WHITE if _time_left > 10.0 else Style.DANGER.lightened(0.3))


## Largest font size (max_s..min_s) whose wrapped text fits into box.
func _fit(font: Font, text: String, box: Vector2, max_s: int, min_s: int) -> int:
	var s := max_s
	while s > min_s:
		var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box.x - 4.0, s)
		if sz.y * 1.12 <= box.y:
			return s
		s -= 1
	return min_s


# =================================================================== bubbles
func _spawn_bubbles() -> void:
	var letters: Array[String] = []
	for i in _need.size():
		letters.append(_need[i])
	var decoys := str(_data.get("decoys", "")).to_upper()
	for i in decoys.length():
		if decoys[i] != " ":
			letters.append(decoys[i])
	var answer_flags: Array[int] = []
	for i in letters.size():
		answer_flags.append(i if i < _need.size() else -1)
	var order: Array = range(letters.size())
	order.shuffle()
	var n := letters.size()
	var lanes := clampi(ceili(n / 2.0), 1, 9)
	var per := ceili(float(n) / lanes)
	var cycle := POOL.size.y + MARGIN * 2.0
	var lane_off: Array[float] = []
	var lane_spd: Array[float] = []
	for l in lanes:
		lane_off.append(randf() * cycle)
		lane_spd.append(randf_range(34.0, 56.0) / Game.timer_scale())
	for j in n:
		var i: int = order[j]
		var lane := j % lanes
		var slot := j / lanes
		var x0 := 84.0 + lane * ((W - 168.0) / maxf(lanes - 1, 1)) + randf_range(-16.0, 16.0)
		var y := -MARGIN + fposmod(lane_off[lane] + slot * cycle / per, cycle)
		_bubbles.append({
			"letter": letters[i], "need": answer_flags[i], "x0": x0, "y": y, "spd": lane_spd[lane],
			"ph": randf() * TAU, "wa": randf_range(12.0, 24.0), "wf": randf_range(0.8, 1.5),
			"r": randf_range(40.0, 46.0), "state": "live", "t": 0.0, "red": 0.0, "cool": 0.0,
			"pos": Vector2(x0, y), "rad": 44.0,
		})


func _update_bubbles(delta: float) -> void:
	var cycle := POOL.size.y + MARGIN * 2.0
	for i in _bubbles.size():
		var b: Dictionary = _bubbles[i]
		var y: float = b["y"] - float(b["spd"]) * delta
		if y < -MARGIN:
			y += cycle
		b["y"] = y
		var wob := sin(_time * float(b["wf"]) + float(b["ph"])) * float(b["wa"])
		var jig := sin(_time * 70.0) * 7.0 * float(b["red"])
		b["pos"] = Vector2(float(b["x0"]) + wob + jig, y)
		var r: float = b["r"] * (1.0 + 0.035 * sin(_time * 2.4 + float(b["ph"])))
		if i == _hover and b["state"] == "live":
			r *= 1.08
		b["rad"] = r
		b["red"] = maxf(0.0, float(b["red"]) - delta * 1.8)
		b["cool"] = maxf(0.0, float(b["cool"]) - delta)
		if b["state"] == "pop":
			b["t"] = float(b["t"]) + delta
			if b["t"] > 0.2:
				b["state"] = "gone"
	# autocomplete: the next needed letter's bubble shimmers (prefer one that is on screen)
	_shimmer = -1
	if Game.has_skill("autocomplete") and _progress < _need.size() and not _done:
		var want := _need[_progress]
		var best := 1e9
		for i in _bubbles.size():
			var b: Dictionary = _bubbles[i]
			if b["state"] != "live" or b["letter"] != want:
				continue
			var y: float = b["y"]
			var score := absf(y - POOL.size.y * 0.5)
			if y < 0.0 or y > POOL.size.y:
				score += 10000.0
			if score < best:
				best = score
				_shimmer = i


func _bubble_at(local: Vector2) -> int:
	var best := -1
	var best_d := 1e9
	for i in _bubbles.size():
		var b: Dictionary = _bubbles[i]
		if b["state"] != "live":
			continue
		var d := local.distance_to(b["pos"])
		if d < float(b["rad"]) * 1.06 and d < best_d:
			best_d = d
			best = i
	return best


func _on_pool_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm:
		var h := _bubble_at(mm.position)
		if h != _hover:
			_hover = h
			_pool.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h >= 0 else Control.CURSOR_ARROW
		return
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var i := _bubble_at(mb.position)
		if i >= 0:
			_try_pop(i)
		accept_event()


func _try_pop(i: int) -> void:
	if not _running or _done:
		return
	var b: Dictionary = _bubbles[i]
	if b["state"] != "live" or float(b["cool"]) > 0.0:
		return
	var gpos: Vector2 = POOL.position + (b["pos"] as Vector2)
	if b["letter"] == _need[_progress]:
		var slot_i := _progress
		_progress += 1
		b["state"] = "pop"
		b["t"] = 0.0
		Audio.sfx("pop", 0.9 + 0.07 * _progress)
		_splash(gpos, float(b["rad"]))
		_fly_letter(str(b["letter"]), gpos, slot_i)
		_refresh_slots()
		if _progress >= _need.size():
			_solved()
	else:
		b["red"] = 1.0
		b["cool"] = 0.45
		Audio.sfx("wrong", 1.15, -3.0)
		Game.mistake(Game.PENALTY_BUBBLES)
		_kit_glitch(0.2, 0.65)
		_kit_flash(Style.DANGER, 0.22, 0.3)
		_kit_shake(6.0, 0.2)
		_kit_shards(gpos, Style.DANGER, 8, 300.0)
		_kit_stamp("WRONG!", Style.DANGER, gpos + Vector2(0, -66), 40, 0.22, 5.0)
		_kit_jolt(_slot_row, 6.0)
		for s in _slots:
			_kit_jolt(s, 5.0)


func _fly_letter(letter: String, from: Vector2, slot_i: int) -> void:
	if slot_i >= _slots.size():
		return
	var g := _gen
	var target: Panel = _slots[slot_i]
	var l := Style.title_label(letter, 48, Style.GOLD, INK, 10)
	l.size = Vector2(80, 70)
	l.pivot_offset = Vector2(40, 35)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = from - l.size * 0.5
	l.scale = Vector2(1.5, 1.5)
	_overlay.add_child(l)
	var to := target.position + target.size * 0.5 - l.size * 0.5
	var mid := (l.position + to) * 0.5 + Vector2(randf_range(-80, 80), -60)
	var dur := 0.3 * maxf(_k, 0.4)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_fly_step.bind(l, from - l.size * 0.5, mid, to), 0.0, 1.0, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, dur)
	tw.tween_property(l, "rotation", TAU, dur)
	tw.chain().tween_callback(_land_letter.bind(l, slot_i, g))


func _fly_step(t: float, l: Label, a: Vector2, b: Vector2, c: Vector2) -> void:
	l.position = _bez(a, b, c, t)


func _bez(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


func _land_letter(l: Label, slot_i: int, g: int) -> void:
	var letter := l.text
	l.queue_free()
	if g != _gen or slot_i >= _slots.size():
		return
	_slot_labels[slot_i].text = letter
	var s := _slots[slot_i]
	s.scale = Vector2(1.4, 1.4)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var c := s.position + s.size * 0.5
	_kit_burst(c, Style.GOLD, 6, 240.0)
	_kit_shards(c, Style.YUZU, 5, 260.0)
	_kit_shake(3.0, 0.12)
	Audio.sfx("select", 1.2 + slot_i * 0.06, -6.0)


# =================================================================== flow
func _intro() -> void:
	Audio.sfx("splash")
	_kit_wipe(Color(Style.AQUA, 0.22), 0.34)
	var tp := _timer_panel.position
	_timer_panel.position = tp + Vector2(380, -30)
	_tw(_timer_panel, "position", tp, 0.28, 0.04)
	var pp := _prompt_panel.position
	_prompt_panel.modulate.a = 0.0
	_prompt_panel.position = pp + Vector2(80, -40)
	_tw(_prompt_panel, "position", pp, 0.26, 0.06)
	_tw(_prompt_panel, "modulate:a", 1.0, 0.16, 0.06)
	for i in _slots.size():
		var s := _slots[i]
		s.scale = Vector2.ZERO
		s.rotation = -0.4
		_tw(s, "scale", Vector2.ONE, 0.22, 0.14 + i * 0.045)
		_tw(s, "rotation", 0.0, 0.22, 0.14 + i * 0.045)
	_pool.modulate.a = 0.0
	_tw(_pool, "modulate:a", 1.0, 0.35)
	_kit_splash(Vector2(W * 0.5, POOL.position.y + 20), 18, 520.0)
	await _sleep(0.5 * _k)
	_toast("POP THE LETTERS IN ORDER!", Vector2(W * 0.5, 304), Style.AQUA, 30, 1.4)
	_running = true
	if Game.autotest:
		_autoplay()


func _tw(n: Object, prop: String, val: Variant, dur: float, delay: float = 0.0) -> void:
	var tw := create_tween()
	tw.tween_property(n, prop, val, dur * _k).set_delay(delay * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _timeout() -> void:
	_running = false
	_gen += 1
	Audio.sfx("wrong")
	Audio.sfx("static", 1.0, -8.0)
	_kit_error(Vector2(W * 0.5, 230))
	Game.mistake(Game.PENALTY_TIMEOUT)
	_kit_stamp("TIME'S UP!", Style.DANGER, Vector2(W * 0.5, 430), 100, 1.1)
	# letters drop out of the slots
	for i in _slot_labels.size():
		var l := _slot_labels[i]
		if l.text == "":
			continue
		var ghost := Style.title_label(l.text, int(l.get_theme_font_size("font_size")), Style.GOLD, INK, 10)
		ghost.position = _slots[i].position
		ghost.size = _slots[i].size
		ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_overlay.add_child(ghost)
		l.text = ""
		var tw := create_tween().set_parallel(true)
		tw.tween_property(ghost, "position:y", ghost.position.y + 220.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(ghost, "rotation", randf_range(-1.2, 1.2), 0.5)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(ghost.queue_free)
	_progress = 0
	_refresh_slots()
	# popped answer bubbles float back up from the bottom
	var cycle := POOL.size.y + MARGIN * 2.0
	var j := 0
	for b in _bubbles:
		if b["state"] != "live":
			b["state"] = "live"
			b["t"] = 0.0
			b["y"] = POOL.size.y + MARGIN * 0.6 + j * 37.0
			if b["y"] > cycle - MARGIN:
				b["y"] = POOL.size.y
			j += 1
	await _sleep(1.4 * _k)
	if _done:
		return
	_time_left = _time_total
	_last_tick = -1
	_update_timer()
	_toast("TRY AGAIN!", Vector2(W * 0.5, 320), Style.YUZU, 36, 1.0)
	_running = true


func _solved() -> void:
	_running = false
	_done = true
	_refresh_slots()
	Audio.sfx("correct")
	Audio.sfx("splash", 1.1, -4.0)
	Game.reward(Game.REWARD_BUBBLES)
	var row_c := Vector2(W * 0.5, 227)
	await _sleep(0.3 * _k)
	_kit_impact(row_c, Style.GOLD)
	# the word glows: slots slam gold one after another
	for i in _slots.size():
		var s := _slots[i]
		s.add_theme_stylebox_override("panel", _slot_style(Color(0.58, 0.36, 0.04, 0.98), Color.WHITE, 4, Color(Style.AQUA, 0.95)))
		_slot_labels[i].add_theme_color_override("font_color", Color.WHITE)
		var tw := create_tween()
		tw.tween_interval(i * 0.05 * _k)
		tw.tween_property(s, "scale", Vector2.ONE * 1.3, 0.08 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector2.ONE * 1.08, 0.18 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_kit_burst(s.position + s.size * 0.5, Style.GOLD, 6, 300.0)
	_kit_stamp("CORRECT!", Style.GOLD, Vector2(W * 0.5, 470), 110)
	# remaining bubbles pop in a cascade
	var live: Array = []
	for b in _bubbles:
		if b["state"] == "live":
			live.append(b)
	live.shuffle()
	for b in live:
		await _sleep(0.07 * _k)
		b["state"] = "pop"
		b["t"] = 0.0
		Audio.sfx("pop", randf_range(0.8, 1.5), -6.0)
		_splash(POOL.position + (b["pos"] as Vector2), float(b["rad"]))
	await _sleep(1.0 * _k)
	var tw2 := create_tween()
	tw2.tween_property(self, "modulate:a", 0.0, 0.25 * _k)
	await tw2.finished
	finished.emit({})


# =================================================================== autotest
func _autoplay() -> void:
	var step := 0.9 if Game.autotest_slow else 0.3
	await _sleep(step)
	if _auto_wrong:
		for i in _bubbles.size():
			if _bubbles[i]["need"] == -1 and not _need.has(str(_bubbles[i]["letter"])):
				_try_pop(i)
				break
		await _sleep(step)
	while not _done and is_inside_tree():
		if _running:
			var want := _need[_progress]
			for i in _bubbles.size():
				var b: Dictionary = _bubbles[i]
				if b["state"] == "live" and b["letter"] == want:
					_try_pop(i)
					break
		await _sleep(step)


# =================================================================== frame
func _process(delta: float) -> void:
	_time += delta
	_kit_tick(delta)
	_pool.position = POOL.position + _stage.position
	_update_bubbles(delta)
	_update_steam(delta)
	if _running:
		_time_left -= delta
		var secs := ceili(_time_left)
		if _time_left <= 10.0 and secs != _last_tick and secs >= 0:
			_last_tick = secs
			Audio.sfx("tick", 1.0 if secs > 3 else 1.25)
			_timer_label.scale = Vector2(1.4, 1.4)
			var tw := _timer_label.create_tween()
			tw.tween_property(_timer_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			_kit_jolt(_timer_panel, 3.0 if secs > 3 else 6.0)
		_update_timer()
		if _time_left <= 0.0:
			_time_left = 0.0
			_update_timer()
			_timeout()
	# next-slot pulse
	if not _done and _progress < _slots.size():
		var s := _slots[_progress]
		var k := 1.0 + 0.05 * sin(_time * 6.0)
		if s.scale.x < 1.1:
			s.scale = Vector2(k, k)
	_pool.queue_redraw()
	_steam_layer.queue_redraw()


# =================================================================== drawing
func _draw_pool() -> void:
	var sz := _pool.size
	# water body
	var top := Color(0.10, 0.55, 0.62, 0.30)
	var bot := Color(0.02, 0.13, 0.24, 0.78)
	_pool.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(0, sz.y)]),
		PackedColorArray([top, top, bot, bot]))
	# slanted light shafts through the water
	for j in 5:
		var x := fposmod(j * 300.0 + _time * 22.0, sz.x + 400.0) - 200.0
		var wv := 60.0 + 30.0 * (j % 2)
		_pool.draw_colored_polygon(PackedVector2Array([Vector2(x + 160, 0), Vector2(x + 160 + wv, 0), Vector2(x + wv, sz.y), Vector2(x, sz.y)]),
			Color(0.6, 1.0, 0.95, 0.035 + 0.015 * (j % 2)))
	# caustic light ribbons
	for j in 4:
		var pts := PackedVector2Array()
		var yb := 70.0 + j * 105.0
		for i in 33:
			var x := i * sz.x / 32.0
			pts.append(Vector2(x, yb + sin(x * 0.012 + _time * (0.8 + j * 0.2) + j) * 14.0))
		_pool.draw_polyline(pts, Color(0.5, 1.0, 0.95, 0.05 + 0.02 * (j % 2)), 10.0, true)
	# surface: hard aqua edge + waves + stripe ticks
	_pool.draw_rect(Rect2(0, 0, sz.x, 4), Color(Style.AQUA, 0.65))
	for layer in 2:
		var pts2 := PackedVector2Array()
		for i in 65:
			var x := i * sz.x / 64.0
			pts2.append(Vector2(x, 9.0 + layer * 7.0 + sin(x * 0.02 + _time * (2.0 - layer * 0.7)) * 4.0))
		_pool.draw_polyline(pts2, Color(0.75, 1.0, 1.0, 0.7 - layer * 0.4), 3.0 - layer, true)
	var font := Style.display_font()
	for i in _bubbles.size():
		var b: Dictionary = _bubbles[i]
		var st: String = b["state"]
		if st == "gone":
			continue
		var p: Vector2 = b["pos"]
		var r: float = b["rad"]
		if st == "pop":
			var t := clampf(float(b["t"]) / 0.2, 0.0, 1.0)
			_pool.draw_arc(p, r * (1.0 + t * 1.3), 0.0, TAU, 40, Color(0.9, 1.0, 1.0, 1.0 - t), 5.0 * (1.0 - t) + 1.0, true)
			continue
		var red: float = b["red"]
		if i == _shimmer:
			var pulse := 0.5 + 0.5 * sin(_time * 7.0)
			_pool.draw_circle(p, r * (1.32 + 0.08 * pulse), Color(Style.GOLD, 0.10 + 0.12 * pulse))
			_pool.draw_arc(p, r * (1.18 + 0.06 * pulse), 0.0, TAU, 48, Color(Style.GOLD, 0.55 + 0.4 * pulse), 4.0, true)
			for s in 4:
				var a := _time * 2.2 + s * TAU / 4.0
				_draw_star(_pool, p + Vector2.from_angle(a) * r * 1.32, 7.0 + 3.0 * pulse, _time * 4.0, Color(1, 0.95, 0.7, 0.9))
		_pool.draw_circle(p + Vector2(6, 8), r, Color(NEAR_BLACK, 0.28))
		var body := Color(0.55, 0.92, 1.0, 0.20).lerp(Color(1.0, 0.3, 0.35, 0.5), red)
		_pool.draw_circle(p, r, body)
		_pool.draw_circle(p + Vector2(r * 0.12, r * 0.16), r * 0.78, Color(0.25, 0.75, 0.95, 0.12))
		var rim := Color(0.88, 1.0, 1.0, 0.9).lerp(Style.DANGER, red)
		if i == _hover:
			rim = Style.GOLD.lerp(Style.DANGER, red)
		_pool.draw_arc(p, r, 0.0, TAU, 48, rim, 3.0 if i != _hover else 4.5, true)
		_pool.draw_arc(p, r - 5.0, PI * 0.15, PI * 0.65, 16, Color(0.75, 0.6, 1.0, 0.45), 3.0, true)
		_pool.draw_arc(p, r - 5.0, PI * 0.95, PI * 1.35, 16, Color(0.5, 1.0, 0.9, 0.45), 3.0, true)
		_pool.draw_circle(p + Vector2(-r * 0.40, -r * 0.42), r * 0.17, Color(1, 1, 1, 0.85))
		_pool.draw_circle(p + Vector2(-r * 0.12, -r * 0.60), r * 0.07, Color(1, 1, 1, 0.7))
		if i == _hover:
			_draw_reticle(p, r * 1.22, Style.GOLD.lerp(Style.DANGER, red))
		var fs := int(r * 0.95)
		var base := p + Vector2(-r, fs * 0.36)
		_pool.draw_string_outline(font, base, str(b["letter"]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 8, Color(0.02, 0.1, 0.18, 0.9))
		_pool.draw_string(font, base, str(b["letter"]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs,
			Color.WHITE.lerp(Style.DANGER.lightened(0.4), red) if i != _shimmer else Color(1, 0.95, 0.75))


## Angular corner brackets around the hovered bubble.
func _draw_reticle(p: Vector2, r: float, col: Color) -> void:
	var l := r * 0.42
	for c in 4:
		var sx := -1.0 if c % 2 == 0 else 1.0
		var sy := -1.0 if c < 2 else 1.0
		var corner := p + Vector2(sx * r, sy * r)
		_pool.draw_colored_polygon(PackedVector2Array([corner, corner - Vector2(sx * l, 0), corner - Vector2(sx * l, sy * 5.0), corner - Vector2(sx * 5.0, sy * 5.0), corner - Vector2(sx * 5.0, sy * l), corner - Vector2(0, sy * l)]), col)


func _new_puff(initial: bool) -> Dictionary:
	return {
		"x": randf_range(-60.0, W + 60.0),
		"y": randf_range(150.0, H) if initial else randf_range(POOL.position.y + 40.0, H + 40.0),
		"r": randf_range(50.0, 120.0), "spd": randf_range(12.0, 26.0), "drift": randf_range(-10.0, 10.0),
		"life": 0.0, "max": randf_range(7.0, 13.0),
	}


func _update_steam(delta: float) -> void:
	for i in _steam.size():
		var s: Dictionary = _steam[i]
		s["y"] = float(s["y"]) - float(s["spd"]) * delta
		s["x"] = float(s["x"]) + float(s["drift"]) * delta
		s["life"] = float(s["life"]) + delta
		if s["life"] > s["max"] or float(s["y"]) < 60.0:
			_steam[i] = _new_puff(false)


func _draw_steam() -> void:
	for s in _steam:
		var t: float = float(s["life"]) / float(s["max"])
		var a := sin(t * PI) * 0.016
		var p := Vector2(s["x"], s["y"])
		var r: float = float(s["r"]) * (0.8 + t * 0.6)
		for k in 6:
			_steam_layer.draw_circle(p + Vector2(k * 3.0, -k * 2.0), r * (1.0 - k * 0.14), Color(0.92, 0.96, 1.0, a))


func _draw_star(ci: CanvasItem, pos: Vector2, r: float, rot: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var rr := r if i % 2 == 0 else r * 0.38
		pts.append(pos + Vector2.from_angle(rot + i * TAU / 8.0) * rr)
	ci.draw_colored_polygon(pts, c)


# =================================================================== effects
func _sleep(t: float) -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(t, 0.001))
	await tw.finished


func _splash(pos: Vector2, r: float) -> void:
	_kit_splash(pos, 12, 340.0)
	_kit_ring(pos, Color(0.85, 1.0, 1.0), r * 2.2, 0.32)
	_kit_shards(pos, Color(0.8, 1.0, 1.0, 0.9), 4, 260.0)


## A slanted band toast that slides in from the right, holds, and slides out to the left.
func _toast(text: String, center: Vector2, col: Color, size: int, hold: float = 0.4) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = center
	_overlay.add_child(holder)
	var font := Style.display_font()
	var tw_ := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var bh := size * 1.5
	var bw := tw_ + 120.0
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = Vector2(-bw * 0.5, -bh * 0.5)
	band.size = Vector2(bw, bh)
	band.draw.connect(func() -> void:
		var q := _kit_quad(bw, bh, bh * 0.4, bh * 0.22)
		var sh := PackedVector2Array()
		for v in q:
			sh.append(v + Vector2(7, 7))
		band.draw_colored_polygon(sh, HARD_SHADOW)
		band.draw_colored_polygon(q, Color(0.06, 0.03, 0.14, 0.94))
		var o := q.duplicate()
		o.append(q[0])
		band.draw_polyline(o, col, 3.0, true))
	holder.add_child(band)
	var l := Style.title_label(text, size, col, NEAR_BLACK, 9)
	l.size = Vector2(bw, bh)
	l.position = Vector2(-bw * 0.5, -bh * 0.5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	holder.position.x = center.x + 900.0
	_kit_hlines(Rect2(0, center.y - bh * 0.5, W, bh), Color(col, 0.5), 0.3, 10)
	var tw := create_tween()
	tw.tween_property(holder, "position:x", center.x, 0.2 * maxf(_k, 0.5)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold * _k)
	tw.tween_property(holder, "position:x", center.x - 1000.0, 0.22 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(holder.queue_free)

# =================================================================== SHARP KIT
# Shared visual kit (identical copy in choice.gd, bubbles.gd, rewind.gd and vote.gd so every file
# stays self-contained): angular styleboxes, night backdrop + vignette, slanted title badge, glitch
# shader, flash, screen shake, particles (shards, water drops, stars, rings), speed lines, diagonal
# wipes, the slam stamp and a screen shatter. The host script provides _k, _stage, _fx and _overlay,
# connects _fx.draw to _kit_draw and calls _kit_tick(delta) from _process.

const NIGHT := Color("120a24")
const NEAR_BLACK := Color("07040f")
const HARD_SHADOW := Color(0.027, 0.016, 0.059, 0.92)
const GLITCH_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform float seed = 0.0;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(seed * 24.0);
	float band = floor(uv.y * 22.0 + rnd(vec2(t, 3.0)) * 5.0);
	float r = rnd(vec2(band, t));
	float shift = r > 0.7 ? (rnd(vec2(t, band)) - 0.5) * 0.09 * amount : 0.0;
	shift += (rnd(vec2(floor(uv.y * 150.0), t)) - 0.5) * 0.007 * amount;
	uv.x += shift;
	float sp = 0.009 * amount;
	vec3 col = vec3(texture(screen_tex, uv + vec2(sp, 0.0)).r, texture(screen_tex, uv).g, texture(screen_tex, uv - vec2(sp, 0.0)).b);
	col *= 1.0 - 0.24 * amount * step(0.5, fract(FRAGCOORD.y * 0.5));
	col = mix(col, vec3(rnd(uv * 517.0 + t)), 0.09 * amount);
	col = mix(col, vec3(1.0, 0.31, 0.43), 0.24 * amount * step(0.86, r));
	COLOR = vec4(col, 1.0);
}
"""

static var _kit_shader: Shader = null
static var _kit_vig: GradientTexture2D = null

var _kit_parts: Array = []
var _kit_lines: Array = []
var _kit_time := 0.0
var _kit_glitch_rect: ColorRect = null
var _kit_flash_rect: ColorRect = null
var _kit_flash_tw: Tween = null
var _kit_glitch_left := 0.0
var _kit_glitch_len := 0.3
var _kit_glitch_peak := 0.0
var _kit_shake_left := 0.0
var _kit_shake_len := 0.3
var _kit_shake_amt := 0.0


## Angular stylebox: chamfered top-left / bottom-right corners, optional skew, hard offset shadow.
func _sb(bg: Color, border: Color, bw: int = 3, cut: int = 14, skew: float = 0.0,
		shadow: Color = HARD_SHADOW, shadow_off: Vector2 = Vector2(7, 7)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.corner_detail = 1
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_radius_top_right = 0
	s.corner_radius_bottom_left = 0
	s.skew = Vector2(skew, 0.0)
	if shadow.a > 0.0:
		s.shadow_color = shadow
		s.shadow_size = 1
		s.shadow_offset = shadow_off
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.anti_aliasing = true
	return s


## Parallelogram (top edge shifted right by s) with chamfered top-left / bottom-right corners.
func _kit_quad(w: float, h: float, s: float, cut: float) -> PackedVector2Array:
	var a := Vector2(s, 0)
	var b := Vector2(w, 0)
	var c := Vector2(w - s, h)
	var d := Vector2(0, h)
	if cut <= 0.0:
		return PackedVector2Array([a, b, c, d])
	return PackedVector2Array([a + (b - a).normalized() * cut, b, c + (b - c).normalized() * cut,
		c + (d - c).normalized() * cut, d, a + (d - a).normalized() * cut])


## Semi-transparent night backdrop (lets the courtroom behind show through) + vignette + slashes.
func _kit_backdrop(alpha: float, accent: Color = Style.AQUA) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_kit_draw_backdrop.bind(c, alpha, accent))
	add_child(c)
	if _kit_vig == null:
		var g := Gradient.new()
		g.set_color(0, Color(NEAR_BLACK, 0.0))
		g.set_color(1, Color(NEAR_BLACK, 0.88))
		g.add_point(0.5, Color(NEAR_BLACK, 0.08))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.02, 1.02)
		gt.width = 256
		gt.height = 144
		_kit_vig = gt
	var vg := TextureRect.new()
	vg.texture = _kit_vig
	vg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(vg)
	return c


func _kit_draw_backdrop(c: Control, alpha: float, accent: Color) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color(NIGHT, alpha))
	# two big diagonal slash bands
	c.draw_colored_polygon(PackedVector2Array([Vector2(-60, H), Vector2(380, 90), Vector2(470, 90), Vector2(30, H)]), Color(Style.VIOLET, 0.07))
	c.draw_colored_polygon(PackedVector2Array([Vector2(W - 330, H), Vector2(W + 40, 250), Vector2(W + 40, 300), Vector2(W - 280, H)]), Color(accent, 0.05))
	# stripe accents in the bottom corners
	for i in 7:
		var x := 18.0 + i * 20.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 44, H - 66), Vector2(x + 54, H - 66), Vector2(x + 10, H), Vector2(x, H)]), Color(accent, 0.13))
	for i in 7:
		var x := W - 170.0 + i * 20.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 44, H - 66), Vector2(x + 54, H - 66), Vector2(x + 10, H), Vector2(x, H)]), Color(Style.YUZU, 0.10))
	# hairline frame
	c.draw_line(Vector2(0, H - 3), Vector2(W, H - 3), Color(accent, 0.25), 2.0)


## Glitch overlay + flash, added last so they sit above everything the minigame draws.
func _kit_top_layers() -> void:
	if _kit_shader == null:
		_kit_shader = Shader.new()
		_kit_shader.code = GLITCH_CODE
	_kit_glitch_rect = ColorRect.new()
	_kit_glitch_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_kit_glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _kit_shader
	_kit_glitch_rect.material = m
	_kit_glitch_rect.visible = false
	add_child(_kit_glitch_rect)
	_kit_flash_rect = ColorRect.new()
	_kit_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_kit_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kit_flash_rect.color = Color.WHITE
	_kit_flash_rect.modulate.a = 0.0
	add_child(_kit_flash_rect)


func _kit_flash(col: Color, alpha: float = 0.6, dur: float = 0.35) -> void:
	if _kit_flash_rect == null:
		return
	if _kit_flash_tw and _kit_flash_tw.is_valid():
		_kit_flash_tw.kill()
	_kit_flash_rect.color = col
	_kit_flash_rect.modulate.a = alpha
	_kit_flash_tw = create_tween()
	_kit_flash_tw.tween_property(_kit_flash_rect, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _kit_glitch(dur: float = 0.3, amt: float = 1.0) -> void:
	if _kit_glitch_rect == null or Game.autotest and not Game.autotest_slow:
		return
	_kit_glitch_peak = maxf(_kit_glitch_peak if _kit_glitch_left > 0.0 else 0.0, amt)
	_kit_glitch_len = maxf(dur, 0.05)
	_kit_glitch_left = _kit_glitch_len
	_kit_glitch_rect.visible = true


func _kit_shake(s: float = 12.0, dur: float = 0.3) -> void:
	_kit_shake_amt = maxf(_kit_shake_amt if _kit_shake_left > 0.0 else 0.0, s)
	_kit_shake_len = maxf(dur, 0.05)
	_kit_shake_left = _kit_shake_len


## Quick tween shake of a single node (restores its position).
func _kit_jolt(n: Control, s: float = 10.0) -> void:
	if n == null or not is_instance_valid(n) or n.has_meta("jolt"):
		return
	var base := n.position
	n.set_meta("jolt", true)
	var tw := n.create_tween()
	for i in 6:
		tw.tween_property(n, "position", base + Vector2(randf_range(-s, s), randf_range(-s, s) * 0.5), 0.03)
	tw.tween_property(n, "position", base, 0.04)
	tw.tween_callback(n.remove_meta.bind("jolt"))


## Slanted title badge (top-left, stays left of the Convince Meter strip) with a diagonal wipe in.
func _kit_badge(title: String, sub: String = "SPLASH TRIAL") -> Control:
	var root := Control.new()
	root.position = Vector2(26, 12)
	root.size = Vector2(336, 56)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(root)
	var p := Panel.new()
	p.size = root.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _sb(Color(0.15, 0.06, 0.30, 0.98), Style.GOLD, 3, 12, 0.36, Color(Style.AQUA_DEEP, 0.95), Vector2(7, 6)))
	root.add_child(p)
	var accent := Control.new()
	accent.size = root.size
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.draw.connect(func() -> void:
		for i in 3:
			var x := 16.0 + i * 11.0
			accent.draw_colored_polygon(PackedVector2Array([Vector2(x + 14, 9), Vector2(x + 20, 9), Vector2(x + 6, 47), Vector2(x, 47)]), Color(Style.YUZU, 0.95 - i * 0.25))
		accent.draw_rect(Rect2(66, 21, 214, 2), Color(Style.AQUA, 0.35)))
	root.add_child(accent)
	var sl := Style.label(sub, 11, Style.AQUA, true)
	sl.position = Vector2(60, 4)
	sl.size = Vector2(260, 16)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sl)
	var fs := 27
	while fs > 16 and Style.display_font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 262.0:
		fs -= 1
	var t := Style.title_label(title, fs, Style.GOLD, NEAR_BLACK, 7)
	t.position = Vector2(58, 17)
	t.size = Vector2(268, 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(t)
	root.position = Vector2(-420, -40)
	var tw := create_tween()
	tw.tween_property(root, "position", Vector2(26, 12), 0.28 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return root


## Diagonal stripe accent (n slanted bars) added to parent.
func _kit_stripes(parent: Control, pos: Vector2, n: int, col: Color, bar: Vector2 = Vector2(7, 30), gap: float = 11.0) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = Vector2(n * gap + bar.x + bar.y * 0.45, bar.y)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		for i in n:
			var x := i * gap
			var s := bar.y * 0.45
			c.draw_colored_polygon(PackedVector2Array([Vector2(x + s, 0), Vector2(x + s + bar.x, 0), Vector2(x + bar.x, bar.y), Vector2(x, bar.y)]), col))
	parent.add_child(c)
	return c


## Slanted name tag in the character's colour.
func _kit_tag(text: String, col: Color, font_size: int = 22) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := _sb(col, Color.WHITE, 2, 8, 0.32, HARD_SHADOW, Vector2(4, 4))
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	tag.add_theme_stylebox_override("panel", st)
	tag.add_child(Style.label(text, font_size, NEAR_BLACK if col.get_luminance() > 0.45 else Color.WHITE, true))
	return tag


# ------------------------------------------------------------------ particles & lines
func _kit_add(kind: String, p: Vector2, v: Vector2, life: float, col: Color, size: float, g: float = 260.0, drag: float = 2.2) -> void:
	_kit_parts.append({"k": kind, "p": p, "v": v, "t": 0.0, "max": life, "c": col, "s": size,
		"r": randf() * TAU, "w": randf_range(-10.0, 10.0), "g": g, "d": drag})


func _kit_burst(pos: Vector2, col: Color, n: int = 18, spd: float = 360.0, star: bool = true) -> void:
	for i in n:
		var a := randf() * TAU
		_kit_add("star" if star else "dot", pos, Vector2.from_angle(a) * spd * randf_range(0.35, 1.0),
			randf_range(0.4, 0.8), col, randf_range(5.0, 12.0))


## Angular glassy shards flying out of an impact point.
func _kit_shards(pos: Vector2, col: Color, n: int = 16, spd: float = 560.0) -> void:
	for i in n:
		var a := randf() * TAU
		var c := col if i % 3 != 0 else (Color.WHITE if i % 2 == 0 else Style.AQUA)
		_kit_add("shard", pos + Vector2.from_angle(a) * randf_range(0.0, 18.0), Vector2.from_angle(a) * spd * randf_range(0.4, 1.0),
			randf_range(0.45, 0.8), c, randf_range(9.0, 22.0), 520.0, 2.6)


## Water droplets (teardrops stretched along their velocity) - hot-spring splash.
func _kit_splash(pos: Vector2, n: int = 14, spd: float = 380.0, col: Color = Color(0.78, 1.0, 1.0, 0.95)) -> void:
	for i in n:
		var a := -PI * 0.5 + randf_range(-1.35, 1.35)
		_kit_add("drop", pos, Vector2.from_angle(a) * spd * randf_range(0.45, 1.0), randf_range(0.45, 0.75), col, randf_range(5.0, 10.0), 900.0, 1.2)


func _kit_ring(pos: Vector2, col: Color, radius: float, dur: float = 0.45) -> void:
	_kit_add("ring", pos, Vector2.ZERO, dur, col, radius, 0.0, 0.0)


## Radial speed lines converging on center.
func _kit_speedlines(center: Vector2, col: Color, dur: float = 0.5, inner: float = 170.0, n: int = 44) -> void:
	_kit_lines.append({"m": "radial", "c": center, "col": col, "t": 0.0, "max": dur, "r0": inner, "n": n, "seed": randi() % 997})


## Horizontal speed streaks inside rect (for fast slides / scrolling strips).
func _kit_hlines(rect: Rect2, col: Color, dur: float = 0.5, n: int = 18) -> void:
	_kit_lines.append({"m": "horiz", "c": rect.position, "sz": rect.size, "col": col, "t": 0.0, "max": dur, "n": n, "seed": randi() % 997})


## A slanted colour band sweeping diagonally across the screen (entrances / transitions).
func _kit_wipe(col: Color, dur: float = 0.32, col2: Color = Style.YUZU) -> void:
	_kit_lines.append({"m": "wipe", "col": col, "col2": col2, "t": 0.0, "max": maxf(dur * _k, 0.05), "seed": 0})


## Impact combo for big CORRECT moments: white flash, ring, shards, splash, speed lines, shake.
func _kit_impact(pos: Vector2, col: Color = Style.GOLD) -> void:
	_kit_flash(Color(1.0, 0.97, 0.85), 0.85, 0.32)
	_kit_ring(pos, col, 320.0, 0.45)
	_kit_ring(pos, Style.AQUA, 200.0, 0.35)
	_kit_shards(pos, col, 22, 640.0)
	_kit_splash(pos, 16, 460.0)
	_kit_speedlines(pos, Color(1.0, 0.96, 0.85, 0.75), 0.55, 190.0)
	_kit_shake(13.0, 0.32)


## Error combo for WRONG answers: glitch jitter + coral flash + shake + coral shards.
func _kit_error(pos: Vector2) -> void:
	_kit_glitch(0.32, 1.0)
	_kit_flash(Style.DANGER, 0.42, 0.4)
	_kit_shake(15.0, 0.3)
	_kit_shards(pos, Style.DANGER, 10, 380.0)


func _kit_hash(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + 4.1414) * 43758.5453, 1.0)


func _kit_tick(delta: float) -> void:
	_kit_time += delta
	if _kit_shake_left > 0.0:
		_kit_shake_left -= delta
		var f := clampf(_kit_shake_left / _kit_shake_len, 0.0, 1.0)
		var a := _kit_shake_amt * f * f
		_stage.position = Vector2(randf_range(-a, a), randf_range(-a, a) * 0.6)
		if _kit_shake_left <= 0.0:
			_stage.position = Vector2.ZERO
			_kit_shake_amt = 0.0
	if _kit_glitch_left > 0.0 and _kit_glitch_rect:
		_kit_glitch_left -= delta
		var gm := _kit_glitch_rect.material as ShaderMaterial
		gm.set_shader_parameter("amount", _kit_glitch_peak * clampf(_kit_glitch_left / _kit_glitch_len, 0.0, 1.0) * randf_range(0.5, 1.0))
		gm.set_shader_parameter("seed", _kit_time)
		if _kit_glitch_left <= 0.0:
			_kit_glitch_rect.visible = false
			_kit_glitch_peak = 0.0
	var busy := not _kit_parts.is_empty() or not _kit_lines.is_empty()
	var n := _kit_parts.size()
	var i := 0
	while i < n:
		var p: Dictionary = _kit_parts[i]
		var t: float = float(p["t"]) + delta
		if t >= float(p["max"]):
			_kit_parts[i] = _kit_parts[n - 1]
			n -= 1
			continue
		p["t"] = t
		var v: Vector2 = p["v"]
		p["p"] = (p["p"] as Vector2) + v * delta
		p["v"] = v * maxf(0.0, 1.0 - float(p["d"]) * delta) + Vector2(0, float(p["g"]) * delta)
		p["r"] = float(p["r"]) + float(p["w"]) * delta
		i += 1
	_kit_parts.resize(n)
	n = _kit_lines.size()
	i = 0
	while i < n:
		var l: Dictionary = _kit_lines[i]
		l["t"] = float(l["t"]) + delta
		if float(l["t"]) >= float(l["max"]):
			_kit_lines[i] = _kit_lines[n - 1]
			n -= 1
			continue
		i += 1
	_kit_lines.resize(n)
	if busy:
		_fx.queue_redraw()


func _kit_draw() -> void:
	for l in _kit_lines:
		_kit_draw_line_fx(l)
	for p in _kit_parts:
		var t: float = float(p["t"]) / float(p["max"])
		var c: Color = p["c"]
		var pos: Vector2 = p["p"]
		var s: float = p["s"]
		var rot: float = p["r"]
		match str(p["k"]):
			"ring":
				c.a *= 1.0 - t
				var e := 1.0 - (1.0 - t) * (1.0 - t)
				_fx.draw_arc(pos, s * (0.2 + 0.8 * e), 0.0, TAU, 48, c, 12.0 * (1.0 - t) + 2.0, true)
			"shard":
				c.a *= 1.0 - t * t
				var k := s * (1.0 - t * 0.4)
				_fx.draw_colored_polygon(PackedVector2Array([pos + Vector2.from_angle(rot) * k,
					pos + Vector2.from_angle(rot + 2.25) * k * 0.45, pos + Vector2.from_angle(rot + 3.8) * k * 0.75]), c)
			"drop":
				c.a *= 1.0 - t
				var v: Vector2 = p["v"]
				var dir := v.normalized() if v.length_squared() > 1.0 else Vector2.DOWN
				var r := s * 0.5 * (1.0 - t * 0.4)
				var tail := clampf(v.length() * 0.035, r * 1.5, r * 5.0)
				var side := Vector2(-dir.y, dir.x) * r
				_fx.draw_colored_polygon(PackedVector2Array([pos - dir * tail, pos + side, pos - side]), c)
				_fx.draw_circle(pos, r, c)
			"star":
				c.a *= 1.0 - t * t
				var pts := PackedVector2Array()
				for j in 8:
					pts.append(pos + Vector2.from_angle(rot + j * TAU / 8.0) * s * (1.0 - t * 0.5) * (1.0 if j % 2 == 0 else 0.38))
				_fx.draw_colored_polygon(pts, c)
			_:
				c.a *= 1.0 - t
				_fx.draw_circle(pos, s * 0.6 * (1.0 - t * 0.5), c)


func _kit_draw_line_fx(l: Dictionary) -> void:
	var t: float = float(l["t"]) / float(l["max"])
	var col: Color = l["col"]
	var sd: int = l["seed"]
	var frame := int(_kit_time * 30.0)
	match str(l["m"]):
		"radial":
			var c: Vector2 = l["c"]
			var n: int = l["n"]
			var r0: float = l["r0"]
			for i in n:
				var h := _kit_hash(sd + i * 13 + frame * 7)
				var h2 := _kit_hash(sd * 3 + i * 31 + frame * 11)
				var a := (i + h * 0.8) * TAU / n
				var rr := r0 * (0.75 + h2 * 0.7) * (1.0 + t * 0.25)
				var wd := 0.005 + 0.012 * h
				var cc := col
				cc.a *= (1.0 - t) * (0.45 + 0.55 * h2)
				_fx.draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * rr,
					c + Vector2.from_angle(a - wd) * 1600.0, c + Vector2.from_angle(a + wd) * 1600.0]), cc)
		"horiz":
			var o: Vector2 = l["c"]
			var sz: Vector2 = l["sz"]
			var n2: int = l["n"]
			for i in n2:
				var h := _kit_hash(sd + i * 17 + frame * 5)
				var h2 := _kit_hash(sd + i * 29 + frame * 3)
				var y := o.y + _kit_hash(sd + i * 7) * sz.y
				var ln := 80.0 + h * 320.0
				var x := o.x + h2 * (sz.x + ln) - ln
				var cc := col
				cc.a *= (1.0 - t) * (0.35 + 0.65 * h)
				_fx.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + ln, y - 1.5 - h * 2.0), Vector2(x + ln, y + 1.5 + h * 2.0)]), cc)
		"wipe":
			var e := 1.0 - pow(1.0 - t, 3.0)
			var bw := 520.0
			var x0 := -bw - 420.0 + e * (W + bw * 2.0 + 840.0)
			var col2: Color = l["col2"]
			col.a *= 1.0 - t * 0.6
			col2.a *= 1.0 - t * 0.6
			_fx.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 420, 0), Vector2(x0 + 420 + bw, 0), Vector2(x0 + bw, H), Vector2(x0, H)]), col)
			_fx.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 420 - 46, 0), Vector2(x0 + 420 - 20, 0), Vector2(x0 - 20, H), Vector2(x0 - 46, H)]), col2)


# ------------------------------------------------------------------ slam stamp
## A slanted, chamfered banner that slams down (scale-in), freezes a beat, then shakes + bursts.
func _kit_stamp(text: String, col: Color, pos: Vector2, size: int = 110, hold: float = -1.0, rot_deg: float = -5.0) -> Control:
	pos = Vector2(clampf(pos.x, 220.0, W - 220.0), clampf(pos.y, 80.0 + size * 0.7, H - size * 0.7))
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = pos
	holder.rotation = deg_to_rad(rot_deg)
	_overlay.add_child(holder)
	var font := Style.display_font()
	var fs := size
	var tw_ := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw_ > 980.0 and fs > 28:
		fs -= 3
		tw_ = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bh := fs * 1.32
	var bw := tw_ + bh * 0.9 + 90.0
	# thin full-width slash lines behind the band
	var lines := Control.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.draw.connect(func() -> void:
		lines.draw_rect(Rect2(-900, -bh * 0.5 - 14, 1800, 4), Color(col, 0.85))
		lines.draw_rect(Rect2(-900, bh * 0.5 + 10, 1800, 4), Color(Style.AQUA, 0.7)))
	holder.add_child(lines)
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = Vector2(-bw * 0.5, -bh * 0.5)
	band.size = Vector2(bw, bh)
	band.draw.connect(_kit_draw_band.bind(band, col))
	holder.add_child(band)
	var l := Style.title_label(text, fs, col, NEAR_BLACK, maxi(8, int(fs / 6.0)))
	l.size = Vector2(bw, bh)
	l.position = Vector2(-bw * 0.5, -bh * 0.5 - fs * 0.02)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	holder.scale = Vector2(2.7, 2.7)
	holder.modulate.a = 0.0
	lines.scale = Vector2(0.0, 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(holder, "scale", Vector2.ONE, 0.13 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(holder, "modulate:a", 1.0, 0.07 * _k)
	var punch := clampf(size / 110.0, 0.3, 1.2)
	tw.chain().tween_callback(func() -> void:
		_kit_shake(11.0 * punch, 0.28)
		_kit_shards(pos, col, int(14 * punch), 620.0 * punch)
		_kit_flash(col.lerp(Color.WHITE, 0.6), 0.3 * punch, 0.18))
	tw.tween_property(lines, "scale:x", 1.0, 0.18 * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "scale", Vector2(1.05, 1.05), 0.05 * _k).set_delay(0.06 * _k)
	tw.chain().tween_property(holder, "scale", Vector2.ONE, 0.12 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.chain().tween_interval(hold * _k)
		tw.chain().tween_property(holder, "modulate:a", 0.0, 0.2 * _k)
		tw.chain().tween_callback(holder.queue_free)
	return holder


func _kit_draw_band(c: Control, col: Color) -> void:
	var w := c.size.x
	var h := c.size.y
	var pts := _kit_quad(w, h, h * 0.42, h * 0.26)
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(10, 9))
	c.draw_colored_polygon(sh, Color(NEAR_BLACK, 0.92))
	c.draw_colored_polygon(pts, Color(0.10, 0.04, 0.20, 0.97))
	for i in 3:
		var x := h * 0.42 + 12.0 + i * 14.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x + 10, 6), Vector2(x + 17, 6), Vector2(x + 7 - h * 0.3, h - 6), Vector2(x - h * 0.3, h - 6)]), Color(col, 0.5 - i * 0.13))
	var o := pts.duplicate()
	o.append(pts[0])
	c.draw_polyline(o, col, 5.0, true)


# ------------------------------------------------------------------ screen shatter
## Captures the screen and blows it apart into textured shards (skipped headless / in fast autotest).
## Call it, then swap what is behind before the shards clear.
func _kit_shatter(center: Vector2, cols: int = 7, rows: int = 4, dur: float = 0.6) -> void:
	if DisplayServer.get_name() == "headless" or (Game.autotest and not Game.autotest_slow):
		return
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	var tex := ImageTexture.create_from_image(img)
	var uvk := Vector2(img.get_width() / W, img.get_height() / H)
	var grid: Array[Vector2] = []
	for y in rows + 1:
		for x in cols + 1:
			var p := Vector2(x * W / cols, y * H / rows)
			if x > 0 and x < cols:
				p.x += randf_range(-0.32, 0.32) * W / cols
			if y > 0 and y < rows:
				p.y += randf_range(-0.32, 0.32) * H / rows
			grid.append(p)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(holder)
	for y in rows:
		for x in cols:
			var a := grid[y * (cols + 1) + x]
			var b := grid[y * (cols + 1) + x + 1]
			var c := grid[(y + 1) * (cols + 1) + x + 1]
			var d := grid[(y + 1) * (cols + 1) + x]
			var tris: Array = [[a, b, c], [a, c, d]] if (x + y) % 2 == 0 else [[a, b, d], [b, c, d]]
			for tri in tris:
				var cen: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
				var poly := Polygon2D.new()
				poly.texture = tex
				poly.position = cen
				poly.polygon = PackedVector2Array([tri[0] - cen, tri[1] - cen, tri[2] - cen])
				poly.uv = PackedVector2Array([tri[0] * uvk, tri[1] * uvk, tri[2] * uvk])
				holder.add_child(poly)
				var dir := (cen - center).normalized()
				var dist := randf_range(180.0, 520.0)
				var st := create_tween().set_parallel(true)
				st.tween_property(poly, "position", cen + dir * dist + Vector2(0, randf_range(160.0, 420.0)), dur).set_delay(randf_range(0.0, 0.08)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				st.tween_property(poly, "rotation", randf_range(-2.4, 2.4), dur)
				st.tween_property(poly, "scale", Vector2.ONE * randf_range(0.5, 0.85), dur)
				st.tween_property(poly, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
	var ht := create_tween()
	ht.tween_interval(dur + 0.15)
	ht.tween_callback(holder.queue_free)
