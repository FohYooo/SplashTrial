extends Control
## INVESTIGATION - explore the resort (rooms in scripts/data/investigation_data.gd), examine hotspots and
## talk to people until every required Truth Drop is collected, then play "investigation_complete" and
## emit finished({}).
##
## Room view: full-screen bg, invisible hotspot rects (glow + label tag on hover), people as portraits.
## Unexamined things sparkle now and then; examined ones get a check badge. Snippets play in a transparent
## auto_portrait ScriptPlayer overlay; after each one the flag "seen_<script id>" is set.
## Keys: M = map, N = notebook (Esc = pause menu, handled by Main).

signal finished(result: Dictionary)

const ScriptPlayer := preload("res://scripts/core/script_player.gd")
const Assets := preload("res://scripts/core/assets.gd")
const Style := preload("res://scripts/ui/style.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Clues := preload("res://scripts/data/clues.gd")
const Story := preload("res://scripts/data/story.gd")
const Inv := preload("res://scripts/data/investigation_data.gd")

const W := 1280.0
const H := 720.0
const BAR_H := 54.0
const INK := Color("2a1a10")
const DIM := Color(0.5, 0.48, 0.62)

## Map layout (board-local centers; the board panel sits at MAP_BOARD.position).
const MAP_BOARD := Rect2(70, 60, 1140, 620)
const CARD_SIZE := Vector2(168, 124)
const MAP_POS := {
	"dining": Vector2(130, 195), "giftshop": Vector2(130, 495), "storage": Vector2(420, 195),
	"lounge": Vector2(420, 345), "garden": Vector2(625, 345), "changing": Vector2(830, 345),
	"sauna": Vector2(830, 195), "bath": Vector2(1022, 345),
}
const MAP_HUB := Vector2(272, 345)
const MAP_LINKS := [
	["dining", "hub"], ["giftshop", "hub"], ["hub", "lounge"], ["lounge", "storage"],
	["lounge", "garden"], ["garden", "changing"], ["changing", "sauna"], ["changing", "bath"],
]
const STONE_LINKS := [["lounge", "garden"], ["garden", "changing"]]

const OUTLINE_SHADER := """shader_type canvas_item;
uniform vec4 line_color : source_color = vec4(1.0, 0.82, 0.4, 1.0);
uniform float amount = 0.0;
uniform float width = 10.0;
varying vec4 vcol;
void vertex() {
	vcol = COLOR;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = 0.0;
	if (amount > 0.001) {
		vec2 px = TEXTURE_PIXEL_SIZE * width;
		a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV + px * 0.7071).a);
		a = max(a, texture(TEXTURE, UV - px * 0.7071).a);
		a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7071).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7071).a);
	}
	float oa = a * amount * line_color.a;
	float out_a = c.a + (1.0 - c.a) * oa;
	vec3 rgb = (c.rgb * c.a + line_color.rgb * (1.0 - c.a) * oa) / max(out_a, 0.0001);
	COLOR = vec4(rgb, out_a) * vcol;
}
"""

var _room_id := ""
var _world: Control
var _bg: TextureRect
var _hot_layer: Control
var _people_layer: Control
var _fx: Control
var _tag: PanelContainer
var _tag_verb: Label
var _tag_name: Label
var _tag_check: Control
var _bar: Panel
var _room_name: Label
var _room_prog: Label
var _drops_count: Label
var _drops_icon: Control
var _btn_nb: Button
var _btn_map: Button
var _map_pulse := false
var _time := 0.0
var _dim_tw: Tween = null
var _banner_layer: Control
var _sp: Control
var _map: Control = null
var _fade: ColorRect
var _outline_shader: Shader

## Current room's interactive things: {kind, verb, label, script, rect, node, badge, tag_anchor, seen, pop, spark}
var _targets: Array = []
var _hover: Dictionary = {}
var _busy := true
var _done := false
var _map_open := false
var _lock_ms := 0
var _cleared := {}
var _mask_cache := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline_shader = Shader.new()
	_outline_shader.code = OUTLINE_SHADER
	_build_world()
	_fx = Fx.new()
	_fx.targets = _targets
	add_child(_fx)
	_build_tag()
	_build_bar()
	_banner_layer = _layer()
	_sp = ScriptPlayer.new()
	_sp.transparent = true
	_sp.auto_portrait = true
	add_child(_sp)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.02, 0.01, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 10
	add_child(_fade)
	for rid in Inv.ROOMS.keys():
		var p := _room_progress(rid)
		if p.y > 0 and p.x >= p.y:
			_cleared[rid] = true
	Game.clue_added.connect(_on_clue_added)
	Audio.play_music("investigate")
	_run.call_deferred()


func _exit_tree() -> void:
	if Game.clue_added.is_connected(_on_clue_added):
		Game.clue_added.disconnect(_on_clue_added)


# =================================================================== flow
func _run() -> void:
	var start: String = Inv.START_ROOM
	if not Inv.ROOMS.has(start):
		start = str(Inv.ROOM_ORDER[0]) if Inv.ROOM_ORDER.size() > 0 else str(Inv.ROOMS.keys()[0])
	_build_room(start)
	_update_drops(false)
	_bar.modulate.a = 0.0
	_bar.position.y = -BAR_H - 10.0
	_set_dialogue_mode(true, true)
	if Story.has("investigation_start"):
		await _play("investigation_start")
		if not is_inside_tree():
			return
		Game.set_flag("seen_investigation_start", true)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bar, "modulate:a", 1.0, _dur(0.3))
	tw.tween_property(_bar, "position:y", 0.0, _dur(0.35)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_show_banner()
	if Game.has_all_required_clues():
		await _complete()
		return
	_set_dialogue_mode(false)
	if await _enter_script():
		return
	_unlock()
	if Game.autotest:
		_autotest()


## Visits every room and activates every hotspot/person in data order, then finishes.
func _autotest() -> void:
	for rid in Inv.ROOM_ORDER:
		if _done or not is_inside_tree():
			return
		if not Inv.ROOMS.has(rid):
			continue
		if rid != _room_id:
			# go through the map like a player would (exercises the map build / close path)
			_open_map()
			await _wait(0.05)
			_close_map()
			await _travel(rid)
		for t in _targets.duplicate():
			if _done or not is_inside_tree():
				return
			await _wait(0.02)
			await _activate(t)
	if not _done and is_inside_tree():
		print("[autotest] investigation: all rooms visited, missing clues: ", _missing_clues())
		await _complete()


## Plays the current room's enter script on the first visit. Returns true if the investigation finished.
func _enter_script() -> bool:
	var room: Dictionary = Inv.ROOMS.get(_room_id, {})
	var enter := str(room.get("enter_script", ""))
	if enter != "" and not _seen(enter):
		return await _snippet(enter, null)
	return false


func _activate(t: Dictionary) -> void:
	if _done:
		return
	_busy = true
	_set_hover({})
	Audio.sfx("confirm")
	var r: Rect2 = t["rect"]
	_fx.ripple(get_global_mouse_position() if not Game.autotest else r.get_center())
	var node: Control = t["node"]
	if node.has_method("press"):
		node.press()
	await _wait(0.14)
	if _done or not is_inside_tree():
		return
	var person: Control = node if str(t["kind"]) == "person" else null
	if await _snippet(str(t["script"]), person):
		return
	_unlock()


## Plays one snippet as an overlay, marks it seen, and checks for completion.
## Returns true if the investigation is complete (finished is being / has been emitted).
func _snippet(id: String, person: Control) -> bool:
	_set_dialogue_mode(true)
	if person:
		var tw := create_tween()
		tw.tween_property(person, "modulate:a", 0.0, _dur(0.18))
	await _play(id)
	if not is_inside_tree():
		return true
	Game.set_flag("seen_" + id, true)
	Audio.play_music("investigate")
	if person and is_instance_valid(person):
		var tw2 := create_tween()
		tw2.tween_property(person, "modulate:a", 1.0, _dur(0.25))
	_refresh_status()
	if not Game.has_all_required_clues() and _everything_examined():
		# Safety net: never soft-lock if a story script forgot a clue.
		var missing := _missing_clues()
		push_warning("Investigation: everything examined but clues missing: %s" % [missing])
		if Game.autotest:
			print("[autotest] investigation: safety net granted ", missing)
		for c in missing:
			Game.add_clue(c)
	if Game.has_all_required_clues():
		await _complete()
		return true
	_set_dialogue_mode(false)
	_check_room_cleared()
	return false


func _play(id: String) -> void:
	_sp.play_id(id)
	if _sp.is_running():
		await _sp.finished


func _complete() -> void:
	if _done:
		return
	_done = true
	_busy = true
	_set_hover({})
	if _map_open:
		_close_map()
	_set_dialogue_mode(true)
	await _celebrate()
	if not is_inside_tree():
		return
	if Story.has("investigation_complete"):
		await _play("investigation_complete")
		if not is_inside_tree():
			return
		Game.set_flag("seen_investigation_complete", true)
	finished.emit({})


func _travel(rid: String) -> void:
	if _done or not Inv.ROOMS.has(rid):
		return
	_busy = true
	_set_hover({})
	if rid != _room_id:
		Audio.sfx("door")
		await _fade_to(1.0, 0.2)
		_build_room(rid)
		await _fade_to(0.0, 0.25)
		if not is_inside_tree():
			return
		_show_banner()
	if await _enter_script():
		return
	_unlock()


func _unlock() -> void:
	if _done:
		return
	_busy = false
	_lock_ms = Time.get_ticks_msec() + 180
	_hover_under_mouse()


func _can_hover() -> bool:
	return not _busy and not _done and not _map_open and not _sp.is_running()


# =================================================================== room building
func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _build_world() -> void:
	_world = _layer()
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_bg)
	# soft shade under the top bar so it reads on bright backgrounds
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.16, 1.0])
	grad.colors = PackedColorArray([Color(0.03, 0.02, 0.08, 0.55), Color(0.03, 0.02, 0.08, 0.0), Color(0, 0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.texture = gt
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(shade)
	_hot_layer = Control.new()
	_hot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_hot_layer)
	_people_layer = Control.new()
	_people_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_people_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_people_layer)


func _build_room(rid: String) -> void:
	_room_id = rid
	var room: Dictionary = Inv.ROOMS[rid]
	_bg.texture = Assets.bg(str(room.get("bg", rid)))
	for c in _hot_layer.get_children():
		c.queue_free()
	for c in _people_layer.get_children():
		c.queue_free()
	_targets.clear()
	_hover = {}
	_tag.visible = false
	var hotspots: Array = room.get("hotspots", [])
	for h in hotspots:
		var ra: Array = h.get("rect", [0, 0, 10, 10])
		var rect := Rect2(float(ra[0]), float(ra[1]), float(ra[2]), float(ra[3]))
		var node := Hotspot.new()
		node.position = rect.position
		node.size = rect.size
		_hot_layer.add_child(node)
		var t := {
			"kind": "hotspot", "verb": "Examine", "label": str(h.get("label", "???")),
			"script": str(h.get("script", "")), "rect": rect, "node": node,
			"badge": Vector2(rect.end.x - 6.0, rect.position.y + 6.0),
			"seen": false, "pop": 1.0, "spark": randf_range(0.4, 2.6),
		}
		_hook(node, t)
		_targets.append(t)
	var people: Array = room.get("people", [])
	var s: float = Inv.PERSON_SCALE
	for p in people:
		var cid := str(p.get("char", ""))
		var x: float = float(Inv.SLOT_X.get(str(p.get("slot", "left")), 640.0))
		var top := H - Assets.PORTRAIT_SIZE.y * s
		var node := Person.new()
		node.tex = Assets.portrait(cid, str(p.get("expr", "normal")))
		node.mask = _hit_mask(cid, str(p.get("expr", "normal")))
		node.base_scale = s
		node.position = Vector2(x - Assets.PORTRAIT_SIZE.x * 0.5, H - Assets.PORTRAIT_SIZE.y)
		node.use_shader(_outline_shader)
		_people_layer.add_child(node)
		var t := {
			"kind": "person", "verb": "Talk", "label": Cast.display_name(cid), "char": cid,
			"script": str(p.get("script", "")),
			"rect": Rect2(x - 80.0, top + 20.0, 160.0, 150.0), "node": node,
			"badge": Vector2(x + 82.0, top + 50.0), "tag_anchor": Vector2(x, top + 12.0),
			"seen": false, "pop": 1.0, "spark": randf_range(0.4, 2.6),
		}
		_hook(node, t)
		_targets.append(t)
	_refresh_status()
	for t in _targets:
		t["pop"] = 1.0


## Small alpha mask of a portrait (rasterized on the CPU from the SVG) for pixel-accurate clicks.
func _hit_mask(cid: String, expr: String) -> Image:
	var key := cid + "_" + expr
	if _mask_cache.has(key):
		return _mask_cache[key]
	var img: Image = null
	for e in [expr, "normal"]:
		var path := "res://art/chars/%s_%s.svg" % [cid, e]
		if FileAccess.file_exists(path):
			var im := Image.new()
			if im.load_svg_from_string(FileAccess.get_file_as_string(path), 0.2) == OK and im.get_width() > 0:
				img = im
				break
	_mask_cache[key] = img
	return img


func _hook(node: Control, t: Dictionary) -> void:
	node.mouse_entered.connect(_on_target_enter.bind(t))
	node.mouse_exited.connect(_on_target_exit.bind(t))
	node.clicked.connect(_on_target_click.bind(t))


# =================================================================== hover / click
func _on_target_enter(t: Dictionary) -> void:
	if _can_hover():
		_set_hover(t)


func _on_target_exit(t: Dictionary) -> void:
	if is_same(_hover, t):
		_set_hover({})


func _on_target_click(t: Dictionary) -> void:
	if not _can_hover() or Time.get_ticks_msec() < _lock_ms:
		return
	_activate(t)


func _set_hover(t: Dictionary, quiet: bool = false) -> void:
	if is_same(_hover, t):
		return
	if not _hover.is_empty():
		var old: Control = _hover["node"]
		if is_instance_valid(old):
			old.set_hover(false)
	_hover = t
	if t.is_empty():
		_tag.visible = false
		return
	var n: Control = t["node"]
	n.set_hover(true)
	if not quiet:
		Audio.sfx("select", 1.0 + randf_range(-0.05, 0.05), -4.0)
	_show_tag(t)


func _hover_under_mouse() -> void:
	if not _can_hover():
		return
	var mp := get_global_mouse_position()
	for kind in ["person", "hotspot"]:
		for i in range(_targets.size() - 1, -1, -1):
			var t: Dictionary = _targets[i]
			if str(t["kind"]) != kind:
				continue
			var n: Control = t["node"]
			var lp: Vector2 = n.get_global_transform().affine_inverse() * mp
			if n._has_point(lp):
				_set_hover(t, true)
				return


func _show_tag(t: Dictionary) -> void:
	_tag_verb.text = str(t["verb"]) + ":"
	_tag_name.text = str(t["label"])
	_tag_check.visible = bool(t["seen"])
	var st: StyleBoxFlat = _tag.get_theme_stylebox("panel")
	st.border_color = Style.GOOD if bool(t["seen"]) else Style.AQUA
	_tag.reset_size()
	var sz := _tag.get_combined_minimum_size()
	_tag.size = sz
	var pos := Vector2.ZERO
	if str(t["kind"]) == "person":
		var a: Vector2 = t["tag_anchor"]
		pos = Vector2(a.x - sz.x * 0.5, a.y - sz.y)
	else:
		var r: Rect2 = t["rect"]
		pos = Vector2(r.get_center().x - sz.x * 0.5, r.position.y - sz.y - 10.0)
		if pos.y < BAR_H + 6.0:
			pos.y = r.end.y + 10.0
		if pos.y + sz.y > H - 6.0:
			pos.y = r.get_center().y - sz.y * 0.5
	pos.x = clampf(pos.x, 8.0, W - sz.x - 8.0)
	pos.y = clampf(pos.y, BAR_H + 4.0, H - sz.y - 4.0)
	_tag.position = pos
	_tag.pivot_offset = Vector2(sz.x * 0.5, sz.y)
	_tag.visible = true
	_tag.scale = Vector2.ONE * 0.8
	_tag.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_tag, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_tag, "modulate:a", 1.0, 0.1)


