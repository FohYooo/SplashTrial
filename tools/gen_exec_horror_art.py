#!/usr/bin/env python3
"""SPLASH TRIAL - horror execution art ("THE FINAL VANISHING ACT").

Writes art/props/hx_*.svg - the props for scripts/screens/execution_screen.gd:
  hx_tent        rotting big top at night (1280x720 backdrop: torn canvas, moon, poles, bleachers, ring)
  hx_curtain     tattered stage drape that hangs behind the cabinet
  hx_mq_front / hx_mq_back / hx_mq_side / hx_mq_body / hx_mq_hand   blank-faced gift-shop mannequin parts
  hx_cab_back / hx_cab_front / hx_cab_door / hx_cab_door_back       the tall magician's cabinet (layered)
  hx_blade, hx_chain, hx_padlock, hx_tophat, hx_monocle, hx_eye, hx_snap_sil, hx_standby,
  hx_splatter, hx_lamp, hx_spotcone

Usage (from the project root):  python3 tools/gen_exec_horror_art.py
Only SVG 1.1 basics are used (no text / filters / images / CSS) so Godot's ThorVG rasterizes it.
The geometry constants marked "shared with execution_screen.gd" must stay in sync with the screen.
"""
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "props")

# shared with execution_screen.gd (cabinet-local coordinates: origin = bottom centre of the 320x620 frame)
CAB_W, CAB_H = 320, 620
OPEN_X0, OPEN_X1, OPEN_Y0, OPEN_Y1 = 40, 280, 95, 575      # door opening inside the frame (svg coords)
BLADE_Y = (280, 370, 460)                                   # svg y of the three horizontal blade slots
VBLADE_X = 180                                              # svg x of the vertical blade slot (crown)
EYE_SLOT = (70, 104, 100, 34)                               # door-local x, y, w, h

BLOOD = "#7a0010"
BLOOD_D = "#3a0008"
BLOOD_H = "#b3001b"
BONE = "#d9ccb0"
BONE_S = "#b3a486"
BONE_D = "#8e7f63"
CRACK = "#5e5240"


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


def rect(x, y, w, h, fill, op=1.0, rx=0, stroke=None, sw=0):
	o = ' opacity="%s"' % f(op) if op < 1.0 else ""
	r = ' rx="%s"' % f(rx) if rx else ""
	s = ' stroke="%s" stroke-width="%s"' % (stroke, f(sw)) if stroke else ""
	return '<rect x="%s" y="%s" width="%s" height="%s" fill="%s"%s%s%s/>' % (f(x), f(y), f(w), f(h), fill, r, s, o)


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


TAU = math.pi * 2


def crack_path(x, y, rng, steps=5, ln=14, ang=1.2):
	d = "M%s %s" % (f(float(x)), f(float(y)))
	a = ang
	for _ in range(steps):
		a += rng.uniform(-0.6, 0.6)
		x += math.cos(a) * ln * rng.uniform(0.6, 1.2)
		y += math.sin(a) * ln * rng.uniform(0.6, 1.2)
		d += " L%s %s" % (f(float(x)), f(float(y)))
	return d


def write(name, content):
	p = os.path.join(OUT, name + ".svg")
	with open(p, "w") as fh:
		fh.write(content)
	print("wrote", os.path.relpath(p, ROOT))


