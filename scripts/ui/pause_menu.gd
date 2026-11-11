extends Control
## Pause menu / notebook overlay (Esc). Main owns one instance on a high CanvasLayer.
##   open("clues")  open("alibi")  open("log")  open("skills")  open("settings")  close()
## Pauses the tree while open. Angular house style: chamfered ink panel with a hard shadow,
## slanted gold title tab, slanted tab buttons, diamond icon frame.

signal quit_to_title
signal closed

const Style := preload("res://scripts/ui/style.gd")
const Fx := preload("res://scripts/ui/fx.gd")
const Clues := preload("res://scripts/data/clues.gd")
const Skills := preload("res://scripts/data/skills.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Chapters := preload("res://scripts/data/chapters.gd")
const Alibis := preload("res://scripts/data/alibis.gd")
const EvidenceViewer := preload("res://scripts/ui/evidence_viewer.gd")
const LogRules := preload("res://scripts/data/log_rules.gd")

const PANEL_POS := Vector2(60, 44)
const TABS := [["clues", "Truth Drops"], ["alibi", "Alibi Board"], ["log", "Log"], ["skills", "Skills"], ["settings", "Settings"]]
const TABS_W := 560.0
const MARKS := {"": ["-", Color(0.66, 0.62, 0.78)], "trust": ["TRUST", Style.GOOD], "doubt": ["DOUBT", Style.DANGER], "unsure": ["?", Style.GOLD]}
const MARK_NEXT := {"": "trust", "trust": "doubt", "doubt": "unsure", "unsure": ""}
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
var _detail_view: Button
var _alibi_title: Label
var _alibi_body: Label
var _viewer: Control = null
var _log_section := "timeline"
var _log_text: RichTextLabel = null
var _resume_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func is_open() -> bool:
	return visible


func open(tab: String = "clues", log_section: String = "") -> void:
	_tab = tab if _has_tab(tab) else "clues"
	if log_section != "":
		_log_section = log_section
	if not visible:
		_resume_paused = get_tree().paused
	visible = true
	get_tree().paused = true
	Audio.sfx("confirm")
	_animate = true
	_rebuild()


func close() -> void:
	visible = false
	get_tree().paused = _resume_paused
	Audio.sfx("cancel")
	closed.emit()


func _unhandled_input(e: InputEvent) -> void:
	if not visible or not e is InputEventKey or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_L and not is_instance_valid(_viewer) and _has_tab("log"):
		if _tab == "log":
			close()
		else:
			_switch_tab("log")
		get_viewport().set_input_as_handled()
	elif _tab == "log" and _log_keys(e):
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_V and _tab == "clues" and _selected != "" and not Clues.images(_selected).is_empty():
		open_viewer(_selected)
		get_viewport().set_input_as_handled()


## Opens a Truth Drop's pictures on top of the notebook (the tree is already paused).
func open_viewer(clue_id: String, zoom: float = 1.0) -> void:
	if is_instance_valid(_viewer) or Clues.images(clue_id).is_empty():
		return
	_viewer = EvidenceViewer.new()
	_viewer.setup({"clue": clue_id, "zoom": zoom})
	add_child(_viewer)


## L while the notebook's pictures are open (they keep the key from reaching _unhandled_input): close them and turn to
## the Log, the same as L anywhere else in the notebook.
func show_log() -> void:
	if not visible or not _has_tab("log"):
		return
	if is_instance_valid(_viewer):
		_viewer.call("close_now")
		_viewer = null
	if _tab != "log":
		_switch_tab("log")


## The tabs this chapter shows. The Alibi Board and the Log only exist in chapters that set "alibi_board" and
## "logbook" (Case 3 on), so Cases 1 and 2 keep the notebook they shipped with.
func _tabs() -> Array:
	var out: Array = []
	for t in TABS:
		if t[0] == "alibi" and not bool(Chapters.get_value("alibi_board", false)):
			continue
		if t[0] == "log" and not Chapters.logbook():
			continue
		out.append(t)
	return out


func _has_tab(tab: String) -> bool:
	for t in _tabs():
		if t[0] == tab:
			return true
	return false


func _switch_tab(tab: String) -> void:
	_tab = tab if _has_tab(tab) else "clues"
	Audio.sfx("select")
	_animate = false
	_rebuild()


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
	tabs.position = Vector2(258, 22)
	tabs.add_theme_constant_override("separation", 10)
	panel.add_child(tabs)
	var tabs_shown := _tabs()
	var tab_w := (TABS_W - 10.0 * (tabs_shown.size() - 1)) / tabs_shown.size()
	for t in tabs_shown:
		var b := Style.button(t[1], Vector2(tab_w, 46), 16)
		if t[0] == _tab:
			b.add_theme_color_override("font_color", Style.INK)
			b.add_theme_color_override("font_hover_color", Style.INK)
			b.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
			b.add_theme_stylebox_override("normal", Style.slant_box(Style.AQUA, Style.INK, 2, 0.2, Color(Style.YUZU, 0.95), Vector2(5, 5)))
			b.add_theme_stylebox_override("hover", Style.slant_box(Style.AQUA.lightened(0.2), Style.INK, 2, 0.2, Color(Style.YUZU, 0.95), Vector2(6, 6)))
		b.pressed.connect(_switch_tab.bind(str(t[0])))
		b.mouse_entered.connect(func() -> void: Audio.sfx("select", 1.25, -14.0))
		tabs.add_child(b)
	var resume := Style.button("Resume", Vector2(120, 46), 19)
	resume.position = Vector2(880, 22)
	resume.pressed.connect(close)
	panel.add_child(resume)
	var quit := Style.button("Title", Vector2(110, 46), 19)
	quit.position = Vector2(1016, 22)
	quit.pressed.connect(func() -> void:
		close()
		get_tree().paused = false   # even if something under the notebook had the game paused: we're leaving it
		quit_to_title.emit())
	panel.add_child(quit)
	_content = Control.new()
	_content.position = Vector2(34, 104)
	_content.size = Vector2(1092, 500)
	panel.add_child(_content)
	match _tab:
		"clues":
			_build_list(Game.clues, true)
		"alibi":
			_build_alibi()
		"log":
			_build_log()
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
	_detail_view = Style.button("View pictures  [V]", Vector2(240, 46), 18)
	_detail_view.position = Vector2(262, 96)
	_detail_view.visible = false
	_detail_view.pressed.connect(func() -> void: open_viewer(_selected))
	detail.add_child(_detail_view)
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
	_detail_view.visible = is_clues and not Clues.images(id).is_empty()
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


# =================================================================== Alibi Board
## An hour-by-hour grid for every living guest: rows are times, columns are guests. It only repeats what Mochi has
## heard and never weighs it; the player's own Trust / Doubt / ? mark under each face is the only judgement on it.
func _build_alibi() -> void:
	var guests := Alibis.guests(Chapters.step_reached(Game.main.current_step() if Game.main else "", "discovery"))
	var rows := Alibis.rows(Game.alibi_rows)
	const LEFT := 88.0
	const HEAD := 102.0
	const ROW_H := 36.0
	var col_w := maxf(72.0, (1092.0 - LEFT - 14.0) / maxf(guests.size(), 1))
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(1092, 410)
	_content.add_child(scroll)
	var grid := Control.new()
	grid.custom_minimum_size = Vector2(LEFT + col_w * guests.size(), HEAD + ROW_H * rows.size() + 54.0)
	scroll.add_child(grid)
	var table_h := grid.custom_minimum_size.y
	var deco := Deco.new(func(ci: Control) -> void:
		ci.draw_rect(Rect2(0, 0, grid.custom_minimum_size.x, table_h), Color(0.1, 0.065, 0.21, 0.97))
		for i in rows.size() + 2:
			var y := HEAD + ROW_H * i
			ci.draw_line(Vector2(0, y), Vector2(grid.custom_minimum_size.x, y), Color(Style.AQUA, 0.14), 1.0)
		for i in guests.size():
			var x := LEFT + col_w * i
			ci.draw_line(Vector2(x, 0), Vector2(x, table_h), Color(Style.AQUA, 0.14), 1.0))
	deco.size = grid.custom_minimum_size
	grid.add_child(deco)
	for i in rows.size():
		var l := Style.title_label(str(rows[i]), 15, Style.AQUA, Style.INK, 4)
		l.position = Vector2(10, HEAD + ROW_H * i + 9)
		grid.add_child(l)
	var ml := Style.title_label("REASON", 15, Style.YUZU, Style.INK, 4)
	ml.position = Vector2(10, HEAD + ROW_H * rows.size() + 16)
	grid.add_child(ml)
	for gi in guests.size():
		var g := str(guests[gi])
		var x := LEFT + col_w * gi
		_alibi_head(grid, g, Vector2(x, 0), col_w, HEAD)
		var seen: Array = Game.alibi_seen.get(g, [])
		for i in rows.size():
			var when := str(rows[i])
			var k := Alibis.known(g, when, seen)
			var cell := _alibi_cell(str(k["where"]), str(k["proof"]) != "", Vector2(col_w - 2, ROW_H - 2), 11)
			cell.position = Vector2(x + 1, HEAD + ROW_H * i + 1)
			cell.mouse_entered.connect(_alibi_detail.bind(g, when))
			cell.pressed.connect(_alibi_detail.bind(g, when))
			grid.add_child(cell)
		var motive := Alibis.known_motive(g, seen)
		var mc := _alibi_cell(motive, false, Vector2(col_w - 2, 52), 11)
		mc.position = Vector2(x + 1, HEAD + ROW_H * rows.size() + 1)
		mc.mouse_entered.connect(_alibi_detail.bind(g, ""))
		mc.pressed.connect(_alibi_detail.bind(g, ""))
		grid.add_child(mc)
	var strip := Deco.new(func(ci: Control) -> void:
		var body := Style.chamfer(Style.Geo.rect_poly(Rect2(0, 0, 1092, 84)), [18.0, 0.0, 18.0, 0.0])
		Style.draw_shape(ci, body, Color(0.06, 0.035, 0.13, 0.98), Color(Style.AQUA, 0.6), 2.0, Color(Style.INK, 0.9), Vector2(6, 6)))
	strip.position = Vector2(0, 416)
	strip.size = Vector2(1092, 84)
	_content.add_child(strip)
	_alibi_title = Style.title_label("ALIBI BOARD", 19, Style.GOLD, Style.INK, 5)
	_alibi_title.position = Vector2(24, 8)
	strip.add_child(_alibi_title)
	_alibi_body = Label.new()
	_alibi_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alibi_body.position = Vector2(24, 36)
	_alibi_body.size = Vector2(1044, 44)
	_alibi_body.add_theme_font_size_override("font_size", 16)
	_alibi_body.text = "What each guest has told you, hour by hour. Point at a square to read it. Click the tag under a face to set your own mark."
	strip.add_child(_alibi_body)


## One column head: the guest's face, name and the player's own mark (click to change it).
func _alibi_head(grid: Control, g: String, pos: Vector2, w: float, _h: float) -> void:
	var face := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = Assets.portrait(g, "normal")
	at.region = Rect2(90, 24, 300, 300)
	face.texture = at
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.position = pos + Vector2((w - 56.0) * 0.5, 4)
	face.size = Vector2(56, 56)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(face)
	var name_l := Style.label(Cast.display_name(g), 13, Cast.color(g).lightened(0.25), true)
	name_l.position = pos + Vector2(0, 60)
	name_l.size = Vector2(w, 18)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	grid.add_child(name_l)
	var mark := Button.new()
	mark.position = pos + Vector2(5, 80)
	mark.size = Vector2(w - 10, 21)
	mark.add_theme_font_size_override("font_size", 12)
	mark.focus_mode = Control.FOCUS_NONE
	_style_mark(mark, Game.alibi_mark(g))
	mark.pressed.connect(func() -> void:
		var next := str(MARK_NEXT.get(Game.alibi_mark(g), ""))
		Game.set_alibi_mark(g, next)
		Audio.sfx("select")
		_style_mark(mark, next))
	mark.mouse_entered.connect(_alibi_detail.bind(g, ""))
	grid.add_child(mark)


func _style_mark(b: Button, mark: String) -> void:
	var m: Array = MARKS.get(mark, MARKS[""])
	b.text = str(m[0])
	var col: Color = m[1]
	var st := Style.cut_box(Color(col, 0.16 if mark != "" else 0.05), 4, Color(col, 0.75), 1)
	st.content_margin_left = 2
	st.content_margin_right = 2
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	for k in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(k, st)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, col)


