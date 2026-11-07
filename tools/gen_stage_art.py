#!/usr/bin/env python3
"""SPLASH TRIAL - layered art for the pseudo-3D trial courtroom (scripts/ui/trial_stage.gd).

Writes art/props/stage_*.svg:
  stage_pano.svg         3000x420  wrapping 360-degree wall strip (arches, pillars, crest banners, lamps)
  stage_podium.svg        330x240  angular wooden podium (front view, anchor = bottom centre)
  stage_throne_back.svg   720x960  rock island + caiman-jaw throne back (Snapjaw sits in front of it)
  stage_throne_front.svg  720x960  seat + armrests drawn over Snapjaw's portrait
  stage_memorial.svg      200x250  frame for Coco's memorial portrait (window left transparent) + dark ribbon
  stage_mochi_back.svg    480x680  Mochi seen from behind (over-the-shoulder shots; body reaches the floor)
  stage_steam.svg         256x256  soft steam puff

Usage (from the project root):  python3 tools/gen_stage_art.py
Only SVG 1.1 basics (no text, filters, images, styles) so Godot's ThorVG rasterizes it.
Self-contained on purpose: no imports from the other generators.
"""
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "art", "props")

# palette (hot-spring night)
NIGHT = "#120a24"
INK = "#07040f"
OUTL = "#2a1a10"
AQUA = "#3ee0d0"
AQUA_D = "#1a8f9e"
YUZU = "#ffb347"
GOLD = "#ffd166"
GOLD_D = "#a8741e"
CORAL = "#ff4f6d"
VIOLET = "#9b6bd6"
CROC_G = "#4f8f52"
CROC_GD = "#2f5e37"
CHROME = "#c3ccd6"
CHROME_D = "#7d8a99"


def fm(v):
	if isinstance(v, float):
		s = "%.2f" % v
		s = s.rstrip("0").rstrip(".")
		return "0" if s in ("-0", "") else s
	return str(v)


def _attrs(kw):
	out = []
	for k, v in kw.items():
		if v is None:
			continue
		out.append('%s="%s"' % (k.replace("_", "-"), fm(v) if isinstance(v, (int, float)) else v))
	return " ".join(out)


def pts(seq):
	return " ".join("%s,%s" % (fm(float(x)), fm(float(y))) for x, y in seq)


def hx(c):
	c = c.lstrip("#")
	return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def to_hex(rgb):
	return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in rgb)


def mix(a, b, t):
	a, b = hx(a), hx(b)
	return to_hex([a[i] + (b[i] - a[i]) * t for i in range(3)])


def dark(c, t):
	return mix(c, "#000000", t)


def light(c, t):
	return mix(c, "#ffffff", t)


class Doc:
	def __init__(self, w, h):
		self.w, self.h = w, h
		self.defs = []
		self.parts = []
		self._n = 0

	def uid(self, p="d"):
		self._n += 1
		return "%s%d" % (p, self._n)

	def add(self, s):
		self.parts.append(s)

	@staticmethod
	def _stops(stops):
		out = []
		for s in stops:
			o, c = s[0], s[1]
			a = s[2] if len(s) > 2 else 1.0
			out.append('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (fm(float(o)), c, fm(float(a))))
		return "".join(out)

	def lin(self, x1, y1, x2, y2, stops):
		i = self.uid("l")
		self.defs.append('<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>'
			% (i, fm(float(x1)), fm(float(y1)), fm(float(x2)), fm(float(y2)), self._stops(stops)))
		return "url(#%s)" % i

	def vlin(self, y1, y2, stops):
		return self.lin(0, y1, 0, y2, stops)

	def rad(self, cx, cy, r, stops):
		i = self.uid("r")
		self.defs.append('<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" r="%s">%s</radialGradient>'
			% (i, fm(float(cx)), fm(float(cy)), fm(float(r)), self._stops(stops)))
		return "url(#%s)" % i

	def brad(self, stops, cx=0.5, cy=0.5, r=0.5):
		i = self.uid("q")
		self.defs.append('<radialGradient id="%s" cx="%s" cy="%s" r="%s">%s</radialGradient>' % (i, cx, cy, r, self._stops(stops)))
		return "url(#%s)" % i

	def clip(self, inner):
		i = self.uid("c")
		self.defs.append('<clipPath id="%s">%s</clipPath>' % (i, inner))
		return "url(#%s)" % i

	def rect(self, x, y, w, h, fill, **kw):
		self.add('<rect %s/>' % _attrs(dict(x=x, y=y, width=w, height=h, fill=fill, **kw)))

	def circle(self, cx, cy, r, fill, **kw):
		self.add('<circle %s/>' % _attrs(dict(cx=cx, cy=cy, r=r, fill=fill, **kw)))

	def ellipse(self, cx, cy, rx, ry, fill, **kw):
		self.add('<ellipse %s/>' % _attrs(dict(cx=cx, cy=cy, rx=rx, ry=ry, fill=fill, **kw)))

	def poly(self, p, fill, **kw):
		kw.setdefault("stroke_linejoin", "round" if kw.get("stroke") else None)
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

	def open(self, **kw):
		self.add("<g %s>" % _attrs(kw))

	def close(self):
		self.add("</g>")

	def svg(self):
		return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n<defs>%s</defs>\n%s\n</svg>\n'
			% (self.w, self.h, self.w, self.h, "\n".join(self.defs), "\n".join(self.parts)))


