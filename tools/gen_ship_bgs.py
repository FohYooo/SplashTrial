#!/usr/bin/env python3
"""SPLASH TRIAL - Chapter 2 ("Murder on the Mudlark") background generator.

Writes the 11 ship backgrounds art/bg/ship_*.svg (1280x720, SVG 1.1 basics only: no text, filters, images or styles).
It reuses the tiny SVG toolkit + motifs of tools/gen_bgs.py (imported read-only, no bytecode written) so the
Mudlark matches the Chapter 1 look: painterly-flat shapes, soft gradients, warm lantern light, Snapjaw crests/cameras.

Ship identity (keep consistent): old paddle-steamer "Mudlark", grimy white + teal paint, brass fittings, red stern
paddle wheel, twin black smokestacks with brass bands, paper lanterns, Snapjaw logos/cameras; warm lantern light
against the cold aqua glow of the cave fungus.

Usage (from the project root):
  python3 tools/gen_ship_bgs.py                       # write all ship backgrounds
  python3 tools/gen_ship_bgs.py --only ship_dock,ship_hall
  python3 tools/gen_ship_bgs.py --debug DIR           # also write DIR/dbg_<id>.svg with hotspot rects + portrait zones

Investigation hotspot rects come from scripts/data/investigation_data2.gd (fallback: the table below, = DESIGN2.md §7).
"""
import math
import os
import random
import re
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)

import gen_bgs as B  # noqa: E402
from gen_bgs import (Doc, G, T, fm, mix, dark, light, smooth, blob_pts, glow, vignette, light_wash, sparkle,  # noqa: E402
	glyphs, snapjaw_crest, croc_cam, steam, steam_wisps, floor_reflect, wooden_bucket,
	INK, LANTERN, LANTERN_HOT, YUZU, YUZU_D, GOLD, GOLD_D, RED_EYE)

W, H = B.W, B.H
ROOT = B.ROOT
TAU = math.tau

# --------------------------------------------------------------------------------------
# Mudlark palette
# --------------------------------------------------------------------------------------
HULL, HULL_D, HULL_L, HULL_G = "#e2d8c2", "#a99d83", "#f3ecdb", "#7d735f"
TEALP, TEALP_D, TEALP_L = "#2e8a83", "#1b5552", "#62b8ac"
BRASS, BRASS_D, BRASS_L = "#d8a945", "#8f6420", "#f7dd8e"
PRED, PRED_D, PRED_L = "#c43b30", "#7e231b", "#e86a52"
STACK, STACK_L = "#23252b", "#4d515b"
WOOD, WOOD_D, WOOD_L, WOOD_DD = "#8b5734", "#5a3720", "#b57d4d", "#36200f"
FUNG, FUNG_L = "#8cf6e6", "#d6fff8"
MUD, MUD_D, MUD_L = "#4e3c2d", "#281e16", "#7a6249"
SJ_MAROON = "#6a1d36"
IRON, IRON_D, IRON_L = "#3d4048", "#1f2126", "#666b76"
SCRUB, SCRUB_D, SCRUB_L = "#8fcbea", "#5e9fc4", "#c4e6f6"
MARI_FUR, MARI_SH, MARI_L = "#d98b55", "#b66d3a", "#eeb383"
LILAC, LILAC_D = "#c4a2df", "#8f6cb0"
LANTERN_COLORS = ("#e8553d", "#f4e9d2", YUZU, "#e8553d", "#f2a541")

HOTSPOTS = {
	"ship_infirmary_body": [("Marigold", 440, 440, 380, 140), ("Cot", 560, 260, 330, 130), ("Rounds log", 370, 140, 110, 140),
		("Kettle", 370, 320, 130, 110), ("Door", 880, 140, 90, 320)],
	"ship_boiler": [("Coal pile", 360, 360, 260, 200), ("Boot prints", 560, 590, 340, 100), ("Furnace", 680, 140, 240, 260),
		("Pressure gauges", 420, 130, 160, 120)],
	"ship_laundry": [("Boot rack", 380, 430, 220, 160), ("Drying line", 420, 110, 460, 200), ("Sewing basket", 660, 470, 160, 110),
		("Wash tubs", 800, 330, 140, 120)],
	"ship_hall": [("Cabin 1 (yours)", 370, 180, 150, 310), ("Cabin 2 (Tumble)", 560, 160, 160, 330), ("Cabin 3 (Pepper)", 760, 180, 150, 310),
		("Speaking tube", 490, 70, 70, 80)],
	"ship_tumble_cabin": [("Bunk & rug", 400, 330, 440, 330), ("Nightstand", 850, 360, 100, 150), ("Porthole", 560, 120, 140, 140),
		("Nightcap", 380, 120, 110, 140)],
	"ship_purser": [("Dictaphone", 560, 300, 200, 200), ("Cylinder rack", 370, 130, 170, 210), ("Safe", 800, 330, 140, 180),
		("Armchair", 380, 420, 160, 170)],
}


# --------------------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------------------

def F(*vals):
	return tuple(fm(float(v)) for v in vals)


def ridge(points, ybot):
	"""Smooth open curve through points, closed down to ybot (for terrain / rock silhouettes)."""
	return smooth(points, closed=False) + " L%s %s L%s %s Z" % F(points[-1][0], ybot, points[0][0], ybot)


def hang(points, ytop):
	"""Like ridge() but closed upward to ytop (for ceilings)."""
	return smooth(points, closed=False) + " L%s %s L%s %s Z" % F(points[-1][0], ytop, points[0][0], ytop)


def quad_pt(p0, c, p1, t):
	return ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1])


class Persp:
	"""One-point perspective: P(x, y, s) moves the back-plane point (x, y) toward the viewer by scale s (s=1: back wall)."""

	def __init__(self, vx, vy):
		self.vx, self.vy = float(vx), float(vy)

	def P(self, x, y, s=1.0):
		return (self.vx + (x - self.vx) * s, self.vy + (y - self.vy) * s)

	def Q(self, seq):
		return [self.P(*p) for p in seq]


FAR = 14.0


def pshell(d, pp, bx0, by0, bx1, by1, wall, wall2, side, ceil, floor1, floor2, side2=None):
	"""Back wall + ceiling + side walls + floor for a one-point room."""
	P = pp.P
	d.rect(0, 0, W, H, ceil)
	d.poly([P(bx0, by0), P(bx1, by0), P(bx1, by0, FAR), P(bx0, by0, FAR)], d.vlin(0, by0, [(0, dark(ceil, 0.4)), (1, ceil)]))
	for (bx, sd, edge) in ((bx0, side, 0), (bx1, side2 or side, W)):
		d.poly([P(bx, by0), P(bx, by1), P(bx, by1, FAR), P(bx, by0, FAR)], d.lin(edge, 0, bx, 0, [(0, dark(sd, 0.42)), (1, sd)]))
	d.poly([P(bx0, by1), P(bx1, by1), P(bx1, by1, FAR), P(bx0, by1, FAR)], d.vlin(by1, H, [(0, floor1), (1, floor2)]))
	d.rect(bx0, by0, bx1 - bx0, by1 - by0, d.vlin(by0, by1, [(0, wall), (1, wall2)]))


def pplanks(d, pp, bx0, bx1, by1, n, color, a=0.5, sw=1.6, joints=True, rng=None):
	P = pp.P
	dd = ""
	for i in range(n + 1):
		xb = bx0 + (bx1 - bx0) * i / n
		a0, a1 = P(xb, by1), P(xb, by1, FAR)
		dd += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
	d.spath(dd, color, sw, opacity=a, stroke_linecap="butt")
	if joints:
		r = rng or random.Random(5)
		dd = ""
		s = 1.0
		while s < 6:
			s *= 1.22
			for i in range(n):
				if r.random() < 0.3:
					xa = bx0 + (bx1 - bx0) * i / n
					xb = bx0 + (bx1 - bx0) * (i + 1) / n
					p0, p1 = P(xa, by1, s), P(xb, by1, s)
					dd += "M%s %s L%s %s " % F(p0[0], p0[1], p1[0], p1[1])
		d.spath(dd, color, sw, opacity=a * 0.8, stroke_linecap="butt")


def pbeams(d, pp, bx0, bx1, by0, svals, color, w=12, a=1.0):
	P = pp.P
	for s in svals:
		p0, p1 = P(bx0, by0, s), P(bx1, by0, s)
		d.spath("M%s %s L%s %s" % F(p0[0], p0[1], p1[0], p1[1]), color, w * s, opacity=a, stroke_linecap="butt")


def side_band(d, pp, bx, y0, y1, fill, s0=1.0, s1=FAR, **kw):
	"""Horizontal band on a side wall (bx = the wall's back-plane x) between back-plane heights y0..y1."""
	P = pp.P
	d.poly([P(bx, y0, s0), P(bx, y0, s1), P(bx, y1, s1), P(bx, y1, s0)], fill, **kw)


def side_line(d, pp, bx, y, color, sw, s0=1.0, s1=FAR, **kw):
	P = pp.P
	a, b = P(bx, y, s0), P(bx, y, s1)
	d.spath("M%s %s L%s %s" % F(a[0], a[1], b[0], b[1]), color, sw, **kw)


def digit(d, x, y, ch, s, color, sw=2.6):
	paths = {
		"1": "M-4 -7 L1 -11 L1 11 M-5 11 L7 11",
		"2": "M-6 -6 Q-5 -11 0 -11 Q6 -11 6 -5 Q6 -1 0 4 L-6 11 L7 11",
		"3": "M-6 -9 Q0 -13 5 -9 Q8 -4 0 -1 Q8 1 7 6 Q4 13 -6 9",
	}
	with G(d, transform=T(x, y, s)):
		d.spath(paths[ch], color, sw)


def rivet_row(d, x0, y0, x1, y1, n, r, color="#c9ccd2", shade="#1a1b1f"):
	for i in range(n):
		t = i / max(1, n - 1)
		x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
		d.circle(x + r * 0.3, y + r * 0.3, r, shade, opacity=0.6)
		d.circle(x, y, r, color)


# --------------------------------------------------------------------------------------
# Mudlark motifs
# --------------------------------------------------------------------------------------

def fungus(d, x, y, s=1.0, rng=None, n=5, a=1.0, up=True, glow_r=1.0):
	"""Cluster of glowing aqua cave mushrooms growing from (x,y). up=False: hanging from a ceiling."""
	r = rng or random.Random(int(x * 7 + y * 3))
	k = 1 if up else -1
	glow(d, x, y - 14 * s * k, 80 * s * glow_r, FUNG, 0.4 * a)
	items = []
	for _ in range(n):
		items.append((x + r.uniform(-22, 22) * s, r.uniform(6, 22) * s, r.uniform(6, 12) * s))
	items.sort(key=lambda it: -it[1])
	for (bx, hgt, cw) in items:
		top = y - k * hgt
		d.line(bx, y, bx, top, "#a9e9df", max(1.6, cw * 0.42), opacity=0.85 * a)
		cap = "M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(bx - cw, top + k * cw * 0.1, bx, top - k * cw * 1.25, bx + cw, top + k * cw * 0.1,
			bx, top - k * cw * 0.2, bx - cw, top + k * cw * 0.1)
		d.path(cap, d.rad(bx, top - k * cw * 0.5, cw * 1.2, [(0, "#ffffff"), (0.45, FUNG_L), (1, FUNG)]), opacity=a)
	dots = ""
	for _ in range(n + 2):
		dots += "M%s %s l0.1 0 " % F(x + r.uniform(-40, 40) * s, y - k * r.uniform(10, 60) * s)
	d.spath(dots, FUNG_L, max(1.4, 2.8 * s), opacity=0.6 * a)


def glow_patch(d, x, y, s=1.0, rng=None, n=7, a=1.0):
	"""Distant patch of bioluminescent fungus: a soft glow with bright specks."""
	r = rng or random.Random(int(x * 5 + y))
	glow(d, x, y, 46 * s, FUNG, 0.4 * a, ry=30 * s)
	for _ in range(n):
		px, py = x + r.uniform(-26, 26) * s, y + r.uniform(-12, 12) * s
		rr = r.uniform(1.2, 3.4) * s
		d.circle(px, py, rr * 2.2, FUNG, opacity=0.25 * a)
		d.circle(px, py, rr, FUNG_L, opacity=0.95 * a)


def glowworms(d, x, y, s=1.0, rng=None, n=5, a=1.0):
	"""Glowing threads hanging from a cave ceiling at (x,y)."""
	r = rng or random.Random(int(x * 3 + y))
	glow(d, x, y + 30 * s, 60 * s, FUNG, 0.3 * a, ry=50 * s)
	for _ in range(n):
		bx = x + r.uniform(-28, 28) * s
		ln = r.uniform(20, 70) * s
		d.line(bx, y, bx, y + ln, "#9fe8dd", max(0.8, 1.1 * s), opacity=0.55 * a)
		for j in range(r.randint(2, 4)):
			by = y + ln * r.uniform(0.3, 1.0)
			d.circle(bx, by, r.uniform(1.0, 2.0) * s, FUNG_L, opacity=0.9 * a)
		d.circle(bx, y + ln, 2.4 * s, "#ffffff", opacity=0.9 * a)
		d.circle(bx, y + ln, 6 * s, FUNG, opacity=0.25 * a)


def shelf_fungus(d, x, y, s=1.0, n=3, a=1.0, flip=False):
	"""Glowing bracket fungus on a wall/rock."""
	glow(d, x, y + 4 * s, 56 * s, FUNG, 0.38 * a)
	k = -1 if flip else 1
	for i in range(n):
		yy = y + i * 10 * s
		ww = (20 - i * 4) * s
		d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(x, yy - 5 * s, x + k * ww * 1.3, yy - 6 * s, x + k * ww * 1.45, yy + 2 * s,
			x + k * ww * 0.7, yy + 5 * s, x, yy + 3 * s), d.rad(x + k * ww * 0.6, yy - 2 * s, ww * 1.2, [(0, "#ffffff"), (0.4, FUNG_L), (1, FUNG)]), opacity=a)


def stalactites(d, rng, x0, x1, top, hmin, hmax, color, count, rim=None, drip=True, wmin=14, wmax=42):
	for _ in range(count):
		x = rng.uniform(x0, x1)
		w = rng.uniform(wmin, wmax)
		h = rng.uniform(hmin, hmax)
		p = [(x - w / 2, top), (x + w / 2, top), (x + w * 0.14, top + h * 0.72), (x + w * 0.02, top + h), (x - w * 0.1, top + h * 0.62)]
		d.poly(p, d.lin(x, top, x, top + h, [(0, dark(color, 0.35)), (1, color)]))
		if rim:
			d.line(x - w * 0.3, top + h * 0.1, x - w * 0.04, top + h * 0.86, rim, 1.6, opacity=0.55)
		if drip and rng.random() < 0.35:
			d.circle(x + w * 0.02, top + h + 7, 1.9, FUNG, opacity=0.75)


def mini_lantern(d, cx, cy, s=1.0, color="#e8553d", lit=True, glow_a=0.5):
	if lit:
		glow(d, cx, cy, 64 * s, LANTERN, glow_a)
	body = d.rad(cx - 4 * s, cy - 6 * s, 22 * s, [(0, light(color, 0.62) if lit else color), (0.6, color), (1, dark(color, 0.35))])
	d.ellipse(cx, cy, 15 * s, 20 * s, body)
	dd = ""
	for k in (-2, -1, 0, 1, 2):
		yy = cy + k * 6.5 * s
		hw = 15 * s * math.sqrt(max(0.0, 1 - (k * 6.5 / 20) ** 2))
		dd += "M%s %s Q%s %s %s %s " % F(cx - hw, yy, cx, yy + 2.4 * s, cx + hw, yy)
	d.spath(dd, dark(color, 0.45), 0.9 * s, opacity=0.55)
	d.rect(cx - 7 * s, cy - 23 * s, 14 * s, 4.5 * s, "#22160f", rx=1.5 * s)
	d.rect(cx - 7 * s, cy + 18.5 * s, 14 * s, 4.5 * s, "#22160f", rx=1.5 * s)
	d.line(cx, cy + 23 * s, cx, cy + 31 * s, "#c0392b", 1.4 * s)
	if lit:
		d.ellipse(cx - 4 * s, cy - 3 * s, 5 * s, 10 * s, LANTERN_HOT, opacity=0.42)


def lantern_string(d, p0, p1, sag, n, s, colors=LANTERN_COLORS, lit=True, glow_a=0.45, cord="#1a1210", start=0):
	c = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2 + 2 * sag)
	d.spath("M%s %s Q%s %s %s %s" % F(p0[0], p0[1], c[0], c[1], p1[0], p1[1]), cord, max(1.0, 1.7 * s))
	for i in range(n):
		t = (i + 0.5) / n
		bx, by = quad_pt(p0, c, p1, t)
		mini_lantern(d, bx, by + 23 * s, s, colors[(i + start) % len(colors)], lit, glow_a)


def ship_lamp(d, x, y, s=1.0, lit=True, hang_from=None, glow_a=0.5, glow_r=150):
	"""Brass caged ship lantern centred at (x,y). hang_from: ceiling y (draws a chain)."""
	if hang_from is not None:
		d.line(x, hang_from, x, y - 32 * s, "#2a1d14", 2.4 * s)
	if lit:
		glow(d, x, y, glow_r * s, LANTERN, glow_a)
	d.circle(x, y - 35 * s, 4 * s, "none", stroke=BRASS_D, stroke_width=2 * s)
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(x - 15 * s, y - 19 * s, x - 13 * s, y - 31 * s, x, y - 32 * s, x + 13 * s, y - 31 * s,
		x + 15 * s, y - 19 * s), d.lin(x - 15 * s, 0, x + 15 * s, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)]))
	glass = d.vlin(y - 19 * s, y + 14 * s, [(0, LANTERN_HOT), (1, LANTERN)]) if lit else "#6d6a62"
	d.rect(x - 12 * s, y - 19 * s, 24 * s, 33 * s, glass)
	if lit:
		d.ellipse(x, y + 2 * s, 4.5 * s, 8 * s, "#ffffff", opacity=0.85)
	dd = "M%s %s L%s %s M%s %s L%s %s M%s %s L%s %s" % F(x - 6 * s, y - 19 * s, x - 6 * s, y + 14 * s, x + 6 * s, y - 19 * s, x + 6 * s, y + 14 * s,
		x - 12 * s, y - 3 * s, x + 12 * s, y - 3 * s)
	d.spath(dd, BRASS_D, 1.6 * s, stroke_linecap="butt")
	d.rect(x - 16 * s, y - 21 * s, 32 * s, 4 * s, BRASS, rx=1.5 * s)
	d.rect(x - 16 * s, y + 13 * s, 32 * s, 5 * s, BRASS_D, rx=1.5 * s)
	d.path("M%s %s L%s %s L%s %s Z" % F(x - 9 * s, y + 18 * s, x + 9 * s, y + 18 * s, x, y + 27 * s), BRASS_D)


def wall_lamp(d, x, y, s=1.0, lit=True, side=1, glow_a=0.5):
	"""Ship lantern on an S-bracket; (x,y) = lamp centre, bracket goes to the wall on side -1 (left) / 1 (right)."""
	wx = x + side * 26 * s
	d.rect(wx - 4 * s if side > 0 else wx - 2 * s, y - 52 * s, 6 * s, 26 * s, BRASS_D, rx=2 * s)
	d.spath("M%s %s Q%s %s %s %s" % F(wx, y - 40 * s, x, y - 66 * s, x, y - 38 * s), BRASS_D, 3 * s)
	ship_lamp(d, x, y, s, lit, glow_a=glow_a)


def porthole(d, cx, cy, r, rng=None, view="cave", sx=1.0, frame=BRASS, a=1.0, glow_a=0.35):
	"""Brass porthole (global coords). sx<1 squashes it horizontally (a porthole on a side wall)."""
	rng = rng or random.Random(int(cx + cy))
	rx = r * sx
	d.ellipse(cx + 2, cy + r * 0.1, rx * 1.06, r * 1.06, "#000000", opacity=0.3)
	d.ellipse(cx, cy, rx, r, d.lin(cx - rx, cy - r, cx + rx, cy + r, [(0, BRASS_L), (0.45, frame), (1, BRASS_D)]))
	ri = r * 0.74
	rix = ri * sx
	d.ellipse(cx, cy, rix + r * 0.07 * sx, ri + r * 0.07, BRASS_D)
	cid = d.clip('<ellipse cx="%s" cy="%s" rx="%s" ry="%s"/>' % F(cx, cy, rix, ri))
	with G(d, clip_path=cid):
		if view == "cave":
			d.rect(cx - rix, cy - ri, rix * 2, ri * 2, d.vlin(cy - ri, cy + ri, [(0, "#05141a"), (0.55, "#0f3a40"), (1, "#22706c")]))
			glow(d, cx + rix * 0.2, cy + ri * 0.4, ri * 1.1, "#5fe0d0", 0.55 * a)
			d.path(ridge([(cx - rix, cy + ri * 0.35), (cx - rix * 0.4, cy + ri * 0.15), (cx + rix * 0.1, cy + ri * 0.4), (cx + rix, cy + ri * 0.2)], cy + ri),
				"#071418", opacity=0.9)
			for _ in range(5):
				fx = cx + rng.uniform(-0.8, 0.8) * rix
				fy = cy + rng.uniform(-0.3, 0.45) * ri
				d.circle(fx, fy, rng.uniform(1.5, 3.2) * r / 50, FUNG_L, opacity=0.9 * a)
				glow(d, fx, fy, 10 * r / 50, FUNG, 0.5 * a)
			dd = ""
			for k in range(4):
				x = cx + (-0.75 + k * 0.5) * rix
				dd += "M%s %s L%s %s L%s %s Z " % F(x - 6 * sx * r / 50, cy - ri, x + 6 * sx * r / 50, cy - ri, x + sx * r / 50, cy - ri + rng.uniform(14, 26) * r / 50)
			d.path(dd, "#03090c")
		elif view == "glow":
			d.rect(cx - rix, cy - ri, rix * 2, ri * 2, d.vlin(cy - ri, cy + ri, [(0, "#1d5a5c"), (1, "#56c9bd")]))
			glow(d, cx, cy + ri * 0.2, ri * 1.2, "#bff8f0", 0.6)
		else:
			d.rect(cx - rix, cy - ri, rix * 2, ri * 2, d.vlin(cy - ri, cy + ri, [(0, "#0a1418"), (1, "#173034")]))
		d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(cx - rix * 0.75, cy + ri * 0.15, cx - rix * 0.15, cy - ri * 0.9, cx + rix * 0.15, cy - ri * 0.9,
			cx - rix * 0.45, cy + ri * 0.45), "#ffffff", opacity=0.16)
		d.ellipse(cx, cy, rix, ri, d.brad([(0, "#bff8f0", 0), (0.8, "#bff8f0", 0.05), (1, "#000000", 0.35)]))
	d.ellipse(cx, cy, rix, ri, "none", stroke="#3a2a10", stroke_width=2)
	for k in range(8):
		ang = k / 8 * TAU + 0.2
		bx, by = cx + math.cos(ang) * r * 0.87 * sx, cy + math.sin(ang) * r * 0.87
		d.ellipse(bx, by, r * 0.06 * max(sx, 0.5), r * 0.06, BRASS_L, stroke=BRASS_D, stroke_width=0.8)
	d.path("M%s %s Q%s %s %s %s" % F(cx - rx * 0.8, cy - r * 0.55, cx - rx * 0.2, cy - r * 1.05, cx + rx * 0.5, cy - r * 0.85), "none",
		stroke="#ffffff", stroke_width=max(1.2, r * 0.05), opacity=0.45, stroke_linecap="round")


def lifebuoy(d, cx, cy, r, sx=1.0, a=1.0):
	rm = r * 0.72
	wb = r * 0.5
	with G(d, opacity=a if a < 1 else None):
		d.ellipse(cx + 3, cy + 4, r * sx, r, "#000000", opacity=0.28)
		d.ellipse(cx, cy, rm * sx, rm, "none", stroke="#f2ece0", stroke_width=wb)
		for k in range(4):
			a0 = k * TAU / 4 + TAU / 16
			a1 = a0 + TAU / 8
			p0 = (cx + math.cos(a0) * rm * sx, cy + math.sin(a0) * rm)
			p1 = (cx + math.cos(a1) * rm * sx, cy + math.sin(a1) * rm)
			d.spath("M%s %s A%s %s 0 0 1 %s %s" % F(p0[0], p0[1], rm * sx, rm, p1[0], p1[1]), PRED, wb, stroke_linecap="butt")
		d.ellipse(cx, cy, r * sx, r, "none", stroke="#3a2a22", stroke_width=1.6)
		d.ellipse(cx, cy, (rm - wb / 2) * sx, rm - wb / 2, "none", stroke="#3a2a22", stroke_width=1.4)
		d.path("M%s %s A%s %s 0 0 1 %s %s" % F(cx - rm * 0.7 * sx, cy - rm * 0.7, rm * sx, rm, cx + rm * 0.2 * sx, cy - rm * 0.98), "none",
			stroke="#ffffff", stroke_width=wb * 0.25, opacity=0.5, stroke_linecap="round")
		for k in range(4):
			ang = k * TAU / 4 + TAU / 8 + TAU / 16
			px, py = cx + math.cos(ang) * r * sx, cy + math.sin(ang) * r
			d.circle(px, py, r * 0.1, "#cdbb94", stroke="#6e5a3a", stroke_width=1)


