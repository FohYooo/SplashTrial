extends Control
## ScriptPlayer - runs the story DSL (see docs/ARCHITECTURE.md section 3).
##
##   const ScriptPlayer := preload("res://scripts/core/script_player.gd")
##   var sp := ScriptPlayer.new()
##   sp.transparent = true        # draw no background (overlay on top of another screen)
##   sp.auto_portrait = true      # each speaker line shows that speaker centered
##   add_child(sp)
##   sp.play_id("prologue")       # or sp.play_text("coco: Ahoy!\n@end")
##   await sp.finished
##
## Layers (bottom -> top): background, portraits, textbox, choices, minigame_layer, hud, overlay, flash.
## `hud` is a public, mouse-transparent layer hosts can put widgets in (e.g. the convince meter).

signal finished
signal event(event_name: String, args: Array)
## Stage hooks (used by the trial courtroom camera, scripts/ui/trial_stage.gd):
## line_started fires for EVERY text line. who = cast id, or "", "narr", "think", "voice", "all".
## expr = that speaker's current expression ("" for non-cast lines).
signal line_started(who: String, expr: String)
signal minigame_started(data_id: String, type: String)
signal minigame_finished(data_id: String)
signal bg_requested(bg_id: String)

const Story := preload("res://scripts/data/story.gd")
const TrialData := preload("res://scripts/data/trial_data.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Clues := preload("res://scripts/data/clues.gd")
const Skills := preload("res://scripts/data/skills.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Style := preload("res://scripts/ui/style.gd")
const Fx := preload("res://scripts/ui/fx.gd")

const MINIGAMES := {
	"debate": "res://scripts/trial/debate.gd",
	"choice": "res://scripts/trial/choice.gd",
	"present": "res://scripts/trial/choice.gd",
	"character": "res://scripts/trial/choice.gd",
	"bubbles": "res://scripts/trial/bubbles.gd",
	"rebuttal": "res://scripts/trial/rebuttal.gd",
	"rewind": "res://scripts/trial/rewind.gd",
	"vote": "res://scripts/trial/vote.gd",
}
const POSITIONS := {"farleft": 0.13, "left": 0.29, "center": 0.5, "right": 0.71, "farright": 0.87}
const SPEAKER_HEADS := ["narr", "think", "voice", "all"]
const CPS := 46.0
const W := 1280.0
const H := 720.0
# textbox geometry (visual): text area stays at y >= 524, ~1160 wide, 3 lines at 25px
const TB_POS := Vector2(60, 524)
const TB_SIZE := Vector2(1160, 178)
const TB_SLANT := 22.0
const NAME_POS := Vector2(84, 479)

var transparent := false
var auto_portrait := false
## stage_mode: an external stage (behind this player) draws background + speakers. The player then
## draws NO background and NO auto portraits; it only emits line_started / bg_requested.
var stage_mode := false

var hud: Control
var minigame_layer: Control

var _bg_a: TextureRect
var _bg_b: TextureRect
var _bg_id := ""
var _portrait_layer: Control
var _textbox: TextBox
var _name_tag: NameBanner
var _text: RichTextLabel
var _next_icon: Droplet
var _choice_box: Control
var _choice_buttons: Array = []
var _overlay: Control
var _flash: ColorRect
var _tb_tween: Tween
var _name_tween: Tween

var _cmds: Array = []
var _labels := {}
var _pc := 0
var _running := false
var _state := ""   # "", typing, wait_click, choice, busy, await_click, minigame
var _gen := 0
var _portraits := {}        # char id -> TextureRect
var _expr := {}             # char id -> current expression
var _auto_current := ""
var _vis := 0.0
var _total := 0
var _blip_pitch := 1.0
var _auto_t := 0.0
var _click_flag := false
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	_bg_a = _make_bg()
	_bg_b = _make_bg()
	_bg_b.modulate.a = 0.0
	_portrait_layer = _full_layer()
	# textbox: angular slanted panel (drawn by TextBox) with hard shadow + accent stripes
	_textbox = TextBox.new()
	_textbox.position = TB_POS
	_textbox.size = TB_SIZE
	add_child(_textbox)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.position = Vector2(48, 30)
	_text.size = Vector2(1066, 136)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 25)
	_text.add_theme_font_size_override("italics_font_size", 25)
	_text.add_theme_font_override("italics_font", Style.italic_font())
	_text.add_theme_constant_override("line_separation", 6)
	_text.add_theme_color_override("font_shadow_color", Color(Style.INK, 0.85))
	_text.add_theme_constant_override("shadow_offset_x", 2)
	_text.add_theme_constant_override("shadow_offset_y", 2)
	_textbox.add_child(_text)
	_next_icon = Droplet.new()
	_next_icon.position = Vector2(TB_SIZE.x - 78, TB_SIZE.y - 54)
	_next_icon.size = Vector2(30, 44)
	_next_icon.visible = false
	_textbox.add_child(_next_icon)
	_name_tag = NameBanner.new()
	_name_tag.position = NAME_POS
	add_child(_name_tag)
	_textbox.visible = false
	_name_tag.visible = false
	# choices: slanted cascading buttons (ChoiceButton), laid out by _choice()
	_choice_box = Control.new()
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_box.position = Vector2(260, 150)
	_choice_box.size = Vector2(760, 340)
	_choice_box.visible = false
	add_child(_choice_box)
	minigame_layer = _full_layer()
	hud = _full_layer()
	_overlay = _full_layer()
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _make_bg() -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _full_layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


# =================================================================== public API
func play_id(script_id: String, start_label: String = "") -> void:
	play_text(Story.get_text(script_id), start_label)


func play_text(text: String, start_label: String = "") -> void:
	_gen += 1
	_parse(text)
	_pc = int(_labels.get(start_label, 0)) if start_label != "" else 0
	_running = true
	_state = ""
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if transparent:
		clear_portraits()
	_step()


func is_running() -> bool:
	return _running


## Immediately set the background without a script (hosts may call this).
func set_background(bg_id: String, instant: bool = true) -> void:
	_set_bg(bg_id, instant)


func clear_portraits() -> void:
	for id in _portraits.keys():
		_portraits[id].queue_free()
	_portraits.clear()
	_auto_current = ""


# =================================================================== parsing
func _parse(text: String) -> void:
	_cmds.clear()
	_labels.clear()
	var lines := text.split("\n")
	var i := 0
	while i < lines.size():
		var raw := lines[i].strip_edges()
		i += 1
		if raw == "" or raw.begins_with("#"):
			continue
		if raw.begins_with("@"):
			var body := raw.substr(1)
			var sp := body.find(" ")
			var op := (body if sp == -1 else body.substr(0, sp)).to_lower()
			var rest := "" if sp == -1 else body.substr(sp + 1).strip_edges()
			if op == "label":
				_labels[rest] = _cmds.size()
				continue
			if op == "choice":
				var opts := []
				while i < lines.size() and lines[i].strip_edges().begins_with(">"):
					var o := lines[i].strip_edges().substr(1).strip_edges()
					i += 1
					var arrow := o.rfind("->")
					if arrow == -1:
						opts.append({"text": o, "label": ""})
					else:
						opts.append({"text": o.substr(0, arrow).strip_edges(), "label": o.substr(arrow + 2).strip_edges()})
				_cmds.append({"op": "choice", "prompt": rest, "options": opts})
				continue
			_cmds.append({"op": op, "rest": rest, "args": Array(rest.split(" ", false))})
		elif raw.begins_with(">"):
			push_warning("ScriptPlayer: stray choice option: " + raw)
		else:
			var who := ""
			var expr := ""
			var txt := raw
			var colon := raw.find(":")
			if colon > 0:
				var head := raw.substr(0, colon).strip_edges()
				var base := head
				var b := head.find("[")
				if b != -1 and head.ends_with("]"):
					base = head.substr(0, b)
					expr = head.substr(b + 1, head.length() - b - 2).strip_edges()
				base = base.to_lower()
				if Cast.exists(base) or SPEAKER_HEADS.has(base):
					who = base
					txt = raw.substr(colon + 1).strip_edges()
				else:
					expr = ""
			_cmds.append({"op": "say", "who": who, "expr": expr, "text": txt})


# =================================================================== execution
func _step() -> void:
	while _running:
		if _pc >= _cmds.size():
			_finish()
			return
		var c: Dictionary = _cmds[_pc]
		_pc += 1
		if _exec(c):
			return


func _goto(label: String) -> void:
	if _labels.has(label):
		_pc = _labels[label]
	else:
		push_error("ScriptPlayer: unknown label '%s'" % label)


## Returns true if the command blocks (it will call _step() itself when done).
func _exec(c: Dictionary) -> bool:
	var op: String = c["op"]
	var args: Array = c.get("args", [])
	var rest: String = c.get("rest", "")
	match op:
		"say":
			_say(c)
			return true
		"choice":
			_choice(c)
			return true
		"bg":
			if stage_mode:
				bg_requested.emit(args[0] if args.size() > 0 else "none")
			else:
				_set_bg(args[0] if args.size() > 0 else "none", args.size() > 1 and args[1] == "instant")
		"music":
			Audio.play_music(args[0] if args.size() > 0 else "stop")
		"sfx":
			if args.size() > 0:
				Audio.sfx(args[0])
		"show":
			if args.size() > 0:
				var expr: String = args[1] if args.size() > 1 else str(_expr.get(args[0], "normal"))
				_show(args[0], expr, args[2] if args.size() > 2 else "center")
		"expr":
			if args.size() > 1:
				_set_expr(args[0], args[1])
		"hide":
			if args.size() == 0 or args[0] == "all":
				for id in _portraits.keys():
					_hide(id)
			else:
				_hide(args[0])
		"jump":
			_goto(rest)
		"if", "ifnot":
			var parts := rest.split("->")
			if parts.size() == 2:
				var v: Variant = Game.get_flag(parts[0].strip_edges(), false)
				var truthy := false
				match typeof(v):
					TYPE_NIL:
						truthy = false
					TYPE_BOOL:
						truthy = bool(v)
					TYPE_INT, TYPE_FLOAT:
						truthy = float(v) != 0.0
					_:
						truthy = str(v) != "" and str(v) != "false"
				if truthy == (op == "if"):
					_goto(parts[1].strip_edges())
		"flag":
			if args.size() > 0:
				var val: Variant = true
				if args.size() > 1:
					var s: String = args[1]
					if s == "false":
						val = false
					elif s == "true":
						val = true
					elif s.is_valid_int():
						val = int(s)
					else:
						val = s
				Game.set_flag(args[0], val)
		"clue":
			if args.size() > 0 and Game.add_clue(args[0]):
				_popup("TRUTH DROP ACQUIRED", Clues.clue_name(args[0]), Clues.desc(args[0]), Assets.clue_icon(args[0]), "clue")
				return true
		"skill":
			if args.size() > 0 and Game.add_skill(args[0]):
				_popup("SKILL LEARNED", Skills.skill_name(args[0]), Skills.desc(args[0]), null, "clue")
				return true
		"convince":
			Game.set_convince(Game.convince + float(rest.replace("+", "")))
		"wait":
			_wait(float(rest) if rest != "" else 1.0)
			return true
		"flash":
			_do_flash(Color(rest) if rest != "" else Color.WHITE)
		"shake":
			_do_shake(float(rest) if rest != "" else 12.0)
		"card":
			_card(rest)
			return true
		"intro":
			if args.size() > 0:
				_intro(args[0])
				return true
		"shout":
			if args.size() > 1:
				_shout(args[0], rest.substr(rest.find(" ") + 1))
				return true
		"minigame":
			if args.size() > 0:
				_run_minigame(args[0])
				return true
		"textbox":
			_show_textbox(rest != "hide")
		"emit":
			event.emit(args[0] if args.size() > 0 else "", args.slice(1))
		"end":
			_finish()
			return true
		_:
			push_warning("ScriptPlayer: unknown command @%s" % op)
	return false


func _finish() -> void:
	if not _running:
		return
	_running = false
	_state = ""
	_show_textbox(false)
	_choice_box.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if transparent:
		clear_portraits()
	# deferred so a script that ends instantly still reaches hosts that `await finished` after play_*()
	finished.emit.call_deferred()


# =================================================================== dialogue
func _say(c: Dictionary) -> void:
	var who: String = c["who"]
	var expr: String = c["expr"]
	var body := Style.markup(str(c["text"]))
	_choice_box.visible = false
	_show_textbox(true)
	_blip_pitch = 1.0
	match who:
		"", "narr":
			_set_name("", Color.WHITE)
			_textbox.set_mode("narr", Style.VIOLET)
			body = "[center][color=#ece6ff]" + body + "[/color][/center]"
		"think":
			_set_name("", Color.WHITE)
			_textbox.set_mode("think", Style.AQUA)
			body = "[color=#a6f2ea][i](" + body + ")[/i][/color]"
		"voice":
			_set_name("???", Color("6c6488"), "unknown voice")
			_textbox.set_mode("speech", Style.TEXT_DIM)
			_blip_pitch = 0.8
		"all":
			_set_name("Everyone", Style.YUZU)
			_textbox.set_mode("speech", Style.YUZU)
		_:
			_set_name(Cast.display_name(who), Cast.color(who), Cast.talent(who))
			_textbox.set_mode("speech", Cast.color(who))
			_blip_pitch = Cast.pitch(who)
			if expr != "":
				_expr[who] = expr
			if stage_mode:
				pass
			elif auto_portrait and who != "mochi":
				_auto_show(who, str(_expr.get(who, "normal")))
			elif expr != "" and _portraits.has(who):
				_set_expr(who, expr)
			_highlight(who)
	line_started.emit(who, str(_expr.get(who, "normal")) if Cast.exists(who) else "")
	_text.text = body
	_text.visible_characters = 0
	_total = _text.get_total_character_count()
	_vis = 0.0
	_next_icon.visible = false
	_state = "typing"


func _set_name(n: String, col: Color, talent: String = "") -> void:
	var was_visible := _name_tag.visible
	var changed := _name_tag.nm != n.to_upper()
	_name_tag.visible = n != ""
	if n == "":
		return
	_name_tag.set_banner(n.to_upper(), talent.to_upper(), col)
	if changed or not was_visible:
		# new speaker: banner snaps in from the left
		if _name_tween:
			_name_tween.kill()
		_name_tag.position = NAME_POS - Vector2(34, 0)
		_name_tag.modulate.a = 0.0
		_name_tween = create_tween().set_parallel(true)
		_name_tween.tween_property(_name_tag, "position", NAME_POS, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_name_tween.tween_property(_name_tag, "modulate:a", 1.0, 0.08)


func _show_textbox(on: bool) -> void:
	if on and not _textbox.visible:
		# textbox snaps up into place (visual only)
		if _tb_tween:
			_tb_tween.kill()
		_textbox.position = TB_POS + Vector2(-18, 22)
		_textbox.modulate.a = 0.0
		_tb_tween = create_tween().set_parallel(true)
		_tb_tween.tween_property(_textbox, "position", TB_POS, 0.17).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_tb_tween.tween_property(_textbox, "modulate:a", 1.0, 0.1)
	_textbox.visible = on
	if not on:
		_name_tag.visible = false


func _process(delta: float) -> void:
	_time += delta
	if _state == "typing":
		var speed := CPS * Game.text_speed
		if Game.is_fast_forward():
			speed = 4000.0
		_vis += delta * speed
		var n := mini(int(_vis), _total)
		if n != _text.visible_characters:
			if not Game.is_fast_forward() and n % 2 == 0:
				Audio.blip(_blip_pitch)
			_text.visible_characters = n
		if n >= _total:
			_text.visible_characters = -1
			_state = "wait_click"
			_auto_t = 0.0
			_next_icon.visible = true
	elif _state == "wait_click":
		if Game.is_fast_forward():
			_auto_t += delta
			if _auto_t > (0.01 if Game.autotest else 0.07):
				_advance()
		elif Game.autotest:
			_auto_t += delta
			if _auto_t > 1.1:
				_advance()


func _advance() -> void:
	_state = ""
	_next_icon.visible = false
	Audio.sfx("select", 1.0, -10.0)
	_step()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_on_click()
		accept_event()


func _unhandled_key_input(e: InputEvent) -> void:
	if not _running or not is_visible_in_tree():
		return
	var k := e as InputEventKey
	if k and k.pressed and not k.echo and k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z]:
		if _state in ["typing", "wait_click", "await_click"]:
			_on_click()
			get_viewport().set_input_as_handled()
	elif k and k.pressed and not k.echo and _state == "choice":
		# number keys 1-9 pick a choice
		var idx := int(k.keycode) - int(KEY_1)
		if idx >= 0 and idx < mini(9, _choice_buttons.size()):
			var b: ChoiceButton = _choice_buttons[idx]
			if is_instance_valid(b):
				b.pressed.emit()
				get_viewport().set_input_as_handled()


func _on_click() -> void:
	match _state:
		"typing":
			_vis = float(_total)
		"wait_click":
			_advance()
		"await_click":
			_click_flag = true


## Async helper: waits for a click (after min_time) or auto_after seconds (<0 = never).
func _await_click(min_time: float = 0.25, auto_after: float = -1.0) -> bool:
	var g := _gen
	_click_flag = false
	_state = "await_click"
	var t := 0.0
	while true:
		await get_tree().process_frame
		if g != _gen or not is_inside_tree():
			return false
		t += get_process_delta_time()
		if t >= min_time and (_click_flag or Game.is_fast_forward() or (Game.autotest and t >= 1.1)):
			break
		if auto_after > 0.0 and t >= auto_after:
			break
	_state = "busy"
	return true


# =================================================================== choices
func _choice(c: Dictionary) -> void:
	_state = "choice"
	var prompt: String = c["prompt"]
	if prompt != "":
		_show_textbox(true)
		_set_name("", Color.WHITE)
		_textbox.set_mode("choice", Style.GOLD)
		_text.text = "[color=#ffd166]" + Style.markup(prompt) + "[/color]"
		_text.visible_characters = -1
		_next_icon.visible = false
	for ch in _choice_box.get_children():
		ch.queue_free()
	_choice_buttons.clear()
	var opts: Array = c["options"]
	var n := opts.size()
	var bh := 62.0
	var gap := 14.0
	# translucent slanted backdrop so the options read clearly over busy art
	var back := Style.Shape.new()
	back.points = Style.slant_poly(Rect2(-90, -26, 940, n * (bh + gap) + 38), 46.0)
	back.fill = Color(Style.INK, 0.5)
	back.size = Vector2(760, n * (bh + gap))
	_choice_box.add_child(back)
	back.modulate.a = 0.0
	back.create_tween().tween_property(back, "modulate:a", 1.0, 0.12)
	for i in n:
		var o: Dictionary = opts[i]
		var b := ChoiceButton.new()
		b.setup(i + 1, str(o["text"]))
		b.size = Vector2(760, bh)
		# cascade along the slant: each lower button sits a little further left
		b.position = Vector2((n - 1 - i) * 13.0 - (n - 1) * 6.5, i * (bh + gap))
		b.pressed.connect(_choose.bind(o))
		b.mouse_entered.connect(func() -> void: Audio.sfx("select", 1.2, -12.0))
		_choice_box.add_child(b)
		_choice_buttons.append(b)
		b.appear(0.03 + i * 0.05)
	_choice_box.visible = true
	_choice_box.size = Vector2(760, n * (bh + gap))
	_choice_box.position = Vector2((W - 760.0) / 2.0, 300 - n * 37)
	if Game.autotest and opts.size() > 0:
		_auto_choose(opts[0])


func _auto_choose(o: Dictionary) -> void:
	var g := _gen
	await get_tree().create_timer(0.8 if Game.autotest_slow else 0.02).timeout
	if g == _gen and _state == "choice":
		_choose(o)


func _choose(o: Dictionary) -> void:
	if _state != "choice":
		return
	Audio.sfx("confirm")
	for b in _choice_buttons:
		if is_instance_valid(b) and b.text_value == str(o["text"]):
			var cpos: Vector2 = b.global_position - global_position + b.size * 0.5
			Fx.splash(_overlay, cpos, Style.GOLD, 10, 140.0, 0.45)
			Fx.flash(_overlay, Style.GOLD, 0.18, 0.18)
	_choice_box.visible = false
	_state = ""
	if o["label"] != "":
		_goto(o["label"])
	_step()


# =================================================================== backgrounds & portraits
func _set_bg(bg_id: String, instant: bool) -> void:
	if bg_id == _bg_id:
		return
	_bg_id = bg_id
	var tex: Texture2D = null if bg_id == "none" else Assets.bg(bg_id)
	if instant or Game.is_fast_forward():
		_bg_a.texture = tex
		_bg_b.modulate.a = 0.0
		return
	_bg_b.texture = tex
	_bg_b.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_bg_b, "modulate:a", 1.0, 0.45)
	tw.tween_callback(func() -> void:
		_bg_a.texture = tex
		_bg_b.modulate.a = 0.0)


