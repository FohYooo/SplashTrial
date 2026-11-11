#!/usr/bin/env python3
"""SPLASH TRIAL - art for the data-driven animated story scenes (scripts/data/anim_scenes.gd).

Writes art/props/an_*.svg:
  an_shutter     1280x720 the resort's steel shutter, filling the screen (hazard stripe along the bottom edge)
  an_desk_l/_r   430x300  the two halves of the reception desk, split down a jagged line
  an_snn_set     1280x720 the shopping channel's set: sunburst wall, bulb arch, plastic palms, checker floor
  an_snn_counter 1280x270 the sales counter in the foreground, transparent above
  an_snn_logo    300x300  the channel's round logo
  an_pedestal    320x340  the turning display stand
  an_item_key    360x330  the first episode's product, on a velvet cushion
Case 3, Days 1 to 3:
  an_bat           260x160  an 'improved' cellar bat (one red camera eye, a brass rivet)
  an_bandage       170x140  a bandaged paw, shown beside a portrait (portraits are never changed)
  an_item_view     380x300  framed night view of the Gaol (broadcast product)
  an_beam          420x1100 a searchlight beam crossing a dark room
  an_item_pass     340x220  a Visitor's Pass
  an_gaol_view     1280x720 the Gaol's lit cell windows through the telescope
  an_item_telescope 260x340 brass telescope on a tripod
  an_ledger        420x300  the Gaol's intake book, closed
  an_ledger_page   260x340  a torn-out page: entries in a light face, names in a black square face
  an_item_strongbox 340x290 a riveted strongbox (broadcast product)
Case 3, Days 4 to 6:
  an_teapot        320x300  the Tea-Time Tribunal's crested silver teapot
  an_item_hourglass 260x340 thirty seconds in a brass hourglass (broadcast product)
  an_glass         1280x720 the Visiting Room's glass partition, see-through, for laying over a scene
  an_item_torch    380x230  a crested electric torch, switched on (broadcast product)
  an_stewpot       440x320  the one big pot everyone eats from, with its ladle
  an_door          420x760  the Library door, heavy oak
  clue_night3_ash / _rug / _desk  200x200  icons for the Tea-Time Tribunal's three Truth Drops

Usage (from the project root):  python3 tools/gen_anim_art.py [names...]
Only SVG 1.1 basics are used (no text / filters / images / CSS) so Godot's ThorVG rasterizes it.
The SVG toolkit and motifs come from tools/gen_bgs.py (imported read-only).
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_bgs as GB  # noqa: E402  (helpers only - never modified)
from gen_bgs import Doc, G, T, fm, glow, mix, dark, light  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "props")
W, H = 1280, 720

INK = "#2a1a10"
BRASS = "#d9a845"
BRASS_L = "#ffe39a"
BRASS_D = "#8a6420"
VELVET = "#8e2b4a"
VELVET_D = "#551530"
VELVET_L = "#c04a70"
TEAL = "#1f8a8a"
TEAL_D = "#0f4a54"
MAGENTA = "#c83a8c"
MAGENTA_D = "#5a1a58"
SUN = "#ffd86b"
CEDAR = "#7a4a2c"
CEDAR_D = "#4a2a18"
CEDAR_L = "#a66a3c"


def bulb(d, x, y, r=7.0, on=True):
	if on:
		glow(d, x, y, r * 3.2, SUN, 0.55)
	d.circle(x, y, r, "#fff4c4" if on else "#7a6a4a", stroke=INK, stroke_width=1.6)
	d.circle(x - r * 0.3, y - r * 0.3, r * 0.3, "#ffffff", opacity=0.9)


def shutter(d):
	rng = random.Random(4101)
	with G(d, transform=T(0, 0, 2.0)):
		GB.steel_shutter(d, 0, 0, 640, 360, rng, crest=True)


def desk_half(d, left):
	"""The desk front, cracked down one side. Drawn for the left half; the right one is mirrored and re-cut."""
	rng = random.Random(77 if left else 78)
	w, h = 430, 300
	jag = [(w - 6, 18)]
	y = 18
	while y < h - 10:
		y += rng.uniform(26, 46)
		jag.append((w - rng.uniform(4, 58), min(y, h - 8)))
	outline = [(8, 18)] + jag + [(8, h - 8)]
	transform = "translate(0 14)" if left else "translate(%d 14) scale(-1 1)" % w
	h -= 14
	with G(d, transform=transform):
		d.poly([(p[0] + 8, p[1] + 8) for p in outline], "#000000", opacity=0.45)
		d.poly(outline, d.vlin(18, h, [(0, CEDAR_L), (0.25, CEDAR), (1, CEDAR_D)]), stroke=INK, stroke_width=4, stroke_linejoin="round")
		cid = d.clip('<polygon points="%s"/>' % " ".join("%s,%s" % (fm(p[0]), fm(p[1])) for p in outline))
		with G(d, clip_path=cid):
			d.rect(0, 18, w, 34, d.vlin(18, 52, [(0, BRASS_L), (1, BRASS_D)]))
			d.line(0, 52, w, 52, INK, 3)
			for x in range(30, w, 86):
				d.rect(x, 74, 62, h - 106, CEDAR_D, stroke=INK, stroke_width=2.2, rx=4)
				d.rect(x + 7, 81, 48, h - 120, CEDAR, opacity=0.8, rx=3)
				d.line(x + 12, 88, x + 12, h - 46, CEDAR_L, 1.8, opacity=0.7)
			d.rect(0, h - 26, w, 26, CEDAR_D)
		# the freshly broken edge
		d.pline(jag, "#f3d9b0", 4.5)
		d.pline([(p[0] - 5, p[1] + 2) for p in jag], "#5a3218", 2.2)
		# the bell the guests never got to ring (left half only)
		if left:
			d.ellipse(150, 16, 28, 6, "#3a2a18")
			d.path("M124 15 Q126 -2 150 -2 Q174 -2 176 15 Z", BRASS, stroke=INK, stroke_width=2.5)
			d.circle(150, -5, 4, BRASS_L, stroke=INK, stroke_width=2)


def set_wall(d):
	rng = random.Random(2204)
	d.rect(0, 0, W, H, d.vlin(0, 520, [(0, MAGENTA_D), (0.55, MAGENTA), (1, "#ff8a5c")]))
	cx, cy = 640, 300
	# sunburst rays, cheap and loud
	n = 26
	for i in range(n):
		a0 = (i + 0.0) / n * math.tau
		a1 = (i + 0.5) / n * math.tau
		r = 1100
		d.poly([(cx, cy), (cx + math.cos(a0) * r, cy + math.sin(a0) * r), (cx + math.cos(a1) * r, cy + math.sin(a1) * r)], SUN, opacity=0.2)
	glow(d, cx, cy, 460, "#fff0b0", 0.42)
	# scalloped cloth swags along the top
	for i in range(9):
		x = i * 160 - 20
		d.path("M%d 0 Q%d 96 %d 0 Z" % (x, x + 80, x + 160), VELVET, stroke=INK, stroke_width=3)
		d.path("M%d 0 Q%d 66 %d 0 Z" % (x + 18, x + 80, x + 142), VELVET_L, opacity=0.6)
		d.circle(x + 160, 14, 9, BRASS, stroke=INK, stroke_width=2.2)
	# bulb arch
	arc = []
	for i in range(31):
		t = math.pi * i / 30.0
		arc.append((cx - math.cos(t) * 400, 470 - math.sin(t) * 336))
	d.pline(arc, BRASS_D, 26)
	d.pline(arc, BRASS, 16)
	for i, p in enumerate(arc):
		if i % 2 == 0:
			bulb(d, p[0], p[1], 8.0)
	# the Warden's crest, enormous, watching the merchandise
	GB.snapjaw_crest(d, cx, 258, 2.4)
	# columns
	for x in (92, 1188):
		d.rect(x - 44, 90, 88, 480, d.lin(x - 44, 0, x + 44, 0, [(0, "#e8dcd0"), (0.5, "#fff9ef"), (1, "#b8a89a")]), stroke=INK, stroke_width=3.5)
		for k in range(-2, 3):
			d.line(x + k * 15, 106, x + k * 15, 556, "#b8a89a", 2, opacity=0.7)
		for _ in range(5):
			sx = x + rng.uniform(-36, 36)
			sy = rng.uniform(130, 500)
			d.spath("M%s %s q %s 26 %s 54" % (fm(sx), fm(sy), fm(rng.uniform(-16, 16)), fm(rng.uniform(-8, 8))), "#a0668c", 1.6, opacity=0.5)
		d.rect(x - 58, 72, 116, 26, BRASS, stroke=INK, stroke_width=3.5)
		d.rect(x - 58, 560, 116, 30, BRASS, stroke=INK, stroke_width=3.5)
	# checker floor in fake perspective
	y0 = 566
	d.rect(0, y0, W, H - y0, "#1d2352")
	rows = [(566, 590), (590, 624), (624, 672), (672, 730)]
	for r, (ya, yb) in enumerate(rows):
		ta = (ya - 470.0) / 250.0
		tb = (yb - 470.0) / 250.0
		for i in range(-16, 17):
			if (i + r) % 2:
				continue
			xa0 = 640 + i * 120 * ta
			xa1 = 640 + (i + 1) * 120 * ta
			xb0 = 640 + i * 120 * tb
			xb1 = 640 + (i + 1) * 120 * tb
			d.poly([(xa0, ya), (xa1, ya), (xb1, yb), (xb0, yb)], "#f4d9e8")
	d.rect(0, y0 - 4, W, 8, BRASS_D)
	# plastic palms (the price tags are still on)
	for x, flip in ((226, 1), (1054, -1)):
		palm(d, x, 572, flip, rng)


def palm(d, x, base, flip, rng):
	d.path("M%d %d L%d %d L%d %d L%d %d Z" % (x - 30, base, x + 30, base, x + 22, base - 48, x - 22, base - 48), "#c8552e", stroke=INK, stroke_width=3)
	d.spath("M%d %d Q%d %d %d %d" % (x, base - 48, x + flip * 14, base - 150, x - flip * 6, base - 250), "#6a4428", 15)
	d.spath("M%d %d Q%d %d %d %d" % (x, base - 48, x + flip * 14, base - 150, x - flip * 6, base - 250), "#a06a3c", 6, opacity=0.8)
	top = (x - flip * 6, base - 250)
	for a in (-160, -125, -90, -55, -20, 15, 195):
		ar = math.radians(a)
		tip = (top[0] + math.cos(ar) * 130, top[1] + math.sin(ar) * 90 + 42)
		ctrl = (top[0] + math.cos(ar) * 70, top[1] + math.sin(ar) * 110 - 30)
		d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (fm(top[0]), fm(top[1]), fm(ctrl[0]), fm(ctrl[1]), fm(tip[0]), fm(tip[1]), fm(ctrl[0]), fm(ctrl[1] + 34), fm(top[0]), fm(top[1])),
			"#2fae5a", stroke=INK, stroke_width=2.6, stroke_linejoin="round")
	# the tag
	tx, ty = top[0] + flip * 58, top[1] + 86
	d.line(top[0] + flip * 40, top[1] + 42, tx, ty - 10, "#f4f1e0", 1.6)
	d.poly([(tx - 16, ty - 8), (tx + 16, ty - 8), (tx + 16, ty + 18), (tx - 16, ty + 18)], "#fff4c4", stroke=INK, stroke_width=2)
	d.line(tx - 9, ty + 2, tx + 9, ty + 2, INK, 2)
	d.line(tx - 9, ty + 9, tx + 3, ty + 9, INK, 2)


def counter(d):
	w, h = 1280, 270
	top = 40
	d.rect(0, top + 16, w, h, d.vlin(top, h, [(0, "#2b2e74"), (1, "#14143e")]), stroke=INK, stroke_width=4)
	# marble slab top
	d.rect(-6, top, w + 12, 26, d.vlin(top, top + 26, [(0, "#fff7ec"), (1, "#c8b6a8")]), stroke=INK, stroke_width=4)
	# gold scallop trim and a row of bulbs
	for i in range(0, 33):
		x = i * 40
		d.path("M%d %d Q%d %d %d %d Z" % (x, top + 26, x + 20, top + 62, x + 40, top + 26), BRASS, stroke=INK, stroke_width=2.4)
	for i in range(1, 16):
		bulb(d, i * 80, top + 96, 8.0)
	# diagonal sale stripes
	cid = d.clip('<rect x="0" y="%d" width="%d" height="%d"/>' % (top + 118, w, h - top - 118))
	with G(d, clip_path=cid):
		for i in range(-4, 40):
			x = i * 70
			d.poly([(x, h), (x + 34, h), (x + 34 + 110, top + 118), (x + 110, top + 118)], "#3a3f9a", opacity=0.8)


def logo(d):
	cx, cy = 150, 150
	spikes = []
	for i in range(40):
		r = 146 if i % 2 == 0 else 122
		a = i / 40.0 * math.tau
		spikes.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
	d.poly([(p[0] + 5, p[1] + 6) for p in spikes], "#000000", opacity=0.55)
	d.poly(spikes, SUN, stroke=INK, stroke_width=4, stroke_linejoin="round")
	d.circle(cx, cy, 118, MAGENTA, stroke=INK, stroke_width=4)
	GB.snapjaw_crest(d, cx, cy + 4, 2.0)


def pedestal(d):
	w, h = 320, 340
	cx = w / 2
	d.path("M%d 60 L%d 60 L%d 300 L%d 300 Z" % (cx - 86, cx + 86, cx + 118, cx - 118), d.lin(cx - 118, 0, cx + 118, 0, [(0, "#3a3f9a"), (0.5, "#6a70d0"), (1, "#23265e")]), stroke=INK, stroke_width=4)
	d.ellipse(cx, 300, 124, 28, "#1b1c4e", stroke=INK, stroke_width=4)
	d.ellipse(cx, 60, 102, 26, d.vlin(34, 86, [(0, BRASS_L), (1, BRASS)]), stroke=INK, stroke_width=4)
	d.ellipse(cx, 56, 80, 17, VELVET, stroke=INK, stroke_width=3)
	for i in range(1, 5):
		bulb(d, cx - 108 + 216 * i / 5.0, 160 + 34 * abs(i - 2.5) / 2.5, 7.0)


def item_key(d):
	w, h = 360, 330
	cx = w / 2
	# cushion
	d.path("M34 268 Q18 222 62 206 Q180 176 298 206 Q342 222 326 268 Q330 306 290 300 Q180 318 70 300 Q30 306 34 268 Z",
		d.vlin(190, 310, [(0, VELVET_L), (0.6, VELVET), (1, VELVET_D)]), stroke=INK, stroke_width=4.5, stroke_linejoin="round")
	d.spath("M70 236 Q180 208 290 236", "#e88aa8", 3, opacity=0.6)
	for x, y in ((36, 270), (324, 270), (66, 300), (294, 300)):
		d.spath("M%d %d q %d 12 %d 26" % (x, y, -4 if x < cx else 4, -2 if x < cx else 2), BRASS, 6)
		d.circle(x + (-2 if x < cx else 2), y + 30, 6, BRASS_L, stroke=INK, stroke_width=2)
	glow(d, cx, 140, 170, SUN, 0.5)
	# the key, leaning across the cushion
	with G(d, transform=T(cx + 6, 196, 0.78, -28)):
		d.rect(-14, -104, 28, 214, d.lin(-14, 0, 14, 0, [(0, BRASS_D), (0.45, BRASS_L), (1, BRASS)]), stroke=INK, stroke_width=4, rx=7)
		d.path("M14 56 L58 56 L58 74 L38 74 L38 88 L58 88 L58 110 L14 110 Z", BRASS, stroke=INK, stroke_width=4, stroke_linejoin="round")
		d.circle(0, -146, 62, "none", stroke=INK, stroke_width=26)
		d.circle(0, -146, 62, "none", stroke=BRASS, stroke_width=18)
		d.circle(0, -146, 62, "none", stroke=BRASS_L, stroke_width=4, opacity=0.8)
		GB.yuzu(d, 0, -146, 28, rot=-20, leaf=True)
	# sparkles
	for x, y, r in ((70, 84, 18), (300, 60, 24), (276, 158, 13)):
		GB.sparkle(d, x, y, r, "#fffbe0")


# ------------------------------------------------------------------------------------------ Case 3, Days 1 to 3
STONE = "#7b8290"
STONE_D = "#4a505e"
LAMPLIT = "#ffd27a"
BLOOD = "#7a0010"
PAPER = "#efe6cc"
PAPER_D = "#cbbd96"
LEATHER = "#1d1a20"
LEATHER_L = "#3a3440"


def bat(d):
	"""One of the Warden's 'improved' cellar bats: wings spread, one red camera eye, a brass rivet in the wing."""
	w = 260
	wing = ("M130 84 Q104 46 52 20 Q60 44 38 52 Q48 68 18 80 Q40 90 26 108 Q68 98 98 116 Q114 100 130 102 Z")
	for side in (1, -1):
		tr = None if side == 1 else "translate(%d 0) scale(-1 1)" % w
		with G(d, transform=tr):
			d.path(wing, "#000000", opacity=0.35, transform="translate(6 8)")
			d.path(wing, d.lin(18, 0, 130, 0, [(0, "#4a3a5e"), (0.6, "#2e2440"), (1, "#22192e")]), stroke=INK, stroke_width=4, stroke_linejoin="round")
			for bone in ("M122 86 Q92 56 52 20", "M118 92 Q84 70 38 52", "M114 98 Q70 86 18 80", "M112 104 Q74 100 26 108"):
				d.spath(bone, "#140e1c", 3, opacity=0.9)
			d.spath("M120 90 Q96 66 62 40", "#7a6a9a", 1.6, opacity=0.5)
	# rivet in the left wing ("improved")
	d.circle(78, 66, 7, BRASS, stroke=INK, stroke_width=2)
	d.line(74, 66, 82, 66, BRASS_D, 1.6)
	d.line(78, 62, 78, 70, BRASS_D, 1.6)
	# body and head
	d.ellipse(130, 108, 24, 30, d.vlin(78, 138, [(0, "#3e3050"), (1, "#1c1426")]), stroke=INK, stroke_width=4)
	for side in (1, -1):
		d.poly([(130 + side * 14, 74), (130 + side * 22, 40), (130 + side * 4, 66)], "#2e2440", stroke=INK, stroke_width=3.5, stroke_linejoin="round")
		d.poly([(130 + side * 15, 70), (130 + side * 19, 50), (130 + side * 9, 66)], "#8a5a7a", opacity=0.7)
	d.circle(130, 82, 21, d.vlin(60, 104, [(0, "#4a3a5e"), (1, "#2a2038")]), stroke=INK, stroke_width=4)
	# one yellow eye, one red camera eye
	d.ellipse(121, 78, 5, 6, "#f4e04d", stroke=INK, stroke_width=1.6)
	d.ellipse(121, 79, 1.6, 4, INK)
	glow(d, 139, 78, 18, "#ff3b3b", 0.75)
	d.circle(139, 78, 6.5, "#ff3b3b", stroke=INK, stroke_width=1.8)
	d.circle(139, 78, 9.5, "none", stroke=BRASS, stroke_width=2.2)
	d.circle(137.5, 76.5, 1.8, "#ffd0d0")
	# snout and fangs
	d.ellipse(130, 92, 8, 5, "#5a4870", stroke=INK, stroke_width=2)
	d.poly([(124, 98), (127, 109), (129, 98)], "#fffbe8", stroke=INK, stroke_width=1.4)
	d.poly([(131, 98), (133, 109), (136, 98)], "#fffbe8", stroke=INK, stroke_width=1.4)
	# little feet
	for side in (1, -1):
		d.spath("M%d 134 l%d 12" % (130 + side * 8, side * 4), INK, 3)


