extends RefCounted
## Shared look & feel.  const Style := preload("res://scripts/ui/style.gd")
## Palette: hot-spring night purple + hot-spring aqua + yuzu orange. Use these instead of ad-hoc colors.
##
## House style: ANGULAR & SHARP - slanted panels, cut (chamfered) corners, hard offset shadows in INK,
## thick outlines, diagonal accent stripes. Helpers:
##   Style.box(bg, radius, border, border_w)            rounded StyleBoxFlat (unchanged, generic)
##   Style.cut_box(bg, cut, border, border_w, shadow)   StyleBoxFlat with chamfered TL/BR corners (+ hard shadow)
##   Style.slant_box(bg, border, border_w, skew, shadow) skewed StyleBoxFlat (buttons/tabs) with hard shadow
##   Style.italic_font()                                 slanted body font (thoughts, [i])
## Polygon helpers (for _draw code):
##   Style.slant_poly(rect, slant)                -> parallelogram (top edge shifted right by slant)
##   Style.chamfer(points, cuts)                  -> polygon with corners cut (cuts[i] = cut length at vertex i)
##   Style.cut_rect(rect, cut)                    -> rect with TL + BR corners cut
##   Style.draw_shape(ci, pts, fill, outline, outline_w, shadow, shadow_off)  call from _draw()
##   Style.draw_stripes(ci, rect, count, color, slant, gap)                    diagonal slash accents
##   Style.Shape.new()   a mouse-transparent Control that draws one such shape (set .points/.fill/...)

const BG_DARK := Color("120a24")
const INK := Color("07040f")          # near-black: hard shadows, heavy outlines
const PANEL := Color(0.09, 0.06, 0.18, 0.92)
const PANEL_LIGHT := Color(0.16, 0.11, 0.30, 0.95)
const AQUA := Color("3ee0d0")
const AQUA_DEEP := Color("1a8f9e")
const YUZU := Color("ffb347")
const GOLD := Color("ffd166")
const DANGER := Color("ff4f6d")
const GOOD := Color("6ee36e")
const VIOLET := Color("9b6bd6")
const TEXT := Color("f4f1ff")
const TEXT_DIM := Color("a89cc8")
const HIGHLIGHT_BB := "#ffb347"   # BBCode color for *key words*

static var _display_font: Font = null
static var _body_font: Font = null
static var _italic_font: Font = null


## Heavy display font for titles, cards, shouts (system font with fallbacks).
static func display_font() -> Font:
	if _display_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Segoe UI Black", "Arial Black", "Impact", "Helvetica Neue", "Arial"])
		f.font_weight = 900
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_display_font = f
	return _display_font


## Body font for dialogue and UI.
static func body_font() -> Font:
	if _body_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Verdana", "Arial", "Noto Sans"])
		f.font_weight = 600
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_body_font = f
	return _body_font


## Slanted (faux-italic) body font - same metrics as body_font(), works with every system font.
static func italic_font() -> Font:
	if _italic_font == null:
		var fv := FontVariation.new()
		fv.base_font = body_font()
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.21, 1), Vector2.ZERO)
		_italic_font = fv
	return _italic_font


