#!/usr/bin/env python3
"""SPLASH TRIAL - Chapter 2 Truth Drop icon generator.

Writes art/props/clue_<id>.svg (200x200, transparent) for the 14 Chapter 2 clue ids
(docs/DESIGN2.md section 5). Same item-card style as the Chapter 1 icons made by tools/gen_bgs.py:
bold #2a1a10 outlines (4.5px), soft cel shading, a ground shadow, no text (writing = scribble glyphs).

Usage (from the project root):
  python3 tools/gen_clue_icons2.py                      # write all 14 icons
  python3 tools/gen_clue_icons2.py --only wax_lump,rules2

Only SVG 1.1 basics are used (no text, filters, images, styles) so Godot's ThorVG rasterizes it.
The tiny SVG toolkit (Doc, G, T, glyphs, snapjaw_crest, ...) is shared with tools/gen_bgs.py.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_bgs as B  # noqa: E402  (stdlib-only sibling module; main() is guarded)

Doc, G, T = B.Doc, B.G, B.T
fm, mix, dark, light, smooth = B.fm, B.mix, B.dark, B.light, B.smooth
glyphs, sparkle, glow, snapjaw_crest, ishadow = B.glyphs, B.sparkle, B.glow, B.snapjaw_crest, B.ishadow
INK, GOLD, GOLD_D, CHROME, CHROME_D, YUZU = B.INK, B.GOLD, B.GOLD_D, B.CHROME, B.CHROME_D, B.YUZU
OL = B.OL

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CLUES2 = ["rules2", "snapjaw_file2", "rounds_log", "lilac_thread", "grub_ghost", "anchor_doorstop", "boot_prints",
	"wax_lump", "bruno_boots", "duchess_shawl", "snore_alibi", "pepper_log", "tumble_bunk", "dictaphone"]

# palette additions
SHAWL = "#c4a2df"      # Duchess's shawl (same as tools/gen_chars.py)
SHAWL_D = "#9474bd"
SHAWL_L = "#e6d6f5"
SHAWL_EMB = "#7a4fae"
BRASS_L = "#ffe08a"
BRASS = "#e2a93a"
BRASS_D = "#9a6418"
COAL = "#1c1b21"
COAL_L = "#4a4955"
WOOD = "#b07a48"
WOOD_D = "#7a4e2a"
WOOD_L = "#d8a46a"
TEAL_PAINT = "#3a9a94"
TEAL_PAINT_D = "#22625e"
PAPER = "#fbf6ea"
SCRIBBLE = "#5a4a3a"


def P(*v):
	"""Format numbers for path strings."""
	return tuple(fm(float(x)) for x in v)


def brass_grad(d, x1, x2, y=0):
	return d.lin(x1, y, x2, y, [(0, BRASS_D), (0.35, BRASS_L), (0.6, BRASS), (1, BRASS_D)])


# --------------------------------------------------------------------------------------
# shared motifs
# --------------------------------------------------------------------------------------

def paddle_steamer(d, x, y, s=1.0):
	"""Little side-view paddle-steamer, waterline at (x, y), ~64 wide at s=1."""
	with G(d, transform=T(x, y, s)):
		# smoke
		d.blob([(-14, -44), (-6, -52), (4, -50), (10, -58), (20, -52), (14, -42), (0, -40)], "#e8eef4", opacity=0.85)
		# twin smokestacks
		for sx in (-11, -1):
			d.rect(sx, -42, 7, 22, "#26232c", stroke=INK, stroke_width=1.8)
			d.rect(sx, -42, 7, 4, "#c0392b")
		# cabins
		d.rect(-22, -22, 36, 11, "#f4f1e6", stroke=INK, stroke_width=1.8)
		d.rect(-16, -29, 24, 8, "#f4f1e6", stroke=INK, stroke_width=1.8)
		for k in range(4):
			d.rect(-19 + k * 8, -19, 4, 5, YUZU)
		# stern paddle wheel (red)
		d.circle(24, -7, 11, "#c0392b", stroke=INK, stroke_width=2)
		dd = ""
		for k in range(4):
			a = math.radians(k * 45)
			dd += "M%s %s L%s %s " % P(24 - math.cos(a) * 10, -7 - math.sin(a) * 10, 24 + math.cos(a) * 10, -7 + math.sin(a) * 10)
		d.spath(dd, "#7a1a18", 1.6)
		d.circle(24, -7, 3, GOLD, stroke=INK, stroke_width=1.2)
		# hull
		d.path("M-32 -11 L18 -11 L14 2 L-26 2 Z", "#f4f1e6", stroke=INK, stroke_width=2, stroke_linejoin="round")
		d.path("M-30 -5 L16 -5 L15 -2 L-28 -2 Z", TEAL_PAINT)
		# water
		d.spath("M-38 4 q5 -3 10 0 t10 0 t10 0 t10 0 t10 0 t10 0 t10 0 t10 0", "#6fe3dc", 2.2)


def chef_hat(d, x, y, s=1.0):
	"""Puffy white chef's hat, band bottom-center at (x, y), ~56 wide at s=1."""
	with G(d, transform=T(x, y, s)):
		puff = [(-20, -4), (-28, -18), (-24, -34), (-10, -40), (0, -46), (12, -42), (26, -34), (28, -18), (20, -4)]
		d.blob(puff, "#ffffff", stroke=INK, stroke_width=3.2)
		d.spath("M-10 -12 Q-12 -26 -6 -36 M8 -12 Q10 -26 6 -38", "#c8ccd8", 2.2)
		d.path("M-22 -8 L22 -8 L20 10 L-20 10 Z", "#f4f4f8", stroke=INK, stroke_width=3.2, stroke_linejoin="round")
		d.spath("M-12 -6 L-12 8 M0 -6 L0 8 M12 -6 L12 8", "#c8ccd8", 2)