class G:
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


def glow(d, cx, cy, r, color, a=0.6, ry=None):
	g = d.brad([(0, color, a), (0.45, color, a * 0.4), (1, color, 0)])
	if ry is None:
		d.circle(cx, cy, r, g)
	else:
		d.ellipse(cx, cy, r, ry, g)


def P(*xy):
	"""flat list -> 'x y L x y ...' path"""
	it = list(zip(xy[0::2], xy[1::2]))
	return "M" + " L".join("%s %s" % (fm(float(x)), fm(float(y))) for x, y in it) + " Z"


# --------------------------------------------------------------------------------------
# Warden crest (caiman head in a top hat inside a gold badge), unit radius ~50
# --------------------------------------------------------------------------------------
def crest(d, cx, cy, s=1.0, a=1.0):
	with G(d, transform=T(cx, cy, s), opacity=a if a < 1 else None):
		d.poly([(0, -58), (50, -29), (50, 29), (0, 58), (-50, 29), (-50, -29)], INK, opacity=0.5, transform="translate(6 6)")
		d.poly([(0, -58), (50, -29), (50, 29), (0, 58), (-50, 29), (-50, -29)], d.brad([(0, "#2c5a46"), (1, "#0f2419")]), stroke=GOLD, stroke_width=5)
		d.poly([(0, -49), (42, -24.5), (42, 24.5), (0, 49), (-42, 24.5), (-42, -24.5)], "none", stroke=GOLD_D, stroke_width=1.6)
		head = "M-25 -8 Q-29 -22 -14 -23 L14 -23 Q29 -22 25 -8 L12 28 Q10 36 0 36 Q-10 36 -12 28 Z"
		d.path(head, CROC_G)
		d.path("M0 -23 L14 -23 Q29 -22 25 -8 L12 28 Q10 36 0 36 Z", CHROME)
		d.path("M4 -20 L13 -20 Q22 -18 21 -8 L17 4 Z", "#ffffff", opacity=0.45)
		d.path(head, "none", stroke=OUTL, stroke_width=2.5, stroke_linejoin="round")
		dd = ""
		for side in (-1, 1):
			for k in range(5):
				y0 = -4 + k * 6
				xo = side * (23.5 - k * 2.4)
				dd += "M%s %s L%s %s L%s %s Z " % (fm(xo), fm(y0), fm(xo + side * 4.2), fm(y0 + 3), fm(xo - side * 0.8), fm(y0 + 5.4))
		d.path(dd, "#fffbe8", stroke=OUTL, stroke_width=1)
		d.ellipse(-12, -12, 6, 5, "#f4e04d", stroke=OUTL, stroke_width=1.6)
		d.ellipse(-12, -12, 1.5, 4, OUTL)
		glow(d, 12, -12, 11, CORAL, 0.7)
		d.circle(12, -12, 5, CORAL, stroke=OUTL, stroke_width=1.6)
		d.circle(11, -13.5, 1.5, "#ffe0e6")
		d.ellipse(-4, 30, 2, 1.3, OUTL)
		d.ellipse(4, 30, 2, 1.3, OUTL)
		d.ellipse(0, -24, 27, 5.5, "#151018", stroke=OUTL, stroke_width=2)
		d.path("M-16 -25 L-14 -54 Q0 -58 14 -54 L16 -25 Z", "#1f1a26", stroke=OUTL, stroke_width=2, stroke_linejoin="round")
		d.path("M-15.5 -34 L15.5 -34 L15.8 -27 L-15.8 -27 Z", YUZU)
		d.path("M-10 -51 L-7 -36 L-4 -36 L-6 -52 Z", "#ffffff", opacity=0.18)


# --------------------------------------------------------------------------------------
# 1) WALL PANORAMA  (3000 x 420, wraps at x=0/3000; v=0 is the top of the wall)
# --------------------------------------------------------------------------------------
PW, PH = 3000, 420
BAY = 250


