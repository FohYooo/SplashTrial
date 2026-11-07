extends Control
## Pause menu / notebook overlay (Esc). Main owns one instance on a high CanvasLayer.
##   open("clues")  open("skills")  open("settings")  close()
## Pauses the tree while open. Angular house style: chamfered ink panel with a hard shadow,
## slanted gold title tab, slanted tab buttons, diamond icon frame.

signal quit_to_title

const Style := preload("res://scripts/ui/style.gd")
const Fx := preload("res://scripts/ui/fx.gd")
const Clues := preload("res://scripts/data/clues.gd")
const Skills := preload("res://scripts/data/skills.gd")
const Assets := preload("res://scripts/core/assets.gd")

const PANEL_POS := Vector2(60, 44)
const PANEL_SIZE := Vector2(1160, 632)

var _content: Control
var _tab := "clues"
var _list: VBoxContainer
var _detail_title: Label
var _detail_desc: Label
var _detail_icon: TextureRect
var _detail_deco: Control
var _selected := ""
var _list_buttons := {}
var _animate := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func is_open() -> bool:
	return visible


func open(tab: String = "clues") -> void:
	_tab = tab
	visible = true
	get_tree().paused = true
	Audio.sfx("confirm")
	_animate = true
	_rebuild()


func close() -> void:
	visible = false
	get_tree().paused = false
	Audio.sfx("cancel")


func _unhandled_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_list_buttons.clear()
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(Style.INK, 0.84)
	add_child(dim)
	Fx.vignette(self, Style.INK, 0.8, 0.4)
	var bg_deco := Deco.new(func(ci: Control) -> void:
		Style.draw_stripes(ci, Rect2(1040, 8, 220, 26), 6, Color(Style.AQUA, 0.35), 14.0, 10.0)
		Style.draw_stripes(ci, Rect2(20, 688, 220, 26), 6, Color(Style.YUZU, 0.35), 14.0, 10.0))
	bg_deco.size = Vector2(1280, 720)
	add_child(bg_deco)
	var panel := Control.new()
	panel.position = PANEL_POS
	panel.size = PANEL_SIZE
	add_child(panel)
	var frame := Deco.new(func(ci: Control) -> void:
		var body := Style.chamfer(Style.Geo.rect_poly(Rect2(Vector2.ZERO, PANEL_SIZE)), [36.0, 0.0, 36.0, 0.0])
		Style.draw_shape(ci, body, Color(0.06, 0.035, 0.13, 0.985), Style.AQUA, 3.0, Color(Style.INK, 0.95), Vector2(14, 14))
		var inner := Style.chamfer(Style.Geo.rect_poly(Rect2(Vector2(10, 10), PANEL_SIZE - Vector2(20, 20))), [28.0, 0.0, 28.0, 0.0])
		inner.append(inner[0])
		ci.draw_polyline(inner, Color(Style.AQUA, 0.16), 1.0)
		# slanted divider under the header
		ci.draw_colored_polygon(Style.slant_poly(Rect2(24, 84, PANEL_SIZE.x - 48, 4), 4.0), Color(Style.AQUA, 0.55))
		Style.draw_stripes(ci, Rect2(PANEL_SIZE.x - 170, PANEL_SIZE.y - 30, 130, 14), 5, Color(Style.YUZU, 0.85), 10.0, 7.0)
		# water line along the bottom
		var wave := PackedVector2Array()
		for i in 61:
			wave.append(Vector2(40.0 + (PANEL_SIZE.x - 260.0) * i / 60.0, PANEL_SIZE.y - 22.0 + sin(i * 0.7) * 3.0))
		ci.draw_polyline(wave, Color(Style.AQUA, 0.18), 2.0))
	frame.size = PANEL_SIZE
	panel.add_child(frame)
	# slanted gold title tab
	var ttab := Deco.new(func(ci: Control) -> void:
		Style.draw_shape(ci, Style.slant_poly(Rect2(0, 0, 230, 62), 18.0), Style.GOLD, Style.INK, 3.0, Color(Style.INK, 0.95), Vector2(7, 7)))
	ttab.position = Vector2(-16, -18)
	ttab.size = Vector2(230, 62)
	panel.add_child(ttab)
	var title := Style.title_label("PAUSED", 38, Style.INK, Color(0, 0, 0, 0), 0)
	title.position = Vector2(26, -12)
	panel.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(262, 22)
	tabs.add_theme_constant_override("separation", 16)
	panel.add_child(tabs)
	for t in [["clues", "Truth Drops"], ["skills", "Skills"], ["settings", "Settings"]]:
		var b := Style.button(t[1], Vector2(176, 46), 20)
		if t[0] == _tab:
			b.add_theme_color_override("font_color", Style.INK)
			b.add_theme_color_override("font_hover_color", Style.INK)
			b.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
			b.add_theme_stylebox_override("normal", Style.slant_box(Style.AQUA, Style.INK, 2, 0.2, Color(Style.YUZU, 0.95), Vector2(5, 5)))
			b.add_theme_stylebox_override("hover", Style.slant_box(Style.AQUA.lightened(0.2), Style.INK, 2, 0.2, Color(Style.YUZU, 0.95), Vector2(6, 6)))
		b.pressed.connect(func() -> void:
			_tab = t[0]
			Audio.sfx("select")
			_animate = false
			_rebuild())
		b.mouse_entered.connect(func() -> void: Audio.sfx("select", 1.25, -14.0))
		tabs.add_child(b)
	var resume := Style.button("Resume", Vector2(150, 46), 20)
	resume.position = Vector2(838, 22)
	resume.pressed.connect(close)
	panel.add_child(resume)
	var quit := Style.button("Title", Vector2(122, 46), 20)
	quit.position = Vector2(1010, 22)
	quit.pressed.connect(func() -> void:
		close()
		quit_to_title.emit())
	panel.add_child(quit)
	_content = Control.new()
	_content.position = Vector2(34, 104)
	_content.size = Vector2(1092, 500)
	panel.add_child(_content)
	match _tab:
		"clues":
			_build_list(Game.clues, true)
		"skills":
			_build_list(Game.skills, false)
		"settings":
			_build_settings()
	if _animate:
		# snap in from the left (works while paused: this node always processes)
		panel.position = PANEL_POS - Vector2(48, 0)
		panel.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(panel, "position", PANEL_POS, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "modulate:a", 1.0, 0.1)