def sj_banner(d, x, y, w, h, color=SJ_MAROON, a=1.0):
	"""Hanging Snapjaw banner: brass rod at (x,y) centre top, swallow-tail cloth with gold trim + crest."""
	with G(d, opacity=a if a < 1 else None):
		d.rect(x - w / 2 - 12, y - 5, w + 24, 8, BRASS, rx=3)
		d.circle(x - w / 2 - 14, y - 1, 6, BRASS_L)
		d.circle(x + w / 2 + 14, y - 1, 6, BRASS_L)
		cloth = "M%s %s L%s %s L%s %s L%s %s L%s %s Z" % F(x - w / 2, y + 3, x + w / 2, y + 3, x + w / 2, y + h, x, y + h - w * 0.28, x - w / 2, y + h)
		d.path(cloth, d.lin(x - w / 2, 0, x + w / 2, 0, [(0, dark(color, 0.35)), (0.45, light(color, 0.12)), (0.6, color), (1, dark(color, 0.4))]))
		d.path("M%s %s L%s %s L%s %s L%s %s L%s %s Z" % F(x - w / 2 + 7, y + 10, x + w / 2 - 7, y + 10, x + w / 2 - 7, y + h - 12, x, y + h - w * 0.28 - 10,
			x - w / 2 + 7, y + h - 12), "none", stroke=GOLD, stroke_width=2.6, stroke_linejoin="round")
		dd = ""
		for k in (0.25, 0.7):
			xx = x - w / 2 + w * k
			dd += "M%s %s L%s %s " % F(xx, y + 6, xx + 3, y + h - 20)
		d.spath(dd, "#000000", 6, opacity=0.14)
		snapjaw_crest(d, x, y + h * 0.36, w / 128)
		d.spath("M%s %s L%s %s M%s %s L%s %s" % F(x - w / 2 + 14, y + h * 0.66, x + w / 2 - 14, y + h * 0.66, x - w / 2 + 14, y + h * 0.7,
			x + w / 2 - 14, y + h * 0.7), GOLD, 2.2, stroke_linecap="butt")


def chain(d, points, link=15, w=5, color="#62666f", hi="#aeb6c2"):
	"""Chain of links along a polyline."""
	seg = []
	for i in range(len(points) - 1):
		(x0, y0), (x1, y1) = points[i], points[i + 1]
		ln = math.hypot(x1 - x0, y1 - y0)
		n = max(1, int(ln / link))
		for k in range(n):
			t = k / n
			seg.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, math.degrees(math.atan2(y1 - y0, x1 - x0))))
	for i, (x, y, ang) in enumerate(seg):
		with G(d, transform=T(x, y, 1, ang)):
			if i % 2 == 0:
				d.ellipse(0, 0, link * 0.62, link * 0.36, "none", stroke="#1c1d21", stroke_width=w + 1.6)
				d.ellipse(0, 0, link * 0.62, link * 0.36, "none", stroke=color, stroke_width=w)
				d.path("M%s %s Q%s %s %s %s" % F(-link * 0.45, -link * 0.2, 0, -link * 0.42, link * 0.45, -link * 0.2), "none", stroke=hi,
					stroke_width=w * 0.4, opacity=0.8)
			else:
				d.rect(-link * 0.62, -w * 0.62, link * 1.24, w * 1.24, "#1c1d21", rx=w * 0.6)
				d.rect(-link * 0.58, -w * 0.45, link * 1.16, w * 0.9, color, rx=w * 0.45)


def crest_plate(d, cx, cy, s=1.0):
	"""Small brass plaque with the Snapjaw crest."""
	d.rect(cx - 30 * s, cy - 30 * s, 60 * s, 60 * s, BRASS_D, rx=8 * s)
	d.rect(cx - 27 * s, cy - 27 * s, 54 * s, 54 * s, d.lin(cx - 27 * s, cy - 27 * s, cx + 27 * s, cy + 27 * s, [(0, BRASS_L), (1, BRASS)]), rx=6 * s)
	snapjaw_crest(d, cx, cy + 1 * s, 0.46 * s)


def mudlark_side(d, x0, base, s, rng, lit=True):
	"""Side elevation of the paddle-steamer Mudlark, bow to the left. x0 = bow tip, base = keel/mud line.
	Total length ~682*s (stern wheel included), height ~418*s (smokestack crowns)."""
	def X(u):
		return x0 + u * s

	def Y(v):
		return base - v * s

	def PP(seq):
		return [(X(u), Y(v)) for (u, v) in seq]

	def R(u0, v0, u1, v1, fill, **kw):
		d.rect(X(u0), Y(max(v0, v1)), (u1 - u0) * s, abs(v1 - v0) * s, fill, **kw)

	if lit:
		glow(d, X(300), Y(150), 430 * s, LANTERN, 0.2, ry=210 * s)
	# ---- twin smokestacks (behind the upper decks)
	for uc in (262, 310):
		R(uc - 13, 200, uc + 13, 394, d.lin(X(uc - 13), 0, X(uc + 13), 0, [(0, "#101115"), (0.32, STACK_L), (0.55, STACK), (1, "#0c0d10")]))
		for vb in (296, 370):
			R(uc - 14.5, vb, uc + 14.5, vb + 7, d.lin(X(uc - 14), 0, X(uc + 14), 0, [(0, BRASS_D), (0.35, BRASS_L), (1, BRASS_D)]))
		crown = [(uc - 13, 394), (uc - 22, 410), (uc - 21, 420), (uc - 15, 413), (uc - 9, 422), (uc - 4, 414), (uc + 1, 423), (uc + 6, 414),
			(uc + 11, 422), (uc + 16, 413), (uc + 21, 420), (uc + 22, 410), (uc + 13, 394)]
		d.poly(PP(crown), "#15161a", stroke=BRASS_D, stroke_width=1.6 * s, stroke_linejoin="round")
		R(uc - 16, 391, uc + 16, 397, BRASS)
	d.spath("M%s %s L%s %s" % F(X(262), Y(352), X(310), Y(352)), BRASS_D, 3.5 * s)
	d.spath("M%s %s Q%s %s %s %s" % F(X(262), Y(338), X(286), Y(326), X(310), Y(338)), BRASS_D, 2.5 * s)
	snapjaw_crest(d, X(286), Y(350), 0.2 * s)
	# smoke / steam drifting from the stacks
	g = d.brad([(0, "#c9d6d4", 0.3), (0.6, "#c9d6d4", 0.14), (1, "#c9d6d4", 0)])
	for uc in (262, 310):
		for k in range(6):
			t = k / 5
			d.ellipse(X(uc + 20 + t * 150), Y(430 + t * 70 + math.sin(t * 5) * 8), (20 + t * 48) * s, (14 + t * 26) * s, g)
	# ---- stern wheel supports (behind the wheel)
	d.poly(PP([(470, 146), (482, 156), (668, 92), (656, 82)]), WOOD_D)
	d.poly(PP([(470, 104), (480, 110), (660, 84), (650, 76)]), WOOD_DD)
	R(612, 80, 618, 182, WOOD_D)
	R(668, 80, 673, 182, WOOD_D)
	R(560, 176, 680, 184, HULL_D)
	R(560, 170, 680, 176, TEALP)
	# ---- hull
	hull = "M%s %s Q%s %s %s %s L%s %s L%s %s Q%s %s %s %s Z" % F(X(4), Y(94), X(280), Y(78), X(562), Y(88), X(562), Y(2), X(66), Y(0),
		X(22), Y(26), X(4), Y(94))
	cid = d.clip('<path d="%s"/>' % hull)
	d.path(hull, TEALP)
	with G(d, clip_path=cid):
		d.rect(X(-10), Y(100), 600 * s, 100 * s, d.vlin(Y(100), Y(0), [(0, TEALP_L), (0.3, TEALP), (1, TEALP_D)]))
		d.rect(X(-10), Y(100), 600 * s, 34 * s, d.vlin(Y(100), Y(66), [(0, HULL_L), (1, HULL)]))
		d.rect(X(-10), Y(67), 600 * s, 4 * s, BRASS)
		# grime streaks + rust runs
		dd = ""
		for _ in range(26):
			u = rng.uniform(10, 555)
			dd += "M%s %s l%s %s " % F(X(u), Y(rng.uniform(56, 92)), rng.uniform(-1, 1), rng.uniform(14, 40) * s)
		d.spath(dd, "#5a4e3a", 2.2 * s, opacity=0.35)
		# just-drained mud coat with drips
		mudtop = [(X(-10), Y(30))]
		u = -10
		while u < 580:
			u += rng.uniform(10, 26)
			mudtop.append((X(u), Y(rng.uniform(24, 32))))
			if rng.random() < 0.35:
				mudtop.append((X(u + 2), Y(rng.uniform(12, 18))))
				mudtop.append((X(u + 4), Y(rng.uniform(24, 30))))
		pth = "M" + " L".join("%s %s" % F(px, py) for px, py in mudtop) + " L%s %s L%s %s Z" % F(X(590), Y(-10), X(-10), Y(-10))
		d.path(pth, d.vlin(Y(36), Y(0), [(0, MUD_L), (1, MUD_D)]))
		d.path(pth, "none", stroke="#9a8064", stroke_width=1.4 * s, opacity=0.6)
		# portholes along the hull
		for k in range(9):
			u = 96 + k * 50
			d.circle(X(u), Y(44), 6.5 * s, BRASS_D)
			d.circle(X(u), Y(44), 4.5 * s, LANTERN if (lit and k % 3 != 1) else "#16313a")
	d.path(hull, "none", stroke="#16211f", stroke_width=2.2 * s)
	# name board on the bow (scribbles stand in for "MUDLARK")
	d.rect(X(36), Y(90), 82 * s, 16 * s, "#1d3b3a", rx=3 * s, stroke=BRASS, stroke_width=1.6 * s)
	glyphs(d, X(42), Y(87.5), 70 * s, 11 * s, 1, BRASS_L, rng, 1.4 * s)
	# ---- main deck: deck house, posts, rail
	R(0, 92, 562, 98, WOOD_D)
	R(70, 98, 500, 152, d.vlin(Y(152), Y(98), [(0, HULL_L), (1, HULL_D)]))
	R(70, 146, 500, 153, TEALP_D)
	for k in range(12):
		u = 86 + k * 34
		top = 140 if k % 4 != 2 else 146
		d.path("M%s %s L%s %s Q%s %s %s %s L%s %s Z" % F(X(u), Y(104), X(u), Y(top - 8), X(u + 9), Y(top + 4), X(u + 18), Y(top - 8),
			X(u + 18), Y(104)), d.vlin(Y(top), Y(104), [(0, LANTERN_HOT), (1, LANTERN)]) if lit else "#2b3a40")
		d.spath("M%s %s L%s %s" % F(X(u + 9), Y(104), X(u + 9), Y(top - 4)), TEALP_D, 1.4 * s)
	for k in range(15):
		u = 30 + k * 36
		R(u, 98, u + 3.4, 158, HULL_L)
	R(20, 116, 540, 119, HULL_L)
	dd = ""
	for k in range(90):
		u = 22 + k * 5.8
		dd += "M%s %s L%s %s " % F(X(u), Y(98), X(u), Y(116))
	d.spath(dd, HULL, 1.0 * s, opacity=0.9)
	# ---- promenade deck
	R(30, 152, 548, 162, TEALP)
	R(30, 152, 548, 154, TEALP_D)
	R(110, 162, 476, 210, d.vlin(Y(210), Y(162), [(0, HULL_L), (1, HULL_D)]))
	for k in range(10):
		u = 124 + k * 35
		R(u, 172, u + 20, 198, d.vlin(Y(198), Y(172), [(0, LANTERN_HOT), (1, LANTERN)]) if lit else "#2b3a40")
		R(u, 184, u + 20, 185.5, TEALP_D)
	for k in range(14):
		u = 34 + k * 39
		R(u, 162, u + 3, 212, HULL_L)
	R(30, 178, 548, 181, HULL_L)
	dd = ""
	for k in range(100):
		u = 32 + k * 5.15
		dd += "M%s %s L%s %s " % F(X(u), Y(162), X(u), Y(178))
	d.spath(dd, HULL, 0.9 * s, opacity=0.9)
	R(90, 210, 500, 218, TEALP)
	R(84, 216, 506, 219, TEALP_D)
	# big crest on the promenade deck house
	crest_plate(d, X(298), Y(186), 0.42 * s)
	# ---- pilot house (aft of the smokestacks)
	R(338, 218, 420, 262, d.vlin(Y(262), Y(218), [(0, HULL_L), (1, HULL_D)]))
	for k in range(3):
		R(344 + k * 25, 232, 364 + k * 25, 254, d.vlin(Y(254), Y(232), [(0, LANTERN_HOT), (1, LANTERN)]) if lit else "#2b3a40")
	R(332, 262, 426, 270, TEALP)
	d.path("M%s %s Q%s %s %s %s Z" % F(X(364), Y(270), X(379), Y(292), X(394), Y(270)), BRASS)
	d.line(X(379), Y(292), X(379), Y(326), "#2a2a2a", 1.8 * s)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(X(379), Y(326), X(414), Y(320), X(406), Y(312), X(379), Y(312)), SJ_MAROON)
	croc_cam(d, X(420), Y(248), 0.34 * s)
	# bell + jackstaff at the bow
	d.line(X(14), Y(94), X(14), Y(168), "#2a2a2a", 2 * s)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(X(14), Y(168), X(46), Y(161), X(40), Y(154), X(14), Y(152)), SJ_MAROON)
	d.path("M%s %s Q%s %s %s %s Z" % F(X(38), Y(106), X(46), Y(126), X(54), Y(106)), BRASS)
	R(44, 126, 48, 132, BRASS_D)
	# stern flagstaff
	d.line(X(676), Y(184), X(676), Y(250), "#2a2a2a", 2 * s)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(X(676), Y(250), X(714), Y(242), X(706), Y(234), X(676), Y(232)), SJ_MAROON)
	# ---- lantern strings along both decks
	if lit:
		for (v, u0, u1, n, sc) in ((150, 30, 548, 6, 0.42 * s), (208, 34, 548, 6, 0.4 * s)):
			step = (u1 - u0) / n
			for k in range(n):
				lantern_string(d, (X(u0 + k * step), Y(v)), (X(u0 + (k + 1) * step), Y(v)), 6 * s, 2, sc, start=k, glow_a=0.35)
	# ---- red stern paddle wheel
	wc = (X(622), Y(84))
	wr = 66 * s
	d.circle(wc[0], wc[1], wr * 1.02, "#000000", opacity=0.25)
	d.circle(wc[0], wc[1], wr * 0.98, "none", stroke=PRED_D, stroke_width=4 * s)
	dd = ""
	for k in range(12):
		a = k * TAU / 12 + 0.12
		dd += "M%s %s L%s %s " % F(wc[0], wc[1], wc[0] + math.cos(a) * wr * 0.95, wc[1] + math.sin(a) * wr * 0.95)
	d.spath(dd, PRED_D, 3.2 * s)
	for k in range(12):
		a = k * TAU / 12 + 0.12
		deg = math.degrees(a)
		with G(d, transform=T(wc[0] + math.cos(a) * wr * 0.8, wc[1] + math.sin(a) * wr * 0.8, 1, deg)):
			d.rect(-wr * 0.24, -4.6 * s, wr * 0.48, 9.2 * s, d.vlin(-4.6 * s, 4.6 * s, [(0, PRED_L), (1, PRED)]), stroke="#3a120e",
				stroke_width=1.2 * s)
	d.circle(wc[0], wc[1], wr * 0.6, "none", stroke=PRED, stroke_width=3.5 * s)
	d.circle(wc[0], wc[1], wr * 0.98, "none", stroke=PRED, stroke_width=2 * s)
	d.circle(wc[0], wc[1], 10 * s, BRASS, stroke=BRASS_D, stroke_width=2 * s)
	d.circle(wc[0] - 2 * s, wc[1] - 2 * s, 3 * s, BRASS_L)
	return {"bow": (X(0), Y(90)), "deck": (X(40), Y(96)), "stern": (X(682), Y(84)), "wheel": wc, "stacks": (X(262), X(310), Y(420))}


# --------------------------------------------------------------------------------------
# SHIP_DOCK - the drained Lower Lake
# --------------------------------------------------------------------------------------

def cave_ceiling(d, rng, y_edge=70, color="#060c0f", tip="#183338", count=26, fungus_n=7, avoid=None):
	pts_ = [(-20, y_edge)]
	x = -20
	while x < W + 20:
		x += rng.uniform(40, 90)
		pts_.append((x, y_edge + rng.uniform(-30, 26)))
	d.path(hang(pts_, -10), color)
	for _ in range(count):
		x = rng.uniform(0, W)
		if avoid and avoid[0] < x < avoid[1]:
			h = rng.uniform(20, 44)
		else:
			h = rng.uniform(40, 150)
		stalactites(d, rng, x, x + 1, y_edge - 26, h * 0.9, h, tip, 1, rim="#3d7a7a")
	for _ in range(fungus_n):
		x = rng.uniform(40, W - 40)
		if avoid and avoid[0] - 40 < x < avoid[1] + 40:
			continue
		glowworms(d, x, y_edge + rng.uniform(-18, 6), rng.uniform(0.7, 1.1), rng, n=rng.randint(4, 7))


def bg_ship_dock(d):
	rng = random.Random(201)
	d.rect(0, 0, W, H, d.vlin(0, H, [(0, "#03080b"), (0.32, "#0a1a1f"), (0.58, "#12282d"), (1, "#0b1416")]))
	glow(d, 650, 300, 720, "#2a9a92", 0.26, ry=230)
	# far cave wall with the old lake level (tide line)
	far = [(0, 236), (90, 200), (210, 224), (330, 176), (460, 206), (560, 170), (690, 196), (800, 164), (930, 198), (1040, 172), (1160, 214), (1280, 190)]
	d.path(ridge(far, 470), d.vlin(160, 470, [(0, "#16343a"), (0.5, "#12292e"), (1, "#0c1a1d")]))
	far2 = [(0, 290), (120, 262), (260, 284), (400, 252), (520, 276), (660, 248), (790, 270), (920, 246), (1060, 272), (1180, 252), (1280, 268)]
	d.path(ridge(far2, 470), d.vlin(250, 470, [(0, "#1a3a40"), (1, "#0e1e21")]), opacity=0.9)
	# old waterline: everything below 318 was underwater until this morning
	d.rect(0, 318, W, 160, d.vlin(318, 470, [(0, "#0a1a1d"), (1, "#081215")]), opacity=0.85)
	d.spath("M0 318 Q320 312 640 318 T1280 316", "#b9d8cf", 3, opacity=0.5)
	d.spath("M0 324 Q320 318 640 324 T1280 322", "#6c9a94", 2, opacity=0.35)
	dd = ""
	for _ in range(70):
		x = rng.uniform(0, W)
		dd += "M%s 322 l%s %s " % F(x, rng.uniform(-1, 1), rng.uniform(8, 40))
	d.spath(dd, "#0a1416", 2.2, opacity=0.6)
	for _ in range(18):
		x = rng.uniform(30, W - 30)
		y = rng.uniform(196, 306)
		glow_patch(d, x, y, rng.uniform(0.5, 0.9), rng, n=rng.randint(5, 9), a=0.8)
	# side rock masses framing the cave
	left = [(-10, 120), (60, 150), (120, 230), (150, 330), (176, 420), (190, 470)]
	d.path(smooth(left, closed=False) + " L-10 470 Z", d.lin(0, 0, 200, 0, [(0, "#040a0c"), (1, "#0f2226")]))
	d.spath(smooth(left, closed=False), "#3d8a86", 2.5, opacity=0.4)
	right = [(1290, 110), (1220, 150), (1170, 230), (1140, 320), (1118, 420), (1106, 470)]
	d.path(smooth(right, closed=False) + " L1290 470 Z", d.lin(W, 0, 1100, 0, [(0, "#040a0c"), (1, "#0f2226")]))
	d.spath(smooth(right, closed=False), "#3d8a86", 2.5, opacity=0.4)
	for (x, y, s_) in [(70, 240, 1.2), (134, 336, 0.95), (1206, 232, 1.2), (1156, 348, 1.0), (40, 404, 0.8), (1244, 414, 0.8)]:
		fungus(d, x, y, s_, rng, n=5)
	# ceiling + stalactites (short ones over the smokestacks)
	cave_ceiling(d, rng, 64, count=30, fungus_n=8, avoid=(520, 690))
	# Snapjaw banners hanging from the ceiling
	for bx in (150, 1130):
		d.line(bx - 50, 20, bx - 40, 70, "#2a2d33", 2)
		d.line(bx + 50, 20, bx + 40, 70, "#2a2d33", 2)
		sj_banner(d, bx, 74, 96, 210)
		glow(d, bx, 150, 120, RED_EYE, 0.08)
	# --- mud flats (far part, behind the ship)
	d.path(ridge([(0, 452), (180, 444), (420, 450), (700, 442), (960, 448), (1280, 440)], 480), d.vlin(440, 480, [(0, "#1e211f"), (1, "#2b261f")]))
	# --- the Mudlark
	info = mudlark_side(d, 352, 474, 0.86, rng)
	# mud piled around the hull + puddles reflecting the lights
	d.path(ridge([(300, 476), (380, 462), (520, 468), (700, 460), (860, 466), (960, 458), (1010, 474)], 520), d.vlin(456, 520, [(0, "#423a2e"), (1, "#28261f")]))
	# --- foreground mud
	fg = [(0, 482), (200, 476), (420, 484), (640, 476), (880, 486), (1100, 478), (1280, 486)]
	d.path(ridge(fg, H), d.vlin(476, H, [(0, "#23231e"), (0.45, "#2c2a23"), (1, "#363128")]))
	dd = ""
	for k in range(26):
		y = 492 + k * 9 + rng.uniform(-3, 3)
		x = rng.uniform(-100, W)
		dd += "M%s %s q%s %s %s 0 " % F(x, y, rng.uniform(60, 160), rng.uniform(-6, 6), rng.uniform(140, 380))
	d.spath(dd, "#5a7a72", 1.8, opacity=0.35)
	# reflections of the ship lights + fungus glow in the wet mud
	for (x, y, rx_, c, a) in [(560, 500, 260, LANTERN, 0.22), (820, 498, 160, LANTERN, 0.18), (120, 520, 140, "#5fe0d0", 0.18), (1180, 520, 140, "#5fe0d0", 0.16)]:
		floor_reflect(d, x, y, rx_, 22, c, a)
	for (x, y, rx_, ry_) in [(250, 560, 70, 12), (1060, 548, 90, 14), (1170, 640, 80, 12), (900, 690, 60, 9), (140, 680, 70, 10)]:
		d.ellipse(x, y, rx_, ry_, d.vlin(y - ry_, y + ry_, [(0, "#2d5a58"), (1, "#173235")]))
		d.ellipse(x - rx_ * 0.2, y - ry_ * 0.2, rx_ * 0.5, ry_ * 0.25, "#9ef0e4", opacity=0.3)
	# --- the plug hole: whirl-scar spiral grooves converging on a whale-sized sinkhole
	hx_, hy_ = 690, 612
	d.ellipse(hx_, hy_ + 6, 290, 92, d.rad(hx_, hy_ + 6, 290, [(0, "#1b140e", 0.7), (0.6, "#2a2018", 0.45), (1, "#2a2018", 0)]))
	for k in range(7):
		a0 = k * TAU / 7 + 0.3
		pts_ = []
		pts2 = []
		for j in range(28):
			t = j / 27
			a = a0 + t * 3.4
			rr = 1.0 - t * 0.72
			pts_.append((hx_ + math.cos(a) * 270 * rr, hy_ + math.sin(a) * 84 * rr))
			pts2.append((hx_ + math.cos(a - 0.06) * 270 * rr, hy_ + math.sin(a - 0.06) * 84 * rr - 2.5))
		d.spath(smooth(pts_, False), "#1d1510", 7, opacity=0.8)
		d.spath(smooth(pts2, False), "#8a7054", 2.2, opacity=0.55)
	d.ellipse(hx_, hy_ + 5, 124, 40, "#140e0a")
	d.ellipse(hx_, hy_, 116, 35, d.rad(hx_, hy_ + 14, 120, [(0, "#000000"), (0.75, "#050403"), (1, "#20170f")]))
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(hx_ - 112, hy_ - 4, hx_, hy_ - 44, hx_ + 112, hy_ - 4, hx_, hy_ - 18, hx_ - 112, hy_ - 4), "#3a2c20")
	d.spath("M%s %s Q%s %s %s %s" % F(hx_ - 112, hy_ + 2, hx_, hy_ + 46, hx_ + 112, hy_ + 2), "#8a7054", 3, opacity=0.7)
	glow(d, hx_, hy_ + 6, 60, "#2fb8a8", 0.25, ry=14)
	# drops of water still trickling in
	for k in range(5):
		x = hx_ - 80 + k * 40
		d.spath("M%s %s q2 8 0 16" % F(x, hy_ - 14 + abs(k - 2) * 3), "#9ef0e4", 1.6, opacity=0.5)
	# the giant plug, pulled out and lying in the mud, chain trailing back to the jetty
	chain(d, [(470, 588), (432, 584), (404, 566), (396, 540)], link=14, w=4.5)
	with G(d, transform=T(500, 614, 1, -8)):
		d.ellipse(6, 22, 66, 12, "#000000", opacity=0.4)
		d.path("M-58 -4 L-50 18 Q0 34 50 18 L58 -4 Z", d.lin(-58, 0, 58, 0, [(0, "#121317"), (0.35, "#3a3d45"), (1, "#101114")]), stroke=INK,
			stroke_width=2.2)
		d.ellipse(0, -4, 58, 17, d.rad(-14, -10, 60, [(0, "#4c505a"), (0.6, "#2a2c32"), (1, "#18191d")]), stroke=INK, stroke_width=2.2)
		d.ellipse(-12, -9, 26, 6, "#ffffff", opacity=0.12)
		d.ellipse(0, -6, 11, 5, BRASS_D, stroke=INK, stroke_width=1.6)
		d.ellipse(-16, -12, 18, 10, "none", stroke="#1a1b1f", stroke_width=6.5)
		d.ellipse(-16, -12, 18, 10, "none", stroke=BRASS, stroke_width=4)
		d.path("M-30 -16 Q-22 -24 -8 -21", "none", stroke=BRASS_L, stroke_width=1.6, opacity=0.9)
	# --- stone jetty on the left, the Mudlark's bow moored at its end
	top = [(0, 432), (382, 452), (412, 490), (0, 520)]
	d.poly(top, d.lin(0, 430, 0, 520, [(0, "#575c60"), (1, "#3e4246")]))
	glow(d, 330, 470, 150, LANTERN, 0.16, ry=34)
	dd = ""
	for (x0, y0, x1, y1) in ((40, 470, 92, 486), (150, 462, 186, 478), (236, 488, 290, 470), (96, 500, 132, 492)):
		dd += "M%s %s L%s %s l8 6 " % F(x0, y0, x1, y1)
	d.spath(dd, "#2a2d30", 1.6, opacity=0.6)
	for (x, y, rx_) in ((120, 488, 46), (290, 466, 30)):
		d.ellipse(x, y, rx_, rx_ * 0.18, "#7fb8b0", opacity=0.18)
	front = [(0, 520), (412, 490), (412, 556), (0, 640)]
	d.poly(front, d.vlin(490, 640, [(0, "#3f4245"), (1, "#25272a")]))
	d.poly([(382, 452), (412, 490), (412, 556), (386, 516)], "#2c2e31")
	d.poly([(0, 520), (412, 490), (412, 502), (0, 536)], "#b9d8cf", opacity=0.35)
	d.poly([(0, 536), (412, 502), (412, 556), (0, 640)], "#22403a", opacity=0.45)
	dd = ""
	for k in range(22):
		x = 8 + k * 18.5
		y0 = 536 - (536 - 502) * x / 412
		dd += "M%s %s q2 %s 0 %s " % F(x, y0, rng.uniform(8, 16), rng.uniform(16, 40))
	d.spath(dd, "#3a5a40", 3, opacity=0.5)
	dd = ""
	for k in range(1, 9):
		x = k * 50
		y0 = 520 - (520 - 490) * x / 412
		y1 = 640 - (640 - 556) * x / 412
		dd += "M%s %s L%s %s " % F(x, y0, x + 4, y1)
	for t in (0.45,):
		dd += "M0 %s L412 %s " % F(520 + (640 - 520) * t, 490 + (556 - 490) * t)
	d.spath(dd, "#1a1c1e", 2, opacity=0.6, stroke_linecap="butt")
	dd = ""
	for k in range(1, 7):
		x = k * 62
		dd += "M%s %s L%s %s " % F(x, 432 + 20 * x / 382, x - 10, 520 - 30 * x / 412)
	d.spath(dd, "#45494d", 1.8, opacity=0.55, stroke_linecap="butt")
	# bollards + mooring ropes
	for bx_, by_ in [(330, 474), (376, 476)]:
		d.ellipse(bx_, by_ + 6, 14, 5, "#000000", opacity=0.35)
		d.rect(bx_ - 9, by_ - 20, 18, 26, d.lin(bx_ - 9, 0, bx_ + 9, 0, [(0, IRON_L), (1, IRON_D)]), rx=5)
		d.ellipse(bx_, by_ - 21, 12, 5, IRON_L)
	bow = info["bow"]
	d.spath("M%s %s Q%s %s %s %s" % F(330, 458, 345, 452, bow[0] + 8, bow[1] + 6), "#cdbb94", 3)
	d.spath("M%s %s Q%s %s %s %s" % F(376, 460, 380, 440, bow[0] + 22, bow[1] + 4), "#cdbb94", 3)
	# gangway from the jetty up to the bow deck
	dk = info["deck"]
	d.poly([(262, 470), (300, 474), (dk[0] + 16, dk[1] + 2), (dk[0] - 8, dk[1] - 2)], d.lin(262, 470, dk[0], dk[1], [(0, WOOD), (1, WOOD_L)]))
	dd = ""
	for k in range(1, 9):
		t = k / 9
		xa = 262 + (dk[0] - 8 - 262) * t
		ya = 470 + (dk[1] - 2 - 470) * t
		xb = 300 + (dk[0] + 16 - 300) * t
		yb = 474 + (dk[1] + 2 - 474) * t
		dd += "M%s %s L%s %s " % F(xa, ya, xb, yb)
	d.spath(dd, WOOD_D, 1.6)
	d.spath("M%s %s L%s %s M%s %s L%s %s" % F(262, 450, dk[0] - 8, dk[1] - 22, 300, 454, dk[0] + 16, dk[1] - 18), "#cdbb94", 1.8)
	for (x, y) in [(262, 470), (300, 474)]:
		d.line(x, y, x, y - 22, WOOD_D, 3)
	# dock lamp at the jetty end
	d.line(400, 478, 400, 352, IRON_D, 4)
	d.spath("M400 360 Q414 344 428 352", IRON_D, 3)
	ship_lamp(d, 428, 378, 0.62, glow_a=0.55)
	croc_cam(d, 397, 392, 0.5, flip=True)
	# --- steam rising off the warm mud
	steam_wisps(d, rng, 430, 474, 980, 500, 9, a=0.07, color="#dff4f0")
	steam_wisps(d, rng, 600, 600, 800, 620, 4, a=0.06, color="#dff4f0")
	steam(d, rng, 300, 440, 1050, 480, 6, a=0.04, rmin=40, rmax=90, color="#dff4f0")
	# cave light + vignette
	light_wash(d, "#5fe0d0", 0.06, 0, 300)
	vignette(d, 0.55, "#020608")
	return info