def pano_arch(d, x0, x1, top, bot, rng, glow_c=AQUA, shutter=False):
	cx = (x0 + x1) / 2
	w = x1 - x0
	# angular pointed arch (straight segments - sharp, not round)
	outer = [(x0, bot), (x0, top + 70), (x0 + w * 0.16, top + 24), (cx, top), (x1 - w * 0.16, top + 24), (x1, top + 70), (x1, bot)]
	inner = [(x0 + 12, bot), (x0 + 12, top + 76), (x0 + 12 + w * 0.14, top + 34), (cx, top + 14), (x1 - 12 - w * 0.14, top + 34), (x1 - 12, top + 76), (x1 - 12, bot)]
	d.poly(outer, "#1c1236")
	d.poly([(x + 7, y + 5) for x, y in inner], INK, opacity=0.8)
	d.poly(inner, d.vlin(top, bot, [(0, "#04020a"), (0.55, "#0a0818"), (1, "#0f2430")]))
	# pool glow climbing the recess
	glow(d, cx, bot + 10, w * 0.62, glow_c, 0.42, ry=120)
	if shutter:
		dd = ""
		for y in range(int(top + 90), int(bot - 6), 14):
			dd += "M%s %s L%s %s " % (fm(x0 + 16.0), fm(float(y)), fm(x1 - 16.0), fm(float(y)))
		d.spath(dd, "#2a2440", 3, opacity=0.8)
		d.spath(dd, "#000000", 1, opacity=0.5, transform="translate(0 3)")
	# steam wisps inside
	for _ in range(3):
		sx = rng.uniform(x0 + 30, x1 - 30)
		sy = rng.uniform(top + 120, bot - 40)
		d.ellipse(sx, sy, rng.uniform(26, 46), rng.uniform(12, 20), "#cfeef0", opacity=0.05)
	# gold inner edge + hard rim
	d.pline(inner, GOLD_D, 2.2, opacity=0.85)
	d.pline(outer, INK, 3, opacity=0.9)


def pano_banner(d, cx, top, bot, rng):
	w = 116
	x0, x1 = cx - w / 2, cx + w / 2
	tip = bot + 34
	shape = [(x0, top), (x1, top), (x1, bot), (cx + w * 0.18, bot - 6), (cx, tip), (cx - w * 0.18, bot - 6), (x0, bot)]
	d.poly([(x + 8, y + 6) for x, y in shape], INK, opacity=0.75)
	d.poly(shape, d.lin(x0, 0, x1, 0, [(0, "#22104a"), (0.5, "#3b1f72"), (1, "#1a0c38")]))
	# yuzu diagonal slash band + gold trims
	cp = d.clip('<polygon points="%s"/>' % pts(shape))
	with G(d, clip_path=cp):
		d.poly([(x0 - 10, top + 196), (x1 + 10, top + 150), (x1 + 10, top + 170), (x0 - 10, top + 216)], YUZU, opacity=0.95)
		d.poly([(x0 - 10, top + 224), (x1 + 10, top + 178), (x1 + 10, top + 184), (x0 - 10, top + 230)], AQUA, opacity=0.8)
		# fabric folds
		for k in range(4):
			fx = x0 + 18 + k * 27
			d.rect(fx, top, 9, bot - top + 40, "#000000", opacity=0.12)
	d.pline([(x0 + 9, top + 4), (x0 + 9, bot - 4), (cx - w * 0.16, bot - 10), (cx, tip - 12)], GOLD, 2.2, opacity=0.8)
	d.pline([(x1 - 9, top + 4), (x1 - 9, bot - 4), (cx + w * 0.16, bot - 10), (cx, tip - 12)], GOLD, 2.2, opacity=0.8)
	d.poly(shape, "none", stroke=INK, stroke_width=3)
	# rod
	d.rect(x0 - 14, top - 8, w + 28, 10, GOLD_D, stroke=INK, stroke_width=2)
	d.poly([(x0 - 22, top - 3), (x0 - 12, top - 12), (x0 - 12, top + 6)], GOLD)
	d.poly([(x1 + 22, top - 3), (x1 + 12, top - 12), (x1 + 12, top + 6)], GOLD)
	crest(d, cx, top + 86, 0.62)


def pano_pillar(d, x, top, bot):
	w = 58
	x0 = x - w / 2
	# hard offset shadow
	d.rect(x0 + 8, top, w, bot - top, INK, opacity=0.6)
	# three faces (lit left, front, dark right) - chamfered column
	d.poly([(x0, top + 30), (x0 + 10, top + 22), (x0 + 10, bot - 22), (x0, bot - 30)], "#3a2f5c")
	d.rect(x0 + 10, top + 22, w - 20, bot - top - 44, d.lin(x0 + 10, 0, x0 + w - 10, 0, [(0, "#2a2048"), (0.5, "#1e1638"), (1, "#120c24")]))
	d.poly([(x0 + w - 10, top + 22), (x0 + w, top + 30), (x0 + w, bot - 30), (x0 + w - 10, bot - 22)], "#0a0616")
	# aqua inlay
	d.rect(x - 2, top + 60, 4, bot - top - 120, AQUA, opacity=0.55)
	d.rect(x - 6, top + 60, 12, bot - top - 120, AQUA, opacity=0.1)
	# capital + base (gold, angular)
	d.poly([(x0 - 12, top + 4), (x0 + w + 12, top + 4), (x0 + w, top + 30), (x0, top + 30)], d.vlin(top, top + 30, [(0, GOLD), (1, GOLD_D)]), stroke=INK, stroke_width=2.5)
	d.poly([(x0, bot - 30), (x0 + w, bot - 30), (x0 + w + 12, bot), (x0 - 12, bot)], d.vlin(bot - 30, bot, [(0, "#2a2048"), (1, "#0c0818")]), stroke=INK, stroke_width=2.5)
	d.line(x0 - 4, bot - 30, x0 + w + 4, bot - 30, GOLD_D, 2.5)


