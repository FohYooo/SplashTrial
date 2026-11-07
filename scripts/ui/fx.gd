extends RefCounted
## Fx - standalone visual effect helpers (all static).   const Fx := preload("res://scripts/ui/fx.gd")
##
## Every helper adds its nodes under `parent` (a Control; full-rect effects cover the parent's rect, which
## should be the 1280x720 screen), ignores the mouse, frees itself when done and returns the node it made
## (or null when skipped: headless runs, and full-speed autotest for the costly ones).
## All of them are GL-Compatibility safe and allocate only when started (nothing per frame).
##
##   Fx.glitch(parent, duration := 0.22, strength := 1.0) -> ColorRect
##       Chromatic glitch over everything drawn behind it: RGB split, horizontal block offsets,
##       scanline jitter, aqua/coral glitch bars. Strength decays to 0, then the node is freed.
##   Fx.wipe_overlay(parent: Node) -> ColorRect   (parent may be a CanvasLayer)
##       A full-rect diagonal static-wipe overlay for screen transitions. Drive it with
##       Fx.wipe_to(overlay, cover, time) -> Tween   (cover 0 = clear, 1 = fully covered, 2 = wiped out).
##       Fx.set_wipe(overlay, cover, strength)        (instant).
##   Fx.speed_lines(parent, center := Vector2(640, 360), duration := 0.45, color := Color.WHITE,
##           count := 34, inner := 170.0) -> Control
##       Radial manga-style speed lines that shoot in from the screen edges toward `center`, then fade.
##   Fx.streaks(parent, rect: Rect2, color := Color.WHITE, count := 12, speed := -2200.0) -> Control
##       Endless horizontal speed streaks inside `rect` (free it yourself / free its parent).
##   Fx.shatter(parent, duration := 0.6, impact := Vector2(640, 360), tex: Texture2D = null) -> Control
##       Captures the current screen (or uses `tex`), splits it into radial glass shards around `impact`
##       (Polygon2D + UV) that crack, fly outward, spin and fade. Put it on top of the new content.
##   Fx.capture(node) -> Texture2D       snapshot of the last rendered frame (null if headless).
##   Fx.vignette(parent, color := Style.INK, strength := 0.75, inner := 0.42) -> TextureRect
##       Static radial darkening (cheap gradient texture, no shader). Caller keeps/frees it.
##   Fx.flash(parent, color := Color.WHITE, duration := 0.25, alpha := 0.8) -> ColorRect
##       Impact flash that fades out and frees itself.
##   Fx.shake(node, strength := 12.0, duration := 0.28)
##       Random positional shake around the node's current position (restored at the end).
##   Fx.ripple(parent, center, color := Style.AQUA, radius := 120.0, duration := 0.5, rings := 2) -> Control
##       Expanding water ripple ellipses.
##   Fx.splash(parent, center, color := Style.AQUA, count := 12, radius := 150.0, duration := 0.55) -> Control
##       Burst of water droplets flying outward from `center` (with a little gravity).
##   Fx.silhouette_material(color) -> ShaderMaterial   flat-colour silhouette of a texture (hard shadows)
##   Fx.skip_heavy() -> bool   true when effects should be skipped (headless or full-speed autotest).

const Style := preload("res://scripts/ui/style.gd")