# ------------------------------------------------------------------ backdrop
def hx_tent():
	rng = random.Random(1313)
	W, H = 1280, 720
	defs = []
	body = []
	defs.append(lin("sky", 0, 0, 0, 1, [(0, "#06100f"), (1, "#14282a")]))
	defs.append(rad("moon", 250, 120, 160, [(0, "#9fbfb2", 0.55), (0.35, "#3d5c57", 0.25), (1, "#0c1a1b", 0)], user=True))
	defs.append(lin("wallshade", 0, 0, 0, 1, [(0, "#000000", 0.0), (0.6, "#000000", 0.25), (1, "#000000", 0.7)]))
	defs.append(rad("floorlit", 640, 590, 430, [(0, "#3a3024"), (0.55, "#231b13"), (1, "#0d0a07")], user=True))
	defs.append(lin("pole", 0, 0, 1, 0, [(0, "#1a120b"), (0.45, "#3b2a1a"), (1, "#120c07")]))
	defs.append(lin("fog", 0, 0, 0, 1, [(0, "#9ab8b0", 0.0), (0.5, "#9ab8b0", 0.16), (1, "#9ab8b0", 0.0)]))
	defs.append(rad("topdark", 640, -80, 700, [(0, "#000000", 0.75), (0.5, "#000000", 0.3), (1, "#000000", 0.0)], user=True))
	body.append(rect(0, 0, W, H, "#050809"))
	# sky + moon (visible through the tears, which are drawn as sky-coloured holes later via a clip)
	tears = [
		[(150, 40), (230, 18), (330, 46), (360, 120), (318, 170), (250, 196), (205, 160), (160, 175), (130, 110)],
		[(860, 70), (905, 52), (960, 80), (948, 128), (910, 150), (872, 126)],
		[(1040, 160), (1090, 140), (1120, 175), (1100, 214), (1060, 220)],
		[(520, 20), (560, 8), (600, 30), (590, 70), (552, 82), (530, 60)],
	]
	def ragged(t):
		out = []
		for i in range(len(t)):
			(x0, y0), (x1, y1) = t[i], t[(i + 1) % len(t)]
			for k in range(4):
				u = k / 4.0
				j = 0 if k == 0 else rng.uniform(-7, 7)
				out.append((x0 + (x1 - x0) * u + j, y0 + (y1 - y0) * u + rng.uniform(-7, 7) * (k > 0)))
		return out
	tears = [ragged(t) for t in tears]
	clip = "".join('<polygon points="%s"/>' % pts(t) for t in tears)
	defs.append('<clipPath id="tears">%s</clipPath>' % clip)

	# roof wedges radiating from the apex down to the eave curve (lowest = farthest at the centre)
	def eave(x):
		return 262 - ((x - 640) / 640.0) ** 2 * 210

	def floorline(x):
		return 455 + ((x - 640) / 640.0) ** 2 * 150

	apex = (640, -230)
	xs = [640 + 1500 * math.tan(a) for a in [i * 0.055 for i in range(-14, 15)]]
	for i in range(len(xs) - 1):
		x0, x1 = xs[i], xs[i + 1]
		col = "#5a3a33" if i % 2 == 0 else "#6a624f"
		sag = 14 + 6 * math.sin(i * 1.7)
		mx = (x0 + x1) * 0.5
		d = "M%s %s L%s %s Q%s %s %s %s Z" % (f(float(apex[0])), f(float(apex[1])), f(x0), f(eave(x0)),
			f(mx), f(eave(mx) + sag), f(x1), f(eave(x1)))
		body.append(path(d, col))
		# grime streaks running down each panel
		for k in range(2):
			gx = rng.uniform(min(x0, x1), max(x0, x1))
			body.append(line(gx, eave(gx) - rng.uniform(60, 220), gx + rng.uniform(-6, 6), eave(gx) + 4, "#120a08", rng.uniform(3, 9), 0.35))
	# wall stripes between the eave and the floor line
	wx = [640 + 380 * math.tan(a) for a in [i * 0.11 for i in range(-13, 14)]]
	for i in range(len(wx) - 1):
		x0, x1 = wx[i], wx[i + 1]
		col = "#4a2e2a" if i % 2 == 0 else "#585141"
		p = [(x0, eave(x0)), (x1, eave(x1)), (x1, floorline(x1)), (x0, floorline(x0))]
		body.append(poly(p, col))
	# wall shading (darker near the floor) + eave rope with a scalloped valance
	body.append(path("M0 %s L1280 %s L1280 600 L0 600 Z" % (f(eave(0)), f(eave(1280))), "url(#wallshade)", op=0.8))
	val = "M0 %s" % f(eave(0) - 4)
	for i in range(33):
		xa = i * 40
		xb = xa + 40
		val += " Q%s %s %s %s" % (f(xa + 20.0), f(eave(xa + 20) + 26 + (8 if i % 3 == 0 else 0)), f(xb), f(eave(xb) - 4))
	val += " L1280 %s L0 %s Z" % (f(eave(1280) - 12), f(eave(0) - 12))
	body.append(path(val, "#2a1615"))
	body.append(path(" ".join(("M" if i == 0 else "L") + "%s %s" % (f(float(x)), f(eave(x) - 6)) for i, x in enumerate(range(0, 1290, 20))), stroke="#6d6450", sw=3, op=0.6))
	# stains / mould blotches
	for _ in range(26):
		x = rng.uniform(0, W)
		y = rng.uniform(0, 420)
		body.append(poly(blob(x, y, rng.uniform(14, 48), rng, 12, 0.45, 0.7), "#0d0806", op=rng.uniform(0.25, 0.55)))
	# the tears: sky + moon clipped to holes, ragged dark rims, hanging flaps
	body.append('<g clip-path="url(#tears)">%s%s%s</g>' % (rect(0, 0, W, 300, "url(#sky)"), circ(250, 120, 160, "url(#moon)"),
		circ(232, 104, 34, "#a8c4b6", 0.85)))
	for t in tears:
		body.append(poly(t, "none", stroke="#0b0605", sw=6))
		x, y = t[-2]
		body.append(poly([(x, y), (x + 26, y + 4), (x + 12, y + 58), (x - 2, y + 40)], "#3a2b24"))
	# trapeze (empty) + rigging
	body.append(line(760, 0, 772, 205, "#1c1510", 3))
	body.append(line(826, 0, 818, 205, "#1c1510", 3))
	body.append(rect(762, 202, 66, 8, "#2a2016", rx=3))
	for x0, y0, x1, y1 in ((330, 60, 640, -40), (950, 60, 640, -40), (330, 120, 0, 40), (950, 120, 1280, 30), (330, 200, 950, 200)):
		body.append(line(x0, y0, x1, y1, "#140e0a", 3, 0.9))
	# torn bunting along the cross rope
	for i in range(14):
		x = 350 + i * 43
		y = 200 + math.sin(i * 0.45) * 3
		if i in (4, 9):
			continue
		col = "#4a2a28" if i % 2 else "#4f4a3a"
		dy = rng.uniform(22, 34)
		body.append(poly([(x, y), (x + 28, y + 1), (x + 15 + rng.uniform(-6, 6), y + dy)], col, op=0.9))
	# floor
	body.append(path("M0 %s Q640 %s 1280 %s L1280 720 L0 720 Z" % (f(floorline(0)), f(floorline(640) - 150 * 0.0), f(floorline(1280))), "#0a0806"))
	body.append(ell(640, 602, 520, 128, "#3d1414"))
	for i in range(36):
		a0 = TAU * i / 36
		a1 = TAU * (i + 0.5) / 36
		if rng.random() < 0.3:
			continue
		p = [(640 + 520 * math.cos(a0), 602 + 128 * math.sin(a0)), (640 + 498 * math.cos((a0 + a1) / 2), 602 + 118 * math.sin((a0 + a1) / 2)),
			(640 + 520 * math.cos(a1), 602 + 128 * math.sin(a1)), (640 + 542 * math.cos((a0 + a1) / 2), 602 + 138 * math.sin((a0 + a1) / 2))]
		body.append(poly(p, "#6a624e", op=0.7))
	body.append(ell(640, 600, 494, 114, "url(#floorlit)"))
	for _ in range(80):
		x = rng.uniform(170, 1110)
		y = rng.uniform(500, 700)
		if ((x - 640) / 494.0) ** 2 + ((y - 600) / 114.0) ** 2 < 1:
			body.append(ell(x, y, rng.uniform(2, 7), rng.uniform(1, 2), "#4a3c2c", op=0.5))
	# bleachers (left + right): stepped planks receding into the dark
	for side in (-1, 1):
		for k, (y, x_in) in enumerate(((330, 300), (392, 330), (454, 352), (516, 372))):
			x_out = 640 + side * 700
			xi = 640 + side * (640 - x_in)
			p = [(xi, y), (x_out, y - 30), (x_out, y - 12), (xi, y + 12)]
			body.append(poly(p, "#2a1e14"))
			body.append(poly([(xi, y + 12), (x_out, y - 12), (x_out, y + 40), (xi, y + 60)], "#120d09"))
			for j in range(5):
				sx = xi + side * (j * 70 + 10)
				body.append(line(sx, y + 12, sx, y + 60, "#0a0705", 4, 0.8))
	# king poles
	for x in (330, 950):
		body.append(rect(x - 13, 0, 26, 520, "url(#pole)"))
		for y in (120, 128, 300, 308):
			body.append(rect(x - 15, y, 30, 4, "#4d4434", op=0.8))
	# fog bands near the floor + darkness pooling under the roof
	body.append(rect(0, 410, W, 140, "url(#fog)"))
	body.append(rect(0, 520, W, 120, "url(#fog)", op=0.6))
	body.append(rect(0, 0, W, 520, "url(#topdark)"))
	write("hx_tent", svg(W, H, "\n".join(body), "".join(defs)))


