#!/usr/bin/env python3
"""SPLASH TRIAL - Chapter 3 ("Warden's Rest", the island) background generator.

Writes the island and mansion backgrounds art/bg/manor_*.svg (1280x720, SVG 1.1 basics only: no text, filters, images
or styles). They are the story-scene backgrounds of Case 3 and the room pictures of the classic --2d investigation.
The toolkit comes from tools/gen_bgs.py, the Mudlark, the Gaol and the house from tools/gen_quake_art.py (all imported
read-only, no bytecode written), so the island looks the same as at the end of the earthquake cutscene.

Look of Warden's Rest (keep consistent with scripts/world3d/rooms3.gd): a grand, earthquake-cracked Victorian house on a
cliff, built for the Warden of the Gaol across the bay. Dark panelling, green and oxblood damask, a black and white marble
chequer in the Grand Hall, gilt frames, brass chandeliers, sea light through tall sash windows, Snapjaw's crests and
crocodile cameras everywhere. Rooms are drawn in one-point perspective from real metre coordinates (see `pt`), so the
furniture sits where it sits in the 3D room. Lower left (x<330, y>340) and lower right (x>950, y>340) stay calm for the
portraits.

Usage (from the project root):
  python3 tools/gen_mansion_bgs.py                    # write all of them
  python3 tools/gen_mansion_bgs.py --only manor_hall,manor_library
  python3 tools/gen_mansion_bgs.py --list
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)

import gen_bgs as B  # noqa: E402  (helpers only - never modified)
import gen_quake_art as QA  # noqa: E402  (the Mudlark, the Gaol, the house, clouds - never modified)
from gen_bgs import (Doc, G, T, fm, mix, dark, light, smooth, blob_pts, glow, vignette, sparkle, snapjaw_crest,  # noqa: E402
	croc_cam, steam, steam_wisps, glyphs, INK, LANTERN, LANTERN_HOT, GOLD, GOLD_D, RED_EYE)

W, H = B.W, B.H
ROOT = B.ROOT
TAU = math.tau
FORBIDDEN = ("<text", "<filter", "<image", "<style", "xlink:href", "href=")

# --------------------------------------------------------------------------------------
# Warden's Rest palette
# --------------------------------------------------------------------------------------
GILT, GILT_D, GILT_L = "#c99a42", "#7e5a1e", "#f0d184"
PANEL, PANEL_D, PANEL_L = "#4a2a16", "#2a170c", "#6e4426"
WOOD, WOOD_D, WOOD_L = "#7a4a28", "#4a2a14", "#a8743f"
MARBLE, MARBLE_D, MARBLE_V = "#e6e1d6", "#1c1d22", "#b9b3a6"
HALL_G, HALL_GM = "#1f3d36", "#33594c"
OXBLOOD, OXBLOOD_M = "#5a1a1e", "#7a3030"
LIB_G, LIB_GM = "#1b3029", "#2c463a"
CREAM, CREAM_D = "#efe4c8", "#cbbd98"
BRICK, BRICK_D, BRICK_L = "#8a4a32", "#5a2c1c", "#a8624a"
STONE, STONE_D, STONE_L = "#8e8a82", "#5c5952", "#b4b0a6"
SEA, SEA_D, SEA_L = "#2a7f9e", "#14506a", "#7cc4d8"
CROC_G = "#4f8f52"
VELVET = "#6a1622"
PLASTER = "#e8e2d4"
DUST = "#f1eee6"

# --------------------------------------------------------------------------------------
# one-point perspective in metres
#   X: metres to the right of the eye line, Y: metres above the floor, Z: metres in front of the viewer.
#   A room's back wall stands at Z0; at that distance one metre is M pixels.
# --------------------------------------------------------------------------------------
VX, VY = 640.0, 300.0
M = 100.0
Z0 = 6.0
EYE = 1.5


class View:
	"""A camera: vanishing point, eye height, back-wall distance and scale (all rooms share the defaults)."""

	def __init__(self, vx=VX, vy=VY, eye=EYE, z0=Z0, m=M):
		self.vx, self.vy, self.eye, self.z0, self.m = vx, vy, eye, z0, m

	def s(self, z):
		return self.z0 / max(0.05, z)

	def pt(self, x, y, z):
		k = self.s(z)
		return (self.vx + x * self.m * k, self.vy + (self.eye - y) * self.m * k)

	def pts(self, seq):
		return [self.pt(*p) for p in seq]


V = View()


def pt(x, y, z):
	return V.pt(x, y, z)


def F(*vals):
	return tuple(fm(float(v)) for v in vals)


def quad(d, p3, fill, **kw):
	d.poly(V.pts(p3), fill, **kw)


def wall_quad(x, y0, y1, z0, z1):
	"""Corner points of a patch of a side wall (constant x) from depth z0 to z1, height y0 to y1."""
	return [(x, y0, z0), (x, y0, z1), (x, y1, z1), (x, y1, z0)]


def floor_quad(x0, x1, z0, z1, y=0.0):
	return [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)]


def back_quad(x0, x1, y0, y1, z):
	return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


def zs(z0, z1, n):
	"""n+1 depths evenly spaced in metres from z0 to z1."""
	return [z0 + (z1 - z0) * i / n for i in range(n + 1)]


def box3(d, x0, x1, y0, y1, z0, z1, front, top=None, side=None, bottom=None, stroke=INK, sw=1.6, a=None):
	"""A box from (x0, y0, z0) to (x1, y1, z1), only the faces the viewer can see. Front is the near (z0) face."""
	kw = {"stroke": stroke, "stroke_width": sw, "stroke_linejoin": "round"} if stroke else {}
	if a is not None:
		kw["opacity"] = a
	top = top or light(front, 0.18) if isinstance(front, str) and front.startswith("#") else (top or front)
	side = side or (dark(front, 0.22) if isinstance(front, str) and front.startswith("#") else front)
	if y1 < V.eye:
		quad(d, [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], top, **kw)
	elif y0 > V.eye:
		quad(d, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], bottom or dark(side, 0.2) if isinstance(side, str) else side, **kw)
	if x0 > 0:
		quad(d, wall_quad(x0, y0, y1, z0, z1), side, **kw)
	if x1 < 0:
		quad(d, wall_quad(x1, y0, y1, z0, z1), side, **kw)
	quad(d, back_quad(x0, x1, y0, y1, z0), front, **kw)


def hline(d, x0, x1, y, z, color, sw=2.0, **kw):
	a, b = pt(x0, y, z), pt(x1, y, z)
	d.line(a[0], a[1], b[0], b[1], color, sw * V.s(z) / 1.0 if kw.pop("scale", False) else sw, **kw)


def side_line(d, x, y, z0, z1, color, sw=2.0, **kw):
	a, b = pt(x, y, z0), pt(x, y, z1)
	d.line(a[0], a[1], b[0], b[1], color, sw, **kw)


def ell3(d, x, y, z, rx, ry, fill, **kw):
	"""An ellipse lying flat (rx along x, ry along z) centred at (x, y, z)."""
	c = pt(x, y, z)
	k = V.s(z)
	near, far = pt(x, y, z - ry), pt(x, y, z + ry)
	d.ellipse(c[0], (near[1] + far[1]) / 2.0, rx * V.m * k, max(0.5, abs(near[1] - far[1]) / 2.0), fill, **kw)


def upright(d, x, y, z, w, h, fill, **kw):
	"""A flat rectangle facing the viewer, bottom centre at (x, y, z)."""
	quad(d, back_quad(x - w / 2.0, x + w / 2.0, y, y + h, z), fill, **kw)


def at(x, y, z, scale=1.0):
	"""SVG transform placing a front-facing sprite drawn in metres*100 px units at (x, y, z)."""
	p = pt(x, y, z)
	return T(p[0], p[1], V.s(z) * scale)


# --------------------------------------------------------------------------------------
# shells, surfaces and trim
# --------------------------------------------------------------------------------------
class Room:
	def __init__(self, w=6.8, h=3.45, z0=1.2, z1=Z0, x0=None):
		self.x0 = -w / 2.0 if x0 is None else x0
		self.x1 = self.x0 + w
		self.h = h
		self.z0, self.z1 = z0, z1


def shell(d, r, back, side_l, side_r, floor, ceil, back2=None):
	"""Ceiling, side walls, floor and back wall of a box room (fills are colours or gradients)."""
	d.rect(0, 0, W, H, ceil if isinstance(ceil, str) and ceil.startswith("#") else "#20140c")
	quad(d, [(r.x0, r.h, r.z0), (r.x1, r.h, r.z0), (r.x1, r.h, r.z1), (r.x0, r.h, r.z1)], ceil)
	quad(d, [(r.x0, -0.01, r.z0), (r.x1, -0.01, r.z0), (r.x1, -0.01, r.z1), (r.x0, -0.01, r.z1)], floor)
	quad(d, wall_quad(r.x0, 0, r.h, r.z0, r.z1), side_l)
	quad(d, wall_quad(r.x1, 0, r.h, r.z0, r.z1), side_r)
	quad(d, back_quad(r.x0, r.x1, 0, r.h, r.z1), back)
	if back2:
		quad(d, back_quad(r.x0, r.x1, 0, r.h, r.z1), back2)


def side_grad(d, r, col, left=True):
	"""Side wall fill: darker toward the viewer."""
	x = r.x0 if left else r.x1
	a, b = pt(x, 1.0, r.z0), pt(x, 1.0, r.z1)
	return d.lin(a[0], 0, b[0], 0, [(0, dark(col, 0.45)), (1, col)])


def back_grad(d, r, col, col2=None):
	a, b = pt(0, r.h, r.z1), pt(0, 0, r.z1)
	return d.vlin(a[1], b[1], [(0, dark(col, 0.18)), (1, col2 or col)])


def floor_grad(d, r, col, col2):
	a, b = pt(0, 0, r.z1), pt(0, 0, r.z0)
	return d.vlin(a[1], min(H, b[1]), [(0, col), (1, col2)])


def ceil_grad(d, r, col):
	a, b = pt(0, r.h, r.z0), pt(0, r.h, r.z1)
	return d.vlin(max(0, a[1]), b[1], [(0, dark(col, 0.4)), (1, col)])


def damask_back(d, x0, x1, y0, y1, z, motif, a=0.4, step=0.42):
	"""Wallpaper on a wall facing the viewer: a lattice of little lozenges and dots."""
	dd = ""
	k = V.s(z)
	row = 0
	y = y0 + step * 0.5
	while y < y1:
		x = x0 + (step * 0.5 if row % 2 else 0.0) + step * 0.25
		while x < x1:
			c = pt(x, y, z)
			hw, hh = 0.07 * V.m * k, 0.12 * V.m * k
			dd += "M%s %s L%s %s L%s %s L%s %s Z " % F(c[0], c[1] - hh, c[0] + hw, c[1], c[0], c[1] + hh, c[0] - hw, c[1])
			x += step
		y += step * 0.75
		row += 1
	d.path(dd, motif, opacity=a)


def damask_side(d, x, y0, y1, z0, z1, motif, a=0.35, step=0.42):
	"""The same wallpaper on a side wall, in perspective."""
	dd = ""
	row = 0
	y = y0 + step * 0.5
	while y < y1:
		z = z1 - (step * 0.5 if row % 2 else 0.0) - step * 0.25
		while z > z0:
			p0 = pt(x, y - 0.12, z)
			p1 = pt(x, y, z - 0.07)
			p2 = pt(x, y + 0.12, z)
			p3 = pt(x, y, z + 0.07)
			dd += "M%s %s L%s %s L%s %s L%s %s Z " % F(p0[0], p0[1], p1[0], p1[1], p2[0], p2[1], p3[0], p3[1])
			z -= step
		y += step * 0.75
		row += 1
	d.path(dd, motif, opacity=a)


def wainscot(d, r, h=1.05, col=PANEL, left=True, right=True, back=True, panels=True):
	"""Dark panelling up to `h` on the back and side walls, with a dado rail and raised panels."""
	rail = dark(col, 0.35)
	if back:
		quad(d, back_quad(r.x0, r.x1, 0, h, r.z1), d.vlin(pt(0, h, r.z1)[1], pt(0, 0, r.z1)[1], [(0, light(col, 0.08)), (1, dark(col, 0.2))]))
		if panels:
			n = max(2, int((r.x1 - r.x0) / 0.9))
			for i in range(n):
				xa = r.x0 + (r.x1 - r.x0) * (i + 0.12) / n
				xb = r.x0 + (r.x1 - r.x0) * (i + 0.88) / n
				quad(d, back_quad(xa, xb, 0.18, h - 0.2, r.z1), "none", stroke=dark(col, 0.45), stroke_width=2.2)
				quad(d, back_quad(xa + 0.02, xb + 0.02, 0.16, h - 0.22, r.z1), "none", stroke=light(col, 0.2), stroke_width=1, opacity=0.5)
		hline(d, r.x0, r.x1, h, r.z1, rail, 5)
		hline(d, r.x0, r.x1, 0.06, r.z1, dark(col, 0.5), 5)
	for (x, on) in ((r.x0, left), (r.x1, right)):
		if not on:
			continue
		quad(d, wall_quad(x, 0, h, r.z0, r.z1), dark(col, 0.12))
		if panels:
			n = max(2, int((r.z1 - r.z0) / 0.9))
			for i in range(n):
				za = r.z0 + (r.z1 - r.z0) * (i + 0.12) / n
				zb = r.z0 + (r.z1 - r.z0) * (i + 0.88) / n
				quad(d, wall_quad(x, 0.18, h - 0.2, za, zb), "none", stroke=dark(col, 0.5), stroke_width=2.4)
		side_line(d, x, h, r.z0, r.z1, rail, 6)
		side_line(d, x, 0.06, r.z0, r.z1, dark(col, 0.5), 7)


def cornice(d, r, col=CREAM, depth=0.18):
	"""A deep cornice where the walls meet the ceiling, and a picture rail under it."""
	y = r.h
	quad(d, back_quad(r.x0, r.x1, y - depth, y, r.z1), d.vlin(pt(0, y, r.z1)[1], pt(0, y - depth, r.z1)[1], [(0, dark(col, 0.25)), (1, col)]))
	hline(d, r.x0, r.x1, y - depth, r.z1, dark(col, 0.45), 2)
	for x in (r.x0, r.x1):
		quad(d, wall_quad(x, y - depth, y, r.z0, r.z1), dark(col, 0.15))
		side_line(d, x, y - depth, r.z0, r.z1, dark(col, 0.45), 2)
		side_line(d, x, y - depth - 0.35, r.z0, r.z1, dark(col, 0.3), 3, opacity=0.7)
	hline(d, r.x0, r.x1, y - depth - 0.35, r.z1, dark(col, 0.3), 3, opacity=0.7)


def corner_lines(d, r, col="#000000", a=0.35):
	for x in (r.x0, r.x1):
		p0, p1 = pt(x, 0, r.z1), pt(x, r.h, r.z1)
		d.line(p0[0], p0[1], p1[0], p1[1], col, 3, opacity=a)
	p0, p1 = pt(r.x0, 0, r.z1), pt(r.x1, 0, r.z1)
	d.line(p0[0], p0[1], p1[0], p1[1], col, 3, opacity=a)


def parquet(d, r, col=WOOD, col2=None, n=None, x0=None, x1=None):
	"""Boards running away from the viewer, with staggered joints."""
	x0 = r.x0 if x0 is None else x0
	x1 = r.x1 if x1 is None else x1
	quad(d, floor_quad(x0, x1, r.z0, r.z1), floor_grad(d, r, light(col, 0.05), dark(col2 or col, 0.25)))
	n = n or int((x1 - x0) / 0.16)
	dd = ""
	for i in range(n + 1):
		x = x0 + (x1 - x0) * i / n
		a, b = pt(x, 0, r.z1), pt(x, 0, r.z0)
		dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
	d.spath(dd, dark(col, 0.45), 1.3, opacity=0.55, stroke_linecap="butt")
	rng = random.Random(int((x1 - x0) * 100))
	dd = ""
	for i in range(n):
		xa = x0 + (x1 - x0) * i / n
		xb = x0 + (x1 - x0) * (i + 1) / n
		z = r.z1 - rng.uniform(0, 1.2)
		while z > r.z0:
			a, b = pt(xa, 0, z), pt(xb, 0, z)
			dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
			z -= rng.uniform(0.9, 1.6)
	d.spath(dd, dark(col, 0.45), 1.1, opacity=0.5, stroke_linecap="butt")


def chequer(d, r, a=MARBLE, b=MARBLE_D, tile=0.6, x0=None, x1=None, rng=None):
	"""Marble chequerboard floor with a few veins."""
	rng = rng or random.Random(7)
	x0 = r.x0 if x0 is None else x0
	x1 = r.x1 if x1 is None else x1
	quad(d, floor_quad(x0, x1, r.z0, r.z1), b)
	i0 = int(math.floor(x0 / tile)) - 1
	i1 = int(math.ceil(x1 / tile)) + 1
	j0 = int(math.floor(r.z0 / tile))
	j1 = int(math.ceil(r.z1 / tile))
	dd = ""
	veins = ""
	for i in range(i0, i1):
		for j in range(j0, j1):
			if (i + j) % 2:
				continue
			xa, xb = max(x0, i * tile), min(x1, (i + 1) * tile)
			za, zb = max(r.z0, j * tile), min(r.z1, (j + 1) * tile)
			if xa >= xb or za >= zb:
				continue
			p = V.pts([(xa, 0, za), (xb, 0, za), (xb, 0, zb), (xa, 0, zb)])
			dd += "M" + " L".join("%s %s" % F(x, y) for x, y in p) + " Z "
			if rng.random() < 0.45:
				q0 = pt(xa + rng.uniform(0, tile), 0, za)
				q1 = pt(xa + rng.uniform(0, tile), 0, zb)
				veins += "M%s %s Q%s %s %s %s " % F(q0[0], q0[1], (q0[0] + q1[0]) / 2 + rng.uniform(-8, 8), (q0[1] + q1[1]) / 2, q1[0], q1[1])
	d.path(dd, d.vlin(pt(0, 0, r.z1)[1], H, [(0, dark(a, 0.12)), (1, a)]))
	d.spath(veins, MARBLE_V, 1.4, opacity=0.6)


def flagstones(d, r, col=STONE, tile=0.7, rng=None, x0=None, x1=None):
	rng = rng or random.Random(11)
	x0 = r.x0 if x0 is None else x0
	x1 = r.x1 if x1 is None else x1
	quad(d, floor_quad(x0, x1, r.z0, r.z1), floor_grad(d, r, col, dark(col, 0.3)))
	dd = ""
	z = r.z1
	row = 0
	while z > r.z0:
		z2 = max(r.z0, z - tile * rng.uniform(0.8, 1.15))
		a, b = pt(x0, 0, z2), pt(x1, 0, z2)
		dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
		x = x0 + (tile * 0.5 if row % 2 else 0.0)
		while x < x1:
			a, b = pt(x, 0, z), pt(x, 0, z2)
			dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
			x += tile * rng.uniform(0.8, 1.3)
		z = z2
		row += 1
	d.spath(dd, dark(col, 0.5), 1.6, opacity=0.6, stroke_linecap="butt")


def bricks_back(d, x0, x1, y0, y1, z, col=BRICK, course=0.075, brick=0.23, a=0.55):
	quad(d, back_quad(x0, x1, y0, y1, z), d.vlin(pt(0, y1, z)[1], pt(0, y0, z)[1], [(0, dark(col, 0.2)), (1, col)]))
	dd = ""
	y = y0
	row = 0
	while y < y1:
		a0, b0 = pt(x0, y, z), pt(x1, y, z)
		dd += "M%s %s L%s %s " % F(a0[0], a0[1], b0[0], b0[1])
		x = x0 + (brick * 0.5 if row % 2 else 0.0)
		while x < x1:
			p0, p1 = pt(x, y, z), pt(x, min(y1, y + course), z)
			dd += "M%s %s L%s %s " % F(p0[0], p0[1], p1[0], p1[1])
			x += brick
		y += course
		row += 1
	d.spath(dd, light(col, 0.35), 1.0, opacity=a, stroke_linecap="butt")


def bricks_side(d, x, y0, y1, z0, z1, col=BRICK, course=0.075, brick=0.23, a=0.5):
	quad(d, wall_quad(x, y0, y1, z0, z1), d.lin(pt(x, 0, z0)[0], 0, pt(x, 0, z1)[0], 0, [(0, dark(col, 0.45)), (1, col)]))
	dd = ""
	y = y0
	row = 0
	while y < y1:
		a0, b0 = pt(x, y, z0), pt(x, y, z1)
		dd += "M%s %s L%s %s " % F(a0[0], a0[1], b0[0], b0[1])
		z = z1 - (brick * 0.5 if row % 2 else 0.0)
		while z > z0:
			p0, p1 = pt(x, y, z), pt(x, min(y1, y + course), z)
			dd += "M%s %s L%s %s " % F(p0[0], p0[1], p1[0], p1[1])
			z -= brick
		y += course
		row += 1
	d.spath(dd, light(col, 0.35), 0.9, opacity=a, stroke_linecap="butt")


def crack(d, x, y, z, rng, n=7, step=0.16, side=None, col="#16100c", sw=2.6, dirx=0.3):
	"""A jagged plaster crack starting at (x, y, z), running down. side=None: on a back wall; else on that side wall."""
	pts_ = [(x, y, z)]
	cx, cy, cz = x, y, z
	for _ in range(n):
		cy -= step * rng.uniform(0.7, 1.3)
		if side is None:
			cx += step * rng.uniform(-0.6, 0.6) + dirx * step * 0.4
		else:
			cz += step * rng.uniform(-0.6, 0.6) + dirx * step * 0.4
		pts_.append((cx, cy, cz))
	p = V.pts(pts_)
	d.pline(p, col, sw)
	if n > 4:
		b = p[n // 2]
		d.pline([b, (b[0] + rng.uniform(-18, 18), b[1] + rng.uniform(8, 22))], col, sw * 0.7)


def plaster_lumps(d, x, z, rng, n=8, r=0.4, col=PLASTER):
	for _ in range(n):
		a = rng.uniform(0, TAU)
		rr = r * math.sqrt(rng.random())
		px, pz = x + math.cos(a) * rr, z + math.sin(a) * rr
		s = rng.uniform(0.03, 0.08)
		c = pt(px, 0, pz)
		k = V.s(pz)
		d.ellipse(c[0], c[1], s * M * k * 1.3, s * M * k * 0.55, col, stroke=dark(col, 0.4), stroke_width=1)


def dust_patch(d, x, z, rx, rz, a=0.5, col=DUST):
	ell3(d, x, 0.002, z, rx, rz, d.brad([(0, col, a), (0.7, col, a * 0.6), (1, col, 0)]))


# --------------------------------------------------------------------------------------
# windows, doors, pictures
# --------------------------------------------------------------------------------------
def vista(d, p, tod="day", gaol=True, rng=None, horizon=0.58, gaol_x=0.62, gaol_s=1.0):
	"""The view out of a window over the bay, clipped to polygon p (screen points)."""
	rng = rng or random.Random(int(p[0][0] + p[0][1]))
	xs = [q[0] for q in p]
	ys = [q[1] for q in p]
	x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
	hz = y0 + (y1 - y0) * horizon
	cp = d.clip('<polygon points="%s"/>' % " ".join("%s,%s" % F(x, y) for x, y in p))
	with G(d, clip_path=cp):
		if tod == "night":
			sky = [(0, "#060a18"), (0.7, "#14223c"), (1, "#24344c")]
			sea = [(0, "#101c2c"), (1, "#050a12")]
		elif tod == "dusk":
			sky = [(0, "#3a3a78"), (0.55, "#c86a6a"), (0.85, "#f4a860"), (1, "#ffd890")]
			sea = [(0, "#6a5a7a"), (0.4, "#3a3a5a"), (1, "#1a2036")]
		else:
			sky = [(0, "#5f9be0"), (0.7, "#a9d2ef"), (1, "#e2f2f6")]
			sea = [(0, SEA_L), (0.25, SEA), (1, SEA_D)]
		d.rect(x0 - 2, y0 - 2, x1 - x0 + 4, hz - y0 + 2, d.vlin(y0, hz, sky))
		d.rect(x0 - 2, hz, x1 - x0 + 4, y1 - hz + 2, d.vlin(hz, y1, sea))
		ww = x1 - x0
		if tod == "day":
			for _ in range(2):
				cx = rng.uniform(x0, x1)
				cy = rng.uniform(y0 + (hz - y0) * 0.15, y0 + (hz - y0) * 0.6)
				d.ellipse(cx, cy, ww * rng.uniform(0.18, 0.3), (hz - y0) * 0.06, "#ffffff", opacity=0.75)
			for k in range(6):
				yy = hz + (y1 - hz) * (k + 1) / 8.0
				xx = rng.uniform(x0, x1)
				d.line(xx, yy, xx + ww * 0.15, yy, "#d8f4ff", 1.5, opacity=0.5)
		elif tod == "dusk":
			glow(d, x0 + ww * 0.25, hz, ww * 0.4, "#ffe0a0", 0.6)
		else:
			for _ in range(int(ww / 14)):
				d.circle(rng.uniform(x0, x1), rng.uniform(y0, hz - 6), rng.uniform(0.6, 1.4), "#ffffff", opacity=rng.uniform(0.4, 0.9))
		d.line(x0, hz, x1, hz, "#ffffff" if tod == "day" else "#8aa0c0", 1.2, opacity=0.5)
		if gaol:
			gx = x0 + ww * gaol_x
			gw = ww * 0.42 * gaol_s
			gh = gw * 0.34
			col = "#5a6270" if tod == "day" else ("#3a3448" if tod == "dusk" else "#080b12")
			d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(gx - gw * 0.7, hz + 1, gx - gw * 0.5, hz - gh * 0.2, gx + gw * 0.6, hz - gh * 0.25, gx + gw * 0.8, hz + 1), dark(col, 0.2))
			d.rect(gx - gw * 0.4, hz - gh, gw * 0.8, gh * 0.8, col)
			for tx in (-0.4, 0.0, 0.4):
				d.rect(gx + gw * tx - gw * 0.05, hz - gh * 1.5, gw * 0.1, gh * 0.7, col)
				d.poly([(gx + gw * tx - gw * 0.07, hz - gh * 1.5), (gx + gw * tx, hz - gh * 1.75), (gx + gw * tx + gw * 0.07, hz - gh * 1.5)], dark(col, 0.2))
			if tod != "day":
				for rr in range(3):
					for cc in range(9):
						if rng.random() < 0.75:
							d.rect(gx - gw * 0.36 + cc * gw * 0.08, hz - gh * 0.9 + rr * gh * 0.22, max(1.2, gw * 0.025), max(1.5, gh * 0.08), "#ffd27a")
	return hz


def sash_window(d, p4, tod="day", frame="#efe8dc", bars=(1, 2), gaol=True, rng=None, horizon=0.58, glow_a=0.35):
	"""A sash window given its 4 screen corners (tl, tr, br, bl): view, frame and glazing bars."""
	vista(d, p4, tod, gaol, rng, horizon)
	d.poly(p4, "none", stroke=frame, stroke_width=7, stroke_linejoin="round")
	d.poly(p4, "none", stroke=INK, stroke_width=1.4, opacity=0.6)
	tl, tr, br, bl = p4
	cols, rows = bars
	dd = ""
	for i in range(1, cols + 1):
		t = i / (cols + 1.0)
		a = (tl[0] + (tr[0] - tl[0]) * t, tl[1] + (tr[1] - tl[1]) * t)
		b = (bl[0] + (br[0] - bl[0]) * t, bl[1] + (br[1] - bl[1]) * t)
		dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
	for j in range(1, rows + 2):
		t = j / (rows + 2.0)
		a = (tl[0] + (bl[0] - tl[0]) * t, tl[1] + (bl[1] - tl[1]) * t)
		b = (tr[0] + (br[0] - tr[0]) * t, tr[1] + (br[1] - tr[1]) * t)
		dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
	d.spath(dd, frame, 3.2)
	if tod == "day" and glow_a > 0:
		cx = sum(q[0] for q in p4) / 4.0
		cy = sum(q[1] for q in p4) / 4.0
		glow(d, cx, cy, abs(tr[0] - tl[0]) * 1.4, "#e8f6ff", glow_a)


def back_window(d, x, y, w, h, z, tod="day", curtains=None, rng=None, gaol=True, sill=True):
	p = V.pts([(x - w / 2, y + h, z), (x + w / 2, y + h, z), (x + w / 2, y, z), (x - w / 2, y, z)])
	quad(d, back_quad(x - w / 2 - 0.08, x + w / 2 + 0.08, y - 0.06, y + h + 0.1, z), dark(PANEL, 0.1))
	sash_window(d, p, tod, rng=rng, gaol=gaol)
	if sill:
		box3(d, x - w / 2 - 0.12, x + w / 2 + 0.12, y - 0.08, y, z - 0.18, z, CREAM, sw=1)
	if curtains:
		for sd in (-1, 1):
			cx0 = x + sd * (w / 2 + 0.05)
			cx1 = x + sd * (w / 2 - 0.22)
			pa = pt(min(cx0, cx1), y + h + 0.15, z - 0.05)
			pb = pt(max(cx0, cx1), y - 0.25, z - 0.05)
			B.curtain(d, pa[0], pa[1], pb[0], pb[1], curtains, folds=3, gather="left" if sd < 0 else "right")
		pa, pb = pt(x - w / 2 - 0.3, y + h + 0.2, z - 0.05), pt(x + w / 2 + 0.3, y + h + 0.2, z - 0.05)
		d.line(pa[0], pa[1], pb[0], pb[1], GILT_D, 4)
		d.circle(pa[0], pa[1], 5, GILT)
		d.circle(pb[0], pb[1], 5, GILT)


def side_window(d, x, y0, y1, z0, z1, tod="day", rng=None, gaol=False, curtains=None, frame="#efe8dc"):
	p = V.pts([(x, y1, z1), (x, y1, z0), (x, y0, z0), (x, y0, z1)])
	if x > 0:
		p = [p[1], p[0], p[3], p[2]]
	quad(d, wall_quad(x, y0 - 0.06, y1 + 0.1, z0 - 0.08, z1 + 0.08), dark(PANEL, 0.1))
	sash_window(d, p, tod, frame=frame, bars=(1, 2), gaol=gaol, rng=rng, glow_a=0.25)
	if tod == "day":
		# a slant of sunlight on the floor
		inner = 0.6 if x < 0 else -0.6
		quad(d, [(x, 0.0, z0), (x, 0.0, z1), (x + inner * 2.2, 0.0, z1 - 0.4), (x + inner * 2.2, 0.0, z0 - 0.4)], "#fff4d8", opacity=0.13)
	if curtains:
		for zz in (z0 - 0.12, z1 + 0.02):
			quad(d, wall_quad(x + (0.04 if x < 0 else -0.04), y0 - 0.3, y1 + 0.2, zz, zz + 0.12), curtains, stroke=dark(curtains, 0.4), stroke_width=1)


def back_door(d, x, z, w=1.1, h=2.3, col=PANEL_L, frame=None, open_=False, beyond="#1a120c", panels=True):
	frame = frame or dark(col, 0.3)
	quad(d, back_quad(x - w / 2 - 0.12, x + w / 2 + 0.12, 0, h + 0.14, z), frame)
	if open_:
		quad(d, back_quad(x - w / 2, x + w / 2, 0, h, z), beyond)
		return
	quad(d, back_quad(x - w / 2, x + w / 2, 0, h, z), d.vlin(pt(0, h, z)[1], pt(0, 0, z)[1], [(0, light(col, 0.1)), (1, dark(col, 0.2))]))
	if panels:
		for sd in (-1, 1):
			for (ya, yb) in ((0.2, h * 0.45), (h * 0.55, h - 0.18)):
				xa = x + sd * 0.08 if sd > 0 else x - w / 2 + 0.1
				xb = x + w / 2 - 0.1 if sd > 0 else x - 0.08
				quad(d, back_quad(xa, xb, ya, yb, z), "none", stroke=dark(col, 0.45), stroke_width=2)
	knob = pt(x + w / 2 - 0.12, 1.0, z)
	d.circle(knob[0], knob[1], 3.5 * V.s(z), GILT, stroke=INK, stroke_width=1)


def side_door(d, x, z0, z1, h=2.3, col=PANEL_L, open_=False, beyond="#140c08"):
	quad(d, wall_quad(x, 0, h + 0.14, z0 - 0.12, z1 + 0.12), dark(col, 0.35))
	if open_:
		quad(d, wall_quad(x, 0, h, z0, z1), beyond)
		return
	quad(d, wall_quad(x, 0, h, z0, z1), dark(col, 0.1))
	for (ya, yb) in ((0.2, h * 0.45), (h * 0.55, h - 0.18)):
		quad(d, wall_quad(x, ya, yb, z0 + 0.1, z1 - 0.1), "none", stroke=dark(col, 0.5), stroke_width=2)
	k = pt(x, 1.0, z0 + 0.12)
	d.circle(k[0], k[1], 3.5 * V.s(z0), GILT)


PORTRAIT_COATS = ["#2a3a5a", "#4a2a2a", "#2a4a3a", "#3a3a3a", "#5a4a2a", "#3a2a4a"]


def portrait_art(d, x0, y0, w, h, kind, rng):
	"""What's in a picture frame (drawn into the box x0, y0, w, h)."""
	if kind == "sea":
		d.rect(x0, y0, w, h * 0.55, d.vlin(y0, y0 + h * 0.55, [(0, "#9ab8c8"), (1, "#e8e0c8")]))
		d.rect(x0, y0 + h * 0.55, w, h * 0.45, d.vlin(y0 + h * 0.55, y0 + h, [(0, "#4a7a8a"), (1, "#2a4a5a")]))
		d.path("M%s %s L%s %s L%s %s Z" % F(x0 + w * 0.3, y0 + h * 0.6, x0 + w * 0.42, y0 + h * 0.2, x0 + w * 0.5, y0 + h * 0.6), "#f4efe0")
		d.line(x0 + w * 0.42, y0 + h * 0.2, x0 + w * 0.42, y0 + h * 0.64, "#3a2a1a", max(1, w * 0.015))
		d.path("M%s %s Q%s %s %s %s Z" % F(x0 + w * 0.25, y0 + h * 0.62, x0 + w * 0.42, y0 + h * 0.72, x0 + w * 0.58, y0 + h * 0.62), "#3a2a1a")
	elif kind == "still":
		d.rect(x0, y0, w, h, d.vlin(y0, y0 + h, [(0, "#3a2a1a"), (1, "#1a120a")]))
		d.ellipse(x0 + w * 0.5, y0 + h * 0.78, w * 0.4, h * 0.06, "#6a4a2a")
		for (fx, fy, fr, c) in ((0.36, 0.66, 0.12, "#c8402a"), (0.55, 0.64, 0.13, "#e8b040"), (0.46, 0.55, 0.11, "#6a8a3a"), (0.66, 0.7, 0.08, "#8a2a5a")):
			d.circle(x0 + w * fx, y0 + h * fy, w * fr, c)
	elif kind == "warden":
		# the Warden himself in oils: a caiman in a frock coat and a top hat, one eye a red lamp
		d.rect(x0, y0, w, h, d.brad([(0, "#3a4a3a"), (1, "#121812")], cx=0.5, cy=0.4, r=0.75))
		cx = x0 + w * 0.5
		d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(x0 + w * 0.06, y0 + h, x0 + w * 0.1, y0 + h * 0.62, cx, y0 + h * 0.6,
			x0 + w * 0.9, y0 + h * 0.62, x0 + w * 0.94, y0 + h), "#1a1a24")
		d.path("M%s %s L%s %s L%s %s Z" % F(cx - w * 0.1, y0 + h * 0.62, cx + w * 0.1, y0 + h * 0.62, cx, y0 + h * 0.86), "#e8e0d0")
		d.path("M%s %s L%s %s L%s %s Z" % F(cx - w * 0.05, y0 + h * 0.66, cx + w * 0.05, y0 + h * 0.66, cx, y0 + h * 0.8), "#8e2b4a")
		snapjaw_crest(d, cx, y0 + h * 0.4, w / 125.0, ring=False)
	elif kind == "gaol":
		d.rect(x0, y0, w, h, d.vlin(y0, y0 + h, [(0, "#c8b89a"), (0.6, "#9aa8a8"), (1, "#4a5a5a")]))
		d.rect(x0 + w * 0.2, y0 + h * 0.4, w * 0.6, h * 0.25, "#5a5a62")
		for tx in (0.22, 0.5, 0.78):
			d.rect(x0 + w * (tx - 0.05), y0 + h * 0.28, w * 0.1, h * 0.37, "#4a4a52")
	else:
		# a past warden or officer: a stern capybara bust in a dark coat, gold buttons, against a brown ground
		coat = rng.choice(PORTRAIT_COATS)
		fur = rng.choice(["#8a6a48", "#7a5a3a", "#9a7a52", "#6a4e34"])
		d.rect(x0, y0, w, h, d.brad([(0, "#5a4430"), (1, "#1e1610")], cx=0.45, cy=0.35, r=0.75))
		cx = x0 + w * 0.5
		d.path("M%s %s Q%s %s %s %s L%s %s L%s %s Q%s %s %s %s Z" % F(x0 + w * 0.1, y0 + h, x0 + w * 0.12, y0 + h * 0.66, cx, y0 + h * 0.6,
			cx, y0 + h * 0.6, x0 + w * 0.9, y0 + h, x0 + w * 0.88, y0 + h * 0.66, cx, y0 + h * 0.6), coat)
		d.rect(x0 + w * 0.12, y0 + h * 0.7, w * 0.76, h * 0.3, coat)
		d.ellipse(cx, y0 + h * 0.42, w * 0.25, h * 0.2, fur)
		d.ellipse(cx, y0 + h * 0.5, w * 0.16, h * 0.1, light(fur, 0.12))
		for sd in (-1, 1):
			d.circle(cx + sd * w * 0.18, y0 + h * 0.25, w * 0.05, dark(fur, 0.2))
			d.circle(cx + sd * w * 0.09, y0 + h * 0.4, w * 0.025, "#120a06")
		if rng.random() < 0.5:
			d.rect(cx - w * 0.2, y0 + h * 0.1, w * 0.4, h * 0.1, "#141014")
			d.rect(cx - w * 0.28, y0 + h * 0.19, w * 0.56, h * 0.03, "#141014")
		for k in range(3):
			d.circle(cx, y0 + h * (0.75 + k * 0.08), w * 0.02, GILT_L)
		d.path("M%s %s L%s %s L%s %s Z" % F(cx - w * 0.06, y0 + h * 0.62, cx + w * 0.06, y0 + h * 0.62, cx, y0 + h * 0.72), "#e8e0d0")