def gen_pano():
	d = Doc(PW, PH)
	rng = random.Random(4242)
	# stone wall
	d.rect(0, 0, PW, PH, d.vlin(0, PH, [(0, "#06030d"), (0.18, "#0c0719"), (0.62, "#170f2e"), (0.9, "#22183f"), (1, "#0d0a1c")]))
	# masonry: staggered angular blocks (very low contrast)
	dd = ""
	for row, y in enumerate(range(70, 380, 34)):
		off = 0 if row % 2 == 0 else 60
		dd += "M0 %d L%d %d " % (y, PW, y)
		for x in range(off, PW + 1, 120):
			dd += "M%d %d L%d %d " % (x, y, x, y + 34)
	d.spath(dd, "#000000", 2, opacity=0.25)
	d.spath(dd, "#ffffff", 1, opacity=0.025, transform="translate(0 2)")
	# caustic light band on the lower wall (reflected pool light)
	dd = ""
	for _ in range(70):
		x = rng.uniform(0, PW - 80)
		y = rng.uniform(250, 370)
		ww = rng.uniform(40, 110)
		dd += "M%s %s q%s %s %s 0 q%s %s %s 0 " % (fm(x), fm(y), fm(ww / 4), fm(-7), fm(ww / 2), fm(ww / 4), fm(7), fm(ww / 2))
	d.spath(dd, AQUA, 2.2, opacity=0.09)
	d.rect(0, 230, PW, 160, d.vlin(230, 390, [(0, AQUA, 0), (1, AQUA, 0.12)]))
	# bays
	kinds = ["banner", "arch", "crest", "arch"] * 3
	for k in range(12):
		x0 = k * BAY + 29
		x1 = (k + 1) * BAY - 29
		cx = k * BAY + BAY / 2
		kind = kinds[k]
		if kind == "banner":
			pano_arch(d, x0 + 6, x1 - 6, 120, 382, rng, AQUA, shutter=True)
			pano_banner(d, cx, 84, 300, rng)
		elif kind == "crest":
			pano_arch(d, x0 + 10, x1 - 10, 150, 382, rng, CORAL, shutter=True)
			glow(d, cx, 112, 70, CORAL, 0.35)
			crest(d, cx, 112, 0.58)
		else:
			pano_arch(d, x0, x1, 100, 382, rng, AQUA)
			# caged lantern in the arch
			glow(d, cx, 210, 46, YUZU, 0.45)
			d.poly([(cx - 12, 196), (cx + 12, 196), (cx + 16, 226), (cx - 16, 226)], "#ffe2a8", stroke=INK, stroke_width=3)
			d.line(cx, 140, cx, 196, INK, 2)
			d.poly([(cx - 18, 190), (cx + 18, 190), (cx, 178)], INK)
	for k in range(13):
		pano_pillar(d, k * BAY, 56, 392)
	# cornice + lamp row
	d.rect(0, 0, PW, 46, d.vlin(0, 46, [(0, "#030108"), (1, "#0b0618")]))
	d.rect(0, 44, PW, 5, GOLD_D, opacity=0.9)
	# chevron frieze (angular accent)
	dd = ""
	for x in range(0, PW, 30):
		dd += "M%d 50 L%d 60 L%d 50 " % (x, x + 15, x + 30)
	d.spath(dd, "#3a2a66", 3, opacity=0.9)
	for x in range(0, PW, 125):
		lx = x + 62.5
		glow(d, lx, 24, 34, AQUA, 0.55)
		d.poly([(lx - 7, 24), (lx, 15), (lx + 7, 24), (lx, 33)], "#e8ffff")
	# baseboard + neon trim
	d.rect(0, 392, PW, 28, d.vlin(392, 420, [(0, "#0c0818"), (1, "#05030a")]))
	d.rect(0, 388, PW, 4, AQUA, opacity=0.95)
	d.rect(0, 378, PW, 24, d.vlin(378, 402, [(0, AQUA, 0), (0.5, AQUA, 0.25), (1, AQUA, 0)]))
	dd = ""
	for x in range(0, PW, 40):
		dd += "M%d 420 L%d 396 " % (x, x + 24)
	d.spath(dd, "#2a1f4a", 5, opacity=0.8, stroke_linecap="butt")
	return d.svg()