def bandage(d):
	"""A bandaged paw, for the three bites (an overlay beside a portrait, never painted onto one)."""
	fur = "#a5754a"
	fur_d = "#7a5232"
	for x in (54, 82, 110):
		d.ellipse(x + 4, 44, 14, 12, "#000000", opacity=0.3)
		d.ellipse(x, 40, 14, 12, fur, stroke=INK, stroke_width=3.5)
		d.ellipse(x - 3, 37, 5, 3.5, light(fur, 0.3), opacity=0.7)
	paw = "M36 126 L40 70 Q42 46 82 44 Q122 46 124 70 L128 126 Z"
	d.path(paw, "#000000", opacity=0.3, transform="translate(6 6)")
	d.path(paw, d.lin(36, 0, 128, 0, [(0, fur_d), (0.4, fur), (1, fur_d)]), stroke=INK, stroke_width=4, stroke_linejoin="round")
	cid = d.clip('<path d="%s"/>' % paw)
	with G(d, clip_path=cid):
		for k, y in enumerate((62, 82, 102, 122)):
			band = "M20 %d L150 %d L150 %d L20 %d Z" % (y - 4 + k % 2 * 6, y - 14 - k % 2 * 6, y + 6 - k % 2 * 6, y + 16 + k % 2 * 6)
			d.path(band, "#f4f1ea", stroke="#b9b4aa", stroke_width=1.6)
			d.path("M20 %d L150 %d L150 %d L20 %d Z" % (y + 10, y, y + 6 - k % 2 * 6, y + 16 + k % 2 * 6), "#c9c4ba", opacity=0.5)
		d.ellipse(98, 88, 8, 6, BLOOD, opacity=0.85)
		d.ellipse(97, 87, 4, 3, "#b3001b", opacity=0.6)
	d.path(paw, "none", stroke=INK, stroke_width=4, stroke_linejoin="round")
	d.spath("M128 104 Q146 112 150 128", "#f4f1ea", 7)
	d.spath("M128 104 Q146 112 150 128", "#b9b4aa", 1.6, opacity=0.8)


