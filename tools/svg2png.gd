extends SceneTree
## Rasterize SVGs exactly like the game does (Godot's ThorVG), for previewing art.
## Usage (from the project folder):
##   Godot --headless --path . -s tools/svg2png.gd -- in.svg out.png [scale]
##   Godot --headless --path . -s tools/svg2png.gd -- --sheet out.png [--cols N] [--cell W] a.svg b.svg ...
## Paths may be absolute or res:// . A contact sheet scales every image to fit a cell (default 320px)
## on a checkerboard so transparency is visible.

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		printerr("usage: -- in.svg out.png [scale] | -- --sheet out.png [--cols N] [--cell W] files...")
		quit(1)
		return
	if a[0] == "--sheet":
		_sheet(a.slice(1))
	else:
		var sc := float(a[2]) if a.size() > 2 else 1.0
		var img := _load(a[0], sc)
		if img == null:
			quit(1)
			return
		img.save_png(a[1])
		print("wrote ", a[1], " ", img.get_size())
	quit(0)


func _load(path: String, sc: float) -> Image:
	var txt := FileAccess.get_file_as_string(path)
	if txt == "":
		printerr("cannot read ", path)
		return null
	var img := Image.new()
	var err := img.load_svg_from_string(txt, sc)
	if err != OK:
		printerr("SVG parse error ", err, " in ", path)
		return null
	return img


func _sheet(args: Array) -> void:
	var out: String = args[0]
	var cols := 5
	var cell := 320
	var files := []
	var i := 1
	while i < args.size():
		if args[i] == "--cols":
			cols = int(args[i + 1]); i += 2
		elif args[i] == "--cell":
			cell = int(args[i + 1]); i += 2
		else:
			files.append(args[i]); i += 1
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	for y in sheet.get_height():
		for x in sheet.get_width():
			var c := ((x / 16) + (y / 16)) % 2 == 0
			sheet.set_pixel(x, y, Color(0.75, 0.75, 0.78) if c else Color(0.55, 0.55, 0.6))
	for n in files.size():
		var img := _load(files[n], 1.0)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var s := minf(float(cell - 8) / img.get_width(), float(cell - 8) / img.get_height())
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_BILINEAR)
		var ox := (n % cols) * cell + (cell - img.get_width()) / 2
		var oy := (n / cols) * cell + (cell - img.get_height()) / 2
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(ox, oy))
	sheet.save_png(out)
	print("wrote sheet ", out, " (", files.size(), " images)")
