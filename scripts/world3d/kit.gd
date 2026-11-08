extends RefCounted
## 3D building kit for the walk-around rooms (3D version only). Everything is built in code from
## primitive meshes, inline shaders and the game's own runtime-loaded SVG art (no imports, no .tscn).
##
##   var k := Kit.new(room_root)
##   k.shell(9.0, 8.0, 3.2, {...})                  # floor, walls, ceiling
##   var g := k.hotspot("lockers", Vector3(-3, 0, -3.6), Vector3(2.6, 2.2, 0.7))
##   k.box(Vector3(2.4, 2.1, 0.5), Vector3(0, 1.05, 0), k.wood_mid, true, g)   # meshes local to g
##   k.person("reginald", Vector3(3, 0, 1))
##   k.door("garden", Vector3(4.5, 0, 0), -PI / 2)
## The screen reads k.hot / k.people / k.doors / k.spawn / k.look afterwards.
##
## Coordinates: metres. Room centred on the origin, the player starts near +z looking towards -z,
## so the back wall (-z) is what the 2D background showed.

const Assets := preload("res://scripts/core/assets.gd")
const Style := preload("res://scripts/ui/style.gd")
const Cast := preload("res://scripts/data/cast.gd")

const LAYER_WORLD := 1
const LAYER_INTERACT := 2

var root: Node3D
var hot := {}       # id -> {"node": Node3D, "body": StaticBody3D, "top": Vector3}
var people := {}    # char id -> Vector3 (floor position)
var doors := {}     # room id -> {"node": Node3D, "body": StaticBody3D, "pos": Vector3, "rot": float, "top": Vector3}
var spots: Array = []   # free-time hubs: extra standing spots (Vector3) for anyone without a named spot
var spawn := Vector3(0, 0, 3)
var look := Vector3(0, 1.3, -3)
var bounds := Vector2(8, 8)   # w, d (used by fallbacks)
var names := {}               # room id -> display name (door signs)
var flickers: Array = []      # lights that flicker (fires, furnaces)

# shared materials (made in _init)
var wood_dark: StandardMaterial3D
var wood_mid: StandardMaterial3D
var wood_light: StandardMaterial3D
var plaster: StandardMaterial3D
var steel: StandardMaterial3D
var brass: StandardMaterial3D
var paper: StandardMaterial3D
var black: StandardMaterial3D
var white: StandardMaterial3D
var stone: StandardMaterial3D

static var _shader_cache := {}
static var _tex_cache := {}


func _init(r: Node3D = null) -> void:
	root = r
	wood_dark = mat(Color(0.2, 0.11, 0.06), 0.7)
	wood_mid = mat(Color(0.33, 0.18, 0.09), 0.6)
	wood_light = mat(Color(0.55, 0.36, 0.19), 0.5)
	plaster = mat(Color(0.82, 0.75, 0.62), 0.95)
	steel = mat(Color(0.24, 0.26, 0.29), 0.4, 0.8)
	brass = mat(Color(0.86, 0.64, 0.26), 0.3, 0.85)
	paper = mat(Color(0.95, 0.92, 0.84), 0.9)
	black = mat(Color(0.05, 0.045, 0.05), 0.5)
	white = mat(Color(0.93, 0.93, 0.9), 0.7)
	stone = mat(Color(0.52, 0.52, 0.5), 0.95)


# =================================================================== shaders
const SH_WOOD := """shader_type spatial;
// Procedural planks in world space. Floors: planks along z. Walls/ceilings: planks run along the wall.
uniform vec3 wood_dark : source_color = vec3(0.30, 0.17, 0.09);
uniform vec3 wood_light : source_color = vec3(0.52, 0.32, 0.17);
uniform float plank_width = 0.24;
uniform float plank_length = 2.2;
uniform bool vertical = false;
varying vec3 wpos;
varying vec3 wnrm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 p = wpos.xz;
	if (abs(wnrm.y) < 0.6) {
		float hz = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
		p = vertical ? vec2(hz, wpos.y) : vec2(wpos.y, hz);
	}
	float row = floor(p.x / plank_width);
	float off = hash(vec2(row, 3.7)) * plank_length;
	float col = floor((p.y + off) / plank_length);
	float h = hash(vec2(row, col));
	vec2 local = vec2(fract(p.x / plank_width), fract((p.y + off) / plank_length));
	float grain = noise(vec2(p.x * 38.0 + h * 17.0, p.y * 1.6)) * 0.6 + noise(vec2(p.x * 140.0, p.y * 5.0 + h * 9.0)) * 0.4;
	vec3 c = mix(wood_dark, wood_light, clamp(h * 0.65 + grain * 0.35, 0.0, 1.0));
	c *= 0.82 + 0.18 * grain;
	float seam_x = smoothstep(0.0, 0.035, local.x) * (1.0 - smoothstep(0.965, 1.0, local.x));
	float seam_z = smoothstep(0.0, 0.004, local.y) * (1.0 - smoothstep(0.996, 1.0, local.y));
	c *= mix(0.32, 1.0, seam_x * seam_z);
	ALBEDO = c;
	ROUGHNESS = 0.4 + grain * 0.25;
	SPECULAR = 0.45;
}
"""

const SH_STONE := """shader_type spatial;
// Irregular stone slabs / tiles in world space (bath decks, garden paths, sauna floor, boiler plates).
uniform vec3 col_a : source_color = vec3(0.46, 0.45, 0.43);
uniform vec3 col_b : source_color = vec3(0.62, 0.6, 0.56);
uniform vec3 grout : source_color = vec3(0.16, 0.15, 0.14);
uniform float tile = 0.7;
uniform float wet = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 p = wpos.xz;
	if (abs(wnrm.y) < 0.6) { p = vec2(abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x, wpos.y); }
	p /= tile;
	float row = floor(p.y);
	p.x += hash(vec2(row, 1.3)) * 0.8;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash(cell);
	float n = noise(p * 6.0) * 0.5 + noise(p * 17.0) * 0.5;
	vec3 c = mix(col_a, col_b, clamp(h * 0.7 + n * 0.3, 0.0, 1.0));
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float g = smoothstep(0.015, 0.05, edge + (n - 0.5) * 0.02);
	c = mix(grout, c, g);
	ALBEDO = c * (0.9 + 0.1 * n);
	ROUGHNESS = mix(0.92, 0.25, wet);
	SPECULAR = mix(0.3, 0.7, wet);
}
"""

