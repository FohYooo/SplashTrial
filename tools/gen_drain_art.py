#!/usr/bin/env python3
"""SPLASH TRIAL - "PULL THE PLUG" lake-drain cutscene art (docs/DESIGN2.md section 8).

Writes art/props/dr_*.svg for scripts/screens/drain_screen.gd:
  dr_cave       1280x720 cavern backdrop: ceiling + stalactites, glowing aqua fungus, festoons of paper
                lanterns along the back wall, Snapjaw banners, the iron pulley the plug chain hangs from
  dr_mud        1280x720 the drained lake bed (transparent above the far shore): wet mud flats, puddles,
                junk, and the plug-hole whirl-scar
  dr_dock       1280x720 the stone pier in the left foreground with lit lantern posts
  dr_front      1280x720 foreground framing (stalactites, rock) for parallax
  dr_ship       1200x660 the paddle-steamer *Mudlark*, side view (bow left), without its wheel
  dr_ship_over  1200x660 the near-side wheel beam + hub cap (drawn over the turning wheel)
  dr_wheel      260x260  the red stern paddle wheel (rotated in code)
  dr_plug       240x260  the giant rubber bath plug with its brass ring
  dr_grip       520x440  extreme close-up: Snapjaw's claw gripping the brass pull handle

Usage (from the project root):  python3 tools/gen_drain_art.py
Only SVG 1.1 basics are used (no text / filters / images / CSS) so Godot's ThorVG rasterizes it.
The SVG toolkit and motifs (crest, croc camera, lanterns) come from tools/gen_bgs.py (imported read-only).
Constants marked "shared with drain_screen.gd" must stay in sync with the screen.
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_bgs as GB  # noqa: E402  (helpers only - never modified)
from gen_bgs import Doc, G, T, fm, smooth, glow, mix, dark, light, blob_pts  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "props")
W, H = 1280, 720

INK = "#2a1a10"
AQUA = "#3ee0d0"
AQUA_L = "#a8fff3"
FUNGUS = "#5ff5e0"
LANTERN = "#ffcf7a"
BRASS = "#d9a845"
BRASS_L = "#ffe39a"
BRASS_D = "#8a6420"
TEAL_P = "#3d918c"
TEAL_D = "#22585a"
WHITE_P = "#dcd5c0"
WHITE_S = "#aaa28a"
GRIME = "#5b4630"
MUD = "#3a2a21"
RED_W = "#c8372d"
RED_WD = "#7c1c17"
WOOD = "#6a4428"
WOOD_D = "#3c2414"
WEED = "#2f5a34"
WEED_L = "#5a8f3e"
ROCK = "#1b1730"

# ---------------------------------------------------------------- shared with drain_screen.gd
SHIP_W, SHIP_H = 1200, 660
KEEL = 640               # hull bottom (svg y)
DECK_MAIN = 520          # main deck / guard line
DECK_PROM = 430          # promenade deck slab top
DECK_TEX = 340           # texas deck slab top
STACK_X = (467, 546)     # smokestack centres
STACK_TOP = 44           # crown tips (canvas y, after the SHIP_DY shift)
STACK_HW = 22
WHISTLE = (506, 22)      # steam whistle mouth (inner ship coords; canvas y + SHIP_DY)
WHEEL_C = (1040, 520)
WHEEL_R = 124
PLAQUE_BOW = (130, 536, 210, 32)     # x, y, w, h - the code writes the ship's name on it
PLAQUE_ARCH = (985, 368, 110, 24)
SHORE_Y = 330            # dr_cave / dr_mud / water: far shoreline (ship_dock's lake edge)
HOLE = (690, 612)        # dr_mud: plug hole centre (as in ship_dock)
FESTOON = [(232, 232), (470, 252), (700, 244), (935, 250), (1100, 232)]   # dr_cave back-wall lantern posts
SHIP_DY = 110            # dr_ship / dr_ship_over: the drawing is shifted down by this (taller stacks)
PLUG_RING = (120, 22)    # dr_plug: chain attachment
GRIP_TOP = (260, 26)     # dr_grip: chain attachment


def catenary(a, b, sag, n):
	"""n points evenly spaced (by t) on a sagging string a -> b (excluding the ends)."""
	out = []
	for i in range(n):
		t = (i + 0.5) / n
		x = a[0] + (b[0] - a[0]) * t
		y = a[1] + (b[1] - a[1]) * t + sag * 4 * t * (1 - t)
		out.append((x, y))
	return out


def string_path(a, b, sag, steps=24):
	p = []
	for i in range(steps + 1):
		t = i / steps
		p.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t + sag * 4 * t * (1 - t)))
	return "M" + " L".join("%s %s" % (fm(float(x)), fm(float(y))) for x, y in p)


# lantern strings on the ship: (from, to, sag, count) - inner (unshifted) ship coordinates
LANTERN_STRINGS = [
	((62, 284), (445, 160), 46, 5),
	((568, 160), (665, 228), 22, 3),
	((665, 228), (932, 298), 40, 5),
]
LANTERN_ROW_Y = 458
LANTERN_ROW_X = [190, 280, 370, 460, 550, 640, 730, 820]


def lantern_positions():
	out = []
	for a, b, sag, n in LANTERN_STRINGS:
		for p in catenary(a, b, sag, n):
			out.append((p[0], p[1] + 14))     # lantern body hangs 14 px under the string
	for x in LANTERN_ROW_X:
		out.append((x, LANTERN_ROW_Y))
	return out


LANTERN_COLS = ["#c0392b", "#e0782a", "#e3b23c"]


# ---------------------------------------------------------------- small motifs
def fungus(d, x, y, s, rng, n=5, a=1.0, up=True):
	"""Cluster of glowing aqua mushroom caps (up=False: hanging from a ceiling)."""
	glow(d, x, y, 70 * s, FUNGUS, 0.32 * a)
	glow(d, x, y, 26 * s, AQUA_L, 0.35 * a)
	for _ in range(n):
		cx = x + rng.uniform(-26, 26) * s
		cy = y + rng.uniform(-8, 8) * s
		r = rng.uniform(4, 10) * s
		sg = -1 if up else 1
		d.line(cx, cy, cx + rng.uniform(-2, 2) * s, cy - sg * r * 1.4, "#2a6f6a", max(1.0, r * 0.35), opacity=0.9 * a)
		top = cy - sg * r * 1.4
		d.path("M%s %s Q%s %s %s %s Z" % (fm(cx - r), fm(top), fm(cx), fm(top - sg * r * 1.3), fm(cx + r), fm(top)),
			FUNGUS, opacity=0.95 * a)
		d.ellipse(cx - r * 0.25, top - sg * r * 0.45, r * 0.35, r * 0.2, "#e9fffb", opacity=0.8 * a)


def stalactite(d, x, y0, w, h, rng, col="#120e24", rim=AQUA, rim_a=0.35):
	"""Tapered rock icicle hanging from y0."""
	k = rng.uniform(-0.15, 0.15)
	p = [(x - w / 2, y0 - 4), (x + w / 2, y0 - 4)]
	tip = (x + k * w, y0 + h)
	path = "M%s %s L%s %s Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (
		p[0][0], p[0][1], p[1][0], p[1][1], x + w * 0.32, y0 + h * 0.5, tip[0], tip[1], x - w * 0.36, y0 + h * 0.45, p[0][0], p[0][1]))
	d.path(path, d.lin(x - w / 2, 0, x + w / 2, 0, [(0, light(col, 0.12)), (0.45, col), (1, dark(col, 0.4))]))
	d.spath("M%s %s Q%s %s %s %s" % tuple(fm(float(v)) for v in (x - w / 2 + 2, y0, x - w * 0.3, y0 + h * 0.4, x - w * 0.12 + k * w * 0.5, y0 + h * 0.72)),
		rim, max(1.5, w * 0.08), opacity=rim_a)
	if rng.random() < 0.5:
		d.circle(tip[0], tip[1] + 6, max(1.5, w * 0.05), AQUA_L, opacity=0.7)


def banner(d, bx, by, w, h):
	d.path("M%s %s L%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(float(v)) for v in (
		bx - w / 2, by, bx + w / 2, by, bx + w / 2, by + h, bx, by + h + 30, bx - w / 2, by + h)),
		d.vlin(by, by + h + 30, [(0, "#8a1c3c"), (1, "#4e0c22")]))
	d.rect(bx - w / 2 - 8, by - 8, w + 16, 12, GB.GOLD_D)
	d.spath("M%s %s L%s %s L%s %s" % tuple(fm(float(v)) for v in (bx - w / 2 + 7, by + 6, bx - w / 2 + 7, by + h - 4, bx, by + h + 22)),
		GB.GOLD, 2, opacity=0.8)
	d.spath("M%s %s L%s %s L%s %s" % tuple(fm(float(v)) for v in (bx + w / 2 - 7, by + 6, bx + w / 2 - 7, by + h - 4, bx, by + h + 22)),
		GB.GOLD, 2, opacity=0.8)
	# tattered damp hem
	d.path("M%s %s L%s %s L%s %s Z" % tuple(fm(float(v)) for v in (bx - w / 2 + 10, by + h - 2, bx - w / 2 + 20, by + h + 10, bx - w / 2 + 28, by + h + 4)),
		"#120618")
	GB.snapjaw_crest(d, bx, by + h * 0.42, w / 115.0)


def lantern_body(d, x, y, col, s=1.0, lit=False):
	"""Small paper lantern on a ship string (centre x, y)."""
	if lit:
		glow(d, x, y, 38 * s, LANTERN, 0.5)
	base = col if lit else mix(col, "#2a2030", 0.45)
	d.line(x, y - 14 * s, x, y - 10 * s, "#1a1010", 1.4 * s)
	d.ellipse(x, y, 9 * s, 12 * s, d.rad(x - 2 * s, y - 3 * s, 12 * s, [(0, light(base, 0.25)), (0.7, base), (1, dark(base, 0.4))]),
		stroke=INK, stroke_width=1.4 * s)
	d.spath("M%s %s Q%s %s %s %s M%s %s Q%s %s %s %s" % tuple(fm(float(v)) for v in (
		x - 8.5 * s, y - 3 * s, x, y - 1.5 * s, x + 8.5 * s, y - 3 * s, x - 8.5 * s, y + 3.5 * s, x, y + 5 * s, x + 8.5 * s, y + 3.5 * s)),
		dark(base, 0.45), 1.0 * s, opacity=0.7)
	d.rect(x - 4.5 * s, y - 13.5 * s, 9 * s, 3.4 * s, "#22160f")
	d.rect(x - 4.5 * s, y + 10.5 * s, 9 * s, 3.4 * s, "#22160f")


def chain_beads(d, x, y0, y1, r=9.0, col="#b9b4a8"):
	"""A vertical ball chain (beads + little connectors)."""
	step = r * 2.5
	y = y0
	while y <= y1:
		d.rect(x - r * 0.18, y, r * 0.36, step, "#4a4640")
		y += step
	y = y0
	while y <= y1:
		d.circle(x + 1.5, y + 2, r, "#000000", opacity=0.35)
		d.circle(x, y, r, d.rad(x - r * 0.35, y - r * 0.4, r * 1.3, [(0, "#ffffff"), (0.25, light(col, 0.3)), (0.7, col), (1, dark(col, 0.55))]),
			stroke=INK, stroke_width=max(1.2, r * 0.18))
		y += step


# ---------------------------------------------------------------- dr_cave
def cave(d):
	"""Laid out to match art/bg/ship_dock.svg (far shore ~y 330, banners at x 150 / 1130)."""
	rng = random.Random(803)
	sy = SHORE_Y
	d.rect(0, 0, W, H, d.vlin(0, H, [(0, "#05060e"), (0.3, "#0b1220"), (0.46, "#122030"), (1, "#0d0f18")]))
	glow(d, 640, sy - 40, 640, "#1b6f7c", 0.26, ry=170)
	glow(d, 330, sy - 60, 260, "#2a9a96", 0.14, ry=110)
	glow(d, 980, sy - 70, 280, "#2a9a96", 0.14, ry=110)
	# back wall strata
	for k in range(8):
		y = 150 + k * 23 + rng.uniform(-5, 5)
		pts_ = []
		for x in range(-40, W + 41, 80):
			pts_.append((x, y + math.sin(x * 0.006 + k) * 10 + rng.uniform(-4, 4)))
		dd = "M" + " L".join("%s %s" % (fm(float(px)), fm(float(py))) for px, py in pts_)
		d.spath(dd, "#1c2c44" if k % 2 else "#0a0e18", rng.uniform(6, 13), opacity=0.55)
	for _ in range(14):
		cx = rng.uniform(140, 1140)
		cy = rng.uniform(170, sy - 30)
		rx = rng.uniform(60, 150)
		ry = rng.uniform(22, 50)
		p = blob_pts(cx, cy, rx, ry, rng, 9, 0.18)
		d.blob(p, d.lin(cx, cy - ry, cx, cy + ry, [(0, "#20344e"), (0.5, "#142236"), (1, "#0b1220")]), opacity=0.85)
		d.spath("M%s %s Q%s %s %s %s" % tuple(fm(float(v)) for v in (cx - rx * 0.7, cy - ry * 0.4, cx, cy - ry * 1.05, cx + rx * 0.6, cy - ry * 0.55)),
			AQUA, 2, opacity=0.2)
	# side walls
	left = [(0, 0), (230, 0), (205, 80), (170, 150), (190, 220), (150, 280), (140, sy), (0, sy + 10)]
	d.blob(left, d.lin(0, 0, 230, 0, [(0, "#04060b"), (0.75, "#0c1420"), (1, "#16263a")]), t=0.6)
	right = [(W, 0), (1045, 0), (1070, 90), (1105, 160), (1090, 230), (1125, 290), (1140, sy), (W, sy + 10)]
	d.blob(right, d.lin(W, 0, 1045, 0, [(0, "#04060b"), (0.75, "#0c1420"), (1, "#16263a")]), t=0.6)
	d.spath(smooth(left[1:-1], False, 0.6), AQUA, 3, opacity=0.24)
	d.spath(smooth(right[1:-1], False, 0.6), AQUA, 3, opacity=0.24)
	# far ledge path along the back wall
	ledge = [(150, sy - 16), (300, sy - 28), (470, sy - 20), (640, sy - 32), (820, sy - 22), (1000, sy - 30), (1135, sy - 16),
		(1135, sy + 4), (150, sy + 4)]
	d.blob(ledge, d.vlin(sy - 34, sy + 4, [(0, "#243650"), (1, "#0e1626")]), t=0.4)
	d.spath(smooth(ledge[:7], False, 0.4), "#5f8fa8", 2, opacity=0.5)
	# festoons of paper lanterns along the back wall (reflected in the lake)
	for x, y in FESTOON:
		d.rect(x - 4, y, 8, sy - 22 - y, "#141c28")
		d.rect(x - 7, y - 6, 14, 8, "#2e4058")
	for i in range(len(FESTOON) - 1):
		a, b = FESTOON[i], FESTOON[i + 1]
		d.spath(string_path(a, b, 26), "#070a10", 1.6)
		for j, (lx, ly) in enumerate(catenary(a, b, 26, 4)):
			col = ["#e8553d", "#f08a3a", "#e8553d", "#f2c04a"][(i + j) % 4]
			glow(d, lx, ly + 9, 26, LANTERN, 0.5)
			d.ellipse(lx, ly + 9, 6, 8, d.rad(lx - 2, ly + 6, 9, [(0, light(col, 0.6)), (0.6, col), (1, dark(col, 0.3))]))
			d.rect(lx - 3.5, ly, 7, 3, "#22160f")
			d.rect(lx - 3.5, ly + 16, 7, 3, "#22160f")
	# far shoreline
	shore = [(-20, sy + 8), (90, sy - 6), (200, sy + 2), (330, sy - 8), (470, sy), (610, sy - 10), (760, sy), (900, sy - 9), (1040, sy + 2),
		(1170, sy - 6), (1300, sy + 4), (1300, sy + 34), (-20, sy + 34)]
	d.blob(shore, d.vlin(sy - 14, sy + 34, [(0, "#22364a"), (1, "#0c121a")]), t=0.5)
	d.spath(smooth(shore[:11], False, 0.5), "#7fb4c8", 1.6, opacity=0.45)
	d.rect(0, sy + 26, W, H - sy - 26, "#12100f")
	# ceiling mass
	ceil = [(-20, -10), (W + 20, -10), (W + 20, 50), (1120, 64), (980, 84), (860, 70), (740, 96), (640, 84), (540, 100), (420, 78),
		(300, 92), (180, 68), (60, 80), (-20, 60)]
	d.blob(ceil, d.vlin(0, 110, [(0, "#020308"), (1, "#0b1220")]), t=0.5)
	xs = sorted(rng.uniform(0, W) for _ in range(38))
	for x in xs:
		w = rng.uniform(18, 54)
		h = rng.uniform(28, 110) * (1.3 if rng.random() < 0.2 else 1.0)
		y0 = 60 + 22 * math.sin(x * 0.01) + rng.uniform(0, 18)
		stalactite(d, x, y0, w, h, rng, col="#0e1624")
	# glowing fungus (placed like the clusters in ship_dock)
	for (fx, fy, s, up) in [(60, 226, 1.1, True), (130, 318, 1.0, True), (46, 392, 0.9, True), (1215, 214, 1.1, True), (1160, 336, 1.0, True),
			(1240, 404, 0.9, True), (330, 96, 0.7, False), (610, 104, 0.8, False), (880, 92, 0.8, False), (470, 250, 0.5, True),
			(820, 236, 0.6, True), (560, sy - 30, 0.6, True), (760, sy - 30, 0.6, True), (1000, sy - 36, 0.6, True)]:
		fungus(d, fx, fy, s, rng, n=rng.randint(4, 7), up=up)
	banner(d, 150, 74, 92, 190)
	banner(d, 1130, 74, 92, 190)
	GB.vignette(d, 0.45, "#04060c", 0.58)


def pulley(d):
	"""The ceiling pulley the plug chain hangs from (only shown before the drain). Chain exit at (70, 100)."""
	px, py = 70, 100
	d.rect(px - 9, 0, 18, py - 52, "#2a2836", stroke=INK, stroke_width=2)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(float(v)) for v in (px - 46, py - 60, px + 46, py - 60, px + 30, py - 40, px - 30, py - 40)),
		"#3a3848", stroke=INK, stroke_width=2.5)
	d.circle(px + 3, py - 22, 34, "#000000", opacity=0.4)
	d.circle(px, py - 26, 34, d.rad(px - 8, py - 36, 40, [(0, "#8b8aa0"), (0.6, "#4e4c60"), (1, "#25232f")]), stroke=INK, stroke_width=3)
	for k in range(6):
		a = k / 6 * math.tau
		d.line(px, py - 26, px + math.cos(a) * 28, py - 26 + math.sin(a) * 28, "#2a2836", 4)
	d.circle(px, py - 26, 26, "none", stroke="#6e6c84", stroke_width=3)
	d.circle(px, py - 26, 8, BRASS, stroke=INK, stroke_width=2)
	d.circle(px, py - 26, 34, "none", stroke=AQUA, stroke_width=1.5, opacity=0.35)


# ---------------------------------------------------------------- dr_mud
def mud(d):
	rng = random.Random(1717)
	top = SHORE_Y - 4
	edge = [(-20, top + 8)]
	for x in range(60, W + 1, 80):
		edge.append((x, top + rng.uniform(-3, 5)))
	edge.append((W + 20, top + 8))
	poly = edge + [(W + 20, H + 20), (-20, H + 20)]
	d.blob(poly, d.vlin(top, H, [(0, "#1c1a1e"), (0.25, "#2a2220"), (0.6, "#3a2c22"), (1, "#45321f")]), t=0.3)
	d.rect(0, top, W, 34, d.vlin(top, top + 34, [(0, "#3b6a72", 0.45), (1, "#3b6a72", 0)]))
	for k in range(28):
		f = k / 27
		y = top + 10 + (H - top) * (f ** 1.5)
		x0 = rng.uniform(-60, 300)
		while x0 < W + 40:
			ln = rng.uniform(60, 220) * (0.4 + f)
			amp = 2 + 5 * f
			d.spath("M%s %s Q%s %s %s %s" % (fm(x0), fm(y), fm(x0 + ln / 2), fm(y - amp), fm(x0 + ln), fm(y)), "#5c4636", 1 + 2.2 * f, opacity=0.5)
			d.spath("M%s %s Q%s %s %s %s" % (fm(x0 + 4), fm(y + 2 + f * 3), fm(x0 + ln / 2), fm(y - amp + 2 + f * 3), fm(x0 + ln - 4), fm(y + 2 + f * 3)),
				"#1c1412", 1 + 1.4 * f, opacity=0.5)
			x0 += ln + rng.uniform(20, 120)
	# puddles (placed like ship_dock's)
	for (px, py, rx) in [(1060, 548, 92), (1170, 640, 82), (140, 680, 72), (900, 690, 66), (300, 372, 50), (980, 420, 54),
			(1200, 380, 46), (560, 360, 44), (760, 352, 40), (540, 700, 60)]:
		ry = rx * (0.12 + (py - top) / (H - top) * 0.22)
		d.ellipse(px, py, rx, ry, d.vlin(py - ry, py + ry, [(0, "#2d6f78"), (0.5, "#163844"), (1, "#0d222a")]))
		d.ellipse(px - rx * 0.2, py - ry * 0.3, rx * 0.5, max(1.5, ry * 0.18), AQUA_L, opacity=0.35)
		d.ellipse(px, py, rx, ry, "none", stroke="#5c4636", stroke_width=2, opacity=0.7)
	for (rx_, ry_, s) in [(1240, 470, 0.9), (1000, 360, 0.5), (460, 690, 0.7), (1110, 700, 1.0)]:
		GB.rock(d, rx_, ry_, 46 * s, 22 * s, rng, color="#4a4054", top_light=0.18)
	for _ in range(30):
		x = rng.uniform(0, W)
		y = rng.uniform(top + 20, H)
		f = (y - top) / (H - top)
		ln = (14 + 40 * f) * rng.uniform(0.6, 1.3)
		dd = "M%s %s q%s %s %s %s" % (fm(x), fm(y), fm(ln * 0.4), fm(-ln * 0.25), fm(ln), fm(rng.uniform(-4, 4)))
		d.spath(dd, WEED, 1.5 + 3 * f, opacity=0.85)
		d.spath(dd, WEED_L, 0.6 + 1.2 * f, opacity=0.6)
	# a giant rubber duck, half buried (the resort's lost spa toy)
	with G(d, transform=T(1130, 476, 0.62, rot=12)):
		d.ellipse(0, 6, 64, 10, "#000000", opacity=0.3)
		d.path("M-60 0 Q-62 -40 -20 -44 Q10 -46 36 -36 Q60 -26 58 0 Z", d.vlin(-46, 0, [(0, "#ffe066"), (1, "#d9a521")]), stroke=INK, stroke_width=3)
		d.circle(30, -62, 28, d.rad(22, -72, 34, [(0, "#fff0a0"), (1, "#e0b22a")]), stroke=INK, stroke_width=3)
		d.path("M54 -62 Q78 -60 76 -52 Q70 -48 52 -52 Z", "#f08a2a", stroke=INK, stroke_width=2.5)
		d.circle(38, -70, 4.5, INK)
		d.circle(36.5, -71.5, 1.4, "#ffffff")
		d.path("M-64 -2 Q0 -14 62 -2 L64 8 L-66 8 Z", "#3a2a21")
	with G(d, transform=T(1010, 650, 0.9, rot=8)):
		d.path("M-40 -30 L30 -38 L36 20 L-34 26 Z", d.lin(-40, 0, 36, 0, [(0, "#8a5a34"), (1, "#5a3a20")]), stroke=INK, stroke_width=3)
		d.ellipse(33, -9, 9, 29, "#2a1a10", stroke=INK, stroke_width=3)
		d.line(-20, -32, -16, 23, "#c0c4cc", 4)
		d.line(14, -36, 18, 21, "#c0c4cc", 4)
	for (yx, yy, r) in [(430, 640, 9), (860, 560, 8), (960, 600, 7), (1180, 560, 10), (620, 690, 11), (350, 700, 9)]:
		d.circle(yx, yy + 2, r, "#000000", opacity=0.3)
		d.circle(yx, yy, r, d.rad(yx - r * 0.3, yy - r * 0.3, r * 1.2, [(0, "#ffe27a"), (0.6, "#ffb627"), (1, "#c97a10")]), stroke=INK, stroke_width=1.6)
		d.ellipse(yx - r * 0.3, yy - r * 0.35, r * 0.32, r * 0.18, "#ffffff", opacity=0.6)
	# the plug-hole whirl-scar (ship_dock: hole 116x35 at (690, 612), scar +-270 x +-84)
	hx, hy = HOLE
	ky = 84.0 / 270.0
	for k in range(6):
		rr = 270 - k * 38
		d.ellipse(hx, hy, rr, rr * ky, "none", stroke="#251a16", stroke_width=6 - k * 0.6, opacity=0.55)
		d.ellipse(hx, hy - 2, rr, rr * ky, "none", stroke="#6a5240", stroke_width=1.8, opacity=0.45)
	dd = ""
	for arm in range(4):
		pts_ = []
		for i in range(44):
			f = i / 43
			a = arm * math.tau / 4 + f * 4.4
			rr = 62 + 208 * f
			pts_.append((hx + math.cos(a) * rr, hy + math.sin(a) * rr * ky))
		dd += "M" + " L".join("%s %s" % (fm(float(x)), fm(float(y))) for x, y in pts_) + " "
	d.spath(dd, "#1c1412", 5, opacity=0.6)
	d.spath(dd, "#7a604a", 1.5, opacity=0.4)
	d.ellipse(hx, hy + 3, 74, 25, "#5a4232", opacity=0.6)
	d.ellipse(hx, hy, 66, 22, "#1a120e")
	d.ellipse(hx, hy + 1, 58, 17.5, d.vlin(hy - 17, hy + 18, [(0, "#000000"), (0.7, "#03080a"), (1, "#0c2a2e")]))
	d.path("M%s %s Q%s %s %s %s" % tuple(fm(float(v)) for v in (hx - 50, hy + 8, hx, hy + 22, hx + 50, hy + 8)), "none", stroke="#2d6f78", stroke_width=2, opacity=0.6)
	d.ellipse(hx, hy, 66, 22, "none", stroke="#7a604a", stroke_width=2, opacity=0.6)


# ---------------------------------------------------------------- dr_dock
def dock(d):
	"""The stone jetty, same footprint as ship_dock's: top (0,432)-(382,452)-(412,490)-(0,520), face down to (412,556)/(0,640)."""
	rng = random.Random(55)
	face = [(0, 520), (412, 490), (412, 556), (0, 640)]
	d.poly(face, d.lin(0, 520, 0, 640, [(0, "#3a4650"), (1, "#202830")]))
	dd = ""
	for k in range(1, 5):
		f = k / 5
		dd += "M0 %s L412 %s " % (fm(520 + 120 * f), fm(490 + 66 * f))
	for k in range(12):
		x = 18 + k * 34 + (k % 2) * 10
		yt = 520 - 30 * (x / 412)
		dd += "M%s %s L%s %s " % (fm(x), fm(yt), fm(x), fm(yt + 120 - 54 * (x / 412)))
	d.spath(dd, "#141a20", 2, opacity=0.8)
	d.poly([(0, 560), (412, 514), (412, 540), (0, 600)], "#4a6a40", opacity=0.3)   # algae band
	d.poly([(0, 600), (412, 540), (412, 556), (0, 640)], "#101418", opacity=0.5)
	d.line(412, 490, 412, 556, "#0c1014", 3)
	top = [(0, 432), (382, 452), (412, 490), (0, 520)]
	d.poly(top, d.lin(0, 432, 0, 520, [(0, "#5a6068"), (1, "#787c84")]))
	dd = ""
	for k in range(1, 4):
		f = k / 4
		dd += "M0 %s L%s %s " % (fm(432 + 88 * f), fm(382 + 30 * f), fm(452 + 38 * f))
	for k in range(9):
		x0 = 20 + k * 44
		dd += "M%s %s L%s %s " % (fm(x0), fm(432 + x0 * 0.052), fm(x0 * 1.05 + 8), fm(520 - x0 * 0.073))
	d.spath(dd, "#3a3e46", 2, opacity=0.7)
	d.spath("M0 520 L412 490", "#a8b4bc", 3, opacity=0.6)
	d.spath("M0 523 L412 493", "#14181c", 2, opacity=0.8)
	d.ellipse(110, 488, 70, 9, AQUA_L, opacity=0.1)
	for (x, y, s) in [(330, 466, 0.75), (372, 472, 0.8)]:
		d.ellipse(x, y + 4 * s, 18 * s, 6 * s, "#000000", opacity=0.35)
		d.path("M%s %s L%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (
			x - 12 * s, y, x - 10 * s, y - 30 * s, x, y - 36 * s, x + 10 * s, y - 30 * s, x + 12 * s, y, x, y + 5 * s, x - 12 * s, y)),
			d.lin(x - 12 * s, 0, x + 12 * s, 0, [(0, "#2a2a36"), (0.4, "#6a6a80"), (1, "#20202a")]), stroke=INK, stroke_width=2)
		d.ellipse(x, y - 32 * s, 15 * s, 6 * s, "#4a4a5c", stroke=INK, stroke_width=2)
	for (x, y, hgt, s) in [(400, 484, 112, 0.8)]:
		d.ellipse(x, y + 4, 20 * s, 6 * s, "#000000", opacity=0.35)
		d.rect(x - 5 * s, y - hgt, 10 * s, hgt, d.lin(x - 5 * s, 0, x + 5 * s, 0, [(0, "#16141e"), (0.5, "#3e3a50"), (1, "#14121a")]), stroke=INK, stroke_width=1.5)
		d.rect(x - 12 * s, y - 14 * s, 24 * s, 14 * s, "#24202e", stroke=INK, stroke_width=1.5)
		d.path("M%s %s L%s %s L%s %s" % tuple(fm(float(v)) for v in (x, y - hgt, x + 30 * s, y - hgt, x + 30 * s, y - hgt + 10 * s)),
			"none", stroke="#2a2636", stroke_width=5 * s)
		GB.chochin(d, x + 30 * s, y - hgt + 48 * s, 0.58 * s, color="#e8553d", lit=True, glow_a=0.6)