def gaol_facade(d, x0, y0, w, h, rng, lit=0.85, rows=7, cols=14):
	"""A wall of cells: grey stone, rows of small barred windows, most of them lit."""
	d.rect(x0, y0, w, h, d.vlin(y0, y0 + h, [(0, light(STONE, 0.1)), (1, STONE_D)]))
	for r in range(int(h / 26) + 1):
		y = y0 + r * 26
		d.line(x0, y, x0 + w, y, STONE_D, 1.2, opacity=0.55)
		off = 0 if r % 2 else 24
		for c in range(int(w / 48) + 2):
			x = x0 + off + c * 48
			d.line(x, y, x, y + 26, STONE_D, 1.0, opacity=0.45)
	cw = w / cols
	rh = h / rows
	for r in range(rows):
		for c in range(cols):
			wx = x0 + c * cw + cw * 0.3
			wy = y0 + r * rh + rh * 0.24
			ww, wh = cw * 0.4, rh * 0.52
			on = rng.random() < lit
			if on:
				glow(d, wx + ww / 2, wy + wh / 2, ww * 1.5, LAMPLIT, 0.4)
			d.rect(wx, wy, ww, wh, LAMPLIT if on else "#1a1c26", stroke=INK, stroke_width=1.6)
			for k in range(1, 3):
				d.line(wx + ww * k / 3, wy, wx + ww * k / 3, wy + wh, "#3a3e4a", 1.6)
			d.rect(wx - 3, wy + wh, ww + 6, 3.5, light(STONE, 0.25))