def brass_horn(d, x0, y0, x1, y1, bell_r, s_w=7, rot_bell=None):
	"""Flared brass horn from a thin neck (x0,y0) to a bell centered (x1,y1)."""
	ang = math.atan2(y1 - y0, x1 - x0)
	nx, ny = -math.sin(ang), math.cos(ang)
	mx, my = (x0 + x1) / 2, (y0 + y1) / 2
	L = math.hypot(x1 - x0, y1 - y0)
	w0 = s_w / 2
	# cone flanks with a slight concave flare
	a1 = (x0 + nx * w0, y0 + ny * w0)
	a2 = (x0 - nx * w0, y0 - ny * w0)
	b1 = (x1 + nx * bell_r, y1 + ny * bell_r)
	b2 = (x1 - nx * bell_r, y1 - ny * bell_r)
	c1 = (mx + nx * (w0 + bell_r * 0.18) - math.cos(ang) * L * 0.05, my + ny * (w0 + bell_r * 0.18) - math.sin(ang) * L * 0.05)
	c2 = (mx - nx * (w0 + bell_r * 0.18) - math.cos(ang) * L * 0.05, my - ny * (w0 + bell_r * 0.18) - math.sin(ang) * L * 0.05)
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % P(a1[0], a1[1], c1[0], c1[1], b1[0], b1[1], b2[0], b2[1], c2[0], c2[1], a2[0], a2[1]),
		d.lin(x0 + nx * bell_r, y0 + ny * bell_r, x0 - nx * bell_r, y0 - ny * bell_r,
			[(0, BRASS_D), (0.3, BRASS_L), (0.55, BRASS), (1, BRASS_D)]),
		stroke=INK, stroke_width=3, stroke_linejoin="round")
	deg = math.degrees(ang) if rot_bell is None else rot_bell
	with G(d, transform=T(x1, y1, 1, deg)):
		d.ellipse(0, 0, bell_r * 0.32, bell_r, BRASS, stroke=INK, stroke_width=3)
		d.ellipse(bell_r * 0.04, 0, bell_r * 0.2, bell_r * 0.78, "#5a3a10")
		d.ellipse(-bell_r * 0.08, -bell_r * 0.5, bell_r * 0.08, bell_r * 0.25, "#fff4c8", opacity=0.7)


def z_shape(d, x, y, s, fill="#e6f6ff", shade="#7fbfe6", sw=3.2):
	"""A bold letter-Z built as a polygon (no text). (x, y) = top-left, s = size."""
	pts_ = [(0, 0), (1, 0), (1, 0.24), (0.42, 0.76), (1, 0.76), (1, 1), (0, 1), (0, 0.76), (0.58, 0.24), (0, 0.24)]
	d.poly([(x + px * s + s * 0.08, y + py * s + s * 0.08) for px, py in pts_], shade, stroke=INK, stroke_width=sw, stroke_linejoin="round")
	d.poly([(x + px * s, y + py * s) for px, py in pts_], fill, stroke=INK, stroke_width=sw, stroke_linejoin="round")


def coal_lump(d, cx, cy, r, rng, n=6):
	p = B.blob_pts(cx, cy, r, r * 0.78, rng, n=n, jitter=0.22, rot=rng.uniform(0, 6.28))
	d.poly(p, COAL, stroke=INK, stroke_width=2)
	d.poly([p[0], p[1], (cx, cy - r * 0.1)], COAL_L, opacity=0.9)
	d.poly([p[-1], p[0], (cx, cy - r * 0.1)], "#34333d")


def fringe(d, pts_list, length, color, sw=2.4, outward=1):
	"""Short fringe strands along a polyline (normal to it)."""
	dd = ""
	for i in range(len(pts_list) - 1):
		(x0, y0), (x1, y1) = pts_list[i], pts_list[i + 1]
		L = math.hypot(x1 - x0, y1 - y0)
		n = max(1, int(L / 6))
		nx, ny = (y1 - y0) / L * outward, -(x1 - x0) / L * outward
		for k in range(n):
			t = (k + 0.5) / n
			px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
			dd += "M%s %s l%s %s " % P(px, py, nx * length, ny * length)
	d.spath(dd, INK, sw + 2.2)
	d.spath(dd, color, sw)


def embroidery(d, spots, r=5.0, color=SHAWL_EMB):
	dd = ""
	for (x, y) in spots:
		dd += "M%s %s L%s %s L%s %s L%s %s Z " % P(x, y - r, x + r * 0.6, y, x, y + r, x - r * 0.6, y)
	d.path(dd, color)
	dd = ""
	for (x, y) in spots:
		dd += "M%s %s l0.1 0 " % P(x, y)
	d.spath(dd, SHAWL_L, 2.2)


def water_drop(d, x, y, r, color="#8fe0f0"):
	d.path("M%s %s Q%s %s %s %s A%s %s 0 1 1 %s %s Q%s %s %s %s Z" % P(
		x, y - r * 2, x + r, y - r * 0.4, x + r, y, r, r, x - r, y, x - r, y - r * 0.4, x, y - r * 2),
		color, stroke=INK, stroke_width=2)


# --------------------------------------------------------------------------------------
# icons
# --------------------------------------------------------------------------------------

def clue_rules2(d):
	"""Mudlark Rules: a painted ship's notice board hung on a rope, steamer + Snapjaw header, six rules."""
	rng = random.Random(301)
	ishadow(d, 100, 188, 62, 8)
	# rope + nail
	d.spath("M58 44 L100 12 L142 44", INK, 7)
	d.spath("M58 44 L100 12 L142 44", "#c9a066", 3.6)
	d.spath("M58 44 L100 12 L142 44", "#8a6a3a", 1.4, stroke_dasharray="3 4")
	d.circle(100, 12, 5.5, GOLD, stroke=INK, stroke_width=2.5)
	with G(d, transform="rotate(4 100 110)"):
		d.rect(30, 38, 140, 146, d.vlin(38, 184, [(0, TEAL_PAINT), (1, TEAL_PAINT_D)]), rx=12, stroke=INK, stroke_width=OL)
		d.rect(36, 44, 128, 6, "#ffffff", rx=3, opacity=0.25)
		# header: night-blue band with the paddle-steamer and the crest
		d.rect(38, 46, 124, 38, d.vlin(46, 84, [(0, "#2a3a66"), (1, "#18203e")]), rx=6, stroke=INK, stroke_width=2.5)
		paddle_steamer(d, 82, 76, 0.78)
		snapjaw_crest(d, 140, 66, 0.2)
		# paper sheet with the six rules
		d.rect(40, 90, 120, 88, PAPER, rx=4, stroke=INK, stroke_width=2.5)
		cols = ["#e8553d", YUZU, "#2bb7b3", "#9a6aff", "#e8553d", "#3a7aa8"]
		for i in range(6):
			y = 99 + i * 13.4
			d.circle(50, y, 3.8, cols[i], stroke=INK, stroke_width=1.4)
			glyphs(d, 58, y - 5.4, 92 - (i % 3) * 12, 11, 1, SCRIBBLE, rng, 1.7)
		# brass rivets
		for (x, y) in [(38, 42), (162, 42), (38, 176), (162, 176)]:
			d.circle(x, y, 3.6, GOLD, stroke=INK, stroke_width=1.6)