# --------------------------------------------------------------------------------------
# SHIP_DECK - promenade deck at night
# --------------------------------------------------------------------------------------

def floor_circle(pp, xc, yb, sc, r, n=28, z0=18.0):
	"""Circle of radius r (back-plane units) lying at height yb, centred at back-plane x xc and depth scale sc.
	Returns projected points (true perspective). z0 = distance of the back plane in 'radius units' scale."""
	zc = z0 / sc
	out = []
	for i in range(n):
		a = i / n * TAU
		x = xc + math.cos(a) * r
		z = zc + math.sin(a) * r / 50.0
		out.append(pp.P(x, yb, z0 / z))
	return out


def cave_backdrop(d, rng, y0=0, y1=H, haze=(640, 300)):
	d.rect(0, y0, W, y1 - y0, d.vlin(y0, y1, [(0, "#03080b"), (0.45, "#0b1c21"), (1, "#102428")]))
	glow(d, haze[0], haze[1], 620, "#2a9a92", 0.22, ry=220)


def bg_ship_deck(d):
	rng = random.Random(301)
	pp = Persp(470, 290)
	P = pp.P
	WX, RX, FY, EY, RT = 390, 610, 360, 262, 310
	# --- cave beyond the rail
	cave_backdrop(d, rng, haze=(900, 260))
	far = [(380, 250), (520, 214), (660, 236), (800, 196), (940, 228), (1080, 200), (1200, 232), (1290, 214)]
	d.path(ridge(far, 420), d.vlin(190, 420, [(0, "#163339"), (1, "#0d1c20")]))
	d.spath("M380 300 Q800 292 1290 300", "#b9d8cf", 2.5, opacity=0.35)
	for _ in range(12):
		glow_patch(d, rng.uniform(420, 1260), rng.uniform(210, 290), rng.uniform(0.5, 0.9), rng, n=rng.randint(5, 8), a=0.8)
	# far jetty lamps + the dock far away
	for (x, y) in [(560, 318), (640, 320), (1010, 314)]:
		glow(d, x, y, 34, LANTERN, 0.5)
		d.circle(x, y, 2.5, LANTERN_HOT)
	cave_ceiling(d, rng, 46, count=28, fungus_n=6)
	# --- smokestacks on the deck-house roof (twin, side by side)
	for (xb, sc) in ((372, 1.55), (306, 1.55)):
		bx, by = P(xb, EY, sc)
		w2 = 16 * sc
		d.rect(bx - w2, -10, w2 * 2, by + 10, d.lin(bx - w2, 0, bx + w2, 0, [(0, "#0e0f12"), (0.3, STACK_L), (0.55, STACK), (0.85, "#15161a"), (1, "#3d7a7a")]))
		d.rect(bx + w2 - 3, -10, 3, by + 10, "#7fd8cf", opacity=0.45)
		for yy in (by - 120 * sc, by - 40 * sc):
			d.rect(bx - w2 - 2, yy, w2 * 2 + 4, 9 * sc, d.lin(bx - w2, 0, bx + w2, 0, [(0, BRASS_D), (0.35, BRASS_L), (1, BRASS_D)]))
		glow(d, bx, by - 60 * sc, 50 * sc, LANTERN, 0.18)
	g = d.brad([(0, "#c9d6d4", 0.12), (1, "#c9d6d4", 0)])
	for k in range(5):
		d.ellipse(250 + k * 70, 20 + k * 4, 70, 30, g)
	# --- deck-house wall (left)
	d.poly([P(WX, EY), P(WX, FY), P(WX, FY, FAR), P(WX, EY, FAR)], d.lin(0, 0, 380, 0, [(0, "#8d8574"), (1, HULL)]))
	side_band(d, pp, WX, FY - 38, FY, d.lin(0, 0, 380, 0, [(0, TEALP_D), (1, TEALP)]))
	side_line(d, pp, WX, FY - 38, BRASS_D, 3)
	side_band(d, pp, WX, EY - 12, EY + 4, d.lin(0, 0, 380, 0, [(0, TEALP_D), (1, TEALP)]))
	side_line(d, pp, WX, EY + 5, "#5e5646", 2, opacity=0.6)
	# windows / door along the wall
	for (s0, s1, kind) in ((1.12, 1.3, "win"), (1.4, 1.62, "win"), (1.75, 2.15, "door"), (2.35, 2.75, "win"), (3.15, 3.7, "win")):
		if kind == "win":
			q = [P(WX, 278, s0), P(WX, 278, s1), P(WX, 314, s1), P(WX, 314, s0)]
			d.poly([P(WX, 274, s0 - 0.03), P(WX, 274, s1 + 0.03), P(WX, 318, s1 + 0.03), P(WX, 318, s0 - 0.03)], TEALP_D)
			d.poly(q, d.lin(q[0][0], 0, q[1][0], 0, [(0, LANTERN_HOT), (1, LANTERN)]))
			m0, m1 = P(WX, 278, (s0 + s1) / 2), P(WX, 314, (s0 + s1) / 2)
			d.spath("M%s %s L%s %s" % F(m0[0], m0[1], m1[0], m1[1]), TEALP_D, 2.2 * s0)
			fl = [P(WX + 2, FY, s0), P(WX + 2, FY, s1), P(WX + 60, FY, s1 + 0.3), P(WX + 60, FY, s0 + 0.2)]
			d.poly(fl, LANTERN, opacity=0.12)
		else:
			q = [P(WX, 270, s0), P(WX, 270, s1), P(WX, FY, s1), P(WX, FY, s0)]
			d.poly([P(WX, 267, s0 - 0.04), P(WX, 267, s1 + 0.04), P(WX, FY, s1 + 0.04), P(WX, FY, s0 - 0.04)], TEALP_D)
			d.poly(q, d.lin(q[0][0], 0, q[1][0], 0, [(0, "#6e4426"), (1, WOOD)]))
			c0 = P(WX, 284, (s0 + s1) / 2)
			porthole(d, c0[0], c0[1] + 4, 9 * s0, rng, view="glow", sx=0.45)
			k0 = P(WX, 318, s1 - 0.06)
			d.circle(k0[0], k0[1], 3 * s0, BRASS_L)
	lb = P(WX, 300, 2.95)
	lifebuoy(d, lb[0], lb[1], 22 * 2.95 * 0.42, sx=0.42)
	cp = P(WX, 290, 2.27)
	crest_plate(d, cp[0], cp[1], 0.5)
	cc = P(WX, EY + 10, 1.33)
	croc_cam(d, cc[0], cc[1], 0.55)
	# --- deck floor
	d.poly([P(WX, FY), P(RX, FY), P(RX, FY, FAR), P(WX, FY, FAR)], d.vlin(FY, H, [(0, "#5a3a24"), (0.5, "#7a5030"), (1, "#5e3c24")]))
	pplanks(d, pp, WX, RX, FY, 14, "#2e1c10", a=0.55, rng=rng)
	for (x, y, rx_, a) in [(330, 420, 140, 0.22), (560, 470, 190, 0.2), (220, 560, 160, 0.18)]:
		floor_reflect(d, x, y, rx_, rx_ * 0.18, LANTERN, a)
	glow(d, 860, 600, 260, "#5fe0d0", 0.06, ry=80)
	# --- far end: bow rail across the deck
	q = [P(WX, RT), P(RX, RT), P(RX, FY), P(WX, FY)]
	dd = ""
	for k in range(23):
		x = WX + (RX - WX) * k / 22
		a0, a1 = P(x, RT, 1), P(x, FY, 1)
		dd += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
	d.spath(dd, HULL, 1.4)
	d.spath("M%s %s L%s %s" % F(q[0][0], q[0][1], q[1][0], q[1][1]), TEALP, 3.5)
	# --- the rail / bulwark on the right
	d.poly([P(RX, RT), P(RX, RT, FAR), P(RX, FY, FAR), P(RX, FY)], d.lin(600, 0, 1280, 0, [(0, HULL_D), (0.5, "#cfc5ae"), (1, HULL)]))
	side_band(d, pp, RX, FY - 14, FY, d.lin(600, 0, 1280, 0, [(0, TEALP_D), (1, TEALP)]))
	side_band(d, pp, RX, RT, RT + 6, d.lin(600, 0, 1280, 0, [(0, TEALP), (1, TEALP_L)]))
	side_line(d, pp, RX, RT, "#f6f0e2", 3)
	# balusters on the far part only; near part stays a calm solid panel
	dd = ""
	s_ = 1.0
	while s_ < 3.1:
		a0, a1 = P(RX, RT + 6, s_), P(RX, FY - 14, s_)
		dd += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
		s_ *= 1.045
	d.spath(dd, "#8a8270", 1.6, opacity=0.7)
	for sc in (1.3, 1.8, 2.5, 3.6, 5.2):
		a0, a1 = P(RX, RT - 2, sc), P(RX, FY, sc)
		d.spath("M%s %s L%s %s" % F(a0[0], a0[1], a1[0], a1[1]), "#e8e0cc" if sc < 3 else "#b9b09a", (4 if sc < 3 else 2.4) * sc, opacity=1 if sc < 3 else 0.7)
	for sc in (2.05, 3.0):
		c = P(RX, 334, sc)
		lifebuoy(d, c[0], c[1], 22 * sc * 0.42, sx=0.42)
	# lantern poles at the rail
	poles = []
	for sc in (1.6, 2.4, 3.6):
		a0, a1 = P(RX, RT, sc), P(RX, 190, sc)
		d.spath("M%s %s L%s %s" % F(a0[0], a0[1], a1[0], a1[1]), "#2a1d14", 3.2 * sc)
		poles.append((sc, a1))
	# --- little wooden onsen tub on the deck
	xc, sc, r = 500, 2.25, 40
	top = floor_circle(pp, xc, FY - 38, sc, r)
	bot = floor_circle(pp, xc, FY, sc, r)
	left_i = min(range(len(top)), key=lambda i: top[i][0])
	right_i = max(range(len(top)), key=lambda i: top[i][0])
	lt, rt_ = top[left_i], top[right_i]
	lb_, rb_ = bot[left_i], bot[right_i]
	front_bot = max(bot, key=lambda p_: p_[1])
	d.ellipse((lb_[0] + rb_[0]) / 2, front_bot[1] + 2, (rb_[0] - lb_[0]) * 0.62, 12, "#000000", opacity=0.35)
	side = "M%s %s L%s %s Q%s %s %s %s L%s %s Z" % F(lt[0], lt[1], lb_[0], lb_[1], (lb_[0] + rb_[0]) / 2, front_bot[1] + (front_bot[1] - lb_[1]),
		rb_[0], rb_[1], rt_[0], rt_[1])
	d.path(side, d.lin(lt[0], 0, rt_[0], 0, [(0, "#6e4426"), (0.4, WOOD_L), (1, "#5a3720")]))
	cid = d.clip('<path d="%s"/>' % side)
	with G(d, clip_path=cid):
		dd = ""
		for k in range(1, 12):
			x = lt[0] + (rt_[0] - lt[0]) * k / 12
			dd += "M%s %s L%s %s " % F(x, lt[1] - 20, x, front_bot[1] + 30)
		d.spath(dd, "#4a2c18", 1.4, opacity=0.6)
		for frac in (0.3, 0.78):
			yy = lt[1] + (lb_[1] - lt[1]) * frac
			d.spath("M%s %s Q%s %s %s %s" % F(lt[0] - 4, yy, (lt[0] + rt_[0]) / 2, yy + (front_bot[1] - lb_[1]) * 1.6 + 10, rt_[0] + 4, yy), "#2b2622", 6)
	d.path(smooth(top), d.vlin(min(p_[1] for p_ in top), max(p_[1] for p_ in top), [(0, "#3a2414"), (1, "#5a3a22")]))
	inner = floor_circle(pp, xc, FY - 36, sc, r - 5)
	d.path(smooth(inner), d.lin(lt[0], 0, rt_[0], 0, [(0, "#2a8f8a"), (0.5, "#6fe3dc"), (1, "#2a8f8a")]))
	icx = sum(p_[0] for p_ in inner) / len(inner)
	icy = sum(p_[1] for p_ in inner) / len(inner)
	d.ellipse(icx - 20, icy - 2, 40, 5, "#ffffff", opacity=0.3)
	B.yuzu(d, icx + 34, icy + 1, 9, 20, water=True)
	B.yuzu(d, icx - 46, icy + 3, 8, -30, water=True)
	steam_wisps(d, rng, lt[0] + 20, icy - 4, rt_[0] - 20, icy + 4, 6, a=0.13)
	wooden_bucket(d, rt_[0] + 46, front_bot[1] - 4, 44, 32)
	d.rect(lt[0] - 70, front_bot[1] - 30, 58, 10, WOOD_L, rx=3)
	d.rect(lt[0] - 64, front_bot[1] - 20, 8, 22, WOOD_D)
	d.rect(lt[0] - 26, front_bot[1] - 20, 8, 22, WOOD_D)
	# --- strings of paper lanterns: deck-house eave -> poles on the rail
	for (sc, ptop) in poles:
		e = P(WX, EY, sc)
		lantern_string(d, (e[0], e[1] + 4), ptop, 22 * sc, 5 + int(sc), 0.42 * sc, start=int(sc * 3), glow_a=0.42)
	light_wash(d, "#ffcf8a", 0.08, 0, 300)
	vignette(d, 0.5, "#03070a")


# --------------------------------------------------------------------------------------
# shared interior pieces
# --------------------------------------------------------------------------------------

def wood_panels(d, x0, y0, x1, y1, color, step=46, line=None, a=0.55):
	d.rect(x0, y0, x1 - x0, y1 - y0, d.vlin(y0, y1, [(0, light(color, 0.06)), (1, dark(color, 0.12))]))
	dd = ""
	x = x0
	while x < x1 - 4:
		x += step
		dd += "M%s %s L%s %s " % F(x, y0, x, y1)
	d.spath(dd, line or dark(color, 0.35), 1.6, opacity=a, stroke_linecap="butt")


def wainscot(d, x0, y0, x1, y1, color=TEALP, rail=BRASS_D, panels=True, grime=True):
	d.rect(x0, y0, x1 - x0, y1 - y0, d.vlin(y0, y1, [(0, color), (1, dark(color, 0.3))]))
	if panels:
		w = 92
		x = x0 + 10
		while x + w < x1:
			d.rect(x, y0 + 12, w - 14, y1 - y0 - 24, "none", stroke=dark(color, 0.35), stroke_width=2, opacity=0.6)
			d.rect(x + 2, y0 + 14, w - 18, 3, light(color, 0.25), opacity=0.4)
			x += w
	if grime:
		d.rect(x0, y1 - 26, x1 - x0, 26, d.vlin(y1 - 26, y1, [(0, "#000000", 0), (1, "#2a2016", 0.45)]))
	d.rect(x0, y0 - 4, x1 - x0, 7, d.vlin(y0 - 4, y0 + 3, [(0, BRASS_L), (1, rail)]))


def pchair(d, pp, xb, sc, side, color="#7a2a36", wood=WOOD_D, floor=430, seat=372, back=292, depth=0.1):
	"""Dining chair seen in perspective, its back on the outer side (side=-1 left of a table, 1 right)."""
	P = pp.P
	xo = xb + side * 24
	xi = xb - side * 22
	s0, s1 = sc - depth, sc + depth
	for (xx, ss) in ((xo, s0 + 0.01), (xi, s0 + 0.01), (xi, s1 - 0.01), (xo, s1 - 0.01)):
		a0, a1 = P(xx, seat, ss), P(xx, floor, ss)
		d.spath("M%s %s L%s %s" % F(a0[0], a0[1], a1[0], a1[1]), dark(wood, 0.2), 4.5 * ss, stroke_linecap="butt")
	# seat cushion (top + front edge)
	d.poly([P(xo, seat, s0), P(xi, seat, s0), P(xi, seat, s1), P(xo, seat, s1)], dark(color, 0.35))
	d.poly([P(xo, seat - 9, s0), P(xi, seat - 9, s0), P(xi, seat - 9, s1), P(xo, seat - 9, s1)], d.lin(P(xo, 0, sc)[0], 0, P(xi, 0, sc)[0], 0,
		[(0, dark(color, 0.1)), (1, light(color, 0.15))]))
	d.poly([P(xi, seat - 9, s0), P(xi, seat - 9, s1), P(xi, seat, s1), P(xi, seat, s0)], dark(color, 0.25))
	# backrest: wooden frame + upholstered panel
	fr = [P(xo, back, s0), P(xo, back, s1), P(xo, seat - 6, s1), P(xo, seat - 6, s0)]
	d.poly(fr, wood)
	d.poly([P(xo, back + 9, s0 + 0.025), P(xo, back + 9, s1 - 0.025), P(xo, seat - 16, s1 - 0.025), P(xo, seat - 16, s0 + 0.025)],
		d.vlin(P(xo, back, sc)[1], P(xo, seat, sc)[1], [(0, light(color, 0.12)), (1, dark(color, 0.2))]))
	t0, t1 = P(xo, back, s0), P(xo, back, s1)
	d.spath("M%s %s L%s %s" % F(t0[0], t0[1], t1[0], t1[1]), BRASS, 2.6 * sc)
	for ss in (s0, s1):
		a0, a1 = P(xo, back - 4, ss), P(xo, back + 2, ss)
		d.circle(a0[0], a0[1] + 3 * sc, 2.4 * sc, BRASS_L)


def side_porthole(d, pp, bx, yb, sc, r, rng, view="cave"):
	c = pp.P(bx, yb, sc)
	porthole(d, c[0], c[1], r * sc, rng, view=view, sx=min(0.78, 0.2 * sc + 0.08))


# --------------------------------------------------------------------------------------
# SHIP_SALOON - dining saloon
# --------------------------------------------------------------------------------------

