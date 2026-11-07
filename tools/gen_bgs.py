#!/usr/bin/env python3
"""SPLASH TRIAL - background + Truth Drop icon generator.

Writes:
  art/bg/<id>.svg            1280x720 backgrounds (ids from docs/ARCHITECTURE.md section 6)
  art/props/clue_<id>.svg    200x200 Truth Drop icons (ids from scripts/data/clues.gd)

Usage (from the project root):
  python3 tools/gen_bgs.py                 # write all art
  python3 tools/gen_bgs.py --debug DIR     # also write debug copies with hotspot rects / portrait zones
  python3 tools/gen_bgs.py --only bath,lobby

Only SVG 1.1 basics are used (no text, filters, images, styles) so Godot's ThorVG rasterizes it.
"""
import math
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 1280, 720

# --------------------------------------------------------------------------------------
# tiny SVG toolkit
# --------------------------------------------------------------------------------------


def fm(v):
	if isinstance(v, float):
		if abs(v - round(v)) < 0.05:
			return str(int(round(v)))
		return ("%.1f" % v)
	return str(v)


def _attrs(kw):
	out = []
	for k, v in kw.items():
		if v is None:
			continue
		k = k.rstrip("_").replace("_", "-")
		if isinstance(v, (int, float)):
			v = fm(v)
		out.append('%s="%s"' % (k, v))
	return " ".join(out)


def pts(seq):
	return " ".join("%s,%s" % (fm(float(x)), fm(float(y))) for x, y in seq)


def hx(c):
	c = c.lstrip("#")
	return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(rgb):
	return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in rgb)


def mix(a, b, t):
	A, B = hx(a), hx(b)
	return to_hex([A[i] + (B[i] - A[i]) * t for i in range(3)])


def dark(c, t):
	return mix(c, "#000000", t)


def light(c, t):
	return mix(c, "#ffffff", t)


def smooth(points, closed=True, t=1.0):
	"""Catmull-Rom spline through points -> SVG path data."""
	n = len(points)
	if n < 3:
		return "M" + " L".join("%s %s" % (fm(float(x)), fm(float(y))) for x, y in points)
	P = [(float(x), float(y)) for x, y in points]
	d = "M%s %s" % (fm(P[0][0]), fm(P[0][1]))
	rng = range(n) if closed else range(n - 1)
	for i in rng:
		p0 = P[i - 1] if (closed or i > 0) else P[0]
		p1 = P[i]
		p2 = P[(i + 1) % n]
		p3 = P[(i + 2) % n] if (closed or i + 2 < n) else P[-1]
		c1 = (p1[0] + (p2[0] - p0[0]) / 6 * t, p1[1] + (p2[1] - p0[1]) / 6 * t)
		c2 = (p2[0] - (p3[0] - p1[0]) / 6 * t, p2[1] - (p3[1] - p1[1]) / 6 * t)
		d += " C%s %s %s %s %s %s" % tuple(fm(v) for v in (c1[0], c1[1], c2[0], c2[1], p2[0], p2[1]))
	if closed:
		d += " Z"
	return d


def blob_pts(cx, cy, rx, ry, rng, n=9, jitter=0.12, rot=0.0):
	out = []
	for i in range(n):
		a = rot + i / n * math.tau
		k = 1.0 + rng.uniform(-jitter, jitter)
		out.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
	return out


class Doc:
	def __init__(self, w=W, h=H):
		self.w, self.h = w, h
		self.defs = []
		self.parts = []
		self._n = 0

	def uid(self, p="d"):
		self._n += 1
		return "%s%d" % (p, self._n)

	def add(self, s):
		self.parts.append(s)

	# ---- paint servers
	@staticmethod
	def _stops(stops):
		out = []
		for s in stops:
			o, c = s[0], s[1]
			a = s[2] if len(s) > 2 else 1.0
			out.append('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (fm(float(o)), c, fm(float(a)) if a not in (0, 1) else str(a)))
		return "".join(out)

	def lin(self, x1, y1, x2, y2, stops):
		i = self.uid("l")
		self.defs.append('<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>'
			% (i, fm(x1), fm(y1), fm(x2), fm(y2), self._stops(stops)))
		return "url(#%s)" % i

	def vlin(self, y1, y2, stops):
		return self.lin(0, y1, 0, y2, stops)

	def blin(self, stops, x1=0, y1=0, x2=0, y2=1):
		i = self.uid("b")
		self.defs.append('<linearGradient id="%s" x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>'
			% (i, x1, y1, x2, y2, self._stops(stops)))
		return "url(#%s)" % i

	def rad(self, cx, cy, r, stops, fx=None, fy=None):
		i = self.uid("r")
		extra = ""
		if fx is not None:
			extra = ' fx="%s" fy="%s"' % (fm(fx), fm(fy))
		self.defs.append('<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" r="%s"%s>%s</radialGradient>'
			% (i, fm(cx), fm(cy), fm(r), extra, self._stops(stops)))
		return "url(#%s)" % i

	def brad(self, stops, cx=0.5, cy=0.5, r=0.5):
		i = self.uid("q")
		self.defs.append('<radialGradient id="%s" cx="%s" cy="%s" r="%s">%s</radialGradient>' % (i, cx, cy, r, self._stops(stops)))
		return "url(#%s)" % i

	def clip(self, inner):
		i = self.uid("c")
		self.defs.append('<clipPath id="%s">%s</clipPath>' % (i, inner))
		return "url(#%s)" % i

	# ---- shapes
	def rect(self, x, y, w, h, fill, **kw):
		self.add('<rect %s/>' % _attrs(dict(x=x, y=y, width=w, height=h, fill=fill, **kw)))

	def circle(self, cx, cy, r, fill, **kw):
		self.add('<circle %s/>' % _attrs(dict(cx=cx, cy=cy, r=r, fill=fill, **kw)))

	def ellipse(self, cx, cy, rx, ry, fill, **kw):
		self.add('<ellipse %s/>' % _attrs(dict(cx=cx, cy=cy, rx=rx, ry=ry, fill=fill, **kw)))

	def poly(self, p, fill, **kw):
		self.add('<polygon %s/>' % _attrs(dict(points=pts(p), fill=fill, **kw)))

	def pline(self, p, stroke, sw=2, **kw):
		kw.setdefault("fill", "none")
		kw.setdefault("stroke_linecap", "round")
		kw.setdefault("stroke_linejoin", "round")
		self.add('<polyline %s/>' % _attrs(dict(points=pts(p), stroke=stroke, stroke_width=sw, **kw)))

	def path(self, d, fill, **kw):
		self.add('<path %s/>' % _attrs(dict(d=d, fill=fill, **kw)))

	def spath(self, d, stroke, sw=2, **kw):
		kw.setdefault("fill", "none")
		kw.setdefault("stroke_linecap", "round")
		kw.setdefault("stroke_linejoin", "round")
		self.add('<path %s/>' % _attrs(dict(d=d, stroke=stroke, stroke_width=sw, **kw)))

	def line(self, x1, y1, x2, y2, stroke, sw=2, **kw):
		kw.setdefault("stroke_linecap", "round")
		self.add('<line %s/>' % _attrs(dict(x1=x1, y1=y1, x2=x2, y2=y2, stroke=stroke, stroke_width=sw, **kw)))

	def blob(self, p, fill, t=1.0, **kw):
		self.path(smooth(p, True, t), fill, **kw)

	def open(self, **kw):
		self.add("<g %s>" % _attrs(kw))

	def close(self):
		self.add("</g>")

	def svg(self):
		return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n<defs>%s</defs>\n%s\n</svg>\n'
			% (self.w, self.h, self.w, self.h, "\n".join(self.defs), "\n".join(self.parts)))


class G:
	"""with G(d, opacity=.5, transform='...'):"""

	def __init__(self, d, **kw):
		self.d, self.kw = d, kw

	def __enter__(self):
		self.d.open(**self.kw)
		return self.d

	def __exit__(self, *a):
		self.d.close()


def T(x, y, s=1.0, rot=0.0, sx=None):
	t = "translate(%s %s)" % (fm(float(x)), fm(float(y)))
	if rot:
		t += " rotate(%s)" % fm(float(rot))
	if sx is not None:
		t += " scale(%s %s)" % (fm(float(sx)), fm(float(s)))
	elif s != 1.0:
		t += " scale(%s)" % fm(float(s))
	return t


# --------------------------------------------------------------------------------------
# palette
# --------------------------------------------------------------------------------------
INK = "#2a1a10"
LANTERN = "#ffcf7a"
LANTERN_HOT = "#fff1c9"
YUZU = "#ffc93c"
YUZU_D = "#e89a1c"
TEAL = "#2bb7b3"
AQUA = "#6fe3dc"
STEEL = "#5d6b7c"
CROC_G = "#4f8f52"
CROC_GD = "#2f5e37"
CHROME = "#c3ccd6"
CHROME_D = "#7d8a99"
GOLD = "#e7b347"
GOLD_D = "#a8741e"
RED_EYE = "#ff3b3b"


# --------------------------------------------------------------------------------------
# reusable motifs
# --------------------------------------------------------------------------------------

def glow(d, cx, cy, r, color, a=0.6, ry=None):
	g = d.brad([(0, color, a), (0.45, color, a * 0.4), (1, color, 0)])
	if ry is None:
		d.circle(cx, cy, r, g)
	else:
		d.ellipse(cx, cy, r, ry, g)


def vignette(d, a=0.45, color="#0a0614", inner=0.55):
	g = d.rad(W / 2, H * 0.46, 820, [(0, color, 0), (inner, color, 0), (1, color, a)])
	d.rect(0, 0, W, H, g)


def light_wash(d, color, a, y0=0, y1=H):
	d.rect(0, y0, W, y1 - y0, d.vlin(y0, y1, [(0, color, a), (1, color, 0)]))


def sparkle(d, x, y, r, color="#ffffff", a=1.0, glow_c=None):
	if glow_c:
		glow(d, x, y, r * 2.2, glow_c, 0.55 * a)
	s = r * 0.22
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(float(v)) for v in (
		x, y - r, x + s, y - s, x + r, y, x + s, y + s, x, y + r, x - s, y + s, x - r, y, x - s, y - s, x, y - r)),
		color, opacity=a)


GLYPH_STROKES = [
	((0.12, 0.2), (0.88, 0.2)), ((0.15, 0.5), (0.85, 0.5)), ((0.05, 0.86), (0.95, 0.86)),
	((0.5, 0.04), (0.5, 0.96)), ((0.25, 0.22), (0.25, 0.86)), ((0.75, 0.2), (0.75, 0.9), (0.6, 0.8)),
	((0.5, 0.45), (0.1, 0.95)), ((0.5, 0.45), (0.92, 0.95)), ((0.2, 0.2), (0.8, 0.2), (0.8, 0.72), (0.2, 0.72), (0.2, 0.2)),
	((0.42, 0.04), (0.56, 0.16)), ((0.1, 0.35), (0.45, 0.35), (0.3, 0.7)), ((0.6, 0.3), (0.9, 0.3), (0.9, 0.65)),
]


def glyphs(d, x, y, w, h, rows, color, rng, sw=2.2, a=1.0, center=False):
	"""Abstract pseudo-kanji scribbles standing in for writing (no <text>)."""
	dd = ""
	lh = h / max(1, rows)
	g = lh * 0.78
	for r in range(rows):
		cy = y + lh * r + (lh - g) / 2
		lw = w * (rng.uniform(0.5, 1.0) if r == rows - 1 and rows > 1 else 1.0)
		n = max(1, int((lw + g * 0.25) / (g * 1.22)))
		used = n * g * 1.22 - g * 0.22
		x0 = x + ((w - used) / 2 if center else 0)
		for k in range(n):
			gx = x0 + k * g * 1.22
			picks = rng.sample(range(len(GLYPH_STROKES)), rng.randint(2, 4))
			for pi in picks:
				st = GLYPH_STROKES[pi]
				dd += "M" + " L".join("%s %s" % (fm(gx + px * g), fm(cy + py * g)) for px, py in st) + " "
	d.spath(dd, color, sw, opacity=a)


def snapjaw_crest(d, cx, cy, s=1.0, ring=True, a=1.0):
	"""Stylized crocodile head wearing a top hat, inside a round gold badge. Unit radius ~50."""
	with G(d, transform=T(cx, cy, s), opacity=a if a < 1 else None):
		if ring:
			d.circle(0, 4, 50, "#000000", opacity=0.25)
			d.circle(0, 0, 50, d.brad([(0, "#2f6b4c"), (1, "#14301f")]), stroke=GOLD, stroke_width=5)
			d.circle(0, 0, 43, "none", stroke=GOLD_D, stroke_width=1.6)
		# head (left green, right chrome)
		head = "M-27 -8 Q-31 -24 -15 -25 L15 -25 Q31 -24 27 -8 L13 30 Q11 39 0 39 Q-11 39 -13 30 Z"
		d.path(head, CROC_G, stroke=INK, stroke_width=2.5, stroke_linejoin="round")
		d.path("M0 -25 L15 -25 Q31 -24 27 -8 L13 30 Q11 39 0 39 Z", CHROME)
		d.path("M4 -22 L14 -22 Q24 -20 23 -9 L18 4 Z", "#ffffff", opacity=0.45)
		d.path("M-20 -18 L-8 -18 L-12 -8 Z", CROC_GD, opacity=0.6)
		d.path(head, "none", stroke=INK, stroke_width=2.5, stroke_linejoin="round")
		d.line(0, -25, 0, 39, CHROME_D, 1.2)
		# teeth
		dd = ""
		for side in (-1, 1):
			for k in range(5):
				y0 = -4 + k * 6.5
				xo = side * (25.5 - k * 2.6)
				dd += "M%s %s L%s %s L%s %s Z " % (fm(xo), fm(y0), fm(xo + side * 4.5), fm(y0 + 3.2), fm(xo - side * 0.8), fm(y0 + 5.8))
		d.path(dd, "#fffbe8", stroke=INK, stroke_width=1)
		# eyes
		d.ellipse(-13, -13, 6.5, 5.5, "#f4e04d", stroke=INK, stroke_width=1.6)
		d.ellipse(-13, -13, 1.6, 4.4, INK)
		glow(d, 13, -13, 11, RED_EYE, 0.7)
		d.circle(13, -13, 5.5, RED_EYE, stroke=INK, stroke_width=1.6)
		d.circle(12, -14.5, 1.6, "#ffd0d0")
		d.circle(13, -13, 8.5, "none", stroke=GOLD, stroke_width=2)
		d.spath("M20 -8 Q24 4 19 14", GOLD, 1.2)
		# nostrils
		d.ellipse(-4.5, 32, 2, 1.4, INK)
		d.ellipse(4.5, 32, 2, 1.4, INK)
		# top hat
		d.ellipse(0, -26, 29, 6, "#151018", stroke=INK, stroke_width=2)
		d.path("M-17 -27 L-15 -58 Q0 -62 15 -58 L17 -27 Z", "#1f1a26", stroke=INK, stroke_width=2, stroke_linejoin="round")
		d.path("M-16.5 -36 L16.5 -36 L16.8 -29 L-16.8 -29 Z", "#8e2b4a")
		d.path("M-11 -55 L-8 -38 L-5 -38 L-7 -56 Z", "#ffffff", opacity=0.18)


def croc_cam(d, x, y, s=1.0, flip=False, lit=True):
	"""Wall security camera shaped like a caiman head. (x,y)=wall mount point; points right (left if flip)."""
	with G(d, transform=T(x, y, s, sx=(-s if flip else s))):
		d.rect(-6, -14, 10, 28, "#30343d", rx=2)
		d.path("M2 -4 L18 -2 L18 4 L2 6 Z", "#3d434e")
		# body / snout
		body = "M14 -12 Q30 -20 44 -14 L84 -6 Q92 -4 90 2 Q88 7 80 7 L40 10 Q20 12 14 4 Z"
		d.path(body, CROC_G, stroke=INK, stroke_width=2.2, stroke_linejoin="round")
		d.path("M40 -15 L84 -6 Q92 -4 90 1 L44 -2 Z", CHROME, opacity=0.9)
		d.path("M20 -10 Q30 -16 40 -13 L36 -6 Z", "#ffffff", opacity=0.25)
		# teeth along jaw
		dd = ""
		for k in range(6):
			tx = 42 + k * 7
			dd += "M%s 7.6 L%s 12.5 L%s 7.2 Z " % (fm(tx), fm(tx + 2.5), fm(tx + 5))
		d.path(dd, "#fffbe8", stroke=INK, stroke_width=0.8)
		# eye-lens
		d.circle(30, -13, 7.5, "#22262e", stroke=INK, stroke_width=2)
		if lit:
			glow(d, 30, -13, 13, RED_EYE, 0.75)
		d.circle(30, -13, 4, RED_EYE if lit else "#7a2a2a")
		d.circle(28.5, -14.5, 1.3, "#ffe0e0")
		d.circle(84, -2, 1.4, INK)


def steel_shutter(d, x, y, w, h, rng, crest=True):
	d.rect(x - 8, y - 14, w + 16, 18, "#3b424d")
	d.rect(x - 8, y - 14, w + 16, 4, "#788596")
	d.rect(x, y, w, h, d.vlin(y, y + h, [(0, "#8794a5"), (0.5, "#6b7788"), (1, "#4d5767")]))
	dd = ""
	sl = 14
	k = y + sl
	while k < y + h - 22:
		dd += "M%s %s L%s %s " % (fm(x), fm(k), fm(x + w), fm(k))
		k += sl
	d.spath(dd, "#3d4654", 2.2, stroke_linecap="butt")
	dd = ""
	k = y + sl + 3
	while k < y + h - 22:
		dd += "M%s %s L%s %s " % (fm(x), fm(k), fm(x + w), fm(k))
		k += sl
	d.spath(dd, "#a7b3c2", 1.2, opacity=0.6, stroke_linecap="butt")
	# hazard stripe bottom
	hy = y + h - 22
	cid = d.clip('<rect x="%s" y="%s" width="%s" height="22"/>' % (fm(x), fm(hy), fm(w)))
	with G(d, clip_path=cid):
		d.rect(x, hy, w, 22, "#f2c230")
		dd = ""
		i = x - 30
		while i < x + w + 30:
			dd += "M%s %s L%s %s L%s %s L%s %s Z " % (fm(i), fm(hy + 22), fm(i + 14), fm(hy + 22), fm(i + 36), fm(hy), fm(i + 22), fm(hy))
			i += 30
		d.path(dd, "#1e1e22")
	# side rails + bolts
	d.rect(x - 10, y - 4, 10, h + 4, "#454c58")
	d.rect(x + w, y - 4, 10, h + 4, "#454c58")
	for by in (y + 20, y + h * 0.5, y + h - 30):
		d.circle(x - 5, by, 2.6, "#b9c3cf")
		d.circle(x + w + 5, by, 2.6, "#b9c3cf")
	# scratches (Coco tried to pry it)
	for _ in range(3):
		sx = x + rng.uniform(0.15, 0.85) * w
		sy = y + rng.uniform(0.35, 0.8) * h
		d.line(sx, sy, sx + rng.uniform(-30, 30), sy + rng.uniform(4, 16), "#c9d3de", 1.2, opacity=0.6)
	if crest:
		snapjaw_crest(d, x + w / 2, y + h * 0.4, min(w, h) / 260)


def chochin(d, cx, cy, s=1.0, color="#e8553d", lit=True, glow_a=0.55, rng=None):
	"""Hanging paper lantern."""
	if lit:
		glow(d, cx, cy, 120 * s, LANTERN, glow_a)
	d.line(cx, cy - 64 * s, cx, cy - 400, "#1a1010", 2 * s)
	body = d.rad(cx - 10 * s, cy - 12 * s, 44 * s, [(0, light(color, 0.55) if lit else color), (0.6, color), (1, dark(color, 0.35))])
	d.ellipse(cx, cy, 34 * s, 46 * s, body)
	dd = ""
	for k in range(-3, 4):
		yy = cy + k * 11 * s
		hw = 34 * s * math.sqrt(max(0.0, 1 - (k * 11 / 46) ** 2))
		dd += "M%s %s Q%s %s %s %s " % (fm(cx - hw), fm(yy), fm(cx), fm(yy + 4 * s), fm(cx + hw), fm(yy))
	d.spath(dd, dark(color, 0.45), 1.2 * s, opacity=0.6)
	d.rect(cx - 16 * s, cy - 52 * s, 32 * s, 9 * s, "#22160f", rx=2 * s)
	d.rect(cx - 16 * s, cy + 43 * s, 32 * s, 9 * s, "#22160f", rx=2 * s)
	if lit:
		d.ellipse(cx - 8 * s, cy - 6 * s, 12 * s, 22 * s, LANTERN_HOT, opacity=0.35)


def stone_lantern(d, x, base, s=1.0, lit=True, stone="#8f939a", night=True):
	"""Kasuga-style stone lantern. x = center, base = ground y. ~180 tall at s=1."""
	sd = dark(stone, 0.3)
	sl = light(stone, 0.25)

	def Y(v):
		return base - v * s

	def X(v):
		return x + v * s
	d.ellipse(x, base, 52 * s, 9 * s, "#000000", opacity=0.25)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % (fm(X(-40)), fm(Y(0)), fm(X(40)), fm(Y(0)), fm(X(32)), fm(Y(16)), fm(X(-32)), fm(Y(16))), sd)
	d.rect(X(-30), Y(20), 60 * s, 5 * s, stone)
	d.rect(X(-11), Y(62), 22 * s, 42 * s, stone)
	d.rect(X(-11), Y(62), 7 * s, 42 * s, sl, opacity=0.5)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % (fm(X(-34)), fm(Y(62)), fm(X(34)), fm(Y(62)), fm(X(28)), fm(Y(74)), fm(X(-28)), fm(Y(74))), stone)
	# fire box
	d.rect(X(-24), Y(112), 48 * s, 38 * s, sd)
	if lit:
		glow(d, x, Y(93), 70 * s, LANTERN, 0.6)
		d.rect(X(-14), Y(106), 28 * s, 26 * s, LANTERN_HOT)
		d.rect(X(-14), Y(106), 28 * s, 26 * s, d.brad([(0, "#ffffff", 0.9), (1, LANTERN, 0.2)]))
	else:
		d.rect(X(-14), Y(106), 28 * s, 26 * s, "#3c3a3e")
	d.rect(X(-2), Y(106), 4 * s, 26 * s, sd)
	# roof
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % tuple(fm(v) for v in (
		X(-50), Y(110), X(-30), Y(116), X(-16), Y(140), X(16), Y(140), X(30), Y(116), X(50), Y(110),
		X(46), Y(118), X(0), Y(122), X(-46), Y(118))), stone)
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % tuple(fm(v) for v in (
		X(-50), Y(110), X(-30), Y(116), X(-16), Y(140), X(0), Y(140), X(0), Y(122), X(-46), Y(118))), sl, opacity=0.35)
	d.ellipse(x, Y(146), 9 * s, 7 * s, stone)
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(v) for v in (
		X(-7), Y(150), X(-7), Y(166), X(0), Y(172), X(7), Y(166), X(7), Y(150))), stone)


def yuzu(d, x, y, r, rot=0, leaf=True, a=1.0, water=False):
	with G(d, transform=T(x, y, 1, rot), opacity=a if a < 1 else None):
		if water:
			d.ellipse(0, r * 0.55, r * 1.35, r * 0.45, "#ffffff", opacity=0.18)
		d.circle(0, 0, r, d.brad([(0, "#fff08a"), (0.55, YUZU), (1, YUZU_D)], cx=0.38, cy=0.35, r=0.7))
		d.circle(-r * 0.32, -r * 0.35, r * 0.22, "#ffffff", opacity=0.55)
		if leaf and r > 5:
			d.path("M0 %s Q%s %s %s %s Q%s %s 0 %s Z" % (fm(-r * 0.9), fm(r * 0.4), fm(-r * 1.6), fm(r * 1.1), fm(-r * 1.3), fm(r * 0.7), fm(-r * 0.7), fm(-r * 0.9)), "#5f9e3a")
		if water:
			d.path("M%s 0 Q0 %s %s 0 Q0 %s %s 0 Z" % (fm(-r), fm(r * 1.05), fm(r), fm(r * 0.7), fm(-r)), "#3a8f8a", opacity=0.35)


def steam(d, rng, x0, y0, x1, y1, n, a=0.18, rmin=40, rmax=110, color="#ffffff"):
	g = d.brad([(0, color, a), (0.5, color, a * 0.55), (1, color, 0)])
	for _ in range(n):
		cx = rng.uniform(x0, x1)
		cy = rng.uniform(y0, y1)
		r = rng.uniform(rmin, rmax)
		d.ellipse(cx, cy, r * rng.uniform(1.2, 1.9), r, g)


def steam_wisps(d, rng, x0, y0, x1, y1, n, a=0.12, color="#ffffff", sw=(26, 48)):
	g = d.brad([(0, color, a), (0.6, color, a * 0.45), (1, color, 0)])
	for _ in range(n):
		x = rng.uniform(x0, x1)
		y = rng.uniform(y0, y1)
		h = rng.uniform(90, 170)
		amp = rng.uniform(10, 22)
		ph = rng.uniform(0, math.tau)
		r0 = rng.uniform(*sw) * 0.55
		for k in range(6):
			t = k / 5
			cx = x + math.sin(ph + t * 3.2) * amp
			cy = y - h * t
			r = r0 * (1 + t * 0.9)
			d.ellipse(cx, cy, r * 1.25, r, g)


def rock(d, cx, cy, rx, ry, rng, color="#6c6f7a", top_light=0.22, a=None, n=9, jitter=0.1):
	p = blob_pts(cx, cy, rx, ry, rng, n, jitter)
	d.blob(p, d.lin(cx, cy - ry, cx, cy + ry, [(0, light(color, top_light)), (0.55, color), (1, dark(color, 0.35))]), opacity=a)
	# top highlight
	hp = [(cx - rx * 0.6, cy - ry * 0.45), (cx - rx * 0.1, cy - ry * 0.85), (cx + rx * 0.5, cy - ry * 0.55), (cx + rx * 0.1, cy - ry * 0.35)]
	d.blob(hp, light(color, 0.35), opacity=0.35)