const GLITCH_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float strength = 1.0;
uniform float cover = 0.0;
uniform float use_wipe = 0.0;
uniform float seed = 0.0;
uniform vec4 tint : source_color = vec4(0.243, 0.878, 0.816, 1.0);
uniform vec4 tint2 : source_color = vec4(1.0, 0.31, 0.427, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 24.0) + seed;
	float band = floor(uv.y * 22.0);
	float rb = hash(vec2(band, t));
	float off = step(0.70, rb) * (hash(vec2(band, t + 3.1)) - 0.5) * 0.11 * strength;
	off += (hash(vec2(floor(uv.y * 180.0), t + 7.0)) - 0.5) * 0.005 * strength;
	vec2 suv = clamp(vec2(uv.x + off, uv.y), vec2(0.0), vec2(1.0));
	float split = 0.011 * strength;
	vec3 c;
	c.r = texture(screen_tex, clamp(suv + vec2(split, 0.0), vec2(0.0), vec2(1.0))).r;
	c.g = texture(screen_tex, suv).g;
	c.b = texture(screen_tex, clamp(suv - vec2(split, 0.0), vec2(0.0), vec2(1.0))).b;
	float bar = step(0.92, hash(vec2(band, t + 11.0))) * min(strength, 1.0);
	vec3 barcol = hash(vec2(band, t + 5.0)) > 0.5 ? tint.rgb : tint2.rgb;
	c = mix(c, barcol, bar * 0.32);
	c *= 1.0 - 0.18 * min(strength, 1.0) * step(0.5, fract(FRAGCOORD.y * 0.5));
	if (use_wipe > 0.5) {
		float row = floor(FRAGCOORD.y / 6.0);
		float jag = (hash(vec2(row, seed)) - 0.5) * 0.05;
		float e = 0.06 + 0.88 * clamp(uv.x * 0.8 + (1.0 - uv.y) * 0.2 + jag, 0.0, 1.0);
		float covered = step(e, cover) * step(cover - 1.0, e);
		float n = hash(floor(FRAGCOORD.xy / 3.0) + vec2(t * 1.7, t));
		vec3 st = mix(vec3(0.027, 0.016, 0.06), vec3(0.085, 0.05, 0.16), n);
		st += tint.rgb * step(0.975, n) * 0.7;
		st += tint.rgb * 0.16 * step(0.82, hash(vec2(floor(FRAGCOORD.y / 2.0), t)));
		st += tint2.rgb * 0.22 * step(0.985, hash(vec2(row, t + 2.0)));
		float lead = 1.0 - smoothstep(0.0, 0.035, abs(e - cover));
		float trail = 1.0 - smoothstep(0.0, 0.035, abs(e - (cover - 1.0)));
		float edge = max(lead * step(0.001, cover) * step(cover, 1.0), trail * step(1.0, cover) * step(cover, 1.999));
		c = mix(c, st, covered);
		c = mix(c, mix(tint.rgb, vec3(1.0), 0.45), edge * 0.85);
	}
	COLOR = vec4(c, 1.0);
}
"""

const SILHOUETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
void fragment() {
	COLOR = vec4(tint.rgb, COLOR.a * tint.a);
}
"""

static var _glitch_shader: Shader = null
static var _sil_shader: Shader = null
static var _vignette_tex: Dictionary = {}


static func skip_heavy() -> bool:
	return DisplayServer.get_name() == "headless" or (Game.autotest and not Game.autotest_slow)


static func _shader() -> Shader:
	if _glitch_shader == null:
		_glitch_shader = Shader.new()
		_glitch_shader.code = GLITCH_SHADER
	return _glitch_shader