def bg_ship_saloon(d):
	rng = random.Random(401)
	pp = Persp(640, 262)
	P = pp.P
	bx0, by0, bx1, by1 = 330, 96, 950, 430
	pshell(d, pp, bx0, by0, bx1, by1, "#a8683e", "#7a4626", "#8a5232", "#3a2414", "#6a4026", "#3e2414")
	# ceiling coffers + beams
	pbeams(d, pp, bx0, bx1, by0, (1.0, 1.35, 1.8, 2.5, 3.6), "#24150c", 10)
	for xb in (430, 640, 850):
		a0, a1 = P(xb, by0, 1), P(xb, by0, FAR)
		d.spath("M%s %s L%s %s" % F(a0[0], a0[1], a1[0], a1[1]), "#24150c", 6)
	for (s0, s1) in ((1.0, 1.35), (1.35, 1.8), (1.8, 2.5)):
		for (xa, xb) in ((430, 640), (640, 850)):
			q = [P(xa + 8, by0, s0 + 0.03), P(xb - 8, by0, s0 + 0.03), P(xb - 8, by0, s1 - 0.03), P(xa + 8, by0, s1 - 0.03)]
			d.poly(q, TEALP_D, opacity=0.7)
	# side walls: wood above, teal wainscot below, portholes + sconces
	for bx in (bx0, bx1):
		side_band(d, pp, bx, 318, by1, d.lin(0 if bx == bx0 else W, 0, bx, 0, [(0, dark(TEALP_D, 0.3)), (1, TEALP)]))
		side_line(d, pp, bx, 318, BRASS, 4)
		side_line(d, pp, bx, by0 + 16, "#24150c", 6)
		for sc in (1.18, 1.55, 2.15, 3.3):
			side_porthole(d, pp, bx, 214, sc, 26, rng)
		for sc in (1.36, 1.83, 2.65):
			c = P(bx, 196, sc)
			wall_lamp(d, c[0] + (14 if bx == bx0 else -14) * sc * 0.5, c[1], 0.42 * sc, side=-1 if bx == bx0 else 1, glow_a=0.42)
	# back wall: panelling + wainscot + galley doors + crest + piano + sideboard
	wood_panels(d, bx0, by0, bx1, 318, "#9c6038", step=62)
	wainscot(d, bx0, 318, bx1, by1)
	d.rect(bx0, by0, bx1 - bx0, 14, "#24150c")
	# galley double doors with portholes
	d.rect(572, 196, 136, 234, "#2a170c")
	for (x0, k) in ((578, 0), (642, 1)):
		d.rect(x0, 202, 60, 228, d.vlin(202, 430, [(0, WOOD_L), (1, WOOD)]))
		d.rect(x0 + 8, 300, 44, 110, "none", stroke=WOOD_D, stroke_width=2.4)
		porthole(d, x0 + 30, 244, 18, rng, view="glow")
		d.rect(x0 + (52 if k == 0 else 2), 312, 6, 34, BRASS, rx=2)
	glow(d, 640, 250, 70, LANTERN, 0.25)
	crest_plate(d, 640, 150, 0.9)
	glow(d, 640, 150, 90, RED_EYE, 0.08)
	croc_cam(d, bx1 - 20, by0 + 34, 0.62, flip=True)
	# sideboard + mirror (back left)
	d.rect(352, 150, 150, 120, "#3a2414", rx=6)
	d.rect(360, 158, 134, 104, d.lin(360, 158, 494, 262, [(0, "#d4e4e2"), (0.5, "#8aa8a8"), (1, "#5e7c7e")]), rx=4)
	d.spath("M380 230 L420 180 M396 244 L452 176", "#ffffff", 4, opacity=0.4)
	d.rect(346, 320, 168, 100, d.vlin(320, 420, [(0, "#5a3420"), (1, "#3a2010")]), rx=3)
	d.rect(340, 312, 180, 10, WOOD_L, rx=3)
	for x0 in (356, 410, 464):
		d.rect(x0, 334, 44, 70, "none", stroke="#2a170c", stroke_width=2)
		d.circle(x0 + 22, 370, 3, BRASS_L)
	for (x, c) in [(372, "#6a2a3a"), (386, "#2e6a4a"), (474, "#e8e2d2"), (492, "#e8e2d2")]:
		d.rect(x - 5, 286, 10, 26, c, rx=3)
		d.rect(x - 2, 278, 4, 10, c)
	d.ellipse(432, 306, 28, 6, "#e8e2d2")
	d.ellipse(432, 300, 22, 5, "#d8d0bd")
	# upright piano (back right)
	d.ellipse(850, 432, 100, 10, "#000000", opacity=0.3)
	d.rect(770, 254, 160, 176, d.vlin(254, 430, [(0, "#3e2214"), (1, "#24130a")]), rx=4)
	d.rect(764, 248, 172, 12, "#4e2c18", rx=3)
	d.rect(780, 266, 140, 70, "#2a170c", rx=3)
	d.rect(788, 274, 124, 54, "none", stroke=BRASS_D, stroke_width=1.6, opacity=0.8)
	d.rect(826, 276, 48, 34, "#f4ecd8")
	glyphs(d, 830, 280, 40, 26, 3, "#5a4a3a", rng, 1.2)
	d.rect(760, 340, 180, 14, "#3a2010")
	d.rect(766, 342, 168, 12, "#f6f1e4")
	dd = ""
	for k in range(1, 28):
		dd += "M%s 342 L%s 354 " % F(766 + k * 6.2, 766 + k * 6.2)
	d.spath(dd, "#b8b0a0", 0.8)
	for k in range(27):
		if k % 7 not in (2, 6):
			d.rect(766 + k * 6.2 + 4, 342, 3.6, 7, "#1a1210")
	d.rect(790, 410, 12, 20, "#1a0e08")
	d.rect(898, 410, 12, 20, "#1a0e08")
	for (cx_, cy_) in ((784, 244), (916, 244)):
		d.rect(cx_ - 3, cy_ - 22, 6, 22, "#fff4dc")
		d.ellipse(cx_, cy_ - 26, 3.5, 6, LANTERN_HOT)
		glow(d, cx_, cy_ - 26, 24, LANTERN, 0.7)
	# chess side-table (back left, in front of the sideboard)
	tc = P(420, 352, 1.22)
	d.ellipse(tc[0], tc[1] + 100, 40, 7, "#000000", opacity=0.3)
	d.rect(tc[0] - 5, tc[1], 10, 96, WOOD_D)
	d.path("M%s %s L%s %s L%s %s Z" % F(tc[0] - 30, tc[1] + 100, tc[0] + 30, tc[1] + 100, tc[0], tc[1] + 80), WOOD_D)
	d.ellipse(tc[0], tc[1] + 5, 50, 12, WOOD_D)
	d.ellipse(tc[0], tc[1], 50, 12, WOOD_L)
	board = [(tc[0] - 32, tc[1]), (tc[0], tc[1] - 9), (tc[0] + 32, tc[1]), (tc[0], tc[1] + 9)]
	d.poly(board, "#f1e6cc", stroke="#2a170c", stroke_width=1.4)
	for i in range(4):
		for j in range(4):
			if (i + j) % 2:
				u0, u1, v0, v1 = i / 4, (i + 1) / 4, j / 4, (j + 1) / 4

				def bp(u, v):
					return (board[0][0] + (board[1][0] - board[0][0]) * u + (board[3][0] - board[0][0]) * v,
						board[0][1] + (board[1][1] - board[0][1]) * u + (board[3][1] - board[0][1]) * v)
				d.poly([bp(u0, v0), bp(u1, v0), bp(u1, v1), bp(u0, v1)], "#5a3a22")
	for (dx, dy, c, hgt) in [(-18, -2, "#f8f4ea", 9), (-10, -6, "#f8f4ea", 12), (-4, 2, "#f8f4ea", 8), (12, 3, "#1e1612", 9), (18, -1, "#1e1612", 13),
			(6, -5, "#1e1612", 8)]:
		x, y = tc[0] + dx, tc[1] + dy
		d.path("M%s %s L%s %s Q%s %s %s %s Z" % F(x - 3, y, x + 3, y, x + 2, y - hgt, x - 2, y - hgt), c, stroke="#2a170c", stroke_width=0.8)
		d.circle(x, y - hgt - 1.5, 2.4, c, stroke="#2a170c", stroke_width=0.8)
	# rug runner + floor planks
	pplanks(d, pp, bx0, bx1, by1, 16, "#24140a", a=0.5, rng=rng)
	d.poly([P(520, by1, 1.05), P(760, by1, 1.05), P(760, by1, FAR), P(520, by1, FAR)], "#6a1a28")
	d.poly([P(532, by1, 1.08), P(748, by1, 1.08), P(748, by1, FAR), P(532, by1, FAR)], "none", stroke=GOLD, stroke_width=3)
	d.poly([P(520, by1, 1.05), P(760, by1, 1.05), P(760, by1, FAR), P(520, by1, FAR)], d.vlin(by1, H, [(0, "#000000", 0.35), (1, "#000000", 0)]))
	# chairs on the far side of the table first (both sides), then the table, then the near chairs
	TY, T0, T1, TX0, TX1 = 334, 1.22, 2.2, 584, 696
	for sc in (1.4, 1.75):
		pchair(d, pp, TX0 - 22, sc, -1)
		pchair(d, pp, TX1 + 22, sc, 1)
	# long table with a white cloth
	for (xx, ss) in ((TX0 + 8, T1 - 0.04), (TX1 - 8, T1 - 0.04), (TX0 + 8, T0 + 0.04), (TX1 - 8, T0 + 0.04)):
		a0, a1 = P(xx, TY, ss), P(xx, by1, ss)
		d.spath("M%s %s L%s %s" % F(a0[0], a0[1], a1[0], a1[1]), WOOD_DD, 9 * ss, stroke_linecap="butt")
		k = P(xx, TY + 70, ss)
		d.ellipse(k[0], k[1], 7 * ss, 4 * ss, WOOD_D)
	for (xx, ss0, ss1) in ((TX0, T0, T1), (TX1, T0, T1)):
		d.poly([P(xx, TY, ss0), P(xx, TY, ss1), P(xx, TY + 52, ss1), P(xx, TY + 52, ss0)], "#cfc6b4")
	d.poly([P(TX0, TY, T1), P(TX1, TY, T1), P(TX1, TY + 56, T1), P(TX0, TY + 56, T1)], d.vlin(P(0, TY, T1)[1], P(0, TY + 56, T1)[1], [(0, "#f4efe4"), (1, "#d8cfbc")]))
	dd = ""
	for k in range(1, 8):
		xx = TX0 + (TX1 - TX0) * k / 8
		a0, a1 = P(xx, TY + 4, T1), P(xx, TY + 56, T1)
		dd += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
	d.spath(dd, "#bfb5a0", 1.4, opacity=0.6)
	d.poly([P(TX0, TY, T0), P(TX1, TY, T0), P(TX1, TY, T1), P(TX0, TY, T1)], d.vlin(P(0, TY, T0)[1], P(0, TY, T1)[1], [(0, "#efe8d8"), (1, "#fbf8f0")]))
	d.poly([P(618, TY, T0), P(662, TY, T0), P(662, TY, T1), P(618, TY, T1)], TEALP, opacity=0.8)
	d.poly([P(621, TY, T0), P(659, TY, T0), P(659, TY, T1), P(621, TY, T1)], "none", stroke=BRASS, stroke_width=1.5, opacity=0.8)
	# place settings, candles, a soup tureen
	for ss in (1.4, 1.75, 2.08):
		for xx in (TX0 + 22, TX1 - 22):
			c = P(xx, TY, ss)
			d.ellipse(c[0], c[1], 15 * ss, 4.2 * ss, "#ffffff", stroke="#c9c0ad", stroke_width=1)
			d.ellipse(c[0], c[1], 9 * ss, 2.4 * ss, "none", stroke=TEALP_L, stroke_width=1.2, opacity=0.8)
			g0 = P(xx + (12 if xx < 640 else -12), TY, ss - 0.07)
			d.rect(g0[0] - 2.5 * ss, g0[1] - 12 * ss, 5 * ss, 12 * ss, "#d8f2ee", opacity=0.75, rx=1)
	for ss in (1.45, 2.0):
		c = P(640, TY, ss)
		d.rect(c[0] - 9 * ss, c[1] - 6 * ss, 18 * ss, 6 * ss, BRASS_D, rx=2)
		for dxk in (-6, 0, 6):
			d.rect(c[0] + dxk * ss - 1.6 * ss, c[1] - 26 * ss, 3.2 * ss, 20 * ss, "#fff4dc")
			d.ellipse(c[0] + dxk * ss, c[1] - 29 * ss, 1.8 * ss, 3.2 * ss, LANTERN_HOT)
			glow(d, c[0] + dxk * ss, c[1] - 29 * ss, 14 * ss, LANTERN, 0.7)
	c = P(640, TY, 1.72)
	d.ellipse(c[0], c[1], 30, 8, "#000000", opacity=0.2)
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % F(c[0] - 26, c[1] - 16, c[0] - 26, c[1] + 2, c[0], c[1] + 2, c[0], c[1] + 2,
		c[0] + 26, c[1] + 2, c[0] + 26, c[1] - 16), d.lin(c[0] - 26, 0, c[0] + 26, 0, [(0, "#c9c0ad"), (0.4, "#ffffff"), (1, "#b8ae98")]))
	d.ellipse(c[0], c[1] - 16, 26, 6, "#f4f0e6", stroke="#c9c0ad", stroke_width=1)
	d.ellipse(c[0], c[1] - 20, 6, 3, BRASS)
	pchair(d, pp, TX0 - 22, 2.1, -1)
	pchair(d, pp, TX1 + 22, 2.1, 1)
	# brass lamps over the table
	for sc in (1.3, 1.95):
		for xb in (586, 694):
			c = P(xb, 196, sc)
			ship_lamp(d, c[0], c[1], 0.5 * sc, hang_from=-10, glow_a=0.38, glow_r=170)
	floor_reflect(d, 640, 600, 300, 50, LANTERN, 0.14)
	light_wash(d, "#ffcf8a", 0.1, 0, 320)
	vignette(d, 0.45, "#0a0604")


# --------------------------------------------------------------------------------------
# SHIP_HALL - cabin corridor (doors 1 2 3)
# --------------------------------------------------------------------------------------

def cabin_door(d, x0, y0, x1, y1, num, rng, wood="#7a4426", arch=False):
	"""Ship cabin door in its frame; (x0,y0)-(x1,y1) = outer frame, y1 = floor."""
	w = x1 - x0
	if arch:
		d.path("M%s %s L%s %s Q%s %s %s %s L%s %s Z" % F(x0 - 4, y1, x0 - 4, y0 + 24, (x0 + x1) / 2, y0 - 24, x1 + 4, y0 + 24, x1 + 4, y1), "#000000", opacity=0.25)
	else:
		d.rect(x0 - 4, y0 - 4, w + 8, y1 - y0 + 4, "#000000", opacity=0.25)
	if arch:
		d.path("M%s %s L%s %s Q%s %s %s %s L%s %s Z" % F(x0, y1, x0, y0 + 26, (x0 + x1) / 2, y0 - 18, x1, y0 + 26, x1, y1), WOOD_DD)
	else:
		d.rect(x0, y0, w, y1 - y0, WOOD_DD)
	lx0, lx1, ly0 = x0 + 12, x1 - 12, y0 + (30 if arch else 12)
	if arch:
		d.path("M%s %s Q%s %s %s %s L%s %s Z" % F(lx0, ly0 - 2, (x0 + x1) / 2, y0 - 2, lx1, ly0 - 2, lx0, ly0 - 2), "#24140a")
		d.path("M%s %s Q%s %s %s %s Z" % F(lx0 + 6, ly0 - 4, (x0 + x1) / 2, y0 + 4, lx1 - 6, ly0 - 4), d.vlin(y0, ly0, [(0, LANTERN_HOT), (1, LANTERN)]))
		dd = ""
		for k in (-2, -1, 0, 1, 2):
			dd += "M%s %s L%s %s " % F((x0 + x1) / 2, ly0 - 4, (x0 + x1) / 2 + k * 22, y0 + 8 + abs(k) * 4)
		d.spath(dd, "#24140a", 2)
	d.rect(lx0, ly0, lx1 - lx0, y1 - ly0, d.lin(lx0, 0, lx1, 0, [(0, light(wood, 0.12)), (0.5, wood), (1, dark(wood, 0.2))]))
	pw = lx1 - lx0
	# upper panel with louvred vent, lower panel
	py0 = ly0 + 54
	d.rect(lx0 + 14, py0, pw - 28, 96, dark(wood, 0.1), stroke=dark(wood, 0.45), stroke_width=2.4)
	d.rect(lx0 + 16, py0 + 2, pw - 32, 4, light(wood, 0.3), opacity=0.5)
	d.rect(lx0 + 14, y1 - 132, pw - 28, 66, dark(wood, 0.1), stroke=dark(wood, 0.45), stroke_width=2.4)
	d.rect(lx0 + 20, y1 - 56, pw - 40, 30, dark(wood, 0.5), rx=2)
	dd = ""
	for k in range(5):
		yy = y1 - 52 + k * 6
		dd += "M%s %s L%s %s " % F(lx0 + 22, yy, lx1 - 22, yy)
	d.spath(dd, light(wood, 0.15), 1.6, opacity=0.8, stroke_linecap="butt")
	d.rect(lx0 + 4, y1 - 14, pw - 8, 12, d.lin(lx0, 0, lx1, 0, [(0, BRASS_D), (0.5, BRASS_L), (1, BRASS_D)]), rx=2)
	# number plaque
	cx = (lx0 + lx1) / 2
	cy = ly0 + 28
	d.ellipse(cx, cy + 2, 22, 17, "#000000", opacity=0.3)
	d.ellipse(cx, cy, 21, 16, d.lin(cx - 20, cy - 16, cx + 20, cy + 16, [(0, BRASS_L), (0.5, BRASS), (1, BRASS_D)]), stroke=BRASS_D, stroke_width=1.6)
	d.ellipse(cx, cy, 15, 11.5, "#2a1a0c")
	digit(d, cx, cy + 0.5, num, 0.82, BRASS_L, 3.2)
	# knob + keyhole escutcheon
	kx = lx1 - 16
	ky = y1 - 160
	d.rect(kx - 5, ky - 10, 10, 34, BRASS_D, rx=4)
	d.circle(kx, ky, 7.5, d.brad([(0, BRASS_L), (1, BRASS_D)], cx=0.35, cy=0.35, r=0.7), stroke=INK, stroke_width=1)
	d.circle(kx, ky + 14, 2, "#1a1008")
	d.rect(kx - 0.8, ky + 14, 1.6, 5, "#1a1008")
	# hinges
	for hy in (ly0 + 30, y1 - 60):
		d.rect(lx0 - 3, hy, 7, 22, BRASS_D, rx=2)
	return (lx0, ly0, lx1, y1, kx, ky)


def bg_ship_hall(d):
	rng = random.Random(501)
	FLOOR = 490
	d.rect(0, 0, W, H, "#2a170c")
	# wall: warm panelling above, teal wainscot below
	wood_panels(d, 0, 52, W, 372, "#b0764a", step=54, a=0.45)
	wainscot(d, 0, 372, W, FLOOR)
	d.rect(0, 52, W, 10, "#3a2010")
	d.rect(0, 62, W, 4, BRASS_D, opacity=0.7)
	# ceiling: beams + pipes
	d.rect(0, 0, W, 54, d.vlin(0, 54, [(0, "#140b06"), (1, "#2a170c")]))
	for (y, c, w_) in ((14, "#556066", 10), (32, BRASS_D, 8)):
		d.rect(0, y - w_ / 2, W, w_, d.vlin(y - w_ / 2, y + w_ / 2, [(0, light(c, 0.35)), (1, dark(c, 0.25))]))
	for x in range(40, W, 160):
		d.rect(x, 6, 10, 34, "#2a2d33", rx=2)
	# floor: planks along the corridor + runner carpet
	d.rect(0, FLOOR, W, H - FLOOR, d.vlin(FLOOR, H, [(0, "#4a2c18"), (1, "#6e4428")]))
	dd = ""
	y = FLOOR + 8.0
	gap = 9.0
	while y < H:
		dd += "M0 %s L%s %s " % F(y, W, y)
		y += gap
		gap *= 1.22
	d.spath(dd, "#2a170c", 1.6, opacity=0.55, stroke_linecap="butt")
	d.rect(0, FLOOR, W, 10, "#000000", opacity=0.35)
	d.rect(0, 560, W, 92, d.vlin(560, 652, [(0, "#5e1724"), (1, "#7a2030")]))
	d.rect(0, 566, W, 3, GOLD, opacity=0.8)
	d.rect(0, 644, W, 3, GOLD, opacity=0.8)
	dd = ""
	for x in range(-20, W + 40, 64):
		dd += "M%s 584 l16 22 l-16 22 l-16 -22 Z " % fm(float(x))
	d.path(dd, "none", stroke=GOLD_D, stroke_width=1.6, opacity=0.45)
	# rules poster (left)
	d.rect(118, 112, 150, 196, "#2a170c", rx=4)
	d.rect(126, 120, 134, 180, d.vlin(120, 300, [(0, "#2a5a5a"), (1, "#1b3b3c")]))
	d.rect(132, 128, 122, 60, "#173234")
	snapjaw_crest(d, 193, 158, 0.42)
	for k in range(6):
		yy = 202 + k * 16
		d.circle(140, yy + 4, 3.5, (PRED, YUZU, TEALP_L, PRED, YUZU, "#9a7ad0")[k])
		glyphs(d, 150, yy - 2, 96, 12, 1, "#e8e2d2", rng, 1.3)
	# lamps
	for x in (300, 1000):
		wall_lamp(d, x, 214, 0.9, side=-1 if x < 640 else 1, glow_a=0.5)
		floor_reflect(d, x, 520, 170, 26, LANTERN, 0.22)
	ship_lamp(d, 640, 108, 0.7, hang_from=40, glow_a=0.45)
	floor_reflect(d, 640, 540, 260, 30, LANTERN, 0.2)
	# speaking tube between doors 1 and 2: pipe from the ceiling, elbow, round horn mouth facing the corridor
	tx, ty = 525, 113
	d.rect(tx - 7, 0, 14, 84, d.lin(tx - 7, 0, tx + 7, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)]))
	for yy in (20, 60):
		d.rect(tx - 11, yy, 22, 8, "#2a2d33", rx=2)
	d.ellipse(tx, ty + 4, 31, 30, "#000000", opacity=0.3)
	d.ellipse(tx, 84, 9, 6, BRASS_D)
	d.rect(tx - 9, 80, 18, 12, d.lin(tx - 9, 0, tx + 9, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)]))
	d.circle(tx, ty, 28, d.lin(tx - 28, ty - 28, tx + 28, ty + 28, [(0, BRASS_L), (0.45, BRASS), (1, BRASS_D)]), stroke=INK, stroke_width=1.8)
	d.circle(tx, ty, 21, d.lin(tx + 20, ty + 20, tx - 20, ty - 20, [(0, BRASS_L), (0.5, BRASS), (1, BRASS_D)]))
	d.circle(tx, ty, 14, d.rad(tx, ty + 3, 15, [(0, "#000000"), (0.7, "#1a1008"), (1, "#3a2410")]))
	d.path("M%s %s A24 24 0 0 1 %s %s" % F(tx - 20, ty - 14, tx + 8, ty - 25), "none", stroke="#ffffff", stroke_width=2.4, opacity=0.5, stroke_linecap="round")
	# hinged whistle cap swung open on top
	d.rect(tx + 16, ty - 32, 8, 8, BRASS_D, rx=2)
	with G(d, transform=T(tx + 24, ty - 34, 1, 28)):
		d.ellipse(10, -4, 14, 6, d.lin(0, -10, 0, 2, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=1.4)
		d.rect(6, -14, 8, 8, BRASS, rx=3, stroke=INK, stroke_width=1.2)
	glow(d, tx, ty, 46, LANTERN, 0.15)
	# fire bucket (rule 3: fire safety first!)
	d.rect(1068, 250, 8, 14, "#2a2d33")
	d.path("M1048 268 L1096 268 L1090 322 L1054 322 Z", d.lin(1048, 0, 1096, 0, [(0, "#a02a22"), (0.4, "#e0483a"), (1, "#8a221c")]), stroke=INK, stroke_width=1.6)
	d.spath("M1048 268 Q1072 236 1096 268", "#2a2d33", 2.4)
	d.rect(1046, 264, 52, 6, "#c0392b", stroke=INK, stroke_width=1.2)
	# far ends of the corridor fade into gloom
	d.rect(0, 0, 160, H, d.lin(0, 0, 160, 0, [(0, "#0a0604", 0.75), (1, "#0a0604", 0)]))
	d.rect(W - 160, 0, 160, H, d.lin(W - 160, 0, W, 0, [(0, "#0a0604", 0), (1, "#0a0604", 0.75)]))
	croc_cam(d, 1180, 92, 0.85, flip=True)
	# --- the three cabin doors
	cabin_door(d, 372, 182, 518, FLOOR, "1", rng)
	l2 = cabin_door(d, 562, 162, 718, FLOOR, "2", rng, arch=True)
	cabin_door(d, 762, 182, 908, FLOOR, "3", rng)
	# door 1 (Mochi): a little yuzu sticker
	B.yuzu(d, 402, 276, 9, -15)
	# door 2: a crescent-moon "shh" hanger on the knob
	kx, ky = l2[4], l2[5]
	d.spath("M%s %s L%s %s L%s %s" % F(kx - 8, ky + 2, kx, ky - 14, kx + 8, ky + 2), "#5a4a3a", 1.2)
	d.path("M%s %s A16 16 0 1 0 %s %s A12 12 0 1 1 %s %s Z" % F(kx - 6, ky + 4, kx + 10, ky + 30, kx - 6, ky + 4), "#f2d27a", stroke=INK, stroke_width=1.4)
	d.circle(kx - 1, ky + 22, 1.6, INK)
	# door 3 (Pepper): a note pinned to the door
	with G(d, transform=T(860, 262, 1, 6)):
		d.rect(-18, -14, 36, 30, "#fbf6e8", stroke="#c9bfa8", stroke_width=1)
		glyphs(d, -13, -7, 26, 18, 2, "#3a3a4a", rng, 1.1)
		d.circle(0, -12, 3, "#d8332c")
	# floor shadows under the doors
	for (x0, x1) in ((372, 518), (562, 718), (762, 908)):
		d.rect(x0, FLOOR, x1 - x0, 16, d.vlin(FLOOR, FLOOR + 16, [(0, "#000000", 0.35), (1, "#000000", 0)]))
		d.rect(x0 + 14, FLOOR - 3, x1 - x0 - 28, 3, LANTERN, opacity=0.25)
	light_wash(d, "#ffcf8a", 0.1, 0, 300)
	vignette(d, 0.5, "#0a0604")


# --------------------------------------------------------------------------------------
# SHIP_CABIN / SHIP_TUMBLE_CABIN - guest cabins (same layout)
# --------------------------------------------------------------------------------------

def nightcap_hanging(d, hx_, hy_):
	"""Tumble's droopy blue starry nightcap hanging from a wall hook at (hx_, hy_)."""
	d.circle(hx_, hy_, 5, BRASS_D)
	d.spath("M%s %s q0 10 8 10" % F(hx_, hy_), BRASS_D, 3)
	cone = smooth([(hx_ - 38, hy_ + 14), (hx_ - 26, hy_ + 6), (hx_ + 6, hy_ + 4), (hx_ + 34, hy_ + 12), (hx_ + 40, hy_ + 30), (hx_ + 30, hy_ + 62),
		(hx_ + 30, hy_ + 92), (hx_ + 40, hy_ + 108), (hx_ + 20, hy_ + 100), (hx_ + 8, hy_ + 70), (hx_ - 10, hy_ + 46), (hx_ - 34, hy_ + 30)])
	d.ellipse(hx_ + 12, hy_ + 66, 30, 46, "#000000", opacity=0.08)
	d.path(cone, d.lin(hx_ - 38, 0, hx_ + 40, 0, [(0, "#3a5590"), (0.45, "#5a7cc0"), (1, "#34508a")]), stroke=INK, stroke_width=2.4)
	cid = d.clip('<path d="%s"/>' % cone)
	with G(d, clip_path=cid):
		for (x, y) in ((-20, 20), (6, 16), (24, 30), (-4, 38), (16, 54), (26, 80), (10, 84)):
			d.circle(hx_ + x, hy_ + y, 3.6, "#f4f1ea", opacity=0.95)
		d.path("M%s %s Q%s %s %s %s L%s %s Z" % F(hx_ + 40, hy_ + 20, hx_ + 26, hy_ + 64, hx_ + 36, hy_ + 104, hx_ + 60, hy_ + 104), "#1e2f5a", opacity=0.3)
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % F(hx_ - 40, hy_ + 10, hx_, hy_ - 4, hx_ + 38, hy_ + 8, hx_ + 36, hy_ + 22, hx_, hy_ + 10,
		hx_ - 36, hy_ + 26), "#f4f1ea", stroke=INK, stroke_width=2.2)
	pom = []
	for i in range(12):
		a = i * TAU / 12
		rr = 13 if i % 2 == 0 else 10
		pom.append((hx_ + 34 + math.cos(a) * rr, hy_ + 112 + math.sin(a) * rr))
	d.path(smooth(pom), "#f8f6f0", stroke=INK, stroke_width=2.2)