def cushion(d, x, y, w, h, color="#8fd8cf", rng=None, tag=True):
	"""Thick foam safety cushion slab, top surface at y..y+h."""
	edge = dark(color, 0.22)
	d.path("M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z" % tuple(fm(v) for v in (
		x + 6, y + h * 0.45, x - 4, y + h + 6, x + w * 0.1, y + h + 10, x + w * 0.9, y + h + 10, x + w + 4, y + h + 6, x + w - 6, y + h * 0.45)), edge)
	d.rect(x, y, w, h, d.vlin(y, y + h, [(0, light(color, 0.45)), (0.7, color), (1, dark(color, 0.08))]), rx=h * 0.45)
	d.rect(x + 8, y + 4, w - 16, h * 0.28, "#ffffff", rx=h * 0.14, opacity=0.4)
	d.spath("M%s %s L%s %s" % (fm(x + 10), fm(y + h - 6), fm(x + w - 10), fm(y + h - 6)), dark(color, 0.3), 1.4, stroke_dasharray="5 4", opacity=0.7)
	if tag and rng is not None:
		tx = x + w * rng.uniform(0.55, 0.7)
		d.rect(tx, y + h * 0.35, 22, 12, "#fffdf2", rx=2, stroke=dark(color, 0.35), stroke_width=1)
		d.spath("M%s %s l4 -3 l4 3 l4 -3 l4 3" % (fm(tx + 3), fm(y + h * 0.35 + 7)), "#c0392b", 1.2)


def plank_floor(d, y0, y1, vx, c_top, c_bot, n=18, line_c=None, spread=2.2, a=0.55, cross=True):
	"""Perspective wooden floor converging to vanishing x at y0."""
	d.rect(0, y0, W, y1 - y0, d.vlin(y0, y1, [(0, c_top), (1, c_bot)]))
	lc = line_c or dark(c_bot, 0.35)
	dd = ""
	for i in range(n + 1):
		xb = -W * (spread - 1) / 2 + i * W * spread / n
		xt = vx + (xb - vx) * 0.32
		dd += "M%s %s L%s %s " % (fm(xt), fm(y0), fm(xb), fm(y1))
	d.spath(dd, lc, 1.6, opacity=a, stroke_linecap="butt")
	if cross:
		dd = ""
		k = 0
		yy = y0
		gap = 10.0
		while yy < y1:
			yy += gap
			gap *= 1.35
			off = (k % 2) * 0.5
			for i in range(n):
				t = (yy - y0) / (y1 - y0)
				xb0 = -W * (spread - 1) / 2 + (i + off) * W * spread / n
				xs = vx + (xb0 - vx) * (0.32 + 0.68 * t)
				ww = W * spread / n * (0.32 + 0.68 * t)
				if (i * 7 + k * 3) % 5 == 0:
					dd += "M%s %s L%s %s " % (fm(xs), fm(yy), fm(xs + ww * 0.0), fm(yy + gap * 0.0 + 0.1))
			k += 1
		d.rect(0, y0, W, 3, "#000000", opacity=0.25)


def shoji(d, x, y, w, h, paper="#f6e7c4", frame="#4a2c1c", glow_c=None, cols=3, rows=4, a=1.0):
	with G(d, opacity=a if a < 1 else None):
		d.rect(x, y, w, h, frame)
		if glow_c:
			d.rect(x + 5, y + 5, w - 10, h - 10, d.vlin(y, y + h, [(0, light(paper, 0.3)), (1, paper)]))
			d.rect(x + 5, y + 5, w - 10, h - 10, d.brad([(0, glow_c, 0.6), (1, glow_c, 0)]))
		else:
			d.rect(x + 5, y + 5, w - 10, h - 10, paper)
		dd = ""
		for c in range(1, cols):
			xx = x + w * c / cols
			dd += "M%s %s L%s %s " % (fm(xx), fm(y + 5), fm(xx), fm(y + h - 5))
		for r in range(1, rows):
			yy = y + h * r / rows
			dd += "M%s %s L%s %s " % (fm(x + 5), fm(yy), fm(x + w - 5), fm(yy))
		d.spath(dd, frame, 2.4, stroke_linecap="butt")


def capy_soak(d, x, y, s=1.0, color="#1a1430", rim=None, yuzu_top=False, face=1, acc=None):
	"""Capybara silhouette soaking: big boxy head + back above the water line at y. face=1 looks right.
	acc: None | 'captain' | 'tophat' | 'bow' | 'headband'."""
	body = [(-66, 2), (-62, -20), (-44, -36), (-14, -44), (10, -44), (22, -58), (36, -78), (62, -88), (96, -84),
		(116, -70), (124, -44), (118, -22), (104, -10), (96, 2), (0, 4)]
	shape = smooth(body)

	def accessory(c):
		if acc == "captain":
			d.path("M34 -82 Q36 -102 62 -104 Q86 -102 86 -84 Z", c)
			d.path("M70 -86 Q92 -88 102 -80 Q90 -78 70 -80 Z", c)
		elif acc == "tophat":
			d.ellipse(60, -86, 30, 6, c)
			d.path("M44 -88 L46 -128 L74 -128 L76 -88 Z", c)
		elif acc == "bow":
			d.path("M62 -94 Q44 -122 32 -110 Q28 -92 62 -94 Z M62 -94 Q82 -124 96 -112 Q100 -92 62 -94 Z", c)
			d.path("M60 -92 L50 -76 L58 -78 Z M64 -92 L76 -78 L68 -78 Z", c)
			d.circle(62, -94, 8, c)
		elif acc == "headband":
			d.spath("M30 -70 Q14 -66 2 -54 M30 -66 Q18 -58 8 -44", c, 5)
	with G(d, transform=T(x, y, s, sx=s * face)):
		if rim:
			d.path(shape, rim, opacity=0.9)
			d.ellipse(42, -84, 9, 8, rim, opacity=0.9)
			accessory(rim)
		with G(d, transform="translate(%s 2.5)" % fm(-2.5 * face)):
			d.path(shape, color)
			d.ellipse(42, -84, 9, 8, color)
			accessory(color)
		d.circle(82, -72, 2.8, rim or "#ffffff", opacity=0.85)
		d.ellipse(116, -46, 2.4, 3.2, rim or "#ffffff", opacity=0.35)
		if acc == "headband":
			d.spath("M34 -72 Q64 -80 96 -72", "#d8332c", 4, opacity=0.9)
		if yuzu_top:
			glow(d, 58, -100, 26, YUZU, 0.4)
			d.circle(58, -100, 12, d.brad([(0, "#fff08a"), (1, YUZU_D)], cx=0.38, cy=0.35, r=0.7))
			d.path("M58 -111 Q64 -122 74 -118 Q66 -110 58 -111 Z", "#5f9e3a")


def capy_stand(d, x, y, s=1.0, color="#1a1430", face=1):
	"""Standing capybara silhouette (side view), feet at y."""
	with G(d, transform=T(x, y, s, sx=s * face)):
		body = ("M-60 -10 Q-70 -40 -58 -66 Q-40 -92 0 -94 Q34 -96 52 -86 L62 -104 Q76 -122 96 -118 "
			"Q112 -114 116 -96 Q118 -84 114 -76 Q110 -64 98 -62 L80 -58 Q76 -40 66 -26 L64 0 L52 0 L50 -20 "
			"L-30 -20 L-34 0 L-46 0 L-48 -14 Z")
		d.path(body, color)
		d.ellipse(68, -114, 7, 6, color)
		d.ellipse(82, -120, 6, 5, color)


def potted_plant(d, x, base, s=1.0, pot="#7a4a32", leaf="#3f7a46", rng=None):
	d.ellipse(x, base, 34 * s, 7 * s, "#000000", opacity=0.25)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(v) for v in (
		x - 26 * s, base - 46 * s, x + 26 * s, base - 46 * s, x + 20 * s, base, x - 20 * s, base)), pot)
	d.rect(x - 30 * s, base - 52 * s, 60 * s, 10 * s, dark(pot, 0.15), rx=3 * s)
	r = rng or random.Random(3)
	for k in range(9):
		a = -math.pi / 2 + (k - 4) * 0.33
		ln = (70 + r.uniform(-12, 18)) * s
		ex, ey = x + math.cos(a) * ln, base - 50 * s + math.sin(a) * ln
		mx, my = x + math.cos(a) * ln * 0.5, base - 50 * s + math.sin(a) * ln * 0.5
		nx, ny = -math.sin(a) * 12 * s, math.cos(a) * 12 * s
		d.path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % tuple(fm(v) for v in (
			x, base - 50 * s, mx + nx, my + ny, ex, ey, mx - nx, my - ny, x, base - 50 * s)), leaf if k % 2 else light(leaf, 0.15))


def wall_sconce(d, x, y, s=1.0, lit=True):
	if lit:
		glow(d, x, y, 110 * s, LANTERN, 0.5)
	d.rect(x - 4 * s, y + 22 * s, 8 * s, 12 * s, "#3a2616")
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(v) for v in (
		x - 16 * s, y - 26 * s, x + 16 * s, y - 26 * s, x + 12 * s, y + 24 * s, x - 12 * s, y + 24 * s)),
		d.vlin(y - 26 * s, y + 24 * s, [(0, LANTERN_HOT if lit else "#cfc0a0"), (1, LANTERN if lit else "#9a8a70")]))
	d.rect(x - 18 * s, y - 30 * s, 36 * s, 6 * s, "#3a2616", rx=2 * s)
	d.rect(x - 14 * s, y + 22 * s, 28 * s, 5 * s, "#3a2616", rx=2 * s)
	dd = "M%s %s L%s %s M%s %s L%s %s" % tuple(fm(v) for v in (x - 5 * s, y - 24 * s, x - 4 * s, y + 22 * s, x + 5 * s, y - 24 * s, x + 4 * s, y + 22 * s))
	d.spath(dd, "#3a2616", 1.5 * s, opacity=0.6)


def chandelier(d, x, y, s=1.0, lit=True):
	if lit:
		glow(d, x, y + 20 * s, 190 * s, LANTERN, 0.45)
	d.line(x, y - 300, x, y - 20 * s, "#2a1d14", 3 * s)
	d.ellipse(x, y, 70 * s, 14 * s, "none", stroke=GOLD, stroke_width=4 * s)
	d.ellipse(x, y + 24 * s, 46 * s, 10 * s, "none", stroke=GOLD_D, stroke_width=3 * s)
	d.path("M%s %s L%s %s L%s %s Z" % tuple(fm(v) for v in (x - 14 * s, y - 20 * s, x + 14 * s, y - 20 * s, x, y + 40 * s)), GOLD_D)
	for k in range(7):
		a = k / 7 * math.tau
		cx = x + math.cos(a) * 70 * s
		cy = y + math.sin(a) * 14 * s
		d.rect(cx - 3 * s, cy - 16 * s, 6 * s, 16 * s, "#fff4dc")
		d.ellipse(cx, cy - 20 * s, 4 * s, 6 * s, LANTERN_HOT)
		if lit:
			glow(d, cx, cy - 20 * s, 16 * s, LANTERN, 0.8)
	for k in range(9):
		cx = x - 40 * s + k * 10 * s
		d.line(cx, y + 20 * s, cx, y + (40 + (k % 3) * 8) * s, "#fff6e0", 1.3 * s, opacity=0.8)
		d.circle(cx, y + (42 + (k % 3) * 8) * s, 2.2 * s, "#ffffff", opacity=0.85)


# --------------------------------------------------------------------------------------
# BACKGROUNDS
# --------------------------------------------------------------------------------------

POOL = [(210, 360), (300, 312), (450, 292), (640, 284), (830, 290), (990, 306), (1075, 345), (1090, 410),
	(1040, 475), (930, 528), (760, 552), (560, 552), (400, 535), (275, 490), (205, 425)]


def bamboo_fence(d, y0, y1, base_c, line_c, rng, x0=0, x1=W, posts=True, lit=None):
	d.rect(x0, y0, x1 - x0, y1 - y0, d.vlin(y0, y1, [(0, light(base_c, 0.12)), (1, dark(base_c, 0.2))]))
	dd = ""
	x = x0
	while x < x1:
		x += rng.uniform(13, 17)
		dd += "M%s %s L%s %s " % (fm(x), fm(y0 + rng.uniform(-2, 3)), fm(x), fm(y1))
	d.spath(dd, line_c, 2.2, opacity=0.75, stroke_linecap="butt")
	# top cut edge (slanted bamboo tops)
	d.rect(x0, y0 - 3, x1 - x0, 6, light(base_c, 0.25), opacity=0.6)
	# nodes
	dd = ""
	x = x0 + 7
	while x < x1:
		for k in range(3):
			yy = y0 + (y1 - y0) * (0.22 + 0.3 * k) + rng.uniform(-6, 6)
			dd += "M%s %s L%s %s " % (fm(x - 5), fm(yy), fm(x + 5), fm(yy))
		x += 15
	d.spath(dd, light(base_c, 0.3), 1.6, opacity=0.5)
	# binding rails
	for t in (0.3, 0.72):
		yy = y0 + (y1 - y0) * t
		d.rect(x0, yy - 5, x1 - x0, 10, dark(base_c, 0.45))
		d.rect(x0, yy - 5, x1 - x0, 3, light(base_c, 0.1), opacity=0.5)
	if posts:
		x = x0 + 90
		while x < x1:
			d.rect(x - 9, y0 - 14, 18, y1 - y0 + 14, dark(base_c, 0.5))
			d.rect(x - 9, y0 - 14, 6, y1 - y0 + 14, light(base_c, 0.05), opacity=0.4)
			d.ellipse(x, y0 - 14, 9, 3, dark(base_c, 0.6))
			x += 230
	if lit:
		for (lx, la) in lit:
			glow(d, lx, (y0 + y1) / 2, 220, LANTERN, la, ry=110)


def bath_scene(d, morning=True, body=False):
	rng = random.Random(7 if morning else 8)
	if morning:
		sky = [(0, "#9db6dc"), (0.55, "#e2cfdc"), (1, "#f9e4cc")]
		mt1, mt2 = "#b9c0da", "#9aa7c6"
		tree, tree2 = "#6d8f8a", "#57787a"
		fence_c, fence_l = "#c9ae74", "#8d7140"
		rock_c = "#858a98"
		w_far, w_near = "#93d6cf", "#3e9ea0"
		deck1, deck2 = "#c4bdb6", "#a49d97"
		cush = "#cfeaf5"
	else:
		sky = [(0, "#070a24"), (0.6, "#1a2250"), (1, "#2d2c5c")]
		mt1, mt2 = "#1b2150", "#20265a"
		tree, tree2 = "#121834", "#0e1329"
		fence_c, fence_l = "#4b3d29", "#2a2116"
		rock_c = "#454a60"
		w_far, w_near = "#2f8d92", "#114a56"
		deck1, deck2 = "#34324a", "#242236"
		cush = "#7d9fbd"
	d.rect(0, 0, W, 320, d.vlin(0, 320, sky))
	if morning:
		glow(d, 1120, 40, 420, "#fff6e0", 0.75)
		glow(d, 1120, 40, 160, "#ffffff", 0.6)
	else:
		# stars
		dd = ""
		for _ in range(70):
			sx, sy = rng.uniform(0, W), rng.uniform(0, 210)
			dd += "M%s %s l0.1 0 " % (fm(sx), fm(sy))
		d.spath(dd, "#ffffff", 2.4, opacity=0.7)
		glow(d, 1065, 92, 260, "#9fb6ff", 0.35)
		d.circle(1065, 92, 44, d.brad([(0, "#fffbe8"), (1, "#f2e6c0")], cx=0.4, cy=0.4))
		d.circle(1050, 84, 8, "#e6d9b0", opacity=0.6)
		d.circle(1078, 104, 6, "#e6d9b0", opacity=0.5)
	# mountains
	d.path("M0 210 L120 150 L230 182 L380 120 L520 176 L640 150 L760 190 L900 128 L1040 170 L1180 136 L1280 160 L1280 320 L0 320 Z", mt1)
	d.path("M0 240 L160 196 L300 226 L470 188 L620 222 L780 196 L940 230 L1100 192 L1280 220 L1280 320 L0 320 Z", mt2)
	# trees behind fence
	for (cx, cy, rx, ry, c) in [(80, 170, 120, 90, tree2), (250, 200, 110, 60, tree), (1150, 180, 150, 90, tree2), (980, 205, 120, 55, tree),
			(560, 215, 90, 30, tree), (760, 212, 110, 34, tree2)]:
		d.blob(blob_pts(cx, cy, rx, ry, rng, 10, 0.12), c)
	# maple leaves accents
	if morning:
		for (cx, cy) in [(200, 175), (300, 190), (1010, 190), (1100, 160)]:
			d.blob(blob_pts(cx, cy, 40, 26, rng, 8, 0.2), "#d98a5a", opacity=0.55)
	bamboo_fence(d, 200, 312, fence_c, fence_l, rng, lit=None if morning else [(925, 0.35), (150, 0.25)])
	# sign on fence: SAFETY FIRST + crest
	d.rect(566, 214, 150, 50, "#000000", opacity=0.25, rx=4)
	d.rect(562, 208, 150, 50, "#f3e3c0" if morning else "#a99a7c", rx=4, stroke="#5b3a1e", stroke_width=3)
	snapjaw_crest(d, 586, 233, 0.2)
	glyphs(d, 604, 216, 98, 34, 2, "#b0302a", rng, 2.4)
	# croc camera on post
	croc_cam(d, 1240, 190, 0.85, flip=True, lit=True)
	# deck
	d.rect(0, 300, W, H - 300, d.vlin(300, H, [(0, deck1), (1, deck2)]))
	dd = ""
	for yy in (590, 640, 700):
		dd += "M0 %s L%s %s " % (fm(yy), fm(W), fm(yy))
	for i in range(-6, 16):
		xb = 640 + i * 150
		dd += "M%s 560 L%s 720 " % (fm(640 + (xb - 640) * 0.7), fm(xb))
	d.spath(dd, dark(deck2, 0.25), 2, opacity=0.35, stroke_linecap="butt")
	for _ in range(18):
		yy = rng.choice([(560, 590), (590, 640), (640, 700)])
		xx = rng.uniform(0, W)
		t0 = (yy[0] - 560) / 160.0
		t1 = (yy[1] - 560) / 160.0
		def X(xb, t):
			return 640 + (xb - 640) * (0.7 + 0.3 * t)
		i = math.floor((xx - 640) / 150.0)
		xa, xb2 = 640 + i * 150, 640 + (i + 1) * 150
		d.poly([(X(xa, t0), yy[0]), (X(xb2, t0), yy[0]), (X(xb2, t1), yy[1]), (X(xa, t1), yy[1])],
			light(deck2, 0.12) if rng.random() < 0.5 else dark(deck2, 0.1), opacity=0.5)
	if not morning:
		glow(d, 150, 610, 260, LANTERN, 0.22, ry=70)
		glow(d, 925, 340, 200, LANTERN, 0.18, ry=50)
	else:
		glow(d, 1000, 640, 380, "#fff4e0", 0.25, ry=90)
	# water
	wpath = smooth(POOL)
	d.path(wpath, d.vlin(284, 552, [(0, w_far), (1, w_near)]))
	wclip = d.clip('<path d="%s"/>' % wpath)
	with G(d, clip_path=wclip):
		# surface light bands
		for (cx, cy, rx, ry, a) in [(560, 320, 260, 8, 0.3), (760, 360, 300, 6, 0.22), (420, 400, 160, 5, 0.2), (880, 440, 200, 6, 0.2),
				(600, 500, 240, 5, 0.15), (300, 450, 90, 4, 0.18), (980, 380, 80, 4, 0.2)]:
			d.ellipse(cx, cy, rx, ry, "#ffffff", opacity=a * (1 if morning else 0.6))
		if morning:
			d.path(wpath, d.rad(1000, 250, 600, [(0, "#ffffff", 0.35), (1, "#ffffff", 0)]))
		else:
			d.ellipse(925, 380, 30, 90, d.brad([(0, LANTERN, 0.7), (1, LANTERN, 0)]))
			d.ellipse(1040, 390, 26, 80, d.brad([(0, "#dfe8ff", 0.45), (1, "#dfe8ff", 0)]))
			d.ellipse(160, 420, 40, 90, d.brad([(0, LANTERN, 0.4), (1, LANTERN, 0)]))
		# caustic ripples
		dd = ""
		for _ in range(16):
			cx, cy = rng.uniform(250, 1050), rng.uniform(300, 540)
			ww = rng.uniform(20, 60)
			dd += "M%s %s q%s %s %s 0 " % (fm(cx), fm(cy), fm(ww / 2), fm(-4), fm(ww))
		d.spath(dd, "#ffffff", 1.6, opacity=0.35 if morning else 0.2)
	d.path(wpath, "none", stroke=dark(w_near, 0.4), stroke_width=7, opacity=0.5)
	# back rocks along the rim
	for i in range(13):
		cx = 240 + i * 68 + rng.uniform(-10, 10)
		if 860 < cx < 990:
			continue
		cy = 300 + abs(cx - 640) * 0.035 + rng.uniform(-4, 4)
		rock(d, cx, cy, rng.uniform(38, 52), rng.uniform(15, 22), rng, rock_c)
	for i in range(7):
		cx = 250 + i * 135 + rng.uniform(-10, 10)
		if 850 < cx < 1000:
			continue
		cy = 296 + abs(cx - 640) * 0.04
		cushion(d, cx - 42, cy - 22, 84, 20, cush, rng, tag=(i == 2))
	rock(d, 925, 302, 62, 20, rng, rock_c)
	stone_lantern(d, 925, 298, 0.9, lit=not morning, stone="#a3a6ad" if morning else "#6f7184")
	# side rocks
	rock(d, 208, 445, 46, 66, rng, dark(rock_c, 0.1), 0.15)
	rock(d, 1088, 430, 44, 60, rng, dark(rock_c, 0.1), 0.15)
	cushion(d, 168, 380, 70, 22, cush, rng, tag=False)
	cushion(d, 1052, 372, 70, 22, cush, rng, tag=False)
	# floating yuzu
	clust = [(398, 318, 10), (427, 311, 9.5), (456, 324, 11), (419, 340, 11), (468, 344, 10), (392, 345, 9)]
	others = [(300, 400, 12), (350, 470, 13), (880, 350, 11), (965, 430, 13), (905, 490, 14), (642, 322, 10), (560, 348, 10),
		(1010, 380, 11), (262, 445, 12), (720, 330, 10)]
	if body:
		others += [(455, 505, 13), (835, 468, 12)]
	else:
		others += [(600, 430, 13), (700, 470, 13), (520, 480, 13), (790, 420, 12)]
	for (x, y, r) in clust + others:
		yuzu(d, x, y, r, rng.uniform(-40, 40), water=True)
	if body:
		coco_floating(d)
	# steam (mid)
	n = 9 if body else 14
	steam(d, rng, 220, 270, 1060, 420, n, 0.14 if morning else 0.2, 50, 110)
	steam_wisps(d, rng, 260, 340, 1040, 520, 8, 0.09 if morning else 0.12)
	# front rocks + cushions
	for (cx, cy, rx, ry) in [(395, 608, 100, 52), (530, 618, 84, 46), (640, 612, 60, 40), (775, 616, 104, 46), (885, 604, 74, 42)]:
		rock(d, cx, cy, rx, ry, rng, rock_c)
	cushion(d, 336, 552, 134, 42, cush, rng)
	cushion(d, 468, 566, 112, 40, cush, rng, tag=False)
	cushion(d, 594, 574, 94, 34, cush, rng, tag=False)
	cushion(d, 690, 566, 172, 42, cush, rng, tag=False)
	cushion(d, 852, 556, 92, 38, cush, rng, tag=False)
	if body:
		headband_on_edge(d)
	# eave top-left + hanging lantern
	d.path("M0 0 L520 0 L470 30 L0 66 Z", "#2a1a12")
	d.path("M0 54 L476 26 L470 34 L0 70 Z", "#5b3a22")
	dd = ""
	for i in range(14):
		x = i * 36
		dd += "M%s 0 L%s %s " % (fm(x), fm(x * 0.92), fm(64 - x * 0.07))
	d.spath(dd, "#4a3020", 2, opacity=0.6)
	chochin(d, 150, 140, 0.75, "#e05a3a", lit=not morning)
	# foreground steam + light
	steam(d, rng, 0, 520, W, 720, 6, 0.08 if morning else 0.12, 80, 160)
	if morning:
		for (x0, x1) in [(900, 1010), (1060, 1130)]:
			d.poly([(x0 + 240, 0), (x1 + 240, 0), (x1 - 300, H), (x0 - 300, H)], "#fffaf0", opacity=0.08)
		light_wash(d, "#fff3e0", 0.25, 0, 400)
		vignette(d, 0.25, "#2a2440")
	else:
		d.rect(0, 500, W, 220, d.vlin(500, H, [(0, "#0a0c24", 0), (1, "#0a0c24", 0.45)]))
		vignette(d, 0.55)


