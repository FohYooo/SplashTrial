#!/usr/bin/env python3
"""SPLASH TRIAL - Chapter 2 execution art ("THE ENDLESS LULLABY").

Writes art/props/lx_*.svg - the props for scripts/screens/execution2_screen.gd:
  lx_cave          the Lower Lake cavern at night (1280x720 backdrop: stalactites, dim fungus, far shore, black water)
  lx_stern         the Mudlark's stern (1280x720 layer: hull, deck house, Snapjaw crane, far wheel beam)
  lx_stern_fg      what stands in front of the paddle wheel (near outrigger beam, bearing, hog rod, camera)
  lx_wheel         the stern paddle wheel (600x600, rotated in code) + lx_wheel_stain (its dark-red stains)
  lx_cradle_back / lx_quilt / lx_quilt_empty / lx_cradle_front / lx_cradle_crack   the giant hanging cradle (layered)
  lx_mob_front / lx_mob_side / lx_mob_back   the tiny Snapjaw heads of the cradle mobile
  lx_lantern, lx_eye, lx_snap_sil, lx_standby, lx_key, lx_gear, lx_gearbox, lx_nightcap

Usage (from the project root):  python3 tools/gen_exec2_art.py
Only SVG 1.1 basics are used (no text / filters / images / CSS) so Godot's ThorVG rasterizes it.
The geometry constants marked "shared with execution2_screen.gd" must stay in sync with the screen.
"""
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "props")
TAU = math.pi * 2

# ---- shared with execution2_screen.gd ---------------------------------------------------------
# cradle sprites: 600x740, the chain ring sits at svg (300, 0) = cradle-local origin
CR_W, CR_H = 600, 740
CR_RAIL_Y = 404          # top of the front rail (Tumble's chin rests just above it)
# wheel: 600x600, hub at (300, 300), 12 paddles at k*30 degrees, paddle boards r 200..296
WH = 600
WH_N = 12
WH_R0, WH_R1 = 200, 296
# ext layout (world px): wheel hub, crane pulley, waterline
WHEEL_C = (812, 380)
PIVOT = (340, 66)
WATER_Y = 548

BLOOD = "#7a0010"
BLOOD_D = "#3a0008"
BLOOD_H = "#b3001b"
INK = "#1a120c"
IRON = "#24282a"
IRON_H = "#6e777a"
PAINT = "#8ca59e"        # faded teal-white cradle paint
PAINT_S = "#64807a"
PAINT_D = "#3e5552"
WOOD = "#6b4a30"
WOOD_D = "#3a281a"


# ------------------------------------------------------------------ tiny toolkit
def f(v):
	if isinstance(v, float):
		if abs(v - round(v)) < 0.01:
			return str(int(round(v)))
		return "%.2f" % v
	return str(v)


def pts(seq):
	return " ".join("%s,%s" % (f(float(x)), f(float(y))) for x, y in seq)


def svg(w, h, body, defs=""):
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
		'<defs>%s</defs>\n%s\n</svg>\n') % (w, h, w, h, defs, body)