func _build_list(ids: Array, is_clues: bool) -> void:
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(408, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	# margins keep the slanted buttons' overhang + hard shadow inside the scroll clip
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(380, 0)
	_list.add_theme_constant_override("separation", 10)
	margin.add_child(_list)
	var detail := Control.new()
	detail.position = Vector2(430, 0)
	detail.size = Vector2(662, 500)
	_content.add_child(detail)
	var accent := Style.AQUA if is_clues else Style.YUZU
	_detail_deco = Deco.new(func(ci: Control) -> void:
		var body := Style.chamfer(Style.Geo.rect_poly(Rect2(0, 0, 662, 500)), [28.0, 0.0, 28.0, 0.0])
		Style.draw_shape(ci, body, Color(0.1, 0.065, 0.21, 0.97), Color(accent, 0.7), 2.0, Color(Style.INK, 0.9), Vector2(9, 9))
		var c := Vector2(122, 118)
		var dia := PackedVector2Array([c + Vector2(0, -100), c + Vector2(100, 0), c + Vector2(0, 100), c + Vector2(-100, 0)])
		Style.draw_shape(ci, dia, Color(0.06, 0.035, 0.13, 1.0), accent, 3.0, Color(Style.INK, 0.9), Vector2(7, 7))
		ci.draw_arc(c, 68.0, 0.0, TAU, 40, Color(accent, 0.16), 2.0)
		if _detail_icon and _detail_icon.texture == null and _selected != "":
			if is_clues:
				ci.draw_colored_polygon(Style.Geo.droplet(c + Vector2(0, 20), 32.0), Style.AQUA)
				ci.draw_circle(c + Vector2(-9, 12), 8.0, Color(1, 1, 1, 0.7))
			else:
				ci.draw_circle(c, 46.0, Style.YUZU)
				ci.draw_circle(c, 38.0, Color("fff0b8"))
				for k in 8:
					var a := TAU * k / 8.0
					ci.draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a), sin(a)) * 7.0,
						c + Vector2(cos(a - 0.3), sin(a - 0.3)) * 33.0, c + Vector2(cos(a + 0.3), sin(a + 0.3)) * 33.0]), Color("ffc85a"))
		Style.draw_stripes(ci, Rect2(480, 22, 140, 14), 5, Color(accent, 0.8), 10.0, 7.0))
	_detail_deco.size = detail.size
	detail.add_child(_detail_deco)
	_detail_icon = TextureRect.new()
	_detail_icon.position = Vector2(122 - 72, 118 - 72)
	_detail_icon.size = Vector2(144, 144)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(_detail_icon)
	_detail_title = Style.title_label("", 30, Style.GOLD, Style.INK, 8)
	_detail_title.position = Vector2(30, 236)
	detail.add_child(_detail_title)
	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.position = Vector2(30, 284)
	_detail_desc.size = Vector2(604, 200)
	_detail_desc.add_theme_font_size_override("font_size", 19)
	detail.add_child(_detail_desc)
	var count := Style.title_label("%d COLLECTED" % ids.size() if is_clues else "%d LEARNED" % ids.size(), 16, accent, Style.INK, 5)
	count.position = Vector2(262, 50)
	detail.add_child(count)
	if ids.is_empty():
		_detail_title.text = "Nothing yet"
		_detail_desc.text = "Investigate to find Truth Drops." if is_clues else "Hang out with others during Free Time to learn skills."
		return
	for id in ids:
		var b := Style.button(Clues.clue_name(id) if is_clues else Skills.skill_name(id), Vector2(366, 44), 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_show_detail.bind(id, is_clues))
		b.mouse_entered.connect(_show_detail.bind(id, is_clues))
		_list.add_child(b)
		_list_buttons[id] = b
	_show_detail(ids[0], is_clues)