def coco_floating(d):
	"""Captain Coco floating face-down (cartoon, non-graphic). Fits rect [470,380,340,140]."""
	fur, fur_d, fur_l = "#a8552f", "#7a3920", "#c97245"
	navy = "#24306a"
	wt = "#2a6d70"
	# submerged silhouette + ripples
	d.ellipse(636, 474, 170, 30, "#1f5257", opacity=0.42)
	d.path("M520 470 Q560 500 600 500 L606 476 Z", "#1f5257", opacity=0.4)
	d.ellipse(636, 458, 190, 50, "none", stroke="#ffffff", stroke_width=2.2, opacity=0.45)
	d.ellipse(636, 462, 222, 60, "none", stroke="#ffffff", stroke_width=1.6, opacity=0.25)
	# far arm reaching forward beyond the head (striped sleeve + paw)
	d.path(smooth([(560, 424), (528, 408), (500, 404), (494, 414), (520, 422), (552, 436)]), "#f5f2ea", stroke=INK, stroke_width=2.2)
	d.spath("M540 414 L536 426 M526 410 L522 421", navy, 4, stroke_linecap="butt")
	d.ellipse(490, 410, 11, 7, fur, stroke=INK, stroke_width=2.2)
	# head (face down in the water) - big round back of head, ears up top
	head = smooth([(496, 462), (500, 438), (518, 420), (548, 414), (576, 424), (590, 446), (588, 464)])
	d.path(head, d.lin(540, 412, 540, 466, [(0, fur_l), (0.55, fur), (1, fur_d)]), stroke=INK, stroke_width=2.6)
	d.path("M520 424 Q540 416 562 418 Q544 424 530 432 Z", "#ffffff", opacity=0.3)
	for (ex, ey) in [(550, 416), (572, 421)]:
		d.ellipse(ex, ey - 3, 8, 7, fur, stroke=INK, stroke_width=2.2)
		d.ellipse(ex, ey - 2, 4, 3.5, fur_d)
	d.path("M496 456 Q540 470 590 456 L590 466 Q540 478 496 466 Z", wt, opacity=0.55)
	# body hump in striped shirt
	hump_pts = [(580, 462), (592, 432), (630, 412), (686, 404), (738, 414), (772, 438), (784, 462), (716, 472), (640, 474)]
	hump = smooth(hump_pts)
	d.path(hump, "#f7f4ec")
	hc = d.clip('<path d="%s"/>' % hump)
	with G(d, clip_path=hc):
		dd = ""
		for i in range(8):
			x = 598 + i * 18
			dd += "M%s 398 Q%s 438 %s 478 L%s 478 Q%s 438 %s 398 Z " % (fm(x), fm(x + 9), fm(x - 2), fm(x + 5), fm(x + 16), fm(x + 7))
		d.path(dd, navy)
		# fur rump below the shirt hem
		d.path("M746 398 Q738 440 752 480 L800 480 L800 398 Z", fur)
		d.path("M752 412 Q760 410 772 424 Q760 422 754 430 Z", fur_l, opacity=0.6)
		d.rect(570, 398, 230, 82, d.vlin(404, 474, [(0, "#ffffff", 0.3), (0.4, "#ffffff", 0), (1, "#0d2f40", 0.45)]))
	d.spath("M746 404 Q738 440 750 470", INK, 2)
	d.path(hump, "none", stroke=INK, stroke_width=2.8)
	# navy collar between head and shirt
	d.spath("M586 436 Q596 420 614 414", navy, 6)
	d.path("M578 462 Q680 480 786 460 L786 470 Q680 490 578 472 Z", wt, opacity=0.5)
	# near arm hanging toward us, hind foot
	d.path(smooth([(630, 456), (622, 476), (612, 488), (600, 490), (602, 478), (614, 460)]), fur, stroke=INK, stroke_width=2.2)
	d.path("M612 458 L630 456 L626 470 L608 472 Z", "#f7f4ec", stroke=INK, stroke_width=2)
	d.spath("M616 459 L613 471 M624 457 L621 470", navy, 3.4, stroke_linecap="butt")
	d.ellipse(794, 466, 13, 6, fur, stroke=INK, stroke_width=2)
	# gold watch chain + cracked watch with a glint
	d.spath("M640 468 Q642 490 568 498", GOLD, 2.2)
	d.circle(560, 499, 10, GOLD, stroke=INK, stroke_width=2)
	d.circle(560, 499, 6.6, "#fbf6e6")
	d.rect(558.5, 487, 3, 3.5, GOLD, stroke=INK, stroke_width=1)
	d.spath("M556 494 L561 499 L558 504 M561 499 L565 495", "#7a6a50", 1.1)
	sparkle(d, 569, 490, 14, "#ffffff", 1.0, glow_c="#fff2b0")
	# white captain hat floating nearby (tilted)
	d.ellipse(786, 416, 38, 9, "#1d4f55", opacity=0.35)
	with G(d, transform=T(784, 404, 1, -10)):
		d.ellipse(0, 6, 25, 7, "#1b1b24", stroke=INK, stroke_width=2)
		d.path("M-28 2 Q-30 -14 0 -16 Q30 -14 28 2 Q0 10 -28 2 Z", "#fbfbf6", stroke=INK, stroke_width=2.2)
		d.path("M-24 -2 Q0 4 24 -2 L25 2 Q0 9 -25 2 Z", "#22305e")
		d.spath("M0 -10 L0 -2 M-4 -7 L4 -7 M-5 -4 Q0 1 5 -4", GOLD, 1.8)
		d.path("M-20 -9 Q-10 -14 4 -14 Q-8 -10 -16 -5 Z", "#ffffff", opacity=0.8)
	d.ellipse(784, 418, 42, 10, "none", stroke="#ffffff", stroke_width=1.6, opacity=0.35)


def headband_on_edge(d):
	"""Bruno's red headband lying on the cushioned front-right edge (rect [700,560,140,70])."""
	d.ellipse(766, 598, 50, 11, "#000000", opacity=0.2)
	# loop of cloth (back part darker, front part bright)
	d.spath("M722 588 Q726 570 760 569 Q794 570 800 584", "#8f1d1a", 12)
	d.spath("M722 588 Q726 571 760 570 Q794 571 800 584", "#c42a24", 8)
	d.spath("M720 586 Q730 604 762 604 Q792 603 802 590", "#8f1d1a", 14)
	d.spath("M720 586 Q730 602 762 602 Q792 601 802 589", "#e0382f", 10)
	d.spath("M732 598 Q760 606 790 596", "#ff9a88", 2.2, opacity=0.85)
	# knot + tails
	d.spath("M804 590 Q820 598 836 612", "#8f1d1a", 10)
	d.spath("M804 590 Q820 598 836 612", "#e0382f", 7)
	d.spath("M802 594 Q808 610 818 624", "#8f1d1a", 10)
	d.spath("M802 594 Q808 610 818 624", "#c42a24", 7)
	d.blob([(796, 584), (810, 584), (812, 596), (798, 598)], "#d8332c", stroke="#8f1d1a", stroke_width=2)



def room_shell(d, bx0, by0, bx1, by1, wall, wall2, ceil, floor1, floor2, side=None, vx=640, planks=18):
	"""One-point room: back wall rect + ceiling/side walls/floor trapezoids."""
	side = side or dark(wall2, 0.25)
	d.rect(0, 0, W, H, ceil)
	# ceiling
	d.poly([(0, 0), (W, 0), (bx1, by0), (bx0, by0)], d.vlin(0, by0, [(0, dark(ceil, 0.3)), (1, ceil)]))
	# side walls
	d.poly([(0, 0), (bx0, by0), (bx0, by1), (0, H + (H - by1) * 0.25)], d.lin(0, 0, bx0, 0, [(0, dark(side, 0.35)), (1, side)]))
	d.poly([(W, 0), (bx1, by0), (bx1, by1), (W, H + (H - by1) * 0.25)], d.lin(W, 0, bx1, 0, [(0, dark(side, 0.35)), (1, side)]))
	# back wall
	d.rect(bx0, by0, bx1 - bx0, by1 - by0, d.vlin(by0, by1, [(0, wall), (1, wall2)]))
	# floor
	fl = d.vlin(by1, H, [(0, floor1), (1, floor2)])
	d.poly([(bx0, by1), (bx1, by1), (W + 600, H), (-600, H)], fl)
	if planks:
		dd = ""
		for i in range(planks + 1):
			xt = bx0 + (bx1 - bx0) * i / planks
			xb = vx + (xt - vx) * (H - by1 + (by1 - 300)) / max(1, by1 - 300)
			dd += "M%s %s L%s %s " % (fm(xt), fm(by1), fm(xb), fm(H))
		d.spath(dd, dark(floor2, 0.35), 1.6, opacity=0.5, stroke_linecap="butt")
	d.rect(bx0, by1 - 4, bx1 - bx0, 8, dark(wall2, 0.5))


def floor_reflect(d, x, y, rx, ry, color=LANTERN, a=0.25):
	glow(d, x, y, rx, color, a, ry=ry)


def noren(d, x, y, w, h, color="#2b3f78", n=3, mark=None):
	gap = 4
	pw = (w - gap * (n - 1)) / n
	d.rect(x - 6, y - 8, w + 12, 8, "#3a2616", rx=3)
	for i in range(n):
		px = x + i * (pw + gap)
		d.path("M%s %s L%s %s L%s %s Q%s %s %s %s Z" % tuple(fm(v) for v in (
			px, y, px + pw, y, px + pw, y + h, px + pw / 2, y + h + 4, px, y + h)), d.vlin(y, y + h, [(0, light(color, 0.1)), (1, dark(color, 0.2))]))
	if mark:
		mark(x + w / 2, y + h * 0.5)


def sofa(d, x, y, w, h, color="#7a3b2e", rng=None):
	"""Low sofa, (x,y) top-left of the backrest."""
	cd = dark(color, 0.3)
	d.ellipse(x + w / 2, y + h + 4, w * 0.55, 10, "#000000", opacity=0.3)
	d.rect(x, y, w, h * 0.55, d.vlin(y, y + h * 0.55, [(0, light(color, 0.15)), (1, color)]), rx=14)
	d.rect(x + 8, y + h * 0.42, w - 16, h * 0.3, light(color, 0.08), rx=10)
	d.rect(x - 10, y + h * 0.3, 26, h * 0.7, cd, rx=10)
	d.rect(x + w - 16, y + h * 0.3, 26, h * 0.7, cd, rx=10)
	d.rect(x + 8, y + h * 0.68, w - 16, h * 0.32, dark(color, 0.15), rx=6)
	d.line(x + w / 2, y + h * 0.1, x + w / 2, y + h * 0.5, cd, 2)


def bg_lobby(d):
	rng = random.Random(11)
	bx0, by0, bx1, by1 = 120, 72, 1160, 470
	room_shell(d, bx0, by0, bx1, by1, "#e2b583", "#a8714a", "#3a2216", "#7a4428", "#3a1d14", side="#9a6440", planks=22)
	# ceiling coffers
	dd = ""
	for i in range(1, 12):
		xt = bx0 + (bx1 - bx0) * i / 12
		xb = 640 + (xt - 640) * 2.3
		dd += "M%s %s L%s 0 " % (fm(xt), fm(by0), fm(xb))
	d.spath(dd, "#24140c", 4, opacity=0.8)
	for yy in (18, 44):
		t = yy / by0
		d.line(bx0 * t, yy, W - (W - bx1) * t, yy, "#24140c", 4, opacity=0.8)
	# side wall shoji (perspective)
	for (sx, flip) in ((0, False), (W, True)):
		k = -1 if flip else 1
		x0 = sx + k * 20
		x1 = sx + k * 100
		def sy(x, top):
			t = abs(x - sx) / bx0
			return (by0 * t + 0 * (1 - t) + 30) if top else (by1 * t + (H + 60) * (1 - t) - 120)
		d.poly([(x0, sy(x0, True)), (x1, sy(x1, True)), (x1, sy(x1, False)), (x0, sy(x0, False))], "#f3dcae", opacity=0.45)
		dd = ""
		for j in range(1, 6):
			xa = x0 + (x1 - x0) * j / 6
			dd += "M%s %s L%s %s " % (fm(xa), fm(sy(xa, True)), fm(xa), fm(sy(xa, False)))
		d.spath(dd, "#5a3420", 3)
	# back wall panels
	for px in (bx0, 470, 790, bx1 - 30):
		d.rect(px, by0, 30, by1 - by0, d.lin(px, 0, px + 30, 0, [(0, "#3e2316"), (0.5, "#5c3522"), (1, "#2e190f")]))
	d.rect(bx0, by0, bx1 - bx0, 24, "#3a2014")
	d.rect(bx0, by0 + 20, bx1 - bx0, 4, GOLD_D, opacity=0.6)
	shoji(d, 160, 120, 300, 260, "#f6e2b8", "#4a2a1a", glow_c="#ffd790", cols=4, rows=4)
	d.rect(150, 380, 320, 90, "#4a2a1a")
	d.rect(150, 380, 320, 6, "#6e4128")
	# right: key cubbies + reception desk
	d.rect(830, 118, 280, 190, "#3d2316", rx=4)
	for r in range(3):
		for c in range(6):
			cx = 840 + c * 45
			cy = 128 + r * 58
			d.rect(cx, cy, 38, 50, "#5a3522")
			d.rect(cx + 3, cy + 3, 32, 44, "#2a160d")
			if (r * 6 + c) % 4 != 1:
				d.line(cx + 19, cy + 8, cx + 19, cy + 26, GOLD, 1.6)
				d.rect(cx + 13, cy + 26, 12, 16, "#c9b07a", rx=2)
	d.rect(815, 340, 320, 130, d.vlin(340, 470, [(0, "#6e3c24"), (1, "#4a2616")]))
	d.rect(805, 332, 340, 14, "#8a5030", rx=3)
	d.rect(805, 332, 340, 4, GOLD, opacity=0.7)
	d.rect(830, 360, 290, 90, "none", stroke=GOLD_D, stroke_width=2, opacity=0.7)
	snapjaw_crest(d, 975, 405, 0.36)
	d.ellipse(1080, 328, 14, 5, "#d8b35a")
	d.path("M1068 328 Q1080 306 1092 328 Z", GOLD)
	d.circle(1080, 306, 2.5, GOLD)
	# entrance with steel shutter
	d.rect(500, 96, 290, 82, "#2e190f")
	dd = ""
	for i in range(1, 12):
		dd += "M%s 100 L%s 174 " % (fm(500 + i * 24), fm(500 + i * 24))
	d.spath(dd, "#7a4a2c", 3)
	d.rect(500, 96, 290, 82, "none", stroke="#5c3522", stroke_width=6)
	d.rect(490, 178, 310, 16, "#5c3522")
	steel_shutter(d, 512, 196, 266, 274, rng, crest=False)
	d.rect(600, 300, 90, 40, "#f2c230", rx=4, stroke="#1e1e22", stroke_width=3)
	d.poly([(612, 334), (628, 306), (644, 334)], "none", stroke="#1e1e22", stroke_width=3)
	d.line(628, 316, 628, 325, "#1e1e22", 3)
	glyphs(d, 650, 308, 34, 24, 2, "#1e1e22", rng, 2)
	# big crest over the entrance (sinister)
	glow(d, 645, 137, 130, RED_EYE, 0.2)
	snapjaw_crest(d, 645, 140, 0.74)
	# cams
	croc_cam(d, bx0 + 34, 120, 0.8)
	croc_cam(d, bx1 - 34, 120, 0.8, flip=True)
	# sofa on the left (low) + side table
	sofa(d, 175, 405, 230, 70, "#7c3a2c")
	# plants by the entrance
	potted_plant(d, 462, 478, 0.9, rng=rng)
	potted_plant(d, 820, 478, 0.9, rng=rng)
	# floor: red carpet runner with gold border
	d.poly([(545, by1), (745, by1), (930, H), (360, H)], "#8c1f2a")
	d.poly([(545, by1), (745, by1), (930, H), (360, H)], "none", stroke=GOLD, stroke_width=5, stroke_linejoin="round")
	d.poly([(565, by1 + 6), (725, by1 + 6), (890, H), (400, H)], "none", stroke=GOLD_D, stroke_width=2, opacity=0.7)
	d.poly([(545, by1), (745, by1), (930, H), (360, H)], d.vlin(by1, H, [(0, "#000000", 0.35), (1, "#000000", 0)]))
	floor_reflect(d, 310, 520, 220, 40, LANTERN, 0.25)
	floor_reflect(d, 640, 500, 200, 30, "#ffb0a0", 0.15)
	floor_reflect(d, 975, 520, 220, 40, LANTERN, 0.22)
	# hanging lanterns
	chochin(d, 330, 165, 0.85, "#f4e9d2", lit=True, glow_a=0.45)
	chochin(d, 955, 165, 0.85, "#f4e9d2", lit=True, glow_a=0.45)
	light_wash(d, "#ffcf8a", 0.18, 0, 300)
	vignette(d, 0.5)


def pendant(d, x, y, s=1.0, color="#e8a64a", lit=True, cord_top=0):
	d.line(x, cord_top, x, y - 20 * s, "#1e140e", 2.2)
	if lit:
		glow(d, x, y + 10 * s, 150 * s, LANTERN, 0.45)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(v) for v in (x - 12 * s, y - 22 * s, x + 12 * s, y - 22 * s, x + 38 * s, y + 10 * s, x - 38 * s, y + 10 * s)),
		d.vlin(y - 22 * s, y + 10 * s, [(0, dark(color, 0.2)), (1, color)]))
	d.ellipse(x, y + 10 * s, 38 * s, 7 * s, LANTERN_HOT if lit else "#cfc4a0")


def bg_dining(d):
	rng = random.Random(21)
	room_shell(d, 0, 0, W, 400, "#d8a877", "#9c6440", "#2a1810", "#7a4630", "#3d2016", planks=24)
	# wainscot + beams
	d.rect(0, 0, W, 36, "#3a2014")
	d.rect(0, 330, W, 70, d.vlin(330, 400, [(0, "#5a3220"), (1, "#3d2016")]))
	d.rect(0, 326, W, 6, "#7a4a2c")
	for px in (60, 500, 780, 1220):
		d.rect(px - 14, 0, 28, 400, d.lin(px - 14, 0, px + 14, 0, [(0, "#3e2316"), (0.5, "#5c3522"), (1, "#2e190f")]))
	# shoji walls left + right
	shoji(d, 90, 70, 380, 250, "#f6e2b8", "#4a2a1a", glow_c="#ffd790", cols=5, rows=4)
	shoji(d, 960, 70, 240, 250, "#f6e2b8", "#4a2a1a", glow_c="#ffd790", cols=3, rows=4)
	# kitchen door (double swing doors w/ portholes) in frame
	d.rect(556, 128, 188, 272, "#3a2014")
	d.rect(566, 140, 168, 260, "#2a170e")
	glow(d, 650, 260, 130, LANTERN, 0.3)
	for (dx, w) in ((570, 78), (652, 78)):
		d.rect(dx, 156, w, 244, d.vlin(156, 400, [(0, "#9a5a34"), (1, "#6e3c22")]))
		d.rect(dx + 8, 290, w - 16, 96, "none", stroke="#5a3220", stroke_width=3)
		cx = dx + w / 2
		d.circle(cx, 215, 24, "#3e2516")
		d.circle(cx, 215, 19, d.brad([(0, LANTERN_HOT), (1, "#f0a850")]))
		d.path("M%s 205 Q%s 200 %s 212" % (fm(cx - 10), fm(cx), fm(cx + 6)), "none", stroke="#ffffff", stroke_width=2.5, opacity=0.7)
		d.rect(dx + (w - 14 if dx < 640 else 6), 250, 8, 26, GOLD_D, rx=3)
	noren(d, 566, 142, 168, 34, "#1f6f6b", 3)
	# menu board (chalkboard)
	d.line(870, 96, 832, 124, "#2a1a10", 2)
	d.line(870, 96, 908, 124, "#2a1a10", 2)
	d.circle(870, 96, 3, GOLD)
	d.rect(806, 124, 128, 168, "#6e4224", rx=6)
	d.rect(816, 134, 108, 148, d.vlin(134, 282, [(0, "#2e3d36"), (1, "#22302a")]))
	glyphs(d, 826, 146, 86, 18, 1, "#fff8e0", rng, 2.6, center=True)
	glyphs(d, 828, 176, 70, 70, 4, "#e8f0e8", rng, 1.6, a=0.85)
	for k in range(4):
		d.circle(910, 186 + k * 17.5, 3, YUZU if k % 2 == 0 else "#ff9a6a")
	yuzu(d, 840, 262, 8, 10, leaf=True)
	d.spath("M856 268 L912 268", "#e8f0e8", 1.6, opacity=0.6)
	# pendant lamps
	pendant(d, 420, 92, 1.0)
	pendant(d, 640, 80, 0.8)
	pendant(d, 1040, 92, 1.0)
	# far-side chairs
	for cx in (450, 530, 760, 840):
		d.rect(cx - 30, 368, 60, 66, "#5a2e1c", rx=8)
		d.rect(cx - 24, 374, 48, 20, "#8a3a2c", rx=6)
	# table (perspective) with cloth
	top = [(410, 432), (870, 432), (900, 560), (380, 560)]
	d.ellipse(640, 625, 300, 22, "#000000", opacity=0.3)
	d.poly([(380, 560), (900, 560), (904, 616), (376, 616)], d.vlin(560, 616, [(0, "#efe6d6"), (1, "#c9bba6")]))
	dd = ""
	for i in range(1, 14):
		x = 380 + i * 40
		dd += "M%s 562 Q%s 590 %s 616 " % (fm(x), fm(x + 3), fm(x))
	d.spath(dd, "#b8a890", 1.4, opacity=0.6)
	d.poly(top, d.vlin(432, 560, [(0, "#f6efe2"), (1, "#e6dccb")]))
	d.poly([(600, 432), (680, 432), (700, 560), (580, 560)], "#e8a43a")
	d.poly([(606, 432), (674, 432), (692, 560), (588, 560)], "none", stroke="#fff0c0", stroke_width=2, opacity=0.7)
	# place settings
	for (x, y, sc) in [(450, 452, 0.75), (540, 452, 0.75), (740, 452, 0.75), (830, 452, 0.75), (440, 525, 1.0), (545, 525, 1.0), (735, 525, 1.0), (840, 525, 1.0)]:
		d.ellipse(x, y, 30 * sc, 10 * sc, "#ffffff", stroke="#c9b9a0", stroke_width=1.5)
		d.ellipse(x, y - 2 * sc, 18 * sc, 6 * sc, "#e8d8b8")
		d.ellipse(x, y - 8 * sc, 13 * sc, 8 * sc, "#2b3f78")
		d.ellipse(x, y - 12 * sc, 11 * sc, 4 * sc, "#fbf8ef")
		d.line(x + 34 * sc, y - 6 * sc, x + 40 * sc, y + 10 * sc, "#7a4a2c", 2.2 * sc)
		d.line(x + 39 * sc, y - 6 * sc, x + 45 * sc, y + 10 * sc, "#7a4a2c", 2.2 * sc)
	# center platter of yuzu + teapot
	d.ellipse(640, 500, 62, 20, "#2b3f78", stroke="#1a2650", stroke_width=2)
	d.ellipse(640, 496, 52, 15, "#f6efe2")
	for (x, y, r) in [(616, 490, 11), (640, 486, 12), (664, 490, 11), (628, 498, 11), (654, 499, 11)]:
		yuzu(d, x, y, r, rng.uniform(-30, 30))
	d.ellipse(700, 462, 20, 16, "#3a6a5a")
	d.path("M716 456 Q732 446 736 438", "none", stroke="#3a6a5a", stroke_width=4)
	d.ellipse(700, 448, 9, 4, "#2a4a40")
	d.rect(592, 452, 16, 22, "#e8f0f4", rx=4, opacity=0.9)
	for (fx, fy, c) in [(596, 440, "#ff7a8a"), (606, 436, "#ffd04a"), (600, 430, "#ffffff")]:
		d.circle(fx, fy, 6, c)
	croc_cam(d, 74, 60, 0.8)
	floor_reflect(d, 640, 660, 360, 40, LANTERN, 0.12)
	light_wash(d, "#ffcf8a", 0.16, 0, 260)
	vignette(d, 0.45)


def bg_kitchen(d):
	rng = random.Random(31)
	# back wall tiles
	d.rect(0, 0, W, 500, d.vlin(0, 500, [(0, "#bcd6cf"), (1, "#8fb3ad")]))
	dd = ""
	for y in range(40, 380, 26):
		dd += "M0 %d L%d %d " % (y, W, y)
	for x in range(0, W, 26):
		dd += "M%d 40 L%d 380 " % (x, x)
	d.spath(dd, "#6f948e", 1.4, opacity=0.55, stroke_linecap="butt")
	d.rect(0, 0, W, 44, "#3a2a20")
	d.rect(0, 40, W, 5, "#5c4434")
	# window above the sink (night)
	d.rect(500, 104, 280, 210, "#4a3a2e", rx=4)
	d.rect(512, 116, 256, 186, d.vlin(116, 302, [(0, "#0d1436"), (1, "#2b3570")]))
	d.circle(712, 160, 22, "#fff4d6")
	glow(d, 712, 160, 70, "#a8c0ff", 0.35)
	dd = ""
	for _ in range(16):
		dd += "M%s %s l0.1 0 " % (fm(rng.uniform(520, 760)), fm(rng.uniform(122, 240)))
	d.spath(dd, "#ffffff", 2.2, opacity=0.7)
	d.path("M512 302 L512 262 Q560 236 610 256 Q660 230 720 252 Q750 244 768 252 L768 302 Z", "#0a0f28")
	d.rect(636, 116, 8, 186, "#4a3a2e")
	d.rect(512, 205, 256, 6, "#4a3a2e")
	d.rect(492, 308, 296, 14, "#5c4434", rx=3)
	for x in (540, 600):
		d.rect(x, 292, 22, 16, "#b0603a", rx=3)
		d.path("M%s 292 Q%s 276 %s 268 Q%s 278 %s 292 Z" % (fm(x + 4), fm(x + 2), fm(x + 11), fm(x + 20), fm(x + 18)), "#4f8f52")
	# range hood + stove (left)
	d.poly([(150, 60), (390, 60), (420, 150), (120, 150)], "#9aa3ab")
	d.poly([(150, 60), (390, 60), (420, 150), (120, 150)], d.lin(120, 0, 420, 0, [(0, "#ffffff", 0.0), (0.3, "#ffffff", 0.25), (1, "#000000", 0.15)]))
	d.rect(118, 148, 304, 10, "#6f787f")
	# pots on stove
	d.rect(170, 300, 110, 72, "#5f6a72", rx=6)
	d.rect(160, 296, 130, 12, "#7f8a92", rx=4)
	d.rect(300, 320, 80, 52, "#a2593a", rx=6)
	d.rect(292, 316, 96, 10, "#c06a44", rx=4)
	d.line(388, 330, 420, 326, "#3a2a20", 5)
	steam_wisps(d, rng, 180, 290, 280, 300, 3, 0.22)
	# hanging utensils rail
	d.line(140, 196, 420, 196, "#6a4a30", 5)
	for i, x in enumerate(range(160, 420, 40)):
		d.line(x, 196, x, 210, "#3a2a20", 2)
		if i % 3 == 0:
			d.line(x, 210, x, 262, "#6f787f", 4)
			d.ellipse(x, 270, 10, 12, "#6f787f")
		elif i % 3 == 1:
			d.line(x, 210, x, 258, "#8a5a34", 5)
			d.ellipse(x, 262, 7, 10, "#8a5a34")
		else:
			d.circle(x, 238, 22, "#4a4f55", stroke="#2a2a2a", stroke_width=2)
			d.circle(x, 238, 15, "#5d636a")
	# shelves right with jars/plates
	for (sy) in (150, 250):
		d.rect(860, sy, 300, 12, "#6a4a30")
		d.rect(860, sy + 12, 300, 6, "#000000", opacity=0.2)
	for i in range(6):
		x = 880 + i * 46
		c = ["#e8a43a", "#c0392b", "#4f8f52", "#f3e9d2", "#2b3f78", YUZU][i]
		d.rect(x, 108, 30, 42, "#dfeee8", opacity=0.7, rx=5)
		d.rect(x + 3, 120, 24, 28, c, rx=4)
		d.rect(x - 1, 102, 32, 8, "#8a5a34", rx=2)
	for i in range(5):
		x = 885 + i * 54
		d.ellipse(x + 18, 230, 26, 20, "#f6f1e6", stroke="#b8b0a0", stroke_width=1.5)
		d.ellipse(x + 18, 230, 14, 10, "none", stroke="#2b3f78", stroke_width=2)
	# counter
	d.rect(0, 372, W, 24, d.vlin(372, 396, [(0, "#d9d2c4"), (1, "#a9a294")]))
	d.rect(0, 396, W, 110, d.vlin(396, 506, [(0, "#6e4a32"), (1, "#4a2f20")]))
	dd = ""
	for x in range(0, W + 1, 160):
		dd += "M%d 404 L%d 500 " % (x, x)
	d.spath(dd, "#2e1c12", 3)
	for x in range(80, W, 160):
		d.rect(x - 16, 424, 32, 6, "#c9b07a", rx=3)
	# sink with dishes + bubbles
	d.rect(530, 374, 220, 14, "#8a949c", rx=4)
	d.ellipse(640, 378, 100, 8, "#5d676f")
	for k in range(6):
		d.ellipse(588 + k * 4, 362 - k * 7, 30, 8, "#f6f1e6", stroke="#b8b0a0", stroke_width=1.5)
	d.ellipse(700, 362, 22, 16, "#f6f1e6", stroke="#b8b0a0", stroke_width=1.5)
	for (x, y, r) in [(620, 360, 10), (650, 350, 14), (676, 362, 9), (700, 342, 8), (566, 366, 7), (640, 334, 6)]:
		d.circle(x, y, r, "#ffffff", opacity=0.35, stroke="#ffffff", stroke_width=1.5)
		d.circle(x - r * 0.35, y - r * 0.35, r * 0.25, "#ffffff", opacity=0.9)
	d.path("M760 372 L760 330 Q760 316 774 316 L790 316", "none", stroke="#8a949c", stroke_width=7)
	# cutting board with yuzu + knife, bowl stack
	d.rect(850, 360, 130, 14, "#c98a56", rx=4, stroke="#7a4a2c", stroke_width=2)
	for (x, r) in [(880, 11), (906, 12)]:
		yuzu(d, x, 350, r, 0, leaf=(x == 880))
	d.circle(934, 356, 9, YUZU)
	d.circle(934, 356, 6, "#fff2a0")
	d.spath("M930 356 L938 356 M934 352 L934 360", YUZU_D, 1.2)
	d.path("M944 360 L986 352 L990 356 L948 364 Z", "#c9ccd4", stroke="#5d676f", stroke_width=1.5)
	d.rect(986, 350, 22, 8, "#3a2a20", rx=3)
	for k in range(4):
		d.path("M%s %s Q%s %s %s %s Z" % (fm(430 - 2 * k), fm(370 - k * 10), fm(455), fm(394 - k * 10), fm(480 + 2 * k), fm(370 - k * 10)), "#f6f1e6", stroke="#b8b0a0", stroke_width=1.5)
		d.ellipse(455, 370 - k * 10, 25 + 2 * k, 4, "#2b3f78", opacity=0.6)
	# lamp over sink
	pendant(d, 640, 70, 0.9, "#d8833a")
	# floor checker
	d.rect(0, 506, W, H - 506, d.vlin(506, H, [(0, "#5a4038"), (1, "#3a2824")]))
	dd = ""
	rows = [506, 536, 572, 616, 668, 730]
	for ri in range(len(rows) - 1):
		y0, y1 = rows[ri], rows[ri + 1]
		t0, t1 = (y0 - 506) / 214.0, (y1 - 506) / 214.0
		for ci in range(-10, 11):
			if (ci + ri) % 2:
				continue
			def X(c, t):
				return 640 + c * 70 * (1 + 1.6 * t)
			dd += "M%s %s L%s %s L%s %s L%s %s Z " % tuple(fm(v) for v in (X(ci, t0), y0, X(ci + 1, t0), y0, X(ci + 1, t1), y1, X(ci, t1), y1))
	d.path(dd, "#c8a890", opacity=0.35)
	d.rect(0, 506, W, 10, "#000000", opacity=0.3)
	croc_cam(d, 1240, 70, 0.8, flip=True)
	floor_reflect(d, 640, 560, 300, 50, LANTERN, 0.2)
	glow(d, 640, 300, 420, LANTERN, 0.12)
	d.rect(0, 0, W, H, d.rad(640, 300, 900, [(0, "#1a1030", 0), (0.5, "#1a1030", 0.12), (1, "#1a1030", 0.45)]))
	vignette(d, 0.5)


