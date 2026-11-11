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

## Doors are at least this big, because the tallest guests are over 1.8 m and one is 2.08 m. tools/roomaudit.gd enforces it.
const DOOR_W := 1.0
const DOOR_H := 2.1
## Anything laid flat against something else steps out by a multiple of this, so no two visible faces share a plane.
const LAYER := 0.004

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
var mode := "investigate"     # "investigate" or "freetime": some spaces are lit / furnished differently
var lifts := {}               # lift id -> {node, body, pos, rot, to, to_space, label, door_l, door_r, sign}
var notes: Array = []         # small things to look at: {node, body, top, label, text}
var stairs_list: Array = []   # {bottom, top, width}: used by the walk test
var cramped := ""             # a story reason this space is narrow on purpose (the room audit then allows 0.8 m walkways)

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
uniform float aspect = 1.33;
// soft shadows of bamboo and leaves falling on the paper from outside (0 = none)
uniform float shade = 0.34;
uniform float seed = 1.0;
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float silhouettes(vec2 uv) {
	float s = 0.0;
	vec2 p = vec2(uv.x * aspect, uv.y);
	for (int i = 0; i < 4; i++) {
		float fi = float(i) + seed * 3.7;
		float x = hash(fi) * aspect;
		float lean = (hash(fi + 2.0) - 0.5) * 0.22;
		float w = 0.008 + 0.012 * hash(fi + 5.0);
		float line = 1.0 - smoothstep(w, w + 0.016, abs(p.x - x - lean * (1.0 - p.y)));
		s = max(s, line);
		for (int j = 0; j < 7; j++) {
			float fj = fi * 7.0 + float(j);
			vec2 c = vec2(x + lean * (1.0 - hash(fj)) + (hash(fj + 1.0) - 0.5) * 0.34, hash(fj + 2.0) * 0.62);
			vec2 d = p - c;
			float a = hash(fj + 3.0) * 3.14;
			vec2 q = vec2(d.x * cos(a) + d.y * sin(a), -d.x * sin(a) + d.y * cos(a));
			s = max(s, 1.0 - smoothstep(0.75, 1.15, length(q / vec2(0.075, 0.018))));
		}
	}
	return s;
}
void fragment() {
	vec2 g = abs(fract(UV * cells) - 0.5) * 2.0;
	float bar = max(smoothstep(0.88, 0.95, g.x), smoothstep(0.86, 0.94, g.y));
	vec2 edge = min(UV, 1.0 - UV);
	bar = max(bar, 1.0 - smoothstep(0.0, 0.03, min(edge.x, edge.y)));
	float grad = 0.75 + 0.25 * (1.0 - UV.y);
	float sil = shade > 0.001 ? silhouettes(UV) : 0.0;
	ALBEDO = mix(glow_col * 0.5, frame_col, bar);
	EMISSION = glow_col * energy * grad * (1.0 - bar) * (1.0 - sil * shade);
	ROUGHNESS = 0.9;
}
"""

const SH_MIRROR := """shader_type spatial;
// A mirror without the cost of a real reflection: silvered glass that catches the room's colours and a soft sheen.
render_mode unshaded;
uniform vec3 top : source_color = vec3(0.74, 0.8, 0.82);
uniform vec3 bottom : source_color = vec3(0.5, 0.45, 0.4);
uniform bool oval = false;
void fragment() {
	vec2 c = UV - 0.5;
	if (oval && dot(c, c) > 0.25) { discard; }
	float d = fract(UV.x * 0.8 + UV.y * 1.1);
	float sheen = smoothstep(0.1, 0.0, abs(d - 0.32)) + 0.5 * smoothstep(0.05, 0.0, abs(d - 0.5));
	float v = 1.0 - smoothstep(0.32, 0.5, length(c));
	ALBEDO = (mix(top, bottom, smoothstep(0.1, 0.95, UV.y)) + vec3(0.16) * sheen) * mix(0.82, 1.0, v);
}
"""

const SH_PUDDLE := """shader_type spatial;
// A shallow film of water on the floor: mostly see-through, with a bright wet sheen and an uneven edge.
render_mode depth_draw_never, cull_disabled, shadows_disabled;
uniform float seed = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 c = UV - 0.5;
	float n = noise(UV * 5.0 + seed) * 0.16 + noise(UV * 13.0 + seed * 3.0) * 0.05;
	float m = 1.0 - smoothstep(0.26 + n, 0.31 + n, length(c));
	ALBEDO = vec3(0.07, 0.09, 0.1);
	ROUGHNESS = 0.03;
	METALLIC = 0.0;
	SPECULAR = 1.0;
	ALPHA = m * 0.46;
}
"""

const SH_PORTVIEW := """shader_type spatial;
// The view through a porthole: the cave outside, black water, a line of rock and fungus glowing on it.
render_mode unshaded;
uniform vec3 glow_col : source_color = vec3(0.25, 0.95, 0.85);
uniform float radius = 0.2;
uniform float energy = 1.2;
uniform float seed = 1.0;
varying vec3 lp;
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 p = vec2(lp.x, -lp.z) / radius;
	float h = -0.18 + 0.05 * sin(p.x * 3.0 + seed);
	vec3 c = mix(vec3(0.03, 0.12, 0.14), vec3(0.06, 0.26, 0.29), smoothstep(h, 0.95, p.y));
	float rock = 0.34 + 0.2 * sin(p.x * 2.3 + seed * 2.0) + 0.1 * sin(p.x * 7.1 + seed);
	c = mix(c, vec3(0.012, 0.05, 0.06), 1.0 - smoothstep(rock - 0.03, rock + 0.03, p.y));
	float glow = 0.0;
	for (int i = 0; i < 8; i++) {
		float fi = float(i) + seed * 4.1;
		vec2 q = vec2(hash(fi) * 1.8 - 0.9, h + 0.06 + hash(fi + 3.0) * 0.5);
		float d = length(p - q);
		float tw = 0.75 + 0.25 * sin(TIME * (0.6 + hash(fi + 1.0)) + fi);
		glow += (1.0 - smoothstep(0.03, 0.05, d)) * tw + 0.5 * exp(-d * d * 42.0) * tw;
	}
	if (p.y < h) {
		c = mix(vec3(0.005, 0.03, 0.04), vec3(0.03, 0.13, 0.14), 0.5 + 0.5 * sin((p.y + TIME * 0.02) * 90.0 + sin(p.x * 11.0) * 2.0));
		c += glow_col * glow * 0.2;
	} else {
		c += glow_col * glow;
	}
	ALBEDO = c * energy;
}
"""

const SH_SKYVIEW := """shader_type spatial;
// A painted distance for glimpses of the outdoors through an open door: sky, hazy hills and a tree line.
render_mode unshaded, cull_disabled;
uniform vec3 sky_top : source_color = vec3(0.58, 0.76, 0.92);
uniform vec3 sky_low : source_color = vec3(0.92, 0.93, 0.86);
uniform vec3 hill : source_color = vec3(0.56, 0.68, 0.66);
uniform vec3 trees : source_color = vec3(0.26, 0.42, 0.26);
uniform float horizon = 0.68;
float wave(float x, float a, float b) { return sin(x * a) * 0.5 + sin(x * b + 1.7) * 0.5; }
void fragment() {
	float x = UV.x * 6.28;
	float y = 1.0 - UV.y;
	vec3 c = mix(sky_low, sky_top, smoothstep(0.25, 0.95, y));
	float line = 1.0 - horizon + 0.14 + 0.05 * wave(x, 2.0, 5.0);
	c = mix(c, hill, 1.0 - smoothstep(line - 0.004, line + 0.004, y));
	float near_line = 1.0 - horizon + 0.05 + 0.025 * wave(x, 9.0, 23.0);
	c = mix(c, trees, 1.0 - smoothstep(near_line - 0.004, near_line + 0.004, y));
	ALBEDO = c;
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
	ALBEDO = color.rgb * (0.03 + f * f * 0.6) * pulse;
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


## Marks a mesh as part of the building ("floor", "wall" or "ceiling"), which the room audit treats differently from props.
static func arch(mi: MeshInstance3D, kind: String) -> MeshInstance3D:
	mi.set_meta("arch", kind)
	return mi


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
	arch(box(Vector3(w, 0.2, d), Vector3(0, -0.1, 0), floor_m, true), "floor")
	var ceil_m: Variant = opts.get("ceiling", wood_mid)
	if ceil_m != null:
		arch(box(Vector3(w, 0.12, d), Vector3(0, h + 0.06, 0), ceil_m), "ceiling")
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
	arch(box(Vector3(length, h, 0.2), Vector3(0, h / 2.0, -0.1), wall_m, true, pivot), "wall")
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


## A door to another space (travel). Builds a door with a destination sign above it; it swings open when used.
func door(to_rid: String, title: String, pos: Vector3, rot_y: float, style: Dictionary = {}) -> Node3D:
	if title == "":
		title = str(names.get(to_rid, to_rid.capitalize()))
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var dw: float = style.get("w", DOOR_W)
	var dh: float = style.get("h", DOOR_H)
	var dm: Material = style.get("mat", wood_mid)
	var fm: Material = style.get("frame", wood_dark)
	# hidden: a jib door that looks like the wall round it (no sign, no sill); open: a real opening (the builder cuts
	# the wall and puts something behind it) with the leaf standing open; broken: open, the leaf hanging off one hinge
	var hidden: bool = style.get("hidden", false)
	var broken: bool = style.get("broken", false)
	var open_view: bool = broken or bool(style.get("open", false))
	if open_view:
		for sd in [-1.0, 1.0]:
			box(Vector3(0.11, dh + 0.12, 0.12), Vector3(sd * (dw / 2.0 + 0.055), (dh + 0.12) / 2.0, 0.02), fm, false, g)
		box(Vector3(dw + 0.22, 0.12, 0.12), Vector3(0, dh + 0.06, 0.02), fm, false, g)
	elif not hidden:
		box(Vector3(dw + 0.22, dh + 0.12, 0.08), Vector3(0, (dh + 0.12) / 2.0, 0.02), fm, false, g)
		quad(Vector2(dw, dh), Vector3(0, dh / 2.0, 0.065), mat(Color(0.02, 0.015, 0.03), 1.0), g)
	else:
		quad(Vector2(dw, dh), Vector3(0, dh / 2.0, LAYER * 2.0), mat(Color(0.02, 0.015, 0.03), 1.0), g)
	var hinge := Node3D.new()
	hinge.position = Vector3(-dw / 2.0, 0, 0.07 if not hidden else 0.035)
	g.add_child(hinge)
	if open_view:
		# swung into the far side of the opening (swing_in: into this side, flat against the wall); a broken one
		# also sags on its torn hinge
		hinge.position.z = 0.0
		hinge.rotation.y = 1.35 if not broken else 1.15
		if bool(style.get("swing_in", false)):
			hinge.position.z = 0.1
			hinge.rotation.y = -1.5
			_collider(hinge, Vector3(dw, dh, 0.08), Vector3(dw / 2.0, dh / 2.0, -0.03))
		if broken:
			hinge.rotation.z = -0.07
	var slab_m := box(Vector3(dw, dh, 0.06), Vector3(dw / 2.0, dh / 2.0, -0.03 if open_view else 0.0), dm, false, hinge)
	if bool(style.get("panels", not hidden)):
		for yy in [dh * 0.27, dh * 0.7]:
			box(Vector3(dw * 0.72, dh * 0.3, 0.02), Vector3(dw / 2.0, yy, 0.04 if not open_view else 0.01), fm, false, hinge)
	if bool(style.get("porthole", false)):
		torus(0.13, 0.17, Vector3(dw / 2.0, dh * 0.72, 0.05), brass, hinge, Vector3(PI / 2.0, 0, 0))
		cyl(0.13, 0.13, 0.01, Vector3(dw / 2.0, dh * 0.72, 0.054), glow(Color(1.0, 0.85, 0.6), 0.8), hinge).rotation.x = PI / 2.0
	if not hidden:
		sphere(0.045, Vector3(dw * 0.88, dh * 0.47, 0.06 if not open_view else 0.03), brass, hinge)
	else:
		# the only giveaways: a hair-thin shadow line round the leaf and a small brass keyhole
		for sd in [-1.0, 1.0]:
			box(Vector3(0.012, dh, 0.012), Vector3(dw / 2.0 + sd * dw / 2.0, dh / 2.0, 0.026), black, false, hinge)
		box(Vector3(dw, 0.012, 0.012), Vector3(dw / 2.0, dh, 0.026), black, false, hinge)
		cyl(0.012, 0.012, 0.012, Vector3(dw * 0.9, dh * 0.47, 0.034), brass, hinge, false, 8).rotation.x = PI / 2.0
	if broken:
		# the bolt keeper, torn out of the frame with a fist of splinters, lies on the floor
		var keep: Node3D = Node3D.new()
		keep.position = Vector3(dw * 0.38, 0, 0.55)
		keep.rotation.y = 0.6
		g.add_child(keep)
		box(Vector3(0.14, 0.03, 0.05), Vector3(0, 0.015, 0), brass, false, keep)
		for i in 4:
			var sp := box(Vector3(0.018, 0.012, 0.16 + 0.05 * (i % 2)), Vector3(-0.08 + i * 0.05, 0.006 + LAYER * i, 0.06), wood_light, false, keep, 0.4 * (i - 1.5))
			sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box(Vector3(0.05, 0.24, 0.04), Vector3(dw / 2.0 + 0.05, dh * 0.47, 0.1), wood_light, false, g)
	var sign_y := dh + 0.3
	var sign_top := pos.y + sign_y + 0.17
	if bool(style.get("sign", not hidden)):
		# destination sign, bolted to the wall above the frame
		var sw := maxf(1.3, title.length() * 0.105 + 0.3)
		box(Vector3(sw + 0.06, 0.34, 0.03), Vector3(0, sign_y, 0.015), glow(Style.AQUA_DEEP, 1.2), false, g)
		box(Vector3(sw, 0.3, 0.04), Vector3(0, sign_y, 0.04), mat(Style.BG_DARK.lightened(0.05), 0.6), false, g)
		label(title.to_upper(), Vector3(0, sign_y, 0.07), 0.0, 40, Style.GOLD, g, 0.0035, 8)
	else:
		sign_top = pos.y + dh + 0.12
	if not hidden:
		# brass sill with a thin inlaid line: exits still read from across the room without shouting
		box(Vector3(dw + 0.1, LAYER * 3.0, 0.16), Vector3(0, LAYER * 1.5, 0.16), brass, false, g)
		box(Vector3(dw - 0.16, LAYER, 0.024), Vector3(0, LAYER * 3.5, 0.2), glow(Style.AQUA, 0.75), false, g)
	var body := _interact_body(g, Vector3(dw + 0.4, dh + 0.3, 0.7), Vector3(0, (dh + 0.3) / 2.0, 0.3))
	_collider(g, Vector3(dw + 0.3, dh, 0.3 if not hidden else 0.14), Vector3(0, dh / 2.0, 0.05 if not hidden else 0.0))
	g.set_meta("door_part", true)
	doors[to_rid] = {"node": g, "body": body, "pos": pos, "rot": rot_y, "slab": slab_m, "hinge": hinge if not open_view else null,
		"top": pos + Vector3(0, dh + 0.7, 0), "w": dw, "h": dh, "sign_top": sign_top, "hidden": hidden,
		"narrow": str(style.get("narrow", ""))}
	return g


## Lets an examinable door double as an exit once it has been examined (e.g. Cabin 2 -> Tumble's cabin).
func link_door(hot_id: String, to_rid: String) -> void:
	var a: Dictionary = hot.get(hot_id, {})
	if a.is_empty():
		return
	var g: Node3D = a["node"]
	var lf: Vector2 = g.get_meta("leaf", Vector2.ZERO)
	doors[to_rid] = {"node": g, "body": null, "pos": g.position, "rot": g.rotation.y, "top": a["top"], "link": hot_id,
		"w": lf.x, "h": lf.y, "narrow": str(g.get_meta("narrow", ""))}


## Records the size of an examinable door's leaf, so the room audit can hold it to the same standard as other doors.
## `narrow` is the story reason a door is narrower than DOOR_W on purpose (the audit then allows 0.8 m).
func leaf(g: Node3D, w: float = DOOR_W, h: float = DOOR_H, narrow: String = "") -> void:
	g.set_meta("leaf", Vector2(w, h))
	if narrow != "":
		g.set_meta("narrow", narrow)


# =================================================================== floor plans, levels, stairs, lifts
## Flat slab whose top surface is at height y (floors, landings, catwalks).
func slab(x0: float, z0: float, x1: float, z1: float, y: float, m: Material, thick: float = 0.2, collide: bool = true,
		kind: String = "floor") -> MeshInstance3D:
	return arch(box(Vector3(x1 - x0, thick, z1 - z0), Vector3((x0 + x1) / 2.0, y - thick / 2.0, (z0 + z1) / 2.0), m, collide), kind)


## A straight wall from a to b (x, z). Going a -> b the room is on the side that makes walls run clockwise seen from
## above with north (-z) up: north wall west->east, east wall north->south, and so on.
## gaps: [[t0, t1, y0, y1], ...] openings, t = metres from a, y relative to the wall's base.
func wall_run(a: Vector2, b: Vector2, y: float, h: float, opts: Dictionary = {}, gaps: Array = []) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.01:
		return
	var dir := d / length
	var rot := atan2(-dir.y, dir.x)
	var cuts := [0.0, length]
	for g in gaps:
		cuts.append(clampf(float(g[0]), 0.0, length))
		cuts.append(clampf(float(g[1]), 0.0, length))
	cuts.sort()
	var plain := opts.duplicate()
	plain["wain"] = null
	plain["top_trim"] = false
	var under := opts.duplicate()
	under["top_trim"] = false
	for i in cuts.size() - 1:
		var t0: float = cuts[i]
		var t1: float = cuts[i + 1]
		if t1 - t0 < 0.005:
			continue
		var c := a + dir * (t0 + t1) / 2.0
		var here: Array = []
		for g in gaps:
			if float(g[0]) <= t0 + 0.001 and float(g[1]) >= t1 - 0.001:
				here.append(g)
		here.sort_custom(func(p: Array, q: Array) -> bool: return float(p[2]) < float(q[2]))
		var cursor := 0.0
		for g in here:
			if float(g[2]) > cursor + 0.01:
				wall(Vector3(c.x, y + cursor, c.y), rot, t1 - t0, float(g[2]) - cursor, under if cursor == 0.0 else plain)
			cursor = float(g[3])
		if h > cursor + 0.01:
			wall(Vector3(c.x, y + cursor, c.y), rot, t1 - t0, h - cursor, opts if cursor == 0.0 else plain)


## Room of any right-angled shape: cells = [[x0, z0, x1, z1], [x0, z0, x1, z1, height], ...] (L, T, U...).
## Builds floor, ceiling and walls around the outline (no walls between touching cells). A lower cell gets a
## drop wall towards a taller neighbour. opts as for shell(), plus "open": any of ["n","s","e","w"] to leave
## that side of the outline without walls (it joins another part of the same space).
func plan(cells: Array, y: float, h: float, opts: Dictionary = {}) -> void:
	var xs: Array = []
	var zs: Array = []
	for c in cells:
		for v in [float(c[0]), float(c[2])]:
			if not xs.has(v):
				xs.append(v)
		for v in [float(c[1]), float(c[3])]:
			if not zs.has(v):
				zs.append(v)
	xs.sort()
	zs.sort()
	var nx := xs.size() - 1
	var nz := zs.size() - 1
	var grid := {}
	for i in nx:
		for j in nz:
			var cx: float = (float(xs[i]) + float(xs[i + 1])) / 2.0
			var cz: float = (float(zs[j]) + float(zs[j + 1])) / 2.0
			for c in cells:
				if cx > float(c[0]) and cx < float(c[2]) and cz > float(c[1]) and cz < float(c[3]):
					grid[Vector2i(i, j)] = float(c[4]) if c.size() > 4 else h
					break
	var floor_m: Material = opts.get("floor", wood_floor())
	var ceil_m: Variant = opts.get("ceiling", wood_mid)
	for c in cells:
		slab(float(c[0]), float(c[1]), float(c[2]), float(c[3]), y, floor_m)
		if ceil_m != null:
			var ch: float = float(c[4]) if c.size() > 4 else h
			slab(float(c[0]), float(c[1]), float(c[2]), float(c[3]), y + ch + 0.12, ceil_m, 0.12, false, "ceiling")
	var open: Array = opts.get("open", [])
	var walled := func(i: int, j: int, oi: int, oj: int) -> float:
		# height of the wall on this cell's side facing (oi, oj), or -1 if there is none
		if not grid.has(Vector2i(i, j)) or grid.has(Vector2i(oi, oj)):
			return -1.0
		return float(grid[Vector2i(i, j)])
	if not "n" in open or not "s" in open:
		for j in nz:
			for side in ["n", "s"]:
				if side in open:
					continue
				var start := -1
				var cur := -1.0
				for i in nx + 1:
					var v: float = walled.call(i, j, i, j - 1 if side == "n" else j + 1) if i < nx else -1.0
					if start >= 0 and v != cur:
						var zl: float = zs[j] if side == "n" else zs[j + 1]
						if side == "n":
							wall_run(Vector2(xs[start], zl), Vector2(xs[i], zl), y, cur, opts)
						else:
							wall_run(Vector2(xs[i], zl), Vector2(xs[start], zl), y, cur, opts)
						start = -1
					if start < 0 and v > 0.0:
						start = i
						cur = v
	for i in nx:
		for side in ["e", "w"]:
			if side in open:
				continue
			var start := -1
			var cur := -1.0
			for j in nz + 1:
				var v: float = walled.call(i, j, i + 1 if side == "e" else i - 1, j) if j < nz else -1.0
				if start >= 0 and v != cur:
					var xl: float = xs[i + 1] if side == "e" else xs[i]
					if side == "e":
						wall_run(Vector2(xl, zs[start]), Vector2(xl, zs[j]), y, cur, opts)
					else:
						wall_run(Vector2(xl, zs[j]), Vector2(xl, zs[start]), y, cur, opts)
					start = -1
				if start < 0 and v > 0.0:
					start = j
					cur = v
	# drop walls between cells of different height
	var drop: Material = opts.get("wall", plaster)
	for key in grid.keys():
		var c0: Vector2i = key
		var h0: float = grid[key]
		for off in [Vector2i(1, 0), Vector2i(0, 1)]:
			var ok: Vector2i = c0 + off
			if not grid.has(ok) or absf(float(grid[ok]) - h0) < 0.01:
				continue
			var lo: float = minf(h0, float(grid[ok]))
			var hi: float = maxf(h0, float(grid[ok]))
			if off.x == 1:
				arch(box(Vector3(0.2, hi - lo - LAYER, float(zs[c0.y + 1]) - float(zs[c0.y])), Vector3(xs[c0.x + 1], y + (lo + hi + LAYER) / 2.0, (float(zs[c0.y]) + float(zs[c0.y + 1])) / 2.0), drop), "wall")
			else:
				arch(box(Vector3(float(xs[c0.x + 1]) - float(xs[c0.x]), hi - lo - LAYER, 0.2), Vector3((float(xs[c0.x]) + float(xs[c0.x + 1])) / 2.0, y + (lo + hi + LAYER) / 2.0, zs[c0.y + 1]), drop), "wall")
	bounds = Vector2(float(xs[nx]) - float(xs[0]), float(zs[nz]) - float(zs[0]))
	spawn = Vector3((float(xs[0]) + float(xs[nx])) / 2.0, y, float(zs[nz]) - 1.2)
	look = Vector3(spawn.x, y + 1.25, float(zs[0]))


## Thin beam between two points (handrails, cords, pipes).
func beam(a: Vector3, b: Vector3, r: float, m: Material, parent: Node = null) -> MeshInstance3D:
	var d := b - a
	var mi := cyl(r, r, d.length(), Vector3.ZERO, m, parent, false, 8)
	var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.FORWARD
	mi.transform = Transform3D(Basis.looking_at(d.normalized(), up) * Basis(Vector3.RIGHT, PI / 2.0), (a + b) / 2.0)
	return mi


## A sagging line between two points, made of short straight pieces (cords, strings of flags and lanterns).
func sag_line(a: Vector3, b: Vector3, sag: float, r: float, m: Material, segs: int = 12) -> void:
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := sag_point(a, b, sag, t)
		beam(prev, p, r, m).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		prev = p


static func sag_point(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)


## Casing around a doorless opening in a wall, covering the joins where two parts of a space meet.
## `pos` is the middle of the opening at floor level, `w` and `h` its size, `depth` how far the casing runs through the wall.
func portal(pos: Vector3, rot_y: float, w: float, h: float, depth: float, m: Material) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	g.set_meta("door_part", true)
	root.add_child(g)
	for sd in [-1.0, 1.0]:
		box(Vector3(0.1, h + 0.1, depth), Vector3(sd * (w / 2.0 + 0.02), (h + 0.1) / 2.0 - 0.02, 0), m, false, g)
	box(Vector3(w + 0.14, 0.1, depth), Vector3(0, h + 0.02, 0), m, false, g)
	box(Vector3(w, LAYER * 3.0, depth), Vector3(0, LAYER * 1.5, 0), m, false, g)
	return g


## Handrail fixed to a wall: `a` and `b` are points on the rail, `to_wall` the offset from the rail to the wall surface.
func wall_rail(a: Vector3, b: Vector3, to_wall: Vector3, m: Material, r: float = 0.022) -> void:
	beam(a, b, r, m)
	var n := maxi(2, int(a.distance_to(b) / 1.0) + 1)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		beam(p, p + to_wall * 1.05, 0.012, m)
		sphere(0.028, p + to_wall, m, null, Vector3.ONE, 8)


## Railing from a to b (points on the floor); also stops you walking through it.
func rail(a: Vector3, b: Vector3, m: Material = null, h: float = 1.0) -> void:
	var mm: Material = m if m != null else brass
	var d := b - a
	var n := maxi(1, int(d.length() / 1.1))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		cyl(0.022, 0.022, h, p + Vector3(0, h / 2.0, 0), mm, null, false, 8)
	beam(a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.03, mm)
	_oriented_blocker(a, b, 0.1, h + 1.2)


## Invisible wall along a (possibly sloped) line; height measured up from the line. A slope is built from upright
## pieces, so the top of the wall doesn't lean out past the end of the rail.
func _oriented_blocker(a: Vector3, b: Vector3, thick: float, h: float) -> void:
	var d := b - a
	var run := Vector2(d.x, d.z).length()
	var n := 1 if absf(d.y) < 0.01 else maxi(1, ceili(run / 0.45))
	var yaw := atan2(d.x, d.z)
	for i in n:
		var piece := Node3D.new()
		piece.position = a.lerp(b, (i + 0.5) / n)
		piece.rotation.y = yaw
		root.add_child(piece)
		_collider(piece, Vector3(thick, h, run / n), Vector3(0, h / 2.0, 0)).set_meta("rail", true)


## Staircase you really walk up: `bottom` and `top` are the middle of the first and last edge, on floor level.
## Visible steps, smooth ramp collider. opts: mat, solid (steps go down to the ground, default true),
## rail: "both" / "left" / "right" / "none", rail_mat.
func stairs(bottom: Vector3, top: Vector3, width: float, opts: Dictionary = {}) -> void:
	var rise := top.y - bottom.y
	var hd := Vector3(top.x - bottom.x, 0, top.z - bottom.z)
	var run := hd.length()
	var dir := hd / run
	var rot := atan2(dir.x, dir.z)
	var count: int = opts.get("count", maxi(2, roundi(absf(rise) / 0.18)))
	var tread := run / count
	var step_h := rise / count
	var g := Node3D.new()
	g.position = bottom
	g.rotation.y = rot
	root.add_child(g)
	var m: Material = opts.get("mat", wood_mid)
	var solid: bool = opts.get("solid", true)
	for i in count:
		var top_y := step_h * (i + 1)
		if solid:
			arch(box(Vector3(width, top_y, tread), Vector3(0, top_y / 2.0, (i + 0.5) * tread), m, false, g), "floor")
		else:
			arch(box(Vector3(width, 0.06, tread + 0.03), Vector3(0, top_y - 0.03, (i + 0.5) * tread), m, false, g), "floor")
			box(Vector3(width - LAYER * 2.0, step_h - 0.06, 0.03), Vector3(0, top_y - 0.06 - (step_h - 0.06) / 2.0, i * tread + LAYER), wood_dark, false, g)
	var slope := atan2(rise, run)
	var ramp := Node3D.new()
	ramp.position = Vector3(0, rise / 2.0, run / 2.0)
	ramp.rotation.x = -slope
	g.add_child(ramp)
	var ln := sqrt(rise * rise + run * run) + 0.1
	_collider(ramp, Vector3(width, 0.2, ln), Vector3(0, -0.1, 0))
	if not solid:
		box(Vector3(0.1, 0.32, ln), Vector3(width / 2.0 - 0.05, -0.1, 0), wood_dark, false, ramp)
		box(Vector3(0.1, 0.32, ln), Vector3(-width / 2.0 + 0.05, -0.1, 0), wood_dark, false, ramp)
	var side := Basis(Vector3.UP, rot) * Vector3(width / 2.0 - 0.04, 0, 0)
	var rail_kind: String = opts.get("rail", "both")
	var rm: Material = opts.get("rail_mat", brass)
	if rail_kind == "both" or rail_kind == "right":
		rail(bottom + side, top + side, rm)
	if rail_kind == "both" or rail_kind == "left":
		rail(bottom - side, top - side, rm)
	stairs_list.append({"bottom": bottom, "top": top, "width": width})


## One stop of a two-stop lift. The door plane is at `pos`; the cab extends behind it (local -z), facing local +z.
## Press the panel inside to ride to lift `to_id` (in `to_space`; "" = same space). style: wall, floor_m, sign (text).
func lift(id: String, pos: Vector3, rot_y: float, to_id: String, to_space: String, dest_label: String, style: Dictionary = {}) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var w := 2.0
	var d := 2.2
	var h := 2.55
	var wm: Material = style.get("wall", brass)
	var fm: Material = style.get("floor_m", wood_mid)
	arch(box(Vector3(w, 0.06, d), Vector3(0, -0.03 + LAYER, -d / 2.0), fm, true, g), "floor")
	arch(box(Vector3(w, 0.08, d), Vector3(0, h + 0.04, -d / 2.0), wood_dark, false, g), "ceiling")
	box(Vector3(0.08, h, d), Vector3(-w / 2.0, h / 2.0, -d / 2.0), wm, true, g)
	box(Vector3(0.08, h, d), Vector3(w / 2.0, h / 2.0, -d / 2.0), wm, true, g)
	box(Vector3(w, h, 0.08), Vector3(0, h / 2.0, -d), wm, true, g)
	box(Vector3(0.14, h, 0.1), Vector3(-w / 2.0 + 0.02, h / 2.0, 0.0), wood_dark, false, g)
	box(Vector3(0.14, h, 0.1), Vector3(w / 2.0 - 0.02, h / 2.0, 0.0), wood_dark, false, g)
	box(Vector3(w + 0.2, 0.5, 0.1), Vector3(0, h + 0.25, 0.0), wood_dark, false, g)
	var sign_l := label(str(style.get("sign", "LIFT")), Vector3(0, h + 0.25, 0.06), 0.0, 44, Style.GOLD, g, 0.0035, 6)
	var inside := label(str(style.get("sign", "LIFT")), Vector3(0, h - 0.28, -0.14), PI, 44, Style.GOLD, g, 0.0035, 6)
	var door_m: Material = style.get("door_m", mat(Color(0.3, 0.32, 0.36), 0.35, 0.75))
	var dl := box(Vector3(0.9, h - 0.1, 0.04), Vector3(-1.42, (h - 0.1) / 2.0, -0.08), door_m, false, g)
	var dr := box(Vector3(0.9, h - 0.1, 0.04), Vector3(1.42, (h - 0.1) / 2.0, -0.08), door_m, false, g)
	omni(g.position + g.basis * Vector3(0, h - 0.2, -d / 2.0), Color(1.0, 0.86, 0.66), 0.9, 4.0)
	box(Vector3(0.5, 0.05, 0.5), Vector3(0, h - 0.02, -d / 2.0), glow(Color(1.0, 0.88, 0.66), 3.0), false, g)
	# button panel on the right-hand wall inside
	var px := w / 2.0 - 0.06
	box(Vector3(0.03, 0.5, 0.3), Vector3(px, 1.2, -0.7), brass, false, g)
	sphere(0.05, Vector3(px - 0.03, 1.32, -0.7), glow(Color(1.0, 0.75, 0.25), 2.5), g)
	sphere(0.05, Vector3(px - 0.03, 1.1, -0.7), glow(Style.AQUA, 2.0), g)
	var body := _interact_body(g, Vector3(0.7, 0.9, 0.8), Vector3(px - 0.28, 1.25, -0.7))
	g.set_meta("door_part", true)
	lifts[id] = {"node": g, "body": body, "pos": pos, "rot": rot_y, "to": to_id, "to_space": to_space, "label": dest_label,
		"door_l": dl, "door_r": dr, "sign": sign_l, "inside": inside, "floor": str(style.get("sign", "LIFT")), "top": pos + g.basis * Vector3(px - 0.2, 1.75, -0.7)}
	return g


## Something small to look at (flavour only: a thought from Mochi; never a clue).
func note(lbl: String, text: String, pos: Vector3, size: Vector3, offset: Vector3 = Vector3.ZERO) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	root.add_child(g)
	var body := _interact_body(g, size, offset)
	notes.append({"node": g, "body": body, "label": lbl, "text": text, "top": pos + offset + Vector3(0, size.y / 2.0 + 0.2, 0)})
	return g


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


## A bare bulb on a cord from the ceiling. Returns the light, so it can flicker.
func bulb(pos: Vector3, ceiling: float, col: Color = Color(1.0, 0.84, 0.58), energy: float = 0.7, light_range: float = 4.5,
		shadows: bool = false) -> OmniLight3D:
	var cord := ceiling - (pos.y + 0.1)
	cyl(0.006, 0.006, cord, Vector3(pos.x, ceiling - cord / 2.0, pos.z), black, null, false, 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cyl(0.028, 0.028, 0.07, pos + Vector3(0, 0.07, 0), black, null, false, 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sphere(0.05, pos, glow(col, 4.0), null, Vector3.ONE, 10)
	return omni(pos + Vector3(0, -0.1, 0), col, energy, light_range, shadows)


## Floor lantern (andon): a paper shade in a wooden frame on four short legs. `pos` is on the floor.
func andon(pos: Vector3, col: Color = Color(1.0, 0.84, 0.6), energy: float = 0.75, light_range: float = 4.5, shadows: bool = false) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	root.add_child(g)
	var h := 0.74
	cyl(0.15, 0.15, 0.5, Vector3(0, 0.4, 0), smat(SH_LANTERN, {"paper": col, "energy": 1.5, "ribs": 7.0}), g).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sx in [-0.17, 0.17]:
		for sz in [-0.17, 0.17]:
			box(Vector3(0.032, h, 0.032), Vector3(sx, h / 2.0, sz), wood_dark, false, g)
	for yy in [0.13, h - 0.02]:
		box(Vector3(0.37, 0.03, 0.37), Vector3(0, yy, 0), wood_dark, false, g)
	cyl(0.17, 0.17, 0.02, Vector3(0, 0.135, 0), wood_dark, g)
	omni(g.position + Vector3(0, h + 0.12, 0), Color(col.r, col.g * 0.94, col.b * 0.88), energy, light_range, shadows)
	_collider(g, Vector3(0.36, h, 0.36), Vector3(0, h / 2.0, 0))
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
	if energy > 0.0:
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


## Snapjaw security camera on a bracket (a sinister touch in every room). `pos` is the point on the wall or post it is
## bolted to, `rot_y` the way that surface faces, `aim` how far the head is turned from straight out.
func cctv(pos: Vector3, rot_y: float, aim: float = 0.0, tilt: float = -0.35) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	box(Vector3(0.14, 0.18, 0.024), Vector3(0, 0, 0.012), black, false, g)
	for sy in [-0.065, 0.065]:
		sphere(0.012, Vector3(0, sy, 0.028), steel, g, Vector3.ONE, 6)
	var arm := beam(Vector3(0, 0, 0.02), Vector3(0, 0, 0.24), 0.018, black, g)
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head := Node3D.new()
	head.position = Vector3(0, -0.02, 0.24)
	head.rotation = Vector3(tilt, aim, 0)
	g.add_child(head)
	sphere(0.05, Vector3.ZERO, black, head, Vector3.ONE, 8)
	var casing := Node3D.new()
	casing.position = Vector3(0, -0.04, 0.18)
	head.add_child(casing)
	box(Vector3(0.16, 0.14, 0.34), Vector3.ZERO, mat(Color(0.12, 0.13, 0.12), 0.4, 0.4), false, casing)
	box(Vector3(0.2, 0.02, 0.38), Vector3(0, 0.08, 0), mat(Color(0.2, 0.42, 0.22), 0.5), false, casing)
	cyl(0.05, 0.05, 0.03, Vector3(0, 0, 0.18), mat(Color(0.02, 0.02, 0.03), 0.1, 0.6), casing).rotation.x = PI / 2.0
	sphere(0.018, Vector3(0.05, 0.04, 0.17), glow(Color(1.0, 0.08, 0.06), 6.0), casing)


## A camera on its own steel pole, for places with no wall to bolt it to. `pos` is the foot of the pole.
func cctv_pole(pos: Vector3, h: float, rot_y: float, aim: float = 0.0) -> void:
	cyl(0.05, 0.065, h, pos + Vector3(0, h / 2.0, 0), steel, null, true, 10)
	cyl(0.12, 0.14, 0.06, pos + Vector3(0, 0.03, 0), steel, null, false, 12)
	cctv(pos + Vector3(0, h - 0.2, 0) + Basis(Vector3.UP, rot_y) * Vector3(0, 0, 0.045), rot_y, aim)


func porthole(pos: Vector3, rot_y: float, r: float = 0.24, glass: Color = Color(0.2, 0.85, 0.8), energy: float = 1.4) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	torus(r, r + 0.07, Vector3(0, 0, 0.03), brass, g, Vector3(PI / 2.0, 0, 0))
	var gl := cyl(r, r, 0.01, Vector3(0, 0, 0.02), smat(SH_PORTVIEW, {"glow_col": glass, "radius": r, "energy": energy * 0.8,
		"seed": fposmod(pos.x * 3.1 + pos.z * 1.7 + pos.y, 7.0) + 0.5}), g)
	gl.rotation.x = PI / 2.0
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 6:
		var a := i * TAU / 6.0
		sphere(0.018, Vector3(cos(a), sin(a), 0) * (r + 0.035) + Vector3(0, 0, 0.07), brass, g)
	return g


func shoji(size: Vector2, pos: Vector3, rot_y: float, col: Color = Color(1.0, 0.88, 0.66), energy: float = 1.4,
		cells: Vector2 = Vector2(4, 3), light: bool = true, shade: float = 0.34) -> void:
	quad(size, pos, smat(SH_SHOJI, {"glow_col": col, "energy": energy, "cells": cells, "shade": shade, "aspect": size.x / size.y,
		"seed": fposmod(pos.x * 1.3 + pos.z * 2.1, 5.0) + 0.3}), null, rot_y)
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


## A framed mirror on a wall: `pos` is on the wall surface. Oval or rectangular.
func mirror(pos: Vector3, rot_y: float, size: Vector2, oval: bool = true, frame_m: Material = null,
		top: Color = Color(0.74, 0.8, 0.82), bottom: Color = Color(0.5, 0.45, 0.4)) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var fm: Material = frame_m if frame_m != null else wood_dark
	if oval:
		var back := cyl(0.5, 0.5, 0.02, Vector3(0, 0, 0.01), fm, g, false, 32)
		back.rotation.x = PI / 2.0
		back.scale = Vector3(size.x + 0.08, 1.0, size.y + 0.08)
		var ring := torus(0.46, 0.5, Vector3(0, 0, 0.022), fm, g, Vector3(PI / 2.0, 0, 0))
		ring.scale = Vector3(size.x + 0.08, 1.0, size.y + 0.08)
	else:
		box(Vector3(size.x + 0.1, size.y + 0.1, 0.03), Vector3(0, 0, 0.015), fm, false, g)
	var gm := smat(SH_MIRROR, {"top": top, "bottom": bottom, "oval": oval})
	quad(size, Vector3(0, 0, 0.03 + LAYER), gm, g)
	return g


## A shallow puddle lying on the floor (`pos` on the floor).
func puddle(pos: Vector3, size: Vector2, rot_y: float = 0.0) -> MeshInstance3D:
	return decal_quad(size, pos + Vector3(0, LAYER, 0), smat(SH_PUDDLE, {"seed": fposmod(pos.x * 2.3 + pos.z * 3.1, 9.0)}), null, rot_y)


## A string of small triangular flags between two points on walls, pinned at both ends.
func bunting(a: Vector3, b: Vector3, count: int, cols: Array, sag: float = 0.12, flag: Vector2 = Vector2(0.26, 0.3)) -> void:
	sag_line(a, b, sag, 0.007, mat(Color(0.86, 0.8, 0.66), 0.9), maxi(count, 8))
	for p in [a, b]:
		sphere(0.024, p, brass, null, Vector3.ONE, 8)
	var rot := atan2(-(b - a).z, (b - a).x)
	for i in count:
		var t := (i + 0.5) / count
		var p: Vector3 = sag_point(a, b, sag, t)
		var f := prism(Vector3(flag.x, flag.y, 0.008), p - Vector3(0, flag.y / 2.0 - 0.004, 0), mat(cols[i % cols.size()], 0.9), null, rot)
		f.rotation.z = PI
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Many copies of one mesh as a single draw, for far-off scenery. `xforms` are world transforms.
func scatter(mesh: Mesh, m: Material, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func flat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## What you glimpse through an opening to the outdoors: grass, a stepping-stone path, shrubs, a fence, and a painted
## distance around the far side. `pos` is the middle of the opening at floor level, `rot_y` the way the wall faces into the
## room (the view lies behind it, local -z). Self-lit, so it reads as daylight whatever the room's lights are doing.
func outdoor_glimpse(pos: Vector3, rot_y: float, w: float = 9.0, depth: float = 5.5, h: float = 5.5) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var grass := flat(Color(0.42, 0.62, 0.3))
	arch(box(Vector3(w, 0.1, depth), Vector3(0, -0.05 - LAYER, -depth / 2.0), grass, false, g), "floor")
	var sky := smat(SH_SKYVIEW)
	quad(Vector2(w, h), Vector3(0, h / 2.0, -depth), sky, g)
	for sd in [-1.0, 1.0]:
		quad(Vector2(depth, h), Vector3(sd * w / 2.0, h / 2.0, -depth / 2.0), sky, g, -sd * PI / 2.0)
	var stone_m := flat(Color(0.8, 0.79, 0.74))
	for i in 7:
		var t := float(i) / 6.0
		var st := cyl(0.34, 0.36, 0.05, Vector3(sin(t * 3.1) * 0.7, 0.025, -0.5 - t * (depth - 1.4)), stone_m, g, false, 14)
		st.scale = Vector3(1.2 - 0.35 * t, 1, 0.8 - 0.25 * t)
	var shrub := flat(Color(0.26, 0.46, 0.24))
	var shrub2 := flat(Color(0.34, 0.54, 0.26))
	for i in 9:
		var a := i * 2.399
		var x := (-1.0 if i % 2 == 0 else 1.0) * (1.3 + 2.8 * fposmod(sin(a * 7.0) * 91.7, 1.0))
		sphere(0.55, Vector3(x, 0.32, -1.0 - i * 0.42), shrub if i % 3 else shrub2, g, Vector3(1.3, 0.85, 1.0), 12)
	var post := flat(Color(0.38, 0.27, 0.16))
	var trunk_x := [-3.0, 2.6]
	for i in 2:
		cyl(0.11, 0.16, 2.4, Vector3(trunk_x[i], 1.2, -depth + 1.1), post, g, false, 8)
		for j in 4:
			sphere(0.8, Vector3(trunk_x[i] + cos(j * 1.6) * 0.5, 2.75 + sin(j * 2.1) * 0.3, -depth + 1.1 + sin(j * 1.6) * 0.3), flat(Color(0.3, 0.52, 0.26).lerp(Color(0.9, 0.56, 0.24), float(i) * 0.75)), g, Vector3.ONE, 10)
	return g


## A short dead-end stretch of passage seen through an open door: floor, walls, a ceiling and a lamp. `pos` is the middle
## of the opening at floor level, `rot_y` the way the wall faces into the room (the passage lies behind it, local -z).
func passage_glimpse(pos: Vector3, rot_y: float, wall_m: Material, floor_m: Material, ceil_m: Material, lamp: Color,
		w: float = 3.0, depth: float = 3.2, h: float = 2.5, energy: float = 0.6) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	arch(box(Vector3(w, 0.1, depth), Vector3(0, -0.05, -depth / 2.0), floor_m, false, g), "floor")
	arch(box(Vector3(w, 0.1, depth), Vector3(0, h + 0.05, -depth / 2.0), ceil_m, false, g), "ceiling")
	arch(box(Vector3(w, h, 0.1), Vector3(0, h / 2.0, -depth - 0.05), wall_m, false, g), "wall")
	for sd in [-1.0, 1.0]:
		arch(box(Vector3(0.1, h, depth), Vector3(sd * (w / 2.0 + 0.05), h / 2.0, -depth / 2.0), wall_m, false, g), "wall")
	box(Vector3(0.14, 0.06, 0.14), Vector3(0, h - 0.03, -depth * 0.55), brass, false, g)
	sphere(0.05, Vector3(0, h - 0.11, -depth * 0.55), glow(lamp, 3.0), g, Vector3.ONE, 8)
	omni(g.global_position + g.basis * Vector3(0, h - 0.3, -depth * 0.55), lamp, energy, depth + 1.0)
	return g


## A framed picture or notice: `pos` is on the wall surface. `art` is the paper; `lines` draws that many rows of print.
func picture(pos: Vector3, rot_y: float, size: Vector2, art: Color, frame_m: Material = null, title: String = "", lines: int = 0,
		ink: Color = Color(0.2, 0.15, 0.12)) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	box(Vector3(size.x + 0.07, size.y + 0.07, 0.024), Vector3(0, 0, 0.012), frame_m if frame_m != null else wood_dark, false, g)
	box(Vector3(size.x, size.y, LAYER), Vector3(0, 0, 0.024 + LAYER / 2.0), mat(art, 0.9), false, g)
	var ink_m := mat(ink, 0.9)
	for i in lines:
		var w := size.x * (0.74 - 0.14 * float(i % 3))
		box(Vector3(w, 0.014, LAYER), Vector3(-size.x * 0.06, size.y * 0.3 - i * size.y * 0.72 / maxf(lines, 1.0), 0.024 + LAYER * 1.5), ink_m, false, g)
	if title != "":
		label(title, Vector3(0, size.y * 0.36, 0.024 + LAYER * 2.5), 0.0, 30, ink, g, 0.0028, 0)
	return g


## A shelf on brackets: `pos` is on the wall at the height of the shelf's top. Put things on it in the returned group,
## where y = 0 is the shelf top and z runs out from the wall.
func wall_shelf(pos: Vector3, rot_y: float, w: float, depth: float = 0.24, m: Material = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var sm: Material = m if m != null else wood_mid
	box(Vector3(w, 0.035, depth), Vector3(0, -0.0175, depth / 2.0), sm, false, g)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (w / 2.0 - 0.08)
		box(Vector3(0.024, 0.16, 0.02), Vector3(x, -0.115, 0.01), wood_dark, false, g)
		beam(Vector3(x, -0.18, 0.012), Vector3(x, -0.035, depth * 0.72), 0.009, wood_dark, g)
	return g


func stool(pos: Vector3, m: Material = null, h: float = 0.44, r: float = 0.17, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	_parent(parent).add_child(g)
	var sm: Material = m if m != null else wood_light
	cyl(r, r, 0.04, Vector3(0, h - 0.02, 0), sm, g, false, 16)
	for i in 3:
		var a := i * TAU / 3.0 + 0.5
		beam(Vector3(cos(a) * r * 0.55, h - 0.04, sin(a) * r * 0.55), Vector3(cos(a) * r, 0.0, sin(a) * r), 0.018, wood_dark, g)
	_collider(g, Vector3(r * 1.7, h, r * 1.7), Vector3(0, h / 2.0, 0))
	return g


## Folded towels or linen, stacked on whatever is at `pos`.
func folded_stack(pos: Vector3, cols: Array, count: int = 4, size: Vector2 = Vector2(0.36, 0.26), rot_y: float = 0.0, parent: Node = null) -> void:
	for i in count:
		var t := box(Vector3(size.x, 0.052, size.y), pos + Vector3(0.006 * (i % 2), 0.026 + i * 0.054, 0), mat(cols[i % cols.size()], 0.95), false, parent, rot_y + 0.03 * float(i % 3 - 1))
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func bottle(pos: Vector3, col: Color, h: float = 0.22, parent: Node = null) -> void:
	var m := mat(col, 0.25)
	cyl(0.04, 0.042, h * 0.66, pos + Vector3(0, h * 0.33, 0), m, parent, false, 10)
	cyl(0.016, 0.03, h * 0.34, pos + Vector3(0, h * 0.83, 0), m, parent, false, 8)


## A coil of rope lying on something.
func rope_coil(pos: Vector3, s: float = 1.0, m: Material = null, parent: Node = null) -> void:
	var rm: Material = m if m != null else mat(Color(0.66, 0.54, 0.36), 0.9)
	for i in 3:
		torus(0.13 * s, 0.2 * s, pos + Vector3(0.01 * (i % 2), 0.036 * s + i * 0.068 * s, 0), rm, parent)


func wall_clock(pos: Vector3, rot_y: float, r: float = 0.17, rim: Material = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	cyl(r, r, 0.04, Vector3(0, 0, 0.02), rim if rim != null else brass, g).rotation.x = PI / 2.0
	cyl(r * 0.84, r * 0.84, 0.01, Vector3(0, 0, 0.042), white, g).rotation.x = PI / 2.0
	box(Vector3(0.012, r * 0.62, 0.004), Vector3(0, r * 0.26, 0.05), black, false, g)
	var h := box(Vector3(r * 0.48, 0.012, 0.004), Vector3(r * 0.2, -0.02, 0.05), black, false, g)
	h.rotation.z = 0.3
	return g


## Rounded boulder (stretched low-poly sphere).
func rock(pos: Vector3, s: Vector3, m: Material, rot_y: float = 0.0, collide: bool = true) -> MeshInstance3D:
	var r := sphere(0.5, pos, m, null, s, 10)
	r.rotation.y = rot_y
	if collide:
		blocker(Vector3(s.x, s.y, s.z) * 0.9, pos)
	return r


## A row of small paper lanterns hanging along a sagging line between a and b.
func lantern_string(a: Vector3, b: Vector3, count: int, cols: Array, sag: float = 0.5, lights_every: int = 3) -> void:
	sag_line(a, b, sag, 0.006, black, 16)
	for i in count:
		var t := (i + 0.5) / count
		var line := sag_point(a, b, sag, t)
		var col: Color = cols[i % cols.size()]
		paper_lantern(line - Vector3(0, 0.26, 0), col, 0.55, lights_every > 0 and i % lights_every == 1, false, 0.7, line.y)


# =================================================================== Warden's Rest (Case 3): shaders
const SH_VISTA := """shader_type spatial;
// The view from a window of Warden's Rest: sky, the sea and, across the bay, the headland with the Gaol on it.
// Painted along the direction you look in, so it shifts like real distance as you walk past the window.
render_mode unshaded, shadows_disabled, cull_disabled;
uniform float prison_at = 0.35;    // where the Gaol stands, radians right of straight out (far outside = not in view)
uniform float land_from = -0.25;   // the headland runs between these two directions
uniform float land_to = 1.1;
uniform float horizon = -0.045;    // the sea's edge, a little below eye level from up on the cliff
uniform float dusk = 0.0;
uniform float seed = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec3 ray = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 o = normalize(vec3(-n.x, 0.0, -n.z) + vec3(0.0001));
	vec3 r = normalize(cross(o, vec3(0.0, 1.0, 0.0)));
	float az = atan(dot(ray, r), dot(ray, o));
	float el = asin(clamp(ray.y, -1.0, 1.0));
	vec3 sky_hi = mix(vec3(0.2, 0.4, 0.72), vec3(0.24, 0.24, 0.52), dusk);
	vec3 sky_lo = mix(vec3(0.62, 0.74, 0.84), vec3(1.0, 0.64, 0.44), dusk);
	vec3 c = mix(sky_lo, sky_hi, smoothstep(horizon, 0.45, el));
	float cl = noise(vec2(az * 2.4 + seed, el * 7.0)) * 0.6 + noise(vec2(az * 7.0 - seed, el * 20.0)) * 0.4;
	vec3 cloud = mix(vec3(0.95, 0.95, 0.93), vec3(1.0, 0.78, 0.66), dusk);
	float cm = smoothstep(0.5, 0.72, cl) * smoothstep(horizon + 0.02, 0.16, el);
	c = mix(c, cloud * (0.82 + 0.18 * smoothstep(0.6, 0.9, cl)), cm * 0.85);
	// the headland across the bay, hazy with distance
	float in_land = step(land_from, az) * step(az, land_to);
	float t = clamp((az - land_from) / max(land_to - land_from, 0.001), 0.0, 1.0);
	float top = horizon + in_land * (0.008 + 0.045 * pow(sin(t * 3.14159), 0.7) + 0.01 * noise(vec2(az * 16.0, seed)));
	// the Gaol: a long wall, a cell block and three towers
	float dp = az - prison_at;
	float wall = 1.0 - step(0.12, abs(dp));
	float block = 1.0 - step(0.06, abs(dp + 0.015));
	float tw = 0.0;
	tw = max(tw, 1.0 - step(0.008, abs(dp + 0.115)));
	tw = max(tw, 1.0 - step(0.01, abs(dp - 0.004)));
	tw = max(tw, 1.0 - step(0.008, abs(dp - 0.112)));
	float g_top = top + wall * 0.018 + block * 0.03 + tw * 0.055;
	vec3 haze = mix(vec3(0.62, 0.7, 0.76), vec3(0.62, 0.48, 0.52), dusk);
	if (el < horizon) {
		float d = clamp((horizon - el) * 3.0, 0.0, 1.0);
		vec3 sea_c = mix(mix(vec3(0.36, 0.56, 0.66), vec3(0.62, 0.5, 0.5), dusk), mix(vec3(0.08, 0.26, 0.36), vec3(0.12, 0.12, 0.24), dusk), sqrt(d));
		float wv = noise(vec2(az * 60.0 / (0.08 + d), el * 900.0 + TIME * 0.4));
		sea_c += vec3(0.2) * smoothstep(0.82, 0.98, wv) * (1.0 - d * 0.7);
		c = sea_c;
	} else if (el < g_top) {
		vec3 land_c = mix(haze, vec3(0.3, 0.38, 0.34), 0.35);
		if (el > top - 0.002 && (wall + block + tw) > 0.0) {
			land_c = mix(vec3(0.5, 0.52, 0.56), vec3(0.34, 0.3, 0.36), dusk);
			vec2 cellp = vec2(dp * 420.0, (el - top) * 380.0);
			float win = step(0.62, fract(cellp.x)) * step(0.5, fract(cellp.y)) * step(0.004, el - top) * block;
			vec3 lit = vec3(1.0, 0.82, 0.45) * (0.4 + 1.2 * dusk) * step(0.45, hash(floor(cellp)));
			land_c = mix(land_c, mix(vec3(0.16, 0.16, 0.2), lit, step(0.001, length(lit))), win);
			land_c = mix(land_c, haze, 0.35);
		}
		c = land_c;
	}
	ALBEDO = c;
}
"""

const SH_MARBLE := """shader_type spatial;
// Polished marble in world space: soft veins, optional chequer of a dark stone, a little sheen.
uniform vec3 col_a : source_color = vec3(0.9, 0.88, 0.84);
uniform vec3 col_b : source_color = vec3(0.6, 0.58, 0.56);
uniform vec3 col_c : source_color = vec3(0.14, 0.15, 0.17);
uniform float tile = 0.8;
uniform float checker = 1.0;
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
	vec2 q = p / tile;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float n = noise(p * 1.7) * 0.6 + noise(p * 5.3) * 0.3 + noise(p * 17.0) * 0.1;
	float vein = 1.0 - smoothstep(0.0, 0.05, abs(sin((p.x + p.y * 0.6) * 2.2 + n * 6.5)));
	vec3 c = mix(col_a, col_b, vein * 0.7 + n * 0.12);
	float odd = mod(cell.x + cell.y, 2.0);
	c = mix(c, col_c * (0.85 + 0.3 * n) + vec3(0.25) * vein, odd * checker);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * tile;
	c *= mix(0.6, 1.0, smoothstep(0.0, 0.008, edge));
	ALBEDO = c;
	ROUGHNESS = 0.18 + 0.1 * n;
	SPECULAR = 0.65;
}
"""

const SH_WALLPAPER := """shader_type spatial;
// Old wallpaper in world space: a soft stripe and a small damask diamond, faded and a little stained.
uniform vec3 base : source_color = vec3(0.42, 0.18, 0.2);
uniform vec3 motif : source_color = vec3(0.62, 0.36, 0.3);
uniform float scale = 0.28;
uniform float stain = 0.25;
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
	float hz = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
	vec2 p = vec2(hz, wpos.y) / scale;
	vec2 f = fract(p + vec2(0.0, floor(p.x) * 0.5)) - 0.5;
	float dia = 1.0 - smoothstep(0.16, 0.2, abs(f.x) + abs(f.y) * 0.72);
	float dot_c = 1.0 - smoothstep(0.04, 0.07, length(f));
	float stripe = smoothstep(0.46, 0.5, abs(fract(p.x * 0.5 + 0.25) - 0.5));
	vec3 c = mix(base, motif, max(dia * 0.75, stripe * 0.35));
	c = mix(c, base * 0.7, dot_c * 0.6);
	float n = noise(wpos.xy * 1.3 + wpos.zy * 0.7);
	c *= 1.0 - stain * smoothstep(0.55, 0.9, n) * 0.5;
	c *= 0.92 + 0.08 * noise(vec2(hz, wpos.y) * 9.0);
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
"""

const SH_DUST := """shader_type spatial;
// A film of fallen plaster on a floor or a tabletop: patchy, pale, never fully hiding what is under it.
render_mode depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 col : source_color = vec3(0.93, 0.92, 0.88);
uniform float amount = 0.6;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float big = noise(wpos.xz * 0.9) * 0.6 + noise(wpos.xz * 2.7) * 0.4;
	float grain = noise(wpos.xz * 46.0) * 0.6 + noise(wpos.xz * 113.0) * 0.4;
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.2, min(e.x, e.y));
	ALBEDO = col * (0.92 + 0.08 * grain);
	ROUGHNESS = 1.0;
	ALPHA = amount * (0.55 + 0.45 * big) * (0.45 + 0.55 * grain) * edge;
}
"""


const SH_BRICK := """shader_type spatial;
// Brickwork (or dressed stone blocks) in world space: running bond, mortar lines, a little colour variation and grime.
uniform vec3 col_a : source_color = vec3(0.5, 0.24, 0.16);
uniform vec3 col_b : source_color = vec3(0.64, 0.34, 0.24);
uniform vec3 mortar : source_color = vec3(0.7, 0.66, 0.6);
uniform vec2 size = vec2(0.24, 0.075);
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
	vec2 p = abs(wnrm.y) > 0.6 ? wpos.xz : vec2(abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x, wpos.y);
	vec2 q = p / size;
	float row = floor(q.y);
	q.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float h = hash(cell);
	float n = noise(p * 9.0);
	vec3 c = mix(col_a, col_b, h * 0.8 + n * 0.2);
	float mx = min(f.x, 1.0 - f.x) * size.x;
	float my = min(f.y, 1.0 - f.y) * size.y;
	c = mix(mortar * (0.85 + 0.15 * n), c, smoothstep(0.004, 0.009, min(mx, my)));
	ALBEDO = c * (0.86 + 0.14 * noise(p * 1.7));
	ROUGHNESS = 0.92;
}
"""


# =================================================================== Warden's Rest (Case 3): stock props
var _dust_m: ShaderMaterial = null


## Brick walls (or, with a bigger `size`, dressed stone blocks).
func brick(a: Color = Color(0.5, 0.24, 0.16), b: Color = Color(0.64, 0.34, 0.24), mortar: Color = Color(0.7, 0.66, 0.6),
		size: Vector2 = Vector2(0.24, 0.075)) -> ShaderMaterial:
	return smat(SH_BRICK, {"col_a": a, "col_b": b, "mortar": mortar, "size": size})


## A film of white plaster dust lying on whatever is at `pos` (floor or furniture). All dust shares one material.
func dust(pos: Vector3, size: Vector2, amount: float = 0.6, parent: Node = null) -> MeshInstance3D:
	if _dust_m == null:
		_dust_m = smat(SH_DUST, {"amount": amount})
	return decal_quad(size, pos + Vector3(0, LAYER, 0), _dust_m, parent)


## A sash window with a painted view of the sea and the Gaol: `pos` is on the wall surface at the middle of the glass.
## opts: frame (Material), prison_at, dusk, land_from, land_to, curtains (Color or null), light (energy of a soft
## daylight just inside, 0 = none), sill (bool).
func vista_window(pos: Vector3, rot_y: float, size: Vector2 = Vector2(1.2, 1.9), opts: Dictionary = {}) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var fm: Material = opts.get("frame", mat(Color(0.9, 0.88, 0.82), 0.6))
	var view := smat(SH_VISTA, {"prison_at": float(opts.get("prison_at", 0.4)), "dusk": float(opts.get("dusk", 0.0)),
		"land_from": float(opts.get("land_from", -0.25)), "land_to": float(opts.get("land_to", 1.1)),
		"seed": fposmod(pos.x * 1.7 + pos.z * 2.3, 9.0)})
	quad(size, Vector3(0, 0, LAYER * 2.0), view, g)
	box(Vector3(size.x + 0.16, 0.08, 0.07), Vector3(0, size.y / 2.0 + 0.04, 0.035), fm, false, g)
	box(Vector3(size.x + 0.16, 0.08, 0.07), Vector3(0, -size.y / 2.0 - 0.04, 0.035), fm, false, g)
	for sd in [-1.0, 1.0]:
		box(Vector3(0.08, size.y, 0.07), Vector3(sd * (size.x / 2.0 + 0.04), 0, 0.035), fm, false, g)
	# glazing bars and the meeting rail of the two sashes
	box(Vector3(0.028, size.y, 0.03), Vector3(0, 0, 0.02), fm, false, g)
	box(Vector3(size.x, 0.05, 0.045), Vector3(0, 0, 0.026), fm, false, g)
	for yy in [-size.y * 0.25, size.y * 0.25]:
		box(Vector3(size.x, 0.024, 0.03), Vector3(0, yy, 0.02), fm, false, g)
	if bool(opts.get("sill", true)):
		box(Vector3(size.x + 0.3, 0.05, 0.2), Vector3(0, -size.y / 2.0 - 0.105, 0.1), fm, false, g)
	var cur: Variant = opts.get("curtains", Color(0.42, 0.1, 0.12))
	if cur != null:
		var rod_y := size.y / 2.0 + 0.24
		var rw := size.x + 0.9
		cyl(0.018, 0.018, rw, Vector3(0, rod_y, 0.12), brass, g, false, 8).rotation.z = PI / 2.0
		for sd in [-1.0, 1.0]:
			box(Vector3(0.04, 0.06, 0.12), Vector3(sd * (rw / 2.0 - 0.1), rod_y, 0.06), brass, false, g)
			sphere(0.035, Vector3(sd * (rw / 2.0 + 0.02), rod_y, 0.12), brass, g, Vector3.ONE, 8)
		var cm := mat(cur, 0.95)
		var cm2 := mat((cur as Color).darkened(0.25), 0.95)
		var drop := size.y + 0.5 + float(opts.get("drop", 0.0))
		for sd in [-1.0, 1.0]:
			for i in 3:
				var x: float = sd * (size.x / 2.0 + 0.05 + i * 0.12)
				box(Vector3(0.13, drop, 0.024), Vector3(x, rod_y - drop / 2.0 + 0.02, 0.12 + 0.03 * float(i % 2) - 0.015), cm if i % 2 == 0 else cm2, false, g)
			# tie-back
			box(Vector3(0.36, 0.05, 0.02), Vector3(sd * (size.x / 2.0 + 0.17), -size.y * 0.18, 0.155), brass, false, g)
	var le: float = float(opts.get("light", 0.0))
	if le > 0.0:
		omni(g.position + g.basis * Vector3(0, 0.1, 0.9), Color(0.86, 0.92, 1.0), le, maxf(size.x, size.y) * 2.6)
	return g


## A brass chandelier on a chain from a ceiling rose: `pos` is the hoop, `ceiling` the height of the ceiling above it.
func chandelier(pos: Vector3, ceiling: float, col: Color = Color(1.0, 0.84, 0.6), energy: float = 1.4, rng: float = 9.0,
		shadows: bool = false, arms: int = 8, s: float = 1.0) -> OmniLight3D:
	cyl(0.13 * s, 0.17 * s, 0.05, Vector3(pos.x, ceiling - 0.025, pos.z), brass, null, false, 16)
	cyl(0.011, 0.011, ceiling - pos.y - 0.3 * s, Vector3(pos.x, (ceiling + pos.y + 0.3 * s) / 2.0, pos.z), black, null, false, 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cyl(0.035 * s, 0.07 * s, 0.34 * s, pos + Vector3(0, 0.14 * s, 0), brass, null, false, 12)
	sphere(0.1 * s, pos + Vector3(0, -0.05 * s, 0), brass, null, Vector3(1, 0.8, 1), 12)
	torus(0.5 * s, 0.55 * s, pos, brass, null, Vector3.ZERO)
	var flame := glow(col, 5.0)
	var cand := glow(col.lerp(Color.WHITE, 0.6), 1.6)
	for i in arms:
		var a := i * TAU / arms
		var p := pos + Vector3(cos(a), 0, sin(a)) * 0.525 * s
		beam(pos + Vector3(0, -0.04 * s, 0), p, 0.012 * s, brass)
		cyl(0.05 * s, 0.04 * s, 0.025, p + Vector3(0, 0.03, 0), brass, null, false, 10)
		cyl(0.018 * s, 0.018 * s, 0.12 * s, p + Vector3(0, 0.1 * s, 0), cand, null, false, 8)
		sphere(0.022 * s, p + Vector3(0, 0.18 * s, 0), flame, null, Vector3(1, 1.5, 1), 8)
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		sphere(0.025 * s, pos + Vector3(cos(a) * 0.3 * s, -0.16 * s, sin(a) * 0.3 * s), mat(Color(0.9, 0.95, 1.0), 0.1, 0.2), null, Vector3(1, 1.6, 1), 8)
		beam(pos + Vector3(cos(a) * 0.3 * s, -0.12 * s, sin(a) * 0.3 * s), pos + Vector3(cos(a) * 0.5 * s, 0, sin(a) * 0.5 * s), 0.004, brass)
	return omni(pos + Vector3(0, -0.2, 0), col, energy, rng, shadows)


## A brass two-candle wall sconce. `pos` is on the wall.
func sconce(pos: Vector3, rot_y: float, col: Color = Color(1.0, 0.82, 0.58), energy: float = 0.7, rng: float = 5.0,
		shadows: bool = false) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	box(Vector3(0.12, 0.3, 0.03), Vector3(0, 0, 0.015), brass, false, g)
	sphere(0.04, Vector3(0, -0.15, 0.03), brass, g, Vector3.ONE, 8)
	var shade := glow(col.lerp(Color(1.0, 0.95, 0.85), 0.3), 2.2)
	for sd in [-1.0, 1.0]:
		beam(Vector3(0, -0.04, 0.03), Vector3(sd * 0.16, 0.02, 0.15), 0.011, brass, g)
		cyl(0.035, 0.03, 0.02, Vector3(sd * 0.16, 0.03, 0.15), brass, g, false, 10)
		cyl(0.045, 0.075, 0.12, Vector3(sd * 0.16, 0.12, 0.15), shade, g, false, 12)
	if energy > 0.0:
		omni(g.position + g.basis * Vector3(0, 0.1, 0.4), col, energy, rng, shadows)


## A marble or stone fireplace against a wall (`pos` on the wall at floor level). The mantel shelf top is at y 1.21.
func fireplace(pos: Vector3, rot_y: float, w: float = 1.8, lit: bool = false, m: Material = null, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	var sm: Material = m if m != null else mat(Color(0.86, 0.84, 0.8), 0.35)
	var iron := mat(Color(0.1, 0.1, 0.11), 0.55, 0.4)
	for sd in [-1.0, 1.0]:
		box(Vector3(0.26, 1.0, 0.3), Vector3(sd * (w / 2.0 - 0.13), 0.5, 0.15), sm, false, g)
		box(Vector3(0.3, 0.08, 0.34), Vector3(sd * (w / 2.0 - 0.13), 0.04, 0.17), sm, false, g)
	box(Vector3(w, 0.15, 0.32), Vector3(0, 1.075, 0.16), sm, false, g)
	box(Vector3(w + 0.2, 0.06, 0.4), Vector3(0, 1.18, 0.2), sm, false, g)
	box(Vector3(w - 0.52, 1.0, 0.03), Vector3(0, 0.5, 0.015), mat(Color(0.06, 0.05, 0.05), 0.95), false, g)
	for sd in [-1.0, 1.0]:
		box(Vector3(0.02, 1.0, 0.27), Vector3(sd * (w / 2.0 - 0.27), 0.5, 0.165), mat(Color(0.14, 0.12, 0.12), 0.9), false, g)
	box(Vector3(w + 0.36, 0.04, 0.62), Vector3(0, 0.02, 0.33), mat(Color(0.3, 0.3, 0.32), 0.7), false, g)
	# the grate: an iron basket on short legs
	var gp := Vector3(0, 0.0, 0.17)
	box(Vector3(0.7, 0.03, 0.26), gp + Vector3(0, 0.12, 0), iron, false, g)
	for sx in [-0.33, 0.33]:
		box(Vector3(0.03, 0.12, 0.03), gp + Vector3(sx, 0.06, 0.1), iron, false, g)
		box(Vector3(0.03, 0.12, 0.03), gp + Vector3(sx, 0.06, -0.1), iron, false, g)
	for i in 6:
		box(Vector3(0.018, 0.2, 0.018), gp + Vector3(-0.3 + i * 0.12, 0.23, 0.12), iron, false, g)
	box(Vector3(0.72, 0.02, 0.02), gp + Vector3(0, 0.33, 0.12), iron, false, g)
	if lit:
		var coal := glow(Color(1.0, 0.38, 0.1), 3.0)
		for i in 7:
			sphere(0.06, gp + Vector3(-0.27 + i * 0.09, 0.17, 0.02 * float(i % 3) - 0.02), coal, g, Vector3(1.2, 0.7, 1.0), 8)
		omni(g.position + g.basis * Vector3(0, 0.45, 0.7), Color(1.0, 0.55, 0.25), 1.0, 5.0)
	_collider(g, Vector3(w, 1.2, 0.36), Vector3(0, 0.6, 0.18))
	return g


## A painting in a gilt frame: `pos` is on the wall. kind: "portrait", "warden", "sea", "still", "plan" (art drawn from SVG).
## back: show the back of the canvas instead (the portraits turned to the wall).
func painting(pos: Vector3, rot_y: float, size: Vector2, kind: String = "portrait", seed: int = 0, back: bool = false,
		frame_m: Material = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var fm: Material = frame_m if frame_m != null else mat(Color(0.78, 0.6, 0.26), 0.35, 0.7)
	if back:
		box(Vector3(size.x + 0.1, size.y + 0.1, 0.03), Vector3(0, 0, 0.015), mat(Color(0.62, 0.52, 0.36), 0.95), false, g)
		for sd in [-1.0, 1.0]:
			box(Vector3(0.05, size.y + 0.1, 0.035), Vector3(sd * (size.x / 2.0 + 0.025), 0, 0.0475), mat(Color(0.46, 0.34, 0.2), 0.9), false, g)
		box(Vector3(size.x * 0.9, 0.05, 0.02), Vector3(0, 0, 0.04), mat(Color(0.46, 0.34, 0.2), 0.9), false, g)
		beam(Vector3(-size.x * 0.3, size.y * 0.3, 0.035), Vector3(size.x * 0.3, size.y * 0.3, 0.035), 0.004, black, g)
		return g
	box(Vector3(size.x + 0.02, size.y + 0.02, 0.03), Vector3(0, 0, 0.015), mat(Color(0.2, 0.14, 0.08), 0.9), false, g)
	quad(size, Vector3(0, 0, 0.03 + LAYER * 2.0), tex_mat(painting_tex(kind, seed), false, false), g)
	box(Vector3(size.x + 0.16, 0.08, 0.06), Vector3(0, size.y / 2.0 + 0.04, 0.03), fm, false, g)
	box(Vector3(size.x + 0.16, 0.08, 0.06), Vector3(0, -size.y / 2.0 - 0.04, 0.03), fm, false, g)
	for sd in [-1.0, 1.0]:
		box(Vector3(0.08, size.y, 0.06), Vector3(sd * (size.x / 2.0 + 0.04), 0, 0.03), fm, false, g)
	if size.y > 0.7:
		box(Vector3(0.22, 0.06, 0.02), Vector3(0, -size.y / 2.0 - 0.04, 0.066), mat(Color(0.9, 0.78, 0.4), 0.3, 0.8), false, g)
	return g


## The art of a painting, drawn as a small SVG (cached per kind and seed).
static func painting_tex(kind: String, seed: int) -> Texture2D:
	var r := func(i: int) -> float: return fposmod(sin(float(seed * 17 + i) * 12.9898) * 43758.5453, 1.0)
	var bgs := ["#3b2a20", "#2a3340", "#3a2433", "#2f3a2a", "#40321c"]
	var coats := ["#3a4a6a", "#5a2a2a", "#2f4a3a", "#4a3a5a", "#5a4a2a"]
	var fur := ["#9a6a3e", "#8a5a34", "#a8784a", "#7a5030", "#b08050"]
	var bg: String = bgs[seed % bgs.size()]
	var svg := ""
	match kind:
		"warden":
			svg = """<svg xmlns="http://www.w3.org/2000/svg" width="200" height="260" viewBox="0 0 200 260">
<defs><radialGradient id="g" cx="0.5" cy="0.35" r="0.7"><stop offset="0" stop-color="#4a5a40"/><stop offset="1" stop-color="#141a12"/></radialGradient></defs>
<rect width="200" height="260" fill="url(#g)"/>
<path d="M30 260 Q40 175 100 170 Q160 175 170 260 Z" fill="#2c3a2a"/><path d="M78 178 L100 230 L122 178 Z" fill="#d8c27a"/>
<circle cx="100" cy="205" r="7" fill="#e8c34a"/><circle cx="84" cy="215" r="5" fill="#c43b30"/>
<path d="M52 120 Q50 70 100 64 Q150 70 148 120 Q150 160 100 172 Q50 160 52 120 Z" fill="#4f8f52"/>
<path d="M60 130 Q100 150 140 130 L150 150 Q100 168 50 150 Z" fill="#3b6e40"/>
<path d="M62 142 L70 132 L78 144 L86 133 L94 145 L102 134 L110 145 L118 133 L126 144 L134 132 L142 142" fill="none" stroke="#f4f0e0" stroke-width="4" stroke-linejoin="round"/>
<circle cx="78" cy="104" r="12" fill="#f4e4a0"/><circle cx="122" cy="104" r="12" fill="#f4e4a0"/>
<circle cx="78" cy="106" r="5" fill="#c41818"/><circle cx="122" cy="106" r="5" fill="#1a1a1a"/>
<path d="M44 72 Q100 30 156 72 L150 84 Q100 70 50 84 Z" fill="#1c2420"/><rect x="56" y="80" width="88" height="10" fill="#d8b44a"/>
</svg>"""
		"sea":
			svg = """<svg xmlns="http://www.w3.org/2000/svg" width="260" height="180" viewBox="0 0 260 180">
<defs><linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6a8aa8"/><stop offset="0.55" stop-color="#e8d8b8"/></linearGradient>
<linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a6a7a"/><stop offset="1" stop-color="#1a3040"/></linearGradient></defs>
<rect width="260" height="180" fill="url(#s)"/><rect y="104" width="260" height="76" fill="url(#w)"/>
<path d="M150 104 L170 70 L190 76 L214 60 L240 104 Z" fill="#4a5048"/><rect x="196" y="40" width="10" height="26" fill="#e8e0d0"/><path d="M194 40 L201 30 L208 40 Z" fill="#a8342c"/>
<path d="M40 112 L90 112 L82 122 L48 122 Z" fill="#2a1a10"/><path d="M62 112 L62 70 L84 108 Z" fill="#f0e8d8"/>
<path d="M0 140 Q30 134 60 140 T120 140 T180 140 T260 140" fill="none" stroke="#9ac0c8" stroke-width="2"/>
</svg>"""
		"still":
			svg = """<svg xmlns="http://www.w3.org/2000/svg" width="220" height="180" viewBox="0 0 220 180">
<rect width="220" height="180" fill="%s"/><rect y="120" width="220" height="60" fill="#5a3a22"/>
<ellipse cx="110" cy="124" rx="70" ry="14" fill="#c8b890"/><circle cx="84" cy="108" r="18" fill="#c43b30"/><circle cx="116" cy="102" r="20" fill="#e8a030"/>
<circle cx="142" cy="110" r="15" fill="#7a9a3a"/><path d="M120 82 Q126 70 134 74" fill="none" stroke="#4a6a2a" stroke-width="4"/>
<rect x="160" y="60" width="18" height="60" fill="#3a5a6a"/><rect x="164" y="50" width="10" height="12" fill="#3a5a6a"/>
</svg>""" % bg
		"plan":
			svg = """<svg xmlns="http://www.w3.org/2000/svg" width="240" height="180" viewBox="0 0 240 180">
<rect width="240" height="180" fill="#e8dcbc"/><g fill="none" stroke="#3a4a6a" stroke-width="3">
<rect x="20" y="20" width="200" height="140"/><path d="M20 80 H120 V20 M120 80 H220 M80 80 V160 M160 80 V160"/></g>
<path d="M40 70 H110 V40 H200" fill="none" stroke="#a8342c" stroke-width="2" stroke-dasharray="6 4"/>
<path d="M200 40 V120 H170" fill="none" stroke="#a8342c" stroke-width="2" stroke-dasharray="6 4"/>
<g fill="#3a4a6a"><rect x="40" y="140" width="40" height="4"/><rect x="130" y="140" width="60" height="4"/><rect x="30" y="30" width="50" height="4"/></g>
</svg>"""
		_:
			var col: String = coats[int(r.call(1) * 5.0) % 5]
			var f: String = fur[int(r.call(2) * 5.0) % 5]
			var hat := ""
			match int(r.call(3) * 4.0):
				0:
					hat = '<path d="M60 70 Q100 40 140 70 L136 80 Q100 70 64 80 Z" fill="#1a1410"/>'
				1:
					hat = '<rect x="72" y="28" width="56" height="44" fill="#1a1410"/><rect x="58" y="68" width="84" height="8" fill="#1a1410"/>'
				2:
					hat = '<path d="M62 76 Q100 50 138 76" fill="none" stroke="#e8e0c8" stroke-width="10"/>'
			svg = """<svg xmlns="http://www.w3.org/2000/svg" width="200" height="260" viewBox="0 0 200 260">
<defs><radialGradient id="g" cx="0.5" cy="0.35" r="0.75"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="#0c0806"/></radialGradient></defs>
<rect width="200" height="260" fill="url(#g)"/>
<path d="M26 260 Q34 180 100 172 Q166 180 174 260 Z" fill="%s"/><path d="M84 176 L100 214 L116 176 Z" fill="#efe6d0"/>
<circle cx="100" cy="200" r="6" fill="#d8b44a"/>
<path d="M58 116 Q56 70 100 66 Q144 70 142 116 Q146 160 100 170 Q54 160 58 116 Z" fill="%s"/>
<ellipse cx="100" cy="142" rx="30" ry="22" fill="%s"/><ellipse cx="90" cy="140" rx="4" ry="3" fill="#2a1a10"/><ellipse cx="110" cy="140" rx="4" ry="3" fill="#2a1a10"/>
<circle cx="82" cy="108" r="5" fill="#1a1410"/><circle cx="118" cy="108" r="5" fill="#1a1410"/>
<circle cx="66" cy="72" r="9" fill="%s"/><circle cx="134" cy="72" r="9" fill="%s"/>%s
</svg>""" % [bg, col, f, "#" + Color(f).darkened(0.18).to_html(false), f, f, hat]
	return svg_tex("painting:%s:%d" % [kind, seed], svg, 1.4)


## An upholstered armchair (`pos` on the floor, facing local +z).
func armchair(pos: Vector3, rot_y: float, m: Material, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	box(Vector3(0.8, 0.34, 0.78), Vector3(0, 0.25, 0), m, false, g)
	box(Vector3(0.56, 0.1, 0.58), Vector3(0, 0.47, 0.07), m, false, g)
	box(Vector3(0.8, 0.66, 0.18), Vector3(0, 0.75, -0.3), m, false, g)
	for sd in [-1.0, 1.0]:
		box(Vector3(0.12, 0.28, 0.7), Vector3(sd * 0.34, 0.55, 0.0), m, false, g)
		sphere(0.07, Vector3(sd * 0.34, 0.69, 0.33), m, g, Vector3(0.9, 0.8, 0.6), 10)
		for sz in [-0.33, 0.33]:
			cyl(0.035, 0.025, 0.08, Vector3(sd * 0.34, 0.04, sz), wood_dark, g, false, 8)
	_collider(g, Vector3(0.8, 1.05, 0.78), Vector3(0, 0.52, 0))
	return g


## A long upholstered sofa (`pos` on the floor, facing local +z).
func sofa(pos: Vector3, rot_y: float, m: Material, w: float = 2.1, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	box(Vector3(w, 0.34, 0.85), Vector3(0, 0.25, 0), m, false, g)
	for i in 3:
		box(Vector3(w / 3.0 - 0.1, 0.1, 0.62), Vector3(-w / 3.0 + i * w / 3.0, 0.47, 0.08), m, false, g)
	box(Vector3(w, 0.6, 0.2), Vector3(0, 0.72, -0.32), m, false, g)
	for sd in [-1.0, 1.0]:
		box(Vector3(0.14, 0.26, 0.8), Vector3(sd * (w / 2.0 - 0.07), 0.55, 0.0), m, false, g)
		for sz in [-0.36, 0.36]:
			cyl(0.035, 0.025, 0.08, Vector3(sd * (w / 2.0 - 0.07), 0.04, sz), wood_dark, g, false, 8)
	_collider(g, Vector3(w, 1.02, 0.85), Vector3(0, 0.51, 0))
	return g


## A tall bookcase against a wall: `pos` on the floor at the middle of its back, facing local +z. Books are drawn in one batch.
func bookcase(pos: Vector3, rot_y: float, size: Vector3 = Vector3(1.6, 2.6, 0.42), seed: int = 1, parent: Node = null,
		m: Material = null, fill: float = 0.86, collide: bool = true) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	var wm: Material = m if m != null else wood_dark
	var w := size.x
	var h := size.y
	var d := size.z
	# the sides in two lengths, so a fallen bookcase still reads as furniture to the room audit
	for sd in [-1.0, 1.0]:
		for half in 2:
			box(Vector3(0.05, h / 2.0, d), Vector3(sd * (w / 2.0 - 0.025), h / 4.0 + half * h / 2.0, d / 2.0), wm, false, g)
	box(Vector3(w - 0.1, h - 0.12, 0.02), Vector3(0, h / 2.0 + 0.02, 0.01), wood_mid, false, g)
	box(Vector3(w + 0.1, 0.1, d + 0.05), Vector3(0, h + 0.05, d / 2.0 + 0.005), wm, false, g)
	box(Vector3(w + 0.04, 0.12, d + 0.02), Vector3(0, 0.06, d / 2.0 + 0.005), wm, false, g)
	var n := maxi(3, int((h - 0.3) / 0.38))
	var gap := (h - 0.16) / n
	var xf: Array = []
	var cols: Array = []
	var pal := [Color(0.45, 0.1, 0.12), Color(0.14, 0.26, 0.4), Color(0.62, 0.5, 0.24), Color(0.18, 0.34, 0.24), Color(0.36, 0.2, 0.38),
		Color(0.55, 0.32, 0.18), Color(0.82, 0.76, 0.6), Color(0.2, 0.18, 0.16)]
	var rr := seed * 31
	for s in n:
		var sy := 0.12 + s * gap
		if s > 0:
			box(Vector3(w - 0.1, 0.03, d - 0.04), Vector3(0, sy - 0.015, d / 2.0 - 0.01), wm, false, g)
		var x := -w / 2.0 + 0.06
		while x < w / 2.0 - 0.08:
			rr += 1
			var hv := fposmod(sin(float(rr) * 12.9898) * 43758.5453, 1.0)
			var bw := 0.025 + 0.035 * hv
			if x + bw > w / 2.0 - 0.06:
				break
			if fposmod(hv * 7.3, 1.0) > fill:
				x += bw + 0.05
				continue
			var bh := minf(gap - 0.05, 0.2 + 0.12 * fposmod(hv * 3.1, 1.0))
			var bd := d * (0.62 + 0.2 * fposmod(hv * 5.7, 1.0))
			var t := Transform3D(Basis.IDENTITY.scaled(Vector3(bw - 0.002, bh, bd)), Vector3(x + bw / 2.0, sy + bh / 2.0, 0.03 + bd / 2.0))
			xf.append(t)
			cols.append(pal[int(hv * 97.0) % pal.size()])
			x += bw
	if not xf.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		mm.mesh = bm
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, xf[i])
			mm.set_instance_color(i, cols[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var bmat := StandardMaterial3D.new()
		bmat.vertex_color_use_as_albedo = true
		bmat.roughness = 0.8
		mi.material_override = bmat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)
	if collide:
		_collider(g, Vector3(w, h, d), Vector3(0, h / 2.0, d / 2.0))
	g.set_meta("shelf_gap", gap)
	return g


## A bed with its head against a wall: `pos` on the floor at the middle of the headboard, the bed runs along local +z.
func bed(pos: Vector3, rot_y: float, cover: Color, w: float = 1.5, posts: bool = false, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	var l := 2.1
	var cm := mat(cover, 0.95)
	box(Vector3(w, 0.3, l), Vector3(0, 0.25, l / 2.0 + 0.06), wood_mid, false, g)
	box(Vector3(w - 0.06, 0.2, l - 0.1), Vector3(0, 0.5, l / 2.0 + 0.06), white, false, g)
	box(Vector3(w - 0.02, 0.05, l * 0.64), Vector3(0, 0.625, l * 0.66 + 0.06), cm, false, g)
	for sd in [-1.0, 1.0]:
		box(Vector3(0.024, 0.34, l * 0.64), Vector3(sd * (w / 2.0 - 0.002), 0.46, l * 0.66 + 0.06), cm, false, g)
	box(Vector3(w - 0.02, 0.32, 0.024), Vector3(0, 0.46, l + 0.06 - 0.002), cm, false, g)
	box(Vector3(w - 0.1, 0.04, 0.3), Vector3(0, 0.63, l * 0.3 + 0.06), mat(cover.lightened(0.5), 0.95), false, g)
	for i in (2 if w > 1.2 else 1):
		var px := 0.0 if w <= 1.2 else (i - 0.5) * w * 0.48
		sphere(0.26, Vector3(px, 0.66, 0.32), white, g, Vector3(1.25, 0.38, 0.7), 14)
	box(Vector3(w + 0.12, 1.2, 0.08), Vector3(0, 0.6, 0.04), wood_dark, false, g)
	box(Vector3(w + 0.2, 0.08, 0.12), Vector3(0, 1.24, 0.06), wood_dark, false, g)
	box(Vector3(w + 0.12, 0.62, 0.07), Vector3(0, 0.31, l + 0.095), wood_dark, false, g)
	if posts:
		for sx in [-1.0, 1.0]:
			for z in [0.04, l + 0.095]:
				cyl(0.045, 0.05, 2.2, Vector3(sx * (w / 2.0 + 0.06), 1.1, z), wood_dark, g, false, 10)
		for z in [0.04, l + 0.095]:
			box(Vector3(w + 0.2, 0.06, 0.06), Vector3(0, 2.23, z), wood_dark, false, g)
		for sx in [-1.0, 1.0]:
			box(Vector3(0.06, 0.06, l + 0.12), Vector3(sx * (w / 2.0 + 0.06), 2.23, l / 2.0 + 0.07), wood_dark, false, g)
		box(Vector3(w + 0.1, 0.02, l), Vector3(0, 2.27, l / 2.0 + 0.07), mat(cover.darkened(0.2), 0.95), false, g)
		for sx in [-1.0, 1.0]:
			box(Vector3(0.02, 0.4, l), Vector3(sx * (w / 2.0 + 0.1), 2.06, l / 2.0 + 0.07), mat(cover.darkened(0.2), 0.95), false, g)
	_collider(g, Vector3(w + 0.1, 0.7, l + 0.12), Vector3(0, 0.35, l / 2.0 + 0.07))
	return g


## A wardrobe against a wall (`pos` on the floor at the middle of its back, facing local +z).
func wardrobe(pos: Vector3, rot_y: float, w: float = 1.2, h: float = 2.2, m: Material = null, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	var wm: Material = m if m != null else wood_mid
	var d := 0.6
	box(Vector3(w, h - 0.12, d), Vector3(0, (h - 0.12) / 2.0 + 0.1, d / 2.0), wm, false, g)
	box(Vector3(w + 0.08, 0.1, d + 0.06), Vector3(0, h + 0.03, d / 2.0 + 0.01), wood_dark, false, g)
	box(Vector3(w + 0.04, 0.1, d + 0.02), Vector3(0, 0.05, d / 2.0 + 0.005), wood_dark, false, g)
	for sd in [-1.0, 1.0]:
		box(Vector3(w / 2.0 - 0.14, h * 0.32, 0.02), Vector3(sd * w / 4.0, h * 0.68, d + 0.01), wood_dark, false, g)
		box(Vector3(w / 2.0 - 0.14, h * 0.3, 0.02), Vector3(sd * w / 4.0, h * 0.3, d + 0.01), wood_dark, false, g)
		sphere(0.03, Vector3(sd * 0.06, h * 0.5, d + 0.02), brass, g, Vector3.ONE, 8)
	box(Vector3(0.012, h - 0.24, 0.012), Vector3(0, (h - 0.12) / 2.0 + 0.1, d + 0.004), black, false, g)
	_collider(g, Vector3(w, h, d), Vector3(0, h / 2.0, d / 2.0))
	return g


## A balustrade from a to b (points on the floor): handrail, bottom rail, close-set balusters and newel posts. Stops you walking through it.
func balustrade(a: Vector3, b: Vector3, h: float = 1.0, m: Material = null, step: float = 0.16, newels: bool = true) -> void:
	var mm: Material = m if m != null else wood_dark
	var d := b - a
	var n := maxi(1, int(d.length() / step))
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		cyl(0.022, 0.03, h - 0.12, p + Vector3(0, 0.06 + (h - 0.12) / 2.0, 0), mm, null, false, 8)
	beam(a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.04, mm)
	beam(a + Vector3(0, 0.06, 0), b + Vector3(0, 0.06, 0), 0.03, mm)
	if newels:
		for p in [a, b]:
			var pp: Vector3 = p
			box(Vector3(0.12, h + 0.08, 0.12), pp + Vector3(0, (h + 0.08) / 2.0, 0), mm)
			sphere(0.075, pp + Vector3(0, h + 0.14, 0), mm, null, Vector3.ONE, 10)
	_oriented_blocker(a, b, 0.12, h + 1.2)


## A grand piano (`pos` on the floor under the middle of the case, keyboard towards local +z).
func grand_piano(pos: Vector3, rot_y: float, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	var lac := mat(Color(0.05, 0.04, 0.045), 0.15)
	box(Vector3(1.5, 0.32, 1.1), Vector3(0, 0.84, 0.25), lac, false, g)
	var tail := cyl(0.75, 0.75, 0.32, Vector3(0, 0.84, -0.3), lac, g, false, 28)
	tail.scale = Vector3(1.0, 1.0, 0.9)
	box(Vector3(1.4, 0.08, 0.3), Vector3(0, 0.72, 0.92), lac, false, g)
	box(Vector3(1.24, 0.03, 0.16), Vector3(0, 0.775, 0.97), white, false, g)
	for i in 18:
		box(Vector3(0.022, 0.025, 0.09), Vector3(-0.58 + i * 0.068 + (0.03 if i % 7 in [2, 6] else 0.0), 0.8, 0.93), black, false, g)
	var lid := Node3D.new()
	lid.position = Vector3(0.74, 1.0, 0.0)
	lid.rotation.z = 0.55
	g.add_child(lid)
	box(Vector3(1.45, 0.02, 1.7), Vector3(-0.72, 0.0, 0.0), lac, false, lid)
	beam(Vector3(0.5, 1.0, -0.1), Vector3(0.45, 1.6, -0.1), 0.012, lac, g)
	for p in [Vector3(-0.6, 0, 0.6), Vector3(0.6, 0, 0.6), Vector3(0.0, 0, -0.85)]:
		var pp: Vector3 = p
		cyl(0.05, 0.06, 0.7, pp + Vector3(0, 0.35, 0), lac, g, false, 10)
	box(Vector3(0.36, 0.1, 0.1), Vector3(0, 0.06, -0.2), brass, false, g)
	box(Vector3(0.08, 0.6, 0.06), Vector3(0, 0.4, -0.2), lac, false, g)
	box(Vector3(0.36, 0.04, 0.3), Vector3(0, 0.8, 0.62), lac, false, g)
	_collider(g, Vector3(1.5, 1.0, 1.9), Vector3(0, 0.5, 0.05))
	# the bench
	var bp := Vector3(0, 0, 1.45)
	box(Vector3(0.8, 0.08, 0.38), bp + Vector3(0, 0.5, 0), lac, false, g)
	for sx in [-0.34, 0.34]:
		for sz in [-0.14, 0.14]:
			box(Vector3(0.05, 0.46, 0.05), bp + Vector3(sx, 0.23, sz), lac, false, g)
	_collider(g, Vector3(0.8, 0.54, 0.38), bp + Vector3(0, 0.27, 0))
	return g


## A typewriter sitting on something (`pos` on its top surface, keys towards local +z).
func typewriter(pos: Vector3, rot_y: float, col: Color = Color(0.12, 0.13, 0.14), parent: Node = null, paper_in: bool = true) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	var body := mat(col, 0.35, 0.3)
	box(Vector3(0.36, 0.06, 0.3), Vector3(0, 0.03, 0), body, false, g)
	var top := box(Vector3(0.34, 0.06, 0.18), Vector3(0, 0.08, -0.05), body, false, g)
	top.rotation.x = -0.25
	for r in 3:
		for c in 8:
			cyl(0.011, 0.011, 0.01, Vector3(-0.14 + c * 0.04 + r * 0.01, 0.066 + r * 0.012, 0.11 - r * 0.035), mat(Color(0.9, 0.88, 0.8), 0.4), g, false, 8)
	cyl(0.028, 0.028, 0.42, Vector3(0, 0.14, -0.1), black, g, false, 12).rotation.z = PI / 2.0
	cyl(0.012, 0.012, 0.05, Vector3(0.23, 0.15, -0.1), mat(Color(0.75, 0.75, 0.78), 0.3, 0.8), g, false, 8).rotation.z = PI / 2.0
	if paper_in:
		var sh := box(Vector3(0.21, 0.2, 0.003), Vector3(0, 0.24, -0.13), paper, false, g)
		sh.rotation.x = -0.15
	return g


## A brass telescope on a wooden tripod (`pos` on the floor), pointing along local -z tilted up by `pitch`.
func telescope(pos: Vector3, rot_y: float, pitch: float = 0.04) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var head := Vector3(0, 1.25, 0)
	for i in 3:
		var a := i * TAU / 3.0 + 0.4
		beam(head, Vector3(cos(a) * 0.48, 0.0, sin(a) * 0.48), 0.022, wood_mid, g)
		sphere(0.03, Vector3(cos(a) * 0.48, 0.02, sin(a) * 0.48), brass, g, Vector3.ONE, 8)
	cyl(0.07, 0.06, 0.1, head, brass, g, false, 12)
	var tube := Node3D.new()
	tube.position = head + Vector3(0, 0.1, 0)
	tube.rotation.x = pitch
	g.add_child(tube)
	cyl(0.075, 0.06, 1.1, Vector3(0, 0, -0.15), brass, tube, false, 16).rotation.x = PI / 2.0
	cyl(0.085, 0.085, 0.1, Vector3(0, 0, -0.68), brass, tube, false, 16).rotation.x = PI / 2.0
	cyl(0.07, 0.07, 0.006, Vector3(0, 0, -0.73), mat(Color(0.3, 0.5, 0.6), 0.05, 0.4), tube, false, 16).rotation.x = PI / 2.0
	cyl(0.025, 0.03, 0.14, Vector3(0, 0, 0.45), black, tube, false, 10).rotation.x = PI / 2.0
	for z in [-0.4, 0.05, 0.3]:
		torus(0.07, 0.085, Vector3(0, 0, z), mat(Color(0.6, 0.42, 0.18), 0.4, 0.8), tube, Vector3(PI / 2.0, 0, 0))
	_collider(g, Vector3(0.6, 1.3, 0.6), Vector3(0, 0.65, 0))
	_collider(tube, Vector3(0.24, 0.24, 1.3), Vector3(0, 0, -0.1))
	return g


## A cork notice board on the wall (`pos` on the wall at its middle). `sheets`: [[x, y, w, h, Color, lines], ...] in metres
## from the middle of the board.
func notice_board(pos: Vector3, rot_y: float, size: Vector2, sheets: Array, title: String = "") -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	box(Vector3(size.x + 0.12, size.y + 0.12, 0.04), Vector3(0, 0, 0.02), wood_dark, false, g)
	box(Vector3(size.x, size.y, 0.012), Vector3(0, 0, 0.046), mat(Color(0.62, 0.44, 0.26), 0.98), false, g)
	var i := 0
	for s in sheets:
		var sx: float = s[0]
		var sy: float = s[1]
		var sw: float = s[2]
		var shh: float = s[3]
		var z := 0.052 + LAYER * (1 + i % 3)
		var sh := box(Vector3(sw, shh, LAYER), Vector3(sx, sy, z), mat(s[4], 0.9), false, g)
		sh.rotation.z = 0.04 * float((i * 7) % 5 - 2)
		var lines: int = s[5]
		for j in lines:
			var lw := sw * (0.78 - 0.18 * float((i + j) % 3))
			box(Vector3(lw, 0.012, LAYER), Vector3(sx - sw * 0.04, sy + shh * 0.32 - j * shh * 0.7 / maxf(lines, 1.0), z + LAYER), mat(Color(0.22, 0.18, 0.16), 0.9), false, g)
		sphere(0.012, Vector3(sx, sy + shh / 2.0 - 0.03, z + 0.008), mat([Color(0.85, 0.15, 0.12), Color(0.2, 0.5, 0.8), Color(0.95, 0.8, 0.2)][i % 3], 0.4), g, Vector3.ONE, 6)
		i += 1
	if title != "":
		box(Vector3(size.x * 0.6, 0.12, 0.02), Vector3(0, size.y / 2.0 + 0.14, 0.01), brass, false, g)
		label(title, Vector3(0, size.y / 2.0 + 0.14, 0.03), 0.0, 34, Color(0.18, 0.1, 0.04), g, 0.0026, 0)
	return g


## A rail of brass coat hooks on the wall (`pos` on the wall at the middle of the rail). coats: one entry per hook,
## a Color (a coat hangs there) or null (empty hook); names: a card above each hook ("" = none).
func coat_rail(pos: Vector3, rot_y: float, coats: Array, names: Array = [], spacing: float = 0.42) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var w := spacing * coats.size() + 0.2
	box(Vector3(w, 0.14, 0.03), Vector3(0, 0, 0.015), wood_dark, false, g)
	for i in coats.size():
		var x := -w / 2.0 + 0.1 + spacing * (i + 0.5)
		beam(Vector3(x, 0.0, 0.03), Vector3(x, 0.05, 0.11), 0.01, brass, g)
		sphere(0.016, Vector3(x, 0.055, 0.115), brass, g, Vector3.ONE, 6)
		if i < names.size() and str(names[i]) != "":
			box(Vector3(0.3, 0.08, 0.006), Vector3(x, 0.13, 0.008), paper, false, g)
			label(str(names[i]), Vector3(x, 0.13, 0.013), 0.0, 20, Color(0.2, 0.12, 0.08), g, 0.002, 0)
		var c: Variant = coats[i]
		if c != null:
			var cm := mat(c, 0.95)
			box(Vector3(0.36, 0.1, 0.1), Vector3(x, 0.02, 0.1), cm, false, g)
			var body := box(Vector3(0.34, 0.85, 0.08), Vector3(x, -0.43, 0.1), cm, false, g)
			body.rotation.z = 0.02 * float(i % 3 - 1)
			for sd in [-1.0, 1.0]:
				box(Vector3(0.06, 0.6, 0.07), Vector3(x + sd * 0.17, -0.3, 0.1), mat((c as Color).darkened(0.2), 0.95), false, g)
			box(Vector3(0.12, 0.14, 0.012), Vector3(x + 0.08, -0.55, 0.146), mat((c as Color).darkened(0.3), 0.95), false, g)
	return g


## A bat hanging upside down from whatever is above `pos` (feet at pos).
func bat(pos: Vector3, s: float = 1.0, rot_y: float = 0.0) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var fur := mat(Color(0.12, 0.09, 0.1), 0.9)
	var wing := mat(Color(0.2, 0.13, 0.15), 0.8)
	beam(Vector3(0, 0, 0), Vector3(0, -0.03 * s, 0), 0.004, fur, g)
	sphere(0.035 * s, Vector3(0, -0.07 * s, 0), fur, g, Vector3(1.0, 1.4, 0.9), 8)
	for sd in [-1.0, 1.0]:
		var w := prism(Vector3(0.05 * s, 0.11 * s, 0.012), Vector3(sd * 0.03 * s, -0.08 * s, 0.01), wing, g)
		w.rotation.z = PI + sd * 0.25
	sphere(0.02 * s, Vector3(0, -0.125 * s, 0.005), fur, g, Vector3.ONE, 8)
	for sd in [-1.0, 1.0]:
		sphere(0.005 * s, Vector3(sd * 0.008 * s, -0.128 * s, 0.022 * s), glow(Color(1.0, 0.3, 0.2), 2.0), g, Vector3.ONE, 4)


## A wooden crutch leaning on something: `pos` is its foot on the floor, it leans towards local -z by `lean`.
func crutch(pos: Vector3, rot_y: float, lean: float = 0.25) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var piv := Node3D.new()
	piv.rotation.x = -lean
	g.add_child(piv)
	cyl(0.02, 0.022, 0.06, Vector3(0, 0.03, 0), black, piv, false, 8)
	cyl(0.014, 0.014, 0.55, Vector3(0, 0.33, 0), wood_light, piv, false, 8)
	for sd in [-1.0, 1.0]:
		beam(Vector3(0, 0.6, 0), Vector3(sd * 0.08, 1.25, 0), 0.012, wood_light, piv)
	box(Vector3(0.2, 0.03, 0.04), Vector3(0, 0.95, 0), wood_mid, false, piv)
	box(Vector3(0.24, 0.05, 0.07), Vector3(0, 1.27, 0), mat(Color(0.25, 0.2, 0.18), 0.8), false, piv)
	return g


## A clock that stands on a mantel or a table: `pos` under its middle, face towards local +z, hands at h:m.
func mantel_clock(pos: Vector3, rot_y: float, hh: float = 3.0, mm: float = 0.0, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	var case_m := mat(Color(0.3, 0.16, 0.08), 0.4)
	box(Vector3(0.34, 0.04, 0.14), Vector3(0, 0.02, 0), brass, false, g)
	box(Vector3(0.3, 0.3, 0.12), Vector3(0, 0.19, 0), case_m, false, g)
	var arch := cyl(0.15, 0.15, 0.12, Vector3(0, 0.34, 0), case_m, g, false, 20)
	arch.rotation.x = PI / 2.0
	cyl(0.11, 0.11, 0.012, Vector3(0, 0.3, 0.066), mat(Color(0.95, 0.92, 0.84), 0.5), g, false, 24).rotation.x = PI / 2.0
	torus(0.105, 0.125, Vector3(0, 0.3, 0.066), brass, g, Vector3(PI / 2.0, 0, 0))
	# hour marks, so the time can be read: long ones at 12, 3, 6 and 9
	for i in 12:
		var ta := -float(i) / 12.0 * TAU
		var tick := box(Vector3(0.005, 0.02 if i % 3 == 0 else 0.011, 0.002), Vector3.ZERO, black, false, g)
		tick.rotation.z = ta
		tick.position = Vector3(0, 0.3, 0.0731) + Vector3(-sin(ta), cos(ta), 0) * (0.088 if i % 3 == 0 else 0.092)
	var ha := -(fposmod(hh, 12.0) + mm / 60.0) / 12.0 * TAU
	var ma := -mm / 60.0 * TAU
	var hand := box(Vector3(0.012, 0.06, 0.004), Vector3(0, 0, 0), black, false, g)
	hand.rotation.z = ha
	hand.position = Vector3(0, 0.3, 0.075) + Vector3(-sin(ha), cos(ha), 0) * 0.03
	var mh := box(Vector3(0.008, 0.09, 0.004), Vector3(0, 0, 0), black, false, g)
	mh.rotation.z = ma
	mh.position = Vector3(0, 0.3, 0.079) + Vector3(-sin(ma), cos(ma), 0) * 0.045
	sphere(0.03, Vector3(0, 0.5, 0), brass, g, Vector3.ONE, 8)
	return g


## A tall longcase clock against a wall (`pos` on the floor at the middle of its back), hands at h:m.
func longcase_clock(pos: Vector3, rot_y: float, hh: float = 8.0, mm: float = 0.0) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var cm := mat(Color(0.28, 0.14, 0.07), 0.35)
	box(Vector3(0.56, 0.4, 0.36), Vector3(0, 0.2, 0.18), cm, false, g)
	box(Vector3(0.42, 1.2, 0.28), Vector3(0, 1.0, 0.14), cm, false, g)
	box(Vector3(0.16, 0.7, 0.012), Vector3(0, 0.95, 0.286), mat(Color(0.12, 0.1, 0.08), 0.2), false, g)
	cyl(0.06, 0.06, 0.014, Vector3(0, 0.78, 0.296), brass, g, false, 16).rotation.x = PI / 2.0
	box(Vector3(0.54, 0.6, 0.34), Vector3(0, 1.9, 0.17), cm, false, g)
	box(Vector3(0.6, 0.1, 0.38), Vector3(0, 2.25, 0.19), cm, false, g)
	cyl(0.2, 0.2, 0.012, Vector3(0, 1.9, 0.346), mat(Color(0.95, 0.92, 0.84), 0.5), g, false, 24).rotation.x = PI / 2.0
	torus(0.19, 0.22, Vector3(0, 1.9, 0.348), brass, g, Vector3(PI / 2.0, 0, 0))
	var ha := -(fposmod(hh, 12.0) + mm / 60.0) / 12.0 * TAU
	var ma := -mm / 60.0 * TAU
	var hand := box(Vector3(0.02, 0.11, 0.006), Vector3.ZERO, black, false, g)
	hand.rotation.z = ha
	hand.position = Vector3(0, 1.9, 0.358) + Vector3(-sin(ha), cos(ha), 0) * 0.05
	var mh := box(Vector3(0.012, 0.16, 0.006), Vector3.ZERO, black, false, g)
	mh.rotation.z = ma
	mh.position = Vector3(0, 1.9, 0.364) + Vector3(-sin(ma), cos(ma), 0) * 0.075
	for sd in [-1.0, 1.0]:
		sphere(0.035, Vector3(sd * 0.24, 2.34, 0.19), brass, g, Vector3.ONE, 8)
	_collider(g, Vector3(0.56, 2.3, 0.36), Vector3(0, 1.15, 0.18))
	return g


## A green-shaded desk lamp sitting on something (`pos` on the top surface). Returns its light, if any.
func desk_lamp(pos: Vector3, rot_y: float, parent: Node = null, energy: float = 0.0, col: Color = Color(1.0, 0.86, 0.62)) -> OmniLight3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	_parent(parent).add_child(g)
	cyl(0.08, 0.09, 0.03, Vector3(0, 0.015, 0), brass, g, false, 14)
	cyl(0.012, 0.012, 0.34, Vector3(0, 0.2, 0), brass, g, false, 8)
	var shade := cyl(0.02, 0.1, 0.1, Vector3(0, 0.36, 0.06), mat(Color(0.1, 0.42, 0.24), 0.3), g, false, 14)
	shade.rotation.x = 0.5
	sphere(0.03, Vector3(0, 0.33, 0.09), glow(col, 3.0), g, Vector3.ONE, 8)
	if energy > 0.0:
		return omni(Vector3(0, 0.25, 0.12), col, energy, 3.5, false, g)
	return null


## A dark, distant prison on its headland (for the outdoor spaces). `pos` is the foot of the rock.
func far_prison(pos: Vector3, s: float = 1.0, rot_y: float = 0.0, lit: bool = false) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var rock_m := rock_mat(Color(0.2, 0.22, 0.22), Color(0.36, 0.37, 0.34))
	sphere(1.0, Vector3(0, 0, 0), rock_m, g, Vector3(60, 22, 34) * s, 18)
	var wall_m := mat(Color(0.42, 0.42, 0.45), 0.9)
	var dark_m := mat(Color(0.26, 0.26, 0.3), 0.9)
	var win_m := glow(Color(1.0, 0.82, 0.45), 2.2) if lit else mat(Color(0.08, 0.08, 0.1), 0.9)
	var base_y := 18.0 * s
	box(Vector3(70, 10, 2) * s, Vector3(0, base_y + 5.0 * s, 14.0 * s), wall_m, false, g)
	box(Vector3(2, 10, 30) * s, Vector3(-35.0 * s, base_y + 5.0 * s, 0), wall_m, false, g)
	box(Vector3(2, 10, 30) * s, Vector3(35.0 * s, base_y + 5.0 * s, 0), wall_m, false, g)
	box(Vector3(48, 20, 16) * s, Vector3(0, base_y + 10.0 * s, -2.0 * s), dark_m, false, g)
	for r in 4:
		for c in 12:
			box(Vector3(1.2, 1.8, 0.4) * s, Vector3((-20.0 + c * 3.6) * s, base_y + (4.0 + r * 4.0) * s, 6.05 * s), win_m, false, g)
	for x in [-35.0, 0.0, 35.0]:
		var tx: float = x
		cyl(3.0 * s, 3.4 * s, 26.0 * s, Vector3(tx * s, base_y + 13.0 * s, 14.0 * s if tx != 0.0 else -10.0 * s), wall_m, g, false, 14)
		cyl(0.0, 4.2 * s, 7.0 * s, Vector3(tx * s, base_y + 29.5 * s, 14.0 * s if tx != 0.0 else -10.0 * s), mat(Color(0.2, 0.2, 0.24), 0.8), g, false, 14)
	sphere(1.4 * s, Vector3(0, base_y + 24.0 * s, -6.5 * s), glow(Color(1.0, 0.95, 0.8), 3.0), g, Vector3.ONE, 10)
	return g