def frame_back(d, x, y, w, h, z, kind="portrait", rng=None, frame=GILT, tilt=0.0, turned=False):
	"""A gilt-framed picture on a wall facing the viewer (x = centre, y = bottom, metres)."""
	rng = rng or random.Random(int(x * 13 + y * 7))
	p = pt(x, y + h, z)
	k = V.s(z)
	pw, ph = w * M * k, h * M * k
	with G(d, transform="rotate(%s %s %s)" % F(tilt, p[0], p[1] + ph / 2) if tilt else None):
		d.rect(p[0] - pw / 2 + 4, p[1] + 6, pw, ph, "#000000", opacity=0.3)
		d.rect(p[0] - pw / 2, p[1], pw, ph, d.vlin(p[1], p[1] + ph, [(0, light(frame, 0.25)), (0.5, frame), (1, dark(frame, 0.35))]),
			stroke=INK, stroke_width=1.5)
		bw = max(4, 0.07 * M * k)
		if turned:
			d.rect(p[0] - pw / 2 + bw * 0.5, p[1] + bw * 0.5, pw - bw, ph - bw, "#8a6a44")
			d.line(p[0] - pw / 2 + bw, p[1] + ph * 0.5, p[0] + pw / 2 - bw, p[1] + ph * 0.5, "#6a4e30", 2)
			d.line(p[0], p[1] + bw, p[0], p[1] + ph - bw, "#6a4e30", 2)
		else:
			portrait_art(d, p[0] - pw / 2 + bw, p[1] + bw, pw - bw * 2, ph - bw * 2, kind, rng)
			d.rect(p[0] - pw / 2 + bw, p[1] + bw, pw - bw * 2, ph - bw * 2, "none", stroke=dark(frame, 0.5), stroke_width=1.5)


def frame_side(d, x, y, z0, z1, h, kind="portrait", rng=None, frame=GILT, turned=False):
	"""A framed picture on a side wall, in perspective (art clipped into the frame's quad)."""
	rng = rng or random.Random(int(x * 13 + z0 * 7))
	outer = V.pts(wall_quad(x, y, y + h, z0, z1))
	b = 0.07
	inner = V.pts(wall_quad(x, y + b, y + h - b, z0 + b * 0.8, z1 - b * 0.8))
	d.poly(outer, d.lin(outer[0][0], 0, outer[1][0], 0, [(0, dark(frame, 0.2)), (1, light(frame, 0.15))]), stroke=INK, stroke_width=1.4)
	xs = [q[0] for q in inner]
	ys = [q[1] for q in inner]
	cp = d.clip('<polygon points="%s"/>' % " ".join("%s,%s" % F(qx, qy) for qx, qy in inner))
	with G(d, clip_path=cp):
		if turned:
			d.rect(min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys), "#8a6a44")
		else:
			# squash the art into the quad's bounding box: good enough at the angles we use
			portrait_art(d, min(xs), (min(ys) + max(ys)) / 2 - (max(ys) - min(ys)) * 0.42, max(xs) - min(xs), (max(ys) - min(ys)) * 0.84, kind, rng)
		d.poly(inner, "#000000", opacity=0.12)


def sconce3(d, x, y, z, lit=True, s=0.8):
	p = pt(x, y, z)
	B.wall_sconce(d, p[0], p[1], s * V.s(z) / 1.0 * 0.55, lit)


def chandelier3(d, x, y, z, lit=True, s=1.0, ceiling=None):
	p = pt(x, y, z)
	k = V.s(z) * s * 0.55
	if ceiling is not None:
		c = pt(x, ceiling, z)
		d.line(c[0], c[1], p[0], p[1] - 20 * k, "#2a1d14", max(1.5, 3 * k))
	with G(d, transform=T(0, 0)):
		B.chandelier(d, p[0], p[1], k, lit)


def crest_back(d, x, y, z, s=0.5):
	p = pt(x, y, z)
	snapjaw_crest(d, p[0], p[1], s * V.s(z) * 0.9)


def cam_back(d, x, y, z, flip=False, s=0.5):
	p = pt(x, y, z)
	croc_cam(d, p[0], p[1], s * V.s(z) * 0.9, flip=flip)


def rug(d, x0, x1, z0, z1, col=VELVET, border=GILT, a=1.0):
	quad(d, floor_quad(x0, x1, z0, z1, 0.004), col, opacity=a)
	inset = 0.16
	quad(d, floor_quad(x0 + inset, x1 - inset, z0 + inset, z1 - inset, 0.005), "none", stroke=border, stroke_width=3, opacity=0.8 * a)
	quad(d, floor_quad(x0 + inset * 2, x1 - inset * 2, z0 + inset * 2, z1 - inset * 2, 0.005), "none", stroke=dark(border, 0.2), stroke_width=1.5, opacity=0.6 * a)


def shade(d, a=0.25, col="#0a0614"):
	vignette(d, a, col, 0.5)


def night(d, a=0.42):
	d.rect(0, 0, W, H, "#0a0e22", opacity=a)


def light_pool(d, x, y, z, r, col=LANTERN, a=0.35):
	p = pt(x, y, z)
	glow(d, p[0], p[1], r * M * V.s(z), col, a)


# --------------------------------------------------------------------------------------
# furniture
# --------------------------------------------------------------------------------------
BOOK_COLS = ["#7a2a2a", "#2a4a6a", "#3a5a3a", "#8a6a2a", "#5a2a4a", "#2a2a3a", "#9a4a2a", "#4a3a2a", "#6a7a8a", "#a88a4a"]


def books_row(d, x0, x1, y, z, h, rng, lean=True):
	"""Spines on one shelf of a bookcase facing the viewer."""
	x = x0 + 0.01
	while x < x1 - 0.03:
		bw = rng.uniform(0.025, 0.06)
		bh = h * rng.uniform(0.7, 0.98)
		if x + bw > x1:
			break
		c = rng.choice(BOOK_COLS)
		quad(d, back_quad(x, x + bw, y, y + bh, z), c, stroke=dark(c, 0.5), stroke_width=0.6)
		if rng.random() < 0.4:
			hline(d, x, x + bw, y + bh * 0.8, z, GILT_L, 1, opacity=0.7)
		x += bw + (rng.uniform(0.0, 0.05) if rng.random() < 0.1 else 0.0)


def bookcase_back(d, x, z, w=1.6, h=2.8, rng=None, col=PANEL, depth=0.4, shelves=6, cornice_=True, empty=0.0):
	"""A tall bookcase standing against a back wall at depth z (its front face at z - depth)."""
	rng = rng or random.Random(int(x * 31 + z))
	zf = z - depth
	box3(d, x - w / 2, x + w / 2, 0, h, zf, z, col, top=dark(col, 0.1), side=dark(col, 0.25), sw=1.4)
	quad(d, back_quad(x - w / 2 + 0.06, x + w / 2 - 0.06, 0.12, h - 0.1, zf), dark(col, 0.55))
	sh = (h - 0.22) / shelves
	for i in range(shelves):
		y = 0.12 + i * sh
		if rng.random() >= empty:
			books_row(d, x - w / 2 + 0.06, x + w / 2 - 0.06, y + 0.03, zf + 0.04, sh - 0.06, rng)
		quad(d, back_quad(x - w / 2 + 0.06, x + w / 2 - 0.06, y, y + 0.03, zf), light(col, 0.12))
	if cornice_:
		box3(d, x - w / 2 - 0.05, x + w / 2 + 0.05, h, h + 0.1, zf - 0.04, z, dark(col, 0.05), sw=1.2)


def bookcase_side(d, x, z0, z1, h=2.8, rng=None, col=PANEL, depth=0.4, shelves=6):
	"""Bookcases standing along a side wall from depth z0 to z1, their fronts facing the room."""
	rng = rng or random.Random(int(x * 17 + z0 * 5))
	xf = x + depth if x < 0 else x - depth
	quad(d, [(x, h, z0), (xf, h, z0), (xf, h, z1), (x, h, z1)], dark(col, 0.1))
	quad(d, wall_quad(xf, 0, h, z0, z1), dark(col, 0.55))
	sh = (h - 0.22) / shelves
	for i in range(shelves):
		y = 0.12 + i * sh
		z = z1 - 0.04
		dd_cols = {}
		while z > z0 + 0.06:
			bw = rng.uniform(0.03, 0.07)
			c = rng.choice(BOOK_COLS)
			bh = (sh - 0.06) * rng.uniform(0.7, 0.98)
			dd_cols.setdefault(c, []).append(V.pts(wall_quad(xf, y + 0.03, y + 0.03 + bh, z - bw, z)))
			z -= bw
		for c, polys in dd_cols.items():
			dd = ""
			for p in polys:
				dd += "M" + " L".join("%s %s" % F(px, py) for px, py in p) + " Z "
			d.path(dd, c, stroke=dark(c, 0.5), stroke_width=0.5)
		quad(d, [(x, y + 0.03, z0), (xf, y + 0.03, z0), (xf, y + 0.03, z1), (x, y + 0.03, z1)], light(col, 0.1))
	# uprights every 1.2 m
	z = z1
	while z > z0 - 0.01:
		quad(d, wall_quad(xf, 0, h, max(z0, z - 0.05), z), col, stroke=INK, stroke_width=0.8)
		z -= 1.2
	quad(d, wall_quad(xf, h - 0.12, h + 0.06, z0, z1), dark(col, 0.05))
	quad(d, wall_quad(xf, 0, 0.12, z0, z1), dark(col, 0.3))


def table3(d, x0, x1, z0, z1, h=0.76, top=WOOD, legs=None, cloth=None, sw=1.4):
	legs = legs or dark(top, 0.3)
	t = 0.05
	for (lx, lz) in ((x0 + 0.06, z1 - 0.06), (x1 - 0.06, z1 - 0.06), (x0 + 0.06, z0 + 0.06), (x1 - 0.06, z0 + 0.06)):
		box3(d, lx - 0.03, lx + 0.03, 0, h - t, lz - 0.03, lz + 0.03, legs, sw=0.8)
	if cloth:
		box3(d, x0 - 0.05, x1 + 0.05, h - 0.3, h, z0 - 0.05, z1 + 0.05, cloth, top=light(cloth, 0.1), sw=sw)
	else:
		box3(d, x0, x1, h - t, h, z0, z1, top, top=light(top, 0.12), sw=sw)


def chair3(d, x, z, col=VELVET, wood=WOOD_D, facing="away", w=0.46):
	"""A dining chair. facing: 'away' (back toward viewer), 'toward', 'left' or 'right'."""
	seat = 0.46
	if facing == "away":
		for lx in (x - w / 2 + 0.03, x + w / 2 - 0.03):
			box3(d, lx - 0.025, lx + 0.025, 0, seat, z + w - 0.05, z + w, wood, sw=0.6)
		box3(d, x - w / 2, x + w / 2, seat - 0.06, seat, z, z + w, col, sw=1)
		for lx in (x - w / 2 + 0.03, x + w / 2 - 0.03):
			box3(d, lx - 0.025, lx + 0.025, 0, 1.0, z - 0.03, z + 0.02, wood, sw=0.6)
		box3(d, x - w / 2 + 0.02, x + w / 2 - 0.02, 0.55, 0.98, z - 0.04, z, col, sw=1)
	elif facing == "toward":
		box3(d, x - w / 2 + 0.02, x + w / 2 - 0.02, 0.5, 1.0, z + w - 0.04, z + w, col, sw=1)
		for lx in (x - w / 2 + 0.03, x + w / 2 - 0.03):
			box3(d, lx - 0.025, lx + 0.025, 0, seat, z, z + 0.05, wood, sw=0.6)
		box3(d, x - w / 2, x + w / 2, seat - 0.06, seat, z, z + w, col, sw=1)
	else:
		sd = -1 if facing == "left" else 1
		bx = x - sd * w / 2
		box3(d, min(bx, bx - sd * 0.05), max(bx, bx - sd * 0.05), 0.5, 1.0, z, z + w, col, sw=1)
		for lz in (z + 0.03, z + w - 0.03):
			box3(d, x - w / 2 + 0.02, x - w / 2 + 0.06, 0, seat, lz - 0.02, lz + 0.02, wood, sw=0.6)
			box3(d, x + w / 2 - 0.06, x + w / 2 - 0.02, 0, seat, lz - 0.02, lz + 0.02, wood, sw=0.6)
		box3(d, x - w / 2, x + w / 2, seat - 0.06, seat, z, z + w, col, sw=1)


def armchair3(d, x, z, col=VELVET, w=0.85):
	box3(d, x - w / 2, x + w / 2, 0.1, 1.05, z + w - 0.2, z + w, dark(col, 0.05), sw=1.2)
	box3(d, x - w / 2, x + w / 2, 0.08, 0.45, z, z + w, col, sw=1.2)
	box3(d, x - w / 2 + 0.12, x + w / 2 - 0.12, 0.45, 0.52, z + 0.02, z + w - 0.2, light(col, 0.1), sw=1)
	for sd in (-1, 1):
		ax0 = x + sd * (w / 2) - (0.16 if sd > 0 else 0.0)
		box3(d, ax0, ax0 + 0.16, 0.08, 0.68, z, z + w - 0.15, dark(col, 0.1), sw=1.1)