func _set_dialogue_mode(on: bool, instant: bool = false) -> void:
	_fx.show_marks = not on
	if on:
		_tag.visible = false
	var col := DIM if on else Color.WHITE
	var bcol := Color(1, 1, 1, 0.45) if on else Color.WHITE
	if _dim_tw:
		_dim_tw.kill()
		_dim_tw = null
	if instant:
		_world.modulate = col
		_btn_nb.modulate = bcol
		_btn_map.modulate = bcol
	else:
		_dim_tw = create_tween().set_parallel(true)
		_dim_tw.tween_property(_world, "modulate", col, _dur(0.22))
		_dim_tw.tween_property(_btn_nb, "modulate", bcol, _dur(0.22))
		_dim_tw.tween_property(_btn_map, "modulate", bcol, _dur(0.22))


## Pulse the Map button while the current room is done but other rooms still have things to examine.
func _process(delta: float) -> void:
	_time += delta
	if _map_pulse and _can_hover():
		var k := 0.5 + 0.5 * sin(_time * 5.0)
		_btn_map.self_modulate = Color(1, 1, 1).lerp(Color(1.5, 1.25, 0.6), k)
	elif _btn_map.self_modulate != Color.WHITE:
		_btn_map.self_modulate = Color.WHITE


# =================================================================== status
func _seen(script_id: String) -> bool:
	if script_id == "":
		return true
	var v: Variant = Game.get_flag("seen_" + script_id, false)
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_INT:
		return v != 0
	return false