## A square of the grid. A small dot means something backs the entry up; what it's worth is the player's call.
func _alibi_cell(text: String, backed: bool, sz: Vector2, fs: int) -> Button:
	var b := Button.new()
	b.size = sz
	b.text = _fit_cell(text, sz, fs) if text != "" else "-"
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Style.TEXT if text != "" else Color(Style.TEXT_DIM, 0.4))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	b.add_theme_constant_override("outline_size", 0)
	var clear := StyleBoxEmpty.new()
	var over := StyleBoxFlat.new()
	over.bg_color = Color(Style.AQUA, 0.14)
	for k in ["normal", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(k, clear)
	b.add_theme_stylebox_override("hover", over)
	if backed:
		var dot := Deco.new(func(ci: Control) -> void: ci.draw_circle(Vector2.ZERO, 3.0, Style.AQUA))
		dot.position = Vector2(sz.x - 7, 6)
		b.add_child(dot)
	return b


## Trims what won't fit in a square; the strip under the grid always shows it in full.
func _fit_cell(text: String, sz: Vector2, fs: int) -> String:
	var limit := int((sz.x - 8.0) / (fs * 0.56)) * maxi(1, int(sz.y / (fs + 3.0)))
	if text.length() <= limit:
		return text
	var cut := text.substr(0, limit - 3)
	var sp := cut.rfind(" ")
	return (cut.substr(0, sp) if sp > limit / 2 else cut) + "..."


## The strip under the grid: the full text of the square under the mouse. when = "" shows the guest's reason.
func _alibi_detail(g: String, when: String) -> void:
	if _alibi_title == null or not is_instance_valid(_alibi_title):
		return
	var seen: Array = Game.alibi_seen.get(g, [])
	if when == "":
		var motive := Alibis.known_motive(g, seen)
		_alibi_title.text = Cast.display_name(g).to_upper() + "  -  REASON TO KILL"
		_alibi_body.text = motive if motive != "" else "Nothing heard yet."
		return
	var k := Alibis.known(g, when, seen)
	_alibi_title.text = "%s  -  %s" % [Cast.display_name(g).to_upper(), when]
	var where := str(k["where"])
	var proof := str(k["proof"])
	if where == "":
		_alibi_body.text = "Nothing heard yet."
	else:
		_alibi_body.text = "Says: %s\nBacked up by: %s" % [where, proof if proof != "" else "nothing you've heard"]


# =================================================================== Log
## The Logbook, one section at a time. Every entry is drawn the same way: nothing here may look more interesting
## than anything else, so there are no counts, no highlights and no "new" marks.
func _build_log() -> void:
	var side := VBoxContainer.new()
	side.position = Vector2(8, 2)
	side.size = Vector2(232, 496)
	side.add_theme_constant_override("separation", 12)
	_content.add_child(side)
	for s in LogRules.SECTIONS:
		var id := str(s[0])
		var b := Style.button(str(s[1]), Vector2(232, 54), 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		if id == _log_section:
			b.add_theme_stylebox_override("normal", Style.slant_box(Color(0.2, 0.13, 0.38, 0.98), Style.GOLD, 2, 0.2, Color(Style.YUZU, 0.8), Vector2(5, 5)))
			b.add_theme_color_override("font_color", Style.GOLD)
		b.pressed.connect(_show_log_section.bind(id))
		b.mouse_entered.connect(func() -> void: Audio.sfx("select", 1.25, -14.0))
		side.add_child(b)
	var body := Deco.new(func(ci: Control) -> void:
		var shape := Style.chamfer(Style.Geo.rect_poly(Rect2(0, 0, 824, 500)), [28.0, 0.0, 28.0, 0.0])
		Style.draw_shape(ci, shape, Color(0.1, 0.065, 0.21, 0.97), Color(Style.AQUA, 0.6), 2.0, Color(Style.INK, 0.9), Vector2(9, 9)))
	body.position = Vector2(268, 0)
	body.size = Vector2(824, 500)
	_content.add_child(body)
	var title := Style.title_label(_log_title().to_upper(), 26, Style.GOLD, Style.INK, 7)
	title.position = Vector2(30, 14)
	body.add_child(title)
	_log_text = null
	if _log_section == "notes":
		_build_log_notes(body)
		return
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = true
	text.position = Vector2(30, 60)
	text.size = Vector2(770, 420)
	text.mouse_filter = Control.MOUSE_FILTER_STOP
	text.add_theme_font_size_override("normal_font_size", 18)
	text.add_theme_font_size_override("italics_font_size", 18)
	text.add_theme_font_override("italics_font", Style.italic_font())
	text.add_theme_constant_override("line_separation", 5)
	text.scroll_following = _log_section == "transcript"
	text.text = _log_bbcode()
	body.add_child(text)
	_log_text = text


func _log_title() -> String:
	for s in LogRules.SECTIONS:
		if s[0] == _log_section:
			return str(s[1])
	return ""


func _show_log_section(id: String) -> void:
	_log_section = id
	Audio.sfx("select")
	_animate = false
	_rebuild()


## Log tab keys: up/down and page up/down scroll the section, left/right change section.
func _log_keys(e: InputEventKey) -> bool:
	match e.keycode:
		KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN:
			if _log_text == null or not is_instance_valid(_log_text):
				return false
			var bar := _log_text.get_v_scroll_bar()
			var page := bar.page * 0.8 if e.keycode in [KEY_PAGEUP, KEY_PAGEDOWN] else 60.0
			bar.value += page if e.keycode in [KEY_DOWN, KEY_PAGEDOWN] else -page
			return true
		KEY_LEFT, KEY_RIGHT:
			var i := 0
			for n in LogRules.SECTIONS.size():
				if LogRules.SECTIONS[n][0] == _log_section:
					i = n
			_show_log_section(str(LogRules.SECTIONS[posmod(i + (1 if e.keycode == KEY_RIGHT else -1), LogRules.SECTIONS.size())][0]))
			return true
	return false


func _log_bbcode() -> String:
	var out := ""
	match _log_section:
		"people":
			out = _log_people()
		"transcript":
			out = _log_transcript()
		_:
			out = _log_entries(Game.log_entries(_log_section))
	return out if out != "" else "[color=%s]Nothing written down yet.[/color]" % Style.TEXT_DIM.to_html(false)


static func _bb(text: String) -> String:
	return text.replace("[", "[lb]")


## Entries under their day and time headings, oldest first.
func _log_entries(entries: Array) -> String:
	var out := ""
	var last := ""
	for e in entries:
		var when := str(e["when"])
		if when != last and when != "":
			out += _log_heading(when)
			last = when
		out += _log_line(e) + "\n"
	return out


func _log_heading(text: String) -> String:
	return "\n[font_size=16][color=%s]%s[/color][/font_size]\n" % [Style.AQUA.to_html(false), _bb(text.to_upper())]


func _log_line(e: Dictionary) -> String:
	var text := _bb(str(e["text"]))
	if bool(e["struck"]):
		return "[s][color=%s]%s[/color][/s]" % [Style.TEXT_DIM.to_html(false), text]
	if str(e["clock"]) != "":
		return "[color=%s]%s[/color]   %s" % [Style.YUZU.to_html(false), _bb(str(e["clock"])), text]
	return text


## What each guest told Mochi, guest by guest in cast order.
func _log_people() -> String:
	var out := ""
	var entries := Game.log_entries("people")
	for g in Cast.ROSTER:
		var said := entries.filter(func(e: Variant) -> bool: return e["who"] == g)
		if said.is_empty():
			continue
		out += "[color=%s]%s[/color]\n" % [Cast.color(str(g)).lightened(0.25).to_html(false), _bb(Cast.display_name(str(g)).to_upper())]
		for e in said:
			out += _log_line(e) + "\n"
		out += "\n"
	return out


func _log_transcript() -> String:
	var out := ""
	for e in Game.log_transcript:
		var who := str(e["who"])
		var text := _bb(str(e["text"]))
		match who:
			"", "narr":
				out += "[color=%s]%s[/color]\n" % [Style.TEXT_DIM.to_html(false), text]
			"think":
				out += "[color=#a6f2ea]([i]%s[/i])[/color]\n" % text
			"voice":
				out += "[color=%s]???[/color]   %s\n" % [Style.TEXT_DIM.to_html(false), text]
			"all":
				out += "[color=%s]EVERYONE[/color]   %s\n" % [Style.YUZU.to_html(false), text]
			_:
				out += "[color=%s]%s[/color]   %s\n" % [Cast.color(who).lightened(0.25).to_html(false), _bb(Cast.display_name(who).to_upper()), text]
	return out


## The player's own marks on each guest (the same marks as the Alibi Board) and a short free-text note.
func _build_log_notes(body: Control) -> void:
	var guests := Alibis.guests(Chapters.step_reached(Game.main.current_step() if Game.main else "", "discovery"))
	var grid := Control.new()
	grid.position = Vector2(26, 56)
	body.add_child(grid)
	const COLS := 7
	var col_w := 772.0 / COLS
	for i in guests.size():
		_alibi_head(grid, str(guests[i]), Vector2(col_w * (i % COLS), 106.0 * floori(i / float(COLS))), col_w, 102.0)
	var note := TextEdit.new()
	note.position = Vector2(30, 278)
	note.size = Vector2(764, 204)
	note.text = Game.log_note
	note.placeholder_text = "Anything you want to remember. Only you write here."
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Style.TEXT)
	note.add_theme_color_override("caret_color", Style.GOLD)
	note.add_theme_color_override("font_placeholder_color", Color(Style.TEXT_DIM, 0.6))
	var box := Style.cut_box(Color(0.05, 0.03, 0.12, 0.96), 8, Color(Style.AQUA, 0.4), 1)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	note.add_theme_stylebox_override("normal", box)
	note.add_theme_stylebox_override("focus", box)
	note.text_changed.connect(func() -> void:
		if note.text.length() > LogRules.NOTE_MAX:
			note.text = note.text.substr(0, LogRules.NOTE_MAX)
			note.set_caret_line(note.get_line_count() - 1)
			note.set_caret_column(note.get_line(note.get_line_count() - 1).length())
		Game.log_note = note.text)
	body.add_child(note)


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
	var keys := "Esc opens this menu, L opens the Log." if _has_tab("log") else "Esc opens this menu."
	var tip := Style.label("Tip: hold Ctrl to fast-forward dialogue. %s Number keys pick choices." % keys, 18, Style.TEXT_DIM)
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
