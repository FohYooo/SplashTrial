extends RefCounted
## Runtime asset loading - no editor import step needed.
##   const Assets := preload("res://scripts/core/assets.gd")
##   var tex := Assets.portrait("coco", "happy")   # Texture2D, logical size = SVG size
##   var bg  := Assets.bg("lobby")                 # 1280x720 logical
##
## SVGs are rasterized at RES_SCALE (1.5x) so they stay crisp in 1080p fullscreen, but the
## returned texture reports its *logical* size (the SVG's width/height), so you can use it
## like any normal texture (Sprite2D scale 1 == SVG size in game pixels).

const Cast := preload("res://scripts/data/cast.gd")

const RES_SCALE := 1.5
const MAX_CACHE := 64

const PORTRAIT_SIZE := Vector2(480, 600)
const BG_SIZE := Vector2(1280, 720)

static var _cache := {}
static var _order: Array = []


## Load any SVG under res:// as a texture. extra_scale multiplies the raster resolution
## AND the logical size (use it to get e.g. a 2x-big texture of a small prop).
## Returns null if the file does not exist or fails to parse.
static func svg(path: String, extra_scale: float = 1.0) -> Texture2D:
	var key := "%s@%s" % [path, extra_scale]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var src := FileAccess.get_file_as_string(path)
		var img := Image.new()
		var err := img.load_svg_from_string(src, RES_SCALE * extra_scale)
		if err == OK and img.get_width() > 0:
			img.generate_mipmaps()
			var t := ImageTexture.create_from_image(img)
			t.set_size_override(Vector2i(
				roundi(img.get_width() / RES_SCALE), roundi(img.get_height() / RES_SCALE)))
			tex = t
		else:
			push_warning("Assets: failed to rasterize %s (err %d)" % [path, err])
	_store(key, tex)
	return tex


static func _store(key: String, tex: Texture2D) -> void:
	_cache[key] = tex
	_order.append(key)
	while _order.size() > MAX_CACHE:
		var old: String = _order.pop_front()
		_cache.erase(old)


## Character portrait (bust-up, 480x600 logical). Falls back to the "normal"
## expression, then to a colored placeholder so the game never crashes on missing art.
static func portrait(char_id: String, expr: String = "normal") -> Texture2D:
	var t := svg("res://art/chars/%s_%s.svg" % [char_id, expr])
	if t == null and expr != "normal":
		t = svg("res://art/chars/%s_normal.svg" % char_id)
	if t == null:
		t = placeholder(PORTRAIT_SIZE, Cast.color(char_id) if Cast.exists(char_id) else Color.GRAY, "portrait:" + char_id)
	return t


## Full-body character art for the 3D standees (640x920 logical, feet on a shared baseline).
## Falls back to the "normal" expression; null if the character has no full-body art.
static func portrait_full(char_id: String, expr: String = "normal") -> Texture2D:
	var t := svg("res://art/chars_full/%s_%s.svg" % [char_id, expr])
	if t == null and expr != "normal":
		t = svg("res://art/chars_full/%s_normal.svg" % char_id)
	return t


## Background (1280x720 logical). Placeholder if missing.
static func bg(bg_id: String) -> Texture2D:
	var t := svg("res://art/bg/%s.svg" % bg_id)
	if t == null:
		t = placeholder(BG_SIZE, Color(0.12, 0.09, 0.2), "bg:" + bg_id)
	return t


## Prop / icon art from res://art/props/<name>.svg. Returns null if missing.
static func prop(prop_name: String, extra_scale: float = 1.0) -> Texture2D:
	return svg("res://art/props/%s.svg" % prop_name, extra_scale)


## Truth Drop icon (res://art/props/clue_<id>.svg) or null.
static func clue_icon(clue_id: String) -> Texture2D:
	return prop("clue_" + clue_id)


static func placeholder(size: Vector2, color: Color, key: String) -> Texture2D:
	var ck := "placeholder:" + key
	if _cache.has(ck):
		return _cache[ck]
	var img := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	img.fill(Color(color, 0.85))
	# simple darker frame so placeholders are recognisable
	var dark := color.darkened(0.5)
	for x in range(int(size.x)):
		for y in [0, 1, 2, int(size.y) - 3, int(size.y) - 2, int(size.y) - 1]:
			img.set_pixel(x, y, dark)
	var t := ImageTexture.create_from_image(img)
	_store(ck, t)
	return t


static func clear_cache() -> void:
	_cache.clear()
	_order.clear()