def item_view(d):
	"""The first broadcast's product: a framed night view of the Gaol, searchlight and all."""
	rng = random.Random(3301)
	w, h = 380, 300
	d.rect(14, 14, w - 28, h - 28, d.vlin(14, 200, [(0, "#0d1530"), (1, "#24304e")]))
	glow(d, 290, 64, 30, "#fff4c4", 0.6)
	d.circle(290, 64, 12, "#fff4c4")
	for _ in range(16):
		d.circle(rng.uniform(26, w - 26), rng.uniform(24, 130), rng.uniform(0.8, 1.8), "#ffffff", opacity=0.8)
	d.rect(14, 200, w - 28, h - 214, d.vlin(200, h - 14, [(0, "#1d3550"), (1, "#0c1a2a")]))
	# the beam
	d.poly([(196, 112), (40, 36), (20, 82)], "#fff6d0", opacity=0.35)
	d.poly([(196, 112), (60, 46), (40, 70)], "#ffffff", opacity=0.35)
	d.blob([(80, 216), (110, 188), (190, 180), (270, 186), (310, 214)], "#3a302c", t=0.5)
	gaol_facade(d, 104, 140, 170, 56, rng, 0.8, 3, 9)
	d.rect(176, 104, 40, 40, STONE_D, stroke=INK, stroke_width=2)
	d.rect(184, 108, 24, 12, "#fff6d0")
	d.poly([(170, 104), (196, 84), (222, 104)], "#3a3550", stroke=INK, stroke_width=2)
	for x in range(30, w - 30, 22):
		d.line(x, 230 + (x % 3) * 8, x + 12, 230 + (x % 3) * 8, "#ffd27a", 2, opacity=0.4)
	# gilt frame
	d.rect(0, 0, w, h, "none", stroke=INK, stroke_width=4)
	d.path("M0 0 H%d V%d H0 Z M18 18 V%d H%d V18 Z" % (w, h, h - 18, w - 18), d.lin(0, 0, w, h, [(0, BRASS_L), (0.5, BRASS), (1, BRASS_D)]),
		stroke=INK, stroke_width=3, fill_rule="evenodd")
	d.rect(18, 18, w - 36, h - 36, "none", stroke=INK, stroke_width=3)
	for x, y in ((9, 9), (w - 9, 9), (9, h - 9), (w - 9, h - 9)):
		d.circle(x, y, 7, BRASS_L, stroke=INK, stroke_width=2)