func _show_detail(id: String, is_clues: bool) -> void:
	if is_clues:
		_detail_title.text = Clues.clue_name(id)
		_detail_desc.text = Clues.desc(id)
		_detail_icon.texture = Assets.clue_icon(id)
	else:
		_detail_title.text = Skills.skill_name(id)
		_detail_desc.text = Skills.desc(id)
		_detail_icon.texture = null
	var fs := 30
	while fs > 20 and Style.display_font().get_string_size(_detail_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 600:
		fs -= 2
	_detail_title.add_theme_font_size_override("font_size", fs)
	_detail_desc.add_theme_font_size_override("font_size", 19 if _detail_desc.text.length() < 300 else 17)
	# mark the selected entry with a gold plate
	if _selected != id and _list_buttons.has(_selected) and is_instance_valid(_list_buttons[_selected]):
		var old: Button = _list_buttons[_selected]
		old.remove_theme_stylebox_override("normal")
		old.remove_theme_color_override("font_color")
	_selected = id
	if _list_buttons.has(id):
		var b: Button = _list_buttons[id]
		b.add_theme_stylebox_override("normal", Style.slant_box(Color(0.2, 0.13, 0.38, 0.98), Style.GOLD, 2, 0.2, Color(Style.YUZU, 0.8), Vector2(5, 5)))
		b.add_theme_color_override("font_color", Style.GOLD)
	if _detail_deco:
		_detail_deco.queue_redraw()


func _build_settings() -> void:
	var box := Deco.new(func(ci: Control) -> void:
		var body := Style.chamfer(Style.Geo.rect_poly(Rect2(0, 0, 1092, 500)), [28.0, 0.0, 28.0, 0.0])
		Style.draw_shape(ci, body, Color(0.1, 0.065, 0.21, 0.97), Color(Style.AQUA, 0.6), 2.0, Color(Style.INK, 0.9), Vector2(9, 9)))
	box.size = Vector2(1092, 500)
	_content.add_child(box)
	var v := VBoxContainer.new()
	v.position = Vector2(56, 40)
	v.add_theme_constant_override("separation", 26)
	_content.add_child(v)
	v.add_child(_slider_row("Music volume", Game.music_volume, func(x: float) -> void:
		Game.music_volume = x
		Audio.apply_volumes()))
	v.add_child(_slider_row("Sound volume", Game.sfx_volume, func(x: float) -> void:
		Game.sfx_volume = x
		Audio.apply_volumes()
		Audio.sfx("select")))
	v.add_child(_slider_row("Text speed", (Game.text_speed - 0.4) / 2.6, func(x: float) -> void:
		Game.text_speed = 0.4 + x * 2.6))
	var fs := CheckButton.new()
	fs.text = "Fullscreen (F11)"
	fs.button_pressed = Game.fullscreen
	fs.add_theme_font_size_override("font_size", 22)
	fs.add_theme_color_override("font_color", Style.TEXT)
	fs.add_theme_color_override("font_hover_color", Style.GOLD)
	fs.add_theme_color_override("font_pressed_color", Style.AQUA)
	fs.toggled.connect(func(_on: bool) -> void: Game.toggle_fullscreen())
	v.add_child(fs)
	var tip := Style.label("Tip: hold Ctrl to fast-forward dialogue. Esc opens this menu. Number keys pick choices.", 18, Style.TEXT_DIM)
	v.add_child(tip)
	if not visibility_changed.is_connected(Game.save_settings):
		visibility_changed.connect(Game.save_settings)


func _slider_row(text: String, value: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	var l := Style.title_label(text.to_upper(), 20, Style.AQUA, Style.INK, 5)
	l.custom_minimum_size = Vector2(240, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(460, 32)
	s.value_changed.connect(cb)
	h.add_child(s)
	return h


## Mouse-transparent Control that calls painter.call(self) from _draw().
class Deco extends Control:
	var painter: Callable

	func _init(p: Callable = Callable()) -> void:
		painter = p
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)