def hx_curtain():
	rng = random.Random(77)
	W, H = 470, 380
	defs = [lin("fold", 0, 0, 1, 0, [(0, "#24100f"), (0.5, "#3b1c1d"), (1, "#1c0b0b")])]
	defs.append(lin("cshade", 0, 0, 0, 1, [(0, "#000000", 0.0), (1, "#000000", 0.6)]))
	body = []
	n = 9
	for i in range(n):
		x0 = i * W / n
		wv = W / n + 2
		bottom = H - 30 + rng.uniform(-10, 30)
		p = "M%s 30 L%s 30 L%s %s" % (f(x0), f(x0 + wv), f(x0 + wv - rng.uniform(0, 6)), f(bottom))
		for k in range(4):
			bx = x0 + wv - (k + 1) * wv / 5
			p += " L%s %s" % (f(bx), f(bottom + rng.uniform(-24, 12)))
		p += " L%s %s Z" % (f(x0 + rng.uniform(0, 6)), f(bottom - rng.uniform(0, 20)))
		body.append('<path d="%s" fill="url(#fold)"/>' % p)
	# holes
	for _ in range(7):
		body.append(poly(blob(rng.uniform(30, W - 30), rng.uniform(90, H - 60), rng.uniform(5, 16), rng, 10, 0.5), "#060303"))
	body.append(rect(0, 30, W, H - 30, "url(#cshade)"))
	# sagging valance + tarnished fringe
	val = "M0 0 L%d 0 L%d 46" % (W, W)
	for i in range(8, 0, -1):
		xa = i * W / 8
		xb = (i - 1) * W / 8
		val += " Q%s %s %s %s" % (f((xa + xb) / 2), f(80.0 + (6 if i % 2 else 0)), f(xb), f(46.0))
	val += " Z"
	body.append(path(val, "#2c1416"))
	for i in range(40):
		x = 6 + i * (W - 12) / 39
		y = 46 + 28 * math.sin(math.pi * ((x % (W / 8)) / (W / 8)))
		body.append(line(x, y, x + rng.uniform(-2, 2), y + rng.uniform(6, 14), "#6b5a34", 2.5, 0.8))
	write("hx_curtain", svg(W, H, "\n".join(body), "".join(defs)))


# ------------------------------------------------------------------ mannequins
def _mq_defs(light_x=0.35):
	return (rad("mqg", light_x, 0.3, 0.75, [(0, "#efe4c8"), (0.55, BONE), (1, BONE_S)])
		+ lin("mqshade", 0, 0, 1, 1, [(0, "#000000", 0.0), (0.6, "#000000", 0.0), (1, "#000000", 0.35)]))


def hx_mq_front():
	rng = random.Random(5)
	b = []
	# neck
	b.append(rect(80, 160, 40, 40, BONE_S))
	b.append(rect(80, 186, 40, 6, BONE_D, op=0.6))
	# tiny capybara ears tucked high on the sides
	for x in (48, 152):
		b.append(ell(x, 34, 10, 8, BONE_S, stroke=BONE_D, sw=2))
	head = "M50 48 Q52 20 100 18 Q148 20 150 48 L156 112 Q160 150 152 170 Q140 186 100 186 Q60 186 48 170 Q40 150 44 112 Z"
	b.append(path(head, "url(#mqg)", stroke=BONE_D, sw=2.5))
	b.append(path(head, "url(#mqshade)"))
	# the big blunt muzzle block - but no nostrils, no mouth, no eyes
	b.append(path("M50 116 Q100 100 150 116 L154 160 Q148 182 100 182 Q52 182 46 160 Z", "#ffffff", op=0.12))
	b.append(path("M52 116 Q100 100 148 116", stroke=BONE_D, sw=2, op=0.4))
	b.append(path("M100 108 L100 182", stroke=BONE_D, sw=1.2, op=0.25))
	# barely-there sockets set high, like a capybara's - "almost" a face
	b.append(ell(68, 66, 11, 8, "#5a4c38", op=0.14))
	b.append(ell(132, 66, 11, 8, "#5a4c38", op=0.14))
	b.append(line(100, 20, 100, 104, BONE_D, 1.2, 0.3))
	for _ in range(3):
		b.append(path(crack_path(rng.uniform(50, 150), rng.uniform(34, 60), rng, 5, 12, rng.uniform(1.0, 2.0)), stroke=CRACK, sw=1.4, op=0.7))
	write("hx_mq_front", svg(200, 200, "\n".join(b), _mq_defs()))