func _portrait_pos(pos: String) -> float:
	if POSITIONS.has(pos):
		return POSITIONS[pos]
	if pos.is_valid_float():
		return clampf(float(pos), 0.0, 1.0)
	return 0.5


func _show(id: String, expr: String, pos: String) -> void:
	_expr[id] = expr
	var x := _portrait_pos(pos) * W - Assets.PORTRAIT_SIZE.x * 0.5
	var y := H - Assets.PORTRAIT_SIZE.y
	var r: TextureRect
	if _portraits.has(id):
		r = _portraits[id]
		r.texture = Assets.portrait(id, expr)
		var tw0 := create_tween()
		tw0.tween_property(r, "position:x", x, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		return
	r = TextureRect.new()
	r.texture = Assets.portrait(id, expr)
	r.size = Assets.PORTRAIT_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Vector2(x + (40 if x > W * 0.4 else -40), y + 10)
	r.modulate.a = 0.0
	r.pivot_offset = Vector2(240, 600)
	_portrait_layer.add_child(r)
	_portraits[id] = r
	var tw := create_tween().set_parallel(true)
	tw.tween_property(r, "position", Vector2(x, y), 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "modulate:a", 1.0, 0.18)
	if expr == "shock":
		_shake_node(r)


func _set_expr(id: String, expr: String) -> void:
	_expr[id] = expr
	if _portraits.has(id):
		_portraits[id].texture = Assets.portrait(id, expr)
		if expr == "shock":
			_shake_node(_portraits[id])


func _hide(id: String) -> void:
	if not _portraits.has(id):
		return
	var r: TextureRect = _portraits[id]
	_portraits.erase(id)
	if _auto_current == id:
		_auto_current = ""
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.15)
	tw.tween_callback(r.queue_free)