def stops(seq):
	out = []
	for s in seq:
		off, col = s[0], s[1]
		op = s[2] if len(s) > 2 else 1.0
		out.append('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (f(float(off)), col, f(float(op))))
	return "".join(out)


def lin(gid, x1, y1, x2, y2, seq, user=False):
	u = ' gradientUnits="userSpaceOnUse"' if user else ""
	return '<linearGradient id="%s" x1="%s" y1="%s" x2="%s" y2="%s"%s>%s</linearGradient>' % (
		gid, f(x1), f(y1), f(x2), f(y2), u, stops(seq))


def rad(gid, cx, cy, r, seq, user=False, fx=None, fy=None):
	u = ' gradientUnits="userSpaceOnUse"' if user else ""
	fo = ' fx="%s" fy="%s"' % (f(fx), f(fy)) if fx is not None else ""
	return '<radialGradient id="%s" cx="%s" cy="%s" r="%s"%s%s>%s</radialGradient>' % (
		gid, f(cx), f(cy), f(r), fo, u, stops(seq))


def poly(p, fill, op=1.0, stroke=None, sw=0):
	o = ' opacity="%s"' % f(op) if op < 1.0 else ""
	s = ' stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (stroke, f(sw)) if stroke else ""
	return '<polygon points="%s" fill="%s"%s%s/>' % (pts(p), fill, s, o)


def path(d, fill="none", stroke=None, sw=0, op=1.0, extra=""):
	o = ' opacity="%s"' % f(op) if op < 1.0 else ""
	s = ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (stroke, f(sw)) if stroke else ""
	return '<path d="%s" fill="%s"%s%s%s/>' % (d, fill, s, o, extra)


def rect(x, y, w, h, fill, op=1.0, rx=0, stroke=None, sw=0, tr=""):
	o = ' opacity="%s"' % f(op) if op < 1.0 else ""
	r = ' rx="%s"' % f(rx) if rx else ""
	s = ' stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (stroke, f(sw)) if stroke else ""
	t = ' transform="%s"' % tr if tr else ""
	return '<rect x="%s" y="%s" width="%s" height="%s" fill="%s"%s%s%s%s/>' % (f(x), f(y), f(w), f(h), fill, r, s, o, t)


def circ(cx, cy, r, fill, op=1.0, stroke=None, sw=0):
	o = ' opacity="%s"' % f(op) if op < 1.0 else ""
	s = ' stroke="%s" stroke-width="%s"' % (stroke, f(sw)) if stroke else ""
	return '<circle cx="%s" cy="%s" r="%s" fill="%s"%s%s/>' % (f(cx), f(cy), f(r), fill, s, o)


def ell(cx, cy, rx, ry, fill, op=1.0, stroke=None, sw=0, tr=""):
	o = ' opacity="%s"' % f(op) if op < 1.0 else ""
	s = ' stroke="%s" stroke-width="%s"' % (stroke, f(sw)) if stroke else ""
	t = ' transform="%s"' % tr if tr else ""
	return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"%s%s%s/>' % (f(cx), f(cy), f(rx), f(ry), fill, s, o, t)


def line(x1, y1, x2, y2, col, sw, op=1.0):
	o = ' opacity="%s"' % f(op) if op < 1.0 else ""
	return '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s" stroke-linecap="round"%s/>' % (
		f(x1), f(y1), f(x2), f(y2), col, f(sw), o)


def group(body, tr="", op=1.0, clip=None):
	t = ' transform="%s"' % tr if tr else ""
	o = ' opacity="%s"' % f(op) if op < 1.0 else ""
	c = ' clip-path="url(#%s)"' % clip if clip else ""
	return "<g%s%s%s>%s</g>" % (t, o, c, "".join(body) if isinstance(body, list) else body)


def star_pts(cx, cy, ro, ri, n=5, rot=-90.0):
	p = []
	for i in range(n * 2):
		r = ro if i % 2 == 0 else ri
		a = math.radians(rot + i * 180.0 / n)
		p.append((cx + r * math.cos(a), cy + r * math.sin(a)))
	return p


def blob(cx, cy, r, rng, n=18, jag=0.35, sy=1.0):
	p = []
	for i in range(n):
		a = TAU * i / n
		rr = r * (1 + rng.uniform(-jag, jag))
		p.append((cx + rr * math.cos(a), cy + rr * math.sin(a) * sy))
	return p


def crack_path(x, y, rng, steps=5, ln=14, ang=1.2):
	d = "M%s %s" % (f(float(x)), f(float(y)))
	a = ang
	for _ in range(steps):
		a += rng.uniform(-0.6, 0.6)
		x += math.cos(a) * ln * rng.uniform(0.6, 1.2)
		y += math.sin(a) * ln * rng.uniform(0.6, 1.2)
		d += " L%s %s" % (f(float(x)), f(float(y)))
	return d


def crescent(cx, cy, r, k=0.62, rot=-30.0):
	"""Crescent moon path: outer circle arc + inner offset arc (k = inner radius ratio)."""
	a0 = math.radians(rot - 70)
	a1 = math.radians(rot + 70)
	p0 = (cx + r * math.cos(a0), cy + r * math.sin(a0))
	p1 = (cx + r * math.cos(a1), cy + r * math.sin(a1))
	ri = r * k * 1.25
	return "M%s %s A%s %s 0 1 0 %s %s A%s %s 0 0 1 %s %s Z" % (
		f(p0[0]), f(p0[1]), f(float(r)), f(float(r)), f(p1[0]), f(p1[1]), f(ri), f(ri), f(p0[0]), f(p0[1]))


def chain_svg(x0, y0, x1, y1, link=24.0, w=13.0, col=IRON, hi=IRON_H, op=1.0):
	"""A chain of alternating face-on / edge-on links along a line."""
	out = []
	dx, dy = x1 - x0, y1 - y0
	ln = math.hypot(dx, dy)
	ang = math.degrees(math.atan2(dy, dx))
	n = int(ln / (link * 0.78))
	for i in range(n):
		u = (i + 0.5) / n
		cx, cy = x0 + dx * u, y0 + dy * u
		tr = "rotate(%s %s %s)" % (f(ang), f(cx), f(cy))
		if i % 2 == 0:
			out.append(ell(cx, cy, link * 0.55, w * 0.5, "none", op, stroke=INK, sw=w * 0.5 + 3, tr=tr))
			out.append(ell(cx, cy, link * 0.55, w * 0.5, "none", op, stroke=col, sw=w * 0.5, tr=tr))
			out.append(ell(cx - 1, cy - 1, link * 0.5, w * 0.42, "none", op * 0.7, stroke=hi, sw=1.6, tr=tr))
		else:
			out.append(rect(cx - link * 0.55, cy - w * 0.2, link * 1.1, w * 0.4, col, op, rx=w * 0.2, stroke=INK, sw=2.0, tr=tr))
			out.append(rect(cx - link * 0.45, cy - w * 0.14, link * 0.9, 1.6, hi, op * 0.7, tr=tr))
	return out


def write(name, content):
	p = os.path.join(OUT, name + ".svg")
	with open(p, "w") as fh:
		fh.write(content)
	print("wrote", os.path.relpath(p, ROOT))


# ------------------------------------------------------------------ the cavern
def fungus(b, rng, cx, cy, n, spread, glow=1.0):
	b.append(circ(cx, cy, spread * 2.6, "url(#fglow)", op=0.75 * glow))
	for _ in range(n):
		x = cx + rng.gauss(0, spread)
		y = cy + rng.gauss(0, spread * 0.6)
		r = rng.uniform(1.4, 4.6)
		b.append(circ(x, y, r * 1.9, "#2f9e94", op=0.25 * glow))
		b.append(circ(x, y, r, "#7fe8da", op=rng.uniform(0.55, 0.95) * glow))


def lx_cave():
	rng = random.Random(2002)
	W, H = 1280, 720
	defs = [lin("csky", 0, 0, 0, 1, [(0, "#020506"), (0.45, "#081315"), (0.66, "#0b1a1c"), (1, "#020405")]),
		rad("glowL", 220, 300, 460, [(0, "#1f5752", 0.45), (0.5, "#143a37", 0.18), (1, "#0b1a1c", 0)], user=True),
		rad("glowR", 1060, 240, 420, [(0, "#1f5752", 0.32), (1, "#0b1a1c", 0)], user=True),
		rad("fglow", 0.5, 0.5, 0.5, [(0, "#3fd0c0", 0.42), (0.4, "#1f8a80", 0.16), (1, "#0b1a1c", 0)]),
		lin("cfog", 0, 0, 0, 1, [(0, "#9fd8d0", 0.0), (0.5, "#9fd8d0", 0.11), (1, "#9fd8d0", 0.0)]),
		lin("wfar", 0, 0, 0, 1, [(0, "#0c1a1c"), (0.25, "#050c0d"), (1, "#010303")]),
		lin("ctop", 0, 0, 0, 1, [(0, "#000000", 0.85), (1, "#000000", 0.0)]),
		rad("lamp", 0.5, 0.5, 0.5, [(0, "#ffd890", 0.55), (1, "#ffd890", 0.0)])]
	b = [rect(0, 0, W, H, "url(#csky)"), rect(0, 0, W, H, "url(#glowL)"), rect(0, 0, W, H, "url(#glowR)")]
	# far wall: three ridges of rock, lighter (fungus lit) to darker
	for layer, (base, amp, col, hi) in enumerate(((300, 120, "#0d1b1d", "#1d3a3b"), (360, 90, "#091416", "#163032"), (420, 60, "#060e0f", "#11292a"))):
		p = [(-20, 480)]
		x = -20
		while x < W + 40:
			p.append((x, base - rng.uniform(0, amp) - 30 * math.sin(x * 0.006 + layer)))
			x += rng.uniform(30, 80)
		p.append((W + 20, 480))
		b.append(poly(p, col))
		b.append(path("M" + " L".join("%s %s" % (f(float(px)), f(float(py))) for px, py in p[1:-1]), stroke=hi, sw=2.5, op=0.5))
	# big pillars at the sides (merged stalactite + stalagmite)
	for (x0, w0) in ((-30, 150), (1150, 170)):
		d = "M%d 0 L%d 0 Q%d 260 %d 360 Q%d 470 %d 720 L%d 720 Q%d 470 %d 360 Q%d 260 %d 0 Z" % (
			x0, x0 + w0, x0 + w0 - 40, x0 + w0 - 50, x0 + w0 - 30, x0 + w0 + 10, x0 - 10, x0 + 30, x0 + 40, x0 + 30, x0)
		b.append(path(d, "#040909", stroke="#122627", sw=3))
	# fungus on the walls and pillars
	for (cx, cy, n, s) in ((140, 250, 14, 14), (260, 330, 9, 10), (420, 280, 7, 8), (980, 230, 12, 12), (1110, 330, 10, 11),
			(1190, 190, 8, 9), (60, 420, 8, 9), (720, 300, 6, 7), (560, 340, 5, 6), (870, 360, 6, 6), (1230, 450, 7, 8)):
		fungus(b, rng, cx, cy, n, s, 0.9)
	# ceiling band + stalactites
	ceil = [(-10, 0)]
	for x in range(-10, W + 30, 24):
		ceil.append((x, 40 + 30 * math.sin(x * 0.011) + rng.uniform(0, 26)))
	ceil.append((W + 10, 0))
	b.append(poly(ceil, "#030707"))
	x = -10
	while x < W + 20:
		w = rng.uniform(14, 44)
		ln = rng.uniform(30, 190) * (0.6 if 380 < x < 900 else 1.0)
		top = 40 + 30 * math.sin(x * 0.011) + 10
		tip = (x + w * 0.5 + rng.uniform(-6, 6), top + ln)
		p = [(x, top), (x + w * 0.2, top + ln * 0.45), tip, (x + w * 0.8, top + ln * 0.5), (x + w, top)]
		b.append(poly(p, "#050b0c"))
		b.append(path("M%s %s L%s %s L%s %s" % (f(x + 2.0), f(top), f(x + w * 0.22), f(top + ln * 0.45), f(tip[0]), f(tip[1])), stroke="#1c3637", sw=2, op=0.65))
		if rng.random() < 0.35:
			b.append(ell(tip[0], tip[1] + 4, 2.2, 3.4, "#8fe0d8", op=0.5))
		x += w * rng.uniform(0.55, 1.1)
	for (cx, cy, n, s) in ((210, 70, 10, 12), (640, 52, 6, 9), (1010, 80, 9, 11), (360, 40, 6, 8), (820, 46, 5, 7)):
		fungus(b, rng, cx, cy, n, s, 0.8)
	# far shore + a distant stone dock with two lanterns
	b.append(path("M-10 470 Q200 456 420 466 Q700 452 960 462 Q1120 456 1290 466 L1290 486 L-10 486 Z", "#030808"))
	b.append(rect(930, 436, 170, 30, "#071011", stroke="#142a2b", sw=2))
	for x in (944, 1000, 1056):
		b.append(rect(x, 466, 10, 24, "#050b0c"))
	for x in (952, 1086):
		b.append(line(x, 436, x, 410, "#0a1414", 3))
		b.append(circ(x, 408, 16, "url(#lamp)"))
		b.append(circ(x, 408, 3, "#ffe0a0", op=0.85))
	# far water
	b.append(rect(-10, 478, W + 20, H - 478, "url(#wfar)"))
	y = 486.0
	k = 0
	while y < H:
		for _ in range(int(6 + k)):
			x = rng.uniform(-20, W)
			ln = rng.uniform(30, 160) * (1 + k * 0.08)
			b.append(line(x, y, x + ln, y, "#1d3a3b", 1.2 + k * 0.12, 0.35))
		k += 1
		y += 5 + k * 2.4
	# fungus + lantern reflections on the water (broken vertical dashes)
	for (x, col, op) in ((140, "#5fd0c4", 0.22), (260, "#5fd0c4", 0.15), (980, "#5fd0c4", 0.18), (1110, "#5fd0c4", 0.16),
			(952, "#ffd890", 0.3), (1086, "#ffd890", 0.3)):
		yy = 484.0
		while yy < 640:
			w = rng.uniform(8, 26)
			b.append(line(x - w * 0.5 + rng.uniform(-4, 4), yy, x + w * 0.5, yy, col, 2, op))
			yy += rng.uniform(5, 11)
	b.append(rect(0, 380, W, 170, "url(#cfog)"))
	b.append(rect(0, 0, W, 260, "url(#ctop)"))
	write("lx_cave", svg(W, H, "\n".join(b), "".join(defs)))


# ------------------------------------------------------------------ the Mudlark's stern
def lx_stern():
	rng = random.Random(77)
	W, H = 1280, 720
	defs = [lin("hull", 0, 0, 0, 1, [(0, "#4c6061"), (0.5, "#344443"), (1, "#141c1b")]),
		lin("house", 0, 0, 0, 1, [(0, "#3e5251"), (1, "#263130")]),
		lin("timber", 0, 0, 0, 1, [(0, "#3a2a1e"), (0.5, "#2a1d14"), (1, "#160f0a")]),
		lin("stack", 0, 0, 1, 0, [(0, "#0c0e0e"), (0.45, "#2a2f2f"), (1, "#0a0c0c")]),
		lin("iron", 0, 0, 1, 0, [(0, "#121516"), (0.45, "#33393b"), (1, "#0e1011")]),
		rad("win", 0.5, 0.5, 0.6, [(0, "#d8b066", 0.85), (1, "#7a5a2a", 0.5)]),
		lin("grime", 0, 0, 1, 0, [(0, "#000000", 0.55), (0.6, "#000000", 0.15), (1, "#000000", 0.35)])]
	b = []
	# smokestack far left, rising out of frame
	b.append(rect(14, -10, 56, 200, "url(#stack)"))
	for y in (30, 36, 120):
		b.append(rect(10, y, 64, 6, "#3a3a32", op=0.8))
	# far outrigger beam (behind the wheel)
	b.append(rect(560, 352, 380, 24, "url(#timber)", stroke="#0a0604", sw=2))
	for x in range(600, 940, 70):
		b.append(rect(x, 350, 8, 28, "#1a1c1c"))
	# deck house (cabins) with arched windows
	b.append(rect(-10, 186, 440, 146, "url(#house)", stroke=INK, sw=3))
	for i, x in enumerate(range(16, 410, 56)):
		lit = i in (1, 4)
		b.append(path("M%d 290 L%d 232 Q%d 214 %d 214 Q%d 214 %d 232 L%d 290 Z" % (x, x, x, x + 15, x + 30, x + 30, x + 30),
			"url(#win)" if lit else "#0b1111", stroke="#20201a", sw=3))
		b.append(line(x + 15, 216, x + 15, 290, "#20201a", 2.5))
		b.append(line(x, 252, x + 30, 252, "#20201a", 2.5))
	b.append(rect(-14, 174, 450, 16, "#2c2620", stroke=INK, sw=2))
	# upper deck railing
	b.append(line(-10, 150, 430, 150, "#3a3028", 5))
	for x in range(0, 432, 22):
		b.append(line(x, 150, x, 174, "#2a2420", 3))
	# hull
	hull = [(-10, 330), (560, 330), (588, 354), (588, 470), (566, 562), (-10, 562)]
	b.append(poly(hull, "url(#hull)", stroke=INK, sw=3))
	for y in range(356, 560, 22):
		b.append(line(-10, y, 580, y, "#26302f", 1.5, 0.5))
	b.append(rect(-10, 446, 596, 16, "#2f5450"))
	b.append(rect(-10, 336, 594, 9, "#2a1e16"))
	for x in range(40, 560, 80):
		lit = x in (120, 360)
		b.append(circ(x, 398, 12, "url(#win)" if lit else "#0c1414", stroke="#5a4c2c", sw=4))
		b.append(path("M%d 410 Q%s 470 %s 548" % (x, f(x + rng.uniform(-4, 4)), f(x + rng.uniform(-6, 6))), stroke="#3a2a1c", sw=rng.uniform(4, 9), op=0.4))
	b.append(rect(-10, 520, 600, 42, "#141c1a", op=0.75))
	b.append(poly(hull, "url(#grime)"))
	b.append(rect(-10, 186, 440, 146, "url(#grime)", op=0.7))
	# main deck railing
	b.append(line(-10, 292, 562, 292, "#3a3028", 6))
	b.append(line(-10, 316, 562, 316, "#2a2420", 3))
	for x in range(0, 562, 28):
		b.append(line(x, 292, x, 330, "#2a2420", 4))
	# the Snapjaw crane: post on the deck-house roof, arm out to the pulley at PIVOT
	px, py = PIVOT
	b.append(rect(196, 18, 26, 168, "url(#iron)", stroke=INK, sw=2))
	for y in (60, 110, 160):
		b.append(rect(194, y, 30, 7, "#5a1212"))
	b.append(poly([(206, 30), (px + 12, py - 14), (px + 14, py - 2), (206, 52)], "url(#iron)", stroke=INK, sw=2))
	b.append(line(212, 130, px - 18, py + 2, "#1c2022", 9))
	b.append(line(212, 130, px - 18, py + 2, "#3a4244", 2.5, 0.7))
	for k in range(5):
		u = (k + 0.5) / 5
		b.append(circ(206 + (px - 206) * u, 41 + (py - 8 - 41) * u, 2.4, "#6e777a"))
	b.append(circ(px, py, 16, "#1a1d1e", stroke=INK, sw=3))
	b.append(circ(px, py, 6, "#6e777a"))
	b.append(rect(px - 4, py, 8, 12, IRON, stroke=INK, sw=1.5))
	# little Snapjaw badge on the crane post (red eye)
	b.append(circ(209, 88, 15, "#121516", stroke="#4a5254", sw=2.5))
	b.append(path("M198 92 L216 86 Q224 86 222 92 L200 96 Z", "#2c3a2a"))
	b.append(rect(204, 72, 12, 12, "#0c0c0c"))
	b.append(circ(214, 88, 2.6, "#c0102a"))
	write("lx_stern", svg(W, H, "\n".join(b), "".join(defs)))


def lx_stern_fg():
	W, H = 1280, 720
	cx, cy = WHEEL_C
	defs = [lin("tim", 0, 0, 0, 1, [(0, "#4a3626"), (0.35, "#33241a"), (1, "#170f0a")]),
		lin("blk", 0, 0, 1, 1, [(0, "#3a4042"), (1, "#121516")])]
	b = []
	# hog rod: iron tie from the upper works down to the beam
	b.append(line(470, 176, cx + 70, cy - 6, "#101314", 7))
	b.append(line(470, 176, cx + 70, cy - 6, "#4a5254", 2, 0.6))
	# near outrigger beam
	b.append(rect(566, cy - 14, 400, 32, "url(#tim)", stroke="#0a0604", sw=2.5))
	b.append(line(570, cy - 11, 962, cy - 11, "#6a5038", 2, 0.6))
	for x in range(600, 960, 64):
		b.append(rect(x, cy - 16, 9, 36, "#1c1f20", stroke="#0a0a0a", sw=1))
		b.append(circ(x + 4.5, cy - 8, 2, "#7a8284"))
	# bearing block + shaft end at the hub
	b.append(rect(cx - 44, cy - 34, 88, 64, "url(#blk)", rx=6, stroke=INK, sw=3))
	b.append(circ(cx, cy, 28, "#1a1d1e", stroke=INK, sw=3))
	b.append(circ(cx, cy, 16, "#3a4042"))
	b.append(circ(cx - 4, cy - 4, 5, "#8a9294", op=0.7))
	for (dx, dy) in ((-34, -24), (34, -24), (-34, 20), (34, 20)):
		b.append(circ(cx + dx, cy + dy, 3, "#7a8284"))
	# the broadcast camera on the beam end
	b.append(rect(952, cy - 52, 10, 40, "#121516"))
	b.append(rect(932, cy - 78, 52, 30, "#16191a", rx=4, stroke=INK, sw=2))
	b.append(rect(908, cy - 72, 26, 18, "#0c0e0f", stroke=INK, sw=2))
	b.append(circ(912, cy - 63, 6, "#2a3436"))
	b.append(circ(974, cy - 70, 3, "#d0102a"))
	write("lx_stern_fg", svg(W, H, "\n".join(b), "".join(defs)))


# ------------------------------------------------------------------ the paddle wheel
def _wheel_paddle_poly(k, r0, r1, half_w):
	a = TAU * k / WH_N
	c, s = math.cos(a), math.sin(a)
	nx, ny = -s, c
	o = WH * 0.5
	return [(o + c * r0 + nx * half_w, o + s * r0 + ny * half_w), (o + c * r1 + nx * half_w, o + s * r1 + ny * half_w),
		(o + c * r1 - nx * half_w, o + s * r1 - ny * half_w), (o + c * r0 - nx * half_w, o + s * r0 - ny * half_w)]


def lx_wheel():
	rng = random.Random(12)
	o = WH * 0.5
	defs = [lin("pad", 0, 0, 1, 0, [(0, "#5e2e22"), (0.5, "#7a4030"), (1, "#4a241a")]),
		rad("hubg", 0.4, 0.4, 0.7, [(0, "#4a5254"), (1, "#121516")])]
	b = []
	# spokes (wooden arms) - dark outline then wood
	for k in range(WH_N):
		a = TAU * (k + 0.5) / WH_N
		x0, y0 = o + math.cos(a) * 40, o + math.sin(a) * 40
		x1, y1 = o + math.cos(a) * 244, o + math.sin(a) * 244
		b.append(line(x0, y0, x1, y1, "#120a06", 20))
		b.append(line(x0, y0, x1, y1, "#4a3424", 14))
		b.append(line(x0, y0, x1, y1, "#6e5038", 3.5, 0.5))
	# cross braces between spokes at r 150 (polygon ring)
	ring = [(o + math.cos(TAU * (k + 0.5) / WH_N) * 150, o + math.sin(TAU * (k + 0.5) / WH_N) * 150) for k in range(WH_N)]
	b.append(poly(ring, "none", stroke="#120a06", sw=12))
	b.append(poly(ring, "none", stroke="#3e2c1e", sw=7))
	# rims (iron)
	for r, sw in ((232, 12), (250, 9)):
		b.append(circ(o, o, r, "none", stroke="#0a0b0b", sw=sw + 5))
		b.append(circ(o, o, r, "none", stroke="#2c3133", sw=sw))
		b.append(circ(o - 1, o - 1, r, "none", stroke="#5c6668", sw=1.6, op=0.6))
	# paddle boards
	for k in range(WH_N):
		p = _wheel_paddle_poly(k, WH_R0, WH_R1, 15)
		b.append(poly(p, "url(#pad)", stroke="#140a06", sw=3.5))
		a = TAU * k / WH_N
		c, s = math.cos(a), math.sin(a)
		for t in (-7, 0, 7):
			b.append(line(o + c * (WH_R0 + 8) - s * t, o + s * (WH_R0 + 8) + c * t, o + c * (WH_R1 - 6) - s * t, o + s * (WH_R1 - 6) + c * t, "#3a1c14", 1.2, 0.55))
		for r in (232, 250):
			bx, by = o + c * r, o + s * r
			b.append(poly(_wheel_paddle_poly(k, r - 4, r + 4, 17), "#202425", stroke="#0a0a0a", sw=1.5))
			b.append(circ(bx, by, 2.4, "#8a9294"))
		# moss + water stain on the outer end
		ex, ey = o + c * (WH_R1 - 14), o + s * (WH_R1 - 14)
		b.append(poly(blob(ex, ey, 10, rng, 9, 0.4), "#1c2a1a", op=0.55))
	# hub
	b.append(circ(o, o, 52, "url(#hubg)", stroke="#0a0a0a", sw=4))
	b.append(circ(o, o, 30, "#1a1d1e", stroke="#0a0a0a", sw=3))
	for k in range(8):
		a = TAU * k / 8
		b.append(circ(o + math.cos(a) * 41, o + math.sin(a) * 41, 3.2, "#7a8284"))
	write("lx_wheel", svg(WH, WH, "\n".join(b), "".join(defs)))


def lx_wheel_stain():
	rng = random.Random(4040)
	o = WH * 0.5
	b = []
	for k in range(WH_N):
		a = TAU * k / WH_N
		c, s = math.cos(a), math.sin(a)
		# soaked outer half of the board
		p = _wheel_paddle_poly(k, WH_R0 + 30 + rng.uniform(-10, 10), WH_R1 - 2, 13)
		b.append(poly(p, BLOOD_D, op=0.8))
		for _ in range(4):
			r = rng.uniform(WH_R0 + 10, WH_R1 - 8)
			t = rng.uniform(-9, 9)
			x, y = o + c * r - s * t, o + s * r + c * t
			b.append(poly(blob(x, y, rng.uniform(5, 11), rng, 9, 0.45), BLOOD, op=rng.uniform(0.75, 1.0)))
		# runs along the board towards the hub
		for t in (-8, 3):
			r1 = rng.uniform(WH_R0 - 30, WH_R0 + 20)
			b.append(line(o + c * (WH_R1 - 10) - s * t, o + s * (WH_R1 - 10) + c * t, o + c * r1 - s * t, o + s * r1 + c * t, BLOOD, rng.uniform(2.5, 4.5), 0.85))
		hx, hy = o + c * (WH_R1 - 30), o + s * (WH_R1 - 30)
		b.append(ell(hx, hy, 6, 2.5, BLOOD_H, op=0.6, tr="rotate(%s %s %s)" % (f(math.degrees(a)), f(hx), f(hy))))
	# splashes on the rim
	for _ in range(18):
		a = rng.uniform(0, TAU)
		r = rng.uniform(226, 254)
		b.append(circ(o + math.cos(a) * r, o + math.sin(a) * r, rng.uniform(2, 5), BLOOD, op=0.8))
	write("lx_wheel_stain", svg(WH, WH, "\n".join(b)))


# ------------------------------------------------------------------ the cradle (600x740, ring at (300, 0))
def _cradle_defs():
	return (lin("paint", 0, 0, 0, 1, [(0, "#9db5ae"), (0.5, PAINT), (1, PAINT_S)])
		+ lin("paintd", 0, 0, 0, 1, [(0, PAINT_S), (1, PAINT_D)])
		+ lin("spin", 0, 0, 1, 0, [(0, "#a8bfb8"), (0.55, PAINT), (1, PAINT_D)])
		+ lin("crshade", 0, 0, 0, 1, [(0, "#000000", 0.0), (0.6, "#000000", 0.12), (1, "#000000", 0.45)]))


def lx_cradle_back():
	rng = random.Random(31)
	b = []
	# back chains to the far corners
	b += chain_svg(300, 18, 104, 370, link=22, w=11, col="#1c1f20", hi="#4a5254", op=0.9)
	b += chain_svg(300, 18, 496, 370, link=22, w=11, col="#1c1f20", hi="#4a5254", op=0.9)
	# headboard with an arched top + carved crescent moon
	hb = "M84 690 L84 300 Q84 176 300 166 Q516 176 516 300 L516 690 Z"
	b.append(path(hb, "url(#paintd)", stroke=INK, sw=5))
	b.append(path("M112 680 L112 306 Q112 204 300 194 Q488 204 488 306 L488 680 Z", stroke="#2c3e3c", sw=4, op=0.8))
	b.append(path(crescent(300, 252, 44, 0.66, -40), "#1c2826", stroke="#7a948e", sw=2, op=0.95))
	for (x, y, r) in ((236, 214, 8), (368, 222, 6), (210, 270, 5), (392, 280, 7)):
		b.append(poly(star_pts(x, y, r, r * 0.45), "#c8c0a0", op=0.55))
	for _ in range(7):
		b.append(poly(blob(rng.uniform(110, 490), rng.uniform(210, 600), rng.uniform(5, 12), rng, 9, 0.5, 0.8), WOOD, op=0.7))
	# inner box: side walls + floor shadow
	b.append(poly([(84, 372), (36, 404), (36, 700), (84, 690)], PAINT_D, stroke=INK, sw=3))
	b.append(poly([(516, 372), (564, 404), (564, 700), (516, 690)], PAINT_D, stroke=INK, sw=3))
	b.append(rect(84, 380, 432, 310, "#1a2422", op=0.85))
	# pillow
	pil = "M164 384 Q150 330 196 322 Q300 306 404 322 Q450 330 436 384 Q300 400 164 384 Z"
	b.append(path(pil, "#cbc2ae", stroke=INK, sw=4))
	b.append(path("M184 372 Q300 386 416 372", stroke="#a0977f", sw=3, op=0.8))
	b.append(path("M196 334 Q300 322 404 334", stroke="#e8e0cc", sw=3, op=0.6))
	# side rails (back corners down to the front posts)
	b.append(line(84, 372, 40, 398, PAINT, 12))
	b.append(line(516, 372, 560, 398, PAINT, 12))
	write("lx_cradle_back", svg(CR_W, CR_H, "\n".join(b), _cradle_defs()))


def _quilt(top_d, rng, empty=False):
	"""Patchwork quilt clipped to the shape whose top edge is the path fragment top_d (from x 52 to 548)."""
	shape = "M52 700 L52 %s L548 700 Z" % top_d
	defs = '<clipPath id="qclip"><path d="%s"/></clipPath>' % shape
	cols = ["#5b6f8f", "#c9b48a", "#8a5a4a", "#6f8a6a", "#9a8fb0", "#b8a070"]
	tiles = []
	for j, y in enumerate(range(330, 720, 46)):
		for i, x in enumerate(range(40, 580, 46)):
			c = cols[(i * 2 + j * 3) % len(cols)]
			tiles.append(rect(x, y, 47, 47, c))
			tiles.append(line(x + 4, y + 4, x + 42, y + 4, "#f0e8d8", 1.2, 0.35))
			tiles.append(line(x + 4, y + 4, x + 4, y + 42, "#f0e8d8", 1.2, 0.35))
	if empty:
		for k in range(7):
			x0 = rng.uniform(90, 500)
			tiles.append(path("M%s 470 Q%s %s %s %s" % (f(x0), f(x0 + rng.uniform(-30, 30)), f(rng.uniform(510, 560)), f(x0 + rng.uniform(-50, 50)), f(rng.uniform(560, 620))), stroke="#000000", sw=4, op=0.25))
	else:
		for (x0, x1) in ((140, 190), (410, 450), (300, 300)):
			tiles.append(path("M%d 440 Q%d 500 %d 560" % (x0, (x0 + x1) // 2 + 10, x1), stroke="#000000", sw=4, op=0.2))
	tiles.append(rect(30, 300, 560, 420, "url(#qshade)"))
	defs += lin("qshade", 0, 0, 0, 1, [(0, "#000000", 0.0), (0.5, "#000000", 0.15), (1, "#000000", 0.5)])
	body = [group(tiles, clip="qclip")]
	body.append(path(shape, stroke=INK, sw=4))
	return defs, body


def lx_quilt():
	rng = random.Random(41)
	top = "440 Q86 424 150 422 Q210 400 300 398 Q390 400 450 422 Q514 424 548 440"
	defs, b = _quilt(top, rng)
	# folded sheet band along the top edge
	band = "M52 440 Q86 424 150 422 Q210 400 300 398 Q390 400 450 422 Q514 424 548 440"
	b.append(path(band, stroke="#2a2018", sw=26))
	b.append(path(band, stroke="#dcd5c6", sw=20))
	b.append(path(band.replace("398", "406").replace("400", "408"), stroke="#b8b0a0", sw=3, op=0.7))
	write("lx_quilt", svg(CR_W, CR_H, "\n".join(b), defs))


def lx_quilt_empty():
	rng = random.Random(43)
	top = "486 Q100 470 170 476 Q232 492 290 500 Q350 506 410 486 Q480 462 548 478"
	defs, b = _quilt(top, rng, empty=True)
	band = "M52 486 Q100 470 170 476 Q232 492 290 500 Q350 506 410 486 Q480 462 548 478"
	b.append(path(band, stroke="#2a2018", sw=24))
	b.append(path(band, stroke="#d4cdbe", sw=18))
	# the hollow where somebody used to lie
	b.append(ell(300, 530, 120, 30, "#000000", op=0.28))
	write("lx_quilt_empty", svg(CR_W, CR_H, "\n".join(b), defs))


def _spindle(cx, y0, y1):
	h = float(y1 - y0)

	def p(dx, k):
		return "%s %s" % (f(cx + dx), f(y0 + h * k))
	return ("M" + p(-7.0, 0.0) + " L" + p(-7.0, 0.18) + " Q" + p(-13.0, 0.36) + " " + p(-11.0, 0.5) + " Q" + p(-13.0, 0.66) + " " + p(-7.0, 0.82)
		+ " L" + p(-7.0, 1.0) + " L" + p(7.0, 1.0) + " L" + p(7.0, 0.82) + " Q" + p(13.0, 0.66) + " " + p(11.0, 0.5) + " Q" + p(13.0, 0.36) + " " + p(7.0, 0.18)
		+ " L" + p(7.0, 0.0) + " Z")


def lx_cradle_front():
	rng = random.Random(51)
	b = []
	# chains from the ring to the front finials
	b += chain_svg(300, 22, 44, 378, link=26, w=14)
	b += chain_svg(300, 22, 556, 378, link=26, w=14)
	b.append(circ(300, 16, 15, "none", stroke=INK, sw=11))
	b.append(circ(300, 16, 15, "none", stroke=IRON, sw=7))
	b.append(circ(298, 14, 15, "none", stroke=IRON_H, sw=1.6, op=0.7))
	# posts + ball finials
	for x in (22, 542):
		b.append(rect(x, 396, 36, 296, "url(#spin)", rx=6, stroke=INK, sw=4))
		for y in (470, 560, 650):
			b.append(rect(x - 3, y, 42, 9, PAINT_S, rx=4, stroke=INK, sw=2.5))
		b.append(rect(x + 8, 372, 20, 26, PAINT_S, stroke=INK, sw=3))
		b.append(circ(x + 18, 366, 20, "url(#spin)", stroke=INK, sw=4))
		b.append(circ(x + 12, 360, 6, "#ffffff", op=0.3))
	# spindles between the top rail and the mid rail
	for i in range(11):
		cx = 90 + i * 42
		b.append(path(_spindle(cx, 424, 552), "url(#spin)", stroke=INK, sw=3))
	# rails
	b.append(rect(16, 400, 568, 28, "url(#paint)", rx=10, stroke=INK, sw=5))
	b.append(line(28, 406, 572, 406, "#c8d8d2", 2.5, 0.55))
	b.append(rect(16, 548, 568, 22, "url(#paint)", rx=6, stroke=INK, sw=4))
	# lower panel: crescent moon, stars, two little Snapjaw heads
	b.append(rect(40, 568, 520, 98, "url(#paintd)", stroke=INK, sw=4))
	b.append(rect(56, 580, 488, 74, "none", stroke="#2c3e3c", sw=3, op=0.8))
	b.append(path(crescent(300, 616, 30, 0.66, -40), "#cfc5a0", stroke=INK, sw=2.5))
	for (x, y, r) in ((248, 596, 7), (352, 640, 6), (210, 636, 5), (390, 598, 6)):
		b.append(poly(star_pts(x, y, r, r * 0.45), "#cfc5a0", op=0.85))
	for sx in (110, 490):
		m = 1 if sx < 300 else -1
		b.append(path("M%d 626 L%d 618 Q%d 612 %d 620 L%d 634 Z" % (sx - 30 * m, sx + 26 * m, sx + 36 * m, sx + 30 * m, sx - 26 * m), "#2c3a2a", stroke=INK, sw=2))
		b.append(rect(sx - 10, 594, 18, 22, "#121014", stroke=INK, sw=2))
		b.append(rect(sx - 16, 614, 30, 5, "#121014"))
		b.append(circ(sx + 6 * m, 622, 3, "#b0102a"))
	b.append(rect(16, 662, 568, 24, "url(#paint)", rx=6, stroke=INK, sw=4))
	# rocker
	b.append(path("M0 676 Q300 750 600 676 L600 696 Q300 770 0 696 Z", "url(#paintd)", stroke=INK, sw=4))
	b.append(path("M14 684 Q300 752 586 684", stroke="#a8bfb8", sw=2, op=0.5))
	# wear: peeled paint, scratches
	for _ in range(16):
		x = rng.uniform(30, 570)
		y = rng.choice((rng.uniform(404, 424), rng.uniform(572, 660), rng.uniform(664, 684)))
		b.append(poly(blob(x, y, rng.uniform(3, 9), rng, 9, 0.5, 0.7), WOOD, op=rng.uniform(0.6, 0.9)))
	for _ in range(6):
		b.append(path(crack_path(rng.uniform(60, 540), rng.uniform(576, 650), rng, 3, 10, rng.uniform(0, TAU)), stroke=INK, sw=1.2, op=0.6))
	b.append(rect(0, 392, 600, 348, "url(#crshade)"))
	write("lx_cradle_front", svg(CR_W, CR_H, "\n".join(b), _cradle_defs()))


def lx_cradle_crack():
	rng = random.Random(61)
	b = []
	# split in the top rail near the wheel side, with splinters
	b.append(poly([(470, 400), (492, 400), (486, 414), (498, 428), (466, 428), (476, 414)], "#0c0806"))
	for k in range(5):
		x = 470 + k * 6
		b.append(line(x, 400, x + rng.uniform(-8, 8), 388 - rng.uniform(4, 16), "#d8c8a8", 2, 0.85))
	# broken spindle: a gap with jagged ends
	cx = 90 + 9 * 42
	b.append(poly([(cx - 14, 456), (cx - 4, 466), (cx + 6, 452), (cx + 14, 462), (cx + 14, 510), (cx + 4, 500), (cx - 6, 514), (cx - 14, 502)], "#0c0806"))
	b.append(line(cx - 10, 458, cx + 12, 456, "#d8c8a8", 2, 0.8))
	b.append(line(cx - 10, 506, cx + 12, 508, "#d8c8a8", 2, 0.8))
	# cracks spreading over rails, panel and the right post
	for (x, y, a, n) in ((480, 414, 3.0, 7), (520, 560, 2.6, 6), (548, 470, 1.7, 6), (440, 600, 3.4, 5), (560, 640, 2.0, 5), (360, 410, 3.1, 5)):
		d = crack_path(x, y, rng, n, 16, a)
		b.append(path(d, stroke="#0c0806", sw=3.5))
		b.append(path(d, stroke="#c8b898", sw=1, op=0.35))
	# gouges from the paddles
	for k in range(4):
		y = 590 + k * 16
		b.append(line(470 + k * 8, y, 560, y - 10, "#0c0806", 3, 0.8))
	write("lx_cradle_crack", svg(CR_W, CR_H, "\n".join(b)))


# ------------------------------------------------------------------ the mobile: tiny Snapjaw heads (120x150, string at (60, 0))
def _mob_defs():
	return (lin("mgreen", 0, 0, 0, 1, [(0, "#62a04a"), (1, "#3c6e2e")])
		+ lin("mmetal", 0, 0, 1, 1, [(0, "#c4ccd0"), (1, "#707a7e")])
		+ lin("mhat", 0, 0, 1, 0, [(0, "#0c0a0e"), (0.5, "#2a2630"), (1, "#0a080c")])
		+ '<clipPath id="mright"><rect x="60" y="0" width="60" height="150"/></clipPath>'
		+ '<clipPath id="mleft"><rect x="0" y="0" width="60" height="150"/></clipPath>')


def _hat(b, cx, y_brim, tilt=0.0):
	tr = "rotate(%s %s %s)" % (f(tilt), f(cx), f(y_brim)) if tilt else ""
	g = [path("M%s %s L%s %s Q%s %s %s %s L%s %s Z" % (f(cx - 19.0), f(y_brim - 2.0), f(cx - 17.0), f(y_brim - 34.0), f(float(cx)), f(y_brim - 38.0),
			f(cx + 17.0), f(y_brim - 34.0), f(cx + 19.0), f(y_brim - 2.0)), "url(#mhat)", stroke=INK, sw=3),
		rect(cx - 19, y_brim - 11, 38, 7, "#7a1418"),
		ell(cx, y_brim, 30, 6.5, "#0c0a0e", stroke=INK, sw=2.5)]
	b.append(group(g, tr=tr))


def lx_mob_front():
	b = [line(60, 0, 60, 14, "#c8c0b0", 2)]
	_hat(b, 60, 46)
	head = "M24 66 Q28 48 60 48 Q92 48 96 66 L97 92 Q96 104 86 106 L34 106 Q24 104 23 92 Z"
	b.append(path(head, "url(#mgreen)", stroke=INK, sw=3))
	b.append(group(path(head, "url(#mmetal)"), clip="mright"))
	b.append(line(60, 50, 60, 104, "#1a1a1a", 1.5, 0.6))
	b.append(path(head, stroke=INK, sw=3))
	# eyes: yellow slit eye + monocle / red camera eye
	b.append(circ(43, 66, 11, "#e2c33a", stroke=INK, sw=2.5))
	b.append(ell(43, 66, 2.6, 7.5, "#120c04"))
	b.append(circ(43, 66, 14, "none", stroke="#c8a040", sw=2.5))
	b.append(circ(77, 66, 11, "#141414", stroke=INK, sw=2.5))
	b.append(circ(77, 66, 7, "#d0102a"))
	b.append(circ(75, 63, 2.2, "#ffffff", op=0.8))
	# snout from the front, grin with teeth
	sn = "M28 88 Q60 78 92 88 L95 120 Q92 138 60 140 Q28 138 25 120 Z"
	b.append(path(sn, "#7aae56", stroke=INK, sw=3))
	b.append(group(path(sn, "#b4bcc0"), clip="mright"))
	b.append(path(sn, stroke=INK, sw=3))
	b.append(ell(50, 94, 4, 3, "#1a120c"))
	b.append(ell(70, 94, 4, 3, "#1a120c"))
	b.append(path("M28 112 Q60 128 92 112 Q60 136 28 112 Z", "#2a0a0a", stroke=INK, sw=2.5))
	for i in range(9):
		x = 34 + i * 6.6
		y = 114 + 12 * math.sin(math.pi * (x - 28) / 64.0) * 0.55
		b.append(poly([(x - 2.6, y - 1), (x + 2.6, y - 1), (x, y + 4.5)], "#f0ead8"))
	# bow tie
	b.append(poly([(60, 144), (44, 136), (44, 150)], "#8a1418", stroke=INK, sw=2))
	b.append(poly([(60, 144), (76, 136), (76, 150)], "#8a1418", stroke=INK, sw=2))
	b.append(circ(60, 144, 4, "#6a0e12", stroke=INK, sw=1.5))
	write("lx_mob_front", svg(120, 150, "\n".join(b), _mob_defs()))


def lx_mob_side():
	b = [line(52, 0, 46, 14, "#c8c0b0", 2)]
	_hat(b, 42, 48, tilt=-12)
	# cranium (metal side)
	b.append(ell(44, 74, 27, 25, "url(#mmetal)", stroke=INK, sw=3))
	b.append(path("M24 70 Q44 60 66 68", stroke="#4a5458", sw=1.5, op=0.7))
	b.append(circ(30, 86, 2, "#5a6266"))
	b.append(circ(40, 92, 2, "#5a6266"))
	b.append(circ(58, 62, 10, "#141414", stroke=INK, sw=2.5))
	b.append(circ(59, 62, 6.5, "#d0102a"))
	b.append(circ(57, 60, 2, "#ffffff", op=0.8))
	# long snout to the right + lower jaw + teeth
	b.append(path("M50 68 Q84 70 112 84 Q120 90 112 96 L52 100 Z", "url(#mmetal)", stroke=INK, sw=3))
	b.append(path("M50 100 L110 98 Q108 112 94 114 L48 114 Z", "#8a9498", stroke=INK, sw=3))
	b.append(path("M60 99 L108 97", stroke="#2a0a0a", sw=3))
	for i in range(8):
		x = 58 + i * 6.4
		b.append(poly([(x - 2.4, 97), (x + 2.4, 97), (x, 103)], "#f0ead8"))
		b.append(poly([(x + 0.8, 101), (x + 5.2, 101), (x + 3, 96)], "#f0ead8"))
	b.append(ell(108, 82, 4, 3, "#2a3034"))
	b.append(line(66, 76, 98, 84, "#4a5458", 1.4, 0.6))
	# bow tie (edge-on), tucked under the jaw
	b.append(poly([(40, 118), (28, 110), (30, 126)], "#8a1418", stroke=INK, sw=2))
	b.append(circ(42, 118, 4, "#6a0e12", stroke=INK, sw=1.5))
	write("lx_mob_side", svg(120, 150, "\n".join(b), _mob_defs()))


def lx_mob_back():
	rng = random.Random(9)
	b = [line(60, 0, 60, 14, "#c8c0b0", 2)]
	_hat(b, 60, 46)
	head = "M24 66 Q28 48 60 48 Q92 48 96 66 L97 96 Q94 120 60 124 Q26 120 23 96 Z"
	b.append(path(head, "url(#mgreen)", stroke=INK, sw=3))
	b.append(group(path(head, "url(#mmetal)"), clip="mleft"))
	for _ in range(10):
		x = rng.uniform(66, 92)
		y = rng.uniform(62, 112)
		b.append(path("M%s %s q4 -4 8 0" % (f(x), f(y)), stroke="#2c5422", sw=1.6, op=0.8))
	for y in (70, 90, 110):
		b.append(circ(34, y, 2, "#5a6266"))
	b.append(line(60, 50, 60, 122, "#1a1a1a", 1.5, 0.6))
	b.append(path(head, stroke=INK, sw=3))
	b.append(poly([(60, 134), (46, 128), (48, 146)], "#8a1418", stroke=INK, sw=2))
	b.append(poly([(60, 134), (74, 128), (72, 146)], "#8a1418", stroke=INK, sw=2))
	write("lx_mob_back", svg(120, 150, "\n".join(b), _mob_defs()))


# ------------------------------------------------------------------ props
def lx_lantern():
	defs = (rad("lglass", 0.5, 0.6, 0.6, [(0, "#fff2c8"), (0.5, "#f0c070", 0.9), (1, "#8a5a24", 0.8)])
		+ lin("lcap", 0, 0, 1, 0, [(0, "#14181a"), (0.5, "#4a5458"), (1, "#101314")]))
	b = [circ(35, 8, 6, "none", stroke="#1a1d1e", sw=3),
		path("M14 32 L35 14 L56 32 Z", "url(#lcap)", stroke=INK, sw=2.5),
		rect(14, 30, 42, 7, "#2a2e30", stroke=INK, sw=2),
		rect(18, 37, 34, 48, "url(#lglass)"),
		path("M35 52 Q42 64 35 74 Q28 64 35 52 Z", "#ffffff", op=0.9)]
	for x in (18, 35, 52):
		b.append(line(x, 37, x, 85, "#1a1614", 3))
	b.append(line(18, 60, 52, 60, "#1a1614", 2))
	b += [rect(13, 85, 44, 8, "#2a2e30", stroke=INK, sw=2), path("M18 93 L52 93 L46 102 L24 102 Z", "#1a1d1e", stroke=INK, sw=2)]
	write("lx_lantern", svg(70, 106, "\n".join(b), defs))


def lx_eye():
	W, H = 240, 150
	defs = (rad("lens", 0.5, 0.5, 0.5, [(0, "#ff6a4a"), (0.3, "#e0102a"), (0.75, BLOOD_H), (1, BLOOD_D)])
		+ lin("chrome", 0, 0, 0, 1, [(0, "#9aa4a8"), (0.5, "#2a3034"), (1, "#5a6468")]))
	b = [ell(120, 75, 116, 70, "#050505"),
		ell(120, 75, 94, 58, "none", stroke="url(#chrome)", sw=8, op=0.8),
		circ(120, 75, 52, "url(#lens)")]
	# aperture blades
	hexp = [(120 + 22 * math.cos(math.radians(30 + 60 * i)), 75 + 22 * math.sin(math.radians(30 + 60 * i))) for i in range(6)]
	for i in range(6):
		a, c = hexp[i], hexp[(i + 1) % 6]
		o1 = (120 + 52 * math.cos(math.radians(30 + 60 * i - 20)), 75 + 52 * math.sin(math.radians(30 + 60 * i - 20)))
		o2 = (120 + 52 * math.cos(math.radians(30 + 60 * (i + 1) - 20)), 75 + 52 * math.sin(math.radians(30 + 60 * (i + 1) - 20)))
		b.append(poly([a, o1, o2, c], "#5a0008", op=0.55, stroke="#2a0004", sw=1.2))
	b.append(poly(hexp, "#120000"))
	b.append(ell(100, 56, 13, 7, "#ffffff", op=0.75))
	b.append(ell(146, 96, 5, 3, "#ffffff", op=0.35))
	write("lx_eye", svg(W, H, "\n".join(b), defs))


def lx_snap_sil():
	"""Warden Snapjaw in a droopy nightcap, leaning out of the dark, one claw raised: 'shhh'.
	Eye socket centre at (620, 330) - the screen puts the glowing lx_eye there. The body runs on below the
	frame (H 1100) so its bottom edge never shows."""
	W, H = 1000, 1100
	rim = BLOOD_D
	b = []
	b.append(path("M20 1100 Q60 760 120 640 Q200 540 360 520 L700 520 Q900 560 960 800 Q990 940 1000 1100 Z", "#050404", stroke=rim, sw=6))
	head = "M300 420 Q260 300 380 250 L700 230 Q800 240 820 330 Q840 430 760 500 L520 540 Q330 540 300 420 Z"
	b.append(path(head, "#070505", stroke=rim, sw=6))
	b.append(path("M380 300 L80 330 Q40 345 50 380 L70 400 L400 430 Z", "#060404", stroke=rim, sw=5))
	b.append(path("M70 410 L420 440 L560 520 Q300 500 90 450 Z", "#040303", stroke=rim, sw=5))
	up = "M78 402"
	for i in range(14):
		x = 90 + i * 24
		up += " L%d %d L%d %s" % (x, 402 + 22 + (i % 2) * 6, x + 12, f(404 + i * 1.4))
	b.append(path(up, stroke="#b8b0a0", sw=3, op=0.75))
	# the nightcap: rises from the head, droops over to the right, pompom at the tip
	cap = "M400 262 Q430 120 560 70 Q700 30 800 120 Q880 200 900 330 Q860 250 800 200 Q760 230 700 240 Z"
	b.append(path(cap, "#060505", stroke=rim, sw=5))
	b.append(path("M392 270 Q560 220 712 236", stroke=rim, sw=16))
	b.append(path("M392 270 Q560 220 712 236", stroke="#0a0606", sw=10))
	b.append(circ(904, 352, 42, "#080606", stroke=rim, sw=5))
	for (x, y, r) in ((560, 120, 10), (660, 100, 8), (760, 160, 9), (520, 190, 7)):
		b.append(poly(star_pts(x, y, r, r * 0.45), "#2a0a0c", op=0.9))
	b.append(circ(620, 330, 64, "none", stroke="#6a5420", sw=7, op=0.7))
	b.append(path("M540 290 Q620 260 700 286", stroke="#1e2224", sw=10))
	# raised claw: "shhh"
	b.append(path("M130 1100 Q150 760 210 560 L238 470 Q246 450 262 470 L254 560 Q300 580 296 640 L290 1100 Z", "#050404", stroke=rim, sw=5))
	b.append(path("M238 470 L232 380 Q238 360 252 380 L262 470", "#050404", stroke=rim, sw=5))
	b.append(path("M236 384 Q244 366 252 384", stroke="#b8b0a0", sw=3, op=0.6))
	write("lx_snap_sil", svg(W, H, "\n".join(b)))


def lx_standby():
	rng = random.Random(909)
	W, H = 1280, 720
	b = [rect(0, 0, W, H, "#0b0b0c")]
	cols = ["#8a8a8a", "#8a8852", "#528888", "#528852", "#7c527c", "#885252", "#52528a"]
	bw = W / 7.0
	for i, c in enumerate(cols):
		b.append(rect(i * bw, 0, bw + 1, 400, c))
	for i in range(8):
		v = int(12 + i * 30)
		b.append(rect(i * W / 8.0, 400, W / 8.0 + 1, 70, "#%02x%02x%02x" % (v, v, v)))
	for i, c in enumerate(["#1e2a3a", "#d8d8d8", "#2a1e3a", "#0b0b0c", "#050505", "#0b0b0c", "#141414"]):
		b.append(rect(i * bw, 470, bw + 1, 250, c))
	b.append(rect(0, 0, W, H, "#000000", op=0.35))
	for _ in range(40):
		b.append(poly(blob(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(20, 80), rng, 12, 0.5, 0.6), "#000000", op=rng.uniform(0.08, 0.25)))
	# the circle: crescent moon + a sleeping Snapjaw in a nightcap, little Z's rising
	b.append(circ(640, 300, 214, "#0e0e12", op=0.9))
	b.append(circ(640, 300, 214, "none", stroke="#c8c8c8", sw=6, op=0.8))
	b.append(circ(640, 300, 170, "none", stroke="#c8c8c8", sw=2, op=0.35))
	b.append(line(426, 300, 854, 300, "#c8c8c8", 3, 0.4))
	b.append(line(640, 86, 640, 514, "#c8c8c8", 3, 0.4))
	b.append(path(crescent(560, 250, 92, 0.7, -35), "#d0d0c4", stroke="#7a7a74", sw=3))
	head = "M600 356 L740 340 Q780 336 790 356 Q796 380 770 390 L620 392 Q596 386 600 356 Z"
	b.append(path(head, "#3a3a3a", stroke="#a0a0a0", sw=4))
	b.append(path("M612 376 L780 372", stroke="#a0a0a0", sw=3))
	b.append(path("M700 344 Q720 300 760 296 Q800 296 824 330 Q800 316 780 322 Q770 336 760 344 Z", "#2c2c2c", stroke="#a0a0a0", sw=4))
	b.append(circ(828, 338, 12, "#d0d0d0"))
	b.append(path("M716 356 Q726 362 736 356", stroke="#d0d0d0", sw=3))
	for (x, y, s) in ((800, 268, 16), (830, 230, 12), (852, 200, 9)):
		b.append(path("M%s %s L%s %s L%s %s L%s %s" % (f(float(x)), f(float(y)), f(float(x + s)), f(float(y)), f(float(x)), f(float(y + s)), f(float(x + s)), f(float(y + s))), stroke="#d0d0d0", sw=3))
	write("lx_standby", svg(W, H, "\n".join(b)))


def lx_key():
	W = 420
	o = W / 2
	defs = (lin("brass", 0, 0, 1, 1, [(0, "#f0d488"), (0.45, "#b8903e"), (1, "#5a4018")])
		+ rad("hubk", 0.4, 0.35, 0.7, [(0, "#f6e0a0"), (0.6, "#a8823a"), (1, "#4a3414")]))
	b = []
	for s in (-1, 1):
		cx = o + s * 112
		lobe = "M%s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Z" % (
			f(o + s * 30.0), f(o - 30.0), f(cx), f(o - 150.0), f(o + s * 196.0), f(o - 60.0),
			f(o + s * 220.0), f(float(o)), f(o + s * 196.0), f(o + 60.0), f(cx), f(o + 150.0), f(o + s * 30.0), f(o + 30.0),
			f(o + s * 20.0), f(float(o)), f(o + s * 30.0), f(o - 30.0))
		b.append(path(lobe, "url(#brass)", stroke=INK, sw=7))
		inner = "M%s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Z" % (
			f(o + s * 70.0), f(o - 20.0), f(cx), f(o - 96.0), f(o + s * 160.0), f(o - 30.0),
			f(o + s * 176.0), f(float(o)), f(o + s * 160.0), f(o + 30.0), f(cx), f(o + 96.0), f(o + s * 70.0), f(o + 20.0))
		b.append(path(inner, "#120c06", stroke="#5a4018", sw=4))
		b.append(path("M%s %s Q%s %s %s %s" % (f(o + s * 44.0), f(o - 40.0), f(cx), f(o - 132.0), f(o + s * 182.0), f(o - 62.0)), stroke="#fff0c0", sw=4, op=0.5))
	b.append(circ(o, o, 56, "url(#hubk)", stroke=INK, sw=7))
	b.append(circ(o, o, 36, "none", stroke="#5a4018", sw=4))
	b.append(path("M%s %s L%s %s Q%s %s %s %s L%s %s Z" % (f(o - 26.0), f(o + 6.0), f(o + 14.0), f(o - 2.0), f(o + 26.0), f(o - 2.0), f(o + 22.0), f(o + 8.0), f(o - 22.0), f(o + 14.0)), "#5a4018"))
	b.append(rect(o - 10, o - 22, 16, 14, "#5a4018"))
	b.append(circ(o + 14, o + 4, 3, "#a01020"))
	for k in range(6):
		a = TAU * k / 6
		b.append(circ(o + math.cos(a) * 46, o + math.sin(a) * 46, 3.5, "#5a4018"))
	write("lx_key", svg(W, W, "\n".join(b), defs))


def _gear_path(cx, cy, r, n, depth):
	d = ""
	for i in range(n * 4):
		a = TAU * i / (n * 4)
		rr = r if (i % 4) in (1, 2) else r - depth
		d += ("M" if i == 0 else " L") + "%s %s" % (f(cx + rr * math.cos(a)), f(cy + rr * math.sin(a)))
	return d + " Z"


def lx_gear():
	W = 320
	o = W / 2
	defs = lin("gearg", 0, 0, 1, 1, [(0, "#7a6a40"), (0.5, "#4a3e22"), (1, "#221c10")])
	b = [path(_gear_path(o, o, 150, 18, 18), "url(#gearg)", stroke=INK, sw=4)]
	b.append(circ(o, o, 104, "#141210", stroke=INK, sw=3))
	for k in range(5):
		a = TAU * k / 5
		b.append(line(o, o, o + math.cos(a) * 104, o + math.sin(a) * 104, "#4a3e22", 22))
		b.append(line(o, o, o + math.cos(a) * 104, o + math.sin(a) * 104, "#2a2214", 4, 0.6))
	b.append(circ(o, o, 104, "none", stroke="#4a3e22", sw=14))
	b.append(circ(o, o, 34, "#5a4a28", stroke=INK, sw=4))
	b.append(circ(o, o, 12, "#141210"))
	write("lx_gear", svg(W, W, "\n".join(b), defs))


def lx_gearbox():
	rng = random.Random(71)
	W, H = 1280, 720
	defs = (lin("plate", 0, 0, 1, 1, [(0, "#262b2d"), (0.5, "#16191a"), (1, "#0a0c0d")])
		+ rad("dial", 0.45, 0.4, 0.7, [(0, "#e6dfcc"), (1, "#9a927e")])
		+ rad("sock", 0.5, 0.5, 0.5, [(0, "#000000"), (0.7, "#0a0b0b"), (1, "#3a4042")]))
	# plate with a window (left) showing the gears behind
	outer = "M0 0 L%d 0 L%d %d L0 %d Z" % (W, W, H, H)
	win = "M110 170 L420 170 L420 560 L110 560 Z"
	b = ['<path d="%s %s" fill="url(#plate)" fill-rule="evenodd"/>' % (outer, win)]
	b.append(rect(104, 164, 322, 402, "none", stroke="#3a4244", sw=10, rx=6))
	b.append(rect(104, 164, 322, 402, "none", stroke=INK, sw=3, rx=6))
	for x in range(30, W, 60):
		for y in (24, H - 24):
			b.append(circ(x, y, 5, "#3a4244", stroke=INK, sw=1.5))
	for y in range(84, H - 60, 60):
		for x in (24, W - 24):
			b.append(circ(x, y, 5, "#3a4244", stroke=INK, sw=1.5))
	b.append(line(560, 40, 560, 680, "#0a0c0d", 3, 0.7))
	b.append(line(900, 40, 900, 680, "#0a0c0d", 3, 0.7))
	# key socket
	b.append(circ(640, 360, 96, "#2a3032", stroke=INK, sw=4))
	b.append(circ(640, 360, 70, "url(#sock)", stroke="#5a6264", sw=3))
	# rocking dial (the needle is drawn in code at (1060, 250), r 110)
	b.append(circ(1060, 250, 124, "#2a3032", stroke=INK, sw=4))
	b.append(circ(1060, 250, 110, "url(#dial)", stroke=INK, sw=3))
	for k in range(11):
		a = math.radians(150 + k * 24)
		b.append(line(1060 + math.cos(a) * 92, 250 + math.sin(a) * 92, 1060 + math.cos(a) * 104, 250 + math.sin(a) * 104, "#2a2620", 4))
	a0, a1 = math.radians(342), math.radians(390)
	b.append(path("M%s %s A96 96 0 0 1 %s %s" % (f(1060 + math.cos(a0) * 96), f(250 + math.sin(a0) * 96), f(1060 + math.cos(a1) * 96), f(250 + math.sin(a1) * 96)), stroke="#8a0a14", sw=12))
	b.append(path(crescent(1030, 300, 16, 0.66, -40), "#3a3428"))
	b.append(poly(star_pts(1094, 300, 12, 5), "#3a3428"))
	# warning stripes
	b.append(rect(0, 600, W, 70, "#c8bf9a"))
	for x in range(-80, W + 80, 70):
		b.append(poly([(x, 670), (x + 35, 600), (x + 70, 600), (x + 35, 670)], "#121314"))
	b.append(rect(0, 596, W, 6, INK))
	b.append(rect(0, 668, W, 6, INK))
	# Snapjaw plaque
	b.append(rect(560, 60, 220, 90, "#1c2022", rx=8, stroke="#5a6264", sw=3))
	b.append(path("M590 118 L700 100 Q730 96 740 110 Q744 124 722 130 L604 132 Z", "#2c3a2a", stroke="#7a8284", sw=2.5))
	b.append(rect(640, 70, 40, 30, "#0c0c0c", stroke="#7a8284", sw=2))
	b.append(circ(706, 112, 5, "#c0102a"))
	for _ in range(30):
		b.append(poly(blob(rng.uniform(0, W), rng.uniform(0, 590), rng.uniform(8, 40), rng, 10, 0.5, 0.7), "#3a2a1a", op=rng.uniform(0.15, 0.4)))
	write("lx_gearbox", svg(W, H, "\n".join(b), defs))


def lx_nightcap():
	W, H = 240, 150
	defs = (lin("capg", 0, 0, 0, 1, [(0, "#4f72c0"), (0.6, "#3a5596"), (1, "#22355e")])
		+ lin("brim", 0, 0, 0, 1, [(0, "#f2eee4"), (1, "#b8b2a4")]))
	b = []
	cap = "M30 52 Q90 30 150 52 Q196 70 206 104 Q170 84 140 92 Q90 112 34 110 Z"
	b.append(path(cap, "url(#capg)", stroke=INK, sw=4))
	for (x, y, r) in ((72, 64, 7), (112, 58, 6), (150, 72, 6), (96, 92, 5), (176, 88, 5)):
		b.append(poly(star_pts(x, y, r, r * 0.45), "#e8e4d6", op=0.9))
	b.append(path("M24 46 Q14 82 30 116 L52 112 Q40 82 48 50 Z", "url(#brim)", stroke=INK, sw=4))
	for y in range(54, 112, 10):
		b.append(circ(36 + 4 * math.sin(y), y, 4, "#ffffff", op=0.5))
	b.append(circ(212, 110, 20, "#ece8de", stroke=INK, sw=4))
	b.append(circ(206, 104, 7, "#ffffff", op=0.7))
	b.append(path("M60 100 Q120 96 170 86", stroke="#16244a", sw=3, op=0.6))
	write("lx_nightcap", svg(W, H, "\n".join(b), defs))


def main():
	os.makedirs(OUT, exist_ok=True)
	for fn in (lx_cave, lx_stern, lx_stern_fg, lx_wheel, lx_wheel_stain, lx_cradle_back, lx_quilt, lx_quilt_empty,
			lx_cradle_front, lx_cradle_crack, lx_mob_front, lx_mob_side, lx_mob_back, lx_lantern, lx_eye, lx_snap_sil,
			lx_standby, lx_key, lx_gear, lx_gearbox, lx_nightcap):
		fn()


if __name__ == "__main__":
	main()