static func _full(parent: Control, c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.position = Vector2.ZERO
	c.size = parent.size if parent.size.x > 1.0 else Vector2(1280, 720)


## Material that draws a texture as a flat-colour silhouette (hard shadows / echoes of portraits).
static func silhouette_material(color: Color) -> ShaderMaterial:
	if _sil_shader == null:
		_sil_shader = Shader.new()
		_sil_shader.code = SILHOUETTE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _sil_shader
	m.set_shader_parameter("tint", color)
	return m


# ------------------------------------------------------------------ glitch
static func glitch(parent: Control, duration: float = 0.22, strength: float = 1.0) -> ColorRect:
	if skip_heavy() or parent == null:
		return null
	# holder = [BackBufferCopy, glitch rect]: the copy guarantees a fresh screen capture for this effect
	var holder := Control.new()
	_full(parent, holder)
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	holder.add_child(bb)
	var r := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = _shader()
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("seed", randf() * 100.0)
	r.material = mat
	_full(holder, r)
	var tw := holder.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("strength", v), strength, 0.0, duration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(holder.queue_free)
	return r


static func wipe_overlay(parent: Node) -> ColorRect:
	var r := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = _shader()
	mat.set_shader_parameter("use_wipe", 1.0)
	mat.set_shader_parameter("strength", 0.0)
	mat.set_shader_parameter("cover", 0.0)
	r.material = mat
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	# the BackBufferCopy is only visible (= only copies the screen) while the wipe is on screen
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	bb.visible = false
	parent.add_child(bb)
	parent.add_child(r)
	r.set_meta("fx_bb", bb)
	return r


static func set_wipe(overlay: ColorRect, cover: float, strength: float) -> void:
	var mat := overlay.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("cover", cover)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("seed", randf() * 100.0)
	overlay.visible = cover > 0.0 and cover < 2.0
	var bb: Node = overlay.get_meta("fx_bb", null)
	if bb is CanvasItem and is_instance_valid(bb):
		(bb as CanvasItem).visible = overlay.visible


## Tweens the wipe from its current cover to `to` (glitch strength peaks while covered).
static func wipe_to(overlay: ColorRect, to: float, time: float) -> Tween:
	var mat := overlay.material as ShaderMaterial
	var from: float = float(mat.get_shader_parameter("cover")) if mat else 0.0
	var tw := overlay.create_tween()
	tw.tween_method(func(v: float) -> void:
		# strength rises toward full cover and decays while revealing
		set_wipe(overlay, v, clampf(1.0 - absf(v - 1.0), 0.0, 1.0) * 0.9 + 0.1), from, to, maxf(time, 0.001)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw


# ------------------------------------------------------------------ speed lines / streaks
static func speed_lines(parent: Control, center: Vector2 = Vector2(640, 360), duration: float = 0.45,
		color: Color = Color.WHITE, count: int = 34, inner: float = 170.0) -> Control:
	if parent == null or DisplayServer.get_name() == "headless":
		return null
	var s := SpeedLines.new()
	s.center = center
	s.color = color
	s.inner = inner
	s.setup(count)
	_full(parent, s)
	var tw := s.create_tween()
	tw.tween_property(s, "progress", 1.0, maxf(duration, 0.05))
	tw.tween_callback(s.queue_free)
	return s


static func streaks(parent: Control, rect: Rect2, color: Color = Color.WHITE, count: int = 12, speed: float = -2200.0) -> Control:
	var s := Streaks.new()
	s.area = rect
	s.color = color
	s.speed = speed
	s.setup(count)
	_full(parent, s)
	return s


# ------------------------------------------------------------------ shatter
static func capture(node: Node) -> Texture2D:
	if node == null or DisplayServer.get_name() == "headless" or not node.is_inside_tree():
		return null
	var vp := node.get_viewport()
	if vp == null:
		return null
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


static func shatter(parent: Control, duration: float = 0.6, impact: Vector2 = Vector2(640, 360), tex: Texture2D = null) -> Control:
	if parent == null or skip_heavy():
		return null
	if tex == null:
		tex = capture(parent)
	if tex == null:
		return null
	var root := Control.new()
	_full(parent, root)
	# local (parent) coords -> texture pixel coords
	var xf := parent.get_viewport().get_final_transform() * parent.get_global_transform_with_canvas()
	var screen := Vector2(1280, 720)
	var rays := 10
	var radii := [0.0, 70.0, 190.0, 380.0, 700.0, 1500.0]
	var angles: Array[float] = []
	var a0 := randf() * TAU
	for i in rays:
		angles.append(a0 + TAU * (i + randf_range(-0.28, 0.28)) / rays)
	var cracks := Cracks.new()
	var shards: Array[Polygon2D] = []
	for j in radii.size() - 1:
		for i in rays:
			var a1: float = angles[i]
			var a2: float = angles[(i + 1) % rays] + (TAU if i == rays - 1 else 0.0)
			var r1: float = radii[j] * (1.0 if j == 0 else randf_range(0.85, 1.15))
			var r2: float = radii[j + 1] * randf_range(0.88, 1.12)
			var pts := PackedVector2Array()
			if j == 0:
				pts.append(impact)
			else:
				pts.append(impact + Vector2(cos(a1), sin(a1)) * r1)
				pts.append(impact + Vector2(cos(a2), sin(a2)) * r1)
			pts.append(impact + Vector2(cos(a2), sin(a2)) * r2)
			pts.append(impact + Vector2(cos(a1), sin(a1)) * r2)
			# skip shards fully outside the screen
			var bb := Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				bb = bb.expand(p)
			if not bb.intersects(Rect2(Vector2.ZERO, screen)):
				continue
			var cen := Vector2.ZERO
			for p in pts:
				cen += p
			cen /= pts.size()
			var local := PackedVector2Array()
			var uv := PackedVector2Array()
			for p in pts:
				local.append(p - cen)
				uv.append(xf * p)
			var poly := Polygon2D.new()
			poly.texture = tex
			poly.polygon = local
			poly.uv = uv
			poly.position = cen
			root.add_child(poly)
			shards.append(poly)
			cracks.lines.append(pts)
	cracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cracks.size = screen
	root.add_child(cracks)
	var crack_t := minf(0.09, duration * 0.2)
	var tw := root.create_tween().set_parallel(true)
	for poly in shards:
		var dir := (poly.position - impact)
		var dist := dir.length()
		dir = dir.normalized() if dist > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)
		var fly := dir * randf_range(140.0, 420.0) * (0.6 + clampf(dist / 600.0, 0.0, 1.0)) + Vector2(0, randf_range(120.0, 320.0))
		var fly_t := duration - crack_t
		tw.tween_property(poly, "position", poly.position + fly, fly_t).set_delay(crack_t) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(poly, "rotation", randf_range(-1.3, 1.3), fly_t).set_delay(crack_t)
		tw.tween_property(poly, "scale", Vector2.ONE * randf_range(0.6, 0.9), fly_t).set_delay(crack_t)
		tw.tween_property(poly, "modulate:a", 0.0, fly_t * 0.6).set_delay(crack_t + fly_t * 0.4)
	tw.tween_property(cracks, "modulate:a", 0.0, 0.12).set_delay(crack_t)
	tw.chain().tween_callback(root.queue_free)
	return root


# ------------------------------------------------------------------ vignette / flash / shake / ripple
static func vignette(parent: Control, color: Color = Style.INK, strength: float = 0.75, inner: float = 0.42) -> TextureRect:
	var key := "%s|%s|%s" % [color.to_html(), strength, inner]
	var gt: GradientTexture2D = _vignette_tex.get(key, null)
	if gt == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, inner, 1.0])
		g.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.0), Color(color, strength)])
		gt = GradientTexture2D.new()
		gt.gradient = g
		gt.width = 160
		gt.height = 90
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 1.0)
		_vignette_tex[key] = gt
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	_full(parent, r)
	return r