func _auto_show(id: String, expr: String) -> void:
	if _auto_current == id and _portraits.has(id):
		_set_expr(id, expr)
		return
	for other in _portraits.keys():
		if other != id:
			_hide(other)
	_auto_current = id
	_show(id, expr, "center")


func _highlight(speaker: String) -> void:
	for id in _portraits.keys():
		var r: TextureRect = _portraits[id]
		var target := Color.WHITE if id == speaker or _portraits.size() == 1 else Color(0.5, 0.48, 0.66)
		if r.self_modulate != target:
			var tw := r.create_tween()
			tw.tween_property(r, "self_modulate", target, 0.12)


func _shake_node(n: Control) -> void:
	var base := n.position
	var tw := create_tween()
	for i in 5:
		tw.tween_property(n, "position", base + Vector2(randf_range(-9, 9), randf_range(-4, 4)), 0.03)
	tw.tween_property(n, "position", base, 0.03)


# =================================================================== effects
func _wait(sec: float) -> void:
	var g := _gen
	_state = "busy"
	await get_tree().create_timer(sec * (0.05 if Game.is_fast_forward() else 1.0)).timeout
	if g == _gen and is_inside_tree():
		_state = ""
		_step()


func _do_flash(col: Color) -> void:
	_flash.color = col
	_flash.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, 0.5)