func _room_progress(rid: String) -> Vector2i:
	var room: Dictionary = Inv.ROOMS.get(rid, {})
	var all: Array = []
	all.append_array(room.get("hotspots", []))
	all.append_array(room.get("people", []))
	var d := 0
	for h in all:
		if _seen(str(h.get("script", ""))):
			d += 1
	return Vector2i(d, all.size())


func _everything_examined() -> bool:
	for rid in Inv.ROOMS.keys():
		var p := _room_progress(rid)
		if p.x < p.y:
			return false
	return true


func _missing_clues() -> Array:
	var out: Array = []
	for c in Clues.REQUIRED:
		if not Game.has_clue(c):
			out.append(c)
	return out


func _refresh_status() -> void:
	for t in _targets:
		var s := _seen(str(t["script"]))
		if s and not bool(t["seen"]):
			t["pop"] = 0.0
		t["seen"] = s
	var room: Dictionary = Inv.ROOMS.get(_room_id, {})
	_room_name.text = str(room.get("name", _room_id.capitalize()))
	var p := _room_progress(_room_id)
	_room_prog.text = "%d/%d examined" % [p.x, p.y]
	_room_prog.add_theme_color_override("font_color", Style.GOOD if p.x >= p.y else Style.TEXT_DIM)
	_update_drops(false)


