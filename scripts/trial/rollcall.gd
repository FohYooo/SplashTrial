extends "res://scripts/trial/trial_common.gd"
## ROLL CALL (trial data type "roll_call"): the trial goes through the guests one at a time. Each one says where
## they were and the player points out who can back them up, or "Nobody".
## data: title, speaker, prompt,
##   entries [{guest, expr, claim, answer, wrong}]
##     answer  a guest id, a list of guest ids (any of them is right), or "nobody"
##     wrong   optional line {speaker, expr, text}, said after a wrong pick
## Right: REWARD_ROLL and on to the next guest. Wrong: PENALTY_ROLL, that face is crossed out, try again.
## The cards are everyone alive (Mochi too) except the guest speaking, plus Nobody; tools/check_depth.py holds answers to that.
## Keys: the arrows move between the cards and Space / Enter picks the one in focus.

const NOBODY := "nobody"
const FACE := Vector2(116, 142)

var _entries: Array = []
var _n := 0
var _state := "intro"
var _cards := {}
var _order: Array = []     # card ids in display order
var _crossed := {}
var _claim_root: Control
var _progress: Label
var _keys_used := false    # the player has been using the keyboard: the next guest's cards get the focus straight away


func _ready() -> void:
	_build_common(Style.YUZU)
	_entries = data.get("entries", [])
	if _entries.is_empty():
		push_warning("roll_call: no entries in '%s'" % str(data.get("id", "")))
		_finish.call_deferred({})
		return
	var badge := _hud_badge(str(data.get("title", "ROLL CALL")), Style.YUZU, 30)
	badge.position = Vector2(16, 8)
	_hud.add_child(badge)
	var lp := _slant(Vector2(250, 44), PANEL_BG, Style.AQUA_DEEP, 3.0, 12.0, 8.0, 3, Color(INK, 0.92), Vector2(6, 6))
	lp.position = Vector2(1010, 12)
	_hud.add_child(lp)
	_progress = Style.title_label("", 19, Style.AQUA, Style.BG_DARK, 5)
	_progress.position = Vector2(26, 8)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.add_child(_progress)
	_run.call_deferred()


func _run() -> void:
	await _banner_sweep(str(data.get("title", "ROLL CALL")), str(data.get("prompt", "Who can back them up?")), Style.YUZU)
	if _gone():
		return
	_show_entry(0)


# =================================================================== one guest
func _candidates(guest: String) -> Array:
	var out: Array = []
	for id in Cast.survivors():
		if id != guest:
			out.append(str(id))
	out.append(NOBODY)
	return out


func _accepts(entry: Dictionary, pick: String) -> bool:
	var a: Variant = entry.get("answer", NOBODY)
	if typeof(a) == TYPE_ARRAY:
		return (a as Array).has(pick)
	return str(a) == pick


func _show_entry(i: int) -> void:
	_n = i
	_crossed.clear()
	_cards.clear()
	if _claim_root and is_instance_valid(_claim_root):
		_claim_root.queue_free()
	var entry: Dictionary = _entries[i]
	var guest := str(entry.get("guest", ""))
	_progress.text = "GUEST %d / %d" % [i + 1, _entries.size()]
	var root := _full(_stage)
	_claim_root = root
	var p := _make_portrait(guest, str(entry.get("expr", "normal")), 0.74)
	p.position = Vector2(8, H - p.size.y + 8.0)
	root.add_child(p)
	var tag := _make_name_tag(guest, 24)
	tag.position = Vector2(30, 660)
	root.add_child(tag)
	var claim := str(entry.get("claim", ""))
	var box_w := 910.0
	var th := _text_height(claim, Style.body_font(), 24, box_w - 60.0)
	var box := _slant(Vector2(box_w, maxf(96.0, th + 36.0)), Color(0.06, 0.035, 0.14, 0.97), Cast.color(guest), 3.0, 16.0, 12.0, 4, Color(INK, 0.95), Vector2(8, 8))
	box.position = Vector2(350, 76)
	root.add_child(box)
	var l := Label.new()
	l.text = claim
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(30, 16)
	l.size = Vector2(box_w - 60.0, th + 8.0)
	l.add_theme_font_size_override("font_size", 24)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	var ask := Style.title_label("WHO CAN BACK THEM UP?", 18, Style.GOLD, Style.BG_DARK, 5)
	ask.position = Vector2(356, 196)
	ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ask)
	var keys := Style.label("Click a card, or arrows and Space", 14, Style.TEXT_DIM)
	keys.position = Vector2(906, 200)
	keys.size = Vector2(350, 20)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(keys)
	var ids := _candidates(guest)
	_order = ids
	var cols := mini(7, ids.size())
	var gap := 10.0
	var card_w := (900.0 - gap * (cols - 1)) / cols
	for k in ids.size():
		var c := _face_card(str(ids[k]), card_w)
		c.position = Vector2(356 + (k % cols) * (card_w + gap), 226 + (k / cols) * (FACE.y + gap))
		root.add_child(c)
		_cards[str(ids[k])] = c
		c.modulate.a = 0.0
		create_tween().tween_property(c, "modulate:a", 1.0, _fxd(0.14)).set_delay(_fxd(0.02 * k))
	Audio.sfx("whoosh", 1.1, -6.0)
	_state = "pick"
	if _keys_used:
		_focus_first()
	if Game.autotest:
		_autoplay()