def hx_mq_back():
	rng = random.Random(6)
	b = []
	b.append(rect(80, 160, 40, 40, BONE_S))
	for x in (50, 150):
		b.append(ell(x, 34, 10, 8, BONE_S, stroke=BONE_D, sw=2))
	head = "M50 48 Q52 20 100 18 Q148 20 150 48 L156 112 Q160 150 152 168 Q140 180 100 180 Q60 180 48 168 Q40 150 44 112 Z"
	b.append(path(head, "url(#mqg)", stroke=BONE_D, sw=2.5))
	b.append(path(head, "url(#mqshade)"))
	b.append(line(100, 28, 100, 172, BONE_D, 1.4, 0.45))
	b.append(circ(100, 164, 5, "#6a6050", stroke="#4a4234", sw=1.5))
	for _ in range(2):
		b.append(path(crack_path(rng.uniform(60, 140), rng.uniform(40, 80), rng, 4, 12, 1.4), stroke=CRACK, sw=1.4, op=0.6))
	write("hx_mq_back", svg(200, 200, "\n".join(b), _mq_defs(0.5)))


def hx_mq_side():
	rng = random.Random(7)
	b = []
	b.append(rect(70, 158, 40, 42, BONE_S))
	b.append(ell(58, 36, 11, 9, BONE_S, stroke=BONE_D, sw=2))
	head = "M24 92 Q22 34 80 30 L150 46 Q184 58 186 100 L186 132 Q184 156 160 158 L100 172 Q40 170 28 136 Z"
	b.append(path(head, "url(#mqg)", stroke=BONE_D, sw=2.5))
	b.append(path(head, "url(#mqshade)"))
	b.append(path("M120 150 Q150 152 182 136", stroke=BONE_D, sw=2, op=0.35))
	b.append(path(crack_path(60, 50, rng, 4, 12, 1.3), stroke=CRACK, sw=1.3, op=0.6))
	write("hx_mq_side", svg(200, 200, "\n".join(b), _mq_defs(0.6)))


def hx_mq_body():
	b = []
	d = "M98 0 L142 0 L146 18 Q214 28 232 70 L240 170 L0 170 L8 70 Q26 28 94 18 Z"
	b.append(path(d, "url(#mqg)", stroke=BONE_D, sw=2.5))
	b.append(path(d, "url(#mqshade)"))
	b.append(path("M120 22 L120 170", stroke=BONE_D, sw=1.5, op=0.4))
	b.append(path("M30 90 Q120 112 210 90", stroke=BONE_D, sw=1.5, op=0.3))
	b.append(ell(120, 8, 24, 8, "#6a6050", op=0.8))
	write("hx_mq_body", svg(240, 170, "\n".join(b), _mq_defs(0.4)))


def hx_mq_hand():
	b = [path("M8 30 Q4 8 24 6 L44 8 Q58 12 56 28 Q54 46 32 46 Q10 46 8 30 Z", "url(#mqg)", stroke=BONE_D, sw=2),
		path("M20 12 L18 30 M30 10 L29 30 M40 12 L40 30", stroke=BONE_D, sw=1.2, op=0.45)]
	write("hx_mq_hand", svg(60, 52, "\n".join(b), _mq_defs(0.4)))


# ------------------------------------------------------------------ cabinet
def _peel(rng, x0, y0, x1, y1, n, col="#4b3624"):
	out = []
	for _ in range(n):
		x = rng.uniform(x0, x1)
		y = rng.uniform(y0, y1)
		out.append(poly(blob(x, y, rng.uniform(4, 13), rng, 9, 0.5, 0.8), col, op=rng.uniform(0.6, 0.95)))
	return out


def hx_cab_back():
	rng = random.Random(21)
	defs = lin("inner", 0, 0, 0, 1, [(0, "#1d1426"), (0.5, "#0f0a14"), (1, "#050307")])
	b = [rect(OPEN_X0 - 4, OPEN_Y0 - 4, OPEN_X1 - OPEN_X0 + 8, OPEN_Y1 - OPEN_Y0 + 8, "url(#inner)")]
	for x in range(OPEN_X0 + 30, OPEN_X1, 30):
		b.append(line(x, OPEN_Y0, x, OPEN_Y1, "#000000", 2, 0.5))
	for y in BLADE_Y:
		b.append(rect(OPEN_X0, y - 4, OPEN_X1 - OPEN_X0, 8, "#000000", op=0.7))
	for _ in range(6):
		b.append(poly(star_pts(rng.uniform(70, 250), rng.uniform(130, 500), 9, 4), "#4a4a56", op=0.25))
	# floor of the cabinet
	b.append(rect(OPEN_X0, OPEN_Y1 - 22, OPEN_X1 - OPEN_X0, 22, "#140d10"))
	write("hx_cab_back", svg(CAB_W, CAB_H, "\n".join(b), defs))