func _do_shake(strength: float) -> void:
	var tw := create_tween()
	for i in 8:
		tw.tween_property(self, "position", Vector2(randf_range(-strength, strength), randf_range(-strength, strength) * 0.6), 0.035)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


func _overlay_root() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(root)
	return root


func _ink_dim(root: Control, alpha: float, time: float = 0.12) -> ColorRect:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(Style.INK, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var tw := dim.create_tween()
	tw.tween_property(dim, "color:a", alpha, time)
	return dim


func _shape(parent: Control, pts: PackedVector2Array, fill: Color, outline: Color = Color(0, 0, 0, 0),
		outline_w: float = 0.0, shadow: Color = Color(0, 0, 0, 0), shadow_off: Vector2 = Vector2(8, 8)) -> Control:
	var s := Style.Shape.new()
	s.points = pts
	s.fill = fill
	s.outline = outline
	s.outline_w = outline_w
	s.shadow = shadow
	s.shadow_off = shadow_off
	s.size = Vector2(W, H)
	parent.add_child(s)
	return s


func _layer_ctl(parent: Control) -> Control:
	var c := Control.new()
	c.size = Vector2(W, H)
	c.pivot_offset = Vector2(W, H) * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _fit_font(text: String, start: int, min_size: int, max_w: float) -> int:
	var fs := start
	while fs > min_size and Style.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 2
	return fs


## Clue / skill popup: angular card with a slanted header tab, diamond icon frame and a splash burst.
func _popup(header: String, title: String, desc: String, icon: Texture2D, sfx_id: String) -> void:
	_state = "busy"
	Audio.sfx(sfx_id)
	var is_skill := header.begins_with("SKILL")
	var accent := Style.YUZU if is_skill else Style.AQUA
	var accent2 := Style.GOLD if is_skill else Style.YUZU
	var root := _overlay_root()
	_ink_dim(root, 0.62)
	Fx.vignette(root, Style.INK, 0.7, 0.35)
	var pw := 740.0
	var text_x := 252.0
	var dsize := 19 if desc.length() < 260 else 17
	var desc_h: float = Style.body_font().get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, pw - text_x - 34, dsize).y
	var ph := clampf(120.0 + desc_h + 54.0, 280.0, 600.0)
	var card := Control.new()
	card.size = Vector2(pw, ph)
	card.position = Vector2((W - pw) / 2.0, (H - ph) / 2.0 - 6.0)
	card.pivot_offset = card.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	var body := Style.chamfer(Style.Geo.rect_poly(Rect2(0, 0, pw, ph)), [36.0, 0.0, 36.0, 0.0])
	var bs := _shape(card, body, Color(0.055, 0.03, 0.12, 0.98), accent, 4.0, Color(Style.INK, 0.92), Vector2(14, 14))
	bs.size = card.size
	var deco := Painter.new(func(ci: Control) -> void:
		var inner := Style.chamfer(Style.Geo.rect_poly(Rect2(11, 11, pw - 22, ph - 22)), [28.0, 0.0, 28.0, 0.0])
		inner.append(inner[0])
		ci.draw_polyline(inner, Color(accent, 0.22), 1.5)
		Style.draw_stripes(ci, Rect2(pw - 190, 16, 150, 14), 5, Color(accent2, 0.9), 10.0, 7.0)
		# ripple wave along the bottom edge
		var wave := PackedVector2Array()
		for i in 41:
			var x := 60.0 + (pw - 140.0) * i / 40.0
			wave.append(Vector2(x, ph - 18.0 + sin(i * 0.9) * 3.0))
		ci.draw_polyline(wave, Color(accent, 0.22), 2.0)
		# diamond icon frame
		var c := Vector2(126, 54 + 110)
		var dia := PackedVector2Array([c + Vector2(0, -104), c + Vector2(104, 0), c + Vector2(0, 104), c + Vector2(-104, 0)])
		Style.draw_shape(ci, dia, Color(0.11, 0.07, 0.23, 1.0), accent, 3.0, Color(Style.INK, 0.9), Vector2(8, 8))
		ci.draw_arc(c, 70.0, 0.0, TAU, 40, Color(accent, 0.18), 2.0)
		if icon == null:
			if is_skill:
				# yuzu-slice emblem
				ci.draw_circle(c, 48.0, Style.YUZU)
				ci.draw_circle(c, 40.0, Color("fff0b8"))
				for k in 8:
					var a := TAU * k / 8.0
					var p1 := c + Vector2(cos(a), sin(a)) * 8.0
					var a1 := a - 0.3
					var a2 := a + 0.3
					ci.draw_colored_polygon(PackedVector2Array([p1, c + Vector2(cos(a1), sin(a1)) * 35.0,
						c + Vector2(cos(a2), sin(a2)) * 35.0]), Color("ffc85a"))
				ci.draw_circle(c, 6.0, Color("fff0b8"))
			else:
				ci.draw_colored_polygon(Style.Geo.droplet(c + Vector2(0, 22), 34.0), Style.AQUA)
				ci.draw_circle(c + Vector2(-10, 12), 8.0, Color(1, 1, 1, 0.7)))
	deco.size = card.size
	card.add_child(deco)
	if icon:
		var ir := TextureRect.new()
		ir.texture = icon
		ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.position = Vector2(126 - 72, 164 - 72)
		ir.size = Vector2(144, 144)
		ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(ir)
	# slanted header tab
	var hfs := 22
	var hw: float = Style.display_font().get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x
	var tab := Control.new()
	tab.position = Vector2(-20, -26)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tab)
	var ts := _shape(tab, Style.slant_poly(Rect2(0, 0, hw + 64, 46), 16), accent, Style.INK, 3.0, Color(Style.INK, 0.95), Vector2(6, 6))
	ts.size = Vector2(hw + 64, 46)
	var hdr := Style.title_label(header, hfs, Style.INK, Color(1, 1, 1, 0.35), 0)
	hdr.position = Vector2(32, 8)
	tab.add_child(hdr)
	var tfs := _fit_font(title, 36, 24, pw - text_x - 34)
	var tl := Style.title_label(title, tfs, Style.GOLD, Style.INK, 9)
	tl.position = Vector2(text_x, 46)
	card.add_child(tl)
	var dl := Label.new()
	dl.text = desc
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.position = Vector2(text_x, 108)
	dl.size = Vector2(pw - text_x - 34, ph - 150)
	dl.add_theme_font_size_override("font_size", dsize)
	dl.add_theme_color_override("font_color", Style.TEXT)
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dl)
	var hint := Style.label("CLICK TO CONTINUE", 13, Style.TEXT_DIM, true)
	hint.position = Vector2(pw - 210, ph - 40)
	card.add_child(hint)
	var dr := Droplet.new()
	dr.position = Vector2(pw - 56, ph - 54)
	dr.size = Vector2(30, 44)
	dr.scale = Vector2(0.75, 0.75)
	card.add_child(dr)
	# entry: slam in from the right, squashed, with a glitch + splash
	var final_pos := card.position
	card.position += Vector2(170, 0)
	card.scale = Vector2(1.12, 0.6)
	card.modulate.a = 0.0
	tab.position.x -= 140
	tab.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "position", final_pos, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.1)
	tw.tween_property(tab, "position:x", -20.0, 0.18).set_delay(0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(tab, "modulate:a", 1.0, 0.08).set_delay(0.1)
	var burst := final_pos + Vector2(126, 164)
	tw.tween_callback(func() -> void:
		Fx.splash(root, burst, accent, 16, 190.0, 0.6)
		Fx.ripple(root, burst + Vector2(0, 96), accent, 170.0, 0.6, 3)
		Fx.flash(root, Color.WHITE, 0.2, 0.22)).set_delay(0.12)
	Fx.glitch(root, 0.2, 0.75)
	_finish_overlay(root, 0.35, -1.0)


func _finish_overlay(root: Control, min_time: float, auto_after: float) -> void:
	var ok := await _await_click(min_time, auto_after)
	if not ok:
		root.queue_free()
		return
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.15)
	tw.tween_callback(root.queue_free)
	_state = ""
	_step()