def long_table(d, x0, x1, z0, z1, h=0.76, cloth="#f2ede0", wood=WOOD_D, chairs=VELVET, places=True, candles=True, lit=True, rng=None):
	"""A long dining table running away from the viewer, with chairs down both sides and a place laid at each."""
	rng = rng or random.Random(5)
	n = max(2, int((z1 - z0) / 0.75))
	# far-side chairs first (painter's order: far to near)
	for i in reversed(range(n)):
		z = z0 + (z1 - z0) * (i + 0.5) / n
		chair3(d, x0 - 0.42, z - 0.23, chairs, wood, facing="right")
		chair3(d, x1 + 0.42, z - 0.23, chairs, wood, facing="left")
	table3(d, x0, x1, z0, z1, h, wood, cloth=cloth)
	if places:
		for i in range(n):
			z = z0 + (z1 - z0) * (i + 0.5) / n
			for sd in (-1, 1):
				px = (x0 + 0.2) if sd < 0 else (x1 - 0.2)
				ell3(d, px, h + 0.005, z, 0.13, 0.11, "#ffffff", stroke="#b8b0a0", stroke_width=0.8)
				ell3(d, px, h + 0.006, z, 0.08, 0.07, "#f4f0e8")
	if candles:
		for i in range(max(1, n // 2)):
			z = z0 + (z1 - z0) * (i + 0.5) / max(1, n // 2)
			cx = (x0 + x1) / 2
			b = pt(cx, h, z)
			k = V.s(z)
			d.rect(b[0] - 6 * k, b[1] - 6 * k, 12 * k, 6 * k, GILT, stroke=INK, stroke_width=0.8)
			for sd in (-1, 0, 1):
				cp = pt(cx + sd * 0.1, h + 0.3, z)
				d.line(b[0] + sd * 10 * k, b[1] - 4 * k, cp[0], cp[1], GILT_D, max(1, 2 * k))
				d.rect(cp[0] - 2 * k, cp[1] - 14 * k, 4 * k, 14 * k, "#fff8e8")
				if lit:
					glow(d, cp[0], cp[1] - 18 * k, 26 * k, LANTERN, 0.7)
					d.ellipse(cp[0], cp[1] - 18 * k, 2.5 * k, 4.5 * k, LANTERN_HOT)


def longcase_clock(d, x, z, h=2.2, col=PANEL_L, face="#f4ecd8", hands=(10, 10), base=0.0):
	box3(d, x - 0.26, x + 0.26, base, base + 0.5, z - 0.3, z, col, sw=1.4)
	box3(d, x - 0.2, x + 0.2, base + 0.5, base + h - 0.6, z - 0.26, z, dark(col, 0.08), sw=1.4)
	box3(d, x - 0.28, x + 0.28, base + h - 0.6, base + h, z - 0.32, z, col, sw=1.4)
	quad(d, back_quad(x - 0.24, x + 0.24, base + h - 0.02, base + h + 0.12, z - 0.3), dark(col, 0.15), stroke=INK, stroke_width=1)
	c = pt(x, base + h - 0.3, z - 0.33)
	k = V.s(z - 0.33)
	r = 0.19 * M * k
	d.circle(c[0], c[1], r + 3 * k, GILT, stroke=INK, stroke_width=1.2)
	d.circle(c[0], c[1], r, face)
	dd = ""
	for i in range(12):
		a = i / 12 * TAU
		dd += "M%s %s L%s %s " % F(c[0] + math.cos(a) * r * 0.82, c[1] + math.sin(a) * r * 0.82, c[0] + math.cos(a) * r * 0.95, c[1] + math.sin(a) * r * 0.95)
	d.spath(dd, INK, max(1, 1.2 * k))
	hh, mm = hands
	ah = (hh % 12 + mm / 60.0) / 12 * TAU - math.pi / 2
	am = mm / 60.0 * TAU - math.pi / 2
	d.line(c[0], c[1], c[0] + math.cos(ah) * r * 0.5, c[1] + math.sin(ah) * r * 0.5, INK, max(1.5, 2.5 * k))
	d.line(c[0], c[1], c[0] + math.cos(am) * r * 0.78, c[1] + math.sin(am) * r * 0.78, INK, max(1, 1.6 * k))
	# pendulum window
	pw = pt(x, base + 1.0, z - 0.27)
	d.ellipse(pw[0], pw[1], 0.08 * M * k, 0.2 * M * k, dark(col, 0.5), stroke=GILT_D, stroke_width=1)
	d.circle(pw[0], pw[1] + 0.1 * M * k, 0.05 * M * k, GILT)


def fireplace_back(d, x, z, w=1.6, h=1.2, col="#d8d0c0", lit=False, rng=None, mantel=True):
	"""A fireplace against a back wall: surround, mantel shelf, black opening, a grate."""
	zf = z - 0.3
	box3(d, x - w / 2, x + w / 2, 0, h, zf, z, col, sw=1.3)
	box3(d, x - w / 2 - 0.1, x + w / 2 + 0.1, h, h + 0.08, zf - 0.08, z, light(col, 0.05), sw=1.3)
	quad(d, back_quad(x - w * 0.32, x + w * 0.32, 0.0, h * 0.68, zf), "#0e0a08")
	quad(d, back_quad(x - w * 0.32, x + w * 0.32, h * 0.6, h * 0.68, zf), dark(col, 0.2))
	box3(d, x - w * 0.36, x + w * 0.36, 0, 0.04, zf - 0.32, zf, dark(col, 0.25), sw=1)
	g0 = pt(x - w * 0.22, 0.12, zf + 0.05)
	g1 = pt(x + w * 0.22, 0.12, zf + 0.05)
	k = V.s(zf)
	for i in range(6):
		gx = g0[0] + (g1[0] - g0[0]) * i / 5
		d.line(gx, g0[1], gx, g0[1] - 18 * k, "#2a2a2e", max(1.2, 2 * k))
	d.line(g0[0], g0[1] - 18 * k, g1[0], g1[1] - 18 * k, "#2a2a2e", max(1.5, 3 * k))
	if lit:
		c = pt(x, 0.25, zf + 0.1)
		glow(d, c[0], c[1], 0.9 * M * k, "#ff9a40", 0.65)
		for sd in (-1, 0, 1):
			d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(c[0] + sd * 14 * k - 10 * k, c[1] + 8 * k, c[0] + sd * 14 * k - 6 * k, c[1] - 20 * k,
				c[0] + sd * 14 * k, c[1] - 34 * k, c[0] + sd * 14 * k + 8 * k, c[1] - 16 * k, c[0] + sd * 14 * k + 10 * k, c[1] + 8 * k), "#ffb050")


def mantel_clock(d, x, y, z, hands=(5, 20), col=GILT, face="#f4ecd8", foot=None):
	p = pt(x, y, z)
	k = V.s(z)
	if foot:
		d.rect(p[0] - 25 * k, p[1] - 2 * k, 50 * k, 5 * k, foot, stroke=INK, stroke_width=0.8)
	d.path("M%s %s L%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(p[0] - 22 * k, p[1], p[0] + 22 * k, p[1], p[0] + 22 * k, p[1] - 30 * k, p[0], p[1] - 34 * k,
		p[0] - 22 * k, p[1] - 30 * k, p[0] - 22 * k, p[1]), col, stroke=INK, stroke_width=1)
	c = (p[0], p[1] - 18 * k)
	r = 11 * k
	d.circle(c[0], c[1], r, face, stroke=INK, stroke_width=0.8)
	hh, mm = hands
	ah = (hh % 12 + mm / 60.0) / 12 * TAU - math.pi / 2
	am = mm / 60.0 * TAU - math.pi / 2
	d.line(c[0], c[1], c[0] + math.cos(ah) * r * 0.5, c[1] + math.sin(ah) * r * 0.5, INK, max(1, 1.6 * k))
	d.line(c[0], c[1], c[0] + math.cos(am) * r * 0.8, c[1] + math.sin(am) * r * 0.8, INK, max(0.8, 1.0 * k))


def plant3(d, x, z, s=1.0, rng=None, pot="#7a4a32", leaf="#3f7a46", y=0.0):
	p = pt(x, y, z)
	B.potted_plant(d, p[0], p[1], s * V.s(z) * 0.5, pot, leaf, rng or random.Random(int(x * 10 + z)))


def palm3(d, x, z, h=2.2, rng=None):
	rng = rng or random.Random(int(x * 7 + z * 3))
	b = pt(x, 0, z)
	k = V.s(z)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(b[0] - 20 * k, b[1] - 40 * k, b[0] + 20 * k, b[1] - 40 * k, b[0] + 15 * k, b[1], b[0] - 15 * k, b[1]), "#8a4a2a",
		stroke=INK, stroke_width=1)
	top = pt(x + 0.1, h, z)
	d.spath("M%s %s Q%s %s %s %s" % F(b[0], b[1] - 40 * k, b[0] + 10 * k, (b[1] + top[1]) / 2, top[0], top[1]), "#6a5030", max(2, 7 * k))
	for i in range(9):
		a = -math.pi * 0.95 + i * math.pi * 0.9 / 8 + rng.uniform(-0.1, 0.1)
		ln = rng.uniform(0.7, 1.1) * M * k
		ex, ey = top[0] + math.cos(a) * ln, top[1] + math.sin(a) * ln * 0.6 + ln * 0.25
		mx, my = top[0] + math.cos(a) * ln * 0.5, top[1] + math.sin(a) * ln * 0.5 - 6 * k
		d.spath("M%s %s Q%s %s %s %s" % F(top[0], top[1], mx, my, ex, ey), "#3f7a46" if i % 2 else "#5a9a4a", max(2, 9 * k))


def gull(d, x, y, s=1.0, a=1.0):
	d.spath("M%s %s q%s %s %s %s q%s %s %s %s" % F(x - 10 * s, y, 5 * s, -6 * s, 10 * s, 0, 5 * s, -6 * s, 10 * s, 0), "#ffffff", 2 * s, opacity=a)


def bat_hanging(d, x, y, s=1.0):
	d.line(x, y - 8 * s, x, y, "#1a1414", 1.5 * s)
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(x - 6 * s, y, x - 8 * s, y + 14 * s, x, y + 20 * s, x + 8 * s, y + 14 * s, x + 6 * s, y), "#2a2024", stroke=INK, stroke_width=0.8)
	d.circle(x - 2 * s, y + 16 * s, 1 * s, "#ff5a40")


def notice_sheets(d, x0, x1, y0, y1, z, rng, n=7):
	"""Papers pinned to a board facing the viewer (scribbles, no text)."""
	for i in range(n):
		w = rng.uniform(0.22, 0.34)
		h = rng.uniform(0.26, 0.4)
		cx = x0 + 0.1 + (x1 - x0 - 0.2) * ((i % 4) + 0.5) / 4 + rng.uniform(-0.04, 0.04)
		cy = y0 + 0.08 + (y1 - y0 - 0.16) * (1 - ((i // 4) + 0.5) / 2) + rng.uniform(-0.04, 0.04)
		c = rng.choice(["#f4efe0", "#fbf2c8", "#e8eef4", "#f8e0d8", "#e4f0dc"])
		p = pt(cx - w / 2, cy + h / 2, z)
		k = V.s(z)
		pw, ph = w * M * k, h * M * k
		with G(d, transform="rotate(%s %s %s)" % F(rng.uniform(-5, 5), p[0] + pw / 2, p[1] + ph / 2)):
			d.rect(p[0] + 2, p[1] + 3, pw, ph, "#000000", opacity=0.25)
			d.rect(p[0], p[1], pw, ph, c, stroke="#8a8070", stroke_width=0.6)
			glyphs(d, p[0] + pw * 0.12, p[1] + ph * 0.12, pw * 0.76, ph * 0.7, rng.randint(3, 5), "#4a4038", rng, sw=max(0.8, 1.2 * k), a=0.75)
			d.circle(p[0] + pw / 2, p[1] + 4 * k, 3 * k, rng.choice(["#c8402a", "#2a6ac8", GILT]))


def coat(d, x, y, z, col, rng, w=0.42, h=1.0):
	"""A coat hanging from a hook at (x, y) on a back wall at depth z."""
	p = pt(x, y, z)
	k = V.s(z)
	pw, ph = w * M * k, h * M * k
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % F(
		p[0] - pw * 0.15, p[1] + 4 * k, p[0] - pw * 0.55, p[1] + ph * 0.15, p[0] - pw * 0.5, p[1] + ph * 0.5,
		p[0] - pw * 0.55, p[1] + ph, p[0], p[1] + ph * 1.04, p[0] + pw * 0.55, p[1] + ph,
		p[0] + pw * 0.5, p[1] + ph * 0.5, p[0] + pw * 0.55, p[1] + ph * 0.15, p[0] + pw * 0.15, p[1] + 4 * k),
		d.lin(p[0] - pw / 2, 0, p[0] + pw / 2, 0, [(0, dark(col, 0.3)), (0.5, col), (1, dark(col, 0.35))]), stroke=INK, stroke_width=1)
	d.line(p[0], p[1] + ph * 0.18, p[0], p[1] + ph, dark(col, 0.45), max(1, 1.5 * k))
	d.path("M%s %s L%s %s L%s %s Z" % F(p[0] - pw * 0.15, p[1] + 4 * k, p[0], p[1] + ph * 0.3, p[0] + pw * 0.15, p[1] + 4 * k), dark(col, 0.25))
	for j in range(3):
		d.circle(p[0] + pw * 0.06, p[1] + ph * (0.4 + j * 0.15), max(1, 2 * k), GILT_L)


# --------------------------------------------------------------------------------------
# the backgrounds
# --------------------------------------------------------------------------------------
def bg_manor_hall(d, tod="day"):
	"""The Grand Hall from the front door: marble chequer, the imperial staircase up to a half landing under the
	Warden's portrait, return flights to the gallery that runs round three sides overhead."""
	global V
	V = View(vy=335, eye=1.55, z0=15.0, m=44)
	rng = random.Random(301)
	r = Room(w=16.0, h=9.4, z0=0.8, z1=15.0)
	wall = HALL_G
	shell(d, r, back_grad(d, r, wall, dark(wall, 0.1)), side_grad(d, r, wall), side_grad(d, r, wall, False), MARBLE_D, ceil_grad(d, r, "#d8ccb4"))
	damask_back(d, r.x0, r.x1, 1.25, r.h - 0.3, r.z1, HALL_GM, 0.45, 0.6)
	damask_side(d, r.x0, 1.25, r.h - 0.3, 7.0, r.z1, HALL_GM, 0.35, 0.6)
	damask_side(d, r.x1, 1.25, r.h - 0.3, 7.0, r.z1, HALL_GM, 0.35, 0.6)
	for z in zs(9.0, r.z1, 3):
		quad(d, [(r.x0, r.h - 0.01, z - 0.14), (r.x1, r.h - 0.01, z - 0.14), (r.x1, r.h - 0.01, z + 0.14), (r.x0, r.h - 0.01, z + 0.14)], "#c4b498")
	cornice(d, r, CREAM, 0.3)
	wainscot(d, r, 1.25)
	chequer(d, r, tile=0.9, rng=rng)
	YL, Y2 = 2.3, 4.6
	zl = 12.4
	# back wall: the terrace's glazed door on the left, a tall window on the right, and high windows over the return flights
	back_window(d, -6.6, 0.0, 1.2, 2.4, r.z1, "night" if tod == "night" else "day", rng=rng, sill=False)
	back_window(d, 6.6, 0.9, 1.1, 2.0, r.z1, "night" if tod == "night" else "day", curtains="#5a1a20", rng=rng)
	for sd in (-1, 1):
		back_window(d, sd * 6.6, Y2 + 1.3, 1.1, 2.2, r.z1, "night" if tod == "night" else "day", curtains="#5a1a20", rng=rng, gaol=False)
	# the Warden in oils over the landing, his crest above, two sconces
	frame_back(d, 0, YL + 1.7, 2.0, 2.6, r.z1, "warden", random.Random(9), GILT)
	crest_back(d, 0, YL + 5.2, r.z1, 0.75)
	for sd in (-1, 1):
		sconce3(d, sd * 1.7, YL + 2.6, r.z1)
	# the half landing across the back, panelled underneath, with a cupboard door; a clock and a fern on it
	box3(d, -5.2, 5.2, 0, YL, zl, r.z1, PANEL, top=light(WOOD, 0.05), side=PANEL_D)
	quad(d, back_quad(-5.2, 5.2, 0.12, YL - 0.32, zl), dark(PANEL, 0.12))
	for i in range(8):
		xa = -5.0 + i * 1.3
		quad(d, back_quad(xa + 0.12, xa + 1.1, 0.3, YL - 0.5, zl), "none", stroke=dark(PANEL, 0.5), stroke_width=2)
	back_door(d, 2.5, zl, 0.8, 1.6, PANEL_L, panels=False)
	longcase_clock(d, -4.4, r.z1, 2.2, hands=(11, 5) if tod == "night" else (10, 20), base=YL)
	plant3(d, 4.5, r.z1 - 0.5, 1.1, y=YL)
	# the return flights, from the landing up toward us to the gallery on each side
	for sd in (-1, 1):
		x0, x1 = (3.4, 5.2) if sd > 0 else (-5.2, -3.4)
		steps = 14
		for i in range(steps):
			y = YL + (Y2 - YL) * i / steps
			za = zl - (zl - 7.6) * i / steps
			zb = zl - (zl - 7.6) * (i + 1) / steps
			box3(d, x0, x1, y, y + (Y2 - YL) / steps, zb, za, WOOD, top=light(WOOD, 0.22), side=WOOD_D, sw=0.7)
		inner = x0 if sd > 0 else x1
		a, b = pt(inner, YL + 1.0, zl), pt(inner, Y2 + 1.0, 7.6)
		for i in range(12):
			t = (i + 0.5) / 12
			p0, p1 = pt(inner, YL + (Y2 - YL) * t, zl - (zl - 7.6) * t), pt(inner, YL + (Y2 - YL) * t + 1.0, zl - (zl - 7.6) * t)
			d.line(p0[0], p0[1], p1[0], p1[1], PANEL_L, 3)
		d.line(a[0], a[1], b[0], b[1], PANEL, 7)
	# the gallery overhead on both sides: its underside, a fascia, its balustrade
	for (x, sd) in ((r.x0, 1), (r.x1, -1)):
		xe = x + sd * 4.6
		quad(d, [(x, Y2 - 0.3, r.z0), (xe, Y2 - 0.3, r.z0), (xe, Y2 - 0.3, 7.6), (x, Y2 - 0.3, 7.6)], dark(PANEL, 0.25))
		for z in zs(r.z0, 7.6, 5):
			quad(d, [(x, Y2 - 0.31, z - 0.06), (xe, Y2 - 0.31, z - 0.06), (xe, Y2 - 0.31, z + 0.06), (x, Y2 - 0.31, z + 0.06)], PANEL_D)
		quad(d, wall_quad(xe, Y2 - 0.36, Y2, r.z0, 7.6), PANEL_D, stroke=INK, stroke_width=1)
		quad(d, back_quad(min(x, xe), max(x, xe), Y2 - 0.36, Y2, 7.6), PANEL_D, stroke=INK, stroke_width=1)
		dd = ""
		for z in zs(r.z0 + 0.4, 7.6, 22):
			a, b = pt(xe, Y2, z), pt(xe, Y2 + 0.95, z)
			dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
		d.spath(dd, PANEL_L, 3)
		side_line(d, xe, Y2 + 1.0, r.z0, 7.6, PANEL, 7)
	# doors on the side walls under the gallery: kitchen (left), marble bath (right)
	side_door(d, r.x0, 10.4, 11.6, 2.3, PANEL_L)
	side_door(d, r.x1, 10.4, 11.6, 2.3, PANEL_L)
	for (x, z) in ((r.x0, 9.6), (r.x1, 9.6), (r.x0, 12.4), (r.x1, 12.4)):
		sconce3(d, x * 0.995, 2.4, z, tod == "night" or True, 0.7)
	cam_back(d, r.x1 - 0.3, 3.6, 13.6, flip=True, s=0.5)
	# the centre flight coming down toward us, a red runner up the middle, newel posts with gilt finials
	steps = 14
	for i in range(steps):
		y0 = YL - YL * (i + 1) / steps
		za = zl - (zl - 7.6) * i / steps
		zb = zl - (zl - 7.6) * (i + 1) / steps
		box3(d, -1.6, 1.6, y0, y0 + YL / steps, zb, za, WOOD, top=light(WOOD, 0.22), side=WOOD_D, sw=0.7)
		quad(d, [(-0.8, y0 + YL / steps + 0.004, zb), (0.8, y0 + YL / steps + 0.004, zb), (0.8, y0 + YL / steps + 0.004, za), (-0.8, y0 + YL / steps + 0.004, za)], "#7a1a20")
		quad(d, back_quad(-0.8, 0.8, y0, y0 + YL / steps, zb), "#5a1018")
	for sd in (-1, 1):
		for i in range(12):
			t = (i + 0.5) / 12
			za = zl - (zl - 7.6) * t
			ya = YL - YL * t
			p0, p1 = pt(sd * 1.62, ya, za), pt(sd * 1.62, ya + 1.0, za)
			d.line(p0[0], p0[1], p1[0], p1[1], PANEL_L, 3)
		a, b = pt(sd * 1.62, YL + 1.0, zl), pt(sd * 1.62, 1.0, 7.6)
		d.line(a[0], a[1], b[0], b[1], PANEL, 7)
		box3(d, sd * 1.62 - 0.13, sd * 1.62 + 0.13, 0, 1.25, 7.36, 7.62, PANEL, sw=1.2)
		nb = pt(sd * 1.62, 1.36, 7.5)
		d.circle(nb[0], nb[1], 0.13 * V.m * V.s(7.5), GILT, stroke=INK, stroke_width=1)
	# earthquake damage: cracks up the walls, a slipped picture rail, plaster on the marble
	crack(d, -6.0, 8.8, r.z1, rng, 10, 0.4)
	crack(d, 3.4, 9.0, r.z1, rng, 7, 0.35, dirx=-0.5)
	crack(d, r.x1, 7.6, 10.0, rng, 6, 0.35, side=True)
	plaster_lumps(d, 4.6, 9.2, rng, 10, 0.6)
	plaster_lumps(d, -3.8, 6.6, rng, 6, 0.4)
	rug(d, -2.5, 2.5, 3.0, 6.2, "#4a0e16", GILT, 0.95)
	if tod == "night":
		night(d, 0.48)
		for sd in (-1, 1):
			light_pool(d, sd * 1.7, YL + 2.6, r.z1, 1.6, LANTERN, 0.5)
		light_pool(d, 0, 6.0, 6.0, 4.0, LANTERN, 0.18)
	else:
		light_pool(d, 0, 5.0, 8.0, 5.0, "#fff2d8", 0.12)
	shade(d, 0.3)


def bg_manor_hall_night(d):
	bg_manor_hall(d, "night")


def side_clock(d, x, z, h=2.2, col=PANEL_L, hands=(8, 5)):
	"""A longcase clock standing against a side wall, its face turned to the room."""
	sd = 1 if x < 0 else -1
	xf = x + sd * 0.34
	box3(d, min(x, xf), max(x, xf), 0, h, z - 0.26, z + 0.26, col, top=light(col, 0.1), side=dark(col, 0.1), sw=1.2)
	c = pt(xf, h - 0.32, z)
	k = V.s(z)
	r = 0.17 * M * k
	d.ellipse(c[0], c[1], r * 0.62, r, "#f4ecd8", stroke=GILT, stroke_width=max(1.5, 2.5 * k))
	hh, mm = hands
	ah = (hh % 12 + mm / 60.0) / 12 * TAU - math.pi / 2
	am = mm / 60.0 * TAU - math.pi / 2
	d.line(c[0], c[1], c[0] + math.cos(ah) * r * 0.3, c[1] + math.sin(ah) * r * 0.5, INK, max(1.5, 2 * k))
	d.line(c[0], c[1], c[0] + math.cos(am) * r * 0.48, c[1] + math.sin(am) * r * 0.78, INK, max(1, 1.4 * k))
	pw = pt(xf, 1.0, z)
	d.ellipse(pw[0], pw[1], 0.05 * M * k, 0.2 * M * k, dark(col, 0.5), stroke=GILT_D, stroke_width=1)


def bg_manor_dining(d, tod="evening"):
	"""The Dining Room down the length of its table: the fireplace at the far end, the tall clock on the left wall,
	windows over the sea on the right, the chandelier lit for dinner."""
	global V
	V = View(vy=290, eye=1.5, z0=13.0, m=58)
	rng = random.Random(402)
	r = Room(w=8.0, h=3.8, z0=1.0, z1=13.0)
	shell(d, r, back_grad(d, r, OXBLOOD), side_grad(d, r, OXBLOOD), side_grad(d, r, OXBLOOD, False), WOOD, ceil_grad(d, r, "#d6c8ac"))
	damask_back(d, r.x0, r.x1, 1.1, r.h - 0.25, r.z1, OXBLOOD_M, 0.5, 0.42)
	damask_side(d, r.x0, 1.1, r.h - 0.25, 4.0, r.z1, OXBLOOD_M, 0.4, 0.42)
	damask_side(d, r.x1, 1.1, r.h - 0.25, 4.0, r.z1, OXBLOOD_M, 0.4, 0.42)
	cornice(d, r, CREAM, 0.22)
	wainscot(d, r, 1.1)
	parquet(d, r, WOOD)
	view = "day" if tod == "day" else "night"
	# the far end: fireplace, a painting of the Gaol over it, the crest, sconces
	fireplace_back(d, 0, r.z1, 1.8, 1.25, "#d8d0c0", lit=(tod != "day"), rng=rng)
	frame_back(d, 0, 1.75, 1.6, 1.1, r.z1, "gaol", rng)
	crest_back(d, 0, 3.25, r.z1, 0.4)
	for sd in (-1, 1):
		sconce3(d, sd * 1.4, 2.2, r.z1)
		plant3(d, sd * 2.9, r.z1 - 0.4, 1.0)
	cam_back(d, r.x0 + 0.25, 3.3, r.z1 - 0.1, s=0.4)
	# windows on the right (the sea side), a sideboard and the tall clock on the left
	for zc in (5.0, 8.0, 11.0):
		side_window(d, r.x1, 0.95, 3.0, zc - 0.6, zc + 0.6, view, rng, gaol=(zc == 11.0), curtains="#3a0a10")
	box3(d, r.x0, r.x0 + 0.5, 0, 0.92, 9.6, 11.4, PANEL, top=light(WOOD, 0.1), side=dark(PANEL, 0.1), sw=1.2)
	for (zz, c) in ((9.9, "#e8e4dc"), (10.3, "#c8a040"), (10.9, "#e8e4dc")):
		b = pt(r.x0 + 0.25, 0.92, zz)
		k = V.s(zz)
		d.rect(b[0] - 6 * k, b[1] - 18 * k, 12 * k, 18 * k, c, stroke=INK, stroke_width=0.8)
	frame_side(d, r.x0, 1.6, 9.7, 11.3, 1.1, "still", rng)
	side_clock(d, r.x0, 7.6, 2.3, PANEL_L, hands=(8, 5) if tod != "day" else (8, 40))
	frame_side(d, r.x0, 1.7, 4.6, 6.2, 1.2, "portrait", rng)
	# the long table, laid, with the chairs down both sides and the candelabra
	long_table(d, -0.65, 0.65, 4.2, 11.0, cloth="#f2ede0", wood=WOOD_D, chairs=VELVET, lit=(tod != "day"), rng=rng)
	chandelier3(d, 0, 2.8, 7.6, lit=True, s=1.1, ceiling=r.h)
	crack(d, 2.6, 3.6, r.z1, rng, 6, 0.3)
	if tod != "day":
		night(d, 0.35)
		light_pool(d, 0, 1.2, 7.6, 3.4, LANTERN, 0.3)
		light_pool(d, 0, 0.5, r.z1 - 0.4, 1.2, "#ff9a40", 0.35)
	shade(d, 0.32)


def bg_manor_dining_day(d):
	bg_manor_dining(d, "day")


def bg_manor_cloakroom(d):
	"""The cloakroom outside the Dining Room: a brass hook and a little card for every guest, an arch through to dinner."""
	global V
	V = View(vy=300, eye=1.5, z0=5.5, m=118)
	rng = random.Random(503)
	r = Room(w=5.4, h=3.4, z0=0.9, z1=5.5)
	wall = "#4a3a2c"
	shell(d, r, back_grad(d, r, OXBLOOD), side_grad(d, r, OXBLOOD), side_grad(d, r, OXBLOOD, False), "#6a5040", ceil_grad(d, r, "#d6c8ac"))
	damask_back(d, r.x0, r.x1, 1.1, r.h - 0.2, r.z1, OXBLOOD_M, 0.45, 0.36)
	damask_side(d, r.x0, 1.1, r.h - 0.2, r.z0, r.z1, OXBLOOD_M, 0.35, 0.36)
	damask_side(d, r.x1, 1.1, r.h - 0.2, r.z0, r.z1, OXBLOOD_M, 0.35, 0.36)
	cornice(d, r, CREAM, 0.18)
	wainscot(d, r, 1.1)
	chequer(d, r, "#c8b48a", "#7a3a2a", 0.3, rng=rng)
	# the arch through to the Dining Room, warm light beyond, a glimpse of the table and the clock
	ax = 0.0
	arch = []
	for i in range(13):
		a = math.pi * i / 12
		arch.append((ax - 0.75 * math.cos(a), 2.15 + 0.5 * math.sin(a), r.z1))
	arch = [(ax - 0.75, 0, r.z1)] + arch + [(ax + 0.75, 0, r.z1)]
	quad(d, [(p[0] * 1.18, p[1] * 1.06 if p[1] > 0 else 0, p[2]) for p in arch], CREAM_D, stroke=INK, stroke_width=1.2)
	pa = V.pts(arch)
	d.poly(pa, d.vlin(pa[6][1], pa[0][1], [(0, "#5a2018"), (1, "#3a1a10")]))
	cp = d.clip('<polygon points="%s"/>' % " ".join("%s,%s" % F(x, y) for x, y in pa))
	with G(d, clip_path=cp):
		glow(d, pt(0, 1.6, r.z1)[0], pt(0, 1.6, r.z1)[1], 140, LANTERN, 0.6)
		t0, t1 = pt(-0.3, 0.76, r.z1), pt(0.3, 0.76, r.z1)
		d.poly([(t0[0] - 30, t0[1] + 40), (t1[0] + 30, t1[1] + 40), (t1[0] + 4, t1[1] - 6), (t0[0] - 4, t0[1] - 6)], "#f2ede0")
		for sd in (-1, 1):
			for j in range(3):
				cx = pt(sd * 0.42, 0.9, r.z1)[0] + sd * j * 14
				d.rect(cx - 6, t0[1] - 10 + j * 14, 12, 34, VELVET)
		c = pt(0, 2.2, r.z1)
		d.circle(c[0], c[1], 12, "#f4ecd8", stroke=GILT, stroke_width=3)
	# the hooks: brass, in a row on oak boards either side of the arch, a card over each and most of them in use
	cols = ["#2a3a5a", "#6a2a2a", "#3a5a3a", "#5a4a3a", "#2a2a2a", "#7a5a2a", "#4a2a5a", "#2a5a6a", "#8a3a2a", "#3a3a4a", "#6a6a4a"]
	slots = [-2.45, -2.0, -1.55, -1.1, 1.1, 1.55, 2.0, 2.45]
	for sd in (-1, 1):
		x0, x1 = (-2.65, -0.95) if sd < 0 else (0.95, 2.65)
		box3(d, x0, x1, 1.72, 1.92, r.z1 - 0.04, r.z1, PANEL_L, sw=1)
	for i, x in enumerate(slots):
		upright(d, x, 2.02, r.z1 - 0.01, 0.2, 0.09, "#f4efe0", stroke="#8a7a60", stroke_width=0.8)
		hb = pt(x, 1.82, r.z1 - 0.06)
		k = V.s(r.z1)
		d.spath("M%s %s q%s %s %s %s" % F(hb[0], hb[1], 0, 8 * k, 6 * k, 10 * k), GILT_D, max(1.5, 3 * k))
		d.circle(hb[0], hb[1], 3 * k, GILT)
		if i not in (2, 6):
			coat(d, x, 1.82, r.z1 - 0.08, cols[i], rng, 0.4, 0.95)
	# side walls: more hooks running toward us, a bench with a hat on it, an umbrella stand, a mirror
	for zc in (2.6, 3.3, 4.0, 4.7):
		for x in (r.x0, r.x1):
			upright_hook = pt(x, 1.82, zc)
			d.circle(upright_hook[0], upright_hook[1], 4 * V.s(zc), GILT, stroke=INK, stroke_width=1)
	frame_side(d, r.x0, 1.25, 3.0, 4.2, 1.1, "sea", rng, GILT)
	box3(d, r.x1 - 0.4, r.x1, 0, 0.45, 2.6, 4.4, PANEL_L, sw=1.2)
	b = pt(r.x1 - 0.2, 0.45, 3.8)
	k = V.s(3.8)
	d.ellipse(b[0], b[1] - 4 * k, 20 * k, 6 * k, "#3a2a4a", stroke=INK, stroke_width=1)
	d.rect(b[0] - 12 * k, b[1] - 22 * k, 24 * k, 18 * k, "#3a2a4a", stroke=INK, stroke_width=1)
	box3(d, -2.4, -2.05, 0, 0.6, 4.8, 5.1, "#6a6a6a", sw=1)
	for j in range(3):
		a, bb = pt(-2.32 + j * 0.1, 0.55, 4.95), pt(-2.36 + j * 0.12, 1.05, 4.95)
		d.line(a[0], a[1], bb[0], bb[1], ["#2a2a2a", "#6a2a2a", "#2a4a2a"][j], 4)
	cam_back(d, r.x1 - 0.3, 3.0, r.z1 - 0.1, flip=True, s=0.5)
	crack(d, -1.4, 3.3, r.z1, rng, 5, 0.25)
	light_pool(d, 0, 1.4, r.z1, 2.6, LANTERN, 0.25)
	shade(d, 0.3)


def bg_manor_kitchen(d):
	"""The kitchen: the range under its hood, copper pans on a rack, the dresser of plates, a scrubbed table,
	the sink under the window; the door to the pantry on the right."""
	global V
	V = View(vy=300, eye=1.5, z0=7.0, m=92)
	rng = random.Random(604)
	r = Room(w=8.6, h=3.6, z0=1.0, z1=7.0)
	wall = "#d8d2b8"
	shell(d, r, back_grad(d, r, wall), side_grad(d, r, wall), side_grad(d, r, wall, False), STONE, ceil_grad(d, r, "#e0d8c0"))
	# green-glazed tiles to shoulder height
	for (x, on) in ((r.x0, True), (r.x1, True)):
		quad(d, wall_quad(x, 0, 1.45, r.z0, r.z1), "#3e7a64")
		dd = ""
		for y in [0.15 * i for i in range(1, 10)]:
			a, b = pt(x, y, r.z0), pt(x, y, r.z1)
			dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
		d.spath(dd, "#2a5a48", 1, opacity=0.6)
	quad(d, back_quad(r.x0, r.x1, 0, 1.45, r.z1), "#3e7a64")
	dd = ""
	for i in range(1, 10):
		a, b = pt(r.x0, i * 0.15, r.z1), pt(r.x1, i * 0.15, r.z1)
		dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
	for i in range(int((r.x1 - r.x0) / 0.15)):
		a, b = pt(r.x0 + i * 0.15, 0, r.z1), pt(r.x0 + i * 0.15, 1.45, r.z1)
		dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
	d.spath(dd, "#2a5a48", 1, opacity=0.6)
	hline(d, r.x0, r.x1, 1.45, r.z1, "#2a4a3a", 4)
	cornice(d, r, "#efe8d4", 0.12)
	flagstones(d, r, "#a89a80", 0.6, rng)
	# the range under its copper hood
	box3(d, -1.2, 1.2, 0, 0.9, r.z1 - 0.7, r.z1, "#1e1e22", top="#3a3a40", side="#141416", sw=1.4)
	for i in range(3):
		quad(d, back_quad(-1.05 + i * 0.75, -0.45 + i * 0.75, 0.15, 0.7, r.z1 - 0.7), "#2a2a30", stroke=GILT_D, stroke_width=1.2)
		k = pt(-0.75 + i * 0.75, 0.62, r.z1 - 0.71)
		d.rect(k[0] - 8, k[1] - 2, 16, 4, GILT)
	ell3(d, -0.6, 0.905, r.z1 - 0.35, 0.22, 0.15, "#4a4a50")
	box3(d, 0.2, 0.75, 0.9, 1.25, r.z1 - 0.55, r.z1 - 0.15, "#8a8a92", top="#b0b0b8", sw=1.2)
	ell3(d, 0.47, 1.25, r.z1 - 0.35, 0.27, 0.2, "#c8b48a")
	steam(d, random.Random(3), pt(0.3, 1.4, r.z1)[0], pt(0, 2.4, r.z1)[1], pt(0.7, 1.4, r.z1)[0], pt(0, 1.4, r.z1)[1], 4, 0.14, 20, 50)
	quad(d, [(-1.4, 2.6, r.z1 - 0.9), (1.4, 2.6, r.z1 - 0.9), (0.9, 3.4, r.z1 - 0.3), (-0.9, 3.4, r.z1 - 0.3)], "#b06a38", stroke=INK, stroke_width=1.4)
	quad(d, back_quad(-0.9, 0.9, 3.4, r.h, r.z1 - 0.3), "#9a5a2e", stroke=INK, stroke_width=1.2)
	quad(d, back_quad(-1.4, 1.4, 2.5, 2.6, r.z1 - 0.9), "#7a4a24", stroke=INK, stroke_width=1)
	# copper pans hanging from a rail
	a, b = pt(-1.6, 2.35, 3.6), pt(1.6, 2.35, 3.6)
	d.line(a[0], a[1], b[0], b[1], "#3a3a3a", 4)
	for (xa, ya) in ((-1.6, 2.35), (1.6, 2.35)):
		p0, p1 = pt(xa, ya, 3.6), pt(xa, r.h, 3.6)
		d.line(p0[0], p0[1], p1[0], p1[1], "#3a3a3a", 2)
	for i in range(6):
		x = -1.35 + i * 0.54
		hk = pt(x, 2.35, 3.6)
		k = V.s(3.6)
		rr = (0.11 + 0.03 * (i % 3)) * M * k
		d.line(hk[0], hk[1], hk[0], hk[1] + 14 * k, "#3a3a3a", 2)
		d.rect(hk[0] - 2 * k, hk[1] + 12 * k, 4 * k, 24 * k, "#8a4a20")
		d.circle(hk[0], hk[1] + 36 * k + rr, rr, d.brad([(0, "#f0a060"), (0.6, "#c06a30"), (1, "#7a3a14")], cx=0.35, cy=0.35, r=0.7), stroke=INK, stroke_width=1)
	# the dresser of plates on the left of the back wall
	box3(d, -3.9, -2.3, 0, 0.95, r.z1 - 0.55, r.z1, "#6a8a6a", top="#c8b890", sw=1.2)
	box3(d, -3.8, -2.4, 0.95, 2.6, r.z1 - 0.28, r.z1, "#6a8a6a", sw=1.2)
	for j in range(3):
		y = 1.15 + j * 0.48
		quad(d, back_quad(-3.72, -2.48, y - 0.02, y, r.z1 - 0.28), "#4a6a4a")
		for i in range(5):
			c = pt(-3.58 + i * 0.27, y + 0.15, r.z1 - 0.26)
			d.circle(c[0], c[1], 0.12 * M * V.s(r.z1 - 0.26), "#f4f0e8", stroke="#2a6aa0", stroke_width=2)
	# the window over the sink on the right of the back wall
	back_window(d, 3.0, 1.3, 1.2, 1.5, r.z1, "day", rng=rng, curtains=None)
	box3(d, 2.2, 3.8, 0, 0.9, r.z1 - 0.6, r.z1, "#e8e4d8", top="#f4f0e8", sw=1.2)
	ell3(d, 3.0, 0.905, r.z1 - 0.3, 0.45, 0.2, "#9aa8a8")
	# the side doors: to the dining room (left), the pantry doorway (right, open), the cellar stairs door
	side_door(d, r.x0, 2.6, 3.6, 2.2, "#2a5a3a")
	side_door(d, r.x1, 3.4, 4.4, 2.2, "#2a5a3a", open_=True, beyond="#3a3226")
	# shelves through the pantry door
	for j in range(3):
		y = 0.8 + j * 0.5
		quad(d, wall_quad(r.x1 + 0.6, y, y + 0.02, 3.5, 4.3), "#c8b890")
		for i in range(4):
			c = pt(r.x1 + 0.55, y + 0.08, 3.6 + i * 0.18)
			d.rect(c[0] - 3, c[1] - 8, 6, 9, rng.choice(["#c8402a", "#e8b040", "#6a8a3a", "#a8a8b0"]))
	side_door(d, r.x0, 5.0, 6.0, 2.2, WOOD_D)
	# the scrubbed table, a stool, the pot of soup, bread, a knife block
	table3(d, -1.4, 1.4, 2.4, 3.4, 0.8, "#d8c49a", legs="#6a4a2a")
	for (x, c) in ((-0.9, "#b05a30"), (0.1, "#e8d8b0"), (0.8, "#6a6a72")):
		b = pt(x, 0.8, 2.9)
		k = V.s(2.9)
		if c == "#e8d8b0":
			d.ellipse(b[0], b[1] - 8 * k, 24 * k, 10 * k, "#c89a5a", stroke=INK, stroke_width=1)
		elif c == "#6a6a72":
			d.rect(b[0] - 10 * k, b[1] - 24 * k, 20 * k, 24 * k, "#5a3a24", stroke=INK, stroke_width=1)
			for j in range(4):
				d.line(b[0] - 7 * k + j * 5 * k, b[1] - 24 * k, b[0] - 7 * k + j * 5 * k, b[1] - 38 * k, "#c0c4cc", 2 * k)
		else:
			d.rect(b[0] - 26 * k, b[1] - 34 * k, 52 * k, 34 * k, d.lin(b[0] - 26 * k, 0, b[0] + 26 * k, 0, [(0, "#8a4a24"), (0.5, "#d0804a"), (1, "#7a3a1a")]), stroke=INK, stroke_width=1)
			d.ellipse(b[0], b[1] - 34 * k, 26 * k, 6 * k, "#5a2a14")
	crest_back(d, 2.8, 3.1, r.z1, 0.35)
	cam_back(d, r.x0 + 0.2, 3.1, r.z1 - 0.2, s=0.45)
	crack(d, -1.8, 3.4, r.z1, rng, 6, 0.25)
	light_pool(d, 0, 2.2, 3.4, 2.4, "#fff2d8", 0.2)
	shade(d, 0.28)


def bg_manor_pantry(d):
	"""The pantry: newspaper-lined shelves of tins and jars, and at the end the dumbwaiter hatch with its bell,
	the bell's paper tape, and under the sill the little door to the bottom of the shaft."""
	global V
	V = View(vy=300, eye=1.5, z0=4.2, m=150)
	rng = random.Random(705)
	r = Room(w=3.2, h=3.2, z0=0.7, z1=4.2)
	wall = "#d8cfb4"
	shell(d, r, back_grad(d, r, wall), side_grad(d, r, wall), side_grad(d, r, wall, False), "#8a7a62", ceil_grad(d, r, "#d8d0b8"))
	wainscot(d, r, 1.0, "#3e6a58", panels=False)
	flagstones(d, r, "#9a8a70", 0.5, rng)
	# shelves down both sides, lined with old newspaper hanging over the front edges
	for x in (r.x0, r.x1):
		xf = x + 0.42 if x < 0 else x - 0.42
		for j in range(5):
			y = 0.5 + j * 0.45
			quad(d, [(x, y, r.z0), (xf, y, r.z0), (xf, y, r.z1), (x, y, r.z1)], "#b8a882", stroke=dark("#b8a882", 0.4), stroke_width=1)
			quad(d, wall_quad(xf, y - 0.07, y, r.z0, r.z1), "#ece4cc", stroke="#a89a7a", stroke_width=0.6)
			dd = ""
			for z in zs(r.z0 + 0.2, r.z1 - 0.1, 14):
				a, b = pt(xf, y - 0.055, z), pt(xf, y - 0.015, z)
				dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
			d.spath(dd, "#7a7060", 1, opacity=0.6)
			z = r.z1 - 0.12
			xc = xf - 0.12 if x < 0 else xf + 0.12
			while z > 1.7:
				c = rng.choice(["#b8503a", "#d8a840", "#6a8a4a", "#9aa0a8", "#e8e0c8", "#8a5a3a", "#4a6a8a"])
				hgt = rng.uniform(0.1, 0.2)
				rad_ = rng.uniform(0.035, 0.05)
				b = pt(xc, y, z)
				k = V.s(z)
				w_, h_ = rad_ * M * k, hgt * M * k
				glass = rng.random() < 0.4
				d.rect(b[0] - w_, b[1] - h_, w_ * 2, h_, d.lin(b[0] - w_, 0, b[0] + w_, 0, [(0, dark(c, 0.3)), (0.4, light(c, 0.15)), (1, dark(c, 0.4))]),
					stroke=INK, stroke_width=0.6, opacity=0.85 if glass else 1.0)
				d.ellipse(b[0], b[1] - h_, w_, w_ * 0.3, "#c8c0b0" if glass else light(c, 0.2), stroke=INK, stroke_width=0.5)
				if not glass:
					d.rect(b[0] - w_, b[1] - h_ * 0.65, w_ * 2, h_ * 0.35, "#f4efe0", opacity=0.8)
				z -= rad_ * 2 + rng.uniform(0.01, 0.06)
	# the hatch: a framed opening in the end wall, its shutter down, the rope gap beside it, the bell over it
	hx, hy, hw_, hh_ = 0.0, 0.9, 0.7, 0.7
	quad(d, back_quad(hx - hw_ / 2 - 0.1, hx + hw_ / 2 + 0.1, hy - 0.12, hy + hh_ + 0.12, r.z1), PANEL, stroke=INK, stroke_width=1.5)
	quad(d, back_quad(hx - hw_ / 2, hx + hw_ / 2, hy, hy + hh_, r.z1), "#1a120c")
	quad(d, back_quad(hx - hw_ / 2 + 0.02, hx + hw_ / 2 - 0.12, hy + 0.02, hy + hh_ - 0.02, r.z1), "#6a3a1a", stroke=INK, stroke_width=1)
	for i in range(5):
		hline(d, hx - hw_ / 2 + 0.04, hx + hw_ / 2 - 0.14, hy + 0.1 + i * 0.12, r.z1, "#4a2a12", 2)
	a, b = pt(hx + hw_ / 2 - 0.06, hy + hh_, r.z1), pt(hx + hw_ / 2 - 0.06, hy, r.z1)
	d.line(a[0], a[1], b[0], b[1], "#c8b48a", 3)
	box3(d, hx - hw_ / 2 - 0.12, hx + hw_ / 2 + 0.12, hy - 0.16, hy - 0.1, r.z1 - 0.22, r.z1, PANEL_L, sw=1)
	upright(d, hx, hy + hh_ + 0.2, r.z1, 0.36, 0.1, GILT, stroke=INK, stroke_width=1)
	glyphs(d, *pt(hx - 0.14, hy + hh_ + 0.28, r.z1), 0.28 * M * V.s(r.z1), 0.06 * M * V.s(r.z1), 1, INK, rng, sw=1.6)
	# the bell on its spring, and the little tape machine that punches a mark for every trip
	bp = pt(hx + 0.62, hy + hh_ + 0.25, r.z1)
	k = V.s(r.z1)
	d.spath("M%s %s q%s %s %s %s q%s %s %s %s" % F(bp[0], bp[1] - 30 * k, 10 * k, 6 * k, 0, 12 * k, -10 * k, 6 * k, 0, 12 * k), GILT_D, 2 * k)
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % F(bp[0] - 12 * k, bp[1] + 10 * k, bp[0] - 10 * k, bp[1] - 8 * k, bp[0], bp[1] - 8 * k,
		bp[0], bp[1] - 8 * k, bp[0] + 10 * k, bp[1] - 8 * k, bp[0] + 12 * k, bp[1] + 10 * k), GILT, stroke=INK, stroke_width=1)
	tp = pt(hx + 0.62, hy + 0.05, r.z1 - 0.02)
	d.rect(tp[0] - 16 * k, tp[1] - 26 * k, 32 * k, 26 * k, "#2a2a30", stroke=INK, stroke_width=1)
	d.rect(tp[0] - 6 * k, tp[1] - 4 * k, 12 * k, 60 * k, "#f4efe0", stroke="#a89a7a", stroke_width=0.6)
	d.circle(tp[0], tp[1] + 14 * k, 2 * k, INK)
	# under the sill: the little door to the bottom of the shaft
	quad(d, back_quad(hx - 0.3, hx + 0.3, 0.12, 0.6, r.z1), "#4a2a14", stroke=INK, stroke_width=1.2)
	kn = pt(hx + 0.22, 0.36, r.z1)
	d.circle(kn[0], kn[1], 3 * k, GILT)
	# a sack of flour, a basket of onions, a bait tin on the top shelf (yellow, with a croc on it)
	b = pt(-0.9, 0, 2.8)
	k = V.s(2.8)
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % F(b[0] - 30 * k, b[1], b[0] - 34 * k, b[1] - 50 * k, b[0] - 14 * k, b[1] - 66 * k,
		b[0] + 14 * k, b[1] - 66 * k, b[0] + 34 * k, b[1] - 50 * k, b[0] + 30 * k, b[1]), "#c8b088", stroke=INK, stroke_width=1.2)
	b = pt(0.95, 0, 3.0)
	k = V.s(3.0)
	d.ellipse(b[0], b[1] - 14 * k, 28 * k, 16 * k, "#a87a3a", stroke=INK, stroke_width=1)
	for i in range(5):
		d.circle(b[0] - 14 * k + i * 7 * k, b[1] - 26 * k, 7 * k, "#c89a5a", stroke=INK, stroke_width=0.6)
	cam_back(d, -0.6, 2.7, r.z1, s=0.5)
	crack(d, 0.9, 3.1, r.z1, rng, 6, 0.22)
	glow(d, pt(0, 3.0, 2.4)[0], pt(0, 3.0, 2.4)[1], 260, LANTERN, 0.22)
	shade(d, 0.36)