def hx_cab_front():
	rng = random.Random(22)
	defs = (lin("plum", 0, 0, 1, 0, [(0, "#2a1633"), (0.5, "#4a2a58"), (1, "#24122c")])
		+ lin("crown", 0, 0, 0, 1, [(0, "#3e2248"), (1, "#26132e")])
		+ lin("silver", 0, 0, 1, 1, [(0, "#a7aeae"), (1, "#5d6464")])
		+ lin("gold", 0, 0, 1, 0, [(0, "#5a4a26"), (0.5, "#9a8344"), (1, "#4a3c1e")]))
	b = []
	# posts
	for x in (0, OPEN_X1):
		b.append(rect(x, 70, 40, 520, "url(#plum)"))
		b.append(rect(x + 4, 74, 4, 512, "#6b4a7a", op=0.4))
		for y in BLADE_Y:
			b.append(rect(x, y - 5, 40, 10, "#020102"))
			b.append(rect(x, y + 5, 40, 2, "#6b4a7a", op=0.4))
	# crown: arched pediment with a crescent + star
	crown = "M-4 96 L-4 58 Q20 56 34 40 Q90 -8 160 -2 Q230 -8 286 40 Q300 56 324 58 L324 96 Z"
	b.append(path(crown, "url(#crown)", stroke="#120814", sw=3))
	b.append(path("M6 88 L314 88", stroke="url(#gold)", sw=6))
	b.append(path("M18 60 Q90 10 160 8 Q230 10 302 60", stroke="url(#gold)", sw=4, op=0.8))
	b.append(circ(160, 50, 26, "url(#silver)"))
	b.append(circ(170, 44, 23, "#2e1838"))
	b.append(poly(star_pts(128, 52, 11, 5), "url(#silver)"))
	b.append(rect(VBLADE_X - 5, 0, 10, 92, "#020102"))
	# base plinth + feet
	b.append(rect(-6, 572, 332, 30, "url(#crown)", stroke="#120814", sw=3))
	b.append(path("M-4 578 L324 578", stroke="url(#gold)", sw=4, op=0.8))
	for x in (8, 92, 208, 292):
		b.append(path("M%d 600 L%d 600 L%d 620 L%d 620 Z" % (x, x + 20, x + 16, x + 4), "#1a0e1e"))
	b += _peel(rng, 0, 80, 40, 570, 6)
	b += _peel(rng, OPEN_X1, 80, 320, 570, 6)
	b += _peel(rng, 10, 20, 310, 90, 5)
	for _ in range(5):
		b.append(path(crack_path(rng.uniform(0, 320), rng.uniform(70, 560), rng, 4, 10, 1.57), stroke="#0a050c", sw=1.5, op=0.7))
	write("hx_cab_front", svg(CAB_W, CAB_H, "\n".join(b), defs))


def hx_cab_door():
	rng = random.Random(23)
	W, H = OPEN_X1 - OPEN_X0, OPEN_Y1 - OPEN_Y0
	defs = (lin("dplum", 0, 0, 1, 1, [(0, "#4f2d5e"), (0.6, "#3a2046"), (1, "#26132e")])
		+ lin("dsilver", 0, 0, 1, 1, [(0, "#9aa1a1"), (1, "#545b5b")]))
	sx, sy, sw_, sh = EYE_SLOT
	outer = "M0 0 L%d 0 L%d %d L0 %d Z" % (W, W, H, H)
	hole = "M%d %d L%d %d L%d %d L%d %d Z" % (sx, sy, sx, sy + sh, sx + sw_, sy + sh, sx + sw_, sy)
	b = ['<path d="%s %s" fill="url(#dplum)" fill-rule="evenodd"/>' % (outer, hole)]
	# inset panels
	b.append(rect(18, 160, W - 36, H - 190, "none", stroke="#1c0e22", sw=4, rx=6))
	b.append(rect(22, 164, W - 44, H - 198, "none", stroke="#6b4a7a", sw=1.5, rx=5, op=0.5))
	# eye slot frame (dark recess)
	b.append(rect(sx - 8, sy - 8, sw_ + 16, sh + 16, "none", stroke="#140a18", sw=8, rx=3))
	b.append(rect(sx - 12, sy - 12, sw_ + 24, sh + 24, "none", stroke="#7a5a88", sw=1.5, rx=4, op=0.45))
	# blade slits across the door
	for y in BLADE_Y:
		yy = y - OPEN_Y0
		b.append(rect(0, yy - 4, W, 8, "#030103"))
		b.append(rect(0, yy + 4, W, 2, "#6b4a7a", op=0.35))
	b.append(rect(VBLADE_X - OPEN_X0 - 4, 0, 8, 60, "#030103", op=0.0))
	# tarnished stars (some half peeled)
	for (x, y, r) in ((50, 60, 14), (190, 66, 11), (120, 220, 18), (60, 320, 12), (180, 330, 15), (110, 420, 13)):
		b.append(poly(star_pts(x, y, r, r * 0.45), "url(#dsilver)", op=0.75))
		if rng.random() < 0.5:
			b.append(poly(blob(x + r * 0.3, y, r * 0.55, rng, 8, 0.4), "#3a2046"))
	b += _peel(rng, 6, 6, W - 6, H - 6, 12)
	# hinges (left) and hasp (right)
	for y in (40, H - 60):
		b.append(rect(-2, y, 22, 34, "#26282a", stroke="#0a0a0a", sw=2, rx=2))
		b.append(circ(9, y + 9, 2.5, "#707676"))
		b.append(circ(9, y + 25, 2.5, "#707676"))
	b.append(rect(W - 26, H / 2 - 22, 24, 44, "#2a2c2e", stroke="#0a0a0a", sw=2, rx=3))
	b.append(circ(W - 14, H / 2, 6, "#0a0a0a"))
	for _ in range(5):
		b.append(path(crack_path(rng.uniform(10, W - 10), rng.uniform(10, H - 10), rng, 4, 11, rng.uniform(0, TAU)), stroke="#120818", sw=1.4, op=0.7))
	write("hx_cab_door", svg(W, H, "\n".join(b), defs))