func _check_room_cleared() -> void:
	if _cleared.has(_room_id):
		return
	var p := _room_progress(_room_id)
	if p.y > 0 and p.x >= p.y:
		_cleared[_room_id] = true
		Audio.sfx("correct", 1.0, -4.0)
		var more := false
		for rid in Inv.ROOMS.keys():
			if not _cleared.has(rid):
				more = true
				break
		_toast("Room fully examined!" + ("  Open the Map to keep looking." if more else ""), Style.GOOD)
		_map_pulse = more


func _owned_required() -> int:
	var n := 0
	for c in Clues.REQUIRED:
		if Game.has_clue(c):
			n += 1
	return n


func _update_drops(animated: bool) -> void:
	var total := Clues.REQUIRED.size()
	var n := _owned_required()
	_drops_count.text = "%d/%d" % [n, total]
	_drops_count.add_theme_color_override("font_color", Style.GOOD if n >= total else Style.GOLD)
	if animated:
		_drops_count.pivot_offset = _drops_count.size * 0.5
		_drops_count.scale = Vector2.ONE * 1.6
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_drops_count, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_drops_icon.pivot_offset = _drops_icon.size * 0.5
		_drops_icon.scale = Vector2(0.6, 1.4)
		tw.tween_property(_drops_icon, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_fx.burst(_drops_icon.global_position + _drops_icon.size * 0.5)


func _on_clue_added(_id: String) -> void:
	if is_inside_tree():
		_update_drops(true)


# =================================================================== top bar, tag, banners
func _build_bar() -> void:
	_bar = Panel.new()
	_bar.size = Vector2(W, BAR_H)
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.035, 0.13, 0.92)
	st.border_color = Style.AQUA_DEEP
	st.border_width_bottom = 3
	st.shadow_color = Color(0, 0, 0, 0.4)
	st.shadow_size = 8
	_bar.add_theme_stylebox_override("panel", st)
	add_child(_bar)
	var tag := Style.title_label("INVESTIGATION", 12, Style.AQUA, Style.BG_DARK, 4)
	tag.position = Vector2(22, 2)
	_bar.add_child(tag)
	var hb := HBoxContainer.new()
	hb.position = Vector2(20, 14)
	hb.size = Vector2(560, 38)
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(hb)
	_room_name = Style.title_label("", 26, Style.GOLD, Style.BG_DARK, 6)
	_room_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_room_name)
	_room_prog = Style.label("", 16, Style.TEXT_DIM)
	_room_prog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_room_prog)
	_drops_icon = DropIcon.new()
	_drops_icon.position = Vector2(616, 9)
	_bar.add_child(_drops_icon)
	var dl := Style.title_label("TRUTH DROPS", 17, Style.AQUA, Style.BG_DARK, 5)
	dl.position = Vector2(648, 15)
	_bar.add_child(dl)
	_drops_count = Style.title_label("0/14", 26, Style.GOLD, Style.BG_DARK, 6)
	_drops_count.position = Vector2(782, 8)
	_drops_count.size = Vector2(86, 36)
	_bar.add_child(_drops_count)
	_btn_nb = _bar_button("Notebook  [N]", Vector2(920, 8), Vector2(178, 38))
	_btn_nb.pressed.connect(_open_notebook)
	_btn_map = _bar_button("Map  [M]", Vector2(1110, 8), Vector2(152, 38))
	_btn_map.pressed.connect(_open_map)


func _bar_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Style.button(text, sz, 18)
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_entered.connect(func() -> void:
		if _can_hover():
			Audio.sfx("select", 1.1, -6.0))
	_bar.add_child(b)
	return b


func _build_tag() -> void:
	_tag = PanelContainer.new()
	var st := Style.box(Color(0.06, 0.035, 0.13, 0.95), 10, Style.AQUA, 2)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 6
	_tag.add_theme_stylebox_override("panel", st)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.visible = false
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.add_child(hb)
	_tag_verb = Style.title_label("Examine:", 18, Style.AQUA, Style.BG_DARK, 4)
	_tag_verb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_tag_verb)
	_tag_name = Style.label("", 20, Style.TEXT)
	_tag_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_tag_name)
	var chk := CheckBadge.new()
	chk.radius = 9.0
	chk.custom_minimum_size = Vector2(22, 22)
	chk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag_check = chk
	hb.add_child(chk)
	add_child(_tag)