const SH_GRASS := """shader_type spatial;
uniform vec3 g1 : source_color = vec3(0.24, 0.48, 0.18);
uniform vec3 g2 : source_color = vec3(0.42, 0.66, 0.26);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float n = noise(p * 1.3) * 0.5 + noise(p * 5.0) * 0.3 + noise(p * 31.0) * 0.2;
	vec3 c = mix(g1, g2, n);
	float blade = noise(p * vec2(90.0, 23.0));
	c *= 0.85 + 0.3 * blade;
	vec2 cell = floor(p * 14.0);
	vec2 f = fract(p * 14.0) - 0.5;
	float fl = step(0.97, hash(cell)) * (1.0 - smoothstep(0.08, 0.16, length(f)));
	c = mix(c, vec3(1.0, 0.95, 0.75), fl * 0.8);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""

const SH_WATER := """shader_type spatial;
// Hot-spring / lake water: animated ripples, fresnel, a soft inner glow.
uniform vec3 deep : source_color = vec3(0.04, 0.36, 0.40);
uniform vec3 shallow : source_color = vec3(0.30, 0.82, 0.78);
uniform float glow = 0.35;
uniform float speed = 1.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float hgt(vec2 p, float t) {
	return noise(p * 1.7 + vec2(t * 0.22, t * 0.15)) * 0.6 + noise(p * 3.9 - vec2(t * 0.27, -t * 0.1)) * 0.4;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float t = TIME * speed;
	vec2 p = wpos.xz;
	float h = hgt(p, t);
	float e = 0.06;
	float hx = hgt(p + vec2(e, 0.0), t) - h;
	float hz = hgt(p + vec2(0.0, e), t) - h;
	NORMAL_MAP = normalize(vec3(-hx * 6.0, -hz * 6.0, 1.0)) * 0.5 + 0.5;
	vec3 c = mix(deep, shallow, smoothstep(0.2, 0.85, h));
	float cau = pow(1.0 - abs(noise(p * 2.3 + vec2(t * 0.2, t * 0.13)) - 0.5) * 2.0, 10.0);
	ALBEDO = c * 0.7;
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	EMISSION = c * glow + vec3(0.6, 1.0, 0.95) * cau * glow * 0.6;
}
"""

const SH_LANTERN := """shader_type spatial;
// Glowing paper lantern: emissive paper with darker ribs (horizontal bands).
render_mode cull_back;
uniform vec3 paper : source_color = vec3(1.0, 0.86, 0.64);
uniform float energy = 2.2;
uniform float ribs = 9.0;
void fragment() {
	float band = abs(fract(UV.y * ribs) - 0.5) * 2.0;
	float rib = smoothstep(0.82, 0.98, band);
	float edge = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);
	vec3 c = paper * mix(1.0, 0.45, rib);
	ALBEDO = c * 0.4;
	EMISSION = c * energy * (0.55 + 0.45 * edge);
	ROUGHNESS = 0.9;
}
"""

const SH_SHOJI := """shader_type spatial;
// Back-lit shoji / window: a warm paper glow behind a dark lattice.
uniform vec3 glow_col : source_color = vec3(1.0, 0.88, 0.66);
uniform vec3 frame_col : source_color = vec3(0.16, 0.09, 0.05);
uniform float energy = 1.4;
uniform vec2 cells = vec2(4.0, 3.0);
void fragment() {
	vec2 g = abs(fract(UV * cells) - 0.5) * 2.0;
	float bar = max(smoothstep(0.88, 0.95, g.x), smoothstep(0.86, 0.94, g.y));
	vec2 edge = min(UV, 1.0 - UV);
	bar = max(bar, 1.0 - smoothstep(0.0, 0.03, min(edge.x, edge.y)));
	float grad = 0.75 + 0.25 * (1.0 - UV.y);
	ALBEDO = mix(glow_col * 0.5, frame_col, bar);
	EMISSION = glow_col * energy * grad * (1.0 - bar);
	ROUGHNESS = 0.9;
}
"""

const SH_STANDEE := """shader_type spatial;
// Character standee: Y-locked billboard of the 2D portrait, unshaded so the art keeps its colours.
// Bust fallback art fades out softly at the bottom (full-body art uses fade ~ 0); `outline` draws a gold glow when you look at them.
render_mode unshaded, cull_disabled, depth_prepass_alpha, shadows_disabled;
uniform sampler2D portrait : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.92);
uniform float brightness = 1.0;
uniform float fade = 0.2;
uniform float gray = 0.0;
uniform float alpha = 1.0;
uniform float outline = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.4, 1.0);
uniform float outline_w = 0.012;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec4 t = texture(portrait, UV);
	float a = t.a;
	float o = 0.0;
	if (outline > 0.001) {
		vec2 d = vec2(outline_w * 0.8, outline_w);
		o = max(o, texture(portrait, UV + vec2(d.x, 0.0)).a);
		o = max(o, texture(portrait, UV - vec2(d.x, 0.0)).a);
		o = max(o, texture(portrait, UV + vec2(0.0, d.y)).a);
		o = max(o, texture(portrait, UV - vec2(0.0, d.y)).a);
		o = max(o, texture(portrait, UV + d * 0.7071).a);
		o = max(o, texture(portrait, UV - d * 0.7071).a);
		o = max(o, texture(portrait, UV + vec2(d.x, -d.y) * 0.7071).a);
		o = max(o, texture(portrait, UV + vec2(-d.x, d.y) * 0.7071).a);
	}
	vec3 c = t.rgb * tint * brightness;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * 0.75, gray);
	float oa = clamp(o - a, 0.0, 1.0) * outline * (0.75 + 0.25 * sin(TIME * 5.0));
	float out_a = a + (1.0 - a) * oa;
	vec3 rgb = (c * a + outline_color.rgb * (1.0 - a) * oa) / max(out_a, 0.0001);
	ALBEDO = rgb;
	ALPHA = out_a * smoothstep(0.0, fade, 1.0 - UV.y) * alpha;
}
"""

const SH_BLOB := """shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.5;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.25, 1.0, d)) * strength;
}
"""

const SH_RIM := """shader_type spatial;
// Overlay used to highlight the object under the crosshair (material_overlay).
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 color : source_color = vec4(0.25, 0.88, 0.82, 1.0);
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float pulse = 0.7 + 0.3 * sin(TIME * 5.0);
	ALBEDO = color.rgb * (0.1 + f * 0.85) * pulse;
}
"""

const SH_ROCK := """shader_type spatial;
// Cave rock / boulders: dark, noisy, slightly wet.
uniform vec3 col_a : source_color = vec3(0.10, 0.10, 0.12);
uniform vec3 col_b : source_color = vec3(0.22, 0.21, 0.22);
uniform float scale = 1.2;
varying vec3 wpos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 p = wpos * scale;
	float n = noise(p) * 0.5 + noise(p * 2.7) * 0.3 + noise(p * 8.0) * 0.2;
	ALBEDO = mix(col_a, col_b, n);
	ROUGHNESS = 0.55 + n * 0.4;
	SPECULAR = 0.4;
}
"""

const SH_METAL := """shader_type spatial;
// Riveted steel plates (boiler room walls / furnace).
uniform vec3 base : source_color = vec3(0.26, 0.27, 0.29);
uniform vec2 plate = vec2(1.2, 0.9);
varying vec3 wpos;
varying vec3 wnrm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 p = abs(wnrm.y) > 0.6 ? wpos.xz : vec2(abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x, wpos.y);
	vec2 q = p / plate;
	vec2 f = fract(q);
	float h = hash(floor(q));
	float seam = min(min(f.x, 1.0 - f.x) * plate.x, min(f.y, 1.0 - f.y) * plate.y);
	vec3 c = base * (0.85 + 0.25 * h);
	c *= mix(0.45, 1.0, smoothstep(0.0, 0.025, seam));
	vec2 rp = vec2((fract(q.x * 6.0) - 0.5) * plate.x / 6.0, (f.y - 0.06) * plate.y);
	float rv = 1.0 - smoothstep(0.012, 0.02, length(rp));
	c += vec3(0.14) * rv;
	ALBEDO = c;
	METALLIC = 0.7;
	ROUGHNESS = 0.45 + 0.2 * h;
}
"""

const SH_BAMBOO := """shader_type spatial;
// Bamboo fence: vertical poles with rings, in world space.
uniform vec3 c1 : source_color = vec3(0.66, 0.6, 0.36);
uniform vec3 c2 : source_color = vec3(0.42, 0.37, 0.2);
uniform float pole = 0.09;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float hz = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
	float f = fract(hz / pole);
	float id = floor(hz / pole);
	float shade = sin(f * 3.14159);
	float ny = fract(wpos.y / 0.45 + fract(id * 0.37));
	float node = 1.0 - smoothstep(0.0, 0.035, min(ny, 1.0 - ny));
	vec3 c = mix(c2, c1, shade) * (1.0 - node * 0.4);
	c *= mix(0.55, 1.0, smoothstep(0.0, 0.1, f) * smoothstep(1.0, 0.9, f));
	ALBEDO = c;
	ROUGHNESS = 0.6;
}
"""

const SH_STRIPES := """shader_type spatial;
// Striped fabric / shirt (UV based).
uniform vec3 a : source_color = vec3(0.95, 0.95, 0.95);
uniform vec3 b : source_color = vec3(0.16, 0.32, 0.62);
uniform float count = 10.0;
void fragment() {
	float s = step(0.5, fract(UV.y * count));
	ALBEDO = mix(a, b, s);
	ROUGHNESS = 0.85;
}
"""


static func shader(code: String) -> Shader:
	if _shader_cache.has(code):
		return _shader_cache[code]
	var s := Shader.new()
	s.code = code
	_shader_cache[code] = s
	return s


func smat(code: String, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(code)
	for k in params.keys():
		m.set_shader_parameter(str(k), params[k])
	return m


func wood_floor(dark: Color = Color(0.30, 0.17, 0.09), light: Color = Color(0.52, 0.32, 0.17), width: float = 0.24) -> ShaderMaterial:
	return smat(SH_WOOD, {"wood_dark": dark, "wood_light": light, "plank_width": width})


func wood_wall(dark: Color, light: Color, width: float = 0.2) -> ShaderMaterial:
	return smat(SH_WOOD, {"wood_dark": dark, "wood_light": light, "plank_width": width, "plank_length": 3.0, "vertical": true})


func stone_floor(a: Color = Color(0.46, 0.45, 0.43), b: Color = Color(0.62, 0.6, 0.56), tile: float = 0.7, wet: float = 0.0) -> ShaderMaterial:
	return smat(SH_STONE, {"col_a": a, "col_b": b, "tile": tile, "wet": wet, "grout": a.darkened(0.6)})


func water(deep: Color = Color(0.04, 0.36, 0.40), shallow: Color = Color(0.30, 0.82, 0.78), glow: float = 0.35) -> ShaderMaterial:
	return smat(SH_WATER, {"deep": deep, "shallow": shallow, "glow": glow})


func bamboo() -> ShaderMaterial:
	return smat(SH_BAMBOO)


func stripes(a: Color, b: Color, count: float = 10.0) -> ShaderMaterial:
	return smat(SH_STRIPES, {"a": a, "b": b, "count": count})


func rock_mat(a: Color = Color(0.10, 0.10, 0.12), b: Color = Color(0.22, 0.21, 0.22)) -> ShaderMaterial:
	return smat(SH_ROCK, {"col_a": a, "col_b": b})


# =================================================================== materials
func mat(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := mat(color, 0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func tex_mat(tex: Texture2D, unshaded: bool = false, alpha: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 0.85
	return m


# =================================================================== primitives
func _parent(p: Node) -> Node:
	return p if p != null else root


## Emissive meshes (bulbs, lamp glass, glowing windows) and lamp hardware never cast shadows.
static func _shadow_rule(mi: GeometryInstance3D, m: Material) -> void:
	var sm := m as StandardMaterial3D
	if sm and sm.emission_enabled:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func box(size: Vector3, pos: Vector3, m: Material, collide: bool = false, parent: Node = null, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	_shadow_rule(mi, m)
	_parent(parent).add_child(mi)
	if collide:
		_collider(mi, size)
	return mi


func _collider(on: Node3D, size: Vector3, offset: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = offset
	body.add_child(cs)
	on.add_child(body)
	return body


## Invisible wall (keeps the player inside open areas).
func blocker(size: Vector3, pos: Vector3, parent: Node = null) -> void:
	var n := Node3D.new()
	n.position = pos
	_parent(parent).add_child(n)
	_collider(n, size)


func cyl(top_r: float, bottom_r: float, height: float, pos: Vector3, m: Material, parent: Node = null,
		collide: bool = false, segments: int = 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	_shadow_rule(mi, m)
	_parent(parent).add_child(mi)
	if collide:
		_collider(mi, Vector3(maxf(top_r, bottom_r) * 1.6, height, maxf(top_r, bottom_r) * 1.6))
	return mi


func sphere(r: float, pos: Vector3, m: Material, parent: Node = null, scale_v: Vector3 = Vector3.ONE, segments: int = 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segments
	sm.rings = maxi(segments / 2, 6)
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = scale_v
	_shadow_rule(mi, m)
	_parent(parent).add_child(mi)
	return mi


func torus(inner: float, outer: float, pos: Vector3, m: Material, parent: Node = null, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 32
	tm.ring_segments = 12
	mi.mesh = tm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	_parent(parent).add_child(mi)
	return mi


## Upright quad facing +z (turned by rot_y).
func quad(size: Vector2, pos: Vector3, m: Material, parent: Node = null, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parent(parent).add_child(mi)
	return mi


## Flat quad lying on the floor (decals: rugs, prints, puddles).
func decal_quad(size: Vector2, pos: Vector3, m: Material, parent: Node = null, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := quad(size, pos, m, parent, 0.0)
	mi.rotation = Vector3(-PI / 2.0, rot_y, 0.0)
	mi.rotation_order = EULER_ORDER_YXZ
	return mi


func prism(size: Vector3, pos: Vector3, m: Material, parent: Node = null, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	_parent(parent).add_child(mi)
	return mi


func omni(pos: Vector3, color: Color, energy: float, light_range: float, shadows: bool = false, parent: Node = null) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadows
	if shadows:
		l.shadow_bias = 0.06
		l.shadow_blur = 1.5
	_parent(parent).add_child(l)
	return l


func spot(pos: Vector3, target: Vector3, color: Color, energy: float, light_range: float, angle: float = 35.0,
		shadows: bool = true) -> SpotLight3D:
	var l := SpotLight3D.new()
	root.add_child(l)
	l.position = pos
	l.look_at_from_position(pos, target, Vector3.UP if absf((target - pos).normalized().y) < 0.99 else Vector3.FORWARD)
	l.light_color = color
	l.light_energy = energy
	l.spot_range = light_range
	l.spot_angle = angle
	l.shadow_enabled = shadows
	return l


func label(text: String, pos: Vector3, rot_y: float = 0.0, size: int = 48, color: Color = Style.GOLD,
		parent: Node = null, px: float = 0.004, outline: int = 10) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Style.display_font()
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(Style.BG_DARK, 0.95)
	l.position = pos
	l.rotation.y = rot_y
	l.double_sided = false
	_parent(parent).add_child(l)
	return l


## Picture of a region of a 2D background (as drawn in the 2D game), framed on a wall.
## rect is in 1280x720 background space.
func bg_crop(bg_id: String, rect: Rect2, size: Vector2, pos: Vector3, rot_y: float = 0.0, parent: Node = null,
		shaded: bool = true) -> MeshInstance3D:
	var tex := crop_texture(bg_id, rect)
	if tex == null:
		return null
	var m := tex_mat(tex, not shaded, false)
	return quad(size, pos, m, parent, rot_y)


static func crop_texture(bg_id: String, rect: Rect2) -> Texture2D:
	var key := "%s:%s" % [bg_id, rect]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := bg_image(bg_id)
	if img == null:
		return null
	var s := float(img.get_width()) / 1280.0
	var r := Rect2i(int(rect.position.x * s), int(rect.position.y * s), int(rect.size.x * s), int(rect.size.y * s))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x <= 0 or r.size.y <= 0:
		return null
	var sub := img.get_region(r)
	sub.generate_mipmaps()
	var t := ImageTexture.create_from_image(sub)
	_tex_cache[key] = t
	return t


static var _bg_imgs := {}


static func bg_image(bg_id: String) -> Image:
	if _bg_imgs.has(bg_id):
		return _bg_imgs[bg_id]
	var path := "res://art/bg/%s.svg" % bg_id
	var img: Image = null
	if FileAccess.file_exists(path):
		var im := Image.new()
		if im.load_svg_from_string(FileAccess.get_file_as_string(path), 1.5) == OK and im.get_width() > 0:
			img = im
	_bg_imgs[bg_id] = img
	return img


static func clear_cache() -> void:
	_tex_cache.clear()
	_bg_imgs.clear()


## Small texture from an inline SVG string (markers, icons).
static func svg_tex(key: String, svg: String, scale_f: float = 1.0) -> Texture2D:
	if _tex_cache.has("svg:" + key):
		return _tex_cache["svg:" + key]
	var img := Image.new()
	var t: Texture2D = null
	if img.load_svg_from_string(svg, scale_f) == OK:
		img.generate_mipmaps()
		t = ImageTexture.create_from_image(img)
	_tex_cache["svg:" + key] = t
	return t


# =================================================================== room shell
## Floor, ceiling and four walls with a wainscot + trims. opts:
##   floor: Material, wall: Material, wain: Material (lower wall, null = none), wain_h, trim: Material,
##   ceiling: Material (null = open sky), beams: bool, walls: Array of "n","s","e","w" (default all)
func shell(w: float, d: float, h: float, opts: Dictionary = {}) -> void:
	bounds = Vector2(w, d)
	var floor_m: Material = opts.get("floor", wood_floor())
	box(Vector3(w, 0.2, d), Vector3(0, -0.1, 0), floor_m, true)
	var ceil_m: Variant = opts.get("ceiling", wood_mid)
	if ceil_m != null:
		box(Vector3(w, 0.12, d), Vector3(0, h + 0.06, 0), ceil_m)
		if bool(opts.get("beams", false)):
			var z := -d / 2.0 + 1.0
			while z < d / 2.0:
				box(Vector3(w, 0.2, 0.2), Vector3(0, h - 0.1, z), wood_dark)
				z += 2.0
	var walls: Array = opts.get("walls", ["n", "s", "e", "w"])
	if "n" in walls:
		wall(Vector3(0, 0, -d / 2.0), 0.0, w, h, opts)
	if "s" in walls:
		wall(Vector3(0, 0, d / 2.0), PI, w, h, opts)
	if "w" in walls:
		wall(Vector3(-w / 2.0, 0, 0), PI / 2.0, d, h, opts)
	if "e" in walls:
		wall(Vector3(w / 2.0, 0, 0), -PI / 2.0, d, h, opts)
	spawn = Vector3(0, 0, d / 2.0 - 1.3)
	look = Vector3(0, 1.25, -d / 2.0)


## One wall; its inner face points towards the room centre (local +z).
func wall(base: Vector3, rot_y: float, length: float, h: float, opts: Dictionary = {}) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = base
	pivot.rotation.y = rot_y
	root.add_child(pivot)
	var wall_m: Material = opts.get("wall", plaster)
	box(Vector3(length, h, 0.2), Vector3(0, h / 2.0, -0.1), wall_m, true, pivot)
	var wain: Variant = opts.get("wain", wood_mid)
	var trim: Material = opts.get("trim", wood_dark)
	if wain != null:
		var wh: float = opts.get("wain_h", 1.0)
		box(Vector3(length, wh, 0.04), Vector3(0, wh / 2.0, 0.02), wain, false, pivot)
		box(Vector3(length, 0.07, 0.07), Vector3(0, wh + 0.02, 0.035), trim, false, pivot)
	box(Vector3(length, 0.12, 0.06), Vector3(0, 0.06, 0.05), trim, false, pivot)
	if bool(opts.get("top_trim", true)):
		box(Vector3(length, 0.1, 0.08), Vector3(0, h - 0.05, 0.04), trim, false, pivot)
	return pivot


# =================================================================== environment
## kind: "indoor" (warm), "dim", "outdoor_morning", "outdoor_dusk", "cave", "steam"
func environment(kind: String, ambient: Color = Color(0.55, 0.46, 0.4), ambient_e: float = 0.25) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_e
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.12, 0.1)
	env.fog_density = 0.012
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.04
	env.adjustment_contrast = 1.04
	match kind:
		"dim":
			env.tonemap_exposure = 1.0
			env.fog_light_color = Color(0.06, 0.05, 0.09)
			env.fog_density = 0.02
		"outdoor_morning", "outdoor_dusk", "outdoor_night":
			var sky := Sky.new()
			var sm := ProceduralSkyMaterial.new()
			if kind == "outdoor_morning":
				sm.sky_top_color = Color(0.42, 0.62, 0.86)
				sm.sky_horizon_color = Color(0.86, 0.88, 0.9)
				sm.ground_horizon_color = Color(0.7, 0.72, 0.7)
				sm.ground_bottom_color = Color(0.3, 0.32, 0.3)
				env.fog_light_color = Color(0.78, 0.82, 0.86)
				env.fog_density = 0.006
			elif kind == "outdoor_dusk":
				sm.sky_top_color = Color(0.32, 0.36, 0.66)
				sm.sky_horizon_color = Color(1.0, 0.66, 0.42)
				sm.ground_horizon_color = Color(0.7, 0.5, 0.38)
				sm.ground_bottom_color = Color(0.2, 0.14, 0.12)
				sm.sun_angle_max = 30.0
				env.fog_light_color = Color(0.9, 0.62, 0.45)
				env.fog_density = 0.005
			else:
				sm.sky_top_color = Color(0.03, 0.03, 0.1)
				sm.sky_horizon_color = Color(0.12, 0.1, 0.24)
				sm.ground_horizon_color = Color(0.08, 0.07, 0.12)
				sm.ground_bottom_color = Color(0.02, 0.02, 0.04)
				env.fog_light_color = Color(0.1, 0.09, 0.2)
				env.fog_density = 0.01
			sky.sky_material = sm
			env.background_mode = Environment.BG_SKY
			env.sky = sky
		"cave":
			env.background_color = Color(0.008, 0.02, 0.03)
			env.fog_light_color = Color(0.04, 0.17, 0.19)
			env.fog_density = 0.028
			env.glow_intensity = 1.0
			env.glow_bloom = 0.08
		"steam":
			env.fog_light_color = Color(0.5, 0.36, 0.26)
			env.fog_density = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	return env


func sun(dir_deg: Vector3, color: Color, energy: float, shadows: bool = true) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = dir_deg
	l.light_color = color
	l.light_energy = energy
	l.shadow_enabled = shadows
	l.directional_shadow_max_distance = 40.0
	root.add_child(l)
	return l


# =================================================================== interactive anchors
## An examinable object. Returns a group node at `pos` (rotated by rot_y): build the object's meshes
## as children of it in local coordinates. `size`/`offset` describe the (generous) interaction box.
func hotspot(id: String, pos: Vector3, size: Vector3, offset: Vector3 = Vector3.ZERO, rot_y: float = 0.0) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var body := _interact_body(g, size, offset if offset != Vector3.ZERO else Vector3(0, size.y / 2.0, 0))
	var c := offset if offset != Vector3.ZERO else Vector3(0, size.y / 2.0, 0)
	hot[id] = {"node": g, "body": body, "top": pos + g.basis * (c + Vector3(0, size.y / 2.0 + 0.22, 0))}
	return g


func _interact_body(on: Node3D, size: Vector3, offset: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_INTERACT
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = offset
	body.add_child(cs)
	on.add_child(body)
	return body


## Where a character from the room data stands (floor position).
func person(char_id: String, pos: Vector3) -> void:
	people[char_id] = pos


## A door to another room (travel). Builds a door with a destination sign above it.
func door(to_rid: String, title: String, pos: Vector3, rot_y: float, style: Dictionary = {}) -> Node3D:
	if title == "":
		title = str(names.get(to_rid, to_rid.capitalize()))
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var dw: float = style.get("w", 1.0)
	var dh: float = style.get("h", 2.1)
	var dm: Material = style.get("mat", wood_mid)
	var fm: Material = style.get("frame", wood_dark)
	box(Vector3(dw + 0.22, dh + 0.12, 0.08), Vector3(0, (dh + 0.12) / 2.0, 0.02), fm, false, g)
	var slab := box(Vector3(dw, dh, 0.06), Vector3(0, dh / 2.0, 0.07), dm, false, g)
	if bool(style.get("panels", true)):
		for yy in [dh * 0.27, dh * 0.7]:
			box(Vector3(dw * 0.72, dh * 0.3, 0.02), Vector3(0, yy, 0.11), fm, false, g)
	if bool(style.get("porthole", false)):
		torus(0.13, 0.17, Vector3(0, dh * 0.72, 0.12), brass, g, Vector3(PI / 2.0, 0, 0))
		cyl(0.13, 0.13, 0.01, Vector3(0, dh * 0.72, 0.11), glow(Color(1.0, 0.85, 0.6), 0.8), g).rotation.x = PI / 2.0
	sphere(0.045, Vector3(dw * 0.38, dh * 0.47, 0.13), brass, g)
	# destination sign
	var sign_y := dh + 0.38
	box(Vector3(maxf(1.3, title.length() * 0.105 + 0.3), 0.3, 0.04), Vector3(0, sign_y, 0.04), mat(Style.BG_DARK.lightened(0.05), 0.6), false, g)
	box(Vector3(maxf(1.3, title.length() * 0.105 + 0.3) + 0.06, 0.34, 0.02), Vector3(0, sign_y, 0.025), glow(Style.AQUA_DEEP, 1.2), false, g)
	label(title.to_upper(), Vector3(0, sign_y, 0.07), 0.0, 40, Style.GOLD, g, 0.0035, 8)
	# glowing threshold strip so exits read from across the room
	box(Vector3(dw, 0.02, 0.12), Vector3(0, 0.01, 0.2), glow(Style.AQUA, 1.6), false, g)
	var body := _interact_body(g, Vector3(dw + 0.4, dh + 0.3, 0.7), Vector3(0, (dh + 0.3) / 2.0, 0.3))
	_collider(g, Vector3(dw + 0.3, dh, 0.3), Vector3(0, dh / 2.0, 0.05))
	doors[to_rid] = {"node": g, "body": body, "pos": pos, "rot": rot_y, "slab": slab,
		"top": pos + Vector3(0, dh + 0.7, 0)}
	return g


## Lets an examinable door double as an exit once it has been examined (e.g. Cabin 2 -> Tumble's cabin).
func link_door(hot_id: String, to_rid: String) -> void:
	var a: Dictionary = hot.get(hot_id, {})
	if a.is_empty():
		return
	var g: Node3D = a["node"]
	doors[to_rid] = {"node": g, "body": null, "pos": g.position, "rot": g.rotation.y, "top": a["top"], "link": hot_id}


# =================================================================== characters
## Full-body art (art/chars_full, tools/gen_chars_full.py): 640x920 canvas, feet on the line y = FULL_BASE.
## One art pixel is the same world size as in the bust standee (1.4 m / 600 px), so faces keep their size.
const FULL_SIZE := Vector2(640.0, 920.0)
const FULL_BASE := 916.0
const FULL_M_PER_PX := 1.4 / 600.0
## Canvas y of the top of each character (hat included): sets the marker height and the blob shadow.
const FULL_TOP := {
	"bramble": 221, "bruno": 114, "coco": 145, "duchess": 149, "fennel": 159, "grub": 155, "lulu": 274, "marigold": 253,
	"mochi": 210, "nibs": 194, "pepper": 245, "reginald": 139, "snapjaw": 24, "tumble": 371, "wisp": 131, "zuzu": 251,
}


## Billboard standee for a character. Uses the full-body art standing on the floor; a character without
## full-body art falls back to the floating bust portrait. Returns {holder, mesh, mat, body, top, base}.
func standee(char_id: String, expr: String, pos: Vector3, height: float = 1.4, base_y: float = 0.36) -> Dictionary:
	var holder := Node3D.new()
	holder.position = Vector3(pos.x, pos.y, pos.z)
	root.add_child(holder)
	var full: Texture2D = Assets.portrait_full(char_id, expr)
	var q := QuadMesh.new()
	var m: ShaderMaterial
	var w: float
	var top_h: float
	var blob_w: float
	var mi := MeshInstance3D.new()
	if full != null:
		q.size = FULL_SIZE * FULL_M_PER_PX
		q.center_offset = Vector3(0.0, q.size.y / 2.0, 0.0)     # pivot at the feet, so breathing keeps them planted
		m = smat(SH_STANDEE, {"portrait": full, "fade": 0.001, "outline_w": 0.0078})
		mi.position.y = -(FULL_SIZE.y - FULL_BASE) * FULL_M_PER_PX
		top_h = (FULL_BASE - float(FULL_TOP.get(char_id, 150))) * FULL_M_PER_PX
		blob_w = maxf(0.75, top_h * 0.58)
		w = q.size.x
	else:
		w = height * 0.8
		q.size = Vector2(w, height)
		m = smat(SH_STANDEE, {"portrait": Assets.portrait(char_id, expr)})
		mi.position.y = base_y + height / 2.0
		top_h = base_y + height
		blob_w = w * 0.95
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	holder.add_child(mi)
	var blob := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(blob_w, blob_w * 0.74)
	blob.mesh = bq
	blob.material_override = smat(SH_BLOB, {"strength": 0.55})
	blob.rotation.x = -PI / 2.0
	blob.position.y = 0.02
	holder.add_child(blob)
	var hit_h := maxf(1.2, top_h)
	var body := _interact_body(holder, Vector3(0.75, hit_h, 0.75), Vector3(0, hit_h / 2.0, 0))
	_collider(holder, Vector3(0.5, 1.6, 0.5), Vector3(0, 0.8, 0))
	return {"holder": holder, "mesh": mi, "mat": m, "body": body,
		"top": holder.position + Vector3(0, top_h + 0.18, 0), "base": mi.position.y}


# =================================================================== stock props
func paper_lantern(pos: Vector3, col: Color = Color(1.0, 0.86, 0.64), s: float = 1.0, light: bool = true,
		shadows: bool = false, energy: float = 1.0, cord_to: float = -1.0) -> void:
	var h := 0.62 * s
	var body := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.27 * s
	sph.height = h
	body.mesh = sph
	body.material_override = smat(SH_LANTERN, {"paper": col})
	body.position = pos
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	cyl(0.12 * s, 0.12 * s, 0.05 * s, pos + Vector3(0, h / 2.0, 0), wood_dark)
	cyl(0.12 * s, 0.12 * s, 0.05 * s, pos + Vector3(0, -h / 2.0, 0), wood_dark)
	if cord_to > pos.y + h / 2.0:
		var cord := cord_to - (pos.y + h / 2.0)
		cyl(0.008, 0.008, cord, pos + Vector3(0, h / 2.0 + cord / 2.0, 0), wood_dark)
	if light:
		omni(pos + Vector3(0, -0.05, 0), Color(col.r, col.g * 0.92, col.b * 0.86), 1.0 * energy, 6.0 * s, shadows)


## Japanese stone lantern (ishidoro).
func stone_lantern(pos: Vector3, s: float = 1.0, lit: bool = true, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	_parent(parent).add_child(g)
	var st := stone
	cyl(0.3 * s, 0.36 * s, 0.14 * s, Vector3(0, 0.07 * s, 0), st, g, false, 6)
	cyl(0.1 * s, 0.13 * s, 0.6 * s, Vector3(0, 0.44 * s, 0), st, g, false, 8)
	cyl(0.24 * s, 0.2 * s, 0.1 * s, Vector3(0, 0.79 * s, 0), st, g, false, 6)
	box(Vector3(0.3, 0.3, 0.3) * s, Vector3(0, 0.99 * s, 0), st, false, g)
	if lit:
		var gm := glow(Color(1.0, 0.8, 0.5), 3.0)
		box(Vector3(0.2 * s, 0.17 * s, 0.32 * s), Vector3(0, 0.99 * s, 0), gm, false, g)
		box(Vector3(0.32 * s, 0.17 * s, 0.2 * s), Vector3(0, 0.99 * s, 0), gm, false, g)
		omni(Vector3(0, 0.99 * s, 0), Color(1.0, 0.78, 0.5), 0.7, 3.5 * s, false, g)
	cyl(0.04 * s, 0.42 * s, 0.24 * s, Vector3(0, 1.26 * s, 0), st, g, false, 6)
	sphere(0.07 * s, Vector3(0, 1.42 * s, 0), st, g)
	_collider(g, Vector3(0.6, 1.4, 0.6) * s, Vector3(0, 0.7 * s, 0))
	return g


func wall_lamp(pos: Vector3, rot_y: float, col: Color = Color(1.0, 0.8, 0.55), energy: float = 0.8, rng: float = 4.5,
		shadows: bool = false) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	box(Vector3(0.14, 0.22, 0.04), Vector3(0, 0, 0.02), brass, false, g)
	cyl(0.015, 0.015, 0.18, Vector3(0, 0, 0.1), brass, g).rotation.x = PI / 2.0
	cyl(0.07, 0.1, 0.2, Vector3(0, 0.06, 0.2), glow(col, 2.5), g)
	cyl(0.08, 0.08, 0.02, Vector3(0, 0.17, 0.2), brass, g)
	omni(g.position + g.basis * Vector3(0, 0.05, 0.35), col, energy, rng, shadows)


func hanging_lamp(pos: Vector3, col: Color = Color(1.0, 0.82, 0.58), energy: float = 1.2, ceiling: float = 3.2,
		shadows: bool = true, rng: float = 7.0) -> void:
	cyl(0.01, 0.01, ceiling - pos.y, Vector3(pos.x, (ceiling + pos.y) / 2.0, pos.z), black).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cyl(0.06, 0.32, 0.2, pos, brass).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cyl(0.1, 0.1, 0.06, pos + Vector3(0, -0.11, 0), glow(col, 3.0))
	omni(pos + Vector3(0, -0.25, 0), col, energy, rng, shadows)


func plant(pos: Vector3, s: float = 1.0) -> void:
	cyl(0.26 * s, 0.2 * s, 0.5 * s, pos + Vector3(0, 0.25 * s, 0), mat(Color(0.32, 0.18, 0.1), 0.8))
	cyl(0.23 * s, 0.23 * s, 0.02, pos + Vector3(0, 0.49 * s, 0), mat(Color(0.12, 0.08, 0.05), 1.0))
	var leaf := mat(Color(0.24, 0.46, 0.2), 0.7)
	var n := 13
	for i in n:
		var pivot := Node3D.new()
		pivot.position = pos + Vector3(0, 0.48 * s, 0)
		pivot.rotation_order = EULER_ORDER_YXZ
		pivot.rotation = Vector3(0.45 + 0.45 * float(i % 3) / 2.0, i * TAU / n + 0.3 * float(i % 2), 0)
		root.add_child(pivot)
		box(Vector3(0.07, 0.75 + 0.1 * float(i % 4), 0.012) * s, Vector3(0, 0.38 * s, 0), leaf, false, pivot)
	blocker(Vector3(0.5, 1.0, 0.5) * s, pos + Vector3(0, 0.5 * s, 0))


func table(pos: Vector3, size: Vector3, top_m: Material = null, leg_m: Material = null, rot_y: float = 0.0,
		parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	var tm: Material = top_m if top_m != null else wood_light
	var lm: Material = leg_m if leg_m != null else wood_dark
	box(Vector3(size.x, 0.06, size.z), Vector3(0, size.y - 0.03, 0), tm, false, g)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(Vector3(0.06, size.y - 0.06, 0.06), Vector3(sx * (size.x / 2.0 - 0.08), (size.y - 0.06) / 2.0, sz * (size.z / 2.0 - 0.08)), lm, false, g)
	_collider(g, Vector3(size.x, size.y, size.z), Vector3(0, size.y / 2.0, 0))
	return g


func chair(pos: Vector3, rot_y: float, seat_m: Material = null, frame_m: Material = null, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	var sm: Material = seat_m if seat_m != null else mat(Color(0.5, 0.1, 0.12), 0.85)
	var fm: Material = frame_m if frame_m != null else wood_dark
	box(Vector3(0.46, 0.08, 0.46), Vector3(0, 0.46, 0), sm, false, g)
	box(Vector3(0.46, 0.55, 0.07), Vector3(0, 0.78, -0.2), sm, false, g)
	for sx in [-0.19, 0.19]:
		for sz in [-0.19, 0.19]:
			box(Vector3(0.04, 0.44, 0.04), Vector3(sx, 0.22, sz), fm, false, g)
	_collider(g, Vector3(0.5, 0.9, 0.5), Vector3(0, 0.45, 0))
	return g


func bucket(pos: Vector3, s: float = 1.0, parent: Node = null, m: Material = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	_parent(parent).add_child(g)
	cyl(0.17 * s, 0.14 * s, 0.26 * s, Vector3(0, 0.13 * s, 0), m if m != null else wood_light, g)
	for yy in [0.05, 0.2]:
		cyl(0.17 * s * (0.88 + yy * 0.5), 0.17 * s * (0.88 + yy * 0.5), 0.02 * s, Vector3(0, yy * s, 0), steel, g)
	cyl(0.15 * s, 0.15 * s, 0.01, Vector3(0, 0.25 * s, 0), wood_dark, g)
	return g


func crate(pos: Vector3, size: Vector3, rot_y: float = 0.0, m: Material = null, collide: bool = true, parent: Node = null) -> MeshInstance3D:
	var c := box(size, pos + Vector3(0, size.y / 2.0, 0), m if m != null else wood_light, collide, parent, rot_y)
	var b := box(size * Vector3(1.02, 0.12, 1.02), Vector3(0, size.y * 0.32, 0), wood_dark, false, c)
	b.position.y = size.y * 0.32
	box(size * Vector3(1.02, 0.12, 1.02), Vector3(0, -size.y * 0.32, 0), wood_dark, false, c)
	return c


## Snapjaw security camera (a sinister touch in every room).
func cctv(pos: Vector3, rot_y: float, tilt: float = -0.35) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	box(Vector3(0.12, 0.12, 0.05), Vector3(0, 0, 0.02), black, false, g)
	var head := Node3D.new()
	head.position = Vector3(0, -0.06, 0.18)
	head.rotation.x = tilt
	g.add_child(head)
	box(Vector3(0.16, 0.14, 0.34), Vector3.ZERO, mat(Color(0.12, 0.13, 0.12), 0.4, 0.4), false, head)
	box(Vector3(0.2, 0.02, 0.38), Vector3(0, 0.08, 0), mat(Color(0.2, 0.42, 0.22), 0.5), false, head)
	cyl(0.05, 0.05, 0.03, Vector3(0, 0, 0.18), mat(Color(0.02, 0.02, 0.03), 0.1, 0.6), head).rotation.x = PI / 2.0
	sphere(0.018, Vector3(0.05, 0.04, 0.17), glow(Color(1.0, 0.08, 0.06), 6.0), head)


func porthole(pos: Vector3, rot_y: float, r: float = 0.24, glass: Color = Color(0.2, 0.85, 0.8), energy: float = 1.4) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	torus(r, r + 0.07, Vector3(0, 0, 0.03), brass, g, Vector3(PI / 2.0, 0, 0))
	var gl := cyl(r, r, 0.01, Vector3(0, 0, 0.02), glow(glass, energy), g)
	gl.rotation.x = PI / 2.0
	for i in 6:
		var a := i * TAU / 6.0
		sphere(0.018, Vector3(cos(a), sin(a), 0) * (r + 0.035) + Vector3(0, 0, 0.07), brass, g)
	return g


func shoji(size: Vector2, pos: Vector3, rot_y: float, col: Color = Color(1.0, 0.88, 0.66), energy: float = 1.4,
		cells: Vector2 = Vector2(4, 3), light: bool = true) -> void:
	quad(size, pos, smat(SH_SHOJI, {"glow_col": col, "energy": energy, "cells": cells}), null, rot_y)
	if light:
		var b := Basis(Vector3.UP, rot_y)
		omni(pos + b * Vector3(0, 0, 0.8), col, 0.45, maxf(size.x, size.y) * 1.3)


func rug(pos: Vector3, size: Vector2, col: Color, border: Color, rot_y: float = 0.0) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	box(Vector3(size.x, 0.012, size.y), Vector3(0, 0.006, 0), mat(border, 0.95), false, g)
	box(Vector3(size.x - 0.16, 0.016, size.y - 0.16), Vector3(0, 0.008, 0), mat(col, 0.95), false, g)


## Cartoon steam puffs rising (hot springs, kettles, stoves).
func steam(pos: Vector3, extent: Vector3, amount: int = 24, size: float = 0.8, alpha: float = 0.16,
		rise: float = 0.5, life: float = 3.5) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extent
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, rise * 0.3, 0)
	p.initial_velocity_min = rise * 0.5
	p.initial_velocity_max = rise
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, alpha), Color(1, 1, 1, 0)])
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = puff_texture()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = m
	p.mesh = q
	root.add_child(p)
	return p


static func puff_texture() -> Texture2D:
	if _tex_cache.has("puff"):
		return _tex_cache["puff"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_tex_cache["puff"] = gt
	return gt


## Rounded boulder (stretched low-poly sphere).
func rock(pos: Vector3, s: Vector3, m: Material, rot_y: float = 0.0, collide: bool = true) -> MeshInstance3D:
	var r := sphere(0.5, pos, m, null, s, 10)
	r.rotation.y = rot_y
	if collide:
		blocker(Vector3(s.x, s.y, s.z) * 0.9, pos)
	return r


## A row of small paper lanterns hanging along a sagging line between a and b.
func lantern_string(a: Vector3, b: Vector3, count: int, cols: Array, sag: float = 0.5, lights_every: int = 3) -> void:
	var segs := 16
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		var mid := (prev + p) * 0.5
		var cm := cyl(0.006, 0.006, prev.distance_to(p), mid, black)
		cm.look_at_from_position(mid, p, Vector3.UP if absf((p - prev).normalized().y) < 0.99 else Vector3.FORWARD)
		cm.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		prev = p
	for i in count:
		var t := (i + 0.5) / count
		var p := a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t) - 0.2, 0)
		var col: Color = cols[i % cols.size()]
		paper_lantern(p, col, 0.55, i % lights_every == 1, false, 0.7)