def velvet_chair(d, cx, base, s=1.0, color="#7a1f3a", glitter=None, rng=None):
	"""Theatre chair seen from behind and slightly above. base = floor y."""
	w = 92 * s
	d.ellipse(cx, base, w * 0.6, 10 * s, "#000000", opacity=0.3)
	# seat (further away -> higher on screen)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(v) for v in (
		cx - w * 0.42, base - 112 * s, cx + w * 0.42, base - 112 * s, cx + w * 0.48, base - 86 * s, cx - w * 0.48, base - 86 * s)),
		d.vlin(base - 112 * s, base - 86 * s, [(0, light(color, 0.2)), (1, color)]))
	if glitter and rng:
		dd = ""
		for _ in range(26):
			gx = cx + rng.uniform(-w * 0.38, w * 0.38)
			gy = base - rng.uniform(88, 110) * s
			dd += "M%s %s l0.1 0 " % (fm(gx), fm(gy))
		d.spath(dd, glitter, 3.2)
		for k in range(4):
			sparkle(d, cx + rng.uniform(-w * 0.32, w * 0.32), base - rng.uniform(92, 108) * s, rng.uniform(5, 8) * s, "#ffd6f0", 1.0, glow_c=glitter)
	# armrests
	d.rect(cx - w * 0.56, base - 104 * s, 16 * s, 70 * s, dark(color, 0.45), rx=6 * s)
	d.rect(cx + w * 0.56 - 16 * s, base - 104 * s, 16 * s, 70 * s, dark(color, 0.45), rx=6 * s)
	d.rect(cx - w * 0.56, base - 106 * s, 16 * s, 6 * s, GOLD_D, rx=3 * s)
	d.rect(cx + w * 0.56 - 16 * s, base - 106 * s, 16 * s, 6 * s, GOLD_D, rx=3 * s)
	# backrest (closest)
	d.path("M%s %s Q%s %s %s %s Q%s %s %s %s L%s %s L%s %s Z" % tuple(fm(v) for v in (
		cx - w * 0.46, base - 30 * s, cx - w * 0.5, base - 96 * s, cx, base - 98 * s, cx + w * 0.5, base - 96 * s, cx + w * 0.46, base - 30 * s,
		cx + w * 0.46, base - 20 * s, cx - w * 0.46, base - 20 * s)),
		d.vlin(base - 98 * s, base - 20 * s, [(0, light(color, 0.1)), (1, dark(color, 0.35))]))
	d.path("M%s %s Q%s %s %s %s" % tuple(fm(v) for v in (cx - w * 0.4, base - 88 * s, cx, base - 94 * s, cx + w * 0.4, base - 88 * s)),
		"none", stroke=light(color, 0.35), stroke_width=3 * s, opacity=0.7)
	d.rect(cx - 8 * s, base - 22 * s, 16 * s, 22 * s, "#2a1810")
	d.rect(cx - w * 0.34, base - 20 * s, w * 0.68, 6 * s, "#2a1810")


def curtain(d, x0, y0, x1, y1, color, folds=6, gather=None):
	"""Theatre curtain. gather: None | 'left' | 'right' (tied back)."""
	w = x1 - x0
	if gather:
		# tied-back curtain: a tapered drape
		if gather == "right":
			pts_ = [(x0, y0), (x1, y0), (x1, y1), (x1 - w * 0.55, y1), (x1 - w * 0.3, y0 + (y1 - y0) * 0.55), (x0 + w * 0.05, y0 + (y1 - y0) * 0.25)]
			tie = (x1 - w * 0.32, y0 + (y1 - y0) * 0.55)
		else:
			pts_ = [(x0, y0), (x1, y0), (x1 - w * 0.05, y0 + (y1 - y0) * 0.25), (x0 + w * 0.3, y0 + (y1 - y0) * 0.55), (x0 + w * 0.55, y1), (x0, y1)]
			tie = (x0 + w * 0.32, y0 + (y1 - y0) * 0.55)
		d.poly(pts_, d.lin(x0, 0, x1, 0, [(0, dark(color, 0.3)), (0.5, color), (1, dark(color, 0.4))]))
		dd = ""
		for k in range(1, folds):
			fx = x0 + w * k / folds
			dd += "M%s %s Q%s %s %s %s " % (fm(fx), fm(y0), fm(fx + (8 if gather == "right" else -8)), fm((y0 + tie[1]) / 2), fm(tie[0]), fm(tie[1]))
		d.spath(dd, dark(color, 0.45), 3, opacity=0.6)
		d.ellipse(tie[0], tie[1], 12, 7, GOLD)
		d.line(tie[0], tie[1] + 4, tie[0] + 3, tie[1] + 26, GOLD, 3)
		return
	d.rect(x0, y0, w, y1 - y0, color)
	stops = []
	for k in range(folds * 2 + 1):
		t = k / (folds * 2)
		stops.append((t, dark(color, 0.45) if k % 2 == 0 else light(color, 0.18)))
	d.rect(x0, y0, w, y1 - y0, d.lin(x0, 0, x1, 0, stops))
	d.path("M%s %s " % (fm(x0), fm(y1)) + " ".join("Q%s %s %s %s" % (fm(x0 + w * (k + 0.5) / folds), fm(y1 + 8), fm(x0 + w * (k + 1) / folds), fm(y1)) for k in range(folds)) + " Z",
		dark(color, 0.2))