def hx_cab_door_back():
	W, H = OPEN_X1 - OPEN_X0, OPEN_Y1 - OPEN_Y0
	defs = lin("wood", 0, 0, 1, 0, [(0, "#1e140e"), (0.5, "#2e2016"), (1, "#18100b")])
	b = [rect(0, 0, W, H, "url(#wood)")]
	for x in range(30, W, 30):
		b.append(line(x, 0, x, H, "#0a0604", 2))
	b.append(path("M10 30 L%d %d" % (W - 10, H - 30), stroke="#3a2a1c", sw=16))
	b.append(rect(0, 20, W, 18, "#2a1d14"))
	b.append(rect(0, H - 40, W, 18, "#2a1d14"))
	sx, sy, sw_, sh = EYE_SLOT
	b.append(rect(W - sx - sw_, sy, sw_, sh, "#000000"))
	write("hx_cab_door_back", svg(W, H, "\n".join(b), defs))


# ------------------------------------------------------------------ props
def hx_blade():
	W, H = 700, 56
	defs = (lin("steel", 0, 0, 0, 1, [(0, "#4a565a"), (0.45, "#2c3437"), (1, "#161c1e")])
		+ lin("grip", 0, 0, 0, 1, [(0, "#2a201a"), (1, "#0e0a08")]))
	cy = 28
	b = [circ(12, cy, 11, "#2a2c2e", stroke="#0a0a0a", sw=2),
		rect(18, cy - 9, 96, 18, "url(#grip)", rx=4)]
	for x in range(26, 112, 12):
		b.append(line(x, cy - 9, x + 6, cy + 9, "#050403", 2, 0.8))
	b.append(rect(112, 4, 14, 48, "#2a2e30", stroke="#0a0a0a", sw=2, rx=3))
	b.append(line(114, 7, 114, 49, "#7fb8b4", 1.5, 0.6))
	b.append(poly([(126, cy - 13), (640, cy - 9), (700, cy), (640, cy + 9), (126, cy + 13)], "url(#steel)", stroke="#0a0d0e", sw=1.5))
	b.append(line(130, cy + 11, 690, cy + 1, "#a8dcd6", 1.6, 0.75))
	b.append(line(130, cy - 3, 600, cy - 2, "#0e1214", 2.5, 0.8))
	write("hx_blade", svg(W, H, "\n".join(b), defs))


def hx_chain():
	W, H = 560, 44
	b = []
	x = 14
	i = 0
	while x < W - 14:
		if i % 2 == 0:
			b.append(ell(x + 18, 22, 21, 14, "none", stroke="#1a1c1e", sw=9))
			b.append(ell(x + 18, 22, 21, 14, "none", stroke="#6a7070", sw=3))
		else:
			b.append(rect(x - 4, 18, 44, 9, "#2a2d2f", rx=4, stroke="#0a0a0a", sw=1.5))
			b.append(line(x, 20, x + 36, 20, "#8a9292", 1.5, 0.7))
		x += 34
		i += 1
	write("hx_chain", svg(W, H, "\n".join(b)))


def hx_padlock():
	defs = lin("brass", 0, 0, 1, 1, [(0, "#8a7a4a"), (1, "#3e3420")])
	b = [path("M24 50 L24 30 Q24 8 45 8 Q66 8 66 30 L66 50", stroke="#2a2c2e", sw=10),
		path("M24 50 L24 30 Q24 8 45 8 Q66 8 66 30 L66 50", stroke="#7a8080", sw=3, op=0.6),
		rect(8, 46, 74, 58, "url(#brass)", rx=10, stroke="#14100a", sw=3),
		circ(45, 70, 7, "#0a0806"), rect(42, 72, 6, 16, "#0a0806")]
	write("hx_padlock", svg(90, 110, "\n".join(b), defs))


def hx_tophat():
	defs = (lin("felt", 0, 0, 1, 0, [(0, "#100d14"), (0.4, "#2e2738"), (0.75, "#1a1620"), (1, "#0a080c")])
		+ lin("band", 0, 0, 0, 1, [(0, "#5f3d7e"), (1, "#3a2450")]))
	b = [ell(110, 196, 104, 14, "#000000", op=0.5),
		ell(110, 186, 100, 18, "#0c0a0f", stroke="#000000", sw=3),
		path("M50 184 L56 40 Q58 22 110 22 Q162 22 164 40 L170 184 Z", "url(#felt)", stroke="#000000", sw=3),
		path("M60 70 Q86 82 104 64 Q120 50 150 64", stroke="#000000", sw=3, op=0.5),
		path("M52 150 L168 150 L170 182 L50 182 Z", "url(#band)"),
		poly(star_pts(132, 166, 11, 5), "#9aa1a1", op=0.85),
		path("M70 46 L66 140", stroke="#3a3446", sw=5, op=0.5)]
	for x, y in ((80, 60), (140, 110), (98, 128)):
		b.append(ell(x, y, 10, 5, "#4a4450", op=0.25))
	write("hx_tophat", svg(220, 210, "\n".join(b), defs))