def beam(d):
	"""A searchlight beam crossing a dark room: a soft, slanted band of white."""
	w, h = 420, 1100
	g = d.lin(0, 0, w, 0, [(0, "#ffffff", 0), (0.35, "#f4f8ff", 0.32), (0.5, "#ffffff", 0.55), (0.65, "#f4f8ff", 0.32), (1, "#ffffff", 0)])
	d.rect(0, 0, w, h, g)
	d.rect(w * 0.44, 0, w * 0.12, h, "#ffffff", opacity=0.25)


def item_pass(d):
	"""A Visitor's Pass: stiff yellow card, crest, cell number band, a photo behind bars."""
	w, h = 340, 220
	d.rect(8, 10, w - 10, h - 12, "#000000", opacity=0.35, rx=16)
	d.rect(2, 2, w - 10, h - 12, d.vlin(2, h, [(0, "#ffe9a0"), (1, "#e8c45a")]), stroke=INK, stroke_width=4, rx=16)
	d.rect(2, 2, w - 10, 40, "#8e2b4a", rx=16)
	d.rect(2, 26, w - 10, 16, "#8e2b4a")
	d.path("M2 42 H%d" % (w - 8), "none", stroke=INK, stroke_width=3)
	GB.snapjaw_crest(d, 30, 22, 0.32)
	rng = random.Random(77)
	GB.glyphs(d, 54, 12, 150, 18, 1, "#ffe39a", rng, sw=2.2)
	# photo window with bars
	px, py, pw, ph = 204, 56, 112, 132
	d.rect(px, py, pw, ph, d.vlin(py, py + ph, [(0, "#5a6070"), (1, "#30343d")]), stroke=INK, stroke_width=3)
	GB.capy_stand(d, px + pw / 2, py + ph - 4, 0.62, color="#14161e")
	for k in range(1, 5):
		d.line(px + pw * k / 5, py, px + pw * k / 5, py + ph, "#9aa2b2", 3)
	d.rect(px, py, pw, ph, "none", stroke=INK, stroke_width=3)
	GB.glyphs(d, 22, 60, 160, 72, 4, "#5a3a20", rng, sw=2.0)
	d.rect(20, 150, 166, 36, "#fff6d6", stroke=INK, stroke_width=2.5, rx=5)
	GB.seg_digits(d, 34, 156, 24, "318", "#8e2b4a")
	d.circle(150, 168, 16, "none", stroke="#c0392b", stroke_width=3, opacity=0.8)
	d.line(138, 168, 162, 168, "#c0392b", 3, opacity=0.8)


def gaol_view(d):
	"""Through the telescope: the Gaol's cell windows, nearly all lit, in a round brass-rimmed view."""
	rng = random.Random(4402)
	cx, cy, r = 640, 360, 318
	d.rect(0, 0, W, H, "#06050a")
	cid = d.clip('<circle cx="%d" cy="%d" r="%d"/>' % (cx, cy, r))
	with G(d, clip_path=cid):
		d.rect(0, 0, W, H, d.vlin(0, H, [(0, "#3a2a5a"), (0.5, "#a0507a"), (1, "#f0a060")]))
		gaol_facade(d, cx - 420, cy - 250, 840, 560, rng, 0.9, 9, 16)
		d.rect(cx - 420, cy + 286, 840, 40, "#30343d")
		d.rect(0, 0, W, H, d.rad(cx, cy, r, [(0, "#000000", 0), (0.72, "#000000", 0), (1, "#000000", 0.85)]))
	d.circle(cx, cy, r + 10, "none", stroke=BRASS_D, stroke_width=22)
	d.circle(cx, cy, r + 10, "none", stroke=BRASS, stroke_width=12)
	d.circle(cx, cy, r + 4, "none", stroke=INK, stroke_width=4)
	d.circle(cx, cy, r + 21, "none", stroke=INK, stroke_width=3)
	d.path("M%d %d A %d %d 0 0 1 %d %d" % (cx - r + 30, cy - 120, r, r, cx + 40, cy - r + 14), "none", stroke="#ffffff", stroke_width=6, opacity=0.18)


def item_telescope(d):
	"""A brass telescope on a wooden tripod, tilted up at the bay."""
	w, h = 260, 340
	for x0 in (50, 130, 210):
		d.line(130, 170, x0, 330, "#3a2414", 13)
		d.line(130, 170, x0, 330, "#7a4a2c", 8)
	d.circle(130, 170, 14, BRASS, stroke=INK, stroke_width=3)
	with G(d, transform=T(130, 160, 1.0, -28)):
		d.rect(-110, -20, 120, 40, d.vlin(-20, 20, [(0, BRASS_L), (0.5, BRASS), (1, BRASS_D)]), stroke=INK, stroke_width=4, rx=6)
		d.rect(6, -26, 96, 52, d.vlin(-26, 26, [(0, BRASS_L), (0.5, BRASS), (1, BRASS_D)]), stroke=INK, stroke_width=4, rx=6)
		d.rect(98, -32, 24, 64, BRASS_D, stroke=INK, stroke_width=4, rx=5)
		d.ellipse(122, 0, 6, 28, "#a8d8f0", stroke=INK, stroke_width=3)
		d.rect(-126, -12, 18, 24, "#2a1a10", stroke=INK, stroke_width=3, rx=3)
		for x in (-60, 40):
			d.rect(x, -22, 8, 44, BRASS_D, opacity=0.6)
	GB.sparkle(d, 214, 64, 12, "#fffbe0")