func _face_card(id: String, w: float) -> Button:
	var b := Button.new()
	b.size = Vector2(w, FACE.y)
	b.pivot_offset = b.size * 0.5
	b.focus_mode = Control.FOCUS_ALL
	var st := Style.cut_box(Color(0.10, 0.065, 0.21, 0.97), 10, Style.AQUA_DEEP, 2)
	var hi := Style.cut_box(Color(0.20, 0.13, 0.38, 0.98), 10, Style.YUZU, 3)
	var ring := Style.cut_box(Color(0, 0, 0, 0), 10, Style.GOLD, 4)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", hi)
	b.add_theme_stylebox_override("pressed", hi)
	b.add_theme_stylebox_override("disabled", st)
	b.add_theme_stylebox_override("focus", ring)
	if id == NOBODY:
		var nl := Style.title_label("NOBODY", 18, Style.GOLD, Style.BG_DARK, 5)
		nl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nl)
	else:
		var face := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = Assets.portrait(id, "normal")
		at.region = Rect2(90, 24, 300, 300)
		face.texture = at
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.position = Vector2((w - 92.0) * 0.5, 8)
		face.size = Vector2(92, 92)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(face)
		var nm := Style.label(Cast.display_name(id), 15, Cast.color(id).lightened(0.25), true)
		nm.position = Vector2(0, 108)
		nm.size = Vector2(w, 24)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nm)
	b.pressed.connect(_pick.bind(id))
	b.mouse_entered.connect(func() -> void: Audio.sfx("select", randf_range(1.1, 1.25), -12.0))
	b.focus_entered.connect(func() -> void: Audio.sfx("select", randf_range(1.1, 1.25), -12.0))
	return b


# =================================================================== keyboard
func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k and k.pressed and not k.echo and k.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] and _state == "pick" and not _done:
		# a focused card moves on by itself (Godot's focus neighbours); this only catches the first press
		var f := get_viewport().gui_get_focus_owner()
		if f == null or not is_ancestor_of(f):
			_keys_used = true
			_focus_first()
			get_viewport().set_input_as_handled()
			return
	super(e)


## Focus the first card still on offer.
func _focus_first(after: String = "") -> void:
	var start := maxi(_order.find(after), -1) + 1 if after != "" else 0
	for i in _order.size():
		var id := str(_order[(start + i) % _order.size()])
		if not _crossed.has(id) and _cards.has(id):
			(_cards[id] as Control).grab_focus()
			return


# =================================================================== answering
func _pick(id: String) -> void:
	if _state != "pick" or _crossed.has(id) or not _cards.has(id):
		return
	_state = "busy"
	Audio.sfx("confirm")
	var entry: Dictionary = _entries[_n]
	if _accepts(entry, id):
		await _right(id)
	else:
		await _wrong(id, entry)


func _right(id: String) -> void:
	var c: Control = _cards[id]
	Audio.sfx("correct")
	Game.reward(Game.REWARD_ROLL)
	_fx.burst(_to_fx(c.get_global_rect().get_center()), 16, [Style.GOLD, Color.WHITE], 340.0, 700.0, 6.0, 2)
	_pop_text("NOTED!", c.get_global_rect().get_center() + Vector2(0, -40), 40, Style.GOLD, -5.0, 0.3)
	await _wait(_fxd(0.7))
	if _gone():
		return
	if _n + 1 < _entries.size():
		_show_entry(_n + 1)
	else:
		_finish({})


func _wrong(id: String, entry: Dictionary) -> void:
	var c: Button = _cards[id]
	Audio.sfx("wrong")
	Audio.sfx("static", 1.0, -8.0)
	_glitch(_fxd(0.3), 0.9)
	_flash(Style.DANGER, 0.36, 0.3)
	_shake(12.0, 0.3)
	Game.mistake(Game.PENALTY_ROLL)
	_crossed[id] = true
	var had_focus := c.has_focus()
	c.disabled = true
	c.focus_mode = Control.FOCUS_NONE
	c.modulate = Color(0.55, 0.5, 0.62, 0.75)
	if had_focus:
		_focus_first(id)
	_pop_text("WRONG!", c.get_global_rect().get_center() + Vector2(0, -40), 40, Style.DANGER, -5.0, 0.3)
	var w: Variant = entry.get("wrong", {})
	if typeof(w) == TYPE_DICTIONARY and not (w as Dictionary).is_empty():
		var d: Dictionary = w
		await _say_box(str(d.get("speaker", entry.get("guest", ""))), str(d.get("expr", "normal")), str(d.get("text", "")), Vector2(360, 556), 880.0, _fxd(3.0), _fxd(0.4))
	else:
		await _wait(_fxd(0.7))
	if _gone():
		return
	_state = "pick"


# =================================================================== autotest
func _autoplay() -> void:
	await _wait(0.08)
	if _gone():
		return
	var entry: Dictionary = _entries[_n]
	if Game.debug_minigame != "" and _n == 0:
		await _auto_keys()
		for id in _cards.keys():
			if not _accepts(entry, str(id)):
				_pick(str(id))
				break
		while not _gone() and _state == "busy":
			await _frame
		if _gone():
			return
	var a: Variant = entry.get("answer", NOBODY)
	var good := str((a as Array)[0]) if typeof(a) == TYPE_ARRAY else str(a)
	_pick(good if _cards.has(good) else NOBODY)


## Isolated runs: the arrow keys really reach the cards (the first press focuses one, the next moves along).
func _auto_keys() -> void:
	for code in [KEY_RIGHT, KEY_RIGHT]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = true
		get_viewport().push_input(ev)
		var up := ev.duplicate()
		up.pressed = false
		get_viewport().push_input(up)
		await _frame
	var f := get_viewport().gui_get_focus_owner()
	var on := ""
	for id in _cards.keys():
		if _cards[id] == f:
			on = str(id)
	if on != "" and on != str(_order[0]):
		print("[autotest] roll call: the arrow keys moved the focus across the cards")
	else:
		push_error("roll_call: the arrow keys did not move between the cards")
		print("[autotest] FAIL roll call: arrow keys left the focus on '", on, "'")