# ---------------------------------------------------------------- dr_front
def front(d):
	rng = random.Random(91)
	tl = [(-20, -20), (360, -20), (330, 18), (250, 36), (190, 30), (120, 70), (60, 60), (-20, 120)]
	d.blob(tl, "#050409", t=0.5)
	tr = [(W + 20, -20), (880, -20), (930, 20), (1010, 30), (1100, 60), (1180, 50), (W + 20, 110)]
	d.blob(tr, "#050409", t=0.5)
	for (x, w, h) in [(30, 60, 230), (110, 40, 170), (176, 34, 120), (250, 26, 80), (300, 18, 60),
			(1250, 64, 250), (1170, 44, 180), (1100, 30, 110), (1020, 24, 70), (960, 18, 50)]:
		stalactite(d, x, 0 if x < 640 else 10, w, h, rng, col="#07060e", rim_a=0.3)
	br = [(W + 20, H + 20), (1010, H + 20), (1030, 690), (1080, 650), (1150, 630), (1230, 618), (W + 20, 600)]
	d.blob(br, d.vlin(600, H, [(0, "#0d0a18"), (1, "#050409")]), t=0.5)
	d.spath(smooth(br[2:6], False, 0.5), AQUA, 2, opacity=0.35)
	fungus(d, 1180, 640, 1.1, rng, n=6)
	fungus(d, 1060, 676, 0.8, rng, n=4)