def teacup(d, cx, base, s=1.0):
	"""Clean, empty white teacup on its saucer (base = saucer bottom)."""
	d.ellipse(cx, base - 2 * s, 24 * s, 6 * s, "#d9d4c8", stroke=INK, stroke_width=1.4)
	d.ellipse(cx, base - 4 * s, 18 * s, 4 * s, "#ffffff")
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(cx - 15 * s, base - 22 * s, cx - 14 * s, base - 4 * s, cx, base - 4 * s, cx + 14 * s, base - 4 * s,
		cx + 15 * s, base - 22 * s), d.lin(cx - 15 * s, 0, cx + 15 * s, 0, [(0, "#d6d2c8"), (0.35, "#ffffff"), (1, "#c8c2b6")]), stroke=INK, stroke_width=1.6)
	d.spath("M%s %s Q%s %s %s %s" % F(cx + 14 * s, base - 18 * s, cx + 24 * s, base - 16 * s, cx + 13 * s, base - 9 * s), INK, 4.2 * s)
	d.spath("M%s %s Q%s %s %s %s" % F(cx + 14 * s, base - 18 * s, cx + 24 * s, base - 16 * s, cx + 13 * s, base - 9 * s), "#f4f1ea", 2.4 * s)
	d.ellipse(cx, base - 22 * s, 15 * s, 4 * s, "#efe9dc", stroke=INK, stroke_width=1.4)
	d.ellipse(cx, base - 21.5 * s, 11 * s, 2.6 * s, "#e2dccd")
	d.spath("M%s %s Q%s %s %s %s" % F(cx - 10 * s, base - 14 * s, cx - 8 * s, base - 8 * s, cx - 2 * s, base - 7 * s), TEALP_L, 1.6 * s, opacity=0.8)


def cabin_room(d, rng, mode):
	tumble = mode == "tumble"
	pp = Persp(640, 300)
	P = pp.P
	bx0, by0, bx1, by1 = 330, 52, 990, 498
	pshell(d, pp, bx0, by0, bx1, by1, "#b88052", "#94603a", "#8a5634", "#3a2414", "#6a4228", "#4a2c18")
	# back wall: vertical planks + teal wainscot
	wood_panels(d, bx0, by0, bx1, 392, "#b07848", step=44, a=0.4)
	wainscot(d, bx0, 392, bx1, by1, panels=False)
	for bx in (bx0, bx1):
		side_band(d, pp, bx, 392, by1, d.lin(0 if bx == bx0 else W, 0, bx, 0, [(0, dark(TEALP_D, 0.3)), (1, TEALP)]))
		side_line(d, pp, bx, 392, BRASS, 4)
		dd = ""
		for k in range(1, 9):
			sc = 1 + k * 0.22
			a0, a1 = P(bx, by0, sc), P(bx, 392, sc)
			dd += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
		d.spath(dd, "#5a3620", 1.4, opacity=0.4)
	pbeams(d, pp, bx0, bx1, by0, (1.0, 1.5, 2.3), "#24150c", 14)
	pplanks(d, pp, bx0, bx1, by1, 12, "#24140a", a=0.5, rng=rng)
	# porthole (back wall, over the bunk)
	porthole(d, 630, 190, 60, rng, view="cave")
	d.poly([(590, 236), (672, 236), (720, 420), (548, 420)], "#7ff0e2", opacity=0.06)
	# right side wall: door out to the corridor (dim, calm); left wall: a small mirror
	dq = [P(bx1, 150, 1.25), P(bx1, 150, 1.75), P(bx1, by1, 1.75), P(bx1, by1, 1.25)]
	d.poly(dq, "#4a2a16")
	dq2 = [P(bx1, 160, 1.3), P(bx1, 160, 1.7), P(bx1, by1, 1.7), P(bx1, by1, 1.3)]
	d.poly(dq2, d.lin(dq2[0][0], 0, dq2[1][0], 0, [(0, "#6a3c20"), (1, "#5a321a")]))
	kn = P(bx1, 330, 1.36)
	d.circle(kn[0], kn[1], 5, BRASS)
	mc = P(bx0, 190, 1.55)
	d.ellipse(mc[0], mc[1], 22, 40, "#4a2a16")
	d.ellipse(mc[0], mc[1], 16, 33, d.lin(mc[0] - 16, mc[1] - 30, mc[0] + 16, mc[1] + 30, [(0, "#c8dcd8"), (1, "#5e7c7e")]))
	croc_cam(d, bx1 - 22, by0 + 40, 0.6, flip=True)
	# --- bunk (built-in berth against the back wall)
	X0, X1, S0, S1 = 474, 776, 1.0, 1.32
	MT = 405
	d.ellipse(P(625, by1, S1)[0], P(625, by1, S1)[1] + 4, 220, 14, "#000000", opacity=0.35)
	for (xx, yt) in ((X0 - 14, 336), (X1 + 14, 360)):
		q = [P(xx, yt + 8, S0), P(xx, yt, S0 + 0.08), P(xx, yt, S1 - 0.08), P(xx, yt + 8, S1), P(xx, by1, S1), P(xx, by1, S0)]
		d.poly(q, d.vlin(P(xx, yt, S1)[1], P(xx, by1, S1)[1], [(0, WOOD), (1, WOOD_D)]))
		a0, a1 = P(xx, yt, S0 + 0.08), P(xx, yt, S1 - 0.08)
		d.spath("M%s %s L%s %s" % F(a0[0], a0[1], a1[0], a1[1]), BRASS, 3)
		for ss in (S0 + 0.02, S1 - 0.02):
			c = P(xx, yt + 4, ss)
			d.circle(c[0], c[1], 4.5, BRASS_L, stroke=BRASS_D, stroke_width=1)
	front = [P(X0 - 14, MT + 6, S1), P(X1 + 14, MT + 6, S1), P(X1 + 14, by1, S1), P(X0 - 14, by1, S1)]
	d.poly(front, d.vlin(front[0][1], front[2][1], [(0, WOOD_L), (1, WOOD)]))
	dw = (X1 - X0 - 18) / 2
	for k in range(2):
		xa = X0 + 4 + k * (dw + 10)
		xb = xa + dw
		q = [P(xa, MT + 26, S1), P(xb, MT + 26, S1), P(xb, by1 - 14, S1), P(xa, by1 - 14, S1)]
		d.poly(q, dark(WOOD, 0.08), stroke=WOOD_D, stroke_width=2.2)
		c = P((xa + xb) / 2, (MT + by1) / 2 + 4, S1)
		d.rect(c[0] - 12, c[1] - 3, 24, 6, BRASS, rx=3)
	# mattress + blanket + pillow
	top = [P(X0, MT, S0), P(X1, MT, S0), P(X1, MT, S1 - 0.02), P(X0, MT, S1 - 0.02)]
	d.poly(top, "#e8e2d4")
	fr = [P(X0, MT - 2, S1 - 0.02), P(X1, MT - 2, S1 - 0.02), P(X1, MT + 10, S1 - 0.02), P(X0, MT + 10, S1 - 0.02)]
	d.poly(fr, "#d2cab8")
	if tumble:
		blanket = "#c4553f"
		bl = [P(X0 + 112, MT - 4, S0), P(X1, MT - 4, S0), P(X1, MT - 4, S1), P(X0 + 112, MT - 4, S1)]
		d.poly(bl, d.lin(bl[0][0], 0, bl[1][0], 0, [(0, light(blanket, 0.08)), (1, dark(blanket, 0.1))]))
		cid = d.clip('<polygon points="%s"/>' % B.pts(bl))
		with G(d, clip_path=cid):
			dd = ""
			dd2 = ""
			for k in range(10):
				xb = X0 + 112 + k * 34
				a0, a1 = P(xb, MT - 4, S0), P(xb, MT - 4, S1)
				dd += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
				a0, a1 = P(xb + 14, MT - 4, S0), P(xb + 14, MT - 4, S1)
				dd2 += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
			for k in range(4):
				ss = S0 + (S1 - S0) * (k + 0.5) / 4
				a0, a1 = P(X0 + 112, MT - 4, ss), P(X1, MT - 4, ss)
				dd += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
			d.spath(dd, "#9e3b2b", 5, opacity=0.6, stroke_linecap="butt")
			d.spath(dd2, "#f2d8a8", 1.2, opacity=0.8, stroke_linecap="butt")
		ff = [P(X0 + 112, MT - 4, S1), P(X1, MT - 4, S1), P(X1, MT + 12, S1), P(X0 + 112, MT + 12, S1)]
		d.poly(ff, dark(blanket, 0.2))
		tc = [P(X0 + 100, MT - 6, S0), P(X0 + 122, MT - 6, S0), P(X0 + 122, MT - 6, S1), P(X0 + 100, MT - 6, S1)]
		d.poly(tc, "#f4f0e6")
		# smooth, untouched pillow
		pc = P(X0 + 52, MT - 4, (S0 + S1) / 2)
		d.ellipse(pc[0], pc[1] + 8, 62, 10, "#000000", opacity=0.15)
		d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Z" % F(pc[0] - 58, pc[1] + 4, pc[0] - 60, pc[1] - 20, pc[0] - 40, pc[1] - 22,
			pc[0], pc[1] - 26, pc[0] + 52, pc[1] - 20, pc[0] + 60, pc[1] - 4, pc[0] + 56, pc[1] + 10, pc[0], pc[1] + 12, pc[0] - 58, pc[1] + 4),
			d.vlin(pc[1] - 26, pc[1] + 12, [(0, "#ffffff"), (1, "#dcd8ce")]), stroke="#a8a294", stroke_width=1.6)
		d.spath("M%s %s Q%s %s %s %s" % F(pc[0] - 36, pc[1] - 14, pc[0], pc[1] - 20, pc[0] + 34, pc[1] - 14), "#ffffff", 3, opacity=0.8)
	else:
		blanket = "#e08a3a"
		bl = [P(X0 + 126, MT - 6, S0), P(X1, MT - 4, S0), P(X1, MT - 4, S1), P(X0 + 104, MT - 8, S1)]
		d.poly(bl, d.lin(bl[0][0], 0, bl[1][0], 0, [(0, "#f0a050"), (1, "#c86e26")]))
		hump = [P(X0 + 136, MT - 8, 1.08), P(X0 + 220, MT - 22, 1.12), P(X1 - 16, MT - 12, 1.2), P(X1 - 24, MT - 4, 1.3), P(X0 + 128, MT - 6, 1.3)]
		d.path(smooth(hump), "#f6a858", opacity=0.55)
		ff = [P(X0 + 104, MT - 8, S1), P(X1, MT - 4, S1), P(X1, MT + 14, S1), P(X0 + 100, MT + 12, S1)]
		d.poly(ff, "#a85a1c")
		for (u, sv) in ((0.3, 1.1), (0.55, 1.2), (0.8, 1.12)):
			c = P(X0 + 126 + (X1 - X0 - 126) * u, MT - 6, sv)
			d.circle(c[0], c[1], 7, YUZU, opacity=0.85)
		pc = P(X0 + 54, MT - 4, (S0 + S1) / 2)
		d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Z" % F(pc[0] - 56, pc[1] + 4, pc[0] - 62, pc[1] - 16, pc[0] - 30, pc[1] - 22,
			pc[0] + 6, pc[1] - 14, pc[0] + 48, pc[1] - 24, pc[0] + 62, pc[1] - 2, pc[0] + 50, pc[1] + 10, pc[0], pc[1] + 12, pc[0] - 56, pc[1] + 4),
			d.vlin(pc[1] - 24, pc[1] + 12, [(0, "#ffffff"), (1, "#d6d2c8")]), stroke="#a8a294", stroke_width=1.6)
	# lee board (low front rail)
	lb = [P(X0 - 14, MT - 10, S1), P(X1 + 14, MT - 10, S1), P(X1 + 14, MT + 6, S1), P(X0 - 14, MT + 6, S1)]
	d.poly(lb, d.vlin(lb[0][1], lb[2][1], [(0, WOOD_L), (1, WOOD_D)]))
	d.spath("M%s %s L%s %s" % F(lb[0][0], lb[0][1], lb[1][0], lb[1][1]), BRASS, 2.4)
	# --- rug beside the bunk
	RX0, RX1, RS0, RS1 = 505, 750, 1.38, 1.76
	rug = [P(RX0, by1, RS0), P(RX1, by1, RS0), P(RX1, by1, RS1), P(RX0, by1, RS1)]
	rugc = "#3d6a8a"
	d.poly(rug, d.vlin(rug[0][1], rug[2][1], [(0, dark(rugc, 0.1)), (1, rugc)]))
	inner = [P(RX0 + 14, by1, RS0 + 0.03), P(RX1 - 14, by1, RS0 + 0.03), P(RX1 - 14, by1, RS1 - 0.04), P(RX0 + 14, by1, RS1 - 0.04)]
	d.poly(inner, "none", stroke="#e8c88a", stroke_width=3)
	inner2 = [P(RX0 + 30, by1, RS0 + 0.07), P(RX1 - 30, by1, RS0 + 0.07), P(RX1 - 30, by1, RS1 - 0.09), P(RX0 + 30, by1, RS1 - 0.09)]
	d.poly(inner2, "none", stroke="#b8503a", stroke_width=2, opacity=0.8)
	c = P((RX0 + RX1) / 2, by1, (RS0 + RS1) / 2)
	d.ellipse(c[0], c[1], 46, 12, "none", stroke="#e8c88a", stroke_width=2.4, opacity=0.8)
	dd = ""
	for k in range(26):
		xb = RX0 + (RX1 - RX0) * k / 25
		for ss in (RS0, RS1):
			a0 = P(xb, by1, ss)
			dd += "M%s %s l0 %s " % F(a0[0], a0[1], 5 if ss == RS1 else -4)
	d.spath(dd, "#e8c88a", 1.6, opacity=0.8)
	if tumble:
		# four small round dents in the pile, near the wall shared with Cabin 1
		for (xb, ss) in ((520, 1.47), (550, 1.47), (520, 1.57), (550, 1.57)):
			c = P(xb, by1, ss)
			d.ellipse(c[0], c[1], 6.5, 2.6, "#1e3a50", opacity=0.85)
			d.spath("M%s %s Q%s %s %s %s" % F(c[0] - 6, c[1] + 1, c[0], c[1] + 4.5, c[0] + 6, c[1] + 1), "#7aa4c4", 1.2, opacity=0.8)
	else:
		# Mochi's slippers on the rug
		for (xb, ss, rot) in ((600, 1.5, -8), (650, 1.55, 6)):
			c = P(xb, by1, ss)
			with G(d, transform=T(c[0], c[1], 1, rot)):
				d.ellipse(0, 2, 20, 7, "#000000", opacity=0.25)
				d.ellipse(0, 0, 19, 7, "#f2a040", stroke=INK, stroke_width=1.4)
				d.path("M-4 -6 Q8 -10 16 -2 Q8 4 -4 2 Z", "#e88a30", stroke=INK, stroke_width=1.2)
	# --- nightstand (right of the bunk)
	NX0, NX1, NS0, NS1 = 850, 925, 1.0, 1.06
	NT = by1 - 114
	d.poly([P(NX0, NT, NS0), P(NX0, NT, NS1), P(NX0, by1, NS1), P(NX0, by1, NS0)], WOOD_D)
	nf = [P(NX0, NT, NS1), P(NX1, NT, NS1), P(NX1, by1, NS1), P(NX0, by1, NS1)]
	d.poly(nf, d.vlin(nf[0][1], nf[2][1], [(0, WOOD_L), (1, WOOD)]), stroke=WOOD_DD, stroke_width=1.6)
	d.poly([P(NX0 - 4, NT, NS0), P(NX1 + 4, NT, NS0), P(NX1 + 4, NT, NS1 + 0.01), P(NX0 - 4, NT, NS1 + 0.01)], "#c08a58")
	q = [P(NX0 + 8, NT + 14, NS1), P(NX1 - 8, NT + 14, NS1), P(NX1 - 8, NT + 50, NS1), P(NX0 + 8, NT + 50, NS1)]
	d.poly(q, dark(WOOD, 0.08), stroke=WOOD_DD, stroke_width=1.8)
	cc = P((NX0 + NX1) / 2, NT + 32, NS1)
	d.circle(cc[0], cc[1], 4, BRASS_L)
	q = [P(NX0 + 8, NT + 62, NS1), P(NX1 - 8, NT + 62, NS1), P(NX1 - 8, by1 - 10, NS1), P(NX0 + 8, by1 - 10, NS1)]
	d.poly(q, "#24140a", opacity=0.75)
	topc = P((NX0 + NX1) / 2, NT, (NS0 + NS1) / 2)
	if tumble:
		teacup(d, topc[0] - 4, topc[1] + 2, 0.9)
	else:
		# small brass oil lamp, lit
		glow(d, topc[0], topc[1] - 34, 190, LANTERN, 0.55)
		d.ellipse(topc[0], topc[1], 22, 6, BRASS_D)
		d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(topc[0] - 20, topc[1] - 2, topc[0] - 22, topc[1] - 22, topc[0], topc[1] - 24, topc[0] + 22,
			topc[1] - 22, topc[0] + 20, topc[1] - 2), d.lin(topc[0] - 20, 0, topc[0] + 20, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=1.4)
		d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % F(topc[0] - 11, topc[1] - 24, topc[0] - 16, topc[1] - 46, topc[0] - 7, topc[1] - 62,
			topc[0] + 7, topc[1] - 62, topc[0] + 16, topc[1] - 46, topc[0] + 11, topc[1] - 24), "#fff4d6", opacity=0.75, stroke=BRASS_D, stroke_width=1.2)
		d.ellipse(topc[0], topc[1] - 40, 4, 9, "#ffffff")
		glow(d, topc[0], topc[1] - 40, 30, LANTERN_HOT, 0.8)
	# --- wall hook (left of the porthole)
	if tumble:
		nightcap_hanging(d, 426, 138)
	else:
		# Mochi's orange hoodie on the hook
		d.circle(426, 140, 5, BRASS_D)
		d.path("M398 150 Q426 136 454 150 L470 236 Q440 248 424 240 Q404 248 384 236 Z", d.lin(384, 0, 470, 0, [(0, "#c8641e"), (0.5, "#f08a3a"), (1, "#b85a1a")]),
			stroke=INK, stroke_width=2)
		d.path("M408 150 Q426 172 444 150 Q426 160 408 150 Z", "#a8501a")
		d.spath("M416 170 L414 196 M436 170 L438 196", "#f4e0c0", 2)
	# ceiling lamp
	if tumble:
		ship_lamp(d, 640, 92, 0.6, hang_from=50, glow_a=0.5, glow_r=200)


def bg_ship_cabin(d):
	rng = random.Random(601)
	cabin_room(d, rng, "mochi")
	# night: everything sinks into blue, then the lamp + porthole glow come back on top
	d.rect(0, 0, W, H, "#081030", opacity=0.45)
	glow(d, 630, 190, 150, "#5fe0d0", 0.28)
	d.poly([(590, 236), (672, 236), (720, 420), (548, 420)], "#9ff6ec", opacity=0.06)
	glow(d, 890, 330, 260, LANTERN, 0.32)
	glow(d, 895, 346, 46, LANTERN_HOT, 0.75)
	d.ellipse(895, 346, 4, 9, "#ffffff", opacity=0.9)
	floor_reflect(d, 860, 540, 220, 40, LANTERN, 0.18)
	vignette(d, 0.6, "#03050f")


def bg_ship_tumble_cabin(d):
	rng = random.Random(701)
	cabin_room(d, rng, "tumble")
	light_wash(d, "#fff2d8", 0.14, 0, 360)
	glow(d, 640, 330, 520, "#fff4e0", 0.1)
	vignette(d, 0.42, "#0a0604")


# --------------------------------------------------------------------------------------
# SHIP_INFIRMARY / SHIP_INFIRMARY_BODY
# --------------------------------------------------------------------------------------

def anchor_doorstop(d, cx, base, s=1.0):
	"""Heavy brass anchor doorstop standing on the floor; base = floor y."""
	with G(d, transform=T(cx, base, s)):
		d.ellipse(0, 0, 26, 5, "#000000", opacity=0.35)
		g = d.lin(-20, 0, 20, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)])
		d.path("M-24 -18 Q-22 -2 0 -2 Q22 -2 24 -18 L30 -14 L24 -30 L14 -20 L18 -18 Q14 -10 4 -10 L4 -44 L14 -44 L14 -50 L4 -50 L4 -54 "
			"L-4 -54 L-4 -50 L-14 -50 L-14 -44 L-4 -44 L-4 -10 Q-14 -10 -18 -18 L-14 -20 L-24 -30 L-30 -14 Z", g, stroke=INK, stroke_width=2,
			stroke_linejoin="round")
		d.circle(0, -60, 7, "none", stroke=INK, stroke_width=5.5)
		d.circle(0, -60, 7, "none", stroke=BRASS, stroke_width=3)
		d.rect(-12, -2, 24, 3, BRASS_D)
		d.spath("M-1 -48 L-1 -14", "#fff2b8", 1.4, opacity=0.8)


def marigold_down(d):
	"""Marigold lying face-down on the floor beside the cot (cartoon, non-graphic). Fits rect [440,440,380,140]."""
	fur, fur_d, fur_l = MARI_FUR, MARI_SH, MARI_L
	ow = 2.4
	d.ellipse(636, 560, 190, 20, "#000000", opacity=0.28)
	# far arm, reaching forward past her head
	d.path(smooth([(590, 486), (560, 470), (520, 462), (482, 460), (480, 472), (520, 476), (560, 484), (584, 500)]), fur, stroke=INK, stroke_width=ow)
	d.path(smooth([(600, 482), (580, 470), (562, 470), (560, 486), (578, 496), (598, 498)]), SCRUB, stroke=INK, stroke_width=ow)
	d.ellipse(470, 466, 13, 8.5, fur_l, stroke=INK, stroke_width=ow)
	d.spath("M462 462 l-2 5 M468 460 l-1 6 M474 460 l0 6", fur_d, 1.4)
	# stethoscope slipped off onto the floor
	d.spath("M552 520 Q540 552 568 566 Q600 578 612 566", INK, 6)
	d.spath("M552 520 Q540 552 568 566 Q600 578 612 566", "#4b5660", 3.4)
	d.circle(618, 562, 9, d.brad([(0, "#ffffff"), (0.6, "#c4ccd4"), (1, "#7d8794")], cx=0.35, cy=0.35, r=0.7), stroke=INK, stroke_width=2)
	d.circle(618, 562, 4, "#9aa5b0")
	# head (face down, snout to the floor), round back of the head + ears
	head = smooth([(470, 530), (472, 504), (488, 480), (516, 468), (548, 472), (566, 492), (566, 520), (552, 540), (520, 548), (488, 546)])
	d.path(head, d.lin(510, 466, 510, 548, [(0, fur_l), (0.5, fur), (1, fur_d)]), stroke=INK, stroke_width=ow)
	d.path("M490 488 Q512 474 538 476 Q514 482 500 496 Z", "#ffffff", opacity=0.3)
	for (ex, ey, rot) in ((530, 468, -20), (556, 478, 25)):
		with G(d, transform=T(ex, ey, 1, rot)):
			d.ellipse(0, 0, 10, 8, fur, stroke=INK, stroke_width=ow)
			d.ellipse(0, 1, 5, 4, "#a35a32")
	d.path("M472 528 Q480 544 498 548 L484 552 Q468 546 466 532 Z", fur_d, opacity=0.6)
	# scrubs top (rounded back)
	top = smooth([(552, 506), (566, 482), (604, 466), (652, 462), (698, 470), (714, 498), (704, 538), (650, 560), (588, 558), (556, 540)])
	d.path(top, d.lin(630, 462, 630, 560, [(0, SCRUB_L), (0.45, SCRUB), (1, SCRUB_D)]), stroke=INK, stroke_width=ow)
	d.path("M600 474 Q640 464 680 470 Q646 474 616 486 Z", "#ffffff", opacity=0.35)
	d.spath("M560 498 Q572 510 568 526", "#5ea6cc", 5)
	d.spath("M640 470 Q648 512 640 556", SCRUB_D, 1.6, opacity=0.6)
	# scrub trousers + feet (soles up)
	legs = smooth([(694, 478), (742, 484), (788, 500), (798, 520), (790, 548), (744, 558), (700, 552)])
	d.path(legs, d.lin(740, 480, 740, 558, [(0, SCRUB_L), (0.5, SCRUB), (1, SCRUB_D)]), stroke=INK, stroke_width=ow)
	d.spath("M708 516 Q752 516 794 524", SCRUB_D, 1.8)
	d.spath("M698 476 Q712 516 700 552", "#5ea6cc", 4)
	for (fx, fy, rot) in ((804, 510, -10), (800, 544, 12)):
		with G(d, transform=T(fx, fy, 1, rot)):
			d.ellipse(0, 0, 15, 10, fur, stroke=INK, stroke_width=ow)
			d.ellipse(2, 0, 7, 5, fur_l)
			for k in (-1, 0, 1):
				d.circle(10, k * 5, 2.2, fur_l)
	# near arm lying along her side
	d.path(smooth([(600, 540), (590, 556), (574, 566), (552, 568), (548, 558), (570, 552), (586, 538)]), fur, stroke=INK, stroke_width=ow)
	d.path(smooth([(612, 534), (604, 554), (590, 556), (588, 540), (600, 530)]), SCRUB, stroke=INK, stroke_width=ow)
	d.ellipse(546, 564, 11, 7.5, fur_l, stroke=INK, stroke_width=ow)
	# nurse cap (green cross) fallen off beside her head
	with G(d, transform=T(486, 566, 1, -14)):
		d.ellipse(0, 9, 26, 5, "#000000", opacity=0.25)
		cap = "M-24 8 L-18 -14 Q0 -20 18 -14 L24 8 Q0 13 -24 8 Z"
		d.path(cap, "#fbfbf8", stroke=INK, stroke_width=2.2)
		d.spath("M-21 -2 Q0 4 21 -2", INK, 1.6)
		d.path("M-3 -16 L3 -16 L3 -12 L7 -12 L7 -7 L3 -7 L3 -3 L-3 -3 L-3 -7 L-7 -7 L-7 -12 L-3 -12 Z", "#2fb06c", stroke=INK, stroke_width=1.2)