def bg_manor_cellar(d):
	"""The wine cellar: a brick barrel vault, racks of bottles both sides, barrels on cradles, a tasting table,
	Snapjaw's bait tins on a shelf, bats asleep up in the vault, the generator room door at the far end."""
	global V
	V = View(vy=320, eye=1.5, z0=12.0, m=62)
	rng = random.Random(806)
	r = Room(w=5.6, h=3.6, z0=1.2, z1=12.0)
	d.rect(0, 0, W, H, "#140c08")
	# floor, then the vault as a run of brick arches (painted far to near)
	flagstones(d, r, "#5a4a3a", 0.7, rng)
	spring = 1.8
	rad = (r.x1 - r.x0) / 2
	bricks_back(d, r.x0, r.x1, 0, spring, r.z1, BRICK)
	arch_pts = [(-rad * math.cos(math.pi * i / 16), spring + rad * 0.9 * math.sin(math.pi * i / 16), r.z1) for i in range(17)]
	quad(d, arch_pts, d.vlin(pt(0, spring + rad * 0.9, r.z1)[1], pt(0, spring, r.z1)[1], [(0, dark(BRICK, 0.5)), (1, BRICK)]))
	back_door(d, 0, r.z1, 1.0, 2.1, "#4a4a52", frame="#2a2a30", panels=False)
	for i in range(4):
		hline(d, -0.45, 0.45, 0.3 + i * 0.5, r.z1, "#2a2a30", 2)
	upright(d, 0, 2.18, r.z1, 0.6, 0.14, "#e8d8a0", stroke=INK, stroke_width=1)
	for x in (r.x0, r.x1):
		bricks_side(d, x, 0, spring, r.z0, r.z1, BRICK)
	zz = zs(r.z0, r.z1, 14)
	for i in range(len(zz) - 1):
		za, zb = zz[i], zz[i + 1]
		for j in range(16):
			a0, a1 = math.pi * j / 16, math.pi * (j + 1) / 16
			p = [(-rad * math.cos(a0), spring + rad * 0.9 * math.sin(a0), za), (-rad * math.cos(a1), spring + rad * 0.9 * math.sin(a1), za),
				(-rad * math.cos(a1), spring + rad * 0.9 * math.sin(a1), zb), (-rad * math.cos(a0), spring + rad * 0.9 * math.sin(a0), zb)]
			shade_t = 0.15 + 0.35 * abs(math.cos((a0 + a1) / 2))
			quad(d, p, dark(BRICK, shade_t + (0.08 if (i + j) % 2 else 0.0)))
	for z in zs(r.z0 + 0.6, r.z1, 6):
		ribs = [pt(-rad * math.cos(math.pi * j / 20), spring + rad * 0.9 * math.sin(math.pi * j / 20), z) for j in range(21)]
		d.pline(ribs, dark(BRICK, 0.6), 3)
	# racks of bottles along both walls
	for x in (r.x0, r.x1):
		xf = x + 0.5 if x < 0 else x - 0.5
		for z0_, z1_ in ((2.6, 5.6), (6.6, 10.6)):
			quad(d, wall_quad(xf, 0, 1.75, z0_, z1_), "#2a1a10")
			dd = {}
			for j in range(7):
				y = 0.15 + j * 0.23
				for zc in zs(z0_ + 0.1, z1_ - 0.1, int((z1_ - z0_) / 0.14)):
					c = rng.choice(["#1a3a1a", "#3a1a2a", "#2a2a1a", "#1a2a3a"])
					p = pt(xf, y, zc)
					dd.setdefault(c, []).append((p, 0.06 * M * V.s(zc)))
			for c, items in dd.items():
				for (p, rr) in items:
					d.circle(p[0], p[1], rr, c)
			for j in range(8):
				side_line(d, xf, 0.04 + j * 0.23, z0_, z1_, "#5a3a20", 2)
			quad(d, [(x, 1.75, z0_), (xf, 1.75, z0_), (xf, 1.75, z1_), (x, 1.75, z1_)], "#4a2e18")
	# barrels on cradles near the far end, a tasting table with a candle and a glass, the stool in the dark
	for (bx_, bz_) in ((-1.9, 10.9), (1.9, 10.9)):
		c = pt(bx_, 0.55, bz_)
		k = V.s(bz_)
		d.ellipse(c[0], c[1], 0.45 * M * k, 0.5 * M * k, d.brad([(0, "#9a6a3a"), (1, "#5a3a1a")]), stroke=INK, stroke_width=1.2)
		for rr in (0.38, 0.22):
			d.ellipse(c[0], c[1], rr * M * k, (rr + 0.05) * M * k, "none", stroke="#3a3a3a", stroke_width=max(1, 2 * k))
		d.circle(c[0], c[1], 4 * k, "#2a1a0a")
	table3(d, -0.5, 0.5, 6.8, 7.6, 0.8, "#6a4a2a")
	b = pt(0, 0.8, 7.2)
	k = V.s(7.2)
	d.rect(b[0] - 3 * k, b[1] - 18 * k, 6 * k, 18 * k, "#fff8e8")
	glow(d, b[0], b[1] - 24 * k, 70 * k, LANTERN, 0.6)
	d.ellipse(b[0], b[1] - 22 * k, 2.5 * k, 4.5 * k, LANTERN_HOT)
	g = pt(0.25, 0.8, 7.0)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(g[0] - 6 * k, g[1] - 24 * k, g[0] + 6 * k, g[1] - 24 * k, g[0] + 1 * k, g[1] - 12 * k, g[0] - 1 * k, g[1] - 12 * k), "#8a2a3a", opacity=0.8)
	d.line(g[0], g[1] - 12 * k, g[0], g[1], "#d8e0e8", 1.5 * k)
	box3(d, 1.2, 1.5, 0, 0.6, 4.8, 5.1, "#4a3020", sw=1)
	# the shelf of bait tins, left, with their cartoon labels
	sx = r.x0 + 0.52
	quad(d, [(r.x0, 1.95, 6.0), (sx, 1.95, 6.0), (sx, 1.95, 6.6), (r.x0, 1.95, 6.6)], "#6a4a2a")
	for i in range(3):
		zc = 6.08 + i * 0.18
		box3(d, sx - 0.24, sx - 0.06, 1.95, 2.1, zc, zc + 0.13, "#e8c030", sw=0.8)
		p = pt(sx - 0.06, 2.03, zc + 0.065)
		d.circle(p[0], p[1], 3, "#2a6a2a")
	# bats asleep up in the vault
	for (bx_, bz_) in ((-0.6, 4.0), (0.4, 5.2), (1.1, 3.6), (-1.3, 6.4), (0.2, 8.0)):
		p = pt(bx_, spring + math.sqrt(max(0.0, rad * rad - bx_ * bx_)) * 0.9 - 0.05, bz_)
		bat_hanging(d, p[0], p[1], V.s(bz_) * 0.9)
	# a bulb on a flex
	bulb = pt(0, 2.9, 5.0)
	d.line(bulb[0], 0, bulb[0], bulb[1], "#1a1a1a", 2)
	glow(d, bulb[0], bulb[1], 200, LANTERN, 0.35)
	d.circle(bulb[0], bulb[1], 7, LANTERN_HOT)
	shade(d, 0.5)