func _show_banner() -> void:
	for c in _banner_layer.get_children():
		if c.has_meta("room_banner"):
			c.queue_free()
	var room: Dictionary = Inv.ROOMS.get(_room_id, {})
	var root := Control.new()
	root.set_meta("room_banner", true)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2(-560, 70)
	_banner_layer.add_child(root)
	var band := Panel.new()
	band.size = Vector2(520, 72)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := Style.box(Color(0.05, 0.03, 0.11, 0.88), 0, Style.AQUA, 0)
	st.corner_radius_top_right = 36
	st.corner_radius_bottom_right = 36
	st.border_width_right = 4
	st.border_color = Style.YUZU
	band.add_theme_stylebox_override("panel", st)
	root.add_child(band)
	var l := Style.title_label(str(room.get("name", _room_id)).to_upper(), 38, Style.GOLD, Style.BG_DARK, 10)
	l.position = Vector2(30, 6)
	root.add_child(l)
	var line := ColorRect.new()
	line.color = Style.AQUA
	line.position = Vector2(32, 56)
	line.size = Vector2(160, 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(line)
	var tw := create_tween()
	tw.tween_property(root, "position:x", 0.0, _dur(0.32)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(line, "size:x", 300.0, _dur(0.5)).set_delay(_dur(0.1))
	tw.tween_interval(_dur(1.3))
	tw.tween_property(root, "position:x", -560.0, _dur(0.3)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


func _toast(text: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := Style.box(Color(0.05, 0.03, 0.11, 0.92), 22, col, 3)
	st.content_margin_left = 22
	st.content_margin_right = 22
	p.add_theme_stylebox_override("panel", st)
	var l := Style.title_label(text, 20, col, Style.BG_DARK, 5)
	p.add_child(l)
	_banner_layer.add_child(p)
	var sz := p.get_combined_minimum_size()
	p.size = sz
	p.position = Vector2((W - sz.x) * 0.5, 66)
	p.pivot_offset = sz * 0.5
	p.scale = Vector2.ONE * 0.6
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, _dur(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "modulate:a", 1.0, _dur(0.15))
	tw.tween_interval(_dur(2.2))
	tw.tween_property(p, "modulate:a", 0.0, _dur(0.4))
	tw.tween_callback(p.queue_free)


## "Every Truth Drop found" banner before the completion script.
func _celebrate() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_banner_layer.add_child(root)
	var band := ColorRect.new()
	band.color = Color(0.05, 0.03, 0.11, 0.94)
	band.position = Vector2(-W, 262)
	band.size = Vector2(W, 196)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	for yy in [0.0, 188.0]:
		var line := ColorRect.new()
		line.color = Style.AQUA
		line.position = Vector2(0, yy)
		line.size = Vector2(W, 8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(line)
	var tl := Style.title_label("EVERY TRUTH DROP FOUND!", 56, Style.GOLD, Style.BG_DARK, 12)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.position = Vector2(0, 40)
	tl.size = Vector2(W, 80)
	band.add_child(tl)
	var sub := Style.label("%d / %d Truth Drops - you're ready for the Splash Trial." % [_owned_required(), Clues.REQUIRED.size()], 24, Style.AQUA, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 118)
	sub.size = Vector2(W, 40)
	band.add_child(sub)
	Audio.sfx("whoosh")
	Audio.sfx("correct")
	_fx.burst(Vector2(_drops_icon.global_position + _drops_icon.size * 0.5))
	var tw := create_tween()
	tw.tween_property(band, "position:x", 0.0, _dur(0.3)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_interval(_dur(1.6))
	tw.tween_property(band, "position:x", W, _dur(0.25)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	await tw.finished


# =================================================================== notebook & map
func _open_notebook() -> void:
	if not _can_hover():
		return
	if Game.main and Game.main.has_method("open_notebook"):
		_set_hover({})
		Game.main.open_notebook("clues")


func _open_map() -> void:
	if _map_open or not _can_hover():
		return
	_map_open = true
	_map_pulse = false
	_set_hover({})
	Audio.sfx("confirm")
	_map = _build_map()
	add_child(_map)
	move_child(_map, _fade.get_index())
	var board: Control = _map.get_meta("board")
	_map.modulate.a = 0.0
	board.scale = Vector2.ONE * 0.94
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_map, "modulate:a", 1.0, 0.16)
	tw.tween_property(board, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_map() -> void:
	if not _map_open or _map == null:
		return
	_map_open = false
	Audio.sfx("cancel", 1.0, -4.0)
	var m := _map
	_map = null
	var tw := create_tween()
	tw.tween_property(m, "modulate:a", 0.0, 0.14)
	tw.tween_callback(m.queue_free)
	if not _busy:
		_lock_ms = Time.get_ticks_msec() + 150
		_hover_under_mouse()


func _on_map_pick(rid: String) -> void:
	if not _map_open:
		return
	Audio.sfx("confirm")
	_close_map()
	if rid != _room_id:
		_travel(rid)


func _build_map() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			root.accept_event()
			_close_map())
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.06, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var board := Panel.new()
	board.position = MAP_BOARD.position
	board.size = MAP_BOARD.size
	board.pivot_offset = MAP_BOARD.size * 0.5
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := Style.box(Color(0.07, 0.045, 0.16, 0.98), 22, Style.AQUA, 3)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 16
	board.add_theme_stylebox_override("panel", st)
	board.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			board.accept_event()
			if e.button_index == MOUSE_BUTTON_RIGHT:
				_close_map())
	root.add_child(board)
	root.set_meta("board", board)
	var title := Style.title_label("RESORT MAP", 34, Style.GOLD, Style.BG_DARK, 10)
	title.position = Vector2(28, 14)
	board.add_child(title)
	var hint := Style.label("Click a room to travel there.  [M] or right-click to close.", 17, Style.TEXT_DIM)
	hint.position = Vector2(30, 64)
	board.add_child(hint)
	var close := Style.button("Close  [M]", Vector2(150, 44), 18)
	close.position = Vector2(MAP_BOARD.size.x - 174, 18)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close_map)
	board.add_child(close)
	# card positions (unknown rooms get a spot along the bottom)
	var pos := {}
	var extra := 0
	for rid in Inv.ROOM_ORDER:
		if MAP_POS.has(rid):
			pos[rid] = MAP_POS[rid]
		else:
			pos[rid] = Vector2(140 + extra * 190, 560)
			extra += 1
	var decor := MapDecor.new()
	decor.size = MAP_BOARD.size
	decor.centers = pos
	board.add_child(decor)
	for rid in Inv.ROOM_ORDER:
		if not Inv.ROOMS.has(rid):
			continue
		var room: Dictionary = Inv.ROOMS[rid]
		var card := MapCard.new()
		card.rid = rid
		card.title = str(room.get("name", rid))
		card.thumb = Assets.svg("res://art/bg/%s.svg" % str(room.get("bg", rid)), 0.125)
		card.current = rid == _room_id
		card.visited = card.current or _seen(str(room.get("enter_script", "")))
		var p := _room_progress(rid)
		card.done = p.x
		card.total = p.y
		var c: Vector2 = pos[rid]
		card.position = c - CARD_SIZE * 0.5
		card.chosen.connect(_on_map_pick)
		board.add_child(card)
	return root


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if _map_open:
		if k.keycode == KEY_M or k.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_map()
		return
	if not _can_hover():
		return
	if k.keycode == KEY_M:
		get_viewport().set_input_as_handled()
		_open_map()
	elif k.keycode == KEY_N:
		get_viewport().set_input_as_handled()
		_open_notebook()


# =================================================================== helpers
func _dur(sec: float) -> float:
	return 0.01 if Game.autotest else sec


func _wait(sec: float) -> void:
	await get_tree().create_timer(_dur(sec), false).timeout


func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, _dur(dur))
	await tw.finished


# =================================================================== inner classes
## Invisible clickable rect; on hover a glowing outline with sliding gold corner brackets.
class Hotspot extends Control:
	signal clicked

	var hover := 0.0
	var target := 0.0
	var t := 0.0
	var flash := 0.0
	var _sb: StyleBoxFlat
	var _glow: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_sb = StyleBoxFlat.new()
		_sb.set_corner_radius_all(14)
		_sb.set_border_width_all(3)
		_sb.anti_aliasing = true
		_glow = StyleBoxFlat.new()
		_glow.draw_center = false
		_glow.set_border_width_all(4)
		_glow.anti_aliasing = true

	func set_hover(on: bool) -> void:
		target = 1.0 if on else 0.0

	func press() -> void:
		flash = 1.0

	func _has_point(p: Vector2) -> bool:
		return Rect2(Vector2.ZERO, size).has_point(p)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit()

	func _process(delta: float) -> void:
		t += delta
		var old := hover
		hover = move_toward(hover, target, delta * 7.0)
		flash = move_toward(flash, 0.0, delta * 3.0)
		if hover > 0.0 or old != hover or flash > 0.0:
			queue_redraw()

	func _draw() -> void:
		var k := maxf(hover, flash)
		if k <= 0.001:
			return
		var r := Rect2(Vector2.ZERO, size)
		var pulse := 0.7 + 0.3 * sin(t * 5.0)
		for i in 3:
			var g := 4.0 + i * 5.0
			_glow.border_color = Color(Style.AQUA, (0.26 - i * 0.07) * k * pulse)
			_glow.set_corner_radius_all(int(14.0 + g))
			draw_style_box(_glow, r.grow(g))
		_sb.bg_color = Color(Style.AQUA, 0.07 * k + 0.18 * flash)
		_sb.border_color = Color(Style.AQUA.lerp(Color.WHITE, 0.35), 0.9 * k)
		draw_style_box(_sb, r)
		var br := r.grow(4.0 + (1.0 - hover) * 16.0)
		var l := minf(26.0, minf(size.x, size.y) * 0.35)
		var corners := [[br.position, Vector2(1, 1)], [Vector2(br.end.x, br.position.y), Vector2(-1, 1)],
			[br.end, Vector2(-1, -1)], [Vector2(br.position.x, br.end.y), Vector2(1, -1)]]
		for c in corners:
			var p: Vector2 = c[0]
			var d: Vector2 = c[1]
			var pts := PackedVector2Array([p + Vector2(d.x * l, 0), p, p + Vector2(0, d.y * l)])
			draw_polyline(pts, Color(INK, 0.55 * k), 8.0, true)
			draw_polyline(pts, Color(Style.GOLD, k), 4.0, true)


## A capybara standing in the room: portrait at PERSON_SCALE, pixel-accurate hit test,
## shader outline glow on hover, gentle breathing.
class Person extends Control:
	signal clicked

	var tex: Texture2D = null
	var base_scale := 0.62
	var hover := 0.0
	var target := 0.0
	var flash := 0.0
	var t := 0.0
	var phase := 0.0
	var mask: Image = null
	var _mat: ShaderMaterial = null

	func _init() -> void:
		size = Assets.PORTRAIT_SIZE
		pivot_offset = Vector2(size.x * 0.5, size.y)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func use_shader(sh: Shader) -> void:
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		material = _mat

	func _ready() -> void:
		phase = randf() * TAU
		scale = Vector2.ONE * base_scale

	func set_hover(on: bool) -> void:
		target = 1.0 if on else 0.0

	func press() -> void:
		flash = 1.0

	func _has_point(p: Vector2) -> bool:
		if not Rect2(Vector2.ZERO, size).has_point(p):
			return false
		if mask == null or mask.is_empty():
			return true
		var ix := clampi(int(p.x / size.x * mask.get_width()), 0, mask.get_width() - 1)
		var iy := clampi(int(p.y / size.y * mask.get_height()), 0, mask.get_height() - 1)
		return mask.get_pixel(ix, iy).a > 0.2

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit()

	func _process(delta: float) -> void:
		t += delta
		hover = move_toward(hover, target, delta * 7.0)
		flash = move_toward(flash, 0.0, delta * 4.0)
		var breathe := sin(t * 2.1 + phase) * 0.006
		var grow := hover * 0.025 + flash * 0.03
		scale = Vector2(base_scale * (1.0 + grow), base_scale * (1.0 + breathe + grow))
		if _mat:
			_mat.set_shader_parameter("amount", hover)
		var b := 1.0 + 0.08 * hover + 0.2 * flash
		self_modulate = Color(b, b, b, 1.0)

	func _draw() -> void:
		if tex:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)


## Sparkles on unexamined things, check badges on examined ones, click ripples, bursts.
class Fx extends Control:
	var targets: Array = []
	var show_marks := true
	var sparks: Array = []
	var ripples: Array = []
	var bursts: Array = []
	var t := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func ripple(at: Vector2) -> void:
		ripples.append({"p": at, "age": 0.0})

	func burst(at: Vector2) -> void:
		for i in 14:
			var a := randf() * TAU
			bursts.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(60.0, 200.0), "age": 0.0,
				"r": randf_range(2.0, 4.5)})

	func _process(delta: float) -> void:
		t += delta
		if show_marks:
			for tg in targets:
				if bool(tg["seen"]):
					tg["pop"] = minf(float(tg["pop"]) + delta * 3.5, 1.0)
					continue
				tg["spark"] = float(tg["spark"]) - delta
				if float(tg["spark"]) <= 0.0:
					tg["spark"] = randf_range(2.2, 3.8)
					var r: Rect2 = tg["rect"]
					var p := r.position + Vector2(randf_range(0.2, 0.8) * r.size.x, randf_range(0.2, 0.8) * r.size.y)
					sparks.append({"p": p, "age": 0.0, "life": 0.9, "s": randf_range(11.0, 16.0)})
					sparks.append({"p": p + Vector2(randf_range(-30, 30), randf_range(-24, 24)), "age": -0.15,
						"life": 0.6, "s": randf_range(5.0, 8.0)})
		for list in [sparks, ripples]:
			for i in range(list.size() - 1, -1, -1):
				var it: Dictionary = list[i]
				it["age"] = float(it["age"]) + delta
				var life: float = it.get("life", 0.5)
				if float(it["age"]) >= life:
					list.remove_at(i)
		for i in range(bursts.size() - 1, -1, -1):
			var b: Dictionary = bursts[i]
			b["age"] = float(b["age"]) + delta
			var v: Vector2 = b["v"]
			v *= 1.0 - 3.0 * delta
			b["v"] = v
			b["p"] = (b["p"] as Vector2) + v * delta
			if float(b["age"]) > 0.6:
				bursts.remove_at(i)
		queue_redraw()

	func _draw() -> void:
		if show_marks:
			for tg in targets:
				if bool(tg["seen"]):
					var k: float = tg["pop"]
					var s := 1.0 + 0.45 * sin(PI * k) if k < 1.0 else 1.0
					_badge(tg["badge"], 11.0 * s)
			for sp in sparks:
				var age: float = sp["age"]
				if age < 0.0:
					continue
				var k := age / float(sp["life"])
				var a := sin(PI * k)
				var p: Vector2 = sp["p"]
				var sz: float = float(sp["s"]) * a
				draw_circle(p, sz * 0.75, Color(1.0, 0.9, 0.55, 0.22 * a))
				_star(p, sz, Color(1.0, 0.97, 0.82, a), age * 2.5)
		for rp in ripples:
			var k: float = float(rp["age"]) / 0.5
			var p: Vector2 = rp["p"]
			draw_arc(p, 8.0 + k * 46.0, 0.0, TAU, 40, Color(Style.AQUA, 1.0 - k), 4.0 * (1.0 - k) + 1.0, true)
			draw_arc(p, 4.0 + k * 26.0, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - k)), 2.0, true)
		for b in bursts:
			var k: float = 1.0 - float(b["age"]) / 0.6
			draw_circle(b["p"], float(b["r"]) * (0.5 + 0.5 * k), Color(Style.GOLD, k))

	func _star(c: Vector2, r: float, col: Color, rot: float) -> void:
		if r < 0.5:
			return
		var pts := PackedVector2Array()
		for i in 8:
			var a := rot + i * TAU / 8.0
			var rr := r if i % 2 == 0 else r * 0.26
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)

	func _badge(c: Vector2, r: float) -> void:
		draw_circle(c + Vector2(0, 2), r + 1.5, Color(0, 0, 0, 0.35))
		draw_circle(c, r + 2.0, INK)
		draw_circle(c, r, Style.GOOD)
		var pts := PackedVector2Array([c + Vector2(-r * 0.45, 0.0), c + Vector2(-r * 0.1, r * 0.38),
			c + Vector2(r * 0.5, -r * 0.36)])
		draw_polyline(pts, Color.WHITE, maxf(2.0, r * 0.26), true)