## @card: diagonal split-screen bands slash in from both sides, title slams down, speed lines + glitch.
## Titles ending in "!" (e.g. A BODY HAS BEEN DISCOVERED!) get the coral danger variant.
func _card(rest: String) -> void:
	_state = "busy"
	_show_textbox(false)
	var parts := rest.split("|")
	var title := parts[0].strip_edges()
	var sub := parts[1].strip_edges() if parts.size() > 1 else ""
	var danger := title.ends_with("!")
	var accent := Style.DANGER if danger else Style.AQUA
	var accent2 := Style.GOLD if danger else Style.YUZU
	var root := _overlay_root()
	var dim := _ink_dim(root, 0.6 if danger else 0.5)
	var grp := _layer_ctl(root)
	grp.rotation = deg_to_rad(-4.0)
	var top := _layer_ctl(grp)
	_shape(top, Style.slant_poly(Rect2(-300, 226, W + 600, 20), 20), accent, Color(0, 0, 0, 0), 0.0, Color(Style.INK, 0.8), Vector2(0, 6))
	var band := _layer_ctl(grp)
	var band_fill := Color(0.16, 0.03, 0.08, 0.97) if danger else Color(0.045, 0.025, 0.10, 0.97)
	_shape(band, Style.slant_poly(Rect2(-300, 252, W + 600, 212), 44), band_fill, Color(accent, 0.9), 3.0, Color(Style.INK, 0.85), Vector2(0, 14))
	Fx.streaks(band, Rect2(-200, 270, W + 400, 176), Color(1, 1, 1, 0.07 if not danger else 0.1), 16, -2600.0)
	var deco := Painter.new(func(ci: Control) -> void:
		Style.draw_stripes(ci, Rect2(70, 290, 120, 136), 4, Color(accent2, 0.85), 34.0, 10.0)
		Style.draw_stripes(ci, Rect2(W - 196, 290, 120, 136), 4, Color(accent2, 0.85), 34.0, 10.0))
	deco.size = Vector2(W, H)
	band.add_child(deco)
	var bot := _layer_ctl(grp)
	_shape(bot, Style.slant_poly(Rect2(-300, 474, W + 600, 12), 12), accent2, Color(0, 0, 0, 0), 0.0, Color(Style.INK, 0.8), Vector2(0, 6))
	var fs := _fit_font(title, 64 if title.length() < 26 else 50, 30, 900.0)
	var ty := 290.0 if sub != "" else 312.0
	var tl2 := Style.title_label(title, fs, accent, accent, 14)
	tl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl2.position = Vector2(7, ty + 7)
	tl2.size = Vector2(W, 90)
	tl2.pivot_offset = Vector2(W * 0.5, 45)
	band.add_child(tl2)
	var tl := Style.title_label(title, fs, Color.WHITE if danger else Style.GOLD, Style.INK, 14)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.position = Vector2(0, ty)
	tl.size = Vector2(W, 90)
	tl.pivot_offset = Vector2(W * 0.5, 45)
	band.add_child(tl)
	var sl: Label = null
	if sub != "":
		sl = Style.title_label(sub, 28, Style.AQUA if not danger else Style.GOLD, Style.INK, 8)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.position = Vector2(0, 384)
		sl.size = Vector2(W, 40)
		band.add_child(sl)
	# entry choreography
	band.position.x = -W * 1.4
	top.position.x = W * 1.4
	bot.position.x = W * 1.4
	for l in [tl, tl2]:
		l.scale = Vector2(1.8, 1.8)
		l.modulate.a = 0.0
	Audio.sfx("whoosh")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(band, "position:x", 0.0, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(top, "position:x", 0.0, 0.26).set_delay(0.03).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(bot, "position:x", 0.0, 0.26).set_delay(0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl, "scale", Vector2.ONE, 0.2).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl, "modulate:a", 1.0, 0.06).set_delay(0.12)
	tw.tween_property(tl2, "scale", Vector2.ONE, 0.2).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl2, "modulate:a", 1.0, 0.06).set_delay(0.15)
	if sl:
		sl.modulate.a = 0.0
		sl.position.x = 90.0
		tw.tween_property(sl, "position:x", 0.0, 0.22).set_delay(0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(sl, "modulate:a", 1.0, 0.12).set_delay(0.2)
	tw.tween_callback(func() -> void:
		Fx.flash(root, Color.WHITE if not danger else Style.DANGER, 0.28, 0.4 if not danger else 0.5)
		Fx.speed_lines(root, Vector2(W * 0.5, 356), 0.5, Color(1, 1, 1, 0.22) if not danger else Color(Style.DANGER, 0.4), 38, 250.0)
		if danger:
			_do_shake(16.0)).set_delay(0.16)
	Fx.glitch(root, 0.4 if danger else 0.24, 1.3 if danger else 0.9)
	_card_out(root, [band, top, bot, dim])


func _card_out(root: Control, parts: Array) -> void:
	var ok := await _await_click(0.6, 2.8)
	if not ok:
		root.queue_free()
		return
	var band: Control = parts[0]
	var top: Control = parts[1]
	var bot: Control = parts[2]
	var dim: ColorRect = parts[3]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(band, "position:x", W * 1.4, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(top, "position:x", -W * 1.4, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(bot, "position:x", -W * 1.4, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(dim, "color:a", 0.0, 0.22)
	tw.chain().tween_callback(root.queue_free)
	await tw.finished
	_state = ""
	_step()


## @intro: diagonal colour panel, big portrait with a hard shadow, slanted talent tab + name plate.
func _intro(id: String) -> void:
	_state = "busy"
	_show_textbox(false)
	for other in _portraits.keys():
		_hide(other)
	var col := Cast.color(id)
	var dark := col.darkened(0.66)
	var root := _overlay_root()
	_ink_dim(root, 0.72, 0.1)
	# diagonal colour panel with scan lines and two bright edge stripes
	var panel := _layer_ctl(root)
	var pdeco := Painter.new(func(ci: Control) -> void:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-60, 0), Vector2(820, 0), Vector2(600, H), Vector2(-60, H)]), Color(dark, 0.96))
		for yy in range(10, int(H), 16):
			var ex := 820.0 - 220.0 * yy / H - 10.0
			ci.draw_line(Vector2(-60, yy), Vector2(ex, yy), Color(col, 0.10), 3.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(820, 0), Vector2(850, 0), Vector2(630, H), Vector2(600, H)]), col)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(866, 0), Vector2(876, 0), Vector2(656, H), Vector2(646, H)]), Color(1, 1, 1, 0.85))
		# rising bubbles (water motif)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		for i in 14:
			var bp := Vector2(rng.randf_range(20, 540), rng.randf_range(40, 700))
			ci.draw_arc(bp, rng.randf_range(5, 16), 0.0, TAU, 20, Color(col.lightened(0.4), 0.28), 2.0))
	pdeco.size = Vector2(W, H)
	panel.add_child(pdeco)
	var tex := Assets.portrait(id, "normal")
	var psize := Assets.PORTRAIT_SIZE * 1.12
	var por_x := W - psize.x - 10
	var shadow := TextureRect.new()
	shadow.texture = tex
	shadow.size = psize
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.material = Fx.silhouette_material(Color(Style.INK, 0.9))
	shadow.position = Vector2(W + 60, H - psize.y + 20)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)
	var echo := TextureRect.new()
	echo.texture = tex
	echo.size = psize
	echo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	echo.material = Fx.silhouette_material(Color(col, 0.55))
	echo.position = Vector2(W + 40, H - psize.y + 20)
	echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(echo)
	var por := TextureRect.new()
	por.texture = tex
	por.size = psize
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.position = Vector2(W + 40, H - por.size.y + 20)
	por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(por)
	# name plate group (slightly rotated)
	var plate := Control.new()
	plate.position = Vector2(48, 318)
	plate.rotation = deg_to_rad(-5.0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	var talent := Cast.talent(id).to_upper()
	var full := Cast.full_name(id).to_upper()
	var tfs := 24
	var tw_t: float = Style.display_font().get_string_size(talent, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var nfs := _fit_font(full, 64, 30, 640.0)
	var nw: float = Style.display_font().get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	var name_plate := Control.new()
	name_plate.position = Vector2(14, 48)
	name_plate.size = Vector2(nw + 84, 100)
	name_plate.pivot_offset = name_plate.size * 0.5
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(name_plate)
	var nps := _shape(name_plate, Style.chamfer(Style.slant_poly(Rect2(0, 0, nw + 84, 100), 26), [0.0, 18.0, 0.0, 18.0]),
		Style.TEXT, Style.INK, 4.0, Color(col, 0.95), Vector2(12, 12))
	nps.size = name_plate.size
	var stripes := Painter.new(func(ci: Control) -> void:
		Style.draw_stripes(ci, Rect2(nw + 30, 66, 46, 22), 3, Color(col.darkened(0.2), 0.9), 10.0, 5.0))
	stripes.size = name_plate.size
	name_plate.add_child(stripes)
	var nm := Style.title_label(full, nfs, Style.INK, Color(1, 1, 1, 0.0), 0)
	nm.position = Vector2(42, (100 - nfs * 1.25) * 0.5)
	name_plate.add_child(nm)
	var tab := Control.new()
	tab.size = Vector2(tw_t + 60, 42)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(tab)
	var tbs := _shape(tab, Style.slant_poly(Rect2(0, 0, tw_t + 60, 42), 14), col, Style.INK, 3.0, Color(Style.INK, 0.95), Vector2(6, 6))
	tbs.size = tab.size
	var tal := Style.title_label(talent, tfs, Color.WHITE, Style.INK, 7)
	tal.position = Vector2(30, 5)
	tab.add_child(tal)
	# entry choreography
	panel.position.x = -980.0
	name_plate.scale = Vector2(1.6, 1.6)
	name_plate.modulate.a = 0.0
	tab.position.x = -520.0
	Audio.sfx("whoosh")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "position:x", 0.0, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(por, "position:x", por_x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(echo, "position:x", por_x - 26, 0.34).set_delay(0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(shadow, "position:x", por_x + 16, 0.32).set_delay(0.02).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tab, "position:x", 0.0, 0.2).set_delay(0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(name_plate, "scale", Vector2.ONE, 0.2).set_delay(0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(name_plate, "modulate:a", 1.0, 0.06).set_delay(0.14)
	tw.tween_callback(func() -> void:
		Fx.flash(root, col.lightened(0.5), 0.25, 0.28)
		Fx.speed_lines(root, Vector2(por_x + psize.x * 0.5, 250), 0.5, Color(col.lightened(0.45), 0.4), 30, 230.0)
		Fx.splash(root, Vector2(140, 440), Style.AQUA, 14, 200.0, 0.6)).set_delay(0.18)
	Fx.glitch(root, 0.2, 0.8)
	_intro_out(root, id)


func _intro_out(root: Control, id: String) -> void:
	var ok := await _await_click(0.5, -1.0)
	if not ok:
		root.queue_free()
		return
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	_auto_current = ""
	_show(id, "normal", "center")
	_auto_current = id
	_state = ""
	_step()


## @shout: slanted band slashes across, portrait cut-in window, text slams in with shake + speed lines,
## and the whole shout shatters away when dismissed.
func _shout(id: String, text: String) -> void:
	_state = "busy"
	_show_textbox(false)
	Audio.sfx("shout")
	var col := Cast.color(id)
	var root := _overlay_root()
	_ink_dim(root, 0.55, 0.08)
	var grp := _layer_ctl(root)
	grp.rotation = deg_to_rad(-9.0)
	var band := _layer_ctl(grp)
	_shape(band, Style.slant_poly(Rect2(-340, 232, W + 680, 256), 64), Color(0.04, 0.02, 0.09, 0.97), col, 5.0,
		Color(col.darkened(0.25), 0.95), Vector2(0, 18))
	Fx.streaks(band, Rect2(-240, 252, W + 480, 216), Color(1, 1, 1, 0.09), 18, -3200.0)
	var bdeco := Painter.new(func(ci: Control) -> void:
		Style.draw_stripes(ci, Rect2(W - 150, 262, 120, 196), 4, Color(Style.GOLD, 0.8), 50.0, 12.0))
	bdeco.size = Vector2(W, H)
	band.add_child(bdeco)
	# portrait cut-in window (textured polygon = portrait clipped to a slanted frame)
	var cut := _layer_ctl(root)
	var win := Rect2(34, 104, 380, 440)
	var win_pts := Style.slant_poly(win, 74)
	var frame: Array = Geometry2D.offset_polygon(win_pts, 8.0, Geometry2D.JOIN_MITER)
	if frame.size() > 0:
		_shape(cut, frame[0], col, Style.INK, 3.0, Color(Style.INK, 0.95), Vector2(12, 12))
	var wdeco := Painter.new(func(ci: Control) -> void:
		ci.draw_colored_polygon(win_pts, col.darkened(0.45))
		for yy in range(int(win.position.y) + 8, int(win.end.y), 14):
			var t := (yy - win.position.y) / win.size.y
			ci.draw_line(Vector2(win.position.x + 74 * (1.0 - t), yy), Vector2(win.end.x - 74 * t, yy), Color(col.lightened(0.3), 0.22), 3.0))
	wdeco.size = Vector2(W, H)
	cut.add_child(wdeco)
	var ptex := Assets.portrait(id, "angry")
	var poly := Polygon2D.new()
	poly.texture = ptex
	poly.polygon = win_pts
	var tr := Rect2(30, 28, 420, 486)
	var uvs := PackedVector2Array()
	for p in win_pts:
		uvs.append(tr.position + (p - win.position) / win.size * tr.size)
	poly.uv = uvs
	cut.add_child(poly)
	# the shout text: colored hard-shadow copy + gold face
	var fsize := _fit_font(text, 86, 36, 800.0)
	var tl2 := Style.title_label(text, fsize, col, col.darkened(0.35), 18)
	var tl := Style.title_label(text, fsize, Style.GOLD, Style.INK, 18)
	for l in [tl2, tl]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(860, 130)
		l.pivot_offset = Vector2(430, 65)
		band.add_child(l)
	tl.position = Vector2(390, 295)
	tl2.position = tl.position + Vector2(9, 9)
	# entry choreography: band slash, cut-in, text slam, then impact (shake/flash/speed lines/glitch)
	band.position.x = W * 1.3
	cut.position.x = -560.0
	for l in [tl, tl2]:
		l.scale = Vector2(2.7, 2.7)
		l.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(band, "position:x", 0.0, 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(cut, "position:x", 0.0, 0.2).set_delay(0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl, "scale", Vector2.ONE, 0.12).set_delay(0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl, "modulate:a", 1.0, 0.04).set_delay(0.08)
	tw.tween_property(tl2, "scale", Vector2.ONE, 0.12).set_delay(0.11).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl2, "modulate:a", 1.0, 0.04).set_delay(0.11)
	tw.tween_callback(func() -> void:
		_do_shake(16.0)
		Fx.flash(root, Color.WHITE, 0.3, 0.6)
		Fx.speed_lines(root, Vector2(820, 340), 0.45, Color(1, 1, 1, 0.45), 42, 280.0)
		Fx.glitch(root, 0.16, 0.9)).set_delay(0.2)
	_shout_out(root)


func _shout_out(root: Control) -> void:
	var ok := await _await_click(0.9, 1.6)
	if not ok:
		root.queue_free()
		return
	var tex: Texture2D = null if Fx.skip_heavy() else Fx.capture(self)
	if tex:
		root.queue_free()
		Fx.shatter(_overlay, 0.55, Vector2(800, 350), tex)
		Audio.sfx("break", 1.15, -9.0)
	else:
		var tw := create_tween()
		tw.tween_property(root, "modulate:a", 0.0, 0.15)
		tw.tween_callback(root.queue_free)
	_state = ""
	_step()


# =================================================================== minigames
func _run_minigame(data_id: String) -> void:
	_state = "minigame"
	_show_textbox(false)
	_choice_box.visible = false
	var data: Dictionary = TrialData.DATA.get(data_id, {})
	var type: String = data.get("type", "")
	var path: String = MINIGAMES.get(type, "")
	if data.is_empty() or path == "" or not ResourceLoader.exists(path):
		push_warning("ScriptPlayer: cannot run minigame '%s' (type '%s')" % [data_id, type])
		_state = ""
		_step()
		return
	var g := _gen
	_portrait_layer.visible = false
	var scr: Script = load(path)
	var mg: Control = scr.new()
	mg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var d := data.duplicate(true)
	d["id"] = data_id
	if mg.has_method("setup"):
		mg.setup(d)
	Game.begin_minigame()
	minigame_started.emit(data_id, type)
	minigame_layer.add_child(mg)
	var result: Variant = await mg.finished
	if g != _gen or not is_inside_tree():
		return
	if typeof(result) == TYPE_DICTIONARY and result.has("flags"):
		var fl: Dictionary = result["flags"]
		for k in fl.keys():
			Game.set_flag(k, fl[k])
	mg.queue_free()
	minigame_finished.emit(data_id)
	_portrait_layer.visible = true
	_state = ""
	_step()


# =================================================================== visual widgets (inner classes)
## Mouse-transparent Control that calls painter.call(self) from _draw().
class Painter extends Control:
	var painter: Callable

	func _init(p: Callable = Callable()) -> void:
		painter = p
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


## The dialogue box: slanted, chamfered panel with a hard ink shadow, a speaker-coloured accent bar,
## diagonal stripes crossing the top edge and a faint water line. Modes: speech, narr, think, choice.
class TextBox extends Control:
	var mode := ""
	var accent := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_mode(m: String, acc: Color) -> void:
		if m == mode and acc == accent:
			return
		mode = m
		accent = acc
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var sl := TB_SLANT
		var body := Style.Geo.chamfer(Style.Geo.slant_poly(Rect2(0, 0, w, h), sl), [26.0, 0.0, 26.0, 0.0])
		var edge := Style.AQUA
		var top := Color(0.12, 0.075, 0.25, 0.97)
		var bot := Color(0.035, 0.02, 0.085, 0.97)
		match mode:
			"narr":
				edge = Color("8a6fd0")
				top = Color(0.09, 0.055, 0.18, 0.96)
				bot = Color(0.03, 0.018, 0.07, 0.96)
			"think":
				top = Color(0.04, 0.13, 0.21, 0.96)
				bot = Color(0.015, 0.045, 0.1, 0.96)
			"choice":
				edge = Style.GOLD
		# thought bubbles rising from the top-left corner
		if mode == "think":
			for bub in [[Vector2(40, -12), 6.0], [Vector2(62, -31), 9.0], [Vector2(95, -49), 13.0]]:
				var bc: Vector2 = bub[0]
				var br: float = bub[1]
				draw_circle(bc + Vector2(4, 4), br, Color(Style.INK, 0.9))
				draw_circle(bc, br, edge)
				draw_circle(bc, br - 2.5, top)
		# hard shadow, outline, vertical gradient fill
		draw_colored_polygon(Style.Geo.offset(body, Vector2(10, 10)), Color(Style.INK, 0.92))
		draw_colored_polygon(body, edge)
		var inner_a: Array = Geometry2D.offset_polygon(body, -3.0, Geometry2D.JOIN_MITER)
		if inner_a.size() > 0:
			var ip: PackedVector2Array = inner_a[0]
			var cols := PackedColorArray()
			for p in ip:
				cols.append(top.lerp(bot, clampf(p.y / h, 0.0, 1.0)))
			draw_polygon(ip, cols)
		var inner2: Array = Geometry2D.offset_polygon(body, -9.0, Geometry2D.JOIN_MITER)
		if inner2.size() > 0:
			var lp: PackedVector2Array = inner2[0]
			lp.append(lp[0])
			draw_polyline(lp, Color(edge, 0.16), 1.0)
		# speaker accent bar parallel to the slanted left edge
		if mode == "speech" or mode == "think":
			var y0 := 30.0
			var y1 := h - 18.0
			var x0 := sl * (1.0 - y0 / h) + 15.0
			var x1 := sl * (1.0 - y1 / h) + 15.0
			draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + 6, y0), Vector2(x1 + 6, y1), Vector2(x1, y1)]),
				Color(accent if mode == "speech" else edge, 0.95))
		# diagonal stripes crossing the top edge (speaker colour)
		var stripe_col := accent if mode == "speech" else edge
		var sr := Rect2(w - 262, -10, 170, 20)
		Style.Geo.draw_stripes(self, Rect2(sr.position + Vector2(3, 3), sr.size), 5, Color(Style.INK, 0.9), 10.0, 8.0)
		Style.Geo.draw_stripes(self, sr, 5, stripe_col, 10.0, 8.0)
		# faint water line along the bottom
		var wave := PackedVector2Array()
		for i in 49:
			wave.append(Vector2(44.0 + (w - 150.0) * i / 48.0, h - 12.0 + sin(i * 0.8) * 2.5))
		draw_polyline(wave, Color(edge, 0.14), 2.0)
		# narration: diamond clasp on the top edge
		if mode == "narr":
			var c := Vector2(w * 0.5, 1)
			var d := PackedVector2Array([c + Vector2(0, -13), c + Vector2(16, 0), c + Vector2(0, 13), c + Vector2(-16, 0)])
			Style.Geo.draw_shape(self, d, edge, Style.INK, 3.0, Color(Style.INK, 0.9), Vector2(3, 3))
			for sx in [-1.0, 1.0]:
				draw_line(c + Vector2(sx * 26, 0), c + Vector2(sx * 120, 0), Color(edge.lightened(0.35), 0.9), 3.0)


## Speaker name as a slanted banner in the speaker's colour, with the talent in a small ink tab.
class NameBanner extends Control:
	var nm := ""
	var talent := ""
	var col := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_banner(n: String, t: String, c: Color) -> void:
		if n == nm and t == talent and c == col:
			return
		nm = n
		talent = t
		col = c
		queue_redraw()

	func _draw() -> void:
		var f := Style.display_font()
		var fs := 27
		var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var h := 46.0
		var sl := 14.0
		var w := nw + 52.0
		var poly := Style.Geo.slant_poly(Rect2(0, 0, w, h), sl)
		Style.Geo.draw_shape(self, poly, col, Style.INK, 3.0, Color(Style.INK, 0.95), Vector2(7, 7))
		Style.Geo.draw_stripes(self, Rect2(w - 46, 6, 20, h - 12), 2, Color(1, 1, 1, 0.3), 8.0, 4.0)
		var by := (h + f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		draw_string_outline(f, Vector2(22, by), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Style.INK)
		draw_string(f, Vector2(22, by), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if talent != "":
			var ts := 14
			var tw := f.get_string_size(talent, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
			var tr := Rect2(w - sl - 4, h - 25, tw + 38, 23)
			Style.Geo.draw_shape(self, Style.Geo.slant_poly(tr, 8.0), Color(Style.INK, 0.96), col, 2.0,
				Color(Style.INK, 0.8), Vector2(5, 5))
			var tby := tr.position.y + (tr.size.y + f.get_ascent(ts) - f.get_descent(ts)) * 0.5
			draw_string(f, Vector2(tr.position.x + 19, tby), talent, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, col.lightened(0.4))


## Continue indicator: a bobbing water droplet that leaves a ripple each time it lands.
class Droplet extends Control:
	var _t := 0.0
	var _drop := Style.Geo.droplet(Vector2.ZERO, 7.0)
	var _drop_sh := Style.Geo.droplet(Vector2(3, 3), 7.0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var ph := fmod(_t * 2.1, 1.0)
		var hop := 4.0 * ph * (1.0 - ph)
		var base := Vector2(size.x * 0.5, size.y - 7.0)
		draw_set_transform(base, 0.0, Vector2(1.0, 0.32))
		draw_arc(Vector2.ZERO, 4.0 + ph * 13.0, 0.0, TAU, 24, Color(Style.AQUA, 0.8 * (1.0 - ph)), 2.0)
		var sq := 0.82 if ph < 0.07 or ph > 0.95 else 1.0
		draw_set_transform(base + Vector2(0, -9.0 - hop * 12.0), 0.0, Vector2(2.0 - sq, sq))
		draw_colored_polygon(_drop_sh, Color(Style.INK, 0.9))
		draw_colored_polygon(_drop, Style.AQUA)
		draw_circle(Vector2(-2.5, -1.0), 2.2, Color(1, 1, 1, 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Choice option: slanted, chamfered plate with a number badge; slides right + glows on hover/focus.
class ChoiceButton extends Button:
	var idx := 1
	var text_value := ""
	var slide := 0.0:
		set(v):
			slide = v
			queue_redraw()
	var glow := 0.0:
		set(v):
			glow = v
			queue_redraw()
	var _hover_tw: Tween

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, empty)
		mouse_entered.connect(func() -> void: _set_hot(true))
		mouse_exited.connect(func() -> void: _set_hot(has_focus()))
		focus_entered.connect(func() -> void: _set_hot(true))
		focus_exited.connect(func() -> void: _set_hot(is_hovered()))
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func setup(i: int, t: String) -> void:
		idx = i
		text_value = t

	func appear(delay: float) -> void:
		var p := position
		position = p + Vector2(110, 0)
		modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "position", p, 0.22).set_delay(delay).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.1).set_delay(delay)

	func _set_hot(on: bool) -> void:
		if _hover_tw:
			_hover_tw.kill()
		_hover_tw = create_tween().set_parallel(true)
		_hover_tw.tween_property(self, "slide", 18.0 if on else 0.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_hover_tw.tween_property(self, "glow", 1.0 if on else 0.0, 0.12)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var off := Vector2(slide, 0)
		var dm := get_draw_mode()
		var down := dm == DRAW_PRESSED or dm == DRAW_HOVER_PRESSED
		var poly := Style.Geo.chamfer(Style.Geo.slant_poly(Rect2(off, Vector2(w, h)), 18.0), [0.0, 14.0, 0.0, 14.0])
		if glow > 0.01:
			var g: Array = Geometry2D.offset_polygon(poly, 8.0 * glow, Geometry2D.JOIN_MITER)
			if g.size() > 0:
				draw_colored_polygon(g[0], Color(Style.AQUA, 0.25 * glow))
		var fill := Color(0.075, 0.045, 0.16, 0.97).lerp(Color(0.2, 0.12, 0.4, 0.98), glow)
		var edge := Style.AQUA_DEEP.lerp(Style.GOLD, glow)
		if down:
			fill = Color(0.1, 0.45, 0.5, 1.0)
			edge = Style.YUZU
		Style.Geo.draw_shape(self, poly, fill, edge, 3.0, Color(Style.INK, 0.92), Vector2(7, 7) - off * 0.25)
		# number badge
		var bp := Style.Geo.slant_poly(Rect2(off + Vector2(22, 12), Vector2(42, h - 24)), 9.0)
		Style.Geo.draw_shape(self, bp, Style.AQUA.lerp(Style.GOLD, glow), Style.INK, 2.0, Color(0, 0, 0, 0), Vector2.ZERO)
		var f := Style.display_font()
		var ns := str(idx)
		var nfs := 22
		var nsz := f.get_string_size(ns, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs)
		var nby := (h + f.get_ascent(nfs) - f.get_descent(nfs)) * 0.5
		draw_string(f, Vector2(off.x + 43 - nsz.x * 0.5, nby), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Style.INK)
		# label
		var bf := Style.body_font()
		var fs := 24
		while fs > 16 and bf.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 150:
			fs -= 1
		var by := (h + bf.get_ascent(fs) - bf.get_descent(fs)) * 0.5
		draw_string_outline(bf, Vector2(off.x + 84, by), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Style.INK)
		draw_string(bf, Vector2(off.x + 84, by), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.TEXT.lerp(Style.GOLD, glow))
		if glow > 0.01:
			Style.Geo.draw_stripes(self, Rect2(off.x + w - 104, 15, 62, h - 30), 3, Color(Style.GOLD, 0.9 * glow), 12.0, 7.0)