def breakfast_tray(d):
	"""Breakfast tray dropped in the infirmary doorway (toast + spilled tea, no red)."""
	d.ellipse(924, 452, 44, 9, "#000000", opacity=0.3)
	with G(d, transform=T(922, 446, 1, 9)):
		d.ellipse(0, 0, 40, 12, "#9a6a3a", stroke=INK, stroke_width=2)
		d.ellipse(0, -1.5, 34, 9, "#c08a52")
	d.ellipse(896, 458, 18, 4, "#c8a068", opacity=0.7)
	with G(d, transform=T(904, 440, 1, -20)):
		d.rect(-11, -9, 22, 18, "#e8b066", rx=5, stroke=INK, stroke_width=1.6)
		d.rect(-8, -6, 16, 12, "#f6d6a0", rx=3)
	with G(d, transform=T(948, 452, 1, 30)):
		d.rect(-10, -8, 20, 16, "#e8b066", rx=5, stroke=INK, stroke_width=1.6)
		d.rect(-7, -5, 14, 10, "#f6d6a0", rx=3)
	with G(d, transform=T(934, 432, 1, 80)):
		d.path("M-9 -8 L9 -8 L7 8 L-7 8 Z", "#ffffff", stroke=INK, stroke_width=1.6)
		d.ellipse(0, -8, 9, 3, "#e2dccd", stroke=INK, stroke_width=1.2)
	d.ellipse(926, 436, 13, 4, "#ffffff", stroke=INK, stroke_width=1.4)


def infirmary_room(d, rng, body):
	pp = Persp(600, 241)
	P = pp.P
	bx0, by0, bx1, by1 = 320, 60, 870, 380
	wall, wall2 = ("#e6ece2", "#c9d4c8") if not body else ("#e8eeea", "#cdd8d2")
	pshell(d, pp, bx0, by0, bx1, by1, wall, wall2, "#c2cdc2", "#4a3a30", "#7a5236", "#4a3020")
	wood_panels(d, bx0, by0, bx1, 300, wall, step=48, line="#a8b4a8", a=0.45)
	wainscot(d, bx0, 300, bx1, by1, panels=False)
	for bx in (bx0, bx1):
		side_band(d, pp, bx, 300, by1, d.lin(0 if bx == bx0 else W, 0, bx, 0, [(0, dark(TEALP_D, 0.3)), (1, TEALP)]))
		side_line(d, pp, bx, 300, BRASS, 4)
	pbeams(d, pp, bx0, bx1, by0, (1.0, 1.6, 2.6), "#3a2a20", 12)
	pplanks(d, pp, bx0, bx1, by1, 14, "#2e1c10", a=0.45, rng=rng)
	# left wall: porthole + first-aid poster
	side_porthole(d, pp, bx0, 170, 1.65, 34, rng)
	q = [P(bx0, 120, 1.12), P(bx0, 120, 1.32), P(bx0, 250, 1.32), P(bx0, 250, 1.12)]
	d.poly(q, "#f6f2e6", stroke="#8a8a7a", stroke_width=1.5)
	c = P(bx0, 160, 1.22)
	d.path("M%s %s l0 -10 l8 0 l0 10 l10 0 l0 8 l-10 0 l0 10 l-8 0 l0 -10 l-10 0 l0 -8 Z" % F(c[0] - 4, c[1] - 4), "#2fb06c")
	glyphs(d, q[0][0] + 6, c[1] + 22, q[1][0] - q[0][0] - 12, 50, 4, "#5a5a6a", rng, 1.2)
	croc_cam(d, bx1 - 24, by0 + 34, 0.62, flip=True)
	# --- desk against the back wall (left) with the rounds log hanging above it
	DX0, DX1, DT = 332, 548, 267
	d.poly([P(DX0, DT, 1.0), P(DX1, DT, 1.0), P(DX1, DT, 1.12), P(DX0, DT, 1.12)], "#b07a48")
	df = [P(DX0, DT, 1.12), P(DX1, DT, 1.12), P(DX1, DT + 40, 1.12), P(DX0, DT + 40, 1.12)]
	d.poly(df, d.vlin(df[0][1], df[2][1], [(0, WOOD_L), (1, WOOD)]))
	for xx in (DX0 + 6, DX1 - 6):
		a0, a1 = P(xx, DT + 40, 1.11), P(xx, by1, 1.11)
		d.spath("M%s %s L%s %s" % F(a0[0], a0[1], a1[0], a1[1]), WOOD_D, 7, stroke_linecap="butt")
	for k in range(2):
		xa = DX0 + 16 + k * 104
		q = [P(xa, DT + 8, 1.12), P(xa + 88, DT + 8, 1.12), P(xa + 88, DT + 32, 1.12), P(xa, DT + 32, 1.12)]
		d.poly(q, "none", stroke=WOOD_D, stroke_width=1.6)
		c = P(xa + 44, DT + 20, 1.12)
		d.circle(c[0], c[1], 3, BRASS_L)
	for (x, w_, h_, c_) in ((498, 10, 34, "#2e6a8a"), (510, 9, 30, "#8a2e3a"), (520, 11, 36, "#3a6a3a"), (532, 8, 28, "#c8a040")):
		d.rect(x, DT - h_, w_, h_, c_, stroke="#2a1a10", stroke_width=1)
	d.rect(342, DT - 22, 22, 22, "#e8f0f0", rx=3, stroke="#7a8a8a", stroke_width=1.2, opacity=0.9)
	d.rect(342, DT - 26, 22, 5, "#8a9a9a", rx=2)
	# rounds log: clipboard on a nail above the desk
	d.circle(425, 150, 3, "#4a4a52")
	d.spath("M425 150 L413 162 M425 150 L437 162", "#5a5a62", 1.4)
	d.rect(394, 158, 64, 98, "#000000", opacity=0.2, rx=4)
	d.rect(390, 154, 64, 98, d.vlin(154, 252, [(0, "#a8784a"), (1, "#7a5230")]), rx=4, stroke=INK, stroke_width=2)
	d.rect(396, 166, 52, 80, "#fbfaf4", stroke="#a8a294", stroke_width=1)
	d.rect(410, 150, 24, 14, d.lin(410, 0, 434, 0, [(0, "#8a929c"), (0.5, "#e8ecf0"), (1, "#7a828c")]), rx=3, stroke=INK, stroke_width=1.4)
	d.path("M418 172 l4 0 l0 -4 l4 0 l0 4 l4 0 l0 4 l-4 0 l0 4 l-4 0 l0 -4 l-4 0 Z", "#2fb06c")
	glyphs(d, 400, 186, 44, 40, 4, "#3a4a5a", rng, 1.1)
	if body:
		d.spath("M404 236 Q414 232 420 238 Q428 246 444 240", "#2a3a7a", 2.6, opacity=0.8)
	else:
		d.spath("M402 236 L432 236", "#3a4a5a", 1.4)
	d.spath("M452 200 Q470 220 466 252", "#8a8a8a", 1)
	d.rect(462, 248, 3, 22, "#e8c040", stroke=INK, stroke_width=0.8)
	# --- medicine cabinet above the cot
	d.rect(646, 94, 156, 140, "#000000", opacity=0.2, rx=4)
	d.rect(640, 88, 156, 140, d.vlin(88, 228, [(0, "#fbfbf6"), (1, "#d8ddd6")]), rx=4, stroke="#8a948c", stroke_width=2)
	for x0 in (650, 722):
		d.rect(x0, 98, 64, 120, "#bfe0de", stroke="#8a948c", stroke_width=2, opacity=0.9)
		for (sy, cols) in ((140, ("#8a4a2a", "#2e6a8a", "#3a7a4a")), (192, ("#d8a040", "#7a3a6a", "#2e6a8a"))):
			for k, c_ in enumerate(cols):
				bx_ = x0 + 10 + k * 19
				d.rect(bx_, sy - 26, 13, 26, c_, rx=3, opacity=0.9)
				d.rect(bx_ + 3, sy - 32, 7, 7, "#f2f2ea")
			d.rect(x0 + 2, sy, 60, 3, "#8a948c")
		d.spath("M%s 108 L%s 150" % F(x0 + 10, x0 + 30), "#ffffff", 4, opacity=0.5)
	d.circle(716, 162, 3, BRASS)
	d.circle(724, 162, 3, BRASS)
	d.rect(700, 64, 32, 32, "#ffffff", rx=4, stroke="#8a948c", stroke_width=1.5)
	d.path("M711 68 l10 0 l0 9 l9 0 l0 10 l-9 0 l0 9 l-10 0 l0 -9 l-9 0 l0 -10 l9 0 Z", "#2fb06c")
	# --- cot against the back wall
	CX0, CX1, CS0, CS1, CM = 582, 868, 1.0, 1.06, 306
	frame = "#f2f2ec"
	for (xx, ss) in ((CX0 + 8, CS0), (CX1 - 8, CS0), (CX0 + 8, CS1), (CX1 - 8, CS1)):
		a0, a1 = P(xx, CM + 30, ss), P(xx, by1, ss)
		d.spath("M%s %s L%s %s" % F(a0[0], a0[1], a1[0], a1[1]), "#8a948c" if ss == CS0 else frame, 5, stroke_linecap="round")
	hr0, hr1 = P(CX0, 262, CS1), P(CX0, CM + 32, CS1)
	d.spath("M%s %s L%s %s" % F(hr0[0], hr0[1] + 6, hr1[0], hr1[1]), frame, 6)
	d.spath("M%s %s L%s %s" % F(hr0[0] + 14, hr0[1] + 6, hr0[0] + 14, hr1[1] - 6), frame, 4)
	d.spath("M%s %s Q%s %s %s %s" % F(hr0[0] - 4, hr0[1] + 8, hr0[0] + 7, hr0[1] - 4, hr0[0] + 18, hr0[1] + 8), frame, 6)
	d.ellipse(CX0 + 40, CM - 12, 44, 15, d.vlin(CM - 26, CM + 2, [(0, "#ffffff"), (1, "#dde2dc")]), stroke="#9aa49c", stroke_width=1.6)
	mt = [P(CX0 + 6, CM, CS0), P(CX1 - 6, CM, CS0), P(CX1 - 6, CM, CS1), P(CX0 + 6, CM, CS1)]
	d.poly(mt, "#f8f8f2")
	mf = [P(CX0 + 6, CM, CS1), P(CX1 - 6, CM, CS1), P(CX1 - 6, CM + 26, CS1), P(CX0 + 6, CM + 26, CS1)]
	d.poly(mf, d.vlin(mf[0][1], mf[2][1], [(0, "#ffffff"), (1, "#d6dcd6")]))
	dd = ""
	for k in range(1, 15):
		xx = CX0 + 6 + (CX1 - CX0 - 12) * k / 15
		a0, a1 = P(xx, CM + 4, CS1), P(xx, CM + 26, CS1)
		dd += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
	d.spath(dd, "#a8c8e0", 1.6, opacity=0.7)
	rail = [P(CX0, CM + 26, CS1), P(CX1, CM + 26, CS1), P(CX1, CM + 34, CS1), P(CX0, CM + 34, CS1)]
	d.poly(rail, frame, stroke="#8a948c", stroke_width=1.2)
	if body:
		d.path(smooth([(762, 304), (800, 296), (852, 300), (856, 318), (840, 334), (790, 336), (766, 326)]), SCRUB_L, stroke="#7aa8c8", stroke_width=1.6)
		d.spath("M772 318 Q810 312 850 318", "#7aa8c8", 1.4)
		d.path("M650 302 Q700 296 742 304", "none", stroke="#c8ccc4", stroke_width=1.4)
		# the lilac silk scrap left on the cot
		d.path("M714 300 L742 296 L732 312 Z", LILAC, stroke=LILAC_D, stroke_width=1.6, stroke_linejoin="round")
		d.spath("M718 300 L736 298", "#ffffff", 1.2, opacity=0.6)
		sparkle(d, 744, 292, 7, "#ffffff", 0.9)
	else:
		d.poly([P(780, CM - 4, CS0), P(CX1 - 8, CM - 4, CS0), P(CX1 - 8, CM - 4, CS1), P(780, CM - 4, CS1)], SCRUB_L)
		fb = [P(780, CM - 4, CS1), P(CX1 - 8, CM - 4, CS1), P(CX1 - 8, CM + 14, CS1), P(780, CM + 14, CS1)]
		d.poly(fb, SCRUB, stroke="#7aa8c8", stroke_width=1.2)
	fr0, fr1 = P(CX1, 272, CS1), P(CX1, CM + 32, CS1)
	d.spath("M%s %s L%s %s" % F(fr0[0], fr0[1], fr1[0], fr1[1]), frame, 6)
	d.spath("M%s %s L%s %s" % F(fr0[0] - 14, fr0[1] + 6, fr0[0] - 14, fr1[1] - 6), frame, 4)
	d.spath("M%s %s Q%s %s %s %s" % F(fr0[0] - 20, fr0[1] + 6, fr0[0] - 8, fr0[1] - 6, fr0[0] + 4, fr0[1] + 4), frame, 6)
	# --- door on the right wall (hinged at the near edge, opening out to the corridor)
	S_A, S_B, DY0 = 1.0556, 1.352, 178.5
	opening = [P(bx1, DY0, S_A), P(bx1, DY0, S_B), P(bx1, by1, S_B), P(bx1, by1, S_A)]
	fr = [P(bx1, DY0 - 10, S_A - 0.02), P(bx1, DY0 - 10, S_B + 0.03), P(bx1, by1, S_B + 0.03), P(bx1, by1, S_A - 0.02)]
	d.poly(fr, WOOD_DD)
	d.poly(opening, d.vlin(opening[1][1], opening[2][1], [(0, "#3a2416"), (0.75, "#5a3a22"), (1, "#2a1a10")]))
	glow(d, (opening[0][0] + opening[1][0]) / 2, 250, 50, LANTERN, 0.45)
	d.poly([opening[3], opening[2], (opening[2][0], opening[2][1] - 18), (opening[3][0], opening[3][1] - 12)], "#6a4428")
	hinge_top, hinge_bot = opening[1], opening[2]
	open_frac = 0.4 if not body else 0.6
	fx_top = (hinge_top[0] + (opening[0][0] - hinge_top[0]) * open_frac, hinge_top[1] + (opening[0][1] - hinge_top[1]) * open_frac + 4)
	fx_bot = (hinge_bot[0] + (opening[3][0] - hinge_bot[0]) * open_frac, hinge_bot[1] + (opening[3][1] - hinge_bot[1]) * open_frac - 6)
	leaf = [hinge_top, fx_top, fx_bot, hinge_bot]
	d.poly(leaf, d.lin(fx_top[0], 0, hinge_top[0], 0, [(0, "#8a5434"), (1, "#5a3420")]), stroke=WOOD_DD, stroke_width=1.6)
	pm = [(fx_top[0] * 0.75 + hinge_top[0] * 0.25, fx_top[1] * 0.75 + hinge_top[1] * 0.25 + 30), (fx_top[0] * 0.25 + hinge_top[0] * 0.75, fx_top[1] * 0.25 + hinge_top[1] * 0.75 + 30)]
	d.spath("M%s %s L%s %s" % F(pm[0][0], pm[0][1], pm[1][0], pm[1][1]), "#4a2a16", 2, opacity=0.6)
	kx = fx_top[0] + (hinge_top[0] - fx_top[0]) * 0.18
	ky = (fx_top[1] + fx_bot[1]) / 2 + 10
	d.circle(kx, ky, 4, BRASS_L, stroke=INK, stroke_width=1)
	if not body:
		glow(d, fx_bot[0] + 8, fx_bot[1] - 18, 40, LANTERN, 0.35)
		anchor_doorstop(d, fx_bot[0] + 8, fx_bot[1] + 14, 0.8)
		sparkle(d, fx_bot[0] + 22, fx_bot[1] - 40, 8, "#ffffff", 0.9)
	# --- low stool with the spirit burner + kettle (front left)
	SX0, SX1, SS0, SS1, ST = 512, 556, 2.18, 2.38, 318
	for (xx, ss) in ((SX0 + 3, SS0), (SX1 - 3, SS0), (SX0 + 3, SS1), (SX1 - 3, SS1)):
		a0, a1 = P(xx, ST, ss), P(xx, by1, ss)
		d.spath("M%s %s L%s %s" % F(a0[0], a0[1], a1[0], a1[1]), WOOD_D if ss == SS0 else WOOD, 7, stroke_linecap="butt")
	sb = [P(SX0, ST + 30, SS1), P(SX1, ST + 30, SS1)]
	d.spath("M%s %s L%s %s" % F(sb[0][0], sb[0][1], sb[1][0], sb[1][1]), WOOD_D, 5)
	stool_top = [P(SX0 - 4, ST, SS0), P(SX1 + 4, ST, SS0), P(SX1 + 4, ST, SS1), P(SX0 - 4, ST, SS1)]
	d.poly(stool_top, WOOD_L, stroke=WOOD_D, stroke_width=1.6)
	sf = [P(SX0 - 4, ST, SS1), P(SX1 + 4, ST, SS1), P(SX1 + 4, ST + 6, SS1), P(SX0 - 4, ST + 6, SS1)]
	d.poly(sf, WOOD)
	cx = (stool_top[0][0] + stool_top[2][0]) / 2
	cy = (stool_top[0][1] + stool_top[2][1]) / 2
	# burner
	d.rect(cx - 24, cy - 18, 48, 16, d.lin(cx - 24, 0, cx + 24, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)]), rx=3, stroke=INK, stroke_width=1.6)
	d.ellipse(cx, cy - 2, 24, 5, BRASS_D, stroke=INK, stroke_width=1.4)
	d.rect(cx - 30, cy - 24, 60, 6, "#3a3a40", rx=2, stroke=INK, stroke_width=1.2)
	if not body:
		glow(d, cx, cy - 30, 40, "#7ab8ff", 0.5)
		d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(cx - 7, cy - 22, cx - 4, cy - 34, cx, cy - 38, cx + 4, cy - 34, cx + 7, cy - 22), "#6ab0ff", opacity=0.9)
	# kettle
	kc = "#2e8a83" if not body else "#2a5a56"
	ky0 = cy - 26
	kbody = "M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(cx - 36, ky0, cx - 40, ky0 - 34, cx - 22, ky0 - 52, cx + 22, ky0 - 52,
		cx + 40, ky0 - 34, cx + 36, ky0, cx, ky0 + 4, cx - 36, ky0)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(cx - 30, ky0 - 22, cx - 62, ky0 - 46, cx - 58, ky0 - 52, cx - 26, ky0 - 34), dark(kc, 0.1), stroke=INK, stroke_width=1.8)
	d.path(kbody, d.lin(cx - 40, 0, cx + 40, 0, [(0, dark(kc, 0.2)), (0.35, light(kc, 0.35)), (1, dark(kc, 0.35))]), stroke=INK, stroke_width=2)
	d.ellipse(cx, ky0 - 50, 20, 5, dark(kc, 0.25), stroke=INK, stroke_width=1.6)
	d.circle(cx, ky0 - 56, 5, BRASS, stroke=INK, stroke_width=1.4)
	d.spath("M%s %s Q%s %s %s %s" % F(cx - 26, ky0 - 46, cx, ky0 - 86, cx + 26, ky0 - 46), INK, 6)
	d.spath("M%s %s Q%s %s %s %s" % F(cx - 26, ky0 - 46, cx, ky0 - 86, cx + 26, ky0 - 46), "#2a2a30", 3.4)
	d.ellipse(cx - 12, ky0 - 34, 8, 12, "#ffffff", opacity=0.35)
	if body:
		# scorched: blackened bottom + soot, a thin wisp of smoke
		cid = d.clip('<path d="%s"/>' % kbody)
		with G(d, clip_path=cid):
			d.rect(cx - 44, ky0 - 22, 88, 30, d.vlin(ky0 - 22, ky0 + 4, [(0, "#1a1410", 0), (0.5, "#1a1410", 0.7), (1, "#0a0806", 0.95)]))
		d.ellipse(cx, cy - 24, 40, 5, "#1a1410", opacity=0.5)
		d.spath("M%s %s q-8 -14 0 -26 q8 -12 -2 -26" % F(cx - 58, ky0 - 54), "#8a8a8a", 3, opacity=0.35)
	else:
		for (fx, fh) in ((-30, 10), (-18, 13), (18, 13), (30, 10)):
			d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(cx + fx - 4, ky0 + 2, cx + fx - 2, ky0 - fh * 0.5, cx + fx, ky0 - fh, cx + fx + 2, ky0 - fh * 0.5,
				cx + fx + 4, ky0 + 2), "#6ab0ff", opacity=0.85)
		steam_wisps(d, rng, cx - 66, ky0 - 56, cx - 54, ky0 - 52, 3, a=0.26, sw=(14, 22))
	# --- ceiling lamp (white enamel shade)
	d.line(600, 0, 600, 56, "#3a3a40", 2.2)
	glow(d, 600, 80, 300, LANTERN if not body else "#f4f8ff", 0.38 if not body else 0.28)
	d.path("M572 80 Q574 58 600 56 Q626 58 628 80 Z", "#f2f4ee", stroke="#8a948c", stroke_width=1.5)
	d.ellipse(600, 80, 28, 6, LANTERN_HOT if not body else "#ffffff")


def bg_ship_infirmary(d):
	rng = random.Random(801)
	infirmary_room(d, rng, body=False)
	d.rect(0, 0, W, H, "#3a2008", opacity=0.2)
	glow(d, 600, 90, 360, LANTERN, 0.3)
	side_c = (157, 152)
	glow(d, side_c[0], side_c[1], 70, "#5fe0d0", 0.3)
	light_wash(d, "#ffc878", 0.14, 0, 420)
	floor_reflect(d, 560, 520, 300, 60, LANTERN, 0.2)
	vignette(d, 0.5, "#0a0604")


def bg_ship_infirmary_body(d):
	rng = random.Random(801)
	infirmary_room(d, rng, body=True)
	marigold_down(d)
	breakfast_tray(d)
	light_wash(d, "#e8f4ff", 0.16, 0, 420)
	d.rect(0, 0, W, H, "#cfe0ea", opacity=0.08)
	vignette(d, 0.45, "#0a1014")


# --------------------------------------------------------------------------------------
# SHIP_PURSER - purser's office
# --------------------------------------------------------------------------------------