## Green check badge as a Control (used in the hover tag).
class CheckBadge extends Control:
	var radius := 9.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, radius + 1.5, INK)
		draw_circle(c, radius, Style.GOOD)
		var pts := PackedVector2Array([c + Vector2(-radius * 0.45, 0.0), c + Vector2(-radius * 0.1, radius * 0.38),
			c + Vector2(radius * 0.5, -radius * 0.36)])
		draw_polyline(pts, Color.WHITE, 2.2, true)


## Water-drop icon for the Truth Drop counter.
class DropIcon extends Control:
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(26, 36)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(13, 22)
		var r := 10.0
		var pts := PackedVector2Array([Vector2(13, 2)])
		for i in 25:
			var a := deg_to_rad(-40.0 + 260.0 * i / 24.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var outline := PackedVector2Array()
		for p in pts:
			outline.append(c + (p - c) * 1.2)
		draw_colored_polygon(outline, INK)
		draw_colored_polygon(pts, Style.AQUA)
		draw_circle(c + Vector2(2, 3), r * 0.55, Color(Style.AQUA_DEEP, 0.6))
		draw_circle(c + Vector2(-4, -3), 2.6, Color(1, 1, 1, 0.75 + 0.25 * sin(t * 3.0)))


## Map background: building regions, paths, garden stepping stones, the lobby hub, decorations.
class MapDecor extends Control:
	var centers := {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _pt(id: String) -> Vector2:
		if id == "hub":
			return MAP_HUB
		return centers.get(id, MAP_HUB)

	func _draw() -> void:
		var f := Style.display_font()
		_region(Rect2(28, 108, 494, 482), Color(0.42, 0.3, 0.62, 0.2), Color(Style.VIOLET, 0.55), "MAIN BUILDING")
		_region(Rect2(530, 240, 190, 350), Color(0.3, 0.62, 0.32, 0.2), Color(0.45, 0.8, 0.45, 0.55), "GARDEN")
		_region(Rect2(736, 108, 380, 482), Color(Style.AQUA_DEEP, 0.22), Color(Style.AQUA, 0.5), "BATHHOUSE")
		# decorations: trees in the garden, a little steaming pool in the bathhouse
		for tr in [[Vector2(566, 470), 20.0], [Vector2(684, 500), 16.0], [Vector2(600, 538), 13.0], [Vector2(690, 440), 11.0]]:
			var p: Vector2 = tr[0]
			var r: float = tr[1]
			draw_circle(p + Vector2(0, 4), r + 2.0, Color(0, 0, 0, 0.25))
			draw_circle(p, r + 2.0, INK)
			draw_circle(p, r, Color("5aa845"))
			draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.45, Color("7cc95e"))
		var pool := Vector2(1010, 515)
		draw_set_transform(pool, 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, 74.0, INK)
		draw_circle(Vector2.ZERO, 70.0, Color("2fb8b0"))
		draw_circle(Vector2(-10, -8), 50.0, Color("4fd6c9"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for yp in [Vector2(-30, -4), Vector2(12, 6), Vector2(36, -8), Vector2(-8, 10)]:
			draw_circle(pool + yp, 5.5, INK)
			draw_circle(pool + yp, 4.0, Color("ffc23a"))
		for i in 3:
			var x0 := pool.x - 34.0 + i * 34.0
			var pts := PackedVector2Array()
			for j in 9:
				pts.append(Vector2(x0 + sin(j * 0.9 + i) * 5.0, pool.y - 30.0 - j * 5.0))
			draw_polyline(pts, Color(1, 1, 1, 0.35), 3.0, true)
		# paths
		for link in MAP_LINKS:
			var a := _pt(link[0])
			var b := _pt(link[1])
			draw_line(a, b, Color(INK, 0.6), 9.0, true)
			draw_dashed_line(a, b, Color(Style.TEXT_DIM, 0.85), 4.0, 10.0, true, true)
		for link in STONE_LINKS:
			var a := _pt(link[0])
			var b := _pt(link[1])
			for i in 9:
				var p := a.lerp(b, (i + 0.5) / 9.0) + Vector2(0, 7.0 if i % 2 == 0 else -7.0)
				draw_circle(p, 7.5, INK)
				draw_circle(p, 5.5, Color("c9c3b8"))
		# lobby hub
		draw_circle(MAP_HUB, 24.0, INK)
		draw_circle(MAP_HUB, 20.0, Style.PANEL_LIGHT)
		draw_arc(MAP_HUB, 20.0, 0.0, TAU, 40, Style.AQUA_DEEP, 3.0, true)
		draw_circle(MAP_HUB, 7.0, Style.YUZU)
		draw_string_outline(f, MAP_HUB + Vector2(-60, 46), "LOBBY", HORIZONTAL_ALIGNMENT_CENTER, 120, 15, 6, Style.BG_DARK)
		draw_string(f, MAP_HUB + Vector2(-60, 46), "LOBBY", HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Style.TEXT_DIM)

	func _region(r: Rect2, fill: Color, border: Color, label: String) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = border
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(18)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var f := Style.display_font()
		draw_string_outline(f, Vector2(r.position.x + 16, r.end.y - 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, Style.BG_DARK)
		draw_string(f, Vector2(r.position.x + 16, r.end.y - 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(border, 1.0))


## A room card on the map: thumbnail, name, progress, current marker, NEW tag, check when complete.
class MapCard extends Control:
	signal chosen(rid: String)

	var rid := ""
	var title := ""
	var thumb: Texture2D = null
	var current := false
	var visited := false
	var done := 0
	var total := 0
	var hovering := false
	var hover := 0.0
	var t := 0.0
	var _sb: StyleBoxFlat

	func _init() -> void:
		size = CARD_SIZE
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_sb = StyleBoxFlat.new()
		_sb.set_corner_radius_all(12)
		_sb.anti_aliasing = true
		_sb.shadow_color = Color(0, 0, 0, 0.45)
		_sb.shadow_size = 8
		_sb.shadow_offset = Vector2(0, 4)

	func _ready() -> void:
		mouse_entered.connect(func() -> void:
			hovering = true
			z_index = 1
			Audio.sfx("select", 1.0 + randf_range(-0.05, 0.05), -4.0))
		mouse_exited.connect(func() -> void:
			hovering = false
			z_index = 0)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			accept_event()
			if e.button_index == MOUSE_BUTTON_LEFT:
				chosen.emit(rid)

	func _process(delta: float) -> void:
		t += delta
		hover = move_toward(hover, 1.0 if hovering else 0.0, delta * 8.0)
		scale = Vector2.ONE * (1.0 + 0.07 * hover)
		queue_redraw()

	func _draw() -> void:
		var f := Style.display_font()
		var r := Rect2(Vector2.ZERO, size)
		var complete := total > 0 and done >= total
		if current:
			var pulse := 0.5 + 0.5 * sin(t * 4.0)
			for i in 3:
				var g := 3.0 + i * 4.0
				var gs := StyleBoxFlat.new()
				gs.draw_center = false
				gs.set_border_width_all(4)
				gs.set_corner_radius_all(int(12 + g))
				gs.border_color = Color(Style.YUZU, (0.35 - i * 0.1) * (0.6 + 0.4 * pulse))
				draw_style_box(gs, r.grow(g))
		_sb.bg_color = Style.PANEL_LIGHT.lerp(Color(0.24, 0.18, 0.44), hover)
		var border := Style.AQUA_DEEP.lerp(Style.AQUA, hover)
		if current:
			border = Style.YUZU
		_sb.border_color = border
		_sb.set_border_width_all(4 if current else 2 + int(hover * 1.5))
		draw_style_box(_sb, r)
		var tr := Rect2(8, 8, size.x - 16, 86)
		draw_rect(tr, Color(0.05, 0.03, 0.1))
		if thumb:
			var mod := Color.WHITE if visited else Color(0.5, 0.48, 0.62)
			draw_texture_rect(thumb, tr, false, mod)
		draw_rect(tr, Color(INK, 0.8), false, 2.0)
		var name_col := Style.GOLD if current or hover > 0.5 else Style.TEXT
		draw_string_outline(f, Vector2(0, 114), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, 5, Style.BG_DARK)
		draw_string(f, Vector2(0, 114), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, name_col)
		# progress pill (bottom-right of the thumbnail)
		if total > 0:
			var txt := "%d/%d" % [done, total]
			var pw := 46.0
			var pr := Rect2(tr.end.x - pw - 4, tr.end.y - 24, pw, 20)
			var ps := StyleBoxFlat.new()
			ps.set_corner_radius_all(10)
			ps.bg_color = Color(0.04, 0.02, 0.08, 0.88)
			ps.border_color = Style.GOOD if complete else Style.AQUA_DEEP
			ps.set_border_width_all(2)
			draw_style_box(ps, pr)
			draw_string(f, Vector2(pr.position.x, pr.position.y + 15), txt, HORIZONTAL_ALIGNMENT_CENTER, pw, 13,
				Style.GOOD if complete else Style.TEXT)
		if current:
			var hs := StyleBoxFlat.new()
			hs.set_corner_radius_all(8)
			hs.bg_color = Style.YUZU
			hs.border_color = INK
			hs.set_border_width_all(2)
			var hr := Rect2(tr.position.x + 4, tr.position.y + 4, 104, 20)
			draw_style_box(hs, hr)
			draw_string(f, Vector2(hr.position.x, hr.position.y + 15), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_CENTER, hr.size.x, 12, Style.BG_DARK)
			# bobbing pin above the top-left corner
			var pin := Vector2(18, -10 + sin(t * 4.0) * 3.0)
			draw_circle(pin, 10.0, INK)
			draw_circle(pin, 7.5, Style.YUZU)
			draw_colored_polygon(PackedVector2Array([pin + Vector2(-6, 6), pin + Vector2(6, 6), pin + Vector2(0, 17)]), INK)
			draw_colored_polygon(PackedVector2Array([pin + Vector2(-3.8, 6), pin + Vector2(3.8, 6), pin + Vector2(0, 13)]), Style.YUZU)
			draw_circle(pin, 3.0, Style.BG_DARK)
		elif not visited:
			var ns := StyleBoxFlat.new()
			ns.set_corner_radius_all(8)
			ns.bg_color = Style.AQUA
			ns.border_color = INK
			ns.set_border_width_all(2)
			var nr := Rect2(tr.position.x + 4, tr.position.y + 4, 46, 20)
			draw_style_box(ns, nr)
			draw_string(f, Vector2(nr.position.x, nr.position.y + 15), "NEW", HORIZONTAL_ALIGNMENT_CENTER, nr.size.x, 12, Style.BG_DARK)
		if complete:
			var c := Vector2(size.x - 6, 6)
			draw_circle(c + Vector2(0, 2), 16.0, Color(0, 0, 0, 0.35))
			draw_circle(c, 16.0, INK)
			draw_circle(c, 13.0, Style.GOOD)
			var pts := PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-1.5, 5), c + Vector2(6.5, -5)])
			draw_polyline(pts, Color.WHITE, 3.4, true)