def bg_lounge(d):
	rng = random.Random(41)
	room_shell(d, 40, 40, 1240, 440, "#5a2f4a", "#3a1d33", "#1c1020", "#5a2a38", "#2a1420", side="#3a1d33", planks=0)
	# wallpaper damask dots + wainscot
	dd = ""
	for y in range(70, 360, 36):
		for x in range(60, 1230, 36):
			ox = 18 if (y // 36) % 2 else 0
			dd += "M%s %s l0.1 0 " % (fm(x + ox), fm(y))
	d.spath(dd, "#8a4a6a", 4, opacity=0.45)
	d.rect(40, 360, 1200, 80, d.vlin(360, 440, [(0, "#4a2418"), (1, "#2e160e")]))
	d.rect(40, 356, 1200, 6, GOLD_D, opacity=0.8)
	# stage (rect 430,120 -> 850,440)
	d.rect(432, 110, 416, 40, "#2a1018")
	d.rect(440, 150, 400, 236, d.vlin(150, 386, [(0, "#1a0c18"), (1, "#2a1428")]))
	# spotlight on the stage + mark where the statue stood
	d.poly([(600, 150), (680, 150), (760, 386), (520, 386)], "#fff2c8", opacity=0.10)
	d.ellipse(640, 380, 110, 16, "#fff2c8", opacity=0.22)
	d.ellipse(640, 378, 34, 8, "#3a2a2e")
	d.ellipse(640, 376, 30, 6, "#6a5560")
	d.spath("M600 384 L680 384 M640 372 L640 390", "#f2c230", 3, opacity=0.8)
	# curtains: left drawn across ~ half, right tied back
	curtain(d, 440, 150, 610, 384, "#b0232f", folds=5)
	curtain(d, 770, 150, 840, 384, "#b0232f", gather="right", folds=3)
	# valance + gold fringe
	d.path("M430 112 L850 112 L850 164 " + " ".join("Q%s 184 %s 164" % (fm(850 - 35 * k - 17.5), fm(850 - 35 * (k + 1))) for k in range(12)) + " Z",
		d.vlin(112, 184, [(0, "#c0303a"), (1, "#8a1a24")]))
	dd = ""
	for k in range(43):
		x = 432 + k * 10
		dd += "M%s 166 L%s 178 " % (fm(x), fm(x))
	d.spath(dd, GOLD, 2.2, opacity=0.9)
	d.rect(426, 104, 428, 10, GOLD_D)
	snapjaw_crest(d, 640, 130, 0.22)
	# stage front
	d.rect(430, 386, 420, 54, d.vlin(386, 440, [(0, "#6e3a22"), (1, "#3e1f12")]))
	d.rect(430, 386, 420, 6, "#a8683a")
	for k in range(6):
		x = 470 + k * 68
		d.circle(x, 392, 4, LANTERN_HOT)
		glow(d, x, 392, 16, LANTERN, 0.8)
	# poster: The Living Statue (left wall)
	d.rect(170, 120, 150, 200, "#1e1424", stroke=GOLD, stroke_width=4)
	d.rect(184, 134, 122, 172, d.vlin(134, 306, [(0, "#4a2a6a"), (1, "#24163a")]))
	glow(d, 245, 230, 60, "#c9a8ff", 0.35)
	capy_stand(d, 222, 290, 0.48, "#0e0814", face=1)
	d.rect(250, 231, 28, 6, "#0e0814")
	d.rect(255, 204, 18, 29, "#0e0814")
	for k in range(5):
		sparkle(d, 200 + k * 22, 150 + (k % 2) * 10, 5, "#e6e6ff", 0.9)
	glyphs(d, 194, 272, 100, 26, 1, "#f2c230", rng, 2.4, center=True)
	# right: back door (860,150 -> 960,430)
	d.rect(858, 146, 104, 288, "#2a1410")
	d.rect(866, 156, 88, 278, d.vlin(156, 434, [(0, "#7a4a2a"), (1, "#4e2c18")]))
	d.rect(874, 170, 72, 100, "none", stroke="#3a2014", stroke_width=3)
	d.rect(874, 290, 72, 120, "none", stroke="#3a2014", stroke_width=3)
	d.circle(940, 300, 5, GOLD)
	d.poly([(866, 156), (884, 162), (884, 428), (866, 434)], "#000000", opacity=0.25)
	d.rect(876, 118, 68, 22, "#1a3a2a", rx=3)
	d.rect(880, 122, 60, 14, "#3fdc8a", rx=2, opacity=0.8)
	glow(d, 910, 129, 50, "#3fdc8a", 0.25)
	d.spath("M888 129 L898 129 M904 125 L904 133 M912 129 L928 129", "#0e2a1a", 2)
	# sconces + chandelier
	wall_sconce(d, 380, 220, 0.8)
	wall_sconce(d, 1030, 220, 0.8)
	chandelier(d, 640, 44, 0.7)
	# small bar table right side (calm, above zone)
	d.rect(1040, 300, 150, 12, "#6e3a22", rx=4)
	d.rect(1100, 312, 30, 48, "#3e1f12")
	for k, c in enumerate(["#3fbfa0", "#e8a43a", "#c0392b"]):
		x = 1060 + k * 40
		d.rect(x, 268, 14, 32, c, rx=4, opacity=0.85)
		d.rect(x + 4, 258, 6, 12, c, opacity=0.85)
	# carpet floor
	d.poly([(40, 440), (1240, 440), (W + 600, H), (-600, H)], d.vlin(440, H, [(0, "#4a1f32"), (1, "#24101c")]))
	dd = ""
	for k in range(8):
		y = 450 + k * k * 4.6
		dd += "M0 %s L%s %s " % (fm(y), fm(W), fm(y))
	d.spath(dd, "#6a2c48", 2, opacity=0.35)
	glow(d, 640, 470, 420, "#ff9a7a", 0.10, ry=60)
	# front row seats (rect 400,480 -> 880,650)
	for i, cx in enumerate((460, 580, 700, 820)):
		velvet_chair(d, cx, 648, 1.15, "#7a1f3a", glitter="#ff6fb8" if i == 1 else None, rng=rng)
	light_wash(d, "#ff9a7a", 0.06, 0, 400)
	vignette(d, 0.55)



def mannequin(d, cx, base, s=1.0, color="#f4e6cc", glitter=False, rng=None, dress=None, hat=None):
	"""Capybara-shaped display mannequin (faceless) on a stand. base = floor y. ~370 tall at s=1."""
	sh = mix(color, "#b08a60", 0.35)

	def P(x, y):
		return (cx + x * s, base - y * s)
	# base + pole
	d.ellipse(cx, base - 4 * s, 56 * s, 12 * s, "#000000", opacity=0.3)
	d.ellipse(cx, base - 8 * s, 48 * s, 11 * s, "#5a4a42")
	d.ellipse(cx, base - 12 * s, 48 * s, 10 * s, "#8a7a6e")
	d.rect(cx - 5 * s, base - 120 * s, 10 * s, 110 * s, "#9a9aa2")
	d.rect(cx - 5 * s, base - 120 * s, 3 * s, 110 * s, "#d0d0d8")
	# torso (dress form)
	torso = [P(-58, 120), P(-64, 170), P(-70, 232), P(-52, 268), P(-22, 280), P(22, 280), P(52, 268), P(70, 232), P(64, 170), P(58, 120), P(0, 112)]
	d.blob(torso, d.lin(cx - 70 * s, 0, cx + 70 * s, 0, [(0, sh), (0.4, light(color, 0.2)), (1, sh)]), stroke=dark(color, 0.45), stroke_width=2.5)
	d.spath("M%s %s Q%s %s %s %s" % tuple(fm(v) for v in (cx, base - 276 * s, cx + 4 * s, base - 200 * s, cx, base - 116 * s)), dark(color, 0.3), 1.5, opacity=0.6)
	if dress:
		dp = [P(-54, 268), P(-50, 230), P(-44, 200), P(-70, 150), P(-104, 70), P(-50, 58), P(0, 62), P(50, 58), P(104, 70), P(70, 150), P(44, 200), P(50, 230), P(54, 268), P(24, 262), P(0, 248), P(-24, 262)]
		d.blob(dp, d.lin(cx - 100 * s, 0, cx + 100 * s, 0, [(0, dark(dress, 0.3)), (0.45, light(dress, 0.15)), (1, dark(dress, 0.3))]), t=0.8,
			stroke=dark(dress, 0.5), stroke_width=2)
		d.spath("M%s %s Q%s %s %s %s M%s %s Q%s %s %s %s" % tuple(fm(v) for v in (
			P(-20, 192)[0], P(-20, 192)[1], P(-40, 120)[0], P(-40, 120)[1], P(-50, 64)[0], P(-50, 64)[1],
			P(20, 192)[0], P(20, 192)[1], P(40, 120)[0], P(40, 120)[1], P(50, 64)[0], P(50, 64)[1])), dark(dress, 0.35), 2, opacity=0.6)
		d.spath("M%s %s Q%s %s %s %s" % tuple(fm(v) for v in (P(-46, 202)[0], P(-46, 202)[1], cx, base - 192 * s, P(46, 202)[0], P(46, 202)[1])), "#fff6e0", 6 * s)
	# neck + capybara head (blank)
	d.rect(cx - 14 * s, base - 300 * s, 28 * s, 24 * s, sh)
	d.ellipse(cx - 34 * s, base - 366 * s, 10 * s, 9 * s, color, stroke=dark(color, 0.45), stroke_width=2)
	d.ellipse(cx + 34 * s, base - 366 * s, 10 * s, 9 * s, color, stroke=dark(color, 0.45), stroke_width=2)
	head = [P(-44, 292), P(-52, 318), P(-48, 350), P(-30, 368), P(0, 372), P(30, 368), P(48, 350), P(52, 318), P(44, 292), P(0, 286)]
	d.blob(head, d.lin(cx - 52 * s, 0, cx + 52 * s, 0, [(0, sh), (0.45, light(color, 0.25)), (1, sh)]), stroke=dark(color, 0.45), stroke_width=2.5)
	d.ellipse(cx, base - 306 * s, 40 * s, 19 * s, light(color, 0.12), opacity=0.9)
	d.spath("M%s %s Q%s %s %s %s" % tuple(fm(v) for v in (cx - 38 * s, base - 316 * s, cx, base - 330 * s, cx + 38 * s, base - 316 * s)), dark(color, 0.25), 1.6, opacity=0.6)
	d.spath("M%s %s l%s %s M%s %s l%s %s" % tuple(fm(v) for v in (cx - 13 * s, base - 312 * s, 4 * s, -3 * s, cx + 13 * s, base - 312 * s, -4 * s, -3 * s)), dark(color, 0.4), 2.2 * s)
	if hat == "sun":
		d.ellipse(cx, base - 362 * s, 78 * s, 16 * s, "#f3e3b0", stroke="#a8864a", stroke_width=2)
		d.path("M%s %s Q%s %s %s %s Z" % tuple(fm(v) for v in (cx - 38 * s, base - 362 * s, cx, base - 404 * s, cx + 38 * s, base - 362 * s)), "#f3e3b0", stroke="#a8864a", stroke_width=2)
		d.rect(cx - 36 * s, base - 372 * s, 72 * s, 8 * s, "#b07ad0")
		d.spath("M%s %s Q%s %s %s %s" % tuple(fm(v) for v in (cx + 30 * s, base - 372 * s, cx + 70 * s, base - 410 * s, cx + 54 * s, base - 430 * s)), "#ffffff", 6 * s)
	if glitter and rng:
		dd = ""
		for side in (-1, 1):
			for _ in range(22):
				gx = cx + side * rng.uniform(20, 62) * s
				gy = base - rng.uniform(250, 282) * s
				dd += "M%s %s l0.1 0 " % (fm(gx), fm(gy))
		d.spath(dd, "#b9a2ff", 3.4 * s)
		for side in (-1, 1):
			for k in range(3):
				sparkle(d, cx + side * rng.uniform(26, 60) * s, base - rng.uniform(254, 280) * s, rng.uniform(6, 10) * s, "#f2eeff", 1.0, glow_c="#9a7aff")


def plushie(d, x, base, s=1.0, color="#9a6440", kind="capy"):
	if kind == "croc":
		d.ellipse(x, base - 16 * s, 22 * s, 17 * s, CROC_G)
		d.ellipse(x + 14 * s, base - 30 * s, 20 * s, 9 * s, CROC_G)
		d.circle(x + 2 * s, base - 38 * s, 5 * s, "#ffffff")
		d.circle(x + 3 * s, base - 38 * s, 2.4 * s, RED_EYE)
		d.rect(x - 6 * s, base - 54 * s, 14 * s, 14 * s, "#1f1a26")
		d.rect(x - 10 * s, base - 42 * s, 22 * s, 3 * s, "#1f1a26")
		d.spath("M%s %s l4 3 l4 -3 l4 3 l4 -3" % (fm(x + 2 * s), fm(base - 25 * s)), "#ffffff", 1.4)
		return
	d.ellipse(x, base - 15 * s, 22 * s, 16 * s, color)
	d.ellipse(x, base - 36 * s, 17 * s, 14 * s, color)
	d.ellipse(x, base - 31 * s, 11 * s, 7 * s, light(color, 0.2))
	d.circle(x - 11 * s, base - 48 * s, 4.5 * s, dark(color, 0.2))
	d.circle(x + 11 * s, base - 48 * s, 4.5 * s, dark(color, 0.2))
	d.circle(x - 6 * s, base - 40 * s, 2 * s, INK)
	d.circle(x + 6 * s, base - 40 * s, 2 * s, INK)
	d.ellipse(x, base - 31 * s, 4 * s, 2.4 * s, dark(color, 0.45))
	if kind == "yuzu":
		d.circle(x, base - 54 * s, 6 * s, YUZU)


def bunting(d, x0, x1, y, sag, rng, colors=("#e8553d", YUZU, "#2bb7b3", "#f3e9d2")):
	n = int((x1 - x0) / 34)
	pts_ = []
	for i in range(n + 1):
		t = i / n
		pts_.append((x0 + (x1 - x0) * t, y + sag * 4 * t * (1 - t)))
	d.spath(smooth(pts_, False), "#3a2616", 1.6)
	for i in range(n):
		(ax, ay), (bx, by) = pts_[i], pts_[i + 1]
		mx, my = (ax + bx) / 2, (ay + by) / 2
		d.poly([(ax + 3, ay), (bx - 3, by), (mx, my + 22)], colors[i % len(colors)])


def bg_giftshop(d):
	rng = random.Random(51)
	room_shell(d, 0, 0, W, 410, "#f0d7b4", "#c99a6e", "#3a2216", "#b07a50", "#6a4028", planks=26)
	d.rect(0, 0, W, 34, "#4a2a1a")
	d.rect(0, 340, W, 70, d.vlin(340, 410, [(0, "#8a5634"), (1, "#5a3220")]))
	d.rect(0, 336, W, 6, "#a8683a")
	bunting(d, 0, 640, 40, 34, rng)
	bunting(d, 640, W, 40, 34, rng)
	# shelves unit (380,120 -> 900,280)
	d.rect(372, 104, 536, 184, "#5a3220", rx=4)
	d.rect(382, 112, 516, 170, "#7a4a2c")
	for (sy) in (168, 224, 280):
		d.rect(376, sy, 528, 9, "#a8683a")
		d.rect(376, sy + 9, 528, 4, "#000000", opacity=0.25)
	kinds = ["capy", "capy", "yuzu", "croc", "capy", "yuzu", "capy", "capy", "croc", "capy"]
	cols = ["#9a6440", "#c48a5a", "#8a5030", "#b87a4a", "#7a4a2c"]
	for i in range(10):
		x = 405 + i * 52
		plushie(d, x, 168, 0.95, cols[i % 5], kinds[i])
	for i in range(13):
		x = 398 + i * 39
		c = ["#2bb7b3", "#f3e9d2", YUZU, "#e8553d"][i % 4]
		if i % 3 == 2:
			d.ellipse(x + 14, 212, 14, 10, YUZU)
			d.ellipse(x + 10, 208, 4, 3, "#ffffff", opacity=0.6)
		else:
			d.rect(x, 192, 28, 32, c, rx=3)
			d.rect(x + 4, 200, 20, 10, "#ffffff", opacity=0.6, rx=2)
	for i in range(9):
		x = 400 + i * 56
		c = ["#d8e8f0", "#f6d8e0", "#e8f0d0"][i % 3]
		d.rect(x, 246, 46, 34, c, rx=12)
		d.spath("M%s 262 Q%s 254 %s 262" % (fm(x + 8), fm(x + 23), fm(x + 38)), dark(c, 0.25), 2)
	# left: display platform with dressed mannequins on small pedestals
	def pedestal(cx, top, rx, h, mark=False):
		d.ellipse(cx, top + h + 4, rx * 1.15, rx * 0.26, "#000000", opacity=0.3)
		d.rect(cx - rx, top, rx * 2, h, d.lin(cx - rx, 0, cx + rx, 0, [(0, "#b8aea4"), (0.35, "#fbf6ee"), (1, "#a49a90")]))
		d.ellipse(cx, top + h, rx, rx * 0.24, "#a49a90")
		d.ellipse(cx, top, rx, rx * 0.24, "#fffdf8", stroke="#c8beb4", stroke_width=2)
		d.rect(cx - rx - 6, top + h - 14, rx * 2 + 12, 14, "#8a7a6e")
		d.ellipse(cx, top + h, rx + 6, rx * 0.26, "#8a7a6e")
		if mark:
			d.ellipse(cx, top, rx * 0.52, rx * 0.12, "none", stroke="#a89a8a", stroke_width=3, stroke_dasharray="6 5")
			d.ellipse(cx, top, rx * 0.5, rx * 0.11, "#e8dccb", opacity=0.6)
	d.rect(96, 322, 262, 30, "#c98a56", rx=4)
	d.rect(104, 352, 246, 64, d.vlin(352, 416, [(0, "#8a5634"), (1, "#5a3220")]))
	d.rect(96, 318, 262, 6, GOLD_D)
	pedestal(160, 300, 40, 26)
	mannequin(d, 160, 300, 0.5, dress="#b07ad0", hat="sun")
	pedestal(290, 300, 40, 26)
	mannequin(d, 290, 300, 0.5, dress="#2bb7b3")
	# spotlight cone onto the empty pedestal
	d.poly([(600, 300), (660, 300), (735, 432), (525, 432)], "#fff6dc", opacity=0.12)
	d.rect(596, 292, 68, 12, "#3a2a20", rx=4)
	pedestal(630, 432, 94, 112, mark=True)
	d.rect(600, 478, 60, 30, "#fff8ea", stroke="#a89a8a", stroke_width=2, rx=3)
	glyphs(d, 606, 484, 48, 18, 2, "#7a5a40", rng, 1.6)
	# counter + price-tag gun (760,420 -> 900,520)
	d.rect(744, 470, 196, 22, d.vlin(470, 492, [(0, "#c98a56"), (1, "#a8683a")]), rx=3)
	d.rect(752, 492, 180, 110, d.vlin(492, 602, [(0, "#7a4a2c"), (1, "#4a2818")]))
	d.rect(764, 506, 156, 80, "none", stroke="#a8683a", stroke_width=2)
	snapjaw_crest(d, 842, 546, 0.26)
	price_gun(d, 826, 466, 1.0)
	d.rect(902, 448, 26, 24, "#e8553d", rx=4)
	d.rect(906, 438, 18, 12, "#f3e9d2", rx=3)
	# right wall: hanging yukata display
	d.line(970, 92, 1200, 92, "#5a3220", 5)
	for k, c in enumerate(["#2b3f78", "#c0392b", "#1f6f6b"]):
		x = 990 + k * 72
		d.path("M%s 96 L%s 96 L%s 122 L%s 122 L%s 300 L%s 300 L%s 122 L%s 122 Z" % tuple(fm(v) for v in (
			x, x + 60, x + 76, x + 64, x + 60, x, x - 4, x - 16)), c)
		d.path("M%s 96 L%s 150 L%s 96 Z" % (fm(x + 18), fm(x + 30), fm(x + 42)), "#f3e9d2")
		d.rect(x - 2, 200, 64, 14, YUZU, opacity=0.9)
		dd = ""
		for j in range(6):
			dd += "M%s %s l0.1 0 " % (fm(x + 8 + (j % 3) * 20), fm(140 + (j // 3) * 90))
		d.spath(dd, "#ffffff", 5, opacity=0.6)
	croc_cam(d, 34, 70, 0.8)
	floor_reflect(d, 630, 560, 200, 30, "#fff6dc", 0.2)
	light_wash(d, "#fff0d0", 0.14, 0, 300)
	vignette(d, 0.4)


def price_gun(d, x, y, s=1.0):
	"""Hand price-tag labeler lying on a counter. (x,y) = rough center-bottom."""
	with G(d, transform=T(x, y, s)):
		d.ellipse(0, 2, 62, 7, "#000000", opacity=0.3)
		# tag strip curling out the front
		d.path("M-56 -12 Q-72 -10 -74 2 Q-72 10 -60 6 L-56 -4 Z", "#ffffff", stroke="#a8a8a8", stroke_width=1.2)
		dd = ""
		for k in range(3):
			dd += "M%s %s l3 -8 " % (fm(-70 + k * 5), fm(4 - k * 2))
		d.spath(dd, "#c0c0c0", 1)
		# head
		d.path("M-58 -32 L4 -32 Q14 -32 14 -22 L14 -8 Q14 0 6 0 L-58 0 Q-62 0 -62 -6 L-62 -26 Q-62 -32 -58 -32 Z", "#f2a33a", stroke=INK, stroke_width=2.5)
		d.rect(-54, -26, 44, 10, "#fff6dc", stroke=INK, stroke_width=1.5, rx=2)
		d.spath("M-50 -21 l6 0 M-40 -21 l4 0 M-32 -21 l6 0", "#7a5a40", 1.6)
		# label roll on top
		d.circle(-18, -44, 18, "#ffffff", stroke=INK, stroke_width=2.5)
		d.circle(-18, -44, 7, "#c9c9c9", stroke=INK, stroke_width=1.5)
		d.path("M-36 -44 Q-40 -34 -50 -32 L-40 -32 Z", "#ffffff")
		# grip + trigger
		d.path("M2 -6 L40 -2 Q54 0 52 10 L48 14 Q44 18 36 14 L0 0 Z", "#e0802a", stroke=INK, stroke_width=2.5, stroke_linejoin="round")
		d.path("M-4 -2 Q4 8 18 6 L14 0 Z", "#3a3a40", stroke=INK, stroke_width=1.5)
		d.path("M-52 -30 L0 -30 L-6 -24 L-52 -24 Z", "#ffffff", opacity=0.3)


def wooden_bucket(d, cx, base, w=64, h=46, color="#d9b27a", crack=False, glitter=False, rng=None):
	tw = w
	bw = w * 0.84
	d.path("M%s %s L%s %s L%s %s Q%s %s %s %s Z" % tuple(fm(v) for v in (
		cx - tw / 2, base - h, cx + tw / 2, base - h, cx + bw / 2, base, cx, base + 6, cx - bw / 2, base)),
		d.lin(cx - tw / 2, 0, cx + tw / 2, 0, [(0, dark(color, 0.25)), (0.4, light(color, 0.15)), (1, dark(color, 0.3))]))
	dd = ""
	for k in range(1, 6):
		t = k / 6
		dd += "M%s %s L%s %s " % (fm(cx - tw / 2 + tw * t), fm(base - h + 4), fm(cx - bw / 2 + bw * t), fm(base))
	d.spath(dd, dark(color, 0.35), 1.2, opacity=0.6)
	for t in (0.25, 0.75):
		yy = base - h + h * t
		ww = tw + (bw - tw) * t
		d.path("M%s %s Q%s %s %s %s" % tuple(fm(v) for v in (cx - ww / 2, yy, cx, yy + 5, cx + ww / 2, yy)), "none", stroke="#4a3a30", stroke_width=4)
	d.ellipse(cx, base - h, tw / 2, h * 0.16, dark(color, 0.45))
	d.ellipse(cx, base - h, tw / 2, h * 0.16, "none", stroke=light(color, 0.2), stroke_width=3)
	if crack:
		d.spath("M%s %s l6 10 l-4 6 l7 9" % (fm(cx + tw * 0.18), fm(base - h - 2)), INK, 2.2)
	if glitter and rng:
		dd = ""
		for _ in range(18):
			dd += "M%s %s l0.1 0 " % (fm(cx + rng.uniform(-tw * 0.4, tw * 0.4)), fm(base - h - rng.uniform(4, 24)))
		d.spath(dd, "#c0a8ff", 3)


def bg_changing(d):
	rng = random.Random(61)
	room_shell(d, 0, 50, W, 510, "#e8cda0", "#c79e6c", "#3a2616", "#a87a4e", "#5a3a24", planks=0)
	d.rect(0, 0, W, 54, "#4a2e1c")
	d.rect(0, 50, W, 6, "#7a5032")
	# vertical wall boards
	dd = ""
	for x in range(0, W, 40):
		dd += "M%d 56 L%d 510 " % (x, x)
	d.spath(dd, "#b08a5a", 1.4, opacity=0.5)
	d.rect(0, 440, W, 70, d.vlin(440, 510, [(0, "#7a5032"), (1, "#5a3a24")]))
	d.rect(0, 436, W, 5, "#9a6a40")
	# floor: slatted sunoko
	d.rect(0, 510, W, H - 510, d.vlin(510, H, [(0, "#8a6440"), (1, "#4a3220")]))
	dd = ""
	y = 516.0
	gap = 10.0
	while y < H:
		dd += "M0 %s L%s %s " % (fm(y), fm(W), fm(y))
		y += gap
		gap *= 1.16
	d.spath(dd, "#3a2616", 2.2, opacity=0.6, stroke_linecap="butt")
	d.rect(0, 510, W, 8, "#000000", opacity=0.3)
	# lockers (60,110 -> 460,540)
	d.rect(62, 104, 398, 436, "#4a2e1c")
	d.rect(62, 500, 398, 40, "#3a2416")
	for r in range(3):
		for c in range(4):
			x = 72 + c * 96
			y = 114 + r * 128
			d.rect(x, y, 88, 120, d.vlin(y, y + 120, [(0, "#c98f5a"), (1, "#a86e40")]), rx=3)
			d.rect(x + 6, y + 6, 76, 4, "#ffffff", opacity=0.2)
			dd = "M%s %s L%s %s M%s %s L%s %s M%s %s L%s %s" % tuple(fm(v) for v in (x + 30, y + 74, x + 58, y + 74, x + 30, y + 82, x + 58, y + 82, x + 30, y + 90, x + 58, y + 90))
			d.spath(dd, "#6e4424", 2)
			d.circle(x + 44, y + 28, 11, "#fff8e8", stroke="#6e4424", stroke_width=2)
			glyphs(d, x + 38, y + 22, 12, 12, 1, "#6e4424", rng, 1.6)
			d.rect(x + 70, y + 50, 8, 16, GOLD_D, rx=2)
			if (r + c) % 3 != 1:
				d.spath("M%s %s q-8 16 4 22 q10 -4 4 -22" % (fm(x + 74), fm(y + 64)), "#3a7aa8" if (r + c) % 2 else "#e8553d", 3)
	# bench in front of lockers
	d.rect(70, 520, 380, 14, "#c08850", rx=3)
	d.rect(90, 534, 14, 30, "#6e4424")
	d.rect(416, 534, 14, 30, "#6e4424")
	# dark gap behind lockers (a rim peeking out)
	d.rect(460, 120, 12, 420, "#1e120a", opacity=0.85)
	d.path("M460 502 Q470 498 474 506 L474 520 L460 520 Z", "#c9a06a")
	# coat hooks (520,140 -> 760,250)
	d.rect(522, 160, 236, 18, d.vlin(160, 178, [(0, "#8a5a34"), (1, "#5a3a22")]), rx=4)
	hooks = [548, 594, 640, 686, 732]
	towels = {0: "#f3f3ee", 1: "#9cc8e8", 3: "#f3f3ee", 4: "#f0c8a0"}
	for i, hx_ in enumerate(hooks):
		d.circle(hx_, 170, 4, "#3a3a40")
		d.spath("M%s 172 L%s 186 Q%s 194 %s 188" % (fm(hx_), fm(hx_), fm(hx_ + 8), fm(hx_ + 10)), "#4a4a52", 4)
		if i in towels:
			c = towels[i]
			d.path("M%s 184 L%s 184 L%s 240 Q%s 246 %s 240 Z" % tuple(fm(v) for v in (hx_ - 16, hx_ + 18, hx_ + 20, hx_ + 2, hx_ - 18)), c, stroke=dark(c, 0.25), stroke_width=1.5)
			d.rect(hx_ - 17, 226, 37, 5, dark(c, 0.18))
		else:
			# Bruno's hook: empty, marked in red
			d.rect(hx_ - 13, 140, 26, 16, "#e0302a", rx=3, stroke="#8f1d1a", stroke_width=2)
			d.spath("M%s 148 l4 -3 l4 3 l4 -3 l4 3" % fm(hx_ - 9), "#ffffff", 1.6)
	# bucket stack (520,430 -> 720,580)
	d.ellipse(620, 580, 110, 12, "#000000", opacity=0.3)
	for (cx, base) in [(556, 576), (620, 576), (684, 576), (588, 530), (652, 530), (620, 484)]:
		wooden_bucket(d, cx, base, 62, 44)
	# side door (790,110 -> 950,510): sliding door, slightly open onto the garden
	d.rect(788, 106, 164, 408, "#4a2e1c")
	d.rect(800, 118, 140, 392, d.vlin(118, 510, [(0, "#bfe3c0"), (0.6, "#8fc78a"), (1, "#6aa060")]))
	d.rect(800, 118, 140, 140, d.vlin(118, 258, [(0, "#e6f4ff"), (1, "#bfe3c0")]))
	d.blob([(800, 250), (840, 226), (870, 238), (900, 214), (940, 236), (940, 330), (800, 330)], "#5f9e5a")
	d.poly([(800, 470), (940, 470), (940, 510), (800, 510)], "#a8a8a0")
	d.ellipse(850, 492, 34, 9, "#c8c8c0")
	d.rect(846, 118, 94, 392, d.vlin(118, 510, [(0, "#a87442"), (1, "#7a5030")]))
	d.rect(856, 130, 74, 170, "none", stroke="#5a3a22", stroke_width=3)
	d.rect(856, 320, 74, 170, "none", stroke="#5a3a22", stroke_width=3)
	d.rect(852, 290, 6, 34, "#3a2416", rx=3)
	d.poly([(800, 510), (846, 510), (900, 720), (760, 720)], "#fff8d0", opacity=0.13)
	glow(d, 822, 400, 140, "#fff6c0", 0.25)
	# right wall (calm): mirror + towel shelf above the zone
	d.ellipse(1110, 190, 70, 86, "#6e4424")
	d.ellipse(1110, 190, 60, 76, d.lin(1050, 110, 1170, 270, [(0, "#e8f4f4"), (0.5, "#b8d0d4"), (1, "#8ab0b8")]))
	d.path("M1072 150 L1092 130 M1068 176 L1104 140", "none", stroke="#ffffff", stroke_width=4, opacity=0.6)
	d.rect(1010, 296, 200, 10, "#8a5a34")
	for k, c in enumerate(["#f3f3ee", "#9cc8e8", "#f3f3ee", "#f0c8a0"]):
		d.rect(1022 + k * 46, 276, 40, 20, c, rx=6)
	# ceiling lamp + cam
	chochin(d, 640, 48, 0.55, "#f4e9d2", lit=True, glow_a=0.4)
	croc_cam(d, 1246, 78, 0.8, flip=True)
	light_wash(d, "#fff3d8", 0.12, 0, 300)
	vignette(d, 0.42)


def bg_sauna(d):
	rng = random.Random(71)
	wood1, wood2 = "#c9773e", "#8a4422"
	d.rect(0, 0, W, 380, d.vlin(0, 380, [(0, dark(wood2, 0.25)), (0.6, wood2), (1, dark(wood2, 0.15))]))
	dd = ""
	for x in range(0, W, 34):
		dd += "M%d 0 L%d 380 " % (x, x)
	d.spath(dd, "#5a2a14", 2, opacity=0.6, stroke_linecap="butt")
	d.rect(0, 0, W, 380, d.rad(600, 260, 700, [(0, "#ffb070", 0.35), (1, "#ffb070", 0)]))
	d.rect(0, 0, W, 26, "#3a1a0c")
	# floor
	d.rect(0, 370, W, H - 370, d.vlin(370, H, [(0, "#5a2e18"), (1, "#2a140a")]))
	d.rect(0, 368, W, 8, "#2a140a")
	# sand timer + thermometer (upper left, above zone)
	d.rect(176, 140, 54, 10, "#5a2a14")
	d.rect(176, 250, 54, 10, "#5a2a14")
	d.path("M184 150 L222 150 L206 200 L222 250 L184 250 L200 200 Z", "#e8f4ff", opacity=0.7, stroke="#5a2a14", stroke_width=2)
	d.path("M188 154 L218 154 L204 190 Z", "#f2c230")
	d.path("M190 248 L216 248 L203 226 Z", "#f2c230")
	d.rect(296, 130, 40, 150, "#6e3a1e", rx=18)
	d.rect(311, 146, 10, 110, "#f6f1e6", rx=5)
	d.rect(311, 196, 10, 60, "#d8332c", rx=5)
	d.circle(316, 258, 9, "#d8332c")
	# stove (500,140 -> 700,360)
	glow(d, 600, 260, 220, "#ff8a3a", 0.45)
	d.rect(522, 250, 156, 110, d.vlin(250, 360, [(0, "#4a4a50"), (1, "#26262a")]), rx=6)
	for k in range(4):
		d.rect(540 + k * 34, 300, 22, 8, "#ff7a2a", rx=3)
		glow(d, 551 + k * 34, 304, 18, "#ff7a2a", 0.7)
	d.rect(516, 244, 168, 12, "#5a5a62", rx=4)
	stones = [(540, 236, 22, 15), (572, 230, 24, 16), (606, 232, 22, 15), (640, 229, 24, 16), (668, 236, 18, 13),
		(556, 214, 20, 14), (590, 210, 22, 15), (624, 212, 22, 15), (656, 218, 18, 13), (590, 194, 18, 12), (622, 192, 20, 13)]
	for (cx, cy, rx, ry) in stones:
		rock(d, cx, cy, rx, ry, rng, "#6e6a70", 0.25)
	for (cx, cy) in [(565, 228), (612, 222), (640, 205)]:
		glow(d, cx, cy, 16, "#ffaa50", 0.6)
	# wooden guard rail
	d.rect(504, 270, 192, 10, "#a85a2c")
	d.rect(504, 330, 192, 10, "#a85a2c")
	for x in range(508, 700, 24):
		d.rect(x, 262, 10, 100, "#c06a34", rx=3)
	steam(d, rng, 520, 140, 680, 200, 6, 0.22, 30, 60)
	steam_wisps(d, rng, 540, 200, 660, 210, 4, 0.18)
	# door panel (820,160 -> 940,320)
	d.line(880, 0, 880, 172, "#3a3a40", 6)
	d.rect(828, 168, 104, 146, d.vlin(168, 314, [(0, "#9aa3ab"), (1, "#6f787f")]), rx=8, stroke="#3a3a40", stroke_width=3)
	d.rect(840, 182, 80, 56, "#0e2a2a", rx=4)
	d.rect(840, 182, 80, 56, d.brad([(0, "#3fdcc8", 0.35), (1, "#3fdcc8", 0)]), rx=4)
	for (yy, txt) in [(188, "9:28"), (212, "9:56")]:
		d.rect(846, yy, 11, 19, "none", stroke="#6ff0d8", stroke_width=1.8)
		d.circle(854, yy + 10, 1.4, "#6ff0d8")
		seg_digits(d, 864, yy + 1, 17, txt, "#7ff8e0", off="#163a38")
	glow(d, 880, 210, 70, "#3fdcc8", 0.25)
	d.circle(852, 258, 6, "#3fdc6a")
	glow(d, 852, 258, 14, "#3fdc6a", 0.7)
	d.circle(872, 258, 6, "#ff4a3a")
	for k in range(3):
		d.rect(890 + k * 0, 252 + k * 0, 0, 0, "none")
	d.rect(888, 252, 30, 12, "#3a3a40", rx=3)
	snapjaw_crest(d, 880, 292, 0.16)
	# sauna door (right)
	d.rect(958, 86, 170, 290, "#3a1a0c")
	d.rect(968, 96, 150, 280, d.vlin(96, 376, [(0, "#b8683a"), (1, "#8a4422")]))
	dd = ""
	for x in range(980, 1118, 18):
		dd += "M%d 96 L%d 376 " % (x, x)
	d.spath(dd, "#6a3418", 1.6, opacity=0.6)
	d.rect(1003, 120, 80, 110, "#f0e0c8", rx=6, opacity=0.85)
	d.rect(1003, 120, 80, 110, d.vlin(120, 230, [(0, "#ffffff", 0.6), (1, "#ffffff", 0)]), rx=6)
	d.rect(1080, 240, 12, 60, "#3a1a0c", rx=5)
	# benches (340,420 -> 860,620)
	def bench(x0, x1, ytop, depth, face):
		d.rect(x0 - 8, ytop + depth + face, x1 - x0 + 16, 10, "#000000", opacity=0.25)
		d.poly([(x0 + 14, ytop), (x1 - 14, ytop), (x1, ytop + depth), (x0, ytop + depth)], d.vlin(ytop, ytop + depth, [(0, "#e8a060"), (1, "#c98048")]))
		dd = ""
		for k in range(1, 4):
			yy = ytop + depth * k / 4
			dd += "M%s %s L%s %s " % (fm(x0 + 14 * (1 - k / 4)), fm(yy), fm(x1 - 14 * (1 - k / 4)), fm(yy))
		d.spath(dd, "#8a4a22", 1.6, opacity=0.7)
		d.rect(x0, ytop + depth, x1 - x0, face, d.vlin(ytop + depth, ytop + depth + face, [(0, "#a85a2c"), (1, "#6a3418")]))
		dd = ""
		for x in range(int(x0) + 30, int(x1), 60):
			dd += "M%d %s L%d %s " % (x, fm(ytop + depth + 4), x, fm(ytop + depth + face))
		d.spath(dd, "#4a2410", 2, opacity=0.5)
	bench(360, 840, 424, 30, 58)
	bench(340, 860, 520, 32, 64)
	# towel on upper bench, bucket + ladle on lower bench
	d.path("M420 424 L500 424 L506 454 L500 500 L486 500 L482 454 L414 454 Z", "#f3f3ee")
	d.path("M482 454 L506 454 L500 500 L486 500 Z", "#d8d8d0")
	wooden_bucket(d, 770, 540, 58, 40, "#d9b27a")
	d.line(770, 500, 800, 470, "#8a5a34", 4)
	d.ellipse(803, 466, 10, 6, "#8a5a34")
	# corner lamp with slats
	glow(d, 90, 80, 160, LANTERN, 0.45)
	d.rect(60, 50, 60, 70, "#5a2a14", rx=6)
	for k in range(5):
		d.rect(64 + k * 11, 54, 7, 62, LANTERN_HOT, rx=2, opacity=0.9)
	steam(d, rng, 0, 80, W, 460, 10, 0.07, 80, 160)
	light_wash(d, "#ff9a50", 0.12, 0, 720)
	vignette(d, 0.5, "#1a0804")


def rose_bush(d, cx, cy, rx, ry, rng, thread=True):
	"""Round rose bush: dark leaves, red/pink roses. thread = snagged violet cape thread."""
	d.ellipse(cx, cy + ry * 0.9, rx * 1.05, ry * 0.22, "#000000", opacity=0.25)
	for (dx, dy, k, c) in [(0, 0.1, 1.0, "#3a7442"), (-0.4, 0.15, 0.62, "#43804a"), (0.42, 0.18, 0.6, "#356a3c"), (0, -0.25, 0.7, "#4e8c52")]:
		d.blob(blob_pts(cx + dx * rx, cy + dy * ry, rx * k, ry * k * 0.95, rng, 12, 0.13), c)
	# leaf texture
	dd = ""
	for _ in range(40):
		a = rng.uniform(0, math.tau)
		rr = rng.uniform(0.1, 0.85)
		lx, ly = cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr
		dd += "M%s %s q6 -8 12 0 q-6 6 -12 0 " % (fm(lx), fm(ly))
	d.path(dd, "#5a9a5a", opacity=0.6)
	# roses
	for _ in range(13):
		a = rng.uniform(0, math.tau)
		rr = rng.uniform(0.1, 0.8)
		x, y = cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr
		r = rng.uniform(9, 13)
		c = rng.choice(["#d8333f", "#e8506a", "#c0283a"])
		d.circle(x, y, r, c)
		d.spath("M%s %s q%s %s %s 0 q%s %s %s 0" % (fm(x - r * 0.5), fm(y), fm(r * 0.5), fm(-r * 0.6), fm(r), fm(-r * 0.4), fm(r * 0.5), fm(-r * 0.6)), dark(c, 0.35), 1.6)
		d.circle(x - r * 0.3, y - r * 0.35, r * 0.25, "#ffffff", opacity=0.35)
	# pruned stems (thorny)
	for (sx, sy) in [(cx - rx * 0.6, cy - ry * 0.55), (cx + rx * 0.7, cy - ry * 0.4)]:
		d.spath("M%s %s l-8 -22 M%s %s l-2 -7 l-5 2" % (fm(sx), fm(sy), fm(sx - 4), fm(sy - 11)), "#4a3a22", 3)
	if thread:
		tx, ty = cx + rx * 0.62, cy - ry * 0.1
		d.spath("M%s %s q14 6 22 22 q6 12 -2 26" % (fm(tx), fm(ty)), "#8a4ad8", 3.2)
		d.spath("M%s %s q14 6 22 22 q6 12 -2 26" % (fm(tx), fm(ty)), "#c8a0ff", 1.2)
		for (ox, oy) in [(10, 6), (20, 22), (18, 40)]:
			sparkle(d, tx + ox, ty + oy, 5, "#ffffff", 1.0, glow_c="#b090ff")


def bg_garden(d, thread=True):
	rng = random.Random(81)
	d.rect(0, 0, W, 420, d.vlin(0, 420, [(0, "#8ec0e8"), (0.6, "#cfe6f0"), (1, "#f4f0dc")]))
	glow(d, 160, 40, 380, "#fff8e0", 0.7)
	# distant trees + far fence in the gap
	for (cx, cy, rx, ry, c) in [(560, 250, 120, 90, "#7aa67a"), (720, 240, 130, 100, "#6a9a72"), (640, 200, 90, 80, "#86b486")]:
		d.blob(blob_pts(cx, cy, rx, ry, rng, 11, 0.12), c)
	# maple
	d.rect(700, 170, 10, 140, "#6a4a32")
	d.blob(blob_pts(706, 160, 70, 50, rng, 10, 0.18), "#e07a4a", opacity=0.9)
	d.blob(blob_pts(690, 140, 40, 30, rng, 8, 0.18), "#f0a060", opacity=0.9)
	bamboo_fence(d, 290, 380, "#c9ae74", "#8d7140", rng, x0=480, x1=800, posts=False)
	# ground
	d.rect(0, 400, W, H - 400, d.vlin(400, H, [(0, "#8fbf6a"), (1, "#5a8a46")]))
	dd = ""
	for _ in range(70):
		x, y = rng.uniform(0, W), rng.uniform(420, H)
		dd += "M%s %s l-3 -9 M%s %s l3 -8 " % (fm(x), fm(y), fm(x + 5), fm(y))
	d.spath(dd, "#4f7f3a", 2, opacity=0.5)
	# LEFT building: lounge (stucco + timber)
	d.rect(0, 70, 500, 340, d.vlin(70, 410, [(0, "#f2e6cc"), (1, "#d8c4a0")]))
	d.rect(0, 70, 500, 340, "none", stroke="#5a3a22", stroke_width=10)
	for x in (110, 300):
		d.rect(x - 8, 70, 16, 340, "#5a3a22")
	d.rect(0, 120, 500, 12, "#5a3a22")
	d.path("M-20 82 L520 82 L500 40 L0 40 Z", "#3a3040")
	d.path("M-20 82 L520 82 L516 92 L-16 92 Z", "#2a2030")
	dd = ""
	for x in range(0, 520, 22):
		dd += "M%d 44 L%d 82 " % (x, x - 4)
	d.spath(dd, "#4f4458", 3, opacity=0.8)
	# window with curtains
	d.rect(140, 160, 130, 120, "#5a3a22")
	d.rect(148, 168, 114, 104, "#3a4a6a")
	d.rect(148, 168, 40, 104, "#9a2a3a")
	d.rect(222, 168, 40, 104, "#9a2a3a")
	d.line(205, 168, 205, 272, "#5a3a22", 4)
	d.rect(136, 280, 138, 10, "#5a3a22")
	# lounge back door (340,160 -> 480,410)
	d.rect(340, 156, 140, 254, "#3a2416")
	d.rect(352, 168, 116, 242, d.vlin(168, 410, [(0, "#8a4a2a"), (1, "#5a2e1a")]))
	d.rect(366, 184, 88, 70, "#f6e2b8")
	d.rect(366, 184, 88, 70, "none", stroke="#3a2416", stroke_width=4)
	d.line(410, 184, 410, 254, "#3a2416", 3)
	d.rect(366, 276, 88, 112, "none", stroke="#3a2416", stroke_width=3)
	d.circle(452, 300, 5, GOLD)
	d.rect(330, 404, 160, 14, "#9a9a92")
	wall_sconce(d, 316, 220, 0.6, lit=False)
	# RIGHT building: bathhouse (dark wood boards + tiled eave)
	d.rect(780, 60, 500, 350, d.vlin(60, 410, [(0, "#6a4a32"), (1, "#4a3020")]))
	dd = ""
	for y in range(80, 410, 18):
		dd += "M780 %d L1280 %d " % (y, y)
	d.spath(dd, "#3a2416", 2, opacity=0.6)
	d.rect(780, 60, 16, 350, "#2a1a10")
	d.path("M760 96 L1300 96 L1280 30 L790 30 Z", "#2e3a44")
	d.path("M760 96 L1300 96 L1296 106 L764 106 Z", "#1e2830")
	dd = ""
	for x in range(790, 1290, 20):
		dd += "M%d 34 L%d 96 " % (x, x - 6)
	d.spath(dd, "#46545e", 3, opacity=0.8)
	d.rect(1040, 140, 140, 100, "#2a1a10")
	d.rect(1050, 150, 120, 80, "#cfe0e0", opacity=0.6)
	steam(d, rng, 1060, 110, 1160, 150, 3, 0.25, 30, 50)
	shoji(d, 1050, 150, 120, 80, "#e8eee8", "#2a1a10", cols=4, rows=2, a=0.6)
	# bathhouse side door (800,160 -> 940,410)
	d.rect(800, 156, 140, 254, "#2a1a10")
	d.rect(810, 166, 120, 244, d.vlin(166, 410, [(0, "#b08050"), (1, "#7a5030")]))
	dd = ""
	for x in range(826, 930, 16):
		dd += "M%d 170 L%d 406 " % (x, x)
	d.spath(dd, "#6a4228", 1.6, opacity=0.6)
	d.rect(820, 178, 100, 60, "#e8eee8", opacity=0.75)
	shoji(d, 820, 178, 100, 60, "#e8eee8", "#4a2e1c", cols=4, rows=2, a=0.9)
	d.rect(818, 290, 8, 40, "#3a2416", rx=3)
	d.rect(844, 132, 52, 20, "#f3e3c0", rx=3, stroke="#4a2e1c", stroke_width=2)
	glyphs(d, 850, 136, 40, 12, 1, "#4a2e1c", rng, 1.6)
	d.rect(806, 404, 128, 14, "#9a9a92")
	# hedges along walls
	for (x0, x1) in [(0, 330), (490, 520), (940, 1280)]:
		for k in range(int((x1 - x0) / 60) + 1):
			cx = x0 + k * 60 + 20
			if cx > x1:
				break
			d.blob(blob_pts(cx, 408, 42, 24, rng, 9, 0.15), "#4f8a4a")
			d.blob(blob_pts(cx - 6, 398, 26, 14, rng, 8, 0.15), "#6aa45a", opacity=0.8)
			for _ in range(2):
				d.circle(cx + rng.uniform(-30, 30), 400 + rng.uniform(-10, 8), 3.4, rng.choice(["#ffffff", "#ffd0e0", YUZU]))
	# stone lanterns
	stone_lantern(d, 250, 432, 0.72, lit=False, stone="#a8aaa8")
	stone_lantern(d, 1030, 432, 0.72, lit=False, stone="#a8aaa8")
	# stone path (U from lounge door to bath door)
	stones_ = [(412, 432, 30, 10), (432, 470, 36, 13), (468, 520, 46, 16), (530, 570, 54, 18), (622, 610, 64, 22),
		(730, 600, 62, 21), (812, 556, 52, 18), (850, 504, 42, 15), (866, 462, 34, 12), (870, 428, 28, 10),
		(470, 640, 58, 22), (790, 660, 70, 24), (620, 680, 80, 26)]
	for (cx, cy, rx, ry) in stones_:
		d.ellipse(cx + 3, cy + 5, rx, ry, "#000000", opacity=0.22)
		d.blob(blob_pts(cx, cy, rx, ry, rng, 9, 0.1), d.vlin(cy - ry, cy + ry, [(0, "#d8d6cc"), (1, "#a2a096")]))
		d.ellipse(cx - rx * 0.2, cy - ry * 0.3, rx * 0.45, ry * 0.3, "#ffffff", opacity=0.25)
	# gravel dots
	dd = ""
	for _ in range(60):
		dd += "M%s %s l0.1 0 " % (fm(rng.uniform(380, 900)), fm(rng.uniform(440, 700)))
	d.spath(dd, "#e8e4d0", 3, opacity=0.5)
	# rose bush in the middle (520,300 -> 760,500)
	rose_bush(d, 640, 412, 112, 84, rng, thread=thread)
	glow(d, 160, 400, 300, "#fff8e0", 0.18, ry=120)
	for (x0, x1) in [(120, 220), (260, 320)]:
		d.poly([(x0, 0), (x1, 0), (x1 + 420, H), (x0 + 380, H)], "#fffbe8", opacity=0.07)
	vignette(d, 0.3, "#203020")


def bg_storage(d):
	rng = random.Random(91)
	room_shell(d, 0, 30, W, 455, "#4a3a44", "#2e2430", "#1a1218", "#3e3036", "#1a1216", planks=20)
	dd = ""
	for x in range(0, W, 46):
		dd += "M%d 30 L%d 455 " % (x, x)
	d.spath(dd, "#22181e", 2, opacity=0.6)
	# light leaking from the stage door (left)
	d.rect(22, 40, 14, 420, "#fff0c0", opacity=0.5)
	d.poly([(36, 455), (22, 455), (0, 720), (160, 720)], "#fff0c0", opacity=0.08)
	glow(d, 30, 250, 120, "#fff0c0", 0.18)
	# costume rack (top-left, ends above the zone)
	d.line(120, 100, 310, 100, "#8a8a92", 5)
	d.line(130, 100, 120, 340, "#6a6a72", 4)
	d.line(300, 100, 310, 340, "#6a6a72", 4)
	for k, c in enumerate(["#3a2a6a", "#7a1f3a", "#1f4a3a", "#5a2a6a"]):
		x = 150 + k * 40
		d.path("M%s 104 L%s 104 L%s 320 Q%s 330 %s 320 Z" % tuple(fm(v) for v in (x - 12, x + 22, x + 30, x + 5, x - 20)), c)
		d.spath("M%s 98 q6 -10 12 0" % fm(x - 1), "#9a9aa2", 2)
	for k in range(5):
		sparkle(d, 158 + k * 30, 160 + (k % 3) * 40, 4, "#e6e6ff", 0.7)
	# prop boxes (340,120 -> 470,320)
	d.rect(330, 314, 152, 10, "#2a1e22")
	for (x, y, w, h, c) in [(346, 252, 122, 62, "#a87a4a"), (352, 196, 110, 56, "#8a6a8a"), (360, 128, 96, 68, "#b8905a")]:
		d.rect(x, y, w, h, d.vlin(y, y + h, [(0, light(c, 0.12)), (1, dark(c, 0.2))]), rx=3, stroke="#2a1a10", stroke_width=2)
		d.rect(x, y + h * 0.42, w, 6, dark(c, 0.3))
		d.rect(x + w * 0.3, y + 10, w * 0.4, 16, "#efe4d2", rx=2)
		glyphs(d, x + w * 0.33, y + 12, w * 0.34, 12, 1, "#5a3a22", rng, 1.4)
	d.spath("M450 196 q20 30 6 60 q-12 24 4 50", "#e05a9a", 7, opacity=0.9)
	d.line(420, 128, 448, 96, "#1a1a1a", 4)
	d.line(445, 99, 450, 93, "#ffffff", 4)
	sparkle(d, 452, 90, 7, "#fff6c0", 1.0)
	# hanging ropes / sandbag (right)
	for x in (1060, 1120, 1170):
		d.line(x, 30, x + 6, 280, "#8a7050", 3)
	d.path("M1100 280 Q1120 270 1140 280 L1146 330 Q1120 344 1094 330 Z", "#8a7a5a")
	# bare bulb + light cone
	d.line(600, 0, 600, 64, "#1a1a1a", 2)
	d.poly([(570, 80), (630, 80), (760, 600), (420, 600)], "#fff2c0", opacity=0.10)
	glow(d, 600, 82, 160, "#fff0c0", 0.6)
	d.circle(600, 80, 13, "#fff8e0")
	d.rect(594, 60, 12, 12, "#6a6a72")
	dd = ""
	for _ in range(30):
		dd += "M%s %s l0.1 0 " % (fm(rng.uniform(470, 730)), fm(rng.uniform(110, 560)))
	d.spath(dd, "#fff6d8", 2.4, opacity=0.6)
	d.ellipse(590, 576, 170, 30, "#fff2c0", opacity=0.12)
	# mannequin (480,200 -> 700,580)
	mannequin(d, 590, 578, 1.0, color="#e8dcc8", glitter=True, rng=rng)
	# magic trunk (740,300 -> 940,560) standing on end
	d.ellipse(840, 560, 104, 12, "#000000", opacity=0.35)
	d.rect(752, 312, 176, 246, d.lin(752, 0, 928, 0, [(0, "#3a1f5a"), (0.4, "#5a3080"), (1, "#2a1544")]), rx=10, stroke="#1a0c28", stroke_width=3)
	d.rect(752, 300, 176, 22, "#4a2a6a", rx=6, stroke="#1a0c28", stroke_width=3)
	for (x, y) in [(752, 312), (928, 312), (752, 558), (928, 558)]:
		d.circle(x, y, 13, GOLD, stroke=GOLD_D, stroke_width=2)
	for yy in (380, 490):
		d.rect(752, yy, 176, 10, GOLD_D)
		d.rect(752, yy, 176, 3, GOLD)
	d.rect(826, 418, 28, 34, GOLD, rx=4, stroke=GOLD_D, stroke_width=2)
	d.circle(840, 432, 4, "#2a1544")
	for (x, y, r) in [(790, 345, 14), (885, 350, 10), (800, 440, 9), (890, 450, 15), (790, 525, 11), (880, 528, 9), (840, 340, 7)]:
		sparkle(d, x, y, r, GOLD, 1.0)
	glow(d, 840, 440, 140, "#9a6aff", 0.12)
	croc_cam(d, 1246, 60, 0.75, flip=True)
	vignette(d, 0.6, "#05030a")



CAST_COLORS = ["#d98a3a", "#a8552f", "#5a3a6a", "#7a3a2a", "#e8a0c0", "#c8a870", "#e6dcc8", "#6a7a3a", "#8a8a8a",
	"#4a4a58", "#c89a5a", "#d8a060", "#b8b0a8", "#e09a60", "#b07a50"]


def bg_hallway(d):
	rng = random.Random(101)
	vx, vy = 640, 300
	NX0, NX1, NY0, NY1 = -120, 1400, -160, 790

	def P(side, sc, v):
		x = vx + ((NX0 if side < 0 else NX1) - vx) * sc
		y = vy + (NY0 - vy) * sc + (NY1 - NY0) * v * sc
		return (x, y)

	def F(u, sc):
		"""floor point: u in 0..1 across the corridor."""
		x = vx + (NX0 + (NX1 - NX0) * u - vx) * sc
		return (x, vy + (NY1 - vy) * sc)
	far = 0.15
	wall1, wall2 = "#e6c79a", "#b88a5c"
	# ceiling + floor + walls
	d.rect(0, 0, W, H, "#2a1810")
	d.poly([P(-1, 1, 0), P(1, 1, 0), P(1, far, 0), P(-1, far, 0)], d.vlin(0, vy, [(0, "#1e120c"), (1, "#4a3020")]))
	d.poly([P(-1, 1, 1), P(1, 1, 1), P(1, far, 1), P(-1, far, 1)], d.vlin(vy, H, [(0, "#5a3a26"), (1, "#3a2216")]))
	for side in (-1, 1):
		d.poly([P(side, 1, 0), P(side, far, 0), P(side, far, 1), P(side, 1, 1)],
			d.lin(P(side, 1, 0)[0], 0, vx, 0, [(0, dark(wall2, 0.35)), (0.7, wall1), (1, light(wall1, 0.1))]))
		# wainscot band
		d.poly([P(side, 1, 0.72), P(side, far, 0.72), P(side, far, 1), P(side, 1, 1)], "#5a3420", opacity=0.9)
		d.spath("M%s %s L%s %s" % (fm(P(side, 1, 0.72)[0]), fm(P(side, 1, 0.72)[1]), fm(P(side, far, 0.72)[0]), fm(P(side, far, 0.72)[1])), GOLD_D, 3, opacity=0.7)
		# ceiling cornice
		d.spath("M%s %s L%s %s" % (fm(P(side, 1, 0.06)[0]), fm(P(side, 1, 0.06)[1]), fm(P(side, far, 0.06)[0]), fm(P(side, far, 0.06)[1])), "#3a2216", 8)
	# ceiling beams + lamps
	for z in (1.4, 2.2, 3.2, 4.4, 5.8):
		sc = 1 / z
		a, b = P(-1, sc, 0), P(1, sc, 0)
		d.spath("M%s %s L%s %s" % (fm(a[0]), fm(a[1]), fm(b[0]), fm(b[1])), "#24140c", 14 * sc)
	for z in (1.8, 2.7, 3.8, 5.1):
		sc = 1 / z
		cx, cy = vx, vy + (NY0 - vy) * sc + 40 * sc
		glow(d, cx, cy + 20 * sc, 220 * sc, LANTERN, 0.5)
		d.rect(cx - 50 * sc, cy, 100 * sc, 18 * sc, LANTERN_HOT, rx=4 * sc)
		d.rect(cx - 50 * sc, cy, 100 * sc, 18 * sc, "none", stroke="#5a3a22", stroke_width=3 * sc)
	# end wall: shuttered window + cam
	ex0, ey0 = P(-1, far, 0)
	ex1, ey1 = P(1, far, 1)
	d.rect(ex0, ey0, ex1 - ex0, ey1 - ey0, d.vlin(ey0, ey1, [(0, wall1), (1, wall2)]))
	steel_shutter(d, ex0 + 50, ey0 + 34, ex1 - ex0 - 100, ey1 - ey0 - 60, rng, crest=False)
	snapjaw_crest(d, (ex0 + ex1) / 2, ey0 + 18, 0.16)
	potted_plant(d, ex0 + 26, ey1 - 2, 0.42, rng=rng)
	potted_plant(d, ex1 - 26, ey1 - 2, 0.42, rng=rng)
	# carpet runner
	d.poly([F(0.36, 1), F(0.64, 1), F(0.64, far), F(0.36, far)], "#8c1f2a")
	for u in (0.37, 0.63):
		a, b = F(u, 1), F(u, far)
		d.spath("M%s %s L%s %s" % (fm(a[0]), fm(a[1]), fm(b[0]), fm(b[1])), GOLD, 3)
	dd = ""
	for z in (1.2, 1.6, 2.1, 2.8, 3.6, 4.6, 5.8):
		a, b = F(0.36, 1 / z), F(0.64, 1 / z)
		dd += "M%s %s L%s %s " % (fm(a[0]), fm(a[1]), fm(b[0]), fm(b[1]))
	d.spath(dd, GOLD_D, 2, opacity=0.6)
	d.poly([F(0.36, 1), F(0.64, 1), F(0.64, far), F(0.36, far)], d.vlin(vy, H, [(0, "#000000", 0.3), (0.5, "#000000", 0), (1, "#000000", 0.25)]))
	# doors on both walls
	doors = [(1.7, 2.3), (2.9, 3.4), (4.0, 4.4), (5.0, 5.35), (5.9, 6.2)]
	k = 0
	for side in (-1, 1):
		for (za, zb) in doors:
			sa, sb = 1 / za, 1 / zb
			col = CAST_COLORS[k % len(CAST_COLORS)]
			k += 1
			fr = [P(side, sa, 0.26), P(side, sb, 0.26), P(side, sb, 1), P(side, sa, 1)]
			d.poly(fr, "#3a2216")
			ia = 1 / (za + (zb - za) * 0.08)
			ib = 1 / (zb - (zb - za) * 0.08)
			pan = [P(side, ia, 0.29), P(side, ib, 0.29), P(side, ib, 1), P(side, ia, 1)]
			d.poly(pan, d.lin(pan[0][0], 0, pan[1][0], 0, [(0, "#8a5230"), (1, "#6a3c22")]))
			# inner panel lines
			ma = 1 / (za + (zb - za) * 0.22)
			mb = 1 / (zb - (zb - za) * 0.22)
			d.poly([P(side, ma, 0.36), P(side, mb, 0.36), P(side, mb, 0.6), P(side, ma, 0.6)], "none", stroke="#4a2a18", stroke_width=3 * ma)
			d.poly([P(side, ma, 0.66), P(side, mb, 0.66), P(side, mb, 0.93), P(side, ma, 0.93)], "none", stroke="#4a2a18", stroke_width=3 * ma)
			# nameplate with a colored capy emblem
			na = 1 / (za + (zb - za) * 0.3)
			nb = 1 / (zb - (zb - za) * 0.3)
			np_ = [P(side, na, 0.18), P(side, nb, 0.18), P(side, nb, 0.23), P(side, na, 0.23)]
			d.poly(np_, "#f3e3c0", stroke=GOLD_D, stroke_width=2 * na)
			cxp = (np_[0][0] + np_[1][0]) / 2
			cyp = (np_[0][1] + np_[3][1]) / 2
			d.circle(cxp, cyp, 9 * na, col, stroke=INK, stroke_width=1.5 * na)
			# knob
			kx = P(side, 1 / (zb - (zb - za) * 0.2), 0.68)
			d.circle(kx[0], kx[1], 5 * sb, GOLD)
	# wall sconces between doors
	for side in (-1, 1):
		for z in (1.25, 2.6, 3.7, 4.7, 5.6):
			x, y = P(side, 1 / z, 0.34)
			wall_sconce(d, x, y, 0.75 / z)
	# portrait zones: soften the near walls
	for side in (-1, 1):
		d.poly([P(side, 1, 0), P(side, 0.62, 0), P(side, 0.62, 1), P(side, 1, 1)], "#1a0e08", opacity=0.25)
	glow(d, vx, vy + 60, 400, LANTERN, 0.12)
	croc_cam(d, 1250, 40, 0.9, flip=True)
	vignette(d, 0.5)


def bg_room(d):
	rng = random.Random(111)
	room_shell(d, 0, 40, W, 420, "#3a4a7a", "#2a3460", "#141a33", "#4a5a40", "#232c1e", side="#232c52", planks=0)
	d.rect(0, 0, W, 44, "#1e1a2a")
	d.rect(0, 40, W, 6, "#3a3048")
	for px in (60, 250, 740, 1030, 1220):
		d.rect(px - 12, 40, 24, 380, d.lin(px - 12, 0, px + 12, 0, [(0, "#1e1828"), (0.5, "#3a3048"), (1, "#15101e")]))
	d.rect(0, 380, W, 40, "#1e1828")
	# shoji window with moonlight + bamboo shadows
	d.rect(276, 96, 452, 270, "#1e1828")
	d.rect(286, 106, 432, 250, d.vlin(106, 356, [(0, "#b8c8f0"), (1, "#8a9ad0")]))
	glow(d, 560, 200, 260, "#e8f0ff", 0.5)
	for (x, a) in [(340, 0.35), (380, 0.25), (660, 0.3)]:
		d.line(x, 106, x + 6, 356, "#2a3460", 7, opacity=a)
		for yy in (170, 250, 320):
			d.path("M%s %s q22 -10 40 -2 q-20 8 -40 2 Z" % (fm(x + 4), fm(yy)), "#2a3460", opacity=a)
			d.path("M%s %s q-22 -12 -36 -4 q18 8 36 4 Z" % (fm(x + 2), fm(yy + 18)), "#2a3460", opacity=a)
	shoji(d, 286, 106, 432, 250, "#000000", "#1e1828", cols=6, rows=4, a=0.0)
	dd = ""
	for c in range(1, 6):
		x = 286 + 432 * c / 6
		dd += "M%s 106 L%s 356 " % (fm(x), fm(x))
	for r in range(1, 4):
		y = 106 + 250 * r / 4
		dd += "M286 %s L718 %s " % (fm(y), fm(y))
	d.spath(dd, "#1e1828", 4, stroke_linecap="butt")
	# tokonoma alcove with hanging scroll + yuzu bowl
	d.rect(770, 80, 240, 300, "#1a1626")
	d.rect(780, 90, 220, 290, d.vlin(90, 380, [(0, "#2e3458"), (1, "#22284a")]))
	d.rect(770, 370, 240, 16, "#4a3a2a")
	d.rect(858, 106, 64, 190, "#e8dcc0")
	d.rect(852, 100, 76, 8, "#4a3020")
	d.rect(852, 294, 76, 8, "#4a3020")
	d.path("M872 230 Q890 160 908 230 Q890 250 872 230 Z", "#7a8a9a", opacity=0.6)
	glyphs(d, 868, 120, 44, 100, 4, "#2a2a3a", rng, 2, a=0.75)
	d.circle(890, 260, 10, "#d84a3a", opacity=0.8)
	d.ellipse(940, 362, 30, 9, "#3a3a52")
	yuzu(d, 932, 352, 10, -20)
	yuzu(d, 950, 354, 9, 20, leaf=False)
	# wall monitor (Snapjaw announcements) + cam
	d.rect(70, 92, 160, 104, "#111118", rx=6)
	d.rect(78, 100, 144, 84, "#20283a")
	d.rect(78, 100, 144, 84, d.brad([(0, "#5a6a8a", 0.6), (1, "#20283a", 0)]))
	dd = ""
	for y in range(104, 184, 6):
		dd += "M80 %d L220 %d " % (y, y)
	d.spath(dd, "#ffffff", 1, opacity=0.08)
	snapjaw_crest(d, 150, 142, 0.34, a=0.55)
	d.line(150, 196, 150, 210, "#111118", 4)
	croc_cam(d, 1246, 70, 0.8, flip=True)
	# tatami floor
	d.rect(0, 420, W, H - 420, d.vlin(420, H, [(0, "#4a5a40"), (1, "#1e261a")]))
	dd = ""
	for i in range(-4, 9):
		xt = 640 + (i * 200 - 640 + 200) * 0.6
		xb = 640 + (i * 200 - 640 + 200) * 1.5
		dd += "M%s 420 L%s 720 " % (fm(xt), fm(xb))
	for y in (470, 560):
		dd += "M0 %d L%d %d " % (y, W, y)
	d.spath(dd, "#1e2618", 4, opacity=0.8, stroke_linecap="butt")
	# moonlight patch on the floor
	d.poly([(330, 430), (700, 430), (820, 620), (280, 620)], "#c8d8ff", opacity=0.08)
	# futon (380,470 -> 900,640)
	d.ellipse(640, 640, 300, 26, "#000000", opacity=0.35)
	d.poly([(420, 470), (860, 470), (920, 610), (360, 610)], "#e8e4dc")
	d.poly([(360, 610), (920, 610), (920, 636), (360, 636)], "#b8b4ac")
	d.rect(470, 474, 120, 40, "#f6f2ea", rx=16, stroke="#c8c4bc", stroke_width=2)
	blanket = [(560, 500), (860, 486), (908, 610), (520, 612)]
	d.poly(blanket, d.lin(520, 0, 908, 0, [(0, "#d98a3a"), (1, "#b86a28")]))
	d.path("M600 520 Q700 500 840 512 Q860 560 820 592 Q700 600 590 596 Q570 556 600 520 Z", "#e89a48", opacity=0.45)
	d.poly([(520, 612), (908, 610), (910, 632), (518, 634)], "#8a4a1a")
	for (x, y) in [(640, 530), (740, 520), (820, 560), (690, 585), (600, 580)]:
		d.circle(x, y, 9, YUZU, opacity=0.8)
		d.path("M%s %s q4 -8 10 -6 q-4 6 -10 6 Z" % (fm(x), fm(y - 8)), "#5f9e3a", opacity=0.9)
	d.spath("M562 502 Q600 520 590 560", "#f0a050", 3, opacity=0.6)
	d.rect(0, 0, W, H, "#0a1030", opacity=0.38)
	d.poly([(330, 430), (700, 430), (820, 620), (280, 620)], "#c8d8ff", opacity=0.06)
	# Mochi's folded orange hoodie + towel by the futon
	d.ellipse(392, 618, 50, 10, "#000000", opacity=0.3)
	d.rect(346, 588, 92, 30, "#d8732a", rx=8)
	d.rect(346, 588, 92, 10, "#f08a3a", rx=6)
	d.path("M372 598 Q392 610 412 598", "none", stroke="#a8561e", stroke_width=3)
	d.rect(352, 572, 80, 18, "#e8ecf4", rx=7)
	d.spath("M360 581 L424 581", "#b8c0d0", 1.6)
	# andon lamp (right of futon)
	glow(d, 930, 400, 300, LANTERN, 0.5)
	d.rect(900, 330, 60, 120, d.vlin(330, 450, [(0, "#fff0c8"), (1, "#f0c070")]))
	d.rect(900, 330, 60, 120, "none", stroke="#3a2616", stroke_width=4)
	d.line(930, 330, 930, 450, "#3a2616", 3)
	d.line(900, 390, 960, 390, "#3a2616", 3)
	d.rect(894, 448, 72, 10, "#3a2616")
	d.rect(898, 458, 6, 18, "#3a2616")
	d.rect(956, 458, 6, 18, "#3a2616")
	floor_reflect(d, 930, 490, 200, 40, LANTERN, 0.3)
	vignette(d, 0.55, "#05060f")


def podium(d, cx, base, s=1.0, color="#8a5a34", emblem=None, memorial=False, dim=0.0):
	w = 70 * s
	h = 62 * s
	wd = dark(color, 0.35)
	d.ellipse(cx, base + 2 * s, w * 0.75, 8 * s, "#000000", opacity=0.35)
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(v) for v in (cx - w / 2, base - h, cx + w / 2, base - h, cx + w * 0.42, base, cx - w * 0.42, base)),
		d.lin(cx - w / 2, 0, cx + w / 2, 0, [(0, wd), (0.45, light(color, 0.12)), (1, wd)]))
	d.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(v) for v in (cx - w * 0.6, base - h - 10 * s, cx + w * 0.6, base - h - 10 * s, cx + w * 0.54, base - h, cx - w * 0.54, base - h)),
		light(color, 0.2))
	d.rect(cx - w * 0.6, base - h - 13 * s, w * 1.2, 4 * s, GOLD_D)
	d.rect(cx - w * 0.3, base - h * 0.72, w * 0.6, h * 0.26, "#f3e3c0", rx=2 * s)
	if emblem:
		d.circle(cx, base - h * 0.59, 6 * s, emblem, stroke=INK, stroke_width=1.2 * s)
	if memorial:
		# framed portrait with a cross of red tape
		fx, fy = cx, base - h - 40 * s
		d.rect(fx - 22 * s, fy - 26 * s, 44 * s, 52 * s, GOLD, stroke=GOLD_D, stroke_width=2 * s)
		d.rect(fx - 17 * s, fy - 21 * s, 34 * s, 42 * s, "#cfe6f0")
		d.ellipse(fx, fy + 4 * s, 12 * s, 10 * s, "#a8552f")
		d.ellipse(fx, fy - 6 * s, 13 * s, 5 * s, "#ffffff")
		d.circle(fx - 8 * s, fy - 3 * s, 2.5 * s, "#a8552f")
		d.rect(fx - 13 * s, fy + 12 * s, 26 * s, 9 * s, "#24306a")
		d.line(fx - 20 * s, fy - 24 * s, fx + 20 * s, fy + 24 * s, "#e0302a", 6 * s, stroke_linecap="butt")
		d.line(fx + 20 * s, fy - 24 * s, fx - 20 * s, fy + 24 * s, "#e0302a", 6 * s, stroke_linecap="butt")
		d.line(fx - 9 * s, fy + 26 * s, fx - 14 * s, base - h - 10 * s, GOLD_D, 2 * s)
		d.line(fx + 9 * s, fy + 26 * s, fx + 14 * s, base - h - 10 * s, GOLD_D, 2 * s)
	if dim > 0:
		d.path("M%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(v) for v in (cx - w * 0.6, base - h - 13 * s, cx + w * 0.6, base - h - 13 * s, cx + w * 0.42, base, cx - w * 0.42, base)), "#05080f", opacity=dim)


def throne_island(d, cx, base, s=1.0, rng=None):
	# rock island
	rng = rng or random.Random(5)
	d.ellipse(cx, base + 10 * s, 150 * s, 26 * s, "#0a2a30", opacity=0.6)
	for (dx, dy, rx, ry) in [(-80, 4, 70, 30), (70, 6, 74, 28), (0, -6, 110, 40), (-30, -30, 70, 34), (40, -26, 60, 30)]:
		rock(d, cx + dx * s, base + dy * s, rx * s, ry * s, rng, "#3a3448", 0.2)
	top = base - 46 * s
	# throne
	glow(d, cx, top - 90 * s, 180 * s, RED_EYE, 0.22)
	d.path("M%s %s L%s %s Q%s %s %s %s Q%s %s %s %s L%s %s Z" % tuple(fm(v) for v in (
		cx - 60 * s, top, cx - 66 * s, top - 150 * s, cx - 40 * s, top - 205 * s, cx, top - 210 * s, cx + 40 * s, top - 205 * s, cx + 66 * s, top - 150 * s, cx + 60 * s, top)),
		d.lin(cx - 66 * s, 0, cx + 66 * s, 0, [(0, "#2a0c18"), (0.5, "#6a1a34"), (1, "#2a0c18")]), stroke=GOLD, stroke_width=4 * s)
	# teeth crown along the top
	dd = ""
	for k in range(7):
		x = cx - 42 * s + k * 14 * s
		dd += "M%s %s L%s %s L%s %s Z " % (fm(x), fm(top - 200 * s + abs(k - 3) * 4 * s), fm(x + 7 * s), fm(top - 222 * s + abs(k - 3) * 5 * s), fm(x + 14 * s), fm(top - 200 * s + abs(k - 3) * 4 * s))
	d.path(dd, "#fffbe8", stroke=GOLD_D, stroke_width=1.5 * s)
	snapjaw_crest(d, cx, top - 140 * s, 0.55 * s)
	# seat + arms
	d.rect(cx - 70 * s, top - 60 * s, 140 * s, 30 * s, "#8a1f3a", rx=8 * s, stroke=GOLD_D, stroke_width=3 * s)
	d.rect(cx - 84 * s, top - 90 * s, 26 * s, 80 * s, "#4a1024", rx=8 * s, stroke=GOLD, stroke_width=3 * s)
	d.rect(cx + 58 * s, top - 90 * s, 26 * s, 80 * s, "#4a1024", rx=8 * s, stroke=GOLD, stroke_width=3 * s)
	d.rect(cx - 60 * s, top - 30 * s, 120 * s, 30 * s, "#3a0c1c")
	for x in (cx - 71 * s, cx + 71 * s):
		d.circle(x, top - 96 * s, 9 * s, GOLD)


def bg_trial(d):
	rng = random.Random(121)
	d.rect(0, 0, W, H, "#06080f")
	# domed ceiling
	d.rect(0, 0, W, 330, d.vlin(0, 330, [(0, "#05060c"), (0.6, "#0c1424"), (1, "#14223a")]))
	# ring of ceiling lights
	for k in range(13):
		t = k / 12
		x = 60 + t * 1160
		y = 40 + 30 * math.sin(t * math.pi)
		glow(d, x, y, 26, AQUA, 0.6)
		d.circle(x, y, 4, "#e8ffff")
	# curved back wall with pillars + arches
	def wall_y(x, base=300, amp=60):
		t = (x - 640) / 700
		return base - amp * (1 - t * t)
	d.path("M0 %s " % fm(wall_y(0, 330)) + " ".join("L%s %s" % (fm(x), fm(wall_y(x, 330))) for x in range(0, W + 1, 40)) + " L%d 120 L0 120 Z" % W,
		"none")
	top_pts = [(x, wall_y(x, 150, 70)) for x in range(-40, W + 41, 40)]
	bot_pts = [(x, wall_y(x, 330, 50)) for x in range(-40, W + 41, 40)]
	wall = "M" + " L".join("%s %s" % (fm(x), fm(y)) for x, y in top_pts) + " L" + " L".join("%s %s" % (fm(x), fm(y)) for x, y in reversed(bot_pts)) + " Z"
	d.path(wall, d.vlin(80, 330, [(0, "#1a2238"), (1, "#24304a")]))
	# arches between pillars
	pill = [-60, 70, 200, 330, 460, 590, 690, 820, 950, 1080, 1210, 1340]
	for i in range(len(pill) - 1):
		x0, x1 = pill[i] + 16, pill[i + 1] - 16
		yb = wall_y((x0 + x1) / 2, 330, 50)
		yt = wall_y((x0 + x1) / 2, 150, 70) + 26
		d.path("M%s %s L%s %s Q%s %s %s %s Z" % tuple(fm(v) for v in (x0, yb, x0, yt + 30, (x0 + x1) / 2, yt - 18, x1, yt + 30)) + " L%s %s Z" % (fm(x1), fm(yb)),
			"#0c1222")
		d.path("M%s %s L%s %s Q%s %s %s %s L%s %s Z" % tuple(fm(v) for v in (x0, yb, x0, yt + 30, (x0 + x1) / 2, yt - 18, x1, yt + 30, x1, yb)), "#0c1222")
	for x in pill:
		yt = wall_y(x, 150, 70)
		yb = wall_y(x, 330, 50)
		d.rect(x - 16, yt, 32, yb - yt, d.lin(x - 16, 0, x + 16, 0, [(0, "#1a2236"), (0.5, "#3a4a66"), (1, "#141a2a")]))
		d.rect(x - 22, yt - 6, 44, 12, "#4a5a7a")
	# hanging banners with crest
	for (bx, by) in [(120, 168), (1160, 168)]:
		d.path("M%s %s L%s %s L%s %s L%s %s L%s %s Z" % tuple(fm(v) for v in (bx - 44, by, bx + 44, by, bx + 44, by + 150, bx, by + 176, bx - 44, by + 150)),
			d.vlin(by, by + 176, [(0, "#5a1430"), (1, "#3a0a20")]))
		d.rect(bx - 50, by - 6, 100, 10, GOLD_D)
		d.spath("M%s %s L%s %s L%s %s" % tuple(fm(v) for v in (bx - 38, by + 4, bx - 38, by + 146, bx, by + 168)), GOLD, 2, opacity=0.7)
		d.spath("M%s %s L%s %s L%s %s" % tuple(fm(v) for v in (bx + 38, by + 4, bx + 38, by + 146, bx, by + 168)), GOLD, 2, opacity=0.7)
		snapjaw_crest(d, bx, by + 74, 0.5)
	# neon trim at the wall base
	d.spath("M" + " L".join("%s %s" % (fm(x), fm(y)) for x, y in bot_pts), AQUA, 4, opacity=0.9)
	d.spath("M" + " L".join("%s %s" % (fm(x), fm(y)) for x, y in bot_pts), AQUA, 14, opacity=0.2)
	# wooden deck ring
	PCX, PCY = 640, 480
	d.ellipse(PCX, PCY + 20, 760, 300, d.vlin(200, 780, [(0, "#3a2a24"), (1, "#5a3a26")]))
	dd = ""
	for k in range(40):
		a = k / 40 * math.tau
		dd += "M%s %s L%s %s " % (fm(PCX + math.cos(a) * 590), fm(PCY + math.sin(a) * 190), fm(PCX + math.cos(a) * 780), fm(PCY + math.sin(a) * 310))
	d.spath(dd, "#24180f", 2, opacity=0.6)
	# pool (glowing turquoise)
	d.ellipse(PCX, PCY, 590, 190, "#0e5a62")
	d.ellipse(PCX, PCY, 590, 190, "none", stroke="#c8a060", stroke_width=10)
	d.ellipse(PCX, PCY, 572, 180, d.rad(PCX, PCY - 20, 560, [(0, "#8ff8ee"), (0.45, "#2bc8c0"), (1, "#0e5a62")]))
	pc = d.clip('<ellipse cx="%d" cy="%d" rx="572" ry="180"/>' % (PCX, PCY))
	with G(d, clip_path=pc):
		dd = ""
		for _ in range(30):
			x, y = rng.uniform(80, 1200), rng.uniform(310, 650)
			ww = rng.uniform(30, 90)
			dd += "M%s %s q%s %s %s 0 q%s %s %s 0 " % (fm(x), fm(y), fm(ww / 4), fm(-6), fm(ww / 2), fm(ww / 4), fm(6), fm(ww / 2))
		d.spath(dd, "#e8ffff", 2, opacity=0.35)
		for (cx, cy, rx, ry) in [(640, 400, 300, 40), (480, 520, 200, 30), (820, 540, 180, 26)]:
			d.ellipse(cx, cy, rx, ry, "#ffffff", opacity=0.1)
	glow(d, PCX, PCY - 40, 520, AQUA, 0.22, ry=220)
	for k in range(24):
		a = k / 24 * math.tau
		x, y = PCX + math.cos(a) * 590, PCY + math.sin(a) * 190
		glow(d, x, y, 14, "#fff2c0", 0.8)
		d.circle(x, y, 3, "#fffbe8")
	steam(d, rng, 200, 330, 1080, 440, 7, 0.06, 90, 150, color="#bff8f0")
	# spotlight beams
	for (x0, x1, tx0, tx1, c, a) in [(560, 600, 520, 760, "#e8ffff", 0.07), (680, 720, 520, 760, "#e8ffff", 0.07), (1060, 1090, 860, 1010, "#ff6a6a", 0.09), (150, 180, 220, 360, "#fff2c8", 0.07)]:
		d.poly([(x0, 0), (x1, 0), (tx1, 460), (tx0, 460)], c, opacity=a)
	# podium ring (15 around the pool; Mochi's own = camera, not drawn)
	pods = []
	for i in range(15):
		th = math.radians(90 + i * 24)
		x = PCX + math.cos(th) * 650
		y = PCY + math.sin(th) * 222
		pods.append((y, i, x))
	pods.sort()
	for (y, i, x) in pods:
		if i == 0:
			continue
		sc = 0.5 + 0.75 * (y - 258) / (702 - 258)
		dim = 0.0
		if (x < 330 or x > 950) and y > 340:
			dim = 0.35
		podium(d, x, y, sc * (1.15 if i == 6 else 1.0), "#8a5a34", emblem=CAST_COLORS[i], memorial=(i == 6), dim=dim)
	# throne island (right of center, keeps x 400-880 calm)
	throne_island(d, 935, 372, 0.6, rng)
	glow(d, PCX, 120, 300, "#5a8aff", 0.10)
	vignette(d, 0.6, "#020308")


def bg_title(d):
	rng = random.Random(131)
	d.rect(0, 0, W, 460, d.vlin(0, 460, [(0, "#060a22"), (0.45, "#141c4a"), (0.8, "#2e2a62"), (1, "#4a3a72")]))
	# stars (sparse in the logo zone)
	dd = ""
	for _ in range(110):
		x, y = rng.uniform(0, W), rng.uniform(0, 330)
		if 290 < x < 990 and 60 < y < 320 and rng.random() < 0.7:
			continue
		dd += "M%s %s l0.1 0 " % (fm(x), fm(y))
	d.spath(dd, "#ffffff", 2.4, opacity=0.75)
	for _ in range(6):
		sparkle(d, rng.choice([rng.uniform(40, 280), rng.uniform(1000, 1240)]), rng.uniform(30, 260), rng.uniform(4, 7), "#ffffff", 0.9)
	# moon
	glow(d, 1080, 150, 360, "#9fb6ff", 0.35)
	glow(d, 1080, 150, 150, "#fff6dc", 0.4)
	d.circle(1080, 150, 66, d.brad([(0, "#fffdf0"), (0.8, "#f6ecc8"), (1, "#e8d8a8")], cx=0.4, cy=0.4))
	for (x, y, r) in [(1060, 132, 12), (1102, 170, 9), (1090, 124, 6), (1058, 178, 7)]:
		d.circle(x, y, r, "#e2d2a0", opacity=0.55)
	# mountains
	d.path("M0 360 L140 300 L260 330 L420 270 L560 320 L700 290 L860 330 L1000 280 L1140 320 L1280 290 L1280 460 L0 460 Z", "#1c2050")
	d.path("M0 400 L180 350 L340 380 L520 340 L700 380 L880 345 L1060 385 L1280 350 L1280 460 L0 460 Z", "#161a40")
	# resort silhouette (left) with lit windows + a red eye on the tower
	d.path("M40 460 L40 330 L20 330 L90 290 L160 330 L140 330 L140 360 L120 360 L190 318 L260 360 L240 360 L240 460 Z", "#0c0e26")
	d.path("M150 300 L150 230 L132 230 L175 200 L218 230 L200 230 L200 300 Z", "#0c0e26")
	d.path("M168 200 L175 176 L182 200 Z", "#0c0e26")
	for (x, y) in [(60, 380), (90, 380), (60, 410), (160, 390), (190, 390), (220, 410), (165, 250), (185, 250)]:
		d.rect(x, y, 14, 12, LANTERN, opacity=0.85)
		glow(d, x + 7, y + 6, 20, LANTERN, 0.5)
	glow(d, 175, 270, 22, RED_EYE, 0.8)
	d.circle(175, 270, 4.5, RED_EYE)
	# bamboo framing
	for (x, w, c) in [(14, 16, "#0a1a1e"), (46, 12, "#0c2024"), (1236, 18, "#0a1a1e"), (1206, 12, "#0c2024")]:
		d.rect(x, 0, w, 520, c)
		dd = ""
		for y in range(30, 520, 70):
			dd += "M%s %s L%s %s " % (fm(x - 2), fm(y), fm(x + w + 2), fm(y))
		d.spath(dd, "#16323a", 3)
	for (x, y, f) in [(30, 90, 1), (60, 200, 1), (1240, 120, -1), (1210, 240, -1), (30, 330, 1)]:
		for k in range(3):
			a = 0.25 + k * 0.35
			d.path("M%s %s q%s %s %s %s q%s %s %s %s Z" % tuple(fm(v) for v in (
				x, y, f * 40, -10 - k * 6, f * 90, 10 + k * 14, f * -40, 0, f * -90, -10 - k * 14)), "#0c2024")
	# hanging lanterns from a branch (top-left)
	d.spath("M0 40 Q160 70 330 52", "#0a0c1e", 8)
	for (x, y) in [(120, 120), (250, 110)]:
		chochin(d, x, y, 0.55, "#e05a3a", lit=True, glow_a=0.5)
	# hot spring
	d.rect(0, 440, W, H - 440, d.vlin(440, H, [(0, "#1e5a74"), (0.4, "#16465e"), (1, "#0c2438")]))
	glow(d, 1060, 470, 120, "#fff6dc", 0.35, ry=30)
	for k in range(9):
		y = 470 + k * 26
		w = 70 + k * 30
		d.ellipse(1060 - k * 18, y, w, 4 + k * 0.6, "#fff6dc", opacity=0.45 - k * 0.04)
	dd = ""
	for _ in range(30):
		x, y = rng.uniform(0, W), rng.uniform(470, 700)
		ww = rng.uniform(30, 80)
		dd += "M%s %s q%s -5 %s 0 " % (fm(x), fm(y), fm(ww / 2), fm(ww))
	d.spath(dd, "#8ad0e0", 1.6, opacity=0.35)
	# rocks rim (back)
	for i in range(14):
		cx = 40 + i * 92 + rng.uniform(-10, 10)
		rock(d, cx, 446 + rng.uniform(-6, 6), rng.uniform(46, 60), rng.uniform(16, 22), rng, "#262844", 0.18)
	stone_lantern(d, 140, 462, 0.75, lit=True, stone="#4a4c66")
	# steam plumes (keep the logo zone mostly clear)
	steam(d, rng, 260, 380, 1020, 470, 12, 0.13, 70, 130)
	for (x, y, r, a) in [(220, 330, 120, 0.12), (1000, 320, 110, 0.1), (640, 360, 140, 0.08), (420, 400, 120, 0.1), (850, 410, 120, 0.1)]:
		d.ellipse(x, y, r * 1.6, r, d.brad([(0, "#e8eeff", a), (1, "#e8eeff", 0)]))
	# capybara silhouettes soaking (rim-lit by the moon)
	for (x, y, s, face, yz, acc) in [(300, 534, 0.72, 1, False, "bow"), (905, 530, 0.78, -1, False, "tophat"), (450, 584, 0.98, 1, False, "captain"),
			(1060, 590, 1.0, -1, False, "headband"), (660, 572, 1.15, 1, True, None)]:
		d.ellipse(x + 10 * face, y + 6, 110 * s, 14 * s, "#06121e", opacity=0.45)
		capy_soak(d, x, y, s, "#0b0f22", rim="#bfd6ff", yuzu_top=yz, face=face, acc=acc)
		d.ellipse(x + 10 * face * s, y + 2, 100 * s, 8 * s, "none", stroke="#a8e0f0", stroke_width=1.6, opacity=0.25)
	# floating yuzu
	for (x, y, r) in [(330, 610, 12), (520, 640, 14), (720, 610, 12), (900, 650, 15), (1120, 600, 12), (160, 660, 14), (680, 680, 16)]:
		yuzu(d, x, y, r, rng.uniform(-30, 30), water=True)
	# foreground rocks + steam
	for (cx, cy, rx, ry) in [(80, 700, 140, 60), (1210, 690, 150, 70)]:
		rock(d, cx, cy, rx, ry, rng, "#14162c", 0.12)
	steam(d, rng, 0, 560, W, 720, 8, 0.08, 100, 180)
	vignette(d, 0.55, "#02030a")



# --------------------------------------------------------------------------------------
# TRUTH DROP ICONS (200x200, transparent)
# --------------------------------------------------------------------------------------
CLUES = ["rules", "snapjaw_file", "coco_watch", "cushion_edge", "bruno_headband", "marigold_account", "cracked_bucket",
	"garden_door", "sauna_log", "cape_thread", "living_statue", "lulu_glitter", "mannequin", "pepper_photo"]
OL = 4.5  # icon outline width

SEG = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abfgcd"}


def seg_digits(d, x, y, h, txt, color, off=None):
	"""7-segment style digits (shapes, not text). (x,y) = top-left, h = digit height."""
	w = h * 0.52
	t = h * 0.14
	cx = x
	for ch in txt:
		if ch == ":":
			d.rect(cx + t * 0.2, y + h * 0.28, t, t, color, rx=t * 0.3)
			d.rect(cx + t * 0.2, y + h * 0.62, t, t, color, rx=t * 0.3)
			cx += t * 1.8
			continue
		segs = {
			"a": (cx + t * 0.6, y, w - t * 1.2, t), "d": (cx + t * 0.6, y + h - t, w - t * 1.2, t), "g": (cx + t * 0.6, y + h / 2 - t / 2, w - t * 1.2, t),
			"f": (cx, y + t * 0.6, t, h / 2 - t * 0.9), "b": (cx + w - t, y + t * 0.6, t, h / 2 - t * 0.9),
			"e": (cx, y + h / 2 + t * 0.3, t, h / 2 - t * 0.9), "c": (cx + w - t, y + h / 2 + t * 0.3, t, h / 2 - t * 0.9),
		}
		for k, (sx, sy, sw_, sh_) in segs.items():
			if k in SEG[ch]:
				d.rect(sx, sy, sw_, sh_, color, rx=t * 0.4)
			elif off:
				d.rect(sx, sy, sw_, sh_, off, rx=t * 0.4)
		cx += w + t * 0.9


def ishadow(d, cx=100, cy=184, rx=62, ry=9):
	d.ellipse(cx, cy, rx, ry, "#000000", opacity=0.25)


def clue_rules(d):
	rng = random.Random(201)
	ishadow(d)
	with G(d, transform="rotate(-6 100 100)"):
		d.rect(42, 22, 116, 156, "#e8d6b0", rx=8, stroke=INK, stroke_width=OL)
		d.rect(48, 28, 104, 144, "#fbf1dc", rx=5)
		d.rect(48, 28, 104, 40, "#2f6b4c", rx=5)
		snapjaw_crest(d, 100, 52, 0.34)
		cols = ["#e8553d", YUZU, "#2bb7b3", "#9a6aff", "#e8553d", "#3a7aa8"]
		for i in range(6):
			y = 80 + i * 15
			d.circle(60, y, 4.5, cols[i], stroke=INK, stroke_width=1.5)
			glyphs(d, 70, y - 6, 74 - (i % 3) * 8, 12, 1, "#5a4a3a", rng, 1.8)
		d.circle(140, 160, 11, "#c0392b", stroke=INK, stroke_width=2.5)
		d.spath("M134 160 l4 4 l8 -8", "#ffe0d0", 2.4)


def clue_snapjaw_file(d):
	rng = random.Random(202)
	ishadow(d)
	d.path("M30 52 L80 52 L90 40 L150 40 Q158 40 158 48 L158 64 Z", "#c9963a", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	with G(d, transform="rotate(5 110 90)"):
		d.rect(58, 30, 100, 120, "#fbf6ea", stroke=INK, stroke_width=3)
		glyphs(d, 70, 100, 76, 36, 3, "#6a5a4a", rng, 1.8)
		d.rect(70, 42, 42, 48, "#cfe6f0", stroke=INK, stroke_width=2.5)
		d.ellipse(91, 74, 14, 11, "#a8552f")
		d.ellipse(91, 64, 14, 5, "#ffffff")
		d.rect(78, 80, 26, 10, "#24306a")
		d.spath("M118 46 L148 46 M118 56 L142 56 M118 66 L146 66", "#6a5a4a", 2.2)
		d.path("M84 36 L98 36 L98 50 L84 50 Z", "none", stroke="#8a8a92", stroke_width=3)
	d.path("M26 60 L162 60 Q170 60 168 68 L156 170 Q155 176 148 176 L36 176 Q30 176 29 170 L20 68 Q19 60 26 60 Z",
		d.vlin(60, 176, [(0, "#f2c66a"), (1, "#d8a040")]), stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.path("M30 66 L158 66", "none", stroke="#fff0c0", stroke_width=3, opacity=0.7)
	with G(d, transform="rotate(-12 70 128)"):
		d.rect(38, 112, 70, 30, "none", stroke="#d0302a", stroke_width=4, rx=4)
		glyphs(d, 46, 118, 54, 18, 1, "#d0302a", rng, 2.6)
	snapjaw_crest(d, 136, 140, 0.32)


def clue_coco_watch(d):
	ishadow(d, 100, 186, 56, 8)
	# chain
	dd = ""
	for k in range(9):
		a = -2.2 + k * 0.22
		x = 100 + math.cos(a) * 70
		y = 92 + math.sin(a) * 70
		dd += "M%s %s a5 3.4 %s 1 0 0.1 0 " % (fm(x), fm(y), fm(math.degrees(a)))
	d.spath(smooth([(100, 26), (70, 20), (40, 34), (26, 62), (30, 92)], False), GOLD_D, 5)
	d.spath(smooth([(100, 26), (70, 20), (40, 34), (26, 62), (30, 92)], False), GOLD, 2.6, stroke_dasharray="6 3")
	d.circle(30, 96, 7, "none", stroke=GOLD, stroke_width=3.5)
	# crown + case
	d.rect(92, 18, 16, 14, GOLD, stroke=INK, stroke_width=3, rx=3)
	d.circle(100, 15, 7, "none", stroke=GOLD_D, stroke_width=3.5)
	d.circle(100, 104, 66, d.brad([(0, "#ffe08a"), (0.7, GOLD), (1, GOLD_D)], cx=0.35, cy=0.3), stroke=INK, stroke_width=OL)
	d.circle(100, 104, 54, "#fbf6e6", stroke=GOLD_D, stroke_width=3)
	# hour ticks
	dd = ""
	for k in range(12):
		a = math.radians(k * 30 - 90)
		r1, r2 = (44, 52) if k % 3 else (40, 52)
		dd += "M%s %s L%s %s " % (fm(100 + math.cos(a) * r1), fm(104 + math.sin(a) * r1), fm(100 + math.cos(a) * r2), fm(104 + math.sin(a) * r2))
	d.spath(dd, "#3a3040", 2.6)
	# anchor emblem
	d.spath("M100 70 L100 86 M94 74 L106 74 M92 82 Q100 90 108 82", "#24306a", 2.2)
	# hands at 9:47
	ha = math.radians((9 + 47 / 60) * 30 - 90)
	ma = math.radians(47 * 6 - 90)
	d.line(100, 104, 100 + math.cos(ha) * 28, 104 + math.sin(ha) * 28, INK, 5)
	d.line(100, 104, 100 + math.cos(ma) * 42, 104 + math.sin(ma) * 42, INK, 3.2)
	d.circle(100, 104, 4.5, "#c0392b")
	# cracked glass
	d.spath("M118 64 L110 88 L126 100 L116 124 M110 88 L92 96 M126 100 L146 96 M116 124 L132 140", "#ffffff", 3.6, opacity=0.95)
	d.spath("M118 64 L110 88 L126 100 L116 124 M110 88 L92 96 M126 100 L146 96 M116 124 L132 140", "#7a8a9a", 1.4)
	d.path("M56 82 Q66 56 92 48 Q72 60 64 86 Z", "#ffffff", opacity=0.55)
	# water drops
	for (x, y, r) in [(160, 52, 6), (172, 74, 4), (38, 150, 5)]:
		d.path("M%s %s Q%s %s %s %s A%s %s 0 1 1 %s %s Q%s %s %s %s Z" % tuple(fm(v) for v in (
			x, y - r * 2, x + r, y - r * 0.4, x + r, y, r, r, x - r, y, x - r, y - r * 0.4, x, y - r * 2)), "#8fe0f0", stroke=INK, stroke_width=2)


def clue_cushion_edge(d):
	rng = random.Random(204)
	ishadow(d, 100, 180, 76, 10)
	rock(d, 100, 140, 78, 40, rng, "#7d8290", 0.25)
	d.path("M30 104 Q26 140 46 146 L154 146 Q174 140 170 104 Z", "#8ab8cc", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.rect(26, 74, 148, 52, d.vlin(74, 126, [(0, "#eef8fc"), (0.6, "#bfe3f0"), (1, "#9ccbe0")]), rx=24, stroke=INK, stroke_width=OL)
	d.rect(40, 80, 120, 12, "#ffffff", rx=6, opacity=0.7)
	d.spath("M42 116 L158 116", "#6a9ab0", 2, stroke_dasharray="6 5")
	d.rect(112, 94, 38, 20, "#fffdf2", rx=3, stroke=INK, stroke_width=2)
	d.spath("M117 105 l5 -4 l5 4 l5 -4 l5 4 l5 -4", "#c0392b", 2)
	d.spath("M60 56 Q64 46 60 36 M100 52 Q104 40 100 28 M140 56 Q144 46 140 36", "#8fd0e8", 4)


def clue_bruno_headband(d):
	ishadow(d, 100, 172, 70, 9)
	d.spath("M40 110 Q40 66 100 64 Q160 66 160 106", "#8f1d1a", 22)
	d.spath("M40 110 Q40 68 100 66 Q160 68 160 106", "#c42a24", 15)
	d.ellipse(100, 112, 64, 30, "none", stroke=INK, stroke_width=28)
	d.ellipse(100, 112, 64, 30, "none", stroke="#e0382f", stroke_width=20)
	d.spath("M52 124 Q100 148 148 124", "#ff9a88", 4, opacity=0.8)
	# knot + tails
	d.spath("M156 116 Q176 138 184 168", INK, 20)
	d.spath("M156 116 Q176 138 184 168", "#e0382f", 13)
	d.spath("M150 120 Q156 150 150 180", INK, 20)
	d.spath("M150 120 Q156 150 150 180", "#c42a24", 13)
	d.blob([(140, 104), (166, 102), (168, 128), (142, 130)], "#d8332c", stroke=INK, stroke_width=OL)
	# white star badge
	sx, sy = 90, 128
	star = []
	for k in range(10):
		a = math.radians(-90 + k * 36)
		r = 11 if k % 2 == 0 else 4.6
		star.append((sx + math.cos(a) * r, sy + math.sin(a) * r))
	d.poly(star, "#ffffff", stroke=INK, stroke_width=2)


def clue_marigold_account(d):
	ishadow(d, 100, 186, 60, 8)
	bubble = "M30 26 L170 26 Q182 26 182 38 L182 126 Q182 138 170 138 L84 138 L54 170 L60 138 L30 138 Q18 138 18 126 L18 38 Q18 26 30 26 Z"
	d.path(bubble, "#fffdf6", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	# night sky + bathhouse door with steam
	d.rect(30, 38, 140, 88, "#24305a", rx=6)
	d.circle(152, 54, 9, "#fff4d6")
	d.rect(92, 58, 52, 68, "#6a4a32", stroke=INK, stroke_width=2.5)
	d.rect(100, 66, 36, 60, "#ffcf7a")
	d.blob([(104, 60), (118, 46), (134, 52), (146, 42), (152, 58), (136, 66)], "#ffffff", opacity=0.75)
	d.blob([(84, 56), (96, 44), (108, 50), (100, 62)], "#ffffff", opacity=0.55)
	# Bruno leaving: big brown head with red headband, steaming
	d.ellipse(70, 104, 28, 24, "#5a3422", stroke=INK, stroke_width=2.5)
	d.circle(52, 84, 6, "#5a3422", stroke=INK, stroke_width=2)
	d.circle(76, 80, 6, "#5a3422", stroke=INK, stroke_width=2)
	d.spath("M44 96 Q70 86 96 96", "#e0382f", 6)
	d.ellipse(84, 112, 12, 9, "#7a4a32")
	d.ellipse(60, 112, 8, 5, "#ff8a7a", opacity=0.8)
	d.spath("M52 70 q-4 -8 2 -14 M66 68 q-4 -8 2 -14", "#ffffff", 3, opacity=0.8)
	# clock 9:56
	d.circle(46, 50, 10, "#fffdf6", stroke=INK, stroke_width=2)
	ha = math.radians((9 + 56 / 60) * 30 - 90)
	ma = math.radians(56 * 6 - 90)
	d.line(46, 50, 46 + math.cos(ha) * 5.5, 50 + math.sin(ha) * 5.5, INK, 2.2)
	d.line(46, 50, 46 + math.cos(ma) * 8, 50 + math.sin(ma) * 8, INK, 1.6)
	# nurse cap badge
	d.path("M120 154 Q148 140 176 154 L172 176 L124 176 Z", "#ffffff", stroke=INK, stroke_width=3.5, stroke_linejoin="round")
	d.rect(144, 156, 8, 18, "#3aa860")
	d.rect(139, 161, 18, 8, "#3aa860")


def clue_cracked_bucket(d):
	rng = random.Random(207)
	ishadow(d, 100, 180, 66, 10)
	# handle (raised bar)
	d.path("M70 66 L70 30 Q70 22 78 22 L122 22 Q130 22 130 30 L130 66 L118 66 L118 34 L82 34 L82 66 Z",
		"#c99a62", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	# bucket body
	d.path("M34 66 L166 66 L152 168 Q100 180 48 168 Z", d.lin(34, 0, 166, 0, [(0, "#b08048"), (0.4, "#f0c88a"), (1, "#a07040")]),
		stroke=INK, stroke_width=OL, stroke_linejoin="round")
	dd = ""
	for k in range(1, 7):
		t = k / 7
		dd += "M%s 70 L%s 166 " % (fm(34 + 132 * t), fm(48 + 104 * t))
	d.spath(dd, "#8a5a30", 2, opacity=0.6)
	for (y, w0) in [(88, 126), (148, 104)]:
		d.path("M%s %s Q100 %s %s %s" % (fm(100 - w0 / 2 - 2), fm(y), fm(y + 8), fm(100 + w0 / 2 + 2), fm(y)), "none", stroke=INK, stroke_width=9)
		d.path("M%s %s Q100 %s %s %s" % (fm(100 - w0 / 2 - 2), fm(y), fm(y + 8), fm(100 + w0 / 2 + 2), fm(y)), "none", stroke="#5a5a62", stroke_width=5)
	d.ellipse(100, 66, 66, 14, "#6a4424", stroke=INK, stroke_width=OL)
	d.ellipse(100, 68, 56, 9, "#4a2e18")
	# dent + crack in the rim
	d.path("M126 56 Q136 66 144 58 L140 72 Q132 76 124 70 Z", "#4a2e18", stroke=INK, stroke_width=2.5)
	d.spath("M134 66 L128 84 L138 96 L130 112", INK, 3.2)
	d.spath("M134 66 L128 84 L138 96 L130 112", "#fff0d8", 1.2)
	# silver-violet glitter on the handle
	dd = ""
	for _ in range(40):
		x = rng.uniform(72, 128)
		y = rng.uniform(22, 36) if rng.random() < 0.6 else rng.uniform(34, 64)
		if 84 < x < 116 and y > 36:
			continue
		dd += "M%s %s l0.1 0 " % (fm(x), fm(y))
	d.spath(dd, "#c8b0ff", 3.6)
	for (x, y, r) in [(80, 20, 9), (118, 28, 7), (126, 50, 8), (74, 48, 6)]:
		sparkle(d, x, y, r, "#f4f0ff", 1.0, glow_c="#9a7aff")


def clue_garden_door(d):
	ishadow(d, 100, 184, 70, 9)
	d.rect(36, 20, 128, 162, "#4a2e1c", stroke=INK, stroke_width=OL, rx=3)
	d.rect(46, 30, 108, 146, d.vlin(30, 176, [(0, "#d8f0ff"), (0.45, "#bfe3c0"), (1, "#7ab86a")]))
	d.blob([(46, 90), (70, 74), (96, 84), (124, 70), (154, 82), (154, 124), (46, 124)], "#5f9e5a")
	d.circle(122, 98, 12, "#d8333f")
	d.circle(104, 104, 8, "#e8506a")
	for (x, y, rx, ry) in [(70, 160, 20, 7), (96, 146, 16, 6), (118, 136, 12, 4.5)]:
		d.ellipse(x, y, rx, ry, "#d8d6cc", stroke=INK, stroke_width=2)
	d.poly([(46, 176), (100, 176), (150, 200), (20, 200)], "#fff8d0", opacity=0.35)
	# sliding door panel pushed right
	d.rect(108, 30, 60, 146, d.vlin(30, 176, [(0, "#c48a52"), (1, "#8a5a30")]), stroke=INK, stroke_width=OL)
	d.rect(118, 42, 40, 50, "#e8eee8", stroke=INK, stroke_width=2.5)
	d.spath("M138 42 L138 92 M118 67 L158 67", INK, 2)
	d.rect(116, 104, 40, 60, "none", stroke="#6a4228", stroke_width=2.5)
	d.rect(110, 92, 7, 28, INK, rx=3)
	# open padlock
	d.rect(54, 120, 30, 26, GOLD, stroke=INK, stroke_width=3, rx=4)
	d.spath("M60 120 L60 108 Q60 98 70 98 Q80 98 80 108", INK, 7)
	d.spath("M60 120 L60 108 Q60 98 70 98 Q80 98 80 108", "#c9ccd4", 3.5)
	d.circle(69, 131, 3.5, INK)


def clue_sauna_log(d):
	ishadow(d, 100, 188, 64, 8)
	d.rect(30, 18, 140, 166, d.vlin(18, 184, [(0, "#b8c0c8"), (1, "#7d8690")]), rx=14, stroke=INK, stroke_width=OL)
	d.rect(42, 32, 116, 96, "#0e2a2a", rx=6, stroke=INK, stroke_width=3)
	d.rect(42, 32, 116, 96, d.brad([(0, "#3fdcc8", 0.35), (1, "#3fdcc8", 0)]), rx=6)
	for (y, txt) in [(44, "9:28"), (86, "9:56")]:
		# door icon
		d.rect(50, y, 18, 28, "none", stroke="#6ff0d8", stroke_width=2.5)
		d.circle(63, y + 15, 2, "#6ff0d8")
		seg_digits(d, 76, y + 1, 26, txt, "#7ff8e0", off="#163a38")
	d.line(48, 80, 152, 80, "#3fdcc8", 1.5, opacity=0.5)
	d.circle(56, 150, 8, "#3fdc6a", stroke=INK, stroke_width=2)
	glow(d, 56, 150, 16, "#3fdc6a", 0.6)
	d.circle(80, 150, 8, "#ff4a3a", stroke=INK, stroke_width=2)
	d.rect(98, 142, 52, 16, "#3a3a40", rx=4)
	d.rect(102, 146, 20, 8, "#6a6a72", rx=2)
	d.path("M44 26 L150 26", "none", stroke="#ffffff", stroke_width=3, opacity=0.6)
	snapjaw_crest(d, 100, 172, 0.15)


def clue_cape_thread(d):
	rng = random.Random(210)
	ishadow(d, 100, 186, 50, 7)
	# thorny stem
	d.spath("M40 186 Q60 120 100 96 Q140 72 160 26", INK, 11)
	d.spath("M40 186 Q60 120 100 96 Q140 72 160 26", "#3f7a46", 6)
	for (x, y, a) in [(56, 148, -30), (82, 110, 40), (118, 86, -40), (146, 54, 30), (66, 128, 150)]:
		with G(d, transform=T(x, y, 1, a)):
			d.path("M0 -4 L16 0 L0 4 Z", "#6a4a2a", stroke=INK, stroke_width=1.6)
	# leaves + rose bud
	for (x, y, a) in [(70, 132, 200), (130, 72, -20)]:
		with G(d, transform=T(x, y, 1, a)):
			d.path("M0 0 Q14 -14 32 0 Q14 14 0 0 Z", "#4f8f52", stroke=INK, stroke_width=2.5)
	d.ellipse(162, 22, 14, 16, "#d8333f", stroke=INK, stroke_width=3)
	d.spath("M154 22 q8 -8 16 0", "#8a1a24", 2)
	# violet thread snagged on the thorn at (118,86)
	thread = smooth([(122, 86), (100, 104), (112, 132), (86, 150), (98, 178)], False)
	d.spath(thread, INK, 10)
	d.spath(thread, "#8a4ad8", 6.5)
	d.spath(thread, "#c8a0ff", 2)
	for (x, y, r) in [(104, 106, 8), (110, 132, 9), (88, 152, 7), (98, 176, 6)]:
		sparkle(d, x, y, r, "#ffffff", 1.0, glow_c="#b090ff")


def clue_living_statue(d):
	ishadow(d, 100, 188, 70, 7)
	d.rect(20, 20, 160, 140, "#2a1428", stroke=INK, stroke_width=OL, rx=4)
	d.poly([(86, 24), (114, 24), (150, 150), (50, 150)], "#fff2c8", opacity=0.25)
	d.ellipse(100, 148, 46, 8, "#fff2c8", opacity=0.4)
	# statue figure (top hat + cape) - perfectly still
	d.path("M74 148 Q72 104 84 88 L116 88 Q128 104 126 148 Z", "#5a2a8a", stroke=INK, stroke_width=3)
	for (x, y) in [(88, 110), (110, 124), (96, 136)]:
		sparkle(d, x, y, 4, "#e6e6ff", 1.0)
	d.ellipse(100, 78, 18, 16, "#3a2616", stroke=INK, stroke_width=3)
	d.rect(84, 60, 32, 6, "#151018", stroke=INK, stroke_width=2)
	d.rect(89, 36, 22, 26, "#1f1a26", stroke=INK, stroke_width=2.5)
	# curtains: left drawn half, right tied
	d.path("M22 22 L84 22 Q80 90 86 158 L22 158 Z", d.lin(22, 0, 84, 0, [(0, "#7a1520"), (0.5, "#c0303a"), (1, "#8a1a24")]), stroke=INK, stroke_width=3)
	d.spath("M36 24 Q34 90 38 156 M54 24 Q52 90 56 156 M70 24 Q68 90 72 156", "#6a1018", 2.5, opacity=0.7)
	d.path("M150 22 L178 22 L178 158 L164 158 Q158 100 150 22 Z", "#b0232f", stroke=INK, stroke_width=3)
	d.rect(20, 18, 160, 14, "#8a1a24", stroke=INK, stroke_width=3)
	# audience heads (4 watchers)
	for (x, c) in [(44, "#c8a870"), (80, "#6a7a3a"), (120, "#b8b0a8"), (156, "#b07a50")]:
		d.ellipse(x, 178, 18, 16, c, stroke=INK, stroke_width=3)
		d.circle(x - 10, 164, 5, c, stroke=INK, stroke_width=2)
		d.circle(x + 10, 164, 5, c, stroke=INK, stroke_width=2)
	d.path("M34 170 L40 160 L46 168 L52 160 L56 170 Z", "#ff6fb8", stroke=INK, stroke_width=1.5)
	d.path("M150 164 L162 164 L160 158 L152 158 Z", "#d8332c")


def clue_lulu_glitter(d):
	rng = random.Random(212)
	ishadow(d, 100, 180, 72, 9)
	d.path("M30 120 Q28 160 46 166 L154 166 Q172 160 170 120 Z", "#5a1024", stroke=INK, stroke_width=OL, stroke_linejoin="round")
	d.rect(24, 82, 152, 58, d.vlin(82, 140, [(0, "#c0304a"), (1, "#7a1a30")]), rx=26, stroke=INK, stroke_width=OL)
	d.rect(40, 88, 120, 12, "#ff8aa0", rx=6, opacity=0.5)
	d.circle(100, 112, 4, "#3a0a18")
	# pink glitter pile
	d.blob([(56, 116), (80, 100), (110, 98), (140, 108), (132, 122), (90, 126)], "#ff7ac0", opacity=0.55)
	dd = ""
	for _ in range(70):
		dd += "M%s %s l0.1 0 " % (fm(rng.uniform(56, 144)), fm(rng.uniform(96, 126)))
	d.spath(dd, "#ffc0e6", 3.4)
	dd = ""
	for _ in range(30):
		dd += "M%s %s l0.1 0 " % (fm(rng.uniform(60, 140)), fm(rng.uniform(98, 124)))
	d.spath(dd, "#ff3a9a", 3)
	for (x, y, r) in [(72, 74, 11), (122, 64, 14), (150, 90, 8), (46, 98, 7), (100, 46, 9)]:
		sparkle(d, x, y, r, "#ffe6f6", 1.0, glow_c="#ff6fb8")
	# little pink bow
	d.path("M150 150 L132 140 L134 162 Z M150 150 L168 140 L166 162 Z", "#ff8ac8", stroke=INK, stroke_width=2.5, stroke_linejoin="round")
	d.circle(150, 151, 5, "#ff5aa8", stroke=INK, stroke_width=2)


def clue_mannequin(d):
	rng = random.Random(213)
	ishadow(d, 100, 188, 50, 7)
	c = "#f4e6cc"
	sh = mix(c, "#b08a60", 0.4)
	d.rect(96, 150, 8, 34, "#9a9aa2", stroke=INK, stroke_width=2)
	d.ellipse(100, 184, 30, 6, "#8a7a6e", stroke=INK, stroke_width=2)
	d.blob([(52, 154), (46, 120), (54, 94), (80, 84), (120, 84), (146, 94), (154, 120), (148, 154), (100, 160)],
		d.lin(46, 0, 154, 0, [(0, sh), (0.45, light(c, 0.3)), (1, sh)]), stroke=INK, stroke_width=OL)
	d.rect(88, 72, 24, 16, sh, stroke=INK, stroke_width=3)
	d.ellipse(70, 26, 10, 9, c, stroke=INK, stroke_width=3)
	d.ellipse(130, 26, 10, 9, c, stroke=INK, stroke_width=3)
	d.blob([(64, 74), (58, 46), (70, 24), (100, 20), (130, 24), (142, 46), (136, 74), (100, 80)],
		d.lin(58, 0, 142, 0, [(0, sh), (0.45, light(c, 0.3)), (1, sh)]), stroke=INK, stroke_width=OL)
	d.ellipse(100, 62, 30, 14, light(c, 0.2))
	d.spath("M90 60 l4 -3 M110 60 l-4 -3", sh, 3)
	# price tag tucked in the collar
	d.spath("M112 88 Q124 100 128 112", "#7a6a5a", 2)
	with G(d, transform="rotate(18 136 122)"):
		d.path("M124 112 L150 112 L150 136 L124 136 L118 124 Z", "#ffffff", stroke=INK, stroke_width=2.5, stroke_linejoin="round")
		d.circle(124, 124, 2.4, "#7a6a5a")
		d.spath("M130 120 L144 120 M130 128 L140 128", "#c0392b", 2)
	# silver-violet glitter on the shoulders
	dd = ""
	for side in (-1, 1):
		for _ in range(26):
			dd += "M%s %s l0.1 0 " % (fm(100 + side * rng.uniform(24, 52)), fm(rng.uniform(86, 104)))
	d.spath(dd, "#c0a8ff", 3.6)
	for (x, y, r) in [(62, 92, 10), (140, 90, 9), (76, 102, 6), (126, 104, 6)]:
		sparkle(d, x, y, r, "#f4f0ff", 1.0, glow_c="#9a7aff")


def clue_pepper_photo(d):
	ishadow(d, 104, 186, 70, 8)
	with G(d, transform="rotate(-7 100 100)"):
		d.rect(26, 18, 150, 164, "#fbf8f0", stroke=INK, stroke_width=OL, rx=4)
		d.rect(38, 30, 126, 112, "#1e1022")
		# flash-lit lounge stage
		d.circle(101, 86, 70, d.brad([(0, "#fff2c8", 0.55), (1, "#fff2c8", 0)]))
		d.path("M38 30 L70 30 Q66 90 72 142 L38 142 Z", "#9a2230")
		d.path("M148 30 L164 30 L164 142 L156 142 Q152 90 148 30 Z", "#9a2230")
		# the "statue": top hat + cape, with a white tag at the collar
		d.path("M80 140 Q78 104 88 92 L114 92 Q124 104 122 140 Z", "#5a2a8a", stroke=INK, stroke_width=2.5)
		d.ellipse(101, 82, 15, 13, "#e8dcc8", stroke=INK, stroke_width=2.5)
		d.rect(86, 66, 30, 5, "#151018")
		d.rect(91, 46, 20, 22, "#1f1a26", stroke=INK, stroke_width=2)
		d.spath("M108 94 L114 104", "#c8c8c8", 1.6)
		d.rect(110, 102, 13, 10, "#ffffff", stroke=INK, stroke_width=1.6)
		d.circle(116.5, 107, 13, "none", stroke=YUZU, stroke_width=3)
		# timestamp 9:46
		seg_digits(d, 120, 124, 13, "9:46", "#ff9a3a")
		d.rect(38, 30, 126, 112, "none", stroke=INK, stroke_width=2.5)
		d.path("M44 36 L88 36 L52 80 Z", "#ffffff", opacity=0.18)
		# camera flash burst corner
	for k in range(8):
		a = math.radians(k * 45)
		d.line(170 + math.cos(a) * 8, 30 + math.sin(a) * 8, 170 + math.cos(a) * 18, 30 + math.sin(a) * 18, YUZU, 4)
	d.circle(170, 30, 7, "#fffbe0", stroke=INK, stroke_width=2)


# ======================================================================================
# MAIN
# ======================================================================================

def bg_bath(d):
	bath_scene(d, morning=False, body=False)


def bg_bath_body(d):
	bath_scene(d, morning=True, body=True)


def read_hotspots():
	"""Parse scripts/data/investigation_data.gd -> {bg_id: [(label, x, y, w, h)]}."""
	path = os.path.join(ROOT, "scripts", "data", "investigation_data.gd")
	out = {}
	cur = None
	try:
		src = open(path, encoding="utf-8").read()
	except OSError:
		return out
	for line in src.splitlines():
		m = re.search(r'"bg":\s*"(\w+)"', line)
		if m:
			cur = m.group(1)
			out.setdefault(cur, [])
		m = re.search(r'"label":\s*"([^"]+)",\s*"rect":\s*\[(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\]', line)
		if m and cur:
			out[cur].append((m.group(1),) + tuple(int(m.group(i)) for i in range(2, 6)))
	return out


def debug_overlay(svg_text, bg_id, hotspots):
	add = []
	# portrait standing zones
	add.append('<rect x="0" y="340" width="330" height="380" fill="#00ffff" fill-opacity="0.10" stroke="#00ffff" stroke-width="2" stroke-dasharray="8 6"/>')
	add.append('<rect x="950" y="340" width="330" height="380" fill="#00ffff" fill-opacity="0.10" stroke="#00ffff" stroke-width="2" stroke-dasharray="8 6"/>')
	if bg_id == "trial":
		add.append('<rect x="400" y="0" width="480" height="720" fill="#ffff00" fill-opacity="0.08" stroke="#ffff00" stroke-width="2" stroke-dasharray="8 6"/>')
	if bg_id == "title":
		add.append('<rect x="290" y="60" width="700" height="260" fill="#ffff00" fill-opacity="0.08" stroke="#ffff00" stroke-width="2" stroke-dasharray="8 6"/>')
	add.append('<rect x="60" y="524" width="1160" height="178" fill="none" stroke="#ffffff" stroke-width="1.5" stroke-dasharray="3 6" opacity="0.6"/>')
	for (label, x, y, w, h) in hotspots.get(bg_id, []):
		add.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#ff00ff" fill-opacity="0.12" stroke="#ff00ff" stroke-width="3"/>' % (x, y, w, h))
	return svg_text.replace("\n</svg>", "\n" + "\n".join(add) + "\n</svg>")


def bg_garden_day(d):
	"""Same garden before the murder (no snagged thread) - used by Day-1 hangouts."""
	bg_garden(d, thread=False)


BGS = ["title", "lobby", "dining", "kitchen", "lounge", "giftshop", "changing", "bath", "bath_body", "sauna", "garden", "garden_day",
	"storage", "hallway", "room", "trial"]


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
	pr_dir = os.path.join(ROOT, "art", "props")
	os.makedirs(bg_dir, exist_ok=True)
	os.makedirs(pr_dir, exist_ok=True)
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
		with open(os.path.join(bg_dir, bid + ".svg"), "w", encoding="utf-8") as f:
			f.write(txt)
		print("bg %-10s %6.1f KB  %d elements" % (bid, len(txt) / 1024.0, txt.count("<") - txt.count("</")))
		if debug_dir:
			with open(os.path.join(debug_dir, "dbg_" + bid + ".svg"), "w", encoding="utf-8") as f:
				f.write(debug_overlay(txt, bid, hs))
	for cid in CLUES if "CLUES" in g else []:
		if only and ("clue_" + cid) not in only and "clues" not in only:
			continue
		fn = g.get("clue_" + cid)
		if fn is None:
			print("  (no icon yet for %s)" % cid)
			continue
		d = Doc(200, 200)
		fn(d)
		txt = d.svg()
		with open(os.path.join(pr_dir, "clue_" + cid + ".svg"), "w", encoding="utf-8") as f:
			f.write(txt)
		print("icon %-16s %5.1f KB" % (cid, len(txt) / 1024.0))


if __name__ == "__main__":
	main()
