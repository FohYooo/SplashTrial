extends SceneTree
## Renders Case 3's evidence photographs from the real 3D rooms (scripts/world3d/rooms3.gd) with the guests' standees
## posed in them, then grades them like flash photos and prints the camera's orange date-back time in the corner.
## Writes art/evidence/<id>.jpg; clues.gd lists them as Truth Drop "images" (the evidence viewer opens them).
## SPOILERS: the poses below are the case.
##
## Needs a real renderer, so run it windowed and muted (it closes itself):
##   Godot --path . --audio-driver Dummy --resolution 1280x720 -s tools/render_evidence3.gd [-- --only=c3_frame_09,c3_roll_1]
##   [--size=3200x1800] [--out=<dir>] (a test render elsewhere, e.g. small)
## Then: Godot --headless --path . --import

const Kit := preload("res://scripts/world3d/kit.gd")
const Rooms := preload("res://scripts/world3d/rooms3.gd")
const Chapters := preload("res://scripts/data/chapters.gd")

const OUT := "res://art/evidence/"
const SIZE := Vector2i(3200, 1800)
const STAMP_COL := Color(1.0, 0.52, 0.12)

## Where everybody stood at seven this morning, in the Library (frames 4 to 16). Zuzu kneels by the body (sunk into the
## floor), Bruno stands under the top end of the fallen bookcase, holding it up. Two guests are in no frame at all.
const MORNING := {
	"zuzu": ["sad", Vector3(0.6, -0.42, -1.4)],
	"bruno": ["angry", Vector3(-1.2, 0.0, -0.65)],
	"reginald": ["sad", Vector3(-2.6, 0.0, 1.4)],
	"lulu": ["sad", Vector3(-1.9, 0.0, 1.65)],
	"fennel": ["sad", Vector3(-1.2, 0.0, 1.95)],
	"mochi": ["sad", Vector3(-0.6, 0.0, 2.3)],
}
const SIX := ["zuzu", "bruno", "reginald", "lulu", "fennel", "mochi"]