# ---------------------------------------------------------------- dr_ship
def ship(d):
	rng = random.Random(1907)
	d.open(transform="translate(0 %d)" % SHIP_DY)
	# --- far-side wheel beam (behind the wheel)
	d.rect(950, 498, 220, 12, WOOD_D, stroke=INK, stroke_width=2)
	# wheel guard arch (behind the wheel)
	wx, wy = WHEEL_C
	arc_r = 138
	dd = "M%s %s A%s %s 0 0 1 %s %s" % (fm(wx - arc_r), fm(wy - 6), fm(arc_r), fm(arc_r), fm(wx + arc_r), fm(wy - 6))
	d.spath(dd, INK, 22, stroke_linecap="butt")
	d.spath(dd, RED_WD, 16, stroke_linecap="butt")
	d.spath(dd, "#e8e0cc", 4, stroke_linecap="butt", opacity=0.8)
	for k in range(9):
		a = math.pi + (k + 0.5) / 9 * math.pi
		d.line(wx + math.cos(a) * (arc_r - 8), wy - 6 + math.sin(a) * (arc_r - 8), wx + math.cos(a) * (arc_r + 8), wy - 6 + math.sin(a) * (arc_r + 8), "#f4ecd8", 2)
	d.rect(wx - arc_r - 6, wy - 10, 14, 40, WOOD_D, stroke=INK, stroke_width=2)
	d.rect(wx + arc_r - 8, wy - 10, 14, 40, WOOD_D, stroke=INK, stroke_width=2)
	px, py, pw, ph = PLAQUE_ARCH
	d.rect(px, py, pw, ph, "#2c1a0e", stroke=BRASS, stroke_width=3, rx=4)
	d.rect(px + 4, py + 4, pw - 8, ph - 8, "none", stroke=BRASS_D, stroke_width=1)

	# --- hull
	top = DECK_MAIN
	hull = "M40 %d L962 %d L968 600 Q966 634 936 %d L170 %d Q118 %d 90 612 Q58 576 40 %d Z" % (top, top, KEEL, KEEL, KEEL, top)
	d.path(hull, d.vlin(top, KEEL, [(0, "#4aa39d"), (0.3, TEAL_P), (0.55, TEAL_D), (0.72, "#1d3c3e"), (0.8, "#3b2c22"), (1, "#2a1e17")]))
	hc = d.clip('<path d="%s"/>' % hull)
	with G(d, clip_path=hc):
		dd = ""
		for y in (548, 572, 596, 620):
			dd += "M30 %d L980 %d " % (y, y)
		d.spath(dd, "#10282a", 2, opacity=0.6)
		# rust/grime streaks and mud splatter
		for _ in range(26):
			x = rng.uniform(60, 950)
			y0 = rng.uniform(526, 560)
			d.spath("M%s %s q%s %s %s %s" % (fm(x), fm(y0), fm(rng.uniform(-3, 3)), fm(20), fm(rng.uniform(-4, 4)), fm(rng.uniform(30, 70))),
				rng.choice(["#6a4a2a", "#3a2a1a", "#7a5a32"]), rng.uniform(2, 6), opacity=rng.uniform(0.25, 0.5))
		for _ in range(30):
			x = rng.uniform(80, 960)
			y = rng.uniform(588, 640)
			d.blob(blob_pts(x, y, rng.uniform(10, 34), rng.uniform(5, 12), rng, 7, 0.3), MUD, opacity=0.8)
		d.rect(30, 598, 960, 50, d.vlin(590, 640, [(0, MUD, 0), (0.4, MUD, 0.7), (1, "#1e1510", 1)]))
		d.rect(30, top, 960, 18, "#ffffff", opacity=0.08)
	d.path(hull, "none", stroke=INK, stroke_width=3.5, stroke_linejoin="round")
	# name plaque on the bow (the code writes the name)
	px, py, pw, ph = PLAQUE_BOW
	d.rect(px + 3, py + 4, pw, ph, "#000000", opacity=0.35, rx=5)
	d.rect(px, py, pw, ph, d.vlin(py, py + ph, [(0, "#4a2c16"), (1, "#2a180a")]), stroke=BRASS, stroke_width=3, rx=5)
	d.rect(px + 5, py + 5, pw - 10, ph - 10, "none", stroke=BRASS_D, stroke_width=1.2, rx=3)
	# portholes
	for x in range(420, 940, 64):
		d.circle(x + 1, 559, 10, "#000000", opacity=0.3)
		d.circle(x, 557, 10, "#0f1a26", stroke=BRASS, stroke_width=3.5)
		d.path("M%s %s Q%s %s %s %s" % (fm(x - 6), fm(553), fm(x - 2), fm(549), fm(x + 3), fm(550)), "none", stroke="#9fd6e0", stroke_width=1.6, opacity=0.6)
		d.spath("M%s 568 q-2 16 1 34" % fm(x - 2), "#6a4a2a", 4, opacity=0.35)
	GB.snapjaw_crest(d, 380, 566, 0.34)
	# rub rail
	d.rect(34, top - 6, 934, 13, d.vlin(top - 6, top + 7, [(0, "#8a5a32"), (1, WOOD_D)]), stroke=INK, stroke_width=2.5)
	d.line(36, top - 4, 966, top - 4, BRASS_L, 1.4, opacity=0.6)
	# bow: capstan, bollard, rail
	d.rect(78, 494, 40, 20, d.lin(78, 0, 118, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=2, rx=3)
	d.ellipse(98, 494, 22, 6, BRASS, stroke=INK, stroke_width=2)
	d.rect(126, 500, 14, 14, "#2a2a32", stroke=INK, stroke_width=1.5)
	dd = ""
	for x in range(48, 152, 13):
		dd += "M%s 496 L%s 514 " % (fm(x + (x - 48) * 0.0), fm(x))
	d.spath(dd, "#e8e0cc", 2.5)
	d.spath("M44 496 L150 496 M44 505 L150 505", "#e8e0cc", 2.5)

	# --- main deck house
	hx0, hx1, hy0 = 150, 900, 438
	d.rect(hx0, hy0, hx1 - hx0, top - 6 - hy0, d.vlin(hy0, top, [(0, WHITE_P), (0.6, "#cfc7b0"), (1, "#a69c82")]), stroke=INK, stroke_width=2.5)
	d.rect(hx0, hy0, hx1 - hx0, 8, TEAL_P, stroke=INK, stroke_width=1.5)
	d.rect(hx0, top - 16, hx1 - hx0, 10, TEAL_D, stroke=INK, stroke_width=1.5)
	for k in range(12):
		x = 180 + 62 * k
		if k in (5, 10):
			# doors
			d.rect(x - 2, 452, 40, 56, d.vlin(452, 508, [(0, TEAL_P), (1, TEAL_D)]), stroke=INK, stroke_width=2)
			d.rect(x + 4, 458, 28, 18, "#142030", stroke=BRASS_D, stroke_width=1.5)
			d.circle(x + 31, 486, 2.4, BRASS)
			continue
		d.path("M%s 498 L%s 466 Q%s 448 %s 466 L%s 498 Z" % (fm(x), fm(x), fm(x + 17), fm(x + 34), fm(x + 34)), "#142030", stroke=BRASS, stroke_width=2.5)
		d.line(x + 17, 452, x + 17, 498, BRASS_D, 1.4)
		d.path("M%s 494 L%s 470 L%s 466 L%s 490 Z" % (fm(x + 4), fm(x + 4), fm(x + 10), fm(x + 10)), "#9fd6e0", opacity=0.22)
		d.spath("M%s 500 q-1 8 1 16" % fm(x + 10), GRIME, 3, opacity=0.35)
	# grime wash on the house
	d.rect(hx0, hy0, hx1 - hx0, top - 6 - hy0, d.vlin(hy0, top, [(0, GRIME, 0.05), (0.5, GRIME, 0.18), (1, GRIME, 0.5)]))
	# columns at the guard edge
	for x in range(168, 900, 92):
		d.rect(x - 4, 442, 8, top - 448, "#e4ddc8", stroke=INK, stroke_width=1.5)

	# --- promenade deck slab + gingerbread
	d.rect(70, DECK_PROM, 870, 13, d.vlin(DECK_PROM, DECK_PROM + 13, [(0, "#efe8d4"), (1, "#b9b09a")]), stroke=INK, stroke_width=2.5)
	d.rect(70, DECK_PROM + 9, 870, 4, TEAL_D)
	dd = ""
	for x in range(74, 936, 20):
		dd += "M%s %s Q%s %s %s %s " % (fm(x), fm(DECK_PROM + 13), fm(x + 10), fm(DECK_PROM + 25), fm(x + 20), fm(DECK_PROM + 13))
	d.spath(dd, "#e8e0cc", 2)
	# --- texas house
	tx0, tx1, ty0 = 290, 830, DECK_TEX + 6
	d.rect(tx0, ty0, tx1 - tx0, DECK_PROM - ty0, d.vlin(ty0, DECK_PROM, [(0, WHITE_P), (1, "#b4ab92")]), stroke=INK, stroke_width=2.5)
	d.rect(tx0, ty0, tx1 - tx0, 7, TEAL_P, stroke=INK, stroke_width=1.5)
	for k in range(11):
		x = 312 + 46 * k
		if k == 6:
			d.rect(x - 2, 362, 30, 66, d.vlin(362, 428, [(0, TEAL_P), (1, TEAL_D)]), stroke=INK, stroke_width=2)
			continue
		d.rect(x, 368, 26, 26, "#142030", stroke=BRASS, stroke_width=2.2)
		d.line(x + 13, 368, x + 13, 394, BRASS_D, 1.2)
		d.path("M%s 390 L%s 372 L%s 372 L%s 390 Z" % (fm(x + 3), fm(x + 3), fm(x + 8), fm(x + 8)), "#9fd6e0", opacity=0.2)
	d.rect(tx0, ty0, tx1 - tx0, DECK_PROM - ty0, d.vlin(ty0, DECK_PROM, [(0, GRIME, 0.05), (1, GRIME, 0.4)]))
	# promenade rail (in front of the texas house)
	dd = ""
	for x in range(82, 938, 15):
		dd += "M%s %s L%s %s " % (fm(x), fm(DECK_PROM - 30), fm(x), fm(DECK_PROM))
	d.spath(dd, "#e8e0cc", 2.2)
	d.spath("M78 %s L938 %s" % (fm(DECK_PROM - 31), fm(DECK_PROM - 31)), INK, 6)
	d.spath("M78 %s L938 %s" % (fm(DECK_PROM - 31), fm(DECK_PROM - 31)), "#efe8d4", 3.4)
	d.spath("M78 %s L938 %s" % (fm(DECK_PROM - 14), fm(DECK_PROM - 14)), "#e8e0cc", 1.6)
	# a small wooden onsen tub on the promenade (bow end)
	d.path("M96 %s L102 %s L162 %s L168 %s Z" % (fm(DECK_PROM - 26), fm(DECK_PROM), fm(DECK_PROM), fm(DECK_PROM - 26)),
		d.lin(96, 0, 168, 0, [(0, "#8a5a34"), (0.5, "#b07a48"), (1, "#6a4426")]), stroke=INK, stroke_width=2)
	d.line(98, DECK_PROM - 18, 166, DECK_PROM - 18, "#c0c4cc", 2.5)
	d.line(100, DECK_PROM - 7, 164, DECK_PROM - 7, "#c0c4cc", 2.5)
	d.ellipse(132, DECK_PROM - 26, 36, 5, "#3a9aa0", stroke=INK, stroke_width=1.5)
	# --- texas deck slab
	d.rect(270, DECK_TEX, 580, 11, d.vlin(DECK_TEX, DECK_TEX + 11, [(0, "#efe8d4"), (1, "#b9b09a")]), stroke=INK, stroke_width=2.5)
	dd = ""
	for x in range(274, 846, 18):
		dd += "M%s %s Q%s %s %s %s " % (fm(x), fm(DECK_TEX + 11), fm(x + 9), fm(DECK_TEX + 21), fm(x + 18), fm(DECK_TEX + 11))
	d.spath(dd, "#e8e0cc", 1.8)
	dd = ""
	for x in range(280, 846, 14):
		if 596 < x < 734 or any(abs(x - sx) < 26 for sx in STACK_X):
			continue
		dd += "M%s %s L%s %s " % (fm(x), fm(DECK_TEX - 18), fm(x), fm(DECK_TEX))
	d.spath(dd, "#e8e0cc", 2)
	d.spath("M276 %s L596 %s M734 %s L846 %s" % ((fm(DECK_TEX - 19),) * 4), "#efe8d4", 3)
	# --- smokestacks
	for sx in STACK_X:
		d.rect(sx - STACK_HW + 4, -24, STACK_HW * 2, DECK_TEX + 24, "#000000", opacity=0.3)
		d.rect(sx - STACK_HW, -30, STACK_HW * 2, DECK_TEX + 30, d.lin(sx - STACK_HW, 0, sx + STACK_HW, 0,
			[(0, "#121118"), (0.32, "#3b3948"), (0.5, "#26242f"), (1, "#0e0d13")]), stroke=INK, stroke_width=2.5)
		for by in (60, 190):
			d.rect(sx - STACK_HW, by, STACK_HW * 2, 7, "#0a090e")
		d.rect(sx - STACK_HW - 3, 302, STACK_HW * 2 + 6, 12, d.lin(sx - 25, 0, sx + 25, 0, [(0, BRASS_D), (0.35, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=2)
		d.rect(sx - STACK_HW - 3, -26, STACK_HW * 2 + 6, 10, d.lin(sx - 25, 0, sx + 25, 0, [(0, BRASS_D), (0.35, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=2)
		# feathered crown
		cw = 34
		pts_ = [(sx - cw, -22)]
		for k in range(7):
			x = sx - cw + (k + 0.5) * (2 * cw / 7)
			pts_.append((x - cw / 14 * 0.6,  -46 + abs(k - 3) * 3))
			pts_.append((x, STACK_TOP - SHIP_DY + abs(k - 3) * 4))
			pts_.append((x + cw / 14 * 0.6,  -46 + abs(k - 3) * 3))
		pts_.append((sx + cw, -22))
		d.poly(pts_, d.lin(sx - cw, 0, sx + cw, 0, [(0, BRASS_D), (0.35, BRASS_L), (0.6, BRASS), (1, BRASS_D)]), stroke=INK, stroke_width=2.2, stroke_linejoin="round")
		d.ellipse(sx, -22, STACK_HW + 2, 5, "#050407", stroke=INK, stroke_width=1.5)
		d.line(sx - 12, -10, sx - 12, 296, "#ffffff", 3, opacity=0.1)
		# soot + weed caught on the stack
		d.blob(blob_pts(sx + 6, 0, 14, 10, rng, 7, 0.3), "#050407", opacity=0.6)
		d.spath("M%s %s q4 18 -2 36" % (fm(sx - STACK_HW + 2), fm(120)), WEED, 3, opacity=0.8)
	# spreader bar + whistle + crest sign between the stacks
	d.rect(STACK_X[0], 40, STACK_X[1] - STACK_X[0], 7, "#2a2836", stroke=INK, stroke_width=1.5)
	wx_, wy_ = WHISTLE
	d.rect(wx_ - 4, wy_ + 4, 8, 40 - wy_ - 4, BRASS_D, stroke=INK, stroke_width=1.2)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(float(v)) for v in (wx_ - 7, wy_ + 6, wx_ - 5, wy_ - 6, wx_ + 5, wy_ - 6, wx_ + 7, wy_ + 6)),
		BRASS, stroke=INK, stroke_width=1.5)
	d.ellipse(wx_, wy_ - 6, 5, 2, BRASS_L, stroke=INK, stroke_width=1)
	cx_ = (STACK_X[0] + STACK_X[1]) / 2
	d.line(cx_ - 22, 47, cx_ - 12, 70, "#3a3848", 2)
	d.line(cx_ + 22, 47, cx_ + 12, 70, "#3a3848", 2)
	GB.snapjaw_crest(d, cx_, 96, 0.52)
	# --- pilothouse
	px0, px1, py0 = 600, 730, 264
	d.rect(px0, py0, px1 - px0, DECK_TEX - py0, d.vlin(py0, DECK_TEX, [(0, WHITE_P), (1, "#b7ae96")]), stroke=INK, stroke_width=2.5)
	for k in range(3):
		x = 610 + k * 38
		d.rect(x, 276, 32, 38, "#122032", stroke=BRASS, stroke_width=2.2)
		d.path("M%s 310 L%s 280 L%s 280 L%s 310 Z" % (fm(x + 4), fm(x + 14), fm(x + 20), fm(x + 10)), "#9fd6e0", opacity=0.22)
	d.rect(px0, 322, px1 - px0, 8, TEAL_P, stroke=INK, stroke_width=1.5)
	d.path("M586 266 L744 266 L724 238 L606 238 Z", d.vlin(238, 266, [(0, TEAL_P), (1, TEAL_D)]), stroke=INK, stroke_width=2.5, stroke_linejoin="round")
	d.line(588, 266, 742, 266, BRASS, 3)
	d.line(665, 238, 665, 222, BRASS_D, 3)
	d.circle(665, 222, 7, d.rad(662, 219, 8, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=1.5)
	GB.croc_cam(d, 730, 284, 0.42)
	# ship's bell
	d.rect(766, 296, 4, 44, WOOD_D)
	d.rect(802, 296, 4, 44, WOOD_D)
	d.rect(762, 292, 48, 6, WOOD, stroke=INK, stroke_width=1.2)
	d.path("M774 300 Q774 324 768 330 L804 330 Q798 324 798 300 Q786 292 774 300 Z", d.lin(768, 0, 804, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=1.8)
	# --- flag staffs + pennants
	d.line(60, top, 60, 278, INK, 7)
	d.line(60, top, 60, 278, WOOD, 4)
	d.circle(60, 276, 5, BRASS, stroke=INK, stroke_width=1.5)
	d.path("M62 288 L122 302 L62 316 Z", "#5a1f6e", stroke=GB.GOLD, stroke_width=2)
	d.circle(80, 302, 5, GB.GOLD)
	d.line(932, DECK_PROM, 932, 292, INK, 7)
	d.line(932, DECK_PROM, 932, 292, WOOD, 4)
	d.circle(932, 290, 5, BRASS, stroke=INK, stroke_width=1.5)
	d.path("M934 300 Q962 296 990 312 Q962 318 934 326 Z", "#43a047", stroke=INK, stroke_width=2)
	# --- lantern strings (unlit; the code lights them)
	for a, b, sag, n in LANTERN_STRINGS:
		d.spath(string_path(a, b, sag), "#1a1010", 1.8)
	d.spath("M84 %s L930 %s" % (fm(LANTERN_ROW_Y - 15), fm(LANTERN_ROW_Y - 15)), "#1a1010", 1.4, opacity=0.8)
	for i, (lx, ly) in enumerate(lantern_positions()):
		lantern_body(d, lx, ly, LANTERN_COLS[i % 3], 1.0, lit=False)
	# --- weeds hanging from deck edges (it was all underwater)
	for (y, x0, x1, n, mx) in [(top + 7, 50, 950, 22, 60), (DECK_PROM + 13, 80, 930, 16, 40), (DECK_TEX + 11, 280, 840, 9, 30)]:
		for _ in range(n):
			x = rng.uniform(x0, x1)
			ln = rng.uniform(12, mx)
			dd = "M%s %s q%s %s %s %s" % (fm(x), fm(y), fm(rng.uniform(-6, 6)), fm(ln * 0.6), fm(rng.uniform(-5, 5)), fm(ln))
			d.spath(dd, WEED, rng.uniform(2.5, 4.5), opacity=0.9)
			d.spath(dd, WEED_L, 1.2, opacity=0.6)
	# barnacle dots on the lower hull
	for _ in range(40):
		x = rng.uniform(100, 940)
		y = rng.uniform(575, 630)
		d.circle(x, y, rng.uniform(1.5, 3.5), "#8a8478", opacity=0.7)
	d.close()


def ship_over(d):
	"""Near-side wheel beam + hub cap, drawn over the turning wheel."""
	wx, wy = WHEEL_C
	d.open(transform="translate(0 %d)" % SHIP_DY)
	d.rect(948, wy - 9, 228, 18, d.vlin(wy - 9, wy + 9, [(0, "#8a5a32"), (1, WOOD_D)]), stroke=INK, stroke_width=2.5)
	for x in (980, 1110, 1160):
		d.circle(x, wy, 2.6, BRASS_L, stroke=INK, stroke_width=1)
	d.circle(wx, wy, 19, d.rad(wx - 5, wy - 5, 22, [(0, BRASS_L), (0.6, BRASS), (1, BRASS_D)]), stroke=INK, stroke_width=2.5)
	d.circle(wx, wy, 7, BRASS_D, stroke=INK, stroke_width=1.5)
	# the crank arm from the engine
	d.path("M900 %s L%s %s L%s %s L900 %s Z" % (fm(wy - 18), fm(wx - 8), fm(wy - 5), fm(wx - 8), fm(wy + 5), fm(wy - 8)),
		d.vlin(wy - 18, wy + 5, [(0, "#4a4858"), (1, "#22202a")]), stroke=INK, stroke_width=2)
	d.close()


def wheel(d):
	c = 130
	for k in range(12):
		a = k * 30
		with G(d, transform="translate(%d %d) rotate(%s)" % (c, c, fm(float(a)))):
			d.rect(-13, -126, 26, 44, d.lin(-13, 0, 13, 0, [(0, RED_WD), (0.4, "#e0503f"), (1, RED_WD)]), stroke=INK, stroke_width=2.5)
			d.line(0, -122, 0, -86, "#6a1410", 1.5)
			d.circle(-7, -90, 1.8, "#d8d0c0")
			d.circle(7, -90, 1.8, "#d8d0c0")
	for k in range(12):
		a = (k * 30 + 15) * math.pi / 180
		x2, y2 = c + math.cos(a) * 104, c + math.sin(a) * 104
		d.line(c, c, x2, y2, INK, 10)
		d.line(c, c, x2, y2, "#a32a22", 6)
	for r, w in ((104, 9), (86, 6), (48, 7)):
		d.circle(c, c, r, "none", stroke=INK, stroke_width=w + 4)
		d.circle(c, c, r, "none", stroke=RED_W if r != 86 else "#9a241d", stroke_width=w)
	d.circle(c, c, 104, "none", stroke="#ff8a70", stroke_width=1.5, opacity=0.5)
	d.circle(c, c, 22, d.rad(c - 6, c - 6, 26, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=2.5)
	rng = random.Random(4)
	for _ in range(22):
		a = rng.uniform(0, math.tau)
		r = rng.uniform(30, 120)
		d.circle(c + math.cos(a) * r, c + math.sin(a) * r, rng.uniform(1.5, 4), MUD, opacity=0.7)


def plug(d):
	cx = 120
	# ring
	d.circle(cx, 62, 40, "none", stroke=INK, stroke_width=20)
	d.circle(cx, 62, 40, "none", stroke=BRASS, stroke_width=13)
	d.circle(cx, 62, 40, "none", stroke=BRASS_L, stroke_width=3, opacity=0.8)
	d.rect(cx - 16, 96, 32, 28, d.lin(cx - 16, 0, cx + 16, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=2.5, rx=4)
	# rubber body
	body = "M16 124 L52 226 Q120 250 188 226 L224 124 Q120 150 16 124 Z"
	d.path(body, d.lin(16, 0, 224, 0, [(0, "#18151e"), (0.28, "#4c4658"), (0.45, "#2c2834"), (1, "#110f15")]), stroke=INK, stroke_width=3.5)
	for y, k in ((152, 0.08), (180, 0.16), (206, 0.24)):
		d.spath("M%s %s Q120 %s %s %s" % (fm(16 + (y - 124) * 0.35), fm(y), fm(y + 22), fm(224 - (y - 124) * 0.35), fm(y)), "#0a090d", 3, opacity=0.8)
		d.spath("M%s %s Q120 %s %s %s" % (fm(18 + (y - 124) * 0.35), fm(y + 3), fm(y + 25), fm(222 - (y - 124) * 0.35), fm(y + 3)), "#6a6478", 1.2, opacity=0.6)
	d.ellipse(cx, 124, 104, 24, d.rad(cx - 20, 118, 110, [(0, "#5a546a"), (1, "#24202c")]), stroke=INK, stroke_width=3)
	d.ellipse(cx - 30, 118, 40, 7, "#ffffff", opacity=0.14)
	GB.snapjaw_crest(d, cx, 194, 0.32, a=0.9)
	# mud + weed clinging to it
	rng = random.Random(8)
	for _ in range(10):
		d.blob(blob_pts(rng.uniform(40, 200), rng.uniform(200, 236), rng.uniform(6, 16), rng.uniform(3, 7), rng, 7, 0.3), MUD, opacity=0.85)
	d.spath("M60 222 q-6 14 2 30 M178 224 q8 12 0 26", WEED, 3.5)


def grip(d):
	gx, gy = GRIP_TOP
	# stem from the chain to the T-bar
	d.circle(gx, gy, 16, d.rad(gx - 5, gy - 5, 20, [(0, "#ffffff"), (0.3, "#d8d2c4"), (1, "#5a564c")]), stroke=INK, stroke_width=3)
	d.rect(gx - 13, gy + 12, 26, 196, d.lin(gx - 13, 0, gx + 13, 0, [(0, BRASS_D), (0.35, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=3.5)
	d.rect(gx - 20, gy + 186, 40, 22, d.lin(gx - 20, 0, gx + 20, 0, [(0, BRASS_D), (0.35, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=3, rx=4)
	# T-bar handle
	d.rect(62, 216, 396, 54, d.vlin(216, 270, [(0, BRASS_L), (0.35, BRASS), (1, BRASS_D)]), stroke=INK, stroke_width=4, rx=27)
	d.line(84, 226, 436, 226, "#fff6d0", 3, opacity=0.7)
	for x in (70, 450):
		d.circle(x, 243, 36, d.rad(x - 10, 232, 40, [(0, BRASS_L), (0.6, BRASS), (1, BRASS_D)]), stroke=INK, stroke_width=4)
		d.circle(x - 10, 232, 9, "#ffffff", opacity=0.45)
	GB.snapjaw_crest(d, 150, 243, 0.34)
	# sleeve (black tux + white cuff + gold cufflink), from the bottom right
	d.path("M330 440 L376 340 Q420 316 470 330 L520 360 L520 440 Z", d.lin(330, 340, 520, 440, [(0, "#2a2634"), (1, "#0c0a10")]), stroke=INK, stroke_width=3.5)
	d.path("M352 352 Q392 318 452 326 L470 352 Q410 344 372 372 Z", "#f4f0e6", stroke=INK, stroke_width=3)
	d.circle(436, 340, 7, GB.GOLD, stroke=INK, stroke_width=2)
	# forearm / palm (green scales left, chrome plates right)
	d.path("M250 300 Q240 262 270 250 L392 250 Q420 262 412 300 L388 352 Q350 368 300 352 Z",
		d.lin(250, 0, 412, 0, [(0, "#3f7f45"), (0.55, "#4f8f52"), (0.56, "#c3ccd6"), (1, "#7d8a99")]), stroke=INK, stroke_width=3.5)
	for k in range(6):
		x = 266 + k * 14
		y = 300 + (k % 2) * 12
		d.path("M%s %s q7 -8 14 0" % (fm(x), fm(y)), "none", stroke="#2f5e37", stroke_width=2)
	d.line(340, 258, 340, 352, "#7d8a99", 1.6)
	for (x, y) in ((362, 300), (386, 290), (372, 330)):
		d.circle(x, y, 3, "#e8eef4", stroke=INK, stroke_width=1)
	# thumb wrapping from below on the left
	d.path("M262 300 Q228 296 222 268 Q220 246 244 242 Q262 244 266 262 Z", "#4f8f52", stroke=INK, stroke_width=3)
	d.path("M226 262 Q222 244 236 240 L230 254 Z", "#fffbe8", stroke=INK, stroke_width=1.5)
	# four fingers curled over the bar (knuckles toward the viewer), claws hooked below
	for k in range(4):
		x = 276 + k * 34
		chrome = k >= 2
		base = "#c3ccd6" if chrome else "#4f8f52"
		shade = "#7d8a99" if chrome else "#2f5e37"
		d.path("M%s 206 Q%s 196 %s 206 L%s 262 Q%s 276 %s 262 Z" % (fm(x - 15), fm(x), fm(x + 15), fm(x + 16), fm(x), fm(x - 16)),
			d.vlin(196, 276, [(0, light(base, 0.25)), (0.6, base), (1, shade)]), stroke=INK, stroke_width=3)
		d.path("M%s 232 Q%s 226 %s 232" % (fm(x - 13), fm(x), fm(x + 13)), "none", stroke=shade, stroke_width=2.2)
		d.path("M%s 262 Q%s 290 %s 298 Q%s 282 %s 262 Z" % (fm(x - 9), fm(x - 4), fm(x + 2), fm(x + 6), fm(x + 9)), "#fffbe8", stroke=INK, stroke_width=2)
		d.ellipse(x - 5, 212, 5, 3, "#ffffff", opacity=0.4)
	# motion strain lines
	d.spath("M196 196 l-22 -16 M200 214 l-28 -6 M478 196 l24 -16 M476 214 l30 -6", "#ffffff", 4, opacity=0.8)


ITEMS = {
	"dr_cave": (W, H, cave),
	"dr_mud": (W, H, mud),
	"dr_dock": (W, H, dock),
	"dr_front": (W, H, front),
	"dr_ship": (SHIP_W, SHIP_H + SHIP_DY, ship),
	"dr_ship_over": (SHIP_W, SHIP_H + SHIP_DY, ship_over),
	"dr_pulley": (140, 110, pulley),
	"dr_wheel": (260, 260, wheel),
	"dr_plug": (240, 260, plug),
	"dr_grip": (520, 440, grip),
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
		print("%-13s %6.1f KB" % (name, len(txt) / 1024.0))
	if "--print" in sys.argv:
		print("LANTERNS (svg x, y):")
		print(", ".join("Vector2(%.1f, %.1f)" % (p[0], p[1] + SHIP_DY) for p in lantern_positions()))


if __name__ == "__main__":
	main()