def hx_monocle():
	defs = (lin("mgold", 0, 0, 1, 1, [(0, "#e0c070"), (0.5, "#a8883a"), (1, "#5a4618")])
		+ rad("glass", 0.35, 0.3, 0.8, [(0, "#ffffff", 0.55), (0.4, "#bfe8e4", 0.18), (1, "#7fb0b0", 0.08)]))
	b = [circ(50, 50, 34, "url(#glass)"),
		circ(50, 50, 34, "none", stroke="#2a200a", sw=10),
		circ(50, 50, 34, "none", stroke="url(#mgold)", sw=6),
		path("M30 30 Q40 22 52 22", stroke="#ffffff", sw=3, op=0.6)]
	d = "M76 74"
	for k in range(9):
		d += " L%s %s" % (f(80 + k * 3.0 + 4 * math.sin(k)), f(82 + k * 9.0))
	b.append(path(d, stroke="#2a200a", sw=5))
	b.append(path(d, stroke="url(#mgold)", sw=2.5))
	write("hx_monocle", svg(120, 170, "\n".join(b), defs))


def hx_eye():
	W, H = 240, 150
	defs = (rad("iris", 0.5, 0.5, 0.5, [(0, "#ff5a3a"), (0.35, "#e0102a"), (0.75, BLOOD_H), (1, BLOOD_D)])
		+ lin("chrome", 0, 0, 0, 1, [(0, "#9aa4a8"), (0.5, "#2a3034"), (1, "#5a6468")]))
	b = [ell(120, 75, 116, 70, "#050505"),
		ell(120, 75, 96, 56, "none", stroke="url(#chrome)", sw=7, op=0.75),
		ell(120, 75, 80, 46, "url(#iris)"),
		path("M120 34 Q132 75 120 116 Q108 75 120 34 Z", "#050000"),
		ell(96, 56, 12, 7, "#ffffff", op=0.8),
		ell(146, 96, 5, 3, "#ffffff", op=0.35)]
	for i in range(14):
		a = TAU * i / 14
		b.append(line(120 + 30 * math.cos(a), 75 + 18 * math.sin(a), 120 + 74 * math.cos(a), 75 + 42 * math.sin(a), "#5a0008", 2, 0.45))
	write("hx_eye", svg(W, H, "\n".join(b), defs))


def hx_snap_sil():
	"""Warden Snapjaw looming out of the dark: near-black silhouette, red rim light, glinting teeth.
	Eye socket centre at (620, 330) - the screen puts the glowing hx_eye there."""
	W, H = 1000, 800
	rim = BLOOD_D
	b = []
	# shoulders
	b.append(path("M60 800 Q120 560 360 520 L700 520 Q900 560 960 800 Z", "#050404", stroke=rim, sw=6))
	# head (3/4 view, snout to the left)
	head = "M300 420 Q260 300 380 250 L700 230 Q800 240 820 330 Q840 430 760 500 L520 540 Q330 540 300 420 Z"
	b.append(path(head, "#070505", stroke=rim, sw=6))
	# long snout reaching left + jaw
	snout = "M380 300 L80 330 Q40 345 50 380 L70 400 L400 430 Z"
	b.append(path(snout, "#060404", stroke=rim, sw=5))
	jaw = "M70 410 L420 440 L560 520 Q300 500 90 450 Z"
	b.append(path(jaw, "#040303", stroke=rim, sw=5))
	# teeth glint (upper + lower zigzags)
	up = "M78 402"
	for i in range(14):
		x = 90 + i * 24
		up += " L%d %d L%d %d" % (x, 402 + 22 + (i % 2) * 6, x + 12, 404 + i * 1.4)
	b.append(path(up, stroke="#b8b0a0", sw=3, op=0.75))
	lo = "M96 448"
	for i in range(12):
		x = 104 + i * 26
		lo += " L%d %d L%d %d" % (x, 432 - (i % 2) * 5, x + 13, 450 + i * 2.2)
	b.append(path(lo, stroke="#8a8478", sw=3, op=0.6))
	# top hat
	b.append(path("M430 250 L460 40 Q470 20 560 22 Q650 24 652 44 L668 238 Z", "#060505", stroke=rim, sw=5))
	b.append(ell(550, 246, 190, 26, "#070606", stroke=rim, sw=5))
	b.append(rect(452, 196, 214, 26, "#1a0306", op=0.9))
	# monocle ring around the eye socket, faint gold
	b.append(circ(620, 330, 64, "none", stroke="#6a5420", sw=7, op=0.7))
	b.append(path("M676 362 Q700 470 660 560", stroke="#4a3a14", sw=4, op=0.6))
	# brow plate
	b.append(path("M540 290 Q620 260 700 286", stroke="#1e2224", sw=10))
	write("hx_snap_sil", svg(W, H, "\n".join(b)))