## One photograph: the space and its story day, the room's photo metas (see rooms3.gd header), the camera (position,
## target, vertical field of view, roll in degrees), who is in the room, the time on the date-back, and the light.
const SHOTS := [
	# ---- the 7 AM roll, frames 1 to 16 (Library, Day 6)
	{"id": "c3_frame_01", "space": "library", "day": 6, "meta": {"photo_trail": true, "photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(-0.7, 1.5, 1.5), "at": Vector3(-2.9, 1.0, 3.8), "fov": 54.0, "who": [], "stamp": "7:02", "flash": 2.6},
	{"id": "c3_frame_02", "space": "library", "day": 6, "meta": {"photo_trail": true, "photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(1.7, 1.6, 2.3), "at": Vector3(4.4, 0.35, 0.6), "fov": 58.0, "who": [], "stamp": "7:02", "flash": 2.4},
	{"id": "c3_frame_03", "space": "library", "day": 6, "meta": {"photo_trail": true, "photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(3.85, 1.95, 0.95), "at": Vector3(4.6, 0.62, 0.02), "fov": 50.0, "who": [], "stamp": "7:02", "flash": 1.6},
	{"id": "c3_frame_04", "space": "library", "day": 6, "meta": {"photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(-1.2, 1.55, 2.6), "at": Vector3(-0.4, 1.0, -2.4), "fov": 56.0, "who": ["zuzu", "bruno"], "stamp": "7:03", "flash": 2.4},
	{"id": "c3_frame_05", "space": "library", "day": 6, "meta": {"photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(1.6, 1.25, 0.9), "at": Vector3(2.7, 0.0, -0.9), "fov": 55.0, "who": [], "stamp": "7:03", "flash": 2.2, "roll": -9.0},
	{"id": "c3_frame_06", "space": "library", "day": 6, "meta": {"photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(1.3, 1.4, -0.3), "at": Vector3(-0.8, 0.9, -2.1), "fov": 52.0, "who": ["zuzu", "bruno"], "stamp": "7:03", "flash": 2.2},
	{"id": "c3_frame_07", "space": "library", "day": 6, "meta": {"photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(-0.6, 1.45, 1.8), "at": Vector3(-0.3, 3.6, -0.2), "fov": 60.0, "who": [], "stamp": "7:03", "flash": 2.0, "roll": 14.0},
	{"id": "c3_frame_08", "space": "library", "day": 6, "meta": {"photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(-0.6, 1.4, 0.2), "at": Vector3(-1.9, 1.05, 2.1), "fov": 50.0, "who": ["reginald", "lulu"], "stamp": "7:04", "flash": 2.2},
	{"id": "c3_frame_09", "space": "library", "day": 6, "meta": {"photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(-2.15, 2.45, 3.55), "at": Vector3(-0.4, 1.11, -1.13), "fov": 57.0, "who": SIX, "stamp": "7:04", "flash": 2.6},
	{"id": "c3_frame_10", "space": "library", "day": 6, "meta": {"photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(1.9, 1.7, -1.0), "at": Vector3(-0.3, 0.9, -2.3), "fov": 44.0, "who": ["zuzu"], "stamp": "7:04", "flash": 1.8},
	{"id": "c3_frame_11", "space": "library", "day": 6, "meta": {"photo_pen": "chewed", "photo_hatch": "shut"},
		"cam": Vector3(2.9, 1.5, -2.2), "at": Vector3(-0.2, 0.85, -2.6), "fov": 40.0, "who": ["zuzu", "bruno"], "stamp": "7:04", "flash": 1.8},
	{"id": "c3_frame_12", "space": "library", "day": 6, "meta": {"photo_pen": "clean", "photo_hatch": "crack"},
		"cam": Vector3(3.0, 1.75, -3.25), "at": Vector3(2.30, 0.32, 1.70), "fov": 78.0, "who": SIX, "stamp": "7:05", "flash": 2.6},
	{"id": "c3_frame_13", "space": "library", "day": 6, "meta": {},
		"cam": Vector3(2.2, 1.35, -0.9), "at": Vector3(0.35, 1.0, 1.15), "fov": 46.0, "who": ["fennel", "mochi"], "stamp": "7:05", "flash": 2.0},
	{"id": "c3_frame_14", "space": "library", "day": 6, "meta": {},
		"cam": Vector3(-0.45, 1.3, -1.35), "at": Vector3(-1.02, 0.8, -2.37), "fov": 40.0, "who": [], "stamp": "7:05", "flash": 1.6},
	{"id": "c3_frame_15", "space": "library", "day": 6, "meta": {},
		"cam": Vector3(-4.0, 1.55, 1.2), "at": Vector3(-2.9, 1.1, 4.3), "fov": 46.0, "who": ["reginald", "lulu", "grub"], "stamp": "7:06", "flash": 2.4},
	{"id": "c3_frame_16", "space": "library", "day": 6, "meta": {},
		"cam": Vector3(-3.7, 1.45, 2.3), "at": Vector3(-3.0, 1.45, 4.4), "fov": 52.0, "who": ["grub_sitting", "snapjaw"], "stamp": "7:06", "flash": 3.0},
	# ---- her own earlier roll, developed in the Gallery darkroom (Day 5): two frames in daylight, four in the blackout
	{"id": "c3_roll_1", "space": "gallery", "day": 5, "meta": {"gallery_clock": Vector2(5.0, 20.0)},
		"cam": Vector3(1.6, 1.5, 2.15), "at": Vector3(7.4, 1.35, -1.6), "fov": 44.0, "who": [], "stamp": "8:52", "flash": 1.6},
	{"id": "c3_roll_2", "space": "gallery", "day": 5, "meta": {"gallery_clock": Vector2(5.0, 22.0)},
		"cam": Vector3(-2.6, 1.5, 2.0), "at": Vector3(-4.6, 2.0, -3.0), "fov": 48.0, "who": [], "stamp": "9:00", "flash": 1.6},
	{"id": "c3_roll_3", "space": "gallery", "day": 6, "meta": {}, "dark": true,
		"cam": Vector3(6.1, 1.35, 1.35), "at": Vector3(8.5, 0.25, 0.25), "fov": 50.0, "who": [], "stamp": "11:06", "flash": 2.4},
	{"id": "c3_roll_4", "space": "gallery", "day": 6, "meta": {}, "dark": true,
		"cam": Vector3(7.0, 1.6, -1.6), "at": Vector3(-8.0, 1.2, -1.0), "fov": 56.0, "who": [], "stamp": "11:09", "flash": 2.6},
	{"id": "c3_roll_5", "space": "gallery", "day": 6, "meta": {}, "dark": true,
		"cam": Vector3(4.4, 1.45, -1.0), "at": Vector3(6.6, 1.2, -2.7), "fov": 52.0, "who": [], "stamp": "11:13", "flash": 2.4},
	{"id": "c3_roll_6", "space": "gallery", "day": 6, "meta": {}, "dark": true,
		"cam": Vector3(1.5, 1.5, 1.9), "at": Vector3(0.5, 2.0, -3.0), "fov": 52.0, "who": [], "stamp": "11:18", "flash": 2.4, "roll": -6.0},
]

## Grades the render like a flash photograph on colour film: warm mids, lifted blacks, a soft vignette, grain.
const GRADE := """shader_type canvas_item;
uniform float warm = 0.05;
uniform float vig = 0.5;
uniform float grain = 0.045;
uniform float lift = 0.035;
uniform float seed = 1.0;
uniform vec2 px = vec2(3200.0, 1800.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	c *= vec3(1.0 + warm, 1.0 + warm * 0.3, 1.0 - warm);
	c = c * (1.0 - lift) + lift * vec3(0.07, 0.055, 0.045);
	vec2 d = UV - 0.5;
	d.x *= 1.5;
	c *= 1.0 - vig * smoothstep(0.3, 0.95, length(d));
	c += (hash(floor(UV * px)) - 0.5) * grain;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

var _size := SIZE
var _out := OUT


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1).split(",")
		elif a.begins_with("--size="):
			var p := a.get_slice("=", 1).split("x")
			_size = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--out="):
			_out = a.get_slice("=", 1)
			if not _out.ends_with("/"):
				_out += "/"
	Chapters.current = 3
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var n := 0
	for s in SHOTS:
		var shot: Dictionary = s
		if not only.is_empty() and not only.has(str(shot["id"])):
			continue
		await _shoot(shot)
		n += 1
	print("render_evidence3: %d photographs written to %s" % [n, _out])
	quit()


func _shoot(shot: Dictionary) -> void:
	# the 3D room, with its own world
	var vp := SubViewport.new()
	vp.size = _size
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var holder := Node3D.new()
	vp.add_child(holder)
	var k := Kit.new(holder)
	k.mode = "photo"
	k.set_meta("day", int(shot["day"]))
	var meta: Dictionary = shot.get("meta", {})
	for key in meta.keys():
		k.set_meta(str(key), meta[key])
	if str(shot["space"]) == "library":
		# the Library's mantel clock tells the same time as the date-back: it was seven in the morning
		var hm := str(shot["stamp"]).split(":")
		k.set_meta("library_clock", Vector2(float(hm[0]), float(hm[1])))
	Rooms.build(str(shot["space"]), k, {})
	# the people in the shot
	for who in shot.get("who", []):
		var cid := str(who)
		if cid == "grub":
			k.standee("grub", "sad", Vector3(-3.0, 0.0, 4.35))
		elif cid == "grub_sitting":
			# he sat down on the floor right there in the doorway
			k.standee("grub", "sad", Vector3(-2.85, -0.55, 3.75))
		elif cid == "snapjaw":
			k.standee("snapjaw", "normal", Vector3(-3.05, 0.0, 4.45))
		elif MORNING.has(cid):
			var e: Array = MORNING[cid]
			k.standee(cid, str(e[0]), e[1])
			if cid == "fennel":
				k.crutch((e[1] as Vector3) + Vector3(0.38, 0.0, 0.05), 0.4, 0.2)
	# the dark: every lamp off, only the flash
	if bool(shot.get("dark", false)):
		_lights_out(holder)
		_dust_motes(k, shot)
	var cam := Camera3D.new()
	cam.fov = float(shot.get("fov", 55.0))
	cam.near = 0.03
	cam.far = 200.0
	holder.add_child(cam)
	cam.global_position = shot["cam"]
	cam.look_at(shot["at"], Vector3.UP)
	if shot.has("roll"):
		cam.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(float(shot["roll"])))
	cam.current = true
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.97, 0.92)
	flash.light_energy = float(shot.get("flash", 2.0))
	flash.omni_range = 14.0
	flash.omni_attenuation = 1.4
	flash.shadow_enabled = true
	holder.add_child(flash)
	flash.global_position = cam.global_position + cam.global_basis.y * 0.12 + cam.global_basis.x * 0.06
	for i in 8:
		await process_frame
	if OS.get_cmdline_user_args().has("--where"):
		# debug: where the things that matter land in the picture
		for hid in ["floor_pen", "hatch", "side_table", "clock"]:
			if k.hot.has(hid):
				var node: Node3D = (k.hot[hid] as Dictionary)["node"]
				var at: Vector3 = node.global_position
				print("    %s %s at %s, in view: %s" % [shot["id"], hid, cam.unproject_position(at), not cam.is_position_behind(at)])
	# grade it and print the date-back
	var post := SubViewport.new()
	post.size = _size
	post.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(post)
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.size = Vector2(_size)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = GRADE
	mat.set_shader_parameter("seed", float(str(shot["id"]).hash() % 1000) * 0.01)
	mat.set_shader_parameter("px", Vector2(_size))
	if bool(shot.get("dark", false)):
		mat.set_shader_parameter("vig", 0.75)
		mat.set_shader_parameter("lift", 0.02)
	tr.material = mat
	post.add_child(tr)
	var st := Stamp.new()
	st.text = str(shot["stamp"])
	st.size = Vector2(_size)
	post.add_child(st)
	for i in 3:
		await process_frame
	var img := post.get_texture().get_image()
	var path := _out + str(shot["id"]) + ".jpg"
	var err := img.save_jpg(ProjectSettings.globalize_path(path), 0.86)
	print("  %s %s" % [path, "ok" if err == OK else "FAILED %d" % err])
	post.queue_free()
	vp.queue_free()
	await process_frame


func _lights_out(n: Node) -> void:
	for c in n.get_children():
		if c is Light3D:
			(c as Light3D).visible = false
		elif c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			env.ambient_light_energy = 0.03
			env.fog_density = 0.03
			env.fog_light_color = Color(0.02, 0.02, 0.03)
			env.glow_intensity = 0.4
		elif c is MeshInstance3D:
			var m := (c as MeshInstance3D).get_active_material(0)
			if m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled:
				(c as MeshInstance3D).material_override = Kit.flat(Color(0.05, 0.05, 0.06))
		_lights_out(c)


## White plaster still drifting down in the dark, lit up by the flash.
func _dust_motes(k: Kit, shot: Dictionary) -> void:
	var from: Vector3 = shot["cam"]
	var to: Vector3 = shot["at"]
	var fwd := (to - from).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.94, 0.9)
	m.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = str(shot["id"]).hash()
	for i in 220:
		var d := rng.randf_range(0.6, 5.0)
		var p := from + fwd * d + side * rng.randf_range(-0.7, 0.7) * d + Vector3.UP * rng.randf_range(-0.45, 0.45) * d
		k.sphere(rng.randf_range(0.003, 0.009), p, m, null, Vector3.ONE, 5)


## The camera's date-back: orange seven-segment figures in the bottom right corner, a little blown out.
class Stamp extends Control:
	var text := ""
	const SEG := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc",
		"7": "abc", "8": "abcdefg", "9": "abcdfg"}

	func _draw() -> void:
		var h := size.y * 0.042
		var w := h * 0.52
		var t := h * 0.15
		var total := 0.0
		for ch in text:
			total += t * 1.9 if ch == ":" else w + t * 0.9
		var x0 := size.x - size.x * 0.05 - total
		var y0 := size.y - size.y * 0.075 - h
		for pass_i in 3:
			var col := Color(1.0, 0.52, 0.12, float([0.16, 0.3, 1.0][pass_i]))
			var grow: float = [t * 0.9, t * 0.45, 0.0][pass_i]
			var x := x0
			for ch in text:
				if ch == ":":
					draw_rect(Rect2(x + t * 0.3 - grow, y0 + h * 0.26 - grow, t + grow * 2.0, t + grow * 2.0), col)
					draw_rect(Rect2(x + t * 0.3 - grow, y0 + h * 0.62 - grow, t + grow * 2.0, t + grow * 2.0), col)
					x += t * 1.9
					continue
				var segs := {
					"a": Rect2(x + t * 0.6, y0, w - t * 1.2, t), "d": Rect2(x + t * 0.6, y0 + h - t, w - t * 1.2, t),
					"g": Rect2(x + t * 0.6, y0 + h / 2.0 - t / 2.0, w - t * 1.2, t),
					"f": Rect2(x, y0 + t * 0.6, t, h / 2.0 - t * 0.9), "b": Rect2(x + w - t, y0 + t * 0.6, t, h / 2.0 - t * 0.9),
					"e": Rect2(x, y0 + h / 2.0 + t * 0.3, t, h / 2.0 - t * 0.9), "c": Rect2(x + w - t, y0 + h / 2.0 + t * 0.3, t, h / 2.0 - t * 0.9),
				}
				for sk in str(SEG.get(ch, "")):
					var r: Rect2 = segs[sk]
					draw_rect(r.grow(grow), col)
				x += w + t * 0.9