def dictaphone(d, cx, base, s=1.0, rng=None):
	"""Snapjaw 'Echo-Matic' wax-cylinder dictaphone: wooden case, brass horn, empty mandrel, REPEAT lever,
	crank, four little round brass feet. (cx, base) = centre of the case bottom / desk contact."""
	def X(v):
		return cx + v * s

	def Y(v):
		return base - v * s
	d.ellipse(cx, base + 2 * s, 66 * s, 7 * s, "#000000", opacity=0.35)
	# four little round feet (back pair peeks out behind the case corners)
	for (fx, fy, r) in ((-50, 6, 6), (50, 6, 6), (-42, 2, 7.5), (42, 2, 7.5)):
		d.circle(X(fx), Y(fy), r * s, d.brad([(0, BRASS_L), (0.6, BRASS), (1, BRASS_D)], cx=0.35, cy=0.35, r=0.7), stroke=INK, stroke_width=1.6 * s)
	# case: front + top face
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(X(-54), Y(56), X(54), Y(56), X(48), Y(66), X(-48), Y(66)), "#b8743e", stroke=INK, stroke_width=2 * s)
	d.rect(X(-54), Y(56), 108 * s, 50 * s, d.vlin(Y(56), Y(6), [(0, "#a8622e"), (1, "#6e3a1a")]), stroke=INK, stroke_width=2.2 * s)
	d.rect(X(-48), Y(50), 96 * s, 38 * s, "none", stroke="#4a2410", stroke_width=1.4 * s, opacity=0.7)
	d.rect(X(-54), Y(14), 108 * s, 6 * s, BRASS_D)
	# Snapjaw crest plaque on the front
	d.rect(X(-13), Y(46), 26 * s, 26 * s, BRASS, rx=4 * s, stroke=INK, stroke_width=1.2 * s)
	snapjaw_crest(d, X(0), Y(33), 0.2 * s, ring=True)
	# empty brass mandrel on top (no cylinder inside)
	d.rect(X(-34), Y(76), 64 * s, 6 * s, d.vlin(Y(76), Y(70), [(0, BRASS_L), (1, BRASS_D)]), rx=3 * s, stroke=INK, stroke_width=1.2 * s)
	d.rect(X(-40), Y(80), 8 * s, 16 * s, BRASS_D, stroke=INK, stroke_width=1.2 * s)
	d.rect(X(28), Y(80), 8 * s, 16 * s, BRASS_D, stroke=INK, stroke_width=1.2 * s)
	# REPEAT lever (switched ON) with a red knob
	d.rect(X(36), Y(70), 14 * s, 6 * s, "#3a2a1a", rx=2 * s)
	d.spath("M%s %s L%s %s" % F(X(42), Y(68), X(58), Y(88)), INK, 5 * s)
	d.spath("M%s %s L%s %s" % F(X(42), Y(68), X(58), Y(88)), "#c9ccd2", 2.6 * s)
	d.circle(X(59), Y(90), 6 * s, "#e0302a", stroke=INK, stroke_width=1.6 * s)
	d.circle(X(57), Y(92), 2 * s, "#ffb0a8")
	# crank on the right side
	d.spath("M%s %s L%s %s L%s %s" % F(X(54), Y(34), X(70), Y(34), X(72), Y(18)), INK, 5 * s)
	d.spath("M%s %s L%s %s L%s %s" % F(X(54), Y(34), X(70), Y(34), X(72), Y(18)), "#c9ccd2", 2.6 * s)
	d.rect(X(68), Y(22), 8 * s, 12 * s, "#2a1a10", rx=3 * s)
	# brass horn: neck rising from the case, flaring into a bell that points up-left
	neck = "M%s %s Q%s %s %s %s" % F(X(-20), Y(64), X(-26), Y(92), X(-56), Y(72))
	d.spath(neck, INK, 12 * s)
	d.spath(neck, BRASS, 8 * s)
	d.spath(neck, BRASS_L, 2.4 * s, opacity=0.8)
	bell = "M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % F(X(-52), Y(63), X(-72), Y(58), X(-106), Y(48), X(-66), Y(96), X(-64), Y(80), X(-60), Y(77))
	d.path(bell, d.lin(X(-106), Y(48), X(-56), Y(90), [(0, BRASS_D), (0.5, BRASS_L), (1, BRASS)]), stroke=INK, stroke_width=2 * s)
	with G(d, transform=T(X(-86), Y(72), 1, -50)):
		d.ellipse(0, 0, 31 * s, 11 * s, d.lin(-30 * s, 0, 30 * s, 0, [(0, BRASS_D), (0.5, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=2 * s)
		d.ellipse(0, 1.5 * s, 23 * s, 7 * s, d.rad(0, 3 * s, 24 * s, [(0, "#1a1008"), (0.7, "#4a3010"), (1, BRASS_D)]))
	d.spath("M%s %s Q%s %s %s %s" % F(X(-96), Y(54), X(-78), Y(62), X(-62), Y(68)), "#fff6cc", 1.8 * s, opacity=0.7)


def bg_ship_purser(d):
	rng = random.Random(901)
	pp = Persp(620, 240)
	P = pp.P
	bx0, by0, bx1, by1 = 330, 60, 960, 490
	pshell(d, pp, bx0, by0, bx1, by1, "#9a6a44", "#7a4e30", "#7a5032", "#3a2414", "#6a4228", "#3a2414")
	wood_panels(d, bx0, by0, bx1, 380, "#946440", step=70, a=0.4)
	wainscot(d, bx0, 380, bx1, by1)
	for bx in (bx0, bx1):
		side_band(d, pp, bx, 380, by1, d.lin(0 if bx == bx0 else W, 0, bx, 0, [(0, dark(TEALP_D, 0.3)), (1, TEALP)]))
		side_line(d, pp, bx, 380, BRASS, 4)
	pbeams(d, pp, bx0, bx1, by0, (1.0, 1.5, 2.3), "#24150c", 12)
	pplanks(d, pp, bx0, bx1, by1, 14, "#24140a", a=0.5, rng=rng)
	# left wall: porthole + framed lake chart; right wall: door (dim, calm)
	side_porthole(d, pp, bx0, 190, 1.55, 30, rng)
	q = [P(bx0, 130, 1.12), P(bx0, 130, 1.36), P(bx0, 260, 1.36), P(bx0, 260, 1.12)]
	d.poly(q, "#3a2414")
	q2 = [P(bx0, 138, 1.14), P(bx0, 138, 1.34), P(bx0, 252, 1.34), P(bx0, 252, 1.14)]
	d.poly(q2, "#e8dcb8")
	c = P(bx0, 195, 1.24)
	d.ellipse(c[0], c[1], 14, 30, "#7ab0b0", opacity=0.6)
	d.spath("M%s %s q6 10 0 20 q-6 10 2 22" % F(c[0], c[1] - 26), "#3a5a5a", 1.2)
	dq = [P(bx1, 150, 1.3), P(bx1, 150, 1.8), P(bx1, by1, 1.8), P(bx1, by1, 1.3)]
	d.poly(dq, "#3a2210")
	dq2 = [P(bx1, 160, 1.34), P(bx1, 160, 1.76), P(bx1, by1, 1.76), P(bx1, by1, 1.34)]
	d.poly(dq2, d.lin(dq2[0][0], 0, dq2[1][0], 0, [(0, "#5a321a"), (1, "#4a2a16")]))
	croc_cam(d, bx0 + 22, by0 + 36, 0.62)
	# --- cylinder rack on the wall (one slot empty)
	RX0, RY0 = 378, 136
	d.rect(RX0 + 4, RY0 + 4, 152, 200, "#000000", opacity=0.25, rx=4)
	d.rect(RX0, RY0, 152, 200, d.vlin(RY0, RY0 + 200, [(0, "#6e4022"), (1, "#4a2a14")]), rx=4, stroke=INK, stroke_width=2)
	d.rect(RX0 + 6, RY0 + 28, 140, 166, "#2a170a")
	empty = (0, 3)
	for r in range(3):
		sy = RY0 + 82 + r * 56
		d.rect(RX0 + 4, sy, 144, 9, d.vlin(sy, sy + 9, [(0, WOOD_L), (1, WOOD_D)]))
		for c in range(5):
			x = RX0 + 20 + c * 28
			if (r, c) == empty:
				d.ellipse(x, sy + 1, 10, 3.5, "#120a04", stroke=WOOD_D, stroke_width=1.4)
				continue
			d.rect(x - 9, sy - 40, 18, 40, d.lin(x - 9, 0, x + 9, 0, [(0, "#8a5a2a"), (0.4, "#d8a868"), (1, "#7a4a22")]), rx=2)
			d.rect(x - 10, sy - 46, 20, 8, d.lin(x - 10, 0, x + 10, 0, [(0, BRASS_D), (0.4, BRASS_L), (1, BRASS_D)]), rx=2, stroke=INK, stroke_width=0.8)
			d.ellipse(x, sy - 46, 10, 2.5, BRASS_L)
			d.rect(x - 7, sy - 28, 14, 10, "#f2e8cc", opacity=0.85)
	d.rect(RX0 + 46, RY0 + 7, 60, 16, BRASS, rx=3, stroke=INK, stroke_width=1)
	glyphs(d, RX0 + 51, RY0 + 10, 50, 10, 1, "#4a3010", rng, 1.1)
	# --- pigeonholes behind the desk + ship's clock
	d.rect(590, 128, 180, 156, "#3a2010", rx=3)
	for r in range(3):
		for c in range(4):
			x = 598 + c * 43
			y = 136 + r * 48
			d.rect(x, y, 38, 42, "#1e1008")
			if (r * 4 + c) % 3 != 2:
				for k in range(rng.randint(1, 3)):
					d.rect(x + 3 + k * 3, y + 14 + k * 4, 30, 24 - k * 4, ("#f2ead6", "#e8d8b0", "#d8e2ea")[k], stroke="#a89c80", stroke_width=0.8)
	d.circle(866, 196, 32, d.lin(834, 164, 898, 228, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=1.6)
	d.circle(866, 196, 24, "#fbf6e8")
	dd = ""
	for k in range(12):
		a = k * TAU / 12
		dd += "M%s %s L%s %s " % F(866 + math.cos(a) * 19, 196 + math.sin(a) * 19, 866 + math.cos(a) * 22, 196 + math.sin(a) * 22)
	d.spath(dd, "#3a2a1a", 1.6)
	d.spath("M866 196 L866 180 M866 196 L878 202", "#1a1008", 2.2)
	ship_lamp(d, 690, 96, 0.7, hang_from=60, glow_a=0.45, glow_r=220)
	# --- the safe (back wall, right)
	SX0, SX1, SY0, SS1 = 800, 908, 340, 1.06
	side = [P(SX0, SY0, 1.0), P(SX0, SY0, SS1), P(SX0, by1, SS1), P(SX0, by1, 1.0)]
	d.poly(side, IRON_D)
	topq = [P(SX0, SY0, 1.0), P(SX1, SY0, 1.0), P(SX1, SY0, SS1), P(SX0, SY0, SS1)]
	d.poly(topq, IRON_L)
	fq = [P(SX0, SY0, SS1), P(SX1, SY0, SS1), P(SX1, by1, SS1), P(SX0, by1, SS1)]
	d.poly(fq, d.lin(fq[0][0], fq[0][1], fq[2][0], fq[2][1], [(0, "#4f5660"), (0.5, "#383d46"), (1, "#24272d")]), stroke=INK, stroke_width=2)
	fx0, fy0, fx1, fy1 = fq[0][0], fq[0][1], fq[2][0], fq[2][1]
	d.rect(fx0 + 10, fy0 + 12, fx1 - fx0 - 20, fy1 - fy0 - 30, "none", stroke=BRASS_D, stroke_width=2.4)
	rivet_row(d, fx0 + 6, fy0 + 6, fx1 - 6, fy0 + 6, 6, 2.2)
	rivet_row(d, fx0 + 6, fy1 - 8, fx1 - 6, fy1 - 8, 6, 2.2)
	cxs, cys = (fx0 + fx1) / 2 - 8, fy0 + 70
	d.circle(cxs, cys, 24, d.lin(cxs - 24, cys - 24, cxs + 24, cys + 24, [(0, BRASS_L), (1, BRASS_D)]), stroke=INK, stroke_width=1.6)
	d.circle(cxs, cys, 15, "#2a2d33")
	dd = ""
	for k in range(16):
		a = k * TAU / 16
		dd += "M%s %s L%s %s " % F(cxs + math.cos(a) * 17, cys + math.sin(a) * 17, cxs + math.cos(a) * 21, cys + math.sin(a) * 21)
	d.spath(dd, "#4a3010", 1.2)
	d.circle(cxs, cys, 5, BRASS)
	d.spath("M%s %s L%s %s" % F(fx1 - 22, cys + 20, fx1 - 22, cys + 60), BRASS, 6)
	d.circle(fx1 - 22, cys + 20, 5, BRASS_L)
	crest_plate(d, cxs, fy1 - 54, 0.42)
	# --- desk + the Echo-Matic on it
	DX0, DX1, DT, D0, D1 = 592, 740, 363, 1.18, 1.42
	floor_reflect(d, 666, 575, 200, 26, "#000000", 0.4)
	dtop = [P(DX0, DT, D0), P(DX1, DT, D0), P(DX1, DT, D1), P(DX0, DT, D1)]
	dsideR = [P(DX1, DT, D0), P(DX1, DT, D1), P(DX1, by1, D1), P(DX1, by1, D0)]
	d.poly(dsideR, "#3e2412")
	dfront = [P(DX0, DT, D1), P(DX1, DT, D1), P(DX1, by1, D1), P(DX0, by1, D1)]
	d.poly(dfront, d.vlin(dfront[0][1], dfront[2][1], [(0, "#7a4a2a"), (1, "#4a2a16")]), stroke=WOOD_DD, stroke_width=1.6)
	fx0, fy0, fx1, fy1 = dfront[0][0], dfront[0][1], dfront[2][0], dfront[2][1]
	for k in range(3):
		yy = fy0 + 14 + k * 46
		d.rect(fx0 + 12, yy, 64, 38, "none", stroke=WOOD_DD, stroke_width=2)
		d.rect(fx0 + 38, yy + 16, 12, 5, BRASS, rx=2)
	d.rect(fx0 + 92, fy0 + 14, fx1 - fx0 - 104, fy1 - fy0 - 30, "none", stroke=WOOD_DD, stroke_width=2)
	d.poly(dtop, d.vlin(dtop[0][1], dtop[2][1], [(0, "#8a5634"), (1, "#a8693e")]))
	d.poly([P(DX0 + 8, DT, D0 + 0.03), P(DX1 - 8, DT, D0 + 0.03), P(DX1 - 8, DT, D1 - 0.04), P(DX0 + 8, DT, D1 - 0.04)], "#2e5a46", opacity=0.85)
	d.spath("M%s %s L%s %s" % F(dtop[3][0], dtop[3][1], dtop[2][0], dtop[2][1]), WOOD_L, 2.4)
	# ledger + inkwell at the desk's left end
	lg = P(DX0 + 22, DT, 1.36)
	d.rect(lg[0] - 18, lg[1] - 10, 30, 8, "#6a2a2a", rx=1, stroke=INK, stroke_width=1)
	d.rect(lg[0] - 16, lg[1] - 16, 26, 7, "#2a4a6a", rx=1, stroke=INK, stroke_width=1)
	dc = P(672, DT, 1.3)
	dictaphone(d, dc[0], dc[1], 1.0, rng)
	# --- worn leather armchair (left)
	fl = P(460, by1, 1.38)
	d.ellipse(fl[0], fl[1] + 2, 86, 10, "#000000", opacity=0.35)
	leather, leather_d, leather_l = "#7a2c26", "#4e1a16", "#a8483a"
	d.path("M394 444 Q400 422 430 424 Q460 416 490 424 Q522 422 526 444 L526 512 L394 512 Z", d.vlin(420, 512, [(0, leather_l), (1, leather)]), stroke=INK, stroke_width=2)
	d.path("M410 450 Q460 436 510 450 L510 506 L410 506 Z", leather_d, opacity=0.35)
	# seat cushion
	d.path("M398 506 Q460 496 522 506 L528 530 Q460 540 392 530 Z", d.vlin(496, 540, [(0, leather_l), (1, leather)]), stroke=INK, stroke_width=2)
	d.path("M430 512 Q460 520 494 512", "none", stroke=leather_d, stroke_width=2, opacity=0.7)
	# arms
	for (x0, k) in ((386, -1), (510, 1)):
		d.path("M%s %s Q%s %s %s %s L%s %s L%s %s Z" % F(x0, 548, x0 - k * 2, 488, x0 + 14, 486, x0 + 30 - (0 if k < 0 else 4), 548, x0, 548),
			d.lin(x0, 0, x0 + 30, 0, [(0, leather_d), (0.5, leather_l), (1, leather)]), stroke=INK, stroke_width=2)
		d.ellipse(x0 + 14, 488, 16, 7, leather_l, stroke=INK, stroke_width=1.6)
	d.rect(392, 530, 136, 30, d.vlin(530, 560, [(0, leather), (1, leather_d)]), stroke=INK, stroke_width=2)
	dd = ""
	for k in range(12):
		dd += "M%s 535 l0.1 0 " % fm(400 + k * 11.0)
	d.spath(dd, BRASS_L, 3.2)
	for x in (400, 516):
		d.rect(x, 560, 8, 22, WOOD_DD, rx=2)
	# knitted throw over the arm
	d.path("M506 482 Q530 478 540 494 L536 560 Q522 566 510 556 L512 500 Z", "#d8a640", stroke=INK, stroke_width=1.6)
	dd = ""
	for k in range(6):
		dd += "M%s %s l14 0 " % F(514, 504 + k * 9)
	d.spath(dd, "#a87a20", 1.4)
	light_wash(d, "#ffcf8a", 0.12, 0, 360)
	vignette(d, 0.5, "#0a0604")


# --------------------------------------------------------------------------------------
# SHIP_BOILER - boiler room
# --------------------------------------------------------------------------------------

def iron_wall(d, x0, y0, x1, y1, rng, color="#3e4249", plate=(120, 90)):
	d.rect(x0, y0, x1 - x0, y1 - y0, d.vlin(y0, y1, [(0, light(color, 0.05)), (1, dark(color, 0.25))]))
	pw, ph = plate
	y = y0
	while y < y1:
		x = x0
		while x < x1:
			d.rect(x + 2, y + 2, min(pw, x1 - x) - 4, min(ph, y1 - y) - 4, "none", stroke="#1e2024", stroke_width=2, opacity=0.6)
			d.rect(x + 4, y + 4, min(pw, x1 - x) - 8, 2, "#7a808a", opacity=0.25)
			for (rx_, ry_) in ((x + 8, y + 8), (x + pw - 8, y + 8), (x + 8, y + ph - 8), (x + pw - 8, y + ph - 8)):
				if rx_ < x1 and ry_ < y1:
					d.circle(rx_, ry_, 2.2, "#8a909a", opacity=0.8)
			x += pw
		y += ph
	dd = ""
	for _ in range(30):
		x = rng.uniform(x0, x1)
		dd += "M%s %s l%s %s " % F(x, rng.uniform(y0, y1 - 40), rng.uniform(-2, 2), rng.uniform(20, 60))
	d.spath(dd, "#6a4a2a", 2, opacity=0.25)


def gauge(d, cx, cy, r, needle=0.3, rng=None):
	d.circle(cx + 2, cy + 3, r + 2, "#000000", opacity=0.35)
	d.circle(cx, cy, r, d.lin(cx - r, cy - r, cx + r, cy + r, [(0, BRASS_L), (0.5, BRASS), (1, BRASS_D)]), stroke=INK, stroke_width=1.8)
	d.circle(cx, cy, r * 0.78, "#fbf6e6", stroke=BRASS_D, stroke_width=1.2)
	d.path("M%s %s A%s %s 0 0 1 %s %s L%s %s Z" % F(cx + math.cos(-0.5) * r * 0.74, cy + math.sin(-0.5) * r * 0.74, r * 0.74, r * 0.74,
		cx + math.cos(0.4) * r * 0.74, cy + math.sin(0.4) * r * 0.74, cx, cy), "#e0302a", opacity=0.75)
	dd = ""
	for k in range(9):
		a = math.pi * 0.8 + k * (math.pi * 1.4) / 8
		dd += "M%s %s L%s %s " % F(cx + math.cos(a) * r * 0.62, cy + math.sin(a) * r * 0.62, cx + math.cos(a) * r * 0.74, cy + math.sin(a) * r * 0.74)
	d.spath(dd, "#3a2a1a", max(1.0, r * 0.05))
	a = math.pi * 0.8 + needle * math.pi * 1.4
	d.spath("M%s %s L%s %s" % F(cx, cy, cx + math.cos(a) * r * 0.66, cy + math.sin(a) * r * 0.66), "#1a1008", max(1.4, r * 0.08))
	d.circle(cx, cy, r * 0.1, "#1a1008")
	d.path("M%s %s A%s %s 0 0 1 %s %s" % F(cx - r * 0.6, cy - r * 0.4, r * 0.7, r * 0.7, cx + r * 0.1, cy - r * 0.7), "none", stroke="#ffffff",
		stroke_width=r * 0.1, opacity=0.6, stroke_linecap="round")


def pipe(d, pts_, w, color=IRON, hi=None, joints=True):
	path = "M" + " L".join("%s %s" % F(x, y) for x, y in pts_)
	d.spath(path, "#121316", w + 4, stroke_linejoin="round")
	d.spath(path, color, w, stroke_linejoin="round")
	d.spath(path, hi or light(color, 0.35), w * 0.25, opacity=0.6, stroke_linejoin="round")
	if joints:
		for (x, y) in pts_[1:-1]:
			d.circle(x, y, w * 0.75, dark(color, 0.2), stroke="#121316", stroke_width=1.5)


def boot_print(d, x, y, ang, s=1.0, a=1.0):
	"""Huge boot print in coal dust (sole + separate heel with tread), pointing along ang (degrees)."""
	sole = "M-4 -11 Q14 -14 24 -9 Q33 0 24 9 Q14 14 -4 11 Q-9 0 -4 -11 Z"
	heel = "M-30 -9 L-13 -10 Q-9 0 -13 10 L-30 9 Q-35 0 -30 -9 Z"
	tf = "translate(%s %s) scale(1 0.62) rotate(%s) scale(%s)" % F(x, y, ang, s)
	with G(d, transform=tf, opacity=a if a < 1 else None):
		d.path(sole + " " + heel, "none", stroke="#5a5c64", stroke_width=3, opacity=0.6)
		d.path(sole, "#08080a")
		d.path(heel, "#08080a")
		dd = "M-1 -8 L-1 8 M6 -10 L6 10 M13 -10 L13 10 M20 -7 L20 7 M-26 -6 L-26 6 M-20 -7 L-20 7 M-15 -7 L-15 7"
		d.spath(dd, "#3e4048", 1.6, opacity=0.9)


def bg_ship_boiler(d):
	rng = random.Random(1001)
	pp = Persp(640, 260)
	P = pp.P
	bx0, by0, bx1, by1 = 250, 40, 1030, 400
	pshell(d, pp, bx0, by0, bx1, by1, "#3e4249", "#2a2d33", "#2e3138", "#16171a", "#2c2a28", "#1a1918")
	iron_wall(d, bx0, by0, bx1, by1, rng)
	pbeams(d, pp, bx0, bx1, by0, (1.0, 1.45, 2.1, 3.2), "#121316", 14)
	# floor plates
	dd = ""
	for i in range(9):
		xb = bx0 + (bx1 - bx0) * i / 8
		a0, a1 = P(xb, by1), P(xb, by1, FAR)
		dd += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
	for sc in (1.3, 1.75, 2.4, 3.4):
		a0, a1 = P(bx0, by1, sc), P(bx1, by1, sc)
		dd += "M%s %s L%s %s " % F(a0[0], a0[1], a1[0], a1[1])
	d.spath(dd, "#0e0e10", 2.2, opacity=0.6, stroke_linecap="butt")
	# right wall: heavy iron door with a wheel (dim); left wall: hanging tools
	dq = [P(bx1, 150, 1.32), P(bx1, 150, 1.72), P(bx1, by1, 1.72), P(bx1, by1, 1.32)]
	d.poly(dq, "#1e2024")
	dq2 = [P(bx1, 162, 1.36), P(bx1, 162, 1.68), P(bx1, by1 - 4, 1.68), P(bx1, by1 - 4, 1.36)]
	d.poly(dq2, d.lin(dq2[0][0], 0, dq2[1][0], 0, [(0, "#2e3136"), (1, "#24262a")]))
	wc = P(bx1, 290, 1.52)
	d.ellipse(wc[0], wc[1], 12, 24, "none", stroke="#6a221c", stroke_width=4)
	for yb in (176, 380):
		for sc in (1.4, 1.64):
			c = P(bx1, yb, sc)
			d.circle(c[0], c[1], 2.4, "#6a6e78")
	for (sc, yb) in ((1.2, 150), (1.45, 160)):
		a0 = P(bx0, yb, sc)
		d.line(a0[0], a0[1], a0[0] + 4, a0[1] + 150 * sc * 0.6, "#2a2016", 4)
		d.rect(a0[0] - 6, a0[1] + 150 * sc * 0.6, 14, 10, "#4a4e56")
	croc_cam(d, bx0 + 26, by0 + 40, 0.62)
	# --- pipes + pressure gauges (back wall, above the coal)
	pipe(d, [(bx0, 236), (690, 236)], 14, "#5a5e66")
	pipe(d, [(470, 236), (470, 206)], 7, BRASS_D)
	pipe(d, [(540, 236), (540, 214)], 7, BRASS_D)
	pipe(d, [(bx0, 112), (650, 112), (650, 150), (700, 150)], 18, "#4a4e56")
	pipe(d, [(910, 170), (980, 170), (980, by0)], 18, "#4a4e56")
	gauge(d, 466, 174, 32, 0.62)
	gauge(d, 540, 190, 24, 0.38)
	d.circle(508, 236, 13, "#b8302a", stroke=INK, stroke_width=1.6)
	d.spath("M497 236 L519 236 M508 225 L508 247", "#7a1a14", 3)
	d.circle(508, 236, 4, BRASS)
	# --- the furnace / boiler front
	FX0, FX1, FY0 = 690, 910, 150
	glow(d, 800, 330, 300, "#ff8a3a", 0.3)
	d.rect(770, -10, 60, FY0 + 20, d.lin(770, 0, 830, 0, [(0, "#1a1b1f"), (0.4, "#4a4e56"), (1, "#141518")]))
	for yy in (40, 100):
		d.rect(766, yy, 68, 8, "#2a2c32")
	front = "M%s %s L%s %s Q%s %s %s %s L%s %s Q%s %s %s %s L%s %s Z" % F(FX0, by1, FX0, FY0 + 40, FX0, FY0, FX0 + 40, FY0, FX1 - 40, FY0, FX1, FY0, FX1, FY0 + 40, FX1, by1)
	d.path(front, d.lin(FX0, 0, FX1, 0, [(0, "#24262b"), (0.35, "#4e525a"), (0.7, "#383b42"), (1, "#1e2024")]), stroke=INK, stroke_width=2.4)
	rivet_row(d, FX0 + 10, FY0 + 16, FX1 - 10, FY0 + 16, 12, 2.4)
	rivet_row(d, FX0 + 10, by1 - 12, FX1 - 10, by1 - 12, 12, 2.4)
	rivet_row(d, FX0 + 10, FY0 + 30, FX0 + 10, by1 - 24, 9, 2.4)
	rivet_row(d, FX1 - 10, FY0 + 30, FX1 - 10, by1 - 24, 9, 2.4)
	# smokebox door (round) with dogs
	d.circle(800, 214, 46, "#2a2c32", stroke=INK, stroke_width=2)
	d.circle(800, 214, 38, d.lin(762, 176, 838, 252, [(0, "#5a5e66"), (1, "#2a2c32")]), stroke="#1a1b1f", stroke_width=2)
	for k in range(8):
		a = k * TAU / 8
		d.circle(800 + math.cos(a) * 42, 214 + math.sin(a) * 42, 4, "#7a808a", stroke=INK, stroke_width=1)
	d.rect(784, 200, 32, 28, BRASS, rx=4, stroke=INK, stroke_width=1.2)
	snapjaw_crest(d, 800, 214, 0.22)
	# firebox door: glowing slits, slightly ajar
	glow(d, 800, 318, 120, "#ff7a2a", 0.55)
	d.rect(742, 282, 116, 72, "#1a0c06", rx=6, stroke=INK, stroke_width=2)
	d.rect(748, 288, 104, 60, d.rad(800, 330, 70, [(0, "#fff2a8"), (0.35, "#ffb040"), (0.8, "#e0501a"), (1, "#7a1a08")]), rx=4)
	for (fx, fh, c_) in ((806, 40, "#ff7a2a"), (822, 50, "#ffb040"), (838, 36, "#ff7a2a"), (814, 28, "#fff2a8"), (832, 26, "#fff2a8")):
		d.path("M%s 348 Q%s %s %s %s Q%s %s %s 348 Z" % F(fx - 9, fx - 10, 348 - fh * 0.5, fx, 348 - fh, fx + 10, 348 - fh * 0.5, fx + 9), c_, opacity=0.95)
	d.path("M748 288 L796 282 L798 356 L748 348 Z", d.lin(748, 0, 798, 0, [(0, "#3a3d44"), (1, "#24262b")]), stroke=INK, stroke_width=2)
	dd = ""
	for k in range(3):
		x = 760 + k * 12
		dd += "M%s 300 L%s 336 " % F(x, x)
	d.spath(dd, "#ffb040", 4, stroke_linecap="round")
	d.spath(dd, "#fff2a8", 1.6, stroke_linecap="round")
	d.rect(784, 312, 18, 8, BRASS, rx=3, stroke=INK, stroke_width=1)
	glow(d, 826, 320, 60, "#ffd080", 0.45)
	for (sx_, sy_) in ((846, 300), (850, 326), (842, 344)):
		sparkle(d, sx_ + rng.uniform(-4, 4), sy_, 4, "#ffd080", 0.9)
	# ash-pit door
	d.rect(752, 364, 96, 28, "#2a2c32", rx=3, stroke=INK, stroke_width=1.6)
	d.rect(760, 372, 80, 4, "#ff7a2a", opacity=0.45)
	# shovel leaning on the furnace
	d.spath("M664 236 L682 396", WOOD_D, 6)
	d.spath("M664 236 L682 396", WOOD_L, 2, opacity=0.6)
	d.path("M656 226 Q664 214 674 226 L670 240 L660 240 Z", WOOD_D, stroke=INK, stroke_width=1.4)
	d.path("M670 382 L696 380 L700 420 Q686 430 672 420 Z", "#6a6e78", stroke=INK, stroke_width=1.8)
	d.path("M676 386 L690 385 L692 412 Z", "#a8b0bc", opacity=0.5)
	# --- coal pile (front left)
	pile = smooth([(358, 552), (366, 480), (392, 428), (434, 392), (486, 372), (538, 380), (578, 412), (604, 462), (622, 552)])
	d.ellipse(490, 552, 150, 16, "#000000", opacity=0.45)
	d.path(pile, d.lin(380, 370, 620, 552, [(0, "#2a2c32"), (0.5, "#141518"), (1, "#0a0a0c")]))
	for _ in range(150):
		x = rng.uniform(370, 612)
		ytop = 372 + (abs(x - 490) / 125) ** 1.6 * 150
		y = rng.uniform(ytop + 6, 548)
		r = rng.uniform(5, 13) * (0.7 + 0.5 * (y - 372) / 180)
		lump = blob_pts(x, y, r, r * 0.8, rng, n=6, jitter=0.3, rot=rng.uniform(0, 3))
		shade = rng.choice(["#1a1b1f", "#24262b", "#111214", "#2e3036"])
		d.poly(lump, shade)
		d.spath("M%s %s L%s %s" % F(lump[3][0], lump[3][1], lump[4][0], lump[4][1]), "#6a7280", 1.4, opacity=0.6)
		if x > 540:
			d.spath("M%s %s L%s %s" % F(lump[0][0], lump[0][1], lump[1][0], lump[1][1]), "#ff9a4a", 1.4, opacity=0.55)
	for _ in range(26):
		x = rng.uniform(340, 680)
		y = rng.uniform(548, 590)
		r = rng.uniform(4, 9)
		d.poly(blob_pts(x, y, r, r * 0.7, rng, n=6, jitter=0.3), "#141518")
	glow(d, 560, 430, 80, "#ff8a3a", 0.18)
	# --- coal dust on the floor with huge boot prints (to the door, and back)
	dust = smooth([(548, 590), (640, 584), (760, 598), (880, 626), (916, 664), (900, 700), (780, 702), (650, 690), (566, 664), (544, 622)])
	d.path(dust, "#2c2d32", opacity=0.9)
	d.path(dust, "none", stroke="#2c2d32", stroke_width=12, opacity=0.35)
	dd = ""
	for _ in range(120):
		dd += "M%s %s l0.1 0 " % F(rng.uniform(560, 900), rng.uniform(596, 696))
	d.spath(dd, "#4a4c54", 2, opacity=0.5)
	for k, (x, y) in enumerate([(606, 610), (684, 618), (762, 628), (838, 638)]):
		boot_print(d, x, y + (5 if k % 2 else -5), 184, 1.12 + k * 0.04)
	for k, (x, y) in enumerate([(622, 656), (700, 664), (778, 672), (852, 680)]):
		boot_print(d, x, y + (5 if k % 2 else -5), 6, 1.16 + k * 0.04)
	# warm furnace light on the floor + dim cage lamp
	floor_reflect(d, 800, 470, 260, 60, "#ff8a3a", 0.3)
	ship_lamp(d, 360, 96, 0.6, hang_from=40, glow_a=0.35)
	light_wash(d, "#ff9a4a", 0.06, 0, 400)
	vignette(d, 0.6, "#050302")


# --------------------------------------------------------------------------------------
# SHIP_LAUNDRY - laundry
# --------------------------------------------------------------------------------------

def big_boot(d, x, base, s=1.0, color="#8a5a32", flip=False):
	"""Enormous leather work boot, side view, toe to the right (left if flip). base = sole bottom."""
	k = -1 if flip else 1
	with G(d, transform="translate(%s %s) scale(%s %s)" % F(x, base, s * k, s)):
		d.ellipse(4, 0, 50, 5, "#000000", opacity=0.3)
		d.path("M-38 -4 L-38 -16 L46 -16 Q56 -14 56 -6 L56 -4 Z", "#2a1a10", stroke=INK, stroke_width=2)
		dd = ""
		for t in range(-34, 52, 8):
			dd += "M%s -3 L%s -1 " % F(t, t + 3)
		d.spath(dd, "#4a3a2a", 1.6)
		boot = "M-36 -16 L-34 -74 Q-34 -82 -24 -82 L4 -82 Q10 -82 10 -74 L12 -44 Q30 -42 46 -30 Q56 -22 54 -16 Z"
		d.path(boot, d.lin(-36, 0, 56, 0, [(0, dark(color, 0.25)), (0.4, light(color, 0.15)), (1, dark(color, 0.2))]), stroke=INK, stroke_width=2.2)
		d.path("M12 -44 Q30 -42 46 -30 Q56 -22 54 -16 L30 -16 Q30 -30 12 -34 Z", dark(color, 0.18))
		d.path("M-36 -78 Q-12 -86 10 -78 L10 -70 Q-12 -76 -35 -70 Z", dark(color, 0.35))
		dd = ""
		for j in range(5):
			y = -66 + j * 9
			dd += "M%s %s L%s %s " % F(-6, y, 10, y + 5)
			dd += "M%s %s L%s %s " % F(10, y, -6, y + 5)
		d.spath(dd, "#f2e2c0", 1.8)
		for j in range(5):
			d.circle(-6, -66 + j * 9, 1.8, BRASS_L)
			d.circle(10, -66 + j * 9, 1.8, BRASS_L)
		d.spath("M-30 -60 Q-28 -40 -30 -22", light(color, 0.35), 3, opacity=0.5)
		d.spath("M-36 -22 L54 -22", dark(color, 0.4), 1.4, stroke_dasharray="3 3")


def scissors(d, x, y, rot=0, s=1.0):
	with G(d, transform=T(x, y, s, rot)):
		d.path("M0 -3 L44 -1 L44 1 L0 3 Z", d.vlin(-3, 3, [(0, "#f4f6f8"), (1, "#9aa2ac")]), stroke=INK, stroke_width=1.4)
		d.path("M0 -1 L40 -10 L42 -8 L2 3 Z", d.vlin(-10, 3, [(0, "#e4e8ec"), (1, "#8a929c")]), stroke=INK, stroke_width=1.4)
		d.circle(0, 0, 2.6, BRASS, stroke=INK, stroke_width=1)
		d.ellipse(-14, 7, 10, 7, "none", stroke=INK, stroke_width=5)
		d.ellipse(-14, 7, 10, 7, "none", stroke="#2a2a30", stroke_width=3)
		d.ellipse(-14, -7, 10, 7, "none", stroke=INK, stroke_width=5)
		d.ellipse(-14, -7, 10, 7, "none", stroke="#2a2a30", stroke_width=3)


def hang_cloth(d, x0, x1, ytop, length, fill, rng, sag=4, fringe=None, pins=True, stroke="#8a8478", sway=0.0, pattern=None):
	"""Cloth hanging from a line between x0..x1 starting at ytop."""
	w = x1 - x0
	pts_ = [(x0, ytop), (x0 + w * 0.5, ytop + sag), (x1, ytop + sag * 0.5)]
	bot = ytop + length
	path = "M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(x0, ytop, x0 + w * 0.5, ytop + sag * 2, x1, ytop, x1 + sway * 0.6, bot - 4,
		x1 - w * 0.25, bot + 6, x0 + w * 0.5, bot, x0 + w * 0.2, bot - 6, x0 + sway, bot)
	d.path(path, fill, stroke=stroke, stroke_width=1.6)
	cid = d.clip('<path d="%s"/>' % path)
	with G(d, clip_path=cid):
		if pattern:
			pattern(x0, x1, ytop, bot)
		dd = ""
		for k in range(1, 4):
			xx = x0 + w * k / 4 + rng.uniform(-6, 6)
			dd += "M%s %s Q%s %s %s %s " % F(xx, ytop + 6, xx + rng.uniform(-8, 8), (ytop + bot) / 2, xx + rng.uniform(-4, 4), bot)
		d.spath(dd, "#000000", 5, opacity=0.08)
		d.rect(x0, ytop, w * 0.18, length + 10, "#ffffff", opacity=0.12)
	if fringe:
		dd = ""
		n = int(w / 6)
		for k in range(n + 1):
			xx = x0 + sway + (x1 + sway * 0.6 - x0 - sway) * k / n
			yy = bot - 2 + math.sin(k * 0.9) * 3
			dd += "M%s %s l%s 9 " % F(xx, yy, rng.uniform(-1.5, 1.5))
		d.spath(dd, fringe, 1.6)
	if pins:
		for xx in (x0 + 8, x1 - 8):
			d.rect(xx - 3, ytop - 8, 6, 16, "#c8a070", rx=2, stroke=INK, stroke_width=1)


def bg_ship_laundry(d):
	rng = random.Random(1101)
	pp = Persp(640, 280)
	P = pp.P
	bx0, by0, bx1, by1 = 300, 50, 990, 448
	pshell(d, pp, bx0, by0, bx1, by1, "#4a9a92", "#2e706a", "#2e6e68", "#24302e", "#5a4a3a", "#3a2e22")
	wood_panels(d, bx0, by0, bx1, 360, "#3f8a83", step=40, line="#22504c", a=0.5)
	wainscot(d, bx0, 360, bx1, by1, color="#24504c", panels=False)
	for bx in (bx0, bx1):
		side_band(d, pp, bx, 360, by1, d.lin(0 if bx == bx0 else W, 0, bx, 0, [(0, "#0e2422"), (1, "#24504c")]))
		side_line(d, pp, bx, 360, BRASS, 4)
	pbeams(d, pp, bx0, bx1, by0, (1.0, 1.5, 2.3), "#1a2a28", 12)
	# wet slatted floor
	pplanks(d, pp, bx0, bx1, by1, 18, "#1a1410", a=0.6, rng=rng)
	# steam pipe along the top + brass tap over the tubs
	pipe(d, [(bx0, 74), (bx1, 74)], 12, "#5a6a6a")
	pipe(d, [(870, 74), (870, 300), (850, 300)], 9, BRASS_D, hi=BRASS_L)
	d.rect(838, 296, 14, 14, BRASS, rx=3, stroke=INK, stroke_width=1.2)
	d.rect(866, 284, 10, 8, "#b8302a", rx=2)
	# porthole + left/right wall shelves
	porthole(d, 352, 210, 38, rng)
	croc_cam(d, bx0 + 24, by0 + 46, 0.62)
	for (yb, sc0, sc1) in ((170, 1.18, 1.62), (236, 1.18, 1.62)):
		q = [P(bx1, yb, sc0), P(bx1, yb, sc1), P(bx1, yb + 8, sc1), P(bx1, yb + 8, sc0)]
		d.poly(q, WOOD)
	for k, c_ in enumerate(("#f2efe6", "#9cc8e8", "#f2efe6", "#e8d0a0")):
		sc = 1.24 + k * 0.1
		a0 = P(bx1, 170, sc)
		d.rect(a0[0] - 10 * sc, a0[1] - 18 * sc, 22 * sc, 18 * sc, c_, rx=3, stroke="#8a8478", stroke_width=1)
	soap = P(bx1, 236, 1.36)
	d.rect(soap[0] - 18, soap[1] - 38, 36, 38, "#e8c040", stroke=INK, stroke_width=1.4)
	snapjaw_crest(d, soap[0], soap[1] - 19, 0.24)
	# --- wash tubs (back right)
	for (cx, w_, h_) in ((838, 70, 78), (906, 58, 64)):
		base = by1 + 4
		wooden_bucket(d, cx, base, w_, h_, color="#c89a60")
		d.ellipse(cx, base - h_, w_ / 2 - 3, h_ * 0.14, "#d8f0f0")
		for _ in range(7):
			d.circle(cx + rng.uniform(-w_ * 0.35, w_ * 0.35), base - h_ - rng.uniform(0, 8), rng.uniform(3, 7), "#ffffff", opacity=0.85, stroke="#b8d8d8",
				stroke_width=0.8)
	d.rect(812, 338, 34, 46, "#c8a070", rx=3, stroke=INK, stroke_width=1.4)
	dd = ""
	for k in range(6):
		dd += "M816 %s L842 %s " % F(346 + k * 6, 346 + k * 6)
	d.spath(dd, "#8a6a48", 2)
	steam_wisps(d, rng, 810, 350, 930, 370, 5, a=0.12)
	# --- drying lines with sheets, towels and the lilac shawl
	for (hx_, hy_) in ((410, 122), (890, 122), (410, 144), (890, 144)):
		d.circle(hx_, hy_, 4, BRASS, stroke=INK, stroke_width=1)
	d.spath("M410 122 Q650 140 890 122", "#e8e2d2", 1.8)

	def lilac_pattern(x0, x1, y0, y1):
		dd = ""
		for yy in range(int(y0) + 14, int(y1), 20):
			for xx in range(int(x0) + 10 + (yy // 20 % 2) * 10, int(x1), 20):
				dd += "M%s %s l4 5 l-4 5 l-4 -5 Z " % F(xx, yy)
		d.path(dd, "#e8d8f4", opacity=0.8)
		d.rect(x0, y1 - 22, x1 - x0, 5, LILAC_D, opacity=0.6)

	def stripe_pattern(x0, x1, y0, y1):
		for yy in (y0 + 18, y0 + 40, y1 - 24):
			d.rect(x0, yy, x1 - x0, 6, "#3a6aa8", opacity=0.85)
	hang_cloth(d, 432, 560, 128, 160, "#f6f4ee", rng, sag=5)
	hang_cloth(d, 574, 628, 133, 96, "#f2efe6", rng, sag=3, pattern=stripe_pattern)
	hang_cloth(d, 646, 800, 132, 132, LILAC, rng, sag=4, fringe=LILAC_D, stroke=LILAC_D, pattern=lilac_pattern)
	d.spath("M410 144 Q650 164 890 144", "#e8e2d2", 1.8)
	hang_cloth(d, 446, 506, 153, 82, "#9cc8e8", rng, sag=2)
	hang_cloth(d, 764, 872, 150, 148, "#f6f4ee", rng, sag=3)
	# --- boot rack with Bruno's enormous boots (front left)
	RX0, RX1, RY = 386, 594, 584
	d.ellipse((RX0 + RX1) / 2, RY + 2, 120, 10, "#000000", opacity=0.35)
	for xx in (RX0 + 4, RX1 - 12):
		d.rect(xx, 452, 10, RY - 452, d.lin(xx, 0, xx + 10, 0, [(0, WOOD_L), (1, WOOD_D)]), stroke=INK, stroke_width=1.2)
	for (yy, dep) in ((532, 10), (RY - 14, 10)):
		d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(RX0, yy, RX1, yy, RX1 - 8, yy - dep, RX0 + 8, yy - dep), "#a8784a")
		d.rect(RX0, yy, RX1 - RX0, 10, d.vlin(yy, yy + 10, [(0, WOOD_L), (1, WOOD_D)]), stroke=INK, stroke_width=1.2)
	big_boot(d, 434, 528, 1.12)
	big_boot(d, 528, 530, 1.16)
	# Reginald's white fencing shoes + Grub's wooden clogs on the lower shelf
	for (x, c_) in ((414, "#f4f2ec"), (446, "#e8e6e0")):
		d.path("M%s %s L%s %s Q%s %s %s %s L%s %s Z" % F(x - 14, RY - 14, x - 14, RY - 28, x + 4, RY - 30, x + 16, RY - 20, x + 18, RY - 14), c_,
			stroke=INK, stroke_width=1.4)
		d.rect(x - 14, RY - 17, 32, 3, "#c8c4b8")
	for x in (500, 548):
		d.path("M%s %s L%s %s Q%s %s %s %s L%s %s Z" % F(x - 20, RY - 14, x - 18, RY - 30, x + 6, RY - 36, x + 22, RY - 22, x + 22, RY - 14),
			"#c8945a", stroke=INK, stroke_width=1.4)
		d.path("M%s %s Q%s %s %s %s" % F(x - 8, RY - 30, x + 4, RY - 26, x + 14, RY - 28), "none", stroke="#3a6a3a", stroke_width=4)
	# --- sewing basket with scissors (front centre-right)
	bcx, bcy = 740, 528
	d.ellipse(bcx, 574, 76, 10, "#000000", opacity=0.35)
	with G(d, transform=T(bcx + 30, bcy - 30, 1, 18)):
		d.ellipse(0, 0, 56, 16, "#b88a52", stroke=INK, stroke_width=1.8)
		d.ellipse(0, -3, 46, 11, "#d8a868")
		d.ellipse(0, -3, 46, 11, "none", stroke="#8a5a2a", stroke_width=1.2, stroke_dasharray="4 3")
	d.path("M%s %s L%s %s Q%s %s %s %s Z" % F(bcx - 64, bcy - 10, bcx + 64, bcy - 10, bcx + 56, bcy + 46, bcx - 56, bcy + 46), d.lin(bcx - 64, 0, bcx + 64, 0,
		[(0, "#8a5a2a"), (0.4, "#c89a5a"), (1, "#7a4a22")]), stroke=INK, stroke_width=2)
	dd = ""
	for k in range(1, 12):
		xx = bcx - 60 + k * 10
		dd += "M%s %s Q%s %s %s %s " % F(xx, bcy - 8, xx + 2, bcy + 18, xx - (xx - bcx) * 0.1, bcy + 44)
	for yy in (bcy + 6, bcy + 22, bcy + 36):
		dd += "M%s %s Q%s %s %s %s " % F(bcx - 62 + (yy - bcy) * 0.12, yy, bcx, yy + 6, bcx + 62 - (yy - bcy) * 0.12, yy)
	d.spath(dd, "#6a3e18", 1.4, opacity=0.7)
	d.ellipse(bcx, bcy - 10, 64, 14, "#5a3818", stroke=INK, stroke_width=2)
	d.ellipse(bcx, bcy - 12, 58, 10, "#3a2410")
	for (dx, c_) in ((-36, "#d8332c"), (-18, YUZU), (2, TEALP_L), (20, LILAC)):
		d.rect(bcx + dx - 6, bcy - 30, 12, 18, c_, rx=2, stroke=INK, stroke_width=1)
		d.rect(bcx + dx - 8, bcy - 32, 16, 4, "#e8d8b8", rx=1, stroke=INK, stroke_width=0.8)
		d.rect(bcx + dx - 8, bcy - 14, 16, 4, "#e8d8b8", rx=1, stroke=INK, stroke_width=0.8)
	d.circle(bcx + 40, bcy - 18, 11, "#4a8a4a", stroke=INK, stroke_width=1.4)
	for (px, py) in ((-4, -6), (3, -8), (6, -2)):
		d.line(bcx + 40 + px, bcy - 18 + py, bcx + 40 + px * 1.8, bcy - 18 + py * 1.8 - 4, "#c9ccd2", 1.2)
	d.spath("M%s %s Q%s %s %s %s Q%s %s %s %s" % F(bcx + 52, bcy - 8, bcx + 70, bcy + 10, bcx + 62, bcy + 30, bcx + 56, bcy + 44, bcx + 70, bcy + 48),
		"#f2e8c8", 4)
	scissors(d, bcx + 24, bcy - 31, 12, 1.25)
	sparkle(d, bcx + 74, bcy - 40, 8, "#ffffff", 0.9)
	# lamp + vignette
	ship_lamp(d, 640, 108, 0.65, hang_from=56, glow_a=0.45, glow_r=260)
	floor_reflect(d, 640, 520, 320, 50, LANTERN, 0.16)
	steam(d, rng, 300, 120, 1000, 340, 6, a=0.05, color="#e8fff8")
	light_wash(d, "#ffd8a0", 0.08, 0, 300)
	vignette(d, 0.5, "#030a0a")


# --------------------------------------------------------------------------------------
# MAIN
# --------------------------------------------------------------------------------------

BGS = ["ship_dock", "ship_deck", "ship_saloon", "ship_hall", "ship_cabin", "ship_tumble_cabin", "ship_infirmary", "ship_infirmary_body",
	"ship_purser", "ship_boiler", "ship_laundry"]

FORBIDDEN = ("<text", "<filter", "<image", "<style", "xlink:href", "href=")


def read_hotspots():
	"""scripts/data/investigation_data2.gd -> {bg_id: [(label, x, y, w, h)]}; falls back to HOTSPOTS."""
	out = {k: list(v) for k, v in HOTSPOTS.items()}
	path = os.path.join(ROOT, "scripts", "data", "investigation_data2.gd")
	try:
		src = open(path, encoding="utf-8").read()
	except OSError:
		return out
	cur = None
	found = {}
	for line in src.splitlines():
		m = re.search(r'"bg":\s*"(\w+)"', line)
		if m:
			cur = m.group(1)
			found.setdefault(cur, [])
		m = re.search(r'"label":\s*"([^"]+)",\s*"rect":\s*\[(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\]', line)
		if m and cur:
			found[cur].append((m.group(1),) + tuple(int(m.group(i)) for i in range(2, 6)))
	for bid, hs in found.items():
		if bid in out and [h[1:] for h in hs] != [h[1:] for h in out[bid]]:
			print("  note: %s hotspot rects in investigation_data2.gd differ from the built-in table; using the data file" % bid)
		out[bid] = hs
	return out


def debug_overlay(svg_text, bg_id, hotspots):
	add = [
		'<rect x="0" y="340" width="330" height="380" fill="#00ffff" fill-opacity="0.10" stroke="#00ffff" stroke-width="2" stroke-dasharray="8 6"/>',
		'<rect x="950" y="340" width="330" height="380" fill="#00ffff" fill-opacity="0.10" stroke="#00ffff" stroke-width="2" stroke-dasharray="8 6"/>',
	]
	for (label, x, y, w, h) in hotspots.get(bg_id, []):
		add.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#ff00ff" fill-opacity="0.10" stroke="#ff00ff" stroke-width="3"/>' % (x, y, w, h))
	return svg_text.replace("\n</svg>", "\n" + "\n".join(add) + "\n</svg>")


def main():
	args = sys.argv[1:]
	debug_dir = None
	only = None
	i = 0
	while i < len(args):
		if args[i] == "--debug":
			debug_dir = args[i + 1]
			i += 2
		elif args[i] == "--only":
			only = set(args[i + 1].split(","))
			i += 2
		else:
			i += 1
	hs = read_hotspots()
	bg_dir = os.path.join(ROOT, "art", "bg")
	os.makedirs(bg_dir, exist_ok=True)
	if debug_dir:
		os.makedirs(debug_dir, exist_ok=True)
	g = globals()
	for bid in BGS:
		if only and bid not in only:
			continue
		fn = g.get("bg_" + bid)
		if fn is None:
			print("  (no generator yet for %s)" % bid)
			continue
		d = Doc()
		fn(d)
		txt = d.svg()
		bad = [t for t in FORBIDDEN if t in txt]
		if bad:
			raise SystemExit("%s contains forbidden SVG features: %s" % (bid, bad))
		with open(os.path.join(bg_dir, bid + ".svg"), "w", encoding="utf-8") as f:
			f.write(txt)
		print("bg %-20s %6.1f KB  %d elements" % (bid, len(txt) / 1024.0, txt.count("<") - txt.count("</")))
		if debug_dir:
			with open(os.path.join(debug_dir, "dbg_" + bid + ".svg"), "w", encoding="utf-8") as f:
				f.write(debug_overlay(txt, bid, hs))


if __name__ == "__main__":
	main()