# --------------------------------------------------------------------------------------
# 2) PODIUM  (330 x 240, anchor bottom centre; front lip at y 36)
# --------------------------------------------------------------------------------------
def gen_podium():
	d = Doc(330, 240)
	front = [(14, 38), (316, 38), (304, 206), (282, 232), (48, 232), (26, 206)]
	# hard offset shadow
	d.poly([(x + 9, y + 6) for x, y in front], INK, opacity=0.7)
	# slanted top lid (seen slightly from above)
	lid = [(4, 40), (326, 40), (306, 8), (24, 8)]
	d.poly(lid, d.vlin(8, 40, [(0, "#4a2c1a"), (1, "#8a5a34")]))
	d.poly([(24, 8), (306, 8), (300, 14), (30, 14)], AQUA, opacity=0.75)
	d.poly(lid, "none", stroke=INK, stroke_width=5)
	# front panel - dark lacquered wood
	d.poly(front, d.lin(14, 0, 316, 0, [(0, "#24140c"), (0.18, "#4e3020"), (0.5, "#6a4228"), (0.82, "#4e3020"), (1, "#1c0f08")]))
	cp = d.clip('<polygon points="%s"/>' % pts(front))
	with G(d, clip_path=cp):
		# wood grain
		dd = ""
		rng = random.Random(77)
		for k in range(14):
			x = 30 + k * 20 + rng.uniform(-4, 4)
			dd += "M%s 40 Q%s 130 %s 232 " % (fm(x), fm(x + rng.uniform(-8, 8)), fm(x + rng.uniform(-6, 6)))
		d.spath(dd, "#000000", 2, opacity=0.18)
		# diagonal light slash across the panel
		d.poly([(180, 38), (226, 38), (128, 232), (82, 232)], "#ffffff", opacity=0.06)
		d.poly([(238, 38), (252, 38), (154, 232), (140, 232)], "#ffffff", opacity=0.05)
		# lower stripe band (yuzu / night stripes)
		d.rect(0, 176, 330, 20, NIGHT)
		dd = ""
		for x in range(-20, 340, 22):
			dd += "M%d 196 L%d 176 " % (x, x + 14)
		d.spath(dd, YUZU, 7, opacity=0.85, stroke_linecap="butt")
		d.rect(0, 174, 330, 3, GOLD)
		d.rect(0, 195, 330, 3, GOLD)
	# nameplate recess (skewed parallelogram) - the stage paints the cast colour inside
	plate = [(92, 64), (262, 64), (240, 132), (70, 132)]
	d.poly([(x + 6, y + 5) for x, y in plate], INK, opacity=0.7)
	d.poly(plate, "#140b26", stroke=GOLD, stroke_width=3.5)
	# aqua droplet emblem
	d.path("M165 140 Q150 160 152 168 Q154 178 165 178 Q176 178 178 168 Q180 160 165 140 Z", AQUA, stroke=INK, stroke_width=3)
	d.ellipse(160, 165, 3.5, 5, "#ffffff", opacity=0.7)
	# gold front lip + outline
	d.poly([(4, 36), (326, 36), (322, 46), (8, 46)], d.vlin(36, 46, [(0, GOLD), (1, GOLD_D)]), stroke=INK, stroke_width=2.5)
	d.poly(front, "none", stroke=INK, stroke_width=5, stroke_linejoin="round")
	# cut-corner bevel highlights
	d.line(28, 206, 48, 228, "#ffffff", 2, opacity=0.25)
	d.line(302, 206, 282, 228, "#000000", 2, opacity=0.4)
	return d.svg()


# --------------------------------------------------------------------------------------
# 3) THRONE (720 x 960, anchor bottom centre = waterline of the rock island)
# --------------------------------------------------------------------------------------
TW, TH = 720, 960


def facet_rock(d, cx, cy, rx, ry, rng, base="#2a2238"):
	n = 7
	p = []
	for k in range(n):
		a = math.pi + k / (n - 1) * math.pi
		r = 1.0 + rng.uniform(-0.12, 0.1)
		p.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
	p.append((cx + rx * 0.9, cy + ry * 0.25))
	p.append((cx - rx * 0.9, cy + ry * 0.25))
	d.poly(p, d.vlin(cy - ry, cy + ry * 0.3, [(0, light(base, 0.12)), (1, dark(base, 0.5))]), stroke=INK, stroke_width=3)
	# lit facet
	top = p[2:5]
	d.poly([top[0], top[1], top[2], (cx, cy - ry * 0.2)], "#ffffff", opacity=0.07)
	# wet aqua rim highlight
	d.pline(p[1:6], AQUA, 2.5, opacity=0.45)


