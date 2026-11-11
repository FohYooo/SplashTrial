extends Control
## EVIDENCE VIEWER: leaf through the pictures of a Truth Drop with next, previous and zoom.
## It shows each picture and its stamp and nothing else: it never marks or names anything in a picture.
##
## Two ways in:
##   As an overlay (notebook, or a Truth Drop during a trial segment):
##     var v := EvidenceViewer.new(); v.setup({"clue": id}); add_child(v); await v.closed
##     Pauses the tree while open, and puts it back the way it found it.
##   As a trial segment (data type "evidence", run by ScriptPlayer like any minigame):
##     {"type": "evidence", "clue": id (or "images": [...]), "speaker": ..., "prompt": ...,
##      "answers": [picture index, ...] (any order; one or several), "wrong": {speaker, expr, text}}
##     The player picks the pictures the question asks for. Wrong costs convince, retry until right.
##
## Keys: Left/Right or A/D = previous/next, wheel or +/- = zoom, drag = pan, 0 = fit, Esc = close (overlay only).
## In a segment: Space = pick or unpick this picture, Enter = confirm.

signal finished(result: Dictionary)
signal closed

const Style := preload("res://scripts/ui/style.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Clues := preload("res://scripts/data/clues.gd")
const Chapters := preload("res://scripts/data/chapters.gd")

const W := 1280.0
const H := 720.0
const ZOOMS := [1.0, 1.5, 2.0, 3.0, 4.0]
const VIEW_RECT := Rect2(90, 54, 1100, 520)
const PICK_RECT := Rect2(150, 190, 980, 378)
const MAX_RASTER := 4096.0

var _data := {}
var _clue := ""
var _images: Array = []
var _pick := false
var _answers: Array = []
var _i := 0
var _zoom_i := 0
var _pan := Vector2.ZERO
var _fit := Vector2.ONE
var _picked: Array = []
var _busy := false
var _done := false
var _was_paused := false
var _dragging := false

var _frame_rect := VIEW_RECT
var _view: Control
var _pic: TextureRect
var _stamp: Label
var _count: Label
var _zoom_label: Label
var _thumbs: Array = []
var _pick_btn: Button
var _confirm: Button
var _hires: Texture2D = null
var _hires_i := -1
var _say_root: Control = null


## data: {"clue": id} or {"images": [...]}, optional "zoom"; type "evidence" makes it a trial segment.
func setup(d: Dictionary) -> void:
	_data = d
	_clue = str(d.get("clue", ""))
	_images = d.get("images", Clues.images(_clue))
	_pick = str(d.get("type", "")) == "evidence"
	_answers = d.get("answers", [])
	_frame_rect = PICK_RECT if _pick else VIEW_RECT


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _pick:
		process_mode = Node.PROCESS_MODE_ALWAYS   # the overlay pauses the tree; a segment is paused like any other
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not _pick:
		_was_paused = get_tree().paused
		get_tree().paused = true
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(Style.INK, 0.9 if not _pick else 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_build()
	_show_image(0)
	var want := float(_data.get("zoom", 1.0))
	for z in ZOOMS.size():
		if ZOOMS[z] <= want:
			_zoom_i = z
	if _zoom_i > 0:
		_apply_zoom()
	if Game.autotest:
		_autoplay.call_deferred()


func _exit_tree() -> void:
	if not _pick and is_inside_tree():
		get_tree().paused = _was_paused


# =================================================================== building
func _build() -> void:
	var r := _frame_rect
	var frame := Panel.new()
	frame.position = r.position - Vector2(6, 6)
	frame.size = r.size + Vector2(12, 12)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", Style.cut_box(Color(0.06, 0.035, 0.13, 1.0), 14, Style.AQUA, 3, Color(Style.INK, 0.95), Vector2(8, 8)))
	add_child(frame)
	_view = Control.new()
	_view.position = r.position
	_view.size = r.size
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	add_child(_view)
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_pic)
	var by := r.end.y + 12.0
	_stamp = Style.title_label("", 20, Style.GOLD, Style.INK, 5)
	_stamp.position = Vector2(r.position.x, by + 4)
	_stamp.size = Vector2(420, 30)
	_stamp.clip_text = true
	add_child(_stamp)
	_count = Style.label("", 16, Style.TEXT_DIM, true)
	_count.position = Vector2(r.end.x - 456.0 - 170.0, by + 8)
	_count.size = Vector2(90, 24)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_count)
	var bw := 106.0
	var row := [["<  Prev", _step_image.bind(-1)], ["Next  >", _step_image.bind(1)], ["Zoom -", _zoom_by.bind(-1)], ["Zoom +", _zoom_by.bind(1)]]
	for i in row.size():
		var b := Style.button(str(row[i][0]), Vector2(bw, 38), 15)
		b.position = Vector2(r.end.x - (bw + 8.0) * (row.size() - i), by)
		b.size = Vector2(bw, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(row[i][1])
		add_child(b)
	_zoom_label = Style.label("", 15, Style.AQUA, true)
	_zoom_label.position = Vector2(r.end.x - 456.0 - 70.0, by + 9)
	add_child(_zoom_label)
	_build_thumbs(by + 48.0)
	if _pick:
		_build_pick_ui()
	else:
		var close := Style.button("Close  [Esc]", Vector2(150, 40), 17)
		close.position = Vector2(W - 170, 8)
		close.focus_mode = Control.FOCUS_NONE
		close.pressed.connect(_close)
		add_child(close)
		var title := Style.title_label(Clues.clue_name(_clue), 24, Style.GOLD, Style.INK, 6)
		title.position = Vector2(92, 12)
		add_child(title)


func _build_thumbs(y: float) -> void:
	var n := _images.size()
	if n < 2:
		return
	var tw_ := minf(92.0, (1160.0 - (n - 1) * 8.0) / n)
	var th := tw_ * 0.56
	var x0 := (W - (n * tw_ + (n - 1) * 8.0)) * 0.5
	for i in n:
		var b := Button.new()
		b.position = Vector2(x0 + i * (tw_ + 8.0), y)
		b.size = Vector2(tw_, th)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		var tr := TextureRect.new()
		tr.texture = _base_tex(i, 256)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.clip_contents = true
		tr.size = b.size
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
		var edge := Panel.new()
		edge.name = "Edge"
		edge.size = b.size
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(edge)
		b.pressed.connect(_show_image.bind(i))
		add_child(b)
		_thumbs.append(b)


func _build_pick_ui() -> void:
	var p := Panel.new()
	p.position = Vector2(40, 84)
	p.size = Vector2(1200, 92)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Style.cut_box(Color(0.05, 0.025, 0.12, 0.95), 16, Style.AQUA, 3, Color(Style.INK, 0.92), Vector2(8, 8)))
	add_child(p)
	var who := str(_data.get("speaker", "mochi"))
	var tag := Style.title_label(Cast.display_name(who), 18, Cast.color(who).lightened(0.2), Style.INK, 5)
	tag.position = Vector2(22, 8)
	p.add_child(tag)
	var l := Style.label(str(_data.get("prompt", "")), 21, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(22, 34)
	l.size = Vector2(1156, 54)
	p.add_child(l)
	_pick_btn = Style.button("Pick this one  [Space]", Vector2(122, 84), 15)
	_pick_btn.position = Vector2(14, 336)
	_pick_btn.size = Vector2(122, 84)
	_pick_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pick_btn.focus_mode = Control.FOCUS_NONE
	_pick_btn.pressed.connect(_toggle_pick)
	add_child(_pick_btn)
	_confirm = Style.button("That's it!  [Enter]", Vector2(122, 84), 15)
	_confirm.position = Vector2(1144, 336)
	_confirm.size = Vector2(122, 84)
	_confirm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.add_theme_color_override("font_color", Style.GOLD)
	_confirm.pressed.connect(_confirm_pick)
	add_child(_confirm)


# =================================================================== images
static func art_path(art: String) -> String:
	if art.begins_with("res://"):
		return art
	for base in ["res://art/props/%s.svg", "res://art/bg/%s.svg", "res://art/evidence/%s.jpg", "res://art/evidence/%s.png"]:
		var p: String = base % art
		if FileAccess.file_exists(p) or (not p.ends_with(".svg") and ResourceLoader.exists(p)):
			return p
	return ""


## Photographs (art/evidence/*.jpg, rendered by tools/render_evidence3.gd) are raster: drawn at a fitting size here
## and loaded whole for the zoom, so their fine detail is only there when you look for it.
const RASTER_FIT := 1280
static var _raster_cache := {}


static func _is_raster(p: String) -> bool:
	return p.ends_with(".jpg") or p.ends_with(".jpeg") or p.ends_with(".png")


## The full picture, from the raw file (dev runs and exports that keep it) or the imported one.
static func raster_image(p: String) -> Image:
	var img := Image.new()
	if FileAccess.file_exists(p):
		var buf := FileAccess.get_file_as_bytes(p)
		var err := img.load_png_from_buffer(buf) if p.ends_with(".png") else img.load_jpg_from_buffer(buf)
		if err == OK and img.get_width() > 0:
			return img
	if ResourceLoader.exists(p):
		var t: Texture2D = load(p)
		if t != null:
			return t.get_image()
	return null


## A raster picture at most `width` pixels across (cached; `width` <= 0 = full size), or null.
static func raster_tex(p: String, width: int) -> Texture2D:
	var key := "%s@%d" % [p, width]
	if _raster_cache.has(key):
		return _raster_cache[key]
	var img := raster_image(p)
	if img == null:
		return null
	if width > 0 and img.get_width() > width:
		img.resize(width, roundi(img.get_height() * float(width) / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	if width > 0:
		if _raster_cache.size() > 48:
			_raster_cache.clear()
		_raster_cache[key] = t
	return t


func _art(i: int) -> String:
	return art_path(str((_images[i] as Dictionary).get("art", "")))


func _base_tex(i: int, width: int = RASTER_FIT) -> Texture2D:
	var p := _art(i)
	var t: Texture2D = null
	if p != "":
		t = raster_tex(p, width) if _is_raster(p) else Assets.svg(p)
	return t if t != null else Assets.placeholder(Assets.BG_SIZE, Color(0.12, 0.09, 0.2), "evidence")


func _show_image(i: int) -> void:
	if _images.is_empty():
		_stamp.text = "No pictures"
		return
	_i = clampi(i, 0, _images.size() - 1)
	_zoom_i = 0
	_pan = Vector2.ZERO
	_hires = null
	_hires_i = -1
	var tex := _base_tex(_i)
	_pic.texture = tex
	var sz := tex.get_size()
	var k := minf(_frame_rect.size.x / sz.x, _frame_rect.size.y / sz.y)
	_fit = sz * k
	_stamp.text = str((_images[_i] as Dictionary).get("stamp", ""))
	_count.text = "%d / %d" % [_i + 1, _images.size()]
	_apply_zoom()
	_refresh_thumbs()


func _step_image(d: int) -> void:
	if _images.size() < 2:
		return
	Audio.sfx("select")
	_show_image(posmod(_i + d, _images.size()))


func _zoom_by(d: int) -> void:
	var z := clampi(_zoom_i + d, 0, ZOOMS.size() - 1)
	if z == _zoom_i:
		return
	_zoom_i = z
	Audio.sfx("select", 1.0 + z * 0.1)
	_apply_zoom()


## Sizes and places the picture. Past 1x it is redrawn from the SVG at full detail (a photograph is loaded whole),
## so fine marks stay sharp.
func _apply_zoom() -> void:
	var z: float = ZOOMS[_zoom_i]
	if z > 1.0 and _hires_i != _i:
		_load_hires()
	_pic.texture = _hires if z > 1.0 and _hires != null else _base_tex(_i)
	var sz := _fit * z
	_pic.size = sz
	var limit := ((sz - _frame_rect.size) * 0.5).max(Vector2.ZERO)
	_pan = _pan.clamp(-limit, limit)
	_pic.position = (_frame_rect.size - sz) * 0.5 + _pan
	if _zoom_label:
		_zoom_label.text = "%dx" % roundi(z) if z == floorf(z) else "%.1fx" % z


func _load_hires() -> void:
	var p := _art(_i)
	if p != "" and _is_raster(p):
		_hires = raster_tex(p, 0)
		_hires_i = _i if _hires != null else -1
		return
	if p == "" or not FileAccess.file_exists(p):
		return
	var sz: Vector2 = _base_tex(_i).get_size()
	var want := _fit.x * float(ZOOMS[ZOOMS.size() - 1])
	var raster := minf(want / sz.x, MAX_RASTER / sz.x)
	var img := Image.new()
	if img.load_svg_from_string(FileAccess.get_file_as_string(p), raster) == OK and img.get_width() > 0:
		img.generate_mipmaps()
		_hires = ImageTexture.create_from_image(img)
		_hires_i = _i


func _refresh_thumbs() -> void:
	for i in _thumbs.size():
		var edge: Panel = (_thumbs[i] as Button).get_node("Edge")
		var col: Color = Style.AQUA_DEEP
		var w := 1
		if _picked.has(i):
			col = Style.YUZU
			w = 4
		elif i == _i:
			col = Style.AQUA
			w = 3
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0, 0, 0, 0)
		st.border_color = col
		st.set_border_width_all(w)
		edge.add_theme_stylebox_override("panel", st)
	if _pick_btn:
		_pick_btn.text = "Unpick  [Space]" if _picked.has(_i) else "Pick this one  [Space]"


# =================================================================== input
func _on_view_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(-1)
		_view.accept_event()
		return
	var mm := e as InputEventMouseMotion
	if mm and _dragging:
		_pan += mm.relative
		_apply_zoom()
		_view.accept_event()


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo or _done:
		return
	var used := true
	match k.keycode:
		KEY_LEFT, KEY_A:
			_step_image(-1)
		KEY_RIGHT, KEY_D:
			_step_image(1)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_zoom_by(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_by(-1)
		KEY_0:
			_zoom_i = 0
			_pan = Vector2.ZERO
			_apply_zoom()
		KEY_SPACE:
			if _pick:
				_toggle_pick()
		KEY_ENTER, KEY_KP_ENTER:
			if _pick:
				_confirm_pick()
		KEY_ESCAPE:
			if _pick:
				used = false
			else:
				_close()
		KEY_L:
			used = not _pick and Game.main != null and Chapters.logbook()   # the tree is paused here, so Main can't hear it
			if used:
				Game.main.open_log()
		_:
			used = false
	if used:
		get_viewport().set_input_as_handled()


## Closes the overlay from outside (the notebook turning to the Log on L).
func close_now() -> void:
	_close()


func _close() -> void:
	if _done:
		return
	_done = true
	Audio.sfx("cancel")
	closed.emit()
	queue_free()


# =================================================================== trial segment
func _toggle_pick() -> void:
	if not _pick or _busy or _images.is_empty():
		return
	if _picked.has(_i):
		_picked.erase(_i)
	else:
		_picked.append(_i)
	Audio.sfx("select", 1.2)
	_refresh_thumbs()


func _confirm_pick() -> void:
	if not _pick or _busy or _done or _picked.is_empty():
		return
	_busy = true
	Audio.sfx("confirm")
	var right := _picked.size() == _answers.size()
	for a in _answers:
		if not _picked.has(int(a)):
			right = false
	await _pause_for(0.2)
	if right:
		_win()
	else:
		await _lose()


func _win() -> void:
	Audio.sfx("correct")
	Audio.sfx("break", 1.1, -6.0)
	Game.reward(Game.REWARD_PAIR if _answers.size() > 1 else Game.REWARD_CHOICE)
	_stamp_text("CORRECT!", Style.GOLD)
	await _pause_for(1.2)
	_done = true
	finished.emit({})


func _lose() -> void:
	Audio.sfx("wrong")
	Audio.sfx("static", 1.0, -8.0)
	Game.mistake(Game.PENALTY_CHOICE)
	_stamp_text("WRONG!", Style.DANGER)
	_picked.clear()
	_refresh_thumbs()
	var wl: Variant = _data.get("wrong", {})
	var line: Dictionary = wl if typeof(wl) == TYPE_DICTIONARY else {}
	await _say(str(line.get("speaker", _data.get("speaker", "mochi"))), str(line.get("expr", "normal")),
		str(line.get("text", "No... those aren't the ones. Look again.")))
	_busy = false


func _stamp_text(text: String, col: Color) -> void:
	var l := Style.title_label(text, 70, col, Style.INK, 12)
	l.size = Vector2(W, 100)
	l.position = Vector2(0, _frame_rect.get_center().y - 50.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.rotation = deg_to_rad(-3.0)
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(_t(0.6))
	tw.tween_property(l, "modulate:a", 0.0, _t(0.25))
	tw.tween_callback(l.queue_free)


## A plain speech box over the picture. Click or Enter closes it.
func _say(who: String, expr: String, text: String) -> void:
	var root := Panel.new()
	root.position = Vector2(150, 572)
	root.size = Vector2(980, 128)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_theme_stylebox_override("panel", Style.cut_box(Color(0.05, 0.025, 0.12, 0.98), 16, Cast.color(who), 3, Color(Style.INK, 0.92), Vector2(8, 8)))
	add_child(root)
	_say_root = root
	var face := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = Assets.portrait(who, expr)
	at.region = Rect2(90, 24, 300, 300)
	face.texture = at
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.position = Vector2(12, 12)
	face.size = Vector2(104, 104)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(face)
	var name_l := Style.title_label(Cast.display_name(who), 18, Cast.color(who).lightened(0.2), Style.INK, 5)
	name_l.position = Vector2(130, 8)
	root.add_child(name_l)
	var l := Style.label(text, 21, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(130, 36)
	l.size = Vector2(830, 86)
	root.add_child(l)
	var clicked := [false]
	root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			clicked[0] = true)
	var t := 0.0
	while not clicked[0] and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
		if Game.autotest and t > 0.05:
			break
		if t > 0.25 and (Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE)):
			break
	if is_instance_valid(root):
		root.queue_free()
	_say_root = null


func _t(sec: float) -> float:
	return sec * 0.1 if Game.autotest and not Game.autotest_slow else sec


func _pause_for(sec: float) -> void:
	await get_tree().create_timer(_t(sec), not _pick).timeout


# =================================================================== autotest
func _autoplay() -> void:
	await _pause_for(0.3)
	_step_image(1)
	_zoom_by(1)
	_zoom_by(1)
	_pan += Vector2(40, 20)
	_apply_zoom()
	_zoom_by(-1)
	_show_image(0)
	if not _pick:
		print("[autotest] evidence viewer: paged and zoomed %d pictures" % _images.size())
		await _pause_for(0.1)
		_close()
		return
	if Game.debug_minigame != "":
		# one wrong attempt first: the first picture that isn't an answer, or none picked if all are
		for i in _images.size():
			if not _answers.has(i):
				_i = i
				_toggle_pick()
				_confirm_pick()
				break
		while _busy and not _done:
			await get_tree().process_frame
	if _done:
		return
	for a in _answers:
		_i = int(a)
		_toggle_pick()
	_confirm_pick()