def bg_manor_generator(d):
	"""The Generator Room: whitewashed brick, the diesel generator on its plinth, fuel drums, the switchboard of
	knife switches, and the logbook on its little desk under a clock."""
	global V
	V = View(vy=300, eye=1.5, z0=7.0, m=96)
	rng = random.Random(907)
	r = Room(w=8.0, h=3.4, z0=1.0, z1=7.0)
	wash = "#e4e0d6"
	d.rect(0, 0, W, H, "#2a2a2a")
	quad(d, [(r.x0, r.h, r.z0), (r.x1, r.h, r.z0), (r.x1, r.h, r.z1), (r.x0, r.h, r.z1)], ceil_grad(d, r, "#c8c4ba"))
	flagstones(d, r, "#8a8a84", 0.8, rng)
	bricks_back(d, r.x0, r.x1, 0, r.h, r.z1, wash, 0.075, 0.23, 0.35)
	for x in (r.x0, r.x1):
		bricks_side(d, x, 0, r.h, r.z0, r.z1, wash, 0.075, 0.23, 0.3)
	for x in (r.x0, r.x1):
		quad(d, wall_quad(x, 0, 0.9, r.z0, r.z1), "#4a5a52", opacity=0.9)
	quad(d, back_quad(r.x0, r.x1, 0, 0.9, r.z1), "#4a5a52", opacity=0.9)
	# the switchboard: a slate panel of knife switches and fuses, on the back wall
	quad(d, back_quad(1.0, 3.2, 1.0, 2.5, r.z1), "#2a2e32", stroke=INK, stroke_width=1.5)
	for i in range(4):
		for j in range(2):
			x = 1.25 + i * 0.52
			y = 1.3 + j * 0.62
			quad(d, back_quad(x - 0.12, x + 0.12, y, y + 0.06, r.z1), "#c8c4b8")
			a, b = pt(x, y + 0.06, r.z1 - 0.02), pt(x + (0.05 if (i + j) % 2 else -0.05), y + 0.38, r.z1 - 0.12)
			d.line(a[0], a[1], b[0], b[1], "#a8a8b0", 4)
			d.circle(b[0], b[1], 5, "#1a1a1a")
	upright(d, 2.1, 2.55, r.z1, 1.0, 0.12, "#e8d8a0", stroke=INK, stroke_width=1)
	# pipes and conduit
	for y in (2.9, 3.05):
		hline(d, r.x0, r.x1, y, r.z1, "#5a5a5a", 6)
	# the little desk with the logbook, a clock above it
	table3(d, -3.6, -2.4, r.z1 - 0.65, r.z1 - 0.05, 0.78, "#7a5a3a")
	b = pt(-3.0, 0.78, r.z1 - 0.35)
	k = V.s(r.z1 - 0.35)
	d.poly([(b[0] - 26 * k, b[1] - 2 * k), (b[0] + 26 * k, b[1] - 2 * k), (b[0] + 22 * k, b[1] - 12 * k), (b[0] - 22 * k, b[1] - 12 * k)], "#f4efe0", stroke="#8a7a60", stroke_width=1)
	d.line(b[0], b[1] - 2 * k, b[0], b[1] - 12 * k, "#8a7a60", 1)
	c = pt(-3.0, 2.3, r.z1)
	d.circle(c[0], c[1], 22, "#f4efe0", stroke="#2a2a2a", stroke_width=4)
	d.line(c[0], c[1], c[0] + 7, c[1] - 9, INK, 3)
	d.line(c[0], c[1], c[0] - 2, c[1] - 16, INK, 2)
	# the generator on its plinth in the middle of the room
	box3(d, -1.6, 1.2, 0, 0.25, 3.4, 5.4, "#8a8a84", sw=1.2)
	box3(d, -1.4, 0.4, 0.25, 1.35, 3.6, 5.2, "#2e5a3a", top="#3e7a4e", side="#1e3a26", sw=1.6)
	for i in range(6):
		quad(d, back_quad(-1.3 + i * 0.28, -1.15 + i * 0.28, 0.45, 1.15, 3.6), "#1e3a26")
	cyl_c = pt(0.8, 0.9, 3.6)
	k = V.s(3.6)
	d.ellipse(cyl_c[0], cyl_c[1], 0.36 * M * k, 0.45 * M * k, "#2e5a3a", stroke=INK, stroke_width=1.4)
	d.ellipse(cyl_c[0], cyl_c[1], 0.2 * M * k, 0.25 * M * k, "#9a9a9a", stroke=INK, stroke_width=1)
	for i in range(3):
		g = pt(-0.9 + i * 0.3, 1.5, 4.0)
		d.circle(g[0], g[1], 10, "#f4efe0", stroke="#2a2a2a", stroke_width=3)
		d.line(g[0], g[1], g[0] + 5, g[1] - 5, "#c8402a", 2)
	ex0, ex1 = pt(-0.5, 1.35, 4.4), pt(-0.5, r.h, 4.4)
	d.line(ex0[0], ex0[1], ex1[0], ex1[1], "#3a3a3a", 18)
	# fuel drums
	for (x, z, c) in ((2.6, 5.6, "#b8402a"), (3.2, 5.0, "#2a4a8a"), (2.9, 4.3, "#b8402a")):
		b = pt(x, 0, z)
		k = V.s(z)
		w_, h_ = 0.3 * M * k, 0.9 * M * k
		d.rect(b[0] - w_, b[1] - h_, w_ * 2, h_, d.lin(b[0] - w_, 0, b[0] + w_, 0, [(0, dark(c, 0.4)), (0.5, c), (1, dark(c, 0.5))]), stroke=INK, stroke_width=1)
		d.ellipse(b[0], b[1] - h_, w_, w_ * 0.3, light(c, 0.1), stroke=INK, stroke_width=1)
		for t in (0.3, 0.7):
			d.line(b[0] - w_, b[1] - h_ * t, b[0] + w_, b[1] - h_ * t, dark(c, 0.5), 2)
	side_door(d, r.x0, 1.6, 2.6, 2.1, "#4a4a52")
	cam_back(d, r.x1 - 0.2, 2.9, r.z1 - 0.1, flip=True, s=0.45)
	bulb = pt(0, 3.0, 4.2)
	d.line(bulb[0], 0, bulb[0], bulb[1], "#1a1a1a", 2)
	glow(d, bulb[0], bulb[1], 300, "#fff4d8", 0.35)
	d.circle(bulb[0], bulb[1], 8, "#fffbe8")
	crack(d, -1.4, 3.3, r.z1, rng, 6, 0.3)
	shade(d, 0.38)


def bg_manor_library(d, after=False):
	"""The Library from its door: bookcases to the cornice, the tall one behind the desk braced to the wall under the
	ledge; on the right wall the dumbwaiter hatch, the side table with its box of pens, the tapestry; the fireplace left.
	after=True: the morning it was found. The bookcase has come down across the desk, books cover the floor, white dust."""
	global V
	V = View(vy=290, eye=1.5, z0=8.5, m=70)
	rng = random.Random(1001)
	r = Room(w=10.0, h=4.6, z0=1.0, z1=8.5)
	shell(d, r, back_grad(d, r, LIB_G), side_grad(d, r, LIB_G), side_grad(d, r, LIB_G, False), WOOD, ceil_grad(d, r, "#d0c4a8"))
	damask_back(d, r.x0, r.x1, 1.05, r.h - 0.25, r.z1, LIB_GM, 0.5, 0.4)
	damask_side(d, r.x0, 1.05, r.h - 0.25, 4.0, r.z1, LIB_GM, 0.4, 0.4)
	damask_side(d, r.x1, 1.05, r.h - 0.25, 4.0, r.z1, LIB_GM, 0.4, 0.4)
	cornice(d, r, CREAM, 0.22)
	wainscot(d, r, 1.05)
	parquet(d, r, WOOD)
	rug(d, -2.3, 1.9, 2.2, 5.6, "#5a1418", GILT, 0.95)
	# the deep ledge along the back wall above the bookcases
	box3(d, r.x0, r.x1, 3.55, 3.7, r.z1 - 0.24, r.z1, PANEL, sw=1.2)
	bc_h = 3.3
	for (x, w_, seed) in ((-3.6, 1.7, 11), (2.5, 1.7, 12), (4.15, 1.3, 13)):
		bookcase_back(d, x, r.z1, w_, bc_h, random.Random(seed), PANEL, 0.42, 7)
	tall_x, tall_w = -0.5, 1.5
	if not after:
		bookcase_back(d, tall_x, r.z1, tall_w, bc_h, random.Random(14), PANEL, 0.45, 7)
		# the brace: an iron strap from the bookcase's top to the wall at each side, bolted under the ledge
		for sd in (-1, 1):
			bx = tall_x + sd * (tall_w / 2 + 0.06)
			quad(d, back_quad(bx - 0.06, bx + 0.06, bc_h - 0.2, bc_h - 0.1, r.z1), "#3a3a3e", stroke=INK, stroke_width=0.8)
			for yy in (bc_h - 0.15,):
				c = pt(bx + sd * 0.03, yy, r.z1)
				d.circle(c[0], c[1], 2.2, "#a8a8b0")
	else:
		# two clean screw holes where the brace's plates were
		for sd in (-1, 1):
			bx = tall_x + sd * (tall_w / 2 + 0.07)
			quad(d, back_quad(bx - 0.05, bx + 0.05, bc_h - 0.19, bc_h - 0.11, r.z1), dark(LIB_G, 0.2))
			c = pt(bx, bc_h - 0.15, r.z1)
			d.circle(c[0], c[1], 2.4, "#0a0806")
		quad(d, back_quad(tall_x - tall_w / 2, tall_x + tall_w / 2, 0, bc_h, r.z1), dark(LIB_G, 0.35))
		damask_back(d, tall_x - tall_w / 2, tall_x + tall_w / 2, 1.05, bc_h, r.z1, LIB_GM, 0.25, 0.4)
	# the left wall: a bookcase, the fireplace with a clock and a seascape, an armchair
	bookcase_side(d, r.x0, 6.6, 8.3, bc_h, random.Random(16), PANEL, 0.42, 7)
	fx = r.x0
	quad(d, wall_quad(fx + 0.3, 0, 1.2, 4.2, 5.8), "#4a4642", stroke=INK, stroke_width=1.2)
	quad(d, [(fx, 1.2, 4.1), (fx + 0.38, 1.2, 4.1), (fx + 0.38, 1.2, 5.9), (fx, 1.2, 5.9)], "#5a5652", stroke=INK, stroke_width=1)
	quad(d, wall_quad(fx + 0.3, 0, 0.8, 4.6, 5.4), "#0e0a08")
	frame_side(d, r.x0, 1.65, 4.4, 5.6, 0.8, "sea", rng)
	mantel_clock(d, fx + 0.2, 1.2, 5.0, (3, 0) if not after else (11, 5))
	armchair3(d, -3.4, 4.2, "#2a4a34", 0.8)
	sconce3(d, r.x0, 2.4, 6.0, True, 0.7)
	# the right wall: a bookcase, the dumbwaiter hatch, the side table, the tapestry over the servants' door
	bookcase_side(d, r.x1, 7.3, 8.3, bc_h, random.Random(15), PANEL, 0.42, 7)
	hx = r.x1
	quad(d, wall_quad(hx, 0.75, 1.65, 6.3, 7.1), PANEL, stroke=INK, stroke_width=1.2)
	quad(d, wall_quad(hx, 0.85, 1.55, 6.4, 7.0), "#0a0806")
	shutter_top = 1.55 - (0.16 if after else 0.0)
	quad(d, wall_quad(hx, 0.85, shutter_top, 6.4, 7.0), "#5a3418", stroke=INK, stroke_width=1)
	for i in range(4):
		side_line(d, hx, 0.95 + i * 0.14, 6.42, 6.98, "#3a2010", 2)
	quad(d, wall_quad(hx, 1.72, 1.8, 6.55, 6.85), GILT, stroke=INK, stroke_width=0.8)
	quad(d, [(hx, 0.85, 6.3), (hx - 0.18, 0.85, 6.3), (hx - 0.18, 0.85, 7.1), (hx, 0.85, 7.1)], PANEL_L)
	# side table with the box of pens and, on the last night, the teacup (not after: the cup is gone by morning)
	table3(d, hx - 0.65, hx - 0.15, 5.4, 5.9, 0.72, WOOD, legs=WOOD_D)
	pb = pt(hx - 0.42, 0.72, 5.62)
	k = V.s(5.62)
	d.poly([(pb[0] - 14 * k, pb[1]), (pb[0] + 14 * k, pb[1]), (pb[0] + 12 * k, pb[1] - 5 * k), (pb[0] - 12 * k, pb[1] - 5 * k)], "#1e3458", stroke=INK, stroke_width=0.6)
	for i in range(6):
		d.line(pb[0] - 10 * k + i * 4 * k, pb[1] - 5 * k, pb[0] - 10 * k + i * 4 * k, pb[1] - 7 * k, "#1a1a1e", 1.5 * k)
	if after:
		ell3(d, hx - 0.3, 0.722, 5.75, 0.04, 0.035, "none", stroke="#5a3418", stroke_width=1.2)
	tz0, tz1 = 4.0, 5.1
	quad(d, wall_quad(hx - 0.02, 0.2, 2.9, tz0, tz1), d.lin(pt(hx, 1, tz0)[0], 0, pt(hx, 1, tz1)[0], 0,
		[(0, "#4a3a28"), (0.3, "#7a6040"), (0.6, "#5a4a30"), (1, "#7a5a38")]), stroke=INK, stroke_width=1.2)
	for i in range(1, 6):
		zc = tz0 + (tz1 - tz0) * i / 6
		a, b = pt(hx - 0.03, 0.22, zc), pt(hx - 0.03, 2.88, zc)
		d.line(a[0], a[1], b[0], b[1], "#3a2a1a", 1.2, opacity=0.6)
	for (yy, zc, rr, c) in ((1.9, 4.3, 0.22, "#3a5a2e"), (1.4, 4.7, 0.25, "#4a6a34"), (0.9, 4.4, 0.2, "#3a5a2e"), (1.2, 4.55, 0.12, "#a88a5a")):
		p0 = pt(hx - 0.04, yy, zc)
		d.ellipse(p0[0], p0[1], rr * M * V.s(zc) * 0.35, rr * M * V.s(zc), c, opacity=0.9)
	side_line(d, hx - 0.05, 2.95, tz0 - 0.1, tz1 + 0.1, GILT_D, 4)
	sconce3(d, r.x1, 2.4, 6.9, True, 0.7)
	cam_back(d, r.x1 - 0.2, 3.5, r.z1 - 0.1, flip=True, s=0.45)
	# the desk facing the tall bookcase, its chair; lamp, blotter, papers, inkstand
	dz0, dz1 = 6.5, 7.3
	if not after:
		table3(d, tall_x - 1.0, tall_x + 1.0, dz0, dz1, 0.79, "#4a2814", legs="#3a1e0e")
		for sd in (-1, 1):
			box3(d, tall_x + sd * 0.72 - 0.25, tall_x + sd * 0.72 + 0.25, 0, 0.74, dz0, dz1, "#4a2814", sw=1.1)
		quad(d, floor_quad(tall_x - 0.92, tall_x + 0.92, dz0 + 0.07, dz1 - 0.07, 0.8), "#2a4a34")
		quad(d, floor_quad(tall_x - 0.95, tall_x - 0.45, dz0 + 0.12, dz1 - 0.2, 0.805), "#e8e8e0")
		lp = pt(tall_x + 0.85, 0.8, dz0 + 0.3)
		k = V.s(dz0 + 0.3)
		d.line(lp[0], lp[1], lp[0], lp[1] - 30 * k, GILT_D, 2 * k)
		d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(lp[0] - 14 * k, lp[1] - 28 * k, lp[0] + 14 * k, lp[1] - 28 * k, lp[0] + 9 * k, lp[1] - 40 * k, lp[0] - 9 * k, lp[1] - 40 * k), "#2a6a3a")
		glow(d, lp[0], lp[1] - 20 * k, 60 * k, LANTERN, 0.5)
		chair3(d, tall_x, dz0 - 0.55, "#2a4a34", WOOD_D, facing="away", w=0.52)
	else:
		# the desk, half under it; the chair pushed back; the bookcase lying across them both
		table3(d, tall_x - 1.0, tall_x + 1.0, dz0, dz1, 0.79, "#4a2814", legs="#3a1e0e")
		for sd in (-1, 1):
			box3(d, tall_x + sd * 0.72 - 0.25, tall_x + sd * 0.72 + 0.25, 0, 0.74, dz0, dz1, "#4a2814", sw=1.1)
		chair3(d, tall_x - 0.05, dz0 - 0.6, "#2a4a34", WOOD_D, facing="away", w=0.52)
		# him, slumped forward over the desk from the chair, in his white coat (seen from behind)
		c0 = pt(tall_x, 0.95, dz0 - 0.2)
		k = V.s(dz0 - 0.2)
		d.path("M%s %s Q%s %s %s %s Q%s %s %s %s L%s %s Z" % F(c0[0] - 34 * k, c0[1] + 30 * k, c0[0] - 40 * k, c0[1] - 20 * k, c0[0] - 10 * k, c0[1] - 36 * k,
			c0[0] + 30 * k, c0[1] - 40 * k, c0[0] + 40 * k, c0[1] - 6 * k, c0[0] + 36 * k, c0[1] + 30 * k), "#ecebe6", stroke=INK, stroke_width=1.4)
		d.line(c0[0], c0[1] - 34 * k, c0[0] + 2 * k, c0[1] + 28 * k, "#c8c6c0", 1.5)
		hd = pt(tall_x + 0.05, 0.92, dz0 + 0.15)
		d.ellipse(hd[0], hd[1] - 8 * k, 20 * k, 14 * k, "#8a6a4a", stroke=INK, stroke_width=1.2)
		for sd in (-1, 1):
			d.circle(hd[0] + sd * 12 * k, hd[1] - 20 * k, 5 * k, "#6a4e34", stroke=INK, stroke_width=0.8)
		arm = [pt(tall_x + 0.3, 0.86, dz0 + 0.0), pt(tall_x + 0.62, 0.84, dz0 + 0.25)]
		d.line(arm[0][0], arm[0][1], arm[1][0], arm[1][1], "#ecebe6", 9 * k)
		# the bookcase, walked forward and come down face first across the desk, a little twisted: we see its back
		piv_z = r.z1 - 0.75
		bl, br = (tall_x - tall_w / 2, 0.0, piv_z + 0.45), (tall_x + tall_w / 2, 0.0, piv_z + 0.45)
		tl, tr = (tall_x - tall_w / 2 - 0.15, 1.25, piv_z - 2.55), (tall_x + tall_w / 2 - 0.1, 1.75, piv_z - 2.35)
		depth = 0.45
		# books spilling out from under it first, then its sides, its back, its top end
		for i in range(26):
			t = rng.uniform(0.15, 1.0)
			x_ = tall_x + rng.uniform(-1.0, 1.0)
			z_ = piv_z - 2.6 * t - rng.uniform(0.0, 0.5)
			p_ = pt(x_, 0.82 if 6.4 < z_ < 7.4 and abs(x_ - tall_x) < 1.0 else 0.0, z_)
			k_ = V.s(z_)
			with G(d, transform="rotate(%s %s %s)" % F(rng.uniform(-60, 60), p_[0], p_[1])):
				d.rect(p_[0] - 10 * k_, p_[1] - 4 * k_, 20 * k_, 7 * k_, rng.choice(BOOK_COLS), stroke=INK, stroke_width=0.6)
		for (b0, t0) in ((bl, tl), (br, tr)):
			quad(d, [b0, (b0[0], b0[1] + depth * 0.2, b0[2] - depth), (t0[0], t0[1] + depth * 0.85, t0[2] - depth * 0.4), t0], PANEL_D, stroke=INK, stroke_width=1.2)
		back = [bl, br, tr, tl]
		quad(d, back, d.vlin(pt(*tr)[1], pt(*bl)[1], [(0, "#6a4024"), (1, "#3a2210")]), stroke=INK, stroke_width=1.8)
		for i in range(1, 6):
			t = i / 6.0
			a3 = (bl[0] + (br[0] - bl[0]) * t, 0.0, bl[2])
			b3 = (tl[0] + (tr[0] - tl[0]) * t, tl[1] + (tr[1] - tl[1]) * t, tl[2] + (tr[2] - tl[2]) * t)
			pa, pb = pt(*a3), pt(*b3)
			d.line(pa[0], pa[1], pb[0], pb[1], "#2a180a", 2, opacity=0.8)
		quad(d, [tl, tr, (tr[0], tr[1] + depth * 0.9, tr[2] - depth * 0.3), (tl[0], tl[1] + depth * 0.9, tl[2] - depth * 0.3)], PANEL_L, stroke=INK, stroke_width=1.4)
		for i in range(4):
			p_ = pt(tl[0] + 0.3 + i * 0.35, tl[1] - 0.05, tl[2] - 0.2)
			d.rect(p_[0] - 5, p_[1], 10, 26, rng.choice(BOOK_COLS), stroke=INK, stroke_width=0.6)
		# scrape marks where its base walked forward, books everywhere, the white dust of the second aftershock
		for sd in (-0.65, 0.65):
			quad(d, floor_quad(tall_x + sd - 0.03, tall_x + sd + 0.03, piv_z, piv_z + 0.35, 0.003), "#c8a070")
		for i in range(60):
			x_ = rng.uniform(-3.5, 4.4)
			z_ = rng.uniform(3.4, 8.1)
			if abs(x_ - tall_x) < 1.1 and z_ > 5.6:
				continue
			p_ = pt(x_, 0, z_)
			k_ = V.s(z_)
			c = rng.choice(BOOK_COLS)
			with G(d, transform="rotate(%s %s %s)" % F(rng.uniform(0, 180), p_[0], p_[1])):
				d.rect(p_[0] - 9 * k_, p_[1] - 3 * k_, 18 * k_, 6 * k_, c, stroke=INK, stroke_width=0.6)
		for (x_, z_, rx, rz) in ((-2.0, 5.2, 2.6, 1.6), (2.0, 6.4, 2.4, 1.4), (0.0, 3.6, 3.4, 1.2), (3.6, 5.0, 1.4, 1.4)):
			dust_patch(d, x_, z_, rx, rz, 0.4)
		quad(d, [(hx - 0.4, 0.004, 4.2), (hx - 0.32, 0.004, 4.2), (hx - 0.36, 0.004, 5.5), (hx - 0.44, 0.004, 5.5)], "#5a4a3a", opacity=0.7)
		d.rect(0, 0, W, H, DUST, opacity=0.06)
	chandelier3(d, -0.3, 3.3, 4.6, lit=True, s=1.0, ceiling=r.h)
	crack(d, 1.6, 4.4, r.z1, rng, 6, 0.3)
	crack(d, r.x0, 4.3, 7.0, rng, 5, 0.3, side=True)
	light_pool(d, -0.3, 2.2, 5.0, 3.4, LANTERN, 0.18)
	shade(d, 0.36)


def bg_manor_library_after(d):
	bg_manor_library(d, True)


def bg_manor_gallery(d, turned=False):
	"""The Gallery down its length: past wardens and officers along the left wall, tall windows over the bay on the
	right, benches and busts, and at the far end the fireplace with its mantel clock beside the cupboard darkroom."""
	global V
	V = View(vy=300, eye=1.5, z0=17.0, m=46)
	rng = random.Random(1102)
	r = Room(w=6.0, h=4.2, z0=1.0, z1=17.0)
	wall = "#3e4a58"
	shell(d, r, back_grad(d, r, wall), side_grad(d, r, wall), side_grad(d, r, wall, False), WOOD, ceil_grad(d, r, "#d8ccb4"))
	damask_back(d, r.x0, r.x1, 1.0, r.h - 0.2, r.z1, "#5a6878", 0.5, 0.42)
	damask_side(d, r.x0, 1.0, r.h - 0.2, 6.0, r.z1, "#5a6878", 0.4, 0.42)
	damask_side(d, r.x1, 1.0, r.h - 0.2, 6.0, r.z1, "#5a6878", 0.4, 0.42)
	cornice(d, r, CREAM, 0.2)
	wainscot(d, r, 1.0)
	parquet(d, r, WOOD)
	# the far end: fireplace, mantel clock, a seascape over it; the darkroom cupboard to its right
	fireplace_back(d, -0.6, r.z1, 1.6, 1.2, "#e0d8c8")
	# the same clock as in the 3D Gallery (kit.mantel_clock): round-topped, dark polished wood, on a brass foot
	mantel_clock(d, -0.6, 1.28, r.z1 - 0.2, (5, 20), col=WOOD_D, foot=GILT)
	frame_back(d, -0.6, 1.75, 1.3, 0.9, r.z1, "sea", rng)
	box3(d, 1.0, 2.2, 0, 2.5, r.z1 - 0.6, r.z1, PANEL, sw=1.2)
	quad(d, back_quad(1.1, 1.58, 0.1, 2.4, r.z1 - 0.6), "none", stroke=dark(PANEL, 0.5), stroke_width=1.5)
	quad(d, back_quad(1.62, 2.1, 0.1, 2.4, r.z1 - 0.6), "none", stroke=dark(PANEL, 0.5), stroke_width=1.5)
	upright(d, 1.6, 2.0, r.z1 - 0.61, 0.3, 0.12, "#a01818", stroke=INK, stroke_width=0.8)
	for sd in (-1, 1):
		sconce3(d, -0.6 + sd * 1.0, 2.1, r.z1)
	# portraits all along the left wall (turned to the wall after the prank)
	z = 15.6
	i = 0
	while z > 2.0:
		w_ = 1.0 + 0.2 * (i % 2)
		frame_side(d, r.x0, 1.4 + 0.1 * (i % 2), z - w_, z, 1.4 - 0.1 * (i % 2), "portrait", random.Random(40 + i), GILT, turned=turned)
		if not turned:
			sconce3(d, r.x0, 2.95, z - w_ / 2, True, 0.55)
		z -= w_ + 0.6
		i += 1
	# tall windows on the right, the bay through them
	for zc in (14.6, 11.0, 7.4, 3.8):
		side_window(d, r.x1, 0.7, 3.4, zc - 0.7, zc + 0.7, "day", rng, gaol=(zc < 9), curtains="#2a3a5a")
	# benches down the middle, a bust on a plinth between them
	for zc in (12.0, 7.0):
		box3(d, -0.5, 0.5, 0.3, 0.45, zc - 1.0, zc + 1.0, "#2a3a6a", top="#3a4a7a", sw=1.2)
		for ez in (zc - 0.9, zc + 0.9):
			box3(d, -0.45, 0.45, 0, 0.3, ez - 0.05, ez + 0.05, WOOD_D, sw=0.8)
	box3(d, -0.25, 0.25, 0, 1.1, 9.4, 9.9, "#e8e4dc", sw=1.2)
	b = pt(0, 1.1, 9.65)
	k = V.s(9.65)
	d.ellipse(b[0], b[1] - 18 * k, 14 * k, 18 * k, "#f0ece4", stroke=INK, stroke_width=1)
	d.ellipse(b[0], b[1] - 4 * k, 20 * k, 6 * k, "#e0dcd4", stroke=INK, stroke_width=1)
	for zc in (14.0, 5.0):
		chandelier3(d, 0, 3.4, zc, lit=True, s=0.9, ceiling=r.h)
	cam_back(d, r.x1 - 0.2, 3.6, r.z1 - 0.1, flip=True, s=0.45)
	crack(d, r.x0, 3.9, 9.0, rng, 6, 0.3, side=True)
	crack(d, 2.3, 4.0, r.z1, rng, 5, 0.3)
	shade(d, 0.32)


def bg_manor_gallery_turned(d):
	bg_manor_gallery(d, True)


def dress_form(d, x, z, col="#e8d8c8", fabric=None):
	b = pt(x, 0, z)
	k = V.s(z)
	d.line(b[0], b[1], b[0], b[1] - 80 * k, "#3a2a1a", 4 * k)
	for sd in (-1, 1):
		d.line(b[0], b[1] - 4 * k, b[0] + sd * 22 * k, b[1], "#3a2a1a", 3 * k)
	top = b[1] - 80 * k
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s L%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(
		b[0] - 22 * k, top, b[0] - 30 * k, top - 40 * k, b[0] - 26 * k, top - 70 * k,
		b[0] - 20 * k, top - 92 * k, b[0] - 6 * k, top - 96 * k,
		b[0] + 6 * k, top - 96 * k, b[0] + 20 * k, top - 92 * k, b[0] + 26 * k, top - 70 * k,
		b[0] + 30 * k, top - 40 * k, b[0] + 22 * k, top), col, stroke=INK, stroke_width=1.2)
	d.rect(b[0] - 5 * k, top - 106 * k, 10 * k, 12 * k, "#3a2a1a")
	if fabric:
		d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % F(b[0] - 24 * k, top - 60 * k, b[0] - 40 * k, top + 10 * k, b[0] - 36 * k, top + 60 * k,
			b[0] + 30 * k, top + 64 * k, b[0] + 34 * k, top - 10 * k, b[0] + 22 * k, top - 64 * k), fabric, stroke=INK, stroke_width=1, opacity=0.95)
		for j in range(5):
			d.circle(b[0] - 18 * k + j * 9 * k, top - 40 * k + (j % 2) * 12 * k, 1.8 * k, "#c0c4cc")