def ledger(d):
	"""The Gaol's intake book: thick, black, brass-cornered, the Warden's crest on the cover."""
	w, h = 420, 300
	d.path("M40 268 L380 268 L404 286 L60 290 Z", "#000000", opacity=0.4)
	d.path("M30 60 L370 40 L392 252 L52 276 Z", PAPER, stroke=INK, stroke_width=4, stroke_linejoin="round")
	for k in range(6):
		d.line(36 + k * 2, 64 + k * 34, 52 + k * 2, 270 - 0 * k, PAPER_D, 1.2, opacity=0.3)
	d.path("M22 48 L362 28 L380 240 L40 264 Z", d.lin(22, 28, 380, 264, [(0, LEATHER_L), (0.5, LEATHER), (1, "#0e0c12")]),
		stroke=INK, stroke_width=4, stroke_linejoin="round")
	d.path("M22 48 L362 28 L364 52 L24 72 Z", "#ffffff", opacity=0.06)
	for (x, y, sx, sy) in ((22, 48, 1, 1), (362, 28, -1, 1), (380, 240, -1, -1), (40, 264, 1, -1)):
		d.path("M%d %d l%d %d l%d %d Z" % (x, y, sx * 40, sy * -2, -sx * 38, sy * 36), BRASS, stroke=INK, stroke_width=2.5)
	d.rect(352, 118, 46, 46, d.vlin(118, 164, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=3, rx=6)
	d.circle(375, 141, 6, INK)
	GB.snapjaw_crest(d, 200, 148, 0.95, a=0.92)
	d.path("M120 222 L290 212 L292 226 L122 236 Z", BRASS, opacity=0.85, stroke=INK, stroke_width=2)


def ledger_page(d):
	"""A torn-out Ledger page: entries typed small and light, each informer's name typed big, black and square."""
	rng = random.Random(5150)
	w, h = 260, 340
	edge = [(18, 6)]
	y = 6
	while y < h - 10:
		y += rng.uniform(8, 18)
		edge.append((rng.uniform(4, 18), min(y, h - 6)))
	outline = [(w - 8, 6), (w - 8, h - 6)] + list(reversed(edge))
	d.poly([(p[0] + 7, p[1] + 7) for p in outline], "#000000", opacity=0.35)
	d.poly(outline, d.vlin(0, h, [(0, PAPER), (1, "#e2d6b4")]), stroke=INK, stroke_width=3.5, stroke_linejoin="round")
	for k in range(14):
		d.line(26, 30 + k * 22, w - 18, 30 + k * 22, "#9ab0c8", 1, opacity=0.5)
	d.line(44, 10, 44, h - 10, "#c06060", 1.2, opacity=0.5)
	for k in range(4):
		y0 = 22 + k * 78
		GB.glyphs(d, 52, y0, w - 82, 38, 3, "#6a5440", rng, sw=1.3)
		# the name, in a squarer, blacker face
		x = 120 + rng.uniform(-10, 20)
		for j in range(rng.randint(5, 8)):
			bw = rng.choice((7, 9, 11))
			d.rect(x, y0 + 48, bw, 13, INK)
			if rng.random() < 0.5:
				d.rect(x + 2, y0 + 51, bw - 4, 4, PAPER)
			x += bw + 4


def item_strongbox(d):
	"""The third broadcast's product: a steel strongbox, riveted, crested, padlocked."""
	w, h = 340, 290
	d.path("M40 270 L310 270 L330 284 L56 286 Z", "#000000", opacity=0.4)
	d.rect(30, 96, 280, 170, d.lin(30, 0, 310, 0, [(0, "#4a5260"), (0.45, "#9aa4b4"), (1, "#3a404c")]), stroke=INK, stroke_width=4, rx=8)
	d.path("M30 104 Q30 60 70 56 L270 56 Q310 60 310 104 Z", d.lin(30, 0, 310, 0, [(0, "#5a6270"), (0.45, "#b0bac8"), (1, "#4a5260")]),
		stroke=INK, stroke_width=4)
	d.rect(30, 98, 280, 14, "#2a2e36", stroke=INK, stroke_width=2.5)
	for x in range(46, 310, 30):
		for y in (124, 252):
			d.circle(x, y, 4, "#cfd6e0", stroke=INK, stroke_width=1.4)
	GB.snapjaw_crest(d, 170, 182, 0.72)
	# padlock
	d.spath("M150 138 Q150 104 170 104 Q190 104 190 138", "#8a93a2", 10)
	d.spath("M150 138 Q150 104 170 104 Q190 104 190 138", INK, 2.5, opacity=0.7)
	d.rect(140, 132, 60, 50, d.vlin(132, 182, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=3.5, rx=8)
	d.circle(170, 152, 6, INK)
	d.path("M167 154 L173 154 L171 168 L169 168 Z", INK)
	GB.sparkle(d, 286, 72, 14, "#fffbe0")
	GB.sparkle(d, 56, 210, 9, "#fffbe0")


# ---------------------------------------------------------------------------------------------- Case 3, Days 4 to 6
SILVER = "#c9ced8"
SILVER_L = "#f1f3f7"
SILVER_D = "#7d8494"
OAK = "#5a3a22"
OAK_D = "#3a2414"
OAK_L = "#8a5a34"


def teapot(d):
	"""The Tea-Time Tribunal's teapot: big, silver, crested, with a little steam."""
	w, h = 320, 300
	d.ellipse(162, 280, 120, 14, "#000000", opacity=0.35)
	# spout and handle behind the body
	d.path("M70 170 Q30 160 18 108 Q14 96 26 96 Q40 132 82 140 Z", d.lin(14, 0, 82, 0, [(0, SILVER_L), (1, SILVER_D)]),
		stroke=INK, stroke_width=4, stroke_linejoin="round")
	d.spath("M248 120 Q312 120 306 182 Q300 236 240 228", INK, 22)
	d.spath("M248 120 Q312 120 306 182 Q300 236 240 228", SILVER, 13)
	d.spath("M252 126 Q300 128 296 180", SILVER_L, 4, opacity=0.8)
	# body
	body = "M70 128 Q64 260 160 266 Q256 260 250 128 Q246 96 160 92 Q74 96 70 128 Z"
	d.path(body, d.lin(64, 0, 256, 0, [(0, SILVER_D), (0.32, SILVER_L), (0.6, SILVER), (1, "#5a6070")]),
		stroke=INK, stroke_width=4.5, stroke_linejoin="round")
	d.path("M96 130 Q92 210 132 246", "none", stroke="#ffffff", stroke_width=7, opacity=0.55, stroke_linecap="round")
	d.rect(66, 118, 188, 16, d.vlin(118, 134, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=3, rx=6)
	GB.snapjaw_crest(d, 168, 196, 0.62)
	# lid and knob
	d.path("M96 116 Q160 64 224 116 Z", d.lin(96, 0, 224, 0, [(0, SILVER_D), (0.4, SILVER_L), (1, SILVER_D)]), stroke=INK, stroke_width=4)
	d.circle(160, 70, 14, BRASS, stroke=INK, stroke_width=3.5)
	d.circle(155, 65, 4, BRASS_L)
	for k, x in enumerate((-20, 0, 18)):
		d.spath("M%d 54 Q%d 34 %d 18 Q%d 4 %d -10" % (24 + x, 10 + x, 26 + x, 40 + x, 28 + x), "#ffffff", 5, opacity=0.35 - k * 0.08)


def item_hourglass(d):
	"""The fourth broadcast's product: thirty seconds, in a brass hourglass."""
	w, h = 260, 340
	d.ellipse(130, 326, 92, 10, "#000000", opacity=0.35)
	for y in (14, 300):
		d.rect(34, y, 192, 24, d.vlin(y, y + 24, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=4, rx=7)
	for x in (48, 212):
		d.rect(x - 6, 36, 12, 266, d.lin(x - 6, 0, x + 6, 0, [(0, BRASS_D), (0.5, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=3)
	glass = "M66 40 Q66 128 124 166 Q66 204 66 298 L194 298 Q194 204 136 166 Q194 128 194 40 Z"
	d.path(glass, "#dff2ff", opacity=0.35)
	sand = "#e9b85a"
	d.path("M86 96 Q100 132 126 160 L134 160 Q160 132 174 96 Z", sand, stroke="#a87830", stroke_width=1.5)
	d.rect(127, 160, 6, 112, sand)
	d.path("M74 298 Q96 252 130 246 Q164 252 186 298 Z", sand, stroke="#a87830", stroke_width=1.5)
	d.path(glass, "none", stroke=INK, stroke_width=4, stroke_linejoin="round")
	d.spath("M82 52 Q82 112 112 146", "#ffffff", 5, opacity=0.6)
	GB.snapjaw_crest(d, 130, 26, 0.3)
	GB.sparkle(d, 214, 120, 12, "#fffbe0")


def glass_pane(d):
	"""The Visiting Room's partition, seen from the visitor's side: thick glass, a steel frame, a speaking grille.
	Mostly see-through, so it lies over anything."""
	d.rect(0, 0, W, 40, d.vlin(0, 40, [(0, "#3c434e"), (1, "#252a32")]))
	d.rect(0, 600, W, 120, d.vlin(600, 720, [(0, "#4a525e"), (1, "#20242b")]))
	d.line(0, 600, W, 600, INK, 5)
	d.line(0, 40, W, 40, INK, 5)
	for x in (0, W - 34):
		d.rect(x, 40, 34, 560, d.lin(x, 0, x + 34, 0, [(0, "#30363f"), (0.5, "#5a6270"), (1, "#30363f")]))
	d.rect(34, 40, W - 68, 560, "#bfe4f2", opacity=0.10)
	for (x, wd, a) in ((180, 120, 0.16), (330, 40, 0.12), (840, 160, 0.10), (1040, 50, 0.14)):
		d.path("M%d 40 L%d 40 L%d 600 L%d 600 Z" % (x, x + wd, x + wd - 260, x - 260), "#ffffff", opacity=a)
	# the speaking grille and the shelf with the telephone cradle
	d.rect(560, 520, 160, 60, "#2a2e36", stroke=INK, stroke_width=3, rx=10)
	for k in range(5):
		d.circle(590 + k * 25, 550, 6, "#11141a")
	d.rect(80, 612, 220, 30, "#1a1d22", stroke=INK, stroke_width=3, rx=6)
	for x in range(60, W, 140):
		d.circle(x, 20, 4, "#9aa2b2", stroke=INK, stroke_width=1.2)
		d.circle(x, 664, 4, "#9aa2b2", stroke=INK, stroke_width=1.2)


def item_torch(d):
	"""The fifth broadcast's product: a crested electric torch, switched on."""
	w, h = 380, 230
	beam = d.lin(150, 0, 380, 0, [(0, "#fff6c8", 0.75), (1, "#fff6c8", 0)])
	d.path("M150 92 L380 10 L380 220 L150 140 Z", beam)
	d.ellipse(150, 200, 120, 10, "#000000", opacity=0.3)
	d.rect(22, 92, 120, 48, d.vlin(92, 140, [(0, "#d24a3a"), (0.45, "#ff8a6a"), (1, "#7a1e18")]), stroke=INK, stroke_width=4, rx=10)
	d.path("M138 84 L170 72 L170 160 L138 148 Z", d.vlin(72, 160, [(0, SILVER_L), (1, SILVER_D)]), stroke=INK, stroke_width=4, stroke_linejoin="round")
	d.ellipse(170, 116, 10, 44, "#fffbe0", stroke=INK, stroke_width=3)
	d.rect(70, 82, 26, 12, BRASS, stroke=INK, stroke_width=2.5, rx=3)
	for x in (40, 54):
		d.line(x, 98, x, 134, "#000000", 2, opacity=0.25)
	GB.snapjaw_crest(d, 108, 116, 0.28)
	GB.sparkle(d, 196, 70, 12, "#fffbe0")


def stewpot(d):
	"""Grub's great pot, with the one ladle everyone shares."""
	w, h = 440, 320
	d.ellipse(220, 300, 190, 16, "#000000", opacity=0.35)
	d.path("M60 120 Q56 286 220 292 Q384 286 380 120 Z", d.lin(56, 0, 384, 0, [(0, "#2a2e36"), (0.35, "#6a7280"), (1, "#1c1f25")]),
		stroke=INK, stroke_width=5, stroke_linejoin="round")
	for x in (34, 384):
		d.rect(x, 128, 22, 30, "#3a404c", stroke=INK, stroke_width=3.5, rx=6)
	d.ellipse(220, 120, 166, 30, "#1a1d22", stroke=INK, stroke_width=5)
	d.ellipse(220, 124, 150, 22, d.rad(220, 124, 150, [(0, "#d8803a"), (1, "#8a3a18")]))
	for (x, y, r) in ((170, 120, 9), (240, 128, 7), (280, 116, 6), (196, 130, 5)):
		d.circle(x, y, r, "#f0c060", stroke="#8a4a18", stroke_width=1.5)
	d.spath("M250 118 L330 18", INK, 14)
	d.spath("M250 118 L330 18", SILVER, 8)
	d.ellipse(242, 120, 26, 10, SILVER_D, stroke=INK, stroke_width=3)
	for k, x in enumerate((130, 200, 290)):
		d.spath("M%d 92 Q%d 66 %d 44 Q%d 22 %d 4" % (x, x - 16, x + 4, x + 20, x), "#ffffff", 7, opacity=0.32 - k * 0.06)
	d.path("M86 150 Q90 240 150 268", "none", stroke="#ffffff", stroke_width=6, opacity=0.25, stroke_linecap="round")


def door(d):
	"""The Library door: heavy oak, four panels, a brass handle. Used whole, then shaken and burst open."""
	w, h = 420, 760
	d.rect(14, 14, w - 14, h - 14, "#000000", opacity=0.4)
	d.rect(4, 4, w - 16, h - 16, d.lin(4, 0, w - 12, 0, [(0, OAK_D), (0.4, OAK_L), (1, OAK)]), stroke=INK, stroke_width=6)
	for (x, y, pw, ph) in ((40, 40, 150, 300), (226, 40, 150, 300), (40, 380, 150, 330), (226, 380, 150, 330)):
		d.rect(x, y, pw, ph, OAK_D, stroke=INK, stroke_width=3, rx=4)
		d.rect(x + 12, y + 12, pw - 24, ph - 24, d.vlin(y, y + ph, [(0, OAK_L), (1, OAK)]), stroke=INK, stroke_width=2, rx=3)
		d.line(x + 22, y + 24, x + 22, y + ph - 24, "#b07a48", 2, opacity=0.6)
	d.rect(334, 330, 40, 90, d.vlin(330, 420, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=3, rx=8)
	d.circle(354, 362, 16, BRASS, stroke=INK, stroke_width=3)
	d.circle(350, 358, 5, BRASS_L)
	d.rect(348, 386, 12, 22, INK, rx=4)


def clue_card(d, kind):
	"""Small Truth Drop icons for the Tea-Time Tribunal (200x200, transparent)."""
	d.ellipse(104, 182, 80, 10, "#000000", opacity=0.3)
	if kind == "ash":
		d.path("M30 120 L170 120 L182 168 L18 168 Z", "#2a2e36", stroke=INK, stroke_width=4)
		for x in range(40, 170, 22):
			d.line(x, 120, x - 6, 168, INK, 3)
		d.path("M62 112 Q80 70 112 84 Q140 60 150 104 Q120 120 62 112 Z", "#4a4a50", stroke=INK, stroke_width=3)
		d.path("M120 40 L176 52 L168 98 L118 88 Z", PAPER, stroke=INK, stroke_width=3.5, transform="rotate(8 146 70)")
		d.path("M118 88 Q130 96 140 88 Q152 98 168 98", "none", stroke="#2a2a2a", stroke_width=5)
		for k in range(4):
			d.rect(128 + k * 10, 60, 7, 10, INK, transform="rotate(8 146 70)")
	elif kind == "rug":
		d.path("M20 70 L180 52 L186 160 L14 176 Z", "#8e2b4a", stroke=INK, stroke_width=4)
		d.path("M34 80 L168 64 L172 148 L28 162 Z", "none", stroke="#d9a845", stroke_width=3)
		d.path("M60 112 Q90 92 130 104 Q150 120 118 132 Q80 138 60 112 Z", "#8f8a82", opacity=0.9)
		rng = random.Random(909)
		for _ in range(26):
			d.circle(70 + rng.uniform(0, 70), 104 + rng.uniform(0, 26), rng.uniform(1.6, 3.2), "#ff7eb9", stroke="#ffffff", stroke_width=0.6)
	else:
		d.path("M12 120 L188 104 L196 146 L8 166 Z", OAK, stroke=INK, stroke_width=4)
		d.path("M40 112 L150 102 L156 132 L42 144 Z", "#3a6a4a", stroke=INK, stroke_width=2.5)
		d.path("M70 112 L118 108 L122 128 L72 134 Z", "#4c8a60", opacity=0.9)
		d.path("M150 60 Q148 94 160 104 L186 102 Q194 90 190 58 Z", "#f4efe2", stroke=INK, stroke_width=3)
		d.ellipse(170, 60, 20, 6, "#6a3a1e", stroke=INK, stroke_width=2)
		d.path("M30 30 L54 30 L50 104 L34 106 Z", BRASS_D, stroke=INK, stroke_width=3)
		d.path("M10 34 Q42 0 74 34 Z", "#3a6a4a", stroke=INK, stroke_width=3)
		glow(d, 42, 44, 34, SUN, 0.5)


ITEMS = {
	"an_teapot": (320, 300, teapot),
	"an_item_hourglass": (260, 340, item_hourglass),
	"an_glass": (W, H, glass_pane),
	"an_item_torch": (380, 230, item_torch),
	"an_stewpot": (440, 320, stewpot),
	"an_door": (420, 760, door),
	"clue_night3_ash": (200, 200, lambda d: clue_card(d, "ash")),
	"clue_night3_rug": (200, 200, lambda d: clue_card(d, "rug")),
	"clue_night3_desk": (200, 200, lambda d: clue_card(d, "desk")),
	"an_bat": (260, 160, bat),
	"an_bandage": (170, 140, bandage),
	"an_item_view": (380, 300, item_view),
	"an_beam": (420, 1100, beam),
	"an_item_pass": (340, 220, item_pass),
	"an_gaol_view": (W, H, gaol_view),
	"an_item_telescope": (260, 340, item_telescope),
	"an_ledger": (420, 300, ledger),
	"an_ledger_page": (260, 340, ledger_page),
	"an_item_strongbox": (340, 290, item_strongbox),
	"an_shutter": (W, H, shutter),
	"an_desk_l": (430, 300, lambda d: desk_half(d, True)),
	"an_desk_r": (430, 300, lambda d: desk_half(d, False)),
	"an_snn_set": (W, H, set_wall),
	"an_snn_counter": (1280, 270, counter),
	"an_snn_logo": (300, 300, logo),
	"an_pedestal": (320, 340, pedestal),
	"an_item_key": (360, 330, item_key),
}


def main():
	only = set(a for a in sys.argv[1:] if not a.startswith("-"))
	os.makedirs(OUT, exist_ok=True)
	for name, (w, h, fn) in ITEMS.items():
		if only and name not in only:
			continue
		d = Doc(w, h)
		fn(d)
		txt = d.svg()
		with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as f:
			f.write(txt)
		print("%-14s %6.1f KB" % (name, len(txt) / 1024.0))


if __name__ == "__main__":
	main()