def gen_throne_back():
	d = Doc(TW, TH)
	rng = random.Random(9)
	cx = TW / 2
	# glow + ominous coral aura behind the throne
	glow(d, cx, 360, 360, CORAL, 0.18)
	glow(d, cx, 520, 300, VIOLET, 0.18)
	# water shadow + foam ring
	d.ellipse(cx, 930, 340, 34, "#04161c", opacity=0.6)
	# rocks (back row)
	for (dx, dy, rx, ry) in [(-210, 870, 120, 70), (200, 874, 130, 66), (-90, 852, 140, 84), (100, 850, 140, 80), (0, 826, 160, 70)]:
		facet_rock(d, cx + dx, dy, rx, ry, rng)
	# stone dais steps (angular)
	d.poly([(cx - 250, 800), (cx + 250, 800), (cx + 220, 760), (cx - 220, 760)], d.vlin(760, 800, [(0, "#3a2f5c"), (1, "#17102c")]), stroke=INK, stroke_width=4)
	d.poly([(cx - 210, 760), (cx + 210, 760), (cx + 186, 726), (cx - 186, 726)], d.vlin(726, 760, [(0, "#463a6c"), (1, "#211838")]), stroke=INK, stroke_width=4)
	d.line(cx - 220, 760, cx + 220, 760, GOLD, 3)
	d.line(cx - 250, 800, cx + 250, 800, AQUA, 3, opacity=0.7)
	# throne back slab - an upper caiman jaw arching over the seat
	back = [(cx - 190, 730), (cx - 205, 330), (cx - 170, 170), (cx - 90, 90), (cx, 60), (cx + 90, 90), (cx + 170, 170), (cx + 205, 330), (cx + 190, 730)]
	d.poly([(x + 12, y + 8) for x, y in back], INK, opacity=0.7)
	d.poly(back, d.lin(cx - 205, 0, cx + 205, 0, [(0, "#140a26"), (0.5, "#2e1a52"), (1, "#0e0720")]), stroke=INK, stroke_width=6)
	# inner panel (deep night with violet glow lines)
	inner = [(cx - 140, 720), (cx - 150, 340), (cx - 122, 220), (cx - 60, 160), (cx, 142), (cx + 60, 160), (cx + 122, 220), (cx + 150, 340), (cx + 140, 720)]
	d.poly(inner, d.vlin(140, 720, [(0, "#1a0f30"), (1, "#07040f")]), stroke=GOLD, stroke_width=4)
	# violet halo behind the Warden's head so his dark suit reads against the slab
	cpi = d.clip('<polygon points="%s"/>' % pts(inner))
	with G(d, clip_path=cpi):
		glow(d, cx, 380, 230, VIOLET, 0.55)
		glow(d, cx, 380, 120, "#d6b8ff", 0.25)
		dd = ""
		for k in range(12):
			a = math.pi * (0.05 + 0.9 * k / 11)
			dd += "M%s %s L%s %s " % (fm(cx), fm(400.0), fm(cx - math.cos(a) * 320), fm(400 - math.sin(a) * 320))
		d.spath(dd, VIOLET, 6, opacity=0.18, stroke_linecap="butt")
	for k, off in enumerate((22, 44)):
		pp = [(cx - 140 + off, 720), (cx - 150 + off, 340 + off * 0.4), (cx - 122 + off * 0.8, 220 + off * 0.5), (cx - 60 + off * 0.3, 160 + off * 0.8),
			(cx, 142 + off), (cx + 60 - off * 0.3, 160 + off * 0.8), (cx + 122 - off * 0.8, 220 + off * 0.5), (cx + 150 - off, 340 + off * 0.4), (cx + 140 - off, 720)]
		d.pline(pp, VIOLET, 2.5, opacity=0.45 - k * 0.15)
	# jaw teeth along the arch (pointing inward/down)
	dd = ""
	edge = [(cx - 150, 340), (cx - 122, 220), (cx - 60, 160), (cx, 142), (cx + 60, 160), (cx + 122, 220), (cx + 150, 340)]
	for i in range(len(edge) - 1):
		(ax, ay), (bx, by) = edge[i], edge[i + 1]
		for k in range(2):
			t0 = k / 2
			t1 = (k + 1) / 2
			x0, y0 = ax + (bx - ax) * t0, ay + (by - ay) * t0
			x1, y1 = ax + (bx - ax) * t1, ay + (by - ay) * t1
			mx, my = (x0 + x1) / 2, (y0 + y1) / 2
			# inward normal (towards the panel centre)
			nx, ny = cx - mx, 430 - my
			ln = math.hypot(nx, ny)
			nx, ny = nx / ln * 30, ny / ln * 30
			dd += "M%s %s L%s %s L%s %s Z " % (fm(x0), fm(y0), fm(mx + nx), fm(my + ny), fm(x1), fm(y1))
	d.path(dd, "#fff6dc", stroke=INK, stroke_width=3, stroke_linejoin="round")
	# crown spikes on the outer edge
	dd = ""
	for (x, y, h) in [(cx - 170, 170, 46), (cx - 90, 90, 60), (cx, 60, 78), (cx + 90, 90, 60), (cx + 170, 170, 46)]:
		dd += "M%s %s L%s %s L%s %s Z " % (fm(x - 22), fm(y + 8), fm(x), fm(y - h), fm(x + 22), fm(y + 8))
	d.path(dd, d.vlin(0, 180, [(0, GOLD), (1, GOLD_D)]), stroke=INK, stroke_width=3)
	# coral eye-jewels on the jaw
	for x in (cx - 172, cx + 172):
		glow(d, x, 262, 40, CORAL, 0.6)
		d.poly([(x, 244), (x + 14, 262), (x, 280), (x - 14, 262)], CORAL, stroke=INK, stroke_width=3)
		d.poly([(x - 2, 250), (x + 5, 258), (x - 4, 262)], "#ffe0e6", opacity=0.8)
	crest(d, cx, 112, 0.6)
	# gold edge
	d.pline(back, GOLD, 4)
	return d.svg()