def bg_manor_music(d):
	"""The Music Room: pale and gilded, the grand piano, the harp, music stands and little gilt chairs, a gramophone;
	in one corner a costume being fitted on a dress form, with its long mirror and sewing table."""
	global V
	V = View(vy=300, eye=1.5, z0=8.0, m=72)
	rng = random.Random(1203)
	r = Room(w=10.0, h=4.2, z0=1.0, z1=8.0)
	wall = "#ece0c2"
	shell(d, r, back_grad(d, r, wall), side_grad(d, r, wall), side_grad(d, r, wall, False), WOOD_L, ceil_grad(d, r, "#f4ecd8"))
	damask_back(d, r.x0, r.x1, 0.9, r.h - 0.2, r.z1, "#d8c89a", 0.6, 0.42)
	damask_side(d, r.x0, 0.9, r.h - 0.2, 3.6, r.z1, "#d8c89a", 0.5, 0.42)
	damask_side(d, r.x1, 0.9, r.h - 0.2, 3.6, r.z1, "#d8c89a", 0.5, 0.42)
	cornice(d, r, "#f4ecd8", 0.24)
	wainscot(d, r, 0.9, "#d8c8a0")
	parquet(d, r, WOOD_L)
	rug(d, -3.0, 2.0, 3.0, 6.6, "#3a4a7a", GILT, 0.95)
	# tall windows on the back wall
	for x in (-2.4, 0.6, 3.6):
		back_window(d, x, 0.8, 1.2, 2.6, r.z1, "day", curtains="#c8a040", rng=rng)
	frame_side(d, r.x0, 1.6, 5.4, 6.8, 1.0, "still", rng)
	frame_side(d, r.x1, 1.6, 5.2, 6.6, 1.0, "sea", rng)
	# the grand piano, lid up
	px, pz = -1.2, 5.6
	box3(d, px - 1.0, px + 0.5, 0.65, 0.95, pz - 0.75, pz + 0.75, "#121216", top="#2a2a30", side="#0a0a0c", sw=1.4)
	quad(d, [(px - 1.0, 0.95, pz + 0.7), (px + 0.5, 0.95, pz + 0.7), (px + 0.3, 1.9, pz + 0.55), (px - 0.9, 1.65, pz + 0.55)], "#1a1a20", stroke=INK, stroke_width=1.2)
	quad(d, back_quad(px - 0.95, px + 0.45, 0.82, 0.92, pz - 0.76), "#f4f0e8")
	dd = ""
	for i in range(14):
		xk = px - 0.92 + i * 0.1
		a, b = pt(xk, 0.86, pz - 0.77), pt(xk + 0.04, 0.92, pz - 0.77)
		dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
	d.spath(dd, "#1a1a1a", 3)
	for (lx, lz) in ((px - 0.9, pz - 0.65), (px + 0.4, pz - 0.65), (px - 0.25, pz + 0.6)):
		box3(d, lx - 0.05, lx + 0.05, 0, 0.65, lz - 0.05, lz + 0.05, "#121216", sw=0.8)
	box3(d, px - 0.5, px, 0, 0.48, pz - 1.4, pz - 1.1, "#121216", top="#3a2a4a", sw=1)
	# the harp beside it
	hb = pt(1.0, 0, 6.2)
	k = V.s(6.2)
	d.path("M%s %s L%s %s Q%s %s %s %s L%s %s Z" % F(hb[0] - 12 * k, hb[1], hb[0] - 18 * k, hb[1] - 140 * k, hb[0] + 30 * k, hb[1] - 170 * k, hb[0] + 50 * k, hb[1] - 120 * k,
		hb[0] + 12 * k, hb[1]), "none", stroke=GILT, stroke_width=6 * k)
	dd = ""
	for i in range(8):
		t = (i + 1) / 9
		dd += "M%s %s L%s %s " % F(hb[0] - 14 * k + t * 26 * k, hb[1] - 6 * k, hb[0] - 16 * k + t * 64 * k, hb[1] - 140 * k + t * 10 * k)
	d.spath(dd, "#f4ecd8", 1)
	# a row of gilt chairs and music stands
	for i in range(3):
		chair3(d, 2.4 + i * 0.6, 6.8, "#c8b070", GILT_D, facing="toward", w=0.42)
	for (sx, sz) in ((2.6, 5.6), (3.4, 5.4)):
		b = pt(sx, 0, sz)
		k = V.s(sz)
		d.line(b[0], b[1], b[0], b[1] - 100 * k, "#1a1a1a", 2 * k)
		for sd in (-1, 0, 1):
			d.line(b[0], b[1] - 4 * k, b[0] + sd * 14 * k, b[1], "#1a1a1a", 2 * k)
		d.poly([(b[0] - 24 * k, b[1] - 110 * k), (b[0] + 24 * k, b[1] - 110 * k), (b[0] + 22 * k, b[1] - 136 * k), (b[0] - 22 * k, b[1] - 136 * k)], "#1a1a1a")
		d.rect(b[0] - 18 * k, b[1] - 134 * k, 36 * k, 22 * k, "#f4efe0")
	# the gramophone on a little table
	table3(d, 3.8, 4.4, 7.3, 7.8, 0.75, "#6a4a2a")
	g = pt(4.1, 0.75, 7.55)
	k = V.s(7.55)
	d.rect(g[0] - 16 * k, g[1] - 16 * k, 32 * k, 16 * k, "#5a3a1a", stroke=INK, stroke_width=1)
	d.path("M%s %s L%s %s Q%s %s %s %s Q%s %s %s %s Z" % F(g[0], g[1] - 18 * k, g[0] + 4 * k, g[1] - 30 * k, g[0] + 30 * k, g[1] - 70 * k, g[0] + 40 * k, g[1] - 60 * k,
		g[0] + 26 * k, g[1] - 40 * k, g[0], g[1] - 18 * k), GILT, stroke=INK, stroke_width=1)
	# the fitting corner, left: dress form with fabric pinned, a sewing table with its tickets, a long mirror
	dress_form(d, -3.6, 6.4, "#e8d8c8", "#7a3a8a")
	table3(d, -4.6, -3.9, 5.2, 5.8, 0.74, "#8a6a4a")
	b = pt(-4.25, 0.74, 5.5)
	k = V.s(5.5)
	for j in range(3):
		d.rect(b[0] - 14 * k + j * 10 * k, b[1] - 3 * k, 8 * k, 3 * k, ["#f4efe0", "#fbf2c8", "#f4efe0"][j])
	d.circle(b[0] + 14 * k, b[1] - 6 * k, 5 * k, "#c83a4a")
	quad(d, wall_quad(r.x0 + 0.02, 0.1, 2.2, 6.9, 7.5), d.lin(pt(r.x0, 1, 6.9)[0], 0, pt(r.x0, 1, 7.5)[0], 0, [(0, "#a8b8c0"), (0.5, "#e8f0f4"), (1, "#a8b8c0")]),
		stroke=GILT, stroke_width=3)
	chandelier3(d, 0, 3.2, 4.8, lit=False, s=1.1, ceiling=r.h)
	cam_back(d, r.x1 - 0.2, 3.6, r.z1 - 0.1, flip=True, s=0.45)
	crack(d, -0.9, 4.0, r.z1, rng, 6, 0.3)
	glow(d, W / 2, 200, 700, "#fff8e8", 0.18)
	shade(d, 0.22)


def bg_manor_conservatory(d):
	"""The conservatory: a glasshouse on a low brick wall, the sky and the sea through it, palms and ferns, benches of
	seedlings, the potting bench with its tins, a little fountain and an easel in the light."""
	global V
	V = View(vy=330, eye=1.5, z0=8.0, m=70)
	rng = random.Random(1304)
	r = Room(w=10.0, h=3.8, z0=1.0, z1=8.0)
	# the world outside first: sky and sea
	d.rect(0, 0, W, H, d.vlin(0, 400, [(0, "#5f9be0"), (0.7, "#a9d2ef"), (1, "#e2f2f6")]))
	hz = 352
	d.rect(0, hz, W, H - hz, d.vlin(hz, H, [(0, SEA_L), (0.3, SEA), (1, SEA_D)]))
	for (x, y, s) in ((220, 110, 0.9), (700, 70, 0.7), (1050, 140, 0.8)):
		QA.cloud(d, x, y, s, random.Random(int(x)), 0.85)
	with G(d, transform=T(820, hz + 4, 0.16)):
		QA.prison(d, 0, 0, random.Random(7))
	# the low brick wall all round, then the floor
	for x in (r.x0, r.x1):
		bricks_side(d, x, 0, 0.7, r.z0, r.z1, BRICK)
	bricks_back(d, r.x0, r.x1, 0, 0.7, r.z1, BRICK)
	quad(d, floor_quad(r.x0, r.x1, r.z0, r.z1, 0.0), "#b0603a")
	chequer(d, r, "#c8704a", "#a0502e", 0.45, rng=rng)
	for x in (r.x0, r.x1):
		quad(d, [(x, 0.7, r.z0), (x + (0.2 if x < 0 else -0.2), 0.7, r.z0), (x + (0.2 if x < 0 else -0.2), 0.7, r.z1), (x, 0.7, r.z1)], "#d8d0c0")
	# glazing bars: iron, painted dark green, on the walls and over the roof
	bar = "#2a3a32"
	for x in (r.x0, r.x1):
		for z in zs(r.z0, r.z1, 8):
			a, b = pt(x, 0.7, z), pt(x, r.h, z)
			d.line(a[0], a[1], b[0], b[1], bar, 4)
		for y in (1.6, 2.6, r.h):
			side_line(d, x, y, r.z0, r.z1, bar, 4)
	for xb in [r.x0 + (r.x1 - r.x0) * i / 10 for i in range(11)]:
		a, b = pt(xb, 0.7, r.z1), pt(xb, r.h, r.z1)
		d.line(a[0], a[1], b[0], b[1], bar, 3)
		a, b = pt(xb, r.h, r.z1), pt(xb, r.h, r.z0)
		d.line(a[0], a[1], b[0], b[1], bar, 3)
	for y in (1.6, 2.6, r.h):
		hline(d, r.x0, r.x1, y, r.z1, bar, 3)
	for z in zs(r.z0, r.z1, 8):
		hline(d, r.x0, r.x1, r.h, z, bar, 3)
	quad(d, [(r.x0, r.h, r.z0), (r.x1, r.h, r.z0), (r.x1, r.h, r.z1), (r.x0, r.h, r.z1)], "#d8f0f8", opacity=0.18)
	# a fountain in the middle, palms in tubs, benches of seedlings
	fz = 5.4
	ell3(d, 0, 0.0, fz, 0.9, 0.6, "#8a8a84", stroke=INK, stroke_width=1.2)
	ell3(d, 0, 0.4, fz, 0.9, 0.6, "#a8a8a0", stroke=INK, stroke_width=1.2)
	ell3(d, 0, 0.38, fz, 0.78, 0.5, "#4aa8b8")
	p0, p1 = pt(0, 0.4, fz), pt(0, 1.2, fz)
	d.line(p0[0], p0[1], p1[0], p1[1], "#a8a8a0", 10)
	ell3(d, 0, 1.2, fz, 0.3, 0.2, "#a8a8a0", stroke=INK, stroke_width=1)
	for sd in (-1, 1):
		d.spath("M%s %s Q%s %s %s %s" % F(p1[0], p1[1] - 6, p1[0] + sd * 30, p1[1] - 40, p1[0] + sd * 50, p1[1] + 40), "#c8f0ff", 3, opacity=0.8)
	for (x, z) in ((-3.6, 7.0), (3.8, 7.2), (-4.2, 3.4)):
		palm3(d, x, z, 2.4, rng)
	for (x0_, x1_, z0_, z1_) in ((-4.6, -2.8, 4.6, 5.6), (2.6, 4.6, 4.4, 5.4)):
		table3(d, x0_, x1_, z0_, z1_, 0.8, "#8a6a42")
		for i in range(5):
			for j in range(2):
				p = pt(x0_ + 0.2 + i * (x1_ - x0_ - 0.4) / 4, 0.8, z0_ + 0.3 + j * 0.4)
				k = V.s(z0_ + 0.3 + j * 0.4)
				d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(p[0] - 8 * k, p[1] - 14 * k, p[0] + 8 * k, p[1] - 14 * k, p[0] + 6 * k, p[1], p[0] - 6 * k, p[1]), "#b0603a",
					stroke=INK, stroke_width=0.6)
				d.ellipse(p[0], p[1] - 18 * k, 10 * k, 8 * k, "#4a8a3a")
	# the potting bench on the back wall, its tins and trowels; the easel in the light
	table3(d, -1.2, 1.2, r.z1 - 0.7, r.z1 - 0.1, 0.85, "#7a5a3a")
	for i in range(4):
		p = pt(-0.9 + i * 0.5, 0.85, r.z1 - 0.4)
		k = V.s(r.z1 - 0.4)
		c = ["#e8c030", "#9aa0a8", "#b0603a", "#e8c030"][i]
		d.rect(p[0] - 9 * k, p[1] - 16 * k, 18 * k, 16 * k, c, stroke=INK, stroke_width=0.8)
		d.ellipse(p[0], p[1] - 16 * k, 9 * k, 3 * k, light(c, 0.2), stroke=INK, stroke_width=0.6)
	eb = pt(2.6, 0, 6.6)
	k = V.s(6.6)
	for sd in (-1, 1):
		d.line(eb[0] + sd * 24 * k, eb[1], eb[0] + sd * 6 * k, eb[1] - 150 * k, "#8a6a42", 4 * k)
	d.line(eb[0], eb[1] - 10 * k, eb[0], eb[1] - 150 * k, "#8a6a42", 3 * k)
	d.rect(eb[0] - 34 * k, eb[1] - 140 * k, 68 * k, 50 * k, "#f8f4ec", stroke=INK, stroke_width=1)
	d.rect(eb[0] - 30 * k, eb[1] - 136 * k, 60 * k, 22 * k, "#8ac0e0")
	d.rect(eb[0] - 30 * k, eb[1] - 114 * k, 60 * k, 20 * k, "#3a8aa8")
	d.line(eb[0] - 36 * k, eb[1] - 88 * k, eb[0] + 36 * k, eb[1] - 88 * k, "#8a6a42", 4 * k)
	cam_back(d, r.x1 - 0.3, 3.3, r.z1, flip=True, s=0.4)
	glow(d, 400, 160, 500, "#fffbe8", 0.2)
	shade(d, 0.18)


def croc_statue(d, x, y, z, s=1.0):
	"""The Warden's bronze crocodile on a plinth at the head of the pool, head in profile, jaws open, hot water arcing
	out of them into the pool."""
	b = pt(x, y, z)
	k = V.s(z) * s
	d.rect(b[0] - 34 * k, b[1] - 40 * k, 68 * k, 40 * k, "#e8e2d4", stroke=INK, stroke_width=1.4)
	d.rect(b[0] - 40 * k, b[1] - 46 * k, 80 * k, 8 * k, "#d8d2c4", stroke=INK, stroke_width=1.2)
	bronze = d.lin(b[0] - 60 * k, 0, b[0] + 60 * k, 0, [(0, "#4a2e14"), (0.5, "#b88a48"), (1, "#5a3a1a")])
	top = b[1] - 46 * k
	# neck and head, snout pointing left and up
	d.path("M%s %s Q%s %s %s %s L%s %s L%s %s Q%s %s %s %s Z" % F(b[0] + 30 * k, top, b[0] + 34 * k, top - 60 * k, b[0] + 6 * k, top - 92 * k,
		b[0] - 70 * k, top - 128 * k, b[0] - 76 * k, top - 116 * k, b[0] - 10 * k, top - 40 * k, b[0] - 18 * k, top), bronze, stroke=INK, stroke_width=1.6)
	# the open lower jaw
	d.path("M%s %s L%s %s L%s %s Z" % F(b[0] - 4 * k, top - 64 * k, b[0] - 72 * k, top - 92 * k, b[0] - 10 * k, top - 44 * k), "#6a4422", stroke=INK, stroke_width=1.4)
	dd = ""
	for i in range(6):
		tx = b[0] - 66 * k + i * 11 * k
		ty = top - 118 * k + i * 9 * k
		dd += "M%s %s l%s %s l%s %s Z " % F(tx, ty, 3 * k, 8 * k, 4 * k, -3 * k)
	d.path(dd, "#f4ecd0", stroke=INK, stroke_width=0.6)
	d.circle(b[0] - 6 * k, top - 98 * k, 6 * k, "#e8c860", stroke=INK, stroke_width=1)
	d.circle(b[0] - 6 * k, top - 98 * k, 2 * k, INK)
	for j in range(4):
		d.circle(b[0] + 2 * k + j * 7 * k, top - 84 * k + j * 12 * k, 3 * k, "#7a5228")
	# the water
	m0 = (b[0] - 60 * k, top - 100 * k)
	d.spath("M%s %s Q%s %s %s %s" % F(m0[0], m0[1], m0[0] - 70 * k, m0[1] - 50 * k, m0[0] - 110 * k, top + 30 * k), "#c8f0ff", 7 * k, opacity=0.75)
	d.spath("M%s %s Q%s %s %s %s" % F(m0[0], m0[1], m0[0] - 70 * k, m0[1] - 50 * k, m0[0] - 110 * k, top + 30 * k), "#ffffff", 2.5 * k, opacity=0.9)


def bg_manor_bath(d):
	"""The Marble Bath: marble walls and a chequered floor, the raised pool steaming, columns, the Warden's bronze
	crocodile spouting hot water at the head of the pool, towels on a bench, high windows."""
	global V
	V = View(vy=300, eye=1.5, z0=9.0, m=70)
	rng = random.Random(1405)
	r = Room(w=10.0, h=4.4, z0=1.0, z1=9.0)
	wall = "#e6e0d2"
	shell(d, r, back_grad(d, r, wall), side_grad(d, r, wall), side_grad(d, r, wall, False), MARBLE, ceil_grad(d, r, "#efe8d8"))
	for (x, on) in ((r.x0, 1), (r.x1, 1)):
		dd = ""
		for i in range(10):
			z0_ = rng.uniform(r.z0, r.z1)
			a, b = pt(x, rng.uniform(0.5, 4.0), z0_), pt(x, rng.uniform(0.5, 4.0), z0_ + rng.uniform(-1, 1))
			dd += "M%s %s Q%s %s %s %s " % F(a[0], a[1], (a[0] + b[0]) / 2 + rng.uniform(-20, 20), (a[1] + b[1]) / 2, b[0], b[1])
		d.spath(dd, MARBLE_V, 1.5, opacity=0.6)
	dd = ""
	for i in range(12):
		a = pt(rng.uniform(r.x0, r.x1), rng.uniform(0.5, 4.2), r.z1)
		b = (a[0] + rng.uniform(-80, 80), a[1] + rng.uniform(20, 80))
		dd += "M%s %s Q%s %s %s %s " % F(a[0], a[1], (a[0] + b[0]) / 2 + rng.uniform(-20, 20), (a[1] + b[1]) / 2, b[0], b[1])
	d.spath(dd, MARBLE_V, 1.5, opacity=0.6)
	wainscot(d, r, 0.9, "#3a5a52", panels=False)
	for (x0_, x1_) in ((r.x0, r.x1),):
		hline(d, x0_, x1_, 2.1, r.z1, GILT, 4)
	for x in (r.x0, r.x1):
		side_line(d, x, 2.1, r.z0, r.z1, GILT, 4)
	cornice(d, r, "#f4ecd8", 0.2)
	chequer(d, r, "#efeae0", "#3a5a52", 0.6, rng=rng)
	# high windows on the back wall
	for x in (-3.0, 3.0):
		back_window(d, x, 2.5, 1.2, 1.4, r.z1, "day", rng=rng, gaol=False)
	# columns
	for (x, z) in ((-2.8, 7.4), (2.8, 7.4), (-2.8, 3.6), (2.8, 3.6)):
		b = pt(x, 0, z)
		t_ = pt(x, r.h, z)
		k = V.s(z)
		w_ = 0.22 * M * k
		d.rect(b[0] - w_, t_[1], w_ * 2, b[1] - t_[1], d.lin(b[0] - w_, 0, b[0] + w_, 0, [(0, "#b8b2a4"), (0.4, "#f4f0e8"), (1, "#a8a294")]), stroke=INK, stroke_width=1)
		d.rect(b[0] - w_ * 1.3, b[1] - 14 * k, w_ * 2.6, 14 * k, "#d8d2c4", stroke=INK, stroke_width=1)
		d.rect(b[0] - w_ * 1.3, t_[1], w_ * 2.6, 16 * k, "#d8d2c4", stroke=INK, stroke_width=1)
	# the raised pool, its water and steam, the bronze crocodile at its head
	px0, px1, pz0, pz1 = -2.0, 2.0, 4.0, 7.6
	box3(d, px0, px1, 0, 0.45, pz0, pz1, "#ece6da", top="#f4f0e8", sw=1.4)
	quad(d, floor_quad(px0 + 0.15, px1 - 0.15, pz0 + 0.15, pz1 - 0.15, 0.4), d.vlin(pt(0, 0.4, pz1)[1], pt(0, 0.4, pz0)[1], [(0, "#5ac0c8"), (1, "#2a8a98")]))
	croc_statue(d, 0, 0.45, pz1 - 0.1, 0.8)
	steam(d, random.Random(11), pt(px0, 0.4, 6)[0], pt(0, 2.4, 6)[1], pt(px1, 0.4, 6)[0], pt(0, 0.5, 6)[1], 8, 0.16, 30, 80)
	# towels on a bench, a little table of bottles, a croc camera
	box3(d, 3.6, 4.6, 0.35, 0.45, 5.2, 6.2, "#e0dad0", sw=1)
	for j in range(3):
		p = pt(4.1, 0.45 + j * 0.08, 5.6)
		k = V.s(5.6)
		d.rect(p[0] - 30 * k, p[1] - 8 * k, 60 * k, 8 * k, ["#f4f0e8", "#c8e0e8", "#f4f0e8"][j], stroke=INK, stroke_width=0.6)
	for ez in (5.25, 6.15):
		box3(d, 3.65, 4.55, 0, 0.35, ez - 0.05, ez + 0.05, "#c8c2b8", sw=0.8)
	side_door(d, r.x0, 3.0, 4.0, 2.3, PANEL_L)
	cam_back(d, r.x1 - 0.2, 3.7, r.z1 - 0.1, flip=True, s=0.45)
	crack(d, 1.4, 4.2, r.z1, rng, 6, 0.3)
	glow(d, W / 2, 140, 600, "#fffbf0", 0.2)
	shade(d, 0.22)


def bg_manor_attic(d):
	"""The attic under the roof: rafters, a round window at the far gable, trunks and the Gaol's old record boxes along
	the low sides, a rocking horse, dust sheets, and a corner wired up to a camera somebody has killed."""
	global V
	V = View(vy=330, eye=1.5, z0=14.0, m=58)
	rng = random.Random(1506)
	r = Room(w=10.0, h=1.0, z0=1.0, z1=14.0)
	ridge = 4.4
	d.rect(0, 0, W, H, "#1a120c")
	parquet(d, r, "#6a4a2e")
	# the gable at the far end
	gp = [(r.x0, 0, r.z1), (r.x1, 0, r.z1), (r.x1, 1.0, r.z1), (0, ridge, r.z1), (r.x0, 1.0, r.z1)]
	quad(d, gp, d.vlin(pt(0, ridge, r.z1)[1], pt(0, 0, r.z1)[1], [(0, "#4a3a2a"), (1, "#6a5038")]))
	wc = pt(0, 2.4, r.z1)
	k = V.s(r.z1)
	d.circle(wc[0], wc[1], 0.55 * M * k + 6, "#3a2a1a")
	d.circle(wc[0], wc[1], 0.55 * M * k, d.vlin(wc[1] - 30, wc[1] + 30, [(0, "#a9d2ef"), (0.55, "#e2f2f6"), (0.56, SEA_L), (1, SEA)]))
	d.line(wc[0] - 0.55 * M * k, wc[1], wc[0] + 0.55 * M * k, wc[1], "#3a2a1a", 3)
	d.line(wc[0], wc[1] - 0.55 * M * k, wc[0], wc[1] + 0.55 * M * k, "#3a2a1a", 3)
	glow(d, wc[0], wc[1], 200, "#e8f4ff", 0.3)
	# the two roof slopes and the kneewalls
	for sd in (-1, 1):
		x = r.x0 if sd < 0 else r.x1
		quad(d, wall_quad(x, 0, 1.0, r.z0, r.z1), "#4a3624")
		quad(d, [(x, 1.0, r.z1), (0, ridge, r.z1), (0, ridge, r.z0), (x, 1.0, r.z0)], d.lin(0, pt(0, ridge, r.z1)[1], 0, pt(x, 1.0, r.z0)[1],
			[(0, "#2a1c10"), (1, "#5a4028")]))
	for z in zs(r.z0, r.z1, 14):
		for sd in (-1, 1):
			x = r.x0 if sd < 0 else r.x1
			a, b = pt(x, 1.0, z), pt(0, ridge, z)
			d.line(a[0], a[1], b[0], b[1], "#6a4a2a", max(2, 9 * V.s(z) / 2))
	ra, rb = pt(0, ridge, r.z1), pt(0, ridge, r.z0)
	d.line(ra[0], ra[1], rb[0], rb[1], "#3a2414", 10)
	for z in zs(3.0, r.z1, 4):
		a, b = pt(-2.6, 2.75, z), pt(2.6, 2.75, z)
		d.line(a[0], a[1], b[0], b[1], "#6a4a2a", 6 * V.s(z) / 2)
	# trunks and boxes along both sides, dust sheets over furniture
	for (x0_, x1_, z0_, z1_, c) in ((-4.8, -3.8, 10.0, 11.0, "#5a3a20"), (-4.8, -3.6, 8.4, 9.4, "#3a4a5a"), (-4.8, -4.0, 6.0, 7.2, "#c8b890"),
			(3.8, 4.8, 10.4, 11.6, "#c8b890"), (3.6, 4.8, 8.0, 9.2, "#6a2a2a"), (4.0, 4.8, 5.0, 6.4, "#c8b890")):
		box3(d, x0_, x1_, 0, 0.55, z0_, z1_, c, sw=1.2)
		if c != "#c8b890":
			hline(d, x0_, x1_, 0.42, z0_, "#2a2a2a", 3)
	for (x0_, x1_, z0_, z1_) in ((-4.6, -3.4, 3.4, 4.6), (3.2, 4.6, 2.8, 4.0)):
		box3(d, x0_, x1_, 0.55, 1.0, z0_, z1_, "#c8b890", sw=1)
		for j in range(3):
			hline(d, x0_ + 0.1, x1_ - 0.1, 0.65 + j * 0.1, z0_, "#5a4a3a", 1.2)
	b = pt(-2.4, 0, 9.0)
	k = V.s(9.0)
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s L%s %s Z" % F(b[0] - 60 * k, b[1], b[0] - 70 * k, b[1] - 80 * k, b[0] - 10 * k, b[1] - 110 * k,
		b[0] + 50 * k, b[1] - 100 * k, b[0] + 70 * k, b[1] - 60 * k, b[0] + 60 * k, b[1]), "#e8e4dc", stroke=INK, stroke_width=1.2)
	# the rocking horse
	h = pt(2.4, 0, 8.0)
	k = V.s(8.0)
	d.spath("M%s %s Q%s %s %s %s" % F(h[0] - 50 * k, h[1] - 10 * k, h[0], h[1] + 10 * k, h[0] + 50 * k, h[1] - 10 * k), "#6a3a1a", 6 * k)
	for sd in (-1, 1):
		d.line(h[0] + sd * 30 * k, h[1] - 6 * k, h[0] + sd * 20 * k, h[1] - 40 * k, "#e8dcc8", 6 * k)
	d.ellipse(h[0], h[1] - 50 * k, 40 * k, 16 * k, "#e8dcc8", stroke=INK, stroke_width=1)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(h[0] + 26 * k, h[1] - 56 * k, h[0] + 44 * k, h[1] - 96 * k, h[0] + 60 * k, h[1] - 86 * k, h[0] + 40 * k, h[1] - 50 * k), "#e8dcc8", stroke=INK, stroke_width=1)
	d.ellipse(h[0] + 36 * k, h[1] - 80 * k, 6 * k, 14 * k, "#8a3a2a")
	# the corner by the window: a crate desk, a glowing screen, cables to a crocodile camera with its eye gone dark
	box3(d, 0.9, 2.0, 0, 0.7, 12.4, 13.0, "#8a6a42", sw=1)
	s_ = pt(1.45, 0.7, 12.7)
	k = V.s(12.7)
	d.rect(s_[0] - 18 * k, s_[1] - 26 * k, 36 * k, 24 * k, "#1a1a1e", stroke=INK, stroke_width=1)
	d.rect(s_[0] - 15 * k, s_[1] - 23 * k, 30 * k, 18 * k, "#5ae0e8")
	glow(d, s_[0], s_[1] - 14 * k, 60 * k, "#5ae0e8", 0.5)
	cp = pt(2.6, 2.2, r.z1)
	croc_cam(d, cp[0], cp[1], 0.4 * V.s(r.z1), flip=True, lit=False)
	d.spath("M%s %s Q%s %s %s %s" % F(cp[0] - 4, cp[1] + 8, cp[0] - 10, s_[1] - 10, s_[0] + 16 * k, s_[1] - 10 * k), "#1a1a1a", 2)
	bulb = pt(0, 3.6, 6.0)
	d.line(bulb[0], pt(0, ridge, 6.0)[1], bulb[0], bulb[1], "#1a1a1a", 2)
	glow(d, bulb[0], bulb[1], 220, LANTERN, 0.3)
	d.circle(bulb[0], bulb[1], 7, LANTERN_HOT)
	for _ in range(40):
		d.circle(rng.uniform(300, 980), rng.uniform(150, 450), rng.uniform(0.8, 1.8), "#fff4d8", opacity=rng.uniform(0.2, 0.5))
	shade(d, 0.45)


