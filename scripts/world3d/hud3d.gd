extends Control
## 2D overlay for the 3D rooms: crosshair (lights up over things you can use) and a controls strip.
## Also makes the floating 3D markers (sparkle = not examined yet, check = examined).

const Style := preload("res://scripts/ui/style.gd")
const Kit := preload("res://scripts/world3d/kit.gd")

var crosshair: Crosshair
var hint: PanelContainer
var _hidden := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair = Crosshair.new()
	crosshair.position = Vector2(640 - 40, 360 - 40)
	crosshair.size = Vector2(80, 80)
	add_child(crosshair)


## keys: [["WASD", "Move"], ["Mouse", "Look"], ...]
func set_hints(keys: Array) -> void:
	if hint:
		hint.queue_free()
	hint = PanelContainer.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := Style.box(Color(0.05, 0.03, 0.11, 0.72), 12, Color(Style.AQUA_DEEP, 0.8), 2)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	hint.add_theme_stylebox_override("panel", st)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(hb)
	for pair in keys:
		var p: Array = pair
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cs := Style.box(Color(0.14, 0.1, 0.26, 0.95), 6, Style.AQUA, 1)
		cs.content_margin_left = 6
		cs.content_margin_right = 6
		cs.content_margin_top = 1
		cs.content_margin_bottom = 1
		cap.add_theme_stylebox_override("panel", cs)
		var kl := Style.label(str(p[0]), 14, Style.GOLD, true)
		cap.add_child(kl)
		cell.add_child(cap)
		var al := Style.label(str(p[1]), 14, Style.TEXT_DIM)
		cell.add_child(al)
		hb.add_child(cell)
	add_child(hint)
	hint.reset_size()
	var sz := hint.get_combined_minimum_size()
	hint.position = Vector2(16, 720 - sz.y - 14)


func set_focus(on: bool) -> void:
	crosshair.focused = on


## Hide everything while a story snippet / menu is up.
func set_hidden(on: bool) -> void:
	_hidden = on
	var tw := create_tween().set_parallel(true)
	tw.tween_property(crosshair, "modulate:a", 0.0 if on else 1.0, 0.15)
	if hint:
		tw.tween_property(hint, "modulate:a", 0.0 if on else 1.0, 0.15)


class Crosshair extends Control:
	var focused := false
	var _k := 0.0
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		var target := 1.0 if focused else 0.0
		var old := _k
		_k = move_toward(_k, target, delta * 7.0)
		if _k > 0.0 or old != _k:
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var k := _k
		draw_circle(c, 4.0, Color(Style.INK, 0.6 * (1.0 - k)))
		draw_circle(c, 2.4, Color(1, 1, 1, 0.95 * (1.0 - k)))
		draw_arc(c, 10.0, 0.0, TAU, 32, Color(Style.AQUA, 0.35 * (1.0 - k)), 1.5, true)
		if k <= 0.001:
			return
		var r := lerpf(26.0, 16.0, k)
		draw_arc(c, r, 0.0, TAU, 40, Color(Style.INK, 0.5 * k), 6.0, true)
		draw_arc(c, r, 0.0, TAU, 40, Color(Style.GOLD, k), 3.0, true)
		draw_circle(c, 3.5, Color(Style.GOLD, k))
		var rot := _t * 1.6
		for i in 4:
			var a := rot + i * TAU / 4.0
			var p := c + Vector2(cos(a), sin(a)) * (r + 9.0)
			var d := Vector2(cos(a), sin(a))
			var tn := Vector2(-d.y, d.x)
			var pts := PackedVector2Array([p + tn * 6.0 - d * 4.0, p + d * 3.0, p - tn * 6.0 - d * 4.0])
			draw_colored_polygon(pts, Color(Style.AQUA, k))


# =================================================================== markers
const STAR_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<circle cx="32" cy="32" r="18" fill="#ffd166" opacity="0.25"/>
<path d="M32 4 L37 27 L60 32 L37 37 L32 60 L27 37 L4 32 L27 27 Z" fill="#2a1a10" opacity="0.55" transform="translate(1.5 2)"/>
<path d="M32 4 L37 27 L60 32 L37 37 L32 60 L27 37 L4 32 L27 27 Z" fill="#ffd166" stroke="#fff6dc" stroke-width="2" stroke-linejoin="round"/>
<circle cx="32" cy="32" r="5" fill="#fffbe8"/>
</svg>"""

const CHECK_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<circle cx="33" cy="34" r="25" fill="#000000" opacity="0.35"/>
<circle cx="32" cy="32" r="26" fill="#07040f"/>
<circle cx="32" cy="32" r="22" fill="#6ee36e"/>
<path d="M20 33 L29 42 L45 23" fill="none" stroke="#ffffff" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
</svg>"""

const DOOR_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<circle cx="32" cy="32" r="26" fill="#07040f" opacity="0.85"/>
<circle cx="32" cy="32" r="22" fill="#1a8f9e"/>
<path d="M22 32 L40 32 M33 23 L42 32 L33 41" fill="none" stroke="#ffffff" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>"""


static func star_tex() -> Texture2D:
	return Kit.svg_tex("marker_star", STAR_SVG, 1.0)


static func check_tex() -> Texture2D:
	return Kit.svg_tex("marker_check", CHECK_SVG, 1.0)


static func door_tex() -> Texture2D:
	return Kit.svg_tex("marker_door", DOOR_SVG, 1.0)


static func make_marker(parent: Node3D, pos: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = star_tex()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.fixed_size = true
	s.pixel_size = 0.00045
	s.position = pos
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.render_priority = 2
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(s)
	return s