def gen_throne_front():
	d = Doc(TW, TH)
	cx = TW / 2
	# seat cushion front (angular, violet velvet, gold piping)
	seat = [(cx - 170, 640), (cx + 170, 640), (cx + 186, 676), (cx + 170, 726), (cx - 170, 726), (cx - 186, 676)]
	d.poly([(x + 8, y + 6) for x, y in seat], INK, opacity=0.6)
	d.poly(seat, d.vlin(640, 726, [(0, "#5a2f9a"), (0.5, "#3a1d66"), (1, "#1c0d38")]), stroke=INK, stroke_width=5)
	d.pline([(cx - 172, 650), (cx + 172, 650)], GOLD, 3)
	dd = ""
	for x in range(int(cx - 150), int(cx + 160), 50):
		dd += "M%d 660 L%d 716 " % (x, x + 18)
	d.spath(dd, "#000000", 4, opacity=0.25)
	# armrests: angular blocks ending in claw tips
	for side in (-1, 1):
		x_in = cx + side * 150
		x_out = cx + side * 236
		arm = [(x_in, 520), (x_out, 506), (x_out + side * 10, 560), (x_out, 740), (x_in, 740)]
		d.poly([(x + 8, y + 6) for x, y in arm], INK, opacity=0.6)
		d.poly(arm, d.lin(min(x_in, x_out), 0, max(x_in, x_out), 0, [(0, "#2a1a4a"), (1, "#120a24")] if side < 0 else [(0, "#120a24"), (1, "#2a1a4a")]),
			stroke=INK, stroke_width=5)
		# gold cap
		cap = [(x_in - side * 6, 512), (x_out + side * 4, 496), (x_out + side * 16, 524), (x_in - side * 6, 536)]
		d.poly(cap, d.vlin(496, 536, [(0, GOLD), (1, GOLD_D)]), stroke=INK, stroke_width=3)
		# claws
		dd = ""
		for k in range(3):
			bx = x_out + side * (8 - k * 2)
			by = 540 + k * 16
			dd += "M%s %s L%s %s L%s %s Z " % (fm(bx), fm(by), fm(bx + side * 18), fm(by + 6), fm(bx), fm(by + 12))
		d.path(dd, "#fff6dc", stroke=INK, stroke_width=2.5)
		# aqua inlay
		d.line(x_in + side * 30, 560, x_in + side * 30, 720, AQUA, 3, opacity=0.6)
	return d.svg()


# --------------------------------------------------------------------------------------
# 4) MEMORIAL FRAME (200 x 250): window (24..176 x 24..196) transparent for Coco's portrait
# --------------------------------------------------------------------------------------
def gen_memorial():
	d = Doc(200, 250)
	# easel legs
	d.line(60, 200, 40, 248, "#3a2214", 8)
	d.line(140, 200, 160, 248, "#3a2214", 8)
	d.line(100, 200, 100, 246, "#2a160c", 6)
	outer = "M14 0 L186 0 L200 14 L200 206 L186 220 L14 220 L0 206 L0 14 Z"
	win = "M24 24 L24 196 L176 196 L176 24 Z"
	d.path(outer + " " + win, INK, opacity=0.7, fill_rule="evenodd", transform="translate(7 6)")
	d.path(outer + " " + win, d.lin(0, 0, 200, 220, [(0, GOLD), (0.5, GOLD_D), (1, "#6a4a14")]), fill_rule="evenodd", stroke=INK, stroke_width=4)
	d.path("M18 18 L182 18 L182 202 L18 202 Z M24 24 L24 196 L176 196 L176 24 Z", "#5a3a0a", fill_rule="evenodd", opacity=0.7)
	# dark mourning ribbon draped across the top-left corner, coral-red tape edge
	band = [(0, 70), (70, 0), (112, 0), (0, 112)]
	d.poly([(x + 5, y + 5) for x, y in band], INK, opacity=0.6)
	d.poly(band, d.lin(0, 0, 100, 100, [(0, "#1a1030"), (1, "#07040f")]), stroke=INK, stroke_width=3)
	d.line(4, 72, 72, 4, CORAL, 4, stroke_linecap="butt")
	d.line(4, 108, 108, 4, CORAL, 4, stroke_linecap="butt")
	# little bow
	d.poly([(56, 56), (30, 38), (38, 70)], "#140a26", stroke=INK, stroke_width=2.5)
	d.poly([(56, 56), (74, 30), (82, 64)], "#140a26", stroke=INK, stroke_width=2.5)
	d.circle(56, 56, 7, "#22143e", stroke=INK, stroke_width=2.5)
	# glass glint
	d.poly([(150, 30), (170, 30), (100, 190), (80, 190)], "#ffffff", opacity=0.08)
	return d.svg()