def hx_standby():
	rng = random.Random(99)
	W, H = 1280, 720
	cols = ["#8c8c8c", "#8c8a4e", "#4e8a8a", "#4e8a4e", "#7e4e7e", "#8a4e4e", "#4e4e8a"]
	b = [rect(0, 0, W, H, "#0b0b0c")]
	bw = W / 7.0
	for i, c in enumerate(cols):
		b.append(rect(i * bw, 0, bw + 1, 470, c))
	inv = ["#4e4e8a", "#0b0b0c", "#7e4e7e", "#0b0b0c", "#4e8a8a", "#0b0b0c", "#8c8c8c"]
	for i, c in enumerate(inv):
		b.append(rect(i * bw, 470, bw + 1, 60, c))
	for i, c in enumerate(["#1e2a3a", "#e0e0e0", "#2a1e3a", "#0b0b0c", "#050505", "#0b0b0c", "#141414"]):
		b.append(rect(i * bw, 530, bw + 1, 190, c))
	# grime
	b.append(rect(0, 0, W, H, "#000000", op=0.35))
	for _ in range(40):
		b.append(poly(blob(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(20, 80), rng, 12, 0.5, 0.6), "#000000", op=rng.uniform(0.08, 0.25)))
	# centre circle + crosshair + Snapjaw TV logo (caiman head in a top hat)
	b.append(circ(640, 300, 210, "#101012", op=0.85))
	b.append(circ(640, 300, 210, "none", stroke="#c8c8c8", sw=6, op=0.8))
	b.append(line(430, 300, 850, 300, "#c8c8c8", 3, 0.5))
	b.append(line(640, 90, 640, 510, "#c8c8c8", 3, 0.5))
	logo = "M520 330 L660 312 Q700 300 730 320 Q760 350 730 372 L560 372 Q520 366 520 330 Z"
	b.append(path(logo, "#3a3a3a", stroke="#9a9a9a", sw=4))
	b.append(path("M540 352 L720 352", stroke="#9a9a9a", sw=3))
	b.append(path("M640 312 L652 196 L736 196 L744 312 Z", "#2a2a2a", stroke="#9a9a9a", sw=4))
	b.append(ell(694, 314, 70, 10, "#2a2a2a", stroke="#9a9a9a", sw=4))
	b.append(circ(708, 336, 9, "#b3001b"))
	write("hx_standby", svg(W, H, "\n".join(b)))


def hx_splatter():
	rng = random.Random(4242)
	W, H = 520, 420
	cx, cy = 250, 200
	b = []
	# main splash: a blob with spikes + a darker core
	p = []
	for i in range(40):
		a = TAU * i / 40
		r = 92 * (1 + rng.uniform(-0.25, 0.25))
		if i % 5 == 0:
			r *= rng.uniform(1.5, 2.1)
		p.append((cx + r * math.cos(a), cy + r * math.sin(a) * 0.82))
	b.append(poly(p, BLOOD))
	b.append(poly(blob(cx - 10, cy + 6, 52, rng, 16, 0.3, 0.8), BLOOD_D, op=0.85))
	# droplets flung outwards along rays, getting smaller
	for k in range(26):
		a = rng.uniform(0, TAU)
		d = rng.uniform(120, 230)
		r = max(2.0, 16 * (1 - (d - 110) / 140.0) * rng.uniform(0.5, 1.1))
		x, y = cx + d * math.cos(a), cy + d * math.sin(a) * 0.82
		if 4 < x < W - 4 and 4 < y < H - 4:
			b.append(ell(x, y, r * 1.5, r, BLOOD, tr="rotate(%s %s %s)" % (f(math.degrees(a)), f(x), f(y))))
	# runs dripping down from the bottom of the splash
	for x0 in (190, 236, 290, 318):
		ln = rng.uniform(60, 150)
		y0 = cy + 50
		b.append(path("M%d %d L%d %s" % (x0 - 6, y0, x0 - 3, f(y0 + ln)) + " Q%d %s %d %s" % (x0, f(y0 + ln + 12), x0 + 3, f(y0 + ln)) + " L%d %d Z" % (x0 + 6, y0), BLOOD))
		b.append(circ(x0, y0 + ln + 2, 7, BLOOD))
	# glossy highlights
	b.append(ell(cx - 30, cy - 34, 30, 9, BLOOD_H, op=0.8, tr="rotate(-18 %d %d)" % (cx - 30, cy - 34)))
	b.append(ell(cx - 38, cy - 38, 8, 3, "#ffffff", op=0.25))
	write("hx_splatter", svg(W, H, "\n".join(b)))


def hx_lamp():
	defs = lin("shade", 0, 0, 1, 0, [(0, "#14181a"), (0.4, "#4a5458"), (1, "#101314")])
	b = [rect(40, 0, 10, 20, "#1a1c1e"),
		path("M45 16 L84 74 L6 74 Z", "url(#shade)", stroke="#050606", sw=2),
		ell(45, 74, 39, 8, "#0c0e0f"),
		ell(45, 82, 16, 14, "#e6f2ea"),
		ell(41, 78, 5, 4, "#ffffff", op=0.8)]
	write("hx_lamp", svg(90, 100, "\n".join(b), defs))


def hx_spotcone():
	W, H = 520, 720
	defs = (lin("cone", 0, 0, 0, 1, [(0, "#ffffff", 0.55), (0.6, "#ffffff", 0.18), (1, "#ffffff", 0.05)])
		+ lin("core", 0, 0, 0, 1, [(0, "#ffffff", 0.5), (1, "#ffffff", 0.0)]))
	b = [poly([(230, 0), (290, 0), (510, H), (10, H)], "url(#cone)"),
		poly([(246, 0), (274, 0), (390, H), (130, H)], "url(#core)", op=0.6)]
	write("hx_spotcone", svg(W, H, "\n".join(b), defs))


def main():
	os.makedirs(OUT, exist_ok=True)
	for fn in (hx_tent, hx_curtain, hx_mq_front, hx_mq_back, hx_mq_side, hx_mq_body, hx_mq_hand,
			hx_cab_back, hx_cab_front, hx_cab_door, hx_cab_door_back, hx_blade, hx_chain, hx_padlock,
			hx_tophat, hx_monocle, hx_eye, hx_snap_sil, hx_standby, hx_splatter, hx_lamp, hx_spotcone):
		fn()


if __name__ == "__main__":
	main()