def bg_manor_passage(d):
	"""The servants' passage inside the walls: bare boards, the row of old service bells, bare bulbs; narrow on purpose."""
	global V
	V = View(vy=300, eye=1.5, z0=8.0, m=210)
	rng = random.Random(1607)
	r = Room(w=0.92, h=3.3, z0=0.45, z1=8.0)
	boards = "#5a3e28"
	shell(d, r, back_grad(d, r, dark(boards, 0.4)), side_grad(d, r, boards), side_grad(d, r, boards, False), "#4a3420", ceil_grad(d, r, "#3a2a1c"))
	for x in (r.x0, r.x1):
		for y in [0.18 * i for i in range(1, 18)]:
			side_line(d, x, y, r.z0, r.z1, dark(boards, 0.35), 1.2, opacity=0.6)
	parquet(d, r, "#4a3420", n=6)
	# the passage turns right at the far end: a lit gap in the right wall
	quad(d, wall_quad(r.x1, 0, 2.2, 7.1, 7.9), "#8a6a40")
	glow(d, pt(r.x1, 1.2, 7.5)[0], pt(r.x1, 1.2, 7.5)[1], 60, LANTERN, 0.4)
	for z in zs(1.0, 7.5, 7):
		quad(d, [(r.x0, r.h - 0.01, z - 0.04), (r.x1, r.h - 0.01, z - 0.04), (r.x1, r.h - 0.01, z + 0.04), (r.x0, r.h - 0.01, z + 0.04)], "#2a1c10")
	# the bells, on their springs, high on the left wall
	quad(d, wall_quad(r.x0, 1.9, 2.25, 3.2, 4.8), PANEL_D, stroke=INK, stroke_width=1)
	for i in range(6):
		z = 3.35 + i * 0.25
		a = pt(r.x0, 2.0, z)
		b = pt(r.x0 + 0.1, 1.86, z)
		d.line(a[0], a[1], b[0], b[1], GILT_D, 2)
		d.circle(b[0], b[1] + 6, 8 * V.s(z) / 6, GILT, stroke=INK, stroke_width=0.8)
	for z in (2.0, 6.0):
		b = pt(0, 2.5, z)
		top = pt(0, r.h, z)
		d.line(b[0], top[1], b[0], b[1], "#1a1a1a", 2)
		glow(d, b[0], b[1], 160 * V.s(z) / 2, LANTERN, 0.45)
		d.circle(b[0], b[1], 10 * V.s(z) / 2, LANTERN_HOT)
	# a forgotten tray, a broom; grey dust over the boards
	b = pt(-0.2, 0, 6.8)
	k = V.s(6.8)
	d.ellipse(b[0], b[1], 30 * k, 8 * k, "#9a9aa0", stroke=INK, stroke_width=1)
	a, b = pt(r.x1 - 0.06, 0, 3.0), pt(r.x1 - 0.1, 1.4, 3.1)
	d.line(a[0], a[1], b[0], b[1], WOOD_L, 5)
	quad(d, floor_quad(r.x0 + 0.04, r.x1 - 0.04, 1.0, 7.8, 0.002), "#8a8a84", opacity=0.35)
	shade(d, 0.5)


def bg_manor_corridor(d):
	"""The Bedroom Wing: a long corridor of doors with the guests' name cards beside them, a runner, sconces between
	the portraits, and the attic stairs door at the far end."""
	global V
	V = View(vy=300, eye=1.5, z0=28.0, m=50)
	rng = random.Random(1708)
	r = Room(w=2.6, h=3.4, z0=0.6, z1=28.0)
	wall = "#5a1e22"
	shell(d, r, back_grad(d, r, wall), side_grad(d, r, wall), side_grad(d, r, wall, False), WOOD, ceil_grad(d, r, "#d6c8ac"))
	damask_side(d, r.x0, 1.0, r.h - 0.2, 3.0, r.z1, "#7a3a34", 0.4, 0.4)
	damask_side(d, r.x1, 1.0, r.h - 0.2, 3.0, r.z1, "#7a3a34", 0.4, 0.4)
	cornice(d, r, CREAM, 0.18)
	wainscot(d, r, 1.0)
	parquet(d, r, WOOD, n=12)
	quad(d, floor_quad(-0.55, 0.55, r.z0, r.z1 - 0.6, 0.004), "#5a1418")
	for sd in (-1, 1):
		a, b = pt(sd * 0.45, 0.005, r.z0), pt(sd * 0.45, 0.005, r.z1 - 0.6)
		d.line(a[0], a[1], b[0], b[1], GILT, 2)
	back_door(d, 0, r.z1, 1.0, 2.1, WOOD_D)
	frame_back(d, 0, 2.3, 0.6, 0.6, r.z1, "sea", rng)
	# doors down both sides, a name card beside each, sconces and pictures between
	for i, z in enumerate((3.4, 7.0, 10.6, 14.2, 17.8, 21.4, 25.0)):
		side_door(d, r.x0, z - 0.5, z + 0.5, 2.2, PANEL_L)
		quad(d, wall_quad(r.x0, 1.42, 1.56, z + 0.72, z + 1.0), "#f4efe0", stroke=GILT_D, stroke_width=1)
		if i < 6:
			sconce3(d, r.x0, 2.25, z + 1.8, i % 2 == 0, 0.5)
	for i, z in enumerate((5.2, 8.8, 12.4, 16.0)):
		side_door(d, r.x1, z - 0.5, z + 0.5, 2.2, PANEL_L)
		quad(d, wall_quad(r.x1, 1.42, 1.56, z - 1.0, z - 0.72), "#f4efe0", stroke=GILT_D, stroke_width=1)
	for zc in (20.0, 23.6):
		side_window(d, r.x1, 0.9, 2.7, zc - 0.55, zc + 0.55, "day", rng, curtains="#5a3a1a")
	for zc in (2.2, 6.6):
		frame_side(d, r.x1, 1.7, zc - 0.3, zc + 0.3, 0.6, "portrait", random.Random(int(zc * 10)))
	for zc in (4.0, 12.0, 20.0):
		chandelier3(d, 0, 2.85, zc, lit=True, s=0.6, ceiling=r.h)
	cam_back(d, r.x0 + 0.2, 2.9, 2.0, s=0.5)
	crack(d, r.x1, 3.3, 5.0, rng, 5, 0.3, side=True)
	shade(d, 0.35)


def bg_manor_bedroom(d, tod="day"):
	"""A guest bedroom (they all share one layout): the bed against the back wall, a cold fireplace, the window over
	the sea on the right with the writing desk under it, the wardrobe on the left."""
	global V
	V = View(vy=300, eye=1.45, z0=5.0, m=120)
	rng = random.Random(1809)
	r = Room(w=6.0, h=3.5, z0=0.8, z1=5.0)
	wall = "#2e4a52"
	shell(d, r, back_grad(d, r, wall), side_grad(d, r, wall), side_grad(d, r, wall, False), WOOD, ceil_grad(d, r, "#d6ccb4"))
	damask_back(d, r.x0, r.x1, 0.9, r.h - 0.2, r.z1, "#4a6a72", 0.5, 0.34)
	damask_side(d, r.x0, 0.9, r.h - 0.2, r.z0, r.z1, "#4a6a72", 0.4, 0.34)
	damask_side(d, r.x1, 0.9, r.h - 0.2, r.z0, r.z1, "#4a6a72", 0.4, 0.34)
	cornice(d, r, CREAM, 0.16)
	wainscot(d, r, 0.9)
	parquet(d, r, WOOD)
	rug(d, -1.0, 1.8, 1.6, 3.4, "#3a2a4a", GILT, 0.95)
	view = "night" if tod == "night" else "day"
	# the fireplace and a painting on the back wall, left
	fireplace_back(d, -1.4, r.z1, 1.2, 1.15, "#e0d8c8")
	frame_back(d, -1.4, 1.6, 0.75, 0.56, r.z1, "sea", rng)
	# the bed, head to the back wall, and its bedside table with a lamp
	bx0, bx1 = 0.0, 1.5
	box3(d, bx0 - 0.05, bx1 + 0.05, 0, 1.25, r.z1 - 0.1, r.z1, PANEL, sw=1.2)
	box3(d, bx0, bx1, 0.25, 0.6, r.z1 - 2.2, r.z1 - 0.1, "#f2ede0", top="#f8f4ec", sw=1.2)
	quad(d, floor_quad(bx0 - 0.02, bx1 + 0.02, r.z1 - 2.22, r.z1 - 0.7, 0.61), "#3a6a8a")
	quad(d, back_quad(bx0 - 0.02, bx1 + 0.02, 0.28, 0.61, r.z1 - 2.22), "#2e5a78")
	for sx in (0.4, 1.1):
		p = pt(sx, 0.65, r.z1 - 0.4)
		k = V.s(r.z1 - 0.4)
		d.ellipse(p[0], p[1] - 6 * k, 30 * k, 12 * k, "#ffffff", stroke="#c8c0b0", stroke_width=1)
	box3(d, bx0, bx1, 0, 0.5, r.z1 - 2.25, r.z1 - 2.15, PANEL, sw=1)
	table3(d, 1.7, 2.15, r.z1 - 0.45, r.z1 - 0.05, 0.6, WOOD)
	lp = pt(1.92, 0.6, r.z1 - 0.25)
	k = V.s(r.z1 - 0.25)
	d.line(lp[0], lp[1], lp[0], lp[1] - 30 * k, GILT_D, 2 * k)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(lp[0] - 14 * k, lp[1] - 26 * k, lp[0] + 14 * k, lp[1] - 26 * k, lp[0] + 9 * k, lp[1] - 46 * k, lp[0] - 9 * k, lp[1] - 46 * k), "#e8d8a8",
		stroke=INK, stroke_width=0.8)
	# the window over the sea on the right, the desk under it
	side_window(d, r.x1, 1.0, 2.8, 2.2, 3.4, view, rng, gaol=True, curtains="#2a3a44")
	table3(d, r.x1 - 0.6, r.x1, 1.6, 2.6, 0.76, WOOD)
	p = pt(r.x1 - 0.35, 0.76, 2.0)
	k = V.s(2.0)
	d.poly([(p[0] - 20 * k, p[1]), (p[0] + 14 * k, p[1] - 2 * k), (p[0] + 10 * k, p[1] - 8 * k), (p[0] - 22 * k, p[1] - 6 * k)], "#f4efe0", stroke="#8a7a60", stroke_width=0.8)
	# the wardrobe and the washstand on the left
	box3(d, r.x0, r.x0 + 0.6, 0, 2.2, 3.4, 4.6, PANEL_L, top=PANEL, side=PANEL, sw=1.2)
	quad(d, wall_quad(r.x0 + 0.6, 0.2, 2.0, 3.5, 4.0), "none", stroke=dark(PANEL_L, 0.5), stroke_width=1.5)
	quad(d, wall_quad(r.x0 + 0.6, 0.2, 2.0, 4.0, 4.5), "none", stroke=dark(PANEL_L, 0.5), stroke_width=1.5)
	table3(d, r.x0, r.x0 + 0.5, 2.0, 2.8, 0.82, "#e0dcd4", legs=WOOD_D)
	bw = pt(r.x0 + 0.25, 0.82, 2.4)
	k = V.s(2.4)
	d.ellipse(bw[0], bw[1] - 4 * k, 18 * k, 6 * k, "#f4f4f4", stroke=INK, stroke_width=0.8)
	quad(d, wall_quad(r.x0, 1.2, 1.9, 2.15, 2.65), d.lin(0, 0, 1, 0, [(0, "#a8b8c0"), (1, "#e8f0f4")]), stroke=WOOD_D, stroke_width=3)
	lamp = pt(0, 2.75, 2.8)
	d.line(lamp[0], pt(0, r.h, 2.8)[1], lamp[0], lamp[1], "#1a1a1a", 2)
	d.path("M%s %s L%s %s L%s %s Z" % F(lamp[0] - 26, lamp[1] + 14, lamp[0] + 26, lamp[1] + 14, lamp[0], lamp[1] - 6), GILT)
	cam_back(d, r.x1 - 0.2, 2.9, r.z1 - 0.1, flip=True, s=0.45)
	crack(d, 2.0, r.h - 0.2, r.z1, rng, 5, 0.22)
	if tod == "night":
		night(d, 0.55)
		glow(d, lp[0], lp[1] - 40, 160, LANTERN, 0.45)
		wp = pt(r.x1, 1.9, 2.8)
		glow(d, wp[0] - 60, wp[1], 200, "#8aa8d8", 0.2)
	else:
		glow(d, pt(r.x1, 1.9, 2.8)[0] - 100, 300, 360, "#fff8e8", 0.2)
	shade(d, 0.3)


def bg_manor_bedroom_night(d):
	bg_manor_bedroom(d, "night")


def sky_sea(d, hz, tod="day", rng=None, sun=(1040, 110)):
	"""Sky down to the horizon at hz and the bay below it, for the outdoor backgrounds."""
	rng = rng or random.Random(5)
	if tod == "dusk":
		d.rect(0, 0, W, hz + 2, d.vlin(0, hz, [(0, "#2a2a5e"), (0.45, "#8a4a6a"), (0.8, "#e8805a"), (1, "#ffc878")]))
		glow(d, sun[0], hz - 30, 360, "#ffd890", 0.55)
		d.circle(sun[0], hz - 30, 34, "#fff0c0", opacity=0.95)
		d.rect(0, hz, W, H - hz, d.vlin(hz, H, [(0, "#8a5a6a"), (0.3, "#4a3a5a"), (1, "#1a1a30")]))
		for k in range(24):
			y = hz + 4 + k * 8
			w_ = 30 + k * 8
			d.line(sun[0] - w_ / 2 + rng.uniform(-20, 20), y, sun[0] + w_ / 2 + rng.uniform(-20, 20), y, "#ffd890", 2, opacity=0.45 - k * 0.015)
		for (x, y, s) in ((240, 120, 0.9), (640, 80, 0.7)):
			with G(d, opacity=0.5):
				d.ellipse(x, y, 160 * s, 18 * s, "#e8a0a0")
	else:
		d.rect(0, 0, W, hz + 2, d.vlin(0, hz, [(0, "#3f7fd8"), (0.55, "#7fb6e8"), (0.9, "#c4e4f4"), (1, "#e2f2f6")]))
		glow(d, sun[0], sun[1], 300, "#fff6d8", 0.45)
		d.circle(sun[0], sun[1], 40, "#fffbe8", opacity=0.95)
		for (x, y, s, a) in ((200, 130, 1.1, 0.95), (560, 80, 0.8, 0.9), (860, 200, 0.9, 0.85), (380, hz - 60, 0.6, 0.7)):
			QA.cloud(d, x, y, s, rng, a)
		d.rect(0, hz, W, H - hz, d.vlin(hz, H, [(0, "#4aa0c0"), (0.25, SEA), (1, SEA_D)]))
		for k in range(26):
			f = k / 25.0
			y = hz + 4 + (H - hz) * f ** 1.6
			x0 = rng.uniform(-80, W)
			while x0 < W + 40:
				ln = rng.uniform(20, 90) * (0.4 + f * 1.4)
				d.line(x0, y, x0 + ln, y, "#bff4ff", 1 + 2 * f, opacity=0.22 + 0.2 * (1 - f))
				x0 += ln + rng.uniform(40, 160)
	d.line(0, hz, W, hz, "#e8fbff" if tod == "day" else "#ffd8b0", 2, opacity=0.6)


def gaol_far(d, x, base, s, tod="day", rng=None):
	"""The Gaol on its rock across the bay (QA.prison scaled), its cell lights lit at dusk."""
	rng = rng or random.Random(77)
	with G(d, transform=T(x, base, s), opacity=0.92):
		QA.prison(d, 0, 0, rng)
	if tod == "dusk":
		for blk in ((60, 200), (470, 200)):
			for rr in range(6):
				for cc in range(9):
					if rng.random() < 0.8:
						d.rect(x + (blk[0] + 14 + cc * 20) * s, base + (-70 - 230 + 20 + rr * 24) * s, 8 * s, 12 * s, "#ffd27a")
						glow(d, x + (blk[0] + 18 + cc * 20) * s, base + (-70 - 230 + 26 + rr * 24) * s, 12 * s, "#ffd27a", 0.35)


def telescope2d(d, x, y, s=1.0):
	with G(d, transform=T(x, y, s)):
		d.line(0, 0, -60, 170, "#2a2018", 8)
		d.line(0, 0, 60, 170, "#2a2018", 8)
		d.line(0, 0, 0, 176, "#2a2018", 8)
		with G(d, transform="rotate(-12)"):
			d.rect(-30, -40, 170, 34, d.vlin(-40, -6, [(0, GILT_L), (0.5, GILT), (1, GILT_D)]), rx=10, stroke=INK, stroke_width=5)
			d.rect(-70, -44, 50, 26, GILT_D, rx=6, stroke=INK, stroke_width=4)
			d.rect(130, -46, 22, 46, GILT_D, rx=6, stroke=INK, stroke_width=4)
		d.circle(0, -6, 10, "#3a2a18", stroke=INK, stroke_width=3)


def bg_manor_terrace(d, tod="day"):
	"""The roofed terrace on the clifftop: columns and the roof's edge overhead, the balustrade, the bay and, across it,
	the Gaol on its rock; the telescope at the rail aimed at the cell windows, a tea table, deckchairs."""
	rng = random.Random(1901)
	hz = 360
	sky_sea(d, hz, tod, rng, sun=(1060, 120) if tod == "day" else (180, 0))
	gaol_far(d, 460, hz + 12, 0.62, tod, rng)
	# the far headland on the right with a lighthouse on its point
	d.blob([(860, hz + 4), (980, hz - 26), (1120, hz - 40), (1300, hz - 30), (1300, hz + 6)], "#5a6a5a" if tod == "day" else "#2a2838", t=0.4)
	d.rect(1180, hz - 90, 16, 54, "#f4f0e8" if tod == "day" else "#c8c0d0")
	d.rect(1176, hz - 98, 24, 10, "#c8402a")
	if tod == "dusk":
		d.poly([(1188, hz - 94), (1300, hz - 130), (1300, hz - 60)], "#fff4c8", opacity=0.25)
	for (x, y) in ((300, 180), (330, 196), (740, 150)):
		gull(d, x, y, 1.4, 0.9)
	# the flagstones, the balustrade with its turned balusters, the coping
	floor_y = 600
	d.rect(0, floor_y, W, H - floor_y, d.vlin(floor_y, H, [(0, "#b8b2a4"), (1, "#8a8478")]))
	for x in range(-80, W + 200, 170):
		d.line(x, floor_y, x - 160, H, "#6a665e", 3, opacity=0.6)
	for y in (628, 664, 708):
		d.line(0, y, W, y, "#6a665e", 3, opacity=0.6)
	d.rect(0, 492, W, 22, "#e0dacc", stroke=INK, stroke_width=3)
	d.rect(0, 584, W, 20, "#c8c2b4", stroke=INK, stroke_width=3)
	for x in range(14, W, 46):
		d.path("M%s 514 Q%s 532 %s 540 Q%s 558 %s 584 L%s 584 Q%s 558 %s 540 Q%s 532 %s 514 Z" % F(x, x - 8, x - 2, x - 10, x - 2, x + 24, x + 32, x + 24, x + 30, x + 22),
			d.lin(x, 0, x + 22, 0, [(0, "#b8b2a4"), (0.4, "#f4f0e8"), (1, "#a8a294")]), stroke=INK, stroke_width=1.6)
	# the roof edge and two columns framing the view
	d.rect(0, 0, W, 56, d.vlin(0, 56, [(0, "#a8a294"), (1, "#e8e2d4")]))
	d.rect(0, 48, W, 14, "#c8c2b4", stroke=INK, stroke_width=2)
	for x in (70, 1210):
		d.rect(x - 34, 56, 68, floor_y - 56, d.lin(x - 34, 0, x + 34, 0, [(0, "#b8b2a4"), (0.4, "#f8f4ec"), (1, "#a8a294")]), stroke=INK, stroke_width=2)
		d.rect(x - 46, 56, 92, 18, "#e0dacc", stroke=INK, stroke_width=2)
		d.rect(x - 46, floor_y - 18, 92, 18, "#e0dacc", stroke=INK, stroke_width=2)
	# hanging lamps from the roof
	for x in (380, 900):
		d.line(x, 60, x, 120, "#1a1a1a", 2)
		d.path("M%s 120 L%s 120 L%s 104 Z" % F(x - 26, x + 26, x), GILT, stroke=INK, stroke_width=1.5)
		if tod == "dusk":
			glow(d, x, 126, 90, LANTERN, 0.5)
		d.circle(x, 124, 6, LANTERN_HOT if tod == "dusk" else "#f4ecd8")
	# the telescope at the rail on the right, aimed at the cells
	telescope2d(d, 980, 430, 0.95)
	# a tea table and two chairs on the left, a deckchair
	tx, ty = 330, 610
	d.ellipse(tx, ty - 90, 70, 16, "#f4f0e8", stroke=INK, stroke_width=2)
	d.line(tx, ty - 86, tx, ty, "#2a2a28", 6)
	d.line(tx - 30, ty, tx + 30, ty, "#2a2a28", 5)
	d.rect(tx - 16, ty - 116, 22, 22, "#f4f0e8", stroke=INK, stroke_width=1.5, rx=4)
	d.ellipse(tx + 20, ty - 100, 14, 5, "#f4f0e8", stroke=INK, stroke_width=1)
	for sd in (-1, 1):
		cx = tx + sd * 110
		d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(cx - 30, ty - 150, cx + 30, ty - 150, cx + 26, ty - 70, cx - 26, ty - 70), "#f4f0e8", stroke=INK, stroke_width=1.5)
		d.rect(cx - 34, ty - 72, 68, 10, "#e8e2d4", stroke=INK, stroke_width=1.5)
		d.line(cx - 28, ty - 62, cx - 30, ty + 6, "#2a2a28", 4)
		d.line(cx + 28, ty - 62, cx + 30, ty + 6, "#2a2a28", 4)
	for (x, c) in ((560, "#c8402a"), (720, "#e8a040")):
		d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(x - 28, 600, x + 28, 600, x + 22, 560, x - 22, 560), "#b0603a", stroke=INK, stroke_width=1.5)
		for j in range(5):
			d.circle(x - 16 + j * 8, 552 - (j % 2) * 6, 10, c, stroke=dark(c, 0.3), stroke_width=1)
	cp = (1150, 80)
	croc_cam(d, cp[0], cp[1], 0.7, flip=True)
	if tod == "dusk":
		d.rect(0, 0, W, H, "#2a1a3a", opacity=0.25)
	shade(d, 0.22)


def bg_manor_terrace_dusk(d):
	bg_manor_terrace(d, "dusk")


def bg_manor_shore(d):
	"""The shore under the cliff the morning after the flood: the wrecked Mudlark listing on the pebbles, her forward
	stack sheared, the path zig-zagging up the cliff to Warden's Rest. (The earthquake cutscene's last frame, plus gulls,
	salvage, and the Gaol across the bay.)"""
	rng = random.Random(2002)
	QA.shore(d)
	gaol_far(d, 40, 302, 0.18, "day", rng)
	for (x, y, s) in ((520, 110, 1.4), (560, 130, 1.1), (180, 180, 1.0), (700, 60, 1.2)):
		gull(d, x, y, s, 0.95)
	# salvage stacked by the tide line, mid-frame (the lower corners stay calm)
	for (x, y, w_, h_, c) in ((410, 470, 70, 46, "#8a5a34"), (450, 440, 52, 34, "#9a6a40"), (880, 500, 60, 40, "#7a4a2a")):
		d.rect(x - w_ / 2, y - h_, w_, h_, d.lin(x - w_ / 2, 0, x + w_ / 2, 0, [(0, dark(c, 0.2)), (0.5, light(c, 0.1)), (1, dark(c, 0.35))]), stroke=INK, stroke_width=2.5)
		d.line(x - w_ / 2, y - h_ / 2, x + w_ / 2, y - h_ / 2, dark(c, 0.5), 2)
	d.ellipse(840, 515, 26, 8, "#e8e4dc", stroke=INK, stroke_width=2)
	d.ellipse(840, 515, 14, 4, "#c8402a")