# --------------------------------------------------------------------------------------
# 5) MOCHI FROM BEHIND (480 x 680) for over-the-shoulder shots - same head placement as the
#    480x600 portraits, but the hoodie continues down to the floor line (y 680)
# --------------------------------------------------------------------------------------
def gen_mochi_back():
	d = Doc(480, 680)
	FUR = "#d0965a"
	SHADE = "#ae733f"
	HOODIE = "#f28a2e"
	# shoulders / hoodie back
	body = "M20 680 L-6 420 Q10 330 120 312 L360 312 Q470 330 486 420 L460 680 Z"
	d.path(body, d.vlin(300, 680, [(0, HOODIE), (0.75, dark(HOODIE, 0.35)), (1, dark(HOODIE, 0.6))]), stroke=OUTL, stroke_width=6, stroke_linejoin="round")
	d.path("M40 640 L440 640 L456 680 L24 680 Z", dark(HOODIE, 0.55))
	d.spath("M40 640 L440 640", OUTL, 4, opacity=0.6)
	# hood lying on the back (angular fold)
	hood = "M130 330 L350 330 L330 440 L240 486 L150 440 Z"
	d.path(hood, dark(HOODIE, 0.12), stroke=OUTL, stroke_width=5, stroke_linejoin="round")
	d.path("M160 346 L320 346 L306 424 L240 458 L174 424 Z", dark(HOODIE, 0.45), opacity=0.85)
	d.spath("M240 486 L240 636", dark(HOODIE, 0.45), 4, opacity=0.6)
	# towel around the neck
	d.path("M110 318 Q240 352 370 318 L376 346 Q240 384 104 346 Z", "#fdfcf6", stroke=OUTL, stroke_width=5)
	d.spath("M118 334 Q240 366 362 334", "#79c3ea", 5, opacity=0.9)
	# head (boxy-round, seen from behind)
	head = "M240 60 Q352 58 372 150 Q388 238 350 296 Q300 336 240 336 Q180 336 130 296 Q92 238 108 150 Q128 58 240 60 Z"
	for (ex, ey) in ((150, 92), (330, 92)):
		d.circle(ex, ey, 30, FUR, stroke=OUTL, stroke_width=6)
		d.circle(ex, ey, 15, dark(FUR, 0.25))
	d.path(head, d.vlin(60, 336, [(0, FUR), (0.65, FUR), (1, SHADE)]), stroke=OUTL, stroke_width=6, stroke_linejoin="round")
	# cel shade on the back of the head (lit from the upper right) + nape
	d.path("M240 62 Q140 62 112 150 Q96 236 132 294 Q182 336 240 336 Q196 300 186 220 Q180 120 240 62 Z", SHADE, opacity=0.75)
	d.path("M150 280 Q240 318 330 280 Q300 330 240 334 Q180 330 150 280 Z", dark(SHADE, 0.2), opacity=0.6)
	d.path("M300 96 Q350 120 356 170 Q340 140 300 120 Z", "#ffffff", opacity=0.22)
	# yuzu on top (mirrored from the front view)
	cx, cy, r = 226, 54, 32
	g = d.brad([(0, "#fff6a0"), (0.45, "#ffd23c"), (1, "#f2961a")], cx=0.36, cy=0.32, r=0.72)
	d.circle(cx, cy, r, g, stroke=OUTL, stroke_width=5.5)
	d.ellipse(cx - 10, cy - 12, 9, 6, "#ffffff", opacity=0.7)
	d.path("M%d %d Q%d %d %d %d Q%d %d %d %d Z" % (cx - 4, cy - r - 6, cx - 18, cy - r - 24, cx - 44, cy - r - 12, cx - 28, cy - r + 2, cx - 4, cy - r - 6),
		"#5dbb4c", stroke=OUTL, stroke_width=3.5)
	# yuzu-orange rim light (spotlight from the right)
	d.spath("M360 120 Q384 210 352 292", YUZU, 7, opacity=0.65)
	d.spath("M462 430 Q482 520 470 640", YUZU, 7, opacity=0.5)
	return d.svg()


# --------------------------------------------------------------------------------------
# 6) STEAM PUFF (256 x 256)
# --------------------------------------------------------------------------------------
def gen_steam():
	d = Doc(256, 256)
	for (x, y, r, a) in [(128, 140, 110, 0.45), (92, 120, 70, 0.35), (166, 116, 76, 0.35), (128, 92, 60, 0.3)]:
		d.circle(x, y, r, d.brad([(0, "#ffffff", a), (0.55, "#ffffff", a * 0.45), (1, "#ffffff", 0)]))
	return d.svg()


ART = {
	"stage_pano": gen_pano,
	"stage_podium": gen_podium,
	"stage_throne_back": gen_throne_back,
	"stage_throne_front": gen_throne_front,
	"stage_memorial": gen_memorial,
	"stage_mochi_back": gen_mochi_back,
	"stage_steam": gen_steam,
}


def main():
	os.makedirs(OUT_DIR, exist_ok=True)
	for name, fn in ART.items():
		path = os.path.join(OUT_DIR, name + ".svg")
		with open(path, "w") as f:
			f.write(fn())
		imp = path + ".import"
		if not os.path.exists(imp):
			with open(imp, "w") as f:
				f.write('[remap]\n\nimporter="keep"\n')
		print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
	main()