def clue_snapjaw_file2(d):
	"""Snapjaw File #2: case folder with the victim photo, red stamp, crest and a big '2' sticker."""
	rng = random.Random(302)
	ishadow(d)
	d.path("M30 52 L80 52 L90 40 L150 40 Q158 40 158 48 L158 64 Z", "#b7843a", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	with G(d, transform="rotate(-5 100 90)"):
		d.rect(48, 28, 104, 120, PAPER, stroke=INK, stroke_width=3)
		glyphs(d, 60, 100, 80, 36, 3, "#6a5a4a", rng, 1.8)
		# photo: capybara in a nurse cap
		d.rect(60, 40, 44, 50, "#d6ecd8", stroke=INK, stroke_width=2.5)
		d.ellipse(82, 76, 15, 12, "#b07a50")
		d.ellipse(82, 82, 8, 4, "#7a4e30")
		d.path("M70 66 Q82 56 94 66 L92 71 L72 71 Z", "#ffffff", stroke=INK, stroke_width=1.6)
		d.rect(80.5, 60, 3, 9, "#3aa860")
		d.rect(77.5, 63, 9, 3, "#3aa860")
		d.rect(70, 84, 24, 6, "#8fd0e8")
		d.spath("M112 46 L142 46 M112 56 L136 56 M112 66 L140 66 M112 76 L130 76", "#6a5a4a", 2.2)
		d.path("M74 34 L88 34 L88 46 L74 46 Z", "none", stroke="#8a8a92", stroke_width=3)
	d.path("M26 60 L162 60 Q170 60 168 68 L156 170 Q155 176 148 176 L36 176 Q30 176 29 170 L20 68 Q19 60 26 60 Z",
		d.vlin(60, 176, [(0, "#f2c66a"), (1, "#d09440")]), stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M30 66 L158 66", "none", stroke="#fff0c0", stroke_width=3, opacity=0.7)
	# two red stripes along the folder's bottom = "volume two"
	d.rect(26, 154, 132, 5, "#d0302a", opacity=0.9)
	d.rect(27, 162, 130, 5, "#d0302a", opacity=0.9)
	with G(d, transform="rotate(-12 70 112)"):
		d.rect(34, 94, 72, 30, "none", stroke="#d0302a", stroke_width=4, rx=4)
		glyphs(d, 42, 100, 56, 18, 1, "#d0302a", rng, 2.6)
	snapjaw_crest(d, 56, 140, 0.22)
	# the "2" sticker (shapes only)
	d.circle(132, 120, 30, "#000000", opacity=0.18)
	d.circle(130, 117, 30, "#fff7e0", stroke=INK, stroke_width=OL)
	d.circle(130, 117, 24, "none", stroke="#d0302a", stroke_width=3)
	two = "M119 108 Q119 98 130 98 Q141 98 141 108 Q141 116 132 122 L119 135 L142 135"
	d.spath(two, INK, 12)
	d.spath(two, "#d0302a", 6.5)


def clue_rounds_log(d):
	"""Marigold's Rounds Log: clipboard, timed entries, the last line trails off into an ink smear."""
	rng = random.Random(303)
	ishadow(d, 100, 190, 60, 7)
	d.rect(36, 22, 128, 166, d.vlin(22, 188, [(0, WOOD_L), (1, WOOD_D)]), rx=10, stroke=INK, stroke_width=OL)
	with G(d, transform="rotate(-2 100 110)"):
		d.rect(48, 40, 104, 138, PAPER, rx=2, stroke=INK, stroke_width=2.5)
		# header: green cross + title scribble
		d.rect(56, 50, 14, 14, "#3aa860", rx=2)
		d.rect(61, 52, 4, 10, "#ffffff")
		d.rect(58, 55, 10, 4, "#ffffff")
		glyphs(d, 76, 50, 64, 13, 1, "#2f5e37", rng, 2.0)
		d.line(56, 70, 144, 70, "#9ab8c8", 1.6)
		# three timed entries (clock bullet + scribbles)
		for i, y in enumerate([84, 102, 120]):
			d.circle(62, y, 5.5, "#ffffff", stroke="#24306a", stroke_width=1.8)
			d.spath("M62 %s L62 %s L%s %s" % P(y, y - 3.5, 62 + (2.5 if i else 3), y + (1 if i else 0)), "#24306a", 1.4)
			glyphs(d, 72, y - 6, 70 if i < 2 else 58, 12, 1, "#24306a", rng, 1.8)
		# last line trails off ...
		trail = smooth([(58, 140), (72, 137), (86, 142), (100, 139), (110, 146), (118, 156), (124, 162)], False)
		d.spath(trail, "#24306a", 2.2)
		# ... into a smear
		d.blob([(116, 158), (128, 150), (142, 154), (146, 166), (136, 174), (120, 172)], "#24306a", opacity=0.9)
		d.path("M120 168 Q100 172 84 170 Q100 166 118 162 Z", "#24306a", opacity=0.55)
		d.path("M132 156 Q138 158 140 164", "none", stroke="#6a7ac8", stroke_width=2, stroke_linecap="round", opacity=0.8)
	# metal clip
	d.path("M70 30 L130 30 L124 48 L76 48 Z", d.vlin(30, 48, [(0, "#e4e8ee"), (1, CHROME_D)]), stroke=INK, stroke_width=3, stroke_linejoin="round")
	d.rect(82, 14, 36, 22, CHROME, rx=7, stroke=INK, stroke_width=3)
	d.rect(92, 20, 16, 8, "#4a3a2a", rx=4)
	d.spath("M76 44 L124 44", "#ffffff", 1.6, opacity=0.6)


def clue_lilac_thread(d):
	"""Lilac Silk Scrap: a little triangle of lilac silk on the cot sheet. Hemmed + fringed like the shawl's
	bottom-right corner, with one perfectly straight cut edge."""
	ishadow(d, 100, 178, 70, 9)
	# white cot sheet it was found on
	d.path("M10 112 Q18 92 54 88 L190 80 L190 160 Q120 172 18 168 Q8 146 10 112 Z", "#eef4f8", stroke=INK, stroke_width=3, stroke_linejoin="round")
	d.spath("M20 138 Q100 130 188 126", "#a8c8dc", 2.4)
	d.spath("M24 154 Q100 148 188 144", "#a8c8dc", 2.4)
	# the scrap: corner at bottom-right, straight cut from (150,30) to (32,144)
	cut_a, cut_b, corner = (150, 30), (32, 144), (158, 150)
	shape = "M%s %s L%s %s Q92 156 %s %s Q164 88 %s %s Z" % P(cut_a[0], cut_a[1], cut_b[0], cut_b[1], corner[0], corner[1], cut_a[0], cut_a[1])
	# fringe on the bottom hem only (same as the shawl)
	fringe(d, [(cut_b[0] + 4, cut_b[1] + 2), (92, 153), (corner[0] - 2, corner[1])], 11, SHAWL_D, 2.4, outward=-1)
	d.path(shape, d.lin(40, 150, 150, 40, [(0, SHAWL_D), (0.35, SHAWL), (0.6, SHAWL_L), (0.8, SHAWL), (1, SHAWL_D)]),
		stroke=INK, stroke_width=OL, stroke_linejoin="round")
	# silk folds + sheen
	d.spath("M70 140 Q112 128 150 136", SHAWL_D, 3, opacity=0.55)
	d.spath("M104 116 Q124 96 140 70", "#ffffff", 4.5, opacity=0.5)
	d.spath("M44 146 Q96 152 152 146", SHAWL_EMB, 2.4, stroke_dasharray="5 4")
	embroidery(d, [(132, 126), (100, 134), (144, 98), (116, 108), (72, 138), (146, 62)], 6)
	# frayed hairs on the straight cut
	d.spath("M120 61 l-6 -5 M92 88 l-6 -6 M64 115 l-6 -5", SHAWL_D, 1.8)
	for (x, y, r) in [(126, 88, 10), (66, 74, 7), (176, 54, 8)]:
		sparkle(d, x, y, r, "#ffffff", 1.0, glow_c="#c9a0ff")


def clue_grub_ghost(d):
	"""Grub's Ghost Story: speech bubble, dark ship corridor at 6:00, a hunched ghostly figure with a horn; chef's hat badge."""
	ishadow(d, 100, 186, 60, 8)
	bubble = "M30 22 L170 22 Q182 22 182 34 L182 126 Q182 138 170 138 L84 138 L54 170 L60 138 L30 138 Q18 138 18 126 L18 34 Q18 22 30 22 Z"
	d.path(bubble, "#fffdf6", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.rect(30, 34, 140, 92, d.vlin(34, 126, [(0, "#1a2244"), (1, "#0e1428")]), rx=6)
	# corridor: wooden floor + office door, slightly ajar
	d.path("M30 108 L170 108 L170 126 Q170 126 164 126 L36 126 Q30 126 30 120 Z", "#2a1e26")
	d.spath("M30 108 L170 108", "#4a3a44", 2)
	d.rect(124, 46, 36, 62, "#3a2620", stroke=INK, stroke_width=2.5)
	d.path("M124 46 L136 50 L136 104 L124 108 Z", "#05060c")
	d.rect(132, 52, 24, 26, "none", stroke="#5a3a2c", stroke_width=2)
	d.circle(150, 82, 2.5, GOLD)
	# glowing, hunched sheet-ghost walking toward the door
	glow(d, 80, 86, 40, "#bfe8ff", 0.5)
	ghost = [(106, 114), (104, 92), (102, 74), (96, 58), (82, 52), (66, 58), (56, 74), (52, 96), (50, 114)]
	d.path(smooth(ghost, False) + " Q54 106 60 114 Q66 106 72 114 Q78 106 84 114 Q90 106 96 114 Q101 106 106 114 Z", "#e8f4ff",
		stroke=INK, stroke_width=3, stroke_linejoin="round", opacity=0.95)
	d.path("M62 76 Q66 62 80 57 Q70 66 68 80 Z", "#ffffff", opacity=0.85)
	d.ellipse(89, 70, 3.2, 4.8, "#1a2244")
	d.ellipse(98, 70, 2.8, 4.4, "#1a2244")
	d.ellipse(95, 82, 3, 3.6, "#1a2244")
	# the "big trumpet thing" carried at its waist
	brass_horn(d, 62, 100, 116, 94, 14, 6)
	d.blob([(74, 92), (86, 90), (92, 98), (82, 104), (72, 100)], "#dcecfa", stroke=INK, stroke_width=2.6)
	# motion puffs behind it
	d.spath("M40 70 l-6 0 M42 84 l-9 0 M40 98 l-6 0", "#bfe8ff", 3, opacity=0.8)
	# 6:00 clock
	d.circle(44, 48, 10, "#fffdf6", stroke=INK, stroke_width=2)
	d.line(44, 48, 44, 41, INK, 1.8)
	d.line(44, 48, 44, 53, INK, 2.4)
	# chef's hat badge (the witness)
	chef_hat(d, 150, 170, 0.72)


def clue_anchor_doorstop(d):
	"""Anchor Doorstop: a heavy brass anchor, dug out of coal, coal dust in one fluke."""
	rng = random.Random(306)
	ishadow(d, 100, 186, 72, 9)
	# coal behind
	for (x, y, r) in [(42, 166, 14), (160, 168, 15), (70, 174, 12), (132, 176, 12)]:
		coal_lump(d, x, y, r, rng)
	bg = brass_grad(d, 30, 170)
	# arms (thick arc)
	arc = "M44 112 Q50 164 100 164 Q150 164 156 112"
	d.spath(arc, INK, 25)
	d.spath(arc, bg, 16)
	d.spath("M52 126 Q64 156 100 156", BRASS_L, 3, opacity=0.7)
	# flukes
	for side in (-1, 1):
		x = 100 + side * 56
		d.path("M%s %s L%s %s L%s %s Q%s %s %s %s Z" % P(x - side * 16, 122, x + side * 2, 90, x + side * 20, 120, x + side * 2, 116, x - side * 16, 122),
			bg, stroke=INK, stroke_width=OL, stroke_linejoin="round")
	# shank
	d.rect(90, 52, 20, 104, d.lin(90, 0, 110, 0, [(0, BRASS_D), (0.35, BRASS_L), (0.7, BRASS), (1, BRASS_D)]), rx=4,
		stroke=INK, stroke_width=OL)
	d.circle(100, 162, 13, d.brad([(0, BRASS_L), (0.6, BRASS), (1, BRASS_D)], cx=0.4, cy=0.35), stroke=INK, stroke_width=OL)
	# stock (cross bar)
	d.rect(50, 54, 100, 14, d.vlin(54, 68, [(0, BRASS_L), (0.5, BRASS), (1, BRASS_D)]), rx=5, stroke=INK, stroke_width=OL)
	for x in (48, 152):
		d.circle(x, 61, 9, d.brad([(0, BRASS_L), (0.6, BRASS), (1, BRASS_D)], cx=0.4, cy=0.35), stroke=INK, stroke_width=OL)
	# ring
	d.circle(100, 32, 16, "none", stroke=INK, stroke_width=13)
	d.circle(100, 32, 16, "none", stroke=BRASS, stroke_width=6.5)
	d.spath("M88 26 Q92 18 102 17", BRASS_L, 2.6)
	d.rect(92, 44, 16, 12, BRASS_D, stroke=INK, stroke_width=3, rx=2)
	# shine
	d.spath("M95 74 L95 138", "#fff4c8", 3, opacity=0.8)
	sparkle(d, 120, 84, 9, "#ffffff", 1.0, glow_c="#fff0a0")
	sparkle(d, 140, 136, 6, "#ffffff", 1.0)
	# coal dust caught in the left fluke
	dd = ""
	for _ in range(34):
		dd += "M%s %s l0.1 0 " % P(rng.uniform(38, 60), rng.uniform(100, 120))
	d.spath(dd, COAL, 3.4, opacity=0.85)
	d.path("M42 118 Q48 108 56 112 Q52 118 44 120 Z", COAL, opacity=0.75)
	# coal in front
	for (x, y, r) in [(26, 178, 11), (176, 180, 10), (100, 184, 8)]:
		coal_lump(d, x, y, r, rng)


def boot_print_shape(d, x, y, s, rot, fill, tread):
	with G(d, transform=T(x, y, s, rot)):
		sole = smooth([(0, -46), (14, -42), (19, -26), (16, -6), (11, 4), (-11, 4), (-16, -6), (-19, -26), (-14, -42)], True)
		d.path(sole, fill)
		d.rect(-14, 12, 28, 26, fill, rx=7)
		dd = ""
		for k in range(5):
			yy = -36 + k * 8
			ww = 14 if k in (1, 2) else 11
			dd += "M%s %s L%s %s " % P(-ww, yy, ww, yy)
		for k in range(3):
			yy = 18 + k * 7
			dd += "M-9 %s L9 %s " % P(yy, yy)
		d.spath(dd, tread, 3.2)


def clue_boot_prints(d):
	"""Giant Boot Prints: two huge, close-together coal-dust boot prints on the boiler-room planks."""
	rng = random.Random(307)
	ishadow(d, 100, 188, 76, 8)
	d.rect(16, 26, 168, 156, d.vlin(26, 182, [(0, "#9a6a40"), (1, "#6a4426")]), rx=14, stroke=INK, stroke_width=OL)
	for y in (56, 88, 120, 152):
		d.line(20, y, 180, y, "#4a2e18", 2.4)
	for (x, y) in [(60, 36), (150, 72), (40, 104), (120, 136), (170, 164)]:
		d.line(x, y, x, y + 14, "#4a2e18", 2)
	# coal dust layer
	p = B.blob_pts(100, 104, 78, 70, rng, n=12, jitter=0.12)
	d.blob(p, "#3a3a44", opacity=0.85)
	dd = ""
	for _ in range(120):
		a = rng.uniform(0, 6.28)
		r = rng.uniform(0.2, 1.0) ** 0.5
		dd += "M%s %s l0.1 0 " % P(100 + math.cos(a) * 80 * r, 104 + math.sin(a) * 72 * r)
	d.spath(dd, "#6a6a76", 2.6, opacity=0.8)
	# the prints (shallow, close together)
	boot_print_shape(d, 76, 90, 1.25, -6, "#101014", "#40404c")
	boot_print_shape(d, 126, 118, 1.25, 6, "#101014", "#40404c")
	# coal lumps on the edge
	for (x, y, r) in [(160, 40, 10), (174, 54, 7), (30, 166, 8)]:
		coal_lump(d, x, y, r, rng)


def clue_wax_lump(d):
	"""Melted Wax Lump: blackened melted wax in the furnace ash, a little brass end-cap stuck in it."""
	rng = random.Random(308)
	ishadow(d, 100, 184, 76, 9)
	# ash heap
	d.path("M14 176 Q30 128 70 122 Q100 116 132 122 Q172 130 186 176 Z", d.vlin(118, 178, [(0, "#a8a39c"), (1, "#6a655e")]),
		stroke=INK, stroke_width=OL, stroke_linejoin="round")
	dd = ""
	for _ in range(60):
		x = rng.uniform(30, 172)
		dd += "M%s %s l0.1 0 " % P(x, rng.uniform(140, 172))
	d.spath(dd, "#5a5550", 3, opacity=0.7)
	for (x, y, r) in [(40, 160, 6), (162, 156, 7), (120, 168, 5)]:
		glow(d, x, y, r * 3, "#ff8a2a", 0.7)
		d.circle(x, y, r * 0.55, "#ffb040")
	# melted lump (dark burnt crust, a little amber wax showing)
	lump = [(46, 132), (48, 108), (64, 86), (86, 74), (112, 72), (138, 84), (152, 106), (156, 132), (128, 140), (100, 144), (70, 140)]
	d.blob(lump, d.rad(92, 92, 80, [(0, "#4a3a32"), (0.6, "#2a2024"), (1, "#141014")]), stroke=INK, stroke_width=OL)
	# drips running onto the ash
	for (x, y, w, h) in [(60, 132, 9, 16), (132, 136, 8, 12), (98, 140, 10, 10)]:
		d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % P(x - w / 2, y, x - w / 2, y + h, x, y + h, x + w / 2, y + h, x + w / 2, y),
			"#2a2024", stroke=INK, stroke_width=2.5)
	d.blob([(60, 112), (72, 96), (88, 92), (80, 110)], "#a8743a", opacity=0.7)
	d.spath("M66 104 Q76 90 92 86", "#e8b878", 3, opacity=0.8)
	d.spath("M112 82 Q130 86 140 100", "#8a7a74", 3, opacity=0.7)
	d.spath("M78 126 Q100 132 124 124", "#5a4a44", 2.4, opacity=0.8)
	# brass end-cap stuck in it
	with G(d, transform=T(122, 86, 1, -28)):
		d.rect(-14, -12, 28, 22, d.lin(-14, 0, 14, 0, [(0, BRASS_D), (0.35, BRASS_L), (0.65, BRASS), (1, BRASS_D)]),
			stroke=INK, stroke_width=3.2)
		d.ellipse(0, -12, 14, 5, BRASS_L, stroke=INK, stroke_width=3)
		d.ellipse(0, -12, 7, 2.4, BRASS_D)
		d.line(-14, -2, 14, -2, BRASS_D, 2)
	d.blob([(104, 94), (114, 86), (128, 96), (140, 92), (138, 104), (112, 104)], "#1e181c", stroke=INK, stroke_width=2.4)
	sparkle(d, 130, 64, 8, "#fff4c8", 1.0, glow_c="#ffd060")
	# smoke wisps
	d.spath("M70 64 Q62 50 72 40 Q80 30 72 18", "#c8c8d0", 4, opacity=0.6)
	d.spath("M100 60 Q108 48 100 36", "#c8c8d0", 3.4, opacity=0.5)


def big_boot(d, x, y, s, leather, leather_d, sock=True, rng=None):
	"""Side-view work boot, heel-bottom at (x, y), toe to the right; ~92 wide x 120 tall at s=1."""
	with G(d, transform=T(x, y, s)):
		if sock:
			sk = [(4, -114), (0, -128), (10, -140), (24, -136), (34, -146), (48, -134), (52, -116)]
			d.blob(sk, "#f4f4ee", stroke=INK, stroke_width=3.4)
			d.spath("M6 -126 Q24 -120 48 -128", TEAL_PAINT, 4)
			d.spath("M12 -136 Q20 -132 28 -132 M30 -140 Q38 -134 44 -136 M18 -130 L22 -122", "#b8bcc4", 2.4)
		boot = ("M0 0 L0 -108 Q0 -118 10 -118 L46 -118 Q54 -118 54 -110 L54 -58 Q66 -50 80 -42 Q96 -34 96 -16 L96 0 Z")
		d.path(boot, d.lin(0, 0, 96, 0, [(0, leather_d), (0.35, leather), (0.7, leather), (1, leather_d)]),
			stroke=INK, stroke_width=OL / s, stroke_linejoin="round")
		# collar (padded top)
		d.path("M0 -104 L0 -110 Q0 -118 10 -118 L46 -118 Q54 -118 54 -110 L54 -104 Z", light(leather, 0.25), stroke=INK, stroke_width=3 / s)
		# toe cap + heel counter
		d.path("M66 -46 Q86 -38 96 -22 L96 -8 L64 -8 Q58 -30 66 -46 Z", dark(leather, 0.15), stroke=INK, stroke_width=2.6 / s)
		d.path("M0 -8 L0 -40 Q16 -42 22 -30 L22 -8 Z", dark(leather, 0.15), stroke=INK, stroke_width=2.6 / s)
		# laces / eyelets up the front
		dd = ""
		for k in range(5):
			yy = -100 + k * 12
			dd += "M42 %s L58 %s " % P(yy, yy + 6)
		d.spath(dd, "#efe2c0", 3.2 / s)
		for k in range(5):
			d.circle(44, -100 + k * 12, 2.6, GOLD, stroke=INK, stroke_width=1.4 / s)
		d.spath("M10 -96 Q12 -60 10 -24", "#ffffff", 3.4, opacity=0.25)
		# sole with coal-dusted tread
		d.path("M-4 -8 L100 -8 Q104 -8 104 -2 L104 4 Q104 10 98 10 L-2 10 Q-6 10 -6 4 L-6 -2 Q-6 -8 -4 -8 Z", COAL, stroke=INK, stroke_width=3 / s)
		dd = ""
		for k in range(12):
			dd += "M%s 6 l3 -8 " % P(-2 + k * 9)
		d.spath(dd, "#55545e", 2.2)
		if rng:
			dd = ""
			for _ in range(26):
				dd += "M%s %s l0.1 0 " % P(rng.uniform(64, 98), rng.uniform(-30, -10))
			d.spath(dd, COAL, 3, opacity=0.75)


def clue_bruno_boots(d):
	"""Bruno's Spare Boots: an enormous pair of brown boots, coal-dusty soles, socks crammed in the top."""
	rng = random.Random(309)
	ishadow(d, 100, 184, 84, 9)
	big_boot(d, 22, 160, 0.92, "#8a5a36", "#5a3820", True, rng)
	big_boot(d, 58, 178, 1.0, "#a86e40", "#6a4426", True, rng)
	# one crumpled sock flopped over the front boot's collar (leg + foot, teal toe and heel)
	d.spath("M72 66 Q62 48 46 62", INK, 15)
	d.spath("M72 66 Q62 48 46 62", "#f4f4ee", 9.5)
	sock = "M39 60 L54 60 L54 98 Q54 110 42 110 L28 110 Q18 110 18 102 Q18 94 28 94 L39 94 Z"
	d.path(sock, "#f4f4ee", stroke=INK, stroke_width=3.4, stroke_linejoin="round")
	d.path("M28 94 L32 94 L32 110 L28 110 Q18 110 18 102 Q18 94 28 94 Z", TEAL_PAINT)
	d.path("M54 100 Q54 110 44 110 L44 100 Z", TEAL_PAINT)
	d.rect(39, 66, 15, 4.5, TEAL_PAINT)
	d.rect(39, 74, 15, 3, TEAL_PAINT)
	d.path(sock, "none", stroke=INK, stroke_width=3.4, stroke_linejoin="round")
	d.spath("M44 80 Q47 86 44 92 M30 100 Q36 104 42 100", "#c8ccd0", 2)
	# dust puffs
	for (x, y, r) in [(170, 176, 6), (182, 168, 4), (16, 176, 5)]:
		d.circle(x, y, r, "#55545e", opacity=0.6)


def clue_duchess_shawl(d):
	"""Duchess's Shawl: lilac shawl drying on the line, one corner cut clean off in a straight line."""
	ishadow(d, 96, 190, 60, 7)
	# drying line
	d.spath("M4 40 Q100 56 196 36", INK, 6)
	d.spath("M4 40 Q100 56 196 36", "#e8dcc0", 3)
	# missing corner ghost outline
	cut_a, cut_b = (164, 128), (126, 170)
	d.path("M%s %s L%s %s L%s %s Z" % P(cut_a[0], cut_a[1], 166, 172, cut_b[0], cut_b[1]), "#ffffff", opacity=0.18)
	d.spath("M%s %s L%s %s L%s %s" % P(cut_a[0], cut_a[1] + 6, 166, 172, cut_b[0] + 6, cut_b[1]), "#ffffff", 2.4,
		stroke_dasharray="5 5", opacity=0.9)
	# bottom fringe (stops at the cut)
	fringe(d, [(40, 168), (82, 172), (cut_b[0] - 2, cut_b[1])], 11, SHAWL_D, 2.4, outward=-1)
	# shawl body: wavy hanging cloth with a straight cut corner at the lower right
	shape = ("M38 46 Q70 52 100 50 Q132 52 162 44 Q160 88 %s %s L%s %s Q84 174 40 168 Q44 130 36 100 Q34 70 38 46 Z"
		% P(cut_a[0], cut_a[1], cut_b[0], cut_b[1]))
	d.path(shape, d.lin(36, 0, 166, 0, [(0, SHAWL_D), (0.2, SHAWL), (0.4, SHAWL_L), (0.6, SHAWL), (0.8, SHAWL_L), (1, SHAWL_D)]),
		stroke=INK, stroke_width=OL, stroke_linejoin="round")
	# folds
	d.spath("M68 56 Q64 110 70 168 M104 54 Q100 110 106 168 M138 52 Q134 90 140 140", SHAWL_D, 3, opacity=0.55)
	# embroidered border + motifs
	d.spath("M44 158 Q84 164 %s %s" % P(cut_b[0] - 4, cut_b[1] - 10), SHAWL_EMB, 2.4, stroke_dasharray="5 4")
	embroidery(d, [(56, 82), (90, 96), (124, 84), (72, 124), (108, 132), (146, 112), (52, 140)], 6)
	# the straight cut, emphasised
	d.line(cut_a[0], cut_a[1], cut_b[0], cut_b[1], "#ffffff", 2, opacity=0.6)
	# clothes pegs
	for (x, y, rot) in [(56, 48, -4), (144, 46, 6)]:
		with G(d, transform=T(x, y, 1, rot)):
			d.rect(-6, -14, 12, 28, "#d8a868", rx=3, stroke=INK, stroke_width=2.6)
			d.line(0, -12, 0, 12, "#8a5a30", 1.6)
			d.rect(-7, -3, 14, 4, CHROME, stroke=INK, stroke_width=1.4)
	# drips
	water_drop(d, 60, 186, 4)
	water_drop(d, 98, 192, 3.4)


def clue_snore_alibi(d):
	"""Tumble's Snoring: snores (Z shapes) coming through the wooden cabin wall."""
	ishadow(d, 100, 186, 70, 8)
	d.rect(24, 24, 140, 156, "#6a4426", rx=8, stroke=INK, stroke_width=OL)
	tones = ["#a8703e", "#b87e48", "#9a6638", "#b4784a", "#a26c3c"]
	for k in range(5):
		x = 29 + k * 26.5
		d.rect(x, 29, 24, 146, d.vlin(29, 175, [(0, light(tones[k], 0.12)), (1, dark(tones[k], 0.12))]), rx=3)
		d.circle(x + 12, 40, 2, "#4a2e18")
		d.circle(x + 12, 164, 2, "#4a2e18")
		d.spath("M%s %s Q%s %s %s %s" % P(x + 7, 60 + k * 7, x + 10, 90, x + 6, 128 - k * 5), dark(tones[k], 0.25), 1.6, opacity=0.7)
	d.rect(24, 24, 140, 156, "none", rx=8, stroke=INK, stroke_width=OL)
	# the wall shakes with every snore
	d.spath("M16 60 Q10 74 16 88 M10 54 Q2 74 10 94 M16 120 Q10 134 16 148 M10 114 Q2 134 10 154", "#ffe8b0", 3, opacity=0.9)
	d.spath("M50 188 l4 -6 M80 190 l0 -7 M112 190 l-3 -6 M140 188 l-4 -6", "#ffe8b0", 3, opacity=0.9)
	# Zzz (shapes) drifting out through the wall
	z_shape(d, 74, 98, 24)
	z_shape(d, 104, 58, 34)
	z_shape(d, 140, 16, 46)


def clue_pepper_log(d):
	"""Pepper's Snore Log: reporter's notebook with evenly spaced tick marks, plus her stopwatch."""
	rng = random.Random(312)
	ishadow(d, 100, 188, 72, 8)
	with G(d, transform="rotate(-7 90 100)"):
		d.rect(26, 26, 116, 154, "#fffdf2", rx=4, stroke=INK, stroke_width=OL)
		d.line(42, 34, 42, 176, "#e88a8a", 1.8)
		for k in range(7):
			d.line(30, 54 + k * 18, 138, 54 + k * 18, "#a8c8e0", 1.6)
		# rows: time scribble + evenly spaced ticks; the last row stops halfway
		for r in range(6):
			y = 52 + r * 18
			glyphs(d, 46, y - 11, 22, 10, 1, SCRIBBLE, rng, 1.6)
			n = 6 if r < 5 else 3
			dd = ""
			for k in range(n):
				dd += "M%s %s l0 -11 " % P(76 + k * 10, y - 1)
			d.spath(dd, "#24306a", 2.6)
		d.spath("M108 136 L134 136", "#c0392b", 2.6)
		# spiral binding
		for k in range(8):
			x = 36 + k * 13.4
			d.rect(x - 3, 18, 6, 16, "none", rx=3, stroke=INK, stroke_width=5)
			d.rect(x - 3, 18, 6, 16, "none", rx=3, stroke=CHROME, stroke_width=2.4)
	# stopwatch
	cx, cy, R = 142, 132, 40
	d.rect(cx - 7, cy - R - 16, 14, 14, CHROME, stroke=INK, stroke_width=3, rx=2)
	d.circle(cx, cy - R - 22, 7, "none", stroke=INK, stroke_width=6)
	d.circle(cx, cy - R - 22, 7, "none", stroke=CHROME, stroke_width=2.6)
	with G(d, transform=T(cx, cy, 1, 42)):
		d.rect(-5, -R - 10, 10, 12, CHROME_D, stroke=INK, stroke_width=2.6, rx=2)
	d.circle(cx, cy, R, d.brad([(0, "#f4f6fa"), (0.7, CHROME), (1, CHROME_D)], cx=0.35, cy=0.3), stroke=INK, stroke_width=OL)
	d.circle(cx, cy, R - 8, "#fffdf6", stroke=CHROME_D, stroke_width=2.4)
	dd = ""
	for k in range(12):
		a = math.radians(k * 30 - 90)
		r1 = R - 16 if k % 3 == 0 else R - 13
		dd += "M%s %s L%s %s " % P(cx + math.cos(a) * r1, cy + math.sin(a) * r1, cx + math.cos(a) * (R - 10), cy + math.sin(a) * (R - 10))
	d.spath(dd, "#3a3040", 2.2)
	# red sweep hand on "4" (every four minutes)
	a = math.radians(4 * 30 - 90)
	d.line(cx, cy, cx + math.cos(a) * (R - 13), cy + math.sin(a) * (R - 13), "#d0302a", 3)
	d.line(cx, cy, cx, cy - (R - 18), INK, 2.4)
	d.circle(cx, cy, 4, "#d0302a", stroke=INK, stroke_width=1.4)
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % P(cx - 26, cy - 10, cx - 22, cy - 26, cx - 6, cy - 30, cx - 18, cy - 22, cx - 26, cy - 10),
		"#ffffff", opacity=0.8)


def clue_tumble_bunk(d):
	"""Tumble's Bunk: neatly made berth with an untouched pillow; four small round dents in the rug."""
	ishadow(d, 100, 188, 80, 8)
	# rug (in front, perspective)
	d.path("M30 136 L170 136 L188 182 L12 182 Z", "#a8453a", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M40 142 L160 142 L174 176 L26 176 Z", "none", stroke="#e8c060", stroke_width=3)
	d.path("M54 148 L146 148 L156 170 L44 170 Z", "#8a3428")
	d.path("M100 150 L114 159 L100 168 L86 159 Z", "#e8c060", opacity=0.7)
	fringe(d, [(14, 182), (186, 182)], 7, "#efe2c0", 2.2, outward=-1)
	# bunk frame
	d.rect(18, 26, 14, 112, WOOD_D, rx=3, stroke=INK, stroke_width=3.4)
	d.rect(168, 56, 14, 82, WOOD_D, rx=3, stroke=INK, stroke_width=3.4)
	d.rect(14, 20, 22, 10, WOOD, rx=3, stroke=INK, stroke_width=3)
	d.rect(164, 50, 22, 10, WOOD, rx=3, stroke=INK, stroke_width=3)
	d.rect(26, 40, 148, 30, d.vlin(40, 70, [(0, "#d0a070"), (1, "#a8703e")]), rx=4, stroke=INK, stroke_width=3.4)  # headboard rail behind
	# mattress + neatly made blanket
	d.rect(26, 84, 150, 22, "#eef0f4", rx=6, stroke=INK, stroke_width=3.4)
	d.path("M60 74 L176 74 Q180 74 180 80 L180 112 L60 112 Z", d.vlin(74, 112, [(0, "#b8c6ce"), (1, "#8a9aa6")]), stroke=INK, stroke_width=3.4)
	d.rect(60, 72, 22, 40, "#f4f4ee", stroke=INK, stroke_width=3)  # folded-down sheet edge
	d.spath("M100 86 L176 86 M100 98 L176 98", "#6a7a88", 2.2, opacity=0.7)
	# smooth, untouched pillow
	d.blob([(30, 80), (36, 64), (52, 60), (60, 66), (62, 82), (50, 88), (34, 88)], "#ffffff", stroke=INK, stroke_width=3.4)
	d.spath("M36 70 Q44 64 54 66", "#dde4ee", 2.6)
	sparkle(d, 44, 52, 6, "#ffffff", 1.0, glow_c="#bfe8ff")
	# bed side rail
	d.rect(22, 106, 160, 16, d.vlin(106, 122, [(0, WOOD_L), (1, WOOD)]), rx=4, stroke=INK, stroke_width=3.4)
	d.spath("M30 112 L174 112", "#ffffff", 1.6, opacity=0.35)
	# four small round dents (two by two)
	for (x, y) in [(76, 150), (124, 150), (70, 168), (130, 168)]:
		d.ellipse(x, y, 9, 4.6, "#4a1a14")
		d.ellipse(x, y - 1.4, 7, 3, "#2a0e0a")
		d.spath("M%s %s Q%s %s %s %s" % P(x - 8, y + 2, x, y + 6.5, x + 8, y + 2), "#d07060", 1.8)


def clue_dictaphone(d):
	"""Echo-Matic Dictaphone: brass horn, wooden base on four round feet, empty mandrel, REPEAT lever ON."""
	ishadow(d, 100, 184, 72, 8)
	# back feet (seen in the gap under the box)
	for x in (78, 128):
		d.circle(x, 160, 6.5, BRASS_D, stroke=INK, stroke_width=2.6)
	# base box: front face + top face
	top = [(40, 112), (148, 112), (164, 98), (56, 98)]
	d.poly(top, "#8a4a2a", stroke=INK, stroke_width=3.5, stroke_linejoin="round")
	d.poly([(148, 112), (164, 98), (164, 140), (148, 156)], "#5a2e18", stroke=INK, stroke_width=3.5, stroke_linejoin="round")
	d.rect(40, 112, 108, 44, d.vlin(112, 156, [(0, "#a85a32"), (1, "#7a3c20")]), stroke=INK, stroke_width=OL)
	d.rect(40, 112, 108, 6, BRASS, stroke=INK, stroke_width=2)
	d.rect(40, 150, 108, 6, BRASS_D, stroke=INK, stroke_width=2)
	# front plate with the Snapjaw crest
	d.rect(70, 122, 48, 24, "#2f5e37", rx=4, stroke=GOLD, stroke_width=2.4)
	snapjaw_crest(d, 94, 134, 0.18, ring=False)
	# front feet
	for x in (50, 138):
		d.circle(x, 162, 8.5, d.brad([(0, BRASS_L), (0.6, BRASS), (1, BRASS_D)], cx=0.35, cy=0.3), stroke=INK, stroke_width=3)
	# mechanism on top: two brass posts with an EMPTY mandrel rod between them
	for x in (66, 128):
		d.rect(x - 4, 80, 8, 26, d.lin(x - 4, 0, x + 4, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS)]), stroke=INK, stroke_width=2.6, rx=2)
	d.line(66, 86, 128, 86, INK, 6)
	d.line(66, 86, 128, 86, CHROME, 2.6)
	d.spath("M76 92 L118 92", "#000000", 3, opacity=0.25)
	# reproducer carriage + horn
	d.rect(86, 70, 22, 14, BRASS, rx=3, stroke=INK, stroke_width=2.8)
	brass_horn(d, 96, 72, 52, 34, 30, 7)
	# REPEAT lever on the right, switched ON
	d.rect(140, 96, 22, 8, "#3a3a40", rx=3, stroke=INK, stroke_width=2)
	d.line(146, 100, 164, 74, INK, 6)
	d.line(146, 100, 164, 74, CHROME, 2.6)
	d.circle(165, 72, 6.5, "#d0302a", stroke=INK, stroke_width=2.6)
	d.circle(163, 70, 2, "#ffb0a0")
	d.circle(172, 90, 4.5, "#3fdc6a", stroke=INK, stroke_width=1.8)
	glow(d, 172, 90, 10, "#3fdc6a", 0.6)
	# winding crank on the side face
	d.spath("M156 124 L176 124 L176 140", INK, 7)
	d.spath("M156 124 L176 124 L176 140", CHROME, 3)
	d.rect(172, 138, 8, 14, "#2a1a10", rx=3)
	d.circle(156, 124, 4, BRASS, stroke=INK, stroke_width=2)
	sparkle(d, 40, 22, 7, "#ffffff", 1.0, glow_c="#fff0a0")


# --------------------------------------------------------------------------------------

def main():
	args = sys.argv[1:]
	only = None
	if "--only" in args:
		only = set(args[args.index("--only") + 1].split(","))
	pr_dir = os.path.join(ROOT, "art", "props")
	os.makedirs(pr_dir, exist_ok=True)
	bad = ("<text", "<filter", "<image", "<style", "href")
	for cid in CLUES2:
		if only and cid not in only:
			continue
		d = Doc(200, 200)
		globals()["clue_" + cid](d)
		txt = d.svg()
		for b in bad:
			if b in txt:
				raise SystemExit("forbidden SVG content %r in clue_%s" % (b, cid))
		with open(os.path.join(pr_dir, "clue_" + cid + ".svg"), "w", encoding="utf-8") as f:
			f.write(txt)
		print("icon %-16s %5.1f KB" % (cid, len(txt) / 1024.0))


if __name__ == "__main__":
	main()