static func box(bg: Color = PANEL, radius: int = 14, border: Color = AQUA, border_w: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.anti_aliasing = true
	return s


## Angular panel: top-left and bottom-right corners cut at 45 degrees, optional hard offset shadow.
static func cut_box(bg: Color = PANEL, cut: int = 16, border: Color = AQUA, border_w: int = 2,
		shadow: Color = Color(0, 0, 0, 0), shadow_off: Vector2 = Vector2(7, 7)) -> StyleBoxFlat:
	var s := box(bg, 0, border, border_w)
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_radius_top_right = maxi(2, cut / 6)
	s.corner_radius_bottom_left = maxi(2, cut / 6)
	s.corner_detail = 1
	if shadow.a > 0.0:
		s.shadow_color = shadow
		s.shadow_size = 1
		s.shadow_offset = shadow_off
	return s


## Skewed (slanted) box for buttons and tabs, with a hard offset shadow.
static func slant_box(bg: Color = PANEL_LIGHT, border: Color = AQUA_DEEP, border_w: int = 2, skew_x: float = 0.2,
		shadow: Color = Color(INK, 0.85), shadow_off: Vector2 = Vector2(5, 5)) -> StyleBoxFlat:
	var s := box(bg, 0, border, border_w)
	s.corner_detail = 1
	s.skew = Vector2(skew_x, 0)
	s.content_margin_left = 22
	s.content_margin_right = 22
	if shadow.a > 0.0:
		s.shadow_color = shadow
		s.shadow_size = 1
		s.shadow_offset = shadow_off
	return s


## Global theme applied at the root (Main). Buttons, labels, panels, sliders, scrollbars.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("italics_font", "RichTextLabel", italic_font())
	t.set_stylebox("panel", "Panel", cut_box(PANEL, 14, AQUA, 2))
	t.set_stylebox("panel", "PanelContainer", cut_box(PANEL, 14, AQUA, 2))
	# Buttons: slanted plates with a hard ink shadow; hover lights up aqua, press flashes yuzu.
	t.set_stylebox("normal", "Button", slant_box(PANEL_LIGHT, AQUA_DEEP, 2))
	t.set_stylebox("hover", "Button", slant_box(Color(0.22, 0.15, 0.44, 0.98), AQUA, 3, 0.2, Color(AQUA_DEEP, 0.9), Vector2(6, 6)))
	t.set_stylebox("pressed", "Button", slant_box(Color(0.10, 0.45, 0.50, 0.98), YUZU, 3, 0.2, Color(INK, 0.9), Vector2(2, 2)))
	t.set_stylebox("hover_pressed", "Button", slant_box(Color(0.10, 0.45, 0.50, 0.98), YUZU, 3, 0.2, Color(INK, 0.9), Vector2(2, 2)))
	t.set_stylebox("focus", "Button", slant_box(Color(0, 0, 0, 0), YUZU, 2, 0.2, Color(0, 0, 0, 0)))
	t.set_stylebox("disabled", "Button", slant_box(Color(0.12, 0.10, 0.18, 0.8), Color(0.3, 0.3, 0.35), 2, 0.2, Color(INK, 0.5)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 4)
	t.set_font("font", "Button", body_font())
	t.set_font_size("font_size", "Button", 22)
	# Check buttons (settings) stay unslanted but get the same colors.
	var cb_empty := StyleBoxEmpty.new()
	t.set_stylebox("normal", "CheckButton", cb_empty)
	t.set_stylebox("hover", "CheckButton", cb_empty)
	t.set_stylebox("pressed", "CheckButton", cb_empty)
	t.set_stylebox("hover_pressed", "CheckButton", cb_empty)
	t.set_stylebox("focus", "CheckButton", cb_empty)
	# Sliders
	var grab := box(AQUA, 8, Color.WHITE, 1)
	grab.corner_detail = 1
	t.set_stylebox("slider", "HSlider", slant_box(Color(0.2, 0.15, 0.35), Color(0, 0, 0, 0), 0, 0.6, Color(INK, 0.8), Vector2(3, 3)))
	t.set_stylebox("grabber_area", "HSlider", slant_box(AQUA_DEEP, Color(0, 0, 0, 0), 0, 0.6, Color(0, 0, 0, 0)))
	t.set_stylebox("grabber_area_highlight", "HSlider", slant_box(AQUA, Color(0, 0, 0, 0), 0, 0.6, Color(0, 0, 0, 0)))
	t.set_constant("grabber_offset", "HSlider", 0)
	# Scrollbars: thin aqua blade on a dark track.
	var track := box(Color(0.05, 0.03, 0.1, 0.8), 0, Color(0, 0, 0, 0), 0)
	track.content_margin_left = 4
	track.content_margin_right = 4
	var blade := box(AQUA_DEEP, 0, Color(0, 0, 0, 0), 0)
	blade.corner_radius_top_left = 6
	blade.corner_radius_bottom_right = 6
	blade.corner_detail = 1
	var blade_hi := blade.duplicate() as StyleBoxFlat
	blade_hi.bg_color = AQUA
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", blade)
	t.set_stylebox("grabber_highlight", "VScrollBar", blade_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", blade_hi)
	return t


static func label(text: String, size: int = 22, color: Color = TEXT, display: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if display:
		l.add_theme_font_override("font", display_font())
	return l


## Big outlined label for titles/shouts.
static func title_label(text: String, size: int = 64, color: Color = GOLD, outline: Color = BG_DARK, outline_size: int = 12) -> Label:
	var l := label(text, size, color, true)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_size)
	return l


static func button(text: String, min_size: Vector2 = Vector2(260, 56), font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_ALL
	return b


## Converts the DSL's *highlight* markup to BBCode.
static func markup(text: String) -> String:
	var out := ""
	var on := false
	for i in text.length():
		var ch := text[i]
		if ch == "*":
			out += "[/color]" if on else "[color=%s]" % HIGHLIGHT_BB
			on = not on
		else:
			out += ch
	if on:
		out += "[/color]"
	return out


# =================================================================== polygon helpers
static func slant_poly(rect: Rect2, slant: float) -> PackedVector2Array:
	return Geo.slant_poly(rect, slant)


static func chamfer(pts: PackedVector2Array, cuts: Array) -> PackedVector2Array:
	return Geo.chamfer(pts, cuts)


static func cut_rect(rect: Rect2, cut: float) -> PackedVector2Array:
	return Geo.chamfer(Geo.rect_poly(rect), [cut, 0.0, cut, 0.0])


static func draw_shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline: Color = Color(0, 0, 0, 0),
		outline_w: float = 0.0, shadow: Color = Color(0, 0, 0, 0), shadow_off: Vector2 = Vector2(7, 7)) -> void:
	Geo.draw_shape(ci, pts, fill, outline, outline_w, shadow, shadow_off)


static func draw_stripes(ci: CanvasItem, rect: Rect2, count: int, color: Color, slant: float = 14.0, gap: float = 10.0) -> void:
	Geo.draw_stripes(ci, rect, count, color, slant, gap)


## Geometry / drawing implementation (inner class so the inner Controls below can use it too).
class Geo:
	static func rect_poly(r: Rect2) -> PackedVector2Array:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

	## Parallelogram inside rect: TL shifted right by slant, BR shifted left by slant ("/" lean).
	static func slant_poly(r: Rect2, s: float) -> PackedVector2Array:
		if s >= 0.0:
			return PackedVector2Array([r.position + Vector2(s, 0), Vector2(r.end.x, r.position.y),
				r.end - Vector2(s, 0), Vector2(r.position.x, r.end.y)])
		return PackedVector2Array([r.position, Vector2(r.end.x + s, r.position.y), r.end, Vector2(r.position.x - s, r.end.y)])

	static func chamfer(pts: PackedVector2Array, cuts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		var n := pts.size()
		for i in n:
			var c: float = float(cuts[i]) if i < cuts.size() else 0.0
			var p := pts[i]
			if c <= 0.0:
				out.append(p)
				continue
			var a := pts[(i - 1 + n) % n]
			var b := pts[(i + 1) % n]
			out.append(p + (a - p).normalized() * minf(c, p.distance_to(a) * 0.45))
			out.append(p + (b - p).normalized() * minf(c, p.distance_to(b) * 0.45))
		return out

	static func offset(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		out.resize(pts.size())
		for i in pts.size():
			out[i] = pts[i] + off
		return out

	## Filled polygon with hard shadow and an inward outline (outline = polygon, fill = inset polygon).
	static func draw_shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline: Color, outline_w: float,
			shadow: Color, shadow_off: Vector2) -> void:
		if pts.size() < 3:
			return
		if shadow.a > 0.0:
			ci.draw_colored_polygon(offset(pts, shadow_off), shadow)
		if outline_w > 0.0 and outline.a > 0.0:
			ci.draw_colored_polygon(pts, outline)
			var inner: Array = Geometry2D.offset_polygon(pts, -outline_w, Geometry2D.JOIN_MITER)
			if inner.size() > 0 and fill.a > 0.0:
				var ip: PackedVector2Array = inner[0]
				if ip.size() >= 3:
					ci.draw_colored_polygon(ip, fill)
		elif fill.a > 0.0:
			ci.draw_colored_polygon(pts, fill)

	## `count` diagonal slashes, left to right inside rect, fading out.
	static func draw_stripes(ci: CanvasItem, r: Rect2, count: int, color: Color, s: float, gap: float) -> void:
		if count <= 0:
			return
		var w := maxf(2.0, (r.size.x - gap * (count - 1) - s) / count)
		for i in count:
			var x := r.position.x + i * (w + gap)
			var c := Color(color, color.a * (1.0 - 0.22 * i))
			ci.draw_colored_polygon(slant_poly(Rect2(x, r.position.y, w + s, r.size.y), s), c)

	## Water droplet (point up) centred on c with radius rad.
	static func droplet(c: Vector2, rad: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		pts.append(c + Vector2(0, -rad * 2.1))
		for i in 13:
			var a := deg_to_rad(-30.0 + i * 20.0)   # -30..210 deg around the bottom
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		return pts


## A mouse-transparent Control that draws one angular shape. Set points (local coords) and colors.
class Shape extends Control:
	var points := PackedVector2Array()
	var fill := Color(0.07, 0.04, 0.15, 0.95)
	var outline := Color(0, 0, 0, 0)
	var outline_w := 0.0
	var shadow := Color(0, 0, 0, 0)
	var shadow_off := Vector2(7, 7)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Geo.draw_shape(self, points, fill, outline, outline_w, shadow, shadow_off)