def bg_manor_wreck(d):
	"""Inside the beached Mudlark: the infirmary knocked sideways, the cot over, the cabinet hanging open, sand drifted in
	through the breach, a porthole of daylight, and the nurse's tall steel locker."""
	global V
	V = View(vy=300, eye=1.4, z0=6.0, m=118)
	rng = random.Random(2103)
	r = Room(w=6.0, h=2.6, z0=0.9, z1=6.0)
	with G(d, transform="rotate(-5 640 360) translate(-30 -20) scale(1.05)"):
		cream = "#ece2c8"
		teal = "#2e7a74"
		shell(d, r, back_grad(d, r, cream), side_grad(d, r, cream), side_grad(d, r, cream, False), "#8a6a48", ceil_grad(d, r, "#d8ccb0"))
		wainscot(d, r, 1.0, teal, panels=False)
		dd = ""
		for i in range(int((r.x1 - r.x0) / 0.12)):
			a, b = pt(r.x0 + i * 0.12, 0, r.z1), pt(r.x0 + i * 0.12, 1.0, r.z1)
			dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
		d.spath(dd, dark(teal, 0.35), 1.2, opacity=0.6)
		parquet(d, r, "#8a6a48")
		for z in zs(1.5, r.z1, 5):
			quad(d, [(r.x0, r.h - 0.01, z - 0.06), (r.x1, r.h - 0.01, z - 0.06), (r.x1, r.h - 0.01, z + 0.06), (r.x0, r.h - 0.01, z + 0.06)], "#6a4a2a")
		# the porthole of daylight, the medicine cabinet hanging open, a shelf of manuals
		pc = pt(-1.6, 1.7, r.z1)
		k = V.s(r.z1)
		d.circle(pc[0], pc[1], 0.32 * M * k + 8, GILT, stroke=INK, stroke_width=2)
		d.circle(pc[0], pc[1], 0.32 * M * k, d.vlin(pc[1] - 30, pc[1] + 30, [(0, "#a9d2ef"), (0.55, "#e2f2f6"), (0.56, SEA_L), (1, SEA)]))
		glow(d, pc[0], pc[1], 180, "#f4fbff", 0.35)
		box3(d, 0.2, 1.2, 1.2, 2.1, r.z1 - 0.25, r.z1, "#f4f4f0", sw=1.2)
		quad(d, back_quad(0.25, 1.15, 1.25, 2.05, r.z1 - 0.25), "#d8d8d0")
		for j in range(2):
			hline(d, 0.25, 1.15, 1.5 + j * 0.28, r.z1 - 0.25, "#a8a8a0", 3)
		for (bx_, c) in ((0.35, "#c8402a"), (0.5, "#e8e4dc"), (0.75, "#4a8ab8")):
			upright(d, bx_, 1.52, r.z1 - 0.2, 0.08, 0.16, c, stroke=INK, stroke_width=0.6)
		quad(d, [(1.2, 1.2, r.z1 - 0.25), (1.2, 2.1, r.z1 - 0.25), (1.75, 2.0, r.z1 - 0.7), (1.75, 1.3, r.z1 - 0.7)], "#e8e8e2", stroke=INK, stroke_width=1.2)
		box3(d, -0.6, -0.1, 1.2, 1.24, r.z1 - 0.22, r.z1, WOOD, sw=0.8)
		for i in range(5):
			upright(d, -0.55 + i * 0.09, 1.24, r.z1 - 0.12, 0.07, 0.24 - 0.02 * (i % 2), rng.choice(["#2a4a6a", "#6a2a2a", "#3a5a3a", "#8a7a5a"]), stroke=INK, stroke_width=0.6)
		# the steel locker on the right wall, with an empty name plate
		box3(d, r.x1 - 0.5, r.x1, 0, 2.0, 3.6, 4.3, "#6a7a84", top="#8a9aa4", side="#4a5a64", sw=1.4)
		for j in range(4):
			quad(d, wall_quad(r.x1 - 0.5, 1.6 + j * 0.06, 1.63 + j * 0.06, 3.75, 4.15), "#3a4a54")
		quad(d, wall_quad(r.x1 - 0.5, 1.3, 1.4, 3.8, 4.1), "#f4efe0", stroke=INK, stroke_width=0.8)
		# the cot on its side, a blanket, the overturned stool
		box3(d, -2.8, -0.9, 0.0, 0.7, 2.4, 2.7, "#c8ccd0", top="#e8ecf0", sw=1.2)
		quad(d, back_quad(-2.7, -1.0, 0.05, 0.65, 2.39), "#e8e4dc")
		quad(d, floor_quad(-2.4, -1.2, 2.0, 2.4, 0.01), "#6a8aa8")
		# sand drifted in through the breach, a sea-wet streak, scattered papers
		for (x_, z_, rx, rz) in ((2.2, 2.6, 1.2, 1.0), (1.2, 4.6, 1.4, 0.7), (-0.4, 3.4, 0.8, 0.5)):
			ell3(d, x_, 0.005, z_, rx, rz, d.brad([(0, "#e0cc9a"), (0.7, "#d8c08a", 0.8), (1, "#d8c08a", 0)]))
		for i in range(7):
			p_ = pt(rng.uniform(-2, 2), 0.01, rng.uniform(2.0, 5.0))
			k_ = V.s(4.0)
			with G(d, transform="rotate(%s %s %s)" % F(rng.uniform(-40, 40), p_[0], p_[1])):
				d.rect(p_[0] - 12 * k_, p_[1] - 3 * k_, 24 * k_, 6 * k_, "#f4efe0", stroke="#a89a7a", stroke_width=0.6)
		lamp = pt(0.3, 2.3, 3.4)
		d.line(lamp[0], pt(0, r.h, 3.4)[1], lamp[0] + 20, lamp[1], "#1a1a1a", 2)
		d.path("M%s %s L%s %s L%s %s Z" % F(lamp[0] - 2, lamp[1] + 18, lamp[0] + 44, lamp[1] + 10, lamp[0] + 20, lamp[1] - 6), GILT)
	glow(d, 420, 260, 320, "#f4fbff", 0.15)
	shade(d, 0.35)


def bg_manor_cliff_path(d):
	"""The cliff path from the terrace toward the causeway: grass and gorse inland, a low stone wall on the edge with the
	sea below, a wind-bent tree, a bench with a view, a signpost, and the Gaol ahead across the water."""
	rng = random.Random(2204)
	hz = 300
	sky_sea(d, hz, "day", rng, sun=(1100, 90))
	gaol_far(d, 600, hz + 10, 0.42, "day", rng)
	# the causeway running out to it
	d.poly([(560, hz + 40), (640, hz + 40), (900, hz + 4), (870, hz + 4)], "#b8b0a0", stroke=INK, stroke_width=1)
	# the headland: grass rising on the left to the near edge, the path running away down its middle
	land = [(-20, H), (-20, 330), (200, 316), (480, 330), (700, 352), (860, 380), (1000, 430), (1300, 470), (1300, H)]
	d.blob(land, d.vlin(310, H, [(0, "#7ab85a"), (0.5, "#5a9a46"), (1, "#3f7a3a")]), t=0.3)
	path_ = [(470, 336), (530, 336), (760, H + 10), (180, H + 10)]
	d.poly(path_, d.vlin(336, H, [(0, "#d8ccb0"), (1, "#b8aa8a")]))
	for i in range(14):
		t = (i + 1) / 15.0
		y = 336 + (H - 336) * t ** 1.4
		xl = 470 + (180 - 470) * (y - 336) / (H - 336)
		xr = 530 + (760 - 530) * (y - 336) / (H - 336)
		d.line(xl, y, xr, y, "#9a8a6a", 1.5, opacity=0.5)
	# the low stone wall along the cliff edge on the right, the drop and the sea beyond it
	wall = [(560, 352), (1300, 520)]
	for i in range(40):
		t = i / 40.0
		x0_ = 560 + (1300 - 560) * t
		y0_ = 352 + (520 - 352) * t
		x1_ = 560 + (1300 - 560) * (t + 1 / 40.0)
		y1_ = 352 + (520 - 352) * (t + 1 / 40.0)
		h0 = 10 + 80 * t
		d.poly([(x0_, y0_), (x1_, y1_), (x1_, y1_ - h0 - 2), (x0_, y0_ - h0)], rng.choice(["#a8a294", "#9a9486", "#b4ae9e"]), stroke="#5a564e", stroke_width=1)
	d.line(560, 342, 1300, 432, "#d8d2c4", 6)
	# gorse and grass tufts on the left, a wind-bent tree, a bench, a signpost
	for _ in range(30):
		x = rng.uniform(0, 440)
		y = rng.uniform(340, 640)
		s = 0.4 + (y - 340) / 300.0
		d.ellipse(x, y, 30 * s, 14 * s, rng.choice(["#4a7a3a", "#5a8a3a", "#3a6a2e"]))
		if rng.random() < 0.5:
			for j in range(3):
				d.circle(x + rng.uniform(-20, 20) * s, y - rng.uniform(0, 10) * s, 3 * s, "#f0c830")
	d.spath("M%s %s Q%s %s %s %s" % F(250, 520, 230, 380, 330, 260), "#5a3a20", 22)
	for (x, y, rr) in ((340, 250, 70), (410, 230, 50), (290, 240, 46), (380, 280, 40)):
		d.circle(x, y, rr, "#3f7a3a", stroke="#2a5a2a", stroke_width=2)
	bx, by = 650, 470
	d.rect(bx - 70, by - 46, 140, 12, WOOD, stroke=INK, stroke_width=2)
	d.rect(bx - 70, by - 26, 140, 10, WOOD, stroke=INK, stroke_width=2)
	for sd in (-1, 1):
		d.line(bx + sd * 60, by - 20, bx + sd * 62, by + 10, "#2a2a28", 5)
	sx, sy = 520, 400
	d.line(sx, sy, sx, sy - 120, WOOD_D, 7)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(sx, sy - 116, sx + 80, sy - 116, sx + 96, sy - 104, sx + 80, sy - 92), WOOD_L, stroke=INK, stroke_width=2)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % F(sx, sy - 86, sx - 80, sy - 86, sx - 96, sy - 74, sx - 80, sy - 62), WOOD_L, stroke=INK, stroke_width=2)
	for (x, y) in ((820, 180), (860, 200)):
		gull(d, x, y, 1.3)
	cam = (sx + 4, sy - 132)
	croc_cam(d, cam[0], cam[1], 0.5)
	shade(d, 0.2)


def bg_manor_boathouse(d):
	"""The boathouse in its cove: a slip of sea water down the middle, walkways either side, rowing boats chained in it
	and every one stove in, oars and nets on the walls, the sea doors chained shut with a crocodile padlock."""
	global V
	V = View(vy=300, eye=1.6, z0=12.0, m=62)
	rng = random.Random(2305)
	r = Room(w=9.0, h=4.6, z0=1.0, z1=12.0)
	timber = "#6a4a2e"
	shell(d, r, back_grad(d, r, timber), side_grad(d, r, timber), side_grad(d, r, timber, False), "#4a3420", ceil_grad(d, r, "#3a2818"))
	for x in (r.x0, r.x1):
		dd = ""
		for z in zs(r.z0, r.z1, 30):
			a, b = pt(x, 0, z), pt(x, r.h, z)
			dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
		d.spath(dd, dark(timber, 0.4), 1.4, opacity=0.6)
	# rafters
	for z in zs(r.z0 + 1, r.z1, 6):
		a, b = pt(r.x0, r.h - 0.3, z), pt(r.x1, r.h - 0.3, z)
		d.line(a[0], a[1], b[0], b[1], "#2a1a0e", 8 * V.s(z) / 2)
	# the sea doors at the far end, chained, daylight round their edges
	quad(d, back_quad(-2.2, 2.2, 0, 3.4, r.z1), "#5a3e24", stroke=INK, stroke_width=2)
	for i in range(1, 8):
		a, b = pt(-2.2 + i * 0.55, 0, r.z1), pt(-2.2 + i * 0.55, 3.4, r.z1)
		d.line(a[0], a[1], b[0], b[1], "#3a2414", 2)
	for y in (0.8, 2.4):
		hline(d, -2.2, 2.2, y, r.z1, "#3a2414", 6)
	g0, g1 = pt(-2.2, 3.4, r.z1), pt(2.2, 0, r.z1)
	d.rect(g0[0] - 3, g0[1] - 3, g1[0] - g0[0] + 6, 3, "#fff4d8", opacity=0.8)
	c0 = pt(0, 1.5, r.z1 - 0.05)
	d.spath("M%s %s Q%s %s %s %s" % F(c0[0] - 50, c0[1] - 20, c0[0], c0[1] + 30, c0[0] + 50, c0[1] - 20), "#8a8a90", 5)
	d.rect(c0[0] - 14, c0[1], 28, 22, "#43a047", stroke=INK, stroke_width=2, rx=4)
	d.circle(c0[0] - 5, c0[1] + 6, 2.5, RED_EYE)
	# the slip of water and the walkways
	quad(d, floor_quad(r.x0, -1.6, r.z0, r.z1), "#7a5a38")
	quad(d, floor_quad(1.6, r.x1, r.z0, r.z1), "#7a5a38")
	for x0_, x1_ in ((r.x0, -1.6), (1.6, r.x1)):
		dd = ""
		for z in zs(r.z0, r.z1, 40):
			a, b = pt(x0_, 0, z), pt(x1_, 0, z)
			dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
		d.spath(dd, "#4a3420", 1.2, opacity=0.6)
	quad(d, floor_quad(-1.6, 1.6, r.z0, r.z1, -0.4), d.vlin(pt(0, -0.4, r.z1)[1], H, [(0, "#3a8aa0"), (1, "#14506a")]))
	for x_ in (-1.6, 1.6):
		quad(d, wall_quad(x_, -0.4, 0, r.z0, r.z1), "#3a2818")
	for _ in range(30):
		z_ = rng.uniform(2, 11)
		x_ = rng.uniform(-1.4, 1.4)
		a = pt(x_, -0.39, z_)
		d.line(a[0], a[1], a[0] + 30 * V.s(z_) / 3, a[1], "#bff4ff", 1.5, opacity=0.4)
	# the boats in the slip, stove in
	for (z_, c) in ((9.4, "#2a5a8a"), (6.2, "#a83a2a")):
		b = pt(0, -0.3, z_)
		k = V.s(z_)
		d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % F(b[0] - 70 * k, b[1] - 30 * k, b[0], b[1] + 30 * k, b[0] + 70 * k, b[1] - 30 * k,
			b[0] + 60 * k, b[1] - 36 * k, b[0], b[1] - 10 * k, b[0] - 60 * k, b[1] - 36 * k), c, stroke=INK, stroke_width=1.5)
		d.path("M%s %s L%s %s L%s %s Z" % F(b[0] - 10 * k, b[1] - 6 * k, b[0] + 14 * k, b[1] - 4 * k, b[0] + 2 * k, b[1] + 10 * k), "#1a1a1a")
		d.line(b[0] - 60 * k, b[1] - 30 * k, b[0] + 60 * k, b[1] - 30 * k, dark(c, 0.4), 2)
	# oars and nets on the walls, a workbench, a lantern
	for i, z_ in enumerate((3.0, 3.4, 3.8)):
		a, b = pt(r.x0, 0.4, z_), pt(r.x0, 3.0, z_ + 0.3)
		d.line(a[0], a[1], b[0], b[1], WOOD_L, 6)
	net = V.pts(wall_quad(r.x1, 1.4, 3.2, 5.0, 8.0))
	d.poly(net, "none", stroke="#c8b890", stroke_width=1.5)
	for i in range(1, 8):
		t = i / 8
		a = (net[0][0] + (net[1][0] - net[0][0]) * t, net[0][1] + (net[1][1] - net[0][1]) * t)
		b = (net[3][0] + (net[2][0] - net[3][0]) * t, net[3][1] + (net[2][1] - net[3][1]) * t)
		d.line(a[0], a[1], b[0], b[1], "#c8b890", 1.2, opacity=0.8)
		a = (net[0][0] + (net[3][0] - net[0][0]) * t, net[0][1] + (net[3][1] - net[0][1]) * t)
		b = (net[1][0] + (net[2][0] - net[1][0]) * t, net[1][1] + (net[2][1] - net[1][1]) * t)
		d.line(a[0], a[1], b[0], b[1], "#c8b890", 1.2, opacity=0.8)
	for i in range(4):
		p_ = pt(r.x1, 2.0 + 0.3 * (i % 2), 5.5 + i * 0.7)
		d.circle(p_[0], p_[1], 8, ["#e8553d", YUZU_C, "#f4efe0", "#e8553d"][i], stroke=INK, stroke_width=1)
	box3(d, r.x0, r.x0 + 0.8, 0, 0.9, 8.0, 10.0, WOOD, sw=1.2)
	l_ = pt(-3.6, 2.6, 7.0)
	glow(d, l_[0], l_[1], 140, LANTERN, 0.45)
	d.rect(l_[0] - 8, l_[1] - 14, 16, 22, "#3a3a3a", stroke=INK, stroke_width=1)
	d.rect(l_[0] - 5, l_[1] - 10, 10, 14, LANTERN_HOT)
	shade(d, 0.4)


YUZU_C = "#ffc93c"


def bg_manor_prison_yard(d):
	"""The Gaol's yard: grey walls topped with wire, the cell block's rows of barred windows, the watchtower with its
	searchlight, the gatehouse office with a typewriter behind its window, and the door to the Visiting Room."""
	global V
	V = View(vy=300, eye=1.6, z0=18.0, m=44)
	rng = random.Random(2406)
	r = Room(w=26.0, h=6.0, z0=1.0, z1=18.0)
	d.rect(0, 0, W, H, d.vlin(0, 320, [(0, "#6f9fd0"), (1, "#c8dcec")]))
	for (x, y, s) in ((240, 90, 0.9), (900, 60, 0.7)):
		QA.cloud(d, x, y, s, rng, 0.8)
	grey = "#8a8c90"
	# the cell block across the back, taller than the walls
	quad(d, back_quad(-9.0, 9.0, 0, 11.0, r.z1), d.vlin(pt(0, 11, r.z1)[1], pt(0, 0, r.z1)[1], [(0, "#9a9ca2"), (1, "#6a6c72")]))
	quad(d, back_quad(-9.4, 9.4, 11.0, 11.6, r.z1), "#5a5c62")
	for row in range(5):
		for col in range(12):
			x = -8.0 + col * 1.45
			y = 1.6 + row * 1.9
			quad(d, back_quad(x - 0.3, x + 0.3, y, y + 0.9, r.z1), "#1a1c22")
			for b in range(3):
				a, bb = pt(x - 0.15 + b * 0.15, y, r.z1), pt(x - 0.15 + b * 0.15, y + 0.9, r.z1)
				d.line(a[0], a[1], bb[0], bb[1], "#8a8c94", 1.5)
	back_door(d, 5.8, r.z1, 1.1, 2.3, "#4a4c52", frame="#2a2c30", panels=False)
	upright(d, 5.8, 2.5, r.z1, 0.9, 0.2, "#e8d8a0", stroke=INK, stroke_width=1)
	# the yard walls left and right, topped with wire
	for x in (r.x0, r.x1):
		quad(d, wall_quad(x, 0, r.h, r.z0, r.z1), side_grad(d, r, grey, x < 0))
		dd = ""
		for y in [0.4 * i for i in range(1, 15)]:
			a, b = pt(x, y, r.z0), pt(x, y, r.z1)
			dd += "M%s %s L%s %s " % F(a[0], a[1], b[0], b[1])
		d.spath(dd, "#6a6c70", 1, opacity=0.5)
		for z in zs(r.z0, r.z1, 20):
			a, b = pt(x, r.h, z), pt(x, r.h + 0.8, z)
			d.line(a[0], a[1], b[0], b[1], "#3a3a3e", 2)
		for y in (r.h + 0.3, r.h + 0.6):
			side_line(d, x, y, r.z0, r.z1, "#5a5a5e", 1.5)
	# flagstones with the painted yellow exercise ring
	flagstones(d, r, "#a8a8a4", 1.4, rng)
	for i in range(28):
		a0 = i / 28 * TAU
		a1 = (i + 0.5) / 28 * TAU
		p0 = pt(5 * math.cos(a0), 0.01, 10 + 3.5 * math.sin(a0))
		p1 = pt(5 * math.cos(a1), 0.01, 10 + 3.5 * math.sin(a1))
		d.line(p0[0], p0[1], p1[0], p1[1], "#e8c030", 4)
	# the gatehouse office on the left, its window and the typewriter behind it
	box3(d, -12.8, -8.0, 0, 3.0, 9.0, 12.5, BRICK, top="#5a3a2a", side=dark(BRICK, 0.2), sw=1.4)
	quad(d, wall_quad(-8.0, 1.0, 2.0, 10.0, 11.4), "#2a3038", stroke="#e8e4dc", stroke_width=4)
	tp = pt(-8.1, 1.15, 10.7)
	k = V.s(10.7)
	d.rect(tp[0] - 16 * k, tp[1] - 12 * k, 32 * k, 12 * k, "#2a2a2a")
	d.rect(tp[0] - 10 * k, tp[1] - 22 * k, 20 * k, 10 * k, "#f4efe0")
	# the watchtower on the right with its searchlight
	box3(d, 8.0, 10.0, 0, 9.0, 13.0, 15.0, "#7a7c82", sw=1.4)
	box3(d, 7.6, 10.4, 9.0, 10.6, 12.6, 15.4, "#5a5c62", sw=1.4)
	quad(d, back_quad(7.8, 10.2, 9.3, 10.3, 12.6), "#2a3038")
	sl = pt(8.5, 10.9, 12.8)
	d.circle(sl[0], sl[1], 12, "#f4f4ec", stroke=INK, stroke_width=2)
	d.poly([(sl[0], sl[1]), (sl[0] - 320, sl[1] + 260), (sl[0] - 160, sl[1] + 320)], "#fffbe8", opacity=0.12)
	box3(d, -3.0, -1.4, 0, 0.45, 9.6, 10.0, WOOD, sw=1)
	cam_back(d, r.x0 + 0.4, 4.5, 6.0, s=0.6)
	shade(d, 0.2)


def bg_manor_visiting_room(d):
	"""The Visiting Room: a long counter cut by thick glass, booths with a telephone on a hook in each, and through the
	glass the prisoners' chairs under a barred light. A sign about the thirty seconds."""
	global V
	V = View(vy=300, eye=1.4, z0=4.6, m=120)
	rng = random.Random(2507)
	r = Room(w=12.0, h=3.4, z0=0.6, z1=4.6)
	wall = "#b8c4c0"
	shell(d, r, back_grad(d, r, "#8a9894"), side_grad(d, r, wall), side_grad(d, r, wall, False), "#7a7e7e", ceil_grad(d, r, "#c8cccc"))
	wainscot(d, r, 1.2, "#4a6a66", panels=False)
	flagstones(d, r, "#8a8e8e", 0.6, rng)
	# the far side: chairs facing the glass, a barred door, a barred light
	for i in range(7):
		x = -4.5 + i * 1.5
		chair3(d, x, 3.4, "#6a6c6e", "#4a4c4e", facing="toward", w=0.46)
	back_door(d, 0, r.z1, 1.1, 2.2, "#5a5c62", frame="#2a2c30", panels=False)
	for i in range(6):
		a, b = pt(-0.45 + i * 0.18, 0, r.z1 - 0.02), pt(-0.45 + i * 0.18, 2.2, r.z1 - 0.02)
		d.line(a[0], a[1], b[0], b[1], "#2a2a2e", 4)
	light_pool(d, 0, 2.8, 3.2, 1.6, "#e8f0ff", 0.35)
	# the glass, floor to ceiling above the counter, with reflections
	gz = 2.2
	quad(d, back_quad(r.x0, r.x1, 0.95, r.h, gz), "#c8e8f0", opacity=0.22)
	for x in (-4.0, -1.0, 2.6, 5.0):
		quad(d, [(x, 1.1, gz), (x + 0.5, 1.1, gz), (x + 1.4, 3.2, gz), (x + 0.9, 3.2, gz)], "#ffffff", opacity=0.18)
	hline(d, r.x0, r.x1, r.h - 0.02, gz, "#3a3c40", 6)
	# the counter on this side, booth dividers, telephones on hooks, stools
	box3(d, r.x0, r.x1, 0, 0.95, gz - 0.55, gz, "#7a8484", top="#5a6262", sw=1.4)
	for i in range(8):
		x = -5.25 + i * 1.5
		box3(d, x - 0.03, x + 0.03, 0.95, 2.5, gz - 0.7, gz, "#4a5454", sw=1)
	for i in range(7):
		x = -4.5 + i * 1.5
		ph = pt(x + 0.4, 1.4, gz - 0.05)
		k = V.s(gz - 0.05)
		d.rect(ph[0] - 8 * k, ph[1] - 18 * k, 16 * k, 30 * k, "#1a1a1a", rx=4 * k)
		d.spath("M%s %s Q%s %s %s %s" % F(ph[0], ph[1] + 12 * k, ph[0] - 20 * k, ph[1] + 40 * k, ph[0] - 10 * k, pt(0, 0.95, gz - 0.3)[1]), "#1a1a1a", 2 * k)
	for i in range(5):
		x = -3.0 + i * 1.5
		b = pt(x, 0, 1.3)
		k = V.s(1.3)
		d.ellipse(b[0], b[1] - 60 * k, 22 * k, 8 * k, "#8a2a24", stroke=INK, stroke_width=1)
		d.line(b[0], b[1] - 58 * k, b[0], b[1], "#3a3a3e", 4 * k)
	# the sign and the clock on the wall above, behind us in the glass's reflection: put them high on the side walls
	quad(d, wall_quad(r.x0, 2.3, 2.9, 1.0, 1.9), "#f4efe0", stroke=INK, stroke_width=2)
	sp = V.pts(wall_quad(r.x0, 2.35, 2.85, 1.05, 1.85))
	glyphs(d, min(q[0] for q in sp) + 4, min(q[1] for q in sp) + 4, max(q[0] for q in sp) - min(q[0] for q in sp) - 8, 40, 2, "#a01810", rng, sw=2.4)
	ck = pt(r.x1, 2.6, 1.5)
	d.ellipse(ck[0], ck[1], 16, 28, "#f4efe0", stroke="#2a2a2a", stroke_width=4)
	cam_back(d, r.x1 - 0.3, 3.0, r.z1 - 0.1, flip=True, s=0.5)
	for x in (-3.0, 3.0):
		lp = pt(x, 3.0, 1.6)
		d.line(lp[0], 0, lp[0], lp[1], "#1a1a1a", 2)
		d.path("M%s %s L%s %s L%s %s Z" % F(lp[0] - 40, lp[1] + 16, lp[0] + 40, lp[1] + 16, lp[0], lp[1] - 4), "#5a6464")
		glow(d, lp[0], lp[1] + 20, 200, "#e8f4ff", 0.3)
	shade(d, 0.28)



# --------------------------------------------------------------------------------------
BGS = {
	"manor_hall": bg_manor_hall,
	"manor_hall_night": bg_manor_hall_night,
	"manor_dining": bg_manor_dining,
	"manor_dining_day": bg_manor_dining_day,
	"manor_cloakroom": bg_manor_cloakroom,
	"manor_kitchen": bg_manor_kitchen,
	"manor_pantry": bg_manor_pantry,
	"manor_cellar": bg_manor_cellar,
	"manor_generator": bg_manor_generator,
	"manor_library": bg_manor_library,
	"manor_library_after": bg_manor_library_after,
	"manor_gallery": bg_manor_gallery,
	"manor_gallery_turned": bg_manor_gallery_turned,
	"manor_music": bg_manor_music,
	"manor_conservatory": bg_manor_conservatory,
	"manor_bath": bg_manor_bath,
	"manor_attic": bg_manor_attic,
	"manor_passage": bg_manor_passage,
	"manor_corridor": bg_manor_corridor,
	"manor_bedroom": bg_manor_bedroom,
	"manor_bedroom_night": bg_manor_bedroom_night,
	"manor_terrace": bg_manor_terrace,
	"manor_terrace_dusk": bg_manor_terrace_dusk,
	"manor_shore": bg_manor_shore,
	"manor_wreck": bg_manor_wreck,
	"manor_cliff_path": bg_manor_cliff_path,
	"manor_boathouse": bg_manor_boathouse,
	"manor_prison_yard": bg_manor_prison_yard,
	"manor_visiting_room": bg_manor_visiting_room,
}


def main():
	args = sys.argv[1:]
	only = None
	if "--list" in args:
		for k in BGS:
			print(k)
		return
	if "--only" in args:
		only = set(args[args.index("--only") + 1].split(","))
	bg_dir = os.path.join(ROOT, "art", "bg")
	os.makedirs(bg_dir, exist_ok=True)
	for bid, fn in BGS.items():
		if only and bid not in only:
			continue
		global V
		V = View()
		d = Doc()
		fn(d)
		txt = d.svg()
		bad = [t for t in FORBIDDEN if t in txt]
		if bad:
			raise SystemExit("%s contains forbidden SVG features: %s" % (bid, bad))
		with open(os.path.join(bg_dir, bid + ".svg"), "w", encoding="utf-8") as f:
			f.write(txt)
		print("bg %-22s %6.1f KB  %d elements" % (bid, len(txt) / 1024.0, txt.count("<") - txt.count("</")))


if __name__ == "__main__":
	main()