static func flash(parent: Control, color: Color = Color.WHITE, duration: float = 0.25, alpha: float = 0.8) -> ColorRect:
	if parent == null:
		return null
	var r := ColorRect.new()
	r.color = Color(color, alpha)
	_full(parent, r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, maxf(duration, 0.01)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(r.queue_free)
	return r


static func shake(node: Node, strength: float = 12.0, duration: float = 0.28) -> void:
	if node == null or not (node is Control or node is Node2D):
		return
	var base: Vector2 = node.get_meta("fx_shake_base", node.get("position"))
	node.set_meta("fx_shake_base", base)
	var steps := maxi(3, int(duration / 0.035))
	var tw := node.create_tween()
	for i in steps:
		var k := 1.0 - float(i) / steps
		tw.tween_property(node, "position", base + Vector2(randf_range(-1, 1), randf_range(-0.6, 0.6)) * strength * k, duration / steps)
	tw.tween_property(node, "position", base, 0.03)
	tw.tween_callback(func() -> void: node.remove_meta("fx_shake_base"))


static func ripple(parent: Control, center: Vector2, color: Color = Style.AQUA, radius: float = 120.0,
		duration: float = 0.5, rings: int = 2) -> Control:
	if parent == null or DisplayServer.get_name() == "headless":
		return null
	var r := Ripple.new()
	r.center = center
	r.color = color
	r.radius = radius
	r.rings = rings
	_full(parent, r)
	var tw := r.create_tween()
	tw.tween_property(r, "progress", 1.0, maxf(duration, 0.05)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(r.queue_free)
	return r


static func splash(parent: Control, center: Vector2, color: Color = Style.AQUA, count: int = 12,
		radius: float = 150.0, duration: float = 0.55) -> Control:
	if parent == null or DisplayServer.get_name() == "headless":
		return null
	var s := Splash.new()
	s.center = center
	s.color = color
	s.radius = radius
	s.setup(count)
	_full(parent, s)
	var tw := s.create_tween()
	tw.tween_property(s, "progress", 1.0, maxf(duration, 0.05))
	tw.tween_callback(s.queue_free)
	return s


# ================================================================== effect nodes
class SpeedLines extends Control:
	var center := Vector2(640, 360)
	var color := Color.WHITE
	var inner := 170.0
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()
	var _ang := PackedFloat32Array()
	var _wid := PackedFloat32Array()
	var _jit := PackedFloat32Array()
	var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

	func setup(count: int) -> void:
		for i in count:
			_ang.append(TAU * (i + randf_range(-0.35, 0.35)) / count)
			_wid.append(randf_range(3.0, 14.0))
			_jit.append(randf_range(0.0, 160.0))

	func _draw() -> void:
		var far := 1500.0
		var shoot := clampf(progress * 3.2, 0.0, 1.0)
		var fade := 1.0 - clampf((progress - 0.35) / 0.65, 0.0, 1.0)
		if fade <= 0.0 or shoot <= 0.0:
			return
		var col := Color(color, color.a * fade)
		for i in _ang.size():
			var d := Vector2(cos(_ang[i]), sin(_ang[i]))
			var p := Vector2(-d.y, d.x)
			var tip_r := minf(far - 60.0, lerpf(far, inner + _jit[i], 1.0 - pow(1.0 - shoot, 3.0)))
			var base := center + d * far
			_tri[0] = center + d * tip_r
			_tri[1] = base + p * _wid[i]
			_tri[2] = base - p * _wid[i]
			draw_colored_polygon(_tri, col)


class Streaks extends Control:
	var area := Rect2(0, 0, 1280, 720)
	var color := Color.WHITE
	var speed := -2200.0
	var _x := PackedFloat32Array()
	var _y := PackedFloat32Array()
	var _len := PackedFloat32Array()
	var _th := PackedFloat32Array()

	func setup(count: int) -> void:
		for i in count:
			_x.append(randf_range(area.position.x, area.end.x))
			_y.append(randf_range(area.position.y, area.end.y))
			_len.append(randf_range(80.0, 320.0))
			_th.append(randf_range(1.5, 4.0))

	func _process(delta: float) -> void:
		var w := area.size.x + 640.0
		for i in _x.size():
			_x[i] += speed * delta * (0.6 + 0.4 * (_th[i] / 4.0))
			if speed < 0.0 and _x[i] + _len[i] < area.position.x - 160.0:
				_x[i] += w
			elif speed > 0.0 and _x[i] > area.end.x + 160.0:
				_x[i] -= w
		queue_redraw()

	func _draw() -> void:
		for i in _x.size():
			draw_line(Vector2(_x[i], _y[i]), Vector2(_x[i] + _len[i], _y[i]), color, _th[i])


class Cracks extends Control:
	var lines: Array[PackedVector2Array] = []

	func _draw() -> void:
		for pts in lines:
			var loop := pts.duplicate()
			loop.append(pts[0])
			draw_polyline(loop, Color(1, 1, 1, 0.9), 2.0)


class Ripple extends Control:
	var center := Vector2.ZERO
	var color := Color.WHITE
	var radius := 120.0
	var rings := 2
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _draw() -> void:
		for i in rings:
			var p := clampf(progress * (1.0 + i * 0.35) - i * 0.25, 0.0, 1.0)
			if p <= 0.0:
				continue
			var rr := radius * p
			var a := (1.0 - p) * color.a
			if a <= 0.01:
				continue
			draw_set_transform(center, 0.0, Vector2(1.0, 0.36))
			draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(color, a), 4.0 * (1.0 - p) + 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class Splash extends Control:
	var center := Vector2.ZERO
	var color := Color.WHITE
	var radius := 150.0
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()
	var _dir := PackedVector2Array()
	var _spd := PackedFloat32Array()
	var _sz := PackedFloat32Array()
	var _unit := Style.Geo.droplet(Vector2.ZERO, 1.0)

	func setup(count: int) -> void:
		for i in count:
			var a := -PI * 0.5 + randf_range(-1.35, 1.35) if i % 3 != 0 else randf() * TAU
			_dir.append(Vector2(cos(a), sin(a)))
			_spd.append(randf_range(0.55, 1.0))
			_sz.append(randf_range(4.0, 9.0))

	func _draw() -> void:
		var e := 1.0 - pow(1.0 - progress, 2.2)
		var a := 1.0 - clampf((progress - 0.5) / 0.5, 0.0, 1.0)
		if a <= 0.0:
			return
		for i in _dir.size():
			var p := center + _dir[i] * radius * _spd[i] * e + Vector2(0, 160.0 * progress * progress)
			var vel := _dir[i] * _spd[i] * (1.0 - progress) + Vector2(0, 0.9 * progress)
			var rot := vel.angle() - PI * 0.5
			var r := _sz[i] * (1.0 - 0.4 * progress)
			draw_set_transform(p, rot, Vector2(r, r))
			draw_colored_polygon(_unit, Color(color, color.a * a))
			draw_circle(Vector2(-0.3, -0.2), 0.28, Color(1, 1, 1, 0.7 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
